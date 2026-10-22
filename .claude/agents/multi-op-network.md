---
name: multi-op-network
description: Multi-operator networking — TR4WServer, the client link, the binary packet protocol with CRC32, log synchronisation, serial-number lockout and time sync. Use for anything about multi-op, networked stations, the server, packet framing, or station-to-station log comparison.
tools: Read, Grep, Glob, Bash, Edit, Write
model: sonnet
---

You own the link between stations at a multi-op.

## Your files

| | |
|---|---|
| the server — its own `.lpr` | `tr4w/tr4wserver/` |
| client socket + password handshake | `tr4w/src/uNetClient.pas` (`TNetClient`) |
| message dispatch | `tr4w/src/uNet.pas` |
| framing | `tr4w/src/uNetFraming.pas` |
| engine side | `tr4w/src/trdos/lognet.pas` |
| server log sync | `tr4w/src/uGetServerLog.pas`, `src/ui/lcl/uServerLogForm.pas` |
| CRC32 packets | `tr4w/src/utils/networkmessageutils.pas` |
| analysis | `docs/TR4W_NETWORKING_ANALYSIS.md` — **read the provenance block first** |

**That analysis is TR4QT's, copied whole.** Three of its V1 claims were checked
against this tree and **do not hold**, and the V2 design in it is TR4QT's, not a
plan for this repo.

## Known-broken, deliberately

**MULTI-OP LOG COMPARISON DOES NOT WORK AND SAYS SO.** It compared a CRC32 of raw
`.TRW` bytes at both ends; this station no longer keeps a `.TRW` and the server
still does. `uNet.ProcessServerLogInfo` **refuses rather than guesses** — it logs
an error once per session and compares nothing.

That is correct behaviour, not a regression to diagnose. Reporting "identical"
would tell an operator their log matches when nothing was checked; reporting
"different" would resynchronise on every connect against a log this build cannot
read. *"Are these two logs the same"* belongs to the new multi-station protocol
and will be asked over **rows**.

## The contest byte on the wire (Q108 S2, 2026-10-16)

`ContestExchange.ceContest` and `TLogFileInformation.liContest` are a
`TContestHandle` now, not the `ContestType` enum -- ONE byte at the same
offsets (265 of 376; 18 of 19), pinned in `uTestLogBinaryFile`. A legacy
contest's handle IS its legacy number, so a D7 peer, the server's log and
the log-compare packet read exactly what they did. The server still links
no contest-factory unit (it uses `NoContest` from `VC`) and needed no change.
A contest with no legacy number (Q108 S3, registered by id) must never reach
these records, and **since Q108 S4 (2026-10-17) it cannot**: the V1 packet is
NOT being converted (NY4I), so every door is a GUARD -- one predicate,
`uContestRegistry.ContestCanUseMultiOp`, one message, `SContestNotOnMultiOp`,
and `uNet.NetCarriesContest` as the logging wrapper. The doors, all in `uNet`:
`TryConnectToNetwork` (before any thread; said once per contest, silent on the
5 s retries) and `ConnectToTR4WServer`; `NetContestChanged` (from
`uSettingsEffects`' CONTEST arm, which drops a live link); `PeerContestRefusal`
in the `NET_PARAMETER` arm (a peer's CONTEST naming one is NOT applied);
`SendRecordToServer` (the one place every QSO, edit and offline resend goes
out); and the `NET_QSOINFO` / `NET_EDITEDQSO` arms (a byte with no legacy
number is dropped, whole). **Do not add a record path that writes to the
socket without going through `SendRecordToServer`.** A unit test reaches the
predicate, the wrapper, `PeerContestRefusal`, `TryConnectToNetwork`'s
refusal and a source read of every door; the live link is two machines and a
BENCH_QUEUE item.

## Peers must be on the same contest (Q110, NY4I 2026-10-18)

*"Peers have to be on the same contest and that is a flagged error to be
reported."* `uNet.PeerRecordInOurContest(rec, door)` is asked by the
`NET_QSOINFO` arm (QSO, note and QTC records) and the `NET_EDITEDQSO` arm,
after `NetCarriesContest`: a record whose `ceContest` is not this station's
`Contest` is dropped whole -- not logged, scored or applied. It is REPORTED,
not silent: a `logger.Error` per record (the audit trail, not rate-limited)
and one `QuickDisplay` notice (`SPeerOnAnotherContest`) per peer and per peer
contest per link session (`ForgetPeerContestNotices` runs when the link
comes up). The wire is untouched. Those two arms are the only places a
received QSO is logged or edited -- do not add a receive path that skips
the check. `tr4wserver` relays and stores every QSO whatever its contest
(one binary server log, `ceContest` read only for the compare header); the
check is the client's. Tests: `uTestContestById` (the judge, the arms fed
through `NetBuffer` by `ConsumeNetBuffer`, now in `uNet`'s interface, and a
source-order read).

## What a received QSO records about OUR station (log schema 3, stage 5, 2026-10-19)

A peer's QSO (`NET_QSOINFO`, then `LogContact`, then `tAddQSOToLog`) is
stamped with THIS station's MY_ values and marked `my_source = 'assumed'`
(ruling D). The store tells it from ours by the record's computer id. It
stores NO `exchange_sent`: the V1 packet carries the peer's serial
(`NumberSent`, kept) but not its CQ template, so our template would be
invented text. A `NET_EDITEDQSO` edit changes the QSO's fields and leaves
the station and the sent exchange as they were. Nothing here changed the
wire or `uNet`. Detail: `docs/SQLITE_LOG_SCHEMA_PLAN.md` section 12h.

## Worker threads and the log-compare record (pointer audit P1/P2, 2026-10-16)

`uNet.ConnectThread` and `uGetServerLog.RunSyncThread` are
`function(aParameter: Pointer): DWORD; stdcall` (`TF.TTR4WThreadStart`) and
are started BARE -- `tCreateThread(ConnectThread, ...)`, never `@ConnectThread`,
which Delphi mode passes unchecked (`Lint-TypedCodePointers`). They were
parameterless procedures until 2026-10-16, which on i386 corrupted the
thread's SEH chain head at exit (`docs/POINTER_AUDIT.md`, D2).
`ShowLogCompare` takes `PLogFileInformation`, not an `lParam` filled with
`integer(s)` -- that cut the pointer in half on x86_64.
`Lint-PointerTruncation` keeps the integer form out. (The dialog is still
unreachable: `ProcessServerLogInfo` compares nothing, as above.)

## The transport, and its one sharp edge

The client is **Indy**, not Winsock. `uNet` used to drive a raw socket and have
Windows deliver events as a **window message** (`WSAAsyncSelect`), so the network
window *was* part of the transport. `NetSocket` is gone — ask `NetIsConnected`.

Parsing still runs on the **main thread**: the reader appends bytes under a lock
and `Application.QueueAsyncCall`s a drain, so every message arm is unchanged.

**The short tail is KEPT between reads — so an unrecognised message id must NOT
be**, or the same bytes re-parse forever and the link wedges in silence.
`ConsumeNetBuffer` reports that case and the drainer resynchronises loudly.

## The console/LCL boundary — the only guard is the server build

`tr4wserver` is built by `FullBuild.ps1` as a normal step. **Never suggest
`-SkipServer`**: that build is the only thing holding the boundary. It went
undetected for three days when a `TF` → `uCrashLog` → `Forms` edge dragged the
LCL into a console program, then stayed hidden for six more behind `-SkipServer`.

The fix was to split `uCrashLog`: the RTL reporter links anywhere, and the two
statements needing a widget set live in `src/ui/lcl/uCrashLogLCL.pas`. **A
`{$IFDEF FPC}` cannot help here** — it asks which *compiler* when the question is
which *program* has a widget set. Only the unit graph can answer that.

Note `Get-SearchPaths.ps1` now **does** give the server LCL paths (`uServerForm`
lives there), so the search path is no longer the guard it once was. The build
step is.

## Oracle

```powershell
.\tr4w\build\Build-Server.ps1
.\tr4w\FullBuild.ps1            # never -SkipServer
```

Real multi-op behaviour is bench-only — two machines, or it is unproven.

**`uNetFraming.NextNetMessage` has no caller in the program** (found in
pointer audit P12, 2026-10-18; no commit ever had `uNet` or the server call
it). `uNet.ConsumeNetBuffer`'s walk asks only `NetMessageSize` and repeats the
partial-message test itself, so `uTestNetFraming`'s walker pins cover a
routine the link does not run. It takes an open array now and refuses to read
past its buffer. Wire one in, or delete it, when the V1 walk is next touched —
not as a side effect. **The record senders (`SendToNet`, `sSend`,
`SendToClient`) keep their untyped buffer on purpose**: each caller hands in
a packed V1 record and that parameter is where its layout becomes the
encoding (P14, skipped for V1).

`tr4wserver.ini` belongs to a different program and is out of scope for the JSON
settings work.

## Coordinate with

`log-database` (row-level sync is the destination) · `contest-scoring` (dupes,
mults and serial lockout cross the link) · `lcl-ui` (`uServerLogForm`) ·
`build-release` (the server is a separate build target).
