#!/bin/bash
#
# DOES THE CONTEST FACTORY SCORE EACH LOG THE WAY TR4W SCORED IT BEFORE?
#
# For every corpus log: rescore and export through the FACTORY, and diff against
# the frozen legacy output in that set's rescored.adi / rescored.cbr.
#
# WHY THIS EXISTS RATHER THAN LEANING ON THE GOLDEN CORPUS.
#
#   THE CORPUS IS BLIND TO SCORING.  Measured, not assumed: changing ARRL DX
#   from 3 points a QSO to 7 leaves export-d12-corpus.sh at "24 passed, 0
#   failed".  /EXPORT sums the QSO points STORED IN THE LOG and never
#   recomputes them -- TotalQSOPoints := TotalQSOPoints + RXData.QSOPoints
#   (logsubs2.pas) -- so CalculateQSOPoints, dispatching on an 88-value enum,
#   has never had coverage of any kind from that direction.
#
#   THE CLAIMED-SCORE LINE IN ref.cbr DOES NOT CHANGE THAT, and it reads as
#   though it should, so it is worth saying plainly: the corpus does byte-diff
#   it, but it is arithmetic over stored points, so a changed scoring RULE does
#   not move it.  That misreading was made and corrected on 2026-09-29.
#
#   AND COMPARING A RESCORE TO THE D7 REFERENCES IS TOO BLUNT TO BE A GATE.
#   Logs legitimately move when rescored, before any factory work: our CTY.DAT
#   is not the one D7 used, so country, zone and therefore points differ.
#   Measured 2026-09-29 while freezing the baseline: iaru_hf alone moves on the
#   TOTAL, 12 -> 16, and seven sets move in their records.  That is worth
#   investigating on its own and is useless as a pass/fail for this.
#
# ---------------------------------------------------------------------------
# WHY THE LEGACY SIDE IS FROZEN RATHER THAN RUN
# ---------------------------------------------------------------------------
# This used to run the same rescore TWICE in one invocation, once through the
# legacy `case` via /NOFACTORY, and diff the two.  That had a death date built
# in: every contest moved into the factory deletes more of the legacy arm, so
# the A/B weakened exactly as the work proceeded and would be unrunnable on the
# day the last contest moved.  NY4I, 2026-09-29: "We should deprecate
# NOFACTORY."
#
# So the legacy pass was run once and written down -- see
# freeze-rescore-baseline.sh, which also records what those bytes do and do not
# assert.  In short: they are OUR OWN former output, so this gate says the
# factory agrees with what TR4W did before the move, and says nothing about
# whether either answer is correct.  That is precisely what /NOFACTORY said.
#
# VERIFIED CAPABLE OF FAILING: with ARRL DX scoring 7 points instead of 3, the
# A/B form of this test reported arrl_dx_cw as DIFF with CLAIMED-SCORE
# 12474 -> 29106, while the corpus on the same binary reported 24 passed.  The
# frozen form compares the same bytes, so it fails on the same change.
#
# A SET WITH NO FROZEN BASELINE IS A FAILURE, NOT A SKIP.  A gate that quietly
# passes the sets it cannot check is worse than no gate: freeze it first.
#
# Usage:  bash tr4w/test/corpus/test-contest-factory.sh
set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
CORPUS="$REPO_ROOT/tr4w/test/corpus"
TARGET="$REPO_ROOT/tr4w/target"
EXE_SRC="$REPO_ROOT/build-out/app-i386-win32/tr4w_fpc.exe"
EXE="factory-run.exe"
WORK="factorytest"

. "$CORPUS/corpus-lib.sh"

if [ ! -f "$EXE_SRC" ]; then
   echo "test-contest-factory: no app at $EXE_SRC -- build first" >&2
   exit 1
fi

cd "$TARGET" || exit 1
cp "$EXE_SRC" "$EXE" || exit 1

pass=0; fail=0; failed=""
for d in "$CORPUS"/*/; do
   name=$(basename "$d")
   [ -f "$d/log.db" ] || continue

   if [ ! -f "$d/rescored.adi" ] || [ ! -f "$d/rescored.cbr" ]; then
      printf "  DIFF  %-28s --> no frozen baseline (run freeze-rescore-baseline.sh)\n" "$name"
      fail=$((fail+1)); failed="$failed $name"
      continue
   fi

   # THE .RST GOES TOO.  It is the restart file -- totals, band and mode
   # memories, carried between sessions -- so leaving one behind means this run
   # starts from the previous set's state and the comparison measures that
   # instead of the scoring.
   rm -f "$WORK".* ./*.LOG
   cp "$d/log.cfg" "$WORK.CFG" || continue
   # A FRESH COPY OF THE FIXTURE: /RESCORE writes back into the database it is
   # given, so the run must start from the untouched tracked log.
   cp "$d/log.db"  "$WORK.db"  || continue

   # THE .CFG IS NAMED, NOT THE .db, AND THAT IS DELIBERATE FOR A RESCORE.
   #
   # Both open the same database -- every other name is derived from the stem --
   # but naming the .db makes LogCfg skip the text read, and the DOMESTIC
   # COUNTRY LIST comes from that read.  Measured while making this change:
   # with the .db named, every /RESCORE logged "[Domestic] The domestic country
   # list is EMPTY, so every callsign will be treated as DX".  The old A/B still
   # agreed -- both arms were equally crippled -- so it reported 13 identical
   # while rescoring a contest that had no domestic countries.  A gate that
   # passes because both sides are wrong is the failure mode this file exists to
   # avoid, and freeze-rescore-baseline.sh names the .CFG for the same reason.
   #
   # The golden corpus is NOT affected and is right to name the .db: /EXPORT
   # reads stored values and never rescores.
   MSYS_NO_PATHCONV=1 timeout 60 "./$EXE" "$WORK.CFG" /RESCORE >/dev/null 2>&1
   rm -f "$WORK.ADI" ./*.LOG
   MSYS_NO_PATHCONV=1 timeout 60 "./$EXE" "$WORK.CFG" /EXPORT >/dev/null 2>&1

   cbr=$(ls ./*.LOG 2>/dev/null | head -1)
   ok=1; detail=""

   if [ ! -f "$WORK.ADI" ]; then
      ok=0; detail=" (the factory pass produced no ADIF)"
   elif ! diff <(corpus_norm_artifact "$WORK.ADI") "$d/rescored.adi" >/dev/null 2>&1; then
      ok=0; detail="$detail rescored.adi"
   fi

   if [ -z "$cbr" ]; then
      ok=0; detail="$detail (the factory pass produced no Cabrillo)"
   elif ! diff <(corpus_norm_artifact "$cbr") "$d/rescored.cbr" >/dev/null 2>&1; then
      ok=0
      a=$(corpus_norm_artifact "$cbr" | grep '^CLAIMED-SCORE:' | head -1)
      b=$(grep '^CLAIMED-SCORE:' "$d/rescored.cbr" 2>/dev/null | head -1)
      if [ -n "$a" ] && [ "$a" != "$b" ]; then
         detail="$detail rescored.cbr [factory $a vs frozen $b]"
      else
         detail="$detail rescored.cbr"
      fi
   fi

   if [ $ok -eq 1 ]; then
      printf "  SAME  %-28s\n" "$name"; pass=$((pass+1))
   else
      printf "  DIFF  %-28s -->%s\n" "$name" "$detail"; fail=$((fail+1)); failed="$failed $name"
   fi
done

rm -f "$WORK".* ./*.LOG "$EXE"

echo "=== factory vs frozen legacy: $pass identical, $fail differing ==="
if [ $fail -ne 0 ]; then
   echo "    differing:$failed"
   exit 1
fi
exit 0
