#!/usr/bin/env python3
r"""Merge the daily WA7BNM calendar files into ONE list of unique contest events.

WHY. NY4I downloads one file a day from the WA7BNM feed Bruce authorised for TR4W
(saved as YYYYMMDD.json). Each file lists the contests of the coming week, so
consecutive files overlap almost entirely. Run this about once a month over the
folder of saved files: it keeps each event ONCE, keyed by the WA7BNM contest id and
the start time, and merges into the output of the last run, so nothing is lost
when a month's files are archived.

THE FILES. A JSON list (UTF-8 with a byte-order mark). One object per occurrence:
   {"source": ..., "sourceurl": ..., "contestid": 498,
    "contestname": "CWops Test (CWT)",
    "dates": [{"start": "2026-11-12T03:00:00", "finish": "2026-11-12T04:00:00"}]}
A contest with several sessions (CWT) is several objects with the same
contestid. Times are written exactly as the feed gives them; the feed is UTC and
nothing is converted here.

THE OUTPUT (--out). JSON, by contest id:
   {"about": ..., "contests": {"498": {"name": ...,
       "events": [{"start": ..., "finish": ..., "first_seen": "20261111",
                   "last_seen": "20261122"}]}}}
   first_seen / last_seen are the file dates (from the file names), so a month's
   run says when an event first appeared and whether it is still listed.
When a later file gives a different finish for the same contest and start, the
LATER file wins (a sponsor corrected it) and the change is reported.

THE DATA STAYS OUT OF THE REPOSITORY. It is WA7BNM's calendar, authorised to
TR4W for the program's use; write --out to the NAS, not to a tracked path.

   python tools/contest-schedules/merge_wa7bnm.py <folder> --out <events.json>

Nothing is fetched. It reads files NY4I saved and writes the one output file.
"""
import argparse
import glob
import json
import os
import re
import sys

FILE_DATE = re.compile(r'(\d{8})')


def load_events(path):
   """The list of occurrence objects in one daily file."""
   with open(path, encoding='utf-8-sig') as f:
      data = json.load(f)
   if not isinstance(data, list):
      raise ValueError('%s: expected a JSON list of contests' % path)
   return data


def file_date(path):
   found = FILE_DATE.search(os.path.basename(path))
   return found.group(1) if found else os.path.basename(path)


def merge(daily_files, existing=None):
   """Merge the files (oldest first) into a contests dict. Returns (contests,
   report) where report counts what the run did."""
   contests = {}
   if existing:
      contests = existing.get('contests', {})

   report = {'files': 0, 'items': 0, 'new': 0, 'changed': 0, 'unchanged': 0,
             'renamed': [], 'bad': [], 'changes': []}

   for path in sorted(daily_files, key=file_date):
      seen_on = file_date(path)
      report['files'] += 1
      try:
         items = load_events(path)
      except (ValueError, OSError) as err:
         report['bad'].append('%s: %s' % (os.path.basename(path), err))
         continue

      for item in items:
         if not isinstance(item, dict) or 'contestid' not in item:
            report['bad'].append('%s: an item without a contestid' % os.path.basename(path))
            continue
         report['items'] += 1
         cid = str(item['contestid'])
         entry = contests.setdefault(cid, {'name': item.get('contestname', ''), 'events': []})
         name = item.get('contestname', '')
         if name and name != entry['name']:
            report['renamed'].append('%s: "%s" -> "%s" (%s)' % (cid, entry['name'], name, seen_on))
            entry['name'] = name

         for date in item.get('dates', []):
            start = date.get('start', '')
            finish = date.get('finish', '')
            if not start:
               continue
            existing_event = None
            for event in entry['events']:
               if event['start'] == start:
                  existing_event = event
                  break
            if existing_event is None:
               entry['events'].append({'start': start, 'finish': finish,
                                       'first_seen': seen_on, 'last_seen': seen_on})
               report['new'] += 1
            else:
               if existing_event['finish'] == finish:
                  report['unchanged'] += 1
               elif seen_on >= existing_event['last_seen']:
                  # A file as new as the newest seen so far: the sponsor changed it.
                  report['changes'].append('%s %s: finish %s -> %s (%s)' % (
                     cid, entry['name'], existing_event['finish'], finish, seen_on))
                  existing_event['finish'] = finish
                  report['changed'] += 1
               else:
                  # An OLDER file than what the event already carries (a second run
                  # over files it has read before): the newer value stands.
                  report['unchanged'] += 1
               if seen_on > existing_event['last_seen']:
                  existing_event['last_seen'] = seen_on
               if seen_on < existing_event['first_seen']:
                  existing_event['first_seen'] = seen_on

   for entry in contests.values():
      entry['events'].sort(key=lambda e: e['start'])
   return contests, report


def main():
   parser = argparse.ArgumentParser(description='Merge daily WA7BNM files into unique events.')
   parser.add_argument('folder', help='folder of saved YYYYMMDD.json files')
   parser.add_argument('--out', required=True, help='the merged events file (read first if it exists)')
   args = parser.parse_args()

   files = glob.glob(os.path.join(args.folder, '*.json'))
   if not files:
      print('merge_wa7bnm: no .json files in %s' % args.folder)
      return 2

   existing = None
   if os.path.exists(args.out):
      with open(args.out, encoding='utf-8') as f:
         existing = json.load(f)

   contests, report = merge(files, existing)

   out = {'about': 'Unique WA7BNM contest events merged from the saved daily files; see '
                   'tools/contest-schedules/merge_wa7bnm.py. Times as the feed gives them (UTC).',
          'contests': contests}
   with open(args.out, 'w', encoding='utf-8') as f:
      json.dump(out, f, indent=1, ensure_ascii=False, sort_keys=True)
      f.write('\n')

   total = sum(len(c['events']) for c in contests.values())
   print('files read:        %d' % report['files'])
   print('items read:        %d' % report['items'])
   print('new events:        %d' % report['new'])
   print('changed finish:    %d' % report['changed'])
   print('already known:     %d' % report['unchanged'])
   print('contests / events: %d / %d' % (len(contests), total))
   for line in report['changes']:
      print('changed:           ' + line)
   for line in report['renamed']:
      print('renamed:           ' + line)
   for line in report['bad']:
      print('PROBLEM:           ' + line)
   return 1 if report['bad'] else 0


if __name__ == '__main__':
   sys.exit(main())
