# TR4W Issue Analysis and Work Planning

> Original analysis 2026-03-14 · Tracker snapshot **2026-11-23**
>
> [Code snapshot `d9ba0e527`](https://github.com/TR4W/TR4W-D12/commit/d9ba0e527) · [April 2026 analysis](https://github.com/TR4W/TR4W-D12/blob/72ed5ed90dc83dc016d0ca26f8e6cb5f60caa838/TR4W_ISSUE_ANALYSIS.md)

## Current trackers

| Repository | Open issues | Latest GitHub release | Scope |
| --- | ---: | --- | --- |
| [TR4W/TR4W](https://github.com/TR4W/TR4W/issues?q=is%3Aissue+is%3Aopen) (D7) | 1 | [4.153.1](https://github.com/TR4W/TR4W/releases/tag/v4.153.1-all) | Original Delphi 7 / Windows line |
| [TR4W/TR4W-D12](https://github.com/TR4W/TR4W-D12/issues?q=is%3Aissue+is%3Aopen) (D12) | 180 | [5.1.0](https://github.com/TR4W/TR4W-D12/releases/tag/v5.1.0) | Current Free Pascal/Lazarus line for Windows, macOS and Linux |

D7’s only open issue, #224, was reopened. Its scoring question also has an open D12 ticket. Confirm whether clearing the multiplier sheet between Ukraine Championship tours should preserve points already earned from multipliers. The D12 ticket records the current behavior and the proposed contest-specific change. [D7 #224](https://github.com/TR4W/TR4W/issues/224) · [D12 #164](https://github.com/TR4W/TR4W-D12/issues/164#issuecomment-6891006076)

D12 has 63 open issues labelled `Requires Testing`, 19 labelled `New Contest Request`, and 6 labelled `Triaged`. Labels can overlap. Apply `Triaged` after individual analysis and a recommendation in the issue comments. [Requires Testing](https://github.com/TR4W/TR4W-D12/issues?q=is%3Aissue+is%3Aopen+label%3A%22Requires+Testing%22) · [New Contest Request](https://github.com/TR4W/TR4W-D12/issues?q=is%3Aissue+is%3Aopen+label%3A%22New+Contest+Request%22) · [Triaged](https://github.com/TR4W/TR4W-D12/issues?q=is%3Aissue+is%3Aopen+label%3ATriaged) · [Bench queue](docs/BENCH_QUEUE.md)

## What changed since April

Of the 103 distinct legacy issue links in the April file, 80 now resolve to closed D7 issues and 23 resolve to transferred D12 issues. Ten of those transfers are still open. D7 closures include 42 marked **Completed** and 38 marked **Not planned**. Some D7 closures have separately filed D12 successors, including band-map navigation and DXLab Commander. [D7 closed issues](https://github.com/TR4W/TR4W/issues?q=is%3Aissue+is%3Aclosed) · [D12 #202](https://github.com/TR4W/TR4W-D12/issues/202) · [D12 #172](https://github.com/TR4W/TR4W-D12/issues/172)

| April item | Current disposition |
| --- | --- |
| [D7 #688](https://github.com/TR4W/TR4W/issues/688), band-map flicker | Closed after the band-map repaint change merged. [PR #869](https://github.com/TR4W/TR4W/pull/869) |
| [D7 #383](https://github.com/TR4W/TR4W/issues/383), lost radio connection | Closed. The recorded behavior is that the main frequency display changes to the configured alert colour. [Closure comment](https://github.com/TR4W/TR4W/issues/383#issuecomment-4253354039) |
| [D7 #719](https://github.com/TR4W/TR4W/issues/719), SQLite contest log | Transferred and closed. D12 uses SQLite for contest logs. Restore UI and full-disk checks remain tracked separately. [D12 #9](https://github.com/TR4W/TR4W-D12/issues/9) · [Log schema](docs/LOG_SCHEMA.md) |
| [D7 #87](https://github.com/TR4W/TR4W/issues/87), section suggestions | Transferred and closed as Completed. [D12 #63](https://github.com/TR4W/TR4W-D12/issues/63) |
| [D7 #736](https://github.com/TR4W/TR4W/issues/736) and [D7 #766](https://github.com/TR4W/TR4W/issues/766), HRD support and external-logger edit exception | Both closed as Completed in D7. AC Log still has a separate D12 verification item. [D12 #33](https://github.com/TR4W/TR4W-D12/issues/33) |
| K4, Yaesu, POTA and housekeeping | K4 CW speed sync and band-map split reset, both FTX-1F tickets, the POTA parser ticket, and the accidental merge incident are closed in D7. [#800](https://github.com/TR4W/TR4W/issues/800) · [#703](https://github.com/TR4W/TR4W/issues/703) · [#817](https://github.com/TR4W/TR4W/issues/817) · [#778](https://github.com/TR4W/TR4W/issues/778) · [#877](https://github.com/TR4W/TR4W/issues/877) · [#396](https://github.com/TR4W/TR4W/issues/396) |

### Transferred issues still open

| Original | D12 issue | Current focus |
| --- | --- | --- |
| [D7 #121](https://github.com/TR4W/TR4W/issues/121) | [D12 #61](https://github.com/TR4W/TR4W-D12/issues/61) | Icom switches from CQ to S&P after F1 in split. The IC-7760 bench did not reproduce it. Repeat on an IC-718 or IC-7610. |
| [D7 #735](https://github.com/TR4W/TR4W/issues/735) | [D12 #33](https://github.com/TR4W/TR4W-D12/issues/33) | AC Log TCP delivery is implemented and loopback-tested. Verify that a real AC Log instance stores and displays the contact. |
| [D7 #789](https://github.com/TR4W/TR4W/issues/789) | [D12 #58](https://github.com/TR4W/TR4W-D12/issues/58) | Review the remaining 2025 RSGB contest changes. |
| [D7 #810](https://github.com/TR4W/TR4W/issues/810) | [D12 #52](https://github.com/TR4W/TR4W-D12/issues/52) | Grid lookup is in 5.1.0. Verify WSJT-X logging for a grid in one state and a grid spanning multiple states. |
| [D7 #818](https://github.com/TR4W/TR4W/issues/818) | [D12 #51](https://github.com/TR4W/TR4W-D12/issues/51) | PCC and Arktika Spring now supply custom prompt labels. Check those prompts in the New Contest dialog. |
| [D7 #835](https://github.com/TR4W/TR4W/issues/835) | [D12 #49](https://github.com/TR4W/TR4W-D12/issues/49) | Band-map click now calls the UDP lookup routine. Confirm DXView receives the selected callsign. |
| [D7 #844](https://github.com/TR4W/TR4W/issues/844) | [D12 #47](https://github.com/TR4W/TR4W-D12/issues/47) | RigSelect Pro support is on hold. |
| [D7 #852](https://github.com/TR4W/TR4W/issues/852) | [D12 #31](https://github.com/TR4W/TR4W-D12/issues/31) | Icom network implementation request for the IC-7700. |
| [D7 #856](https://github.com/TR4W/TR4W/issues/856) | [D12 #6](https://github.com/TR4W/TR4W-D12/issues/6) | Polymorphic keepalive for factory radios remains open. |
| [D7 #871](https://github.com/TR4W/TR4W/issues/871) | [D12 #29](https://github.com/TR4W/TR4W-D12/issues/29) | WinKeyer source review found one space in both paths. Compare logged send timing and actual keying at the reported speed. |

## Work planning

### Multi-op and log recovery

- **Restock responsiveness.** The 5.1.0 gate measured about 12 seconds on the main thread for 5,000 QSOs. The posting loop reads each committed row again to construct the wire message. Measure planning and posting separately. Verify that an interrupted restock can replan on reconnect and send only what the server lacks. [D12 #381](https://github.com/TR4W/TR4W-D12/issues/381) · [Restock code](tr4w/src/uNet.pas#L3767)
- **Protocol follow-ups.** 5.1.0 requires protocol 5 at every station and on the server. The wire schema includes `rcvd_year`. Review the older variable-length and mixed-version issues against that contract and verify EUHFC/KVP year multipliers through catch-up. Shared settings, intercom and spots have their own length-limit issue. [5.1.0 upgrade notes](RELEASE_NOTES.md#before-upgrading) · [Wire columns](tr4w/src/uQsoColumns.pas#L152) · [D12 #360](https://github.com/TR4W/TR4W-D12/issues/360) · [#379](https://github.com/TR4W/TR4W-D12/issues/379) · [#315](https://github.com/TR4W/TR4W-D12/issues/315)
- **Durability and restore.** Commit-before-publish, atomic saves for multi-leg QSOs, background periodic backups and the server SQLite change are recorded as complete. Run the full-disk and missing-disk bench cases for the station log, server and exports. The restore engine is in place and the operator-facing Restore button is open. [5.1.0 developer notes](CHANGES.md#log-durability-and-commit-before-publish-ulogrepository-ulogstore-mainunit-ulogbackup---issues-347-348-349-350-351) · [D12 #341](https://github.com/TR4W/TR4W-D12/issues/341) · [#311](https://github.com/TR4W/TR4W-D12/issues/311) · [#313](https://github.com/TR4W/TR4W-D12/issues/313) · [#314](https://github.com/TR4W/TR4W-D12/issues/314) · [#242](https://github.com/TR4W/TR4W-D12/issues/242)

### Contest rules, scoring and exports

- **Cabrillo.** Jock White Field Day’s QSO columns are implemented and its issue is closed. ALL JA has QSO columns on main, with the Preferences and Edit QSO layouts and the DXLog `RCVD2` interpretation still open. Use sponsor formats for the remaining exchange issues and extend the pin tables to contests registered by ID. [D12 #368](https://github.com/TR4W/TR4W-D12/issues/368) · [#361](https://github.com/TR4W/TR4W-D12/issues/361#issuecomment-7116964162) · [#376](https://github.com/TR4W/TR4W-D12/issues/376) · [Open Cabrillo issues](https://github.com/TR4W/TR4W-D12/issues?q=is%3Aissue+is%3Aopen+label%3ACabrillo)
- **Scoring decisions.** Settle clear-multiplier behavior for Ukraine Championship tours and resolve the KVP sent-year multiplier, permitted band and modes, and Cabrillo name. Check the county-plus-host-state multiplier in both the score and per-QSO reports. [D12 #164](https://github.com/TR4W/TR4W-D12/issues/164) · [#378](https://github.com/TR4W/TR4W-D12/issues/378) · [#317](https://github.com/TR4W/TR4W-D12/issues/317) · [#318](https://github.com/TR4W/TR4W-D12/issues/318)
- **Digital modes.** The proposal is to retain the actual mode for the QSO and preserve the Digital category for scoring and totals. Review compatibility across stored logs, ADIF, Cabrillo and multi-op before changing the representation. [D12 #377](https://github.com/TR4W/TR4W-D12/issues/377) · [Design proposal](docs/DIGITAL_SUBMODES_DESIGN.md)

### Operator and hardware checks

- **Radio and keying.** Use the bench queue for Commander, Ten-Tec Alt-M, Icom split and WinKeyer timing. Record the rig, firmware, connection type, TR4W build and relevant trace with each result. [D12 #172](https://github.com/TR4W/TR4W-D12/issues/172) · [#181](https://github.com/TR4W/TR4W-D12/issues/181) · [#61](https://github.com/TR4W/TR4W-D12/issues/61) · [#29](https://github.com/TR4W/TR4W-D12/issues/29) · [Bench queue](docs/BENCH_QUEUE.md)
- **UI checks.** Exercise band-map Next when a tune is refused and decide whether Next should fill the selected call’s initial exchange. Check that `NO COLUMN HEADER` applies in the running app and verify the setup wizard’s new integration pages before closing those tickets. [D12 #202](https://github.com/TR4W/TR4W-D12/issues/202) · [#352](https://github.com/TR4W/TR4W-D12/issues/352) · [#334](https://github.com/TR4W/TR4W-D12/issues/334)

The tracker snapshot records issue state and selected code, release and bench evidence. Bench and hardware outcomes above come from the linked records.
