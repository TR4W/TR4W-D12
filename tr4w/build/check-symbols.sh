#!/bin/sh
# ---------------------------------------------------------------------------
# check-symbols.sh -- does the SHIPPED binary still carry what turns an
# address in a crash report into a file and a line?
#
# WHY THIS EXISTS.  build-unix.sh compiles line information INTO the binary
# (-gl, plus -gw2 on Darwin) rather than into a separate file, and until now
# NOTHING asked whether it was still there at the end.  Between the compiler
# and the artifact a user downloads there are several steps that remove debug
# information as a matter of routine and say nothing about it:
#
#   * codesign, and install_name_tool, which rewrite the Mach-O
#   * strip, which a packaging script can acquire in one line
#   * the AppImage pack, which copies the payload through mksquashfs
#
# Every one of those is invisible in a green build.  The symptom arrives
# months later as an operator's backtrace printing bare hex, which is exactly
# the failure the -gw2 work was done to fix.
#
# IT ASKS THE SHIPPED CONTAINER, NOT THE STAGING DIRECTORY.  The caller
# extracts the tarball, mounts the .dmg and unpacks the AppImage and hands
# this script the binary from inside.  Checking build-out/app-*/tr4w would
# prove only that the compiler did its job, which was never in doubt.
#
# EVERY CHECK HAS A FLOOR, AND A TOOL THAT CANNOT READ THE FILE IS A FAILURE.
# A guard that reports "0 found" and passes is the failure mode this tree has
# already had (see CLAUDE.md, "Give every lint a floor").  So each check
# compares a COUNT against a minimum, the minimum is stated in the output, and
# an unreadable binary or a missing tool fails rather than passing quietly.
#
# usage: sh check-symbols.sh <os> <binary> <label>
#        os      linux | darwin
#        binary  path to the executable inside the shipped artifact
#        label   what to call it in the output
#
# exit 0  every check met its floor
# exit 1  a check failed, or the binary could not be read
# exit 2  called wrongly
# ---------------------------------------------------------------------------

set -u

MODE=${1:-}

# TWO CALL FORMS, one UUID comparison.
#
#   <linux|darwin> <binary> <label>   the shipped-artifact check
#   dsym-match <binary> <dsym> <label>   a STAGED .dSYM against the SHIPPED
#                                        binary it claims to describe
#
# The second exists because the .dSYM is deliberately NOT staged beside the
# binary -- it would land inside TR4W.app and double the bundle -- so the
# darwin arm's `$BIN.dSYM` convention cannot reach it.  Both forms end up in
# uuid_match() below: a second copy of that comparison is exactly the kind of
# duplicate that drifts, and getting it wrong is silent (a mismatched .dSYM
# does not refuse, it resolves every address to a confidently wrong line).
if [ "$MODE" = dsym-match ]; then
   BIN=${2:-}
   DSYM=${3:-}
   LABEL=${4:-}
   if [ -z "$BIN" ] || [ -z "$DSYM" ] || [ -z "$LABEL" ]; then
      printf 'usage: %s dsym-match <binary> <dsym> <label>\n' "$0" >&2
      exit 2
   fi
else
   OS=$MODE
   BIN=${2:-}
   LABEL=${3:-}
   if [ -z "$OS" ] || [ -z "$BIN" ] || [ -z "$LABEL" ]; then
      printf 'usage: %s <linux|darwin> <binary> <label>\n' "$0" >&2
      printf '       %s dsym-match <binary> <dsym> <label>\n' "$0" >&2
      exit 2
   fi
fi

say() { printf '%s\n' "$*"; }

FAILED=0

fail() {
   say "      FAIL  $*"
   FAILED=1
}

pass() {
   say "      ok    $*"
}

# need <tool> -- a missing tool is a failed check, never a skipped one.  If
# this runner cannot answer the question then this build has not been checked,
# and saying so is the whole point.
need() {
   if ! command -v "$1" > /dev/null 2>&1; then
      fail "$1 is not installed on this machine -- the symbol check could not run"
      return 1
   fi
   return 0
}

# uuid_match <binary> <dsym>
#
# THE ONE COMPARISON, used by both call forms.
#
# A .dSYM is bound to the binary it was generated from by an LC_UUID the linker
# wrote, and NOTHING downstream changes it -- measured 2026-09-27, the UUID is
# byte-identical before and after codesign, notarize and staple, for both
# tr4w and tr4wserver.  That is what makes this check meaningful: it is the
# only property that survives signing and still identifies one exact build.
#
# Two builds of the SAME VERSION have different UUIDs, so a version match is
# not a match.  And the failure is silent in the worst way: atos given a
# mismatched .dSYM does not refuse, it resolves every address against the wrong
# build and prints confident nonsense.
uuid_match() {
   need dwarfdump || return 1

   _um_bin=$(dwarfdump --uuid "$1" 2>/dev/null | awk '{print $2; exit}')
   _um_dsym=$(dwarfdump --uuid "$2" 2>/dev/null | awk '{print $2; exit}')

   if [ -z "$_um_bin" ]; then
      fail "could not read a UUID from $1 -- not a Mach-O file?"
      return 1
   fi
   if [ -z "$_um_dsym" ]; then
      fail "could not read a UUID from $2 -- is it a .dSYM bundle?"
      return 1
   fi
   if [ "$_um_bin" = "$_um_dsym" ]; then
      pass "UUID matches the binary ($_um_bin)"
      return 0
   fi

   fail "UUID MISMATCH -- the .dSYM is $_um_dsym and the binary is $_um_bin. \
It belongs to a different build, so atos would resolve every address to a \
confidently wrong line rather than refusing"
   return 1
}

say "    $LABEL"
say "      file  $BIN"

if [ ! -f "$BIN" ]; then
   fail "no such file -- nothing was checked"
   exit 1
fi

# THE STAGED-.dSYM FORM ends here: one question, asked and answered.
if [ "$MODE" = dsym-match ]; then
   say "      dsym  $DSYM"
   if [ ! -d "$DSYM" ]; then
      fail "no .dSYM bundle at $DSYM -- nothing was checked"
      exit 1
   fi
   uuid_match "$BIN" "$DSYM" || exit 1
   exit 0
fi

# ---------------------------------------------------------------------------
# THE FLOORS.
#
# Measured against v5.0.23 on linux-ci-build and mac-ci, then rounded down
# hard.  They exist to catch removal, not to pin a number: a stripped binary
# scores zero on all of them, and an ordinary release drifts nowhere near
# them.  Numbers actually observed are in the comment beside each.
# ---------------------------------------------------------------------------
MIN_DECODED_ROWS=1000         # v5.0.23 linux: 1,963,999 bytes of .debug_line,
                              # decoding to far more rows than this
MIN_OSO_ENTRIES=100           # v5.0.23 darwin: 679 debug-map entries
MIN_SYMBOLS=10000             # v5.0.23 darwin: 124,297 symbol table entries
MIN_LINEINFO_SYMBOLS=1        # the lnfodwrf/lineinfo reader must be linked

case "$OS" in

linux)
   # -----------------------------------------------------------------------
   # ELF.  FPC's -gl on x86_64-linux emits DWARF, and the section that
   # matters is .debug_line: that is the address-to-line table, and it is the
   # first thing `strip` removes.  .debug_info can be present with a useless
   # .debug_line, so the size asked for is .debug_line's own.
   # -----------------------------------------------------------------------
   need readelf || exit 1

   # readelf's own exit status, captured separately: a pipeline would report
   # awk's status and this check would become decoration (CLAUDE.md records
   # `stapler validate | tail -3` returning 0 while printing failure).
   _sections=$(readelf -SW "$BIN" 2>/dev/null)
   if [ $? -ne 0 ] || [ -z "$_sections" ]; then
      fail "readelf could not read the section headers -- not an ELF file?"
      exit 1
   fi

   _hasline=$(printf '%s\n' "$_sections" | grep -c '\.debug_line')
   [ -n "$_hasline" ] || _hasline=0
   if [ "$_hasline" -ge 1 ]; then
      pass "the .debug_line section is present"
   else
      fail "no .debug_line section -- line information has been removed from \
the shipped binary"
   fi

   # Present is not the same as decodable, and the row count is the magnitude
   # check: readelf prints the section size in HEX, which no portable shell
   # can compare, whereas decoded rows come out countable and are better
   # evidence anyway -- they are the table actually being read.
   _rows=$(readelf --debug-dump=decodedline "$BIN" 2>/dev/null | wc -l)
   [ -n "$_rows" ] || _rows=0
   if [ "$_rows" -ge "$MIN_DECODED_ROWS" ]; then
      pass "readelf decoded $_rows line-table rows (floor $MIN_DECODED_ROWS)"
   else
      fail "readelf decoded only $_rows line-table rows, floor is \
$MIN_DECODED_ROWS -- the table is present but not usable"
   fi

   # The reader has to be linked too.  Debug information in the file resolves
   # nothing at run time unless the RTL's line-info unit is in the binary to
   # read it, and that is a compile switch someone can drop.
   need nm || exit 1
   _li=$(nm "$BIN" 2>/dev/null | grep -c -i 'lnfodwrf\|lineinfo')
   [ -n "$_li" ] || _li=0
   if [ "$_li" -ge "$MIN_LINEINFO_SYMBOLS" ]; then
      pass "the RTL line-info reader is linked ($_li symbols)"
   else
      fail "no lnfodwrf/lineinfo symbols -- the binary carries a line table \
it cannot read; -gl was not passed"
   fi
   ;;

darwin)
   # -----------------------------------------------------------------------
   # Mach-O, and it behaves nothing like ELF.
   #
   # ld64 does NOT copy DWARF into the executable.  It leaves it in the .o
   # files and writes a DEBUG MAP into the symbol table instead -- one N_OSO
   # stab per object file, naming where the DWARF for that object lives.
   # `dsymutil` is the tool that follows that map and collects the DWARF into
   # a .dSYM bundle.  So on Darwin there is no __DWARF segment to check for,
   # and its absence is not evidence that anything was stripped.
   #
   # MEASURED, v5.0.23 (2026-09-27): the shipped TR4W.app binary has no
   # __DWARF segment, and neither does the binary as the compiler left it.
   # What it does have is 679 OSO entries and a full 124,297-entry symbol
   # table, unchanged by signing, notarization and stapling.
   #
   # So what this checks on Darwin is that the DEBUG MAP AND THE SYMBOL TABLE
   # SURVIVED -- which is precisely what codesign or a stray `strip` would
   # destroy, and is the question asked.  It does NOT claim that a macOS
   # backtrace resolves to a file and a line -- IT DOES NOT, and no file staged
   # beside the binary changes that under FPC 3.2.2.  The reason is in the
   # .dSYM block below and in build-unix.sh's compile(); the short version is
   # that 3.2.2's exeinfo.pp gives every darwin target a 32-bit PowerPC Mach-O
   # reader which can only answer for '.stab' and '.stabstr'.
   #
   # (uCrashLog:336 records the neighbouring half of the same gap from the
   # other side -- GetModuleByAddr cannot answer on Darwin either, because
   # exeinfo installs its Unix hook only for ELF.)
   # -----------------------------------------------------------------------
   need nm || exit 1

   _syms=$(nm -ap "$BIN" 2>/dev/null)
   if [ $? -ne 0 ] || [ -z "$_syms" ]; then
      fail "nm could not read the symbol table -- the binary is stripped, or \
it is not a Mach-O file"
      exit 1
   fi

   _oso=$(printf '%s\n' "$_syms" | grep -c ' OSO ')
   [ -n "$_oso" ] || _oso=0
   if [ "$_oso" -ge "$MIN_OSO_ENTRIES" ]; then
      pass "the debug map survived: $_oso OSO entries (floor $MIN_OSO_ENTRIES)"
   else
      fail "only $_oso OSO entries, floor is $MIN_OSO_ENTRIES -- the debug \
map has been stripped out of the shipped binary"
   fi

   _count=$(printf '%s\n' "$_syms" | wc -l | tr -d '[:space:]')
   [ -n "$_count" ] || _count=0
   if [ "$_count" -ge "$MIN_SYMBOLS" ]; then
      pass "symbol table has $_count entries (floor $MIN_SYMBOLS)"
   else
      fail "symbol table has only $_count entries, floor is $MIN_SYMBOLS -- \
the shipped binary has been stripped"
   fi

   _li=$(nm "$BIN" 2>/dev/null | grep -c -i 'lnfodwrf\|lineinfo')
   [ -n "$_li" ] || _li=0
   if [ "$_li" -ge "$MIN_LINEINFO_SYMBOLS" ]; then
      pass "the RTL line-info reader is linked ($_li symbols)"
   else
      fail "no lnfodwrf/lineinfo symbols -- -gl was not passed, so a crash \
report from this binary cannot name a file even with a .dSYM present"
   fi

   # THE .dSYM, IF ONE IS EVER PRODUCED.  Checked rather than assumed absent,
   # so that the day a dsymutil step is added this gate already validates it
   # -- including the UUID match, which is the one way a .dSYM can be present
   # and silently wrong, and which `atos` requires.
   #
   # IT IS A CHECK AND NOT A REQUIREMENT, and that is measured rather than
   # cautious (2026-09-27).  A .dSYM does NOT make an FPC 3.2.2 backtrace
   # resolve on this platform: exeinfo.pp registers a 32-bit PowerPC Mach-O
   # reader for every darwin target, and it answers only for '.stab' and
   # '.stabstr', so a request for .debug_line cannot be satisfied at all.
   # Proven with a probe built on these flags -- bare addresses with a matching
   # .dSYM staged, and the same probe on Linux naming a unit and a line.
   #
   # So REQUIRING one here would fail every macOS build over a file that cannot
   # help on the operator's machine.  What the .dSYM is genuinely for is
   # OFFLINE symbolisation by us, with `atos` against the addresses and image
   # base uCrashLog already logs -- and that wants the file kept beside the
   # release, not shipped in the bundle.  See docs/INSTALLER_DESIGN.md.
   _dsym="$BIN.dSYM"
   if [ -d "$_dsym" ]; then
      # Its return value is not tested on purpose: uuid_match calls fail(),
      # which sets FAILED, and this script exits on FAILED at the end.  There
      # is no `set -e` here, so a plain call is the whole statement.
      uuid_match "$BIN" "$_dsym"
   else
      say "      note  no .dSYM beside the binary, and none is expected HERE: \
the build stages one for upload instead, because inside TR4W.app it would \
double the bundle to describe a file FPC 3.2.2 cannot read. A backtrace from \
this artifact prints bare addresses; resolve a macOS crash with atos, against \
the image base uCrashLog logs and the UUID in symbols-<version>.txt."
   fi
   ;;

*)
   fail "unknown platform '$OS' -- nothing was checked"
   exit 1
   ;;
esac

exit $FAILED
