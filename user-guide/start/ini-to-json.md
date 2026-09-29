# Convert INI settings to JSON

`tr4wconvert` brings legacy **station settings** into the current JSON settings file. It is a separate utility; it does not convert your contest log or complete every part of contest migration.

## Recommended sequence

1. Close TR4W and preserve the old installation, `tr4w.ini`, and any existing `tr4w.json`.
2. Install the intended 5.x package, including its matching `tr4wconvert` utility.
3. Place a copy of the legacy `tr4w.ini` beside the destination settings file. If JSON does not exist yet, use the directory where it will be created.
4. Run `tr4wconvert` from a terminal. Review the printed settings path, INI path, proposed changes, skipped contest settings, and refused values.
5. Apply only when the report describes the intended source and destination. The interactive answer defaults to **No**.
6. Start TR4W and verify callsign, radio/keyer setup, integrations, and other station preferences. Keep the original files until that check is complete.

The preferred sequence is **install → convert → start TR4W**. The converter can create a missing JSON file from defaults plus the legacy settings. It can also operate on an existing JSON file, so review the report carefully if the new program has already been used.

## Preview without writing

Run the matching executable from its installed location. On Windows, for an explicitly selected destination:

```powershell
.\tr4wconvert.exe --settings "C:\TR4W\settings\tr4w.json" --report-only
```

That example reads `C:\TR4W\settings\tr4w.ini` by default. Substitute your actual location. On native Unix packages, invoke the converter by its path without `.exe`.

With no explicit settings path, the utility first considers a settings folder beside itself, then the platform settings location. Always read the reported path; the shell's current directory is not a reliable substitute for that check.

## Options

| Option | Behavior |
| --- | --- |
| No mode option | Report, then ask to apply if standard input is a terminal. |
| `--report-only` | Report without prompting or writing. |
| `--apply` | Write without prompting; intended for deliberate scripted use. |
| `--settings <path>` | Select the destination settings file. |
| `--no-ini` | Do not read an INI file. |
| `--all` | Include every command in the report. |
| `--ini <path>` | Still accepted, but deprecated; names a nondefault legacy INI. |

When run without an interactive terminal and without `--apply`, the utility reports and writes nothing. Exit code **0** includes an operator declining conversion; it is not proof that a file was written. **1** indicates a settings-read failure; **2** indicates one or more refused values. Review the report as well as the exit code.

## Scope and limits

Contest-scoped settings belong in the contest database and are reported/skipped by this tool. Contact data and contest messages need their own migration checks. See [Import contacts](../log/import.md) and [Moving from 4.x](migration.md).

Conversion of an older JSON `commands` bucket is a different path: the converter's current program header says TR4W startup now imports and collapses those legacy setting locations itself. Do not confuse that JSON cleanup with importing a 4.x INI file.

??? info "Source check"
    tr4wconvert.lpr (`tr4w/tools/tr4wconvert/tr4wconvert.lpr`) is the authority for arguments, discovery, prompting, and exit codes. `uSettingsConvert.pas` implements conversion, but some of its introductory startup comments predate later changes. No personal settings were converted while preparing this page.
