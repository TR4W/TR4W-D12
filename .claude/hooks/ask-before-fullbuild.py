#!/usr/bin/env python3
r"""PreToolUse(Bash|PowerShell) hook: ASK the user before FullBuild.ps1 runs.

WHY THIS EXISTS. NY4I, 2026-11-18: FullBuild.ps1 takes about 13 minutes, so it is
a pre-release / pre-push gate that HE requests (end of a session, often before a
push) and not something an agent starts on its own initiative. CLAUDE.md states
the rule; this hook is the harder lock. It does not forbid the run -- it makes
the harness stop and put the question to the user, so "run the full build" from
NY4I still works, with one approval.

WHAT COUNTS AS RUNNING IT. A command segment (split on ; && || | and newlines)
that names FullBuild -- the .ps1 or its .cmd twin -- is a RUN unless the segment
starts with a program that only READS: rg, grep, cat, git, sed, fd, ls, head,
tail, wc, file, Get-Content, Select-String, Test-Path, Get-Item and the like. So
`rg -n x tr4w/FullBuild.ps1` and `git add tr4w/FullBuild.ps1` pass without a
prompt, and `.\tr4w\FullBuild.ps1 -BuildInstaller`, `powershell -File
FullBuild.ps1` and `cd tr4w && .\FullBuild.ps1` each ask.

A bias, stated: it errs toward asking. A false prompt costs one keystroke; a
missed one costs 13 minutes. Anything the hook cannot read as JSON passes
through (the other hooks fail closed; this one is a convenience guard, and a
broken one must not wedge every shell command).

Not covered, on purpose: a script that itself calls FullBuild. Nothing here does.

THE SECOND GATE GROUP -- TESTS, LINTS, CORPUS (NY4I, 2026-11-22). "We have wasted
days with needless builds": one session ran about 35 full app builds and about 60
unit-suite builds, because the agent briefs listed the gates as each agent's own
work and the coordinator then re-ran them. A rule in memory was broken twice, so
it is a hook now. COMPILING THE PRODUCT IS FREE (Build-App, Build-App
-Incremental, Build-Server): an agent must be able to find its own compile
error. EVERYTHING THAT RUNS OR REBUILDS A CHECK ASKS:

   Build-Tests (any form: it clears and rebuilds the whole suite every time),
   the unit-test exe itself, Build-Bench, Run-Lints (the whole set; a single
   Lint-*.ps1 stays free), the corpus, the contest matrix, the ADIF round
   trip and the ADIF validator.

The marker `.claude/gates-preapproved` (untracked, local to a clone) pre-approves
this group for an unattended run, as `fullbuild-preapproved` does for FullBuild.
"""
import json
import os
import re
import sys

FULLBUILD_REASON = ('FullBuild.ps1 takes about 13 minutes and runs only when NY4I asks '
                    '(pre-release / pre-push). Approve only if he asked for it.')
GATES_REASON = ('A TEST, LINT OR CORPUS RUN: each rebuilds or runs a whole check and the '
                'suite alone is a full rebuild every time. NY4I, 2026-11-22: run these '
                'once per batch, only when asked. Compiling the product (Build-App, '
                'Build-Server) does not need approval. Approve only if he asked for this run.')

# (pattern, reason, marker file) -- the first gate whose pattern a run segment names.
GATES = [
   (re.compile(r'fullbuild', re.IGNORECASE), FULLBUILD_REASON, 'fullbuild-preapproved'),
   (re.compile(r'build-tests|tr4w_unit_tests|build-bench|run-lints|export-d12-corpus|'
               r'run-contest-matrix|freeze-contest-matrix|freeze-rescore-baseline|'
               r'test-adif-roundtrip|validate-adif-outputs', re.IGNORECASE),
    GATES_REASON, 'gates-preapproved'),
]

# Programs that read a file or run git bookkeeping; naming FullBuild after one of
# these is not a run.
READERS = {
   'rg', 'grep', 'egrep', 'fgrep', 'cat', 'git', 'sed', 'sd', 'fd', 'ls', 'dir',
   'head', 'tail', 'wc', 'file', 'stat', 'diff', 'less', 'more', 'type', 'echo',
   'get-content', 'select-string', 'test-path', 'get-item', 'get-childitem',
   'get-command', 'resolve-path', 'gc', 'sls', 'gci', 'ni', 'cp', 'copy', 'mv',
   'move', 'rm', 'del', 'touch', 'chmod', 'cmp', 'sha256sum', 'md5sum',
}

SEGMENT_SPLIT = re.compile(r'&&|\|\||[;|\n]')

# Leading noise that is not the program: call operator, dot-source, env prefixes.
PREFIX = re.compile(r'^\s*(?:[&.]\s+)?(?:\w+=\S*\s+)*')


def first_word(segment):
   seg = PREFIX.sub('', segment, count=1).strip()
   if not seg:
      return ''
   word = seg.split(None, 1)[0].strip('"\'')
   # a path to a program: keep only the leaf name, without .exe
   word = re.split(r'[\\/]', word)[-1].lower()
   if word.endswith('.exe'):
      word = word[:-4]
   return word


def gate_for(command):
   """The (reason, marker) of the first gate this command RUNS, or None."""
   for segment in SEGMENT_SPLIT.split(command):
      if first_word(segment) in READERS:
         continue
      for pattern, reason, marker in GATES:
         if pattern.search(segment):
            return reason, marker
   return None


def main():
   try:
      data = json.load(sys.stdin)
      command = (data.get('tool_input') or {}).get('command') or ''
   except Exception:
      return 0

   gate = gate_for(command) if command else None
   if gate is None:
      return 0
   reason, marker_name = gate

   # NY4I, 2026-11-20: an unattended session sat on this prompt. He creates the
   # marker (untracked, local to his clone) to pre-approve the group, and deletes
   # it to restore the prompt.
   # GATE_MARKER_DIR is for the test, which must not depend on whether the clone
   # happens to hold a marker right now.
   marker_dir = os.environ.get('GATE_MARKER_DIR') or os.path.join(
      os.path.dirname(os.path.abspath(__file__)), '..')
   marker = os.path.join(marker_dir, marker_name)
   if os.path.exists(marker):
      return 0

   print(json.dumps({
      'hookSpecificOutput': {
         'hookEventName': 'PreToolUse',
         'permissionDecision': 'ask',
         'permissionDecisionReason': reason,
      }
   }))
   return 0


if __name__ == '__main__':
   sys.exit(main())
