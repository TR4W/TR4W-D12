# Shutdown lifetime review — concurrence and original evidence

Prepared November 15, 2026. Updated after Tom supplied the receiving agent's
reply. Tom reports approval of the Interfaces-order correction and the other
agent is implementing it. Application ownership changes remain separate.
The original investigation below is retained with its validation boundaries.

## Native verification after the ordering correction, November 16

The Linux workflow artifact from run `43776700899`, checked out at
`4547b9117f4d5c23a3606bd4de9477d5eb4b5019`, now passes Preferences open/hide
and normal exit with application status 0. All 101 original contacts remain
unchanged. [Identified workflow smoke result](gui-test/linux-prefs-persistence-20261116/workflow-smoke-result.json).

The stronger Linux Save/Cancel/restart scenario exposed separate Preferences
reload defects, corrected in a small private source patch. It passes with
three normal application exits, all 0. A private Mac build of the same base
plus the reload patch and Cocoa accessibility patch passes the Mac smoke and
clean footer actions with normal exit 0, unchanged contacts/default files and
verified release restoration. [Linux persistence](gui-test/linux-prefs-persistence-20261116/result.json),
[Mac smoke](gui-test/mac-prefs-persistence-20261116/smoke-result.json),
[separate reload review](PREFERENCES_RELOAD_GUI_REVIEW.md).

These measurements supersede the older exit-217 results for those exact paths
and builds. They do not validate /EXPORT, tr4wserver, all retained windows or
Windows finalizers. The receiving agent's broader release gates remain distinct.

The final Preferences reload/search patch now passes the same persistence
sequence on both platforms: three independent process exits 0 per platform,
unchanged original contacts, and verified baseline restoration across restart.
The final Linux GDB run has no SIGSEGV stops or EACCESSVIOLATION markers.
[Final Linux GDB result](gui-test/linux-prefs-persistence-20261116/final-gdb-result.json),
[Mac persistence result](gui-test/mac-prefs-persistence-20261116/result.json).

## Concurrence with the receiving agent's correction

The nil Application is a symptom of widgetset teardown order, not a
Preferences-specific ownership diagnosis. Concur with explicitly linking
Interfaces before TR4W units in tr4w.lpr, while retaining cthreads and cwstring
ahead of it on Unix. This addresses the common prerequisite for UI finalizers
instead of moving only gPrefsForm cleanup. Concur with removing demonstrated
logging after logger teardown; audit actual ownership rather than moving the
logger's lifetime speculatively.

Source checks made after the reply:

- The isolated pre-fix tr4w.lpr does not name Interfaces; uLCLCoexist reaches it
  through its implementation uses clause. The server and unit-test entry
  points explicitly list Interfaces early, below the Unix manager units.
- The installed mac-ci Lazarus source at revision
  `62c14a4d18c81f222127d42ce9b89b922c63fcbf` has Cocoa Interfaces finalization
  call FreeWidgetSet. In lcl/forms.pp:2361-2375, FreeWidgetSet calls
  Application.Free, sets Application and CustomApplication to nil, calls
  interface finalization handlers and frees WidgetSet.
- Main's working tr4w.lpr now explicitly lists Interfaces ahead of SysUtils
  and MainUnit, below the Unix manager units. This is an observed uncommitted
  source change, not a completed release or platform verification.

The receiving agent reports these Windows measurements; they were not
independently rerun in this worktree: with finalizers enabled, no Preferences
opened faults in TCustomTimer.KillTimer; opened/hidden Preferences faults
inside FreeWidgetSet with 0xC000041D; Interfaces first keeps Application
assigned through all 13 observed finalizers and gPrefsForm cleanup is clean.
The agent also reports a remaining main-form repaint after themes teardown.
Do not mark shutdown fixed until that remaining fault and the intended gates
are resolved. Do not change every form owner as an incidental follow-up;
cached globals and destruction order require their own reviewed change.

## Linux trace to return to the receiving agent

The Linux first crash site differs from the reported Windows opened/hidden
case, but is consistent with the shared ordering defect. On `debian`
(toms@findaclub-staging, Debian 13 x86_64), run `linux-gdb-002` opened
Preferences, hid it with Escape, then closed the main window and confirmed
the observed exit question. GDB caught the first shutdown SIGSEGV before
Pascal handling:

```text
#0 TApplication.RemoveAsyncCalls(this=0x0, AnObject=0x7ffff40a1990)
   include/application.inc:2345
#1 TCustomForm.Destroy(this=0x7ffff40a1990)
   include/customform.inc:128
#2 TPrefsForm.Destroy(this=0x7ffff40a1990)
   src/ui/lcl/uPrefsForm.pas:2321
...
#7 uPrefsForm finalization
   src/ui/lcl/uPrefsForm.pas:9383
#8 System.FinalizeUnits
```

After continuing, later SIGSEGV stops included TCustomTimer.KillTimer at
customtimer.pas:103 through uAppTimers finalization at uAppTimers.pas:188,
and a null call from uRadioHamLibDirect finalization at line 1572. These later
stops support the wider audit but are not isolated first-fault reproductions.
We did not run the Preferences-never-opened case or instrument all unit
finalizers in this Linux session. No Windows-style menu-drawing failure was
the first captured Linux SIGSEGV. The earlier caught Pascal exceptions include
the intentional crash-symbol startup probe; distinguish them from shutdown.

Exact evidence: [first SIGSEGV/main-thread stack](gui-test/linux-pilot-20261115/shutdown-gdb.txt#L237),
[later timer stop](gui-test/linux-pilot-20261115/shutdown-gdb.txt#L1036),
[later HamLib finalizer stop](gui-test/linux-pilot-20261115/shutdown-gdb.txt#L1264),
[full run result](gui-test/linux-pilot-20261115/shutdown-gdb-result.json).
The archived executable SHA256 is
`f775c35156cc45bda4c4fa5b2ce7a60d2215fda17a99ea37830f12fb0f48d806`;
its source revision is unknown. The embedded line numbers above belong to
that binary, not necessarily today's checkout. No corrected-order Linux
build has been exercised by this investigation yet.

The receiving agent owns the application fix and release-workflow validation,
including corpus /EXPORT and tr4wserver. Our Mac Cocoa accessibility patch
remains isolated and independent. Rerun the Linux/Mac GUI pilot against the
identified fixed build, preserving shutdown exit assertions and original
contact comparisons. mac-ci must first have an unlocked console session.

## Original decision request

Concur or disagree with this recommendation: correct the confirmed Preferences
shutdown defect, then audit the shared shutdown path for the same lifetime
violation in retained forms, timers, subscriptions, queued callbacks and
logging. Apply small fixes to demonstrated violations. A finding in one form
does not establish that every finalizer is defective or justify a framework
rewrite.

The required invariant is: **a dependent object must be stopped and destroyed
before the service its cleanup needs is destroyed.** For UI forms that includes
the live LCL Application/widgetset; for cleanup that logs, it includes valid
logging infrastructure. Removing a callback must precede freeing its target.

## Workspace and evidence provenance

- Review worktree: `C:\tr4w-d12\.worktrees\linux-gui-pilot`.
- Branch: `codex/linux-gui-pilot`; base commit
  `ed126e424ab57c735129234582fc03b597b146d2`.
- The original shutdown investigation did not change application Pascal sources.
  Subsequent Preferences reload corrections are committed separately as
  `72f9f92c`; harness, documentation and evidence accompany them in a second
  commit on this branch. See PREFERENCES_RELOAD_GUI_REVIEW.md for integration.
- Main has unrelated work in progress. Inspect its current state before
  implementing or integrating anything; do not overwrite another agent's work.
- The original live pilot and GDB runs used `debian`.
  It connects as `toms@findaclub-staging`, Debian 13 x86_64. A subsequent native
  mac-ci pilot also reproduced the shutdown failure; see the follow-up below.
- Binary: user-staged v5.0.40 Linux release, SHA256
  `f775c35156cc45bda4c4fa5b2ce7a60d2215fda17a99ea37830f12fb0f48d806`.
  Its build-time source revision is **unknown**. Current checkout line numbers
  differ from the binary's embedded symbols. Do not certify the binary as a
  build of the worktree base commit.

Primary evidence:

- [Complete GDB transcript](gui-test/linux-pilot-20261115/shutdown-gdb.txt).
- [Debugger run result](gui-test/linux-pilot-20261115/shutdown-gdb-result.json).
- [Original pilot result](gui-test/linux-pilot-20261115/result.json).
- [Pilot architecture, setup, findings and reproduction](../tools/gui_test/LINUX.md).

### mac-ci follow-up, November 15

With the native helper approved for Accessibility and Screen Recording,
`mac-pilot-004` on macOS 27 arm64 also returns exit 217 after opening/hiding
Preferences and sending native Command+Q. No application exit question is
observed on that native Quit path. All original fields of the 101 practice
contacts, default settings and default contest-file inventories are unchanged.

The **first recorded** EAccessViolation is in
`TApplication.RemoveAsyncCalls`, from `TPrefsForm.Destroy`, through
`uPrefsForm` finalization. A subsequent fault names `TCustomTimer.KillTimer`
in `uAppTimers` finalization. This adds live macOS evidence to the shared
lifetime review; the timer fault remains a later fault whose independence from
the first must be investigated. No LLDB capture of the receiver has been made,
so only Linux has directly established `Application = nil` in debugger locals.

Mac executable SHA256:
`6be86420d44ebfde4b00336418f4ece3c2c53ce80126c963b01896e9eb3ef321`.
The crash log identifies Mach-O UUID `05074080-332D-3D28-90DA-44BDBB084CEC`.
It is a user-staged v5.0.40 bundle with uncertified source revision, distinct
from the Linux executable. Match any dSYM to that UUID before symbolication.

See [macOS result](gui-test/mac-pilot-20261115/result.json),
[crash records](gui-test/mac-pilot-20261115/shutdown-crash.txt) and
[macOS pilot report](../tools/gui_test/MACOS.md). The Cocoa footer AX assertion
also fails and is documented separately; do not conflate it with the shutdown
exception. Neither platform's application code has been changed here.

Later same-source macOS builds identify TR4W revision
`ed126e424ab57c735129234582fc03b597b146d2` with no tracked application changes.
Both the unpatched Cocoa baseline and the isolated Cocoa accessibility fix
still exit 217. The accessibility fix makes the Preferences footer assertion
and clean Cancel/Save and close keyboard actions pass; it does not address
shutdown. See the [known-source baseline](gui-test/mac-ax-fix-20261115/baseline/result.json)
and [final-patch button-action run](gui-test/mac-ax-fix-20261115/footer-actions-result.json).
This is additional reproduction evidence, not another agent's concurrence
or an accepted application lifetime fix.

On Debian the exact executable is retained at
`~/tr4w-gui-test/evidence/<SHA256>/tr4w`; debugger artifacts are in
`~/tr4w-gui-test/artifacts/linux-gdb-002/`. Full local artifacts are under this
worktree's `build-out/linux-gui-pilot/`.

## Confirmed failure

Reproduction: launch a fresh disposable copy of the CQ-WW-SSB corpus log,
open Preferences with Ctrl+J, dismiss it with Escape, request normal main-window
close, and confirm the observed exit question. Navigation works. The application
returns **217**, repeatedly. All original fields of the 101 contacts are
unchanged; the application's schema migration adds columns separately.

GDB 16.3, run `linux-gdb-002`, catches the **first** shutdown SIGSEGV here:

```text
#0 TApplication.RemoveAsyncCalls(this=0x0, AnObject=<Preferences instance>)
#1 TCustomForm.Destroy
#2 TPrefsForm.Destroy
...
#7 uPrefsForm unit finalization
```

This establishes that the Preferences instance is destroyed during unit
finalization when the LCL Application object used by its inherited destructor
is already nil. The underlying path by which that Application was destroyed
must still be checked against the applicable Lazarus version before choosing
the cleanup hook. The stack proves the lifetime violation; it does not by
itself prove the best hook or ownership implementation.

The current source matches the relevant pattern in
[uPrefsForm.pas](../tr4w/src/ui/lcl/uPrefsForm.pas):

- `ShowPreferences` creates `gPrefsForm` with `TPrefsForm.Create(nil)`.
- Closing Preferences uses `caHide`, retaining the instance for reuse.
- The unit's `finalization` section calls `FreeAndNil(gPrefsForm)`.
- `TPrefsForm.Destroy` ultimately calls its inherited form destructor.

Later debugger stops involve HamLib-module finalization logging, Log4D and
thread-local/critical-section machinery. These are subsequent faults, not
evidence that HamLib or NTP caused the first SIGSEGV. Ordinary logs reach
program shutdown and factory finalization without recording the original
fault; logging cannot be assumed reliable during the failing teardown.

## Why a shared audit is warranted

[MainUnit.tr4w_ShutDown](../tr4w/src/MainUnit.pas) explicitly stops services,
closes the database, logs shutdown and calls `FreeAndNil(logger)`. It then
uses `ExitProcess(0)` on Windows and `Halt(0)` elsewhere. The source explicitly
documents that Windows bypasses unit finalization whereas the Unix path runs
it. Therefore an ordinary Windows exit can conceal a finalization defect that
Linux exposes. The same Unix source branch covers macOS; the subsequent Mac
pilot now also reproduces the Preferences destruction failure.

The logger ordering also warrants review: some unit finalizers still log
after `tr4w_ShutDown` frees its logger reference. For example,
[uRadioHamLibDirect.pas](../tr4w/src/radioFactory/uRadioHamLibDirect.pas)
logs its finalization. Inspect the actual ownership and lifetime contracts in
[Log4D.pas](../tr4w/include/Log4D.pas) before changing logger destruction;
its hierarchy and appenders have their own shutdown/finalization behavior.
Do not attribute all later debugger faults to one logger call without tracing
that ownership.

Additional **audit candidates**, not confirmed crashes:

| Area | Source to inspect | Reason |
| --- | --- | --- |
| Application timers | [uAppTimers](../tr4w/src/ui/lcl/uAppTimers.pas) | Ownerless TTimers and their callback host are freed at finalization |
| Input handlers | [uAppInputHooks](../tr4w/src/ui/lcl/uAppInputHooks.pas) | Application handlers refer to a retained callback object |
| State subscriptions / queued callbacks | [uStateBridge](../tr4w/src/ui/lcl/uStateBridge.pas), [uMainForm](../tr4w/src/ui/lcl/uMainForm.pas) | Existing `FreeDeferralTarget` already cancels queued work and checks Application state; preserve and reuse that contract |
| TX-inhibit deferred work | [uTXInhibitView](../tr4w/src/ui/lcl/uTXInhibitView.pas) | Retained timer and callback objects are freed at finalization |
| Other retained windows | [uLogSearchForm](../tr4w/src/ui/lcl/uLogSearchForm.pas), [uSetupWizardForm](../tr4w/src/ui/lcl/uSetupWizardForm.pas), [uPostScoresForm](../tr4w/src/ui/lcl/uPostScoresForm.pas), [uPanadapterForm](../tr4w/src/ui/lcl/uPanadapterForm.pas) | Determine actual creation, ownership, close and destruction paths individually |

Component ownership and window stacking ownership are distinct. In
[uLCLFormHelpers.LeaveFormUnowned](../tr4w/src/ui/lcl/uLCLFormHelpers.pas),
the implementation sets `PopupParent` and `PopupMode`; it does not define the
component's destruction owner. A fix must preserve the intended modeless
window stacking, focus and reopen behavior.

## Proposed implementation boundaries

First agree on a suitable shared cleanup point that runs while the LCL and
required services are alive. Inspect existing teardown helpers before adding
another abstraction. Prefer a direct, small cleanup routine over a generic
lifecycle manager unless the audit demonstrates a need for one.

The intended ordering, refined by actual dependencies, is:

1. Stop/join relevant background producers and detach subscriptions so they
   cannot schedule more work against objects being destroyed.
2. Stop timers and cancel queued callbacks before freeing callback targets.
3. Destroy retained UI objects on the main thread while Application and their
   dependencies remain valid; clear cached references.
4. Release remaining services in dependency order. Keep valid logging available
   until all intended logging callers have finished; flush/close it last.

Each cleanup must tolerate an object never having been created and repeated
calls without double-freeing or accessing stale references. Existing explicit
service shutdown must not be duplicated in unit finalizers.

Avoid these apparent fixes:

- Catching and suppressing the destructor exception.
- Skipping form destruction whenever Application is nil and accepting a leak.
- Adding unrelated per-form shutdown conventions that will drift.
- Changing Windows from ExitProcess to Halt as an incidental portability edit.
  That exposes every finalizer and needs its own justified decision and tests.
- Conflating this with the separate absolute-Unix-path argument-parser defect
  documented in the pilot report.

## Suggested independent review tracks

The receiving agent may delegate these read-only tracks to sub-agents, then
reconcile the results into one proposal for Tom:

1. **UI lifetime:** verify the first fault against source and Lazarus teardown;
   inventory retained forms, timers and callback targets. Identify a safe hook
   and concrete affected objects, with ownership evidence for each.
2. **Services and logging:** trace `tr4w_ShutDown`, background producers,
   subscriptions and Log4D ownership. Separate independent defects from fallout
   after the first fault; recommend the smallest safe dependency order.
3. **Validation:** review the Linux harness/GDB evidence, propose meaningful
   regression coverage and platform checks, and identify anything that would
   invalidate the diagnosis or falsely produce a passing test.

Request a short written response that states agreement/disagreement, evidence,
affected files, proposed minimal changes, remaining uncertainties and tests.
Do not implement application changes until the coordinated plan is reviewed
with Tom.

## Acceptance criteria for the eventual fix

- Build from identified source; retain the exact executable and matching
  symbols. Do not reuse the old release's passing navigation evidence for a
  different build.
- On Linux, exercise exit with Preferences never opened, opened and hidden,
  reopened, and visible at the normal main-window exit. Include dirty
  Preferences and preserve the intended save/discard semantics.
- Exercise other retained windows actually implicated by the audit, including
  live timers or queued callbacks where relevant. Verify absence of callbacks
  after target destruction and cleanup on partially initialized paths.
- The pilot must return 0 with application exit 0. A GDB rerun must show no
  shutdown SIGSEGV; expected caught startup exceptions, such as the deliberate
  symbol probe, are not themselves acceptance failures.
- Preserve original contact data, expected settings/layout persistence and
  window behavior. Do not weaken the current assertions to obtain green.
- Validate the shared change on Windows and macOS too. Distinguish live results
  from source review and build-only checks. Windows still using ExitProcess
  does not prove that its finalizers are correct.

Current validation is 15 passing portable harness tests and the established
Linux navigation/accessibility observations. The application's shutdown test
still fails in the archived runs. This investigation has not applied or
certified an application fix; the receiving agent's current work and reported
approval are described in the concurrence section above.
