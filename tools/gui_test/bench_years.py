"""Create and reopen licence-year contests using the real New Contest form."""

from contextlib import closing
import json
import sqlite3

from contest_forms import choose_contest, set_field, dismiss_grid_prompt
from session import capture, close_normally, launch


def check(app, startup, root, run_name, output, journal, phase):
   directory = root / "runs" / run_name
   if list(directory.glob("*.db")):
      raise RuntimeError("Year creation requires a fresh fixture")
   zone = phase == "bench-zone-create"
   name = "IARU HF World Championship" if zone else ("European HF" if phase.endswith("euhfc") else "KV PRVENSTVO ZRS")
   fields = choose_contest(startup, name, journal)
   if zone and fields:
      raise AssertionError("Regular IARU station should not require HQ exchange input")
   if not zone and len(fields) != 1:
      raise AssertionError("Expected one licence-year field")
   if not zone:
      set_field(fields[0], "64", journal)
   capture(startup, output / "year-setup.png")
   startup.child_window(title_re="&?OK", class_name="Button").click_input()
   main = app.window(title_re=r"TR4W v.*")
   main.wait("visible enabled", timeout=30)
   dismiss_grid_prompt(app, journal)
   capture(main, output / "created.png")
   close_normally(app, main, journal)
   databases = list(directory.glob("*.db"))
   if len(databases) != 1:
      raise AssertionError("Created database is not unique")
   if zone:
      return {"passed": True, "note": "IARU isolated log created; zone exports remain pending"}

   def stored_year():
      with closing(sqlite3.connect(databases[0].resolve().as_uri() + "?mode=ro", uri=True)) as connection:
         rows = connection.execute("SELECT command,value,source FROM config WHERE command = 'MY ZONE'").fetchall()
      if len(rows) != 1 or rows[0][1] != "64":
         raise AssertionError("Licence year did not persist under MY ZONE: " + repr(rows))
      return rows

   before = stored_year()
   (output / "saved-year.json").write_text(json.dumps(before, indent=3), encoding="utf-8")
   app = launch(root, run_name, databases[0].name)
   main = app.window(title_re=r"TR4W v.*")
   main.wait("visible enabled", timeout=30)
   main.type_keys("^j")
   prefs = app.window(title="TR4W Preferences")
   prefs.wait("visible enabled", timeout=10)
   from bench_preferences import search_control
   control, observation = search_control(prefs, "MY ZONE", output, journal)
   (output / "reopened-year.json").write_text(json.dumps(observation, indent=3), encoding="utf-8")
   if observation["value"] != "64":
      raise AssertionError("Reopened MY ZONE differs: " + repr(observation))
   prefs.child_window(title="Cancel").click_input()
   close_normally(app, main, journal)
   result = {"passed": True, "contest": name, "saved_rows": before,
      "reopened_control": observation, "rows_after_reopen": stored_year(),
      "note": "Windows storage and reopened control verified; labels require screenshot review"}
   (output / "year-result.json").write_text(json.dumps(result, indent=3), encoding="utf-8")
   return result
