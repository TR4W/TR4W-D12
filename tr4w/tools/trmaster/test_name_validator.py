"""
Tests for the operator-name validator in trmaster_build.py (issue 239):
valid_name, the per-source loaders, the previous-DTA clean-up and fall-through
to a lower-priority name.  Plain asserts; run:  python -I test_name_validator.py
No network.
"""

import os
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import check_dta_names as cdn
import trmaster_build as tb
import trmaster_codec as tc


def check(got, want, label):
   assert got == want, "%s: got %r, wanted %r" % (label, got, want)


def write_file(dirname, name, text):
   path = os.path.join(dirname, name)
   with open(path, "w", encoding="utf-8", newline="") as f:
      f.write(text)
   return path


def test_junk_rejected():
   for junk in ("2A", "QRA:", "NIGHTOWL()", "(YU)", "KARL-", "-KARL", "U",
                "", "A  B", "A--B", "78TH", "K4NHW1", "\"WADE\"", "JÜRGEN",
                "mary", "-", "'"):
      check(tb.valid_name(junk), False, "junk %r" % junk)


def test_ordinary_names_kept():
   for ok in ("ED", "MARY-ANN", "O'BRIEN", "JEAN PIERRE", "TOM", "AL"):
      check(tb.valid_name(ok), True, "ordinary %r" % ok)


def test_accept_name_returns_name_or_none():
   check(tb.accept_name("K1ABC", "ED", "test"), "ED", "valid passes through")
   check(tb.accept_name("PS2CIA", "2A", "test"), None, "junk gives None")


def test_loaders_drop_junk_and_keep_the_rest():
   with tempfile.TemporaryDirectory() as d:
      cw = write_file(d, "cwops.csv",
                      "x,y,K1AAA,101,ED\nx,y,K1BBB,102,QRA:\nx,y,K1CCC,103,MARY-ANN\n")
      got = tb.parse_cwops_csv(cw)
      check(got["K1AAA"], {"User1": "101", "Name": "ED"}, "cwops good")
      # the member keeps the number; only the name is dropped
      check(got["K1BBB"], {"User1": "102"}, "cwops junk name dropped, number kept")
      check(got["K1CCC"]["Name"], "MARY-ANN", "cwops hyphen")

      foc = write_file(d, "foc.csv", "K1DDD,7,NIGHTOWL()\nK1EEE,8,JEAN PIERRE\n")
      got = tb.parse_simple_csv(foc, "FOC")
      check(got["K1DDD"], {"FOC": "7"}, "foc junk name dropped")
      check(got["K1EEE"], {"FOC": "8", "Name": "JEAN PIERRE"}, "foc good")

      names = write_file(d, "names.csv", "PS2CIA,2A\nK1FFF,O'BRIEN\n")
      got = tb.load_names_csv(names)
      check(got, {"K1FFF": "O'BRIEN"}, "names csv")


def test_history_junk_falls_to_next_file():
   with tempfile.TemporaryDirectory() as d:
      a = write_file(d, "a.txt", "# comment\nK1AAA,(YU)\nK1BBB,TOM\n")
      b = write_file(d, "b.txt", "K1AAA,YURI\nK1BBB,THOMAS\n")
      got = tb.load_history_names([a, b])
      check(got["K1AAA"], "YURI", "junk in the first file, good in the second")
      check(got["K1BBB"], "TOM", "first file still wins when valid")


def test_merge_falls_through_to_lower_priority_name():
   # CWops carries junk for W1AW: its number is kept, its name is not, and the
   # history name below it is what is written.
   with tempfile.TemporaryDirectory() as d:
      cw = write_file(d, "cwops.csv", "x,y,W1AW,55,2A\n")
      cwops = tb.parse_cwops_csv(cw)
   history = {"W1AW": "HIRAM"}
   merged = tb.merge({"W1AW"}, {}, history, cwops, {}, {}, {})
   check(merged["W1AW"], {"Name": "HIRAM", "User1": "55"}, "history survives junk CWops")


def test_carried_forward_junk_dropped_then_qrz_fills():
   with tempfile.TemporaryDirectory() as d:
      old = os.path.join(d, "old.dta")
      tc.write_dta(old, {"PS2CIA": {"Name": "2A"}, "K1ABC": {"Name": "ED"},
                         "K1XYZ": {"Name": "QRA:", "User1": "9"}})
      existing = tb.load_existing(old)
      check("Name" in existing["PS2CIA"], False, "junk removed from the old record")
      check(existing["K1ABC"]["Name"], "ED", "good old name kept")
      check(existing["K1XYZ"], {"User1": "9"}, "membership kept, junk name gone")
      merged = tb.merge({"PS2CIA", "K1ABC", "K1XYZ"}, existing, {}, {}, {}, {},
                        {"K1XYZ": "XAVIER"})
      check(merged["PS2CIA"].get("Name"), None, "no name beats a junk name")
      check(merged["K1XYZ"]["Name"], "XAVIER", "lower-priority QRZ name fills the gap")


def test_scan_finds_bad_names():
   with tempfile.TemporaryDirectory() as d:
      p = os.path.join(d, "t.dta")
      tc.write_dta(p, {"PS2CIA": {"Name": "2A"}, "K1ABC": {"Name": "ED"},
                       "K1BBB": {}, "K1CCC": {"Name": "(YU)"}})
      calls = tc.read_dta(p)["calls"]
      check(cdn.bad_names(calls), [("K1CCC", "(YU)"), ("PS2CIA", "2A")], "scan")
      check(cdn.main([p, "--limit", "0"]), 1, "exit code with bad names")


def main():
   tests = [(n, f) for n, f in sorted(globals().items())
            if n.startswith("test_") and callable(f)]
   for name, fn in tests:
      fn()
      print("ok  " + name)
   print("%d tests passed" % len(tests))


if __name__ == "__main__":
   main()
