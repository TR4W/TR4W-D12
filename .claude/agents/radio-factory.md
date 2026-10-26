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
`LogSUBS2.WaitForPollingThreadWithMessages` (pumps sent messages: the poller
can be inside a cross-thread `SetWindowText`, e.g. `DisplayCodeSpeed`), bounded
by `POLLING_THREAD_STOP_TIMEOUT_MS` (6 s, longer than a 5 s connect). On a
timeout the radio is **deliberately leaked**, never freed, and the slot is
cleared BEFORE the stop request is withdrawn -- `pFactoryRadio` leaves its loop
when `rig^.tFactoryObject <> ro`, so a leaked poller cannot become a second
one. `RadioObject.StartPollingThread` is the one place a poller starts.
Pinned by the two `Test_ShutDown*` tests. **`ExitProgram` still waits 3 s
without `InterruptLink`** -- it does not free the radios, so it is not the
same defect, but it is the same blind spot.

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
now and so goes again on every reconnect. The Icom `$27 $15` span read is
still sent only from `StartSpectrum` (its enables are re-sent on connect, its
span read is not) -- same shape, not yet fixed.

**`uRadioPolling.BeginPolling` is `function(aParameter: Pointer): DWORD;
stdcall`** (`TF.TTR4WThreadStart`, pointer audit P1, 2026-10-16) and reads its
RadioObject as `RadioPtr(aParameter)` -- `SetUpRadioInterface` passes `@Self`
as `tCreateThread`'s parameter. It was `procedure(rig: RadioPtr); stdcall`,
which the untyped thread start never checked. Start it bare,
`tCreateThread(BeginPolling, ...)`; `Lint-TypedCodePointers` fails on `@`.

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
CAT, Yaesu binary. Re-confirmed under FPC: K4, K3S, FT-1000MP. **Unproven: Icom
LAN, Yaesu ASCII, HamLib.** Keep `docs/RADIO_BENCH_STATUS.md` current.

## Coordinate with

`cw-keying` (the `TKYRadio` hierarchy, `rcCWByCAT`) · `tci-interface` ·
`serial-port-io` (transports, port identity) · `settings-config` (the radio
library, define-many/activate-one).
