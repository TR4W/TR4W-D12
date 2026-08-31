"""Machine-seed every catalogue EXCEPT Polish, one language at a time.

WHY NOT Refresh-Catalogues.ps1 -Seed ALL. That loops every language, and
tr4w_pl.po is out with a translator (NY4I, 2026-08-31) -- writing to it while
someone holds a copy means their return has to be reconciled against changes
they never saw. Polish gets the same merge, dedupe and seed when it comes back.

Everything mt_seed writes is FUZZY, which is the point: a machine translation is
a starting position for a human, never an answer. Nothing here overwrites an
existing translation.
"""
import subprocess
import sys

SKIP = {'POL'}

LANGS = ['CHN', 'CZE', 'DAN', 'DUT', 'ENG', 'ESP', 'FIN', 'FRA', 'GER', 'GRE',
         'ITA', 'JPN', 'KOR', 'MNG', 'POL', 'POR', 'PTB', 'ROM', 'RUS', 'SER',
         'SWE', 'UKR']


def main():
   done, failed = [], []
   for lang in LANGS:
      if lang in SKIP:
         print('%-5s SKIPPED -- out with a translator' % lang)
         continue
      print('%-5s seeding...' % lang, flush=True)
      r = subprocess.run(
         [sys.executable, 'tools/i18n/mt_seed.py', '--lang', lang],
         capture_output=True, text=True)
      tail = [l for l in r.stdout.strip().split('\n') if l.strip()][-2:]
      for l in tail:
         print('      ' + l.strip())
      (done if r.returncode == 0 else failed).append(lang)

   print()
   print('seeded : %d  (%s)' % (len(done), ' '.join(done)))
   if failed:
      print('FAILED : %d  (%s)' % (len(failed), ' '.join(failed)))
   print('skipped: %s' % ' '.join(sorted(SKIP)))


if __name__ == '__main__':
   main()
