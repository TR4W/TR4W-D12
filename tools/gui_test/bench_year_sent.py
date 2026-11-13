"""Issue 300 (log schema 8): each QSO stores the licence year it sent.

bench-yearsent-create-<contest>  New Contest with year 64; one CW and one SSB
                                 QSO on 40 m through the normal fields, no CW
                                 (Ctrl+Enter); normal close; the closed log read.
bench-yearsent-check-<c>-<no|yes>  on a CLONE of that log: reopen, Preferences
                                 License year, Edit QSO Year sent, change the
                                 Station year to 05, read both questions without
                                 answering by position, choose "Also this
                                 contest" then No or Yes, log a third QSO,
                                 export ADIF and Cabrillo and check every row.
bench-yearsent-check-cwopen      the control: Edit QSO in a contest that sends
                                 no year (CW Open seed) -- Year sent empty and
                                 disabled.
"""

from contextlib import closing
import json
import re
import sqlite3
import time

from contest_forms import choose_contest, set_field, dismiss_grid_prompt
from session import capture, close_normally, describe_windows, dialog_facts, click_dialog_button
from qso_entry import log_without_cw, open_contact_editor, my_station_fields
from fixture_data import contacts

CONTESTS = {"euhfc": "European HF", "kvp": "KV PRVENSTVO ZRS"}
# Two QSOs before the change, one after: call, received exchange, mode.
BEFORE = (("W7SP", "599 85", "CW"), ("K6RB", "59 72", "SSB"))
AFTER = ("N7XX", "599 91", "CW")
BAND_MODE = re.compile(r"^\s*(160|80|60|40|30|20|17|15|12|10|6|2)\s*(CW|SSB|PH|DIGI|DIG|RY|RTTY|FM|AM|USB|LSB|DATA)\s*$")
PHONE = {"SSB", "PH", "USB", "LSB", "FM", "AM"}


def database_of(root, run_name):
   databases = list((root / "runs" / run_name).glob("*.db"))
   if len(databases) != 1:
      raise AssertionError("Fixture database is not unique: " + repr(databases))
   return databases[0]


def closed_log(database):
   """The closed log as the program left it: schema, the year rows, every QSO."""
   with closing(sqlite3.connect(database.resolve().as_uri() + "?mode=ro", uri=True)) as connection:
      version = connection.execute("PRAGMA user_version").fetchone()[0]
      tables = [row[0] for row in connection.execute("SELECT name FROM sqlite_master WHERE type='table'")]
      meta = {}
      for table in tables:
         if "meta" in table.lower() or "schema" in table.lower():
            meta[table] = [list(row) for row in connection.execute("SELECT * FROM " + table)]
      config = connection.execute("SELECT command,value,source FROM config WHERE command IN "
         "('MY LICENSE YEAR','MY ZONE')").fetchall()
   rows = contacts(database)
   keep = ("_rowid", "call", "callsign", "band", "mode", "year_sent", "exchange", "rst_sent", "rst_received")
   summary = [{key: row[key] for key in row if key in keep or "year" in key.lower() or "zone" in key.lower()}
      for row in rows]
   return {"user_version": version, "meta_tables": meta, "config": [list(row) for row in config],
      "qsos": summary}


def band_mode(main):
   texts = [control.window_text() for control in main.descendants() if control.is_visible()]
   found = [BAND_MODE.match(text) for text in texts]
   found = [match for match in found if match]
   if len(found) != 1:
      raise RuntimeError("Band/mode display not unique: " + repr([t for t in texts if t.strip()][:80]))
   return found[0].group(1), found[0].group(2)


def select_band_mode(main, band, mode, journal):
   for _ in range(12):
      if band_mode(main)[0] == band:
         break
      journal.perform("next band without a radio", lambda: main.type_keys("%b"))
      time.sleep(0.3)
   # Alt-M cycles the modes (CW, DIGI, SSB observed); read the display each time.
   wanted = {"CW"} if mode == "CW" else PHONE
   for _ in range(5):
      if band_mode(main)[1] in wanted:
         break
      journal.perform("next mode without a radio", lambda: main.type_keys("%m"))
      time.sleep(0.3)
   observed = band_mode(main)
   if observed[0] != band or observed[1] not in wanted:
      raise RuntimeError("Could not select " + band + " " + mode + "; display reads " + repr(observed))
   return observed


def create(app, startup, root, run_name, output, journal, slug):
   if list((root / "runs" / run_name).glob("*.db")):
      raise RuntimeError("Year creation requires a fresh fixture")
   fields = choose_contest(startup, CONTESTS[slug], journal)
   if len(fields) != 1:
      raise AssertionError("Expected one licence-year field, found " + str(len(fields)))
   set_field(fields[0], "64", journal)
   capture(startup, output / "year-setup.png")
   startup.child_window(title_re="&?OK", class_name="Button").click_input()
   main = app.window(title_re=r"TR4W v.*")
   main.wait("visible enabled", timeout=30)
   dismiss_grid_prompt(app, journal)
   logged = []
   for call, exchange, mode in BEFORE:
      observed = select_band_mode(main, "40", mode, journal)
      log_without_cw(main, call, exchange, journal)
      logged.append({"call": call, "exchange": exchange, "band_mode_shown": observed})
      capture(main, output / ("logged-" + call.lower() + ".png"))
   close_normally(app, main, journal)
   state = closed_log(database_of(root, run_name))
   (output / "created-log.json").write_text(json.dumps({"logged": logged, "log": state}, indent=3,
      default=str), encoding="utf-8")
   failures = []
   if len(state["qsos"]) != 2:
      failures.append("Expected two QSOs, found " + str(len(state["qsos"])))
   if any(str(row.get("year_sent")) != "64" for row in state["qsos"]):
      failures.append("year_sent is not 64 on every QSO: " + repr(state["qsos"]))
   return {"passed": not failures, "failures": failures, "log": state,
      "note": "Two QSOs logged with Ctrl+Enter; year_sent read from the closed log"}


def editor_facts(app, main, output, journal, name):
   editor = open_contact_editor(app, main, journal)
   fields = my_station_fields(editor)
   facts = {key: {"text": control.window_text(), "enabled": control.is_enabled(),
      "rect": str(control.rectangle())} for key, control in fields.items()}
   describe_windows(app, output)
   capture(editor, output / (name + ".png"))
   cancel = [control for control in editor.descendants(class_name="Button") if control.is_visible()
      and control.window_text().replace("&", "") == "Cancel"]
   if len(cancel) != 1:
      raise RuntimeError("Edit QSO Cancel not unique")
   journal.perform("close Edit QSO unchanged", cancel[0].click_input)
   editor.wait_not("visible", timeout=10)
   return facts


def adif_rows(text):
   rows = []
   for record in re.split(r"<EOR>", text, flags=re.I)[:-1]:
      fields = {match.group(1).upper(): match.group(3) for match in
         re.finditer(r"<([A-Z_0-9]+):(\d+)(?::[A-Z])?>([^<]*)", record, re.I)}
      rows.append({key: fields.get(key, "").strip() for key in
         ("CALL", "MODE", "BAND", "STX_STRING", "SRX_STRING", "MY_CQ_ZONE", "MY_ITU_ZONE")})
   return rows


def zone_after_save(app, main, root, run_name, output, journal, database, slug):
   """Isolate what changes the captured our-station CQ zone: QSO A after the
   reopen with no Preferences visit, then a Preferences save that changes only
   MY NAME, then QSO B. The licence year is not touched."""
   from bench_preferences import search_control, write_value
   facts = {"log_at_start": closed_log(database)}
   select_band_mode(main, "40", "CW", journal)
   exchanges = ("5 ANN", "6 BOB") if slug == "cwopen" else ("599 77", "599 78")
   log_without_cw(main, "N7AA", exchanges[0], journal)
   facts["after_qso_a"] = closed_log(database)
   journal.perform("open Preferences", lambda: main.type_keys("^j"))
   prefs = app.window(title="TR4W Preferences")
   prefs.wait("visible enabled", timeout=10)
   _, zone = search_control(prefs, "MY ZONE", output, journal)
   _, itu = search_control(prefs, "MY ITU ZONE", output, journal)
   facts["station_page_cq_zone"], facts["station_page_itu_zone"] = zone["value"], itu["value"]
   control, observation = search_control(prefs, "MY NAME", output, journal)
   facts["my_name_before"] = observation["value"]
   write_value(control, observation, "TOM", journal)
   capture(prefs, output / "only-my-name-changed.png")
   journal.perform("save and close", lambda: prefs.child_window(title="Save and close").click_input())
   prefs.wait_not("visible", timeout=10)
   time.sleep(0.5)
   facts["windows_after_save"] = [w.window_text() for w in app.windows() if w.is_visible()]
   log_without_cw(main, "N7BB", exchanges[1], journal)
   facts["after_qso_b"] = closed_log(database)
   rows = {row["callsign"]: row.get("my_cq_zone") for row in facts["after_qso_b"]["qsos"]}
   facts["my_cq_zone_by_call"] = rows
   (output / "zone-after-save.json").write_text(json.dumps(facts, indent=3, default=str), encoding="utf-8")
   failures = [call + " captured my_cq_zone " + str(zone) for call, zone in rows.items() if str(zone) != "5"]
   return {"passed": not failures, "failures": failures, "my_cq_zone_by_call": rows,
      "note": "W1AW's CTY CQ zone is 5; every QSO should capture 5"}


def check(app, main, root, run_name, output, journal, phase):
   from bench_preferences import search_control, write_value
   from bench_exports import run_export
   if phase == "bench-yearsent-check-cwopen":
      facts = editor_facts(app, main, output, journal, "cwopen-edit-qso")
      year = facts["year_sent"]
      (output / "cwopen-year-sent.json").write_text(json.dumps(facts, indent=3), encoding="utf-8")
      failures = [] if (year["text"] == "" and not year["enabled"]) else [
         "CW Open Year sent is not empty and disabled: " + repr(year)]
      return {"passed": not failures, "failures": failures, "year_sent": year}
   _, slug, answer = phase.rsplit("-", 2)
   answer_yes = answer == "yes"
   database = database_of(root, run_name)
   if answer == "zone":
      return zone_after_save(app, main, root, run_name, output, journal, database, slug)
   failures = []
   facts = {"contest": CONTESTS[slug], "answer": "Yes" if answer_yes else "No",
      "log_at_start": closed_log(database)}

   journal.perform("open Preferences", lambda: main.type_keys("^j"))
   prefs = app.window(title="TR4W Preferences")
   prefs.wait("visible enabled", timeout=10)
   _, shown = search_control(prefs, "MY LICENSE YEAR", output, journal)
   facts["preferences_license_year_on_reopen"] = shown["value"]
   _, zone = search_control(prefs, "MY ZONE", output, journal)
   facts["preferences_cq_zone_on_reopen"] = zone["value"]
   capture(prefs, output / "preferences-reopened.png")
   journal.perform("cancel Preferences", lambda: prefs.child_window(title="Cancel").click_input())
   prefs.wait_not("visible", timeout=10)

   facts["edit_qso_before"] = editor_facts(app, main, output, journal, "edit-qso-before")
   year = facts["edit_qso_before"]["year_sent"]
   if year["text"] != "64" or not year["enabled"]:
      failures.append("Edit QSO Year sent is not an enabled 64: " + repr(year))
   if facts["edit_qso_before"]["cq_zone"]["text"] != "5":
      failures.append("Edit QSO our-station CQ zone is not W1AW's CTY zone 5: "
         + repr(facts["edit_qso_before"]["cq_zone"]))

   journal.perform("reopen Preferences", lambda: main.type_keys("^j"))
   prefs = app.window(title="TR4W Preferences")
   prefs.wait("visible enabled", timeout=10)
   control, observation = search_control(prefs, "MY LICENSE YEAR", output, journal)
   write_value(control, observation, "05", journal)
   capture(prefs, output / "license-year-05-typed.png")
   journal.perform("save and close", lambda: prefs.child_window(title="Save and close").click_input())

   dialog, first = dialog_facts(app, "License year")
   capture(dialog, output / "question-1-license-year.png")
   facts["question_1"] = first
   if sorted(name.replace("&", "") for name in first["answers"]) != sorted(["Also this contest", "Station default only"]):
      failures.append("Question 1 buttons are not exactly the two answers: " + repr(first["answers"]))
   if (first.get("default") or "").replace("&", "") != "Station default only":
      failures.append("Question 1 default is not Station default only: " + repr(first.get("default")))
   click_dialog_button(app, dialog, "Also this contest", journal)

   dialog, second = dialog_facts(app, "Correct logged QSOs?")
   capture(dialog, output / "question-2-correct-logged.png")
   facts["question_2"] = second
   if (second.get("default") or "").replace("&", "") != "No":
      failures.append("Question 2 default is not No: " + repr(second.get("default")))
   body = " ".join(second["uia_texts"] + [item["text"] for item in second["win32_texts"]])
   if "2 QSO(s)" not in body or "64" not in body or "05" not in body:
      failures.append("Question 2 body does not name 2 QSOs, 64 and 05: " + repr(body))
   click_dialog_button(app, dialog, "Yes" if answer_yes else "No", journal)
   prefs.wait_not("visible", timeout=10)
   time.sleep(0.5)
   describe_windows(app, output)

   observed = select_band_mode(main, "40", AFTER[2], journal)
   log_without_cw(main, AFTER[0], AFTER[1], journal)
   capture(main, output / "third-qso.png")
   facts["third_qso_band_mode"] = observed

   adif, _ = run_export(app, main, root, run_name, output, journal, "adif", "yearsent")
   if adif is None:
      raise RuntimeError("ADIF export opened no viewer")
   rows = adif_rows(adif)
   facts["adif_rows"] = rows
   old = "05" if answer_yes else "64"
   expected = {"W7SP": "599 " + old, "K6RB": "59 " + old, "N7XX": "599 05"}
   actual = {row["CALL"]: row["STX_STRING"] for row in rows}
   if actual != expected:
      failures.append("ADIF STX_STRING per call " + repr(actual) + ", expected " + repr(expected))
   # The fixture station is W1AW: CTY.DAT puts it in CQ zone 5 (issue 305).
   if any(row["MY_CQ_ZONE"] != "5" for row in rows):
      failures.append("ADIF MY_CQ_ZONE is not W1AW's zone 5: " + repr([row["MY_CQ_ZONE"] for row in rows]))
   try:
      facts["log_after_export"] = closed_log(database)
   except Exception as error:
      facts["log_after_export_error"] = repr(error)
   cabrillo, declined = run_export(app, main, root, run_name, output, journal, "cabrillo", "yearsent")
   lines = [line for line in cabrillo.splitlines() if line.startswith("QSO:")]
   facts["cabrillo_qso_lines"] = lines
   facts["upload_declined"] = declined
   for call, sent in expected.items():
      matching = [line for line in lines if re.search(r"\b" + call + r"\b", line)]
      if len(matching) != 1 or not re.search(r"\b" + sent.replace(" ", r"\s+") + r"\b", matching[0]):
         failures.append("Cabrillo line for " + call + " does not send " + sent + ": " + repr(matching))
   facts["failures"] = failures
   (output / "year-sent-result.json").write_text(json.dumps(facts, indent=3, default=str), encoding="utf-8")
   return {"passed": not failures, "failures": failures,
      "note": "Questions read without answering by position; per-QSO export rows asserted"}
