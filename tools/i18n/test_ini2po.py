"""ini2po -- what a re-run must KEEP when it brings a help catalogue up to date.

Run:  python tools/i18n/test_ini2po.py        (exit 0 = pass)

WHY THIS EXISTS. emit() used to rebuild every help_<code>.po from the inis
alone. On 2026-11-02, the first run after the tooltips shipped, that would have
wiped 552 machine drafts held only in the .po files and defuzzed 25 entries a
reviewer had sent back on purpose. The .po is the master now and the inis only
seed it; these tests pin the merge rules in ini2po._merge.

Nothing under the repository is written: every catalogue is a temp file.
"""

import os
import shutil
import sys
import tempfile
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import ini2po      # noqa: E402
import pasconsts as pc  # noqa: E402
import pofile      # noqa: E402

TODAY = "2026-11-02"

# Four entries, CRLF, in the shape ini2po writes.
FIXTURE = (
   'msgid ""\r\n'
   'msgstr ""\r\n'
   '"Content-Type: text/plain; charset=UTF-8\\n"\r\n'
   '"Language: de\\n"\r\n'
   '\r\n'
   '#. Config command: KEEP ME\r\n'
   'msgctxt "TC_HELP_KEEP_ME"\r\n'
   'msgid "Unchanged English."\r\n'
   'msgstr "Unveraendert."\r\n'
   '\r\n'
   '#. Config command: DRAFT\r\n'
   '#, fuzzy\r\n'
   'msgctxt "TC_HELP_DRAFT"\r\n'
   'msgid "A machine draft."\r\n'
   'msgstr "Ein Maschinenentwurf."\r\n'
   '\r\n'
   '#. ACCELERATOR: a reviewer note that must survive.\r\n'
   '#. Config command: SENT BACK\r\n'
   '#, fuzzy\r\n'
   'msgctxt "TC_HELP_SENT_BACK"\r\n'
   'msgid "S&P mode."\r\n'
   'msgstr "S&P-Modus."\r\n'
   '\r\n'
   '#. Config command: REVIEWED\r\n'
   'msgctxt "TC_HELP_REVIEWED"\r\n'
   'msgid "Old English."\r\n'
   'msgstr "Altes Deutsch."\r\n'
   '\r\n'
   '#. Config command: REWORDED DRAFT\r\n'
   '#, fuzzy\r\n'
   'msgctxt "TC_HELP_REWORDED_DRAFT"\r\n'
   'msgid "Moved text."\r\n'
   'msgstr "Verschobener Text."\r\n'
   '\r\n'
   '#. Config command: GONE\r\n'
   'msgctxt "TC_HELP_GONE"\r\n'
   'msgid "Removed from the English."\r\n'
   'msgstr "Entfernt."\r\n'
)


def read_bytes(path):
   with open(path, "rb") as fh:
      return fh.read()


def entries_by_key(path):
   return {e.key: e for e in pofile.read_po(path)}


class MergeTests(unittest.TestCase):

   @classmethod
   def setUpClass(cls):
      pc.load_language_registry(os.path.join(os.path.dirname(HERE), "..", "i18n"))

   def setUp(self):
      self.dir = tempfile.mkdtemp()
      self.path = os.path.join(self.dir, "help_de.po")
      with open(self.path, "wb") as fh:
         fh.write(FIXTURE.encode("utf-8"))

   def tearDown(self):
      shutil.rmtree(self.dir)

   def run_emit(self, english, ini=None, lang="GER"):
      return ini2po.emit(english, ini or {}, lang, self.path, today=TODAY)

   # The English the fixture was built from, unchanged except where a test
   # says so.
   ENGLISH = [
      ("KEEP ME", "", "Unchanged English."),
      ("DRAFT", "", "A machine draft."),
      ("SENT BACK", "", "S&P mode."),
      ("REVIEWED", "", "Old English."),
      ("REWORDED DRAFT", "", "Moved text."),
      ("GONE", "", "Removed from the English."),
   ]

   def test_no_change_is_byte_identical(self):
      before = read_bytes(self.path)
      self.run_emit(self.ENGLISH, {"SENT BACK": "S&P-Modus."})
      self.assertEqual(read_bytes(self.path), before)

   def test_machine_draft_survives_an_ini_without_it(self):
      self.run_emit(self.ENGLISH)
      e = entries_by_key(self.path)["TC_HELP_DRAFT"]
      self.assertEqual(e.target, "Ein Maschinenentwurf.")
      self.assertTrue(e.fuzzy)

   def test_fuzzy_is_never_cleared_by_ini_text(self):
      # The ini holds a real translation of this entry; the .po's fuzzy flag
      # is a reviewer's decision and stays.
      self.run_emit(self.ENGLISH, {"SENT BACK": "S&P-Modus."})
      self.assertTrue(entries_by_key(self.path)["TC_HELP_SENT_BACK"].fuzzy)

   def test_other_notes_survive_a_changed_default(self):
      english = [x if x[0] != "SENT BACK" else ("SENT BACK", "FALSE", x[2])
                 for x in self.ENGLISH]
      self.run_emit(english)
      self.assertEqual(entries_by_key(self.path)["TC_HELP_SENT_BACK"].notes,
                       ["ACCELERATOR: a reviewer note that must survive.",
                        "Config command: SENT BACK   (default: FALSE)"])

   def test_reworded_reviewed_translation_is_kept_and_fuzzied(self):
      english = [x if x[0] != "REVIEWED" else ("REVIEWED", "", "New English.")
                 for x in self.ENGLISH]
      report = self.run_emit(english)
      e = entries_by_key(self.path)["TC_HELP_REVIEWED"]
      self.assertEqual(e.source, "New English.")
      self.assertEqual(e.target, "Altes Deutsch.")
      self.assertTrue(e.fuzzy)
      self.assertEqual(e.previous, ['#| msgid "Old English."'])
      self.assertTrue(any(TODAY in c for c in e.comments))
      self.assertEqual(report["reworded-kept"], ["TC_HELP_REVIEWED"])

   def test_reworded_machine_draft_is_cleared(self):
      english = [x if x[0] != "REWORDED DRAFT"
                 else ("REWORDED DRAFT", "", "Different text.")
                 for x in self.ENGLISH]
      report = self.run_emit(english)
      e = entries_by_key(self.path)["TC_HELP_REWORDED_DRAFT"]
      self.assertEqual(e.source, "Different text.")
      self.assertEqual(e.target, "")
      self.assertTrue(e.fuzzy)
      self.assertEqual(report["reworded-cleared"], ["TC_HELP_REWORDED_DRAFT"])

   def test_new_key_takes_the_text_whose_old_english_it_is(self):
      # 'Moved text.' moves to a new command; its translation follows it.
      english = [x if x[0] != "REWORDED DRAFT"
                 else ("REWORDED DRAFT", "", "Different text.")
                 for x in self.ENGLISH] + [("NEW HOME", "", "Moved text.")]
      self.run_emit(english)
      e = entries_by_key(self.path)["TC_HELP_NEW_HOME"]
      self.assertEqual(e.target, "Verschobener Text.")
      self.assertTrue(e.fuzzy)

   def test_new_key_from_the_ini_is_fuzzy(self):
      english = self.ENGLISH + [("BRAND NEW", "TRUE", "Brand new.")]
      self.run_emit(english, {"BRAND NEW": "Ganz neu."})
      e = entries_by_key(self.path)["TC_HELP_BRAND_NEW"]
      self.assertEqual(e.target, "Ganz neu.")
      self.assertTrue(e.fuzzy)
      self.assertEqual(e.notes, ["Config command: BRAND NEW   (default: TRUE)"])

   def test_gone_from_english_is_kept_obsolete(self):
      english = [x for x in self.ENGLISH if x[0] != "GONE"]
      self.run_emit(english)
      e = entries_by_key(self.path)["TC_HELP_GONE"]
      self.assertTrue(e.obsolete)
      self.assertEqual(e.target, "Entfernt.")

   def test_nothing_is_lost(self):
      before = {e.key for e in pofile.read_po(self.path)}
      english = [x for x in self.ENGLISH if x[0] != "GONE"] + \
         [("BRAND NEW", "", "Brand new.")]
      self.run_emit(english)
      after = {e.key for e in pofile.read_po(self.path)}
      self.assertTrue(before <= after)

   def test_source_catalogue_follows_the_english(self):
      english = [x if x[0] != "REVIEWED" else ("REVIEWED", "", "New English.")
                 for x in self.ENGLISH]
      self.run_emit(english, lang="ENG")
      e = entries_by_key(self.path)["TC_HELP_REVIEWED"]
      self.assertEqual((e.source, e.target, e.fuzzy),
                       ("New English.", "New English.", False))

   def test_fresh_catalogue_is_all_fuzzy_and_empty(self):
      os.remove(self.path)
      self.assertIsNone(self.run_emit(self.ENGLISH))
      got = pofile.read_po(self.path)
      self.assertEqual(len(got), len(self.ENGLISH))
      self.assertTrue(all(e.fuzzy and e.target == "" for e in got))
      self.assertTrue(read_bytes(self.path).count(b"\r\n") > 0)


if __name__ == "__main__":
   unittest.main()
