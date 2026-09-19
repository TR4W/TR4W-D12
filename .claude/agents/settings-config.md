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
- **`tr4w.ini` STORES NOTHING.** On NY4I's station it is 67 bytes of sentinel
  text. It and the contest `.cfg` are **read-once-and-convert import formats**.
- **The contest `.cfg` is deliberately exempt** from JSON: its parameters go to
  the **contest SQLite database**.
- **Credentials live in the OS vault**, not in settings.

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
which is always empty at that point, so the pre-fill never fires.

## Lints that gate you

`Lint-ConfigArrays` (**inverted — every ceiling is 0; any occurrence fails
anywhere in the tree**; the forbidden shape is a const table holding the ADDRESS
of a global), `Lint-ConfigOwnership`, `Lint-OneConfigWriter`, `Lint-IniUsage`,
`Lint-SettingsMigration`, `Lint-SpellingTables`.

Regenerate the inventory with `tools/settings_inventory.py` then
`tools/settings_inventory_doc.py`. **KEEP THE NOTES COLUMN** — the rest of the
table reproduces, NY4I's notes do not. If the generator and the program disagree,
**the generator is wrong**.

## Open

**The startup precedence defect is OPEN** (memory:
`settings-startup-precedence-defect`). Six config sources today; the target is two
plus a converter.

## Coordinate with

`radio-factory` (the radio library, define-many/activate-one) · `serial-port-io`
(`SERIAL n` vocabulary) · `lcl-ui` (Preferences is a designed form) ·
`contest-factory` (the `.cfg` destination).
