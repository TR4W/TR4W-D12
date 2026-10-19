"""pofile must rewrite a catalogue LOSSLESSLY.

Run:  python tools/i18n/test_pofile.py        (exit 0 = pass)

WHY THIS EXISTS. Every catalogue writer in tools/i18n -- po_merge, po_lint
--fix, po_rekey, po_prune, po_dedupe, mt_seed, salvage_lossy -- reads a
catalogue with read_po and writes it back with write_po. Until 2026-10-18
that round trip was not lossless: it dropped every '# ' translator comment
and replaced the header with gettext's template placeholders. Measured on
the 22 catalogues: 4-5 lines lost each, 36 in Polish -- the dated
2026-10-16 audit notes ("machine error: zawody ..."), the provenance of the
DL4BBH author credit, and G0DVJ's Poedit header (PO-Revision-Date,
X-Generator). po_merge's own docstring promised "an existing translation is
never touched", and the entries were not -- but the record around them was.

THE RULE IT PINS: reading and writing a catalogue changes NOTHING but the
entries a caller actually added, removed or changed. A catalogue read and
written unchanged comes back byte-identical.

No dependency beyond the standard library and pofile itself, so a build or
lint step can run it as-is.
"""

import glob
import os
import shutil
import sys
import tempfile
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))
sys.path.insert(0, HERE)
import pofile  # noqa: E402

CATALOGUES = sorted(glob.glob(os.path.join(REPO, "i18n", "tr4w_*.po")))

# The other files the same tools rewrite: the help catalogues (ini2po) and the
# Lazarus template (read by po_merge). Not the gate's subject, but a rewrite
# of them must be lossless too, and checking costs a fraction of a second.
OTHER_PO_FILES = sorted(glob.glob(os.path.join(REPO, "i18n", "help_*.po"))
                        + glob.glob(os.path.join(REPO, "tr4w", "languages", "*.pot")))

# A small catalogue carrying every shape the real ones do: a commented,
# hand-edited header; translator comments ('# '), extracted notes ('#.'),
# references ('#:'), several flags on one line, a previous-msgid ('#|'), a
# multi-line msgid, a comment-only block between entries, and an obsolete
# entry. CRLF, as the tree requires.
SAMPLE = (
   "# Polish translation, hand-edited header\n"
   "msgid \"\"\n"
   "msgstr \"\"\n"
   "\"Project-Id-Version: TR4W\\n\"\n"
   "\"PO-Revision-Date: 2026-10-01 21:08+0100\\n\"\n"
   "\"X-Generator: Poedit 3.9\\n\"\n"
   "\n"
   "# 2026-10-16: a dated audit note\n"
   "#. an extracted note\n"
   "#: uappstrings.sone\n"
   "#, fuzzy, object-pascal-format\n"
   "#| msgid \"Old one\"\n"
   "msgid \"One %s\"\n"
   "msgstr \"Jeden %s\"\n"
   "\n"
   "# an orphan comment block, attached to nothing\n"
   "\n"
   "#: uappstrings.stwo\n"
   "msgid \"\"\n"
   "\"Two\\n\"\n"
   "\"lines\"\n"
   "msgstr \"Dwa\"\n"
   "\n"
   "#~ msgid \"Gone\"\n"
   "#~ msgstr \"Nie ma\"\n"
   "\n"
).replace("\n", "\r\n").encode("utf-8")


def roundtrip_bytes(raw, mutate=None, language="pl"):
   """Write `raw` to a scratch file, read it, optionally mutate the entry
   list, write it back, and return the bytes written."""
   tmp = tempfile.mkdtemp()
   try:
      path = os.path.join(tmp, "tr4w_%s.po" % language)
      with open(path, "wb") as fh:
         fh.write(raw)
      entries = pofile.read_po(path)
      if mutate is not None:
         entries = mutate(entries)
      pofile.write_po(path, entries, language)
      with open(path, "rb") as fh:
         return fh.read()
   finally:
      shutil.rmtree(tmp)


def first_difference(a, b):
   """A readable pointer at where two byte strings part company."""
   n = min(len(a), len(b))
   for i in range(n):
      if a[i] != b[i]:
         break
   else:
      i = n
   line = a[:i].count(b"\n") + 1
   return "first difference at byte %d (line %d): %r vs %r (%d vs %d bytes)" % (
      i, line, a[i:i + 60], b[i:i + 60], len(a), len(b))


class RealCatalogues(unittest.TestCase):
   """THE GATE: every shipped catalogue survives a read/write unchanged."""

   def test_there_are_catalogues(self):
      # A floor, so the gate cannot pass by finding nothing to check.
      self.assertGreaterEqual(len(CATALOGUES), 22, "found %d catalogues" % len(CATALOGUES))

   def test_every_catalogue_roundtrips_byte_identical(self):
      self.assertEqual(roundtrip_failures(CATALOGUES), [])

   def test_help_catalogues_and_template_roundtrip_byte_identical(self):
      self.assertGreater(len(OTHER_PO_FILES), 0)
      self.assertEqual(roundtrip_failures(OTHER_PO_FILES), [])


def roundtrip_failures(paths):
   """One line per file that does not come back byte-identical."""
   failures = []
   for path in paths:
      with open(path, "rb") as fh:
         raw = fh.read()
      name = os.path.basename(path)
      out = roundtrip_bytes(raw)
      if out != raw:
         failures.append("%s: %s" % (name, first_difference(raw, out)))
   return failures


class Sample(unittest.TestCase):
   """The shapes, one at a time, so a failure names what broke."""

   def test_unchanged_sample_is_byte_identical(self):
      out = roundtrip_bytes(SAMPLE)
      self.assertEqual(out, SAMPLE, first_difference(SAMPLE, out))

   def test_fields_parse_as_before(self):
      tmp = tempfile.mkdtemp()
      try:
         path = os.path.join(tmp, "tr4w_pl.po")
         with open(path, "wb") as fh:
            fh.write(SAMPLE)
         entries = pofile.read_po(path)
      finally:
         shutil.rmtree(tmp)
      self.assertEqual(len(entries), 3)
      one, two, gone = entries
      self.assertEqual((one.source, one.target, one.fuzzy), ("One %s", "Jeden %s", True))
      self.assertEqual(one.notes, ["an extracted note"])
      self.assertEqual(one.refs, ["uappstrings.sone"])
      self.assertEqual((two.source, two.target, two.fuzzy), ("Two\nlines", "Dwa", False))
      self.assertTrue(gone.obsolete)

   def test_appending_an_entry_changes_only_the_end(self):
      def add(entries):
         entries.append(pofile.Entry(key="", source="Three", target="", fuzzy=True,
                                     refs=["uappstrings.sthree"]))
         return entries
      out = roundtrip_bytes(SAMPLE, add)
      tail = ("#: uappstrings.sthree\r\n#, fuzzy\r\nmsgid \"Three\"\r\n"
              "msgstr \"\"\r\n\r\n").encode("utf-8")
      self.assertEqual(out, SAMPLE + tail, first_difference(SAMPLE + tail, out))

   def test_changing_a_translation_keeps_its_comments_and_flags(self):
      def edit(entries):
         entries[0].target = "Raz %s"
         return entries
      out = roundtrip_bytes(SAMPLE, edit)
      expected = SAMPLE.replace(b"msgstr \"Jeden %s\"", b"msgstr \"Raz %s\"")
      self.assertEqual(out, expected, first_difference(expected, out))

   def test_defuzzing_keeps_the_other_flags(self):
      def defuzz(entries):
         entries[0].fuzzy = False
         return entries
      out = roundtrip_bytes(SAMPLE, defuzz)
      expected = SAMPLE.replace(b"#, fuzzy, object-pascal-format", b"#, object-pascal-format")
      self.assertEqual(out, expected, first_difference(expected, out))

   def test_removing_the_first_entry_keeps_the_header(self):
      out = roundtrip_bytes(SAMPLE, lambda entries: entries[1:])
      self.assertIn(b"X-Generator: Poedit 3.9", out)
      self.assertIn(b"PO-Revision-Date: 2026-10-01 21:08+0100", out)
      self.assertTrue(out.startswith(b"# Polish translation, hand-edited header\r\n"))
      self.assertNotIn(b"uappstrings.sone", out)
      self.assertIn(b"uappstrings.stwo", out)

   def test_lf_and_bom_are_preserved(self):
      raw = b"\xef\xbb\xbf" + SAMPLE.replace(b"\r\n", b"\n")
      out = roundtrip_bytes(raw)
      self.assertEqual(out, raw, first_difference(raw, out))

   def test_a_new_catalogue_gets_the_template_header(self):
      # A catalogue built from nothing (pas2po --new-lang) is unchanged by
      # this work: template header, CRLF, one blank line between entries.
      tmp = tempfile.mkdtemp()
      try:
         path = os.path.join(tmp, "tr4w_fi.po")
         pofile.write_po(path, [pofile.Entry("TC_A", "A", "", True, refs=["x.a"])], "fi")
         with open(path, "rb") as fh:
            out = fh.read()
      finally:
         shutil.rmtree(tmp)
      expected = (
         "msgid \"\"\nmsgstr \"\"\n"
         "\"Project-Id-Version: TR4W\\n\"\n"
         "\"PO-Revision-Date: YEAR-MO-DA HO:MI+ZONE\\n\"\n"
         "\"Last-Translator: FULL NAME <EMAIL@ADDRESS>\\n\"\n"
         "\"Language-Team: LANGUAGE <LL@li.org>\\n\"\n"
         "\"MIME-Version: 1.0\\n\"\n"
         "\"Content-Type: text/plain; charset=UTF-8\\n\"\n"
         "\"Content-Transfer-Encoding: 8bit\\n\"\n"
         "\"Language: fi\\n\"\n"
         "\"X-Source-Language: en\\n\"\n"
         "\n"
         "#: x.a\n#, fuzzy\nmsgctxt \"TC_A\"\nmsgid \"A\"\nmsgstr \"\"\n\n"
      ).replace("\n", "\r\n").encode("utf-8")
      self.assertEqual(out, expected, first_difference(expected, out))


if __name__ == "__main__":
   unittest.main(verbosity=2)
