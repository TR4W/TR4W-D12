---
name: lcl-ui
description: The user interface — LCL designed forms under src/ui/lcl, the main window, window management, display coordination, colours and theming, and the removal of Win32 UI artifacts. Use for any window, control, layout, keyboard or mouse handling, painting, or colour question.
tools: Read, Grep, Glob, Bash, Edit, Write
model: opus
---

You own what the operator sees.

## Your files

`tr4w/src/ui/lcl/` (the designed forms), plus `MainUnit.pas` (main window
creation, keyboard/mouse input, display coordination), `uWinManager.pas`,
`uDialogs.pas`, `tr4w/src/trdos/logwind.pas` (display routines), and `VC.pas`
(`TMainWindowElement`, `tr4wColors`).

**The UI is LCL Forms.** The program runs `Application.Run`; the hand-rolled
`GetMessage`/`TranslateMessage`/`DispatchMessage` loop is gone. **Every tool
window is a designed form.**

## THE RULE: IF YOU TOUCH IT, IT LEAVES NATIVE

NY4I, verbatim: *"if you touch a piece of code, validate if the code is doing
things as a native LCL app would do it. If not, change it to such. The way the
program did it before is immaterial and any references to handles require
immediate evaluation."*

**"It is not the LCL way" is a complete reason on its own.** It needs no second
justification — testability is *also* a reason, and citing it must never imply the
native-way argument was insufficient without it.

| if you find | write instead |
|---|---|
| an owner-draw handler | the control's own drawing + `OnPrepareCanvas` |
| a control holding empty items with the data in a global | the data IN the control — `Cells`, `Items`, `Caption` |
| a shadow counter beside a control | ask the control |
| a forced `Invalidate` after a data change | put the data in the control; it invalidates itself |
| `Objects[]` or a pointer carrying an identity | a typed field the view owns |
| a `Handle`, `HWND` or `SendMessage` | the property or method the LCL provides |
| a procedure variable passing a `TCanvas` between units | the event the control already raises |

**A handle is the loudest signal and gets evaluated on sight** — not left for a
sweep. Legitimate ones (a real Win32 boundary behind `{$IFDEF WINDOWS}`,
byte-exact serial I/O) keep the handle **and gain a comment saying why**.

### The worked example

`lstPossibleCall` held **N empty strings** with the callsigns in a global and the
paint handler in another unit. Every defect followed from the control holding no
data: it could not tell its content changed (forced `Invalidate`), its item count
could not be trusted (a shadow counter), every pixel was ours
(`DefaultDrawing := False`), and hiding it dropped its handle so the accessors
broke outright. It is a `TStringGrid` now — **none of those four failures can
recur** — and roughly fifty lines of canvas work in `MainUnit` are deleted.

## NEVER WRITE A COUNT OR A LIST OF SURVIVORS

This is a standing instruction from NY4I: *"stale info in CLAUDE.md wastes my
time."* A list of remaining Win32 dialogs was repeated as current fact and was
wrong the next day, four days running. **Ask the tree:**

```powershell
.\build\Lint-Win32Dialogs.ps1 -Group ui
.\build\Lint-Win32Dialogs.ps1 -Group platform
```

**And do not search `tr4w/src` alone** — `src/backup/` (IDE copies) and
`src/graphify-out/` (a cache) are gitignored snapshots days out of date. The lints
exclude both; a hand-run `grep` does not.

## Retiring a line

**Deleting is the default.** Where the old code genuinely helps diagnose the new,
comment it and mark it `//AGENT_DEPRECATED`. The lint counts **code only** (block
comments and string literals are stripped first), which is exactly why the marker
earns its keep: commenting out *live* code would lower the Win32 numbers, and a
ratchet that falls because work was HIDDEN looks identical to one that falls
because work was DONE. `Lint-AgentDeprecated` fails the build if a marked line is
not actually commented out, and lists every marked line so the pile gets swept.

## Two traps with no compiler diagnostic

- **A converted window loses its translations, silently** — every conversion up to
  2026-08-29 did. The `.lfm` carries a re-typed English caption while a translated
  `TC_`/`RC_` constant sits unreachable. `uServerLogForm` is the pattern: the
  `.lfm` text is an explicit placeholder and `HandleShow` assigns every caption
  from the constant. See `i18n` before typing a caption.
- **Position a form through `lclForm.BoundsRect`, never `SetWindowPos`** — the LCL
  holds its own bounds and pushes the designed ones back down when it shows, which
  silently undid a restored position.
- **A lazily created async-call target must be freed AND unqueued** (2026-10-22).
  `uMainForm`'s `GNoticeArmer` and `GDeferrer` were created on the first
  off-main-thread write and never freed -- two unfreed blocks the checked unit run
  caught. Its finalization now frees them through `FreeDeferralTarget`, which first
  calls `Application.RemoveAsyncCalls`: `TApplication.Destroy` drains the async
  queue AFTER unit finalization, so a call still queued against a freed object
  would run on freed memory at shutdown. **They are created in the unit's
  initialization since issue #132** (2026-11-04): created lazily, two worker
  threads arriving together could each make one and leak the other. A nil
  target now means "after finalization", and the callers return.

## A window that shows something per contest asks the contest

Since M9a (2026-10-02) the New Contest dialog, the totals window, the summary
sheet, the WRTC menus and windows and the QTC menu render DATA a contest class
gives them (`docs/ADDING_A_CONTEST.md`, "How a contest tells the display and
the reports"): `uNewContest` renders `DescribeNewContestPrompts`, `uTotal`
reads `TotalsDisplay`, the menus and `OpenTR4WWindow` ask
`PermittedOperatingAids` / `OffersQTCs`. **Do not put an `if Contest = ...`
back into a window** -- `Lint-ContestNameTests` holds each file's ceiling. What
only the UI knows stays here: which window IS which operating aid is
`MainUnit.OperatingAidOfWindow`, and how a prompt's steps become rows, a comment
and the "I am in" box is `uNewContest.RenderPrompt`.

**Since M9b (2026-10-02) the UI asks the contest for the rest** (design 8.2n):

- **The New Contest list is a `TListBox` under a search box** (Q103 and Q52,
  2026-10-19) listing `DisplayName`s, built by `uContestChoices` (no LCL,
  unit tested; `TContestChoices.Matching` is the search -- the caption,
  case-insensitive, anywhere). The list is **not `Sorted`** and must not be:
  `TfrmNewContest.FShown` holds the `TContestHandle` of each row, filled in
  the same pass as `Items`, and a sorted list would reorder `Items` behind
  it. A search that hides the chosen contest UN-chooses it. Inactive
  contests are HIDDEN unless "Show inactive contests" is ticked (Q59), and
  one listed that way cannot start a new contest: the rule is
  `uContestChoices.ContestCanStartNew`, applied in `SelectedContest`, so a
  highlighted inactive row reads as `NoContest` (a `TListBox` cannot
  disable one row). The list's
  width is measured from the widest name at run time. `SelectedContest` is the
  identity; `ContestName` is still the TOKEN (`ContestTypeSA`) -- it names
  the log file and the `CONTEST` command, so it must not become the caption.
- **CATEGORY-POWER is one value**: the Cabrillo summary window writes
  `Settings.Contest.CategoryPower` through `SetCFGCommandValue`, before the
  export runs and on close; a change with QSOs logged calls
  `MainUnit.RescoreLog` (the Rescore command, named once) and shows a
  NOTICE (`QuickDisplay`), never a modal question. The decision is
  `uCategoryPowerChange`, unit tested.
- **Call entry, band stepping, the log columns** ask
  `ShowsContestStatus`, `BandStepIncludesWARC`, `PowerFieldIsFOCNumber` and
  `CallEntryFrequencyWarning` (`MainUnit.ShowCallEntryFrequencyWarning`
  replaced `WagCheck`).

`BENCH_QUEUE.md` carries what to look at.

## Before converting another window

Read `docs/BANDMAP_LCL_DESIGN.md`, `docs/COLOR_ROLES_DESIGN.md` (**the palette
names COLOURS, not roles — that is what blocks theming; and the radio panel's cyan
IS its active-radio indicator, so removing it deletes a state signal**), and the
notes at the top of the `src/ui/lcl/` unit you are touching.

`docs/GRID_RESTYLE_PLAN.md` is **PARKED** until conversions finish.

## Lints

`Lint-DesignedForms`, `Lint-FormDefaults`, `Lint-FormEvents`, `Lint-FormFields`,
`Lint-FormOverlap`, `Lint-FormTags`, `Lint-LFMProperties`, `Lint-LFMLoad`,
`Lint-MainElements`, `Lint-MenuDispatch`, `Lint-BindKeys`, `Lint-Win32Dialogs`,
`Lint-TabOrder`.

**`Lint-TabOrder` (2026-11-02): Tab moves in reading order.** An `.lfm`'s
`TabOrder` is the order controls were CREATED, so moving one in the designer
leaves Tab jumping; every Preferences page shipped that way. The rule is rows
(tops within 8 px) top to bottom, left to right. A form that reads in columns
DECLARES them in `build/lint-taborder.txt` and stays judged; only the main
window is allow-listed (its focus is set by code). Fix a form with
`python tools/lfm_taborder.py fix --config tr4w/build/lint-taborder.txt <form>.lfm`.

`Lint-LFMProperties` compiles a real FPC helper that links the LCL and asks the
same RTTI the streaming loader uses — "does this class publish this property, and
is this a legal value" cannot be answered by grepping a `published` block.

**`Lint-LFMLoad` ACTUALLY STREAMS EVERY FORM**, through `ObjectTextToBinary` +
`TReader`, because asking the same RTTI is nearly the loader and is not it.
5.0.20 and 5.0.21 shipped a Preferences window that could not be opened at all —
`AnchorSideRight.Side = asrLeft`, and `asrLeft` is a CONSTANT in `controls.pp`
(`asrLeft = asrTop`), not a member of `TAnchorSideReference`. It reads naturally
in Pascal; an `.lfm` streams an enum BY NAME and there is no such name.
`Lint-LFMProperties` passed that commit because it value-checked only UNDOTTED
properties (fixed), and the layout was "verified" by rebuilding the button row
in code, which never opens the `.lfm`.

**VERIFYING A DESIGNED FORM BY BUILDING IT IN CODE PROVES NOTHING ABOUT THE
FORM.** Load the resource.

**GUI defects need a running program.** The corpus and the unit tests are blind to
the UI; measure the screen, not the source.

**The needs strips (`uMainGrids`) are written, never polled** (issue #100,
2026-10-26). Their cells hold the answer in `Caption` and colour; what decides
WHEN they are rewritten is the engine (`LOGEDIT.ShowNeedsForCall`, asked by
`LogContact` after a QSO). A stale strip is a missing call there, not a repaint
problem -- do not add an `Invalidate` or a timer. A test can drive them on the
streamed form: `uTestStatusAndNotice`'s `EnsureMainForm` + `BindMainGrids`.

**The PTT box has ONE colour rule and ONE caption rule** (issue #97,
2026-10-26). Colour: `MainUnit.PTTIndicatorBack`, from
`uTXInhibitAlert.PTTIndicatorRole` (idle / transmitting / inhibited), used by
the sweep. Caption: `uStateBridge.ApplyPTT`, from `RadioState` (`PTTOn`,
`TXInhibitAlert`). A caption change is what repaints the colour
(`ElementCaptionChanged` requests the sweep) -- do not add a second colour
write. The box is THREE cells wide, so an inhibited key-up says `INH`
(`STXInhibitedIndicator`) and the sentence `TX INHIBITED: <reason>` goes on the
keyed radio's status panel. `uTXInhibitView` owns when, on the main thread only
(the `mtTXInhibitAlert` job); it clears only a status text it posted, by asking
`CurrentStatusText`. On the default palette `AlertColor` (trAlert) is the same
red as radio one's TX, so the caption, not the colour, is the distinguishing
signal there. NY4I confirmed the `INH` display on his K4 (2026-10-26).
`uTXInhibitView`'s triggers sit inside `PTTOn` and `AddStringToBuffer`, so
they catch everything and never raise; the status sentence is built by
`TXInhibitedStatusText`, which falls back to the English if a (shipped, fuzzy)
translation of the format will not take the reason. A key-up TR4W started is
reviewed once, not once per character (`GKeyUpNoted`).

`uStateBridge`'s three `Apply*` exit when `TR4WMainForm` is nil (a queued
apply can outlive the form), and `GBridge` is freed through
`uMainForm.FreeDeferralTarget`, which is public now for that reason.

**No worker thread writes a control; the guard says so as an ERROR** (issue
#108, 2026-10-26). `uCrashLog.ReportOffMainThread` is the one off-thread
report -- `TElementPanel.Caption`, the element, status and entry-field
accessors all call it -- and it logs at **Error** (deduped per call site and
thread; never raises). `OffMainThreadReportCount` counts every call, for
tests: run the worker path, assert the count did not move.
`ElementOffThreadReport` is wired in `uMainForm`'s **initialization**, not in
`CreateTR4WMainForm` -- wired there it was blind in every test that streams
the form itself, and the #108 test passed against the defect until it moved.
A worker that changes state the UI shows publishes the state and requests a
`uMainThreadWork` job (`mtCodeSpeedDisplay`, `mtCWByCATMessageEnded`,
`mtBandMapCallOnFrequency`, `mtTuneDupeCheck`, the keying threads'
`mtCWMessageEnded` / `mtCWAutoCallTerminate` / `mtWinKeyerSendEnded` /
`mtDVPMessageEnded` from issue #132, and the older ones); **`uAppTimers`
reports a timer started or stopped off the main thread** too (#132: a TTimer
enabled from a thread is that thread's `SetTimer` on Windows and never fires
there). A job
takes no argument, so a value it needs is published first with
`InterlockedExchange`. **`ShowQuickCommandNotice` from a worker hands the whole
notice over** (caption and 30 s wipe, latest text wins, held in
`GNoticeArmer`) instead of writing through `SetElementText`, which reported
it. Pinned by `uTestStatusAndNotice`'s `Test_ARadioSpeedChangeIsDrawnOnTheMainThread`
(the SHIPPED polling thread over a probe radio) and
`Test_ANoticeFromAWorkerThreadIsHandedOverWhole`.

## Linux findings from issue #141 (2026-10-27)

- **FindFirst masks are case-sensitive off Windows.** `uNewContestForm.PopulateFiles`
  asked for `'*.CFG'`, so a lower-case `old.cfg` was never listed on Linux and the
  .cfg migration path was invisible there; it crashed the whole Linux suite (a grid
  index past the rows). It scans `*` once and judges the lower-cased extension.
  Never put an extension in a FindFirst mask.
- **THE STATUS STRIP HAS ITS OWN FITTED FONT (issue #142).** It used to paint in the
  system UI font while each of its 4 panels is a quarter of `ws * 46`, a scale that
  ignores the font: on the gtk2 runner (DejaVu Sans 14 px) "** DISCONNECTED from DX
  Cluster" was 246 px against 187 px of room, and nine `StatusAndNotice` checks
  failed. NY4I chose the font, not the panels or the wording (2026-11-01):
  `uMainForm.ApplyStatusStripFont` sets the window's face (`Settings.Font.Face`),
  regular, starting at 9 pt (today's Windows size, never larger), and steps down a
  pixel at a time until the widest connection status of either subsystem fits the
  narrowest panel. It runs when the form streams (`Loaded`, with
  `MainUnit.MainWindowLayoutWidth`) and in `MakeMainWindowResizeable`, and logs
  `[Layout] status strip font: ...`. A `TStatusPanel` has no font of its own, so the
  strip's font is the only native lever; reshuffling panel widths cannot work
  (the four panels need more than the strip has). The test is unchanged and the
  Linux pins are gone. Do not "fix" the test.
- `TStringList.Sort` is locale collation on Linux and ordinal on Windows; a test that
  pins an order uses `CustomSort` with `CompareStr`. `TStringList.Text` joins with
  `LineEnding`, not `#13#10`.

## A window that is a VIEW of something longer-lived (2026-10-27)

The Network window is the worked example. The multi-op link belongs to the
program (`uNet`, owned by the `multi-op-network` agent); the window used to
connect on show, drop on close and run the retry timer, so closing a window
decided whether stations could talk. Now it connects nothing and stops nothing:

- It **subscribes** (`uNetLink.NetLinkObservers.Add`) in `HandleCreate` and
  **unsubscribes in its destructor**, which also clears its global only if the
  global is `Self`. The model never holds a form; a window created and destroyed
  while the model lives is safe. Copy this for the next view of a long-lived
  object (radio panel, cluster) rather than a global the model writes into.
- It **asks for state when shown** (`RefreshFromLink` from `HandleShow`): a view
  opened mid-session saw none of the messages that built the state, so relying
  on the next message draws it half empty. Put the model's redraw behind a
  function the view can call (`uNet.DisplayAllClients`).
- It never has its Caption written from a worker thread. Status that arrives off
  the main thread is kept by the model, and the view reads it on notification.
- Test it by creating the real form (`TfrmNetwork.Create(nil)`), loading the
  model, calling the refresh and reading `lvClients.Items`; and by counting the
  observers before and after `Free`.
- The Net menu rows are enabled by the model's state (`ApplyNetworkMenuState`),
  not by the window. The top-level popup is never greyed, because it holds the
  way to get started.

## Window z-order: who owns whom (2026-11-01)

- The main form is `ShowInTaskBar = stAlways`, so on Windows it is UNOWNED.
  Every tool window (`LeaveFormUnowned`, issue #1) still has the LCL's hidden
  `AppHandle` as its Win32 owner (stDefault, `MainFormOnTaskBar` False), and
  Windows raises the tool windows as ONE GROUP when any of them is clicked.
  The main window is outside that group, which left it behind them on a
  switch back from another program (NY4I, bench).
- The fix is `uMainForm.TActivationRaiser`: `Application.OnActivate` (once per
  switch INTO TR4W) queues `BringToFront` on every showing tool window, bottom
  first in `Screen.CustomFormsZOrdered`, then the main window last. It skips
  while a modal is up, and `IsActivationEcho` stops it re-arming itself on
  gtk2, which derives app activation from per-window focus. **Armed by
  `ArmActivationRaiser` at the END of `MainUnit.RestoreToolWindows`**, stamped
  as a raise (issue #219): armed before the queued restore, a start-up
  activation -- which the LCL delivers through `QueueAsyncCall` -- raised every
  window a second time. `RaiseFromQueue` logs at Debug what it raised, or which
  guard declined. Do not "fix" this by owning tool windows by the main form
  again -- that is issue #1.
- **The restore opens windows with `OpenTR4WWindow(i, False)`**: no focus
  hand-back per window, one `FocusEntry` at the end (#219). Showing a form
  still activates it on Win32 -- the LCL has no show-without-activating for a
  form (`TWin32WSCustomForm.ShowHide` is `SW_SHOWNORMAL`), and
  `ShowWithoutTakingFocus` is `Show` plus a `BringToFront` back, two
  activations, not zero.

**Mnemonics were tried and dropped by NY4I 2026-11-03**: accelerators are
ShortCut keystrokes only (`uAccelerators`, `TMenuItem.ShortCut`). A caption put
where `&` is not markup (a window title from a menu row) goes through
`uCaptionText.DisplayedText`.

## File > Open Log is a restart, not an in-place switch (issue 218 S0, 2026-11-05)

`MainUnit.OpenAnotherLog` refuses while either radio is keyed or CW is being
sent (`uOpenLogRelaunch.OpenLogRefusal`; asked before the dialog AND after it),
then shows **the startup New Contest dialog** (issue 228):
`uNewContest.RunNewContestDialog(ncmSwitchContest, ...)` -- the same form, a
mode that only retitles it, and a runner that writes NO global (only
`ShowNewContest`, the startup wrapper, writes `TR4W_CFG_FILENAME` or the `'_'`
cancel sentinel; the running contest's writers read that name). Last Contest is
hidden when it names the open contest -- it is recorded once, at startup, so
mid-session it always does. `uOpenLogRelaunch.PlanOpenLog` decides: Cancel
nothing, the open contest "already open", a `.db` or a text `.cfg` relaunch,
anything startup would halt on refused before closing. **A New Contest is not
created in the running process** (that would build it with the open contest's
state): its queued choices are written to a hand-off file
(`uNewContestCommands.SaveNewContestChoices`, in `WritableSettingsDir`), the
child gets `--new-contest-from=<file>` and `uProgramMain.NewContestHandOffFailed`
loads it into the queue startup applies, deleting the file; an unreadable one
shows New Contest instead. Then a one-shot `RequestRelaunch` and
`ExitProgram(False)`. `tr4w_ShutDown` starts the child in
`StartRequestedRelaunch`, AFTER `LogStoreClose` and BEFORE the logger is freed.
The child carries `--wait-for-instance=<pid>` (one argument, so
`FirstNonSwitchArgument` never takes the pid for the contest) and
`uProgramMain.WaitForRelaunchingInstance` retries the mutex for 10 s, closing
its own handle before each retry. **Do not "simplify" this into reopening the
contest in place**: the survey on issue 218 lists the state that leaks; that is
S1-S6, and needs NY4I's go-ahead.

## Run-time children: anchors and a form that was never shown (issue 231, 2026-11-06)

**A child created at run time and anchored `akRight` inside a panel that was created at
its default width and THEN aligned (`Align := alTop`) moves by the whole difference**:
the External logger editor's rows were built in 170-wide panels stretched to 670, so the
key's eye sat 500 px over its box and the Logbook drop-down's arrow and Refresh button
left the row. Anchor run-time children left/top only when the dialog does not resize, or
anchor them to a sibling's side (`AnchorSideLeft.Control`), which does not depend on when
the parent changes size. `uPasswordReveal` anchors the eye to its EDIT for that reason.

**A test that streams a form and never shows it cannot see geometry.** Position, anchors
and alignment are applied when the form is shown. `uTestPasswordRevealLayout` shows the
form off screen (as `uTestNewContestForm` does), calls `Application.ProcessMessages` and
measures; copy it for any run-time layout. Row constants such as the editor's
`EDIT_LEFT` / `ROW_HEIGHT` are 96-dpi pixels, not scaled (`Scale96ToForm` is the LCL's
answer); unmeasured at 150%.

## A dragged column width is kept per user -- the main log per contest (issue 234, 2026-11-06)

The `columns` section of `settings\tr4w.json` (`uColumnWidthStore`): grid name -> column
token -> width at 96 dpi. **A token is never an index or a caption** --
`ColumnCanonicalName` for a log column, a fixed constant per column elsewhere
(`LOGGER_COLUMN_TOKENS`, `COLORS_COLUMN_TOKENS`); `''` means "not kept".

- **THE MAIN LOG IS PER CONTEST, NOT PER USER** (NY4I: its column set depends on the
  contest). `TR4WEditableLog.WidthsPerContest := True` makes `TLogGrid` read and write
  `uColumnWidthStore.ContestColumnWidths` (grid `CONTEST_LOG_COLUMNS_NAME`) instead of
  `LayoutName` / the pending marks; it is asked at every sizing, not cached. `uLogStore`
  fills it from the contest database's `COLUMN WIDTH <token>` rows at the open (through
  `uCFG.CheckCommand`'s arm, routed BEFORE the replay's renderable guard, which had
  refused every such row as "an action"), writes it back in the close capture
  (`CaptureContestColumnWidths`) and empties it at `LogStoreClose`. Same clamp, same 96
  dpi, same tokens -- only the backing store differs. **No other grid sets it**, and the
  main log never touches the `columns` section. `ColumnWidthOverride` is gone.
- **`TLogGrid` keeps its own.** Set `LayoutName` and the grid does the rest: it
  overrides the protected `HeaderSized` (drag AND divider double-click), holds a
  per-instance width list, reads the saved widths lazily at the first sizing with a
  handle, and floors a user width at its header text on every sizing pass. Do not wire
  `OnHeaderSized` to save a width again.
  **A fit-and-fill log grid always fills its `ClientWidth`, whatever the overrides**
  (2026-11-06): free columns share the surplus; when every column has a chosen width
  the LAST one takes it, its width a floor; a drag re-fits at once. Nothing is
  subtracted from `ClientWidth` (a cell includes its grid line; the bar is permanent).
  Pinned by `uTestColumnWidthStore`'s `LogGridFill` tests.
- **Any other `TCustomDrawGrid`**: `uLCLFormHelpers.RestoreGridColumnWidths` after the
  grid's own sizing (and after its captions, which the clamp measures),
  `SaveGridColumnWidth` from `OnHeaderSized`. A fill column (`AutoFillColumns`) and a
  zero-width hidden column get no token.
- **A save MARKS; `FlushColumnWidths` WRITES** -- in the window's close handler, and in
  `SaveTR4WPOSFILE` (exit and the 5-second autosave, whose tick also fires on
  `ColumnWidthsPending`). A restore reads the file overlaid by the unwritten marks.
- **A test flushes only into a file it has redirected and checked.** Drive
  `ApplyGridColumnWidths` / `CaptureGridColumnWidth` against your own store, or read
  `PendingColumnWidths`, and clear the marks behind you (a later close would write them).
  To test the flush itself, point `TR4W_INI_FILENAME` at a temp folder, ASSERT
  `TR4WConfigFileName` landed there (a `--settings` switch wins over the redirect), then
  flush -- `uTestColumnWidthStore.Test_Flush_AMarkReachesTheFileAndAFreshGridReadsIt`.

## Coordinate with

Every other agent — each owns a window. `i18n` on any caption.
