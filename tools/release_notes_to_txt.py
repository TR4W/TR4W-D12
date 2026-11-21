"""Convert RELEASE_NOTES.md into a plain-text file the installer ships.

   usage: release_notes_to_txt.py <RELEASE_NOTES.md> <out.txt>

The installer puts a "Release notes" shortcut in the Start-menu group, and
Notepad cannot show markdown readably.  This is run by build\\Build-Installer.ps1
on every installer build, so a release can never carry a stale or missing file.

It fails (non-zero exit, message on stderr) when the .md is missing or empty,
so a broken path stops the build rather than shipping an empty shortcut target.

Output: UTF-8 with a BOM (older Notepad guesses the code page without one and
mangles the dashes), CRLF line endings.

What is done to the markup, and what is deliberately left alone:
   # Heading        text, underlined with = (level 1) or - (level 2);
                    deeper levels are plain text with a blank line before
   - / * bullet     "- " (continuation lines keep their indent)
   [text](url)      "text (url)"; just "text" when the text IS the url
   **bold**         bold removed; `code` backticks removed
   ``` fence        fence lines dropped, the code indented four spaces
   | table |        pipes kept, columns padded to line up, separator row dropped
   > quote          four-space indent
   --- rule         a line of dashes
   HTML tags        removed
"""

import os
import re
import sys

RULE_WIDTH = 72

_IMAGE = re.compile(r"!\[([^\]]*)\]\(([^)\s]+)[^)]*\)")
_LINK = re.compile(r"\[([^\]]+)\]\(([^)\s]+)[^)]*\)")
_AUTOLINK = re.compile(r"<(https?://[^>\s]+)>")
_BOLD = re.compile(r"(\*\*|__)(?=\S)(.+?)(?<=\S)\1")
_ITALIC = re.compile(r"(?<![\w*])\*(?!\s)([^*\n]+?)(?<!\s)\*(?![\w*])")
_CODE = re.compile(r"`+([^`]+)`+")
_HTML = re.compile(r"</?[A-Za-z][^>]*>")
_HEADING = re.compile(r"^(#{1,6})\s+(.*?)\s*#*\s*$")
_BULLET = re.compile(r"^(\s*)[-*+]\s+(.*)$")
_HRULE = re.compile(r"^\s*([-*_])(\s*\1){2,}\s*$")
_TABLE_SEPARATOR = re.compile(r"^\s*\|?\s*:?-{2,}:?\s*(\|\s*:?-{2,}:?\s*)*\|?\s*$")


def _link_text(match):
   text = match.group(1)
   url = match.group(2)
   if text == url:
      return url
   return "%s (%s)" % (text, url)


def _image_text(match):
   alt = match.group(1)
   url = match.group(2)
   if alt == "":
      return url
   return "%s (%s)" % (alt, url)


def strip_inline(text):
   """Remove inline markup from one line of prose."""
   text = _IMAGE.sub(_image_text, text)
   text = _LINK.sub(_link_text, text)
   text = _AUTOLINK.sub(r"\1", text)
   text = _CODE.sub(r"\1", text)
   text = _BOLD.sub(r"\2", text)
   # A bold span that wraps onto the next line leaves a lone marker on each.
   text = text.replace("**", "")
   text = _ITALIC.sub(r"\1", text)
   text = _HTML.sub("", text)
   return text


def _split_row(line):
   cells = line.strip()
   if cells.startswith("|"):
      cells = cells[1:]
   if cells.endswith("|"):
      cells = cells[:-1]
   return [strip_inline(cell.strip()) for cell in cells.split("|")]


def _format_table(rows):
   """rows: list of lists of cell text, separator row already removed."""
   width = max(len(row) for row in rows)
   for row in rows:
      while len(row) < width:
         row.append("")
   widths = [max(len(row[i]) for row in rows) for i in range(width)]
   result = []
   for row in rows:
      cells = [row[i].ljust(widths[i]) for i in range(width)]
      result.append(" | ".join(cells).rstrip())
   return result


def convert_lines(lines):
   """Turn the lines of a markdown document into the lines of the text file."""
   out = []
   in_fence = False
   table = []

   def flush_table():
      if table:
         out.extend(_format_table(table))
         del table[:]

   for raw in lines:
      line = raw.rstrip()

      if line.lstrip().startswith("```"):
         flush_table()
         in_fence = not in_fence
         continue
      if in_fence:
         out.append(("    " + line).rstrip())
         continue

      if line.lstrip().startswith("|"):
         if not _TABLE_SEPARATOR.match(line):
            table.append(_split_row(line))
         continue
      flush_table()

      heading = _HEADING.match(line)
      if heading:
         level = len(heading.group(1))
         text = strip_inline(heading.group(2))
         if out and out[-1] != "":
            out.append("")
         out.append(text)
         if level == 1:
            out.append("=" * max(len(text), 3))
         elif level == 2:
            out.append("-" * max(len(text), 3))
         continue

      if _HRULE.match(line):
         out.append("-" * RULE_WIDTH)
         continue

      if line.startswith(">"):
         quoted = line.lstrip(">").lstrip()
         out.append(("    " + strip_inline(quoted)).rstrip())
         continue

      bullet = _BULLET.match(line)
      if bullet:
         out.append("%s- %s" % (bullet.group(1), strip_inline(bullet.group(2))))
         continue

      out.append(strip_inline(line))

   flush_table()
   return out


def convert_text(markdown):
   """Whole-document form of convert_lines; returns text with CRLF endings."""
   markdown = markdown.replace("\r\n", "\n").replace("\r", "\n")
   # Maintainer notes live in HTML comments (the changelog baseline marker,
   # how to cut a release); they are not for the reader and span lines.
   markdown = re.sub(r"<!--.*?-->", "", markdown, flags=re.DOTALL)
   converted = convert_lines(markdown.split("\n"))
   out = []
   for line in converted:
      if line == "" and (not out or out[-1] == ""):
         continue
      out.append(line)
   while out and out[-1] == "":
      out.pop()
   return "\r\n".join(out) + "\r\n"


def convert_file(source, destination):
   """Returns 0 on success; prints the reason on stderr and returns 1 on failure."""
   if not os.path.isfile(source):
      sys.stderr.write("release_notes_to_txt: source not found: %s\n" % source)
      return 1
   with open(source, "rb") as handle:
      data = handle.read()
   try:
      markdown = data.decode("utf-8-sig")
   except UnicodeDecodeError as err:
      sys.stderr.write("release_notes_to_txt: %s is not UTF-8: %s\n" % (source, err))
      return 1
   if markdown.strip() == "":
      sys.stderr.write("release_notes_to_txt: source is empty: %s\n" % source)
      return 1
   text = convert_text(markdown)
   folder = os.path.dirname(os.path.abspath(destination))
   if not os.path.isdir(folder):
      os.makedirs(folder)
   with open(destination, "wb") as handle:
      handle.write(b"\xef\xbb\xbf" + text.encode("utf-8"))
   return 0


def main(argv):
   if len(argv) != 3:
      sys.stderr.write("usage: release_notes_to_txt.py <RELEASE_NOTES.md> <out.txt>\n")
      return 2
   return convert_file(argv[1], argv[2])


if __name__ == "__main__":
   sys.exit(main(sys.argv))
