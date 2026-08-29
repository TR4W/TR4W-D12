"""Recover what can be recovered from a lang file that decodes under no codepage.

WHY THIS EXISTS. tr4w_consts_chn.pas holds a real translation by a native
speaker -- Li Jia Wei BA4WI -- and pas2po refuses to harvest it, correctly: the
file decodes as neither UTF-8 nor GBK nor Big5, so a blanket take would emit
mojibake into a catalogue nobody here can proofread.

WHAT IS ACTUALLY WRONG WITH IT. The text is UTF-8 whose bytes have been damaged
at the BIT level, uniformly enough to be partly invertible: a lead byte reads
0x10 high, a continuation byte 0x40 high, and a continuation that would
underflow past 0x80 reads 0x10 low instead. Undo that and OK_WORD is exactly
U+786E U+5B9A, CANCEL_WORD exactly U+53D6 U+6D88, RC_FREQUENCY exactly
U+9891 U+7387. Measured 2026-08-28: 110 of 254 non-ASCII literals come back as
well-formed UTF-8 Chinese.

WHY THE RESULT IS MARKED FUZZY AND MUST STAY THAT WAY. The inversion is not
sound. Where the rule has to guess a bit it guesses wrong often enough to
matter: CLOSE_WORD comes back U+5176 U+95ED where it must be U+5173 U+95ED,
HELP_WORD U+5F2E U+52A9 where it must be U+5E2E U+52A9. A wrong hanzi is a
perfectly ordinary-looking hanzi -- nothing downstream can flag it and nobody on
this side can read it. So every salvaged string is written as a SUGGESTION:
fuzzy, which build/Make-LanguageRes.ps1 drops before it can reach a build, and
which Poedit shows as 'Needs work'. A native speaker confirms or corrects each
one; until then Chinese falls back to English, which is the honest outcome.

DO NOT 'clean up' by defuzzing these in bulk. That is the whole safety property.

   python tools/i18n/salvage_lossy.py            # CHN into i18n/tr4w_zh_CN.po
   python tools/i18n/salvage_lossy.py --dry-run  # report only, write nothing
"""

import argparse
import os
import re
import sys

import pasconsts as pc
import pofile

# Every salvaged entry carries this, so a reviewer opening the catalogue in six
# months knows the text is a machine repair and not BA4WI's own keystrokes.
SALVAGE_NOTE = ("RECOVERED from a bit-corrupted lang file -- a suggestion, not "
                "a translation. VERIFY EVERY CHARACTER before clearing 'needs "
                "work'; wrong hanzi look exactly like right ones.")

LITERAL = re.compile(rb"^\s*([A-Za-z_]\w*)\s*=\s*'(.*)';\s*$")

# The only Latin-script values worth taking from a CJK lang file: who did the
# work and how to reach them.
CREDIT_FIELDS = frozenset((
   "TC_TRANSLATION_LANGUAGE",
   "TC_TRANSLATION_AUTHOR",
   "TC_TRANSLATOR_EMAIL",
   "TC_TRANSLATION_CREDIT",
))

CJK_FIRST = u"一"
CJK_LAST = u"鿿"


def repair_continuation(b):
   """Undo the damage to one UTF-8 continuation byte."""
   c = b - 0x40
   if c < 0x80:
      # Underflowed out of the continuation range, so the other direction is
      # the only one that lands back inside it.
      return b + 0x10
   return c


def repair(value):
   """Best-effort inverse of the corruption. Bytes it cannot place are kept."""
   out = bytearray()
   i = 0
   while i < len(value):
      b = value[i]
      if b >= 0xf0 and i + 2 < len(value):
         out.append(b - 0x10)
         out.append(repair_continuation(value[i + 1]))
         out.append(repair_continuation(value[i + 2]))
         i += 3
      else:
         out.append(b)
         i += 1
   return bytes(out)


def has_cjk(text):
   return any(CJK_FIRST <= ch <= CJK_LAST for ch in text)


def candidates(lang_path):
   """{constant name: recovered text} for everything that comes back clean."""
   with open(lang_path, "rb") as fh:
      raw = fh.read()
   if raw.startswith(b"\xef\xbb\xbf"):
      raw = raw[3:]

   found, rejected, ascii_kept = {}, [], 0
   for line in raw.splitlines():
      m = LITERAL.match(line)
      if not m:
         continue
      name = m.group(1).decode("ascii", "replace")
      value = m.group(2)

      if not any(c > 127 for c in value):
         # An ASCII string in a catalogue for a non-Latin script is not a
         # translation -- it is the English the translator had not reached, and
         # in this file it is often an OLDER English wording than ships today.
         # Carrying it would fill the catalogue with entries a reviewer has to
         # clear one at a time. The credit fields are the exception: those are
         # genuinely his, and genuinely Latin.
         if name in CREDIT_FIELDS:
            found[name] = value.decode("ascii")
            ascii_kept += 1
         continue

      try:
         text = repair(value).decode("utf-8")
      except UnicodeDecodeError:
         rejected.append(name)
         continue
      if has_cjk(text):
         found[name] = text
      else:
         rejected.append(name)
   return found, rejected, ascii_kept


def main():
   ap = argparse.ArgumentParser(
      description=__doc__,
      formatter_class=argparse.RawDescriptionHelpFormatter)
   ap.add_argument("--lang", default="CHN")
   ap.add_argument("--dry-run", action="store_true")
   args = ap.parse_args()

   lang = args.lang.upper()
   code = pc.LANG_CODES.get(lang)
   if code is None:
      print("unknown LANG %r" % lang, file=sys.stderr)
      return 2

   paths = pc.repo_paths()
   lang_path = os.path.join(paths["lang"], "tr4w_consts_%s.pas" % lang.lower())
   po_path = os.path.join(paths["i18n"], "tr4w_%s.po" % code)
   if not os.path.exists(lang_path):
      print("no lang file %s" % lang_path, file=sys.stderr)
      return 2
   if not os.path.exists(po_path):
      print("no catalogue %s -- create it first with" % po_path,
            file=sys.stderr)
      print("   python tools/i18n/pas2po.py --new-lang %s" % lang,
            file=sys.stderr)
      return 2

   found, rejected, ascii_kept = candidates(lang_path)
   entries = pofile.read_po(po_path)

   applied = 0
   skipped_done = 0
   for e in entries:
      text = found.get(e.key)
      if text is None or not text.strip():
         continue
      if e.translated:
         # Someone has already reviewed this one. A machine suggestion must
         # never overwrite a human decision.
         skipped_done += 1
         continue
      if text == e.source:
         continue                    # the English left in place, not a translation
      e.target = text
      e.fuzzy = True
      if SALVAGE_NOTE not in e.notes:
         e.notes = list(e.notes) + [SALVAGE_NOTE]
      applied += 1

   print("%s: %d translated literal(s) recovered, %d unrecoverable, "
         "%d ASCII carried"
         % (lang, len(found) - ascii_kept, len(rejected), ascii_kept))
   print("     %d written into %s as fuzzy suggestions"
         % (applied, os.path.basename(po_path)))
   if skipped_done:
      print("     %d left alone -- already reviewed" % skipped_done)
   print("     %d string(s) still lost -- they need BA4WI's original file"
         % len(rejected))
   if args.dry_run:
      print("     (dry run -- nothing written)")
      return 0

   pofile.write_po(po_path, entries, code)
   return 0


if __name__ == "__main__":
   sys.exit(main())
