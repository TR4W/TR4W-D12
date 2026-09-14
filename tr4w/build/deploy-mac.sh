#!/bin/bash
#
# DEPLOY THE macOS BUILD -- to mac-ci in a form that can be double-clicked,
# and to NAS2.
#
# ---------------------------------------------------------------------------
# THE SAME SHAPE AS deploy-linux.sh, AND ONE REAL DIFFERENCE
# ---------------------------------------------------------------------------
#
# On Linux the build host and the run host are two machines.  On macOS they
# are the SAME machine -- mac-ci builds it and mac-ci is where NY4I runs it --
# so this does not copy the app anywhere to install it.  What it does instead
# is put it somewhere a person can find and launch (~/Applications), and make
# it launchABLE, which on macOS is not the same as making it present.
#
# ---------------------------------------------------------------------------
# WHY THE xattr LINE EXISTS, AND WHY IT IS NOT A HACK
# ---------------------------------------------------------------------------
#
# THE BUNDLE IS NOT SIGNED AND NOT NOTARIZED.  That is a deliberate, recorded
# state -- signing needs an Apple Developer ID, which is a purchase and a
# decision, not a build flag -- and Gatekeeper's message for an unsigned
# bundle is the actively misleading:
#
#     "TR4W.app is damaged and can't be opened. You should move it to
#      the Trash."
#
# It is NOT damaged.  macOS says that when it cannot verify a signature on a
# bundle carrying the com.apple.quarantine extended attribute.
#
#     xattr -dr com.apple.quarantine <bundle>
#
# removes that attribute, and the app opens.  It is the documented way to run
# your own unsigned build of your own program on your own machine, and it
# changes nothing about the binary.
#
# WHEN IT MATTERS: a bundle that reaches the Mac through a BROWSER, AirDrop,
# or the NAS share via Finder gets quarantined.  One that arrives by scp or is
# built in place usually does not.  This runs it EVERY TIME anyway, because it
# is idempotent and harmless, and because "sometimes quarantined" is exactly
# the kind of intermittent that costs an hour.
#
# Usage:
#     sh tr4w/build/deploy-mac.sh                # install on mac-ci + NAS2
#     sh tr4w/build/deploy-mac.sh --nas-only     # archive only
#     sh tr4w/build/deploy-mac.sh --mac-only     # no NAS write
#
set -u

MAC_HOST=mac-ci
MAC_APPS='~/Applications'
NAS_DIR='/w/TR4WInstalls/New/MacOS'

do_mac=1
do_nas=1
for arg in "$@"; do
   case "$arg" in
      --nas-only) do_mac=0 ;;
      --mac-only) do_nas=0 ;;
      -h|--help)  sed -n '2,47p' "$0"; exit 0 ;;
      *) echo "deploy-mac: unknown option '$arg'" >&2; exit 2 ;;
   esac
done

say() { printf '%s\n' "$*"; }
die() { printf 'deploy-mac: %s\n' "$*" >&2; exit 1; }

# --- 1. WHAT IS THERE TO DEPLOY -------------------------------------------
say "== finding the artifact on $MAC_HOST"
tarball=$(ssh -o BatchMode=yes "$MAC_HOST" \
   'ls -t ~/projects/TR4W-D12/build-out/dist/tr4w-*-darwin.tar.gz 2>/dev/null | head -1') \
   || die "cannot reach $MAC_HOST"
[ -n "$tarball" ] || die "no tarball on $MAC_HOST -- run build-unix.sh --all first"

base=$(basename "$tarball")
stamp=$(ssh -o BatchMode=yes "$MAC_HOST" "date -u -r '$tarball' '+%Y-%m-%d %H:%M:%SZ'")
say "   $base  (built $stamp)"

# Reported, not enforced -- see the same note in deploy-linux.sh.
age_h=$(ssh -o BatchMode=yes "$MAC_HOST" \
   "echo \$(( ( \$(date -u +%s) - \$(stat -f %m '$tarball') ) / 3600 ))")
if [ "${age_h:-0}" -gt 6 ]; then
   say "   NOTE: that artifact is ${age_h}h old.  If you just built, the build"
   say '         FAILED and this is the previous one -- read the summary.'
fi

inner=$(ssh -o BatchMode=yes "$MAC_HOST" "tar tzf '$tarball' | head -1 | cut -d/ -f1")
[ -n "$inner" ] || die 'cannot read the tarball'

# --- 2. INSTALL IT ON THE MAC ---------------------------------------------
if [ "$do_mac" = 1 ]; then
   say "== installing on $MAC_HOST"

   # ~/Applications, NOT /Applications.  The system folder needs sudo, and an
   # unsigned personal build has no business asking for an admin password.
   # ~/Applications appears in Finder's sidebar and in Launchpad just the same.
   ssh -o BatchMode=yes "$MAC_HOST" "
      set -e
      mkdir -p $MAC_APPS
      tmp=\$(mktemp -d)
      tar xzf '$tarball' -C \"\$tmp\"

      # REPLACE THE BUNDLE WHOLE.  Unpacking over a live TR4W.app leaves files
      # from the previous build inside it when one is renamed, and a bundle is
      # a directory -- so the stale file is still found at run time.
      rm -rf $MAC_APPS/TR4W.app
      mv \"\$tmp/$inner/TR4W.app\" $MAC_APPS/TR4W.app

      # The server is a command-line program and does not belong in a bundle.
      if [ -d \"\$tmp/$inner/server\" ]; then
         mkdir -p ~/tr4w
         rm -rf ~/tr4w/server
         mv \"\$tmp/$inner/server\" ~/tr4w/server
         chmod +x ~/tr4w/server/tr4wserver
      fi
      rm -rf \"\$tmp\"

      chmod +x $MAC_APPS/TR4W.app/Contents/MacOS/tr4w

      # THE LINE THIS SCRIPT EXISTS TO GET RIGHT.  See the header: without it
      # macOS reports an unsigned bundle as DAMAGED, which sends people to the
      # Trash with a working build.  -r is required because a bundle is a
      # directory and the attribute can sit on any file inside it.
      xattr -dr com.apple.quarantine $MAC_APPS/TR4W.app 2>/dev/null || true

      echo \"   installed -> \$(cd $MAC_APPS && pwd)/TR4W.app\"
      echo -n '   quarantine: '
      if xattr -p com.apple.quarantine $MAC_APPS/TR4W.app >/dev/null 2>&1; then
         echo 'STILL SET -- the app will report itself as damaged'
      else
         echo 'clear'
      fi
   " || die 'install on the Mac failed'

   # PROVE IT IS A MACH-O FOR THIS MACHINE'S ARCHITECTURE.  An arm64 Mac
   # running an x86_64 binary works through Rosetta and is not what was built;
   # an empty or truncated file does not work at all.
   ssh -o BatchMode=yes "$MAC_HOST" \
      "file -b $MAC_APPS/TR4W.app/Contents/MacOS/tr4w | cut -c1-70 | sed 's/^/   /'"

   say '   open it:  open ~/Applications/TR4W.app'
   say '   or find TR4W in Finder > Go > Applications (the HOME one)'
fi

# --- 3. NAS2 ---------------------------------------------------------------
#
# THE ARCHIVED COPY IS THE TARBALL, not the installed bundle, and the xattr
# above does NOT travel with it: a tarball pulled off the share through Finder
# is quarantined again on arrival.  Whoever unpacks it runs the same one line,
# which is why it is printed at the end rather than only living in this file.
if [ "$do_nas" = 1 ]; then
   say "== archiving to $NAS_DIR"
   [ -d "$NAS_DIR" ] || die "$NAS_DIR is not there -- is W: (\\\\nas2\\shared) mapped?"

   work=$(mktemp -d) || die 'mktemp'
   trap 'rm -rf "$work"' EXIT
   scp -q -o BatchMode=yes "$MAC_HOST:$tarball" "$work/$base" || die 'scp from the Mac'

   bytes=$(wc -c < "$work/$base")
   [ "$bytes" -gt 1000000 ] || die "the tarball is only $bytes bytes -- refusing to archive it"

   cp "$work/$base" "$NAS_DIR/$base" || die 'copy to NAS2 failed'
   nas_bytes=$(wc -c < "$NAS_DIR/$base")
   [ "$nas_bytes" = "$bytes" ] \
      || die "NAS2 copy is $nas_bytes bytes, source is $bytes -- the write was short"
   say "   $NAS_DIR/$base  ($(( nas_bytes / 1024 )) KB, verified)"

   say ''
   say '   TO RUN THE ARCHIVED COPY ON ANY MAC:'
   say "     tar xzf $base"
   say "     xattr -dr com.apple.quarantine $inner/TR4W.app"
   say "     open $inner/TR4W.app"
   say '   The second line is not optional. macOS calls an unsigned bundle'
   say '   "damaged" until the quarantine attribute is removed.'
fi

say '== done'
