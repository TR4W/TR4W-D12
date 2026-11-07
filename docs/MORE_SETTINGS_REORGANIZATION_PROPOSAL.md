# Retire the More settings placeholder

> **STATUS, 2026-11-06: DONE (issue 235, stages 1 and 2, not yet committed at
> the time of writing).** More settings and tag 30 are removed. Every setting
> below is placed by `uPrefsForm.PrefsPlacements`, which is the authority on
> where a setting is shown now; this document is the reasoning behind it, not
> a current map. Where the implementation differs from the table below, the
> reason is a comment on that line in `DeclarePrefsPlacements`. In short:
>
> - CW has ONE home (NY4I), so Operating > CW became CW Settings > While operating.
> - The "Logging" destinations went elsewhere, because the Logging page is
>   TR4W's diagnostic log: the time settings and LOG FREQUENCY ENABLE went to
>   Entry and dupe checking, and DISTANCE MODE went to Log display.
> - IE SWITCH went to Band Map (NY4I).
> - STEREO PIN HIGH went to Hardware (NY4I).
> - LOG SUB TITLE and CONTACTS PER PAGE went to Contest > Printed log (NY4I).
> - TUNE ALT-D ENABLE went to Two Radio Mode, because its help text describes SO2R.
> - QZB RANDOM OFFSET ENABLE went to Band Map > Window and tuning, with the four
>   band map settings: it is a spot-tune offset, and the Band Map page is full.
> - CALLSIGN UPDATE ENABLE and COMPLETE CALLSIGN MASK went to Entry, because both
>   are about typing.
> - SHOW TYPED CALLSIGN and ALLOW AUTO UPDATE went to Network, because their help
>   names the network.
> - MISSINGCALLSIGNS FILE ENABLE went to Audio (it is a DVK setting).
> - The DX Cluster settings went to a DX Cluster > Spots and console leaf, because
>   the designed page is full.
> - ~~FREQUENCY POLL RATE is on Hardware TEMPORARILY. It moves to each radio's
>   definition in step 3.~~ DONE (step 3, 2026-11-06): it is
>   `TRadioDefinition.FrequencyPollRate`, edited on the radio editor's Advanced
>   tab; the Hardware row is gone and the command name is store-owned.
> - The band plan button is on Operating > Bands.

Proposal and implementation handoff, November 6, 2026. Reviewed against main at commit 3c0cdede and the working-tree sources available during review. This is documentation only; no application code, settings data, tests, or navigation have been changed.

## Recommendation

Remove More settings after every setting and its band-plan editor action has a real home. Group controls by the operator's task, not by their old Ctrl-J history. Keep the existing stored keys, legacy command names, scope, validation, effects and restart behavior. Moving a control should not require users to migrate their configuration.

Use the existing binding and generated-row machinery where appropriate. Add focused leaves where a designed page has insufficient space; do not append dozens of controls below an existing fixed-height panel. The destinations below are proposed UI placements, not implemented pages or changes to station/contest scope.

## Verified current behavior

- uPrefsForm.BuildGeneratedSections constructs NAV_MORE (tag 30), and BuildNavTree adds a top-level More settings node. The heading itself explicitly describes this as temporary.
- The holding page selects nine prefixes: operating.ctrlj., cw.ctrlj., appearance.ctrlj., hardware.ctrlj., files.ctrlj., bandmap.ctrlj., network.ctrlj., voice.ctrlj. and cluster.ctrlj. The declarations contain **71 settings across eight populated prefixes**. voice.ctrlj. has no matching registered declaration in the inspected source. Old category-count comments are stale; do not use them as inventory counts.
- AddGeneratedRows chooses controls from registry metadata, binds editable controls and displays read-only settings without binding them. DOMESTIC FILENAME is explicitly registered read-only. Keep that protection: saving display text is not a valid way to update every registry value.
- The page also owns a separate **Band plan (cutoff frequencies and memories) > Edit...** action, created specifically when AddGeneratedRows handles bandmap.ctrlj. It is not one of the 71 settings. Moving or replacing the row generator must preserve this action.
- BuildGeneratedSection creates a complete section under layContent; BuildGeneratedBlock adds rows to an existing panel. The latter sizes a plain host panel to its remaining height and does not provide a general scrolling layout. Its caller must account for overlap and overflow.
- Placement is currently selected by stored-key prefix. That couples navigation to persistence. Renaming keys just to move a control would introduce avoidable compatibility work.
- Existing examples show why prefix-only placement is insufficient: AskForFrequencies concerns cluster spots, FrequencyPollRate concerns radio polling, MainCallsign is the station's remembered callsign, and StationsCallsignsMask filters the multi-op stations window. Their declarations all currently use operating.ctrlj.

### Inventory totals

| Current prefix | Registered settings |
| --- | --- |
| `operating.ctrlj.` | 32 |
| `cw.ctrlj.` | 11 |
| `appearance.ctrlj.` | 10 |
| `hardware.ctrlj.` | 1 |
| `files.ctrlj.` | 8 |
| `bandmap.ctrlj.` | 4 |
| `network.ctrlj.` | 2 |
| `cluster.ctrlj.` | 3 |
| **Total** | **71** |

This is a source-registration inventory, not a runtime screenshot row count. It excludes the band-plan action, already separate appearance.layout.* settings, and deliberately non-UI settings outside the selected prefixes.

## Proposed destinations

Keep existing top-level pages and their familiar names. Add Operating > Entry and dupe checking for general input/dupe behavior; Appearance > Log display for the larger display group; CW Settings > Sending for character mappings and speed; and Files and updates for the six file/update settings not assigned to contest exchange or multiplier data. Names after an existing leaf below generally denote sections on that page, not an instruction to create another navigation node for every subsection.

Keep Operating > CW distinct from CW Settings: operating-time automatic sending and tune/dupe behavior belong under Operating; keying/character configuration belongs under CW Settings. Confirm this distinction with NY4I before implementing the new leaves. DE ENABLE controls a message prefix shared by sending modes, so do not hide it in a CW-only hardware page merely because the name is familiar to CW operators.

### operating (32)

| Stored key | Existing command / search term | Proposed destination |
| --- | --- | --- |
| `operating.ctrlj.askForFrequencies` | ASK FOR FREQUENCIES | DX Cluster |
| `operating.ctrlj.autoDisplayDupeQso` | AUTO DISPLAY DUPE QSO | Operating > Entry and dupe checking (new leaf) |
| `operating.ctrlj.autoDupeEnableCq` | AUTO DUPE ENABLE CQ | Operating > Entry and dupe checking (new leaf) |
| `operating.ctrlj.autoDupeEnableSAndP` | AUTO DUPE ENABLE S AND P | Operating > Entry and dupe checking (new leaf) |
| `operating.ctrlj.autoSPEnable` | AUTO S&P ENABLE | Operating > Entry and dupe checking (new leaf) |
| `operating.ctrlj.autoSPEnableSensitivity` | AUTO S&P ENABLE SENSITIVITY | Operating > Entry and dupe checking (new leaf) |
| `operating.ctrlj.autoTimeIncrement` | AUTO TIME INCREMENT | Logging > Time entry |
| `operating.ctrlj.band` | BAND | Operating > Bands |
| `operating.ctrlj.customUserString` | CUSTOM USER STRING | Appearance > Log display (new leaf) |
| `operating.ctrlj.deEnable` | DE ENABLE | Operating > Messages (new leaf; confirm shared CW/voice placement) |
| `operating.ctrlj.digitalModeEnable` | DIGITAL MODE ENABLE | Contest > Modes |
| `operating.ctrlj.distanceMode` | DISTANCE MODE | Logging > Distance display |
| `operating.ctrlj.dupeCheckSound` | DUPE CHECK SOUND | Audio > Alerts |
| `operating.ctrlj.dupeSheetAutoReset` | DUPE SHEET AUTO RESET | Operating > Entry and dupe checking (new leaf) |
| `operating.ctrlj.frequencyMemoryEnable` | FREQUENCY MEMORY ENABLE | Operating > Bands |
| `operating.ctrlj.frequencyPollRate` | FREQUENCY POLL RATE | Hardware > Radios > Polling (shared setting) |
| `operating.ctrlj.ieSwitch` | IE SWITCH | Contest > Initial exchange (confirm) |
| `operating.ctrlj.incrementTimeEnable` | INCREMENT TIME ENABLE | Logging > Time entry |
| `operating.ctrlj.logFrequencyEnable` | LOG FREQUENCY ENABLE | Logging |
| `operating.ctrlj.logSubTitle` | LOG SUB TITLE | Appearance > Log display (new leaf; no-live-reader review) |
| `operating.ctrlj.mainCallsign` | MAIN CALLSIGN | Station |
| `operating.ctrlj.mode` | MODE | Operating > Bands |
| `operating.ctrlj.possibleCallAcceptKey` | POSSIBLE CALL ACCEPT KEY | SCP > Suggested-call controls |
| `operating.ctrlj.possibleCallLeftKey` | POSSIBLE CALL LEFT KEY | SCP > Suggested-call controls |
| `operating.ctrlj.possibleCallMode` | POSSIBLE CALL MODE | SCP > Suggested-call controls |
| `operating.ctrlj.possibleCallRightKey` | POSSIBLE CALL RIGHT KEY | SCP > Suggested-call controls |
| `operating.ctrlj.qsxEnable` | QSX ENABLE | DX Cluster > Split information |
| `operating.ctrlj.qzbRandomOffsetEnable` | QZB RANDOM OFFSET ENABLE | Operating > CW |
| `operating.ctrlj.radiusOfEarth` | RADIUS OF EARTH | Advanced > Distance calculations |
| `operating.ctrlj.shiftKeyEnable` | SHIFT KEY ENABLE | Operating > Entry and dupe checking (new leaf) |
| `operating.ctrlj.stationsCallsignsMask` | STATIONS CALLSIGNS MASK | Network > Stations display |
| `operating.ctrlj.wakeUpTimeOut` | WAKE UP TIME OUT | Audio > Alerts |

### cw (11)

| Stored key | Existing command / search term | Proposed destination |
| --- | --- | --- |
| `cw.ctrlj.autoSendCharacterCount` | AUTO SEND CHARACTER COUNT | Operating > CW |
| `cw.ctrlj.codeSpeed` | CODE SPEED | CW Settings > Sending (new leaf) |
| `cw.ctrlj.questionMarkChar` | QUESTION MARK CHAR | CW Settings > Sending (new leaf) |
| `cw.ctrlj.short0` | SHORT 0 | CW Settings > Sending (new leaf) |
| `cw.ctrlj.short1` | SHORT 1 | CW Settings > Sending (new leaf) |
| `cw.ctrlj.short2` | SHORT 2 | CW Settings > Sending (new leaf) |
| `cw.ctrlj.short9` | SHORT 9 | CW Settings > Sending (new leaf) |
| `cw.ctrlj.shortIntegers` | SHORT INTEGERS | CW Settings > Sending (new leaf) |
| `cw.ctrlj.slashMarkChar` | SLASH MARK CHAR | CW Settings > Sending (new leaf) |
| `cw.ctrlj.startSendingNowKey` | START SENDING NOW KEY | Operating > CW |
| `cw.ctrlj.tuneAltDEnable` | TUNE ALT-D ENABLE | Operating > Entry and dupe checking (new leaf) |

### appearance (10)

| Stored key | Existing command / search term | Proposed destination |
| --- | --- | --- |
| `appearance.ctrlj.beepEnable` | BEEP ENABLE | Audio > Alerts |
| `appearance.ctrlj.columnAutosize` | COLUMN AUTOSIZE | Appearance > Log display (new leaf) |
| `appearance.ctrlj.completeCallsignMask` | COMPLETE CALLSIGN MASK | Appearance > Log display (new leaf) |
| `appearance.ctrlj.contactsPerPage` | CONTACTS PER PAGE | Appearance > Log display (new leaf) |
| `appearance.ctrlj.hourDisplay` | HOUR DISPLAY | Appearance > Log display (new leaf) |
| `appearance.ctrlj.insertMode` | INSERT MODE | Operating > Entry and dupe checking (new leaf) |
| `appearance.ctrlj.rateDisplay` | RATE DISPLAY | Appearance > Log display (new leaf) |
| `appearance.ctrlj.showFrequencyInLog` | SHOW FREQUENCY IN LOG | Appearance > Log display (new leaf) |
| `appearance.ctrlj.showTypedCallsign` | SHOW TYPED CALLSIGN | Appearance > Log display (new leaf) |
| `appearance.ctrlj.userInfoShown` | USER INFO SHOWN | Appearance > Log display (new leaf) |

### hardware (1)

| Stored key | Existing command / search term | Proposed destination |
| --- | --- | --- |
| `hardware.ctrlj.stereoPinHigh` | STEREO PIN HIGH | Operating > Two Radio Mode |

### files (8)

| Stored key | Existing command / search term | Proposed destination |
| --- | --- | --- |
| `files.ctrlj.allowAutoUpdate` | ALLOW AUTO UPDATE | Files and updates (new page) |
| `files.ctrlj.callsignUpdateEnable` | CALLSIGN UPDATE ENABLE | Files and updates (new page) |
| `files.ctrlj.countryInformationFile` | COUNTRY INFORMATION FILE | Files and updates (new page) |
| `files.ctrlj.ctyUpdateCheckOnStartup` | CTY UPDATE CHECK ON STARTUP | Files and updates (new page) |
| `files.ctrlj.domesticFilename` | DOMESTIC FILENAME | Contest > Multiplier data (read-only) |
| `files.ctrlj.missingcallsignsFileEnable` | MISSINGCALLSIGNS FILE ENABLE | Files and updates (new page) |
| `files.ctrlj.unknownCountryFileName` | UNKNOWN COUNTRY FILE NAME | Files and updates (new page) |
| `files.ctrlj.initialExchangeFilename` | INITIAL EXCHANGE FILENAME | Contest > Initial exchange |

### bandmap (4)

| Stored key | Existing command / search term | Proposed destination |
| --- | --- | --- |
| `bandmap.ctrlj.bandMapItemHeight` | BAND MAP ITEM HEIGHT | Operating > Band Map |
| `bandmap.ctrlj.bandMapItemWidth` | BAND MAP ITEM WIDTH | Operating > Band Map |
| `bandmap.ctrlj.bandMapSize` | BAND MAP SIZE | Operating > Band Map |
| `bandmap.ctrlj.bandMapSplitMode` | BAND MAP SPLIT MODE | Operating > Band Map |

### network (2)

| Stored key | Existing command / search term | Proposed destination |
| --- | --- | --- |
| `network.ctrlj.computerName` | COMPUTER NAME | Network |
| `network.ctrlj.netStatusUpdateInterval` | NET STATUS UPDATE INTERVAL | Network |

### cluster (3)

| Stored key | Existing command / search term | Proposed destination |
| --- | --- | --- |
| `cluster.ctrlj.broadcastAllPacketData` | BROADCAST ALL PACKET DATA | DX Cluster |
| `cluster.ctrlj.consoleLines` | TELNET CONSOLE LINES | DX Cluster |
| `cluster.ctrlj.spotCommentMultiplier` | CLUSTER SPOT COMMENT MULTIPLIER | DX Cluster |

## Placements and semantics requiring care

1. **Station identity:** MainCallsign is deliberately separate from the callsign being operated. The inspected model says the remembered station value prefills New Contest; a contest override does not replace it. Put both on the appropriate screens with clear labels rather than consolidating their values.
2. **Scope:** DIGITAL MODE ENABLE is contest-scoped in the settings inventory. A Files setting moved onto Contest, or a station-wide setting placed near contest controls, must retain its actual persistence scope. Do not infer storage scope from its page title.
3. **Shared radio polling:** ~~FrequencyPollRate is currently one Operating model property. Moving it near radios must not silently turn it into one value per radio definition. Its help text must explain the existing scope.~~ SUPERSEDED by NY4I's ruling on issue 235 ("This should go on the radio definition"): it IS one value per radio definition now, deliberately, each seeded once from the old station-wide value, and its help says it is per radio.
4. **Initial exchange:** The model identifies IE SWITCH as an initial-exchange behavior read by uSpots. Confirm the actual user-facing explanation and desired placement before relabeling it. The table proposes grouping it beside INITIAL EXCHANGE FILENAME; it does not assume those settings have the same storage scope.
5. **Log subtitle:** The inspected model explicitly says LogSubTitle has no live reader in this build. Record this as a separate behavior/retirement decision. A navigation cleanup must not silently remove it or claim that changing it currently updates the window title.
6. **Stereo and messages:** The registration comment associates STEREO PIN HIGH with YCCC stereo behavior. Confirm whether the operator expects this beside Two Radio Mode or its hardware definition. DE ENABLE's shared sending semantics likewise need a clear group before implementation.
7. **Internal parameters:** RADIUS OF EARTH is proposed for Advanced rather than normal operating controls. Keep the option reachable; moving it is not authorization to change its validation or remove it.
8. **No empty Voice leaf:** There are no matching voice.ctrlj. declarations in the current inventory. Do not create a blank page from the obsolete prefix list.

## Implementation plan for a worktree

1. Capture the then-current baseline and coordinate with any concurrent Preferences work. At review time, main already had unrelated uncommitted changes in the external-logger grid, several tests and the test runner. Do not overwrite or stage those changes with this work.
2. Create a compact UI-placement definition that maps an existing setting key to one destination and an optional group/order. Prefer explicit registry/UI metadata or one UI-owned table over scattered per-command branches. Reuse the same placement decision for construction and search; do not create independent routing tables that can drift.
3. Keep persisted keys and legacy command spellings unchanged. Existing prefix-based generated pages can remain the default for unaffected settings; the formerly held settings need explicit placement. Do not add a new dependency or redesign the settings model for this.
4. Build the smallest needed designed containers/leaves, reusing the binding/control construction already present. Where a control already exists, bind one editor to that setting and remove the obsolete generated copy. Multiple editable bindings to one value are a suspected defect, not a migration strategy.
5. Move one coherent group at a time, checking scrolling, labels, keyboard order, help and search before proceeding. Preserve allowed-value combos, numeric limits, read-only display, dirty marking, Save and Cancel behavior, effects and per-setting restart notices.
6. Give the band-plan editor an explicit home under Operating > Bands, with a link from Band Map if useful. Share its existing handler; do not duplicate the editor or its persistence. Confirm that generated search indexes the action at its new section.
7. Remove NAV_MORE and its tree node only after the complete inventory and action have destinations. Remove stale placeholder comments/headings. Do not reuse tag 30 casually: first check all navigation/tag consumers and lint expectations.
8. Update current architecture/navigation documentation and any live bench instructions that direct an operator to More settings. Preserve historical results as history rather than rewriting their outcomes. The existing BENCH_QUEUE entry naming the band-plan action needs particular attention; coordinate with its current editor.

The suggested small abstraction separates **UI location** from **stored identity**. The tradeoff is an explicit placement definition to maintain. A completeness check is necessary so adding a setting cannot silently leave it inaccessible. Renaming dozens of stored keys solely to move their controls is not recommended.

## Validation and acceptance

### Automated checks

- Every one of the 71 inventoried keys has exactly one intended editor or read-only display. Reconcile this inventory against runtime registration before implementation; declarations can change while the proposal is pending.
- A mapped key must resolve in the setting registry, a destination must exist, and duplicate placements/bindings must fail validation. Check the band-plan action separately because it is not a setting.
- Search by both the current caption and old Ctrl-J command opens the new destination and focuses its control. Existing uTestPrefsSearch covers ranking, not full UI placement or binding completeness; extend coverage at the actual routing boundary rather than assuming those ranking tests prove navigation.
- Load old settings JSON without renaming keys; save/reload representative values from each former group. Verify allowed-value lists, numeric validation and read-only fields. Cancel must not persist changed settings.
- Run the relevant form-field, tag, overlap, tab-order, search-index, LFM property and real LCL streaming checks, and an application build. The existing static search-index lint covers designed controls; runtime-generated routing needs its own meaningful coverage.

### Operator checks

- More settings is gone; all listed settings are reachable in their task pages.
- Every visible page fits at the supported minimum size and representative Windows DPI/font scaling. Use scrolling where appropriate; no horizontal scrollbar merely to reach the value field, no clipped heading, and no controls hidden below the panel.
- Tab order follows reading order. Labels and help explain abbreviated legacy names while legacy spellings remain searchable.
- Files and updates, radio polling, dupe checking, character mappings, station identity and log-display options can each be found without knowing their former Ctrl-J grouping.
- The band-plan editor remains reachable and opens the same existing editor. Its different whole-section save behavior remains explicit.
- Save, Save and close, Cancel and restart notices match actual behavior; moving a page introduces no new restart requirement.

No build, full test suite or application launch is required for this documentation-only task. Implementation and its validation belong in a worktree after the grouping is reviewed.

## Evidence reviewed

- [uPrefsForm.pas](../tr4w/src/ui/lcl/uPrefsForm.pas): BuildGeneratedSections, BuildGeneratedSection, BuildGeneratedBlock, AddGeneratedRows, GeneratedBandPlanClick and BuildNavTree.
- [uPrefsForm.lfm](../tr4w/src/ui/lcl/uPrefsForm.lfm): designed Preferences panels.
- [uSettingsDeclarations.pas](../tr4w/src/uSettingsDeclarations.pas): all 71 selected registrations and read-only domestic filename.
- [uSettingsModel.pas](../tr4w/src/uSettingsModel.pas): operating, station identity, message, QSX, QZB and stations-filter semantics.
- [uSettingsCaptions.pas](../tr4w/src/uSettingsCaptions.pas): current caption vocabulary.
- [SETTINGS_INVENTORY.md](../tr4w/docs/SETTINGS_INVENTORY.md): existing command/model and station/contest-scope reference; generated columns should not be hand-edited.
- [uTestPrefsSearch.pas](../tr4w/test/unit/uTestPrefsSearch.pas): existing search-ranking test boundary.
- [BENCH_QUEUE.md](BENCH_QUEUE.md): existing band-plan bench instructions referencing the placeholder.
