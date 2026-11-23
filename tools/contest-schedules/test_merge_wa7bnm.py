#!/usr/bin/env python3
r"""Tests for merge_wa7bnm.py, on invented data (no WA7BNM content is stored here).

   python -I tools/contest-schedules/test_merge_wa7bnm.py
"""
import json
import os
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import merge_wa7bnm


def event(cid, name, start, finish):
   return {'source': 'test', 'sourceurl': 'test', 'contestid': cid, 'contestname': name,
           'dates': [{'start': start, 'finish': finish}]}


def write_day(folder, day, items):
   path = os.path.join(folder, day + '.json')
   with open(path, 'w', encoding='utf-8-sig') as f:   # the feed's files carry a BOM
      json.dump(items, f)
   return path


class MergeTests(unittest.TestCase):

   def test_overlapping_days_keep_each_event_once(self):
      with tempfile.TemporaryDirectory() as d:
         a = write_day(d, '20260101', [event(1, 'Alpha', '2026-01-02T00:00:00', '2026-01-02T01:00:00'),
                                       event(2, 'Beta', '2026-01-03T00:00:00', '2026-01-03T02:00:00')])
         b = write_day(d, '20260102', [event(2, 'Beta', '2026-01-03T00:00:00', '2026-01-03T02:00:00'),
                                       event(3, 'Gamma', '2026-01-08T00:00:00', '2026-01-08T01:00:00')])
         contests, report = merge_wa7bnm.merge([a, b])
      self.assertEqual(sorted(contests), ['1', '2', '3'])
      self.assertEqual(report['new'], 3)
      self.assertEqual(report['unchanged'], 1)
      beta = contests['2']['events'][0]
      self.assertEqual((beta['first_seen'], beta['last_seen']), ('20260101', '20260102'))

   def test_a_contest_with_several_sessions_is_one_contest(self):
      with tempfile.TemporaryDirectory() as d:
         a = write_day(d, '20260101', [event(5, 'Weekly', '2026-01-02T03:00:00', '2026-01-02T04:00:00'),
                                       event(5, 'Weekly', '2026-01-02T07:00:00', '2026-01-02T08:00:00')])
         contests, _ = merge_wa7bnm.merge([a])
      self.assertEqual(len(contests['5']['events']), 2)

   def test_the_later_file_wins_when_the_finish_changes(self):
      with tempfile.TemporaryDirectory() as d:
         a = write_day(d, '20260101', [event(1, 'Alpha', '2026-01-02T00:00:00', '2026-01-02T01:00:00')])
         b = write_day(d, '20260102', [event(1, 'Alpha', '2026-01-02T00:00:00', '2026-01-02T02:00:00')])
         contests, report = merge_wa7bnm.merge([b, a])      # order of the list must not matter
      self.assertEqual(contests['1']['events'][0]['finish'], '2026-01-02T02:00:00')
      self.assertEqual(report['changed'], 1)

   def test_running_over_the_same_files_again_changes_nothing(self):
      with tempfile.TemporaryDirectory() as d:
         a = write_day(d, '20260101', [event(1, 'Alpha', '2026-01-02T00:00:00', '2026-01-02T01:00:00')])
         b = write_day(d, '20260102', [event(1, 'Alpha', '2026-01-02T00:00:00', '2026-01-02T02:00:00')])
         first, _ = merge_wa7bnm.merge([a, b])
         second, report = merge_wa7bnm.merge([a, b], {'contests': first})
      self.assertEqual(second['1']['events'][0]['finish'], '2026-01-02T02:00:00')
      self.assertEqual(report['changed'], 0)
      self.assertEqual(report['new'], 0)

   def test_a_second_run_merges_into_the_first(self):
      with tempfile.TemporaryDirectory() as d:
         a = write_day(d, '20260101', [event(1, 'Alpha', '2026-01-02T00:00:00', '2026-01-02T01:00:00')])
         first, _ = merge_wa7bnm.merge([a])
         b = write_day(d, '20260201', [event(1, 'Alpha', '2026-02-02T00:00:00', '2026-02-02T01:00:00')])
         second, report = merge_wa7bnm.merge([b], {'contests': first})
      self.assertEqual(len(second['1']['events']), 2)
      self.assertEqual(report['new'], 1)

   def test_a_bad_file_is_reported_not_fatal(self):
      with tempfile.TemporaryDirectory() as d:
         bad = os.path.join(d, '20260101.json')
         with open(bad, 'w', encoding='utf-8') as f:
            f.write('{"not": "a list"}')
         good = write_day(d, '20260102', [event(1, 'Alpha', '2026-01-02T00:00:00', '2026-01-02T01:00:00')])
         contests, report = merge_wa7bnm.merge([bad, good])
      self.assertEqual(len(report['bad']), 1)
      self.assertIn('1', contests)


if __name__ == '__main__':
   unittest.main()
