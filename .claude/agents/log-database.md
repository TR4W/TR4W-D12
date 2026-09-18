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
| schema | `tr4w/src/domain/uLogSchema.pas` |
| repository | `tr4w/src/uLogRepository.pas` |
| source selection (default `lsDatabase`) | `tr4w/src/uLogSource.pas` |
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

## Oracles

```powershell
.\tr4w\build\Build-Tests.ps1 -Run
```

```bash
bash tr4w/test/corpus/export-d12-corpus.sh    # 24/0/2 AND exit 0
```

**The corpus exercises the DATABASE, not the binary log.** The tracked fixtures
are still D7-written `.trw` files — that independence is the whole value of the
oracle — but `uLogSource` defaults to `lsDatabase`, so the export path under test
reads SQLite. The `.trw` is the fixture format, not the store.

`Lint-DomainPurity.ps1` guards `src/domain/`.

**SQLite is bound dynamically**, so a missing `sqlite3.dll` is a run-time failure,
not a link error.

## Open

`LogStoreBackup` orchestration tests are owed — extracting a leaf unit for them is
NY4I's call, not yours to assume.

## Coordinate with

`contest-scoring` (QSOs arrive from there) · `file-formats` (import and export) ·
`multi-op-network` (row-level sync is the destination) · `contest-factory`
(contest parameters live in the contest database).
