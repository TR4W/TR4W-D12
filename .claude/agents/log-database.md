---
name: log-database
description: The contest log in SQLite — schema, the database layer, the repository, log source selection, search, notes, backup and integrity. Use for anything that reads or writes QSOs, the log store, database migrations, log naming, or log integrity checks.
tools: Read, Grep, Glob, Bash, Edit, Write
model: opus
---

You own the contest log. **It is SQLite, and has been since 2026-09-01.**

## Your files

| | |
|---|---|
| database + pragmas + integrity | `tr4w/src/domain/uLogDatabase.pas` |
| the watchdog over every SECOND connection (the WRL worker's) | `tr4w/src/domain/uLogConnectionWatch.pas`, a leaf; its timer is in `uWRLExternalLogger.pas`; tests in `test/unit/uTestLogLocking.pas` |
| backup orchestration (stage, verify, `.bak`, publish) | `tr4w/src/domain/uLogBackup.pas` — `LogStoreBackup` is a thin caller; tests in `test/unit/uTestLogBackup.pas` |
| the copy to BACKUP DESTINATION (worker thread, file I/O only) | `tr4w/src/domain/uBackupCopier.pas`, glue `tr4w/src/uBackupCopyService.pas`; tests in `test/unit/uTestBackupCopier.pas` |
| schema | `tr4w/src/domain/uLogSchema.pas` |
| repository | `tr4w/src/uLogRepository.pas` |
| the read seam — SQLite only, no source selection | `tr4w/src/uLogSource.pas` |
| store, search, notes, naming, config | `uLogStore.pas`, `uLogSearch.pas`, `uLogNote.pas`, `uLogNaming.pas`, `uLogConfig.pas` (**the Log4D layout, NOT the config table**). (`uLogCompare.pas` was listed here and was never the store's: it was the multi-op Difference-in-logs dialog's seam, deleted with the dialog in Phase 1, C6.) |
| which contest-scoped `config` rows are written, and which stored ones are statements | `uLogContestStatements.pas`, a leaf so the rules are unit-tested (`uTestLogContestStatements`) |
| our station as it was for one QSO (the my_* columns, schema 3) | `tr4w/src/domain/uQsoMyFacts.pas`, a leaf (`uTestLogMyFacts`) |
| import only | `uLogImport.pas`, `uLogBinaryFile.pas` |
| docs | **`docs/LOG_SCHEMA.md` -- THE SCHEMA AS IT STANDS** (every column and its class, the reader rule, the version history, the add-a-column checklist; keep it current with every schema change), `docs/SQLITE_MIGRATION_TASKS.md` (**read before touching log storage**), `docs/SQLITE_LOG_SCHEMA_PLAN.md` (plan and decision history, not the definition) |

**The binary `.TRW` is IMPORT-ONLY.** `tAddQSOToLog` writes to the database and
nowhere else. Anything that assumes a live `.TRW` is stale.

## The standard these units set — hold new code to it

The five log units carry **no `PChar` of any kind** and no raw platform calls.
That is deliberate and it is the bar.

**Before reaching for a C call, check whether the wrapper already has a method.**
The worked example: pragmas first went through `sqlite3_exec`, justified as "the C
API takes a `PAnsiChar` by definition" — true of that function and beside the
point. `TSQLConnection.ExecuteDirect` is the wrong method (`sqldb.pp:1492` starts
a transaction unconditionally), but **`TSQLite3Connection.execsql`** is the
connector's own transaction-free path, takes a native `string`, and already owns
the `PAnsiChar`, the error message and the `sqlite3_free`. It is `protected`, so a
descendant reaches it — which is what `protected` is for.

Likewise: `TFileStream`, not `Windows.ReadFile`. And **never** a hardcoded
`'sqlite3.dll'` — FPC's own `sqlite3.inc:28-30` does the platform naming.

## A measured trap worth keeping

**`BEGIN IMMEDIATE` does not detect a read-only database.** Measured: it returns
no error; only an actual write does (`attempt to write a readonly database`). The
writability probe is a **same-value `PRAGMA user_version`** — read it, write it
back unchanged.

And `faReadOnly` binds to `db.TFieldAttribute` because sqldb pulls `db` after
`SysUtils` — qualify it as `SysUtils.faReadOnly`.

`FileSetAttr` is **Windows-only**; tests that mark a file read-only need
`FpChmod` under `{$IFDEF UNIX}`.

**`TLogDatabase.Open` WRITES — USE `OpenReadOnly` TO INSPECT.** `ApplyPragmas`
sets `journal_mode = WAL` (and `MigrateSchema` may run), so anything that "only
opens to check" changes the file. Measured 2026-09-18 on a backup snapshot:
header bytes 18, 19, 27 and 95 go 1 to 2 (rollback journal to WAL); no page
content changes.

`TLogDatabase.OpenReadOnly` (2026-09-19) is the door for a file you must not
disturb: `OpenFlags = [sofReadOnly]` — the connector's own path into
`sqlite3_open_v2` — no write-side pragmas, no `MigrateSchema`, and
`CheckIntegrity` skips its WAL checkpoint there. `VerifyIdentity` is kept,
because it only reads. `Open` is unchanged and still fail-closed. The backup
verifier uses it, so a published backup is now byte-identical to the snapshot
(pinned by an MD5 comparison in `uTestLogBackup`).

**CLEAR LOG TAKES A VERIFIED BACKUP FIRST, AND DOES NOT CLEAR WITHOUT ONE
(2026-10-23).** `MainUnit.ClearLog` calls `LogStoreBackupBeforeClear` ->
`LogStoreBackup` to `<log name less .db> before clear <UTC yyyy-mm-dd
hhnnss>Z.db` (`LogStoreClearBackupFileName`, pinned in `uTestLogStore`). A
failed backup is an Error line plus `showwarning`, and nothing is deleted.
The `.TRW` is not read, copied or named. An empty log is backed up like any
other.
- **IT IS WRITTEN TO `uAppPaths.BackupDir`, NOT BESIDE THE LOG (issue #98
  step 1, 2026-10-24).** `BackupDir` is `backup` under the writable settings
  directory (`target\settings\backup\` on Windows), and `--settings` moves it
  with `DownloadedDataDir` (one base, `WritableSettingsDir`). A backup beside
  the log was listed by the Open dialog (it scans `ContestDir` for `*.db`,
  not recursively) as a contest, and sorted below its own cleared log. The
  caller passes the folder (`LogStoreBackupBeforeClear(BackupDir, ...)`), so
  a test hands in a scratch one; **never call `BackupDir` from a test** --
  the unit-test binary would create it under the real settings directory.
- **Names never stack**: every trailing ` before clear <stamp>Z` or ` before
  catch-up <stamp>Z` of exactly that shape, and every trailing ` periodic`, is
  removed from the log's name
  first -- ONE rule, `uLogBackup.LogBackupBaseName`, under both names.
  **A folder that cannot be made fails the backup** (no fallback beside the
  log); the test uses a file occupying the folder's name. Backups already
  beside logs (old `logback.db` files included) are left alone.

**THE PERIODIC BACKUP IS LOCAL FIRST, THEN COPIED (issue #98 step 2,
2026-10-25).**
- **Local**: `logstuff.BackupLogNow` -> `LogStoreBackupPeriodic(BackupDir,
  ...)` -> `LogStoreBackup` to `<log> periodic.db` in `BackupDir`
  (`LogStorePeriodicBackupFileName`), one per log, `.bak` kept by
  `TLogBackup`. It replaced `logback.db`, one name every contest overwrote
  beside the logs. **BACKUP LOG FREQUENCY = 0 is the off switch**; an empty
  name no longer is (there is no name). **OFF THE MAIN THREAD SINCE ISSUE
  350** when the log is WAL -- see "THE PERIODIC BACKUP RUNS ON A WORKER"
  below; `BackupLogNowInline` keeps the synchronous run for a non-WAL log.
- **THE TRIGGER IS A COUNT OF QSOs LOGGED SINCE THE LAST BACKUP, NOT
  `QSOTotals mod N` (2026-10-31).** QSOTotals is a score total (no X-QSO, no
  deleted QSO, rebuilt by a rescore), so it went DOWN and fired a second
  backup one QSO after the first (live: frequency 5, W4UB X-QSO'd). Now
  `LogContact` calls `logstuff.CountQsoTowardPeriodicBackup` once per record
  written (X-QSOs, dupes and peer QSOs included; notes go elsewhere and do
  not count); the rule is `uLogBackup.PeriodicBackupDue` (`>=`, 0 = never),
  pinned by `uTestLogBackup.TPeriodicBackupDueTests`. **Only a SUCCESSFUL
  `BackupLogNow` resets the count** (issue 351 (b), 2026-11-21; it reset on
  failure too until then). Rescore/reload never touch it; it starts at 0
  each session.
- **ISSUE 351 (b): THE RULE ALSO ASKS THE CLOCK.** Due when the count
  reaches N, OR the last SUCCESSFUL backup is `PERIODIC_BACKUP_MAX_AGE_SEC`
  (30 min) old or absent -- so a short session backs up on its first QSO.
  "Last success" is the published `<log> periodic.db`'s MODIFICATION TIME
  (`LogStoreSecondsSincePeriodicBackup`): it exists only after a verified
  publish, survives a restart, and needs no row, no write path and no write
  to a possibly full disk. A failure resets nothing; the retry is throttled
  by `PERIODIC_BACKUP_RETRY_SEC` (5 min, `LogStoreNotePeriodicBackup` keeps
  the failure tick, in memory), and `LogStoreShowRecoveryNotice` re-says
  `SLogBackupStillFailing` after every QSO until a success. Frequency 0 asks
  nothing (no `BackupDir`, no stat).
- **ISSUE 351 (a): every open reads back `synchronous` and
  `sqlite_version()`** (plain SQL; `TLogDatabase.Synchronous`,
  `.SQLiteVersion`), and the store logs one Info line after `log database:`
  plus a Warn per shortfall from the pure `uLogDatabase.LogDurabilityWarnings`
  (synchronous < FULL on a write connection, journal not WAL, SQLite older
  than 3.27.0 or unreadable). Pinned in `uTestLogLocking`.
- **ISSUE 351 (c): A STARTUP WRITE CHECK THE DISK REFUSES OPENS THE LOG
  READ-ONLY** when `TLogDatabase.WritableFailure <> lwfNone` (set by
  `CheckWritable` by code: folder, attribute, or `SQLiteWriteFailure` of the
  write), integrity just passed, the schema is current, and the open neither
  created nor migrated it (`ReopenReadOnlyAfterAStartupWriteFailure`, shares
  `ReopenReadOnlyAtThisSchema` with the locked-log choice). Same modal and
  causes as a mid-contest full disk. `LogStoreTryRecoverWrites` sees a
  read-only CONNECTION and opens a fresh write connection beside it, swaps
  only after `CheckWritable` passes (`ReopenForWritingAfterAStartupWriteFailure`).
  NOT unit-tested yet; the WRL worker is not started after such a recovery.
- **Copy**: `BACKUP DESTINATION` (`Settings.Log.BackupDestination`, a
  FOLDER, '' = local only) replaced `BACKUP LOG FILE NAME`, which is now its
  second name; a value under the old name is converted by NAME
  (`RegisterCommandValueSpelling` -> `FolderOfFormerBackupFileName`: a folder
  carries over, a bare name becomes ''), and an old settings file's
  `Log.BackupFileName` member by `TR4WSettings.CarryFormerBackupFileName`.
  Not in `SHARED_WITH_PEERS` any more.
- **`src/domain/uBackupCopier.pas`** (one worker thread, file I/O only, NO
  SQLite object) and its glue `src/uBackupCopyService.pas`. The worker never
  opens the published local file: `Submit` copies it into `BackupDir\outbox`
  under a unique name, so a slow share can never make the next local
  publish's rename fail (Windows refuses to rename an open file). Pending
  jobs coalesce per file name. Copy = `.partial` (unique, same folder),
  `FileFlush`, byte read-back, then a rename dance that never targets an
  existing name and rolls back on failure. **The destination folder is never
  created** (an unmounted `/Volumes` share is a local folder). Retries every
  60 s on its own clock; reports are TRANSITIONS (reachable / failed /
  recovered), marshalled by `QueueAsyncCall`. `Shutdown` is bounded
  (`BACKUP_COPY_SHUTDOWN_MS`); on False the copier is not freed.
- **What the operator sees (2026-10-25).** With a destination, `BackupLogNow`
  says "Log backed up; copying to <FOLDER> ..." -- the destination, not the
  local file; NY4I read the local name as "the destination was ignored" when
  the copy had worked. Every arriving generation (`bceCopied`) then shows
  "Backup copied to <file>", no beep, and is an INFO line. Both texts are
  `uBackupCopyService.BackupDoneText` / `BackupCopyNotice`, pure and pinned in
  `uTestBackupCopier` (`TBackupCopyNoticeTests`). `BackupCopySubmit` now
  returns whether it queued, and no longer writes the status line itself.
  ~~At open, a destination that already holds the generation is also
  `bceCopied`~~ -- **NOT SINCE 2026-10-25 (NY4I: hide it).** An
  `OnlyIfDifferent` job that finds identical bytes writes nothing and
  reports **`bceAlreadyCurrent`**: no status-line notice (`BackupCopyNotice`
  gives empty text, and the receiver queues nothing), an Info line "already
  up to date at <file>". It is still a SUCCESS for the health transitions:
  after a failure it reports `bceRecovered` once, as a write would
  (`TestASkipAfterAFailureIsARecoveryOnce`). `bceCopied` means a real write.
- **A FAILED COPY SAYS ONE SHORT SENTENCE (NY4I, 2026-11-18, after a full
  D: showed "... failed: Stream write error. Logging continues, ...").**
  The report carries `TBackupCopyFailure` (`bcfDiskFull`,
  `bcfFolderMissing`, `bcfNoAccess`, `bcfOther`); the status line is
  `BackupCopyFailedText` -- folder + reason, NEVER the detail, which goes to
  tr4w.log only. The reason comes from the OS CODE, not exception text:
  `TBackupFileOps` writes with `FileCreate`/`FileWrite`/`FileFlush` (not
  `TFileStream`, whose `WriteBuffer` raises a code-less `EWriteError`) and
  raises `RaiseLastOSError(GetLastOSError)` at the failing call;
  `BackupFailureOfOSCode` maps it. **A code-less write error is
  `bcfOther`, never "disk full"**: a share dropping mid-copy fails the same
  way. Tests: `TestACopyFailureIsClassifiedByTheSystemsCode`,
  `TestAFailureNeverShowsItsDetail`, `TestTheSystemsCodesAreClassified`.
- **Started in `uProgramMain` after every headless Halt** (so the corpus
  never probes a share), which also offers this log's existing periodic
  backup to the destination, copied only if it differs. Tests:
  `uTestBackupCopier` (copier + setting), `uTestLogStore` (names, folder).
- **Still open in #98**: the 60 s dirty
  timer, generations/catalog/SHA-256, retention, Restore, and reconciling an
  ambiguous rename on a share by name + hash. (The snapshot off the main
  thread is done: issue 350, below.)
- **THE PERIODIC BACKUP RUNS ON A WORKER (issue 350, 2026-11-22).**
  `src/domain/uLogBackupWorker.pas` (leaf: one `TThread`, `TCriticalSection`,
  `TEvent`) runs `uLogBackup.TLogFileBackup.Run` -- the SAME stage, verify
  and publish as the synchronous path, lifted to the interface, not copied
  -- then the outbox copy (`OnPublished` = `BackupCopySubmit`, which locks
  inside the copier). Glue `src/uPeriodicBackupService.pas`: lazy creation,
  results hopped to the main thread by `Application.QueueAsyncCall`,
  `PeriodicBackupStop` in `tr4w_ShutDown` BEFORE `BackupCopyStop` and
  `LogStoreClose`. Main thread: `logstuff.PeriodicBackupArrived` ->
  `ShowPeriodicBackupOutcome` (shared with `BackupLogNowInline`, so the
  status line, beep, `LogStoreNotePeriodicBackup` and the 351 reminder are
  one code path).
  - **WAL ONLY** (`uLogStore.LogStoreJournalIsWal`). In rollback-journal mode
    a reader's SHARED lock blocks the writer's commit, so a non-WAL log (a
    share) keeps the synchronous run.
  - **Coalesced, not queued** (`TBackupCoalescer`, pure, pinned in
    `uTestLogBackupWorker`): a request during a run is ONE more run, the
    newest request's values. `CountQsoTowardPeriodicBackup` does not ask
    while `PeriodicBackupInFlight` (the count and the file age still say
    "due" until the result lands); the menu does ask (the "again" flag). Both
    callers use the worker, so they never write the same `.new` at once.
  - **The count**: `Tag` is `QsosCountedThisSession` at the request; a
    success raises `QsosCoveredByBackup` to it and the count becomes total
    minus covered, so QSOs logged during the run stay counted and two
    coalesced results never subtract twice. The inline path covers all.
  - **Enabled only by `uProgramMain`** (`PeriodicBackupEnable`, beside
    `BackupCopyStart`, after every headless Halt): `/MATRIX`, `/EXPORT` and
    the unit-test program keep the synchronous run and never start the
    thread.
  - **Per-run connections, NOT watched**: `TLogFileBackup` opens read-only
    and closes per run, so no long-lived read transaction blocks WAL resets
    between runs; `uLogConnectionWatch` would interrupt a long VACUUM INTO,
    so the backup's connections take no `Watch`.
  - **Shutdown waits for the run in progress** (unbounded: local disk, and
    the thread holds a SQLite connection); a request not yet started is
    dropped -- the next session backs up on its first QSO by file age. No
    startup sweep of `.new`: `Run` step 3 deletes a stale one, and `Run`
    deliberately KEEPS a verified `.new` when the publish rename fails.
  - **Stay synchronous**: `LogStoreBackupBefore*` (Clear Log, catch-up) and
    `BackUpLogBeforeUpgrade`. There is no Restore yet.
  - **Measure**: `tr4w/test/bench/bench_enter_latency.lpr` (phases: commit
    only / inline backup / worker; p50-p99-max; `sqlite3.dll` beside it).
    No numbers recorded yet -- BENCH_QUEUE.md.
- **NEVER RUN `VACUUM` (INTO OR NOT) ON THE LIVE CONNECTION (2026-10-24).**
  A VACUUM resets every schema of the connection that runs it, and FPC's
  connector prepares with the LEGACY `sqlite3_prepare`, which never
  re-prepares. So every KEPT statement is broken for good. Live in CQ WW SSB
  on 5.0.33: after each periodic backup the grid's `ReadRange` raised
  `TLogConnection : not an error` on every repaint. `TLogDatabase.SnapshotTo`
  now opens its own short-lived `OpenReadOnly` connection to the file and
  runs `VACUUM INTO` there. It copies every COMMITTED row, the `-wal` included.
  Pinned by `uTestLogStore.TestTheGridReadsTheLogAfterABackup`, which was
  seen to fail on the old code with that exact message.
- **So `TLogStoreBackup.SnapshotTo` no longer commits and no longer refuses
  during a batch.** Both existed only because `VACUUM INTO` on the live
  connection refuses the read transaction sqldb leaves open ("cannot VACUUM
  from within a transaction", 2026-10-23). A separate connection ignores it.
  Do not put the commit back: a backup must not decide a write.
- The same hazard covers any statement that expires prepared statements
  (`OP_Expire`: a flag pragma such as `foreign_keys`; ATTACH/DETACH; DDL that
  bumps the schema cookie). Today every one of them runs at open or migration,
  before `TLogRepository.Create` prepares anything. Keep it that way.

**And the stray-`-wal` worry that went with that finding did NOT reproduce**
(measured 2026-09-19): on a clean close SQLite removed both sidecars, so the
old code left nothing behind. The exposure was only a crash mid-check, and a
read-only connection to a rollback-journal file creates no WAL at all.

**BUT A READ-ONLY CONNECTION TO A WAL-MODE LOG LEAVES ITS `-wal` BEHIND**
(measured 2026-10-14, `OpenReadOnly` and Python's `?mode=ro` alike). A test
that asserts "nothing beside the file" must check BEFORE it opens the file to
inspect it.

**TO GLANCE AT A LOG, `TLogDatabase.OpenToPeek` (2026-10-19)** -- the New
Contest dialog's Last Contest button, through `uLogFileFacts.ReadLogFileFacts`.
With NO sidecar beside the file it opens `file:...?immutable=1` (`sofURI` +
`sofReadOnly`): no lock, no WAL, nothing left behind. With ANY sidecar --
`-wal`, `-shm` or `-journal` (`LogSidecarPresent`, lifted out of `uLogImport`)
-- it falls back to `OpenReadOnly`. **The `-journal` matters**: the first
version checked only `-wal`, so a rollback-journal log (a network share) in the
middle of a write was read immutable, uncommitted spilled pages and all
(`Test_ARollbackLogMidWriteIsNotReadImmutable`). The decision lives in
`OpenToPeek`, not the caller. A writer arriving between the check and the
read is an accepted window: the peek can misread, never harm the writer.
- **`ImmutableURI`**: a drive gets `file:///C:/`, a UNC name `file:////server/`
  (empty authority, the only kind SQLite accepts by default); `%`, `?`, `#`,
  space are escaped; a backslash is a separator only where it is
  `DirectorySeparator` -- on Unix it is `%5C`. URIs work in the shipped
  `sqlite3.dll` because `sofURI` asks per open; proven end to end by an awkward
  path (`%41`, `#`, an accent) and by `\\localhost\C$` in `uTestLatestContest`.

**EVERY "NOW" STORED IN THE LOG IS UNIX UTC (2026-10-19).**
`DateTimeToUnix` does NOT convert -- its `AInputIsUTC` defaults to True -- so
`DateTimeToUnix(Now)` stores LOCAL time. `contest.created_at`, `config.set_at`,
`session_state.saved_at` and the contest guid's UUIDv7 timestamp all did. They
go through `uLogRepository.UnixNowUTC` (`LocalTimeToUniversal(Now)`, the tree's
one way). Rows already written keep their value; nothing migrates them.
Pinned by `TestEveryNowTheLogStoresIsUTC`, which can only discriminate on a
machine whose clock is not UTC, and says so on one that is.

**NEVER `FieldByName` IN A PER-ROW READ.** In FPC 3.2.2 `TFields.FindField` is
a linear scan that upper-cases both names on every comparison. `ReadRecord` paid
about 190 µs a row for it, on every read path (measured 2026-10-14), and that
was most of the cost of an `/EXPORT`. It now reads `Fields[Ord(qc_x)]`.
`TQsoColumn` is in `QSO_COLUMNS` order, and each identifier is `qc_` + the column
name, which `BuildQsoColumnTable` checks through RTTI.

- **Add or move a column in BOTH `QSO_COLUMNS` and `TQsoColumn`, or no
  repository can be created.** `TLogRepository.Create` raises the mismatch.
- **Open every qso reader through `OpenQsoReader`.** It checks the fields by
  name, once per Open, and raises on any drift. A reader opened any other way
  bypasses the guard that position-reading depends on.
- **Do not "fix" a raise by falling back to name lookup.** The pins are in
  `uTestLogRepository`: the table, a drifted SELECT, and every reader
  round-tripping a record.

**Make every SELECT with `NewReadQuery`.** It sets `UsePrimaryKeyAsKey :=
False`. With sqldb's default, every Open of a single-table SELECT first runs
three PRAGMAs (`UpdateServerIndexDefs`, `sqldb.pp:3121`) for key metadata that
nothing here uses: about 935 against 715 µs an Open. `ParseSQL := False`
measures the same, but only as a side effect, so it was not chosen. A statement
called per row is prepared once and kept, like `FRowIdAtIndex`. Do not create it
per call. Numbers: `docs/SQLITE_LOG_SCHEMA_PLAN.md` §9c.

**A WHOLE-LOG PASS READS ONCE AND WRITES ONCE (F1/F4, 2026-10-14).**
`tUpdateLog` runs the rescore and the dupe- and mult-sheet clears. It reads
through `LogSourceNextWithRowId`, collects the changed records in a
`TLogRowUpdates` (row id + record), closes the cursor, and writes them with
`LogStoreUpdateQSOsByRowId`, which is all or none: `TLogRepository.WriteBatch`
rolls back and re-raises, then the store disables itself.
- **Do not go back to `LogSourceReadAtIndex` in a loop.** It is an `OFFSET` walk
  plus a 68-column Open per row. winter_fd's `/RESCORE` went from 2.17 s to
  0.48 s without it.
- **The sequential cursor is `QSO_COLUMNS, id`.** The id comes after the QSO
  columns, at position `QSO_COLUMN_COUNT`, and is checked by name
  (`OpenQsoReader(q, True)`).
- **Never begin a batch with the cursor open.** `Commit` closes every dataset on
  the transaction (`sqldb.pp:2412`). `BeginBatchUpdate` refuses, which is why
  the pass collects its rows instead of writing as it goes.

**A SEQUENCE OF WRITES IS ATOMIC ONLY INSIDE A TRANSACTION THAT ITS CALLER
ENDS WITH `Commit`** (the audit is in `docs/SQLITE_LOG_SCHEMA_PLAN.md` §9c,
2026-10-14). A comment that claims "one transaction" is not evidence; a test
is. On failure, nothing commits, and `TLogDatabase.Close` rolls back.

- **sqldb starts a transaction only when a statement PREPARES**
  (`sqldb.pp:1296`). `FInsert` and `FUpdate` are prepared once and kept, so
  after any `Commit` they used to run in SQLite AUTOCOMMIT. Measured before
  the fix: of "two SaveQSOs" the first survived a crash and the second did
  not. **Every execution of a kept write statement goes through
  `TLogRepository.ExecuteKeptWrite`**, which begins the transaction. A new
  kept write statement must do the same. Pinned by
  `TestEveryWriteWaitsForItsCommit` (16 write paths).
- **SQLite can end a transaction itself** (on FULL, IOERR, NOMEM or BUSY), and
  sqldb is not told. Its `ROLLBACK` then raises "no transaction is active" and
  it stays `Active`. **Roll back through `TLogDatabase.Rollback`**, never
  `Transaction.Rollback`. It resyncs the two with a raw `BEGIN` and matches no
  message text. Pinned by `TestABatchSQLiteRollsBackItself...` and
  `TestALogSQLiteRolledBackClosesCleanly`.
- **The pin covers 21 write paths** (17 until issue 300 added
  `BackfillYearSent` and `CorrectSentYear`, 2026-11-13; the fingerprint now
  includes `year_sent`; schema 9 added `BackfillStationFacts`, 2026-11-17,
  and `my_prec`; schema 10 added `BackfillOffContest`, 2026-11-19, and
  `is_off_contest`). `SetSentExchange` joined it and left
  again the same day (2026-10-17) when its only caller was deleted; the
  fingerprint still includes `exchange_sent`. `UpdateQSOMyFacts` (the Edit
  QSO write of the my_* columns) joined on 2026-10-18, and the fingerprint
  now also includes `my_grid` and `my_source`. `MarkServerProgress` (the
  multi-op bookkeeping, 2026-10-27) is the 17th, and the fingerprint also
  includes `sent_to_server` and `server_dirty`.
- **`BeginBatchUpdate` still commits what is pending and then starts its own
  transaction**, so a batch's rollback undoes the batch and nothing before it.
- **How to test a "one transaction" claim:**
  1. Commit a seed.
  2. Run the path, and inject a failure part-way. A raising callback works
     (`aIsRetired`), and so does a `RAISE(ROLLBACK)` / `RAISE(FAIL)` trigger.
     Create the trigger, then create a NEW repository: statements prepared
     before it fail with "schema has changed".
  3. Prove through the same connection that the write happened.
  4. Free the repository and database WITHOUT a commit. That is what a crash
     leaves.
  5. Reopen and compare with the seed.
  6. Mutation-test the pin.
- ~~**Open (§9c):** the migration import's FILE is not atomic~~ and ~~the ADIF
  import commits per QSO on purpose~~ -- **both RULED AND DONE by NY4I,
  2026-10-14.** Section 9c, "NY4I's three rulings", has the detail and the
  numbers. A county-line contact still commits per QSO on purpose: the commit
  is the contact.

**A `.TRW` MIGRATION IS BUILT UNDER `<log>.db.importing` AND PUBLISHED BY
RENAME (ruling 1, 2026-10-14).** `ImportBinaryLog` renames the staged file to
the log only after every record is written, the transaction has committed,
and the database is CLOSED with no `-wal`, `-shm` or `-journal` left beside it.
So the log's name never names a partial import, and `EnsureOpen`'s "migrate
when the `.db` is missing" IS the recovery.
- A leftover from a crash is discarded and the import starts again; `EnsureOpen`
  logs it at Error (`RECOVERED FROM AN INTERRUPTED MIGRATION`).
- **A failed record publishes nothing**, for every caller, `/IMPORTLOG`
  included.
- **The sidecar check after the close is the guarantee**, and it is load-bearing
  on Unix. `rename(2)` happily moves an open file away from its `-wal`;
  `MoveFileW` refuses.
- **Delete sidecars before the database, and refuse if one will not go.** A
  `-wal` carries no record of which database it belongs to.

**AN ADIF IMPORT IS ONE TRANSACTION -- ALL OR NOTHING (ruling 2).**
- `ImportFromADIF` collects a `TLogQsoAppends` and writes it with
  `LogStoreAppendQSOs` -> `TLogRepository.AppendBatch`. That is the F4 batch's
  begin/commit/rollback, with an insert where `WriteBatch` has an update.
  `TLogRowUpdates` and `TLogQsoAppends` share `TLogQsoList`.
- **The store stays enabled after a rolled-back import** -- unlike the
  rescore's batch. The usual cause is a record with no `CALL` (NOT NULL), which
  is a fact about the file. Only a ROLLBACK that fails (`InBatch` still True)
  disables it.
- `/IMPORT` exits 2 on failure.
- **Do not "restore" per-record commits.** 1,316 records: 1,268 -> 429 ms for
  parse and write.

**A RESCORE NEVER MINTS AN EXCHANGE ID (ruling 3, F6).** An id is an identity,
not scoring. A QSO without one is REPORTED by the Tools-menu verification check
`Every QSO has an exchange id` (`LogStoreCheckExchangeIds` ->
`QSOsWithoutExchangeId`) and never repaired. `test-rescore.sh` fails a log
whose id count changes across the FIRST rescore. `test-contest-factory.sh`
sets `APP_TR4W_ID` aside only for a fixture that holds no id at all
(`corpus-lib.sh`). The frozen baselines were NOT regenerated.

**`SysUtils.RenameFile` differs by platform:** `MoveFileW` on Windows refuses an
existing target; `rename(2)` on Unix replaces it. A directory at the target
fails on both, which is the portable way to make a publish rename fail in a test.

## The contest row and the contest byte (Q108 S2, 2026-10-16)

`contest.contest_type` holds the contest's ID (`uContestRegistry.ContestId`;
for a legacy contest its `ContestTypeSA` spelling, so no stored row changed).
`SetContest` / `LogContest` take a `TContestHandle`; the row is read back by
`uContestNames.ContestFromName` (`TF.GetContestFromString` is deleted). The
`.TRW` importer REFUSES a first record whose contest byte is above the legacy
range -- a message, and no log -- instead of stamping the log through an
out-of-range table index (`uTestLogImport.TestImportRefusesAContestNumberItDoesNotKnow`).

## Q61 (2026-10-17): the categories, the declaration, and `exchange_sent`

Detail and measurements: `docs/SQLITE_LOG_SCHEMA_PLAN.md` §12f.

- **CATEGORY-ASSISTED, -BAND, -MODE, -OPERATOR and -POWER have ONE home: the
  log's `config` row** -- each is a contest-scoped setting, so a stated value
  is a statement row (below). NOT the `contest` row's `category_*` columns,
  which nothing reads. `uCbrSum.CabrilloTagText` answers the setting when the
  summary window is closed; the window commits through `SetCFGCommandValue`
  and then `LogStoreRecordContestStatement`, which writes that ONE row and
  commits, so the change survives a crash. The single-row rule is
  `uLogContestStatements.CaptureContestStatement`; the full capture loops
  over it. **A single write does NOT set the statements-only mark** -- it
  vouches for one row, not the log.
- **The entry declaration (`contest` row: my_call, my_park, the nine
  CATEGORY tags, club, soapbox, op_name, address, city, state, postcode,
  country, email) is written ONCE**, on the open that made or migrated the
  log, after the contest stamp: `RecordEntryDeclaration(repo, isNewLog or
  aRebuilt, ...)`. It had been rewritten on every open, and for a new log it
  ran before the row existed. `SetEntryDeclaration` now returns whether a
  row was written. It is the entry AS MADE; nothing reads it back.
- **`exchange_sent` is INSERT-ONLY** -- out of `QSO_COLUMNS_UPDATABLE`, like
  `qso_set_id`. Every update (Edit QSO, the rescore batch, the network
  update, a re-import) used to NULL it. `SetNextSentExchange` is for the next
  INSERT, and **nothing writes an existing row's sent exchange** --
  ~~`TLogRepository.SetSentExchange`~~ is deleted with the branch below.
- **No schema change, no `user_version` bump**, fixtures byte-identical.
- **`test-contest-factory.sh` compares the Cabrillo HEADER** (the golden
  corpus does not). This said it reported 13 DIFF until NY4I re-froze;
  **measured 2026-10-17 it reports 13 identical**, so treat the frozen
  output as current. Do not re-freeze without him.

## AN APPEND ALWAYS INSERTS; A REWRITE ALWAYS WRITES (2026-10-17)

The suspected defect recorded here was REAL in the store and UNREACHED by the
program. Detail: `docs/SQLITE_LOG_SCHEMA_PLAN.md` §12g.

- **The defect.** `LogStoreAppendQSO`'s `if rebuilt` branch UPDATED the
  newest imported row with the QSO in hand and returned True, on B2's
  premise that `tAddQSOToLog` had written the `.TRW` first.
  `LogStoreUpdateNewestQSO` had a twin, `if rebuilt then Exit`. Since B5
  the `.TRW` holds nothing this build logs. Run against the old code, an
  append that migrated `cqww_ssb` left 101 rows, with QSO 101 `KP4PR`
  overwritten by `N0NEW`, and the rewrite was dropped.
- **Why no QSO was lost.** `aRebuilt` is True only on the `EnsureOpen`
  call that migrates. Startup's `LogStoreApplyContestConfig` is always that
  call: it runs after `SetUpFileNames` and before every path that writes
  (the GUI, `/IMPORT`, `/MATRIX`, `/RESCORE`), and it ignores the flag.
  `/IMPORTLOG` halts earlier and never appends. `LogStoreClose` runs only
  at shutdown and leaves the `.db` in place.
- **Deleted:** both branches, `TLogRepository.SetSentExchange` (their only
  caller), and `EnsureOpen`'s unread `aAppendPending`. `aRebuilt` stays:
  it marks a migrated log as new for the capture and the declaration.
- **`uLogStore` IS LINKABLE BY THE TEST PROGRAM now** (it links `MainUnit`).
  `uTestLogStore` is the first suite that calls the store itself rather than
  modelling it. It points `TR4W_LOG_FILENAME` at a scratch `.trw`, sets
  `tSilentExport` so a failure is a log line and not a modal, and calls
  `LogStoreClose` before and after each test. **`GDisabled` is never
  cleared**, so a store test that disables the store breaks every later one.

## SCHEMA 3: EVERY QSO RECORDS OUR STATION AS IT WAS (2026-10-18, stage 1)

NY4I: *"The QSO record should have all the MY_ values (such as MY_GRID)."*
Detail, rulings A to E, and measurements: `docs/SQLITE_LOG_SCHEMA_PLAN.md` §12h.

- **`LOG_SCHEMA_VERSION` WAS 3 HERE (11 since 2026-11-19; each later schema
  has its section below). ONCE A
  SCHEMA-3 BUILD HAS OPENED A LOG, NO EARLIER 5.0.x BUILD CAN OPEN IT**
  (accepted by NY4I). `Open` migrates;
  `OpenReadOnly` does not. The corpus is safe because every script works on a
  COPY of the tracked `log.db`. Never point a writing `Open` at a tracked
  fixture.
- **The migration adds each column of `uLogSchema.LOG_V3_QSO_COLUMNS` that
  `pragma_table_info` does not show, all before one commit.** It ASKS FIRST
  because `PragmaAsString` ends the transaction around itself; asking between
  two ALTERs would commit the first one alone. The CREATE TABLE ends with the
  same columns in the same order, and a test compares a migrated table with a
  new one.
- **`my_source` is the "captured?" marker, not the NULL in each value.**
  `BindText` stores `''` as NULL, so a value column cannot tell "never
  captured" from "unknown". NULL source means fall back to the session (ruling
  A); otherwise the source is `logged`, `assumed` (a multi-op peer's QSO
  stamped with THIS station's values, ruling D), `imported` or `edited`.
- **The my_* columns are INSERT-ONLY, like `exchange_sent`**: in `QSO_COLUMNS`
  (as `QSO_MY_COLUMNS`) and NOT in `QSO_COLUMNS_UPDATABLE`. Set them with
  `SetNextMyFacts`; it is cleared after every save. The only later write is
  `UpdateQSOMyFacts`, from Edit QSO.
- **`TQsoMyFacts` lives in the leaf `src/domain/uQsoMyFacts.pas`**, so the
  repository, the store, the editor and (at stage 3) the contest classes share
  it without sqldb.
- **The capture is `uLogStore.CaptureMyFactsNow`**, and it reads what scoring
  reads: `Settings.My.Resolved*` plus `uContestFactory.CurrentStation`.
  `my_state` is MY STATE (the place), **not** `SentMyState`.
- **A peer QSO is told apart by its computer id** (`QsoWasLoggedHere`): every
  local path stamps `Settings.Computer.Id` before logging.
- **`test-contest-factory.sh` reads `tr4w/target/settings/tr4w.json` (it
  passes no `--settings`).** In a fresh worktree that file is the program's
  defaults, and the check reports 0 identical and 13 differing for that reason
  alone. Measured 2026-10-18: with the station's file copied in, 13 identical.
- **THE IMPORT RULE (NY4I, 2026-10-18; it REPLACED stage 2's "absent tag =
  unknown"): a record naming no MY_ tag is STAMPED with this contest's values
  at import time** (`LogStoreCurrentMyFacts`, `my_source = 'stamped'`). A
  file that names some is reported, and the operator is asked when any differ:
  Yes keeps the file's (a tag it lacks is unknown), No stamps. Headless
  `/IMPORT` keeps the file's. The rule is `uQsoMyFacts.MyFactsForImport`.
  `uADIF.MyFactsFromADIF` reads the MY_* tags and STATION_CALLSIGN;
  `SentExchangeFromADIF` makes `exchange_sent` from STX_STRING, else NULL. The
  live sent-exchange callback is deleted (D3), and **a `TLogQsoAppends` row
  carries its own sent exchange and station**. Never give a batch the live
  station.
- **Export: `EmitADIFMyStationFields` writes the record's tags AFTER the
  contest's tail and skips any tag the tail already wrote** (POTA's park,
  MY_STATE, MY_DXCC). A never-captured row writes nothing new, so the corpus
  does not move. **The contest matrix DOES**: its rows are captured live, so
  every export gained the matrix station's MY_ tags. That is a re-freeze for
  NY4I, not a regression; strip the added tags and all 187 are identical.
- **Stage 3: a stored QSO is scored by its recorded grid.** The rescore reads
  each row's facts (`LogSourceNextWithRowId(rowId, qso, facts)`) and hands
  them to `RecomputeQSOScoring`; `LoadinLog` and live entry fill
  `TLoggedQSOView.MyFacts`. Detail: §12h.
- **Stage 4: an export writes what each QSO's record says it sent.** The sent
  exchange is built from the row's station (`uContestBase.MyStationExchangeOfQSO`);
  an imported row's `exchange_sent` (its file's STX_STRING) is written back
  verbatim; our call is the row's `my_call`, else `contest.my_call`
  (`TLogRepository.DeclaredCall`), else today's. A never-captured row is the
  session's. Detail: §12h.
- **Stage 5: only OUR QSO records a sent exchange.** A peer's QSO
  (`assumed`) stores none: the V1 packet does not carry the peer's template,
  only its serial (kept as `serial_sent`). A note or QTC record captures
  neither a station nor a sent exchange. A peer's edit keeps the row
  `assumed`. Detail: section 12h.
- **The lints scan nothing in a `.claude\worktrees\` checkout** (by design,
  `Get-ScanExclusions.ps1`), and twenty of them then FAIL as "no files
  scanned". Lint a copy of the change from a checkout outside that path.

## SCHEMA 4: AN EDITED FUNCTION-KEY MEMORY SURVIVES A RESTART (Q113, 2026-10-23)

D7 kept an Alt-P edit across a restart, through the `.cfg`'s `[Messages]`
section. The log's `message` table was written at close and never read, so
every edit was lost. Detail: `docs/SQLITE_LOG_SCHEMA_PLAN.md` §12i.

- **`message.edited` (`LOG_V4_MESSAGE_COLUMN`, `NOT NULL DEFAULT 0`).** It is
  migrated like the v3 columns: asked first, then `ALTER`, in one transaction.
  An old log restores nothing.
- **"Edited" IS LogCW's Q9 LATCH**, now covering both banks and the captions.
  It is not a second record of the same fact. The capture
  (`uLogStore.CaptureMessageMemories`) rewrites the table whole and flags the
  latched keys. The restore (`RestoreEditedMessageMemories`) applies only the
  flagged rows, and it applies them through the latch.
- **THE RESTORE RUNS LAST IN `LogStoreApplyContestConfig`**, after the contest
  is set up. The set-up forgets another contest's statements and writes its
  defaults, so an earlier restore would be lost. A new default writer for a
  memory must go through `SetContestDefault...`, or it overwrites an edit
  while the log still records it as one.
- **`KeyId(Char(anAnsiChar))` IS A CODE-PAGE CONVERSION, NOT A CAST.** `Char`
  is `WideChar` here, so a memory key from #128 up becomes another character
  and `KeyId` answers `''`. That covers nearly every Ctrl key and every Alt
  key, and the old capture skipped all of them. Use `MemoryKeyId`, which
  converts by ordinal.
- **Walk the memory modes as `CW`, `Phone`, never `CW to Phone`.** `Digital`
  sits between them; the accessors fold it into CW, and `MessageModeName`
  calls it PHONE.
- **AN ACCEPTED EDIT IS COMMITTED ON OK (R2, 2026-10-23)**, as D7 wrote its
  `.cfg`. Two routes record one: `uEditMessageForm.ApplyAcceptedMessageEdit`
  (it applies both fields and then records the key once) and
  `LogCW.MemoryProgram`'s line-input edits. **`MemoryProgram` has no caller,
  and had none in D7.** Both go through `LogStoreRecordContestStatement`.
  That routine is Q61's, EXTENDED, not copied: a memory name
  (`ParseMessageMemoryCommand`) writes the key's row through
  `CaptureMessageMemory`, the single-row rule the close capture loops over.
  **Never call it from a default writer or the open replay.** The close
  capture stays, as reconciliation.
- **ITS RESULT IS TRUE ONLY AFTER THE COMMIT** (Codex follow-up A). The result
  was set before `Commit`, so a failed commit answered "saved". Pinned by
  `Test_R2_ACommitThatFailsIsNotReportedSaved`. That test makes the COMMIT
  itself fail: a trigger inserts a row that breaks a `DEFERRABLE INITIALLY
  DEFERRED` foreign key, and SQLite checks a deferred key only at commit.
- **`GDisabled` CAN BE CLEARED NOW, BY A TEST ONLY.**
  `LogStoreForgetFailureForTests` clears it. `LogStoreFailureNotice` takes
  `Disable`'s modal, so a test can see the notice without hanging. The program
  touches neither. **The store-level fault-injection tests that were owed are
  writable now.** A test that disables the store must call the reset in its
  `finally`.
- **THE ORDERED REPLAY IS `LogStoreApplyContestConfigWith(aSetUpContest)`**
  (R3). The program hands in `CheckCommand('CONTEST')`. A test hands in a
  set-up that writes only the memories. **That is not `FoundContest`**, and
  the legacy `.cfg` + database ordering is still not covered.
- **A MIGRATION IS ONE COMMIT, AND A TEST COUNTS IT** (R5, follow-up B).
  `user_version` rides in the ALTERs' transaction.
  `TestAMigrationIsOneCommit` counts the commit frames in the `-wal`. A test
  that fails on an ALTER cannot tell one commit from two, because both fail
  before their first commit.
- **AN OLD-SCHEMA FIXTURE COMES FROM `DowngradeTestLog`** (R4,
  `uTestLatestContest`). It removes EVERY later addition. A downgrade that
  drops only the column under test leaves a hybrid file.
- **PowerShell is refused in an isolated worktree** (the worktree-isolation
  guard cannot prove it runs no git). Run `Build-Tests.ps1`'s FPC command
  directly instead: `-Mdelphi -Px86_64 -Twin64 -Sc -B`, the `Get-SearchPaths.ps1`
  Tests list, run from `tr4w/test/unit`. Then copy the runtime DLLs from
  `tr4w/redist/x86_64-win64`.

## THE MULTI-OP SERVER'S BOOKKEEPING: `sent_to_server`, `server_dirty` (Phase 1, C5, 2026-10-27)

The two columns were always in the schema; nothing used them since the `.TRW`
resend died. Now (design and threading: the `multi-op-network` agent):

- **Owed rows** = `TLogRepository.CollectUnsentToServer`: `(sent_to_server = 0 OR
  server_dirty = 1) AND NOT (session_id = 0 AND session_seq = 0)`, oldest first,
  through `OpenQsoReader(q, True)` like the cursor. The first term is
  `idx_qso_unsent`'s predicate verbatim, so SQLite uses the partial index
  (EXPLAIN QUERY PLAN: `SCAN qso USING INDEX idx_qso_unsent`, also for the two
  UPDATEs and both counts). **Both ids 0 means NOT OWED**: that is every import's
  pair (1,314 of winter_fd's 1,316 rows) and it cannot be addressed by its ids.
- **`MarkServerProgress(aSent, aEditsDone)` writes the two flags and nothing else**,
  each only where it is not already in the wanted state, addressed by the network
  key. It is a per-call statement (prepares each time, so it begins its own
  transaction) and is the **17th write path** in `TestEveryWriteWaitsForItsCommit`
  (whose fingerprint now includes the two flags). `LogStoreMarkServerProgress` runs
  a whole batch in ONE transaction and commits. A key that matches no row is not
  an error.
- **`HasQSOBySessionIds`** is a full scan of `qso` (there is NO index on
  `session_id, session_seq` -- `uNet.FindAndUpdateQSOInLog`'s old comment claimed
  one). Measured 1.7 ms per miss on 11,800 rows, so no index was added; a schema
  change for it would cost a migration, fixtures and a version bump.
- **The pair is not unique in old logs** (see `SaveQSO`'s note) and was not unique
  in new ones either: `ceQSOID2` was a 10-16 ms tick. `uNetResend.NextQsoSequence`
  makes it strictly increasing within a run, which is what lets the receiver treat
  a held pair as "the same QSO".
- **Do not store `sent_to_server = 1` for a packet that was only posted.** The flag
  changes when the writer thread has written the bytes (`SettleServerProgress`).
  `tUSQ`/`tUSQE` are a recount from the log (`CountUnsentToServer`) after each
  settle, not increments.

## QSOs THAT ARRIVE FROM THE MULTI-OP SERVER'S LOG ARE ADDED, NEVER REPLACED (Phase 1, C6, 2026-10-27)

A station that comes up mid-contest fetches the server's log and adds what this
log lacks (design, contest rule and threading: the `multi-op-network` agent and
`uNetCatchUp`'s header). What it asks of the store:

- **`TLogRepository.CollectSessionKeys` / `LogStoreCollectSessionKeys`**: every
  `(session_id, session_seq)` the log holds, `(0, 0)` left out, in ONE read. The
  merge plans against that set. Do not ask `HasQSOBySessionIds` per server record:
  it scans the table (1.7 ms a miss on 11,800 rows) on the main thread. A read
  that fails returns False and the merge does not run -- a plan made without the
  keys would add what is already there.
- **`TLogRepository.CollectForServerRestock` / `LogStoreCollectForServerRestock`
  (2026-10-28, the OTHER direction)**: every row, oldest first, EXCEPT those whose
  network key a caller-supplied `TQsoKeyTest` (method pointer) says the server already
  holds -- asked from the two key columns BEFORE `ReadRecord`, so a log the server
  already has costs a pass over two integers a row and not a parse of every record.
  Imports (0, 0) and owed rows are returned too: `uNetCatchUp.TPushPlan` judges and
  counts them. A READ: it adds no write path (the pin stays 17), it uses
  `NewReadQuery` and `OpenQsoReader`, and a failure returns False and the store
  stays enabled. The pushed rows' flags are NOT written: they are already
  `sent_to_server = 1`, and the send is untagged so nothing settles.
- **The write is `LogStoreAppendQSOs` -> `AppendBatch`, the ADIF import's path**:
  one transaction, all or none (a refused record rolls everything back and the
  store stays enabled -- the fault is the file's). It is NOT a new write path, so
  the `TestEveryWriteWaitsForItsCommit` pin stays at 17. Each row goes through
  `TLogQsoAppends.Add(rec, facts, '')` with `facts.Source := mfsAssumed` (this
  station's values, marked so) and NO sent exchange, exactly what a peer's QSO
  gets live. The record carries `ceContest := Contest`, `ceSendToServer = True`,
  `ceNeedSendToServerAE = False`, so `idx_qso_unsent` never sees the row.
- **The backup first is `LogStoreBackupBeforeCatchUp`**: a DATED, never-rotated
  `<log> before catch-up <UTC stamp>Z.db` in `uAppPaths.BackupDir`, the same
  verified snapshot as Clear Log's. It deliberately does NOT use the periodic slot
  (that would rotate the operator's last periodic backup into `.bak`, and would
  run even with BACKUP LOG FREQUENCY = 0). A failed backup means no write. One
  routine serves both purposes: `LogStoreBackupBefore(aInfix, ...)` over
  `LogStoreDatedBackupFileName`; Clear Log's name is unchanged byte for byte
  (`LogStoreClearBackupFileName` is that rule with `CLEAR_BACKUP_INFIX`).
  `uLogBackup.LogBackupBaseName` strips a trailing `before catch-up` stamp as it
  does `before clear`, so names never stack across the two. A test hands in its
  own folder and never calls `BackupDir`. Backups accumulate (no retention yet,
  issue #98).
- **Nothing here deletes or rewrites a row**, and nothing replaces the file. The
  old `ReplaceLogByServerLog` (copy a downloaded `.TRW` over the log) is deleted.
- **Appended at the END.** A caught-up QSO older than one logged here meanwhile is
  still a later row, and `tUpdateLog`'s rescore walks log order, so the dupe tie
  goes to the earlier ROW, not the earlier time. Same as a live peer QSO; recorded
  here because a catch-up makes it likelier.

## SCHEMA 5: `external_delivery`, AND ITS `last_sent` (WRL, 2026-10-31)

Durable external-logger delivery, one row per (logger, account, logbook,
contact); `contact` is the QSO's `guid`. Repo access is
`src/domain/uExternalDelivery.pas`; the worker (`uWRLWorker`) owns its OWN
connection.

- **`last_sent` (Unix UTC seconds, 0 = never) ARRIVED INSIDE SCHEMA 5, NOT AS
  A 6.** Schema 5 was unreleased, but development logs were already stamped 5,
  so `MigrateSchema` asks for the column BEFORE its "already current" exit
  (only when the table exists) and ALTERs it in. An added column after a
  release still bumps the version, as v3/v4 did. Pinned by
  `uTestWRLDelivery.TestLastSentMigration` (old DDL as a literal, user_version
  5, migrated columns equal a fresh log's, second open a no-op).
- **Written only by `Complete`, on doConfirmed and doFailed** (the server
  answered), with SQLite's `strftime('%s','now')` -- UTC by construction, so no
  caller passes a time. Inside the guarded UPDATE, so a stale completion
  cannot move it. `Enqueue` never touches it.
- **Edit QSO reads it through `LogStoreReadDeliveryAtIndex` ->
  `ExternalDeliveryStatusOfQso`, on a SHORT-LIVED `OpenReadOnly` connection,
  NOT the store's.** The store's connection can be holding a read transaction
  from an earlier read (sqldb keeps one open until a commit), and that snapshot
  would not show what the worker committed since. Same reason as
  `ExternalDeliveryCounts`. Several destinations for one contact: the one with
  the newest `last_sent` is shown.
- **`DowngradeTestLog` to below 5 drops `external_delivery`** (it did not, so a
  "schema-4" fixture still had the v5 table).

## SCHEMA 6: `rcvd_year`, THE RECEIVED YEAR (issue 298, stage 1, 2026-11-12)

The year first licensed (EUHFC, KVP) is a standard field. Detail:
`docs/SQLITE_LOG_SCHEMA_PLAN.md` section 12j.

- **`ContestExchange.RcvdYear: Word` (324) + `RcvdYearKnown: Boolean` (326)**,
  carved from `sReserved` (now `string[46]`). **Still 376 bytes, no offset
  before them moved** -- `.TRW`, `SERVERLOG.TRW` and the 384-byte packet keep
  their layout. Pinned in `uTestLogBinaryFile`'s offsets test.
- **NOT "0 = none".** 00 is a year (first licensed 2000), and a zero-filled
  record must read as no year: `RcvdYearKnown` False. Column NULL = no year.
- **`qso.rcvd_year`** last in the table (`LOG_V6_QSO_YEAR_COLUMN`), updatable.
  **Schema 5 shipped (5.0.37): a log this build opens is refused by 5.0.37.**
- **The migration asks the CONTEST** through the global
  `uLogDatabase.LogContestKeepsYearInZone` (the leaf cannot see the registry;
  `uLogStore`'s initialization assigns it to
  `uContestRegistry.ContestKeepsYearInZoneSlot`). **Unassigned, a log below 6
  is REFUSED by `Open`** -- never stamped 6 without its years. Carry =
  `UPDATE qso SET rcvd_year = rcvd_zone WHERE rcvd_zone IS NOT NULL`, in the
  ALTER's one commit.
- **`TLogBinaryReader.ReadNext` clears the year** (D7 never wrote it);
  `uLogImport` refills it from `Zone` for a year contest, same rule.
- **Stage 1 writes both** (`StoreLicenceYear`: slot + field) and reads the slot
  (`LicenceYearOf`). **`rcvd_zone` is authoritative in stage 1**: Edit QSO
  (`FLD_ZONE`) saves a new zone with the OLD year, and the ADIF `CQZ` arm writes
  only `Zone`. Stage 2 must re-carry (overwrite, v7) for year contests before
  any reader moves to `rcvd_year`.
- **SCHEMA 7 (stage 2, 2026-11-12) IS THAT RE-CARRY, and no shape change**
  (plan 12k): below 7, a year contest's log gets `UPDATE qso SET rcvd_year =
  rcvd_zone` -- every row, NO WHERE -- in the migration's one commit; the judge
  is asked of every log below 7 (unassigned: refused). The judge is now the
  class's stated `ReceivedYearKind`. From 7 the READERS read `rcvd_year`
  (`TryLicenceYearOf`, the remembered exchange), Edit QSO and the ADIF import
  write it through `StoreLicenceYear`, and the dual write stays until stage 4
  moves the multiplier sheet. `DowngradeTestLog(..., 6)` only re-stamps.
- **STAGE 3 (2026-11-12, plan 12l, no schema change): display and export read
  `rcvd_year`**, and `my_cq_zone` stops recording the year:
  `LogStoreCurrentMyFacts` asks `uContestFactory.SessionMyCQZone(
  ContestIdentity(Contest))` -- MY CALL's CTY zone where the contest's MY ZONE
  is no station zone. **Rows captured before keep their value; nothing
  rewrites a captured row.** What stage 4 still reads from `rcvd_zone`: the
  multiplier sheet, `LOGEDIT.SetLoggedZone`, PostUnit's first-call-per-zone
  report.

## SCHEMA 8: `year_sent`, THE LICENCE YEAR EACH QSO SENT (issue 300, 2026-11-13)

NY4I: *"a QSO record depends on nothing but its own row."* Detail: plan
section 12m-bis.

- **`exchange_sent` IS NOT A RECORD OF THE YEAR SENT. Measured** (headless
  `/MATRIX`, EUHFC and KVP, `MY LICENSE YEAR=64`): `599 64` on every logged row,
  SSB included -- the CW template, rebuilt once. Never read the year from it.
- **`qso.year_sent`**, last column, the number AS SENT (64 / 1964 / a count);
  NULL = none, 0 = 00. One rule: `uContestBase.SentLicenseYearValue`
  (`SentLicenseYearText` formats it). The last of `QSO_MY_COLUMNS`, so
  insert-only plus Edit QSO; `TQsoMyFacts.YearSent` / `YearSentKnown`.
  **Read whatever `my_source` says** (`ReadMyFacts` reads it before the
  never-captured exit) -- a backfilled row's year is its own.
- **Where it comes from: `uQsoMyFacts.SentYearSourceOf`.** Ours when logged
  here; **NEVER OURS ON A PEER'S ROW** (`assumed`, live or caught up --
  `CaptureMyFactsNow` and `uGetServerLog` take the year THE PEER sent from the
  record's `YearSent` / `YearSentKnown`, which the protocol-4 packet carries
  (2026-11-13), and none when it carries none); an import's STX_STRING, else the contest's
  (`ApplyImportedSentYear`; `MyFactsForImport` keeps the record's year
  whichever station the operator picks).
- **Readers:** `MyStationExchangeOfQSO(..., aYearKind)` (default `rykNone`, so
  a grid-only caller is unchanged; PostUnit passes the contest's kind) puts
  the row's year in the zone slot; logged/edited/imported-with-none sends
  none; never-captured-with-none AND `assumed`-with-none are the session's
  (a peer's column stays NULL; the export sends what it did before schema 8). A year contest's
  `CanonicalSentExchange` is RST + `ctx.SentYearText`, not the template.
- **Migration: ALTER + the session_state mark `LOG_YEAR_SENT_BACKFILL_KEY`
  (only when the log has rows), one commit. The BACKFILL is the store's**,
  after set-up (`LogStoreApplyContestConfigWith`), through
  `TLogRepository.BackfillYearSent`: the rows whose export was rebuilt from
  the session (NULL/`logged`/`edited`, or `imported`/`stamped` with no
  `exchange_sent`), NULL-only, mark deleted in the same commit. Never
  `assumed`. Read-only leaves the mark. `DowngradeTestLog(..., 7)` drops the
  column and the mark.
- **Correction:** Edit QSO's "Year sent" box (a year alone does NOT mark the
  station edited: `MyFactsYearSentDiffers`); `LogStoreCountQSOsSentYear` /
  `LogStoreCorrectSentYear` for Preferences' default-No question (this
  station's rows only), ruled by `uLicenseYearChange.LicenseYearCorrectionOf`.
  `uPrefsForm.SaveStationPanel` asks it (issue 300 step 7) after the
  two-answer question, gated by `uLicenseYearChange.LicenseYearCorrectionAsks`;
  "This contest and its existing QSOs" and `lysContestAndQSOs` are retired.
- **THE PEER'S YEAR IS ON THE WIRE (2026-11-13, protocol 4)**: a pair carved
  from `ContestExchange.sReserved` (`YearSentKnown` at 327, `YearSent` at 328).
  No schema change. `ReadRecord` now fills the pair from `year_sent` (every
  stored row read back for a resend, restock or edit carries it);
  `BindRecord` does not write it (the my_* tier does, once, at insert). See
  multi-op-network.md.
- Schema 7 shipped in 5.0.40: a log this build opens is refused by it.

## SCHEMA 9: EVERY STATION FACT IS ON THE QSO (2026-11-17)

NY4I: *"ALL MY_ VALUES GET WRITTEN TO THE QSO RECORD."* Six TEXT columns after
`year_sent` (`LOG_V9_QSO_COLUMNS`: `my_name`, `my_fd_class`, `my_check`,
`my_prec`, `my_postal_code`, `my_foc_number`; `TQsoMyFacts.Name` ..
`FocNumber`), in `QSO_MY_COLUMNS`, following `my_source` like the v3 values.
`MyStationExchangeOfQSO` overlays them, so a Sweepstakes precedence changed
after logging no longer rewrites earlier sent lines (it did: export read
`Settings.My.Resolved*`). **`uStationFactRecord.STATION_FACT_IN_RECORD` is
`array[TStationFact]`: a new station fact does not compile until it names its
column or a reason it is not per-QSO**, and `LogStoreCurrentMyFacts` captures
by it. `my_check` is NOT `year_sent` (Sweepstakes stating a
`ReceivedYearKind` would trip the v6/v7 carry, the v8 backfill and the
Preferences correction). The migration marks a log whose rows captured a
station (`LOG_STATION_FACTS_BACKFILL_KEY`); the store's
`BackfillStationFacts` (after set-up, beside `BackfillYearSent`) gives those
rows' NULLs the contest's current values -- what they exported -- once.
Import reads `MY_NAME` (alone it names no station) and `MY_POSTAL_CODE`; the
four with no ADIF tag take the contest's even when the file's station is
kept. ADIF export does NOT yet write MY_NAME/MY_POSTAL_CODE (matrix re-freeze).
No packet change: a peer's row is stamped `assumed`. Schema 8
shipped: a log this build opens is refused by earlier builds. Detail: plan
section 12n; tests `uTestLogStationFacts`.

**Phase 2 (2026-11-17, plan 12n "phase 2"):** Edit QSO shows and edits the
six (enabled per contest; a greyed box is never read back). An edit of a
NEVER-CAPTURED row freezes the untouched values at the session's
(`uQsoMyFacts.MyFactsAfterEdit`), not at the blanks shown. Preferences'
correction of logged QSOs for any as-typed value is
`TLogRepository.CountQSOsSentStationValue` / `CorrectSentStationValue`: rows
`record_kind = 'QSO'` and `my_source IN ('logged','edited')` (never a peer's,
an imported/stamped or a never-captured row), exact old text ('' = NULL), the
column name checked against `QSO_MY_COLUMNS` (never operator text), and each
corrected row marked `edited`. `LogStoreCorrectSentStation` does the year and
every value in ONE transaction. Tests `uTestStationFactChange`.

## SCHEMA 10: THE CONTEST'S RULE IS STORED ON THE QSO (2026-11-19)

NY4I: an X-QSO decided by the contest's band/mode/host rule is STORED when
the QSO is logged, and the exports simply read it -- *"Otherwise we have
business rules being derived at cabrillo generation."* Definition and the
column classes: `docs/LOG_SCHEMA.md`.

- **`qso.is_off_contest`** (`LOG_V10_QSO_OFF_CONTEST_COLUMN`, `INTEGER NOT
  NULL DEFAULT 0`, last column), `ContestExchange.ceOffContest` (offset 330,
  carved from `sReserved`, now `string[42]` at 331; still 376 bytes, nothing
  before 330 moved). DERIVED-AND-STORED like `qso_points`; UPDATABLE (in
  `QSO_COLUMNS_UPDATABLE`), so any other update writes back what it read.
- **NOT `is_xqso`.** That is the operator's statement; the stamp never writes
  it, so a rule change can release a QSO at the next rescore.
- **ONE writer: `uContestRegistry.StampOffContest`** =
  `QSOIsOffContest(LoggedQSOContest(ceContest), qso)`. Called ONLY where the
  stored value is set: `LogContact` (before the multipliers, the packet and
  the UDP/logger/HamScore post), `LogStoreAppendQSO` and `LogStoreAppendQSOs`
  (`TLogQsoList.StampEach` -- every insert, import and catch-up included),
  `LogStoreUpdateQSOBySessionIds` (a peer's edit), `tUpdateLog`'s rescore
  (every QSO row, deleted ones too, after one `ActiveContest` refresh), Edit
  QSO's save (every save), and `uGetServerLog.TryGetServerLogRow`.
- **ONE reader predicate: `uContestRegistry.StoredQSOIsXQSO`** (`is_xqso OR
  is_off_contest`) and `StoredQSOCountsTowardTotals` -- Cabrillo (PostUnit,
  uCabrillo), ADIF, the grids, Search, Edit QSO's box, HamScore/UDP
  `IsClaimedQso`, the loader, its LOGDUPE replay, the bonus view and the
  summary sheet. `LoggedQSOIsXQSO` is now THE JUDGE (works the rule out now),
  for setting points and tests only. `Lint-XQSOReads` fences both: reads of
  `ceXQSO`/`ceOffContest` outside owners, and calls of the judge routines
  outside the setting-point units.
- **THE WIRE BYTE IS NEVER TRUSTED**: every receive path stamps with THIS
  station's contest, so an older station (byte 0) needs no protocol bump.
- **Migration**: ALTER + the mark `LOG_OFF_CONTEST_BACKFILL_KEY` when the log
  holds a QSO, one commit. **The store stamps every QSO row once**
  (`TLogRepository.BackfillOffContest(@StampOffContest)`, after set-up, in
  `LogStoreApplyContestConfigWith` beside the schema-8/9 fills): read with the
  cursor closed before writing, 1 for refused rows, 0 for the rest, mark
  deleted, one commit. **A `.TRW` import writes the same mark** (no contest
  is set up while it converts). It is the 21st write path in
  `TestEveryWriteWaitsForItsCommit` (fingerprint has `is_off_contest`).
- **Known residue**: `TContestBase.CountsTowardBonus` still judges rows in
  the bonus view (they agree with the stored value except between a rule
  change and the next rescore). Tests: `uTestLogOffContest`,
  `uTestAutomaticXQSO` (the rule flipped under a logged QSO), `uTestLogStore`
  (`TestAnAppendStoresTheContestsRule`), `uTestLogBinaryFile` (offset 330).

## SCHEMA 11: SIXTEEN UNUSED COLUMNS REMOVED BY A TABLE REBUILD (issue 94, 2026-11-19)

NY4I: `my_*` is OUR station, `rcvd_*` the worked one, *"as long as that is
consistent, I do not see why we would keep those fields"*. Plan section 12o;
`docs/LOG_SCHEMA.md` section 1 and 4.

- **Removed** (`uLogSchema.LOG_V11_DROPPED_QSO_COLUMNS`, name + old
  declaration): `snr_sent`, `snr_received`, `rcvd_state`, `rcvd_county`,
  `rcvd_section`, `rcvd_grid`, `rcvd_continent`, `rcvd_postal_code`,
  `rcvd_society`, `rcvd_department`, `rcvd_rda`, `rcvd_park`, `rcvd_summit`,
  `rcvd_iota`, `rcvd_coords`, `cty_itu_zone`. Never written or read by any
  build (re-verified: src, tools, scripts, Python, `git log -S`); NULL in every
  corpus log. A received QTH of any kind is `rcvd_qth`. **Kept: `rcvd_year`.**
- **A REMOVAL IS A REBUILD, NEVER `ALTER TABLE DROP COLUMN`.** DROP COLUMN
  needs 3.35 and the Linux tarball and macOS use the system library (published
  package versions, not measured: Ubuntu 20.04 has 3.31, Debian 11 3.34;
  measured: linux-ci 3.45.1, which the AppImage
  bundles; mac-ci 3.54.0); it fails on 3.42+ distro builds around comment
  lines (#141); and it cuts the stored CREATE text. `TLogDatabase.RebuildQsoTable`:
  rename the old table to `qso_before_v11` FIRST (a table renamed INTO `qso`
  gets its stored text rewritten), create `LOG_QSO_TABLE`, copy kept columns
  BY NAME, restore the `sqlite_sequence` mark (the copy leaves it at
  `max(id)`; Clear Log makes it lower than the old mark), drop the old table,
  recreate `LOG_QSO_INDEXES`. Last in `MigrateSchema`, same transaction, one
  commit. A migrated `qso` is a new log's text for text.
- **`LOG_QSO_TABLE` and `LOG_QSO_INDEX_*` are named constants** that
  `LOG_SCHEMA_STATEMENTS` lists and the rebuild runs: one text, two callers.
  A test pins that `LOG_QSO_INDEXES` is exactly the schema's qso indexes.
- **Refused before any change**: a trigger on `qso`, any view, a foreign key
  to `qso` (the rebuild would destroy or misdirect it), and a column this
  program never made (the copy names it and fails; the list is NOT
  intersected with the new table, so nothing is lost in silence).
- **NEVER READ A LIST THROUGH `group_concat` + `PragmaAsString`.** MEASURED:
  sqlite3conn makes an expression column (no declared type) an ftString of
  255 and CUTS a longer value silently. The first rebuild read qso's column
  list that way, dropped every column past character 255, and the copy reset
  `is_off_contest` to 0; the fixture test caught it. Use
  `TLogDatabase.PragmaRowsAsText` (one row per value). The same trap applies
  to any test that compares a `group_concat` of long text.
- ~~No migration takes a backup first~~ -- **RULED 2026-11-19: every
  migration does now**; see "AN OLDER LOG IS BACKED UP BEFORE IT IS UPGRADED"
  below. (Issue 94's comment claimed earlier migrations did; none had.)
- **Tests: `uTestLogDroppedColumns`**, over a REAL schema-10 file
  (`test/unit/fixtures/logdb/florida_qp_schema10.db`: the corpus florida_qp
  log migrated 2 -> 10 by the schema-10 build's headless `/EXPORT`).
  `DowngradeTestLog` below 11 ADDS the sixteen back, at the END of the table,
  after its drops, so every older migration test runs through the rebuild.

## SCHEMA 12: WHERE A ROVER SENT THE QSO FROM (issues 133 and 87, 2026-11-19)

NY4I: one log for the whole event, each QSO stamped with the place it was
sent from; `my_county` is ADIF MY_CNTY (a REAL county) and `my_state` stays
the primary subdivision -- a district that is no county goes in the sent
exchange only.

- **`qso.my_rover_qth`** (`LOG_V12_QSO_ROVER_QTH_COLUMN`, TEXT, last column),
  **on the record**: `ContestExchange.ceRoverQTH` (`string[10]`, offset 331,
  carved from `sReserved`, now `string[31]` at 342). UPDATABLE through
  `BindRecord`/`ReadRecord` like any record field -- NOT a `QSO_MY_COLUMNS`
  member, because the loader, the rescore and the dupe key must read it from
  the record (`ContestExchange` carries no `my_*`). NULL = not roving.
- **Migration**: asked before any change; ALTER only on a table the v11
  rebuild does not rebuild (from below 11 the new `LOG_QSO_TABLE` already ends
  with it). No backfill, no mark. `DowngradeTestLog` below 12 drops it first.
- **Written by `LOGSUBS2.LogContact`** for a QSO logged HERE while roving (the
  first place; a county-line leg arrives with its own). A peer's packet
  carries ITS place, which is that QSO's fact, so a receiver keeps it; the
  `.TRW` reader clears it.
- **`my_county`** of a row with a place: `uLogStore.CaptureMyFactsNow` asks
  `PostUnit.RoverPlaceADIFCounty` -- the worked station's CNTY rule
  (`ADIFCountyOfQSO`, lifted out of the export unchanged), KOH -> `HI,Hawaii`.
- **The export** sends it in place of MY STATE:
  `PostUnit.CurrentMyStationExchange(contest, facts, rec.ceRoverQTH)` ->
  `uContestBase.MyStationExchangeWithRoverPlace`. A row with none exports
  byte-for-byte as before, so no corpus fixture can move.
- **`TLogRepository.HasRoverQSO`** (`uLogSource.LogSourceHasRoverQSO`; rover
  step F, 2026-11-19): one `EXISTS` over non-deleted rows with a
  `my_rover_qth`. The Cabrillo export asks it before it walks the log a
  second time to split by activation -- a log that never roved costs one
  query (file-formats.md).

## SCHEMA 13: THE UNIT A QSO WAS SENT FROM, AND THE ROVER'S PLACES (2026-11-20)

NY4I's rulings of 2026-11-20 on issues 133 and 87: an in-state party QSO
records the HOST state in `my_state` ("since I said I was in state"), and the
call is ASSEMBLED from its parts, never stripped (ruling 6).

- **`qso.my_sent_unit`, `qso.my_rover_places`** (`LOG_V13_QSO_COLUMNS`, TEXT,
  last two columns), **`QSO_MY_COLUMNS` members** (`TQsoMyFacts.SentUnit` /
  `.RoverPlaces`): written at insert and by an edit of our station, never by
  an ordinary update. NULL means "as before" on every row.
- **Capture**: `uLogStore.LogStoreCurrentMyFacts` asks
  `PostUnit.ApplyPartyUnitToMyFacts(SentMyState)` when
  `FCONTEST.StationInHostState`; `CaptureMyFactsNow` asks it of a rover's
  `ceRoverQTH` (overriding) and records `RoverState.Joined('/')` in
  `my_rover_places`. `my_call` is the call SETTING as set (no places).
- **The export**: `MyStationExchangeOfQSO` sends `SentUnit` in the state
  slot when the row has one, else `my_state` (every older row).
  `uLogSource.CabrilloCallFor` = `AssembledCall(ExportCallFor, places)` for
  every Cabrillo writer (QSO line, per-activation header, HamScore line);
  ADIF's STATION_CALLSIGN stays `my_call`.
- **A schema-12 rover row** holds `my_call` = NY4I/KIN/QUE and no places:
  the base call is not derivable without stripping, so it exports exactly as
  it did (Cabrillo and ADIF both sign NY4I/KIN/QUE).
- **Known gap**: the Station-page MY STATE correction (`uStationFactRecord`,
  `sfState` -> `my_state`, matched AS TYPED) no longer finds an in-state
  party row (its `my_state` is the host state now; the typed code is
  `my_sent_unit`). Not built; reported for a ruling.
- **Migration**: asked before any change; ALTER only on a table the v11
  rebuild does not rebuild. `DowngradeTestLog` below 13 drops both first.
  **The backup-before-migration rule covers it with no extra code**:
  `TLogDatabase.BackUpAnOlderLog` backs up any log whose version is below
  `LOG_SCHEMA_VERSION`, so a schema-12 log is copied before the ALTER.
- **`my_county` IS THE COUNTY FILE'S NAME, never the session list's
  (2026-11-20)**: `PostUnit.ADIFCountyOfQSO` (CNTY and `my_county` alike) asks
  `TContestBase.CountyFileCountyName` -- the party's own `<base>_cty.dom`,
  read once per object -- because an IN-STATE session's list (`mo.DomList`)
  files every county under the host state (`Pin > Fl`) and named none, so an
  in-state Florida, Georgia, California ... station stored an EMPTY
  `my_county`. `uTestRoverState.Test_TheCountyFileNamesWhatTheListNamed`
  proves the out-of-state answer did not move, key for key.
- **Every reader asks the same row** (`uTestCabrilloActivation.
  Test_ANewYorkRoverOnACountyLineIsFourLinesAndOneRecord`, the real exports):
  NY4I's KIN/QUE x CAT/CAY entry is four Cabrillo lines signed
  VE3FRV/W2/KIN/QUE, ONE ADIF record (STATION_CALLSIGN the setting, MY_STATE
  NY, MY_CNTY/CNTY the first counties, both USACA pairs), and each row's
  station as Edit QSO's panel reads it (State NY, County its own county).
- **Not the row's yet**: HamScore's one-QSO line rebuilds the SENT exchange
  from today's CQ template (`uExchangeBuilder.BuildSentExchangeTextOf`), not
  from `my_sent_unit`; only its call is the row's (`CabrilloCallFor`).

## AN OLDER LOG IS BACKED UP BEFORE IT IS UPGRADED (NY4I, 2026-11-19)

Every migration, not one schema's. Definition and the case-by-case list:
`docs/LOG_SCHEMA.md` section 1.

- **The seam is `TLogDatabase.BeforeMigration`**, a per-instance function
  property (`TLogBeforeMigration`), nil by default. `Open` asks it FIRST,
  before its write connection exists: `BackUpAnOlderLog` peeks the file
  (`OpenToPeek` -- immutable with no sidecar, so a refusal leaves nothing
  beside a WAL-mode log; `OpenReadOnly` left a `-wal`, measured on the
  schema-10 fixture), reads `user_version`, and below `LOG_SCHEMA_VERSION`
  calls the hook. False raises `ELogDatabaseError` ("NOT upgraded and has not
  been changed") and the file is byte-identical (MD5-pinned). The peek runs
  `VerifyIdentity`, so a newer or foreign file is refused before any copy.
- **NOT a global like `LogContestKeepsYearInZone`, on purpose**: the store
  links into the test program, and a global hook would send every
  `DowngradeTestLog` -> `db.Open` test's backup into the real settings
  folder. Only the store assigns it (`OpenExistingLog`, before the
  busy-retry loop); a test or a tool that opens a file it made takes none.
- **The store's answer** is `BackUpTheLogBeforeUpgrading` ->
  `uLogBackup.BackUpLogBeforeUpgrade`: `TLogBackup.Run` (stage `.new`,
  integrity-check on its own read-only connection, rename) with a by-path
  source, `TLogFileBackup` -- **NEVER `TLogStoreBackup`**, whose
  `SourceIsReady` calls `LogStoreEnsureOpen` and would re-enter the open in
  progress. Name: `<base> before schema <from> to <to>.db`
  (`LogSchemaBackupFileName`); **a taken name gets a number**
  (`uLogNaming.FirstFreeLogFileName`), because `Run` would displace an
  existing destination to `.bak` and replace an older `.bak`.
  `LogBackupBaseName` strips that suffix too (exact shape, digits).
- **The folder is `uLogStore.LogStoreUpgradeBackupFolder`**, a function
  variable that `uProgramMain` assigns `@BackupDir` at the top of `RunTR4W`.
  Asked only for an older log, so a current one never creates the folder.
  **NIL FAILS CLOSED** (refused, the reason names the variable), so a store
  test that opens a downgraded log must assign a scratch-folder function --
  **never `BackupDir`**. A folder that does not exist fails the backup.
- **Headless runs back up too** (`/EXPORT` of an older log migrates it). All
  13 corpus logs are schema 2, so every corpus/rescore/round-trip/factory run
  writes one backup per set into `tr4w/test/corpus/settings/backup/`
  (`--settings` moves `BackupDir`); `corpus-lib.sh`'s
  `corpus_clear_upgrade_backups` empties it at each run's start and
  `.gitignore` lists it. Do NOT skip the backup to tidy a run. **A REFUSED
  headless upgrade EXITS 0** (measured: `/EXPORT`, backup folder a file --
  Error lines, log byte-identical, no artifact written). That is every
  failed store open under `/EXPORT`, not this feature's; open for the
  startup owner.
- **The failure pin is a ROLLBACK-JOURNAL copy** (`journal_mode = DELETE`
  first): the fixture is WAL, on which `ApplyPragmas` changes no header
  byte, so an MD5 over it could not see the order. Mutation-tested: the
  backup moved after `OpenConnection` fails the MD5 and the "not open" pin.
- **Not covered**: `external_delivery.last_sent`, the one migration that can
  reach a log already AT the current schema (development logs). A migration
  that fails after its backup backs up again on the next try (numbered name),
  and so does a busy retry in `OpenExistingLog`. A backup that fails AFTER
  its snapshot started may leave the reader's empty `-wal`/`-shm` beside a
  WAL-mode log (SQLite's own; no content). Tests: `uTestLogMigrationBackup`.

## A LOCKED LOG: THE STALE SNAPSHOT, THE BUSY WAIT, THE DIALOG, THE WATCHDOG (2026-10-31)

NY4I: the log belongs to TR4W; the database must never get in the way of
logging; delivery is the junior partner. tr4w.log 2026-10-31: an unhandled
`database is locked` on the main thread at startup (10:39:27), and `the
configuration could not be recorded on close` (10:43:25) with the worker
ALREADY STOPPED.

- **THE CAUSE WAS NOT A MISSING TIMEOUT. IT WAS `SQLITE_BUSY_SNAPSHOT` (517).**
  Measured (Python's sqlite3 and `uTestLogLocking`): a connection whose read
  transaction began before another connection committed CANNOT upgrade it to a
  write; SQLite fails it AT ONCE, a 2 s busy timeout or not. sqldb begins a
  transaction when a statement PREPARES and never ends it, so after a per-call
  read (the startup walk, a count, a search) the main connection holds an old
  snapshot. A KEPT statement (the grid's `FSelectRange`) runs outside one -- a
  pin that reads through the grid proves nothing (it was tried, and passed on
  the broken code).
- **`uLogStore.BeginMainWrite` is the cure: `GDatabase.EndTransaction` (now
  public) before every main-thread write** -- each write entry, the close
  capture, and `SaveRestartFile` through `LogStoreReadyToWrite`. Not in a batch
  and not with the sequential cursor open (`TLogRepository.SequentialReadOpen`,
  new). It COMMITS what is pending, as `BeginBatchUpdate` already did.
- **A BUSY WRITE IS RETRIED AND THEN REFUSED, NEVER A DISABLED STORE.** The
  append is `LogStoreAppendQSO` -> `AppendQSOOnce` x `LOG_WRITE_ATTEMPTS` (3),
  each rolled back (`RollBackAfterBusy`, which also invalidates the record
  count). `Disable` has a busy branch, FOR A WRITE TO AN OPEN LOG ONLY
  (`GRepository` assigned): roll back, log every time, a notice
  (`SLogBusyNotSaved`) at most once a minute, the store STAYS OPEN. A failed
  OPEN still stands the store down -- left "not disabled", every later store
  call re-opened, probe and wait included (pinned headless). Before this, one delivery commit
  between a read and a QSO disabled the store for the session. In WAL a busy
  failure comes before the transaction's first write, so a rollback loses
  nothing; that is not true in rollback-journal mode (a cache spill), where
  only the busy wait applies.
- **ONE busy classifier: `uLogDatabase.SQLiteIsBusy(E)` (codes 5 and 6, extended
  included), by CODE.** `TLogConnection.ExecutePragma` now raises
  `ESQLDatabaseError` with `sqlite3_extended_errcode` (FPC's own `sqlite3dyn`,
  no new binding), and `ELogDatabaseError.SQLiteCode` carries it through the
  re-wraps. uWRLWorker's private copy is deleted.
- **Every connection gets `busy_timeout` FIRST in `ApplyPragmas`**:
  `LOG_BUSY_TIMEOUT_MS` = 2000 for the main one, `TLogDatabase.BusyTimeoutMs`
  to change it before Open (the worker 1000, tests 20; the store's test seam is
  `LogStoreBusyTimeoutMs`). **The `PRAGMA busy_timeout = 250` that
  `TWRLExternalLogger.AfterLogCommit` set on the MAIN connection is deleted** --
  it was its only wait, and it lowered it.
- **The worker starts after the log is loaded** (`uProgramMain`, beside
  `BackupCopyStart`, after every headless Halt); it used to start from
  `StartExternalLoggerFromSettings`, before `CreateMainWindow` loaded the log.
- **A LOCKED LOG AT OPEN ASKS** (`OpenExistingLog`): `ProbeLogWriteLock`
  (a raw `TLogConnection`, `BEGIN IMMEDIATE` + `ROLLBACK`, no create flag),
  then `QuestionDlg` Retry / Open read-only / Quit, compared by modal result.
  A busy failure of the `Open` itself (a lock taken after the probe) is asked
  about the same way.
  Test seam `LogStoreLockedQuestion`; headless never asks. Quit is `Halt(1)`.
  **NEVER offer or do a delete of `-wal`/`-shm`.** The holding process is not
  named: that needs the Restart Manager, a new DLL binding.
- **READ-ONLY (`GReadOnly`, `LogStoreIsReadOnly`)**: `OpenReadOnly`, no
  `CheckWritable`, no worker, no close capture, no contest-row correction;
  every write entry calls `RefuseReadOnly` (one notice per session,
  `SLogReadOnlyRefused`; the append returns False). An older-schema log cannot
  be opened read-only (its upgrade is a write) and says so.
- **THE WATCHDOG (`uLogConnectionWatch`)**: a SECONDARY connection's
  `TLogConnection.Watch` is told of BEGIN/COMMIT/ROLLBACK and its handle by
  overrides of sqldb's own hooks (`StartDBTransaction`, `Commit`, `RollBack`,
  `DoInternalConnect/Disconnect` -- AnsiString parameters, or they do not
  override). `RunLogWatchdog` (1 s TTimer in `uWRLExternalLogger`): past
  `LOG_WATCH_THRESHOLD_MS` (3 s) ask the owner to roll back; + grace (2 s)
  `sqlite3_interrupt`; + another grace, `OnGiveUp` (the owner stops the worker,
  frees it when `Finished`, starts a new one). **Measured: interrupt ends a
  running statement, NOT a busy wait and NOT an idle transaction**, hence the
  three steps. The main connection is NOT watched (it always holds a read
  transaction). Never close another thread's connection from the main thread.
- **Tools > Run Verification Checks: "Contest log is not locked"**
  (`LogStoreCheckLockState`): overdue transactions by name, the probe, the
  sidecars (looked at BEFORE the probe; expected while open, never removed),
  the intervention count.
- **Not done**: `CheckWritable` loses the busy code into its report, so a lock
  taken between the probe and that write still disables the store as
  "not writable". The worker does not restart itself after a busy failure at
  ITS open (it stops; the next QSO's `AfterLogCommit` only Wakes it).

## A FULL DISK LEAVES THE LOG READ-ONLY, NOT DISABLED (2026-11-18)

NY4I filled the D: drive under a running TR4W: the QSO got the "not being
saved" modal, then `Disable` freed the database, and a double click on a QSO
the grid still showed did NOTHING (`EditableLogWindowDblClick`'s bare
`if not LogSourceOpen then Exit`). Ruling: a write the disk will not take
must not make the log unreadable.

- **THE MEASURED FAILURE CARRIED NO CODE.** tr4w.log: `EDatabaseError --
  database or disk is full` -- plain `EDatabaseError`, so it came from
  `execsql` (COMMIT), not a statement step (`ESQLDatabaseError`). BEGIN,
  COMMIT and ROLLBACK go through `execsql`, which raises with the message
  only. **`TLogConnection.StartDBTransaction` / `Commit` / `RollBack` now
  re-raise it as `ESQLDatabaseError` with `sqlite3_extended_errcode`**
  (`CodedFailure`, shared with `ExecutePragma`). Side effect: a busy COMMIT
  is now `SQLiteIsBusy` and takes the busy branch instead of disabling.
  Pinned: `uTestLogLocking.TestAFailedCommitCarriesItsCode`.
- **One classifier, by code: `uLogDatabase.SQLiteWriteFailure(E)`** --
  `lwfDiskFull` for SQLITE_FULL; `lwfWriteError` for SQLITE_READONLY and
  SQLITE_IOERR except IOERR_READ, IOERR_SHORT_READ and IOERR_CORRUPTFS;
  `lwfNone` for everything else (CORRUPT, NOTADB, busy, constraints, code 0).
  Pinned: `TestTheWriteFailureClassifier`.
- **`Disable`'s second branch** (after the busy one, same conditions: a write
  to an OPEN log, not a batch whose rollback failed): roll back, and if no
  transaction is left, `MakeReadOnlyAfterAFailedWrite` -- `GReadOnly`,
  `GReadOnlyCause` (`lrcDiskFull` / `lrcWriteError`; `lrcLocked` is the
  startup choice), `GReadOnlyRefusalShown := True` so the locked-log modal
  never shows, ONE modal `SLogNotSavedReadOnly` (reason, remedy, file). The
  database and repository stay; every write entry refuses through
  `RefuseReadOnly`; every read works. A rollback that fails falls through and
  stands the store down.
- **A failed OPEN still stands down, whatever the code**: `EnsureOpen`'s
  handler frees `GRepository` before `Disable`, so a failure after the
  repository exists (the stamp or declaration commit) is not mistaken for a
  write to an open log. That also changed a busy failure there from "store
  left usable behind an open that answered False" to standing down.
  **Corruption and a failed integrity or writability check are unchanged**:
  disabled. Pinned: `uTestLogStore.TestADamagedLogStillStandsTheStoreDown`.
- **Later refusals are the status line, never a modal.** One text,
  `LogStoreNotSavedText`: `SLogReadOnlyNotSaved` ("Log is read-only (disk
  full): not saved.") when read-only, else `SQsoNotLogged`. Used by
  `tAddQSOToLog` (line + beep), `uEditQSO.EditRefusedByReadOnlyLog` (the
  edit form's Save and close-query) and Alt-Y `DeleteLastContact`.
- **Edit QSO opens for viewing; the SAVE is refused, FIRST.**
  `SaveQSOToEditableLog` posts the edit to the external loggers, UDP,
  HamScore and the server BEFORE the store write, and the store write
  returns nothing -- so the refusal is at its top. The fields stay editable;
  Save keeps the window open; closing with changes does not ask "Save
  changes?" (Yes could only be refused). Alt-Y is refused before its events
  the same way.
- **The double-click path says why** on the status line at every exit
  (`SEditQSONoQSOSelected`, `SEditQSOLogUnreadable`, `SEditQSONoSuchQSO`, and
  in `LoadQSOIntoEditForm` `SEditQSOCannotRead`, `SEditQSONotEditable`).
- **A REFUSED QSO STAYS TYPED (NY4I's second and third runs, same day).**
  `LOGSUBS2.LogContact` is a FUNCTION now (True = in the log), and
  `MainUnit.TryLogContact` stops on False: no further legs, no clearing of
  the call/exchange windows or the exchange, no `ClearQuickDisplayText` /
  `CleanUpDisplay` / `UpdateWindows` (those wiped the "not saved" line),
  and the park and county queues are emptied. It sets `QSOSaveRefused`, and
  the CQ and S&P Enter paths leave at once on it. An own QSO is refused at
  the TOP of `LogContact` when the store is read-only or will not open,
  before `SendRecordToServer` / `PostLoggedQso`. The FIRST failure is still
  found at the append, after the post (that order is NY4I's open question).
  Pinned by source read: `uTestAutomaticXQSO.Test_ARefusedSaveKeepsTheEntryAndItsReason`.
- **NO RESTART: THE NEXT SAVE TRIES AGAIN (NY4I: "clear up disk space,
  then hit enter").** `LogStoreTryRecoverWrites` is called where a save is
  decided: `LogContact`'s own-QSO refusal (before anything is posted),
  `uEditQSO.EditRefusedByReadOnlyLog`, Alt-Y. If the log is read-only
  because a WRITE FAILED, it runs `ProbeAWriteCommits` once. That is one
  transaction that inserts and deletes a page-sized `zeroblob(4096)` row
  in `session_state` (`tr4w.writeProbe`) and commits; the content is
  unchanged, but it needs one new or free page plus the commit's write. A
  failure goes through `Disable` (rolled back, still read-only, no modal).
  Success clears `GReadOnly` and leaves "The log is writable again."
  pending: `LogStoreShowRecoveryNotice` shows it. `TryLogContact` calls it
  AFTER its `ClearQuickDisplayText`. A LOCKED read-only open
  (`lrcLocked`) never recovers. **One write-failure modal per log**
  (`GWriteFailureNoticeShown`); a failure after a recovery is the status
  line only. Not polled: a peer's QSO (`MyComputer = False`) does not try
  again, so after a recovery peer QSOs log again but before one they are
  refused at the append. Pinned: `TestAFreedDiskRecoversWithoutARestart`
  (`LogStoreFreeTheDiskForTests` raises `max_page_count`), and the locked
  test's "does not recover" checks.
- **Test seam `LogStoreFillTheDiskForTests`**: `PRAGMA max_page_count = 1`
  on the store's OWN connection (it is per connection) -- SQLITE_FULL at
  the next page a write needs, on no real disk. Pinned:
  `TestAFullDiskLeavesTheLogReadable`.
- **Not done**: a full disk AT STARTUP (open, migration, `CheckWritable`)
  still disables -- the log is not viewable then. The ADIF import's batch
  (`LogStoreAppendQSOs`) rolls back and stays writable; the next write
  demotes. A running WRL worker fails on its own connection by itself.
  `uQTCS` marks a QTC through `LogStoreUpdateQSOAtIndex` with no status-line
  refusal (logged only).

## A CHANGE TO A LOGGED QSO IS "SAVED" ONLY WHEN IT IS COMMITTED (issue 349, 2026-11-22)

`docs/QSO_LOG_INTEGRITY_REVIEW.md` finding 3. Edit QSO and Alt-Y called
store PROCEDURES that answered nothing, and posted to the external loggers,
UDP, HamScore and the multi-op server BEFORE the write.

- **`LogStoreUpdateNewestQSO` and both `LogStoreUpdateQSOAtIndex` overloads
  are FUNCTIONS now**: True only after `Commit` returned, with the intended
  row changed (`TLogRepository.UpdateQSO`'s `RowsAffected > 0` on the
  primary key, and `UpdateQSOMyFacts`'s when facts are written). Every other
  ending is False: disabled, read-only, no row at that position or an empty
  log, a failed write or COMMIT (`Disable` as before). Callers that ignore
  the answer still compile (Delphi mode); none of the OPERATOR paths does.
- **An UPDATE that changed no row is rolled back** (`AbandonUnchangedUpdate`
  -> `RollBackAfterBusy`): the statement began a write transaction, and it
  must not sit holding the lock until the next `BeginMainWrite` commits it.
  `LogStoreUpdateQSOBySessionIds` does the same when no row matches.
- **`LogStoreUpdateQSOBySessionIds` answered True when its COMMIT raised**
  (the result was the match, assigned before `Commit`) -- the R2 defect
  again. True is assigned after the commit now.
- **Callers, classified.** OPERATOR: `uEditQSO.SaveQSOToEditableLog` reads
  what the event carries (station, sent exchange, second domestic key)
  BEFORE the write, writes, and only on True posts `PostQsoEvent`, sends
  `NET_EDITEDQSO_ID`, rescores; False shows `LogStoreChangeNotSavedText`,
  beeps, and returns False so the form stays open with its fields.
  `logsubs2.DeleteLastContact` (Alt-Y) writes first; only on True flips
  `tLastLogEntryIsDeleted`, posts, sends, reloads and shows the message.
  BULK/PEER: `uQTCS` sends the QTC mark to the server only after a True and
  logs a False; `uNet.FindAndUpdateQSOInLog` already rescored only on True;
  the rescore (`LogStoreUpdateQSOsByRowId`) already returned a checked
  boolean.
- **`LogStoreChangeNotSavedText`** (`SLogChangeNotSaved`) is the status line
  for a change; `LogStoreNotSavedText` keeps "NOT LOGGED ... do not clear
  the entry" for a new QSO. One body, `NotSavedTextOr`, for the read-only
  lines of both.
- **No busy retry on an update** (an append tries `LOG_WRITE_ATTEMPTS`
  times). `BeginMainWrite` removes the stale-snapshot cause; a busy update is
  refused through `Disable`'s busy branch and the edit window stays open for
  another Save.
- **Pins**: `uTestLogStore.TestAChangeWhoseCommitFailsIsNotReportedSaved`
  (the R2 deferred-foreign-key COMMIT trap on `qso`, AFTER INSERT and AFTER
  UPDATE, added after the migration because the v11 rebuild refuses a
  trigger on `qso`; insert, edit, delete, restore and a peer's edit each
  answer False and the file is unchanged). `max_page_count` is NOT a usable
  injection for an update: an in-place rewrite needs no new page.
  `uTestAutomaticXQSO.Test_AChangeIsAnnouncedOnlyAfterItsCommit` reads both
  operator paths for the order.
- **Not done**: Alt-Y rewrites `NewestRowId` and does not check that it is
  the row `LogSourceReadFromEnd(1)` returned (both on the main thread, so no
  interleaving is known). The rollback of an unchanged update, like any
  commit, closes the datasets on the transaction.

## A TAKEN NEW-CONTEST LOG NAME GETS A NUMBER, NEVER AN OVERWRITE (issue 276, 2026-11-11)

NY4I: an automatic numeric suffix, and never offer to overwrite. CW Open runs
three sessions a day (serials from 1, separate submissions), so one contest,
date and callsign must name several logs.

- **`uLogNaming.FirstFreeLogFileName(dir, name[, aTaken])`** is the rule:
  `X.db`, then `X 2.db`, `X 3.db`... the FIRST free number (a gap is filled).
  `aTaken` is injectable; the two-argument overload asks the disk. Pinned in
  `uTestLogNaming`. It raises past 9999 rather than loop on a broken test.
- **`uNewContest.SaveNewContest` decides BEFORE it queues anything**: Create
  new log (the numbered name, default), Open existing log, Cancel (the New
  Contest dialog is shown again; nothing queued, no file). Open existing is
  answered as `nccOpenSelected`, exactly like choosing that log's row, so File >
  Open Log relaunches on it without a hand-off file.
- **The old `TC_FOLDERALREADYEXISTSOVERWRITE` question was false**: Yes and No
  both opened the existing log, because an existing `.db` is opened and
  `TLogDatabase.CreateNew` refuses to replace one. It is retired from every
  catalogue.
- **No reader of the name's parts was found** (searched 2026-11-11: the only
  caller of `ContestLogFileName` is `SaveNewContest`, and no routine named for
  parsing a log's file name exists in `src/`). Keep it so: `W1AW 2.db` reads
  the same as the sanitised `W1AW/2`, so the name cannot be an identity record.
- **The date in a new log's name is TODAY'S UTC DATE** (issue 284,
  2026-11-12): `SaveNewContest` asks `uLogNaming.NewContestLogFileName`,
  which is `ContestLogFileName` on `LocalTimeToUniversal(Now)`. It was the
  local date, a day behind the contest on a US evening. Not the contest's
  start date: nothing writes `start_time` yet (Q99). An existing log keeps
  its name.

## The `config` table holds only what the operator STATED (2026-10-01)

For a contest-scoped setting, a row means the operator stated it, and a
missing row means the contest decides. See `docs/CONTEST_OWNERSHIP_DESIGN.md`
section 7.8.

- **Capture.** `CaptureContestStatements` writes a row while
  `Settings.CommandIsStated` is True and deletes it otherwise. It never writes
  `CONTEST`. It then sets the **mark** `session_state.configHoldsStatementsOnly
  = 1`.
- **Read.** `KeepOnlyStatements` filters the rows `LoadContestConfig`
  returns.
  - **A marked log:** every row is a statement.
  - **An unmarked log** (written before the rule; every corpus fixture is
    one): a contest-scoped row equal to the `TR4WSettings` constructor default
    is dropped and logged. A non-default row is a statement.
- **The mark is how a stated `NONE` survives.** Without it, an operator who
  chose the default on purpose would be indistinguishable from the old
  sentinel.
- **Station rows are unchanged -- except the station FACTS** (design 7.12,
  2026-10-13). MY STATE, MY ZONE, MY GRID and the rest of
  `uSettingsModel.TStationFact` are written by
  `CaptureStationFactRows`: the contest's override as `contest` while it is
  stated, else the station's value as `station`. On reopen such a row
  becomes the override again through `uCFG.ApplyContestStatement`, BEFORE
  the no-op skip. The skip compares against the station's value and would
  otherwise demote an override equal to it. A log written before 7.12 holds
  the same `contest` rows and reads as it did.

`/EXPORT` never captures, so the tracked fixtures keep their sentinels for
good. The reader handles them; do not rewrite the fixtures to "clean" them.

**The main log's column widths are `config` rows too, and NOT settings**
(NY4I, 2026-11-06: per contest, because the main log's columns depend on the
contest). `COLUMN WIDTH <token>` = a 96-dpi width, source `contest`, one row
per column anyone dragged; the token is `ColumnCanonicalName`, and an unknown
one is kept and written back. In memory they are
`uColumnWidthStore.ContestColumnWidths`.
- **Read:** the apply loop routes them to `CheckCommand` BEFORE the renderable
  guard. The settings object owns no such name, so that guard refused every
  one as "an action, not a setting" until 2026-11-06 -- `arrl_fd_2026_ny4i`
  and `cqwpx_cw_2026_ny4i` hold such rows. The store is emptied after
  `EnsureOpen` (after a new log's creation capture, so a `.cfg` import's
  widths survive) and again at `LogStoreClose`.
- **Write:** `CaptureContestColumnWidths`, inside the close capture -- not on
  a timer, so a main-thread layout tick never competes with the QSO writer
  for the lock. Replaced, never deleted. A crash loses that session's drags,
  as it loses every other unrecorded setting.
- **Units:** old rows are read as 96-dpi, unconverted. Measured: no DPI
  awareness in `W11.manifest` or `tr4w.lpi`, so a Windows build's rows are
  96-dpi already. Inferred: a gtk2/Cocoa build's rows (a text `.cfg`
  contest captured into its `.db`) may be off by the scale factor until the
  next drag. A too-small one (the September character counts) is floored at
  its header by the grid.

**Modelled, not called:** the statement tests model the store's apply as two
steps, `KeepOnlyStatements` then `TrySetByCommand`. If you change the apply
loop, keep it that pair. (They were written while `uLogStore` could not be
linked; it can now -- see `uTestLogStore` -- so calling
`LogStoreApplyContestConfig` directly is open to whoever next touches them.)

## Oracles

```powershell
.\tr4w\build\Build-Tests.ps1 -Run
```

```bash
bash tr4w/test/corpus/export-d12-corpus.sh    # 24/0/2 AND exit 0
```

**The corpus exercises the DATABASE, and its fixture IS a database** — each set
tracks a `log.db`, since 2026-09-24 (`badc63c5`). The independence that matters
is unchanged and is in the REFERENCES: `ref.adi` and `ref.cbr` are still
D7-produced and were never regenerated. Binary-log import keeps its coverage as
a unit test over the six `.trw` fixtures in `test/unit/fixtures/binarylog/`.

**`uLogSource` HAS NO SOURCE SELECTION.** `TLogSourceKind`, `LogSourceKind`,
`lsBinary`/`lsDatabase`, `LogSourceDescription` and the binary read path were
removed on 2026-09-24 along with `/EXPORTDB`: `/EXPORTTRW` had gone first, which
left one reachable state and eleven unreachable `case` arms that no compiler can
diagnose. Import is untouched.

`Lint-DomainPurity.ps1` guards `src/domain/`.

**SQLite is bound dynamically**, so a missing `sqlite3.dll` is a run-time failure,
not a link error.

## Open

~~`LogStoreBackup` orchestration tests are owed~~ — **done 2026-09-18** (NY4I
approved the leaf extraction): `uLogBackup` + 18 tests.

~~Whether the verifier should stop converting the snapshot to WAL~~ and
~~whether a failed `.bak` displacement should stop the publish~~ — **both
decided YES by NY4I and fixed 2026-09-19.** See `OpenReadOnly` above for the
first; for the second, `TLogBackup.Run` now honours the displacement rename,
stops before publishing when it fails, keeps the verified `.new` and names all
three files. Do not re-report either as open.

Still open: the store-level fault-injection tests for the QSO acknowledgement
contract (a commit that fails must make `LogStoreAppendQSO` return False). The
repository half is pinned as of 2026-10-14
(`TestEveryWriteWaitsForItsCommit`): a QSO the store did not commit is no
longer durable. ~~The store-level test still needs `uLogStore` to be
linkable~~ -- **it IS linkable** (2026-10-17, `uTestLogStore`). Since
2026-10-23 the two test seams and the deferred-foreign-key commit trap exist
(`Test_R2_ACommitThatFailsIsNotReportedSaved` is the pattern), so nothing
blocks those tests now; they are simply not written.

## Coordinate with

`contest-scoring` (QSOs arrive from there) · `file-formats` (import and export) ·
`multi-op-network` (row-level sync is the destination) · `contest-factory`
(contest parameters live in the contest database).
