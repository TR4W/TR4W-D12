"""
Tests for trmaster_names_qrz.main(): a QRZ failure ends the live lookups, never
the run, so cached names after the failing call are still emitted.
Plain asserts; run:  python -I test_qrz_names.py     No network.
"""

import csv
import os
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import trmaster_names_qrz as nq


def check(got, want, label):
   assert got == want, "%s: got %r, wanted %r" % (label, got, want)


class FakeClient:
   """A cache of three kinds of call: fresh, stale and absent."""

   def __init__(self, *args, **kwargs):
      self._cache = {
         "AA1AA": {"name": "ANN", "ts": 1},      # fresh
         "CC3CC": {"name": "CAL", "ts": 1},      # fresh
         "DD4DD": {"name": "DAN", "ts": 1},      # stale
      }
      self.live_calls = []

   def needs_lookup(self, call, want_geo=False):
      return call not in ("AA1AA", "CC3CC")

   def cached(self, call):
      return self._cache.get(call)

   def lookup(self, call, want_geo=False):
      self.live_calls.append(call)
      raise RuntimeError("QRZ session error: Username record failure")

   def save(self):
      pass


def run(cands, extra_args):
   work = tempfile.mkdtemp()
   calls = os.path.join(work, "calls.txt")
   out = os.path.join(work, "names.csv")
   with open(calls, "w") as f:
      f.write("\n".join(cands) + "\n")
   nq.QRZNameClient = FakeClient
   nq.read_credentials = lambda path: ("user", "password")
   made = []
   original = nq.QRZNameClient
   nq.QRZNameClient = lambda *a, **k: made.append(original(*a, **k)) or made[-1]
   nq.main(["--calls-file", calls, "--out", out] + extra_args)
   with open(out, newline="", encoding="utf-8") as f:
      rows = [tuple(r) for r in csv.reader(f)]
   return rows, made[0]


def test_failure_keeps_the_names_after_it():
   rows, client = run(["AA1AA", "BB2BB", "CC3CC", "DD4DD", "EE5EE"], [])
   check(rows, [("AA1AA", "ANN"), ("CC3CC", "CAL"), ("DD4DD", "DAN")],
         "every cached name is emitted, before and after the failing call")
   check(client.live_calls, ["BB2BB"], "live lookups stop at the first failure")


def test_cache_only_never_queries_and_uses_stale():
   rows, client = run(["AA1AA", "BB2BB", "DD4DD"], ["--cache-only"])
   check(rows, [("AA1AA", "ANN"), ("DD4DD", "DAN")], "stale cached name is used")
   check(client.live_calls, [], "cache-only makes no live call")


if __name__ == "__main__":
   test_failure_keeps_the_names_after_it()
   test_cache_only_never_queries_and_uses_stale()
   print("test_qrz_names: 2 passed")
