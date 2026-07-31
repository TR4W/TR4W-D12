#!/usr/bin/env bash
# pull-d12-candidates.sh [D12_EXPORT_ROOT]
#
# For each corpus set, look for a D12 re-export of the same log under
# D12_EXPORT_ROOT/<same dir name as the D7 source> and pull it in as cand.*.
# Then run run-golden-diff.sh to compare against the frozen D7 ref.*.
#
# The D12 exports mirror the D7 source dir names, e.g.
#   D7 : /c/radio/TR4w/2026 ARRL-FD NY4I
#   D12: /c/TR4W-D12/D7-LOGFILESFORTESTING/2026 ARRL-FD NY4I
D12_ROOT="${1:-/c/TR4W-D12/D7-LOGFILESFORTESTING}"
here="tr4w/test/corpus"
found=0
for m in "$here"/*/manifest.json; do
   slug=$(python -c "import json,sys;print(json.load(open(sys.argv[1]))['slug'])" "$m")
   src=$(python -c "import json,sys;print(json.load(open(sys.argv[1]))['source_dir'])" "$m")
   base=$(basename "$src")
   d12="$D12_ROOT/$base"
   adi=$(ls "$d12"/*.ADI "$d12"/*.adi 2>/dev/null | head -1)
   # Only pull an export that is actually a D12 build's output.  D12 exports
   # carry the "-D12" version suffix in their banner; the D7 leftovers seeded
   # into this folder do not, so this skips them (a D7-vs-D7 false pass).
   #
   # Match the SUFFIX only, not the whole version string.  The original pattern
   # was 'TR4W v[.0-9]+-D12', which assumed the suffix follows the number
   # directly.  On 2026-07-28 (899cdb6) TR4W_CURRENTVERSION gained ' Delphi12',
   # so the banner became "TR4W v.4.149.0 Delphi12-D12", the pattern stopped
   # matching, EVERY candidate was rejected, and the whole corpus reported
   # "no fresh D12 candidate" -- 0 passed / 22 failed -- while the exports
   # themselves were perfectly fine.  Anchoring on the suffix keeps this
   # independent of whatever else the banner carries.
   if [ -n "$adi" ] && grep -qiE 'TR4W v.*-D12' "$adi"; then
      bash "$here/import-candidate.sh" "$d12" "$slug" >/dev/null
      found=$((found+1))
   fi
done
echo "pulled $found D12 candidate(s) from $D12_ROOT"
echo
bash "$here/run-golden-diff.sh"
