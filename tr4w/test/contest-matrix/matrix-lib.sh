#!/bin/bash
#
# matrix-lib.sh -- THE ONE RUN LOOP behind run-contest-matrix.sh (compare) and
# freeze-contest-matrix.sh (freeze).  Sourced, never run.
#
# It lives in one file because the two scripts must agree byte for byte on how
# a record is produced: if the freeze wrote records one way and the compare
# produced them another, every contest would report a difference that is not
# one -- on the gate that is supposed to watch setup, scoring and export.
#
# ---------------------------------------------------------------------------
# WHAT A RUN IS
# ---------------------------------------------------------------------------
#   1. tr4w.exe /MATRIXLIST lists every ContestType (the enum, iterated by the
#      program -- nothing here names a contest).
#   2. For each contest and each STATION VARIANT, a .cfg is written into a
#      fresh scratch directory and the program is started on it with
#          <cfg> /MATRIX <record> <ordinal> --settings <fixture copy>
#      so the contest is set up by the ordinary startup path, exactly as an
#      operator opening it would.  ONE PROCESS PER RECORD: FoundContest is not
#      idempotent, so a shared process would make each record depend on the
#      contests run before it.  See uContestMatrix's header.
#   3. The variant records are concatenated into <IDENTIFIER>.matrix.
#
# THE STATION VARIANTS, AND WHY THESE FOUR
#   us       K0AAA, Kansas.  A US station that is the host of no state party.
#   us-host  ONLY for a contest with a host state (ContestsArray P <> 0).
#            MY STATE is the FIRST KEY of the contest's domestic file -- what
#            FoundMyStateInDomFile tests MY STATE against -- or, when the row
#            names no file, the host state itself.  The call is VE7AAA (grid
#            CN89) when the host is a VE7 party, K0AAA (EM17) otherwise.
#   ve       VE3AAA, Ontario.  W/VE contests treat VE differently from DX.
#   dx       DL1AAA, Germany.  No MY STATE at all.  DL1ABC in the QSO table is
#            its same-country contact.
#   Every variant also states MY NAME, MY FD CLASS, MY CHECK and MY PREC, so a
#   contest that sends one of them has a value to send.
#
# ---------------------------------------------------------------------------
# DETERMINISM, AND WHAT IT RESTS ON
# ---------------------------------------------------------------------------
#   * The program reads the matrix's OWN settings fixture (settings/tr4w.json),
#     COPIED into the scratch directory for every run so nothing a run writes
#     can reach the tracked file -- never the operator's settings.
#   * --settings moves the writable data directory into the scratch directory,
#     which holds no CTY.DAT, so the SHIPPED tr4w/target/cty.dat answers, not a
#     copy a developer downloaded.  Same reasoning as the golden corpus.
#   * The program runs from tr4w/target, so dom/ and cty.dat are the tracked
#     ones.  COMMONMESSAGES.INI is NOT tracked and would change the recorded CW
#     memories, so its presence there refuses the run.
#   * Times are fixed in the QSO table; the one clock-derived setting (CONTEST
#     TITLE) is left out; machine paths are replaced in the program.
#   Two consecutive runs are byte-identical -- that was checked when the
#   matrix was first frozen, and the compare would expose any drift since.
set -u

MATRIX_REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
MATRIX_DIR="$MATRIX_REPO_ROOT/tr4w/test/contest-matrix"
MATRIX_FROZEN="$MATRIX_DIR/frozen"
MATRIX_SETTINGS="$MATRIX_DIR/settings/tr4w.json"
MATRIX_TARGET="$MATRIX_REPO_ROOT/tr4w/target"
MATRIX_EXE_SRC="$MATRIX_REPO_ROOT/build-out/app-i386-win32/tr4w_fpc.exe"
MATRIX_EXE="matrix-run.exe"
MATRIX_WORK="$MATRIX_REPO_ROOT/build-out/contest-matrix-work"

# A record line ends CRLF, the same as the lines the program writes, so a
# concatenated record has one line ending throughout.
matrix_line(){
   printf '%s\r\n' "$1"
}

# What an exit code means, in words -- the export corpus's table, for the
# codes a headless TR4W actually returns.
matrix_exit_reason(){
   case "$1" in
      124)        echo "timed out -- a dialog, or a hang" ;;
      1)          echo "refused at startup" ;;
      2)          echo "the record could not be written" ;;
      4)          echo "no usable contest file" ;;
      217)        echo "CRASHED: unhandled exception" ;;
      3221225477) echo "CRASHED: access violation" ;;
      3221225725) echo "CRASHED: stack overflow" ;;
      *)          echo "exited $1" ;;
   esac
}

# matrix_preflight -- every condition that would make a run measure the wrong
# thing is a refusal, not a warning.
matrix_preflight(){
   if [ ! -f "$MATRIX_EXE_SRC" ]; then
      echo "contest-matrix: no app at $MATRIX_EXE_SRC -- run Build-App.ps1 first" >&2
      return 1
   fi
   if [ ! -f "$MATRIX_SETTINGS" ]; then
      echo "contest-matrix: the settings fixture $MATRIX_SETTINGS is missing" >&2
      echo "                -- it is tracked, so the checkout is incomplete." >&2
      return 1
   fi
   if ls "$MATRIX_TARGET"/[Cc][Oo][Mm][Mm][Oo][Nn][Mm][Ee][Ss][Ss][Aa][Gg][Ee][Ss].[Ii][Nn][Ii] >/dev/null 2>&1; then
      echo "contest-matrix: REFUSING -- tr4w/target holds a COMMONMESSAGES.INI." >&2
      echo "                It is untracked and would change the recorded CW" >&2
      echo "                memories, so the run would describe this machine." >&2
      return 1
   fi
   return 0
}

# matrix_dom_first_key <DF> -- the first key FoundMyStateInDomFile could match:
# the text before '=' on the first line that has one, cut at '>', trimmed.
# EnumDOM2's own reading, line for line.  Empty when there is no such file.
matrix_dom_first_key(){
   local df="$1" f
   [ -n "$df" ] || return 0
   f=$(find "$MATRIX_TARGET/dom" -maxdepth 1 -iname "$df.dom" 2>/dev/null | head -1)
   [ -n "$f" ] || return 0
   tr -d '\r' < "$f" | awk -F'=' 'NF > 1 {
         k = $1; sub(/>.*/, "", k);
         gsub(/^[ \t]+|[ \t]+$/, "", k);
         print k; exit }'
}

# matrix_write_cfg <file> <call> <state> <section> <grid> <contest spelling>
# The station first and CONTEST last, as a real contest .cfg has it: FoundContest
# reads MY STATE and MY CALL, so they must already be set when CONTEST runs it.
matrix_write_cfg(){
   local f="$1" call="$2" state="$3" section="$4" grid="$5" contest="$6"
   {
      matrix_line "[COMMANDS]"
      matrix_line "MY CALL=$call"
      [ -n "$state" ] && matrix_line "MY STATE=$state"
      matrix_line "MY SECTION=$section"
      matrix_line "MY GRID=$grid"
      matrix_line "MY NAME=TOM"
      matrix_line "MY FD CLASS=1A"
      matrix_line "MY CHECK=99"
      matrix_line "MY PREC=A"
      matrix_line "CONTEST=$contest"
   } > "$f"
}

# matrix_run_one <record-file> <ordinal> <spelling> <label> <call> <state> <section> <grid>
# Appends one variant's record to <record-file>.  Returns 3 when another TR4W
# holds the install's mutex, which the caller treats as fatal: every later run
# would be refused the same way.
matrix_run_one(){
   local rec="$1" ord="$2" spelling="$3" label="$4"
   local call="$5" state="$6" section="$7" grid="$8"
   local run="$MATRIX_WORK/run" rc

   rm -rf "$run"
   mkdir -p "$run" || return 1
   matrix_write_cfg "$run/MATRIX.CFG" "$call" "$state" "$section" "$grid" "$spelling"
   cp "$MATRIX_SETTINGS" "$run/tr4w.json" || return 1

   ( cd "$MATRIX_TARGET" && MSYS_NO_PATHCONV=1 timeout 60 "./$MATRIX_EXE" \
        "$(cygpath -w "$run/MATRIX.CFG")" /MATRIX "$(cygpath -w "$run/out.matrix")" \
        "$ord" --settings "$(cygpath -w "$run/tr4w.json")" >/dev/null 2>&1 )
   rc=$?

   matrix_line "### variant $label: MY CALL=$call MY STATE=$state MY SECTION=$section MY GRID=$grid" >> "$rec"
   if [ "$rc" -eq 3 ]; then
      return 3
   fi
   if [ "$rc" -eq 0 ] && [ -f "$run/out.matrix" ]; then
      cat "$run/out.matrix" >> "$rec"
   else
      # RECORDED, NOT SKIPPED.  A contest that cannot be opened today is a
      # fact about today, and freezing it means the day it starts opening --
      # or a second one stops -- is a difference somebody has to look at.
      matrix_line "RUN FAILED: exit $rc ($(matrix_exit_reason "$rc"))" >> "$rec"
   fi
   return 0
}

# matrix_run <out-dir> [IDENTIFIER ...]
# Writes one <IDENTIFIER>.matrix per contest into <out-dir> (emptied first).
# No identifiers means every contest.  Prints a progress dot per contest and a
# count at the end.  Non-zero when the run could not be done at all.
matrix_run(){
   local out="$1"; shift
   local list="$MATRIX_WORK/contests.tsv"
   local n=0 rc ord ident spelling p df host want s key hcall hsection hgrid

   matrix_preflight || return 1
   mkdir -p "$MATRIX_WORK" || return 1
   rm -rf "$out"
   mkdir -p "$out" || return 1

   cp "$MATRIX_EXE_SRC" "$MATRIX_TARGET/$MATRIX_EXE" || return 1

   rm -f "$list"
   ( cd "$MATRIX_TARGET" && MSYS_NO_PATHCONV=1 timeout 60 "./$MATRIX_EXE" \
        /MATRIXLIST "$(cygpath -w "$list")" >/dev/null 2>&1 )
   rc=$?
   if [ "$rc" -ne 0 ] || [ ! -s "$list" ]; then
      echo "contest-matrix: /MATRIXLIST failed ($(matrix_exit_reason "$rc")) -- nothing to run" >&2
      rm -f "$MATRIX_TARGET/$MATRIX_EXE"
      return 1
   fi

   # '|', NOT A TAB: IFS whitespace collapses two adjacent separators, so an
   # empty field (Colorado's DF) would shift every field after it.
   while IFS='|' read -r ord ident spelling p df host; do
      host="${host%$'\r'}"
      [ -n "$ident" ] || continue

      if [ $# -gt 0 ]; then
         want=0
         for s in "$@"; do
            [ "$s" = "$ident" ] && want=1
         done
         [ $want -eq 1 ] || continue
      fi

      rec="$out/$ident.matrix"
      : > "$rec"

      matrix_run_one "$rec" "$ord" "$spelling" us K0AAA KS KS EM17
      rc=$?
      [ $rc -eq 3 ] && break

      if [ "$p" != "0" ]; then
         key=$(matrix_dom_first_key "$df")
         [ -n "$key" ] || key="$host"
         hcall=K0AAA; hsection=KS; hgrid=EM17
         case "$host" in
            VE*) hcall=VE7AAA; hsection=BC; hgrid=CN89 ;;
         esac
         matrix_run_one "$rec" "$ord" "$spelling" us-host "$hcall" "$key" "$hsection" "$hgrid"
         rc=$?
         [ $rc -eq 3 ] && break
      fi

      matrix_run_one "$rec" "$ord" "$spelling" ve VE3AAA ON ON FN03
      rc=$?
      [ $rc -eq 3 ] && break

      matrix_run_one "$rec" "$ord" "$spelling" dx DL1AAA "" DX JO62
      rc=$?
      [ $rc -eq 3 ] && break

      n=$((n+1))
      printf '.'
      [ $((n % 50)) -eq 0 ] && printf ' %d\n' "$n"
   done < "$list"
   printf '\n'

   rm -f "$MATRIX_TARGET/$MATRIX_EXE"
   rm -rf "$MATRIX_WORK/run"

   if [ "${rc:-0}" -eq 3 ]; then
      echo "contest-matrix: REFUSED -- another TR4W holds this install's mutex." >&2
      echo "                Close it (Get-Process -Name tr4w) and run again." >&2
      return 1
   fi

   MATRIX_CAPTURED=$n
   return 0
}

# matrix_report_failures <dir> -- every record line that says something raised
# or a run failed, so neither is ever a quiet pass.  Prints the count.
matrix_report_failures(){
   local dir="$1" f n first
   for f in "$dir"/*.matrix; do
      n=$(grep -c -E '^(RUN FAILED|RAISED)' "$f" 2>/dev/null)
      [ "${n:-0}" -gt 0 ] || continue
      first=$(grep -m1 -E '^(RUN FAILED|RAISED)' "$f" | tr -d '\r')
      printf '    %-24s %3d RUN FAILED/RAISED line(s), first: %s\n' \
         "$(basename "$f" .matrix)" "$n" "$first"
   done
}
