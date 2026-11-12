"""Radio definitions only: validation/persistence with no profile activation."""

import json
import re
import win32gui
from pywinauto.controls.win32_controls import ComboBoxWrapper
from pywinauto.controls.common_controls import TabControlWrapper
from pywinauto.timings import wait_until

from preferences_audit import select_page, focus_info
from session import capture, close_normally, launch, acknowledge_notice, hover_control, wait_for_hint


def check(app, main, prefs, root, run_name, output, journal):
   log = root / "runs" / run_name / "tr4w.log"
   select_page(prefs, log, 26)
   prefs.child_window(title="Add...", class_name="Button").click_input()
   editor = app.window(title="Radio")
   editor.wait("visible enabled", timeout=10)
   edits = [control for control in editor.descendants(class_name="Edit") if control.is_visible()
      and win32gui.GetClassName(win32gui.GetParent(control.handle)) != "LCLComboBox"]
   name = min(edits, key=lambda control: control.rectangle().top)
   name.set_edit_text("GUI K4 inactive")
   combos = [control for control in editor.descendants(class_name="LCLComboBox") if control.is_visible()]
   model = ComboBoxWrapper(min(combos, key=lambda control: control.rectangle().top).handle)
   choices = model.item_texts()
   (output / "radio-models.json").write_text(json.dumps(choices, indent=3), encoding="utf-8")
   k4 = [text for text in choices if "K4" in text and "Elecraft" in text]
   if len(k4) != 1:
      raise RuntimeError("Elecraft K4 model not unique")
   model.select(k4[0])
   tabs = editor.child_window(class_name="SysTabControl32")
   TabControlWrapper(tabs.handle).select("Advanced")
   rate_matches = [control for control in editor.descendants(class_name="Edit") if control.is_visible()
      and control.window_text() == "10" and win32gui.GetClassName(win32gui.GetParent(control.handle)) != "LCLComboBox"]
   capture(editor, output / "advanced-default.png")
   if len(rate_matches) != 1:
      raise RuntimeError("Polling rate default 10 is not unique")
   rate = rate_matches[0]
   rate.set_focus()
   rate.type_keys("{TAB}")
   following = focus_info(editor)
   if following["rect"][1] < tabs.rectangle().bottom - 8:
      raise AssertionError("Polling rate is not the last control on Advanced")
   hover_control(rate)
   hints = wait_for_hint()
   hint = " ".join(window.window_text() for window in hints).lower().replace("-", " ")
   if not any(text in hint for text in ("per radio", "this radio", "each radio")) or not ("ms" in hint or "millisecond" in hint):
      raise AssertionError("Poll-rate tooltip does not describe per-radio milliseconds: " + hint)
   hamlib = editor.child_window(title="Drive through HamLib", class_name="Button")
   rate.set_edit_text("37")
   hamlib.click_input()
   wait_until(3, 0.1, lambda: not rate.is_enabled())
   hamlib.click_input()
   wait_until(3, 0.1, rate.is_enabled)
   if rate.window_text() != "37":
      raise AssertionError("HamLib toggle lost the rate value")
   notices = []
   for invalid in ("5", "5000"):
      rate.set_edit_text(invalid)
      rate.type_keys("{TAB}")
      editor.child_window(title="Save and close").click_input()
      text = acknowledge_notice(app, ("10", "1000"), journal, output / ("invalid-" + invalid + ".png"))
      if not {"10", "1000"}.issubset(set(re.findall(r"\d+", text))) or not editor.is_visible():
         raise AssertionError("Invalid poll rate did not preserve editor and name both limits")
      notices.append({"input": invalid, "notice": text})
   rate.set_edit_text("")
   rate.type_keys("{TAB}")
   editor.child_window(title="Save and close").click_input()
   editor.wait_not("visible", timeout=10)
   prefs.child_window(title="Save and close").click_input()
   prefs.wait_not("visible", timeout=10)
   close_normally(app, main, journal)
   stored = json.loads((root / "runs" / run_name / "tr4w.json").read_text(encoding="utf-8-sig"))
   if len(stored["radios"]) != 1 or stored.get("general", {}).get("activeProfile") or stored.get("general", {}).get("autoConnect"):
      raise AssertionError("Radio definition changed profile activation or was not stored")
   database = list((root / "runs" / run_name).glob("*.db"))[0]
   app = launch(root, run_name, database.name)
   main = app.window(title_re=r"TR4W v.*CWOPEN.*")
   main.wait("visible enabled", timeout=30)
   main.type_keys("^j")
   prefs = app.window(title="TR4W Preferences")
   prefs.wait("visible enabled", timeout=10)
   select_page(prefs, log, 26)
   prefs.child_window(title="Edit...", class_name="Button").click_input()
   editor = app.window(title="Radio")
   editor.wait("visible enabled", timeout=10)
   TabControlWrapper(editor.child_window(class_name="SysTabControl32").handle).select("Advanced")
   if not any(control.is_visible() and control.window_text() == "10" for control in editor.descendants(class_name="Edit")):
      raise AssertionError("Blank rate did not save/reopen as the default 10")
   capture(editor, output / "advanced-reopened.png")
   editor.child_window(title="Cancel").click_input()
   prefs.child_window(title="Cancel").click_input()
   (output / "radio-result.json").write_text(json.dumps({"invalid_inputs": notices,
      "stored_definition": stored["radios"], "restart_verified": True, "profile_active": False}, indent=3), encoding="utf-8")
   return {"passed": True, "note": "Inactive K4 poll range, HamLib toggle, default and restart asserted"}, app, main
