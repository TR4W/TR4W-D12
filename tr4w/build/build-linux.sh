#!/bin/sh
#
# Build TR4W on Linux.  A wrapper -- the implementation is build-unix.sh.
#
# THERE IS ONE IMPLEMENTATION ON PURPOSE.  Linux and macOS differ in four
# places: the target name, the widget set, where Lazarus lives, and what a
# distributable artifact IS (a tarball of a binary, versus an .app bundle).
# Everything else -- toolchain discovery, every search path, the version parse,
# the four stages, the reporting, the list of gates that cannot run off Windows
# -- was identical.
#
# Two copies of seven hundred lines would have drifted, and THE DRIFT WOULD HAVE
# BEEN INVISIBLE, because each copy is exercised on a different machine: a fix
# made on the Linux box would simply not be there the next time someone built on
# the Mac, and nothing would report it.  That is the same failure this project
# has already had twice today -- compile-native.sh's pinned list quietly falling
# behind the lint it claimed to mirror, and the Free Vision search-path lesson
# living in a comment in one probe while the other tripped over it.
#
# This file exists so the documented command keeps working and so `ls build/`
# still shows a Linux build script.  It is not a place to add behaviour: put it
# in build-unix.sh, where both platforms get it.

exec sh "$(cd "$(dirname "$0")" && pwd)/build-unix.sh" "$@"
