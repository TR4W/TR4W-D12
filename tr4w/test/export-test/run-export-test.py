"""THE PER-CONTEST EXPORT TEST (issue 390).

For each case in cases.json:
   1. a NEW contest log in its own empty folder, created the way File > New
      creates one (the new-contest hand-off file),
   2. ONE contact, entered as Enter enters it (tr4w.exe <log> /ENTERQSO),
   3. a SECOND run exports Cabrillo from the log on disk,
   4. the whole QSO: line is checked, field by field and in order.

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
PROGRAM_LOG = os.path.join(TARGET, 'tr4w.log')
REFUSED = 'was refused and is not set'


def write_handoff(path, case):
   """The station first and CONTEST last: setting CONTEST builds the contest
   from the values before it."""
   lines = [HANDOFF_HEADER, case['station']['MY CALL']]
   lines += ['%s=%s' % item for item in case['station'].items()]
   lines.append('CONTEST=' + case['contest'])
   io.open(path, 'w', encoding='utf-8', newline='\r\n').write('\n'.join(lines) + '\n')


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


def check_line(line, case):
   """QSO: freq mode date time mycall <sent...> call <received...>.  The
   frequency, mode, date and time are the run's own and are not checked."""
   tokens = line.split()
   expected = ([case['station']['MY CALL']] + case['sent'] +
               [case['worked']] + case['received'])
   actual = tokens[5:]
   if actual != expected:
      return ['expected: ' + ' '.join(expected),
              'got:      ' + ' '.join(actual),
              'line:     ' + line]
   return []


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
   shutil.copy(SETTINGS, settings)

   start = log_size()
   code = run(exe, [log, '/ENTERQSO', case['worked'], case['typed'],
                    '--settings', settings, '--new-contest-from=' + handoff])
   refused = refused_settings(start)
   if refused is None:
      return ['no %s, so a refused setting could not be seen' % PROGRAM_LOG]
   if refused:
      return ['a setting was refused: ' + line for line in refused]
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
   if len(lines) != 1:
      return ['expected one Cabrillo QSO line, found %d (folder %s)' % (len(lines), folder)]
   return check_line(lines[0], case)


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

   cases = json.load(io.open(os.path.join(HERE, 'cases.json'), encoding='utf-8'))
   if options.names:
      cases = [c for c in cases if c['name'] in options.names]
   if not cases:
      print('export-test: no cases to run')
      return 1

   failed = 0
   for case in cases:
      problems = run_case(exe, case)
      print('%s  %s' % ('FAIL' if problems else 'PASS', case['name']))
      for problem in problems:
         print('      ' + problem)
      failed += 1 if problems else 0
   print('=== export test: %d passed, %d failed ===' % (len(cases) - failed, failed))
   return 1 if failed else 0


if __name__ == '__main__':
   sys.exit(main())
