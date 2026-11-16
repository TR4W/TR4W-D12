# Preferences reload defects found by the native GUI regression

November 16, 2026. Isolated worktree:
`C:\tr4w-d12\.worktrees\linux-gui-pilot`, branch `codex/linux-gui-pilot`.
Main and its other agent's working changes were not modified.

## Observed defects and minimal correction

On Debian, workflow artifact `43776700899` at source
`4547b9117f4d5c23a3606bd4de9477d5eb4b5019` passes navigation and normal exit 0.
Its generated Preferences controls lose their dirty handlers after Cancel
rebuilds them: changing Radius Of Earth updates the visible text while Save
stays disabled. HookDirtyMarkers runs during construction only. The fix calls
the existing HookDirtyMarker for each generated control at creation; existing
custom handlers are preserved by that helper.

Continuing the stronger regression exposed a second reload failure: newly
generated pages start hidden, but the selected navigation node survives Cancel.
Selecting that same node again does not fire a change event. The search focus
timer cannot focus the hidden replacement control. Its timeout warning uses
IfThen with ActiveControl.Name as an argument; Pascal evaluates that argument
even when ActiveControl is nil.

GDB caught the first SIGSEGV in FocusTimerTick at the warning expression
(uPrefsForm.pas:5557 in the one-dirty-hook diagnostic build). This is an
in-session failure, separate from the earlier application shutdown defect.
The screenshot shows the Advanced page blank behind the access-violation
dialog. The tester does not dismiss or ignore that exception.

The Linux reload correction changes one application unit, 21 additions/one deletion:

- Attach the existing dirty hook at generated-control creation.
- Stop the search-focus timer and clear its target before freeing generated
  controls. This preserves the pending-callback lifetime invariant; it is not
  claimed as the cause of the captured warning-expression crash.
- Reapply the existing tvNavChange routine after rebuilding pages, retaining
  the selected page through the existing visibility rule.
- Read ActiveControl.Name only inside an explicit nil guard in the warning.

No new application abstraction or dependency is added. The extra visibility
pass runs only during page rebuild; dirty hooks attach once per new control.
The existing loading guards suppress edit notifications during population.

## Verification

The native Linux build used a detached worktree on `linux-ci-build`, FPC 3.2.2
and installed Lazarus 3.0. Source is the revision above plus the exact
[application patch](gui-test/linux-prefs-persistence-20261116/application.patch),
SHA256 `01a9caf49d22dcc951ee672eef55b7f3dcebf724572e5d54266d65eeeb1b84ec`.
The CI checkout files and installed toolchain were not changed.

`linux-prefs-persistence-006` passes Cancel, Save, restart, baseline restoration,
and a second restart. All three application exit codes are 0. All 101 contacts'
original fields remain unchanged; added migration fields are recorded
separately. The disposable setting's UI and independent JSON value agree.

The full sequence was then repeated under GDB as
`linux-prefs-persistence-gdb-002`: three distinct inferiors, all exit 0,
zero SIGSEGV stops and zero EACCESSVIOLATION markers. Each debugger launch
uses a unique inferior PID file so restart cannot adopt a stale PID.
[Passing GDB result](gui-test/linux-prefs-persistence-20261116/gdb-result.json),
[complete fixed GDB transcript](gui-test/linux-prefs-persistence-20261116/fixed-gdb.txt).

Evidence: [passing result](gui-test/linux-prefs-persistence-20261116/result.json),
[steps](gui-test/linux-prefs-persistence-20261116/steps.jsonl),
[dirty-hook failure](gui-test/linux-prefs-persistence-20261116/dirty-hook-failure.json),
[GDB diagnostic](gui-test/linux-prefs-persistence-20261116/reopen-gdb.txt),
[native build log](gui-test/linux-prefs-persistence-20261116/build.log).

Driver/setup failures are retained separately: Enter did not activate the GTK
search result; mousemove --sync stalled when the cursor was already there;
an initial fixture value used metres instead of the required kilometres and
was correctly rejected by application validation. The accepted run uses
named rows, verified cursor position and valid values. No assertion was removed.

## Final cross-platform patch and passing Mac persistence

After Accessibility approval, the Mac test exposed another application defect:
typing just "RA" activated Radius Of Earth without an explicit choice. The
native listbox sends selection notifications during result population and the
default ClickOnSelChange converts them into OnClick. The search overlay now
sets ClickOnSelChange=False, keeping highlighting separate from activation.
This is a control configuration change using an existing public LCL property,
not a new platform-specific event workaround or another widgetset patch.

The final application diff is 24 additions/one deletion in the same unit.
[Final patch](gui-test/linux-prefs-persistence-20261116/application-search.patch),
SHA256 `c6e9acbb7f8dd2eaa15353638711abf01fc0976dfe898ea21f1080c8b1d4d0d2`.
The original 21-line reload correction and its earlier evidence stay archived.

The complete shared case passes on Mac as `mac-prefs-persistence-010`:
Cancel discards the edit, Save survives restart, Save and close restores the
baseline across another restart, all three processes exit 0, all 101 original
contacts and default user files are unchanged, and the release bundle is
restored. Its executable SHA256 is
`c4fa935a3ecab7be5cf0642e8894a1758ddcae9693e4161604320a62717dbae2`.
The build uses the same identified base plus this app patch and the separate
private Cocoa accessibility patch. The approved helper binaries are unchanged.
[Mac result](gui-test/mac-prefs-persistence-20261116/result.json),
[auto-activation failure](gui-test/mac-prefs-persistence-20261116/search-autoactivation-failure.json),
[application log](gui-test/mac-prefs-persistence-20261116/search-autoactivation.log).

The final application patch also passes the full Linux sequence under GDB as
`linux-prefs-search-gdb-001`, three exits 0, zero SIGSEGV stops and zero
EACCESSVIOLATION markers. Its executable SHA256 is
`65b038b6cbd3c7864d31691792a2188fdb7faa9627d063f66ff1d5551e63c87c`.
[Final Linux result](gui-test/linux-prefs-persistence-20261116/final-gdb-result.json).

Mac driver issues were distinguished from app defects: bulk text posting
delivered a prefix, so the driver acknowledges each character; virtual result
cells hit-test as their table, so it proves the table center lies in the unique
result before requesting a native hit-validated click. No helper guard was
loosened. Cocoa owner-drawn result captions and Return activation remain
unverified/unsupported by this persistence case; neither is certified here.

Windows was not rerun for this application patch. Review and integrate the
small application change separately from the GUI harness when appropriate.

## Integration handoff

Application correction: commit `72f9f92c` on `codex/linux-gui-pilot`.
The following commit on that branch contains the native harness, documentation,
external Lazarus patch and evidence. Cherry-pick these commits in order; the
application commit can also be reviewed and integrated independently.

The branch starts at `ed126e42`, while native validation used source
`4547b911` plus the exact application patch archived above. Do not merge the
old branch base over newer main changes. The external Cocoa patch requires
the separate toolchain procedure in tools/gui_test/patches/README.md; merely
cherry-picking the harness does not alter an installed Lazarus toolchain.
