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
| schema | `tr4w/src/domain/uLogSchema.pas` |
| repository | `tr4w/src/uLogRepository.pas` |
| the read seam — SQLite only, no source selection | `tr4w/src/uLogSource.pas` |
| store, search, compare, notes, naming, config | `uLogStore.pas`, `uLogSearch.pas`, `uLogCompare.pas`, `uLogNote.pas`, `uLogNaming.pas`, `uLogConfig.pas` (**the Log4D layout, NOT the config table**) |
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

**And the stray-`-wal` worry that went with that finding did NOT reproduce**
(measured 2026-09-19): on a clean close SQLite removed both sidecars, so the
old code left nothing behind. The exposure was only a crash mid-check, and a
read-only connection to a rollback-journal file creates no WAL at all.

**BUT A READ-ONLY CONNECTION TO A WAL-MODE LOG LEAVES ITS `-wal` BEHIND**
(measured 2026-10-14, `OpenReadOnly` and Python's `?mode=ro` alike). A test
that asserts "nothing beside the file" must check BEFORE it opens the file to
inspect it.

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
- **The pin covers 16 write paths.** `SetSentExchange` joined it and left
  again the same day (2026-10-17) when its only caller was deleted; the
  fingerprint still includes `exchange_sent`. `UpdateQSOMyFacts` (the Edit
  QSO write of the my_* columns) joined on 2026-10-18, and the fingerprint
  now also includes `my_grid` and `my_source`.
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

- **`LOG_SCHEMA_VERSION = 3`. ONCE A SCHEMA-3 BUILD HAS OPENED A LOG, NO
  EARLIER 5.0.x BUILD CAN OPEN IT** (accepted by NY4I). `Open` migrates;
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
- **The lints scan nothing in a `.claude\worktrees\` checkout** (by design,
  `Get-ScanExclusions.ps1`), and twenty of them then FAIL as "no files
  scanned". Lint a copy of the change from a checkout outside that path.

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
linkable~~ -- **it IS linkable** (2026-10-17, `uTestLogStore`), so nothing
blocks those tests now; they are simply not written.

## Coordinate with

`contest-scoring` (QSOs arrive from there) · `file-formats` (import and export) ·
`multi-op-network` (row-level sync is the destination) · `contest-factory`
(contest parameters live in the contest database).
