#!/bin/sh
#
# Compile TR4W units for the platform this script is RUNNING ON, to prove they
# are free of Windows.
#
# Replaces tools/compile-darwin.sh, which did the same thing for macOS only.
# Two copies would drift, and the difference between the platforms turned out
# to be four lines: the target name, the CPU, where fpcupdeluxe or the distro
# put the units, and where Lazarus lives.
#
#   ./tools/compile-native.sh uctydat.pas       one unit
#   ./tools/compile-native.sh utils/utils_file.pas
#   ./tools/compile-native.sh --all             the pinned list
#   ./tools/compile-native.sh --tree            MainUnit and everything it
#                                               needs, in ONE pass -- start here
#   ./tools/compile-native.sh --every           EVERY unit under src, as a
#                                               census: how far is the tree?
#
# Exit status is the compiler's for a single unit; for --all and --tree it is
# the compiler's too.  --every always exits 0: it is a measurement, not a gate,
# and a tree that does not fully build yet is the expected answer.
#
# --tree IS THE ONE TO REACH FOR, and --every is almost never what you want.
# FPC already resolves dependencies: pointed at MainUnit it compiles every unit
# MainUnit needs, in order, reusing each .ppu -- ONE walk of the tree.  --every
# asks each of ~1000 units to compile ON ITS OWN with the cache cleared in
# between, so it walks the shared dependencies ~1000 times.  That is minutes
# versus hours, and it is why --every prints progress: it is not hung, it is
# doing something quadratic on purpose.
#
# WHAT --every BUYS FOR THAT PRICE, and it is not nothing: it finds units that
# NOTHING REACHES.  A unit no longer in any uses clause is invisible to --tree
# by definition, and a dead unit that stopped compiling years ago is exactly
# the sort of thing worth knowing before someone reaches for it again.  Run it
# when you want the census; run --tree when you want the answer.
#
# WHY THE PATHS ARE SPELLED OUT.  A glob over every package directory made the
# command line long enough that the compiler stopped finding the RTL at all,
# which presents as "Can't find unit system" for every unit and reads as a
# broken installation rather than a broken invocation.
#
# THE OUTPUT DIRECTORY IS CLEARED PER UNIT.  Sharing it across a run produces a
# FALSE FAILURE: a .ppu left by an earlier unit is picked up by a later one and
# its own dependency can then no longer be satisfied -- "Can't find unit
# version used by VC", for a Version.pas sitting in the same directory as
# everything that had just compiled.  Each unit is asked whether it compiles ON
# ITS OWN, which is also the question worth asking.

set -u

REPO=$(cd "$(dirname "$0")/.." && pwd)
SRC="$REPO/tr4w/src"
OUT="${TMPDIR:-/tmp}/tr4w-native"

# THE CPU COMES FROM THE MACHINE, NOT FROM A CONSTANT (2026-09-08).
#
# This said CPU=x86_64, which is right on exactly one of the boxes this is
# meant to run on. A Raspberry Pi 5 running 64-bit Pi OS is aarch64, and a
# 32-bit Pi OS is arm -- and hardcoding the wrong one does not fail cleanly:
# FPC would look for units under a directory that does not exist and report
# "Can't find unit system", which reads as a broken toolchain.
#
# uname -m is the authority. The mapping is to FPC's OWN spelling of each
# architecture, which is not always the kernel's:
#
#     kernel      FPC      what it is
#     x86_64      x86_64   ordinary 64-bit PC
#     aarch64     aarch64  Pi 4/5 on 64-bit Pi OS, and Apple Silicon
#     armv7l      arm      32-bit Pi OS, and older Pis
#     armv6l      arm      Pi Zero / Pi 1
#     i686        i386     32-bit PC
detect_cpu() {
   case "$(uname -m)" in
      x86_64|amd64)      echo x86_64 ;;
      aarch64|arm64)     echo aarch64 ;;
      armv7l|armv6l|arm) echo arm ;;
      i386|i486|i586|i686) echo i386 ;;
      *)
         echo "Unknown machine $(uname -m) -- add it to detect_cpu." >&2
         return 2
         ;;
   esac
}

case "$(uname -s)" in
   Darwin)
      # Apple Silicon. An Intel Mac would be x86_64; detect_cpu handles both,
      # but the fpcupdeluxe layout below is written for the aarch64 install
      # that exists, so this stays explicit until an Intel Mac needs it.
      CPU=$(detect_cpu) || exit 2
      TARGET=darwin
      ARCH="$CPU-$TARGET"
      FPCROOT="${FPCROOT:-$HOME/fpcupdeluxe}"
      LAZROOT="${LAZROOT:-$FPCROOT/lazarus}"
      FPC="$FPCROOT/fpc/bin/$ARCH/fpc"
      UNITS="$FPCROOT/fpc/units/$ARCH"
      # fpcupdeluxe writes an fpc.cfg next to the compiler and it is NOT
      # enough on its own -- a bare invocation cannot find the RTL.
      FU="-Fu$UNITS/rtl -Fu$UNITS/rtl-objpas -Fu$UNITS/rtl-extra"
      FU="$FU -Fu$UNITS/fcl-base -Fu$UNITS/hash"
      # univint: MacOSAll, which the LCL's own LCLIntf pulls in on this
      # platform -- "Can't find unit MacOSAll used by LCLIntf" is what its
      # absence looks like, and it reads as a broken Lazarus rather than a
      # missing package.
      # cocoaint: the Objective-C bridge the cocoa widget set is built on.
      #
      # NAMED, NOT GLOBBED. There are 97 package directories here and the
      # header above records what happens if you add them all: the command line
      # grows until the compiler stops finding the RTL, and every unit then
      # fails with "Can't find unit system" -- which reads as a broken install.
      FU="$FU -Fu$UNITS/univint -Fu$UNITS/cocoaint"
      LCL="$LAZROOT/lcl/units/$ARCH"
      LAZUTILS="$LAZROOT/components/lazutils/lib/$ARCH"
      ;;
   Linux)
      CPU=$(detect_cpu) || exit 2
      TARGET=linux
      ARCH="$CPU-$TARGET"
      FPC=$(command -v fpc || echo /usr/bin/fpc)
      # The distro packages carry a working /etc/fpc.cfg, so the RTL needs no
      # -Fu here. Lazarus is versioned; take the newest that has LCL units.
      FU=""
      LAZROOT="${LAZROOT:-/usr/lib/lazarus}"
      LCL=""
      for d in "$LAZROOT"/*/lcl/units/$ARCH; do
         [ -d "$d" ] && LCL="$d"
      done
      LAZUTILS=$(dirname "$(dirname "$(dirname "$LCL")")")/components/lazutils/lib/$ARCH
      ;;
   *)
      echo "Unsupported host: $(uname -s). This runs ON the target platform." >&2
      exit 2
      ;;
esac

if [ ! -x "$FPC" ]; then
   echo "No $TARGET compiler at $FPC" >&2
   exit 2
fi
# THE WIDGET SET IS A DIRECTORY LEVEL, and missing it is not obvious from the
# error you get. Lazarus splits its compiled units in two:
#
#     lcl/units/x86_64-linux/           the platform-independent LCL
#     lcl/units/x86_64-linux/gtk2/      the interface for ONE widget set
#
# The first alone gets you a long way -- far enough to compile most of TR4W --
# and then something fails on a unit that looks unrelated.
#
# THE DEFAULT IS PER-PLATFORM, because the widget set IS the platform: cocoa on
# macOS, gtk2 on Linux. Getting it wrong is not fatal -- the note below lists
# what is actually present -- but a wrong default sends the reader looking for
# a broken install rather than a wrong variable. Override with LCL_WIDGETSET
# for a qt5 box.
case "$TARGET" in
   darwin) WS="${LCL_WIDGETSET:-cocoa}" ;;
   *)      WS="${LCL_WIDGETSET:-gtk2}"  ;;
esac

if [ -n "$LCL" ] && [ -d "$LCL" ]; then
   FU="$FU -Fu$LCL"
   if [ -d "$LCL/$WS" ]; then
      FU="$FU -Fu$LCL/$WS"
   else
      # Say so rather than failing later on a unit that reads as OUR problem.
      echo "note: no $WS units under $LCL -- set LCL_WIDGETSET to one of:" >&2
      ls -1 "$LCL" 2>/dev/null | sed 's/^/      /' >&2
   fi
fi
if [ -d "$LAZUTILS" ]; then
   FU="$FU -Fu$LAZUTILS"
fi

# datetimectrls: uEditQSOForm uses TDateTimePicker, an ordinary LCL component
# that is NOT part of the LCL package itself. Its compiled units carry the
# WIDGET SET level too -- lib/x86_64-linux/gtk2 -- which is why the plain
# lib/$ARCH probe found nothing on a distro Lazarus. Distro and fpcupdeluxe
# layouts differ, so try both, and fall back to the SOURCE directory, which the
# compiler can build for itself.
for d in "$LAZROOT"/*/components/datetimectrls/lib/"$ARCH/$WS" \
         "$LAZROOT"/components/datetimectrls/lib/"$ARCH/$WS" \
         "$LAZROOT"/*/components/datetimectrls/lib/"$ARCH" \
         "$LAZROOT"/components/datetimectrls/lib/"$ARCH" \
         "$LAZROOT"/*/components/datetimectrls \
         "$LAZROOT"/components/datetimectrls; do
   if [ -d "$d" ]; then
      FU="$FU -Fu$d"
      break
   fi
done

# EVERY SOURCE DIRECTORY, and this list had drifted from the cross-compile
# probe's (2026-09-08).  It was missing src/lang, src/contestFactory and all
# three vendored Indy directories, so a native run of MainUnit died on
# "Can't find unit IdException used by uFactoryRadioBase" -- which reads as a
# portability finding and is nothing of the sort.  A search-path gap and a real
# Windows dependency produce the SAME message; only the unit name differs, and
# only if you already know which units are ours.
FU="$FU -Fu$SRC -Fu$SRC/utils -Fu$SRC/trdos -Fu$SRC/radioFactory"
FU="$FU -Fu$SRC/rotatorFactory -Fu$SRC/domain -Fu$SRC/ui/lcl"
FU="$FU -Fu$SRC/lang -Fu$SRC/contestFactory"
# The vendored Indy 10.6.3.3 -- the same three directories the app build uses.
FU="$FU -Fu$REPO/tr4w/include"
FU="$FU -Fu$REPO/tr4w/include/Core -Fu$REPO/tr4w/include/System"
FU="$FU -Fu$REPO/tr4w/include/Protocols"

mkdir -p "$OUT"

compile_one() {
   unit=$1
   if [ ! -f "$SRC/$unit" ]; then
      echo "  MISSING     $unit" >&2
      return 2
   fi
   rm -rf "$OUT"
   mkdir -p "$OUT"
   # shellcheck disable=SC2086
   "$FPC" -Mdelphi -Sc -T$TARGET -P$CPU -FU"$OUT" -Fi"$SRC" $FU "$SRC/$unit" \
      > "$OUT/last.log" 2>&1
}

first_error() {
   grep -E 'Fatal:|Error:' "$OUT/last.log" | head -1 |
      sed 's|.*/||' | cut -c1-78
}

# THE PINNED LIST IS READ FROM THE LINT, NOT COPIED FROM IT.
#
# It used to be a literal here under the comment "mirrors
# tr4w/build/Lint-LinuxCompile.ps1", and by 2026-09-08 it did not: the lint had
# eighteen units and this had fifteen, missing uStickyKeys, utils/uAudio and
# GetWinVersionInfo.  Nothing reported that, because a list that is short only
# runs FEWER checks -- it passes.  A drifting copy whose failure mode is a
# quieter pass is the worst kind, so there is one list now and this reads it.
#
# The lint's rows look like
#     @{ Unit = 'uBandLookup.pas'; Since = '2026-09-06' }
# except one, which spells its separator as [char]92 to keep a backslash out of
# a PowerShell string:
#     @{ Unit = 'utils' + [char]92 + 'uAudio.pas'; Since = '2026-09-08' }
#
# SO IT IS NORMALISED FIRST, THEN EXTRACTED ONCE.  Trying to do both with two
# alternative patterns in one sed script does not work and fails QUIETLY: the
# general pattern also matches the [char]92 line and yields a bare 'utils',
# which is then reported as a MISSING UNIT rather than as a parsing bug.  One
# pattern, applied to text that has been made uniform, has no such arm.
LINT="$REPO/tr4w/build/Lint-LinuxCompile.ps1"
read_pinned() {
   if [ ! -f "$LINT" ]; then
      echo "No $LINT -- cannot read the pinned unit list." >&2
      return 2
   fi
   sed "s/' *+ *\[char\]92 *+ *'/\\\\/g" "$LINT" |
      sed -n "s/.*Unit *= *'\([^']*\)'.*/\1/p" |
      tr '\\' '/'
}

if [ $# -eq 0 ]; then
   echo "usage: $0 <unit.pas> | --all | --tree | --every" >&2
   exit 2
fi

case "$1" in
   --all)
      ok=0; bad=0
      ALL=$(read_pinned) || exit 2
      if [ -z "$ALL" ]; then
         echo "The pinned list came back EMPTY -- the lint's format changed." >&2
         echo "Refusing to report success on nothing." >&2
         exit 2
      fi
      for u in $ALL; do
         if compile_one "$u"; then
            ok=$((ok + 1)); echo "  OK       $u"
         else
            bad=$((bad + 1)); echo "  blocked  $u"; echo "             $(first_error)"
         fi
      done
      echo
      echo "compile-native ($ARCH): $ok compiled, $bad blocked"
      [ "$bad" -eq 0 ]
      exit $?
      ;;

   --tree)
      # ONE dependency walk, which is what the compiler is for.  The output
      # directory is NOT cleared between units here -- reuse is the whole
      # point, and the false-failure trap the header describes applies to
      # INDEPENDENT compiles, not to a single graph the compiler is ordering
      # itself.
      rm -rf "$OUT"
      mkdir -p "$OUT"
      echo "compile-native ($ARCH): MainUnit.pas and everything it needs..."
      # shellcheck disable=SC2086
      "$FPC" -Mdelphi -Sc -T$TARGET -P$CPU -FU"$OUT" -Fi"$SRC" $FU \
             "$SRC/MainUnit.pas"
      status=$?
      if [ "$status" -eq 0 ]; then
         echo
         echo "COMPILES: MainUnit and its whole dependency graph, for $ARCH."
      fi
      exit $status
      ;;

   --every)
      # A CENSUS, not a gate. Prints the blocking reason for each failure,
      # collapsed and counted, because the same missing unit accounts for
      # dozens of them and the RANKING is the worklist.
      ok=0; bad=0
      reasons="$OUT.reasons"
      : > "$reasons"
      list=$(cd "$SRC" && find . -name '*.pas' \
              ! -path './backup/*' ! -path './graphify-out/*' \
              | sed 's|^\./||' | sort)
      total=$(printf '%s\n' "$list" | wc -l | tr -d ' ')
      n=0
      echo "compile-native ($ARCH) CENSUS: $total unit(s), each compiled ON ITS"
      echo "OWN with the cache cleared between them. This is SLOW BY DESIGN --"
      echo "use --tree if you want the answer rather than the census."
      echo
      for u in $list; do
         n=$((n + 1))
         # Progress on ONE line to stderr, so a redirected stdout still holds
         # nothing but the result. Without this the run looks hung for an hour.
         printf '\r  [%d/%d] %-46s' "$n" "$total" "$u" >&2
         if compile_one "$u"; then
            ok=$((ok + 1))
         else
            bad=$((bad + 1))
            first_error >> "$reasons"
         fi
      done
      printf '\r%-70s\r' '' >&2
      echo "compile-native ($ARCH) CENSUS: $ok compiled, $bad failed"
      echo
      echo "top blocking reasons:"
      sed 's/^[^ ]*([0-9,]*) //' "$reasons" | sort | uniq -c | sort -rn | head -20
      exit 0
      ;;

   *)
      compile_one "$1" && { echo "  OK       $1"; exit 0; }
      echo "  blocked  $1"
      grep -E 'Fatal:|Error:' "$OUT/last.log" | head -5 | sed 's/^/             /'
      exit 1
      ;;
esac
