"""Fail when a TR4W resourcestring has no entry in some language catalogue.

WHY THIS EXISTS (issue 291, 2026-11-12). uAppStrings declared 308
resourcestrings and 64 of them were in none of the 21 i18n/tr4w_*.po files;
three more units held 17 more. A string that no catalogue names is never
offered to a translator, so it shows in English in every language -- and
nothing warned, nothing failed, because the program runs perfectly well on
its English default. Strings reach the catalogues by a deliberate step
(updatepofiles + po_merge --add-only, below), and a step that can be forgotten
was forgotten 85 times.

WHAT IT READS. The compiler's own list of resourcestrings: FPC writes
<unit>.rsj beside the .o for every unit that declares one, on every build.
That is the authority on which names exist -- no Pascal parsing here -- so
this runs AFTER a compile, against that compile's output directory
(Build-Tests.ps1 calls it with its -FU directory). A unit counts when it is
TR4W's own: po_merge.our_units, the rule the merge itself uses (Indy and
Log4D carry .rsj files too and are not ours to translate).

And the catalogues ON DISK, not the embedded copy: Make-LanguageRes drops an
empty entry, so the .res cannot say whether an entry exists.

WHAT COUNTS AS PRESENT. Any live (not #~) entry that claims the identifier
`<unit>.<name>` -- pofile.claimed_identifiers, the rule po_merge and LazUtils
use. Text is not required: an empty fuzzy entry is the correct state for a new
string, and the English shows until someone translates it.

WHAT IS SKIPPED. A resourcestring whose English is not language
(pofile.is_translatable: 'TR4W', 'CTY.DAT', 'INH'), because po_merge never
adds one either.

IT FAILS CLOSED: no .rsj of a TR4W unit, no catalogue, or no name read is
exit 2, never a pass.

THE FIX IT PRINTS is the safe route and the only one -- never pas2po, which
rebuilds a catalogue from the TC_/RC_ tables and destroys every other entry.

Usage
-----
  python tools/i18n/po_coverage.py --rsj-dir build-out/tests-x86_64-win64
  python tools/i18n/po_coverage.py --rsj-dir <dir> --dir <i18n copy>   # a test
"""

import argparse
import glob
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pofile
import po_merge


def resourcestrings(rsj_dir, ours):
   """{'unit.name': English} for every resourcestring of a TR4W unit."""
   names = {}
   units = []
   for path in sorted(glob.glob(os.path.join(rsj_dir, '*.rsj'))):
      unit = os.path.splitext(os.path.basename(path))[0].lower()
      if unit not in ours:
         continue
      units.append(unit)
      with open(path, encoding='utf-8') as fh:
         data = json.load(fh)
      for s in data.get('strings', []):
         names[s['name'].lower()] = s.get('value', '')
   return names, units


def claimed(path):
   """Every identifier a live entry of this catalogue answers for."""
   ids = set()
   for e in pofile.read_po(path):
      if not e.obsolete:
         ids |= pofile.claimed_identifiers(e)
   return ids


def missing(names, catalogues):
   """{'unit.name': [catalogue file names lacking it]}, translatable names only."""
   result = {}
   for name, english in names.items():
      if not pofile.is_translatable(english):
         continue
      lacking = [c for c, ids in catalogues.items() if name not in ids]
      if lacking:
         result[name] = lacking
   return result


def main():
   ap = argparse.ArgumentParser(description=__doc__,
                                formatter_class=argparse.RawDescriptionHelpFormatter)
   ap.add_argument('--rsj-dir', required=True,
                   help='a compile output directory holding <unit>.rsj files')
   ap.add_argument('--dir', default=None, help='the i18n directory')
   args = ap.parse_args()

   repo = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
   i18n = args.dir or os.path.join(repo, 'i18n')

   names, units = resourcestrings(args.rsj_dir, po_merge.our_units(repo))
   files = sorted(glob.glob(os.path.join(i18n, 'tr4w_*.po')))
   if not units or not names or not files:
      print('po_coverage: FAILED CLOSED -- %d TR4W .rsj file(s) in %s, %d name(s), '
            '%d catalogue(s) in %s' % (len(units), args.rsj_dir, len(names),
                                       len(files), i18n))
      return 2

   catalogues = {os.path.basename(f): claimed(f) for f in files}
   gaps = missing(names, catalogues)
   if not gaps:
      print('po_coverage: OK -- %d resourcestrings in %d unit(s), each in all %d catalogues'
            % (len(names), len(units), len(files)))
      return 0

   print('po_coverage: FAILED -- %d resourcestring(s) missing from a catalogue '
         '(the operator sees English in every language that lacks one):'
         % len(gaps))
   for name in sorted(gaps):
      lacking = gaps[name]
      where = ('all %d' % len(files)) if len(lacking) == len(files) else ', '.join(lacking)
      print('  %-56s %s' % (name, where))
   print('')
   print('  Add them -- additive, never pas2po (docs/I18N_TOOLS.md):')
   print('    C:\\Lazarus\\tools\\updatepofiles.exe <dir>\\<unit>.rsj <EMPTY scratch>.pot')
   print('    python tools/i18n/po_merge.py --pot <scratch>.pot --apply --add-only')
   return 1


if __name__ == '__main__':
   sys.exit(main())
