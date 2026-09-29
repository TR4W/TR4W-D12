#!/bin/bash
#
# FREEZE THE LEGACY RESCORE OUTPUT, so the contest factory keeps a scoring gate
# after the legacy `case` and /NOFACTORY are gone.
#
# ---------------------------------------------------------------------------
# WHY THIS EXISTS
# ---------------------------------------------------------------------------
# test-contest-factory.sh used to answer "does the factory produce what the
# legacy arm produced" by running the SAME rescore twice in one invocation --
# once each way, via /NOFACTORY -- and diffing the two.  That is an exact
# comparison and it was the right tool while both paths existed.
#
# IT HAS A DEATH DATE BUILT IN.  Every contest moved into the factory deletes a
# little more of the legacy arm, so the A/B gets weaker exactly as the work
# proceeds, and on the day the last contest moves it can no longer be run at
# all.  NY4I, 2026-09-29, ruling on that: "We should deprecate NOFACTORY."
#
# So the comparison is split in two.  This script runs the legacy pass ONCE and
# writes the bytes down; test-contest-factory.sh then rescores through the
# factory and diffs against them.  Same assertion, same sensitivity to a
# point-rule change -- and it survives the legacy path's deletion, which the
# live A/B cannot.
#
# ---------------------------------------------------------------------------
# WHAT THE FROZEN BYTES ARE, AND WHAT THEY ARE NOT
# ---------------------------------------------------------------------------
# THIS IS A SELF-BASELINE.  rescored.adi / rescored.cbr are OUR OWN output,
# recorded on the date below.  They assert:
#
#     the factory scores this log the way TR4W scored it before the move
#
# and they do NOT assert that either answer is CORRECT.  That is exactly what
# /NOFACTORY asserted, so nothing is lost in the trade -- but unlike ref.adi /
# ref.cbr, which are D7-produced and are the independent half of the golden
# corpus, these have no independent authority at all.  Do not cite them as one.
#
# NY4I, 2026-09-29: "We want to be able to use as much of what we have to
# validate but not get hung up on what we cannot do.  Just document that and we
# move on."  This block is that documentation.  The gap that stays open is
# whether the SCORING RULES are right, which no artifact in this tree answers;
# a real contest submission does.
#
# ---------------------------------------------------------------------------
# REGENERATING ONE, LATER
# ---------------------------------------------------------------------------
# After /NOFACTORY is deleted this script cannot reproduce a legacy pass, so a
# regenerated baseline is FACTORY output -- which makes that set's gate a
# tautology until someone confirms the new bytes are right.  So regeneration is
# a deliberate act with a reason attached, not a way to clear a red run:
#
#     a set goes red  ->  find out WHY.  A rule genuinely changed (a sponsor
#                         changed it, or a defect was fixed) is the only good
#                         reason to re-freeze, and the commit message says
#                         which, with the score before and after.
#
# A red set that is re-frozen without that is a scoring regression being
# written into the oracle, and nothing downstream would ever notice.
#
# Usage:  bash tr4w/test/corpus/freeze-rescore-baseline.sh [slug ...]
#         (no arguments freezes every set that has a log.db)
set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
CORPUS="$REPO_ROOT/tr4w/test/corpus"
TARGET="$REPO_ROOT/tr4w/target"
EXE_SRC="$REPO_ROOT/build-out/app-i386-win32/tr4w_fpc.exe"
EXE="freeze-run.exe"
WORK="freezetest"

. "$CORPUS/corpus-lib.sh"

if [ ! -f "$EXE_SRC" ]; then
   echo "freeze-rescore-baseline: no app at $EXE_SRC -- build first" >&2
   exit 1
fi

# A BASELINE IS ONLY WORTH FREEZING FROM A BUILD THAT MATCHES THE SOURCE.
# These bytes become the gate, so an incremental or stale binary would pin
# whatever it happened to contain.  The caller is expected to have run a FULL
# Build-App.ps1; this reports what it is freezing from so the commit can say.
echo "freezing from: $EXE_SRC"
echo "               $(date -u '+%Y-%m-%dT%H:%M:%SZ')"

cd "$TARGET" || exit 1
cp "$EXE_SRC" "$EXE" || exit 1

froze=0; skipped=0; failed=""

for d in "$CORPUS"/*/; do
   name=$(basename "$d")
   [ -f "$d/log.db" ] || continue

   # An explicit slug list narrows the run; no arguments means all of them.
   if [ $# -gt 0 ]; then
      want=0
      for s in "$@"; do
         [ "$s" = "$name" ] && want=1
      done
      [ $want -eq 1 ] || continue
   fi

   rm -f "$WORK".* ./*.LOG
   cp "$d/log.cfg" "$WORK.CFG" || { skipped=$((skipped+1)); continue; }
   cp "$d/log.db"  "$WORK.db"  || { skipped=$((skipped+1)); continue; }

   # THE .CFG IS NAMED, NOT THE .db, AND THAT IS DELIBERATE FOR A RESCORE.
   # Naming the .db makes LogCfg skip the text read, and the DOMESTIC COUNTRY
   # LIST comes from that read -- a rescore done that way logs "the domestic
   # country list is EMPTY, so every callsign will be treated as DX" and scores
   # a contest that has no domestic countries.  Freezing THAT would bake the
   # crippled answer into the gate permanently.
   MSYS_NO_PATHCONV=1 timeout 60 "./$EXE" "$WORK.CFG" /RESCORE /NOFACTORY >/dev/null 2>&1
   rm -f "$WORK.ADI" ./*.LOG
   MSYS_NO_PATHCONV=1 timeout 60 "./$EXE" "$WORK.CFG" /EXPORT >/dev/null 2>&1

   cbr=$(ls ./*.LOG 2>/dev/null | head -1)
   if [ ! -f "$WORK.ADI" ] || [ -z "$cbr" ]; then
      printf "  FAIL  %-28s (produced nothing)\n" "$name"
      failed="$failed $name"
      continue
   fi

   corpus_norm_artifact "$WORK.ADI" > "$d/rescored.adi" || { failed="$failed $name"; continue; }
   corpus_norm_artifact "$cbr"      > "$d/rescored.cbr" || { failed="$failed $name"; continue; }

   score=$(grep -h '^CLAIMED-SCORE:' "$d/rescored.cbr" 2>/dev/null | head -1)
   printf "  FROZE %-28s %s\n" "$name" "$score"
   froze=$((froze+1))
done

rm -f "$WORK".* ./*.LOG "$EXE"

echo "=== froze $froze set(s), skipped $skipped ==="
if [ -n "$failed" ]; then
   echo "    failed:$failed"
   exit 1
fi
exit 0
