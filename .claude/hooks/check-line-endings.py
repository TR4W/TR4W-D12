"""PostToolUse hook: catch a source file that has just been LF-ified.

WHY. Lint-LineEndings already gates the BUILD, which is the right place for a
gate but the wrong place to LEARN. On 2026-08-29 a single command that rewrote
97 files converted all of them to LF, and that surfaced minutes later as a lint
failure with no obvious connection to the command that caused it. Twice more the
same day, one file at a time.

The existing PostToolUse hook is driven by tool_input.file_path, so it only ever
sees Edit/Write/MultiEdit. Every one of those incidents came from a script run
through BASH, which that hook cannot see.

So this one asks git what changed instead of being told, and reports straight
back. It never blocks -- the write already happened -- it just makes the damage
visible while the cause is still on screen.

Exit 2 with a message = feedback to the model. Exit 0 = quiet.
"""

import json
import os
import subprocess
import sys

REPO = os.environ.get('CLAUDE_PROJECT_DIR') or 'C:/tr4w-d12'

# Source that must be CRLF in this tree. Kept in step with
# tr4w/build/PascalSource.psm1 and Lint-LineEndings.ps1.
EXTS = ('.pas', '.lpr', '.dpr', '.dpk', '.inc', '.lfm', '.dfm', '.ps1', '.psm1')

# Deliberately LF, or not ours.
SKIP = ('/include/', '\\include\\', '/backup/', '\\backup\\',
        'graphify-out', 'build-out')


def git(*args):
   try:
      out = subprocess.run(['git', '-C', REPO] + list(args),
                           capture_output=True, timeout=15)
      return out.stdout.decode('utf-8', 'replace').splitlines()
   except Exception:
      return []


def main():
   try:
      sys.stdin.read()          # drain; the payload is not needed
   except Exception:
      pass

   changed = set(git('diff', '--name-only'))
   changed |= set(git('diff', '--cached', '--name-only'))
   changed |= set(git('ls-files', '--others', '--exclude-standard'))
   if not changed:
      return 0

   bad = []
   for rel in changed:
      if not rel.lower().endswith(EXTS):
         continue
      if any(s in rel for s in SKIP):
         continue
      path = os.path.join(REPO, rel)
      try:
         raw = open(path, 'rb').read()
      except Exception:
         continue
      crlf = raw.count(b'\r\n')
      lf = raw.count(b'\n') - crlf
      if lf > 0:
         bad.append((rel, lf))

   if not bad:
      return 0

   msg = ['LINE ENDINGS: %d source file(s) now contain bare LF.' % len(bad), '']
   for rel, n in bad[:12]:
      msg.append('   %-58s %d bare LF' % (rel, n))
   if len(bad) > 12:
      msg.append('   ... and %d more' % (len(bad) - 12))
   msg += [
      '',
      'This tree is CRLF and it is load-bearing -- the form designer inserts',
      'code BY BYTE OFFSET, so against an LF file a new handler is spliced into',
      'the middle of an identifier (CLAUDE.md, "CRLF is load-bearing").',
      '',
      'Almost always the cause is a script that read with universal newlines',
      'and wrote with newline=\'\'. Use tools/srcfile.py (read/write preserve the',
      'file\'s own BOM and newline), or repair with:',
      '',
      '   powershell -File tr4w\\build\\Lint-LineEndings.ps1 -SourceDir tr4w -Fix',
   ]
   sys.stderr.write('\n'.join(msg) + '\n')
   return 2


if __name__ == '__main__':
   try:
      sys.exit(main())
   except Exception:
      sys.exit(0)      # a hook must never wedge the session
