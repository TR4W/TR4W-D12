"""Regression checks for GUI preflight/evidence failures, without driving a UI."""

import json
import os
import struct
import tempfile
import unittest
import zlib
from pathlib import Path

from evidence import StepLog, file_digest, pe_info, preserve_build, require_matching_bitness, preserve_generated_file


def make_pair(directory):
   bits = struct.calcsize("P") * 8
   debug = b"test symbol file"
   (directory / "test.dbg").write_bytes(debug)
   payload = b"test.dbg\0\0\0\0" + struct.pack("<I", zlib.crc32(debug))
   data = bytearray(0x500)
   data[:2] = b"MZ"
   struct.pack_into("<I", data, 0x3C, 0x80)
   data[0x80:0x84] = b"PE\0\0"
   struct.pack_into("<HHIIIHH", data, 0x84, 0x8664 if bits == 64 else 0x14C,
                    1, 0, 0x300, 0, 0, 0)
   data[0x98:0xA0] = b"/4\0\0\0\0\0\0"
   struct.pack_into("<II", data, 0x98 + 16, len(payload), 0x400)
   strings = b".gnu_debuglink\0"
   struct.pack_into("<I", data, 0x300, 4 + len(strings))
   data[0x304:0x304 + len(strings)] = strings
   data[0x400:0x400 + len(payload)] = payload
   exe = directory / "test.exe"
   exe.write_bytes(data)
   (directory / "source-provenance.json").write_text(
      json.dumps({"SourceRevision": "a" * 40, "SourceClean": True}), encoding="utf-8"
   )
   return exe


class EvidenceTests(unittest.TestCase):
   def test_wrong_bitness_is_refused(self):
      native = struct.calcsize("P") * 8
      self.assertEqual(require_matching_bitness(native), native)
      with self.assertRaisesRegex(RuntimeError, "No UI actions"):
         require_matching_bitness(32 if native == 64 else 64)

   def test_matching_pair_is_archived_but_changed_symbols_are_refused(self):
      with tempfile.TemporaryDirectory() as temporary:
         directory = Path(temporary)
         exe = make_pair(directory)
         self.assertEqual(pe_info(exe)["debug_name"], "test.dbg")
         metadata = preserve_build(exe, directory / "evidence")
         self.assertTrue((Path(metadata["archive"]) / "test.dbg").exists())
         (directory / "test.dbg").write_bytes(b"different build")
         with self.assertRaisesRegex(RuntimeError, "CRC32"):
            preserve_build(exe, directory / "evidence")

   def test_unknown_source_is_refused(self):
      with tempfile.TemporaryDirectory() as temporary:
         directory = Path(temporary)
         exe = make_pair(directory)
         (directory / "source-provenance.json").write_text("{}", encoding="utf-8")
         with self.assertRaisesRegex(RuntimeError, "Certified source"):
            preserve_build(exe, directory / "evidence")

   def test_selected_binary_requires_its_exact_hash_and_marks_source_unknown(self):
      with tempfile.TemporaryDirectory() as temporary:
         directory = Path(temporary)
         exe = make_pair(directory)
         source = directory / "source-provenance.json"
         provenance = {"ProvenanceKind": "user-selected-existing-binary",
            "SourceExecutable": str(exe), "SourceSHA256": "0" * 64,
            "SourceRevision": None, "SourceClean": False}
         source.write_text(json.dumps(provenance), encoding="utf-8")
         with self.assertRaisesRegex(RuntimeError, "explicitly identified"):
            preserve_build(exe, directory / "evidence")
         provenance["SourceSHA256"] = file_digest(exe)
         source.write_text(json.dumps(provenance), encoding="utf-8")
         metadata = preserve_build(exe, directory / "evidence")
         self.assertIsNone(metadata["source"]["SourceRevision"])
         self.assertFalse(metadata["source"]["SourceClean"])

   def test_failed_action_has_before_and_error_but_no_after(self):
      with tempfile.TemporaryDirectory() as temporary:
         path = Path(temporary) / "steps.jsonl"
         journal = StepLog(path)
         with self.assertRaises(ValueError):
            journal.perform("tab selection", lambda: int("invalid"))
         events = [json.loads(line) for line in path.read_text().splitlines()]
         self.assertEqual([event["state"] for event in events], ["before", "error"])
         self.assertTrue(all(event["action"] == "tab selection" for event in events))


class ExportEvidenceTests(unittest.TestCase):
   def test_stale_export_is_rejected_without_replacing_evidence(self):
      with tempfile.TemporaryDirectory() as temporary:
         source = Path(temporary) / "export.adi"
         target = Path(temporary) / "evidence.adi"
         source.write_bytes(b"old export")
         target.write_bytes(b"preserved evidence")
         with self.assertRaisesRegex(RuntimeError, "not rewritten"):
            preserve_generated_file(source, target, source.stat().st_mtime_ns)
         self.assertEqual(target.read_bytes(), b"preserved evidence")

   def test_rewritten_export_is_preserved_with_its_digest(self):
      with tempfile.TemporaryDirectory() as temporary:
         source = Path(temporary) / "export.adi"
         target = Path(temporary) / "evidence.adi"
         source.write_bytes(b"old export")
         previous = source.stat().st_mtime_ns
         source.write_bytes(b"new export")
         os.utime(source, ns=(previous + 1_000_000_000, previous + 1_000_000_000))
         metadata = preserve_generated_file(source, target, previous)
         self.assertEqual(target.read_bytes(), b"new export")
         self.assertEqual(metadata["sha256"], file_digest(target))
         self.assertEqual(metadata["previous_mtime_ns"], previous)


if __name__ == "__main__":
   unittest.main()
