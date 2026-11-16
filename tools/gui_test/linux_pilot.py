"""Linux GTK2 navigation/accessibility pilot in a private X11/D-Bus session.

This is a scoped smoke test, not the Windows regression suite. No contacts,
radio definitions, or message memories are exercised. The application's
automatic NTP startup check still runs; this is not a network sandbox.
"""

import argparse
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import re
import signal
import shutil
import subprocess
import sys
import time
import traceback
import uuid

from evidence import StepLog, file_digest, native_build_identity
from fixture_data import contact_digest, contacts, prepare_offline_fixture


def command(*arguments):
   return subprocess.run(arguments, check=True, capture_output=True, text=True, timeout=10).stdout.strip()


def wait_for(description, observe, timeout=30):
   deadline = time.monotonic() + timeout
   while time.monotonic() < deadline:
      value = observe()
      if value:
         return value
      time.sleep(0.2)
   raise TimeoutError(description)


def windows(pid):
   result = []
   for line in command("wmctrl", "-lpG").splitlines():
      parts = line.split(None, 8)
      if len(parts) == 9 and int(parts[2]) == pid:
         result.append({"id": parts[0], "pid": pid, "title": parts[8],
            "rectangle": [int(value) for value in parts[3:7]]})
   return result


def find_window(process, title):
   if process.poll() is not None:
      raise RuntimeError("Owned application exited: " + str(process.returncode))
   matches = [row for row in windows(process.pid) if title in row["title"]]
   if len(matches) > 1:
      raise RuntimeError("Ambiguous owned window: " + repr(matches))
   return matches[0] if matches else None


def focus(window):
   def activate():
      command("xdotool", "windowactivate", "--sync", window["id"])
      return int(command("xdotool", "getactivewindow")) == int(window["id"], 16)
   wait_for("Owned window did not receive focus", activate, 5)


def capture(window, destination):
   from PIL import ImageGrab
   focus(window)
   previous = None
   for attempt in range(20):
      image = ImageGrab.grab()
      if image.size != (1280, 800):
         raise RuntimeError("Unexpected screen dimensions: " + repr(image.size))
      data = image.tobytes()
      if data == previous:
         if int(command("xdotool", "getactivewindow")) != int(window["id"], 16):
            # Startup may restore a tool window after the main form appears.
            # Retry within the same bound, never accept an obscured capture.
            focus(window)
            previous = None
            continue
         else:
            image.save(destination)
            return
      previous = data
      time.sleep(0.15)
   raise RuntimeError("Desktop did not settle for capture")


def accessible_nodes(pid):
   import gi
   gi.require_version("Atspi", "2.0")
   from gi.repository import Atspi
   desktop = Atspi.get_desktop(0)
   applications = [desktop.get_child_at_index(index) for index in range(desktop.get_child_count())]
   applications = [app for app in applications if app.get_process_id() == pid]
   if len(applications) != 1:
      return None
   records = []

   def visit(node, path):
      if len(records) >= 3000 or len(path) > 32:
         raise RuntimeError("Accessibility tree exceeds pilot limits")
      states = node.get_state_set()
      record = {"path": path, "role": node.get_role_name(), "name": node.get_name(),
         "showing": states.contains(Atspi.StateType.SHOWING),
         "enabled": states.contains(Atspi.StateType.ENABLED),
         "focused": states.contains(Atspi.StateType.FOCUSED)}
      component = node.get_component_iface()
      if component is not None:
         rect = component.get_extents(Atspi.CoordType.SCREEN)
         record["rectangle"] = [rect.x, rect.y, rect.width, rect.height]
      text = node.get_text_iface()
      if text is not None:
         record["text"] = Atspi.Text.get_text(text, 0, min(Atspi.Text.get_character_count(text), 4000))
      records.append((node, record))
      for index in range(node.get_child_count()):
         child = node.get_child_at_index(index)
         if child is not None:
            visit(child, path + [index])

   visit(applications[0], [])
   return records


def accessible_tree(pid):
   nodes = accessible_nodes(pid)
   return [record for node, record in nodes] if nodes is not None else None


class LinuxPreferences:
   def __init__(self, application, journal, output):
      self.application = application
      self.journal = journal
      self.output = output
      self.selected_path = None
      self.sequence = 0

   def nodes(self):
      nodes = accessible_nodes(self.application().pid)
      if not nodes:
         raise AssertionError("Owned AT-SPI application is unavailable")
      if any(record["showing"] and "access violation" in ((record["name"] or "") + " " + record.get("text", "")).lower()
         for node, record in nodes):
         raise RuntimeError("Owned application reported an access violation")
      roots = [record for node, record in nodes if record["role"] in ("frame", "dialog")
         and "Preferences" in (record["name"] or "") and record["showing"]]
      if len(roots) != 1:
         raise AssertionError("Preferences accessibility root is not unique")
      path = roots[0]["path"]
      return [(node, record) for node, record in nodes if record["path"][:len(path)] == path and record["showing"]]

   def open_preferences(self):
      main = wait_for("Owned main window", lambda: find_window(self.application(), "TR4W v."))
      focus(main)
      self.journal.perform("open Preferences", lambda: command("xdotool", "key", "--clearmodifiers", "ctrl+j"))
      prefs = wait_for("Preferences window", lambda: find_window(self.application(), "Preferences"))
      focus(prefs)

   def focus_node(self, node):
      from gi.repository import Atspi
      if not node.get_component_iface().grab_focus():
         raise AssertionError("AT-SPI could not focus the selected control")
      wait_for("Selected control focus", lambda: node.get_state_set().contains(Atspi.StateType.FOCUSED), 5)

   def selected(self):
      matches = [(node, record) for node, record in self.nodes() if record["path"] == self.selected_path]
      if len(matches) != 1 or matches[0][1]["role"] != "text" or not matches[0][1]["enabled"]:
         raise AssertionError("Selected setting is no longer an enabled visible text control")
      return matches[0]

   def select_setting(self, term):
      nodes = self.nodes()
      edits = [(node, record) for node, record in nodes if record["role"] == "text" and record["enabled"]]
      if not edits:
         raise AssertionError("No visible Preferences search field")
      ordered = sorted(edits, key=lambda item: (item[1]["rectangle"][0], item[1]["rectangle"][1]))
      search, search_record = ordered[0]
      self.focus_node(search)
      command("xdotool", "key", "--clearmodifiers", "ctrl+a")
      command("xdotool", "type", "--clearmodifiers", "--delay", "2", term)
      label = re.sub(r"[^a-z0-9]", "", term.lower())

      def search_result():
         matches = [(node, row) for node, row in self.nodes() if row["role"] == "table cell"
            and re.sub(r"[^a-z0-9]", "", (row["name"] or "").lower()) == label]
         if len(matches) > 1:
            raise AssertionError("Search result is ambiguous: " + term)
         return matches[0] if matches else None

      node, row = wait_for("Named search result " + term, search_result, 8)
      # The owner-drawn search row exposes its name and current bounds through
      # AT-SPI. Click that observed row, never a fixed screen position.
      x, y, width, height = row["rectangle"]
      if width <= 0 or height <= 0 or not row["enabled"]:
         raise AssertionError("Named search result is not clickable")
      target = (x + width // 2, y + height // 2)

      def click_result():
         prefs = find_window(self.application(), "Preferences")
         focus(prefs)
         left, top, frame_width, frame_height = prefs["rectangle"]
         if not (left <= target[0] < left + frame_width and top <= target[1] < top + frame_height):
            raise AssertionError("Search result is outside its owned Preferences window")
         # --sync waits for a motion event that never arrives if the pointer
         # is already here. Check its actual location instead.
         command("xdotool", "mousemove", str(target[0]), str(target[1]))

         def pointer_arrived():
            location = dict(line.split("=", 1) for line in command("xdotool", "getmouselocation", "--shell").splitlines())
            return (int(location["X"]), int(location["Y"])) == target

         wait_for("Pointer at named search row", pointer_arrived, 5)
         command("xdotool", "click", "1")

      self.journal.perform("select named search result " + term, click_result)

      def selected_setting():
         rows = self.nodes()
         focused = [record for node, record in rows if record["focused"] and record["role"] == "text"
            and record["path"] != search_record["path"]]
         return focused[0] if len(focused) == 1 else None

      record = wait_for("Search focused setting " + term, selected_setting, 8)
      self.selected_path = record["path"]
      self.sequence += 1
      tree = [row for node, row in self.nodes()]
      (self.output / f"setting-{self.sequence:02d}.json").write_text(json.dumps(tree, indent=3))
      if not any(label in re.sub(r"[^a-z0-9]", "", (row["name"] or "").lower()) for row in tree):
         raise AssertionError("Selected page does not expose the expected setting label: " + term)

   def read_value(self):
      return self.selected()[1]["text"]

   def write_value(self, value):
      node, record = self.selected()
      self.focus_node(node)
      command("xdotool", "key", "--clearmodifiers", "ctrl+a")
      command("xdotool", "type", "--clearmodifiers", "--delay", "2", value)
      wait_for("Setting edit displayed", lambda: self.read_value() == value, 5)

   def footer_state(self):
      result = {}
      nodes = self.nodes()
      for caption in ("Save", "Save and close", "Cancel"):
         matches = [record for node, record in nodes if record["role"] == "button" and record["name"] == caption]
         if len(matches) != 1:
            raise AssertionError("Footer button is not unique: " + caption)
         result[caption] = matches[0]["enabled"]
      return result

   def activate_footer(self, caption):
      matches = [(node, record) for node, record in self.nodes() if record["role"] == "button" and record["name"] == caption]
      if len(matches) != 1 or not matches[0][1]["enabled"]:
         raise AssertionError("Footer is not uniquely enabled: " + caption)
      self.journal.perform("activate Preferences " + caption, lambda: self.focus_node(matches[0][0]))
      command("xdotool", "key", "--clearmodifiers", "space")
      if caption == "Save":
         wait_for("Save finished and cleared dirty state", lambda: not self.footer_state()["Save"], 10)
      else:
         wait_for("Preferences dismissed", lambda: not find_window(self.application(), "Preferences"), 10)


class DebuggedApplication:
   """Keep the inferior's UI PID separate from GDB's wait/exit-status PID."""

   def __init__(self, controller, pid):
      self.controller = controller
      self.pid = pid

   @property
   def returncode(self):
      return self.controller.returncode

   def poll(self):
      return self.controller.poll()

   def wait(self, timeout):
      return self.controller.wait(timeout=timeout)

   def terminate(self):
      try:
         os.kill(self.pid, signal.SIGTERM)
      except ProcessLookupError:
         pass
      self.controller.terminate()

   def kill(self):
      try:
         os.kill(self.pid, signal.SIGKILL)
      except ProcessLookupError:
         pass
      self.controller.kill()


def launch_application(arguments, run, output, log, debug):
   if not debug:
      return subprocess.Popen(arguments, cwd=run, stdout=log, stderr=subprocess.STDOUT)
   # Restarts must not adopt a previous inferior's PID file.
   pid_file = output / ("gdb-inferior-" + uuid.uuid4().hex[:8] + ".pid")
   script = pid_file.with_suffix(".gdb")
   script.write_text("\n".join([
      "set pagination off", "set confirm off", "set auto-load off",
      "set print thread-events off", "set startup-with-shell off",
      "handle SIGPIPE nostop noprint pass",
      "break FPC_RAISEEXCEPTION", "commands", "silent",
      'printf "\\n=== Pascal exception raised ===\\n"',
      "x/a $rdi", "bt full 30", "continue", "end",
      "catch signal SIGSEGV", "commands", "silent",
      'printf "\\n=== SIGSEGV before Pascal handling ===\\n"',
      "thread apply all bt full 40", "continue", "end",
      "starti",
      "python open(" + repr(str(pid_file)) + ", 'w').write(str(gdb.selected_inferior().pid))",
      "continue", "",
   ]), encoding="utf-8")
   controller = subprocess.Popen(["gdb", "-nx", "-batch", "--return-child-result",
      "-x", str(script), "--args", *arguments], cwd=run, stdout=log, stderr=subprocess.STDOUT)
   try:
      def inferior_pid():
         if controller.poll() is not None:
            raise RuntimeError("GDB exited before launching the application; see processes.log")
         return int(pid_file.read_text()) if pid_file.exists() and pid_file.stat().st_size else None
      return DebuggedApplication(controller, wait_for("GDB inferior startup", inferior_pid, 20))
   except BaseException:
      controller.terminate()
      controller.wait(timeout=10)
      raise


def worker(args):
   run = args.root / "runs" / args.run
   output = args.root / "artifacts" / args.run
   journal = StepLog(output / "steps.jsonl")
   exe = args.root / "app" / "tr4w"
   result = {"passed": False, "checks": [], "case": args.case, **native_build_identity(exe, args.build_record),
      "display": os.environ.get("DISPLAY"), "run": str(run)}
   archive = args.root / "evidence" / result["executable_sha256"]
   archive.mkdir(parents=True, exist_ok=True)
   archived_exe = archive / "tr4w"
   if archived_exe.exists():
      if file_digest(archived_exe) != result["executable_sha256"]:
         raise RuntimeError("Archived executable does not match its hash")
   else:
      shutil.copy2(exe, archived_exe)
   result["executable_archive"] = str(archived_exe)
   default_contests = Path.home() / "tr4w"

   def contest_inventory():
      if not default_contests.exists():
         return None
      return {str(path.relative_to(default_contests)): [path.stat().st_size, path.stat().st_mtime_ns]
         for path in default_contests.rglob("*") if path.is_file()}

   contests_before = contest_inventory()
   wm = None
   app = None
   with (output / "processes.log").open("w") as log:
      try:
         wm = subprocess.Popen(["openbox"], stdout=log, stderr=subprocess.STDOUT)

         def wm_ready():
            if wm.poll() is not None:
               raise RuntimeError("Openbox exited")
            probe = subprocess.run(["wmctrl", "-m"], capture_output=True, text=True, timeout=5)
            return probe.stdout if probe.returncode == 0 else None

         result["window_manager"] = wait_for("Openbox startup", wm_ready, 10)
         original_contacts = contacts(run / "practice.db")
         if not original_contacts:
            raise RuntimeError("Pilot requires a nonempty practice fixture")
         original_columns = list(original_contacts[0])
         before = contact_digest(run / "practice.db", original_columns)
         def launch_owned():
            nonlocal app
            app = journal.perform("launch owned application", lambda: launch_application(
               # Relative paths avoid the separately tracked slash-switch bug.
               [str(exe), "./practice.db", "--settings", str(run / "tr4w.json"), "--lang", "en"],
               run, output, log, args.gdb))
            result["pid"] = app.pid
            result.setdefault("application_pids", []).append(app.pid)
            (output / "owned-process.json").write_text(json.dumps({"pid": app.pid, "exe": str(exe)}))
            window = wait_for("Main window", lambda: find_window(app, "TR4W v."))
            if "Open configuration file" in window["title"]:
               raise AssertionError("New Contest opened instead of the practice log")
            return window

         def close_owned():
            main_window = find_window(app, "TR4W v.")
            journal.perform("request normal close", lambda: command("wmctrl", "-ic", main_window["id"]))

            def exit_question():
               tree = accessible_tree(app.pid)
               if tree:
                  (output / "exit-tree.json").write_text(json.dumps(tree, indent=3), encoding="utf-8")
                  return any("really want to exit" in ((row.get("text") or "") + " " + (row["name"] or "")).lower()
                     and row["showing"] for row in tree)
               return False

            wait_for("Exit confirmation", exit_question, 10)
            journal.perform("confirm observed exit question", lambda: command("xdotool", "key", "--clearmodifiers", "alt+y"))
            app.wait(timeout=15)
            result["application_exit_code"] = app.returncode
            result.setdefault("application_exit_codes", []).append(app.returncode)
            if contact_digest(run / "practice.db", original_columns) != before:
               raise AssertionError("Original practice contact values changed")
            if app.returncode != 0:
               raise AssertionError("Application exit status: " + str(app.returncode))

         def restart():
            close_owned()
            launch_owned()

         main = launch_owned()
         result["main_window"] = main
         journal.perform("capture main window", lambda: capture(main, output / "main.png"))
         tree = wait_for("PID-scoped AT-SPI application", lambda: accessible_tree(app.pid), 15)
         (output / "main-tree.json").write_text(json.dumps(tree, indent=3), encoding="utf-8")
         result["checks"].append("Isolated practice log opened and AT-SPI application identified by PID")
         journal.perform("open Preferences with Ctrl+J", lambda: command("xdotool", "key", "--clearmodifiers", "ctrl+j"))
         preferences = wait_for("Preferences window", lambda: find_window(app, "Preferences"), 15)
         journal.perform("capture Preferences", lambda: capture(preferences, output / "preferences.png"))
         tree = accessible_tree(app.pid)
         (output / "preferences-tree.json").write_text(json.dumps(tree, indent=3), encoding="utf-8")
         (output / "windows.json").write_text(json.dumps(windows(app.pid), indent=3), encoding="utf-8")
         # Scope footer assertions to the actual Preferences subtree, not a
         # similarly named button in another owned window.
         roots = [row for row in tree if "Preferences" in (row["name"] or "") and row["role"] in ("frame", "dialog")]
         if len(roots) != 1:
            raise AssertionError("Preferences accessibility root is not unique")
         path = roots[0]["path"]
         buttons = [row for row in tree if row["path"][:len(path)] == path
            and row["role"] == "button" and row["showing"]]
         captions = [row["name"].replace("_", "").replace("&", "") for row in buttons]
         for caption in ("Save and close", "Cancel", "Save"):
            if captions.count(caption) != 1:
               raise AssertionError("Expected unique visible Preferences button: " + caption + "; observed " + repr(captions))
         result["footer"] = [{"name": row["name"], "enabled": row["enabled"]} for row in buttons
            if row["name"] in ("Save and close", "Cancel", "Save")]
         if any(row["enabled"] != (row["name"] != "Save") for row in result["footer"]):
            raise AssertionError("Unexpected clean Preferences footer state")
         result["checks"].append("AT-SPI exposes clean Preferences footer: Save disabled, Save and close/Cancel enabled")
         journal.perform("close Preferences with Escape", lambda: command("xdotool", "key", "--clearmodifiers", "Escape"))
         wait_for("Preferences dismissal", lambda: not find_window(app, "Preferences"), 10)
         result["checks"].append("Escape dismissed Preferences")
         result["navigation_passed"] = True
         if args.case == "preferences-persistence":
            from preferences_roundtrip import run_preferences_roundtrip
            driver = LinuxPreferences(lambda: app, journal, output)
            result["preferences_persistence"] = {}
            run_preferences_roundtrip(driver, run / "tr4w.json", restart, journal, result["preferences_persistence"])
            result["checks"].extend(result["preferences_persistence"]["checks"])
         close_owned()
         result["contact_count"] = len(original_contacts)
         result["added_contact_columns"] = sorted(set(contacts(run / "practice.db")[0]) - set(original_columns))
         if contact_digest(run / "practice.db", original_columns) != before:
            raise AssertionError("Practice contacts changed during navigation")
         result["checks"].append("All original contact fields unchanged after application exit; migration columns recorded separately")
         result["checks"].append("Normal application exit")
         result["passed"] = True
      except Exception:
         result["error"] = traceback.format_exc()
         try:
            from PIL import ImageGrab
            ImageGrab.grab().save(output / "failure.png")
            if app is not None and app.poll() is None:
               (output / "windows.json").write_text(json.dumps(windows(app.pid), indent=3), encoding="utf-8")
               (output / "failure-tree.json").write_text(json.dumps(accessible_tree(app.pid), indent=3), encoding="utf-8")
         except Exception:
            result["diagnostic_error"] = traceback.format_exc()
      finally:
         for process in (app, wm):
            if process is not None and process.poll() is None:
               process.terminate()
               try:
                  process.wait(timeout=10)
               except subprocess.TimeoutExpired:
                  process.kill()
                  process.wait(timeout=5)
         result["cleanup"] = "Only owned application/window-manager PIDs stopped"
         result["default_contest_files_unchanged"] = contests_before == contest_inventory()
         if not result["default_contest_files_unchanged"]:
            result["passed"] = False
         result["executable_unchanged"] = file_digest(exe) == result["executable_sha256"]
         if not result["executable_unchanged"]:
            result["passed"] = False
         runtime = output / "runtime"
         runtime.mkdir()
         for path in run.rglob("*.log"):
            target = runtime / path.relative_to(run)
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(path, target)
         (output / "result.json").write_text(json.dumps(result, indent=3), encoding="utf-8")
   print(json.dumps(result, indent=3))
   return 0 if result["passed"] else 1


def main():
   parser = argparse.ArgumentParser(description=__doc__)
   parser.add_argument("--root", type=Path, default=Path.home() / "tr4w-gui-test")
   parser.add_argument("--run", default=datetime.now(timezone.utc).strftime("linux-%Y%m%dT%H%M%S-") + uuid.uuid4().hex[:6])
   parser.add_argument("--database-template", type=Path)
   parser.add_argument("--settings-template", type=Path, default=Path(__file__).parent / "fixtures/tr4w.json")
   parser.add_argument("--worker", action="store_true", help=argparse.SUPPRESS)
   parser.add_argument("--gdb", action="store_true", help="Capture Pascal exception stacks under GDB")
   parser.add_argument("--build-record", type=Path, help="Digest-matched source/build provenance JSON")
   parser.add_argument("--case", choices=("smoke", "preferences-persistence"), default="smoke")
   args = parser.parse_args()
   if sys.platform != "linux":
      parser.error("Run this pilot on Linux using the system Python")
   if args.gdb and os.uname().machine != "x86_64":
      parser.error("The GDB exception-register diagnostic currently supports Linux x86_64 only")
   args.root = args.root.resolve()
   allowed = (Path.home() / "tr4w-gui-test").resolve()
   if args.root != allowed or not re.fullmatch(r"[A-Za-z0-9-]+", args.run):
      parser.error("Use ~/tr4w-gui-test and an alphanumeric/hyphen run name")
   if args.worker:
      return worker(args)
   if args.database_template is None:
      parser.error("--database-template must name a stopped repository fixture")
   import fcntl
   with (args.root / "pilot.lock").open("a") as lock:
      fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
      run = args.root / "runs" / args.run
      output = args.root / "artifacts" / args.run
      run.mkdir()
      output.mkdir()
      prepare_offline_fixture(args.database_template, args.settings_template, run)
      environment = os.environ.copy()
      for name in ("DBUS_SESSION_BUS_ADDRESS", "AT_SPI_BUS_ADDRESS", "SESSION_MANAGER"):
         environment.pop(name, None)
      for name in ("CONFIG", "DATA", "STATE", "CACHE"):
         directory = run / name.lower()
         directory.mkdir()
         environment["XDG_" + name + "_HOME"] = str(directory)
      # This pilot has no credentials. libsecret otherwise tries to activate
      # the user's existing keyring on the PRIVATE bus, where it can wait 25s
      # per lookup. Make this external service explicitly unavailable in this
      # test session, without changing the desktop's bus or keyring.
      services = run / "data/dbus-1/services"
      services.mkdir(parents=True)
      (services / "org.freedesktop.secrets.service").write_text(
         "[D-BUS Service]\nName=org.freedesktop.secrets\nExec=/usr/bin/false\n", encoding="utf-8")
      environment.update(GTK_MODULES="gail:atk-bridge", GNOME_ACCESSIBILITY="1", NO_AT_BRIDGE="0", GIO_USE_VFS="local")
      arguments = ["xvfb-run", "-a", "-s", "-screen 0 1280x800x24 -dpi 96 -nolisten tcp",
         "dbus-run-session", "--", sys.executable, str(Path(__file__).resolve()),
         "--root", str(args.root), "--run", args.run, "--worker"]
      arguments.extend(["--case", args.case])
      if args.gdb:
         arguments.append("--gdb")
      if args.build_record:
         arguments.extend(["--build-record", str(args.build_record.resolve())])
      process = subprocess.Popen(arguments, env=environment, start_new_session=True)
      try:
         return process.wait(timeout=150)
      except (subprocess.TimeoutExpired, KeyboardInterrupt):
         os.killpg(process.pid, signal.SIGTERM)
         try:
            process.wait(timeout=10)
         except subprocess.TimeoutExpired:
            os.killpg(process.pid, signal.SIGKILL)
            process.wait(timeout=5)
         (output / "timeout.json").write_text(json.dumps({"passed": False, "error": "Worker timed out or was interrupted; owned process group stopped"}))
         return 2


if __name__ == "__main__":
   raise SystemExit(main())
