"""Exercise non-destructive New Contest collision choices on a cloned practice log."""

import json
import sqlite3
from contextlib import closing

from contest_forms import choose_contest, set_field, dismiss_grid_prompt
from evidence import file_digest
from session import capture, close_normally, launch


def form_values(startup):
   controls = [control for control in startup.descendants() if control.is_visible()
      and control.class_name() in {"Edit", "LCLComboBox"}]
   controls.sort(key=lambda control: (control.rectangle().top, control.rectangle().left))
   return [(control.class_name(), control.window_text()) for control in controls]


def ask(app, startup, journal, expected_buttons=("Create new log", "Open existing log", "Cancel")):
   journal.perform("submit a taken CW Open name", lambda: startup.child_window(title_re="&?OK", class_name="Button").click_input())
   question = app.window(title="This contest already has a log")
   journal.perform("wait for taken-name question", lambda: question.wait("visible", timeout=10))
   buttons = {control.window_text().replace("&", ""): control for control
      in question.descendants(class_name="Button") if control.is_visible()}
   if set(buttons) != set(expected_buttons):
      raise AssertionError("Unexpected startup collision buttons: " + repr(list(buttons)))
   return question, buttons


def cw_open(startup, journal):
   fields = choose_contest(startup, "CW Open", journal)
   if len(fields) != 1:
      raise RuntimeError("CW Open name row not unique")
   set_field(fields[0], "TOM", journal)


def start(root, run_name, journal):
   app = journal.perform("restart into the startup picker", lambda: launch(root, run_name, ""))
   startup = app.window(title_re=r".*Open configuration file or start a new contest")
   startup.wait("visible", timeout=30)
   cw_open(startup, journal)
   return app, startup


def wait_main(app, contest, journal):
   main = app.window(title_re=r"TR4W v.*" + contest + r".*")
   main.wait("visible", timeout=30)
   dismiss_grid_prompt(app, journal)
   main.wait("enabled", timeout=10)
   return main


def check(app, startup, root, run_name, output, journal, phase="bench-lognames"):
   directory = root / "runs" / run_name
   original = list(directory.glob("CWOPEN*.db"))
   close_only = phase.endswith("-close")
   if close_only:
      original = [path for path in original if path.stem.endswith(" W1AW")]
   if len(original) != 1:
      raise RuntimeError("Naming test requires one cloned original CWOPEN log")
   original = original[0]
   original_hash = file_digest(original)
   before_files = sorted(path.name for path in directory.glob("*.db"))
   cw_open(startup, journal)
   before_values = form_values(startup)
   for action in (("Close",) if close_only else ("Escape", "Close", "Cancel")):
      question, buttons = ask(app, startup, journal)
      journal.perform("capture three-choice question " + action,
         lambda: capture(question, output / ("question-" + action.lower() + ".png")))
      if action == "Escape":
         journal.perform("cancel question using Escape", lambda: question.type_keys("{ESC}"))
      elif action == "Close":
         journal.perform("click the question's title-bar close button", lambda: question.click_input(
            coords=(question.rectangle().width() - 20, 14)))
      else:
         journal.perform("cancel question using Cancel", buttons["Cancel"].click_input)
      question.wait_not("visible", timeout=10)
      startup.wait("visible enabled", timeout=10)
      if form_values(startup) != before_values:
         raise AssertionError("New Contest inputs changed after " + action)
      if sorted(path.name for path in directory.glob("*.db")) != before_files:
         raise AssertionError(action + " created or removed a database")
   journal.perform("capture retained fields after cancellations", lambda: capture(startup, output / "cancel-retained.png"))
   if close_only:
      journal.perform("leave startup without creating a log", lambda: startup.child_window(title="Cancel").click_input())
      app.wait_for_process_exit(timeout=20)
      return {"passed": True, "pid": app.process, "close_button": "physical mouse click",
         "inputs_preserved": True, "created_no_files": True}
   for number in (2, 3):
      question, buttons = ask(app, startup, journal)
      expected = original.with_name(original.stem + " " + str(number) + ".db")
      journal.perform("accept default Create new log with Enter", lambda: question.type_keys("{ENTER}"))
      main = wait_main(app, "CWOPEN", journal)
      if not expected.is_file():
         raise AssertionError("Expected numbered log was not created: " + str(expected))
      journal.perform("capture empty numbered log " + str(number),
         lambda: capture(main, output / ("numbered-" + str(number) + ".png")))
      close_normally(app, main, journal)
      if file_digest(original) != original_hash:
         raise AssertionError("Creating numbered logs modified the original database")
      app, startup = start(root, run_name, journal)
   question, buttons = ask(app, startup, journal)
   files_before_open = sorted(path.name for path in directory.glob("*.db"))
   journal.perform("open the existing original", buttons["Open existing log"].click_input)
   main = wait_main(app, "CWOPEN", journal)
   journal.perform("capture original contacts after Open existing", lambda: capture(main, output / "opened-original.png"))
   if sorted(path.name for path in directory.glob("*.db")) != files_before_open:
      raise AssertionError("Open existing created a new database")
   close_normally(app, main, journal)
   app, startup = start(root, run_name, journal)
   question, buttons = ask(app, startup, journal)
   journal.perform("Cancel before choosing another contest", buttons["Cancel"].click_input)
   question.wait_not("visible", timeout=10)
   fields = choose_contest(startup, "CWops Test", journal)
   if len(fields) != 2:
      raise RuntimeError("CWT name/member fields not unique")
   for field, value in zip(fields, ("TOM", "1234")):
      set_field(field, value, journal)
   journal.perform("create the different CWT contest", lambda: startup.child_window(title_re="&?OK", class_name="Button").click_input())
   main = wait_main(app, "CWOPS", journal)
   journal.perform("capture different contest after Cancel", lambda: capture(main, output / "cwt-after-cancel.png"))
   tool_menu = main.menu().get_menu_path("Tools")[0].sub_menu()
   submit = [item for item in tool_menu.items() if item.text().replace("&", "") == "Submit ARRL Log"]
   if len(submit) != 1 or submit[0].is_enabled():
      raise AssertionError("Submit ARRL Log should be disabled for CWT")
   close_normally(app, main, journal)
   cwt = list(directory.glob("CWOPS*.db"))
   if len(cwt) != 1:
      raise AssertionError("The different CWT log is not unique")
   with closing(sqlite3.connect(cwt[0].resolve().as_uri() + "?mode=ro", uri=True)) as connection:
      member = connection.execute("SELECT value FROM config WHERE command=?", ("MY STATE",)).fetchone()
   if member != ("1234",):
      raise AssertionError("CWT did not store the entered member number under MY STATE")
   result = {"passed": True, "pid": app.process, "original_sha256_before_numbering": original_hash,
      "original_unchanged_after_numbering": True, "cancel_actions": ["Escape", "Close", "Cancel"],
      "inputs_preserved": True, "cancel_created_no_files": True, "numbered_logs": [2, 3],
      "open_existing_created_no_file": True, "different_contest_after_cancel": "CWOPS",
      "cwt_submit_arrl_enabled": False,
      "cwt_saved_my_state": member[0],
      "note": "Behavior assertions passed; question wording, empty serials and original-QSO screenshots need visual review"}
   (output / "naming-result.json").write_text(json.dumps(result, indent=3), encoding="utf-8")
   return result
