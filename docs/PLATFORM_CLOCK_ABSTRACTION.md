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

---

# PART 2 -- THE OTHER CLOCK: interval timing, and why CW makes it hard

**Added 2026-09-01.** Everything above is about the WALL CLOCK -- what time is it,
and a wire format that carries it. This part is about INTERVALS -- how long is a
dit -- and they are different problems with different answers. They live in one
document because they will be touched by the same person on the same day.

## What TR4W actually uses, measured

`winmm` shows up in the DLL audit as 189 declarations, which is misleading:
`MMSystem.pas` is a 4,669-line unit declaring the whole Windows multimedia API.
**TR4W calls five things, at 13 sites.**

| what | where | why |
|---|---|---|
| `timeSetEvent` + `timeBeginPeriod(1)` / `timeEndPeriod(1)` | `LOGK1EA.tCWSleep`, `:1963`, `:2019` | **CW element timing.** The hard one |
| `timeSetEvent` | `LOGDVP:658` | DVP voice playback, waiting on `tDVP_Event` |
| `sndPlaySound(nil, SND_ASYNC)` | `MainUnit:1077` | passing NIL is the documented way to STOP whatever is playing -- used when aborting DVP |
| `timeKillEvent` | `MainUnit:1079` | cancels the DVP timer |
| `waveIn*` (6 calls) | `uMP3Recorder` | audio capture: open, start, add buffer, reset, close |

So the port is not 189 anything. It is **two subsystems that need real work**
(precision timing, audio capture) and **two calls that do not**.

## Why CW keying is the hard case

`LOGK1EA.tCWSleep`:

```pascal
t := timeSetEvent(millsec, 1, TFNTimeCallBack(myEvent), 0,
                  TIME_ONESHOT + TIME_CALLBACK_EVENT_SET);
if t <> 0 then
   WaitForSingleObject(myEvent, INFINITE)
else
   Sleep(millsec);
```

**Windows' default timer granularity is about 15.6 ms.** A dit at 30 WPM is 40 ms;
at 40 WPM it is 30 ms. Quantising CW elements to 15.6 ms steps is audibly wrong
keying, which is why `timeBeginPeriod(1)` raises the system timer to 1 ms and
`timeSetEvent` provides the one-shot.

**Note the `else` branch.** A fallback to plain `Sleep` already exists, so the
SHAPE of a portable abstraction is present -- only the Windows arm is filled in.

## EpikTimer: right project, wrong half

NY4I found `c:\projects\epiktimer` and asked whether it is the answer. **It is a
STOPWATCH, not a DELAY**, and the distinction is the whole point here.

`epiktimer.pas:425`:

```pascal
function TEpikTimer.SystemSleep(Milliseconds: Integer): integer;
begin
  Sleep(Milliseconds);
  Result := 0;
end;
```

The declaration above it promises *"overhead compensated system sleep to provide a
best possible precision delay"*; the body is a bare `Sleep`. **Adopting it for
`tCWSleep` would give the keyer the FALLBACK path our code currently takes only
when `timeSetEvent` fails.** The author says so himself in two comments --
*"nanosleep... poor absolute accuracy due to large amounts of jitter"*.

**What it is genuinely good at, and what we do not have:** a high-resolution
cross-platform CLOCK -- TSC-based, with overhead extraction and timebase
correlation against the system clock. That matters twice over. We have no portable
way to answer *"was that dit actually 40 ms?"* -- today the only check on keying
accuracy is an operator's ear -- and a precise DELAY is built from a precise
CLOCK: sleep coarsely, then spin the last stretch against a high-resolution tick
source.

**Its limits, from its own source:** `{$IFDEF}`s for Windows, Linux and FreeBSD --
**no Darwin** -- and the hardware timebase is `CPUI386`, i.e. the Pentium TSC,
which does not exist on ARM. It is also an LCL `TComponent` with a palette icon,
which is the wrong shape for this and is probably part of why it never reached the
RTL, along with the TSC's need for calibration and correlation.

## THE APPLE SILICON GAP, AND IT IS REAL -- verified in FPC's own source

`rtl/unix/sysutils.pp:54`:

```pascal
{$IF defined(LINUX) or defined(FreeBSD)}
{$DEFINE HAVECLOCKGETTIME}
{$ENDIF}
```

**FPC 3.2.2 does not define `HAVECLOCKGETTIME` for Darwin**, and `clock_gettime`
is declared only in `linux.pp:471` and `freebsd.pas:233`. There is no Darwin
declaration anywhere in the RTL, and `rtl/darwin/aarch64/` contains only signal
handling. So on macOS -- Apple Silicon or Intel -- **FPC gives us no monotonic
high-resolution clock at all**; `Now` and `GetTickCount64` fall back to
`gettimeofday`, which is wall time and can step.

That is what justifies writing our own, and it is worth stating plainly because
the standing rule is to prefer an FPC/LCL class: **there is no FPC class to
prefer here.**

## The per-platform reference for an HPTimer

**Verify each of these on the platform before trusting it.** They are written down
so the work starts from a specific claim that can be checked, not a search.

| platform | monotonic tick source | precise sleep |
|---|---|---|
| **Windows** | `QueryPerformanceCounter` / `QueryPerformanceFrequency` | what we have: `timeBeginPeriod(1)` + `timeSetEvent` one-shot + wait |
| **Linux** | `clock_gettime(CLOCK_MONOTONIC_RAW)` -- FPC declares it | `clock_nanosleep(CLOCK_MONOTONIC, TIMER_ABSTIME)` -- absolute deadline, no drift accumulation |
| **macOS / Apple Silicon** | `mach_absolute_time()` + `mach_timebase_info()`; **or** `clock_gettime(CLOCK_MONOTONIC_RAW)`, which macOS 10.12+ has in libSystem and FPC merely fails to declare | `mach_wait_until(deadline)` -- macOS has **no `clock_nanosleep`** |

**Apple Silicon specifics to check on hardware rather than believe from here:**

- There is **no RDTSC**. The ARM equivalent is `CNTVCT_EL0` with `CNTFRQ_EL0`
  for the frequency, and `mach_absolute_time` is the supported way to read it
  rather than the register directly.
- `mach_timebase_info` returns numer/denom to convert ticks to nanoseconds. On
  Intel Macs it is 1/1; on Apple Silicon it is **reported** as 125/3 (a 24 MHz
  counter). **Do not hardcode either** -- that is the whole reason the call
  exists.
- **P-cores and E-cores matter.** A thread that drifts onto an efficiency core
  keys differently. Audio applications set thread QoS, or a real-time
  scheduling policy via `thread_policy_set` with
  `THREAD_TIME_CONSTRAINT_POLICY`. Whether CW keying needs that is a bench
  question, and it is the sort of thing that shows up as intermittent bad
  keying rather than as a failure.

**Declaring `mach_absolute_time` and `mach_wait_until` ourselves is a direct
libSystem binding**, which CLAUDE.md's rule says must be justified. The
justification is the section above: FPC declares neither, and there is no class
to prefer. Write that reason beside the declarations.

## The shape

One unit, `tr4w/src/utils/uHPTimer.pas`, with two independent halves, because the
measurement half is useful immediately and the sleep half is not:

```pascal
{ MEASUREMENT -- usable now, and the only way to bench keying accuracy at all }
function HPTicks: Int64;              { monotonic, platform's best source }
function HPTicksPerSecond: Int64;
function HPElapsedMicroseconds(const aFrom: Int64): Int64;

{ DELAY -- what tCWSleep becomes }
procedure HPSleepMicroseconds(aMicroseconds: Int64);
```

**Do the measurement half first.** It is the smaller of the two, it has no
real-time requirement, and it produces the instrument that says whether the sleep
half is working -- which no bench test can currently answer on any platform.

**Keep `timeSetEvent` on Windows.** It is bench-proven keying and there is no
reason to risk it; the abstraction's value on Windows is that `LOGK1EA` stops
naming a Win32 API, not that the mechanism changes.

## What this does NOT cover

Audio capture (`uMP3Recorder`'s `waveIn*`) and `sndPlaySound`. Those are a
different subsystem with a different answer -- a cross-platform audio library, or
a Lazarus package -- and folding them in here would make one document about two
unrelated ports.

---

## What this is NOT

Not a general sweep of `Windows.` call sites. There are several hundred qualified
`Windows.` references left in the tree and they are Phase 8's problem as a whole;
this one is written up separately because the wire-format trap makes it unsafe to do
mechanically along with the rest.
