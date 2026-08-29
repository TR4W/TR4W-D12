"""Write a copy of a catalogue with the fuzzy flags removed, FOR TESTING ONLY.

WHY THIS EXISTS RATHER THAN A --allowFuzzy SWITCH
-------------------------------------------------
Showing an unreviewed translation is not one decision the program could make. It
is TWO gates, and only one of them is ours:

  build time   build/Make-LanguageRes.ps1 drops every fuzzy block BEFORE it
               reaches res/tr4w_languages.res, so the entries are not in the
               binary at all;
  run time     LazUtils refuses them again on lookup --
               translations.pas: `if (Item<>nil) and (pos(sFuzzyFlag, Item.Flags)=0)`

A runtime flag cannot recover text the binary does not contain, and defeating the
second gate would mean bypassing LCL code written to honour that flag -- putting a
path in the shipping binary whose only purpose is to display unreviewed text.

The flag is a line in the .po. Remove it from a COPY and both gates simply see a
finished translation. No code change, and the shipping path never sees the file.

WHAT IT IS FOR. Layout truth: does the text fit, does a button grow, does a
caption clip. Measured 2026-08-27, Spanish went from 385 usable entries to 1008.
It says nothing about whether the words are right -- machine output stays machine
output, and that is what the fuzzy flag is recording.

WHERE THE FILE GOES. Beside the EXE, not beside the working directory:
uEmbeddedTranslations builds its path from ExtractFilePath(ParamStr(0)) and a
file there wins over the embedded catalogue. So for a build-out binary run from
tr4w/target, the target is build-out/app-i386-win32/languages/<lang>/tr4w.po.
--install does that for you. The program says which one it used:

    UI language: "es" selected by ... loaded from <path> (overriding the
    embedded catalogue)

Usage
-----
  python tools/i18n/po_defuzz.py i18n/tr4w_es.po --install
  python tools/i18n/po_defuzz.py i18n/tr4w_es.po --out /tmp/es.po
  python tools/i18n/po_defuzz.py i18n/tr4w_es.po --install --exe-dir <dir>
"""

import argparse
import io
import os
import re
import sys

# The whole line goes. Verified across the shipped catalogues on 2026-08-27: all
# 657 Spanish fuzzy markers are a bare `#, fuzzy` with no second flag, so nothing
# else is lost with it. A combined marker (`#, fuzzy, c-format`) would need the
# flag removed rather than the line, which is why this checks instead of
# assuming.
BARE_FUZZY = re.compile(r'^#,\s*fuzzy\s*$')
ANY_FLAGS = re.compile(r'^#,\s*(.+?)\s*$')

DEFAULT_EXE_DIR = os.path.join('build-out', 'app-i386-win32')


def defuzz(text):
   """Return (text without fuzzy flags, removed, rewritten)."""
   out, removed, rewritten = [], 0, 0
   for line in text.split('\n'):
      stripped = line.rstrip('\r')
      if BARE_FUZZY.match(stripped):
         removed += 1
         continue
      m = ANY_FLAGS.match(stripped)
      if m and 'fuzzy' in [f.strip() for f in m.group(1).split(',')]:
         keep = [f.strip() for f in m.group(1).split(',') if f.strip() != 'fuzzy']
         out.append('#, ' + ', '.join(keep))
         rewritten += 1
         continue
      out.append(stripped)
   return '\n'.join(out), removed, rewritten


def usable_count(text):
   """Entries the PROGRAM WILL USE: a non-empty msgstr AND no fuzzy flag.

   Both halves matter. Counting non-empty msgstr alone reports no change at all
   across this tool, because defuzzing does not add a translation -- it stops the
   two gates discarding ones that are already there.
   """
   n = 0
   for block in text.split('\n\n'):
      if 'msgid' not in block or block.lstrip().startswith('#~'):
         continue
      if re.search(r'^msgid ""\s*$', block, re.M) and 'Project-Id-Version' in block:
         continue
      if re.search(r'^#,.*\bfuzzy\b', block, re.M):
         continue
      if re.search(r'^msgstr "(?!")', block, re.M):
         n += 1
   return n


def main():
   ap = argparse.ArgumentParser(description=__doc__,
                                formatter_class=argparse.RawDescriptionHelpFormatter)
   ap.add_argument('po', help='the catalogue to copy, e.g. i18n/tr4w_es.po')
   ap.add_argument('--out', help='write here')
   ap.add_argument('--install', action='store_true',
                   help='write to <exe-dir>/languages/<lang>/tr4w.po')
   ap.add_argument('--exe-dir', default=None,
                   help='where tr4w_fpc.exe lives (default %s)' % DEFAULT_EXE_DIR)
   ap.add_argument('--force-salvaged', action='store_true',
                   help='defuzz zh_CN anyway; see the refusal message')
   args = ap.parse_args()

   if not args.out and not args.install:
      ap.error('pass --install or --out')

   if not os.path.exists(args.po):
      print('no catalogue at ' + args.po)
      return 2

   # ZH_CN IS NOT LIKE THE OTHERS AND MUST NOT BE DEFUZZED CASUALLY.
   #
   # Everywhere else, a fuzzy entry is a machine draft: the words may be wrong
   # but the CHARACTERS are what the engine produced. In zh_CN a large part of
   # the fuzzy set is salvage from tr4w_consts_chn.pas, whose bytes are damaged
   # at the bit level -- tools/i18n/salvage_lossy.py recovers what decodes as
   # well-formed UTF-8 and marks all of it fuzzy precisely because the inversion
   # guesses wrong often enough to matter, and a wrong hanzi looks exactly like
   # a right one. CLAUDE.md: "Never bulk-defuzz that catalogue -- fuzzy is the
   # only thing keeping unverified text out of a build."
   #
   # For LAYOUT measurement the text does not have to be correct, so this is a
   # refusal you may legitimately override -- but it has to be deliberate, and
   # the resulting file must never be mistaken for a translation.
   if 'zh_CN' in os.path.basename(args.po) and not args.force_salvaged:
      print('REFUSING to defuzz ' + os.path.basename(args.po) + '.')
      print('  Its fuzzy entries are not machine drafts -- they are salvage from a')
      print('  bit-damaged source, and a wrong hanzi is indistinguishable from a')
      print('  right one. See CLAUDE.md, "Never bulk-defuzz that catalogue".')
      print('  For LAYOUT testing only, pass --force-salvaged.')
      return 2

   text = io.open(args.po, encoding='utf-8').read()
   before = usable_count(text)
   fixed, removed, rewritten = defuzz(text)
   after = usable_count(fixed)

   lang = re.search(r'tr4w_([A-Za-z_]+)\.po$', os.path.basename(args.po))
   lang = lang.group(1).lower() if lang else 'xx'

   if args.install:
      repo = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
      exedir = args.exe_dir or os.path.join(repo, DEFAULT_EXE_DIR)
      target = os.path.join(exedir, 'languages', lang, 'tr4w.po')
   else:
      target = args.out

   os.makedirs(os.path.dirname(os.path.abspath(target)), exist_ok=True)
   with io.open(target, 'w', encoding='utf-8', newline='\n') as fh:
      fh.write(fixed)

   print('  language              : %s' % lang)
   print('  fuzzy lines removed   : %d' % removed)
   if rewritten:
      print('  combined flags kept   : %d  (fuzzy dropped, the rest left alone)' % rewritten)
   print('  usable entries        : %d -> %d' % (before, after))
   print('\nwrote %s' % target)
   print('\nTHIS IS A TEST ARTIFACT. It carries unreviewed machine translation and')
   print('must never be shipped -- the installer takes the embedded catalogue,')
   print('which still has the fuzzy entries removed. Delete it when done.')
   return 0


if __name__ == '__main__':
   sys.exit(main())
