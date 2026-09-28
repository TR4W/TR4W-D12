#!/bin/sh
#
# Sign, notarize and staple the macOS artifacts.  Called by build-unix.sh's
# packaging stage; it is not meant to be run on its own, but it will be.
#
#   sh mac-sign.sh app <stage-dir>    sign the .app and the server binary,
#                                     notarize the app, staple the ticket
#   sh mac-sign.sh dmg <disk-image>   sign the image, notarize it, staple
#   sh mac-sign.sh pkg <stage-dir> <out.pkg>
#                                     BUILD the installer package from the
#                                     already-stapled bundle, sign it with the
#                                     Developer ID INSTALLER certificate,
#                                     notarize it and staple.
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
#   1a. the nested libraries      Contents/Frameworks/*.  TR4W.app carries its
#                                 own OpenSSL, because macOS ships none.  They
#                                 are ENUMERATED, not named, and a missing or
#                                 empty Frameworks directory is a failure --
#                                 an unsigned dylib fails the whole
#                                 notarization, and a bundle without them has
#                                 no TLS.
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
#   TR4W_PKG_IDENTITY    (pkg mode only) the FULL common name of the Developer
#                        ID INSTALLER certificate.  A DIFFERENT certificate
#                        from the one below and not interchangeable with it:
#                        productbuild will not accept an Application identity,
#                        and an Installer identity is not a codesigning
#                        identity at all -- it does not appear in
#                        `security find-identity -p codesigning` output.
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

OUTPKG=${3:-}

case "$MODE" in
   app|dmg) ;;
   pkg)
      [ -n "$OUTPKG" ] || die 'pkg mode needs an output path: mac-sign.sh pkg <stage-dir> <out.pkg>'
      ;;
   *)
      say "usage: $0 <app|dmg|pkg> <path> [out.pkg]" >&2
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
# THE IDENTITY VARIABLE DEPENDS ON THE MODE, because the certificate does.
# Requiring TR4W_SIGN_IDENTITY in pkg mode would demand a credential that mode
# never uses, and requiring TR4W_PKG_IDENTITY in app mode would break every
# existing caller.
if [ "$MODE" = pkg ]; then
   IDENTITY_VAR=TR4W_PKG_IDENTITY
else
   IDENTITY_VAR=TR4W_SIGN_IDENTITY
fi

missing=''
for v in "$IDENTITY_VAR" TR4W_NOTARY_KEY TR4W_NOTARY_KEY_ID TR4W_NOTARY_ISSUER; do
   eval "val=\${$v:-}"
   [ -n "$val" ] || missing="$missing $v"
done
[ -z "$missing" ] || die "these are not set:$missing"
[ -f "$TR4W_NOTARY_KEY" ] || die "TR4W_NOTARY_KEY points at no file: $TR4W_NOTARY_KEY"

# THE IDENTITY MUST BE PRESENT AND UNAMBIGUOUS.
#
# codesign -s and productbuild --sign both match the string against the common
# name, so a partial or duplicated name can select a certificate nobody
# intended.  Requiring exactly one match of the FULL name turns that into a
# build failure here rather than into a Gatekeeper failure on someone's Mac.
#
# require_identity <full-common-name> [policy args for find-identity...]
#
# COUNT DISTINCT FINGERPRINTS, NOT MATCHING LINES (2026-09-27).  This was
# `grep -cF`, and that counts OUTPUT ROWS -- so ONE certificate reachable
# through TWO keychains on the search list counts as two and this check kills
# the build with "ambiguous" over a certificate that is not ambiguous at all.
#
# That is not hypothetical on this machine.  mac-ci's search list currently
# holds FIVE copies of one path (a different project's runner appends it and
# never checks), and the only reason the line count is still right is that the
# path is stale and the keychain is not there.  The day it exists, a
# line-counting check breaks the signing of a release for no reason.
#
# A fingerprint is the certificate's identity; two rows with the same
# fingerprint are one certificate seen twice.  Two rows with DIFFERENT
# fingerprints and the same name are genuinely ambiguous and still fail.
#
# THE POLICY IS A PARAMETER, AND THAT IS THE WHOLE REASON THIS IS A FUNCTION.
# An Installer certificate IS NOT A CODESIGNING IDENTITY: it does not appear in
# `security find-identity -p codesigning` at all -- verified on mac-ci, which
# holds both certificates and lists exactly one under that policy.  So the pkg
# mode must ask WITHOUT the policy filter, and a second copy of this check with
# one argument changed is precisely the duplicate that drifts.
require_identity() {
   _rq_name=$1
   shift
   _rq_matches=$(security find-identity -v "$@" 2>/dev/null |
                 grep -F "\"$_rq_name\"" |
                 awk '{ print $2 }' |
                 sort -u |
                 wc -l |
                 tr -d '[:space:]')
   case "$_rq_matches" in
      1) return 0 ;;
      0)
         say '  Identities available to this user:'
         security find-identity -v "$@" 2>&1 | sed 's/^/    /'
         die "no valid identity named \"$_rq_name\""
         ;;
      *)
         security find-identity -v "$@" 2>&1 | sed 's/^/    /'
         die "$_rq_matches distinct certificates match \"$_rq_name\" -- ambiguous"
         ;;
   esac
}

if [ "$MODE" = pkg ]; then
   require_identity "$TR4W_PKG_IDENTITY"
else
   require_identity "$TR4W_SIGN_IDENTITY" -p codesigning
fi

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

eval "ACTIVE_IDENTITY=\${$IDENTITY_VAR}"

say ''
say "=== macOS signing ($MODE) ==="
say "  identity : $ACTIVE_IDENTITY"

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

      # THE NESTED LIBRARIES, INSIDE OUT AND ENUMERATED RATHER THAN NAMED.
      #
      # TR4W.app carries its own OpenSSL (Contents/Frameworks) because macOS
      # ships none and FPC's TLS needs it. Every Mach-O in a submission must
      # be signed with the same Developer ID: ONE unsigned dylib here fails
      # the notarization of the WHOLE bundle, with an error that names the
      # file and not this omission.
      #
      # Enumerated, because a list of names is a list somebody has to
      # remember to extend. And the count is checked, because a glob that
      # matches nothing would sign nothing and say nothing -- the
      # fails-open shape this repository has been bitten by before.
      FRAMEWORKS="$BUNDLE/Contents/Frameworks"
      [ -d "$FRAMEWORKS" ] ||
         die "no $FRAMEWORKS -- the bundle carries no OpenSSL, so it would have no TLS at all"
      nested=0
      for lib in "$FRAMEWORKS"/*; do
         [ -f "$lib" ] || continue
         sign "$lib" --options runtime
         nested=$((nested + 1))
      done
      [ "$nested" -gt 0 ] ||
         die "$FRAMEWORKS is empty -- see build-unix.sh's mac_bundle_openssl"
      say "  nested   : $nested library/libraries signed"

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

   pkg)
      # ---------------------------------------------------------------------
      # THE INSTALLER PACKAGE.
      #
      # BUILT HERE RATHER THAN IN build-unix.sh, WHICH IS NOT THE PATTERN THE
      # .dmg FOLLOWS, and the difference is productbuild's.  A disk image can
      # be created unsigned and signed afterwards, so build-unix.sh builds it
      # and this script signs it.  `productbuild --sign` FUSES those two: there
      # is no supported way to build a product archive and then sign it with
      # productbuild (productsign(1) exists for that, and adds a step whose
      # only product is a briefly-unsigned .pkg on disk).  Fusing them is also
      # the better outcome against this file's own rule -- an unsigned artifact
      # never exists to be shipped by accident.
      #
      # FROM THE STAPLED BUNDLE, which is why this runs after `app` mode and
      # not beside it.  The .pkg wraps the very bundle the .dmg carries; it
      # neither re-signs nor modifies it.
      # ---------------------------------------------------------------------
      STAGE=$ARTIFACT
      BUNDLE="$STAGE/TR4W.app"
      [ -d "$BUNDLE" ] || die "no bundle at $BUNDLE"

      for t in pkgbuild productbuild; do
         command -v "$t" > /dev/null 2>&1 ||
            die "$t is not installed -- it ships with the Xcode command line tools"
      done

      # THE VERSION COMES OUT OF THE BUNDLE BEING PACKAGED, not from a
      # parameter.  A version passed in can disagree with the thing it
      # describes; one read from Info.plist cannot.
      PKGVER=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' \
                  "$BUNDLE/Contents/Info.plist" 2>/dev/null)
      [ -n "$PKGVER" ] ||
         die "no CFBundleShortVersionString in $BUNDLE/Contents/Info.plist"
      say "  version  : $PKGVER (from the bundle)"

      # THE PACKAGE IDENTIFIER IS HOW macOS RECOGNISES AN UPGRADE, so it is
      # stated rather than left to pkgbuild's inference and must not change
      # between releases.  It is a separate namespace from the bundle id and
      # deliberately spelled the same, so there is one name to remember.
      PKGID=net.tr4w.TR4W

      COMPONENT="$WORK/tr4w-component.pkg"
      DIST="$WORK/Distribution.xml"

      say '  pkgbuild : the component'
      run pkgbuild --identifier "$PKGID" --version "$PKGVER" \
                   --component "$BUNDLE" --install-location /Applications \
                   "$COMPONENT" ||
         die 'pkgbuild could not build the component package'

      # THE COMPONENT IS DELIBERATELY NOT SIGNED.  man pkgbuild: "if you are
      # going to create a signed product with the resulting package, using
      # productbuild(1), there is no reason to sign the individual package."
      # Signing it as well would be two signatures where one is checked.
      #
      # A SYNTHESIZED DISTRIBUTION, for now.  productbuild --synthesize writes
      # one that installs everything with customize="never" -- no choices pane,
      # which is exactly this task's scope.  When the optional-symbols pane
      # arrives it replaces this file with a tracked one; the distribution is
      # where that lives, and nothing else here changes.
      say '  synthesize: the distribution'
      run productbuild --synthesize --package "$COMPONENT" "$DIST" ||
         die 'productbuild --synthesize failed'

      rm -f "$OUTPKG"
      say "  productbuild: $OUTPKG"
      # --timestamp is NOT passed: with a Developer ID identity productbuild
      # includes a trusted timestamp by default (man pkgbuild, SIGNED
      # PACKAGES), and the same is true of codesign above.
      run productbuild --distribution "$DIST" --package-path "$WORK" \
                       --sign "$TR4W_PKG_IDENTITY" "$OUTPKG" ||
         die 'productbuild could not build and sign the product archive'
      [ -f "$OUTPKG" ] ||
         die "productbuild exited 0 with no package at $OUTPKG"

      notarize "$OUTPKG" || {
         # NO UNSIGNED OR UNNOTARIZED .pkg SURVIVES. An installer macOS
         # refuses is worse than no installer: the user has already
         # double-clicked it by the time they find out.
         rm -f "$OUTPKG"
         die 'the installer package was not accepted -- no .pkg was produced'
      }

      # -t install, NOT -t exec OR -t open.  A .pkg is assessed by Gatekeeper
      # under the installer policy, and asking either of the other two
      # questions passes things the Installer would refuse.
      staple_and_verify "$OUTPKG" -t install
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

if [ "$MODE" = pkg ]; then
   say "  done: $OUTPKG"
else
   say "  done: $ARTIFACT"
fi
exit 0
