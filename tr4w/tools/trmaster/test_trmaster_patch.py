"""
Tests for trmaster_patch.py: patch a copy of the contest-matrix fixture
(test/contest-matrix/MATRIX-TRMASTER.DTA, 9 calls) and a tiny file built with
the repo's own writer, then re-read it with trmaster_codec.read_dta.
Plain asserts; run:  python -I test_trmaster_patch.py     No network.
"""

import hashlib
import io
import os
import sys
import tempfile
from contextlib import redirect_stderr, redirect_stdout

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import trmaster_codec as tc
import trmaster_patch as tp

FIXTURE = os.path.join(HERE, "..", "..", "test", "contest-matrix", "MATRIX-TRMASTER.DTA")


def check(got, want, label):
   assert got == want, "%s: got %r, wanted %r" % (label, got, want)


def sha(path):
   with open(path, "rb") as handle:
      return hashlib.sha256(handle.read()).hexdigest()


def run(argv):
   """Returns (exit code, stdout, stderr)."""
   out = io.StringIO()
   err = io.StringIO()
   with redirect_stdout(out), redirect_stderr(err):
      code = tp.main(argv)
   return code, out.getvalue(), err.getvalue()


def copies_of(path, call):
   """Every stored copy of a call's record, as (bucket index, fields)."""
   with open(path, "rb") as handle:
      buckets = tp.read_buckets(handle.read())
   found = []
   for k, bucket in enumerate(buckets):
      i = 0
      while i < len(bucket):
         got, fields, i = tc._decode_record(bucket, i)
         if got == call:
            found.append((k, fields))
   return found


def patch(d, call, *options):
   out = os.path.join(d, "out.dta")
   code, stdout, stderr = run([FIXTURE, out, "--call", call] + list(options))
   check(code, 0, "patch exit (%s)" % stderr)
   return out


def test_fixture_is_the_shape_we_expect():
   info = tc.read_dta(FIXTURE)
   check(len(info["calls"]), 9, "fixture calls")
   check(info["calls"]["K4ABC"]["Name"], "BOB", "K4ABC name")
   # K4ABC lives in several buckets, so the multi-copy path is exercised
   assert len(info["buckets_of"]["K4ABC"]) > 1


def test_longer_name_changes_only_that_call():
   before = tc.read_dta(FIXTURE)
   with tempfile.TemporaryDirectory() as d:
      out = patch(d, "K4ABC", "--name", "ROBERTO")
      after = tc.read_dta(out)
      check(after["calls"]["K4ABC"]["Name"], "ROBERTO", "patched name")
      want = dict(before["calls"]["K4ABC"])
      want["Name"] = "ROBERTO"
      check(after["calls"]["K4ABC"], want, "patched call keeps its other fields")
      for call, fields in before["calls"].items():
         if call != "K4ABC":
            check(after["calls"][call], fields, "untouched call " + call)
      check(set(after["calls"]), set(before["calls"]), "call set")
      check(after["buckets_of"], before["buckets_of"], "bucket membership")
      check(after["n_records"], before["n_records"], "record count")
      check(after["end_offset"], after["file_size"], "end offset is the file size")
      assert after["file_size"] > before["file_size"]


def test_every_bucket_copy_is_replaced():
   with tempfile.TemporaryDirectory() as d:
      out = patch(d, "K4ABC", "--name", "ROBERTO")
      copies = copies_of(out, "K4ABC")
      assert len(copies) > 1
      for k, fields in copies:
         check(fields["Name"], "ROBERTO", "copy in bucket %d" % k)


def test_shorter_name_and_input_not_modified():
   digest = sha(FIXTURE)
   before = tc.read_dta(FIXTURE)
   with tempfile.TemporaryDirectory() as d:
      out = patch(d, "K9ABC", "--name", "Z")
      after = tc.read_dta(out)
      check(after["calls"]["K9ABC"]["Name"], "Z", "short name")
      assert after["file_size"] < before["file_size"]
      check(after["end_offset"], after["file_size"], "end offset")
   check(sha(FIXTURE), digest, "input file unchanged")


def test_untouched_buckets_are_byte_identical():
   with open(FIXTURE, "rb") as handle:
      old = tp.read_buckets(handle.read())
   with tempfile.TemporaryDirectory() as d:
      out = patch(d, "DL1ABC", "--name", "HANSJOERG")
      with open(out, "rb") as handle:
         new = tp.read_buckets(handle.read())
   touched = [k for k in range(len(old)) if old[k] != new[k]]
   expected = sorted(x * 37 + y for (x, y) in tc.bucket_pairs("DL1ABC"))
   check(touched, expected, "only DL1ABC's buckets differ")


def test_add_change_and_remove_other_fields():
   with tempfile.TemporaryDirectory() as d:
      out = patch(d, "ON4ABC", "--section", "BEL", "--check", "77", "--hits", "5")
      fields = tc.read_dta(out)["calls"]["ON4ABC"]
      check(fields["Section"], "BEL", "section added")
      check(fields["Check"], "77", "check added")
      check(fields["Hits"], 5, "binary hits")
      check(fields["Name"], "JEAN", "name kept")
      second = os.path.join(d, "second.dta")
      code, _, err = run([out, second, "--call", "on4abc", "--name", "", "--section", "WAL"])
      check(code, 0, "second patch " + err)
      fields = tc.read_dta(second)["calls"]["ON4ABC"]
      assert "Name" not in fields
      check(fields["Section"], "WAL", "section changed; call matched case-insensitively")


def test_unknown_call_refused_and_nothing_written():
   with tempfile.TemporaryDirectory() as d:
      out = os.path.join(d, "out.dta")
      code, _, err = run([FIXTURE, out, "--call", "N0SUCH", "--name", "X"])
      check(code, 1, "exit code")
      assert "not in the file" in err
      assert not os.path.exists(out)
      code, _, err = run([FIXTURE, "--list-call", "N0SUCH"])
      check(code, 1, "list unknown exit")


def test_refuses_to_overwrite_the_input():
   with tempfile.TemporaryDirectory() as d:
      copy = os.path.join(d, "copy.dta")
      with open(FIXTURE, "rb") as src, open(copy, "wb") as dst:
         dst.write(src.read())
      digest = sha(copy)
      code, _, err = run([copy, copy, "--call", "K4ABC", "--name", "X"])
      check(code, 2, "exit code")
      check(sha(copy), digest, "file unchanged")


def test_bad_values_rejected():
   with tempfile.TemporaryDirectory() as d:
      out = os.path.join(d, "out.dta")
      check(run([FIXTURE, out, "--call", "K4ABC", "--name", "A\x01B"])[0], 2, "control char")
      check(run([FIXTURE, out, "--call", "K4ABC", "--hits", "300"])[0], 2, "hits range")
      check(run([FIXTURE, out, "--call", "K4ABC", "--name", "中"])[0], 2, "non latin-1")
      check(run([FIXTURE, out, "--call", "K4ABC"])[0], 2, "no field given")
      assert not os.path.exists(out)


def test_list_call_prints_fields():
   code, out, _ = run([FIXTURE, "--list-call", "k4abc"])
   check(code, 0, "exit")
   assert "K4ABC" in out and "BOB" in out and "NFL" in out, out


def test_tiny_file_from_the_repos_own_writer():
   calls = {"N4AF": {"Name": "HOWARD", "Section": "GA"},
            "K1ZZZ": {"Name": "AL"},
            "W1AW": {}}
   with tempfile.TemporaryDirectory() as d:
      src = os.path.join(d, "tiny.dta")
      tc.write_dta(src, calls)
      out = os.path.join(d, "patched.dta")
      code, _, err = run([src, out, "--call", "N4AF", "--name", "Howie"])
      check(code, 0, "exit " + err)
      after = tc.read_dta(out)
      check(after["calls"]["N4AF"], {"Name": "Howie", "Section": "GA"}, "N4AF")
      check(after["calls"]["K1ZZZ"], {"Name": "AL"}, "K1ZZZ")
      check(set(after["calls"]), {"N4AF", "K1ZZZ", "W1AW"}, "call set")
      check(after["end_offset"], after["file_size"], "end offset")


def main():
   tests = [(n, f) for n, f in sorted(globals().items())
            if n.startswith("test_") and callable(f)]
   for name, fn in tests:
      fn()
      print("ok  " + name)
   print("%d tests passed" % len(tests))


if __name__ == "__main__":
   main()
