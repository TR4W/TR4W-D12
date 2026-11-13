"""Earlier pending verifications, each on a CLONE of the CW Open seed log.

bench-pending-empty-exchange  issue 292: CQ mode, a call, plain Enter, then
                              Enter on the empty exchange: the notice line and
                              no QSO. Plain Enter is safe ONLY because the
                              fixture has no radio and no keyer; the phase
                              refuses to run otherwise.
bench-pending-accented-name   MY NAME "José" through Preferences, Save,
                              normal exit, restart: what Preferences shows.
bench-pending-message-long    the message editor refuses a 300-byte message:
                              warning box, editor stays open, nothing saved,
                              the [EditMessage] log line.
"""

import json
import time

from session import capture, close_normally, describe_windows, dialog_facts, click_dialog_button, launch
from qso_entry import entry_fields
from fixture_data import contacts


def visible_texts(window):
   return [control.window_text() for control in window.descendants()
      if control.is_visible() and control.window_text().strip()]


def database_of(root, run_name):
   databases = list((root / "runs" / run_name).glob("CWOPEN*.db"))
   if len(databases) != 1:
      raise RuntimeError("Expected one CW Open log")
   return databases[0]


def empty_exchange(app, main, root, run_name, output, journal):
   settings = json.loads((root / "runs" / run_name / "tr4w.json").read_text(encoding="utf-8-sig"))
   if settings.get("radios") or settings.get("keyers"):
      raise RuntimeError("Plain Enter needs a fixture with no radio and no keyer")
   database = database_of(root, run_name)
   before = len(contacts(database))
   call_field, exchange_field = entry_fields(main)
   facts = {"qsos_before": before, "texts_start": visible_texts(main)}
   journal.perform("focus callsign", call_field.set_focus)
   journal.perform("type W9XYZ", lambda: call_field.type_keys("W9XYZ"))
   journal.perform("first Enter (CQ mode: call and exchange)", lambda: call_field.type_keys("{ENTER}"))
   time.sleep(1.5)
   facts["after_first_enter"] = {"call": call_field.window_text(), "exchange": repr(exchange_field.window_text()),
      "texts": visible_texts(main), "windows": [w.window_text() for w in app.windows() if w.is_visible()]}
   capture(main, output / "after-first-enter.png")
   journal.perform("clear the exchange box", lambda: exchange_field.set_edit_text(""))
   journal.perform("focus exchange", exchange_field.set_focus)
   journal.perform("second Enter on the empty exchange", lambda: exchange_field.type_keys("{ENTER}"))
   time.sleep(1.5)
   texts = visible_texts(main)
   facts["after_second_enter"] = {"call": call_field.window_text(), "exchange": repr(exchange_field.window_text()),
      "texts": texts, "windows": [w.window_text() for w in app.windows() if w.is_visible()]}
   capture(main, output / "after-second-enter.png")
   facts["qsos_after"] = len(contacts(database))
   failures = []
   if not any("Not enough info in exchange" in text for text in texts):
      failures.append("No 'Not enough info in exchange!!' notice on screen")
   if facts["qsos_after"] != before:
      failures.append("A QSO was logged on the empty exchange")
   journal.perform("clear the entry with Escape", lambda: exchange_field.type_keys("{ESC}{ESC}{ESC}"))
   (output / "empty-exchange.json").write_text(json.dumps(facts, indent=3), encoding="utf-8")
   return {"passed": not failures, "failures": failures, "note": "Two plain Enters, no keyer configured"}


def accented_name(app, main, root, run_name, output, journal):
   from bench_preferences import search_control, write_value
   name = "José"
   journal.perform("open Preferences", lambda: main.type_keys("^j"))
   prefs = app.window(title="TR4W Preferences")
   prefs.wait("visible enabled", timeout=10)
   control, observation = search_control(prefs, "MY NAME", output, journal)
   facts = {"before": observation["value"]}
   write_value(control, observation, name, journal)
   capture(prefs, output / "my-name-typed.png")
   journal.perform("save and close", lambda: prefs.child_window(title="Save and close").click_input())
   prefs.wait_not("visible", timeout=10)
   time.sleep(0.5)
   facts["windows_after_save"] = [w.window_text() for w in app.windows() if w.is_visible()]
   close_normally(app, main, journal)
   facts["json_mentions_name"] = name in (root / "runs" / run_name / "tr4w.json").read_text(encoding="utf-8-sig")
   from contextlib import closing
   import sqlite3
   with closing(sqlite3.connect(database_of(root, run_name).resolve().as_uri() + "?mode=ro", uri=True)) as connection:
      facts["db_my_name_rows"] = connection.execute(
         "SELECT command,value,source FROM config WHERE command='MY NAME'").fetchall()
   app = launch(root, run_name, database_of(root, run_name).name)
   main = app.window(title_re=r"TR4W v.*CWOPEN.*")
   main.wait("visible enabled", timeout=30)
   journal.perform("reopen Preferences after restart", lambda: main.type_keys("^j"))
   prefs = app.window(title="TR4W Preferences")
   prefs.wait("visible enabled", timeout=10)
   control, observation = search_control(prefs, "MY NAME", output, journal)
   facts["after_restart"] = observation["value"]
   capture(prefs, output / "my-name-after-restart.png")
   journal.perform("cancel Preferences", lambda: prefs.child_window(title="Cancel").click_input())
   prefs.wait_not("visible", timeout=10)
   failures = [] if facts["after_restart"] == name else [
      "MY NAME after restart is " + repr(facts["after_restart"]) + ", expected " + repr(name)]
   (output / "accented-name.json").write_text(json.dumps(facts, indent=3, ensure_ascii=False), encoding="utf-8")
   return {"passed": not failures, "failures": failures}, app, main


def message_long(app, main, root, run_name, output, journal):
   command = "CQ CW MEMORY F3"
   journal.perform("open message bank chooser", lambda: main.menu_select("Settings->Program messages"))
   chooser = app.window(title="Memory program function")
   chooser.wait("visible", timeout=10)
   journal.perform("choose CQ bank", lambda: chooser.type_keys("c"))
   messages = app.window(title="List of messages")
   messages.wait("visible", timeout=10)
   messages.child_window(title="Standard", class_name="Button").click_input()
   listing = messages.child_window(class_name="SysListView32")
   names = [listing.get_item(i, 0).text() for i in range(listing.item_count())]
   index = names.index(command)
   before = listing.get_item(index, 1).text()
   listing.select(index)
   listing.set_focus()
   journal.perform("edit " + command, lambda: listing.type_keys("{ENTER}"))
   editor = app.window(title="Program message")
   editor.wait("visible", timeout=10)
   fields = sorted(editor.descendants(class_name="Edit"), key=lambda c: c.rectangle().top)
   # The box takes at most 255 characters, so the operator's way past 255
   # STORED bytes is control characters: Ctrl+P arms an escape and the next
   # Ctrl+letter inserts its code, stored as <XX> (four bytes). 250 letters and
   # two Ctrl+P Ctrl+A escapes are 252 characters and 258 stored bytes.
   journal.perform("type 250 letters", lambda: fields[0].set_edit_text("A" * 250))
   journal.perform("caret to the end", lambda: fields[0].type_keys("^{END}"))
   journal.perform("two Ctrl+P Ctrl+A escapes", lambda: fields[0].type_keys("^p^a^p^a"))
   text = fields[0].window_text()
   facts = {"command": command, "before": before, "typed_length": len(text),
      "control_characters": [hex(ord(ch)) for ch in text if ord(ch) < 32]}
   known = {w.handle for w in app.windows() if w.is_visible()}
   journal.perform("OK with the long message", lambda: editor.child_window(title="OK").click_input())
   time.sleep(1.5)
   new = [w for w in app.windows() if w.is_visible() and w.handle not in known]
   facts["new_windows"] = [{"title": w.window_text(), "class": w.class_name()} for w in new]
   failures = []
   if len(new) != 1:
      failures.append("Expected one warning window, saw " + repr(facts["new_windows"]))
      describe_windows(app, output)
   else:
      dialog, warning = dialog_facts(app, new[0].window_text())
      capture(dialog, output / "long-message-warning.png")
      facts["warning"] = warning
      body = " ".join(warning["uia_texts"] + [item["text"] for item in warning["win32_texts"]])
      if "255" not in body or "258" not in body:
         failures.append("Warning does not name 258 and 255 bytes: " + repr(body))
      click_dialog_button(app, dialog, warning["answers"][0].replace("&", ""), journal)
      time.sleep(0.5)
   facts["editor_still_open"] = editor.exists(timeout=1) and editor.is_visible()
   if not facts["editor_still_open"]:
      failures.append("The message editor closed after the refusal")
   else:
      from preferences_audit import focus_info
      focused = focus_info(editor)
      facts["focus_after_warning"] = {"class": focused.get("class"),
         "is_message_field": focused.get("handle") == fields[0].handle}
      capture(editor, output / "editor-after-warning.png")
      journal.perform("cancel the editor", lambda: editor.child_window(title="Cancel").click_input())
      editor.wait_not("visible", timeout=5)
   facts["after"] = listing.get_item(index, 1).text()
   if facts["after"] != before:
      failures.append("The long message was saved: " + repr(facts["after"][:40]))
   journal.perform("close message list", lambda: messages.type_keys("{ESC}"))
   log = (root / "runs" / run_name / "tr4w.log").read_text(encoding="utf-8", errors="replace")
   facts["log_lines"] = [line for line in log.splitlines() if "[EditMessage]" in line][-5:]
   if not any("not saved" in line for line in facts["log_lines"]):
      failures.append("No [EditMessage] ... not saved line in tr4w.log")
   (output / "message-long.json").write_text(json.dumps(facts, indent=3), encoding="utf-8")
   return {"passed": not failures, "failures": failures}


def check(app, main, root, run_name, output, journal, phase):
   if phase == "bench-pending-empty-exchange":
      return empty_exchange(app, main, root, run_name, output, journal)
   if phase == "bench-pending-accented-name":
      return accented_name(app, main, root, run_name, output, journal)
   if phase == "bench-pending-message-long":
      return message_long(app, main, root, run_name, output, journal)
   raise ValueError(phase)
