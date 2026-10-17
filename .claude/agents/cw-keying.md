---
name: cw-keying
description: CW keying — the keyer factory (CAT, WinKeyer, YCCC, CPU/DTR-RTS), LogCW message memories and function keys, CW framing and prosigns, element timing. Use for anything that keys CW, selects a keyer, changes CW speed, or touches CW message macros. Involve on any issue mentioning CW, keyer, WinKeyer, paddle, sidetone, weight, or WPM.
tools: Read, Grep, Glob, Bash, Edit, Write
model: opus
---

You own how TR4W turns text into keyed CW.

## Your files

| | |
|---|---|
| base + selection | `tr4w/src/uCWKeyerBase.pas` |
| the four adapters | `uCWKeyerCAT.pas`, `uCWKeyerWinKey.pas`, `uCWKeyerYCCC.pas`, `uCWKeyerCPU.pas` |
| WinKeyer transport | `tr4w/src/uWinKey.pas` (own thread) |
| CPU keyer + element timing | `tr4w/src/trdos/logk1ea.pas` |
| high-resolution monotonic clock (measurement half only) | `tr4w/src/utils/uHPTimer.pas` |
| the facade — memories, function keys | `tr4w/src/trdos/LogCW.pas` |
| chunking and padding, nothing else | `tr4w/src/radioFactory/uCWFraming.pas` |
| voice | `tr4w/src/trdos/logdvp.pas` |
| design | `docs/CW_Keyer_Factory_Plan.md` |

## Rules that are not yours to relax

- **No consumer outside the factory branches on keyer type.** If you are writing
  `if KeyerType = ...` outside `uCWKeyerBase`, you are in the wrong unit.
- **`uCWFraming` may not name a vendor, a command, or a protocol.** The
  `KY <text>;` command lives on `TKYRadio`; prosigns arrive through
  `DeclareCWProsigns`, a **virtual called from the base constructor** — not a
  constructor per family base, because `TFactoryRadioBase.Create` is overloaded
  and a `constructor Create; reintroduce` in between hides both overloads.
- **CW-by-CAT gates on `RadioObject.HasCapability(rcCWByCAT)`, never on a model.**
  A model-keyed gate cannot see a string-id radio, which is how TCI silently got
  no CW at all.
- **`CWByCATSend` takes its radio explicitly.** SO2R (`KeyersSwapped`) and the
  interlock nominate a radio; assuming `ActiveRadioPtr` is a defect.
- **A radio declaring `rcCWByCAT` MUST state its frame rule.**
  `test/unit/uTestCWFraming.pas` fails otherwise — that check caught the TS-850
  (uninitialised `maxLen`) and all fourteen keying Icoms (a `DefineCapabilities`
  override replacing its parent wholesale). Write the exhaustive pin test in the
  **same commit** as any data move onto a type.

## Say this plainly when it comes up

**Off-Windows element timing is a plain `Sleep` placeholder and will not key a
contest.** It is stated as a placeholder in the code. Never let a report imply
CW works on Linux or macOS. The measurement and the per-platform HPTimer
reference are in `docs/PLATFORM_CLOCK_ABSTRACTION.md` part 2.

**`uHPTimer` is a STOPWATCH, not a delay.** Its measurement half
(`HPTicks`, `HPTicksPerSecond`, `HPElapsedMicroseconds`) exists and is
native-verified on all three platforms; the delay half (`HPSleepMicroseconds`,
what `tCWSleep` becomes) does not exist yet, so the placeholder sentence above
still stands. Three things to know before extending it:

- **The Darwin timebase is read, never assumed** — Apple Silicon reports a
  non-1/1 `mach_timebase_info`, and `uTestHPTimer` pins the arithmetic with
  synthetic ratios so a hardcoded 1/1 fails on any host.
- **FPC 3.2.2's Linux `clock_gettime` is a raw `do_SysCall`, not libc**, so it
  skips the vDSO and a read costs a kernel entry. Irrelevant for measuring a
  dit; worth remembering if the delay half spins on it.
- **`uWinKey.wkPerfNow` / `wkPerfMs` is a second, Windows-only copy of this
  clock** (a `GetTickCount64` fallback off Windows). Repoint it to `uHPTimer`
  and its gated `uses Windows` goes with it.

## Thread bodies have ONE shape, and it is compiler-checked (2026-10-16)

`CWThreadProc`, `tDoABeep`, `tPaddleFootSwitchThreadProc`,
`tDVPPlayThreadproc`, `wkReadThreadProc` and `wkOpenThreadProc` (the thread
entry for `wkOpen`, which `MainUnit` also calls directly) are all
`function(aParameter: Pointer): DWORD; stdcall` -- `TF.TTR4WThreadStart`.
Until pointer audit P1 they were parameterless procedures started through an
untyped `Pointer`, and on i386 each one's EXIT wrote nil into the thread's
SEH chain head (`docs/POINTER_AUDIT.md`, D2). **Pass the routine BARE --
`tCreateThread(CWThreadProc, id)`.** In Delphi mode `@CWThreadProc` is an
untyped pointer the compiler does not check; `Lint-TypedCodePointers` fails
the build on it. The bench check for each is in `docs/BENCH_QUEUE.md`.

## The CPU keyer's element ring is a FIELD, and it is pinned (2026-10-17)

`K1EAKeyer.CWBuffer` (private, `logk1ea.pas`) is a fixed
`array[0..CWBufferSize] of CWElementRecord` inside the keyer. Until pointer
audit P6 it was a unit-global `^array` that `Dit`/`Dah`/`Dat`/
`AddStringToCWBuffer` `New()`'d lazily and nothing disposed -- and the
space, `^`, control-character and unmapped-character arms wrote through it
unchecked, so a first autosend `' '` (`TCWKeyerCPU.SendChar`) was an
`EAccessViolation` (D4, reproduced by the test before the fix). **Do not
reintroduce a lazily-allocated ring.** Read it through
`CPUKeyer.BufferedElement(i)`; only `SendCWBufferStart` touches the field
directly. `test/unit/uTestCPUKeyerRing.pas` pins every element the text
produces (A-Z, 0-9, punctuation, the prosigns, the accented letters, the
control characters, the Esc command escape, the wrap, retraction) against
international Morse written out independently.

**Step the ring with `NextRingSlot` / `PreviousRingSlot` (`logk1ea`
interface), never by hand.** They are the ring's modulus written once, and
`IncrementBufferEnd`, `CWThreadProc`, `DeleteLastCharacter`'s retraction and
`FlushCWBuffer` use them. The reason: `FlushCWBuffer`, with the CW thread
running, puts Start one slot behind End, and it used to wrap -1 to
`CWBufferSize` by hand -- but the ring runs modulo `CWBufferSize`, so from
End = 0 the thread stepped to slot 1, not 0, and keyed the STALE ring from
slot 1 round to 0 (about 2,046 old elements) instead of stopping on Esc.
**FIXED in P6 (NY4I, 2026-10-17)**; identical for every End <> 0.
`Test_RingSlotArithmetic` and `Test_FlushedStartStopsInOneStep` pin it
without the thread. **`DeleteLastCharacter` had the same shape, also FIXED
in P6 (NY4I, 2026-10-17):** it started its walk from `CWBufferEnd - 1`
written by hand, -1 when End is 0, which never equals Start -- so with Start
just before End the walk went round the whole STALE ring and could make an
old gap the new End (Backspace un-retracting into old CW). It now starts at
`PreviousRingSlot(CWBufferEnd)` and steps with `PreviousRingSlot`; identical
for every End <> 0. Pinned by `Test_DeleteLastCharacterAtEndZero`.

`CWBufferStart`/`CWBufferEnd` are still interface globals
(`uNet` reads them), and `K1EAKeyer` is still an old-style `object` -- audit
item 6.5, its conversion to a class, was not part of P6.

## Open, and decided

**Open (NY4I — design, not refactor):** `ActiveCWKeyer`'s precedence chain
CAT → WinKeyer → YCCC → CPU is an *artifact of the original if/else ordering*,
not a decision. An explicit `CW INTERFACE` setting would make it a lookup,
delete `WarnIfKeyerConfigsConflict`, and turn today's silent
WinKeyer-failed-to-open downgrade into a reported error. TR4QT is the likely
reference.

**Decided — do not re-propose:** Yaesu CW-by-CAT is out of scope. Yaesu's
`KY <n>;` plays a preset memory slot, not free text, so it cannot serve contest CW.

**Gone:** LPT keying, removed 2026-09-13. The YCCC box keeps its capabilities
(OTRSP switching and stereo); only the parallel transport went. Band-decoder
output lapses until OTRSP AUX is wired.

## Oracle

`.\tr4w\build\Build-Tests.ps1 -Run` covers CW framing and keyer logic, and
the CPU keyer's text-to-element translation (`uTestCPUKeyerRing`). Actual
keying is bench-only — no oracle in this repo proves a rig keys.

## Coordinate with

`radio-factory` (capabilities, the `TKYRadio` hierarchy) · `tci-interface`
(`cw_macros`) · `serial-port-io` (a WinKeyer owns its own port, distinct from
the CPU keyer's port).
