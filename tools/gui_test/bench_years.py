"""Create and reopen licence-year contests using the real New Contest form."""

from contextlib import closing
import json
import sqlite3

from contest_forms import choose_contest, set_field, dismiss_grid_prompt
from session import capture, close_normally, launch


def form_texts(app, startup):
   # LCL labels are not windows; UI Automation is the only text route to the
   # New Contest prompt. An empty result means "not readable", not "absent".
   from pywinauto import Application
   uiapp = Application(backend="uia").connect(process=app.process)
   return [control.window_text() for control in uiapp.window(handle=startup.handle).descendants()
      if control.window_text()]


def chosen_contest(startup):
   lists = [control for control in startup.descendants(class_name="LCLListBox") if control.is_visible()]
   items = lists[0].item_texts() if len(lists) == 1 else []
   return items[0] if items else None


def prompts(app, startup, root, run_name, output, journal):
   """Issues 290 and 287: New Contest prompts and the Jock White branch row."""
   directory = root / "runs" / run_name
   if list(directory.glob("*.db")):
      raise RuntimeError("Prompt checks require a fresh fixture")
   observed = {}
   failures = []

   def look(key, search):
      choose_contest(startup, search, journal)
      capture(startup, output / (key + ".png"))
      texts = form_texts(app, startup)
      observed[key] = {"contest": chosen_contest(startup), "texts": texts}
      return " ".join(texts)

   nccc = look("nccc", "NCCC Sprint")
   if "or member number" in nccc:
      failures.append("NCCC Sprint prompt still offers a member number")
   cwt = look("cwt", "CWT")
   boxes = [control for control in startup.descendants(class_name="Button")
      if control.is_visible() and control.window_text() == "Show inactive contests"]
   if len(boxes) != 1:
      raise RuntimeError("Show inactive contests checkbox not unique")
   if boxes[0].get_check_state() != 1:
      journal.perform("show inactive contests", boxes[0].click_input)
   locust = look("locust", "Locust")
   if "or member number" in locust:
      failures.append("Locust QSO Party prompt still offers a member number")
   for key, text in (("nccc", nccc), ("cwt", cwt), ("locust", locust)):
      observed[key]["prompt_readable"] = "Enter your" in text
   if observed["cwt"]["prompt_readable"] and "or member number" not in cwt:
      failures.append("CWT prompt lost its member number")
   fields = choose_contest(startup, "Jock White", journal)
   observed["jockwhite"] = {"contest": chosen_contest(startup), "texts": form_texts(app, startup)}
   if len(fields) != 1:
      raise AssertionError("Expected one Jock White branch field, found " + str(len(fields)))
   set_field(fields[0], "27", journal)
   capture(startup, output / "jockwhite.png")
   startup.child_window(title_re="&?OK", class_name="Button").click_input()
   main = app.window(title_re=r"TR4W v.*")
   main.wait("visible enabled", timeout=30)
   dismiss_grid_prompt(app, journal)
   capture(main, output / "jockwhite-created.png")
   close_normally(app, main, journal)
   databases = list(directory.glob("*.db"))
   if len(databases) != 1:
      raise AssertionError("Created database is not unique")
   with closing(sqlite3.connect(databases[0].resolve().as_uri() + "?mode=ro", uri=True)) as connection:
      rows = connection.execute("SELECT command,value,source FROM config WHERE command = 'MY ZONE'").fetchall()
   observed["jockwhite"]["my_zone_rows"] = rows
   observed["jockwhite"]["database"] = databases[0].name
   if not any(row[1] == "27" for row in rows):
      failures.append("Jock White branch 27 was not stored as MY ZONE: " + repr(rows))
   (output / "prompts-result.json").write_text(json.dumps({"observed": observed, "failures": failures},
      indent=3), encoding="utf-8")
   return {"passed": not failures, "failures": failures,
      "note": "Prompt wording asserted where UIA exposes it; row labels require screenshot review"}


def check(app, startup, root, run_name, output, journal, phase):
   if phase == "bench-prompts-check":
      return prompts(app, startup, root, run_name, output, journal)
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
      # Since issue 298 the sent year is its own contest-scoped command,
      # MY LICENSE YEAR. MY ZONE is a zone in every contest and must not
      # carry the year typed on the New Contest form.
      with closing(sqlite3.connect(databases[0].resolve().as_uri() + "?mode=ro", uri=True)) as connection:
         rows = connection.execute("SELECT command,value,source FROM config WHERE command IN "
            "('MY LICENSE YEAR','MY ZONE')").fetchall()
      years = [row for row in rows if row[0] == "MY LICENSE YEAR"]
      if len(years) != 1 or years[0][1] != "64":
         raise AssertionError("Licence year did not persist under MY LICENSE YEAR: " + repr(rows))
      if any(row[0] == "MY ZONE" and row[1] == "64" for row in rows):
         raise AssertionError("Licence year was also written to MY ZONE: " + repr(rows))
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
   # Preferences shows the STATION's License year (the default), not this
   # contest's override, so its value is recorded but not asserted
   # (BENCH_QUEUE, issue 298). The search must land on an edit box.
   control, observation = search_control(prefs, "MY LICENSE YEAR", output, journal)
   (output / "reopened-year.json").write_text(json.dumps(observation, indent=3), encoding="utf-8")
   if observation["kind"] != "edit":
      raise AssertionError("MY LICENSE YEAR search did not focus an edit box: " + repr(observation))
   prefs.child_window(title="Cancel").click_input()
   close_normally(app, main, journal)
   result = {"passed": True, "contest": name, "saved_rows": before,
      "reopened_control": observation, "rows_after_reopen": stored_year(),
      "note": "MY LICENSE YEAR storage across reopen and the Preferences search target verified; labels require screenshot review"}
   (output / "year-result.json").write_text(json.dumps(result, indent=3), encoding="utf-8")
   return result
