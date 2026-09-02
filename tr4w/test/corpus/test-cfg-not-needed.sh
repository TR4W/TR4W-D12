#!/bin/bash
#
# THE CONTEST .cfg MUST NOT BE NECESSARY -- phase E3.
#
# NY4I: "when done, the .cfg file should not be necessary."
#
# A contest .cfg is read ONCE, when the log is created, and captured into the
# log's config table.  From then on the LOG says what the contest is.  This
# asserts it the only way that means anything: export a log normally, then EMPTY
# THE .cfg TO ZERO BYTES and export again, and require the same Cabrillo.
#
# The file itself still has to exist, because its NAME is how a contest is
# selected and where the log's name comes from.  Its CONTENTS are what must not
# be needed.
#
# WHY THIS IS A SEPARATE TEST FROM THE CORPUS.  The corpus always has a full
# .cfg beside every log, so it cannot tell a value that came from the log from
# one that came from the file -- and for a log created by this build the two
# agree by construction.  Only removing the file's contents separates them.
#
# THREE THINGS THIS CAUGHT while it was being made to pass, none of which the
# corpus could see:
#
#   CheckCommand's first parameter is declared PAnsiChar and then read as
#   @Command[1] -- a pointer to a SHORTSTRING, whose byte 0 is its length.
#   Passing PAnsiChar of an AnsiString matched 'CONTEST' as 'ONTEST', so every
#   command was rejected with a warning that blamed the value.
#
#   CONTEST's crA hook is not idempotent: applying it twice built the domestic
#   file name from itself -- dom\iaruhq.domiaruhq.dom -- so the file could not
#   be opened and the export produced nothing.  Only settings that DIFFER are
#   applied now.
#
#   ConfigurationOkay halted on "No callsign specified" from inside
#   ReadInConfigFile, halfway through assembling the configuration and before
#   the log had contributed anything.  It runs once, at the end, now.
#
# CURRENT STATE: 11 of 13 identical.  arrl_dx_cw and general_qso still differ,
# and for an ORDERING reason rather than a missing setting -- every command in
# both .cfg files IS captured and applied.  MY CALL now arrives from the LOG,
# which is later than the .cfg used to supply it, so anything derived from the
# callsign DURING config load (country, continent) is computed while it is still
# empty.  In ARRL-DX that decides whether the received exchange is a power or a
# section, and every QSO renders "DX".
#
# The fix is to recompute callsign-derived state after every source has
# contributed, not to capture more.  The two rows stay here as a failing
# measurement rather than being excluded, because excluding them would hide it.
#
# Usage:  bash tr4w/test/corpus/test-cfg-not-needed.sh
set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
TARGET="$REPO_ROOT/tr4w/target"
EXE_SRC="$REPO_ROOT/build-out/app-i386-win32/tr4w_fpc.exe"
EXE="cfgtest-run.exe"
WORK="cfgnotneeded"

if [ ! -f "$EXE_SRC" ]; then
   echo "test-cfg-not-needed: no app at $EXE_SRC -- build first" >&2
   exit 1
fi

cd "$TARGET" || exit 1
cp "$EXE_SRC" "$EXE" || exit 1

norm() { sed -E 's/(Created by TR4W version .* on ).*/\1TIME/; s/(<CREATED_TIMESTAMP:15>).*/\1TIME/' "$1" 2>/dev/null; }

pass=0; fail=0
for d in "$REPO_ROOT"/tr4w/test/corpus/*/; do
   name=$(basename "$d")
   [ -f "$d/log.trw" ] || continue

   rm -f "$WORK".* ./*.LOG
   cp "$d/log.cfg" "$WORK.CFG" || continue
   cp "$d/log.trw" "$WORK.TRW" || continue

   # With the .cfg: migrates the binary log in and captures the configuration.
   MSYS_NO_PATHCONV=1 timeout 60 "./$EXE" "$WORK.CFG" /EXPORT >/dev/null 2>&1
   with=$(mktemp -d); cp "$WORK.ADI" "$with/" 2>/dev/null; cp ./*.LOG "$with/" 2>/dev/null
   produced=$(ls "$with" 2>/dev/null)

   # Without it.  The file stays -- it names the contest -- but says nothing.
   : > "$WORK.CFG"
   rm -f "$WORK.ADI" ./*.LOG
   MSYS_NO_PATHCONV=1 timeout 60 "./$EXE" "$WORK.CFG" /EXPORT >/dev/null 2>&1

   ok=1; detail=""
   if [ -z "$produced" ]; then
      ok=0; detail=" (the run WITH a .cfg produced nothing, so this proves nothing)"
   fi
   for f in $produced; do
      if [ ! -f "$f" ]; then
         ok=0; detail="$detail $f(missing)"
      elif ! diff <(norm "$with/$f") <(norm "$f") >/dev/null 2>&1; then
         ok=0; detail="$detail $f"
      fi
   done
   rm -rf "$with"

   if [ $ok -eq 1 ]; then
      printf "  SAME  %-28s\n" "$name"; pass=$((pass+1))
   else
      printf "  DIFF  %-28s -->%s\n" "$name" "$detail"; fail=$((fail+1))
   fi
done

rm -f "$WORK".* ./*.LOG "$EXE"

echo "=== with a .cfg vs an EMPTY .cfg: $pass identical, $fail differing ==="
[ $fail -eq 0 ] || exit 1
exit 0
