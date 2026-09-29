# Import contacts

ADIF import adds contacts to the open contest database. Choose the receiving contest before importing; an exchange's interpretation depends on that contest.

## Import an ADIF file

1. Preserve the original file and [back up](backup.md) any receiving contest that already contains contacts.
2. Create or open the intended contest. For a migration trial, use a separate empty contest.
3. Choose **File → Import → ADIF** and select the `.adi` or `.adif` file.
4. If the receiving log is not empty, review the prompt asking whether to append imported QSOs. Cancel if this is not the intended destination.
5. Review the completion counts and any failures, then check representative calls, dates/times, bands, modes, and exchanges in the log.
6. Export the resulting contest and compare important fields with the source, especially contest-specific exchanges and multi-location contacts.

The importer appends through the database store and counts a contact as loaded only when its append commits. It rescores and reloads the log afterward. A partially failed import can therefore leave some contacts successfully added; do not rerun it blindly and assume the first attempt was all-or-nothing.

## Avoid accidental duplicates

The append prompt is not a promise that repeated imports are automatically deduplicated. Keep track of which source files have been imported and check the log before repeating an import. The importer has contest-specific handling, including county-line contacts; unusual repeated calls may be legitimate and need inspection rather than blanket removal.

## Bringing a 4.x log forward

Export ADIF from the old installation, preserve the original contest folder, and import into a separate correctly selected contest in the new build. The source explicitly supports ADIF import without requiring a `.TRW` file beside it.

The opening picker also recognizes legacy configurations where no matching database exists, as described in [Moving from 4.x](../start/migration.md). That path should be tested on copies. Neither contact import nor [INI-to-JSON conversion](../start/ini-to-json.md) by itself proves that all messages, station settings, categories, and contest-specific configuration have migrated.

This guide does not establish a Cabrillo-import command. Cabrillo appears here as an export/submission format.

??? info "Source check"
    `MainUnit.pas`, `ImportFromADIF`, supplies the picker, append prompt, commit-based counts, and rescore/reload. `uADIF.pas` supplies parsing. Tests include `uTestLogImport`, `uTestLogRepository`, and ADIF fixtures. No user log was imported for this page.
