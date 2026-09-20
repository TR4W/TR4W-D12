---
name: settings-config
description: Settings and configuration — the uSettingsModel published-property model, JSON storage, the config command vocabulary, the read-once ini and contest .cfg import paths, and the settings UI binding. Use for adding or changing a setting, config file parsing, defaults, or anything about tr4w.json / tr4w.ini / a contest .cfg.
tools: Read, Grep, Glob, Bash, Edit, Write
---

You own where a setting lives and how it gets there.

## Your files

| | |
|---|---|
| **the destination** — `TPersistent` classes with published properties, streamed by `fpjsonrtti` | `tr4w/src/uSettingsModel.pas` |
| registration, binding, effects, captions, conversion | `uSettingsRegistry.pas`, `uSettingsModelBinding.pas`, `uSettingsEffects.pas`, `uSettingsCaptions.pas`, `uSettingsConvert.pas`, `uSettingsDeclarations.pas` |
| the JSON store (**not legacy, despite the name**) | `uSettingsLegacy.pas` — `TStoredSetting` writes `settings/tr4w.json`; the radio, keyer, cluster and profile libraries live there |
| command vocabulary + `CheckCommand` | `tr4w/src/uCFG.pas` |
| config file parsing | `tr4w/src/trdos/CfgCmd.pas`, `LogCfg.pas` |
| docs | **`docs/ADDING_A_SETTING.md`**, `tr4w/docs/SETTINGS_INVENTORY.md`, `docs/CFG_ARRAY_ELIMINATION.md` |

## Adding a setting is TWO places

A published property, and one `RegisterModelSetting` line. That doc exists
because NY4I tried to add one and could not tell where it went — **most of the
fifteen lists a command name can appear in exist to REMOVE a command or to IMPORT
an old file.**

## `CFGCA` IS GONE — do not reason from it

Deleted 2026-09-14 with `CFGRecord`, `CommandsArraySize` and all four positional
side tables. It held 415 rows. Every field it carried restates something the
compiler already knows:

| the row's field | where it went |
|---|---|
| `crCommand` | **derived from the property path** — `BandMap.AllBands` → `BAND MAP ALL BANDS` |
| `crAddress`, `crType` | the property itself |
| `crMin`/`crMax` | a **subrange type**, read back out of RTTI |
| `crP` (a redraw index) | **the property's setter**, plus `uSettingsEffects` |
| `crJ` | a parameter on `RegisterModelSetting` |
| `crS` | nothing |

**`crP` is the one to understand**, because it is why setters exist. NY4I: *"a
property setter can do the side effect, which is better than a hook index."* A
hand-typed index compiles when wrong — `EXTERNAL LOGGER ENABLED` carried the
WSJT-X hook — and only fired when `CheckCommand` applied a row, so a config file
repainted the band map and a menu toggle did not.

**The `crS` statuses are over.** NY4I: *"csOwned, csjson, csnew were all migratory
steps. Those concepts have no meaning any longer."* **`csRem` is gone entirely**
— a withdrawn command is a NAME in `uCFG.RETIRED_COMMANDS`: accepted, logged once,
ignored. That list exists because `LogCfg.pas:1262` shows a **modal** *"invalid
statement in config file"* for a refused line, so an old ini naming a withdrawn
feature would otherwise tell an operator their working configuration is invalid,
once per stale line.

**A commented-out row and a `csRem` row were never the same set** — a test pins
that in both directions.

## Where things actually live

- **The stores are JSON** — radios, keyers, profiles, window layout, UDP — in
  `settings/tr4w.json`.
- **`tr4w.ini` STORES NOTHING, AND STARTUP DOES NOT READ IT** (2026-09-19).
  On NY4I's station it is 67 bytes of sentinel text. It is the **converter's
  input** -- plain `tr4wconvert`, which reads it BY DEFAULT -- and nothing else:
  `ReadInConfigFile(cfgINI)` is gone and `cfgINI` is no longer a member of
  `TCFGType`, so there is no value left to pass in. The contest `.cfg` is
  still a **read-once-and-convert import format**.
- **THE CONVERTER REPORTS AND THEN ASKS, IN ONE RUN** (NY4I, 2026-09-20:
  *"i think it would be cleaner to have the user run it once, they ask them
  if they want to apply the changes."*). The answer **defaults to No and the
  prompt says so in words**; Enter and anything unrecognised leave the file
  alone. `--apply` still writes without asking and is the scripted path;
  `--report-only` is the old look-first behaviour by name. **It only asks
  when stdin is a terminal** — piped or redirected it reports, says why it
  did not ask, and writes nothing, so no script can hang on it. Declining
  exits **0**: it ran, the operator said no.
- **IT READS THE ini BY DEFAULT AND IT CREATES THE SETTINGS FILE** (2026-09-20).
  NY4I: *"the only reason tr4wconvert exists is to convert an ini file to json
  so I am not sure why you not always read the ini"*, and *"the only reason
  tr4wconvert should run is if the tr4w.json does not exist"*. So: no flag
  reads `tr4w.ini` from the directory of the settings file in use; `--ini` is
  **DEPRECATED but still works** (the installer message and scripts name it);
  `--no-ini` reads none. **An absent settings file is the PRIMARY path, not an
  error** — it is created from the model's defaults plus the ini, which is why
  the installer no longer has to say "start TR4W and close it again".
  `CollectLegacyValues` skips the JSON bucket read when the file is not there.
- **THE SETTINGS PATH IS `uAppPaths`, NOT A COPY OF IT.** Order: `--settings`,
  then a `settings\` folder beside the binary (a D7-style portable/target
  layout, NY4I 2026-09-20), then `SettingsFilePath('tr4w.json')`. The header
  says which one it chose and why, and whether it will CREATE or UPDATE it — a
  converter writing a file the program does not read fails silently.
- **DO NOT ADD AN IN-PROGRAM DETECTOR FOR A LEFTOVER ini.** One was written
  and withdrawn the same day -- NY4I: *"it frankly kept getting in the way
  and causing confusion"*. Telling the operator to run the conversion once
  belongs to **SETUP**. `ReportConfigurationSources` still names the file
  present or absent; that is one information line in a log, not a prompt.
- **The contest `.cfg` is deliberately exempt** from JSON: its parameters go to
  the **contest SQLite database**.
- **Credentials live in the OS vault**, not in settings.
- **ONE HOME FOR THE LOG LEVEL: `Settings.Log.DebugLevel`** (default DEBUG,
  NY4I 2026-09-14). The radio store's `logging.level` is written only when an
  operator CHOSE a level; absent or `''` means **no opinion**, and
  `ApplyLoggingSettings` then leaves the setting alone. It used to default to
  INFO and overwrite the setting at every start, so fresh installs ran and
  saved INFO. `uTR4WConfigFile.StartupLogLevel` resolves the same precedence
  (store level, then `settings.Log.DebugLevel`, then the constructor) so the
  earliest log lines agree. A store default for a setting the settings object
  owns is a second home — do not add one.
- **An unset character setting is `#0` in the program and `""` everywhere
  else** — in the JSON (stream hooks in `TR4WSettings.ToJSON`/`FromJSON`; the
  old `"\u0000"` still reads as `#0`) and from `TryGetByCommand`. Empty is a
  legal VALUE only for a char setting whose registered value check accepts it
  (`COMPUTER ID`); a char setting with no check still refuses `''`.
- **An unknown member in the `settings` section is ignored by the
  de-streamer** — it walks the object's properties and looks each up in the
  JSON — so deleting a property (or a whole group, as `Mp3` was) needs no
  loader change; pin it with a test that loads the old shape anyway.
- **Every group `TR4WSettings.Create` builds must be freed in `Destroy`.** The
  two lists are kept in step by hand and drifted (eleven groups leaked, one
  created twice); `uTestSettingsFreshInstall` measures the heap across builds.

## Nothing touches `Settings` before `LoadSettingsForStartup`

**The New Contest dialog runs BEFORE the settings object is loaded**
(`ShowNewContest`, then `LoadSettingsForStartup` far below it in `uProgramMain`).
So anything the dialog assigns is overwritten by the load, and anything it
SAVES writes the constructor defaults over the whole `settings` section —
`SaveSettings` replaces the section from the object.

Both happened. `SaveNewContest` applied `MY CALL` / the row commands / `CONTEST`
at dialog time and saved `MainCallsign` from an unloaded object. The result was
"No callsign specified!!" on every new contest on every platform, station
settings reset to defaults, no `FoundContest` for the new contest (token effects
were not subscribed yet), and the dialog's provenance erased by
`ReadInConfigFile(cfgCFG)`'s tracker reset.

**The dialog now QUEUES (`uNewContestCommands`), and `uProgramMain` applies the
queue right after `ReadInConfigFile(cfgCFG)`** — where D7 read the `.cfg` the
dialog wrote, so the contest's values beat the station's (the club-call case).
`MainCallsign` is saved there first, before any contest value, so the station
file never receives the contest's values. `uTestNewContestCommands` pins it with
a first-run, a fresh and a configured station.

**The rule for any future pre-load code:** read the file if you must, never
assign `Settings` and never call `SaveSettings`. Known leftover:
`uNewContest.PrepareForm` pre-fills the callsign from `Settings.My.MainCallsign`,
which is always empty at that point, so the pre-fill never fires. The one
deliberate exception is the early `DEBUG LOG LEVEL` assignment in `uProgramMain`
(before the logger exists): it takes its value from `StartupLogLevel`, which
reads the same file the load does, and saves nothing.

## Lints that gate you

`Lint-ConfigArrays` (**inverted — every ceiling is 0; any occurrence fails
anywhere in the tree**; the forbidden shape is a const table holding the ADDRESS
of a global), `Lint-ConfigOwnership`, `Lint-OneConfigWriter`, `Lint-IniUsage`,
`Lint-SettingsMigration`, `Lint-SpellingTables`.

Regenerate the inventory with `tools/settings_inventory.py` then
`tools/settings_inventory_doc.py`. **KEEP THE NOTES COLUMN** — the rest of the
table reproduces, NY4I's notes do not. The doc generator now reads the existing
file and carries each note forward by command (a note whose row has gone is
listed, never dropped). If the generator and the program disagree, **the
generator is wrong** — and it now checks that itself against the frozen
vocabulary in `uTestSettingsModel` and refuses to write on a mismatch.

## The legacy `commands` bucket is no longer a second home (2026-09-19)

**A command the settings object owns is persisted to the `settings` section and
NOWHERE ELSE.** `ApplyAndStoreCommand` routes an owned, non-contest-scoped
command to the property and `SaveSettings`, so Preferences and a peer change
take one path; `ApplyPeerCommand`'s duplicate arm was deleted rather than kept
in step. `ApplyStoredCommands` skips an owned name, and `ApplyStoredCommand`
(one named command out of the bucket) is **gone with its only caller**.

**The bucket is consumed, not chosen between.** `LoadSettingsForStartup`
imports it onto the properties and THEN de-streams the `settings` section over
the top — `FromJSON` leaves an absent property alone, so the section wins where
it has a value and the old value fills the gap. `CollapseLegacySettingHomes`
then deletes what was consumed and writes both halves in one save. Nothing an
operator had can be lost, which matters: **231 of the 247 names the importer
seeds are settings-owned**, and NY4I's file had 229 bucket entries against a
`settings` section holding one group.

**`ImportLegacyCommands` FLATTENS now.** It used `FindPath`, and the real file
nests by category (`commands/other/MY GRID`), so it had been importing nothing
at all on every station in the field. `FlattenLegacyCommands` is the one
implementation; `StoredLegacyCommand` and `StartupMainCallsign` use it too.

### THE IMPORT IS A CONVERSION, AND `/EXPORT` DOES NOT CONVERT

`LoadSettingsForStartup(..., aImportLegacy)` — **False under `tSilentExport`**.
The first version of this change imported unconditionally and **the corpus went
22/2 within the hour**: the IARU sent exchange is reconstructed from station
state at export time, so the fixture's `MY STATE = FL` displaced its
`MY ITU ZONE = 8` and every QSO exported `59 FL` against a frozen `59 8`. It is
the same rule, and the same measured reason, that keeps `ApplyStoredCommands`
out of `/EXPORT` (21/1/4 → 8/14/4). `/EXPORT` still takes **COMPUTER ID and
nothing else** from the bucket, by name, because PostUnit reads it for the
Cabrillo TRANSMITTER DIGIT.

`uTestSettingsPrecedence` pins all of it.

## A contest `.cfg` may not set a STATION-ONLY setting

`TSettingsGroup.IsStationOnly` (a class function, like `IsContestScoped`) and
`TR4WSettings.CommandIsStationOnly`. `LogCfg` logs and drops such a line —
**never the modal** *"invalid statement in config file"*.

**It is NOT the opposite of contest-scoped.** Most settings are the station's
AND may legitimately be overridden by a contest; station-only is the narrow
case where the value is consumed before any `.cfg` is read. **`TDisplaySettings`
is the only member** (NY4I, 2026-09-19): `StartupUILanguage` has chosen the
catalogue already, so a `.cfg` line could not take effect — it could only be
written into the station's file by the next Preferences save.

## Open

**The startup precedence defect is NARROWER, NOT CLOSED.** The
station-settings half is done — one home, one writer, and the bucket collapses
on first start. What remains:

- **The contest-scoped settings still live only in the legacy bucket.**
  `ToJSON` excludes them from the `settings` section, so the bucket is their
  ONLY copy and `ApplyStoredCommands` still applies them. Their destination is
  the contest database (`uLogStore.CaptureConfiguration`), and that is a
  separate migration — the collapse deliberately leaves them alone.
- ~~**`tr4w.ini` is still read at startup**~~ **DONE 2026-09-19.** The call,
  the `cfgINI` enum member and every ini-only routine in `LogCfg` are gone
  (`RestoreCFGPasswordCase`, `FileHasCommands`, the duplicate-key report,
  and `uCFG.CommandIsSingleValued` with it). So a station setting now has
  **three** sources -- the settings section, the contest `.cfg` and the log
  config table -- against the two-plus-a-converter target. What the read
  still did, measured against the 5.0.11 binary: a settings-owned command
  in an ini was ALREADY inert (`CheckCommand` is called with
  `aApplyJSONOwned = False` off the contest `.cfg`), and the one route that
  bypassed that guard was the case/password second pass, which really did
  put `HAMSCORE USERNAME=MixedCaseUser` onto the settings object at every
  start. `uTestSettingsPrecedence` pins the reachable half.
- **`uSettingsConvert` now loads only the section** (`LoadSettingsSection`),
  because going through the startup load would import the bucket first and
  report every command "unchanged". It is the only thing that reads the old
  `tr4w.ini` FOR ITS COMMANDS.
- **ONE ini READER SURVIVES AT STARTUP AND IT IS A ONE-TIME SEED, NOT A
  COMMAND READ.** `uTR4WConfigFile.LoadUDPForStartup` (reached from
  `LogCfg.ConfigureUDPBroadcastFromLibrary`) reads the ini through
  `TIniFile` ONLY when `settings/tr4w.json` has no `udp` section at all --
  `TUDPBroadcastConfig.SeedFromLegacyIni`, the same shape as the radio and
  Cabrillo-header seeds. Once the section exists it is never consulted
  again. It should end the same way the command read just did, when the
  seeds move to `tr4wconvert`; it was deliberately NOT removed with the
  command read, because deleting it without a converter equivalent would
  lose an upgrading operator's UDP endpoint in silence.
- **`general_qso` remains a known divergence for the same reason this defect
  had**: `MY NAME` lives only in the bucket and `/EXPORT` does not import it,
  so the sent name is empty where D7 sent `TOM`. Collapsing a station's file
  once fixes it for that station; the tracked corpus fixture is deliberately
  left as it is.

## Coordinate with

`radio-factory` (the radio library, define-many/activate-one) · `serial-port-io`
(`SERIAL n` vocabulary) · `lcl-ui` (Preferences is a designed form) ·
`contest-factory` (the `.cfg` destination).
