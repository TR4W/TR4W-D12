"""pofile.is_translatable -- which English is LANGUAGE, and so a catalogue entry.

Run:  python tools/i18n/test_is_translatable.py        (exit 0 = pass)

WHY THIS EXISTS. The .lfm harvest took every Caption, and 21 of them were not
language: the function-key panel's 'F1'..'F12', the radio editor's '7'/'8'
data bits and '1'/'2' stop bits, the panadapter's '-'/'+', a '--' and a '...'
and the server-log counters' '0'. They sat in every catalogue, and Weblate
asked translators to translate '8' (NY4I, 2026-10-21).

THE RULE IT PINS, in both directions: a function-key name, a bare number or
bare punctuation is NOT language; anything carrying a letter IS, even beside
digits -- 'F1 help' and '8 hours' are sentences a translator may reorder.

AND THAT NO CATALOGUE HOLDS ONE. The predicate is asked by po_merge (it never
adds such an entry and drops an empty one) and by po_lint; this checks the
files themselves, so an entry that arrived some other way fails here too.
"""

import glob
import os
import sys
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))
sys.path.insert(0, HERE)
import pofile  # noqa: E402

CATALOGUES = sorted(glob.glob(os.path.join(REPO, "i18n", "tr4w_*.po")))


class Predicate(unittest.TestCase):

   NOT_LANGUAGE = [
      "F1", "&F12", "F&1", "F24",          # function-key names
      "8", "10", "0",                      # bare numbers
      "-", "+", "--", "...", " ", "",      # punctuation and whitespace
   ]

   LANGUAGE = [
      "F1 help", "Band 8", "OK", "No", "8 hours",
      "F25",                               # not a key: past F24
      "&Yes", "Dah 73% of normal duration",
      u"Нет",               # Cyrillic 'Net'
      u"取消",                     # CJK
   ]

   def test_not_language(self):
      for text in self.NOT_LANGUAGE:
         self.assertFalse(pofile.is_translatable(text),
                          "%r is not language, but was offered" % text)

   def test_language(self):
      for text in self.LANGUAGE:
         self.assertTrue(pofile.is_translatable(text),
                         "%r is language, but was refused" % text)


class RealCatalogues(unittest.TestCase):

   def test_there_are_catalogues(self):
      # A floor, so the check cannot pass by finding nothing.
      self.assertGreaterEqual(len(CATALOGUES), 21, "found %d" % len(CATALOGUES))

   def test_no_catalogue_holds_an_entry_that_is_not_language(self):
      found = []
      for path in CATALOGUES:
         for e in pofile.read_po(path):
            if not e.obsolete and not pofile.is_translatable(e.source):
               found.append("%s: %r" % (os.path.basename(path), e.source))
      self.assertEqual(found, [])

   def test_there_is_no_english_catalogue(self):
      # English is the msgid; the program loads no catalogue for it.
      self.assertFalse(os.path.exists(os.path.join(REPO, "i18n", "tr4w_en.po")))


if __name__ == "__main__":
   unittest.main()
