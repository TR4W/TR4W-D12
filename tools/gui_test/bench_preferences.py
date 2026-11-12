"""Preferences checks through visible search and controls, with isolated settings."""

import json
import sqlite3
from contextlib import closing
import win32gui
from pywinauto.controls.win32_controls import ButtonWrapper, ComboBoxWrapper, EditWrapper
from pywinauto.timings import wait_until, TimeoutError

from session import capture, describe_windows
from preferences_audit import focus_info

STATION_PATHS = {
   "DE ENABLE": ("settings", "Message", "DeEnable"),
   "SCP MINIMUM LETTERS": ("settings", "Scp", "MinimumLetters"),
   "RADIUS OF EARTH": ("settings", "GridMap", "RadiusOfEarth"),
}


def same_value(term, actual, expected):
   if term in {"SCP MINIMUM LETTERS", "RADIUS OF EARTH"}:
      return float(actual or 0) == float(expected or 0)
   return actual == expected


def station_values(root, run_name):
   settings = json.loads((root / "runs" / run_name / "tr4w.json").read_text(encoding="utf-8-sig"))
   result = {}
   for term, path in STATION_PATHS.items():
      value = settings
      for key in path:
         value = value[key]
      result[term] = value
   return result


def verify_storage(root, run_name, output, phase):
   station = "station" in phase
   state = json.loads((root / "runs" / run_name / ("prefs-station-roundtrip.json" if station
      else "prefs-roundtrip.json")).read_text(encoding="utf-8"))
   expected = state["expected" if phase.endswith("-save") else "baseline"]
   if station:
      values = station_values(root, run_name)
      for term, value in expected.items():
         if not same_value(term, values[term], value):
            raise AssertionError("Station JSON key did not retain " + term)
      (output / "stored-settings.json").write_text(json.dumps({"paths": STATION_PATHS,
         "values": values}, indent=3), encoding="utf-8")
      return
   database = list((root / "runs" / run_name).glob("CWOPEN*.db"))
   if len(database) != 1:
      raise RuntimeError("Storage check needs the one closed practice log")
   with closing(sqlite3.connect(database[0].resolve().as_uri() + "?mode=ro", uri=True)) as connection:
      rows = connection.execute("SELECT command,value,source FROM config WHERE command IN (?,?,?)",
         tuple(expected)).fetchall()
   actual = {command: value for command, value, source in rows}
   for term, value in expected.items():
      serialized = ("TRUE" if value else "FALSE") if isinstance(value, int) else value
      if actual.get(term) != serialized:
         raise AssertionError("Stored legacy key " + term + " did not match the UI value")
   if any(source != "contest" for command, value, source in rows):
      raise AssertionError("These three contest-scoped settings changed storage scope")
   (output / "stored-config.json").write_text(json.dumps(rows, indent=3), encoding="utf-8")


def search_control(prefs, term, output, journal):
   search = min([control for control in prefs.descendants(class_name="Edit") if control.is_visible()],
      key=lambda control: (control.rectangle().left, control.rectangle().top))
   journal.perform("focus Preferences search", search.set_focus)
   journal.perform("search " + term, lambda: search.set_edit_text(term))
   results = [control for control in prefs.descendants(class_name="LCLListBox")
      if control.is_visible() and control.rectangle().left == search.rectangle().left
      and control.rectangle().width() > search.rectangle().width()]
   if len(results) != 1:
      raise AssertionError("Search result popup is not unique for " + term)
   journal.perform("click first visible result for " + term, lambda: results[0].click_input(coords=(30, 12)))
   wait_until(5, 0.1, lambda: focus_info(prefs).get("handle") not in {0, search.handle})
   info = focus_info(prefs)
   journal.perform("capture searched page " + term,
      lambda: capture(prefs, output / (term.lower().replace(" ", "-") + ".png")))
   if not info.get("handle") or info["handle"] == search.handle or not info.get("visible"):
      raise AssertionError("Search did not focus a visible target for " + term)
   parent = win32gui.GetParent(info["handle"])
   if info["class"] == "LCLComboBox" or win32gui.GetClassName(parent) == "LCLComboBox":
      control = ComboBoxWrapper(info["handle"] if info["class"] == "LCLComboBox" else parent)
      value = control.window_text()
      kind = "combo"
   elif info["class"] == "Edit":
      control = EditWrapper(info["handle"])
      value = control.window_text()
      kind = "edit"
   elif info["class"] == "Button":
      control = ButtonWrapper(info["handle"])
      value = control.get_check_state()
      kind = "check"
   else:
      raise AssertionError("Unexpected search target: " + repr(info))
   return control, {"term": term, "kind": kind, "value": value, "focus": info}


def write_value(control, observation, value, journal):
   if observation["term"] == "RADIUS OF EARTH" and value == "":
      # The observed blank default corresponds to stored zero; use the documented
      # numeric default when restoring, rather than an empty invalid real input.
      value = "0"
   if observation["kind"] == "check":
      if control.get_check_state() != value:
         journal.perform("toggle " + observation["term"], control.click_input)
      actual = control.get_check_state()
   elif observation["kind"] == "combo":
      journal.perform("select " + str(value), lambda: control.select(value))
      actual = control.window_text()
   else:
      journal.perform("write " + observation["term"], lambda: control.set_edit_text(value))
      actual = control.window_text()
   if not same_value(observation["term"], actual, value):
      raise AssertionError(observation["term"] + " did not take the requested value")


def check(app, main, output, journal, phase, root, run_name):
   journal.perform("open Preferences with Ctrl+J", lambda: main.type_keys("^j"))
   prefs = app.window(title="TR4W Preferences")
   prefs.wait("visible", timeout=10)
   if phase == "bench-prefs-loggers":
      from bench_loggers import check as check_loggers
      return check_loggers(app, main, prefs, root, run_name, output, journal)
   if phase == "bench-prefs-radio":
      from bench_radio_editor import check as check_radio
      return check_radio(app, main, prefs, root, run_name, output, journal)
   if phase == "bench-prefs-online":
      from bench_online import check as check_online
      return check_online(app, main, prefs, root, run_name, output, journal)
   if phase == "bench-prefs-hints":
      from bench_remaining import inspect_hints
      return inspect_hints(app, prefs, output, journal, validate=True)
   if phase == "bench-prefs-focus":
      from bench_remaining import check_focus
      return check_focus(app, prefs, root, run_name, output, journal)
   if phase == "bench-prefs-editor-inspect":
      from bench_remaining import inspect_editors
      return inspect_editors(app, prefs, root, run_name, output, journal)
   if phase == "bench-prefs-hints-inspect":
      from bench_remaining import inspect_hints
      return inspect_hints(app, prefs, output, journal)
   if phase == "bench-prefs-remaining-inspect":
      from bench_remaining import inspect
      return inspect(app, prefs, root, run_name, output, journal)
   if phase == "bench-prefs-audit":
      from preferences_audit import audit
      pages = audit(app, prefs, root / "runs" / run_name / "tr4w.log", output)
      prefs.child_window(title="Cancel").click_input()
      return {"passed": True, "pages_observed": len(pages),
         "note": "Mechanical Tab observations only; semantic order and screenshots require review"}
   if phase == "bench-prefs-overview":
      bounds = prefs.rectangle()
      trees = [control for control in prefs.descendants(class_name="Window") if control.is_visible()
         and control.rectangle().height() > 300 and control.rectangle().width() < 250
         and control.rectangle().left < bounds.left + 200]
      if len(trees) != 1:
         raise RuntimeError("Preferences navigation region is not unique")
      tree = trees[0]
      labels = ("WSJT-X", "External Logger", "DXLab", "MMTTY")

      def overview():
         tree.set_focus()
         tree.type_keys("{END}{UP}{LEFT}")
         wait_until(5, 0.1, lambda: all(any(control.is_visible() and control.window_text() == label
            for control in prefs.descendants(class_name="Button")) for label in labels))
         buttons = {label: [control for control in prefs.descendants(class_name="Button")
            if control.is_visible() and control.window_text() == label] for label in labels}
         if any(len(matches) != 1 for matches in buttons.values()):
            raise AssertionError("External Software overview buttons missing or duplicated")
         return {label: matches[0] for label, matches in buttons.items()}

      buttons = overview()
      capture(prefs, output / "external-software-overview.png")
      tree.set_focus()
      visited = []
      for _ in range(16):
         prefs.type_keys("{TAB}")
         focused = focus_info(prefs)
         if focused.get("text") in labels:
            visited.append(focused["text"])
         if all(label in visited for label in labels):
            break
      if not all(label in visited for label in labels):
         raise AssertionError("Tab did not reach each overview button: " + repr(visited))
      navigation = []
      for label in labels:
         for method in ("Enter", "Click"):
            button = overview()[label]
            if method == "Enter":
               button.set_focus()
               journal.perform("open " + label + " with Enter", lambda: button.type_keys("{ENTER}"))
            else:
               journal.perform("open " + label + " with click", button.click_input)
            # A selected leaf must replace the overview, not just leave its buttons.
            try:
               wait_until(5, 0.1, lambda: not all(any(control.is_visible() and control.window_text() == name
                  for control in prefs.descendants(class_name="Button")) for name in labels))
               navigated = True
            except TimeoutError:
               navigated = False
            navigation.append({"label": label, "method": method, "navigated": navigated})
            capture(prefs, output / (label.lower().replace(" ", "-") + "-" + method.lower() + ".png"))
      overview()
      capture(prefs, output / "external-software-returned.png")
      journal.perform("close overview checks without changes", lambda: prefs.child_window(title="Cancel").click_input())
      (output / "overview-result.json").write_text(json.dumps({"tab_buttons": visited,
         "navigation": navigation, "buttons_not_duplicated": True,
         "operating_page": "NOT RUN: requires verified page selection"}, indent=3), encoding="utf-8")
      return {"passed": all(item["navigated"] for item in navigation), "navigation": navigation,
         "note": "Overview navigation outcomes recorded individually; screenshots need review"}
   observations = []
   station = "station" in phase
   terms = tuple(STATION_PATHS) if station else ("QTC MINUTES", "CATEGORY-POWER", "SPRINT QSY RULE", "CALL HISTORY FILENAME")
   for term in terms:
      control, observation = search_control(prefs, term, output, journal)
      observations.append(observation)
   (output / "search-results.json").write_text(json.dumps(observations, indent=3), encoding="utf-8")
   state_file = root / "runs" / run_name / ("prefs-station-roundtrip.json" if station else "prefs-roundtrip.json")
   if phase.endswith("-restore"):
      state = json.loads(state_file.read_text(encoding="utf-8"))
      for term, value in state["baseline"].items():
         control, observation = search_control(prefs, term, output, journal)
         write_value(control, observation, value, journal)
      journal.perform("restore failed-test fixture values", lambda: prefs.child_window(title="Save and close").click_input())
      prefs.wait_not("visible", timeout=10)
      return {"passed": True, "note": "Original fixture values restored after failed restart check"}
   if phase.endswith("-save"):
      baselines = {item["term"]: item["value"] for item in observations
         if station or item["kind"] != "edit"}
      original_store = station_values(root, run_name) if station else None
      expected = {}
      for item in observations:
         term, value = item["term"], item["value"]
         if term not in baselines:
            continue
         if term == "SCP MINIMUM LETTERS":
            expected[term] = "3" if float(value or 0) != 3 else "4"
         elif term == "RADIUS OF EARTH":
            expected[term] = "6371" if float(value or 0) != 6371 else "6370"
         elif item["kind"] == "check":
            expected[term] = 1 - value
         elif item["kind"] == "combo":
            expected[term] = "LOW" if value != "LOW" else "HIGH"
         else:
            expected[term] = str(int(float(value)) + 1)
      for term, value in expected.items():
         control, observation = search_control(prefs, term, output, journal)
         write_value(control, observation, value, journal)
      if not prefs.child_window(title="Save").is_enabled():
         raise AssertionError("Changing three Preferences leaves did not enable Save")
      journal.perform("Cancel three pending leaf changes", lambda: prefs.child_window(title="Cancel").click_input())
      prefs.wait_not("visible", timeout=10)
      journal.perform("reopen after Cancel", lambda: main.type_keys("^j"))
      prefs.wait("visible", timeout=10)
      for term, value in baselines.items():
         control, observation = search_control(prefs, term, output, journal)
         if not same_value(term, observation["value"], value):
            raise AssertionError("Cancel did not restore " + term)
      if station and station_values(root, run_name) != original_store:
         raise AssertionError("Cancel changed one of the three station JSON values")
      for term, value in expected.items():
         control, observation = search_control(prefs, term, output, journal)
         write_value(control, observation, value, journal)
      journal.perform("save the same three leaf changes", lambda: prefs.child_window(title="Save and close").click_input())
      prefs.wait_not("visible", timeout=10)
      state_file.write_text(json.dumps({"baseline": baselines, "expected": expected,
         "cancel_verified": True}, indent=3), encoding="utf-8")
      return {"passed": True, "note": "Cancel verified on three leaves; Save completed, restart verification pending"}
   if phase.endswith("-verify"):
      state = json.loads(state_file.read_text(encoding="utf-8"))
      actual = {item["term"]: item["value"] for item in observations}
      for term, value in state["expected"].items():
         if not same_value(term, actual[term], value):
            raise AssertionError("After restart " + term + " is " + repr(actual[term]) + ", expected " + repr(value))
      for term, value in state["baseline"].items():
         control, observation = search_control(prefs, term, output, journal)
         write_value(control, observation, value, journal)
      journal.perform("restore original fixture values", lambda: prefs.child_window(title="Save and close").click_input())
      prefs.wait_not("visible", timeout=10)
      state["restart_verified"] = True
      state["baseline_restored"] = True
      (output / "roundtrip-result.json").write_text(json.dumps(state, indent=3), encoding="utf-8")
      return {"passed": True, "note": "Three leaf values survived restart; original fixture values restored"}
   describe_windows(app, output)
   journal.perform("cancel search inspection", lambda: prefs.child_window(title="Cancel").click_input())
   prefs.wait_not("visible", timeout=10)
   return {"passed": True, "note": "Search inspection captured; semantic review required"}
