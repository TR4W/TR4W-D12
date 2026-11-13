"""Issue 278: what Windows UI Automation names each Preferences > Station input.

Read-only observation of the running Preferences window. Rows are paired by
geometry (a caption and the input on its row), never by the UIA Name under
test, and each input's Name is read straight from IUIAutomationElement.
CurrentName -- window_text() can return an Edit's VALUE instead of its Name.
Nothing is saved: the phase ends with Cancel.
"""

import json
import time

import win32gui
from pywinauto import mouse
from pywinauto.uia_element_info import UIAElementInfo

from session import capture
from preferences_audit import focus_info
from bench_preferences import search_control

# The 17 Station captions in their designed Tab order (uPrefsForm.lfm). The
# left column is the first ten, the right column the last seven.
CAPTIONS = ("Callsign:", "First name:", "Grid square:", "Continent:", "CQ zone:", "ITU zone:",
   "State/Province:", "ARRL section:", "Country:", "Postal code:",
   "Check:", "Precedence:", "FD class:", "FOC number:", "IOTA:", "Park:", "License year:")
ENDS = ("Callsign:", "Postal code:", "Check:", "License year:")


def uia_facts(handle):
   element = UIAElementInfo(handle).element
   facts = {"name": element.CurrentName, "control_type": element.CurrentLocalizedControlType,
      "class": element.CurrentClassName, "automation_id": element.CurrentAutomationId,
      "help_text": str(element.GetCurrentPropertyValue(30013) or "")}
   try:
      labeled = element.CurrentLabeledBy
      facts["labeled_by"] = labeled.CurrentName if labeled else None
   except Exception as error:
      facts["labeled_by"] = None
      facts["labeled_by_error"] = repr(error)
   return facts


def msaa_name(handle):
   """IAccessible.accName of the window's client object, independent of UIA."""
   import ctypes
   import comtypes.client
   oleacc = comtypes.client.GetModule("oleacc.dll")
   pointer = ctypes.POINTER(oleacc.IAccessible)()
   ctypes.oledll.oleacc.AccessibleObjectFromWindow(handle, ctypes.c_long(-4).value & 0xFFFFFFFF,
      ctypes.byref(oleacc.IAccessible._iid_), ctypes.byref(pointer))
   try:
      return pointer.accName(0)
   except TypeError:
      return pointer.accName[0]


def answers_wm_getobject(handle):
   """Does the window answer WM_GETOBJECT(OBJID_CLIENT) itself? Nonzero means it
   supplies its own accessible object instead of the system proxy (the proxy is
   what names an edit from the static before it). Diagnostic only."""
   import win32con
   try:
      _, value = win32gui.SendMessageTimeout(handle, 0x003D, 0, 0xFFFFFFFC,
         win32con.SMTO_ABORTIFHUNG, 1000)
      return value
   except Exception as error:
      return repr(error)


def neighbours(handle):
   """The window just before and after HANDLE in z-order, which is where the
   Win32 accessibility proxy looks for an edit's label."""
   result = {}
   for key, other in (("self", handle), ("previous", win32gui.GetWindow(handle, 3)),
         ("next", win32gui.GetWindow(handle, 2))):
      result[key] = {"handle": other, "class": win32gui.GetClassName(other) if other else None,
         "text": win32gui.GetWindowText(other) if other else None}
      if other:
         # Styles and control id: what the Win32 label rule could depend on.
         result[key].update({"style": hex(win32gui.GetWindowLong(other, -16) & 0xFFFFFFFF),
            "exstyle": hex(win32gui.GetWindowLong(other, -20) & 0xFFFFFFFF),
            "id": win32gui.GetWindowLong(other, -12)})
   return result


def positive_control(static_style=0x50000000, edit_style=0x50010000):
   """THE METHOD'S OWN CONTROL: a plain Win32 window owned by this worker, a
   STATIC 'Probe label:' then an EDIT, read by exactly the same calls. If its
   edit is named, the reader works and an empty TR4W name is the program's.
   The styles are parameters so TR4W's own observed styles can be replayed."""
   import threading
   import win32con
   import win32api
   ready = threading.Event()
   handles = {}

   def run():
      instance = win32api.GetModuleHandle(None)
      top = win32gui.CreateWindowEx(0, "Static", "UIA probe", win32con.WS_OVERLAPPEDWINDOW | win32con.WS_VISIBLE,
         20, 20, 320, 120, 0, 0, instance, None)
      label = win32gui.CreateWindowEx(0, "Static", "Probe label:", static_style,
         10, 14, 100, 20, top, 0, instance, None)
      edit = win32gui.CreateWindowEx(win32con.WS_EX_CLIENTEDGE, "Edit", "value",
         edit_style, 120, 10, 150, 24, top, 0, instance, None)
      handles.update(top=top, label=label, edit=edit, thread=win32api.GetCurrentThreadId())
      ready.set()
      win32gui.PumpMessages()

   thread = threading.Thread(target=run, daemon=True)
   thread.start()
   ready.wait(5)
   try:
      result = {"uia": uia_facts(handles["edit"]), "neighbours": neighbours(handles["edit"]),
         "wm_getobject": answers_wm_getobject(handles["edit"])}
      try:
         result["msaa_name"] = msaa_name(handles["edit"])
      except Exception as error:
         result["msaa_error"] = repr(error)
   finally:
      win32api.PostThreadMessage(handles["thread"], 0x0012, 0, 0)
      win32gui.PostMessage(handles["top"], 0x0010, 0, 0)
      thread.join(5)
   return result


def station_rows(prefs, left_anchor, right_anchor):
   """The 17 inputs, paired with their captions by designed position.

   The inputs are the two columns the searched Callsign (left_anchor) and
   License year (right_anchor) boxes stand in, top to bottom: 10 and 7. The
   caption windows (TStaticText since 68e0a232; TLabel before, so no window)
   are found by their text and must sit on their input's row. Neither step
   reads the UIA Name being measured."""
   controls = [control for control in prefs.descendants() if control.is_visible()]
   inputs = [control for control in controls if control.class_name() in {"Edit", "LCLComboBox"}
      and win32gui.GetClassName(win32gui.GetParent(control.handle)) != "LCLComboBox"]

   def column(anchor, count):
      left = win32gui.GetWindowRect(anchor)[0]
      cells = sorted([control for control in inputs if abs(control.rectangle().left - left) <= 2],
         key=lambda control: control.rectangle().top)
      if len(cells) != count:
         raise AssertionError("Expected " + str(count) + " inputs in the column at x=" + str(left)
            + ", found " + str(len(cells)))
      return cells

   fields = column(left_anchor, 10) + column(right_anchor, 7)
   captions = {}
   for control in controls:
      if control.window_text() in CAPTIONS:
         if control.window_text() in captions:
            raise AssertionError("Station caption not unique: " + control.window_text())
         captions[control.window_text()] = control
   rows = []
   for text, field in zip(CAPTIONS, fields):
      caption = captions.get(text)
      row = {"caption": text, "caption_windowed": caption is not None,
         "input_handle": field.handle, "input_class": field.class_name(),
         "input_rect": str(field.rectangle()), "input_value": field.window_text(),
         "input_uia": uia_facts(field.handle), "input_neighbours": neighbours(field.handle),
         "input_wm_getobject": answers_wm_getobject(field.handle)}
      try:
         row["input_msaa_name"] = msaa_name(field.handle)
      except Exception as error:
         row["input_msaa_error"] = repr(error)
      if caption is not None:
         middle = caption.rectangle().mid_point().y
         if not field.rectangle().top <= middle <= field.rectangle().bottom:
            raise AssertionError("Caption " + text + " is not on the row of its input")
         row.update({"caption_handle": caption.handle, "caption_class": caption.class_name(),
            "caption_rect": str(caption.rectangle()), "caption_uia": uia_facts(caption.handle)})
      if field.class_name() == "LCLComboBox":
         inner = win32gui.FindWindowEx(field.handle, 0, "Edit", None)
         row["inner_edit_handle"] = inner
         row["inner_edit_uia"] = uia_facts(inner) if inner else None
      rows.append(row)
   return rows


def expected_name(caption):
   return {caption, caption.rstrip(":")}


def anchors(prefs, output, journal):
   """Land on the Station page through search; the focused boxes are the column anchors."""
   _, right = search_control(prefs, "MY LICENSE YEAR", output, journal)
   _, left = search_control(prefs, "MY CALL", output, journal)
   return left["focus"]["handle"], right["focus"]["handle"]


def observe(prefs, label, output, journal, main_call_handle):
   rows = station_rows(prefs, *anchors(prefs, output, journal))
   journal.perform("capture Station page " + label, lambda: capture(prefs, output / ("station-" + label + ".png")))
   main_call = uia_facts(main_call_handle) if main_call_handle else None
   return {"label": label, "rows": rows, "main_callsign_uia": main_call}


def main_callsign(prefs, output, journal):
   """MAIN CALLSIGN (the generated row, still a TLabel) is the control case.
   None when search cannot reach it; that is recorded, not guessed."""
   try:
      _, observation = search_control(prefs, "MAIN CALLSIGN", output, journal)
   except AssertionError:
      return None
   return observation["focus"]["handle"]


def check(app, main, prefs, root, run_name, output, journal):
   failures = []
   main_call_handle = main_callsign(prefs, output, journal)
   search = min([c for c in prefs.descendants(class_name="Edit") if c.is_visible()],
      key=lambda c: (c.rectangle().left, c.rectangle().top))
   passes = [observe(prefs, "initial", output, journal, main_call_handle)]

   # The same names after another page and back.
   search_control(prefs, "DE ENABLE", output, journal)
   passes.append(observe(prefs, "after-page-switch", output, journal, main_call_handle))

   # Tab from Callsign through the page; record every stop.
   rows = passes[-1]["rows"]
   by_handle = {}
   for row in rows:
      by_handle[row["input_handle"]] = row["caption"]
      if row.get("inner_edit_handle"):
         by_handle[row["inner_edit_handle"]] = row["caption"]
   by_handle[main_call_handle] = "MAIN CALLSIGN"
   caption_handles = {row["caption_handle"]: row["caption"] for row in rows if row["caption_windowed"]}
   callsign = next(row for row in rows if row["caption"] == "Callsign:")
   from pywinauto.controls.hwndwrapper import HwndWrapper
   journal.perform("focus Callsign", lambda: HwndWrapper(callsign["input_handle"]).set_focus())
   tab_stops = [dict(focus_info(prefs), field=by_handle.get(focus_info(prefs)["handle"]))]
   for _ in range(24):
      prefs.type_keys("{TAB}", pause=0.05)
      time.sleep(0.05)
      item = focus_info(prefs)
      item["field"] = by_handle.get(item["handle"])
      item["is_caption"] = item["handle"] in caption_handles
      tab_stops.append(item)
   order = [stop["field"] for stop in tab_stops if stop["field"] and stop["field"] != "MAIN CALLSIGN"]
   seen = []
   for field in order:
      if field not in seen:
         seen.append(field)
   if seen[:len(CAPTIONS)] != list(CAPTIONS):
      failures.append("Tab order differs from the designed order: " + repr(seen))
   if any(stop.get("is_caption") for stop in tab_stops):
      failures.append("Tab focused a caption: " + repr([s for s in tab_stops if s.get("is_caption")]))

   # Click each caption from a neutral focus (the search box) and see where focus goes.
   clicks = []
   for row in rows:
      if not row["caption_windowed"]:
         clicks.append({"caption": row["caption"], "status": "NOT RUN: caption is not a window"})
         continue
      journal.perform("neutral focus before clicking " + row["caption"], search.set_focus)
      time.sleep(0.15)
      before = focus_info(prefs)
      rect = win32gui.GetWindowRect(row["caption_handle"])
      point = ((rect[0] + rect[2]) // 2, (rect[1] + rect[3]) // 2)
      journal.perform("click caption " + row["caption"], lambda: mouse.click(coords=point))
      time.sleep(0.3)
      after = focus_info(prefs)
      clicks.append({"caption": row["caption"], "clicked_at": point,
         "focus_before": {"handle": before.get("handle"), "class": before.get("class")},
         "focus_after": {"handle": after.get("handle"), "class": after.get("class"),
            "field": by_handle.get(after.get("handle")),
            "is_caption": after.get("handle") in caption_handles,
            "is_search": after.get("handle") == search.handle}})
   journal.perform("capture Station page after clicks", lambda: capture(prefs, output / "station-after-clicks.png"))

   # Close and reopen Preferences: the names again on a fresh form.
   journal.perform("cancel Preferences", lambda: prefs.child_window(title="Cancel").click_input())
   prefs.wait_not("visible", timeout=10)
   journal.perform("reopen Preferences", lambda: main.type_keys("^j"))
   prefs = app.window(title="TR4W Preferences")
   prefs.wait("visible enabled", timeout=10)
   reopened_main = main_callsign(prefs, output, journal)
   passes.append(observe(prefs, "after-reopen", output, journal, reopened_main))

   names = []
   for observation in passes:
      table = {row["caption"]: (row["input_uia"]["name"], row["input_uia"]["control_type"])
         for row in observation["rows"]}
      names.append(table)
      for row in observation["rows"]:
         name = row["input_uia"]["name"]
         if name not in expected_name(row["caption"]):
            failures.append(observation["label"] + ": " + row["caption"] + " input is named " + repr(name))
      callsign_name = next(row["input_uia"]["name"] for row in observation["rows"] if row["caption"] == "Callsign:")
      if callsign_name.rstrip(":") == "First name":
         failures.append(observation["label"] + ": Callsign reads 'First name'")
   if not (names[0] == names[1] == names[2]):
      failures.append("Names differ between the initial, page-switch and reopen passes")
   summary = [{"caption": caption,
      "initial": names[0].get(caption), "after_page_switch": names[1].get(caption),
      "after_reopen": names[2].get(caption)} for caption in CAPTIONS]
   main_names = [observation["main_callsign_uia"]["name"] if observation["main_callsign_uia"] else None
      for observation in passes]
   control = positive_control()
   if control["uia"]["name"] not in {"Probe label:", "Probe label"}:
      failures.append("METHOD: the worker's own Static+Edit control is named " + repr(control["uia"]["name"])
         + ", so empty TR4W names cannot be attributed to the program")
   # The same probe with the styles TR4W's caption and edit were observed to
   # carry (diagnostic only): does a style alone remove the name?
   observed = passes[0]["rows"][0]["input_neighbours"]
   replays = {}
   for label, static_style, edit_style in (
         ("tr4w_static_style", int(observed["previous"]["style"], 16), 0x50010000),
         ("tr4w_static_and_edit_styles", int(observed["previous"]["style"], 16), int(observed["self"]["style"], 16)),
         ("ss_notify_only", 0x50000100, 0x50010000),
         ("clip_flags_only", 0x56000000, 0x50010000)):
      replay = positive_control(static_style, edit_style)
      replays[label] = {"static_style": hex(static_style), "edit_style": hex(edit_style),
         "uia_name": replay["uia"]["name"], "msaa_name": replay.get("msaa_name")}
   result = {"method_positive_control": control, "style_replays": replays, "names": summary, "end_rows": [row for row in summary if row["caption"] in ENDS],
      "main_callsign_names": main_names, "tab_stops": tab_stops, "tab_order": seen,
      "caption_clicks": clicks, "passes": passes, "failures": failures}
   (output / "station-names.json").write_text(json.dumps(result, indent=3, default=str), encoding="utf-8")
   journal.perform("cancel Preferences after the name checks", lambda: prefs.child_window(title="Cancel").click_input())
   prefs.wait_not("visible", timeout=10)
   return {"passed": not failures, "failures": failures,
      "note": "UIA Names read from CurrentName; caption-click focus recorded, not asserted"}
