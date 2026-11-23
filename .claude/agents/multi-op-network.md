---
name: multi-op-network
description: Multi-operator networking — TR4WServer, the client link, the binary packet protocol with CRC32, log synchronisation and serial-number lockout. Use for anything about multi-op, networked stations, the server, packet framing, or a station catching up from the server's log.
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

## A NEW QSO'S PACKET IS SENT ONLY AFTER THE LOCAL COMMIT (issue 347, plan commit 4, 2026-11-22)

`LogContact` copies the record into its leg at the point it used to call
`SendRecordToServer(NET_QSOINFO_ID, ...)` and sends THAT COPY from Release,
after `LogStoreAppendLiveQSOs` committed -- same record, same bytes, later. A
refused QSO sends nothing; its `ceQSOID2` is simply never used (a retry takes
a fresh one, plan 2d). `sent_to_server` keeps its meaning: the row now exists
before any `SettleServerProgress` can mark it, and a crash between the commit
and the post leaves it 0 for `ResendOfflineWork`. `tUSQ` still counts a post
that found no link.

**Commits 6 and 7 (2026-11-22, NY4I rulings 3 and 4 of 2026-11-21):**

- **The receive arm honours `LogContact`'s answer** (`uNet`, `NET_QSOINFO_ID`).
  True: `UpdateWindows`. False (the log refused; commit 4 already posted no UDP
  or HamScore for it): `ReportPeerQsoRefused` -- an Error line EVERY time (call,
  band, mode, network key), ONE operator notice per link (`SPeerQsoNotSaved`,
  `QuickDisplay`, or `PeerQsoRefusedNoticeSink` in a test), counted by
  `PeerQsosRefusedOnThisLink` (reset by `NetBeginLinkSession`). Once per link,
  not once per packet, because a full disk refuses every peer QSO and the store
  already raises its own modal on the first refusal. **No retry queue.** The
  report text is true because: the server stores a QSOINFO (when its own write
  works, `tr4wserverUnit` 759-780) and relays it; nothing on the wire
  acknowledges a QSO, so the server cannot think this station stored it; the
  refused pair is not "known" (`ReceivedQsoIsKnown` reads the log), so the next
  catch-up or Net > Synchronize (insert-only by `(ceQSOID1, ceQSOID2)`) adds it.
  The one case the text hedges ("if the server has it") is a server whose log
  write failed too. A QSO this station DID store is untouched (the False branch
  is the only new code).
- **`MainUnit.AddRecordToLogAndSendToNetwork` appends first** and sends the
  record only when `tAddQSOToLog` returned True. A refused record sends nothing,
  counts no `tUSQ` (no row owes the server) and returns False, so the QTC
  callers (`uQTCR`, `uQTCS`) skip their pacing `Sleep`; the success path is
  unchanged (same record, same bytes, later). Note: a committed record posted
  with no link still returns False and counts `tUSQ`, as before.
- Pins: `uTestAutomaticXQSO.Test_APeersRefusedQSOIsReportedNotAssumedSaved` and
  `Test_ANoteOrQTCRecordIsSentOnlyAfterItsCommit` (source reads). Bench:
  BENCH_QUEUE "Peer refused" and "QTC and note". An incoming NOTE or QTC record
  (`rkNote`, `rkQTCR/S` arms) already checked `tAddQSOToLog` and logs at Error.

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

## Network protocol 3: the QSO record carries a received year (issue 298, 2026-11-12)

`NET_PROTOCOL_VERSION` = **3**. `ContestExchange` gained `RcvdYear` (Word, offset
324) and `RcvdYearKnown` (326), carved from `sReserved`: **every size is
unchanged** (QSO packet 384, record 376, `SERVERLOG.TRW` stride 376) and the
server stores and relays the record without knowing. The bump is for MEANING: a
protocol-2 station sends those bytes as zero, so its QSOs would arrive with no
year. NY4I ruled no compatibility with a released server is needed.
(Superseded by protocol 4 below, which keeps this layout; TR4WServerPy and
netprobe are at 4 now.) Pins: `uTestNetHello` (the version),
`uTestLogReceivedYear` (`TNetReceivedYearTests`: the packet carries the year
and the year 00; a QSO caught up from the server's log keeps it; and since
stage 2 a QSO received LIVE through the real NET_QSOINFO arm stores it).

## Log schema 10: byte 330 is `ceOffContest`, and NO receiver trusts it (2026-11-19)

`ContestExchange.ceOffContest` (Boolean, offset **330**, carved from
`sReserved`, now `string[42]` at 331..373; record 376, packet 384, every
earlier offset unchanged) is the contest's band/mode/host-area rule as the
LOGGING station stamped it (`qso.is_off_contest`, docs/LOG_SCHEMA.md). **No
protocol bump**: every receive path re-stamps with THIS station's contest --
a live NET_QSOINFO through `LogContact`, a peer's edit in
`LogStoreUpdateQSOBySessionIds`, a catch-up through `LogStoreAppendQSOs`, a
server-log row in `uGetServerLog.TryGetServerLogRow` -- so an older station's
zero byte and a newer station's stamp are judged alike. Both servers store and
relay the record whole and read none of it.

## Network protocol 5: a QSO is a length-framed JSON row (W3+W5 part 1, 2026-11-22; design 13.7)

`NET_PROTOCOL_VERSION` = **5**. Pascal framing, HELLO 5 and the in-tree `tr4wserver` are DONE; the CLIENT
(send, receive, catch-up, push) is the other agent's. TR4WServerPy and `tools/netprobe` ARE converted (2026-11-22).

- **netprobe on protocol 5, and the two-server comparison.** `tools/netprobe/netprobe.py` carries a COPY of TR4WServerPy's `wire.py` codec (checked against `tr4w/test/wire/golden_vectors.json` by `--case selftest` and `test_codec.py`: re-copy and re-run if wire.py changes). Cases: `selftest connect spot qso burst edit disc dup serial time hello resend catchup restock badcrc big legacy offline-ack clear`. With `--launch pascal|python --server <exe|py> --workdir <dir>` it starts the server itself, one fresh directory per case, which is what lets `catchup` (kill, restart, same bytes), `offline-ack` (kill at the FIRST ack: every acked row survives) and `clear` (backup file) run. `tools/netprobe/compare.py --pascal <exe> --python <tr4wserver.py> --work <scratch>` runs each case against both servers with the SAME seed and compares the RESULT lines, every column of every row of both `.tr4wsrv` files in seq order, the meta table and the decoded sync stream; every difference is a DIVERGENCE line. The Pascal server spells the sync-stream JSON with spaces (`{ "a" : 1 }`), Python compactly: same values, different bytes (a NOTE, not a divergence; a client must parse, not compare text).

- **Framing (`uNetFraming`).** `NET_WIRE_QSO_ID` 1041, `NET_WIRE_EDIT_ID` 1051, `NET_WIRE_OFFLINE_ID` 1057:
  2-byte LE id, 4-byte LE payload length, payload = 1 sender byte + UTF-8 JSON (`uWireQso`). Cap
  `NET_WIRE_MAX_PAYLOAD` 60000; an over-cap declaration is `nwOversize` decided from the six header bytes
  (never "partial"); `NET_RECEIVE_BUFFER_SIZE` 131072. `NetMessageSize` is 0 for the wire ids and for the retired
  1040/1050/1055 (unknown ids; the constants stay in VC.pas marked `(* retired *)` until the client stops using
  them). Helpers: `BuildWireMessage` (WireText, then checksum, then EncodeJson), `TakeWireMessage`
  (`wtOk/wtNoSender/wtBadJson/wtBadChecksum/wtBadNumber`), `PutWordLE/PutCardinalLE/GetWordLE/GetCardinalLE`,
  `BuildSyncHeaderFrame/BuildSyncRowFrame/TakeSyncHeader/TakeSyncRow`, `OutboundWireMessageIsWellFormed`.
  No `Move`/`FillChar` in any of it.
- **Server decisions are a leaf (`uServerWireFrames`)**: `ProcessWireFrame` over a `TServerWireStore`, and
  `SendSyncStream`. `tr4wserverUnit.HandleWireFrame` only sends (relay with the sender byte RE-STAMPED from the
  accepted HELLO; a connection with no accepted HELLO has its QSO frames refused). OFFLINE ACKs are counted
  and sent by `FinishOfflineRun` only after `Release` returned True; a failed row voids the run's ACKs.
  A refused row never drops the link; an oversize or unknown id disconnects with a logged reason.
  The disk-failed NEW row is STILL relayed (issue 314) -- the contract's "relay only when stored" was not
  applied there; NY4I to confirm.
- **Store additions (`uServerWireStore`)**: `Release` returns Boolean; `Contest` / `RememberContest`
  (first HELLO wins; `INSERT OR IGNORE` into meta) / `ForgetContest` (Clear-all forgets it);
  `BackupTo` (VACUUM INTO via `TLogDatabase.SnapshotTo(dest, aStationLog=False)`, which skips the
  station identity check); `ReadAll(rows, contest)` reads the contest in the same snapshot.
  Clear-all-logs backs up first (`SERVERLOG before clear <stamp>.tr4wsrv`) and REFUSES to clear if the backup fails.
- **Files**: `SERVERLOG.tr4wsrv`; an existing `SERVERLOG.TRW` is reported once and left. The log-info packet
  (1010) carries the ROW COUNT in `liServerLogSize` (contest/CRC 0). Sync stream = header frame
  `{"contest","rows","schema":5}` then one frame per row, from ONE `ReadAll`.
- Retired: `uServerLogStore`, `uTestServerLogStore`. Kept because the client still uses them:
  `uServerQsoIndex`, `uCRC32`.
- Tests: `uTestNetFraming` (wire framing, split at every byte, oversize, retired ids, round trips),
  `uTestServerWireFrames` (the server decisions over a scratch DB, sync stream, backup, contest).

## Network protocol 4: the QSO record carries the year its SENDER sent (issue 300, 2026-11-13)

`NET_PROTOCOL_VERSION` = **4**. A QSO row stores the licence year it SENT
(`qso.year_sent`, log schema 8, unchanged: **no schema 9, no migration**); NY4I
(2026-11-13: *"Server wire formats can be done at will. Just update the Python
tr4wserver and FPC/Laz version."*) wanted a peer's row to hold the year THE PEER
sent. `ContestExchange` gained `YearSentKnown` (Boolean, offset **327**) and
`YearSent` (Word, **328**), carved from `sReserved` (now `string[43]`, 330..373,
still ending at 374; bytes 374..375 are padding). **THE BOOLEAN IS FIRST ON
PURPOSE**: `sReserved` began at the odd offset 327, so a Word there would have
been aligned to 328 leaving an uninitialised pad byte at 327. Byte 327 was
`sReserved`'s length byte (always zero), so every older record -- `.TRW`,
`SERVERLOG.TRW`, a protocol-3 packet -- reads "no year" with no conversion.
**Every size is unchanged** (record 376, QSO packet 384, `SERVERLOG.TRW` stride
376); both servers store and relay the record whole and read none of it.
Pinned in `uTestLogBinaryFile` (offsets 327/328/330, end 374, total 376).

- **Filled on the sender in ONE place per path.** A QSO this station has just
  made is stamped by `uContestFactory.StampSessionSentYear` (over
  `SessionLicenseYearSent`; cleared where the contest sends none) in the two
  sites that make and post one: `logsubs2.LogContact` (MyComputer branch) and
  `MainUnit.AddRecordToLogAndSendToNetwork`, **before** `SendRecordToServer`
  (the packet goes before `tAddQSOToLog`). **DO NOT STAMP IN `PostQsoPacket`**:
  it also sends edits, resends and restocks of PEER rows, and stamping there
  would put this station's year on a peer's QSO. A STORED row read back
  (`uLogRepository.ReadRecord`, the one reader behind the resend, the restock,
  Edit QSO, delete/undelete and the QTC edits) carries the row's own
  `year_sent` (NULL = none, 0 = the year 00), so a resend or edit of a peer's
  row sends the PEER's year. The one writer of the pair is
  `uContestBase.StoreSentLicenceYear` (range-checked: a year over 65535 is none,
  not wrapped).
- **Stored on the receiver** by `uLogStore.CaptureMyFactsNow` (`sysPeer`:
  `SetFactsYearSent(.., aQso.YearSentKnown, aQso.YearSent)`; was cleared) and,
  per record, by `uGetServerLog.MergeServerLog` (the catch-up; gated on the
  contest sending a year, as `SentYearSourceOf` is). A record with none stores
  NULL, never ours. `uNetCatchUp.StampCaughtUp` and the push plan do not touch
  the bytes. The `.TRW` reader clears them (a D7 log carries none).
- **An edit does not refill `year_sent`**: it is insert-only in the my_* tier,
  so a peer's EDIT of a QSO this station already stored does not change the
  stored year (a row stored with none before the edit stays none). Not a
  regression; say so if asked.
- **The EXPORT** (`MyStationExchangeOfQSO`) already preferred a row's year when
  known; a peer's row now holds the peer's year and so exports it. A peer's row
  with none (a protocol-3 era server log, a sender whose contest sends none)
  still falls back to the session's, as before schema 8.
- **What an older party does on meeting protocol 4:** a protocol-3 station
  HELLOing a protocol-4 server gets `SM_PROTOCOL_MISMATCH` (8330, param 4) and
  "server newer"; a protocol-4 station meeting a protocol-3 server (TR4WServerPy
  deployed before this change, the pi400 rig) is refused with "server older".
  Both are the ordinary `JudgeProtocol` refusal, once per address/port.
- **Servers:** the in-tree `tr4wserver` takes the constant from `uNetHello` and
  needed no other change. TR4WServerPy (other repository, master) moved to 4
  (`NET_PROTOCOL_VERSION`, `CHANGES.md`, `README.md`, `CLAUDE.md`); it never
  reads the bytes. `tools/netprobe/netprobe.py` is at 4.
- **Tests:** `uTestNetHello` (the 4), `uTestLogBinaryFile` (layout),
  `uTestLogYearSent.Test_TheRecordCarriesTheSentYear` (the writer, the range, the
  repository reader), `uTestLogReceivedYear.Test_APeersSentYearTravelsAndIsStored`
  (the packet bytes, the catch-up storing 91 / 00 / none, a stored row's resend
  carrying it), `uTestLogMyFacts.TestTheStoreRecordsTheYearOurQSOSent` (the
  live store: ours 64, a peer's 85, a peer's none), `uTestLogYearSent.
  Test_TheExportSendsTheRowsYear` (a peer's 85 exports 85 while the session
  sends 90) and `Test_TheCorrectionTouchesOnlyOurOldYear` (a peer's 64
  survives the year correction: the predicate is by `my_source`). **Not
  driven:** the live `NET_QSOINFO` arm with a sent year (it reaches the same
  `CaptureMyFactsNow`), the real two-station check (BENCH_QUEUE). Note the EUHFC
  rules are single-operator only; a networked SO2R pair sends one operator's
  year.

**A UNIT TEST CAN DRIVE THE NET_QSOINFO ARM WITH A NEW QSO -- IF IT STREAMS THE
MAIN FORM** (diagnosed 2026-11-12, issue 298 stage 2). The access violation
stage 1 met, and the old belief that "LogContact cannot be survived in a unit
test" (`uTestNetResend`, `uTestContestById`), were both the display: run step
by step, `LogContact(.., False)` COMPLETES and the row is stored; the fault is
`UpdateWindows` (`DisplayTotalScore`, `DisplayNextQSONumber`,
`DisplayQSOsByOpMode`) and `LogContact`'s `DisplayHour`, which write
`TR4WMainForm` panels -- nil in the test binary. NOT a live defect: the program
creates the form before `NetLinkStartup`, and a packet is parsed on the main
thread via `Application.QueueAsyncCall`. `uTestMainFormHarness.EnsureTestMainForm`
/ `ReleaseTestMainForm` (lifted from `uTestStatusAndNotice`) supply and remove
it; always release it (other suites assert it is nil). Send the peer's QSO as
an X-QSO to keep it off the session totals and sheets later suites share.

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

**Tools > Correct Station Facts (issue 223, 2026-11-22) sends one
`NET_EDITEDQSO_ID` per changed row of OURS, after the commit and the
rescore** (`uEditQSO.AnnounceStationCorrection`); the rows are stored
`server_dirty`, so an unconnected station resends them. A peer's (`assumed`)
row is corrected locally and NOT sent from here. The packet carries no my_*
column; what the server gains is the rescored record.

**An outgoing `NET_EDITEDQSO_ID` is sent only AFTER the log committed the
change (issue 349, 2026-11-22)** -- Edit QSO's save, Alt-Y's delete/restore,
and the QTC mark in `uQTCS`, together with the dispatcher's edited/deleted
events (`PostQsoEvent`). They used to go before a store write that answered
nothing. And an INCOMING edit's `FindAndUpdateQSOInLog` True now means
COMMITTED: `LogStoreUpdateQSOBySessionIds` answered True when its commit
raised, and now also rolls back an UPDATE that matched no row. Detail:
`log-database.md`, "A CHANGE TO A LOGGED QSO".

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
the main thread for every QSO, status, intercom line, spot and
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

## The server log that cannot be written (issues 314, 312; review H9, 2026-11-16)

- **No in-memory buffer.** `AddContestExchangeToBuffer` / `WriteContestExchangesBufferToServerLog`
  had no caller (30 slots, lost on exit) and are deleted. A QSO the log cannot take is
  **still relayed**: no packet acknowledges a QSO, the sender marks it sent when its
  writer wrote it and never offers it again, so withholding it would only take it from
  the others' dupe and mult checks. The next station to link pushes what the server's
  log lacks (the restock). Nothing on a station waits for the 8300 ACK (it only sets
  `tNet_Event`), so "no ACK" does NOT make a station resend.
- **The notice channel is the intercom** (`NET_INTERCOMMESSAGE_ID`, sender `#`, a Str80,
  <= 79 chars): `tr4wserverUnit.SendNoticeToStations`. No new wire field; an older station
  shows it too. Sent on the TRANSITIONS only (first failure of a run, first success
  after), by `NoteServerLogFailure` / `NoteServerLogWritten`; the window shows the count.
  Texts and the clip of the OS reason live in `uServerLogHealth` (a leaf, tested).
- **The window:** `uServerForm.SetServerLogProblem` (red label + `LOG NOT SAVING` title
  suffix; one title builder, because `SetClientCount` also writes the title). Issue 312:
  `ShowServerProblems` also reads `appender.WriteFailures` (Log4D counts instead of
  raising), checked in `DisplayRCVDBytes`. The tr4w APP's own tr4w.log counter is not
  yet shown anywhere.
- **Torn tail at start:** `OfferTornLogRepair` (before `OpenOrCreateServerLog`) -> only a
  file whose first record is the CURRENT header is offered a backup-then-trim
  (`BackupAndTrimServerLog`: copy, size check, then truncate; `<file>.torn-<stamp>.bak`).
  Size alone cannot tell a torn tail from an older record size, the header can. Any other
  wrong-size log is still refused, untouched.
- TR4WServerPy (other repository) has none of this; parity is open.

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

## The server store's integrity rules (issue 341 P3, 2026-11-23; the next section is STALE on "nothing calls it")

`tr4wserverUnit` DOES call `uServerWireStore` since W3+W5; the section below is W2's
record. What is true now, and not obvious from the code:

- **Integrity check at start runs on the READ-ONLY peek**, before the read-write open
  (which sets WAL and replays the `-wal`). A damaged or foreign file is refused untouched.
- **Full disk = roll back, notice once, relay anyway, the NEXT write is the probe**
  (`NoteServerLogWritten` is the recovery notice). Do not add a second read-only state.
  `lwfWriteError` (not a full disk) makes the store REOPEN its connection first.
  `TServerWireStore.LimitPages` is the test's `PRAGMA max_page_count`.
- **Clear-all (8230, the only live one) backs up with `BackupTo` first and refuses without
  one.** The copy is verified (integrity + row count) and a log that cannot be COUNTED is
  refused too (`Count` is -1 then, which once skipped the backup).
- **`sqlite3.dll` must sit beside `tr4wserver.exe`**: the installer puts the server in
  `server\`, a level below the app's copy, and the loader starts at the exe's folder.
  `WireStoreLibraryProblem` names it at start.
- **No `SERVERLOG.TRW` import or exporter exists, on purpose**: a flat record has no
  `guid`, the wire's identity. The old file is renamed with a stamp after a clean start.

## The server's SQLite store EXISTS and nothing calls it yet (W2, 2026-11-22)

`src/uServerWireStore.pas` (`TServerWireStore`, tests `uTestServerWireStore`) is the
server's log as its own SQLite database over `TWireValues` rows: hold/release (one
transaction), insert-if-identity-absent, update-newest, holds, clear, clear-flags,
max serial, count, and `ReadAll` (arrival order, one read transaction on its own
connection, any thread). **Identity is the `guid` column** -- the old pair is the
station's LOCAL `session_id`/`session_seq` and never reaches the wire; an empty guid
is stored every time and an edit carrying it changes nothing. The rules both servers
follow (schema, NULL versus '', refusals) are design note section 13.6. **W3 swaps
it in behind the `uServerLogStore` seam; until then `tr4wserverUnit` and
`SERVERLOG.TRW` are untouched and the store is only compiled** (listed in
`tr4wserver.lpr`). Facts a later stage needs:

- **The table of columns moved**: `uQsoColumns.pas` (a leaf over `uWireQso`) holds
  `QSO_TABLE_COLUMNS`, `QsoWireColumns`, `QsoTableColumns`, `QsoColumnIsLocal`;
  `uLogRepository` uses it and keeps the wire READER (`GWireReadPosition`,
  `QsoWireTableProblem`). `uLogRepository` itself cannot be linked into the server
  (registry, TF, ADIF, zones).
- **The connection layer is reused, not lifted**: `TLogDatabase.OpenWithoutIdentity`
  (new, public) is `OpenConnection` with no schema, no 'TR4W' check, no migration.
  The server's own identity is application id `$54523453` ('TR4S'), file `.tr4wsrv`.
- **The Server search path now has `sqlite`, `fcl-db`, `fcl-base`**
  (`Get-SearchPaths.ps1`): the guard that withheld them is retired by ruling, not
  replaced. The installer must ship `sqlite3.dll` beside `tr4wserver.exe` (design 7).
- **A held run is durable only at Release**: ACK an OFFLINEQSO run AFTER `Release`.
- **This framework calls `TearDown` after EVERY check**: a suite that removes its
  scratch directory there loses it mid-test (it cost a failed run).

## The server log is behind ONE seam (SQLite plan phase P1, 2026-11-19)

`tr4wserverUnit` no longer touches `SERVERLOG.TRW`. `src/uServerLogStore.pas` (a leaf,
unit-tested by `uTestServerLogStore`) holds `TServerLogStore` (abstract: `Initialize`,
`Hold`/`Release`, `Append`, `UpdateNewest`, `Holds(id1,id2)`, `Clear`, `ClearFlags`,
`MaxNumberSent`, `Describe` = size + first record's contest + CRC, `Count`, `OpenImage`)
and `TFileServerLogStore`, the only implementation: the old bodies MOVED, open/close/hold
semantics and the CRC cache included. The global is `tr4wserverUnit.ServerLogStore`,
made by `CreateServerLogStore` (tr4wserver.lpr, after `ServerLogFileName` is set); the
server's reactions to a failed or successful write and the window's QSO count are three
plain callbacks (`NoteServerLogFailure`, `NoteServerLogWritten`, `DisplayServerLogCount`)
called at the same points in the sequence as before. `uServerNet.SyncExecute` asks
`OpenImage` and is otherwise unchanged: **the sync-port snapshot hazard (design 6.2) is
still there on purpose.** Do not add file access to the server unit again; add a method.
Oracle: `tools/netprobe/compare.py` (both servers, every case, row-level; see the protocol-5 section) and `netprobe.py --case all`. The byte-oracle scripts (`Run-SyncBaseline.ps1`, `Run-TrwRoundTrip.ps1`, `baselines/`) were removed 2026-11-22: there is no 376-byte image to hash.

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
its sender (2026-10-27).** From 2026-08-25 the DX spot, time sync (since removed), intercom line and
spot-via-network left with a leading id of ZERO: four global records had their id
initialisers commented out when the Network window (whose WM_INITDIALOG set them) became
a form. The server cannot frame past an unknown id and drops the connection, so the link
flapped once per spot (reconnect, resend, catch-up). Nothing saw it: netprobe builds its
own packets, `uTestNetWireSizes` checks TYPES, and no test had ever read a byte the
CLIENT wrote. **THE LESSON: every record the client sends must be captured from the
client's own send path -- types and probes cannot see a missing id.**
`uTestNetClientPackets` does that (real uNet, `TNetClient.CreateWithWriter`, a stub that
keeps the bytes). The fix is two layers: (1) `uNet.SendDXSpotToNet`,
`SendIntercomToNet`, `SendSpotViaNetworkToNet` (and `SendTimeSyncToNet`, removed) each build a LOCAL record and set its id on
every send (as `SendParameterToNetwork`, `SendStationStatus`, `SendMessageStatus` and
`SendRecordToServer` always did) -- the four globals are gone, so a new caller cannot
forget; (2) `SendToNet` refuses a packet whose first Word is not an id
`uNetFraming.NetMessageSize` knows or whose length is not that size
(`OutboundPacketIsWellFormed`), returns 0, and logs an Error once per distinct
(id, length) per link (`TNetSendRefusals`, reset by `NetBeginLinkSession`). There is no
bypass: the only raw send that existed, `LogNet.SendMultiMessage` (K1EA text), has no live
caller, and the 4-byte log-info sentinel is not sent through `SendToNet`. **A new record
type needs an entry in `NetMessageSize` before it can be sent at all.**
**`MyStationState` is one global written from FOUR threads** -- the main thread, the
WinKeyer reader (`uWinKey`, its busy bit), the CPU keyer's CW thread and the paddle thread
(both through `PTTOn`/`PTTOff` -> `PTTStatusChanged`). Not the radio poller (its
`PTTStatusChanged` calls are commented out). Issue 132's audit said all callers were main
thread; that was wrong (review M12, 2026-11-16). `SendStationStatus` now holds
`GStationStateLock` across the fill and the send, so the record cannot tear.
`SendMessageStatus`'s local record is still not zeroed.

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

## Time sync is REMOVED, and its message id is KEPT (2026-11-03)

NY4I: "Synchronize time on all computers" (Net menu, Ctrl+Alt+T) let one station
set every other station's SYSTEM CLOCK. That is a permissions question, so the
feature is gone: the menu row and `menu_alt_setnettime` (10326) and its
accelerator, `SendTimeSyncToNet`, the client's receive body and its
`SetSystemTime` call (so `uNet` no longer `uses Windows`), the server's relay and
its `ALLOW TIME SYNCHRONIZING` ini key (`sAllowTimeSynchronizing`, `dmTimeSyn`),
the `TNetTimeSync` record, `RC_TIMESYN`, `TC_SENDTIMETOCOMPUTERSONTHENETWORK` and
`TC_COMPUTERCLOCKISSYNCHRONIZED` (lang tables, `uTR4WStrings`, the `.pot`, all
catalogues).

**`NET_TIMESYN_ID` (1070) AND ITS 20-BYTE FRAME (`NET_TIMESYN_SIZE`, VC) STAY, as
a recognised no-op.** Evidence: the HELLO handshake refuses only stations whose
`NET_PROTOCOL_VERSION` differs, and every 5.x build released before this change
speaks protocol 2, is admitted, still has the menu row and still sends 1070. The
framing has no length prefix, so a station or server that does not know the id
cannot find the end of the message: the client's `ConsumeNetBuffer` would
`Desync` and the server would DROP the connection (unknown id). Hence
`uNetFraming.NetMessageSize(NET_TIMESYN_ID)` = 20, an explicit client arm (one
Debug line per link, `GTimeSyncNoted`, never touches a clock), and an explicit
server arm (skips 20 bytes, does NOT relay, Debug line -- the generic `else` arm
would Warn "not one the server handles" per packet). Nothing builds the packet
any more. The out-of-tree TR4WServerPy still relays 1070 blindly, so a new client
can still receive one through it; it is skipped the same way.
The alternative, bumping `NET_PROTOCOL_VERSION` to drop the id, would refuse every
deployed 5.x station and was not taken; it is NY4I's call if the id is ever to go.
Pins: `uTestNetClientPackets` (`Test_AnOlderStationsTimeSyncIsSkippedNotActedOn`: a
1070 followed by a spot in one buffer, consumed whole, spot handled, nothing
posted; a source read that no clock setter is in `uNet`), `uTestNetFraming` and
`uTestNetWireSizes` (the 20-byte frame), `tools/netprobe --case time` (skipped,
not relayed, the line behind it relayed, A still connected). Bench: BENCH_QUEUE,
"AN OLDER STATION'S TIME SYNC IS SKIPPED".

## The link can go through a Tailcat tunnel (issue 293, 2026-11-12)

`SERVER USE TAILCAT` on: the link does NOT connect to `SERVER ADDRESS`. It
connects to `127.0.0.1` at a port `uNetTunnel` answers, and
`utils/uTailcatForwarder` carries the bytes through the tunnel that
`SERVER TAILCAT ADDRESS` (a secret) names. `TNetClient`, the write queue and the
catch-up download are UNTOUCHED: they are given a different address, in
`uNet.ConnectToTR4WServer` and `uGetServerLog.StartServerCatchUp`, and nowhere
else. Both server ports travel (port and port + 1), each with its own local
door on a port the system picks.

- **`utils/uTailcatLib` is the only unit that names the library** (`libtailcat`,
  upstream's own C ABI, version 1, checked at load). Loaded at run time from
  `PrivateLibraryDir`, only when the box is ticked, and NEVER unloaded (it
  embeds a Go runtime; the header says so). Upstream builds 64-bit only, so a
  32-bit TR4W reports that and stays down.
- **The tunnel is opened on the CONNECT THREAD** (`NetTunnelOpen` blocks: load,
  reach a relay, ping the server, up to 15 s). `NetTunnelSyncPort` and
  `NetTunnelClose` do not wait on the network and run on the main thread.
- **Lifetime:** one tunnel, kept across a DROPPED link (`NetLinkWentDown` alone
  leaves it), closed by `NetLinkDisconnect`, `NetLinkShutdown`, an unticked box,
  and a connect through it that FAILED -- so the next attempt pings again,
  which is the only step that can say whether the tunnel or the server is at
  fault.
- **A tunnel that cannot open is told to the operator ONCE PER RUN, as one short
  line** (`SNetServerNotAvailable`, latched by `uNetLink.TakeUnavailableNotice`;
  the reason is a Warn in tr4w.log, then Debug on the retries) and is never a fall back to
  `SERVER ADDRESS`. A wrong address and a server that is not running look the
  same: the address is the only thing that names the server.
- **NOTHING LOGS THE ADDRESS.** Log and status lines call the server `Tailcat`
  (`ServerNameForLog`); the library's error text has the address cut out.
- **Loopback only**, on purpose: a listener on every interface would hand the
  tunnel to the station's whole network.
- **Oracle:** `tools/netprobe` through the forwarder against TR4WServerPy with
  `--tailcat`, identical to the plain port (the one failure, TIMESYN relayed, is
  TR4WServerPy's own). What is NOT yet shown: the link inside a running TR4W,
  two separate networks, a tunnel that dies mid-contest. No unit test drives
  the forwarder; it needs the library and a relay.
- **The library is BUILT, never committed** (NY4I, 2026-11-12).
  `tr4w/build/tailcat.pin` is the one place that names the upstream commit and
  the Go version; `build/Build-Tailcat.ps1` (Windows) and
  `build/build-tailcat.sh` (Linux, macOS) read it, fetch that commit, fail
  closed on anything else, and write `libtailcat-NOTICES.txt` beside the
  library (the licence of every module linked in -- it must ship with the
  binary). **The server end must be built from the SAME commit**: upstream
  promises no stable wire format, so moving the pin means rebuilding
  TR4WServerPy's `libtailcat` too.
- **Open under issue 293:** the release workflow calling those scripts and the
  packages carrying the result (macOS: in `Contents/Frameworks` before
  `mac-sign.sh`), the in-tree `tr4wserver` as a tunnel server, a link status
  that says "tunnel up" apart from "admitted".

## A shared setting: who sends it, and what is said when it cannot go (issue 315, 2026-11-16)

- **The parameter packet (`TParameterToNetwork`) carries 255 BYTES per field**;
  `uNet.ParameterFitsTheWire` decides, `SendParameterToNetwork` refuses an
  over-long value and logs a Warn. **It no longer shows the operator anything.**
- **`uCFG.ShareWithPeers` is the one sender for `SHARED_WITH_PEERS` names**
  (`SetCFGCommandValue`, `ApplyContestEdit`). It tells the operator
  (`SNetParameterTooLong`, status line) when the value is too long WHATEVER THE
  LINK STATE -- the issue's complaint was that an offline edit was never reported
  -- and keeps the local value whole. MainUnit's INSERT MODE still calls
  `SendParameterToNetwork` directly (not a shared-list name; always fits).
- **PREFERENCES SENDS SHARED EDITS AT ITS SAVE** (2026-11-16, NY4I ruled the
  silence an oversight). Noted per command before the apply
  (`uCFG.NoteSharedPreferenceChange`, from `TSettingBinding.Save` and
  `TPrefsForm.ApplyIfChanged`), sent once by `uCFG.ShareNotedPreferenceChanges`
  in `TPrefsForm.SaveStore` through `ShareWithPeers` -- the LIVE value, and only
  when it differs from the first note's. **No echo:** `ApplyPeerCommand` forgets
  a pending note and never notes; `ApplyAndStoreCommand` (which it calls) does
  not note either. **The receive side refuses a POSITION'S OWN settings** (NY4I
  2026-11-19, "6. Yes"): `uCFG.CommandIsOnePositionsOwn` (BAND, MODE, CODE SPEED,
  CW TONE, WEIGHT, FARNSWORTH ENABLE/SPEED) is asked by `uNet`'s NET_PARAMETER arm
  BEFORE `ApplyPeerCommand`, so an older peer still sending one is logged (Info)
  and ignored. It is in the uNet arm and NOT in `ApplyPeerCommand` on purpose:
  `PersistCommandThroughStore` reaches `ApplyPeerCommand` for this station's OWN
  edit (a BOOLSWAP key on FARNSWORTH ENABLE), which must still apply. Every other
  name is applied as before (a secret excepted).
- **NO RE-SEND ON LINK-UP** (NY4I 2026-11-19, "7. no. only upon request"). Shared
  values go only when an operator changes one. **No request path exists:**
  `SM_GETSTATUS` asks for station status only; a settings request would be a new
  message (a protocol change) and was not built.
- **THE SHARED LIST AFTER NY4I'S RULINGS (2026-11-19).** The list was audited
  against D7's intent ("settings that affect the entire operation"); D7 4.x had
  crNetwork=1 on 355 rows by DEFAULT, so it is not a statement of intent. Removed:
  CONTEST (on a peer it would switch the contest mid-session), MY CONTINENT,
  INITIAL EXCHANGE CURSOR POS, the thirteen names that resolved to nothing, and
  CONNECTION COMMAND. Added: the contest-wide settings (QSO POINTS x4, MULT BY /
  QSO BY BAND and MODE, QSO NUMBER BY BAND, COUNT DOMESTIC COUNTRIES, DOMESTIC
  FILENAME, MULTIPLE BANDS/MODES, HF/VHF/WARC BAND ENABLE, SPRINT QSY RULE,
  MINITOUR DURATION, R150S/RFOBL MODE, LITERAL DOMESTIC QTH, DIGITAL MODE ENABLE,
  QTC ENABLE/EXTRA SPACE/MINUTES/QRS, MULT SHEET AUTO RESET, CUSTOM INITIAL
  EXCHANGE STRING, INITIAL EXCHANGE OVERWRITE, TEN MINUTE RULE). NOT shared, by
  ruling (operator-specific): the QUICK QSL messages, AUTO DUPE ENABLE CQ / S AND
  P, EXCHANGE MEMORY ENABLE. Pinned in `uTestNetClientPackets`
  (`Test_TheSharedListIsTheRuledOne`, `Test_APeersOwnPositionSettingsAreRefused`).
  The unit tests pin the names that are ON the list and a set of names that are
  not; they do not count the list, so a name added by mistake that no test names
  would pass.

## A station on another BUILD is reported, never refused (issue 120 item 4, 2026-11-19)

NY4I: *"Clients should all be same version as server or report it."* The HELLO
already carries `hmAppVersion` (16 chars), so **no wire change and no protocol
bump**. `uNetHello.JudgeAppVersion(ours, theirs)` -> `avSame | avDiffers |
avUnannounced` (text compare, case and blanks ignored; an empty version is
unannounced, never a difference). A difference is a REPORT and never a refusal:
`JudgeProtocol` alone decides who may talk.

- **A station** (`uNet.ReportPeerVersion`, from `HandleHelloReceived` after
  `GPeers.Announce`): one Error line and ONE operator notice (`SPeerOnAnotherVersion`)
  per (station, version) per link, through `TNetPeers.FirstNotice` with
  `VersionNoticeKey` (starts with a control character so it cannot equal a contest
  id). The notice goes to `PeerContestNoticeSink` when set, else `QuickDisplay`.
  `NetPeers.Clear` at link-up re-arms it.
- **The server** (`tr4wserverUnit.AcceptHello`): one Error line per ACCEPTED HELLO
  from a station whose version differs from the program version the server was
  built from (`TR4W_CURRENTVERSION_NUMBER`). It sends the stations nothing (each
  reports for itself) and does not latch: a contest change re-sends the HELLO and
  logs again.
- **What is NOT compared: the server's own HELLO version** (`TR4WSERVER_CURRENTVERSION`,
  '1.41', a number series of its own, not the program's) -- so a station cannot
  tell that the server it joined is another build; only the server's log can.
  TR4WServerPy has no equivalent. The in-test HELLO feeders (`uTestNetSupport`,
  `uTestContestById.FeedHello`) announce THIS build's version, or every one would
  raise the report.
- Tests: `uTestNetHello.Test_TheBuildJudgement`,
  `uTestContestById.Test_APeerOnAnotherBuildIsReportedOncePerVersionAndNeverRefused`.

## A peer's QSO carries the place its rover sent it from (issues 133/87, 2026-11-19)

- `ContestExchange.ceRoverQTH` (`string[10]`, offset 331, log schema 12) was
  carved from `sReserved`; the packet is still 384 bytes, no protocol bump.
  An older station's byte 331 is 0, so it reads ''. UNLIKE `ceOffContest`,
  the receiver KEEPS it: it is that QSO's own fact (the place the PEER sent
  it from), not a rule this station re-judges. The `.TRW` reader clears it.
- A boundary entry logs one QSO per place (`MainUnit.TEntryLegs`, legs of ONE
  `LogEntry` since issue 348), so a peer receives one packet per place, each
  with its own `ceRoverQTH` -- posted in leg order, and only after the whole
  entry committed; a refused entry sends no packet for any leg.

## Coordinate with

`log-database` (row-level sync is the destination) · `contest-scoring` (dupes,
mults and serial lockout cross the link) · `lcl-ui` (`uServerLogForm`) ·
`build-release` (the server is a separate build target).
