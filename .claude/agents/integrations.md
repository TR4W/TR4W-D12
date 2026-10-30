---
name: integrations
description: Third-party program integration — WSJT-X (UDP), MMTTY (RTTY), and the external logger factory (DXKeeper, ACLog, HRD). Use for digital-mode interop, decode handling, colorization hints, QSO hand-off to another logger, or anything about an out-of-process companion program.
tools: Read, Grep, Glob, Bash, Edit, Write
model: sonnet
---

You own TR4W's links to other programs on the operator's desk.

## Your files

| | |
|---|---|
| WSJT-X — UDP | `tr4w/src/uWSJTX.pas` |
| MMTTY — RTTY | `tr4w/src/uMMTTY.pas`, `src/ui/lcl/uMMTTYForm.pas` |
| external logger factory | `uExternalLoggerFactory.pas` |
| abstract base | `uExternalLoggerBase.pas` (`TExternalLoggerBase`) |
| implementation | `uExternalLogger.pas` (~~`uExternalLoggerManager.pas`~~ was never linked; deleted 2026-10-16) |
| outbound delivery of a QSO | `uQsoDispatcher.pas` (thread, queue, message) and `uQsoSinks.pas` (UDP, external logger, HamScore sinks) |

Globals in `MainUnit`: `wsjtx: TWSJTXServer`, `externalLogger: TExternalLogger`.

## WSJT-X

UDP; sends colorization hints, receives decodes and QSOs. Enabled with
`WSJT-X ENABLE = TRUE`.

The UDP thread **does not write the entry fields** — that separation was a fix,
not an accident. Highlighting had two separate defects before it worked reliably;
dupe and new-multiplier colouring in the decode list is the visible contract.

**The UDP handler runs on Indy's listener thread** (`ThreadedEvent := true`), so
anything it does that reads the dupe sheet, the multiplier structures or
`ActiveContest` is a data race with the main thread -- `ActiveContest` can free
and rebuild the contest object on EVERY call. Fixed 2026-10-14 for the CQ decode:
the listener parses and copies; `PostCQDecode` queues a job of VALUES through
`Application.QueueAsyncCall` (FIFO, not `TThread.Queue`, which purges a thread's
entries when it is destroyed), and `EvaluateCQDecode` -- which refuses off the
main thread -- does the dupe/mult test and sends the `HighlightCall` reply.
`Stop` detaches queued jobs from the server; a detached job is popped and dropped.
`HighlightCall`'s `SendBuffer` is thread-neutral (the binding is fixed when the
server goes Active), so the reply was never the problem.

**All four UDP messages that touch program state are handed off now** (same day):
CQ decode, STATUS, CLEAR and LOGGED ADIF -- `PostCQDecode` / `PostStatus` /
`PostClear` / `PostLoggedADIF` copy values into ONE FIFO, and the matching
`Evaluate*` runs on the main thread and refuses elsewhere (`OffMainThread`).
`EvaluateLoggedADIF` is the one that LOGS A QSO. Do not add a second queue:
the one order is what keeps a QSO's LOGGED message beside the STATUS and decodes
around it, and the entry-field work an evaluation starts is queued behind it.
**A logged QSO is never dropped:** `Stop` (main thread, listener already down)
evaluates every pending LOGGED job in FIFO order before it detaches; pending
STATUS/CLEAR/CQ jobs are dropped as transient. `tr4w_ShutDown` calls
`wsjtx.Stop` before `LogStoreClose`, so the log is still open. A `LOST QSO` ERROR
with the ADIF text is the last resort only (a LOGGED job surviving to
finalization, a Stop off the main thread, or a failure while logging). The heartbeat and close arms only set
`WSJTXState`, which is what a network thread is for.

**The TCP command handler is still off the main thread, on purpose.** It is
request/response against WSJT-X's ~1 s deadline and CmdTX/CmdRX are PTT, so
queuing is wrong for it; it reads the radio status record unsynchronised and
writes `Settings.Ptt.ViaCommands`. That belongs to the radio-status snapshot work.

**`destructor Destroy;` without `override` is a WARNING, not an error, and `Free`
never reaches it.** `TWSJTXServer`'s did not, so `FreeAndNil(wsjtx)` leaked the
sockets until 2026-10-14. Check the keyword on any destructor you add.

## The local UDP score (`dynamicresults`)

`logsubs2.BuildScoreUDPXml` / `PostScoreToUDP` feed N1MM-style listeners and WRTC's
local aggregators. **It is never suppressed by a contest's score-posting permission**
(NY4I, Q109: *"dynamicresults is perfectly fine for wrtc. That was its original
purpose"*) -- only the ONLINE builder (`uGetScores.BuildDynamicResultsXml`) and
HamScore ask the contest. The mode loop runs `CW to Both`: the ALL rows carry
qso/mult/point, and WRTC's HQ/country labels appear only there. Each `total` row is
its own mode's bands summed. Pinned in `uTestUDPDatagrams`.

**`<contestnr>` (contactinfo, contactreplace, contactdelete, lookupinfo) is
`uContestRegistry.ContestBroadcastNumber`, the only place** (Q108 S4,
2026-10-17): the legacy number for a legacy contest -- pinned, it did not move
-- else `256 + CRC32(the id) mod (2^31 - 256)`. N1MM's appendix defines it as
*"a unique number assigned to this contest instance in this database"*: local
to a log, no range, never a shared contest code, so any stable per-contest
number serves. Never write `Ord(...)` of a contest there again.

**A logged QSO's UDP record reads the RECORD, never the radio** (2026-10-25, NY4I).
`BuildUDPContact` sends `RXData.Frequency` (stored at log time) as rxfreq AND txfreq for
contactinfo and contactreplace; split TX is not recorded, so there is no separate TX
value. Band default only when the record's frequency is 0. A whole-log resend once put
the radio's frequency on 53 QSOs across four bands. Only `lookupinfo` (the call being
typed NOW) reads the live radio. `<operator>` is `RXData.ceOperator`. Pinned in
`uTestUDPContactXml`.

## MMTTY

**MMTTY is out-of-process** — launched with `WinExec`, not loaded as a DLL. That
matters for one reason worth stating: **it does not block the 64-bit work.**

The `MMTTYMODE` compile-time switch was **deleted 2026-08-18** (NY4I: *"the
boolean controls it now"*). It had been `True` for the life of this tree, so all
20 of its `{$IF}` blocks always compiled and one `{$IF NOT MMTTYMODE}` block never
did. Do not reintroduce a compile-time gate here.

**An address handed to the RichEdit is `LPARAM(@...)`, never `integer(@...)`**
(pointer audit P2, 2026-10-16). Three `SendMessage` sites in `uMMTTY` and
`uMMTTYForm` used `integer`, which is exact on i386 and, with the x86_64
image based at `$100000000`, would have handed RichEdit half the address of
`MMTTY.mmttyCF` / `mmttyTwoBytes`. `Lint-PointerTruncation` fails the build on
the integer form. RTTY text display has no automated oracle -- it is in
`docs/BENCH_QUEUE.md`.

## The QSO dispatcher -- ONE thread delivers to every outside program (2026-10-24)

**Why:** two QSOs in CQ WW SSB froze the main thread 2.7 s each (tr4w.log
`Milliseconds to send UDP...` = 2702 / 2680; the others 2-6 ms). External logger and
HamScore were off, so the UDP broadcast ran inline on the Enter key to a destination
named by HOST NAME. Indy resolves it on every send. The DNS cause is an inference (DNS
client log was off); the fix does not depend on it.

**UDP destinations resolve per send through the platform resolver (issue 148,
2026-10-28):** `LogCfg.SendUDPPayload` calls `uHostResolve.ResolveHostForConnect`
before `gUdpLock` and hands Indy the address (Windows: unchanged). Deliberately
UNCACHED (NY4I: staleness over UDP is silent; the OS resolvers already cache with
real TTLs). A failure raises and the broadcaster's per-destination containment logs
it and moves on. The lookup is inside the timed region, so the slow-send warning
still counts it.

**Shape (NY4I):** the main thread builds an immutable `TQsoMessage` and `Post`s it,
nothing more. `TQsoDispatcher` (own thread, bounded FIFO) fans each message to the
`TQsoSink`s in order: UDP, external logger, HamScore. A sink that is slow (> 250 ms, Warn
naming the sink; the broadcaster also names address:port) or raises is contained.

- **A message holds RESULTS, not state.** Whatever reads live state (Settings, contest,
  radio status, CTY, operator) is read by the BUILDER on the main thread and stored as
  text: `logsubs2.PostQsoEvent` / `PostLoggedQso`, `HamScorePrepareInfo/Delete`,
  `TExternalLogger.PrepareOp`. Those reads are NOT thread-safe (the contest object can
  be freed and rebuilt on any call) -- do not move a Prepare onto the dispatcher thread.
  The sinks' `Wants`/`Deliver` read only their own locked configuration
  (`UDPBroadcaster`'s swap-under-lock `Configure`) or hand a finished value to a queue
  (`SubmitOp`, `HamScoreSubmit`).
- **`UDPBroadcaster.SendNow` / `SendDirect` BLOCK and are for the dispatcher thread
  only.** It was `Send` and the rename is the guard: every old inline call stopped
  compiling. UDP from anywhere else goes `QsoDispatcher.PostUDP` / `PostUDPDirect`
  (score, radio -- from the poll thread --, rotor, lookup, PstRotator).
- **The Indy `udp` client is not shared:** `LogCfg.SendUDPPayload` holds a lock. The
  Test button (`TestDestination`) stays SYNCHRONOUS on purpose -- an operator asking
  "does this work", expecting the answer in the dialog -- and so waits behind a send in
  progress; it is not on the logging path.
- **Queue:** `QueueLimit` 256 counts DROPPABLE messages only (lookup, score, radio,
  rotor): at the limit the oldest droppable goes. A QSO-bearing message (new, edited,
  deleted) is NEVER dropped and Post never refuses it -- the full-log UDP resend and the
  HamScore resync post thousands; they grow the queue (~0.5-2 KB each). Drops are logged
  once per episode (ends when the queue empties). Order is global FIFO, so a stalled
  destination delays the ones behind it -- the price of one thread; the Warn names the
  destination if it ever matters.
- **Shutdown:** `ExitProgram` calls `QsoDispatcher.Shutdown(1000)` BEFORE freeing `udp`;
  `externalLogger` and the HamScore uploader are freed later and must outlive it. False
  means a sink is stuck: do not free what it uses.
- **Not a sink:** multi-op `SendRecordToServer` (multi-op-network; ordering and serial
  lockout).
- **HamScore re-send is the ONLY path to `<deletelog>`, and it asks (2026-10-29).**
  `MainUnit.HamScoreResyncWithConfirmation` (Tools menu AND the status window's
  button) shows a `QuestionDlg`: Re-send only / Delete and re-send / Cancel (default
  and Escape). Only "Delete and re-send" calls `HamScoreResyncFromScratch`. The
  button used to queue the `<deletelog>` alone, no prompt and no re-upload. NOT
  KNOWN: what the real server does with a re-sent QSO (replace or duplicate) --
  the code only shows the original `<ID>` is sent, and the comment at
  `HamScoreOnEdit` says the server tells new from edit by ID-already-seen;
  no RTC spec is in the repo. `QuestionDlg` custom captions must be ansi strings
  (`LclText`), never a UnicodeString, or its parser raises.
- **Their own threads stay:** the external logger's `TSenderThread` does connect-per-
  command with retry/backoff; the HamScore uploader batches on a 2-minute cycle with
  retry. Neither exists merely to get off the main thread.
- Tests: `uTestQsoDispatcher` (stub sinks), `uTestUDPBroadcaster`, `uTestUDPDatagrams`
  (runs the dispatcher `Synchronous`).

## External loggers

| type | status |
|---|---|
| `lt_DXKeeper` | Complete |
| `lt_ACLog` | **Incomplete** — the factory logs a warning on creation |
| `lt_HRD` | **Incomplete** — same |

Each logger runs its own `TReadingThread` / `TSenderThread` pair.

**Only the reading thread may call Indy's `Connected`** (2026-10-25, after the
network-radio hang a4866344): it does a select plus a BLOCKING recv, so from any other
thread it can hang for ever or steal the reader's bytes. A bare `Disconnect` is
`Disconnect(True)` and asks `Connected` first. Everywhere else: `IndyLinkIsOpen`
(`uIndyLink`, fields only) and `Disconnect(False)`; give the client an IOHandler it
owns (`uIndyLink.IndyLinkOwnHandler`) because Indy frees a managed one on a failed
Connect. **DXKeeper never uses the persistent `socket`**: `TExternalLogger.DeliverCommand`
opens a local client per command on the sender thread (its sole owner, no reader), so
`client.Connected` there is legal -- keep it that way. Nothing calls the base
`Connect`/`SendToLogger`/`IsConnected` in production today (ACLog/HRD are stubs and
`LookupCallsign` has no caller); the rule is for the day they do. Pinned in
`uTestExternalLoggerSocket`.

**ONE CONNECT AT A TIME, AND RECONNECTION IS THE READER'S JOB (2026-10-26, #102).** Every
connect goes through `ConnectGuarded` (`FConnectLock`): it returns at once if
`IndyLinkIsOpen`, and refuses (-4) a non-reader caller while a reading thread exists. The
reader reconnects through `ReconnectFromReader` (same lock, RAISES so its back-off still
sees the exception). `DoSocketConnect` is the single protected seam where the socket's
`Connect` is called -- a test counts attempts there. The timeout is
`uIndyLink.INDY_LINK_CONNECT_TIMEOUT_MS` (5000; Indy's `ConnectTimeout` is MILLISECONDS --
it was 10). `TFactoryRadioBase.Connect` still has its own literal 5000. Not pinned: the
reader-exists refusal (needs a live reading thread against a peer that stays up).
`TExternalLogger.LookupCallsign`'s DXKeeper arm called ITSELF until #101; it queues through
`QueueSingleCommand` like every DXKeeper command (never the persistent socket), and the
unsupported types return -1 -- assign `Result` on every path (`-gt`). Pinned in
`uTestExternalLoggerLookup` (a recording `DeliverCommand`).

**`TExternalLoggerBase.Destroy` was `overload; virtual`, hiding `TObject.Destroy`**, so
`FreeAndNil(externalLogger)` ran no destructor: no `ShutdownDrain`, queued QSOs lost at
exit unreported. It is `override` since 2026-10-25.

**This is the OLDER factory shape** — a `case` in one class function
(`TExternalLoggerFactory.CreateLogger`) raising
`EExternalLoggerFactoryException`, not the radio factory's self-registration
registry. **If it grows, move it toward the registry pattern rather than extending
the `case`.** That is the standing instruction, not a suggestion.

Note `TReadingThread` here owns its own `radioWasDisconnected` flag and holds no
radio reference — do not reach for a radio from inside it.

## Mode names on the wire (2026-10-23)

**Never send `VC.ExtendedModeStringArray` to another program** -- `DATA`,
`CW-R`, `FM-N`, `D-STAR`, `NoMode` are TR4W's own spellings. Two answers, one
each:

- **ADIF text** (export, the DXKeeper external log): `uADIF.ResolveADIFModeSubmode`.
- **N1MM-format XML** (the UDP contact broadcast, RadioInfo):
  `uN1MMMode.N1MMModeName` -- N1MM's name where it has one, else ADIF's;
  generic data is RTTY; SSB is USB/LSB by frequency (60 m USB).

Both are `array[ExtendedModeType]` tables, so a new mode fails to compile until
it has a row. Pinned in `uTestN1MMMode` and `uTestUDPContactXml`.

## Gone — do not restore

**MixW was deleted 2026-09-05** (NY4I: *"you can remove all traces of mixw. I
confused it with a different program"*). It was never working code: the whole unit
body sat inside `{$IFDEF MIXWMODE}`, a define that existed **nowhere** in the
tree, and defining it would not have helped — the var block was commented out and
`tw_MixWWINDOW_INDEX` was never declared. `SendMessageToMixW` compiled to an empty
procedure and its six live callers did nothing.

## SuperCheckPartial upload (2026-10-25)

`uSuperCheckPartialFileUpload`. **The signature is over BYTES:** `SCPSignature(secret,
fileBytes)` = SHA-256 of the secret's ASCII then the raw file bytes (`SHA256OfByteArrays`);
`SCPEncodeBase64` encodes the same array. `string` is UnicodeString here, so the old
`Move` of N file bytes into a `string` made garbage and the server answered 400. Read the
file once as `TBytes`; never route file content through a `string`. A failed POST keeps the
server's body (`EIdHTTPProtocolException.ErrorMessage`) in `errorResult` and `tr4w.log`.
Pinned in `uTestSCPUpload` against a hashlib digest. **The transport is `uHTTPDownload.THttpPost`
since 2026-10-26** (no Indy HTTP/SSL left; Indy is Base64 only). Certificate checking is
`ApplyTLSVerification`'s and fails closed. **TEST THE BYTES THAT ARE SENT, not just the values
signed:** production got HTTP 400 "key must be a string at line 1 column 2" because
`TStringStream.Create(<UnicodeString>)` is UTF-16LE in FPC 3.2.2 (`{` #0 `"` #0). `SCPRequestBody`
builds the text; `uHTTPDownload.CreateWireBodyStream` (a `TRawByteStringStream`, never a
`TStringStream`) is the one place a body becomes wire bytes. `THttpPost.Send` returns True for a
non-2xx (Post allows every status): `StatusCode` + `Response` carry the refusal, and
`SendFile` puts both in `errorResult`. Tests run a loopback HTTP fixture, no internet.
`TSCPUpload.Destroy` is `override` since 2026-10-26 (#103; it hid `TObject.Destroy`, so
`scp.Free` freed nothing). It frees http, sslOpts, indyLog. The logger-less constructor path
(`FLogger = nil`) builds an scp.log appender and `Configure`s it onto the GLOBAL root: the
field is an `ILogAppender` (Log4D appenders are ref-counted; a class field plus `Free`
freed an object the root still held) and the destructor `RemoveAppender`s it. The logger
itself is hierarchy-owned: never freed here.

## Prefer a reported error over a silent fallback

Several defects on this branch were silent downgrades. A companion program that
fails to start, or an incomplete logger type selected by an operator, should
**say so**.

## Coordinate with

`contest-scoring` (a decode becomes a QSO) · `log-database` (hand-off writes) ·
`multi-op-network` (the other UDP/TCP consumers) · `lcl-ui` (`uMMTTYForm`).
