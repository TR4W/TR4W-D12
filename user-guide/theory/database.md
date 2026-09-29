# SQLite integrity and durability

TR4W uses a SQLite database as the contest log. Protection comes from several checks at different stages, not from a single “database is safe” flag.

## Before accepting contacts

The database layer checks file identity and schema version. A foreign database or a schema newer than the program understands is refused rather than treated as a compatible log.

On opening the contest store, TR4W checks database integrity and then checks whether it can write. An integrity failure or a failed write check disables the log store and reports the problem. Opening a file successfully is not treated as proof that a later QSO can be saved.

| Check | What it detects |
| --- | --- |
| Application identity and schema version | Wrong file type or unsupported schema |
| SQLite `integrity_check` | Structural database problems; success requires the result `ok` |
| SQLite `foreign_key_check` | Broken relationships between records |
| Writability probe | A database that opens but cannot accept writes |

The full integrity check runs on open; it is not a full database scan after every QSO.

## When saving a contact

The append path starts with a failure result and returns success only after the repository commit succeeds. This makes “saved” depend on persistence rather than merely placing a row on screen.

The write connection requests `synchronous = FULL` and write-ahead logging (`journal_mode = WAL`). It reads back the actual journal mode and foreign-key enforcement state. Foreign-key enforcement is required. WAL is requested rather than assumed; the connection records the mode SQLite actually supplies.

In WAL mode, recent committed data can reside in a companion `-wal` file. The main `.db` file alone is therefore not necessarily a complete live copy of the contest.

## When making a backup

The backup path creates a consistent SQLite snapshot, including committed data still in the WAL. It writes to a staged `.new` file, opens that snapshot on a separate read-only connection, checks it, then publishes it by rename. An existing destination is retained as `.bak` during replacement.

Verification is read-only so it does not change the bytes being checked. Failure cases report the surviving filenames, including a verified `.new` file when publication fails. See [Back up your log](../log/backup.md) for the operating procedure.

## What these protections cannot prove

A successful integrity check does not validate callsigns, received exchanges, the contest category, or the sponsor's scoring rules. Durable commits also depend on the operating system and storage device honoring writes. No database setting eliminates disk loss, accidental deletion, or the need for a separate backup.

If TR4W reports an integrity or write failure, preserve the database and its companion files, retain the diagnostic log, and work from a separate recovery copy. Do not delete a WAL file as a troubleshooting shortcut.

## Supporting evidence

- Database implementation (`tr4w/src/domain/uLogDatabase.pas`): `ApplyWritePragmas`, `CheckIntegrity`, `CheckWritable`, and snapshot handling.
- Contest store (`tr4w/src/uLogStore.pas`): open-time checks and commit-dependent append result.
- Backup implementation (`tr4w/src/domain/uLogBackup.pas`): staging, verification, publication, and failure reports.
- Schema design history (`docs/SQLITE_LOG_SCHEMA_PLAN.md`): rationale and migration discussion. It includes stale implementation claims, including its backup status; current source takes precedence.

These are implementation-backed explanations for the documented snapshot, not a report of a power-loss or hardware-failure test performed for this guide.
