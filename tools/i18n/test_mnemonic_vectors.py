"""The shared mnemonic vectors, run through mt_seed.place_accelerator.

Run:  python tools/i18n/test_mnemonic_vectors.py        (exit 0 = pass)

tr4w/test/unit/fixtures/mnemonic_vectors.txt is read by two implementations
of one placement rule: uMnemonics.AssignMnemonics in Pascal (uTestMnemonics)
and mt_seed.place_accelerator here. Copies drift; this is what makes a drift
fail instead of ship. The file's header describes its rows.

Only the 'place' rows apply to mt_seed -- one caption, nothing reserved, and
the English letter present in the translation. The 'set' rows describe a
whole form, which mt_seed never sees, and are Pascal's alone; they are parsed
here only so a malformed file fails in both suites.
"""

import os
import sys
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import mt_seed  # noqa: E402
import po_lint  # noqa: E402

VECTORS = os.path.join(HERE, "..", "..", "tr4w", "test", "unit", "fixtures",
                       "mnemonic_vectors.txt")


def has_cjk(text):
   """The Pascal rule (uMnemonics.IsCJKChar): Han, kana or Hangul."""
   ranges = ((0x1100, 0x11FF), (0x2E80, 0x2FDF), (0x3040, 0x30FF),
             (0x3100, 0x318F), (0x3400, 0x4DBF), (0x4E00, 0x9FFF),
             (0xAC00, 0xD7AF), (0xF900, 0xFAFF), (0xFF66, 0xFF9F))
   return any(lo <= ord(ch) <= hi for ch in text for lo, hi in ranges)


def read_rows():
   rows = []
   with open(VECTORS, encoding="utf-8") as f:
      for number, line in enumerate(f, 1):
         line = line.rstrip("\r\n")
         if not line or line.startswith("#"):
            continue
         rows.append((number, line.split("|")))
   return rows


class SharedVectors(unittest.TestCase):

   def test_the_file_is_well_formed(self):
      in_set = False
      kinds = {"place": 5, "set": 3, "item": 4, "end": 1}
      for number, f in read_rows():
         self.assertIn(f[0], kinds, "line %d: unknown row kind" % number)
         self.assertEqual(len(f), kinds[f[0]], "line %d: field count" % number)
         if f[0] == "set":
            self.assertFalse(in_set, "line %d: set inside a set" % number)
            in_set = True
         elif f[0] == "item":
            self.assertTrue(in_set, "line %d: item outside a set" % number)
         elif f[0] == "end":
            self.assertTrue(in_set, "line %d: end outside a set" % number)
            in_set = False
      self.assertFalse(in_set, "the last set has no end line")

   def test_place_rows_agree_with_mt_seed(self):
      count = 0
      for number, f in read_rows():
         if f[0] != "place":
            continue
         _, lang, letter, caption, expected = f
         # The row's own preconditions, so a row that only ONE side can
         # honour is refused rather than quietly passing on the other.
         self.assertEqual(po_lint.lone_ampersands(caption), 0,
                          "line %d: a place caption carries no marker" % number)
         cjk_lang = lang.split("-")[0].split("_")[0].lower() in \
            mt_seed.SUFFIX_ACCELERATOR_LANGS
         self.assertEqual(cjk_lang, has_cjk(caption),
                          "line %d: the language and the script disagree" % number)
         self.assertEqual(mt_seed.place_accelerator(caption, letter, lang),
                          expected, "line %d" % number)
         count += 1
      self.assertGreaterEqual(count, 10, "the file should hold 10+ place rows")


if __name__ == "__main__":
   unittest.main()
