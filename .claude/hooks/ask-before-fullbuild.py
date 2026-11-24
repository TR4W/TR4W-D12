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

THE SECOND GATE -- THE CONTEST MATRIX ONLY (NY4I, 2026-11-24). It began on
2026-11-22 as a whole group -- tests, lints, corpus, matrix, ADIF checks -- after
"we have wasted days with needless builds" (one session ran about 35 full app
builds and 60 unit-suite builds). Measured on 2026-11-24, the unit suite is
about 4 minutes, the lints 2, the corpus under 1, and the contest matrix about
17: only the matrix is long enough to be worth a prompt. NY4I: "let's keep this
simple now ... put the command hook on only running the 17 minute test ... I
would be fine letting the ci-runner do it." So run-contest-matrix.sh and
freeze-contest-matrix.sh ask; Build-Tests, the unit-test exe, Build-Bench,
Run-Lints, the corpus, the ADIF round trip and the ADIF validator are FREE, as
Build-App and Build-Server always were. (Run them once per batch all the same:
they are cheap, not free of cost.)

The marker `.claude/gates-preapproved` (untracked, local to a clone) pre-approves
the matrix for an unattended run, as `fullbuild-preapproved` does for FullBuild.
"""
import json
import os
import re
import sys

FULLBUILD_REASON = ('FullBuild.ps1 takes about 13 minutes and runs only when NY4I asks '
                    '(pre-release / pre-push). Approve only if he asked for it.')
GATES_REASON = ('THE CONTEST MATRIX takes about 17 minutes (213 contests, one process each). '
                'NY4I, 2026-11-24: it is not run here for now; the CI runner is the place '
                'for it. Approve only if he asked for this run.')

# (pattern, reason, marker file) -- the first gate whose pattern a run segment names.
GATES = [
   (re.compile(r'fullbuild', re.IGNORECASE), FULLBUILD_REASON, 'fullbuild-preapproved'),
   (re.compile(r'run-contest-matrix|freeze-contest-matrix', re.IGNORECASE),
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
