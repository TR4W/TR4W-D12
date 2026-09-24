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
   # A FRESH COPY OF THE FIXTURE.  The log IS the input since 2026-09-24, so
   # the pass starts from the untouched database instead of rebuilding one from
   # a .TRW -- and the line above, which used to delete a DERIVED file, now
   # deletes the thing under test.  Without this the export produced nothing
   # and all 13 sets reported DIFF.
   cp "$SRC_DB" "$WORK.db" || return 1
   # THE .CFG IS NAMED, NOT THE .db, AND THAT IS DELIBERATE FOR A RESCORE.
   #
   # Both open the same database -- every other name is derived from the stem --
   # but naming the .db makes LogCfg skip the text read, and the DOMESTIC
   # COUNTRY LIST comes from that read.  Measured while making this change:
   # with the .db named, every /RESCORE logged "[Domestic] The domestic country
   # list is EMPTY, so every callsign will be treated as DX".  The A/B still
   # agreed -- both arms were equally crippled -- so it reported 13 identical
   # while rescoring a contest that had no domestic countries.  A gate that
   # passes because both sides are wrong is the failure mode this whole file
   # exists to avoid.
   #
   # The golden corpus is NOT affected and is right to name the .db: /EXPORT
   # reads stored values and never rescores.
   MSYS_NO_PATHCONV=1 timeout 60 "./$EXE" "$WORK.CFG" /RESCORE $1 >/dev/null 2>&1
   rm -f "$WORK.ADI" ./*.LOG
   MSYS_NO_PATHCONV=1 timeout 60 "./$EXE" "$WORK.CFG" /EXPORT >/dev/null 2>&1
}

pass=0; fail=0; failed=""
for d in "$REPO_ROOT"/tr4w/test/corpus/*/; do
   name=$(basename "$d")
   [ -f "$d/log.db" ] || continue

   # EACH PASS STARTS FROM THE SAME LOG -- run_pass takes a fresh copy, because
   # /RESCORE writes back into the database it is given.  (This used to stage a
   # .cfg and a .trw and let a first /EXPORT migrate them in; the corpus fixture
   # is the log itself since 2026-09-24, so there is nothing to migrate and that
   # extra export is gone with it.)
   SRC_DB="$d/log.db"
   rm -f "$WORK".* ./*.LOG
   cp "$d/log.cfg" "$WORK.CFG" || continue

   run_pass ""
   fac=$(mktemp -d); cp "$WORK.ADI" "$fac/" 2>/dev/null; cp ./*.LOG "$fac/" 2>/dev/null
   produced=$(ls "$fac" 2>/dev/null)

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
