# M10 -- the contest-factory endpoint: a staged, measured plan

Repo `c:\tr4w-d12`, branch `contestFactory`, measured at HEAD `de62e724`
(2026-10-14). READ-ONLY: nothing was built, run or edited. Every number has
the command that produced it. The two helper scripts are in
`tools/contest-factory-m10/`, so every count here can be re-measured. Re-measure
before acting on a number; this plan records HEAD `de62e724`, not today:

* `count-ids.ps1 -Ids @(...) [-Lines]` -- per-unit code-only occurrences of
  one identifier at a time, via `tr4w/build/PascalSource.psm1`
  (`Get-PascalCodeOnlyText -BlankStrings`, `Get-TR4WPascalFiles`), so comments,
  strings and `backup/` are excluded. `w=` counts `<id> :=`, `r=` the rest.
  Run as `pwsh -NoProfile -Command "& './tools/contest-factory-m10/count-ids.ps1' -Lines -Ids @('X')"`.
* `orphans.ps1` -- every routine named inside a line range, with its count of
  uses outside that range (same stripper).
* The legacy case's arm labels and `QSOPointMethodType`'s members were listed
  into throwaway text files from code-only lines of `logstuff.pas`; re-derive
  them with the same stripper rather than look for those files.

**Executed in this order, each stage its own gated commit.** Decisions taken
when this plan was adopted (2026-10-14, design §8.2s): S7 is DECIDED, not
held -- the import follows the class, because the class already owns the
county-line rule (Michigan's own header says the row is wrong) and two owners
of one rule is the shape this migration removes. The six multiplier/exchange
KIND enums outlive M10 and move into the classes at **M11** (risk 2 below).

---

## 0. The answer to the decisive question first

**No class reaches the legacy scoring `case`. Deleting it changes no
registered contest's score.** Evidence, three independent checks:

1. `logstuff.pas:6332` `CalculateQSOPoints`: `if ActiveContest(Contest) <> nil
   then ActiveContest(Contest).ScoreQSO(RXData); Exit;` precedes
   `case ActiveQSOPointMethod of` (`:6382`).
2. `uContestFactory.pas:258-285` `ActiveContest` returns nil only when
   `ContestClassFor(aContest) = nil`; 186 `RegisterContest` calls
   (`rg -c -i '^\s*RegisterContest\(' tr4w/src/contestFactory/*.pas | wc -l`)
   against 187 enum members (DUMMYCONTEST is the one without).
3. `TContestBase.CalculateQSOPoints` (`uContestBase.pas:2568-2571`) is
   `aQso.QSOPoints := 0` -- a class that does not override falls through to
   **zero**, never to the engine. No factory unit uses LOGSTUFF:
   `count-ids.ps1 -Ids @('QSOPointMethod','GetQSOPointMethod')` shows the only
   code reader of the trait is `fcontest.pas:811` (ApplyContestTraits); the
   167 `GetQSOPointMethod` hits in `contestFactory` are declarations/bodies.

So the case is reachable **only when `Contest = DUMMYCONTEST`**, and there it
reads an `ActiveQSOPointMethod` that FoundContest never resets
(`fcontest.pas:853`, the head is skipped for DUMMYCONTEST) -- a stale value
from a previous contest or an operator's `QSO POINT METHOD`. That is the only
behaviour the deletion removes (finding F6).

---

## 1. Measurements

### 1.1 The seven `Active*` globals -- declarations, writers, readers

Command: `count-ids.ps1 -Lines -Ids @('ActiveQSOPointMethod','ActiveExchange',
'ActiveInitialExchange','ActiveDomesticMult','ActiveDXMult','ActiveZoneMult',
'ActivePrefixMult')`. Counts are code-only occurrences.

`ActiveBand` / `ActiveMode` are NOT in this set: they are operating state the
radio and the operator change all session long (`logedit.pas:414`,
`logddx.pas:871`); `TSessionDefaults.Band/Mode` only seeds them. They stay.

| global | declared | writers (production) | readers by unit (occurrences) |
|---|---|---|---|
| `ActiveQSOPointMethod` | `logwind.pas:477` | `fcontest:811` (head), `uSettingsEffects:424` (QSO POINT METHOD) | `logstuff:6382` (the legacy case -- the ONLY rule reader); `uContestMatrix:564` |
| `ActiveExchange` | `logwind.pas:472` | `fcontest:530` (session), `:812` (head), `uSettingsEffects:383` | MainUnit 16; logddx 26; logedit 15; logdupe 9 (**3 of them are the PARAMETER `ActiveExchange` of `SetUpExchangeInformation`, decl `:362`/`:1601`, use `:1625` -- a shadow, see F9**); logstuff 4; postunit 3; fcontest 2 (`:396`, `:945` closing `case`); uProgramMain 2; tree 1 (`:2507`, **per log row per repaint**); uScoreTotals 1; uContestMatrix 1 |
| `ActiveInitialExchange` | `logwind.pas:473` | `fcontest:562`, `:813`; `uSettingsEffects:389`, `:507`, `:512` (ZONE MULTIPLIER side effect) | logedit 2 (`:2269` `case`, `:2713`); uContestMatrix 1 |
| `ActiveDomesticMult` | `logdom.pas:86` | `fcontest:534`, `:814`; `uSettingsEffects:465`; `logdom:499` (`DomQTHInit` -- **no caller**, F8) | logdom 8; logstuff 7; logsubs2 4; logdupe 2; LogCfg 1 (`:430` Doing*); logddx 1; logedit 1; postunit 1; MainUnit 1; uProgramMain 1; uScoreTotals 1; uWSJTX 1 (`:231`, main thread via QueueAsyncCall); uContestFactory 1 (`:172`, `EngineIsNewMultiplierAnywhere`); uContestMatrix 1; test `uTestOffBandCredit` r2 w4 |
| `ActiveDXMult` | `VC.pas:4536` | `fcontest:538`, `:815`; `uSettingsEffects:471` | uMults 4; uScoreTotals 2; uEditQSO 2; LogCfg 1; logddx 1; logdupe 1; MainUnit 1; uSettingsEffects 2 more (`:365`, `:476` -- the CTY country-mode derivation, F5); uContestMatrix 1; test `uTestOffBandCredit` r1 w2 |
| `ActiveZoneMult` | `logwind.pas:487` | `fcontest:566`, `:816`; `uSettingsEffects:500` | logedit 4; logstuff 3; postunit 3 (ADIF CQZ/ITUZ); logddx 2; LogCfg 1; logdupe 1; uScoreTotals 1; uSettingsEffects 2 more (`:505`, `:510`); uContestMatrix 1 |
| `ActivePrefixMult` | `logdupe.pas:246` | `fcontest:542`, `:817`; `uSettingsEffects:494` | MainUnit 2; LogCfg 1; logedit 1; uScoreTotals 1; uContestMatrix 1 |

**The inventory's view of the same ground** (`docs/CONTEST_RULES_OUTSIDE_FACTORY.md`
1.1): 186 shape-4 `Active*` proxy rows of 215. **105 of the 215 rows are arms
of the legacy case** (`awk '/^## 4\./,/^## 5\./' docs/CONTEST_RULES_OUTSIDE_FACTORY.md
| rg -o "logstuff\.pas:\d+"` filtered to 6382..9650: 105 inside, 4 outside),
so stage S3 alone removes about half the inventory. The other ~80 proxies are
kind-keyed engine arms (the sheet, the shape parsers, display) that survive
M10 -- see 2.2 and F1.

### 1.2 The tables

Command: `count-ids.ps1 -Lines -Ids @('ContestsArray','ContestsBooleanArray',
'QSOPointMethodArray','USQSOPartyStateName','QSOPartyAreaName','RowFlag')`.

| table | declared | production readers | test / tool readers |
|---|---|---|---|
| `ContestsArray` (`array[ContestType] of TContestInfo`, 187 rows) | `VC.pas:3857` | `uContestBase` 21 (every row-default getter, `GetMarksDupes:2752`, `QSOPartyAreaName:3097`); `VC.USQSOPartyStateName:4572`; `postunit:477` (`ZoneSentForThisContest`, `.ZnM`); **`MainUnit:10184` and `uADIF:1556` (`.CountyLineAllowed`, NOT via the class -- F3)**; `uContestMatrix:376-388` (contest list), `:473` (`countyline.row.allowed`) | `uTestContestFactory` 7; `uTestContestDisplay` 2; `uTestADIFFixtures` 1; **`test/logdump/logdump.lpr:115,116,225` -- built by no gate** (`rg -l -i logdump tr4w/build .github` is empty) |
| `ContestsBooleanArray` (`array[ContestType] of Word`) | `VC.pas:4294` | `uContestBase.RowFlag:2405` (7 set-up getters); **`MainUnit:4512` (ERMAK_BIT)**; **`uHamScore:969` (RTC_CAPABLE_BIT)** | `uTestContestFactory:2514` |
| `QSOPointMethodArray` (spellings) | `VC.pas:3491` | `uSettingsEffects:423`; `uCFG:1698` (vocabulary) | `Lint-SpellingTables.ps1:68` (`'ONY'` baseline) |
| the other six spelling tables of the retiring settings | `ActiveExchangeArray VC:3700`, `InitialExchangeTypeStringArray logwind:446`, `DomesticMultStringArray VC:3478`, `DXMultTypenameArray logdupe:214`, `PrefixMultStringArray VC:3303`, `ZoneMultTypeSA logwind:427` | each: `uSettingsEffects` 1 + `uCFG` vocabulary 1; **`ActiveExchangeArray` also `uADIFExchange:403,413` (two log messages)** | -- |
| `QSOParties` (`array[1..22]`, indexed by the row's `P`) | `VC.pas:3776` | `uContestBase:2460` (InStateDomesticFileName), `:3100` (area name); `VC:4581-4583`; `uContestMatrix:378` | -- |

Bit usage over the 187 rows of `ContestsBooleanArray`
(`awk 'NR>=4294 && NR<=4500' tr4w/src/VC.pas | rg -o "ci\w+?[01]\b" | sort | uniq -c`):
QB1 170, MB1 112, QM1 84, CQZoneMode1 25, Ermak1 24, MM1 23, VHF1 18, CDC1 15, RTC1 12.

**What the matrix sees of those bits** (`rg -o -N "^(setting\.(QSO BY BAND|...)|cty\.zonemode) =" tr4w/test/contest-matrix/frozen | sort | uniq -c`):
QSO BY BAND/MODE, MULT BY BAND/MODE, VHF BAND ENABLE, COUNT DOMESTIC COUNTRIES
and `cty.zonemode` -- **yes**. **ERMAK and RTC -- no line at all**; they need
unit pins (S0).

### 1.3 The traits

Every production read of a kind trait is ONE site, the set-up head:
`count-ids.ps1 -Ids @('ExchangeKind','InitialExchangeKind','DXMultiplierType',
'DomesticMultiplierType','ZoneMultiplierType','PrefixMultiplierType','QSOPointMethod')`
-> `fcontest.pas:811-817` and nothing else outside tests. `IsUSQSOParty`:
`fcontest:861` + `uContestBase:3111`. `MarksDupes`: `logsubs2:1625`.

**Which registered classes still INHERIT a row value from the base.** Overrider
counts (`rg -l -i "function\s+T\w+\.<Getter>\b" tr4w/src/contestFactory/*.pas`,
base excluded): GetQSOPointMethod 167, GetExchangeKind 170, GetInitialExchangeKind
168, GetDXMultiplierType 171, GetDomesticMultiplierType 169, GetZoneMultiplierType
170, GetPrefixMultiplierType 170, GetIsUSQSOParty 153, GetWA7BNMId 171,
GetQRZRUId 169, GetSubmissionEmail 170, GetDomesticFileName 170,
GetFriendlyName/CabrilloName/ADIFContestId 186 (all), GetMarksDupes 2,
GetHostState 21, **GetQSOByBand / QSOByMode / MultByBand / MultByMode /
VHFBandsEnabled / CountsDomesticCountries / ZoneMode / InStateDomesticFileName: 0**.

Resolving inheritance through the family bases (a python walk of
`class(Parent)` and `function T*.Get*` over `contestFactory/*.pas`, comparing
each inherited row value with DUMMYCONTEST's row, i.e. with a neutral default):
**17 contests inherit 100 non-neutral row values** --

| contest | inherited non-neutral row values |
|---|---|
| ARKTIKA_SPRING, ARRLDIGI | QSOPointMethod |
| ARRLFIELDDAY | QSOPointMethod |
| ARRLDXCW / ARRLDXSSB | QSOPointMethod, ExchangeKind, WA7BNMId, QRZRUId, SubmissionEmail |
| ARRLSSCW / ARRLSSSSB | QSOPointMethod, ExchangeKind, InitialExchangeKind, DomesticMultiplierType, WA7BNMId, SubmissionEmail, DomesticFileName |
| CQWPXCW / CQWPXSSB | QSOPointMethod, ExchangeKind, PrefixMultiplierType, WA7BNMId, QRZRUId, SubmissionEmail |
| CQWWCW / CQWWSSB | QSOPointMethod, ExchangeKind, InitialExchangeKind (CW **Custom**, SSB **Zone**), DXMultiplierType, ZoneMultiplierType, WA7BNMId, QRZRUId, SubmissionEmail |
| FLORIDAQSOPARTY, MICHQSOPARTY | QSOPointMethod, ExchangeKind, (DX), DomesticMultiplierType, WA7BNMId, DomesticFileName |
| GENERALQSO | QSOPointMethod, ExchangeKind, InitialExchangeKind |
| IARU | QSOPointMethod, ExchangeKind, InitialExchangeKind, DomesticMultiplierType, ZoneMultiplierType, WA7BNMId, QRZRUId, SubmissionEmail, DomesticFileName |
| NASPRINTCW / NASPRINTRTTY | QSOPointMethod, ExchangeKind, InitialExchangeKind, DXMultiplierType, DomesticMultiplierType, WA7BNMId, SubmissionEmail, DomesticFileName |
| WINTERFIELDDAY | QSOPointMethod, ExchangeKind, DomesticMultiplierType, WA7BNMId, SubmissionEmail, DomesticFileName |

(Three apparent hits -- ARRL FD's DM, the RTTY Roundup's and CQIR's AIE -- are
fields omitted from the row literal, i.e. ordinal 0, i.e. neutral. Excluded.)

Plus, for **all 186**: the seven `ContestsBooleanArray` set-up flags, the
ERMAK and RTC bits, and for the **22** contests with `P <> 0`
(`awk 'NR>=3857 && NR<=4052' VC.pas | rg -o "P:\s*\d+"`) the party index
behind `InStateDomesticFileName`, `QSOPartyAreaName` and `USQSOPartyStateName`.

`Test_MovedRowValuesStillMatchTheArray` (`uTestContestFactory.pas:1774`) has
171 `CheckAgainstArray(` lines (`awk '/^procedure ...Test_MovedRow.../,/^end;/' | rg -c`)
-- ~170 contests -- but compares only the 16 `ContestsArray` getters. It does
**not** cover the Boolean word, ERMAK/RTC, `P`, or `CountyLineAllowed`, and
for an inheriting class it compares the row with itself.

### 1.4 Session value vs trait -- why a reader may NOT simply ask `ContestIdentity`

A python pass over the frozen matrix compared each record's `active.*` line with
the contest's `ContestsArray` row (= its trait, by transcription). **27 contests
run with a session kind different from their trait in at least one variant**:
ALLASIANCW/SSB, ARRL10, ARRL160, ARRLDXCW/SSB, ArizonaQsoParty, CALQSOPARTY,
DARC10M, DARCWAEDCCW/SSB, DELAWAREQSOPARTY, JIDXCW/SSB, KCJ, NEWENGLANDQSO,
OKDX, PACC, RDA, SACCW/SSB, SALMONRUN, SEVENQP, SOUTHAMERICANWW, TEXASQSOPARTY,
WAG, YBDX. Some differ per station (ARRL DX, ARRL 160, Salmon Run, 7QP, Texas,
DARC WAEDC, WAG -- in/out of state or country); the rest differ in **every**
variant (DescribeSession overrides its own trait unconditionally). No variant
differs on `qsopointmethod`. Matching DescribeSession statements:
`rg -l -i "aSession\.(Exchange|DomesticMult|DXMult|PrefixMult|InitialExchange|ZoneMult)\s*:=" tr4w/src/contestFactory`
-> 11 / 14 / 31 / 13 / 4 / 2 files.

**So the kinds are SESSION facts, not identity facts.** A reader repointed to
`ContestIdentity(Contest).ExchangeKind` would silently change 27 contests.

### 1.5 The seven settings -- every site they reach

Spellings from `uSettingsModel.pas:6008-6028`: `QSO POINT METHOD`,
`EXCHANGE RECEIVED`, `INITIAL EXCHANGE`, `DOMESTIC MULTIPLIER`,
`DX MULTIPLIER`, `PREFIX MULTIPLIER`, `ZONE MULTIPLIER`.
Command: `rg -n -i "Contest\.(QsoPointMethod|ExchangeReceived|DomesticMultiplier|DxMultiplier|ZoneMultiplier|PrefixMultiplier|InitialExchange)\b|'(QSO POINT METHOD|EXCHANGE RECEIVED|DOMESTIC MULTIPLIER|DX MULTIPLIER|ZONE MULTIPLIER|PREFIX MULTIPLIER|INITIAL EXCHANGE)'" tr4w/src tr4w/test`.

| where | what | owner |
|---|---|---|
| `uSettingsModel.pas` | 7 published properties (+ setters), 7 `Alias(...)` `:6008-6028` | settings-config |
| `uSettingsDeclarations.pas:452,454,458,462,504,510,655` | 7 `RegisterModelSetting` | settings-config |
| `uSettingsCaptions.pas:144-194` | 7 `RS_CONTEST_*` resourcestrings | i18n |
| `uCFG.pas:1688-1712` | 7 `RegisterSettingAllowedValues` (vocabularies) | settings-config |
| `uCFG.pas:740-766` `SHARED_WITH_PEERS` | all 7 are broadcast to multi-op peers | multi-op-network |
| `uCFG.pas:809` `RETIRED_COMMANDS: array[0..87]` | the destination (+7 -> `[0..94]`) | settings-config |
| `uRadioConfigApply.pas:389-412` `MIGRATED_COMMANDS` | all 7 (ini -> store seeding list) | settings-config |
| `uSettingsEffects.pas:189-201` paths; `:382,388,423,464,470,493,499` arms; `:525` `CONTEST_STATEMENT_PATHS`; `:529` `ReplayContestStatements` (called `fcontest:819`) | the token arms and the M2 replay | settings-config + contest-factory |
| `uSettingsEffects.pas:365-377` (CONTEST arm) and `:476-488` (DX arm) | **`CTY.ctyCountryMode` derived from `ActiveDXMult`** -- the CONTEST half must SURVIVE (F5) | contest-factory |
| `uSettingsEffects.pas:500-513` (ZONE arm) | sets `ctyZoneMode` and `ActiveInitialExchange` as side effects -- dies with the setting | contest-factory |
| `uLogStore.pas:1461` `KeepOnlyStatements`, `:1856` `CheckCommand` reapply; `uLogContestStatements.pas:138-186` capture | stored rows (1.6) | log-database |
| `uSettingsConvert.pas:329` (tr4wconvert) | iterates the MODEL's `CommandNames`, so a retired name in an old ini produces no outcome line at all -- silently skipped, which is acceptable; optional `coRetired` outcome | settings-config |
| `target/commands_help_{eng,esp,cze}.ini` | 10 section matches each (`rg -c -i "^\[?(QSO POINT METHOD|...)\]?"`) | i18n / docs |
| tests | `uTestLogContestStatements:78-82,653-659`, `uTestLogDatabase:497-508`, `uTestStationFactOverrides:199,349`, `uTestSettingsModel:1519` (THE FROZEN VOCABULARY), `uTestContestFactory` (trait reads) | -- |
| lints | `Lint-SpellingTables.ps1:68` (`'QSOPointMethodArray' = @('ONY')`) and **`$minimumTables = 31`** -- six or seven vocabularies leave, so the floor must drop by exactly that many, each named, as its own header demands | build-release |

**Tracked `.cfg` files naming any of the seven: none.** (`git ls-files | rg -i '\.cfg$'`
-> 16 files, each `rg -q -i "^\s*(QSO POINT METHOD|...)\s*="` -> 0 hits.)

### 1.6 Stored statements -- the import path

`python` over `tr4w/test/corpus/*/log.db`: **all 13 hold all 7 rows**, values
`NONE`/`UNKNOWN`, and **none** carries the `configHoldsStatementsOnly` mark --
they are pre-rule logs.

Today: `KeepOnlyStatements` (`uLogContestStatements.pas:248-290`) drops each
because `CommandIsContestScoped` is True and the value equals the constructor
default. **After retirement** the name is unknown to the model, so
`CommandIsContestScoped` is False, the row is KEPT, and `uLogStore.pas:1856`
sends it to `CheckCommand`, which accepts it at `uCFG.pas:1419` as withdrawn
and logs `Info` -- **no modal and no Warn**, which is the requirement. Two
gaps:

* `CaptureContestStatements` iterates `aSettings.CommandNames` (`:155`), so it
  **never deletes** a retired row: the 7 rows live in every old log for ever
  and log 7 Info lines per open. Fix in S2: drop and delete a row whose
  command `CommandIsRetired`.
* A **statement** (non-sentinel, or statements-only log) of one of the seven
  is now silently ignored apart from that Info line. That is NY4I's Q4 ruling;
  the plan only makes it visible (one line naming the setting and value).

`.cfg` path: `LogCfg` shows the modal only when `CheckCommand` returns False;
retired names return True. Covered.

### 1.7 The legacy scoring case

* Range: `logstuff.pas:6382` (`case ActiveQSOPointMethod of`) to `:9650`
  (`end;`), routine ends `:9654` -- 3,269 lines (code-only scan, `arms.txt`).
* **130 arms, one label each; `QSOPointMethodType` has 133 members**; the three
  with no arm are `SouthAmericanQSOPointMethod`, `NYQPQP` and
  `INQSOPoinRMethod` (**spelled with an R** -- search for it that way).
  Command: the code-only label scan vs the enum parsed from `VC.pas:3335`,
  `comm -23 enum2.txt arm2.txt`.
* Routines named inside the case all have callers outside it (`orphans.ps1
  -From 6382 -To 9650`): nothing becomes dead with it except the routine's own
  locals.
* `Lint-ContestNameTests -List`: the one contest-name test inside it is
  `logstuff.pas:8308` (`Contest = RU3AXMEMORIAL`) -> logstuff ceiling 1 -> 0.
  Tree total 7 -> 6, above the lint's floor of 5.
* `$WARN_CEILING = 4` (`Build-App.ps1:180`): one of the four is Ten-Ten's
  `RXData.TenTenNum <> -1` (`logstuff.pas:8542`, design 8.2k) -> expect 3.
  `$NARROW_CEILING = 1271` (`:360`) will fall by an amount only a build
  measures.

---

## 2. What each `Active*` reader becomes

### 2.1 The rule

**Not `ContestIdentity`.** 1.4 shows the value is the SESSION's: trait, then
the operator's token (retiring), then `DescribeSession`. After S2 the operator
layer is gone, so the resolved value is a pure function of
`(contest, CurrentStation)`, computed once in `FoundContest`.

**Home: one session object with one writer.** A class (not a record -- CLAUDE.md)
in a new leaf unit, e.g. `uContestSession.pas` (uses `VC` only, so every TRDOS
unit can use it without a cycle), holding the six resolved kinds:
`Exchange`, `InitialExchange`, `DomesticMult`, `DXMult`, `ZoneMult`,
`PrefixMult`, plus the derived facts that are computed from them today:
`CountsDomesticMults/DXMults/PrefixMults/ZoneMults` (LogCfg's `Doing*`,
`LogCfg.pas:430-433`) and `CountryMode` (F5). Properties read-only; written
only by `FCONTEST.ApplyContestTraits`/`ApplySessionDefaults` through one
`internal` setter (tests use the same setter).

* **Lifetime / threads:** created once at startup, freed at shutdown,
  **never replaced** -- mutated in place by the one writer. A
  free-and-recreate would turn today's benign global read into a
  use-after-free for anything holding a reference. All measured readers are
  on the main thread (`uWSJTX:207` runs from `QueueAsyncCall`).
* **Hot path:** `tree.pas:2507` runs per log row per repaint; a property
  backed by a field is a field read. No virtual, no allocation.
* **This is a re-home, not the death of the kinds.** The kind enums remain the
  engine's vocabulary (sheet, shape parsers) until those arms move into the
  classes -- see F1. The improvement M10 can honestly buy is: seven
  independently writable globals and an operator back-door become one object
  with one writer, resolved once.

### 2.2 Per reader (production)

| reader | today asks | becomes |
|---|---|---|
| sheet / dupe / mult key: logdupe, logddx, logdom, logsubs2, uMults, uEditQSO, MainUnit `ParametersOkay:7287`, `uContestFactory:172` | the kind globals | `Session.<Kind>` -- same value. Reach-1-3 arms stay kind-keyed until M11 (design §8.2l "DECIDED") |
| shape parsing / exchange display: logstuff `:3911,:3918,:10298,:10303`, MainUnit (PerQSOExchString, rover detection, ProcessReturn, ExchangeWindowChange, ParametersOkay `:7118`, SetColumnsWidth), logedit, tree `:2507` | `ActiveExchange` | `Session.Exchange` |
| initial exchange: logedit `:2269`, `:2713` | `ActiveInitialExchange` | `Session.InitialExchange` |
| export: postunit `:2350`, `:3026`, `:3675` (exchange), `:2388` (dom), `:2404-2416` (CQZ/ITUZ) | session globals | `Session.*`. `postunit:477` reads `ContestsArray[Contest].ZnM` -- the ROW, not the session -- see F4 |
| totals: `uScoreTotals:159-164` | 5 globals into `TScoreTotals` | `Session.*` (already data to the class) |
| set-up: `fcontest:396`, `:945`; `LogCfg:430-433`; `uProgramMain:2304`, `:2584` (readiness) | globals | `Session.*`; the four `Doing*` become derived properties of the session |
| `uSettingsEffects:365-377` CONTEST arm | `ActiveDXMult` -> `ctyCountryMode` | the session's `CountryMode`, set in FoundContest's tail -- F5 |
| `uWSJTX:231` | `ActiveDomesticMult = GridFields` | `Session.DomesticMult` (lcl-ui notified) |
| `uContestMatrix:564-570` | globals | `Session.*`; line text identical |
| tests: `uTestOffBandCredit` (writes) | globals | the session's setter |

**Values that are NOT the class's and need the home above:**

1. **Per-station `DescribeSession` statements** (27 contests, 1.4) -- the session.
2. **The operator's tokens** (7 settings) -- deleted at S2, no home (Q4).
3. **Multi-op:** the 7 are in `SHARED_WITH_PEERS`, so a peer's statement
   reaches this station today. After S2 a NEW build neither sends nor applies
   them; an OLD peer's packet lands in `CheckCommand` -> retired -> ignored.
   Mixed-version stations then disagree only where an operator overrode a
   contest -- the intended outcome. Route to `multi-op-network`.
4. **Runtime writers:** `logdom.DomQTHInit` (no caller -- delete);
   `uSettingsEffects` ZONE arm (dies at S2). No other runtime writer exists.
5. **Derived globals computed FROM the kinds:** `CTY.ctyCountryMode` (F5),
   `Doing*` (LogCfg) -- move into the session as derivations.

---

## 3. DUMMYCONTEST

**It needs a guard, not a class.** After S6 the base getters return neutral
constants, and those constants ARE DUMMYCONTEST's row (`VC.pas:3859`:
NoPrefixMults, NoZoneMults, NoInitialExchange, NoDomesticMults, P 0,
UnknownExchange, NoDXMults, NoQSOPointMethod, blank names; Boolean word 0) --
so `ContestIdentity(DUMMYCONTEST)` (already a plain `TContestBase`,
`uContestRegistry.pas:208`) answers correctly with no table. The one site that
needs a decision is `logstuff.CalculateQSOPoints`'s classless path:
`ApplyQSOPointOverride` then `RXData.QSOPoints := 0` (keeps the four
overrides; drops the stale-method read, F6). `FoundContest` already skips
DUMMYCONTEST (`fcontest.pas:853`); `Test_M7bBatch2ContestsAreSiblingsOnTheBase`
keeps "exactly one classless". Pin it in S0.

---

## 4. Stages

Gates for every stage: corpus `24/0/2` AND exit 0; `test-contest-factory.sh`
13 identical; the matrix; `Build-Tests.ps1 -Run` zero failures; lints. "Matrix
identical" means `run-contest-matrix.sh` clean with no re-freeze. Order: pins
and the guard first; the matrix format change isolated; the narrow deletions;
the transcription under its widened pin; the table deletion; and **last the
widest change (the session re-home), when every other pin exists**.

### S0 -- Pins and the guard (no behaviour change)

* **Files:** `test/unit/uTestContestFactory.pas` (widen
  `Test_MovedRowValuesStillMatchTheArray` to EVERY registered contest and add
  the Boolean word bit by bit, `P`/area/in-state file, ERMAK, RTC; a new
  exhaustive pin of class `CountyLineAllowed` vs row, asserting the KNOWN
  six disagreements by name); a DUMMYCONTEST scoring pin;
  new `build/Lint-NoContestTables.ps1` on `PascalSource.psm1` (a typed CONST
  `array[ContestType]` with an initialiser fails) with an allow-list
  `{ContestsArray, ContestsBooleanArray, ContestTypeSA}`, each with the stage
  that removes it; `Run-Lints.ps1` registration next to `Lint-NoRadioTables`;
  a fixture (commented table, var cache, test unit) and a floor (0 files
  scanned fails).
* **Matrix:** identical. **Ceilings:** none. **Risk:** low.
* **Route:** contest-factory, build-release.

### S1 -- The matrix record format (one deliberate re-freeze)

* **Files:** `src/uContestMatrix.pas`; `MainUnit.pas:10184`, `uADIF.pas:1556`,
  `test/logdump/logdump.lpr:225` to call ONE new function
  `ContestAllowsCountyLineOnImport(c)` (initially returning the row's flag --
  no behaviour change); drop `active.qsopointmethod`; rename
  `countyline.row.allowed` -> `countyline.import.allowed` read through that
  function.
* **Matrix:** 580 records change in exactly two lines. Proof before freezing:
  diff old vs new excluding those two keys -> empty. Freeze reason: "record
  format: QSOPointMethod retires at M10; the county-line line names what the
  importer asks". **Never fold another change into this re-freeze.**
* **Risk:** low. **Route:** contest-factory, file-formats (uADIF).

### S2 -- Retire the seven settings (decided behaviour change, Q4)

**DONE 2026-10-14** (on top of `4af8742d`). As planned, with these
corrections and decisions, each measured:

* **The seven:** `QSO POINT METHOD`, `EXCHANGE RECEIVED`, `INITIAL EXCHANGE`,
  `DOMESTIC MULTIPLIER`, `DX MULTIPLIER`, `PREFIX MULTIPLIER`,
  `ZONE MULTIPLIER`. `RETIRED_COMMANDS` `[0..87]`->`[0..94]`;
  `SHARED_WITH_PEERS` `[0..44]`->`[0..37]`; `MIGRATED_COMMANDS`
  `[0..248]`->`[0..241]`; the model's command count 298 -> 291.
* **Lint floor: 31 -> 24, as planned -- but the lint RESOLVED 32 at
  `4af8742d`, not 31.** It resolves 25 now, so the one table of slack
  predates S2 and is kept; the floor fell by exactly the seven named tables.
* **Spelling tables:** six deleted (`QSOPointMethodArray`,
  `DomesticMultStringArray`, `PrefixMultStringArray` in VC;
  `ZoneMultTypeSA`, `InitialExchangeTypeStringArray` in logwind;
  `DXMultTypenameArray` in logdupe). **`ActiveExchangeArray` KEPT**,
  unregistered: its one reader names an exchange kind in a `uADIFExchange`
  log line, and it goes with the kind enums at M11. `'ONY'` baseline removed.
* **Stored rows -- DELETED at the capture, not left inert.**
  `KeepOnlyStatements` sets a retired row aside in BOTH eras (a marked log can
  hold a real pre-ruling statement) and hands it back with its value;
  `uLogStore` logs one Info line per open; `CaptureContestStatements` deletes
  every `source = 'contest'` row a retired name holds, found through
  `LoadContestConfig` because the model's names no longer reach it. The leaf
  is passed `uCFG.CommandIsRetired` rather than linking uCFG. Pinned by
  `uTestLogContestStatements` (`Test_RetiredRowsAreSetAsideInEitherEra`,
  `Test_CaptureDeletesRetiredRowsOnce` -- a second capture is a no-op).
* **F7 fixed: once per name per session.** `CheckCommand` logged every
  occurrence; `uCFG.RetiredCommandFirstSighting` latches it, with the value.
* **Found and fixed: an old PEER's retired command produced a false Warn.**
  `ApplyPeerCommand` sent a name the model does not own to its un-migrated
  branch, which warned "applied but not persisted" for a value never applied.
  It now routes a retired name to `CheckCommand` and stops.
* **The checked gate failed on S2 with a heaptrc FALSE POSITIVE, not a heap
  defect.** S2's code changes moved the return addresses so that the
  `IndexOfName` temp in `BuildCommandMap` (size 34) got the CRC-32 signature
  `$AAAAAAAA`, which is heaptrc's own "released" marker. That gave a
  "freed again" on a live block and a halted run. Verified arithmetically
  from the report. `Build-Tests.ps1` now runs `HEAPTRC=nohalt` and excuses
  ONLY a report whose recomputed signature is `$AAAAAAAA`
  (`build/HeaptrcReport.ps1`, self-checked against this block).
* **NOT done:** the help `.ini` sections (`target/commands_help_*.ini`, all
  seven languages carry the seven) are left -- they are an i18n catalogue
  `ini2po` harvests, and an unreachable section is inert; and the `.po`
  entries of the seven deleted `RS_CONTEST_*` captions are orphaned and left
  for the catalogue tooling (a note in `uSettingsCaptions` says so; `pas2po`
  never). `tr4wconvert` needs no change: it walks
  the model's names, so a retired ini key is never reported or carried
  forward.

As planned:

* **Files:** `uSettingsModel` (7 properties, 7 aliases), `uSettingsDeclarations`
  (7), `uSettingsCaptions` (7), `uCFG` (7 vocabularies; `SHARED_WITH_PEERS`
  -7, bound `[0..44]`->`[0..37]`; `RETIRED_COMMANDS` +7, `[0..87]`->`[0..94]`),
  `uRadioConfigApply.MIGRATED_COMMANDS` (-7, bound 248->241),
  `uSettingsEffects` (7 arms, the 7 paths, `CONTEST_STATEMENT_PATHS`,
  `ReplayContestStatements`; **keep the CONTEST arm's country-mode
  derivation**), `fcontest.pas:819` (the replay call), the six/seven spelling
  tables (`uADIFExchange:403,413` switch to the enum's RTTI name, or keep
  `ActiveExchangeArray` until M11 -- decide; the plan assumes delete),
  `uLogContestStatements` (`KeepOnlyStatements` drops and the capture deletes
  any `CommandIsRetired` row), `uLogStore` comment, help `.ini` sections,
  `docs/SETTINGS_INVENTORY.md` (regenerate), `Lint-SpellingTables.ps1` (floor
  31 -> 24 naming each table; remove the `'ONY'` baseline).
* **Tests:** frozen vocabulary in `uTestSettingsModel` (deliberate edit);
  `uTestLogContestStatements` re-pointed at another contest-scoped token for
  the D2 rules, plus: a retired row (sentinel AND statement, both log eras)
  loads with no Warn, no modal, is ignored, and is deleted by the next
  capture; `uTestLogDatabase`, `uTestStationFactOverrides` names.
* **Matrix:** identical (no variant states any of the seven -- `rg` of
  `frozen/` for `setting.<name>` finds none). Corpus identical; its
  `tr4w.log` gains Info lines then loses them after capture.
* **Risk:** medium -- wide settings surface, three silent-loss traps
  (MIGRATED_COMMANDS, the vocabulary floor, stale stored rows), all pinned
  above. **Route:** settings-config, log-database, multi-op-network, i18n
  (resourcestrings, help ini), build-release (lint floor).

### S3 -- Delete the legacy scoring case (7.15, Q11)

**DONE 2026-10-14** (on top of `f0716521`). Re-measured first: the case was
still `logstuff.pas:6382-9650`, the routine `:6332-9652`. As planned, with
these corrections:

* **The guard** is section 3's: `RXData.QSOPoints := 0`, the class's
  `ScoreQSO` and `Exit` when `ActiveContest(Contest) <> nil`, else
  `ApplyQSOPointOverride(CurrentQSOPointOverrides, RXData)` and nothing more.
  Every local of the routine went (none is read by the guard).
* **Correction to 1.7 -- three UNITS became dead with it, not only locals.**
  `orphans.ps1` lists routines, and every routine the case named does have a
  caller outside it (re-checked case-insensitively over `tr4w/`, tests and
  `.lpr` included: `MarineOrAirMobileStation`, `RTCGridDistance`,
  `IsDmMult`, `LooksLikeAGeoCoordinates`, `GetRussiaOblastByTwoChars` and the
  rest are all called by classes or other engine code). But three entries of
  logstuff's `uses` were used ONLY by the case and are removed: `Math`
  (`Floor`, `Ceil`, `ln` -- every identifier in `math.pp`'s interface was
  checked against the rest of the unit), `uRussiaOblasts`
  (`GetRussiaOblastByTwoChars`, `RussianRegionType`) and
  `uRFChampionshipPoints` (`RFChampionshipPoints`). The units themselves
  stay: classes use them.
* **Provenance comments reworded**, not deleted: 66 comments in factory
  units cited "LOGSTUFF.CalculateQSOPoints's arm" (or "one arm of"), and 18
  more sites (units, tests, `uRFChampionshipPoints`) said an arm "is
  reached", "stays" or "is written"; each now says the arm was
  deleted at M10 S3 and points at git history / the D7 tree.
* **`Lint-ContestNameTests`:** logstuff 1 -> 0 (unlisted), total 7 -> 6 in 3
  files, floor kept at 5.
* **Build ceilings NOT lowered here** -- left for the full build to measure.
  Expected to go: the range warning at HEAD `logstuff.pas:8542`
  (`RXData.TenTenNum <> -1`, design 8.2k), so `$WARN_CEILING` 4 -> 3, and
  every implicit narrowing inside the deleted lines.
* **`ActiveQSOPointMethod` is now read NOWHERE** (`count-ids.ps1`: one write,
  `fcontest.pas` ApplyContestTraits; the other hit is its declaration in
  `logwind`). S4 deletes it with the trait.
* **Behaviour:** for a DUMMYCONTEST session a stale point-method read became
  "the overrides, then 0" -- decided (section 3, F6).

* **Files:** `trdos/logstuff.pas` only: the case `:6382-9650`, unused locals,
  classless path = overrides then 0 (section 3).
* **Matrix:** identical (DUMMYCONTEST is not in the matrix; every matrix
  contest has a class -- section 0). `test-contest-factory.sh` identical.
* **Ceilings:** `Lint-ContestNameTests` logstuff 1 -> 0; `$WARN_CEILING`
  4 -> 3 (measure); `$NARROW_CEILING` lower by the measured amount.
  Regenerate `CONTEST_RULES_OUTSIDE_FACTORY.md` after the commit (~105 rows go).
* **Risk:** low (proven unreachable for any class). **Route:** contest-scoring.

### S4 -- Delete QSOPointMethod as a concept

**DONE 2026-10-14** (on top of `bf25d7dd`). Re-measured first
(`count-ids.ps1`): `ActiveQSOPointMethod` one write (`fcontest`
ApplyContestTraits) and its declaration (`logwind`), no reader;
`.QSOPointMethod` read only there and in two tests; every
`QSOPointMethodType` member named only in `VC.pas`, the getter bodies and
`uTestContestFactory` (a scan of all 133 members). As planned, with these
corrections:

* **Deleted:** `GetQSOPointMethod` in 167 leaf units and the base (declaration
  and body, 168 of each -- the compiler would have refused a survivor), the
  `QSOPointMethod` property, `ActiveQSOPointMethod` and its one writer, the
  enum (133 members), the `QP` field of `TContestInfo` and **its column in all
  187 rows** -- done now rather than left to S8, because removing one field
  from a typed constant is a per-row regex. **Trap:** two rows, Idaho and
  Delaware, start `(Email:` with no `{Name: ...}` comment, so a match keyed on
  the name comment misses them; the compiler would have said so.
* **`MarksDupes` -> `True` in the base, proved equal for every contest.** At
  `bf25d7dd` the base answered `row.QP <> AlwaysOnePointPerQSO`. Exactly two
  rows held `AlwaysOnePointPerQSO` -- `VC.pas:3751` INTERNETSPRINT (ordinal
  55) and `:3831` SRR-JR = YOUTHCHAMPIONSHIPRF (ordinal 135; one commented-out
  WWDIGI row sits in between, and the enum's ordinals were checked against
  it). `GetMarksDupes` has exactly two overriders, those two classes, both
  returning the constant False; nothing else overrides it (the IN7QPNE
  composite and its components inherit). So every other contest, DUMMYCONTEST
  (`NoQSOPointMethod`) included, answered True, and the two answer False
  before and after.
* **Tests:** `Test_MovedRowValuesStillMatchTheArray` drops the QP and the
  MarksDupes comparisons (no row value derives either now) and keeps the
  rest. `Test_MarksDupesIsTheRowsDupePolicy` is
  `Test_EveryContestMarksDupesButTheTwoThatIgnoreThem`: every ContestType,
  the two named, DUMMYCONTEST asserted True. NRAU-Baltic's
  `Ord(TwoPointsPerQSO)` check is deleted -- its four `PointsFor` checks
  already pin 2 points per mode.
* **Tooling:** the inventory's `TRAIT_GETTERS` and `ACTIVE` maps lose their
  QP entries and the render text its getter name; the generator runs and
  changes only line numbers (logdupe +1). `Lint-SpellingTables` (25 tables)
  and `uContestMatrix` named the enum in comments only. `settings_inventory*`
  never named it.
* **Comments:** `logdupe`'s off-band note pointed at
  `LOGSTUFF.CalculateQSOPoints` for the points half -- it has been
  `TContestBase.ScoreQSO` since M3. Base, two class headers, `logsubs2`,
  `fcontest` and `uContestMatrix` reworded to the past tense. The row
  transcriptions in each unit's header (`QP: ...` inside a comment) stay as
  history of the row the class was transcribed from.
* **Not done:** the matrix, corpus, factory check and full build are left
  to the gated run. The incremental app compile died with the known
  "Internal error 200306067" at `MainUnit.pas(45,1)`; the unit-test build
  (every factory unit, VC and the touched engine units) is clean.

As planned:

* **Files:** `GetQSOPointMethod` in the 167 overriding units and the base,
  the `QSOPointMethod` property, `ActiveQSOPointMethod` (`logwind:477`,
  `fcontest:811`), `QSOPointMethodType` (`VC.pas:3335`) and `QSOPointMethodArray`
  if S2 left it, the `QP` column of `TContestInfo` (or leave the column to S8);
  `GetMarksDupes` -> `True` constant (the only two `AlwaysOnePointPerQSO` rows,
  `VC.pas:3916` and `:3996`, are exactly the two overriders --
  Internet Sprint and Youth Championship RF). Tests reading `.QSOPointMethod`.
* **Matrix:** identical (its line left at S1). **Risk:** low, mechanical,
  167-file diff -- review by the compiler (an override of a deleted virtual
  fails to compile, so none can be missed).
* **Route:** contest-factory.

### S5 -- Every class states what it still inherits (transcription)

**DONE 2026-10-14** (on top of `8668cf0f`). Re-measured first with the
inventory's own reader (`tools/contest-rules-inventory/model.py` over a fresh
`dump-code-only.ps1` dump: each registered class's chain, which ancestor
implements which getter, every row compared with the neutral DUMMYCONTEST
row). After S4 the inherited non-neutral values were **82 row values in 15
contests** (the plan's 100 in 17 less the 17 QP values, and less Michigan's
"(DX)", which is neutral; ARKTIKA_SPRING, ARRLDIGI and ARRL Field Day had
inherited only QP) **plus 22 `InStateDomesticFileName`s** -- 104 -- and every
class's nine flag bits. **No class inherited `IsUSQSOParty` or `HostState`**:
all 22 contests with a `P` already stated both. After the edit the same scan
reports **0** inherited non-neutral values, every contest's chain implements
`GetFlags`, and every party's chain implements `GetQSOPartyArea`.

* **The flags API (DECIDED):** `TContestFlag = (cfQSOByBand, cfQSOByMode,
  cfMultByBand, cfMultByMode, cfErmakSpecification, cfVHFBandsEnabled,
  cfCQZoneMode, cfCountsDomesticCountries, cfRTCCapable)` -- declared in bit
  order -- and `TContestFlags = set of TContestFlag`, stated through ONE
  protected virtual `GetFlags: TContestFlags`, published as the read-only
  property `Flags`. Named `Flags`, not `SetUpFlags`, because two members
  (ERMAK, RTC) are not set-up facts. The nine per-flag getters and
  `GetZoneMode` are now **non-virtual** and answer from the set (none was
  ever overridden), so a contest cannot state a flag twice or contradict
  itself; every reader and every property name is unchanged. The base's
  `GetFlags` reads the row's word through a named bit table (`FLAG_BIT`), not
  the members' ordinals, until S6 makes it `[]`; the private `RowFlag` is
  deleted. The radio factory's `TRadioCapabilitySet` is the model.
* **Where the values went.** The 82 row values: **in the leaf**, as this
  stage specified (the M9a rule). The flag sets: in the leaf for 176
  contests, and **once on the family base for the five CW/SSB pair families**
  (ARRL DX, ARRL SS, CQ WPX, CQ WW, NRAU-Baltic) -- both members' words were
  equal, and the set is the contest's rule run in two modes, which is what
  those families are for. The state-party family states per leaf (its
  members' words differ). Four leaves and the ARRL SS base state `[]`
  (ARRL 160, County Hunter, QCWA Golden, Stew Perry).
* **Party data (DECIDED): the classes state strings; the `QSOParties` index
  is not carried into the classes.** Each of the 22 states its
  `InStateDomesticFileName` in its leaf. The area the New Contest prompt
  names became a class property, `QSOPartyArea` (`GetQSOPartyArea`; base:
  the table, through `QSOPartyAreaName`). On `TContestStateQSOPartyBase` it
  is `HostState` -- a family rule (a single-state party's area IS its state),
  so 19 classes do not restate a fact they already state; British Columbia
  (`'VE7'`), 7QP (`'7th area'`) and IN7QPNE (`'IN7QPNE'`) state theirs.
  Named `QSOPartyArea` because the implementation-only free function
  `QSOPartyAreaName(aContest)` still exists and a property of that name
  would hide it inside the class; S6 repoints `DescribeNewContestPrompts` to
  the property and deletes the function. With every party stating `IsUSQSOParty`,
  `HostState`, its in-state file and its area, S8 can delete `QSOParties`.
* **The pin.** `Test_MovedRowValuesStillMatchTheArray` gained ONE comparison
  -- `cls.QSOPartyArea` against the entry's `StateName` -- because the new
  property would otherwise be unpinned; no expectation changed and BCQP's
  `HostState` is still its one named mismatch. **Unit run: 88297 passed,
  0 failed.**
* **Uses clauses.** Eight pair leaves (ARRL DX x2, ARRL SS x2, CQ WPX x2,
  CQ WW x2) now name kind enums in their interface, so `VC` moved from their
  implementation `uses` to their interface `uses`; Indiana, Michigan and
  Pennsylvania gained `uContestBase` in theirs (`TContestFlags`).
* **Row values that look odd, transcribed as-is (questions, not changes):**
  Minnesota is the only party whose word sets `RTC_CAPABLE_BIT` (291);
  IN7QPNE's prompt "area" is the token `'IN7QPNE'`, not a place, so the New
  Contest prompt names it twice; the NA Sprint CW and RTTY rows name
  different domestic files (`naqp` vs `s49p8`).
* **Docs, same change:** `ADDING_A_CONTEST.md`'s trait table (a new class
  states `GetFlags`; `QSOPartyArea`), the contest-factory agent, the base's
  comments.
* **Not done:** the matrix, corpus, factory check, lints and a full build
  (the gated run). The incremental app compile stopped at the known
  "Internal error 200306067" (`MainUnit.pas(60,1)`); the unit-test build
  (every factory unit) is clean. The contest-rules inventory needs no
  regeneration for a missing seam, but its line numbers moved -- regenerate
  after the commit.

As planned:

* **Files:** the 17 contests of 1.3 state their 100 values IN THE LEAF (the
  M9a rule for identity, applied to every row value -- not on family bases);
  the seven set-up flags plus ERMAK and RTC for all 186, **recommended as ONE
  protected virtual returning a set** -- `GetSetUpFlags: TContestSetUpFlags`,
  the shape of the radio factory's capability flags -- rather than nine
  getters x 186 classes; public properties keep their names; the 22 party
  classes state `InStateDomesticFileName` and the area name (or a party index,
  if the `QSOParties` table is kept as data -- decide).
* **Pin:** S0's widened test proves class == row for every field and bit.
  **Matrix:** identical. **Risk:** medium (volume; every mistype is caught by
  the S0 pin or the matrix -- ERMAK/RTC only by the pin).
* **Route:** contest-factory.

### S6 -- The base stops reading the tables; every outside reader asks the class

**DONE 2026-10-14** (on top of `337656c3`). Re-measured first
(`count-ids.ps1 -Lines -Ids @('ContestsArray','ContestsBooleanArray','QSOParties','QSOPartyAreaName','USQSOPartyStateName')`
over all of `tr4w/`, tests, `.lpr` and tools included). As planned, with these
corrections and decisions:

* **The neutral constants, field by field against DUMMYCONTEST's row**
  (`VC.pas` `ContestsArray[DUMMYCONTEST]` and `ContestsBooleanArray[DUMMYCONTEST]`):
  `CABName ''`/`ADIFName ''`/`FriendlyName ''` -> the base answers the
  enum's spelling, which is what the two-step gave for a blank; `WA7BNM 0000`
  -> 0; `QRZRUID 0` -> 0; `Email ''`, `DF ''` -> `''`; `PxM NoPrefixMults`,
  `ZnM NoZoneMults`, `XM NoDXMults`, `DM NoDomesticMults`,
  `AIE NoInitialExchange`, `AE UnknownExchange` -> those members by name;
  `P 0` -> `IsUSQSOParty` False, `HostState`, `InStateDomesticFileName` and
  `QSOPartyArea` `''` (each of the three table readers answered `''` for
  `P = 0`); the word `ciCDC0 + ciCQZoneMode0 + ciVHFEnabled0 + ciErmak0 +
  ciQB0 + ciQM0 + ciMB0 + ciMM0` (every `ci*0` is `= 0`, no RTC term) -> `Flags`
  `[]`, so `ZoneMode` stays `ITUZoneMode`. `CountyLineAllowed` is omitted from
  the row (False) and is not a base getter (S7). `uContestBase` now reads no
  table; `ContestTypeSA` stays.
* **`USQSOPartyStateName` and `QSOPartyAreaName` are DELETED** (VC and the base).
  `DescribeNewContestPrompts` asks `QSOPartyArea`.
* **CORRECTION -- `uADIF:1437` must NOT become `HostState`.** It would change
  British Columbia's export: the class states `HostState` `'BC'` (S5's named
  pin mismatch) while its area -- the table's `StateName` -- is `'VE7'`, so
  `GetStateForContest` would start writing `<STATE:2>BC` (and `CNTY`) on every
  BCQP QSO, and the frozen `BCQP.matrix` has none. It asks the class's
  `QSOPartyArea` with the SAME two-letter test the deleted function applied --
  equal to the table read for every contest, because the S0 pin holds
  `QSOPartyArea` = `StateName`. **Open for NY4I:** ADIF's STATE carries a
  Canadian province, so `BC` is probably right; it is a decision, not a side
  effect of S6. `uContestBritishColumbiaQP`'s header says the same.
* **CORRECTION -- `postunit:477` is repointed to the CLASS, not the session.**
  This section said "the session's zone kind (F4)". The class's value equals
  the row's (S0 pin), so `ContestIdentity(Contest).ZoneMultiplierType` changes
  nothing; the session would be a behaviour change folded into a table
  removal. **F4 stands, for S9:** `ZoneSentForThisContest` asks the
  contest's zone kind and the ADIF CQZ/ITUZ block (`postunit` `ActiveZoneMult`)
  the session's -- two answers to one question. Recorded in the routine's
  header and in `known-divergences.txt`'s IARU note.
* **The matrix's contest list changed in one field, its records in none.**
  Field 4 was the row's party index `P`; the class carries no index, so it is
  `1`/`0` from `IsUSQSOParty`. `matrix-lib.sh` only ever tests it `!= "0"`
  and `IsUSQSOParty = (P <> 0)` for every contest (S0 pin), so the same
  variants run. `DF` -> `DomesticFileName`, host -> `QSOPartyArea` (both
  pinned equal). The list is a scratch file, not a frozen record.
* **Outside readers repointed:** `MainUnit` ERMAK menu ->
  `ContestIdentity(Contest).ErmakSpecification`; `uHamScore.ContactInfoUploadAllowed`
  -> `ContestIdentity(RXData.ceContest).RTCCapable` (after the `oaScorePosting`
  gate, untouched); `postunit.ZoneSentForThisContest`; `uContestMatrix`'s
  `/MATRIXLIST`; `uADIF.GetStateForContest`.
* **Tests that asked a plain `TContestBase` for a ROW value** -- found by
  reading every `TContestBase.Create(` in the tests, because after S6 the base
  answers neutral and such a check would either fail or pass vacuously:
  `Test_FieldDayHasNoDXMultiplier` and `uTestContestSession`'s Field Day check
  read `ContestsArray[..].XM` directly (S8 deletes those lines);
  `Test_NRAUAndJockWhiteRowsAreNotShifted` asks the registered class.
  `Test_HostStateDerivationIsTheOneTable`, Idaho's and Delaware's checks
  repointed from `USQSOPartyStateName` to `HostState` and
  `GetStateForContest` -- including BCQP: HostState `'BC'`, export `''`.
* **No class was relying on the base's table read**: the S0 pin is green with
  the base neutral. **Unit run: 88307 passed, 0 failed.**
* **Table readers left after S6** (code-only): `VC.pas` (the three
  declarations); `uContestRegistry.ContestAllowsCountyLineOnImport` (S7);
  `uADIF.ResolveRoverCall` `.CountyLineAllowed` (S7 decides); tests --
  `Test_MovedRowValuesStillMatchTheArray` (the S0 pin), the county-line pins
  (`Test_MichiganForbidsCountyLineAgainstTheArray`, the class-vs-row
  county-line test), `Test_IdentityIsWhatTheExportersWroteBeforeM1`,
  `Test_ZoneModeIsCQOrITUForEveryContest`, `Test_FieldDayHasNoDXMultiplier`,
  `uTestContestSession`'s Field Day check, `uTestContestDisplay.ExpectedHead`,
  `uTestADIFFixtures`; `test/logdump/logdump.lpr` (S8, ungated). Tooling:
  `Lint-DomCoverage.ps1` and `tools/contest-rules-inventory/model.py` PARSE
  `VC.pas`'s tables -- S8 must give them another source.
* **Not done:** the matrix, corpus, factory check, `Run-Lints` and a full build
  (the gated run). The incremental app compile stopped at the known
  "Internal error 200306067" (`MainUnit.pas(491,1)`), so `uContestMatrix` and
  its whole cone (MainUnit, postunit, uHamScore) were compiled separately
  with the App search paths into a scratch directory: 0 errors.
  `Lint-NoContestTables` (3 of 3 allow-listed tables found) and
  `Lint-ContestNameTests` (6 in 3 files, no rise) were run on their own.
  Regenerate the contest-rules inventory after the commit.

As planned:

* **Files:** `uContestBase` getters -> neutral constants (DUMMYCONTEST's row;
  name getters -> `ContestTypeSA` spelling); `MainUnit:4512` ->
  `ContestIdentity(Contest)` ERMAK flag; `uHamScore:969` -> RTC flag;
  `VC.USQSOPartyStateName` and its reader `uADIF:1437` -> `HostState`;
  `QSOPartyAreaName`; `uContestMatrix:376-388` contest list from the class;
  `postunit:477` -> the session's zone kind (F4). JIDX CW/SSB are the only
  classes stating `ZoneMult` in DescribeSession, and 1.4 found no matrix
  variant whose session zone kind differs from the row, so the matrix should
  stay identical -- and is the check.
* **Matrix:** identical. **Risk:** low-medium. **Route:** contest-factory,
  file-formats (uADIF, postunit), integrations (uHamScore), lcl-ui (MainUnit Ermak).

### S7 -- County-line import asks the class (BEHAVIOUR CHANGE -- DECIDED 2026-10-14, see the header)

**DONE 2026-10-14** (on top of `c3c70be5`). As planned for the import, with
the export question decided on its own evidence:

* **The import.** `uContestRegistry.ContestAllowsCountyLineOnImport` now answers
  `ContestIdentity(c) is TContestStateQSOPartyBase` and that class's
  `CountyLineAllowed`; any other contest answers False (the row said False for
  every non-party). `MainUnit.pas` (the `ceClearDupeSheet` site) is its ONLY
  production caller besides the matrix line -- re-checked with
  `rg -i ContestAllowsCountyLineOnImport tr4w`. Michigan stops; Arizona, BC,
  Virginia, Salmon Run and New York start.
* **The rover export is NOT repointed, and the reason is evidence.**
  `uADIF.ResolveRoverCall` asks a different question than a county line: its
  own comment says "only relevant for state-QP exchanges", and it splits a
  call such as `KG1S/MON` when the suffix equals the QSO's QTH, writing
  `APP_TR4W_ROVERCALL`. A ROVER and a COUNTY-LINE contact are different things
  (a rover moves between counties; a county line is one transmission claimed
  by two counties), and the row's boolean was only ever a stand-in for "is a
  state party". The import's rover strip (`MainUnit.ctyLocateCallStripRover`)
  and the import's reading of `APP_TR4W_ROVERCALL` do not consult the flag at
  all, so repointing export at the class would make Michigan's rovers import as
  rovers and export as plain `W8XYZ/KENT` calls: a lossy round trip for a
  party whose sponsor DOES allow rovers (Michigan's header only disclaims the
  county line). The class has no property answering "does a /COUNTY suffix name
  a rover", and the row's answer (15 parties) is not any class property the
  other way round either (the class set is all 20). **So export is unchanged
  and the row's reader stays, recorded as the only remaining production reader
  of `ContestsArray[..].CountyLineAllowed`; S8 cannot delete the field until
  NY4I answers Q90** (new, in `CONTEST_FACTORY_OPEN_QUESTIONS.md`). The corpus
  is unaffected either way (only the Florida set has a rover call).
* **Tests.** `Test_CountyLineRowAndClassDisagreeOnlyForTheKnownSix` keeps its
  six-disagreement pin and now ALSO asserts, for every contest, that
  `ContestAllowsCountyLineOnImport` equals the class's answer, with explicit
  Michigan (False) and Arizona/BC/Virginia/Salmon Run/New York (True) checks.
  `ceClearDupeSheet` itself is set inside `MainUnit`'s import routine, which no
  unit test reaches; the seam it asks is what is pinned. S0's table pin is
  untouched and green. Unit run: 88499 passed, 0 failed.
* **Matrix prediction:** `countyline.import.allowed` moves for exactly six
  contests and nothing else: `MICHQSOPARTY` true -> false; `ArizonaQsoParty`,
  `BCQP`, `VAQP`, `SALMONRUN`, `NYQP` false -> true. Export lines do not move
  (export still reads the row).
* **`test/logdump/logdump.lpr:225` is unchanged** (S8's, by hand).

* **Files:** `ContestAllowsCountyLineOnImport` -> `TContestStateQSOPartyBase(..).CountyLineAllowed`.
* **Effect, measured:** row True for 15 parties (`rg -n -i "CountyLineAllowed: True" VC.pas`);
  class True for 19 of 20 party classes (`GetCountyLineCountiesMax` overrides:
  Michigan 0, the rest 2 or 4 or unlimited). Changes: **MICHQSOPARTY stops**
  clearing the dupe flag (its header calls the row wrong);
  **ArizonaQsoParty, BCQP, VAQP, SALMONRUN, NYQP start**.
* **Matrix:** exactly those six contests' `countyline.import.allowed` lines
  move; re-freeze those records only, reason "S7, county-line import asks the
  class". Unit pin on the import's `ceClearDupeSheet` for one contest each way.
* **CORRECTION (S0/S1, 2026-10-14): `uADIF:1556` is NOT an import site.** It
  is `ResolveRoverCall`, called from `EmitADIFRecord` -- it builds a rover's
  callsign on EXPORT. Repointing it through `ContestAllowsCountyLineOnImport`
  would make S7 change the ADIF EXPORT of the six contests. S1 left it reading
  the row; S7 decides it on its own evidence. `test/logdump/logdump.lpr:225`
  also still reads the row: it links only `VC` and `uLogBinaryFile`, and no
  gate builds it -- S8 must fix it by hand.
* **Risk:** medium (silent dupe acceptance/refusal on import).
  **Route:** contest-factory, file-formats, log-database (import).
  Can run any time after S1; must precede S8.

### S8 -- Delete the tables

**DONE 2026-10-14** (on top of `9dc93f67`). Re-measured first
(`count-ids.ps1 -Lines -Ids @('ContestsArray','ContestsBooleanArray','QSOParties','TContestInfo','CountyLineAllowed')`
plus `rg -i` over all of `tr4w/` and `tools/`): code readers were `VC.pas`
(the declarations), `uADIF.ResolveRoverCall`, `test/logdump/logdump.lpr`
(three), and the tests `uTestADIFFixtures`, `uTestContestDisplay` (two),
`uTestContestFactory` (twelve) and `uTestContestSession`; tooling
`Lint-DomCoverage.ps1`, `tools/contest-rules-inventory/model.py` and the
one-shot `tools/gen_friendly_names.py`. As planned, with these decisions:

* **Deleted:** `ContestsArray`, `TContestInfo`, `ContestsBooleanArray`, the
  `ci*` / `*_BIT` constants, `QSOParties`, `TUSQSOPartyRecord`,
  `QSOPartiesCount` -- 532 lines of `VC.pas`. `ContestTypeSA` stays. No
  `FLAG_BIT` table was left to delete (S6 made the base's `GetFlags` `[]`).
* **The rover split has a home, and its output is unchanged.**
  `TContestStateQSOPartyBase.SplitsRoverCallOnExport` (protected virtual
  `GetSplitsRoverCallOnExport`, default False), stated True in the fifteen
  leaves whose row said `CountyLineAllowed: True` -- California, Colorado,
  Delaware, Florida, Idaho, Indiana, Michigan, Minnesota, Missouri, North
  Carolina, Ohio, Pennsylvania, Tennessee, Texas, Wisconsin -- and asked
  through `uContestRegistry.ContestSplitsRoverCallOnExport` (False for any
  contest not on the party base, as the row was). On the party base because
  only a party had the flag, and the base already argues a county concept off
  the root. NOT derived from `CountyLineAllowed` (they differ for six; Q90
  stays open). **Proved before the table went:** the list was printed from the
  table by a scratch program linking VC, matched a text count of
  `CountyLineAllowed: True` (15), and a scratch program linking every
  registered class compared the property with the row for every ContestType:
  186 registered, 15 True, **0 disagreements**. Then hardcoded in
  `Test_FifteenPartiesSplitARoverCallOnExport`.
* **Tests, each table read replaced by its literal:** the S0 pin
  `Test_MovedRowValuesStillMatchTheArray` is DELETED (with the orphaned
  transcription-guard header that said to delete it now); the row half of
  `Test_IdentityIsWhatTheExportersWroteBeforeM1` went with it -- the same
  comparison -- keeping the accessor checks and pinning DUMMYCONTEST's
  neutral names. `Test_ZoneModeIsCQOrITUForEveryContest`: the CQ bit is a
  literal set of 25 and the floor (`>= 10`) became exact (25). The county-line
  disagreement test is `Test_RoverSplitAndCountyLineDisagreeOnlyForTheKnownSix`,
  its row column the literal fifteen. `Test_MichiganForbidsCountyLine` (was
  `...AgainstTheArray`) asserts the rover split in place of the row's True.
  The two Field Day row lines are gone (class and session are held to the
  literal). `uTestContestDisplay.ExpectedHead` is a literal `case` of the 21
  areas (BC excluded, as before). `uTestADIFFixtures`' IN7QPNE check asks
  both seams the row fed (`ContestAllowsCountyLineOnImport`,
  `ContestSplitsRoverCallOnExport`) and pins the fixture's contest.
  **Unit run: 77760 passed, 0 failed** -- about 10,700 fewer assertions than
  S7, which is the S0 pin (171 named calls plus the 187-contest loop, ~30
  checks each) and the identity loop's 935.
* **The loss the S0 pin left is closed: `uTestContestIdentityPin`.**
  `Test_EveryContestStatesItsIdentityLiterally` holds every `ContestType`
  (DUMMYCONTEST included, exact count 187) to a literal row of WA7BNM id,
  QRZ.RU id, submission e-mail, friendly name, display name and domestic file
  name, each row carrying its `ContestTypeSA` spelling so a shifted row fails
  by name; the array is `array[ContestType]`, so the compiler refuses a
  missing row. Generated ONCE by a scratch program linking every class, and
  cross-checked against `ContestsArray` at `9dc93f67` (WA7BNM, QRZRUID, Email,
  DF, FriendlyName, ADIF and Cabrillo names: 0 differences in 187); its
  header says it is NEVER regenerated to clear a failure. The ADIF id and
  Cabrillo name are left to the matrix (`CONTEST_ID`, `CONTEST:`) except for
  the three it cannot see that way -- DUMMYCONTEST, GENERALQSO, POTA --
  pinned by `Test_MatrixBlindContestsStateTheirIds`. 1504 assertions (187 x 8, two counts, six ids).
* **`logdump.lpr`** (ungated) no longer reads a contest rule. It emits the
  contest's `ContestTypeSA` spelling (`ContestToken`) and ordinal
  (`ContestOrdinal`) instead of the row's ADIF name and `CountyLineAllowed`:
  asking the class would link the factory -- and the LCL, measured: the
  scratch program linking every class needed `Interfaces` -- into a program
  that links VC and `uLogBinaryFile` only. The old `Contest` field was already
  wrong for every contest with a blank row `ADIFName` (`CONTEST_<n>`, where
  export has written the spelling since M1). `verify_adif_export.py` stops
  checking `CONTEST_ID` (pinned by the unit tests and the matrix) and checks a
  rover split it finds in the ADIF for consistency rather than deciding which
  contests split. Built with `BuildLogDump.ps1` (BUILD OK) and run against
  the Arktika binary-log fixture (exit 0). Its `-Run` smoke test points at a
  corpus `log.trw` deleted on 2026-09-24, so it skips -- not fixed here.
* **Tooling.** `Lint-DomCoverage` reads each party class's
  `GetInStateDomesticFileName` literal (comments stripped through
  `PascalSource.psm1`), floor 22, and FAILS on an empty factory directory, a
  computed name, a commented-out override (21 < 22) and a missing `.dom` --
  each checked. **It is in `Run-Lints.ps1` now.** It had gated FullBuild's
  installer path since 2026-08-13 and was lost, not dropped, when FullBuild
  was rewritten for FPC that night (`724d53d0` kept it only in the D12
  script, later deleted) -- no reason to leave it out was found; it is fast
  and reads only the tree. `Run-Lints.ps1`, run once: **44 lint(s) passed**,
  exit 0.
  `Lint-NoContestTables` allows `ContestTypeSA` alone (stale-entry rule
  unchanged). `Lint-ContestNameTests`' fixture named `ContestsArray` as an
  index example; it names `ContestTypeSA`. `Lint-SpellingTables` never read
  these tables. The inventory's `model.Contests` reads the enum and
  `ContestTypeSA` from `VC.pas` and each contest's row values from its class
  (`adopt_class_facts`: the single value the chain's getter returns, else the
  base's; fails closed on a renamed base getter or fewer than half the
  contests read). Against the HEAD table, 187 contests x 10 fields: 3
  differences, all a row that omitted a field whose class states the neutral
  value (Field Day `DM`, the RTTY Roundup's and CQIR's `AIE`). The generated
  document's rows are identical (110, shapes 6/0/13/91, 74 of 186, 37/20
  candidates); `trait_disagreements` and `identity_gaps` are deleted -- each
  compared a class with the row -- and sections 9.2/9.3 say "retired".
  `tools/gen_friendly_names.py`, which wrote `FriendlyName` INTO
  `ContestsArray`, is deleted.
* **Docs, same change:** `ADDING_A_NEW_CONTEST.md` (no row; where each field
  went), `ADDING_A_CONTEST.md`, CLAUDE.md's "Add a contest" and its map row,
  the contest-factory and build-release agents, design 8.2s.
* **Not done:** the matrix, corpus, factory check, round-trip, `Run-Lints` and
  a full build (the gated run). The incremental app compile stopped at the
  known "Internal error 200306067" (`MainUnit.pas(491,1)`); the unit-test
  build (VC, every factory unit, uADIF) is clean, and no app unit outside it
  named a deleted identifier (`count-ids.ps1`). Regenerate the contest-rules
  inventory after the commit.

As planned:

* **Files:** `VC.pas` `ContestsArray`, `TContestInfo`, `ContestsBooleanArray`,
  the `ci*`/`*_BIT` constants (`VC.pas:4250-4292`), `QSOParties` if S5 moved
  its data; `test/logdump/logdump.lpr` (not gated -- fix by hand);
  `Test_MovedRowValuesStillMatchTheArray` and S0's widening (they have nothing
  to compare against; the class values they proved are now the only source --
  replace with a pin of the S5 values if NY4I wants one); `uTestContestDisplay`,
  `uTestADIFFixtures`; `Lint-NoContestTables` allow-list -> `{ContestTypeSA}`.
* **Docs, same commit:** `docs/ADDING_A_NEW_CONTEST.md` and
  `docs/ADDING_A_CONTEST.md` (no more rows -- an enum member, its
  `ContestTypeSA` spelling, a class); CLAUDE.md and the contest-factory agent
  ("the three `VC.pas` rows"); design §8.2 M10 row.
* **Matrix:** identical. **Risk:** low once S5/S6 are in (the compiler finds
  every straggler). **Route:** contest-factory, build-release (lint).

### S9a-f -- The six kind globals become the session object (widest; last)

One kind per commit, smallest first so the pattern is proven cheaply:
S9a `ActiveInitialExchange` (9 occ.), S9b `ActivePrefixMult` (10), S9c
`ActiveZoneMult` (22), S9d `ActiveDXMult` (22, + F5 country mode), S9e
`ActiveDomesticMult` (41, + delete `DomQTHInit`), S9f `ActiveExchange` (84).
The first commit adds `uContestSession` and the writer.

* **Trap (F9):** `logdupe.SetUpExchangeInformation(ActiveExchange: ExchangeType; ...)`
  (`:362`, `:1601`, used `:1625`) -- a PARAMETER named like the global. A
  text replace turns the parameter use into a session read, which compiles and
  is wrong whenever a caller passes something else. Rename the parameter
  first, in its own diff.
* **Matrix:** identical every time (the emitter reads the session).
  **Ceilings:** none expected. **Risk:** highest by breadth (188
  code-only occurrences of the six, declarations and writers included, 1.1), lowest per site; every pin exists by now.
* **Route:** contest-scoring (logstuff, logdupe, logddx, logdom, logsubs2,
  logedit), file-formats (postunit), lcl-ui (MainUnit, uEditQSO, uWSJTX),
  settings-config (uSettingsEffects CONTEST arm).

---

## 5. Defects and contradictions found

* **F1 (design vs scope).** Design §8.2 M10 says "the traits ... are deleted";
  §1.2 says "the multiplier KEY at M10"; §8.2l says when Q4 retires the
  commands "each kind moves into the class(es) that declare it and the kind
  enums die with the engine". But the kind traits' only consumer is set-up
  (1.3), and the kinds themselves drive ~80 surviving engine arms (sheet,
  shape parsers, display). M10 as small gated commits can delete
  QSOPointMethod, the tables and the globals; it **cannot** delete the six
  kind traits/enums without moving those arms. Recommend recording an
  **M11 -- the kinds move into the classes** and narrowing the M10 row.
* **F2 (the transcription is not complete).** CLAUDE.md/M7b say every class
  transcribes its row; true for M7b classes, not for 17 M1-M5-era classes
  (100 values) nor for any class's set-up flags (0 overriders of 8 getters).
  `fcontest.pas` ApplyContestTraits' own comment ("its getters default to the
  arrays until it states its own") is accurate; the summaries are not.
* **F3.** `MainUnit.pas:10184` and `uADIF.pas:1556` read
  `ContestsArray[..].CountyLineAllowed`, which disagrees with the classes for
  six contests (S7). Documented for Michigan only (`uContestMichiganQP.pas:76-90`).
* **F4.** `postunit.pas:477` `ZoneSentForThisContest` reads the ROW's `ZnM`,
  not the session's `ActiveZoneMult` that the ADIF CQZ/ITUZ block
  (`postunit.pas:2404-2416`) reads. Two answers to one question.
  **S6 repointed it to the CLASS's `ZoneMultiplierType` (equal to the row),
  not to the session -- the inconsistency is unchanged and is S9's.**
* **F5.** `uSettingsEffects.pas:365-377`: the contest's CTY country mode is
  derived from `ActiveDXMult` in the CONTEST *setting's* arm, after
  `FoundContest` set it to ARRL at its head (`fcontest.pas:840`). A set-up
  rule living in a settings effect; it must survive S2 and move to the session.
* **F6.** The legacy case is reachable only for DUMMYCONTEST and reads a
  point method `FoundContest` never resets there. Removed by S3.
* **F7 (CLAUDE.md / agent).** "`RETIRED_COMMANDS`: accepted, **logged once**" --
  `uCFG.pas:1419-1426` logs on every occurrence; there is no once-guard.
  **FIXED at S2:** the code now matches the claim (`RetiredCommandFirstSighting`).
* **F8.** `logdom.pas:492` `DomQTHInit` has no caller (`rg -n -i -w DomQTHInit`,
  only its declaration and a commented call `:660`) and is a runtime writer of
  `ActiveDomesticMult`. Delete at S9e.
* **F9.** The `ActiveExchange` parameter shadow in `logdupe` (above).
* **F10.** `Test_MovedRowValuesStillMatchTheArray` compares an inheriting
  class's row with itself, so it proves nothing for the 17 contests that most
  need it, and covers no Boolean bit -- hence S0.
* **F11.** `test/logdump/logdump.lpr` and the bench programs read
  `ContestsArray` and are built by no gate; S8 breaks them silently unless
  fixed by hand.
* **F12.** `Lint-SpellingTables` `$minimumTables = 31` fails S2 unless lowered
  with each removed table named -- its header demands that. **Done at S2:
  31 -> 24, each named; the lint resolves 25.**
* **F13.** `QSOPointMethodType` member `INQSOPoinRMethod` is misspelt; a search
  for `INQSOPointMethod` finds nothing. **Moot: the enum is deleted (S4).**
