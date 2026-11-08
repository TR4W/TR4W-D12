# Back up your log

TR4W creates a verified snapshot of the open contest database. A manual backup works without an external backup destination.

## Make and check a backup

1. Press **Alt+F** to back up the open log.
2. Read the result and note the local snapshot path. Local backups are kept in the **backup** folder under TR4W's writable settings folder.
3. If you configured **BACKUP DESTINATION**, TR4W also copies the snapshot there in the background. Check that copy's completion separately: a successful local snapshot does not prove the external copy completed.
4. Confirm the reported file exists. Keep a copy on another physical disk for protection against loss of the local disk.

## Set an automatic interval

Open **Ctrl+J**, find the backup settings, and set the number of new QSOs between backups. **0** disables the automatic schedule.

The interval counts newly logged records since the last backup, rather than the current log total. It starts at zero each session. New dupes, X-QSOs, and contacts received from peer stations count; notes do not. A manual backup resets the interval counter, including a failed attempt, so check the result and retry a failure yourself.

An optional **BACKUP DESTINATION** adds a background copy; it is not required for local backups.

## Snapshot files

The periodic snapshot is named for its log, with **periodic.db** in the filename. A successful replacement retains the prior snapshot as **.bak**. A **.new** file is a staging file: preserve it after a failure, but check the result and diagnostic log before trusting it.

**Clear Log** first makes a separate UTC-dated snapshot in the local backup folder. If that snapshot fails, clearing stops without removing the contacts. Keep the dated snapshot until you have verified the intended result.

## Recover safely

Use TR4W's backup command while the log is open. Copying only an active database file can miss committed contacts still in its write-ahead log.

For a full station archive, close TR4W and retain the contest folder, settings, and custom support files as well. A log snapshot does not back up every station file or credential.

Follow [Restore files and recover a contest](restore.md) to rehearse recovery on a separate copy. Check identity, contact count, recent QSOs, and score before relying on it.

??? info "Source and review boundary"
    Reviewed at 48806af1: uAppPaths.BackupDir, uLogStore, domain/uLogBackup, uBackupCopyService, and manual/periodic backup callers. No live contest was cleared or restored during this review.
