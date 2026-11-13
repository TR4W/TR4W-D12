"""Issue 317: an in-state QSO-party entrant's first host-state county also earns the state.

One phase per party (bench-countyhost-<ky|al|wv|vt|fl>), each on a fresh
fixture: New Contest, tick the in-state box, physically pick our county, then
log through the normal fields with Ctrl+Enter (no CW) on 40 m CW: a station
outside the state, then a host-state county. The visible totals are recorded
after every QSO, and every Windows > Mults entry is opened and captured. The
score after each QSO is ASSERTED (see PARTIES): CW points times domestic
multipliers separates "county AND host state" (3 mults) from "county only"
(2). The host state shown worked on the Mults list is a reviewed capture.
"""

import json
import re
import time

from pywinauto import Application

from contest_forms import choose_contest, dismiss_grid_prompt
from bench_county import tick_in_state, pick_county
from bench_year_sent import select_band_mode, database_of
from session import capture, close_normally, describe_windows
from qso_entry import log_without_cw
from fixture_data import contacts

# name, host area (the in-state caption), our county, QSOs (call, received
# exchange), and the score shown after each QSO. After the county QSO the score
# is CW points x domestic mults: 3 mults (outside state + county + host state)
# gives 12 (2-point CW) or 18 (VT, 3-point CW); county only would give 8 or 12.
# Florida gives no host-state multiplier (sponsor), so 2 x 4 = 8.
PARTIES = {
   "ky": ("Kentucky QSO Party", "KY", "SCO", (("W1AW", "599 CT"), ("K4AAA", "599 FAY")), ("2 Pts", "12 Pts")),
   "al": ("Alabama QSO Party", "AL", "BALD", (("W1AW", "599 CT"), ("K4AAA", "599 AUTA")), ("2 Pts", "12 Pts")),
   "wv": ("West Virginia QSO Party", "WV", "MIN", (("W1AW", "599 CT"), ("K8AAA", "599 BAR")), ("2 Pts", "12 Pts")),
   "vt": ("Vermont QSO Party", "VT", "CHI", (("W1AW", "599 CT"), ("W1ADD", "599 ADD")), ("3 Pts", "18 Pts")),
   "fl": ("Florida QSO Party", "FL", "ALC", (("W7SP", "599 UT"), ("W4AFC", "599 PIN")), ("2 Pts", "8 Pts")),
}


def visible_texts(window):
   return [control.window_text() for control in window.descendants()
      if control.is_visible() and control.window_text().strip()]


def uia_texts(app, window):
   uiapp = Application(backend="uia").connect(process=app.process)
   result = []
   for control in uiapp.window(handle=window.handle).descendants():
      name = control.element_info.element.CurrentName
      if name and name.strip():
         result.append({"type": control.element_info.control_type, "name": name})
   return result


def open_multiplier_windows(app, main, output, journal):
   submenu = main.menu().get_menu_path("Windows->Mults")[-1].sub_menu()
   entries = [item.text() for item in submenu.items() if item.text() and item.text() != "-"]
   seen = []
   for entry in entries:
      title = entry.split("\t")[0].replace("&", "")
      journal.perform("open Windows > Mults > " + title, lambda: main.menu_select("Windows->Mults->" + entry))
      time.sleep(1)
      windows = [window for window in app.windows() if window.is_visible() and window.window_text() == title]
      record = {"entry": entry, "title": title, "windows": len(windows)}
      if len(windows) == 1:
         slug = re.sub(r"[^a-z0-9]+", "-", title.lower()).strip("-") or "mults"
         capture(windows[0], output / ("mults-" + slug + ".png"))
         record["texts"] = visible_texts(windows[0])
         record["uia"] = uia_texts(app, windows[0])
         if title == "Domestic":
            # The list scrolls sideways; page right so every key, the host
            # state's included, is in some reviewed capture.
            uiapp = Application(backend="uia").connect(process=app.process)
            pages = 0
            for page in range(1, 9):
               buttons = [control for control in uiapp.window(handle=windows[0].handle).descendants(control_type="Button")
                  if control.element_info.element.CurrentName == "Page right"]
               if len(buttons) != 1:
                  break
               journal.perform("page the Domestic list right", buttons[0].invoke)
               time.sleep(0.3)
               capture(windows[0], output / ("mults-domestic-page-" + str(page) + ".png"))
               pages = page
            record["pages_captured"] = pages
         windows[0].post_message(0x0010)
         time.sleep(0.5)
      seen.append(record)
   return entries, seen


def check(app, startup, root, run_name, output, journal, phase):
   slug = phase.rsplit("-", 1)[1]
   name, area, my_county, qsos, scores = PARTIES[slug]
   if list((root / "runs" / run_name).glob("*.db")):
      raise RuntimeError("County-host checks require a fresh fixture")
   facts = {"party": name, "my_county": my_county, "qsos": []}
   fields = choose_contest(startup, name, journal)
   facts["setup_fields"] = [field.window_text() for field in fields]
   tick_in_state(startup, area, output)
   ok = startup.child_window(title_re="&?OK", class_name="Button")
   facts["county_items"] = len(pick_county(app, startup, ok, area, my_county, journal))
   capture(startup, output / "setup-in-state.png")
   journal.perform("create the in-state log", ok.click_input)
   main = app.window(title_re=r"TR4W v.*")
   main.wait("visible enabled", timeout=30)
   dismiss_grid_prompt(app, journal)
   facts["title"] = main.window_text()
   facts["band_mode"] = select_band_mode(main, "40", "CW", journal)
   capture(main, output / "empty.png")
   facts["totals_empty"] = visible_texts(main)
   for index, (call, exchange) in enumerate(qsos, 1):
      log_without_cw(main, call, exchange, journal)
      time.sleep(0.5)
      capture(main, output / ("after-qso-" + str(index) + ".png"))
      facts["qsos"].append({"call": call, "exchange": exchange, "totals_after": visible_texts(main),
         "uia_after": uia_texts(app, main)})
   facts["mults_menu"], facts["mults_windows"] = open_multiplier_windows(app, main, output, journal)
   describe_windows(app, output)
   close_normally(app, main, journal)
   rows = contacts(database_of(root, run_name))
   facts["logged_rows"] = rows
   failures = []
   if len(rows) != len(qsos):
      failures.append("Expected " + str(len(qsos)) + " logged QSOs, found " + str(len(rows)))
   facts["points_texts"] = [text for text in facts["qsos"][-1]["totals_after"] if re.search(r"\bPts\b", text)]
   for qso, expected in zip(facts["qsos"], scores):
      shown = [text for text in qso["totals_after"] if re.search(r"\bPts\b", text)]
      qso["score_shown"] = shown
      if shown != [expected]:
         failures.append("After " + qso["call"] + " the score reads " + repr(shown) + ", expected " + expected)
   (output / "county-host-result.json").write_text(json.dumps(facts, indent=3, default=str), encoding="utf-8")
   return {"passed": not failures, "failures": failures, "points_texts": facts["points_texts"],
      "note": "QSOs logged; multiplier verdict from recorded totals and reviewed captures"}
