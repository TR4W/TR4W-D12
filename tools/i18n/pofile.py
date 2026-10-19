"""Minimal GNU gettext .po reader and writer for TR4W's catalogues.

.po is the master format: FPC/Lazarus load it at run time, Poedit is a gettext
tool, and Poedit bundles msgfmt/msgmerge so the catalogues get real validation
and real fuzzy-matching on source changes.

Only the subset TR4W needs is implemented, deliberately:

  msgctxt  the STABLE KEY -- the Pascal constant name (TC_ISADUPE). gettext
           identity is (msgctxt, msgid), so putting the key here means an
           English wording fix does not orphan ten translations. When the
           resourcestrings are declared this becomes FPC's own
           `unitname.identifier` form; the re-key is mechanical.
  msgid    the English source text.
  msgstr   the translation.
  #,fuzzy  needs review. This is what Poedit shows as "Needs work" and it is
           the gate: nothing fuzzy is ever written back into Pascal.
  #.       translator note (extracted comment).
  #:       source reference.
  #~       obsolete -- a key that no longer exists in the source.

  #        translator comment -- kept, never interpreted.
  #|       previous msgid -- kept, never interpreted.

Plural forms are NOT implemented. TR4W has no plural-sensitive strings today,
and guessing at plural rules for ten languages would be worse than not having
them. If one appears, add it here rather than working around it at a call site.

A REWRITE IS LOSSLESS (2026-10-18). Every catalogue tool reads with read_po and
writes with write_po, so this module decides what a rewrite can destroy. It
used to rebuild every entry from its parsed fields and the header from
gettext's template, which silently dropped every '# ' translator comment --
the dated audit notes, the provenance of each author credit -- and G0DVJ's
Poedit header in Polish. Now each entry read from a file remembers its exact
text and the fields it was parsed into; write_po emits that text VERBATIM
unless a caller changed a field, and only then re-renders the entry, keeping
its translator comments, flags and previous-msgid lines. The header, the
blank lines and comment-only blocks between entries, a BOM and the line
endings come back exactly as read. test_pofile.py pins it: all 22 catalogues
round-trip byte-identical.
"""

import os
import html
import re

# gettext escapes a C string. \r matters to us: 11 TR4W values embed #13.
_ESCAPES = {
   "\\": "\\\\", '"': '\\"', "\n": "\\n", "\t": "\\t", "\r": "\\r",
}
_UNESCAPES = {
   "\\": "\\", '"': '"', "n": "\n", "t": "\t", "r": "\r", "a": "\a",
   "b": "\b", "f": "\f", "v": "\v", "0": "\0",
}


class Entry:
   """One catalogue entry."""

   def __init__(self, key, source, target="", fuzzy=False, notes=None,
                refs=None, obsolete=False, comments=None, flags=None,
                previous=None):
      self.key = key                 # msgctxt
      self.source = source           # msgid
      self.target = target           # msgstr
      self.fuzzy = fuzzy
      self.notes = notes or []       # #.
      self.refs = refs or []         # #:
      self.obsolete = obsolete       # #~
      self.comments = comments or [] # '# ' lines, whole, as written
      self.flags = flags or []       # #, flags OTHER than fuzzy, e.g. object-pascal-format
      self.previous = previous or [] # '#|' lines, whole, as written

      # Where this entry came from, when read_po made it: the catalogue it
      # belongs to, the text before it (blank lines, comment-only blocks),
      # its own exact text, and the fields that text parsed into. write_po
      # uses the text verbatim while the fields still match. None for an
      # entry a caller constructs.
      self._source = None
      self._lead = None
      self._raw = None
      self._snap = None

   def _state(self):
      """Every field write_po would render, so a change to any of them is seen."""
      return (self.key, self.source, self.target, bool(self.fuzzy),
              tuple(self.notes), tuple(self.refs), bool(self.obsolete),
              tuple(self.comments), tuple(self.flags), tuple(self.previous))

   @property
   def translated(self):
      """Usable text: non-empty and not awaiting review."""
      return bool(self.target.strip()) and not self.fuzzy and not self.obsolete


class _Catalogue:
   """What a file holds besides its entries: the header block exactly as
   written (with anything before it), the text after the last entry, the
   line ending to give a NEW entry, and whether the file had a BOM."""

   def __init__(self, header, tail, newline, bom):
      self.header = header
      self.tail = tail
      self.newline = newline
      self.bom = bom


def escape(text):
   out = []
   for ch in text:
      esc = _ESCAPES.get(ch)
      if esc is not None:
         out.append(esc)
      elif ord(ch) < 32 or ord(ch) == 127:
         out.append("\\%03o" % ord(ch))
      else:
         out.append(ch)
   return "".join(out)


def unescape(text):
   out = []
   i = 0
   n = len(text)
   while i < n:
      ch = text[i]
      if ch != "\\":
         out.append(ch)
         i += 1
         continue
      i += 1
      if i >= n:
         break
      nxt = text[i]
      # Octal escape -- what escape() emits for a control character it has no
      # named form for. Always digits 0-7, up to three of them.
      if nxt in "01234567":
         m = re.match(r"[0-7]{1,3}", text[i:])
         out.append(chr(int(m.group(0), 8)))
         i += len(m.group(0))
         continue
      out.append(_UNESCAPES.get(nxt, nxt))
      i += 1
   return "".join(out)


def _emit_string(label, text):
   """Render `label "..."`, splitting on embedded newlines as gettext does."""
   if "\n" not in text:
      return '%s "%s"\n' % (label, escape(text))
   parts = text.split("\n")
   lines = ['%s ""\n' % label]
   for i, part in enumerate(parts):
      tail = "" if i == len(parts) - 1 else "\\n"
      if part == "" and tail == "":
         continue
      lines.append('"%s%s"\n' % (escape(part), tail))
   return "".join(lines)


def _template_header(language, source_language, project):
   """The header a catalogue built from nothing gets. Ends at the header's
   last line; the blank line after it is the first entry's separator."""
   # The date/translator/team fields are gettext's own template placeholders.
   # msgfmt warns if they are absent; a real timestamp would make every
   # regeneration churn the whole file, so leave them for Poedit to fill in.
   # An EXISTING catalogue keeps its own header -- see write_po.
   header = [
      "Project-Id-Version: %s\\n" % (project or "TR4W"),
      "PO-Revision-Date: YEAR-MO-DA HO:MI+ZONE\\n",
      "Last-Translator: FULL NAME <EMAIL@ADDRESS>\\n",
      "Language-Team: LANGUAGE <LL@li.org>\\n",
      "MIME-Version: 1.0\\n",
      "Content-Type: text/plain; charset=UTF-8\\n",
      "Content-Transfer-Encoding: 8bit\\n",
      "Language: %s\\n" % language,
      "X-Source-Language: %s\\n" % source_language,
   ]
   return 'msgid ""\nmsgstr ""\n' + "".join('"%s"\n' % line for line in header)


def _render(e):
   """An entry from its fields, LF line endings. Used for an entry a caller
   built or changed; an unchanged entry is written from its own text."""
   out = []
   for line in e.comments:
      out.append(line + "\n")
   for note in e.notes:
      out.append("#. %s\n" % note)
   for ref in e.refs:
      out.append("#: %s\n" % ref)
   flags = (["fuzzy"] if e.fuzzy else []) + list(e.flags)
   if flags:
      out.append("#, %s\n" % ", ".join(flags))
   for line in e.previous:
      out.append(line + "\n")
   prefix = "#~ " if e.obsolete else ""
   if e.key:
      out.append(prefix + _emit_string("msgctxt", e.key))
   out.append(prefix + _emit_string("msgid", e.source))
   out.append(prefix + _emit_string("msgstr", e.target))
   return "".join(out)


def write_po(path, entries, language, source_language="en", project=None):
   """Write a .po file. `entries` is an ordered iterable of Entry.

   LOSSLESS FOR WHAT read_po READ. When the entries came from read_po, the
   file's own header, BOM, line endings, inter-entry text and trailing text
   are written back as read, and each entry is written from its own text
   unless one of its fields was changed. `language`, `source_language` and
   `project` then name nothing: they only fill the template header of a
   catalogue built from entries a caller constructed (pas2po --new-lang).

   The catalogue is the one the FIRST read entry came from. Entries from any
   other file keep their own text; new entries get that catalogue's line
   ending, or CRLF -- .gitattributes is `* text=auto eol=crlf` for this tree.
   """
   entries = list(entries)
   cat = next((e._source for e in entries if e._source is not None), None)
   if cat is not None:
      newline = cat.newline
      out = [cat.header]
      tail = cat.tail
      bom = cat.bom
   else:
      newline = "\r\n"
      out = [_template_header(language, source_language, project).replace("\n", newline)]
      tail = newline
      bom = False

   for e in entries:
      if e._raw is not None and e._state() == e._snap:
         out.append(e._lead)
         out.append(e._raw)
         continue
      nl = e._source.newline if e._source is not None else newline
      if e._raw is not None:
         lead = e._lead                  # a changed entry keeps its place's spacing
      else:
         lead = nl                       # a new entry: one blank line before it
         # A file whose last line had no line ending would glue this entry to
         # it; give that line its ending first.
         if out and out[-1] and not out[-1].endswith("\n"):
            out.append(nl)
      out.append(lead)
      out.append(_render(e).replace("\n", nl))
   out.append(tail)

   data = "".join(out).encode("utf-8")
   with open(path, "wb") as fh:
      if bom:
         fh.write(b"\xef\xbb\xbf")
      fh.write(data)


def _parse_block(lines):
   """The fields of one block of non-blank lines, as the reader has always
   parsed them -- or None when the block holds no msgid or msgctxt line (a
   comment-only block). Returns (entry_or_None, had_message): an entry is
   None with had_message True for the header (empty msgid, no msgctxt)."""
   notes, refs, comments, flags, previous = [], [], [], [], []
   fuzzy = obsolete = False
   field = None
   parts = {"msgctxt": [], "msgid": [], "msgstr": []}

   for line in lines:
      whole = line.rstrip("\r\n")
      body = whole.strip()
      if body.startswith("#~"):
         obsolete = True
         body = body[2:].strip()
      if body.startswith("#."):
         notes.append(body[2:].strip())
         continue
      if body.startswith("#:"):
         refs.append(body[2:].strip())
         continue
      if body.startswith("#,"):
         fuzzy = "fuzzy" in body
         flags.extend(f.strip() for f in body[2:].split(",")
                      if f.strip() and f.strip() != "fuzzy")
         continue
      if body.startswith("#|"):
         previous.append(whole)
         continue
      if body.startswith("#"):
         comments.append(whole)
         continue
      m = re.match(r'^(msgctxt|msgid|msgstr)\s+"(.*)"$', body)
      if m:
         field = m.group(1)
         parts[field] = [m.group(2)]
         continue
      m = re.match(r'^"(.*)"$', body)
      if m and field:
         parts[field].append(m.group(1))

   if not parts["msgid"] and not parts["msgctxt"]:
      return None, False
   key = unescape("".join(parts["msgctxt"]))
   src = unescape("".join(parts["msgid"]))
   dst = unescape("".join(parts["msgstr"]))
   if not (src or key):                  # the header (empty msgid, no ctxt)
      return None, True
   return Entry(key, src, dst, fuzzy, notes, refs, obsolete,
                comments, flags, previous), True


def read_po(path):
   """Parse a .po file into a list of Entry. The header entry is skipped.

   Each entry also carries its exact text and its catalogue's header, BOM,
   line endings and trailing text, so write_po can put the file back as it
   was. The parsed fields are what they have always been."""
   if not os.path.exists(path):
      return []
   with open(path, "rb") as fh:
      raw = fh.read()
   bom = raw.startswith(b"\xef\xbb\xbf")
   if bom:
      raw = raw[3:]
   text = raw.decode("utf-8")

   # The line ending a NEW entry gets: whichever this file mostly uses.
   crlf = text.count("\r\n")
   newline = "\r\n" if crlf >= text.count("\n") - crlf else "\n"

   # Runs of blank and non-blank lines, every line keeping its own ending, so
   # joining the runs gives back the file exactly. Split on LF ONLY:
   # str.splitlines also breaks at U+0085, U+2028, form feed and others, which
   # a translation may contain, and would cut an entry in two.
   runs = []
   for line in re.findall(r"[^\n]*\n|[^\n]+$", text):
      blank = not line.strip()
      if runs and runs[-1][0] == blank:
         runs[-1][1].append(line)
      else:
         runs.append((blank, [line]))

   entries = []
   header = None
   pending = ""
   for blank, lines in runs:
      chunk = "".join(lines)
      if blank:
         pending += chunk
         continue
      entry, had_message = _parse_block(lines)
      if entry is None:
         if had_message and header is None and not entries:
            header = pending + chunk     # the header, and anything before it
            pending = ""
         else:
            pending += chunk             # a comment-only block: travels with the next entry
         continue
      entry._lead = pending
      entry._raw = chunk
      entry._snap = entry._state()
      entries.append(entry)
      pending = ""

   cat = _Catalogue(header if header is not None else "", pending, newline, bom)
   for e in entries:
      e._source = cat
   return entries


def by_key(entries):
   return {e.key: e for e in entries if e.key and not e.obsolete}

def lcl_catalogue(lang):
   """The LCL's OWN translations for this language, by English text.

   Standard buttons -- OK, Cancel, Yes, No, Close, Help -- are the widget
   set's, not ours. Lazarus ships lclstrconsts.<lang>.po translated by the
   people who maintain it, so asking a machine translator for 'OK' is both
   wasted and worse: Argos returns 'OK' and Spanish wants 'Aceptar'.

   Returns {english_lowercased_without_ampersand: translation}, or {} when the
   language has no LCL catalogue -- which is not an error, just a language
   Lazarus has not been translated into.
   """
   import os
   out = {}
   for root in (os.environ.get('LAZARUS_DIR'), r'C:/lazarus', '/usr/share/lazarus'):
      if not root:
         continue
      path = os.path.join(root, 'lcl', 'languages', 'lclstrconsts.%s.po' % lang)
      if not os.path.exists(path):
         continue
      for e in read_po(path):
         if e.source.strip() and e.target.strip() and not e.obsolete:
            out[e.source.replace('&', '').strip().lower()] = e.target
      break
   return out

# ---------------------------------------------------------------- HTML entities

# WHY A CATALOGUE EVER CONTAINS ONE. LibreTranslate's French model renders the
# space before a colon -- correct French typography -- as the HTML entity
# `&#160;`, and something in the round trip has been putting a space inside it,
# so what lands in the .po is the literal text `& #160;`. TR4W paints that
# verbatim: 'Saisissez votre nom & #160;:'. 24 French entries carried it.
#
# Tolerating the stray space is the point; a strict `&#\d+;` finds none of them.
_ENTITY = re.compile(r"&\s*(#\d+|#x[0-9a-fA-F]+|nbsp|amp|quot|lt|gt|apos)\s*;")


def unescape_entities(text):
   """Turn HTML entities in caption text back into the characters they name.

   `&amp;` becomes `&&` rather than `&`, because in a caption a lone ampersand
   is an ACCELERATOR marker -- unescaping it naively would silently invent a
   keyboard shortcut on whatever letter followed."""
   def one(m):
      name = m.group(1)
      if name == "amp":
         return "&&"
      return html.unescape("&%s;" % name)
   return _ENTITY.sub(one, text)
