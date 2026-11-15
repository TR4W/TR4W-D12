"""pas2res -- the reference scan behind `--unreferenced` (issues 144 and 158).

Run:  python tools/i18n/test_pas2res.py        (exit 0 = pass)

WHY THIS EXISTS. pas2res decides whether a TC_/RC_ constant is used by
searching the Pascal sources for its name. The scan it uses to EMIT the unit
reads its own output (uTR4WStrings.pas), the backup/ folders and every
comment, so no constant can ever look unused (issue 144, point 5). The
corrected scan behind `--unreferenced` must not swing the other way and call a
used constant dead: a name inside a string literal IS a use (catalogue
identifiers such as 'utr4wstrings.tc_translation_author'), and `//` inside a
URL is not a comment.

WHAT IT PINS
  * all three comment forms are blanked, unterminated ones to the end;
  * a string literal survives whole, `//` and `{` inside it included;
  * referenced_names skips a named directory, a named file and comments, and
    matches case-insensitively on a whole word;
  * the emitting rule (code_referenced_rc) is UNCHANGED: a comment still counts.
"""

import os
import shutil
import sys
import tempfile
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import pas2res   # noqa: E402


class StripComments(unittest.TestCase):

   def test_each_comment_form_is_blanked(self):
      text = "a { TC_ONE } b (* TC_TWO *) c // TC_THREE\nd"
      out = pas2res.strip_pascal_comments(text)
      for name in ("TC_ONE", "TC_TWO", "TC_THREE"):
         self.assertNotIn(name, out)
      for kept in ("a", "b", "c", "\nd"):
         self.assertIn(kept, out)

   def test_a_string_literal_survives_whole(self):
      text = "x := 'http://host/{TC_KEY}'; y := TC_AFTER;"
      out = pas2res.strip_pascal_comments(text)
      self.assertIn("'http://host/{TC_KEY}'", out)
      self.assertIn("TC_AFTER", out)

   def test_a_doubled_quote_does_not_open_a_comment(self):
      out = pas2res.strip_pascal_comments("s := 'it''s // not'; TC_LIVE;")
      self.assertIn("TC_LIVE", out)

   def test_an_unterminated_comment_runs_to_the_end(self):
      out = pas2res.strip_pascal_comments("a (* TC_GONE\nTC_ALSO_GONE")
      self.assertNotIn("TC_GONE", out)
      self.assertNotIn("TC_ALSO_GONE", out)


class ReferencedNames(unittest.TestCase):

   def setUp(self):
      self.root = tempfile.mkdtemp(prefix="pas2res_test_")
      self.write("src/uLive.pas",
                 "x := tc_used;  // TC_COMMENTED\n"
                 "y := 'utr4wstrings.tc_in_string';\n")
      self.write("src/uTR4WStrings.pas", "TC_SELF = 'only declared here';\n")
      self.write("src/backup/uLive.pas", "x := TC_BACKUP;\n")
      self.write("test/uTestX.pas", "x := TC_TESTED;\n")

   def tearDown(self):
      shutil.rmtree(self.root)

   def write(self, rel, text):
      path = os.path.join(self.root, *rel.split("/"))
      os.makedirs(os.path.dirname(path), exist_ok=True)
      with open(path, "w", encoding="utf-8", newline="\r\n") as fh:
         fh.write(text)

   NAMES = {"TC_USED", "TC_COMMENTED", "TC_IN_STRING", "TC_SELF", "TC_BACKUP",
            "TC_TESTED", "TC_NOWHERE", "TC_USE"}

   def test_the_corrected_scan(self):
      used = pas2res.referenced_names([self.root], self.NAMES,
                                      skip_dirs=["backup"],
                                      skip_files={"utr4wstrings.pas"},
                                      strip_comments=True)
      self.assertEqual(used, {"TC_USED", "TC_IN_STRING", "TC_TESTED"})

   def test_the_emitting_rule_is_unchanged(self):
      # code_referenced_rc reads src/ only, comments, itself and backup/ included.
      src = os.path.join(self.root, "src")
      lang = os.path.join(src, "lang")
      used = pas2res.code_referenced_rc(src, lang, self.NAMES)
      self.assertEqual(used, {"TC_USED", "TC_COMMENTED", "TC_IN_STRING",
                              "TC_SELF", "TC_BACKUP"})


if __name__ == "__main__":
   unittest.main()
