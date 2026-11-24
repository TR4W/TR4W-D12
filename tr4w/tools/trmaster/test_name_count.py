"""
Tests for check_name_count.py (issue 309): the guard that fails a TRMASTER build
whose named-call count fell sharply.  Plain asserts; run:
   python -I test_name_count.py
No network.
"""

import os
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import check_name_count as cnc
import trmaster_codec as tc


def check(got, want, label):
   assert got == want, "%s: got %r, wanted %r" % (label, got, want)


def test_drop_rule():
   check(cnc.name_drop_too_large(26647, 64255, 0.10), True, "the 2026 incident")
   check(cnc.name_drop_too_large(60000, 64255, 0.10), False, "a small fall is fine")
   # 64255 * 0.9 is 57829.5, so no whole count sits exactly on the boundary there.
   check(cnc.name_drop_too_large(57830, 64255, 0.10), False, "just inside ten percent is fine")
   check(cnc.name_drop_too_large(57829, 64255, 0.10), True, "just over ten percent is not")
   # A previous count whose ninety percent is a whole number: 1000 -> 900 is exactly ten percent.
   check(cnc.name_drop_too_large(900, 1000, 0.10), False, "exactly ten percent is fine")
   check(cnc.name_drop_too_large(899, 1000, 0.10), True, "one record past ten percent is not")
   check(cnc.name_drop_too_large(70000, 64255, 0.10), False, "growth is fine")
   check(cnc.name_drop_too_large(0, 0, 0.10), False, "no previous names cannot drop")


def test_named_count():
   calls = {"K1AA": {"Name": "ED"}, "K1BB": {"Name": ""}, "K1CC": {}}
   check(cnc.named_count(calls), 1, "only records with a name count")


def test_main_with_files():
   with tempfile.TemporaryDirectory() as d:
      old = os.path.join(d, "old.dta")
      good = os.path.join(d, "good.dta")
      bad = os.path.join(d, "bad.dta")
      tc.write_dta(old, {"K1%s" % chr(65 + i): {"Name": "ED"} for i in range(10)})
      tc.write_dta(good, {"K1%s" % chr(65 + i): {"Name": "ED"} for i in range(10)})
      tc.write_dta(bad, {"K1%s" % chr(65 + i): ({"Name": "ED"} if i < 5 else {}) for i in range(10)})
      check(cnc.main([good, old]), 0, "same count passes")
      check(cnc.main([bad, old]), 1, "half the names fails")
      check(cnc.main([bad, os.path.join(d, "missing.dta")]), 0, "no previous file passes")


if __name__ == "__main__":
   test_drop_rule()
   test_named_count()
   test_main_with_files()
   print("test_name_count: all passed")
