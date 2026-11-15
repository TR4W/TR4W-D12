#!/usr/bin/env python3
"""
Guard for the monthly TRMASTER build (issue 309): fail when the number of
NAMED calls in a freshly built TRMASTER.DTA falls by more than a set fraction
against the previous file.

A QRZ error once ended the name step early and a DTA with 26,647 names instead
of about 64,255 was built, passed validation and exited 0.  Nothing compared
the name count with the last good file.  This does.

Read-only: it writes nothing.  Exit 0 when the count is acceptable (or there is
no previous file to compare with), 1 when it dropped by more than --max-drop,
2 when a file cannot be read.

Usage:
   python check_name_count.py NEW.DTA PREVIOUS.DTA [--max-drop 0.10]
"""

import argparse
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import trmaster_codec as tc


def named_count(calls):
   """How many records carry an operator name."""
   return sum(1 for f in calls.values() if f.get("Name"))


def name_drop_too_large(new_count, previous_count, max_drop):
   """True when new_count is below previous_count by more than max_drop (a
   fraction, 0.10 = ten percent).  A previous count of zero cannot drop."""
   if previous_count <= 0:
      return False
   return new_count < previous_count * (1.0 - max_drop)


def main(argv=None):
   ap = argparse.ArgumentParser(description="Fail when the name count of a TRMASTER.DTA drops sharply")
   ap.add_argument("new_dta")
   ap.add_argument("previous_dta")
   ap.add_argument("--max-drop", type=float, default=0.10,
                   help="largest allowed fall as a fraction of the previous count (default 0.10)")
   args = ap.parse_args(argv)

   if not os.path.exists(args.previous_dta):
      print("%s: no previous file, nothing to compare" % args.previous_dta)
      return 0
   try:
      new_count = named_count(tc.read_dta(args.new_dta)["calls"])
      previous_count = named_count(tc.read_dta(args.previous_dta)["calls"])
   except Exception as e:
      print("cannot read a DTA: %s" % e)
      return 2

   print("named calls: %d now, %d before (allowed fall %.0f%%)"
         % (new_count, previous_count, args.max_drop * 100))
   if name_drop_too_large(new_count, previous_count, args.max_drop):
      print("*** the name count fell by more than %.0f%%: %s was NOT accepted. "
            "Check the QRZ name step before deploying." % (args.max_drop * 100, args.new_dta))
      return 1
   return 0


if __name__ == "__main__":
   sys.exit(main())
