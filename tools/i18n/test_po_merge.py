"""po_merge -- a new identifier never makes a duplicate (msgctxt, msgid) (issue 156).

Run:  python tools/i18n/test_po_merge.py        (exit 0 = pass)

WHY THIS EXISTS. po_merge decides an entry is new by its identifiers. A new
uAppStrings resourcestring arrives with an empty msgctxt, so when a form caption
with no msgctxt already says the same English, a plain append made a second
entry with the same (msgctxt, msgid) -- which msgfmt rejects and Weblate
mishandles (issue 153 removed 115 of them). The merge must join the new `#:`
reference to the existing entry instead.

WHAT IT PINS
  * the twin gains the new reference, keeps its translation, and no entry is
    appended for it;
  * an entry with its OWN msgctxt is not a twin of one without;
  * an entry that is genuinely new is still appended, fuzzy and empty;
  * nothing else in the file changes, and a second merge changes nothing.
"""

import os
import shutil
import sys
import tempfile
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import pofile     # noqa: E402
import po_merge   # noqa: E402

CATALOGUE = (
   'msgid ""\r\n'
   'msgstr ""\r\n'
   '"Content-Type: text/plain; charset=UTF-8\\n"\r\n'
   '\r\n'
   '#: tfrmtelnet.btnconnect.caption\r\n'
   'msgid "Connect"\r\n'
   'msgstr "Verbinden"\r\n'
   '\r\n'
   '#: utr4wstrings.tc_telnet_check\r\n'
   'msgctxt "TC_TELNET_CHECK"\r\n'
   'msgid "Check"\r\n'
   'msgstr "Pruefen"\r\n'
)

TEMPLATE = (
   'msgid ""\r\n'
   'msgstr ""\r\n'
   '\r\n'
   '#: uappstrings.snetconnect\r\n'
   'msgid "Connect"\r\n'
   'msgstr ""\r\n'
   '\r\n'
   '#: uappstrings.scheck\r\n'
   'msgid "Check"\r\n'
   'msgstr ""\r\n'
   '\r\n'
   '#: uappstrings.sbrandnew\r\n'
   'msgid "Brand new"\r\n'
   'msgstr ""\r\n'
)


class JoinNotDuplicate(unittest.TestCase):

   def setUp(self):
      self.dir = tempfile.mkdtemp(prefix='po_merge_test_')
      self.po = os.path.join(self.dir, 'tr4w_de.po')
      self.pot = os.path.join(self.dir, 'scratch.pot')
      with open(self.po, 'wb') as fh:
         fh.write(CATALOGUE.encode('utf-8'))
      with open(self.pot, 'wb') as fh:
         fh.write(TEMPLATE.encode('utf-8'))

   def tearDown(self):
      shutil.rmtree(self.dir)

   def run_merge(self):
      template = [e for e in pofile.read_po(self.pot) if e.source.strip()]
      # 'uappstrings' must be OURS, or the merge skips every entry as a
      # dependency's string (po_merge.is_third_party).
      return po_merge.merge(self.po, template, {'uappstrings'}, True, add_only=True)

   def test_the_twin_gains_the_reference_and_nothing_is_appended_for_it(self):
      self.run_merge()
      entries = [e for e in pofile.read_po(self.po) if e.source.strip()]
      connects = [e for e in entries if e.source == 'Connect']
      self.assertEqual(len(connects), 1)
      self.assertEqual(connects[0].refs,
                       ['tfrmtelnet.btnconnect.caption', 'uappstrings.snetconnect'])
      self.assertEqual(connects[0].target, 'Verbinden')
      self.assertFalse(connects[0].fuzzy)

   def test_an_entry_with_its_own_msgctxt_is_not_a_twin(self):
      self.run_merge()
      checks = [e for e in pofile.read_po(self.po) if e.source == 'Check']
      self.assertEqual(sorted((e.key or '') for e in checks), ['', 'TC_TELNET_CHECK'])
      new = [e for e in checks if not e.key][0]
      self.assertEqual(new.target, '')
      self.assertTrue(new.fuzzy)

   def test_a_genuinely_new_entry_is_still_appended(self):
      added, _carried, _retired, _total = self.run_merge()
      self.assertEqual(added, 2)            # 'Check' (no msgctxt) and 'Brand new'
      sources = [e.source for e in pofile.read_po(self.po)]
      self.assertIn('Brand new', sources)

   def test_only_reference_lines_are_added_and_a_second_run_is_idempotent(self):
      self.run_merge()
      with open(self.po, 'rb') as fh:
         first = fh.read().decode('utf-8')
      for line in CATALOGUE.split('\r\n'):
         self.assertIn(line, first)
      self.assertIn('#: tfrmtelnet.btnconnect.caption\r\n#: uappstrings.snetconnect\r\n',
                    first)
      self.run_merge()
      with open(self.po, 'rb') as fh:
         self.assertEqual(fh.read().decode('utf-8'), first)


if __name__ == '__main__':
   unittest.main()
