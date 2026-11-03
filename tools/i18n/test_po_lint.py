"""po_lint.controls -- a line break is compared as a BREAK, not as its bytes.

Run:  python tools/i18n/test_po_lint.py        (exit 0 = pass)

WHY THIS EXISTS (2026-11-03). Eleven TC_ strings break their line with #13,
so pas2po wrote the C escape \\r into every catalogue. LazUtils' .po reader
cannot decode \\r (lazutf8.pas:1044 drops the backslash and keeps the letter,
so "willst\\rund" showed as "willstrund"), and Make-LanguageRes now rewrites
\\r as \\n in the shipped copy. A translation saying \\n where the English
says \\r is therefore the SAME break on screen, and po_lint must not call it a
defect -- while a translation that loses or adds a break still is one.

controls() feeds draft_defects(), which mt_seed asks before writing a machine
draft, so the rule pinned here gates the seeder too.
"""

import os
import sys
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import po_lint  # noqa: E402


class LineBreaks(unittest.TestCase):

   def same(self, english, translated):
      self.assertEqual(po_lint.controls(english), po_lint.controls(translated),
                       "%r and %r should hold the same breaks" % (english, translated))
      self.assertNotIn(po_lint.CONTROL_DEFECT,
                       po_lint.draft_defects(english, translated))

   def differ(self, english, translated):
      self.assertNotEqual(po_lint.controls(english), po_lint.controls(translated),
                          "%r and %r should NOT hold the same breaks" % (english, translated))
      self.assertIn(po_lint.CONTROL_DEFECT,
                    po_lint.draft_defects(english, translated))

   def test_cr_matches_lf(self):
      self.same("one\rtwo", "eins\nzwei")

   def test_crlf_is_one_break(self):
      self.same("one\rtwo", "eins\r\nzwei")
      self.same("one\r\ntwo", "eins\nzwei")

   def test_lfcr_is_one_break(self):
      self.same("one\n\rtwo", "eins\nzwei")

   def test_two_crs_are_two_breaks(self):
      self.differ("one\r\rtwo", "eins\nzwei")
      self.same("one\r\rtwo", "eins\n\nzwei")

   def test_a_lost_break_is_still_a_defect(self):
      self.differ("one\rtwo", "eins zwei")
      self.differ("one\rtwo", "einsrzwei")

   def test_an_added_break_is_still_a_defect(self):
      self.differ("one two", "eins\nzwei")

   def test_a_tab_is_still_compared(self):
      self.differ("one\ttwo", "eins zwei")
      self.differ("one\ttwo", "eins\nzwei")
      self.same("one\ttwo", "eins\tzwei")


if __name__ == "__main__":
   unittest.main()
