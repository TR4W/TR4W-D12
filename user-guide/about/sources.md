# Evidence and review

## Source snapshot

| Source | Revision / scope |
| --- | --- |
| Development tree | `24f06a30081b607dbca5020fe583d97944be97d8`, version 5.0.22 |
| TR4W wiki | `d512ef6d6adfa8c187b6c9c7992af0cc9d60d791`, fetched September 24, 2026 |
| Public website | [tr4w.net](https://tr4w.net/), consulted September 24, 2026; describes 4.x |
| Local documentation | Files in the development snapshot above; includes historical manuals and design proposals |

The wiki was read from its Git repository after browser retrieval failed. It is a source for editorial comparison, not an automatically published mirror. No external images or entire manuals are copied into this prototype.

Operator instructions are included in this guide. Development-tree filenames below and in source notes identify editorial evidence; they are not external links or required reading. The generated reference retains this provenance without requiring access to the TR4W-D12 repository.

## Evidence by page

| Guide page | Primary evidence | Review still needed |
| --- | --- | --- |
| Choose your version | `tr4w/src/Version.pas`, `docs/INSTALL_LINUX.md`, website | Actual release artifacts and each supported OS |
| Open your first contest | `uNewContestForm.lfm` and `.pas` in `tr4w/src/ui/lcl/` | First-run screens, complete QSO and export walkthrough |
| Moving from 4.x | `uNewContestForm.pas`, `uSettingsModel.pas`, Linux notes | Migration on representative copied logs and recovery |
| Connect a radio | `uRadioEditForm.lfm`, TCP/IP wiki guide | Menu route and hardware tests per transport |
| WSJT-X | Wiki `WSJT-X-Integration.md`; `TWsjtxSettings` and aliases in `uSettingsModel.pas` | Actual UDP/log/highlight behavior |
| Earlier manuals | Wiki Home and `docs/MANUAL_UPDATE_SUMMARY.md` | Topic-by-topic reconciliation |
| POTA | `uPOTAParks.pas`, `MainUnit.pas`, `trdos/logstuff.pas`, `trdos/postunit.pas`; wiki POTA page | Park entry, repeat action, multiple parks, and ADIF in a running build |
| Keyboard essentials | `uAccelerators.pas`, `uMenu.pas`, `uTR4WStrings.pas`, `MainUnit.pas` | Focus and desktop handling on each platform |
| Backup | `domain/uLogBackup.pas`, `uLogStore.pas`, `trdos/logstuff.pas`, `trdos/logsubs2.pas`, Preferences form | Destination selection, periodic trigger, and restore rehearsal |
| Export | `uMenu.pas`, `MainUnit.pas`, `trdos/postunit.pas`, `uADIF.pas` | Export dialogs, output comparison, and receiver acceptance |
| About TR4W | Project positioning supplied for this experiment; repository history context | Release-specific platform availability before strengthening native-support claims |
| Command reference | `tr4w/docs/SETTINGS_INVENTORY.md`, `uSettingsModel.pas`, frozen vocabulary in `uTestSettingsModel.pas`, `uCFG.pas`, English help, v4.01 contents | Inherited descriptions, unextracted values, specialized command routes |
| Radio support | Initialization registrations in `tr4w/src/radioFactory/`; `uRadioRegistry.pas` | Runtime linking, backend availability, per-model hardware verification |
| External loggers | `uExternalLoggerFactory.pas`, `uExternalLogger.pas`, `uExternalLoggerBase.pas`, Preferences | DXKeeper delivery/edit/reconnect test |
| TCI | `radioFactory/uRadioTCI.pas`, `uRadioHamLibOnly.pas`, `uTCIServer.pas`, Preferences | Native driver and server interoperability tested separately |
| Database theory | `domain/uLogDatabase.pas`, `domain/uLogBackup.pas`, `uLogStore.pas`; schema design history | Power/storage-failure behavior is not certified by this documentation review |
| Test methodology | Database/backup unit suites, corpus README, UI tests, hardware test plan | Actual run results must identify revision and platform |
| Band map / cluster / multipliers | LCL forms, `uBandMapView`, `uSpots`, `uDXClusterClient`, `uTelnet`, `uRemMults`, `uMults` | Live UI, spot feed, and contest examples |
| CW | `uCWKeyerBase` and four adapters, keyer form, factory design history | Device/platform timing, routing, and cancellation |
| Languages | `uUILanguage`, embedded loader, resource-build script, `i18n/*.po`, translator documents | Human translation quality and screen layout; source counts are not approval counts |
| Contests | `VC.ContestTypeSA` and new-contest picker | Sponsor rule changes and event-specific examples |
| Installation / files / data | Build scripts, Linux notes, `uAppPaths`, downloaders | Package-specific installation checks; owner confirms native macOS operation |
| Reports / imports | Menus, `MainUnit.ImportFromADIF`, ADIF and report implementations | Individual report output and representative migration files |
| Network | `uNet`, network/compare forms, corrected networking analysis | Real multi-station disconnect/sync tests |
| INI conversion | `tools/tr4wconvert/tr4wconvert.lpr`, `uSettingsConvert` | Conversion of representative copied settings and post-conversion station checks |

## Editorial rules

The operating additions also reconcile the old reference manual and wiki SO2R tips with current code: colors and resizing (`uPrefsForm`, `uMainForm`), monitor recovery (`MainUnit`, `uWindowLayoutStore`), radio-panel fields (`uRadioPanelForm`), callsign assistance (`logedit`, `logscp`), message programming (`uEditMessageForm`, `logsend`), HamScore (`uHamScore`, Tools and status-window handlers), and radio reconnects (`ResetRadioPorts`). Each page records its source check. Physical-radio, multi-monitor, remote-scoreboard, and GUI restore rehearsals remain open.

The HamScore source check exposed a current UI limitation: the status-window resync button queues the remote delete request without the full-log walk performed by the Tools action. The operator page documents the distinction; this documentation change does not modify the application.

1. Label the target version and platform. Never turn a development plan into a released feature claim.
2. Start a procedure with an operator task and finish with a visible success check.
3. Verify field names and defaults in current forms and code; verify behavior by running the procedure.
4. Keep earlier-version reference material distinguishable from current instructions.
5. Record the source revision when reviewing a page. Update the documentation with the corresponding code change.
6. Keep TR4W as the product name. Lead with cross-platform contest logging and TRLOG heritage; keep the historical Windows expansion out of prominent product copy. Qualify native platform availability by release.

## Gaps this experiment exposed

- This version runs natively on Windows, macOS, and Linux; project-owner clarification confirms macOS operation. Older public copy must not obscure that platform support.
- The wiki's INI-oriented setup needs reconciliation with the current settings store.
- The local keyboard inventory dates from April 2026. The selected keyboard page now uses the current accelerator table; a full context-sensitive key audit remains open.
- Proposal files such as `NETWORK_LOG_AUTO_SYNC.md` describe intended changes, not proof of implemented behavior.
- Backup and export now have source-checked procedures. Hands-on migration, backup, recovery, and export checks remain open.
- Language review policy changed after the translator guide: this testing build includes fuzzy UI text unless built with `-ReviewedOnly`.
- Current path code places native Unix contest files in `~/tr4w`; the older Linux installation paragraph locating them beside the binary is stale.
