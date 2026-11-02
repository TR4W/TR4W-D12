"""po_dedupe -- one entry per (msgctxt, msgid), and the right one survives.

Run:  python tools/i18n/test_po_dedupe.py        (exit 0 = pass)

WHY THIS EXISTS. Issue 153 (2026-11-02): every tr4w_*.po held 5 to 7 pairs of
entries with an empty msgctxt and the same msgid -- 115 in all -- which msgfmt
rejects and Weblate mishandles (it shows the first copy and saves into the
second). po_dedupe grouped on the msgid ALONE, which would also have merged
about 898 deliberately distinct Polish entries, and its tie-break kept the
form-property machine guess over the audited uAppStrings copy.

WHAT IT PINS
  * the key is (msgctxt, msgid): an entry with its own msgctxt is untouched;
  * an empty copy never beats a filled one, and a reviewed copy stays reviewed;
  * otherwise the copy naming a `uappstrings.` identifier wins;
  * every reference and translator comment survives, and the dropped text is
    quoted in a dated comment;
  * obsolete entries are left alone, the file keeps CRLF and the survivor its
    place;
  * AND THAT NO CATALOGUE HOLDS A DUPLICATE -- checked on the files
    themselves, so one arriving from a merge or from Weblate fails here.
"""

import collections
import datetime
import glob
import os
import shutil
import sys
import tempfile
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))
sys.path.insert(0, HERE)
import pofile      # noqa: E402
import po_dedupe   # noqa: E402

TODAY = datetime.date(2026, 11, 2)

HEADER = 'msgid ""\nmsgstr ""\n"Content-Type: text/plain; charset=UTF-8\\n"\n'


def block(refs, msgid, msgstr, fuzzy=True, ctxt=None, comments=()):
   lines = list(comments)
   lines += ['#: %s' % r for r in refs]
   if fuzzy:
      lines.append('#, fuzzy')
   if ctxt is not None:
      lines.append('msgctxt "%s"' % ctxt)
   lines.append('msgid "%s"' % msgid)
   lines.append('msgstr "%s"' % msgstr)
   return '\n'.join(lines) + '\n'


class Catalogue(unittest.TestCase):
   """Each test writes a small CRLF catalogue and reads it back with pofile."""

   def setUp(self):
      self.dir = tempfile.mkdtemp()
      self.path = os.path.join(self.dir, 'tr4w_xx.po')

   def tearDown(self):
      shutil.rmtree(self.dir)

   def load(self, *blocks):
      text = HEADER + '\n' + '\n'.join(blocks)
      with open(self.path, 'wb') as fh:
         fh.write(text.replace('\n', '\r\n').encode('utf-8'))
      return pofile.read_po(self.path)

   def run_dedupe(self, entries):
      return po_dedupe.dedupe(entries, today=TODAY)

   # ------------------------------------------------------------- the key

   def test_distinct_msgctxt_is_untouched(self):
      entries = self.load(
         block(['tfrmtelnet.btnconfigure.caption'], 'Configure...', 'Konfiguruj',
               ctxt='tfrmtelnet.btnconfigure.caption'),
         block(['tfrmradio.btnconfigure.caption'], 'Configure...', 'Ustaw',
               ctxt='tfrmradio.btnconfigure.caption'),
         block(['utr4wstrings:tc_qsos'], 'QSOs', 'QSO', fuzzy=False, ctxt='TC_QSOS'),
         block(['utr4wstrings.tc_qsos'], 'QSOs', 'QSOS'))
      out, collapsed, removed, dis = self.run_dedupe(entries)
      self.assertEqual((collapsed, removed, dis), (0, 0, []))
      self.assertEqual([e.target for e in out], ['Konfiguruj', 'Ustaw', 'QSO', 'QSOS'])

   def test_same_empty_msgctxt_is_merged(self):
      entries = self.load(
         block(['tfrmeditqso.lblcheck.caption'], 'Check', 'Kontrola'),
         block(['uappstrings.sverifycolumncheck'], 'Check', 'Kontrola'))
      out, collapsed, removed, dis = self.run_dedupe(entries)
      self.assertEqual((len(out), collapsed, removed, dis), (1, 1, 1, []))

   def test_three_copies_become_one(self):
      entries = self.load(
         block(['ulclformhelpers.tc_prefs_contest'], 'Contest', 'Zawody',
               comments=['# note one']),
         block(['usettingscaptions.rs_contest_contest'], 'Contest', 'Zawody',
               comments=['# note two']),
         block(['uappstrings.snewcontestfilescontest'], 'Contest', 'Zawody'))
      out, collapsed, removed, dis = self.run_dedupe(entries)
      self.assertEqual((len(out), removed), (1, 2))
      self.assertEqual(out[0].refs, ['ulclformhelpers.tc_prefs_contest',
                                     'usettingscaptions.rs_contest_contest',
                                     'uappstrings.snewcontestfilescontest'])
      self.assertEqual(out[0].comments, ['# note one', '# note two'])

   # ------------------------------------------------------------- the tie-break

   def test_audited_copy_beats_the_form_guess(self):
      entries = self.load(
         block(['tfrmnewcontest.lblcontest.caption'], 'CONTEST', 'SYMPERASMA'),
         block(['uappstrings.snewcontestcontestlabel'], 'CONTEST', 'DIAGONISMOS',
               comments=['# 2026-10-19: audit note']))
      out, _, _, dis = self.run_dedupe(entries)
      self.assertEqual(out[0].target, 'DIAGONISMOS')
      self.assertTrue(out[0].fuzzy)
      self.assertEqual(dis[0]['dropped'], [('SYMPERASMA', ['tfrmnewcontest.lblcontest.caption'])])

   def test_audited_beats_another_resourcestring(self):
      # da 'Contest': BOTH copies are resourcestring units; only the
      # uappstrings prefix tells them apart.
      entries = self.load(
         block(['ulclformhelpers.tc_prefs_contest', 'usettingscaptions.rs_contest_contest'],
               'Contest', 'Kontrol'),
         block(['uappstrings.snewcontestfilescontest'], 'Contest', 'Konkurrence'))
      out, _, _, _ = self.run_dedupe(entries)
      self.assertEqual(out[0].target, 'Konkurrence')

   def test_empty_audited_copy_loses_to_filled_form_copy(self):
      entries = self.load(
         block(['tfrmtelnet.btnconnect.caption'], 'Connect', 'Spojit'),
         block(['uappstrings.snetmenuconnect'], 'Connect', ''))
      out, _, _, dis = self.run_dedupe(entries)
      self.assertEqual(out[0].target, 'Spojit')
      self.assertEqual(dis[0]['dropped'], [('', ['uappstrings.snetmenuconnect'])])
      # nothing was lost, so nothing is quoted
      self.assertEqual(out[0].comments, [])

   def test_reviewed_copy_stays_reviewed(self):
      entries = self.load(
         block(['tfrmeditqso.lblcheck.caption'], 'Check', 'Sprawdz', fuzzy=False),
         block(['uappstrings.sverifycolumncheck'], 'Check', 'Sprawdz'))
      out, _, _, _ = self.run_dedupe(entries)
      self.assertFalse(out[0].fuzzy)
      self.assertTrue(out[0].translated)

   def test_file_order_breaks_a_true_tie(self):
      entries = self.load(
         block(['tfrma.x.caption'], 'File', 'Eins'),
         block(['tfrmb.x.caption'], 'File', 'Zwei'))
      out, _, _, _ = self.run_dedupe(entries)
      self.assertEqual(out[0].target, 'Eins')

   # ------------------------------------------------------------- nothing lost

   def test_dropped_text_is_quoted_in_a_dated_comment(self):
      entries = self.load(
         block(['tfrmnewcontest.lblcontest.caption'], 'CONTEST', 'CONTEST',
               comments=['# form audit']),
         block(['uappstrings.snewcontestcontestlabel'], 'CONTEST', 'CONCORSO',
               comments=['# uappstrings audit']))
      out, _, _, _ = self.run_dedupe(entries)
      self.assertEqual(out[0].comments[:2], ['# form audit', '# uappstrings audit'])
      self.assertEqual(len(out[0].comments), 3)
      note = out[0].comments[2]
      self.assertTrue(note.startswith('# 2026-11-02: po_dedupe merged'), note)
      self.assertIn('tfrmnewcontest.lblcontest.caption said: "CONTEST"', note)

   def test_every_identifier_still_resolves(self):
      entries = self.load(
         block(['tfrmeditqso.lblcheck.caption'], 'Check', 'Cheque'),
         block(['uappstrings.sverifycolumncheck'], 'Check', 'Verificar'),
         block(['utr4wstrings:tc_x tr4w/src/lang/tr4w_consts_eng.pas:9'], 'X', 'Y'))
      before = set().union(*(pofile.claimed_identifiers(e) for e in entries))
      out, _, _, _ = self.run_dedupe(entries)
      after = set().union(*(pofile.claimed_identifiers(e) for e in out))
      self.assertEqual(before, after)

   def test_obsolete_entries_are_left_alone(self):
      entries = self.load(
         '#~ msgid "Gone"\n#~ msgstr "Weg"\n',
         '#~ msgid "Gone"\n#~ msgstr "Fort"\n')
      out, collapsed, _, _ = self.run_dedupe(entries)
      self.assertEqual((len(out), collapsed), (2, 0))

   def test_text_between_entries_is_never_dropped(self):
      entries = self.load(
         block(['tfrma.x.caption'], 'File', 'Plik'),
         '# a comment-only block\n',
         block(['uappstrings.sfile'], 'File', 'Plik'))
      with self.assertRaises(po_dedupe.DedupeError):
         self.run_dedupe(entries)

   def test_written_file_keeps_crlf_and_place(self):
      entries = self.load(
         block(['tfrma.a.caption'], 'Alpha', 'A'),
         block(['tfrmeditqso.lblcheck.caption'], 'Check', 'Cheque'),
         block(['tfrma.b.caption'], 'Beta', 'B'),
         block(['uappstrings.sverifycolumncheck'], 'Check', 'Verificar'))
      out, _, _, _ = self.run_dedupe(entries)
      pofile.write_po(self.path, out, 'xx')
      with open(self.path, 'rb') as fh:
         raw = fh.read()
      self.assertEqual(raw.count(b'\n'), raw.count(b'\r\n'))
      back = pofile.read_po(self.path)
      self.assertEqual([e.source for e in back], ['Alpha', 'Check', 'Beta'])
      self.assertEqual(back[1].target, 'Verificar')
      self.assertEqual(back[1].refs, ['tfrmeditqso.lblcheck.caption',
                                      'uappstrings.sverifycolumncheck'])


class NoDuplicatesInTheTree(unittest.TestCase):
   """(msgctxt, msgid) is unique in every catalogue and in the Lazarus template."""

   def test_every_catalogue(self):
      paths = sorted(glob.glob(os.path.join(REPO, 'i18n', 'tr4w_*.po')) +
                     glob.glob(os.path.join(REPO, 'i18n', 'help_*.po')) +
                     [os.path.join(REPO, 'tr4w', 'languages', 'tr4w_laz.pot')])
      self.assertTrue(len(paths) > 20, paths)
      bad = []
      for p in paths:
         c = collections.Counter((e.key, e.source) for e in pofile.read_po(p)
                                 if not e.obsolete and e.source)
         bad += ['%s %r x%d' % (os.path.basename(p), k, n) for k, n in c.items() if n > 1]
      self.assertEqual(bad, [], '\n'.join(bad))


if __name__ == '__main__':
   unittest.main()
