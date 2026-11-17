"""The taskbar-candidate rule bench_taskbar asserts with, without a desktop."""

import unittest

from bench_taskbar import is_taskbar_candidate, WS_EX_APPWINDOW, WS_EX_TOOLWINDOW


class TaskbarRuleTests(unittest.TestCase):
   def test_an_unowned_visible_window_has_a_button(self):
      self.assertTrue(is_taskbar_candidate(True, 0, 0))

   def test_an_owned_window_has_none(self):
      self.assertFalse(is_taskbar_candidate(True, 0x1234, 0))

   def test_a_tool_window_has_none(self):
      self.assertFalse(is_taskbar_candidate(True, 0, WS_EX_TOOLWINDOW))

   def test_appwindow_wins_over_owner_and_tool_style(self):
      self.assertTrue(is_taskbar_candidate(True, 0x1234, WS_EX_APPWINDOW | WS_EX_TOOLWINDOW))

   def test_a_hidden_window_has_none(self):
      self.assertFalse(is_taskbar_candidate(False, 0, WS_EX_APPWINDOW))


if __name__ == "__main__":
   unittest.main()
