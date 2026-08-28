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

Plural forms are NOT implemented. TR4W has no plural-sensitive strings today,
and guessing at plural rules for ten languages would be worse than not having
them. If one appears, add it here rather than working around it at a call site.
"""

import os
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
                refs=None, obsolete=False):
      self.key = key                 # msgctxt
      self.source = source           # msgid
      self.target = target           # msgstr
      self.fuzzy = fuzzy
      self.notes = notes or []       # #.
      self.refs = refs or []         # #:
      self.obsolete = obsolete       # #~

   @property
   def translated(self):
      """Usable text: non-empty and not awaiting review."""
      return bool(self.target.strip()) and not self.fuzzy and not self.obsolete


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


def write_po(path, entries, language, source_language="en", project=None):
   """Write a .po file. `entries` is an ordered iterable of Entry."""
   out = []
   out.append('msgid ""\n')
   out.append('msgstr ""\n')
   # The date/translator/team fields are gettext's own template placeholders.
   # msgfmt warns if they are absent; a real timestamp would make every
   # regeneration churn the whole file, so leave them for Poedit to fill in.
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
   for line in header:
      out.append('"%s"\n' % line)
   out.append("\n")

   for e in entries:
      for note in e.notes:
         out.append("#. %s\n" % note)
      for ref in e.refs:
         out.append("#: %s\n" % ref)
      if e.fuzzy:
         out.append("#, fuzzy\n")
      prefix = "#~ " if e.obsolete else ""
      if e.key:
         out.append(prefix + _emit_string("msgctxt", e.key))
      out.append(prefix + _emit_string("msgid", e.source))
      out.append(prefix + _emit_string("msgstr", e.target))
      out.append("\n")

   # CRLF: .gitattributes is `* text=auto eol=crlf` for this tree.
   text = "".join(out).replace("\n", "\r\n")
   with open(path, "wb") as fh:
      fh.write(text.encode("utf-8"))


def read_po(path):
   """Parse a .po file into a list of Entry. The header entry is skipped."""
   if not os.path.exists(path):
      return []
   with open(path, "rb") as fh:
      raw = fh.read()
   if raw.startswith(b"\xef\xbb\xbf"):
      raw = raw[3:]
   text = raw.decode("utf-8").replace("\r\n", "\n")

   entries = []
   cur = {"notes": [], "refs": [], "fuzzy": False, "obsolete": False}
   field = None
   parts = {"msgctxt": [], "msgid": [], "msgstr": []}

   def flush():
      if not parts["msgid"] and not parts["msgctxt"]:
         return
      key = unescape("".join(parts["msgctxt"]))
      src = unescape("".join(parts["msgid"]))
      dst = unescape("".join(parts["msgstr"]))
      if src or key:                      # skip the header (empty msgid, no ctxt)
         entries.append(Entry(key, src, dst, cur["fuzzy"], list(cur["notes"]),
                              list(cur["refs"]), cur["obsolete"]))

   for line in text.split("\n"):
      stripped = line.strip()
      if not stripped:
         flush()
         cur = {"notes": [], "refs": [], "fuzzy": False, "obsolete": False}
         parts = {"msgctxt": [], "msgid": [], "msgstr": []}
         field = None
         continue
      body = stripped
      if body.startswith("#~"):
         cur["obsolete"] = True
         body = body[2:].strip()
      if body.startswith("#."):
         cur["notes"].append(body[2:].strip())
         continue
      if body.startswith("#:"):
         cur["refs"].append(body[2:].strip())
         continue
      if body.startswith("#,"):
         cur["fuzzy"] = "fuzzy" in body
         continue
      if body.startswith("#"):
         continue
      m = re.match(r'^(msgctxt|msgid|msgstr)\s+"(.*)"$', body)
      if m:
         field = m.group(1)
         parts[field] = [m.group(2)]
         continue
      m = re.match(r'^"(.*)"$', body)
      if m and field:
         parts[field].append(m.group(1))
   flush()
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
