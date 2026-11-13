"""Check CW Open exchange validation through the real entry fields, without CW."""

from collections import Counter
from contextlib import closing
import json
import sqlite3
import time

from pywinauto.timings import wait_until

from contest_forms import choose_contest, set_field, dismiss_grid_prompt
from preferences_audit import focus_info
from qso_entry import entry_fields
from session import capture, close_normally, describe_windows, hover_control, wait_for_hint


EM_GETCUEBANNER = 0x1502


def cue_banner(control):
   # The native placeholder (LCL TextHint on Win32) is read back with
   # EM_GETCUEBANNER; an empty answer means no gray suggestion is set.
   # Windows does not marshal this message between processes, so the buffer is
   # allocated INSIDE the application (RemoteMemoryBlock); a local pointer would
   # make TR4W write through an address that means nothing in its own space.
   import ctypes
   import win32gui
   from pywinauto.remote_memory_block import RemoteMemoryBlock
   characters = 512
   remote = RemoteMemoryBlock(control, size=characters * 2)
   try:
      returned = control.send_message(EM_GETCUEBANNER, remote.mem_address, characters)
      buffer = ctypes.create_unicode_buffer(characters)
      remote.Read(buffer)
   finally:
      remote.CleanUp()
   return {"handle": control.handle, "class": win32gui.GetClassName(control.handle),
      "returned": int(returned), "text": buffer.value}


def visible_texts(main):
   rows = []
   for control in main.descendants():
      if control.is_visible() and control.window_text().strip():
         rect = control.rectangle()
         rows.append({"text": control.window_text(), "class": control.class_name(),
            "rect": [rect.left, rect.top, rect.right, rect.bottom]})
   return rows


def notice_controls(main, message):
   return [control for control in main.descendants()
      if control.is_visible() and message in control.window_text()]


def colour_profile(image):
   # Background = the commonest colour; text = the commonest colour that differs
   # clearly from it. Numbers, not a judgement of "red" or "black".
   pixels = list(image.convert("RGB").getdata())
   counts = Counter(pixels)
   background = counts.most_common(1)[0][0]
   distinct = Counter({colour: n for colour, n in counts.items()
      if sum(abs(a - b) for a, b in zip(colour, background)) > 120})
   text = [{"rgb": list(colour), "pixels": n} for colour, n in distinct.most_common(5)]
   return {"background_rgb": list(background), "text_colours": text, "pixel_count": len(pixels)}


def observe_notice(main, message, output, name):
   controls = notice_controls(main, message)
   result = {"message": message, "controls": []}
   for index, control in enumerate(controls):
      rect = control.rectangle()
      crop = output / (name + "-notice-" + str(index) + ".png")
      capture(main, crop, region=(rect.left, rect.top, rect.right, rect.bottom))
      from PIL import Image
      with Image.open(crop) as image:
         profile = colour_profile(image)
      result["controls"].append({"text": control.window_text(), "class": control.class_name(),
         "rect": [rect.left, rect.top, rect.right, rect.bottom], "crop": crop.name, "colours": profile})
   return result


def check(app, startup, root, run_name, output, journal):
   directory = root / "runs" / run_name
   if list(directory.glob("*.db")):
      raise RuntimeError("Exchange-error checks require a fresh run with no log")
   fields = choose_contest(startup, "CW Open", journal)
   if len(fields) != 1:
      raise RuntimeError("CW Open name input not unique")
   set_field(fields[0], "TOM", journal)
   journal.perform("create the empty exchange-test log", lambda: startup.child_window(title_re="&?OK", class_name="Button").click_input())
   main = app.window(title_re=r"TR4W v.*CWOPEN.*")
   main.wait("visible", timeout=30)
   dismiss_grid_prompt(app, journal)
   main.wait("enabled", timeout=10)
   databases = list(directory.glob("CWOPEN*.db"))
   if len(databases) != 1:
      raise RuntimeError("Created exchange-test log is not unique")

   def count():
      with closing(sqlite3.connect(databases[0].resolve().as_uri() + "?mode=ro", uri=True)) as connection:
         return connection.execute("SELECT COUNT(*) FROM qso").fetchone()[0]

   if count() != 0:
      raise AssertionError("Exchange test did not start with zero contacts")
   call, exchange = entry_fields(main)
   observations = {"placeholders_empty_fields": [cue_banner(call), cue_banner(exchange)],
      "visible_texts_start": visible_texts(main)}
   rect = exchange.rectangle()
   capture(main, output / "exchange-empty.png")
   capture(main, output / "exchange-empty-crop.png", region=(rect.left, rect.top, rect.right, rect.bottom))
   call.set_focus()
   journal.perform("type W7SP", lambda: call.type_keys("W7SP"))
   journal.perform("advance without CW", lambda: call.type_keys("^{ENTER}"))
   time.sleep(0.5)
   observations["exchange_after_call"] = {"text": exchange.window_text(), "placeholder": cue_banner(exchange)}
   observations["visible_texts_after_call"] = visible_texts(main)
   capture(main, output / "exchange-awaiting.png")
   capture(main, output / "exchange-awaiting-crop.png", region=(rect.left, rect.top, rect.right, rect.bottom))
   journal.perform("hover exchange field", lambda: hover_control(exchange))
   time.sleep(1.5)
   hints = wait_for_hint(2)
   observations["exchange_hover_hint"] = [{"class": h.class_name(), "text": h.window_text()} for h in hints]
   if hints:
      capture(main, output / "exchange-hover.png")
   results = []
   for text, message, name in (("WOODY", "No QSO number found!!", "missing-serial"),
      ("234", "No name found!!", "missing-name")):
      journal.perform("focus exchange", exchange.set_focus)
      journal.perform("enter incomplete exchange " + text, lambda: exchange.set_edit_text(text))
      before_focus = focus_info(main)["handle"]
      journal.perform("submit incomplete exchange without CW", lambda: exchange.type_keys("^{ENTER}"))
      wait_until(5, 0.1, lambda: message in (directory / "tr4w.log").read_text(encoding="utf-8", errors="replace"))
      if count() != 0 or call.window_text() != "W7SP":
         raise AssertionError("Incomplete exchange was logged or changed the callsign")
      if focus_info(main)["handle"] != before_focus:
         raise AssertionError("Refused exchange moved keyboard focus away from the field")
      capture(main, output / (name + ".png"))
      notice = observe_notice(main, message, output, name)
      notice["exchange_text_after_refusal"] = exchange.window_text()
      notice["visible_texts"] = visible_texts(main)
      observations[name] = notice
      results.append({"input": text, "message": message, "qso_count": 0, "focus_retained": True,
         "notice_controls": len(notice["controls"])})
   journal.perform("replace with valid exchange", lambda: exchange.set_edit_text("234 WOODY"))
   journal.perform("submit valid exchange without CW", lambda: exchange.type_keys("^{ENTER}"))
   if call.window_text():
      journal.perform("complete valid CQ entry without CW", lambda: exchange.type_keys("^{ENTER}"))
   wait_until(5, 0.1, lambda: count() == 1)
   if call.window_text() or exchange.window_text():
      raise AssertionError("Valid entry did not clear the input fields")
   capture(main, output / "valid-after-errors.png")
   observations["visible_texts_after_valid"] = visible_texts(main)
   call.set_focus()
   journal.perform("empty Ctrl+Enter", lambda: call.type_keys("^{ENTER}"))
   time.sleep(0.7)
   capture(main, output / "empty-enter.png")
   observations["visible_texts_after_empty_enter"] = visible_texts(main)
   if count() != 1 or call.window_text() or exchange.window_text():
      raise AssertionError("Empty Enter changed the log or entry fields")
   (output / "notice-observations.json").write_text(json.dumps(observations, indent=3), encoding="utf-8")
   describe_windows(app, output)
   started = time.monotonic()
   close_normally(app, main, journal)
   exit_seconds = round(time.monotonic() - started, 2)
   result = {"passed": True, "pid": app.process, "refusals": results,
      "valid_qso_count": 1, "empty_enter_qso_count": 1, "close_to_exit_seconds_no_radio": exit_seconds,
      "note": "Notice strings, counts and focus passed; colour, placeholder and format observations are in notice-observations.json"}
   (output / "entry-result.json").write_text(json.dumps(result, indent=3), encoding="utf-8")
   return result
