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
"""
import json
import re
import sys

NAME = re.compile(r'fullbuild', re.IGNORECASE)

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


def is_run(command):
   for segment in SEGMENT_SPLIT.split(command):
      if not NAME.search(segment):
         continue
      if first_word(segment) in READERS:
         continue
      return True
   return False


def main():
   try:
      data = json.load(sys.stdin)
      command = (data.get('tool_input') or {}).get('command') or ''
   except Exception:
      return 0

   if not command or not is_run(command):
      return 0

   print(json.dumps({
      'hookSpecificOutput': {
         'hookEventName': 'PreToolUse',
         'permissionDecision': 'ask',
         'permissionDecisionReason':
            'FullBuild.ps1 takes about 13 minutes and runs only when NY4I asks '
            '(pre-release / pre-push). Approve only if he asked for it.',
      }
   }))
   return 0


if __name__ == '__main__':
   sys.exit(main())
