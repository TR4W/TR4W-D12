#!/bin/sh
# Is tr4w/res/tr4w_languages.res made from the catalogues in this checkout?
#
#   sh tr4w/build/check-language-res.sh        # exit 0 current, 1 stale, 2 cannot tell
#
# THE UNIX HALF OF build/LanguageResStamp.ps1. Windows REGENERATES the .res when
# its inputs change; Linux and macOS cannot (the generator is PowerShell and
# runs fpcres from a Windows-hosted FPC), so they must at least REFUSE to ship a
# stale one. Before 2026-10-16 nothing compared the two, and two catalogue
# commits sat unlinked in the tracked .res for two weeks while every build was
# green.
#
# THE DEFINITION OF "CURRENT" IS LanguageResStamp.ps1's, reproduced here: the
# stamp tr4w/res/tr4w_languages.res.inputs holds a mode line and one
# "<sha256>  <path>" line per input (every i18n/tr4w_*.po in ordinal order, then
# Make-LanguageRes.ps1 and LanguageResStamp.ps1), each hashed with CR bytes
# removed so a line-ending conversion on checkout cannot make a clone look
# stale. If you change the rule, change BOTH files; the PowerShell side is the
# one that writes the stamp.
#
# ONE implementation: build-unix.sh calls this, and so can a human.

BUILD_DIR=$(cd "$(dirname "$0")" && pwd)
TR4W_DIR=$(dirname "$BUILD_DIR")
REPO=$(dirname "$TR4W_DIR")
STAMP="$TR4W_DIR/res/tr4w_languages.res.inputs"
RES="$TR4W_DIR/res/tr4w_languages.res"

# The mode the build produces; LanguageResStamp.ps1 $script:LanguageResModeDefault.
MODE=fuzzy-included

if command -v sha256sum > /dev/null 2>&1; then
   sha() { sha256sum | cut -d' ' -f1; }
elif command -v shasum > /dev/null 2>&1; then
   sha() { shasum -a 256 | cut -d' ' -f1; }
else
   echo "check-language-res: no sha256sum or shasum on PATH; cannot tell." >&2
   exit 2
fi

if [ ! -f "$RES" ]; then
   echo "check-language-res: STALE -- tr4w/res/tr4w_languages.res is missing." >&2
   exit 1
fi
if [ ! -f "$STAMP" ]; then
   echo "check-language-res: STALE -- tr4w/res/tr4w_languages.res.inputs is missing." >&2
   exit 1
fi

WANT=$(mktemp "${TMPDIR:-/tmp}/langres-want.XXXXXX") || exit 2
HAVE=$(mktemp "${TMPDIR:-/tmp}/langres-have.XXXXXX") || exit 2
trap 'rm -f "$WANT" "$HAVE"' EXIT INT TERM

printf 'mode  %s\n' "$MODE" > "$WANT"
# The .po names, sorted by BYTE value so the order matches the ordinal sort in
# PowerShell ('.' sorts before '_': tr4w_pt.po, then tr4w_pt_BR.po).
for f in $(ls "$REPO"/i18n/tr4w_*.po | sed "s|^$REPO/||" | LC_ALL=C sort) \
         tr4w/build/Make-LanguageRes.ps1 tr4w/build/LanguageResStamp.ps1; do
   if [ ! -f "$REPO/$f" ]; then
      echo "check-language-res: cannot tell -- input $f is missing." >&2
      exit 2
   fi
   printf '%s  %s\n' "$(tr -d '\r' < "$REPO/$f" | sha)" "$f" >> "$WANT"
done

# The stamp as written has comment lines and may have CRLF; compare the rest.
tr -d '\r' < "$STAMP" | grep -v '^#' | grep -v '^$' > "$HAVE"

if cmp -s "$WANT" "$HAVE"; then
   echo "check-language-res: tr4w_languages.res is current ($(grep -c 'i18n/' "$WANT") catalogues)."
   exit 0
fi

echo "check-language-res: STALE -- tr4w_languages.res was not built from the catalogues in this tree." >&2
echo "  differing inputs (< expected from tree, > recorded in the stamp):" >&2
diff "$WANT" "$HAVE" | grep '^[<>]' | sed 's/^/    /' >&2
echo "  Fix: on Windows, run tr4w/build/Build-App.ps1 (or Make-LanguageRes.ps1) and commit" >&2
echo "  tr4w/res/tr4w_languages.res together with tr4w_languages.res.inputs." >&2
exit 1
