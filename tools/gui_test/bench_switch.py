"""Check in-session Open Log cancellation without switching or hardware."""

import json
from session import capture


def check(app, main, output, journal, phase, root=None, run_name=None):
   if phase == "bench-switch-regression":
      return regression(app, main, root, run_name, output, journal)
   file_menu = main.menu().get_menu_path("File")[0].sub_menu()
   entries = [item.text() for item in file_menu.items()]
   matches = [text for text in entries if text.replace("&", "").lower() == "open log..."]
   if len(matches) != 1:
      raise AssertionError("Open Log menu entry not unique: " + repr(entries))
   results = []
   for method in ("Cancel", "Close"):
      journal.perform("open File > Open Log", lambda: main.menu_select("File->" + matches[0]))
      dialog = app.window(title_re=r".*Switch to another contest.*")
      dialog.wait("visible enabled", timeout=15)
      if any(control.is_visible() and "Last Contest" in control.window_text()
         for control in dialog.descendants(class_name="Button")):
         raise AssertionError("Last Contest button visible mid-session")
      capture(dialog, output / (method.lower() + "-dialog.png"))
      title = dialog.window_text()
      if method == "Cancel":
         dialog.child_window(title="Cancel").click_input()
      else:
         rectangle = dialog.rectangle()
         dialog.click_input(coords=(rectangle.width() - 20, 14))
      dialog.wait_not("visible", timeout=10)
      if not app.is_process_running() or not main.is_visible():
         raise AssertionError("Cancellation lost the original application")
      results.append({"method": method, "dialog_title": title,
         "same_pid": app.process, "last_contest_hidden": True})
   if phase.endswith("-taken"):
      from bench_log_names import cw_open, ask, form_values
      main.menu_select("File->" + matches[0])
      dialog = app.window(title_re=r".*Switch to another contest.*")
      dialog.wait("visible enabled", timeout=15)
      cw_open(dialog, journal)
      before = form_values(dialog)
      question, buttons = ask(app, dialog, journal, ("Create new log", "Cancel"))
      capture(question, output / "already-open-question.png")
      buttons["Cancel"].click_input()
      question.wait_not("visible", timeout=5)
      if form_values(dialog) != before:
         raise AssertionError("Taken-name cancellation changed form inputs")
      dialog.child_window(title="Cancel").click_input()
      dialog.wait_not("visible", timeout=10)
      results.append({"same_log_choices": list(buttons), "cancel_preserves_form": True})
   capture(main, output / "session-after-cancels.png")
   (output / "switch-cancel-result.json").write_text(json.dumps(results, indent=3), encoding="utf-8")
   return {"passed": True, "note": "Open Log title, hidden Last Contest and both cancellation routes passed"}


def regression(app, main, root, run_name, output, journal):
   from datetime import datetime, timezone
   from bench_log_names import cw_open, ask
   from fixture_data import contact_digest, log_state
   import time
   from session import choose_file, adopt_restarted_app, launch
   from pywinauto.timings import wait_until
   directory = root / "runs" / run_name
   original = list(directory.glob("*.db"))[0]
   # A new log is named by the UTC date (issue 284), so the default New Contest
   # name only collides with the seed while the UTC date is unchanged.
   if datetime.now(timezone.utc).strftime("%Y-%m-%d") not in original.name:
      raise RuntimeError("Switch fixture UTC date changed; prepare a fresh suite after 00:00 UTC")
   before = contact_digest(original)
   original_pid = app.process
   failures = []
   main.menu_select("File->Open Log...")
   dialog = app.window(title_re=r".*Switch to another contest.*")
   dialog.wait("visible enabled", timeout=10)
   invalid = directory / "not-a-log.db"
   invalid.write_text("This is not a SQLite contest log.", encoding="ascii")
   dialog.child_window(title="Browse...").click_input()
   choose_file(app, invalid, journal)
   time.sleep(0.5)
   # Three outcomes: the process restarts (issue 306's defect), the dialog
   # stays open, or the dialog closes and the refusal goes to the main
   # window's status line (the 306 fix: "Not a TR4W contest log ...").
   wait_until(30, 0.1, lambda: not app.is_process_running() or not dialog.exists(timeout=0)
      or dialog.is_enabled())
   if not app.is_process_running():
      app, unused = adopt_restarted_app(app, root, run_name, invalid, output / "unexpected-invalid-handoff.json", wait_main=False)
      time.sleep(0.5)
      if "[CRASH] LCL: unhandled" in (directory / "tr4w.log").read_text(encoding="utf-8", errors="replace"):
         raise RuntimeError("Invalid-file successor crashed; leave it alive for dump collection")
      try:
         capture(app.top_window(), output / "unexpected-invalid-restart.png")
      finally:
         app.kill()
      failures.append("Invalid database caused an unexpected process restart")
      app = launch(root, run_name, original.name)
      main = app.window(title_re=r"TR4W v.*CWOPEN.*")
      main.wait("visible enabled", timeout=30)
   else:
      if app.process != original_pid or contact_digest(original) != before:
         raise AssertionError("Invalid-file browse changed the current contest")
      if dialog.exists(timeout=0):
         capture(dialog, output / "invalid-file-refused.png")
         dialog.child_window(title="Cancel").click_input()
         dialog.wait_not("visible", timeout=10)
      else:
         # The status line is transient, so either the visible refusal or the
         # program's own refusal line in tr4w.log satisfies this; both are
         # recorded so the evidence says which one matched.
         refusal_visible = any(c.is_visible() and "Not a TR4W contest log" in c.window_text()
            for c in main.descendants())
         capture(main, output / "invalid-file-refused.png")
         log_text = (directory / "tr4w.log").read_text(encoding="utf-8", errors="replace")
         refusal_logged = "not-a-log.db is not a contest TR4W can open" in log_text
         if not (refusal_visible or refusal_logged):
            raise AssertionError("Dialog closed without any refusal for the invalid file")
         (output / "invalid-file-refusal.json").write_text(json.dumps({"dialog_closed": True,
            "status_line_seen": refusal_visible, "refusal_logged": refusal_logged,
            "same_pid": True, "contacts_unchanged": True}, indent=3), encoding="utf-8")
   main.menu_select("File->Open Log...")
   dialog = app.window(title_re=r".*Switch to another contest.*")
   dialog.wait("visible enabled", timeout=10)
   cw_open(dialog, journal)
   question, buttons = ask(app, dialog, journal, ("Create new log", "Cancel"))
   capture(question, output / "create-new-question.png")
   buttons["Create new log"].click_input()
   new_database = original.with_name(original.stem + " 2.db")
   app, main = adopt_restarted_app(app, root, run_name, new_database, output / "handoff-new.json")
   if not new_database.is_file() or log_state(new_database)["qso_count"] != 0:
      raise AssertionError("Switch did not create an empty numbered log")
   if not any(c.is_visible() and c.window_text() == "0 Pts" for c in main.descendants()):
      raise AssertionError("New log main window does not show zero points")
   capture(main, output / "new-log.png")
   if contact_digest(original) != before:
      raise AssertionError("Creating a new log changed the original contacts")
   main.menu_select("File->Open Log...")
   dialog = app.window(title_re=r".*Switch to another contest.*")
   dialog.wait("visible enabled", timeout=10)
   dialog.child_window(title="Browse...").click_input()
   choose_file(app, original, journal)
   app, main = adopt_restarted_app(app, root, run_name, original, output / "handoff-back.json")
   if contact_digest(original) != before or log_state(original)["qso_count"] != 3:
      raise AssertionError("Returning to the original log changed its records")
   if not any(c.is_visible() and c.window_text() == "6 Pts" for c in main.descendants()):
      raise AssertionError("Original score was not restored")
   capture(main, output / "original-restored.png")
   (output / "switch-result.json").write_text(json.dumps({"original": str(original), "new": str(new_database),
      "original_digest": before, "invalid_refused_without_restart": not failures, "round_trip": True,
      "failures": failures}, indent=3), encoding="utf-8")
   return {"passed": not failures, "failures": failures, "note": "Invalid browse, new-log process handoff and return to unchanged original asserted"}, app, main
