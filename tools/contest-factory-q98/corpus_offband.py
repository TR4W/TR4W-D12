"""For each golden-corpus set: the (band, Cabrillo mode) pairs of its ref.cbr
QSO lines, so a stage can predict which sets' exports move when their
contest states its bands and modes."""
import collections
import os
import re

CORPUS = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', 'tr4w', 'test', 'corpus')


def band_of(khz):
   f = int(khz)
   table = [(1800, 2000, '160'), (3500, 4000, '80'), (5000, 5500, '60'),
            (7000, 7300, '40'), (10100, 10150, '30'), (14000, 14350, '20'),
            (18068, 18168, '17'), (21000, 21450, '15'), (24890, 24990, '12'),
            (28000, 29700, '10')]
   for lo, hi, b in table:
      if lo <= f <= hi:
         return b
   if f in (50, 144, 222, 432, 902, 1296):
      return str(f)
   return 'khz' + str(f)


def main():
   for d in sorted(os.listdir(CORPUS)):
      p = os.path.join(CORPUS, d, 'ref.cbr')
      if not os.path.isfile(p):
         continue
      c = collections.Counter()
      for line in open(p, encoding='utf-8', errors='replace'):
         m = re.match(r'^(?:X-)?QSO:\s+(\d+)\s+(\S+)\s', line)
         if m:
            c[(band_of(m.group(1)), m.group(2))] += 1
      print('%-26s %s' % (d, ' '.join('%s/%s=%d' % (b, mo, n) for (b, mo), n in sorted(c.items()))))


if __name__ == '__main__':
   main()
