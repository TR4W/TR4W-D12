#!/bin/sh
#
# Compile ONE unit for aarch64-darwin, to prove it is free of Windows.
#
# The macOS counterpart of tools/Compile-Linux.ps1, and it exists for the same
# reason: a {$IFDEF WINDOWS} that has never been compiled for anything else is
# a guess.  Runs ON THE MAC -- there is no macOS cross compiler on the Windows
# box -- so the loop is: push from Windows, `git pull` here, run this.
#
#   ./tools/compile-darwin.sh uCTYDAT.PAS
#   ./tools/compile-darwin.sh utils/utils_file.pas      # subdirectories work
#   ./tools/compile-darwin.sh --all                     # the pinned list
#
# Exit status is the compiler's: 0 means the unit built for Darwin.
#
# WHY THE PATHS ARE SPELLED OUT HERE.  fpcupdeluxe writes an fpc.cfg next to
# the compiler, and it is NOT enough on its own -- a bare invocation fails with
# "Can't find unit system", so the RTL has to be named explicitly.  Three more
# had to be added one error at a time, and each is worth knowing:
#
#   -Fi<src>     tr4w.inc is included by almost every unit, and the include
#                path is separate from the unit path.  Without it the failure
#                surfaces inside Log4D, which is confusing.
#   hash         supplies `crc`, which uCRC32 uses.
#   include/     the vendored Indy tree, and `tr4wserial` -- the serial unit
#                FPC does not build for Darwin at all, which is why it is
#                vendored.  uSerialPort compiles here because of it.

set -u

REPO=$(cd "$(dirname "$0")/.." && pwd)
FPCROOT="${FPCROOT:-$HOME/fpcupdeluxe}"
LAZROOT="${LAZROOT:-$FPCROOT/lazarus}"

CPU=aarch64
ARCH="$CPU-darwin"
FPC="$FPCROOT/fpc/bin/$ARCH/fpc"
UNITS="$FPCROOT/fpc/units/$ARCH"

if [ ! -x "$FPC" ]; then
   echo "No Darwin compiler at $FPC" >&2
   echo "Set FPCROOT if fpcupdeluxe is installed elsewhere." >&2
   exit 2
fi

if [ ! -d "$UNITS/rtl" ]; then
   echo "No aarch64-darwin RTL at $UNITS/rtl" >&2
   exit 2
fi

SRC="$REPO/tr4w/src"
OUT="${TMPDIR:-/tmp}/tr4w-darwin"

# CLEARED EVERY RUN, and searched.
#
# Both halves were missing and together they produced a phantom failure: a
# STALE .ppu from an earlier run made FPC recompile a unit it should have
# reused, and the recompile failed on a dependency that resolves perfectly
# well when compiled directly -- "Can't find unit version used by VC", for a
# Version.pas sitting right there. Compiling the same unit by hand then
# succeeded, which is the signature of stale state rather than broken source.
rm -rf "$OUT"
mkdir -p "$OUT"

# The unit search path, smallest set that works. Kept explicit rather than
# globbed over every package directory: a glob of all ~100 made the command
# line long enough that the compiler stopped finding the RTL at all, which
# presents as "Can't find unit system" for every unit and looks like a broken
# installation rather than a broken invocation.
FU="-Fu$UNITS/rtl -Fu$UNITS/rtl-objpas -Fu$UNITS/rtl-extra -Fu$UNITS/fcl-base"
FU="$FU -Fu$UNITS/hash"
FU="$FU -Fu$LAZROOT/lcl/units/$ARCH"
FU="$FU -Fu$LAZROOT/components/lazutils/lib/$ARCH"
FU="$FU -Fu$SRC -Fu$SRC/utils -Fu$SRC/trdos -Fu$SRC/radioFactory -Fu$SRC/domain"
FU="$FU -Fu$REPO/tr4w/include"
FU="$FU -Fu$OUT"   # units built earlier in this run

compile_one() {
   unit=$1
   if [ ! -f "$SRC/$unit" ]; then
      echo "  MISSING     $unit" >&2
      return 2
   fi
   # shellcheck disable=SC2086
   if "$FPC" -Mdelphi -Sc -Tdarwin -P$CPU -FU"$OUT" -Fi"$SRC" $FU "$SRC/$unit" \
        > "$OUT/last.log" 2>&1; then
      echo "  DARWIN OK   $unit"
      return 0
   fi
   echo "  blocked     $unit"
   grep -E 'Fatal|Error' "$OUT/last.log" | head -3 | sed 's/^/                /'
   return 1
}

# The pinned list mirrors tr4w/build/Lint-LinuxCompile.ps1. It is NOT a gate
# yet -- nothing runs this automatically -- so it is a report, and adding a
# unit here is a note that it compiled on some particular day, not a promise.
ALL="uWindowSnap.pas
uAppPaths.pas
uRussiaOblasts.pas
uCRC32.pas
uAccelerators.pas
uBandLookup.pas
uADIF.pas
utils/utils_file.pas
VC.pas
cty.pas
uCTYDAT.PAS
uCallSignRoutines.pas
ComPortEnumerator.pas
uSerialPort.pas
uYCCCSO2R.pas"

if [ $# -eq 0 ]; then
   echo "usage: $0 <unit.pas> | --all" >&2
   exit 2
fi

if [ "$1" = "--all" ]; then
   ok=0
   bad=0
   for u in $ALL; do
      if compile_one "$u"; then ok=$((ok+1)); else bad=$((bad+1)); fi
   done
   echo
   echo "compile-darwin: $ok compiled, $bad blocked"
   [ "$bad" -eq 0 ]
   exit $?
fi

compile_one "$1"
