"""
Tests for qrz_geo.py, the geo cache-freshness rule, load_geo_csv and the
geo layer of merge().  Plain asserts; run:  python -I test_qrz_geo.py
No network.
"""

import json
import os
import sys
import tempfile
import time

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import county_section as cs
import qrz_geo as qg
import trmaster_build as tb
import trmaster_codec as tc
import trmaster_names_qrz as nq

TABLE = cs.CountySectionTable()


def check(got, want, label):
   assert got == want, "%s: got %r, wanted %r" % (label, got, want)


def test_normalize_grid():
   check(qg.normalize_grid("el88"), "EL88", "four, lower case")
   check(qg.normalize_grid("EL88AB"), "EL88ab", "six, upper case")
   check(qg.normalize_grid(" el88ab "), "EL88ab", "six, spaces")
   check(qg.normalize_grid("EL88ab12"), "EL88ab", "eight is cut to six")
   check(qg.normalize_grid("EL8"), "", "too short")
   check(qg.normalize_grid("ZZ99"), "", "field letters past R")
   check(qg.normalize_grid("EL88zz"), "", "subsquare past X")
   check(qg.normalize_grid(""), "", "empty")
   check(qg.normalize_grid(None), "", "None")
   check(len(qg.normalize_grid("EL88ab12")), 6, "never longer than six")


def test_grid_from_latlon():
   check(qg.grid_from_latlon("28.5", "-82.5"), "EL88", "Florida")
   check(qg.grid_from_latlon("51.5", "-0.1"), "IO91", "London")
   check(qg.grid_from_latlon("-33.9", "151.2"), "QF56", "Sydney")
   check(qg.grid_from_latlon("", ""), "", "blank")
   check(qg.grid_from_latlon("x", "y"), "", "not numbers")
   check(qg.grid_from_latlon("95", "0"), "", "latitude out of range")


def test_geo_from_entry():
   e = {"grid": "EL88ab", "state": "FL", "county": "Hillsborough",
        "country": "United States"}
   grid, sec, src = qg.geo_from_entry(e, TABLE)
   check((grid, sec, src), ("EL88ab", "WCF", "qrz"), "Florida")

   e = {"grid": "", "lat": "28.5", "lon": "-82.5", "state": "OH",
        "country": "United States"}
   check(qg.geo_from_entry(e, TABLE), ("EL88", "OH", "latlon"), "latlon fallback")

   # a DX page with a state-looking value must not get a US section
   e = {"grid": "GG66", "state": "CA", "county": "Los Angeles",
        "country": "Brazil"}
   check(qg.geo_from_entry(e, TABLE), ("GG66", "", "qrz"), "non-US state")

   # split state, county QRZ does not give: no guess
   e = {"grid": "EM12", "state": "TX", "county": "", "country": "United States"}
   check(qg.geo_from_entry(e, TABLE), ("EM12", "", "qrz"), "split, no county")

   check(qg.geo_from_entry({}, TABLE), ("", "", ""), "empty entry")


def _client(cache, geo_days=365):
   fd, path = tempfile.mkstemp(suffix=".json")
   os.close(fd)
   with open(path, "w", encoding="utf-8") as f:
      json.dump(cache, f)
   c = nq.QRZNameClient("u", "p", path, geo_max_age_days=geo_days)
   return c, path


def test_cache_freshness_rule():
   now = int(time.time())
   cache = {
      "OLD": {"name": "BOB", "ts": now},                      # pre-geo entry
      "NEW": {"name": "ANN", "ts": now, "geo_ts": now},
      "AGED": {"name": "SAM", "ts": now, "geo_ts": now - 400 * 86400},
   }
   c, path = _client(cache)
   try:
      check(c.needs_lookup("OLD"), False, "pre-geo entry, names only")
      check(c.needs_lookup("OLD", True), True, "pre-geo entry, geo wanted")
      check(c.needs_lookup("NEW", True), False, "fresh geo")
      check(c.needs_lookup("AGED"), False, "aged geo, names only")
      check(c.needs_lookup("AGED", True), True, "aged geo, geo wanted")
      check(c.needs_lookup("UNKNOWN"), True, "not cached")
   finally:
      os.remove(path)
   c, path = _client(cache, geo_days=0)
   try:
      check(c.needs_lookup("AGED", True), False, "0 = geo never expires")
   finally:
      os.remove(path)


def test_load_geo_csv():
   fd, path = tempfile.mkstemp(suffix=".csv")
   os.close(fd)
   rows = ["W1AW,FN31,CT", "K1ABC,EL88ab,WCF", "K2LONG,EL88abcd,WCF",
           "K3SEC,EL88,TOOLONGSECTION", "K4BAD,ZZ99,", "bad call,EL88,CT",
           "K5GRID,EL88,", "K6SEC,,STX"]
   with open(path, "w", encoding="utf-8") as f:
      f.write("\n".join(rows) + "\n")
   try:
      geo = tb.load_geo_csv(path)
   finally:
      os.remove(path)
   check(geo["W1AW"], {"Grid": "FN31", "Section": "CT"}, "plain")
   check(geo["K1ABC"], {"Grid": "EL88ab", "Section": "WCF"}, "six")
   check("Grid" in geo.get("K2LONG", {}), False, "eight-char grid refused")
   check(geo["K2LONG"], {"Section": "WCF"}, "section kept when grid refused")
   check(geo["K3SEC"], {"Grid": "EL88"}, "long section refused")
   check("K4BAD" in geo, False, "nothing valid, no row")
   check(geo["K5GRID"], {"Grid": "EL88"}, "grid only")
   check(geo["K6SEC"], {"Section": "STX"}, "section only")
   check(tb.load_geo_csv(None), {}, "no path")


def test_merge_fills_empty_slots_only():
   existing = {"W1AW": {"Name": "HIRAM", "Grid": "FN31pr"},
               "K1ABC": {"Name": "ANN"}}
   geo = {"W1AW": {"Grid": "FN31", "Section": "CT"},
          "K1ABC": {"Grid": "EL88", "Section": "WCF"},
          "N0NEW": {"Grid": "EM12"}}
   out = tb.merge({"N0NEW"}, existing, {}, {}, {}, {}, {}, geo)
   check(out["W1AW"]["Grid"], "FN31pr", "curated grid never overwritten")
   check(out["W1AW"]["Section"], "CT", "empty section filled")
   check(out["K1ABC"], {"Name": "ANN", "Grid": "EL88", "Section": "WCF"},
         "both filled")
   check(out["N0NEW"], {"Grid": "EM12"}, "new call gets geo")
   plain = tb.merge({"N0NEW"}, {}, {}, {}, {}, {}, {})
   check(plain["N0NEW"], {}, "no geo argument, nothing added")


def test_codec_round_trips_grid_and_section():
   calls = {"W1AW": {"Name": "HIRAM", "Grid": "FN31pr", "Section": "CT"},
            "K1ABC": {"Name": "ANN"},
            "N0X": {"Grid": "EM12", "Section": "STX", "User1": "123"}}
   fd, path = tempfile.mkstemp(suffix=".dta")
   os.close(fd)
   try:
      tc.write_dta(path, calls)
      back = tc.read_dta(path)["calls"]
   finally:
      os.remove(path)
   check(back, calls, "round trip")


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
