#!/bin/sh
#
# Build TR4W on macOS.  A wrapper -- the implementation is build-unix.sh, which
# detects the platform and differs from the Linux run in four places: the target
# name, the widget set (cocoa, not gtk2), where Lazarus lives (fpcupdeluxe under
# $HOME, since that is how FPC and Lazarus get onto a Mac in practice), and what
# it packages -- an .app bundle rather than a tarball of a bare binary.
#
# WHY THE BUNDLE IS NOT DECORATION.  A bare Mach-O executable launched from
# Finder gets no Dock icon, no menu bar and no application activation: Cocoa
# decides an app IS an app by finding an Info.plist in Contents/.  TR4W would
# run and appear to do nothing at all.
#
# WHAT THIS DOES NOT DO, and should not be assumed to:
#
#   IT DOES NOT SIGN OR NOTARIZE.  Gatekeeper refuses an unsigned bundle on any
#   Mac but the one that built it, and the message the user gets says the app is
#   DAMAGED rather than unsigned -- which sends people looking for a corrupt
#   download.  Fixing that needs an Apple Developer ID and is a distribution
#   decision, not a build step.
#
#   IT DOES RUN TO COMPLETION NOW.  This said "IT HAS NOT BEEN RUN TO
#   COMPLETION... the whole unit graph COMPILES, which is not the same as
#   linking an application" -- true when written, false a few hours later, and
#   left behind to tell the next reader the Mac does not build.  Measured
#   2026-09-08: app, tr4wserver and the TR4W.app bundle all produced.
#
#   WHAT IS STILL NOT DONE, so this does not swing too far the other way: the
#   unit tests RUN on macOS and a handful still fail, and NOBODY HAS RUN THE
#   GUI.  Building is not running, and a contest logger is not proven by a
#   linker.
#
# See "Building on macOS" in the README.

exec sh "$(cd "$(dirname "$0")" && pwd)/build-unix.sh" "$@"
