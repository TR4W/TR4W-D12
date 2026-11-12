"""Verify snapshots reject mismatched symbols and mixed runtime assets."""

from pathlib import Path
import tempfile
import unittest

from stage_main_build import stage
from test_evidence import make_pair


class StageTests(unittest.TestCase):
   def fixture(self, root):
      exe = make_pair(root)
      (root / "cacert.pem").write_text("test certificate file", encoding="utf-8")
      (root / "help").mkdir()
      (root / "help" / "help_en.po").write_text("test help", encoding="utf-8")
      return exe

   def test_symbols_must_match_before_any_snapshot_is_used(self):
      with tempfile.TemporaryDirectory() as temporary:
         root = Path(temporary)
         exe = self.fixture(root)
         (root / "test.dbg").write_bytes(b"different compiler run")
         with self.assertRaisesRegex(RuntimeError, "symbols"):
            stage(exe, root / "output")

   def test_existing_snapshot_cannot_silently_mix_runtime_versions(self):
      with tempfile.TemporaryDirectory() as temporary:
         root = Path(temporary)
         exe = self.fixture(root)
         first = stage(exe, root / "output")
         self.assertTrue(Path(first["archive"]).is_file())
         self.assertTrue(first["vm_root"].startswith("C:\\TR4W-Test\\bench-main-"))
         (root / "cacert.pem").write_text("changed runtime file", encoding="utf-8")
         with self.assertRaisesRegex(RuntimeError, "mix different files"):
            stage(exe, root / "output")


if __name__ == "__main__":
   unittest.main()
