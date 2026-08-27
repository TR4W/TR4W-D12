"""Check a catalogue before it is trusted -- especially one back from a translator.

Poedit cannot know TR4W's rules, and a translator has no way to see them. Three
things go wrong silently, and all three are cheap to detect and expensive to
find later.

1. CONTROL CHARACTERS DROPPED OR ADDED
   'Folder "%s" already exists.\rOverwrite ?' is ONE string with a line break in
   the middle. A translator working in Poedit sees the break as part of the text
   and can delete it without noticing; the message then renders as one run-on
   line, or two lines where there should be one.

   NY4I, 2026-08-27: "all it takes is a translator to mis-edit and delete that
   and the message does not display correctly."

   21 English strings carry one. Measured on the machine-seeded Spanish, 1
   translation had already lost a \r before any human touched it.

2. FORMAT SPECIFIERS CHANGED
   TR4W formats through wsprintfA -- UNCHECKED VARARGS. A %d turned into %s
   dereferences an integer as a pointer. mt_seed validates its own output; this
   catches the same defect arriving from a person instead.

3. AN EMPTY ENTRY THAT IS NOT FUZZY
   Poedit clears the fuzzy flag on an entry with no translation, because in
   gettext that state is meaningless. It is meaningful here: fuzzy+empty is what
   mt_seed selects, so a cleared one is invisible to the seeder and will never be
   filled. 25 arrived that way from the first review round.

EXIT CODE is non-zero if anything in the first two categories is found, so this
can gate. The third is reported and repaired by --fix, since it is Poedit doing
something reasonable rather than anyone making a mistake.

Usage
-----
  python tools/i18n/po_lint.py i18n/tr4w_es.po
  python tools/i18n/po_lint.py i18n/tr4w_es.po --fix     # re-flag empty entries
  python tools/i18n/po_lint.py --all
"""

import argparse
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pofile

# %s %d %u %x, and the Delphi-style %.8f. Order matters as much as count: a
# translation may reorder words, but wsprintfA takes its arguments positionally,
# so the SEQUENCE has to survive.
#
# THE CONVERSION CHARACTER IS AN EXPLICIT SET, and the SPACE FLAG IS NOT ALLOWED,
# because prose contains percent signs. The first version permitted both and read
# 'Dah 73% of normal duration' as carrying a "% o" specifier -- a false positive
# on the very first run, which is how a check earns the reputation CLAUDE.md
# records for Lint-PCharAnsi (5 reported, 5 false) and gets ignored thereafter.
#
# %% is a literal percent and is deliberately not a specifier here: it consumes
# no argument, so its presence or absence cannot misalign the varargs.
_FMT = re.compile(r"%[-+#0]*[0-9]*(?:\.[0-9]+)?[sduxXcfgeEp]")


def say(text):
   """Print text that may not survive the console's codepage.

   The catalogues are UTF-8 and the console here is cp1252, so printing a Czech
   or Russian translation raises UnicodeEncodeError and takes the whole run with
   it -- a checker that dies on the data it is checking is worse than none.
   """
   enc = sys.stdout.encoding or "utf-8"
   sys.stdout.write(text.encode(enc, "replace").decode(enc, "replace") + "\n")


def controls(text):
   return [c for c in text if ord(c) < 32]


def specifiers(text):
   return _FMT.findall(text)


def check(path, fix):
   entries = pofile.read_po(path)
   name = os.path.basename(path)
   ctrl_bad, fmt_bad, stranded = [], [], []

   for e in entries:
      if e.obsolete or not e.source.strip():
         continue

      if not e.target.strip():
         # empty and unflagged -- invisible to mt_seed
         if not e.fuzzy:
            stranded.append(e)
            if fix:
               e.fuzzy = True
         continue

      if controls(e.source) != controls(e.target):
         ctrl_bad.append(e)
      if specifiers(e.source) != specifiers(e.target):
         fmt_bad.append(e)

   for e in ctrl_bad:
      say("  %s: CONTROL CHARS differ" % name)
      say("     english    %r" % e.source[:70])
      say("     translated %r" % e.target[:70])
   for e in fmt_bad:
      say("  %s: FORMAT SPECIFIERS differ -- %s vs %s"
            % (name, specifiers(e.source), specifiers(e.target)))
      say("     english    %r" % e.source[:70])
      say("     translated %r" % e.target[:70])

   if stranded:
      print("  %s: %d empty entr%s not flagged fuzzy%s"
            % (name, len(stranded), "y" if len(stranded) == 1 else "ies",
               " -- re-flagged" if fix else " (run with --fix)"))

   if fix and stranded:
      lang = name.rsplit("_", 1)[-1].replace(".po", "")
      pofile.write_po(path, entries, lang)

   ok = not ctrl_bad and not fmt_bad
   if ok and not stranded:
      live = [e for e in entries if not e.obsolete and e.source.strip()]
      print("  %-16s %4d entries, no control-character or format defects"
            % (name, len(live)))
   return len(ctrl_bad) + len(fmt_bad)


def main():
   ap = argparse.ArgumentParser(description=__doc__,
                                formatter_class=argparse.RawDescriptionHelpFormatter)
   ap.add_argument("catalogue", nargs="*", help="the .po file(s) to check")
   ap.add_argument("--all", action="store_true", help="every tr4w_*.po in i18n/")
   ap.add_argument("--fix", action="store_true",
                   help="re-flag empty entries that lost their fuzzy marker")
   args = ap.parse_args()

   here = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
   paths = list(args.catalogue)
   if args.all:
      i18n = os.path.join(here, "i18n")
      paths += [os.path.join(i18n, f) for f in sorted(os.listdir(i18n))
                if f.startswith("tr4w_") and f.endswith(".po")]
   if not paths:
      ap.error("give a catalogue, or --all")

   bad = 0
   for p in paths:
      bad += check(p, args.fix)

   print()
   if bad:
      print("%d defect(s) a translator cannot see and the compiler cannot catch." % bad)
      return 1
   print("clean")
   return 0


if __name__ == "__main__":
   sys.exit(main())
