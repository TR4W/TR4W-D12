"""Merge a .pot into the language catalogues, adding what is new and touching nothing else.

The harvest (tr4w_laz.pot -- 561 form properties plus the resourcestrings) is a
TEMPLATE. The 16 language files do not know those strings exist. This adds them
as untranslated entries so a translator gets ONE complete file instead of the
417 they have now and a second batch of ~690 covering the same dialogs.

THE ONE RULE: AN EXISTING TRANSLATION IS NEVER TOUCHED.

~417 strings per language are finished native-speaker work (NY4I: "we do not
want to re-translate already completed items"). So this only ever ADDS. It does
not delete, does not reword, does not clear a msgstr, and does not clear a fuzzy
flag. Entries already in the catalogue are left exactly as they are, including
their existing refs -- po_rekey.py owns those.

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

IDENTITY IS (msgctxt, msgid) where a msgctxt exists, else the `#:` identifier,
else the msgid. That is gettext's own rule plus the Lazarus convention, and it
is what keeps the legacy TC_-keyed entries distinct from the new form-keyed ones
even when the English is identical.

Usage
-----
  python tools/i18n/po_merge.py --pot <path>            # dry run
  python tools/i18n/po_merge.py --pot <path> --apply
"""

import argparse
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pofile


def identity(entry):
   """What makes two entries the same entry."""
   if entry.key:
      return ('ctx', entry.key.lower())
   for r in (entry.refs or []):
      # a rekey/Lazarus identifier, not a source reference ending in a line number
      if not r.rsplit(':', 1)[-1].isdigit():
         return ('id', r.lower().replace(':', '.'))
   return ('src', entry.source)


def merge(path, template, apply_changes):
   existing = pofile.read_po(path)
   seen = set(identity(e) for e in existing)

   # An English string already translated here, for the carry-over.
   by_source = {}
   for e in existing:
      if e.source.strip() and e.target.strip() and not e.fuzzy:
         by_source.setdefault(e.source, e.target)

   added = carried = 0
   for t in template:
      if not t.source.strip():
         continue                      # the header
      if identity(t) in seen:
         continue                      # already known -- leave it alone

      new = pofile.Entry(key=t.key, source=t.source, target='',
                         notes=list(t.notes or []), refs=list(t.refs or []))
      if t.source in by_source:
         new.target = by_source[t.source]
         new.fuzzy = True              # a source-text match is a guess about context
         carried += 1
      existing.append(new)
      added += 1

   if apply_changes and added:
      lang = os.path.basename(path).rsplit('_', 1)[-1].replace('.po', '')
      pofile.write_po(path, existing, lang)
   return added, carried, len(existing)


def main():
   ap = argparse.ArgumentParser(description=__doc__,
                                formatter_class=argparse.RawDescriptionHelpFormatter)
   ap.add_argument('--pot', required=True, help='the template to merge in')
   ap.add_argument('--apply', action='store_true', help='write the files')
   ap.add_argument('--dir', default=None, help='the i18n directory')
   args = ap.parse_args()

   here = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
   i18n = args.dir or os.path.join(here, 'i18n')

   template = [e for e in pofile.read_po(args.pot) if e.source.strip()]
   print('template: %d entries' % len(template))

   files = sorted(f for f in os.listdir(i18n)
                  if f.lower().startswith('tr4w_') and f.lower().endswith('.po'))
   for f in files:
      added, carried, total = merge(os.path.join(i18n, f), template, args.apply)
      print('  %-16s +%4d new (%2d carried over, fuzzy)  -> %4d entries'
            % (f, added, carried, total))

   verb = 'written' if args.apply else 'would be added'
   print('\n%s across %d file(s)' % (verb, len(files)))
   if not args.apply:
      print('Dry run -- nothing written. Re-run with --apply.')
   return 0


if __name__ == '__main__':
   sys.exit(main())
