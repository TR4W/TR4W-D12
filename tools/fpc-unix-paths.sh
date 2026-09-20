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
             fcl-json fcl-db fcl-net fcl-web fcl-process fcl-xml fcl-image \
             pasjpeg libpng hermes \
             sqlite openssl regexpr paszlib zlib pthreads iconvenc; do
      [ -d "$_units/$_p" ] && printf ' -Fu%s' "$_units/$_p"
   done
   return 0
}

# fpc_darwin_link_flags
#
# The macOS SDK, as -XR (sysroot) and -Fl (library path).  Empty off Darwin.
#
# WITHOUT THIS, NOTHING LINKS ON A MAC -- not TR4W, not a three-line WriteLn
# program:
#
#     ld: library 'c' not found
#     Error: Error while linking
#
# fpcupdeluxe writes an fpc.cfg pinning
# /Library/Developer/CommandLineTools/SDKs/MacOSX.sdk, and on a machine where
# Xcode is the real toolchain that is the WRONG SDK for the ld actually being
# run.  Both SDKs exist and both contain libc.tbd, which is why the error is so
# unhelpful: the library is there, and the linker is looking in the other place.
#
# xcrun IS THE AUTHORITY, BUT ONLY WHEN IT IS ASKED THE RIGHT QUESTION, and
# that distinction cost the v5.0.11 and v5.0.12 release runs.
#
# MEASURED ON mac-ci, 2026-09-20 (macOS 27.0, Xcode 26.2):
#
#     xcrun --show-sdk-path          /Library/Developer/CommandLineTools/SDKs/MacOSX.sdk
#                                    -> the 27.0 SDK
#     xcrun --sdk macosx --show-sdk-path
#                                    -> Xcode's own MacOSX26.2.sdk
#     xcodebuild -version            errors: it cannot locate the 27.0 SDK at all
#
# The bare form answers with the Command Line Tools SDK, which on that machine
# was a MAJOR VERSION AHEAD of the Xcode whose ld actually ran.  Compiling
# against 27.0 and linking with Xcode 26.2's linker ended every link in
#
#     Undefined symbols for architecture arm64:
#       _CFArrayGetCount, _CFArrayGetValueAtIndex, _AXIsProcessTrusted
#     ld: symbol(s) not found for architecture arm64
#
# -- CoreFoundation and ApplicationServices, i.e. it reads as a broken LCL and
# not as a mismatched SDK.  Proven by cloning the v5.0.11 TAG, which had built
# successfully the day before, on that machine: it failed identically, and the
# one-line change to --sdk macosx made it PASS.
#
# THAT MACHINE HAS SINCE MOVED ON, which is the point rather than a footnote:
# re-measured hours later the same day, mid-update, it carried Xcode 27.0 and
# BOTH xcrun forms answered `rc=69, You have not agreed to the Xcode license
# agreements`.  So the pair of answers this function reasons about changes
# under it without warning -- do not re-derive the rule from whatever the box
# says today, and do not conclude the bare form is now safe because the two
# happen to agree again.
#
# SO ASK FOR THE macosx SDK BY NAME FIRST.  Compiler, SDK and linker have to
# come from ONE install; `--sdk macosx` resolves through the selected developer
# directory, which is the same install that supplies the ld being invoked.  The
# bare form is a separate default that is free to disagree with it, and on a
# machine carrying both Xcode and the Command Line Tools it eventually does.
#
# The bare form is kept as a FALLBACK for a machine that has the Command Line
# Tools and no Xcode at all.  UNVERIFIED (2026-09-20): whether `--sdk macosx`
# answers correctly on such a machine has not been measured here -- no
# CLT-only Mac was available -- so the fallback is coded rather than assumed
# away.  If it turns out `--sdk macosx` always answers there too, this branch
# becomes dead code and can go; do not delete it on reasoning alone.
#
# AND IT FAILS LOUDLY IF NEITHER ANSWERS.  This used to `return 0` on every
# failure path, emitting NO flags at all -- and a missing -XR produces the same
# wall of undefined symbols as the wrong one, so the silent path and the
# wrong-SDK path are indistinguishable from the output.  It now prints what it
# asked and what each answered, and returns non-zero; the caller stops.
#
# The two "obsolete flag" warnings FPC 3.2.2 provokes from a modern ld
# (-macosx_version_min, -multiply_defined) are noise, not failure; the link
# succeeds through them.
fpc_darwin_link_flags() {
   [ "$(uname -s)" = Darwin ] || return 0

   if ! command -v xcrun >/dev/null 2>&1; then
      printf '%s\n' 'MACOS SDK NOT FOUND: xcrun is not on PATH.' >&2
      printf '%s\n' '  Install the Xcode command line tools (xcode-select --install).' >&2
      return 1
   fi

   # BOTH ANSWERS ARE TAKEN, so the diagnostic below can report what each one
   # said rather than only that the chosen one was unusable.  Neither is
   # allowed to abort the function: a missing SDK is reported by this function,
   # not by xcrun's exit status.
   _sdk_named=$(xcrun --sdk macosx --show-sdk-path 2>/dev/null) || _sdk_named=''
   _sdk_default=$(xcrun --show-sdk-path 2>/dev/null) || _sdk_default=''

   _sdk=''
   if [ -n "$_sdk_named" ] && [ -d "$_sdk_named" ]; then
      _sdk=$_sdk_named
   elif [ -n "$_sdk_default" ] && [ -d "$_sdk_default" ]; then
      # The Command-Line-Tools-only case described in the header.  Said out
      # loud, because on a machine that HAS Xcode this branch would mean the
      # named lookup broke and the link is about to use a possibly mismatched
      # SDK -- which is the failure this whole function exists to prevent.
      _sdk=$_sdk_default
      printf '%s\n' "macOS SDK: 'xcrun --sdk macosx' gave nothing usable; falling back to 'xcrun --show-sdk-path' ($_sdk_default)." >&2
      printf '%s\n' '  Expected on a machine with the Command Line Tools and no Xcode.  On a machine with Xcode this is a warning: compiler, SDK and linker must come from one install.' >&2
   fi

   if [ -z "$_sdk" ]; then
      # LOUDLY, AND NAMING BOTH QUESTIONS.  Emitting nothing here is what made
      # this expensive: the build carries on, every link fails on undefined
      # symbols, and nothing in the output mentions an SDK.
      printf '%s\n' 'MACOS SDK NOT FOUND -- refusing to link without one.' >&2
      printf '%s\n' "  xcrun --sdk macosx --show-sdk-path -> ${_sdk_named:-<no answer>}" >&2
      printf '%s\n' "  xcrun --show-sdk-path             -> ${_sdk_default:-<no answer>}" >&2
      printf '%s\n' '  Neither named a directory that exists.  Check xcode-select -p, and' >&2
      printf '%s\n' '  that the selected developer directory really holds an SDK.' >&2
      return 1
   fi

   printf ' -XR%s -Fl%s/usr/lib' "$_sdk" "$_sdk"

   # FRAMEWORKS THE LCL REFERENCES BUT DOES NOT ASK FOR.
   #
   # Lazarus's cocoawsextctrls.o references UNUserNotificationCenter and
   # friends -- the UserNotifications framework, which Apple split out of
   # Foundation. Without it the link ends in a wall of
   #
   #     "_OBJC_CLASS_$_UNUserNotificationCenter", referenced from:
   #     ld: symbol(s) not found for architecture arm64
   #
   # which reads as a broken LCL rather than a missing -framework. -k passes
   # the flag through FPC to ld, and it takes ONE argument, so the framework
   # name needs its own -k.
   printf ' -k-framework -kUserNotifications'

   # THE CLASSIC LINKER, because FPC 3.2.2 predates Apple's new one.
   #
   #     ld: malformed method list atom 'ltmp5'
   #         (.../lcl/units/aarch64-darwin/cocoa/cocoawsextctrls.o),
   #         fixups found beyond the number of method entries
   #
   # That is the Xcode 15+ linker rejecting Objective-C metadata that FPC
   # 3.2.2 -- released in 2021 -- still emits in the older layout. It is not a
   # corrupt object file and not a Lazarus bug; the same .o links fine under
   # the previous linker, which Apple still ships as -ld_classic.
   #
   # THIS IS A DATED WORKAROUND AND SHOULD BE REVISITED. Apple has deprecated
   # -ld_classic and will eventually drop it, at which point the answer becomes
   # a newer FPC (3.3.1 fixed the metadata layout) rather than an older linker.
   # Written down here so that when it stops working the cause is not a mystery.
   printf ' -k-ld_classic'
   return 0
}
