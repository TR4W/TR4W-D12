"""Add catalogue entries for resourcestrings that have none, seeded from the
legacy per-language tables.

WHY IT IS SEPARATE FROM pas2po. pas2po REWRITES a catalogue from the language
tables: its emit() builds the file from the ENG declarations and drops anything
it did not produce. The catalogues also carry 661 entries harvested from the
.lfm files, which pas2po has never heard of, so running its writer today would
delete them. This only ever APPENDS -- the same rule po_merge states, for the
same reason: ~3400 reviewed entries across 21 languages are native-speaker work.

WHAT IT FIXES. pas2po harvested TC_ only, because that is all the constants were
when it was written. The cut-over made RC_ constants resourcestrings too, so
they went live on screen while being absent from every catalogue in every
language -- 170 of 550 for Spanish. NY4I found it from the other end: the main
menu says `Window` and there was no entry to translate (2026-08-27).

169 of those 170 ALREADY HAVE SPANISH, sitting unused in TR4W_CONSTS_ESP.PAS
since the per-language-binary days -- RC_WINDOWS is 'Ventanas'. So the entries
are seeded from each language's own table rather than left blank for a machine
to guess at. Where a language has no translation the entry still appears, in
English and marked fuzzy, which is what makes it visible to a translator or to
a LibreTranslate pass. Being IN the file is the point (NY4I).

WHAT GOES IN A NEW ENTRY
  msgctxt   the Pascal constant name, the stable key
  msgid     the English from tr4w_consts_eng.pas
  msgstr    that language's table value, or empty
  #:        utr4wstrings:<name>  -- what the run time matches on, and the
            source line, matching what po_rekey.py writes for existing entries
  fuzzy     when the value is absent, or identical to the English (there is no
            way to tell "deliberately the same" from "nobody has looked")

Usage
-----
  python tools/i18n/po_backfill.py            # report only
  python tools/i18n/po_backfill.py --apply
"""

import argparse
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pasconsts as pc
import pofile
import pas2po


def covered_names(entries):
   """Keys a catalogue already has, by msgctxt and by utr4wstrings reference."""
   seen = set()
   for e in entries:
      if e.key:
         seen.add(e.key.lower())
      for r in e.refs:
         r = r.strip().lower()
         if r.startswith('utr4wstrings:') or r.startswith('utr4wstrings.'):
            seen.add(r.split(':')[-1].split('.')[-1])
   return seen


def main():
   ap = argparse.ArgumentParser(description=__doc__,
                                formatter_class=argparse.RawDescriptionHelpFormatter)
   ap.add_argument('--apply', action='store_true', help='write the files')
   args = ap.parse_args()

   for stream in (sys.stdout, sys.stderr):
      if hasattr(stream, 'reconfigure'):
         stream.reconfigure(encoding='utf-8', errors='replace')

   paths = pc.repo_paths()
   pc.load_language_registry(paths['i18n'])
   live = pas2po.live_resourcestrings(paths['root'])
   eng_decls, others, _files, _lossy = pas2po.build_catalog(paths['lang'], live)

   # EVERY CATALOGUE, not only the ten with a legacy table.
   #
   # Iterating the tables would skip da, el, fi, sv, nl, pt, pt_BR, fr, it, ja
   # and ko -- languages added after the per-language-binary era, which have no
   # TR4W_CONSTS_<LANG>.pas to seed from. Those are precisely the ones a
   # LibreTranslate pass is for, and it can only translate a string that is IN
   # the file (NY4I). So they get the entry in English, marked fuzzy.
   bycode = {pc.LANG_CODES[l]: others[l] for l in others if l in pc.LANG_CODES}

   total_added = total_seeded = 0
   for fn in sorted(f for f in os.listdir(paths['i18n'])
                    if f.startswith('tr4w_') and f.endswith('.po')):
      code = fn[len('tr4w_'):-len('.po')]
      path = os.path.join(paths['i18n'], fn)

      entries = pofile.read_po(path)
      have = covered_names(entries)
      table = bycode.get(code, {})

      added = seeded = 0
      for d in eng_decls:
         if not d.name or d.name.lower() in have:
            continue
         t = table.get(d.name)
         value = t.value if t is not None else ''
         # Absent, or the same bytes as the English: either way nobody has
         # confirmed it, and a false "done" hides the string for good.
         fuzzy = (value == '') or (value == d.value)
         if value and value != d.value:
            seeded += 1
         entries.append(pofile.Entry(
            key=d.name,
            source=d.value,
            target=value,
            fuzzy=fuzzy,
            notes=['Section: %s' % d.context] + ([d.comment] if d.comment else []),
            refs=['utr4wstrings:%s' % d.name.lower(),
                  'tr4w/src/lang/tr4w_consts_eng.pas:%d' % d.lineno]))
         added += 1

      if added:
         src = 'the %s table' % code if seeded else 'English only'
         print('  %-16s +%3d entrie(s), %3d seeded from %s'
               % (fn, added, seeded, src))
      total_added += added
      total_seeded += seeded
      if args.apply and added:
         pofile.write_po(path, entries, code, pc.LANG_CODES[pc.SOURCE_LANG])

   print('\n  %d entrie(s) added, %d carrying an existing translation'
         % (total_added, total_seeded))
   if not args.apply:
      print('  Dry run -- nothing written. Re-run with --apply.')
   return 0


if __name__ == '__main__':
   sys.exit(main())
