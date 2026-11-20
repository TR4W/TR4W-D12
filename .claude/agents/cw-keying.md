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
- **A CAT keyer may have no abort and no speed.** DXLab Commander (`cwchars`,
  2026-11-17) is the case: Escape withdraws only text still in its queue, the
  rig keys at Commander's own speed, and the busy window is TR4W's speed
  estimate x 1.25. Do not invent a stop command to make Escape look complete.

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
entry for `wkOpen`, started only by `wkStart`) are all
`function(aParameter: Pointer): DWORD; stdcall` -- `TF.TTR4WThreadStart`.
Until pointer audit P1 they were parameterless procedures started through an
untyped `Pointer`, and on i386 each one's EXIT wrote nil into the thread's
SEH chain head (`docs/POINTER_AUDIT.md`, D2). **Pass the routine BARE --
`tCreateThread(CWThreadProc, id)`.** In Delphi mode `@CWThreadProc` is an
untyped pointer the compiler does not check; `Lint-TypedCodePointers` fails
the build on it. The bench check for each is in `docs/BENCH_QUEUE.md`.

## The WinKeyer is opened and closed by ONE pair, `wkStart` / `wkStop` (2026-11-14)

Startup, the Alt-menu re-open and `uRadioConfigApply.ApplyProfile` (Preferences
Activate and Save, the setup wizard) all go through `uWinKey.wkStop` /
`wkStart`; nothing calls `wkOpen` directly. Until then a profile apply never
opened or closed the WinKeyer: a new one waited for a restart, and a moved one
kept its old port and reader thread while `ActiveCWKeyer` fell back to the CPU
keyer in silence.

- **`wkStop` WAITS, by flag** (`wkOpening`, `wkReaderRunning`: set by the
  creator before `tCreateThread`, cleared by the thread in a finally; the loop
  is `TF.WaitForFlagToClear`, shared with the radio poller's stop). Open first,
  then `wkActive := False`, then the reader, then `wkClose` and
  **`FreeAndNil(WinKeyPort)`** -- a `TSerialPort`'s name is fixed at Create, so
  a closed-not-freed port reopened on the OLD port. 3 s each; on a timeout it
  logs an Error and leaves the port alone, and `wkStart` refuses while either
  flag is up. **Once both are down, `wkStart` frees any `WinKeyPort` a
  timed-out stop left behind** (`wkReleasePort`, shared with `wkStop`) --
  otherwise the next open reused the old object on the OLD port (review M12,
  2026-11-16).
- **A failed open is REPORTED, every time** (review H5, 2026-11-16). `wkOpen`
  and `wkOpenPort` return a reason for every False (not enabled, not a serial
  port, the port would not open, no echo, wrong echo byte, reader not
  started); `wkOpenThreadProc` hands it to `wkReportNotOpened`: one Error
  naming the port, the reason and the keyer CW now goes to, and one notice
  (`TC_WINKEYERDIDNOTOPEN`, through `QuickDisplay`, any thread). The modal
  `showwarning` for an unopenable port is gone -- one report, not two.
  `ActiveCWKeyer`'s precedence is NOT changed; refusing the fallback is the
  open CW INTERFACE question below. The old `wksWinKey2Port = NoPort` guard is
  gone too: it refused every device node (`/dev/ttyUSB0` has no ordinal).
- **The handshake is the open thread's alone** (review M12). `wkPortOpen` is
  True from the port open, before the echo test, and the main-thread entry
  points (`wkSetSpeed`, `wkSetKeyerOutput`, `wkTurnPTT`) guard on it alone.
  `wkWriteRaw` -- the one write path -- refuses (Warn) any other thread while
  `wkHandshaking`; `wkOpen` raises it and drops it just before the reader
  starts.
- **`wkActive` is set by `wkOpen` before it creates the reader**, not by the
  reader: a stop landing between create and first line was undone by the
  reader itself, which then looped beside the next one and stole the echo byte.
- **`wkStart` opens on a worker** (the echo test and HOST OPEN are blocking
  reads) and does nothing when not enabled, or when `tSilentExport` /
  `WarningsHaveNoOperator` say there is no station.
- `ApplyProfile` stops it after phase 1 (before `ApplyKeyersForProfile`
  rewrites the port) and starts it after phase 3 (`wkOpen` reads
  `ActiveRadioPtr`); `uTestStatusAndNotice` pins the order.
  `ActiveRadioSettingsChanged(store, which, keyers)` reports an edited keyer
  device (`TAppliedRadioSnapshot.KeyerSlotChanged`, by Id plus
  `TKeyerDefinition.SameDeviceSettingsAs` -- a RENAME is not a change), so
  Save re-applies. **The CW output itself is compared by Id too**
  (`RecordProfileSlot` / `CWOutputChanged` carry `CWOutputNId`; the names
  decide only when either Id is empty -- CAT, NONE, a pre-id profile). Until
  review H6 (2026-11-16) it compared the NAME first, so a rename rebuilt both
  radio links; `Test_ActiveSettingsChangedIgnoresAKeyerRename` records the
  profile slot, which the moved-WinKeyer test never did.
- `logsubs2.ExitProgram` stops it with `wkStop` too (bounded; a timeout logs
  and the exit continues).
- `DescribePortConflicts(store, profile, keyers)` compares the profile's
  WinKeyer port with every radio's CAT port and with the keyer port of a slot
  that names no keyer device. Without `keyers` it is not asked.

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

## An edited memory is an operator statement, and the log keeps it (Q9, Q113)

`LogCW` latches every function-key memory the operator edits.
`TryApplyMessageCommand` latches every branch, CQ or EX, text or caption, and
so do both line-input edits. Since Q113 (2026-10-23) the latch covers the EX
bank and the captions, where Q9 covered only CQ.
- **A CONTEST DEFAULT GOES THROUGH `SetContestDefaultCQMemoryString` /
  `SetContestDefaultEXMemoryString` / `SetContestDefaultEXCaptionMemoryString`.**
  Each of them leaves a latched key alone. A plain `SetEXMemoryString` in a
  default writer overwrites the operator's edit. Worse, the contest log still
  records that key as edited, so the default is pinned at the next open.
- **`ForgetMemoryStatementsOfOtherContests`** (renamed from
  `...CQMemory...`) clears both banks when a different contest is set up.
- **The latch applies; it does not save.** `TryApplyMessageCommand` writes
  nothing to the log. The dialog's OK
  (`uEditMessageForm.ApplyAcceptedMessageEdit`) records the key once, after
  the text and the caption are both applied, and so do `MemoryProgram`'s
  line-input edits (R2, 2026-10-23). **`MemoryProgram` has no caller, and had
  none in D7.** `ParseMessageMemoryCommand` and `MessageMemoryCommand` are the
  name's parse and its inverse. Build a key with `AnsiChar(n)` or
  `AnsiChar(Ord(aChar))`, never by an implicit `Char` -> `AnsiChar`
  conversion: that one goes through the code page and loses #128 and up.
- **The log restores the latched memories at open**
  (`uLogStore.RestoreEditedMessageMemories`, after the contest's set-up).
  `cfgdef.UpdateSAndPF1Caption` runs after that restore, which is why it now
  uses the guarded caption writer.

## Where TR4W starts a transmission (issue #97, 2026-10-26)

The TX-inhibited warning hooks the ONE place each kind of key-up begins, and
nothing per caller: `LogCW.AddStringToBuffer` (every CW message -- F-keys,
autosend start, the keyboard window), `MainUnit.PTTOn` (every PTT TR4W
asserts: CPU keyer, paddle, footswitch port, digital, DVK) and
`logdvp.tsndPlaySound` (a voice message, which covers VOX where `PTTOn` exits
early). `PTTOff` reports the end. Each calls `uTXInhibitView.NoteTransmitStarting`
/ `NoteTransmitEnded`, which marshal (the paddle and footswitch are threads)
and **never raise into the keying path** -- a fault is logged at Error and
keying carries on (`Test_AFaultInTheReviewNeverReachesKeying`). In
`AddStringToBuffer` the call is `NoteCWKeyUp`, inside the two arms that send,
and never for `''` (the sidetone toggle sends one) or the CAT terminator.

**WHICH RADIO A KEYER KEYS IS THE KEYER'S ANSWER: `TCWKeyer.KeyedRadio`**,
nil when it keys none. CW-by-CAT and the WinKeyer follow the swap
(`LogCW.KeyerOutputRadioPtr`: inactive while `KeyersSwapped`); CW-by-CAT also
answers nil when `CATCanKey` says `CWByCATSend` will send nothing. The CPU
keyer is ALWAYS `ActiveRadioPtr` -- it drives the active radio's line and the
port swap in `SetUpToSendOnInactiveRadio` is commented out, as in D7. The YCCC
box keys its own TX radio (`uYCCCSO2R.YCCCTxRadio`). `LogCW.KeyedRadioPtr` asks
`ActiveCWKeyer`. `uTestCWKeyer` pins each adapter both ways and the CAT routing.

**`SendStringAndStop` sends its CAT terminator through `KeyerCAT.SendString`**
(fixed 2026-10-26): it sent it to `ActiveRadioPtr` while the text went to the
swapped radio, and `CWByCATSend` holds a radio's text until ITS terminator, so
the inactive radio's text was never sent. Every other terminator goes through
`AddStringToBuffer`, so it already matched. `TCWKeyerCAT.SendChar` still sends
char and terminator to `ActiveRadioPtr` -- consistent, and unswapped.

`uYCCCSO2R.logger` is assigned at unit load now; it was assigned only in
`YCCCOpen`, so calling `YCCCSetActiveRadio` before the box opened was a nil
dereference (the program only calls it while `ycccActive`).

Autosend characters after the first (`ActiveCWKeyer.SendChar`) and PTT raised
directly through `tPTTVIACATForRadio` (WSJT-X, the TCI server, `TXON`) are NOT
hooked; the radio's own TX report (trigger 2) covers them.

## A speed change or a message end seen on a thread is drawn on the main thread (issue #108, 2026-10-26)

`CodeSpeed` is live shared state and is still set where the change is seen --
the radio poller's CW SPEED SYNC, the WinKeyer speed pot (`SetSpeed`). The
**readout** is not: `DisplayCodeSpeed` assigns `pnlCodeSpeed.Caption` and
stores `SpeedMemory`, so a thread requests `uMainThreadWork.mtCodeSpeedDisplay`
(registered by LOGWIND) and never calls it. **The CW-by-CAT end of message
seen by the poller** sets `CWByCAT_Sending := False` there and requests
`mtCWByCATMessageEnded` (uRadioPolling): on the main thread it stops the busy
timer of any radio no longer sending, then `ReturnInCQOpMode` (auto-call
terminate) and `BackToInactiveRadioAfterQSO` + `tStartAutoCQ`, in the order
the poller used. `tStartAutoCQ` enables an LCL TTimer, which from the poller
was a Win32 timer owned by a thread with no message loop.
`TEventHandlers.OnTimerTick` initialises `callInactive` now (it was read
uninitialised when the tick found nothing sending).

**The keying threads do none of that UI work either (issue #132,
2026-11-04).** Each sets state and requests ITS OWN job, which runs the moved
statements in that thread's original order -- the orders differ, and they
matter: `SwapRadios` (inside `BackToInactiveRadioAfterQSO`) calls
`TryKillAutoCQ`, so auto-CQ-then-swap is not swap-then-auto-CQ. Do not merge
them into `mtCWByCATMessageEnded`.

| thread | job | runs, in order |
|---|---|---|
| `CWThreadProc` end | `mtCWMessageEnded` (LOGK1EA) | `tStartAutoCQ`, `BackToInactiveRadioAfterQSO` |
| `CWThreadProc`, auto call terminate | `mtCWAutoCallTerminate` (LOGK1EA) | `ReturnInCQOpMode` |
| `wkReadThreadProc`, busy bit drops | `mtWinKeyerSendEnded` (uWinKey) | `AutoCallTerminateIsDue` ? `ReturnInCQOpMode` : `tStartAutoCQ`; then `BackToInactiveRadioAfterQSO` |
| `tDVPPlayThreadproc` end | `mtDVPMessageEnded` (LOGDVP) | `tStartAutoCQ`, `DisplayCodeSpeed`, `BackToInactiveRadioAfterQSO` |

- **Each end job is requested as the thread's LAST statement**, after
  `ClearThread` (and LOGDVP's `FillChar`). A CQ that the swap sends must find
  no thread running, or it lands in a ring the exiting thread drops.
- **`tStartAutoCallTerminate` is now `AutoCallTerminateIsDue`, a predicate
  only.** The CW thread asks it, requests `mtCWAutoCallTerminate`, and stays
  alive with PTT up while `CWAutoCallTerminatePending` (the keep-alive loop's
  third term): `ReturnInCQOpMode` clears `tAutoSendMode` BEFORE it appends
  the exchange, so without the wait the thread could exit between the two.
  The flag has three states (none / asked / running): the job sets running on
  entry and none after `ReturnInCQOpMode` returns. **The 2 s deadline covers
  "asked, not yet started" ONLY** (then it logs an Error and stops waiting,
  so a job that never runs cannot hold PTT). A deadline on a running job
  would reopen the very gap: the keep-alive reaches the flag only once
  `tAutoSendMode` is False, i.e. inside `ReturnInCQOpMode`.
  The call-to-exchange gap is now one main-loop turn plus up to 10 ms.
- **DVP draws `DisplayCodeSpeed` inside its own job, not via
  `mtCodeSpeedDisplay`**: it stores `ActiveRadioPtr.SpeedMemory`, and the swap
  after it changes `ActiveRadioPtr`.
- Both `AttachThreadInput` calls those paths made are gone (the WinKeyer
  reader's was never undone). The paddle/foot-switch thread's remains, in
  `tFootSwitchProcedure`, which has no caller.
- **`uAppTimers` reports a timer started or stopped off the main thread**
  (`ReportOffMainThread`, never raises). On Windows a TTimer enabled from a
  thread is a `SetTimer` owned by that thread, so **the auto-CQ repeat armed by
  the CW thread or the WinKeyer reader could not fire** -- moving it to the
  main thread may make auto-CQ repeat where the previous 5.x build did not.
- Pinned by `uTestStatusAndNotice`: the shipped CW thread and DVK playback body
  run to their end with no off-thread report and the timer armed only after the
  drain; a comment-stripped source guard covers the WinKeyer reader and the
  auto call terminate. All fail on the pre-#132 code. Bench: `docs/BENCH_QUEUE.md`.

## Auto-send keys TEXT, not call-window commands (issue 258, 2026-11-11)

While auto-send runs, `CallWindowKeyDownProc` keys each keystroke through
`ActiveCWKeyer.SendChar` -- its ONE caller. What may be keyed is decided there,
once, by `MainUnit.AutoSendKeysCallWindowKey`: not the start-sending-now key
and not the three POSSIBLE CALL keys (read from `Settings.PossibleCall`, never
the literals ',' '.' ';'). **Do not add a filter to an adapter**: the keyer
factory does not know what a possible-call key is. D7 keyed them (a departure,
bench item in `docs/BENCH_QUEUE.md`). Why they had to go: the call field
refuses them (`KeyboardCallsignChar`), so the keyed call differed from the
screen, and each keyer did something different -- CPU keys period/comma and a
bare gap for ';', a WinKeyer keys period/comma/AA (WK3 datasheet Table 14),
**a ';' ENDS a `KY <text>;` command early**, and TCI's server strips it.
Still keyed, open for a ruling: every other character the field refuses
(QUICK QSL KEY 1/2 '\' '=' among them), and `QuestionMarkChar`/`SlashMarkChar`
reach the field substituted but the keyer RAW.

## Open, and decided

**Open (NY4I — design, not refactor):** `ActiveCWKeyer`'s precedence chain
CAT → WinKeyer → YCCC → CPU is an *artifact of the original if/else ordering*,
not a decision. An explicit `CW INTERFACE` setting would make it a lookup,
delete `WarnIfKeyerConfigsConflict`, and turn today's WinKeyer-failed-to-open
downgrade into a refusal. (Since review H5, 2026-11-16, the downgrade is no
longer silent -- a log Error and a notice say it happened -- but CW still
falls through to the next keyer.) TR4QT is the likely reference.

**Phone S&P Enter with the DVK off sends nothing** (`MainUnit.Send_DE`, gated
on DVK ENABLE as in D7; review M10, 2026-11-16, pinned by
`uTestCWKeyer.Test_PhoneEnterWithTheDVKOffSendsNothing`). Issue 66 dropped
the gate and that ran `SendFunctionKeyMessage` on every phone Enter, which
clears `SwitchNext`/`Switch`/`InactiveRigCallingCQ`. Issue 66's actual ask --
a separate S&P CALL message settable to a radio command -- is NOT built.

**Decided — do not re-propose:** Yaesu CW-by-CAT is out of scope. Yaesu's
`KY <n>;` plays a preset memory slot, not free text, so it cannot serve contest CW.

**Gone:** LPT keying, removed 2026-09-13. The YCCC box keeps its capabilities
(OTRSP switching and stereo); only the parallel transport went. Band-decoder
output lapses until OTRSP AUX is wired.

## There is no YCCC box off Windows (issue #141, 2026-10-27)

`uYCCCSO2R`'s non-Windows arm has no HID: `YCCCSetActiveRadio` does nothing and
`YCCCTxRadio` is documented as 1, so `KeyerYCCC.KeyedRadio` is radio 1 on Linux and
macOS whatever it was told. `Test_EachKeyerStatesTheRadioItKeys` asked for radio 2
and failed there; its YCCC half is `{$IFDEF WINDOWS}` now and the other arm pins the
documented 1. Not a product defect: the box is never opened off Windows, so the
chain never selects it.

## Oracle

`.\tr4w\build\Build-Tests.ps1 -Run` covers CW framing and keyer logic, and
the CPU keyer's text-to-element translation (`uTestCPUKeyerRing`). Actual
keying is bench-only — no oracle in this repo proves a rig keys.

**The WinKeyer's wire bytes are pinned without a keyer** (`uTestWinKeyWire`,
P12, 2026-10-18). `wkWriteRaw` takes `const aBytes: array of Byte`; an admin
command is a `TwkAdminCommand` (exactly two bytes, so the D12-era
"every command went out as CALIBRATE" width bug cannot recur); and the
LOAD DEFAULTS value list goes out through `wkValueListBytes`, one wire byte
per field — **not** as the packed record's memory, which had made the
record's field order the wire format by accident. Adding or reordering a
`TwkValueList` field no longer changes what the keyer receives; changing
`wkValueListBytes` does, and the test says so.

## Brace words in a message, and the rover's call (NY4I, 2026-11-20)

**ONE GRAMMAR: `src/uMessageText.pas`** (a leaf, pinned by
`uTestMessageText`). **NY4I's rule: `{` stands for `<03>` and `}` for
`<04>`, nothing more.** A body is any text but a brace and runs exactly as
`<03>BODY<04>` runs (`{SPEED+}`, `{ALT-D}`, `{SRS=PB1;}`); the name (up to the
first `=`) matches in any case, the rest is verbatim. A leading `$` is the
inactive radio, the old Ctrl-A (`{$SPEED+}`). A body is a TOKEN (`ROVERCALL`,
`ROVERQTH`), a COMMAND (every `sCommandsArray` row, registered by
`uProcessCommand`'s initialization -- the old lookup -- plus `QSY` and
`SPEED` + digits or `+`/`-`), or UNKNOWN. **A `{` with no body is still the
cryptic worked call** (`{}`, unclosed, the first `{` of `{{X}}`); the cryptic
characters are text to the parser and `SendCrypticCWString` keys them as
before.

- `FoundCommand` (called first by `SendCrypticMessage`, every mode) runs every
  command -- brace or old `<03>..<04>` -- IN ORDER, BEFORE any text is keyed
  (where bookends always ran), takes out unknown words with a notice
  (`SMessageUnknownWordSkipped`) and leaves tokens for the `'{'` arm, which
  keys them in place and skips (never keys) any other word.
- The chain test in `SendFunctionKeyMessage` is `MessageChainsOrCommands`: a
  Ctrl-D OR a brace command -- a command message has never flushed CW.
- `SetCQMemoryString` / `SetEXMemoryString` convert `<03>X<04>` to `{X}` on
  load (`UpgradeMessageBookends`, byte for byte, a leading Ctrl-A becoming
  `$`); only an unknown name, or a body holding a brace or another control
  character, stays old.
- The Alt-P editor refuses an unknown word; the picker inserts `{NAME}`.
- `\` keys the PLAIN `Settings.My.Call`, always. `{ROVERCALL}` keys
  `uRoverState.RovingCall` (NY4I/KOH while roving), and so do the S&P space
  bar, `DEPlusMyCall`, `Send_DE` and `logsubs2.ProcessExchangeFunctionKey`.
  Never change `Settings.My.Call` itself for a rover.
- `&` and `{ROVERQTH}` key `FCONTEST.SentPlaceNow`.
- Phone (DVP) runs commands but does not expand tokens.

## Coordinate with

`radio-factory` (capabilities, the `TKYRadio` hierarchy) · `tci-interface`
(`cw_macros`) · `serial-port-io` (a WinKeyer owns its own port, distinct from
the CPU keyer's port).
