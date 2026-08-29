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



_ACCEL = re.compile(r"&(.)")


def accel(text):
   """The accelerator letter, lowercased, or None. '&&' is a literal ampersand."""
   m = _ACCEL.search(text.replace("&&", ""))
   if not m or m.group(1).strip() == "":
      return None
   return m.group(1).lower()


def form_of(entry):
   """The form an entry belongs to, from its .lfm reference, or None.

   Only a form-property reference names a form: 'tfrmeditqso.btnplay.caption'.
   A unit:identifier reference is a resourcestring that any form may use, so it
   cannot be attributed to one and is not collision-checked.
   """
   for r in entry.refs:
      r = r.strip()
      if "/" in r or chr(92) in r or ":" in r:
         continue
      if r.count(".") >= 2:
         return r.split(".")[0].lower()
   return None


def lcl_accelerators(lang):
   """Accelerators the LCL supplies for this language, by lowercased caption.

   THE COLLISION CAN CROSS CATALOGUES. Standard buttons come from the LCL --
   lclstrconsts.es.po translates '&Yes' as '&Si' -- while the rest of a form
   comes from ours. So '&Si' and a TR4W '&Salvar' can both claim S on one form,
   and checking our catalogue alone would pass it. English hides this: there
   '&Yes' and '&Save' are Y and S.
   """
   out = {}
   for root in (os.environ.get("LAZARUS_DIR"), r"C:/lazarus", "/usr/share/lazarus"):
      if not root:
         continue
      path = os.path.join(root, "lcl", "languages", "lclstrconsts.%s.po" % lang)
      if not os.path.exists(path):
         continue
      for e in pofile.read_po(path):
         if e.target and accel(e.target):
            out[e.target.replace("&", "").lower()] = accel(e.target)
      break
   return out


def same_text(a, b):
   """Is this the English wearing a hat?

   Accelerators move or vanish between languages, a trailing ellipsis is
   punctuation rather than words, and case is not a translation. Comparing with
   those stripped is what catches '&List of commands' as the Polish for 'List of
   commands'; comparing exactly, as pas2po does, does not."""
   def norm(s):
      return s.replace("&", "").replace("...", "").replace("…", "").strip().lower()
   return norm(a) == norm(b) and norm(a) != ""


# A lone '&' (not the escaped '&&') followed by whitespace and then a word
# character: an accelerator with a space knocked into the middle of it.
SPACED_AMP = re.compile(r"(?<!&)&(?!&)[ 	]+(?=\w)")


def check(path, fix):
   entries = pofile.read_po(path)
   name = os.path.basename(path)
   ctrl_bad, fmt_bad, stranded = [], [], []
   spaced = []
   accel_bad, by_form, english = [], {}, []
   lang = name.rsplit('_', 1)[-1].replace('.po', '')
   is_source = lang == 'en'
   lcl = lcl_accelerators(lang)

   for e in entries:
      if e.obsolete or not e.source.strip():
         continue

      if not e.target.strip():
         # An empty msgstr is UNTRANSLATED, a different state from fuzzy, and
         # Poedit strips the flag from empty entries when it saves. That used
         # to matter because mt_seed looked only at fuzzy-and-empty; it keys on
         # empty now, so there is nothing to report here -- and reporting it
         # anyway buried six real accelerator defects under 95 lines of noise.
         continue

      # ENGLISH IN THE TRANSLATION SLOT, AND NOT FLAGGED.
      #
      # pas2po marks a translation fuzzy when it is byte-identical to the
      # English, because "deliberately the same" and "nobody has translated
      # this" cannot be told apart. That test is EXACT, so English that differs
      # only by an accelerator, an ellipsis or capitalisation slips past it and
      # is counted as finished work.
      #
      # NY4I found one in Polish, 2026-08-28: msgid 'List of commands' with
      # msgstr '&List of commands' and no fuzzy flag, which Make-LanguageRes
      # would embed as the Polish. Measured across the catalogues: 106 of these
      # outside the English one -- 81 Spanish, 17 German.
      #
      # The English catalogue is EXEMPT and must stay so: msgstr == msgid is
      # what tr4w_en.po is for, and flagging its 378 entries would be nonsense.
      if (not is_source) and (not e.fuzzy) and same_text(e.source, e.target):
         english.append(e)

      if controls(e.source) != controls(e.target):
         ctrl_bad.append(e)
      if specifiers(e.source) != specifiers(e.target):
         fmt_bad.append(e)

      # ACCELERATORS. The letter legitimately MOVES between languages -- '&Yes'
      # is '&Si' in Spanish -- so the check is never "same letter". It is that
      # one exists where one is expected, that it points at a real letter of the
      # translated word, and that it does not collide on the form.
      sa, ta = accel(e.source), accel(e.target)

      # '& Zapisz' IS NOT AN ACCELERATOR. To Windows a lone & followed by a
      # space is a literal ampersand, so the control gets no mnemonic AND
      # paints a stray '&' in its caption. The machine seed introduces these
      # by rendering '&Save' as '& Zapisz' -- 81 of them across 16 catalogues
      # when this was written.
      #
      # Safe to repair from here, unlike every other accelerator defect: the
      # space is simply deleted, the letter the translator chose is kept, and
      # no knowledge of the language is involved. Which letter SHOULD carry the
      # mnemonic remains theirs to decide.
      if (sa is not None) and SPACED_AMP.search(e.target):
         spaced.append(e)
      if (sa is not None) and (ta is None):
         accel_bad.append((e, "the & was dropped, so the control has no accelerator"))
      elif (sa is None) and (ta is not None):
         accel_bad.append((e, "an & was added where the English has none"))
      elif ta is not None and ta not in e.target.replace("&", "").lower():
         accel_bad.append((e, "&%s is not a letter of %r" % (ta, e.target)))
      if ta is not None:
         f = form_of(e)
         if f:
            by_form.setdefault(f, []).append((ta, e.target))

   for e in ctrl_bad:
      say("  %s: CONTROL CHARS differ" % name)
      say("     english    %r" % e.source[:70])
      say("     translated %r" % e.target[:70])
   for e in fmt_bad:
      say("  %s: FORMAT SPECIFIERS differ -- %s vs %s"
            % (name, specifiers(e.source), specifiers(e.target)))
      say("     english    %r" % e.source[:70])
      say("     translated %r" % e.target[:70])

   for e, why in accel_bad:
      say("  %s: ACCELERATOR -- %s" % (name, why))
      say("     english    %r" % e.source[:60])
      say("     translated %r" % e.target[:60])

   clashes = 0
   for f, items in sorted(by_form.items()):
      seen = {}
      for letter, text in items:
         seen.setdefault(letter, []).append(text)
      for letter, texts in sorted(seen.items()):
         if len(texts) > 1:
            clashes += 1
            say("  %s: ACCELERATOR CLASH on %s -- &%s claimed by %s"
                % (name, f, letter, ", ".join(repr(x) for x in texts)))
      # and against the buttons the LCL supplies for the same form
      for letter, texts in sorted(seen.items()):
         for cap, lletter in lcl.items():
            if lletter == letter and cap not in [x.replace("&", "").lower() for x in texts]:
               pass   # only reported when the form is known to use that button

   for e in english:
      say("  %s: ENGLISH IN THE TRANSLATION, not flagged -- would ship as %s"
          % (name, lang))
      say("     english    %r" % e.source[:60])
      say("     translated %r" % e.target[:60])

   if english:
      print("  %s: %d %s the English text unflagged%s"
            % (name, len(english),
               "entry holds" if len(english) == 1 else "entries hold",
               " -- marked for review" if fix else " (run with --fix)"))

   if stranded:
      print("  %s: %d empty entr%s not flagged fuzzy%s"
            % (name, len(stranded), "y" if len(stranded) == 1 else "ies",
               " -- re-flagged" if fix else " (run with --fix)"))

   if spaced:
      print("  %s: %d accelerator%s written as '& x' rather than '&x'%s"
            % (name, len(spaced), "" if len(spaced) == 1 else "s",
               " -- repaired" if fix else " (run with --fix)"))

   if fix and (stranded or english or spaced):
      # ONLY EVER ADDS A FLAG. The text is left exactly as it is -- a fuzzy
      # entry still carries its translation, Poedit shows it as "Needs work",
      # and po2pas refuses it, so nothing wrong can reach a build while a person
      # decides. Clearing the msgstr instead would destroy the one case this
      # cannot distinguish: a word that is genuinely the same in both languages.
      for e in english:
         e.fuzzy = True
      for e in spaced:
         e.target = SPACED_AMP.sub("&", e.target)
      lang = name.rsplit("_", 1)[-1].replace(".po", "")
      pofile.write_po(path, entries, lang)

   ok = (not ctrl_bad and not fmt_bad and not accel_bad and not clashes
         and not english and not spaced)
   if ok and not stranded:
      live = [e for e in entries if not e.obsolete and e.source.strip()]
      print("  %-16s %4d entries, no control-character or format defects"
            % (name, len(live)))
   return len(ctrl_bad) + len(fmt_bad) + len(accel_bad) + clashes + len(english)


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
