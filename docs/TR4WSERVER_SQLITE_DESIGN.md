# tr4wserver: should the centralised log move to SQLite? (issue 341)

> **SUPERSEDED IN PART, 2026-11-22: read section 13 first.** NY4I's rulings of
> that day (issue 300) overturn this note's BLOB-per-record store, its
> byte-exact `SERVERLOG.TRW` stream and its D1/D2/D3/D5 recommendations. Sections
> 1-12 are kept as the record of what was read and why; where they disagree with
> section 13, section 13 governs.

Design note, 2026-11-19. **Nothing here is built.** It answers the open questions
in issue TR4W/TR4W-D12 #341 from what was read, says what was only inferred, and
recommends a phased plan. NY4I's rulings are listed at the end; none is assumed.

**Read 2026-11-19 against TR4QT's peer-to-peer document -- see
[`SQLITE_LOG_SCHEMA_PLAN.md`](SQLITE_LOG_SCHEMA_PLAN.md), "The network, deltas
and the peer-to-peer question".** Phases are in section 9. Short form: a separate server database is
moot under pure P2P and should reuse the station schema under an elected
master, and this note's BLOB-per-record store is the form least likely to
survive either. Phases P0 (byte oracle) and P1 (store seam) and the flat-file
integrity fixes of section 6 pay off in every case; **P2 and P3 should wait
for a ruling on the topology and on the wire operation** (a stable id, an
edit version, a tombstone). Not a ruling; NY4I decides.

Evidence tags used below:

- **[read]** a file or a GitHub clone was opened and the line was read.
- **[inferred]** concluded from what was read, not seen to happen.
- **[not checked]** nobody looked.

---

## 1. Summary and recommendation

1. **Yes, move the in-tree server's log to SQLite, but not as a new schema.**
   Store each 376-byte `ContestExchange` as a BLOB with two or three index
   columns beside it. The server stays contest-agnostic: it stores and relays
   records and never interprets them (`multi-op-network` agent file).
2. **The sync port must keep sending a valid `SERVERLOG.TRW`**: a 4-byte size,
   then the 376-byte header record, then the records in arrival order. A BLOB per
   record can reproduce those bytes exactly. Station schema 10 columns cannot (the
   station's reader folds, clears and re-stamps fields), so the server must not
   reuse the station schema or `uLogRepository`.
3. **The wire is less constrained than the issue says.** Every station the HELLO
   gate admits speaks protocol 4, and every protocol-4 build contains the C6
   catch-up (2026-10-27), which reads only the size from the log-compare packet.
   Nothing in the client reads the CRC32 or the contest field. What must stay
   byte-exact is the sync-port stream and the size. NY4I wrote on 2026-11-13
   *"Server wire formats can be done at will. Just update the Python tr4wserver and
   FPC/Laz version."* The issue says the wire must not change for deployed
   stations. **NY4I must reconcile the two** (decision D1); this note keeps the
   stream byte-exact either way, because that costs almost nothing and gives a
   free rollback.
4. **The smallest safe first step is not SQLite.** It is a byte oracle on today's
   server plus a store seam (phases P0 and P1), so the SQLite store can be proven
   byte-identical before it carries a QSO.
5. **TR4WServerPy is a separate implementation of the same flat file**, with no
   shared code. It is not stranded by an in-tree change, but it also does not
   benefit. Per the bench-rig memory note (dated 2026-10-29, so it may be stale) the Pi
   runs TR4WServerPy, started by hand, so **an in-tree-only change protects nothing on NY4I's rig** until the
   Python server follows (decision D2).
6. **Integrity gains, in order of value:** one transaction per store; a read
   snapshot for the sync port (today it can stream a mixed image, section 6);
   read-only-and-keep-serving on a full disk, with the existing intercom notice;
   a verified backup before Clear-all-logs (today it truncates with no backup);
   an integrity check at start.
7. **Cost:** the Server search path currently withholds sqlite/fcl-db on purpose.
   A SQLite server removes that guard deliberately, the DLL has to ship in the
   `server\` folder, and the connection layer in `uLogDatabase` has to be lifted
   into a lower shared unit rather than copied (section 5).

---

## 2. What was read

| area | files [read] |
| --- | --- |
| issue | `gh issue view 341` and `340` on TR4W/TR4W-D12 |
| in-tree server | `tr4w/tr4wserver/tr4wserver.lpr`, `src/tr4wserverUnit.pas` (open/append/edit/clear/CRC/serial scan, `ProcessClientBuffer`), `src/uServerNet.pas` (sync port), `src/uServerLogHealth.pas`, `src/uServerQsoIndex.pas` (header only) |
| client | `src/uGetServerLog.pas` (`FetchServerLog`), `src/uNetCatchUp.pas` (`TServerLogImage.Accept`), `src/uNet.pas` (`ProcessServerLogInfo`, resend loop), `src/VC.pas` (`TLogFileInformation`, `TLogHeader`) |
| station store | `.claude/agents/log-database.md` (pages 1-2 and the full-disk section), `docs/LOG_SCHEMA.md` (sections 1-4), `src/domain/uLogDatabase.pas` (interface, backup, integrity) |
| build/packaging | `build/Get-SearchPaths.ps1`, `build/Build-Server.ps1`, `build/full.nsi` |
| Python server | `gh repo clone TR4W/TR4WServerPy` into a scratch directory outside the repo: `tr4wserver.py` (the log, sync, edit and clear paths), `CLAUDE.md`, `README.md`, `CHANGES.md` |
| probe | `tools/netprobe/netprobe.py` (constants, `parse_log_compare`, case list) |
| bench notes | memory note `bench-rig-mint-and-pi400` only. No ssh was used. |

Not read, or only skimmed: `uServerForm`, the Python `tailcat_transport.py`, the
test units, `docs/SQLITE_LOG_SCHEMA_PLAN.md`, the second half of the log-database
agent file.

---

## 3. Question 1: TR4WServerPy

**Read.** `tr4wserver.py` is one class, `TR4WServer`, standard library only. It
reads and writes the same flat file as the in-tree server, by its own code:

- `DEFAULT_LOG_RECORD_SIZE = 376`, configurable through `LOG RECORD SIZE` in its
  ini (`tr4wserver.py:174, 716`). It refuses to start when the file size is not a
  multiple of that (`init_log_file`, line 761).
- It writes its own 376-byte header (`create_log_header`, line 792): the version
  string `v1.7\0 \r\n`, the file description, the warning text, zero padding. It
  states the layout was copied from `VC.pas`.
- Append is `open(..., 'ab')`, write, flush, `fsync` (`add_qso_to_log`, line 1598).
  An edit rewrites the matching record in place, scanning from the end
  (`update_qso_in_log`, line 1630). The key is bytes 8..15 of the record,
  hard-coded.
- The sync port sends `struct.pack('<I', size)` and then the raw file in 4096-byte
  chunks, **holding `log_lock` for the whole transfer** (`handle_sync_client`,
  line 1142).
- The log-compare packet is 19 bytes with a streaming CRC32 of the whole file,
  cached by a `server_crc32_changed` flag; the contest byte comes from record 1 at
  `CE_CONTEST_OFFSET` (`send_log_file_info`, line 1520).
- Serial lockout scans `NumberSent` at offset 204 of every record at start and on
  clear.
- Threading is thread-per-connection with `log_lock` around all file I/O.

**Findings that matter for a design.**

- It does **not** share the in-tree server's code, so a SQLite in-tree server
  does not touch it. The two agree only through the file format and the protocol.
- **Parity gaps already exist** between the two servers. The in-tree server
  rewrites every record on `SM_CLEAR_DUPESHEET_MESSAGE` and
  `SM_CLEAR_MULTSHEET_MESSAGE` (`tUpdateServerLog`). The Python server only
  broadcasts them (`tr4wserver.py` around line 1960, **[read]**). It also has no
  torn-tail repair, no failure notice to stations, and no trim-back after a failed
  append. Both edit walks go back from the end and stop at the first record whose pair
  matches. Python's `update_qso_in_log` stops at the header slot
  (`while pos >= self.log_record_size`); the in-tree loop's bound is
  `-FilePointer * 376 <= Size`, so it also reads the header slot. Header bytes 8..15
  are text and will not match a real pair, so nothing is lost today, but the two
  do not match each other. The SQLite design excludes the header from `qso`
  altogether.
- A flat file is the **interchange** format today: moving a log between the two
  servers, or restoring one, is a file copy. **This is a real property to keep**
  (decision D3, and the exporter in section 8).

**What a SQLite tr4wserver would mean for it.**

- Nothing breaks on the wire. Stations cannot tell the servers apart.
- **If the in-tree server alone moves**, the two servers stop sharing a log file.
  Moving the log between them needs the exporter. [inferred] That is acceptable
  if the exporter is a supported command.
- **If both move**, Python's standard `sqlite3` module needs no new dependency, so
  parity is cheap. It is a second implementation to keep byte-identical, so the
  shared byte oracle (P0) must run against both.

---

## 4. Question 2: what the client fetches, and what must stay byte-exact

### 4.1 What the server sends

1. **On admit**: the 19-byte `TLogFileInformation` (`NET_LOGCOMPARE_ID` 1010):
   `liID`, `liSeverCRC32`, `liLocalCRC32` (0), `liServerLogSize`, `liLocalLogSize`
   (0), `liContest` (a byte). Also in answer to the 4-byte `NET_LOGINFO_MESSAGE`
   sentinel (`SendLogFileInformation`, `tr4wserverUnit.pas:1482`). [read]
2. **On the sync port** (port + 1): the client writes 10 password bytes; the server
   writes a 4-byte native-order size, then the file (`TServerEvents.SyncExecute`,
   `uServerNet.pas:582`). [read]
3. **`NET_TAKESERVERQSO_ID` (1060)** exists in the id table and is skipped by the
   server's `else` arm; nothing sends it. [read]

### 4.2 What the client does with it

- `uNet.ProcessServerLogInfo` **reads only `liServerLogSize`**, to log "the server
  says its log holds N record(s)". It does not read the CRC or the contest.
  [read, `uNet.pas:2290`]
- Grep over `src/` finds `liSeverCRC32` and `liContest` only in `VC.pas` and the
  server writer. No client unit reads them. [read]
- `netprobe` parses the packet in `parse_log_compare` (comment: *"Only the server
  log size is still meaningful"*) and asserts only that the packet arrives on
  admit. [read]
- `FetchServerLog` writes the password, reads a 4-byte size (rejecting negative or
  over 256 MB), then reads exactly that many bytes. `TServerLogImage.Accept` then
  requires: received == declared; either empty, or at least one header record; and
  `(size - 376) mod 376 = 0`. The header's **contents are not checked**; the first
  376 bytes are skipped. Records are read by position. [read, `uNetCatchUp.pas:335-372`]

### 4.3 Which stations are "deployed"

- The HELLO gate refuses any protocol other than the server's own, so an admitted
  station speaks protocol 4. Protocol 4 arrived in commit `088f7e7d` (2026-11-13).
  The C6 catch-up that dropped the CRC comparison is `02fa68d9` (2026-10-27),
  earlier. [read from git log; `git merge-base --is-ancestor 02fa68d9 088f7e7d` answers yes,
  so every build that has protocol 4 contains the C6 catch-up]
- Therefore **no admitted station compares CRCs.** D7 (4.x) stations never join a
  5.x network (NY4I: *"D7 (4.x) NEVER joins a 5.x network"*).

### 4.4 What a SQLite server must still produce

| output | must it be byte-exact? | why |
| --- | --- | --- |
| the sync-port stream: size, header record, N x 376-byte records in arrival order | **Yes** | `Accept` checks size and stride; the catch-up reads records by position |
| the declared size equals the streamed length | **Yes** | `Accept` rejects a mismatch |
| `liServerLogSize` | **Yes** (it is the file's size) | read, and logged, by the client |
| `liSeverCRC32` | **No station reads it** [read] | keep computing it unless D1 rules otherwise (below) |
| `liContest` | **No station reads it** [read] | keep it: the first record's `ceContest` byte |
| the 384-byte QSO packet and the 376-byte record layout | **Yes** | relayed whole; the server reads only the pair, `NumberSent` and one contest byte |

**Can it do that from rows?** Yes, if each record is stored as the BLOB it
arrived as. The stream is then the header blob followed by the BLOBs `ORDER BY seq`.
**No, if it is rebuilt from station-schema columns:** [read] the station reader
(`uLogRepository.ReadRecord`) folds `ceQSO_Skiped` into `ceQSO_Deleted`, the `.TRW`
reader clears the year bytes, receive paths restamp `ceContest` and
`ceOffContest` (schema 10: the station's own byte is not trusted on receipt), and
padding bytes in packed strings are not preserved. A round trip through columns
is not byte-identical, and the server would also have to judge contests it must
not judge.

### 4.5 Reconciling the issue with NY4I's 2026-11-13 ruling

The issue says the wire format must not change for deployed stations. The agent
file records NY4I on 2026-11-13: *"Server wire formats can be done at will. Just
update the Python tr4wserver and FPC/Laz version."* These can both be true: the
second is about a protocol bump (a new `NET_PROTOCOL_VERSION`) and the first about
not changing bytes **without** one. **Decision D1.** Recommendation: change no
bytes in phases P0 to P3. If a later phase wants to drop the CRC, send it as 0 only
under a protocol bump.

---

## 5. Question 4: the schema

### 5.1 Reuse the station schema 10, or a slimmer one?

**A slimmer one, and not an extension of the station's.**

- The server is contest-agnostic and cannot judge a record's contest; the station's
  `ceContest` byte means different things on different builds for by-id contests.
- `ceOffContest` (offset 330, schema 10) is the logging station's own judgement and
  "NO receiver trusts it" (agent file). A server that columned it would present a
  value no one may rely on.
- The station schema carries 68 columns of derived and captured facts (`my_*`,
  `rcvd_year`, `year_sent`, `exchange_sent`) that the V1 record either does not
  carry or carries in `sReserved` bytes the server has no business reading.
- Reusing `uLogRepository` would pull the contest registry, settings and
  `MainUnit` into the server. That breaks the boundary the Server build target
  exists to hold.

### 5.2 Proposed shape (a sketch for discussion, not final DDL)

| table | columns | notes |
| --- | --- | --- |
| `meta` | `key TEXT PRIMARY KEY, value` | the 376-byte header record stored **verbatim**; the import's source size and CRC32; the server-log schema version |
| `qso` | `seq INTEGER PRIMARY KEY AUTOINCREMENT`, `id1 INTEGER NOT NULL`, `id2 INTEGER NOT NULL`, `record BLOB NOT NULL CHECK(length(record) = 376)`, `stored_at INTEGER` | `seq` is arrival order, the order the stream must reproduce |
| index | `qso(id1, id2)` **non-unique** | see below |

- **File identity.** A distinct extension (not `.db`, which the station's Open
  dialog scans for contests) and a distinct `PRAGMA application_id`, so the station's
  `VerifyIdentity` (accepts 0 or `'TR4W'`) can never treat it as a contest log.
  Decision D5 names them.
- **Why the pair index is NOT unique.** The pair `(ceQSOID1, ceQSOID2)` is "not
  unique in old logs" (log-database agent file), because `ceQSOID2` was a 10-16 ms
  tick before 2026-10-27, and the file may hold repeats the server has stored
  since. A UNIQUE index would refuse the import. `(0, 0)` names nothing and is
  stored every time. Uniqueness is enforced in the insert (`... WHERE NOT EXISTS`)
  inside the same transaction, as the in-memory set does today.
- **Edits match today's semantics, not a naive UPDATE.** Today
  `UpdateQSOInServerlog` rewrites only the **newest** record with the pair
  (it walks back from the end and stops). SQL must say
  `WHERE seq = (SELECT MAX(seq) FROM qso WHERE id1=? AND id2=?)`. A plain
  `WHERE id1=? AND id2=?` would rewrite every copy.
- **The edit is the whole record, last writer wins, no edit counter.** That is
  today's behaviour and stays; ordering/conflict rules belong to the row-level
  protocol.
- **An edit for a pair the server does not hold** is, today, relayed and **ACKed
  but not stored** (`Result := True` before the search; the in-tree walk simply
  finds nothing). [read] Phase 1 preserves it. Whether to **upsert** instead is
  decision D7; the arguments are in section 6.4.
- **Mutating a record** (clear-dupesheet, clear-mults): cast the BLOB to
  `ContestExchange`, change the fields, write the BLOB back, as `tUpdateServerLog`
  does now. Untouched bytes stay identical.
- **Derived columns.** Only `id1` and `id2` are extracted (they are bytes 8..15 of
  the record, [read] `netprobe` constants and the Python server both hard-code
  them). `NumberSent` (offset 204 per `CHANGES.md`, [read]) is **not** extracted:
  the serial scan is a one-pass read at start and on clear today, and a second copy
  of a value in the BLOB is a second source of truth. A start-time check that every
  `id1`/`id2` column equals its BLOB bytes is an integrity check (P3).

### 5.3 What the server keeps besides QSOs

[read] Nothing else on disk: the settings are in `tr4wserver.ini`; each slot's
HELLO, status and serial-lockout state (`clSerialNumber`, `clSerialNumberStatus`)
are in memory. After a restart the serial counter is re-derived from the
maximum `NumberSent` in the log (`ScanLogForSerialsNumbers`). **Persisting the
serial state is not needed**; the scan reproduces it.

---

## 6. Question 5 and 6: integrity, failure, concurrency

### 6.1 Today's write path [read]

- Every write runs on the **main thread**: the Indy connection threads only move
  bytes and call `TThread.Synchronize` for each parse (`uServerNet.pas`, header
  comment). OFFLINEQSO runs share one held open file (`HoldServerLog` /
  `ReleaseServerLog`) flushed once at the end of the run; a QSOINFO is flushed per
  record.
- A failed append trims the file back to its size before the write; a failed
  rewrite writes the old record back (`AppendRecordToOpenServerLog`,
  `UpdateQSOInServerlog`). `NoteServerLogFailure` counts, shows `LOG NOT SAVING`,
  and sends one intercom notice on the first failure and one on recovery
  (`uServerLogHealth`, 79-character limit). **The QSO is still relayed** when the
  store fails, deliberately: no packet acknowledges a QSO, so the sender will never
  offer it again, and withholding it would take it from the other stations' dupe
  and mult checks. The next station to link restocks it.
- A torn tail at start is offered a backup-then-trim, only when the first record
  is the current header (`OfferTornLogRepair`, `PlanServerLogRepair`). Any other
  wrong-size file is refused untouched.

### 6.2 A hazard found while reading: the sync port is not a snapshot

[read] `SyncExecute` opens the file itself with `fmShareDenyNone`, takes
`size := fs.Size`, writes that as the 4-byte head, then calls
`IOHandler.Write(fs, 0, False)`. In the vendored Indy, `Write(AStream, 0, ...)`
sets `ASize := AStream.Size` **at that call** and rewinds
(`IdIOHandler.pas:1787-1790`). So the declared size and the streamed length are two
separate reads of the file, with no lock, while the main thread may append, rewrite
in place (`tUpdateServerLog` writes the whole buffer back), or truncate (Clear).
A station could get a declared size that disagrees with the bytes, or a record
caught mid-rewrite.

- **Confirmed from source; not reproduced.** The window is small (a download
  racing a write) and the client protects itself: `Accept` rejects a size mismatch,
  and a mid-rewrite record is only wrong in bytes the catch-up then stamps. It
  should still be fixed, and a SQLite store fixes it by construction: one read
  transaction yields the count and the rows.
- The Python server avoids it differently: it holds `log_lock` for the entire
  transfer, so a slow station blocks every write for up to the send timeout.

### 6.3 Proposed behaviour on a SQLite store

**Connection model.**

- **One write connection**, owned by the main thread, as today's single-writer
  reality. Every QSO store is one transaction; a run of consecutive OFFLINEQSO
  packets (the existing hold) is **one** transaction committed at release. This
  keeps ordering: the commit precedes the relay for QSOINFO.
- **A short-lived read-only connection per sync transfer** (on the connection
  thread), giving a consistent snapshot: size and rows from one read transaction.
  Mind the two traps from the log-database agent file: a long read transaction holds
  back WAL checkpoints, and a read-only connection to a WAL file can leave `-wal`
  and `-shm` behind. The transfer must not be able to stall the writer.
- WAL with `synchronous = FULL`, as the station. If the directory is not writable
  (for SQLite WAL the **directory** must be writable, not only the file), refuse at
  start with a message. Where an installed server's `AppDir` resolves
  (`LogFilePath` = `AppDir + name`) is **[not checked]** on an installed Windows
  setup (`$INSTDIR\server`, Program Files by default).

**Full disk or write error.** Reuse the station's classification
(`uLogDatabase.SQLiteWriteFailure`: `lwfDiskFull`, `lwfWriteError`). On either:

1. Roll back, and make the store **read-only** (no QSO is half-stored).
2. **Keep serving**: reads and the sync port still work, relays continue, exactly
   the current rule "QSO relayed, not stored".
3. Tell stations once on the transition, over the existing intercom channel
   (`SendNoticeToStations`, sender `#`, at most 79 characters): the text already
   exists in `uServerLogHealth`. No new wire field. **This is also the server half
   of issue 340** ("tell other stations when one station's log goes read-only"):
   the server cannot, as far as was read, know a **station's** log went read-only
   (`TClientStatus` holds only `csID` and `csTelnet` [read]; the larger station-status
   record was not read, so [inferred]); issue 340 needs either a client message or the station's own
   notice. The server's own read-only state is covered here.
4. **Recover without a restart**: probe a write on the next QSO (the station's
   `ProbeAWriteCommits` pattern), clear read-only on success and send the recovery
   notice.

**Observation worth keeping (from issue 340's comment).** A station whose local
commit was refused had already sent the QSO; it is in the other station's grid (issue 340's
comment shows the Mac grid) and, [inferred, not shown in the issue] in the server. The network is a failsafe: stations are replicas, so a lost server
log is recoverable from any station through the restock (2026-10-28). That recovers
**QSOs**, not edits, and only those some station still holds.

**Backups and integrity.**

- The station snapshots with **`VACUUM INTO` on its own short-lived read-only
  connection**, then verifies the copy (`TLogDatabase.SnapshotTo`,
  `uLogBackup`; `uLogDatabase.pas:537` says explicitly *"VACUUM INTO, not the C
  backup API"*). The issue text and the task brief say "Online Backup API"; the
  code does not use it. The server should do the same, for the same reasons.
- **Never `VACUUM` on the live connection** (agent file: it breaks every kept
  statement on that connection).
- **Clear-all-logs today truncates with no backup**, on a message
  (`SM_CLEARALLLOGS_MESSAGE`, 8230) any station can send. [read] The in-tree
  `SM_CLEARSERVERLOG_MESSAGE` arm sits inside a `{ }` block and is not live, so
  8230 is the only truncating message there; TR4WServerPy handles 8230 only
  (`clear_server_log`). The SQLite version should take a verified, dated snapshot
  first and refuse to clear without one, as the station's Clear Log does.
- `PRAGMA integrity_check` and `foreign_key_check` at start (the station's
  `CheckIntegrity`), plus the id-column-equals-blob check from section 5.2. A
  failed check starts the server **read-only on the file** and says so rather than
  serving a damaged log silently.

### 6.4 Edits and deletes

- **A delete is not a message of its own.** [read] There is no contactdelete
  message in the id table. A delete is a `NET_EDITEDQSO_ID` carrying the record with
  `ceQSO_Deleted` set; `DeleteLastContact` sets `ceNeedSendToServerAE := True`
  before storing (agent file), and the resend sends `NET_EDITEDQSO_ID` for such a
  row. The server rewrites the record in place like any edit. [inferred from those
  two reads; the live send of a delete was not traced end to end]
- **The unheld-edit ACK.** Today an edit for a pair the server does not hold is
  relayed and ACKed (`SM_RECEIVED_UPDATED_QSO_MESSAGE`) but changes nothing. After
  a server that lost its log is restocked, an old edit could arrive first and be
  dropped. An upsert would store it, but an edit carries the **whole** record, so an
  upsert is also a way to store a QSO the server never received. It is correct
  data, but it is a behaviour change, so it is a decision (D7), not a phase-2 side
  effect.

### 6.5 Throughput

A commit per QSOINFO costs one fsync under `synchronous = FULL`. The in-tree server
today acknowledged an OFFLINEQSO restock at 42.6 ms a record (85 ms for the first
200 in one run, 213 s for 5,000, measured 2026-10-28, agent file) because it
opens the log twice and flushes per record and logs at trace level. A transaction
per held run should be no slower and probably faster. **No number is promised;**
measure it with `netprobe --case restock --restock-big 5000` before and after.

---

## 7. Platform and packaging

- **The Server search path withholds sqlite and fcl-db on purpose**
  (`build/Get-SearchPaths.ps1`, the block `if ($For -ne 'Server')`). Its stated
  premise, *"tr4wserver has no log of its own -- it relays QSOs between clients"*,
  is **false** (the server keeps `SERVERLOG.TRW`). The note beside it also treats
  that path as the **only** guard against the server growing a sqldb dependency.
  A SQLite server removes the guard deliberately. **Decision D6:** replace it with
  a narrower rule (only the server-log unit may use sqldb, enforced by a lint), so
  the boundary is held again and not simply deleted.
- **`sqlite3.dll` is bound at run time** (`uLogDatabase`, FPC `sqlite3dyn`;
  `docs/UPDATING_RUNTIME_DLLS.md`: 64-bit only, a missing DLL is a run-time
  failure, not a link error). `full.nsi` installs `tr4wserver.exe` in
  `$INSTDIR\server` and `sqlite3.dll` in `$INSTDIR`. [read] The default Windows DLL
  search is the executable's own folder first, so **the server will not find the
  app's copy in the parent folder** [inferred from standard Windows behaviour; not
  run]. Ship a second copy in `server\` or load it by explicit path, and make the
  server **diagnose a failed load at start**, with the station's
  `DiagnoseSQLiteLoad` message (it reads the PE header for a 32/64-bit mismatch),
  not at the first QSO.
- **Linux and macOS:** the server is built for both (tarball, `.app` bundle).
  **On Unix the guard does not exist at all:** `build-unix.sh` (line 2275) says
  `/etc/fpc.cfg` supplies the package units to every compile through a `-Fu`
  wildcard, so the Windows search-path guard has no effect there, and a green
  server build is not evidence the boundary held. [read] That strengthens D6: a
  lint is the only guard that would work on all three platforms. How the server finds
  `libsqlite3` on each, and whether the tarball ships it, is **[not checked]**; the
  AppImage collects `libsqlite3` for the app only.
- **Reuse the station's connection layer; do not fork it.**
  `uLogDatabase.pas` mixes the generic layer (`TLogConnection`, coded failures,
  `SQLiteWriteFailure`, pragmas, `CheckIntegrity`, `SnapshotTo`) with the station
  schema and migration (`ApplySchema`, `MigrateSchema`, the contest year judge,
  `uLogSchema`, `uAppPaths`). The generic half should be lifted into a lower unit
  both stores use (the repository rule in `CLAUDE.md`: when the second caller
  appears, lift it, do not copy it). **[not checked]** whether the interface section
  reaches an app unit that would drag the LCL contest code into the server; the
  implementation `uses` are `uLogSchema, uAppPaths, sqlite3dyn`.
- **Native, not raw:** use `TSQLite3Connection` through the lifted layer, not new
  `sqlite3_*` calls (the project rule against new direct DLL calls).

---

## 8. Question 3: migration and rollback

**One-time import, never destructive.**

1. At first start with the SQLite store enabled and no database file present, find
   `SERVERLOG.TRW`. If it is absent, create an empty store and write the standard
   header (the same 376 bytes as today).
2. Run `PlanServerLogRepair` first (whole / trim / refuse). A **torn tail** keeps
   today's rule: the first record must be the current header; offer the
   backup-then-trim (`<file>.torn-<stamp>.bak`, copy and size-check before trimming).
   A **wrong size with any other header** is refused untouched, as today. **A
   partial record is never imported**; the whole `.TRW` is left where it is.
3. Build under `<name>.importing`, **publish by rename** after the transaction
   commits and the database is closed with no `-wal`, `-shm` or `-journal` beside
   it. This is the station's ruling-1 pattern (`ImportBinaryLog`), so the real name
   never names a partial import, and a leftover `.importing` is discarded and the
   import runs again.
4. Import the header record **verbatim** and every record **in file order**, with
   **no deduplication** (repeats are preserved and counted in the log, because
   removing them would change what the stations download).
5. Record the source's size and CRC32 in `meta`.
6. **Never delete the `.TRW`.** Leave it in place, or rename it with a stamp
   (decision D4). Either way it is the rollback.

**Both files present at start.** If a database exists and the `.TRW` also exists
and has **changed since the import** (an older build, or TR4WServerPy writing the
same directory), the two disagree. Refuse and ask; never merge. [inferred risk, not
observed]

**Rollback is nearly free.** The sync-port stream **is** a valid `SERVERLOG.TRW`.
One exporter, writing the header blob and the record blobs in `seq` order, serves
three needs: rolling back to an older server, moving a log to TR4WServerPy, and the
test oracle. Write it as a supported command (`--export-trw <path>`), not a test
helper.

**The key test is a round trip:** import a `.TRW`, export, and compare **MD5**
for byte identity, over (a) a real contest log, (b) a log with repeated pairs and
(0, 0) records, (c) an empty log (header only), (d) a torn tail (refusal and
trim), (e) a size-mismatch header (refusal).

---

## 9. Phased plan

| phase | what | exit criterion |
| --- | --- | --- |
| **P0: oracle** | On today's server: run `netprobe` `catchup`, `restock`, `edit`, `dup`, `serial` and record the sync-port bytes of each; commit a `.TRW` fixture round-trip script. No server change. | a recorded byte baseline, against both servers |
| **P1: store seam** | Put the file code behind one interface: Append, UpdateNewest(pair), Holds(pair), Clear, ClearFlags, MaxNumberSent, StreamImage (header + records), Count, FirstContestByte, Crc. `tr4wserverUnit` calls it. **No behaviour change**; the file store is the only implementation. | the whole P0 oracle unchanged; `netprobe --case all` green |
| **P2: SQLite store** | A second implementation behind the seam: the schema of section 5.2, import once, exporter, snapshot-per-transfer for the sync port. Chosen by a setting, default **off**. | import/export MD5 round trip; P0 oracle identical on both stores |
| **P3: integrity** | Read-only on full disk with the intercom notice and recovery probe; backup before clear; integrity check at start; DLL diagnosis at start. Then the default flips (decision D8). | a forced `PRAGMA max_page_count` test; a server killed mid-run restarts holding every acknowledged QSO |
| **Later** | Derived columns, a CRC drop under a protocol bump, row-level protocol, TR4WServerPy parity. | with the row-level protocol |

TR4WServerPy parity is **not** part of P2; it is decision D2.

**Status 2026-11-19: P0 and P1 are built, uncommitted at the time of writing.**
P0 (RETIRED 2026-11-22 with the 376-byte image; replaced by `tools/netprobe/compare.py`, a row-level comparison of both servers): `tools/netprobe/Run-SyncBaseline.ps1` and `Run-TrwRoundTrip.ps1`, with
baselines for catchup, restock, edit, dup and serial. **Both servers produce the
same bytes for all five**, header record included (TR4WServerPy at its
`c1c6447`, run with `-PyServer`). Two of the five (dup, serial) write no QSOs,
so they pin only the 376-byte header. P1: `uServerLogStore.pas`
(`TServerLogStore`, the flat file as its only implementation), proven against
the P0 baselines, the round trip, `netprobe --case all` and 15 unit tests. The
sync-port snapshot hazard of section 6.2 is deliberately still there.

### Tests

- **Unit (new, leaf):** the store interface over both implementations with one
  shared test body; the import (whole, torn, refused, repeated pairs, (0, 0));
  edit-newest semantics with duplicate pairs; clear with and without a backup; the
  export MD5 round trip; a read-only transition and recovery.
- **Probe:** `tools/netprobe` all cases against the SQLite store, and against the
  file store as the baseline. New cases: `export-roundtrip` (sync-port stream equals
  the exported file), `readonly` (store refuses, relay continues, notice arrives).
- **Bench (NY4I's rig, read-only until he asks):** the in-tree server on Windows
  with two stations; kill the server mid-run and restart; fill a volume.
  `ssh mint` and `ssh pi400` per the memory note, to **read** only; nothing is
  deployed from this work. The Pi runs TR4WServerPy, started by hand.

### Risks

| risk | mitigation |
| --- | --- |
| a byte difference in the stream strands every station's catch-up | MD5 round trip before any QSO; P0 oracle on both stores |
| SQLite per-commit fsync slows a burst | one transaction per held OFFLINEQSO run; measure first |
| the boundary guard is lost | a narrower lint (D6), not a deletion |
| `sqlite3.dll` missing beside the server | explicit path + start-time diagnosis |
| the two servers drift further | the shared byte oracle; the exporter as the interchange |
| a long snapshot read blocks WAL checkpoints | short-lived read connection; bounded transfer |
| the directory is not writable (WAL) | check at start, refuse with a message |
| both a `.TRW` and a database exist | refuse and ask |

---

## 10. Decisions for NY4I

Each with a recommendation. None is assumed.

| # | decision | recommendation |
| --- | --- | --- |
| **D1** | The issue says the wire must not change; the 2026-11-13 ruling says wire formats may change at will with a protocol bump. Which governs this work? | Change **no bytes** in P0-P3 (the stream is byte-exact, free rollback). A later CRC drop needs a protocol bump. |
| **D2** | Does TR4WServerPy follow? The Pi ran it per a 2026-10-29 note, so an in-tree-only change does not protect your rig. | Yes, later, with `sqlite3` from the standard library, behind the same byte oracle, after the in-tree P2 is proven. Not in P2. |
| **D3** | Is the flat `.TRW` still a supported interchange and rollback format? | Yes: ship the exporter (`--export-trw`) as supported. |
| **D4** | After import, leave `SERVERLOG.TRW` in place or rename it with a stamp? | Rename with a stamp **after** the first clean start on the database, keep it forever; never delete. |
| **D5** | File name and identity of the server store. | A distinct extension (not `.db`) and a distinct `application_id`, so a station never opens it as a contest log. |
| **D6** | The Server search-path guard on sqldb. | Replace it with a lint: only the server-log unit may use sqldb; the guard's premise comment corrected. |
| **D7** | An edit for a pair the server does not hold: keep (relay and ACK, store nothing) or upsert. | Keep in P2; revisit with the row-level protocol. |
| **D8** | When does SQLite become the default? | Only after one bench contest weekend on the SQLite store with the file store available to roll back to. |
| **D9** | Should Clear-all-logs refuse when a backup cannot be made? | Yes, as the station's Clear Log does. |
| **D10** | Does issue 340 need a client-to-server "my log is read-only" message? | Separate issue; the server cannot learn it today. This note covers the server's own read-only state only. |

---

## 11. What was not verified

- Nothing was built, run or deployed. No test was run.
- The Python server was read, not run.
- The in-tree sync-port race (section 6.2) is confirmed from source, **not reproduced**.
- Where an **installed** server's `AppDir` resolves, and whether `server\` is
  writable for WAL files, was not checked.
- DLL lookup beside `server\` is standard Windows behaviour, not run.
- Linux and macOS packaging of `libsqlite3` for the server was not checked.
- That `uLogDatabase`'s interface does not reach app units was not checked.
- Throughput of a SQLite store is **unmeasured**; the only numbers quoted are the
  2026-10-28 file-store measurements in the agent file.
- That no deployed station reads the CRC or contest field rests on a grep of
  `src/` and on commit order in `git log`; no old build was run.
- That a delete reaches the server as an edit rests on the agent file and the
  resend code, not on a captured packet.

## 12. Small defects noticed (not fixed here)

- `DisplayServerLogSize` computes the count as `(Size - 4) div SizeOf(ContestExchange)`.
  The header is 376 bytes, not 4, and the result is right only because of floor
  division. It reads like the old 4-byte-head layout and is worth a comment or a fix
  when the seam is cut.
- The sync-port race of section 6.2.
- TR4WServerPy does not apply the clear-dupesheet and clear-mults messages to its
  log, which the in-tree server does.
- Clear-all-logs (8230) truncates with no backup, in both servers.

---

## 13. The 2026-11-22 rulings: the wire changes and the server log is rebuilt (issues 300 and 341)

NY4I approved this design on 2026-11-22. The evidence and the measurements are
in [`WIRE_FORMAT_METRICS.md`](WIRE_FORMAT_METRICS.md); this section is the plan.

### 13.1 What is decided

1. **The wire carries the QSO as an event**: the `qso` table's columns, by
   column name, including the station facts captured when the QSO was logged
   (`my_*`), minus the local bookkeeping (`id`, `session_id`, `session_seq`,
   `sent_to_server`, `server_dirty`, `sent_udp`, `udp_dirty`; `notes`,
   `rcvd_extra` and `qso_set_id` still need a ruling). The 376-byte
   `ContestExchange` is NOT the wire any more.
2. **JSON, a field omitted when it equals its column's default, plus a record
   checksum.** Omission is "equals the default", never "is zero": a nullable
   column's NULL and its 0 stay distinct. Absent means the default, never
   "unchanged"; an edit is a complete snapshot. CRC-32 over every column in
   schema order as tag + 2-byte byte-length + UTF-8 value, defaults included, so
   it is the same whether or not a sender omitted anything.
3. **The wire is UTF-8.** Every sender converts from its own native strings.
   A NUL is never sent (the writer stores NULL, and the sender treats a NUL as
   blank).
4. **No backward compatibility.** The protocol version is the schema version; a
   server refuses and REPORTS a client of a different version, and the client
   reports it to the operator (what the operator sees today has not been
   checked). The old 1040/1050/1055 QSO messages are deleted.
5. **No required-field list on the wire**; the client refuses to log a QSO with
   no callsign.
6. **The server's log is its own SQLite database**, named columns, Unicode
   text. `SERVERLOG.TRW`, its whole-log CRC32, the byte-exact sync stream and
   Python's `CE_*_OFFSET` constants are retired. **This overturns section 1
   items 1 and 2 and D1, D3 and D5.**
7. **THE MAIN-THREAD RULE: multi-op networking adds no time to logging a QSO.**
   After the commit the main thread does one non-blocking signal and nothing else
   for the network; a sender thread reads the committed row on its own connection
   and sends it. The table is already the outbox (`sent_to_server`,
   `server_dirty`). Measured today: the post is a few microseconds on the main
   thread against a 0.6 ms commit; the new design removes it.
8. **Every part of the design reads the schema through the repository**, not
   through its own SQL: the wire's column set (name, kind, default, on-wire or
   not) is defined ONCE beside `TQsoColumn`, with a test that pins it to the
   `CREATE TABLE`.

### 13.2 Three code bases change together

The Pascal client (`tr4w`), the in-tree Pascal `tr4wserver`, and the Python
`TR4WServerPy`. With no compatibility there is no mixed fleet, but the three must
move in one coordinated release, and `netprobe` is how each is proven against the
others.

### 13.3 Stages

Each stage is green on its own and leaves the program working. The unit tests, the
lints and the quick build gate each commit; the corpus, the contest matrix and the
checked run are run once per batch.

| stage | what | exit criterion |
| ----- | ---- | -------------- |
| **W1: the codec** (client; no behaviour change) | The wire column table beside `TQsoColumn` (name, kind, default, on-wire) with a test pinning it to the schema; a repository method that returns a row's wire values by column; a leaf unit with the canonical stream, CRC-32 and JSON encode/decode, UTF-8, NUL to blank; a golden-vector file read by BOTH the Pascal unit tests and `wire_check.py`; `bench_wire_formats` switched to the repository's list. | unit tests pass; Python verifies the Pascal vectors; the bench's numbers reproduce; the raw `SELECT` is gone from the bench |
| **W2: the server store** | The server's SQLite database with the wire's columns, in BOTH servers (Pascal: lift the connection layer out of `uLogDatabase` into a shared unit; Python: standard-library `sqlite3`). `netprobe` row-level cases replace the byte oracle of P0 for the new store. | both servers store and return identical rows for the same input; a server killed mid-run restarts holding every acknowledged QSO |
| **W3: protocol 5** | New QSO / edit / offline messages carrying an id AND a length (so the framing is no longer a fixed-size table); HELLO protocol 5; the version gate refuses and reports, on the server's log AND to the operator on the client; the old messages deleted. The client posts from the committed row, still from the main thread. | `netprobe --case all` green against both servers; a protocol-4 client is refused with a message the operator sees |
| **W4: the outbox sender** | The main thread signals; a sender thread reads the committed row and sends it, using the existing `sent_to_server` / `server_dirty` marking; the writer queue stays. | `bench_enter_latency` with the link up versus down: commit-to-ready unchanged; a link that drops mid-contest resends every owed row |
| **W5: catch-up and retirement** | Catch-up by per-row identity (`(ceQSOID1, ceQSOID2)` and the row's `guid`) in place of the whole-log CRC32; `SERVERLOG.TRW`, the sync-port stream and the `CE_*` offsets deleted; Clear-all-logs backs up first (D9). | a station joins late and receives the log; both servers; the old code paths are gone, not dormant |

### 13.4 Tests and benches

- **Golden vectors** shared by Pascal and Python: rows with NULL, 0, defaults,
  NUL, non-ASCII, a 510-byte value, a character outside the BMP, the string
  `"0"`. Both implementations must produce byte-identical canonical streams and
  checksums.
- **Dropped-field and exact round-trip** tests, over the corpus, as the bench
  does today.
- **The main-thread rule**: `bench_enter_latency`, link up versus down.
- **The schema pin**: a test that fails when a column is added to the table and
  not classified (on-wire or local), so the wire cannot drift from the schema.

### 13.5 Risks and open questions

- **The 376-byte stream was the rollback.** With the byte-exact sync stream gone
  there is no free rollback; the exporter (`--export-trw`) is the interchange and
  a real backup before the first run on a live station is the mitigation.
- **Defaults are defined in the `CREATE TABLE` text.** The wire table repeats
  them; the schema pin test is what keeps the two equal.
- **NUL in TEXT columns** (3,229 values in the corpus): the writer's
  `AnsiChar` binding should store NULL; unknown whether live logging does this.
- Open rulings: `notes`, `rcvd_extra`, `qso_set_id` on or off the wire; what the
  operator sees today on a version refusal; how W2's Pascal server shares the
  connection layer (section 5 of this note still applies to the lift).
- Phases P0 and P1 of section 9 (byte oracle, store seam) are described there as
  built; their status in the tree was not re-checked for this section. The store
  seam (`uServerLogStore`) is still the right interface; the byte oracle is the
  thing W5 retires.

### 13.6 The server database: the rules both servers follow (stage W2, 2026-11-22)

Built in Pascal as `src/uServerWireStore.pas` (tests `uTestServerWireStore`) and
to be built in Python from `tr4w/test/wire/columns.json`. The file is the same
thing in both: either server must be able to open the other's file, and a test
may compare them. Nothing in `tr4wserverUnit` calls the Pascal store yet (W3
swaps it in behind the `uServerLogStore` seam).

1. **File.** Extension `.tr4wsrv` (never `.db`: the station's Open dialog scans
   for that). `PRAGMA application_id = 0x54523453` (`'TR4S'`; the station's
   contest logs are `0x54523457`, `'TR4W'`). WAL and `synchronous = FULL`, set on
   the write connection and read back. A journal mode other than WAL is a warning,
   not a refusal.
2. **`meta`.** `CREATE TABLE meta (key TEXT PRIMARY KEY, value)`, one row:
   `('schema_version', 1)`. The version is `WIRE_STORE_SCHEMA_VERSION`, independent
   of `NET_PROTOCOL_VERSION` (W3 may decide to tie them). It is not defined in
   `uWireQso`, which has no version; the number lives here until W3.
3. **`qso`.** `seq INTEGER PRIMARY KEY AUTOINCREMENT`, then the 89 wire columns of
   `columns.json` IN FILE ORDER, each named as in the file. A column with
   `"num": true` is declared `INTEGER`, otherwise `TEXT` (those two words exactly).
   When `"def"` is `""` there is NO `DEFAULT` clause; otherwise `DEFAULT <def>`,
   unquoted for a numeric column and single-quoted (quotes doubled) for text
   (`DEFAULT 0`, `DEFAULT 'QSO'`). No `NOT NULL`, no `UNIQUE`, no other
   constraint. The defaults are descriptive only: every insert names every column.
4. **Index.** `CREATE INDEX idx_qso_guid ON qso(guid)`, NON-unique.
5. **Identity is `guid`**, because the old pair `(ceQSOID1, ceQSOID2)` is the
   station's `session_id` / `session_seq`, which are local columns and never on
   the wire. `''` (NULL) is the old `(0, 0)`: it names nothing, is stored every
   time, is never "held", and an edit carrying it changes nothing. (Before, a
   `(0, 0)` edit rewrote the newest `(0, 0)` record: that was a guess.)
6. **Insert if absent**, in the insert, inside its transaction:
   `INSERT INTO qso (...) SELECT :p0, ... WHERE NOT EXISTS (SELECT 1 FROM qso
   WHERE guid = :g)` when the guid is not empty, a plain `INSERT` when it is.
   Rows affected 0 is "duplicate": nothing stored, nothing relayed, an OFFLINEQSO
   still ACKed. Never a UNIQUE index: a log restocked from several stations may
   hold repeats (5.2).
7. **Edit** (last writer wins, the whole row, no edit counter):
   `UPDATE qso SET <every column> = :p WHERE seq = (SELECT MAX(seq) FROM qso WHERE
   guid = :g)`. A field the edit omits is its DEFAULT, never "unchanged". An edit
   for a guid the server does not hold stores nothing and is not a failure
   (relayed and ACKed, as today; design 6.4, decision D7 still open).
8. **NULL versus ''.** Canonical text makes NULL and `''` one value, so EVERY
   column stores `''` as NULL and reads NULL back as `''`. A numeric column holds
   an integer (bound as one, read back as its canonical digits); a text column
   holds text, so the string `"0"` stays text. A numeric value that is not
   canonical digits is rejected before any write (`TryCanonicalInt64`: optional
   `-`, then digits; no `$1F`, `0x1F`, `14.025`, spaces).
9. **Text is UTF-8** bytes, stored and read byte for byte.
10. **ReadAll** is `SELECT <the 89 columns> FROM qso ORDER BY seq` on a read-only
    connection of its own, one transaction: arrival order, a snapshot of what is
    committed, safe from any thread. This replaces the byte-exact sync image.
11. **Held run** (a run of OFFLINEQSO packets): one transaction, committed at
    Release. An ACK sent before Release is an ACK for a row that is not yet
    durable, so W3 must ACK a held run AFTER Release. A failure inside the run
    rolls back the whole run and ends the hold.
12. **Open.** A missing file or an empty SQLite file is created (tables, version,
    application id). An existing file is examined READ-ONLY first (no write at
    all) and refused, left untouched, and reported when: its application id is
    not `0x54523453` (and not 0 with no tables); its `schema_version` is not this
    server's; its `qso` columns are not exactly `seq` then the wire's columns in
    order; or it fails `PRAGMA integrity_check`. Never silently reused, never
    migrated.
13. **Clear** deletes every `qso` row (`seq` keeps increasing). **ClearFlags**
    changes only rows whose `record_kind = 'QSO'`: set-dupesheet sets
    `clear_dupe_sheet = 1`; clear-mults sets `clear_mult_sheet = 1` and
    `mult_domestic`, `mult_dx`, `mult_prefix`, `mult_zone` to 0; both answer
    False for an empty store. **MaxNumberSent** is
    `COALESCE(MAX(serial_sent), 0)` over every row (the old -1 is NULL).

### 13.7 Protocol 5 and catch-up: the W3+W5 contract (NY4I, 2026-11-22)

W3 and W5 are ONE change. The survey (scratchpad `w3_map.md`) showed the sync
port, the client catch-up, push and restock all work on the 376-byte file image
and on `(ceQSOID1, ceQSOID2)`, which the wire no longer carries; a W3 that left
them would not leave a working program. It lands as commits on one branch and
ships together. No bridge that fabricates 376-byte images.

**Rulings (NY4I, 2026-11-22):**

1. W3+W5 merged, as above.
2. **A receiver stores the SENDER's facts verbatim**: every wire column of a
   peer's QSO, `my_*` and `my_source` included, goes into its row as sent. This
   replaces ruling D for rows that arrive on the wire.
3. **A station pushes only rows logged HERE** (the wire `computer_id` equals this
   station's own computer id), so pre-upgrade rows copied from peers, which carry
   local guids, cannot be duplicated onto the server. **Catch-up DOWNLOAD is
   unchanged in effect**: a station that was offline receives every QSO the server
   holds that it lacks, insert-only by guid, after a backup, as today.
4. **The server holds one contest**: the server database `meta` carries
   `contest` (the contest id string the first accepted station announced in its
   HELLO). A client compares it once at catch-up and refuses with the existing
   contest-mismatch notice; there is no per-row judge.
5. The wire's `notes`, `rcvd_extra` and `qso_set_id` stay on the wire (W1 table).
6. The operator-visible version refusal already exists (`RefuseServerProtocol`,
   `SM_PROTOCOL_MISMATCH`, `SNetServerProtocolOlder/Newer`); W3 raises the
   version to 5 and keeps the HELLO a FIXED 70 bytes parsed first, so a
   protocol-4 peer is still refused readably.

**Framing.** The three QSO messages (new, edited, offline) become variable
length. Every other message keeps its fixed size and the existing table. A
variable message is: 2-byte LE message id, 4-byte LE payload length, payload.
New ids (old 1040/1050/1055 are deleted and become unknown ids, logged and
dropped): `NET_WIRE_QSO_ID` 1041, `NET_WIRE_EDIT_ID` 1051,
`NET_WIRE_OFFLINE_ID` 1057 (1056 is taken by NET_THIS_QTC_WAS__SEND_ID). Payload length cap
60000; larger is a protocol error: the sender of it is disconnected and the
reason logged (never a buffer left holding bytes that cannot complete).
Receive buffers on the client and both servers are raised to 131072 so a whole
frame always fits; a frame is consumed only when whole.

**Payload.** 1 byte sender computer id (the client sets its own; the server
re-stamps it on relay from the accepted HELLO), then the UTF-8 JSON object from
`uWireQso.EncodeJson` (defaults omitted, member `"k"` the record CRC-32 as hex).
A bad checksum, unparsable JSON, or a numeric value that fails
`TryCanonicalInt64` rejects the row: logged, not stored, not relayed, and the
link is NOT dropped. A NUL is never sent (blank).

**Server behaviour.** Stores through `TServerWireStore`; relays a NEW or EDIT to
every other station only when stored (or already held, for the duplicate case:
not relayed); an OFFLINE row is stored but never relayed and is ACKed only after
`Release` (13.6 rule 11); an edit for a guid not held is relayed and ACKed, not
stored (as today). Clear-all, clear-dupesheet, clear-mults and the serial scan
use the store's `Clear`, `ClearFlags`, `MaxNumberSent`. **Clear-all-logs copies
the database to a dated backup first (D9).** An existing `SERVERLOG.TRW` is
reported once in the server log as unused and left in place (never deleted).
The server file is `SERVERLOG.tr4wsrv`.

**Sync stream (the sync port).** One connection, server to client: a header
frame `{"contest":"<id>","rows":N,"schema":5}` as 4-byte LE length + UTF-8 JSON,
then N row frames of 4-byte LE length + the UTF-8 JSON row (no sender byte), in
arrival order, taken from ONE `ReadAll` snapshot. The log-info packet becomes the
row count.

**Client.** After the commit the main thread posts the row id; the message is
built from the committed row (`ReadWireValues` -> `EncodeJson`); W4 later moves
that to a sender thread. A received NEW row is saved through the by-guid path
keeping the sender's guid and columns; a guid already held is ignored; an EDIT
replaces the row's wire columns. Own-echo test and contest judge keep using the
header's sender id. Catch-up: read the sync stream; refuse on a contest
mismatch; insert (by guid, after backup) every row the station lacks; push (as
OFFLINE rows) every row logged here that the server's guid set lacks. Restock
pushes only rows logged here. `TPushPlan`, `uNetCatchUp`, `uGetServerLog`,
`uServerLogForm`, dedupe, the delivery tag, the resend set and
`CollectSessionKeys` / `CollectUnsentToServer` move from the pair to the guid.

**Retired in the same change:** `TFileServerLogStore`, the 376-byte sync image,
the whole-log CRC32, the Python `CE_*` offsets, the byte-oracle baselines and
their scripts (or turned into a row dump), the old 1040/1050/1055 framing.

**The Move/FillChar ceiling (418) must not rise.** New code uses `TBytes`,
`SetLength`/`Copy`, `Default()`, assignment and indexed loops, never `Move`,
`FillChar` or `ZeroMemory`; the lint is run on every commit of this change.
