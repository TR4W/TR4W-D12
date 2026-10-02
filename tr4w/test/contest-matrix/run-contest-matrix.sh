#!/bin/bash
#
# DOES THE PROGRAM STILL SET UP, SCORE AND EXPORT EVERY CONTEST THE WAY IT DID
# WHEN THE MATRIX WAS FROZEN?
#
# The legacy-fixture harness of docs/CONTEST_OWNERSHIP_DESIGN.md (milestone M0),
# and the gate for M1 to M4: for every ContestType and every station variant it
# boots the contest headless (tr4w.exe <cfg> /MATRIX ...), records the set-up,
# the per-QSO scoring of a fixed synthetic QSO table and the real exporters'
# output, and byte-compares the result against tr4w/test/contest-matrix/frozen.
#
# ---------------------------------------------------------------------------
# WHAT IT SEES THAT THE OTHER ORACLES DO NOT
# ---------------------------------------------------------------------------
#   export-d12-corpus.sh    13 registered contests; blind to set-up, per-QSO
#                           points and every contest with no class
#   test-contest-factory.sh scoring, but over the same 13 logs
#   THIS                    EVERY ContestType, classless included, under four
#                           station variants: set-up (the seven Active*
#                           values, every setting contest set-up writes, the
#                           domestic countries, the county-line answer, the CW
#                           memories), per-QSO points and the fields scoring
#                           writes, and the Cabrillo CONTEST:/QSO: lines and
#                           ADIF records the real exporters produce, and
#                           what the ADIF import makes of those records and of
#                           synthetic foreign-logger ones
#
# It sees ADIF IMPORT (M5a): the records the export wrote, plus synthetic
# foreign-logger records, read back through the real import path.  It does NOT
# see PARSING a typed exchange yet -- the synthetic QSOs carry their exchange
# fields already filled.  That capture is M5b's, and is marked as an extension
# point in uContestMatrix.
#
# ---------------------------------------------------------------------------
# WHAT A GREEN RUN MEANS, AND WHAT IT DOES NOT
# ---------------------------------------------------------------------------
# THE FROZEN FILES ARE THIS PROGRAM'S OWN OUTPUT.  A green run says a change
# kept every contest doing what it did on the day of the freeze -- NOT that
# what it did was right.  Defects present that day are pinned exactly as
# faithfully as correct rules; that is the point of a strangler gate, and it is
# the same bargain test-contest-factory.sh makes with its frozen rescores.
#
# ---------------------------------------------------------------------------
# THIS SCRIPT NEVER WRITES THE FROZEN FILES
# ---------------------------------------------------------------------------
# A red run is a finding.  Find out WHY a record moved.  Only a rule that
# genuinely changed -- a sponsor changed it, or a defect was fixed on purpose --
# is a reason to re-freeze, and that is done with freeze-contest-matrix.sh,
# which demands the reason in writing.  NEVER RE-FREEZE TO CLEAR A RED RUN:
# that writes a regression into the oracle, and nothing downstream would ever
# notice.
#
# FAILS CLOSED: no contests captured, a frozen record with no fresh one, a fresh
# record with no frozen one, or any byte difference is a failure (exit 1).  A
# record that says RUN FAILED or RAISED passes only if it said so when frozen,
# and is LISTED on every run so it is never a quiet pass.
#
# Usage:   rebuild the app (Build-App.ps1), make sure TR4W is not running, then
#          bash tr4w/test/contest-matrix/run-contest-matrix.sh
set -u

. "$(dirname "${BASH_SOURCE[0]}")/matrix-lib.sh"

FRESH="$MATRIX_WORK/fresh"

if [ ! -d "$MATRIX_FROZEN" ] || ! ls "$MATRIX_FROZEN"/*.matrix >/dev/null 2>&1; then
   echo "contest-matrix: FAIL -- nothing is frozen in $MATRIX_FROZEN." >&2
   echo "                Freeze first with freeze-contest-matrix.sh --reason ..." >&2
   exit 1
fi

echo "contest matrix: running every contest against $MATRIX_EXE_SRC"
if ! matrix_run "$FRESH"; then
   echo "=== contest matrix: FAILED -- the run could not be done ==="
   exit 1
fi

if [ "${MATRIX_CAPTURED:-0}" -eq 0 ]; then
   echo "=== contest matrix: FAILED -- zero contests captured ==="
   exit 1
fi

same=0; differ=0; missing=0; unfrozen=0
failed=""

for f in "$MATRIX_FROZEN"/*.matrix; do
   name=$(basename "$f")
   if [ ! -f "$FRESH/$name" ]; then
      printf '  MISSING  %-28s (frozen, but this run produced no record)\n' "${name%.matrix}"
      missing=$((missing+1)); failed="$failed ${name%.matrix}"
   elif cmp -s "$f" "$FRESH/$name"; then
      same=$((same+1))
   else
      printf '  DIFF     %-28s\n' "${name%.matrix}"
      # THE FIRST FEW CHANGED LINES, to say what moved.  Display only -- cmp
      # above decided, byte for byte; --strip-trailing-cr keeps a line-ending
      # change from drowning the content change in this excerpt.
      diff --strip-trailing-cr "$f" "$FRESH/$name" | tr -d '\r' | head -8 | sed 's/^/           /'
      differ=$((differ+1)); failed="$failed ${name%.matrix}"
   fi
done

for f in "$FRESH"/*.matrix; do
   name=$(basename "$f")
   if [ ! -f "$MATRIX_FROZEN/$name" ]; then
      printf '  UNFROZEN %-28s (a contest this run found that was never frozen)\n' "${name%.matrix}"
      unfrozen=$((unfrozen+1)); failed="$failed ${name%.matrix}"
   fi
done

echo "=== contest matrix: $same identical, $differ differing, $missing missing, $unfrozen unfrozen ($MATRIX_CAPTURED contests run) ==="
matrix_report_failures "$FRESH"

if [ $((differ + missing + unfrozen)) -ne 0 ]; then
   echo "    failing:$failed"
   echo "    Full records: $FRESH  (frozen: $MATRIX_FROZEN)"
   exit 1
fi
exit 0
