"""Named documentation captures and Preferences evidence, driven by Python."""

import argparse
import ctypes
import json
import time
import traceback
from pathlib import Path
from pywinauto.timings import wait_until

from session import capture, describe_windows, launch


def main():
   parser = argparse.ArgumentParser(description=__doc__)
   parser.add_argument("scenario", choices=["preferences", "preferences-audit", "station-hints", "new-contest", "cw-open", "cw-open-qso", "cw-open-collision"])
   parser.add_argument("--run", default="pilot-001")
   parser.add_argument("--root", type=Path, default=Path(r"C:\TR4W-Test"))
   args = parser.parse_args()
   output = args.root / "artifacts" / args.scenario
   output.mkdir(parents=True, exist_ok=True)
   ctypes.windll.user32.SetProcessDPIAware()
   result = {"scenario": args.scenario, "passed": False, "captures": []}
   app = None
   try:
      existing = list((args.root / "runs" / args.run).glob("CWOPEN*.db"))
      is_cwo = args.scenario in {"cw-open", "cw-open-qso"}
      create = args.scenario in {"new-contest", "cw-open-collision"} or (is_cwo and not existing)
      contest = existing[0].name if is_cwo and existing else "practice.db"
      app = launch(args.root, args.run, "" if create else contest)
      result["pid"] = app.process
      if create:
         window = app.window(title_re=r".*Open configuration file or start a new contest")
      elif args.scenario in {"preferences", "preferences-audit", "station-hints"}:
         main_window = app.window(title_re=r"TR4W v.*")
         main_window.wait("visible", timeout=30)
         main_window.set_focus()
         main_window.type_keys("^j")
         window = app.window(title="TR4W Preferences")
      else:
         window = app.window(title_re=r"TR4W v.*CWOPEN.*")
      window.wait("visible", timeout=30)
      if create:
         edits = sorted(window.descendants(class_name="Edit"), key=lambda c: c.rectangle().left)
         if len(edits) != 2:
            raise AssertionError("Expected search and callsign fields before contest selection")
         edits[0].set_edit_text("CW Open")
         lists = [c for c in window.descendants() if c.class_name() == "LCLListBox"]
         if len(lists) != 1:
            raise AssertionError("Contest list was not uniquely identified")
         lists[0].set_focus()
         lists[0].type_keys("{HOME}")
         edits[1].set_focus()
         edits[1].type_keys("^aW1AW", with_spaces=True)
         name_fields = [
            c for c in window.descendants(class_name="Edit")
            if c.handle not in {edits[0].handle, edits[1].handle}
         ]
         if len(name_fields) == 1:
            name_fields[0].set_focus()
            name_fields[0].type_keys("^aTOM{TAB}", with_spaces=True)
      describe_windows(app, output)
      capture(window, output / (args.scenario + ".png"))
      result["captures"].append(args.scenario + ".png")
      if args.scenario == "cw-open-collision":
         if not existing:
            raise AssertionError("Collision scenario requires the existing same-day CWOPEN fixture")
         window.child_window(title_re="&?OK", class_name="Button").click_input()
         question = app.window(class_name="#32770")
         question.wait("visible", timeout=10)
         capture(question, output / "same-day-session-prompt.png")
         result["captures"].append("same-day-session-prompt.png")
         question.child_window(title_re="&?No", class_name="Button").click_input()
         result["review_note"] = "Selected No; existing practice contacts were not deliberately overwritten"
      if args.scenario == "station-hints":
         bounds = window.rectangle()
         tree = [c for c in window.descendants(class_name="Window")
                 if c.is_visible() and c.rectangle().height() > 300
                 and c.rectangle().width() < 250 and c.rectangle().left < bounds.left + 200][0]
         tree.set_focus()
         tree.type_keys("{HOME}")
         def grid_fields():
            return [c for c in window.descendants(class_name="Edit")
                    if c.is_visible() and c.window_text() == "FN31"]
         wait_until(5, 0.1, lambda: len(grid_fields()) == 1)
         grid = grid_fields()
         if len(grid) != 1:
            raise AssertionError("MY GRID fixture is not uniquely identifiable")
         grid[0].set_focus()
         rect = grid[0].rectangle()
         from pywinauto import mouse
         mouse.move(coords=(bounds.left + 10, bounds.top + 10))
         time.sleep(0.3)
         grid[0].move_mouse_input(coords=(rect.width() // 2, rect.height() // 2))
         time.sleep(2)
         capture(window, output / "my-grid-hover.png")
         result["captures"].append("my-grid-hover.png")
         describe_windows(app, output)
      if args.scenario == "preferences-audit":
         from preferences_audit import audit
         pages = audit(app, window, args.root / "runs" / args.run / "tr4w.log", output)
         result["observed_pages"] = len(pages)
         result["review_note"] = "Observed focus cycles and screenshots require semantic order review"
      if args.scenario == "cw-open":
         if create:
            ok = window.child_window(title_re="&?OK", class_name="Button")
            ok.wait("enabled", timeout=5)
            ok.click_input()
         main_window = app.window(title_re=r"TR4W v.*CWOPEN.*")
         main_window.wait("visible", timeout=30)
         capture(main_window, output / "cw-open-main.png")
         result["captures"].append("cw-open-main.png")
         result["main_title"] = main_window.window_text()
         menus = {}
         for item in main_window.menu().items():
            submenu = item.sub_menu()
            menus[item.text()] = [child.text() for child in submenu.items()] if submenu else []
         (output / "menus.json").write_text(json.dumps(menus, indent=3), encoding="utf-8")
         main_window.set_focus()
         main_window.type_keys("%p")
         messages = app.window(title="List of messages")
         messages.wait("visible", timeout=10)
         capture(messages, output / "cq-messages.png")
         result["captures"].append("cq-messages.png")
         lists = messages.descendants(class_name="SysListView32")
         if len(lists) != 1:
            raise AssertionError("Message list not uniquely observable")
         lists[0].select(0)
         lists[0].set_focus()
         messages.type_keys("{ENTER}")
         editor = app.window(title="Program message")
         editor.wait("visible", timeout=10)
         capture(editor, output / "message-editor.png")
         result["captures"].append("message-editor.png")
         editor.type_keys("{ESC}")
         messages.type_keys("{ESC}")
         main_window.menu_select("Settings->Program messages")
         chooser = app.window(title="Memory program function")
         chooser.wait("visible", timeout=10)
         capture(chooser, output / "message-chooser.png")
         result["captures"].append("message-chooser.png")
         chooser.type_keys("{ESC}")
         describe_windows(app, output)
      if args.scenario == "cw-open-qso":
         fields = sorted(
            [c for c in window.descendants(class_name="Edit") if c.is_visible()],
            key=lambda c: c.rectangle().top,
         )
         if len(fields) != 2:
            raise AssertionError("Call and exchange entry fields are not uniquely identifiable")
         fields[0].set_focus()
         fields[0].set_edit_text("")
         fields[0].type_keys("K6RB")
         fields[1].set_focus()
         fields[1].set_edit_text("")
         fields[1].type_keys("1 ROB", with_spaces=True)
         fields[1].type_keys("^{ENTER}")
         # The CQ state machine may first advance to the exchange stage.
         if fields[0].window_text():
            fields[1].type_keys("^{ENTER}")
         time.sleep(1)
         capture(window, output / "practice-qso.png")
         result["captures"].append("practice-qso.png")
         if app.window(title_re="Sending CW from the keyboard.*").exists(timeout=0):
            raise AssertionError("Unexpected keyboard-CW modal: contact capture is invalid")
         result["review_note"] = "Contact row and score need visual verification; capture alone is not a logging assertion"
         describe_windows(app, output)
      result["passed"] = True
   except Exception:
      result["error"] = traceback.format_exc()
      if app is not None:
         try:
            describe_windows(app, output)
            capture(app.top_window(), output / "failure.png")
         except Exception:
            result["diagnostic_error"] = traceback.format_exc()
   finally:
      if app is not None:
         app.kill()
      (output / "result.json").write_text(json.dumps(result, indent=3), encoding="utf-8")
   print(json.dumps(result))
   return 0 if result["passed"] else 1


if __name__ == "__main__":
   raise SystemExit(main())
