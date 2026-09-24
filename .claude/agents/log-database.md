---
name: log-database
description: The contest log in SQLite — schema, the database layer, the repository, log source selection, search, notes, backup and integrity. Use for anything that reads or writes QSOs, the log store, database migrations, log naming, or log integrity checks.
tools: Read, Grep, Glob, Bash, Edit, Write
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
| store, search, compare, notes, naming, config | `uLogStore.pas`, `uLogSearch.pas`, `uLogCompare.pas`, `uLogNote.pas`, `uLogNaming.pas`, `uLogConfig.pas` |
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

**`SysUtils.RenameFile` differs by platform:** `MoveFileW` on Windows refuses an
existing target; `rename(2)` on Unix replaces it. A directory at the target
fails on both, which is the portable way to make a publish rename fail in a test.

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

Still open: `uLogStore` itself is not linkable by the test program, and the
fault-injection tests for the QSO acknowledgement contract are owed.

## Coordinate with

`contest-scoring` (QSOs arrive from there) · `file-formats` (import and export) ·
`multi-op-network` (row-level sync is the destination) · `contest-factory`
(contest parameters live in the contest database).
