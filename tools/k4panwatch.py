#!/usr/bin/env python3
"""
k4panwatch -- capture and decode the Elecraft K4 panadapter stream.

WHY THIS EXISTS.  TR4W is about to grow a panadapter window, and the only
description of the K4's spectrum wire format we have is a READING of TR4QT's
C++ decoder (src/radio/K4PanadapterReader.cpp).  That is a second-hand source:
it says the header is 64 bytes, that bytes 7-12 hold an ASCII sample rate, that
the payload is 2048 big-endian int16 tenths of a dB.  Every one of those is a
claim, and porting on top of an unverified claim is how a silently-wrong
decoder ships.  This tool asks the radio instead.

It is also the FIXTURE GENERATOR.  --save writes the raw bytes exactly as they
came off the socket, so the Pascal decoder can later be unit-tested against a
real capture with no radio present -- the same golden-master habit the contest
corpus uses.

WHAT IT DELIBERATELY DOES NOT DO.  By default it sends the radio NOTHING.
TR4QT's reader connects and immediately starts reading with no enable command,
which implies the K4 streams unprompted -- but "TR4QT never sends one" is not
the same fact as "none is needed".  Sending nothing is what tells them apart.
If packets arrive on a silent socket, the stream is unsolicited and that is
now measured rather than inferred.

THE STALL QUESTION.  TR4W's own K4 driver notes that the K4's CAT server drops
silent clients after 10 seconds, which is why it polls PING; every second
(uRadioElecraftK4.pas Connect).  Whether the PANADAPTER port does the same is
unknown, and it matters: if it does, a reader that only listens will die a few
seconds in.  This tool watches for that -- run it silent for 30 s and see
whether the stream stops.  --ping turns on TR4QT's keepalive so the two can be
compared directly.

TRUST NOTHING, PRINT EVERYTHING.  --dump-header prints the raw 64-byte header
as hex and ASCII.  TR4QT only ever reads bytes 0-28 of it; bytes 29-63 are
completely undocumented and might not be padding.  Looking is free.

USAGE
    python k4panwatch.py --host 192.168.73.108
    python k4panwatch.py --host 192.168.73.108 --seconds 30 --save k4pan.bin
    python k4panwatch.py --host 192.168.73.108 --dump-header 2 --seconds 5
    python k4panwatch.py --replay k4pan.bin            # no radio needed

SAFETY.  This tool never transmits and never sends a CAT command.  It opens one
TCP connection and reads.  The only thing it can write is the 4-byte literal
"PING", and only with --ping.
"""

import argparse
import socket
import struct
import sys
import time

# ---------------------------------------------------------------------------
# Frame geometry, as claimed by TR4QT (PanadapterTypes.h:39-43).  Held in one
# place so a capture that contradicts it can be fixed in one place.
# ---------------------------------------------------------------------------
SYNC = bytes([0xFF, 0xFE, 0x01, 0x00])
HEADER_SIZE = 64
SAMPLE_COUNT = 2048
PAYLOAD_SIZE = SAMPLE_COUNT * 2      # 4096
FOOTER_SIZE = 2                      # CRC-16
PACKET_SIZE = HEADER_SIZE + PAYLOAD_SIZE + FOOTER_SIZE   # 4162

# Nibble-table CRC-16, reflected polynomial 0x8408 (the CRC-16/X-25 family).
# Copied from TR4QT K4PanadapterReader.cpp:26-31 -- which credits it to
# Elecraft's own K4LanExample.  Init 0xFFFF, final complement.
CRC16_TABLE = [
   0x0000, 0x1081, 0x2102, 0x3183,
   0x4204, 0x5285, 0x6306, 0x7387,
   0x8408, 0x9489, 0xa50a, 0xb58b,
   0xc60c, 0xd68d, 0xe70e, 0xf78f,
]

# Unpacking 2048 big-endian SIGNED shorts.  Prebuilt: this runs per packet at
# up to ~30 packets/s and struct.Struct is markedly faster than a format string
# re-parsed each call.
SAMPLE_STRUCT = struct.Struct(">%dh" % SAMPLE_COUNT)


def crc16(data):
   """CRC-16 over data, matching the K4's footer."""
   crc = 0xFFFF
   for byte in data:
      c = byte
      crc = ((crc >> 4) & 0x0FFF) ^ CRC16_TABLE[(crc ^ c) & 0x0F]
      c >>= 4
      crc = ((crc >> 4) & 0x0FFF) ^ CRC16_TABLE[(crc ^ c) & 0x0F]
   return ~crc & 0xFFFF


def ascii_field(packet, start, length):
   """An ASCII header field, as text.  Returned raw (only stripped) so a field
   that is not what we think it is shows up as itself rather than as a 0."""
   return packet[start:start + length].decode("latin-1").strip()


def decode(packet):
   """Decode one 4162-byte packet into a dict.

   Every derived value carries its raw source alongside it, because the point
   of this tool is to check the interpretation, not to apply it.  A field that
   fails to parse is reported as None with the raw text preserved -- it is NOT
   defaulted.  TR4QT defaults a bad sample rate to 48000 and a bad centre
   frequency to 0, which is reasonable in a running program and actively
   harmful in a measurement: it would manufacture a plausible reading out of a
   misidentified field.
   """
   out = {}
   out["version"] = packet[4]
   out["seq"] = packet[5]
   out["pan"] = chr(packet[6])

   for name, start, length in (("rate", 7, 6),
                               ("center", 13, 11),
                               ("noise", 24, 5)):
      raw = ascii_field(packet, start, length)
      out[name + "_raw"] = raw
      try:
         out[name] = int(raw)
      except ValueError:
         out[name] = None

   # Noise floor is claimed to be tenths of a dB.
   out["noise_db"] = None if out["noise"] is None else out["noise"] / 10.0

   # Header checksum: TR4QT claims the 64 header bytes sum to zero mod 256.
   out["header_sum"] = sum(packet[:HEADER_SIZE]) & 0xFF

   # CRC-16 over everything but the trailing two bytes, compared big-endian.
   out["crc_computed"] = crc16(packet[:PACKET_SIZE - 2])
   out["crc_received"] = (packet[PACKET_SIZE - 2] << 8) | packet[PACKET_SIZE - 1]

   samples = SAMPLE_STRUCT.unpack_from(packet, HEADER_SIZE)
   out["raw_min"] = min(samples)
   out["raw_max"] = max(samples)
   out["db_min"] = out["raw_min"] / 10.0
   out["db_max"] = out["raw_max"] / 10.0
   out["db_mean"] = sum(samples) / len(samples) / 10.0
   return out


def dump_header(packet):
   """The whole 64-byte header, hex and ASCII, 16 bytes to a line.

   Bytes 29-63 are read by nothing in TR4QT.  If they turn out to be non-zero
   and structured, that is a finding -- and it is only visible if we look.
   """
   lines = []
   for offset in range(0, HEADER_SIZE, 16):
      chunk = packet[offset:offset + 16]
      hexpart = " ".join("%02x" % b for b in chunk)
      txt = "".join(chr(b) if 32 <= b < 127 else "." for b in chunk)
      lines.append("    %02d  %-47s  %s" % (offset, hexpart, txt))
   return "\n".join(lines)


class Framer:
   """Byte stream -> whole packets, with resync.

   Mirrors TR4QT's loop (K4PanadapterReader.cpp:135-178) deliberately, so that
   if the framing rule is wrong we find out here rather than in Pascal: hunt
   for the sync marker, discard what precedes it, and keep the trailing 3 bytes
   when no marker is found so a marker split across two reads is not lost.
   """

   def __init__(self):
      self.buf = bytearray()
      self.discarded = 0
      self.resyncs = 0

   def feed(self, data):
      self.buf.extend(data)
      while len(self.buf) >= PACKET_SIZE:
         if self.buf[0:4] != SYNC:
            pos = self.buf.find(SYNC, 1)
            if pos < 0:
               # Keep the last 3 bytes: a marker may straddle the boundary.
               keep = min(len(self.buf), 3)
               self.discarded += len(self.buf) - keep
               del self.buf[:len(self.buf) - keep]
               return
            self.discarded += pos
            self.resyncs += 1
            del self.buf[:pos]
            continue
         packet = bytes(self.buf[:PACKET_SIZE])
         del self.buf[:PACKET_SIZE]
         yield packet


class Stats:
   """Per-run tallies.  Kept separate from decoding so replay and live share it."""

   def __init__(self):
      self.packets = 0
      self.header_bad = 0
      self.crc_bad = 0
      self.pans = {}
      self.last_seq = {}
      self.seq_gaps = 0
      self.rates = {}
      self.first_time = None
      self.last_time = None

   def add(self, info):
      self.packets += 1
      now = time.monotonic()
      if self.first_time is None:
         self.first_time = now
      self.last_time = now

      if info["header_sum"] != 0:
         self.header_bad += 1
      if info["crc_computed"] != info["crc_received"]:
         self.crc_bad += 1

      pan = info["pan"]
      self.pans[pan] = self.pans.get(pan, 0) + 1
      self.rates[info["rate_raw"]] = self.rates.get(info["rate_raw"], 0) + 1

      # Sequence is per pan: two pans interleaved on one socket each carry
      # their own counter, so a global check would report constant false gaps.
      prev = self.last_seq.get(pan)
      if prev is not None and info["seq"] != (prev + 1) % 256:
         self.seq_gaps += 1
      self.last_seq[pan] = info["seq"]

   def report(self, framer):
      print()
      print("=" * 70)
      print("SUMMARY")
      print("=" * 70)
      if self.packets == 0:
         print("  NO PACKETS DECODED.")
         print("  Bytes discarded while hunting for a sync marker: %d" % framer.discarded)
         print("  If bytes arrived but none framed, the packet geometry is wrong.")
         return

      span = (self.last_time - self.first_time) if self.last_time else 0.0
      print("  packets decoded    %d" % self.packets)
      if span > 0.5:
         print("  packet rate        %.1f/s  over %.1f s" % (self.packets / span, span))
      print("  header sum != 0    %d   %s" % (
         self.header_bad,
         "OK -- the zero-sum rule holds" if self.header_bad == 0 else "*** RULE IS WRONG ***"))
      print("  CRC-16 mismatches  %d   %s" % (
         self.crc_bad,
         "OK -- CRC understood" if self.crc_bad == 0 else "*** CRC IS WRONG ***"))
      print("  sequence gaps      %d" % self.seq_gaps)
      print("  resyncs            %d  (%d bytes discarded)" % (framer.resyncs, framer.discarded))
      print("  pan IDs seen       %s" % ", ".join(
         "%s=%d" % (k, v) for k, v in sorted(self.pans.items())))
      print("  sample-rate fields %s" % ", ".join(
         "'%s'=%d" % (k, v) for k, v in sorted(self.rates.items())))


def show(info, index, args, packet):
   """One line (or more) per packet, at whatever depth was asked for."""
   hdr_ok = "ok" if info["header_sum"] == 0 else "BAD"
   crc_ok = "ok" if info["crc_computed"] == info["crc_received"] else "BAD"

   if info["center"] is not None and info["rate"]:
      half = info["rate"] / 2.0
      span = "%.6f - %.6f MHz" % ((info["center"] - half) / 1e6,
                                  (info["center"] + half) / 1e6)
   else:
      span = "span unknown"

   print("#%-6d pan=%s seq=%-3d ver=%d  rate='%s' center='%s' noise='%s'"
         % (index, info["pan"], info["seq"], info["version"],
            info["rate_raw"], info["center_raw"], info["noise_raw"]))
   print("        %s   noise=%s dB   dB range %.1f .. %.1f  mean %.1f"
         % (span,
            "?" if info["noise_db"] is None else "%.1f" % info["noise_db"],
            info["db_min"], info["db_max"], info["db_mean"]))
   print("        header sum=%d (%s)  crc computed=%04x received=%04x (%s)"
         % (info["header_sum"], hdr_ok,
            info["crc_computed"], info["crc_received"], crc_ok))

   if index < args.dump_header:
      print(dump_header(packet))
   print()


def run_live(args):
   framer = Framer()
   stats = Stats()
   saved = open(args.save, "wb") if args.save else None

   print("connecting to %s:%d ..." % (args.host, args.port))
   sock = socket.create_connection((args.host, args.port), timeout=5.0)
   sock.settimeout(1.0)
   print("connected.  %s" % ("sending PING keepalive every 5 s"
                             if args.ping else
                             "SENDING NOTHING -- if packets arrive, the stream is unsolicited"))
   print("running for up to %.0f s (Ctrl-C to stop early)" % args.seconds)
   print()

   started = time.monotonic()
   last_data = started
   last_ping = started
   shown = 0
   total_bytes = 0
   stalled_reported = False

   try:
      while time.monotonic() - started < args.seconds:
         now = time.monotonic()

         if args.ping and now - last_ping >= 5.0:
            sock.sendall(b"PING")
            last_ping = now

         try:
            data = sock.recv(65536)
         except socket.timeout:
            data = b""

         if data:
            total_bytes += len(data)
            last_data = now
            stalled_reported = False
            if saved:
               saved.write(data)
            for packet in framer.feed(data):
               info = decode(packet)
               stats.add(info)
               if shown < args.show:
                  show(info, shown, args, packet)
               shown += 1

         # THE STALL CHECK.  This is the whole reason to run silent: if the
         # K4 hangs up on a quiet client the way its CAT port does, it shows
         # up here as a gap, and that is a real finding about what the Pascal
         # reader will need to do.
         quiet = now - last_data
         if quiet > 3.0 and not stalled_reported:
            print("*** STREAM STALLED: no bytes for %.1f s at t=%.1f s%s"
                  % (quiet, now - started,
                     "" if args.ping else "  (running WITHOUT keepalive -- try --ping)"))
            stalled_reported = True

   except KeyboardInterrupt:
      print("\ninterrupted")
   finally:
      sock.close()
      if saved:
         saved.close()
         print("raw capture written to %s" % args.save)
      print("bytes received: %d" % total_bytes)
      stats.report(framer)


def run_replay(args):
   framer = Framer()
   stats = Stats()
   print("replaying %s" % args.replay)
   print()

   shown = 0
   with open(args.replay, "rb") as handle:
      while True:
         data = handle.read(65536)
         if not data:
            break
         for packet in framer.feed(data):
            info = decode(packet)
            stats.add(info)
            if shown < args.show:
               show(info, shown, args, packet)
            shown += 1

   # Replay has no wall clock, so suppress the rate line by clearing the span.
   stats.first_time = stats.last_time = None
   stats.report(framer)


def main():
   ap = argparse.ArgumentParser(
      description="Capture and decode the Elecraft K4 panadapter stream.")
   ap.add_argument("--host", help="K4 IP address, e.g. 192.168.73.108")
   ap.add_argument("--port", type=int, default=9201,
                   help="panadapter port; the K4 serves it on CAT port + 1 "
                        "(CAT defaults to 9200, so this defaults to 9201)")
   ap.add_argument("--seconds", type=float, default=15.0,
                   help="how long to capture (default 15)")
   ap.add_argument("--show", type=int, default=5,
                   help="decode and print this many packets in full (default 5)")
   ap.add_argument("--dump-header", type=int, default=0, metavar="N",
                   help="hex-dump the full 64-byte header of the first N "
                        "packets.  TR4QT reads only bytes 0-28; this is how "
                        "you find out what is in the rest.")
   ap.add_argument("--save", metavar="FILE",
                   help="write the raw socket bytes to FILE, for replay and "
                        "as a unit-test fixture")
   ap.add_argument("--replay", metavar="FILE",
                   help="decode a previously saved capture; no radio needed")
   ap.add_argument("--ping", action="store_true",
                   help="send TR4QT's 4-byte PING keepalive every 5 s.  Off by "
                        "default so that a silent run can establish whether "
                        "the stream is unsolicited and whether the radio drops "
                        "quiet clients.")
   args = ap.parse_args()

   if args.replay:
      run_replay(args)
   elif args.host:
      run_live(args)
   else:
      ap.error("give --host to capture, or --replay to decode a capture")


if __name__ == "__main__":
   main()
