"""The invalid-input sweep: what Preferences does with obviously bad input.

A REPORT, not a verdict. For every visible, enabled text box on the
Preferences pages in this phase's tag range (Station, tag 1, has its own case,
bench_station_check), it enters each of input_checks.SWEEP_VALUES the way an
operator would (typed; the 300-character string pasted), leaves the box with
Tab and records what the program did: accepted silently, refused or cut while
typing, changed the value on leaving, marked it inline (focus held, red
text), put up a window (its text is read, then it is dismissed with its
non-committing answer), hung, or crashed. Each box's original text is put
back after every value and the walk ends with Cancel: nothing is saved.

passed means only that the walk completed without a crash or hang; the rules
for these fields are undecided, so no behaviour is asserted. Rows are written
to sweep-rows.jsonl as they are observed, so a crash keeps everything before
it; tools/gui_test/sweep_report.py turns them into the markdown table.
"""

import json
import time

import win32clipboard
import win32con
import win32gui
from pywinauto.controls.hwndwrapper import HwndWrapper
from pywinauto.controls.win32_controls import EditWrapper

from session import capture
from preferences_audit import current_page, focus_info, navigation_tree
from bench_station_names import uia_facts
from input_checks import SWEEP_VALUES, classify, keys_for, red_pixels, shorten
from input_ui import dismiss, ensure_foreground, new_windows, ocr, owned_windows, window_body

# Inclusive tag ranges, split so each phase stays inside vm_run's 1200 s poll.
PAGE_RANGES = {
   "bench-prefs-invalid-sweep-a": (2, 16),
   "bench-prefs-invalid-sweep-b": (17, 32),
   "bench-prefs-invalid-sweep-c": (33, 99),
}
TIME_BUDGET = 1050


def put_clipboard(text):
   win32clipboard.OpenClipboard()
   try:
      win32clipboard.EmptyClipboard()
      win32clipboard.SetClipboardData(win32con.CF_UNICODETEXT, text)
   finally:
      win32clipboard.CloseClipboard()


class Sweep:
   def __init__(self, app, prefs, root, run_name, output, journal, phase):
      self.app = app
      self.prefs = prefs
      self.output = output / "sweep"
      self.output.mkdir(parents=True, exist_ok=True)
      self.rows_path = output / "sweep-rows.jsonl"
      self.journal = journal
      self.low, self.high = PAGE_RANGES[phase]
      self.log = root / "runs" / run_name / "tr4w.log"
      self.log_start = self.log.stat().st_size if self.log.exists() else 0
      self.baseline = set(owned_windows(app.process))
      self.tree = navigation_tree(prefs)
      edits = [control for control in prefs.descendants(class_name="Edit") if control.is_visible()]
      self.search = min(edits, key=lambda control: (control.rectangle().left, control.rectangle().top)).handle
      tree = self.tree.rectangle()
      frame = prefs.rectangle()
      # The page area: right of the navigation tree, as tall as it.
      self.content = (tree.right + 4, tree.top, frame.right - 12, tree.bottom)
      self.rows = []
      self.pages = []
      self.foreground_events = []
      self.captions = []
      self.stopped = None
      self.started = time.monotonic()

   def crashed(self):
      if not self.app.is_process_running():
         return True
      if not self.log.exists():
         return False
      with self.log.open("rb") as stream:
         stream.seek(self.log_start)
         return b"[CRASH]" in stream.read()

   def hung(self):
      import ctypes
      return bool(ctypes.windll.user32.IsHungAppWindow(self.prefs.handle))

   def red(self, name, region):
      path = self.output / (name + ".png")
      ensure_foreground(self.prefs, self.foreground_events, name)
      capture(self.prefs, path, region=region, focus=False)
      from PIL import Image
      with Image.open(path) as image:
         return red_pixels(image)

   def inside(self, control):
      rect = control.rectangle()
      return (rect.left >= self.content[0] and rect.right <= self.content[2] and rect.top >= self.content[1]
         and rect.bottom <= self.content[3])

   def boxes(self):
      """The page's text boxes: visible, writable Edits, not the search box and
      not the edit inside a combo box. Returns (enabled, skipped) where skipped
      counts what is NOT swept and why, so the report can say so."""
      result = []
      skipped = {"disabled": 0, "read-only": 0, "combo box": 0}
      for control in self.prefs.descendants(class_name="Edit"):
         handle = control.handle
         if handle == self.search or not control.is_visible():
            continue
         if win32gui.GetClassName(win32gui.GetParent(handle)) == "LCLComboBox":
            skipped["combo box"] += 1
            continue
         if not control.is_enabled():
            skipped["disabled"] += 1
            continue
         if win32gui.GetWindowLong(handle, win32con.GWL_STYLE) & win32con.ES_READONLY:
            skipped["read-only"] += 1
            continue
         result.append(control)
      return sorted(result, key=lambda control: (control.rectangle().top, control.rectangle().left)), skipped

   def bring_into_view(self, control):
      """A box below the fold: focus it (the page scrolls to the focused
      control) and look again. True when it is now fully in the page area."""
      if self.inside(control):
         return True
      try:
         HwndWrapper(control.handle).set_focus()
      except Exception:
         return False
      time.sleep(0.3)
      return self.inside(control)

   def name(self, control):
      facts = uia_facts(control.handle)
      help_text = " ".join((facts.get("help_text") or "").split())
      rect = control.rectangle()
      return {"uia_name": facts.get("name") or "", "help": shorten(help_text, 160),
         "rect": [rect.left, rect.top, rect.right, rect.bottom]}

   def caption_crop(self, tag, index, control):
      """The box's caption is a TLabel (no window, no accessibility name), so
      its pixels are kept -- left of the box on its row, or above a box with
      no room to its left -- and read by OCR after the walk (read_captions)."""
      rect = control.rectangle()
      if rect.left - 4 - self.content[0] >= 40:
         region = (self.content[0], rect.top - 2, rect.left - 4, rect.bottom + 2)
      else:
         region = (rect.left, rect.top - 20, rect.right, rect.top - 1)
      path = self.output / "caption-{}-{:02d}.png".format(tag, index)
      ensure_foreground(self.prefs, self.foreground_events, path.stem)
      capture(self.prefs, path, region=region, focus=False)
      self.captions.append({"page": tag, "index": index, "path": str(path)})

   def read_captions(self, output):
      for item in self.captions:
         try:
            item["text"] = ocr(item["path"])
         except Exception as error:
            item["error"] = repr(error)
      (output / "box-names.json").write_text(json.dumps(self.captions, indent=3), encoding="utf-8")

   def windows(self, context):
      seen = []
      for _ in range(3):
         extra = new_windows(self.app.process, self.baseline)
         if not extra:
            break
         for handle, (kind, title) in extra.items():
            item = {"class": kind, "title": title}
            seen.append(item)
            item["text"] = window_body(self.app, handle)
            try:
               capture(self.app.window(handle=handle), self.output / ("window-" + context + "-" + str(len(seen)) + ".png"))
            except Exception as error:
               item["capture_error"] = repr(error)
            item["dismissed_with"] = dismiss(self.app, handle, self.journal)
         time.sleep(0.3)
      return seen

   def try_value(self, tag, index, control, label, value, original):
      handle = control.handle
      context = "{}-{:02d}-{}".format(tag, index, label.split()[0])
      wrapper = HwndWrapper(handle)
      self.journal.perform("focus box " + context, wrapper.set_focus)
      red_before = self.red(context + "-before", self.content)
      if len(value) > 40:
         put_clipboard(value)
         keys = "{HOME}+{END}{DEL}^v"
      else:
         keys = "{HOME}+{END}{DEL}" + keys_for(value)
      self.journal.perform("enter " + label + " in " + context, lambda: wrapper.type_keys(keys, with_spaces=True, pause=0.01))
      # A password box (ES_PASSWORD) answers WM_GETTEXT with nothing across
      # processes, so its text cannot be read back: say so, never "refused".
      masked = bool(win32gui.GetWindowLong(handle, win32con.GWL_STYLE) & win32con.ES_PASSWORD)
      observation = {"typed": value, "masked": masked, "entered": EditWrapper(handle).window_text()}
      observation["windows_while_typing"] = self.windows(context + "-typing")
      self.journal.perform("leave " + context + " with Tab", lambda: wrapper.type_keys("{TAB}", pause=0.01))
      time.sleep(0.6)
      if self.crashed():
         observation["crashed"] = True
         return observation
      observation["hung"] = self.hung()
      modals = observation["windows_while_typing"] + self.windows(context + "-leaving")
      observation["modals"] = [item["class"] + " '" + item["title"] + "': " + item["text"] for item in modals]
      observation["window_details"] = modals
      if self.crashed():
         observation["crashed"] = True
         return observation
      if not win32gui.IsWindow(handle):
         observation["after"] = "<box gone>"
         return observation
      observation["focus_held"] = focus_info(self.prefs).get("handle") == handle
      observation["after"] = EditWrapper(handle).window_text()
      if observation["focus_held"]:
         wrapper.type_keys("{END}")
      left, top, right, bottom = win32gui.GetWindowRect(handle)
      observation["field_red"] = self.red(context + "-field", (left + 2, top + 2, right - 2, bottom - 2)) >= 5
      observation["red_before"] = red_before
      observation["red_after"] = self.red(context + "-after", self.content)
      # Put the original back (WM_SETTEXT, no Tab: nothing is judged).
      self.journal.perform("restore " + context, lambda: EditWrapper(handle).set_edit_text(original))
      observation["windows_after_restore"] = self.windows(context + "-restore")
      return observation

   def sweep_page(self, tag):
      boxes, skipped = self.boxes()
      page = {"tag": tag, "boxes": len(boxes), "skipped": skipped, "scrolled_into_view": 0,
         "not_reachable": 0}
      self.pages.append(page)
      if not boxes:
         return True
      self.journal.perform("capture page " + str(tag), lambda: capture(self.prefs, self.output / ("page-" + str(tag) + ".png")))
      for index, control in enumerate(boxes):
         below_fold = not self.inside(control)
         if not self.bring_into_view(control):
            page["not_reachable"] += 1
            continue
         if below_fold:
            page["scrolled_into_view"] += 1
         identity = self.name(control)
         self.caption_crop(tag, index, control)
         original = EditWrapper(control.handle).window_text()
         for label, value in SWEEP_VALUES:
            if time.monotonic() - self.started > TIME_BUDGET:
               self.stopped = "time budget reached on page " + str(tag)
               return False
            observation = self.try_value(tag, index, control, label, value, original)
            row = {"page": tag, "index": index, "control": identity, "value": label,
               "original": original, "behaviour": classify(observation), "observation": observation}
            self.rows.append(row)
            with self.rows_path.open("a", encoding="utf-8") as stream:
               stream.write(json.dumps(row, default=str) + "\n")
            if observation.get("crashed"):
               self.stopped = "crash on page " + str(tag)
               return False
            if observation.get("hung"):
               self.stopped = "hung on page " + str(tag)
               return False
            if not win32gui.IsWindow(control.handle):
               break
      return True

   def walk(self):
      """Every page, in tree order (Home, then Right and Down as the audit
      walks it); the page is the program's own '[Prefs] section tag=' line."""
      visited = set()

      def visit():
         time.sleep(0.15)
         page = current_page(self.log)
         if page is None:
            raise AssertionError("No selected-page diagnostic; pages cannot be identified")
         if page[0] not in visited:
            visited.add(page[0])
            tag = int(page[0])
            if tag != 1 and self.low <= tag <= self.high:
               if not self.sweep_page(tag):
                  return None
            self.tree.set_focus()
         return page[0]

      self.tree.set_focus()
      self.tree.type_keys("{HOME}", pause=0.03)
      if visit() is None:
         return
      for _ in range(150):
         before = current_page(self.log)
         self.tree.type_keys("{RIGHT}", pause=0.03)
         after_right = visit()
         if after_right is None:
            return
         self.tree.type_keys("{DOWN}", pause=0.03)
         after_down = visit()
         if after_down is None:
            return
         if before and before[0] == after_right == after_down:
            return
      raise AssertionError("Navigation walk exceeded its bounded limit")


def sweep(app, main, prefs, root, run_name, output, journal, phase):
   prefs.wait("visible enabled", timeout=10)
   run = Sweep(app, prefs, root, run_name, output, journal, phase)
   run.walk()
   summary = {"phase": phase, "tags": [run.low, run.high], "pages": run.pages, "rows": len(run.rows),
      "stopped": run.stopped, "seconds": round(time.monotonic() - run.started),
      "foreground_lost_before_capture": run.foreground_events}
   (output / "sweep-summary.json").write_text(json.dumps(summary, indent=3), encoding="utf-8")
   failures = []
   if run.stopped and ("crash" in run.stopped or "hung" in run.stopped):
      failures.append(run.stopped)
      return {"passed": False, "failures": failures, "rows": len(run.rows), "note": "Sweep stopped: " + run.stopped}
   journal.perform("Cancel: the sweep saves nothing", lambda: prefs.child_window(title="Cancel").click_input())
   prefs.wait_not("visible", timeout=10)
   run.read_captions(output)
   result = {"passed": True, "rows": len(run.rows), "pages": len(run.pages),
      "note": "REPORT: behaviours recorded, not asserted; table by sweep_report.py"}
   if run.stopped:
      result["incomplete"] = [run.stopped]
   return result
