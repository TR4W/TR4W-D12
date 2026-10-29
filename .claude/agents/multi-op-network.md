---
name: multi-op-network
description: Multi-operator networking — TR4WServer, the client link, the binary packet protocol with CRC32, log synchronisation, serial-number lockout and time sync. Use for anything about multi-op, networked stations, the server, packet framing, or a station catching up from the server's log.
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
| what each row still owes the server, when a flag may change, unique QSO ids (a leaf) | `tr4w/src/uNetResend.pas` |
| a set of network keys: the in-tree server's held QSOs, and the keys this station's log holds when it catches up (a leaf) | `tr4w/src/uServerQsoIndex.pas` |
| late catch-up: the server log as bytes, the judge of a record's contest, the plan of what to add, and (2026-10-28) the push plan of what the server lacks and the one on-connect decision (a leaf) | `tr4w/src/uNetCatchUp.pas` |
| the Network window (a VIEW of the link) | `tr4w/src/ui/lcl/uNetworkForm.pas` |
| a probe that speaks the protocol to any server | `tools/netprobe/` |
| engine side | `tr4w/src/trdos/lognet.pas` |
| late catch-up: the download thread, the insert-only merge, the on-connect decision | `tr4w/src/uGetServerLog.pas` |
| Net > Synchronize: the window that shows the downloaded server log and adds what this log lacks | `src/ui/lcl/uServerLogForm.pas` |
| CRC32 packets | `tr4w/src/utils/networkmessageutils.pas` |
| analysis | `docs/TR4W_NETWORKING_ANALYSIS.md` — **read the provenance block first** |

**That analysis is TR4QT's, copied whole.** Three of its V1 claims were checked
against this tree and **do not hold**, and the V2 design in it is TR4QT's, not a
plan for this repo.

## Log comparison is GONE, and a late catch-up replaced it (Phase 1, C6, 2026-10-27)

There is **no comparison of two logs any more**, and no wish for one: it was a
CRC32 of raw `.TRW` bytes at both ends, this station keeps no `.TRW`, and the
server still does. (Until 2026-10-27 `ProcessServerLogInfo` **refused** to guess
and logged an error once per session; that was right while nothing replaced it.)
What a station that comes up in the middle of a contest needs is not "are these
the same" but "what do the others have that I lack", and that is **fetch the
server's log and insert what is missing** -- see *Late catch-up* below. The
LOGCOMPARE packet still arrives on admit and is now only noted in the log (the
server's record count). *"Are these two logs the same"* proper belongs to the new
multi-station protocol and will be asked over **rows**.

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

The server's own log holds each sender's `ceContest` byte as it came (a by-id handle means nothing outside the program that wrote it), and the log-compare packet reads the first record's. Neither is judged by the server. The late catch-up (below) reads that log and restamps, as the receive arms do, and judges each record's contest itself.

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

`uNet.ConnectThread` and `uGetServerLog.CatchUpThread` (it was `RunSyncThread`)
are `function(aParameter: Pointer): DWORD; stdcall` (`TF.TTR4WThreadStart`) and
are started BARE -- `tCreateThread(ConnectThread, ...)`, never `@ConnectThread`,
which Delphi mode passes unchecked (`Lint-TypedCodePointers`). They were
parameterless procedures until 2026-10-16, which on i386 corrupted the
thread's SEH chain head at exit (`docs/POINTER_AUDIT.md`, D2).
(`ShowLogCompare`, which took the log-compare record by pointer, is gone with the
dialog it opened; `Lint-PointerTruncation` still keeps the integer form out of
the tree.)

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
  `OnPacketLost` -> `uNet.NetPacketLost`. Since C5 (below) both `OnPacketLost`
  and the new `OnPacketWritten` carry the packet's TAG, and a QSO packet's row is
  settled from them; `NetPacketLost` no longer bumps `tUSQ` itself (it did, from
  the writer thread) -- `SettleServerProgress` counts the rows.
- **`SendToNet`'s result is the count POSTED**, 0 when the link is down.
  `SendRecordToServer`'s True therefore means *posted*, not *delivered*, and it no
  longer touches the record it is given (C5): the log's flags change when the
  writer has WRITTEN the packet. Nothing awaits a send's result;
  `tNet_Event` (the server's 8300 ack) is still set by its arm and nothing waits
  on it since the `.TRW` resend loop went.
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

## Catching up after a lost link (Phase 1, C5, 2026-10-27)

NY4I: a station that reboots or loses the link mid-contest must catch up -- required.
The QSOs and edits made while the link was down are rows in the SQLite log
(`sent_to_server = 0`, `server_dirty = 1`); they go to the server when it is back.
**`uNet.CommitChangesInLocalLog` is GONE** -- it read the `.TRW` and only
`RunSyncThread` called it. `uNetResend.pas` (a leaf: no socket, no store, no
widget set; `uTestNetResend`) holds the decisions; `uNet` does the work.

- **Selection is the repository's** (`TLogRepository.CollectUnsentToServer`, store
  `LogStoreCollectUnsentToServer`): rows with `(sent_to_server = 0 OR server_dirty
  = 1)` that have a network identity, oldest first. The WHERE reuses
  `idx_qso_unsent`'s own predicate, so SQLite reads the partial index (checked
  with EXPLAIN QUERY PLAN). **A row with ceQSOID1 = ceQSOID2 = 0 is never owed**:
  that is what an import carries, it identifies nothing on the wire and cannot be
  marked afterwards by its ids. `LoadinLog` counts `tUSQ`/`tUSQE` with the same
  rule (`ResendNeedsOf`).
- **When: once per link, after the SERVER'S OWN HELLO** (proves the protocol), at
  the END of the drain that handled it (`HandleHelloReceived` sets `GResendDue`;
  `TNetDrainer.Drain` calls `NetServiceResend` after `DrainBuffer`), so a refusal
  (8320) sent in the same read has already been acted on. Guards in
  `ResendOfflineWork`: link up, server HELLO seen, no standing id refusal, not
  already done this link (`GResentThisLink`). `NetBeginLinkSession` resets all of
  it and the peer table; the connect thread calls it before the HELLO goes out.
- **What goes: a row owing a QSO goes as `NET_QSOINFO_ID`, NOT `NET_OFFLINEQSO_ID`.**
  Both servers STORE an OFFLINEQSO and ACK it (8300) but never RELAY it, so the
  other stations would never see it. A row owing an edit goes as
  `NET_EDITEDQSO_ID` (a row owing both sends both, QSO first). One main-thread
  pass, no per-record wait (the old loop waited 1 s each: 200 QSOs = 200 s).
  Then `SM_SERVERLOG_CHANGED` with the QSO count (as D7 did), and ONE notice
  (`SNetResent`, via `QuickDisplay` / `ResendNoticeSink`).
- **When a QSO counts as SENT: when the writer thread has handed its bytes to the
  socket** (`OnPacketWritten`), not when posted. `SendToNet`/`TNetClient.Send`/
  `TNetSendQueue.Post` take an `aTag` (`NetQsoTag(ceQSOID1, ceQSOID2)`, 0 = none)
  and hand it back. The writer thread only `TNetDelivery.Report`s; the MAIN thread
  `SettleServerProgress`es (scheduled by `QueueAsyncCall`, one per batch) and
  writes the two FLAGS ONLY, in one transaction (`LogStoreMarkServerProgress`).
  Written is not read-by-the-server: a packet in the kernel send buffer when the
  cable is pulled is lost, and the next link sends it again -- harmless because
  receivers ignore a held pair. No ack exists on the wire for a QSO (the 8300 does
  not say which), so (c) would be a protocol change.
- **SendRecordToServer does not mutate the record** (it used to set
  `ceSendToServer := True` before posting, and the caller then stored that). The
  PACKET carries sent/not-dirty; the caller stores the record as it made it
  (`LogContact` and `AddRecordToLogAndSendToNetwork` now state `False/False`
  explicitly). `DeleteLastContact` and `uQTCS` set `ceNeedSendToServerAE := True`
  before storing -- a delete made offline was lost before.
- **An edit's `server_dirty` is cleared only when EVERY edit packet posted for
  that QSO was written** (`TNetDelivery.EditPosted` / `Settle`). A failed edit
  leaves it set for good; a later edit that is written carries the whole record
  and clears it. A packet still queued at `Shutdown` is neither written nor lost,
  so its row stays owing; `NetLinkShutdown` settles what the final drain wrote.
- **ceQSOID2 must be unique per QSO** (`uNetResend.NextQsoSequence`): it was
  `GetTickCount64`, 10-16 ms resolution, and the QTC loops make records inside one
  step while the link is down. `LogContact` and `AddRecordToLogAndSendToNetwork` use it.
- **Idempotence, everywhere a QSO is received.** A known `(ceQSOID1, ceQSOID2)` is
  ignored: in-tree `tr4wserver` (`ServerHoldsQSO`, `uServerQsoIndex.pas`, a sorted
  set rebuilt from the log file whenever the file's size is not the one it was
  built from), TR4WServerPy (`qso_in_log`, same rule), and the client's QSOINFO arm
  (`ReceivedQsoIsKnown` -> `LogStoreHasQSOBySessionIds`, after the contest gate).
  **The server neither stores NOR RELAYS a duplicate QSOINFO** (the first copy
  reached the others; each ignores a second anyway) and still ACKs a duplicate
  OFFLINEQSO. Edits are always applied and relayed. The pair (0, 0) is never a
  duplicate. `tools/netprobe` `--case resend` pins all of it against both servers.
- **A refused station can still push**: the server answers the HELLO before it
  judges the id, so QSOs posted in the gap before the 8320 is read are accepted by
  the server. The deferral to the end of the drain closes the usual case (same
  read); a refusal in a later segment is not covered. Existing behaviour for the
  seven status packets, not new.
- **Throughput, measured 2026-10-27:** the in-tree server relays about 34 QSOs a
  second (29 ms each, 200 in 6 s) with or without the dedupe; the probe's burst
  window must be generous (`--timeout 10` for `--burst 200`).
- Tests: `uTestNetResend` (leaf, the ledger, and the real uNet over
  `TNetClient.CreateWithWriter` -- a client whose writer is a stub, through the
  real queue and thread -- on a scratch SQLite log); `uTestLogRepository` (the
  selection, flag-only marking, and `MarkServerProgress` as the 17th write path).
  **The real two-station check is BENCH_QUEUE.**

## Late catch-up from the server's log (Phase 1, C6, 2026-10-27)

NY4I: *"Late catch-up has to be supported as it was ... to handle a station that
comes up (reboots) in the middle of the contest."*

**WHAT D7 DID** (the D7 tree at `C:\TR4W`, read-only): on admit the server sent
`LOGCOMPARE` (`tr4wserver.dpr:421`, built at `tr4wserverUnit.pas:769-785`: size,
first record's contest, CRC32 of `SERVERLOG.TRW`). `uNet.ProcessServerLogInfo`
(`uNet.pas:863-926`) CRC32'd its own `.TRW` and compared (`:867-877`). **Equal:**
"Server and local logs are identical" (`:922`). **Different:** with
`SERVER AUTO SYNCHRONIZE LOG ON CONNECT` (issue #912, `uNet.pas:161`,
`uCFG.pas:782`, default False) and a matching contest (or a server with none) it
downloaded headlessly (`:893-915`), the worker `SendMessage`ing the main window
(`uGetServerLog.pas:253-262`, `tr4w.dpr:253-262`) to run
`ReplaceLogByServerLog(True)`; otherwise the "Difference in logs" dialog
(`uLogCompare.pas:49-294`: size, records, CRC32, USQ, USQE, contest; Synchronize
greyed when the contests differ `:249-251`; Clear all logs; Exit) and from its
Synchronize the window (`uGetServerLog.pas:67-116`): Get server log (`:85-94`),
then **"Create and use new log"** (`:97-100`). The Net menu row *Compare and
synchronize logs* (`Tr4w.rc:448`, Ctrl+Alt+S, `MainUnit.pas:4146`) sent the
sentinel and went the same way. The download (`RunSyncThread`,
`uGetServerLog.pas:140-273`) first ran `CommitChangesInLocalLog` (`:155`), then
read port+1 until the peer went quiet for 2 s, and **`ReplaceLogByServerLog`
backed the `.TRW` up as `LOGBACKUP_nnn.TRW` and COPIED THE DOWNLOAD OVER IT**
(`:118-138`). So D7 was REPLACE: an edit another station made while this one was
away arrived with it, and any QSO only this station held was lost unless the
resend at the start of the download had got it to the server first.

**WHAT IT IS NOW** -- the operator-facing behaviour is kept, the mechanism is not:

- **When.** Once per link, after the server's own HELLO, at the end of the same
  drain as the resend (`HandleHelloReceived` sets `GCatchUpDue`,
  `TNetDrainer.Drain` calls `NetServiceCatchUp` after `NetServiceResend`; the same
  guards). The fetch is `uGetServerLog.StartServerCatchUp(cuOnConnect)`.
- **How a station knows it is behind: it does not ask, it fetches.** The log is
  376 bytes a QSO. Measured 2026-10-27 over loopback to the in-tree server: 10,000
  QSOs = 3.76 MB in 0.05 s, 50,000 = 18.8 MB in 0.5 s; the plan over 20,000
  records against 10,000 held took 110 ms. A count or id comparison would need the
  same fetch to be sure (this log holds rows from other stations and its own
  unsent ones, so equal counts prove nothing). The answer is a COUNT of server
  QSOs this log lacks, which no CRC could give.
- **Off the main thread: the transfer only.** `CatchUpThread` owns its own
  connection and fills a `TServerLogImage` (uNetCatchUp) in memory; it reads NO
  setting (the starter captures host, port and the password's wire form). The
  comparison, the backup, the write and the rescore are the MAIN thread's, handed
  over by `RunOnMainThread`. `FetchServerLog` reads exactly the stated size (D7
  waited for 2 s of silence) and says how far it got when a read fails.
- **What the operator sees.** `AutoSynchronizeLogOnConnect` on: the missing QSOs
  are added (`SNetCaughtUp`, "Caught up from the server: N QSO(s) added."). Off:
  asked, with the count (`SCatchUpAsk`). Nothing at all when the log is already
  complete -- a link that flaps would otherwise announce it all night. A fetch that
  fails is a notice (`SCatchUpFetchFailed`) and an Error line.
- **Net > Synchronize** (`menu_getserverlog`) opens `TfrmServerLog`
  (`ShowServerLogSync`): **Get server log** downloads and SHOWS the rows (the
  virtual grid reads the image through `TryGetServerLogRow`), and the second
  button, formerly *Create and use new log*, is **Add missing QSOs** -- the same
  `AddServerLogToLog`. It replaces nothing. The Difference-in-logs dialog
  (`uLogCompare`, `uLogCompareForm`) is DELETED, as are `ReplaceLogByServerLog`,
  `RunSyncThread`, `HeadlessSyncMode`, `TR4W_SYN_FILENAME` (`SERVERLOG.TMP`),
  `SyncNetBuffer`, `LogSyncSocket` and the form's dead "Sent records" field.
- **The merge is INSERT-ONLY** (`MergeServerLog`): the plan is built HERE from the
  keys the log holds at this moment (`TLogRepository.CollectSessionKeys`, one
  read), so a QSO the live arm logged while the question was open is not added
  twice. A server record whose `(ceQSOID1, ceQSOID2)` the log holds is left alone
  and the row is never touched (pinned with a differing callsign); `(0, 0)` is
  skipped; a pair twice in the file is added once. Then, only if there is
  something to add: **a verified backup first** (`LogStoreBackupBeforeCatchUp`
  into `uAppPaths.BackupDir`: a DATED, never-rotated `<log> before catch-up
  <UTC stamp>Z.db`, like Clear Log's, NOT the periodic slot -- the operator's
  last periodic backup is neither rotated into `.bak` nor touched, and it is
  taken whatever BACKUP LOG FREQUENCY says; a log that cannot be backed up is
  not written to), then ONE all-or-none transaction (`LogStoreAppendQSOs` ->
  `AppendBatch`, the ADIF import's path), then `RescoreLog`. Every added row is
  stamped by `StampCaughtUp`: THIS station's contest handle, `sent_to_server = 1`,
  `server_dirty = 0` (so `ResendOfflineWork` never sends it back), and
  `my_source = 'assumed'` with no `exchange_sent` (the V1 record carries neither
  the peer's station nor its template). Deleted QSOs, notes and QTC records are
  carried too. The log file is never replaced or deleted.
- **WHICH CONTEST** (`JudgeServerRecord`, the unit header has the table): the
  server is contest-agnostic and its log may not have been cleared. For a LEGACY
  contest of ours the record's byte is definitive (the frozen number, the same on
  every build). Otherwise the author (`ceComputerID`, a LETTER) is judged by what
  its HELLO announced on this link (`JudgePeerContest`, by id string); an author
  who is gone is judged by the byte, equal to our handle = ours. For a contest
  registered BY ID that last rule is exact only between stations on the same
  build: a record from a departed author whose byte differs is **skipped and
  counted as unjudged** (`cusUnknownContest`), never imported. The log line names
  every reason with the first call; the operator is told how many belong to
  another contest (`SCatchUpSkipped`).
- **EDITS ARE NOT CAUGHT UP.** The server's copy of an edited QSO is the edited
  record in place (netprobe `catchup` pins it), and D7 got it by replacing the
  file. Insert-only cannot tell which copy is newer: a record has no edit counter,
  this station's own edit may still be on its way (the resend runs just before the
  fetch), and overwriting could turn a newer local edit back into an older one.
  An edit made while this station is UP still arrives live. The fix is the
  row-level protocol, not a guess here. (A QSO is also appended at the END of the
  log; the rescore runs in log order, so a catch-up QSO older than one this station
  logged meanwhile can lose a dupe tie the server's order would have given it.)
- **Settings/menu.** `SERVER AUTO SYNCHRONIZE LOG ON CONNECT` keeps its name and its
  default (False); only what "synchronize" does changed. The Net menu row is still
  `menu_getserverlog`, still needs a live link; its caption ("Compare and
  synchronize logs") is the old English and is the i18n agent's to reword.
- **Tests.** `uTestNetCatchUp` (the image, the judge for a legacy and a by-id
  contest, the plan, the stamp, a 20,000-record timing, the merge over a scratch
  SQLite log: absent rows in, present rows untouched, `(0, 0)`/other contest
  skipped, flags and contest and `my_source`, backup first and no write without
  one, idempotent, all-or-none on a refused record, a live-logged QSO not added
  twice, and `FetchServerLog` against an in-process TIdTCPServer playing the sync
  port: exact bytes, ten password bytes, a short transfer, an impossible size, a
  server that is not there) over the shared base `uTestNetSupport`
  (`TNetStoreTestCase`, lifted out of `uTestNetResend`). Five deliberate mutations
  (legacy byte, held skip, sent flag, `(0, 0)`, backup failure ignored) were each
  caught. `tools/netprobe` `--case catchup` against both servers. **The real
  two-station reboot check is BENCH_QUEUE.**

## A server that lost its log: the catch-up is TWO-WAY (the restock, 2026-10-28)

NY4I moved TR4WServerPy to another machine with no log. His Windows station held 83
QSOs already marked `sent_to_server = 1` (sent to the OLD server); the resend sends
only rows still owed and the catch-up only asked what the SERVER has that this log
lacks, so the new server stayed empty and nothing could push the log up. The same
state follows the server's Clear-server-log or any restart that lost `SERVERLOG.TRW`.

- **Detect, from the image the catch-up already downloads (no second transfer).**
  `uNetCatchUp.TPushPlan.Create(image, resentThisLink)` indexes every pair the image
  holds (deleted records and other contests' too: the question is whether the server
  HOLDS the pair); `Consider(rec)` judges one row of this log: `pvNoIdentity` (both
  ids 0, an import: counted), `pvOwed` (`ResendNeedsOf`, or a pair the resend posted on
  THIS link -- the fetch is on its own connection and the writer may already have marked
  them sent: counted), `pvServerHas`, `pvRepeated` (a pair twice in this log: once),
  else `pvSend`. A QSO this station RECEIVED from another station is pushed like its
  own -- any station can restock the server; the key is the pair, not the author.
  `uGetServerLog.MakePushPlan` feeds it from `LogStoreCollectForServerRestock` (the
  repository skips rows the image holds before parsing them -- see log-database).
  **So the "still owed" count is only the owed rows the server LACKS**: an owed row the
  server holds an older copy of (edited offline) is skipped by the repository and never
  reaches the judge; the resend sends its edit as before.
- **Send as `NET_OFFLINEQSO_ID`, NOT QSOINFO, through `uNet.RestockServer`.** Both
  servers STORE an OFFLINEQSO and ACK it (8300) but do NOT relay it (read: in-tree
  `tr4wserverUnit` OFFLINEQSO arm never calls `SendMessageToClients`; Python
  `NET_OFFLINEQSO_ID` arm never calls `broadcast_to_clients`; `netprobe --case restock`
  asserts a second connected probe receives nothing), and a pair already held is not
  stored (still ACKed). So restocking never floods the connected stations; one that
  lacks some catches up from the server's log on its next link. `RestockServer` posts
  through the ONE packet builder (`PostQsoPacket`, the same as `SendRecordToServer`,
  qiSenderID and the `SendToNet` guard included) with tag 0, re-checking the guards
  (`NetIsConnected`, server HELLO seen, no refused id) at send time because the fetch is
  asynchronous. **No flag is written and nothing is queued for the main thread:**
  `ReportPacketOutcome` skips a WRITTEN tag-0 QSO packet (a failure is still reported).
  A link that drops half way needs no repair: the plan is made again from the server's
  log on the next link.
- **One decision, one question.** `uNetCatchUp.SyncOnConnect(pull, push, auto)` ->
  `socNothing | socDoNow | socAskPull | socAskPush | socAskBoth`;
  `uGetServerLog.DecideOnConnect` asks AT MOST once (`SCatchUpAsk`, `SPushAsk`,
  `SSyncAskBoth`) and does the push, then the pull. Nothing is said when both sides are
  complete. `SNetPushedToServer` ("Sent to the server: %d QSO(s) it did not have.") is the
  notice; the log lines are `[Net] restock: ...` with the counts.
- **The window (Net > Synchronize with the server..., `uServerLogForm`).** After Get server
  log the Add button (`SERVER ... N missing`) and a Send button (`SYNC_FIELD_ENABLE_SEND`,
  "Send N QSO(s) to the server") appear independently; Send is offered only while the link is
  up and sends AT ONCE, re-planning from the log at click time, and stays disabled until the
  next Get server log (the image is the server's log as it WAS).
- **The servers need no change.** Verified from source and by `netprobe --case restock`
  against both. One difference worth knowing: the in-tree OFFLINEQSO arm stores nothing and
  sends no ACK if `OpenServerLog(slOpenExisting)` fails (QSOINFO buffers instead); the file
  is created at startup, so it matters only if SERVERLOG.TRW is deleted while it runs.
- **Measured 2026-10-28.** Client (unit test `uTestNetRestock`, scratch SQLite log, stub
  writer): the plan over a log the server already holds is 141 ms at 10,000 rows and 359 ms
  at 20,000 (main thread, once per link, image index included); a 5,000-QSO push is
  planned in 94 ms holding about 3.2 MB (the plan's copies of the rows), posted in under a
  millisecond (the queue copies bytes) and drained by the stub immediately. Servers
  (`netprobe --case restock`, `--restock-big 5000` in ONE write): TR4WServerPy
  acknowledged 5,000 in 5.1 s (1 ms each); the in-tree `tr4wserver` in 213 s (42.6 ms each;
  85 ms each for the first 200 in one run) -- its OFFLINEQSO arm opens the log twice and
  flushes per record, and logs at trace level by default -- so a 5,000-QSO restock of
  the in-tree server takes minutes, not seconds, and a probe's wait must be sized for it
  (`count * 0.05 s`). Both stored every record whole, once each, in order, relayed none, and
  held all 5,200 after a restart in the same directory. **ONE unexplained event:** in the
  first of five in-tree runs the process was gone about 7 s into the 5,000 round (about 1,390
  records stored), with no crash line in `tr4wserver.log` and no Windows error-reporting
  event; four later runs, including one at `LOG LEVEL = ERROR`, did not reproduce it.
  Not understood; watch for it on the bench (`$p.ExitCode` of the server process is the
  first thing to read).
- **Tests**: `uTestNetRestock` (the 83-row plan over a scratch store, idempotence, a partial
  server, other stations' rows, a second plan after the push, resent-this-link keys, deleted
  and repeated rows, the decision table, the posting over a stub writer, the unusable-link
  refusal, the window's buttons and its layout read from the `.lfm`, source reads);
  `TStubLink`, `WaitWrites` and `NewImage` now live in `uTestNetSupport`. **The real
  two-station check is BENCH_QUEUE ("A SERVER THAT LOST ITS LOG").**

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

**Every packet the client sends is judged at `SendToNet`, and each record's id is set by
its sender (2026-10-27).** From 2026-08-25 the DX spot, time sync, intercom line and
spot-via-network left with a leading id of ZERO: four global records had their id
initialisers commented out when the Network window (whose WM_INITDIALOG set them) became
a form. The server cannot frame past an unknown id and drops the connection, so the link
flapped once per spot (reconnect, resend, catch-up). Nothing saw it: netprobe builds its
own packets, `uTestNetWireSizes` checks TYPES, and no test had ever read a byte the
CLIENT wrote. **THE LESSON: every record the client sends must be captured from the
client's own send path -- types and probes cannot see a missing id.**
`uTestNetClientPackets` does that (real uNet, `TNetClient.CreateWithWriter`, a stub that
keeps the bytes). The fix is two layers: (1) `uNet.SendDXSpotToNet`, `SendTimeSyncToNet`,
`SendIntercomToNet`, `SendSpotViaNetworkToNet` each build a LOCAL record and set its id on
every send (as `SendParameterToNetwork`, `SendStationStatus`, `SendMessageStatus` and
`SendRecordToServer` always did) -- the four globals are gone, so a new caller cannot
forget; (2) `SendToNet` refuses a packet whose first Word is not an id
`uNetFraming.NetMessageSize` knows or whose length is not that size
(`OutboundPacketIsWellFormed`), returns 0, and logs an Error once per distinct
(id, length) per link (`TNetSendRefusals`, reset by `NetBeginLinkSession`). There is no
bypass: the only raw send that existed, `LogNet.SendMultiMessage` (K1EA text), has no live
caller, and the 4-byte log-info sentinel is not sent through `SendToNet`. **A new record
type needs an entry in `NetMessageSize` before it can be sent at all.** Out of scope but
real: `MyStationState` is one global written from the main and the radio polling thread, so
the record can tear (the id is fine); `SendMessageStatus`'s local record is not zeroed.

`tr4wserver.ini` belongs to a different program and is out of scope for the JSON
settings work.

## A host name goes through `uHostResolve` before Indy sees it (issue 148, 2026-10-28)

The vendored Indy resolves a Unix name with FPC's netdb (hosts file, then its own
DNS client against the resolv.conf stub), never the C library, so a `.local` (mDNS)
name failed on Linux while `getent hosts` resolved it. `src/utils/uHostResolve.pas`
(a leaf, no logger): on Unix it asks libc `gethostbyname` (Linux: FPC's `cnetdb`;
macOS: declared in the unit, because `cnetdb` is not built for Darwin) and returns
the IPv4 address; on Windows it returns the name untouched and calls nothing. A
literal address, an IPv6 literal or an empty name never reaches libc. IPv4 only: a
name with only an AAAA record fails, naming the host. **Call it only from a thread
that may wait** -- the multi-op `ConnectThread` (`uNet.ResolveServerAddress`, which
logs an Error once per name until `ForgetServerRefusal`), the catch-up worker
(`FetchServerLog`, which resolves; the starter on the main thread only captures the
name), the cluster connect thread, the radio polling thread (a network radio's
Connect is deferred to it), the K4 spectrum thread, the DXKeeper sender thread. Log
lines keep the NAME as typed. Not routed: NTP (its server comes from the Windows
registry only). UDP broadcast destinations ARE routed, in the one transport
`LogCfg.SendUDPPayload` (the dispatcher thread, PstRotator's `SendDirect` and the
destination dialog's Test button all pass through it): the name is resolved at
EVERY send, before `gUdpLock`, and DELIBERATELY NOT CACHED (NY4I: a stale address
over UDP fails silently, and the OS resolvers cache with real TTLs). A failure
raises out of the transport and `TUDPBroadcaster` contains it per destination, so
the next one is still sent; the Test button's message carries the reason. The
Test button resolves on the main thread, as Indy did before.

## Sharing DX spots is a setting, per station (2026-10-29)

`Settings.Network.ShareSpots` (`NETWORK SHARE SPOTS`, Preferences > Network,
default **True** = the old behaviour). OFF means THIS station neither posts nor
accepts spots: the send gate is in `uSpots.AddSpot` (before `SendDXSpotToNet`),
the receive gate is the `NET_NETWORKDXSPOT_ID` arm in `uNet.ConsumeNetBuffer`,
which skips `AddSpot` and `DisplayBandMap` but still lets the common
`inc(Bufindex, MsgSize)` consume the packet (one Debug line per link,
`GSpotShareNoted`). Both read the setting at the moment of the spot, so no
restart. It is deliberately NOT in `SHARED_WITH_PEERS`: the usual setup is one
gateway computer with the cluster and peers without, and stations must be free
to differ. A received spot is added with `SendToNetwork` False, so a station
never posts back what it was sent. **`SendSpotViaNetworkToNet` and its arm (the
Send Spot form) are NOT governed by it**: explicit operator action; the servers
hand it to the first OTHER station whose status says it has a cluster. Neither
server was changed (both relay 1030 blindly to every other station). Tests:
`uTestNetClientPackets` (`Test_SharingOffPostsNoSpot`,
`Test_SharingOffIgnoresSpotsFromTheNetwork`), `uTestSettingsModel`.

## Coordinate with

`log-database` (row-level sync is the destination) · `contest-scoring` (dupes,
mults and serial lockout cross the link) · `lcl-ui` (`uServerLogForm`) ·
`build-release` (the server is a separate build target).
