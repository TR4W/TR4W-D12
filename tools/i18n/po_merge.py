"""Merge a .pot into the language catalogues, adding what is new and touching nothing else.

The harvest (tr4w_laz.pot -- 561 form properties plus the resourcestrings) is a
TEMPLATE. The language files do not know those strings exist. This adds them
as untranslated entries so a translator gets ONE complete file instead of the
417 they have now and a second batch of ~690 covering the same dialogs.

THE ONE RULE: AN EXISTING TRANSLATION IS NEVER TOUCHED.

~417 strings per language are finished native-speaker work (NY4I: "we do not
want to re-translate already completed items"). So it ADDS. It does not reword,
does not clear a msgstr, and does not clear a fuzzy flag. Entries already in the
catalogue are left exactly as they are, including their existing refs --
po_rekey.py owns those. The only deletions are the three kinds merge() explains: a
dependency's string (a unit the .lpi does not list), an obsolete (#~) entry, and
an UNTRANSLATED entry whose English is not language -- 'F1', '8', '...' (see
pofile.is_translatable; such a template entry is never added either).

THERE IS NO ENGLISH CATALOGUE (2026-10-21). English is the msgid; the program
loads no catalogue for it. A tr4w_en.po is not something this tool creates.

AND "EXACTLY AS THEY ARE" MEANS BYTE FOR BYTE -- TRUE ONLY SINCE 2026-10-18.
Before then the rewrite went through a pofile.write_po that rebuilt every entry
from its parsed fields and the header from gettext's template, so an --apply
silently dropped every '# ' translator comment (the dated audit notes, each
author credit's provenance) and G0DVJ's Poedit header in Polish: 4-5 lines per
catalogue, 36 in Polish, measured on that day. The entries survived; the record
around them did not. pofile now writes unchanged entries from their own text,
and tools/i18n/test_pofile.py fails if any catalogue does not round-trip
byte-identical. Check `git diff --numstat i18n` after an --apply: an add-only
merge shows additions and no deletions.

WHAT IT CARRIES OVER. A new entry whose ENGLISH already appears elsewhere in the
same catalogue, translated and not fuzzy, is seeded with that translation and
MARKED FUZZY. Fuzzy because a match on source text alone is a guess about
context -- 'Clear' on a button and 'Clear' in a menu can differ in gender or
mood in a way English does not show -- and fuzzy is exactly the flag that says
"a human should look at this". po2pas.py refuses fuzzy entries, so a wrong guess
cannot reach a build.

Measured before writing this: of 709 harvest strings, 22 have an existing
Spanish translation, and several of those are junk matches ('Band' -> 'Band').
So the carry-over is small and the flag matters more than the saving.

IDENTITY IS THE IDENTIFIERS an entry answers for -- its msgctxt and every
identifier token on every `#:` line (claimed_identifiers) -- else, for an entry
naming none, the msgid. A template entry is already known when it shares ANY
identifier with an existing one. That is the Lazarus convention (LazUtils loads
each `#:` identifier), and it is what keeps the legacy TC_-keyed entries
distinct from the new form-keyed ones even when the English is identical.

Usage
-----
  python tools/i18n/po_merge.py --pot <path>            # dry run
  python tools/i18n/po_merge.py --pot <path> --apply
"""

import argparse
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pofile


# WHAT IS OURS IS WHAT THE PROJECT COMPILES FROM SOURCE, and the project file
# says so exactly -- no name list, no path heuristic, no guessing (NY4I,
# 2026-08-26: "why are we guessing when all we need to do is look at the files
# defined in the fpc/laz project file").
#
# A .rsj carries every resourcestring the compiler saw, vendored code included,
# so the harvest needs filtering. The rule is: a unit LISTED IN tr4w/src/... in
# the .lpi is TR4W's and gets translated. Anything else is a dependency.
#
# Indy is excluded for free: it is not a project unit at all, it is resolved
# from tr4w/include via the search path, so it never appears in this set. A new
# dependency added the same way needs no edit here.
#
# THIS ONLY WORKS BECAUSE Log4D MOVED. It was vendored into tr4w/src and listed
# like a TR4W unit, so every rule -- name, location, project membership -- called
# it ours. It is tr4w/include/Log4D.pas now, beside Indy and pcre, which is
# where a dependency belongs; the exception this used to carry is gone.
#
# Two reasons a dependency's strings must not be translated: they belong to
# somebody else, so the work is lost the next time it is refreshed; and Log4D's
# are LOG OUTPUT, which stays English by house rule -- a Spanish log is harder
# to support, because whoever reads it is usually not the operator.


# OURS BUT NOT YET IN THE PROJECT FILE.
#
# uTR4WStrings is the resourcestring unit pas2res generates from the English
# tables. It is TR4W's own, it is what po_rekey pointed all 381 legacy entries
# at -- `#: utr4wstrings:tc_isadupe` -- and it is deliberately NOT in the .lpi
# yet: adding it declares 546 identifiers that VC.pas already declares as
# consts, and with both in scope uses-order decides silently. That cut-over is
# its own commit.
#
# Without this the .lpi rule reads those 381 entries as belonging to an unknown
# unit and retires every one -- the finished Spanish translations included. The
# dry run caught it; the fix is one line and the reason is worth the ten above.
PLANNED_UNITS = ('utr4wstrings',)


def our_units(repo_root):
   """Unit names the project compiles from tr4w/src, read from the .lpi."""
   lpi = os.path.join(repo_root, 'tr4w', 'tr4w.lpi')
   names = set(PLANNED_UNITS)
   with open(lpi, encoding='utf-8', errors='replace') as fh:
      for m in re.finditer(r'<Filename Value="([^"]+)"', fh.read()):
         path = m.group(1).replace('\\', '/')
         if path.lower().startswith('src/'):
            names.add(os.path.splitext(os.path.basename(path))[0].lower())
   return names


def is_third_party(entry, ours):
   """True when nothing in tr4w/src declares this string's unit."""
   for r in (entry.refs or []):
      ident = r.lower().replace(':', '.')
      if ident.rsplit('.', 1)[-1].isdigit():
         continue                      # a source reference, not an identifier
      unit = ident.split('.')[0]
      # A form key is t<formclass>.<control>.<property> -- the class, not a unit.
      # Those are always ours: a form only exists because a project unit declares it.
      if unit.startswith('t'):
         return False
      return unit not in ours
   return False


def claimed_identifiers(entry):
   """EVERY identifier an entry answers for: its msgctxt, and each token on
   each `#:` line that is an identifier rather than a `path:line` reference.

   ALL OF THEM, NOT THE FIRST (2026-10-18). This used to be the msgctxt alone
   when there was one, else the first `#:` line taken whole. But an entry
   routinely names two identifiers -- `#: tfrminiretire.caption
   uappstrings.siniretiretitle` on one line, or `uappstrings.salreadyrunningtitle`
   on a second `#:` line under a form caption's msgctxt -- because the same
   English is a caption and a resourcestring. Measured on the first merge of a
   uAppStrings template: 2 of the 38 'new' strings were already claimed that
   way in all 22 catalogues, and the merge added a twin of each. LazUtils loads
   every `#:` identifier (translations.pas), and Make-LanguageRes ships one
   entry per identifier, so the twin added nothing but debt."""
   ids = set()
   if entry.key:
      ids.add(entry.key.lower())
   for r in (entry.refs or []):
      for tok in r.split():
         # a rekey/Lazarus identifier, not a source reference ending in a line number
         if not tok.rsplit(':', 1)[-1].isdigit():
            ids.add(tok.lower().replace(':', '.'))
   return ids


def is_known(entry, seen_ids, seen_sources):
   """True when the catalogue already holds this entry: it shares an
   identifier with one, or -- for an entry naming no identifier at all --
   its English matches one that names none either."""
   ids = claimed_identifiers(entry)
   if ids:
      return not ids.isdisjoint(seen_ids)
   return entry.source in seen_sources


def merge(path, template, ours, apply_changes):
   existing = pofile.read_po(path)
   seen_ids = set()
   seen_sources = set()
   for e in existing:
      ids = claimed_identifiers(e)
      seen_ids |= ids
      if not ids:
         seen_sources.add(e.source)

   # An English string already translated here, for the carry-over.
   by_source = {}
   for e in existing:
      if e.source.strip() and e.target.strip() and not e.fuzzy:
         by_source.setdefault(e.source, e.target)

   # REMOVE what an earlier merge let through -- 48 Log4D strings per catalogue,
   # before the rule read the project file.
   #
   # DELETED, NOT MARKED OBSOLETE, and the difference is the point. Obsolete is
   # for OUR strings that have left the source: the key may come back, so the
   # translation is kept against that day -- which is why the 84 drifted TC_/RC_
   # entries stay, all 84 of them carrying real Spanish. A DEPENDENCY's string is
   # not coming back into our catalogue, because it was never ours to hold. It is
   # 5% of the file, invisible to Poedit but present in every diff and every
   # review, for text nobody will ever translate (NY4I, 2026-08-26: "that was a
   # mistake. no need for them to be there").
   #
   # Measured before deleting: 1 of the 48 had any text at all.
   before = len(existing)
   existing = [e for e in existing if not is_third_party(e, ours)]
   retired = before - len(existing)

   # AND DROP THE OBSOLETE ENTRIES TOO, for the same reason one step further out.
   #
   # gettext keeps an obsolete entry so its translation survives until the key
   # returns. That is sound in principle and was worth nothing here: measured
   # across the 84 in Spanish, 8 had the same English already translated in a
   # live entry, 0 were recoverable into a live entry that needed one, and 76
   # named text that exists nowhere in the program.
   #
   # What they cost is real. NY4I, 2026-08-26: "inert or not, an editor will
   # think they have to translate them." Poedit hides them; a text editor does
   # not, and a reviewer opening the file sees 84 blocks that look like work.
   # 349 lines, 5% of the file, in every diff forever.
   #
   # The translations they held are not lost: po_merge carries a matching
   # English into the new entry as it adds it, which is how 'Connect' ->
   # 'Conectar' moved from TC_TELNET_CONNECT to tfrmtelnet.btnconnect.caption.
   before = len(existing)
   existing = [e for e in existing if not e.obsolete]
   dropped = before - len(existing)
   retired += dropped

   # AND WHAT IS NOT LANGUAGE -- pofile.is_translatable, the one rule. An
   # earlier harvest let in every .lfm caption, 'F1' and '8' and '...'
   # included, and Weblate offered them to translators (2026-10-21). Removed
   # only while EMPTY: a msgstr someone wrote is kept and reported, because
   # deciding it is noise is a person's call, not this tool's.
   kept = []
   for e in existing:
      if pofile.is_translatable(e.source):
         kept.append(e)
      elif e.target.strip():
         kept.append(e)
         print('  %s: KEPT %r -- not language, but it carries %r'
               % (os.path.basename(path), e.source, e.target))
      else:
         retired += 1
   existing = kept

   added = carried = skipped = 0
   for t in template:
      if not t.source.strip():
         continue                      # the header
      if not pofile.is_translatable(t.source):
         continue                      # 'F1', '8', '...': see pofile.is_translatable
      if is_known(t, seen_ids, seen_sources):
         continue                      # already known -- leave it alone
      if is_third_party(t, ours):
         skipped += 1
         continue

      # FUZZY, EVEN WHEN EMPTY. That is this project's convention, not gettext's
      # default: pas2po flags every unreviewed entry fuzzy, and mt_seed selects
      # exactly `fuzzy and not target` -- so an untranslated entry that is NOT
      # fuzzy is invisible to the seeder. The first version of this left new
      # entries unflagged and mt_seed reported "0 entries to seed" against 687
      # empty ones.
      new = pofile.Entry(key=t.key, source=t.source, target='', fuzzy=True,
                         notes=list(t.notes or []), refs=list(t.refs or []))
      if t.source in by_source:
         new.target = by_source[t.source]
         new.fuzzy = True              # a source-text match is a guess about context
         carried += 1
      existing.append(new)
      added += 1
      # Known from here on, so a template naming one identifier twice adds it once.
      ids = claimed_identifiers(new)
      seen_ids |= ids
      if not ids:
         seen_sources.add(new.source)

   if apply_changes and (added or retired):
      # The code is everything between the 'tr4w_' prefix and '.po'. Splitting
      # on the LAST underscore instead turned tr4w_pt_BR.po into 'BR' and
      # tr4w_zh_CN.po into 'CN' in the written header (found 2026-10-01 by a
      # read/write round-trip of every catalogue; the other twenty matched).
      # Since 2026-10-18 an existing catalogue keeps its OWN header, so this
      # code only reaches a header when the catalogue had no entries to keep.
      name = os.path.basename(path)
      lang = name[len('tr4w_'):-len('.po')]
      pofile.write_po(path, existing, lang)
   return added, carried, retired, len(existing)


def main():
   ap = argparse.ArgumentParser(description=__doc__,
                                formatter_class=argparse.RawDescriptionHelpFormatter)
   ap.add_argument('--pot', required=True, help='the template to merge in')
   ap.add_argument('--apply', action='store_true', help='write the files')
   ap.add_argument('--dir', default=None, help='the i18n directory')
   args = ap.parse_args()

   here = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
   i18n = args.dir or os.path.join(here, 'i18n')

   ours = our_units(here)
   print('%d unit(s) listed under tr4w/src in the .lpi' % len(ours))
   template = [e for e in pofile.read_po(args.pot) if e.source.strip()]
   print('template: %d entries' % len(template))

   files = sorted(f for f in os.listdir(i18n)
                  if f.lower().startswith('tr4w_') and f.lower().endswith('.po'))
   for f in files:
      added, carried, retired, total = merge(os.path.join(i18n, f), template, ours, args.apply)
      print('  %-16s +%4d new (%2d carried), %3d retired  -> %4d entries'
            % (f, added, carried, retired, total))

   verb = 'written' if args.apply else 'would be added'
   print('\n%s across %d file(s)' % (verb, len(files)))
   if not args.apply:
      print('Dry run -- nothing written. Re-run with --apply.')
   return 0


if __name__ == '__main__':
   sys.exit(main())
