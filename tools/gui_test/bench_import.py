"""Assert transactional ADIF failure, later entry and a successful GUI import."""

import json
import time
from pywinauto.timings import wait_until

from adif_fixtures import write_contacts
from fixture_data import contacts, log_state, contact_digest
from qso_entry import log_without_cw
from session import capture, select_menu, choose_file, notice_text, acknowledge_notice, answer_question


def import_file(app, main, path, database, output, journal, bad=False, own_answer=None):
   before = log_state(database)["qso_count"]
   select_menu(main, ("File", "Import", "ADIF"), journal)
   choose_file(app, path, journal)
   notices = []
   deadline = time.monotonic() + 25
   while time.monotonic() < deadline:
      notice = app.window(class_name="#32770", visible_only=True)
      if notice.exists(timeout=0):
         try:
            text = notice_text(app, notice)
         except LookupError:
            continue
         notices.append(text)
         if "Append imported QSOs to current log" in text:
            answer_question(app, "Append imported QSOs to current log", journal, answer="Yes")
            continue
         if "MY_GRIDSQUARE" in text and own_answer is not None:
            answer_question(app, "MY_GRIDSQUARE", journal, output / "station-question.png", answer=own_answer)
            continue
         lower = text.lower()
         if "import" not in lower:
            raise RuntimeError("Unexpected import notice: " + text)
         if bad and not ("call" in lower and "record" in lower and ("nothing" in lower or "unchanged" in lower)):
            raise AssertionError("Failed import notice does not explain the refused record/unchanged log: " + text)
         acknowledge_notice(app, (text,), journal, output / ("bad-notice.png" if bad else "import-notice.png"))
         if bad:
            break
      elif log_state(database)["qso_count"] != before:
         time.sleep(0.3)
         if not app.window(class_name="#32770", visible_only=True).exists(timeout=0):
            break
      time.sleep(0.1)
   else:
      raise AssertionError("Import neither completed nor produced its expected notice")
   wait_until(10, 0.1, main.is_enabled)
   if bad and not notices:
      raise AssertionError("Rejected import gave no visible warning")
   return notices


def check(app, main, root, run_name, output, journal):
   directory = root / "runs" / run_name
   database = list(directory.glob("*.db"))[0]
   before = contact_digest(database)
   if log_state(database)["qso_count"] != 3:
      raise AssertionError("Import case requires the three-contact seed")
   bad = directory / "bad-import.adi"
   write_contacts(bad, bad=True)
   notices = import_file(app, main, bad, database, output, journal, bad=True)
   if contact_digest(database) != before or not any(c.is_visible() and c.window_text() == "6 Pts" for c in main.descendants()):
      raise AssertionError("Failed import changed existing contacts or score")
   capture(main, output / "after-rollback.png")
   log_without_cw(main, "N0GUI", "12 SAM", journal)
   if log_state(database)["qso_count"] != 4:
      raise AssertionError("Manual entry did not work after import rollback")
   good = directory / "good-import.adi"
   write_contacts(good, first_sent=5)
   import_file(app, main, good, database, output, journal)
   rows = contacts(database)
   if len(rows) != 6 or not {"K1GUI", "K2GUI", "N0GUI"}.issubset({row["callsign"] for row in rows}):
      raise AssertionError("Good import/manual contact set is incorrect")
   capture(main, output / "after-good-import.png")
   from bench_exports import check as export_adif
   export_adif(app, main, root, run_name, output, journal, "bench-export-discover", expected_records=6)
   (output / "import-result.json").write_text(json.dumps({"bad_notices": notices, "rollback_digest": before,
      "manual_after_rollback": True, "final_contacts": len(rows), "calls": [row["callsign"] for row in rows]}, indent=3), encoding="utf-8")
   return {"passed": True, "note": "Bad import rolled back with visible warning; later logging, good import and re-export verified"}
