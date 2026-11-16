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

4. (2026-11-16, review finding H8) THE HOOK NOW FAILS CLOSED AND LOOKS THROUGH:
   - A command it cannot parse (unbalanced quote, unterminated `$(`, or an
     internal hook error) is REFUSED, not allowed. A guard that allows what it
     cannot read is open exactly where the risk is.
   - `$( )`, backticks and `<( )` / `>( )` bodies are judged as commands of
     their own, including inside double quotes (never inside single quotes).
   - Wrappers are skipped WITH their options: `env -i -u X`, `sudo -u x`,
     `time -p`, `nice -n 5`, `stdbuf -oL`, `nohup`, `exec`, `command`, `ionice`,
     `doas`, `winpty`, `setsid`, `timeout [opts] N` and `VAR=value` prefixes.
     `command -v x` only asks a question and is left alone.
   - A command string handed to another shell is judged: `bash -c "..."`,
     `cmd /c ...`, `ssh host ...` (a remote command inherits our stdin, so
     `ssh host python -` waits; `ssh -n` does not).
   - `python -i` / `node -i` keep the REPL open and read stdin after the script.
   - A newline outside quotes ends a command (it used to be plain whitespace, so
     `echo hi<newline>python -` hid the second command), and a `#` comment is
     removed the way a shell does it (shlex's own comment rule also fired in the
     MIDDLE of a word and swallowed the rest of the command).

LIMITS, said plainly: this is a token walk, not a shell parser. An interpreter
reached through `xargs`, a function, an alias, a `case` statement inside `$( )`,
or a `powershell -Command "..."` string is not seen.

Write a file with the Write tool, edit one with the Edit tool or
tools/srcfile.py, and pass a script to Python as a file in the scratchpad.

Exit 0 always; a block is reported as a PreToolUse "deny" decision. Input that is
not the expected PreToolUse JSON, or is not a Bash call, is not judged at all.
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
#
# name -> the options that take the NEXT word as their value (so that word is not
# mistaken for the command). Any other `-x` option is skipped on its own, which
# covers `env -i`, `time -p`, `nice -5` and the attached `stdbuf -oL`. `timeout`
# has its own routine because its DURATION is a positional argument.
WRAPPERS = {
   'env': {'-u', '-C', '-S', '--unset', '--chdir', '--split-string'},
   'sudo': {'-u', '-g', '-C', '-h', '-p', '-r', '-t', '-U', '-D', '-R', '-T'},
   'doas': {'-u', '-C'},
   'time': {'-f', '-o', '--format', '--output'},
   'nice': {'-n', '--adjustment'},
   'ionice': {'-c', '-n', '-p', '-P', '-u', '-t'},
   'stdbuf': {'-i', '-o', '-e', '--input', '--output', '--error'},
   'nohup': set(),
   'exec': {'-a'},
   'command': set(),
   'winpty': set(),
   'setsid': set(),
   'timeout': set(),
}
# Shells that take their program as a string after `-c`.
SHELLS = {'bash', 'sh', 'zsh', 'dash'}
# `ssh` options that take a value (the host is the first word that is not one).
SSH_VALUED = {'-B', '-b', '-c', '-D', '-E', '-e', '-F', '-I', '-i', '-J', '-L', '-l', '-m', '-O', '-o',
              '-p', '-Q', '-R', '-S', '-W', '-w'}
# How deep `$( $( ) )` and `bash -c "bash -c ..."` may nest before we give up (and refuse).
MAX_DEPTH = 6
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
          'stdin': set(), 'valopts': {'-W', '-X', '--check-hash-based-pycs'}, 'iletters': 'i'}
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


def normalise_windows_paths(cmd):
   """POSIX shlex reads a backslash as an escape and would eat the separators of
   `C:\\Python312\\python.exe`; write a Windows drive path with slashes first."""
   return WINDOWS_PATH.sub(lambda m: m.group(0).replace('\\', '/'), cmd)


def tokenize(cmd):
   """The command as shell-ish tokens, or None when the quoting is unbalanced."""
   cmd = normalise_windows_paths(cmd)
   try:
      lexer = shlex.shlex(cmd, posix=True, punctuation_chars=';&|()<>')
      lexer.whitespace_split = True
      # shlex would treat a `#` ANYWHERE as the start of a comment and drop the rest
      # of the command; extract_substitutions has already removed real comments.
      lexer.commenters = ''
      return list(lexer)
   except ValueError:
      return None                       # unbalanced quotes: the caller refuses the command


def find_closing_paren(cmd, start):
   """Index of the `)` that closes a `(` already consumed, starting at `start`; -1 if none.

   Quotes inside the body are honoured, so `$(echo ")")` closes where the shell closes it.
   """
   depth = 1
   i = start
   n = len(cmd)
   while i < n:
      c = cmd[i]
      if c == '\\':
         i += 2
         continue
      if c == "'":
         end = cmd.find("'", i + 1)
         if end < 0:
            return -1
         i = end + 1
         continue
      if c == '"':
         i += 1
         while i < n and cmd[i] != '"':
            i += 2 if cmd[i] == '\\' else 1
         i += 1
         continue
      if c == '(':
         depth += 1
      elif c == ')':
         depth -= 1
         if depth == 0:
            return i
      i += 1
   return -1


def extract_substitutions(cmd):
   """(text, bodies), or None when a quote or substitution is never closed.

   `text` is the command with every `$( )`, backtick and `<( )` / `>( )` replaced
   by the word SUBST, every comment removed and every unquoted newline turned
   into `;`; `bodies` are the substituted command lines, to be judged on their
   own. A substitution is live inside double quotes and dead inside single ones.
   """
   out = []
   bodies = []
   i = 0
   n = len(cmd)
   in_single = False
   in_double = False
   while i < n:
      c = cmd[i]
      nxt = cmd[i + 1] if i + 1 < n else ''
      if in_single:
         out.append(c)
         if c == "'":
            in_single = False
         i += 1
         continue
      if c == '\\':
         if nxt == '\n':
            out.append(' ')             # a line continuation
         else:
            out.append(cmd[i:i + 2])
         i += 2
         continue
      if c == "'" and not in_double:
         in_single = True
         out.append(c)
         i += 1
         continue
      if c == '"':
         in_double = not in_double
         out.append(c)
         i += 1
         continue
      if c == '`':
         j = i + 1
         while j < n and cmd[j] != '`':
            j += 2 if cmd[j] == '\\' else 1
         if j >= n:
            return None
         bodies.append(cmd[i + 1:j])
         out.append('SUBST')
         i = j + 1
         continue
      if nxt == '(' and (c == '$' or (c in '<>' and not in_double)):
         close = find_closing_paren(cmd, i + 2)
         if close < 0:
            return None
         bodies.append(cmd[i + 2:close])
         out.append('SUBST')
         i = close + 1
         continue
      if not in_double:
         if c == '\n':
            out.append(' ; ')
            i += 1
            continue
         if c == '#' and (i == 0 or cmd[i - 1] in ' \t\n;&|()'):
            while i < n and cmd[i] != '\n':
               i += 1
            continue
      out.append(c)
      i += 1
   if in_single or in_double:
      return None
   return ''.join(out), bodies


def command_name(word):
   """`C:\\Python\\python3.12.exe` -> `python`; a path and a version are not the interpreter."""
   base = word.replace('\\', '/').rsplit('/', 1)[-1].lower()
   if base.endswith('.exe'):
      base = base[:-4]
   match = re.match(r'^(python|pythonw|py)[0-9.]*$', base)
   if match:
      return match.group(1)
   return base


def skip_timeout_arguments(toks, j):
   """Index of the command word after `timeout [options] DURATION`, given toks[j] == 'timeout'.

   `timeout 10 python -` still hangs: timeout starts python with the same
   standard input, and only kills it after the duration.
   """
   j += 1
   while j < len(toks) and toks[j].startswith('-') and toks[j] not in COMMAND_START:
      if toks[j] in ('-s', '-k', '--signal', '--kill-after'):
         j += 1                         # the option's value is the next word
      j += 1
   return j + 1                         # the duration


def skip_wrapper(toks, j):
   """(index of the word after `wrapper [options]`, True when it only asks a question).

   `command -v python` prints a path and exits; it does not run python.
   """
   name = command_name(toks[j])
   valued = WRAPPERS[name]
   asks_only = False
   j += 1
   while j < len(toks) and toks[j].startswith('-') and toks[j] not in COMMAND_START:
      option = toks[j]
      if option == '--':
         j += 1
         break
      if name == 'command' and option in ('-v', '-V'):
         asks_only = True
      j += 2 if option in valued else 1
   return j, asks_only


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
      asks_only = False
      while j < n:
         wrapper = command_name(toks[j])
         if ASSIGNMENT.match(toks[j]):
            j += 1
         elif wrapper == 'timeout':
            j = skip_timeout_arguments(toks, j)
         elif wrapper in WRAPPERS:
            j, asked = skip_wrapper(toks, j)
            asks_only = asks_only or asked
         else:
            break
      if asks_only or j >= n or toks[j] in COMMAND_START:
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


def cat_reads_stdin(operands):
   """True when a `cat` with these operands (redirections removed) reads standard input."""
   # `cat -` IS standard input, so `-` is not a file; any other word is.
   return not any(o != '-' and not o.startswith('-') for o in operands) or '-' in operands


def interpreter_reads_stdin(name, operands, spec):
   """True when this interpreter, given these operands, reads its program from stdin."""
   ci = spec.get('ci', False)
   i = 0
   while i < len(operands):
      raw = operands[i]
      tok = raw.lower() if ci else raw
      if tok == '-' or tok in spec['stdin']:
         return True
      # `node -i` is a REPL (bun's and deno's `-i` mean something else, so name-keyed).
      if name == 'node' and tok in ('-i', '--interactive'):
         return True
      # `python -i script.py` runs the script and then reads the REPL from stdin.
      # Only letters BEFORE one that takes a value count: `-Wignore` and `-mpip` end in text.
      if tok.startswith('-') and not tok.startswith('--') and len(tok) > 1 and not ci:
         for ch in tok[1:]:
            if ch in 'cmWX':
               break
            if ch in spec.get('iletters', ''):
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


def shell_command_string(operands):
   """The program text given to `bash -c TEXT` (also `-lc`), or None when there is none."""
   i = 0
   while i < len(operands):
      tok = operands[i]
      if tok in SHELL['valopts']:
         i += 2
         continue
      if tok == '-c' or (tok.startswith('-') and not tok.startswith('--') and 'c' in tok[1:]):
         return operands[i + 1] if i + 1 < len(operands) else None
      if tok.startswith('-') or tok.startswith('+'):
         i += 1
         continue
      return None                       # the first plain word is a script file
   return None


def ssh_remote_command(operands):
   """The remote command line given to ssh ('' when none); None when `-n` closes its stdin."""
   i = 0
   host_seen = False
   while i < len(operands):
      tok = operands[i]
      if not host_seen and tok.startswith('-') and len(tok) > 1:
         if not tok.startswith('--') and 'n' in tok[1:] and tok not in SSH_VALUED:
            return None                 # `ssh -n`: the remote command reads /dev/null
         i += 2 if tok in SSH_VALUED else 1
         continue
      if not host_seen:
         host_seen = True
         i += 1
         continue
      return ' '.join(operands[i:])
   return ''


def cmd_command_line(operands):
   """The command line given to `cmd /c ...` (or /k), or None when there is none."""
   for i, tok in enumerate(operands):
      if tok.lower() in ('/c', '/k', '/r'):
         return ' '.join(operands[i + 1:])
   return None


def judge(name, args, fed, depth):
   """One simple command: None when it may run, else ('cat', name) / ('interp', name) / ('unparseable', '')."""
   operands, stdin_target, here_string = split_redirections(args)
   if name == 'cat':
      if fed or supplies_stdin(stdin_target, here_string, True):
         return None
      if cat_reads_stdin(operands):
         return ('cat', name)
      return None
   if fed or supplies_stdin(stdin_target, here_string, False):
      return None                       # something real feeds it, and an inner command inherits that
   nested = None
   if name in SHELLS:
      nested = shell_command_string(operands)
   elif name == 'ssh':
      nested = ssh_remote_command(operands)
   elif name == 'cmd':
      nested = cmd_command_line(operands)
   if nested:
      found = scan(nested, depth + 1)
      if found:
         return found
   spec = INTERPRETERS.get(name)
   if spec is not None and interpreter_reads_stdin(name, operands, spec):
      return ('interp', name)
   return None


def scan(cmd, depth=0):
   """The first finding in a command line, or None.

   A finding is ('cat', name), ('interp', name), or ('unparseable', '') when the
   command cannot be read -- which is refused, because a guard that allows what
   it cannot read is open exactly where the danger is.
   """
   if depth > MAX_DEPTH:
      return ('unparseable', '')
   cmd = normalise_windows_paths(cmd)
   split = extract_substitutions(cmd)
   if split is None:
      return ('unparseable', '')
   text, bodies = split
   for body in bodies:
      found = scan(body, depth + 1)
      if found:
         return found
   toks = tokenize(text)
   if toks is None:
      return ('unparseable', '')
   for name, args, fed in commands(toks):
      found = judge(name, args, fed, depth)
      if found:
         return found
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
   try:
      found = scan(cmd)
   except Exception:
      found = ('unparseable', '')       # a hook bug must not turn into "allowed"
   if found is None:
      return None
   kind, waiting = found
   if kind == 'unparseable':
      return ("BLOCKED (block-stdin-readers hook): this command cannot be parsed (an "
              "unbalanced quote, an unterminated `$(` or backtick, or nesting too deep), "
              "so the hook cannot tell whether it waits on standard input and refuses it "
              "(issue 289). Fix the quoting, or write the text to a file with the Write "
              "tool and pass the FILE.")
   if kind == 'cat':
      return ("BLOCKED (block-stdin-readers hook): `cat` has no input file here, so it "
              "reads standard input and waits for ever -- a 2026-10-14 shell sat for "
              "over a day on `cat > /dev/null`. Give `cat` a file, or write the file "
              "with the Write tool.")
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
