#!/bin/bash
#
# THE RESCORE MUST BE IDEMPOTENT, AND NOTHING ELSE TESTS IT.
#
# tUpdateLog(actRescore) recomputes country, prefix, zone, multiplier flags,
# QSO points and dupe state for every QSO in the log.  Its only callers are
# interactive -- a menu action, an ADIF import, saving an edited QSO -- so the
# corpus and the unit tests never run it.  B5 rewrote it
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
. "$REPO_ROOT/tr4w/test/corpus/corpus-lib.sh"
cp "$EXE_SRC" "$EXE" || exit 1
corpus_cleanup_on_exit

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

# How many QSO rows carry an exchange id.  A RESCORE MUST NOT ADD ONE (NY4I,
# 2026-10-14, open question F6): it recomputes scoring, and an id is an
# identity.  It used to give a fresh GUID to every row without one, so the
# first rescore of every imported or migrated log rewrote every row -- 1,772
# rows across this corpus -- and a second rescore could not see it, because by
# then the ids were there.  So the count is compared across the FIRST rescore.
idcount() {
   python - "$WORK.db" <<'PY'
import sqlite3, sys
try:
   c = sqlite3.connect(sys.argv[1])
   print(c.execute("SELECT COUNT(*) FROM qso WHERE exchange_id IS NOT NULL "
                   "AND exchange_id <> ''").fetchone()[0])
except Exception as e:
   print('ERROR:%s' % e)
PY
}

fail=0
for d in "$REPO_ROOT"/tr4w/test/corpus/*/; do
   name=$(basename "$d")
   [ -f "$d/log.db" ] || continue

   # The corpus fixture IS the log since 2026-09-24, so there is no binary log
   # to migrate in first -- copy it and rescore it.
   rm -f "$WORK".*
   cp "$d/log.cfg" "$WORK.CFG" || continue
   cp "$d/log.db" "$WORK.db" || continue

   # THE .CFG IS NAMED, NOT THE .db.  Both open the same database, but naming
   # the .db makes LogCfg skip the text read -- and the DOMESTIC COUNTRY LIST
   # comes from that read, so a rescore would treat every callsign as DX.  See
   # the longer note in test-contest-factory.sh.
   ids_before=$(idcount)
   MSYS_NO_PATHCONV=1 timeout 60 "./$EXE" "$WORK.CFG" /RESCORE >/dev/null 2>&1
   first=$(digest)
   ids_after=$(idcount)
   MSYS_NO_PATHCONV=1 timeout 60 "./$EXE" "$WORK.CFG" /RESCORE >/dev/null 2>&1
   second=$(digest)

   if [ "$ids_before" != "$ids_after" ]; then
      printf "  MINT  %-28s exchange ids %s before the rescore, %s after\n" \
         "$name" "$ids_before" "$ids_after"
      fail=$((fail+1))
      continue
   fi

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

rm -f "$WORK".* "$EXE"

if [ $fail -ne 0 ]; then
   echo "=== test-rescore: $fail log(s) changed on a SECOND rescore, or had exchange ids MINTED by the first ==="
   exit 1
fi
echo "=== test-rescore: every log unchanged by a second rescore, and no exchange id minted ==="
exit 0
