#!/bin/sh
#
# Sign, notarize and staple the macOS artifacts.  Called by build-unix.sh's
# packaging stage; it is not meant to be run on its own, but it will be.
#
#   sh mac-sign.sh app <stage-dir>    sign the .app and the server binary,
#                                     notarize the app, staple the ticket
#   sh mac-sign.sh dmg <disk-image>   sign the image, notarize it, staple
#
# WHY IT IS A SEPARATE FILE.  build-unix.sh is the ONE implementation of the
# Unix build and is deliberately platform-neutral above four documented
# differences.  Apple's signing chain is none of those: it is ~200 lines that
# only ever run on darwin, it needs credentials that no other stage touches,
# and it has its own failure vocabulary.  Inlining it would put a third of the
# script behind `if [ "$OS" = darwin ]`.
#
# ---------------------------------------------------------------------------
# WHAT IT DOES, INSIDE OUT.  The order is not a preference; each step consumes
# the previous one's output.
#
#   1. the server binary          tr4wserver sits OUTSIDE TR4W.app but INSIDE
#                                 the disk image.  An unsigned Mach-O anywhere
#                                 in the submission fails the WHOLE
#                                 notarization, so it is signed first and on
#                                 its own -- nothing else will reach it.
#   2. the app's executable       Contents/MacOS/tr4w.
#   3. the bundle                 TR4W.app itself, which seals 1-2 in.
#   4. a zip, via ditto           A .app CANNOT be submitted to notarytool
#                                 directly; it has to travel as a zip, and it
#                                 has to be ditto's zip -- /usr/bin/zip does
#                                 not preserve the symlinks and resource forks
#                                 a bundle can contain.
#   5. notarize, then staple      The ticket is attached to TR4W.app, not to
#                                 the zip, which is why the zip is discarded.
#   6. (the dmg mode)             The image is built from the STAPLED app by
#                                 the caller, then signed and notarized in its
#                                 own right, because a disk image carries its
#                                 own signature and its own ticket.
#
# ---------------------------------------------------------------------------
# HARDENED RUNTIME IS NOT OPTIONAL.  --options runtime is what makes the
# binary eligible for notarization at all; Apple rejects a Developer ID
# submission without it.  --timestamp is equally non-negotiable: a signature
# with no trusted timestamp stops validating the day the certificate expires
# (1 Feb 2027 for this one) instead of continuing to validate for artifacts
# signed while it was live.
#
# NOTHING FALLS BACK TO AD-HOC.  There is no "sign if we can" path here.  A
# missing credential, a missing identity or a rejected submission FAILS, and
# the caller's contract is that a failure means no artifact is produced at
# all.  A green run that shipped an unsigned bundle is the exact outcome this
# file exists to make impossible.
#
# ---------------------------------------------------------------------------
# AND THE EXIT CODE OF `notarytool --wait` IS NOT THE ANSWER.  It reports
# whether the submission was TRACKED to completion, not whether the result was
# Accepted -- it can and does exit 0 on `status: Invalid`.  So the status line
# is parsed, an Invalid or Rejected result prints `notarytool log` for the
# submission (which names the offending binary and the reason), and the real
# gates are run afterwards against the artifact itself:
#
#     xcrun stapler validate    is there a ticket, and does it match
#     spctl --assess            would Gatekeeper actually let this run
#
# Those two ask the system the same question a user's Mac will ask.
#
# ---------------------------------------------------------------------------
# ENVIRONMENT (all required; there are no defaults that guess):
#
#   TR4W_SIGN_IDENTITY   the FULL common name of the Developer ID Application
#                        certificate.  Selected by name and never by
#                        `find-identity | head -1`: a second identity in the
#                        keychain -- an Apple Development cert, say -- would
#                        silently take the slot, and the artifact would be
#                        signed with something Gatekeeper does not accept for
#                        distribution.
#   TR4W_NOTARY_KEY      path to the App Store Connect API key (.p8).
#   TR4W_NOTARY_KEY_ID   its key id.
#   TR4W_NOTARY_ISSUER   the issuer UUID.
#
# The .p8 is never read, copied or echoed here; only its path is used, and its
# lifetime belongs to whoever created it.

set -u

MODE=${1:-}
ARTIFACT=${2:-}

say() { printf '%s\n' "$*"; }

die() {
   say "  SIGNING FAILED: $*"
   exit 1
}

case "$MODE" in
   app|dmg) ;;
   *)
      say "usage: $0 <app|dmg> <path>" >&2
      exit 2
      ;;
esac

[ -n "$ARTIFACT" ] || die "no path given for mode '$MODE'"
[ -e "$ARTIFACT" ] || die "$ARTIFACT does not exist"

# ---------------------------------------------------------------------------
# Credentials.  Checked ALL AT ONCE and named individually, because the
# alternative -- failing on the first one missing -- means three CI runs to
# discover three unset secrets.
# ---------------------------------------------------------------------------
missing=''
for v in TR4W_SIGN_IDENTITY TR4W_NOTARY_KEY TR4W_NOTARY_KEY_ID TR4W_NOTARY_ISSUER; do
   eval "val=\${$v:-}"
   [ -n "$val" ] || missing="$missing $v"
done
[ -z "$missing" ] || die "these are not set:$missing"
[ -f "$TR4W_NOTARY_KEY" ] || die "TR4W_NOTARY_KEY points at no file: $TR4W_NOTARY_KEY"

# THE IDENTITY MUST BE PRESENT AND UNAMBIGUOUS.
#
# codesign -s matches the string against the common name, so a partial or
# duplicated name can select a certificate nobody intended.  Requiring exactly
# one match of the FULL name turns that into a build failure here rather than
# into a Gatekeeper failure on someone's Mac.
matches=$(security find-identity -v -p codesigning 2>/dev/null |
          grep -cF "\"$TR4W_SIGN_IDENTITY\"")
case "$matches" in
   1) ;;
   0)
      say '  Identities available to this user:'
      security find-identity -v -p codesigning 2>&1 | sed 's/^/    /'
      die "no valid codesigning identity named \"$TR4W_SIGN_IDENTITY\""
      ;;
   *)
      security find-identity -v -p codesigning 2>&1 | sed 's/^/    /'
      die "$matches identities match \"$TR4W_SIGN_IDENTITY\" -- ambiguous"
      ;;
esac

# Scratch space for the notarization zip and the notarytool output.  Removed on
# every exit path, including a failure: the runners are treated as a temp
# folder, and leaving a zip of the application behind in _work is the kind of
# residue that later reads as someone's work in progress.
WORK=$(mktemp -d "${TMPDIR:-/tmp}/tr4w-notarize.XXXXXX") || die 'mktemp failed'
cleanup() { rm -rf "$WORK"; }
trap cleanup EXIT HUP INT TERM

# run <cmd...> -- run it, indent everything it says, return ITS exit status.
#
# EVERY GATE IN THIS FILE GOES THROUGH HERE, and the reason is a bug that is
# very easy to write and impossible to see:
#
#     codesign --verify --strict "$x" 2>&1 | sed 's/^/    /' || die ...
#
# a pipeline's exit status is the LAST command's, and sed succeeds on
# anything.  Written that way the verification is decoration -- it prints the
# rejection and carries on.
run() {
   _rc=0
   "$@" > "$WORK/run.out" 2>&1 || _rc=$?
   sed 's/^/    /' "$WORK/run.out"
   return $_rc
}

# sign <path> [extra codesign options...] -- trusted timestamp, this identity.
#
# --options runtime is passed BY THE CALLER rather than here, and only for the
# Mach-O artifacts. The hardened runtime is a property of a running process:
# on the executables it is mandatory (Apple rejects a Developer ID submission
# without it), and on a disk image it describes nothing. Apple's own recipe
# signs an image with neither, so the image is signed with neither.
sign() {
   _p=$1
   shift
   say "  codesign : $_p"
   run codesign --force --timestamp "$@" --sign "$TR4W_SIGN_IDENTITY" "$_p" ||
      die "codesign failed for $_p"
   run codesign --verify --strict "$_p" ||
      die "codesign --verify --strict rejected $_p"
   return 0
}

# notarize <path-to-zip-or-dmg>
#
# Returns 0 only on `status: Accepted`.  Anything else prints the submission
# log, which is the only place Apple says WHY.
notarize() {
   say "  notarize : $(basename "$1")"
   out="$WORK/notarytool.out"
   xcrun notarytool submit "$1" \
         --key "$TR4W_NOTARY_KEY" \
         --key-id "$TR4W_NOTARY_KEY_ID" \
         --issuer "$TR4W_NOTARY_ISSUER" \
         --wait > "$out" 2>&1
   rc=$?
   sed 's/^/    /' "$out"

   sub=$(grep -E '^ *id: ' "$out" | tail -1 | sed 's/^ *id: *//')
   status=$(grep -E '^ *status: ' "$out" | tail -1 | sed 's/^ *status: *//')

   if [ "$status" != 'Accepted' ]; then
      say "  notarization did not succeed (status='${status:-none}', notarytool exit $rc)"
      if [ -n "$sub" ]; then
         say "  --- notarytool log $sub ---"
         xcrun notarytool log "$sub" \
               --key "$TR4W_NOTARY_KEY" \
               --key-id "$TR4W_NOTARY_KEY_ID" \
               --issuer "$TR4W_NOTARY_ISSUER" 2>&1 | sed 's/^/    /'
      else
         say '  no submission id was reported, so there is no log to fetch.'
      fi
      return 1
   fi
   say "  accepted : $sub"
   return 0
}

# staple_and_verify <path> <spctl-type-args...>
#
# THE TWO GATES.  stapler validate proves a ticket is attached and matches the
# artifact; spctl asks Gatekeeper's own assessment engine whether it would
# allow it.  Both, because they fail independently: a ticket can be stapled to
# something Gatekeeper still refuses (wrong certificate kind), and a perfectly
# signed artifact with no ticket passes spctl on a machine that can reach
# Apple's servers and fails on one that cannot.
staple_and_verify() {
   path=$1
   shift
   run xcrun stapler staple "$path" ||
      die "stapler staple failed for $path"
   run xcrun stapler validate "$path" ||
      die "stapler validate rejected $path -- there is no usable ticket"
   run spctl --assess -vvv "$@" "$path" ||
      die "spctl rejected $path -- Gatekeeper would refuse this"
   say "  verified : $path"
   return 0
}

say ''
say "=== macOS signing ($MODE) ==="
say "  identity : $TR4W_SIGN_IDENTITY"

case "$MODE" in
   app)
      STAGE=$ARTIFACT
      BUNDLE="$STAGE/TR4W.app"
      SERVER="$STAGE/server/tr4wserver"

      [ -d "$BUNDLE" ] || die "no bundle at $BUNDLE"
      [ -f "$SERVER" ] || die "no server binary at $SERVER"

      # THE SERVER FIRST.  It is outside the bundle, so signing the bundle
      # cannot reach it -- and an unsigned Mach-O anywhere in the disk image
      # fails the image's notarization, with an error that names tr4wserver
      # and not this omission.
      sign "$SERVER"                   --options runtime
      sign "$BUNDLE/Contents/MacOS/tr4w" --options runtime
      sign "$BUNDLE"                   --options runtime

      # --deep on the bundle as well as --strict.  Deprecated for SIGNING and
      # rightly so, but it is still the documented way to VERIFY that every
      # nested piece validates rather than just the outermost seal.
      run codesign --verify --deep --strict --verbose=2 "$BUNDLE" ||
         die "codesign --verify --deep --strict rejected $BUNDLE"
      run codesign --verify --strict --verbose=2 "$SERVER" ||
         die "codesign --verify --strict rejected $SERVER"

      zip="$WORK/TR4W.zip"
      run ditto -c -k --keepParent "$BUNDLE" "$zip" ||
         die 'ditto could not build the submission zip'
      notarize "$zip" || die 'the app bundle was not accepted'

      # -t exec: the bundle is an executable, not an installer.
      staple_and_verify "$BUNDLE" -t exec

      say '  The server binary is covered by the disk image submission; a ticket'
      say '  cannot be stapled to a bare Mach-O, which is why only the bundle is'
      say '  stapled here.'
      ;;

   dmg)
      DMG=$ARTIFACT
      sign "$DMG"
      notarize "$DMG" || die 'the disk image was not accepted'
      # -t open with the primary-signature context: the assessment a Mac makes
      # when the image is DOUBLE-CLICKED.  `-t exec` on a .dmg asks the wrong
      # question and passes things a user's Mac would refuse.
      staple_and_verify "$DMG" -t open --context context:primary-signature
      ;;
esac

say "  done: $ARTIFACT"
exit 0
