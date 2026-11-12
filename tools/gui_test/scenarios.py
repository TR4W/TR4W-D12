"""Named documentation captures and Preferences evidence, driven by Python."""

import argparse
from scenario_names import SCENARIOS
import ctypes
import json
import time
import traceback
from pathlib import Path
from pywinauto.timings import wait_until

from session import capture, close_normally, describe_windows, launch, hover_control


def main():
   parser = argparse.ArgumentParser(description=__doc__)
   parser.add_argument("scenario", choices=SCENARIOS)
   parser.add_argument("--run", default="pilot-001")
   parser.add_argument("--root", type=Path, default=Path(r"C:\TR4W-Test"))
   args = parser.parse_args()
   output = args.root / "artifacts" / args.scenario
   output.mkdir(parents=True, exist_ok=True)
   ctypes.windll.user32.SetProcessDPIAware()
   result = {"scenario": args.scenario, "run": args.run, "root": str(args.root), "passed": False, "captures": []}
   if args.scenario.startswith(("radio-", "bench-")):
      try:
         if args.scenario.startswith("bench-"):
            from bench_ui import run
            result.update(run(args.root, args.run, args.scenario))
         else:
            from radio_workflow import step
            result.update(step(args.root, args.run, args.scenario))
      except Exception:
         result["error"] = traceback.format_exc()
         if args.scenario.startswith("radio-"):
            try:
               from radio_workflow import diagnose
               diagnose(args.root, args.run, output)
            except Exception:
               result["diagnostic_error"] = traceback.format_exc()
      (output / "result.json").write_text(json.dumps(result, indent=3), encoding="utf-8")
      return 0 if result["passed"] else 1
   app = None
   try:
      existing = list((args.root / "runs" / args.run).glob("CWOPEN*.db"))
      cwt_cases = {"cwt-messages", "capture-check", "guide-cwt", "cwt-setup"}
      if args.scenario in cwt_cases:
         existing = list((args.root / "runs" / args.run).glob("CWOPS*.db"))
         if len(existing) > 1:
            raise AssertionError("Expected at most one isolated CWOPS practice database")
      is_cwo = args.scenario in {"cw-open", "cw-open-qso"}
      create = args.scenario in {"new-contest", "cw-open-collision", "cwt-setup"} or ((is_cwo or args.scenario == "cwt-messages") and not existing)
      if args.scenario == "capture-check" and len(existing) != 1:
         raise AssertionError("Capture check requires one existing CWOPS practice log")
      contest = existing[0].name if (is_cwo or args.scenario in cwt_cases) and existing else "practice.db"
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
         window = app.window(title_re=r"TR4W v.*CWOPS.*" if args.scenario in cwt_cases else r"TR4W v.*CWOPEN.*")
      window.wait("visible", timeout=30)
      if args.scenario == "capture-check":
         from evidence import StepLog
         journal = StepLog(output / "steps.jsonl")
         journal.perform("wait for main window ready", lambda: window.wait("enabled", timeout=15))
         window.set_focus()
         window.capture_as_image().save(output / "desktop-rectangle-before.png")
      if create:
         edits = sorted(window.descendants(class_name="Edit"), key=lambda c: c.rectangle().left)
         if len(edits) != 2:
            raise AssertionError("Expected search and callsign fields before contest selection")
         edits[0].set_edit_text("CWT" if args.scenario in cwt_cases else "CW Open")
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
         if args.scenario in cwt_cases:
            name_fields.sort(key=lambda c: c.rectangle().top)
            if len(name_fields) != 2:
               raise AssertionError("Expected CWT MY NAME and MY STATE inputs")
            name_fields[0].set_focus()
            name_fields[0].type_keys("^aTOM{TAB}")
            name_fields[1].set_focus()
            name_fields[1].type_keys("^aFL{TAB}")
      describe_windows(app, output)
      capture(window, output / (args.scenario + ".png"))
      result["captures"].append(args.scenario + ".png")
      if args.scenario == "guide-bandmap":
         from evidence import StepLog
         from guide_capture import capture_cluster
         journal = StepLog(output / "steps.jsonl")
         capture_cluster(app, window, output, journal)
         describe_windows(app, output)
         close_normally(app, window, journal)
         app = None
      if args.scenario in {"guide-cwo", "guide-cwt"}:
         from evidence import StepLog
         from message_workflow import program_messages
         journal = StepLog(output / "steps.jsonl")
         is_cwt = args.scenario == "guide-cwt"
         program_messages(app, window, output, journal,
            event="CWT" if is_cwt else "CWO", exchange="TOM FL" if is_cwt else "# TOM", read_only=True)
         if not is_cwt:
            from guide_capture import capture_station
            capture_station(app, window, output, journal)
         describe_windows(app, output)
         close_normally(app, window, journal)
         app = None
      if args.scenario == "capture-check":
         window.menu_select("Settings->Program messages")
         chooser = app.window(title="Memory program function")
         chooser.wait("visible", timeout=10)
         chooser.set_focus()
         chooser.capture_as_image().save(output / "dialog-rectangle-before.png")
         capture(chooser, output / "dialog-visible-frame.png")
         result["captures"].append("dialog-visible-frame.png")
         chooser.type_keys("{ESC}")
         close_normally(app, window, journal)
         app = None
      if args.scenario == "cwt-messages":
         from evidence import StepLog
         from message_workflow import program_messages
         journal = StepLog(output / "steps.jsonl")
         if create:
            journal.perform("create isolated CWT practice log", lambda: window.child_window(title_re="&?OK", class_name="Button").click_input())
         main_window = app.window(title_re=r"TR4W v.*CWOPS.*")
         journal.perform("wait for CWOPS main window", lambda: main_window.wait("visible", timeout=30))
         notice = app.window(class_name="#32770")
         if notice.exists(timeout=2):
            from pywinauto import Application
            uiapp = Application(backend="uia").connect(process=app.process)
            text = " ".join(c.window_text() for c in uiapp.window(handle=notice.handle).descendants())
            if "Set value of MY GRID" not in text:
               raise RuntimeError("Unexpected startup prompt: " + text)
            journal.perform("defer grid setup in isolated message-only fixture", lambda: notice.child_window(title="&No").click_input())
         journal.perform("wait for main window ready", lambda: main_window.wait("enabled", timeout=10))
         program_messages(app, main_window, output, journal, event="CWT", exchange="TOM FL")
         result["captures"].extend([
            "message-chooser.png", "cq-messages.png", "message-editor.png",
            "sp-messages.png", "other-messages.png", "cwt-main.png",
         ])
         journal.perform("capture CWT main window", lambda: capture(main_window, output / "cwt-main.png"))
         describe_windows(app, output)
         close_normally(app, main_window, journal)
         app = None
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
         hover_control(grid[0])
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
         from evidence import StepLog
         from message_workflow import program_messages
         program_messages(app, main_window, output, StepLog(output / "steps.jsonl"))
         result["captures"].extend([
            "message-chooser.png", "cq-messages.png", "message-editor.png",
            "sp-messages.png", "other-messages.png",
         ])
         describe_windows(app, output)
         close_normally(app, main_window, StepLog(output / "steps.jsonl"))
         app = None
      if args.scenario == "cw-open-qso":
         from evidence import StepLog
         from qso_entry import log_without_cw
         log_without_cw(window, "K6RB", "1 ROB", StepLog(output / "steps.jsonl"))
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
