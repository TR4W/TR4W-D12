import csv
import os
import io

SRC = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'sources.tsv')
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', 'docs', 'Q98_CONTEST_BANDS_MODES.csv')

ORDER = {'NONE': 0, 'both-DISAGREE': 1, 'both-unparsed': 2, 'wa7bnm-only': 3, 'dxlog-only': 4, 'both-agree': 5}
WHAT = {
   'NONE': 'NO SOURCE -- please state bands and modes',
   'both-DISAGREE': 'DXLog and WA7BNM DISAGREE -- please decide',
   'both-unparsed': 'WA7BNM wording needs a reading (e.g. "VHF", "All except WARC") -- please confirm',
   'wa7bnm-only': 'WA7BNM only -- confirm',
   'dxlog-only': 'DXLog only -- confirm',
   'both-agree': 'both sources agree -- proposed is used unless you change it',
}

rows = list(csv.DictReader(open(SRC, encoding='utf-8'), delimiter='\t'))
kinds = set(r['kind'] for r in rows)
unknown = kinds - set(ORDER)
if unknown:
   raise SystemExit('unknown kind values: %r' % unknown)
rows.sort(key=lambda r: (ORDER[r['kind']], r['id']))

buf = io.StringIO()
w = csv.writer(buf, quoting=csv.QUOTE_ALL, lineterminator='\r\n')
w.writerow(['contest_id', 'status', 'what_is_needed', 'dxlog_bands', 'dxlog_modes',
            'wa7bnm_ref', 'wa7bnm_bands', 'wa7bnm_mode', 'proposed_bands',
            'your_bands', 'your_modes', 'notes'])
for r in rows:
   proposed = r['dxlog_bands'] if r['kind'] == 'both-agree' else ''
   w.writerow([r['id'], r['kind'], WHAT[r['kind']], r['dxlog_bands'], r['dxlog_modes'],
               '' if r['wa7bnm'] in ('', '0') else r['wa7bnm'], r['wa_bands'], r['wa_mode'],
               proposed, '', '', ''])
open(OUT, 'w', encoding='utf-8-sig', newline='').write(buf.getvalue())
from collections import Counter
print(len(rows), 'rows;', dict(Counter(r['kind'] for r in rows)))
