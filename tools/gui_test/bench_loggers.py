"""Inactive logger-library regressions; never enable a definition or Refresh."""

import json
import time
import win32gui
from pywinauto import mouse
from pywinauto.controls.win32_controls import ComboBoxWrapper
from pywinauto.timings import wait_until

from preferences_audit import select_page
from session import capture, close_normally, launch, click_context_menu, describe_windows
from visual_assert import compare_images


def check(app, main, prefs, root, run_name, output, journal):
   log = root / "runs" / run_name / "tr4w.log"
   select_page(prefs, log, 17)

   def grid():
      matches = [control for control in prefs.descendants(class_name="Window") if control.is_visible()
         and control.rectangle().width() > 600 and 120 < control.rectangle().height() < 350]
      if len(matches) != 1:
         raise RuntimeError("Logger grid is not unique")
      return matches[0]

   rectangle = grid().rectangle()
   capture(prefs, output / "empty-grid.png", region=(rectangle.left, rectangle.top, rectangle.right, rectangle.bottom))
   prefs.child_window(title="Add...", class_name="Button").click_input()
   editor = app.window(title="External logger")
   editor.wait("visible enabled", timeout=10)

   def provider():
      controls = [c for c in editor.descendants(class_name="LCLComboBox") if c.is_visible()]
      return ComboBoxWrapper(min(controls, key=lambda c: c.rectangle().top).handle)

   choices = provider().item_texts()
   (output / "providers.json").write_text(json.dumps(choices, indent=3), encoding="utf-8")

   def select_provider(kind):
      aliases = {"WRL": ("WRL", "WORLD RADIO LEAGUE"), "ACLOG": ("ACLOG", "N3FJP")}
      matches = [text for text in choices if text.upper() in aliases.get(kind, (kind,))]
      if len(matches) != 1:
         raise RuntimeError("Provider not unique: " + kind + " in " + repr(choices))
      provider().select(matches[0])
      time.sleep(0.15)

   def fields():
      return sorted([control for control in editor.descendants(class_name="Edit") if control.is_visible()
         and win32gui.GetClassName(win32gui.GetParent(control.handle)) != "LCLComboBox"],
         key=lambda c: c.rectangle().top)

   def certificates():
      return [c for c in editor.descendants(class_name="Button") if c.is_visible()
         and c.window_text() == "Verify the server's certificate"]

   observations = []
   for kind in ("DXKEEPER", "ACLOG", "WRL", "CLOUDLOG", "CLUBLOG"):
      select_provider(kind)
      values = fields()
      active = editor.child_window(title="Active (send newly logged QSOs)", class_name="Button")
      if active.get_check_state():
         raise AssertionError("New logger must remain inactive")
      row = {"provider": kind, "fields": [c.window_text() for c in values], "certificate_controls": len(certificates())}
      if kind in {"DXKEEPER", "ACLOG"}:
         if len(values) != 3 or certificates():
            raise AssertionError("Host/port provider shows wrong fields")
         if kind == "ACLOG" and values[-1].window_text() != "1100":
            raise AssertionError("ACLog default port must be 1100")
      elif len(certificates()) != 1:
         raise AssertionError("HTTP logger must show one destination certificate control")
      if kind == "CLOUDLOG":
         values[1].set_edit_text("http://127.0.0.1:65534")
         values[1].type_keys("{TAB}")
         wait_until(3, 0.1, lambda: not certificates()[0].is_enabled())
      if kind == "CLUBLOG":
         if len(values) != 3:
            raise AssertionError("Club Log must show only name, callsign and token")
         values[1].set_edit_text("W1AW")
         token = values[2]
         token.set_edit_text("gui-token-not-a-real-token")
         if token.send_message(0x00D2) == 0:
            raise AssertionError("API token is not masked")
         bounds = token.rectangle()
         eyes = [c for c in editor.descendants() if c.is_visible() and c.rectangle().left >= bounds.right
            and c.rectangle().left - bounds.right < 40 and abs(c.rectangle().top - bounds.top) < 8
            and 8 < c.rectangle().width() < 40]
         if len(eyes) != 1:
            raise RuntimeError("Token reveal control is not unique")
         eyes[0].click_input()
         if token.send_message(0x00D2) != 0:
            raise AssertionError("Reveal did not unmask the token")
         eyes[0].click_input()
         if token.send_message(0x00D2) == 0:
            raise AssertionError("Second reveal click did not mask the token")
         before = editor.rectangle().height()
         certificates()[0].click_input()
         wait_until(3, 0.1, lambda: editor.rectangle().height() > before)
      capture(editor, output / (kind.lower() + ".png"))
      describe_windows(app, output)
      observations.append(row)
   editor.child_window(title="Cancel").click_input()
   editor.wait_not("visible", timeout=10)
   if prefs.child_window(title="Save", class_name="Button").is_enabled():
      raise AssertionError("Cancelling an added definition armed Preferences Save")
   for kind, name in (("DXKEEPER", "GUI DX1"), ("ACLOG", "GUI AC2")):
      prefs.child_window(title="Add...", class_name="Button").click_input()
      editor.wait("visible enabled", timeout=10)
      select_provider(kind)
      fields()[0].set_edit_text(name)
      if editor.child_window(title="Active (send newly logged QSOs)", class_name="Button").get_check_state():
         raise AssertionError("Definition unexpectedly active")
      editor.child_window(title="Save to Preferences").click_input()
      editor.wait_not("visible", timeout=10)
   rectangle = grid().rectangle()
   start = (rectangle.left + 20, rectangle.top + 35)
   mouse.press(coords=start)
   for offset in (8, 16, 24):
      mouse.move(coords=(start[0], start[1] + offset))
      time.sleep(0.15)
   mouse.release(coords=(start[0], start[1] + 24))
   capture(prefs, output / "reordered.png")
   prefs.child_window(title="Save and close").click_input()
   prefs.wait_not("visible", timeout=10)
   close_normally(app, main, journal)
   stored = json.loads((root / "runs" / run_name / "tr4w.json").read_text(encoding="utf-8-sig"))
   definitions = stored["externalLoggers"]
   (output / "stored-loggers.json").write_text(json.dumps(definitions, indent=3), encoding="utf-8")
   if [item["name"] for item in definitions] != ["GUI AC2", "GUI DX1"] or stored["activeExternalLoggerIds"]:
      raise AssertionError("Order or inactive state did not persist")
   database = list((root / "runs" / run_name).glob("*.db"))[0]
   app = launch(root, run_name, database.name)
   main = app.window(title_re=r"TR4W v.*CWOPEN.*")
   main.wait("visible enabled", timeout=30)
   main.type_keys("^j")
   prefs = app.window(title="TR4W Preferences")
   prefs.wait("visible enabled", timeout=10)
   select_page(prefs, log, 17)
   grid().click_input(button="right", coords=(100, 35))
   click_context_menu(prefs, "Edit", journal)
   editor = app.window(title="External logger")
   editor.wait("visible enabled", timeout=10)
   if fields()[0].window_text() != "GUI AC2" or fields()[-1].window_text() != "1100":
      raise AssertionError("Reopened reordered definition does not match saved provider/port")
   editor.child_window(title="Cancel").click_input()
   prefs.child_window(title="Cancel").click_input()
   baseline = root / "runs" / run_name / "ui-baselines/logger-empty.png"
   compare_images(output / "empty-grid.png", baseline, output / "empty-grid-diff.png")
   (output / "logger-result.json").write_text(json.dumps({"providers": observations,
      "order": [item["name"] for item in definitions], "inactive": True, "restart_verified": True}, indent=3), encoding="utf-8")
   return {"passed": True, "note": "Provider fields, masking, Cancel, inactive order/restart and empty-grid baseline asserted"}, app, main
