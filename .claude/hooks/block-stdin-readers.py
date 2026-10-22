#!/usr/bin/env python3
r"""PreToolUse(Bash) hook: BLOCK a command that waits on standard input.

WHY THIS EXISTS. On 2026-10-14 an agent ran

   cd /c/tr4w-d12/tr4w && cat > /dev/null; python - <<'EOF'
   ...

as a background shell. `cat > /dev/null` has no input file, so it read the
shell's standard input -- which nothing ever writes or closes -- and waited.
The heredoc after it never ran. The shell sat there for 1 day 0 h 21 m, and
the agent that owned it could not finish until it was killed by hand. NY4I:
"That should never be allowed to happen."

A tool timeout does not catch this: a background shell has none, and a
foreground one only backgrounds itself when the limit passes, it does not kill.
So the control is to refuse the shapes that read standard input in the first
place:

1. A HEREDOC (`<<WORD`, `<<'WORD'`, `<<-WORD`). NY4I's instructions already
   forbid them ("Do not use HEREDOC as it is error prone"); this makes the rule
   real instead of remembered. A here-STRING (`<<<`) is allowed: it supplies its
   input and cannot wait.
2. `cat` with NO FILE ARGUMENT, which reads standard input: a bare `cat`, or
   `cat` followed only by a redirection or the end of a command (`cat > f`,
   `cat >> f`, `cat -`, `cat | x`, `cat; x`). `cat file`, `cat -A file` and
   `x | cat` (fed by a pipe) are allowed.

Write a file with the Write tool, edit one with the Edit tool or
tools/srcfile.py, and pass a script to Python as a file in the scratchpad.

Exit 0 always; a block is reported as a PreToolUse "deny" decision, so a parse
hiccup in this hook never breaks tool use.
"""
import sys, json, re, shlex

# A heredoc opener: `<<` not part of `<<<`, optional `-`, optional quote, then
# a word. Requiring a letter or underscore after it keeps arithmetic such as
# $((1<<2)) out.
HEREDOC = re.compile(r"(?<!<)<<(?!<)-?\s*['\"]?[A-Za-z_]")

# Where a command ends, for deciding whether `cat` was given a file.
COMMAND_END = {';', '&&', '||', '|', '&', ')'}
REDIRECTION = re.compile(r'^\d*(?:>>?|<)')


def cat_reads_stdin(cmd):
   """True when some `cat` in the command has no file operand and is not fed by a pipe."""
   try:
      lexer = shlex.shlex(cmd, posix=True, punctuation_chars=';&|()<>')
      lexer.whitespace_split = True
      toks = list(lexer)
   except ValueError:
      return False                  # unbalanced quotes: let the shell report it

   for i, tok in enumerate(toks):
      if tok != 'cat':
         continue

      # `x | cat` is fed by the pipe, so it cannot wait on the terminal.
      if i > 0 and toks[i - 1] == '|':
         continue

      # Is this the command word? A `cat` that is an argument (`echo cat`) is not.
      if i > 0 and toks[i - 1] not in COMMAND_END and toks[i - 1] not in ('then', 'do', 'else', '{'):
         continue

      has_file = False
      j = i + 1
      while j < len(toks) and toks[j] not in COMMAND_END:
         t = toks[j]
         if REDIRECTION.match(t) or t in ('>', '>>', '<'):
            j += 2                  # the redirection and its target
            continue
         if t == '-':
            break                   # `cat -` IS standard input
         if not t.startswith('-'):
            has_file = True
            break
         j += 1
      if not has_file:
         return True
   return False


def deny(reason):
   json.dump({'hookSpecificOutput': {'hookEventName': 'PreToolUse',
                                     'permissionDecision': 'deny',
                                     'permissionDecisionReason': reason}},
             sys.stdout)
   sys.stdout.write('\n')


try:
   data = json.load(sys.stdin)
except Exception:
   sys.exit(0)

if (data.get('tool_name') or '') != 'Bash':
   sys.exit(0)

cmd = (data.get('tool_input') or {}).get('command', '') or ''
if not cmd:
   sys.exit(0)

if HEREDOC.search(cmd):
   deny("BLOCKED (block-stdin-readers hook): this command uses a heredoc. "
        "Heredocs are forbidden here -- a 2026-10-14 shell waited on standard "
        "input for over a day. Write the content with the Write tool (into the "
        "scratchpad if it is temporary) and pass the FILE to the command instead.")
elif cat_reads_stdin(cmd):
   deny("BLOCKED (block-stdin-readers hook): `cat` has no input file here, so it "
        "reads standard input and waits for ever -- a 2026-10-14 shell sat for "
        "over a day on `cat > /dev/null`. Give `cat` a file, or write the file "
        "with the Write tool.")

sys.exit(0)
