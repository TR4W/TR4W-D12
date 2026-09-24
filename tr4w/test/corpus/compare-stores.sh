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
# BOTH RUNS FORCE THEIR STORE (/EXPORTTRW and /EXPORTDB) rather than letting
# one of them inherit the default.  Since B4 the default is the database, so a
# run that inherited it would compare the database against ITSELF and pass
# while proving nothing -- the exact failure this script exists to prevent.
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

# THE BINARY LOGS MOVED OUT OF THE CORPUS, 2026-09-24.
#
# The golden corpus's input is a log.db now, so the D7 .trw files it used to
# carry are unit fixtures -- six of the thirteen, kept because assertions in
# uTestLogBinaryFile / uTestLogImport / uTestLogRepository name them.  This
# script runs over those six.
#
# THAT IS SEVEN LOGS OF COVERAGE GIVEN UP, and it is stated rather than hidden:
# the binary store is import-only, so what is left to compare is a legacy read
# path, not the program's log.  The contest .cfg still comes from the corpus set
# of the same name -- it is the contest definition, and it never moved.
BINLOGS="$REPO_ROOT/tr4w/test/unit/fixtures/binarylog"

pass=0; fail=0; failed_names=""
for t in "$BINLOGS"/*.trw; do
   [ -f "$t" ] || continue
   name=$(basename "$t" .trw)
   d="$REPO_ROOT/tr4w/test/corpus/$name"
   [ -f "$d/log.cfg" ] || { echo "  MISS  $name (no log.cfg in the corpus set)"; continue; }

   rm -f "$WORK".* ./*.LOG
   cp "$d/log.cfg" "$WORK.CFG" || continue
   cp "$t" "$WORK.TRW" || continue

   # MSYS_NO_PATHCONV: stop Git Bash rewriting /IMPORTLOG and /EXPORT into paths.
   MSYS_NO_PATHCONV=1 timeout 60 "./$EXE" /IMPORTLOG "$WORK.TRW" "$WORK.db" >/dev/null 2>&1
   qsos=$(python -c "import sqlite3;print(sqlite3.connect('$WORK.db').execute('SELECT COUNT(*) FROM qso').fetchone()[0])" 2>/dev/null || echo '?')

   rm -f "$WORK.ADI" ./*.LOG
   MSYS_NO_PATHCONV=1 timeout 60 "./$EXE" "$WORK.CFG" /EXPORT /EXPORTTRW >/dev/null 2>&1
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
