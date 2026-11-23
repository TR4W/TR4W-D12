"""Tests for latest_release_json.  Run: python -m unittest tools/test_latest_release_json.py

The full-release fixture is the REAL v5.1.0 payload, captured read-only with
   gh release view v5.1.0 --json tagName,publishedAt,assets
(reduced to name, size, url and digest per asset).  The partial and draft cases
are derived from it in the tests, so each differs from the real shape by exactly
the thing it is testing.
"""

import copy
import json
import os
import subprocess
import sys
import tempfile
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import latest_release_json as tool  # noqa: E402

FIXTURE = os.path.join(HERE, "test_fixtures", "latest_release", "release-v5.1.0.json")
BASE = "https://github.com/TR4W/TR4W-D12/releases/download/v5.1.0/"


def full_release():
   with open(FIXTURE, "r", encoding="utf-8") as handle:
      return json.load(handle)


def without(release, *fragments):
   """A copy of the release with every asset whose name contains a fragment removed."""
   result = copy.deepcopy(release)
   result["assets"] = [
      a for a in result["assets"] if not any(f in a["name"] for f in fragments)
   ]
   return result


class FullReleaseTests(unittest.TestCase):
   def setUp(self):
      self.out = tool.build(full_release())

   def test_identity(self):
      self.assertEqual(self.out["schema"], 1)
      self.assertEqual(self.out["tag"], "v5.1.0")
      self.assertEqual(self.out["version"], "5.1.0")
      self.assertEqual(self.out["published"], "2026-11-23T07:50:11Z")
      self.assertEqual(self.out["release_url"], "https://github.com/TR4W/TR4W-D12/releases/tag/v5.1.0")

   def test_three_platforms_all_available(self):
      self.assertEqual(list(self.out["platforms"]), ["windows-x64", "macos-aarch64", "linux-x86_64"])
      for key, platform in self.out["platforms"].items():
         self.assertTrue(platform["available"], key)
         self.assertEqual(platform["missing"], [], key)
         self.assertNotIn("reason", platform, key)

   def test_windows_installer(self):
      files = self.out["platforms"]["windows-x64"]["files"]
      self.assertEqual(len(files), 1)
      self.assertEqual(files[0], {
         "role": "installer",
         "name": "tr4w_setup_5.1.0-x64.exe",
         "url": BASE + "tr4w_setup_5.1.0-x64.exe",
         "size": 60040699,
         "sha256": "f6ee4f616788d8ee97c8b788a0e4a983b085c80233fbcd54658eea59ff525767",
         "description": files[0]["description"],
      })
      self.assertTrue(files[0]["description"])

   def test_macos_pkg_then_dmg(self):
      files = self.out["platforms"]["macos-aarch64"]["files"]
      self.assertEqual([f["role"] for f in files], ["pkg", "dmg"])
      self.assertEqual(files[0]["name"], "tr4w-5.1.0-aarch64-darwin.pkg")
      self.assertEqual(files[0]["size"], 26498512)
      self.assertEqual(files[1]["name"], "tr4w-5.1.0-aarch64-darwin.dmg")
      self.assertEqual(files[1]["sha256"],
                       "05d9592e49613be0921e232e25a4adb447523a340ff26f3059fba1e11fc879c3")

   def test_linux_appimage_not_tarball(self):
      files = self.out["platforms"]["linux-x86_64"]["files"]
      self.assertEqual([f["name"] for f in files], ["TR4W-5.1.0-x86_64.AppImage"])
      self.assertEqual(files[0]["size"], 43768312)

   def test_virustotal_report(self):
      report = self.out["virustotal"]
      self.assertEqual(report["name"], "virustotal-report.md")
      self.assertEqual(report["url"], BASE + "virustotal-report.md")

   def test_no_symbol_or_debug_file_is_offered(self):
      names = [f["name"] for p in self.out["platforms"].values() for f in p["files"]]
      for name in names:
         self.assertNotIn("dSYM", name)
         self.assertFalse(name.endswith(".dbg"), name)

   def test_every_url_is_the_tagged_form(self):
      for platform in self.out["platforms"].values():
         for entry in platform["files"]:
            self.assertEqual(entry["url"], BASE + entry["name"])


class PartialReleaseTests(unittest.TestCase):
   def test_no_linux_and_no_macos(self):
      out = tool.build(without(full_release(), "darwin", ".AppImage", "x86_64-linux"))
      self.assertTrue(out["platforms"]["windows-x64"]["available"])
      for key in ("macos-aarch64", "linux-x86_64"):
         platform = out["platforms"][key]
         self.assertFalse(platform["available"], key)
         self.assertEqual(platform["files"], [], key)
         self.assertIn("v5.1.0", platform["reason"], key)
         self.assertTrue(platform["missing"], key)

   def test_pkg_present_dmg_missing(self):
      out = tool.build(without(full_release(), ".dmg"))
      mac = out["platforms"]["macos-aarch64"]
      self.assertTrue(mac["available"])
      self.assertEqual([f["role"] for f in mac["files"]], ["pkg"])
      self.assertEqual([m["role"] for m in mac["missing"]], ["dmg"])
      self.assertNotIn("reason", mac)

   def test_missing_virustotal_report_is_null_not_an_error(self):
      out = tool.build(without(full_release(), "virustotal-report"))
      self.assertIsNone(out["virustotal"])

   def test_missing_digest_gives_null_sha256(self):
      release = full_release()
      for asset in release["assets"]:
         if asset["name"].endswith(".exe"):
            del asset["digest"]
      out = tool.build(release)
      self.assertIsNone(out["platforms"]["windows-x64"]["files"][0]["sha256"])


class RefusalTests(unittest.TestCase):
   def test_no_windows_installer_is_refused(self):
      with self.assertRaises(tool.ReleaseError):
         tool.build(without(full_release(), "tr4w_setup_"))

   def test_draft_url_is_refused(self):
      release = full_release()
      for asset in release["assets"]:
         asset["url"] = asset["url"].replace("/v5.1.0/", "/untagged-443cafad5572b698aabb/")
      with self.assertRaises(tool.ReleaseError):
         tool.build(release)

   def test_bad_tag_is_refused(self):
      release = full_release()
      release["tagName"] = "latest"
      with self.assertRaises(tool.ReleaseError):
         tool.build(release)

   def test_missing_field_is_refused(self):
      release = full_release()
      del release["assets"]
      with self.assertRaises(tool.ReleaseError):
         tool.build(release)

   def test_zero_size_is_refused(self):
      release = full_release()
      for asset in release["assets"]:
         if asset["name"].endswith(".exe"):
            asset["size"] = 0
      with self.assertRaises(tool.ReleaseError):
         tool.build(release)


class CommandLineTests(unittest.TestCase):
   def run_tool(self, source_text):
      with tempfile.TemporaryDirectory() as scratch:
         source = os.path.join(scratch, "release.json")
         target = os.path.join(scratch, "latest.json")
         with open(source, "w", encoding="utf-8") as handle:
            handle.write(source_text)
         done = subprocess.run(
            [sys.executable, "-I", os.path.join(HERE, "latest_release_json.py"), source, target],
            capture_output=True, text=True,
         )
         written = None
         if os.path.exists(target):
            with open(target, "r", encoding="utf-8", newline="") as handle:
               written = handle.read()
         return done, written

   def test_writes_json_with_lf_endings(self):
      with open(FIXTURE, "r", encoding="utf-8") as handle:
         text = handle.read()
      done, written = self.run_tool(text)
      self.assertEqual(done.returncode, 0, done.stderr)
      self.assertNotIn("\r", written)
      self.assertEqual(json.loads(written)["tag"], "v5.1.0")

   def test_refusal_exits_nonzero_and_writes_nothing(self):
      done, written = self.run_tool("{\"tagName\": \"v5.1.0\", \"publishedAt\": \"x\", \"assets\": []}")
      self.assertEqual(done.returncode, 1)
      self.assertIsNone(written)
      self.assertIn("Windows", done.stderr)

   def test_not_json_exits_nonzero(self):
      done, written = self.run_tool("not json")
      self.assertEqual(done.returncode, 1)
      self.assertIsNone(written)


if __name__ == "__main__":
   unittest.main()
