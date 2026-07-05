#!/usr/bin/env bash
# import-candidate.sh <source_contest_dir> <slug>
#
# Pull the CURRENT ADIF + Cabrillo export from a contest dir into an existing
# corpus set as cand.adi / cand.cbr -- the D12 build's output to be golden-
# diffed against the frozen D7 ref.adi / ref.cbr.  cand.* are transient
# (gitignored); re-run any time you re-export from D12.
#
# The D7 references are already committed as ref.* in the corpus, so it is
# safe to re-export D12 over the original source dir -- the ground truth is
# preserved regardless.
set -euo pipefail
src="${1:?usage: import-candidate.sh <source_dir> <slug>}"
slug="${2:?usage: import-candidate.sh <source_dir> <slug>}"
dest="tr4w/test/corpus/$slug"
[ -d "$dest" ] || { echo "ERROR: no such corpus set: $dest" >&2; exit 1; }

adi=$(ls "$src"/*.ADI "$src"/*.adi 2>/dev/null | head -1 || true)
cbr=""
for f in "$src"/*.LOG "$src"/*.log "$src"/*.CBR "$src"/*.cbr; do
   [ -f "$f" ] || continue
   head -1 "$f" 2>/dev/null | grep -qi 'START-OF-LOG' && { cbr="$f"; break; }
done

[ -n "$adi" ] && cp "$adi" "$dest/cand.adi"
[ -n "$cbr" ] && cp "$cbr" "$dest/cand.cbr"

ver=$(grep -m1 -hioE 'TR4W v[.0-9]+' "$adi" "$cbr" 2>/dev/null | head -1 || true)
echo "candidate $slug: ver=${ver:-?} adi=$([ -n "$adi" ]&&echo y||echo -) cbr=$([ -n "$cbr" ]&&echo y||echo -)"
