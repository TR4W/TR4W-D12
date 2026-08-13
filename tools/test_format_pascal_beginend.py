#!/usr/bin/env python3
"""
Self-test for tools/format_pascal_beginend.py.

For every fixture in tools/test_fixtures/beginend/:

   1. format <name>.in.pas and compare the resulting BYTES to
      <name>.expected.pas -- byte equality, so a lost CRLF or a dropped
      UTF-8 BOM is a failure, not a cosmetic difference;
   2. format the expected output again and require no change
      (idempotence);
   3. check the expected output still has the same token stream as the
      input, ignoring the begin/end tokens we are allowed to add -- a
      formatter that eats or invents code fails here;
   4. optionally (--lint) run tr4w/build/Lint-PascalBeginEnd.ps1 over the
      expected outputs.

Usage:  python tools/test_format_pascal_beginend.py [--lint] [--regen]
"""

import argparse
import glob
import os
import re
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import format_pascal_beginend as F   # noqa: E402

FIXTURES = os.path.join(HERE, "test_fixtures", "beginend")
LINT = os.path.abspath(os.path.join(HERE, "..", "tr4w", "build", "Lint-PascalBeginEnd.ps1"))

# Violations the lint still reports on a fully formatted fixture.  Listed with
# a reason rather than papered over -- two different situations:
#
#   comments   -- LINT BUG.  It strips comments line by line, so it cannot see
#                 a multi-line { } / (* *) block and flags the commented-out
#                 code inside it.  The formatter is right to leave it.
#   empty_body -- FORMATTER LIMITATION, deliberate.  `if B then ;` is an empty
#                 statement; there is nothing to wrap, and inventing a
#                 `begin end;` is a change of intent, not of layout.
KNOWN_RESIDUAL_LINT = {"comments.expected.pas": 2, "empty_body.expected.pas": 1}


token_signature = F.token_signature   # the formatter's own guard, reused as the oracle


def run_fixture(name, regen):
   inp = os.path.join(FIXTURES, name + ".in.pas")
   exp = os.path.join(FIXTURES, name + ".expected.pas")
   bom, text, codec = F.read_source(inp)
   got = F.format_text(text)

   if regen:
      F.write_source(exp, bom, got, codec)
      return True, "regenerated"

   if not os.path.exists(exp):
      return False, "missing %s" % os.path.basename(exp)

   with open(exp, "rb") as fh:
      want_bytes = fh.read()
   got_bytes = bom + got.encode(codec)
   if got_bytes != want_bytes:
      return False, "output differs from %s" % os.path.basename(exp)

   # idempotence
   again = F.format_text(got)
   if again != got:
      return False, "NOT idempotent -- a second pass changed the file"

   # nothing lost, nothing invented
   if token_signature(text) != token_signature(got):
      return False, "token stream changed (code was altered, not just re-laid-out)"

   return True, "ok"


def run_lint():
   files = sorted(glob.glob(os.path.join(FIXTURES, "*.expected.pas")))
   proc = subprocess.run(
      ["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", LINT] + files,
      capture_output=True, text=True)
   counts = {}
   for line in proc.stdout.splitlines():
      # "<path>:<line>: <message>" -- and <path> holds a drive-letter colon,
      # so match the line number rather than splitting on the first ':'.
      m = re.match(r"^(?P<file>.+?):(?P<line>\d+): ", line)
      if not m:
         continue
      base = os.path.basename(m.group("file"))
      counts[base] = counts.get(base, 0) + 1
   ok = True
   for base, n in sorted(counts.items()):
      allowed = KNOWN_RESIDUAL_LINT.get(base, 0)
      if n > allowed:
         print("  LINT FAIL %s: %d violation(s), %d allowed" % (base, n, allowed))
         ok = False
      else:
         print("  lint known-residual %s: %d" % (base, n))
   if ok:
      print("  lint: no unexpected violations in any formatted fixture")
   return ok


def main():
   ap = argparse.ArgumentParser()
   ap.add_argument("--lint", action="store_true", help="also run the PowerShell lint")
   ap.add_argument("--regen", action="store_true", help="rewrite the .expected.pas files")
   args = ap.parse_args()

   names = sorted(os.path.basename(p)[:-len(".in.pas")]
                  for p in glob.glob(os.path.join(FIXTURES, "*.in.pas")))
   if not names:
      print("no fixtures found in %s" % FIXTURES)
      return 1

   failures = 0
   for name in names:
      ok, msg = run_fixture(name, args.regen)
      print("%-14s %s %s" % (name, "PASS" if ok else "FAIL", msg))
      if not ok:
         failures += 1

   if args.lint and not args.regen:
      print("lint:")
      if not run_lint():
         failures += 1

   print("%d fixture(s), %d failure(s)" % (len(names), failures))
   return 1 if failures else 0


if __name__ == "__main__":
   sys.exit(main())
