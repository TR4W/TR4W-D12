"""Second pass for the contests the Cabrillo join could not match: list the
DXLog files whose FILE NAME, CABRILLO_CONTEST_NAME or CONTESTNAME contains a
distinctive token of the TR4W id. A CANDIDATE, for a human to confirm -- not
a join."""
import os
import re
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'dom-crosscheck'))
import crosscheck_dom_dxlog as cc   # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
STOP = {'CW', 'SSB', 'RTTY', 'QSO', 'PARTY', 'DX', 'CONTEST', 'THE', 'OF', 'HF',
        'AUTUMN', 'SPRING', 'FIELD', 'DAY', 'MEMORIAL', 'CUP'}


def main():
   dx = cc.read_dxlog()
   rows = [l.rstrip('\n').split('\t') for l in open(os.path.join(HERE, 'bands_join.tsv'), encoding='utf-8')][1:]
   for r in rows:
      if r[3] != 'none':
         continue
      cid = r[0]
      toks = [t for t in re.split(r'[^A-Z0-9]+', cid.upper()) if t and t not in STOP and len(t) >= 3]
      hits = []
      for f in dx:
         hay = ' '.join([f.name.upper(), f.cabrillo.upper(), f.contestname.upper()])
         hay2 = re.sub(r'[^A-Z0-9]', '', hay)
         if any(t in hay or t in hay2 for t in toks):
            hits.append('%s{%s|%s|B=%s|M=%s}' % (f.name, f.cabrillo, f.contestname,
                                                f.keys.get('BANDS', ''), f.keys.get('MODES', '')))
      print('%s :: %s' % (cid, ' ; '.join(hits[:6]) if hits else '-- no candidate --'))


if __name__ == '__main__':
   main()
