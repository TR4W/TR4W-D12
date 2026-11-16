# macOS GUI pilot

## November 16: shared persistence passes on Mac and Linux

`mac-prefs-persistence-010` passes the shared Cancel/Save/restart/restoration
scenario on the final application patch. It uses three distinct application
PIDs, all exit 0, preserves all 101 original contacts and default settings/
contest-file inventories, and restores the complete original release bundle.
The same final application patch passes on Linux under GDB with no SIGSEGV
stops or access-violation markers. This completes the first shared native
persistence case, not parity with the full Windows case catalog.

[Mac result](../../docs/gui-test/mac-prefs-persistence-20261116/result.json),
[Mac steps](../../docs/gui-test/mac-prefs-persistence-20261116/steps.jsonl),
[Linux final GDB result](../../docs/gui-test/linux-prefs-persistence-20261116/final-gdb-result.json).

`mac-fixed-smoke-001` passes on source revision
`4547b9117f4d5c23a3606bd4de9477d5eb4b5019` plus the small Preferences reload
fix in [PREFERENCES_RELOAD_GUI_REVIEW.md](../../docs/PREFERENCES_RELOAD_GUI_REVIEW.md)
and the private Cocoa container patch below. Normal Command+Q returns 0.
The original approved runner and probe perform the smoke/footer-action checks;
all 101 contacts, default user-file inventories and bundle restoration pass.
The historic exit-217 results below belong to older source builds.

Complete final experimental bundle: `~/tr4w-gui-test/app/TR4W-prefs-search-4547.app`.
Executable SHA256:
`c4fa935a3ecab7be5cf0642e8894a1758ddcae9693e4161604320a62717dbae2`.
Its build record is `~/tr4w-gui-test/artifacts/mac-prefs-search-build.json`.
The app source was built in a new detached worktree; neither the installed CI
toolchain nor the other agent's checkout files were changed. The complete
bundle uses resources from workflow run `43776700899`, with an independently
compiled executable and an ad-hoc signature verified deep/strict.

The Linux persistence scenario now passes and is shared with Mac through
[preferences_roundtrip.py](preferences_roundtrip.py). The Cocoa driver is
[mac_preferences.py](mac_preferences.py): it reads native fields, verifies the
full search query and a single result, verifies focus, edits text and checks named
footer actions. It calls the same Cancel/Save/restart/restoration assertions
and independent JSON storage checks as Linux.

### Approved input helper

The original runner's restricted key set cannot type the shared test's search
term or numeric values. The prepared full-input helper is a **separate** app:

- App: `~/Applications/TR4W GUI Runner.app`.
- Bundle identifier: `net.tr4w.gui-pilot.runner`.
- Executable SHA256: `4acfd4985e9480556b162ed309879d7b55c82c6161a927eb830af8d6ce541133`.
- Source SHA256: `cf1ac881ae3564afc9e63f025ad12e6852ba46be50d6396cf69d713a824117e1`.
- Required grant: Accessibility only. The approved GUI Pilot retains screen
  capture and WindowServer inventory duties; it does not need reapproval.

This helper adds `text`, `focus`, `press` and `click`, and additional navigation
keys. All operations still validate the staged executable's PID. Input requires
that application foreground. Control actions require a unique enabled match
inside a named owned window. Mouse clicks use that control's current bounds,
require its center inside the owned frame, and require a matching native hit
test. Unicode text is bounded to 4096 UTF-16 units and checks foreground during
posting. A successful native call is not acceptance: the driver checks the
actual resulting UI and the scenario checks persistence independently.

The helper compiles without warnings and its signature verifies. Text, focus,
native AXPress and hit-validated mouse clicks are now exercised by the passing
case. Initial preflight attempts stopped before launch while approval was
absent. The UI later showed an enabled entry while fresh processes still
reported denied; removing/re-adding the exact final bundle resolved it without
rebuilding the helper or changing either older helper's permissions. The grant
is now active. Rerun with a fresh automatic run name:

```bash
/usr/bin/python3 "$HOME/tr4w-gui-test/run_mac_pilot.py" \
   --database-template "$HOME/tr4w-gui-test/practice-source.db" \
   --settings-template "$HOME/tr4w-gui-test/tr4w.json" \
   --app-bundle "$HOME/tr4w-gui-test/app/TR4W-prefs-search-4547.app" \
   --build-record "$HOME/tr4w-gui-test/artifacts/mac-prefs-search-build.json" \
   --runner-next --case preferences-persistence
```

To reopen its setup: `ssh mac-ci 'open "$HOME/Applications/TR4W GUI Runner.app"'`.
The setup requests no new Screen Recording grant. Both earlier approved apps
remain byte-identical. Development candidates with no grants were archived
under `~/tr4w-gui-test/source/`; do not approve those copies.

### Measured Cocoa input and search limits

The native text call reports event posting, not completed delivery. A bulk
request delivered only a prefix while focus stayed in the intended field.
The driver therefore clears the field explicitly and acknowledges each typed
prefix before posting the next character; it fails immediately if focus moves.
It does not substitute a fixed sleep or accept truncated text.

The owner-drawn Cocoa search table exposes unnamed virtual cells. The driver
requires the exact query to yield one popup table below the observed search
field and exactly one result cell. It clicks the native table only after
proving its center lies in that cell; the helper additionally requires a
matching hit test inside the owned window. Direct cell clicks correctly failed
that guard because the native hit resolves to the table. The selected text
field and independent JSON setting value prove the resulting edit.

Return did not activate the search result in a diagnostic attempt; this case
uses the mouse and does not certify Return behavior or owner-drawn cell naming.
Typing originally activated a result after the prefix "RA": the search list's
default ClickOnSelChange treated Cocoa's selection notification as a click.
The final app patch disables that selection-as-click behavior for this overlay,
keeping typing/highlighting separate from actual activation. No driver check
was weakened, and the approved helper binary remained unchanged throughout.

The builder's replacement guard now accepts JSON false and numeric zero as
equivalent native permission denials. Either granted permission or missing/
unknown status still refuses replacement. Portable regression tests cover this
distinction. Console readiness now uses an explicit IOConsoleLocked value if
the per-session lock key is absent; both locked and unlocked shapes were read
on this host. Unknown readiness still stops before launching the application.

## Historical November 15 results

November 15, 2026: the native bridge is approved and the live Cocoa pilot has
run on `mac-ci`. **The missing Preferences buttons are fixed in an isolated
build by a Lazarus Cocoa patch.** A same-source unpatched build fails the
footer assertion; the final patched build passes with both approved readers.
Keyboard activation of clean Cancel and Save and close also passes.
**The overall test still fails on the separate shutdown exit 217.** The
approved helpers, installed CI toolchain and operator app remain unchanged.

## Continuation status

Later on November 15 the mac-ci desktop was locked. The interactive tab test
was refused by the original helper's foreground guard. A subsequent real-app
startup attempt hit the old reader's tree bound while locked. Neither is
accepted as a GUI regression verdict. The owned processes were cleaned up and
the original release restored. IORegistry reports the console user logged in
and `CGSSessionScreenIsLocked=true`.

The coordinators now share job dispatch and bounded polling in
[mac_bridge.py](mac_bridge.py). They record console readiness and stop before
launching any application if the console is locked or its state is unknown.
The locked preflight was exercised: no TR4W PID, no fixture database created,
default user-file inventories unchanged and release restoration verified.
The IORegistry field check is measured on this macOS 27 host; a changed field
schema deliberately requires review. The latest shared-dispatch version still
needs an unlocked end-to-end rerun; earlier passing live evidence below is
retained with its original identities.

Resume by unlocking mac-ci's logged-in desktop, then run the final experimental
bundle command in [patches/README.md](patches/README.md). Do not rebuild either
approved helper. The optional fixture `--exercise-tabs` check is unfinished;
its initial attempt stopped at the foreground guard. Its default separate-
launch tab visibility checks passed before the lock.

On the local checkout, all work remains in `codex/linux-gui-pilot` at
`C:\tr4w-d12\.worktrees\linux-gui-pilot`, uncommitted. Do not alter main's
unrelated edits. The shared mac-ci toolchain has not been patched. The user's
request to locate an updated SHUTDOWN_LIFECYCLE_REVIEW.md was checked against
local and freshly fetched GitHub main at `245c7435`; neither contains it.
Only this worktree's original review document was found. Tom subsequently
pasted the receiving agent's reply; the review now records concurrence with
the Interfaces-order correction and the exact Linux trace requested by that
agent. Their reported Windows verification and remaining main-form repaint
fault are distinguished from this investigation's own measurements.

## Accessibility fix — measured cause and isolated validation

The probe has been approved for Accessibility. Its original executable and
the original runner remain unchanged. Live expanded inspection and independent
hit tests establish a broken parent/child enumeration contract, with a native
positive-control reproduction confirming the relevant Cocoa behavior.

### Measured diagnosis

`mac-ax-probe-004` reads the Preferences scroll container's AXChildren,
AXContents and AXChildrenInNavigationOrder successfully, but each has no
children. This is not an attribute timeout or denied permission. A second
graph walk after hit testing still exposes no footer buttons.

Direct AX hit tests at the three measured footer centers succeed and identify:

| Hit target | AXRole | AXEnabled | Action |
| --- | --- | --- | --- |
| Save and close | AXButton | true | AXPress |
| Cancel | AXButton | true | AXPress |
| Save | AXButton | false | AXPress |

Each button's reported parent is the same AXScrollArea whose child lists are
empty. The buttons exist as accessible native objects; the hierarchy prevents
normal discovery. These hit tests do not replace the failing hierarchy
assertion and are not used for automated clicks.

The installed Lazarus source at commit
`62c14a4d18c81f222127d42ce9b89b922c63fcbf` creates the form/scroll-document view
as TCocoaCustomControl, an NSControl subclass. It does not override
accessibilityChildren. A standalone Cocoa reproduction with nested containers
and three native buttons produced:

| Container implementation | Footer exposed through the graph |
| --- | --- |
| Generic NSControl, matching the relevant inheritance | No |
| Plain NSView | Yes, all names and enabled states correct |
| NSControl with accessibilityElement set to false | No |
| NSControl overriding accessibilityChildren to return NSAccessibilityUnignoredChildren(subviews) | Yes, all names and enabled states correct |
| Same override, filtering hidden views before enumeration | Yes, and hidden buttons/hidden-panel descendants stay absent |

The first override exposed hidden descendants in an extended native regression
test. It is superseded by the checked-in patch, which filters each child with
isHiddenOrHasHiddenAncestor before calling NSAccessibilityUnignoredChildren.
The native fixture preserves the unfiltered variant as a negative control.
All five cases assert their expected names, enabled states and hidden sentinel
visibility; the final filtered variant matches plain NSView for those checks.

The standalone fixture used the isolated test slot while the full release
bundle was parked safely. The harness restored the original complete release,
verified its original executable hash and deep/strict signature, and stopped
each owned fixture process. It did not modify the operator app or the CI
toolchain. Fixture source: [mac_ax_container_control.m](mac_ax_container_control.m);
harness: [run_mac_ax_container_control.py](run_mac_ax_container_control.py).

Evidence: [expanded run result and hit/parent data](../../docs/gui-test/mac-ax-probe-20261115/result.json),
[initial expanded graph](../../docs/gui-test/mac-ax-probe-20261115/preferences-tree.json),
[post-hit graph](../../docs/gui-test/mac-ax-probe-20261115/post-hit-tree.json),
[native positive-control summary](../../docs/gui-test/mac-ax-probe-20261115/container-control/summary.json).

### Applied private fix and validation boundary

The [Lazarus Cocoa patch](patches/lazarus-cocoa-container-accessibility.patch)
adds one accessibilityChildren override to TCocoaCustomControl. It implements
the native behavior proven by the positive control at the shared widgetset
layer, rather than adding labels to individual buttons or working around
discovery with coordinates. The installed FPC Cocoa binding already declares
the selector and NSAccessibilityUnignoredChildren; no new dependency is needed.

Tom authorized continuing the isolated build plan. Cocoa LCL and TR4W were
built from private Lazarus copies and a detached application worktree:

- TR4W revision: `ed126e424ab57c735129234582fc03b597b146d2`, no tracked changes.
- Lazarus revision: `62c14a4d18c81f222127d42ce9b89b922c63fcbf`.
- Baseline copy: `~/tr4w-gui-test/toolchain/lazarus-ax-baseline`, no tracked diff.
- Patched copy: `~/tr4w-gui-test/toolchain/lazarus-ax-fix`, one file/23 inserted lines.
- FPC: 3.2.2, `~/fpcupdeluxe/fpc/bin/aarch64-darwin/fpc`.
- Final experimental bundle: `~/tr4w-gui-test/app/TR4W-ax-visible.app`.
- Final executable SHA256: `23ef2627830b13d02a346e0a58dcadb3155b10e194edcb24e1ce4405c3c8a654`.
- Patch SHA256: `fd25f3d00b289996134462fe4e14ab593126479a0010b10eb03af9577fdcaa30`.

| Live comparison | Footer graph | Other measured result |
| --- | --- | --- |
| Same-source unpatched build, `mac-ax-baseline-001` | FAIL, all three absent | Navigation works; shutdown 217 |
| Final filtered patch, `mac-ax-visible-001`, expanded probe | PASS, exact names/enabled states | Navigation works; shutdown 217 |
| Same final build, `mac-ax-visible-original-runner-001` | PASS using original AXChildren reader | Release restoration recorded; shutdown 217 |
| Same final build, `mac-ax-visible-footer-001` | PASS | Observed keyboard focus, Space activates Cancel and Save and close; shutdown 217 |

All original fields of all 101 contacts remain unchanged. Default settings and
contest-file inventories are unchanged. The full release bundle is restored
after each experimental run and its original hash and deep/strict signature
are verified. Neither approved helper was rebuilt or reapproved.

Evidence: [final build record](../../docs/gui-test/mac-ax-fix-20261115/build.json),
[same-source baseline](../../docs/gui-test/mac-ax-fix-20261115/baseline/result.json),
[final expanded result](../../docs/gui-test/mac-ax-fix-20261115/result.json),
[original-reader result](../../docs/gui-test/mac-ax-fix-20261115/original-runner-result.json),
[footer action result](../../docs/gui-test/mac-ax-fix-20261115/footer-actions-result.json),
[native visibility regression](../../docs/gui-test/mac-ax-fix-20261115/container-control-summary.json),
[Lazarus subclass regression](../../docs/gui-test/mac-ax-fix-20261115/lcl-container-summary.json).

The small [Lazarus fixture](mac_lcl_ax_control.lpr) also passes with each tab
selected in a separate launch. The active page's button, panel child and
status-bar child are present; the inactive page's button and both hidden
sentinels are absent. A splitter is instantiated and queried as part of the
same tree. This checks basic visibility and traversal, not interactive tab
switching, splitter dragging or status-bar painting.

This validates the shared Cocoa container fix for the measured Preferences
case. It is not a release certification or a complete accessibility audit.
The sidebar's custom-drawn navigation, other control types, dirty Save/Cancel
persistence and other macOS versions remain untested. The override also
applies to TCocoaCustomControl subclasses (tab pages, status bars and splitter
owner controls); their interactive behavior needs broader coverage before a
global toolchain rollout. It does work only when an accessibility client queries it,
with a pass over the immediate subviews and an autoreleased native array.
It adds no startup/background work or dependency.

Build/application instructions and rollout boundaries are in
[patches/README.md](patches/README.md). The installed Lazarus/CI sources have
not been changed. Do not promote the unfiltered initial patch or mark the
overall GUI pilot green while shutdown returns 217.

### Probe setup and protocol

Tom authorized work to resolve the missing-button issue. The updated reader
is built as a **separate** app so the original approved runner and its grants
remain intact:

- App: `/Users/<user>/Applications/TR4W AX Probe.app`.
- Bundle ID: `net.tr4w.gui-pilot.ax-probe`.
- Executable SHA256:
  `ce2b843ccf00eb9fbd158fd1eef9a04eec8f7cbd0ebfc58123f4afa15a738dc0`.
- Required permission: **Accessibility only**. It does not request Screen
  Recording and refuses keyboard, activation and capture jobs.

The probe is compiled from the shared native source with `TR4W_AX_PROBE=1`.
It records supported attributes/actions and the numeric AX error for every
failed read. Its graph walk follows AXChildren, AXContents, AXVisibleChildren,
AXChildrenInNavigationOrder and AXWindows, retains the edge relation and uses
CF identity comparisons to deduplicate nodes and stop cycles. This separates
empty arrays from unsupported attributes or failed IPC. The same depth/node
limits remain in force.

It can also perform read-only AX hit tests and record each returned element's
parent chain. For the already reviewed 860x648-point Preferences window, the
coordinator supplies the measured footer centers. These points are diagnostic
queries only: they are never used to click a button or pass the named-control
assertion. At another window size it does not guess those points.

The coordinator's new `--ax-probe` option uses this app only for inspection.
The unchanged original runner still supplies activation, keys and screenshots.
Both app identities are checked against their recorded executable hashes.
Native compilation and signature verification pass, as do the 15 portable
harness tests. The earlier `mac-ax-preflight-001` stopped without a TR4W launch
before the probe was granted Accessibility; subsequent live runs confirm the
grant. This initial result is a setup result, not an application failure.

To grant the probe's one permission, launch its setup on mac-ci:

```bash
ssh mac-ci 'open "$HOME/Applications/TR4W AX Probe.app"'
```

Click Request Accessibility and enable **TR4W AX Probe** under Privacy &
Security > Device Control and Data Access. The new setup window exits after
opening that page, avoiding the prior repeated request-window loop. The
original TR4W GUI Pilot does not need to be removed, reset or reapproved.

Then rerun with a fresh run name:

```bash
/usr/bin/python3 "$HOME/tr4w-gui-test/run_mac_pilot.py" \
   --database-template "$HOME/tr4w-gui-test/practice-source.db" \
   --settings-template "$HOME/tr4w-gui-test/tr4w.json" \
   --ax-probe
```

The live expanded result is recorded above. Accessibility Inspector is also
installed with Xcode on mac-ci if independent visual inspection is needed.
No application Pascal or installed Lazarus sources have been modified here;
only the private Lazarus copy carries the patch described above.

An initial expanded run used the AX-only probe for WindowServer window names,
which macOS redacts without Screen Recording permission. The coordinator now
keeps that inventory on the original approved runner. Another diagnostic used
WindowServer's frame, which has a one-point border beyond the AX frame, so the
measured-size guard correctly omitted its hit tests. The final run uses the
observed AX rectangle and includes all three queries. Neither early diagnostic
mistake is an application defect or a reason for broader permissions.

## Live result: mac-pilot-004

Host: macOS 27.0 arm64, toms's logged-in desktop. The v5.0.40 binary is identified
below. Both native permission checks pass. All 101 contacts retain their
original fields; added schema-migration columns are recorded separately.
Default settings and contest-file size/mtime inventories are unchanged.

| Check | Result |
| --- | --- |
| Launch the disposable practice log | PASS |
| ScreenCaptureKit main/Preferences captures | PASS, reviewed at native Retina resolution |
| Control+J opens Preferences | PASS |
| Escape dismisses Preferences | PASS |
| AX clean-footer assertion | FAIL, content controls absent from the current AXChildren walk |
| Native Command+Q | Application exits 217, no application confirmation observed |
| Original contact values / default user files | Unchanged |

The Preferences AX subtree contains its window, an empty AXScrollArea, title
and native traffic-light buttons. It does not expose the visible Save and
close, Cancel or Save buttons through the current walk. Screenshots show those
buttons and the disabled Save, but visual review is not a passing AX assertion.
The later independent probe, native reproduction and same-source comparison
above establish the Cocoa parent/child enumeration defect. This historical
result remains archived; it describes the original unpatched release.

The crash log provides an independent macOS reproduction of the Preferences
shutdown problem: its first recorded EAccessViolation is in
`TApplication.RemoveAsyncCalls` from `TPrefsForm.Destroy`, reached through
`uPrefsForm` unit finalization. A subsequent exception names
`TCustomTimer.KillTimer` in `uAppTimers` finalization. No LLDB receiver/locals
capture has been made on macOS, so retain the distinction between this stack
and Linux's GDB observation of a nil Application receiver.

Evidence: [result](../../docs/gui-test/mac-pilot-20261115/result.json),
[main](../../docs/gui-test/mac-pilot-20261115/main.png),
[Preferences](../../docs/gui-test/mac-pilot-20261115/preferences.png),
[AX tree](../../docs/gui-test/mac-pilot-20261115/preferences-tree.json),
[crash records](../../docs/gui-test/mac-pilot-20261115/shutdown-crash.txt),
[steps](../../docs/gui-test/mac-pilot-20261115/steps.jsonl).
Full artifacts are on mac-ci in `~/tr4w-gui-test/artifacts/mac-pilot-004/`
and locally under `build-out/mac-gui-pilot/` in this worktree.

After Tom reported approving an additional macOS permission, the unchanged
runner again reported both required permissions granted. A fresh run,
`mac-pilot-005`, reproduced the same AX footer failure and exit 217, with
navigation/capture working and original contacts/default settings/default
contest files unchanged. The exact additional prompt was not established from
the permission logs. [Post-approval result](../../docs/gui-test/mac-pilot-20261115/post-approval-result.json).

Run 001 encountered NSRunningApplication's startup-registration delay; the
coordinator now retries that validation only during startup of its own PID.
Run 002 established the footer-tree limitation. Runs 003 and 004 independently
reproduced exit 217. These early driver/setup failures are not new application
defects. The last run records the actual application exit, original-contact
comparison and independent failed footer assertions together.

### Reproduce from mac-ci

The scripts, source fixture and settings template are already staged:

```bash
/usr/bin/python3 "$HOME/tr4w-gui-test/run_mac_pilot.py" \
   --database-template "$HOME/tr4w-gui-test/practice-source.db" \
   --settings-template "$HOME/tr4w-gui-test/tr4w.json"
```

The automatic unique run name avoids overwriting evidence. Exit 0 requires all
assertions and application exit 0; the current result is exit 1. Use an exclusive
test desktop. The coordinator refuses an existing TR4W process, holds a file
lock and stops only the process it launched. It uses a relative database path
from the fresh run directory to avoid the known slash-switch parser defect.
Native jobs run with `open -g -W -n` so the helper does not take foreground
focus from TR4W. `launchctl asuser` was unnecessary and was denied to the
unprivileged SSH session; no privilege change was made.

The shared `fixture_data.prepare_offline_fixture` is now called by both Linux
and macOS coordinators. It retains the existing offline fixture preparation
and SQLite snapshot behavior. The macOS coordinator appends to the application's
normal `~/Library/Logs/TR4W/tr4w.log` and saves only that run's appended slice;
it does not truncate, rename or relocate the user's log. XDG variables are not
used to pretend that macOS log/settings paths have moved. Default settings and
contest folders are inventoried before/after. The old operator bundle is not
launched. Normal application keychain/NTP startup behavior is not certified
or replaced by this navigation test.

Fifteen portable tests pass on Windows, and the four shared fixture tests also
pass on mac-ci. Compilation and native signature checks pass. These results do
not turn the live pilot green or certify every Cocoa control.

## Installed identity and user approval

App: `/Users/<user>/Applications/TR4W GUI Pilot.app`.
Bundle ID: `net.tr4w.gui-pilot`.
Executable SHA256:
`95b23ad52400eb84543517455e79a0812f6ab739ffecb71c21aa69631c3a5ff6`.
The app is ad-hoc signed and its signature was verified. No private signing
identity was used. Preserve this executable after approval; rebuilding can
invalidate permissions and needs explicit identity/approval review.

To launch its permission setup on mac-ci's logged-in desktop:

```bash
ssh mac-ci 'open "$HOME/Applications/TR4W GUI Pilot.app"'
```

The app shows its current status and buttons to request Accessibility and
Screen Recording. Requests are made only by the user's button click; the
preflight never triggers a permission prompt or launches TR4W.

These commands open the two relevant settings pages on that Mac:

```bash
ssh mac-ci 'open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"'
ssh mac-ci 'open "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"'
```

In Privacy & Security, enable **TR4W GUI Pilot** for Accessibility and Screen
& System Audio Recording. The bridge captures window images, with audio
disabled. If the app is not listed, request the permission from its setup
window or use the settings pane's Add button and select the exact app above.
Close/reopen it if macOS requests a restart. macOS 27 displays the Accessibility
page as **Device Control and Data Access**. Full Disk Access, Terminal
approval and Apple Events Automation are not required by the chosen bridge.
If the helper's request window appears to loop, close it, add/enable the exact
app in the settings list, then reopen it. Avoid repeatedly pressing the request
button; the window reports status but cannot approve its own request.

On this Mac, `man tccutil` exposes reset, not grant. There is no supported
ordinary shell command to grant these two permissions on an unmanaged Mac.
Do not edit TCC databases, disable system protections or reset existing
permissions as a setup shortcut. Initial user approval in the UI is required;
it has already been completed for the two recorded helper identities on mac-ci.

After closing its setup window, an agent can verify the same identity without
requesting permissions:

```bash
ssh mac-ci 'open -W -n "$HOME/Applications/TR4W GUI Pilot.app" --args --preflight; cat ~/tr4w-gui-test/artifacts/mac-preflight.json'
```

Both `accessibility` and `screen_recording` must be true/nonzero before live
automation. This status is permission readiness, not a passing application
test. Saved preflight/build identity:
[preflight](../../docs/gui-test/mac-preflight-20261115/mac-preflight.json),
[build identity](../../docs/gui-test/mac-preflight-20261115/mac-runner-build.json).

## Native bridge architecture

[mac_pilot.m](mac_pilot.m) uses AppKit, Accessibility, CoreGraphics and
ScreenCaptureKit directly. [run_mac_pilot.py](run_mac_pilot.py) is the standard-
library coordinator. It needs no pip packages or third-party automation
framework. [build_mac_pilot.py](build_mac_pilot.py) invokes the native compiler,
assembles the app bundle, signs it ad-hoc and verifies its signature.
The second unapproved development build compiled without warnings.

Default launch shows permission setup. `--preflight` records permission and
identity status and exits. `--job <path>` accepts a JSON job under
`~/tr4w-gui-test/jobs/`, with a new result path under
`~/tr4w-gui-test/artifacts/`. The compiled job operations are:

- `preflight`: read permission state without requesting it.
- `inspect`: walk the target process's AX tree and list its on-screen windows.
- `activate`: request foreground activation of the target app.
- `key`: post a limited set of real keys/modifiers, requiring target foreground.
- `capture`: capture the specified owned window through ScreenCaptureKit,
  requiring screen permission and target foreground before/after capture.

All target operations require Accessibility permission and validate the PID's
executable against `~/tr4w-gui-test/app/TR4W.app/Contents/MacOS/tr4w`. They cannot
be used against the older operator application or unrelated desktop apps.
The AX walk has depth/node limits and a per-message timeout. Capture retains
image data before crossing its asynchronous callback boundary. The coordinator
still needs to enforce overall deadlines, own application PIDs and validate
observable UI outcomes; an operation returning successfully is not acceptance
of the application's behavior.

Live inspection, key injection and capture have now been exercised, with the
specific limitations in the result above. No GUI verdict is inferred from code
alone. Do not reuse Windows or Linux screenshot baselines for Cocoa rendering.

The builder refuses to overwrite an installed runner by default. Its explicit
`--replace-unapproved` development option first runs the existing app's own
preflight and refuses either granted permission, then retains the prior
unapproved bundle under `~/tr4w-gui-test/source/`. That option was used before
requesting user approval. Never approve the archived development copy.

## TR4W build selected for the next stage

The existing `~/Applications/TR4W.app` is v5.0.2 and was left untouched.
The complete packaged v5.0.40 bundle from the CI distribution was copied to
`~/tr4w-gui-test/app/TR4W.app` with ditto; its deep/strict signature verification
passed. Its executable SHA256 is:
`6be86420d44ebfde4b00336418f4ece3c2c53ce80126c963b01896e9eb3ef321`.
Build-time source revision has not been certified. This is the bundle used in
the live pilot; its binary was not rebuilt or modified.

Next: review and integrate the external Cocoa patch into the managed macOS
toolchain, with regression coverage for its other container subclasses.
Coordinate the separate shared shutdown lifetime fix with the other agent,
then rerun against an identified fresh build. Save/Cancel edits across restart
and broader window coverage remain untested.

The shutdown findings and another agent's review remain separate application
work in [SHUTDOWN_LIFECYCLE_REVIEW.md](../../docs/SHUTDOWN_LIFECYCLE_REVIEW.md).
