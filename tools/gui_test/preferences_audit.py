"""Observe Preferences navigation, real keyboard focus and exposed help text."""

import ctypes
from ctypes import wintypes
import json
import re
import time

import win32gui
import win32process
from pywinauto import Application

from session import capture


class GUIThreadInfo(ctypes.Structure):
   _fields_ = [
      ("size", wintypes.DWORD), ("flags", wintypes.DWORD),
      ("active", wintypes.HWND), ("focus", wintypes.HWND),
      ("capture", wintypes.HWND), ("menu_owner", wintypes.HWND),
      ("move_size", wintypes.HWND), ("caret", wintypes.HWND),
      ("caret_rect", wintypes.RECT),
   ]


def focus_info(window):
   thread, _ = win32process.GetWindowThreadProcessId(window.handle)
   info = GUIThreadInfo()
   info.size = ctypes.sizeof(info)
   if not ctypes.windll.user32.GetGUIThreadInfo(thread, ctypes.byref(info)):
      raise ctypes.WinError()
   handle = info.focus
   if not handle:
      return {"handle": 0}
   return {
      "handle": handle,
      "text": win32gui.GetWindowText(handle),
      "class": win32gui.GetClassName(handle),
      "rect": win32gui.GetWindowRect(handle),
      "visible": bool(win32gui.IsWindowVisible(handle)),
      "enabled": bool(win32gui.IsWindowEnabled(handle)),
   }


def audit(app, prefs, log, output):
   # Locate the visible navigation area by its observed geometry, not LCL names.
   bounds = prefs.rectangle()
   candidates = [
      c for c in prefs.descendants(class_name="Window")
      if c.is_visible() and c.rectangle().height() > 300
      and c.rectangle().width() < 250
      and c.rectangle().left < bounds.left + 200
   ]
   if len(candidates) != 1:
      raise AssertionError("Preferences navigation region is not uniquely observable")
   tree = candidates[0]
   tree.set_focus()
   tree.type_keys("{HOME}", pause=0.03)
   pages = {}
   uiapp = Application(backend="uia").connect(process=app.process)

   def observe():
      time.sleep(0.12)
      text = log.read_text(encoding="utf-8", errors="replace")
      selected = re.findall(r"\[Prefs\] section tag=(\d+) -> (panel|placeholder)", text)
      if not selected:
         raise AssertionError("No selected-page diagnostic; cannot identify captures reliably")
      tag, state = selected[-1]
      if tag in pages:
         return tag
      page = {"tag": tag, "application_report": state, "forward_tab": [], "reverse_tab": []}
      pages[tag] = page
      capture(prefs, output / ("preferences-" + tag + ".png"))
      # Walk a complete observed focus cycle, capped to detect traps safely.
      tree.set_focus()
      initial = focus_info(prefs)["handle"]
      for direction, key in (("forward_tab", "{TAB}"), ("reverse_tab", "+{TAB}")):
         tree.set_focus()
         for _ in range(80):
            prefs.type_keys(key, pause=0.01)
            item = focus_info(prefs)
            page[direction].append(item)
            if item["handle"] == initial:
               break
         else:
            page[direction + "_limit_reached"] = True
      forward = [x["handle"] for x in page["forward_tab"][:-1]]
      reverse = [x["handle"] for x in page["reverse_tab"][:-1]]
      page["reverse_matches_forward"] = reverse == list(reversed(forward))
      page["invalid_focus"] = [
         x for x in page["forward_tab"]
         if not x.get("visible", False) or not x.get("enabled", False)
      ]
      page["exposed_help"] = []
      try:
         uiprefs = uiapp.window(handle=prefs.handle)
         for control in uiprefs.descendants():
            if control.element_info.control_type not in {"Edit", "ComboBox", "CheckBox", "Button"}:
               continue
            if not control.is_visible():
               continue
            help_text = control.element_info.element.GetCurrentPropertyValue(30013)
            page["exposed_help"].append({
               "name": control.window_text(),
               "type": control.element_info.control_type,
               "help_text": str(help_text or ""),
               "meaning": "Empty UIA HelpText is not proof that a hover tooltip is missing",
            })
      except Exception as error:
         page["help_inspection_error"] = repr(error)
      (output / "preferences-audit.json").write_text(
         json.dumps(list(pages.values()), indent=3), encoding="utf-8"
      )
      tree.set_focus()
      return tag

   observe()
   for _ in range(100):
      before = observe()
      tree.type_keys("{RIGHT}", pause=0.03)
      after_right = observe()
      tree.type_keys("{DOWN}", pause=0.03)
      after_down = observe()
      if before == after_right == after_down:
         break
   else:
      raise AssertionError("Navigation walk exceeded its bounded limit")
   return list(pages.values())
