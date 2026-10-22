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
. "$CORPUS/corpus-lib.sh"
cp "$EXE_SRC" "$EXE" || exit 1
corpus_logs_snapshot
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

      # NARROWED 2026-09-14, FROM "CONTEST_ID DXCC STATE ARRL_SECT" TO ONE TAG.
      #
      # The old list existed because D7 stamped this log ALRS-UA1DZ-CUP while
      # its own .CFG said WINTER FIELD DAY -- a .TRW written under an older
      # ContestType layout, whose ordinal maps to a different contest now.  A
      # section contest writes DXCC, STATE and ARRL_SECT beside the QTH and an
      # ALRS-UA1DZ-CUP QSO does not, so all four tags differed from one cause.
      #
      # NY4I ruled on that (2026-09-14): ref.adi is re-frozen from the WFD
      # candidate -- see known-divergences.txt, which keeps the reasoning and
      # the cost.  CONTEST_ID, STATE and ARRL_SECT now MATCH and are compared.
      #
      # DXCC STAYS, FOR A DIFFERENT AND UNDIAGNOSED REASON, and emptying the
      # list is how it surfaced.  Exactly ONE record of 1316 differs:
      #
      #   ref   ... <CALL:3>W4I ... <QTH:2>PR ... <DXCC:3>291 <ARRL_SECT:2>PR
      #   cand  ... <CALL:3>W4I ... <QTH:2>PR ...              <ARRL_SECT:2>PR
      #
      # A direct export from the .TRW emits DXCC 291; the same record exported
      # again AFTER an ADIF import does not.  PostUnit gates that field on
      # rec.QTH.CountryID = 'K' (postunit.pas:2396), so the country resolved
      # differently on the way back in -- for this one callsign, while the
      # other 1315 are unaffected.  W4I is NOT a CTY.DAT exception (checked),
      # so why it alone changes is NOT established and is deliberately not
      # guessed at here.  Do not 'fix' this by widening the ignore list.
      winter_fd_2025_w4ta) echo "DXCC" ;;

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

# A KNOWN DIFFERENCE PINNED LINE FOR LINE -- <set>/known.adi.diff, the SAME
# file and the SAME meaning as run-golden-diff.sh, through the one shared
# implementation (known-pin-lib.sh). The round trip imports ref.adi and
# exports it, so where our export is ruled to differ from D7's (michigan's
# four out-of-state STATE lines, Q76) it differs here in the same lines.
#
# TWO THINGS ARE HANDLED EXPLICITLY. This script compares a NORMALISED view
# (records only; per-set tags and, where the reference has none,
# APP_TR4W_ID removed from both sides), so the same normaliser is applied to
# the pinned lines before matching -- pin_matches' filter. And its own diff
# runs candidate-first for the failure listing; the pin is matched against a
# reference-first unified diff, the orientation the pin is written in.
. "$CORPUS/known-pin-lib.sh"

pass=0; fail=0; skip=0; known=0

# ONE ROUND TRIP: a fresh contest from $d's .CFG, $3 imported into it, the
# log exported, and the records compared with $3. $1 is the label printed;
# $2 the set's directory (its .CFG, its pin); $3 the ADIF file to import.
roundtrip_one() {
   local name="$1" d="$2" input="$3"
   local rc out drop note pin n

   # A FRESH CONTEST WITH NO BINARY LOG -- which is what a converted contest is,
   # and what made the import refuse before /IMPORT stopped requiring one.
   rm -f "$WORK".*; corpus_remove_new_logs
   cp "$d/log.cfg" "$WORK.CFG" || return

   MSYS_NO_PATHCONV=1 timeout 60 "./$EXE" "$WORK.CFG" /IMPORT "$(cygpath -d "$input")" \
      --settings "$SETTINGS_WIN" >/dev/null 2>&1
   rc=$?
   if [ "$rc" -ne 0 ]; then
      printf "  FAIL  %-28s import exited %s\n" "$name" "$rc"
      fail=$((fail+1)); return
   fi

   MSYS_NO_PATHCONV=1 timeout 60 "./$EXE" "$WORK.CFG" /EXPORT \
      --settings "$SETTINGS_WIN" >/dev/null 2>&1
   rc=$?
   if [ "$rc" -ne 0 ]; then
      printf "  FAIL  %-28s export exited %s\n" "$name" "$rc"
      fail=$((fail+1)); return
   fi

   out=$(ls "$WORK".ADI "$WORK".adi 2>/dev/null | head -1)
   if [ -z "$out" ]; then
      printf "  FAIL  %-28s the export wrote no ADIF\n" "$name"
      fail=$((fail+1)); return
   fi

   drop=$(ignored_tags_for "$name")
   note=""
   if [ -n "$drop" ]; then
      note=" (ignoring $drop)"
   fi

   # A minted identity is only ignored where the reference has none to compare.
   if ! grep -qi '<app_tr4w_id:' "$input"; then
      drop="$drop APP_TR4W_ID"
   fi

   # OUR STATION, BY THE SAME RULE (NY4I, 2026-10-18). A record that names no
   # MY_ field is given THIS CONTEST'S station at import, as a new QSO would
   # be, and the export then writes it -- so a reference with no MY_ tag at all
   # comes back carrying the contest's. That is the import working, and it is
   # set aside only where the reference has none to compare; the MY_ case below
   # carries them and is compared tag for tag. STATION_CALLSIGN is NOT set
   # aside: it is written by the same operator rule either way.
   if ! grep -qi '<my_' "$input"; then
      drop="$drop MY_GRIDSQUARE MY_STATE MY_CNTY MY_ARRL_SECT MY_IOTA MY_CQ_ZONE MY_ITU_ZONE MY_DXCC MY_SIG MY_SIG_INFO MY_POTA_REF"
      # ...BUT THEY MUST BE THERE. Setting them aside must not hide an import
      # that stamped nothing: every record is given the contest's station,
      # which always knows its country, so every record carries MY_DXCC.
      if [ "$(grep -ci '<my_dxcc:' "$out")" -ne "$(grep -ci '<eor>' "$out")" ]; then
         printf "  FAIL  %-28s the import did not give every record this contest's station (MY_DXCC on %s of %s)\n" \
            "$name" "$(grep -ci '<my_dxcc:' "$out")" "$(grep -ci '<eor>' "$out")"
         fail=$((fail+1)); return
      fi
   fi

   records_only "$out"       | strip_tags "$drop" > "$WORK.cand.txt"
   records_only "$input" | strip_tags "$drop" > "$WORK.ref.txt"

   pin="$d/known.adi.diff"
   # The normaliser this set's view went through, for the pinned lines.
   view_filter() { strip_tags "$drop"; }

   if diff -q "$WORK.cand.txt" "$WORK.ref.txt" >/dev/null 2>&1; then
      if [ -f "$pin" ]; then
         # The pinned difference is GONE -- a stale pin fails, or it would
         # excuse the difference coming back.
         printf "  FAIL  %-28s identical, but known.adi.diff still pins a difference -- remove it\n" "$name"
         fail=$((fail+1))
      else
         n=$(grep -ci '<eor>' "$WORK.ref.txt")
         printf "  PASS  %-28s %s record(s)%s\n" "$name" "$n" "$note"
         pass=$((pass+1))
      fi
   elif [ -f "$pin" ] &&
        pin_matches "$pin" "$(diff -u "$WORK.ref.txt" "$WORK.cand.txt")" view_filter; then
      printf "  KNOWN %-28s %s\n" "$name" "$(pin_reason "$pin")"
      known=$((known+1))
   else
      if [ -f "$pin" ]; then
         printf "  FAIL  %-28s records differ beyond known.adi.diff:\n" "$name"
      else
         printf "  FAIL  %-28s records differ:\n" "$name"
      fi
      diff "$WORK.cand.txt" "$WORK.ref.txt" | head -6 | sed 's/^/          /'
      fail=$((fail+1))
   fi
}

for d in "$CORPUS"/*/; do
   name=$(basename "$d")
   [ -n "$ONLY" ] && [ "$ONLY" != "$name" ] && continue
   [ -f "$d/ref.adi" ] || continue
   [ -f "$d/log.cfg" ] || continue
   roundtrip_one "$name" "$d" "$d/ref.adi"
done

# ---------------------------------------------------------------------------
# OUR STATION SURVIVES THE TRIP -- log schema 3, stage 2 (2026-10-18).
#
# No D7 reference carries a MY_ tag, so the sets above prove only that a
# record WITHOUT them comes back without them. This case is one set's
# reference with every MY_ tag the import reads put before each <EOR>, in the
# order the export writes them -- the export puts a QSO's own station after
# the contest's fields -- so a record that came back the same in every tag is
# one whose station the import stored and the export wrote from the row.
#
# NA Sprint because its records carry no MY_ tag of the contest's own (POTA
# writes its park, MY_STATE and MY_DXCC itself, and those win), and because
# it is two records. STATION_CALLSIGN is left out: the export writes it only
# when someone else operated, which is the operator's rule, not this test's.
# ---------------------------------------------------------------------------
MY_SET="na_sprint_cw_2026_ny4i"
MY_TAGS='<MY_GRIDSQUARE:6>EN01AB <MY_STATE:2>NE <MY_CNTY:3>LAN <MY_ARRL_SECT:2>NE <MY_IOTA:6>NA-001 <MY_CQ_ZONE:1>4 <MY_ITU_ZONE:1>7 <MY_DXCC:3>291 <MY_SIG:4>POTA <MY_SIG_INFO:7>US-1234 <MY_POTA_REF:7>US-1234 '
if [ -z "$ONLY" ] || [ "$ONLY" = "$MY_SET" ]; then
   if [ -f "$CORPUS/$MY_SET/ref.adi" ]; then
      awk -v tags="$MY_TAGS" '
         seen { gsub(/<[Ee][Oo][Rr]>/, tags "<EOR>") }
         { print }
         /<[Ee][Oo][Hh]>/ { seen = 1 }' "$CORPUS/$MY_SET/ref.adi" > "$WORK-my.adi"
      if [ "$(grep -c '<MY_POTA_REF:' "$WORK-my.adi")" -eq 0 ]; then
         printf "  FAIL  %-28s the MY_ input was not built\n" "MY_ tags ($MY_SET)"
         fail=$((fail+1))
      else
         roundtrip_one "MY_ tags ($MY_SET)" "$CORPUS/$MY_SET/" "$TARGET/$WORK-my.adi"
      fi
   else
      printf "  FAIL  %-28s no ref.adi to build the MY_ case from\n" "$MY_SET"
      fail=$((fail+1))
   fi
fi

rm -f "$WORK".* "$WORK-my.adi" "$EXE"; corpus_remove_new_logs

echo
echo "=== $pass passed, $fail failed, $known known-divergence, $skip skipped ==="
[ "$fail" -eq 0 ] || exit 1
