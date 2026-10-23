"""Joins bands_join.tsv (DXLog) and wa7bnm.tsv (WA7BNM) per TR4W contest id
and classifies each contest's band source:

   both-agree, both-disagree, dxlog-only, wa7bnm-only, NONE

Bands are normalised to TR4W band names. WA7BNM writes '80, 40, 20, 15, 10m',
'160-10m', '6m and up' and prose; anything the normaliser cannot read is
kept verbatim and reported as 'unparsed', never guessed.
Writes sources.tsv and prints the classification and the disagreements."""
import os
import re

HERE = os.path.dirname(os.path.abspath(__file__))
HF = ['160', '80', '40', '20', '15', '10']
ALL_HF = ['160', '80', '60', '40', '30', '20', '17', '15', '12', '10']
DX2TR = {'50': '6', '70': '4', '144': '2', '222': '222', '432': '432', '902': '902',
         '1296': '1296', '2300': '2304', '3400': '3456', '5650': '5760', '10G': '10G', '24G': '24G'}


def dxlog_bands(s):
   if not s or '|' in s:
      return None
   return frozenset(DX2TR.get(b.strip(), b.strip()) for b in s.split(';') if b.strip())


def wa_bands(s):
   """WA7BNM 'Bands:' -> set, or None when the text is not a plain list."""
   t = s.lower().replace('meters', 'm').replace(' ', '')
   if not t:
      return None
   out = set()
   if t in ('160-10m', '160-10m(nowarc)', '160,80,40,20,15,10m'):
      return frozenset(HF)
   if t.startswith('alll'):
      return None
   for part in re.split(r'[,;]', t):
      part = part.rstrip('m')
      m = re.fullmatch(r'(\d+)-(\d+)', part)
      if m and m.group(1) in ALL_HF and m.group(2) in ALL_HF:
         a, b = ALL_HF.index(m.group(1)), ALL_HF.index(m.group(2))
         out |= {x for x in ALL_HF[a:b + 1] if x not in ('60', '30', '17', '12')}
         continue
      if part in ALL_HF or part in ('6', '2'):
         out.add(part)
         continue
      return None
   return frozenset(out)


def main():
   dx = {}
   for l in open(os.path.join(HERE, 'bands_join.tsv'), encoding='utf-8').read().splitlines()[1:]:
      r = l.split('\t')
      dx[r[0]] = r
   wa = {}
   for l in open(os.path.join(HERE, 'wa7bnm.tsv'), encoding='utf-8').read().splitlines()[1:]:
      r = l.split('\t')
      wa[r[0]] = r
   rows = []
   kinds = {}
   for cid in sorted(dx):
      d = dx[cid]
      w = wa.get(cid, [cid, '?', '', ''])
      db = dxlog_bands(d[5]) if d[3] == 'one' else None
      has_dx = d[3] in ('one', 'disagree')
      has_wa = w[1] not in ('0', '?') and (w[2] or w[3])
      wb = wa_bands(w[3]) if has_wa else None
      if has_dx and has_wa:
         if db is not None and wb is not None:
            kind = 'both-agree' if db == wb else 'both-DISAGREE'
         else:
            kind = 'both-unparsed'
      elif has_dx:
         kind = 'dxlog-only'
      elif has_wa:
         kind = 'wa7bnm-only'
      else:
         kind = 'NONE'
      kinds.setdefault(kind, []).append(cid)
      rows.append((cid, kind, d[5], d[6], w[1], w[3], w[2]))
   with open(os.path.join(HERE, 'sources.tsv'), 'w', encoding='utf-8', newline='\n') as f:
      f.write('id\tkind\tdxlog_bands\tdxlog_modes\twa7bnm\twa_bands\twa_mode\n')
      for r in rows:
         f.write('\t'.join(r) + '\n')
   for k in sorted(kinds):
      print('%-15s %3d' % (k, len(kinds[k])))
   for k in ('both-DISAGREE', 'wa7bnm-only', 'NONE', 'both-unparsed'):
      print('\n== %s' % k)
      for r in rows:
         if r[1] == k:
            print('   %-28s DX[%s | %s]  WA%s[%s | %s]' % (r[0], r[2], r[3], r[4], r[5], r[6]))


if __name__ == '__main__':
   main()
