#!/usr/bin/env python3
"""PreToolUse(Bash) hook: enforce `git -C /c/tr4w-d12 ...` and forbid a leading `cd`.

NY4I's standing rule (project CLAUDE.md > "MANDATORY: Git command form"): every git
invocation must use the -C flag so no `cd` to the repo is needed (a cd to the current
dir triggers a permission prompt every time). This hook is the enforced backstop.

Exit 0 = allow. Exit 2 = block; stderr is shown back to the agent as feedback.
Only git invocations are inspected; msbuild's `cd /d ...\\tr4w` etc. are untouched.
"""
import sys, json, re, os

# The repo path is DERIVED, not hardcoded. This hook is tracked and runs in every
# clone, and the clones are not at the same path -- this one is C:\tr4w-d12, the
# other is C:\projects\TR4W-D12. Only the advisory message needs it; the rule
# itself is just "git must use -C", which is path-independent.
_repo = os.environ.get("CLAUDE_PROJECT_DIR") or os.getcwd()
REPO = _repo.replace("\\", "/")

try:
   data = json.load(sys.stdin)
except Exception:
   sys.exit(0)  # never break tool use on a parse hiccup

cmd = (data.get("tool_input") or {}).get("command", "") or ""

# Find each git invocation that starts a command/segment (^, newline, ; && || | )
# so the word "git" inside a commit message or path does not false-trigger.
violations = []
for m in re.finditer(r'(?:^|[\n;&|])\s*(git\b[^\n;&|]*)', cmd):
   seg = m.group(1)
   if not re.match(r'git\s+-C\b', seg):
      violations.append(seg.strip()[:120])

if violations:
   sys.stderr.write(
      "BLOCKED by .claude/hooks/enforce-git-c.py (git-command-convention).\n"
      "Every git command MUST use:  git -C " + REPO + " <subcommand>\n"
      "Do NOT prepend `cd` for git. Rewrite these invocation(s):\n")
   for v in violations:
      sys.stderr.write("  - " + v + "\n")
   sys.exit(2)

sys.exit(0)
