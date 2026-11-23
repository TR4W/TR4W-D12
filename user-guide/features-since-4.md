# What's new since TR4W 4.x

This page compares the Windows 4.x edition described on the TR4W website with **TR4W 5.1.0**. The keyboard-driven workflow, band map, SO2R, POTA, CW keying, WSJT-X, and Cabrillo and ADIF exports were already part of 4.x. [TR4W 4.x features](https://tr4w.net/whytr4w.html)

## What changes when you upgrade

| Area | What you get in 5.1.0 |
| --- | --- |
| Operating systems | Native builds for Windows, macOS, and Linux. The Windows installer requires 64-bit Windows. [Install TR4W](start/install.md) |
| Contest logs | One SQLite database per contest, with verified snapshots, background periodic backups, and recovery from refused saves. [Back up your log](log/backup.md) |
| Station setup | Searchable Preferences, a first-run setup wizard, and reusable radio definitions and station profiles. Station settings use `tr4w.json`. [First-run setup](start/first-contest.md#complete-the-initial-station-setup) · [Preferences](start/preferences.md) |
| Multi-op | Protocol 5 requires a compatible server and updated clients. Stations catch up on missing contacts when they reconnect. [Upgrade a network](station/network.md) |
| Contest operation | Sort the contest picker by the next known date, choose rover locations from the call-window command menu, and review the station facts stored with each contact. [Pick a contest](start/first-contest.md#create-a-contest) · [Operate as a rover](operating/contests.md#operate-as-a-rover) |
| Integrations | Configure several external logging destinations, including Club Log and World Radio League, and optionally receive N1MM-style contact messages. [External loggers](station/external-loggers.md) · [N1MM-style input](station/wsjtx.md#receive-n1mm-style-log-messages) |

## Contests added since 4.x

The 4.x website lists **184 entries**. The 5.1.0 guide lists **213 contest identifiers**, including **29 additions** below. Website labels can differ from the current identifiers. For example, look for **New England QSO Party** in 5.1.0 under `NEWEQP`. [4.x website contest list](https://tr4w.net/tr4w_contests.html) · [Complete 5.1.0 contest list](reference/contests.md)

### U.S. QSO parties

| QSO party | TR4W identifier |
| --- | --- |
| Alabama | `AL-QSO-PARTY` |
| Arkansas | `AR-QSO-PARTY` |
| Delaware | `DELAWARE QSO PARTY` |
| Georgia | `GA-QSO-PARTY` |
| Hawaii | `HI-QSO-PARTY` |
| Idaho | `IDAHO QSO PARTY` |
| Illinois | `IL-QSO-PARTY` |
| Iowa | `IA-QSO-PARTY` |
| Kansas | `KS-QSO-PARTY` |
| Kentucky | `KY-QSO-PARTY` |
| Louisiana | `LA-QSO-PARTY` |
| Mississippi | `MS-QSO-PARTY` |
| Nebraska | `NE-QSO-PARTY` |
| New Hampshire | `NH-QSO-PARTY` |
| New Jersey | `NJ-QSO-PARTY` |
| New Mexico | `NM-QSO-PARTY` |
| North Dakota | `ND-QSO-PARTY` |
| Oklahoma | `OK-QSO-PARTY` |
| South Carolina | `SC-QSO-PARTY` |
| South Dakota | `SD-QSO-PARTY` |
| Vermont | `VT-QSO-PARTY` |
| West Virginia | `WV-QSO-PARTY` |

### Canadian QSO parties

| QSO party | TR4W identifier |
| --- | --- |
| Atlantic Canada | `AC-QSO-PARTY` |
| Canadian Prairies | `CP-QSO-PARTY` |
| Ontario | `ON-QSO-PARTY` |
| Quebec | `QC-QSO-PARTY` |

### Digital and RTTY contests

| Contest | TR4W identifier |
| --- | --- |
| Russian WW Digital Contest | `RUS-WW-DIGI` |
| URC DX RTTY Contest | `URC-DX-RTTY` |
| Weekly RTTY Test | `WRT` |

Existing contests also have rules updates, including Winter Field Day, ARRL Sweepstakes, the RU3AX Memorial, and Florida QSO Party. [Check the contest rules and exchanges](operating/contests.md#contest-additions-through-510).

## Bring your station and logs forward

Keep a copy of your 4.x contest folder, including the `.CFG` and `.TRW` files, and test migration on that copy. Bring station settings from `tr4w.ini` in a separate step. Use the two guides to check the migrated settings, log, and a representative export before operating. [Migrate an existing contest](start/migration.md#try-an-older-contest-on-a-copy) · [Convert station settings](start/ini-to-json.md)
