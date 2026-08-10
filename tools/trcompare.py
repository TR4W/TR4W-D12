#!/usr/bin/env python3
"""
trcompare -- do IF's T/R flag and TQ agree on the same radio?

THE QUESTION.  On a K3S, after a single RX;, TQ reports receive in ~360 ms
while IF's T/R flag stays at 1 for ~2900 ms.  Two explanations fit:

    (a) the IF flag LAGS -- the radio is already receiving and IF says
        otherwise for nearly three seconds;
    (b) the first RX; was LOST, and the unkey only happened when a later
        retry arrived -- in which case the flag was telling the truth.

They have opposite consequences.  Under (a), IF is the wrong thing to poll
for T/R and the K3 manual's advice to use TQ is well founded.  Under (b),
IF is fine and something is eating commands.

HOW THIS SEPARATES THEM.  Send ONE RX; and never repeat it, then ask TQ; and
IF; alternately, printing both.  If TQ flips to 0 while IF still says 1, the
two disagree and it is (a).  If both hold at 1 until they flip together, it
is (b) and the command never arrived.

SAFETY.  Keys the transmitter for the requested time.  Sends exactly one RX;
during the measurement, deliberately -- retrying would destroy the
experiment -- but ALWAYS unkeys on the way out, confirming it took.

    python trcompare.py --port COM15 --key 3
"""

import argparse
import sys
import time

try:
    import serial
except ImportError:
    sys.exit("pyserial is required:  python -m pip install pyserial")

CR = bytes([13])
IF_LEN = 38
TR_INDEX = 28


def ask(sp, cmd, wait=0.12):
    """Send one command and return whatever came back, raw."""
    sp.reset_input_buffer()
    sp.write(cmd.encode() + CR)
    time.sleep(wait)
    return sp.read(4096).decode("latin-1", "replace")


def tq_flag(raw):
    i = raw.rfind("TQ")
    if i >= 0 and len(raw) >= i + 4 and raw[i + 3] == ";":
        return raw[i + 2]
    return "?"


def if_flag(raw):
    i = raw.rfind("IF")
    while i >= 0:
        if len(raw) >= i + IF_LEN and raw[i + IF_LEN - 1] == ";":
            return raw[i + TR_INDEX]
        i = raw.rfind("IF", 0, i)
    return "?"


def main():
    ap = argparse.ArgumentParser(description="Compare IF's T/R flag against TQ.")
    ap.add_argument("--port", required=True)
    ap.add_argument("--baud", type=int, default=38400)
    ap.add_argument("--key", type=float, default=3.0)
    ap.add_argument("--watch", type=float, default=6.0,
                    help="seconds to keep comparing after the single RX;")
    args = ap.parse_args()

    sp = serial.Serial()
    sp.port = args.port
    sp.baudrate = args.baud
    sp.bytesize = 8
    sp.parity = "N"
    sp.stopbits = 1
    sp.timeout = 0.2
    sp.rtscts = False
    sp.dsrdtr = False
    sp.dtr = False          # pyserial raises these on open; on a rig with PTT
    sp.rts = False          # wired to either that keys the transmitter
    sp.open()

    t0 = time.monotonic()

    def stamp():
        return "%7.0f ms" % ((time.monotonic() - t0) * 1000)

    def sample(note=""):
        tq = tq_flag(ask(sp, "TQ;"))
        f = if_flag(ask(sp, "IF;"))
        mark = "   <<< DISAGREE" if (tq != f and "?" not in (tq, f)) else ""
        print(f"{stamp()}   TQ={tq}  IF={f}{mark}   {note}")
        return tq, f

    try:
        print("=== before keying ===")
        sample()

        print("=== TX; ===")
        sp.write(b"TX;" + CR)
        time.sleep(0.05)
        deadline = time.monotonic() + args.key
        while time.monotonic() < deadline:
            sample()
            time.sleep(0.15)

        print("=== ONE RX; -- not repeated, whatever happens ===")
        sp.write(b"RX;" + CR)
        rx_at = time.monotonic()
        tq_cleared = None
        if_cleared = None
        deadline = time.monotonic() + args.watch
        while time.monotonic() < deadline:
            tq, f = sample()
            if tq == "0" and tq_cleared is None:
                tq_cleared = (time.monotonic() - rx_at) * 1000
            if f == "0" and if_cleared is None:
                if_cleared = (time.monotonic() - rx_at) * 1000
            if tq_cleared is not None and if_cleared is not None:
                break
            time.sleep(0.05)

        print()
        print("RX; -> TQ reported receive : %s" %
              ("%.0f ms" % tq_cleared if tq_cleared is not None else "never, within the watch window"))
        print("RX; -> IF reported receive : %s" %
              ("%.0f ms" % if_cleared if if_cleared is not None else "never, within the watch window"))
        if tq_cleared is not None and if_cleared is not None:
            gap = if_cleared - tq_cleared
            print()
            if abs(gap) < 250:
                print("They agree (%.0f ms apart).  The single RX; worked and both saw it --" % gap)
                print("so the earlier 2900 ms was a LOST COMMAND, not a lagging flag.")
            else:
                print("They DISAGREE by %.0f ms.  The radio was already receiving while IF" % gap)
                print("still said otherwise -- the IF T/R flag lags, and TQ is the one to poll.")
    finally:
        # One RX; during the measurement, but never leave it keyed.
        for _ in range(5):
            sp.write(b"RX;" + CR)
            time.sleep(0.3)
            if if_flag(ask(sp, "IF;")) == "0" and tq_flag(ask(sp, "TQ;")) == "0":
                print("\nrig CONFIRMED in receive")
                break
        else:
            print("\n*** WARNING: could not confirm receive -- CHECK THE RADIO")
        sp.close()


if __name__ == "__main__":
    main()
