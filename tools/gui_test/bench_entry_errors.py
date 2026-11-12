"""Check CW Open exchange validation through the real entry fields, without CW."""

from contextlib import closing
import json
import sqlite3

from pywinauto.timings import wait_until

from contest_forms import choose_contest, set_field, dismiss_grid_prompt
from preferences_audit import focus_info
from qso_entry import entry_fields
from session import capture, close_normally


def check(app, startup, root, run_name, output, journal):
   directory = root / "runs" / run_name
   if list(directory.glob("*.db")):
      raise RuntimeError("Exchange-error checks require a fresh run with no log")
   fields = choose_contest(startup, "CW Open", journal)
   if len(fields) != 1:
      raise RuntimeError("CW Open name input not unique")
   set_field(fields[0], "TOM", journal)
   journal.perform("create the empty exchange-test log", lambda: startup.child_window(title_re="&?OK", class_name="Button").click_input())
   main = app.window(title_re=r"TR4W v.*CWOPEN.*")
   main.wait("visible", timeout=30)
   dismiss_grid_prompt(app, journal)
   main.wait("enabled", timeout=10)
   databases = list(directory.glob("CWOPEN*.db"))
   if len(databases) != 1:
      raise RuntimeError("Created exchange-test log is not unique")

   def count():
      with closing(sqlite3.connect(databases[0].resolve().as_uri() + "?mode=ro", uri=True)) as connection:
         return connection.execute("SELECT COUNT(*) FROM qso").fetchone()[0]

   if count() != 0:
      raise AssertionError("Exchange test did not start with zero contacts")
   call, exchange = entry_fields(main)
   call.set_focus()
   journal.perform("type W7SP", lambda: call.type_keys("W7SP"))
   journal.perform("advance without CW", lambda: call.type_keys("^{ENTER}"))
   results = []
   for text, message, name in (("WOODY", "No QSO number found!!", "missing-serial"),
      ("234", "No name found!!", "missing-name")):
      journal.perform("focus exchange", exchange.set_focus)
      journal.perform("enter incomplete exchange " + text, lambda: exchange.set_edit_text(text))
      before_focus = focus_info(main)["handle"]
      journal.perform("submit incomplete exchange without CW", lambda: exchange.type_keys("^{ENTER}"))
      wait_until(5, 0.1, lambda: message in (directory / "tr4w.log").read_text(encoding="utf-8", errors="replace"))
      if count() != 0 or call.window_text() != "W7SP":
         raise AssertionError("Incomplete exchange was logged or changed the callsign")
      if focus_info(main)["handle"] != before_focus:
         raise AssertionError("Refused exchange moved keyboard focus away from the field")
      capture(main, output / (name + ".png"))
      results.append({"input": text, "message": message, "qso_count": 0, "focus_retained": True})
   journal.perform("replace with valid exchange", lambda: exchange.set_edit_text("234 WOODY"))
   journal.perform("submit valid exchange without CW", lambda: exchange.type_keys("^{ENTER}"))
   if call.window_text():
      journal.perform("complete valid CQ entry without CW", lambda: exchange.type_keys("^{ENTER}"))
   wait_until(5, 0.1, lambda: count() == 1)
   if call.window_text() or exchange.window_text():
      raise AssertionError("Valid entry did not clear the input fields")
   capture(main, output / "valid-after-errors.png")
   call.set_focus()
   journal.perform("empty Ctrl+Enter", lambda: call.type_keys("^{ENTER}"))
   capture(main, output / "empty-enter.png")
   if count() != 1 or call.window_text() or exchange.window_text():
      raise AssertionError("Empty Enter changed the log or entry fields")
   close_normally(app, main, journal)
   result = {"passed": True, "pid": app.process, "refusals": results,
      "valid_qso_count": 1, "empty_enter_qso_count": 1,
      "note": "Notice strings, counts and focus passed; screenshots need review for red notices and their clearing"}
   (output / "entry-result.json").write_text(json.dumps(result, indent=3), encoding="utf-8")
   return result
