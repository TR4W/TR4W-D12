"""Test native container alternatives and restore the staged release in finally.

The approved bridge accepts only the test-slot executable path. This harness
parks that complete staged release, occupies the slot with a declared native
fixture, and restores/validates the original before returning. No operator app
or CI toolchain is modified.
"""

from datetime import datetime, timezone
import argparse
import fcntl
import json
import plistlib
from pathlib import Path
import shutil
import subprocess
import tempfile
import time
import uuid

from evidence import file_digest
from mac_bridge import MacBridge, console_status, wait_for
from mac_test_slot import helper_identity, staged_bundle


def measure_case(observation, mode, lcl):
   if lcl:
      target_titles = ("First page action", "Second page action", "Panel action", "Status action")
      expected_titles = (mode.capitalize() + " page action", "Panel action", "Status action")
   else:
      target_titles = ("Save and close", "Save", "Cancel")
      expected_titles = ("Save and close", "Cancel", "Save") if mode in ("view", "children", "visible") else ()
   tree = observation["tree"]
   record = {"mode": mode}
   record["buttons"] = [{"title": row.get("AXTitle"), "enabled": row.get("AXEnabled")}
      for row in tree if row.get("AXRole") == "AXButton" and row.get("AXTitle") in target_titles]
   record["hidden_sentinels"] = [row.get("AXTitle") for row in tree
      if row.get("AXTitle") in ("Hidden button sentinel", "Hidden panel sentinel")]
   expected_buttons = [{"title": title, "enabled": title != "Save"} for title in expected_titles]
   expected_hidden = {"Hidden button sentinel", "Hidden panel sentinel"} if mode == "children" else set()
   actual = sorted(record["buttons"], key=lambda row: row["title"])
   expected = sorted(expected_buttons, key=lambda row: row["title"])
   record["passed"] = actual == expected and set(record["hidden_sentinels"]) == expected_hidden
   return record


def main():
   parser = argparse.ArgumentParser(description=__doc__)
   parser.add_argument("--lcl-executable", type=Path, help="Inspect the compiled mac_lcl_ax_control fixture instead of the native fixture")
   parser.add_argument("--exercise-tabs", action="store_true", help="Diagnostic keyboard tab switching; requires the LCL fixture to become foreground")
   args = parser.parse_args()
   if args.exercise_tabs and not args.lcl_executable:
      parser.error("--exercise-tabs requires --lcl-executable")
   root = (Path.home() / "tr4w-gui-test").resolve()
   stage = root / "app/TR4W.app"
   exe = stage / "Contents/MacOS/tr4w"
   if not stage.resolve().is_relative_to(root / "app"):
      raise RuntimeError("Test slot resolves outside the staged application area")
   name = datetime.now(timezone.utc).strftime("ax-control-%Y%m%dT%H%M%S-") + uuid.uuid4().hex[:6]
   output = root / "artifacts" / name
   jobs = root / "jobs" / name
   output.mkdir()
   jobs.mkdir()
   bridge = MacBridge(jobs, output).perform
   summary = {"fixture": "Lazarus Cocoa container/subclass regression" if args.lcl_executable else "standalone Cocoa NSScrollView/container/NSButton reproduction",
      "artifact_directory": str(output), "cases": []}
   with (root / "pilot.lock").open("a") as lock:
      fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
      original_sha = file_digest(exe)
      summary["original_executable_sha256"] = original_sha
      summary["console"] = console_status()
      if not summary["console"]["ready"]:
         summary["passed"] = False
         summary["error"] = "macOS console must be logged in and unlocked before GUI testing"
         (output / "summary.json").write_text(json.dumps(summary, indent=3))
         raise RuntimeError(summary["error"])
      probe = Path.home() / "Applications/TR4W AX Probe.app"
      summary["probe_identity"] = helper_identity(root, probe, "mac-ax-probe-build.json")
      if args.exercise_tabs:
         summary["runner_identity"] = helper_identity(root, Path.home() / "Applications/TR4W GUI Pilot.app", "mac-runner-build.json")
      if subprocess.run(["/usr/bin/pgrep", "-x", "tr4w"], capture_output=True).returncode == 0:
         raise RuntimeError("A TR4W process already exists")
      with tempfile.TemporaryDirectory(prefix="ax-container-control-", dir=root / "source") as temporary:
         fixture = Path(temporary) / "TR4W.app"
         fixture_exe = fixture / "Contents/MacOS/tr4w"
         fixture_exe.parent.mkdir(parents=True)
         (fixture / "Contents/Info.plist").write_bytes(plistlib.dumps({
            "CFBundleIdentifier": "net.tr4w.ax-container-control", "CFBundleExecutable": "tr4w",
            "CFBundleName": "AX container control", "CFBundlePackageType": "APPL", "CFBundleVersion": "1"}))
         if args.lcl_executable:
            shutil.copy2(args.lcl_executable, fixture_exe)
         else:
            source = Path(__file__).with_name("mac_ax_container_control.m")
            subprocess.run(["xcrun", "clang", "-fobjc-arc", "-Wall", "-Wextra", "-Wno-deprecated-declarations",
               "-framework", "AppKit", str(source), "-o", str(fixture_exe)], check=True)
         subprocess.run(["/usr/bin/codesign", "--force", "--sign", "-", str(fixture)], check=True)
         summary["fixture_executable_sha256"] = file_digest(fixture_exe)
         with staged_bundle(root, fixture):
            modes = ("first", "second") if args.lcl_executable else ("control", "view", "ignored", "children", "visible")
            for mode in modes:
               with (output / (mode + ".log")).open("w") as log:
                  app = subprocess.Popen([str(exe), mode], stdout=log, stderr=subprocess.STDOUT)
                  try:
                     time.sleep(1)
                     result = bridge("inspect", probe=True, pid=app.pid)
                     (output / (mode + ".json")).write_text(json.dumps(result, indent=3))
                     record = measure_case(result, mode, bool(args.lcl_executable))
                     summary["cases"].append(record)
                     if args.exercise_tabs and mode == "first":
                        bridge("activate", pid=app.pid)
                        time.sleep(0.3)
                        for target in ("second", "first"):
                           bridge("key", pid=app.pid, key="tab", modifiers=["control"])

                           def switched():
                              observation = bridge("inspect", probe=True, pid=app.pid)
                              measurement = measure_case(observation, target, True)
                              (output / ("switched-to-" + target + ".json")).write_text(json.dumps(observation, indent=3))
                              return measurement if measurement["passed"] else None

                           measured = wait_for("Tab switch to " + target, switched, 5)
                           measured["interaction"] = "Control+Tab"
                           summary["cases"].append(measured)
                  finally:
                     if app.poll() is None:
                        app.terminate()
                        try:
                           app.wait(timeout=5)
                        except subprocess.TimeoutExpired:
                           app.kill()
                           app.wait(timeout=5)
         summary["original_restored"] = file_digest(exe) == original_sha
         summary["passed"] = summary["original_restored"] and all(case["passed"] for case in summary["cases"])
         (output / "summary.json").write_text(json.dumps(summary, indent=3))
         print(json.dumps(summary, indent=3))
   if not summary["passed"]:
      raise AssertionError("Native accessibility container regression or restored release hash mismatch")


if __name__ == "__main__":
   main()
