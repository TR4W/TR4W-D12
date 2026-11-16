"""lfm_harvest -- every designed-form caption reaches every catalogue (issue 145).

Run:  python tools/i18n/test_lfm_harvest.py        (exit 0 = pass)

WHY THIS EXISTS. The harvest replaces the .lrj the Lazarus IDE writes on a
form save, and its --check is a build gate (Lint-LFMCatalogue). A parser that
mis-reads a .lfm names the wrong identifier, and TPOTranslator then finds no
entry -- the English shows in every language and nothing says so. Measured
against all 38 .lrj files on 2026-11-15 the harvest agreed on every key both
held; these cases pin the shapes that agreement depended on.

WHAT IT PINS
  * identifiers: the form's own property, a nested component (flat, not by
    path), a collection item (`panels[1].text`), a dotted property;
  * values: '' escapes, #13#10, `+` continuation lines;
  * what is skipped: non-string values, TStrings lists, binary data, text that
    is not language, and the two placeholder spellings;
  * the IDE's backup/ copies are not read; a stale exclusion fails;
  * --check fails on a missing entry, passes on an empty fuzzy one, and fails
    CLOSED on a form it cannot parse.
"""

import io
import os
import shutil
import sys
import tempfile
import unittest
from contextlib import redirect_stdout

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import lfm_harvest   # noqa: E402
import pofile        # noqa: E402

FORM = (
   "object frmDemo: TfrmDemo\r\n"
   "  Left = 10\r\n"
   "  Caption = 'Demo window'\r\n"
   "  object pnlTop: TPanel\r\n"
   "    Caption = ''\r\n"
   "    object btnGo: TButton\r\n"
   "      Caption = 'Don''t go'\r\n"
   "      Hint = 'Line one'#13#10'Line two'\r\n"
   "      TabOrder = 0\r\n"
   "    end\r\n"
   "    object lblLong: TLabel\r\n"
   "      Caption = 'First half, ' +\r\n"
   "        'second half'\r\n"
   "    end\r\n"
   "  end\r\n"
   "  object sbMain: TStatusBar\r\n"
   "    Panels = <\r\n"
   "      item\r\n"
   "        Width = 50\r\n"
   "      end\r\n"
   "      item\r\n"
   "        Text = 'Ready'\r\n"
   "        Width = 50\r\n"
   "      end>\r\n"
   "  end\r\n"
   "  object grdLog: TStringGrid\r\n"
   "    Columns = <\r\n"
   "      item\r\n"
   "        Title.Caption = 'Call'\r\n"
   "      end>\r\n"
   "  end\r\n"
   "  object cbxScheme: TComboBox\r\n"
   "    Items.Strings = (\r\n"
   "      'Caption = not a property'\r\n"
   "      'Second'\r\n"
   "    )\r\n"
   "    Text = 'F1'\r\n"
   "  end\r\n"
   "  object imgLogo: TImage\r\n"
   "    Picture.Data = {\r\n"
   "      0A54504E474F626A656374\r\n"
   "    }\r\n"
   "  end\r\n"
   "  object lblHeading: TLabel\r\n"
   "    Caption = 'lblHeading'\r\n"
   "  end\r\n"
   "  object rgBank: TRadioGroup\r\n"
   "    Caption = 'Bank (assigned at run time)'\r\n"
   "  end\r\n"
   "  object lblNote: TLabel\r\n"
   "    Caption = '(set at run time from SNote)'\r\n"
   "  end\r\n"
   "end\r\n"
)

EXPECTED = [
   ('tfrmdemo.caption', 'Demo window'),
   ('tfrmdemo.btngo.caption', "Don't go"),
   ('tfrmdemo.btngo.hint', 'Line one\r\nLine two'),
   ('tfrmdemo.lbllong.caption', 'First half, second half'),
   ('tfrmdemo.sbmain.panels[1].text', 'Ready'),
   ('tfrmdemo.grdlog.columns[0].title.caption', 'Call'),
]


def catalogue(entries):
   """A catalogue text claiming each identifier with an empty fuzzy entry."""
   out = ['msgid ""', 'msgstr ""',
          '"Content-Type: text/plain; charset=UTF-8\\n"', '']
   for ident, text in entries:
      out += ['#: ' + ident, '#, fuzzy', 'msgid "%s"' % pofile.escape(text),
              'msgstr ""', '']
   return '\r\n'.join(out)


class Harvest(unittest.TestCase):

   def setUp(self):
      self.tmp = tempfile.mkdtemp()
      self.src = os.path.join(self.tmp, 'src')
      self.i18n = os.path.join(self.tmp, 'i18n')
      os.makedirs(os.path.join(self.src, 'backup'))
      os.makedirs(self.i18n)
      self.write(os.path.join(self.src, 'uDemoForm.lfm'), FORM)
      # The IDE's previous copy, with OLD English. Never harvested.
      self.write(os.path.join(self.src, 'backup', 'uDemoForm.lfm'),
                 FORM.replace('Demo window', 'Old title'))
      self.saved = lfm_harvest.EXCLUDED_FORMS
      lfm_harvest.EXCLUDED_FORMS = {}

   def tearDown(self):
      lfm_harvest.EXCLUDED_FORMS = self.saved
      shutil.rmtree(self.tmp)

   def write(self, path, text):
      with open(path, 'w', encoding='utf-8', newline='') as fh:
         fh.write(text)

   def run_main(self, *argv):
      buf = io.StringIO()
      with redirect_stdout(buf):
         code = lfm_harvest.main(['--src', self.src, '--dir', self.i18n] + list(argv))
      return code, buf.getvalue()

   def test_identifiers_and_values(self):
      files, stale = lfm_harvest.form_files(self.src)
      self.assertEqual(stale, [])
      self.assertEqual([os.path.basename(f) for f in files], ['uDemoForm.lfm'])
      strings, placeholders = lfm_harvest.harvest(files)
      self.assertEqual([(i, t) for i, t, _ in strings], EXPECTED)
      self.assertEqual(placeholders, 3)

   def test_stale_exclusion_fails(self):
      lfm_harvest.EXCLUDED_FORMS = {'uGoneForm.lfm': 'test'}
      code, out = self.run_main('--check')
      self.assertEqual(code, 2, out)
      self.assertIn('uGoneForm.lfm', out)

   def test_check_fails_on_a_missing_entry(self):
      self.write(os.path.join(self.i18n, 'tr4w_de.po'), catalogue(EXPECTED))
      self.write(os.path.join(self.i18n, 'tr4w_fr.po'), catalogue(EXPECTED[:-1]))
      code, out = self.run_main('--check')
      self.assertEqual(code, 1, out)
      self.assertIn('tfrmdemo.grdlog.columns[0].title.caption', out)
      self.assertIn('tr4w_fr.po', out)

   def test_check_passes_on_empty_fuzzy_entries(self):
      self.write(os.path.join(self.i18n, 'tr4w_de.po'), catalogue(EXPECTED))
      code, out = self.run_main('--check')
      self.assertEqual(code, 0, out)

   def test_check_fails_closed_on_an_unparseable_form(self):
      self.write(os.path.join(self.i18n, 'tr4w_de.po'), catalogue(EXPECTED))
      self.write(os.path.join(self.src, 'uBrokenForm.lfm'),
                 "object frmBroken: TfrmBroken\r\n  Caption = 'Broken'\r\n")
      code, out = self.run_main('--check')
      self.assertEqual(code, 2, out)

   def test_check_fails_closed_with_no_catalogue(self):
      code, out = self.run_main('--check')
      self.assertEqual(code, 2, out)

   def test_pot_round_trips_through_po_merge(self):
      import po_merge
      pot = os.path.join(self.tmp, 'lfm.pot')
      code, out = self.run_main('--pot', pot)
      self.assertEqual(code, 0, out)
      de = os.path.join(self.i18n, 'tr4w_de.po')
      self.write(de, catalogue(EXPECTED[:2]))
      with redirect_stdout(io.StringIO()):
         added, _, retired, _ = po_merge.merge(de, pofile.read_po(pot), set(),
                                               True, add_only=True)
      self.assertEqual((added, retired), (len(EXPECTED) - 2, 0))
      code, out = self.run_main('--check')
      self.assertEqual(code, 0, out)


if __name__ == '__main__':
   unittest.main()
