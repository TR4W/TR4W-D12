"""Collapse entries that carry the SAME English into one, keeping every reference.

THE PROBLEM. A translator opening tr4w_es.po met 'Cancel' fifteen times, 'OK'
eleven, 'Add...' six -- once per form that has such a button -- plus a second
copy of things like 'CAT DTR' coming from a resourcestring beside the .lfm
caption for the same label. Measured 2026-08-27: 892 distinct English strings
spread over 1032 entries, so 140 of them were re-translations of text already
translated a few rows above (NY4I, reviewing the Spanish file).

WHY MERGING IS SAFE, and this is the part worth checking before trusting it.
LazUtils does not resolve only by identifier. translations.pas:1217 --

    Item := FIdentifierLowToItem[lowercase(Identifier)];
    if Item = nil then
      Item := FOriginalToItem.Data[OriginalValue];      <-- falls back to the English

-- so an entry naming ONE of the fifteen Cancel buttons still answers for the
other fourteen, by their original text. Merging also removes an ambiguity that
exists today: with fifteen identical originals, FOriginalToItem holds fifteen
candidates and an arbitrary one wins.

WHICH TRANSLATION SURVIVES, and it is not a coin toss. Measured on tr4w_es.po:

    unit:identifier entries (the .pas language tables)  381 entries, 0 fuzzy
    form.property   entries (harvested from .lfm)       661 entries, 657 fuzzy

The language tables are finished native-speaker work; the form properties were
machine-seeded. So preferring a reviewed translation over a fuzzy one IS
preferring the one from TR4W_CONSTS_<LANG>.pas, which is what NY4I asked for.
Where that tie-break does not settle it, a unit:identifier reference wins over a
form.property one, and failing that the first entry in file order -- so the
result does not depend on dictionary ordering.

WHAT IT NEVER DOES. It does not discard a translation. A merged entry keeps the
best msgstr found among its copies, so a string translated in the language table
and left fuzzy on the form comes out translated. It does not touch entries whose
English is unique, and it leaves obsolete entries alone.

THE ONE THING GIVEN UP is per-context wording: after merging, 'Name' is one
string, and a language wanting a different word for a column heading than for a
field label can no longer say so through these two entries. That is recoverable
-- add an entry carrying that control's own reference and the identifier lookup
finds it before the text fallback -- but it is a real constraint and the reason
this was put to NY4I before running.

Usage
-----
  python tools/i18n/po_dedupe.py --dir i18n            # report only
  python tools/i18n/po_dedupe.py --dir i18n --apply
"""

import argparse
import io
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pofile

IDENT_REF = re.compile(r'^[A-Za-z_]\w*:[A-Za-z_]\w*')


def ref_rank(entry):
   """0 for a language-table reference, 1 for a form property, 2 for anything else.

   Only a tie-break: the fuzzy flag decides first, and on this catalogue it
   decides almost every case on its own.
   """
   for r in entry.refs:
      if IDENT_REF.match(r.strip()):
         return 0
   for r in entry.refs:
      if '.' in r and '/' not in r:
         return 1
   return 2


def pick(group):
   """The entry whose translation survives. File order breaks a final tie."""
   return min(enumerate(group),
              key=lambda p: (not p[1].translated, ref_rank(p[1]), p[0]))[1]


def dedupe(entries):
   """Return (merged entries, groups collapsed, entries removed)."""
   order, groups = [], {}
   for e in entries:
      if e.obsolete or not e.source:
         order.append(('solo', e))
         continue
      if e.source not in groups:
         groups[e.source] = []
         order.append(('group', e.source))
      groups[e.source].append(e)

   out, collapsed, removed = [], 0, 0
   for kind, item in order:
      if kind == 'solo':
         out.append(item)
         continue
      group = groups[item]
      if len(group) == 1:
         out.append(group[0])
         continue

      winner = pick(group)
      # Every reference, in first-seen order, so each control can still be
      # traced back to the entry that translates it.
      refs, seen = [], set()
      for e in group:
         for r in e.refs:
            if r not in seen:
               seen.add(r)
               refs.append(r)
      notes, nseen = [], set()
      for e in group:
         for n in e.notes:
            if n not in nseen:
               nseen.add(n)
               notes.append(n)

      merged = pofile.Entry(key=winner.key, source=winner.source,
                            target=winner.target, fuzzy=winner.fuzzy,
                            notes=notes, refs=refs, obsolete=False)
      out.append(merged)
      collapsed += 1
      removed += len(group) - 1
   return out, collapsed, removed


def main():
   ap = argparse.ArgumentParser(description=__doc__,
                                formatter_class=argparse.RawDescriptionHelpFormatter)
   ap.add_argument('--dir', default=None, help='the i18n directory')
   ap.add_argument('--apply', action='store_true', help='write the files')
   args = ap.parse_args()

   repo = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
   d = args.dir or os.path.join(repo, 'i18n')
   files = sorted(f for f in os.listdir(d)
                  if f.startswith('tr4w_') and f.endswith('.po'))
   if not files:
      print('no catalogues in ' + d)
      return 2

   total_removed = rescued = 0
   for f in files:
      path = os.path.join(d, f)
      entries = pofile.read_po(path)
      before_usable = sum(1 for e in entries if e.translated)
      merged, collapsed, removed = dedupe(entries)
      after_usable = sum(1 for e in merged if e.translated)
      lang = f[len('tr4w_'):-len('.po')]

      # A merged entry can be USABLE where its form-property copy was fuzzy, so
      # this number is expected to be >= 0, never negative. It is printed
      # because a negative would mean a translation was lost.
      gain = after_usable - before_usable
      print('  %-16s %4d entries -> %4d   (%d group(s) collapsed, %d removed, usable %d -> %d)'
            % (f, len(entries), len(merged), collapsed, removed,
               before_usable, after_usable))
      total_removed += removed
      rescued += max(0, gain)
      if args.apply:
         pofile.write_po(path, merged, lang)

   print('\n  %d duplicate entrie(s) removed across %d catalogue(s)' % (total_removed, len(files)))
   if not args.apply:
      print('  Dry run -- nothing written. Re-run with --apply.')
   return 0


if __name__ == '__main__':
   sys.exit(main())
