#!/bin/bash
#
# THE DATABASE IS THE LOG, AND A STRAY .TRW CANNOT AFFECT IT.
#
# Since B5 the SQLite log is not derived from anything: it is opened, or created
# empty, and a binary log beside it is looked at ONCE -- when no database exists
# yet -- purely to migrate an existing contest in.  After that it is not
# consulted again, so deleting it, truncating it, or letting TR4W recreate an
# empty one has no effect on the QSOs.
#
# THIS TEST HAS ASSERTED THREE DIFFERENT CONTRACTS, WHICH IS THE POINT OF
# KEEPING IT.  While two live stores existed, something had to reconcile them on
# every open, and there was no right answer:
#
#   Rebuilding from the binary log DESTROYED a contest.  TR4W creates a fresh
#   376-byte header-only log when it finds none, the reconciler read "shadow 101,
#   log 0", called it drift, and rebuilt.  101 QSOs became 0 with an INFO line as
#   the only trace, and the export after it wrote an empty ADIF and returned
#   success.
#
#   Refusing to rebuild RESURRECTED one.  The county-line harness resets its log
#   every run and inherited three QSOs from the run before.
#
#   Moving the database aside preserved both -- and was still ceremony around a
#   question that only existed because there were two stores.
#
# There is one store now, so there is nothing to reconcile and none of those
# failures are reachable.  This asserts that: lose the binary log and the QSOs
# are simply still there.
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

echo "  with the binary log:   $before_rows row(s), $before_qsos QSO(s) exported"
echo "  after losing it:       $after_rows row(s), $after_qsos QSO(s) exported"

orphan=$(ls -1 "$WORK".db.orphaned-* 2>/dev/null | head -1)
rm -f "$WORK".* "$WORK".db.orphaned-* ./*.LOG "$EXE"

if [ "$before_rows" -lt 1 ]; then
   echo "test-store-recovery: FAIL -- the fixture produced no rows to begin with; the test proves nothing"
   exit 1
fi
if [ -n "$orphan" ]; then
   # An orphan means something still reconciled the two stores.  That machinery
   # was removed with the second store; if it is back, so are its failures.
   echo "test-store-recovery: FAIL -- an orphan file appeared ($orphan). Nothing should be reconciling stores any more."
   exit 1
fi
if [ "$after_rows" != "$before_rows" ] || [ "$after_qsos" != "$before_qsos" ]; then
   echo "test-store-recovery: FAIL -- losing the binary log changed the SQLite log ($before_rows -> $after_rows rows, $before_qsos -> $after_qsos exported). It is not supposed to be consulted at all."
   exit 1
fi
echo "test-store-recovery: PASS -- the binary log was deleted and all $after_rows QSO(s) are still logged and still export"
exit 0
