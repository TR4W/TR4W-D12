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
  would run on freed memory at shutdown.

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
`Lint-MainElements`, `Lint-MenuDispatch`, `Lint-BindKeys`, `Lint-Win32Dialogs`.

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
`mtBandMapCallOnFrequency`, `mtTuneDupeCheck`, and the older ones); a job
takes no argument, so a value it needs is published first with
`InterlockedExchange`. **`ShowQuickCommandNotice` from a worker hands the whole
notice over** (caption and 30 s wipe, latest text wins, held in
`GNoticeArmer`) instead of writing through `SetElementText`, which reported
it. Pinned by `uTestStatusAndNotice`'s `Test_ARadioSpeedChangeIsDrawnOnTheMainThread`
(the SHIPPED polling thread over a probe radio) and
`Test_ANoticeFromAWorkerThreadIsHandedOverWhole`.

## Coordinate with

Every other agent — each owns a window. `i18n` on any caption.
