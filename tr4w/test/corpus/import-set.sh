#!/usr/bin/env bash
# import-set.sh <source_contest_dir> <slug>
#
# Imports one matched TR4W contest set into the golden-master corpus:
#   log.trw  <- the main contest .TRW (backups excluded)
#   log.cfg  <- the contest .CFG (drives export header + scoring context)
#   ref.adi  <- the fresh D7 ADIF export        (golden master)
#   ref.cbr  <- the fresh D7 Cabrillo export     (golden master; TR4W names it <CALL>.LOG)
#   manifest.json <- provenance (source dir, D7 version, QSO count, claimed score)
#
# The ADIF/Cabrillo MUST be regenerated from a single CURRENT D7 build (v4.149.x).
# A non-4.149 export is flagged as a WARNING so stale exports never slip in silently.
set -euo pipefail
src="${1:?usage: import-set.sh <source_dir> <slug>}"
slug="${2:?usage: import-set.sh <source_dir> <slug>}"
dest="tr4w/test/corpus/$slug"
[ -d "$src" ] || { echo "ERROR: no such source dir: $src" >&2; exit 1; }

# main log: largest .TRW that is not a *BACKUP*
log=$(ls -S "$src"/*.TRW "$src"/*.trw 2>/dev/null | grep -vi backup | head -1 || true)
cfg=$(ls    "$src"/*.CFG "$src"/*.cfg 2>/dev/null | grep -vi backup | head -1 || true)
# ADIF: first .ADI present
adi=$(ls "$src"/*.ADI "$src"/*.adi 2>/dev/null | head -1 || true)
# Cabrillo: any .LOG/.CBR whose first line is START-OF-LOG (excludes LOGBACKUP_*.TRW)
cbr=""
for f in "$src"/*.LOG "$src"/*.log "$src"/*.CBR "$src"/*.cbr; do
   [ -f "$f" ] || continue
   head -1 "$f" 2>/dev/null | grep -qi 'START-OF-LOG' && { cbr="$f"; break; }
done

[ -n "$log" ] || { echo "ERROR: no contest .TRW found in $src" >&2; exit 1; }
mkdir -p "$dest"
cp "$log" "$dest/log.trw"
[ -n "$cfg" ] && cp "$cfg" "$dest/log.cfg"
[ -n "$adi" ] && cp "$adi" "$dest/ref.adi"
[ -n "$cbr" ] && cp "$cbr" "$dest/ref.cbr"

ver=$(grep -m1 -hioE 'TR4W v[.0-9]+' "$adi" "$cbr" 2>/dev/null | head -1 || true)
qso=$(grep -c -i '<eor>' "$dest/ref.adi" 2>/dev/null || echo 0)
score=$(grep -m1 -i '^CLAIMED-SCORE:' "${dest}/ref.cbr" 2>/dev/null | tr -dc '0-9' || true)

cat > "$dest/manifest.json" <<EOF
{
  "slug": "$slug",
  "source_dir": "$src",
  "d7_version": "${ver:-unknown}",
  "qso_count": ${qso:-0},
  "claimed_score": "${score:-}",
  "orig": {
    "log": "$(basename "$log")",
    "cfg": "$([ -n "$cfg" ] && basename "$cfg" || echo -)",
    "adi": "$([ -n "$adi" ] && basename "$adi" || echo -)",
    "cbr": "$([ -n "$cbr" ] && basename "$cbr" || echo -)"
  }
}
EOF

warn=""
case "$ver" in *4.149*) ;; *) warn="  <<< WARNING: not v4.149 — regenerate from current D7";; esac
echo "imported $slug: ver=${ver:-?} qso=${qso:-?} score=${score:-?} adi=$([ -n "$adi" ]&&echo y||echo -) cbr=$([ -n "$cbr" ]&&echo y||echo -)$warn"
