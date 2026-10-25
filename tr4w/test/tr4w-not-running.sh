#!/usr/bin/env bash
# tr4w-not-running.sh -- ONE guard, sourced by corpus-lib.sh and matrix-lib.sh,
# so the golden corpus, the ADIF round trip and the contest matrix all refuse
# to start while an operator's TR4W is running.  Sourced, never run.
#
# WHY IT REFUSES (2026-10-25).  Every headless run writes tr4w.log in
# tr4w/target -- the same file a running TR4W is appending to.  The two
# processes each keep their own file offset, so they overwrite each other's
# lines: the corpus was run three times while NY4I's TR4W was up, and his
# session's lines landed on top of the corpus runs' lines.  CLAUDE.md said to
# check first; a sentence did not stop it, so the scripts do.
#
# WHICH PROCESSES: tr4w.exe (target, FullBuild's output) and tr4w_fpc.exe
# (build-out, what NY4I runs in place), matched EXACTLY -- not tr4w*, which
# would also match tr4w_unit_tests.exe and tr4wserver.exe, neither of which
# writes tr4w.log in target.
#
# IT FAILS CLOSED.  If neither tasklist (Windows) nor pgrep (Linux, macOS) is
# available, it cannot tell, and it says so and refuses rather than passing.

# tr4w_refuse_if_running <name of the calling script>
# Returns 0 when no TR4W is running; otherwise prints why and returns 1.
tr4w_refuse_if_running(){
   local who="$1"
   local running=""

   if command -v tasklist >/dev/null 2>&1; then
      # //FO and //NH: a single slash would be rewritten as a path by MSYS.
      running="$(tasklist //FO CSV //NH 2>/dev/null | tr -d '\r' | awk -F'","' '
         {
            name = tolower($1)
            sub(/^"/, "", name)
            if (name == "tr4w.exe" || name == "tr4w_fpc.exe") {
               print "        " name " (pid " $2 ")"
            }
         }')"
   elif command -v pgrep >/dev/null 2>&1; then
      running="$(pgrep -l -x 'tr4w|tr4w_fpc' 2>/dev/null | sed 's/^/        /')"
   else
      echo "$who: REFUSING TO RUN -- cannot tell whether TR4W is running" >&2
      echo "        (neither tasklist nor pgrep is available)." >&2
      return 1
   fi

   if [ -n "$running" ]; then
      echo "$who: REFUSING TO RUN -- TR4W is running:" >&2
      echo "$running" >&2
      echo "        A run writes tr4w.log in tr4w/target, which the running TR4W" >&2
      echo "        is also writing, and each would overwrite the other's lines." >&2
      echo "        Close TR4W, then run this again." >&2
      return 1
   fi
   return 0
}
