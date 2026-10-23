"""Fetch WA7BNM's contest page for every contest whose identity pin names a
WA7BNM id (tr4w/test/unit/uTestContestIdentityPin.pas -- the literal rows),
and pull its "Mode:" and "Bands:" fields. Pages are cached in wa7bnm/ so a
second run reads disk. Writes wa7bnm.tsv: token, id, mode, bands."""
import os
import re
import time
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
CACHE = os.path.join(HERE, 'wa7bnm')
PIN = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', 'tr4w', 'test', 'unit', 'uTestContestIdentityPin.pas')
ROW = re.compile(r"\(Token:\s*'([^']*)';\s*WA7BNM:\s*(\d+);")


def fetch(ref):
   path = os.path.join(CACHE, '%d.html' % ref)
   if not os.path.isfile(path):
      url = 'https://www.contestcalendar.com/contestdetails.php?ref=%d' % ref
      req = urllib.request.Request(url, headers={'User-Agent': 'TR4W-Q98-measurement'})
      with urllib.request.urlopen(req, timeout=30) as r:
         data = r.read()
      with open(path, 'wb') as f:
         f.write(data)
      time.sleep(1.0)
   return open(path, encoding='utf-8', errors='replace').read()


def field(text, name):
   flat = re.sub(r'<[^>]+>', ' ', text)
   flat = flat.replace('&nbsp;', ' ')
   m = re.search(name + r':\s+([^\n\r]*)', flat)
   return re.sub(r'\s+', ' ', m.group(1)).strip() if m else ''


def main():
   os.makedirs(CACHE, exist_ok=True)
   rows = ROW.findall(open(PIN, encoding='utf-8', errors='replace').read())
   out = []
   for token, ref in rows:
      ref = int(ref)
      if ref == 0:
         out.append((token, '0', '', ''))
         continue
      try:
         t = fetch(ref)
         out.append((token, str(ref), field(t, 'Mode'), field(t, 'Bands')))
      except Exception as e:      # a failed fetch is reported, not hidden
         out.append((token, str(ref), 'FETCH-FAILED ' + type(e).__name__, ''))
   with open(os.path.join(HERE, 'wa7bnm.tsv'), 'w', encoding='utf-8', newline='\n') as f:
      f.write('token\twa7bnm\tmode\tbands\n')
      for r in out:
         f.write('\t'.join(r) + '\n')
   print('pins read:', len(rows), ' with an id:', sum(1 for r in out if r[1] != '0'),
         ' fetch failures:', sum(1 for r in out if r[2].startswith('FETCH-FAILED')))


if __name__ == '__main__':
   main()
