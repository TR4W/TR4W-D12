"""Shared parser for TR4W's language constant include fragments.

`tr4w/src/lang/tr4w_consts_<lang>.pas` are NOT units -- they are `{$INCLUDE}`
fragments: a bare `const` keyword followed by one declaration per physical line.
That makes a line-oriented parser correct and sufficient. See
`docs/I18N_TS_EVALUATION.md` for the format decision this supports.

Hazards this module exists to handle (all confirmed against real files):

  1. Commented-out declarations   `//  TC_FILE = 'File';`
  2. Trailing comments that carry real translator context
                                  `TC_M = 'm'; //minute`
  3. Doubled-quote escapes        `'...one radio''s CONTROL PORT...'`
  4. `#13` concatenation          `'...version.'#13'TR4W is expecting...'`
  5. Declarations at column 0 mixed in among indented ones, and `TC_`/`RC_`
     interleaved -- so neither indentation nor position may be used to classify.

Every declaration is captured as a `Decl` that remembers the exact byte spans of
the original line, so a caller can replace *only* the string expression and leave
indentation, alignment, trailing comments and neighbouring `RC_` lines untouched.
"""

import os
import re

# A declaration line: indent, name, the '=' run, then the value expression.
# The expression is deliberately NOT matched here -- it is scanned by
# parse_string_expr, because a Pascal literal may contain ';' and '//'.
_DECL_RE = re.compile(r"^(\s*)([A-Za-z_]\w*)(\s*=\s*)")

# A section banner, e.g. {MAIN} or {FD Additions NY4I}. Single-line braces only.
_BANNER_RE = re.compile(r"^\s*\{([^{}]*)\}\s*$")

DEFAULT_CONTEXT = "General"


class ParseError(Exception):
   pass


def is_section_banner(label):
   """True if a `{...}` comment is a section heading rather than prose.

   Real banners are unit-ish names: {MAIN}, {UTELNET}, {FD Additions NY4I}.
   The file also contains the %s/%c/%d/%u header notes and at least one stray
   sentence -- eng line 91, "{This version TR4W v.4.009 beta was build in ...}"
   -- which must NOT become a context, or it shows up in Qt Linguist's context
   pane as a garbage entry.
   """
   if not label or label.startswith("%"):
      return False
   if len(label) > 40:
      return False
   # Sentence punctuation means prose, not a heading.
   return not any(ch in label for ch in ".?!")


class Decl:
   """One `NAME = 'value';` declaration, with the spans needed to rewrite it."""

   def __init__(self, name, value, comment, context, lineno, line,
                expr_start, expr_end):
      self.name = name
      self.value = value              # decoded: '' -> ', #13 -> \n
      self.comment = comment          # trailing // text, or None
      self.context = context          # nearest preceding banner
      self.lineno = lineno            # 1-based
      self.line = line                # original line, newline stripped
      self.expr_start = expr_start    # byte span of the value expression
      self.expr_end = expr_end

   def rewrite(self, new_value):
      """Return this line with only the value expression replaced."""
      return (self.line[:self.expr_start]
              + encode_string_expr(new_value)
              + self.line[self.expr_end:])


def parse_string_expr(text, pos):
   """Scan a Pascal string expression at `text[pos:]`.

   Handles a run of quoted literals and #NN / #$HH character codes, optionally
   joined by '+'. Returns (decoded_value, end_pos). Raises ParseError if the
   text at `pos` does not begin a string expression.
   """
   out = []
   end = pos
   n = len(text)
   i = pos
   seen = False

   while i < n:
      c = text[i]

      if c == "'":
         i += 1
         buf = []
         closed = False
         while i < n:
            if text[i] == "'":
               # A doubled quote is an escaped apostrophe, not a terminator.
               if i + 1 < n and text[i + 1] == "'":
                  buf.append("'")
                  i += 2
                  continue
               i += 1
               closed = True
               break
            buf.append(text[i])
            i += 1
         if not closed:
            raise ParseError("unterminated string literal")
         out.append("".join(buf))
         seen = True
         end = i

      elif c == "#":
         m = re.match(r"#(\$[0-9A-Fa-f]+|\d+)", text[i:])
         if not m:
            break
         tok = m.group(1)
         code = int(tok[1:], 16) if tok.startswith("$") else int(tok)
         out.append(chr(code))
         i += m.end()
         seen = True
         end = i

      elif c in " \t+":
         # Only skip separators if a further part follows on this line.
         j = i
         while j < n and text[j] in " \t+":
            j += 1
         if j < n and (text[j] == "'" or text[j] == "#"):
            i = j
            continue
         break

      else:
         break

   if not seen:
      raise ParseError("not a string expression")
   return "".join(out), end


def encode_string_expr(value):
   """Render a Python string as a Pascal string expression.

   Control characters become #NN parts; everything else goes in quoted runs with
   apostrophes doubled. Inverse of parse_string_expr for all values we produce.
   """
   if value == "":
      return "''"

   parts = []
   buf = []
   for ch in value:
      if ord(ch) < 32 or ord(ch) == 127:
         if buf:
            parts.append("'" + "".join(buf).replace("'", "''") + "'")
            buf = []
         parts.append("#%d" % ord(ch))
      else:
         buf.append(ch)
   if buf:
      parts.append("'" + "".join(buf).replace("'", "''") + "'")
   return "".join(parts)


def split_trailing_comment(suffix):
   """Pull a trailing `//` comment out of the text after the value expression.

   `suffix` starts after the string expression, so any `//` in it is a real
   comment -- quotes have already been consumed by parse_string_expr.
   """
   idx = suffix.find("//")
   if idx < 0:
      return None
   return suffix[idx + 2:].strip() or None


# The historical per-language codepages, per CLAUDE.md. Only consulted when a
# file is not valid UTF-8; today that is POL and CHN alone.
LEGACY_CODEPAGES = {
   "RUS": "cp1251", "UKR": "cp1251", "MNG": "cp1251",
   "CZE": "cp1250", "ROM": "cp1250", "SER": "cp1250",
   "POL": "cp1250",
   "GER": "cp1252", "ESP": "cp1252", "ENG": "cp1252",
   "CHN": "gbk",
}


def read_lang_file(path):
   """Read a lang fragment, preserving BOM and line-ending information.

   Files are UTF-8 in practice, but two are not: POL is CP1250 and CHN is GBK
   (both are decided-out languages -- see CLAUDE.md). Fall back to the
   documented historical codepage for the language rather than crashing, so the
   validator can still report on them.
   """
   with open(path, "rb") as fh:
      raw = fh.read()

   has_bom = raw.startswith(b"\xef\xbb\xbf")
   if has_bom:
      raw = raw[3:]

   lossy = False
   try:
      text = raw.decode("utf-8")
      encoding = "utf-8"
   except UnicodeDecodeError:
      lang = os.path.basename(path)[len("tr4w_consts_"):][:3].upper()
      encoding = LEGACY_CODEPAGES.get(lang, "cp1252")
      try:
         text = raw.decode(encoding)
      except UnicodeDecodeError:
         # Decodes under NO declared codepage -- the file is genuinely corrupt
         # (CHN today). surrogateescape keeps the bytes intact so nothing is
         # destroyed, and `lossy` tells callers to refuse to process it rather
         # than emit mojibake into a translation file.
         text = raw.decode(encoding, errors="surrogateescape")
         lossy = True

   newline = "\r\n" if "\r\n" in text else "\n"
   lines = text.split("\n")
   lines = [ln[:-1] if ln.endswith("\r") else ln for ln in lines]
   return lines, FileForm(has_bom, newline, encoding, lossy)


class FileForm:
   """How a lang file was encoded on disk, so it can be written back as found."""

   def __init__(self, has_bom, newline, encoding, lossy=False):
      self.has_bom = has_bom
      self.newline = newline
      self.encoding = encoding
      self.lossy = lossy   # decoded only via surrogateescape; do not translate


def write_lang_file(path, lines, form):
   text = form.newline.join(lines)
   raw = text.encode(form.encoding, errors="surrogateescape")
   if form.has_bom:
      raw = b"\xef\xbb\xbf" + raw
   with open(path, "wb") as fh:
      fh.write(raw)


def parse_lang_file(path, prefix="TC_"):
   """Parse a lang fragment into an ordered list of Decl for `prefix` keys.

   Returns (decls, lines, form). Declaration order is the file's own; the
   caller must not assume it matches any other language -- the RUS file is in a
   wholly different order from ENG.
   """
   lines, form = read_lang_file(path)
   decls = []
   context = DEFAULT_CONTEXT

   for lineno, line in enumerate(lines, start=1):
      stripped = line.strip()
      if not stripped:
         continue

      banner = _BANNER_RE.match(line)
      if banner:
         label = banner.group(1).strip()
         if is_section_banner(label):
            context = label
         continue

      # Hazard 1: a commented-out declaration is not a declaration.
      if stripped.startswith("//"):
         continue

      m = _DECL_RE.match(line)
      if not m:
         continue
      name = m.group(2)
      if name.lower() == "const" or not name.startswith(prefix):
         continue

      try:
         value, end = parse_string_expr(line, m.end())
      except ParseError:
         # Not a plain string constant (none exist today, but do not guess).
         continue

      decls.append(Decl(
         name=name,
         value=value,
         comment=split_trailing_comment(line[end:]),
         context=context,
         lineno=lineno,
         line=line,
         expr_start=m.end(),
         expr_end=end,
      ))

   return decls, lines, form


# LANG code in VC.pas -> BCP-47-ish tag used for the .ts filename and the
# TS `language` attribute. Qt writes these with an underscore.
LANG_CODES = {
   "ENG": "en",
   "GER": "de",
   "RUS": "ru",
   "UKR": "uk",
   "CZE": "cs",
   "ROM": "ro",
   "SER": "sr",
   "ESP": "es",
   "MNG": "mn",
   "POL": "pl",
   "CHN": "zh_CN",
   # Not yet in tr4w/src/lang -- a new language starts life as a .ts template
   # produced by `pas2ts.py --new-lang <CODE>`.
   #
   # The three-letter codes are TR4W's own convention (GER not DEU, ESP not
   # SPA), not ISO. FRA is used here rather than the ISO 639-2/B "FRE"; if you
   # prefer FRE for consistency with CZE and ROM, change it BEFORE generating
   # anything -- it names the {$INCLUDE} file and the LANG_xxx define.
   "ITA": "it",
   "FRA": "fr",
}

# Endonym for TC_TRANSLATION_LANGUAGE -- the language's name IN that language.
# The endonym for each built-in LANG. Two of these were here already; the rest
# were added 2026-08-28 so `mt_seed.py --list-languages` can say WHICH language
# a code means. The codes are TR4W's own rather than ISO 639-2 -- POR is
# Portugal and PTB is Brazil -- so a reader has nowhere else to look them up
# (NY4I: "I honestly could not recall the three letter code for port. versus
# brazilian port.").
#
# Languages added through i18n/languages.json carry their own name and override
# anything here.
LANGUAGE_NAMES = {
   "CHN": "ZHONGWEN",
   "CZE": "CESTINA",
   "DAN": "DANSK",
   "DUT": "NEDERLANDS",
   "ENG": "ENGLISH",
   "ESP": "ESPANOL",
   "FIN": "SUOMI",
   "FRA": "FRANCAIS",
   "GER": "DEUTSCH",
   "GRE": "ELLINIKA",
   "ITA": "ITALIANO",
   "JPN": "NIHONGO",
   "KOR": "HANGUGEO",
   "MNG": "MONGOL",
   "POL": "POLSKI",
   "POR": "PORTUGUES (PORTUGAL)",
   "PTB": "PORTUGUES (BRASIL)",
   "ROM": "ROMANA",
   "RUS": "RUSSKIY",
   "SER": "SRPSKI",
   "SWE": "SVENSKA",
   "UKR": "UKRAYINSKA",
}

# Languages added after this file was written live in i18n/languages.json, so
# adding one is a command rather than a source edit. Shape:
#   { "FRA": { "code": "fr", "name": "FRANCAIS" } }
#
# An entry may also carry "deferred": "<reason>". The catalogue is still
# generated and seeded -- that work is cheap to keep and expensive to redo --
# but ts2pas.py refuses to create the .pas, which is the step that would put
# the language into a build.
LANGUAGE_REGISTRY = "languages.json"

# LANG -> reason, populated from the registry.
DEFERRED = {}


def load_language_registry(i18n_dir):
   """Merge i18n/languages.json over the built-in tables. Idempotent."""
   path = os.path.join(i18n_dir, LANGUAGE_REGISTRY)
   if not os.path.exists(path):
      return
   import json
   with open(path, "r", encoding="utf-8") as fh:
      data = json.load(fh)
   for lang, entry in data.items():
      lang = lang.upper()
      if isinstance(entry, str):        # tolerate the short form
         entry = {"code": entry}
      LANG_CODES[lang] = entry["code"]
      if entry.get("name"):
         LANGUAGE_NAMES[lang] = entry["name"]
      if entry.get("deferred"):
         DEFERRED[lang] = entry["deferred"]
      else:
         DEFERRED.pop(lang, None)


def register_language(i18n_dir, lang, code, name=None):
   """Add a language to i18n/languages.json and to the in-memory tables."""
   import json
   path = os.path.join(i18n_dir, LANGUAGE_REGISTRY)
   data = {}
   if os.path.exists(path):
      with open(path, "r", encoding="utf-8") as fh:
         data = json.load(fh)
   entry = {"code": code}
   if name:
      entry["name"] = name
   data[lang.upper()] = entry
   os.makedirs(i18n_dir, exist_ok=True)
   with open(path, "w", encoding="utf-8", newline="\r\n") as fh:
      json.dump(data, fh, indent=3, sort_keys=True, ensure_ascii=False)
      fh.write("\n")
   load_language_registry(i18n_dir)

SOURCE_LANG = "ENG"


def find_lang_files(lang_dir):
   """Map LANG code -> path. Filenames are inconsistently cased on disk."""
   found = {}
   for entry in os.listdir(lang_dir):
      m = re.match(r"^tr4w_consts_([a-z]{3})\.pas$", entry, re.IGNORECASE)
      if m:
         found[m.group(1).upper()] = os.path.join(lang_dir, entry)
   return found


def repo_paths(start=None):
   """Locate the repo root from this file, then the dirs we care about."""
   here = os.path.dirname(os.path.abspath(start or __file__))
   root = os.path.abspath(os.path.join(here, "..", ".."))
   return {
      "root": root,
      "lang": os.path.join(root, "tr4w", "src", "lang"),
      "i18n": os.path.join(root, "i18n"),
   }


# TR4W's `Format` is NOT SysUtils.Format -- it is wsprintfA from user32, bound
# by the overload set at TF.pas:263-285. So the grammar that matters is Win32
# wsprintf: %[-#0][width][.prec]type, type in c C d i s S u x X. There is no
# space flag (allowing one makes "73% of normal duration" parse as a specifier,
# a false positive on real TR4W help text) and NO floating-point types --
# wsprintf does not support %f/%g/%e at all.
#
# This matters more than it looks: wsprintf is unchecked varargs. A translation
# that changes %d to %s makes it dereference an integer as a pointer -- an
# access violation. Nothing in the current Pascal workflow can catch that.
PLACEHOLDER_RE = re.compile(r"%[-#0]*(?:\d+|\*)?(?:\.(?:\d+|\*))?[cCdisSuxX%]")


# --- XML text with characters XML 1.0 cannot carry -------------------------
#
# TC_TELNET is a NUL-separated Win32 string list (fed to TB_ADDSTRING), and
# several strings use #13. XML 1.0 cannot represent U+0000 at all -- not even
# as a numeric character reference -- and a literal CR is silently normalised
# to LF by every conforming parser, which would corrupt #13 on the way back.
#
# Qt's .ts format has a purpose-built element for exactly this: <byte value=/>.
# Use it for NUL, CR and the other C0 controls; keep tab and LF literal because
# they survive parsing unchanged and stay readable in the editor.

def xml_escape_text(value):
   """Render a string as .ts element content, using <byte/> where needed."""
   out = []
   for ch in value:
      code = ord(ch)
      if ch in ("\t", "\n"):
         out.append(ch)
      elif code < 0x20 or code == 0x7F:
         out.append('<byte value="x%02x"/>' % code)
      elif ch == "&":
         out.append("&amp;")
      elif ch == "<":
         out.append("&lt;")
      elif ch == ">":
         out.append("&gt;")
      else:
         out.append(ch)
   return "".join(out)


def xml_read_text(elem):
   """Inverse of xml_escape_text: reassemble text around <byte/> children."""
   if elem is None:
      return None
   parts = [elem.text or ""]
   for child in elem:
      if child.tag == "byte":
         raw = child.get("value", "")
         if raw.startswith("x") or raw.startswith("X"):
            parts.append(chr(int(raw[1:], 16)))
         elif raw:
            parts.append(chr(int(raw)))
      parts.append(child.tail or "")
   return "".join(parts)


def placeholders(value):
   """Ordered list of format specifiers, ignoring the literal '%%' escape."""
   return [p for p in PLACEHOLDER_RE.findall(value) if p != "%%"]


def edge_space(value):
   """The leading and trailing whitespace of a value, as a pair.

   Sixteen ENG values carry one because the code concatenates onto them --
   'Failed to connect to ' is followed straight by the host. It belongs to the
   string's role in the code, not to the language, so it must survive
   translation. Compared as a pair rather than a boolean so ' ' and '  ' are
   not treated as the same thing.
   """
   return (value[:len(value) - len(value.lstrip())],
           value[len(value.rstrip()):])


def specifier_types(value):
   """Just the conversion letters, in order -- what must match across languages.

   Width and precision are a translator's legitimate business (a Cyrillic
   string may need a different column width); the TYPE and ORDER are not.

   Under wsprintf, a type change is the dangerous case (%d -> %s dereferences
   an int as a pointer). Too FEW specifiers merely drops information; too MANY
   reads past the pushed arguments.
   """
   return [p[-1] for p in placeholders(value)]
