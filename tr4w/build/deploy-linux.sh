#!/bin/bash
#
# DEPLOY THE LINUX BUILD -- to the Mint bench box, and to NAS2.
#
# ---------------------------------------------------------------------------
# WHY THIS RUNS ON WINDOWS AND NOT ON THE BUILD HOST
# ---------------------------------------------------------------------------
#
# Three machines are involved and no two of them can see everything:
#
#   linux-ci-build     builds.  Ubuntu, FPC + Lazarus, NO radio, NO display,
#                      and no route to the NAS share.
#   192.168.1.182      runs.  Linux Mint, the FTDI radio hardware and a
#                      display, and NO toolchain and no source tree.
#   this Windows box   has W: mapped to \\nas2\shared, and ssh to both.
#
# So the developer workstation is the only place that can reach the artifact,
# the bench box and the archive, which is why the script lives here rather
# than on either Linux machine.  It pulls, it pushes, it verifies.
#
# ---------------------------------------------------------------------------
# WHAT IT DOES NOT DO
# ---------------------------------------------------------------------------
#
# IT DOES NOT BUILD.  A deploy script that silently rebuilds hides which
# binary you are testing, and the whole reason the Mint box exists is to run
# a known artifact.  Build first:
#
#     ssh linux-ci-build 'cd ~/projects/TR4W-D12 && \
#         sh tr4w/build/build-unix.sh --app --server --package'
#
# IT DOES NOT TOUCH settings/ OR ANY LOG ON THE BENCH BOX.  The tarball is
# unpacked into a VERSIONED directory and a `current` symlink is moved, so an
# operator's tr4w.json, their contest .db files and tr4w.log all survive a
# deploy and a rollback is one symlink.
#
# Usage:
#     sh tr4w/build/deploy-linux.sh                 # bench box + NAS2
#     sh tr4w/build/deploy-linux.sh --nas-only      # archive only
#     sh tr4w/build/deploy-linux.sh --bench-only    # no NAS write
#
set -u

BUILD_HOST=linux-ci-build
BENCH_HOST=192.168.1.182
BENCH_ROOT='~/tr4w'
NAS_DIR='/w/TR4WInstalls/New/Linux'

do_bench=1
do_nas=1
for arg in "$@"; do
   case "$arg" in
      --nas-only)   do_bench=0 ;;
      --bench-only) do_nas=0 ;;
      -h|--help)    sed -n '2,45p' "$0"; exit 0 ;;
      *) echo "deploy-linux: unknown option '$arg'" >&2; exit 2 ;;
   esac
done

say() { printf '%s\n' "$*"; }
die() { printf 'deploy-linux: %s\n' "$*" >&2; exit 1; }

# --- 1. WHAT IS THERE TO DEPLOY -------------------------------------------
#
# ASK THE BUILD HOST rather than assuming a version.  A hardcoded 5.0.2 would
# deploy yesterday's tarball on the day Version.pas changes, and the failure
# would look like "the fix is not in the build".
say '== finding the artifact on '"$BUILD_HOST"
# THE GLOB IS DELIBERATELY LOOSE ON THE MIDDLE AND TIGHT ON THE ENDS. The
# artifact is named tr4w-<version>-<arch>-linux.tar.gz and the version moves;
# pinning it would deploy the wrong file the day Version.pas changes.
tarball=$(ssh -o BatchMode=yes "$BUILD_HOST" \
   'ls -t ~/projects/TR4W-D12/build-out/dist/tr4w-*-linux.tar.gz 2>/dev/null | head -1') \
   || die "cannot reach $BUILD_HOST"
[ -n "$tarball" ] || die "no tarball on $BUILD_HOST -- run build-unix.sh --package first"

base=$(basename "$tarball")
stamp=$(ssh -o BatchMode=yes "$BUILD_HOST" "date -u -r '$tarball' '+%Y-%m-%d %H:%M:%SZ'")
say "   $base  (built $stamp)"

# THE AGE IS REPORTED, NOT ENFORCED.  A tarball from last week is a legitimate
# thing to deploy -- re-testing a known build is most of what a bench box is
# for -- but deploying one by accident because a build failed and nobody read
# the log is not, and that has happened.
age_h=$(ssh -o BatchMode=yes "$BUILD_HOST" \
   "echo \$(( ( \$(date -u +%s) - \$(date -u -r '$tarball' +%s) ) / 3600 ))")
if [ "${age_h:-0}" -gt 6 ]; then
   say "   NOTE: that artifact is ${age_h}h old.  If you just built, the build"
   say '         FAILED and this is the previous one -- read the summary.'
fi

work=$(mktemp -d) || die 'mktemp'
trap 'rm -rf "$work"' EXIT

say '== fetching'
scp -q -o BatchMode=yes "$BUILD_HOST:$tarball" "$work/$base" || die 'scp from build host'
bytes=$(wc -c < "$work/$base")
[ "$bytes" -gt 1000000 ] || die "the tarball is only $bytes bytes -- refusing to deploy it"
say "   $(( bytes / 1024 )) KB"

# The directory inside the tarball, taken FROM the tarball.  Deriving it from
# the file name would break the first time the two disagree.
inner=$(tar tzf "$work/$base" | head -1 | cut -d/ -f1)
[ -n "$inner" ] || die 'cannot read the tarball'

# --- 2. THE BENCH BOX ------------------------------------------------------
if [ "$do_bench" = 1 ]; then
   say "== deploying to $BENCH_HOST"
   ssh -o BatchMode=yes -o ConnectTimeout=10 "$BENCH_HOST" true 2>/dev/null \
      || die "cannot reach the bench box at $BENCH_HOST"

   scp -q -o BatchMode=yes "$work/$base" "$BENCH_HOST:/tmp/$base" \
      || die 'scp to bench box'

   # VERSIONED DIRECTORY PLUS A SYMLINK.  Unpacking over the live directory
   # would leave files from the previous build behind when one is renamed or
   # removed, and there would be no way back.  This way `current` is the only
   # thing that moves, rollback is one command, and the old build is still on
   # disk to compare against.
   ssh -o BatchMode=yes "$BENCH_HOST" "
      set -e
      mkdir -p $BENCH_ROOT/releases
      rm -rf $BENCH_ROOT/releases/$inner
      tar xzf /tmp/$base -C $BENCH_ROOT/releases
      rm -f /tmp/$base
      chmod +x $BENCH_ROOT/releases/$inner/tr4w
      [ -f $BENCH_ROOT/releases/$inner/server/tr4wserver ] && \
         chmod +x $BENCH_ROOT/releases/$inner/server/tr4wserver
      ln -sfn $BENCH_ROOT/releases/$inner $BENCH_ROOT/current
      echo \"   unpacked -> \$(readlink -f $BENCH_ROOT/current)\"
   " || die 'unpack on the bench box failed'

   # PROVE THE BINARY IS THERE AND IS AN ELF.  A tarball can arrive intact and
   # carry the wrong thing; `file` costs nothing and answers it.
   ssh -o BatchMode=yes "$BENCH_HOST" \
      "file -b $BENCH_ROOT/current/tr4w | cut -c1-60 | sed 's/^/   /'"

   say "   run it:  ssh $BENCH_HOST  then  ~/tr4w/current/tr4w"
   say '   (it needs a display -- run it ON the Mint desktop, not over ssh)'
fi

# --- 3. NAS2 ---------------------------------------------------------------
if [ "$do_nas" = 1 ]; then
   say "== archiving to $NAS_DIR"
   [ -d "$NAS_DIR" ] || die "$NAS_DIR is not there -- is W: (\\\\nas2\\shared) mapped?"
   cp "$work/$base" "$NAS_DIR/$base" || die 'copy to NAS2 failed'

   # READ IT BACK.  An SMB write that reports success and lands short is the
   # failure this catches, and a silently-truncated archive is discovered
   # months later by whoever needed it.
   nas_bytes=$(wc -c < "$NAS_DIR/$base")
   [ "$nas_bytes" = "$bytes" ] \
      || die "NAS2 copy is $nas_bytes bytes, source is $bytes -- the write was short"
   say "   $NAS_DIR/$base  ($(( nas_bytes / 1024 )) KB, verified)"
fi

say '== done'
