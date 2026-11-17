"""Convert sponsor-style schedule cells in docs/CONTEST_SCHEDULES.csv.

THE INTAKE SIDE ONLY. NY4I types a contest's period the way a sponsor's page
shows it -- a start and an end:

   1st full weekend of October at 16:00 UTC until Sunday 21:59 UTC

and the contest CLASS carries the form the program parses
(uContestSchedule, docs/CONTEST_SCHEDULES_README.md):

   1st full weekend of October at 16:00 UTC for 30h

This script rewrites the first into the second. A cell with no 'until' passes
through unchanged. The program never reads the CSV and never sees 'until'.

THE RULES (NY4I, 2026-11-16):
- The end is the first moment at or after the start that matches 'until'.
- 'until <Weekday> HH:MM UTC': the first such weekday on or after the START
  day whose time is after the start. It needs the start's weekday, so the
  anchor must fix one (a full weekend, an nth weekday, 'every <weekday>', an
  ISO date); 'every day' and 'MM-DD' do not, and are refused.
- 'until HH:MM UTC' (no weekday): the next occurrence of that clock time
  after the start -- 16:00 until 02:00 crosses midnight, 00:00 until 04:00
  is the same day.
- An end minute of :59 is the LAST INCLUDED minute: 01:59 means the period
  ends at 02:00, 23:59 at the next 00:00. The period is [start, end).
- The duration is written 'for Nh' when it is whole hours, else 'for Nm'.
- 'for' and 'until' in one clause, an end not after the start, or a weekday
  end more than 7 days out is an error naming the contest id and the clause.

Usage (stdlib only; run with python -I):
   python -I convert_sponsor_times.py --check [csv]   report, change nothing
   python -I convert_sponsor_times.py --write [csv]   rewrite the CSV in place
The CSV keeps its UTF-8 BOM, CRLF line endings and 8 columns; only the
schedule cell of a converted row changes.
"""

import csv
import datetime
import io
import os
import re
import sys

DEFAULT_CSV = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                           '..', '..', 'docs', 'CONTEST_SCHEDULES.csv')

WEEKDAYS = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday',
            'saturday', 'sunday']
ORDINALS = ['1st', '2nd', '3rd', '4th', '5th', 'first', 'second', 'third',
            'fourth', 'fifth', 'last']
MAX_MINUTES = 7 * 24 * 60
MINUTES_PER_DAY = 24 * 60


class ConvertError(Exception):
   pass


def parse_hhmm(text):
   m = re.fullmatch(r'(\d\d):(\d\d)', text)
   if not m:
      raise ConvertError('not a valid HH:MM time "%s"' % text)
   hh, mm = int(m.group(1)), int(m.group(2))
   if hh > 23 or mm > 59:
      raise ConvertError('not a valid HH:MM time "%s"' % text)
   return hh * 60 + mm


def anchor_weekday(anchor_words):
   """The weekday (0 = Monday) the anchor's day falls on, before any offset,
   or None when the anchor does not fix one."""
   w = anchor_words
   if not w:
      raise ConvertError('empty anchor')
   if w[0] == 'every':
      if len(w) == 2 and w[1] in WEEKDAYS:
         return WEEKDAYS.index(w[1])
      return None
   if w[0] in ORDINALS:
      if len(w) >= 3 and w[1] == 'full' and w[2] == 'weekend':
         return WEEKDAYS.index('saturday')
      if len(w) >= 2 and w[1] in WEEKDAYS:
         return WEEKDAYS.index(w[1])
      return None
   m = re.fullmatch(r'(\d{4})-(\d\d)-(\d\d)', w[0])
   if m and len(w) == 1:
      try:
         return datetime.date(int(m.group(1)), int(m.group(2)), int(m.group(3))).weekday()
      except ValueError:
         raise ConvertError('not a valid YYYY-MM-DD date "%s"' % w[0])
   return None


def convert_clause(clause):
   """One clause: an 'until' clause becomes its 'for' form; any other clause
   comes back exactly as written."""
   words = clause.split()
   lower = [x.lower() for x in words]
   if 'until' not in lower:
      return clause
   if 'for' in lower:
      raise ConvertError('"for" and "until" in one clause')
   at = lower.index('at') if 'at' in lower else -1
   until = lower.index('until')
   if at < 0 or until != at + 3 or lower[at + 2] != 'utc':
      raise ConvertError('expected "<anchor> at HH:MM UTC until [Weekday] HH:MM UTC"')
   start = parse_hhmm(lower[at + 1])
   rest = lower[until + 1:]
   end_weekday = None
   if rest and rest[0] in WEEKDAYS:
      end_weekday = WEEKDAYS.index(rest[0])
      rest = rest[1:]
   if len(rest) != 2 or rest[1] != 'utc':
      raise ConvertError('expected "until [Weekday] HH:MM UTC" at the end')
   end_clock = parse_hhmm(rest[0])

   anchor = lower[:at]
   offset = 0
   if anchor and re.fullmatch(r'\+\d+d', anchor[-1]):
      offset = int(anchor[-1][1:-1])
      anchor = anchor[:-1]

   if end_weekday is None:
      # The next occurrence of that clock time after the start.
      minutes = end_clock - start
      if minutes <= 0:
         minutes += MINUTES_PER_DAY
   else:
      day = anchor_weekday(anchor)
      if day is None:
         raise ConvertError('"until <Weekday>" needs an anchor that fixes the start '
                            'weekday (a full weekend, an nth weekday, every <weekday> '
                            'or an ISO date)')
      start_weekday = (day + offset) % 7
      minutes = None
      for k in range(0, 8):
         if (start_weekday + k) % 7 == end_weekday:
            candidate = k * MINUTES_PER_DAY + end_clock - start
            if candidate > 0:
               minutes = candidate
               break
      if minutes is None or minutes > MAX_MINUTES:
         raise ConvertError('weekday end is more than 7 days after the start')
   if end_clock % 60 == 59:
      minutes += 1      # :59 is the last included minute
   if minutes <= 0:
      raise ConvertError('end is not after the start')
   if minutes > MAX_MINUTES:
      raise ConvertError('period is longer than 168h')
   duration = '%dh' % (minutes // 60) if minutes % 60 == 0 else '%dm' % minutes
   return ' '.join(words[:at + 3]) + ' for ' + duration


def convert_cell(cell, contest_id=''):
   """A whole schedule cell. Unchanged when no clause holds 'until'."""
   if not re.search(r'\buntil\b', cell, re.I):
      return cell
   out = []
   for i, clause in enumerate(cell.split(';')):
      text = clause.strip()
      try:
         out.append(convert_clause(text))
      except ConvertError as e:
         raise ConvertError('%s clause %d "%s": %s' % (contest_id, i + 1, text, e))
   return '; '.join(out)


def read_bytes(path):
   with open(path, 'rb') as f:
      return f.read()


def write_bytes(path, data):
   with open(path, 'wb') as f:
      f.write(data)


def read_csv(path):
   # A spreadsheet may save without the BOM; read either, always write one.
   raw = read_bytes(path)
   text = raw.decode('utf-8-sig')
   lines = text.split('\r\n')
   if '\n' in text.replace('\r\n', ''):
      raise ConvertError('%s: a bare LF; the CSV is CRLF' % path)
   return lines


def row_of(line):
   return next(csv.reader([line]))


def line_of(row):
   buf = io.StringIO()
   csv.writer(buf, lineterminator='').writerow(row)
   return buf.getvalue()


def process(path, write):
   lines = read_csv(path)
   header = row_of(lines[0])
   if len(header) != 8 or header[3] != 'schedule':
      raise ConvertError('%s: unexpected header' % path)
   changed = 0
   errors = 0
   for n in range(1, len(lines)):
      if lines[n] == '':
         continue
      row = row_of(lines[n])
      if len(row) != 8:
         raise ConvertError('%s line %d: %d columns, not 8' % (path, n + 1, len(row)))
      if not re.search(r'\buntil\b', row[3], re.I):
         continue
      try:
         converted = convert_cell(row[3], row[0])
      except ConvertError as e:
         print('ERROR', e)
         errors += 1
         continue
      print('%s\n   was: %s\n   now: %s' % (row[0], row[3], converted))
      row[3] = converted
      lines[n] = line_of(row)
      changed += 1
   print('%d row(s) with "until", %d error(s)' % (changed + errors, errors))
   if write and errors == 0 and changed:
      write_bytes(path, b'\xef\xbb\xbf' + '\r\n'.join(lines).encode('utf-8'))
      print('rewrote %s' % path)
   return errors == 0


def main(argv):
   if len(argv) < 2 or argv[1] not in ('--check', '--write'):
      print(__doc__)
      return 2
   path = argv[2] if len(argv) > 2 else DEFAULT_CSV
   try:
      return 0 if process(path, argv[1] == '--write') else 1
   except ConvertError as e:
      print('ERROR', e)
      return 1


if __name__ == '__main__':
   sys.exit(main(sys.argv))
