"""
Check arrl-sections-counties.json before it is used or committed.

The file maps a US state or Canadian province to an ARRL/RAC section, either
directly ("OH": "OH") or county by county for the states whose sections split
inside the state ("CA": {"Alameda": "EB", ...}).  It rarely changes.

Checks, each a hard failure:
   - the file is valid JSON and every value is a section or a county table
   - every section named is one the program knows (target/dom/arrlsect.dom)
   - no county name is empty or carries stray whitespace

Run:  python check_county_sections.py
"""

import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
DATA = os.path.join(HERE, "arrl-sections-counties.json")
DOM = os.path.join(HERE, "..", "..", "target", "dom", "arrlsect.dom")


def known_sections():
   """Every spelling arrlsect.dom accepts: the names after '=' on each line.

   A line reads 'ENy = EN,ENY' or 'Ns = NS,^ Nova Scotia'; the text after a
   caret is a description, not a spelling."""
   result = set()
   with open(DOM, encoding="utf-8", errors="replace") as f:
      for line in f:
         m = re.match(r"^\s*\w+\s*=\s*(.*)$", line)
         if not m:
            continue
         for part in m.group(1).split("^")[0].split(","):
            part = part.strip().upper()
            if part:
               result.add(part)
   return result


def main():
   with open(DATA, encoding="utf-8-sig") as f:
      table = json.load(f)

   known = known_sections()
   problems = []
   used = set()

   for key, value in table.items():
      if isinstance(value, str):
         used.add(value)
      elif isinstance(value, dict):
         for county, section in value.items():
            if not county or county != county.strip():
               problems.append("%s: bad county name %r" % (key, county))
            if not isinstance(section, str):
               problems.append("%s/%s: section is not a string" % (key, county))
            else:
               used.add(section)
      else:
         problems.append("%s: neither a section nor a county table" % key)

   for section in sorted(used - known):
      problems.append("section %s is not in arrlsect.dom" % section)

   for problem in problems:
      print("FAIL", problem)
   print("%d states/provinces, %d distinct sections, %d problems" %
         (len(table), len(used), len(problems)))
   return 1 if problems else 0


if __name__ == "__main__":
   sys.exit(main())
