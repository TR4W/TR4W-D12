#!/bin/sh
#
# build-tailcat.sh -- build libtailcat (.so on Linux, .dylib on macOS) from the
# pinned upstream commit.  The Unix counterpart of Build-Tailcat.ps1; read that
# file's header for why the library is built and not committed (issue 293).
#
#   sh tr4w/build/build-tailcat.sh              build, or say "up to date"
#   sh tr4w/build/build-tailcat.sh --force      build even when up to date
#   sh tr4w/build/build-tailcat.sh --jobs 2     fewer parallel compiles
#
# linux-ci-build has 2.4 GB of memory: use --jobs 2 there.  Go links Tailscale's
# whole data plane and an unbounded build has been seen to swap on a 4 GB Pi.
#
# WHAT IT NEEDS ON THE MACHINE
#   git, curl, tar, awk, and sha256sum or shasum
#   a C compiler: cc on PATH (gcc on Linux, Apple clang on macOS), or TAILCAT_CC
#   Go: NOT needed beforehand.  A `go` on PATH is used when it is EXACTLY the
#       pinned version; otherwise the official archive is downloaded, checked
#       against the sha256 in tailcat.pin and unpacked under build-out/.
#
# WHERE THINGS GO.  Everything is under <repo>/build-out/tailcat (TAILCAT_WORK
# moves it), which is ignored with the rest of build-out:
#   toolchain/go<version>/   the Go toolchain, when it had to be downloaded
#   src/                     the upstream checkout
#   gopath/  gocache/        Go's caches; nothing is written to $HOME
#   <cpu>-<os>/libtailcat.so | .dylib       the result
#   <cpu>-<os>/libtailcat.built.txt         what it was built from (cache key)
#   <cpu>-<os>/libtailcat-NOTICES.txt       the licence of every module linked
#
# IT DOES NOT STAGE THE LIBRARY INTO A PACKAGE.  TR4W looks for it in
# uAppPaths.PrivateLibraryDir: beside the binary on Linux, Contents/Frameworks
# in TR4W.app on macOS.  Putting it there is the packaging step's job
# (build-unix.sh), and on macOS it must be there BEFORE mac-sign.sh runs: that
# script signs every file in Contents/Frameworks with the hardened runtime, and
# one unsigned library fails notarization of the whole bundle.
#
# IT FAILS CLOSED, on the same four things Build-Tailcat.ps1 does.

set -eu

HERE=$(cd "$(dirname "$0")" && pwd)
REPO_ROOT=$(cd "$HERE/../.." && pwd)
WORK=${TAILCAT_WORK:-$REPO_ROOT/build-out/tailcat}
PIN_FILE="$HERE/tailcat.pin"

FORCE=0
JOBS=0
while [ $# -gt 0 ]; do
   case "$1" in
      --force) FORCE=1 ;;
      --jobs)  shift; JOBS=${1:-0} ;;
      *) echo "build-tailcat: unknown argument: $1" >&2; exit 2 ;;
   esac
   shift
done

fail() {
   echo "build-tailcat: FAILED: $*" >&2
   exit 1
}

# One value from the pin file.  The file is CRLF on a Windows checkout, so the
# carriage return is dropped here.
pin() {
   _v=$(tr -d '\r' < "$PIN_FILE" | awk -F= -v k="$1" '$1 == k { print substr($0, length(k) + 2); exit }')
   [ -n "$_v" ] || fail "tailcat.pin: $1 is missing"
   printf '%s\n' "$_v"
}

sha256_of() {
   if command -v sha256sum > /dev/null 2>&1; then
      sha256sum "$1" | awk '{ print $1 }'
   else
      shasum -a 256 "$1" | awk '{ print $1 }'
   fi
}

# ---------------------------------------------------------------------------
# The target.  Named the way build-unix.sh names it (<cpu>-<os>).
# ---------------------------------------------------------------------------
case "$(uname -s)-$(uname -m)" in
   Linux-x86_64)
      TARGET=x86_64-linux;   GO_PLATFORM=linux-amd64;  PIN_KEY=GO_SHA256_LINUX_AMD64
      GOOS=linux;  GOARCH=amd64; LIB=libtailcat.so ;;
   Darwin-arm64)
      TARGET=aarch64-darwin; GO_PLATFORM=darwin-arm64; PIN_KEY=GO_SHA256_DARWIN_ARM64
      GOOS=darwin; GOARCH=arm64; LIB=libtailcat.dylib ;;
   *)
      fail "no pinned Go toolchain for $(uname -s) $(uname -m); add its sha256 to tailcat.pin and a case here" ;;
esac

REPO=$(pin TAILCAT_REPO)
COMMIT=$(pin TAILCAT_COMMIT)
GO_VERSION=$(pin GO_VERSION)
GO_SHA256=$(pin "$PIN_KEY")

case "$COMMIT" in
   *[!0-9a-f]*) fail 'tailcat.pin: TAILCAT_COMMIT must be a full commit id, not a tag or a branch' ;;
esac
[ ${#COMMIT} -eq 40 ] || fail 'tailcat.pin: TAILCAT_COMMIT must be a full 40-character commit id'

OUT_DIR="$WORK/$TARGET"
OUT="$OUT_DIR/$LIB"
STAMP="$OUT_DIR/libtailcat.built.txt"
NOTICES="$OUT_DIR/libtailcat-NOTICES.txt"
SRC="$WORK/src"

echo "build-tailcat: tailcat $COMMIT, Go $GO_VERSION, target $TARGET"

show_result() {
   echo "   file     $OUT"
   echo "   bytes    $(wc -c < "$OUT" | tr -d ' ')"
   echo "   sha256   $(sha256_of "$OUT")"
   if command -v file > /dev/null 2>&1; then
      echo "   kind     $(file -b "$OUT")"
   fi
}

# ---------------------------------------------------------------------------
# Up to date?
# ---------------------------------------------------------------------------
stamp_value() {
   awk -F= -v k="$1" '$1 == k { print substr($0, length(k) + 2); exit }' "$STAMP"
}

if [ "$FORCE" = 0 ] && [ -f "$STAMP" ] && [ -f "$OUT" ] && [ -f "$NOTICES" ]; then
   if [ "$(stamp_value commit)" = "$COMMIT" ] &&
      [ "$(stamp_value go)" = "$GO_VERSION" ] &&
      [ "$(stamp_value sha256)" = "$(sha256_of "$OUT")" ]; then
      echo 'build-tailcat: up to date, nothing built.'
      show_result
      exit 0
   fi
fi

# ---------------------------------------------------------------------------
# Go: the one on PATH only when it is exactly the pinned version.
# ---------------------------------------------------------------------------
GO=''
if command -v go > /dev/null 2>&1; then
   if [ "$(go version 2>/dev/null)" = "go version go$GO_VERSION $GOOS/$GOARCH" ]; then
      GO=$(command -v go)
   fi
fi
if [ -z "$GO" ]; then
   TOOL_ROOT="$WORK/toolchain/go$GO_VERSION"
   GO="$TOOL_ROOT/go/bin/go"
   if [ ! -x "$GO" ]; then
      ARCHIVE="go$GO_VERSION.$GO_PLATFORM.tar.gz"
      mkdir -p "$TOOL_ROOT"
      echo "   downloading https://go.dev/dl/$ARCHIVE"
      curl -fsSL -o "$WORK/toolchain/$ARCHIVE" "https://go.dev/dl/$ARCHIVE"
      GOT=$(sha256_of "$WORK/toolchain/$ARCHIVE")
      if [ "$GOT" != "$GO_SHA256" ]; then
         rm -f "$WORK/toolchain/$ARCHIVE"
         fail "$ARCHIVE has sha256 $GOT, tailcat.pin says $GO_SHA256"
      fi
      tar -xzf "$WORK/toolchain/$ARCHIVE" -C "$TOOL_ROOT"
      rm -f "$WORK/toolchain/$ARCHIVE"
   fi
fi
echo "   go       $GO"

# ---------------------------------------------------------------------------
# The source, at exactly the pinned commit.
# ---------------------------------------------------------------------------
if [ ! -d "$SRC/.git" ]; then
   mkdir -p "$WORK"
   git clone --quiet --no-checkout "$REPO" "$SRC"
fi
if ! git -C "$SRC" rev-parse --verify --quiet "$COMMIT^{commit}" > /dev/null; then
   git -C "$SRC" fetch --quiet origin
fi
# --force: a previous run's checkout is ours to replace, and nothing else is
# ever edited in this directory.
git -C "$SRC" checkout --quiet --force --detach "$COMMIT"

HEAD_NOW=$(git -C "$SRC" rev-parse HEAD)
[ "$HEAD_NOW" = "$COMMIT" ] || fail "the checkout is at '$HEAD_NOW', not the pinned $COMMIT"
[ -z "$(git -C "$SRC" status --porcelain)" ] ||
   fail "the checkout in $SRC has local changes; delete the directory and run again"
echo "   source   $SRC at $HEAD_NOW"

# ---------------------------------------------------------------------------
# The C compiler.
# ---------------------------------------------------------------------------
CC_BIN=${TAILCAT_CC:-}
if [ -z "$CC_BIN" ]; then
   CC_BIN=$(command -v cc || command -v gcc || command -v clang || true)
fi
[ -n "$CC_BIN" ] || fail 'no C compiler (cc, gcc or clang) on PATH; cgo needs one. Name it in TAILCAT_CC.'
echo "   cc       $CC_BIN ($("$CC_BIN" -dumpmachine 2>/dev/null || echo unknown))"

# ---------------------------------------------------------------------------
# The build: upstream's own release settings (its build-tags.md).
# ---------------------------------------------------------------------------
[ -f "$SRC/build-tags.txt" ] || fail 'upstream build-tags.txt is missing at the pinned commit'
TAGS=$(tr -d '\r\n' < "$SRC/build-tags.txt")

mkdir -p "$OUT_DIR"
rm -f "$OUT" "$STAMP" "$NOTICES" "$OUT_DIR/libtailcat.h"

export CGO_ENABLED=1
export GOOS GOARCH
export CC="$CC_BIN"
export GOTOOLCHAIN=local          # never fetch a different Go behind our back
export GOFLAGS=-mod=readonly      # go.sum decides; the build may not edit it
export GOPATH="$WORK/gopath"
export GOCACHE="$WORK/gocache"

STARTED=$(date +%s)
if [ "$JOBS" -gt 0 ]; then
   ( cd "$SRC" && "$GO" build -p "$JOBS" -buildmode=c-shared -trimpath \
        -ldflags='-s -w' -tags "$TAGS" -o "$OUT" ./cmd/libtailcat ) || fail 'go build'
else
   ( cd "$SRC" && "$GO" build -buildmode=c-shared -trimpath \
        -ldflags='-s -w' -tags "$TAGS" -o "$OUT" ./cmd/libtailcat ) || fail 'go build'
fi
echo "   built in $(( $(date +%s) - STARTED )) s"

[ -f "$OUT" ] || fail 'go build reported success and wrote no library'

# ---------------------------------------------------------------------------
# The notices.  The library is Tailcat PLUS every Go module linked into it.  The
# list is read out of the library itself (`go version -m`), so it is what was
# linked; the texts come from the module cache this build just used.
#
# write_notices <library> <module cache> <go root> <tailcat source>
# ---------------------------------------------------------------------------
write_notices() {
   _lib=$1
   _cache=$2
   _goroot=$3
   _src=$4
   _missing=''
   _count=0

   # "name<TAB>directory" for each thing linked in.  A "=>" line replaces the
   # module on the line before it.  The module cache spells an upper-case
   # letter as "!" and its lower-case form.
   {
      printf '%s\t%s\n' "github.com/tailscale/tailcat $COMMIT" "$_src"
      printf '%s\t%s\n' "Go $GO_VERSION (runtime and standard library)" "$_goroot"
      "$GO" version -m "$_lib" | awk -F'\t' -v cache="$_cache" '
         function escaped(s,   i, c, r) {
            r = ""
            for (i = 1; i <= length(s); i++) {
               c = substr(s, i, 1)
               if (c ~ /[A-Z]/) { r = r "!" tolower(c) } else { r = r c }
            }
            return r
         }
         $2 == "dep" { if (held != "") print held; held = $3 " " $4 "\t" cache "/" escaped($3) "@" escaped($4) }
         $2 == "=>"  { held = $3 " " $4 "\t" cache "/" escaped($3) "@" escaped($4) }
         END         { if (held != "") print held }'
   } > "$OUT_DIR/notices.list"

   {
      echo 'libtailcat -- third-party notices'
      echo
      echo "libtailcat is Tailscale's Tailcat ($REPO)"
      echo "built from commit $COMMIT with Go $GO_VERSION for $TARGET."
      echo 'It contains the Go runtime and the modules listed below. The licence text of'
      echo 'each follows, as its authors published it.'
      echo
   } > "$NOTICES"

   _tab=$(printf '\t')
   while IFS="$_tab" read -r _name _dir; do
      [ -n "$_name" ] || continue
      _count=$((_count + 1))
      {
         echo '=============================================================================='
         echo "$_name"
         echo '=============================================================================='
      } >> "$NOTICES"
      _found=0
      for _f in "$_dir"/*; do
         [ -f "$_f" ] || continue
         case "$(basename "$_f")" in
            LICENSE|LICENSE[.-]*|LICENCE|LICENCE[.-]*|COPYING|COPYING[.-]*|NOTICE|NOTICE[.-]*|PATENTS|PATENTS[.-]*|AUTHORS|AUTHORS[.-]*|COPYRIGHT|COPYRIGHT[.-]*)
               _found=1
               {
                  echo
                  echo "--- $(basename "$_f") ---"
                  echo
                  cat "$_f"
                  echo
               } >> "$NOTICES" ;;
         esac
      done
      if [ "$_found" = 0 ]; then
         _missing="$_missing $_name;"
      fi
   done < "$OUT_DIR/notices.list"
   rm -f "$OUT_DIR/notices.list"

   if [ -n "$_missing" ]; then
      rm -f "$NOTICES"
      fail "no licence file found for:$_missing a binary may not ship without them"
   fi
   [ "$_count" -ge 3 ] || { rm -f "$NOTICES"; fail '`go version -m` listed no modules in the library'; }
   echo "   notices  $NOTICES ($_count modules)"
}

write_notices "$OUT" "$GOPATH/pkg/mod" "$("$GO" env GOROOT)" "$SRC"

# ---------------------------------------------------------------------------
# Stamp it.
# ---------------------------------------------------------------------------
{
   echo "commit=$COMMIT"
   echo "repo=$REPO"
   echo "go=$GO_VERSION"
   echo "target=$TARGET"
   echo "sha256=$(sha256_of "$OUT")"
} > "$STAMP"

echo 'build-tailcat: BUILD OK'
show_result
exit 0
