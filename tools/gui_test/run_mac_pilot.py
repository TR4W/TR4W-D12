"""Run the Cocoa navigation pilot through the approved native bridge."""

import argparse
from contextlib import ExitStack
from datetime import datetime, timezone
import fcntl
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import time
import traceback
import uuid

from evidence import StepLog, file_digest, native_build_identity
from fixture_data import contacts, contact_digest, prepare_offline_fixture
from mac_bridge import MacBridge, console_status, wait_for
from mac_test_slot import helper_identity, staged_bundle


def inventory(directory):
   if not directory.exists():
      return None
   return {str(path.relative_to(directory)): [path.stat().st_size, path.stat().st_mtime_ns]
      for path in directory.rglob("*") if path.is_file()}


def main():
   parser = argparse.ArgumentParser(description=__doc__)
   parser.add_argument("--database-template", type=Path, required=True)
   parser.add_argument("--settings-template", type=Path, required=True)
   parser.add_argument("--run", default=datetime.now(timezone.utc).strftime("mac-%Y%m%dT%H%M%S-") + uuid.uuid4().hex[:6])
   parser.add_argument("--ax-probe", action="store_true", help="Use the separately approved read-only AX Probe for inspection")
   parser.add_argument("--app-bundle", type=Path, help="Temporarily test this complete signed bundle and restore the release afterward")
   parser.add_argument("--build-record", type=Path, help="Build provenance JSON, matched to the tested executable SHA256")
   parser.add_argument("--exercise-footer", action="store_true", help="Activate clean Cancel and Save and close using observed keyboard focus")
   parser.add_argument("--runner-next", action="store_true", help="Use the separately approved full-input TR4W GUI Runner")
   parser.add_argument("--case", choices=("smoke", "preferences-persistence"), default="smoke")
   args = parser.parse_args()
   if args.case == "preferences-persistence" and not args.runner_next:
      parser.error("Preferences persistence requires --runner-next for native text/control input")
   if sys.platform != "darwin" or not re.fullmatch(r"[A-Za-z0-9-]+", args.run):
      parser.error("Run on macOS with an alphanumeric/hyphen run name")
   root = Path.home() / "tr4w-gui-test"
   run = root / "runs" / args.run
   output = root / "artifacts" / args.run
   jobs = root / "jobs" / args.run
   helper = Path.home() / ("Applications/TR4W GUI Runner.app" if args.runner_next else "Applications/TR4W GUI Pilot.app")
   probe_helper = Path.home() / "Applications/TR4W AX Probe.app"
   exe = root / "app/TR4W.app/Contents/MacOS/tr4w"
   result = {"passed": False, "checks": [], "failures": [], "run": str(run), "case": args.case, "source_revision": None,
      "provenance": "user-staged-release-binary"}
   app = None
   original = None
   columns = None
   before = None
   starting = False
   with ExitStack() as cleanup:
      lock = cleanup.enter_context((root / "pilot.lock").open("a"))
      fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
      cleanup.enter_context(staged_bundle(root, args.app_bundle))
      result.update(native_build_identity(exe, args.build_record))
      if args.app_bundle and not args.build_record:
         result["provenance"] = "experimental-bundle-without-build-record"
      run.mkdir()
      output.mkdir()
      jobs.mkdir()
      bridge = MacBridge(jobs, output, next_runner=args.runner_next).perform
      journal = StepLog(output / "steps.jsonl")
      default_settings = Path.home() / "Library/Application Support/TR4W"
      default_contests = Path.home() / "tr4w"
      settings_before = inventory(default_settings)
      contests_before = inventory(default_contests)
      runtime_log = Path.home() / "Library/Logs/TR4W/tr4w.log"
      log_offset = runtime_log.stat().st_size if runtime_log.exists() else 0

      def inspect(hit_points=(), diagnostic=True):
         if app.poll() is not None:
            raise RuntimeError("Owned application exited: " + str(app.returncode))
         return bridge("inspect", probe=args.ax_probe and diagnostic, capture_runner=args.runner_next and not diagnostic,
            pid=app.pid, hit_points=list(hit_points))

      def window(title):
         try:
            # WindowServer redacts window names without Screen Recording.
            # Keep inventory/capture on the already-approved original runner;
            # the read-only AX probe needs Accessibility only.
            observation = inspect(diagnostic=False)
         except RuntimeError as error:
            # NSRunningApplication registration follows process creation.
            # Retry only during startup of the Popen-owned PID; the native
            # bridge must still validate its executable before any UI action.
            if starting and app.poll() is None and str(error) == "Native inspect: PID does not belong to the staged TR4W executable":
               return None
            raise
         matches = [row for row in observation["windows"]
            if title in row.get("kCGWindowName", "") and row.get("kCGWindowLayer") == 0]
         if len(matches) > 1:
            raise RuntimeError("Owned window is ambiguous: " + repr(matches))
         return matches[0] if matches else None

      def key(name, modifiers=()):
         return bridge("key", pid=app.pid, key=name, modifiers=list(modifiers))

      def activate():
         bridge("activate", pid=app.pid)
         time.sleep(0.3)

      def capture(row, name):
         activate()
         observation = bridge("capture", pid=app.pid, window_id=row["kCGWindowNumber"])
         shutil.copy2(observation["png"], output / name)

      def activate_footer(caption):
         activate()
         for attempt in range(20):
            tree = inspect(diagnostic=False)["tree"]
            frames = [row for row in tree if row.get("AXRole") == "AXWindow" and "Preferences" in row.get("AXTitle", "")]
            if len(frames) != 1:
               raise AssertionError("Preferences disappeared before footer activation")
            path = frames[0]["path"]
            focused = [row for row in tree if row["path"][:len(path)] == path and row.get("AXFocused")]
            if len(focused) == 1 and focused[0].get("AXRole") == "AXButton" and focused[0].get("AXTitle") == caption:
               if not focused[0].get("AXEnabled"):
                  raise AssertionError("Focused footer is disabled: " + caption)
               result.setdefault("footer_actions", []).append({"caption": caption, "focus": focused[0], "tabs": attempt})
               key("space")
               wait_for("Footer activation dismissed Preferences: " + caption, lambda: not window("Preferences"), 15)
               return
            key("tab", ["shift"])
            time.sleep(0.1)
         raise AssertionError("Keyboard traversal did not focus footer: " + caption)

      with (output / "processes.log").open("w") as log:
         try:
            result["console"] = console_status()
            if not result["console"]["ready"]:
               raise RuntimeError("macOS console must be logged in and unlocked before GUI testing")
            result["runner_identity"] = helper_identity(root, helper, "mac-runner-next-build.json" if args.runner_next else "mac-runner-build.json")
            permissions = bridge("preflight")
            result["permissions"] = permissions
            if not permissions.get("accessibility"):
               raise RuntimeError("Native input runner requires Accessibility approval")
            if args.runner_next:
               capture_helper = Path.home() / "Applications/TR4W GUI Pilot.app"
               result["capture_runner_identity"] = helper_identity(root, capture_helper, "mac-runner-build.json")
               result["capture_permissions"] = bridge("preflight", capture_runner=True)
               if not result["capture_permissions"].get("accessibility") or not result["capture_permissions"].get("screen_recording"):
                  raise RuntimeError("Original capture runner requires its existing Accessibility and Screen Recording approvals")
            elif not permissions.get("screen_recording"):
               raise RuntimeError("Native runner requires both Accessibility and Screen Recording approval")
            if args.ax_probe:
               result["probe_identity"] = helper_identity(root, probe_helper, "mac-ax-probe-build.json")
               probe_permissions = bridge("preflight", probe=True)
               result["probe_permissions"] = probe_permissions
               if not probe_permissions.get("accessibility"):
                  raise RuntimeError("TR4W AX Probe requires Accessibility approval; the original runner remains unchanged")
            # A singleton collision could otherwise attach to an operator's app.
            running = subprocess.run(["/usr/bin/pgrep", "-x", "tr4w"], capture_output=True, text=True)
            if running.returncode == 0:
               raise RuntimeError("A TR4W process already exists; use an exclusive test desktop")
            prepare_offline_fixture(args.database_template, args.settings_template, run)
            original = contacts(run / "practice.db")
            if not original:
               raise RuntimeError("Pilot requires a nonempty repository fixture")
            columns = list(original[0])
            before = contact_digest(run / "practice.db", columns)
            archive = root / "evidence" / result["executable_sha256"]
            archive.mkdir(parents=True, exist_ok=True)
            archived = archive / "tr4w"
            if not archived.exists():
               shutil.copy2(exe, archived)
            if file_digest(archived) != result["executable_sha256"]:
               raise RuntimeError("Archived executable has changed")
            def launch_owned():
               nonlocal app, starting
               starting = True
               try:
                  app = journal.perform("launch owned Cocoa application", lambda: subprocess.Popen(
                     [str(exe), "./practice.db", "--settings", str(run / "tr4w.json"), "--lang", "en"],
                     cwd=run, stdout=log, stderr=subprocess.STDOUT))
                  result["pid"] = app.pid
                  result.setdefault("application_pids", []).append(app.pid)
                  (output / "owned-process.json").write_text(json.dumps({"pid": app.pid, "exe": str(exe)}))
                  row = wait_for("Cocoa main window", lambda: window("TR4W v."))
                  if "Open configuration file" in row["kCGWindowName"]:
                     raise AssertionError("New Contest opened instead of the practice log")
                  return row
               finally:
                  starting = False

            def close_owned():
               activate()
               journal.perform("request quit with Command+Q", lambda: key("q", ["command"]))

               def exit_question():
                  if app.poll() is not None:
                     return "exited"
                  tree = inspect()["tree"]
                  if any("really want to exit" in str(row.get("AXValue", row.get("AXTitle", ""))).lower() for row in tree):
                     return "question"
                  return None

               state = wait_for("Cocoa quit response", exit_question, 10)
               result["quit_confirmation_seen"] = state == "question"
               if state == "question":
                  journal.perform("confirm observed exit question", lambda: key("y", ["option"]))
               app.wait(timeout=20)
               result["application_exit_code"] = app.returncode
               result.setdefault("application_exit_codes", []).append(app.returncode)
               if contact_digest(run / "practice.db", columns) != before:
                  raise AssertionError("Original practice contact fields changed")
               if app.returncode != 0:
                  raise AssertionError("Application exit status: " + str(app.returncode))

            def restart():
               close_owned()
               launch_owned()

            main_window = launch_owned()
            result["main_window"] = main_window
            journal.perform("capture Cocoa main window", lambda: capture(main_window, "main.png"))
            result["checks"].append("Practice log opened and main window captured")
            activate()
            journal.perform("open Preferences with Control+J", lambda: key("j", ["control"]))
            preferences = wait_for("Cocoa Preferences window", lambda: window("Preferences"), 15)
            journal.perform("capture Cocoa Preferences", lambda: capture(preferences, "preferences.png"))
            observation = inspect()
            tree = observation["tree"]
            (output / "preferences-tree.json").write_text(json.dumps(tree, indent=3), encoding="utf-8")
            frames = [row for row in tree if row.get("AXRole") == "AXWindow" and "Preferences" in row.get("AXTitle", "")]
            if len(frames) != 1:
               raise AssertionError("Preferences accessibility window is not unique")
            rect = frames[0].get("rectangle", [])
            if args.ax_probe and len(rect) == 4 and rect[2:] == [860, 648]:
               # AX uses the window frame without WindowServer's extra border.
               # Points are measured in the reviewed Retina capture and are
               # read-only diagnostics, never clicks or acceptance criteria.
               points = [[rect[0] + rect[2] - right, rect[1] + rect[3] - 26]
                  for right in (259, 152, 58)]
               result["ax_hit_tests"] = inspect(points).get("hit_tests", [])
               post_hit_tree = inspect()["tree"]
               (output / "post-hit-tree.json").write_text(json.dumps(post_hit_tree, indent=3), encoding="utf-8")
               result["post_hit_button_titles"] = [row.get("AXTitle") for row in post_hit_tree
                  if row.get("AXRole") == "AXButton" and row.get("AXTitle") in ("Save and close", "Cancel", "Save")]
            path = frames[0]["path"]
            footer = [row for row in tree if row["path"][:len(path)] == path and row.get("AXRole") == "AXButton"
               and row.get("AXTitle") in ("Save and close", "Save", "Cancel")]
            footer_failures = []
            for caption in ("Save and close", "Save", "Cancel"):
               matches = [row for row in footer if row.get("AXTitle") == caption]
               if len(matches) != 1 or bool(matches[0].get("AXEnabled")) != (caption != "Save"):
                  footer_failures.append("Cocoa AX did not expose the expected clean Preferences footer state: " + caption)
            result["footer"] = footer
            result["footer_assertion_passed"] = not footer_failures
            result["failures"].extend(footer_failures)
            if not footer_failures:
               result["checks"].append("Cocoa AX exposes clean Preferences footer with disabled Save")
            journal.perform("dismiss Preferences with Escape", lambda: key("escape"))
            wait_for("Cocoa Preferences dismissal", lambda: not window("Preferences"), 15)
            result["checks"].append("Escape dismissed Preferences")
            if args.exercise_footer:
               if footer_failures:
                  raise AssertionError("Footer action checks require a complete accessible footer")
               for caption in ("Cancel", "Save and close"):
                  activate()
                  journal.perform("reopen clean Preferences for " + caption, lambda: key("j", ["control"]))
                  wait_for("Preferences reopened", lambda: window("Preferences"), 15)
                  journal.perform("activate focused footer " + caption, lambda: activate_footer(caption))
                  result["checks"].append("Keyboard activated clean " + caption + " and dismissed Preferences")
            result["navigation_passed"] = True
            if args.case == "preferences-persistence":
               if footer_failures:
                  raise AssertionError("Preferences persistence requires a complete accessible footer")
               from mac_preferences import MacPreferences
               from preferences_roundtrip import run_preferences_roundtrip
               driver = MacPreferences(bridge, lambda: app, window, output, journal)
               result["preferences_persistence"] = {}
               run_preferences_roundtrip(driver, run / "tr4w.json", restart, journal, result["preferences_persistence"])
               result["checks"].extend(result["preferences_persistence"]["checks"])
            close_owned()
            result["contact_count"] = len(original)
            result["added_contact_columns"] = sorted(set(contacts(run / "practice.db")[0]) - set(columns))
            if contact_digest(run / "practice.db", columns) != before:
               raise AssertionError("Original practice contact fields changed")
            result["checks"].append("Original contact fields unchanged on exit")
            result["checks"].append("Normal application exit")
            result["passed"] = not result["failures"]
         except Exception:
            result["error"] = traceback.format_exc()
            if app is not None and app.poll() is None:
               try:
                  (output / "failure-inspection.json").write_text(json.dumps(inspect(), indent=3), encoding="utf-8")
               except Exception:
                  result["diagnostic_error"] = traceback.format_exc()
         finally:
            if app is not None and app.poll() is not None:
               result["application_exit_code"] = app.returncode
            if app is not None and app.poll() is None:
               result["forced_cleanup"] = True
               app.terminate()
               try:
                  app.wait(timeout=10)
               except subprocess.TimeoutExpired:
                  app.kill()
                  app.wait(timeout=5)
            if original is not None:
               result["contact_count"] = len(original)
               result["original_contacts_unchanged"] = contact_digest(run / "practice.db", columns) == before
               if not result["original_contacts_unchanged"]:
                  result["passed"] = False
            result["default_settings_unchanged"] = settings_before == inventory(default_settings)
            result["default_contest_files_unchanged"] = contests_before == inventory(default_contests)
            result["executable_unchanged"] = file_digest(exe) == result["executable_sha256"]
            if not all(result[key] for key in ("default_settings_unchanged", "default_contest_files_unchanged", "executable_unchanged")):
               result["passed"] = False
            if runtime_log.exists():
               with runtime_log.open("rb") as source:
                  source.seek(log_offset)
                  (output / "tr4w.log").write_bytes(source.read())
            result["cleanup"] = "Only the owned TR4W process was stopped; bridge jobs exit individually"
            (output / "result.json").write_text(json.dumps(result, indent=3), encoding="utf-8")
      try:
         # Restoration runs before releasing the exclusive lock and before
         # returning a verdict. A passing UI check cannot hide a restore error.
         cleanup.close()
         result["staged_release_restored"] = True
      except Exception:
         result["passed"] = False
         result["staged_release_restored"] = False
         result["restoration_error"] = traceback.format_exc()
      (output / "result.json").write_text(json.dumps(result, indent=3), encoding="utf-8")
   print(json.dumps({key: value for key, value in result.items() if key not in ("ax_hit_tests", "footer", "build_record")}, indent=3))
   return 0 if result["passed"] else 1


if __name__ == "__main__":
   raise SystemExit(main())
