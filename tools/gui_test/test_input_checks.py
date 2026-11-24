"""Portable checks of the input-validation helpers (no VM, no pywinauto)."""

import unittest

from PIL import Image, ImageDraw

from input_checks import (STATION_FIELDS, PRELOADED_BAD, choose_good, classify, keys_for, names_all,
   names_any, red_pixels, render_sweep, stored_matches)
from sweep_report import coverage_lines, page_names, table_rows


class StationFieldTable(unittest.TestCase):
   def test_every_checked_command_once(self):
      commands = [field["command"] for field in STATION_FIELDS]
      self.assertEqual(len(commands), len(set(commands)))
      self.assertEqual(set(commands), {"MY GRID", "MY ZONE", "MY ITU ZONE", "MY STATE", "MY SECTION",
         "MY COUNTRY", "MY CHECK", "MY PREC", "MY FD CLASS", "MY FOC NUMBER", "MY IOTA", "MY PARK",
         "MY LICENSE YEAR", "MY PREFECTURE", "MY POWER CLASS"})

   def test_nyai_values(self):
      by_command = {field["command"]: field for field in STATION_FIELDS}
      self.assertEqual(by_command["MY SECTION"]["bad"], "okh")
      self.assertIn("WCF", by_command["MY SECTION"]["goods"])
      self.assertEqual(by_command["MY PARK"]["bad"], "abcdedf")
      self.assertEqual(by_command["MY LICENSE YEAR"]["bad"], "alph")
      self.assertEqual(by_command["MY STATE"]["bad"], "AA")
      self.assertIn("FL", by_command["MY STATE"]["goods"])

   def test_reason_words_are_unique_to_their_field(self):
      for field in STATION_FIELDS:
         for other in STATION_FIELDS:
            if other is not field:
               self.assertNotEqual(field["words"][1].casefold(), other["words"][1].casefold())

   def test_preloaded_fields_are_on_the_page_in_order(self):
      keys = [field["key"] for field in STATION_FIELDS]
      positions = [keys.index(key) for key, _ in PRELOADED_BAD]
      self.assertEqual(positions, sorted(positions))

   def test_choose_good_skips_the_loaded_value(self):
      self.assertEqual(choose_good(("K", "VE"), "K"), "VE")
      self.assertEqual(choose_good(("K", "VE"), " k "), "VE")
      self.assertEqual(choose_good(("K", "VE"), ""), "K")
      with self.assertRaises(ValueError):
         choose_good(("K",), "K")


class Matching(unittest.TestCase):
   def test_ocr_spacing_and_case_do_not_matter(self):
      line = "Park: A park reference is letters, a hyphen and four or five digits: US-1234. Separate"
      self.assertTrue(names_all(line, ("park", "us1234")))
      self.assertTrue(names_all("CQ zone: A CQ zone is a number from 1 to 40.", ("cqzone", "1to40")))
      self.assertFalse(names_all(line, ("park", "1to40")))
      self.assertTrue(names_any("Station settings not saved. ARRL section: This is not an ARRL or RAC section",
         ("stationsettingsnotsaved",)))

   def test_keys_for_escapes_type_keys_commands(self):
      self.assertEqual(keys_for("a+b(c)"), "a{+}b{(}c{)}")
      self.assertEqual(keys_for("US-0001"), "US-0001")

   def test_stored_matches(self):
      self.assertTrue(stored_matches("ItuZone", 8, "8"))
      self.assertFalse(stored_matches("ItuZone", None, "8"))
      self.assertTrue(stored_matches("Section", "WCF", "wcf"))
      self.assertFalse(stored_matches("Park", "abcdedf", "US-0001"))


class RedPixels(unittest.TestCase):
   def test_red_text_counts_and_black_does_not(self):
      image = Image.new("RGB", (60, 20), (255, 255, 255))
      draw = ImageDraw.Draw(image)
      draw.text((2, 2), "ZZ99", fill=(0, 0, 0))
      self.assertEqual(red_pixels(image), 0)
      draw.text((30, 2), "ZZ", fill=(255, 0, 0))
      self.assertGreater(red_pixels(image), 5)

   def test_selection_blue_is_not_red(self):
      self.assertEqual(red_pixels(Image.new("RGB", (10, 10), (0, 120, 215))), 0)


class Classify(unittest.TestCase):
   def test_silent(self):
      self.assertEqual(classify({"typed": "abc", "entered": "abc", "after": "abc"}), ["accepted silently"])

   def test_crash_wins(self):
      self.assertEqual(classify({"crashed": True, "typed": "x"}), ["crashed"])

   def test_modal_and_inline(self):
      result = classify({"typed": "abc", "entered": "abc", "after": "abc", "modals": ["#32770 'TR4W': bad"],
         "focus_held": True})
      self.assertEqual(result[0], "modal box: #32770 'TR4W': bad")
      self.assertEqual(result[1], "marked inline (focus held)")

   def test_typing_filters(self):
      self.assertEqual(classify({"typed": "abc", "entered": "", "after": ""}),
         ["refused while typing (field stayed empty)"])
      self.assertEqual(classify({"typed": "X" * 300, "entered": "X" * 40, "after": "X" * 40}),
         ["cut to 40 chars while typing"])
      self.assertEqual(classify({"typed": "-999", "entered": "999", "after": "999"}),
         ["filtered while typing to '999'"])

   def test_number_only_balloon_is_not_a_modal(self):
      result = classify({"typed": "abc", "entered": "", "after": "",
         "window_details": [{"class": "SysShadow", "title": "", "text": ""}]})
      self.assertEqual(result, ["Windows number-only balloon", "refused while typing (field stayed empty)"])

   def test_password_box_is_not_called_refused(self):
      self.assertEqual(classify({"typed": "abc", "masked": True, "entered": "", "after": ""}),
         ["password box (value not readable)", "no window, no mark"])

   def test_changed_on_leaving(self):
      self.assertEqual(classify({"typed": "abc", "entered": "abc", "after": "0"}), ["changed on leaving to '0'"])

   def test_red_text_on_page(self):
      self.assertEqual(classify({"typed": "a", "entered": "a", "after": "a", "red_before": 0, "red_after": 40}),
         ["marked inline (red text appeared on page)"])


class Report(unittest.TestCase):
   def test_table_is_compact_and_escaped(self):
      rows = [{"page": 4, "index": 0, "control": {"uia_name": "", "help": "SCP MINIMUM | LETTERS", "rect": [1, 2, 3, 4]},
         "value": "letters", "behaviour": ["accepted silently"]},
         {"page": 4, "index": 1, "control": {"uia_name": "Port", "help": "", "rect": [1, 2, 3, 4]},
         "value": "300-char string", "behaviour": ["cut to 5 chars while typing"]}]
      text = render_sweep(table_rows(rows, {4: "SCP"}), "Sweep", ["One line."])
      self.assertIn("| 4 SCP | SCP MINIMUM \\| LETTERS | letters | accepted silently |", text)
      self.assertIn("| cut while typing | 1 |", text)
      self.assertEqual(text.count("\r\n| 4 SCP"), 2)

   def test_coverage_names_empty_pages_and_skips(self):
      lines = coverage_lines([{"tag": 5, "boxes": 0, "skipped": {"disabled": 2}},
         {"tag": 6, "boxes": 3, "skipped": {"disabled": 0}, "scrolled_into_view": 1, "not_reachable": 0}], {5: "UDP"})
      self.assertIn("5 UDP", lines[0])
      self.assertIn("disabled 2", lines[1])
      self.assertIn("scrolling into view: 1", lines[1])

   def test_page_names_come_from_the_tree(self):
      names = page_names()
      if names:
         self.assertEqual(names.get(1), "Station")


if __name__ == "__main__":
   unittest.main()
