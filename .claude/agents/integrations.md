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

**The Preferences External Logger page edits DEFINITIONS in its grid (issue 220,
2026-11-05; `docs/EXTERNAL_LOGGERS_DESIGN.md` is authoritative).** `uExternalLoggerGrid`
is the view over the Preferences working copy of `TExternalLoggerConfig`; the order
rules live in the config class, not the grid. Facts that are easy to get wrong:
**Order and Send new QSOs are one fact** (membership of `ActiveIds`; a dash is an
inactive logger, not a bug). **`ActiveIds` order IS the delivery order**, so every
reorder path (drag, Move up/down) must end in `ApplyOrder`. **The LCL starts a row drag
only from a FIXED column** (`gzFixedRows` in `grids.pas`), so Order is the fixed column;
a drag fires `OnColRowMoved` after the cells have moved, and the grid then re-maps its
own selected row, so a `Row :=` assigned inside the handler is applied twice (the
selection is put right in a queued call). The hidden Id column carries identity because
a dragged row carries its cells. `Definitions` is an owning `TObjectList`: reorder with
`Exchange`, never `Move`. **The Enabled column (issue 226, 2026-11-06) is that same
flag as a real LCL checkbox column** (`cbsCheckboxColumn`, cells `'1'`/`'0'`, no
`goEditing`): the click is the grid's own, on mouse RELEASE on the cell it was pressed on
(toggling regroups rows), and Space; a refused activation must `Refresh` or the box stays
ticked. It changes the Preferences working copy only -- **applying is restart**, because
`TExternalLoggers` is immutable once started (`FActive`/`FCommandCount` are set in `Add`;
live apply is issue 218). **The Connection column** is
`DeriveExternalLoggerState(enabled, known, snapshot, counts)` in `uExternalLoggerService`:
`StateSnapshot(deliveryId)` on the composite (keyed by DELIVERY id, so an edited
destination reads "not running"), the worker's `FillSnapshot` (locked `FStatusLock` fields:
busy, last outcome and code, halted -- never `TakeNotice`, which consumes the notice the
owner shows), `TDurableExternalLogger.FillSnapshot` (capture paused, setup required,
stalled), DXKeeper's queue depth. Main thread only. Old failed/uncertain rows are counts
in the text, not a Failed row. A CA-bundle-missing delivery is a RETRY, not a pause
(`ApplyNothingSent`); auth policy and URL refused halt the worker. The 5 s timer rewrites
State cells only (hidden ordinal column feeds `OnPrepareCanvas`; the selected row keeps the
theme colours). Removal leaves the vault and queued deliveries alone (design
doc). The single-definition editor is `uExternalLoggersForm`; the shared OK checks are
`ExternalLoggerConfigAcceptable`. The real drag, the popup and the modal editor are
bench-only (BENCH_QUEUE).

**A PROVIDER DECLARES ITS EDITOR ROWS; THE EDITOR NAMES NO PROVIDER (issue 227,
2026-11-06).** The `lcf*` flag set is gone. `RegisterExternalLogger(id, name, ctor,
declarer)`: the declarer fills a `TLoggerFieldList` (`AddText/AddPort/AddSecret/
AddChoice`), built afresh on every `CreateFields` because captions are resourcestrings
(a copy made at registration is never translated). `ExternalLoggerDefinitionError`
reads the same list: required text, port range, and a choice needs its value AND
`Account`; a secret is never required (a locked vault leaves it empty and the logger
must still start). A registration is a class owned by the registry. Facts that bite:
**WRL's account id and logbook id are never fields.** The logbook is a CHOICE
(`LF_LOGBOOK` with `LF_LOGBOOK_NAME` beside it); the loader (`LoadWRLLogbookChoices`,
over `uWRLClient.WRLReadAccountId/WRLReadLogbooks`) runs
on a worker thread on a private copy of the definition and derives `Account` from the
key's uid. **The editor writes that account only when the operator picks or the key
changes** -- a hand-typed or migrated account is part of `DestinationFingerprint`, so
refreshing a list must not move the queue. `LogbookName` is display only and OUT of the
fingerprint (pinned with a literal `DeliveryId`). **There is no WRL setup dialog and
no provider setup action (issue 231, NY4I): TR4W does not create WRL logbooks**; the
operator uses the WRL website or app, and the editor's own load/Refresh validates the
key. Do not restore `uWRLSetupForm`, `WRLSetupAction` or `TWRLClient.CreateLogbook`.
A provider declaring more than `EXTERNAL_LOGGER_MAX_FIELDS` rows fails a test. Pinned
in `uTestExternalLoggerFields`.

**THE EDITOR'S ROWS ARE ANCHORED LEFT AND TOP ONLY, AND THE EYE ANCHORS TO ITS EDIT
(issue 231).** `BuildRow` creates each row panel at its default 170 wide and Align
stretches it to 670; a control with `akRight` moved by the whole 500, so the key's eye
sat over its box (measured gap -500) and the Logbook drop-down's arrow and Refresh were
pushed out of the row. `uPasswordReveal` now anchors the button's sides to its EDIT
(`AnchorSideLeft` at the edit's right, top and bottom to the edit's), not to the
parent, so it follows whatever the edit does. A test that streams a form and never
shows it cannot see this: `uTestPasswordRevealLayout` SHOWS the editor and the input
prompt off screen and measures. The row captions and heights are 96-dpi pixels,
unmeasured at 150%.

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

**A worker that notifies its owner by callback dispatches it UNDER the lock that
`ForgetOwner`/detach takes (WRL, peer review R1, 2026-11-04).** A stalled worker is not
joined at close, so it outlives its owner; copying the callback and calling it after
releasing the lock leaves a call in flight that detach cannot revoke. The callback only
queues work (`Application.QueueAsyncCall`), never waits on the main thread (detach may be
holding the main thread at that very lock) and never re-enters `TakeNotice`.
`RemoveAsyncCalls` runs only AFTER detach has returned. Pinned by
`TWRLDeliveryTests.TestNoticeForgetOwner`; rule also at the head of `uWRLWorker.pas`.

**The HamScore score tick publishes only from a successful read (R2, 2026-11-04).**
`CalculateTotals` returns False WITHOUT raising when the log source will not open, after
zeroing the totals; building XML from them posts a zero score. `uScoreBreakdown.RebuildScoreXml`
(seams for the read and the build) decides; a failed read keeps the last XML, leaves the dirty flag set, and warns once per
streak. A successful read of an empty log still publishes zeros.

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

## What the HTTP layer logs, and TLS that cannot start (NY4I, 2026-11-05)

**The URL is logged; the secret never is.** `uHTTPDownload` writes method, URL, exception class
and message for every failed request, credentialed or not, and one DEBUG line per request (tag `[HTTP]`; method, URL, headers, body -- what we send, never what we receive)
(secrets are a fixed `********`: `POST <url> Authorization: Bearer ********`). The older rule -- log nothing about the URL
or exception of an authenticated request -- is gone. What replaced it is `ScrubSecret`: the
bearer token and the form password (raw and URL-encoded) are scrubbed out of ALL of it, because
a server's error text can echo what we sent. `MaskSecret` is the one mask. A new log line in that
layer for a credentialed request goes through them; `uTestHttpSecrets` captures the Log4D output
and fails if the fake token appears.

**TLS that cannot start is a proven pre-request failure.** `THttpRequest.TlsUnavailable` is set
when https was asked for and `EnsureOpenSSL` said no: no byte was sent. Club Log and WRL map it
to `doRetry` (`CLUBLOG_TLS_UNAVAILABLE` / `WRL_TLS_UNAVAILABLE`, 300 s), NOT `doUncertain`.
The diagnostic goes to the log once per distinct text. `EnsureOpenSSL` is locked (workers call
it) and on Windows retries a failed load after 30 s; Linux/macOS keep the first answer. The test
seam is `SetOpenSSLForcedUnavailable`.

**A missing or unreadable CA bundle is the same class (issue 221, 2026-11-05).**
`THttpRequest.TrustBundleMissing` is set when `ApplyTLSVerification` refused and
`uTLSTrust.TrustBundleUsable` is False (`TlsUnavailable` stays False; `Send` resets both at its
top). Club Log / WRL map it to `doRetry`, 300 s, `CLUBLOG_CA_BUNDLE_MISSING` /
`WRL_CA_BUNDLE_MISSING`, status 0. **Search order** (`TrustBundlePath`, the one resolver for the
existence check, the handshake's `CertCA.FileName` and the messages): the data directory
(`DataFilePath`, the working directory on Windows), then `uAppPaths.BesideProgramFilePath` (the
exe's folder; macOS Resources, which is the data directory already). First USABLE file wins
(exists and opens); which place answered is logged once (`[TLS] CA bundle: <path> (<tier>)`). The
"REFUSING" Error line is latched per distinct reason. **The operator is told once per service per
session:** the client puts `uTLSTrust.TrustBundleAlertText(service)` (resourcestring
`SCaBundleMissingNotice`; '' after the first) in `TExternalDeliveryResult.OperatorNotice`, the
worker passes it to `Notice`, and the owner shows it on the main thread through its
`QueueAsyncCall` + `showwarning` path (`TDurableExternalLogger.ShowDeliveryNotice`, which shows
one notice per owner: `FReported`). Nothing visible is touched from the worker. Seams:
`SetTrustBundleFolders`, `ResetTrustBundleLatches`. NOT done (issue 221 remainder / 224): an OS
trust-store fallback and a platform transport. The other HTTP callers (version check, CTY, POTA,
HamScore, SCP) only read `FailReason` and are unchanged.

**THE WIRE IS A TRANSPORT BEHIND `uHTTPDownload` (issue 224, S1a, 2026-11-05;
`docs/HTTP_TRANSPORT_DESIGN.md` is authoritative).** `uHTTPDownload` is the SHARED layer: verbs,
`THttpRequest`, scheme and bearer policy, the verify-or-not policy, ALL logging and scrubbing.
`uHttpTransport` is the contract (failure kinds, wire request/result, `NothingSent`, the
registry); `uHttpTransportGeneric` is the FPC `TFPHTTPClient` + OpenSSL + `uTLSTrust` path that
used to be written out in `uHTTPDownload`. Rules that are easy to break:

* **A transport never logs a URL, a header, a body or an exception message.** It returns them in
  the result; `uHTTPDownload.RunTransport` scrubs and logs (the once-per-reason latches live
  there). `Test_TransportErrorTextCannotReachALogOrTheOperator` pins it with a fake whose error
  text echoes the token.
* **`NothingSent(kind)` is the ONE place that says a failure proves no byte left.** The generic
  transport can prove only `hfTlsUnavailable`, `hfTrustUnavailable` and
  `hfVerificationUnavailable` (all before the connection); anything raised once the client is
  moving is `hfOther` / `hfTlsLibraryFault` / `hfResponseTooLarge`, "may have been sent". Do not
  promote an exception to a nothing-sent kind because it looks like a refusal.
* **Selection is once, logged, and there is NO per-request fallback** (non-idempotent POSTs).
  Tests that must not depend on a platform transport name `TGenericHttpTransport` or install a
  `TFakeHttpTransport` with `SetHttpTransportForTest`; `uTestTLSRefusal` and `uTestHttpSecrets`
  run against the registry's generic default.
* `THttpRequest.TlsUnavailable` / `TrustBundleMissing` are properties over `Failure`, readable
  and writable (stubs assign them). `AcceptAnyStatus` and `HasBody` on the wire request exist to
  keep the Get verbs (`[200]` only, no body) and `Send` (any status, always a body stream, so
  `Content-Length: 0`) byte-identical to what they were.
* **Club Log and WRL classify by `NothingSent`, through ONE function:
  `uExternalDeliveryClient.ApplyNothingSent`** (S1b). Do not read `TlsUnavailable` /
  `TrustBundleMissing` in a client again. Table in the design doc (S1b as built): TLS, bundle and
  verification-unavailable are retry 300 s (`*_TLS_UNAVAILABLE`, `*_CA_BUNDLE_MISSING`,
  `*_VERIFICATION_UNAVAILABLE`); the bearer gate is a PAUSED retry (`*_AUTH_POLICY`); plaintext
  or no scheme is a PAUSED failure (`*_URL_REFUSED`); any other proved kind is `*_NOT_SENT`.
  **The CA-bundle `OperatorNotice` is raised for `hfTrustUnavailable` and no other kind**
  (`uTestNothingSent` loops every kind). A failure that may have been sent keeps its old
  answer (uncertain for a POST). Pinned in `uTestNothingSent`.
* The Get verbs FOLLOW redirects (pinned by `Test_AGetStillFollowsARedirect`); S1c decides the
  https-to-http hop. No Windows or macOS transport exists (S2+ wait for NY4I's section-8 answers).

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
