"""Download a few ARRL public Cabrillo logs per contest, for reference.

WHY: a sponsor's public logs are the ground truth for what a real Cabrillo
file for that contest looks like -- the CONTEST: name, the header lines and
the QSO-line columns -- as written by the loggers people actually use. NY4I,
2026-10-15: "For cabrillo questions, a good source of info about the cabrillo
logs are what are called Public Logs."

WHERE THEY GO: build-out/public-logs/arrl/<contest>/<year>/<CALL>.log, which
is gitignored. They are other operators' logs: read them, quote a header or
a column layout from them, but never commit them to this public repository.

HOW: contests.arrl.org/publiclogs.php lists the contests (eid), each contest
page lists its years (iid), and each year page links every log as
showpubliclog.php?cn=<code>&yr=<year>&call=<CALL>, served as text/plain.

   python tools/public-logs/fetch_arrl_public_logs.py               # every contest, latest year, 3 logs
   python tools/public-logs/fetch_arrl_public_logs.py --per 5 --contest 3
   python tools/public-logs/fetch_arrl_public_logs.py --list         # the contests and their eids

Prints, per contest, the CONTEST: line(s) and one QSO line, which is usually
all a Cabrillo question needs. Polite by design: one request at a time and a
pause between them.
"""

import argparse
import html
import os
import re
import sys
import time
import urllib.request

BASE = 'https://contests.arrl.org/'
PAUSE_SECONDS = 1.0
TIMEOUT_SECONDS = 30
USER_AGENT = 'TR4W-reference-fetch/1.0 (https://github.com/TR4W/TR4W-D12)'

REPO_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
OUT_ROOT = os.path.join(REPO_ROOT, 'build-out', 'public-logs', 'arrl')


def fetch(url):
   time.sleep(PAUSE_SECONDS)
   request = urllib.request.Request(url, headers={'User-Agent': USER_AGENT})
   with urllib.request.urlopen(request, timeout=TIMEOUT_SECONDS) as response:
      return response.read().decode('utf-8', errors='replace')


def list_contests():
   page = fetch(BASE + 'publiclogs.php')
   contests = []
   for eid, name in re.findall(r'<option value=(\d+)>([^<]+)', page):
      if eid != '0':
         contests.append((int(eid), html.unescape(name).strip()))
   return contests


def latest_year(eid):
   """The newest year on a contest's page: (year, iid), or None."""
   page = fetch(BASE + 'publiclogs.php?eid=%d' % eid)
   years = re.findall(r'href="publiclogs\.php\?eid=%d&iid=(\d+)">(\d{4})</a>' % eid, page)
   if not years:
      return None
   iid, year = max(years, key=lambda pair: int(pair[1]))
   return int(year), int(iid)


def log_links(eid, iid):
   """Every (contest code, year, call) the year page links."""
   page = fetch(BASE + 'publiclogs.php?eid=%d&iid=%d' % (eid, iid))
   return re.findall(r'showpubliclog\.php\?cn=([^&"]+)&yr=(\d{4})&call=([^"&]+)', page)


def summarise(text):
   contest_lines = sorted(set(re.findall(r'^CONTEST:.*$', text, re.M)))
   qso = re.search(r'^QSO:.*$', text, re.M)
   created = re.search(r'^CREATED-BY:.*$', text, re.M)
   return contest_lines, (qso.group(0) if qso else None), (created.group(0) if created else None)


def main():
   parser = argparse.ArgumentParser(description=__doc__.split('\n')[0])
   parser.add_argument('--per', type=int, default=3, help='logs per contest (default 3)')
   parser.add_argument('--contest', type=int, action='append',
                       help='an eid from --list; repeatable; default every contest')
   parser.add_argument('--list', action='store_true', help='list the contests and stop')
   args = parser.parse_args()

   contests = list_contests()
   if not contests:
      print('FAILED: no contests found on publiclogs.php -- the page layout changed?')
      return 1

   if args.list:
      for eid, name in contests:
         print('%4d  %s' % (eid, name))
      return 0

   wanted = [c for c in contests if (not args.contest) or (c[0] in args.contest)]
   if not wanted:
      print('FAILED: no contest matches --contest %s' % args.contest)
      return 1

   failures = 0
   for eid, name in wanted:
      found = latest_year(eid)
      if found is None:
         print('== %s (eid %d): no years listed' % (name, eid))
         failures += 1
         continue
      year, iid = found
      links = log_links(eid, iid)
      if not links:
         print('== %s (eid %d) %d: no logs listed' % (name, eid, year))
         failures += 1
         continue

      print('== %s (eid %d) %d: %d public logs' % (name, eid, year, len(links)))
      for code, yr, call in links[:args.per]:
         url = BASE + 'showpubliclog.php?cn=%s&yr=%s&call=%s' % (code, yr, call)
         try:
            text = fetch(url)
         except Exception as error:
            print('   %-10s FAILED: %s' % (call, error))
            failures += 1
            continue

         folder = os.path.join(OUT_ROOT, code, yr)
         os.makedirs(folder, exist_ok=True)
         safe_call = re.sub(r'[^A-Za-z0-9_-]', '_', html.unescape(call))
         with open(os.path.join(folder, safe_call + '.log'), 'w', encoding='utf-8', newline='') as out:
            out.write(text)

         contest_lines, qso, created = summarise(text)
         print('   %-10s %s | %s' % (call, '; '.join(contest_lines) or 'NO CONTEST: LINE',
                                    created or 'no CREATED-BY'))
         if qso:
            print('              %s' % qso)

   print('saved under %s' % OUT_ROOT)
   return 1 if failures else 0


if __name__ == '__main__':
   sys.exit(main())
