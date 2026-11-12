"""Protect queue triage from losing multiline requirements or checkbox state."""

import unittest

from bench_queue import index_queue


class QueueTests(unittest.TestCase):
   def test_nested_items_keep_scope_and_multiline_requirements(self):
      text = "# Queue\n## Layout\n- [ ] Main window\n  at 150% on Windows and Linux.\n  - [ ] Child check\n## Hardware\n- [x] K4 done\n- [-] Retired\n"
      items = index_queue(text)
      self.assertEqual(len(items), 4)
      self.assertEqual(items[0]["section"], "Layout")
      self.assertIn("150% on Windows and Linux", items[0]["text"])
      self.assertEqual([item["state"] for item in items], [" ", " ", "x", "-"])
      self.assertNotIn("Hardware", items[1]["text"])

   def test_line_movement_does_not_change_content_identity(self):
      text = "# Queue\n## Form\n- [ ] Enter a name\n  Save and reopen.\n"
      original = index_queue(text)[0]
      shifted = index_queue("\n\n" + text)[0]
      self.assertEqual(original["id"], shifted["id"])
      self.assertEqual(original["line"] + 2, shifted["line"])


if __name__ == "__main__":
   unittest.main()
