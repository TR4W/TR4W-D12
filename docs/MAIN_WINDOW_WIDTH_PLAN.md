# Main window: resizable in width (plan)

Status, 2026-11-21: **e0, e1, e2, e5 with e3 folded in, and e4 are
implemented** (`uMainLayout`, `MainUnit.LayOutMainWindow`,
`uMainForm.PlaceMainBands`, `tools/gen_main_elements.py`, `uTestMainLayout`).
e5+e3 is committed (41fe73a4); e4 is written and waits for NY4I's build.
**Next: e6.** Owner: `lcl-ui`. Also
touches `settings-config` (WINDOW SIZE), `i18n` (a retired setting's caption),
`gui-test` (one heuristic) and `build-release` (corpus gate wording).

**NY4I's answers to the open questions (2026-11-21), which settle them:**

1. **Yes**, the band map and Log Search text follow the main window's scale,
   **live** (option (i) WITH the notification, c1).
2. The minimum log is **3 rows** (b3). It is the window's MinHeight since e5:
   `MAIN_LOG_MINIMUM_ROWS = 3`, with the start layout `MAIN_LOG_START_ROWS =
   5` kept as a separate constant.
3. ws was **13..27**; WS_MAX raised to 43 on 2026-11-21 so a wide window scales up (revert if unwanted) (`uMainLayout.WS_MIN` / `WS_MAX`).
4. **Container bands (e5) come BEFORE scaling (e4).**

**So the order is: e0, e1, e2, then e5 (with e3 folded into it), e4, e6.**

**What e4 did (2026-11-21):**

- **The rule is `uMainLayout.ScaleForClient(clientWidth, layoutHeight,
  currentWs)`**, pure. `layoutHeight` is the client height less the status
  strip. It steps down at once to `width div 46` below `46 * ws`, steps up
  to `width div 46` once the width reaches `46 * (ws + 1) + WS_STEP_UP_SLACK`
  (8 px), clamps to 13..27, then lowers the result while
  `MinClientHeight(ws)` does not fit `layoutHeight`.
  - The slack decides when to step up, not how far. So `46 * n` set from a
    smaller scale lands on n, which b1's `(width - SLACK) div 46` would not.
- **The height cap replaces "grow the window" (b3).** MinHeight keeps the
  current scale's floor, so the cap only ever refuses a step up. The window
  never grows, and there is no work-area code.
- **The handler is `TTR4WMainForm.Resize` (override) -> `RescaleToClient`.**
  - It is inert until `ArmScaling`, which `MainUnit.RestoreToolWindows` calls
    last, after `ArmActivationRaiser`.
  - Arming lowers MinWidth to the layout at WS_MIN and judges the client
    once. That one judgement is the c2 fallback for a layout saved without a
    scale: the restored width decides.
  - A step runs `LayOutMainWindow(newWs)` inside
    `DisableAutoSizing`/`EnableAutoSizing`, then `SetMainWindowFloors` (the
    one place for the client-to-outer constraint arithmetic, shared with
    `MakeMainWindowResizeable`), then `ApplyStatusStripFont`. That routine
    now logs at Info only when its size changes. The step ends with the
    observers.
  - `FRescaling` guards re-entry. The Debug line is
    `[Layout] scale a -> b in n ms`.
- **Live followers: `uMainForm.AddMainScaleObserver` /
  `RemoveMainScaleObserver`** (a LazUtils `TMethodList`). Log Search
  subscribes in `FormCreate` and unsubscribes in `Destroy`. It re-applies
  the main font and `LogRowHeight(ws)`.
  - **The band map is not a follower.** Its text height is BAND MAP SIZE
    (`10 + Settings.BandMap.Size`), and only the face and weight come from
    the main window. Making it follow ws needs NY4I to say what BAND MAP
    SIZE then means.
- **The saved scale is `"scale"` in the `Main` entry** of the `windows`
  section (`TWindowLayoutEntry.Scale`, `SetScale`/`ScaleOf`, carried through
  `SaveWindowLayout`'s merge). `SaveTR4WPOSFILE` writes `ws`, and
  `LoadWindowLayoutFromJSON` sets `MainUnit.SavedMainWindowScale`.
  `MainWindowScale` prefers it, within 13..27, and falls back to WINDOW
  SIZE + 12. A drag never writes WINDOW SIZE.
- **Tests:**
  - `uTestMainLayout`:
    - `ScaleForClientAtItsBoundaries` (every scale's boundaries, the
      no-overflow invariant over every width, the cap);
    - `TheScaleFollowsTheWidth` (the shown form: unarmed resize, 17 -> 20,
      the slack, the step down, back to 17 exactly);
    - `AShortWindowCapsTheScale`.
  - `uTestWindowLayoutStore.Test_TheMainWindowScaleSurvivesASave`.

**What e5 + e3 did (2026-11-21):**

- **Three bands, generated.** `pnlTopBand` (alTop, 7 ws) holds the clocks,
  the totals grid, Total Score and Dupe Info. Inside it, `pnlNeedsBlock`
  (alRight, 14 ws) holds the need headers, Beam Heading and the need strips.
  `pnlBottomBand` (alBottom, 7 ws + 6, above `sbStatus`) holds everything below
  the log, including the five hand-written controls: both progress bars, the
  tour bar and readout, and the possible-call strip.
  - The strip is alBottom in that band with `BorderSpacing.Bottom = 6`.
  - The log and the B4 list are alClient.
  - `gen_main_elements.py` writes all three bands and their children in
    reading order (`lfm_taborder.row_order`). The `allow` entry for the main
    window in `lint-taborder.txt` is deleted.
- **Band-relative arithmetic.** `uMainLayout.ElementRect(e, ws)` and every
  bottom-band rectangle are in the band's coordinates; none takes a log
  height. `ElementBand` says which band an element is in, and `BandOrigin`
  turns a band rectangle back into window coordinates for the tests.
  `NeedLeft` and `LogRect` are deleted.
- **Gone:** `AnchorMainWindowControls`, `EditableLogHeight` (VC.pas; its
  only readers were MainUnit and the test), `TR4WEditableLogSetBounds`,
  `TR4WPreviousDupesSetBounds`, and `UpdateBaseBounds` on the strip
  (`SetPossibleCallBounds` became `SetPossibleCallSize`, height only).
- **`LayOutMainWindow(aWS)`** places the bands first (`PlaceMainBands`), then
  every child in its band. **CreateMainWindow's order is now size, then lay
  out, then report.** That is `MakeMainWindowResizeable(width, startHeight,
  minHeight)`, `LayOutMainWindow`, `ReportMainWindowLayout`. The reason: a form
  that is not shown does not align, and the bottom band is placed against the
  current client height.
- **The status strip stays the bottom.** Two alBottom siblings are ordered by
  their current bottom edges, so `PlaceMainBands` gives `sbStatus`, the bottom
  band, the top band and the needs block their whole rectangles inside
  `DisableAlign`/`EnableAlign`.
- **e3: the width is free.** `MakeMainWindowResizeable` releases the old
  constraints, then sets MinWidth to the layout width and no MaxWidth.
  `RestoreMainWindowBounds` restores the saved width, never below MinWidth.
  MinHeight is `MinClientHeight(ws)`: both bands plus `MinLogHeight`, which is
  header + 3 rows + an 8 px frame allowance.
- **The bands carry the drag-the-background handlers.** They now cover the
  form's background. The handlers convert through the Sender and capture on
  it.
- **The overhang and dump diagnostics walk every control**, each measured
  against its parent's client area.
- **Tests (uTestMainLayout):**
  - every rectangle is inside its band and lands where the e2 formula put it
    in the window, at ws 13..27;
  - the streamed form matches the `.lfm` (band-relative). Shown, it matches
    the e2 positions in the window at ws 17 and 13, and every element is in
    the band uMainLayout names;
  - taller, wider (+200), narrower than MinWidth, re-laid out at 13 and 27;
  - gridlines;
  - three whole log rows at MinHeight at ws 13, 17 and 27.
- **Behaviour changes.** The window can be dragged wider, and shorter: three
  log rows where the minimum was five. A saved width is restored where it was
  discarded. Nothing moves at the old size.

**What e0-e2 did:**

- **e0:** `MainWindowWidth` and `FKButtonWidth` are deleted. e2 made three
  more dead, and they are deleted too:
  - `RightTopWidth`: its one reader asks `uMainLayout.NeedLeft` now;
  - `MainWindowEditHeight`: its readers ask `uMainLayout.EntryFieldRect`;
  - `MainWindowPCLID`: its one use was an argument nothing read.

  The table in a1 below describes the code before these stages.
- **e1:** the gridline arm had already stopped resizing the log (d689fef9).
  `CheckEditableWindowHeight` repeated `CreateTR4WEditableLog`'s bounds and
  is deleted. The only writers of the log's bounds are now
  `CreateTR4WEditableLog` (once, at creation, so the columns are built at
  their real width) and `LayOutMainWindow`. The e1 test is
  `uTestMainLayout.Test_GridlinesLeaveATallLogAlone`. It grows the shown form,
  toggles gridlines through `DispalayLogGridLines`, and asserts that neither
  the log nor the call field moved. The log grid there has no rows, so it reads
  no contest log.
- **e2:** `MainUnit.LayOutMainWindow(aWS, aLogHeight)`; the arithmetic is in
  the leaf `uMainLayout`; tests are in `uTestMainLayout`.
  - **The log height is a parameter, not a policy.** `CreateMainWindow` passes
    the five-row minimum. e4 passes `ClientHeight - status -
    FixedBandsHeight(ws)`.
  - **`LayOutMainWindow` does not size the window or anchor.**
    `CreateMainWindow` still calls `MakeMainWindowResizeable` and
    `AnchorMainWindowControls` once, after it, so the startup log line is
    unchanged. Constraints per ws are e4's.
  - **`SetElementFont` now re-fits the caption**
    (`TElementPanel.SetFittedFontHeight`). Without that, a second layout left
    a caption at its unfitted full size.
  - **Risk d2:** read from `control.inc`, a `SetBounds` that moves a control
    re-captures its anchor base against the parent's current client size, so
    a re-layout at the current height should leave the anchors right.
    `uTestMainLayout.Test_BottomAnchorsHoldAfterARelayout` decides it on a
    shown form. NY4I has ordered e5 first anyway, which removes the question
    rather than answering it.
  - **Found by the new overlap test**, present in the arithmetic before e2,
    and pinned by name (BENCH_QUEUE):
    - the Rover panel covers the exchange field;
    - the totals "All" column runs 3 px under Total Score at ws 15, 19, 23
      and 27.

Line numbers are from `main` at `9938189d`. They drift, so search for the
identifier rather than trusting the number. **Facts** come from reading the
code. **Guesses** are marked as guesses, each with the measurement that would
settle it.

## 0. The goal, and where things stand today

NY4I wants the main window resizable in width as well as height. Today the
window corner shows a diagonal cursor, but only the height changes:

- `uMainForm.MakeMainWindowResizeable` (uMainForm.pas 1750) sets `ClientWidth`
  to the layout width and then pins
  `Constraints.MinWidth = Constraints.MaxWidth = Width` (1857-1859).
- The comment in `MainUnit.CreateMainWindow` (4990-5027) explains why: the
  layout is fixed columns scaled by `ws`, so a wider window would only add
  empty space.

`ws := Settings.MainWindow.WindowSize + 12` (`MainWindowScale`, MainUnit.pas
9512). WindowSize is `1..15` (`TMainWindowSize`, uSettingsModel.pas 382), so
`ws` runs 13..27 and the default is 17. The client width is `46 * ws`
(`MainWindowLayoutWidth`, 9517), which gives **598 px at WindowSize 1, 782 px
at the default, and 1242 px at 15**. Those figures match the screenshots
(about 600 and 1245 px).

**The recommended end state:** the window's client width decides `ws`. Dragging
the window wider makes everything larger in steps, and WINDOW SIZE stops being
a setting.

## (a) Everything that computes layout from ws

### a1. The scale globals (all written in `MainUnit.SetWindowSize`, 9522)

| global | value | declared | read by |
|---|---|---|---|
| `ws` | `WindowSize + 12` | VC.pas 3246 (`= 5` initial) | everything below |
| `ws2` | `ws div 4` | VC.pas 3247 | `logwind.DisplayAutoSendCharacterCount` only (logwind.pas 2267) |
| `RightTopWidth` | `14 * ws` | VC.pas 3260 | `uMainGrids.PositionMainGrids` (545) |
| `MainWindowChildsWidth` | `46 * ws` | VC.pas 3257 | CreateMainWindow 4700, 4866, 5048; CheckEditableWindowHeight 10726; PositionMainGrids 545 |
| `MainWindowWidth` | `ChildsWidth + 7` | VC.pas 3255 | **nothing** (one commented-out reference at 4674) -- dead |
| `MainWindowEditHeight` | `(3*ws) div 2 - 1` | VC.pas 3244 | CreateMainWindow 4833; CreateCallOrExchangeWin 8612/8619 |
| `FKButtonWidth` | `4*ws - 3` | VC.pas 3270 | **nothing** in src, `tr4w.lpr` or test -- dead |
| `EditableLogHeight` | measured back from the log grid | VC.pas 3258 | the y origin of every lower-band control |

`SetWindowSize` is called once, from `uProgramMain` 2843. WINDOW SIZE is
registered as **restart-required** (uSettingsDeclarations.pas 823, the `True`
argument). **Nothing in the program re-lays out the main window at run time
today.** That fact shapes the whole plan.

The hits for `ws` in `uWebSocketServer.pas` and `uRadioTCI.pas` are
WebSocket-related text, not the scale. TCI does not depend on the window.

### a2. `MainUnit.CreateMainWindow` (begins about 4660)

CreateMainWindow creates controls and positions them in the same pass:

- **Log grid:** 4699 `CreateTR4WEditableLog(0, ws*7, MainWindowChildsWidth, 30 + RowCount*(ws+2))`,
  then `EditableLogHeight := TR4WEditableLogBoundsHeight` (4703). The grid
  snaps itself to whole rows (uMainForm.pas 3591-3619).
- **The TWindows[] elements:** the loop at 4714-4754.
  - Bounds: `mweiX*ws, mweiY*ws + mweB*EditableLogHeight, round(mweiWidth*ws), mweiHeight*ws`.
  - Font: `ws - 2 + Settings.Font.Size` (4740).
  - Elements with `mweiStyle <= 2` are skipped. That is how the duplicate rows
    in the table (Call/Clock/Exchange, Name/Network, UserInfo/WholeScreen)
    avoid clashing.
- **Fonts on single elements:** `mweWSJTX` uses
  `Round((ws-2+Font.Size) * cells/chars)` (4770). `mweQSONumber` uses `ws + 3`
  (4802/4806).
- **Entry fields:** `CreateCallOrExchangeWin` at 4809 and 4832. It calls
  `CreateTR4WEntryField(ws*15, Top, 13*ws, MainWindowEditHeight, ..., ws+3)`
  (8611-8621). Each call **creates** a `TEdit`, so it cannot be re-run.
- **Progress bars:** `mpbLastHour` and `mpbRate` at `ws*28` and `ws*33`
  (4827-4830).
- **Minitour block:** 4841-4857, only when `MinitourDuration <> 0`.
  - `mweQuickCommand` at `(0, ELH + 12ws, 33ws, ws)`.
  - The tour text at `38ws`.
  - `mpbTourDuration` at `33ws`.
- **Possible-call strip:** `CreateTR4WPossibleCallList(0, ELH + 13ws, MainWindowChildsWidth, ws, ..., ws, 5*ws)`
  (4865). It sets `DefaultRowHeight` and `DefaultColWidth`, then calls
  `UpdateBaseBounds` (uMainForm.pas 3776). The call is there because the strip
  is designed and its streamed anchor base was stale. Font: `SetPossibleCallFont(ws-2+Font.Size)` (4868).
- **Window size:** `MakeMainWindowResizeable(MainWindowChildsWidth, 6 + EditableLogHeight + ws*14 + MainStatusBarHeight)`
  (5048), then `AnchorMainWindowControls` (5050).

### a3. After CreateMainWindow (`uProgramMain` 2897-2905)

- `BindMainGrids` and then `uMainGrids.PositionMainGrids` (uMainGrids.pas 506).
  - The totals grid uses `TotalsColumnGeometry(ws, ...)`: label column `5ws`,
    pitch `Round(ws*2.5)`, rows `ws`, header `2ws` (474-504).
  - The need strips start at `needLeft := MainWindowChildsWidth - RightTopWidth`,
    with cells `2ws` wide (543-577).
  - **`PositionMainGrids` runs AFTER `AnchorMainWindowControls` and sets no
    anchors.** `uMainForm.lfm` holds no `Anchors` lines (grep: none). So these
    67 panels keep the LCL default `[akLeft, akTop]`. On a wider window the
    need strips would **stay where they are**, even though the comment at 543
    says they "hang off the RIGHT".
- `ConfigureNeedRows` then calls `MatchNeedLabelFonts` (uMainGrids.pas 217,
  618). That routine measures text, so it depends on the cell width.

### a4. Other writers that depend on ws

- `logwind.DisplayAutoSendCharacterCount` (logwind.pas 2266): the arrow's left
  edge is `(AutoSendCharacterCount-1)*ws2*3 + ws*15`. It runs whenever the
  auto-send state changes. It is a position writer that lives outside the
  layout.
- `MainUnit.CheckEditableWindowHeight` (10697): it sets the log to
  `(0, ws*7, MainWindowChildsWidth, 30 + RowCount*(ws+2))`. It is called from
  `logwind.DispalayLogGridLines` (2954), and that is called at **run time** by
  `uSettingsEffects` (613) whenever **SHOW GRIDLINES** changes. See risk d1.
- Grid row heights:
  - `TR4WEditableLog.DefaultRowHeight := ws + 2` (uMainForm.pas 3408) and
    `TR4WPreviousDupes.DefaultRowHeight := ws + 2` (3314).
  - The log's font comes from `ApplyMainFontTo`, whose height is
    `MainFontCellHeight = ws + 2*Font.Size - 3` (MainUnit.pas 5198).
- **Tool windows that use the main-window scale:**
  - `uBandMapForm` 414 (`ApplyMainFontTo(grdSpots.Font)`).
  - `uLogSearchForm` 382-383 (font, plus `DefaultRowHeight := ws + 2`).
  - `uMainGrids` 279 (the totals and need cells).
- Log columns: in `lgsDeclared` mode `TLogGrid` sizes a column as
  `ColumnsArray[].Width * ws` (uLogGrid.pas 677, 935). **The main log is
  `lgsFitAndFill`** (uMainForm.pas 3051). It re-fits on every `DoOnResize`
  (uLogGrid.pas 1018), so it already absorbs any width it is given. A width
  the operator dragged is stored in **96-dpi pixels per contest**, not in ws
  units, so a dragged column does **not** rescale when ws changes. That is
  acceptable, and it is stated here so nobody "fixes" it by accident.
- Status strip:
  - `ApplyStatusStripFont(bar, width)` (uMainForm.pas 2063) runs from
    `Loaded` with `MainWindowLayoutWidth` (2177) and from
    `MakeMainWindowResizeable` (1867).
  - `LayOutStatusPanels` (2030) runs from `sbStatus.OnResize` (2180), so it
    already follows the width.
  - The font is fitted to the **narrowest panel** (2135-2137). A wider strip
    still fits, but a narrower one would need a refit.
- `TElementPanel.Resize` re-fits its caption whenever the panel resizes
  (uElementPanel.pas 239). A font change has to reset the panel's base font
  height, which `SetElementFont` does today. A re-layout must go through
  `SetElementFont` and not write `Font.Height` directly.

### a5. The design-time copy

- `tools/gen_main_elements.py` writes `uMainForm.lfm` at `WS = 17` (line 71).
- `EDITABLE_LOG_HEIGHT` (73), `STATUS_BAR_HEIGHT = 23` (98), `NEED_LEFT = (46-14)*WS`
  (200) and the totals arithmetic (218-232) are a Python copy of the Pascal
  formulas.
- `Lint-MainElements` checks the `.lfm` against what the generator would write.
  `Lint-FormOverlap` checks sibling overlap in the `.lfm`, which only ever
  shows ws = 17.
- **No test checks the run-time layout at any other ws.**

### a6. `TWindows[]` (VC.pas 1024-1088)

TWindows[] is a 46-column grid. Every row is `mweiX/mweiY/mweiWidth/mweiHeight`
in ws units plus `mweB` (0 = above the log, 1 = below it):

- **Top band:** rows 0-6.
  - Left half, columns 0-23: the clocks, then (in uMainGrids) the totals grid.
  - Columns 23-32: TotalScore and DupeInfoCall.
  - Columns 32-46: the need headers and BeamHeading, plus the need strips from
    uMainGrids.
- **Bottom band:** rows 7-12, columns 0-46. The entry fields sit at columns
  15-28. The elements at the right edge are 42-46 (Insert, S&P counter,
  Operator, FootSwitch) and 38-46 (CQ total).

## (b) Deriving ws from the width

### b1. The rule

```
step down, immediately:  if ClientWidth < 46*ws        then ws = ClientWidth div 46
step up, with a margin:  if ClientWidth >= 46*(ws+1) + SLACK then ws = (ClientWidth - SLACK) div 46
then clamp to WS_MIN..WS_MAX
```

**The rule never lets the layout be wider than the client.** A naive
`(ClientWidth + SLACK) div 46` would keep ws while the client is up to SLACK px
too narrow, clipping the right column. That is exactly the gtk2 defect that
`MakeMainWindowResizeable` fixed on 2026-09-09 (uMainForm.pas 1788-1812).

- `WS_MIN = 13` and `WS_MAX = 27` keep today's range, so no operator sees a
  size they could not choose before. Widening the range is a later, separate
  decision.
- **Integer steps, not continuous scaling.** Three reasons:
  - Every font is an integer pixel height derived from ws.
  - The totals pitch already rounds (`Round(ws*2.5)`). With a fractional ws,
    rounding would put adjacent cells one pixel apart or overlapping at some
    widths. That is the class of defect `Lint-FormOverlap` found ten of at the
    one size it can see.
  - The step is also the debounce: ws changes at most once every 46 px of
    drag.
- **`SLACK` (a few px, value to be measured) applies to stepping UP only.** It
  stops the size flickering when a dragged edge sits on a boundary. Stepping
  down has no slack, because it must not overflow.
- **gtk2 transient sizes are handled by WHEN the rule runs, not by slack.**
  The lcl-ui notes record that gtk2 reports transient client areas during
  OnShow (a 710x480 panel measured as 706x476). Because the client width is
  exactly `46*ws` at startup, any such transient would step ws down. So the
  resize handler is **armed only after the form is shown and settled**, for
  example from the end of `ShowTR4WMainForm` (or a QueueAsyncCall from it).
  Until then a resize does not change the scale.
- The rule lives in a **pure leaf function** with no LCL, for example
  `uMainLayout.ScaleForClientWidth(width, currentWs): integer`. It is unit
  tested the way `uBandMapOrder.EffectiveDisplayLimit` is: the boundaries,
  the clamps, the hysteresis, and a width of zero or less.

### b2. Leftover width (0-45 px, or more beyond WS_MAX)

- Controls that stretch take it: the log (`akRight` already, fit-and-fill
  columns), the possible-call strip (`akRight` already), and the status strip
  (`alBottom`).
- **The right-hand block of the top band** follows the right edge: the need
  headers, BeamHeading and the need strips (columns 32-46). That is what the
  `needLeft` comment always intended.
- **The bottom band stretches** (NY4I, 2026-11-21): every element's left and
  right edge is mapped by `StretchX(x, bandWidth, ws) = x * bandWidth div
  LayoutWidth(ws)`, so the lower grid meets the window edge. Identity at the
  layout width. The top band's left part stays left-aligned. WS_MAX is 43 now,
  so the scale itself rises with a wide window.
- **Rejected: snapping the window to `46*ws` on release.** It fights the
  window manager (tiling WMs, maximized windows, Cocoa's live resize), and the
  LCL has no portable "resize ended" event to hang it on. `WM_EXITSIZEMOVE` is
  Win32-only.

### b3. Height coupling

The fixed bands are `14*ws + 6` px plus the status strip. Going from ws 17 to
ws 27 adds 140 px. The policy:

- **The log absorbs height**, as it does today. After a ws step:
  `log height = ClientHeight - status - 14*ws - 6`.
- **`Constraints.MinHeight` is recomputed for each ws:** the fixed bands plus a
  minimum log of `MIN_LOG_ROWS` rows. Proposal: 3 rows plus the header. Treat
  that number as a guess until NY4I rules on it.
- **If a ws step would push the log below that minimum, grow the window's
  height** to MinHeight, but never past the monitor's work area. If even that
  is not enough, cap ws so it fits. The cap is a second input to the pure
  function: `ScaleForClient(width, height, currentWs)`.
- **Guess:** the LCL raises MinHeight smoothly during a live drag on Win32 and
  gtk2. That needs measuring. If it misbehaves mid-drag, apply the height half
  through `Application.QueueAsyncCall` after the resize event. That queue
  follows the agent rule: the target is freed and `RemoveAsyncCalls` runs.

### b4. Re-laying out live, without flicker

- `TTR4WMainForm.Resize` (or a handler on the form's OnResize) computes the
  new ws through the pure function. **If ws did not change, it does nothing.**
  The stretching controls and anchors already handle that case.
- If ws changed, it calls `LayOutMainWindow(ws)` (see e2) inside
  `DisableAutoSizing / EnableAutoSizing` (or
  `DisableAlign / EnableAlign`). The roughly 110 SetBounds calls and font
  changes then become one alignment pass.
- **Live or delayed:** live, at most once every 46 px of drag. **Guess:** the
  cost is about 130 bounds+font changes plus `FitCaption` measurement, which
  should take under 30 ms. Measure it with a `[Layout]` Debug line that times
  the pass. Only if it is visibly slow, coalesce through a single
  `QueueAsyncCall` (latest wins), not a TTimer. A timer adds a fixed delay to
  every step, and `uAppTimers` warns about timers started off the main thread.
- **A re-entrancy flag (`FLayingOut`) guards the handler.** `LayOutMainWindow`
  sets constraints and can grow `ClientHeight`, and both raise Resize again
  while the routine is partway through. "ws unchanged" alone is not a guard in
  that state.
- **Constraints are in `Width`/`Height` units, not client units.** Compute
  `MinWidth`/`MinHeight` as the client figure plus the measured
  `Width - ClientWidth` / `Height - ClientHeight` of the shown form. That is
  how the existing code does it: it reads `Width` back after sizing
  (uMainForm.pas 1857).
- `ApplyStatusStripFont` should run only when the strip's width class changes
  (from the same handler), and its Info log should drop to Debug or fire only
  when the result changes. Otherwise a drag fills `tr4w.log`.

## (c) WINDOW SIZE, saved bounds, migration

### c1. The setting

**Recommendation: retire WINDOW SIZE as a scale once e4 lands.** The width the
operator drags to is the scale, and two controls for one number would
disagree.

- `settings-config` work: the name goes into `RETIRED_COMMANDS`, so an old
  `.cfg` line or tr4w.json key is accepted and ignored. The Preferences row and
  its placement are removed. `CheckEveryInventoriedSettingHasOneEditor` and
  `uTestPrefsPlacement` must still pass.
- `i18n` work: `RS_APPEARANCE_LAYOUT_WINDOWSIZE` and the matching help entry
  become obsolete in the catalogues.
- **The honest reason to keep a remnant:** the band map grid
  (`uBandMapForm` 414) and Log Search (`uLogSearchForm` 382-383) take their
  font and row height from the main window's scale. Two options:
  - **(i) Follow the live main ws.** A tool window re-applies the font when it
    is next opened. A window that is already open is updated through a
    "main scale changed" notification, an observer list as in
    `uNetLink.NetLinkObservers`.
  - **(ii) Give tool windows their own text size,** decoupled from the main
    window.

  **Recommend (i) without the live notification at first.** Open windows pick
  up the new scale when next opened. That keeps today's coupling and adds
  nothing. **This is a question for NY4I**, because widening the main window
  would now enlarge the band map text the next time it opens.
- `Settings.Font.Size` stays. It is an offset added to ws, not a scale.
- `ROW COUNT` stays as the **initial** log height when no saved height exists.
  It is already only that (MainUnit.pas 10717-10724).

### c2. Saved bounds and migration

- The main window's rect is saved as the form's `BoundsRect` in the JSON
  window layout (`uWindowLayoutStore`, through `FindAndSaveRectOfAllWindows`).
- `RestoreMainWindowBounds` (uMainForm.pas 1484) **restores Left, Top and
  height but discards the width** (1510-1512).
- **What the saved width holds is UNVERIFIED.** Since 2026-09-09
  `MakeMainWindowResizeable` sets `ClientWidth := 46*ws`, and its comment
  (uMainForm.pas 1788-1812) says the outer `Width` differs from the client by
  the frame. So a saved `BoundsRect` width is probably `46*ws + frame`, not
  exactly `46*ws`. The bench figure at 3996-4008 (1012 = 46*22) predates that
  change, when `Width` itself was being assigned `46*ws`, so it shows what was
  written, not the client size.
- `(46*ws + frame) div 46` still gives the old ws while the frame is under
  46 px, so deriving the scale from the saved width probably works. But
  restoring that number as `Width` and re-deriving from `ClientWidth` is where
  a step can be lost. **So the derivation is the FALLBACK, not the contract.**
- `LoadTR4WPOSFILE` runs at uProgramMain 2471, before `SetWindowSize` (2843)
  and `CreateMainWindow` (2897). So anything saved is available when ws is
  first computed.
- **The contract (recommended, e4):** save **ws** itself (or the client width)
  as an explicit field of the main window's layout entry. At startup
  `MainWindowScale` reads it and the form sets `ClientWidth := 46*ws` (plus any
  saved leftover width), so nothing depends on how a platform reports its
  frame. A missing field falls back, in order, to the saved width div 46, then
  to the old WindowSize, then to 17. An operator upgrading therefore keeps
  their size through the fallback once, and the explicit field from then on.
- First run with no saved layout: start at the default ws 17, or at the old
  WindowSize if the operator still has one, read once during the transition
  release.

## (d) Risks

1. **`CheckEditableWindowHeight` resets the log at run time.** Toggling SHOW
   GRIDLINES (`uSettingsEffects` 613, then `DispalayLogGridLines`, then 10725)
   sets the log back to `30 + RowCount*(ws+2)` tall at the top-band origin.
   The bottom band stays anchored to the window's bottom edge.
   - **From reading the code, this is probably already a defect today:** after
     dragging the window taller, a gridline toggle should shrink the log and
     open a gap above the entry fields. **Not measured on a running program.**
   - Once width is free, the same call would also snap the log back to
     `46*ws` wide.
   - Fix it in e1: the gridline arm sets grid lines and does not touch bounds.
     The log's bounds have one owner, the layout.
2. **Anchors are captured measurements.** `AnchorMainWindowControls`
   (uMainForm.pas 1871) works only because sizing happens before anchoring
   (MainUnit.pas 5016-5027). `lstPossibleCall` needs `UpdateBaseBounds`
   because its streamed base was stale.
   - A re-layout that calls SetBounds on anchored controls while the parent
     resizes depends on the LCL re-capturing the base on every SetBounds.
   - **Guess:** `TControl.SetBounds` outside an align pass updates the base
     bounds. The lstPossibleCall incident shows a designed control can hold a
     stale base. See the container option in e5, which removes the question.
3. **Off-thread writers.** All the layout writers are main-thread. The resize
   handler is main-thread by construction. No new risk.
4. **Headless `/EXPORT` and `/RESCORE` run CreateMainWindow too.**
   `uProgramMain` 2897-2905 builds the main window and positions the grids
   before `/RESCORE` (2929), `/IMPORT` and `/EXPORT` (3007) `Halt`. **So the
   corpus is not irrelevant:**
   - It exercises the layout code on a form that is never shown.
   - Every layout routine must be safe with no handle and no shown form, and
     the resize handler must not assume the form is visible.
   - **The corpus exit code (not its diffs) is a gate for every stage.** An AV
     in the layout path would make all 13 exports exit non-zero.
   - The contest matrix does not care, beyond the same exit code.
5. **Fonts per element.** WSJTX, the QSO number, need-label matching,
   `TElementPanel.FitCaption` and the status strip each have their own sizing
   rule. Each one becomes a call inside `LayOutMainWindow`. Missing one leaves
   a single element at the old size, and nothing reports it. The geometry test
   (e3) should assert the font height of each family at two ws values.
6. **Linux gtk2:**
   - The transient client sizes (b1) need the hysteresis.
   - A substituted font (no Arial) is why captions are measured rather than
     computed. Re-measuring on every step is required, not optional.
   - On gtk2 the WM may deliver resize events asynchronously after
     `ClientWidth` is set, so the handler can run more than once for one
     change. Because it is idempotent and guarded by "ws changed", that is
     harmless.
7. **macOS Cocoa:** unrun. Live resize there delivers continuous events, and
   the same guard applies. Item for BENCH_QUEUE.
8. **Tool windows keyed off ws:** band map, Log Search, the previous-dupes
   grid. Decision (c1).
9. **GUI tests (`tools/gui_test`):**
   - `qso_entry.py:14` finds the log grid by `width() > 600 and 70 < height() < 250`.
     At ws 13 the log is 598 wide, and a dragged-taller log exceeds 250. That
     already fails for an operator at WindowSize 1. Change the heuristic to
     find the grid by class or name.
   - No visual baseline covers the main window. `ui-baselines` holds
     `logger-empty` and the `search-*` files.
   - The fixture `tr4w.json` sets no WindowSize and no layout, so it stays at
     ws 17 and the Log Search baselines do not move.
   - Add a GUI case that drags the right edge and reads back the element
     rectangles.
10. **The design-time copy:** `gen_main_elements.py` stays at WS = 17. The
    `.lfm` remains "the layout at the default scale", and that is honest as
    long as the Pascal formulas are the run-time source. The two copies of the
    totals and need geometry (Pascal and Python) remain, as today.
11. **`Lint-FormOverlap` sees only ws 17.** The run-time test in e3 is what
    covers 13..27.

## (e) Staged implementation

Each stage is a commit or a small group. **Every stage** passes:
`Build-App.ps1`, `Build-Tests.ps1 -Run`, `Build-Tests.ps1 -Checked -Run`,
`Lint-MainElements`, `Lint-FormOverlap`, `Lint-LFMLoad`, and **the corpus run
with every export exiting 0**. Screen judgments are added to `BENCH_QUEUE.md`
for Windows and Mint.

### e0. Delete the dead globals (trivial, behaviour-neutral)

`MainWindowWidth` and `FKButtonWidth` are written and never read. Delete both
(VC.pas 3255, 3270; MainUnit.pas 9574, 9577). Test: it compiles.

### e1. Give the log's bounds one owner (fixes d1)

- `DispalayLogGridLines` sets the grid lines only.
- `CheckEditableWindowHeight` runs once, at creation, or folds into the
  creation call.
- Test: a unit test streams and **shows** the form off screen, as
  `uTestPasswordRevealLayout` does. It grows ClientHeight, toggles
  `Settings.MainWindow.ShowGridlines`, and asserts the log's height and the
  call field's top did not move.
- Bench: drag taller, toggle gridlines (on Windows and Mint).
- **This stage ships on its own merit, whatever happens to the rest.**

### e2. Extract `LayOutMainWindow(aWS)` from `CreateMainWindow` (behaviour-neutral)

- Creation stays in CreateMainWindow. Positions, sizes and fonts move to one
  idempotent routine:
  - the globals `SetWindowSize` computes (parameterised by ws);
  - the log's bounds and `DefaultRowHeight` (main log and previous dupes);
  - the TWindows[] loop's `SetBounds` and `SetElementFont`;
  - WSJTX and the QSO number;
  - the entry fields (a new `SetEntryFieldBounds`, because
    CreateTR4WEntryField creates);
  - the progress bars and the minitour block;
  - the possible-call strip's bounds, row height, column width and font;
  - `PositionMainGrids` and `MatchNeedLabelFonts`;
  - `DisplayAutoSendCharacterCount`;
  - `ApplyStatusStripFont`;
  - the constraints.
- The pure arithmetic moves to a leaf unit `uMainLayout`, with no LCL:
  `ElementRect(e, ws, logHeight)`, `EntryFieldRect`, `TotalsColumnGeometry`
  (moved from uMainGrids), `NeedLeft(clientWidth, ws)`, `MinClientHeight(ws)`.
- Test 1: unit tests of `uMainLayout`. **No sibling overlap at every ws from
  13 to 27**, which closes d11. Every rect stays inside `46*ws`.
- Test 2: a "same bounds" pin. Show the form off screen at ws 17 and 13,
  record every child's BoundsRect, and compare with the values the current
  code produces. Capture them before the refactor, in the same commit, as the
  oracle.
- Startup must log the same `[Layout] main window: client ...` line as before.

### e3. Width becomes free; the right-hand block follows the right edge (no scaling yet)

**DONE 2026-11-21, folded into e5**, by bands rather than the anchors sketched
below: see the status header.

- `MakeMainWindowResizeable` stops pinning MaxWidth. MinWidth stays at the
  layout width.
- `RestoreMainWindowBounds` restores the saved width, clamped to at least
  MinWidth.
- The need headers, BeamHeading, the need labels and the need cells get
  `[akTop, akRight]`. That is set in `AnchorMainWindowControls`, after
  `PositionMainGrids` has placed them, so the "size first, then anchor" order
  holds. The call order in uProgramMain changes accordingly, or
  PositionMainGrids calls the anchor step itself.
- The log, the possible-call strip and the status strip already stretch.
- Test: off screen, at ClientWidth `46*ws + 200`:
  - the need cells' right edge equals ClientWidth minus the same margin;
  - the log's width grew by 200;
  - the entry fields did not move;
  - no overlap.
- Bench on Windows and Mint.
- **This is a usable stopping point.** The window can be widened for a wider
  log and possible-call strip, the text size is still WINDOW SIZE, and the
  only new empty space is in the middle of the top band and the right of the
  bottom band.

### e4. ws follows the width (the goal)

- `uMainLayout.ScaleForClient(width, height, currentWs)`, with clamps,
  hysteresis and the height cap. Unit tested exhaustively at the boundaries.
- `TTR4WMainForm` gets a resize handler. If ws changed, it calls
  `LayOutMainWindow` inside DisableAutoSizing and logs `[Layout] scale
  %d -> %d in %d ms` at Debug.
- The startup ws comes from an explicit saved ws field (c2). The restored
  width is only the fallback, for a layout saved by an older version.
- MinHeight is recomputed for each ws, and the window grows only up to the
  monitor's work area.
- Test, off screen: set ClientWidth to `46*20`, then process messages, then
  check:
  - `ws = 20`;
  - every element's rect equals `uMainLayout.ElementRect(e, 20, ...)`;
  - the fonts are at ws 20;
  - the log fills the remaining height;
  - growing to one pixel below `46*(ws+1) + SLACK` leaves ws unchanged;
  - shrinking to one pixel below `46*ws` steps ws down at once, and no child's
    right edge passes ClientWidth (the no-overflow invariant);
  - a resize before the form is armed (b1) does not change ws.

  Then shrink and assert that the layout returns.
- Bench: drag across several steps on Windows and Mint, and check for flicker
  and the time per step in the log.

### e5 (optional; decide before e4). Container bands instead of anchors

**DONE 2026-11-21, before e4 as NY4I ordered**: see the status header. Two
details are not in the sketch below. The band is 7 ws + 6 as sketched, and the
6 px sits under the possible-call strip as its `BorderSpacing.Bottom`. The
status strip's order is held by `PlaceMainBands`.

**The native-LCL shape:**

- `pnlTopBand` (`alTop`, height `7*ws`) holds the top-band elements and the
  grids.
- `pnlBottomBand` (`alBottom`, height `7*ws + 6`, above `sbStatus`) holds the
  lower band. Child tops become band-relative (`(mweiY-7)*ws`).
- The log is `alClient`.

**Gains:**

- Height resizing needs no code. `AnchorMainWindowControls`, the
  "size first, then anchor" rule and the `UpdateBaseBounds` call on
  lstPossibleCall all disappear.
- Risk d2 stops existing.
- The right-hand block can be its own `alRight` panel inside the top band.

**Costs:**

- `gen_main_elements.py` emits nested parents, and `Lint-MainElements`
  follows.
- `Lint-FormOverlap` becomes per-parent. It already is per-parent, so this
  mostly works for free.
- The z-order and UIA reading order change (the main window has no caption
  pairs, so the issue-278 rule is not at stake).
- `EditableLogHeight` disappears as a y origin, a cross-unit change.
- Tests that stream the form and look up children by parent are affected.

**Recommendation:** do e5 **before** e4 if e2 shows that anchored controls
need `UpdateBaseBounds` after a re-layout (risk d2 confirmed). Otherwise do it
after e4 as the "leave native" sweep the house rule asks for. Either way, do
not leave the anchor capture permanently: by the house rule, an anchor
captured from absolute coordinates is the non-native shape, and the band
layout is what replaces it.

### e6. Retire WINDOW SIZE (settings-config, i18n)

**Done 2026-11-21.** The first-run seed is `uMainLayout.WS_FIRST_RUN` (17, the old
default); a pre-e4 layout's saved width still decides its scale through
ArmScaling. The band map no longer reads the main scale at all (BAND MAP SIZE),
and Log Search reads the live `ws`, so c1's coupling question is moot for this step.

- Add it to RETIRED_COMMANDS and remove the Preferences row and placement.
- Mark the catalogue entries obsolete.
- Add a migration read of the old value for one release (c2).
- Make the decision on tool-window coupling (c1).
- Tests: `uTestPrefsPlacement` (no editor for the retired key) and the config
  defaults tests. `uTestConfigDefaults` references Settings.MainWindow
  (line 253), so check it.

### Where to stop

- **e1 is worth doing whatever is decided**, because it fixes a probable
  existing defect.
- **e3 is the recommended stopping point if scale-to-width proves too risky.**
  It is small and anchor-only, it lets operators widen the window, and the
  extra width goes to the controls that can use it.
- **e2 is the prerequisite for everything after e3,** and it pays for itself
  on its own: the layout becomes testable at every ws for the first time.
- **e4 delivers the goal.** Its specific risks are the gtk2 transient sizes and
  the cost of re-layout during a drag. Both are measurable in e2 and e3 before
  e4 commits to anything.

## Open questions for NY4I

1. Should the band map and Log Search text follow the main window's size (c1)?
2. The minimum number of log rows when the scale grows (b3). Proposed: 3.
3. Keep ws at 13..27, or allow larger on wide screens?
4. Container bands (e5) before or after e4?
