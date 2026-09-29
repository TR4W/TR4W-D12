# Files and folders

The **contest log** contains your contacts. The **diagnostic log**, `tr4w.log`, records program activity and errors. They are different files with different purposes.

## Default locations

`~` means your home directory. On Windows, “working folder” means the process's current directory, normally established by its shortcut or launch command; it is not always the executable's folder.

| File group | Windows | macOS | Linux |
| --- | --- | --- | --- |
| Station settings | `working folder/settings/tr4w.json` | `~/Library/Application Support/TR4W/tr4w.json` | `~/.config/tr4w/tr4w.json` |
| Diagnostic log | `working folder/tr4w.log` | `~/Library/Logs/TR4W/tr4w.log` | `~/.local/state/tr4w/tr4w.log` |
| Default contest root | Working folder | `~/tr4w/` | `~/tr4w/` |
| Shipped reference data | Working folder | `TR4W.app/Contents/Resources/` | `/usr/share/tr4w/`, with fallback beside the binary |
| Downloaded CTY/TRMASTER/POTA data | Settings directory | Settings directory | Settings directory |

On Linux, `XDG_CONFIG_HOME` and `XDG_STATE_HOME` override the `.config` and `.local/state` bases. A `--settings <path>` launch option selects a different settings file and also relocates downloaded data beside that file. Opening a contest elsewhere does not imply that the station settings moved with it.

## Example directory trees

These examples use `practice.db` as an illustrative contest filename. You can open a contest elsewhere; these show the default roots. Downloaded files appear after you obtain them, and SQLite companion files need not always be present.

=== "Windows"

    Example working folder: `C:\TR4W`.

    ```text
    C:\TR4W\
    ├── settings\
    │   ├── tr4w.json
    │   ├── CTY.DAT          downloaded country data
    │   ├── TRMASTER.DTA     downloaded callsign data
    │   └── pota_parks.csv   downloaded park data
    ├── dom\                shipped domestic multiplier definitions
    ├── CTY.DAT              shipped fallback, if packaged
    ├── TRMASTER.DTA         shipped fallback, if packaged
    ├── practice.db          contest database
    ├── practice.db-wal      SQLite companion, when present
    ├── practice.db-shm      SQLite companion, when present
    └── tr4w.log             diagnostic log
    ```

=== "macOS"

    ```text
    ~/tr4w/
    ├── practice.db
    ├── practice.db-wal      when present
    └── practice.db-shm      when present
    ~/Library/Application Support/TR4W/
    ├── tr4w.json
    ├── CTY.DAT
    ├── TRMASTER.DTA
    └── pota_parks.csv
    ~/Library/Logs/TR4W/
    └── tr4w.log
    /Applications/TR4W.app/Contents/Resources/
    ├── dom/
    └── ...                 shipped reference data
    ```

=== "Linux"

    ```text
    ~/tr4w/
    ├── practice.db
    ├── practice.db-wal      when present
    └── practice.db-shm      when present
    ~/.config/tr4w/
    ├── tr4w.json
    ├── CTY.DAT
    ├── TRMASTER.DTA
    └── pota_parks.csv
    ~/.local/state/tr4w/
    └── tr4w.log
    /usr/share/tr4w/         or data beside the unpacked binary
    ├── dom/
    └── ...                 shipped reference data
    ```

Use **Preferences → Logging → Open log file** to locate the active diagnostic log instead of guessing which installation produced it. See [Diagnostic logging](../log/diagnostics.md) for DEBUG/TRACE settings and subsystem traces.

## File types

| File | Purpose |
| --- | --- |
| Contest `.db` | SQLite contest database: contacts and contest-associated data. |
| `.db-wal`, `.db-shm` | SQLite companion files that can exist while a database is in use. Do not discard them while copying or recovering a live database. |
| `tr4w.json` | Station configuration. Use Preferences or the migration tool rather than assuming an older INI edit applies. |
| Legacy `.CFG` / `.TRW` | Earlier configuration and binary log formats; preserve originals during migration. |
| `.ADI` | ADIF export for transferring contacts. |
| Cabrillo `.LOG` | Contest submission output; distinct from the diagnostic `tr4w.log`. |
| `.DOM` | Domestic-multiplier definitions used by the contest. Shipped sets live in the data root's `dom` directory. |
| `CTY.DAT` | Country/prefix information. |
| `TRMASTER.DTA` | Callsign/Super Check Partial reference data. |
| `pota_parks.csv` | POTA park-reference and name lookup. |

## DOM files and contest-specific data

The [DOMESTIC FILENAME](../reference/commands/a-d.md#domestic-filename) setting identifies the domestic multiplier file. Contest definitions can select their own data, and DOM files can include other definitions from the shipped DOM directory. Preserve custom DOM files with the contest archive and record which version you used.

Do not move a working setup's custom data merely to match a generic table. The configured filename and the program's diagnostic messages are the authority for a particular contest.

## Download precedence

For data using the preferred-data resolver, the downloaded copy beside the active settings file wins over the shipped copy. This lets the application update data without modifying a signed macOS bundle or a read-only Linux package. A newer application package can still use an older downloaded override until you update that override.

For a live contest backup, use [TR4W's snapshot procedure](../log/backup.md). For an archive, close the application and preserve the contest files, relevant settings, and custom reference data.

??? info "Source check"
    Paths and precedence: uAppPaths.pas (`tr4w/src/uAppPaths.pas`). DOM handling: `trdos/logdom.pas`. Export names: `trdos/postunit.pas` and the corpus README. The Linux installation document's older “beside the binary” contest location is superseded by `ContestDir`.
