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
      "F1 help", "Band 8", "No", "8 hours",
      "F25",                               # not a key: past F24
      "&Yes", "Dah 73% of normal duration",
      u"Нет",               # Cyrillic 'Net'
      u"取消",                     # CJK
      # Real words beside the named abbreviations, and sentences that
      # contain one: the list matches the WHOLE msgid only.
      "Band", "Mode", "Port", "Port:", "Zone", "CONTEST", "SPLIT", "INSERT",
      "QTH:", "CW speed", "Ok", "DX spot", "Load CTY.DAT",
      # Units and country names stay translatable on purpose (NY4I,
      # 2026-11-02): Russian writes 'мс', and UK and CIS are translated.
      "m", "s", " ms", "Hz", "UK", "CIS",
   ]

   # THE NAMED LIST, pinned as NY4I approved it on 2026-11-02. Adding a name
   # is a decision: make it here and in pofile.INVARIANT_NAMES together.
   NAMED = ["OK", "QTH", "DX", "CW", "PTT", "RIT", "XIT", "WPM", "SCP",
            "CTY.DAT", "TR4W", "MMTTY", "LPT", "SH/50", "X-QSO", "IOTA",
            "IOTA:", "INH", "S&P"]

   def test_not_language(self):
      for text in self.NOT_LANGUAGE:
         self.assertFalse(pofile.is_translatable(text),
                          "%r is not language, but was offered" % text)

   def test_language(self):
      for text in self.LANGUAGE:
         self.assertTrue(pofile.is_translatable(text),
                         "%r is language, but was refused" % text)

   def test_the_named_list_is_exactly_what_was_approved(self):
      self.assertEqual(sorted(pofile.INVARIANT_NAMES), sorted(self.NAMED))

   def test_every_named_abbreviation_is_not_language(self):
      for text in self.NAMED + ["&OK", " OK ", "&TR4W", "MM&TTY"]:
         self.assertFalse(pofile.is_translatable(text),
                          "%r is a named abbreviation, but was offered" % text)


def kept_for_review(e):
   """A REVIEWED translation that differs from the English is never removed
   by a tool, even of a msgid that is not language: mn and ro wrote their own
   SCP, Polish 'SH / 50'. po_merge keeps such an entry and prints it; NY4I
   decides (2026-11-02). Anything else not language fails the test below."""
   return ((not e.fuzzy) and e.target.strip()
           and e.target.strip() != e.source.strip())


class RealCatalogues(unittest.TestCase):

   def test_there_are_catalogues(self):
      # A floor, so the check cannot pass by finding nothing.
      self.assertGreaterEqual(len(CATALOGUES), 21, "found %d" % len(CATALOGUES))

   def test_no_catalogue_holds_an_entry_that_is_not_language(self):
      found = []
      for path in CATALOGUES:
         for e in pofile.read_po(path):
            if (not e.obsolete and not pofile.is_translatable(e.source)
                  and not kept_for_review(e)):
               found.append("%s: %r" % (os.path.basename(path), e.source))
      self.assertEqual(found, [])

   def test_there_is_no_english_catalogue(self):
      # English is the msgid; the program loads no catalogue for it.
      self.assertFalse(os.path.exists(os.path.join(REPO, "i18n", "tr4w_en.po")))


if __name__ == "__main__":
   unittest.main()
