# The band map: what it does today, and the LCL form that should replace it

**Status: DESIGN, not yet implemented.** Written 2026-08-22, before any band map
source was touched, because "port the Win32 form" is the wrong framing here. The
band map is the one high-volume, externally-fed, continuously-repainting window
in the program, and three of its worst behaviours are consequences of *how it
repaints*, not of Win32. Porting the shape as-is would carry all three across.

Everything in the first half was read out of the source, not inferred. File and
line references are to the tree at the time of writing.

---

## 1. The data path as it exists

```
  cluster node
      |  TCP
  TDXClusterReader.Execute                 uDXClusterClient.pas:168   READER THREAD
      |  OnLine(complete line, 8-bit)
  TClusterEvents.Line                      uTelnet.pas:~1160          READER THREAD
      |  PostMessage(WM_TELNET_MSG, TELNET_DATA, chunk)
  ==================== thread boundary, correctly placed ====================
  ProcessTelnetLine                        uTelnet.pas:1738           UI THREAD
      |
      +-- ProcessDX                        uTelnet.pas:1807
      |      +-- uDXSpotParse.ParseDXSpot  (pure, unit-tested: freq, call,
      |      |                              source, notes, QSX)
      |      +-- VisibleLog.DetermineIfNewMult / dupe check
      |      +-- SpotsList.AddSpot(TempSpot, True)   uSpots.pas:129
      |
      +-- AddStringToTelnetConsole
      +-- BandMapNeedsRefresh := True                uTelnet.pas:1769

  SetTimer(tr4whandle, BANDMAP_REFRESH_TIMER_HANDLE, 250, ...)   tr4w.dpr:1061
      |
  BandMapRefreshTimerProc                  MainUnit.pas:2306
      +-- DisplayBandMap                   LOGWIND.PAS:3491
             +-- SpotsList.Display         uSpots.pas:242
```

**The thread SAFETY is right; the thread MARSHALLING is not what we would build.**
Correcting what this section said when first written ("the threading is already
right and must not change"). The safety claim is true and narrow: the reader
thread does nothing but package a complete line and hand it over, and every
mutation of the spot list, the log and the UI happens on the main thread. There
is no race and no cross-thread UI touch.

But `PostMessage(WM_USER + 250)` to a dialog's `HWND` is not how you would deliver
a line to the main thread if you were starting today, and it is not what the LCL
end state allows -- no HWND, no `WM_*`. **See [section 6](#6-the-ingest-marshalling----separate-work-already-largely-analysed).**
It is separate work from the form, and it is correctly sequenced *after* the
`Application.Run` pivot that the band map itself gates -- so the band map form is
built against the marshalling as it stands, and the marshalling is replaced next.

**The coalescing is also already right in principle.** A boolean is raised by the
ingest path and a 250 ms timer converts a burst into one repaint. Three units
raise it: `uTelnet.pas:1769` (a cluster spot), `uRadioPolling.pas:960` and `:1001`
(a VFO move).

Other things that repaint, all going straight to `DisplayBandMap` with no
coalescing: a logged QSO (`LOGSUBS2.PAS:1710`), a log edit (`LOGEDIT.PAS`), the
once-a-minute age decay (`LOGWIND.PAS:2013`), band and filter changes, `WM_SIZE`,
and losing focus (`uBandmap.pas:786`).

## 2. What `Display` actually costs

`uSpots.TDXSpotsList.Display` is the whole render, and it rebuilds everything:

1. `UpdateSpotsMultiplierStatus` -- **`VisibleLog.DetermineIfNewMult` for every
   spot in the list**, a log lookup per spot, on every repaint (uSpots.pas:582).
2. A filter pass over all `FCount` spots into `FiltSpotIndex`.
3. Centring arithmetic to pick a `BandMapDisplayLimit`-wide window (default 164).
4. `WM_SETREDRAW` off, `LB_RESETCONTENT`, `LB_INITSTORAGE`, then **one
   `LB_ADDSTRING` per row**, `LB_SETCURSEL`, `WM_SETREDRAW` on.
5. `ValidateRect` + `RedrawWindow(RDW_INVALIDATE or RDW_NOERASE or RDW_UPDATENOW)`
   -- an explicit dance to suppress the erase that step 4 just queued.

On top of which `WM_INITDIALOG` sets `WS_EX_COMPOSITED` on the dialog
(uBandmap.pas:400) so Windows back-buffers the children.

**Steps 4, 5 and `WS_EX_COMPOSITED` are three separate flash mitigations layered
on one root cause: the list is torn down and rebuilt on every update.** They are
not the design; they are scar tissue. The LCL form should not carry any of them,
because it should not rebuild.

Volume, honestly: a busy cluster is a handful of spots a second before filtering,
and the display is capped at 164 rows. The flashing is not caused by the rate. It
is caused by destroying and recreating 164 items to show that one changed.

## 3. Six defects the current shape produces

These are the reasons this is a redesign and not a port. Each was read out of the
code, and each survives a mechanical port.

**3.1 -- Spots arriving while the band map has focus are LOST, not deferred.**
`LBN_SETFOCUS` sets `BandMapPreventRefresh := True` (uBandmap.pas:449). The first
thing `AddSpot` does is `if BandMapPreventRefresh then exit` (uSpots.pas:141) --
before `InsertSpot`. The spot never enters `FList`. `KillFocus` calls
`SendAndClearBuffer`, which is meant to replay them, but **`BCount` is never
incremented anywhere**: `InsertSpotBuffer` is declared (uSpots.pas:73) and defined
(uSpots.pas:711) and *never called*, so `BList`, `BCount`, `BCapacity`,
`GrowBuffer` and `SetCapacityBuffer` are an unfinished feature and
`SendAndClearBuffer` is a no-op. Click into the band map to read a comment and
every spot that arrives while you are looking is gone for good.

**3.2 -- The row payload is an index into a shifting array.** `Display` stores
`FiltSpotIndex[k]` as the list box item data, and `WM_DRAWITEM` reads it back and
calls `SpotsList.Get(itemData)` (uBandmap.pas:239). `InsertSpot` `Move`s the array
to make room, so any insert between a `Display` and the next paint renumbers every
item above it -- and the row repaints as a different spot. It is self-limiting
today only because 3.1 blocks inserts while the window has focus.

**3.3 -- QSX is parsed properly and then thrown away.** `uDXSpotParse` has a real
tokenizer for the split grammar (`QSX`, `UP`, `DOWN`, `LSN`, `SPLIT`, MHz units,
"NOT SPLIT" refused) with its own unit tests, and it fills `FQSXFrequency`. The
display shows this as the single letter `S` in a 17-pixel box -- and then
**`if Spot.FDupe` overwrites it with `D`** (uBandmap.pas:312 then :316). One glyph
carries mult, split and dupe, so only the last one wins. The QSX *frequency* is
never shown anywhere; it is used only when you double-click to tune.

**3.4 -- The comment is only visible in the state that freezes updates.**
`FNotes` reaches the operator through `ShowSpotInfo` -> status bar panel 4, and
`ShowSpotInfo` runs on `LBN_SETFOCUS` / `LBN_SELCHANGE`. So reading a comment
requires focusing the list, which is exactly the state that drops arriving spots.

**3.5 -- Multiplier status is recomputed on the paint path.** See section 2 step
1. Whether a spot is a new multiplier changes when the *log* changes, not when the
screen repaints. Doing it per repaint is O(spots x log) at 4 Hz for an answer that
changed at most once since the last QSO.

**3.6 -- `sleep(BMDelay)` runs on the UI thread** (uTelnet.pas:1760), inside the
message handler, once per accepted spot. `BMDelay` is `= 0` (LOGWIND.PAS:629) and
has no CFG row, so it is inert today -- but it is a message-pump sleep sitting in
the ingest path waiting for someone to give it a value.

Dead weight to remove while here: `NEWBMLBPROC` / `OLDBMLBPROC` -- a list box
subclass that is declared and defined and never installed.

---

## 4. The replacement

### 4.1 One decision first: a virtual grid, not a list box

**`TDrawGrid` with `RowCount` driven by the model and `OnDrawCell` for painting.**

The alternative considered was `TListView` with `OwnerData := True` and
`OnCustomDrawSubItem`. Rejected: the band map's painting is not decoration, it is
data -- a gradient fill behind the frequency cell coloured by band, a second
gradient behind the flag cell, and a callsign colour ramped by age. Custom-drawing
a `TListView` subitem to get a gradient means fighting the control for the cell
rectangle on every row. `TDrawGrid` hands you the rectangle and gets out of the
way, and the codebase already uses grids (the Preferences colours page).

What the grid buys, against the five-step rebuild in section 2:

| today | with `TDrawGrid` |
|---|---|
| `LB_RESETCONTENT` + N x `LB_ADDSTRING` | `RowCount := n` |
| `WM_SETREDRAW` off/on | nothing |
| `ValidateRect` + `RedrawWindow(RDW_NOERASE)` | nothing |
| `WS_EX_COMPOSITED` on the dialog | `DoubleBuffered := True` |
| `WM_MEASUREITEM` | `DefaultRowHeight` |
| paint cost O(all 164 rows) | O(rows actually on screen) |
| repaint one aged row = rebuild all | `InvalidateRow(i)` |
| hand-computed `TRect`s, `GetTextExtentPoint32('28888.8')` | `ColWidths[]`, operator-resizable |

Nothing in the painting *rules* changes. The band colour, the red current-spot
marker, the mult and dupe fills and the five-step age ramp move across verbatim;
they stop being arithmetic on a shared `temprect` and become a `case aCol of`.

### 4.2 A snapshot, so paint never reads the live list

The form owns `FRows: array of TSpotRecord` -- **value copies**, taken once per
coalesced tick under `TDXSpotsList`'s existing critical section. `OnDrawCell`
reads `FRows[aRow - 1]` and nothing else.

This is what closes 3.2. The paint path cannot see a renumbered array because it
is not looking at the array. It also means painting takes no lock. 164 records at
roughly 90 bytes is about 15 KB, refreshed at most four times a second.

The filter and centring logic (section 2 steps 2 and 3) moves out of
`uSpots.Display` and into the snapshot builder. `TDXSpotsList` stops knowing that
a list box exists: `Display`, `SetTextInBMSB` from `uSpots.pas:481`, and the
`BandMapListBox` references in `SetCursor` all go. That is the right boundary --
the spot list is also the network and `bandmap.bin` model, and it should not be
reaching into a control.

### 4.3 A revision counter, not a boolean

`BandMapNeedsRefresh` is a global raised by three units and cleared by a fourth.
Replace it with `TDXSpotsList.Revision: cardinal`, bumped by every mutator
(`AddSpot`, `Delete`, `Clear`, `DecrementSpotsTimes`, `UpdateSpotsDupeStatus`,
`ResetSpots*`). A `TTimer` on the form, 250 ms, does:

```
   if SpotsList.Revision = FPaintedRevision then Exit;
   FPaintedRevision := SpotsList.Revision;
   RebuildSnapshot;
   Invalidate;
```

Cannot be missed, cannot be double-cleared, and a tick with nothing to do costs
one comparison. The `SetTimer` in `tr4w.dpr:1061` and
`MainUnit.BandMapRefreshTimerProc` are then deleted -- the form owns its own
refresh, which is the point of the LCL move.

Callers that today call `DisplayBandMap` directly (a logged QSO, a log edit, the
decay tick, a band change) should instead bump the revision, so **every** path
gets the coalescing and not just the two that remember to ask for it.
`DisplayBandMap` survives as a thin "bump and let the timer run" for the existing
call sites, so this is not a fourteen-site edit.

### 4.4 Focus freezes the VIEW, never the MODEL

Delete `BandMapPreventRefresh` from `AddSpot` and from `Display`. Ingestion is
never gated -- that is 3.1.

What the operator actually wants when they click into the band map is for the rows
to stop moving under the mouse. So the form keeps `FFrozen`, set on `OnEnter` and
cleared on `OnExit`, and while it is set the snapshot is still rebuilt and still
painted -- new spots appear -- but the **centring window and the selection are
held**. New arrivals show up; the row under the cursor does not jump.

Selection is held **by identity, not by row index**: remember the selected spot's
frequency and callsign, and re-find it after each snapshot. Today it is re-derived
from `FCurrentCursorFreq` by matching a frequency, which is close, but the row
index is what actually gets set and a spot inserted above shifts it.

`BList` / `BCount` / `GrowBuffer` / `SetCapacityBuffer` / `InsertSpotBuffer` /
`SendAndClearBuffer` are deleted with it -- the whole unfinished buffer exists only
to undo a freeze that no longer happens.

### 4.5 Show what the parser already knows

Six columns, all resizable, widths persisted with the rest of the window layout:

| Freq | Flags | Call | QSX | Age | Comment |
|---|---|---|---|---|---|
| `FFrequency`, band-coloured, red inside the guard band | `M` `D` `CQ` as **independent** marks | `FCall`, age-ramped | `FQSXFrequency` when non-zero | `FMinutesLeft` | `FNotes` |

- **Flags stop competing for one glyph** (3.3). A spot that is both a multiplier
  and a dupe says so.
- **QSX gets the frequency, not a letter** -- the tokenizer in `uDXSpotParse`
  already produces it and nothing displays it.
- **The comment is on every row** (3.4), so reading one costs no focus change.

The status bar becomes a `TStatusBar` with `Align := alBottom` and named panels,
which retires the hardcoded `BMPanelWidth: array[0..5]` pixel table, the
`STATUSCLASSNAME` `CreateWindowA`, `SetTextInBMSB` and `ClearSpotInfo`. It keeps
the two things the row cannot show: the resolved DXCC country name
(`ctyGetCountryName`) and the spot count.

**`FNotes` stays 32 bytes for now.** `TSpotRecord` is written raw to `bandmap.bin`
(LOGWIND.PAS:2727, behind a `BandMapFileVersion` byte) and raw onto the wire inside
`TNetDXSpot` (uNet.pas:376) -- widening it is a two-format break and belongs with
the SQLite contest-file work, not here.

### 4.6 Multiplier status leaves the paint path

`UpdateSpotsMultiplierStatus` moves to where the answer actually changes: on ingest
for the new spot only, and a full sweep when the log changes -- the same places
that already call `UpdateSpotsDupeStatus` (`LOGSUBS2.PAS:1689`). That is 3.5, and
it is what makes a 250 ms tick genuinely cheap rather than nominally cheap.

### 4.7 The menu, the seam, and everything that stays

- The context menu becomes a **`TPopupMenu` in the .lfm**, one `OnClick` per item,
  `Checked` refreshed in `OnPopup`. The numeric command ids 66 / 68 / 69 / 77 /
  202..206, `CreateTR4WMenu`, the `CheckMenuItem` block and `TrackPopupMenu` all go,
  along with the band map's `B_MENU_ARRAY` entry.
- The **seam is the one `uFunctionKeysForm` already established**: a
  `CreateTR4WBandMapWindow(aParent: HWND): HWND` and a second arm in
  `OpenTR4WWindow` (MainUnit.pas:5306). `tr4w_WindowsArray[tw_BANDMAPWINDOW_INDEX]
  .WndHandle` keeps holding a real handle, so window position save/restore, the
  menu check mark, `tWindowsExist` and `CloseTR4WWindow` are untouched.

  **That `HWND` in the signature is SCAFFOLDING, and it is on the demolition
  list.** The end state has no HWND anywhere -- see ROADMAP section 2 and the
  mapping table there. `tr4w_WindowsArray` is a Win32 window registry: an array
  of handles, window procs and rects that exists because there was no
  `TApplication` to own the tool windows. Once the last `tw_` window is a form,
  that array becomes `Screen.Forms` plus a saved layout, and the seam parameter
  and return type go with it. Nothing in this design should be read as endorsing
  the handle -- it is there so the band map can convert without also converting
  window-position persistence in the same commit.
- The form is parented with `OwnFormByMainWindow`, as every converted form is.
- **`TuneRadioToSpot`, `DeleteSpotFromBandmap`, `GetBandMapBandModeFromFrequency`
  and `TuneDupeCheck` do not move.** They are program behaviour, not widgets; the
  form calls them. If the uses clause turns circular, use the
  `TFunctionKeyProc`-style procedure variable already in `uFunctionKeysForm`.
- The **thread boundary does not move**. `uDXClusterClient` and the `PostMessage`
  in `TClusterEvents.Line` are correct and stay exactly as they are.

### 4.8 What gets deleted

`BandmapDlgProc` (the `WM_MEASUREITEM` / `WM_DRAWITEM` / `WM_CTLCOLORLISTBOX` /
`WM_SIZE` / `WM_INITDIALOG` / `WM_COMMAND` arms), `NEWBMLBPROC` / `OLDBMLBPROC`
(never installed), `BandmapDRAWITEMSTRUCT`, `BandMapBckgrndBrush`,
`FreqRectWidth` / `BandMapFreqWidthCalculated` / `BandMapItemHeight` /
`BandMapItemWidth`, `BMPanelWidth`, `SetTextInBMSB`, `GetBMSelItemData`,
`BandMapListBox`, `BandMapStatusBar`, `BandMapPreventRefresh`,
`BandMapSettingFocus`, `BandMapNeedsRefresh`, `BandMapRefreshTimerProc`, the
`SetTimer` at `tr4w.dpr:1061`, `TDXSpotsList.Display`, the `BList` buffer group,
and `sleep(BMDelay)`.

`CreateOwnerDrawListBox` and `tListBoxClientAlign` **stay** -- six and eight other
callers respectively, all still Win32.

## 5. Order of work

Each step builds and is testable on its own; none of them requires the next.

1. **Model first, no UI change. DONE, awaiting bench (queue section 27).**
   `TDXSpotsList` gained `RepaintToken` / `RequestRepaint` / `NeedsRepaint`,
   bumped by every mutator, with `Display` recording `FPaintedToken` **last and
   only on the path that painted** -- so a repaint refused because the window did
   not exist, or because the list was frozen, is retried rather than marked done.
   `BandMapNeedsRefresh` is deleted. The `BandMapPreventRefresh` gate is gone from
   `AddSpot` (3.1) and kept in `Display` (the freeze was only ever wanted for the
   view). The dead `BList` group and `sleep(BMDelay)` (3.6) are gone.

   Found while doing it: **`Delete` had `try ... finally FCriticalSection.Leave`
   with no matching `Enter`** -- releasing a section this thread did not own,
   which decrements the recursion count of whoever does. Every sibling pairs them
   correctly. Fixed in the same change.

   **3.5 is NOT in step 1.** Moving `UpdateSpotsMultiplierStatus` off the paint
   path needs the complete list of places the LOG changes. `UpdateWindows`
   (MainUnit.pas:6404) demonstrably covers QSO-logged, log-load, network QSO and
   WSJT-X, and `LOGSUBS2.PAS:1686` covers the logged QSO directly -- but nothing
   proves an in-place log EDIT is covered, and a stale multiplier flag presents as
   wrong scoring rather than as an error. It gets its own change, with the site
   list established rather than assumed.
2. **The form.** `.lfm` with `TDrawGrid` + `TStatusBar` + `TPopupMenu`, the
   snapshot builder, `OnDrawCell` carrying the painting rules across, the seam in
   `OpenTR4WWindow`. Behind the existing menu item, so it is either the new window
   or the old one, never both.
3. **Columns.** QSX and comment as real columns; independent flag marks (3.3, 3.4).
4. **Delete** the Win32 form and the list in 4.8; `Lint-DesignedForms` and
   `Lint-Win32Dialogs` ratchet down.

Bench items this needs, none provable by review: a real cluster feed with the
window focused for a minute (3.1); a spot arriving while another is selected
(3.2); a split spot that is also a dupe (3.3); double-click tune to a QSX
frequency; and the age ramp across a decay tick.

---

## 6. The ingest marshalling -- separate work, already largely analysed

Not part of the form. Recorded here only because "how would we build the band map
from scratch" cannot be answered without it.

**Read ROADMAP section 2's marshalling-seam analysis first -- most of this is
settled there and is not repeated.** In particular it already establishes that the
band map is *not* in the blocked set (workers only set a dirty flag; the repaint is
main-thread), that a dirty flag plus one coalesced repaint is the shape every
converted panel should copy, and the three hazards below. What follows is only what
is specific to the CLUSTER LINE path and is not in that analysis.

### 6.1 What is specific to this path

`TClusterEvents.Line` runs on the reader thread and, per line (uTelnet.pas:~1155),
`New`s a `TTelnetChunk` -- a fixed `array[0..8192] of AnsiChar` -- copies the line
in, and `PostMessage`s the pointer to the telnet dialog's `HWND`; the handler
`SetString`s and `Dispose`s it (uTelnet.pas:793).

1. **The delivery address is a WINDOW.** A cluster session is a service, not a
   widget. `WM_DESTROY` calls `Disconnect` (uTelnet.pas:1109), so closing the
   console drops the feed and with it the band map's supply. Not a bug today --
   but it is the reason the coupling can never be relaxed while the window is the
   address, and it is the same HWND dependency the end state removes.
2. **About 8 KB of heap per ~80-character line.** The fixed buffer is sized for
   arbitrary `recv()` chunks, which the Indy transport stopped producing.
3. **Ownership crosses the boundary as a raw pointer**, and the `PostMessage`
   result is unchecked -- a failed post leaks the chunk and loses the line
   silently; anything queued at shutdown is never disposed.
4. **No coalescing at ingest.** One line, one message, one handler call. The
   250 ms timer coalesces the *repaint*, not the *work*.
5. **Not unit-testable.** `uDXSpotParse` was split out precisely so the decode half
   could be pinned; the delivery half is a `WM_USER` to a dialog.

### 6.2 What we would build

`TDXClusterClient` owns a bounded, lock-guarded queue of `AnsiString` lines. The
reader enqueues; on the **empty -> non-empty edge only** it schedules one drain;
the main thread drains the whole queue in that one call.

The edge-triggered kick is the point: everything arriving before the main thread
gets round to draining lands in the drain that is *already scheduled*. Forty lines
become one callback -- coalescing with **no added latency**, which a timer cannot
give you (a timer trades one for the other). It is the same dirty-flag-plus-one-drain
shape ROADMAP section 2 already nominates, applied to the work rather than the paint.

That also answers the open question that analysis flagged -- *"whether the SPOT DATA
shared between the cluster thread and the main thread is itself handed over safely"*
-- by making the handover a queue with one owner on each side instead of a raw
pointer in an `LPARAM`.

### 6.3 The three hazards, from ROADMAP section 2, applied here

**I got one of these wrong on the first pass and the roadmap already had it right.**

- **`TThread.Queue` DOES fire today** -- not because anything calls
  `CheckSynchronize`, but because `Forms` hooks `WakeMainThread` and that message
  reaches the LCL through the hand-rolled loop's fall-through `DispatchMessage`.
  (I first wrote that it "does not fire at all"; that is wrong.) The real objection
  is the one already recorded: it is **load-bearing on the very loop the pivot
  deletes**, so adding new dependencies on it before the pivot is backwards. Hence
  the sequencing in 6.4.
- **A queueing thread that exits purges its own callback** (`uMainWindowProc.pas:617`).
  The cluster reader is created and joined on every connect/disconnect, so a drain
  queued against it would vanish at exactly the wrong moment. Queue it against
  `nil`, not the thread -- the ownerless form is not purged.
- **`Synchronize` blocks the worker** until the main thread services it. Not an
  option on a reader thread; the TCI path rejected it for the same reason.

### 6.4 Scope and order

The band map form does not depend on any of this -- it needs only that `AddSpot`
happens on the main thread, true before and after.

1. the band map (sections 4 and 5), which unblocks `Application.Run`;
2. the pivot to `Application.Run`;
3. this -- then the same pattern for the radio, external-logger and WinKey threads,
   which share the shape and the HWND dependency.
