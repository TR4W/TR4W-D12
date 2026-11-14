"""Issue 278 probe windows, run as a SEPARATE process by bench_uia278.py.

Each variant is a plain Win32 top-level window holding a STATIC caption created
immediately before an EDIT (so the caption is the edit's GW_HWNDPREV sibling,
the layout TR4W's Station page has). One variable changes per variant. Running
in its own process means the measuring worker reads these windows through the
same cross-process accessibility proxies it uses for TR4W.

argv: <handles.json> <stop-file>. Writes the handles, then pumps messages until
the stop file exists or 300 s pass. Owns nothing outside its own windows.
"""

import json
import os
import sys
import time

import win32api
import win32con
import win32gui

DLGC_WANTALLKEYS = 0x0004
DLGC_STATIC = 0x0100
EM_SETCUEBANNER = 0x1501

# Keep every Python window procedure alive for the life of the process.
_procs = []


def answer_dlgcode(handle, value):
   """Subclass HANDLE so WM_GETDLGCODE returns VALUE and nothing else changes."""
   previous = {}

   def procedure(hwnd, message, wparam, lparam):
      if message == win32con.WM_GETDLGCODE:
         return value
      return win32gui.CallWindowProc(previous["proc"], hwnd, message, wparam, lparam)

   _procs.append(procedure)
   previous["proc"] = win32gui.SetWindowLong(handle, win32con.GWL_WNDPROC, procedure)


def register_panel_class(instance):
   """A child container class with DefWindowProc, standing in for an LCL TPanel."""
   klass = win32gui.WNDCLASS()
   klass.hInstance = instance
   klass.lpszClassName = "UIA278ProbePanel"
   klass.lpfnWndProc = {}
   klass.hbrBackground = win32con.COLOR_WINDOW + 1
   win32gui.RegisterClass(klass)
   return klass.lpszClassName


def build(instance, panel_class, index, name, static_code=None, edit_code=None,
      in_panel=False, with_static=True, cue=None):
   top = win32gui.CreateWindowEx(0, "Static", "UIA278 probe " + name,
      win32con.WS_OVERLAPPEDWINDOW | win32con.WS_VISIBLE,
      20 + index * 12, 470 + index * 12, 340, 120, 0, 0, instance, None)
   parent = top
   panel = 0
   if in_panel:
      panel = win32gui.CreateWindowEx(win32con.WS_EX_CONTROLPARENT, panel_class, "",
         win32con.WS_CHILD | win32con.WS_VISIBLE | win32con.WS_CLIPCHILDREN | win32con.WS_CLIPSIBLINGS,
         0, 0, 330, 80, top, 0, instance, None)
      parent = panel
   label = 0
   if with_static:
      # TR4W's observed caption style: WS_CHILD|WS_VISIBLE|WS_CLIPSIBLINGS|WS_CLIPCHILDREN|SS_NOTIFY.
      label = win32gui.CreateWindowEx(0, "Static", "Probe label:", 0x56000100,
         10, 14, 100, 20, parent, 0, instance, None)
   # TR4W's observed edit style: WS_CHILD|WS_VISIBLE|WS_CLIPSIBLINGS|WS_CLIPCHILDREN|WS_TABSTOP|ES_AUTOHSCROLL.
   edit = win32gui.CreateWindowEx(win32con.WS_EX_CLIENTEDGE, "Edit", "value", 0x56010080,
      120, 10, 150, 24, parent, 0, instance, None)
   if static_code is not None and label:
      answer_dlgcode(label, static_code)
   if edit_code is not None:
      answer_dlgcode(edit, edit_code)
   if cue is not None:
      win32gui.SendMessage(edit, win32con.WM_SETTEXT, 0, "")
      win32gui.SendMessage(edit, EM_SETCUEBANNER, 1, cue)
   return {"name": name, "top": top, "panel": panel, "label": label, "edit": edit,
      "static_code_forced": static_code, "edit_code_forced": edit_code,
      "in_panel": in_panel, "with_static": with_static, "cue": cue}


VARIANTS = (
   # name, keyword arguments
   ("native", {}),
   ("static_answers_wantallkeys", {"static_code": DLGC_WANTALLKEYS}),
   ("static_answers_static_explicit", {"static_code": DLGC_STATIC}),
   ("static_answers_static_or_wantallkeys", {"static_code": DLGC_STATIC | DLGC_WANTALLKEYS}),
   ("edit_answers_wantallkeys", {"edit_code": DLGC_WANTALLKEYS}),
   ("in_panel", {"in_panel": True}),
   ("in_panel_static_answers_wantallkeys", {"in_panel": True, "static_code": DLGC_WANTALLKEYS}),
   ("in_panel_static_answers_static", {"in_panel": True, "static_code": DLGC_STATIC}),
   ("cue_banner_no_static", {"with_static": False, "cue": "Cue name"}),
)


def main():
   handles_path, stop_path = sys.argv[1], sys.argv[2]
   instance = win32api.GetModuleHandle(None)
   panel_class = register_panel_class(instance)
   variants = [build(instance, panel_class, index, name, **options)
      for index, (name, options) in enumerate(VARIANTS)]
   with open(handles_path + ".tmp", "w", encoding="utf-8") as stream:
      json.dump({"pid": os.getpid(), "variants": variants}, stream, indent=3)
   os.replace(handles_path + ".tmp", handles_path)
   deadline = time.monotonic() + 300
   while time.monotonic() < deadline and not os.path.exists(stop_path):
      win32gui.PumpWaitingMessages()
      time.sleep(0.01)
   for variant in variants:
      win32gui.DestroyWindow(variant["top"])
   return 0


if __name__ == "__main__":
   raise SystemExit(main())
