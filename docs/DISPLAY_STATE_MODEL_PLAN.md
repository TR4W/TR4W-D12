# Display state as a model — the successor to the window conversions

**Status: PARKED, on the record.** Written 2026-08-24, at the end of the day
that converted the main window's forty-two elements to LCL controls. NY4I asked
how a WSJT-X datagram turns the WSJT-X indicator green; tracing the answer found
a defect, the defect was fixed at the right layer, and then the real question:
*"And this is how one would do this in a multithreaded LCL app starting from
scratch?"*

**No.** This document is why, and what the end state is.

Do not start this until the window conversions are finished. It is the natural
successor to them, not a competitor.

---

## What we have, and why it is shaped that way

A worker thread today tells the UI **which control to write**:

```pascal
// TWSJTXServer.OnServerRead -- an Indy UDP listener thread
SetMainWindowText(mweWSJTX, 'WSJTX');
ShowElement(mweWSJTX, True);
```

That is a UDP listener knowing the name of a widget. The same shape appears in
`uRadioPolling` (frequency, PTT status), `uWinKey` and `LOGK1EA`.

**Two of those four were already stale when this was written, and the correction
matters more than the list does.** `LOGK1EA`'s only `SetMainWindowText` is
commented out, and its one live edge into the UI (`QueueStartSendingKey`) was
already marshalled. `uRadioPolling`'s frequency write went through
`DisplayFrequency`, which has *no callers at all*. So the plan opened by naming
two units that needed nothing -- which is exactly the reason step 4 below is now
gated on the program's own evidence rather than on a reading of the tree.

**It worked for twenty years because Win32 made it work.** `SetWindowTextW`,
`ShowWindow` and `EnableWindow` are kernel calls: Windows marshals them to the
window's own thread. Nobody wrote that down, and nobody had to. Assigning an LCL
`Caption` does no such thing — so converting those calls to property
assignments turned an accidental safety into a silent corruption, and the guard
in `uMainForm.ElementOnMainThread` is what makes it safe again.

**That guard is a retrofit, and it is the right retrofit.** `SetMainWindowText`
alone has ~75 callers; a rule saying each must know its own thread is right for
a year and then quietly wrong. One funnel cannot be forgotten. But a guard that
makes wrong code *work* is weaker than a structure that makes it
*unwriteable* — and the latter is what a new app would have.

## What a from-scratch LCL app does instead

1. **Threads update a MODEL; the view reads it.** The worker says *"the WSJT-X
   link is up"*, not *"set `mweWSJTX` green"*. Deciding that an up link means a
   green panel is the view's job and belongs in `src/ui/`.
2. **The thread boundary is ONE place** — the change notification — not one per
   setter. We currently marshal in three: `uPanelUpdate`, `uMainThreadWork`, and
   the accessor funnel. All three exist because the boundary was retrofitted
   rather than drawn.
3. **Coalescing is free.** A model holds the LATEST value; the view reads
   whatever is there when it repaints. We have two hand-built coalescing
   mechanisms (`uPanelUpdate`'s value cache, `uMainThreadWork`'s bit-per-job)
   precisely because the transport had to do it.
4. **No unit outside `src/ui/` knows `mweWSJTX` exists.**

## The one trap that survives a rewrite

**`TThread.Queue` is the obvious mechanism and it is wrong here, measurably.**
It stamps each entry with the CALLING thread's id, and `TThread.Destroy` purges
by that id — so a thread that queues and then exits **deletes its own pending
callback**. Radio threads are torn down on every reconnect, which is exactly
when a display update matters most. That is why `uPanelUpdate` uses
`Application.QueueAsyncCall`, and it was measured rather than assumed (see the
header there). A from-scratch app hits this too; it just hits it once, at the
notification dispatch, instead of at every call site.

## Where the tree already is

The direction is right in everything written recently:

- `uBandMapForm` has `SpotsList` and a snapshot.
- `TFlowGrid` is a model with a view over it, shared by three windows.
- The stations window had its rows extracted from the control on 2026-08-24
  specifically so the control stopped being the model.

**The main-window elements are the last place where a thread writes a widget.**

## Shape of the work

1. `TRadioState`, `TWSJTXState`, `TKeyerState` -- plain objects the threads own
   and update under a lock. No LCL types in them.
2. Change notification with ONE marshalling point.
3. The main form subscribes and maps state to appearance -- which is also where
   the restyle in [`GRID_RESTYLE_PLAN.md`](GRID_RESTYLE_PLAN.md) wants to live,
   so the two should be planned together.
4. `SetMainWindowText` and the element accessors become internal to `src/ui/`.
   The guard stays as a backstop; it should simply stop having anything to
   catch.

## Steps 1-3 are done. Step 4 is gated, deliberately

| state object | replaced | commit |
|---|---|---|
| `TWSJTXState` | a UDP listener thread naming `mweWSJTX` | earlier |
| `TRadioState` | the radio polling thread writing `mwePTTStatus` | `f46c5d5c` |
| `TKeyerState` | THREE writers -- `wkOpen` plus both WinKey read threads | `a585a7e5` |

**Step 4 was not started next, and the reason is the finish line it is measured
against.** It is roughly sixty mechanical call-site moves in `LOGWIND` and
`MainUnit`, every one of them already on the main thread -- a layering
improvement with no thread-safety payoff. Its stated success condition is that
the guard has "nothing to catch", and **that condition was unaskable**: all
three element accessors deferred off-thread work in complete silence, so the
only available evidence was a hand call-graph walk. That form of evidence has
been wrong three times in this tree, twice in this document.

So the guard was made to report first, reusing `ReportOffMainThread` -- the
same mechanism its sibling `ControlUsable` has always used for the entry fields,
and the same mechanism whose silence licensed *that* conversion ("a full bench
session with a K4 produced none"). A bench session now answers "does any thread
still write a main-window element" in the log, and step 4 can be justified by
what the program says rather than by what a search found.

The same change closed a gap it surfaced: `SetElementColors` was the one
accessor of four with **no thread guard at all**. Its known off-thread caller is
safe by a different mechanism -- `uRadioPolling` registers
`RefreshMainWindowElementColors` as a main-thread job -- which is precisely the
kind of safety that holds only while one registration keeps holding.

## Where it ended, 2026-08-30

Eight bench sessions with a K4, WSJT-X, live CW and a DX cluster under spot
load. The report was moved out twice before it could answer anything -- first
from inside the guard to the accessors (`9202356c`), then from the accessors to
`SetMainWindowText` (`ff5dbe80`), because each level named *itself* and deduped
everything behind it.

Once it named real callers, the answer was eleven sites, and **ten of them were
one thread running one batch** after a WSJT-X QSO. Marshalled as a batch
(`ff49eaad`) rather than converted into ten state objects -- see that commit for
why, and NY4I's call on it.

| what | where |
|---|---|
| `TWSJTXState`, `TRadioState`, `TKeyerState` | done -- `f46c5d5c`, `a585a7e5` |
| WSJT-X entry-field writes | `1e3c295b` |
| WSJT-X display batch (10 sites) | `ff49eaad` |
| stations `TListItem` write from a socket thread | `7ab38d88` |

### The finding that outlives this plan

**A clean report is evidence about what is instrumented, not about the
program.** The off-thread report covers `SetMainWindowText` and `uMainForm`'s
element and entry accessors -- the MAIN window's funnels. Every converted tool
window has its own way in, and `uStationsForm.StationsSetCell` guards the
control's *existence* without guarding the *thread*. So eight runs converging on
a tidy list of main-window callers said nothing whatever about the stations
window, and the genuinely dangerous defect of the whole exercise -- a UDP
listener assigning `TListItem.Caption` and `SubItems`, which reallocates rather
than flickers -- was found by reading, not by the instrument built to find it.

Measured coverage, same date: of the units under `src/ui/lcl` with a
`...Usable` guard, only `uMainForm` and `uStateBridge` test the thread.
`uStationsForm` and `uTelnetForm` do not. Telnet is safe in practice because the
cluster event queue marshals before reaching it -- but nothing enforces that,
and "safe in practice" is what this document exists to stop relying on.

### What is deliberately left

`LogContact` (`LOGSUBS2:1440`) interleaves model and view: it logs the QSO *and*
calls `UpdateStationStatus`, `ShowDomesticMultiplierStatus`, `DisplayHour` and
`DisplayNamePercentage`. That is why a socket thread reaches four display
routines at all. The remaining reporters all reach the main window through
accessors that DO defer, so what is left is **layering debt, not races**.

Separating them is contest-engine surgery that wants a corpus run and daylight,
and it is the same work the SQLite contest-state move
([`SQLITE_LOG_SCHEMA_PLAN.md`](SQLITE_LOG_SCHEMA_PLAN.md)) will do properly.
Doing it twice is the thing to avoid.

Also open: `tDispalyOnAirTime` (`LOGWIND:3689,3694`) on the radio polling
thread -- a clock tick, unrelated to any of the above, and a small state object
when someone wants it.

**Expected argument against, answered in advance:** this is a port, and the
existing design is defensible for a port -- it preserves behaviour, every step
is verifiable, and it is genuinely safer than the Win32 it replaced. The case
for doing it is not tidiness. It is that "which thread am I on?" is a question
the code should not be able to ask, and today it can.
