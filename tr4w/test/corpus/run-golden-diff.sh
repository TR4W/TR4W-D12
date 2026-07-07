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
pass=0; fail=0; skip=0; known=0
for d in tr4w/test/corpus/*/; do
   slug=$(basename "$d")
   for kind in adi cbr; do
      ref="${d}ref.$kind"; cand="${d}cand.$kind"
      [ -f "$ref" ] || continue
      if [ ! -f "$cand" ]; then
         if is_known "$slug"; then
            printf '  KNOWN %-26s %-3s (no candidate; known-divergence)\n' "$slug" "$kind"
            known=$((known+1))
         elif [ "${GOLDEN_STRICT:-0}" = 1 ]; then
            # Fail-loud: a full export ran but produced no FRESH candidate for
            # this set (aborted export / no output). Never let a prior stale
            # file mask that -- the export driver deletes candidates first.
            printf '  FAIL  %-26s %-3s (no fresh D12 candidate -- export aborted or produced no output)\n' "$slug" "$kind"
            fail=$((fail+1))
         else
            printf '  ....  %-26s %-3s (no D12 candidate yet)\n' "$slug" "$kind"
            skip=$((skip+1))
         fi
         continue
      fi
      if out=$(python "$GD" "$ref" "$cand" 2>&1); then
         printf '  PASS  %-26s %s\n' "$slug" "$kind"; pass=$((pass+1))
      elif is_known "$slug"; then
         printf '  KNOWN %-26s %-3s (event-source issue, deferred)\n' "$slug" "$kind"; known=$((known+1))
      else
         printf '  FAIL  %-26s %s\n' "$slug" "$kind"
         echo "$out" | grep -E '^[-+@]' | head -8 | sed 's/^/        /'
         fail=$((fail+1))
      fi
   done
done
echo "=== $pass passed, $fail failed, $known known-divergence, $skip awaiting-candidate ==="
[ "$fail" -eq 0 ]
