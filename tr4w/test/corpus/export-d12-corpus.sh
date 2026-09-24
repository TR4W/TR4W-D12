#!/usr/bin/env bash
# export-d12-corpus.sh [only_slug]
#
# THE QUESTION THIS ASKS: does a given log produce the expected ADIF and
# Cabrillo?  For each corpus set it runs the build's batch-export mode:
#     tr4w.exe "<contest>.db" /EXPORT
# (in uProgramMain after SetUpGlobalsAndInitialize -- opens the contest, writes
# <log>.ADI + <CALL>.LOG with the -D12 banner, then Halts before the GUI/network
# init), then pull-d12-candidates.sh diffs everything vs the frozen D7 refs.
#
# Usage:  rebuild the app first, then:
#     bash tr4w/test/corpus/export-d12-corpus.sh                # all sets, then sweep
#     bash tr4w/test/corpus/export-d12-corpus.sh arrl_fd_2026_ny4i   # one set (smoke test)
#
# THE INPUT IS THE TRACKED log.db beside each manifest, staged into
# build-out/corpus-work.  A contest IS a SQLite log in this program, so that is
# what the oracle is given.  The D7 .trw/.cfg inputs were retired by decision on
# 2026-09-24 -- corpus-lib.sh carries NY4I's words and says where binary-log
# import is covered now.  DO NOT reintroduce them here.
#
# THE REFERENCES ARE STILL D7-PRODUCED AND ARE NEVER REGENERATED.  That is the
# half of the oracle we did not write: our input, somebody else's expected
# output.  A ref that "needs" to change is a behaviour finding, not a step.
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

# THE BINARY MUST NOT BE OLDER THAN THE ONE JUST BUILT.
#
# This runs tr4w/target/tr4w.exe, which is where FullBuild.ps1 puts the app.
# Build-App.ps1 -- the fast iteration path -- writes build-out/ instead and does
# NOT touch target/.  So "edit, Build-App, run the corpus" silently measures the
# PREVIOUS binary, and the corpus reports PASS for code that was never run.
#
# That is not hypothetical: it happened for a whole session on 2026-09-02.  Every
# green corpus result was against a build 14 hours old, and the run that finally
# used the new binary turned 22/0/4 into 24/0/2 -- two divergences had already
# been fixed and the corpus could not see it.  A regression would have hidden
# exactly as well.
#
# Refusing is the only safe answer: a warning in a 30-line pass list is a
# warning nobody reads.
BUILD_OUT="build-out/app-i386-win32/tr4w_fpc.exe"
if [ -f "$BUILD_OUT" ] && [ -f "$EXE" ] && [ "$BUILD_OUT" -nt "$EXE" ]; then
   echo "corpus: REFUSING TO RUN -- $EXE is older than $BUILD_OUT." >&2
   echo "        The corpus would measure the previous build and report PASS" >&2
   echo "        for code that never ran.  Copy it into place first:" >&2
   echo "          cp $BUILD_OUT $EXE" >&2
   echo "        (or run FullBuild.ps1, which puts it there itself)." >&2
   exit 1
fi
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
# (postunit.pas:2552).  Two things then happen, and neither says so:
#
#   * Winter Field Day and ARRL10 REFUSE to export at all.  The guard at
#     postunit.pas:2567 warns "LOCATION field is empty." and Exits, the program
#     returns 0, and no cand.cbr is written.  The sweep below reports "export
#     aborted or produced no output", which reads as a defect in the EXPORTER.
#   * Every other Cabrillo carries `LOCATION: <value>` in its header, so a
#     DIFFERENT value than the refs were frozen with is a byte diff on sets
#     that have nothing to do with the change under test.
#
# So a missing or blank tag is not a test result, it is an unrunnable test, and
# it is reported as one -- before 26 exports run and one of them gets blamed.
#
# THE CORPUS OWNS ITS SETTINGS NOW, 2026-09-12, which is the fix this comment
# asked for and no longer a guard around somebody else's file.
#
# WHY IT MATTERED, MEASURED RATHER THAN ARGUED. This read
# tr4w/target/settings/tr4w.json -- the OPERATOR'S live configuration, in a
# gitignored directory. That made the scoring oracle depend on the machine it
# ran on, and it failed exactly that way: NY4I staged a first-run file there to
# test conversion, it had no _LOCATION, and the corpus was unrunnable for a day
# while scoring work waited on it.
#
# NY4I, 2026-09-12: "you should have your own json file (make a copy of this
# one) and feed that one to tr4w as a parameter for the corpus."
#
# The fixture is a copy of a real working configuration with every credential
# blanked -- the values that produce the frozen references, and nothing that
# should not be in a public repository. tr4w.exe reads it through --settings,
# which exists for this.
SETTINGS="tr4w/test/corpus/settings/tr4w.json"
if [ ! -f "$SETTINGS" ]; then
   echo "ERROR: $SETTINGS is missing."
   echo "  This is the corpus's OWN settings fixture and it is tracked, so it"
   echo "  should never be absent -- if it is, the checkout is incomplete."
   exit 1
fi
if ! grep -q '"_LOCATION"[[:space:]]*:[[:space:]]*"[^"]\+"' "$SETTINGS"; then
   echo "ERROR: $SETTINGS has no non-empty _LOCATION tag."
   echo "  Winter Field Day and ARRL10 refuse to export without it"
   echo "  (postunit.pas:2567), and the sweep would blame the exporter."
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

# AFTER towin IS DEFINED, and after the guard has proved the fixture is there:
# cygpath -d needs the file to exist. The export runs from tr4w/target, so the
# path handed to the app is absolute.
SETTINGS_WIN="$(towin "$(pwd)/$SETTINGS")"


# Fail-loud prep: clear prior candidates so a set whose export aborts/produces
# nothing can't keep passing on a stale file (run-golden-diff.sh runs below in
# GOLDEN_STRICT mode -- a set with a ref but no FRESH candidate is a FAIL).
rm -f "$here"/*/cand.adi "$here"/*/cand.cbr 2>/dev/null
# WHAT AN EXIT CODE MEANS, IN WORDS.
#
# Windows reports a fault as its NTSTATUS, so an access violation arrives here
# as 3221225477 -- 0xC0000005, which reads as noise. A guard whose output has
# to be decoded before it can be acted on is one that gets ignored.
exit_reason() {
   case "$1" in
      124)        echo "timed out (45 s) -- a dialog, or a hang" ;;
      3)          echo "refused: another TR4W instance holds the mutex" ;;
      4)          echo "refused: no usable contest file was passed" ;;
      3221225477) echo "CRASHED: access violation (0xC0000005)" ;;
      3221225725) echo "CRASHED: stack overflow (0xC00000FD)" ;;
      3221225620) echo "CRASHED: illegal instruction (0xC000001D)" ;;
      21474836*)  echo "CRASHED: fatal exception ($1)" ;;
      3221225*)   echo "CRASHED: fatal exception ($1)" ;;
      *)          echo "exited $1" ;;
   esac
}

# Sets whose exporter did not exit 0, named so the summary can list them.
bad_exit=0
bad_slugs=""

n=0
for m in "$here"/*/manifest.json; do
   slug=$(corpus_manifest_get "$m" slug)
   [ -n "$ONLY" ] && [ "$ONLY" != "$slug" ] && continue
   case "$SKIP" in *" $slug "*) printf '  SKIP   %-26s (interactive dialog)\n' "$slug"; continue;; esac
   d12=$(corpus_set_dir "$slug")
   corpus_stage_set "$m" "$slug" "$d12" || { printf '  MISS   %-26s (staging failed)\n' "$slug"; continue; }
   log=$(ls "$d12"/*.db 2>/dev/null | head -1)
   [ -n "$log" ] || { printf '  MISS   %-26s (no log database in %s)\n' "$slug" "$d12"; continue; }
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
   # --settings: the app reads and writes the corpus's fixture, never the
   # operator's. The path is absolute because the export runs from tr4w/target.
   ( cd tr4w/target && MSYS_NO_PATHCONV=1 timeout 45 "./$EXE_NAME" "$(towin "$log")" /EXPORT --settings "$SETTINGS_WIN" >/dev/null 2>&1 )
   rc=$?

   # THE EXIT CODE IS EVIDENCE AND IT WAS BEING THROWN AWAY.
   #
   # An export that writes both artifacts correctly and THEN crashes produced a
   # clean 24/0/2 here for at least two days (see the header). Judged where the
   # set is still known, the way every other check in this loop is.
   if [ "$rc" -ne 0 ]; then
      printf '  ^^^^^^ %-26s %s\n' "$slug" "$(exit_reason "$rc")"
      bad_exit=$((bad_exit+1))
      bad_slugs="$bad_slugs $slug($rc)"
   fi

   # SAY WHY, HERE, WHERE THE SET IS STILL KNOWN.  A set that wrote nothing
   # surfaces 26 exports later as a bare "no fresh candidate", by which point
   # the reason is a log entry nobody thought to read.
   # BOTH GLOBS MUST FAIL, TESTED SEPARATELY.  `ls a b` exits non-zero when
   # EITHER operand is missing, and Git Bash globs case-sensitively -- so with
   # the two patterns in one ls, a set that wrote ARKTIK~1.ADI still reported
   # "wrote NO ADIF" because *.adi matched nothing and stayed literal.
   #
   # It fired on all 13 healthy sets, which is worse than not firing at all:
   # this line exists to say WHY a set produced nothing, and a warning that is
   # always wrong is one nobody reads on the day it is right.  It also printed
   # the last app warning beside each one, which made a benign TotalTextOut
   # message look like the cause of a failure that had not happened.
   if ! ls "$d12"/*.ADI >/dev/null 2>&1 && ! ls "$d12"/*.adi >/dev/null 2>&1; then
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
   sweep_rc=$?
else
   echo "(single-set smoke test -- run with no args for the full export + sweep)"
   sweep_rc=0
fi

# A CRASHING EXPORTER FAILS THE RUN, EVEN WITH 26 BYTE-PERFECT ARTIFACTS.
#
# Repeated after the sweep on purpose: the per-set line above is thirty lines
# up by the time the summary prints, and the summary is the line people read.
if [ "$bad_exit" -gt 0 ]; then
   echo
   echo "=== CORPUS FAILED: $bad_exit of $n export run(s) did not exit 0 ==="
   echo "    $bad_slugs"
   echo "    The artifacts above may still compare byte-perfect -- they are"
   echo "    written before the exporter exits. An export that cannot exit"
   echo "    cleanly is a defect the byte comparison cannot see, which is why"
   echo "    this is judged separately."
   exit 1
fi

exit $sweep_rc
