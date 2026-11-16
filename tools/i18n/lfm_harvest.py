"""Harvest the translatable text of every designed form, without the Lazarus IDE.

WHY THIS EXISTS (issue 145, 2026-11-15). A designed form's captions reach the
catalogues through the .lrj the Lazarus IDE writes when the form is SAVED in
the IDE. Forms are edited as text far more often than they are saved there, so
every control added or renamed since a form's last IDE save had no catalogue
entry -- lblLanguage and lblLanguageHint on Preferences, and nine forms with no
.lrj at all. Nothing warned: the program runs on the .lfm's English, in every
language. This reads the .lfm files themselves, so the harvest no longer
depends on anyone having opened a form in the IDE.

WHAT IT HARVESTS. The properties the IDE's harvest writes for these forms
(measured from every .lrj in the tree): Caption, Hint, Text, TextHint, Title and
TextForNullDate, on the form, on every named component, on collection items
(`panels[0].text`) and on nested properties (`title.caption`). Each becomes the
identifier TPOTranslator looks up -- `t<formclass>.<component>.<property>`,
lower case, the form's own properties as `t<formclass>.<property>`. A string
that is not language (pofile.is_translatable: 'F1', '8', '...') is skipped,
because po_merge never adds one either. TStrings lists (`Items.Strings`) are
not harvested: TPOTranslator does not translate them.

WHICH FORMS. Every .lfm under tr4w/src except EXCLUDED_FORMS, each excluded
with its reason; an exclusion naming a form that no longer exists fails.

THREE MODES
  --pot <path>   write the harvest as a template, for
                 `po_merge.py --pot <path> --apply --add-only` -- the safe,
                 additive route. Never pas2po, never tr4w_laz.pot.
  --check        the gate (Run-Lints.ps1, Lint-LFMCatalogue.ps1): exit 1 when a
                 harvested string has no entry in some i18n/tr4w_*.po, and
                 print the two commands that fix it.
  --list         every harvested identifier and its English, and stop.

WHAT COUNTS AS PRESENT. Any live (not #~) entry that claims the identifier --
pofile.claimed_identifiers, the rule po_merge, po_coverage and LazUtils use.
Text is not required: an empty fuzzy entry is the correct state for a new
caption, and the English shows until someone translates it. A caption that
the form's code overwrites at run time still gets an entry: the entry costs a
translator one line, and deciding per control which captions are placeholders
is a judgement this gate cannot make and must not guess at.

IT FAILS CLOSED: no form, no string, an .lfm it cannot parse, or no catalogue
is exit 2, never a pass.

Usage
-----
  python tools/i18n/lfm_harvest.py --check
  python tools/i18n/lfm_harvest.py --pot <scratch>.pot
  python tools/i18n/lfm_harvest.py --list
"""

import argparse
import glob
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pofile


# The IDE's harvest writes these for this tree's forms -- measured from every
# .lrj, 2026-11-15: caption 574, text 6, hint 2, texthint 2, title 1,
# textfornulldate 1. Compared lower case; the last segment of a dotted name.
HARVESTED = ('caption', 'hint', 'text', 'texthint', 'title', 'textfornulldate')

# A form that is never translated by these catalogues, and why. A name here
# that matches no .lfm FAILS: the list only shrinks.
EXCLUDED_FORMS = {
   'uServerForm.lfm': 'tr4wserver\'s window; that program loads no catalogue',
}

OBJ_RE = re.compile(r'^\s*(object|inherited|inline)\s+(\w*)\s*:\s*(\w+)', re.I)
PROP_RE = re.compile(r'^\s*([A-Za-z_][\w.]*)\s*=\s*(.*)$')
STRING_PART_RE = re.compile(r"\s*(?:'((?:[^']|'')*)'|#(\d+))")


class LfmError(Exception):
   pass


def decode_value(text, more_lines):
   """The value of a string property: quoted runs, #nnn characters and `+`
   continuations onto the following lines. None when the value is not a
   string (a number, an identifier, a set, a list)."""
   parts = []
   rest = text
   while True:
      pos = 0
      matched = False
      while True:
         m = STRING_PART_RE.match(rest, pos)
         if not m:
            break
         matched = True
         if m.group(1) is not None:
            parts.append(m.group(1).replace("''", "'"))
         else:
            parts.append(chr(int(m.group(2))))
         pos = m.end()
      if not matched:
         return None
      tail = rest[pos:].strip()
      if tail == '':
         return ''.join(parts)
      if tail == '+':
         try:
            rest = next(more_lines)
         except StopIteration:
            raise LfmError('a string continues past the end of the file')
         continue
      return None                      # e.g. 'abc' followed by something odd


def harvest_file(path):
   """[(identifier, English, owning component's name, lower case)] for one
   .lfm, in file order. The owner of the form's own properties is the form's
   object name ('frmsetupwizard')."""
   with open(path, encoding='utf-8-sig') as fh:
      lines = iter(fh.read().splitlines())

   form_class = None
   depth = 0                           # object nesting
   component = []                      # the component name at each object depth
   collection = []                     # [(name, item index)] while inside < >
   result = []

   for line in lines:
      stripped = line.strip()
      if not stripped:
         continue

      m = OBJ_RE.match(line)
      if m:
         name, cls = m.group(2), m.group(3)
         if form_class is None:
            form_class = cls.lower()
         component.append(name.lower())
         depth += 1
         continue

      low = stripped.lower()
      if collection:
         if low == 'item':
            collection[-1][1] += 1
            continue
         if low in ('end', 'end>'):
            if low == 'end>':
               collection.pop()
            continue
         if low == '>':
            collection.pop()
            continue

      if low == 'end':
         if depth == 0:
            raise LfmError('%s: an end with no object open' % path)
         depth -= 1
         component.pop()
         continue

      pm = PROP_RE.match(line)
      if not pm:
         continue                      # a list item, binary data, a set continuation
      prop, value = pm.group(1), pm.group(2).strip()

      if value == '<':
         collection.append([prop.lower(), -1])
         continue
      if value == '<>':
         continue
      if value.startswith('('):
         # a TStrings list or a set: skip to its closing ')'
         while not value.rstrip().endswith(')'):
            try:
               value = next(lines).strip()
            except StopIteration:
               raise LfmError('%s: a list never closes' % path)
         continue
      if value.startswith('{'):
         while not value.rstrip().endswith('}'):
            try:
               value = next(lines).strip()
            except StopIteration:
               raise LfmError('%s: binary data never closes' % path)
         continue

      if prop.split('.')[-1].lower() not in HARVESTED:
         continue
      text = decode_value(value, lines)
      if text is None:
         continue
      if form_class is None:
         raise LfmError('%s: a property before any object' % path)

      ident = [form_class]
      if depth > 1:
         ident.append(component[-1])
      if collection:
         name, index = collection[-1]
         ident.append('%s[%d]' % (name, index))
      ident.append(prop.lower())
      result.append(('.'.join(ident), text, component[-1]))

   if depth != 0 or collection:
      raise LfmError('%s: %d object(s) never closed' % (path, depth))
   return result


def _in_backup_dir(path, root):
   parts = os.path.relpath(path, root).replace('\\', '/').lower().split('/')
   return 'backup' in parts[:-1]


def form_files(src, excluded=None):
   """Every .lfm under SRC the catalogues translate, and the stale exclusions.

   NOT the IDE's `backup/` directories: Lazarus keeps the previous copy of
   every form it saves there (git-ignored), and harvesting those reported the
   OLD English of a reworded caption as the current one."""
   if excluded is None:
      excluded = EXCLUDED_FORMS
   found = sorted(p for p in glob.glob(os.path.join(src, '**', '*.lfm'), recursive=True)
                  if not _in_backup_dir(p, src))
   names = {os.path.basename(p) for p in found}
   stale = sorted(n for n in excluded if n not in names)
   files = [p for p in found if os.path.basename(p) not in excluded]
   return files, stale


# THE .lfm's OWN WORD THAT A CAPTION IS A PLACEHOLDER. A form whose captions
# the code assigns at run time (the uServerLogForm pattern) says so in the
# .lfm, one of two ways, and such text is not English anyone reads -- NY4I,
# 2026-08-31: nobody needs a control name translated.
#   * the caption IS the control's own name ('lblHeading' on lblHeading,
#     'frmSetupWizard' on the form). Compared with the owner's name, never by
#     the shape of the text: a widget-prefix pattern misses 'tsStation'.
#   * the caption carries the marker '(assigned at run time' or '(set at run
#     time' -- 'Bank (assigned at run time)', '(set at run time from
#     SLoggerEditorNote)'.
RUN_TIME_MARKER = re.compile(r'\((?:assigned|set) at run time\b', re.I)


def is_placeholder(text, owner):
   """True when the .lfm itself says this text is replaced at run time."""
   if text.strip().lower() == owner.lower():
      return True
   return RUN_TIME_MARKER.search(text) is not None


def harvest(files):
   """([(identifier, English, form file)], placeholders skipped): translatable
   strings only, each identifier once."""
   seen = set()
   result = []
   placeholders = 0
   for path in files:
      for ident, text, owner in harvest_file(path):
         if not pofile.is_translatable(text):
            continue
         if is_placeholder(text, owner):
            placeholders += 1
            continue
         if ident in seen:
            continue
         seen.add(ident)
         result.append((ident, text, os.path.basename(path)))
   return result, placeholders


def write_pot(path, strings):
   """A template po_merge can apply: one entry per identifier, no msgctxt,
   so po_merge's (msgctxt, msgid) join (issue 156) can attach a caption to an
   existing entry with the same English instead of duplicating it."""
   entries = [pofile.Entry(key=None, source=text, refs=[ident])
              for ident, text, _ in strings]
   pofile.write_po(path, entries, 'en')


def claimed(path):
   """{identifier: msgid} for every identifier a live entry of this catalogue
   answers for (pofile.claimed_identifiers, the rule po_merge uses)."""
   ids = {}
   for e in pofile.read_po(path):
      if not e.obsolete:
         for ident in pofile.claimed_identifiers(e):
            ids.setdefault(ident, e.source)
   return ids


def _same_english(a, b):
   """Equal once a line break is a line break however it is spelled."""
   def norm(s):
      return s.replace('\r\n', '\n').replace('\r', '\n')
   return norm(a) == norm(b)


def main(argv=None):
   ap = argparse.ArgumentParser(description=__doc__,
                                formatter_class=argparse.RawDescriptionHelpFormatter)
   mode = ap.add_mutually_exclusive_group(required=True)
   mode.add_argument('--check', action='store_true', help='the gate')
   mode.add_argument('--pot', help='write the harvest as a template here')
   mode.add_argument('--list', action='store_true', help='print the harvest')
   ap.add_argument('--dir', default=None, help='the i18n directory')
   ap.add_argument('--src', default=None, help='the form tree (default tr4w/src)')
   args = ap.parse_args(argv)

   repo = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
   files, stale = form_files(args.src or os.path.join(repo, 'tr4w', 'src'))
   if stale:
      print('lfm_harvest: FAILED -- EXCLUDED_FORMS names a form that does not exist: %s'
            % ', '.join(stale))
      return 2
   try:
      strings, placeholders = harvest(files)
   except LfmError as e:
      print('lfm_harvest: FAILED CLOSED -- %s' % e)
      return 2
   if not files or not strings:
      print('lfm_harvest: FAILED CLOSED -- %d form(s), %d string(s)'
            % (len(files), len(strings)))
      return 2

   if args.list:
      for ident, text, form in strings:
         print('%-60s %r' % (ident, text))
      print('%d string(s) from %d form(s); %d run-time placeholder(s) skipped'
            % (len(strings), len(files), placeholders))
      return 0

   if args.pot:
      write_pot(args.pot, strings)
      print('lfm_harvest: wrote %d string(s) from %d form(s) to %s'
            % (len(strings), len(files), args.pot))
      return 0

   i18n = args.dir or os.path.join(repo, 'i18n')
   catalogues = sorted(glob.glob(os.path.join(i18n, 'tr4w_*.po')))
   if not catalogues:
      print('lfm_harvest: FAILED CLOSED -- no catalogue in %s' % i18n)
      return 2
   ids = {os.path.basename(c): claimed(c) for c in catalogues}
   gaps = []
   drift = []
   for ident, text, form in strings:
      lacking = [c for c, have in ids.items() if ident not in have]
      if lacking:
         gaps.append((ident, text, form, lacking))
      stale = sorted({have[ident] for have in ids.values()
                      if ident in have and not _same_english(have[ident], text)})
      if stale:
         drift.append((ident, text, stale))

   # REWORDED ENGLISH: REPORTED, NOT GATED. LazUtils finds a translation by
   # identifier alone, so when a caption's English is reworded in the .lfm the
   # catalogue's translation of the OLD English keeps shipping under it, and
   # po_merge (also by identifier) cannot see it. Fixing one rewrites an
   # existing entry -- a person's step, docs/I18N_TOOLS.md "reworded caption"
   # -- so this warns and the gate does not fail on it.
   if drift:
      print('lfm_harvest: WARNING -- %d caption(s) reworded in the .lfm; the '
            'catalogue entry still has the old English (its translation ships '
            'under the new text -- see docs/I18N_TOOLS.md):' % len(drift))
      for ident, text, stale in drift:
         print('  %-56s now %r' % (ident, text[:60]))
         for old in stale:
            print('  %-56s was %r' % ('', old[:60]))

   if not gaps:
      print('lfm_harvest: OK -- %d .lfm string(s) from %d form(s), each in all %d '
            'catalogues (%d run-time placeholder(s) skipped)'
            % (len(strings), len(files), len(catalogues), placeholders))
      return 0

   print('lfm_harvest: FAILED -- %d .lfm string(s) missing from a catalogue '
         '(the operator sees English in every language that lacks one):' % len(gaps))
   for ident, text, form, lacking in gaps:
      where = ('all %d' % len(catalogues)) if len(lacking) == len(catalogues) \
         else ', '.join(lacking)
      print('  %-56s %-32r %s' % (ident, text[:32], where))
   print('')
   print('  Add them -- additive, never pas2po (docs/I18N_TOOLS.md):')
   print('    python tools/i18n/lfm_harvest.py --pot <scratch>.pot')
   print('    python tools/i18n/po_merge.py --pot <scratch>.pot --apply --add-only')
   return 1


if __name__ == '__main__':
   sys.exit(main())
