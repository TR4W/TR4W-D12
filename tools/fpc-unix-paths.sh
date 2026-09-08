#!/bin/sh
#
# The FPC package directories TR4W and the LCL need, for a Unix host that does
# NOT have a config supplying them.
#
# WHY THIS FILE EXISTS AT ALL.  A packaged FPC -- the Debian and Ubuntu fpc
# package -- ships /etc/fpc.cfg carrying `-Fu.../units/$fpctarget/*`, so every
# package is already on the search path and naming them would be hardcoding a
# distro layout for no gain.  FPCUPDELUXE, which is how FPC and Lazarus get onto
# a Mac in practice, writes an fpc.cfg next to the compiler that is NOT enough:
# a bare invocation there cannot even find `system`.  So the Mac needs the list
# and Linux does not.
#
# WHY IT IS SOURCED RATHER THAN COPIED.  It was written twice -- once in
# tools/compile-native.sh and once in tr4w/build/build-unix.sh -- and those two
# scripts are exercised by different people at different times, which is the
# arrangement where one gains a package and the other does not, silently.  This
# project has already had that failure: compile-native.sh's pinned unit list
# drifted three units behind the lint whose name it carried, and nothing
# reported it because a short list only runs FEWER checks and still passes.
#
# NAMED, NOT GLOBBED, and that is not fastidiousness.  There are ~97 package
# directories in an fpcupdeluxe install; adding them all grows the command line
# until the compiler stops finding the RTL, at which point EVERY unit fails with
# "Can't find unit system" and it reads as a broken installation rather than a
# broken invocation.
#
# THE ORDER MATTERS TOO, and the caller owns it: these must come AFTER Lazarus.
# univint ships its own Menus.ppu, and ahead of the LCL it shadows the LCL's --
# the checksum check on Forms then fails and the compiler tries to rebuild it
# from sources that are not shipped.  tools/Compile-Linux.ps1 records the same
# trap with Free Vision's `menus` on Windows.

# fpc_unix_package_paths <units-dir>
#
# Echoes the -Fu arguments for every package present under <units-dir>, which is
# typically $FPCROOT/fpc/units/<arch>.  Absent packages are skipped silently:
# a thinner install should fail with a missing UNIT that names itself, not with
# a path error that does not.
fpc_unix_package_paths() {
   _units=$1
   [ -d "$_units" ] || return 0

   # rtl* first: they are the RTL itself and nothing shadows them.
   # univint  -- MacOSAll, which the LCL's own LCLIntf pulls in on macOS.
   # cocoaint -- the Objective-C bridge the cocoa widget set is built on.
   # chm      -- FastHTMLParser, which Lazarus's Clipbrd needs. Not a Lazarus
   #             unit despite appearances.
   # fcl-json -- jsonscanner, used by Lazarus's Translations.
   # sqlite   -- the contest log.  openssl -- Indy's TLS.
   # pasjpeg/libpng/hermes -- fcl-image declares the readers; the codecs live in
   #             their own packages, so "Can't find unit JPEGLib used by
   #             FPReadJPEG" is what their absence looks like.
   for _p in rtl rtl-objpas rtl-extra rtl-generics rtl-unicode rtl-console \
             fcl-base hash univint cocoaint chm \
             fcl-json fcl-db fcl-net fcl-process fcl-xml fcl-image \
             pasjpeg libpng hermes \
             sqlite openssl regexpr paszlib zlib pthreads iconvenc; do
      [ -d "$_units/$_p" ] && printf ' -Fu%s' "$_units/$_p"
   done
   return 0
}
