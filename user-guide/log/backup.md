# Back up your log

TR4W can create a verified snapshot of the open contest database, manually or after a chosen number of logged contacts.

## Configure a destination

1. Open settings with **Ctrl+J** and find **Log backup**. Searching for `BACKUP LOG FILE NAME` also locates the destination control.
2. In **Copy to:**, enter a destination filename or use **Browse...**. Choose a different physical disk if you want protection against failure of the log's disk. Use a distinct filename for each contest.
3. In **Back up every:**, set the number of QSOs between automatic backups. **0 = never** disables the automatic schedule. For example, `10` requests a backup at each ten-QSO total.
4. Apply the settings, return to the operating window, and press **Alt+F** for a manual backup.
5. Look for the success message **Log backed up to …**, then confirm the file exists at the reported destination.

!!! warning "Set the destination first"
    A manual backup with an empty destination does not create a file. A periodic interval alone is not enough.

## What the backup files mean

| File | Meaning |
| --- | --- |
| The destination you configured | Latest successfully published snapshot. |
| The same name followed by `.bak` | Previous destination displaced by a later successful backup cycle. |
| The same name followed by `.new` | Staging file; a failure message may identify it as a verified copy that could not be published. |

TR4W writes a snapshot and checks its integrity before replacing the destination. It reports failures and records them in the diagnostic log. If a message names a `.new` file, preserve that file and the existing backups while investigating; the extension alone does not establish whether a staged file is usable.

## Avoid copying only an open database

Use TR4W's backup command while the contest is open. The database can have committed contacts in a separate write-ahead log, so copying only the `.db` file during operation can miss data.

For a full station archive, close TR4W and retain the contest folder and your settings as well. The log snapshot procedure does not establish that all external station files or downloaded databases are included.

## Check a recovery copy before you need it

See [Restore files and recover a contest](restore.md) for the copy-first recovery procedure, settings recovery, and handling database sidecar files.

Keep the backup untouched and make a separate working copy for a restore rehearsal. Open that copy as an existing contest and compare the contest identity and recent contacts against the original. This rehearsal remains an operator-review task for the preview; do not replace a live contest database as part of it.

If a backup fails, check the destination path, write permissions, available space, and whether the destination is open elsewhere. Repeat the backup and look for explicit success.

??? info "Source check"
    Controls: `ui/lcl/uPrefsForm.lfm` and `.pas`. Schedule: `trdos/logsubs2.pas`. Manual action: `uAccelerators.pas`, `MainUnit.pas`, and `BackupLogNow` in `trdos/logstuff.pas`. Snapshot verification and rotation: `domain/uLogBackup.pas` and `uLogStore.pas`. This guide has not performed a restore test.
