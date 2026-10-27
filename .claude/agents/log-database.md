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
| backup orchestration (stage, verify, `.bak`, publish) | `tr4w/src/domain/uLogBackup.pas` — `LogStoreBackup` is a thin caller; tests in `test/unit/uTestLogBackup.pas` |
| the copy to BACKUP DESTINATION (worker thread, file I/O only) | `tr4w/src/domain/uBackupCopier.pas`, glue `tr4w/src/uBackupCopyService.pas`; tests in `test/unit/uTestBackupCopier.pas` |
| schema | `tr4w/src/domain/uLogSchema.pas` |
| repository | `tr4w/src/uLogRepository.pas` |
| the read seam — SQLite only, no source selection | `tr4w/src/uLogSource.pas` |
| store, search, notes, naming, config | `uLogStore.pas`, `uLogSearch.pas`, `uLogNote.pas`, `uLogNaming.pas`, `uLogConfig.pas` (**the Log4D layout, NOT the config table**). (`uLogCompare.pas` was listed here and was never the store's: it was the multi-op Difference-in-logs dialog's seam, deleted with the dialog in Phase 1, C6.) |
| which contest-scoped `config` rows are written, and which stored ones are statements | `uLogContestStatements.pas`, a leaf so the rules are unit-tested (`uTestLogContestStatements`) |
| our station as it was for one QSO (the my_* columns, schema 3) | `tr4w/src/domain/uQsoMyFacts.pas`, a leaf (`uTestLogMyFacts`) |
| import only | `uLogImport.pas`, `uLogBinaryFile.pas` |
| docs | `docs/SQLITE_MIGRATION_TASKS.md` (**read before touching log storage**), `docs/SQLITE_LOG_SCHEMA_PLAN.md` |

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
  name no longer is (there is no name). Still SYNCHRONOUS on the main thread
  -- local disk; moving the snapshot off is a later #98 step.
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
- **Started in `uProgramMain` after every headless Halt** (so the corpus
  never probes a share), which also offers this log's existing periodic
  backup to the destination, copied only if it differs. Tests:
  `uTestBackupCopier` (copier + setting), `uTestLogStore` (names, folder).
- **Still open in #98**: the snapshot off the main thread, the 60 s dirty
  timer, generations/catalog/SHA-256, retention, Restore, and reconciling an
  ambiguous rename on a share by name + hash.
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
- **The pin covers 17 write paths.** `SetSentExchange` joined it and left
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

- **`LOG_SCHEMA_VERSION` WAS 3 HERE, AND IS 4 SINCE Q113 (below). ONCE A
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
  directly instead: `-Mdelphi -Pi386 -Twin32 -Sc -B`, the `Get-SearchPaths.ps1`
  Tests list, run from `tr4w/test/unit`. Then copy the runtime DLLs from
  `tr4w/target`.

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
