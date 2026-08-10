#!/usr/bin/env python3
"""
Offline tests for k3watch's parsing and pacing.

WHY THESE EXIST.  Three successive versions of k3watch went to a live radio
with bugs in them -- a spanning response parser, a duplicated RX;, and a
--wait-all that silently did not wait.  Every one was found by NY4I running
it against his K3 and reading nonsense in the output.  That is an expensive
way to find a bug in a fifty-line loop, and it puts a transmitter in the
path of my mistakes.

A fake serial port answers like a K3, so the logic can be wrong here instead.

Run:  python test_k3watch.py
"""

import re
import sys

import k3watch


IF_RX = "IF00014074000     -000000 0006000001 ;"
IF_TX = "IF00014074000     -000000 0016000001 ;"


def check(name, got, want):
    ok = got == want
    print(f"  {'PASS' if ok else 'FAIL'}  {name}")
    if not ok:
        print(f"        got  {got!r}")
        print(f"        want {want!r}")
    return ok


def test_find_last_if():
    print("find_last_if")
    ok = True
    # A burst reply: IF, then FB, then MD$, then DT$.  The parser must return
    # the IF response ALONE -- the bug it had was spanning to the DT$ ';'.
    burst = IF_TX + "FB00014017200;MD$6;DT$0;"
    ok &= check("burst: returns only the IF response",
                k3watch.find_last_if(burst), IF_TX)
    ok &= check("burst: T/R read from it", k3watch.tr_flag(k3watch.find_last_if(burst)), "1")
    ok &= check("receive variant", k3watch.tr_flag(k3watch.find_last_if(IF_RX + "FB1;")), "0")
    # A partial response must not be accepted as a whole one.
    ok &= check("truncated is rejected", k3watch.find_last_if("IF000140740"), None)
    # The LAST complete response wins when several are buffered.
    ok &= check("takes the most recent", k3watch.find_last_if(IF_TX + IF_RX), IF_RX)
    ok &= check("nothing in an empty buffer", k3watch.find_last_if(""), None)
    return ok


def test_find_last_tq():
    print("find_last_tq")
    ok = True
    ok &= check("TQ1", k3watch.tr_flag(k3watch.find_last_tq("TQ1;")), "1")
    ok &= check("TQ0", k3watch.tr_flag(k3watch.find_last_tq("junk;TQ0;")), "0")
    ok &= check("partial TQ rejected", k3watch.find_last_tq("TQ0"), None)
    return ok


def test_dt_reply():
    print("DT_REPLY (what satisfies --wait-all)")
    ok = True
    # THE BUG THIS PINS.  --wait-all tested `"DT" in buf` against the
    # CUMULATIVE buffer, where "DT" is present from the first burst onwards.
    # It was therefore true for ever and --wait-all never waited -- it
    # measured the same thing as plain --burst, and I reported the result as
    # if it meant something.
    ok &= check("a complete DT reply matches",
                bool(k3watch.DT_REPLY.search("DT$0;")), True)
    ok &= check("the ECHOED COMMAND does not match",
                bool(k3watch.DT_REPLY.search("DT$;")), False)
    ok &= check("a partial reply does not match",
                bool(k3watch.DT_REPLY.search("DT0")), False)
    ok &= check("an IF reply alone does not satisfy the burst",
                bool(k3watch.DT_REPLY.search(IF_TX)), False)
    ok &= check("IF+FB+MD but no DT does not satisfy it",
                bool(k3watch.DT_REPLY.search(IF_TX + "FB00014017200;MD$6;")), False)
    ok &= check("the full burst does",
                bool(k3watch.DT_REPLY.search(IF_TX + "FB00014017200;MD$6;DT$0;")), True)
    return ok


def main():
    print()
    results = [test_find_last_if(), test_find_last_tq(), test_dt_reply()]
    print()
    if all(results):
        print("all tests passed")
        return 0
    print("FAILURES -- do not run this against a radio")
    return 1


if __name__ == "__main__":
    sys.exit(main())
