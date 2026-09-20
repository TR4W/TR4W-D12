#!/bin/sh
#
# Build a Linux AppImage from the payload build-unix.sh already stages.
#
#   sh tr4w/build/build-appimage.sh            # from a completed package stage
#   sh tr4w/build/build-appimage.sh --deps     # what it would bundle, and stop
#
# WHY AN APPIMAGE AT ALL. GTK 2 is years past retirement and no modern desktop
# installs it by default, so the tarball's first instruction to a tester is an
# apt line. Bundling removes that, and SQLite and OpenSSL with it. NY4I,
# 2026-09-09: "My testers will find far more than I can alone" -- every apt
# line between a tester and the program is a tester who does not test.
#
# ============================================================================
# WHAT THIS DOES NOT FIX, AND YOU SHOULD KNOW BEFORE RUNNING IT
# ============================================================================
#
# THE glibc FLOOR IS UNCHANGED, AND IT IS HIGHER THAN THE EXECUTABLE'S.
#
# An AppImage bundles everything EXCEPT glibc, so one built here still refuses
# to start on a machine older than the build host.
#
# THIS SAID GLIBC_2.34 AND WAS WRONG ABOUT THE BUNDLE, which is the sort of
# wrong that gets quoted into a release note. 2.34 is the highest symbol the
# TR4W EXECUTABLE references, and it would be the answer if the executable
# travelled alone. It does not: it travels with 38 shared libraries lifted off
# the build host, and THEY have a floor of their own.
#
# Measured on linux-ci-build (Ubuntu 24.04, glibc 2.39) 2026-09-20, with
# objdump -T over everything in usr/lib: THIRTEEN of the 38 reference
# GLIBC_2.38 -- libglib-2.0, libgio-2.0, libpango-1.0, libcairo, libharfbuzz,
# libfontconfig, libexpat, libsqlite3, libcrypto, libselinux, libmount,
# libblkid, libbsd. So the AppImage's real floor is 2.38:
#
#     RUNS      Ubuntu 24.04 / 23.10, Debian 13, Fedora 39+
#     DOES NOT  Ubuntu 22.04 LTS, Ubuntu 20.04, Debian 12, RHEL 9
#
# The floor is a property of the BUILD HOST, not of this script -- it is
# whatever the oldest machine you build on can produce. Lowering it means
# building on an older base (a container or an old VM), and the builder has
# neither docker nor podman today. See task #17.
#
# WHAT IS NOT IN THE BUNDLE, AND THEREFORE STILL DEPENDS ON THE HOST: HamLib.
# DLOPENED below lists sqlite3 and OpenSSL and nothing else, and libhamlib is
# not installed on the build host to be copied even if it were listed. A
# HamLib-driven radio therefore needs libhamlib.so.4 present on the user's
# machine -- dlopen will find a system copy through the loader cache, but that
# combination has never been exercised. Radios TR4W drives itself are not
# affected.
#
# IT ADDS A DEPENDENCY OF ITS OWN: FUSE 2 on the tester's machine, or they run
# it with --appimage-extract-and-run.
#
# ~~THE PAYLOAD IS READ-ONLY, AND TR4W STILL WRITES TWO THINGS BESIDE ITS
# DATA~~ -- BOTH ARE FIXED, 2026-09-10, and this note is kept because the
# second one bit an operator before it was.
#
#     settings/tr4w.pos    STALE WHEN WRITTEN. That file is READ-ONLY now --
#                          a one-time seed -- and the window layout is saved
#                          into settings/tr4w.json, which is under
#                          ~/.config/tr4w and writable.
#
#     the contest files    REAL, AND IT COST A BENCH SESSION. NY4I ran this
#                          AppImage on a fresh Debian 13 and got a dialog
#                          demanding sqlite3.dll -- a file that cannot exist
#                          on Linux and was not the problem. The contest log
#                          was being created at /tmp/.mount_XXXX/usr/bin/ and
#                          QSOs were not being saved. uAppPaths has a fourth
#                          root now, ContestDir (~/tr4w off Windows), and New
#                          Contest composes from it.
#
# Settings and the log were already XDG (~/.config/tr4w, ~/.local/state/tr4w)
# and were always fine.
#
# THE LESSON FOR WHOEVER ADDS THE NEXT WRITE: this header named the hazard
# correctly and in advance, and the program shipped with it anyway. A note is
# not a guard. uProgramMain's own comment says the same thing -- "a write is
# the case where getting it wrong puts an operator's contest file inside an
# application bundle" -- and it, too, was written before the bug rather than
# after.
#
# ============================================================================

set -e

here=$(cd "$(dirname "$0")" && pwd)
TR4W="$here/.."
REPO=$(cd "$TR4W/.." && pwd)
OUTROOT="$REPO/build-out"

# TWO NAMES, AND THEY ARE NOT THE SAME. build-unix.sh stages under the full
# target triple (x86_64-linux, matching the tarball name); appimagetool wants
# the CPU alone in its ARCH variable. Conflating them looks for a stage
# directory that does not exist -- which is exactly what the first run did.
TARGET=x86_64-linux
ARCH=x86_64
VER=$(sed -n "s/.*TR4W_CURRENTVERSION_NUMBER[^']*'\([^']*\)'.*/\1/p" \
        "$TR4W/src/Version.pas" | head -1)
[ -n "$VER" ] || { echo "cannot read the version from src/Version.pas"; exit 2; }

STAGE="$OUTROOT/dist/tr4w-$VER-$TARGET"
APPDIR="$OUTROOT/appimage/TR4W.AppDir"
OUT="$OUTROOT/dist/TR4W-$VER-$ARCH.AppImage"

# ---------------------------------------------------------------------------
# WHAT COMES FROM THE HOST AND WHAT TRAVELS.
#
# The rule is not "bundle everything ldd names" -- that ships a copy of the
# graphics stack and breaks the moment the host's driver disagrees with it.
# The three families below MUST come from the host:
#
#   glibc and its siblings   the loader refuses two of them in one process
#   GL and the X11 client    they talk to the local driver and display server
#   glib's low-level pair    they are pulled in by anything already loaded
#
# Everything else -- GTK, GDK, pango, cairo, harfbuzz, pixbuf, fontconfig --
# is ours to carry, because they are what the host may not have at all.
# ---------------------------------------------------------------------------
HOST_LIBS="ld-linux libc.so libm.so libdl.so libpthread librt.so libresolv
           libgcc_s libstdc++
           libGL libGLX libGLdispatch libEGL libdrm libgbm
           libX11 libXext libXrender libXrandr libXi libXfixes libXcursor
           libXinerama libXdamage libXcomposite libXau libXdmcp libxcb
           libwayland"

is_host_lib() {
   for pat in $HOST_LIBS; do
      case "$1" in *"$pat"*) return 0 ;; esac
   done
   return 1
}

# The libraries TR4W opens by NAME at run time -- ldd cannot see these, and
# they are exactly the ones a tester is most likely to be missing.
DLOPENED="libsqlite3.so.0 libssl.so.3 libcrypto.so.3 libssl.so.1.1 libcrypto.so.1.1"

collect_libs() {
   exe="$1"; dest="$2"
   mkdir -p "$dest"

   # ldd's second column is the resolved path; entries without one (vdso) have
   # no path to copy and are skipped by the -f test.
   ldd "$exe" | sed -n 's/.*=> \(\/[^ ]*\).*/\1/p' | while read -r lib; do
      base=$(basename "$lib")
      if is_host_lib "$base"; then continue; fi
      [ -f "$lib" ] || continue
      cp -L -n "$lib" "$dest/" 2>/dev/null || true
   done

   for name in $DLOPENED; do
      # ldconfig knows where the loader would find it, which is the same
      # question TR4W's own dlopen asks.
      path=$(ldconfig -p 2>/dev/null | sed -n "s/.*$name[^=]*=> \(.*\)/\1/p" | head -1)
      if [ -n "$path" ] && [ -f "$path" ]; then
         cp -L -n "$path" "$dest/" 2>/dev/null || true
      fi
   done
}

if [ "${1:-}" = "--deps" ]; then
   echo "Libraries that would travel with the AppImage:"
   tmp=$(mktemp -d)
   collect_libs "$STAGE/tr4w" "$tmp"
   ls -1 "$tmp" | sed 's/^/  /'
   echo ""
   echo "From the host (deliberately NOT bundled): $HOST_LIBS" | tr -s ' '
   rm -rf "$tmp"
   exit 0
fi

[ -d "$STAGE" ] || {
   echo "no staged payload at $STAGE"
   echo "run: sh tr4w/build/build-linux.sh   (it produces the package stage)"
   exit 2
}

echo "=== AppDir ==="
rm -rf "$APPDIR"
mkdir -p "$APPDIR/usr/bin" "$APPDIR/usr/lib"

# THE DATA SITS BESIDE THE BINARY, NOT UNDER usr/share.
#
# uAppPaths.DataDir prefers /usr/share/tr4w and falls back to the binary's own
# directory. Inside an AppImage the first is the HOST's /usr/share, which will
# not have it -- so the fallback is the path that runs, and the data has to be
# where the fallback looks. Putting it under $APPDIR/usr/share would be tidier
# and would never be found.
cp -R "$STAGE"/. "$APPDIR/usr/bin/"
rm -rf "$APPDIR/usr/bin/server"        # tr4wserver ships in the tarball, not here

collect_libs "$STAGE/tr4w" "$APPDIR/usr/lib"
echo "  bundled $(ls -1 "$APPDIR/usr/lib" | wc -l) library file(s)"

# ---------------------------------------------------------------------------
# THE UNVERSIONED .so SYMLINKS, WITHOUT WHICH THE BUNDLE DOES NOT LAUNCH.
#
# ldd reports SONAMEs -- libgdk-x11-2.0.so.0 -- so collect_libs copies those
# and only those. But FPC's own gtk2 binding declares the library by its
# UNVERSIONED name (packages/gtk2/src/gtk+/gdk/gdk2.pas:60,
# gdklib = 'libgdk-x11-2.0.so') and loads it at run time under that name.
# There is no such file in the bundle, so the loader falls through
# LD_LIBRARY_PATH to the HOST's /usr/lib/.../libgdk-x11-2.0.so and the process
# ends up with TWO copies of GDK: the bundled .so.0 and the host's .so.
#
# The symptom names neither library and points at neither cause:
#
#     GLib-GObject-CRITICAL: cannot register existing type 'GdkScreen'
#     Gdk-CRITICAL: IA__gdk_screen_get_primary_monitor: assertion
#                   'GDK_IS_SCREEN (screen)' failed
#
# and the program then HANGS rather than exiting, so there is no exit code to
# read either. Measured with LD_DEBUG=libs on linux-ci-build, 2026-09-19: the
# loader tries $APPDIR/usr/lib/libgdk-x11-2.0.so first -- correctly -- finds
# nothing, and takes the host's.
#
# THIS IS WHY IT IS DONE FOR EVERY LIBRARY AND NOT JUST GDK. The same trap is
# armed for any bundled library some binding names without its version, and the
# failure is silent in exactly the same way: the host copy is loaded, it works
# on the build machine, and it is missing or incompatible on a tester's.
# A symlink costs nothing and removes the whole class.
# ---------------------------------------------------------------------------
links=0
for f in "$APPDIR"/usr/lib/*.so.*; do
   [ -f "$f" ] || continue
   unversioned=$(echo "$f" | sed 's/\.so\..*$/.so/')
   if [ ! -e "$unversioned" ]; then
      ln -s "$(basename "$f")" "$unversioned"
      links=$((links + 1))
   fi
done
echo "  unversioned .so symlinks: $links"

# ---------------------------------------------------------------------------
# GDK-PIXBUF'S LOADERS, WHICH ARE THE CLASSIC GTK BUNDLING TRAP.
#
# The loaders are separate .so files found through a CACHE FILE that holds
# ABSOLUTE PATHS. Copy the loaders without regenerating the cache and GTK
# silently loads none of them -- no icons, and on some themes no window at all.
# ---------------------------------------------------------------------------
# NEITHER OF THESE IS WHERE THE OBVIOUS ANSWER SAYS.
#
# pkg-config --variable=gdk_pixbuf_moduledir needs the -dev package, which an
# operator's machine and this builder both lack, and it fails EMPTY rather than
# loudly. And gdk-pixbuf-query-loaders is NOT ON PATH on Debian -- it lives
# beside the loaders it queries. Both were found by asking the machine after
# the first run reported "not found" for something that was plainly installed.
PIXBUF_DIR=$(pkg-config --variable=gdk_pixbuf_moduledir gdk-pixbuf-2.0 2>/dev/null || true)
if [ -z "$PIXBUF_DIR" ] || [ ! -d "$PIXBUF_DIR" ]; then
   PIXBUF_DIR=$(ls -d /usr/lib/*/gdk-pixbuf-2.0/*/loaders /usr/lib64/gdk-pixbuf-2.0/*/loaders \
                  2>/dev/null | head -1)
fi

PIXBUF_QUERY=$(command -v gdk-pixbuf-query-loaders 2>/dev/null || true)
if [ -z "$PIXBUF_QUERY" ]; then
   PIXBUF_QUERY=$(ls /usr/lib/*/gdk-pixbuf-2.0/gdk-pixbuf-query-loaders \
                     /usr/lib64/gdk-pixbuf-2.0/gdk-pixbuf-query-loaders \
                     2>/dev/null | head -1)
fi

if [ -n "$PIXBUF_DIR" ] && [ -d "$PIXBUF_DIR" ]; then
   mkdir -p "$APPDIR/usr/lib/gdk-pixbuf-2.0/loaders"
   cp -L "$PIXBUF_DIR"/*.so "$APPDIR/usr/lib/gdk-pixbuf-2.0/loaders/" 2>/dev/null || true
   if [ -n "$PIXBUF_QUERY" ] && [ -x "$PIXBUF_QUERY" ]; then
      ( cd "$APPDIR" && \
        GDK_PIXBUF_MODULEDIR="$APPDIR/usr/lib/gdk-pixbuf-2.0/loaders" \
        "$PIXBUF_QUERY" \
          > "$APPDIR/usr/lib/gdk-pixbuf-2.0/loaders.cache" ) || true
      # The cache holds absolute build-host paths; make them relative to the
      # mount point so AppRun can point at them wherever it lands.
      sed -i "s|$APPDIR|@APPDIR@|g" \
          "$APPDIR/usr/lib/gdk-pixbuf-2.0/loaders.cache" 2>/dev/null || true
      echo "  pixbuf loaders: $(ls -1 "$APPDIR/usr/lib/gdk-pixbuf-2.0/loaders" | wc -l)"
   else
      echo "  WARNING: gdk-pixbuf-query-loaders not found -- no loader cache."
      echo "           Icons will not render. It ships with libgdk-pixbuf-2.0-0"
      echo "           and lives beside the loaders, not on PATH."
   fi
else
   echo "  WARNING: gdk-pixbuf module dir not found -- loaders not bundled."
fi

# ---------------------------------------------------------------------------
# AppRun. The cache rewrite above left @APPDIR@ placeholders; this is what
# turns them into the real mount point, which is only known at run time.
# ---------------------------------------------------------------------------
cat > "$APPDIR/AppRun" <<'APPRUN'
#!/bin/sh
HERE=$(dirname "$(readlink -f "$0")")

export LD_LIBRARY_PATH="$HERE/usr/lib:$LD_LIBRARY_PATH"

if [ -f "$HERE/usr/lib/gdk-pixbuf-2.0/loaders.cache" ]; then
   # The cache is written once per run because the mount point changes.
   CACHE="${XDG_RUNTIME_DIR:-/tmp}/tr4w-pixbuf-$$.cache"
   sed "s|@APPDIR@|$HERE|g" \
       "$HERE/usr/lib/gdk-pixbuf-2.0/loaders.cache" > "$CACHE" 2>/dev/null
   export GDK_PIXBUF_MODULE_FILE="$CACHE"
   trap 'rm -f "$CACHE"' EXIT
fi

exec "$HERE/usr/bin/tr4w" "$@"
APPRUN
chmod +x "$APPDIR/AppRun"

cat > "$APPDIR/tr4w.desktop" <<DESKTOP
[Desktop Entry]
Type=Application
Name=TR4W
Comment=Amateur radio contest logger
Exec=tr4w
Icon=tr4w
Categories=HamRadio;Network;
Terminal=false
DESKTOP

# appimagetool insists on an icon. A generated one is honest about there not
# being real artwork yet; a missing file just fails the build.
#
# AND THERE IS NOTHING IN THE TREE TO USE INSTEAD. Measured 2026-09-20:
# tr4w/res/tr4w.ico holds exactly ONE image, 32x32 at 24bpp -- a Win32 titlebar
# icon. Scaling that to the 256x256 a desktop wants would look worse than a
# plain square and would look like somebody's finished work, which is the
# reason not to do it. Drop real artwork at tr4w/res/tr4w.png and this branch
# stops running.
if [ -f "$TR4W/res/tr4w.png" ]; then
   cp "$TR4W/res/tr4w.png" "$APPDIR/tr4w.png"
else
   # PURE PYTHON, NO PIL. The builder has no imaging library and installing
   # one to draw a placeholder square would be a dependency added for a
   # placeholder. zlib is in the standard library and a PNG is a header, one
   # deflated IDAT and an IEND -- forty lines, and no reason for it ever to
   # fail on a machine that can run the rest of this script.
   python3 - "$APPDIR/tr4w.png" <<'PY'
import struct, sys, zlib

W = H = 256
BG = (20, 40, 80)

rows = b''
for y in range(H):
    rows += b'\x00' + bytes(BG) * W          # filter 0, then RGB per pixel


def chunk(tag, data):
    return (struct.pack('>I', len(data)) + tag + data
            + struct.pack('>I', zlib.crc32(tag + data) & 0xFFFFFFFF))


png = (b'\x89PNG\r\n\x1a\n'
       + chunk(b'IHDR', struct.pack('>IIBBBBB', W, H, 8, 2, 0, 0, 0))
       + chunk(b'IDAT', zlib.compress(rows, 9))
       + chunk(b'IEND', b''))

open(sys.argv[1], 'wb').write(png)
PY
   [ -f "$APPDIR/tr4w.png" ] || {
      echo "  could not generate an icon -- add tr4w/res/tr4w.png"
      exit 2
   }
   echo "  icon: a generated placeholder. Real artwork goes in tr4w/res/tr4w.png."
fi

echo ""
echo "=== appimagetool ==="

# ---------------------------------------------------------------------------
# THE TOOLING IS CACHED OUTSIDE THE WORKSPACE, AND THERE ARE TWO PIECES OF IT.
#
# This used to keep appimagetool in build-out/. That is inside the checkout,
# and actions/checkout runs `git clean -ffdx` before every job -- build-out is
# gitignored, so it is wiped -- which made the cache a cache that never hit:
# a release run downloaded the tool EVERY time.
#
# AND IT WAS NOT ONE DOWNLOAD BUT TWO. appimagetool fetches the type2 runtime
# it stamps onto the front of the image from
# github.com/AppImage/type2-runtime/releases/continuous unless it is handed one
# with --runtime-file (measured in its own strings, 2026-09-20:
# "Failed to download runtime file, please download the runtime manually ...
# and pass it to appimagetool with --runtime-file"). Two GitHub fetches inside
# a release job are two chances to fail for a reason that has nothing to do
# with TR4W.
#
# So both live in a per-user cache that no checkout touches. $HOME/.cache is
# the runner's own cache directory as much as a developer's; TR4W_CACHE_DIR
# overrides it, and TR4W_APPIMAGETOOL pins one specific binary for an air-
# gapped or offline build.
#
# EVERY DOWNLOAD IS STAGED AND VERIFIED BEFORE IT ENTERS THE CACHE. A cache is
# a place a truncated download can live forever: half a tool, written straight
# to the cache path, is executable-looking and broken on every subsequent run,
# with no way to tell it from a good one. Each file is fetched to a temporary
# name, checked (the tool must answer --version, the runtime must be an ELF of
# a plausible size) and only then moved into place, which is atomic within a
# directory.
# ---------------------------------------------------------------------------
CACHE_DIR="${TR4W_CACHE_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/tr4w}"
mkdir -p "$CACHE_DIR"

TOOL="${TR4W_APPIMAGETOOL:-$CACHE_DIR/appimagetool-$ARCH.AppImage}"
RUNTIME="$CACHE_DIR/runtime-$ARCH"

tool_works() {
   [ -x "$1" ] || return 1
   "$1" --appimage-extract-and-run --version >/dev/null 2>&1
}

if tool_works "$TOOL"; then
   echo "  appimagetool: cached at $TOOL"
elif [ -n "${TR4W_APPIMAGETOOL:-}" ]; then
   # A PINNED path that does not work is an error, never a silent download:
   # whoever set it meant that file and nothing else.
   echo "  TR4W_APPIMAGETOOL=$TOOL is not a working appimagetool"
   exit 2
else
   echo "  downloading appimagetool -> $TOOL"
   tmp="$TOOL.part.$$"
   rm -f "$tmp"
   if curl -fsSL -o "$tmp" \
        "https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-$ARCH.AppImage"
   then
      chmod +x "$tmp"
      if tool_works "$tmp"; then
         mv "$tmp" "$TOOL"
      else
         rm -f "$tmp"
         echo "  the downloaded appimagetool does not run -- not cached"
         exit 2
      fi
   else
      rm -f "$tmp"
      echo "  download failed -- put a working appimagetool at $TOOL,"
      echo "  or point TR4W_APPIMAGETOOL at one"
      exit 2
   fi
fi

# THE RUNTIME IS AN OPTIMISATION, NOT A REQUIREMENT. If it cannot be fetched,
# appimagetool is left to get its own exactly as before -- a cache miss must
# not turn into a build failure for something that used to work without a
# cache at all.
RUNTIME_ARG=''
if [ -s "$RUNTIME" ] && [ "$(head -c 4 "$RUNTIME" | od -An -c | tr -d ' \n')" = '177ELF' ]; then
   echo "  type2 runtime: cached at $RUNTIME"
   RUNTIME_ARG="$RUNTIME"
else
   echo "  downloading the type2 runtime -> $RUNTIME"
   tmp="$RUNTIME.part.$$"
   rm -f "$tmp"
   if curl -fsSL -o "$tmp" \
        "https://github.com/AppImage/type2-runtime/releases/download/continuous/runtime-$ARCH" \
      && [ -s "$tmp" ] \
      && [ "$(wc -c < "$tmp")" -gt 100000 ] \
      && [ "$(head -c 4 "$tmp" | od -An -c | tr -d ' \n')" = '177ELF' ]
   then
      chmod +x "$tmp"
      mv "$tmp" "$RUNTIME"
      RUNTIME_ARG="$RUNTIME"
   else
      rm -f "$tmp"
      echo "  could not cache the runtime -- appimagetool will fetch its own"
   fi
fi

# REMOVED FIRST, so a failed run cannot leave yesterday's image in the place
# a packaging or release step looks. "The file is there" has to mean "this run
# produced it", which is the same reason build-unix.sh rm -f's the tarball.
rm -f "$OUT"

# --appimage-extract-and-run: the builder may have no FUSE, and requiring it
# to BUILD an AppImage would be an odd dependency to add to a CI box.
if [ -n "$RUNTIME_ARG" ]; then
   ARCH="$ARCH" "$TOOL" --appimage-extract-and-run \
     --runtime-file "$RUNTIME_ARG" "$APPDIR" "$OUT" \
     || { echo "  appimagetool failed"; exit 1; }
else
   ARCH="$ARCH" "$TOOL" --appimage-extract-and-run "$APPDIR" "$OUT" \
     || { echo "  appimagetool failed"; exit 1; }
fi

echo ""
echo "=== Summary ==="
echo "  $OUT"
ls -la "$OUT" 2>/dev/null | sed 's/^/  /'
echo ""
echo "  NOT VERIFIED BY THIS SCRIPT: that it runs on a machine other than the"
echo "  one that built it. That is the only test that matters for an AppImage,"
echo "  and it needs a second machine -- ideally one WITHOUT GTK 2 installed,"
echo "  which is the whole reason for building this."
