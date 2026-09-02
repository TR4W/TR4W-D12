#!/bin/bash
#
# THE RESCORE MUST BE IDEMPOTENT, AND NOTHING ELSE TESTS IT.
#
# tUpdateLog(actRescore) recomputes country, prefix, zone, multiplier flags,
# QSO points and dupe state for every QSO in the log.  Its only callers are
# interactive -- a menu action, an ADIF import, saving an edited QSO -- so the
# corpus, compare-stores and the unit tests never run it.  B5 rewrote it
# completely: it used to memory-map the .TRW PAGE_READWRITE and mutate records
# where they lay, and it now reads rows, recomputes, and writes back the ones
# that changed.
#
# Running it TWICE must leave the log identical the second time: the second pass
# recomputes the same values from the same QSOs.  The memory map had that
# property for free; the row version has to earn it, and asserting it exercises
# the whole loop -- the read at every index, the change detection, and the
# write-back.  A loop that wrote every row unconditionally would still pass a
# "did it crash" test and fail this one only if it corrupted something; a loop
# that read the WRONG row would fail it immediately.
#
# The first pass is allowed to change things.  These are D7-written logs and our
# CTY.DAT is not theirs, so recomputing legitimately moves values.  What must not
# move is the second pass.
#
# Usage:  bash tr4w/test/corpus/test-rescore.sh
set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
TARGET="$REPO_ROOT/tr4w/target"
EXE_SRC="$REPO_ROOT/build-out/app-i386-win32/tr4w_fpc.exe"
EXE="rescore-run.exe"
WORK="rescoretest"

if [ ! -f "$EXE_SRC" ]; then
   echo "test-rescore: no app at $EXE_SRC -- build first" >&2
   exit 1
fi

cd "$TARGET" || exit 1
cp "$EXE_SRC" "$EXE" || exit 1

# Every QSO row, ordered, hashed -- the whole log's content in one value.
digest() {
   python - "$WORK.db" <<'PY'
import sqlite3, sys, hashlib
try:
   c = sqlite3.connect(sys.argv[1])
   cols = [d[1] for d in c.execute('PRAGMA table_info(qso)')]
   rows = c.execute('SELECT ' + ','.join(cols) + ' FROM qso ORDER BY id').fetchall()
except Exception as e:
   print('ERROR:%s' % e)
   sys.exit(0)
h = hashlib.sha256()
for r in rows:
   h.update(repr(r).encode('utf-8'))
print('%d:%s' % (len(rows), h.hexdigest()[:16]))
PY
}

fail=0
for d in "$REPO_ROOT"/tr4w/test/corpus/*/; do
   name=$(basename "$d")
   [ -f "$d/log.trw" ] || continue

   rm -f "$WORK".* ./*.LOG
   cp "$d/log.cfg" "$WORK.CFG" || continue
   cp "$d/log.trw" "$WORK.TRW" || continue

   # Migrate the binary log in, so there is something to rescore.
   MSYS_NO_PATHCONV=1 timeout 60 "./$EXE" "$WORK.CFG" /EXPORT >/dev/null 2>&1

   MSYS_NO_PATHCONV=1 timeout 60 "./$EXE" "$WORK.CFG" /RESCORE >/dev/null 2>&1
   first=$(digest)
   MSYS_NO_PATHCONV=1 timeout 60 "./$EXE" "$WORK.CFG" /RESCORE >/dev/null 2>&1
   second=$(digest)

   case "$first" in
      ERROR:*|0:*)
         printf "  FAIL  %-28s no rows after the first rescore (%s)\n" "$name" "$first"
         fail=$((fail+1))
         continue
         ;;
   esac

   if [ "$first" = "$second" ]; then
      printf "  SAME  %-28s %s\n" "$name" "$first"
   else
      printf "  DIFF  %-28s %s -> %s\n" "$name" "$first" "$second"
      fail=$((fail+1))
   fi
done

rm -f "$WORK".* ./*.LOG "$EXE"

if [ $fail -ne 0 ]; then
   echo "=== test-rescore: $fail log(s) changed on a SECOND rescore -- it is not idempotent ==="
   exit 1
fi
echo "=== test-rescore: every log unchanged by a second rescore ==="
exit 0
