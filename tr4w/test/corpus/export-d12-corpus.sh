#!/usr/bin/env bash
# export-d12-corpus.sh [only_slug]
#
# Automates the D12 golden-master exports.  For each corpus set it runs the
# D12 build's batch-export mode:
#     tr4w.exe "<contest>.CFG" /EXPORT
# (added in tr4w.dpr after SetUpGlobalsAndInitialize -- boots the contest,
# writes <log>.ADI + <CALL>.LOG with the -D12 banner, then Halts before the
# GUI/network init), then pull-d12-candidates.sh diffs everything vs the
# frozen D7 refs.  Replaces hand-doing File->Export on every log.
#
# Usage:  rebuild the app (IDE) first, then:
#     bash tr4w/test/corpus/export-d12-corpus.sh                # all sets, then sweep
#     bash tr4w/test/corpus/export-d12-corpus.sh arrl_fd_2026_ny4i   # one set (smoke test)
#
# Override the D12 log-staging root with env D12_ROOT.
#
# Override the binary under test with env TR4W_EXE (a file name inside
# tr4w/target, not a path).  That is how the FPC-built app is put through the
# same 26 byte-comparisons as the Delphi one:
#
#     TR4W_EXE=tr4w_fpc.exe bash tr4w/test/corpus/export-d12-corpus.sh
#
# The references are the SAME frozen D7 files either way -- the point is that
# a second compiler has to reproduce them byte for byte, not that it has to
# agree with whatever the first compiler happened to emit.
set -u
here="tr4w/test/corpus"
EXE_NAME="${TR4W_EXE:-tr4w.exe}"
EXE="tr4w/target/$EXE_NAME"
D12_ROOT="${D12_ROOT:-/c/tr4w-d12/D7-LogFilesForTesting}"
ONLY="${1:-}"
# Sets whose load pops an interactive dialog would BLOCK batch -- skip them.
#
# EMPTY as of 2026-08-13.  iaru_hf_2026_ny4i was listed here, and the listing
# had gone stale: it now exports cleanly (exit 0, both artifacts, no dialog).
# While it was skipped its divergence was ASSERTED by known-divergences.txt
# rather than demonstrated, which is the hole P2-9 was about -- see the header
# of run-golden-diff.sh.  Before adding a slug here, be sure the dialog is real
# and say what it is; a skipped set is a set nobody is checking.
SKIP=" "
[ -f "$EXE" ] || { echo "ERROR: no $EXE -- rebuild the D12 app first."; exit 1; }

# /c/foo/bar -> C:\foo\bar  (the app needs a native Windows path)
towin(){ cygpath -d "$1"; }   # DOS 8.3 short path -- NO spaces, so Git-Bash->exe
                              # arg passing can't split the contest dir name.

# Fail-loud prep: clear prior candidates so a set whose export aborts/produces
# nothing can't keep passing on a stale file (run-golden-diff.sh runs below in
# GOLDEN_STRICT mode -- a set with a ref but no FRESH candidate is a FAIL).
rm -f "$here"/*/cand.adi "$here"/*/cand.cbr 2>/dev/null
n=0
for m in "$here"/*/manifest.json; do
   slug=$(python -c "import json,sys;print(json.load(open(sys.argv[1]))['slug'])" "$m")
   [ -n "$ONLY" ] && [ "$ONLY" != "$slug" ] && continue
   case "$SKIP" in *" $slug "*) printf '  SKIP   %-26s (interactive dialog)\n' "$slug"; continue;; esac
   src=$(python -c "import json,sys;print(json.load(open(sys.argv[1]))['source_dir'])" "$m")
   d12="$D12_ROOT/$(basename "$src")"
   cfg=$(ls "$d12"/*.CFG "$d12"/*.cfg 2>/dev/null | grep -vi backup | head -1)
   [ -n "$cfg" ] || { printf '  MISS   %-26s (no cfg in %s)\n' "$slug" "$d12"; continue; }
   printf '  export %-26s\n' "$slug"
   # Fail-loud: delete this set's prior export outputs (ADIF + the Cabrillo .LOG,
   # identified by its START-OF-LOG header) so an aborted export leaves NO stale
   # candidate. A missing candidate then surfaces as a strict FAIL, not a pass.
   rm -f "$d12"/*.ADI "$d12"/*.adi 2>/dev/null
   for lg in "$d12"/*.LOG "$d12"/*.log; do
      [ -f "$lg" ] || continue
      head -1 "$lg" 2>/dev/null | grep -qi 'START-OF-LOG' && rm -f "$lg"
   done
   # run from target/ so the app resolves CTY.DAT + support files as usual
   # MSYS_NO_PATHCONV: stop Git Bash from mangling the /EXPORT flag into a path.
   # per-set timeout: a stray load dialog can't hang the whole run
   ( cd tr4w/target && MSYS_NO_PATHCONV=1 timeout 45 "./$EXE_NAME" "$(towin "$cfg")" /EXPORT >/dev/null 2>&1 )
   n=$((n+1))
done
echo "exported $n set(s)"; echo

if [ -z "$ONLY" ]; then
   GOLDEN_STRICT=1 bash "$here/pull-d12-candidates.sh" "$D12_ROOT"
else
   echo "(single-set smoke test -- run with no args for the full export + sweep)"
fi
