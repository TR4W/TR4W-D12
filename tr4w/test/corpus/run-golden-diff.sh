#!/usr/bin/env bash
# run-golden-diff.sh
#
# The CENTRAL Phase-1 check: for every corpus set that has a D12 candidate
# export (cand.adi / cand.cbr), byte-diff it against the frozen D7 reference
# (ref.adi / ref.cbr) via golden_diff.py, which normalizes only the version
# string + export timestamp.  A PASS means D12 reproduces D7 output exactly.
#
# Populate candidates first, e.g.:
#   bash tr4w/test/corpus/import-candidate.sh "/c/radio/TR4w/2026 ARRL-FD NY4I" arrl_fd_2026_ny4i
GD="tr4w/test/python/golden_diff.py"
KNOWN="tr4w/test/corpus/known-divergences.txt"
# A set listed in known-divergences.txt diffs for a tracked, non-conversion
# reason (see that file); report it as KNOWN, not FAIL.
is_known(){ grep -qiE "^$1[[:space:]]" "$KNOWN" 2>/dev/null; }

# THE ROW'S OWN REASON, not a fixed one. known-divergences.txt is documented as
# `<slug>  <reason>` and every row carries a different reason -- but this script
# printed "(event-source issue, deferred)" for all of them, which was true of
# the rows that existed when it was written and became a plain lie the moment
# one was added for another cause. A reader trusts the line on screen; they do
# not open the file to check whether it means what it says.
known_reason(){ grep -iE "^$1[[:space:]]" "$KNOWN" 2>/dev/null | head -1 |
                sed -E "s/^[^[:space:]]+[[:space:]]+//"; }
# A KNOWN DIFFERENCE IN ONE ARTIFACT, PINNED LINE FOR LINE (Q54, 2026-10-16).
#
# A row in known-divergences.txt excuses EVERY difference in BOTH artifacts of
# its set, which is the right tool for a defect whose reach is open-ended
# (general_qso's sent exchange) and the wrong one for a ruled change of a
# known size: listing winter_fd there for its one FM line would have blinded
# the corpus to any future regression in that set's ADIF and Cabrillo alike.
#
# So a set may instead carry <set>/known.<kind>.diff, matched by the ONE
# implementation both corpus oracles source -- known-pin-lib.sh, which says
# what a pin means. test-adif-roundtrip.sh reads the same file.
. "$(dirname "${BASH_SOURCE[0]}")/known-pin-lib.sh"
pass=0; fail=0; skip=0; known=0
for d in tr4w/test/corpus/*/; do
   slug=$(basename "$d")
   for kind in adi cbr; do
      ref="${d}ref.$kind"; cand="${d}cand.$kind"
      [ -f "$ref" ] || continue
      if [ ! -f "$cand" ]; then
         if [ "${GOLDEN_STRICT:-0}" = 1 ]; then
            # Fail-loud, and deliberately NOT exempting known-divergence sets:
            # a full export ran but produced no FRESH candidate for this set
            # (aborted export / no output). Never let a prior stale file mask
            # that -- the export driver deletes candidates first.
            printf '  FAIL  %-26s %-3s (no fresh D12 candidate -- export aborted or produced no output)\n' "$slug" "$kind"
            fail=$((fail+1))
         else
            printf '  ....  %-26s %-3s (no D12 candidate yet)\n' "$slug" "$kind"
            skip=$((skip+1))
         fi
         continue
      fi
      pin="${d}known.$kind.diff"
      out=$(python "$GD" "$ref" "$cand" 2>&1); rc=$?
      if [ "$rc" -eq 0 ]; then
         if [ -f "$pin" ]; then
            # The pinned difference is GONE. Not a silent pass: the pin is now
            # stale and must come out, or it would excuse the line coming back.
            printf '  FAIL  %-26s %-3s (identical, but %s still pins a difference -- remove it)\n' \
                   "$slug" "$kind" "known.$kind.diff"
            fail=$((fail+1))
         else
            printf '  PASS  %-26s %s\n' "$slug" "$kind"; pass=$((pass+1))
         fi
      elif [ -f "$pin" ] && [ "$rc" -eq 1 ] &&
           pin_matches "$pin" "$out"; then
         # rc 1 is a FIDELITY difference only; a validity failure (rc 3, a
         # corrupt candidate) or a usage error is never excused by a pin.
         printf '  KNOWN %-26s %-3s (%s)\n' "$slug" "$kind" "$(pin_reason "$pin")"; known=$((known+1))
      elif [ -f "$pin" ]; then
         printf '  FAIL  %-26s %s (differs beyond %s)\n' "$slug" "$kind" "known.$kind.diff"
         echo "$out" | grep -E '^[-+@]' | head -8 | sed 's/^/        /'
         fail=$((fail+1))
      elif is_known "$slug"; then
         printf '  KNOWN %-26s %-3s (%s)\n' "$slug" "$kind" "$(known_reason "$slug")"; known=$((known+1))
      else
         printf '  FAIL  %-26s %s\n' "$slug" "$kind"
         echo "$out" | grep -E '^[-+@]' | head -8 | sed 's/^/        /'
         fail=$((fail+1))
      fi
   done
done
echo "=== $pass passed, $fail failed, $known known-divergence, $skip awaiting-candidate ==="
[ "$fail" -eq 0 ]
