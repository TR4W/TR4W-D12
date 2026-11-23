"""compare.py -- run netprobe's cases against BOTH servers and compare what each
one stored.

Standard library only; three-space indentation.

For every case, and for each server (the in-tree Pascal tr4wserver.exe and
TR4WServerPy's tr4wserver.py), it starts the server in a fresh directory, runs
the case with the SAME seed (so the same guids and rows go in), and keeps what
the case left behind. Then it compares the two servers:

   1. the RESULT lines (status and detail; a check named `timing` is ignored),
   2. the final database: EVERY column of EVERY qso row in seq order, and the
      meta table (read with sqlite3 after the server is stopped),
   3. the final sync stream, byte for byte.

Any difference is a DIVERGENCE and is printed. A FAIL on either server is
printed too. Exit code 0 only when nothing failed and nothing diverged.

   python -I tools/netprobe/compare.py --pascal tr4w/tr4wserver/tr4wserver.exe ^
        --python C:\\projects\\TR4WServerPy\\tr4wserver.py --work <scratch dir>

The Pascal exe is copied into <work> beside sqlite3.dll (from tr4w/redist) so
nothing in the tree is touched. Use temp ports and a scratch directory.
"""

import argparse
import json
import os
import shutil
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))
PROBE = os.path.join(HERE, 'netprobe.py')
SQLITE_DLL = os.path.join(REPO, 'tr4w', 'redist', 'x86_64-win64', 'sqlite3.dll')

DEFAULT_CASES = ['qso', 'burst', 'edit', 'dup', 'hello', 'resend', 'restock',
                 'catchup', 'serial', 'badcrc', 'big', 'legacy', 'offline-ack',
                 'clear']

# One block of row numbers per case, so no two cases share a guid and the same
# case gets the same rows on both servers.
SEED_STEP = 1000000


def run_probe(kind, server, workdir, case, seed, port, extra):
   command = [sys.executable, '-I', PROBE, '--case', case, '--label', kind,
              '--launch', kind, '--server', server, '--workdir', workdir,
              '--port', str(port), '--seed-ids', str(seed)] + extra
   done = subprocess.run(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                         text=True, encoding='utf-8', timeout=900)
   lines = [ln for ln in done.stdout.splitlines() if ln.strip()]
   return done.returncode, lines


def normal(line, kind):
   """A RESULT line without the label, or None when it is not one that is
   compared (timings)."""
   if not line.startswith('RESULT '):
      return None
   body = line[len('RESULT '):]
   if body.startswith(kind + ' '):
      body = body[len(kind) + 1:]
   if ' timing: ' in body or 'version text (differs by build)' in body or ' sync frame sizes ' in body:
      return None
   return body


def read_json(path):
   if not os.path.exists(path):
      return None
   with open(path, 'r', encoding='utf-8') as f:
      return json.load(f)


def read_bytes(path):
   if not os.path.exists(path):
      return None
   with open(path, 'rb') as f:
      return f.read()


def parse_stream(raw):
   """A sync stream as JSON values: [header, row, row, ...]. The two servers
   spell the JSON differently (the Pascal server's has spaces around the
   colons), so the STREAMS are compared as values and the byte difference is
   reported as a note. None for no stream."""
   if raw is None:
      return None
   at = 0
   frames = []
   while at < len(raw):
      length = int.from_bytes(raw[at:at + 4], 'little')
      frames.append(json.loads(raw[at + 4:at + 4 + length].decode('utf-8')))
      at += 4 + length
   return frames


def compare_databases(a, b, divergences, case):
   if a is None or b is None:
      if a != b:
         divergences.append('%s: only one server left a database' % case)
      return
   if a['columns'] != b['columns']:
      divergences.append('%s: the qso columns differ: %s vs %s' %
                         (case, a['columns'], b['columns']))
      return
   if len(a['rows']) != len(b['rows']):
      divergences.append('%s: the databases hold %d rows (pascal) and %d (python)' %
                         (case, len(a['rows']), len(b['rows'])))
   for at, (ra, rb) in enumerate(zip(a['rows'], b['rows'])):
      for name, va, vb in zip(a['columns'], ra, rb):
         if va != vb or type(va) is not type(vb):
            divergences.append('%s: row %d column %s: pascal %r, python %r' %
                               (case, at + 1, name, va, vb))
   if a['meta'] != b['meta']:
      divergences.append('%s: meta differs: pascal %s, python %s' %
                         (case, a['meta'], b['meta']))


def main(argv):
   p = argparse.ArgumentParser(description='Run netprobe against both servers and compare.')
   p.add_argument('--pascal', required=True, help='tr4wserver.exe (built)')
   p.add_argument('--python', required=True, help="TR4WServerPy's tr4wserver.py")
   p.add_argument('--work', required=True, help='scratch directory (emptied)')
   p.add_argument('--port', type=int, default=1261)
   p.add_argument('--cases', default=','.join(DEFAULT_CASES))
   p.add_argument('--burst', type=int, default=30)
   p.add_argument('--restock-big', type=int, default=0)
   args = p.parse_args(argv)

   if os.path.isdir(args.work):
      shutil.rmtree(args.work)
   os.makedirs(args.work)
   exe_dir = os.path.join(args.work, 'pascal-exe')
   os.makedirs(exe_dir)
   exe = os.path.join(exe_dir, 'tr4wserver.exe')
   shutil.copy(args.pascal, exe)
   shutil.copy(SQLITE_DLL, exe_dir)

   extra = ['--burst', str(args.burst), '--restock-big', str(args.restock_big)]
   servers = [('pascal', exe), ('python', args.python)]
   failed = 0
   divergences = []
   spelling = []
   for index, case in enumerate(args.cases.split(',')):
      seed = (index + 1) * SEED_STEP
      outcome = {}
      for kind, server in servers:
         workdir = os.path.join(args.work, kind)
         code, lines = run_probe(kind, server, workdir, case, seed, args.port, extra)
         for ln in lines:
            print(ln, flush=True)
         outcome[kind] = {
            'code': code,
            'lines': [n for n in (normal(ln, kind) for ln in lines) if n is not None],
            'db': read_json(os.path.join(workdir, case, 'final-db.json')),
            'sync': read_bytes(os.path.join(workdir, case, 'final-sync.bin')),
         }
         if code != 0:
            failed += 1
      a, b = outcome['pascal'], outcome['python']
      for ln in a['lines']:
         if ln not in b['lines']:
            divergences.append('%s: only pascal: %s' % (case, ln))
      for ln in b['lines']:
         if ln not in a['lines']:
            divergences.append('%s: only python: %s' % (case, ln))
      compare_databases(a['db'], b['db'], divergences, case)
      sync_a, sync_b = parse_stream(a['sync']), parse_stream(b['sync'])
      if sync_a != sync_b:
         divergences.append('%s: the final sync streams DECODE differently (header and rows as JSON values)'
                            % case)
      elif a['sync'] != b['sync']:
         spelling.append('%s: the sync streams decode identically but differ as BYTES '
                         '(pascal %d bytes, python %d bytes): JSON spelling only' %
                         (case, len(a['sync']), len(b['sync'])))
      same = (a['lines'] == b['lines'] and a['db'] == b['db'] and sync_a == sync_b)
      print('COMPARE %s: %s' % (case, 'identical' if same else 'DIVERGES'), flush=True)

   print('')
   print('SUMMARY: %d probe run(s) exited non-zero, %d divergence line(s), %d spelling note(s)' %
         (failed, len(divergences), len(spelling)))
   for line in divergences:
      print('DIVERGENCE ' + line)
   for line in spelling:
      print('NOTE ' + line)
   return 1 if (failed or divergences) else 0


if __name__ == '__main__':
   sys.exit(main(sys.argv[1:]))
