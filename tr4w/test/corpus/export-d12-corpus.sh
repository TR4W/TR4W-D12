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
# The inputs come from the TRACKED log.cfg/log.trw beside each manifest, staged
# into build-out/corpus-work -- a fresh clone can run this with no out-of-tree
# data, and the (destructive) export cannot touch a real log directory.  Set
# D12_ROOT to export from a raw log directory instead; see corpus-lib.sh.
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
. "$here/corpus-lib.sh"
EXE_NAME="${TR4W_EXE:-tr4w.exe}"
EXE="tr4w/target/$EXE_NAME"
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

# ---------------------------------------------------------------------------
# PRE-FLIGHT: the corpus needs the operator's Cabrillo header tags.
#
# WHY THIS EXISTS.  tr4w/target/* is gitignored, so a FRESH CLONE has no
# settings/tr4w.json -- and LOCATION is read from there
# (PostUnit.PAS:2552).  Two things then happen, and neither says so:
#
#   * Winter Field Day and ARRL10 REFUSE to export at all.  The guard at
#     PostUnit.PAS:2567 warns "LOCATION field is empty." and Exits, the program
#     returns 0, and no cand.cbr is written.  The sweep below reports "export
#     aborted or produced no output", which reads as a defect in the EXPORTER.
#   * Every other Cabrillo carries `LOCATION: <value>` in its header, so a
#     DIFFERENT value than the refs were frozen with is a byte diff on sets
#     that have nothing to do with the change under test.
#
# So a missing or blank tag is not a test result, it is an unrunnable test, and
# it is reported as one -- before 26 exports run and one of them gets blamed.
#
# THIS IS A GUARD, NOT THE FIX.  The real fix is for the corpus to own its
# header tags rather than read the operator's -- see
# docs/CORPUS_FRESH_CLONE_DEFECT.md.
SETTINGS="tr4w/target/settings/tr4w.json"
if [ ! -f "$SETTINGS" ]; then
   echo "ERROR: $SETTINGS is missing."
   echo "  The corpus reads the Cabrillo LOCATION tag from it, and tr4w/target/*"
   echo "  is gitignored -- so a fresh clone or worktree has no settings at all."
   echo "  Winter Field Day and ARRL10 will REFUSE to export, and every other"
   echo "  Cabrillo will carry a LOCATION that does not match the frozen refs."
   echo "  Run TR4W once to seed it, or copy one from a working tree."
   echo "  See docs/CORPUS_FRESH_CLONE_DEFECT.md."
   exit 1
fi
if ! grep -q '"_LOCATION"[[:space:]]*:[[:space:]]*"[^"]\+"' "$SETTINGS"; then
   echo "ERROR: $SETTINGS has no non-empty _LOCATION tag."
   echo "  Winter Field Day and ARRL10 refuse to export without it"
   echo "  (PostUnit.PAS:2567), and the sweep would blame the exporter."
   echo "  See docs/CORPUS_FRESH_CLONE_DEFECT.md."
   exit 1
fi

# The app's own last complaint, for a set that exported nothing.  It already
# said what was wrong; the harness simply was not looking.
last_app_warning(){
   local log="tr4w/target/tr4w.log"
   [ -f "$log" ] || return 0
   tail -400 "$log" 2>/dev/null       | grep -iE 'warn|error|fatal'       | tail -1       | sed 's/^[0-9]\{2\} [A-Za-z]\{3\} [0-9]\{4\} [0-9:.]* *//'
}

# /c/foo/bar -> C:\foo\bar  (the app needs a native Windows path)
towin(){ cygpath -d "$1"; }   # DOS 8.3 short path -- NO spaces, so Git-Bash->exe
                              # arg passing can't split the contest dir name.

# Fail-loud prep: clear prior candidates so a set whose export aborts/produces
# nothing can't keep passing on a stale file (run-golden-diff.sh runs below in
# GOLDEN_STRICT mode -- a set with a ref but no FRESH candidate is a FAIL).
rm -f "$here"/*/cand.adi "$here"/*/cand.cbr 2>/dev/null
n=0
for m in "$here"/*/manifest.json; do
   slug=$(corpus_manifest_get "$m" slug)
   [ -n "$ONLY" ] && [ "$ONLY" != "$slug" ] && continue
   case "$SKIP" in *" $slug "*) printf '  SKIP   %-26s (interactive dialog)\n' "$slug"; continue;; esac
   src=$(corpus_manifest_get "$m" source_dir)
   d12=$(corpus_set_dir "$slug" "$(basename "$src")")
   corpus_stage_set "$m" "$slug" "$d12" || { printf '  MISS   %-26s (staging failed)\n' "$slug"; continue; }
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

   # SAY WHY, HERE, WHERE THE SET IS STILL KNOWN.  A set that wrote nothing
   # surfaces 26 exports later as a bare "no fresh candidate", by which point
   # the reason is a log entry nobody thought to read.
   if ! ls "$d12"/*.ADI "$d12"/*.adi >/dev/null 2>&1; then
      why=$(last_app_warning)
      printf '  ^^^^^^ %-26s wrote NO ADIF' "$slug"
      [ -n "$why" ] && printf ' -- the app said: %s' "$why"
      printf '
'
   fi
   n=$((n+1))
done
echo "exported $n set(s)"; echo

if [ -z "$ONLY" ]; then
   GOLDEN_STRICT=1 bash "$here/pull-d12-candidates.sh"
else
   echo "(single-set smoke test -- run with no args for the full export + sweep)"
fi
