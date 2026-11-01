"""
County -> ARRL/RAC section, from arrl-sections-counties.json.

Pure lookup: no network, no globals beyond the table it loads once.  The table
maps a state or province either straight to its section ("OH": "OH") or, for
the nine whose sections split inside the state, county by county
("CA": {"Alameda": "EB", ...}).

THE RULE THAT MATTERS: a split state with a county we cannot match returns ''.
A wrong section in the TRMASTER Section slot is worse than none -- it is sent
as the operator's exchange -- so this never falls back to a "most likely"
section.  A whole-state entry returns its section whatever the county says.

QRZ spells counties as the operator typed them, so both sides are reduced to
one key before comparing: accents dropped, case folded, "Saint"/"Ste." folded
to "st", a trailing "County"/"Parish"/"Borough" removed, and every
non-alphanumeric dropped ("Miami-Dade" = "Miami Dade", "De Soto" = "DeSoto").
The key is checked for collisions inside each state when the table loads.
"""

import json
import os
import re
import unicodedata

HERE = os.path.dirname(os.path.abspath(__file__))
DEFAULT_TABLE = os.path.join(HERE, "arrl-sections-counties.json")

# QRZ and the table both append these to some names ("Orleans Parish",
# "Aleutians East Borough").  Longest first so "city and borough" wins over
# "borough".
TRAILING_WORDS = ("city and borough", "census area", "county", "parish",
                  "borough", "municipality")


def county_key(name):
   """The comparison key for one county spelling ('' if nothing is left)."""
   if not name:
      return ""
   text = unicodedata.normalize("NFKD", name)
   text = "".join(c for c in text if not unicodedata.combining(c)).lower()
   text = text.replace("&", " and ")
   text = re.sub(r"[.'`]", "", text)          # "St." "O'Brien" -> "st" "obrien"
   text = re.sub(r"[-,/]", " ", text)         # "Miami-Dade" -> "miami dade"
   text = re.sub(r"\s+", " ", text).strip()
   for word in TRAILING_WORDS:
      if text.endswith(" " + word):
         text = text[: -len(word) - 1].strip()
         break
   # Saint / Sainte / Ste are all "st" -- "St. Johns" and "Saint Johns" meet.
   text = re.sub(r"\b(saint|sainte|ste|st)\b", "st", text)
   return re.sub(r"[^a-z0-9]", "", text)


class CountySectionTable:
   """The loaded crosswalk.  Build one and reuse it."""

   def __init__(self, path=DEFAULT_TABLE):
      with open(path, encoding="utf-8-sig") as f:
         raw = json.load(f)
      self._whole = {}
      self._split = {}
      for state, value in raw.items():
         key = state.strip().upper()
         if isinstance(value, str):
            self._whole[key] = value
         else:
            by_key = {}
            for county, section in value.items():
               k = county_key(county)
               # Two counties folding to one key would make a lookup ambiguous;
               # fail at load rather than return whichever came last.
               if k in by_key and by_key[k] != section:
                  raise ValueError("%s: counties collide on key %r" % (state, k))
               by_key[k] = section
            self._split[key] = by_key

   def is_split(self, state):
      return state.strip().upper() in self._split

   def knows_state(self, state):
      s = state.strip().upper()
      return s in self._whole or s in self._split

   def section_for(self, state, county=""):
      """The section for a state/province (+ county), or '' if not known.

      '' also means "do not guess": a split state with no match."""
      if not state:
         return ""
      s = state.strip().upper()
      if s in self._whole:
         return self._whole[s]
      if s in self._split:
         return self._split[s].get(county_key(county), "")
      return ""
