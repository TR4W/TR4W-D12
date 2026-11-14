"""Issue 278 probe: WHY the Preferences > Station inputs have no accessible name.

Measurement only; nothing is saved (Preferences ends with Cancel, the native
file picker with Cancel). Records, for the Station panel, one input and its
caption: the HWND parent chain and full sibling z-order, each window's
WM_GETDLGCODE answer, the UIA element (Name, ControlType, ClassName,
AutomationId, FrameworkId, ProviderDescription, LabeledBy, LegacyIAccessible
Name/Role), the UIA parent chain and the panel's UIA children, and the MSAA
accName/accRole of OBJID_CLIENT and OBJID_WINDOW.

Then a comparison: every Edit/ComboBox/Button in Preferences and the main window
with its Name, and the native file picker's filename field (a non-LCL input in
the same process). Then probe windows in a separate process
(uia278_probe_window.py) that change one variable at a time: the caption's
WM_GETDLGCODE answer, a container parent, the edit's own answer, a cue banner.

The phase PASSES when every measurement was taken; it asserts nothing about
TR4W's names, because this is a probe, not a regression check.
"""

import ctypes
from ctypes import wintypes
import json
import subprocess
import sys
import time
from pathlib import Path

import win32con
import win32gui

from bench_preferences import search_control
from session import capture, select_menu

WM_GETDLGCODE = 0x0087
OBJID_WINDOW = 0x00000000
OBJID_CLIENT = 0xFFFFFFFC
DLGC_NAMES = ((0x0001, "WANTARROWS"), (0x0002, "WANTTAB"), (0x0004, "WANTALLKEYS"),
   (0x0008, "WANTMESSAGE"), (0x0010, "HASSETSEL"), (0x0020, "DEFPUSHBUTTON"),
   (0x0040, "UNDEFPUSHBUTTON"), (0x0080, "RADIOBUTTON"), (0x0100, "STATIC"),
   (0x0200, "WANTCHARS"), (0x2000, "BUTTON"))

UIA = {"Name": 30005, "ControlType": 30003, "LocalizedControlType": 30004, "ClassName": 30012,
   "AutomationId": 30011, "NativeWindowHandle": 30020, "FrameworkId": 30024,
   "ProviderDescription": 30107, "IsKeyboardFocusable": 30009, "HelpText": 30013,
   "IsControlElement": 30016, "IsContentElement": 30017,
   "LegacyName": 30092, "LegacyRole": 30095, "LegacyDescription": 30094}


def iuia():
   from pywinauto.uia_defines import IUIA
   return IUIA().iuia


def dlgcode(handle):
   try:
      _, value = win32gui.SendMessageTimeout(handle, WM_GETDLGCODE, 0, 0,
         win32con.SMTO_ABORTIFHUNG, 1000)
   except Exception as error:
      return {"error": repr(error)}
   flags = [name for bit, name in DLGC_NAMES if name and value & bit]
   return {"value": hex(value), "flags": flags}


def real_class(handle):
   buffer = ctypes.create_unicode_buffer(256)
   ctypes.windll.user32.RealGetWindowClassW(wintypes.HWND(handle), buffer, 256)
   return buffer.value


def hwnd_facts(handle):
   if not handle:
      return None
   return {"handle": handle, "class": win32gui.GetClassName(handle), "real_class": real_class(handle),
      "text": win32gui.GetWindowText(handle),
      "style": hex(win32gui.GetWindowLong(handle, win32con.GWL_STYLE) & 0xFFFFFFFF),
      "exstyle": hex(win32gui.GetWindowLong(handle, win32con.GWL_EXSTYLE) & 0xFFFFFFFF),
      "id": win32gui.GetWindowLong(handle, win32con.GWL_ID),
      "visible": bool(win32gui.IsWindowVisible(handle)), "rect": win32gui.GetWindowRect(handle),
      "dlgcode": dlgcode(handle)}


def parent_chain(handle):
   chain = []
   current = win32gui.GetParent(handle)
   while current:
      chain.append(hwnd_facts(current))
      current = win32gui.GetParent(current)
   return chain


def sibling_order(parent):
   """Every child of PARENT in z-order (GW_CHILD, then GW_HWNDNEXT)."""
   result = []
   current = win32gui.GetWindow(parent, win32con.GW_CHILD)
   while current:
      result.append(hwnd_facts(current))
      current = win32gui.GetWindow(current, win32con.GW_HWNDNEXT)
   return result


def element_facts(element):
   if element is None:
      return None
   facts = {}
   for key, identifier in UIA.items():
      try:
         value = element.GetCurrentPropertyValue(identifier)
         facts[key] = value if isinstance(value, (str, int, float, bool)) or value is None else str(value)
      except Exception as error:
         facts[key] = "ERROR " + repr(error)
   try:
      labeled = element.CurrentLabeledBy
      facts["LabeledBy"] = labeled.CurrentName if labeled else None
   except Exception as error:
      facts["LabeledBy"] = "ERROR " + repr(error)
   return facts


def uia_element(handle):
   return iuia().ElementFromHandle(wintypes.HWND(handle))


def walk(step, element):
   """One walker step. comtypes raises COMError for the walker's NULL (the end
   of the chain) rather than returning None, so the end is that exception."""
   import _ctypes
   try:
      return step(element)
   except (_ctypes.COMError, ValueError):
      return None


def uia_parent_chain(element):
   walker = iuia().RawViewWalker
   chain = []
   current = walk(walker.GetParentElement, element)
   while current and len(chain) < 12:
      chain.append(element_facts(current))
      current = walk(walker.GetParentElement, current)
   return chain


def uia_children(element, limit=200):
   walker = iuia().RawViewWalker
   children = []
   current = walk(walker.GetFirstChildElement, element)
   while current and len(children) < limit:
      children.append(element_facts(current))
      current = walk(walker.GetNextSiblingElement, current)
   return children


def msaa(handle, objid):
   import comtypes.client
   oleacc = comtypes.client.GetModule("oleacc.dll")
   function = ctypes.oledll.oleacc.AccessibleObjectFromWindow
   function.argtypes = [wintypes.HWND, wintypes.DWORD, ctypes.c_void_p, ctypes.c_void_p]
   pointer = ctypes.POINTER(oleacc.IAccessible)()
   try:
      function(handle, objid, ctypes.byref(oleacc.IAccessible._iid_), ctypes.byref(pointer))
   except Exception as error:
      return {"error": repr(error)}
   facts = {}
   for key, getter in (("accName", lambda: pointer.accName(0)), ("accRole", lambda: pointer.accRole(0)),
         ("accValue", lambda: pointer.accValue(0)), ("accChildCount", lambda: pointer.accChildCount)):
      try:
         value = getter()
      except TypeError:
         try:
            value = getattr(pointer, key)[0]
         except Exception as error:
            value = "ERROR " + repr(error)
      except Exception as error:
         value = "ERROR " + repr(error)
      facts[key] = value if isinstance(value, (str, int, float, bool)) or value is None else str(value)
   if isinstance(facts.get("accRole"), int):
      buffer = ctypes.create_unicode_buffer(128)
      ctypes.windll.oleacc.GetRoleTextW(facts["accRole"], buffer, 128)
      facts["accRoleText"] = buffer.value
   return facts


def full(handle):
   """Everything recorded about one window: HWND, UIA and MSAA."""
   element = uia_element(handle)
   return {"hwnd": hwnd_facts(handle), "uia": element_facts(element),
      "msaa_client": msaa(handle, OBJID_CLIENT), "msaa_window": msaa(handle, OBJID_WINDOW),
      "previous_sibling": hwnd_facts(win32gui.GetWindow(handle, win32con.GW_HWNDPREV)),
      "next_sibling": hwnd_facts(win32gui.GetWindow(handle, win32con.GW_HWNDNEXT))}


def label_walk(handle, limit=6):
   """The windows before HANDLE in z-order, as a label search would visit them."""
   visited = []
   current = win32gui.GetWindow(handle, win32con.GW_HWNDPREV)
   while current and len(visited) < limit:
      visited.append(hwnd_facts(current))
      current = win32gui.GetWindow(current, win32con.GW_HWNDPREV)
   return visited


def survey(window):
   """Every input-like window under WINDOW (visible or not) with its UIA Name."""
   rows = []
   for control in window.descendants():
      klass = control.class_name()
      if klass not in {"Edit", "LCLComboBox", "Button", "LCLListBox", "ComboBox", "LCLCheckListBox",
            "LCLSpinEdit", "msctls_trackbar32", "SysListView32"}:
         continue
      handle = control.handle
      try:
         element = uia_element(handle)
         name = element.CurrentName
         provider = element.GetCurrentPropertyValue(UIA["ProviderDescription"])
      except Exception as error:
         name, provider = "ERROR " + repr(error), None
      previous = win32gui.GetWindow(handle, win32con.GW_HWNDPREV)
      rows.append({"handle": handle, "class": klass, "text": win32gui.GetWindowText(handle)[:60],
         "visible": bool(win32gui.IsWindowVisible(handle)), "uia_name": name,
         "provider": provider,
         "parent_class": win32gui.GetClassName(win32gui.GetParent(handle)),
         "previous": {"class": win32gui.GetClassName(previous), "text": win32gui.GetWindowText(previous)[:60],
            "dlgcode": dlgcode(previous)} if previous else None})
   return rows


def summarize_survey(rows):
   named = [row for row in rows if row["uia_name"] and not str(row["uia_name"]).startswith("ERROR")]
   by_class = {}
   for row in rows:
      entry = by_class.setdefault(row["class"], {"total": 0, "named": 0, "named_equals_own_text": 0})
      entry["total"] += 1
      if row in named:
         entry["named"] += 1
         if row["uia_name"].replace("&", "") == row["text"].replace("&", ""):
            entry["named_equals_own_text"] += 1
   named_not_own = [row for row in named if row["uia_name"].replace("&", "") != row["text"].replace("&", "")]
   return {"by_class": by_class, "named_by_something_other_than_own_text": named_not_own}


def station(prefs, output, journal):
   """The Station panel, the Callsign edit, its caption, and the Continent combo."""
   _, observation = search_control(prefs, "MY CALL", output, journal)
   edit = observation["focus"]["handle"]
   caption = win32gui.GetWindow(edit, win32con.GW_HWNDPREV)
   panel = win32gui.GetParent(edit)
   # The Continent combo: the LCLComboBox in the same panel on the row of the
   # "Continent:" caption (search does not reach MY CONTINENT uniquely).
   children = [facts for facts in sibling_order(panel) if facts["visible"]]
   label = [facts for facts in children if facts["class"] == "Static" and facts["text"] == "Continent:"]
   if len(label) != 1:
      raise AssertionError("Continent caption is not unique in the Station panel")
   middle = (label[0]["rect"][1] + label[0]["rect"][3]) // 2
   combos = [facts["handle"] for facts in children if facts["class"] == "LCLComboBox"
      and facts["rect"][1] <= middle <= facts["rect"][3]]
   if len(combos) != 1:
      raise AssertionError("Continent combo is not unique on its caption's row")
   combo = combos[0]
   journal.perform("capture Station page", lambda: capture(prefs, output / "station.png"))
   panel_element = uia_element(panel)
   edit_element = uia_element(edit)
   result = {
      "edit": full(edit), "caption": full(caption) if caption else None, "panel": full(panel),
      "continent_combo": full(combo), "continent_inner_edit": full(win32gui.FindWindowEx(combo, 0, "Edit", None))
         if win32gui.FindWindowEx(combo, 0, "Edit", None) else None,
      "continent_label_walk": label_walk(combo),
      "edit_label_walk": label_walk(edit),
      "hwnd_parent_chain": parent_chain(edit),
      "panel_children_zorder": sibling_order(panel),
      "uia_parent_chain_of_edit": uia_parent_chain(edit_element),
      "uia_panel_children_raw": uia_children(panel_element),
   }
   return result


def file_picker(app, main, output, journal):
   """The native Open dialog's filename field: a non-LCL input inside TR4W."""
   select_menu(main, ("File", "Import", "ADIF"), journal)
   dialog = app.window(class_name="#32770", visible_only=True)
   dialog.wait("visible enabled", timeout=10)
   dialog_handle = dialog.handle
   time.sleep(0.5)
   journal.perform("capture native file picker", lambda: capture(dialog, output / "file-picker.png"))
   fields = [control for control in dialog.descendants(class_name="Edit") if control.is_visible()]
   rows = []
   for control in fields:
      handle = control.handle
      rows.append({"full": full(handle), "label_walk": label_walk(handle),
         "parent_chain": parent_chain(handle)[:4]})
      combo = win32gui.GetParent(handle)
      if win32gui.GetClassName(combo) == "ComboBox":
         rows[-1]["combo"] = full(combo)
         rows[-1]["combo_label_walk"] = label_walk(combo)
         outer = win32gui.GetParent(combo)
         if win32gui.GetClassName(outer) == "ComboBoxEx32":
            rows[-1]["comboex"] = full(outer)
            rows[-1]["comboex_label_walk"] = label_walk(outer)
   statics = [{"text": control.window_text(), "handle": control.handle, "dlgcode": dlgcode(control.handle)}
      for control in dialog.descendants(class_name="Static") if control.is_visible()]
   cancel = [control for control in dialog.descendants(class_name="Button")
      if control.is_visible() and control.window_text().replace("&", "") == "Cancel"]
   if len(cancel) != 1:
      raise AssertionError("Native file picker Cancel is not unique")
   journal.perform("cancel native file picker", cancel[0].click_input)
   dialog.wait_not("visible", timeout=10)
   return {"dialog_handle": dialog_handle, "edits": rows, "visible_statics": statics}


def probe_windows(output):
   """The one-variable-at-a-time replays in a separate process."""
   script = Path(__file__).with_name("uia278_probe_window.py")
   handles_path = output / "probe-handles.json"
   stop_path = output / "probe-stop"
   for path in (handles_path, stop_path):
      if path.exists():
         path.unlink()
   python = Path(sys.executable)
   process = subprocess.Popen([str(python), str(script), str(handles_path), str(stop_path)])
   try:
      deadline = time.monotonic() + 30
      while not handles_path.exists() and time.monotonic() < deadline:
         time.sleep(0.1)
      if not handles_path.exists():
         raise RuntimeError("Probe windows did not start")
      time.sleep(0.5)
      layout = json.loads(handles_path.read_text(encoding="utf-8"))
      results = []
      for variant in layout["variants"]:
         row = dict(variant)
         row["edit_facts"] = full(variant["edit"])
         row["label_dlgcode"] = dlgcode(variant["label"]) if variant["label"] else None
         row["edit_dlgcode"] = dlgcode(variant["edit"])
         row["uia_name"] = row["edit_facts"]["uia"]["Name"]
         row["msaa_name"] = row["edit_facts"]["msaa_client"].get("accName")
         results.append(row)
      return {"probe_pid": layout["pid"], "variants": results}
   finally:
      stop_path.write_text("stop", encoding="utf-8")
      try:
         process.wait(timeout=15)
      except subprocess.TimeoutExpired:
         # Only the probe process this function started.
         process.kill()


def check(app, main, prefs, root, run_name, output, journal):
   result = {"station": station(prefs, output, journal)}
   result["preferences_survey"] = survey(prefs)
   result["preferences_survey_summary"] = summarize_survey(result["preferences_survey"])
   journal.perform("cancel Preferences", lambda: prefs.child_window(title="Cancel").click_input())
   prefs.wait_not("visible", timeout=10)
   result["main_survey"] = survey(main)
   result["main_survey_summary"] = summarize_survey(result["main_survey"])
   result["file_picker"] = file_picker(app, main, output, journal)
   result["probe"] = probe_windows(output)
   (output / "uia278-probe.json").write_text(json.dumps(result, indent=3, default=str), encoding="utf-8")
   table = [{"variant": row["name"], "label_dlgcode": row["label_dlgcode"], "uia_name": row["uia_name"],
      "msaa_name": row["msaa_name"]} for row in result["probe"]["variants"]]
   station_edit = result["station"]["edit"]
   summary = {"station_edit_uia_name": station_edit["uia"]["Name"],
      "station_edit_msaa_name": station_edit["msaa_client"].get("accName"),
      "station_caption_dlgcode": result["station"]["caption"]["hwnd"]["dlgcode"] if result["station"]["caption"] else None,
      "station_edit_provider": station_edit["uia"]["ProviderDescription"],
      "probe": table}
   (output / "uia278-summary.json").write_text(json.dumps(summary, indent=3, default=str), encoding="utf-8")
   return {"passed": True, "failures": [], "summary": summary,
      "note": "Probe: measurements recorded, no assertion on TR4W names"}
