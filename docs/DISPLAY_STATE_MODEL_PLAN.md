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

**Expected argument against, answered in advance:** this is a port, and the
existing design is defensible for a port -- it preserves behaviour, every step
is verifiable, and it is genuinely safer than the Win32 it replaced. The case
for doing it is not tidiness. It is that "which thread am I on?" is a question
the code should not be able to ask, and today it can.
