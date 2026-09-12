#!/bin/bash
#
# THE ADIF IMPORT, AGAINST THE THIRTEEN FROZEN D7 REFERENCES.
#
# NY4I, 2026-09-12, on converting an existing log: *"it would be much easier to
# have the D7 version of TR4W just export the contest then have the new program
# user import the adif file.  That would handle the conversion case ... plus it
# allows us to validate our import works properly.  You can even use the adif
# files from the corpus and import them as part of the corpus."*
#
# This is that.  For each set it makes a FRESH contest -- the .CFG and nothing
# else, no .TRW -- imports the set's ref.adi, exports, and compares the QSO
# records against the file it imported.
#
# ---------------------------------------------------------------------------
# WHY THIS IS A SECOND SCRIPT AND NOT A STAGE IN export-d12-corpus.sh
# ---------------------------------------------------------------------------
#
# The golden corpus proves the EXPORT: D7-written .TRW in, our artifacts out,
# byte-compared against D7's.  Its value is that its inputs are files we did not
# produce, and folding a second question into it would put our own output on the
# input side of the oracle.  So the export oracle is left exactly as it is and
# this asks the other half -- given our own export, does our import put it back?
#
# ---------------------------------------------------------------------------
# WHAT IS COMPARED, AND WHAT IS NOT
# ---------------------------------------------------------------------------
#
# THE QSO RECORDS ONLY.  The ADIF header carries the program name, its version
# and the moment the file was written, so three of its seven lines differ by
# construction -- ours says TR4W 5.x today, the reference says 4.149.0 in July.
# Comparing them would be comparing the clock.  Everything from the first record
# on is compared verbatim.
#
# A DIFFERENCE HERE IS AN IMPORT DEFECT, and the first run of this found one:
# the exporter PREPENDS the received RST to SRX_STRING to make it symmetric with
# STX_STRING, nothing took it off on the way back, and NY4I's IARU QSOs came
# back carrying a QTH of "59 8" -- the RST and the zone, stored as though they
# were a location.  Invisible until something re-exported what the import wrote.
#
# ---------------------------------------------------------------------------
# THE TWO THINGS THAT ARE NORMALIZED, AND WHY NEITHER IS A BLIND SPOT
# ---------------------------------------------------------------------------
#
# APP_TR4W_ID.  A QSO's identity is minted when the record is created, so a
# record arriving from a program that never wrote one LEAVES the import with an
# id it did not arrive with.  That is the import working, not failing.  It is
# removed from BOTH sides -- and only when the reference has none at all, so a
# reference that DOES carry ids is still compared on them.
#
# A PER-SET TAG LIST, for divergences that are already tracked elsewhere.  Each
# entry names the tag and the reason.  The tag is removed from both files and
# EVERYTHING ELSE STILL HAS TO MATCH EXACTLY -- so the set keeps its value as a
# regression test and a new difference in it still fails.  Adding a tag here is
# a decision; the reason goes beside it.
#
# Usage:  bash tr4w/test/corpus/test-adif-roundtrip.sh [slug]
set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
TARGET="$REPO_ROOT/tr4w/target"
CORPUS="$REPO_ROOT/tr4w/test/corpus"
EXE_SRC="$REPO_ROOT/build-out/app-i386-win32/tr4w_fpc.exe"
EXE="roundtrip-run.exe"
WORK="rtriptest"
ONLY="${1:-}"

# The corpus's own settings fixture, for the same reason the export uses it: a
# test whose result depends on the developer's configuration is not a test.
SETTINGS="$CORPUS/settings/tr4w.json"

if [ ! -f "$EXE_SRC" ]; then
   echo "test-adif-roundtrip: no app at $EXE_SRC -- build first" >&2
   exit 1
fi
if [ ! -f "$SETTINGS" ]; then
   echo "test-adif-roundtrip: no settings fixture at $SETTINGS" >&2
   exit 1
fi

cd "$TARGET" || exit 1
cp "$EXE_SRC" "$EXE" || exit 1
SETTINGS_WIN="$(cygpath -d "$SETTINGS")"

# Everything from the first ADIF record onward.  <EOH> ends the header, and a
# reference with no header at all still works: nothing matches, nothing is cut.
records_only() {
   awk 'seen { print } /<[Ee][Oo][Hh]>/ { seen = 1 }' "$1"
}

# The tags whose difference is already understood, per set.  See the header.
ignored_tags_for() {
   case "$1" in
      # The sent exchange is rebuilt from MY-station globals at export time
      # rather than stored per QSO, and /EXPORT does not apply them -- so MY
      # NAME is empty and D7's "59 TOM" comes back as "59".  That is TR4W-D12
      # issue #2, it is asserted by known-divergences.txt for the golden
      # corpus too, and it is an EXPORT fault: the import stored what it read.
      general_qso_2026_w1aw4) echo "STX_STRING" ;;

      # D7 stamped this log ALRS-UA1DZ-CUP while its own .CFG says WINTER FIELD
      # DAY -- a .TRW written under an older ContestType layout, whose ordinal
      # maps to a different contest now (uLogStore.pas, 2026-09-03).  A fresh
      # contest built from the .CFG is correctly WFD, so the two files disagree
      # about the contest for a reason that has nothing to do with the import.
      #
      # THE OTHER THREE FOLLOW FROM THAT ONE, and are the same fact three more
      # times: a section contest resolves the received section and writes DXCC,
      # STATE and ARRL_SECT beside the QTH, and ALRS-UA1DZ-CUP is not one, so
      # the D7 file has none of them.  That our WFD export writes all three is
      # CORRECT and is proven by arrl_fd_2026_ny4i, whose D7 reference carries
      # exactly those fields and which round-trips byte for byte.
      #
      # The section itself is NOT ignored -- <QTH> is compared on all 1316
      # records, which is what caught the import erasing it.
      winter_fd_2025_w4ta) echo "CONTEST_ID DXCC STATE ARRL_SECT" ;;

      *) echo "" ;;
   esac
}

# Delete whole ADIF fields by name.  An ADIF value cannot contain '<', which is
# what makes the value pattern safe.
strip_tags() {
   local expr='' t
   for t in $1; do
      expr="$expr s/<$t:[0-9]*>[^<]*//Ig;"
   done
   if [ -z "$expr" ]; then
      cat
   else
      sed "$expr"
   fi
}

pass=0; fail=0; skip=0
for d in "$CORPUS"/*/; do
   name=$(basename "$d")
   [ -n "$ONLY" ] && [ "$ONLY" != "$name" ] && continue
   [ -f "$d/ref.adi" ] || continue
   [ -f "$d/log.cfg" ] || continue

   # A FRESH CONTEST WITH NO BINARY LOG -- which is what a converted contest is,
   # and what made the import refuse before /IMPORT stopped requiring one.
   rm -f "$WORK".* ./*.LOG
   cp "$d/log.cfg" "$WORK.CFG" || continue

   MSYS_NO_PATHCONV=1 timeout 60 "./$EXE" "$WORK.CFG" /IMPORT "$(cygpath -d "$d/ref.adi")" \
      --settings "$SETTINGS_WIN" >/dev/null 2>&1
   rc=$?
   if [ "$rc" -ne 0 ]; then
      printf "  FAIL  %-28s import exited %s\n" "$name" "$rc"
      fail=$((fail+1)); continue
   fi

   MSYS_NO_PATHCONV=1 timeout 60 "./$EXE" "$WORK.CFG" /EXPORT \
      --settings "$SETTINGS_WIN" >/dev/null 2>&1
   rc=$?
   if [ "$rc" -ne 0 ]; then
      printf "  FAIL  %-28s export exited %s\n" "$name" "$rc"
      fail=$((fail+1)); continue
   fi

   out=$(ls "$WORK".ADI "$WORK".adi 2>/dev/null | head -1)
   if [ -z "$out" ]; then
      printf "  FAIL  %-28s the export wrote no ADIF\n" "$name"
      fail=$((fail+1)); continue
   fi

   drop=$(ignored_tags_for "$name")
   note=""
   if [ -n "$drop" ]; then
      note=" (ignoring $drop)"
   fi

   # A minted identity is only ignored where the reference has none to compare.
   if ! grep -qi '<app_tr4w_id:' "$d/ref.adi"; then
      drop="$drop APP_TR4W_ID"
   fi

   records_only "$out"       | strip_tags "$drop" > "$WORK.cand.txt"
   records_only "$d/ref.adi" | strip_tags "$drop" > "$WORK.ref.txt"

   if diff -q "$WORK.cand.txt" "$WORK.ref.txt" >/dev/null 2>&1; then
      n=$(grep -ci '<eor>' "$WORK.ref.txt")
      printf "  PASS  %-28s %s record(s)%s\n" "$name" "$n" "$note"
      pass=$((pass+1))
   else
      printf "  FAIL  %-28s records differ:\n" "$name"
      diff "$WORK.cand.txt" "$WORK.ref.txt" | head -6 | sed 's/^/          /'
      fail=$((fail+1))
   fi
done

rm -f "$WORK".* ./*.LOG "$EXE"

echo
echo "=== $pass passed, $fail failed, $skip skipped ==="
[ "$fail" -eq 0 ] || exit 1
