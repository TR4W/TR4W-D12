#!/usr/bin/env python3
r"""Tests for block-stdin-readers.py (issue 289).

Runs the REAL hook as a subprocess, the way Claude Code does, with the PreToolUse
JSON on its standard input -- and that input is always a FILE (never a pipe that
could stay open, never the terminal), so the test itself cannot hang. None of the
commands below is ever run; they are only text handed to the hook.

   python .claude/hooks/test-block-stdin-readers.py

Exit 0 when every case behaves, 1 otherwise. Fails closed: it also fails if the
tables below hold fewer cases than the floors, so an emptied list cannot pass.
"""
import json, os, subprocess, sys, tempfile

HOOK = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'block-stdin-readers.py')

# Commands the hook must REFUSE.
BLOCKED = [
   # the original shapes
   "cat",
   "cat > /dev/null; echo hi",
   "cat >> out.txt",
   "cat -",
   "cat | wc -l",
   "cd /c/x && cat > f",
   "python - <<'EOF'\nprint(1)\nEOF",
   "python - <<EOF\nprint(1)\nEOF",
   "cat <<-X\nhi\nX",
   # the issue 289 shapes
   "python -",
   "python - --version",
   "python3 -",
   "python",
   "python3",
   "py",
   "python -u",
   "python -u -",
   "python - arg1 arg2",
   "python.exe -",
   "/usr/bin/python3.12 -",
   "C:\\Python312\\python.exe -",
   "python - < /dev/null",
   "python - --version < /dev/null",
   "python - > out.txt",
   "python - 2>&1",
   "python - 2>/dev/null",
   "node",
   "node -",
   "bun",
   "bun -",
   "deno -",
   "perl",
   "perl -",
   "ruby -",
   "bash",
   "bash -s",
   "bash -",
   "bash -l",
   "sh",
   "sh -s arg",
   "zsh -s",
   "powershell",
   "powershell -NoProfile",
   "powershell -Command -",
   "pwsh -c -",
   "pwsh -NoProfile -Command -",
   "pwsh -NoLogo",
   "cd /c/tr4w-d12 && python -",
   "echo start; python -",
   "echo hi && node",
   "FOO=1 python -",
   "env FOO=1 python -",
   "python - | tee out.txt",
   "if true; then python -; fi",
   "(python -)",
   # wrappers that hide the command word (a timeout kills it late, not never)
   "timeout 10 python -",
   "timeout -k 5 10 python -",
   "timeout --signal=KILL 10 python - --version",
   "timeout 8 python - < /dev/null > /dev/null 2>&1",
   "winpty python",
   "setsid python -",
   "timeout 10 cat",
   # review finding H8 (2026-11-16): substitutions, in every spelling
   "echo $(python -)",
   "echo \"$(python -)\"",
   "echo `python -`",
   "echo \"`python -`\"",
   "x=$(cat)",
   "echo $(echo $(python -))",
   "diff <(python -) f",
   "cat f > >(python -)",
   # wrappers with options that hid the command word
   "env -i python -",
   "env -u FOO python",
   "sudo -u x python -",
   "sudo python",
   "time -p python -",
   "nice -n 5 python -",
   "stdbuf -oL python -",
   "stdbuf -o L python -",
   "nohup python -",
   "ionice -c 3 python -",
   "echo hi && env -i FOO=1 python -",
   # a command string handed to another program
   "bash -c \"python -\"",
   "bash -lc 'cat'",
   "sh -c 'echo hi; python -'",
   "bash -c \"bash -c 'python -'\"",
   "cmd.exe /c python -",
   "cmd /c python",
   "ssh host python -",
   "ssh -p 22 user@host 'python -'",
   "ssh -o BatchMode=yes host cat",
   # an interactive interpreter reads stdin after (or instead of) the script
   "python -i script.py",
   "python -iu script.py",
   "python3 -i -c 'print(1)'",
   "node -i",
   # a command that cannot be parsed is refused, not allowed
   "echo 'unbalanced",
   "echo \"unbalanced",
   "echo $(python -c 'x'",
   "echo `unterminated",
   "echo $(echo \")\"",
   # a newline ends a command, and a `#` inside a word is not a comment
   "echo hi\npython -",
   "echo hi \\\n && python -",
   "echo a#b; python -",
]

# Commands the hook must ALLOW.
ALLOWED = [
   "ls -l",
   "cat file.txt",
   "cat -A file.txt",
   "cat a b > c",
   "cat < file.txt",
   "cat < /dev/null",
   "cat 2>/dev/null file.txt",
   "echo hi | cat",
   "cat file | python -",
   "echo cat",
   "python script.py",
   "python script.py arg",
   "python -I script.py",
   "python -u script.py",
   "python -c 'print(1)'",
   "python -c \"import sys; print(sys.argv)\" arg",
   "python3 -c 'print(1)'",
   "python -m pytest",
   "python -m pip install x",
   "python -Wignore script.py",
   "python -W error script.py",
   "python -X utf8 script.py",
   "python --version",
   "python -V",
   "python3 --version",
   "python -h",
   "python.exe script.py",
   "C:\\Python312\\python.exe script.py",
   "/usr/bin/python3.12 script.py",
   "py -3 script.py",
   "python .claude/hooks/test-block-stdin-readers.py",
   "python tools/srcfile.py a b > out.txt 2>&1",
   "python - < script.py",
   "python - < /c/tr4w-d12/tools/srcfile.py",
   "python - <<< 'print(1)'",
   "echo 'print(1)' | python -",
   "printf 'x' | python",
   "cat script.py | python -",
   "echo hi | node",
   "echo hi | bash -s",
   "node script.js",
   "node -e 'console.log(1)'",
   "node -p 1+1",
   "node --version",
   "node -r ts-node/register script.js",
   "bun script.ts",
   "bun run build",
   "bun --version",
   "bun -e 'console.log(1)'",
   "deno run script.ts",
   "perl script.pl",
   "perl -e 'print 1'",
   "ruby -e 'puts 1'",
   "bash script.sh",
   "bash script.sh arg",
   "bash -c 'echo hi'",
   "bash -lc 'echo hi'",
   "bash -e script.sh",
   "bash --version",
   "bash -o pipefail -c 'echo hi'",
   "sh -c 'echo hi'",
   "sh build.sh",
   "sh tr4w/build/build-unix.sh --list",
   "zsh -c 'echo hi'",
   "powershell -NoProfile -File build.ps1",
   "powershell -Command \"Get-Date\"",
   "powershell -NoProfile -Command Get-Date",
   "powershell -ExecutionPolicy Bypass -File x.ps1",
   "pwsh -c 'Get-Date'",
   "pwsh -File x.ps1 -Arg 1",
   "pwsh -Version",
   "powershell -Command - < script.ps1",
   "cd /c/x && python script.py",
   "FOO=1 python script.py",
   "env FOO=1 python script.py",
   "echo hi; python script.py; echo done",
   "if true; then python script.py; fi",
   "python script.py && node script.js",
   "x=$(python -c 'print(1)')",
   "echo 'python -' > note.txt",
   "echo python",
   "git commit -m 'fix python - bug'",
   "rg -n 'python -' .",
   "gh issue view 289 --comments",
   "echo $((1<<2))",
   "cat <<< 'text'",
   "timeout 10 python script.py",
   "timeout -k 5 10 python -c 'print(1)'",
   "timeout 10 python - < script.py",
   "timeout 10 ls",
   "timeout 10 cat file.txt",
   "echo hi | timeout 10 python -",
   "winpty python script.py",
   # review finding H8: the counterparts of the new blocked shapes
   "echo $(date)",
   "echo \"$(python -c 'print(1)')\"",
   "echo `date`",
   "echo '$(python -)'",
   "echo '`python -`'",
   "echo $((1 + 2))",
   "diff <(sort a) <(sort b)",
   "cat f > >(wc -l)",
   "env -i python script.py",
   "env -u FOO python script.py",
   "sudo -u x python script.py",
   "time -p python script.py",
   "nice -n 5 python script.py",
   "stdbuf -oL python script.py",
   "stdbuf -o L python script.py",
   "nohup python script.py",
   "ionice -c 3 python script.py",
   "command -v python",
   "command -v cat",
   "echo x | env python -",
   "echo x | sudo -u x python -",
   "bash -c \"python script.py\"",
   "bash -lc 'echo hi'",
   "sh -c 'echo hi; python -c \"print(1)\"'",
   "bash -c 'python - < script.py'",
   "echo x | bash -c 'python -'",
   "cmd.exe /c python script.py",
   "cmd /c dir",
   "ssh host python script.py",
   "ssh host 'ls -l'",
   "ssh -p 22 user@host 'python -c \"print(1)\"'",
   "ssh -n host python -",
   "ssh host 'python - < f'",
   "echo x | ssh host python -",
   "python -i script.py < input.txt",
   "python -mpip install x",
   "python -Wignore script.py",
   "node script.js",
   "bun -i script.ts",
   "echo hi # don't wait",
   "echo hi\nls -l",
   "echo hi \\\n && ls",
   "echo a#b python -",
]

MIN_BLOCKED = 100
MIN_ALLOWED = 130


def run_hook(command, tool_name='Bash'):
   """Returns the parsed decision, or None when the hook printed nothing (= allow)."""
   payload = json.dumps({'tool_name': tool_name, 'tool_input': {'command': command}})
   with tempfile.NamedTemporaryFile('w', suffix='.json', delete=False, encoding='utf-8') as f:
      f.write(payload)
      path = f.name
   try:
      with open(path, 'rb') as stdin_file:
         done = subprocess.run([sys.executable, '-I', HOOK], stdin=stdin_file,
                               stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=30)
   finally:
      os.unlink(path)
   if done.returncode != 0:
      return {'error': 'exit %d: %s' % (done.returncode, done.stderr.decode('utf-8', 'replace'))}
   if done.stderr.strip():
      return {'error': 'stderr: ' + done.stderr.decode('utf-8', 'replace')}
   out = done.stdout.decode('utf-8', 'replace').strip()
   if not out:
      return None
   return json.loads(out)


def main():
   failures = []

   if len(BLOCKED) < MIN_BLOCKED or len(ALLOWED) < MIN_ALLOWED:
      failures.append('case tables below their floors: %d blocked (min %d), %d allowed (min %d)'
                      % (len(BLOCKED), MIN_BLOCKED, len(ALLOWED), MIN_ALLOWED))

   dup = set(BLOCKED) & set(ALLOWED)
   if dup:
      failures.append('commands in both tables: %r' % sorted(dup))

   for cmd in BLOCKED:
      got = run_hook(cmd)
      if got is None:
         failures.append('NOT BLOCKED (should be): %r' % cmd)
      elif 'error' in got:
         failures.append('hook error on %r: %s' % (cmd, got['error']))
      elif got.get('hookSpecificOutput', {}).get('permissionDecision') != 'deny':
         failures.append('wrong decision on %r: %r' % (cmd, got))

   for cmd in ALLOWED:
      got = run_hook(cmd)
      if got is not None:
         failures.append('BLOCKED (should be allowed): %r -> %s' % (cmd, json.dumps(got)[:160]))

   # Not a Bash call, and garbage input: the hook must stay silent and exit 0.
   if run_hook('python -', tool_name='Read') is not None:
      failures.append('a non-Bash tool call was judged')
   with tempfile.NamedTemporaryFile('wb', suffix='.json', delete=False) as f:
      f.write(b'this is not json')
      path = f.name
   try:
      with open(path, 'rb') as stdin_file:
         done = subprocess.run([sys.executable, '-I', HOOK], stdin=stdin_file,
                               stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=30)
      if done.returncode != 0 or done.stdout.strip():
         failures.append('garbage input did not exit 0 silently')
   finally:
      os.unlink(path)

   total = len(BLOCKED) + len(ALLOWED) + 2
   if failures:
      for line in failures:
         print('FAIL ' + line)
      print('block-stdin-readers tests: %d FAILED of %d' % (len(failures), total))
      return 1
   print('block-stdin-readers tests: %d passed (%d blocked shapes, %d allowed shapes)'
         % (total, len(BLOCKED), len(ALLOWED)))
   return 0


if __name__ == '__main__':
   sys.exit(main())
