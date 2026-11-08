#!/usr/bin/env python3
"""
Read-only scan of a TRMASTER.DTA for operator names that fail the builder's
name rule (trmaster_build.valid_name): letters, internal single space / hyphen /
apostrophe, at least 2 letters, no digits or other punctuation.

Never writes anything.  Prints each offending call and name, then a count.
Exit 0 if every name is valid, 1 if any is not (so it can gate a deploy).

Usage:
   python check_dta_names.py [TRMASTER.DTA] [--limit N]

Default file: ../../target/TRMASTER.DTA.  --limit caps the lines printed (the
count is always the full total); 0 prints them all.
"""

import argparse
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import trmaster_build as tb
import trmaster_codec as tc


def bad_names(calls):
   """[(call, name)] for every record whose Name fails valid_name, sorted."""
   return sorted((c, f["Name"]) for c, f in calls.items()
                 if f.get("Name") and not tb.valid_name(f["Name"]))


def main(argv=None):
   ap = argparse.ArgumentParser(description="Scan a .dta for invalid operator names")
   ap.add_argument("dta", nargs="?",
                   default=os.path.join(HERE, "..", "..", "target", "TRMASTER.DTA"))
   ap.add_argument("--limit", type=int, default=50,
                   help="lines to print (0 = all); the count is always complete")
   args = ap.parse_args(argv)

   calls = tc.read_dta(args.dta)["calls"]
   bad = bad_names(calls)
   named = sum(1 for f in calls.values() if f.get("Name"))
   shown = bad if args.limit == 0 else bad[:args.limit]
   for call, name in shown:
      print(f"{call:<12} {name!r}")
   if len(shown) < len(bad):
      print(f"... {len(bad) - len(shown)} more (use --limit 0)")
   print(f"{args.dta}: {len(calls)} calls, {named} named, {len(bad)} invalid names")
   return 1 if bad else 0


if __name__ == "__main__":
   sys.exit(main())
