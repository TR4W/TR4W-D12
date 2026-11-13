"""Discover and exercise local exports through the running application's menus."""

import json
import time
import re
from pathlib import Path
from pywinauto.timings import wait_until

from session import capture, describe_windows, answer_question
from evidence import preserve_generated_file
from fixture_data import log_state


def check(app, main, root, run_name, output, journal, phase, expected_records=None):
   year = phase.startswith("bench-export-year")
   zone = phase.startswith("bench-export-zone")
   prefix = "zone" if zone else ("year" if year else "cwopen")
   count = 1 if year or zone else 3
   if expected_records is not None:
      count = expected_records
   expected_year = "05" if "year05" in phase else "64"
   expected_sent = ("42" if "42" in phase else "8") if zone else expected_year
   if year or zone:
      database = list((root / "runs" / run_name).glob("*.db"))
      if len(database) != 1:
         raise RuntimeError("Year-export database is not unique")
      rows = log_state(database[0])["qso_count"]
      if rows == 0:
         from qso_entry import log_without_cw
         log_without_cw(main, "W7SP", "599 8" if zone else "599 85", journal)
         capture(main, output / "year-contact.png")
      elif rows != 1:
         raise AssertionError("Year export fixture must have zero or one contact")
      if "year05" in phase:
         from bench_preferences import search_control, write_value
         before = log_state(database[0])
         main.type_keys("^j")
         prefs = app.window(title="TR4W Preferences")
         prefs.wait("visible enabled", timeout=10)
         control, observation = search_control(prefs, "MY ZONE", output, journal)
         write_value(control, observation, "05", journal)
         capture(prefs, output / "license-year-05-entered.png")
         prefs.child_window(title="Save and close").click_input()
         prefs.wait_not("visible", timeout=10)
         (output / "year-change.json").write_text(json.dumps({"before": before,
            "original_control": observation, "after_save": log_state(database[0])}, indent=3), encoding="utf-8")
      if phase.endswith("-edit-inspect"):
         from qso_entry import open_contact_editor
         editor = open_contact_editor(app, main, journal)
         describe_windows(app, output)
         capture(editor, output / "edit-qso.png")
         cancel = [control for control in editor.descendants(class_name="Button") if control.is_visible()
            and control.window_text().replace("&", "") == "Cancel"]
         if len(cancel) != 1:
            raise RuntimeError("Unknown contact editor; Cancel not unique")
         cancel[0].click_input()
         editor.wait_not("visible", timeout=10)
         return {"passed": True, "note": "Contact editor discovery only; no value changed"}
      if "edit42" in phase:
         from qso_entry import open_contact_editor
         observations = []

         def itu_field(editor):
            fields = [control for control in editor.descendants(class_name="Edit") if control.is_visible()]
            return max(fields, key=lambda control: (control.rectangle().top, control.rectangle().left))

         for action, expected in (("Cancel", "8"), ("Save", "42")):
            editor = open_contact_editor(app, main, journal)
            field = itu_field(editor)
            if field.window_text() != "8":
               raise AssertionError("ITU fixture must start at 8")
            field.set_edit_text("42")
            field.type_keys("{TAB}")
            capture(editor, output / ("itu-42-before-" + action.lower() + ".png"))
            editor.child_window(title_re="&?" + action, class_name="Button").click_input()
            if action == "Cancel":
               answer_question(app, "Save changes?", journal, output / "discard-itu-edit.png")
            else:
               answer_question(app, "Save changes?", journal, output / "confirm-itu-edit.png", answer="Yes")
            editor.wait_not("visible", timeout=10)
            editor = open_contact_editor(app, main, journal)
            actual = itu_field(editor).window_text()
            if actual != expected:
               raise AssertionError(action + " did not preserve expected ITU zone " + expected)
            capture(editor, output / ("itu-after-" + action.lower() + ".png"))
            observations.append({"action": action, "reopened_itu": actual})
            editor.child_window(title="Cancel").click_input()
            editor.wait_not("visible", timeout=10)
         (output / "itu-edit-result.json").write_text(json.dumps(observations, indent=3), encoding="utf-8")
   if phase.endswith("-multipliers"):
      submenu = main.menu().get_menu_path("Windows->Mults")[-1].sub_menu()
      entries = [item.text() for item in submenu.items()]
      (output / "multiplier-menu.json").write_text(json.dumps(entries, indent=3), encoding="utf-8")
      matches = [text for text in entries if "default" in text.replace("&", "").lower()]
      if len(matches) != 1:
         raise RuntimeError("Default multiplier entry not unique: " + repr(entries))
      journal.perform("open Windows > Mults > Default", lambda: main.menu_select("Windows->Mults->" + matches[0]))
      time.sleep(1)
      describe_windows(app, output)
      candidates = [window for window in app.windows() if window.is_visible()
         and window.window_text() == matches[0].split("\t")[0].replace("&", "")]
      if len(candidates) != 1:
         raise AssertionError("Multiplier window not unique: " + repr([w.window_text() for w in candidates]))
      capture(candidates[0], output / "remaining-multipliers.png")
      candidates[0].post_message(0x0010)
      return {"passed": True, "note": "Remaining-multiplier window captured; semantic screenshot review required"}
   export = main.menu().get_menu_path("File")[0].sub_menu().get_menu_path("Export")[0].sub_menu()
   entries = [item.text() for item in export.items()]
   (output / "export-menu.json").write_text(json.dumps(entries, indent=3), encoding="utf-8")
   kind = "cabrillo" if phase.endswith("-cabrillo") else "adif"
   fixture_db = list((root / "runs" / run_name).glob("*.db"))
   if len(fixture_db) != 1:
      raise RuntimeError("Export requires exactly one isolated database")
   generated = fixture_db[0].with_suffix(".log" if kind == "cabrillo" else ".adi")
   previous_mtime_ns = generated.stat().st_mtime_ns if generated.exists() else None
   matches = [text for text in entries if kind in text.lower()]
   if len(matches) != 1:
      raise AssertionError(kind + " export menu not unique: " + repr(entries))
   journal.perform("select local " + kind + " export", lambda: main.menu_select("File->Export->" + matches[0]))
   time.sleep(1)
   describe_windows(app, output)
   top = app.top_window()
   if kind == "cabrillo" and top.window_text() == "Station information":
      capture(top, output / "cabrillo-summary.png")
      journal.perform("confirm local Cabrillo summary", lambda: top.child_window(title="OK").click_input())
      time.sleep(1)
      top = app.top_window()
      describe_windows(app, output)
   capture(top, output / "after-export-command.png")
   (output / "export-files.json").write_text(json.dumps([
      {"name": path.name, "bytes": path.stat().st_size} for path in (root / "runs" / run_name).iterdir()
      if path.is_file()], indent=3), encoding="utf-8")
   if top.handle != main.handle and top.window_text().lower().endswith(".adi"):
      path = Path(top.window_text()).resolve()
      if not path.is_relative_to((root / "runs" / run_name).resolve()) or path != generated.resolve():
         raise RuntimeError("Export viewer points outside the isolated fixture")
      metadata = preserve_generated_file(path, output / (prefix + ".adi"), previous_mtime_ns)
      (output / "export-write.json").write_text(json.dumps(metadata, indent=3), encoding="utf-8")
      data = (output / (prefix + ".adi")).read_bytes()
      text = data.decode("utf-8", errors="replace")
      if len(re.findall(r"<EOR>", text, re.I)) != count:
         raise AssertionError("Unexpected exported contact count")
      if not year and not zone and re.search(r"<CQZ:", text, re.I):
         raise AssertionError("CW Open ADIF must contain three contacts and no CQZ tag")
      if year and not re.search(r"<STX_STRING:6>599 " + expected_year, text, re.I):
         raise AssertionError("Year ADIF does not send expected license year " + expected_year)
      if year:
         # Issues 298/305: MY_CQ_ZONE is the station call's CQ zone, present,
         # and never the licence year this contest sends.
         my_cq = re.search(r"<MY_CQ_ZONE:\d+>(\d+)", text, re.I)
         received = re.search(r"<SRX_STRING:\d+>([^<]*)", text, re.I)
         (output / "year-adif-fields.json").write_text(json.dumps({
            "MY_CQ_ZONE": my_cq.group(1) if my_cq else None,
            "SRX_STRING": received.group(1).strip() if received else None}, indent=3), encoding="utf-8")
         if not my_cq or int(my_cq.group(1)) == int(expected_year):
            raise AssertionError("Year ADIF MY_CQ_ZONE missing or equal to the licence year: "
               + (my_cq.group(0) if my_cq else "absent"))
      if zone and not re.search(r"<STX_STRING:\d+>599 " + expected_sent + r"\b", text, re.I):
         raise AssertionError("Zone-contest ADIF does not send expected ITU zone " + expected_sent)
      if "edit42" in phase and not re.search(r"<MY_ITU_ZONE:2>42", text, re.I):
         raise AssertionError("ADIF did not retain the edited ITU zone 42")
      top.post_message(0x0010)
      top.wait_not("visible", timeout=10)
      return {"passed": True, "records": count, "license_year_checked": year,
         "note": "Actual File > Export > ADIF output verified"}
   if kind == "cabrillo":
      databases = list((root / "runs" / run_name).glob("*.db"))
      if len(databases) != 1:
         raise RuntimeError("Cabrillo fixture database not unique")
      path = databases[0].with_suffix(".log").resolve()
      if not path.is_relative_to((root / "runs" / run_name).resolve()):
         raise RuntimeError("Cabrillo viewer points outside the isolated fixture")
      metadata = preserve_generated_file(path, output / (prefix + ".cbr"), previous_mtime_ns)
      (output / "export-write.json").write_text(json.dumps(metadata, indent=3), encoding="utf-8")
      data = (output / (prefix + ".cbr")).read_bytes()
      text = data.decode("utf-8", errors="replace")
      rows = [line for line in text.splitlines() if line.startswith("QSO:")]
      pattern_ok = all(re.search(r"\b599\s+" + expected_sent + r"\b", line) for line in rows) if year or zone else all(
         re.search(r"\b0*" + str(index) + r"\s+TOM\b", line) for index, line in enumerate(rows, 1))
      if len(rows) != count or not pattern_ok:
         raise AssertionError("Cabrillo contacts/exchanges do not match the fixture: " + repr(rows))
      if top.handle != main.handle:
         if Path(top.window_text()).resolve() != path:
            raise RuntimeError("Unclassified window after declining upload: " + top.window_text())
         top.post_message(0x0010)
         top.wait_not("visible", timeout=10)
      declined = answer_question(app, "upload your Cabrillo file to SuperCheck", journal,
         output / "upload-prompt-declined.png")
      wait_until(10, 0.1, main.is_enabled)
      return {"passed": True, "records": count, "license_year_checked": year,
         "upload_declined": declined,
         "note": "Actual local Cabrillo export verified; no submission performed"}
   if top.handle != main.handle:
      cancel = [control for control in top.descendants(class_name="Button")
         if control.is_visible() and control.window_text().replace("&", "") == "Cancel"]
      if len(cancel) != 1:
         raise RuntimeError("Unclassified export dialog; inspect captured controls")
      cancel[0].click_input()
      top.wait_not("visible", timeout=10)
   return {"passed": True, "note": "Export route inspected only; no content requirement accepted"}
