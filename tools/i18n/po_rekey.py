"""Add FPC/Lazarus resourcestring identifiers to TR4W's .po catalogues.

WHY THIS EXISTS
---------------
The catalogues key on `msgctxt` -- the Pascal constant name, TC_ISADUPE -- which
is TR4W's own convention and is what `po2pas.py` writes back with. The FPC and
Lazarus toolchain keys on something else: the `#:` SOURCE REFERENCE, in the form
`unitname:identifier`, which is what `rstconv` emits from a .rsj and what
LazUtils' Translations unit looks up at run time.

Verified rather than assumed (2026-08-26):

  * `rstconv -f po` on a real .rsj writes `#: uappstrings:salreadyrunningtitle`
    and NO msgctxt.
  * translations.pas reads that `#:` line and NORMALISES the colon to a dot,
    because "the RTL creates identifier paths with point instead of colons".
    Lookup is then by IdentifierLow.
  * translations.pas also parses and re-emits `msgctxt` (as Item.Context), so
    carrying both costs nothing.

So this tool ADDS the `#:` reference and LEAVES msgctxt ALONE. Both keys, one
file: the runtime matches on the identifier, and gettext tools keep a unique
(msgctxt, msgid) pair.

THAT SECOND KEY IS NOT DECORATION. Measured across tr4w_es.po: 416 live entries,
415 distinct English strings -- exactly one collision, 'North America', shared by
TC_NORTHAMERICA and TC_C9_NORTHAMERICA, AND THE TWO TRANSLATIONS DIFFER. Drop
msgctxt and gettext merges them, silently keeping one. One pair out of 416 is
easy to wave away right up until it is the pair a translator queries.

THE UNIT NAME IS A ONE-WAY DOOR
-------------------------------
It becomes part of every key. Renaming the unit later re-keys every entry in
every language and orphans the lot, which is why --unit is explicit and has no
default. Same reason the identifiers keep their TC_/RC_ spelling: a rename is a
new key, and 6,672 translations are riding on the old one. Renaming is possible
later, one string at a time, through this same tool.

Usage
-----
  python tools/i18n/po_rekey.py --unit utr4wstrings            # dry run
  python tools/i18n/po_rekey.py --unit utr4wstrings --apply
  python tools/i18n/po_rekey.py --unit utr4wstrings --check    # non-zero if any
                                                               # entry lacks a ref
"""

import argparse
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pofile


def ref_for(unit, key):
   """The `#:` reference FPC would have emitted for this constant.

   Lowercased because that is what rstconv writes and what Translations
   compares against (IdentifierLow); the colon is what rstconv uses and the
   loader normalises.
   """
   return "{0}:{1}".format(unit.lower(), key.lower())


def rekey(path, unit, apply_changes):
   entries = pofile.read_po(path)
   added = kept = skipped = 0

   for e in entries:
      if e.obsolete or not e.key:
         skipped += 1
         continue
      want = ref_for(unit, e.key)
      refs = list(e.refs or [])
      if want in refs:
         kept += 1
         continue
      # DROP ANY PREVIOUS REKEY REFERENCE, whatever unit it named -- not just
      # this unit's. Rerunning with a different --unit would otherwise leave
      # two live identifiers in the file and the loader would match whichever
      # it read first, which is a silent wrong translation rather than a
      # missing one. A rekey reference is recognisable: its right-hand side is
      # exactly this entry's key. The source references pas2po writes
      # (`tr4w/src/lang/...pas:283`) end in a LINE NUMBER and so never match.
      tail = ":" + e.key.lower()
      refs = [r for r in refs if not r.lower().endswith(tail)]
      refs.insert(0, want)
      e.refs = refs
      added += 1

   if apply_changes and added:
      lang = os.path.basename(path).rsplit("_", 1)[-1].replace(".po", "")
      pofile.write_po(path, entries, lang)
   return added, kept, skipped


def main():
   ap = argparse.ArgumentParser(description=__doc__,
                                formatter_class=argparse.RawDescriptionHelpFormatter)
   ap.add_argument("--unit", required=True,
                   help="the resourcestring unit these will live in "
                        "(baked into every key -- see the module docstring)")
   ap.add_argument("--apply", action="store_true", help="write the files")
   ap.add_argument("--check", action="store_true",
                   help="exit non-zero if any live entry lacks the reference")
   ap.add_argument("--dir", default=None, help="the i18n directory")
   args = ap.parse_args()

   here = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
   i18n = args.dir or os.path.join(here, "i18n")

   files = sorted(f for f in os.listdir(i18n)
                  if f.lower().startswith("tr4w_") and f.lower().endswith(".po"))
   if not files:
      print("no tr4w_*.po in " + i18n)
      return 2

   total_added = 0
   for f in files:
      added, kept, skipped = rekey(os.path.join(i18n, f), args.unit,
                                   args.apply and not args.check)
      total_added += added
      print("  {0:16} +{1:4} ref(s), {2:4} already correct, {3:3} skipped"
            .format(f, added, kept, skipped))

   verb = "written" if (args.apply and not args.check) else "would be added"
   print("\n{0} reference(s) {1} across {2} file(s), unit '{3}'"
         .format(total_added, verb, len(files), args.unit.lower()))

   if args.check and total_added:
      print("FAIL: entries are missing their resourcestring reference.")
      return 1
   if not args.apply and total_added:
      print("Dry run -- nothing written. Re-run with --apply.")
   return 0


if __name__ == "__main__":
   sys.exit(main())
