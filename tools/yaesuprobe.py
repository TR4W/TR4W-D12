#!/usr/bin/env python3
"""
yaesuprobe -- send one 5-byte Yaesu binary CAT command and dump what comes back.

WHY.  The FT-1000MP driver reads by FIXED FRAME LENGTH: it sends two commands
per cycle and expects their replies to concatenate into exactly 38 bytes.
There is no delimiter, so adding a third command means knowing precisely how
many bytes it answers with -- and getting that wrong misaligns every frame
after it, silently, taking frequency and mode with it.

So: ask the radio, count the bytes, then write the code.

    python yaesuprobe.py --port COM19 --cmd "00 00 00 01 10"
    python yaesuprobe.py --port COM19 --cmd "00 00 00 03 10"   # known: 32
    python yaesuprobe.py --port COM19 --cmd "00 00 00 01 FA"   # known: 6

The two known ones are worth running first: if they report 32 and 6, the probe
agrees with the driver and its answer for the unknown command can be trusted.

SAFETY.  Sends only what you pass on the command line and nothing else, and
holds DTR/RTS low at open -- pyserial raises them, and on a rig whose PTT is
wired to either that keys the transmitter.  Do NOT pass a PTT command unless
that is what you mean: 00 00 00 01 0F keys an FT-1000MP.
"""

import argparse
import sys
import time

try:
    import serial
except ImportError:
    sys.exit("pyserial is required:  python -m pip install pyserial")


def main():
    ap = argparse.ArgumentParser(description="Probe one Yaesu binary CAT command.")
    ap.add_argument("--port", required=True)
    ap.add_argument("--baud", type=int, default=4800)
    ap.add_argument("--cmd", required=True,
                    help='five bytes, hex, e.g. "00 00 00 01 10"')
    ap.add_argument("--wait", type=float, default=1.5,
                    help="seconds to collect the reply (default 1.5)")
    args = ap.parse_args()

    raw = bytes(int(x, 16) for x in args.cmd.replace(",", " ").split())
    if len(raw) != 5:
        sys.exit("a Yaesu binary command is exactly 5 bytes; got %d" % len(raw))

    sp = serial.Serial()
    sp.port = args.port
    sp.baudrate = args.baud
    sp.bytesize = 8
    sp.parity = "N"
    sp.stopbits = 2          # FT-1000MP default is 4800 8N2
    sp.timeout = 0.2
    sp.rtscts = False
    sp.dsrdtr = False
    sp.dtr = False
    sp.rts = False
    sp.open()
    time.sleep(0.3)
    sp.reset_input_buffer()

    sp.write(raw)
    deadline = time.time() + args.wait
    got = b""
    while time.time() < deadline:
        got += sp.read(4096)
    sp.close()

    print("sent     : %s  (%d bytes)" % (" ".join("%02X" % b for b in raw), len(raw)))
    print("received : %d bytes" % len(got))
    if got:
        for i in range(0, len(got), 16):
            chunk = got[i:i + 16]
            print("  %3d: %-47s" % (i, " ".join("%02X" % b for b in chunk)))
        print()
        # The specific thing this was written to answer.
        print("byte 1 (index 0) = %02X   bit7 (=$80) is %s"
              % (got[0], "SET -> transmitting" if got[0] & 0x80 else "clear -> receiving"))
    else:
        print("  (nothing -- wrong port, wrong baud, or the radio does not answer this command)")


if __name__ == "__main__":
    main()
