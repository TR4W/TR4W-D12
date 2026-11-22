"""wire_check.py -- the receiving half of bench_wire_formats (issue 300).

bench_wire_formats.exe <corpus> 3 <outdir> writes, per corpus log, three files
of length-prefixed frames (4-byte little-endian length, then the payload):

   <set>.jsonfull   JSON, every field named
   <set>.jsonomit   JSON, blank and zero fields omitted
   <set>.tlv        tag byte, length byte, value; tag 0 is the checksum

plus fields.json: the field names in TAG ORDER (tag i is entry i, 1-based) and
whether each is numeric.

THIS IS AN INDEPENDENT RECEIVER. It never sees the Pascal code: it decodes each
frame, fills every missing field with blank, rebuilds the canonical stream from
the RULE (below) and recomputes the CRC-32 with zlib. A frame is GOOD only if
that equals the checksum the sender stated. So a disagreement between Pascal
and Python about the canonical form shows up here as a mismatch, which is the
point of running it in another language (and on another machine).

THE CANONICAL RULE: for every field i = 1..N in order, with blanks included:
   byte(i), byte(len(value)), value bytes (latin-1)
where a numeric 0 and an empty string are both the empty value.

Also reports bytes per record and decode microseconds per record, and repeats
the dropped-field test: every non-blank field treated as lost must change the
CRC.

Usage:  python wire_check.py <outdir> [passes]
Exit 0 only if every frame verified and every dropped field was detected.
"""

import json
import os
import struct
import sys
import time
import zlib


def canon_crc(vals, skip=0):
   """CRC-32 of the canonical stream. vals[0] is unused (tags start at 1)."""
   parts = []
   for i in range(1, len(vals)):
      v = "" if i == skip else vals[i]
      b = v.encode("latin-1")
      parts.append(bytes((i, len(b))))
      parts.append(b)
   return zlib.crc32(b"".join(parts)) & 0xFFFFFFFF


def read_frames(path):
   with open(path, "rb") as f:
      data = f.read()
   frames = []
   pos = 0
   while pos < len(data):
      (n,) = struct.unpack_from("<I", data, pos)
      pos += 4
      frames.append(data[pos:pos + n])
      pos += n
   return frames


def decode_json(frame, names, nums):
   """Returns (vals, stated_crc). A missing member stays blank."""
   obj = json.loads(frame.decode("utf-8"))
   stated = int(obj.pop("k"), 16)
   vals = [""] * (len(names) + 1)
   for idx, name in enumerate(names, start=1):
      if name in obj:
         v = obj[name]
         if nums[idx - 1]:
            vals[idx] = "" if v == 0 else str(v)
         else:
            vals[idx] = v
   return vals, stated


def decode_tlv(frame, count):
   vals = [""] * (count + 1)
   stated = 0
   p = 0
   while p < len(frame):
      tag = frame[p]
      ln = frame[p + 1]
      p += 2
      body = frame[p:p + ln]
      p += ln
      if tag == 0:
         stated = struct.unpack("<I", body)[0]
      else:
         vals[tag] = body.decode("latin-1")
   return vals, stated


def check(frames, decode):
   """Verify every frame; returns (bad, dropped_trials, dropped_caught)."""
   bad = 0
   trials = 0
   caught = 0
   for frame in frames:
      vals, stated = decode(frame)
      full = canon_crc(vals)
      if full != stated:
         bad += 1
      for i in range(1, len(vals)):
         if vals[i] != "":
            trials += 1
            if canon_crc(vals, skip=i) != full:
               caught += 1
   return bad, trials, caught


def time_decode(frames, decode, passes):
   """Decode and recompute the checksum, nothing else (microseconds/record)."""
   start = time.perf_counter()
   for _ in range(passes):
      for frame in frames:
         vals, stated = decode(frame)
         canon_crc(vals)
   elapsed = time.perf_counter() - start
   return elapsed * 1e6 / (passes * len(frames))


def main():
   if len(sys.argv) < 2:
      print(__doc__)
      return 2
   outdir = sys.argv[1]
   passes = int(sys.argv[2]) if len(sys.argv) > 2 else 3

   with open(os.path.join(outdir, "fields.json"), encoding="utf-8") as f:
      fields = json.load(f)
   names = [e["name"] for e in fields]
   nums = [e["num"] for e in fields]
   count = len(names)

   formats = [
      ("jsonfull", lambda fr: decode_json(fr, names, nums)),
      ("jsonomit", lambda fr: decode_json(fr, names, nums)),
      ("tlv", lambda fr: decode_tlv(fr, count)),
   ]

   sets = sorted(f[:-4] for f in os.listdir(outdir) if f.endswith(".tlv"))
   print("wire_check: %d fields, %d sets, %d timing passes, python %s" %
         (count, len(sets), passes, sys.version.split()[0]))
   print("%-26s %-9s %6s %9s %10s %9s %5s" %
         ("set", "format", "QSOs", "avg bytes", "dec us/rec", "dropped", "bad"))

   total_bad = 0
   total_trials = 0
   total_caught = 0
   totals = {}
   for s in sets:
      for ext, decode in formats:
         frames = read_frames(os.path.join(outdir, s + "." + ext))
         if not frames:
            continue
         bad, trials, caught = check(frames, decode)
         us = time_decode(frames, decode, passes)
         avg = sum(len(fr) for fr in frames) / len(frames)
         print("%-26s %-9s %6d %9.1f %10.1f %4d/%-4d %5d" %
               (s, ext, len(frames), avg, us, caught, trials, bad))
         total_bad += bad
         total_trials += trials
         total_caught += caught
         t = totals.setdefault(ext, [0, 0.0, 0.0])
         t[0] += len(frames)
         t[1] += avg * len(frames)
         t[2] += us * len(frames)

   print()
   for ext, (n, nbytes, nus) in totals.items():
      print("ALL %-9s %6d QSOs  %7.1f bytes avg  %7.1f us/rec decode" %
            (ext, n, nbytes / n, nus / n))
   print("dropped-field test: %d of %d detected; frames failing verification: %d" %
         (total_caught, total_trials, total_bad))
   return 0 if (total_bad == 0 and total_caught == total_trials) else 1


if __name__ == "__main__":
   sys.exit(main())
