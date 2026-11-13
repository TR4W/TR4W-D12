"""Shared PID-scoped launch, evidence capture and diagnostics for GUI scenarios."""

import subprocess
import hashlib
import json
import time
from pathlib import Path

from pywinauto import Application
from window_capture import capture_window
from evidence import preserve_build


def launch(root, run_name="pilot-001", contest="practice.db"):
   root = Path(root).resolve()
   run = root / "runs" / run_name
   exe = root / "app" / "tr4w_fpc.exe"
   preserve_build(exe, root / "evidence")
   settings = run / "tr4w.json"
   required = [exe, settings]
   if contest:
      required.append(run / contest)
   for path in required:
      if not path.is_file():
         raise FileNotFoundError(path)
   arguments = [str(exe)]
   if contest:
      arguments.append(str(run / contest))
   arguments.extend(["--settings", str(settings), "--lang", "en"])
   app = Application(backend="win32").start(
      subprocess.list2cmdline(arguments), work_dir=str(run), wait_for_idle=False
   )
   record_owned_process(root, run_name, app.process)
   return app


def record_owned_process(root, run_name, pid):
   root = Path(root)
   (root / "runs" / run_name / "owned-process.json").write_text(json.dumps({"pid": pid,
      "executable": str(root / "app" / "tr4w_fpc.exe")}), encoding="utf-8")


def adopt_restarted_app(previous, root, run_name, database, output, wait_main=True):
   previous.wait_for_process_exit(timeout=30)
   expected_exe = str((Path(root) / "app" / "tr4w_fpc.exe").resolve())
   expected_settings = str((Path(root) / "runs" / run_name / "tr4w.json").resolve())
   query = "Get-CimInstance Win32_Process -Filter \"Name='tr4w_fpc.exe'\" | Select-Object ProcessId,ExecutablePath,CommandLine | ConvertTo-Json -Compress"
   deadline = time.monotonic() + 30
   while time.monotonic() < deadline:
      process = subprocess.run(["powershell.exe", "-NoProfile", "-NonInteractive", "-Command", query],
         capture_output=True, text=True, timeout=20, creationflags=subprocess.CREATE_NO_WINDOW)
      if process.returncode:
         raise RuntimeError("Could not identify the replacement process: " + process.stderr)
      rows = json.loads(process.stdout or "[]")
      if isinstance(rows, dict):
         rows = [rows]
      matches = [row for row in rows if (row.get("ExecutablePath") or "").casefold() == expected_exe.casefold()
         and expected_settings.casefold() in (row.get("CommandLine") or "").casefold()]
      if len(matches) == 1:
         identity = matches[0]
         break
      if len(matches) > 1:
         raise RuntimeError("More than one process matches the owned settings")
      time.sleep(0.2)
   else:
      raise RuntimeError("Replacement process did not preserve the owned executable/settings")
   pid = identity["ProcessId"]
   record_owned_process(root, run_name, pid)
   Path(output).write_text(json.dumps({"previous_pid": previous.process, "new_pid": pid,
      "identity": identity, "expected_database": str(database)}, indent=3), encoding="utf-8")
   app = Application(backend="win32").connect(process=pid)
   main = app.window(title_re=r"TR4W v.*")
   if wait_main:
      main.wait("visible enabled", timeout=30)
   return app, main


def capture(window, path, region=None):
   # Use this HWND's visible foreground frame, excluding invisible resize borders.
   window.set_focus()
   # Visible does not mean painted: capture only after the opening animation settles.
   previous = None
   deadline = time.monotonic() + 3
   while time.monotonic() < deadline:
      image = capture_window(window.handle, region=region)
      digest = hashlib.sha256(image.tobytes()).digest()
      if digest == previous:
         image.save(path)
         return
      previous = digest
      time.sleep(0.2)
   raise RuntimeError("Window did not become visually stable for screenshot capture")


def close_normally(app, main, journal):
   notice = app.window(class_name="#32770")
   if not notice.exists(timeout=0):
      journal.perform("request normal close to save messages", lambda: main.post_message(0x0010))
   journal.perform("wait for exit confirmation", lambda: notice.wait("visible", timeout=10))
   text = notice_text(app, notice)
   if "really want to exit" not in text:
      raise RuntimeError("Unexpected close confirmation: " + text)
   journal.perform("confirm normal exit", lambda: notice.child_window(title="&Yes").click_input())
   journal.perform("wait for owned application exit", lambda: app.wait_for_process_exit(timeout=20))


def notice_text(app, notice):
   import win32gui
   uiapp = Application(backend="uia").connect(process=app.process)
   handle = notice.handle
   deadline = time.monotonic() + 5
   last_error = None
   while time.monotonic() < deadline:
      if not win32gui.IsWindowVisible(handle):
         raise LookupError("Notice disappeared before its body could be read")
      try:
         native = app.window(handle=handle).descendants(class_name="Static")
         body = [control.window_text() for control in native if control.window_text().strip()]
         if body:
            return " ".join(body)
         controls = uiapp.window(handle=handle).descendants()
         body = [control.window_text() for control in controls
            if control.element_info.control_type == "Text" and control.window_text().strip()]
         if body:
            return " ".join(body)
      except Exception as error:
         last_error = error
      time.sleep(0.1)
   raise RuntimeError("Visible notice has no readable body text: " + repr(last_error))


def menu_paths(main):
   result = []

   def visit(menu, parents, depth):
      if depth > 4:
         raise RuntimeError("Unexpected menu depth")
      for item in menu.items():
         text = item.text()
         if text == "-":
            continue
         path = parents + [text]
         submenu = item.sub_menu()
         if submenu is not None:
            visit(submenu, path, depth + 1)
         else:
            result.append({"path": "->".join(path), "text": text, "enabled": item.is_enabled()})

   visit(main.menu(), [], 0)
   return result


def select_menu(main, words, journal):
   matches = [entry for entry in menu_paths(main)
      if all(word.casefold() in entry["path"].replace("&", "").casefold() for word in words)]
   if len(matches) != 1 or not matches[0]["enabled"]:
      raise RuntimeError("Menu command not unique/enabled: " + repr(matches))
   journal.perform("menu " + matches[0]["path"], lambda: main.menu_select(matches[0]["path"]))


def choose_file(app, path, journal):
   dialog = app.window(class_name="#32770", visible_only=True)
   dialog.wait("visible enabled", timeout=10)
   opened = app.window(handle=dialog.handle)
   fields = [control for control in dialog.descendants(class_name="Edit")
      if control.is_visible() and control.is_enabled()]
   if not fields:
      raise RuntimeError("Native file dialog has no filename field")
   field = max(fields, key=lambda control: control.rectangle().top)
   if field.rectangle().top < dialog.rectangle().mid_point().y or field.rectangle().width() < 100:
      raise RuntimeError("Filename selector does not match the observed native dialog")
   journal.perform("choose isolated file " + path.name, lambda: field.set_edit_text(str(path)))
   dialog.child_window(title_re="&?Open", class_name="Button").click_input()
   opened.wait_not("visible", timeout=15)


def click_context_menu(owner, prefix, journal):
   import ctypes
   from ctypes import wintypes
   from pywinauto import Desktop, mouse
   import win32gui
   menu = Desktop(backend="win32").window(class_name="#32768", visible_only=True)
   menu.wait("visible", timeout=5)
   # MN_GETHMENU retrieves the visible native popup's menu handle. Selection
   # uses the actual caption/rectangle; it never guesses a menu item ordinal.
   handle = win32gui.SendMessage(menu.handle, 0x01E1, 0, 0)
   if not handle:
      raise RuntimeError("Visible popup has no menu handle")
   user32 = ctypes.WinDLL("user32", use_last_error=True)
   read_text = user32.GetMenuStringW
   read_text.argtypes = [wintypes.HMENU, wintypes.UINT, wintypes.LPWSTR, ctypes.c_int, wintypes.UINT]
   read_text.restype = ctypes.c_int
   choices = []
   for index in range(win32gui.GetMenuItemCount(handle)):
      buffer = ctypes.create_unicode_buffer(1024)
      count = read_text(handle, index, buffer, len(buffer), 0x400)
      if count >= len(buffer) - 1:
         raise RuntimeError("Context caption exceeds the read buffer")
      choices.append((index, buffer.value))
   matches = [(index, text) for index, text in choices if text.replace("&", "").casefold().startswith(prefix.casefold())]
   if len(matches) != 1:
      raise RuntimeError("Context action not unique: " + repr(choices))
   read_rectangle = user32.GetMenuItemRect
   read_rectangle.argtypes = [wintypes.HWND, wintypes.HMENU, wintypes.UINT, ctypes.POINTER(wintypes.RECT)]
   read_rectangle.restype = wintypes.BOOL
   bounds = wintypes.RECT()
   if not read_rectangle(owner.handle, handle, matches[0][0], ctypes.byref(bounds)):
      raise ctypes.WinError(ctypes.get_last_error())
   rectangle = (bounds.left, bounds.top, bounds.right, bounds.bottom)
   journal.perform("context action " + matches[0][1], lambda: mouse.click(
      coords=((rectangle[0] + rectangle[2]) // 2, (rectangle[1] + rectangle[3]) // 2)))


def acknowledge_notice(app, required_parts, journal, screenshot=None):
   notice = app.window(class_name="#32770")
   notice.wait("visible", timeout=10)
   opened = app.window(handle=notice.handle)
   text = notice_text(app, notice)
   if not all(part in text for part in required_parts):
      raise RuntimeError("Unexpected notice: " + text)
   if screenshot is not None:
      capture(notice, screenshot)
   buttons = [control for control in notice.descendants(class_name="Button")
      if control.window_text().replace("&", "") == "OK"]
   if len(buttons) != 1:
      raise RuntimeError("Notice OK button not unique")
   journal.perform("acknowledge expected notice", buttons[0].click_input)
   opened.wait_not("visible", timeout=10)
   return text


def hover_control(control):
   from pywinauto import mouse
   import win32gui
   rectangle = control.rectangle()
   point = ((rectangle.left + rectangle.right) // 2, (rectangle.top + rectangle.bottom) // 2)
   mouse.move(coords=point)
   if win32gui.GetCursorPos() != point:
      raise RuntimeError("Mouse did not reach the requested control")


def wait_for_hint(timeout=3):
   from pywinauto import Desktop
   deadline = time.monotonic() + timeout
   while time.monotonic() < deadline:
      windows = [window for window in Desktop(backend="win32").windows()
         if window.is_visible() and window.class_name() in {"HintWindow", "tooltips_class32"}]
      if windows:
         return windows
      time.sleep(0.1)
   return []


def answer_question(app, expected_text, journal, screenshot=None, timeout=3, answer="No"):
   if answer not in {"Yes", "No"}:
      raise ValueError("Only explicit Yes/No answers are supported")
   # Visible only, bound to one handle, and re-resolved while a notice vanishes
   # under us: a transient #32770 once "disappeared" before its body was read
   # while the real question was already on screen (euhfc-yes, 2026-11-13).
   spec = app.window(class_name="#32770", visible_only=True)
   if not spec.exists(timeout=timeout):
      return False
   deadline = time.monotonic() + 10
   while True:
      notice = app.window(handle=spec.handle)
      try:
         text = notice_text(app, notice)
         break
      except LookupError:
         if time.monotonic() > deadline or not spec.exists(timeout=2):
            raise
   opened = notice
   if expected_text not in text:
      raise RuntimeError("Unclassified question: " + text)
   if screenshot is not None:
      capture(notice, screenshot)
   buttons = [control for control in notice.descendants(class_name="Button")
      if control.window_text().replace("&", "") == answer]
   if len(buttons) != 1:
      raise RuntimeError("Question's answer button is not unique")
   journal.perform("answer " + answer + ": " + expected_text, buttons[0].click_input)
   opened.wait_not("visible", timeout=10)
   return True


def dialog_facts(app, title, timeout=10):
   """Read a modal question WITHOUT answering it: its class, body text, every
   button and which one is the default. Works for an LCL QuestionDlg form and
   a native #32770 / TaskDialog alike, because it reads both the win32 buttons
   (BS_DEFPUSHBUTTON is the default) and UI Automation (whose buttons a
   TaskDialog draws without windows). The focused element is recorded too: in
   both kinds the default button starts with the keyboard focus."""
   import win32gui
   import win32con
   from pywinauto.uia_defines import IUIA
   dialog = app.window(title=title, visible_only=True)
   dialog.wait("visible", timeout=timeout)
   facts = {"title": dialog.window_text(), "class": dialog.class_name(), "handle": dialog.handle,
      "win32_buttons": [], "uia_buttons": [], "uia_texts": [], "win32_texts": []}
   for control in dialog.descendants():
      if not control.is_visible():
         continue
      if control.class_name() == "Button":
         style = win32gui.GetWindowLong(control.handle, win32con.GWL_STYLE)
         facts["win32_buttons"].append({"text": control.window_text(), "handle": control.handle,
            "default_style": (style & 0x0F) == win32con.BS_DEFPUSHBUTTON})
      elif control.window_text().strip():
         facts["win32_texts"].append({"class": control.class_name(), "text": control.window_text()})
   uiapp = Application(backend="uia").connect(process=app.process)
   for control in uiapp.window(handle=dialog.handle).descendants():
      kind = control.element_info.control_type
      name = control.element_info.element.CurrentName
      if kind == "Button":
         facts["uia_buttons"].append(name)
      elif kind == "Text" and name.strip():
         facts["uia_texts"].append(name)
   try:
      focused = IUIA().iuia.GetFocusedElement()
      facts["focused"] = {"name": focused.CurrentName, "type": focused.CurrentLocalizedControlType,
         "handle": focused.CurrentNativeWindowHandle}
   except Exception as error:
      facts["focused_error"] = repr(error)
   # The title-bar Close of a TaskDialog is a UIA button too; it is not an answer.
   facts["answers"] = [name for name in facts["uia_buttons"] if name.replace("&", "") != "Close"]
   defaults = [button["text"] for button in facts["win32_buttons"] if button["default_style"]]
   facts["default"] = defaults[0] if len(defaults) == 1 else facts.get("focused", {}).get("name")
   return dialog, facts


def click_dialog_button(app, dialog, caption, journal):
   """Press the named answer of a dialog read by dialog_facts, by its caption."""
   uiapp = Application(backend="uia").connect(process=app.process)
   buttons = [control for control in uiapp.window(handle=dialog.handle).descendants(control_type="Button")
      if control.element_info.element.CurrentName.replace("&", "") == caption]
   if len(buttons) != 1:
      raise RuntimeError("Dialog button not unique: " + caption)
   handle = dialog.handle
   journal.perform("answer " + caption, buttons[0].click_input)
   app.window(handle=handle).wait_not("visible", timeout=10)


def describe_windows(app, output):
   import json

   windows = []
   for window in app.windows():
      item = {"title": window.window_text(), "class": window.class_name()}
      item["controls"] = [
         {
            "text": control.window_text(),
            "class": control.class_name(),
            "handle": control.handle,
            "visible": control.is_visible(),
            "enabled": control.is_enabled(),
            "rect": {
               key: getattr(control.rectangle(), key)
               for key in ("left", "top", "right", "bottom")
            },
         }
         for control in window.descendants()
      ]
      windows.append(item)
   (output / "windows.json").write_text(
      json.dumps(windows, indent=3), encoding="utf-8"
   )
