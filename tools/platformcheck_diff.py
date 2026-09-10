#!/usr/bin/env python3
"""Compare platform-conformance results across targets.

   python tools/platformcheck_diff.py <dir-or-file> [<dir-or-file> ...]

Reads the platformcheck-<target>.json files that tr4w_platformcheck writes on
each platform and prints one row per probe with every target's answer beside
it.

WHY THE COMPARISON IS THE POINT, and not the individual runs. A probe that
FAILS is caught on the machine that ran it and needs no help from this script.
The interesting output is the other kind: a probe that PASSES everywhere while
answering differently, because that is a difference the code is silently
carrying. SizeOf(TThreadID) is 4 on Win32 and 8 on both Unixes; nothing failed,
and a unit holding it in an integer is broken on two of three platforms.

    DIFFERS  is the column worth reading.
    same     rows are shown too, because a fact that is stable across three
             platforms is worth knowing is stable rather than assumed to be.

MISSING IS NOT AGREEMENT. A probe absent from one target's file -- because it
is inside an {$IFDEF} for another -- prints as '-' and is never counted as a
match. Treating absence as sameness is how a conformance report tells you
everything is fine about a question one platform was never asked.
"""

import json
import os
import sys


def load(path):
   """Return (target, {key: (outcome, actual)}) for one result file."""
   with open(path, encoding='utf-8') as fh:
      doc = json.load(fh)

   probes = {}
   for key, rec in doc.get('probes', {}).items():
      probes[key] = (rec.get('outcome', '?'), rec.get('actual', ''))

   return doc.get('target', os.path.basename(path)), probes


def collect(args):
   """Expand directories to the result files inside them."""
   files = []
   for arg in args:
      if os.path.isdir(arg):
         for name in sorted(os.listdir(arg)):
            if name.startswith('platformcheck-') and name.endswith('.json'):
               files.append(os.path.join(arg, name))
      else:
         files.append(arg)
   return files


def main(argv):
   files = collect(argv[1:] or ['.'])

   if not files:
      print('no platformcheck-*.json files found', file=sys.stderr)
      return 2

   results = [load(p) for p in files]
   targets = [t for t, _ in results]

   keys = []
   for _, probes in results:
      for key in probes:
         if key not in keys:
            keys.append(key)
   keys.sort()

   # Column widths from the content, so a long library path does not wrap.
   key_w = max([len(k) for k in keys] + [len('probe')])
   col_w = []
   for i, target in enumerate(targets):
      widest = len(target)
      for key in keys:
         widest = max(widest, len(results[i][1].get(key, ('', '-'))[1]))
      col_w.append(widest)

   header = 'probe'.ljust(key_w)
   for i, target in enumerate(targets):
      header += '  ' + target.ljust(col_w[i])
   header += '  verdict'
   print(header)
   print('-' * len(header))

   differing = 0
   failing = 0

   for key in keys:
      row = key.ljust(key_w)
      seen = []
      present = 0

      for i in range(len(results)):
         outcome, actual = results[i][1].get(key, ('missing', '-'))
         if outcome == 'missing':
            shown = '-'
         else:
            present += 1
            shown = actual
            seen.append(actual)
            if outcome == 'FAIL':
               failing += 1
         row += '  ' + shown.ljust(col_w[i])

      # MISSING NEVER COUNTS AS AGREEMENT -- see the module note.
      if present < len(results):
         verdict = 'not asked everywhere'
      elif len(set(seen)) > 1:
         verdict = 'DIFFERS'
         differing += 1
      else:
         verdict = 'same'

      print(row + '  ' + verdict)

   print('')
   print('%d probe(s), %d differ across targets, %d failed somewhere'
         % (len(keys), differing, failing))

   if failing:
      print('')
      print('A FAILED probe means a platform answered something this build was')
      print('not written against. Fix the code or correct the expectation --')
      print('and the expectation is wrong often enough to check it first.')

   return 1 if failing else 0


if __name__ == '__main__':
   sys.exit(main(sys.argv))
