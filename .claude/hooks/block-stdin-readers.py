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
   `cat >> f`, `cat -`, `cat | x`, `cat; x`). `cat file`, `cat -A file`,
   `cat < file` and `x | cat` (fed by a pipe) are allowed.
3. A BARE INTERPRETER (issue 289, 2026-11-12): python / python3 / py, node, bun,
   deno, perl, ruby, bash / sh / zsh / dash, powershell / pwsh given NO program
   -- no script file, no `-c`/`-e`/`-m`/`-Command`/`-File` -- or given `-` (or
   `bash -s`), which means "read the program from standard input". `python -
   --version` was the shape that got through: `-` ends python's options, so
   `--version` was merely an argument to a program read from stdin.
   Allowed: `python script.py`, `python -c '...'`, `python -m mod`,
   `python --version`, `bash -c '...'`, `x | python -` (a pipe supplies it),
   `python - < file` and `python - <<< "text"` (supplied input).

   `< /dev/null` DOES NOT COUNT FOR AN INTERPRETER, and that is measured, not
   assumed (2026-11-12, Windows, Python 3.12): `python - < /dev/null` with its
   output also sent to /dev/null ran past a 15 s timeout, where `python - <
   somefile` returned at once. Windows reports the NUL device as a terminal, so
   a native python treats it as an interactive console rather than a file at
   EOF. The same redirect is fine for `cat` (measured: returns at once), so it
   is accepted there only. Redirect from a REAL file, or pipe a real producer.

LIMITS, said plainly: this is a token walk, not a shell parser. A wrapper this
file does not know (`timeout 10 python -`, `winpty python`) hides the command
word and is not seen; `env`, `time`, `nohup`, `exec`, `command`, `sudo` and
`VAR=value` prefixes are skipped. An interpreter reached through `xargs`, a
function or an alias is not seen either.

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

# Where a command ends, for deciding whether a command was given its input.
COMMAND_END = {';', '&&', '||', '|', '&', ')'}
# Words after which a new command starts.
COMMAND_START = COMMAND_END | {'(', 'then', 'do', 'else', '{', '!'}
# A redirection operator token, with an optional leading fd digit or `&`.
REDIRECTION = re.compile(r'^(?:\d*|&)(?:>>?&?|<<<|<&?)$')
# Words that run the next word without changing what it reads.
WRAPPERS = {'env', 'time', 'nohup', 'exec', 'command', 'sudo'}
ASSIGNMENT = re.compile(r'^[A-Za-z_]\w*=')
WINDOWS_PATH = re.compile(r'(?<![\w])[A-Za-z]:\\[^\s"\';|&<>()]*')

# Redirect targets that look like "input is supplied" and are not, for an
# interpreter (see the header). `cat` is fine with /dev/null.
NULL_DEVICES = {'/dev/null', 'nul', 'NUL', '/dev/tty', '/dev/stdin', '/dev/zero', 'con', 'CON'}

# What each interpreter treats as "a program was supplied" or "just print info".
#   program : flags that carry the program inline (it is NOT read from stdin)
#   letters : letters that, inside a short-option cluster such as -lc, do the same
#   info    : flags that print something and exit
#   stdin   : flags that mean "read the program from stdin" (`-` is always one)
#   valopts : flags whose next word is their value, not a script
#   ci      : option names are case-insensitive (PowerShell)
#   dash_after_program : `-Command -` means stdin (PowerShell only)
PYTHON = {'program': {'-c', '-m'}, 'letters': 'cm', 'info': {'-V', '-VV', '--version', '-h', '-?', '--help'},
          'stdin': set(), 'valopts': {'-W', '-X', '--check-hash-based-pycs'}}
NODE = {'program': {'-e', '--eval', '-p', '--print'}, 'letters': '', 'info': {'-v', '--version', '-h', '--help'},
        'stdin': set(), 'valopts': {'-r', '--require', '--import', '--loader', '--experimental-loader'}}
SHELL = {'program': {'-c'}, 'letters': 'c', 'info': {'--version', '--help', '-h'},
         'stdin': {'-s'}, 'valopts': {'-o', '+o', '-O', '+O', '--rcfile', '--init-file'}, 'sletters': 's'}
PERL = {'program': {'-e', '-E'}, 'letters': '', 'info': {'-v', '-V', '-h', '--version', '--help'},
        'stdin': set(), 'valopts': {'-I', '-M', '-m'}}
POWERSHELL = {'program': {'-command', '-c', '-file', '-f', '-encodedcommand', '-e', '-ec'}, 'letters': '',
              'info': {'-?', '-help', '-h', '-version', '-v'}, 'stdin': set(),
              'valopts': {'-executionpolicy', '-ep', '-workingdirectory', '-wd', '-inputformat', '-if',
                          '-outputformat', '-of', '-windowstyle', '-w', '-configurationname', '-psconsolefile',
                          '-custompipename', '-settingsfile'},
              'ci': True, 'dash_after_program': True}

INTERPRETERS = {
   'python': PYTHON, 'py': PYTHON, 'pythonw': PYTHON,
   'node': NODE, 'bun': NODE, 'deno': NODE,
   'perl': PERL, 'ruby': PERL,
   'bash': SHELL, 'sh': SHELL, 'zsh': SHELL, 'dash': SHELL,
   'powershell': POWERSHELL, 'pwsh': POWERSHELL,
}


def tokenize(cmd):
   """The command as shell-ish tokens, or None when the quoting is unbalanced."""
   # POSIX shlex reads a backslash as an escape and would eat the separators of
   # `C:\Python312\python.exe`; write a Windows drive path with slashes first.
   cmd = WINDOWS_PATH.sub(lambda m: m.group(0).replace('\\', '/'), cmd)
   try:
      lexer = shlex.shlex(cmd, posix=True, punctuation_chars=';&|()<>')
      lexer.whitespace_split = True
      return list(lexer)
   except ValueError:
      return None                       # unbalanced quotes: let the shell report it


def command_name(word):
   """`C:\\Python\\python3.12.exe` -> `python`; a path and a version are not the interpreter."""
   base = word.replace('\\', '/').rsplit('/', 1)[-1].lower()
   if base.endswith('.exe'):
      base = base[:-4]
   match = re.match(r'^(python|pythonw|py)[0-9.]*$', base)
   if match:
      return match.group(1)
   return base


def commands(toks):
   """Yield (name, args, fed_by_pipe) for every simple command in the token list."""
   n = len(toks)
   for s in range(n):
      if s > 0 and toks[s - 1] not in COMMAND_START:
         continue
      if toks[s] in COMMAND_START:
         continue
      fed = s > 0 and toks[s - 1] == '|'
      j = s
      while j < n and (ASSIGNMENT.match(toks[j]) or toks[j] in WRAPPERS):
         j += 1
      if j >= n or toks[j] in COMMAND_START:
         continue
      k = j + 1
      while k < n and toks[k] not in COMMAND_END and toks[k] != '(':
         k += 1
      yield command_name(toks[j]), toks[j + 1:k], fed


def split_redirections(args):
   """(operands, stdin_target, here_string): the arguments with redirections taken out.

   stdin_target is the word after the last `<` (None when there is none);
   here_string is True when a `<<<` supplied the input.
   """
   operands = []
   stdin_target = None
   here_string = False
   i = 0
   while i < len(args):
      t = args[i]
      # `2>/dev/null` tokenises as `2`, `>`, `/dev/null`: the digit belongs to it.
      if t.isdigit() and i + 1 < len(args) and REDIRECTION.match(args[i + 1]):
         i += 1
         continue
      if REDIRECTION.match(t):
         target = args[i + 1] if i + 1 < len(args) else None
         if t == '<<<':
            here_string = True
         elif t.endswith('<'):
            stdin_target = target
         i += 2
         continue
      operands.append(t)
      i += 1
   return operands, stdin_target, here_string


def supplies_stdin(stdin_target, here_string, null_is_input):
   """True when the command's standard input is a real source, so it cannot wait."""
   if here_string:
      return True
   if stdin_target is None:
      return False
   if stdin_target in NULL_DEVICES and not null_is_input:
      return False
   return True


def cat_reads_stdin(cmd):
   """True when some `cat` in the command has no file operand and is not fed by a pipe."""
   toks = tokenize(cmd)
   if toks is None:
      return False
   for name, args, fed in commands(toks):
      if name != 'cat' or fed:
         continue
      operands, stdin_target, here_string = split_redirections(args)
      if supplies_stdin(stdin_target, here_string, True):
         continue
      # `cat -` IS standard input, so `-` is not a file; any other word is.
      if not any(o != '-' and not o.startswith('-') for o in operands) or '-' in operands:
         return True
   return False


def interpreter_reads_stdin(name, operands, spec):
   """True when this interpreter, given these operands, reads its program from stdin."""
   ci = spec.get('ci', False)
   i = 0
   while i < len(operands):
      raw = operands[i]
      tok = raw.lower() if ci else raw
      if tok == '-' or tok in spec['stdin']:
         return True
      if tok in spec['program']:
         if spec.get('dash_after_program') and i + 1 < len(operands) and operands[i + 1] == '-':
            return True
         return False
      if tok in spec['info']:
         return False
      if tok in spec['valopts']:
         i += 2
         continue
      if tok.startswith('-') and not tok.startswith('--') and len(tok) > 1 and not ci:
         letters = tok[1:]
         if any(ch in spec['letters'] for ch in letters):
            return False
         if any(ch in spec.get('sletters', '') for ch in letters):
            return True
         i += 1
         continue
      if tok.startswith('-') or (name in ('bash', 'sh', 'zsh', 'dash') and tok.startswith('+')):
         i += 1                         # an option we do not know: keep looking for the program
         continue
      return False                      # the first plain word is the script (or, for bun, a subcommand)
   return True                          # no program anywhere: it reads standard input


def interpreter_waits(cmd):
   """The name of the first bare interpreter that would wait on stdin, or None."""
   toks = tokenize(cmd)
   if toks is None:
      return None
   for name, args, fed in commands(toks):
      spec = INTERPRETERS.get(name)
      if spec is None or fed:
         continue
      operands, stdin_target, here_string = split_redirections(args)
      if supplies_stdin(stdin_target, here_string, False):
         continue
      if interpreter_reads_stdin(name, operands, spec):
         return name
   return None


def deny(reason):
   json.dump({'hookSpecificOutput': {'hookEventName': 'PreToolUse',
                                     'permissionDecision': 'deny',
                                     'permissionDecisionReason': reason}},
             sys.stdout)
   sys.stdout.write('\n')


def verdict(cmd):
   """The deny reason for a command, or None when it may run."""
   if HEREDOC.search(cmd):
      return ("BLOCKED (block-stdin-readers hook): this command uses a heredoc. "
              "Heredocs are forbidden here -- a 2026-10-14 shell waited on standard "
              "input for over a day. Write the content with the Write tool (into the "
              "scratchpad if it is temporary) and pass the FILE to the command instead.")
   if cat_reads_stdin(cmd):
      return ("BLOCKED (block-stdin-readers hook): `cat` has no input file here, so it "
              "reads standard input and waits for ever -- a 2026-10-14 shell sat for "
              "over a day on `cat > /dev/null`. Give `cat` a file, or write the file "
              "with the Write tool.")
   waiting = interpreter_waits(cmd)
   if waiting:
      return ("BLOCKED (block-stdin-readers hook): `" + waiting + "` is given no script, "
              "or is given `-`, so it reads its program from standard input and waits "
              "(issue 289). Write the script to a file with the Write tool and pass the "
              "FILE, or use `-c`/`-e` with the code inline. `< /dev/null` does not help: "
              "a Windows python treats the NUL device as a terminal and still hangs. "
              "Redirect from a real file, or pipe a real producer.")
   return None


def main():
   try:
      data = json.load(sys.stdin)
   except Exception:
      return
   if (data.get('tool_name') or '') != 'Bash':
      return
   cmd = (data.get('tool_input') or {}).get('command', '') or ''
   if not cmd:
      return
   reason = verdict(cmd)
   if reason:
      deny(reason)


if __name__ == '__main__':
   try:
      main()
   except Exception:
      pass                              # a hook bug must never break tool use
   sys.exit(0)
