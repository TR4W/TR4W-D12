"""Guest-side helpers for the input-validation cases: which top-level windows
the owned process shows, what a new one says, how to dismiss it, and reading
windowless text by OCR. Windows only (win32 + pywinauto)."""

import subprocess
import time
from pathlib import Path

import win32gui
import win32process
from PIL import Image

from input_checks import TRANSIENT_WINDOW_CLASSES

OCR_SCRIPT = Path(__file__).resolve().parent / "ocr_text.ps1"


def owned_windows(pid):
   """{handle: (class, title)} of the VISIBLE top-level windows of PID, tooltips
   excluded. A modal box is one of these whatever its class: an LCL form is
   class 'Window' like every other, so nothing is filtered by class but hints."""
   found = {}

   def visit(handle, _):
      if not win32gui.IsWindowVisible(handle):
         return True
      _, owner = win32process.GetWindowThreadProcessId(handle)
      if owner != pid:
         return True
      kind = win32gui.GetClassName(handle)
      if kind not in TRANSIENT_WINDOW_CLASSES:
         found[handle] = (kind, win32gui.GetWindowText(handle))
      return True

   win32gui.EnumWindows(visit, None)
   return found


def new_windows(pid, baseline, settle=0.0):
   """Windows of PID that were not in BASELINE, after an optional settle."""
   if settle:
      time.sleep(settle)
   return {handle: facts for handle, facts in owned_windows(pid).items() if handle not in baseline}


def window_body(app, handle):
   """Title plus every readable text inside a top-level window: win32 child
   texts, then UI Automation Text elements (a TaskDialog draws its body
   without windows)."""
   from pywinauto import Application
   parts = [win32gui.GetWindowText(handle)]
   try:
      for control in app.window(handle=handle).descendants():
         text = control.window_text()
         if text and text.strip() and control.class_name() != "Button":
            parts.append(text)
   except Exception as error:
      parts.append("<win32 read failed: " + repr(error) + ">")
   try:
      uiapp = Application(backend="uia").connect(process=app.process)
      for control in uiapp.window(handle=handle).descendants():
         if control.element_info.control_type == "Text":
            name = control.element_info.element.CurrentName
            if name and name.strip() and name not in parts:
               parts.append(name)
   except Exception as error:
      parts.append("<uia read failed: " + repr(error) + ">")
   return " | ".join(part.strip() for part in parts if part and part.strip())


def dismiss(app, handle, journal, answers=("OK", "No", "Cancel", "Close")):
   """Close a window the program put up, with its first non-committing answer
   (by caption, in ANSWERS order), else Escape. Returns what was pressed."""
   from pywinauto import Application
   if not (win32gui.IsWindow(handle) and win32gui.IsWindowVisible(handle)):
      return "closed by itself"
   window = app.window(handle=handle)
   buttons = {}
   try:
      for control in window.descendants(class_name="Button"):
         buttons.setdefault(control.window_text().replace("&", "").strip(), control)
   except Exception:
      pass
   if not buttons:
      try:
         uiapp = Application(backend="uia").connect(process=app.process)
         for control in uiapp.window(handle=handle).descendants(control_type="Button"):
            buttons.setdefault(control.element_info.element.CurrentName.replace("&", "").strip(), control)
      except Exception:
         pass
   if not (win32gui.IsWindow(handle) and win32gui.IsWindowVisible(handle)):
      return "closed by itself"
   try:
      for answer in answers:
         if answer in buttons:
            journal.perform("dismiss window with " + answer, buttons[answer].click_input)
            break
      else:
         answer = "Escape"
         journal.perform("dismiss window with Escape", lambda: window.type_keys("{ESC}"))
   except Exception:
      # A window that closes itself between the look and the press is not a
      # driver failure; anything still on screen is.
      if win32gui.IsWindow(handle) and win32gui.IsWindowVisible(handle):
         raise
      return "closed by itself"
   deadline = time.monotonic() + 5
   while time.monotonic() < deadline and win32gui.IsWindow(handle) and win32gui.IsWindowVisible(handle):
      time.sleep(0.1)
   return answer


def ensure_foreground(window, events, name):
   """Make WINDOW the foreground window for a capture WITHOUT moving the
   keyboard focus inside it. If another window holds the foreground it is
   appended to EVENTS (what, which process), WINDOW is re-activated at the top
   level only, and the focused control must still be the one it was --
   otherwise the capture would follow a focus change the check did not make."""
   from preferences_audit import focus_info
   holder = win32gui.GetForegroundWindow()
   if holder == window.handle:
      return
   events.append({"capture": name, "holder": holder,
      "class": win32gui.GetClassName(holder) if holder else None,
      "title": win32gui.GetWindowText(holder) if holder else None,
      "pid": win32process.GetWindowThreadProcessId(holder)[1] if holder else None})
   before = focus_info(window).get("handle")
   win32gui.SetForegroundWindow(window.handle)
   deadline = time.monotonic() + 3
   while time.monotonic() < deadline and win32gui.GetForegroundWindow() != window.handle:
      time.sleep(0.1)
   time.sleep(0.2)
   if focus_info(window).get("handle") != before:
      raise RuntimeError("Re-activating the window for capture " + name + " moved the keyboard focus")


def client_region(parent, left, top, width, height):
   """Screen rectangle of a client-relative area of window PARENT."""
   x, y = win32gui.ClientToScreen(parent, (left, top))
   return (x, y, x + width, y + height)


def ocr(png):
   """The text Windows OCR reads in PNG, upscaled 3x first (9 pt at 96 DPI is
   small for it). Raises when OCR itself cannot run, so a missing reader is a
   driver error, never a pass."""
   png = Path(png)
   large = png.with_name(png.stem + "-x3.png")
   with Image.open(png) as image:
      image.convert("RGB").resize((image.width * 3, image.height * 3), Image.LANCZOS).save(large)
   process = subprocess.run(["powershell.exe", "-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass",
      "-File", str(OCR_SCRIPT), "-Path", str(large)], capture_output=True, timeout=90,
      creationflags=subprocess.CREATE_NO_WINDOW)
   if process.returncode:
      raise RuntimeError("OCR failed: " + process.stderr.decode("utf-8", "replace"))
   return " ".join(process.stdout.decode("utf-8", "replace").split())
