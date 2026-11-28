"""THE PER-CONTEST EXPORT TEST (issue 390).

For each case in cases.json:
   1. a NEW contest log in its own empty folder, created the way File > New
      creates one (the new-contest hand-off file),
   2. ONE contact, entered as Enter enters it (tr4w.exe <log> /ENTERQSO),
   3. a SECOND run exports Cabrillo from the log on disk,
   4. the whole QSO: line is checked, field by field and in order,
   5. and the ADIF record's STX_STRING and SRX_STRING hold the same fields.
A case marked 'refused' instead expects the entry to be refused.

THE EXPECTED FIELDS COME FROM THE SPONSOR, and each case records its source.
Never fill them in from this program's output: issue 361 shipped because every
check had been taken from it. A case with no 'source' is refused.

TR4W is started directly, with what tr4w/test/Run-Headless.ps1 gives it: run
from tr4w/target, its own --settings, --unattended and a time limit.  Not
through that script, because PowerShell splits '--new-contest-from=C:\\...'
at the colon.

   python tr4w/test/export-test/run-export-test.py [NAME ...] [--exe PATH]

Exit 0 only when every case run passed.  It fails closed: no cases, a missing
program, no Cabrillo file or no single QSO line are failures.
"""
import argparse
import io
import json
import os
import re
import shutil
import sqlite3
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(os.path.dirname(HERE)))
TARGET = os.path.join(REPO, 'tr4w', 'target')
SETTINGS = os.path.join(REPO, 'tr4w', 'test', 'contest-matrix', 'settings', 'tr4w.json')
WORK = os.path.join(REPO, 'build-out', 'export-test')
DEFAULT_EXE = os.path.join(REPO, 'build-out', 'app-x86_64-win64', 'tr4w_fpc.exe')
HANDOFF_HEADER = 'TR4W NEW CONTEST HAND-OFF 1'
TIME_LIMIT_SECONDS = 120
EXIT_ENTRY_REFUSED = 6          # VC.EXITCODE_ENTRY_REFUSED
PROGRAM_LOG = os.path.join(TARGET, 'tr4w.log')
REFUSED = 'was refused and is not set'


def new_contest_questions(exe):
   """What New Contest asks, asked of the program itself:
   {contest id: (active, asked, asked_when_the_box_is_ticked)}."""
   os.makedirs(WORK, exist_ok=True)
   out = os.path.join(WORK, 'new-contest-questions.txt')
   if os.path.isfile(out):
      os.replace(out, out + '.previous')
   code = run(exe, ['/NEWCONTESTPROMPTS', out, '--settings', SETTINGS_COPY()])
   if code != 0 or not os.path.isfile(out):
      return None
   found = {}
   for line in io.open(out, encoding='utf-8').read().splitlines():
      contest, active, _box, asked, inside = line.split('|')
      found[contest] = (active == '1',
                        {a.upper() for a in asked.split(';') if a},
                        {a.upper() for a in inside.split(';') if a})
   return found


def SETTINGS_COPY():
   """A throwaway copy: nothing may be pointed at the tracked fixture."""
   path = os.path.join(WORK, 'questions-settings.json')
   shutil.copy(SETTINGS, path)
   return path


def unasked_answers(case, questions):
   """THE REALISM SAFEGUARD.  'station' is what New Contest queues, so it may
   hold only what New Contest asks this contest.  Anything else belongs in
   'station_settings'.  An answer the dialog never asks makes the contest's
   own statement out of an everyday setting -- which hid the IARU defect."""
   if case['contest'] not in questions:
      return ['no contest %r in the program' % case['contest']]
   _active, asked, inside = questions[case['contest']]
   allowed = {'MY CALL'} | asked
   if case.get('i_am_in'):
      allowed |= inside
   return ['New Contest does not ask %r here: move it to station_settings' % key
           for key in case['station']
           if key.upper() not in allowed and not key.upper().startswith('CATEGORY-')]


def write_status(questions, results):
   """THE COVERAGE SAFEGUARD: every contest the program knows, each pass, fail
   or unverified with a reason, so what is not covered stays visible."""
   reasons = json.load(io.open(os.path.join(HERE, 'unverified.json'), encoding='utf-8'))
   rows, counts = [], {'pass': 0, 'fail': 0, 'unverified': 0}
   for contest in sorted(questions):
      outcomes = results.get(contest)
      if outcomes is None:
         state, why = 'unverified', reasons.get(contest, 'no case written yet')
      elif all(outcomes):
         state, why = 'pass', '%d case(s)' % len(outcomes)
      else:
         state, why = 'fail', '%d of %d case(s) failed' % (outcomes.count(False), len(outcomes))
      counts[state] += 1
      active = '' if questions[contest][0] else ' (inactive)'
      rows.append('| %s%s | %s | %s |' % (contest, active, state, why))
   path = os.path.join(WORK, 'status.md')
   text = ('# Export test status\n\n%d contests: %d pass, %d fail, %d unverified.\n\n'
           '| contest | status | detail |\n|---|---|---|\n' %
           (len(rows), counts['pass'], counts['fail'], counts['unverified']))
   io.open(path, 'w', encoding='utf-8').write(text + '\n'.join(rows) + '\n')
   print('=== all contests: %d pass, %d fail, %d unverified of %d -- %s ===' %
         (counts['pass'], counts['fail'], counts['unverified'], len(rows), path))


def write_handoff(path, case):
   """The station first and CONTEST last: setting CONTEST builds the contest
   from the values before it."""
   lines = [HANDOFF_HEADER, case['station']['MY CALL']]
   lines += ['%s=%s' % item for item in case['station'].items()]
   lines.append('CONTEST=' + case['contest'])
   io.open(path, 'w', encoding='utf-8', newline='\r\n').write('\n'.join(lines) + '\n')


def write_settings(path, case):
   """The run's own settings: the tracked fixture, plus the case's station
   settings -- what Preferences > Station holds on a real station, as opposed
   to what New Contest asks for one contest."""
   data = json.load(io.open(SETTINGS, encoding='utf-8'))
   if case.get('station_settings'):
      data.setdefault('settings', {})['My'] = dict(case['station_settings'])
   io.open(path, 'w', encoding='utf-8').write(json.dumps(data, indent=2))


def run(exe, arguments):
   try:
      done = subprocess.run([exe] + arguments + ['--unattended'], cwd=TARGET,
                            timeout=TIME_LIMIT_SECONDS)
   except subprocess.TimeoutExpired:
      return 'timed out after %d s' % TIME_LIMIT_SECONDS
   return done.returncode


def log_size():
   return os.path.getsize(PROGRAM_LOG) if os.path.isfile(PROGRAM_LOG) else 0


def refused_settings(start):
   """The settings this run's own lines of tr4w.log say were refused.  TR4W
   only warns, and a refused value leaves the line being checked built from
   something else.  The log is shared and appended to; it is only read."""
   size = log_size()
   if size == 0:
      return None
   with io.open(PROGRAM_LOG, 'rb') as log:
      log.seek(start if start <= size else 0)      # it rolled over
      text = log.read().decode('utf-8', 'replace')
   return [line.split('[NewContest] ', 1)[1].strip()
           for line in text.splitlines() if REFUSED in line and '[NewContest] ' in line]


def logged_contest(log):
   """The contest the new log says it is."""
   db = sqlite3.connect(log)
   try:
      row = db.execute('SELECT contest_type FROM contest WHERE id = 1').fetchone()
   finally:
      db.close()
   return row[0] if row else None


def qso_lines(folder):
   found = []
   for name in sorted(os.listdir(folder)):
      path = os.path.join(folder, name)
      if not os.path.isfile(path) or name.lower().endswith(('.db', '.json', '.txt', '-wal', '-shm')):
         continue
      text = io.open(path, 'rb').read().decode('utf-8', 'replace')
      if text.startswith('START-OF-LOG'):
         found += [line.rstrip() for line in text.splitlines() if line.startswith('QSO:')]
   return found


def same_form(token):
   return str(int(token)) if token.isdigit() else token


def expected_lines(case):
   """One QSO line from 'sent' and 'received', or one per entry of 'lines' (a
   county line is one typed contact and a line for each county)."""
   if 'lines' in case:
      return case['lines']
   return [{'sent': case['sent'], 'received': case['received']}]


def line_fields(line):
   return [same_form(t) for t in line.split()[5:]]


def check_lines(found, case):
   """Every expected QSO line, field by field and in order within the line:
   QSO: freq mode date time mycall <sent...> call <received...>.  The
   frequency, mode, date and time are the run's own and are not checked.
   The lines themselves may come in either order.
   A field that is all digits on both sides is compared as a number: sponsors'
   samples write serial 1 where a logger writes 001.  A report stays exact in
   effect (59 and 599 are different numbers)."""
   wanted = []
   for line in expected_lines(case):
      wanted.append([case['station']['MY CALL']] + line['sent'] +
                    [case['worked']] + line['received'])
   if sorted([same_form(t) for t in w] for w in wanted) == sorted(line_fields(l) for l in found):
      return []
   return (['expected: ' + ' '.join(w) for w in wanted] +
           ['got:      ' + ' '.join(l.split()[5:]) for l in found] +
           ['line:     ' + l for l in found])


def adif_records(folder):
   found = []
   for name in sorted(os.listdir(folder)):
      if name.lower().endswith('.adi'):
         text = io.open(os.path.join(folder, name), 'rb').read().decode('utf-8', 'replace')
         body = re.split(r'(?i)<EOH>', text)[-1]
         for record in re.split(r'(?i)<EOR>', body):
            fields = {}
            for tag in re.finditer(r'<([A-Za-z0-9_]+):(\d+)(?::\w)?>', record):
               fields[tag.group(1).upper()] = record[tag.end():tag.end() + int(tag.group(2))]
            if 'CALL' in fields:
               found.append(fields)
   return found


def check_adif(folder, case):
   """THE ADIF SIDE.  A sponsor defines Cabrillo, not ADIF, so the expected
   ADIF is DERIVED FROM THE CASE'S OWN sponsor-sourced fields: STX_STRING is
   the sent fields and SRX_STRING the received ones.  Where ADIF rightly
   differs, the case says so under 'adif' -- 'sent', 'received' or 'records',
   with 'why'.  A county line is one typed contact in ADIF, so its received
   fields (one set per Cabrillo line) are not compared."""
   told = case.get('adif', {})
   if told and not told.get('why', '').strip():
      return ["the case's 'adif' gives no 'why'"]
   records = adif_records(folder)
   wanted_records = told.get('records', 1)
   if len(records) != wanted_records:
      return ['ADIF: expected %d record(s), found %d (folder %s)'
              % (wanted_records, len(records), folder)]
   lines = expected_lines(case)
   checks = [('STX_STRING', told.get('sent', lines[0]['sent']))]
   if len(lines) == 1:
      checks.append(('SRX_STRING', told.get('received', lines[0]['received'])))
   problems = []
   for tag, fields in checks:
      for record in records:
         got = record.get(tag, '').split()
         if [same_form(t) for t in got] != [same_form(t) for t in fields]:
            problems.append('ADIF %s: expected %r, got %r'
                            % (tag, ' '.join(fields), ' '.join(got)))
   return problems


def run_case(exe, case):
   if not case.get('source', '').strip():
      return ['the case records no source for its expected fields']
   os.makedirs(WORK, exist_ok=True)
   folder = os.path.join(WORK, case['name'])
   number = 0
   while os.path.exists(folder):      # a new folder each run; nothing is deleted
      number += 1
      folder = os.path.join(WORK, '%s.%d' % (case['name'], number))
   os.makedirs(folder)

   handoff = os.path.join(folder, 'handoff.txt')
   settings = os.path.join(folder, 'tr4w.json')
   log = os.path.join(folder, case['name'] + '.db')
   write_handoff(handoff, case)
   write_settings(settings, case)

   start = log_size()
   code = run(exe, [log, '/ENTERQSO', case['worked'], case['typed'],
                    case['band'], case['mode'], '--settings', settings, '--new-contest-from=' + handoff])
   refused = refused_settings(start)
   if refused is None:
      return ['no %s, so a refused setting could not be seen' % PROGRAM_LOG]
   if refused:
      return ['a setting was refused: ' + line for line in refused]
   if case.get('refused'):
      if code != EXIT_ENTRY_REFUSED:
         return ['expected the entry to be refused (exit %d), got exit %s (folder %s)'
                 % (EXIT_ENTRY_REFUSED, code, folder)]
      with io.open(PROGRAM_LOG, 'rb') as program_log:
         program_log.seek(start if start <= log_size() else 0)
         said = program_log.read().decode('utf-8', 'replace')
      if case['refused'] not in said:
         return ['refused, but not with %r (folder %s)' % (case['refused'], folder)]
      return []
   if code != 0:
      return ['entering the contact: exit %s (folder %s)' % (code, folder)]
   recorded = logged_contest(log)
   if recorded != case['contest']:
      return ['the new log records contest %r, not %r (folder %s)'
              % (recorded, case['contest'], folder)]
   code = run(exe, [log, '/EXPORT', '--settings', settings])
   if code != 0:
      return ['export: exit %s (folder %s)' % (code, folder)]

   lines = qso_lines(folder)
   if len(lines) != len(expected_lines(case)):
      return (['expected %d Cabrillo QSO line(s), found %d (folder %s)'
               % (len(expected_lines(case)), len(lines), folder)] +
              ['line:     ' + line for line in lines])
   return check_lines(lines, case) + check_adif(folder, case)


def main():
   parser = argparse.ArgumentParser()
   parser.add_argument('names', nargs='*')
   parser.add_argument('--exe', default=DEFAULT_EXE)
   options = parser.parse_args()

   if not os.path.isfile(options.exe):
      print('export-test: no program at %s -- build it first' % options.exe)
      return 1
   # the program is run from tr4w/target, beside its DLLs and data files
   exe = os.path.join(TARGET, 'tr4w.exe')
   shutil.copy(options.exe, exe)

   questions = new_contest_questions(exe)
   if not questions:
      print('export-test: the program did not list what New Contest asks')
      return 1

   cases = json.load(io.open(os.path.join(HERE, 'cases.json'), encoding='utf-8'))
   if options.names:
      cases = [c for c in cases if c['name'] in options.names]
   if not cases:
      print('export-test: no cases to run')
      return 1

   failed = 0
   results = {}
   for case in cases:
      problems = unasked_answers(case, questions) or run_case(exe, case)
      results.setdefault(case['contest'], []).append(not problems)
      print('%s  %s' % ('FAIL' if problems else 'PASS', case['name']))
      for problem in problems:
         print('      ' + problem)
      failed += 1 if problems else 0
   print('=== export test: %d passed, %d failed ===' % (len(cases) - failed, failed))
   if not options.names:          # a partial run must not report coverage
      write_status(questions, results)
   return 1 if failed else 0


if __name__ == '__main__':
   sys.exit(main())
