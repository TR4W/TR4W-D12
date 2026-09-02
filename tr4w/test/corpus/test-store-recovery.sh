#!/bin/bash
#
# THE DATABASE MUST SURVIVE THE LOSS OF THE BINARY LOG.
#
# This exists because it once did not, and the failure was silent.  Move a .TRW
# aside and start TR4W: the program CREATES a fresh log -- 376 bytes, a header
# and no records -- because that is what it does for a new contest.  The shadow
# read "shadow holds 101, the log holds 0", called it drift, and rebuilt the
# database from the empty log.  101 QSOs became 0, in one startup, and the
# export that followed wrote an empty ADIF and returned success.
#
# The binary log is APPEND-ONLY: deletes mark a record rather than removing it,
# so its count can rise or hold but never fall.  A fall means the log was lost,
# truncated or recreated -- and NOTHING CAN TELL THOSE APART.  TLogHeader
# carries no identity: version string, description, warning, byte-identical in
# every TR4W log ever written.
#
# So the contract this asserts is not "the database wins".  Simply keeping it
# would RESURRECT a contest -- the county-line harness resets its log every run
# and inherited three QSOs from the run before.  The contract is:
#
#     the working database matches the binary log, and the QSOs that were in it
#     are still on disk, in a named orphan file, not deleted.
#
# Nothing destroyed, nothing silently carried into a contest it does not belong
# to, and a path in the log telling the operator where their QSOs went.
#
# Usage:  bash tr4w/test/corpus/test-store-recovery.sh
set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
TARGET="$REPO_ROOT/tr4w/target"
EXE_SRC="$REPO_ROOT/build-out/app-i386-win32/tr4w_fpc.exe"
EXE="storerec-run.exe"
WORK="storerec"
FIXTURE="$REPO_ROOT/tr4w/test/corpus/cqww_ssb_2025_ny4i"

if [ ! -f "$EXE_SRC" ]; then
   echo "test-store-recovery: no app at $EXE_SRC -- build first" >&2
   exit 1
fi

cd "$TARGET" || exit 1
cp "$EXE_SRC" "$EXE" || exit 1
rm -f "$WORK".* ./*.LOG
cp "$FIXTURE/log.cfg" "$WORK.CFG" || exit 1
cp "$FIXTURE/log.trw" "$WORK.TRW" || exit 1

rows() { python -c "import sqlite3,sys;print(sqlite3.connect(sys.argv[1]).execute('SELECT COUNT(*) FROM qso').fetchone()[0])" "$WORK.db" 2>/dev/null || echo 0; }
qsos() { grep -ci '<eor>' "$WORK.ADI" 2>/dev/null || echo 0; }

MSYS_NO_PATHCONV=1 timeout 60 "./$EXE" "$WORK.CFG" /EXPORT >/dev/null 2>&1
before_rows=$(rows); before_qsos=$(qsos)

# The loss.  Not a truncation -- the file simply is not there, which is what an
# operator sees after a bad copy, a wrong folder, or a restore that missed it.
rm -f "$WORK.ADI" ./*.LOG "$WORK.TRW"

MSYS_NO_PATHCONV=1 timeout 60 "./$EXE" "$WORK.CFG" /EXPORT >/dev/null 2>&1
after_rows=$(rows); after_qsos=$(qsos)

orphan=$(ls -1 "$WORK".db.orphaned-* 2>/dev/null | head -1)
orphan_rows=0
if [ -n "$orphan" ]; then
   orphan_rows=$(python -c "import sqlite3,sys;print(sqlite3.connect(sys.argv[1]).execute('SELECT COUNT(*) FROM qso').fetchone()[0])" "$orphan" 2>/dev/null || echo 0)
fi

echo "  with the binary log:   $before_rows row(s), $before_qsos QSO(s) exported"
echo "  after losing it:       $after_rows row(s) in the working log"
echo "  orphaned aside:        ${orphan:-<none>} holding $orphan_rows row(s)"

rm -f "$WORK".* "$WORK".db.orphaned-* ./*.LOG "$EXE"

if [ "$before_rows" -lt 1 ]; then
   echo "test-store-recovery: FAIL -- the fixture produced no rows to begin with; the test proves nothing"
   exit 1
fi
if [ -z "$orphan" ]; then
   echo "test-store-recovery: FAIL -- no orphan file: the QSOs were DESTROYED rather than moved aside"
   exit 1
fi
if [ "$orphan_rows" != "$before_rows" ]; then
   echo "test-store-recovery: FAIL -- the orphan holds $orphan_rows of $before_rows QSO(s); some were lost in the move"
   exit 1
fi
if [ "$after_rows" != "0" ]; then
   echo "test-store-recovery: FAIL -- the working log holds $after_rows row(s) against an empty binary log; a previous contest was resurrected"
   exit 1
fi
echo "test-store-recovery: PASS -- nothing destroyed ($orphan_rows QSOs preserved in the orphan) and nothing resurrected"
exit 0
