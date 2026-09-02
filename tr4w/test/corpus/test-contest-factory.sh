#!/bin/bash
#
# DOES THE CONTEST FACTORY PRODUCE WHAT THE LEGACY CASE PRODUCED?
#
# For every corpus log: rescore and export through the FACTORY, then rescore and
# export through the LEGACY `case ActiveQSOPointMethod of`, and diff.  Same
# program, same CTY.DAT, same log -- only the dispatch differs, so any difference
# is the move.
#
# WHY THIS EXISTS RATHER THAN LEANING ON THE GOLDEN CORPUS.
#
#   THE CORPUS IS BLIND TO SCORING.  Measured, not assumed: changing ARRL DX
#   from 3 points a QSO to 7 leaves export-d12-corpus.sh at "24 passed, 0
#   failed".  /EXPORT reads the QSO points STORED IN THE LOG and never
#   recomputes them, so CalculateQSOPoints -- 3,264 lines dispatching on an
#   88-value enum -- has never had coverage of any kind.
#
#   AND COMPARING A RESCORE TO THE D7 REFERENCES IS TOO BLUNT TO BE A GATE.
#   7 of the 13 logs move when rescored, before any factory work: our CTY.DAT is
#   not the one D7 used, so country, zone and therefore points legitimately
#   differ.  That is worth investigating on its own (see below) and is useless as
#   a pass/fail for this.
#
# So the exact question is the A/B, and /NOFACTORY is in the program for no other
# reason.
#
# VERIFIED CAPABLE OF FAILING: with ARRL DX scoring 7 points instead of 3, this
# reports arrl_dx_cw as DIFF with CLAIMED-SCORE 12474 -> 29106.  The corpus, run
# on the same binary, reported 24 passed.
#
# SEPARATE FINDING, RECORDED HERE BECAUSE THIS IS WHERE IT WAS MEASURED: seven
# corpus logs score differently when recomputed than the values D7 stored in
# them -- arrl_dx_cw, arrl_ss_ssb, cqww_ssb, general_qso, iaru_hf, michigan_qp
# and winter_fd.  Some of that is a newer CTY.DAT and some may not be.  Nothing
# has ever compared the two before, so it is unexplored rather than accepted.
#
# Usage:  bash tr4w/test/corpus/test-contest-factory.sh
set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
TARGET="$REPO_ROOT/tr4w/target"
EXE_SRC="$REPO_ROOT/build-out/app-i386-win32/tr4w_fpc.exe"
EXE="factory-run.exe"
WORK="factorytest"

if [ ! -f "$EXE_SRC" ]; then
   echo "test-contest-factory: no app at $EXE_SRC -- build first" >&2
   exit 1
fi

cd "$TARGET" || exit 1
cp "$EXE_SRC" "$EXE" || exit 1

# Two things are generated fresh on every run BY DESIGN and must not be
# compared: the creation timestamp, and APP_TR4W_ID -- the per-QSO UUIDv7,
# minted when a QSO is imported, so re-importing the same .TRW twice gives
# different ids for the same contacts.  Nothing else is normalised: the whole
# value of this test is that everything else must match exactly.
norm() { sed -E 's/(Created by TR4W version .* on ).*/\1TIME/; s/(<CREATED_TIMESTAMP:15>).*/\1TIME/; s/<APP_TR4W_ID:32>[0-9a-f]*/<APP_TR4W_ID:32>ID/g' "$1" 2>/dev/null; }

# Rescore one way and export; leaves the artifacts in the working directory.
run_pass() {   # $1 = extra switch for /RESCORE ("" or /NOFACTORY)
   # THE .RST GOES TOO.  It is the restart file -- totals, band and mode
   # memories, carried between sessions -- so leaving it means the second pass
   # starts from the first pass's state and the comparison measures that
   # instead of the dispatch.  Four contests with NO factory class at all
   # reported differences until this line existed, which is what gave it away:
   # both passes were taking the identical legacy path.
   rm -f "$WORK.db" "$WORK.db-wal" "$WORK.db-shm" "$WORK.ADI" "$WORK.RST" ./*.LOG
   MSYS_NO_PATHCONV=1 timeout 60 "./$EXE" "$WORK.CFG" /EXPORT >/dev/null 2>&1
   MSYS_NO_PATHCONV=1 timeout 60 "./$EXE" "$WORK.CFG" /RESCORE $1 >/dev/null 2>&1
   rm -f "$WORK.ADI" ./*.LOG
   MSYS_NO_PATHCONV=1 timeout 60 "./$EXE" "$WORK.CFG" /EXPORT >/dev/null 2>&1
}

pass=0; fail=0; failed=""
for d in "$REPO_ROOT"/tr4w/test/corpus/*/; do
   name=$(basename "$d")
   [ -f "$d/log.trw" ] || continue

   rm -f "$WORK".* ./*.LOG
   cp "$d/log.cfg" "$WORK.CFG" || continue
   cp "$d/log.trw" "$WORK.TRW" || continue

   run_pass ""
   fac=$(mktemp -d); cp "$WORK.ADI" "$fac/" 2>/dev/null; cp ./*.LOG "$fac/" 2>/dev/null
   produced=$(ls "$fac" 2>/dev/null)

   cp "$d/log.trw" "$WORK.TRW"
   run_pass "/NOFACTORY"

   ok=1; detail=""
   if [ -z "$produced" ]; then
      ok=0; detail=" (the factory pass produced nothing)"
   fi
   for f in $produced; do
      if [ ! -f "$f" ]; then
         ok=0; detail="$detail $f(missing)"
      elif ! diff <(norm "$fac/$f") <(norm "$f") >/dev/null 2>&1; then
         ok=0
         a=$(grep -h '^CLAIMED-SCORE:' "$fac/$f" 2>/dev/null | head -1)
         b=$(grep -h '^CLAIMED-SCORE:' "$f" 2>/dev/null | head -1)
         if [ -n "$a" ] && [ "$a" != "$b" ]; then
            detail="$detail $f [factory $a vs legacy $b]"
         else
            detail="$detail $f"
         fi
      fi
   done
   rm -rf "$fac"

   if [ $ok -eq 1 ]; then
      printf "  SAME  %-28s\n" "$name"; pass=$((pass+1))
   else
      printf "  DIFF  %-28s -->%s\n" "$name" "$detail"; fail=$((fail+1)); failed="$failed $name"
   fi
done

rm -f "$WORK".* ./*.LOG "$EXE"

echo "=== factory vs legacy: $pass identical, $fail differing ==="
if [ $fail -ne 0 ]; then
   echo "    differing:$failed"
   exit 1
fi
exit 0
