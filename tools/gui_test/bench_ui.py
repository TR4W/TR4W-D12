"""Black-box Windows checks selected from BENCH_QUEUE; never touch station hardware."""

import json
from pathlib import Path

from pywinauto import Application
from pywinauto.controls.win32_controls import ListBoxWrapper

from evidence import StepLog, preserve_build
from session import capture, close_normally, describe_windows, launch
from qso_entry import log_without_cw
from contest_forms import choose_contest, set_field, dismiss_grid_prompt


def run(root, run_name, phase):
   root = Path(root)
   output = root / "artifacts" / phase
   output.mkdir(parents=True, exist_ok=True)
   journal = StepLog(output / "steps.jsonl")
   metadata = preserve_build(root / "app" / "tr4w_fpc.exe", root / "evidence")
   (output / "build-evidence.json").write_text(json.dumps(metadata, indent=3), encoding="utf-8")
   if phase == "bench-locked-regression":
      from bench_locked import run as check_locked
      return check_locked(root, run_name, output, journal)
   database = ""
   if phase.startswith(("bench-prefs", "bench-switch", "bench-export", "bench-messages", "bench-tools", "bench-import", "bench-search", "bench-k4", "bench-tailcat")):
      databases = list((root / "runs" / run_name).glob("*.db" if phase.startswith(("bench-export-year", "bench-export-zone")) else "CWOPEN*.db"))
      if len(databases) != 1:
         raise RuntimeError("Preferences batch requires exactly one CW Open fixture")
      database = databases[0].name
   app = journal.perform("launch isolated current-main build", lambda: launch(root, run_name, database))
   state = root / "runs" / run_name / "bench-workflow.json"
   state.write_text(json.dumps({"pid": app.process}), encoding="utf-8")
   try:
      if phase.startswith(("bench-prefs", "bench-switch", "bench-export", "bench-messages", "bench-tools", "bench-import", "bench-search", "bench-k4", "bench-tailcat")):
         from bench_preferences import check, verify_storage
         main = app.window(title_re=r"TR4W v.*" if phase.startswith(("bench-export-year", "bench-export-zone")) else r"TR4W v.*CWOPEN.*")
         main.wait("visible enabled", timeout=30)
         if phase.startswith("bench-tailcat"):
            from bench_tailcat import check as check_tailcat
            result = check_tailcat(app, main, root, run_name, output, journal, phase)
         elif phase.startswith("bench-k4"):
            from bench_k4 import check as check_k4
            result = check_k4(app, main, root, run_name, output, journal, phase)
         elif phase.startswith("bench-search"):
            from bench_search import check as check_search
            result = check_search(app, main, root, run_name, output, journal)
         elif phase.startswith("bench-import"):
            from bench_import import check as check_import
            result = check_import(app, main, root, run_name, output, journal)
         elif phase.startswith("bench-tools"):
            from bench_remaining import inspect_main
            result = inspect_main(app, main, output, journal, phase)
         elif phase.startswith("bench-messages"):
            from bench_messages import check as check_messages
            result, app, main = check_messages(app, main, root, run_name, output, journal)
         elif phase.startswith("bench-export"):
            from bench_exports import check as check_export
            result = check_export(app, main, root, run_name, output, journal, phase)
         elif phase.startswith("bench-switch"):
            from bench_switch import check as check_switch
            result = check_switch(app, main, output, journal, phase, root, run_name)
         else:
            result = check(app, main, output, journal, phase, root, run_name)
         if isinstance(result, tuple):
            result, app, main = result
         close_normally(app, main, journal)
         if phase.endswith(("-save", "-verify", "-restore")):
            verify_storage(root, run_name, output, phase)
         return dict(result, pid=app.process)
      startup = app.window(title_re=r".*Open configuration file or start a new contest")
      journal.perform("wait for New Contest", lambda: startup.wait("visible", timeout=30))
      if phase == "bench-county-inspect":
         from bench_county import inspect
         return inspect(app, startup, output, journal)
      if phase in {"bench-county-check", "bench-county-texas"}:
         from bench_county import check
         return check(app, startup, root, run_name, output, journal, phase)
      if phase.startswith("bench-year-") or phase in {"bench-zone-create", "bench-prompts-check"}:
         from bench_years import check
         return check(app, startup, root, run_name, output, journal, phase)
      if phase == "bench-entry-errors":
         from bench_entry_errors import check
         return check(app, startup, root, run_name, output, journal)
      if phase.startswith("bench-lognames"):
         from bench_log_names import check
         return check(app, startup, root, run_name, output, journal, phase)
      edits = [control for control in startup.descendants(class_name="Edit") if control.is_visible()]
      min(edits, key=lambda control: control.rectangle().left).set_edit_text("")
      lists = [control for control in startup.descendants(class_name="LCLListBox") if control.is_visible()]
      catalog = ListBoxWrapper(lists[0].handle).texts()
      (output / "contest-catalog.json").write_text(json.dumps(catalog, indent=3), encoding="utf-8")
      if phase == "bench-catalog":
         startup.child_window(title="Show inactive contests").click_input()
         catalog = ListBoxWrapper(lists[0].handle).texts()
         (output / "contest-catalog-with-inactive.json").write_text(json.dumps(catalog, indent=3), encoding="utf-8")
         capture(startup, output / "catalog.png")
         startup.child_window(title="Cancel").click_input()
         app.wait_for_process_exit(timeout=20)
         return {"passed": True, "pid": app.process, "note": "Catalog enumerated from native visible list"}
      if phase != "bench-seed":
         inactive = startup.child_window(title="Show inactive contests")
         if not inactive.get_check_state():
            journal.perform("include inactive Locust regression case", inactive.click_input)
      inspections = (
         ("CWops Test", "cwt", ("TOM", "1234")),
         ("European HF", "euhfc", ("64",)),
         ("KV PRVENSTVO ZRS", "kvp", ("64",)),
         ("North American QSO Party, CW", "naqp", ("FL", "TOM")),
         ("Locust", "locust", ("TOM", "FL")),
         ("NCCC Sprint", "nccc", ("TOM", "FL")),
      )
      if phase == "bench-seed":
         inspections = ()
      for name, slug, values in inspections:
         fields = choose_contest(startup, name, journal)
         (output / (slug + "-fields.json")).write_text(json.dumps([
            {"text": control.window_text(), "rect": str(control.rectangle())} for control in fields
         ], indent=3), encoding="utf-8")
         if slug == "locust" and not fields:
            journal.perform("capture unavailable inactive Locust setup", lambda: capture(startup, output / "locust-inactive.png"))
            (output / "locust-blocked.json").write_text(json.dumps({"status": "NOT RUN",
               "reason": "The visible catalog marks Locust inactive and its setup has no exchange fields."}), encoding="utf-8")
            continue
         if len(fields) != len(values):
            raise AssertionError(name + " expected " + str(len(values)) + " input rows")
         for field, value in zip(fields, values):
            set_field(field, value, journal)
         journal.perform("capture " + name + " labels", lambda: capture(startup, output / (slug + ".png")))
      fields = choose_contest(startup, "CW Open", journal)
      if len(fields) != 1:
         raise AssertionError("CW Open needs one name field")
      set_field(fields[0], "TOM", journal)
      journal.perform("create fresh CW Open practice log", lambda: startup.child_window(title_re="&?OK", class_name="Button").click_input())
      main = app.window(title_re=r"TR4W v.*CWOPEN.*")
      main.wait("visible", timeout=30)
      dismiss_grid_prompt(app, journal)
      main.wait("enabled", timeout=10)
      journal.perform("capture empty CW Open totals", lambda: capture(main, output / "cwo-empty.png"))
      journal.perform("select 20 m without a connected radio", lambda: main.type_keys("%b%b%b"))
      log_without_cw(main, "K6RB", "1 ROB", journal)
      log_without_cw(main, "W7SP", "2 WOODY", journal)
      texts = [control.window_text() for control in main.descendants() if control.is_visible()]
      if not all(text in texts for text in ("4 Pts", "QSOs", "Calls")) or "Zones" in texts:
         raise AssertionError("CW Open two-contact score/labels do not match 2 QSOs, 2 Calls, 4 points")
      journal.perform("capture two contacts and score", lambda: capture(main, output / "cwo-two.png"))
      journal.perform("select 40 m without a connected radio", lambda: main.type_keys("%v"))
      log_without_cw(main, "K6RB", "3 ROB", journal)
      if not any(control.is_visible() and control.window_text() == "6 Pts" for control in main.descendants()):
         raise AssertionError("CW Open repeat on another band must score 6 points")
      journal.perform("capture three contacts and score", lambda: capture(main, output / "cwo-three.png"))
      menus = {}
      for name in ("Tools", "Windows"):
         menu = main.menu().get_menu_path(name)[0].sub_menu()
         menus[name] = [{"text": item.text(), "enabled": item.is_enabled()} for item in menu.items()]
      (output / "menus.json").write_text(json.dumps(menus, indent=3), encoding="utf-8")
      describe_windows(app, output)
      close_normally(app, main, journal)
      from fixture_data import log_state
      databases = list((root / "runs" / run_name).glob("CWOPEN*.db"))
      if len(databases) != 1 or log_state(databases[0])["qso_count"] != 3:
         raise AssertionError("Seed log did not preserve three contacts")
      return {"passed": True, "pid": app.process,
         "note": "CW Open score/label assertions and three saved contacts passed; other setup captures are inspection only"}
   except BaseException:
      try:
         if phase.startswith("bench-switch") and not app.is_process_running():
            from session import adopt_restarted_app
            try:
               app, main = adopt_restarted_app(app, root, run_name, database, output / "failure-handoff.json")
            except Exception as handoff_error:
               (output / "handoff-diagnostic.txt").write_text(repr(handoff_error), encoding="utf-8")
         owned = json.loads((root / "runs" / run_name / "owned-process.json").read_text(encoding="utf-8"))
         if owned["pid"] != app.process:
            app = Application(backend="win32").connect(process=owned["pid"])
         if app.is_process_running():
            describe_windows(app, output)
            capture(app.top_window(), output / "failure.png")
      except Exception as diagnostic_error:
         (output / "diagnostic-error.txt").write_text(repr(diagnostic_error), encoding="utf-8")
      log = root / "runs" / run_name / "tr4w.log"
      fatal = log.exists() and "[CRASH] LCL: unhandled" in log.read_text(encoding="utf-8", errors="replace")
      import ctypes
      hung = app.is_process_running() and any(ctypes.windll.user32.IsHungAppWindow(w.handle) for w in app.windows())
      if hung:
         (output / "hung-process.json").write_text(json.dumps({"pid": app.process}), encoding="utf-8")
      if not fatal and not hung and app.is_process_running():
         app.kill()
      # A fatal process stays alive for the runner to dump before stopping workers.
      raise
