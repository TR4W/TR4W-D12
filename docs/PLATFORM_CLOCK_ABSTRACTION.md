# The system clock: one Win32 call to abstract, one wire format to leave alone

**Status:** open, not started. Written 2026-08-25 from the K4-Spectrum worktree after
NY4I spotted `Windows.SetSystemTime` while reading `uNet.pas`. Small, self-contained,
and independent of the panadapter work.

## What prompted it

`uNet.pas:396`

```pascal
if Windows.SetSystemTime(NetTimeSyncPtr.tsTime) then
```

A qualified Win32 call in the middle of the multi-op network message handler. It is
the kind of thing Phase 8 of the LCL migration exists to remove.

## The two halves pull in opposite directions

This is the part to get right before touching anything, because the obvious move --
"replace `SYSTEMTIME` with an FPC-native type" -- is wrong for one half.

### Half 1: the record MUST NOT CHANGE. It is a wire format.

`VC.pas:2137`

```pascal
TNetTimeSync = packed record
   tsID: Word;
   tsTime: SYSTEMTIME;
end;
```

That record is **sent over the multi-op network socket**. `SYSTEMTIME` is not being
used here as an API type that happens to be convenient; it *is* the on-the-wire
layout -- 8 x Word, 16 bytes, little-endian -- and every peer on the far side of a
multi-op LAN sends and expects exactly those bytes, including D7 stations running the
heritage program.

Substituting `SysUtils.TSystemTime` because the names look alike would compile
cleanly and could silently change the field set or ordering. The failure mode is a
peer setting the wrong system clock in the middle of a contest, which is both
invisible at the point of the bug and expensive.

**If it is ever repointed, prove it byte-identical first** -- `SizeOf` plus a
per-field offset check, pinned in a unit test, in the same commit. Do not substitute
on the strength of the declaration looking the same.

The recommendation is to leave the record alone and add a comment saying what it is,
because the next reader will have the same (correct) instinct that a `SYSTEMTIME` in
2026 looks out of place.

### Half 2: the two API calls SHOULD move -- to an abstraction, not to a type

Only two sites in the program touch the system clock:

| Site | Call |
|---|---|
| `MainUnit.pas:4211` | `Windows.GetSystemTime(NetTimeSync.tsTime)` |
| `uNet.pas:396` | `Windows.SetSystemTime(NetTimeSyncPtr.tsTime)` |

Reading the clock has a portable answer. **Setting it does not** -- FPC has no
cross-platform "set the system clock"; it is a privileged operation with a different
mechanism on every OS.

So this is exactly the situation `utils/uPlatformProcess.pas` already solved for
program launching, and that unit's header is the pattern to follow:

- something meaningful on every platform gets a portable implementation and no guard
- something Windows-only is **named as such**, guarded in ONE file, and **reports
  failure** rather than doing nothing
- the guard lives in the abstraction, not scattered through the callers

Proposed shape, a small `tr4w/src/utils/uPlatformClock.pas`:

```pascal
{ The system clock, read and set, in one place.

  Reading is meaningful everywhere.  SETTING is a privileged, per-OS operation
  with no portable equivalent, so it is guarded here rather than at the call
  site, and it reports why it failed. }

function ReadSystemClockUTC: TDateTime;
function SetSystemClockUTC(const AWhen: TDateTime): boolean;
```

Both callers then convert at the boundary: `uNet` decodes the wire `SYSTEMTIME` into
a `TDateTime` and passes that in; `MainUnit` encodes the other way. The wire record
stays untouched and Win32 stops leaking into the network handler.

## Two real defects to fix while it moves

Neither is the reason for the change, but both are in the code being touched and
neither should survive the move.

**1. The validation is weaker than it looks.** `uNet.pas:390-393`:

```pascal
if NetTimeSyncPtr.tsTime.wYear > 2007 then
  if NetTimeSyncPtr.tsTime.wMonth <= 12 then
    if NetTimeSyncPtr.tsTime.wDay <= 31 then
      if NetTimeSyncPtr.tsTime.wHour <= 23 then
```

It accepts month 0, day 0, and 31 February, and never checks minutes or seconds at
all. This is a value arriving over a socket from another station, so it is exactly
the input that deserves a real check. Once the parameter is a `TDateTime`,
`TryEncodeDateTime` does the whole job correctly and the four nested `if`s go away.

**2. `SetSystemTime` needs `SE_SYSTEMTIME_NAME` enabled** or it fails on any
normally-privileged account. The current code does report -- there is a
`ShowSysErrorMessage('SET SYSTEM TIME')` on the else branch, which is right -- but
the abstraction is the place to turn "access denied" into something an operator can
act on, since "TR4W needs to be allowed to set the clock" is a configuration answer,
not a bug report.

## Scope

Small. One new unit under `tr4w/src/utils/`, two call sites, one added unit-test
suite (the offset pin for `TNetTimeSync`, plus the validation cases the four `if`s
currently let through). No behaviour change on a correctly-configured Windows
station -- which is also why it needs the pin test, since nothing else would notice
if the wire layout moved.

## What this is NOT

Not a general sweep of `Windows.` call sites. There are several hundred qualified
`Windows.` references left in the tree and they are Phase 8's problem as a whole;
this one is written up separately because the wire-format trap makes it unsafe to do
mechanically along with the rest.
