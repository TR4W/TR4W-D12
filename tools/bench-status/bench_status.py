#!/usr/bin/env python3
"""
Regenerate docs/RADIO_BENCH_STATUS.md -- the per-radio bench-test record.

WHY GENERATED.  The table is seeded from the RADIO REGISTRY, so a radio added
to the factory shows up automatically as "not tested" instead of being
forgotten.  The point of the document is to answer "what is still unverified?"
at a glance; that only works if nothing can be missing from it.

WHAT IS PRESERVED.  Everything a human typed -- the Tested / By / Notes cells
-- is read back out of the existing document and re-emitted.  Running this
script NEVER discards a test report.  Only the radio list itself is rebuilt.

Usage:  python bench_status.py          (rerunnable, no args)
"""

import os
import re
import sys

TR4W_ROOT = r"C:\tr4w-d12"
FACTORY_DIR = os.path.join(TR4W_ROOT, r"tr4w\src\radioFactory")
DOC = os.path.join(TR4W_ROOT, r"docs\RADIO_BENCH_STATUS.md")

# Registration forms, mirroring tr4w/build/Lint-RadioRegistry.ps1: the ctor is
# an anonymous function containing no string literals, so for the enum forms the
# FIRST quoted literal is the display name.
CALL = re.compile(
   r"Register(?:HamLibOnly)?Radio\s*\(\s*(?P<enum>[A-Za-z_][A-Za-z0-9_]*)\s*,(?P<rest>.*?)\)\s*;",
   re.S)


def strip_comments(text):
   """Blank { } and // comments so a documentation EXAMPLE is not read as a call."""
   text = re.sub(r"\{.*?\}", lambda m: "\n" * m.group(0).count("\n"), text, flags=re.S)
   text = re.sub(r"//[^\n]*", "", text)
   return text


def registered_radios():
   found = {}
   for name in sorted(os.listdir(FACTORY_DIR)):
      if not name.lower().endswith(".pas"):
         continue
      with open(os.path.join(FACTORY_DIR, name), encoding="utf-8", errors="replace") as f:
         body = strip_comments(f.read())
      for m in CALL.finditer(body):
         rest = m.group("rest")
         if "function" not in rest:          # a declaration/forward, not a call
            continue
         lits = re.findall(r"'([^']*)'", rest)
         if not lits:
            continue
         found[m.group("enum")] = (lits[0], name)
   return found


def existing_rows(path):
   """enum -> (tested, by, notes) from the current document, so reports survive."""
   rows = {}
   if not os.path.exists(path):
      return rows
   with open(path, encoding="utf-8") as f:
      for line in f:
         if not line.startswith("| "):
            continue
         cells = [c.strip() for c in line.strip().strip("|").split("|")]
         # FIVE columns: Radio | Enum | Tested | By | Notes.  This read < 6 in
         # the first version, so every row was skipped, `prior` came back empty
         # and a regeneration silently RESET every test report to '-'.  Caught
         # immediately (the seeded rows vanished), but it is exactly the failure
         # this function exists to prevent -- hence the explicit count and the
         # guard below.
         if len(cells) < 5 or cells[0] in ("Radio", "---"):
            continue
         # | Display | enum | Tested | By | Notes |  (unit column is derived)
         rows[cells[1]] = (cells[2], cells[3], cells[4])
   return rows


def main():
   radios = registered_radios()
   if len(radios) < 80:
      sys.exit("FATAL: only %d registrations parsed -- the table would be wrong. "
               "Fix the parser before regenerating." % len(radios))
   prior = existing_rows(DOC)
   # Refuse to run if a populated document parsed as empty -- that is the
   # signature of a broken row parser, and writing now would erase every test
   # report in it.  (Exactly what the len(cells) < 6 bug did on first run.)
   if os.path.exists(DOC):
      with open(DOC, encoding="utf-8") as f:
         row_lines = sum(1 for ln in f
                         if ln.startswith("| ") and not ln.startswith("| Radio")
                         and not ln.startswith("|---"))
      if row_lines and not prior:
         sys.exit("FATAL: %s has %d rows but none parsed -- the row parser is "
                  "broken and regenerating would erase every test report. "
                  "Fix existing_rows() first." % (DOC, row_lines))

   done = sum(1 for e in radios if prior.get(e, ("", "", ""))[0] not in ("", "-", "no"))
   L = []
   L.append("# Radio bench-test status")
   L.append("")
   L.append("Which factory radios have actually been tested against hardware, by whom,")
   L.append("and when.  **Generated** by `tools/bench-status/bench_status.py` from the")
   L.append("radio registry, so a newly added radio appears here automatically as")
   L.append("untested rather than being forgotten.  Re-running the script PRESERVES")
   L.append("every hand-written Tested / By / Notes cell -- it only rebuilds the radio")
   L.append("list.")
   L.append("")
   L.append("Fill in a row when a report comes back.  `Tested` is a date (YYYY-MM-DD);")
   L.append("leave it `-` for untested.  Put what was actually exercised in `Notes` --")
   L.append('"connects" and "CW, split and RIT verified" are very different claims.')
   L.append("")
   L.append("**Why this matters here:** the legacy radio path is kept only until bench")
   L.append("coverage makes its deletion safe (see `docs/tr4w-migration-strategy.md`).")
   L.append("This table is the gate on that decision.")
   L.append("")
   L.append("| Radio | Enum | Tested | By | Notes |")
   L.append("|---|---|---|---|---|")
   for enum in sorted(radios, key=lambda e: radios[e][0].lower()):
      display, _unit = radios[enum]
      tested, by, notes = prior.get(enum, ("-", "-", ""))
      L.append("| %s | %s | %s | %s | %s |" % (display, enum, tested, by, notes))
   L.append("")
   L.append("_%d registered radios; %d with a test report._" % (len(radios), done))
   L.append("")

   with open(DOC, "w", encoding="utf-8") as f:
      f.write("\n".join(L))
   print("%d radios, %d tested -> %s" % (len(radios), done, DOC))


if __name__ == "__main__":
   main()
