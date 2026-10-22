"""Tests for parse_udc.py.

Run:  python tools/udc/test_parse_udc.py        (exit 0 = pass)

The fixtures are written here, as text, and encoded at run time -- a UTF-16
file and a ZIP are binary, and a binary fixture in the repository cannot be
read in review.  Nothing is downloaded and nothing is read from the cache.
"""

import json
import os
import shutil
import sys
import tempfile
import unittest
import zipfile

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import parse_udc  # noqa: E402

UDC_TEXT = (
   "[Author]\r\n"
   "AuthorName=Test Author\r\n"
   "[File]\r\n"
   "Revision =1.0.0\r\n"
   "[Contest]\r\n"
   "Name =TESTQSO\r\n"
   "DisplayName = Test \u00c9 QSO Party\r\n"
   "CabrilloName =TEST-QSO\r\n"
   "Mode =CW\r\n"
   "MultWindowType = TESTSEC\r\n"
   "cabrilloformat = 99\r\n"
   "CabrilloFormat = 99\r\n"
   "EntryWindowInfo =SNTText, 450, RCVText, 450, Exchange1Text, 600\r\n"
   "CabrilloString =SNT, 4, SentNr, 4, CallSign, 13, Space, 2, Exchange1, 6\r\n"
)

SEC_TEXT = "TESTSEC\r\nAA\r\nBB\r\nCC\r\n"


class DecodeTests(unittest.TestCase):

   def test_utf16_with_bom(self):
      raw = UDC_TEXT.encode("utf-16")
      self.assertTrue(raw.startswith(b"\xff\xfe"))
      text, encoding = parse_udc.decode_bytes(raw)
      self.assertEqual(encoding, "utf-16")
      self.assertEqual(text, UDC_TEXT)

   def test_utf8_and_cp1252(self):
      text, encoding = parse_udc.decode_bytes(UDC_TEXT.encode("utf-8"))
      self.assertEqual((text, encoding), (UDC_TEXT, "utf-8"))
      text, encoding = parse_udc.decode_bytes(UDC_TEXT.encode("cp1252"))
      self.assertEqual((text, encoding), (UDC_TEXT, "cp1252"))

   def test_binary_is_not_text(self):
      self.assertFalse(parse_udc.looks_like_text(b"MZ\x90\x00\x03\x00\x00" * 50))


class IniTests(unittest.TestCase):

   def test_keys_are_case_sensitive_and_last_duplicate_wins(self):
      sections, dups = parse_udc.parse_ini(UDC_TEXT)
      contest = sections["Contest"]
      self.assertEqual(contest["Name"], "TESTQSO")
      self.assertIn("cabrilloformat", contest)
      self.assertIn("CabrilloFormat", contest)
      self.assertEqual(dups, [])
      sections, dups = parse_udc.parse_ini("[Contest]\nName=A\nName=B\n")
      self.assertEqual(sections["Contest"]["Name"], "B")
      self.assertEqual(dups, ["Contest.Name"])

   def test_prose_line_is_not_a_section_header(self):
      sections, _ = parse_udc.parse_ini("[Contest] section\nName=A\n")
      self.assertNotIn("Contest", sections)

   def test_value_may_contain_equals(self):
      sections, _ = parse_udc.parse_ini("[Contest]\nSpecialInstructions=a=b\n")
      self.assertEqual(sections["Contest"]["SpecialInstructions"], "a=b")


class PairListTests(unittest.TestCase):

   def test_cabrillo_string(self):
      fields, warnings = parse_udc.parse_pair_list(
         "SNT, 4, SentNr, 4, CallSign, 13, Space, 2, Exchange1, 6")
      self.assertEqual(warnings, [])
      self.assertEqual([(f["field"], f["width"]) for f in fields],
                       [("SNT", 4), ("SentNr", 4), ("CallSign", 13),
                        ("Space", 2), ("Exchange1", 6)])
      self.assertEqual(parse_udc.width_sum(fields), 29)

   def test_odd_and_bad_widths_are_reported(self):
      fields, warnings = parse_udc.parse_pair_list("SNT, 4, Misc")
      self.assertEqual(fields[1], {"field": "Misc", "width": None})
      self.assertEqual(len(warnings), 1)
      _, warnings = parse_udc.parse_pair_list("SNT, x")
      self.assertEqual(len(warnings), 1)

   def test_empty(self):
      self.assertEqual(parse_udc.parse_pair_list(""), ([], []))


class ZipTests(unittest.TestCase):

   def setUp(self):
      self.work = tempfile.mkdtemp(prefix="udc-test-")
      self.addCleanup(shutil.rmtree, self.work, ignore_errors=True)

   def make_zip(self):
      path = os.path.join(self.work, "bundle.zip")
      with zipfile.ZipFile(path, "w", zipfile.ZIP_DEFLATED) as archive:
         archive.writestr("TESTQSO.udc", UDC_TEXT.encode("utf-16"))
         archive.writestr("sub/TESTSEC.sec", SEC_TEXT)
         archive.writestr("tool.exe", b"MZ\x90\x00\x03\x00\x00" * 100)
         archive.writestr("../escape.txt", "must not be written")
         archive.writestr("C:/abs.txt", "must not be written")
      return path

   def test_extraction_guards(self):
      dest = os.path.join(self.work, "out")
      os.makedirs(dest)
      members = {m["name"]: m for m in
                 parse_udc.extract_zip(self.make_zip(), dest)}
      self.assertIsNone(members["TESTQSO.udc"]["skipped"])
      self.assertEqual(members["tool.exe"]["skipped"], "non-text")
      self.assertEqual(members["../escape.txt"]["skipped"], "unsafe-path")
      self.assertEqual(members["C:/abs.txt"]["skipped"], "unsafe-path")
      self.assertFalse(os.path.exists(os.path.join(self.work, "escape.txt")))
      self.assertTrue(os.path.isfile(os.path.join(dest, "sub", "TESTSEC.sec")))

   def test_whole_pipeline_on_a_zip_and_a_loose_utf16_file(self):
      cache = os.path.join(self.work, "cache")
      files = os.path.join(cache, "files")
      os.makedirs(files)
      shutil.copy(self.make_zip(), os.path.join(files, "bundle.zip"))
      with open(os.path.join(files, "loose.udc"), "wb") as handle:
         handle.write(UDC_TEXT.encode("utf-16"))
      with open(os.path.join(cache, "manifest.json"), "w") as handle:
         json.dump({"entries": [{"file_name": "bundle.zip", "title": "B",
                                 "page_url": "https://x/mmfiles/bundle-zip/",
                                 "date": "2026-01-01"}]}, handle)
      with open(os.path.join(cache, "display_names.json"), "w") as handle:
         json.dump([{"display_name": "Bundle Contest",
                     "page_url": "https://x/mmfiles/bundle-zip/",
                     "filenames": ["TESTQSO.udc in bundle.zip"]}], handle)

      records = []
      failures = []
      for name in ("bundle.zip", "loose.udc"):
         records.extend(parse_udc.process_file(
            os.path.join(files, name), cache,
            {"bundle.zip": {"file_name": "bundle.zip", "title": "B",
                            "page_url": "https://x/mmfiles/bundle-zip/"}},
            *parse_udc.build_display_maps(
               [{"display_name": "Bundle Contest",
                 "page_url": "https://x/mmfiles/bundle-zip/",
                 "filenames": ["TESTQSO.udc in bundle.zip"]}]),
            failures))
      self.assertEqual(failures, [])
      self.assertEqual(len(records), 2)

      bundle = records[0]
      self.assertEqual(bundle["contest"]["DisplayName"], "Test \u00c9 QSO Party")
      self.assertEqual(bundle["encoding"], "utf-16")
      self.assertEqual(bundle["display_page"]["display_name"], "Bundle Contest")
      self.assertEqual(bundle["cabrillo_fields"][3],
                       {"field": "Space", "width": 2})
      self.assertTrue(any("cabrilloformat" in w for w in bundle["warnings"]))
      sec = [c for c in bundle["companions"] if c["name"].endswith(".sec")][0]
      self.assertEqual(sec["line_count"], 4)
      self.assertEqual(sec["referenced_by"], ["Contest.MultWindowType"])
      self.assertTrue(bundle["external_list"]["in_bundle"])
      skipped = [c for c in bundle["companions"] if c["skipped"]]
      self.assertEqual(sorted(c["skipped"] for c in skipped),
                       ["non-text", "unsafe-path", "unsafe-path"])

      loose = records[1]
      self.assertEqual(loose["companions"], [])
      self.assertFalse(loose["external_list"]["in_bundle"])

   def test_csv_is_bom_quoted_crlf(self):
      record = parse_udc.build_record("f.udc", "f.udc", UDC_TEXT, "utf-8",
                                      {}, None, [])
      path = os.path.join(self.work, "x.csv")
      parse_udc.write_csv(path, [record])
      with open(path, "rb") as handle:
         raw = handle.read()
      self.assertTrue(raw.startswith(b"\xef\xbb\xbf\""))
      self.assertTrue(raw.split(b"\r\n")[0].endswith(b"\"Warnings\""))
      self.assertIn(b"\r\n", raw)
      self.assertNotIn(b"\n", raw.replace(b"\r\n", b""))


if __name__ == "__main__":
   unittest.main()
