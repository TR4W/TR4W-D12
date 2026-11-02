"""Collapse entries with the same (msgctxt, msgid) into one, keeping every reference.

THE IDENTITY IS (msgctxt, msgid) -- gettext's own, and the one Weblate and msgfmt
check. Two entries with the same msgctxt and msgid are a DUPLICATE: msgfmt
rejects the file, and Weblate shows the first copy but saves an edit into the
second, so a community translation lands where nobody sees it (issue 153,
2026-11-02: 115 such entries across the 21 catalogues -- Check, Connect,
Disconnect, Contest, CONTEST, QSOs, File).

UNTIL 2026-11-02 THIS GROUPED ON THE msgid ALONE, and that was the bug. It
would have merged entries that are deliberately distinct: the Lazarus harvest
gives a repeated English its own msgctxt (`tfrmtelnet.btnconfigure.caption`),
and the legacy TC_/RC_ entries carry their constant name. Measured on
tr4w_pl.po before the fix: grouping on the msgid would have removed 898
entries; keyed correctly it removes 8 (7 groups).
An entry whose msgctxt is its own is never touched.

HOW THE DUPLICATES ARISE. po_merge decides whether a template entry is already
known by its IDENTIFIERS (pofile.claimed_identifiers), so a new resourcestring
`uappstrings.snetmenuconnect` is new -- and is appended with the template's
empty msgctxt beside the form caption `tfrmtelnet.btnconnect.caption`, which
also has an empty msgctxt and the same English. The hand-appending recipe for
a uAppStrings string does the same thing. Each was harmless to the program and
a duplicate to gettext.

WHY MERGING CANNOT LOSE A LOOKUP. Every identifier of every copy goes onto the
surviving entry, one `#:` line each, in first-seen order. Make-LanguageRes
ships ONE ENTRY PER IDENTIFIER (Write-TrimmedCatalogue splits each `#:` token
into its own entry), so the embedded catalogue still answers each identifier
by name. A loose catalogue read by LazUtils directly keeps only the last `#:`
line as the identifier, but translations.pas falls back to the ORIGINAL text --

    Item := FIdentifierLowToItem[lowercase(Identifier)];
    if Item = nil then
      Item := FOriginalToItem.Data[OriginalValue];      <-- the English

-- and every copy in a group has the same English by construction.

WHICH TRANSLATION SURVIVES, in this order:

  1. one with text. An empty copy never wins over a filled one: in most
     languages the uappstrings copy of Connect/Disconnect/QSOs is empty and
     the form caption holds the only translation.
  2. a reviewed one (not fuzzy). The merge must never turn a native speaker's
     reviewed text back into a draft -- es 'Conectar', G0DVJ's pl 'Sprawdz'.
  3. one naming a `uappstrings.` identifier. Those are the copies the
     2026-10-19 audit checked and annotated; the form-property copy is the
     machine guess the audit corrected (el CONTEST: 'SYMPERASMA', conclusion,
     against 'DIAGONISMOS'). The test is the literal prefix, not "a
     resourcestring rather than a form key": in da and zh_CN 'Contest' the
     losing copy is a resourcestring too (usettingscaptions).
  4. one naming a language-table `unit:identifier`, the original tie-break.
  5. the first in file order -- so the result never depends on dict ordering.

WHAT IT NEVER DOES. It does not discard a translation silently. Where a losing
copy held DIFFERENT non-empty text, the surviving entry gains a dated `# `
translator comment quoting it, so the text stays in the file for a reviewer
-- and every copy's existing `# ` comments travel too, the audit notes among
them. It does not defuzz: the winner's flag is kept as it is. It leaves
obsolete (`#~`) entries alone, and it refuses (exit 2) if removing a copy
would drop any non-blank text that sits between entries.

THE ONE THING GIVEN UP is per-context wording for those few strings: after
merging, 'Check' is one string for the Edit QSO label and the verification
column. A language wanting two words needs a msgctxt on one of them, which is
the gettext way to say so.

Usage
-----
  python tools/i18n/po_dedupe.py --dir i18n            # report only
  python tools/i18n/po_dedupe.py --dir i18n --apply
"""

import argparse
import datetime
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pofile

IDENT_REF = re.compile(r'^[A-Za-z_]\w*:[A-Za-z_]\w*')
AUDITED_PREFIX = 'uappstrings.'


class DedupeError(Exception):
   """A merge that would lose text which is not part of any entry."""


def is_audited(entry):
   """True when one of the entry's `#:` tokens names a uAppStrings identifier."""
   for r in entry.refs:
      for tok in r.split():
         if tok.lower().startswith(AUDITED_PREFIX):
            return True
   return False


def ref_rank(entry):
   """0 for a language-table `unit:identifier` reference, 1 for anything else.

   The last tie-break before file order; see the module docstring."""
   for r in entry.refs:
      if IDENT_REF.match(r.strip()):
         return 0
   return 1


def rank(entry):
   """Smaller is better. The order is the docstring's 1 to 4."""
   return (not entry.target.strip(), entry.fuzzy, not is_audited(entry), ref_rank(entry))


def pick(group):
   """The entry whose translation survives. File order breaks a final tie."""
   return min(enumerate(group), key=lambda p: (rank(p[1]), p[0]))[1]


def _unique(items):
   out, seen = [], set()
   for x in items:
      if x not in seen:
         seen.add(x)
         out.append(x)
   return out


def dedupe(entries, today=None):
   """Merge every group of live entries sharing (msgctxt, msgid).

   Returns (entries, groups collapsed, entries removed, disagreements). Each
   disagreement is a dict: msgctxt, msgid, kept (text, refs) and dropped, a
   list of (text, refs) for every losing copy whose text differed from the
   kept one -- empty text included, so a caller can tell "filled" from
   "overruled".

   The surviving entry is the FIRST copy, updated in place, so it keeps its
   place in the file and its own spacing; the winner's text, fuzzy flag,
   flags and previous-msgid lines are moved onto it."""
   stamp = (today or datetime.date.today()).isoformat()

   groups = {}
   for e in entries:
      if e.obsolete or not e.source:
         continue
      groups.setdefault((e.key, e.source), []).append(e)

   dropped_ids = set()
   collapsed = removed = 0
   disagreements = []
   for (key, source), group in groups.items():
      if len(group) == 1:
         continue
      first = group[0]
      winner = pick(group)

      for e in group[1:]:
         if e._lead is not None and e._lead.strip():
            raise DedupeError('a copy of %r is preceded by text that is not an entry '
                              '(%r); merge it by hand' % (source, e._lead.strip()[:60]))

      losers = [e for e in group if e is not winner and e.target != winner.target]
      notes_for_dropped = []
      for e in losers:
         if e.target.strip():
            notes_for_dropped.append(
               '# %s: po_dedupe merged a duplicate (msgctxt, msgid) entry (issue 153); '
               'the copy for %s said: "%s"'
               % (stamp, ' '.join(e.refs) or '(no reference)', pofile.escape(e.target)))
      if losers:
         disagreements.append({
            'msgctxt': key, 'msgid': source,
            'kept': (winner.target, list(winner.refs)),
            'dropped': [(e.target, list(e.refs)) for e in losers],
         })

      # Every reference, note and translator comment from every copy, first
      # seen first. The flags (object-pascal-format) and '#|' previous-msgid
      # lines describe the WINNER's text, so they come from the winner alone.
      refs = _unique(r for e in group for r in e.refs)
      notes = _unique(n for e in group for n in e.notes)
      comments = _unique(c for e in group for c in e.comments) + notes_for_dropped
      target, fuzzy = winner.target, winner.fuzzy
      flags, previous = list(winner.flags), list(winner.previous)

      first.refs = refs
      first.notes = notes
      first.comments = comments
      first.target = target
      first.fuzzy = fuzzy
      first.flags = flags
      first.previous = previous
      for e in group[1:]:
         dropped_ids.add(id(e))
      collapsed += 1
      removed += len(group) - 1

   out = [e for e in entries if id(e) not in dropped_ids]
   return out, collapsed, removed, disagreements


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

   total_removed = 0
   for f in files:
      path = os.path.join(d, f)
      entries = pofile.read_po(path)
      before_usable = sum(1 for e in entries if e.translated)
      try:
         merged, collapsed, removed, disagreements = dedupe(entries)
      except DedupeError as exc:
         print('  %s: REFUSED -- %s' % (f, exc))
         return 2
      after_usable = sum(1 for e in merged if e.translated)
      lang = f[len('tr4w_'):-len('.po')]

      # Usable (reviewed, non-empty) can only stay level or rise: the winner is
      # reviewed whenever any copy was. A fall would mean reviewed work lost.
      print('  %-16s %4d entries -> %4d   (%d group(s) collapsed, %d removed, usable %d -> %d)'
            % (f, len(entries), len(merged), collapsed, removed,
               before_usable, after_usable))
      for dis in disagreements:
         for text, refs in dis['dropped']:
            print('      %-6s %r: kept %r (%s), %s %r (%s)'
                  % (lang, dis['msgid'], dis['kept'][0], ' '.join(dis['kept'][1]),
                     'dropped' if text.strip() else 'filled empty', text, ' '.join(refs)))
      total_removed += removed
      if args.apply and removed:
         pofile.write_po(path, merged, lang)

   print('\n  %d duplicate entrie(s) removed across %d catalogue(s)' % (total_removed, len(files)))
   if not args.apply:
      print('  Dry run -- nothing written. Re-run with --apply.')
   return 0


if __name__ == '__main__':
   sys.exit(main())
