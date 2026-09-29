# Moving from 4.x

The 5.x contest picker works with database logs. Some instructions in the older manual refer to files and storage that have since changed.

Treat station and contest migration as separate tasks: [convert station INI settings to JSON](ini-to-json.md), then [import and verify contact data](../log/import.md). Neither step alone confirms that your messages and contest-specific configuration are correct.

## Try an older contest on a copy

1. Close the old TR4W instance and copy the entire contest folder to a separate test location.
2. Start the 5.x preview and use **Browse...** in the opening dialog to select the copied legacy configuration.
3. Allow the program to open the contest, then check the calls, exchanges, number of contacts, and contest selection.
4. Close and reopen the migrated contest and check it again.
5. Keep the original folder until you have compared an export from the migrated log with your original records.

The picker lists a legacy `.CFG` only when its matching `.db` is absent. Its implementation explains that opening a legacy contest builds the database from the binary log on first open; once the database exists, the picker avoids listing both entries.

!!! warning "Migration is not a backup"
    Work on the copied folder during this evaluation. This prototype has not tested round-trip compatibility or recovery of a live contest database. For subsequent backups of an open 5.x log, use the [verified backup procedure](../log/backup.md).

## Settings also changed

Do not assume that an old instruction to edit `tr4w.ini` describes the current settings store. The current code has a typed settings model and the Linux notes identify `~/.config/tr4w/tr4w.json` as the settings file. Prefer the program's settings controls while evaluating the preview.

??? info "Source check"
    `tr4w/src/ui/lcl/uNewContestForm.pas` (`PopulateFiles`), `tr4w/src/uSettingsModel.pas`, and `docs/INSTALL_LINUX.md`. Full migration, backup, and recovery procedures remain review tasks.
