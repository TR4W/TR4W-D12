"""Check actual Search Log filter choices, rendered calls and column persistence."""

import json
import time
from pywinauto.controls.win32_controls import ComboBoxWrapper
from pywinauto import mouse

from adif_fixtures import write_contacts
from bench_import import import_file
from session import select_menu, capture, close_normally, launch, describe_windows
from visual_assert import compare_images


def check(app, main, root, run_name, output, journal):
   directory = root / "runs" / run_name
   database = list(directory.glob("CWOPEN*.db"))[0]
   source = directory / "mixed-search.adi"
   write_contacts(source, mixed=True)
   import_file(app, main, source, database, output, journal)
   select_menu(main, ("Search log",), journal)
   search = app.window(title="Search Log")
   search.wait("visible enabled", timeout=10)

   def controls():
      combos = sorted([c for c in search.descendants(class_name="LCLComboBox") if c.is_visible()],
         key=lambda c: c.rectangle().left)
      if len(combos) != 3:
         raise AssertionError("Search must expose Mode, Band and Operator")
      query = min([c for c in search.descendants(class_name="Edit") if c.is_visible()], key=lambda c: c.rectangle().left)
      grids = [c for c in search.descendants(class_name="Window") if c.is_visible()
         and c.rectangle().width() > 700 and c.rectangle().height() > 150]
      if len(grids) != 1:
         raise RuntimeError("Search result grid not unique")
      return query, [ComboBoxWrapper(c.handle) for c in combos], grids[0]

   query, (mode, band, operator), grid = controls()
   choices = {"mode": [s.strip() for s in mode.item_texts()], "band": [s.strip() for s in band.item_texts()],
      "operator": [s.strip() for s in operator.item_texts()]}
   (output / "choices.json").write_text(json.dumps(choices, indent=3), encoding="utf-8")
   describe_windows(app, output)
   capture(search, output / "initial.png")
   if set(choices["mode"]) != {"All", "CW", "SSB"}:
      raise AssertionError("Mode filter does not match the two logged modes: " + repr(choices))
   if set(choices["band"]) != {"All", "80", "40", "20", "15"}:
      raise AssertionError("Band filter does not match the four logged bands: " + repr(choices))
   if any("NON" in value for value in choices["operator"]):
      raise AssertionError("Operator filter exposes NON")
   images = []

   def select_band(value):
      matches = [i for i, text in enumerate(band.item_texts()) if text.strip() == value]
      if len(matches) != 1:
         raise AssertionError("Band choice not unique: " + repr(band.item_texts()))
      band.select(matches[0])

   def snapshot(name):
      time.sleep(0.4)
      capture(search, output / (name + ".png"))
      rectangle = grid.rectangle()
      capture(search, output / (name + "-calls.png"), region=(rectangle.left + 256,
         rectangle.top + 21, rectangle.left + 354, rectangle.top + 141))
      capture(search, output / (name + "-bands.png"), region=(rectangle.left + 1,
         rectangle.top + 21, rectangle.left + 71, rectangle.top + 141))
      images.append(name)

   query.set_edit_text("GUI")
   snapshot("all")
   mode.select("CW")
   snapshot("cw")
   mode.select("SSB")
   snapshot("ssb")
   mode.select("All")
   select_band("80")
   snapshot("80m")
   query.set_edit_text("K6")
   time.sleep(0.3)
   if band.window_text().strip() != "All":
      raise AssertionError("Band did not fall back to All when the new calls have no 80 m contacts")
   select_band("20")
   query.set_edit_text("K6R")
   time.sleep(0.3)
   if band.window_text().strip() != "20":
      raise AssertionError("Band choice was lost while narrowing a matching callsign")
   snapshot("k6-20m")
   query.set_edit_text("K1")
   time.sleep(0.3)
   if band.window_text().strip() != "All":
      raise AssertionError("Band did not fall back to All for a call absent on 20 m")
   snapshot("k1-fallback")
   select_band("All")
   query.set_edit_text("")
   main.set_focus()
   main.type_keys("%b%b%b")
   from qso_entry import log_without_cw
   log_without_cw(main, "K3GUI", "11 BOB", journal)
   search.set_focus()
   time.sleep(0.5)
   if "10" not in [s.strip() for s in band.item_texts()]:
      raise AssertionError("Open Search did not learn the newly logged 10 m band")
   query.set_edit_text("GUI")
   snapshot("new-band")
   rectangle = grid.rectangle()
   start = (rectangle.left + 72, rectangle.top + 10)
   mouse.press(coords=start)
   mouse.move(coords=(start[0] + 35, start[1]), duration=0.4)
   mouse.release(coords=(start[0] + 35, start[1]))
   time.sleep(0.4)
   capture(search, output / "header-dragged.png", region=(rectangle.left + 1, rectangle.top + 1,
      rectangle.right - 18, rectangle.top + 20))
   search.post_message(0x0010)
   search.wait_not("visible", timeout=10)
   close_normally(app, main, journal)
   stored = json.loads((directory / "tr4w.json").read_text(encoding="utf-8-sig"))
   (output / "stored-columns.json").write_text(json.dumps(stored.get("columns"), indent=3), encoding="utf-8")
   if not stored.get("columns"):
      raise AssertionError("Search drag did not persist any column widths")
   app = launch(root, run_name, database.name)
   main = app.window(title_re=r"TR4W v.*CWOPEN.*")
   main.wait("visible enabled", timeout=30)
   select_menu(main, ("Search log",), journal)
   search = app.window(title="Search Log")
   search.wait("visible enabled", timeout=10)
   query, combos, grid = controls()
   rectangle = grid.rectangle()
   capture(search, output / "header-restarted.png", region=(rectangle.left + 1, rectangle.top + 1,
      rectangle.right - 18, rectangle.top + 20))
   compare_images(output / "header-restarted.png", output / "header-dragged.png", output / "header-diff.png")
   search.post_message(0x0010)
   search.wait_not("visible", timeout=10)
   failures = []
   for name in images:
      for region in ("calls", "bands"):
         try:
            filename = name + "-" + region
            compare_images(output / (filename + ".png"), directory / ("ui-baselines/search-" + filename + ".png"),
               output / (filename + "-diff.png"))
         except (RuntimeError, AssertionError) as error:
            failures.append(str(error))
   (output / "search-result.json").write_text(json.dumps({"choices": choices, "images": images,
      "failures": failures, "column_restart": True}, indent=3), encoding="utf-8")
   return {"passed": not failures, "failures": failures, "note": "Filter choices, rendered calls, live new band and dragged-column restart"}, app, main
