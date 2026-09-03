#!/usr/bin/env python3
"""Architecture metrics for TR4W -- god classes, and whether they are shrinking.

NY4I, 2026-09-03: "We also need to start making use of the TR4QT code that
tracks the stats for God Classes (of course adapted to pascal)" and "A script
that generates the numbers is always preferable for anything you do."

TR4QT keeps .claude/METRICS.md by hand -- MainWindow LOC, a god-class count, a
coverage guess -- with a target of MainWindow under 2,500 lines. A hand-kept
table is exactly what CLAUDE.md complains about elsewhere in this repo: "Unit
and line counts are not stated here on purpose: they drift, and a stale count is
believed. Measure."  So this measures.

WHAT IT COUNTS, AND WHY EACH ONE

  lines            The blunt instrument, and the one NY4I is reacting to.
  routines         A unit with 400 routines is a god class even if it is short.
  public routines  What the rest of the program can reach -- the real coupling
                   surface. A big unit with a small interface is a module; a big
                   unit with a huge interface is a god class.
  globals          Interface-section variables. TR4W's actual coupling runs
                   through these, not through parameters, so a unit that
                   publishes forty of them cannot be split without deciding
                   where each one lives.
  used by          How many other units name it. MainUnit is reached from
                   everywhere, which is what makes it hard to break up and what
                   makes progress worth measuring.

WHAT IT DOES NOT COUNT: cyclomatic complexity, test coverage. Both are real and
neither is measurable from a text scan; claiming a number for them would be the
drift this script exists to prevent.

Usage:
    python tools/architecture-metrics.py              # the table
    python tools/architecture-metrics.py --record     # append to the doc
    python tools/architecture-metrics.py --json       # for a build step
"""

import argparse
import json
import os
import re
import sys
from datetime import date

SRC = os.path.join('tr4w', 'src')
DOC = os.path.join('docs', 'ARCHITECTURE_METRICS.md')

# A unit is a god class candidate once it is past this. Not a rule -- a filter,
# so the table shows the units the question is actually about.
REPORT_OVER = 1500

ROUTINE = re.compile(r'^\s*(?:class\s+)?(?:procedure|function|constructor|destructor)\s+([A-Za-z_][\w.]*)',
                     re.IGNORECASE | re.MULTILINE)


def strip_comments(text):
   """Remove (* *), { } and // so a routine named in prose is not counted.

   Crude on purpose: it does not track strings, because a Pascal string
   containing an unbalanced comment opener is not a thing this tree does and
   the alternative is a parser."""
   text = re.sub(r'\(\*.*?\*\)', ' ', text, flags=re.DOTALL)
   text = re.sub(r'\{.*?\}', ' ', text, flags=re.DOTALL)
   text = re.sub(r'//[^\n]*', ' ', text)
   return text


def split_sections(text):
   """(interface, implementation). Either may be empty for a program file."""
   low = text.lower()
   i = low.find('\ninterface')
   j = low.find('\nimplementation')
   if i < 0:
      return '', text
   if j < 0:
      return text[i:], ''
   return text[i:j], text[j:]


def count_globals(interface_text):
   """Interface-section var declarations -- the coupling surface that matters."""
   total = 0
   in_var = False
   for line in interface_text.splitlines():
      s = line.strip()
      if not s:
         continue
      low = s.lower()
      if re.match(r'^var\b', low):
         in_var = True
         continue
      if re.match(r'^(const|type|procedure|function|implementation|resourcestring)\b', low):
         in_var = False
         continue
      if in_var and ':' in s:
         # `a, b, c: integer;` is three.
         names = s.split(':', 1)[0]
         total += len([n for n in names.split(',') if n.strip()])
   return total


def measure(path):
   with open(path, 'r', encoding='latin-1') as fh:
      raw = fh.read()

   code = strip_comments(raw)
   iface, impl = split_sections(code)

   return {
      'unit':     os.path.splitext(os.path.basename(path))[0],
      'path':     path.replace('\\', '/'),
      'lines':    raw.count('\n') + 1,
      'routines': len(ROUTINE.findall(impl)) if impl else len(ROUTINE.findall(code)),
      'public':   len(ROUTINE.findall(iface)),
      'globals':  count_globals(iface),
   }


def pascal_files(root):
   for base, dirs, files in os.walk(root):
      dirs[:] = [d for d in dirs if d.lower() != 'backup']
      for f in files:
         if os.path.splitext(f)[1].lower() == '.pas':
            yield os.path.join(base, f)


def used_by(units, files):
   """How many units name each one. Case-insensitive: Pascal identifiers are."""
   counts = {u.lower(): 0 for u in units}
   for path in files:
      with open(path, 'r', encoding='latin-1') as fh:
         low = strip_comments(fh.read()).lower()
      me = os.path.splitext(os.path.basename(path))[0].lower()
      for u in counts:
         if u == me:
            continue
         if re.search(r'\b' + re.escape(u) + r'\b', low):
            counts[u] += 1
   return counts


def main():
   ap = argparse.ArgumentParser()
   ap.add_argument('--record', action='store_true', help='append a row to ' + DOC)
   ap.add_argument('--json', action='store_true')
   ap.add_argument('--all', action='store_true', help='every unit, not just the big ones')
   args = ap.parse_args()

   if not os.path.isdir(SRC):
      sys.stderr.write('run me from the repository root (no %s)\n' % SRC)
      return 2

   files = sorted(pascal_files(SRC))
   rows = [measure(p) for p in files]
   big = [r for r in rows if r['lines'] >= REPORT_OVER] if not args.all else rows
   big.sort(key=lambda r: -r['lines'])

   uses = used_by([r['unit'] for r in big], files)
   for r in big:
      r['used_by'] = uses[r['unit'].lower()]

   total = sum(r['lines'] for r in rows)

   if args.json:
      print(json.dumps({'date': date.today().isoformat(),
                        'units': len(rows), 'lines': total,
                        'god_classes': big}, indent=2))
      return 0

   print('TR4W architecture metrics -- %s' % date.today().isoformat())
   print('%d units, %d lines of Pascal under %s' % (len(rows), total, SRC))
   print('')
   print('%-22s %7s %9s %7s %8s %8s' %
         ('unit', 'lines', 'routines', 'public', 'globals', 'used by'))
   print('%-22s %7s %9s %7s %8s %8s' % ('-' * 22, '-' * 7, '-' * 9, '-' * 7, '-' * 8, '-' * 8))
   for r in big:
      print('%-22s %7d %9d %7d %8d %8d' %
            (r['unit'], r['lines'], r['routines'], r['public'], r['globals'], r['used_by']))
   print('')
   print('Reported: units over %d lines. --all for everything.' % REPORT_OVER)

   if args.record:
      row = '| %s | %s |\n' % (
         date.today().isoformat(),
         ' | '.join('%d' % r['lines'] for r in big[:4]))
      with open(DOC, 'a', encoding='utf-8', newline='\r\n') as fh:
         fh.write(row)
      print('appended to %s' % DOC)

   return 0


if __name__ == '__main__':
   sys.exit(main())
