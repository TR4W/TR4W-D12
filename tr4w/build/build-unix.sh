#!/bin/sh
#
# The Unix counterpart of tr4w/FullBuild.ps1 -- run ON Linux or macOS, with FPC and
# Lazarus installed natively.
#
#   sh tr4w/build/build-unix.sh               every stage
#   sh tr4w/build/build-unix.sh --app         one stage (--tests --server
#                                             --package --appimage)
#   sh tr4w/build/build-unix.sh --list        what the stages are, and stop
#
# build-linux.sh and build-mac.sh are one-line wrappers around this file. There
# is ONE implementation because the platforms differ in four places -- the
# target name, the widget set, where Lazarus lives, and what a distributable
# artifact IS -- and everything else was identical. Two copies of 700 lines
# would have drifted, and the drift would have been invisible: each is exercised
# on a different machine.
#
# IT LINKS.  This header said "IT IS EXPECTED TO FAIL, AND THAT IS ITS JOB
# TODAY... nothing here is going to link an executable this month", which was
# true when it was written and was false by the end of the same day.  Measured
# 2026-09-08: Linux produces the app, tr4wserver and a tarball; macOS produces
# the app, tr4wserver and a TR4W.app bundle.
#
# THAT SENTENCE IS THE REASON IT IS BEING CORRECTED RATHER THAN QUIETLY DELETED.
# An agent or a developer reading it concludes the port does not build and stops
# looking -- which is exactly the stale-document failure this project keeps
# paying for.  What is genuinely unfinished is stated in the README under
# "Where this actually stands"; the honest short version is that NOBODY HAS RUN
# THE GUI on either platform, and building is not running.
#
# IT STILL DOES NOT STOP AT THE FIRST FAILURE, unlike FullBuild.ps1, and that is
# still right.  On Windows an early stop is correct -- a failing unit test must
# not produce a shippable binary.  Here a red stage is a WORKLIST ITEM, and
# stopping at the first would hide the ones behind it.
# Nothing shippable is produced either way.
#
# AND IT NEVER FAKES A PASS.  No stubbing, no skipping to reach exit 0: a stage
# that cannot run says so and counts as unfinished.  The exit status is 0 only
# if every stage genuinely succeeded, which is a thing that has not happened yet
# and will mean something on the day it does.
#
# ---------------------------------------------------------------------------
# WHAT HAS NO LINUX EQUIVALENT, and is therefore absent rather than ported:
#
#   the version resource   fpcres compiles a Win32 VERSIONINFO into a PE
#                          resource directory.  ELF has no such section and
#                          nothing reads one.  The version is still PARSED here
#                          -- the tarball is named with it -- but it is not
#                          stamped into the binary, so the FullBuild check that
#                          the exe reports the version Version.pas states has no
#                          counterpart.
#   the manifest           Win11.res asks the Windows loader for Common-Controls
#                          v6.  There is no side-by-side assembly on Linux.
#   -WG                    the PE subsystem flag.  ELF has no subsystem field;
#                          a GUI program is one that opens a display.
#   the shipped DLLs       libhamlib, sqlite3 and OpenSSL are packages here, not
#                          files beside the binary.  The architecture check in
#                          Build-App.ps1 guards a Windows-loader failure mode
#                          (0xC000007B before any of our code runs) that the ELF
#                          loader reports properly and at link time.
#   NSIS                   see the packaging stage.
#   the lints              build/Run-Lints.ps1 and the Edit-QSO round-trip are
#                          PowerShell, and several read Windows-only artifacts.
#                          Reported as not-run, never as passed.
#
# ---------------------------------------------------------------------------
# WHY -Mdelphi HERE, WHEN tools/Compile-Linux.ps1 USES -MObjFPC.
#
# The two are answering different questions and both are right for theirs.
#
# Compile-Linux.ps1 is a Windows-hosted cross-compile probe, and it puts
# C:\Lazarus\lcl on the unit path -- the LCL SOURCE, because Lazarus ships no
# compiled LCL for x86_64-linux on a Windows box.  So that probe compiles the
# LCL itself, and the LCL requires objfpc mode: Delphi mode packs sets to one
# byte, which breaks Lazarus's own `Integer(AFont.Style)` in grids.pas.
#
# Nothing of the sort happens natively.  Lazarus 3.0 here ships COMPILED LCL
# units for x86_64-linux, so the LCL is consumed as .ppu and never recompiled --
# exactly as on Windows, where the app build has always used -Mdelphi against
# prebuilt i386-win32 LCL units.  Mode is a property of the unit being compiled,
# not of the ones it uses.
#
# And -Mdelphi is not a preference: tr4w.lpr's uses clause pulls in the vendored
# Indy 10.6.3.3, which is Delphi-mode source.  Building the app in objfpc mode
# would be building a different program.
#
# -Sc (C-style operators) is carried over from compile-native.sh for the same
# reason it is there: anything that reaches lazutils in SOURCE form dies in
# lazfileutils.pas on `Param+=Params[p]`, which reads as a broken Lazarus.

set -u

# ---------------------------------------------------------------------------
# Where we are.  Resolved from the script's own location so the working
# directory is irrelevant -- CI, a shell in build/, and a shell in $HOME all
# have to behave identically.
# ---------------------------------------------------------------------------
BUILD_DIR=$(cd "$(dirname "$0")" && pwd)
TR4W_DIR=$(dirname "$BUILD_DIR")
REPO=$(dirname "$TR4W_DIR")
SRC="$TR4W_DIR/src"
TARGET="$TR4W_DIR/target"
SERVER_DIR="$TR4W_DIR/tr4wserver"
TEST_DIR="$TR4W_DIR/test/unit"
OUTROOT="$REPO/build-out"

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

CPU=$(detect_cpu) || exit 2

# FPC's spelling of the target OS, which is not always the kernel's: Darwin is
# `darwin` to the compiler and `Darwin` to uname.
case "$(uname -s)" in
   Linux)  OS=linux  ;;
   Darwin) OS=darwin ;;
   *)
      echo "Unsupported host $(uname -s). This runs ON the target platform." >&2
      exit 2
      ;;
esac
ARCH="$CPU-$OS"

# The widgetset picks which interfaces.ppu is linked, and IT IS THE PLATFORM:
# cocoa on macOS, gtk2 on Linux (what the Debian and Ubuntu lazarus packages
# build; qt5 exists on some installs). Overridable because getting it wrong
# presents as "Can't find unit Interfaces", which reads as a missing Lazarus
# rather than a missing widgetset.
case "$OS" in
   darwin) LCL_WIDGETSET="${LCL_WIDGETSET:-cocoa}" ;;
   *)      LCL_WIDGETSET="${LCL_WIDGETSET:-gtk2}"  ;;
esac

# ---------------------------------------------------------------------------
# Reporting.  Every stage records a one-line verdict and, when it fails, the
# FIRST compiler error -- the first is the one to act on, and the other 200 are
# usually consequences of it.
# ---------------------------------------------------------------------------
VERDICTS="${TMPDIR:-/tmp}/tr4w-$OS-verdicts.$$"
: > "$VERDICTS"
FAILURES=0

# SKIPS ARE COUNTED, AND THEY DID NOT USED TO BE (fixed 2026-09-20).
#
# record() incremented FAILURES for FAIL only, so a stage that recorded SKIP
# left the run reporting 'ALL STAGES PASSED' -- with the skipped stage printed
# two lines above it, in the same summary.  Measured: `--package` on its own
# printed 'NOT ATTEMPTED: there is no application binary to package' and then
# 'ALL STAGES PASSED'.
#
# A summary that contradicts itself is worse than a wrong one, because the
# last line is the line people quote.  A skipped stage is a stage that did not
# complete: it is counted here, named in the closing text as a skip rather
# than as a failure, and the run exits non-zero.
SKIPS=0

say() { printf '%s\n' "$*"; }

phase() {
   say ''
   say "=== $1 ==="
}

# record <PASS|FAIL|SKIP> <stage> <detail>
record() {
   printf '%s\t%s\t%s\n' "$1" "$2" "$3" >> "$VERDICTS"
   [ "$1" = FAIL ] && FAILURES=$((FAILURES + 1))
   [ "$1" = SKIP ] && SKIPS=$((SKIPS + 1))
   return 0
}

# The first thing the compiler actually objected to.  Fatal and Error are both
# taken: a missing unit is Fatal and stops the run, a type mismatch is Error and
# does not, and the earliest of either is the honest answer.
#
# "ERROR WHILE LINKING" IS NOT A REASON, and reporting it as one wastes the run.
# FPC prints it at the .lpr's last line whatever the linker actually said, so
# the summary reads "tr4w_unit_tests.lpr(427,1) Error: Error while linking" --
# which names a file that is fine and a line that is `end.`  The real answer is
# four lines further down and is specific enough to act on:
#
#     /usr/bin/ld.bfd: cannot find -luser32.dll
#
# So when the compiler's first complaint is the link, ld's own first complaint
# is what gets reported.
first_error() {
   e=$(grep -E '\bFatal:|\bError:' "$1" 2>/dev/null | head -1)
   case "$e" in
      *'Error while linking'*)
         l=$(grep -E '^/[^ ]*ld[^ ]*: ' "$1" 2>/dev/null | head -1)
         [ -n "$l" ] && e="$e -- $l"
         ;;
   esac
   printf '%s' "$e" | cut -c1-200
}

# ---------------------------------------------------------------------------
# STAGE 1 -- the toolchain.
#
# Same contract as build/Find-Toolchain.ps1, including the part that matters
# most: A PIN IS AUTHORITATIVE, NEVER A FIRST GUESS.  If FPC_HOME or LAZARUS_DIR
# names something that will not do, this fails rather than quietly falling
# through to whatever else is installed -- on CI a build that succeeds against a
# toolchain nobody configured is worse than one that fails.
#
# And it lists every location tried.  "Toolchain not found" with no list is the
# least useful build error there is, and the only diagnostic a remote user has.
# ---------------------------------------------------------------------------
SEARCHED=""
looked() { SEARCHED="$SEARCHED  $1
"; }

find_toolchain() {
   phase 'Toolchain'

   FPC=''
   if [ -n "${FPC_HOME:-}" ]; then
      # Either spelling, as Find-Toolchain accepts either: the binary itself or
      # the directory holding it.  CI tends to set a directory and a developer
      # tends to paste the binary; rejecting one of them explains nothing.
      for c in "$FPC_HOME" "$FPC_HOME/fpc" "$FPC_HOME/bin/fpc"; do
         looked "FPC (pinned): $c"
         if [ -x "$c" ] && [ ! -d "$c" ]; then FPC="$c"; break; fi
      done
      if [ -z "$FPC" ]; then
         say "TOOLCHAIN NOT FOUND"
         say "  PINNED FPC REJECTED: $FPC_HOME"
         say "  Nothing executable there.  Discovery is NOT attempted when a pin"
         say "  is given -- fix FPC_HOME or clear it to search instead."
         printf '%s' "$SEARCHED"
         return 1
      fi
   else
      # fpcupdeluxe is how FPC and Lazarus get onto a Mac in practice, and it
      # installs under $HOME rather than anywhere on PATH -- so a Mac with a
      # perfectly good toolchain answers "fpc not found" to `command -v`.
      for c in "$(command -v fpc 2>/dev/null || true)" \
               "$HOME/fpcupdeluxe/fpc/bin/$ARCH/fpc" \
               /usr/bin/fpc /usr/local/bin/fpc /opt/homebrew/bin/fpc; do
         [ -z "$c" ] && continue
         looked "FPC: $c"
         if [ -x "$c" ]; then FPC="$c"; break; fi
      done
   fi

   if [ -z "$FPC" ]; then
      say 'TOOLCHAIN NOT FOUND'
      say "  No fpc on PATH or in the usual places.  Set FPC_HOME."
      printf '%s' "$SEARCHED"
      return 1
   fi

   # THE COMPILER MUST BE ABLE TO TARGET THIS ARCH, which "fpc exists" does not
   # establish -- the Windows script checks for a ppc386 backend and an
   # i386-win32 RTL for exactly this reason.  Natively the equivalent question
   # is whether the RTL for our own target is present, and the cheapest honest
   # test is to ask the compiler to find `system` rather than to guess where the
   # distro put it.  /etc/fpc.cfg carries the RTL paths on a packaged install
   # and there is no fixed directory to test.
   # BEFORE THE PROBE, NOT AFTER. The probe below compiles an empty unit to
   # prove the RTL is reachable -- and on a host whose config does not supply
   # the RTL (fpcupdeluxe), it cannot be reachable until these paths exist.
   # Ordering this wrong reports "its RTL is missing or its config is broken"
   # on a perfectly good toolchain.
   #
   # AND IT CAN FAIL: on macOS it resolves the SDK, and without one nothing
   # links. Propagated, so find_toolchain's own `|| exit 2` stops the run.
   set_fpc_packages || return 1

   FPCVER=$("$FPC" -iV 2>/dev/null)
   probe="${TMPDIR:-/tmp}/tr4w-fpcprobe.$$"
   mkdir -p "$probe"
   printf 'unit tr4wprobe;\ninterface\nimplementation\nend.\n' > "$probe/tr4wprobe.pas"
   # shellcheck disable=SC2086 -- FPC_PKGS is a list of -Fu arguments
   if ! "$FPC" -T$OS -P$CPU $FPC_PKGS -FU"$probe" "$probe/tr4wprobe.pas" > "$probe/log" 2>&1; then
      say 'TOOLCHAIN NOT FOUND'
      say "  $FPC (version ${FPCVER:-unknown}) cannot compile even an empty unit"
      say "  for $ARCH.  Its RTL is missing or its config is broken:"
      sed 's/^/    /' "$probe/log" | head -10
      rm -rf "$probe"
      return 1
   fi
   rm -rf "$probe"

   LAZ=''
   if [ -n "${LAZARUS_DIR:-}" ]; then
      looked "LCL (pinned): $LAZARUS_DIR/lcl/units/$ARCH"
      if [ -d "$LAZARUS_DIR/lcl/units/$ARCH" ]; then
         LAZ="$LAZARUS_DIR"
      else
         say 'TOOLCHAIN NOT FOUND'
         say "  PINNED LAZARUS REJECTED: $LAZARUS_DIR"
         say "  It carries no LCL units for $ARCH.  Discovery is NOT attempted"
         say "  when a pin is given -- fix LAZARUS_DIR or clear it."
         printf '%s' "$SEARCHED"
         return 1
      fi
   else
      # Versioned directories, newest last so the last match wins -- the same
      # rule compile-native.sh uses, and the reason /usr/lib/lazarus/default
      # (a symlink to one of them) is not special-cased: it would just be a
      # second name for a directory already in the list.
      for d in /usr/lib/lazarus/*/ /usr/local/share/lazarus/ "$HOME/fpcupdeluxe/lazarus/"; do
         [ -d "$d" ] || continue
         looked "LCL: ${d}lcl/units/$ARCH"
         [ -d "${d}lcl/units/$ARCH" ] && LAZ=$(cd "$d" && pwd)
      done
   fi

   if [ -z "$LAZ" ]; then
      say 'TOOLCHAIN NOT FOUND'
      say "  No Lazarus carrying LCL units for $ARCH.  Set LAZARUS_DIR."
      printf '%s' "$SEARCHED"
      return 1
   fi

   # A MISSING WIDGETSET IS FATAL, NOT A WARNING (2026-09-14).
   #
   # This used to warn and carry on, and the build then died ~300 lines
   # later with
   #
   #     uLCLCoexist.pas(120,4) Fatal: Can't find unit Interfaces
   #
   # which names a unit rather than the reason. interfaces.ppu lives IN the
   # widgetset directory -- one per widgetset -- so "no cocoa units" and
   # "can't find Interfaces" are the same fact, stated once usefully and
   # once uselessly, with the useful one scrolled off the top.
   #
   # Measured on mac-ci: fpcupdeluxe's Lazarus there carries ONLY nogui, so
   # every macOS GUI build fails this way.
   #
   # AND IT USED TO WORK, WHICH IS THE POINT. That box built
   # tr4w-5.0.2-aarch64-darwin.tar.gz on 2026-09-09 and still has the
   # TR4W.app to prove it. fpcuprevisions.log shows an fpcupdeluxe UPDATE
   # on 14-9-26 02:06 that rebuilt the SAME git hashes (0d122c49 /
   # 62c14a4d) and left the LCL with nogui only. Every path under
   # ~/fpcupdeluxe is stamped 02:08 that morning.
   #
   # So a missing widgetset is not "never provisioned" -- it is something a
   # routine toolchain update can TAKE AWAY overnight, silently, from a
   # machine that shipped an artifact last week. That is exactly why this
   # is fatal here instead of a warning 300 lines from the failure.
   if [ ! -d "$LAZ/lcl/units/$ARCH/$LCL_WIDGETSET" ]; then
      avail=$(ls -d "$LAZ/lcl/units/$ARCH"/*/ 2>/dev/null |
              sed 's|.*/\([^/]*\)/$|\1|' | tr '\n' ' ')
      say 'TOOLCHAIN INCOMPLETE'
      say "  No $LCL_WIDGETSET widgetset units under $LAZ/lcl/units/$ARCH"
      say "  available: ${avail:-(none)}"
      say ''
      say "  interfaces.ppu lives in the widgetset directory, so without it"
      say "  every GUI unit fails with \"Can't find unit Interfaces\" -- which"
      say "  names the symptom, not this."
      say "  Build the $LCL_WIDGETSET LCL in that Lazarus, or set LCL_WIDGETSET"
      say "  to one of the available ones above (nogui builds no GUI)."
      printf '%s' "$SEARCHED"
      return 1
   fi

   say "  FPC       : $FPC (${FPCVER:-unknown})"
   say "  Lazarus   : $LAZ"
   say "  widgetset : $LCL_WIDGETSET"
   return 0
}

# ---------------------------------------------------------------------------
# STAGE 2 -- the version.
#
# FullBuild.ps1's rule, kept verbatim because it is the important half: NOT a
# fallback to 0.0.0.  A release stamped 0.0.0 is worse than no release, and an
# artifact named after a version nobody set is the same defect wearing a
# tarball.
# ---------------------------------------------------------------------------
read_version() {
   VERSION_PAS="$SRC/Version.pas"
   if [ ! -f "$VERSION_PAS" ]; then
      say "could not find $VERSION_PAS"
      return 1
   fi
   # tr -d '\r' first: the tree is CRLF by .gitattributes, and a trailing
   # carriage return inside the captured version would end up in a file name.
   TR4W_VERSION=$(tr -d '\r' < "$VERSION_PAS" |
                  sed -n "s/.*TR4W_CURRENTVERSION_NUMBER[ 	]*=[ 	]*'\([^']*\)'.*/\1/p" |
                  head -1)
   if [ -z "$TR4W_VERSION" ]; then
      say "could not parse TR4W_CURRENTVERSION_NUMBER from $VERSION_PAS"
      return 1
   fi
   return 0
}

# ---------------------------------------------------------------------------
# STAGE 3 -- the search paths.
#
# THE SAME LIST AS build/Get-SearchPaths.ps1, and the same three targets.  It is
# a second copy in a second language, which is exactly what that file's own
# header warns against -- so when a directory is added there, it has to be added
# here.  There is no way around that short of the build system speaking one
# language, and the alternative (a shorter list here) fails as "Can't find unit"
# in whichever target was forgotten, days later.
#
# WHAT DIFFERS FROM WINDOWS, and why:
#
#   ui/lcl BEFORE src        -- identical reasoning: uSettingsBinding exists in
#                               both and search ORDER is the only thing choosing.
#   the widgetset subdir     -- Windows spells it lcl/units/<arch>/win32; here it
#                               is the WIDGETSET name (gtk2), not the OS.  Same
#                               slot, different meaning.
#   the FPC packages         -- not listed at all.  A packaged FPC ships
#                               /etc/fpc.cfg with -Fu.../units/$fpctarget/*,
#                               which already covers regexpr, fcl-json, sqlite,
#                               fcl-db and fcl-base.  Naming them again would be
#                               hardcoding a distro layout for no gain.
#
#                               AND IT COSTS THE SERVER GUARD.  Get-SearchPaths
#                               deliberately withholds sqlite/fcl-db from the
#                               Server target so a unit that grows a database
#                               dependency FAILS THE SERVER BUILD rather than
#                               quietly linking an engine into a relay.  That
#                               guard cannot exist here while the config's
#                               wildcard supplies those units to every compile.
#                               Reported below rather than papered over.
#   datetimectrls            -- source or compiled, whichever is present, same
#                               as compile-native.sh.  uEditQSOForm needs
#                               TDateTimePicker and it is not part of the LCL.
# ---------------------------------------------------------------------------
FU=''
fu_add() { [ -d "$1" ] && FU="$FU -Fu$1"; return 0; }

# THE FPC PACKAGES, ON A HOST WHOSE CONFIG DOES NOT SUPPLY THEM.
#
# A packaged FPC ships /etc/fpc.cfg with a wildcard covering every package, so
# Linux needs none of this -- see the long note above. FPCUPDELUXE, which is how
# FPC gets onto a Mac, writes a config that cannot even find `system`, so there
# the list has to be explicit.
#
# It lives in tools/fpc-unix-paths.sh because compile-native.sh needs exactly
# the same list, and two copies exercised on different machines is how one of
# them silently falls behind.
. "$REPO/tools/fpc-unix-paths.sh"
FPC_PKGS=''
# NOT COMPUTED HERE. $FPC is found by find_toolchain, which runs after this
# file is read, so the value is set at the END of that function instead --
# see set_fpc_packages.
set_fpc_packages() {
   case "$OS" in
      darwin)
         # From .../fpc/bin/<arch>/fpc up to .../fpc, then units/<arch>.
         _fpcroot=$(cd "$(dirname "$FPC")/../.." && pwd)
         FPC_PKGS=$(fpc_unix_package_paths "$_fpcroot/units/$ARCH")
         # And the SDK, without which NOTHING links -- see the note on
         # fpc_darwin_link_flags. These are LINK flags, not unit paths, so they
         # ride along in the same variable rather than earning a second one.
         #
         # CHECKED, NOT ASSUMED. That function used to answer with an empty
         # string when it could not find an SDK, and an absent -XR fails every
         # link with a wall of undefined symbols that names neither the SDK nor
         # this script. It now reports what it asked and returns non-zero; this
         # is a TOOLCHAIN fault, so it stops the run here the same way a
         # missing compiler does, rather than becoming ten red stages.
         if ! _link=$(fpc_darwin_link_flags); then
            say 'TOOLCHAIN NOT USABLE'
            say '  No macOS SDK -- the two xcrun answers are above.'
            return 1
         fi
         FPC_PKGS="$FPC_PKGS$_link"
         ;;
      *)
         # A packaged FPC's /etc/fpc.cfg already supplies these.
         FPC_PKGS=''
         ;;
   esac
   return 0
}

# search_paths <App|Tests|Server>
search_paths() {
   FU=''
   [ "$1" = Tests ] && fu_add "$TEST_DIR"

   fu_add "$SRC/ui/lcl"
   fu_add "$SRC"
   fu_add "$SRC/trdos"
   fu_add "$SRC/utils"
   fu_add "$SRC/lang"
   fu_add "$SRC/domain"
   fu_add "$SRC/radioFactory"
   fu_add "$SRC/contestFactory"
   fu_add "$SRC/rotatorFactory"

   fu_add "$LAZ/lcl/units/$ARCH"
   fu_add "$LAZ/lcl/units/$ARCH/$LCL_WIDGETSET"
   fu_add "$LAZ/components/lazutils/lib/$ARCH"
   fu_add "$LAZ/packager/units/$ARCH"

   # THE WIDGETSET SUBDIRECTORY IS PART OF THE PATH HERE, and missing it is a
   # false portability finding rather than a build-path error.  Lazarus builds
   # this component per widgetset -- lib/x86_64-linux holds ONLY gtk2/ and qt5/
   # and not one .ppu -- so a lookup that stops at lib/<arch> finds a directory,
   # takes it, and the build dies with "Can't find unit DateTimePicker used by
   # uEditQSOForm", which reads as a portability problem in a form that is
   # perfectly portable.  Measured 2026-09-08 on the Ubuntu lazarus package;
   # tools/compile-native.sh has the same lookup and the same gap.
   #
   # The source directory is the last resort and it is a real one: FPC compiles
   # datetimepicker.pas itself, which is what the Windows build already does --
   # Lazarus prebuilds this component for x86_64 only.
   #
   # Each candidate is tested for THE UNIT, not for the directory.  A directory
   # with no datetimepicker in it is not a unit path, and testing -d is what let
   # the arch-level directory swallow the search.
   for d in "$LAZ/components/datetimectrls/lib/$ARCH/$LCL_WIDGETSET" \
            "$LAZ/components/datetimectrls/lib/$ARCH" \
            "$LAZ/components/datetimectrls"; do
      if [ -f "$d/datetimepicker.ppu" ] || [ -f "$d/datetimepicker.pas" ]; then
         fu_add "$d"
         break
      fi
   done

   # The vendored Indy 10.6.3.3 -- kept deliberately, and the reason -Mdelphi is
   # not negotiable for this program.
   fu_add "$TR4W_DIR/include"
   fu_add "$TR4W_DIR/include/Core"
   fu_add "$TR4W_DIR/include/System"
   fu_add "$TR4W_DIR/include/Protocols"

   # LAST, AND THAT ORDER IS LOAD-BEARING: univint ships its own Menus.ppu and
   # ahead of the LCL it shadows the LCL's, after which Forms fails its
   # checksum check and the compiler tries to rebuild it from sources that are
   # not shipped. Empty on Linux, where the config supplies these already.
   FU="$FU$FPC_PKGS"
}

# -Fi is a SEPARATE list and has to be: FPC resolves {$I foo.inc} from the
# including file's own directory and then from -Fi.  It does not search -Fu.
# Log4D.pas lives in include/ and includes src/tr4w.inc, which is why both are
# here -- see Get-Tr4wIncludePaths for the day that cost.
FI="-Fi$SRC -Fi$TR4W_DIR/include"

# ---------------------------------------------------------------------------
# Compiling.
#
# THE OUTPUT DIRECTORY IS CLEARED EVERY TIME, and that is not paranoia.  FPC
# judges staleness on MTIME, which cannot see a changed compiler switch and is
# not a valid test across a rename -- a `git mv` keeps the old mtime, so a .ppu
# built from the file's PREVIOUS home looks current and gets reused.  That
# produced a fully green Windows build against a unit that could not compile
# (2026-08-26).  Here it would be worse: this script's entire output is a list of
# what does not build yet, and a stale artifact silently removes an entry.
#
# compile <label> <workdir> <program.lpr> <outdir> <exe> <extra args...>
# ---------------------------------------------------------------------------
compile() {
   label=$1; workdir=$2; prog=$3; outdir=$4; exe=$5
   shift 5

   rm -rf "$outdir"
   mkdir -p "$outdir"
   log="$OUTROOT/$label-build.log"

   # -gl links the line-info unit, so a crash report carries a file and a line
   # rather than three raw addresses.  Carried over from Build-App.ps1; it is
   # the one debug switch that is worth its size for a program whose users
   # report faults by email.
   #
   # -gw2 -Xg are NOT carried over: -Xg writes the debug info to a separate file
   # through objcopy, which is a binutils dependency this script has no reason
   # to require before anything links at all.  Revisit when it does.
   # -gw2 ON DARWIN. -gl alone links FPC's STABS line-info reader, and on
   # Darwin there are no stabs -- so a crash backtrace prints bare
   # addresses, which is exactly what the first macOS crash produced:
   #
   #     Backtrace:
   #       $0000000104A4A304
   #       $0000000104BD1644
   #
   # With DWARF requested, -gl links lnfodwrf instead and the same
   # backtrace names a unit and a line. Linux resolves without it, and
   # DWARF costs build time and binary size, so it is asked for only
   # where it buys something.
   _dbg='-gl'
   [ "$OS" = darwin ] && _dbg='-gl -gw2'

   # shellcheck disable=SC2086
   ( cd "$workdir" && "$FPC" -Mdelphi -Sc -T$OS -P$CPU $_dbg \
        -FU"$outdir" -o"$exe" $FI $FU "$@" "$prog" ) > "$log" 2>&1
   rc=$?

   errs=$(grep -cE '\bFatal:|\bError:' "$log" 2>/dev/null | head -1)
   say "  log      : $log"
   say "  errors   : $errs"
   if [ "$rc" -ne 0 ]; then
      say "  FAILED (exit $rc)"
      say "  first    : $(first_error "$log")"
      return 1
   fi
   if [ ! -f "$exe" ]; then
      # A zero exit with no binary is not success.  It means the compiler was
      # asked to build a unit rather than a program, or the link was skipped --
      # either way there is nothing to run and nothing to package.
      say "  FAILED: exit 0 but no binary at $exe"
      return 1
   fi
   say "  OK -> $exe ($(($(wc -c < "$exe") / 1024)) KB)"
   return 0
}

# ---------------------------------------------------------------------------
# STAGE 4 -- the application.
# ---------------------------------------------------------------------------
stage_app() {
   phase 'Application'
   search_paths App
   # REMOVED BEFORE THE COMPILE, so "the binary is on disk" means "this run
   # produced it".  Without this a failed link leaves the PREVIOUS run's
   # executable sitting at the same path, and the packaging stage -- which asks
   # the disk, not a shell variable -- would cheerfully tar up a build nobody
   # made today.
   rm -f "$APP_EXE"
   # LANG_ENG selects the ENG string table.  VERSIONINFO_RES is deliberately NOT
   # passed: it links tr4w_versioninfo.res, which is a PE resource that neither
   # exists nor means anything here.
   if compile app "$TR4W_DIR" tr4w.lpr "$OUTROOT/app-$ARCH" "$APP_EXE" -dLANG_ENG; then
      record PASS 'app' "$APP_EXE"
      return 0
   fi
   record FAIL 'app' "$(first_error "$OUTROOT/app-build.log")"
   return 1
}

# ---------------------------------------------------------------------------
# STAGE 5 -- the unit tests.
#
# THE BINARY MUST LAND IN test/unit, not in build-out, and that is a requirement
# of the suites rather than tidiness: several resolve their data from ParamStr(0)
# (fixtures/, and ../../target/cty.dat).  Built anywhere else the result is 30
# red CTYDAT tests and a bare runtime error, neither of which points at the
# cause.
#
# They are run if they build.  Nothing is skipped to protect the exit code -- a
# red suite here is a finding, and a suite that will not even start is a bigger
# one.
# ---------------------------------------------------------------------------
#
# AND IT NEEDS A DISPLAY, which is not obvious and does not fail obviously.
#
# The test binary LINKS THE LCL, so gtk2 opens a display during unit
# initialisation -- before a single assertion runs.  On a headless box that is
#
#     Gtk-WARNING **: cannot open display:
#
# and an exit code of 1, which this stage then recorded as
# "FAIL unit tests (run) exit 1" with an empty tally beside it.  A RED RESULT
# FOR THE WRONG REASON is worse than a red result: it is the shape that gets
# looked at, dismissed as "the known flaky suite", and stops being read.
#
# The wrapping belongs HERE rather than in the caller (the release workflow
# used to wrap the whole script in xvfb-run) because this stage is the one that
# knows why a display is needed.  Wrapped here it is right for a developer over
# ssh, for CI, and for anything else that runs the script -- and the caller
# cannot forget it.
#
# If there is no display AND no xvfb-run, the stage does not run the tests and
# says exactly that.  It is still counted as not-completed -- see record() --
# so nothing goes green on a missing display either.
headless_prefix() {
   # An existing display is used as-is: xvfb-run inside a desktop session is
   # pointless, and nesting it inside an outer xvfb-run would be worse.
   if [ -n "${DISPLAY:-}" ] || [ -n "${WAYLAND_DISPLAY:-}" ]; then
      return 0
   fi
   if command -v xvfb-run >/dev/null 2>&1; then
      printf 'xvfb-run -a'
      return 0
   fi
   return 1
}

stage_tests() {
   phase 'Unit tests'
   search_paths Tests
   rm -f "$TEST_EXE"            # same reason as stage_app
   if ! compile tests "$TEST_DIR" tr4w_unit_tests.lpr "$OUTROOT/tests-$ARCH" "$TEST_EXE"; then
      record FAIL 'unit tests (build)' "$(first_error "$OUTROOT/tests-build.log")"
      return 1
   fi

   if XPRE=$(headless_prefix); then
      [ -n "$XPRE" ] && say '  no display -- running the suite under xvfb-run'
   else
      say '  NOT RUN: this binary links the LCL, so it needs a display, and this'
      say '  machine has neither one nor xvfb-run.  That is a MISSING DISPLAY,'
      say '  not a test result -- install xvfb (apt install xvfb) and re-run.'
      record SKIP 'unit tests (run)' 'no display and no xvfb-run -- not a test result'
      return 1
   fi

   runlog="$OUTROOT/tests-run.log"
   # Unquoted on purpose: $XPRE is either empty or the two words 'xvfb-run -a',
   # and it is built here, not taken from anywhere.
   # shellcheck disable=SC2086
   ( cd "$TEST_DIR" && $XPRE "$TEST_EXE" ) > "$runlog" 2>&1
   trc=$?
   summary=$(grep 'PASSED:' "$runlog" | tail -1)
   [ -n "$summary" ] && say "  $summary"
   if [ "$trc" -ne 0 ]; then
      # A display failure that got this far -- xvfb-run present but unable to
      # start a server, say -- is still not a test result, and is reported as
      # what it is rather than as a red suite.
      if grep -q 'cannot open display' "$runlog"; then
         say '  NOT RUN: the suite could not open a display (see the log).'
         sed -n '1,5p' "$runlog" | sed 's/^/    /'
         record SKIP 'unit tests (run)' 'could not open a display -- not a test result'
         return 1
      fi
      say "  FAILED (exit $trc)"
      grep '\[FAIL\]' "$runlog" | head -10 | sed 's/^/    /'
      record FAIL 'unit tests (run)' "exit $trc; $(printf '%s' "$summary" | cut -c1-80)"
      return 1
   fi
   record PASS 'unit tests' "${summary:-ran clean}"
   return 0
}

# ---------------------------------------------------------------------------
# STAGE 6 -- tr4wserver.
#
# It is an LCL application since 2026-09-06, so it gets the same paths as the
# app.  The one thing it does NOT get on Windows -- sqlite and fcl-db, withheld
# so a database dependency creeping into the relay fails the build -- cannot be
# withheld here; see the search-path header.  Said out loud in the summary so
# nobody reads a green server build as proof of that boundary.
# ---------------------------------------------------------------------------
stage_server() {
   phase 'TR4WServer'
   search_paths Server
   rm -f "$SERVER_EXE"          # same reason as stage_app
   if compile server "$SERVER_DIR" tr4wserver.lpr "$OUTROOT/server-$ARCH" "$SERVER_EXE"; then
      record PASS 'tr4wserver' "$SERVER_EXE"
      return 0
   fi
   record FAIL 'tr4wserver' "$(first_error "$OUTROOT/server-build.log")"
   return 1
}

# ---------------------------------------------------------------------------
# THE LANGUAGES THE BUNDLE DECLARES, TAKEN FROM THE RESOURCE THE BINARY LINKS.
#
# WHY THIS EXISTS AT ALL. macOS lists an application in System Settings >
# General > Language & Region > Applications only if the bundle DECLARES its
# localizations -- CFBundleLocalizations, or .lproj directories under
# Contents/Resources. TR4W has no .lproj and never will: its translations are
# .po catalogues compiled into the executable as RCDATA, which Cocoa cannot
# see. Without the declaration macOS says "TR4W doesn't support additional
# languages" and the operator has no per-app picker at all (NY4I, on mac-ci).
#
# THE LIST IS DERIVED, NEVER TYPED. A hand-written list here would be a second
# definition of what we ship, and it would drift the first time a catalogue is
# added or dropped -- silently, because nothing would compare the two.
#
# THE SOURCE OF TRUTH IS tr4w/res/tr4w_languages.res -- the resource that is
# {$R}-linked into the executable, built from i18n/*.po by
# build/Make-LanguageRes.ps1. It is deliberately NOT the i18n/ directory, which
# is one step upstream: a .po added without regenerating the .res is not in the
# binary, so declaring it would offer the operator a language that silently
# resolves to English.
#
# HOW IT IS READ. fpcres writes resource NAMES as UTF-16LE, so stripping NUL
# bytes leaves them as plain ASCII. The payload is the .po text and no shipped
# catalogue contains the string "TR4W_" (checked), so the match cannot pick up
# content; the LCL_<LANG> entries -- the Lazarus catalogues embedded beside
# ours -- are excluded by the prefix.
#
# THE SPELLING macOS WANTS is BCP 47. Our catalogue keys are lower case with an
# underscore and Apple uses a hyphen with an upper-case region, so pt_BR becomes
# pt-BR. Chinese is the one that is not mechanical: Apple identifies Chinese by
# SCRIPT rather than by country and its own picker offers zh-Hans / zh-Hant.
# Ours is the Simplified catalogue, so zh_CN is declared as zh-Hans.
#
# AND THE PROGRAM AGREES WITH THIS MAPPING RATHER THAN KEEPING ITS OWN. What
# macOS hands back once the operator picks one of these is read by
# uUILanguage.SystemUILanguage and mapped BACK by SystemLanguageCode, which
# turns pt-BR into pt_br and zh-Hans into zh_cn. The two are inverses of each
# other; when a region-qualified catalogue is added, both need the row.
#
# SERBIAN IS DECLARED 'sr', NOT 'sr-Latn', and that is worth knowing: our
# catalogue is Serbian in LATIN script (Dragan Acimovic YT3W), so 'sr-Latn' is
# arguably the truer tag. It is not used because nobody has confirmed how the
# macOS picker labels it, and 'sr' resolves to the same catalogue either way.
# ---------------------------------------------------------------------------
mac_bundle_localizations() {
   res="$TR4W_DIR/res/tr4w_languages.res"
   [ -f "$res" ] || return 0
   LC_ALL=C tr -d '\000' < "$res" \
      | LC_ALL=C grep -ao 'TR4W_[A-Z][A-Z_]*' \
      | sort -u \
      | while read -r name; do
           code=${name#TR4W_}
           case "$code" in
              ZH_CN)
                 printf '    <string>zh-Hans</string>\n'
                 ;;
              *_*)
                 printf '    <string>%s-%s</string>\n' \
                    "$(printf '%s' "${code%%_*}" | tr '[:upper:]' '[:lower:]')" \
                    "${code#*_}"
                 ;;
              *)
                 printf '    <string>%s</string>\n' \
                    "$(printf '%s' "$code" | tr '[:upper:]' '[:lower:]')"
                 ;;
           esac
        done
}

# ---------------------------------------------------------------------------
# STAGE 7 -- packaging.
#
# WHAT A LINUX RELEASE SHOULD BE, since there is no NSIS and no precedent in
# this tree.  A tarball, not a .deb and not an AppImage, for two reasons: a
# tarball needs nothing installed to produce and nothing installed to unpack,
# and TR4W's runtime layout is already relocatable -- the program resolves its
# data from its own directory (ParamStr(0)), which is what makes the corpus and
# the unit tests work at all.  So the natural Linux artifact is the target/
# directory with a binary in it, which is precisely what the Windows installer
# lays down under $INSTDIR.
#
# A .deb or an AppImage is a better answer for actual distribution and both are
# downstream of this: neither is worth designing while the binary does not link,
# and both would need the shared-library question settled first.
#
# THE PAYLOAD IS TAKEN FROM full.nsi, minus what Windows owns:
#
#   shipped      tr4w, tr4wserver, cty.dat, TRMASTER.DTA, cacert.pem, dom/,
#                commands_help_eng.ini, r150s.dat, rfobl.dat,
#                cluster_commands.txt, i18n help catalogues
#   NOT shipped  every .dll.  libhamlib, sqlite3 and OpenSSL are PACKAGES on
#                Linux, resolved by the dynamic linker from the system, not
#                files carried beside the binary.  That is a real difference in
#                kind and not an omission: bundling them would mean vendoring
#                shared objects and setting an rpath, which is a decision
#                nobody has made.  inpout32 has no Linux counterpart at all --
#                LPT keying there is ppdev, which is a port, not a packaging
#                question.
#   NOT shipped  tr4w.dbg.  -Xg is not passed (see compile), so there is none.
#
# It is deliberately built from the STAGED FILES rather than from a manifest of
# names: a file listed and missing must fail the stage, because a tarball that
# is quietly short is the packaging equivalent of a stale .ppu.
# ---------------------------------------------------------------------------
stage_package() {
   phase 'Package'

   if [ ! -f "$APP_EXE" ]; then
      say "  NOT ATTEMPTED: there is no application binary at $APP_EXE."
      say '  Nothing is faked here -- a tarball without tr4w in it would be an'
      say '  artifact that exists only to make this script exit 0.'
      record SKIP 'package' 'no application binary'
      return 1
   fi

   stage="$OUTROOT/dist/tr4w-$TR4W_VERSION-$ARCH"
   rm -rf "$stage"
   mkdir -p "$stage"

   missing=''
   # cacert.pem is the trusted root bundle. It is not optional decoration:
   # without it no server certificate can be verified, on any platform, and
   # FPC does not fall back to a system trust store -- see uTLSTrust.pas.
   for f in cty.dat TRMASTER.DTA commands_help_eng.ini r150s.dat rfobl.dat \
            cluster_commands.txt cacert.pem; do
      if [ -f "$TARGET/$f" ]; then
         cp "$TARGET/$f" "$stage/"
      else
         missing="$missing $f"
      fi
   done
   if [ -d "$TARGET/dom" ]; then
      cp -R "$TARGET/dom" "$stage/dom"
   else
      missing="$missing dom/"
   fi
   # THE INSTALL NOTES TRAVEL WITH THE ARCHIVE, and that is the point of them.
   #
   # A tester who unpacks this has no repository and no wiki -- so a dependency
   # list that lives anywhere else is a dependency list they do not have. The
   # two things that stop TR4W starting on a stock machine are a glibc older
   # than 2.34 and a missing GTK 2, and neither produces a message anyone can
   # act on without being told what it means.
   #
   # NOT FATAL IF ABSENT: a build from a tree without docs/ still produces a
   # working archive, and refusing to package over a missing README would be
   # the wrong trade.
   readme="$REPO/docs/INSTALL_$(echo "$OS" | tr '[:lower:]' '[:upper:]').md"
   if [ -f "$readme" ]; then
      cp "$readme" "$stage/README-INSTALL.md"
   else
      say "  note: no $readme -- the archive ships without install notes."
   fi

   if [ -d "$REPO/i18n" ]; then
      mkdir -p "$stage/help"
      # The help catalogues only; the rest of i18n/ is source for the build.
      for p in "$REPO"/i18n/help_*.po; do
         [ -f "$p" ] && cp "$p" "$stage/help/"
      done
   fi

   # THE PAYLOAD IS THE SAME ON BOTH; ONLY THE LAYOUT DIFFERS.
   #
   # On Linux the binary sits beside its data, which is what a tarball unpacked
   # into ~/tr4w should look like.
   #
   # ON MACOS IT HAS TO BE AN .app BUNDLE, and that is not decoration. A bare
   # Mach-O executable launched from Finder gets no Dock icon, no menu bar and
   # no application activation -- Cocoa decides an app IS an app by finding an
   # Info.plist in Contents/. TR4W would run and appear to do nothing.
   #
   # THE LAYOUT INSIDE THE BUNDLE IS PRESCRIBED by Apple, not chosen here:
   #     TR4W.app/Contents/Info.plist       what makes it an application
   #     TR4W.app/Contents/MacOS/tr4w       the executable, named by the plist
   #     TR4W.app/Contents/Resources/       cty.dat, dom/, the rest
   #
   # SIGNING IS CONDITIONAL, AND IT IS OFF BY DEFAULT. With TR4W_MAC_SIGN=1
   # and the notary credentials set, the bundle, the server binary and the
   # disk image are signed with a Developer ID, notarized and stapled by
   # build/mac-sign.sh -- see the block after the payload check. Without it
   # the artifacts are unsigned, Gatekeeper refuses them on any Mac but the
   # one that built them, and the run says so rather than pretending
   # otherwise.
   if [ "$OS" = darwin ]; then
      bundle="$stage/TR4W.app"
      mkdir -p "$bundle/Contents/MacOS" "$bundle/Contents/Resources"
      # Move the data payload inside the bundle, where a Mac app finds it.
      for item in "$stage"/*; do
         case "$item" in
            "$bundle") continue ;;
         esac
            mv "$item" "$bundle/Contents/Resources/" 2>/dev/null || true
      done
      cp "$APP_EXE" "$bundle/Contents/MacOS/tr4w"
      chmod +x "$bundle/Contents/MacOS/tr4w"

      # FAIL RATHER THAN DECLARE NOTHING. An empty list here is not a
      # cosmetic loss: it is the exact state NY4I hit on the bench, where
      # macOS reports that TR4W supports no additional languages, and it
      # would look identical to a build that simply ships one language.
      localizations=$(mac_bundle_localizations)
      if [ -z "$localizations" ]; then
         say '  FAILED: no languages could be read from tr4w/res/tr4w_languages.res,'
         say '  so the bundle would declare none and the macOS per-app language'
         say '  picker would refuse TR4W.'
         record FAIL 'package' 'no CFBundleLocalizations could be derived'
         return 1
      fi

      cat > "$bundle/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key>              <string>TR4W</string>
  <key>CFBundleDisplayName</key>       <string>TR4W</string>
  <key>CFBundleExecutable</key>        <string>tr4w</string>
  <key>CFBundleIdentifier</key>        <string>net.tr4w.TR4W</string>
  <key>CFBundlePackageType</key>       <string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$TR4W_VERSION</string>
  <key>CFBundleVersion</key>           <string>$TR4W_VERSION</string>
  <key>CFBundleDevelopmentRegion</key> <string>en</string>
  <key>CFBundleLocalizations</key>
  <array>
$localizations
  </array>
  <key>NSHighResolutionCapable</key>   <true/>
  <key>LSMinimumSystemVersion</key>    <string>11.0</string>
</dict>
</plist>
PLIST
      if [ -f "${SERVER_EXE:-}" ]; then
         mkdir -p "$stage/server"
         cp "$SERVER_EXE" "$stage/server/tr4wserver"
      else
         missing="$missing tr4wserver"
      fi
   else
      cp "$APP_EXE" "$stage/tr4w"
      if [ -f "${SERVER_EXE:-}" ]; then
         mkdir -p "$stage/server"
         cp "$SERVER_EXE" "$stage/server/tr4wserver"
      else
         missing="$missing tr4wserver"
      fi
   fi

   if [ -n "$missing" ]; then
      say "  FAILED: payload incomplete --$missing"
      record FAIL 'package' "missing:$missing"
      return 1
   fi

   # -----------------------------------------------------------------
   # macOS: SIGN AND NOTARIZE THE STAGE BEFORE ANYTHING IS ARCHIVED.
   #
   # THE ORDER IS WHY THIS LIVES HERE rather than in the release workflow.
   # Both macOS artifacts are built FROM $stage, and a notarization ticket is
   # stapled INTO TR4W.app -- so an archive rolled before stapling carries an
   # app with no ticket, and the Mac that downloads it has nothing to verify
   # offline. Signing afterwards in CI would mean re-creating the tarball and
   # the disk image there: a second copy of this packaging logic, in a second
   # language, exercised on a different machine, which is exactly the drift
   # this one-implementation script exists to prevent.
   #
   # AND IT MAKES AN UNSIGNED ARTIFACT UNREACHABLE. If signing fails, this
   # returns with NO tarball and NO disk image on disk, so there is nothing
   # for a later step to find and upload. The alternative -- build both, then
   # delete them if signing fails -- is one forgotten `rm` away from
   # publishing the artifact it was meant to prevent.
   #
   # OPT-IN, AND FAIL-CLOSED ONCE IN. Without TR4W_MAC_SIGN=1 a developer
   # build behaves exactly as it did and says out loud that it is unsigned.
   # CI sets it, so a missing credential THERE fails the stage instead of
   # quietly shipping. There is no middle setting.
   # -----------------------------------------------------------------
   SIGNING=0
   if [ "$OS" = darwin ] && [ "${TR4W_MAC_SIGN:-0}" = 1 ]; then
      SIGNING=1
      if ! sh "$BUILD_DIR/mac-sign.sh" app "$stage"; then
         say '  FAILED: the app bundle could not be signed, notarized and stapled.'
         say '  NOTHING IS ARCHIVED. An unsigned tarball or disk image here would'
         say '  be indistinguishable from a signed one to every step after this.'
         record FAIL 'package' 'sign/notarize failed -- no artifact produced'
         return 1
      fi
   fi

   # ON MACOS, A DMG AS WELL -- AND BOTH, NOT ONE.
   #
   # The DMG is the distributable: notarization staples its ticket to a disk
   # image or a directly-submitted zip, and a .tar.gz carries no ticket of its
   # own -- what it carries is the stapled app inside it, which is why the
   # order above matters.
   #
   # THE TARBALL STAYS because deploy-mac.sh globs
   # build-out/dist/tr4w-*-darwin.tar.gz, reads its inner directory with
   # `tar tzf` and extracts it to ~/Applications. Replacing it would break the
   # local deploy path to buy nothing.
   #
   # Same $stage for both, so the two artifacts cannot drift in content.
   #
   # IT IS BUILT BEFORE THE TARBALL, which is a change (2026-09-20): the image
   # is created, signed, notarized and stapled first, so a rejected submission
   # leaves NEITHER artifact behind. Built the other way round, a rejected
   # image would leave a perfectly good tarball beside it and the run would
   # look half-successful.
   dmg=''
   if [ "$OS" = darwin ]; then
      dmg="$OUTROOT/dist/tr4w-$TR4W_VERSION-$ARCH.dmg"
      rm -f "$dmg"
      if ! command -v hdiutil >/dev/null 2>&1; then
         say '  WARNING: hdiutil not found -- the .dmg was not produced'
         dmg=''
      elif ! hdiutil create -volname TR4W -srcfolder "$stage" -ov -format UDZO "$dmg" >/dev/null 2>&1; then
         # Reported, not silent: a missing DMG must not look like a choice.
         say '  WARNING: hdiutil failed -- the .dmg was not produced'
         rm -f "$dmg"
         dmg=''
      else
         say "  OK -> $dmg ($(($(wc -c < "$dmg") / 1024)) KB)"
      fi

      if [ "$SIGNING" = 1 ]; then
         # WITH SIGNING ON, A MISSING DISK IMAGE IS A FAILURE and not a
         # warning. The .dmg is the notarized distributable; a release that
         # quietly carried only the tarball would be shipping the artifact
         # nobody checked.
         if [ -z "$dmg" ]; then
            say '  FAILED: signing is required and no disk image was produced.'
            record FAIL 'package' 'no .dmg to sign'
            return 1
         fi
         if ! sh "$BUILD_DIR/mac-sign.sh" dmg "$dmg"; then
            say '  FAILED: the disk image could not be signed, notarized and stapled.'
            rm -f "$dmg"
            record FAIL 'package' 'dmg sign/notarize failed -- no artifact produced'
            return 1
         fi
      else
         say '  NOT SIGNED AND NOT NOTARIZED. Gatekeeper will refuse these on any'
         say '  Mac but the one that built them, and the message a user gets says'
         say '  the app is damaged rather than unsigned. Set TR4W_MAC_SIGN=1 with'
         say '  an Apple Developer ID and notary credentials to sign; this is a'
         say '  build, not a release.'
      fi
   fi

   tarball="$OUTROOT/dist/tr4w-$TR4W_VERSION-$ARCH.tar.gz"
   rm -f "$tarball"
   ( cd "$OUTROOT/dist" && tar czf "$tarball" "tr4w-$TR4W_VERSION-$ARCH" ) || {
      say '  FAILED: tar'
      rm -f "$tarball"
      [ -n "$dmg" ] && rm -f "$dmg"
      record FAIL 'package' 'tar failed'
      return 1
   }
   say "  OK -> $tarball ($(($(wc -c < "$tarball") / 1024)) KB)"

   # DOES THE TICKET SURVIVE THE TARBALL?  Asked, not assumed.
   #
   # Stapling writes the ticket into the bundle, so in principle tar carries
   # it -- but "in principle" is how an artifact ships that Gatekeeper refuses
   # offline, and the failure would surface on a user's Mac rather than here.
   # So the archive is unpacked into scratch space and the extracted app is
   # put through `stapler validate`, which is the same question the download
   # machine asks. It costs a second and it converts a belief into a check.
   if [ "$SIGNING" = 1 ]; then
      _vt="$OUTROOT/dist/.staple-check.$$"
      _vlog="$OUTROOT/staple-check.log"
      rm -rf "$_vt"
      mkdir -p "$_vt"
      _vrc=0
      # Each status captured on its own, never through a pipe: a pipeline
      # reports sed's exit code, which would make this check decoration.
      ( cd "$_vt" && tar xzf "$tarball" ) > "$_vlog" 2>&1 || _vrc=$?
      if [ "$_vrc" -eq 0 ]; then
         xcrun stapler validate "$_vt/tr4w-$TR4W_VERSION-$ARCH/TR4W.app" \
            >> "$_vlog" 2>&1 || _vrc=$?
      fi
      sed 's/^/    /' "$_vlog"
      rm -rf "$_vt"
      if [ "$_vrc" -ne 0 ]; then
         say '  FAILED: the notarization ticket did not survive the tarball.'
         rm -f "$tarball"
         [ -n "$dmg" ] && rm -f "$dmg"
         record FAIL 'package' 'tarball carries an unstapled app'
         return 1
      fi
      say '  ticket verified inside the tarball'
   fi

   if [ -n "$dmg" ]; then
      record PASS 'package' "$tarball, $dmg"
      return 0
   fi
   record PASS 'package' "$tarball"
   return 0
}

# ---------------------------------------------------------------------------
# STAGE 8 -- the Linux AppImage.
#
# WHY IT IS A STAGE OF ITS OWN, AND NOT PART OF PACKAGING THE WAY THE .dmg IS.
#
# The disk image is built inside stage_package because it HAS to be: both mac
# artifacts are rolled from the same staged bundle and the notarization ticket
# must be stapled into it before either archive exists.  Ordering forces them
# together.
#
# Nothing of the sort is true here.  The AppImage CONSUMES the finished stage
# directory read-only -- it copies out of it and writes one file beside the
# tarball -- so the two artifacts are independent, and independent artifacts
# want independent verdicts.  Folded into stage_package, a failed AppImage
# would have to either fail the whole stage (throwing away a perfectly good
# tarball that a release should still ship) or print a warning and let the
# stage pass (an artifact missing for a reason nobody reads).  A row of its
# own says the true thing: tarball green, AppImage red.
#
# IT RUNS IN THE SAME PROCESS, IMMEDIATELY AFTER PACKAGING, and that is the
# whole point.  A second invocation -- `sh build-unix.sh --package` after an
# `--app` -- was the shape that used to fail on an unset shell variable, and
# splitting the AppImage into a separate CI step would have re-created that
# class of problem in YAML instead of in shell.  One run, one flow, one place
# where the ordering is stated.
#
# Linux only, and quietly so on macOS: an AppImage is a Linux container format
# and its absence there is not a finding.
# ---------------------------------------------------------------------------
stage_appimage() {
   [ "$OS" = linux ] || return 0

   phase 'AppImage'

   # build-appimage.sh names its stage directory and its output x86_64 in two
   # places and has only ever been run there.  On a Pi this would look for a
   # directory that does not exist and report it as a missing payload, which
   # would be a misleading answer to a question nobody has asked yet.
   if [ "$CPU" != x86_64 ]; then
      say "  NOT ATTEMPTED on $CPU: build-appimage.sh is x86_64-only today."
      record SKIP 'appimage' "not supported on $CPU"
      return 1
   fi

   stage="$OUTROOT/dist/tr4w-$TR4W_VERSION-$ARCH"
   if [ ! -d "$stage" ]; then
      say "  NOT ATTEMPTED: there is no staged payload at $stage."
      say '  The AppImage is built FROM the package stage; run --package first.'
      record SKIP 'appimage' 'no staged payload'
      return 1
   fi

   appimage="$OUTROOT/dist/TR4W-$TR4W_VERSION-$CPU.AppImage"
   if ! sh "$BUILD_DIR/build-appimage.sh"; then
      say '  FAILED: build-appimage.sh did not produce an image.'
      # Belt and braces: the script removes its own output before it starts,
      # so this should already be true.  An artifact that a release step might
      # glob is not left to "should".
      rm -f "$appimage"
      record FAIL 'appimage' 'build-appimage.sh failed'
      return 1
   fi
   if [ ! -f "$appimage" ]; then
      say "  FAILED: build-appimage.sh exited 0 with no image at $appimage."
      record FAIL 'appimage' 'exit 0 but no image'
      return 1
   fi
   say "  OK -> $appimage ($(($(wc -c < "$appimage") / 1024)) KB)"
   record PASS 'appimage' "$appimage"
   return 0
}

# ---------------------------------------------------------------------------
# What is NOT run, said explicitly.  A gate that is absent must never be
# mistaken for a gate that passed -- that is the same rule -SkipServer follows
# on Windows, where skipping is loud and marks the build unshippable.
# ---------------------------------------------------------------------------
report_gates_not_run() {
   phase 'Gates NOT run on Linux'
   if command -v pwsh > /dev/null 2>&1; then
      say '  pwsh IS installed here, so build/Run-Lints.ps1 could be attempted --'
      say '  but several lints read Windows-only artifacts (PE headers, .res'
      say '  files, i386 unit output), so a run would mix real findings with'
      say '  noise.  Deciding which of the ten are platform-neutral is its own'
      say '  piece of work and is not guessed at here.'
   else
      say '  build/Run-Lints.ps1        no pwsh on this machine (10 lints)'
   fi
   say '  test/ui/Invoke-FieldCheck  drives the Windows binary'
   say '  version stamp check        no PE version resource on ELF'
   say '  manifest verification      no side-by-side assemblies on Linux'
   say '  DLL architecture check     no bundled DLLs; ELF loader reports this'
   say '  server LCL/sqlite guard    /etc/fpc.cfg supplies the package units to'
   say '                             every compile via its -Fu wildcard, so the'
   say '                             Windows search-path guard has no effect'
   say '                             here.  Do not read a green server build as'
   say '                             evidence the boundary held.'
}

# ---------------------------------------------------------------------------
# Drive.
# ---------------------------------------------------------------------------
WANT=all
case "${1:-}" in
   '')          WANT=all ;;
   --all)       WANT=all ;;
   --app)       WANT=app ;;
   --tests)     WANT=tests ;;
   --server)    WANT=server ;;
   --package)   WANT=package ;;
   --appimage)  WANT=appimage ;;
   --list)
      say 'stages: app  tests  server  package  appimage (linux x86_64 only)'
      exit 0
      ;;
   *)
      say "usage: $0 [--all|--app|--tests|--server|--package|--appimage|--list]" >&2
      exit 2
      ;;
esac

say "TR4W $OS build -- $ARCH"
say "repo: $REPO"

mkdir -p "$OUTROOT"

find_toolchain || exit 2

phase 'Version'
if read_version; then
   say "  TR4W $TR4W_VERSION (from src/Version.pas)"
else
   # Same rule as FullBuild.ps1: no default.  Everything downstream is named
   # after this, so a guess would produce a plausibly-named wrong artifact.
   exit 2
fi

# WHERE EACH STAGE'S OUTPUT LIVES -- SET ONCE, BEFORE ANY STAGE RUNS.
#
# These were assigned INSIDE stage_app and stage_server and initialised to ''
# here, which made a single-stage run of a later stage impossible: with a
# perfectly good binary on disk from an earlier `--app`, `--package` tested an
# empty shell variable and reported 'there is no application binary to
# package'.  The path is a property of the tree, not of what this process
# happened to do, so it is stated once and every stage asks THE DISK.
#
# That is only safe because each producing stage now rm -f's its own output
# before it builds: a stale binary from a previous run cannot survive a failed
# compile and be packaged as though it were current.
APP_EXE="$OUTROOT/app-$ARCH/tr4w"
SERVER_EXE="$OUTROOT/server-$ARCH/tr4wserver"
TEST_EXE="$TEST_DIR/tr4w_unit_tests_$OS"

case "$WANT" in
   all)
      stage_app
      stage_tests
      stage_server
      stage_package
      stage_appimage
      ;;
   app)      stage_app ;;
   tests)    stage_tests ;;
   server)   stage_server ;;
   package)  stage_package ;;
   appimage) stage_appimage ;;
esac

report_gates_not_run

# ---------------------------------------------------------------------------
# The summary IS the worklist.  Read top to bottom: the app blocks the tarball,
# and everything blocks a release.
# ---------------------------------------------------------------------------
phase "Summary -- TR4W $TR4W_VERSION for $ARCH"
TAB=$(printf '	')
while IFS="$TAB" read -r status stage detail; do
   printf '  %-4s  %-22s  %s\n' "$status" "$stage" "$detail"
done < "$VERDICTS"
rm -f "$VERDICTS"

say ''
if [ "$FAILURES" -eq 0 ] && [ "$SKIPS" -eq 0 ]; then
   say 'ALL STAGES PASSED.'
   say 'Note the gates listed above did NOT run -- this is not a shippable build.'
   exit 0
fi

if [ "$FAILURES" -gt 0 ]; then
   say "$FAILURES stage(s) did not complete.  That is the expected answer today:"
   say 'TR4W is a Win32 program being made portable, and the first error of each'
   say 'failing stage above is the next piece of that work.'
fi
if [ "$SKIPS" -gt 0 ]; then
   say "$SKIPS stage(s) were SKIPPED and did not run at all.  A skip is not a"
   say 'pass: the detail beside it says what was missing.'
fi
exit 1
