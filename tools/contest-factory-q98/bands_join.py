"""Q98 measurement: join every TR4W contest (the frozen contest matrix) to
DXLog's BANDS= / MODES= keys, through the dom-crosscheck tool's own join
(read_matrix, read_dxlog, dxlog_candidates, CABRILLO_OVERRIDES).

Writes bands_join.tsv beside this script and prints a summary.

For each contest it also PREDICTS which of the matrix's 17 logged synthetic
QSOs (uContestMatrix.MATRIX_QSOS) and 19 key QSOs (MATRIX_KEY_QSOS) would be
off-band or off-mode under the DXLog lists -- the matrix lines a stage that
states those lists would move.
"""
import os
import re
import sys

TOOL = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'dom-crosscheck')
sys.path.insert(0, TOOL)
import crosscheck_dom_dxlog as cc   # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))

# uContestMatrix.MATRIX_QSOS, index -> (band, mode token)
BASE_QSOS = {
   1: ('20', 'CW'), 2: ('20', 'SSB'), 3: ('144', 'FM'), 4: ('40', 'RTTY'),
   5: ('20', 'FT8'), 6: ('160', 'CW'), 7: ('15', 'SSB'), 8: ('10', 'CW'),
   9: ('30', 'CW'), 10: ('40', 'SSB'), 11: ('15', 'CW'), 12: ('50', 'SSB'),
   13: ('20', 'CW'), 14: ('10', 'SSB'), 15: ('20', 'SSB'), 16: ('80', 'CW'),
   17: ('20', 'SSB'),
}
# uContestMatrix.MATRIX_KEY_QSOS (18..36): all CW but 23 (SSB); bands
KEY_QSOS = {}
_kb = ['20', '15', '20', '20', '40', '20', '20', '20', '20', '20', '40',
       '20', '20', '40', '40', '20', '20', '20', '20']
for i, b in enumerate(_kb):
   KEY_QSOS[18 + i] = (b, 'SSB' if 18 + i == 23 else 'CW')

DXLOG_BAND = {'2300': '2304', '3400': '3456', '5650': '5760'}

# A mode implied by the TR4W contest's own id: the CW/SSB/RTTY runnings are
# separate contests in TR4W and ONE file in DXLog (CQWW.txt: MODES=CW;SSB).
NAME_MODE_RULES = [
   (re.compile(r'(^|[-_ ])(CW)($|[-_ ])'), {'CW'}),
   (re.compile(r'(^|[-_ ])(SSB|PH|PHONE)($|[-_ ])'), {'SSB', 'FM', 'AM'}),
   (re.compile(r'(^|[-_ ])(RTTY|RY)($|[-_ ])'), {'RTTY'}),
]


def name_modes(contest_id):
   hits = set()
   for rx, modes in NAME_MODE_RULES:
      if rx.search(contest_id.upper()):
         hits |= modes
   return hits


def mode_ok(token, modes):
   """Is a synthetic QSO's mode in a DXLog MODES list?"""
   if token == 'SSB':
      return 'SSB' in modes or 'USB' in modes or 'LSB' in modes
   if token == 'FT8':
      return 'FT8' in modes
   return token in modes


def main():
   records = cc.read_matrix()
   dx = cc.read_dxlog()
   seen = {}
   for r in records:
      seen.setdefault(r['contest'], r)
   class_of = {}
   for path in os.listdir(cc.MATRIX_DIR):
      for line in open(os.path.join(cc.MATRIX_DIR, path), encoding='utf-8', errors='replace'):
         if line.startswith('contest.requested = '):
            cid = line.split('=', 1)[1].split(' (')[0].strip()
         if line.startswith('contest.class = '):
            class_of[cid] = line.split('=', 1)[1].strip()
            break
   rows = []
   for cid in sorted(seen):
      cab = seen[cid]['cabrillo'] or ''
      cands = cc.dxlog_candidates(dx, cab) if cab else []
      bands = sorted({f.keys.get('BANDS', '') for f in cands} - {''})
      modes = sorted({f.keys.get('MODES', '') for f in cands} - {''})
      files = ';'.join(f.name for f in cands)
      status = 'none'
      if cands:
         status = 'one' if len(bands) <= 1 and len(modes) <= 1 else 'disagree'
         if not bands:
            status = 'no-BANDS-key'
      off_base, off_key = [], []
      nm = name_modes(cid)
      if len(bands) == 1:
         bset = {DXLOG_BAND.get(b.strip(), b.strip()) for b in bands[0].split(';')}
         mset = {m.strip().upper() for m in modes[0].split(';')} if len(modes) == 1 else None
         if nm and mset is not None:
            mset = mset & nm if mset & nm else mset
         for table, out in ((BASE_QSOS, off_base), (KEY_QSOS, off_key)):
            for i, (b, m) in sorted(table.items()):
               bad = b not in bset
               if mset is not None and not mode_ok(m, mset):
                  bad = True
               if bad:
                  out.append(str(i))
      rows.append((cid, class_of.get(cid, '?'), cab, status, files,
                   '|'.join(bands), '|'.join(modes), ','.join(sorted(nm)),
                   ','.join(off_base), ','.join(off_key)))
   tsv = os.path.join(HERE, 'bands_join.tsv')
   with open(tsv, 'w', encoding='utf-8', newline='\n') as f:
      f.write('id\tclass\tcabrillo\tstatus\tdxlog_files\tBANDS\tMODES\tname_modes\toff_base_qsos\toff_key_qsos\n')
      for r in rows:
         f.write('\t'.join(r) + '\n')
   counts = {}
   for r in rows:
      counts[r[3]] = counts.get(r[3], 0) + 1
   print('contests:', len(rows))
   for k in sorted(counts):
      print('  %-14s %d' % (k, counts[k]))
   print('wrote', tsv)


if __name__ == '__main__':
   main()
