#!/usr/bin/env python3
r"""PreToolUse(Bash|Grep|Glob) hook: two ways a source search silently lies here.

RULE 1 -- CASE-SENSITIVE PASCAL GLOBS (blocks).

src\trdos uses UPPERCASE extensions -- LOGSTUFF.PAS, LOGSUBS2.PAS, LOGRADIO.PAS
and 24 more. Measured in tr4w\src on 2026-08-20:

    grep --include='*.pas'   ->  7 files in src\trdos
    grep --include='*.PAS'   -> 25 files in src\trdos
    find  -name  '*.pas'     ->  7        -iname '*.pas' -> 32

So the lowercase glob SILENTLY SKIPS THE ENTIRE CONTEST ENGINE. It is not a
Windows filesystem question -- the filesystem is case-insensitive, but grep,
ripgrep, find -name, the shell's own globbing AND the Grep tool's `glob` all
match the NAME case-sensitively. All four were measured.

THAT IS HOW A FALSE "DEAD CODE" VERDICT GETS MADE. On 2026-08-20 a search for
SaveTR4WPOSFILE with --include=*.pas returned only the declaration and the
definition, and very nearly produced the claim that TR4W never saves window
positions. It is called from LOGSUBS2.PAS:728, inside ExitProgram, exactly as in
D7. Nothing about the wrong answer looked wrong.

Use instead:

    grep -rni --include='*.[pP][aA][sS]' Symbol src/
    find src -iname '*.pas'
    Grep tool:  glob = "*.[pP][aA][sS]"

or drop the glob and filter afterwards. This is the FILE NAME half of the
problem; CLAUDE.md's separate rule about `grep -i` for Pascal IDENTIFIERS still
applies, because this codebase spells the same identifier three ways.

ESCAPE HATCH: put `glob-case-ok` in a Bash command. Say why.

RULE 2 -- SEARCHING src\ AND FORGETTING THE PROGRAM FILES (warns only).

tr4w.lpr lives at tr4w\, not under src\, so `grep -rn ... src/` skips it -- and
it is where every unit is listed. A reachability question answered against src\
alone cannot see whether a unit is COMPILED AT ALL.

THE EXTENSION IS .lpr, NOT .dpr, SINCE 2026-08-29 (adaa30dd, "the program files
are .lpr -- this is FPC and Lazarus, not Delphi"). There is no .dpr left in
the tree at all; all twelve program files are .lpr. This text said otherwise
until 2026-08-31, so the hook was telling every reader to search a file that
does not exist -- on a search that was already missing the real one. dpr stays
in the patterns below because matching an extension that occurs nowhere costs
nothing, and a returning .dpr should still be recognised as a program file.

Also not hypothetical: the 2026-08-20 proof that `unit Help` is dead rested on
"it appears in none of the 8 .dpr/.lpr files". Scoped to src\, that search finds
no `uses Help` either -- the right conclusion for the wrong reason, and without
ever learning the unit is not built.

A WARNING, NOT A BLOCK, deliberately. Plenty of searches are legitimately
src-scoped, and a rule that fires on those gets routed around rather than
followed.

Exit 0 = allow. Exit 2 = block; stderr comes back to the agent as feedback.
"""
import sys, json, re

# Only .pas actually varies today (334 lowercase, 27 uppercase, all in
# src\trdos). .dpr/.inc/.dpk/.lpr are uniformly lowercase in both this tree and
# the D7 tree at C:\TR4W -- but they are listed anyway, because the count is a
# snapshot and the failure mode is silent. A rule that only fires on today's
# known-bad case teaches nothing about tomorrow's.
PASCAL_EXT = ('pas', 'dpr', 'inc', 'dpk', 'lpr', 'lfm', 'dfm')

# `*.pas` / `*.PAS` / `*.Pas` -- a star, a dot, then letters and nothing else.
# The bracket form `*.[pP][aA][sS]` cannot match: `[` is not in the class.
GLOB = re.compile(r'\*\.([A-Za-z]+)\b')

CASE_INSENSITIVE_FLAG = re.compile(r'-i(?:name|regex|path)\s*$')

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


def offenders(text):
   """Every case-sensitive Pascal glob in `text`, as written."""
   out = []
   for m in GLOB.finditer(text):
      if m.group(1).lower() not in PASCAL_EXT:
         continue
      # `find -iname '*.pas'` is already correct -- do not flag it. Look back a
      # short way for the flag, tolerating the quote between them.
      before = text[max(0, m.start() - 24):m.start()]
      before = before.rstrip().rstrip('\'"').rstrip()
      if CASE_INSENSITIVE_FLAG.search(before):
         continue
      out.append(m.group(0))
   return out


def suggest(tok):
   ext = tok.split('.', 1)[1]
   return '*.' + ''.join('[%s%s]' % (c.lower(), c.upper()) for c in ext)


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

# Deliberate opt-out, Bash only -- the tool calls have nowhere to put a comment.
if tool == 'Bash' and 'glob-case-ok' in subject:
   sys.exit(0)

bad = offenders(subject)
if not bad:
   warn_src_only(subject if tool == 'Bash' else '')
   sys.exit(0)

seen = []
for b in bad:
   if b not in seen:
      seen.append(b)

sys.stderr.write(
   'BLOCKED by .claude/hooks/enforce-pascal-glob.py (pascal-glob-case).\n'
   'A case-sensitive Pascal glob in %s SILENTLY SKIPS src\\trdos, which uses\n'
   'UPPERCASE extensions -- 27 .PAS files including LOGSTUFF, LOGSUBS2 and\n'
   'LOGRADIO. Measured: --include=*.pas finds 7 files there, *.PAS finds 25.\n'
   'This is how a false "no callers / dead code" answer gets made.\n\n'
   'Rewrite:\n' % where)

for b in seen:
   sys.stderr.write("  %-10s ->  %s\n" % (b, suggest(b)))

sys.stderr.write(
   '\nOr use `find -iname`, or drop the glob and filter afterwards.\n'
   'If lowercase-only is genuinely what you want, put `glob-case-ok` in the\n'
   'Bash command and say why.\n')
sys.exit(2)
