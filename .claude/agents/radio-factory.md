---
name: radio-factory
description: The radio factory — one unit per model under src/radioFactory/, the registry, capability sets, family bases (Icom, Kenwood, Yaesu, Elecraft, Flex, Ten-Tec, HamLib, TCI), reading/polling threads, SO2R, and the radio configuration library. Use for adding or fixing any radio, CAT behaviour, VFO/split/RIT, frequency or mode polling, or radio setup.
tools: Read, Grep, Glob, Bash, Edit, Write
model: opus
---

You own every radio TR4W can talk to.

## Your files

`tr4w/src/radioFactory/` — one unit per model, plus:

| | |
|---|---|
| base class | `uFactoryRadioBase.pas` (`TFactoryRadioBase`) |
| registry — the single source of truth | `uRadioRegistry.pas` |
| factory | `uRadioFactory.pas` |
| SO2R | `tr4w/src/uRadio12.pas` |
| polling | `tr4w/src/uRadioPolling.pas` |
| config dialog machinery | `tr4w/src/uCAT.pas` |
| legacy shell | `tr4w/src/trdos/logradio.pas` |
| docs | `docs/ADDING_A_RADIO.md`, `docs/RADIO_FACTORY_README.md`, `docs/RADIO_BENCH_STATUS.md` |

**Do not write a radio count anywhere.** `.\build\Run-Lints.ps1` prints it via
`Lint-RadioRegistry` on every build; that number is the true one. A written count
here was wrong within a day, twice.

## The two hard rules

1. **A base class must NEVER ask which radio model it is.** The subclass declares
   a trait; the base guards on the trait. Three real defects in one afternoon had
   exactly the shape `if RadioModel in [FT857, FT897]`.
2. **One `RegisterRadio` per unit.** One model, one file, one registration — and
   every model an operator can buy gets its own entry and display name even when
   models share a class (FT-817/818, IC-7850/7851). **A duplicate display name
   makes a model invisible in the radio list.**

## And these

- **No enum-indexed radio tables.** `Lint-NoRadioTables` fails the build if one
  returns. `RadioParametersArray` and `InterfacedRadioTypeSA` were deleted in
  2026-08: being `array[InterfacedRadioType]`, the *compiler* demanded a row for
  every new radio, and the tests then compared the radio against a row someone
  had just invented. They had already drifted — the name table missed `TS140` and
  carried a `TS530` the enum never had, so **a config saying `TS440` selected the
  TS-140 driver** for years. `uRadioRegistry.RadioTypeToken` derives the
  config spelling from the enum, making that drift unrepresentable.
- **Capabilities belong to the radio object** — a `TRadioCapabilities` set plus
  the `DefineCapabilities` virtual. Not a global table. **An override that
  replaces its parent wholesale silently wipes the family's values** (all fourteen
  keying Icoms, once).
- **The legacy path is DELETED, not deprecated.** Never reach for `logradio.pas`
  or `uRadioPolling.pas` to fix radio behaviour. `LOGRADIO` holds no per-model
  knowledge at all now.
- **`uCAT.CATDlgProc` is DEAD — it has no caller.** Do not treat it as the place
  to change radio configuration. What *is* live in that unit: port enumeration,
  the filtered COM drop-down (item data, never index arithmetic), string-id radios
  in the type combo, and `CloseCATAndKeyerForThisRadio`.
- **There is no `RestartPollingThread`** — checked 2026-09-24, no such identifier
  exists. **A radio is never reconfigured in place; it is REBUILT.**
  `CheckAndInitializePorts_ForThisRadio` → `SetUpRadioInterface` →
  `ShutDownRadioInterface` (stop the poller, wait, free) → new object, new thread.
  Its only drivers are `ApplyProfile` and `ResetRadioPorts`. **Anything that
  changes a radio's settings without going through one of those leaves the live
  radio holding its startup values** — that is the IC-9700 stale-credential
  defect of 2026-09-24, where a corrected LAN password sat in the library while
  every reconnection logged `network credentials set` and sent the old one.
- **FREQUENCY POLL RATE IS PER RADIO** (issue 235 step 3, 2026-11-06):
  `TRadioDefinition.FrequencyPollRate` (10..1000 ms, default 10) →
  `ApplyRadioToSlot` → `RadioObject.FrequencyPollRate` → `pFactoryRadio`, which
  reads it through `uRadioConfigStore.ClampFrequencyPollRate` (a never-applied
  slot holds 0, and `Sleep(0)` spins). It drives TWO things, as the global did:
  the loop tick for every non-HamLib radio (the cadence at which polled or
  transceive-pushed state is published), and -- serial + `requiresPolling` +
  `honorsFreqPollRate` only -- the CAT `pollingInterval`. HamLib keeps its own
  50 ms tick. The editor greys the field for HamLib rather than asking the
  driver's trait, because the tick reaches every native driver. There is no
  `Settings.Operating.FrequencyPollRate` any more; the command name is in
  `uCFG.OWNED_BY_A_STORE`.
- **Read the D7 tree at `C:\TR4W` as the authority on old behaviour. Never mirror
  a fix back into it.**

## Threading and link health

Each radio instance runs its own reading thread with exponential-backoff
reconnection (1s → 30s). **An open COM port is not a working link** — serial
radios need a real close/reopen (`MaintainSerialLink`, on the radio, not in the
poller). **A radio can answer CAT before it is ready**: gate post-connect sends on
link *stability*, not presence.

Disconnection sets the `radioWasDisconnected` flag rather than tearing the object
down. Note `TReadingThread` owns its own copy of that flag and holds **no radio
reference** — per-radio reset work belongs in `Connect`.

**THE ICOM LAN TRANSPORT IS WRITTEN AND READ ON SEVERAL THREADS AT ONCE** (D8,
2026-11-05). Its TX history (`TIcomTxHistory`, a ring with its own leaf lock) had
no lock at all: the senders (CI-V queue, timer thread, a reader answering a login)
evicted entries that the Indy listener was reading for a retransmit, and
`uTestIcomTxHistory` crashed the old code. Before adding state to that class, ask
which threads touch it. Still open: `SendTrackedPacket` increments `FSendSeq`
with no lock, from more than one thread. Separately, `uRadioPolling` drains HamLib's
queue through `ro is THamLibDirect` -- the poller asking a radio's class, which
should become a virtual.

**NEVER CALL INDY'S `Connected` FROM OUTSIDE THE READING THREAD.** It is not a
flag read: `TIdIOHandlerStack.Connected` calls `ReadFromSource(False, 0, False)`,
which is a zero-timeout select followed by a **blocking `recv`**, and it appends the
bytes to the `InputBuffer` the reading thread is consuming. The reading thread reads
the same socket with no lock. If the select says "readable" and the reading thread
takes the bytes first, the other thread's `recv` waits for ever. That was the
**main-thread hang of 2026-10-25**, captured in a process dump: a band-map
double-click went to `TK4Radio.SetFrequency`, then `SendToRadio`, then
`socket.Connected`, then `recv`. A bare `Disconnect` is `Disconnect(True)`, which asks
`Connected` first, so it carries the same trap.
- Ask **`SocketIsConnected`** on the base. It reads only fields (`IOHandler.Opened`,
  `not ClosedGracefully`, `Socket.BindingAllocated`) and cannot raise.
- Disconnect with **`socket.Disconnect(False)`**. `DisconnectNotifyPeer` is empty for
  a `TIdTCPClient`, so the only thing `False` drops is the read.
- Detecting a hung-up peer is the **reading thread's** job. It sets `Disconnecting`.
  A write in the gap raises inside `SendToRadio`'s except.
- Pinned by `test/unit/uTestRadioSocketNoRead.pas`: the two `*_DoesNotReadTheSocket`
  tests fail on the old code.
- The same shape is still live **outside** the factory: `uDXClusterClient`
  (`IsConnected`/`SendLine`/`Disconnect` on the main thread against `TDXClusterReader`)
  and `uExternalLoggerBase` (sender path against its `TReadingThread`). `uNetClient`
  already uses a flag for this reason.

**THE RADIO OWNS ITS IOHANDLER; INDY MUST NEVER MANAGE IT** (2026-10-25). Indy's
implicit handler is `ManagedIOHandler`, and a **failed** `TIdTCPClientCustom.Connect`
sets `IOHandler := nil`, which **frees** it (`include/Core/IdTCPClient.pas:338-342`,
`IdTCPConnection.pas:722-726`). `ro.Connect` runs on the polling thread with no lock
while the main thread (`SendToRadio`) and the reading thread (`FConn.Connected`)
dereference `socket.IOHandler` -- a use-after-free on every failed reconnect of a
switched-off radio. `TFactoryRadioBase.Connect` now assigns its own
`MakeDefaultIOHandler(socket)` on first use (owned by the socket component, so not
managed, so a failed connect only Closes it). Also know: `TIdIOHandler.Open` sets
`Opened` **before** the socket connects (`IdIOHandler.pas:866`), so `SocketIsConnected`
is True for the whole `ConnectTimeout` of an attempt in flight; a write then raises
inside `SendToRadio`'s except. Pinned by the two `*FailedConnect*` tests in
`uTestRadioSocketNoRead`. The handler is still made on first use, so a serial or
never-connected radio allocates nothing; freeing the socket frees it.

**THE RADIO DESTRUCTORS RUN NOW, AND THEY NEVER DID BEFORE 2026-10-25.**
`TFactoryRadioBase.Destroy` was `overload; Virtual;` -- a new slot that hid
`TObject.Destroy`, so every `Free`/`FreeAndNil` ran **no** radio destructor (base,
K4, Icom, HamLib, TCI, Kenwood LAN): the memory went, nothing inside it was torn
down. It is `override` with `inherited Destroy` now. Rules that came with it:
- **Every radio destructor is `override` and ends with `inherited Destroy`.** A
  `Destroy; overload; virtual;` anywhere in a hierarchy re-creates the defect.
- **`TFactoryRadioBase.BeforeDestruction` stops the base reading thread** while
  the object is whole: its handler is the subclass's `ProcessMsg`, and destructors
  run most-derived first. It closes the **socket** (a network `ReadLn` has no
  timeout) but **not the serial port** -- a family may have its own writer on it
  (the Icom CI-V send queue), which its own destructor stops first.
- **Close before join.** The old never-run body joined the reader before closing
  the socket, which would have hung on any connected network radio.
- **Teardown is idempotent.** Every caller Disconnects before Free
  (`ShutDownRadioInterface`, `ExitProgram`), so each step runs twice. Shared steps
  are one routine each: `CloseNetworkLink`/`StopReadingThread` (base),
  `StopCIVSendQueue` (Icom), `CloseRig` (HamLib).
- Pinned by `test/unit/uTestRadioDestructors.pas`: Free through a base reference
  reaches the destructor; every registry entry frees, with and without Disconnect
  first; a connected K4 with a live reader frees within a watchdog.
- **A thread's destructor stops and joins it BEFORE freeing what it uses** --
  `TCIVSendThread.Destroy` freed its event, lock and queues first (issue #105).
  Free fields AFTER `inherited Destroy` (which joins, and starts a never-started
  thread so it can finish); that is sound because the instance memory goes in
  `FreeInstance`. Under `-Checked` heaptrc fills freed memory with `$F0`, so a
  virtual call on a freed object AVs every time -- that is how the test sees it.

**A RADIO IS FREED ONLY AFTER ITS POLLING THREAD HAS STOPPED** (issue #104,
2026-10-26). `ShutDownRadioInterface`: `PollingStopRequested`, then
**`ro.InterruptLink`** (close the link from another thread, free nothing -- base
closes its socket; NOT the serial port, a handle race), then
`LogSUBS2.WaitForPollingThreadWithMessages` (pumps sent messages -- no poller
path writes a control since issue #108, but the pump stays as the backstop the
off-thread report cannot be: it reports, it does not stop a write), bounded
by `POLLING_THREAD_STOP_TIMEOUT_MS` (6 s, longer than a 5 s connect). On a
timeout the radio is **deliberately leaked**, never freed, and the slot is
cleared BEFORE the stop request is withdrawn -- `pFactoryRadio` leaves its loop
when `rig^.tFactoryObject <> ro`, so a leaked poller cannot become a second
one. `RadioObject.StartPollingThread` is the one place a poller starts.
Pinned by the two `Test_ShutDown*` tests.
**EXIT GOES THROUGH THE SAME ROUTINE** (issue #107, 2026-10-26).
`ExitProgram` used to keep its own copy -- a 3 s wait it ignored, then
`Disconnect`, no `InterruptLink` -- so a switched-off network radio held exit
for 3 s, and `tr4w_ShutDown` then freed a radio whose poller might still be
inside a 5 s `Connect`. It now calls `LogRadio.ShutDownRadiosForExit([@Radio1,
@Radio2])`: every occupied slot's stop request first, then
`ShutDownRadioInterface(AProgramExit = True)` per slot. **The one exit-only
difference is the panadapter: DETACHED, not closed** (closing records
visible=False and it would not reopen next run). Afterwards both slots are nil,
freed or leaked; everything later on the exit path (`PutAllRadiosIntoReceive`'s
backstop, `tr4w_ShutDown`'s panadapter release and `FreeAndNil`) tests for nil.
Pinned by the two `Test_Exit*` tests. Do not grow a second stop sequence again.

**A STOP OR AN UNKEY ON A RADIO WITH NO LINK IS A NO-OP** (issue #99):
`SendStopToRadio` (debug, not the "Cannot send" ERROR), gated on
`LinkIsOpen` -- transport state only, never "has it answered lately", because a
mute radio may still be keyed. A class that overrides `SendToRadio(s)` with its
own transport overrides `LinkIsOpen` too (Icom, TCI). It sends through the
virtual `SendToRadioUrgent` (base: `SendToRadio`; the Icom overrides it to jump
its CI-V queue). **Every driver's `StopCW` and `Receive` now goes through it**,
and that is asserted over the WHOLE REGISTRY, not driver by driver:
`uTestRadioDestructors.Test_EveryRegisteredRadio_StopAndUnkeyWithNoLink_LogNoError`
builds every entry on every link it claims, places it on that link without
connecting, and fails on any exception or ERROR line. A new driver that sends
its stop unconditionally fails there by name. A byte-frame stop builds its
frame and hands it over (`TYaesuBinary.Frame5`, `TFlexAPI.FlexCmdLine`) rather
than growing a second send path.

**A QUESTION ASKED AT CONNECT BELONGS IN THE DRIVER'S `Connect`, NOT IN A UI
PATH.** The K4's spectrum socket connects before its CAT link, so `#SPN;` sent
from `StartSpectrum` was dropped at every start; it is in `TK4Radio.Connect`
now and so goes again on every reconnect. **The Icom's `$27 $15` span read had
the same shape and is fixed (issue #106):** `TIcomRadio.CIVStreamOpened` (the
`icsConnected` arm of `OnNetworkStateChange`, so first connect and every
reconnect) re-sends the scope enables AND asks the span whenever
`SpectrumAvailable`, window open or not. The read is one routine,
`RequestScopeSpan`, shared with `StartSpectrum` and `SetSpectrumSpan`.
`CIVStreamOpened` is protected so `uTestIcomScopeSeam.Test_SpanIsAskedOnEveryLinkUp`
can play a link-up on a real IC-9700 whose `SendToRadio` is a list. Inside an
Icom, `RadioAddress` is the CI-V byte and hides the base's host --
write `TFactoryRadioBase(Self).radioAddress`.

**THE PANADAPTER'S DISPLAY NUMBERS BELONG TO THE RADIO (2026-11-02).** Default
scale, slider range, margin under the reference, waterfall share and whether the
levels are real dB are a `TSpectrumDisplayDefaults` (`uSpectrumTypes`) from the
virtual `SpectrumDisplayDefaults(sourceId)`. Base answers the neutral, INVALID
all-zero record; `TK4Radio` and `TIcomRadio` (gated on `rcSpectrum`) state
80 / 10..150 / 10 dB / 0.5 -- the constants `uPanadapterForm` used to hold, the
Icom's a deliberate copy. **A new spectrum driver must override it**:
`uTestSpectrumDisplayDefaults` walks the registry and fails by name on an
`rcSpectrum` radio with an invalid record, on a non-spectrum radio stating one,
and on any `rcSpectrum` radio not equal to the pre-move constants (update that
pin deliberately when a radio's display is tuned). The window refuses an invalid
record with an ERROR rather than borrowing numbers. Details:
`docs/PANADAPTER_LCL_DESIGN.md` section 10.1a.

**WHAT THE RADIO SAYS ITS DISPLAY IS SET TO IS RADIO STATE TOO (2026-11-02,
stages 1-2).** Distinct from the defaults above: a
`TSpectrumRadioState` (`uSpectrumTypes`) of LIVE values -- REF, scale, AutoRef
and offset, waterfall share, averaging, colour range, colour mode -- each with its own `Has`
flag, plus a `Generation` that moves on every accepted report (repeats too),
never back to 0 (there is no reset any more -- see below). "Nothing known" is `SpectrumRadioStateKnowsNothing`
(the flags), NOT record equality. Virtual `SpectrumRadioState(sourceId)`; base
answers unknown, the Icoms/Flex inherit it. `TK4Radio` decodes the `#` reports
with the pure leaf `uK4DisplayReport` (on the reading thread, under its own
`FDisplayStateLock`, returned by value; `A` = main/`#REF`, `B` = sub/`#REF$`,
others unknown), ~~resets at the TOP of `Connect`~~ **HOLDS IT ACROSS A
RECONNECT (NY4I, later 2026-11-03): `Connect` clears nothing and
`ResetK4DisplayState` is deleted** -- a value stands until the radio reports a
new one; only a NEW `TK4Radio` (a different radio, a profile change, Reset
Radio Ports) starts from nothing. It asks `K4_DISPLAY_QUERIES` on its own line
beside `#SPN;`.
**Reads only: never send a `#REF` value (it freezes AutoRef) or `#AR0;`/`#AR1;`/
`#AR9;` (sets)** -- pinned by `Test_DisplayStateAskedOnConnect_ReadsOnly`.
Whether the K4 pushes `#SCL`/`#WFH`/`#WBS`/`#WFC`/`#AVG` is unverified
(`docs/BENCH_QUEUE.md`). Details: `docs/PANADAPTER_LCL_DESIGN.md` section 10.3.

**THE WINDOW FOLLOWS THE K4'S LCD WATERFALL (2026-11-03, NY4I) -- through a
SECOND, NEUTRAL virtual, never `SpectrumRadioState` itself** (radio units).
`SpectrumLiveDisplay(sourceId)` returns a `TSpectrumLiveDisplay`: waterfall
share 0..1 inclusive, colour floor as a fraction of the scale, a
`TSpectrumPaletteTone`, each with a `Has` flag. Base: unknown. `TK4Radio`
translates with the pure `uK4DisplayReport.K4LiveDisplay` from `#WFH`, `#WBS`
(floor = WBS/40, QK4's UNVERIFIED photographic fit -- `K4_COLOUR_FLOOR_DIVISOR`)
and `#WFC` (parsed as plain `#WFC`, NOT the manual's `#WFC$`, which the radio
does not answer). **LCD only**: `#HWFH`/`#HWBS` reach no window and `#HWFC` is
not decoded. The window (`ApplyLiveDisplay`) applies a value only when it
CHANGES -- never on `Generation`, which AutoRef's `#REF` pushes move several
times a second. Unknown = the defaults exactly. `SpectrumDisplayDefaults` is
unchanged. A registry walk pins that every fresh radio claims nothing.
Details: `docs/PANADAPTER_LCL_DESIGN.md` section 10.5.

**AND THE REFERENCE, AND A REAL BLUE (later 2026-11-03).** `TSpectrumLiveDisplay`
also carries `RefDb` and `ScaleDb`, each with a `Has` flag that
`SpectrumLiveDisplayKnowsNothing` counts: `#REF` for pan A, `#REF$` for B, the
one `#SCL` for both, Y nothing. The window's policy is two pure functions in
`uSpectrumTypes`: `SpectrumTraceFloorDb` (REF exactly, no margin -- QK4's
`minDb = refLevel` -- else noise floor less `RefMarginDb`) and
`SpectrumReferenceDb` (what a waterfall row is stored against). **REF is never a
re-colour trigger**: a row keeps the reference it was captured with, so AutoRef's
pushes reach new rows only (QK4 `da384ee`, same reason). ~~**`#SCL` is carried and
NOT drawn**~~ **A CHANGED `#SCL` MOVES TR4W'S SCALE SLIDER, AND TR4W NEVER WRITES
IT** (NY4I's option (b), still later 2026-11-03). The palette's rule: apply only
on a change (`uSpectrumTypes.SpectrumRadioScaleChanged` /
`SpectrumScaleAfterReport` / `SpectrumClampScaleDb`, pure), the operator's drag
stands until the rig reports a DIFFERENT value, `FScaleFromRadio` (twin of
`FPaletteFromRadio`) sends a radio switch back to the default. Set with
`SetParams`, never `Position` -- `OnChange` is the operator's path. The K4's
10..150 is written once, in `uK4DisplayReport` (`K4_SCALE_MIN_DB`/`MAX_DB`);
`uRadioElecraftK4`'s pair now names those. QK4's control WRITES `#SCL` --
option (a), not taken. Design doc 10.6. **QK4 has ONE
waterfall colour table** whatever `#WFC` says, so TR4W's `Blue` palette (index 5,
appended) is TR4W's own design; Fire-Ice is the operator's only. Details:
`docs/PANADAPTER_LCL_DESIGN.md` section 10.6.

**THE K4 MAIN PAN IS CROPPED TO `#SPN` BY THE RADIO (2026-11-03, NY4I).**
`TK4Radio.HandleSpectrumFrame` passes B, Y and Z through. It crops A with the
pure `uSpectrumTypes.SpectrumCropCentred`, which is exact (bin Hz unchanged
to the Hz), keeps a count in steps of 750 Hz nearest `#SPN`, and never keeps
more than 2048 - 2 x `K4_EDGE_GUARD_BINS` (49, the worst pad measured). The
result goes into a radio-owned buffer that is reused frame after frame. The
window does not crop. `DecodeK4Frame` stays a faithful wire decode. Unknown
`#SPN`, or one not narrower than the frame, passes through. The K4 serves
fixed frame widths (24/48/96/192/384 kHz) with a fixed ~40+3 bin pad per
edge. Pinned by `uTestK4SpectrumCrop` against two real captures. Details:
`docs/PANADAPTER_LCL_DESIGN.md` section 10.4.

**TX INHIBITED IS A RADIO CONDITION CARRIED IN THE STATUS (issue #97, phase 1,
2026-10-26).** A radio that can say "I will not radiate when keyed" declares
`rcReportsTXInhibit`; its parser calls the base's protected
`SetTXInhibited(on, reason)` with the radio's own words. The base refuses an
ON from a radio that has not declared the trait (ERROR once) -- the guard is
the trait, never the model. `TFactoryRadioBase.Connect` clears it (a new link
says nothing yet). The pair is guarded by its own `FTXInhibitLock`, not
`SocketLock`: written on the reading thread, read on the polling thread.
- **The status carries it**: `RadioStatusRecord.TXInhibited` +
  `TXInhibitReason`, copied by `LogRadio.CaptureTXInhibit` beside `TXOn` in
  `pFactoryRadio`, compared in `RadioStatusDiffers`. The reason is
  `TTXInhibitReason = string[31]`, a ShortString **on purpose**: the record is
  block-copied (seqlock snapshot, `scExchangeRadios`' `CopyMemory`) and
  `FillChar`-zeroed, so a managed `string` there would be copied without its
  refcount. A ShortString's `<>` compares content up to its length byte, never
  the stale bytes past it (pinned).
- **The program's read is `LogRadio.RadioTXInhibited(rig, out reason)`**, from
  the SETTLED status (`ReadRadioStatus`), the same snapshot `TXOn` is taken from
  for `PTTStatusChanged`. Nothing above the factory reads the driver.
- **The K4** parses `TSn;` (0 off, 1 on, reason `"TX test mode"`), asks `TS;`
  in `Connect` and from `PollRadioState` every `K4_TX_TEST_POLL_MS` (5 s) on its
  own clock -- NOT appended to every `IF;`. Whether it PUSHES `TS` under
  auto-info is unverified (`docs/BENCH_QUEUE.md`); do not claim it does.
- **Only the K4 declares it**, pinned by a registry walk
  (`uTestTXInhibit.Test_OnlyTheK4DeclaresTheTrait`). The K3/K3S/KX have no
  documented equivalent: Hamlib's `rigs/kenwood/k3.c`/`elecraft.c` carry no TX
  TEST read, and `uRadioElecraftSerial` already notes `TQ` reports TX TEST as
  transmitting rather than as a separate state. Candidates not wired: the Flex
  API's `interlock` reason (`uRadioFlexAPI.ProcessInterlockStatus` reads only
  `state`), the IC-7610's `$16 $66`, the FT-990/FT-1000D read-flags inhibit bits.

**`uRadioPolling.BeginPolling` is `function(aParameter: Pointer): DWORD;
stdcall`** (`TF.TTR4WThreadStart`, pointer audit P1, 2026-10-16) and reads its
RadioObject as `RadioPtr(aParameter)` -- `SetUpRadioInterface` passes `@Self`
as `tCreateThread`'s parameter. It was `procedure(rig: RadioPtr); stdcall`,
which the untyped thread start never checked. Start it bare,
`tCreateThread(BeginPolling, ...)`; `Lint-TypedCodePointers` fails on `@`.

**THE SPLIT TX VFO IS THE RADIO'S ANSWER, NOT 'B'** (issue 38, 2026-11-08).
The `-` entry writes the TX frequency to `RadioObject.SplitTransmitVFOLetter`,
which asks the virtual `SplitTransmitVFO` (base: `nrVFOB`, the old fixed
answer). Only `TKenwoodTS890Radio` overrides it, to the VFO it is not receiving
on (`FR`). The entry then calls `PutRadioIntoSplitTransmittingOn(letter)` ->
virtual `SplitTransmittingOn` (base: `Split(True)`, refuses anything but B);
`TKenwoodLAN` sends `FT` for that VFO. **A plain `Split(True)` stays `FT1;`**:
the band-map QSX, WSJT-X and the TCI server write B then call it, and following
the receive VFO there would transmit on A -- the DX's frequency for a QSX click.
`Split(False)` sends `FT` for the receive VFO (safe for every caller). Those
three callers are still A-centric for a TS-890 receiving on B; routing them is
follow-up work (TCI: with `tci-interface`). The TS-990 shares the LAN base and
deliberately keeps B. Pinned over the whole
registry by `uTestKenwoodLANSplit` (receive VFO set to B first, or the pin
proves nothing). **Flex still assumes A receives**: `TFlexAPI` never reads a
slice's `active=`, so its override needs active-slice tracking first.

## Before any "behaviour-preserving" swap

Prove equivalence **in both directions**, and expect the first check to say no.
Replacing `IcomRadiosThatSupportRIT` with `HasCapability(rcReadRIT)` looked
trivial, but no Icom *model* unit declares `rcReadRIT` — it is set once on the
family base — so the naive substitution would have disabled RIT clear for every
Icom. It was made only after comparing both sets and getting 13 vs 13 with an
empty difference.

## Oracles

```powershell
.\tr4w\build\Build-Tests.ps1 -Run     # CI-V, Kenwood, Yaesu ASCII/binary, Elecraft IF, Flex, HamLib IDs, registry taxonomy, capability pinning
.\build\Run-Lints.ps1                 # Lint-RadioRegistry, Lint-NoRadioTables, Lint-PollRadioState
```

**ASK THE RADIO BEFORE YOU ARGUE FROM THE CODE.**
`tr4w/test/bench/bench_icombands.lpr` connects a networked Icom and prints which
bands it says it has, raw payloads and decode both. It is read-only, it tears
its session down cleanly, and it takes credentials only from the command line.
It settled "can a radio enumerate its own bands" in eight seconds after code
reading could not, and in the same run exposed a false `$1E`-unsupported log
line that no compiler, lint, test or corpus could have seen — that class of
defect needs a radio that answers. Reach for it (or write its sibling) rather
than a throwaway. `bench_icomscope` is the same idea for the bandscope, but it
DOES touch the radio. **`FullBuild.ps1` builds both** (through `Build-Bench.ps1`,
after the unit tests), so a driver change that breaks them fails the build.

`tools/radiosim` **proves things about TR4W, not about radios** — when a driver
and the simulator disagree, suspect the simulator first.
`C:\Users\toms\projects\Hamlib` (`rigs/` backends, *not* `simulators/`) is the
independent reference.

**Bench status is the honest gate: one verified rig per protocol family.**
Verified under Delphi: Elecraft serial/network, Kenwood serial, Icom serial, Flex
CAT, Yaesu binary. Re-confirmed under FPC: K4, K3S, FT-1000MP. **Icom LAN: the
link is proven on TWO models only** -- IC-7760 and IC-9700, a 7 h 52 m soak under
FPC on 2026-09-27 (transport as of `38fd77b5`; changed since, not re-soaked); CW,
PTT and split over LAN, and every other LAN Icom, are not. **Unproven: Yaesu
ASCII, HamLib.** Keep `docs/RADIO_BENCH_STATUS.md` current.

## Coordinate with

`cw-keying` (the `TKYRadio` hierarchy, `rcCWByCAT`) · `tci-interface` ·
`serial-port-io` (transports, port identity) · `settings-config` (the radio
library, define-many/activate-one).
