# D7 settings parity: can every setting D7's Options window could change be changed in TR4W 5.x?

Read-only audit, 2026-11-26, for NY4I's question *"let's check the ones we could set in D7"*. Nothing was
built or run; every finding below is read from source. D7 = `C:\TR4W\tr4w\src`, 5.x = `C:\tr4w-d12\tr4w\src`.

## Counts

Scope: 307 `CFGCA` rows the D7 Options windows could actually CHANGE, plus the 101 rows of the D7 Colours window
(50 elements x colour/background, plus ALERT COLOR) = **408**.

| status | meaning | CFGCA rows | Colours window | total |
|---|---|---|---|---|
| A | designed control (Preferences or a library editor) | 126 | 100 | 226 |
| B-visible | generated row on a visible generated page | 83 | 0 | 83 |
| B-hidden | generated row in a BuildPlacedBlock host (currently invisible) | 20 | 0 | 20 |
| C | no UI; only a contest `.cfg` import (or hand-editing tr4w.json) | 0 | 1 | 1 |
| D-store | name accepted, value lives in a store/library with its own editor | 57 | 0 | 57 |
| D-retired | RETIRED_COMMANDS | 19 | 0 | 19 |
| E | does not resolve in 5.x | 2 | 0 | 2 |
| | | 307 | 101 | **408** |

Of the 19 D-retired, 6 have a replacement under another name or mechanism (see the D table); 13 are gone.

## How D7 was counted

- **Ways into the window.** `MainUnit.pas:3440-3494` (D7): `menu_options` -> `RunOptionsDialog(cfAll)`,
  `menu_appearance` -> `cfAppearance`, `menu_colors` -> `cfCol`, `menu_winkeyer2` -> `cfWK`. `cfRadio1`/`cfRadio2`
  are never opened (`RunOptionsDialog(cfRadio1)` is commented out at :3479; Radio 1/2 use the CAT dialog), so
  their 40 rows are OUT of scope. `SetCommand` (:8461) opens `menu_options` pre-selected on a row; same list.
- **Listed.** `uOption.CommandsToListView2` (uOption.pas:376-382): `crS <> csRem`, `crType` in the 19-type set,
  `cfFunc = CommandsFilter`. `cfCol` is a separate branch (:316-374): one COLOR and one BACKGROUND row per
  `TMainWindowElement`, plus ALERT COLOR.
- **Changeable.** `ChangeValue2` (:483-787), reached by double-click (`NewSLVProc`, NM_DBLCLK, :853) or the default
  button. It `Exit`s on `crJ = 2` (:570) and only has arms for `crKind` ckArray/ckList or `crType` in a 14-type
  set (:572-574) -- so `ctMessage`, `ctPortLPT` and ckNormal `ctOther`/`ctBand` rows were SHOWN but could not be
  changed (crJ 2/3 rows are drawn grey, :869). 378 rows were listed in the three menus; 307 changeable; 71 shown
  but not changeable (appendix 3).
- **Parser** (`scratchpad\parse_d7.py`): strips `{ }`, `(* *)` and `//` comments while respecting Pascal string
  literals, then reads each `(crCommand: ...)` record of `CFGCA`. Enum names are compared case-insensitively
  (the table spells `csoLD`, `ctFilename`, `ctinteger`). **484 rows**; 17 commented-out `crCommand` lines skipped.
- **Cross-check**: the compiler's own count. `CommandsArraySize` (uCFG.pas:334-366) sums to **484**, and
  `array[1..CommandsArraySize]` would not compile with any other row count.

## How 5.x was resolved

In the order `CheckCommand` (uCFG.pas:1628) uses: `TryApplyCommandAction` (4 actions), `Settings.OwnsCommand`
(published properties, names derived from the path or aliased -- taken from `tools/settings_inventory.collect()`,
which checks itself against the frozen vocabulary), `RETIRED_COMMANDS` (uCFG.pas:1089), `OWNED_BY_A_STORE`
(:1352) and the radio-library key shape (`CommandIsRadioLibraryKey`, :1461). The UI side: registrations in
`uSettingsDeclarations.pas` (`RegisterModelSetting`/`RegisterStoredSetting`), `FBindings.Bind` in
`uPrefsForm.BuildBindings` (:7546), `DeclarePrefsPlacements` (:1801-2080), the `contest.`/`advanced.` prefix pages
(:3934-3937), the hand-wired list (`AddHandWiredToSearchIndex`, :5365-5501) and the library editors
(`uKeyerEditForm`, `uRadioEditForm`, `uUDPDestinationEditForm`, the Rotators and DX Cluster pages, `uBandPlanForm`).
A setting existing in `uSettingsModel` was never taken as "has UI"; a control or a placement was required.

**Gating.** No `{$IFDEF}` or platform test in `DeclarePrefsPlacements`, `uSettingsDeclarations` or `BuildBindings`,
and `AddPlacedRows` filters only by page. The one runtime gate found: the four external-logger fields redirect to
the library's Add button when `FStore.ExternalLoggers.Present` (uPrefsForm.pas:5311-5317).

## B-hidden: every setting in a BuildPlacedBlock host (all of them, not only D7's)

The block host is `NewGeneratedBlock` (uPrefsForm.pas:4675): `Width := aParent.ClientWidth` at creation, anchored
`[akLeft, akTop]` only, so it does not follow the page. The 150 px width and commit ed88a6b7e are from the brief;
**I did not measure it.** Nine pages call `BuildPlacedBlock` (:3963-3976); Station's placement list is empty.

| 5.x page | D7 window | command | key | D7 settable? |
|---|---|---|---|---|
| Audio | Options (cfAll) | BEEP ENABLE | `appearance.ctrlj.beepEnable` | yes |
| Audio | Options (cfAll) | MISSINGCALLSIGNS FILE ENABLE | `files.ctrlj.missingcallsignsFileEnable` | yes |
| Audio | Options (cfAll) | DUPE CHECK SOUND | `operating.ctrlj.dupeCheckSound` | yes |
| Audio | Options (cfAll) | WAKE UP TIME OUT | `operating.ctrlj.wakeUpTimeOut` | yes |
| Band Map | Options (cfAll) | IE SWITCH | `operating.ctrlj.ieSwitch` | yes |
| Bands | Options (cfAll) | BAND | `operating.ctrlj.band` | shown, read-only (crJ=2) |
| Bands | Options (cfAll) | FREQUENCY MEMORY ENABLE | `operating.ctrlj.frequencyMemoryEnable` | yes |
| Bands | Options (cfAll) | MODE | `operating.ctrlj.mode` | yes |
| Hardware | Options (cfAll) | STEREO PIN HIGH | `hardware.ctrlj.stereoPinHigh` | yes |
| Network | Options (cfAll) | SHOW TYPED CALLSIGN | `appearance.ctrlj.showTypedCallsign` | yes |
| Network | Options (cfAll) | ALLOW AUTO UPDATE | `files.ctrlj.allowAutoUpdate` | yes |
| Network | Options (cfAll) | COMPUTER NAME | `network.ctrlj.computerName` | yes |
| Network | Options (cfAll) | NET STATUS UPDATE INTERVAL | `network.ctrlj.netStatusUpdateInterval` | yes |
| Network | - | NETWORK HTTP TRANSPORT | `network.httpTransport` | no D7 row |
| Network | Options (cfAll) | STATIONS CALLSIGNS MASK | `operating.ctrlj.stationsCallsignsMask` | yes |
| SCP | Options (cfAll) | POSSIBLE CALL ACCEPT KEY | `operating.ctrlj.possibleCallAcceptKey` | yes |
| SCP | Options (cfAll) | POSSIBLE CALL LEFT KEY | `operating.ctrlj.possibleCallLeftKey` | yes |
| SCP | Options (cfAll) | POSSIBLE CALL MODE | `operating.ctrlj.possibleCallMode` | yes |
| SCP | Options (cfAll) | POSSIBLE CALL RIGHT KEY | `operating.ctrlj.possibleCallRightKey` | yes |
| Two-radio | Options (cfAll) | TUNE ALT-D ENABLE | `cw.ctrlj.tuneAltDEnable` | yes |
| WSJT-X | - | N1MM LISTEN ADDRESS | `wsjtx.n1mmListenAddress` | no D7 row |
| WSJT-X | - | ENABLE N1MM LOG LISTENER | `wsjtx.n1mmListenerEnabled` | no D7 row |
| Bands | Options (cfAll) | BAND MAP CUTOFF FREQUENCY | band plan editor, via the Edit... button `AddBandPlanRow` puts in the same host (:3977, :4796) | yes |
| Bands | Options (cfAll) | FREQUENCY MEMORY | same Edit... button | yes |

The band plan editor (`uBandPlanForm`) has no other entry: its only caller is `GeneratedBandPlanClick`
(uPrefsForm.pas:4749); D7's `menu_bandplan` is commented out in 5.x MainUnit.pas:6011. So 20 D7-settable
settings are hidden (18 rows + the 2 band-plan ones), plus BAND (read-only in D7) and three with no D7 row.

## C: no UI, only a contest `.cfg` import

In-session there is no command route for a settings-owned name: `CfgCmd` calls `CheckCommand(ID, CMD)` without
`aApplyJSONOwned` (trdos/CfgCmd.pas:125, :142), so an owned name is "accepted and inert" there (uCFG.pas:1713-1720).
The routes left are a contest `.cfg` read at open (`LogCfg`, `ApplyContestStatement`) and hand-editing tr4w.json.

| D7 window | command | 5.x | evidence |
|---|---|---|---|
| Colours (cfCol) | ALERT COLOR | `Settings.MainWindow.AlertColor`, registered `appearance.alertColor` | uSettingsDeclarations.pas:824. No `Bind`, no `Place`, not a generated-page prefix, and the Colours grid is filled from `TWindows` only (uPrefsForm.pas:4211-4222). `appearance.` is not a holding prefix, so `CheckEveryInventoriedSettingHasOneEditor` (:4003) never flags it. |

No `CFGCA` row the D7 Options window could change is in C: the four candidates the script first put there
(DEBUG LOG LEVEL, TELNET SERVER, ROTATOR TYPE/PORT, PSTROTATOR IP/UDP) all have a designed editor (appendix 1).

## E: does not resolve in 5.x

Each was searched for by name (case-insensitive, whole tree) and for a rename. Consequence, **read from code, not
observed**: `CheckCommand` returns False, so an old contest `.cfg` naming one goes to `LogCfg`'s refused-line path
(trdos/LogCfg.pas:1116 -> :1165, "Invalid statement in config file") -- unlike their siblings, which were put on
`RETIRED_COMMANDS` so they are accepted and ignored.

| D7 window | command | D7 row | what happened in 5.x |
|---|---|---|---|
| Options (cfAll) | SERIAL PORT DEBUG | uCFG.pas:780 (D7), `@CPUKeyer.SerialPortDebug`, ctBoolean | Withdrawn by NY4I ("TRACE covers it", uTestSettingsModel.pas:993) and taken OFF the retired list, so it is now refused. The comment at uProgramMain.pas:3415 still says it is "accepted, not applied" -- stale. |
| Options (cfAll) | STEREO CONTROL PIN | uCFG.pas:805 (D7), ckArray | Went with the parallel port 2026-09-13 (uCFG.pas:2185, uSettingsModel.pas:1871), but was not added with the six LPT names retired 2026-11-21 (uCFG.pas:1222-1237). Its companion STEREO PIN HIGH survives (B-hidden). |

Also unresolved but NOT changeable in D7 (shown, no edit arm): PADDLE PORT (ctPortLPT; removed with the LPT,
uSettingsDeclarations.pas:779). Same refusal consequence.

## D: retired, or owned by a store

### D-retired (19)

| D7 window | command | D7 crAddress | replaced by |
|---|---|---|---|
| Options (cfAll) | BAND MAP ENABLE | `@BandMapEnable` | nothing (feature withdrawn) |
| Options (cfAll) | COLUMN DUPESHEET ENABLE | `@ColumnDupeSheetEnable` | nothing (feature withdrawn) |
| Options (cfAll) | COUNTRY INFORMATION FILE | `@CountryInformationFile` | nothing; read by nothing here or in D7 (uCFG.pas:1216-1219) |
| Options (cfAll) | CUSTOM CARET | `@tr4w_CustomCaret` | nothing (feature withdrawn) |
| Options (cfAll) | FREQUENCY ADDER RADIO ONE | `@Radio1.FrequencyAdder` | radio editor `edtFreqOffset` (per radio) |
| Options (cfAll) | FREQUENCY ADDER RADIO TWO | `@Radio2.FrequencyAdder` | radio editor `edtFreqOffset` (per radio) |
| Options (cfAll) | INITIAL EXCHANGE | `Pointer(7)` | not an operator choice any more: the contest's class decides (M10 S2, uCFG.pas:1196-1215) |
| Options (cfAll) | MP3 PATH | `@TR4W_MP3PATH` | nothing (feature withdrawn) |
| Options (cfAll) | MP3 PLAYER | `@TR4W_MP3_PLAYER_FILENAME` | nothing (feature withdrawn) |
| Options (cfAll) | MP3 RECORDER BITRATE | `pointer(9)` | nothing (feature withdrawn) |
| Options (cfAll) | MP3 RECORDER DURATION | `pointer(41)` | nothing (feature withdrawn) |
| Options (cfAll) | MP3 RECORDER ENABLE | `@RecorderEnable` | nothing (feature withdrawn) |
| Options (cfAll) | MULTI INFO MESSAGE | `@MultiInfoMessage` | nothing (feature withdrawn) |
| Options (cfAll) | ORION PORT | `pointer(40)` | nothing (feature withdrawn) |
| Options (cfAll) | RADIO TCP SERVER PORT | `@RadioServerTCPPort` | nothing; no reader in D7 either (uCFG.pas:1164-1168) |
| Appearance (cfAppearance) | ROW COUNT | `pointer(4)` | follows the main window height, restored from the saved window position (uCFG.pas:1238-1243) |
| Options (cfAll) | UDP BROADCAST PORT | `@UDPBroadcastPort` | per-destination port in uUDPDestinationEditForm |
| Options (cfAll) | USE CONTROL PORT | `@tUseControlPort` | nothing (feature withdrawn) |
| Appearance (cfAppearance) | WINDOW SIZE | `pointer(5)` | text scale follows the window width, saved with the window layout (uCFG.pas:1244-1251) |

None had `crAddress: nil` in D7, but a real address is not a reader: by the 5.x comments COUNTRY INFORMATION FILE
and RADIO TCP SERVER PORT were read by nothing in D7 either. The reasons for the rest are in the comments in
`RETIRED_COMMANDS` (uCFG.pas:1089-1271); I did not re-verify each against D7 readers.

### D-store (57) -- the replacing control was found for each

| D7 window | command | 5.x control |
|---|---|---|
| Options (cfAll) | CONNECTION COMMAND | Preferences > DX Cluster `edtClusterCommand` (cluster library) |
| Options (cfAll) | FREQUENCY POLL RATE | radio editor (uRadioEditForm) Advanced tab `edtPollRate`, per radio |
| Options (cfAll) | HAMLIB ASYNC ONLY | Preferences > Logging `chkHamLibAsyncOnly` |
| Options (cfAll) | HAMLIB DEBUG | Preferences > Logging `chkHamLibDebug` |
| Options (cfAll) | HAMLIB TRACE | Preferences > Logging `chkHamLibTrace` |
| Options (cfAll) | POLL RADIO ONE | radio editor `chkPolling` |
| Options (cfAll) | POLL RADIO TWO | radio editor `chkPolling` |
| Options (cfAll) | RADIO ONE CW BY CAT | Preferences profile slot CW-output combo, item "CW by CAT" (uPrefsForm.pas:3042-3045), offered only for a radio declaring rcCWByCAT |
| Options (cfAll) | RADIO ONE CW SPEED SYNC | Preferences profile `chkSpeedSync1`/`chkSpeedSync2` (uPrefsForm.lfm:458, :513) |
| Options (cfAll) | RADIO ONE FT1000MP CW REVERSE | radio editor `chkFT1000MPReverse` |
| Options (cfAll) | RADIO ONE ICOM DATA MODE ID | radio editor `edtDataMode` |
| Options (cfAll) | RADIO ONE ICOM FILTER BYTE | radio editor `edtFilterByte` |
| Options (cfAll) | RADIO ONE KEYER STOP BITS | radio editor `cbxKeyerStopBits` |
| Options (cfAll) | RADIO ONE NAME | radio editor `edtName` |
| Options (cfAll) | RADIO ONE STARTUP COMMAND | radio editor `edtStartup` |
| Options (cfAll) | RADIO ONE USE HAMLIB | radio editor `chkUseHamLib` |
| Options (cfAll) | RADIO TWO CW BY CAT | Preferences profile slot CW-output combo, item "CW by CAT" (uPrefsForm.pas:3042-3045), offered only for a radio declaring rcCWByCAT |
| Options (cfAll) | RADIO TWO CW SPEED SYNC | Preferences profile `chkSpeedSync1`/`chkSpeedSync2` (uPrefsForm.lfm:458, :513) |
| Options (cfAll) | RADIO TWO FT1000MP CW REVERSE | radio editor `chkFT1000MPReverse` |
| Options (cfAll) | RADIO TWO ICOM DATA MODE ID | radio editor `edtDataMode` |
| Options (cfAll) | RADIO TWO ICOM FILTER BYTE | radio editor `edtFilterByte` |
| Options (cfAll) | RADIO TWO KEYER STOP BITS | radio editor `cbxKeyerStopBits` |
| Options (cfAll) | RADIO TWO NAME | radio editor `edtName` |
| Options (cfAll) | RADIO TWO STARTUP COMMAND | radio editor `edtStartup` |
| Options (cfAll) | RADIO TWO USE HAMLIB | radio editor `chkUseHamLib` |
| Options (cfAll) | TELNET DEBUG | Preferences > Logging `chkTelnetDebug` |
| Options (cfAll) | UDP BROADCAST ADDRESS | destination `edtAddress` |
| Options (cfAll) | UDP BROADCAST ALL QSOS | `chkUDPAllQSOs` |
| Options (cfAll) | UDP BROADCAST APP INFO | `chkStreamAppInfo` |
| Options (cfAll) | UDP BROADCAST CONTACT INFO | `chkStreamContact` |
| Options (cfAll) | UDP BROADCAST LOOKUP INFO | `chkStreamLookup` |
| Options (cfAll) | UDP BROADCAST PORT APP INFO | destination `edtPort` (one port per destination, not per stream) |
| Options (cfAll) | UDP BROADCAST PORT CONTACT | destination `edtPort` (per destination) |
| Options (cfAll) | UDP BROADCAST PORT LOOKUP | destination `edtPort` (per destination) |
| Options (cfAll) | UDP BROADCAST PORT RADIO | destination `edtPort` (per destination) |
| Options (cfAll) | UDP BROADCAST PORT SCORE | destination `edtPort` (per destination) |
| Options (cfAll) | UDP BROADCAST RADIO INFO | `chkStreamRadio` |
| Options (cfAll) | UDP BROADCAST ROTOR | `chkStreamRotor` |
| Options (cfAll) | UDP BROADCAST ROTOR PORT | destination `edtPort` (per destination) |
| Options (cfAll) | UDP BROADCAST SCORE | `chkStreamScore` |
| WinKeyer (cfWK) | WK AUTOSPACE | chkWKAutospace |
| WinKeyer (cfWK) | WK CT SPACING | chkWKCTSpacing |
| WinKeyer (cfWK) | WK DIT DAH RATIO | edtWKRatio |
| WinKeyer (cfWK) | WK ENABLE | no checkbox: a WinKeyer is enabled by choosing it as a profile slot's CW output |
| WinKeyer (cfWK) | WK FIRST EXTENSION | edtWKFirstExt |
| WinKeyer (cfWK) | WK IGNORE SPEED POT | chkWKIgnoreSpeedPot |
| WinKeyer (cfWK) | WK KEYER COMPENSATION | edtWKComp |
| WinKeyer (cfWK) | WK KEYER MODE | cbxWKKeyerMode |
| WinKeyer (cfWK) | WK LEADIN TIME | edtWKLeadIn |
| WinKeyer (cfWK) | WK PADDLE ONLY SIDETONE | chkWKPaddleOnlySidetone |
| WinKeyer (cfWK) | WK PADDLE SWAP | chkWKPaddleSwap |
| WinKeyer (cfWK) | WK PADDLE SWITCHPOINT | edtWKSwitchpoint |
| WinKeyer (cfWK) | WK PORT | cbxPort |
| WinKeyer (cfWK) | WK SIDETONE ENABLE | chkWKSidetoneEnable |
| WinKeyer (cfWK) | WK SIDETONE FREQUENCY | cbxWKSidetone |
| WinKeyer (cfWK) | WK TAIL TIME | edtWKTail |
| WinKeyer (cfWK) | WK WEIGHT | edtWKWeight |

WK rows are in the keyer editor (Hardware > CW keyers, `uKeyerEditForm.pas:63-93`). Radio rows are per radio in
`uRadioEditForm.pas:90-196`. The per-stream UDP ports became one port per destination: settable, but a different
shape (send two streams to two ports = two destinations).

## Other things found on the way

- **Rotators:** ROTATOR TYPE/PORT and PSTROTATOR IP/UDP are edited in the rotator library, but
  `Settings.Rotator.*` still exists beside it. Which one the running program reads was NOT verified.
- **DEBUG LOG LEVEL** is edited through the radio store's `logging.level` (`cbxLogLevel`), the documented
  precedence above `Settings.Log.DebugLevel`.
- **MY CONTINENT** was read-only in D7 (crJ=2); 5.x makes it editable (`cbxMyContinent`, Station page).
- **The D7 message rows** (CQ EXCHANGE, S&P EXCHANGE, QSL MESSAGE, QSO BEFORE, CALL OK NOW, REPEAT S&P; ctMessage,
  crJ 3) were SHOWN in D7 Options but edited elsewhere. In 5.x they are owned settings with no Preferences
  registration. Whether the 5.x message editor reaches them was **not checked** (out of the Options scope).

## Appendix 1: A (designed control)

Plus the 100 Colours-window rows: all 50 D7 element names exist in 5.x `TWindows` (5.x adds ROVER) and each gets
a colour and a background cell in the Colours grid (`BuildColorsSection`, uPrefsForm.pas:4100-4227).

### CFGCA rows (126)

| D7 window | command | evidence |
|---|---|---|
| Options (cfAll) | ALL CW MESSAGES CHAINABLE | bound designed control chkCWMessagesChainable (key cw.messagesChainable) |
| Options (cfAll) | ALT-D BUFFER ENABLE | bound designed control chkAltDBuffer (key operating.tworadio.altDBuffer) |
| Options (cfAll) | ALT-D CQ ENABLE | bound designed control chkAltDCQ (key operating.tworadio.altDCQ) |
| Options (cfAll) | ALWAYS CALL BLIND CQ | bound designed control chkAlwaysBlindCQ (key operating.tworadio.blindCQ) |
| Options (cfAll) | AUTO QSO NUMBER DECREMENT | bound designed control chkAutoQSONumberDecrement (key operating.autoQSONumberDecrement) |
| Options (cfAll) | AUTO RETURN TO CQ MODE | bound designed control chkAutoReturnToCQ (key operating.autoReturnToCQ) |
| Options (cfAll) | BACKUP LOG FILE NAME | second name of BACKUP DESTINATION; hand-wired designed control edtBackupFile |
| Options (cfAll) | BACKUP LOG FREQUENCY | hand-wired designed control edtBackupEvery |
| Options (cfAll) | BAND MAP ALL BANDS | hand-wired designed control chkBandMapAllBands |
| Options (cfAll) | BAND MAP ALL MODES | hand-wired designed control chkBandMapAllModes |
| Options (cfAll) | BAND MAP CALL WINDOW ENABLE | hand-wired designed control chkBandMapCallWindow |
| Options (cfAll) | BAND MAP DECAY TIME | hand-wired designed control edtBandMapDecay |
| Options (cfAll) | BAND MAP DISPLAY CQ | hand-wired designed control chkBandMapCQ |
| Options (cfAll) | BAND MAP DISPLAY GHZ | hand-wired designed control chkBandMapGHz |
| Options (cfAll) | BAND MAP DISPLAY LIMIT | hand-wired designed control edtBandMapLimit |
| Options (cfAll) | BAND MAP DUPE DISPLAY | hand-wired designed control chkBandMapDupes |
| Options (cfAll) | BAND MAP GUARD BAND | hand-wired designed control edtBandMapGuard |
| Options (cfAll) | BAND MAP MULTS ONLY | hand-wired designed control chkBandMapMultsOnly |
| Options (cfAll) | BAND MAP SO2R DISPLAY | hand-wired designed control chkBandMapSO2R |
| Appearance (cfAppearance) | BOLD FONT | hand-wired designed control edtFontFace |
| Options (cfAll) | CALL WINDOW SHOW ALL SPOTS | bound designed control chkCallWindowShowAllSpots (key bandmap.callWindowShowAllSpots) |
| Options (cfAll) | CHECK LOG FILE SIZE | bound designed control chkCheckLogFileSize (key logging.checkLogFileSize) |
| Options (cfAll) | COMPUTER ID | hand-wired designed control edtNetComputerID |
| Options (cfAll) | CONFIRM EDIT CHANGES | bound designed control chkConfirmEditChanges (key operating.confirmEditChanges) |
| Options (cfAll) | CONNECTION AT STARTUP | bound designed control chkClusterAtStartup (key cluster.connectAtStartup) |
| Options (cfAll) | CW ENABLE | bound designed control chkCWEnable (key cw.enable) |
| Options (cfAll) | CW SPEED FROM DATABASE | bound designed control chkCWSpeedFromDatabase (key cw.speedFromDatabase) |
| Options (cfAll) | CW SPEED INCREMENT | bound designed control cbxCWSpeedIncrement (key cw.speedIncrement) |
| Options (cfAll) | CW TONE | bound designed control edtCWTone (key cw.tone) |
| Options (cfAll) | DEBUG LOG LEVEL | Preferences > Logging, `cbxLogLevel` (store-backed; writes the radio store `logging.level`, which wins over `Settings.Log.DebugLevel`) |
| Options (cfAll) | DIT DAH RATIO | bound designed control cbxDitDah (key operating.cw.serial.ditDahRatio) |
| Options (cfAll) | DVK ENABLE | bound designed control chkDVKEnable (key audio.dvk.enable) |
| Options (cfAll) | DVK LOCALIZED MESSAGES ENABLE | bound designed control chkDVKLocalizedMessages (key audio.dvk.localizedMessages) |
| Options (cfAll) | DVK PATH | bound designed control edtDVKPath (key audio.dvk.path) |
| Options (cfAll) | DVK RECORDER | bound designed control edtDVKRecorder (key audio.dvk.recorder) |
| Options (cfAll) | ESCAPE EXITS SEARCH AND POUNCE | bound designed control chkEscapeExitsSAP (key operating.escapeExitsSAP) |
| Options (cfAll) | EXTERNAL LOGGER | hand-wired designed control cbxLoggerType |
| Options (cfAll) | EXTERNAL LOGGER ADDRESS | hand-wired designed control edtLoggerAddress |
| Options (cfAll) | EXTERNAL LOGGER ENABLED | hand-wired designed control chkLoggerEnabled |
| Options (cfAll) | EXTERNAL LOGGER PORT | hand-wired designed control edtLoggerPort |
| Options (cfAll) | FARNSWORTH ENABLE | bound designed control chkFarnsworth (key operating.cw.serial.farnsworth) |
| Options (cfAll) | FARNSWORTH SPEED | bound designed control edtFarnsworthSpeed (key operating.cw.serial.farnsworthSpeed) |
| Options (cfAll) | FONT SIZE | hand-wired designed control spnFontSize |
| Options (cfAll) | HAMSCORE ENABLE | bound designed control chkHamScoreEnable (key scoring.hamscore.enable) |
| Options (cfAll) | HAMSCORE PASSWORD | bound designed control edtHamScorePass (key scoring.hamscore.password) |
| Options (cfAll) | HAMSCORE SEND CONTACT INFO | bound designed control chkHamScoreContact (key scoring.hamscore.contactInfo) |
| Options (cfAll) | HAMSCORE URL | bound designed control edtHamScoreURL (key scoring.hamscore.url) |
| Options (cfAll) | HAMSCORE USERNAME | bound designed control edtHamScoreUser (key scoring.hamscore.username) |
| Options (cfAll) | HF BAND ENABLE | bound designed control chkHFBands (key operating.bands.hf) |
| Options (cfAll) | IN BAND LOCKOUT | bound designed control chkInBandLockout (key operating.tworadio.inBandLockout) |
| Options (cfAll) | INCLUDE F-KEY NUMBER | bound designed control chkIncludeFKeyNumber (key cw.includeFKeyNumber) |
| Options (cfAll) | INTERCOM FILE ENABLE | bound designed control chkIntercomFile (key network.intercomFile) |
| Options (cfAll) | KEYPAD CW MEMORIES | bound designed control chkKeypadCWMemories (key operating.cw.keypadMemories) |
| Options (cfAll) | LEADING ZERO CHARACTER | bound designed control edtLeadingZeroChar (key operating.cw.leadingZeroChar) |
| Options (cfAll) | LEADING ZEROS | bound designed control cbxLeadingZeros (key operating.cw.leadingZeros) |
| Options (cfAll) | LEAVE CURSOR IN CALL WINDOW | bound designed control chkLeaveCursorInCall (key operating.leaveCursorInCall) |
| Options (cfAll) | LOG WITH SINGLE ENTER | bound designed control chkLogWithSingleEnter (key operating.logWithSingleEnter) |
| Options (cfAll) | MAIN CALLSIGN | bound designed control edtMainCallsign (key operating.ctrlj.mainCallsign) |
| Appearance (cfAppearance) | MAIN FONT | hand-wired designed control edtFontFace |
| Options (cfAll) | MMTTY ENGINE | hand-wired designed control edtMMTTYEngine |
| Options (cfAll) | MULTI MULTS ONLY | bound designed control chkMultiMultsOnly (key network.multiMultsOnly) |
| Options (cfAll) | MY CHECK | hand-wired designed control edtMyCheck |
| Options (cfAll) | MY FD CLASS | hand-wired designed control edtMyFDClass |
| Options (cfAll) | MY FOC NUMBER | hand-wired designed control edtMyFOCNumber |
| Options (cfAll) | MY GRID | hand-wired designed control edtMyGrid |
| Options (cfAll) | MY IOTA | hand-wired designed control edtMyIOTA |
| Options (cfAll) | MY ITU ZONE | hand-wired designed control edtMyITUZone |
| Options (cfAll) | MY NAME | hand-wired designed control edtMyName |
| Options (cfAll) | MY PARK | hand-wired designed control edtMyPark |
| Options (cfAll) | MY POSTAL CODE | hand-wired designed control edtMyPostalCode |
| Options (cfAll) | MY PREC | hand-wired designed control edtMyPrec |
| Options (cfAll) | MY SECTION | hand-wired designed control edtMySection |
| Options (cfAll) | NAME FLAG ENABLE | bound designed control chkNameFlag (key scp.nameFlag) |
| Appearance (cfAppearance) | NO BORDER | bound designed control chkNoBorder (key appearance.noBorder) |
| Appearance (cfAppearance) | NO CAPTION | bound designed control chkNoCaption (key appearance.noCaption) |
| Appearance (cfAppearance) | NO COLUMN HEADER | bound designed control chkNoColumnHeader (key appearance.noColumnHeader) |
| Options (cfAll) | NO POLL DURING PTT | bound designed control chkNoPollDuringPTT (key ptt.noPollDuringPTT) |
| Options (cfAll) | PADDLE MONITOR TONE | bound designed control edtPaddleTone (key cw.paddle.monitorTone) |
| Options (cfAll) | PADDLE PTT HOLD COUNT | bound designed control edtPaddleHold (key cw.paddle.pttHoldCount) |
| Options (cfAll) | PADDLE SPEED | bound designed control edtPaddleSpeed (key cw.paddle.speed) |
| Options (cfAll) | PARTIAL CALL ENABLE | bound designed control chkPartialCall (key scp.partialCall) |
| Options (cfAll) | POSSIBLE CALLS | bound designed control chkPossibleCalls (key scp.possibleCalls) |
| Options (cfAll) | PSTROTATOR IP ADDRESS | Preferences > Rotators, `edtRotatorIP` (rotator library) |
| Options (cfAll) | PSTROTATOR UDP PORT | Preferences > Rotators, `edtRotatorUDP` (rotator library) |
| Options (cfAll) | PTT ENABLE | bound designed control chkPTTEnable (key ptt.enable) |
| Options (cfAll) | PTT LOCKOUT | bound designed control chkPTTLockout (key ptt.lockout) |
| Options (cfAll) | PTT TURN ON DELAY | bound designed control edtPTTDelay (key ptt.turnOnDelay) |
| Options (cfAll) | PTT VIA COMMANDS | bound designed control chkPTTViaCommands (key ptt.viaCommands) |
| Options (cfAll) | QSY INACTIVE RADIO | bound designed control chkQSYInactive (key operating.tworadio.qsyInactive) |
| Options (cfAll) | ROTATOR PORT | Preferences > Rotators, `cbxRotatorPort` (rotator library) |
| Options (cfAll) | ROTATOR TYPE | Preferences > Rotators, `cbxRotatorType` (rotator library) |
| Options (cfAll) | SAY HI ENABLE | bound designed control chkSayHiEnable (key operating.cw.sayHi) |
| Options (cfAll) | SAY HI RATE CUTOFF | bound designed control edtSayHiCutoff (key operating.cw.sayHiRateCutoff) |
| Options (cfAll) | SCORE POSTING URL | bound designed control edtScorePostURL (key scoring.board.postingUrl) |
| Options (cfAll) | SCORE READING URL | bound designed control edtScoreReadURL (key scoring.board.readingUrl) |
| Options (cfAll) | SCP COUNTRY STRING | hand-wired designed control edtSCPCountry |
| Options (cfAll) | SCP MINIMUM LETTERS | hand-wired designed control cbxSCPMinLetters |
| Options (cfAll) | SEND COMPLETE FOUR LETTER CALL | bound designed control chkSendFourLetterCall (key cw.sendFourLetterCall) |
| Options (cfAll) | SERVER ADDRESS | hand-wired designed control edtNetAddress |
| Options (cfAll) | SERVER AUTO SYNCHRONIZE LOG ON CONNECT | hand-wired designed control chkNetAutoSync |
| Options (cfAll) | SERVER PASSWORD | hand-wired designed control edtNetPassword |
| Options (cfAll) | SERVER PORT | hand-wired designed control edtNetPort |
| Appearance (cfAppearance) | SHOW GRIDLINES | bound designed control chkShowGridlines (key appearance.showGridlines) |
| Options (cfAll) | SKIP ACTIVE BAND | bound designed control chkSkipActiveBand (key operating.tworadio.skipActiveBand) |
| Options (cfAll) | SPACE BAR DUPE CHECK ENABLE | bound designed control chkSpaceBarDupeCheck (key operating.spaceBarDupeCheck) |
| Options (cfAll) | SPOT COLLECTOR ENABLED | hand-wired designed control chkSpotCollector |
| Options (cfAll) | SWAP PACKET SPOT RADIOS | bound designed control chkSwapPacketSpotRadios (key bandmap.swapPacketSpotRadios) |
| Options (cfAll) | SWAP PADDLES | bound designed control chkSwapPaddles (key cw.paddle.swap) |
| Options (cfAll) | SWAP RADIO RELAY SENSE | bound designed control chkSwapRelaySense (key operating.tworadio.swapRelaySense) |
| Options (cfAll) | TELNET SERVER | Preferences > DX Cluster, `cbxClusterServer` (cluster library; TELNET SERVER is rendered from the active cluster, uRadioConfigApply.pas:1785) |
| Options (cfAll) | TUNE WITH DITS | bound designed control chkTuneWithDits (key cw.tuneWithDits) |
| Options (cfAll) | TWO RADIO MODE | bound designed control chkTwoRadioMode (key operating.tworadio.enable) |
| Options (cfAll) | UNKNOWN COUNTRY FILE ENABLE | bound designed control chkUnknownCountryFile (key logging.unknownCountryFile) |
| Options (cfAll) | UPDATE RESTART FILE ENABLE | bound designed control chkUpdateRestartFile (key logging.updateRestartFile) |
| Options (cfAll) | USE RECORDED SIGNS | bound designed control chkUseRecordedSigns (key audio.useRecordedSigns) |
| Options (cfAll) | VHF BAND ENABLE | bound designed control chkVHFBands (key operating.bands.vhf) |
| Options (cfAll) | WAIT FOR STRENGTH | bound designed control chkWaitForStrength (key operating.tworadio.waitForStrength) |
| Options (cfAll) | WARC BAND ENABLE | bound designed control chkWARCBands (key operating.bands.warc) |
| Options (cfAll) | WEIGHT | bound designed control edtWeight (key operating.cw.serial.weight) |
| Options (cfAll) | WILDCARD PARTIALS | bound designed control chkWildcardPartials (key scp.wildcardPartials) |
| Options (cfAll) | WSJT-X BROADCAST PORT | hand-wired designed control edtWSJTXPort |
| Options (cfAll) | WSJT-X ENABLED | hand-wired designed control chkWSJTXEnabled |
| Options (cfAll) | WSJT-X MULTICAST GROUP | hand-wired designed control edtWSJTXMulticast |
| Options (cfAll) | WSJT-X RADIO CONTROL ENABLED | hand-wired designed control chkWSJTXRadioControl |
| Options (cfAll) | WSJT-X SEND HIGHLIGHTS | hand-wired designed control chkWSJTXHighlights |
| Options (cfAll) | YCCC SO2R ENABLE | hand-wired designed control chkYCCCSO2R |

## Appendix 2: B-visible (generated row on a visible page)

### CFGCA rows (83)

| D7 window | command | evidence |
|---|---|---|
| Options (cfAll) | ASK FOR FREQUENCIES | generated page NAV_CLUSTERSPOTS (key operating.ctrlj.askForFrequencies) |
| Options (cfAll) | AUTO CALL TERMINATE | generated page NAV_CWCHARACTERS (key operating.autoCallTerminate) |
| Options (cfAll) | AUTO DISPLAY DUPE QSO | generated page NAV_ENTRY (key operating.ctrlj.autoDisplayDupeQso) |
| Options (cfAll) | AUTO DUPE ENABLE CQ | generated page NAV_ENTRY (key operating.ctrlj.autoDupeEnableCq) |
| Options (cfAll) | AUTO DUPE ENABLE S AND P | generated page NAV_ENTRY (key operating.ctrlj.autoDupeEnableSAndP) |
| Options (cfAll) | AUTO QSL INTERVAL | generated page NAV_CONTESTQUICKQSL (key contest.autoQslInterval) |
| Options (cfAll) | AUTO S&P ENABLE | generated page NAV_ENTRY (key operating.ctrlj.autoSPEnable) |
| Options (cfAll) | AUTO S&P ENABLE SENSITIVITY | generated page NAV_ENTRY (key operating.ctrlj.autoSPEnableSensitivity) |
| Options (cfAll) | AUTO SEND CHARACTER COUNT | generated page NAV_CWCHARACTERS (key cw.ctrlj.autoSendCharacterCount) |
| Options (cfAll) | AUTO TIME INCREMENT | generated page NAV_ENTRY (key operating.ctrlj.autoTimeIncrement) |
| Options (cfAll) | AUTO-CQ DELAY TIME | generated Contest page by prefix (key contest.autoCQDelayTime) |
| Options (cfAll) | BAND MAP ITEM HEIGHT | generated page NAV_BANDMAPWINDOW (key bandmap.ctrlj.bandMapItemHeight) |
| Options (cfAll) | BAND MAP ITEM WIDTH | generated page NAV_BANDMAPWINDOW (key bandmap.ctrlj.bandMapItemWidth) |
| Options (cfAll) | BAND MAP SIZE | generated page NAV_BANDMAPWINDOW (key bandmap.ctrlj.bandMapSize) |
| Options (cfAll) | BAND MAP SPLIT MODE | generated page NAV_BANDMAPWINDOW (key bandmap.ctrlj.bandMapSplitMode) |
| Options (cfAll) | BEEP EVERY 10 QSOS | generated Contest page by prefix (key contest.beepEvery10Qsos) |
| Options (cfAll) | BROADCAST ALL PACKET DATA | generated page NAV_CLUSTERSPOTS (key cluster.ctrlj.broadcastAllPacketData) |
| Options (cfAll) | CALLSIGN UPDATE ENABLE | generated page NAV_ENTRY (key files.ctrlj.callsignUpdateEnable) |
| Options (cfAll) | CATEGORY-ASSISTED | generated page NAV_CONTESTCABRILLO (key contest.categoryAssisted) |
| Options (cfAll) | CATEGORY-BAND | generated page NAV_CONTESTCABRILLO (key contest.categoryBand) |
| Options (cfAll) | CATEGORY-MODE | generated page NAV_CONTESTCABRILLO (key contest.categoryMode) |
| Options (cfAll) | CATEGORY-OPERATOR | generated page NAV_CONTESTCABRILLO (key contest.categoryOperator) |
| Options (cfAll) | CATEGORY-OVERLAY | generated page NAV_CONTESTCABRILLO (key contest.categoryOverlay) |
| Options (cfAll) | CATEGORY-POWER | generated page NAV_CONTESTCABRILLO (key contest.categoryPower) |
| Options (cfAll) | CATEGORY-TRANSMITTER | generated page NAV_CONTESTCABRILLO (key contest.categoryTransmitter) |
| Options (cfAll) | CODE SPEED | generated page NAV_CWCHARACTERS (key cw.ctrlj.codeSpeed) |
| Options (cfAll) | COLUMN AUTOSIZE | generated page NAV_LOGDISPLAY (key appearance.ctrlj.columnAutosize) |
| Options (cfAll) | COMPLETE CALLSIGN MASK | generated page NAV_ENTRY (key appearance.ctrlj.completeCallsignMask) |
| Options (cfAll) | CONTACTS PER PAGE | generated page NAV_PRINTEDLOG (key appearance.ctrlj.contactsPerPage) |
| Options (cfAll) | COUNT DOMESTIC COUNTRIES | generated page NAV_CONTESTMULTS (key contest.countDomesticCountries) |
| Options (cfAll) | CTY UPDATE CHECK ON STARTUP | generated page NAV_FILES (key files.ctrlj.ctyUpdateCheckOnStartup) |
| Options (cfAll) | CUSTOM INITIAL EXCHANGE STRING | generated page NAV_CONTESTINITIALEX (key contest.customInitialExchangeString) |
| Options (cfAll) | CUSTOM USER STRING | generated page NAV_LOGDISPLAY (key operating.ctrlj.customUserString) |
| Options (cfAll) | DE ENABLE | generated page NAV_MESSAGES (key operating.ctrlj.deEnable) |
| Options (cfAll) | DIGITAL MODE ENABLE | generated page NAV_CONTESTMODES (key operating.ctrlj.digitalModeEnable) |
| Options (cfAll) | DISTANCE MODE | generated page NAV_LOGDISPLAY (key operating.ctrlj.distanceMode) |
| Options (cfAll) | DUPE SHEET AUTO RESET | generated page NAV_ENTRY (key operating.ctrlj.dupeSheetAutoReset) |
| Options (cfAll) | EXCHANGE MEMORY ENABLE | generated page NAV_CONTESTINITIALEX (key contest.exchangeMemoryEnable) |
| Options (cfAll) | GRID MAP CENTER | generated Contest page by prefix (key contest.gridMapCenter) |
| Options (cfAll) | HAND LOG MODE | generated Advanced page by prefix (key advanced.handLogMode) |
| Options (cfAll) | HOUR DISPLAY | generated page NAV_LOGDISPLAY (key appearance.ctrlj.hourDisplay) |
| Options (cfAll) | INCREMENT TIME ENABLE | generated page NAV_ENTRY (key operating.ctrlj.incrementTimeEnable) |
| Options (cfAll) | INITIAL EXCHANGE CURSOR POS | generated page NAV_CONTESTINITIALEX (key contest.initialExchangeCursorPos) |
| Options (cfAll) | INITIAL EXCHANGE FILENAME | generated page NAV_CONTESTINITIALEX (key files.ctrlj.initialExchangeFilename) |
| Options (cfAll) | INITIAL EXCHANGE OVERWRITE | generated page NAV_CONTESTINITIALEX (key contest.initialExchangeOverwrite) |
| Options (cfAll) | INSERT MODE | generated page NAV_ENTRY (key appearance.ctrlj.insertMode) |
| Options (cfAll) | LITERAL DOMESTIC QTH | generated page NAV_CONTESTMULTS (key contest.literalDomesticQth) |
| Options (cfAll) | LOG FREQUENCY ENABLE | generated page NAV_ENTRY (key operating.ctrlj.logFrequencyEnable) |
| Options (cfAll) | LOG RS SENT | generated Contest page by prefix (key contest.logRsSent) |
| Options (cfAll) | LOG RST SENT | generated Contest page by prefix (key contest.logRstSent) |
| Options (cfAll) | LOG SUB TITLE | generated page NAV_PRINTEDLOG (key operating.ctrlj.logSubTitle) |
| Options (cfAll) | LOOK FOR RST SENT | generated Contest page by prefix (key contest.lookForRstSent) |
| Options (cfAll) | MESSAGE ENABLE | generated Contest page by prefix (key contest.messageEnable) |
| Options (cfAll) | MULT REPORT MINIMUM BANDS | generated page NAV_CONTESTMULTS (key contest.multReportMinimumBands) |
| Options (cfAll) | MULTIPLE BANDS | generated page NAV_CONTESTRULES (key contest.multipleBands) |
| Options (cfAll) | MULTIPLE MODES | generated page NAV_CONTESTMODES (key contest.multipleModes) |
| Options (cfAll) | NO LOG | generated Advanced page by prefix (key advanced.noLog) |
| Options (cfAll) | QSL MODE | generated page NAV_CONTESTQUICKQSL (key contest.qslMode) |
| Options (cfAll) | QSO NUMBER BY BAND | generated page NAV_CONTESTQSO (key contest.qsoNumberByBand) |
| Options (cfAll) | QSX ENABLE | generated page NAV_CLUSTERSPOTS (key operating.ctrlj.qsxEnable) |
| Options (cfAll) | QTC ENABLE | generated page NAV_CONTESTQTC (key contest.qtcEnable) |
| Options (cfAll) | QTC EXTRA SPACE | generated page NAV_CONTESTQTC (key contest.qtcExtraSpace) |
| Options (cfAll) | QTC MINUTES | generated page NAV_CONTESTQTC (key contest.qtcMinutes) |
| Options (cfAll) | QTC QRS | generated page NAV_CONTESTQTC (key contest.qtcQrs) |
| Options (cfAll) | QUESTION MARK CHAR | generated page NAV_CWCHARACTERS (key cw.ctrlj.questionMarkChar) |
| Options (cfAll) | QUICK QSL KEY 1 | generated page NAV_CONTESTQUICKQSL (key contest.quickQslKey1) |
| Options (cfAll) | QUICK QSL KEY 2 | generated page NAV_CONTESTQUICKQSL (key contest.quickQslKey2) |
| Options (cfAll) | QZB RANDOM OFFSET ENABLE | generated page NAV_BANDMAPWINDOW (key operating.ctrlj.qzbRandomOffsetEnable) |
| Options (cfAll) | RADIUS OF EARTH | generated page NAV_ADVANCED (key operating.ctrlj.radiusOfEarth) |
| Options (cfAll) | RANDOM CQ MODE | generated Contest page by prefix (key contest.randomCqMode) |
| Options (cfAll) | RATE DISPLAY | generated page NAV_LOGDISPLAY (key appearance.ctrlj.rateDisplay) |
| Options (cfAll) | REMAINING MULT DISPLAY MODE | generated page NAV_CONTESTMULTS (key contest.remainingMultDisplayMode) |
| Options (cfAll) | REVERSE INITIAL EX | generated page NAV_CONTESTINITIALEX (key contest.reverseInitialEx) |
| Options (cfAll) | SHIFT KEY ENABLE | generated page NAV_ENTRY (key operating.ctrlj.shiftKeyEnable) |
| Options (cfAll) | SHORT INTEGERS | generated page NAV_CWCHARACTERS (key cw.ctrlj.shortIntegers) |
| Options (cfAll) | SHOW DOMESTIC MULTIPLIER NAME | generated page NAV_CONTESTMULTS (key contest.showDomesticMultiplierName) |
| Options (cfAll) | SHOW FREQUENCY IN LOG | generated page NAV_LOGDISPLAY (key appearance.ctrlj.showFrequencyInLog) |
| Options (cfAll) | SLASH MARK CHAR | generated page NAV_CWCHARACTERS (key cw.ctrlj.slashMarkChar) |
| Options (cfAll) | SPRINT QSY RULE | generated page NAV_CONTESTRULES (key contest.sprintQsyRule) |
| Options (cfAll) | START SENDING NOW KEY | generated page NAV_CWCHARACTERS (key cw.ctrlj.startSendingNowKey) |
| Options (cfAll) | TEN MINUTE RULE | generated page NAV_CONTESTRULES (key contest.tenMinuteRule) |
| Options (cfAll) | UNKNOWN COUNTRY FILE NAME | generated page NAV_FILES (key files.ctrlj.unknownCountryFileName) |
| Options (cfAll) | USER INFO SHOWN | generated page NAV_LOGDISPLAY (key appearance.ctrlj.userInfoShown) |

## Appendix 3: shown in D7 Options but not changeable there (71) -- context only

| D7 window | command | why D7 could not change it | 5.x |
|---|---|---|---|
| Options (cfAll) | ADD DOMESTIC COUNTRY | crJ=2 | owned, no Preferences row: TryApplyCommandAction (an action, no property) |
| Options (cfAll) | BAND | crJ=2 | B-hidden: BuildPlacedBlock on NAV_BANDS (key operating.ctrlj.band) |
| Options (cfAll) | CALL OK NOW CW MESSAGE | crJ=3 | owned, no Preferences row: owned by settings object (Settings.Messages.CallOkNowCw) but no registration/hand-wired control |
| Options (cfAll) | CALL OK NOW MESSAGE | crJ=3 | owned, no Preferences row: second name of CALL OK NOW CW MESSAGE; owned by settings object (Settings.Messages.CallOkNowCw) but no registration/hand-wired control |
| Options (cfAll) | CALL OK NOW SSB MESSAGE | crJ=3 | owned, no Preferences row: owned by settings object (Settings.Messages.CallOkNowSsb) but no registration/hand-wired control |
| Options (cfAll) | CLEAR DUPE SHEET | crJ=2 | owned, no Preferences row: TryApplyCommandAction (an action, no property) |
| Options (cfAll) | CONTEST | crJ=2 | B-visible: generated Contest page by prefix (key contest.contest) |
| Options (cfAll) | CONTEST NAME | crJ=2 | B-visible: generated Contest page by prefix (key contest.contestName) |
| Options (cfAll) | CONTEST TITLE | crJ=2 | B-visible: generated Contest page by prefix (key contest.contestTitle) |
| Options (cfAll) | CQ CW EXCHANGE | crJ=3 | owned, no Preferences row: owned by settings object (Settings.Messages.CqExchangeCw) but no registration/hand-wired control |
| Options (cfAll) | CQ CW EXCHANGE NAME KNOWN | crJ=3 | owned, no Preferences row: owned by settings object (Settings.Messages.CqExchangeCwNameKnown) but no registration/hand-wired control |
| Options (cfAll) | CQ EXCHANGE | crJ=3 | owned, no Preferences row: second name of CQ CW EXCHANGE; owned by settings object (Settings.Messages.CqExchangeCw) but no registration/hand-wired control |
| Options (cfAll) | CQ EXCHANGE NAME KNOWN | crJ=3 | owned, no Preferences row: second name of CQ CW EXCHANGE NAME KNOWN; owned by settings object (Settings.Messages.CqExchangeCwNameKnown) but no registration/hand-wired control |
| Options (cfAll) | CQ SSB EXCHANGE | crJ=3 | owned, no Preferences row: owned by settings object (Settings.Messages.CqExchangeSsb) but no registration/hand-wired control |
| Options (cfAll) | CQ SSB EXCHANGE NAME KNOWN | crJ=3 | owned, no Preferences row: owned by settings object (Settings.Messages.CqExchangeSsbNameKnown) but no registration/hand-wired control |
| Options (cfAll) | DOMESTIC FILENAME | crJ=2 | B-visible: generated page NAV_CONTESTMULTS (key files.ctrlj.domesticFilename) |
| Options (cfAll) | DOMESTIC MULTIPLIER | crJ=2 | D-retired: RETIRED_COMMANDS |
| Options (cfAll) | DX MULTIPLIER | crJ=2 | D-retired: RETIRED_COMMANDS |
| Options (cfAll) | EXCHANGE RECEIVED | crJ=2 | D-retired: RETIRED_COMMANDS |
| Options (cfAll) | KEYER RADIO ONE OUTPUT PORT | crJ=2 | D-store: radio library key (CommandIsRadioLibraryKey) |
| Options (cfAll) | KEYER RADIO TWO OUTPUT PORT | crJ=2 | D-store: radio library key (CommandIsRadioLibraryKey) |
| Options (cfAll) | LATEST CONFIG FILE | crJ=2 | D-retired: RETIRED_COMMANDS |
| Options (cfAll) | LPT1 BASE ADDRESS | crJ=2 | D-retired: RETIRED_COMMANDS |
| Options (cfAll) | LPT2 BASE ADDRESS | crJ=2 | D-retired: RETIRED_COMMANDS |
| Options (cfAll) | LPT3 BASE ADDRESS | crJ=2 | D-retired: RETIRED_COMMANDS |
| Options (cfAll) | MINITOUR DURATION | crJ=2 | B-visible: generated page NAV_CONTESTRULES (key contest.minitourDuration) |
| Options (cfAll) | MULT BY BAND | crJ=2 | B-visible: generated page NAV_CONTESTMULTS (key contest.multByBand) |
| Options (cfAll) | MULT BY MODE | crJ=2 | B-visible: generated page NAV_CONTESTMULTS (key contest.multByMode) |
| Options (cfAll) | MULT SHEET AUTO RESET | crJ=2 | B-visible: generated page NAV_CONTESTMULTS (key contest.multSheetAutoReset) |
| Options (cfAll) | MY CALL | crJ=2 | A: hand-wired designed control edtMyCall |
| Options (cfAll) | MY CONTINENT | crJ=2 | owned, no Preferences row: owned by settings object (Settings.Contest.MyContinent) but no registration/hand-wired control |
| Options (cfAll) | MY COUNTRY | crJ=2 | A: hand-wired designed control edtMyCountry |
| Options (cfAll) | MY QTH | crJ=2 | A: second name of MY STATE; hand-wired designed control edtMyState |
| Options (cfAll) | MY STATE | crJ=2 | A: hand-wired designed control edtMyState |
| Options (cfAll) | MY ZONE | crJ=2 | A: hand-wired designed control edtMyZone |
| Options (cfAll) | PADDLE PORT | no edit arm for ctPortLPT/ckNormal | E: does not resolve: not owned, not retired, not a store, not an action |
| Options (cfAll) | PREFIX MULTIPLIER | crJ=2 | D-retired: RETIRED_COMMANDS |
| Options (cfAll) | QSL CW MESSAGE | crJ=3 | owned, no Preferences row: owned by settings object (Settings.Messages.QslCw) but no registration/hand-wired control |
| Options (cfAll) | QSL MESSAGE | crJ=3 | owned, no Preferences row: second name of QSL CW MESSAGE; owned by settings object (Settings.Messages.QslCw) but no registration/hand-wired control |
| Options (cfAll) | QSL SSB MESSAGE | crJ=3 | owned, no Preferences row: owned by settings object (Settings.Messages.QslSsb) but no registration/hand-wired control |
| Options (cfAll) | QSO BEFORE CW MESSAGE | crJ=3 | owned, no Preferences row: owned by settings object (Settings.Messages.QsoBeforeCw) but no registration/hand-wired control |
| Options (cfAll) | QSO BEFORE MESSAGE | crJ=3 | owned, no Preferences row: second name of QSO BEFORE CW MESSAGE; owned by settings object (Settings.Messages.QsoBeforeCw) but no registration/hand-wired control |
| Options (cfAll) | QSO BEFORE SSB MESSAGE | crJ=3 | owned, no Preferences row: owned by settings object (Settings.Messages.QsoBeforeSsb) but no registration/hand-wired control |
| Options (cfAll) | QSO BY BAND | crJ=2 | B-visible: generated page NAV_CONTESTQSO (key contest.qsoByBand) |
| Options (cfAll) | QSO BY MODE | crJ=2 | B-visible: generated page NAV_CONTESTQSO (key contest.qsoByMode) |
| Options (cfAll) | QSO POINT METHOD | crJ=2 | D-retired: RETIRED_COMMANDS |
| Options (cfAll) | QSO POINTS DOMESTIC CW | crJ=2 | B-visible: generated page NAV_CONTESTQSO (key contest.qsoPointsDomesticCw) |
| Options (cfAll) | QSO POINTS DOMESTIC PHONE | crJ=2 | B-visible: generated page NAV_CONTESTQSO (key contest.qsoPointsDomesticPhone) |
| Options (cfAll) | QSO POINTS DX CW | crJ=2 | B-visible: generated page NAV_CONTESTQSO (key contest.qsoPointsDxCw) |
| Options (cfAll) | QSO POINTS DX PHONE | crJ=2 | B-visible: generated page NAV_CONTESTQSO (key contest.qsoPointsDxPhone) |
| Options (cfAll) | QUICK QSL CW MESSAGE | crJ=2 | B-visible: generated page NAV_CONTESTQUICKQSL (key contest.quickQslCwMessage) |
| Options (cfAll) | QUICK QSL CW MESSAGE1 | crJ=2 | B-visible: second name of QUICK QSL CW MESSAGE; generated page NAV_CONTESTQUICKQSL (key contest.quickQslCwMessage) |
| Options (cfAll) | QUICK QSL MESSAGE 1 | crJ=2 | B-visible: second name of QUICK QSL CW MESSAGE; generated page NAV_CONTESTQUICKQSL (key contest.quickQslCwMessage) |
| Options (cfAll) | QUICK QSL MESSAGE 2 | crJ=2 | B-visible: generated page NAV_CONTESTQUICKQSL (key contest.quickQslMessage2) |
| Options (cfAll) | QUICK QSL SSB MESSAGE | crJ=2 | B-visible: generated page NAV_CONTESTQUICKQSL (key contest.quickQslSsbMessage) |
| Options (cfAll) | R150S MODE | crJ=2 | B-visible: generated page NAV_CONTESTRULES (key contest.r150sMode) |
| Appearance (cfAppearance) | REMINDER | crJ=2 | D-retired: RETIRED_COMMANDS |
| Options (cfAll) | REPEAT S&P CW EXCHANGE | crJ=3 | owned, no Preferences row: owned by settings object (Settings.Messages.RepeatSpExchangeCw) but no registration/hand-wired control |
| Options (cfAll) | REPEAT S&P EXCHANGE | crJ=3 | owned, no Preferences row: second name of REPEAT S&P CW EXCHANGE; owned by settings object (Settings.Messages.RepeatSpExchangeCw) but no registration/hand-wired control |
| Options (cfAll) | REPEAT S&P SSB EXCHANGE | crJ=3 | owned, no Preferences row: owned by settings object (Settings.Messages.RepeatSpExchangeSsb) but no registration/hand-wired control |
| Options (cfAll) | RFOBL MODE | crJ=2 | B-visible: generated page NAV_CONTESTRULES (key contest.rfoblMode) |
| Options (cfAll) | S&P CW EXCHANGE | crJ=3 | owned, no Preferences row: owned by settings object (Settings.Messages.SpExchangeCw) but no registration/hand-wired control |
| Options (cfAll) | S&P EXCHANGE | crJ=3 | owned, no Preferences row: second name of S&P CW EXCHANGE; owned by settings object (Settings.Messages.SpExchangeCw) but no registration/hand-wired control |
| Options (cfAll) | S&P SSB EXCHANGE | crJ=3 | owned, no Preferences row: owned by settings object (Settings.Messages.SpExchangeSsb) but no registration/hand-wired control |
| Options (cfAll) | SHORT 0 | crJ=2 | B-visible: generated page NAV_CWCHARACTERS (key cw.ctrlj.short0) |
| Options (cfAll) | SHORT 1 | crJ=2 | B-visible: generated page NAV_CWCHARACTERS (key cw.ctrlj.short1) |
| Options (cfAll) | SHORT 2 | crJ=2 | B-visible: generated page NAV_CWCHARACTERS (key cw.ctrlj.short2) |
| Options (cfAll) | SHORT 9 | crJ=2 | B-visible: generated page NAV_CWCHARACTERS (key cw.ctrlj.short9) |
| Options (cfAll) | SINGLE BAND SCORE | crJ=2 | B-visible: generated page NAV_CONTESTRULES (key contest.singleBandScore) |
| Options (cfAll) | STEREO CONTROL PORT | no edit arm for ctPortLPT/ckNormal | D-retired: RETIRED_COMMANDS |
| Options (cfAll) | ZONE MULTIPLIER | crJ=2 | D-retired: RETIRED_COMMANDS |

## Not verified

- The block-host width (from the brief, not measured); that a generated row on a VISIBLE page actually renders
  (no running program); that each library editor control saves the value it shows.
- Which value the program reads where a settings property and a library both exist (rotators).
- The `cfRadio1`/`cfRadio2` rows (D7 CAT dialog, outside the Options window) and every other D7 dialog.
- That the refused-line dialog really appears for the three E names (read from code).

Scripts: `parse_d7.py`, `classify.py`, `report.py`, `writemd.py`, `colors.py` in the session scratchpad.
