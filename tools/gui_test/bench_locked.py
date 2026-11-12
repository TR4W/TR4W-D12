"""Exercise a real outside SQLite writer and the startup recovery choices."""

import json
import sqlite3
import time

from fixture_data import contact_digest, log_state
from qso_entry import log_without_cw
from session import launch, capture, close_normally, describe_windows, notice_text, acknowledge_notice


def run(root, run_name, output, journal):
   directory = root / "runs" / run_name
   database = list(directory.glob("CWOPEN*.db"))[0]
   observations = []
   app = None
   lock = sqlite3.connect(database, timeout=1)

   def start_locked():
      nonlocal app
      lock.execute("BEGIN IMMEDIATE")
      started = time.monotonic()
      owned = launch(root, run_name, database.name)
      app = owned
      dialog = owned.window(title="Contest log is locked")
      dialog.wait("visible enabled", timeout=30)
      buttons = {c.window_text().replace("&", ""): c for c in dialog.descendants(class_name="Button") if c.is_visible()}
      required = {"Retry", "Open read-only (no logging)", "Quit TR4W"}
      if set(buttons) != required:
         raise AssertionError("Unexpected lock choices: " + repr(list(buttons)))
      from pywinauto import Application
      uiapp = Application(backend="uia").connect(process=owned.process)
      text = " ".join(c.window_text() for c in uiapp.window(handle=dialog.handle).descendants())
      if database.name not in text or "delete" in text.casefold():
         raise AssertionError("Lock dialog omits filename or offers deletion: " + text)
      observations.append({"body": text, "seconds": time.monotonic() - started, "buttons": list(buttons)})
      return owned, dialog, buttons

   try:
      app, dialog, buttons = start_locked()
      capture(dialog, output / "locked-startup.png")
      buttons["Retry"].click_input()
      time.sleep(3)
      dialog.wait("visible enabled", timeout=15)
      capture(dialog, output / "retry-still-locked.png")
      lock.rollback()
      dialog.child_window(title="Retry").click_input()
      main = app.window(title_re=r"TR4W v.*CWOPEN.*")
      main.wait("visible enabled", timeout=30)
      log_without_cw(main, "N0GUI", "12 SAM", journal)
      if log_state(database)["qso_count"] != 4:
         raise AssertionError("Retry after unlock did not permit logging")
      capture(main, output / "unlocked-entry.png")
      close_normally(app, main, journal)
      before = contact_digest(database)
      app, dialog, buttons = start_locked()
      buttons["Open read-only (no logging)"].click_input()
      main = app.window(title_re=r"TR4W v.*CWOPEN.*")
      main.wait("visible enabled", timeout=30)
      from bench_exports import check as export_adif
      export_adif(app, main, root, run_name, output, journal, "bench-export-discover", expected_records=4)
      log_without_cw(main, "N1GUI", "13 BOB", journal)
      warning = app.window(class_name="#32770")
      warning.wait("visible", timeout=10)
      text = notice_text(app, warning)
      if "read-only" not in text.casefold():
         raise AssertionError("Read-only entry warning missing: " + text)
      acknowledge_notice(app, (text,), journal, output / "read-only-refusal.png")
      if contact_digest(database) != before:
         raise AssertionError("Read-only logging changed the contacts")
      log_without_cw(main, "N2GUI", "14 AMY", journal)
      time.sleep(0.5)
      if app.window(class_name="#32770", visible_only=True).exists(timeout=0):
         raise AssertionError("Read-only warning repeated for another QSO")
      log = (directory / "tr4w.log").read_text(encoding="utf-8", errors="replace")
      if "[QuickDisplay] (NOT LOGGED" not in log:
         raise AssertionError("Read-only refusal did not reach the quick display")
      capture(main, output / "read-only-no-entry.png")
      close_normally(app, main, journal)
      if contact_digest(database) != before:
         raise AssertionError("Read-only close changed contacts")
      lock.rollback()
      for choice in ("Quit TR4W", "Escape", "Close"):
         app, dialog, buttons = start_locked()
         import win32api
         import win32con
         handle = win32api.OpenProcess(win32con.PROCESS_QUERY_INFORMATION | win32con.SYNCHRONIZE, False, app.process)
         capture(dialog, output / ("quit-" + choice.split()[0].lower() + ".png"))
         if choice == "Escape":
            dialog.type_keys("{ESC}")
         elif choice == "Close":
            dialog.post_message(0x0010)
         else:
            buttons[choice].click_input()
         app.wait_for_process_exit(timeout=20)
         import win32process
         code = win32process.GetExitCodeProcess(handle)
         handle.Close()
         if code != 1:
            raise AssertionError("Locked-log Quit exit code: " + str(code))
         log = (directory / "tr4w.log").read_text(encoding="utf-8", errors="replace")
         if "operator chose Quit" not in log:
            raise AssertionError("Quit was not recorded in runtime log")
         lock.rollback()
      (output / "locked-result.json").write_text(json.dumps(observations, indent=3), encoding="utf-8")
      return {"passed": True, "note": "Real writer: retry/release/log, read-only export/refusal, Quit/Escape/Close"}
   except BaseException:
      if app is not None and app.is_process_running():
         describe_windows(app, output)
         capture(app.top_window(), output / "failure.png")
         log = (directory / "tr4w.log").read_text(encoding="utf-8", errors="replace")
         if "[CRASH] LCL: unhandled" not in log:
            app.kill()
      raise
   finally:
      lock.rollback()
      lock.close()
