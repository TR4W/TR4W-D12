"""Classify every differing contest-matrix line against a Q98 stage's
prediction (docs/CONTEST_OWNERSHIP_DESIGN.md 8.2v, "predicted matrix
movement"). Written for S1 with CQ WW's S4a statement (2026-10-22); a later
stage edits the S1 table below for ITS contests and QSOs.

A line may move only in a predicted QSO's scoring (where the stage allows
scoring to move), export, import or keys line, and in totals; identity,
setup, parse and initialexchange never move. Prints UNPREDICTED: 0 when
every differing line is the stage.

Usage:
   python -I classify_matrix.py <frozen dir> <fresh dir> <record name>...
   (the record names are run-contest-matrix.sh's "failing:" list)
"""
import re
import sys

FROZEN, FRESH = sys.argv[1], sys.argv[2]

ALL_BASE = set(range(1, 18))
KEYS = set(range(18, 37))

# record name -> (predicted base QSOs, predicted keys, may scoring move?,
#                 score/CLAIMED-SCORE may move?)
S1 = {}
for r in ['ARRL-160', 'CQ-160-CW', 'CQ-160-SSB', 'RSGB-160']:
   S1[r] = (ALL_BASE - {6}, set(), False, False)
for r in ['IDAHO_QSO_PARTY', 'IN_QSO_PARTY', '7QP']:
   S1[r] = ({3, 9, 12}, set(), False, False)
S1['NEWEQP'] = ({3, 6, 9, 12}, set(), False, False)
for r in ['DELAWARE_QSO_PARTY', 'NE-QSO-PARTY', 'IN7QPNE']:
   S1[r] = ({9}, set(), False, False)
S1['CQ-WW-CW'] = ({2, 3, 4, 5, 7, 9, 10, 12, 14, 15, 17}, {23}, True, True)
S1['CQ-WW-SSB'] = ({1, 3, 4, 5, 6, 8, 9, 11, 13, 16, 12}, KEYS, True, True)
# Not in the design's S4a row (it is S5's contest): every base QSO but 4
# (40 m RTTY), and every key, which moves to Digital/eRTTY.
S1['CQ-WW-RTTY'] = (ALL_BASE - {4}, KEYS, True, True)


def parse(path):
   """variant -> section -> list of lines"""
   out = {}
   variant = None
   section = None
   for raw in open(path, encoding='utf-8', errors='replace').read().split('\n'):
      line = raw.rstrip('\r')
      if line.startswith('### variant'):
         variant = line
         out[variant] = {}
         section = None
         continue
      if line.startswith('== '):
         section = line[3:].strip()
         out[variant].setdefault(section, [])
         continue
      if variant is not None and section is not None:
         out[variant][section].append(line)
   return out


def qso_of(section, line, index):
   m = re.match(r'qso (\d+) ', line)
   if m:
      return int(m.group(1))
   m = re.match(r'imp export\.(\d+) ', line)
   if m:
      return int(m.group(1))
   m = re.match(r'key (\d+) ', line)
   if m:
      return int(m.group(1))
   m = re.search(r'<STX:\d+>0*(\d+)', line)
   if m and section.startswith('export.adif'):
      return int(m.group(1))
   m = re.search(r'<APP_TR4W_ID:32>0*(\d+)', line)
   if m:
      return int(m.group(1))
   m = re.match(r'(X-)?QSO: +\d+ +\w+ +\d{4}-\d\d-\d\d 12(\d\d) ', line)
   if m:
      return int(m.group(2))
   return None


def main():
   names = sys.argv[3:]
   bad = 0
   for name in names:
      fz = parse('%s/%s.matrix' % (FROZEN, name))
      fr = parse('%s/%s.matrix' % (FRESH, name))
      base, keys, scoring_ok, score_ok = S1[name]
      counts = {}
      if list(fz.keys()) != list(fr.keys()):
         print('%s: VARIANTS DIFFER' % name)
         bad += 1
         continue
      for v in fz:
         if list(fz[v].keys()) != list(fr[v].keys()):
            print('%s: SECTIONS DIFFER in %s' % (name, v))
            bad += 1
            continue
         for sec in fz[v]:
            a, b = fz[v][sec], fr[v][sec]
            if sec == 'totals':
               if a != b:
                  counts['totals'] = counts.get('totals', 0) + 1
                  if not score_ok:
                     moved = [l for l in (set(a) ^ set(b))
                              if l.startswith(('totals.totalscore', 'totals.cabrillo', 'totals.qsopoints'))]
                     if moved:
                        print('%s %s totals: SCORE MOVED: %s' % (name, v[:30], sorted(moved)))
                        bad += 1
               continue
            if len(a) != len(b):
               print('%s %s %s: LINE COUNT %d -> %d' % (name, v[:30], sec, len(a), len(b)))
               bad += 1
               continue
            for i, (x, y) in enumerate(zip(a, b)):
               if x == y:
                  continue
               q = qso_of(sec, x, i)
               if sec in ('identity', 'setup', 'parse', 'initialexchange'):
                  print('%s %s %s: NEVER-MOVES section moved: %s' % (name, v[:30], sec, x[:100]))
                  bad += 1
                  continue
               if sec == 'scoring' and not scoring_ok:
                  print('%s %s scoring moved (S1 predicts none): %s' % (name, v[:30], x[:100]))
                  bad += 1
                  continue
               allowed = base if sec != 'keys' else keys
               if q is None or q not in allowed:
                  print('%s %s %s: QSO %s not predicted: %s' % (name, v[:30], sec, q, x[:120]))
                  bad += 1
                  continue
               counts[sec] = counts.get(sec, 0) + 1
      print('%-20s ok-lines %s' % (name, dict(sorted(counts.items()))))
   print('UNPREDICTED: %d' % bad)


main()
