#!/usr/bin/env python3
r"""Tests for ask-before-fullbuild.py.

Runs the REAL hook as a subprocess with the PreToolUse JSON on its standard
input, which is always a FILE so the test cannot hang. None of the commands is
ever run; they are only text handed to the hook.

   python .claude/hooks/test-ask-before-fullbuild.py

Exit 0 when every case behaves, 1 otherwise. Fails closed: also fails if a table
holds fewer cases than its floor, so an emptied list cannot pass.
"""
import json
import os
import subprocess
import sys
import tempfile

HOOK = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'ask-before-fullbuild.py')

# Commands that must make the hook ASK.
ASKS = [
   r".\tr4w\FullBuild.ps1",
   r".\tr4w\FullBuild.ps1 -BuildInstaller",
   r"& .\tr4w\FullBuild.ps1 -SkipServer",
   r"powershell -NoProfile -ExecutionPolicy Bypass -File tr4w\FullBuild.ps1",
   r"cd tr4w && .\FullBuild.ps1",
   r"cd /c/tr4w-d12/tr4w; powershell.exe -File FullBuild.ps1",
   r"tr4w\FullBuild.cmd",
   r"pwsh -File C:\tr4w-d12\tr4w\fullbuild.ps1",
   "git status\n.\\tr4w\\FullBuild.ps1",
]

# Commands that merely READ or name it, and must pass without a prompt.
PASSES = [
   r"rg -n Python tr4w/FullBuild.ps1",
   r"git add tr4w/FullBuild.ps1",
   r"git diff tr4w/FullBuild.ps1",
   r"cat tr4w/FullBuild.ps1",
   r"sed -n 100,135p tr4w/FullBuild.ps1",
   r"Get-Content tr4w\FullBuild.ps1 -TotalCount 40",
   r"Select-String -Path tr4w\FullBuild.ps1 -Pattern python",
   r"wc -l tr4w/FullBuild.ps1 | cat",
   r".\tr4w\build\Build-App.ps1 -Incremental",
   r".\tr4w\build\Build-App.ps1",
   r"cd C:\tr4w-d12\tr4w; .\build\Build-App.ps1 2>&1 | Select-String 'BUILD'",
   r".\tr4w\build\Build-Server.ps1",
   r"powershell -File tr4w\build\Lint-LineEndings.ps1 -SourceDir tr4w -Fix",
   r"rg -n Run-Lints tr4w/build/FullBuild.ps1",
   r"git add tr4w/build/Build-Tests.ps1 tr4w/test/corpus/export-d12-corpus.sh",
   r"cat tr4w/build/Run-Lints.ps1",
   r"git commit -m 'Run-Lints and Build-Tests ceilings lowered'",
   r"ls tr4w",
]

# The second group (2026-11-22): tests, lints, corpus. Compiling the product is
# free (see PASSES); each of these asks.
ASKS += [
   r".\tr4w\build\Build-Tests.ps1",
   r".\tr4w\build\Build-Tests.ps1 -Run",
   r".\tr4w\build\Build-Tests.ps1 -Checked -Run",
   r"cd C:\tr4w-d12\tr4w; .\build\Build-Tests.ps1 -Run 2>&1 | Select-String PASSED",
   r"powershell -File tr4w\build\Run-Lints.ps1",
   r"tr4w\build\Run-Lints.cmd",
   r"powershell -File tr4w\build\Build-Bench.ps1",
   r"tr4w\test\unit\tr4w_unit_tests_fpc.exe",
   r".\tr4w_unit_tests_fpc.exe | Select-String FAIL",
   r"bash tr4w/test/corpus/export-d12-corpus.sh",
   r"bash tr4w/test/contest-matrix/run-contest-matrix.sh",
   r"sh tr4w/test/corpus/test-adif-roundtrip.sh",
   r"bash tr4w/test/adif-validate/validate-adif-outputs.sh",
   r"bash tr4w/test/corpus/freeze-rescore-baseline.sh",
]

ASK_FLOOR = 20
PASS_FLOOR = 18


EMPTY_MARKER_DIR = tempfile.mkdtemp(prefix='gate-markers-')


def hook_env():
   """The hook's environment with the marker directory pointed at an EMPTY one,
   so the result does not depend on a pre-approval marker in this clone."""
   env = dict(os.environ)
   env['GATE_MARKER_DIR'] = EMPTY_MARKER_DIR
   return env


def run_hook(command):
   payload = {'tool_name': 'Bash', 'tool_input': {'command': command}}
   with tempfile.NamedTemporaryFile('w', suffix='.json', delete=False) as f:
      json.dump(payload, f)
      path = f.name
   try:
      with open(path, 'rb') as stdin:
         result = subprocess.run([sys.executable, HOOK], stdin=stdin,
                                 capture_output=True, timeout=15, env=hook_env())
   finally:
      os.unlink(path)
   out = result.stdout.decode('utf-8', 'replace').strip()
   asked = False
   if out:
      asked = json.loads(out)['hookSpecificOutput']['permissionDecision'] == 'ask'
   return result.returncode, asked


def main():
   failures = []

   if len(ASKS) < ASK_FLOOR or len(PASSES) < PASS_FLOOR:
      failures.append('a case table is below its floor -- it was emptied')

   for cmd in ASKS:
      code, asked = run_hook(cmd)
      if code != 0 or not asked:
         failures.append('SHOULD ASK, did not: %r' % cmd)

   for cmd in PASSES:
      code, asked = run_hook(cmd)
      if code != 0 or asked:
         failures.append('SHOULD PASS, asked: %r' % cmd)

   # Garbage on stdin must not wedge the shell: exit 0, no decision.
   with tempfile.NamedTemporaryFile('w', suffix='.json', delete=False) as f:
      f.write('not json')
      path = f.name
   try:
      with open(path, 'rb') as stdin:
         result = subprocess.run([sys.executable, HOOK], stdin=stdin,
                                 capture_output=True, timeout=15)
      if result.returncode != 0 or result.stdout.strip():
         failures.append('malformed input should pass silently')
   finally:
      os.unlink(path)

   for line in failures:
      print('FAIL: ' + line)
   print('%d ask cases, %d pass cases, %d failure(s)' % (len(ASKS), len(PASSES), len(failures)))
   return 1 if failures else 0


if __name__ == '__main__':
   sys.exit(main())
