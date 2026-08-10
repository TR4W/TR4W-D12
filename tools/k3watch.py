#!/usr/bin/env python3
"""
k3watch -- poll an Elecraft (or Kenwood-protocol) rig and report T/R changes.

WHY THIS EXISTS.  A PTT unkey that looked like a one-second delay in TR4W
turned out to be RX; queued behind poll traffic inside the RADIO's own CAT
input buffer.  Proving that needed a measurement with TR4W entirely out of
the picture -- one program, one port, nothing else talking.  This is that
tool, kept because the next such question will want it too.

WHAT IT DOES.  Sends IF; over and over and prints a line every time the T/R
flag changes, with the interval since the previous change.  Optionally sends
TX; / RX; itself so you can measure command-to-effect latency directly.

PACING.  By default it waits for each reply before sending the next request.
That is the point: a fixed-rate poller that does not wait is exactly what
caused the problem this tool was written to find.  Use --interval to poll on
a timer instead (i.e. to REPRODUCE the fault), and --burst to send the same
four-command poll TR4W used to send.

USAGE
    python k3watch.py --port COM15
    python k3watch.py --port COM15 --key 3           # TX for 3 s, then RX
    python k3watch.py --port COM15 --interval 0.117 --burst   # reproduce it

SAFETY.  --key transmits.  In a data mode with no audio applied a K3 puts out
essentially nothing, but check what the rig is connected to first.  The
transmission is bounded and the script always sends RX; on the way out,
including on Ctrl-C.
"""

import argparse
import sys
import time

try:
    import serial
except ImportError:
    sys.exit("pyserial is required:  python -m pip install pyserial")


# The IF response is 37 characters plus the ';'.  Index 28 is the T/R flag.
#
# That index was established empirically rather than read off a chart: it was
# the ONLY character that differed between a transmitting and a receiving
# response from this rig, and the character immediately after it is the mode
# field (6 = DATA), which pins the alignment.  Verify it on your own rig with
# --raw before trusting it.
TR_INDEX = 28
IF_LEN = 38          # 'IF' + 35 payload + ';'


def find_last_if(buf):
    """Return the most recent complete IF response in buf, or None.

    FIXED LENGTH, deliberately.  The first version searched back from the last
    ';', which with a burst poll ('IF;FB;MD$;DT$;') returned a span reaching
    from the IF all the way to the DT$ reply's terminator -- one "response"
    several fields long.  The T/R character happened to still land inside the
    IF part so the readings were right by luck, but the consume step then ate
    replies that had not been examined.  An IF response is exactly IF_LEN
    characters ending in ';': accept nothing else.
    """
    start = buf.rfind("IF")
    while start != -1:
        end = start + IF_LEN - 1
        if end < len(buf) and buf[end] == ";":
            return buf[start:end + 1]
        start = buf.rfind("IF", 0, start)
    return None


def find_last_tq(buf):
    """Return the most recent complete TQ response in buf, or None."""
    i = buf.rfind("TQ")
    if i == -1 or len(buf) < i + 4 or buf[i + 3] != ";":
        return None
    return buf[i:i + 4]


def tr_flag(resp):
    """The T/R character, from either an IF or a TQ response."""
    if resp is None:
        return None
    if resp.startswith("TQ"):
        return resp[2]              # TQ0; / TQ1;
    if len(resp) <= TR_INDEX:
        return None
    return resp[TR_INDEX]


def describe(flag):
    if flag == "1":
        return "TRANSMIT"
    if flag == "0":
        return "receive "
    return "unknown "


def main():
    ap = argparse.ArgumentParser(description="Watch a rig's T/R state over CAT.")
    ap.add_argument("--port", required=True, help="e.g. COM15 or /dev/ttyUSB0")
    ap.add_argument("--baud", type=int, default=38400)
    ap.add_argument("--interval", type=float, default=0.0,
                    help="seconds between polls; 0 (default) means wait for "
                         "each reply before sending the next")
    ap.add_argument("--burst", action="store_true",
                    help="send IF;FB;MD$;DT$; instead of IF; -- the poll TR4W "
                         "used to send, for reproducing the backlog")
    ap.add_argument("--key", type=float, default=0.0, metavar="SECONDS",
                    help="transmit for this long, then return to receive, and "
                         "report the latency of each command")
    ap.add_argument("--probe", choices=["if", "tq"], default="if",
                    help="what to ask for.  'tq' uses the K3's TQ; query, "
                         "which answers TQ0;/TQ1; -- far fewer bytes than an "
                         "IF response.  NOTE the manual's caveat: TQ1 is also "
                         "returned for PSEUDO-transmit (TX TEST, or pre-armed "
                         "for CW via XMIT/PTT), because those raise KEY OUT "
                         "for downstream relays.  So tq and if do NOT always "
                         "agree, and that difference is worth measuring.")
    ap.add_argument("--wait-all", action="store_true",
                    help="with --burst, wait for EVERY reply before sending "
                         "the next poll, not just the first.  This models the "
                         "proposed change to TR4W's gate, which today reopens "
                         "on any valid response -- so with a four-command "
                         "poll the IF reply releases it while FB/MD$/DT$ are "
                         "still in flight.  Run it against plain --burst to "
                         "see what strengthening the gate would buy.")
    ap.add_argument("--raw", action="store_true",
                    help="print every response, not just the changes")
    ap.add_argument("--max-seconds", type=float, default=60.0,
                    help="hard stop.  This tool can key a transmitter, so it "
                         "must not be able to run unbounded if anything goes "
                         "wrong -- see the reply timeout below.")
    args = ap.parse_args()

    poll = "IF;FB;MD$;DT$;\r" if args.burst else "IF;\r"

    # DO NOT let the port open assert DTR/RTS.
    #
    # pyserial raises both lines when it opens a port, and on a rig whose PTT
    # is wired to either one that KEYS THE TRANSMITTER before a single command
    # has been sent.  It happened on the first run of this script: the rig
    # reported transmitting 172 ms in, before any TX;, and stayed keyed after
    # the script exited.
    #
    # Setting the attributes on an unopened Serial makes pyserial apply them
    # as part of the open, so there is no window in which they are high.  It
    # is not the same as clearing them afterwards.
    sp = serial.Serial()
    sp.port = args.port
    sp.baudrate = args.baud
    sp.bytesize = 8
    sp.parity = "N"
    sp.stopbits = 1
    sp.timeout = 0.05
    sp.rtscts = False
    sp.dsrdtr = False
    sp.dtr = False
    sp.rts = False
    sp.open()

    # Whatever state the rig was left in, start from receive, and drain
    # anything the previous talker left in flight so a stale response cannot
    # be read as the current state.
    sp.write(b"RX;\r")
    time.sleep(0.4)
    sp.reset_input_buffer()

    print(f"{args.port} at {args.baud} 8N1.  "
          f"{'paced (wait for reply)' if args.interval == 0 else f'every {args.interval*1000:.0f} ms'}"
          f"{', burst poll' if args.burst else ''}.  Ctrl-C to stop.")
    print()

    buf = ""
    last_flag = None
    last_change = time.monotonic()
    key_at = None
    unkey_at = None
    # Separate from unkey_at, which is CLEARED once the change is reported.
    # Reusing it as the "have we sent RX; yet" flag re-armed the schedule and
    # sent a second RX;.
    unkey_sent = False
    pending = False        # a poll is out and unanswered
    sent_at = 0.0
    next_poll = 0.0
    started = time.monotonic()

    def stamp():
        return time.strftime("%H:%M:%S") + f".{int(time.time() % 1 * 1000):03d}"

    try:
        while True:
            now = time.monotonic()

            # --- keying schedule ----------------------------------------
            if args.key > 0:
                if key_at is None and now - started > 1.0:
                    sp.write(b"TX;\r")
                    key_at = time.monotonic()
                    print(f"{stamp()}  -> TX;")
                elif (key_at is not None and not unkey_sent
                      and now - key_at >= args.key):
                    sp.write(b"RX;\r")
                    unkey_at = time.monotonic()
                    unkey_sent = True
                    print(f"{stamp()}  -> RX;")

            # --- send a poll --------------------------------------------
            if args.interval > 0:
                if now >= next_poll:
                    sp.write(poll.encode())
                    next_poll = now + args.interval
            elif not pending:
                sp.write(poll.encode())
                pending = True
                sent_at = now
            elif now - sent_at > 0.5:
                # THE DEADLOCK THIS FIXES.  Paced polling only sends when the
                # previous reply is in, so a SINGLE missed response stopped
                # this loop sending for ever -- and with nothing being sent,
                # nothing ever arrived to clear it.  The script then hung with
                # the rig KEYED, which is exactly the failure a test tool must
                # not have.  (The same reasoning is why the fix in TR4W's poll
                # loop carries a timeout: flow control without one is a stall
                # waiting to happen.)
                pending = False

            # --- read ---------------------------------------------------
            data = sp.read(4096)
            if data:
                buf += data.decode("latin-1")
                if len(buf) > 8192:
                    buf = buf[-2048:]

            if args.probe == "tq" and not args.burst:
                resp = find_last_tq(buf)
            else:
                resp = find_last_if(buf)

            # WHAT SATISFIES A POLL.
            #
            # Normally any reply does -- which is exactly what TR4W's gate
            # does today, because UpdateLastValidResponse fires per frame.
            # With a four-command burst that means the IF reply releases the
            # gate while FB/MD$/DT$ are still inbound, so the next burst goes
            # out on top of them and the backlog the gate exists to prevent
            # builds anyway.
            #
            # --wait-all models the proposed fix: DT$ is sent LAST, so its
            # reply is the one that means "the radio has finished with that
            # burst".  Run it against plain --burst to see what strengthening
            # the gate would buy before changing TR4W.
            if args.wait_all and args.burst:
                if "DT" in buf and buf.rstrip().endswith(";"):
                    pending = False
            elif resp is not None:
                pending = False

            if resp is not None:
                flag = tr_flag(resp)

                if args.raw:
                    print(f"{stamp()}  {describe(flag)}  {resp}")

                if flag is not None and flag != last_flag:
                    t = time.monotonic()
                    if last_flag is None:
                        print(f"{stamp()}  {describe(flag)}  (initial)")
                    else:
                        held = (t - last_change) * 1000
                        line = f"{stamp()}  {describe(flag)}  after {held:7.0f} ms"
                        # The number that matters: command -> observed effect.
                        if flag == "1" and key_at is not None:
                            line += f"   [TX; -> transmitting: {(t - key_at)*1000:.0f} ms]"
                        if flag == "0" and unkey_at is not None:
                            line += f"   [RX; -> receiving:    {(t - unkey_at)*1000:.0f} ms]"
                            unkey_at = None
                        print(line)
                    last_flag = flag
                    last_change = t
                    # Consume, so the same response is not re-reported.
                    buf = buf[buf.rfind(resp) + len(resp):]

            if args.interval == 0 and pending:
                time.sleep(0.005)

            # Hard stop, whatever else is going on.  Checked before the
            # normal exit so a bug in that condition cannot outrank it.
            if now - started > args.max_seconds:
                print(f"{stamp()}  max-seconds reached, stopping")
                break

            # Exit once a --key cycle has completed and settled.
            if (args.key > 0 and unkey_sent and last_flag == "0"
                    and now - key_at > args.key + 0.5):
                break

    except KeyboardInterrupt:
        print("\ninterrupted")
    finally:
        try:
            sp.write(b"RX;\r")     # never leave the rig keyed
            time.sleep(0.2)
        except Exception:
            pass
        sp.close()
        print("port closed, rig left in receive")


if __name__ == "__main__":
    main()
