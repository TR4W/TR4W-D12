"""Tests for convert_sponsor_times.py. Run: python -I test_convert_sponsor_times.py

The README's "How do I enter..." table is read here: every sponsor-style cell
must convert to its class-form cell, so the document cannot drift from the
converter. (uTestContestSchedule parses the class-form cells with the
program's own parser.)"""

import os
import re
import shutil
import sys
import tempfile
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import convert_sponsor_times as cst

README = os.path.join(HERE, '..', '..', 'docs', 'CONTEST_SCHEDULES_README.md')


def readme_examples():
   text = cst.read_bytes(README).decode('utf-8-sig')
   body = text.split('<!-- schedule-examples-begin -->')[1].split('<!-- schedule-examples-end -->')[0]
   rows = []
   for line in body.splitlines():
      cells = [c.strip() for c in line.strip().strip('|').split('|')]
      if len(cells) != 3:
         continue
      sponsor = re.fullmatch(r'`([^`]*)`', cells[1])
      klass = re.fullmatch(r'`([^`]*)`', cells[2])
      if sponsor and klass:
         rows.append((cells[0], sponsor.group(1), klass.group(1)))
   return rows


class ConvertTests(unittest.TestCase):

   def test_readme_table_converts_to_its_class_form(self):
      rows = readme_examples()
      self.assertGreaterEqual(len(rows), 10, 'the README table was found')
      for want, sponsor, klass in rows:
         self.assertEqual(klass, cst.convert_cell(sponsor, want), want)

   def test_california_weekday_end_and_59(self):
      self.assertEqual('1st full weekend of October at 16:00 UTC for 30h',
                       cst.convert_cell('1st full weekend of October at 16:00 UTC until Sunday 21:59 UTC'))

   def test_cq_wpx_ssb_48h(self):
      self.assertEqual('last full weekend of March at 00:00 UTC for 48h',
                       cst.convert_cell('last full weekend of March at 00:00 UTC until Sunday 23:59 UTC'))

   def test_crossing_midnight_without_weekday(self):
      self.assertEqual('4th Saturday of April at 16:00 UTC for 10h',
                       cst.convert_cell('4th Saturday of April at 16:00 UTC until 02:00 UTC'))

   def test_same_day(self):
      self.assertEqual('2026-11-01 at 00:00 UTC for 4h',
                       cst.convert_cell('2026-11-01 at 00:00 UTC until 04:00 UTC'))

   def test_minutes_when_not_whole_hours(self):
      self.assertEqual('every Wednesday at 02:30 UTC for 30m',
                       cst.convert_cell('every Wednesday at 02:30 UTC until 03:00 UTC'))
      self.assertEqual('every Wednesday at 02:30 UTC for 90m',
                       cst.convert_cell('every Wednesday at 02:30 UTC until 04:00 UTC'))

   def test_offset_anchor_end_on_its_own_day(self):
      self.assertEqual('2nd full weekend of April +1d at 14:00 UTC for 10h',
                       cst.convert_cell('2nd full weekend of April +1d at 14:00 UTC until 23:59 UTC'))
      # +1d moves the start to Sunday, so "until Monday" is the next day.
      self.assertEqual('2nd full weekend of June +1d at 18:00 UTC for 9h',
                       cst.convert_cell('2nd full weekend of June +1d at 18:00 UTC until Monday 02:59 UTC'))

   def test_weekday_end_same_weekday_later_time(self):
      self.assertEqual('every Saturday at 12:00 UTC for 6h',
                       cst.convert_cell('every Saturday at 12:00 UTC until Saturday 18:00 UTC'))

   def test_weekday_end_same_weekday_earlier_time_is_next_week(self):
      self.assertEqual('every Saturday at 12:00 UTC for 166h',
                       cst.convert_cell('every Saturday at 12:00 UTC until Saturday 10:00 UTC'))

   def test_iso_date_weekday_end(self):
      # 2026-11-01 is a Sunday.
      self.assertEqual('2026-11-01 at 20:00 UTC for 6h',
                       cst.convert_cell('2026-11-01 at 20:00 UTC until Monday 02:00 UTC'))

   def test_59_is_last_included_minute(self):
      self.assertEqual('every day at 00:00 UTC for 2h',
                       cst.convert_cell('every day at 00:00 UTC until 01:59 UTC'))

   def test_no_until_passes_through_unchanged(self):
      cell = '4th Saturday of April at 16:00 UTC for 10h;4th Saturday of April +1d at 12:00 UTC for 10h'
      self.assertEqual(cell, cst.convert_cell(cell))

   def test_mixed_forms_in_one_cell(self):
      self.assertEqual('4th Saturday of April at 16:00 UTC for 10h; 4th Saturday of April +1d at 12:00 UTC for 10h',
                       cst.convert_cell('4th Saturday of April at 16:00 UTC for 10h; '
                                        '4th Saturday of April +1d at 12:00 UTC until 21:59 UTC'))

   def test_errors_name_contest_and_clause(self):
      bad = [
         '4th Saturday of April at 16:00 UTC until 02:00 UTC for 10h',
         '4th Saturday of April at 16:00 UTC until 25:00 UTC',
         '4th Saturday of April at 16:00 UTC until Someday 02:00 UTC',
         '4th Saturday of April at 16:00 until 02:00 UTC',
         '07-01 at 00:00 UTC until Monday 02:00 UTC',
         'every day at 00:00 UTC until Monday 02:00 UTC',
      ]
      for cell in bad:
         with self.assertRaises(cst.ConvertError) as ctx:
            cst.convert_cell('1st Saturday of May at 00:00 UTC for 1h; ' + cell, 'TEST-ID')
         self.assertIn('TEST-ID clause 2', str(ctx.exception), cell)

   def test_csv_write_preserves_bom_crlf_and_other_rows(self):
      folder = tempfile.mkdtemp()
      try:
         path = os.path.join(folder, 'schedules.csv')
         lines = [
            'contest_id,contest_name,mode_variant,schedule,status,rules_url,rules_year,notes',
            'A,Alpha,,1st Saturday of May at 13:00 UTC for 18h,verified,,,"kept, as is"',
            'B,Beta,,1st full weekend of October at 16:00 UTC until Sunday 21:59 UTC,candidate,,,',
            '',
         ]
         cst.write_bytes(path, b'\xef\xbb\xbf' + '\r\n'.join(lines).encode('utf-8'))
         self.assertTrue(cst.process(path, True))
         raw = cst.read_bytes(path)
         self.assertTrue(raw.startswith(b'\xef\xbb\xbf'))
         out = raw[3:].decode('utf-8').split('\r\n')
         self.assertEqual(lines[0], out[0])
         self.assertEqual(lines[1], out[1])
         self.assertEqual('B,Beta,,1st full weekend of October at 16:00 UTC for 30h,candidate,,,', out[2])
         self.assertNotIn(b'\n', raw.replace(b'\r\n', b''))
      finally:
         shutil.rmtree(folder)

   def test_the_real_csv_checks_clean(self):
      self.assertTrue(cst.process(cst.DEFAULT_CSV, False))


if __name__ == '__main__':
   unittest.main()
