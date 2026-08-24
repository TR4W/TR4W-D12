# The domain layer, and the order the three big pieces go in

**Decided 2026-08-24 with NY4I**, at the end of the window conversions.
NY4I: *"I'm not interested in a port of mediocre design. I want the contest
factory and SQLite steps but we need to combine this to the true, native LCL
way to do this."*

This document owns the ORDER. `ROADMAP.md` §8 points here rather than
restating it.

---

## The three pieces are one problem

Display state, the contest factory and the SQLite log look like three projects.
They are three faces of the same one: **TR4W has no domain layer.**

| what it looks like | what it is |
|---|---|
| the widgets hold the display state | no model |
| `case Contest of` scattered across units | no model |
| the ListView is the log, the `.dat` is the store | no model |

Every one of them is *extract a model*. So the order follows one rule:

> **Do them in order of how many other things will be written against them.**

## The order, and why

### 0. Persistent worker threads, and `TThread.Queue` — a PREREQUISITE, not a nicety

Added 2026-08-24 after NY4I pushed back on the marshalling choice: *"this sounds
like a capitulation we would not do if this was started from scratch."* He is
right, and the capitulation is one level below the mechanism.

Everything in this tree marshals with `Application.QueueAsyncCall` because
`TThread.Queue` stamps each entry with the **calling thread's** id
(`classes.inc:556`, unconditionally — passing `nil` as the thread does **not**
dodge it) and `TThread.Destroy` purges by the object *and* by that id. A thread
that queues and then exits deletes its own pending callback.

**That semantic is correct.** When a thread dies, an update about its work
refers to something that no longer exists. The defect is that `TReadingThread`
(`uFactoryRadioBase:211`) is **destroyed and recreated on every reconnect**. A
radio connection is a long-lived resource; reconnecting is a state transition
*inside* one thread's life, not a reason to tear the thread down. Move the
backoff loop inside a persistent thread and the purge fires only at shutdown —
which is when dropping pending updates is right.

There is a second reason, independent of the purge: **`QueueAsyncCall` lives in
`Forms`**, so it binds marshalling to the LCL. `TThread.Queue` is RTL — it works
in a console tool, in the unit tests, and on any widget set. For a program that
intends to reach macOS and Linux, choosing the widget-set-specific primitive for
a core mechanism is the wrong default on its own.

**So this comes before, or with, the display-state work rather than after it** —
otherwise every state object added below inherits the interim. The order is:
persistent radio threads, then `TThread.Queue` throughout, then the rest of this
document.

### 1. Display state — smallest, and it goes first

Not because it matters most. Because **the other two will write against whatever
seam exists when they are built.**

If SQLite and the contest factory land while the display still works by *a
worker thread names a widget*, they will be wired that way: score, mult counts,
rate, band changes all pushed as `SetMainWindowText(mweXxx, ...)` from wherever
they happen. Then two large new subsystems have to be unwired. Doing this first
means both are written against state observers from the first line.

It is also the only one of the three that is **bounded and verifiable today**:
a handful of units, no schema, no contest semantics, and the window conversions
just made every consumer explicit. See
[`DISPLAY_STATE_MODEL_PLAN.md`](DISPLAY_STATE_MODEL_PLAN.md) for the argument
and the two measured traps (Win32's accidental thread safety;
`TThread.Queue` purging its own callbacks).

### 2. SQLite — gives the log a model

The editable log then converts as an LCL **virtual list** (`OwnerData` /
`OnData`), which is the native answer and is already the recorded decision: it
converts AFTER the log has a model, not before. That is the 36 remaining `wh[]`
sites, and they fall out rather than being fought.

**A design constraint, not an afterthought: the golden corpus is the regression
oracle and it reads binary `.dat` through the export path.** The migration has
to keep that oracle working across the change, or the only proof that scoring
and Cabrillo did not move is gone at exactly the moment it is most needed.

### 3. Contest factory — needs both

It wants a log it can query and a display it can update without naming widgets.
It is also the largest — 120+ contests, `case ActiveExchange` in `PostUnit`,
scoring, multipliers — and it is where `ContestExchange` becomes an object. It
also harvests the per-contest initial states out of `FCONTEST.PAS` (NY4I,
2026-08-24).

## The shape

```
src/domain/    contest, log, radio, keyer state -- NO LCL, NO Windows
src/ui/lcl/    forms and views, observing the domain
src/trdos/     shrinks as behaviour migrates into domain
```

with **ONE marshalling point** — the notification dispatch — not one per
setter. Today there are three (`uPanelUpdate`, `uMainThreadWork`, and the
accessor funnel in `uMainForm`), all of which exist because the boundary was
retrofitted rather than drawn.

## What makes the layering hold: a lint

Every time this tree has needed several files to agree, the answer has been a
lint and never a convention — `Lint-FormDefaults`, `Lint-FormEvents`,
`Lint-SettingsMigration`, `Lint-Win32Dialogs`.

**`Lint-DomainPurity`: no unit under `src/domain/` may reference the LCL,
`Windows`, `wh[]`, or any `mwe*` identifier.**

It is grep-cheap, it fails the build, and it makes the layering a fact rather
than an intention. Without it there will be a `uses Forms` in the domain within
a month, and it will arrive in a commit that is about something else.

## The risk, named

Doing display state first delays the two things NY4I actually wants. That is
real. The mitigation is that it is genuinely the smallest of the three, and that
it is the prerequisite for not repeating the same mistake at ten times the
scale.
