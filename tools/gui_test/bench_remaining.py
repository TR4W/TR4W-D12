"""Pending UI regression cases; inspection phases are not suite acceptance."""

from pathlib import Path
import json
import time
from pywinauto import mouse, Desktop, Application
import win32gui
from preferences_audit import select_page
from session import capture, describe_windows, hover_control


def inspect(app, prefs, root, run_name, output, journal):
   log = root / "runs" / run_name / "tr4w.log"
   for name, tag in (("online", 22), ("loggers", 17), ("radios", 26)):
      journal.perform("select observed " + name + " page", lambda: select_page(prefs, log, tag))
      directory = output / name
      directory.mkdir(exist_ok=True)
      capture(prefs, directory / "page.png")
      describe_windows(app, directory)
   prefs.child_window(title="Cancel").click_input()
   return {"passed": True, "status": "INSPECTED", "note": "Discovery only; excluded from regression acceptance"}


def inspect_main(app, main, output, journal, phase):
   from session import menu_paths, select_menu
   (output / "menu-paths.json").write_text(json.dumps(menu_paths(main), indent=3), encoding="utf-8")
   if phase.endswith("-dialogs-inspect"):
      for name, words in (("import", ("File", "Import", "ADIF")), ("search", ("Search log",))):
         select_menu(main, words, journal)
         time.sleep(0.7)
         dialog = app.top_window()
         if dialog.handle == main.handle:
            raise RuntimeError("Expected " + name + " dialog did not open")
         directory = output / name
         directory.mkdir(exist_ok=True)
         capture(dialog, directory / "dialog.png")
         describe_windows(app, directory)
         cancel = [c for c in dialog.descendants(class_name="Button") if c.is_visible()
            and c.window_text().replace("&", "") in {"Cancel", "Close"}]
         if len(cancel) == 1:
            cancel[0].click_input()
         else:
            dialog.post_message(0x0010)
         dialog.wait_not("visible", timeout=10)
   return {"passed": True, "status": "INSPECTED", "note": "Menu discovery only"}


def inspect_editors(app, prefs, root, run_name, output, journal):
   for name, tag in (("logger", 17), ("radio", 26)):
      select_page(prefs, root / "runs" / run_name / "tr4w.log", tag)
      prefs.child_window(title="Add...", class_name="Button").click_input()
      time.sleep(0.5)
      top = app.top_window()
      directory = output / name
      directory.mkdir(exist_ok=True)
      capture(top, directory / "editor.png")
      describe_windows(app, directory)
      buttons = [c for c in top.descendants(class_name="Button") if c.is_visible()
         and c.window_text().replace("&", "") == "Cancel"]
      if len(buttons) != 1:
         raise RuntimeError("Unknown editor; Cancel not unique")
      buttons[0].click_input()
      top.wait_not("visible", timeout=10)
   prefs.child_window(title="Cancel").click_input()
   return {"passed": True, "status": "INSPECTED", "note": "Editor discovery only"}


def inspect_hints(app, prefs, output, journal, validate=False):
   from bench_preferences import search_control
   observations = []
   # MY GRID is Preferences > Station > Grid square, issue 280.
   for term in ("CW TONE", "SAY HI ENABLE", "BAND MAP DECAY TIME", "ALWAYS CALL BLIND CQ", "MY GRID",
         "NO BORDER", "SHOW GRIDLINES"):
      control, observation = search_control(prefs, term, output, journal)
      bounds = prefs.rectangle()
      mouse.move(coords=(bounds.left + 10, bounds.top + 10))
      time.sleep(0.4)
      before = {w.handle for w in Desktop(backend="win32").windows() if w.is_visible()}
      rectangle = control.rectangle()
      hover_control(control)
      tips = []
      for _ in range(8):
         time.sleep(0.4)
         tips = [w for w in Desktop(backend="win32").windows() if w.is_visible() and w.handle not in before
            and "IME" not in w.class_name()]
         if tips:
            break
      observation["cursor"] = list(win32gui.GetCursorPos())
      observation["hints"] = [{"title": w.window_text(), "class": w.class_name(),
         "rect": [w.rectangle().left, w.rectangle().top, w.rectangle().right, w.rectangle().bottom]}
         for w in tips if w.class_name() == "HintWindow"]
      capture(prefs, output / (term.lower().replace(" ", "-") + "-hover.png"))
      mouse.move(coords=(bounds.left + 10, bounds.top + 10))
      time.sleep(0.4)
      observation["dismissed"] = all(not w.is_visible() for w in tips)
      observations.append(observation)
      (output / "hint-observations.json").write_text(json.dumps(observations, indent=3), encoding="utf-8")
   prefs.child_window(title="Cancel").click_input()
   if validate:
      failures = []
      words = {"CW TONE": ("pitch", "speaker"), "SAY HI ENABLE": ("names", "SAY HI ENABLE"),
         "BAND MAP DECAY TIME": ("minutes", "bandmap"), "ALWAYS CALL BLIND CQ": ("Sprint", " ..."),
         "MY GRID": ("Four- or six-character grid identifier",)}
      import win32api
      width, height = win32api.GetSystemMetrics(0), win32api.GetSystemMetrics(1)
      for item in observations:
         hints = item["hints"]
         if item["term"] not in words:
            if hints:
               failures.append(item["term"] + " unexpectedly shows a hint")
            continue
         if len(hints) != 1:
            failures.append(item["term"] + " has no unique actual tooltip")
            continue
         hint = hints[0]
         text = hint["title"]
         # The tooltip wraps its text; compare against it with the line breaks
         # folded so a phrase split across two lines still matches.
         flat = " ".join(text.split())
         if not all(word in flat for word in words[item["term"]]):
            failures.append(item["term"] + " shows incorrect help text")
         if max(map(len, text.splitlines()), default=0) > 70 or len(text.replace("\r\n", " ")) > 604:
            failures.append(item["term"] + " exceeds wrapping/length bounds")
         left, top, right, bottom = hint["rect"]
         if not (0 <= left < right <= width and 0 <= top < bottom <= height) or not item["dismissed"]:
            failures.append(item["term"] + " is off screen or does not dismiss")
      (output / "hint-result.json").write_text(json.dumps({"failures": failures,
         "controls_checked": len(observations)}, indent=3), encoding="utf-8")
      return {"passed": not failures, "failures": failures, "note": "Actual tooltip text, wrap, cap, bounds and dismissal asserted"}
   return {"passed": True, "status": "INSPECTED", "note": "Hover discovery only"}


def check_focus(app, prefs, root, run_name, output, journal):
   from preferences_audit import audit
   pages = audit(app, prefs, root / "runs" / run_name / "tr4w.log", output)
   failures = []
   observed = {int(page["tag"]) for page in pages}
   missing = set(range(1, 49)) - {30} - observed
   if missing or 30 in observed:
      failures.append({"page": "navigation", "reason": "missing pages or More settings returned", "missing": sorted(missing)})
   for page in pages:
      if page["invalid_focus"] or not page["reverse_matches_forward"] or page.get("forward_tab_limit_reached") or page.get("reverse_tab_limit_reached"):
         failures.append({"page": page["tag"], "reason": "focus cycle/visibility/reverse order"})
         continue
      cycle = page["forward_tab"]
      if len(cycle) < 4 or cycle[-2]["class"] != "Edit" or cycle[-1]["class"] != "Window":
         failures.append({"page": page["tag"], "reason": "search/tree cycle order"})
         continue
      body = cycle[:-2]
      body = [item for item in body if not (item["class"] == "Button" and item["text"] in {"Save and close", "Cancel", "Save"})]
      if page["tag"] == "1":
         # Reviewed versions have six contest fields, or seven with the new
         # separate License year field. Both retain the same two-column order.
         if len(body) not in {17, 18} or body[10]["rect"][0] <= body[0]["rect"][0] or body[-1]["rect"][1] <= body[9]["rect"][1]:
            failures.append({"page": "1", "reason": "Station column groups changed"})
         pairs = list(zip(body[:10], body[1:10])) + list(zip(body[10:-1], body[11:-1]))
      else:
         pairs = list(zip(body, body[1:]))
      for previous, current in pairs:
         x0, y0 = previous["rect"][:2]
         x1, y1 = current["rect"][:2]
         if y1 < y0 - 8 or abs(y1 - y0) <= 8 and x1 < x0 - 8:
            failures.append({"page": page["tag"], "reason": "not in reading order", "from": previous, "to": current})
   prefs.child_window(title="Cancel").click_input()
   (output / "focus-result.json").write_text(json.dumps({"pages": len(pages), "failures": failures}, indent=3), encoding="utf-8")
   return {"passed": not failures, "pages": len(pages), "failures": failures}
