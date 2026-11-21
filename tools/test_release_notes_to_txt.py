"""Tests for release_notes_to_txt.  Run: python -m unittest tools/test_release_notes_to_txt.py"""

import os
import subprocess
import sys
import tempfile
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import release_notes_to_txt as conv  # noqa: E402

REPO = os.path.dirname(HERE)


def lines_of(markdown):
   return conv.convert_text(markdown).split("\r\n")[:-1]


class InlineTests(unittest.TestCase):
   def test_link_keeps_text_and_url(self):
      self.assertEqual(conv.strip_inline("see [the docs](https://x.org/a) now"),
                       "see the docs (https://x.org/a) now")

   def test_link_whose_text_is_the_url_is_not_doubled(self):
      self.assertEqual(conv.strip_inline("[https://x.org](https://x.org)"), "https://x.org")

   def test_bold_code_italic(self):
      self.assertEqual(conv.strip_inline("a **bold** and `code` and *it* z"),
                       "a bold and code and it z")

   def test_lone_asterisk_survives(self):
      self.assertEqual(conv.strip_inline("2 * 3 = 6"), "2 * 3 = 6")

   def test_html_removed(self):
      self.assertEqual(conv.strip_inline("a<br>b <b>c</b>"), "ab c")

   def test_less_than_in_prose_survives(self):
      self.assertEqual(conv.strip_inline("if a < b and c > d"), "if a < b and c > d")


class BlockTests(unittest.TestCase):
   def test_headings(self):
      self.assertEqual(lines_of("# Title\n## Sub\n### Deep"),
                       ["Title", "=====", "", "Sub", "---", "", "Deep"])

   def test_bullets_normalised(self):
      self.assertEqual(lines_of("* one\n- two\n  - nested"), ["- one", "- two", "  - nested"])

   def test_code_fence_indented_and_fence_dropped(self):
      self.assertEqual(lines_of("```pascal\nx := 1;\n```\nafter"), ["    x := 1;", "after"])

   def test_markup_inside_fence_untouched(self):
      self.assertEqual(lines_of("```\n**not bold**\n```"), ["    **not bold**"])

   def test_table_aligned_separator_dropped(self):
      result = lines_of("| Call | N |\n|---|---|\n| N4AF | 346 |\n| NY4I | 7 |")
      self.assertEqual(result, ["Call | N", "N4AF | 346", "NY4I | 7"])

   def test_table_cell_links_converted(self):
      result = lines_of("| a | b |\n|--|--|\n| [x](http://u) | y |")
      self.assertEqual(result[1], "x (http://u) | y")

   def test_rule_and_quote(self):
      self.assertEqual(lines_of("---\n> quoted **b**"), ["-" * conv.RULE_WIDTH, "    quoted b"])

   def test_html_comment_dropped_even_across_lines(self):
      self.assertEqual(lines_of("a\n<!--\nmaintainer note\n-->\n\n\nb"), ["a", "", "b"])

   def test_output_is_crlf_only(self):
      text = conv.convert_text("a\nb\r\nc")
      self.assertNotIn("\n", text.replace("\r\n", ""))
      self.assertTrue(text.endswith("\r\n"))


class FileTests(unittest.TestCase):
   def setUp(self):
      self.tmp = tempfile.TemporaryDirectory()
      self.addCleanup(self.tmp.cleanup)

   def path(self, name):
      return os.path.join(self.tmp.name, name)

   def test_missing_source_fails_and_writes_nothing(self):
      rc = conv.convert_file(self.path("nope.md"), self.path("out.txt"))
      self.assertEqual(rc, 1)
      self.assertFalse(os.path.exists(self.path("out.txt")))

   def test_empty_source_fails(self):
      with open(self.path("e.md"), "wb") as handle:
         handle.write(b"  \n")
      self.assertEqual(conv.convert_file(self.path("e.md"), self.path("out.txt")), 1)

   def test_writes_bom_and_creates_folder(self):
      with open(self.path("a.md"), "wb") as handle:
         handle.write("# T — x\n".encode("utf-8"))
      out = os.path.join(self.tmp.name, "sub", "out.txt")
      self.assertEqual(conv.convert_file(self.path("a.md"), out), 0)
      with open(out, "rb") as handle:
         data = handle.read()
      self.assertTrue(data.startswith(b"\xef\xbb\xbf"))
      self.assertEqual(data[3:].decode("utf-8"), "T — x\r\n=====\r\n")

   def test_command_line_exit_codes(self):
      script = os.path.join(HERE, "release_notes_to_txt.py")
      bad = subprocess.run([sys.executable, "-I", script, self.path("nope.md"), self.path("o.txt")],
                           capture_output=True)
      self.assertEqual(bad.returncode, 1)
      self.assertIn(b"not found", bad.stderr)
      usage = subprocess.run([sys.executable, "-I", script], capture_output=True)
      self.assertEqual(usage.returncode, 2)


class RealNotesTests(unittest.TestCase):
   """The tracked RELEASE_NOTES.md converts, and nothing markdown-shaped is left."""

   def test_real_release_notes(self):
      source = os.path.join(REPO, "RELEASE_NOTES.md")
      out = os.path.join(tempfile.mkdtemp(), "RELEASE_NOTES.txt")
      self.assertEqual(conv.convert_file(source, out), 0)
      with open(out, "rb") as handle:
         text = handle.read().decode("utf-8-sig")
      self.assertTrue(text.startswith("TR4W Release Notes\r\n=====\r\n") or
                      text.startswith("TR4W Release Notes\r\n==="))
      self.assertGreater(len(text.splitlines()), 500)
      for line in text.splitlines():
         self.assertFalse(line.startswith("#"), line)
         self.assertNotIn("](", line)
         self.assertNotIn("**", line)


if __name__ == "__main__":
   unittest.main()
