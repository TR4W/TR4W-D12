#!/usr/bin/env python3
"""
aiprobe -- does the auto-info level survive a port close?

DOES EXACTLY FOUR THINGS AND NOTHING ELSE (NY4I):

    1. open the port
    2. send  AI;
    3. print what came back, RAW -- no parsing, no interpretation
    4. send  AI2;   then close

Nothing is sent on the way out.  No RX;, no restore, no IF;, no tidying up.
That is the whole point: run it twice, and the second run's AI; reply says
whether the radio kept AI2 across the close.

The one thing done that was not asked for is holding DTR and RTS low at open,
and it is not a radio command: pyserial raises both lines when it opens a
port, and on a rig whose PTT is wired to either that KEYS THE TRANSMITTER.
It did exactly that on this bench earlier.

    python aiprobe.py --port COM15      # run me twice
"""

import argparse
import sys
import time

try:
    import serial
except ImportError:
    sys.exit("pyserial is required:  python -m pip install pyserial")


def main():
    ap = argparse.ArgumentParser(description="Read the auto-info level, set AI2, close.")
    ap.add_argument("--port", required=True)
    ap.add_argument("--baud", type=int, default=38400)
    ap.add_argument("--set", default="AI2;",
                    help="what to leave the radio at (default AI2;)")
    args = ap.parse_args()

    sp = serial.Serial()
    sp.port = args.port
    sp.baudrate = args.baud
    sp.bytesize = 8
    sp.parity = "N"
    sp.stopbits = 1
    sp.timeout = 0.5
    sp.rtscts = False
    sp.dsrdtr = False
    sp.dtr = False          # see the module comment -- safety, not a command
    sp.rts = False
    sp.open()

    # 2 + 3: ask, and print the answer verbatim.
    sp.write(b"AI;" + bytes([13]))
    time.sleep(0.6)
    raw = sp.read(4096)

    print("sent    : %r" % (b"AI;" + bytes([13])))
    print("received: %r" % raw)
    print("as text : %s" % raw.decode("latin-1", "replace"))

    # 4: set, then close.  Nothing else.
    sp.write(args.set.encode() + bytes([13]))
    time.sleep(0.3)
    print("sent    : %r" % (args.set.encode() + bytes([13])))

    sp.close()
    print("port closed -- nothing else sent")


if __name__ == "__main__":
    main()
