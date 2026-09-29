# Restore files and recover a contest

The current contest log is a SQLite database. Older instructions for rebuilding or copying a legacy binary log are not the recovery procedure for this version. **Ctrl+R**, described as “Restore last entry” in the old shortcut list, is an entry-editing action, not database restoration.

## Restore a verified log snapshot

1. Stop logging and close TR4W. Preserve the current contest folder before replacing anything, including any `.db-wal` and `.db-shm` files that remain. Keep the originals together and untouched for investigation.
2. Locate the most recent successful [TR4W backup](backup.md). The configured destination is the latest published snapshot; its `.bak` is the prior snapshot. A `.new` file needs the backup result/log checked before treating it as a valid backup.
3. Make a separate working copy of the chosen snapshot in a recovery folder. Give the copy a `.db` extension if the backup filename has another extension, so it can be selected as a database. Keep the backup itself unchanged.
4. Start TR4W and open that copy as an existing contest. TR4W performs database identity, version, integrity, and foreign-key checks during opening. If it refuses the file, retain the error and diagnostic log; do not work around it by creating an empty file over the original.
5. Verify the contest, station identity, contact count, recent QSOs, and score. Determine which QSOs occurred after the snapshot. Reconcile them from independent records before continuing; a successful open alone does not show that the backup contains every contact.
6. Choose the verified recovered database as the continuing log and set its backup destination appropriately. Keep the original and recovery evidence until reconciliation is complete.

Do not attach old live-database WAL files to a restored snapshot. Use a fresh recovery folder so sidecars from a different database cannot be mixed with it. For a database recovered from a disk rather than a TR4W snapshot, preserve the database and its matching sidecars together and work on copies.

## Restore settings and reference files

| Item | Recovery approach |
| --- | --- |
| `tr4w.json` station settings and window layout | With TR4W closed, retain the current file and restore a known-good copy to the actual settings path. This can also restore older radio addresses, passwords, and window positions; check them before operating. |
| CTY.DAT and TRMASTER.DTA | Restore saved copies or use the [reference-data download procedures](../start/data-updates.md). Follow the reload/restart instructions. |
| Custom DOM and other contest support files | Recover from your station archive. A generic download may not reproduce custom multipliers or local definitions. |
| ADIF/Cabrillo/CSV exports | Keep as independent evidence and deliverables. They are not substitutes for a complete database/settings backup. See [importing](import.md) for the supported import route. |

The database snapshot does not back up the entire station configuration. See [files and folders](../start/files.md) for platform-specific locations, and [window recovery](../operating/appearance.md#recover-a-window-from-a-missing-monitor) if the problem is only an off-screen window.

??? info "Source check and review boundary"
    Current snapshot behavior: `domain/uLogBackup.pas`; database opening/validation: `uLogStore.pas` and `uLogDatabase.pas`. This is a conservative copy-first recovery procedure derived from those paths. A complete GUI restore rehearsal remains to be performed; no user's log was restored or overwritten while writing this guide.
