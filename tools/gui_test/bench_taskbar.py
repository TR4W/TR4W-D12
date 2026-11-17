"""TR4W has a taskbar button while the New Contest dialog is up, and exactly one once the main window shows.

NY4I, 2026-11-16: with the startup New Contest dialog up the pinned TR4W icon showed
no "running" mark, and a click started a second copy. The fix (uLCLCoexist.
StartupTaskBarBehavior) shows the LCL's Application window, which carries the one
button until the main window shows.

WHAT IS ASSERTED IS A PROXY for the shell's rule, not the taskbar itself: a visible
top-level window of the process that is a taskbar candidate -- WS_EX_APPWINDOW, or
unowned and not WS_EX_TOOLWINDOW. Whether the pinned icon then shows "running" and
whether a click on it raises the dialog is judged on a desktop with the icon pinned
(BENCH_QUEUE).
"""

import json


GWL_EXSTYLE = -20
GW_OWNER = 4
WS_EX_TOOLWINDOW = 0x00000080
WS_EX_APPWINDOW = 0x00040000


def is_taskbar_candidate(visible, owner, exstyle):
   """The shell's rule for a top-level window's taskbar button."""
   if not visible:
      return False
   if exstyle & WS_EX_APPWINDOW:
      return True
   if exstyle & WS_EX_TOOLWINDOW:
      return False
   return owner == 0


def top_level_windows(pid):
   """Every top-level window of the process, with what the rule reads."""
   import ctypes
   from ctypes import wintypes

   user32 = ctypes.windll.user32
   user32.GetWindowLongPtrW.restype = ctypes.c_ssize_t
   user32.GetWindow.restype = wintypes.HWND
   found = []

   @ctypes.WINFUNCTYPE(wintypes.BOOL, wintypes.HWND, wintypes.LPARAM)
   def visit(hwnd, _):
      owner_pid = wintypes.DWORD()
      user32.GetWindowThreadProcessId(hwnd, ctypes.byref(owner_pid))
      if owner_pid.value == pid:
         title = ctypes.create_unicode_buffer(256)
         user32.GetWindowTextW(hwnd, title, 256)
         klass = ctypes.create_unicode_buffer(256)
         user32.GetClassNameW(hwnd, klass, 256)
         visible = bool(user32.IsWindowVisible(hwnd))
         owner = user32.GetWindow(hwnd, GW_OWNER) or 0
         exstyle = user32.GetWindowLongPtrW(hwnd, GWL_EXSTYLE) & 0xFFFFFFFF
         found.append({"hwnd": int(hwnd or 0), "title": title.value, "class": klass.value,
            "visible": visible, "owner": int(owner), "exstyle": hex(exstyle),
            "candidate": is_taskbar_candidate(visible, int(owner), exstyle)})
      return True

   user32.EnumWindows(visit, 0)
   return found


def window_state(hwnd):
   import ctypes

   user32 = ctypes.windll.user32
   return {"visible": bool(user32.IsWindowVisible(hwnd)), "iconic": bool(user32.IsIconic(hwnd)),
      "enabled": bool(user32.IsWindowEnabled(hwnd))}


def minimize_and_restore(button_hwnd, dialog_hwnd):
   """SC_MINIMIZE then SC_RESTORE to the window carrying the button: what two
   clicks on an active taskbar button send. Records, never asserts."""
   import ctypes
   import time

   user32 = ctypes.windll.user32
   WM_SYSCOMMAND = 0x0112
   SC_MINIMIZE = 0xF020
   SC_RESTORE = 0xF120
   record = {"before": window_state(dialog_hwnd)}
   user32.PostMessageW(button_hwnd, WM_SYSCOMMAND, SC_MINIMIZE, 0)
   time.sleep(1.5)
   record["after_minimize"] = window_state(dialog_hwnd)
   record["button_after_minimize"] = window_state(button_hwnd)
   user32.PostMessageW(button_hwnd, WM_SYSCOMMAND, SC_RESTORE, 0)
   time.sleep(1.5)
   record["after_restore"] = window_state(dialog_hwnd)
   record["button_after_restore"] = window_state(button_hwnd)
   record["foreground_is_dialog"] = user32.GetForegroundWindow() == dialog_hwnd
   return record


def check(app, startup, root, run_name, output, journal):
   # Here, not at the top: they import pywinauto, which the portable rule test
   # (test_bench_taskbar.py) must not need.
   from contest_forms import choose_contest, set_field, dismiss_grid_prompt
   from session import close_normally

   evidence = {}
   failures = []

   evidence_file = output / "taskbar-windows.json"
   windows = journal.perform("list windows with New Contest up", lambda: top_level_windows(app.process))
   evidence["new_contest"] = windows
   evidence_file.write_text(json.dumps(evidence, indent=3), encoding="utf-8")
   candidates = [window for window in windows if window["candidate"]]
   if not candidates:
      failures.append("New Contest up: no window of the process is a taskbar candidate")
   else:
      # Two clicks on the button minimize and restore its window. The modal must
      # come back: before the fix there was no button, so this could not happen.
      evidence["minimize_restore"] = journal.perform("minimize and restore through the button's window",
         lambda: minimize_and_restore(candidates[0]["hwnd"], startup.handle))
      evidence_file.write_text(json.dumps(evidence, indent=3), encoding="utf-8")
      after = evidence["minimize_restore"]["after_restore"]
      if not (after["visible"] and after["enabled"] and not after["iconic"]):
         failures.append("New Contest did not come back after minimize/restore: " + json.dumps(after))

   fields =choose_contest(startup, "CW Open", journal)
   if len(fields) != 1:
      raise AssertionError("CW Open needs one name field")
   set_field(fields[0], "TOM", journal)
   journal.perform("create CW Open log", lambda: startup.child_window(title_re="&?OK", class_name="Button").click_input())
   # The run folder holds the seed's CW Open log, so the same contest, date and
   # call collide: continue in it.
   existing = app.window(title="This contest already has a log")
   if existing.exists(timeout=5):
      journal.perform("open the seed's existing log",
         lambda: existing.child_window(title="Open existing log").click_input())
   main = app.window(title_re=r"TR4W v.*CWOPEN.*")
   main.wait("visible", timeout=30)
   dismiss_grid_prompt(app, journal)
   main.wait("enabled", timeout=10)

   windows = journal.perform("list windows with the main window up", lambda: top_level_windows(app.process))
   evidence["main_window"] = windows
   evidence["main_hwnd"] = main.handle
   candidates = [window for window in windows if window["candidate"]]
   if [window["hwnd"] for window in candidates] != [main.handle]:
      failures.append("Main window up: expected exactly one taskbar candidate, the main window; got " +
         json.dumps([(window["title"], window["class"]) for window in candidates]))

   evidence_file.write_text(json.dumps(evidence, indent=3), encoding="utf-8")
   close_normally(app, main, journal)
   if failures:
      raise AssertionError("; ".join(failures))
   return {"passed": True, "pid": app.process,
      "note": "taskbar candidate present under New Contest; only the main window once it shows (proxy for the shell)"}
