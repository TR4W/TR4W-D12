"""Observe QSO-party form behavior using visible controls and isolated inputs."""

import json
from contextlib import closing
import sqlite3
from pywinauto.controls.win32_controls import ComboBoxWrapper, ListBoxWrapper
from pywinauto.timings import wait_until

from contest_forms import choose_contest, set_field, dismiss_grid_prompt
from session import capture, close_normally


def inspect(app, startup, output, journal):
   observations = []
   for name in ("Florida QSO Party", "Texas QSO Party", "Colorado QSO Party"):
      choose_contest(startup, name, journal)
      slug = name.split()[0].lower()

      def observe(state):
         capture(startup, output / (slug + "-" + state + ".png"))
         observations.append({"contest": name, "state": state, "controls": [
            {"class": control.class_name(), "text": control.window_text(),
             "enabled": control.is_enabled(), "rect": str(control.rectangle())}
            for control in startup.descendants() if control.is_visible()]})

      observe("initial")
      boxes = [control for control in startup.descendants(class_name="Button")
         if control.is_visible() and "I am in" in control.window_text().replace("&", "")]
      if len(boxes) == 1:
         journal.perform("toggle in-state for " + name, boxes[0].click_input)
         observe("toggled")
         boxes[0].click_input()
   (output / "county-observations.json").write_text(json.dumps(observations, indent=3), encoding="utf-8")
   startup.child_window(title="Cancel").click_input()
   app.wait_for_process_exit(timeout=20)
   return {"passed": True, "note": "Discovery captures only; no county requirements accepted yet"}


def in_state_box(startup):
   matches = [control for control in startup.descendants(class_name="Button")
      if control.is_visible() and "I am in" in control.window_text().replace("&", "")]
   if len(matches) != 1:
      raise AssertionError("In-state checkbox is not unique")
   return matches[0]


def county_combo(startup):
   controls = [control for control in startup.descendants(class_name="LCLComboBox") if control.is_visible()]
   return ComboBoxWrapper(min(controls, key=lambda control: control.rectangle().top).handle)


def tick_in_state(startup, area, output):
   # Wait for the selected party's own caption: the form is rebuilt per contest.
   wait_until(5, 0.1, lambda: area in in_state_box(startup).window_text())
   capture(startup, output / (area.lower() + "-before-checkbox.png"))
   if in_state_box(startup).get_check_state() != 1:
      in_state_box(startup).click_input()
   wait_until(3, 0.1, lambda: in_state_box(startup).get_check_state() == 1)


def pick_county(app, startup, ok, area, code, journal):
   """Physically click county CODE in the in-state list; the OK button must enable."""
   listing = county_combo(startup)
   items = listing.item_texts()
   matches = [index for index, text in enumerate(items) if text.split(" - ")[0] == code]
   if len(matches) != 1:
      raise AssertionError("County code is not unique: " + code)
   index = matches[0]
   listing.click_input(coords=(listing.rectangle().width() - 10, 10))
   popup = app.window(class_name="ComboLBox", visible_only=True)
   popup.wait("visible", timeout=3)
   native = ListBoxWrapper(popup.handle)
   # Scroll (not select) the item into the popup's view first: an item below
   # the visible rows has a rectangle outside the list, and a click there
   # closes the popup without choosing anything (KY SCO, WV MIN).
   import win32gui
   win32gui.SendMessage(popup.handle, 0x0197, index, 0)
   rectangle = native.item_rect(index)
   inside = native.client_rect()
   if not (0 <= rectangle.top and rectangle.bottom <= inside.bottom):
      raise RuntimeError("County " + code + " is not inside the visible popup after scrolling")
   journal.perform("physically click " + area + " " + code + " county", lambda: native.click_input(
      coords=(rectangle.left + 15, (rectangle.top + rectangle.bottom) // 2)))
   wait_until(3, 0.1, ok.is_enabled)
   if listing.window_text().split(" - ")[0] != code:
      raise AssertionError("Physical click selected a different county: " + listing.window_text())
   return items


def check(app, startup, root, run_name, output, journal, phase):
   results = {}

   def box():
      return in_state_box(startup)

   def county():
      return county_combo(startup)

   def in_state(area):
      tick_in_state(startup, area, output)

   state = choose_contest(startup, "Florida QSO Party", journal)[0]
   ok = startup.child_window(title_re="&?OK", class_name="Button")
   results["florida_states"] = []
   for value, accepted in (("GA", True), ("XX", False), ("ALC", False), ("FL", False), ("DX", True), ("ON", True)):
      set_field(state, value, journal)
      wait_until(3, 0.1, lambda: ok.is_enabled() == accepted)
      capture(startup, output / ("florida-" + value + ".png"))
      results["florida_states"].append({"value": value, "accepted": accepted})
   fields = choose_contest(startup, "Colorado QSO Party", journal)
   if len(fields) != 2:
      raise AssertionError("Colorado state/name fields not unique")
   set_field(fields[1], "TOM", journal)
   for _ in range(2):
      box().click_input()
      wait_until(3, 0.1, lambda: any(control.is_visible() and control.window_text() == "TOM"
         for control in startup.descendants(class_name="Edit")))
   capture(startup, output / "colorado-name-retained.png")
   results["colorado_name_retained"] = True
   results["unchanged_parties"] = []
   for name in ("British Columbia QSO Party", "Ontario QSO Party", "Quebec QSO Party",
      "Combined Indiana, 7th Call Area, New England and Delaware QSO Party"):
      choose_contest(startup, name, journal)
      capture(startup, output / (name.split()[0].lower() + "-unchanged.png"))
      if any(control.is_visible() and "I am in" in control.window_text()
         for control in startup.descendants(class_name="Button")):
         raise AssertionError("Unexpected in-state checkbox for " + name)
      results["unchanged_parties"].append(name)
   state = choose_contest(startup, "7th Call Area QSO Party", journal)[0]
   for value, accepted in (("AZ", False), ("CA", True)):
      set_field(state, value, journal)
      wait_until(3, 0.1, lambda: ok.is_enabled() == accepted)
      capture(startup, output / ("7qp-" + value + ".png"))
   in_state("7th area")
   results["7qp_counties"] = county().item_texts()
   if "AZAPH" not in results["7qp_counties"]:
      raise AssertionError("7QP county AZAPH absent")
   capture(startup, output / "7qp-county.png")
   choose_contest(startup, "Texas QSO Party", journal)
   in_state("TX")
   listing = county()
   items = listing.item_texts()
   results["texas_counties"] = items
   if not any("ANDE" in item and "Anderson" in item for item in items):
      raise AssertionError("Texas named county ANDE - Anderson absent")
   capture(startup, output / "texas-county.png")
   texas = phase == "bench-county-texas"
   area, code, slug = ("TX", "ANDE", "texas") if texas else ("FL", "ALC", "florida")
   choose_contest(startup, "Texas QSO Party" if texas else "Florida QSO Party", journal)
   in_state(area)
   if ok.is_enabled():
      raise AssertionError("Florida OK enabled before choosing county")
   pick_county(app, startup, ok, area, code, journal)
   capture(startup, output / (slug + "-county-selected.png"))
   ok.click_input()
   main = app.window(title_re=r"TR4W v.*")
   main.wait("visible enabled", timeout=30)
   dismiss_grid_prompt(app, journal)
   capture(main, output / (slug + "-created.png"))
   close_normally(app, main, journal)
   databases = list((root / "runs" / run_name).glob("*.db"))
   if len(databases) != 1:
      raise AssertionError("Florida database is not unique")
   with closing(sqlite3.connect(databases[0].resolve().as_uri() + "?mode=ro", uri=True)) as connection:
      rows = connection.execute("SELECT command,value FROM config WHERE command='MY STATE'").fetchall()
   if rows != [("MY STATE", code)]:
      raise AssertionError("County was not stored as " + code + ": " + repr(rows))
   results[slug + "_saved"] = rows
   (output / "county-result.json").write_text(json.dumps(results, indent=3), encoding="utf-8")
   return {"passed": True, "note": "County validation and saved " + slug + " county passed; screenshots require review"}
