"""Use Tailcat ticked with NO stored address: one warning, and never a connection to Server.

Needs no secret. The fixture sets SERVER USE TAILCAT on and SERVER ADDRESS to a
TEST-NET-1 address (192.0.2.10, RFC 5737), so a quiet fall back to Server would
show as a connect attempt to that address in tr4w.log. The test user's vault
holds no Tailcat address, so the setting reads empty.
"""

import json
import time

from pywinauto import Application

from session import capture, describe_windows, menu_paths


FALLBACK_ADDRESS = "192.0.2.10"


def log_text(root, run_name):
   path = root / "runs" / run_name / "tr4w.log"
   return path.read_text(encoding="utf-8", errors="replace") if path.exists() else ""


def extra_windows(app, main):
   return [window for window in app.windows() if window.is_visible() and window.handle != main.handle]


def window_body(app, window):
   texts = [control.window_text() for control in window.descendants() if control.window_text().strip()]
   if not texts:
      uiapp = Application(backend="uia").connect(process=app.process)
      texts = [control.window_text() for control in uiapp.window(handle=window.handle).descendants()
         if control.window_text().strip()]
   return texts


def menu_entry(main, words):
   entries = [entry for entry in menu_paths(main)
      if entry["path"].replace("&", "").split("\t")[0].split("->") == words]
   if len(entries) != 1 or not entries[0]["enabled"]:
      raise RuntimeError("Menu " + "->".join(words) + " not unique/enabled: " + repr(entries))
   return entries[0]["path"]


def check(app, main, root, run_name, output, journal, phase):
   observations = {"menus": [entry["path"] for entry in menu_paths(main) if entry["path"].startswith(("Net", "&Net"))]}
   warnings = []
   time.sleep(3)
   existing = extra_windows(app, main)
   observations["windows_before_connect"] = [window.window_text() for window in existing]
   already = {window.handle for window in existing}
   path = menu_entry(main, ["Net", "Connect"])
   started = time.monotonic()
   journal.perform("menu " + path, lambda: main.menu_select(path))
   deadline = time.monotonic() + 35
   while time.monotonic() < deadline:
      for window in [window for window in extra_windows(app, main) if window.handle not in already]:
         body = window_body(app, window)
         seconds = round(time.monotonic() - started, 2)
         capture(window, output / ("tailcat-warning-" + str(len(warnings)) + ".png"))
         warnings.append({"seconds_after_connect": seconds, "title": window.window_text(),
            "class": window.class_name(), "body": body})
         buttons = [control for control in window.descendants(class_name="Button")
            if control.window_text().replace("&", "") == "OK"]
         if len(buttons) != 1:
            raise RuntimeError("Warning has no unique OK button: " + repr(body))
         journal.perform("acknowledge Tailcat warning", buttons[0].click_input)
         # app.windows() returns plain wrappers with no wait_not; watch the handle.
         import win32gui
         closing = time.monotonic() + 10
         while win32gui.IsWindow(window.handle) and win32gui.IsWindowVisible(window.handle):
            if time.monotonic() > closing:
               raise RuntimeError("Tailcat warning did not close after OK")
            time.sleep(0.1)
      time.sleep(0.25)
   log = log_text(root, run_name)
   observations["warnings"] = warnings
   observations["tailcat_log_lines"] = [line for line in log.splitlines() if "[Net] Tailcat" in line][:40]
   observations["fallback_lines"] = [line for line in log.splitlines() if FALLBACK_ADDRESS in line][:40]
   observations["net_lines"] = [line for line in log.splitlines() if "[Net]" in line][:80]
   capture(main, output / "tailcat-after.png")
   path = menu_entry(main, ["Net", "Disconnect"])
   journal.perform("menu " + path, lambda: main.menu_select(path))
   time.sleep(2)
   for window in extra_windows(app, main):
      observations.setdefault("windows_after_disconnect", []).append(
         {"title": window.window_text(), "body": window_body(app, window)})
   describe_windows(app, output)
   (output / "tailcat-observations.json").write_text(json.dumps(observations, indent=3), encoding="utf-8")
   failures = []
   if len(warnings) != 1:
      failures.append("Expected exactly one warning, saw " + str(len(warnings)))
   if observations["fallback_lines"]:
      failures.append("tr4w.log names SERVER ADDRESS " + FALLBACK_ADDRESS + ": the link fell back to Server")
   result = {"passed": not failures, "phase": phase, "warning_count": len(warnings)}
   if failures:
      result["failures"] = failures
   return result
