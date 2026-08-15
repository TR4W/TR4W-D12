# The rows still `csOld` — what needs confirming, and what does not

**The classification already exists: it is `crC`.** `crC:1` means the editor writes the key to the
contest `.CFG`; `crC:0` means `tr4w.ini` (`uOption.pas:765`, `:772`). So the station-vs-event
question is answered per row in `CFGCA` today, and NY4I's read is right — **151 of the 168 rows still
`csOld` are `crC:0`, i.e. not contest-scoped**, against 17 marked `crC:1`.

What follows is therefore not a fresh classification. It is `crC` **checked against what the 74
contest `.cfg` files on this machine actually contain, and against `FCONTEST.PAS`**, because the
rows worth anyone's attention are the ones where those disagree.

### The headline: `crC` under-declares by 38 rows

Counting a row as contest-related if **any** signal says so — `crC:1`, a real `.cfg` sets it, or
`FCONTEST` assigns it on contest selection — gives **55 of the 168**, not the 17 that `crC:1` marks.
The other 113 have no contest signal at all, so the "majority are not contest related" reading is
right; the count is simply higher than the table admits.

The gap is `FCONTEST.PAS`. Rows like `DX MULTIPLIER` (28 assignments), `S&P EXCHANGE` (19),
`CQ EXCHANGE` (18) and `WARC BAND ENABLE` (5) are written in code whenever a contest is selected
while being marked `crC:0`, "write me to `tr4w.ini`". `CFG_COMMAND_TABLE.md` already notes this
class for the 16 keys visible in `.cfg` files; the `FCONTEST` half more than doubles it.

**This is a data defect in `CFGCA`, not merely a documentation gap.** A `crC:0` row that a contest
overwrites gives Preferences an editor whose value is silently replaced at the next contest
selection — the `HF/WARC/VHF BAND ENABLE` problem, but across 38 rows rather than three.

---

## The one thing that needs your eyes — 25 rows marked `crC:0` that contests really do set

These say "write me to `tr4w.ini`" while real contest files set them anyway. **This is the layering
problem**, and it is not confined to `csOld` rows — the list below spans every status, because a row
that already migrated has the same conflict.

A station value and an event value are both legitimate here; what is missing is a rule for which
wins and where an edit lands. `CommandCameFromContestCFG` now gives the read side (a loaded `.cfg`
wins while that contest is loaded); the write side is undecided.

**The evidence column separates a contest DEFINITION from an event copy, and the distinction
matters.** Only one `.cfg` here is a definition (`dom/Idaho QSO Party.cfg`); the other 73 are
per-event files TR4W itself wrote when each log was created. So these 25 rows are really two
different stories:

* **Nine appear in the DEFINITION** — `CONTEST`, `CONTEST NAME`, `CONTEST TITLE`, `DOMESTIC
  FILENAME`, `DOMESTIC MULTIPLIER`, `EXCHANGE RECEIVED`, `MULT BY BAND`, `MULT BY MODE`,
  `QSO POINT METHOD`. These are contest properties by construction and their `crC:0` looks simply
  wrong. Contest-factory rows, not settings.
* **The rest appear only in event copies** — the whole `MY *` family and the CQ/S&P/QSL message set.
  Two of them (`CONTEST`, `MY CALL`) are in *all* 73, which means TR4W writes them into every event
  file and proves nothing about scope. The others are in a SUBSET — `MY STATE` in 26, `MY GRID` in
  12, `S&P CW EXCHANGE` in 9 — and a subset is the interesting part, because something chose to
  record them for those events and not others. **Who wrote them is the question this scan cannot
  answer**, and it is the same station-vs-event line NY4I drew: home state FL, operating from GA.

| command | status | target | in real `.cfg` files |
|---|---|---|---|
| `CONTEST` | `csOld` | `pointer(22)` | **contest DEFINITION** + 73 event copies |
| `CONTEST NAME` | `csOld` | `ContestName` | **contest DEFINITION** + 0 event copies |
| `CONTEST TITLE` | `csOld` | `ContestTitle` | **contest DEFINITION** + 0 event copies |
| `CQ CW EXCHANGE` | `csOld` | `CQExchange` | 8 event copies |
| `CQ CW EXCHANGE NAME KNOWN` | `csOld` | `CQExchangeNameKnown` | 1 event copy |
| `DOMESTIC FILENAME` | `csOld` | `DomQTHDataFileName` | **contest DEFINITION** + 0 event copies |
| `DOMESTIC MULTIPLIER` | `csOld` | `pointer(13)` | **contest DEFINITION** + 0 event copies |
| `EXCHANGE RECEIVED` | `csOld` | `pointer(10)` | **contest DEFINITION** + 0 event copies |
| `MULT BY BAND` | `csOld` | `MultByBand` | **contest DEFINITION** + 0 event copies |
| `MULT BY MODE` | `csOld` | `MultByMode` | **contest DEFINITION** + 0 event copies |
| `MY CALL` | `csOwned` | `MyCall` | **contest DEFINITION** + 73 event copies |
| `MY CHECK` | `csOwned` | `MyCheck` | 2 event copies |
| `MY FD CLASS` | `csOwned` | `MyFDClass` | 6 event copies |
| `MY GRID` | `csOwned` | `MyGrid` | 12 event copies |
| `MY NAME` | `csOwned` | `MyName` | 8 event copies |
| `MY PARK` | `csOwned` | `MyPark` | 5 event copies |
| `MY POSTAL CODE` | `csOwned` | `MyPostalCode` | 1 event copy |
| `MY PREC` | `csOwned` | `MyPrec` | 2 event copies |
| `MY QTH` | `csOwned` | `MyState` | 3 event copies |
| `MY SECTION` | `csOwned` | `MySection` | 8 event copies |
| `MY STATE` | `csOwned` | `MyState` | 26 event copies |
| `QSL CW MESSAGE` | `csOld` | `QSLMessage` | 1 event copy |
| `QSO POINT METHOD` | `csOld` | `pointer(1)` | **contest DEFINITION** + 0 event copies |
| `REPEAT S&P CW EXCHANGE` | `csOld` | `RepeatSearchAndPounceExchange` | 7 event copies |
| `S&P CW EXCHANGE` | `csOld` | `SearchAndPounceExchange` | 9 event copies |

---

## Marked `crC:1` but no `.cfg` on this machine sets it — 13 rows

Declared event-scoped and unexercised by the 74 files here. Most likely genuinely contest-scoped and
simply not used by the contests NY4I runs — **not evidence of anything wrong**, listed only so the
absence is visible rather than assumed.

| command | type | target | in real `.cfg` files |
|---|---|---|---|
| `BAND` | Band | `ActiveBand` *(ListParamArray[24])* | `FCONTEST` assigns it **29×** |
| `HF BAND ENABLE` | Boolean | `HFBandEnable` | `FCONTEST` assigns it **4×** |
| `INITIAL EXCHANGE` | Other | `Pointer(7)` | — |
| `INITIAL EXCHANGE CURSOR POS` | Other | `InitialExchangeCursorPos` *(ListParamArray[6])* | `FCONTEST` assigns it **2×** |
| `INITIAL EXCHANGE FILENAME` | Filename | `TR4W_INITIALEX_FILENAME` | — |
| `INITIAL EXCHANGE OVERWRITE` | Boolean | `InitialExchangeOverwrite` | `FCONTEST` assigns it **4×** |
| `LITERAL DOMESTIC QTH` | Boolean | `LiteralDomesticQTH` | `FCONTEST` assigns it **11×** |
| `QSO NUMBER BY BAND` | Boolean | `QSONumberByBand` | `FCONTEST` assigns it **2×** |
| `SHORT INTEGERS` | Boolean | `ShortIntegers` | — |
| `SINGLE BAND SCORE` | Band | `SingleBand` *(ListParamArray[25])* | — |
| `SPRINT QSY RULE` | Boolean | `SprintQSYRule` | `FCONTEST` assigns it **5×** |
| `TEN MINUTE RULE` | Other | `TenMinuteRule` *(ListParamArray[18])* | — |
| `VHF BAND ENABLE` | Boolean | `VHFBandsEnabled` | `FCONTEST` assigns it **9×** |

---

## Marked `crC:1` and contests do set them — 4 rows

Agreed and uncontroversial. Contest-scoped, no action.

| command | type | target | in real `.cfg` files |
|---|---|---|---|
| `CALLSIGN UPDATE ENABLE` | Boolean | `CallsignUpdateEnable` | **10** — ARRL-DX-CW.CFG, ARRL-DX-SSB.CFG, ARRL-FD.CFG … |
| `MODE` | Other | `ActiveMode` *(ListParamArray[5])* | **1** — ARRL-VHF-JUN.CFG |
| `MULTIPLE BANDS` | Boolean | `MultipleBandsEnabled` | **1** — Idaho QSO Party.cfg |
| `MULTIPLE MODES` | Boolean | `MultipleModesEnabled` | **1** — Idaho QSO Party.cfg |

---

## `crC:0`, no `.cfg` names them, but `FCONTEST` assigns them — 24 rows

**Contest-driven without appearing in any contest file.** Selecting a contest writes these in code,
so a Preferences editor would be silently overwritten. `WARC BAND ENABLE` is the clearest case:
`crC:0`, in no `.cfg`, and assigned five times by `FCONTEST`.

| command | type | target | in real `.cfg` files |
|---|---|---|---|
| `AUTO DUPE ENABLE CQ` | Boolean | `AutoDupeEnableCQ` | `FCONTEST` assigns it **5×** |
| `AUTO DUPE ENABLE S AND P` | Boolean | `AutoDupeEnableSandP` | `FCONTEST` assigns it **4×** |
| `CALL OK NOW CW MESSAGE` | Message | `CorrectedCallMessage` | `FCONTEST` assigns it **4×** |
| `CALL OK NOW MESSAGE` | Message | `CorrectedCallMessage` | `FCONTEST` assigns it **4×** |
| `CONTACTS PER PAGE` | Integer | `ContactsPerPage` | `FCONTEST` assigns it **1×** |
| `COUNT DOMESTIC COUNTRIES` | Boolean | `CountDomesticCountries` | `FCONTEST` assigns it **5×** |
| `CQ EXCHANGE` | Message | `CQExchange` | `FCONTEST` assigns it **18×** |
| `DIGITAL MODE ENABLE` | Boolean | `DigitalModeEnable` | `FCONTEST` assigns it **5×** |
| `DX MULTIPLIER` | Multiplier | `ActiveDXMult` *(ListParamArray[11])* | `FCONTEST` assigns it **28×** |
| `EXCHANGE MEMORY ENABLE` | Boolean | `ExchangeMemoryEnable` | `FCONTEST` assigns it **6×** |
| `PREFIX MULTIPLIER` | Multiplier | `ActivePrefixMult` *(ListParamArray[3])* | `FCONTEST` assigns it **14×** |
| `QSL MESSAGE` | Message | `QSLMessage` | `FCONTEST` assigns it **10×** |
| `QSO BEFORE CW MESSAGE` | Message | `QSOBeforeMessage` | `FCONTEST` assigns it **4×** |
| `QSO BEFORE MESSAGE` | Message | `QSOBeforeMessage` | `FCONTEST` assigns it **4×** |
| `QSO BY BAND` | Boolean | `QSOByBand` | `FCONTEST` assigns it **7×** |
| `QSO BY MODE` | Boolean | `QSOByMode` | `FCONTEST` assigns it **7×** |
| `QTC ENABLE` | Boolean | `QTCsEnabled` | `FCONTEST` assigns it **1×** |
| `QUICK QSL CW MESSAGE` | Message | `QuickQSLMessage1` | `FCONTEST` assigns it **4×** |
| `QUICK QSL CW MESSAGE1` | Message | `QuickQSLMessage1` | `FCONTEST` assigns it **4×** |
| `QUICK QSL MESSAGE 1` | Message | `QuickQSLMessage1` | `FCONTEST` assigns it **4×** |
| `REPEAT S&P EXCHANGE` | Message | `RepeatSearchAndPounceExchange` | `FCONTEST` assigns it **11×** |
| `S&P EXCHANGE` | Message | `SearchAndPounceExchange` | `FCONTEST` assigns it **19×** |
| `WARC BAND ENABLE` | Boolean | `WARCBandsEnabled` | `FCONTEST` assigns it **5×** |
| `ZONE MULTIPLIER` | Multiplier | `ActiveZoneMult` *(ListParamArray[23])* | `FCONTEST` assigns it **4×** |

---

## The remaining 113 — `crC:0`, no `.cfg`, no `FCONTEST` write

The bulk, and the pool future station-settings work draws from. **No confirmation needed** unless one
looks wrong to you; every signal agrees.

| command | type | target | in real `.cfg` files |
|---|---|---|---|
| `ASK FOR FREQUENCIES` | Boolean | `AskForFrequencies` | — |
| `AUTO CALL TERMINATE` | Boolean | `AutoCallTerminate` | — |
| `AUTO DISPLAY DUPE QSO` | Boolean | `AutoDisplayDupeQSO` | — |
| `AUTO QSL INTERVAL` | Integer | `AutoQSLInterval` *(ArrayRecordArray[3])* | — |
| `AUTO QSO NUMBER DECREMENT` | Boolean | `AutoQSONumberDecrement` | — |
| `AUTO RETURN TO CQ MODE` | Boolean | `AutoReturnToCQMode` | — |
| `AUTO S&P ENABLE` | Boolean | `AutoSAPEnable` | — |
| `AUTO S&P ENABLE SENSITIVITY` | Integer | `AutoSAPEnableRate` | — |
| `AUTO SEND CHARACTER COUNT` | Integer | `AutoSendCharacterCount` *(ArrayRecordArray[2])* | — |
| `AUTO TIME INCREMENT` | Integer | `AutoTimeIncrementQSOs` | — |
| `BAND MAP CUTOFF FREQUENCY` | FreqList | `tBandMapCutoffFrequency` | — |
| `BAND MAP SPLIT MODE` | Other | `BandMapSplitMode` *(ListParamArray[14])* | — |
| `BEEP ENABLE` | Boolean | `BeepEnable` | — |
| `BEEP EVERY 10 QSOS` | Boolean | `BeepEvery10QSOs` | — |
| `BROADCAST ALL PACKET DATA` | Boolean | `Packet.BroadcastAllPacketData` | — |
| `CALL OK NOW SSB MESSAGE` | Message | `CorrectedCallPhoneMessage` | — |
| `CALL WINDOW SHOW ALL SPOTS` | Boolean | `CallWindowShowAllSpots` | — |
| `CHECK LOG FILE SIZE` | Boolean | `CheckLogFileSize` | — |
| `CLEAR DUPE SHEET` | Boolean | `ClearDupeSheetCommandGiven` | — |
| `CODE SPEED` | Integer | `CodeSpeed` | — |
| `COLUMN DUPESHEET ENABLE` | Boolean | `ColumnDupeSheetEnable` | — |
| `CONFIRM EDIT CHANGES` | Boolean | `ConfirmEditChanges` | — |
| `COUNTRY INFORMATION FILE` | String | `CountryInformationFile` | — |
| `CQ EXCHANGE NAME KNOWN` | Message | `CQExchangeNameKnown` | — |
| `CQ SSB EXCHANGE` | Message | `CQPhoneExchange` | — |
| `CQ SSB EXCHANGE NAME KNOWN` | Message | `CQPhoneExchangeNameKnown` | — |
| `CUSTOM INITIAL EXCHANGE STRING` | String | `CustomInitialExchangeString` | — |
| `CUSTOM USER STRING` | String | `CustomUserString` | — |
| `DE ENABLE` | Boolean | `DEEnable` | — |
| `DISPLAY REFRESH` | Integer | `DisplayRefresh` | — |
| `DISTANCE MODE` | Other | `DistanceMode` *(ListParamArray[20])* | — |
| `DUPE CHECK SOUND` | Other | `DupeCheckSound` *(ListParamArray[12])* | — |
| `ESCAPE EXITS SEARCH AND POUNCE` | Boolean | `EscapeExitsSearchAndPounce` | — |
| `FREQUENCY MEMORY` | FreqList | `tFrequencyMemory` | — |
| `FREQUENCY MEMORY ENABLE` | Boolean | `FrequencyMemoryEnable` | — |
| `FREQUENCY POLL RATE` | Integer | `FreqPollRate` | — |
| `GRID MAP CENTER` | String | `GridMapCenter` | — |
| `HOUR DISPLAY` | Other | `HourDisplay` *(ListParamArray[8])* | — |
| `IN BAND LOCKOUT` | Boolean | `InBandLock` | — |
| `INCREMENT TIME ENABLE` | Boolean | `IncrementTimeEnable` | — |
| `INSERT MODE` | Boolean | `InsertMode` | — |
| `INTERCOM FILE ENABLE` | Boolean | `IntercomFileenable` | — |
| `LEAVE CURSOR IN CALL WINDOW` | Boolean | `LeaveCursorInCallWindow` | — |
| `LOG FREQUENCY ENABLE` | Boolean | `LogFrequencyEnable` | — |
| `LOG RS SENT` | Word | `LogRSSent` | — |
| `LOG RST SENT` | Word | `LogRSTSent` | — |
| `LOG SUB TITLE` | String | `LogSubTitle` | — |
| `LOG WITH SINGLE ENTER` | Boolean | `LogWithSingleEnter` | — |
| `LOOK FOR RST SENT` | Boolean | `LookForRSTSent` | — |
| `MESSAGE ENABLE` | Boolean | `MessageEnable` | — |
| `MULT REPORT MINIMUM BANDS` | Integer | `MultReportMinimumBands` *(ArrayRecordArray[7])* | — |
| `MULTI INFO MESSAGE` | String | `MultiInfoMessage` | — |
| `MULTI MULTS ONLY` | Boolean | `MultiMultsOnly` | — |
| `MULTIPLIER ITEM WIDTH` | Byte | `MultiplierItemWidth` | — |
| `NAME FLAG ENABLE` | Boolean | `NameFlagEnable` | — |
| `NO LOG` | Boolean | `NoLog` | — |
| `ORION PORT` | Other | `ActiveRotatorPort` *(ListParamArray[40])* | — |
| `PADDLE PORT` | PortLPT | `ActivePaddlePort` | — |
| `PARTIAL CALL ENABLE` | Boolean | `PartialCallEnable` | — |
| `POSSIBLE CALL ACCEPT KEY` | Char | `PossibleCallAcceptKey` | — |
| `POSSIBLE CALL LEFT KEY` | Char | `PossibleCallLeftKey` | — |
| `POSSIBLE CALL MODE` | Other | `CD.PossibleCallAction` *(ListParamArray[4])* | — |
| `POSSIBLE CALL RIGHT KEY` | Char | `PossibleCallRightKey` | — |
| `POSSIBLE CALLS` | Boolean | `PossibleCallEnable` | — |
| `QSL MODE` | Other | `ParameterOkayMode` *(ListParamArray[2])* | — |
| `QSL SSB MESSAGE` | Message | `QSLPhoneMessage` | — |
| `QSO BEFORE SSB MESSAGE` | Message | `QSOBeforePhoneMessage` | — |
| `QSO POINTS DOMESTIC CW` | Integer | `QSOPointsDomesticCW` | — |
| `QSO POINTS DOMESTIC PHONE` | Integer | `QSOPointsDomesticPhone` | — |
| `QSO POINTS DX CW` | Integer | `QSOPointsDXCW` | — |
| `QSO POINTS DX PHONE` | Integer | `QSOPointsDXPhone` | — |
| `QSX ENABLE` | Boolean | `QSXEnable` | — |
| `QSY INACTIVE RADIO` | Boolean | `QSYInactiveRadio` | — |
| `QTC EXTRA SPACE` | Boolean | `QTCExtraSpace` | — |
| `QTC MINUTES` | Boolean | `QTCMinutes` | — |
| `QTC QRS` | Boolean | `QTCQRS` | — |
| `QUESTION MARK CHAR` | Char | `QuestionMarkChar` | — |
| `QUICK QSL KEY 1` | Char | `QuickQSLKey1` | — |
| `QUICK QSL KEY 2` | Char | `QuickQSLKey2` | — |
| `QUICK QSL MESSAGE 2` | Message | `QuickQSLMessage2` | — |
| `QUICK QSL SSB MESSAGE` | Message | `QuickQSLPhoneMessage` | — |
| `RADIUS OF EARTH` | Real | `RadiusOfEarth` | — |
| `RANDOM CQ MODE` | Boolean | `RandomCQMode` | — |
| `RATE DISPLAY` | Other | `RateDisplay` *(ListParamArray[0])* | — |
| `REMAINING MULT DISPLAY MODE` | Other | `RemainingMultDisplayMode` *(ListParamArray[16])* | — |
| `REMINDER` | Other | — | — |
| `REPEAT S&P SSB EXCHANGE` | Message | `RepeatSearchAndPouncePhoneExchange` | — |
| `ROTATOR PORT` | Other | `ActiveRotatorPort` *(ListParamArray[40])* | — |
| `ROTATOR TYPE` | Other | `ActiveRotatorType` *(ListParamArray[17])* | — |
| `S&P SSB EXCHANGE` | Message | `SearchAndPouncePhoneExchange` | — |
| `SHORT 0` | Char | `Short0` | — |
| `SHORT 1` | Char | `Short1` | — |
| `SHORT 2` | Char | `Short2` | — |
| `SHORT 9` | Char | `Short9` | — |
| `SLASH MARK CHAR` | Char | `SlashMarkChar` | — |
| `SPACE BAR DUPE CHECK ENABLE` | Boolean | `SpaceBarDupeCheckEnable` | — |
| `START SENDING NOW KEY` | Char | `StartSendingNowKey` | — |
| `STEREO CONTROL PIN` | integer | `StereoControlPin` *(ArrayRecordArray[8])* | — |
| `STEREO PIN HIGH` | Boolean | `StereoPinState` | — |
| `SWAP PACKET SPOT RADIOS` | Boolean | `SwapPacketSpotRadios` | — |
| `SWAP RADIO RELAY SENSE` | Boolean | `SwapRadioRelaySense` | — |
| `TAIL END CW MESSAGE` | Message | `TailEndMessage` | — |
| `TAIL END KEY` | Char | `TailEndKey` | — |
| `TAIL END MESSAGE` | Message | `TailEndMessage` | — |
| `TAIL END SSB MESSAGE` | Message | `TailEndPhoneMessage` | — |
| `TUNE ALT-D ENABLE` | Boolean | `TuneDupeCheckEnable` | — |
| `UNKNOWN COUNTRY FILE ENABLE` | Boolean | `UnknownCountryFileEnable` | — |
| `UNKNOWN COUNTRY FILE NAME` | String | `UnknownCountryFileName` | — |
| `UPDATE RESTART FILE ENABLE` | Boolean | `UpdateRestartFileEnable` | — |
| `USER INFO SHOWN` | Other | `UserInfoShown` *(ListParamArray[19])* | — |
| `WAIT FOR STRENGTH` | Boolean | `WaitForStrength` | — |
| `WAKE UP TIME OUT` | Integer | `WakeUpTimeOut` | — |
| `WILDCARD PARTIALS` | Boolean | `WildCardPartials` | — |
