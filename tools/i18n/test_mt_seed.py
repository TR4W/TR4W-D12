"""mt_seed -- what it must REFUSE to write, and what it must LEAVE ALONE (#92).

Run:  python tools/i18n/test_mt_seed.py        (exit 0 = pass)

WHY THIS EXISTS. On 2026-10-19 LibreTranslate flattened the line breaks of
SImportMyFactsQuestion in all 19 seeded languages. mt_seed checked only the
format specifiers, so it wrote every draft; po_lint --all then reported 19 new
"CONTROL CHARS differ". The drafts were cleared back to empty by hand -- and the
next mt_seed run, for an unrelated string, seeded them all again, because an
empty entry is exactly what mt_seed fills.

So two rules are pinned here:

  1. A draft po_lint would reject is never written. mt_seed asks po_lint's own
     draft_defects(), so the two cannot disagree about what "damaged" means.
  2. An entry carrying the translator comment '# mt-seed: skip' is never
     seeded, and never wiped by --reseed. A translator comment is the field
     msgmerge, Poedit and Weblate carry through untouched, so the decision
     travels with the entry instead of living in a list in this script.

No engine is contacted: translate() and check_target() are replaced by a fake
that behaves like LibreTranslate with format=html -- every run of whitespace,
newlines included, comes back as one space.
"""

import contextlib
import io
import os
import re
import shutil
import sys
import tempfile
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import mt_seed  # noqa: E402
import po_lint  # noqa: E402
import pofile   # noqa: E402

# A minimal catalogue in the shape po_merge writes. CRLF, as every catalogue is.
FIXTURE = (
   'msgid ""\r\n'
   'msgstr ""\r\n'
   '"Content-Type: text/plain; charset=UTF-8\\n"\r\n'
   '"Language: de\\n"\r\n'
   '\r\n'
   '#: uappstrings.splain\r\n'
   '#, fuzzy\r\n'
   'msgid "Hello world"\r\n'
   'msgstr ""\r\n'
   '\r\n'
   '#: uappstrings.smultiline\r\n'
   '#, fuzzy\r\n'
   'msgid ""\r\n'
   '"Keep these values?\\n"\r\n'
   '"\\n"\r\n'
   '"Yes keeps them."\r\n'
   'msgstr ""\r\n'
   '\r\n'
   '# mt-seed: skip -- cleared 2026-10-19, the engine flattens its line breaks\r\n'
   '#: uappstrings.scleared\r\n'
   'msgid "Import the file"\r\n'
   'msgstr ""\r\n'
   '\r\n'
   '# MT-Seed: Skip\r\n'
   '#: uappstrings.skeptdraft\r\n'
   '#, fuzzy\r\n'
   'msgid "Open the log"\r\n'
   'msgstr "Das Log oeffnen"\r\n'
   '\r\n'
   '#: uappstrings.scopy\r\n'
   '#, fuzzy\r\n'
   'msgid "&Copy"\r\n'
   'msgstr ""\r\n'
   '\r\n'
   '#: uappstrings.ssearchpounce\r\n'
   '#, fuzzy\r\n'
   'msgid "Search && pounce mode"\r\n'
   'msgstr ""\r\n'
)


def fake_translate(url, texts, target, source="en", batch=1):
   """LibreTranslate under format=html: whitespace runs collapse to a space,
   and an escaped ampersand is damaged the way the real models damaged it on
   2026-11-02 ('&amp;Copy' -> '" Copy')."""
   out = []
   for t in texts:
      t = t.replace("&amp;", '" ')
      out.append("%s: %s" % (target, re.sub(r"\s+", " ", t).strip()))
   return out


class SeedFixture(unittest.TestCase):

   def setUp(self):
      self.dir = tempfile.mkdtemp(prefix="test_mt_seed_")
      self.path = os.path.join(self.dir, "tr4w_de.po")
      with io.open(self.path, "w", encoding="utf-8", newline="") as fh:
         fh.write(FIXTURE)
      self.saved = (mt_seed.translate, mt_seed.check_target,
                    pofile.lcl_catalogue)
      mt_seed.translate = fake_translate
      mt_seed.check_target = lambda url, target, source="en": None
      # No Lazarus lookup: the LCL fill is not what is under test.
      pofile.lcl_catalogue = lambda lang: {}

   def tearDown(self):
      (mt_seed.translate, mt_seed.check_target,
       pofile.lcl_catalogue) = self.saved
      shutil.rmtree(self.dir, ignore_errors=True)

   def run_seed(self, reseed=False, only=None):
      out = io.StringIO()
      with contextlib.redirect_stdout(out):
         mt_seed.seed(self.path, "http://unused", "de", "GER", False,
                      reseed=reseed, only=only)
      return out.getvalue()

   def entries(self):
      return {e.refs[0]: e for e in pofile.read_po(self.path)}

   # -- the control: the fake engine does produce drafts --------------------

   def test_a_sound_draft_is_still_seeded(self):
      self.run_seed()
      self.assertEqual(self.entries()["uappstrings.splain"].target,
                       "de: Hello world")

   # -- accelerators (2026-11-02) --------------------------------------------

   def test_the_accelerator_never_reaches_the_engine_and_comes_back(self):
      # The fake damages any escaped '&' it is sent, as the real models did,
      # so a correct draft proves the '&' was taken out before sending.
      self.run_seed()
      self.assertEqual(self.entries()["uappstrings.scopy"].target, "de: &Copy")

   def test_a_literal_double_ampersand_survives(self):
      self.run_seed()
      self.assertEqual(self.entries()["uappstrings.ssearchpounce"].target,
                       "de: Search && pounce mode")

   def test_the_help_catalogue_sends_its_ampersands_as_text(self):
      # captions=False: in help text an '&' is part of a command name
      # ('AUTO S&P ENABLE'), so it is NOT taken out.
      sent = []

      def recording(url, texts, target, source="en", batch=1):
         sent.extend(texts)
         return list(texts)
      mt_seed.translate = recording
      out = io.StringIO()
      with contextlib.redirect_stdout(out):
         mt_seed.seed(self.path, "http://unused", "de", "GER", False,
                      only={"uappstrings.scopy"}, captions=False)
      self.assertEqual(sent, ["&amp;Copy"])

   def test_a_caption_is_sent_without_its_accelerator(self):
      sent = []

      def recording(url, texts, target, source="en", batch=1):
         sent.extend(texts)
         return list(texts)
      mt_seed.translate = recording
      out = io.StringIO()
      with contextlib.redirect_stdout(out):
         mt_seed.seed(self.path, "http://unused", "de", "GER", False,
                      only={"uappstrings.scopy", "uappstrings.ssearchpounce"})
      self.assertEqual(sent, ["Copy", 'Search <nm id="0"></nm> pounce mode'])

   # -- defect 1: a draft po_lint rejects ------------------------------------

   def test_a_draft_that_lost_its_line_breaks_is_not_written(self):
      self.run_seed()
      e = self.entries()["uappstrings.smultiline"]
      self.assertEqual(e.target, "",
                       "mt_seed wrote a draft po_lint rejects: %r" % e.target)

   def test_no_seeded_entry_fails_po_lint(self):
      self.run_seed()
      for e in pofile.read_po(self.path):
         if e.target:
            self.assertEqual(po_lint.draft_defects(e.source, e.target), [],
                             "%s: %r" % (e.refs[0], e.target))

   def test_the_refusal_is_reported(self):
      out = self.run_seed()
      self.assertIn("uappstrings.smultiline", out)
      self.assertIn("CONTROL CHARS differ", out)

   # -- defect 2: a cleared entry comes back ---------------------------------

   def test_an_entry_marked_skip_is_not_seeded(self):
      self.run_seed()
      self.assertEqual(self.entries()["uappstrings.scleared"].target, "")

   def test_an_entry_marked_skip_stays_empty_on_every_run(self):
      self.run_seed()
      self.run_seed()
      self.assertEqual(self.entries()["uappstrings.scleared"].target, "")

   def test_reseed_does_not_wipe_an_entry_marked_skip(self):
      self.run_seed(reseed=True)
      self.assertEqual(self.entries()["uappstrings.skeptdraft"].target,
                       "Das Log oeffnen")

   def test_the_marker_survives_a_seed_run(self):
      self.run_seed()
      e = self.entries()["uappstrings.scleared"]
      self.assertTrue(mt_seed.marked_skip(e), e.comments)

   # -- --only: a change seeds what it touched, nothing else (2026-11-01) ----

   def test_only_seeds_the_named_entry(self):
      self.run_seed(only={"uappstrings.splain"})
      self.assertEqual(self.entries()["uappstrings.splain"].target,
                       "de: Hello world")

   def test_only_leaves_every_other_empty_entry_empty(self):
      # Named in a different case and with ':' -- the identifier as LazUtils
      # normalises it, not as typed.
      self.run_seed(only={"UAPPSTRINGS:SMULTILINE"})
      self.assertEqual(self.entries()["uappstrings.splain"].target, "")

   def test_only_still_applies_the_skip_marker(self):
      self.run_seed(only={"uappstrings.scleared"})
      self.assertEqual(self.entries()["uappstrings.scleared"].target, "")

   def test_reseed_with_only_does_not_wipe_other_drafts(self):
      self.run_seed(reseed=True, only={"uappstrings.splain"})
      self.assertEqual(self.entries()["uappstrings.skeptdraft"].target,
                       "Das Log oeffnen")


class CommandNames(unittest.TestCase):
   """--catalog help: command names and TRUE/FALSE stay English (2026-11-02).

   The engine is not contacted: each test plays the engine's part on the
   payload protect() built, then hands the result to unprotect()."""

   RX = re.compile(r"(?<![A-Za-z0-9])(?:AUTO S&amp;P ENABLE|BACKUP DESTINATION"
                   r"|TRUE|FALSE)(?![A-Za-z0-9])")

   def round_trip(self, english, engine):
      payload, specs, names = mt_seed.protect(english, self.RX)
      return mt_seed.unprotect(engine(payload), specs, names)

   def test_a_name_survives(self):
      text, problem = self.round_trip(
         "Use BACKUP DESTINATION.", lambda p: p.replace("Use", "Nutze"))
      self.assertIsNone(problem)
      self.assertEqual(text, "Nutze BACKUP DESTINATION.")

   def test_a_name_with_an_ampersand_survives_the_escaping(self):
      payload, _, names = mt_seed.protect("If AUTO S&P ENABLE is TRUE.", self.RX)
      self.assertEqual(names, ["AUTO S&P ENABLE", "TRUE"])
      self.assertNotIn("S&amp;P", payload)
      text, problem = mt_seed.unprotect(payload.replace("If", "Wenn"), [], names)
      self.assertIsNone(problem)
      self.assertEqual(text, "Wenn AUTO S&P ENABLE is TRUE.")

   def test_names_the_engine_reorders_are_restored(self):
      def swap(p):
         a, b = '<nm id="0"></nm>', '<nm id="1"></nm>'
         return p.replace(a, "\0").replace(b, a).replace("\0", b)
      text, problem = self.round_trip("Set TRUE or FALSE.", swap)
      self.assertIsNone(problem)
      self.assertEqual(text, "Set FALSE or TRUE.")

   def test_a_dropped_name_drops_the_draft(self):
      _, problem = self.round_trip("Set TRUE or FALSE.",
                                   lambda p: p.replace('<nm id="1"></nm>', "FALSCH"))
      self.assertIsNotNone(problem)

   def test_a_doubled_name_drops_the_draft(self):
      _, problem = self.round_trip("Set TRUE.",
                                   lambda p: p + ' <nm id="0"></nm>')
      self.assertIsNotNone(problem)

   def test_a_word_inside_another_word_is_not_a_name(self):
      _, _, names = mt_seed.protect("UNTRUE and TRUEISH are not TRUE.", self.RX)
      self.assertEqual(names, ["TRUE"])

   def test_without_a_pattern_nothing_is_masked(self):
      payload, _, names = mt_seed.protect("Set TRUE.")
      self.assertEqual((payload, names), ("Set TRUE.", []))

   def test_the_real_vocabulary_is_built(self):
      root = os.path.dirname(os.path.dirname(HERE))
      rx = mt_seed.command_name_pattern(root)
      self.assertTrue(rx.search(mt_seed.html.escape("If AUTO S&P ENABLE is set",
                                                    quote=False)))
      self.assertTrue(rx.search("BACKUP DESTINATION"))
      # A bracketed reference is masked with its brackets, so the engine
      # cannot mangle them.
      payload, _, names = mt_seed.protect("Use [BACKUP DESTINATION] now.", rx)
      self.assertEqual(names, ["[BACKUP DESTINATION]"])
      self.assertEqual(payload, 'Use <nm id="0"></nm> now.')


class Marker(unittest.TestCase):

   def entry(self, *comments):
      return pofile.Entry("", "Some text", comments=list(comments))

   def test_spellings_that_mean_skip(self):
      for line in ("# mt-seed: skip", "#  MT-SEED:  SKIP", "# mt-seed: skip -- why",
                   "# mt-seed:skip"):
         self.assertTrue(mt_seed.marked_skip(self.entry(line)), line)

   def test_lines_that_do_not(self):
      for line in ("# skip", "# translator: mt-seed skipped this once",
                   "# mt-seed: skipped", "# 2026-10-19 cleared"):
         self.assertFalse(mt_seed.marked_skip(self.entry(line)), line)
      self.assertFalse(mt_seed.marked_skip(self.entry()))

   def test_an_extracted_comment_is_not_the_marker(self):
      # '#.' lines belong to the template; msgmerge rewrites them from the
      # .pot, so a marker there would vanish on the next merge.
      e = pofile.Entry("", "Some text", notes=["mt-seed: skip"])
      self.assertFalse(mt_seed.marked_skip(e))


class DraftDefects(unittest.TestCase):
   """po_lint's per-entry rule, as mt_seed asks it."""

   def test_line_breaks_tabs_and_specifiers(self):
      self.assertEqual(po_lint.draft_defects("a\nb", "a\nb"), [])
      self.assertTrue(po_lint.draft_defects("a\nb", "a b"))
      self.assertTrue(po_lint.draft_defects("a\tb", "a b"))
      self.assertTrue(po_lint.draft_defects("a b", "a\nb"))
      self.assertTrue(po_lint.draft_defects("%d of %s", "%s of %d"))
      self.assertTrue(po_lint.draft_defects("%-8s", "%s"))
      self.assertEqual(po_lint.draft_defects("%d of %s", "%d von %s"), [])

   def test_accelerator_rule_is_only_asked_for_captions(self):
      self.assertEqual(po_lint.draft_defects("&Copy", '" Copy'), [])
      self.assertTrue(po_lint.draft_defects("&Copy", '" Copy', accelerators=True))


class Accelerators(unittest.TestCase):
   """Taken out before the engine, put back after it (2026-11-02)."""

   def test_split(self):
      cases = {
         "&Copy": ("Copy", "C"),
         "Paddle swa&p": ("Paddle swap", "p"),
         "Search && pounce mode": ("Search && pounce mode", None),
         "Search && &pounce": ("Search && pounce", "p"),
         "& x": ("& x", None),                     # not before a letter
         "Press &E to program S&P": ("Press &E to program S&P", None),  # two
         "Plain": ("Plain", None),
      }
      for text, want in cases.items():
         self.assertEqual(mt_seed.split_accelerator(text), want, text)

   def test_place_before_the_same_letter_at_a_word_start(self):
      P = mt_seed.place_accelerator
      self.assertEqual(P("Copiar", "C", "es"), "&Copiar")
      # No word starts with an 'a', so the first 'a' takes it.
      self.assertEqual(P("Seleziona tutto", "a", "it"), "Selezion&a tutto")
      self.assertEqual(P("Esegui i controlli", "R", "it"), "Esegui i cont&rolli")
      self.assertEqual(P("Kör kontroller", "k", "sv"), "&Kör kontroller")

   def test_no_such_letter_means_no_accelerator(self):
      self.assertEqual(mt_seed.place_accelerator("Kopiera", "C", "sv"), "Kopiera")
      self.assertEqual(mt_seed.place_accelerator("Поиск", "S", "ru"), "Поиск")

   def test_never_inside_a_specifier_or_a_literal(self):
      P = mt_seed.place_accelerator
      self.assertEqual(P("in %s", "s", "it"), "in %s")
      self.assertEqual(P("Sono in %s", "s", "it"), "&Sono in %s")
      self.assertEqual(P("A && B", "a", "en"), "&A && B")

   def test_cjk_puts_the_letter_after_the_word(self):
      P = mt_seed.place_accelerator
      self.assertEqual(P("コピー", "C", "ja"), "コピー(&C)")
      self.assertEqual(P("保存...", "s", "ja"), "保存(&S)...")
      self.assertEqual(P("复制", "c", "zh-Hans"), "复制(&C)")
      self.assertEqual(P("닫기:", "c", "ko"), "닫기(&C):")

   def test_none_is_left_alone(self):
      self.assertEqual(mt_seed.place_accelerator("Copiar", None, "es"), "Copiar")

   def test_a_literal_double_ampersand_round_trips_as_an_element(self):
      payload, specs, names = mt_seed.protect("Search && pounce %s", literal_amp=True)
      self.assertEqual(payload, 'Search <nm id="0"></nm> pounce <ph id="0"></ph>')
      text, problem = mt_seed.unprotect(payload.replace("Search", "Suche"), specs, names)
      self.assertIsNone(problem)
      self.assertEqual(text, "Suche && pounce %s")


class AcceleratorDefects(unittest.TestCase):
   """po_lint.accelerator_defects -- the rule TRANSLATOR_GUIDE section 5 gives."""

   def defects(self, source, target):
      return po_lint.accelerator_defects(source, target)

   def test_sound_translations_pass(self):
      for source, target in (("&Copy", "&Kopieren"), ("&Copy", "Kopiera"),
                             ("Copy", "Kopiera"), ("&Copy", "コピー(&C)"),
                             ("Search && pounce", "Buscar && atacar"),
                             ("Search && pounce", "Buscar y atacar"),
                             ("Paddle swa&p", "Inversione pa&ddle")):
         self.assertEqual(self.defects(source, target), [], (source, target))

   def test_what_the_engine_did(self):
      cases = (
         ("&Copy", '" Copy', po_lint.ACCEL_QUOTE),
         ("&Copy", ">", po_lint.ACCEL_QUOTE),
         ("&I am in %s", "# I am in %s", po_lint.ACCEL_QUOTE),
         ("&Save", "& Gem", po_lint.ACCEL_SPACED),
         ("Select &all", "Vælg & alle", po_lint.ACCEL_SPACED),
         ("&Copy", "&Co&pia", po_lint.ACCEL_TWO),
         ("Press &E to program", "Pulse &E en S&P", po_lint.ACCEL_TWO),
         ("Search && pounce mode", "Mode de recherche & & ponce", po_lint.ACCEL_LITERAL),
         ("Search && pounce mode", "Søg i & pounce tilstand", po_lint.ACCEL_LITERAL),
         ("List of commands", "&Lista comenzilor", po_lint.ACCEL_ADDED),
      )
      for source, target, want in cases:
         self.assertIn(want, self.defects(source, target), (source, target))


class LintReportsTheBlindSpots(unittest.TestCase):
   """po_lint's ACCELERATOR check: two '&' in one translation, and a literal
   '&&' broken up. Before 2026-11-02 both passed."""

   CATALOGUE = (
      'msgid ""\r\n'
      'msgstr ""\r\n'
      '"Content-Type: text/plain; charset=UTF-8\\n"\r\n'
      '\r\n'
      '#: uappstrings.spresse\r\n'
      'msgid "Press &E to program"\r\n'
      'msgstr "Pulse &E en S&P"\r\n'
      '\r\n'
      '#: uappstrings.ssearch\r\n'
      '#, fuzzy\r\n'
      'msgid "Search && pounce mode"\r\n'
      'msgstr "Mode de recherche & & ponce"\r\n'
   )

   def test_both_are_reported(self):
      d = tempfile.mkdtemp(prefix="test_po_lint_")
      try:
         path = os.path.join(d, "tr4w_xx.po")
         with io.open(path, "w", encoding="utf-8", newline="") as fh:
            fh.write(self.CATALOGUE)
         out = io.StringIO()
         with contextlib.redirect_stdout(out):
            bad = po_lint.check(path, False)
         self.assertIn("two & in one translation", out.getvalue())
         self.assertIn("literal && was broken up", out.getvalue())
         self.assertGreaterEqual(bad, 2)
      finally:
         shutil.rmtree(d, ignore_errors=True)


if __name__ == "__main__":
   unittest.main(verbosity=2)
