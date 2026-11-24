"""Issue 361: the ALL JA's own station fields, MY PREFECTURE and MY POWER CLASS.

bench-allja  on a fixture with NO contest log, so New Contest opens:
   (a) choose "All JA Contest"; the dialog asks exactly two things, read by
       Windows OCR as the prefecture and the power class prompts (the captions
       are windowless TLabels). Each bad value is tried with the OTHER field
       already good, so the refusal can only be its own (an empty row disables
       OK too): 10 + X and 49 + M leave OK disabled and the comment line names
       the field; 10 + M enables OK.
   (b) create the log, log one CW QSO without CW (Ctrl+Enter), open Edit QSO:
       the our-station group's Prefecture and Power class boxes read an
       enabled 10 and M; the closed log's row holds my_prefecture 10 and
       my_power_class M.
   (c) File > Export > Cabrillo: CONTEST: ALL-JA, and the QSO line carries the
       sent prefecture right-aligned in three, one space, the power letter
       left-aligned in two, a separating space, then the received call -- and
       no RST anywhere in the line (uContestAllJA.GetCabrilloSentExchange).

Failures are collected per item and returned, so an application defect reads
FAIL; an exception means the driver could not observe (ERROR).
"""

import json
import re
import time

from pywinauto.controls.win32_controls import ListBoxWrapper

from contest_forms import choose_contest, set_field, dismiss_grid_prompt
from session import capture, close_normally, describe_windows
from qso_entry import log_without_cw
from input_checks import squeeze
from input_ui import ocr
from fixture_data import contacts
from bench_year_sent import database_of, select_band_mode, editor_facts

CONTEST = "All JA Contest"
SENT_PREFECTURE, SENT_POWER = "10", "M"
BAD_PREFECTURE, BAD_POWER = "49", "X"
RECEIVED_CALL, RECEIVED_EXCHANGE = "JA1ABC", "599 12H"
# What the comment line must say when a row's value is refused
# (SNewContestFieldValueRefused: 'The value of %s is not one this contest
# accepts.', %s the command name).
REFUSED_WORDS = "notonethiscontestaccepts"
# The two rows' captions: a startup row is labelled with its command name. The
# prompt TEXT (TC_PREFECTURE, SNewContestEnterPowerClass) goes to the one
# comment line, where each prompt overwrites the one before
# (uNewContest.SetCommentAndEnableEditControl), so only the last -- the power
# class -- is ever shown; it is recorded, not asserted.
PROMPT_WORDS = ("myprefecture", "mypowerclass")
RST_TOKEN = re.compile(r"\b(599|59|5NN)\b")


def ok_button(startup):
   return startup.child_window(title_re="&?OK", class_name="Button")


def ok_state_after(startup, expected, seconds=3):
   """OK's enabled state once it settles on EXPECTED, or the last one read."""
   deadline = time.monotonic() + seconds
   state = ok_button(startup).is_enabled()
   while state != expected and time.monotonic() < deadline:
      time.sleep(0.1)
      state = ok_button(startup).is_enabled()
   return state


def dialog_text(startup, output, name, journal):
   path = output / (name + ".png")
   journal.perform("capture New Contest " + name, lambda: capture(startup, path))
   return ocr(path)


def try_pair(startup, prefecture_field, power_field, prefecture, power, expect_ok, output, name, journal):
   set_field(prefecture_field, prefecture, journal)
   set_field(power_field, power, journal)
   enabled = ok_state_after(startup, expect_ok)
   text = dialog_text(startup, output, name, journal)
   return {"prefecture": prefecture, "power_class": power, "ok_enabled": enabled, "ocr": text}


def new_contest(app, startup, output, journal):
   """Item (a). Returns (facts, failures); leaves the dialog with 10 + M."""
   failures = []
   facts = {}
   fields = choose_contest(startup, CONTEST, journal)
   listing = ListBoxWrapper(startup.child_window(class_name="LCLListBox").handle)
   selected = [listing.item_texts()[index] for index in listing.selected_indices()]
   facts["selected_contest"] = selected
   # An item is the name, then its next date in brackets when it has a
   # schedule: 'All JA Contest   (2027-04-24 12:00 UTC)'.
   if len(selected) != 1 or re.sub(r"\s+\([^)]*\)\s*$", "", selected[0]).strip() != CONTEST:
      raise RuntimeError("Contest selection is not " + CONTEST + ": " + repr(selected))
   facts["prompt_edit_count"] = len(fields)
   if len(fields) != 2:
      failures.append("New Contest for " + CONTEST + " shows " + str(len(fields)) + " prompt inputs, expected 2")
      return facts, failures
   prefecture_field, power_field = fields
   text = dialog_text(startup, output, "allja-prompts", journal)
   facts["prompts_ocr"] = text
   missing = [word for word in PROMPT_WORDS if word not in squeeze(text)]
   if missing:
      failures.append("New Contest rows not read as MY PREFECTURE and MY POWER CLASS; missing " + repr(missing))
   if REFUSED_WORDS in squeeze(text):
      failures.append("New Contest shows a refusal before anything was typed: " + repr(text))
   facts["comment_names_power_class_prompt"] = "enteryourpowerclass" in squeeze(text)

   bad_power = try_pair(startup, prefecture_field, power_field, SENT_PREFECTURE, BAD_POWER, False,
      output, "refused-power-X", journal)
   facts["power_X"] = bad_power
   if bad_power["ok_enabled"]:
      failures.append("Power class X with prefecture 10: OK is enabled")
   if not (REFUSED_WORDS in squeeze(bad_power["ocr"]) and "mypowerclass" in squeeze(bad_power["ocr"])):
      failures.append("Power class X: the comment does not name MY POWER CLASS as refused: " + repr(bad_power["ocr"]))

   bad_prefecture = try_pair(startup, prefecture_field, power_field, BAD_PREFECTURE, SENT_POWER, False,
      output, "refused-prefecture-49", journal)
   facts["prefecture_49"] = bad_prefecture
   if bad_prefecture["ok_enabled"]:
      failures.append("Prefecture 49 with power class M: OK is enabled")
   if not (REFUSED_WORDS in squeeze(bad_prefecture["ocr"]) and "myprefecture" in squeeze(bad_prefecture["ocr"])):
      failures.append("Prefecture 49: the comment does not name MY PREFECTURE as refused: "
         + repr(bad_prefecture["ocr"]))

   good = try_pair(startup, prefecture_field, power_field, SENT_PREFECTURE, SENT_POWER, True,
      output, "accepted-10-M", journal)
   facts["accepted_10_M"] = good
   if not good["ok_enabled"]:
      failures.append("Prefecture 10 with power class M: OK stays disabled")
   if REFUSED_WORDS in squeeze(good["ocr"]):
      failures.append("10 + M: the comment still reads a refusal: " + repr(good["ocr"]))
   return facts, failures


def cabrillo_checks(text):
   """Item (c) over the exported file's text. Returns (facts, failures)."""
   failures = []
   lines = text.splitlines()
   contest = [line for line in lines if line.upper().startswith("CONTEST:")]
   qsos = [line for line in lines if line.startswith("QSO:")]
   facts = {"contest_lines": contest, "qso_lines": qsos}
   if [line.split(":", 1)[1].strip() for line in contest] != ["ALL-JA"]:
      failures.append("Cabrillo CONTEST line is not ALL-JA: " + repr(contest))
   if len(qsos) != 1:
      failures.append("Expected one QSO line, found " + str(len(qsos)) + ": " + repr(qsos))
      return facts, failures
   line = qsos[0]
   # The sent call, the column pad, then the class's '%3s %-2s ' and the call.
   match = re.search(r"\bW1AW( +)(\S+) (\S+)( +)" + RECEIVED_CALL + r"\b", line)
   if match is None:
      failures.append("QSO line does not read W1AW, prefecture, power, received call: " + repr(line))
      return facts, failures
   facts.update({"sent_prefecture": match.group(2), "sent_power": match.group(3),
      "gap_before_received_call": len(match.group(4)),
      "received_part": line[match.end():]})
   if match.group(2) != SENT_PREFECTURE or match.group(3) != SENT_POWER:
      failures.append("Sent columns read " + repr(match.group(2) + " " + match.group(3)) + ", expected '10 M'")
   # '%-2s ' of one letter is the letter, its pad and the separator: two spaces.
   if len(match.group(4)) != 2:
      failures.append("Expected the power letter, its pad and one separating space (2 spaces) before "
         + RECEIVED_CALL + ", found " + str(len(match.group(4))) + ": " + repr(line))
   rst = RST_TOKEN.findall(line)
   if rst:
      failures.append("QSO line carries an RST " + repr(rst) + ": " + repr(line))
   return facts, failures


def check(app, startup, root, run_name, output, journal):
   if list((root / "runs" / run_name).glob("*.db")):
      raise RuntimeError("The ALL JA case requires a fixture with no contest log")
   items = {}
   facts, failures = new_contest(app, startup, output, journal)
   items["a"] = {"passed": not failures, "failures": failures, "facts": facts}
   if not facts.get("accepted_10_M", {}).get("ok_enabled"):
      items["b"] = items["c"] = {"passed": False, "failures": ["NOT RUN: New Contest did not accept 10 + M"]}
      result = finish(output, items)
      # Raised, not returned: the dialog is still up, and bench_ui's handler
      # ends the owned process; an AssertionError reads FAIL, not ERROR.
      raise AssertionError("; ".join(result["failures"]))

   journal.perform("create the ALL JA log", lambda: ok_button(startup).click_input())
   main = app.window(title_re=r"TR4W v.*")
   main.wait("visible enabled", timeout=30)
   dismiss_grid_prompt(app, journal)
   describe_windows(app, output)
   observed = select_band_mode(main, "80", "CW", journal)
   log_without_cw(main, RECEIVED_CALL, RECEIVED_EXCHANGE, journal)
   capture(main, output / "logged.png")

   # (b) Edit QSO's two new boxes, then the stored row.
   failures = []
   editor = editor_facts(app, main, output, journal, "edit-qso-allja")
   for key, value in (("prefecture", SENT_PREFECTURE), ("power_class", SENT_POWER)):
      box = editor[key]
      if box["text"] != value or not box["enabled"]:
         failures.append("Edit QSO " + key + " is not an enabled " + value + ": " + repr(box))
   rows = contacts(database_of(root, run_name))
   stored = [{key: row.get(key) for key in ("callsign", "call", "band", "mode", "my_prefecture",
      "my_power_class", "exchange")} for row in rows]
   if [(row.get("my_prefecture"), row.get("my_power_class")) for row in rows] != [(SENT_PREFECTURE, SENT_POWER)]:
      failures.append("Logged row does not store my_prefecture 10 / my_power_class M: " + repr(stored))
   items["b"] = {"passed": not failures, "failures": failures,
      "facts": {"band_mode_shown": observed, "edit_qso": editor, "stored": stored}}

   # (c) The Cabrillo line.
   from bench_exports import run_export
   text, declined = run_export(app, main, root, run_name, output, journal, "cabrillo", "allja")
   facts, failures = cabrillo_checks(text)
   facts["upload_declined"] = declined
   items["c"] = {"passed": not failures, "failures": failures, "facts": facts}
   close_normally(app, main, journal)
   return finish(output, items)


def finish(output, items):
   (output / "allja-result.json").write_text(json.dumps(items, indent=3, default=str), encoding="utf-8")
   failures = [name + ": " + failure for name, item in items.items() for failure in item["failures"]]
   return {"passed": not failures, "failures": failures, "items": {name: item["passed"] for name, item in items.items()},
      "note": "Per-item facts in allja-result.json; OCR is Windows OCR over the whole New Contest dialog"}
