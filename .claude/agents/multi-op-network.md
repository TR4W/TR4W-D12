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
| the HELLO message, protocol version, per-station contest table | `tr4w/src/uNetHello.pas` |
| the link as a state, the Net-menu rules, the startup rule, the observer list | `tr4w/src/uNetLink.pas` (a leaf: no sockets, no widget set) |
| the Network window (a VIEW of the link) | `tr4w/src/ui/lcl/uNetworkForm.pas` |
| a probe that speaks the protocol to any server | `tools/netprobe/` |
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

## Network protocol 2: HELLO, and every contest travels (2026-10-27)

NY4I: *"D7 (4.x) NEVER joins a 5.x network. V1 may change."* and *"ALL contests
must work on the network, including those registered by id."* The wire is
**protocol 2** now. `d7-protocol` is the git tag on TR4WServerPy that last spoke
V1 (98-byte spot, letter-coded disconnect, COMPUTERID first, no HELLO); a V1
station and a protocol 2 server refuse each other, and say so.

**`uNetHello.pas` (a leaf: sockets-free, so it is unit-tested) holds the whole
of it.** `NET_HELLO_ID = 1150`, `THelloMessage`, packed, **70 bytes**, pinned in
`uTestNetWireSizes` and `uTestNetHello`:

| offset | field |
|---|---|
| 0 | `hmID` Word = 1150 |
| 2 | `hmProtocol` Word = `NET_PROTOCOL_VERSION` (2) |
| 4 | `hmComputerID` Byte, 1..26; **0 is the SERVER's own HELLO** |
| 5 | `hmReserved` Byte |
| 6 | `hmAppVersion` 16 chars, NUL padded |
| 22 | `hmContestId` 48 chars, NUL padded; `''` from the server |

The rules, identical in `tr4wserverUnit` (`MessageAllowedNow`, `AcceptHello`)
and in TR4WServerPy (`_require_hello`, `_accept_hello`):

- The client sends HELLO right after the password (`ConnectThread`, `SendHello`)
  and no longer sends COMPUTERID: the HELLO carries the id, and the server
  judges it with the same rule (`SetComputerID`, first come first served, own
  slot ignored). Anything else first is a log line (`first message was not
  HELLO ... a 4.x client?`) and the connection is dropped (`DropRequested`, read
  by `uServerNet.SyncParse`; the connection thread does the closing).
- Versions must be **equal** (`JudgeProtocol`). A different one is sent
  `SM_PROTOCOL_MISMATCH` (8330, `smParam` = the server's protocol) and dropped;
  the client turns that into `SNetServerProtocolOlder` / `Newer`, once per
  address and port (`FServerRefusedFor`; Net > Connect or Reconnect re-arm it
  through `NetLinkConnect`, which calls `ForgetServerRefusal` -- that also
  forgets a refused computer id. Opening the Network window no longer does).
- The server answers a first HELLO with its own (id 0) **before** judging the
  computer id, so a station refused for its id has seen the protocol.
  `FServerHelloSeen` / `FHelloSentTick`: a link that drops within 5 s of our
  HELLO with no server HELLO is reported as "probably an older server"
  (`SNetNoHelloAnswer`): an older server cannot say anything a station could
  read.
- **Relay, not a separate message.** The server keeps each accepted HELLO in its
  slot (`clHello`), tells a newcomer every other station's, and relays a station's
  HELLO to the rest. A contest change is therefore just another HELLO
  (`NetContestChanged` -> `SendHello`), with no message type of its own, and the
  server stays contest-agnostic: it stores and forwards text, it never judges a
  contest. A pull (answering `SM_GETSTATUS`) was rejected: the server already
  holds the state and a station that is silent would leave a hole.
- Only an ACCEPTED hello is kept and relayed, so a station refused for its id
  never appears to the others. The server sends it nothing more than the 8320.

**Contests are agreed by ID STRING, never by the byte.** `ContestCanUseMultiOp`,
`MultiOpRefusalText`, `SContestNotOnMultiOp`, `NetCarriesContest` and
`PeerContestRefusal` are GONE (Q108 S4's six doors). `uNet.GPeers` (`TNetPeers`)
holds what each station announced; `PeerRecordInOurContest(var rec, sender,
door)` asks `uNetHello.JudgePeerContest` (case-insensitive id compare), then
**stamps `rec.ceContest := Contest`** on an accepted record, so a by-id handle
(assigned at the registry seal, different between builds) is never stored from
the wire. A sender that never said HELLO is refused and logged (Error, no
notice); a sender on another contest is refused, logged per record and noticed
once per (station, contest id) per link (`SPeerOnAnotherContest`,
`ForgetPeerContestNotices` at link-up). `GPeers.Clear` runs at link-up, and the
`SM_DISCONECT_CLIENT` arm forgets a departed station.

**`TNetQSOInformation.qiSenderID` (was a reserved byte, always 0) names the
STATION THAT SENT THE PACKET**, ordinal 1..26, set in `SendRecordToServer`. It is
NOT `ceComputerID` (who logged the QSO): an edit is sent by whoever edited, and
the QSO's logger may have left. The receiver judges the packet by what THAT
station announced. **Do not add a record path that writes to the socket without
going through `SendRecordToServer`**, or the packet has no sender and is
refused. The sender leaves `ceContest` as its own handle; nothing reads it.

Every received QSO is still logged or edited in exactly two places (the
`NET_QSOINFO` and `NET_EDITEDQSO` arms), both behind `PeerRecordInOurContest`;
do not add a receive path that skips it. Tests: `uTestNetHello` (layout, build
and refusals, the version judge, the table, the contest judge, framing),
`uTestContestById` (a by-id and a legacy peer accepted and restamped, the byte
never read, case, no HELLO, a departed station, a re-announcement, the notice
latch, source reads of the wiring), `tools/netprobe` `--case hello` against both
servers. The live link (a real client against a real server, a contest change,
an old server) is two machines and a BENCH_QUEUE item.

Also changed in the same pass, in the Python server (parity with this tree's
server): the DX spot is **106** bytes, `SM_DISCONECT_CLIENT` carries the
ordinal 1..26 (not the ASCII letter), and a duplicate computer id is refused
with `SM_COMPUTERID_IN_USE`; its computer id is no longer taken from
`TStationState`, which let a refused station take the id it was refused.

The server's own log holds each sender's `ceContest` byte as it came (a by-id handle means nothing outside the program that wrote it), and the log-compare packet reads the first record's. Neither is judged; a late catch-up that reads that log must restamp, as the receive arms do.

## The link belongs to the program, not to the Network window (2026-10-27)

NY4I: *"I never liked the idea that we only connected when the Network window
was up."* Until then `TryConnectToNetwork` had two callers, both in
`uNetworkForm`, and closing the window dropped the link. Now:

- **Who wants a link:** `GLinkWanted` (uNet), the operator's wish for this
  session. `NetLinkConnect` / `NetLinkReconnect` (Net menu) and `NetLinkStartup`
  set it; `NetLinkDisconnect` clears it. It is not persisted.
- **Startup rule:** `uNetLink.ShouldConnectAtStartup(Network.AutoConnect,
  Computer.Id)`. The setting is `NETWORK AUTO CONNECT`, default **False** on
  purpose: `SERVER ADDRESS` defaults to LOCALHOST, so a default of True makes
  every single-operator station knock on its own door for ever. A blank computer
  id never connects at startup; Net > Connect with no id opens Preferences at
  COMPUTER ID (`SetCommand`) instead.
- **Who retries:** the `atNetReconnect` app timer (`NetLinkTick`, main thread,
  `Network.StatusUpdateInterval`), running only while a link is wanted. It was
  the Network window's `tmrStatus`.
- **State:** `NetLinkState` = `ResolveLinkState(wanted, connected, connecting
  (ThreadStarted(NetThreadID)), refused (NetLinkRefused))`. Off, Connecting,
  Connected, Waiting (wanted, down, the timer is retrying), Refused (latched,
  nothing retried). `LinkCommandEnabled` says which of Connect / Disconnect /
  Reconnect / Show window each state offers; `LinkNeedsLiveLink` is the rule for
  the rows that send to other stations (set time, send message, synchronize,
  the clear rows).
- **The Net menu** (top-level, always enabled; the old `EnableNetworkMenuItem`
  greyed all of it and is gone): `ApplyNetworkMenuState` /
  `ApplyNetworkMenuStateFor(state)` enable each row. ProcessMenu arms:
  `menu_net_connect/disconnect/reconnect/showwindow` (VC ids 10520-10523);
  `MainUnit.ShowTR4WWindow` shows and fronts a tool window and never closes it.
- **Who is told:** `uNetLink.NetLinkObservers`, a list of `TNotifyEvent`. The
  window adds a method in `HandleCreate` and removes it in its destructor; the
  link never holds a form. `NetLinkChanged` may be called from ANY thread (the
  connect thread does) and hops to the main thread with `QueueAsyncCall`; it
  re-applies the menu and notifies. `ShowConnectionStatus` keeps the last status
  line (`GLinkOperation`, under `GNetLock`) and the window's title is
  `NetWindowCaption` -- the worker thread no longer writes the form's Caption.
- **A window opened mid-session** missed every status message, so
  `TfrmNetwork.RefreshFromLink` (called from `HandleShow`) takes the title from
  `NetWindowCaption` and calls `DisplayAllClients`, which redraws every station
  in `StatusArray` through `DisplayClientField(Index, type)` (the old
  `DisplayClientStatus` body with the type as a parameter). A station that left
  is blanked across ALL columns (it used to leave the D flag and the operator).
- **Cancelling a connect in flight:** `NetLinkDisconnect` while the connect
  thread is running only clears the wish (the client is the thread's until it
  returns); `ConnectThread` drops a link nobody wants before it ends.
  `NetLinkReconnect` is refused while connecting.
- **Dropped/refused links** go through `NetLinkWentDown` (close, blank every
  station, status line): `ReportDropped`, `RefuseServer`, the id-in-use arm and
  Disconnect. A refusal used to leave the strip saying "Connected".
- **Exit leaves the network:** `ExitProgram` calls `NetLinkShutdown` (stop the
  retry timer, `NetDisconnect`) after the restart file is saved and before the
  QSO dispatcher goes. `Disconnect` already orders it: bounded drain of posted
  packets, writer stopped, reader stopped, socket closed. A connect still in
  flight is left to the process end.

**tr4wserver: a closed context must not answer for its handle (2026-10-27).**
Windows reuses socket handle values at once. `ContextOf` matched `FHandle`, and a
context the server had just closed (a refused station) stayed in the list until
its thread ended, so the next connection, sometimes holding the same number, was
matched to the dead one: the 'TR4W' write failed ("could not answer TR4W") or hit
a freed context (EAccessViolation in the read path). netprobe's hello case showed
it in 5 runs of 20. Every server-initiated close now goes through
`TServerConn.CloseConnection` (sets `FClosed`), `SyncDrop` sets it too, and
`ContextOf` skips closed contexts. 25 clean runs after (20 hello, 5 all).

Tests: `uTestNetLink` (decision table, command and menu enablement on the real
built menu in every state, startup rule, observers incl. removal during
notification, the refusal latch through the real arms, the window drawing a
mid-session state and unsubscribing, source reads of the wiring). Real
connect / drop / retry is two machines and BENCH_QUEUE.

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

## Outbound writes never run on the caller's thread (2026-10-24)

`TNetClient.Send` used to call Indy's `IOHandler.Write` on the caller's thread --
the main thread for every QSO, status, time sync, intercom line, spot and
serial-number request -- and Indy has no write timeout, so a server that stopped
reading froze logging. It is now `uNetSendQueue.TNetSendQueue`: `Send` copies the
complete packet bytes on the caller's thread (so a packet holds the state of the
moment it was built) and posts them; ONE writer thread owned by `TNetClient`
writes them in FIFO order. `uNet.SendToNet` names the packet from its leading
Word id (`NetPacketKind`) for the log. **The only `IOHandler.Write`s left are the
handshake password in `Connect` (connect thread) and `WriteToSocket` (writer
thread); a unit test reads `uNetClient.pas` and fails if `Send` touches the
IOHandler again.** Do not add a path that writes the socket directly.

What to keep true:

- **Never dropped, unbounded queue.** Nothing on this link is stale. A packet is
  lost only when its WRITE fails (link down, exception): Warn naming the kind, and
  `OnPacketLost` -> `uNet.NetPacketLost`, which counts a lost `QSOINFO` into `tUSQ`.
- **`SendToNet`'s result is the count POSTED**, 0 when the link is down.
  `SendRecordToServer`'s True therefore means *accepted*, not *delivered*; the
  flags it restores on a failed send are restored only for a link that was
  already down. A write failing afterwards leaves `ceSendToServer` True and bumps
  `tUSQ`. Nothing awaits a send's result otherwise; `tNet_Event` (the server's
  ack, `CommitChangesInLocalLog`, a dead resend path) is still a 1 s wait that
  carries on regardless.
- **A write over 250 ms logs a Warn with the packet kind.** A write in flight
  over `WRITE_STALL_LIMIT_MS` (8 s) is cut by the READER thread (it wakes every
  250 ms): `Binding.CloseSocket`, the write fails, the reader sees the drop, the
  ordinary reconnect runs.
- **`Disconnect` is bounded** (250 ms drain on a live link, 750 ms after a cut)
  and stops the writer's work BEFORE the reader and the IOHandler go. The queue
  and its thread live as long as the client; `Destroy` shuts the queue down
  before freeing the socket and leaks the socket rather than free it under a
  stuck thread.
- Packets queued when a link drops fail fast (not written to a closing socket)
  and are reported lost one by one.
- `SendFullStationStatus` (answering `SM_GETSTATUS_MESSAGE`, on the MAIN thread)
  still `Sleep(20)`s between statuses -- a pacing delay from before the queue,
  not a network wait, and not touched.

## The transport, and its one sharp edge

The client is **Indy**, not Winsock. `uNet` used to drive a raw socket and have
Windows deliver events as a **window message** (`WSAAsyncSelect`), so the network
window *was* part of the transport. `NetSocket` is gone — ask `NetIsConnected`.

Parsing still runs on the **main thread**: the reader appends bytes under a lock
and `Application.QueueAsyncCall`s a drain, so every message arm is unchanged.

**The short tail is KEPT between reads — so an unrecognised message id must NOT
be**, or the same bytes re-parse forever and the link wedges in silence.
`ConsumeNetBuffer` reports that case and the drainer resynchronises loudly.
(The server keeps its tail the same way -- see the C7 note near the end.)

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

**The in-tree server frames by `uNetFraming` too (C7, 2026-10-27).** Before it,
`tr4wserver` parsed each read (at most 4096 bytes) as if it were whole, capped
the walk at 25 passes and lost any incomplete tail: the probe measured 30 QSOs in
one send -> 11 relayed AND logged. Now each `TServerConn` owns a
`uNetFraming.TNetStreamBuffer`; `MainExecute` appends the read, takes
`WholeBytes(True, ...)` (the whole-message prefix; True admits the 4-byte
`NET_LOGINFO_MESSAGE` sentinel, whose low Word is pinned NOT to be a message id),
hands only that to `ProcessClientBuffer`, and keeps the tail. An unknown id is an
Error line with the bytes and the connection is DROPPED (the station reconnects).
`ProcessClientBuffer`'s arms are verbatim; it gained an `else` that skips and
Warns on an id the table knows but the server does not handle (1010, 1060), and
the 25-pass cap became a "did not advance" guard. `NextNetMessage` has its first
real caller (inside `NetWholeBytes`); the CLIENT's `ConsumeNetBuffer` still does
its own walk over `NetMessageSize`. **The sync port reads what arrives, up to 50
bytes** (D7's `recv(sock, buf, 50)` semantics): the old `ReadBytes(raw, 50)`
waited for fifty when every client, D7 and this one, writes ten. Pins:
`uTestNetFraming` (30 back-to-back, 1460-byte segments, a cut at every byte, a
kept tail, an unknown id, the sentinel cut at 1-3 bytes). **The record senders (`SendToNet`, `sSend`,
`SendToClient`) keep their untyped buffer on purpose**: each caller hands in
a packed V1 record and that parameter is where its layout becomes the
encoding (P14, skipped for V1).

`tr4wserver.ini` belongs to a different program and is out of scope for the JSON
settings work.

## Coordinate with

`log-database` (row-level sync is the destination) · `contest-scoring` (dupes,
mults and serial lockout cross the link) · `lcl-ui` (`uServerLogForm`) ·
`build-release` (the server is a separate build target).
