"""Groups bands_join.tsv by DXLog BANDS pattern, and prints each contest with
the synthetic matrix QSOs a stage stating DXLog's lists would turn into
X-QSOs (base = logged and exported; key = scored only)."""
import collections
import os

HERE = os.path.dirname(os.path.abspath(__file__))


def main():
   rows = [l.rstrip('\n').split('\t') for l in open(os.path.join(HERE, 'bands_join.tsv'), encoding='utf-8')]
   head, rows = rows[0], rows[1:]
   groups = collections.defaultdict(list)
   for r in rows:
      d = dict(zip(head, r))
      key = d['BANDS'] if d['status'] == 'one' else '(%s)' % d['status']
      groups[key].append(d)
   for key in sorted(groups, key=lambda k: (-len(groups[k]), k)):
      items = groups[key]
      print('== BANDS %s : %d contests' % (key, len(items)))
      for d in items:
         nb = len([x for x in d['off_base_qsos'].split(',') if x])
         nk = len([x for x in d['off_key_qsos'].split(',') if x])
         print('   %-34s %-26s M=%-30s name=%-10s off.base=%2d [%s] off.key=%2d' % (
            d['id'][:34], d['class'][:26], d['MODES'][:30], d['name_modes'], nb, d['off_base_qsos'], nk))


if __name__ == '__main__':
   main()
