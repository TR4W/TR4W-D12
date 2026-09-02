#!/bin/bash
#
# B3 -- THE EQUIVALENCE GATE: does the store change the exported bytes?
#
# For each corpus log: import the .TRW into SQLite, export ADIF + Cabrillo from
# EACH store, and diff the two outputs against each other.
#
# THIS IS NOT export-d12-corpus.sh AND DOES NOT REPLACE IT. That script compares
# our output against the FROZEN D7 REFERENCES, which were written by a different
# program, and that independence is the whole value of the oracle. This one asks
# the narrower question the migration turns on:
#
#     changing ONLY the source of the QSOs, do the bytes change?
#
# Both are needed. The corpus says the exporter is right; this says the database
# is a faithful stand-in for the binary log. Neither implies the other: an
# exporter broken the same way from both stores would pass this and fail the
# corpus, and a store that lost a field the references happen not to exercise
# would pass the corpus and fail this.
#
# Usage:  bash tr4w/test/corpus/compare-stores.sh
#
# Requires a built app.  Guard that TR4W is not running -- a live instance
# collides on target/ and every log reports a false difference.
set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
TARGET="$REPO_ROOT/tr4w/target"
EXE_SRC="$REPO_ROOT/build-out/app-i386-win32/tr4w_fpc.exe"
# THE EXE NAME MUST NOT SHARE THE WORK PREFIX. It did -- "cmpstores.exe" and
# WORK="cmpstores" -- so the loop's own `rm -f "$WORK".*` deleted the
# executable on the first iteration and every log then reported a difference.
EXE="cmpstores-run.exe"
WORK="cmpstores"

if [ ! -f "$EXE_SRC" ]; then
   echo "compare-stores: no app at $EXE_SRC -- build first" >&2
   exit 1
fi

cd "$TARGET" || exit 1
cp "$EXE_SRC" "$EXE" || exit 1

# The creation timestamp is Now() and differs between two runs BY DESIGN.  It is
# the only normalisation, and it is deliberately narrow: normalising anything
# else would be hiding exactly what this script exists to find.
norm() { sed -E 's/(Created by TR4W version .* on ).*/\1TIME/; s/(<CREATED_TIMESTAMP:15>).*/\1TIME/' "$1" 2>/dev/null; }

pass=0; fail=0; failed_names=""
for d in "$REPO_ROOT"/tr4w/test/corpus/*/; do
   name=$(basename "$d")
   [ -f "$d/log.trw" ] || continue

   rm -f "$WORK".* ./*.LOG
   cp "$d/log.cfg" "$WORK.CFG" || continue
   cp "$d/log.trw" "$WORK.TRW" || continue

   # MSYS_NO_PATHCONV: stop Git Bash rewriting /IMPORTLOG and /EXPORT into paths.
   MSYS_NO_PATHCONV=1 timeout 60 "./$EXE" /IMPORTLOG "$WORK.TRW" "$WORK.db" >/dev/null 2>&1
   qsos=$(python -c "import sqlite3;print(sqlite3.connect('$WORK.db').execute('SELECT COUNT(*) FROM qso').fetchone()[0])" 2>/dev/null || echo '?')

   rm -f "$WORK.ADI" ./*.LOG
   MSYS_NO_PATHCONV=1 timeout 60 "./$EXE" "$WORK.CFG" /EXPORT >/dev/null 2>&1
   binout=$(mktemp -d); cp "$WORK.ADI" "$binout/" 2>/dev/null; cp ./*.LOG "$binout/" 2>/dev/null

   rm -f "$WORK.ADI" ./*.LOG
   MSYS_NO_PATHCONV=1 timeout 60 "./$EXE" "$WORK.CFG" /EXPORT /EXPORTDB >/dev/null 2>&1

   ok=1; detail=""
   produced=$(ls "$binout" 2>/dev/null)
   if [ -z "$produced" ]; then
      # A log that exported NOTHING from the binary store would compare equal to
      # a database that exported nothing, and pass while proving nothing.
      ok=0; detail=" (the binary export produced no artifacts)"
   fi
   for f in $produced; do
      if ! diff <(norm "$binout/$f") <(norm "$f") >/dev/null 2>&1; then
         ok=0; detail="$detail $f"
      fi
   done
   rm -rf "$binout"

   if [ $ok -eq 1 ]; then
      printf "  SAME  %-28s %5s QSOs\n" "$name" "$qsos"; pass=$((pass+1))
   else
      printf "  DIFF  %-28s %5s QSOs -->%s\n" "$name" "$qsos" "$detail"
      fail=$((fail+1)); failed_names="$failed_names $name"
   fi
done

rm -f "$WORK".* ./*.LOG "$EXE"

echo "=== binary vs database: $pass identical, $fail differing ==="
if [ $fail -ne 0 ]; then
   echo "    differing:$failed_names"
   exit 1
fi
exit 0
