# Commit before publish: a QSO leaves the station only after it is in the log

Status: **APPROVED (section 7). Commits 1-3 BUILT 2026-11-22, NOT WIRED** --
`AppendBatch`'s row ids and per-row hook, `LogStoreAppendLiveQSOs` (with
`LogStoreAppendQSO` as its one-leg call) and the sequencing leaf
`src/domain/uSubmitSequence.pas`. Nothing in `LogContact`, `TryLogContact` or
`DrainPendingMultiQSORefs` calls them yet: the program still publishes before
the append (commits 4-8 open). Detail and the decisions taken while building
them: `.claude/agents/log-database.md`, "ONE ENTRY, ONE TRANSACTION". Written
2026-11-21 against `main` at `6924737c`.

Two corrections found while building commits 1-2:
- **5a's "store enabled" after a leg refused by a trigger, or a refused
  commit, is not the live rule**: a constraint disables the store, as for one
  QSO today. Enabled holds for busy and a full disk.
- **`TLogRepository.ReprepareAfterSavepointRollback` refused inside a batch**,
  which would have turned a durable-delivery capture failure into a failed
  QSO. It now refuses only with the sequential cursor open.
Issues: **#347** (a QSO goes to the multi-op server, UDP, HamScore and an external
logger before it is saved) and **#348** (a county-line, multi-park or rover entry
can save only some of its legs). Source: `docs/QSO_LOG_INTEGRITY_REVIEW.md`,
findings 1 and 2. Agent areas: log-database (owner), contest-scoring,
multi-op-network, integrations, lcl-ui.

---

## 1. The current sequence (verified in the code)

### 1a. One row, entered by the operator (Enter)

| # | step | where | reads pre-QSO sheets? | leaves the station? |
|---|---|---|---|---|
| 1 | `ParametersOkay` parses the entry, mints a new exchange id `RData.ID := GetGUID`, stamps the time | MainUnit.pas:1257, 7896 | yes (scoring) | no |
| 2 | `LogContact`: refuses at once when the log is read-only or will not open (own QSO only) | logsubs2.pas:1717-1725 | - | no |
| 3 | auto time increment (it changes THIS QSO's time), `tLastLogEntryIsDeleted`, ten-minute rule | logsubs2.pas:1744-1763 | - | no (session state, NOT undone on refusal) |
| 4 | `StampOffContest`, rover place, dupe test and zero points, `ProcessMultipliers` (`Sheet.SetMultFlags`, a read) | logsubs2.pas:1787-1861 | **yes** | no |
| 5 | network ids: `ceQSOID1`, `ceQSOID2 := NextQsoSequence(...)`, operator, sent year, `ceSendToServer := False` | logsubs2.pas:1864-1882 | - | no |
| 6 | **`SendRecordToServer(NET_QSOINFO_ID)`**, posted to the writer thread | logsubs2.pas:1889; uNet.pas:3316-3353 | - | **YES, server and every other station** |
| 7 | **`PostLoggedQso`**: builds UDP text (with `SecondDomesticKeyForUDP`, asked "before the sheets below have the QSO"), the non-durable external-logger command, the HamScore body, and **posts** to the dispatcher thread | logsubs2.pas:1900-1907, 3315-3392 | **yes** (#318: `mo` as it stood) | **YES, UDP, HamScore, DXKeeper-style logger** |
| 8 | `tAddQSOToLog` -> `LogStoreAppendQSO` -> `AppendQSOOnce`: `BeginMainWrite`, live capture of station facts and sent exchange, insert with grouping, **durable-logger capture in the same transaction**, `Commit`, then `LogStoreStartExternalDelivery` | logsubs2.pas:1921, 2875; uLogStore.pas:2895-3068; uDurableExternalLogger.pas:101 | - | durable outbox only after commit (correct today) |
| 9 | on False: `Exit` (the entry stays typed, MainUnit.pas:1288-1295) | logsubs2.pas:1921-1924 | - | steps 6 and 7 are already out |
| 10 | on True: grid count and search refresh | logsubs2.pas:2886-2903 | - | no |
| 11 | serial high-water, initial-exchange history, totals, `Sheet.AddQSOToSheets`, `AddLoggedQSO(LogStoreLastAppendedMyFacts)`, dupe sheets, `SendStationStatus` | logsubs2.pas:1934-1969 | **this is the sheet mutation** | status packet |
| 12 | needs strips, rate counters, `CountQsoTowardPeriodicBackup` (may run `BackupLogNow` inline), `SaveRestartFile` (a store write), spots, `SendScoreToUDP` | logsubs2.pas:1977-2059 | - | score UDP |
| 13 | `TryLogContact` clears the windows, `SendSerialNumberChange` | MainUnit.pas:1297-1350 | - | serial lockout packet |

Durable external loggers (WRL, Club Log, QRZ, Cloudlog, ACLog;
`TDurableExternalLogger.PrepareOp` returns `xoNone`, uDurableExternalLogger.pas:83-89)
are **already correct**: their delivery row is written inside the QSO's
transaction under a `SAVEPOINT`. Only command-queue services
(`TExternalLogger`, `QueuesCommands = True`) get an event before the commit
(`TExternalLoggers.PrepareMessage`, uExternalLoggers.pas:292).

### 1b. Several legs from one Enter (county line, multi-park, rover boundary)

`TryLogContact` (MainUnit.pas:1288) runs `LogContact(ReceivedData)` - the whole of
1a, **committed and published** - and then `DrainPendingMultiQSORefs`
(MainUnit.pas:963): one full `LogContact` per queued park (984-993), per queued
county (994-1024, `ceClearDupeSheet := True`, the same serial), then one per rover
copy (`RoverBoundaryLegs`, 1034-1046). It stops at the first `False`. Every leg is
its own commit and its own publication, and each leg's step 4 reads sheets that
already hold the earlier legs (step 11). That ordering is load-bearing: a second
leg with the same call must not be flagged as a new country, prefix or zone again.

**Confirmed failure:** leg 2 fails, leg 1 is committed and published, the windows
keep the entry, and the next Enter parses again with a **new** exchange id
(MainUnit.pas:7896) - so leg 1 is logged twice, in two different `qso_set_id`s,
and the server and the other stations hold leg 1 twice under two network keys.

### 1c. WSJT-X

`TWSJTXServer` (uWSJTX.pas:1445-1483): `ParametersOkay`, then one `LogContact`;
stops on `False`. Same as 1a. It never drains queued legs (a rover at a boundary
logging FT8 records one place only - a separate gap, not in this plan).

### 1d. A QSO received from a peer

uNet.pas:1008-1068: contest gate and `ReceivedQsoIsKnown` (a store read), then
`LogContact(rec, False)` at 1032 with the **result ignored**, then
`UpdateWindows`. Inside, the `else` arm posts UDP (if `BROADCAST ALL QSOS`) and
HamScore (logsubs2.pas:1914-1917) **before** the append. A refused peer QSO is
never offered again by the server: it neither stores nor relays a duplicate
QSOINFO (tr4wserverUnit.pas:759-780). Notes and QTC records (1043, 1057) go
straight to `tAddQSOToLog` and do check it.

### 1e. Notes and QTC records

`AddRecordToLogAndSendToNetwork` (MainUnit.pas:10415; callers MainUnit.pas:4169,
uQTCR.pas:349, uQTCS.pas:325) sends at 10438 and appends at 10459. Its own comment
says "THE ORDER IS WRONG AND IS LEFT ALONE ON PURPOSE ... raised for NY4I". The
review does not mention it.

---

## 2. The target design

**Rule: the local commit is the release point.** Nothing reaches the network, the
dispatcher or a non-durable logger until `LogStore...` has returned True, and True
means COMMITTED (pinned today by `Test_R2_ACommitThatFailsIsNotReportedSaved`
and `TestEveryWriteWaitsForItsCommit`).

### 2a. Three phases per leg

| phase | what | when |
|---|---|---|
| **Prepare** | steps 3-5 as today, plus BUILD (do not post) the QSOINFO record and the `TQsoMessage` (UDP text with the pre-sheet second key, external command, HamScore body). Kept in a small per-leg holder. | before the write, reading the sheets exactly as today, so every payload is byte-identical by construction |
| **Score** | step 11 minus `SendStationStatus` and minus `AddLoggedQSO`: totals, sheets, dupe sheets. Only state that `LoadinLog` rebuilds (`Sheet.DisposeOfMemoryAndZeroTotals`, logdupe.pas:1233, clears dupe sheets, mults, `QSOTotals`, `MaxSerialSent`, `ContinentQSOCount`, points, the logged-QSO view, `tUSQ`). | see 2b |
| **Release** | grid refresh, `AddLoggedQSO(leg, aFacts[i])` with the facts the store returns (legs 0..n-2 are scored before any facts exist; the view is read by the final score's bonuses, not by Prepare - to re-check with `rg -i` in commit 4), initial-exchange history and serial high-water, then **post the packet and the dispatcher message**, then `SendStationStatus`, needs strips, rate counters, spots, score UDP; LAST `CountQsoTowardPeriodicBackup` and `SaveRestartFile` | after the commit only, legs in order. A due backup never delays the relay. |

On refusal: the held messages are freed, nothing is posted, the windows keep the
entry (as today), `ceQSOID2` is simply not used.

**Do not "tidy" the HamScore body onto the store's captured facts.** It is built
from `LogStoreCurrentMyFacts` today; `CaptureMyFactsNow` adds the rover override,
so switching would change the payload. Byte-identical payloads are the point.

### 2b. One submission, one transaction

- **Score lazily: a leg is scored just before the NEXT leg is prepared.** The last
  leg (the only leg, in a one-row entry) is scored after the commit. So a one-row
  entry mutates no score state before its commit, **exactly as today**, and needs
  no undo.
- A multi-leg entry scores legs 0..n-2 before the commit, because legs 1..n-1 must
  be prepared against them. **On refusal the store has rolled everything back and
  the session is rebuilt from the log with `LoadinLog`**, the path `RescoreLog`
  already uses. It must reach no store write (a full disk still reads); that is
  a CHECK in commit 5, not yet verified. Then `QSOSaveRefused` as today.
- The transaction lives inside ONE synchronous store call. It never spans
  `LogContact` calls: any store write in between (`SaveRestartFile`, a queued
  `SettleServerProgress` -> `LogStoreMarkServerProgress`) would commit it early.

### 2c. Store and repository API

| unit | change |
|---|---|
| `uLogRepository` | `AppendBatch` gains two optional outputs: the row id of each row, and a per-row hook `procedure(aRowId: Int64) of object` called after each insert inside the transaction. ADIF import and catch-up pass neither and are unchanged. |
| `uLogStore` | new `LogStoreAppendLiveQSOs(const aLegs; out aFacts; out aRowIds): boolean`. It is `AppendQSOOnce` generalised to N rows: `StampOffContest` each, live `CaptureMyFactsNow` + `BuildSentExchangeText` per row into a `TLogQsoAppends`, `AppendBatch` with the hook calling `externalLogger.CaptureSavedQso`, `GLastAppendedMyFacts` from the last row, `LogStoreStartExternalDelivery` once after the commit; the busy retry re-runs the WHOLE batch; a failure goes to `Disable` with the live semantics (disk full -> read-only, busy -> refused, store open). Not `LogStoreAppendQSOs`, which keeps import semantics (stays enabled, logs only). |
| `uLogStore` | `LogStoreAppendQSO` becomes the one-leg call of the above, so there is one live append path. The contest matrix (which calls it directly) is the byte oracle that it did not move. |
| `logsubs2` | `LogContact` is split into Prepare / Score / Release around `LogStoreAppendLiveQSOs`; `PostLoggedQso` into build and post. `LogContact(var rec, MyComputer): boolean` keeps its signature for WSJT-X and the peer path. `tAddQSOToLog` keeps its signature for notes and QTCs. |
| `MainUnit` | `TryLogContact` + `DrainPendingMultiQSORefs` drive one submission: prepare leg 0, then each park, county and rover leg (score the previous one first), one store call, release all or rebuild. |

The sequencing (prepare, score-lazily, write, release-or-rebuild) goes in a **leaf
with method-pointer seams**, so it is unit-tested with recording stubs even though
`LogContact` is not (see section 5).

### 2d. Network identity on retry: a fresh sequence, NOT reused

A refused entry publishes nothing, so its `(ceQSOID1, ceQSOID2)` was seen by no
one and a fresh pair on retry cannot duplicate anything on the server. A retry is
a new parse anyway: new exchange id (MainUnit.pas:7896) and new time. A gap in
`NextQsoSequence` is harmless (uniqueness is what matters, uNetResend.pas:206).
Reuse would only matter if True could be returned for an uncommitted row or False
for a committed one. The pins above forbid the first. The second - a COMMIT that
reports failure after its frames reached disk (an fsync or IOERR at commit) - is
**NOT verified either way**; if it happens, the row reappears on reopen with
`sent_to_server = 0` and is resent on the next link, and the operator's retype
adds a second row under a new key, locally and on the server. Reusing the
sequence would not prevent that, because the sequence does not survive a restart
(it is in memory). So the recommendation stands; the residual case is a visible
duplicate the operator can X-QSO, never a lost QSO.

### 2e. The multi-op "sent" flag: unchanged

`sent_to_server` still means "the writer thread handed the bytes to the socket"
(`SettleServerProgress`, uNet.pas:3211). The packet is posted after the commit, so
the row exists before any settle can mark it. **A crash after the commit and before
the post leaves `sent_to_server = 0`, and `ResendOfflineWork` sends it on the next
link** - no new code. What such a crash CAN lose: the UDP datagrams, the HamScore
upload (HamScore has a full resync) and a non-durable logger command. Durable
loggers lose nothing.

### 2f. NOT changed

Wire format and protocol (2/4), the 376-byte `ContestExchange`, the schema and
`user_version`, both servers, the meaning of the sent flag, resend, catch-up, the
restock, the durable outbox, the dispatcher's sink order, any payload's bytes.
**No server acknowledgement is added**; a durable server copy is still reconciled
by catch-up and Synchronize.

---

## 3. Risks and invariants

| area | risk | how the plan holds it |
|---|---|---|
| wire | none: same packets, later | packets built from the same record at the same point |
| record layout | none | no field added |
| pre-commit TRDOS state | step 3 (auto time increment, ten-minute date) and the beeps run before the write and are not undone | unchanged by this plan; the increment changes the QSO's own time, so moving it is a scoring decision (question 6) |
| sheet state on a multi-leg refusal | legs 0..n-2 are scored before the commit | `LoadinLog` rebuild; only `LoadinLog`-rebuilt state may be scored early. The initial-exchange history and rate counters are NOT rebuilt, so they move to Release |
| re-entrancy | `Disable` shows a MODAL (disk full) inside the store call; the modal pumps messages, so a queued peer QSO, `SettleServerProgress` or WSJT-X job can run while legs 0..n-2 are scored and not yet rebuilt | the store returns its notice to the caller, which shows it after the rebuild; until then no modal inside a multi-leg submission (lcl-ui reviews). The transaction itself is already over when the modal shows |
| dispatcher thread | messages are built on the main thread and posted later | ownership: the holder frees an unposted message in a `finally`; FIFO order across legs is kept because legs are posted in order |
| grouping | all legs share the exchange id, so `SaveQSOGroupingByExchangeId` files them in one `qso_set_id`; inside one transaction the lookup sees the earlier legs (same connection) | pinned by an extended `TestCountyLineQSOsShareAnExchangeId` |
| HamScore id | legs share `RXData.id`, sent as `msg.HamQSOID` | CHECK in the release test; if two legs collide upstream it is a separate issue |
| "sent before saved" relied on? | none found: the server never echoes to the sender (tr4wserverUnit.pas:548), the receiver skips its own computer id (uNet.pas:1030) and a held pair (`ReceivedQsoIsKnown`) | - |
| receive path | ignores the Boolean today | section 4, commit 6 |
| dead code | `OperateContest` (logsubs2.pas:2575) has no caller; its four `LogContact` calls are unreachable | not planned around; lcl-ui may delete it separately |
| backup in the window | `BackupLogNow` snapshots committed rows only | it runs in Release, after the commit |

---

## 4. Work breakdown (small commits, each buildable and testable)

| # | commit | area | tests |
|---|---|---|---|
| 1 | `AppendBatch`: row ids out and the per-row hook (optional; import and catch-up unchanged) | log-database | repository: ids in order, hook inside the transaction, a hook that raises rolls back the batch |
| 2 | `LogStoreAppendLiveQSOs`; `LogStoreAppendQSO` becomes its one-leg call | log-database | store: section 5a; contest matrix byte-identical; `TestEveryWriteWaitsForItsCommit` unchanged (no new write path) |
| 3 | the sequencing leaf (prepare / score-lazily / write / release-or-rebuild) with stubs | log-database + contest-scoring | leaf tests, section 5b |
| 4 | `LogContact` split; `PostLoggedQso` split into build and post; single row through the leaf | contest-scoring + integrations | source-read pin in the style of `Test_ARefusedSaveKeepsTheEntryAndItsReason`; corpus; matrix |
| 5 | `TryLogContact` + `DrainPendingMultiQSORefs` as one submission; `LoadinLog` on refusal (verify it writes nothing; measure it); `Disable`'s modal deferred until after the rebuild | contest-scoring + log-database (the modal is `uLogStore`'s) + lcl-ui | leaf tests; `TestAFullDiskLeavesTheLogReadable` and `TestAFreedDiskRecoversWithoutARestart` kept green; release check |
| 6 | peer receive: honour the Boolean, report (question 3) | multi-op-network | `uTestNetResend` over the stub writer where reachable; release check |
| 7 | `AddRecordToLogAndSendToNetwork` reordered (question 4) | multi-op-network | release check with QTCs and a note |
| 8 | docs: `LOG_SCHEMA`/§9c row "county line commits per QSO" (SQLITE_LOG_SCHEMA_PLAN.md:1447, labelled "a decision", NOT one of NY4I's rulings) reversed; `log-database` and `multi-op-network` agent files; BENCH_QUEUE entries | log-database | - |

Commits 1-3 change no behaviour. Commit 4 fixes the operator's own single-row
path, 5 fixes #348, 6 and 7 the rest of #347. **Commit wording closes issues
here**: commits 1-6 say "Part of issue 347" / "Part of issue 348"; only the last
commit for each issue may close it.

---

## 5. Test plan

### 5a. Repository and store (unit suite)

Seams that exist: a `RAISE(ROLLBACK)` / `RAISE(FAIL)` trigger on a chosen call,
created BEFORE a new repository (statements prepared earlier fail with "schema has
changed"); the deferred-foreign-key commit trap of
`Test_R2_ACommitThatFailsIsNotReportedSaved` (fails the COMMIT itself);
`LogStoreFillTheDiskForTests` / `LogStoreFreeTheDiskForTests`;
`LogStoreForgetFailureForTests` in every `finally`; the
`uTestWRLDelivery` scratch-log pattern for `external_delivery` rows.

- Three legs, the trigger refuses leg 2: False; zero `qso` rows; zero
  `external_delivery` rows; `LogStoreLastAppendedMyFacts` unchanged; store enabled
  and writable.
- Three legs, the commit fails (deferred key): the same, and True never returned.
- Full disk: False, read-only, zero rows; free the disk; retry: exactly three rows,
  ONE `qso_set_id`, each row's `exchange_sent` and `my_*` as a live append writes
  them (compare with `TestAnAppendBatchWritesRowsAsTheLiveAppendDoes`).
- Busy (the existing locking seam): the whole batch retried, never half.
- Crash shape: free repository and database without a commit, reopen, compare
  with the seed (CLAUDE "how to test a one-transaction claim", steps 1-6),
  mutation-tested by removing the batch's begin.
- One leg: `LogStoreAppendQSO` results unchanged (`uTestLogStore`,
  `TestAnAppendStoresTheContestsRule`, the existing append tests).

### 5b. The sequencing leaf (unit suite)

Recording stubs for prepare, score, write, release, rebuild:
write False -> no release call for any leg, rebuild called iff some leg was scored
(never for one leg), messages freed; write True -> release per leg in order, the
last leg scored after the write; leg i prepared after leg i-1 scored.

### 5c. What the unit suite CANNOT cover

`LogContact`, `TryLogContact`, the network and the dispatcher wiring are not unit
callable (CLAUDE.md). The corpus and the matrix prove the success path did not
move; only a run proves the order. **Release check (bench), on an isolated
contest, with a UDP listener, a DXKeeper-style logger, HamScore and a two-station
network:**

- [ ] **Kill before commit.** Break the process at the append (debugger, or a test
  build that halts there). Reopen with the WAL: the QSO is absent; the server, the
  peer, the UDP listener and the logger never saw it; retype it once: one row
  everywhere.
- [ ] **Kill after commit, before release.** Reopen: the QSO is present,
  `sent_to_server = 0`; on link-up it is resent once; the peer holds it once.
- [ ] **Forced write failure** (full disk, as in BENCH_QUEUE "A FULL DISK"): no UDP,
  no logger command, no HamScore, no packet for the refused Enter; the entry
  stays typed; after freeing space one Enter logs it once with a new network key.
- [ ] **Held lock** (another process holding the write lock past the busy wait):
  refused as a whole, nothing published, then logs once.
- [ ] **Later leg fails** (county line PIN/HIL, a two-park POTA entry, a rover at a
  boundary): with the trigger or the disk filled between legs, zero rows, zero
  events, totals and mult windows as before the Enter; retry gives exactly one
  linked set; ADIF export links the legs; Cabrillo shows each leg.
- [ ] **Compare** for every case: row identities (`guid`, `exchange_id`,
  `qso_set_id`, session ids), exchange fields, sent serials (legs share one),
  linked sets, the retained input, and every outbound event (packet keys, UDP
  text, logger command, HamScore id per leg).
- [ ] **Peer refused**: fill the receiving station's disk; the refusal is in
  tr4w.log at Error and shown; after space is freed, Synchronize (or the next
  link's catch-up) adds it once.
- [ ] **QTC and note** (after commit 7): a refused QTC record is not sent.

---

## 6. Decisions needed from NY4I

1. **Reverse "a county line commits per QSO".** One Enter = one transaction, all
   legs or none. *Recommend: yes* (the bench item already expects it).
2. **Retry identity.** *Recommend: a fresh network sequence on retry, no reuse*
   (section 2d).
3. **A peer QSO this station cannot store.** Refuse, log at Error, show it once,
   rely on catch-up/Synchronize - or add a retry queue. *Recommend: refuse and
   report; no new queue.*
4. **Notes and QTC records** (`AddRecordToLogAndSendToNetwork`): commit first and
   send only a committed record, keeping the Boolean as the network's answer for
   the QTC pacing. *Recommend: yes, in this change.*
5. **Partial legs as an alternative to all-or-none** (keep committed legs and
   report the rest). *Recommend: no* - it is today's defect, and a retry cannot
   tell which legs exist.
6. **The auto time increment and ten-minute date** run before the write and are not
   undone on refusal. *Recommend: leave them* (they set this QSO's time); revisit
   only if a refused Enter visibly shifts hand-log time.
7. **`LoadinLog` on a multi-leg refusal** costs a full reload on the main thread
   (rare: disk full or a held lock). *Recommend: accept; measure on the largest
   corpus log in commit 5.*

### Review discrepancies

- Finding 1 says "applicable external-logger event": only command-queue loggers
  (`TExternalLogger`) are posted early. WRL, Club Log, QRZ, Cloudlog and ACLog
  capture inside the transaction and are already commit-gated.
- Finding 1 omits `AddRecordToLogAndSendToNetwork` (notes, QTCs), which has the
  same order (section 1e).
- Finding 2: a retry after a partial save re-appends leg 1 under a NEW exchange id,
  so the duplicate is in a different `qso_set_id` - worse than the review states.
- The review's bench link (`BENCH_QUEUE.md#L333`) now lands on other text; the item
  is at line 348.
- The receive path's early UDP and HamScore post is inside `LogContact`
  (logsubs2.pas:1914-1917); `uNet` (1032) only calls it and drops the result.
- The "county line commits per QSO" row (SQLITE_LOG_SCHEMA_PLAN.md:1447) was an
  agent decision, not one of NY4I's rulings; decision 1 reverses it.
- Line numbers in the review and the lead's description were otherwise confirmed.

---

## 7. Decisions (NY4I, 2026-11-21)

All seven taken as recommended in section 6.

1. **One Enter is one transaction** (county line, multi-park, rover boundary): all legs or none. The row going into the `qsos` table is the primary act; the multi-op packet, UDP, HamScore and external loggers are secondary and follow the commit. NOT a two-phase commit: nothing waits on a sink, and a sink that was down is reconciled later by the resend flags and catch-up/Synchronize.
2. **A retry gets a fresh network sequence**, no reuse.
3. **A peer QSO this station cannot store** is refused, reported (Error log, shown once) and left to catch-up/Synchronize. No retry queue.
4. **Notes and QTC records** commit first, then send (same change).
5. **No partial legs.** Requirement added by NY4I: the operator's entry (call and exchange) must stay in the window and must not be cleared until the QSO record is committed, so a failure can be reported and acted on (even written on paper). This is today's refused-save behaviour for the single row (step 9 of section 1a) and must hold for the multi-leg entry too; the windows are cleared only after the one commit succeeds (step 13).
6. **The auto time increment and ten-minute rule are not undone on refusal.**
7. **A reload (`LoadinLog`) after a refused multi-leg entry is accepted**; its cost is measured in commit 5.
