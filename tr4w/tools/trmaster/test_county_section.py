"""
Tests for county_section.py.  Plain asserts; run:  python -I test_county_section.py
"""

import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import county_section as cs

T = cs.CountySectionTable()


def check(got, want, label):
   assert got == want, "%s: got %r, wanted %r" % (label, got, want)


def test_each_split_state():
   # One real county per split state, taken from the table itself so the test
   # follows the data: the first county of each state must map to its section.
   import json
   with open(cs.DEFAULT_TABLE, encoding="utf-8-sig") as f:
      raw = json.load(f)
   split = [s for s, v in raw.items() if isinstance(v, dict)]
   check(sorted(split), ["CA", "FL", "MA", "NJ", "NY", "ON", "PA", "TX", "WA"],
         "the nine split states")
   for state in split:
      for county, section in raw[state].items():
         check(T.section_for(state, county), section, "%s %s" % (state, county))


def test_known_counties():
   check(T.section_for("CA", "Alameda"), "EB", "Alameda")
   check(T.section_for("CA", "Los Angeles"), "LAX", "Los Angeles")
   check(T.section_for("TX", "Harris"), "STX", "Harris")
   check(T.section_for("FL", "Miami-Dade"), "SFL", "Miami-Dade")
   check(T.section_for("NY", "Kings"), "NLI", "Kings")
   check(T.section_for("WA", "King"), "WWA", "King")


def test_whole_state_ignores_county():
   check(T.section_for("OH", ""), "OH", "Ohio, no county")
   check(T.section_for("OH", "Franklin"), "OH", "Ohio, county")
   check(T.section_for("OH", "Nonsense"), "OH", "Ohio, a county that does not exist")
   check(T.section_for("MD", "Howard"), "MDC", "Maryland is MDC")
   check(T.section_for("HI", ""), "PAC", "Hawaii is PAC")
   check(T.section_for("YT", ""), "TER", "Yukon")


def test_normalisation():
   check(T.section_for("TX", "HARRIS"), "STX", "upper case")
   check(T.section_for("TX", "harris county"), "STX", "county suffix")
   check(T.section_for("TX", "Harris County"), "STX", "county suffix, cased")
   check(T.section_for("FL", "Saint Johns"), T.section_for("FL", "St. Johns"),
         "Saint = St.")
   check(T.section_for("FL", "St Lucie"), T.section_for("FL", "St. Lucie"),
         "St without a period")
   check(T.section_for("FL", "Miami Dade"), T.section_for("FL", "Miami-Dade"),
         "hyphen")
   check(T.section_for("FL", "Miami-Dade County"), T.section_for("FL", "Miami-Dade"),
         "hyphen and suffix")
   check(T.section_for("NY", "St Lawrence"), T.section_for("NY", "St. Lawrence"),
         "NY St Lawrence")
   check(T.section_for("TX", "De Witt"), T.section_for("TX", "DeWitt"),
         "De Witt = DeWitt")
   check(T.section_for("TX", "  Harris  "), "STX", "surrounding spaces")
   check(T.section_for(" tx ", "Harris"), "STX", "state spacing and case")
   check(cs.county_key("Orleans Parish"), cs.county_key("Orleans"), "parish")
   check(cs.county_key("Aleutians East Borough"), cs.county_key("Aleutians East"),
         "borough")
   check(cs.county_key("Curaçao"), "curacao", "accents")
   check(cs.county_key("O'Brien"), "obrien", "apostrophe")
   check(cs.county_key("Smith & Jones"), "smithandjones", "ampersand")


def test_unmatched_county_in_a_split_state_is_blank():
   check(T.section_for("TX", "Narnia"), "", "no such county")
   check(T.section_for("TX", ""), "", "split state, no county")
   check(T.section_for("CA", ""), "", "California, no county")
   check(T.section_for("ON", "Nowhere"), "", "Ontario, unmatched")


def test_non_us_or_unknown():
   check(T.section_for("", "Harris"), "", "no state")
   check(T.section_for("XX", "Harris"), "", "unknown state")
   check(T.section_for("DX", ""), "", "DX is not a state")
   check(T.knows_state("TX"), True, "TX known")
   check(T.knows_state("XX"), False, "XX unknown")
   check(T.is_split("TX"), True, "TX split")
   check(T.is_split("OH"), False, "OH not split")


def test_ontario_names():
   check(T.section_for("ON", "Toronto"), "GH", "Toronto")
   check(T.section_for("ON", "Stormont, Dundas and Glengarry"), "ONE",
         "Stormont, Dundas and Glengarry")
   check(T.section_for("ON", "Chatham Kent"), T.section_for("ON", "Chatham-Kent"),
         "Chatham-Kent")


def main():
   tests = [(n, f) for n, f in sorted(globals().items())
            if n.startswith("test_") and callable(f)]
   failed = 0
   for name, fn in tests:
      try:
         fn()
         print("ok  ", name)
      except AssertionError as e:
         failed += 1
         print("FAIL", name, "-", e)
   print("%d tests, %d failed" % (len(tests), failed))
   return 1 if failed else 0


if __name__ == "__main__":
   sys.exit(main())
