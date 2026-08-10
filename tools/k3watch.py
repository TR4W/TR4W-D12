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
import re
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

# DT$ is the LAST command in the burst poll, so its reply is what means "the
# radio has finished with that burst".  The reply carries the sub-receiver
# marker back: we send DT$; and the K3 answers DT$0;.  The optional $ is
# NOT cosmetic -- requiring a digit straight after "DT" matched nothing, so
# --wait-all would never have fired.  Caught by test_k3watch.py, not by a
# fourth trip to the radio.  The echoed command DT$; must not match.
DT_REPLY = re.compile(r"DT\$?\d;")


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


def ensure_receive(sp, attempts=5):
    """Send RX; and CONFIRM the rig acted on it.  Returns True if it did.

    WHY THIS IS NOT ONE WRITE.  The exit path used to send a single RX; and
    print "rig left in receive" -- a claim, not a fact.  It was wrong twice on
    NY4I's bench: the script exited saying that while the K3 was still keyed.
    A transmitter is the one thing a test tool must not be optimistic about,
    so this asks the rig, and if it cannot get agreement it says so loudly
    instead of reassuring.
    """
    for _ in range(attempts):
        try:
            sp.reset_input_buffer()
            sp.write(b"RX;" + bytes([13]))
            time.sleep(0.3)
            sp.write(b"IF;" + bytes([13]))
            time.sleep(0.3)
            resp = find_last_if(sp.read(4096).decode("latin-1"))
            if resp is not None and tr_flag(resp) == "0":
                return True
        except Exception:
            pass
    return False


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
    ap.add_argument("--ai", type=int, choices=[0, 1, 2, 3], default=None,
                    help="set the rig's auto-info level, then LISTEN.  AI is "
                         "the other side of everything this tool measures: "
                         "the latency it exists to find comes from OUR "
                         "commands sitting in the rig's input queue, so a "
                         "mode where the rig pushes state and we send nothing "
                         "removes the cause instead of trading against it.  "
                         "With --ai and no explicit --poll nothing is polled "
                         "at all, so what you see is what the rig "
                         "volunteered.  AI0 is restored on exit.")
    ap.add_argument("--poll", default="",
                    help="exact poll string to send each cycle, e.g. "
                         "--poll IF;FB; or --poll TQ;  Overrides --burst "
                         "and --probe.  Use it to price each command: on a "
                         "K3 every extra command in the transmit-time poll "
                         "cost roughly 125 ms of unkey latency.")
    ap.add_argument("--raw", action="store_true",
                    help="print every response, not just the changes")
    ap.add_argument("--max-seconds", type=float, default=0.0,
                    help="hard stop.  This tool can key a transmitter, so it "
                         "must not be able to run unbounded if anything goes "
                         "wrong -- see the reply timeout below.")
    args = ap.parse_args()

    # The hard stop is a TRANSMIT safety, so it only needs to be tight when
    # this tool can key.  A listening session is hands-on -- you are turning
    # the VFO and pressing buttons -- and cutting it off after a minute helps
    # nobody.  Ctrl-C ends it either way.
    if args.max_seconds <= 0:
        args.max_seconds = 60.0 if args.key > 0 else 3600.0

    # WHAT TO SEND EACH CYCLE.
    #
    # --poll wins, so any combination can be measured without editing this
    # file.  That matters: the useful question is not "burst or not" but what
    # each COMMAND in the transmit-time poll costs in unkey latency, and that
    # is a table someone builds by trying them.
    # --ai with no explicit --poll means LISTEN ONLY.  Polling would defeat
    # the point: the question is what the radio sends WITHOUT being asked.
    listen_only = (args.ai is not None and args.ai > 0 and not args.poll)

    if args.poll:
        poll = args.poll
    elif args.burst:
        poll = "TQ;FB;MD$;DT$;" if args.probe == "tq" else "IF;FB;MD$;DT$;"
    elif args.probe == "tq":
        poll = "TQ;"
    else:
        poll = "IF;"
    CR = chr(13)
    if not poll.endswith(CR):
        poll += CR

    # Where the T/R flag is read from follows what we actually ASK for, so a
    # switch cannot disagree with the poll.  --probe tq was parsed and then
    # never used to build the poll string, so it has been sending IF; all
    # along -- a silent no-op edit that nothing checked.
    use_tq = "TQ" in poll

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

    if args.ai is not None:
        # SET IT, THEN ASK THE RADIO WHAT IT THINKS -- and print the answer.
        # Announcing "auto-info set to AI0" without showing the reply is an
        # assertion, not a measurement, and NY4I rightly would not take it on
        # trust when the result of a run depends on it.
        sp.write(("AI%d;" % args.ai).encode() + bytes([13]))
        time.sleep(0.3)
        sp.reset_input_buffer()
        sp.write(b"AI;" + bytes([13]))
        time.sleep(0.4)
        echoed = sp.read(4096).decode("latin-1", "replace").strip()
        sp.reset_input_buffer()
        print(f"auto-info: sent AI{args.ai};  radio answered {echoed!r}"
              + ("   LISTENING ONLY -- nothing is polled" if listen_only else ""))
        if echoed and ("AI%d;" % args.ai) not in echoed:
            print(f"*** WARNING: radio did not confirm AI{args.ai} -- readings below may not mean what you think")

    if listen_only:
        print("not polling -- every line below is something the RADIO sent")
        print("use the radio's controls now (VFO, mode, XMIT); Ctrl-C when done")
    else:
        print(f"poll: {poll.rstrip()}    T/R read from {'TQ' if use_tq else 'IF'}")
    if listen_only:
        mode = "listening"
    elif args.interval == 0:
        mode = "paced (wait for reply)"
    else:
        mode = f"every {args.interval*1000:.0f} ms"
    print(f"{args.port} at {args.baud} 8N1.  {mode}"
          f"{', burst poll' if args.burst and not listen_only else ''}.  "
          f"Ctrl-C to stop.")
    print()

    buf = ""
    poll_buf = ""          # replies to the poll currently outstanding
    last_rx = 0.0          # when bytes last arrived, for --wait-all
    last_unkey_retry = 0.0 # rate-limits the transmit watchdog
    msg_buf = ""           # for splitting the stream into whole messages
    tally = {}             # message prefix -> how many arrived
    first_seen = {}        # message prefix -> seconds after start
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
            if listen_only:
                pass
            elif args.interval > 0:
                if now >= next_poll:
                    sp.write(poll.encode())
                    poll_buf = ""
                    next_poll = now + args.interval
            elif not pending:
                sp.write(poll.encode())
                poll_buf = ""
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
                chunk = data.decode("latin-1")
                buf += chunk
                poll_buf += chunk          # THIS poll's replies only
                last_rx = now               # for the quiet-period rule
                if len(buf) > 8192:
                    buf = buf[-2048:]

            # WHAT DID THE RADIO VOLUNTEER?  Split the stream into whole
            # messages and record each, so an --ai run answers the actual
            # question: does the rig push T/R changes?  VFO B?  the mode?
            if data:
                msg_buf += chunk
                while ";" in msg_buf:
                    j = msg_buf.index(";")
                    msg, msg_buf = msg_buf[:j + 1].strip(), msg_buf[j + 1:]
                    if not msg:
                        continue
                    prefix = ""
                    for ch in msg:
                        if not ch.isalpha():
                            break
                        prefix += ch
                    prefix = prefix[:2] or "?"
                    tally[prefix] = tally.get(prefix, 0) + 1
                    if prefix not in first_seen:
                        first_seen[prefix] = now - started
                    if listen_only or args.raw:
                        print(f"{stamp()}  <- {msg}")

            if use_tq:
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
            if args.wait_all:
                # A QUIET PERIOD, not a named last reply.
                #
                # Waiting for "the reply to the last command" has to know
                # what that command is, which does not survive --poll taking
                # an arbitrary string.  Silence does: the poll is answered
                # when the radio stops talking.  It is also the heuristic
                # worth considering for TR4W, where Icom CI-V and the binary
                # Yaesus answer in frames that do not map one-to-one onto
                # commands and so cannot be counted either.
                #
                # Against poll_buf, which is reset on every send.  The first
                # version tested "DT" in the CUMULATIVE buffer, where it is
                # present from the first burst onwards -- so it was true for
                # ever and --wait-all never waited at all.
                if poll_buf and (now - last_rx) > 0.03:
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

            # TRANSMIT WATCHDOG.  Independent of the flag detection AND of
            # the exit condition, both of which have been wrong in this file:
            # if the rig has been keyed longer than was asked for, keep
            # telling it to stop.  The run that prompted this sent one RX;
            # and then sat in the loop while the K3 stayed keyed.
            if (key_at is not None and last_flag == "1"
                    and now - key_at > args.key + 1.5
                    and now - last_unkey_retry > 1.0):
                sp.write(b"RX;" + bytes([13]))
                last_unkey_retry = now
                print(f"{stamp()}  -> RX; (watchdog retry)")

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
        if args.ai is not None and args.ai != 0:
            # Leave the rig as we found it.  A K3 left chattering at AI2 is a
            # surprise for whatever opens the port next -- TR4W included.
            try:
                sp.write(b"AI0;" + bytes([13]))
                time.sleep(0.2)
                print("auto-info restored to AI0")
            except Exception:
                print("*** WARNING: could not restore AI0 -- check the radio")

        if tally:
            print()
            print("messages received, by type:")
            for k in sorted(tally, key=lambda k: -tally[k]):
                print(f"    {k:<4} {tally[k]:6d}   first at {first_seen[k]:6.2f} s")

        ok = ensure_receive(sp)
        sp.close()
        if ok:
            print("port closed, rig CONFIRMED in receive")
        else:
            print("*** WARNING: could not confirm the rig returned to receive.")
            print("*** CHECK THE RADIO.  It may still be transmitting.")


if __name__ == "__main__":
    main()
