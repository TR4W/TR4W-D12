#!/usr/bin/env python3
r"""PreToolUse(Bash|Grep|Glob) hook: a search scoped to src\ misses the program
files.

RULE 1 IS GONE (2026-09-07), AND WHAT REPLACED IT IS STRONGER.

It used to BLOCK case-sensitive Pascal globs, because src\trdos held 25 files
with an UPPERCASE extension and `--include=*.pas` silently skipped every one --
the whole contest engine. That was not paranoia: on 2026-08-20 a search for
SaveTR4WPOSFILE with the lowercase glob returned only the declaration and the
definition, and very nearly produced the claim that TR4W never saves window
positions. It is called from logsubs2.pas, inside ExitProgram.

Those files are lowercase now, renamed for a reason the glob rule never
covered. FPC resolves a unit by trying <AsWritten>.pas, <lowercase>.pas and
<UPPERCASE>.PAS, and matches them ITSELF rather than asking the OS -- so a
mixed-case base with an uppercase extension is invisible to every uses clause
that names it, even on a case-INSENSITIVE volume. Proved on macOS and on native
Linux, and invisible to the Windows-hosted Linux cross-compile, which inherits
case-insensitive lookup from its host.

So the glob rule protects nothing any more. What stops the next uppercase file
being added is tr4w\build\Lint-UnitFileNames.ps1, which FAILS THE BUILD -- a
better guarantee than a hook that fires only when someone types a glob.

RULE 2 REMAINS, AND IS NOW THE WHOLE HOOK (warns, never blocks).

tr4w.lpr lives at tr4w\, not under src\, so `grep -rn ... src/` skips it -- and
it is where every unit is listed. A reachability question answered against src\
alone cannot see whether a unit is COMPILED AT ALL.

Not hypothetical: the 2026-08-20 proof that `unit Help` is dead rested on "it
appears in none of the 8 .lpr files". Scoped to src\, that search finds no
`uses Help` either -- the right conclusion for the wrong reason, and without
ever learning the unit is not built.

A WARNING, NOT A BLOCK, deliberately. Plenty of searches are legitimately
src-scoped, and a rule that fires on those gets routed around rather than
followed.

Exit 0 = allow, always.
"""
import sys, json, re

# Rule 2, decided on TOKENS rather than on one regex over the whole command.
#
# The regex form got it wrong in a way worth recording. `-[A-Za-z]*r\b` does not
# match `grep -rn`: the trailing \b wants a non-word character after the `r`, and
# `n` is a word character. It matched a bare `grep -r` and silently missed every
# `-rn`, `-rl`, `-ri` -- which is nearly every real search. The rule would have
# looked installed and done almost nothing.
#
# Tokens also stop the rule firing on a command that merely CONTAINS the words,
# such as a script being written about grep.
PROGRAM_FILE = re.compile(r'\.(?:dpr|lpr|lpi|dpk)\b', re.I)
SRC_TOKEN = re.compile(r'^(?:\./)?(?:tr4w[/\\])?src(?:[/\\].*)?$')
RECURSIVE_FLAG = re.compile(r'^-[A-Za-z]*r[A-Za-z]*$')

WARNING = (
   "Reminder (pascal-glob hook): this searches src\\ only. The PROGRAM files are "
   "OUTSIDE it -- tr4w/tr4w.lpr, tr4w/tr4wserver/tr4wserver.lpr, the test and "
   "bench .lpr files, tr4w/build/lintlfm/lintlfm.lpr. tr4w/tr4w.lpr is where "
   "every unit is listed, so "
   "\"who references this\" and \"is this even compiled\" are NOT answered by src\\ "
   "alone. Add tr4w/tr4w.lpr to the search if that is the question being asked."
)


def warn_src_only(cmd):
   """Rule 2: emit the reminder as injected context, and allow the command."""
   if not cmd or PROGRAM_FILE.search(cmd):
      return

   toks = [t.strip('\'"') for t in cmd.split()]

   recursive = ('rg' in toks) or \
               ('grep' in toks and any(RECURSIVE_FLAG.match(t) for t in toks))
   if not recursive:
      return

   if not any(SRC_TOKEN.match(t) for t in toks):
      return
   json.dump({'hookSpecificOutput': {'hookEventName': 'PreToolUse',
                                     'additionalContext': WARNING}},
             sys.stdout)
   sys.stdout.write('\n')


try:
   data = json.load(sys.stdin)
except Exception:
   sys.exit(0)          # never break tool use on a parse hiccup

tool = data.get('tool_name') or ''
ti = data.get('tool_input') or {}

if tool == 'Bash':
   subject = ti.get('command', '') or ''
   where = 'this command'
elif tool == 'Grep':
   subject = ti.get('glob', '') or ''
   where = "the Grep tool's `glob`"
elif tool == 'Glob':
   subject = ti.get('pattern', '') or ''
   where = "the Glob tool's `pattern`"
else:
   sys.exit(0)

if not subject:
   sys.exit(0)

# THE OPT-OUT AND THE BLOCK ARE BOTH GONE with rule 1. `glob-case-ok` is
# still accepted in a command and simply does nothing, so anything written
# while the rule existed keeps working.
warn_src_only(subject if tool == 'Bash' else '')
sys.exit(0)
