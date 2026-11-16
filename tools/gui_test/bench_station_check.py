"""Preferences > Station refuses bad input INLINE, never with a modal box.

NY4I, 2026-11-16: bad Station input was accepted silently or flagged by an
old-style message box, "the types of things the python GUI testers should
have found". Commit be4dc5a6 made the page check each field when it loses
focus (uStationFieldCheck). This case drives the real window and asserts,
for every checked field (input_checks.STATION_FIELDS):

   (a) a bad value turns the field red and the line under the fields
       (lblStationProblem) names it; a good one clears both
   (b) NO new top-level window appears when the field is left
   (c) focus is back in the bad field after Tab (Shift+Tab for the last
       field, whose Tab goes to a button and is let go by design)
   (d) Save and close (and Save, when enabled) with a bad value keeps the
       dialog open, says "Station settings not saved" and leaves tr4w.json
       byte-identical
   (e) bad values written into tr4w.json before a launch are marked when
       the page opens and block Save until each is fixed
   (f) every field fixed, Save and close closes, and the values are in
       tr4w.json

HOW THE UI IS READ. Inputs are found by their designed captions and position
(bench_station_names.station_rows). Focus is the thread's real focus
(GetGUIThreadInfo). Windows are the owned process's visible top-level
windows. The red mark and the message line are PIXELS: lblStationProblem is
a TLabel, which has no window and no accessibility object, so its text is
read by Windows OCR from a crop (input_ui.ocr) and matched on words; the
crops and the raw OCR text are kept as evidence. The line's position is its
designed client rectangle in the Station panel (PROBLEM_LINE).
"""

import hashlib
import json
import time

import win32gui
from pywinauto.controls.hwndwrapper import HwndWrapper
from pywinauto.controls.win32_controls import EditWrapper

from session import capture, close_normally, launch
from preferences_audit import focus_info
from bench_station_names import anchors, station_rows
from input_checks import (STATION_FIELDS, PRELOADED_BAD, NOT_SAVED_WORDS, choose_good, keys_for,
   names_all, names_any, red_pixels, stored_matches)
from input_ui import client_region, dismiss, ensure_foreground, new_windows, ocr, owned_windows, window_body

# lblStationProblem's designed rectangle in the Station panel's client area
# (uPrefsForm.lfm: Left 12, Top 332, Width 640, Height 34; 96 DPI, unscaled).
PROBLEM_LINE = (12, 332, 640, 34)
# Red pixels that count as "marked": a field's text, the line's text.
FIELD_RED_MIN = 5
LINE_RED_MIN = 20
HOLD_TIMEOUT = 1.5


def settings_file(root, run_name):
   return root / "runs" / run_name / "tr4w.json"


def digest(path):
   return hashlib.sha256(path.read_bytes()).hexdigest()


def stored_my(path):
   return json.loads(path.read_text(encoding="utf-8-sig")).get("settings", {}).get("My", {})


def text_of(handle):
   return EditWrapper(handle).window_text()


class StationProbe:
   """One Preferences window's Station page, read and driven."""

   def __init__(self, app, prefs, output, journal):
      self.app = app
      self.prefs = prefs
      # Resolved once: the spec finds only a VISIBLE window, and Preferences is
      # hidden (not destroyed) by Save and close, which is what is checked.
      self.handle = prefs.handle
      self.prefs = app.window(handle=self.handle)
      self.output = output / "station"
      self.output.mkdir(parents=True, exist_ok=True)
      self.journal = journal
      self.baseline = set(owned_windows(app.process))
      self.failures = []
      self.ocr_checks = []
      self.windows_seen = []
      self.foreground_events = []
      # Every crop gets a unique, ordered name; carried across the relaunch so
      # the second launch cannot overwrite the first launch's evidence.
      self.sequence = 0
      self.fields = self.locate(output)
      self.panel = win32gui.GetParent(self.fields[0]["handle"])
      if any(win32gui.GetParent(field["handle"]) != self.panel for field in self.fields):
         raise RuntimeError("The Station inputs do not share one panel; the message line cannot be located")

   def locate(self, output):
      rows = station_rows(self.prefs, *anchors(self.prefs, output, self.journal))
      by_caption = {row["caption"]: row for row in rows}
      fields = []
      for spec in STATION_FIELDS:
         row = by_caption.get(spec["caption"])
         if row is None or row["input_class"] != "Edit":
            raise RuntimeError("Station input not found as an Edit: " + spec["caption"])
         fields.append(dict(spec, handle=row["input_handle"]))
      return fields

   def fail(self, text):
      self.failures.append(text)

   def focused(self):
      return focus_info(self.prefs).get("handle")

   def type_into(self, field, value):
      control = HwndWrapper(field["handle"])
      self.journal.perform("type " + repr(value) + " into " + field["caption"],
         lambda: control.type_keys("{HOME}+{END}{DEL}" + keys_for(value), with_spaces=True, pause=0.02))
      readback = text_of(field["handle"])
      if readback != value:
         raise RuntimeError("Driver could not enter " + repr(value) + " in " + field["caption"]
            + "; the box reads " + repr(readback))

   def leave(self, field, keys):
      self.journal.perform("leave " + field["caption"] + " with " + keys,
         lambda: HwndWrapper(field["handle"]).type_keys(keys, pause=0.02))

   def wait_focus_on(self, handle, timeout=HOLD_TIMEOUT):
      deadline = time.monotonic() + timeout
      while time.monotonic() < deadline:
         if self.focused() == handle:
            time.sleep(0.3)
            return self.focused() == handle
         time.sleep(0.1)
      return False

   def check_windows(self, context):
      """(b): any new top-level window is the regression NY4I hit. It is read,
      captured, dismissed (so the run can go on) and reported."""
      extra = new_windows(self.app.process, self.baseline)
      if not win32gui.IsWindowEnabled(self.handle) and not extra:
         self.fail("(b) " + context + ": Preferences is disabled, as under a modal")
      for handle, (kind, title) in extra.items():
         body = window_body(self.app, handle)
         self.windows_seen.append({"context": context, "class": kind, "title": title, "text": body})
         self.fail("(b) " + context + ": a window appeared: " + kind + " '" + title + "': " + body)
         try:
            capture(self.app.window(handle=handle), self.output / ("unexpected-window-" + str(len(self.windows_seen)) + ".png"))
         except Exception as error:
            self.windows_seen[-1]["capture_error"] = repr(error)
         self.windows_seen[-1]["dismissed_with"] = dismiss(self.app, handle, self.journal)
      return not extra

   def foreground(self, name):
      ensure_foreground(self.prefs, self.foreground_events, name)

   def field_red(self, field, name):
      left, top, right, bottom = win32gui.GetWindowRect(field["handle"])
      path = self.output / (name + "-field.png")
      self.foreground(name)
      capture(self.prefs, path, region=(left + 2, top + 2, right - 2, bottom - 2), focus=False)
      from PIL import Image
      with Image.open(path) as image:
         return red_pixels(image)

   def line(self, name):
      """The message line: saved crop path and its red pixel count."""
      path = self.output / (name + "-line.png")
      self.foreground(name)
      capture(self.prefs, path, region=client_region(self.panel, *PROBLEM_LINE), focus=False)
      from PIL import Image
      with Image.open(path) as image:
         return path, red_pixels(image)

   def expect_line(self, path, label, must, must_not=()):
      self.ocr_checks.append({"label": label, "path": str(path), "must": list(must), "must_not": list(must_not)})

   def probe(self, index, field, value, bad):
      """Type VALUE, leave the field and observe (a), (b), (c)."""
      keys = "+{TAB}" if index == len(self.fields) - 1 else "{TAB}"
      self.sequence += 1
      name = "{:03d}-{:02d}-{}-{}".format(self.sequence, index, field["key"], "bad" if bad else "good")
      HwndWrapper(field["handle"]).set_focus()
      self.type_into(field, value)
      self.leave(field, keys)
      observation = {"field": field["caption"], "value": value, "bad": bad, "leave": keys}
      if bad:
         observation["focus_held"] = self.wait_focus_on(field["handle"])
      else:
         time.sleep(0.8)
         observation["focus_held"] = self.focused() == field["handle"]
      observation["no_new_window"] = self.check_windows(field["caption"] + " " + repr(value))
      if observation["focus_held"]:
         # The hold selects the text (white on blue); deselect to see its colour.
         self.journal.perform("deselect " + field["caption"], lambda: HwndWrapper(field["handle"]).type_keys("{END}"))
      observation["field_red"] = self.field_red(field, name)
      path, observation["line_red"] = self.line(name)
      observation["after"] = text_of(field["handle"])
      if bad:
         if not observation["focus_held"]:
            self.fail("(c) " + field["caption"] + " " + repr(value) + ": focus did not stay in the field after "
               + keys + " (focus is on " + repr(focus_info(self.prefs)) + ")")
         if observation["field_red"] < FIELD_RED_MIN:
            self.fail("(a) " + field["caption"] + " " + repr(value) + ": the field is not red ("
               + str(observation["field_red"]) + " red pixels)")
         if observation["line_red"] < LINE_RED_MIN:
            self.fail("(a) " + field["caption"] + " " + repr(value) + ": no message line under the fields")
         self.expect_line(path, "(a) " + field["caption"] + " " + repr(value) + " is named", field["words"])
      else:
         if observation["focus_held"]:
            self.fail("(c) " + field["caption"] + " good " + repr(value) + ": focus was held on a valid value")
         if observation["field_red"] > 2:
            self.fail("(a) " + field["caption"] + " good " + repr(value) + ": the field is still red")
      return observation, path

   def save_refused(self, button, field, label):
      """(d): press BUTTON with FIELD wrong; nothing may be written."""
      settings = self.settings
      before = digest(settings)
      control = self.prefs.child_window(title=button)
      self.journal.perform(label + ": press " + button, control.click_input)
      time.sleep(1.0)
      result = {"button": button, "field": field["caption"]}
      result["dialog_open"] = bool(win32gui.IsWindowVisible(self.handle))
      result["no_new_window"] = self.check_windows(label + " " + button)
      result["file_unchanged"] = digest(settings) == before
      result["focus_on_field"] = self.wait_focus_on(field["handle"])
      if not result["dialog_open"]:
         self.fail("(d) " + label + ": " + button + " closed Preferences with " + field["caption"] + " wrong")
         return result
      if not result["file_unchanged"]:
         self.fail("(d) " + label + ": " + button + " changed tr4w.json with " + field["caption"] + " wrong")
      if not result["focus_on_field"]:
         self.fail("(d) " + label + ": focus did not go to " + field["caption"] + " after the refused save")
      self.sequence += 1
      path, result["line_red"] = self.line("{:03d}-save-{}-{}".format(self.sequence, label.replace(" ", "-"), button.replace(" ", "-")))
      if result["line_red"] < LINE_RED_MIN:
         self.fail("(d) " + label + ": no message line after the refused save")
      self.expect_line(path, "(d) " + label + " " + button + " says not saved and names " + field["caption"],
         NOT_SAVED_WORDS + tuple(field["words"]))
      return result

   def save_and_close(self, label):
      """(f): press Save and close with every field right. A question the
      program asks at Save (not at field exit) is read, answered No and
      recorded; it is not a (b) failure."""
      self.journal.perform(label + ": Save and close", self.prefs.child_window(title="Save and close").click_input)
      questions = []
      deadline = time.monotonic() + 15
      while time.monotonic() < deadline and win32gui.IsWindowVisible(self.handle):
         extra = new_windows(self.app.process, self.baseline)
         for handle in extra:
            text = window_body(self.app, handle)
            questions.append({"text": text, "answered": dismiss(self.app, handle, self.journal, ("No", "OK", "Cancel"))})
         time.sleep(0.2)
      if win32gui.IsWindowVisible(self.handle):
         self.fail("(f) " + label + ": Save and close did not close Preferences with every field right")
         path, _ = self.line("save-" + label + "-still-open")
         self.expect_line(path, "(f) diagnostic: the line after a refused good save", ())
      return questions

   def run_ocr(self):
      results = []
      for check in self.ocr_checks:
         text = ocr(check["path"])
         passed = names_all(text, check["must"]) and not names_any(text, check["must_not"])
         results.append(dict(check, ocr=text, passed=passed))
         if not passed:
            self.fail(check["label"] + ": the line reads " + repr(text))
      return results


def fresh_page(probe, root, run_name):
   """(a), (b), (c), (d), (f) on the clean fixture. Returns the typed goods."""
   probe.settings = settings_file(root, run_name)
   loaded = {field["key"]: text_of(field["handle"]) for field in probe.fields}
   path, red = probe.line("00-open")
   if red:
      probe.fail("(a) the clean fixture shows a message line when the page opens (" + str(red) + " red pixels)")
   observations = []
   goods = {}
   for index, field in enumerate(probe.fields):
      bad, _ = probe.probe(index, field, field["bad"], True)
      goods[field["key"]] = choose_good(field["goods"], loaded[field["key"]])
      good, _ = probe.probe(index, field, goods[field["key"]], False)
      if good["line_red"]:
         probe.fail("(a) " + field["caption"] + " good: the message line is not cleared ("
            + str(good["line_red"]) + " red pixels) with every field so far right")
      observations += [bad, good]

   park = next(field for field in probe.fields if field["key"] == "Park")
   index = probe.fields.index(park)
   probe.probe(index, park, park["bad"], True)
   save_enabled = probe.prefs.child_window(title="Save").is_enabled()
   refusals = [probe.save_refused("Save and close", park, "typed")]
   if save_enabled:
      refusals.append(probe.save_refused("Save", park, "typed"))
   probe.probe(index, park, goods["Park"], False)
   immediate_before = stored_my(probe.settings)
   questions = probe.save_and_close("fresh")
   immediate = stored_my(probe.settings)
   return {"loaded": loaded, "goods": goods, "fields": observations, "refused_saves": refusals,
      "save_button_enabled_after_station_edit": save_enabled, "save_questions": questions,
      "stored_before_save": immediate_before, "stored_right_after_save": immediate}


def check_stored(probe, goods, label):
   stored = stored_my(probe.settings)
   for key, value in goods.items():
      if not stored_matches(key, stored.get(key), value):
         probe.fail("(f) " + label + ": tr4w.json My." + key + " is " + repr(stored.get(key)) + ", expected " + repr(value))
   return stored


def preloaded_page(probe):
   """(e): the values PRELOADED_BAD wrote into tr4w.json, never touched."""
   by_key = {field["key"]: field for field in probe.fields}
   bad_fields = [by_key[key] for key, _ in PRELOADED_BAD]
   result = {"loaded": {}}
   for key, value in PRELOADED_BAD:
      field = by_key[key]
      result["loaded"][key] = text_of(field["handle"])
      if result["loaded"][key] != value:
         probe.fail("(e) tr4w.json held " + key + " " + repr(value) + " but the page shows "
            + repr(result["loaded"][key]))
      red = probe.field_red(field, "preload-open-" + key)
      result["loaded"][key + "_red"] = red
      if red < FIELD_RED_MIN:
         probe.fail("(e) the loaded " + field["caption"] + " " + repr(value) + " is not marked when the page opens")
   path, red = probe.line("preload-open")
   if red < LINE_RED_MIN:
      probe.fail("(e) no message line when the page opens with loaded bad values")
   probe.expect_line(path, "(e) the line at open names the first wrong field, " + bad_fields[0]["caption"],
      bad_fields[0]["words"])
   result["refused_saves"] = [probe.save_refused("Save and close", bad_fields[0], "loaded")]
   goods = {}
   for position, field in enumerate(bad_fields):
      index = probe.fields.index(field)
      goods[field["key"]] = field["goods"][0]
      observation, path = probe.probe(index, field, goods[field["key"]], False)
      result.setdefault("fixed", []).append(observation)
      if position + 1 < len(bad_fields):
         following = bad_fields[position + 1]
         probe.expect_line(path, "(e) after fixing " + field["caption"] + " the line names " + following["caption"],
            following["words"], (field["words"][1],))
         result["refused_saves"].append(probe.save_refused("Save and close", following, "loaded"))
   result["save_questions"] = probe.save_and_close("preloaded")
   result["goods"] = goods
   return result


def check(app, main, prefs, root, run_name, output, journal):
   """Both launches. Returns (result, app, main) for the second process; the
   runner's normal close follows, then verify_after_exit reads tr4w.json."""
   prefs.wait("visible enabled", timeout=10)
   probe = StationProbe(app, prefs, output, journal)
   fresh = fresh_page(probe, root, run_name)
   journal.perform("capture main after the fresh save", lambda: capture(main, probe.output / "main-after-fresh.png"))
   close_normally(app, main, journal)
   fresh["stored_after_exit"] = check_stored(probe, fresh["goods"], "fresh, after exit")

   document = json.loads(probe.settings.read_text(encoding="utf-8-sig"))
   for key, value in PRELOADED_BAD:
      document["settings"]["My"][key] = value
   probe.settings.write_text(json.dumps(document, indent=3), encoding="utf-8")
   databases = list((root / "runs" / run_name).glob("CWOPEN*.db"))
   if len(databases) != 1:
      raise RuntimeError("Relaunch needs the one CW Open log")
   app = journal.perform("relaunch with bad values in tr4w.json", lambda: launch(root, run_name, databases[0].name))
   main = app.window(title_re=r"TR4W v.*CWOPEN.*")
   main.wait("visible enabled", timeout=30)
   startup_windows = owned_windows(app.process)
   journal.perform("open Preferences with Ctrl+J", lambda: main.type_keys("^j"))
   prefs = app.window(title="TR4W Preferences")
   prefs.wait("visible enabled", timeout=10)
   kept = (probe.failures, probe.ocr_checks, probe.windows_seen, probe.foreground_events, probe.sequence)
   probe = StationProbe(app, prefs, output, journal)
   probe.failures, probe.ocr_checks, probe.windows_seen, probe.foreground_events, probe.sequence = kept
   probe.settings = settings_file(root, run_name)
   preloaded = preloaded_page(probe)
   preloaded["windows_at_startup"] = {str(handle): facts for handle, facts in startup_windows.items()}

   result = {"fresh": fresh, "preloaded": preloaded, "unexpected_windows": probe.windows_seen,
      "foreground_lost_before_capture": probe.foreground_events}
   try:
      result["ocr"] = probe.run_ocr()
   except Exception as error:
      result["incomplete"] = ["OCR could not read the message line: " + repr(error)]
   (output / "station-check.json").write_text(json.dumps(result, indent=3, default=str), encoding="utf-8")
   summary = {"passed": not probe.failures, "failures": probe.failures,
      "fields_checked": len(probe.fields), "pending_after_exit": dict(preloaded["goods"]),
      "note": "Station page inline validation: field mark, line, focus hold, no window, refused and good saves"}
   if "incomplete" in result:
      summary["incomplete"] = result["incomplete"]
   return summary, app, main


def verify_after_exit(root, run_name, output, result):
   """(e)'s fixed values must be in tr4w.json once the program has closed."""
   stored = stored_my(settings_file(root, run_name))
   failures = list(result.get("failures", []))
   for key, value in result.get("pending_after_exit", {}).items():
      if not stored_matches(key, stored.get(key), value):
         failures.append("(e) after fixing and saving, tr4w.json My." + key + " is " + repr(stored.get(key))
            + ", expected " + repr(value))
   (output / "stored-after-exit.json").write_text(json.dumps(stored, indent=3), encoding="utf-8")
   return dict(result, failures=failures, passed=not failures)
