# Lazarus Cocoa container accessibility patch

`lazarus-cocoa-container-accessibility.patch` fixes child enumeration in
TCocoaCustomControl, the NSControl subclass Lazarus uses for form/document and
panel containers. On mac-ci, native buttons answer direct hit tests while
their parent returns an empty child list. This blocks normal discovery by
accessibility clients. The fix belongs in the shared Cocoa widgetset.

The override enumerates immediate, nonhidden subviews, then lets
NSAccessibilityUnignoredChildren flatten ignored native containers. Filtering
with isHiddenOrHasHiddenAncestor matters: the earlier unfiltered override
exposed hidden buttons and hidden-panel descendants. Do not use that version.
The signed NSArray iteration bound handles an empty subview array without
unsigned underflow. The temporary NSMutableArray is autoreleased by Cocoa;
the override neither owns nor retains child views beyond the query.

Validated dependency: Lazarus commit
`62c14a4d18c81f222127d42ce9b89b922c63fcbf`, FPC 3.2.2 Cocoa bindings, macOS 27
arm64. TR4W source revision: `ed126e424ab57c735129234582fc03b597b146d2`.
The patch adds 23 lines to one external dependency file, no application units
or dependencies. Preserve LF line endings; git apply rejects a CRLF-converted
patch against this LF source.

## Rebuild in an independent copy

These commands are for the already provisioned mac-ci host over `ssh mac-ci`.
The patch is staged at the path below. Choose new review directory names when
rerunning; the commands intentionally refuse existing targets. No command
modifies the installed Lazarus sources or CI working tree files.

```bash
set -eu
TR4W_AX_ROOT="$HOME/tr4w-gui-test"
TR4W_AX_SOURCE="$TR4W_AX_ROOT/source/tr4w-ax-review"
TR4W_AX_LAZARUS="$TR4W_AX_ROOT/toolchain/lazarus-ax-review"
TR4W_AX_PATCH="$TR4W_AX_ROOT/source/lazarus-cocoa-container-accessibility.patch"
TR4W_AX_FPC="$HOME/fpcupdeluxe/fpc/bin/aarch64-darwin/fpc"
test ! -e "$TR4W_AX_SOURCE"
test ! -e "$TR4W_AX_LAZARUS"
test -f "$TR4W_AX_PATCH"
test "$(git -C "$HOME/fpcupdeluxe/lazarus" rev-parse HEAD)" = 62c14a4d18c81f222127d42ce9b89b922c63fcbf
test -z "$(git -C "$HOME/fpcupdeluxe/lazarus" status --porcelain --untracked-files=no)"
git -C "$HOME/actions-runner-tr4w/_work/TR4W-D12/TR4W-D12" worktree add --detach \
   "$TR4W_AX_SOURCE" ed126e424ab57c735129234582fc03b597b146d2
ditto "$HOME/fpcupdeluxe/lazarus" "$TR4W_AX_LAZARUS"
git -C "$TR4W_AX_LAZARUS" apply --check "$TR4W_AX_PATCH"
git -C "$TR4W_AX_LAZARUS" apply "$TR4W_AX_PATCH"
. "$TR4W_AX_SOURCE/tools/fpc-unix-paths.sh"
TR4W_AX_PACKAGES=$(fpc_unix_package_paths "$HOME/fpcupdeluxe/fpc/units/aarch64-darwin")
nice -n 10 make -C "$TR4W_AX_LAZARUS" -j1 lcl LCL_PLATFORM=cocoa \
   FPC="$TR4W_AX_FPC" PP="$TR4W_AX_FPC" OPT="$TR4W_AX_PACKAGES" \
   > "$TR4W_AX_ROOT/artifacts/lcl-ax-review-build.log" 2>&1
cd "$TR4W_AX_SOURCE"
FPC_HOME="$TR4W_AX_FPC" LAZARUS_DIR="$TR4W_AX_LAZARUS" \
   nice -n 10 sh tr4w/build/build-unix.sh --app \
   > "$TR4W_AX_ROOT/artifacts/tr4w-ax-review-build.log" 2>&1
```

`FPC_HOME` must be the full compiler path here. Pinning it to the fpcupdeluxe
root does not satisfy this build script's compiler discovery contract.
The native build logs explicitly list gates that were not run; a successful
compile is not a shippable release.

## Rerun the already built final experiment

The complete final test bundle is already on mac-ci. It is a copy of the
release's resources/frameworks with the independently built executable,
ad-hoc signed and deep/strict verified. It is not notarized or installed as
the operator app. Its exact source/patch/compiler/hash record is
`~/tr4w-gui-test/artifacts/mac-ax-visible-build.json`.

From mac-ci:

```bash
/usr/bin/python3 "$HOME/tr4w-gui-test/run_mac_pilot.py" \
   --database-template "$HOME/tr4w-gui-test/practice-source.db" \
   --settings-template "$HOME/tr4w-gui-test/tr4w.json" \
   --app-bundle "$HOME/tr4w-gui-test/app/TR4W-ax-visible.app" \
   --build-record "$HOME/tr4w-gui-test/artifacts/mac-ax-visible-build.json" \
   --ax-probe --exercise-footer
```

Both approved helpers retain their original executables and permissions.
`--ax-probe` selects the expanded, read-only reader; omit it to check the
original runner's AXChildren traversal. `--exercise-footer` reopens clean
Preferences twice, traverses backward by Tab until the named enabled button
has observed focus, then presses Space and verifies dismissal. It does not
click coordinates or edit preferences; it does not test dirty persistence.

`--app-bundle` parks the full release under an exclusive pilot.lock, copies
the experiment into the approved test path, then restores the full release
in a finally block and checks its original hash/signature. The replacement
bundle remains available separately; used test-slot copies are retained for
inspection. `mac_test_slot.py` implements this once for the native fixture and
the real-app coordinator. The coordinator writes restoration failures into
the final result and fails the run. A digest mismatch in `--build-record`
stops before any application launch and still restores the release.

The expected current outcome is a passing footer/navigation/action result
inside an overall failing result: shutdown still returns 217. Do not weaken
that exit assertion. Results, screenshots, native observations and step logs
go into a fresh `~/tr4w-gui-test/artifacts/<run>/` directory.

## Native and Lazarus regression fixtures

The native fixture builds itself and runs five asserted container variants:

```bash
/usr/bin/python3 "$HOME/tr4w-gui-test/run_mac_ax_container_control.py"
```

The already compiled Lazarus fixture is separate from TR4W and has no settings,
database, networking or radio code:

```bash
/usr/bin/python3 "$HOME/tr4w-gui-test/run_mac_ax_container_control.py" \
   --lcl-executable "$HOME/tr4w-gui-test/source/lcl-ax-fixture-build/tr4w"
```

To rebuild it, start an actual POSIX shell (`sh`) first. mac-ci's default zsh
does not split the helper's flag strings into compiler arguments. These flags
reuse the existing package/SDK helper, including UserNotifications and the
classic linker required by this FPC version:

```sh
set -eu
TR4W_AX_ROOT="$HOME/tr4w-gui-test"
TR4W_AX_LAZARUS="$TR4W_AX_ROOT/toolchain/lazarus-ax-fix"
. "$TR4W_AX_ROOT/source/tr4w-ax-fix/tools/fpc-unix-paths.sh"
TR4W_AX_UNITS=$(fpc_unix_package_paths "$HOME/fpcupdeluxe/fpc/units/aarch64-darwin")
TR4W_AX_LINK=$(fpc_darwin_link_flags)
mkdir -p "$TR4W_AX_ROOT/source/lcl-ax-fixture-build"
"$HOME/fpcupdeluxe/fpc/bin/aarch64-darwin/fpc" \
   -Fu"$TR4W_AX_LAZARUS/lcl/units/aarch64-darwin" \
   -Fu"$TR4W_AX_LAZARUS/lcl/units/aarch64-darwin/cocoa" \
   -Fu"$TR4W_AX_LAZARUS/components/lazutils/lib/aarch64-darwin" \
   -Fu"$TR4W_AX_LAZARUS/packager/units/aarch64-darwin" \
   $TR4W_AX_UNITS $TR4W_AX_LINK \
   -FU"$TR4W_AX_ROOT/source/lcl-ax-fixture-build" \
   -o"$TR4W_AX_ROOT/source/lcl-ax-fixture-build/tr4w" \
   "$TR4W_AX_ROOT/mac_lcl_ax_control.lpr"
```

It selects each tab on a separate launch and checks that only that page's
button, the panel button and status-bar button are exposed. Hidden sentinels
must stay absent. A splitter is present during traversal. Like the native
fixture, it uses the shared test-slot restoration code and approved probe,
then stops only its own fixture PID. These fixtures do not test normal TR4W
shutdown; use the real application pilot for that.

## Integration and rollback

Apply this as a managed patch in macOS toolchain provisioning after review,
then rebuild Cocoa LCL and dependent applications. A TR4W source change alone
does not fix already compiled Cocoa widgetset units. Check the Lazarus commit
and patch application explicitly; do not silently apply it with fuzzy
matching to a new dependency version or copy compiled units between versions.
Remove the local patch when an equivalent upstream fix is adopted.

The Lazarus fixture covers basic active/inactive tab visibility, panel/status
bar children and traversal with a splitter instantiated. Before changing the
shared CI toolchain, cover interactive tab switching, splitter dragging and
status-bar rendering, dirty Preferences save/cancel behavior, and intended
macOS versions. Those interactive checks and global rollout were not performed.
The fixture's optional `--exercise-tabs` diagnostic was attempted later while
the desktop was locked and stopped at the foreground guard. It remains
unfinished. Both coordinators now reject a locked/unknown console before
launch; unlock the existing console session before rerunning.
Windows and GTK2 do not use this Cocoa class and need no corresponding patch.
The shutdown lifetime defect is independent and has its own review note.

Rollback uses the unmodified Lazarus toolchain followed by rebuilding the
application. Keep a known release bundle until validation is complete.
Do not rebuild or replace either approved GUI helper as part of this fix.
See [MACOS.md](../MACOS.md) for measured comparisons and archived evidence.
