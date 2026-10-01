#!/bin/bash
#
# FREEZE THE CONTEST MATRIX -- write tr4w/test/contest-matrix/frozen from a run
# of the current build.  The ONLY thing that writes those files.
#
# ---------------------------------------------------------------------------
# WHEN THIS MAY BE RUN
# ---------------------------------------------------------------------------
#   1. ONCE, BEFORE THE FIRST MOVE (milestone M0).  The records then say what
#      every contest did before any of its rules moved into a class.
#   2. FOR A NEW ContestType, which has no record yet: name it, and only it.
#   3. WHEN A RULE GENUINELY CHANGED ON PURPOSE -- a sponsor changed it, or a
#      defect was fixed deliberately -- for the contests that change reaches,
#      and only those.
#
# NEVER TO CLEAR A RED RUN.  run-contest-matrix.sh going red is a finding:
# find out WHY the record moved first.  A record re-frozen without a reason is
# a regression written into the oracle, and from then on the gate certifies it.
#
# So the reason is REQUIRED, in writing, and printed back: put it in the commit
# message together with which contests moved and what moved in them.
#
# The bytes are this program's own output, recorded on the day of the freeze.
# They assert "the program does what it did then", never "what it did was
# right" -- see run-contest-matrix.sh.
#
# A BUILD THAT MATCHES THE SOURCE.  These bytes become the gate, so a stale or
# incremental binary would pin whatever it happened to contain.  Run a FULL
# Build-App.ps1 first; the binary frozen from is printed below.
#
# Usage:
#   bash tr4w/test/contest-matrix/freeze-contest-matrix.sh --reason "<why>" [IDENTIFIER ...]
#     no identifiers   re-freeze EVERY contest (replaces the whole frozen set)
#     identifiers      re-freeze only those contests (the ContestType names,
#                      e.g. FLORIDAQSOPARTY), leaving every other record alone
set -u

. "$(dirname "${BASH_SOURCE[0]}")/matrix-lib.sh"

reason=""
if [ "${1:-}" = "--reason" ]; then
   reason="${2:-}"
   shift 2 2>/dev/null || shift $#
fi

if [ -z "$reason" ]; then
   echo "freeze-contest-matrix: REFUSING -- no --reason given." >&2
   echo "  Re-freezing rewrites the oracle.  Say why, in words that will go in" >&2
   echo "  the commit message:  --reason \"<what changed and why it is right>\"" >&2
   echo "  If run-contest-matrix.sh is red and you do not know why, do not freeze." >&2
   exit 1
fi

FRESH="$MATRIX_WORK/freeze"

echo "freezing from: $MATRIX_EXE_SRC"
echo "               $(date -u -r "$MATRIX_EXE_SRC" '+built %Y-%m-%dT%H:%M:%SZ' 2>/dev/null)"
echo "reason:        $reason"

if ! matrix_run "$FRESH" "$@"; then
   echo "=== freeze FAILED -- the run could not be done; nothing was written ==="
   exit 1
fi

# FAIL CLOSED BEFORE TOUCHING ANYTHING.  Zero records, or fewer than were
# named, means the run did not capture what it was asked to.
if [ "${MATRIX_CAPTURED:-0}" -eq 0 ]; then
   echo "=== freeze FAILED -- zero contests captured; nothing was written ==="
   exit 1
fi
if [ $# -gt 0 ] && [ "$MATRIX_CAPTURED" -ne $# ]; then
   echo "=== freeze FAILED -- $# contest(s) named, $MATRIX_CAPTURED captured; nothing was written ==="
   echo "    Name them by ContestType identifier, e.g. FLORIDAQSOPARTY."
   exit 1
fi

mkdir -p "$MATRIX_FROZEN" || exit 1
if [ $# -eq 0 ]; then
   rm -f "$MATRIX_FROZEN"/*.matrix
fi
cp "$FRESH"/*.matrix "$MATRIX_FROZEN"/ || exit 1

echo "=== froze $MATRIX_CAPTURED contest(s) into $MATRIX_FROZEN ==="
matrix_report_failures "$FRESH"
echo "    Commit message: say which contests moved, what moved, and: $reason"
exit 0
