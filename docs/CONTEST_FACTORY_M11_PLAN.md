# M11 -- the kinds move into the classes: a staged, measured plan

**Status: PLAN, S0 DONE. S0a, S0b and S0d are DONE (2026-10-14, at
`95e127a5`); S0c is DONE (2026-10-14, on `3b4c0777`, its re-freeze NY4I's);
S2 is DONE (2026-10-14, on `c749f2c5`) except its F15 and F6 bullets, which
wait (section 4 S2); S3 is DONE -- part 1 (the move) on `42a999c1`, part 2
(the deletion) on `cbcba524`, both 2026-10-14; S4 is DONE -- part 1 (the
move) on `3c8ce116`, part 2 (the deletion) on `6b874f1a`, both 2026-10-14;
S5 is DONE -- part 1 (the move) on `f0c54f4c`, part 2 (the deletion)
on `a8186905`, both 2026-10-14; S6 is DONE -- part 1a (the move, every
shape but the domestic file) on `ef8241fa`, part 1b (the domestic file) on
`69a2740a`, part 2 (the deletion) on `a37c3100`, uncommitted at its
hand-back, all 2026-10-14 -- so ALL FOUR MULTIPLIER KINDS ARE GONE; S7 is
DONE (2026-10-14, on `17902292`, uncommitted at its hand-back) except the
SS columns (F15, blocked on S1); S1, S8 and on are not built (see "WHAT S7,
S8 AND S9 INHERIT" after S6).** See section 4 S0 for
what each did and the corrections it made to the figures below. The plan was
measured READ-ONLY at HEAD `f006acb2` (branch `contestFactory`, 2026-10-14,
"M10 COMPLETE"). Re-measure before you act on a number. Every count below
gives the command that produced it (section 1.0); the script behind L2 and L9
is committed at `tools/contest-factory-m11/kind-reach.py` since S0a.

Owner: `contest-factory`. Engine side: `contest-scoring`. Also touched:
`file-formats`, `lcl-ui`, `log-database`, `multi-op-network`,
`settings-config` and `build-release`. Read with
[`CONTEST_OWNERSHIP_DESIGN.md`](CONTEST_OWNERSHIP_DESIGN.md) (§0, §1, §8.2g,
§8.2s) and the "M10 COMPLETE" header of
[`CONTEST_FACTORY_M10_PLAN.md`](CONTEST_FACTORY_M10_PLAN.md).

---

## 0. The answer first -- is a kind a SHAPE or a RULE?

**Each of the six enums is two different things under one name.** A member
names a *data format* (how an exchange is spelled, how a grid becomes a key,
which zone system is used) **or** a *sponsor's decision* (which countries
count, whose calls are prefixes, who may send a blank exchange). The
measurements in section 1 split them like this:

| enum | what its arms mostly do | verdict | can M11 delete it? |
|---|---|---|---|
| `ExchangeType` (61) | 162 of its 168 `case` arms are four contest-blind machines keyed on the shape: parse (`logstuff:6715`, 56 arms), field list (`logdupe:1612`, 43), ADIF (`uADIFExchange:135`, 32), Cabrillo (`uCabrilloExchange:141`, 31) | **SHAPE vocabulary. KEEP IT.** 14 of its 37 compare lines are rules in disguise, and those move; 2 more duplicate the field list (2.1) | **No.** The cost is in 0.2 |
| `InitialExchangeType` (15) | one `case` (`logedit:2271`); 6 live members, 8 dead since S2 | RULE (a prefill source plus contest exceptions) | **Yes** |
| `PrefixMultType` (15) | one key function (`logedit.SetPrefix`) plus sentinels | RULE (who counts as a prefix) | **Yes** |
| `DXMultType` (18) | one key function (`logdupe.GetDXQTH`), a remaining-mults filter, the CTY country mode | RULE (which countries count) over an existing SHAPE (`CountryModeType`, ARRL/CQ) | **Yes** -- the shape half already has its own type |
| `ZoneMultType` (7) | zone count, zone tag, EUHFC numbering | mostly a SHAPE (zone system) plus two rules | **Yes**, as class answers -- but two contests contradict themselves (F5) |
| `DomesticMultType` (9) | QTH-to-key normalisation (`logdom.GetDomQTH`), plus rover and mobile rules hung on two members | key shapes plus rules | **Yes**, with key helpers the class calls |

### 0.1 Recommendation

1. **Keep `ExchangeType`, documented as the exchange SHAPE vocabulary.** A class
   selects its shape per station, and the four shape machines stay keyed on it,
   as design §8.2g already decided for the parsers. This is the same footing
   as `CountryModeType` (ARRL/CQ) and `ZoneModeType` (CQ/ITU): they describe
   data, not rules, and nobody proposes to delete them.
2. **Delete the other five enums.** Each one feeds essentially ONE key
   function. A class virtual plus helpers that the class calls (§1.3) is a
   1:1 replacement, and it touches 20-119 contests per kind (1.5).
3. **Move every reach-1/2/3 RULE that is tested outside the shape machines**,
   whatever its enum (section 2).
4. **Reach-1 SHAPES** -- 20 `ExchangeType` members that one contest uses -- are
   a separate, optional decision (S10). Reach decides how many classes a member
   touches, not whether it is a rule.

**ANSWERED 2026-10-14 (Q92): NOT AS PROPOSED HERE -- NY4I CHOSE OPTION 2.** The shape machines become plain named helpers that each class CALLS explicitly from its own overrides (family bases where a family shares one); the enum selects nothing. S9 is re-planned on that basis; S10 is moot. The original text follows. **THIS CONTRADICTS THE DESIGN'S TEXT, SO IT NEEDS NY4I (Q92).** §0.2 says the
kind enums "have no job in a factory, so they die with the engine". §1.3 says a
helper is "never selected, registered or named by an enum". Keeping
`ExchangeType` means the four machines are still selected by an enum. The
evidence for asking anyway is in 0.2.

### 0.2 What "delete all six" would cost (`ExchangeType` is the whole cost)

- **Four coordinated statements per class instead of one.** Every class would
  have to override parse, fields, ADIF and Cabrillo, and keep all four agreeing
  (1.3: 162 arms). Today only some classes override any of them (13
  `ParseReceivedExchange`, 18 Cabrillo-received, 13 ADIF-sent; command in
  1.0). That means roughly 4 x 186 methods less the existing overrides. One
  enum value is what keeps the four consistent. Splitting it rebuilds, inside
  each class, the many-owners shape that M10 removed.
- **About fifty `Process...Exchange` parsers would have to be lifted out of
  LOGSTUFF into leaves first.** They read `DomQTHTable`, CTY, `DefaultRST`, the
  county-line queue and `ExchangeErrorMessage`, and a class may not call TRDOS
  (§8.2g). This is the biggest lift on offer anywhere in the project.
- **The only alternative to copies is a per-shape object**, which is a strategy
  -- forbidden by §0.2.
- **There is no compatibility gain, so the whole price is code volume.**
  `ExchangeType` is not persisted and does not cross the network. The only
  type mentions outside the factory are the session, the matrix emitter, the
  readiness sets, the two leaf formatters, `SetUpExchangeInformation` and
  `ParseExchangeShape` (1.0, command L4).

---

## 1. Measurements

### 1.0 Commands (run from `c:\tr4w-d12`)

| id | command | gives |
|---|---|---|
| L1 | `powershell -NoProfile -ExecutionPolicy Bypass -File tools/contest-rules-inventory/dump-code-only.ps1 -Repo C:\tr4w-d12 -Out <scratch>\dump` | code-only copy of every tracked `.pas`, through `PascalSource.psm1` (650 files) |
| L2 | `python <scratch>\kind-reach.py <scratch>\dump` (appendix A; commit as `tools/contest-factory-m11/kind-reach.py` at S0) | every `case` whose labels are kind members (any selector), every compare/`in` site, and per-value reach |
| L3 | `pwsh -NoProfile -Command "& './tools/contest-factory-m10/count-ids.ps1' -Ids @('GetExchangeKind','GetInitialExchangeKind','GetDomesticMultiplierType','GetDXMultiplierType','GetZoneMultiplierType','GetPrefixMultiplierType')"` | 373 / 355 / 357 / 355 / 349 / 347 code-only occurrences, 2,136 in all (declaration and body per class) |
| L4 | `rg -n -i -w "ExchangeType\|InitialExchangeType\|DXMultType\|PrefixMultType\|ZoneMultType\|DomesticMultType" <scratch>\dump\code\tr4w` | where the TYPES are named |
| L5 | `rg -n -i "aSession\.(Exchange\|InitialExchange\|PrefixMult\|ZoneMult\|DXMult\|DomesticMult)\s*:=" tr4w/src/contestFactory` | 89 `DescribeSession` kind statements in 41 files (42 contests; the ARRL DX base serves two) |
| L6 | `rg -n -i "\.(ExchangeKind\|InitialExchangeKind\|DomesticMultiplierType\|DXMultiplierType\|ZoneMultiplierType\|PrefixMultiplierType)\b" <scratch>\dump\code\tr4w` minus the `Get...` lines | the traits' only reader: `fcontest.pas:812-817` (`ApplyContestTraits`) |
| L7 | `rg -o -N "^### variant (\w+)" -r '$1' tr4w/test/contest-matrix/frozen/*.matrix \| cut -d: -f2 \| sort \| uniq -c` | matrix stations: `us` 208 (22 parties carry a second, `us-host`), `ve` 186, `dx` 186 (DL) |
| L8 | `powershell -File tr4w/build/Lint-ContestNameTests.ps1 -List` | 6 tests in 3 files; `$TOTAL_FLOOR = 5` |
| L9 | `python <scratch>\kind-reach.py <scratch>\dump --inventory` -- the inventory's own `scan.scan_sites` / `effective_reach` / `classify_proxies` on L1, then reclassified with the session reach | 123 shape-4 sites, 229 records -- the published figures -- and the reclassification in 1.4 |

**REACH is defined here as the SESSION reach.** It is the class trait,
UNION every value the frozen matrix records for that contest (any variant),
UNION every literal its `DescribeSession` chain states under any condition.
That over-approximates, which is the safe direction for calling an arm dead.
It is exact for the matrix's stations. Since M10 S2 the session has exactly
two writers, the trait and then `DescribeSession` (`fcontest.pas:812-817`,
`:530-566`), so nothing else can select a value.

`trdos/logddx.pas` is compiled by nothing (M10 F14, Q91) and is **excluded**
from every figure here unless one says otherwise.

### 1.1 The six enums by reach (L2)

| enum | members | dead | reach 1 | reach 2-3 | reach 4+ | contests running a non-`No*` value |
|---|---:|---:|---:|---:|---:|---:|
| `ExchangeType` | 61 | 9 (+ `UnknownExchange`, the zero and DUMMYCONTEST's) | 20 | 15 | 16 | 186 |
| `InitialExchangeType` | 15 | 8 | 1 | 1 | 5 (incl. `No`) | 46 |
| `DXMultType` | 18 | 4 | 4 | 4 | 6 (incl. `No`) | 78 |
| `PrefixMultType` | 15 | 3 | 5 | 4 | 3 (incl. `No`) | 32 |
| `ZoneMultType` | 7 | 1 | 1 | 2 | 3 (incl. `No`) | 20 |
| `DomesticMultType` | 9 | 1 | 1 | 2 | 5 (incl. `No`) | 119 |

**Dead since S2** (reach 0; S2 retired the seven settings, which were their
only selector):

- `ExchangeType`: `NoExchangeReceived`, `QSONumberAndAgeExchange`,
  `CheckAndChapterOrQTHExchange`, `RSTAndGrid3Exchange`, `RSTAndDOMESTICQTH`,
  `RSTAndFOCNumberExchange`, `RSTAndSerialNumberAndGridandPossibleMemberNumber`,
  `RSTNameAndPossibleFOCNumber`, `RSTQSONumberOrDomesticQTHExchange`.
- `InitialExchangeType`: `Section`, `QTH`, `FOC`, `User1`..`User5`.
- `DXMultType`: `CQDXCCWithNoHB9`, `CQDXCCWithNoOK`, `CQNonEuropeanCountries`,
  `NonSouthAmericanCountries`.
- `PrefixMultType`: `AsianPrefixes`, `NorthAmericanPrefixes`, `RussianPrefixes`.
- `ZoneMultType`: `JAPrefectures`.
- `DomesticMultType`: `NumericID`.

The dead members appear in **32 `case` arms (30 wholly dead) and 5 compare
lines**: `logedit` 12, `logdupe` 10, `logstuff` 7, `uADIFExchange` 3,
`uCabrilloExchange` 3, `uMults` 1, `uContestBase` 1, plus the set constants
`uContestReadiness` (4) and `uGridShape` (1).

**Reach 1 and 2-3, by member:**

- `ExchangeType` reach 1: YOUTHCHAMPIONSHIPRF, KIDSDAY, TENTEN, GRIDLOC,
  NZFIELDDAY, RADIOYOC, RAEM, RFASCHAMPIONSHIPCW, CQIR, ALLJA, WWL, POTA, ARCI,
  XMAS, FISTS, COUNTYHUNTER, CQWWRTTY, JALONGPREFECT, RADIOMEMORY,
  UA4WCHAMPIONSHIP.
- `ExchangeType` reach 2-3:
  - Field Days -- `ClassDomesticOrDX`
  - BATAVIA/MAKROTHEN -- `Grid`
  - ARRLDIGI/WWDIGI -- `Grid2`
  - R9W + RF Champ -- `QSONumberAndZone`
  - Cup RF x3 -- `QSONumberAndGridSquare`
  - CQP (host) + VAQP -- `QSONumberDomesticOrDXQTH`
  - QCWA x2
  - ARRL SS x2
  - All Asian x2 + YOTA -- `RSTAge`
  - CQMM + SAWW -- `RSTAndContinent`
  - RoPoCo x2
  - BWQP + GENERALQSO -- `RSTNameAndQTH`
  - JIDX x2 -- `RSTPrefecture`
  - NRAU x2 + Ohio -- `RSTQSONumberAndDomesticQTH`
  - REF x2
- `DXMultType`:
  - reach 1: ARI (`NoIOrIS0`), JTDX (`NoJT`), PACC, BSCI (`BlackSea`)
  - reach 2-3: `NoARRLSections` (ARRL10, ARRL160, WFD), `CQDXCCWithNoUSAOrCanada` (CQ160 x2), `CQEuropean` (WAEDC x2), `CQUBAEuropean` (UBA x2)
- `PrefixMultType`:
  - reach 1: YBDX, JTDX, SAWW (`NonSouthAmerican`), CQMM (`SouthAndNorthAmerican`), GAGARINCUP (`GCStation`)
  - reach 2-3: UBA x2, SAC x2, `SouthAmerican` (CQMM, SASPRINT, SAWW), WAE regions (WAEDC x2)
- `ZoneMultType`: `BranchZones` (NZFD); `EUHFCYear` (EUROPEANHFC, KVP); `RFChampionchipZones` (RF Champ x2).
- `DomesticMultType`: `IOTADomestic` (IOTA); `DOKCodes` (DARC10M, WAG); `RDADistrict` (RDA, ALRS).

### 1.2 Where the six kinds are read (L2, compiled code)

**10 `case` statements, 217 arms**, plus 3 more in `logddx`:

| site | selector | arms | arm reach |
|---|---|---:|---|
| `trdos/logstuff.pas:6715` `ParseExchangeShape` | `aShape` | 56 | 20 arms reach 1, 5 dead |
| `trdos/logdupe.pas:1612` `SetUpExchangeInformation` | `aExchangeKind` | 43 | 4 dead |
| `uADIFExchange.pas:135` `FormatADIFExchangeOfKind` | `aKind` | 32 + `else` | 2 dead |
| `uCabrilloExchange.pas:141` `SetHisEx` | `aCtx.SessionExchange` | 31 + `else` | 3 dead |
| `trdos/fcontest.pas:943` `FoundContest` (sent messages) | session | 5 | 8 / 23 / 48 / 10 / 6 |
| `MainUnit.pas:834` `PerQSOExchString` | session | 1 + `else` | 5 |
| `trdos/logdupe.pas:662` `GetDXQTH` | session | 15 + `else` | 4 dead; ARI, JTDX, BSCI, PACC 1 each; WAE 2; UBA 2 |
| `trdos/logdupe.pas:2242` `SetUpRemainingMultiplierArrays` | session | 6 + `else` | JA dead; NZFD 1; EUHFC 2; RF 2 |
| `trdos/logedit.pas:2271` `InitialExchangeEntry` | session | 14 | 8 dead; CQWWCW 1; SS 2; Zone 21; Name 9; NameQTH 8; Grid 5 |
| `trdos/logedit.pas:2905` `SetPrefix` | session | 14 | 3 dead; 5 reach 1; 4 reach 2-3 |

**96 compare/`in` lines in 43 routines.** The member `Prefix` is excluded
wherever it is a local or field of that name (`logname`, `logradio`,
`uRadioKenwoodSerial`, `uADIF` and others: name collisions, not kind tests).

| enum | lines | routines |
|---|---:|---:|
| Exchange | 37 | 12 |
| Domestic | 25 | 13 |
| DX | 15 | 7 |
| Zone | 13 | 8 |
| Prefix | 5 | 4 |
| InitialExchange | 1 | 1 |

**Passed as data rather than tested**, 10 sites:

- `logdupe:1277` and `uContestFactory:176` -- `IsDmMult(..., DomesticMult)`
- `tree:2510` -- `in GRID_CARRYING_EXCHANGES`
- `postunit:2364`, `:3040`, `:3689` -- the exporters
- `logstuff:3911`, `:3918` -- `ExchangeModeAttribution`
- `logstuff:7017` -- the parse session
- `uProgramMain:2306`, `:2586`
- `MainUnit:9986` -- the ADIF import session
- `uScoreTotals:165-166` -- `SessionExchange` and `SessionDXMult`

**Set constants keyed on a kind:**

- `uContestReadiness:69/90/98` -- the domestic-QTH, zone and grid exchanges
- `uGridShape` -- `GRID_CARRYING_EXCHANGES`
- `VC.pas:3406` -- `ActiveExchangeArray`, kept only for two log lines, `uADIFExchange:403/413`

**Inside the factory**, the kind tests are:

- 11 classes testing `aSession.Exchange` inside `ParseReceivedExchange`:
  ARRL SS base, Arktika, Canada Day, Canada Winter, IARU, LABRE, PCC, SAC x2,
  UA4W, UK/EI
- `TContestBase.CombineScore` (`uContestBase:2718`, FISTS)
- `TContestBase.ApplyADIFImport` (`:2924-2928`, the grid shapes)
- the two WAEDC classes' `CombineWithMultipliers` (`aTotals.SessionDXMult`)
- the 89 `DescribeSession` statements (L5)
- 2,136 trait-getter occurrences (L3)

### 1.3 Session versus trait, per station (L2 and L5)

- **28 contests** run a kind their trait does not state **at a matrix station**:
  ALLASIAN x2, ARRL10, ARRL160, ARRLDX x2, ARRLFIELDDAY, Arizona, CQP, DARC10M,
  WAEDC x2, Delaware, JIDX x2, KCJ, NEQP, OKDX, PACC, RDA, SAC x2, Salmon Run,
  7QP, SAWW, Texas, WAG, YBDX.
- **36** do so for some station, if every `DescribeSession` literal is
  counted. The extra eight: ALRS, CQMM, CROATIAN, HELVETIA, UBA x2, UKRAINIAN, YUDX.
- **42 classes** state at least one kind in `DescribeSession`.
- M10 §1.4's "27" was measured at an earlier HEAD.

The matrix's stations (L7) do NOT reach most per-station branches. The
branches test JA, OK/OM, ON, Scandinavia, Russia, 9A, HB, EI, YU, UR, Asia and
South America as the entrant's location, and the matrix has none of them.

**Five trait values never run.** In each case `DescribeSession` overwrites the
trait on every station:

| contest | kind | trait | always stated | site |
|---|---|---|---|---|
| ARRL10 | DX | `ARRLDXCCWithNoUSACanadaKH6OrKL7` | `ARRLDXCCWithNoARRLSections` | `uContestARRL10:201` |
| ARRLFIELDDAY | Domestic | `NoDomesticMults` | `DomesticFile` | `uContestARRLFieldDay:454` |
| KCJ | InitialExchange | `NoInitialExchange` | `ZoneInitialExchange` | `uContestKCJ:226` |
| YBDX | DX | `NoDXMults` | `ARRLDXCC` | `uContestYBDX:239` |
| YBDX | Prefix | `NoPrefixMults` | `IndonesianDistricts` | `uContestYBDX:240` |

Seven more unconditional statements only repeat the trait:

- ARRLFIELDDAY DX
- BCQP DX
- JTDX initial exchange and prefix
- NYQP domestic
- SST domestic
- WFD DX

### 1.4 Reconciliation with the inventory's shape-4 rows (L9)

The published numbers are 123 sites, 229 records, 91 PROXY / 96 SHARED / 42
UNUSED. 29 of the sites and 25 of the PROXY rows are `logddx`. Of the 66
compiled PROXY rows: Exchange 43, DX 7, Domestic 5, Zone 5, Prefix 4, initial
exchange 2.

**The inventory's reach is blind to `DescribeSession` (F1).** Once its reach
is recomputed with the session reach from 1.0, the records come out as
SHARED->SHARED 96, PROXY->PROXY 88, UNUSED->UNUSED 30, **UNUSED->PROXY 12**
and PROXY->SHARED 3. Eleven of the twelve UNUSED rows that are really live
are in compiled code:

| row | value | live for |
|---|---|---|
| `logdupe:708` | CQEuropean | WAEDC x2 |
| `logdupe:740` | PACC | PACC |
| `logdom:250` | DOK | DARC10M, WAG |
| `logstuff:7120` | DOK | DARC10M, WAG |
| `logedit:2906` | WAE regions | WAEDC x2 |
| `logedit:2912` | SAC | SAC x2 |
| `logedit:2913` | Indonesian | YBDX |
| `logedit:2927` | S+N American | CQMM |
| `logedit:2932` | non-SA | SAWW |
| `logedit:2797` | RSTPrefecture | JIDX x2 |
| `uMults:272` | CQEuropean | WAEDC x2 |

**What the inventory does not scan:**

- Three of the four shape machines: `logstuff:6715`, `uADIFExchange:135` and
  `uCabrilloExchange:141`. Only `SetUpExchangeInformation` is scanned, through
  `KIND_PARAMETERS`, and it contributes 37 PROXY rows that are shape
  descriptors, not contest rules. **Corrected at S0a: 25 rows, of 43
  records** (section 4 S0a).
- Kind tests on non-session operands: `uMults:211`, `uContestReadiness:221`.

### 1.5 What pins the arms today

**The matrix** records, per contest, variant and synthetic QSO:

- `pts`, the four mult flags, `pfx=`, `dxqth=` and `dommultqth=` -- so
  `SetPrefix`, `GetDXQTH` and `GetDomQTH` are pinned FOR ITS QSOs
- the set-up messages (`FoundContest:943`), the `doing.*` flags and
  `cty.countrymode` / `cty.zonemode`
- exports
- the 66-case parse section
- totals

**Gaps:**

- Its 17 QSOs contain no ON, YB, JT, SM/LA/OH/OX, UA9/UA0, GC callsign, I/IS0,
  HB9 or OK, and no IOTA, DOK, RDA or grid-field QTH. So most reach-1 key arms
  are executed by nothing.
- `InitialExchangeEntry` is pinned by no oracle at all; the matrix records only
  `active.initialexchange`.
- `SetUpExchangeInformation` and `MaxNumberOfZones` are not recorded.

**Unit tests:**

- `uTestContestSession` pins one contest per kind where session differs from
  trait. Three of those (YBDX, KCJ, ARRL10) pin the contradictions in 1.3.
- `uTestContestParse:622-633` pins `InitialExchangeFromCall`, which the program
  never calls (F3).
- TRDOS key functions are not unit-linkable.

**Scoring over real logs:** `test-contest-factory.sh` (13 logs) rescoring.

---

## 2. Classification of every arm

**S0..S10 below name the stage that moves the arm.** "Stays" means shape
machinery that M11 keeps, as section 0 recommends.

### 2.1 `ExchangeType`

**The four machines stay (162 arms):** `ParseExchangeShape`,
`SetUpExchangeInformation`, `FormatADIFExchangeOfKind` and `SetHisEx`. Their
dead arms go at S1 and their reach-1 arms at S10. Several other shape readers
also stay:

- `FoundContest:943` -- 5 arms: the sent-message default per shape
- `PerQSOExchString` -- `MainUnit:834`
- the history renders of `GetInitialExchangeStringFromContestExchange` -- `logdupe:2062-2100`
- `InitialExchangeEntry`'s history branch -- `logedit:2678-2688`, `:2703`, `:2797`
- `RSTZoneOrDomesticQTH`'s domestic-call drop -- `logedit:2431`, `:2698`
- the FISTS field placement -- `logdupe:1949`
- `tree:2510` and the readiness sets
- `uContestBase:2924-2928` (ADIF import)

**The rules move:**

| arm(s) | contests | rule | stage |
|---|---|---|---|
| `MainUnit:934-936`, `:975-977` -- the rover suffix is stripped for `RSTDomesticQTH` / `RSTQTH` / `RSTDomesticOrDXQTH` | 25 by shape | is a `/xxx` suffix a county? | S7, transcribed exactly; F4 |
| `MainUnit:2061-2062`, `:5988` -- several QTHs on Enter | 21 by shape | multi-county entry | S7; F4 |
| `MainUnit:7121-7122`, `logstuff:7012` -- a blank exchange is allowed | BWQP, GENERALQSO, POTA | `AcceptsBlankExchange` | S7 |
| `MainUnit:4054` -- the park name is shown | POTA | `OffersParkTools` (exists) or new | S7 |
| `fcontest:396` -- zone plus state are sent | CQWWRTTY | its `DescribeSession` / `CQExchangeDefault` (Q57) | S7 |
| `uContestBase:2718` -- FISTS scores points only | FISTS | `TContestFISTS.CombineWithMultipliers` | S7 |
| `MainUnit:9514-9516` -- the SS columns | ARRL SS x2 | equals `ExchangeInformation.Precedence`/`.Check` once S1 has run (F15) | S2 |
| the 11 factory `aSession.Exchange` guards | those 11 classes | tautologies since S2 (F11) | S2 |

### 2.2 `InitialExchangeType` -> class (S8)

- `logedit:2271` -- 6 live arms: Custom, Zone, Name, NameQTH, CheckSection, Grid.
- `logedit:2715` -- the zone test, and IARU.
- The shape-1 rows that live inside it:
  - `:2420` -- OZCR
  - `:2438` -- RF Champ
  - `:2650` -- RUSSIANDX, RDA, RU3AX
  - `:2715` -- IARU
- `:2472` (ITU) moves with S5.
- The 8 dead arms go at S1, and with them the only callers of
  `GetVEInitialExchange` (F3).

### 2.3 `PrefixMultType` -> class (S3)

- `logedit:2905 SetPrefix`, with its GAGARINCUP callsign list (shape-3 row
  `logedit:2949`).
- `MainUnit:7290-7291` -- `SetPrefix` without `DoingPrefixMults`.
- The sentinels `MainUnit:9542`, `LogCfg:435` and `uScoreTotals:163` go at S2.

### 2.4 `ZoneMultType` -> class answers (S5)

- `logdupe:2242` -- the zone count.
- `logedit:1000-1003` -- CQ versus ITU for the mult array.
- `logedit:1501` -- EUHFC numbers from zero.
- `logstuff:5589` -- the EUHFC range, which moves into the parse of EUROPEANHFC and KVP.
- `logedit:2472` -- the ITU initial zone.
- `postunit:491`, `:2418-2430` -- the ADIF CQZ/ITUZ tag.
- `logstuff:5600-5608` -- JA, dead, goes at S1.
- The sentinels `LogCfg:436` and `uScoreTotals:164` go at S2.

### 2.5 `DXMultType` -> class (S4)

- `logdupe:662 GetDXQTH` -- 15 arms plus `else`. PACC's UA9/UA0 split is PACC's own.
- `logdupe:655` -- the WYSIWYG guard.
- `uMults:269-275` -- the remaining-mults filter; F7.
- `uSettingsEffects:369-374` -- the country mode; this is M10's F5.
- The sentinels go at S2: `LogCfg:434`, `MainUnit:9543`, `uEditQSO:393/485`,
  `uMults:264`, `uScoreTotals:162`.
- The WAEDC `CombineWithMultipliers` tests its own station rule, and that test
  becomes `Station.MyContinent`.

### 2.6 `DomesticMultType` -> class (S6)

- `logdom:220-316 GetDomQTH` -- 7 tests.
- `logstuff:7106-7191 DomStringParse` -- a copy of the above; it becomes the shared helper at S2 (F6).
- The grid-rover rules move to the six VHF classes:
  - `logedit:477`
  - `logsubs2:1307`, `:1622`, `:1635`
  - `logstuff:6259`
- `logsubs2:1611` -- the mobile call is rewritten to `call/QTH` when the kind is `DomesticFile` (94 contests).
- `postunit:2402` -- RDA writes no GRIDSQUARE.
- `uMults:211`, `uWSJTX:231` -- the grid-field key.
- `uContestReadiness:221` -- a domestic file is needed.
- The sentinels `LogCfg:433` and `uScoreTotals:161` go at S2.

**`DomesticFile` cannot be derived from the domestic file name.** The two
disagree for 8 contests:

- `DomesticFile` without a trait file name: ARRLDX x2, FOCMARATHON, NEQP.
- A file name without `DomesticFile`: ALRS, GAGARINCUP, IARU, WRTC.

So the answer has to be stated.

---

## 3. The session object

**The kinds ARE class answers, per station. That much is measured.** Since S2
each kind has exactly two writers, the class's trait and then the class's
`DescribeSession`, and both read nothing but the station. 28/36 contests vary
by station (1.3).

**So the target is one statement per fact per class.** In practice:

- **The exchange shape** becomes
  `function ExchangeShape(const aStation: TStationContext): ExchangeType`.
  Its input is the one `DescribeSession` already has, and it replaces both
  `ExchangeKind` and `TSessionDefaults.Exchange`.
- **The multiplier and initial-exchange kinds stop being values.**
  - The per-station choice goes inside the class's own rule, where
    `TContestUBACW.PrefixMultiplierKey` asks `Station.MyCountry` exactly as
    its `DescribeSession` does today.
  - "Does this session count X multipliers" becomes one class answer per
    station: `MultiplierKinds(aStation)`, a set over `RemainingMultiplierType`'s
    four kinds. That type already exists.

**`ContestSession` stays, and it shrinks to one enum and four booleans.**

- What remains: `Exchange` (the shape) plus `DoingDomestic/DX/Prefix/Zone`,
  moved into it from `LogCfg`'s globals. FCONTEST still writes it, once, at
  set-up.
- The other five kind fields go with their enums.

**It stays because it is a cache, and the cache earns its keep.**

- **Cost:** `tree.LooksLikeAGrid` reads the shape once per log-grid row per
  repaint. `uContestFactory.ActiveContest` rebuilds `CurrentStation` (about
  twenty fields and the resolved settings) on every call
  (`uContestFactory.pas:262-274`). A class question on that path would be a
  regression. **Measure it before routing any per-row or per-QSO path through
  `ActiveContest`.**
- **Coherence:** it is one main-thread snapshot that every reader shares.

**The trait/`DescribeSession` duality is the thing to delete, not the
session.** Doing so fixes the five contradictions in 1.3 by construction:
a class can no longer state a value it never runs.

---

## 4. Stages

**Gate for every stage:**

- the full build
- `Run-Lints`
- `Build-Tests.ps1 -Run`
- `run-contest-matrix.sh`
- `test-contest-factory.sh` (13 logs)
- `export-d12-corpus.sh` -- 24/0/2 **and exit 0**
- the Edit-QSO round-trip

**Each stage is one commit (or two, as marked), and every stage regenerates
the inventory.** A stage that deletes a kind removes that kind's
`active.<kind>` line from every matrix record. That is a format-only
re-freeze, and its stated reason must be checked by a diff that excludes
exactly that line, as at M10 S1. Every other stage expects the matrix
**identical**.

The order puts every pin in place first (S0), then the moves with no
behaviour (S1-S2), then the best-pinned kinds, then the worst-pinned.

### S0 -- Instruments and pins (no behaviour change)

- **S0a** -- **DONE 2026-10-14.** Commit `tools/contest-factory-m11/kind-reach.py` (appendix A).
  Fix the inventory: `scan.effective_reach` must union the `DescribeSession`
  literals (F1), and the four shape machines are judged `SHAPE` rather than
  PROXY. *Files:* `tools/contest-rules-inventory/scan.py`, `judgements.py`,
  the regenerated doc. *Expected:* rows move (12 UNUSED->PROXY; 37
  `SetUpExchangeInformation` rows->SHAPE). This is a measurement correction,
  stated as one.
  - **What was done.** `scan.describe_session_statements` reads every
    `aSession.<Kind> := <value>` in a factory `DescribeSession`, on TOKENS
    (89 statements in 41 classes, L5's figure), and fails closed on a kind
    statement outside `DescribeSession`, a value that is not one identifier,
    or none found. `effective_reach` unions them over each contest's class
    chain. `judgements.SHAPE_MACHINES` names the four machines and
    `classify_proxies` gives their arms the class SHAPE, which the summary
    counts and no table lists; the generator fails if no record is SHAPE.
    The frozen matrix is NOT read: since S2 the trait and `DescribeSession`
    are the session's only writers, so the matrix can add nothing, and
    `kind-reach.py --inventory` now proves it (below).
  - **Inventory at `95e127a5`, before -> after:** 110 -> **94** table rows;
    shapes 1/2/3/4 6/0/13/91 -> **6/0/13/75**; records PROXY 91 (39 reach-1,
    52 reach-2-3) -> **75** (25, 50), SHARED 96 -> **85**, UNUSED 42 -> **26**,
    SHAPE -> **43**; registered contests with rules outside the factory 74 ->
    **66**. Every one of the 229 records accounted for: PROXY->PROXY 63,
    **UNUSED->PROXY 12** (exactly 1.4's list, `logddx:313` among them),
    **PROXY->SHARED 3** (`logddx:863`, `logdupe:681`, `logedit:2680` --
    `DescribeSession` adds contests to those values), PROXY->SHAPE 25,
    SHARED->SHAPE 14, UNUSED->SHAPE 4, and the rest unchanged. Rows: 110 - 25
    - 3 + 12 = 94. Contests: 20 leave (their only rows were
    `SetUpExchangeInformation` arms or the three that became SHARED -- ARCI,
    ARRLDIGI, BATAVIA_FT8, CUPURAL, DELAWAREQSOPARTY, JALONGPREFECT, KIDSDAY,
    MAKROTHEN, PAQSOPARTY, R9W, RADIOMEMORY, RADIOYOC, RAEM, RFASCHAMPIONSHIPCW,
    RoPoCo x2, UKRAINECHAMPIONSHIP, WWDIGI, XMAS, YOUTHCHAMPIONSHIPRF) and 12
    join (ALRS, ARRL160, DARC10M, WAEDC x2, JIDX x2, PACC, SAC x2, WAG, YBDX).
  - **CORRECTION: 25 rows, not 37.** `SetUpExchangeInformation` contributed
    **25** PROXY rows (14 reach-1, 9 reach-2, 2 reach-3) to the published
    document, of **43** records (25 PROXY, 14 SHARED, 4 UNUSED). All 43 are
    SHAPE now. F1 and 1.4 said 37; the tracked document says 25.
  - **Still not scanned:** the other three machines (`ParseExchangeShape`,
    `FormatADIFExchangeOfKind`, `SetHisEx`) take the shape as a parameter the
    scan does not follow. They are named in `SHAPE_MACHINES` so that widening
    the scan cannot table their arms as contest rules. See F16 for what that
    blindness costs section 9.1 of the inventory.
  - **`kind-reach.py` is committed with one change from appendix A:** its
    `DescribeSession` half calls `scan.describe_session_statements` instead of
    its own line regex -- one reader, so the script and the inventory cannot
    disagree. Its CASE/TEST/MEMBER output is byte-identical to the appendix
    version's. `--inventory` now reads the fixed reach and keeps SHAPE as
    SHAPE, so it is a CROSS-CHECK: at `95e127a5` every one of the 229 records
    reclassifies to its own class (SHARED 85, PROXY 75, UNUSED 26, SHAPE 43).
- **S0b** -- **DONE 2026-10-14, at the MATRIX's stations, not this roster.**
  `uTestContestKindPin`. For every contest x a station roster (us
  out-of-host, us-host, VE, DL, JA, OK, ON, SM, UA, YB, PY, 9A, HB, EI, YU,
  UR, an Asian and a South American entrant), assert the six kinds that
  `trait` + `DescribeSession` resolve to, as literals. Generate it ONCE and
  never regenerate it to clear a failure, the `uTestContestIdentityPin` rule.
  It pins every per-station branch without needing matrix variants.
  - **What was built.** `tr4w/test/unit/uTestContestKindPin.pas`, registered
    as suite `ContestKindPin`. `KIND_PINS: array[ContestType]` holds each
    contest's six kinds at `us`, `ve` and `dx`; `HOST_KIND_PINS` holds the 22
    parties' `us-host` station (call, country, MY STATE, section, grid) and
    kinds. `Kinds` resolves them as FCONTEST does -- the trait, then each
    stated value over it -- on `ContestIdentity`, as `FoundContest` asks.
    Assertions: 187 x 3 x 6 = **3,366** plus 22 x 6 = **132**, every count
    exact; a party with no host row, or a host row on a non-party, fails.
  - **The stations are the matrix's** (`matrix-lib.sh` `matrix_run`), as the
    task directed: us K0AAA/KS/EM17, ve VE3AAA/ON/FN03, dx DL1AAA/no
    state/JO62, us-host per party from its frozen record's `### variant
    us-host` line, plus what `CurrentStation` hands `DescribeSession` at that
    point (CTY country and continent, MY STATE, `InHostState` = True only at
    us-host). The zone, power, category mode and the three services are left
    zero: no `DescribeSession` reads them (measured).
  - **Proved before it was written down:** the generated kinds equal the
    frozen matrix's `active.*` lines for all **580 records, 3,480 values, 0
    differences**, so the literals are what the program runs. 7 contests vary
    across us/ve/dx (ARRL160, ARRL DX x2, WAEDC x2, WAG, DARC10M) and 6
    parties differ in the host state (AZ, CA, DE, Salmon Run, 7QP, TX); the
    test asserts both counts.
  - **NOT DONE -- the rest of this roster.** JA, OK, ON, SM, UA, YB, PY, 9A,
    HB, EI, YU, UR, Asian and South American entrants are not pinned, so the
    per-station branches only those stations reach (1.3) are still unpinned.
    Adding them means new rows in the same unit, generated the same way and
    checked by hand, because the matrix cannot cross-check a station it does
    not run.
- **S0c** -- Matrix instrument extension, a deliberate re-freeze with that
  reason:
  - QSOs that hit every live key arm: ON4, YB, JT, SM/LA/OH/OX, UA9 and UA0,
    RK1G, I/IS0, LZ/UR (Black Sea), 9A.
  - QTH texts for IOTA, DOK, RDA, grid square and grid field.
  - The setup lines `exchange.fields = ...` (`SetUpExchangeInformation`) and
    `zones.max = N`.
  - *Check:* every existing QSO's scoring, export, import and parse line is
    unchanged (diff with the added lines excluded). The `totals` section
    changes by construction, because there are more QSOs, so that section is
    re-frozen for that reason and nothing else.
  - **DONE 2026-10-14 -- and STRICTLY APPEND-ONLY: `totals` does NOT change.**
    The new QSOs are scored but never logged, so export, import and totals
    describe exactly the log they described before. Every new line is in one
    of two NEW sections of each variant, and removing those two sections
    from a new record gives the frozen record byte for byte:
    - **`== keys`**, between `parse` and `totals`: `exchange.fields = ...`
      (the fields `SetUpExchangeInformation` set, by name) and `zones.max = N`
      (`MaxNumberOfZones`) -- in this section, not in `setup`, so the
      append-only rule is "whole new sections" and nothing else; then
      **19 QSOs numbered 18-36** (ON4ABC, YB1ABC, JT1ABC, SM5ABC, LA1ABC,
      OH2ABC, OH0ABC, OX3ABC, UA9ABC, UA0ABC, RK1G, I1ABC, IS0ABC, LZ1ABC,
      UR5ABC, 9A2ABC, KL7ABC, HB9ABC, OK1ABC) through `RecomputeQSOScoring`,
      the scoring section's own line format; then **8 typed exchanges**
      through the parse path (`iota` `599 123 EU005`, `iota.dash`
      `599 123 EU-005`, `iota.short` `599 EU5`, `dok` `599 A01`, `serial.dok`
      `599 123 A01`, `grid6` `599 FN31PR`, `grid.field` `599 FN`, `rda.short`
      `599 MO1`), the parse section's own line format.
    - **`== initialexchange`**, LAST: `InitialExchangeEntry` for 33 calls
      (the 11 logged, the 19 above, UA3ABC, R35AB, K9ABC), one `iex` line
      each with four columns -- `none` (no call-history file, no history),
      `trmaster` (the matrix's OWN file), `logged` (that plus the logged
      history), `custom` (that plus a CUSTOM INITIAL EXCHANGE STRING naming
      all fifteen of the Custom arm's commands) -- and three lines saying
      what the program left open (`initialexchange.trmaster.program`,
      `.indexopen`) and whether the fixture was opened (`.fixture`).
  - **F17 is worked around IN THE HARNESS, deterministically -- production
    is unchanged.** `tr4w/test/contest-matrix/MATRIX-TRMASTER.DTA` is a
    tracked 9-call file written from `trmaster-fixture.txt` by
    `make-trmaster-fixture.py` through `tr4w/tools/trmaster/trmaster_codec.py`
    (the shipped file's own writer; read back and compared). `matrix-lib.sh`
    copies it into each run directory under THAT name -- never as
    `TRMASTER.DTA`, so `FCONTEST.SetUpFileNames` cannot find it and no section
    before `initialexchange` sees it -- and `uContestMatrix` points
    `CD.ActiveFilename` at it and sets `MasterFileExists`, the assignment
    `uProgramMain:2701` makes after the halt. The shipped `TRMASTER.DTA` is
    never opened by the new section, so a monthly refresh moves nothing.
    `uProgramMain`'s order is NOT changed: that is production start-up.
  - **F18 is worked around the same way.** The `logged` pass clears
    `IntitialExLoaded` and calls `LoadinLog` again -- what opening a
    non-empty log does at start-up -- after `totals`, so `totals` is
    untouched. Measured: history now differs from `none` (NAQSOCW K4ABC
    `" Bob "` -> `" JOE FL "`; ARRL SS W1AW `" 14CT "` -> `" 00 "`). Whether
    a live in-session reload loses history (F18's open half) is still not
    measured -- that is production behaviour, recorded, not changed.
  - **Arms now executed on a call or text they act on**, at the matrix's
    stations (dev runs over 50 contests, below):
    - `SetPrefix` -- `BelgiumPrefixes` (ON4), `SACDistricts` (SM, LA, OH,
      OX, and OH0's own branch), `IndonesianDistricts` (YB1),
      `MongolianCallSignPrefix` (JT1), `GCStation` (RK1G), the WAE regions
      (UA9 -> `UA99`, UA0 -> `UA90`, KL7, JT); `Prefix`, `CallSignPrefix`,
      `SouthAmericanPrefixes` were already.
    - `GetDXQTH` -- `ARRLDXCCWithNoIOrIS0` (I, IS0 excluded; 9A counted),
      `ARRLDXCCWithNoJT`, `BlackSeaCountries` (LZ, UR, RK1G's UA in; SM,
      LA, OH, UA9 out), `CQUBAEuropeanCountries` (SM, OH, OH0, I, IS, LZ,
      9A, OK in; ON, LA, UR, HB9, OX out -- ON is not on the list. FINDING:
      `UBAEuroCountryString` exists TWICE and the copies disagree --
      `uCallSignRoutines:49` (what `UBACountry` reads) has 9A and no G,
      `uCTYDAT:168` has G/GD/GI/GJ/GM/GU/GW and no 9A; the matrix pins the
      first),
      `ARRLDXCCWithNoUSACanadaKH6OrKL7` and the North American list (KL7);
      the rest were already.
    - zone count -- all five live values recorded (`CQZones` 40, `ITUZones`
      75, `EUHFCYear` 100, `BranchZones` 99, `RFChampionchipZones` 7).
    - `GetDomQTH` (through the parse path) -- `IOTADomestic` accepted
      (`EU005`, `EU5` -> `EU-005`) and refused (`EU-005`); `DOKCodes` on a
      real DOK; `RDADistrict` refused (`MO1`, "Improper domestic QTH!!");
      `GridFields` refused (`FN`). `GridSquares` 4-character, `WYSIWYG` and
      `RDADistrict` accepted were already.
    - `InitialExchangeEntry` -- `Custom` with every command and its CTY zone
      fallbacks (and a pinned defect: `USER1` adds no trailing space, so
      `U1U2`); `Zone` from the file's CQ and ITU zones, from CTY, the OZ-CR
      `R3n` exit (R35AB) and the RF Championship's oblast branches `1`,
      `2`, `9`, `0`; `Name`, `NameQTH`, `CheckSection` (both fields, and one
      missing), `Grid`; the Russian oblast fallback; and the HISTORY branch
      (the `/` rewrite, the zone/IARU first-word drop, the SS leading `0`).
  - **NOT covered, and why:**
    - **`PACCCountriesAndPrefixes`** (and so UA9/UA0's PACC split), and
      **`SouthAndNorthAmericanPrefixes`** / **`NonSouthAmericanPrefixes`** --
      `DescribeSession` selects them only for a PA (`uContestPACC:229`) or
      South American (`uContestCQMM:234`, `uContestSouthAmericanWW:217`)
      entrant, and the matrix runs neither. This plan names no station for
      S0c, and a new variant is a process per contest; pin these in
      `uTestContestKindPin`'s roster (S0b's NOT DONE) or unit-test them at
      S3/S4, or add a `pa`/`py` variant -- NY4I's call.
    - **`GridSquares`' six-character branch** -- not reachable by a typed
      exchange: MEASURED, `599 FN31PR` is taken as a CALL CORRECTION
      (`call=FN31PR`, `cty=F/27/Europe`), so the grid never reaches
      `GetDomQTH`. Pinned as found -- a finding for `contest-scoring`.
    - **`InitialExchangeEntry`'s rover branch** (`RoverCall`) -- no logged
      call is a rover; and `Settings.InitialExchange.Reverse`, which nothing
      the matrix runs states.
    - **POTA's record** -- its set-up builds the operator-name set
      (`InitOperatorNameSet`), which sets `MasterFileExists` on the SHIPPED
      file, and by the `initialexchange` section the shipped index is OPEN
      (`.indexopen = TRUE`), so the fixture cannot be swapped in
      (`.fixture = FALSE`). POTA states no initial exchange, so no `iex`
      value reads the file; but POTA's EARLIER sections may read the shipped
      `TRMASTER.DTA` -- a refresh could move them. Not measured further.
    - The dead arms (1.1) -- deleted at S1, so pinned by nothing on purpose.
  - **The append-only proof.** A scratch script (`check_append_only.py`,
    not committed) removes, per variant, every line from a `== keys` or
    `== initialexchange` header up to the next `== ` or `### variant` line,
    and byte-compares the rest with the frozen record; it also FAILS a
    variant that has `== totals` but lacks either new section or has one
    empty. Dev runs (single-contest `matrix_run`, scratch output, the tree's
    `frozen/` never touched): 50 contests, all OK, +201 lines per
    three-variant record (+268 with `us-host`); two consecutive runs
    byte-identical. ALRS's empty-QTH points (Q37) are stable across runs
    for the new QSOs as for the old.
- **S0d** -- **Measure, do not change.** **DONE 2026-10-14.**
  - Can `InitialExchangeEntry` run headless in the matrix? If yes, add an
    `initialexchange` section (empty and logged history) at S0c's re-freeze.
  - Is `Doing*` (`LogCfg:433-436`, run once from `uProgramMain:2318`) re-derived
    when a contest changes without a restart (`uSettingsEffects:353`)? F9.
  - **How it was measured.** A scratch build of the app (scratchpad only;
    `tr4w.lpr` copied with absolute paths, and a patched COPY of
    `uContestMatrix` adding the probes below) was driven by `matrix-lib.sh`'s
    own `matrix_run`, pointed at the scratch binary and a scratch output
    directory -- nothing compared, nothing frozen, the tree untouched. Its
    records were byte-identical to the frozen ones outside the probe lines,
    for all 12 contests run.
  - **ANSWER 1: YES, it runs headless -- and the section S0c would add pins
    less than it looks.** Over CQWWCW (Custom), CQWWSSB, IARU, OZCR_O and
    RFCHAMPIONSHIPCW (Zone), NAQSOCW (Name), NASPRINTCW (NameQTH), ARRLDIGI
    (Grid), ARRLSSCW (CheckSection), RUSSIANDX, RDA and ARRLDXCW (none), at
    us/ve/dx, for the 11 matrix calls plus one unlogged call, before and
    after `CaptureTotals`' reload: 864 lines, no exception, byte-identical on
    a second run. Its UI calls (`CheckAndSetInitialExchangeCursorPos`) are
    `ControlUsable`-guarded no-ops. The zone kinds answer from CTY (CQ WW SSB
    gives CQ zones, IARU and OZCR ITU zones, the RF Championship its own
    rule). But two things make the section weaker than S0c assumed:
    - **The matrix opens no TRMASTER (F17).** `CD.MasterFileExists` is set at
      `uProgramMain:2701`, AFTER the `/MATRIX` halt at `:2405`, so
      `LoadInIndexArray` refuses: probed, `MasterFileExists=FALSE` with the
      shipped `TRMASTER.DTA` as `ActiveFilename`, and `CD.GetEntry('W1AW')`
      "not found" although the file holds W1AW (name HIRAM, read with
      `tools/trmaster/trmaster_codec.py`). So the Name, NameQTH, CheckSection
      and Grid arms, and Custom's TRMASTER commands, return blank for every
      call. The section would pin only their no-TRMASTER branch. Opening it
      in the harness would make every such record depend on the tracked
      `TRMASTER.DTA`, which is refreshed, so each refresh would re-freeze.
    - **The logged-history case is unreachable (F18).** `LoadinLog` adds a
      QSO's initial exchange to `CallsignsList` only `if not
      IntitialExLoaded`, and sets that latch at its end (`MainUnit:8031`).
      Start-up's `LoadinLog` (empty log) sets it, so `CaptureTotals`' reload
      adds nothing; the scoring section bypasses `logsubs2:1740`, the live
      path that does add it. Measured: "empty" equals "logged" for every
      line. Pinning history needs S0c to log through a path that calls
      `AddIniitialExchange`, or the harness to clear the latch.
  - **ANSWER 2: NO -- they DO diverge (F9).** `Doing*` has one writer,
    `LogCfg:433-436`, one caller, start-up (`uProgramMain:2318`). `CONTEST` is
    in `uCFG.SHARED_WITH_PEERS`, is registered with no restart or read-only
    flag, and a peer's change arrives through `uNet`'s `NET_PARAMETER_ID` arm
    -> `ApplyPeerCommand` -> the setting -> `uSettingsEffects:353` ->
    `FoundContest`, which rewrites the six kinds. Measured on that exact path
    (`ApplyPeerCommand('CONTEST', 'ARRL-SS-CW')` in a CQ WW CW session, all
    three stations): the session became `DomesticFile NoDXMults NoPrefixMults
    NoZoneMults` and `Doing*` stayed `FALSE TRUE FALSE TRUE`, CQ WW's. The
    matrix cannot see this: it opens one contest per process.
  - **So S2's `Doing*` bullet does not meet its own condition.** Moving the
    derivation into FCONTEST's applier would re-derive it on every
    `FoundContest`, which FIXES the run-time switch -- a behaviour change on
    that path, not a no-op. **DECIDED 2026-10-14 (orchestrator, design
    delegated): fix it at S2.** Stale `Doing*` after a contest change is an
    engine-correctness defect, not a sponsor rule: the sheet and the totals
    would count multiplier kinds the running contest does not have. S2
    re-derives `Doing*` wherever the kinds are written, says so in its
    commit, and pins the switch with a test. Whether an operator can switch contest
    locally without a restart (Preferences) was not measured.
- *Risk:* low, but S0c is a large re-freeze. *Specialists:* `contest-scoring`,
  `file-formats` (matrix exports), `build-release` (inventory tool).

### S1 -- Delete what S2 made dead

26 members, 32 arms, 5 compare lines, and the set entries (1.1).

- `InitialExchangeEntry`'s Section/QTH arms are the only callers of
  `zonecont.GetVEInitialExchange`, so the VE-province routine and the Russian
  `InitialExchangeFromCall` bodies lose their last caller -- **F3: settle Q50
  first, or this stage deletes a pinned seam.**
- `NoExchangeReceived` and its `ActiveExchangeArray` entry go.
  `UnknownExchange` stays (it is the zero).
- *Files:* `logedit`, `logdupe`, `logstuff`, `uADIFExchange`,
  `uCabrilloExchange`, `uMults`, `uContestBase`, `uContestReadiness`,
  `uGridShape`, `VC`, `zonecont`, the tests.
- *Matrix:* identical -- the arms are unreachable.
- *Risk:* low. Compile-proven, but a member removal also changes `Ord()` of
  later members: check that nothing persists an ordinal (L4 finds none; the
  logs store keys, not kinds).
- *Specialists:* `contest-scoring`, `file-formats`, `multi-op-network`
  (`tr4wserver` links `VC`: rebuild it).

### S2 -- Duplicates and tautologies (no behaviour change, except F6)

- **One statement per kind per class.** Align the five traits in 1.3 to what
  the session runs, and delete the 7 restatements. Then re-point
  `uTestContestSession`'s three trait-differs tests at contests that genuinely
  vary by station (ARRL DX, OKDX, JIDX, UBA).
- **Delete the 11 parse-rule shape guards (F11),** and update
  `uTestContestParse`'s "defers under another shape" cases.
- **Use the existing fields record for the SS columns:** `SetColumnsWidth`
  reads `ExchangeInformation.Precedence`/`.Check` (F15).
- **One domestic-key helper.** `DomStringParse` and `GetDomQTH` call one leaf,
  `uDomesticKey`, for RDA, DOK, IOTA, grid square and grid field. This fixes
  F6: an uninitialised result, and a global used as scratch. That is a
  behaviour change on a garbage path only.
- **One derivation of `Doing*`.** It moves to FCONTEST's applier, inside
  `ContestSession`, and every `ContestSession.<Kind> <> No*` sentinel (13
  lines) reads the flag -- **only if S0d proved the two cannot diverge
  today.** **S0d proved they CAN** (F9): this move is a behaviour change on a
  run-time contest switch -- DECIDED: a defect fix, done here (see S0d).
- *Matrix:* identical. *Risk:* low-medium (the Doing* move).
- *Specialists:* `contest-scoring`, `lcl-ui` (`MainUnit`, `uEditQSO`).
- **DONE 2026-10-14 (on `c749f2c5`), three bullets of five.** Unit run:
  86,396 passed, 1 failed (an SST assertion that pinned the deleted
  restatement; corrected, compiled, not re-run). Inventory: 94 rows
  unchanged; shape-4 sites 123 -> **108**, records 229 -> **214**, SHARED 85
  -> **70** (the 15 sentinels), PROXY 75 / SHAPE 43 / UNUSED 26 unchanged;
  `DescribeSession` kind statements 89 in 41 classes -> **77 in 32**.
  - **`Doing*` -- DONE, and NOT as written: no derivation moved.** The four
    LOGDUPE globals are gone. `ContestSession.DoingDomesticMults`,
    `.DoingDXMults`, `.DoingPrefixMults` and `.DoingZoneMults` are read-only
    properties COMPUTED from the kinds on every read (`kind <> No*`), so
    there is no second store and nothing for any writer to forget -- the
    run-time switch (F9) is fixed by construction, not by a second call in
    FCONTEST. Cost: a call and a field compare, as for the kinds; the
    busiest reader is `SetMultFlags`, four per QSO. **61 code reads
    repointed** in 10 units (`MainUnit` 11, `logedit` 9, `logdupe` 9 -- four
    of them its debug lines -- `uTotal` 8, `logsubs2` 6, `uWSJTX` 6,
    `uContestMatrix` 5, `LogCfg` 4, `uEditQSO` 2, `postunit` 1;
    the record fields `TADIFImportSession.DoingDomesticMults` and its
    readers are untouched), and LogCfg's four start-up assignments deleted.
    **CORRECTION: 15 sentinels, not 13** -- `logdom:220` (`GetDomQTH`'s
    no-domestic exit) and `postunit:2430` (the ADIF CQZ test) were not on
    the list; all 15 read the flag now (`uScoreTotals`' four by De Morgan,
    `not (all = No*)` = any flag). Equality is by definition. **Evidence the
    matrix stays identical:** the frozen `doing.*` line equals `kind <> No*`
    of the same record's `active.*` lines in all **580 records, 0
    mismatches** (scratch script), and the matrix opens one contest per
    process, so the computed answer prints what the start-up copy printed.
    **Pin:** `uTestContestKindPin.Test_DoingFlagsFollowEveryContestSwitch` --
    every member of the four kinds written and answered at once; S0d's case
    (CQ WW CW -> ARRL SS CW: FALSE TRUE FALSE TRUE -> TRUE FALSE FALSE FALSE)
    by literal at us, ve and dx; and all 187 contests switched in sequence at
    each station, flags = the resolved kinds. FoundContest itself is not
    driven (it writes Settings and the domestic list other suites read); the
    peer path end to end is a bench item. **F19 (new):** the flags are now
    right after a switch, but LogCfg's other start-up derivations from them
    (`NumberDifferentMults`, `RemainingMultDisplay`, `Sheet.SheetInitAndLoad`)
    and `uProgramMain`'s `SetUpExchangeInformation` / `SetColumnsWidth` still
    run once only, so a run-time switch remains incoherent elsewhere.
  - **One statement per kind per class -- DONE.** 12 unconditional
    statements found by script (each `DescribeSession` statement at the
    routine's top level compared with the class's own getter): the 5 of 1.3
    and the 7 restatements, exactly the plan's list. The five traits now
    say what runs -- ARRL10 DX `ARRLDXCCWithNoARRLSections`, ARRLFIELDDAY
    domestic `DomesticFile` (a NEW override; the base said
    `NoDomesticMults`), KCJ initial exchange `ZoneInitialExchange`, YBDX DX
    `ARRLDXCC` and prefix `IndonesianDistricts` -- and all 12 statements are
    deleted; JTDX's and NYQP's `DescribeSession` were left empty and are
    deleted (the base's is empty and neither parent overrides it). **Why it
    is behaviour-preserving:** the traits' only reader is
    `ApplyContestTraits` (L6, re-measured), each statement was unconditional,
    none of the 9 classes has a subclass, and the operator statements a
    restatement used to overwrite retired at M10 S2. **Oracle:** the kind
    pin (3,498 resolved-kind assertions) passed unchanged. Re-pointed: KCJ ->
    **JIDX CW at a JA station** (initial exchange), YBDX -> **WAEDC CW at a
    DL station** (prefix), ARRL10 -> **ARRL 160 at a W station** (DX); each
    also asserts the other station runs the trait. The Field Day DX test and
    an SST assertion now assert NO restatement. After S2, 24 contests run a
    kind their trait does not state at a matrix station (28 less ARRL10,
    ARRLFIELDDAY, KCJ, YBDX), 32 at some station.
  - **The 11 shape guards (F11) -- DONE.** Each class's session exchange is
    its trait for every station, not only the matrix's: none of the 11
    states `aSession.Exchange` in `DescribeSession` (L5, re-measured), all
    sit on `TContestBase` (no inherited statement), Sweepstakes' two
    runnings share the trait, and nothing calls `ParseReceivedExchange`
    with another session but the tests (IN7QPNE delegates to its parties,
    none of the 11). `uTestContestParse`'s six "another shape" cases (RAC,
    PCC, UA4W, IARU, UK/EI, Sweepstakes) are deleted with them;
    `uContestBase`'s contract comment says why, and that a rule written for
    a shape a class does NOT always run must still test it.
  - **NOT DONE -- the SS columns (F15).** Equality with
    `ExchangeInformation.Precedence`/`.Check` holds only once S1 deletes
    `CheckAndChapterOrQTH`; deferred to after S1, as directed.
  - **NOT DONE -- `uDomesticKey` (F6).** Not behaviour-preserving, which S2
    was told to be: besides F6's garbage paths, the two copies differ in
    control flow -- `GetDomQTH`'s IOTA arm has no `Exit`, so a valid key AND
    an unknown continent both fall through to the domestic-file lookup,
    while an over-long text or a non-digit number exits False. One helper
    either copies that flow into both callers or changes it. Its own
    commit, with the S0c parse cases (`iota`, `iota.dash`, `iota.short`,
    `dok`, `rda.short`, `grid.field`) as the oracle.

### S3 -- Prefix multipliers move into the classes (32 contests)

1. **Move (matrix identical).**
   - Add `TContestBase.PrefixMultiplierKey(const aQso): string` (base `''`),
     with helpers in a leaf: `WPXPrefix`, call-as-key, continent filters.
   - `SetPrefix` asks `ActiveContest`. Fetch it once per QSO, not per helper.
   - UBA/SAC/WAEDC/SAWW/CQMM state their station test inside the rule.
   - GAGARINCUP's six callsigns move into its class, which removes its shape-3 row.
   - `MainUnit:7290` becomes "the class has a prefix rule".
2. **Delete (format re-freeze).** `PrefixMultType`, the trait (347
   occurrences), `TSessionDefaults.PrefixMult`, the session field, and the
   DescribeSession statements.
- *Pins:* the matrix `pfx=` lines on S0c's QSOs, and `uTestContestKindPin`.
- *Risk:* low-medium. *Specialists:* `contest-scoring`, `log-database` (the
  `Prefix` key is persisted: the keys must be byte-identical, which the
  13-log rescore checks), `multi-op-network` (the key is in the packet).
- **PART 1 (THE MOVE) DONE 2026-10-14, on `42a999c1`.** Part 2 is separate
  and later; nothing in part 1 needs it.
  - **The seam.** `TContestBase.PrefixMultiplierKey(const aQso; out aKey:
    PrefixMultiplierString): boolean`, base False; the free
    `ContestPrefixMultiplierKey(aContest, ...)` answers False for nil
    (DUMMYCONTEST). **Not the `string` the plan sketched, on purpose:**
    six live arms (of nine) assigned only on a match and LEFT the QSO's prefix
    otherwise, and the rescore (`RecomputeQSOScoring`) runs over a stored
    record, so "no key" (False) and "an empty key" (True, `''`) must stay
    distinct; and the key is the field's own type, so nothing converts
    between the rule and the record. `LOGEDIT.SetPrefix` fetches
    `ActiveContest(Contest)` once per QSO and asks it; its `case` is gone,
    with the three dead arms (`NorthAmerican`, `Asian`, `Russian`).
  - **Helpers** (`contestFactory/uPrefixMultiplierKey.pas`, a leaf on VC and
    `uCallSignRoutines`): ZoneCont's `EuropeanCountriesAndWAECallRegions`,
    `SACDistrict` and `IndonesianDistrict`, moved as they stood (ZoneCont's
    copies deleted; each name they call resolved to `uCallSignRoutines`
    there and does here). `IndonesianDistrict` read `Settings.My.Country`;
    it takes the entrant's country, and YB DX passes `Station.MyCountry`.
    The plan's other helpers (WPX prefix, call-as-key, continent filters)
    were NOT made: each is one field read, and a helper would hold nothing
    but the contest's choice (design 1.3).
  - **The 32, by rule.** CTY prefix: APSPRINT, BATAVIA_FT8, CQ WPX CW+SSB
    (once, on `TContestCQWPXBase`), CQ WPX RTTY, DARCXMAS, OCEANIA DX x2, PCC,
    UCG. Callsign: CWOPEN, CWOPS, MINI40, MINI80, MINITEST, MST, CUPURAL.
    JT callsign: JTDX. Six memorial calls: GAGARINCUP (its shape-3 row is
    gone). South America: SASPRINT. YB: YBDX. Station-dependent, each
    asking `Station` as its `DescribeSession` does: UBA x2 (none at ON),
    CQ MM (the Americas from SA, else SA), SAWW (non-SA from SA, else SA),
    All Asian x2 (none in Asia, else CTY prefix), OK DX (CTY prefix at
    OK/OM only), WAEDC x2 (call regions in Europe, else none), SAC x2
    (district outside Scandinavia, else none). 31 units.
  - **`MainUnit:7290`** -- the `PrefixMult in [six kinds]` half is deleted,
    not replaced: since S2 `DoingPrefixMults` IS `PrefixMult <>
    NoPrefixMults`, so the set was a subset of the first half. The test is
    `DoingPrefixMults` alone, which is "the session has a prefix rule" until
    part 2 makes it a class answer.
  - **Pins, written BEFORE the move and run green on the old code.**
    `uTestPrefixMultiplierKey`: 79 literal (contest, entrant, QSO) -> key
    rows covering all 32 and every station branch -- including the PY
    entrant S0c could not reach for CQ MM and SAWW, and ON, SM, JA, OK and
    YB -- plus a count of 32. The old run went through the program's own
    case, lifted verbatim into the leaf for that run and selected by
    `uTestContestKindPin.Kinds` (exported for it): 86,398 -> **86,478**
    passed, 0 failed. After the move the same rows ask the classes, and
    `Test_EveryContestAgreesWithItsSessionKind` compares every ContestType
    x 9 entrants x 11 QSOs (18,513) with the old case, frozen in the test,
    under the resolved session kind -- no prefix contest lost a branch and
    no other gained a key; exactly 32 give one: **104,993 passed, 0
    failed**. That cross-check and its frozen case go with part 2.
    **PACC needs nothing here** -- it states no prefix kind; its PA branch
    is a DX rule (S4).
  - **Matrix: predicted IDENTICAL** (not run). At us/ve/dx each class
    answers exactly what the session's arm did -- the cross-check proves it
    for those three entrants' countries and continents among its nine -- so every `pfx=` line, the
    `== keys` section and every flag follow unchanged. One difference no
    oracle sees: F20.
  - **Narrowing 1267 -> 1264** (`$NARROW_CEILING` lowered): SetPrefix's
    three implicit narrowings went; the classes cast the same truncation
    explicitly. Measured by a scratch `-B` compile (the incremental build
    crashed FPC). `Lint-ContestNameTests` 6, unchanged.
  - **Inventory** (generated, then the tracked doc restored): rows 94 ->
    **84**; shapes 6/0/13/75 -> **6/0/12/66**; shape-4 sites 108 -> **106**
    (one `case`, one compare); records 214 -> **199** -- PROXY 75 -> **66**
    (reach-1 25 -> 20, reach-2-3 50 -> 46), SHARED 70 -> **67**, UNUSED 26 ->
    **23**, SHAPE 43; contests with rules outside the factory 66 -> **61**
    (CQMM, GAGARINCUP, SASPRINT, SOUTHAMERICANWW, YBDX leave).
    `judgements.SHAPE3` lost the GAGARINCUP row in the same change (the
    generator fails closed on it). Outside the factory `PrefixMultType` is
    now read only by FCONTEST's two writers, `ContestSession` and the
    matrix's `active.prefixmult` line -- part 2's list.

- **PART 2 (THE DELETION) DONE 2026-10-14, on `cbcba524`.** `PrefixMultType`
  is gone, and with it everything that only carried it.
  - **Deleted.** The enum (VC; 15 members, every member's use with it). The
    trait `PrefixMultiplierType` / `GetPrefixMultiplierType` on
    `TContestBase` and its 172 overrides. `ContestSession`'s field, its
    `PrefixMult` and `DoingPrefixMults` properties and `WritePrefixMult`.
    `TSessionDefaults.PrefixMult` and `svPrefixMult`. FCONTEST's two writes
    (`ApplyContestTraits`, `ApplySessionDefaults`). The 14 `DescribeSession`
    statements in 11 classes (UBA x2, All Asian x2, OK DX, WAE x2, CQ MM,
    SAWW, SAC x2); the South American WW's `DescribeSession` stated nothing
    else and is deleted whole. The matrix's `active.prefixmult` line. Part
    1's cross-check `Test_EveryContestAgreesWithItsSessionKind` and its
    frozen case; the 79 literal key pins stay. The inventory's `Pxm`
    (`scan.ACTIVE`, `scan.SESSION`, `model.FIELD_GETTERS`,
    `kind-reach.ENUMS`) and the stale `judgements` row for `SetPrefix`.
    `code-only` occurrences of `PrefixMultType`, `NoPrefixMults`,
    `WritePrefixMult`, `svPrefixMult` and `PrefixMultiplierType`: 374 / 653 /
    16 / -- / -- -> **0** each (`count-ids.ps1`); the one member name left,
    `CQNonEuropeanCountriesAndWAECallRegions`, is in `logddx.pas`, compiled
    by nothing (F14).
  - **`DoingPrefixMults` IS THE CONTEST'S ANSWER (closes F20).** Most of its
    readers ask with no QSO in hand -- the log grid's prefix column
    (`MainUnit:9549`), the remaining-mults column width (`:9920`), the
    remaining-mults cycle (`logsubs2:588`), the totals (`uTotal:215, :350`),
    `LogCfg`'s mult count, the score's "counts multipliers"
    (`uScoreTotals`) -- so "does the key assign" cannot answer it. It is a
    class answer: `TContestBase.HasPrefixMultiplier` (base False), True for
    the 23 contests with a prefix multiplier everywhere, and for UBA (not
    ON), the All Asian (not Asia), OK DX (OK/OM), WAE (Europe) and SAC (not
    Scandinavia) the very test their `DescribeSession` used to choose the
    kind -- which their keys now call, so key and answer cannot disagree.
    `LOGEDIT.DoingPrefixMults` = `ContestHasPrefixMultiplier(ActiveContest(
    Contest))`, read live against `Station` like the key; `SetMultFlags`
    asks the object it already holds, and `GatherScoreTotals` takes the
    contest (one more `ActiveContest` per score). So whether a prefix is set
    and what it is follow the same MY CALL: F20 is closed, and that is the
    one intended behaviour change -- a mid-session change of the entrant's
    country without a CONTEST change.
  - **Evidence it is otherwise identical.** At every matrix station the
    answer equals the frozen `doing` flag: a script over all 186 frozen
    records (580 variants) predicted each variant's prefix flag from the
    rule above -- **0 mismatches**, 31 contests True somewhere (OK DX is
    never True at us/ve/dx). The kind pin's prefix column, read as "not
    NoPrefixMults" before it was deleted, gave exactly the us (29), ve (29)
    and dx (31) sets now frozen in `uTestPrefixMultiplierKey.HAS_PREFIX`.
  - **Pins.** `Test_EveryContestHasItsPinnedPrefixMultiplier`: every
    ContestType at all nine roster stations against literal sets (us/ve/dx
    from the kind pin's column; PY, ON, SM, JA, OK and YB written by hand
    from the five station tests as they stood at `cbcba524`), each set's
    count, the INVARIANT that a contest with no prefix multiplier gives no
    key for any of the 11 QSOs, and exactly 32 contests True somewhere.
    `uTestContestKindPin` lost its prefix column (583 cells; 6 -> 5 kinds,
    187 x 3 x 5 and 22 x 5 assertions; the `varying` counts 7 and 6 are
    unchanged -- WAE also varies in its DX kind) and the prefix flag of its
    switch test; nothing else in it changed, and nothing was regenerated.
    `uTestContestSession` lost its prefix assertions and
    `Test_WAEDCRunsAPrefixMultiplierItsTraitDoesNotState` (its station
    split is `HAS_PREFIX`'s psUS/psDX rows now).
  - **Matrix: re-freeze, one line per variant.** Every record loses exactly
    its `active.prefixmult = ...` line(s) -- one per `### variant`, 580 in
    all -- and nothing else; `doing.domestic/dx/prefix/zone` keeps its format
    and values. Checked by running the matrix on 18 contests (the 9
    station-dependent ones, CQ WPX CW/RTTY, YB DX, Gagarin, JTDX, CQ WW, ARRL
    SS, Arizona and Idaho with their us-host) into scratch: 18 of 18 equal
    their frozen record minus those lines (56 lines).
  - **Narrowing 1264, unchanged** (scratch `-B`; the incremental build
    crashed FPC again). Inventory: rows **84**, shapes 6/0/12/66, records
    PROXY 66 / SHARED 67 / SHAPE 43 / UNUSED 23, 61 contests -- all
    unchanged; DescribeSession kind statements 77 in 32 classes -> **63 in
    30**.

### S4 -- DX multipliers move into the classes (78 contests)

1. **Move (matrix identical).**
   - Add `DXMultiplierKey(const aQso): string` and
     `CountryMode(aStation): CountryModeType`.
   - The common shapes become helpers the class calls: all countries, all but
     K/VE, all but the ARRL-section countries, and so on.
   - PACC, ARI, JTDX and BSCI state their own rule.
   - `FillVisibleBytes` asks a class answer that **reproduces today's three
     filters exactly** -- not the full rule, F7.
   - `uSettingsEffects:369-374` (M10 F5) asks `CountryMode`.
   - The two WAEDC `CombineWithMultipliers` read their station rather than the
     session.
2. **Delete (format re-freeze).** `DXMultType` and its trait (355), the
   session field and the statements.
- *Risk:* medium-high. `GetDXQTH` runs for every QSO and every rescore, and
  the country mode changes every CTY lookup. Time a rescore of the 13 logs
  before and after.
- *Specialists:* `contest-scoring`, `settings-config` (`uSettingsEffects`),
  `lcl-ui` (the remaining-mults window), `log-database` and
  `multi-op-network` (the `DXQTH` key).
- **PART 1 (THE MOVE) DONE 2026-10-14, on `3c8ce116`.** Part 2 (the deletion)
  is separate and later; nothing in part 1 needs it.
  - **The seams** (`TContestBase`, each with a nil-safe free function, nil
    being the classless DUMMYCONTEST):
    - `DXMultiplierKey(const aQso; out aKey: DXMultiplierString): boolean`,
      base False (`ContestDXMultiplierKey`). **Not the `string` the plan
      sketched, for S3's reason:** every arm assigned only on a match and LEFT
      the QSO's DX QTH otherwise, and the rescore runs over a stored record,
      so "no key" (False) and "an empty key" (True, `''` -- ARI's
      first-letter test on an empty country) stay distinct; the key is the
      field's own type.
    - `CountryMode: CountryModeType`, base `CQCountryMode`
      (`ContestCountryMode`) -- **parameterless, reading `Station`**, as
      `HasPrefixMultiplier` does, not `CountryMode(aStation)`: the one caller
      holds `ActiveContest`'s object, whose station is the `CurrentStation`
      snapshot FoundContest handed `DescribeSession`.
    - `ListsRemainingDXCountry(aCountryID, aContinent): boolean`, base True
      (`ContestListsRemainingDXCountry`) -- today's filters EXACTLY, not the
      DX rule (F7 stays open, unchanged).
  - **`LOGDUPE.GetDXQTH(aContest, var RXData)`.** Its head (COUNT DOMESTIC
    COUNTRIES, the WYSIWYG domestic QTH, the domestic-country call) is the
    engine's and stays; the `case ContestSession.DXMult of` is gone, with its
    four dead arms (no HB9, no OK, non-European, non-South American).
    `LOGDUPE.GetNumber`, whose only caller was the PACC arm, moved verbatim
    into `uContestPACC` as `PACCCallAreaDigit` -- it is NOT
    `uCallSignRoutines.GetNumber` (that one answers #0 and reads the call,
    not its prefix), so it was not merged.
  - **Helpers** (`contestFactory/uDXMultiplierKey.pas`, a leaf on VC and
    `uCallSignRoutines`): `IsUSAOrCanadaCountry` (K, VE),
    `IsUSACanadaHawaiiOrAlaskaCountry` (K, VE, KH6, KL), `IsARRLSectionCountry`
    (the same `ARRLSectionCountryString` the arm read) and
    `IsNorthAmericanDXCountry` -- each its arm's test, inverted, on a
    ShortString so no comparison allocates. NOT helpers (design 1.3): every
    country (the key is the CTY country), WAE's continent filter, the
    one-country exclusions (JT, ARI's first letter), UBA's and the Black Sea
    lists (`uCallSignRoutines` already holds them, one contest each), PACC.
  - **The 78, in 76 classes, by rule.** Every country, CQ list: BATAVIA_FT8,
    CQM, CQMM, CQ WW CW+SSB (once, on `TContestCQWWBase`), CQWWRTTY, DARC10M,
    EUDX, FOCMARATHON, GACWWWSACW, HADX, King of Spain x2, MARCONIMEMORIAL,
    OKDX, OKOMSSB, OZCR_O, Region 1 FD x3, RSGB18, UKEI, UKRAINIAN, WWIH.
    Every country, ARRL list: ARRL RTTY RU, CIS, LABRE, RADIOYOC, RU3AX,
    RUSSIANDX, UNDX, WRTC, YBDX, YODX, YOUTHCHAMPIONSHIPRF; YUDX (key
    constant, ARRL list for a YU entrant). Every country for some entrants:
    RDA (Russian), Helvetia (HB), JIDX x2 (JA), SAC x2 (Scandinavian), All
    Asian x2 (Asia) -- ARRL list there, CQ elsewhere; WAG (DL), Croatian (9A),
    ALRS (not a Russian outside UA1A/UA1C). Not the ARRL section countries:
    ARRL10, WFD; ARRL 160 (for an entrant in one). Not K/VE: CQ160 x2, AZ, FL,
    ID; ARRL DX (W/VE entrant, once on `TContestARRLDXBase`), Salmon Run (in
    state). Not K/VE/KH6/KL: ARCI; Delaware, 7QP, Texas (in state), NEQP (New
    England). ARI (not I), JTDX (not JT), BSCI (Black Sea), NAQP x3, NA
    Sprint x2, Internet Sprint, SST (North America but K/VE/KL), UBA x2 (its
    list outside ON, every country at ON), WAEDC x2 (Europe, for an entrant
    outside it), PACC (PA entrant). A class whose answer depends on the
    entrant tests exactly what its `DescribeSession` tests; where the key and
    the country list both ask, one private `CountsDXMultiplier` (WAE:
    `CountsEuropeanCountries`, UBA: `CountsUBACountries`) holds it. ALRS's
    oblast test was LIFTED out of `DescribeSession` into
    `CountsRDADistricts`, which both now call (one statement, not two).
  - **The country list** (`uSettingsEffects`' CONTEST arm):
    `CTY.ctyCountryMode := ContestCountryMode(ActiveContest(Contest))`, still
    straight after FoundContest. **36 contests choose the ARRL list at some
    roster station** (the 21 whose trait is an ARRL kind, the 15 whose
    `DescribeSession` states one), in 35 classes; the North American kind
    was never in the ARRL set and its seven contests keep the CQ list.
  - **The remaining-mults filter**: `mo.FillVisibleBytes(aContest)`, asked
    from `uProgramMain` with `ActiveContest(Contest)`; WAEDC x2 and UBA x2
    override it. `uMults` no longer reads the DX kind.
  - **WAEDC's final score** reads its station (`CountsEuropeanCountries`)
    instead of `TScoreTotals.SessionDXMult`, which now has no reader and goes
    with the enum in part 2. `uTestContestTotals.Test_WAEWeightsItsMultipliers`
    hands it European and North American stations, and pins that the session
    kind is not read.
  - **THE PER-QSO PATH -- ONE ActiveContest, NEVER MORE THAN BEFORE.**
    `GetDXQTH` takes the contest object; no caller fetches it twice. LOGEDIT
    gained `SetPrefix(aContest, var RData)` (the one-argument form delegates)
    and `SetDXQTHAndPrefix(var RData)`, the two steps the entry paths took, in
    order, from one lookup. Lookups per QSO, before -> after: the rescore
    (`MainUnit.RecomputeQSOScoring`) 1-2 -> 1 (`DoingPrefixMults`, then
    `SetPrefix` for a prefix contest; now one fetched at the top; its
    `SetMultFlags` and `CalculateQSOPoints` fetch their own, unchanged);
    `ParametersOkay`'s two exits 1-2 -> 1 each; the WSJT-X logged-ADIF path
    1-2 -> 1; the need-multiplier hint (`EditableLog.GetMultArray`, per spot
    in the band map) 1-3 -> 1. The keys allocate no string the old arms did
    not, except a station test that already allocated in its
    `DescribeSession` (`ScandinavianCountry`, `RussianID`, ALRS's
    `GetOblast`) -- SAC's prefix key made the same call per QSO since S3.
  - **Pins, written BEFORE the move and run green on the old code.**
    `uTestDXMultiplierKey`: 161 literal (contest, entrant, QSO) -> key rows
    covering all 78 and every station branch, over 14 entrants (us, ve, dx,
    a New England host, PA, JA, SM, HB, 9A, YU, ON, UA, UA1, EI) and 20 QSOs
    (including an empty country); 42 country-mode rows; 13
    remaining-filter rows; each with its count. The old run went through
    the program's case, set and filters, frozen in the test and selected by
    `uTestContestKindPin.Kinds`: **174,206 passed, 1 failed** -- the hand
    count of ARRL-list contests (35; measured 36, Delaware missed in the
    tally), corrected to the measured value. After the move the same rows
    ask the classes, and three cross-checks compare every ContestType x 14
    entrants (x 20 QSOs for the key: 52,360 keys, 2,618 modes, and every
    filter answer where the session counts DX) with the frozen rules under
    the resolved session kind: **174,209 passed, 0 failed**. The
    cross-checks and the frozen rules go with part 2; the literals stay.
  - **Matrix: predicted IDENTICAL** (not run). At us/ve/dx/us-host each
    class answers exactly what the session's arm did -- the cross-check
    proves it for those entrants among its fourteen -- so every `dxqth=`
    line, `cty.countrymode` and every flag follow unchanged. The window's
    filter and the WSJT-X path are not in the matrix.
  - **Narrowing 1264 and range 3, unchanged** (scratch `-B`; the incremental
    build crashed FPC, as at S3). `Lint-ContestNameTests`: no ContestType
    member was added outside the factory.
  - **Inventory** (generated, then the tracked doc restored): rows 84 ->
    **75**; shapes 6/0/12/66 -> **6/0/12/57**; shape-4 sites 106 -> **101**
    (GetDXQTH's `case`, `uMults`' three compares, `uSettingsEffects`' one);
    records PROXY 66 -> **57**, SHARED 67 -> **62**, UNUSED 23 -> **18**,
    SHAPE 43; contests with rules outside the factory 61 -> **54** (ARRL10,
    ARRL160, BSCI, JTDX, PACC, UBA x2 leave). `judgements.ROUTINES` names
    the new seams for `GetDXQTH` (whose remaining site is the WYSIWYG
    domestic head, S6's) and `FillVisibleBytes`.
  - **F21 recorded** -- the key, the list and the filter follow the live
    station while whether `GetDXQTH` runs still follows the set-up kind
    (`DoingDXMults`); part 2 closes it, as S3's did F20.

- **PART 2 (THE DELETION) DONE 2026-10-14, on `6b874f1a`.** `DXMultType` is
  gone, and with it everything that only carried it. `CountryModeType` and
  `CTY.ctyCountryMode` STAY: the ARRL/CQ country list is data CTY.DAT
  resolves calls against, not a rule.
  - **Deleted.** The enum (VC; 18 members, every member's use with it). The
    trait `DXMultiplierType` / `GetDXMultiplierType` on `TContestBase` and
    its 176 overrides. `TSessionDefaults.DXMult` and `svDXMult`.
    `ContestSession`'s field, its `DXMult` and `DoingDXMults` properties and
    `WriteDXMult`. FCONTEST's two writes (`ApplyContestTraits`,
    `ApplySessionDefaults`). The 26 `DescribeSession` statements, one in each
    of 26 classes (ALRS, ARRL 160, ARRL DX (base), All Asian x2, Croatian, DARC
    10M, WAE x2, Delaware, Helvetia, IRTS, JIDX x2, NEQP, PACC, RDA, SAC x2,
    7QP, Texas, UBA x2, WAG, Salmon Run, YU DX); the All Asian x2, Croatian,
    SAC x2 and Delaware `DescribeSession`s stated nothing else and are
    deleted whole. `TScoreTotals.SessionDXMult` (no reader since part 1).
    The matrix's `active.dxmult` line. Part 1's three cross-checks
    (`Test_EveryContest{Key,CountryMode}AgreesWithItsSessionKind`,
    `Test_RemainingCountriesFilterAgreesWithItsSessionKind`) and their frozen
    rules (`LegacyDXKeyOfKind`, `LegacyCountryModeOfKind`,
    `LegacyListsCountryOfKind`, `LegacyGetNumber`); the 161 key, 42 mode and
    13 filter literals stay, and the cross-check's count of 36 ARRL-list
    contests stays as a literal over the program. The inventory's `XM`
    (`scan.ACTIVE`, `scan.SESSION`, `model.FIELD_GETTERS`,
    `kind-reach.ENUMS`) and the stale `judgements` row for
    `FillVisibleBytes`. `code-only` occurrences (`count-ids.ps1`):
    `DXMultType` 387, `NoDXMults` 531, `GetDXMultiplierType` 355,
    `svDXMult` 23, `WriteDXMult` 17, `DXMultiplierType` 9, `SessionDXMult` 5
    -> **0** each; the 11 member names left (one each) are in `logddx.pas`,
    compiled by nothing (F14, Q91).
  - **`DoingDXMults` IS THE CONTEST'S ANSWER (closes F21).** A class answer,
    `TContestBase.HasDXMultiplier` (base False), with the nil-safe
    `ContestHasDXMultiplier`: True for the 56 contests whose session ran a
    DX kind wherever it ran, and for the other 22 the station test their
    `DescribeSession` used to choose the kind -- through the SAME private
    predicate their key and country list already ask (`CountsDXMultiplier`;
    WAE `CountsEuropeanCountries`; ALRS `not CountsRDADistricts(Station)`;
    for the Croatian, WAG and PACC, whose test stood inline in the key,
    `HasDXMultiplier` holds it and the key asks `HasDXMultiplier`). So the
    key, the list and the answer cannot disagree, and all read `Station`
    live: whether `GetDXQTH` runs and what it keys follow the same MY CALL.
    That is the one intended behaviour change -- a mid-session change of the
    entrant's country, continent or host state without a CONTEST change.
  - **Its readers.** Per QSO, every site already holding the contest object
    asks it (`ContestHasDXMultiplier`), with no new `ActiveContest`:
    `LOGDUPE.SetMultFlags`, `MainUnit.RecomputeQSOScoring` (the rescore),
    `LOGEDIT.SetDXQTHAndPrefix` (both `ParametersOkay` exits, the WSJT-X
    logged-ADIF path) and `EditableLog.GetMultArray` (the need-mult hint, per
    spot; asked once into a local). `mo.FillVisibleBytes` asks it once
    before its country loop, not per country. With no object in hand they
    ask `LOGEDIT.DoingDXMults` (one `ActiveContest`, as `DoingPrefixMults`):
    the DX column (`MainUnit`), the totals (`uTotal` x2), the remaining-mults
    cycle (`logsubs2`), `LogCfg`'s mult count, Edit QSO (x2), the matrix's
    `doing` line. "Counts any multiplier" had two spellings -- the score's
    (`uScoreTotals.GatherScoreTotals`) and the WSJT-X decode gate -- and is
    one now, `LOGEDIT.DoingAnyMults(aContest)`: the session's domestic and
    zone kinds first, the contest fetched at most once for its DX and prefix
    answers. None runs per log row or per paint.
  - **Evidence it is otherwise identical.** A script over all 186 frozen
    records (580 variants) predicted each variant's DX flag (the second
    `doing.*` word) from the rule above -- **0 mismatches**; the same script
    with the station tests removed (trait only) gives 20, so it sees the
    rule. 67 records are True somewhere. The kind pin's DX column, read as
    "not NoDXMults" before it was deleted, gave exactly the us (62), ve (62)
    and dx (58) sets now frozen in `uTestDXMultiplierKey.HAS_DX`.
  - **Pins.** `Test_EveryContestHasItsPinnedDXMultiplier`: every ContestType
    at all fourteen roster stations against literal sets (us/ve/dx from the
    kind pin's column; host, PA, JA, SM, HB, 9A, YU, ON, UA, UA1 and EI
    written from the station tests as they stood at `6b874f1a`), each set's
    count, the INVARIANT that a contest with no DX multiplier gives no key
    for any of the 20 QSOs, and exactly 78 contests True somewhere.
    `uTestContestKindPin` lost its DX column (583 cells; 5 -> 4 kinds) and
    the DX flag of its switch test; nothing in it was regenerated, but its
    two `varying` counts fall with the column, 7 -> **5** (WAE x2 varied in
    the DX kind only) and 6 -> **5** (Delaware likewise). `uTestContestSession`
    lost its DX assertions and `Test_ARRL160RunsADXMultiplierItsTraitDoesNotState`
    (its station split is `HAS_DX`'s rows now); its Field Day test asks
    `HasDXMultiplier`. Delaware's, Idaho's and Field Day's trait assertions
    in `uTestContestDelawareQP` / `uTestContestFactory` ask `HasDXMultiplier`.
  - **Matrix: re-freeze, one line per variant.** Every record loses exactly
    its `active.dxmult = ...` line(s) -- one per `### variant`, 580 in all --
    and nothing else; `doing.domestic/dx/prefix/zone` keeps its format and
    values. Checked by running the matrix on 29 contests (the 22
    station-dependent ones, IRTS, CQ WW CW, CQ WPX CW, Idaho, Arizona, ARRL
    and Winter Field Day) into scratch: 29 of 29 equal their frozen record
    minus those lines (93 lines).
  - **Narrowing 1264 and range 3, unchanged** (scratch `-B`; the incremental
    build crashed FPC, as at S3 and S4 part 1). `tr4wserver` builds.
    Inventory: rows 75 -> **73**; shapes 6/0/12/57 -> **6/0/12/55**; shape-4
    sites 101 -> **100** (7 `case`s -> 6); records PROXY 57 -> **55**
    (reach-1 16 -> 15, reach-2-3 41 -> 40), SHARED 62 -> **58**, UNUSED 18 ->
    **15**, SHAPE 43; contests with rules outside the factory 54 -> **51**;
    DescribeSession kind statements 63 in 30 classes -> **37 in 19**.

### S5 -- Zone multipliers become class answers (20 contests)

1. **Move.**
   - New class answers: zone count, zone system for the tag and the initial
     zone, and zero-based numbering. The EUHFC range moves into the
     EUROPEANHFC and KVP parse.
   - The ADIF CQZ/ITUZ tag keeps its present rule.
   - **F5 must be answered or transcribed exactly first:** CROATIAN is ITU
     zone-mult over a CQ zone mode and exports a CQ zone as `ITUZ`; CWOPEN is
     the inverse. Do not fold the zone multiplier into `cfCQZoneMode`; that
     would change both.
2. **Delete.** `ZoneMultType` and its trait (349).
- *Risk:* medium (ADIF output). *Specialists:* `contest-scoring`,
  `file-formats` (CQZ/ITUZ).
- **PART 1 (THE MOVE) DONE 2026-10-14, on `f0c54f4c`.** Part 2 (the deletion)
  is separate and later; nothing in part 1 needs it.
  - **The seams** (`TContestBase`, each with a nil-safe free function, nil
    being the classless DUMMYCONTEST, which ran `NoZoneMults`):
    `ZoneMultiplierCount: integer` (base 0; `ContestZoneMultiplierCount`),
    `ZoneMultiplierZones: TZoneMultiplierZones` (base `zmzNotCQOrITU`;
    `ContestZoneMultiplierZones`) and `NumbersZonesFromZero: boolean` (base
    False; `ContestNumbersZonesFromZero`). `TZoneMultiplierZones =
    (zmzNotCQOrITU, zmzCQZones, zmzITUZones)` is new in `uContestBase`, and
    is deliberately NOT `ZoneModeType`: it is the list the MULTIPLIER counts,
    while `ZoneMode` (`cfCQZoneMode`) is which zone CTY.DAT gives a call.
    `CQ_ZONE_MULTIPLIERS` (40) and `ITU_ZONE_MULTIPLIERS` (75) are named
    once there; there is no shared computation, so there is no leaf.
  - **The 20 contests in 19 units.** CQ zones, 40: CQ WW CW and SSB (once,
    on `TContestCQWWBase`), CQ WW RTTY, CW Open, GACW WWSA, WWIH, and JIDX CW
    and SSB for a Japanese entrant only (its private `IsJapaneseEntrant`,
    which is `CountsDXMultiplier` renamed -- the DX answers ask it too, and
    it is the test `DescribeSession` states `CQZones` under). ITU zones, 75:
    BSCI, the Croatian, Gagarin Cup, IARU, LZ DX, OZCR-O and OZCR-Z. The
    year licensed, 100, numbered from zero: the European HFC and KVP. The
    NZART branch, 99: Jock White (NZFIELDDAY). The RF Championship's 7 zones:
    CW and SSB. Own-numbered contests state only the count; their list is
    the base's.
  - **The engine readers.** `LOGDUPE.SetUpRemainingMultiplierArrays`' `case`
    is one call (its JAPrefectures arm, 50, ran for no contest); LOGEDIT's
    hint (`GetMultArray`) asks the contest it already holds;
    `ShowRemMultsInWindow` asks zero-based numbering ONCE before its zone
    walk (it was inside the loop); `InitialExchangeEntry`'s ITU initial zone
    and `POSTUNIT.ZoneSentForThisContest(aContest)` and the ADIF CQZ/ITUZ
    block ask the same `ZoneMultiplierZones` -- ONE source, as S9c made it
    (F4). `ContestSession.ZoneMult` keeps only `DoingZoneMults` and the
    matrix's `active.zonemult` as readers (and the uncompiled `logddx`).
  - **THE EUHFC RANGE DID NOT MOVE -- IT WAS VACUOUS.** `LOGSTUFF.
    ProcessRSTAndZoneExchange`'s `ZoneMult = EUHFCYear` arm accepted two
    digits as 0..99 and skipped the CQ-zone limit. Two digits are always
    0..99, and that limit applies only in CQ zone mode, which neither the
    European HFC nor KVP ever runs (their own flags: ITU, the only mode
    FCONTEST sets for them). The arm and the fall-through answered alike
    for every input, so it was deleted rather than moved into their parse;
    the matrix's `parse age "599 45"` (accepted, zone 45) pins both. The
    two JAPrefectures arms beside it (plan 2.4, "goes at S1") read a kind no
    contest runs and went with it.
  - **F5 / Q95 TRANSCRIBED, NOT FIXED.** The Croatian answers `zmzITUZones`
    over a CQ `ZoneMode` (W1AW exports `<ITUZ:2>05`); CW Open answers
    `zmzCQZones` over an ITU one. Both classes say so beside the answer, and
    `uTestZoneMultiplier.Test_CroatianAndCWOpenKeepTheirTwoZoneSystemsApart`
    pins the two facts side by side, so Q95's decision is a deliberate edit
    there. The matrix pins both contests' ADIF zone tags at us/ve/dx.
  - **THE PER-QSO PATH IS UNCHANGED.** `SetMultFlags`' zone test still asks
    `DoingZoneMults` and nothing else; the rescore's per-QSO work has no new
    lookup. New `ActiveContest` calls, each once: per remaining-mults set-up
    (load, rescore), per zone-window refresh, per ADIF record exported (the
    tail emitter fetches once and
    passes it to the zone sent, STX_STRING and the tag -- the new
    `POSTUNIT.MyExchangeForExport(aContest)`), per QSO the external logger
    sends (`GetMyExchangeForExport`, now a wrapper), and once per Cabrillo
    export (held for the whole log). The hint fetches none: it already held
    the contest. **The TRMASTER initial zone asks `ContestIdentity`, not
    `ActiveContest` (F22):** the first build fetched the active contest there
    and moved three matrix records, through a pre-existing uninitialised
    read in `LOGSCP.BestTwoLetters`; the choice itself is now the pure
    `uContestBase.InitialZoneFromCallHistory` (the old rule exactly: ITU
    list -> the entry's ITU zone or nothing, else its CQ zone or nothing).
  - **Pins, written BEFORE the move and run green on the old code.**
    `uTestZoneMultiplier`: 36 literal (contest, station) -> (count, list,
    zero-based) rows covering all 20 and JIDX on both sides of its test,
    over 7 entrants (us, ve, dx, a New England host, JA, 9A, UA); every
    ContestType at every entrant against literal sets (exactly 20 count
    zones somewhere); a cross-check of every ContestType x 7 entrants
    against the frozen old rules under the resolved session kind; and the
    F5 pair. Old code (the Program functions returning the frozen rules):
    **148,128 passed, 0 failed**. After the move, the same tables ask the
    classes: **148,128 passed, 0 failed**. Added with the F22 fix (no
    old-code run -- the helper did not exist; its rows are the old arm's
    branches by hand): `Test_CallHistoryOffersTheZoneOfTheContestsList` (12
    rows -- the Croatian, IARU, IRTS, WRTC, CQ WW, CW Open, JIDX and the
    classless contest, with the fixture's JA1ABC zones and the half-empty
    entries) and `Test_TheITUQuestionDependsOnNoStation` (every ContestType
    at every roster entrant). The cross-check and the frozen
    rules go with part 2; the literals stay.
  - **Matrix: MEASURED IDENTICAL, all 186 records byte-for-byte against
    `frozen/`** (a scratch run of the final build, not the freeze script).
    The first build's prediction ("identical; the ITU initial zone is not
    reached, F17") was WRONG on its reason -- S0c's fixture reaches that
    branch -- and wrong in result: the Croatian, IRTS and WRTC moved one
    `iex JA1ABC` line per station. The cause is F22, not the zone rule; see
    above and the F22 row. `zones.max` (40, 75, 100, 99, 7), every ADIF
    `CQZ`/`ITUZ` tag, the parse section, the initialexchange section and
    `active.zonemult` are unchanged.
  - **Narrowing 1264 and range 3, unchanged** (scratch `-B`; the
    incremental build crashed FPC, as at S3 and S4). `Lint-ContestNameTests`
    6, unchanged.
  - **Inventory** (generated, then the tracked doc restored): rows 73 ->
    **68**; shapes 6/0/12/55 -> **6/0/12/50**; records PROXY 55 -> **50**,
    SHARED 58 -> **50**, UNUSED 15 -> **12**, SHAPE 43; contests with rules
    outside the factory 51 -> **48** (EUROPEANHFC, KVP, NZFIELDDAY leave).
    `judgements.ROUTINES` names the new seams for
    `SetUpRemainingMultiplierArrays` and the zone window.

- **PART 2 (THE DELETION) DONE 2026-10-14, on `a8186905`.** `ZoneMultType`
  is gone, and with it everything that only carried it. `ZoneModeType` and
  `cfCQZoneMode` STAY: they are the CTY lookup's zone system, not the
  multiplier's list (F5, Q95 open).
  - **Deleted.** The enum (VC; 7 members, every member's use with it). The
    trait `ZoneMultiplierType` / `GetZoneMultiplierType` on `TContestBase`
    and its 173 overrides. `TSessionDefaults.ZoneMult` and `svZoneMult`.
    `ContestSession`'s field, its `ZoneMult` and `DoingZoneMults`
    properties and `WriteZoneMult` (three kinds remain in the session).
    FCONTEST's two writes (`ApplyContestTraits`, `ApplySessionDefaults`).
    The two `DescribeSession` statements, JIDX CW and SSB's `CQZones` for
    a JA station (their `DescribeSession`s state other values and stay).
    The matrix's `active.zonemult` line. Part 1's cross-check
    (`Test_EveryContestAgreesWithItsSessionKind`) and its frozen rules
    (`LegacyZoneCountOfKind`, `LegacyZonesOfKind`,
    `LegacyFromZeroOfKind`); the 36 literal rows, the every-contest sets,
    the F5 pair pin and the call-history rows stay.
    `uTestContestSession.Test_JIDXRunsAZoneMultiplierItsTraitDoesNotState`
    went with the kind (uTestZoneMultiplier pins JIDX at a JA entrant). The
    inventory's `ZnM` (`scan.ACTIVE`, `scan.SESSION`,
    `model.FIELD_GETTERS`, `kind-reach.ENUMS`) and two `judgements` rows
    that matched no site since part 1 (`SetUpRemainingMultiplierArrays`,
    LOGEDIT's `Add`). `code-only` occurrences (`count-ids.ps1`):
    `ZoneMultType` 378, `NoZoneMults` 693, `GetZoneMultiplierType` 349,
    `CQZones` 31, `ITUZones` 35, `EUHFCYear` 11, `RFChampionchipZones` 10,
    `BranchZones` 7, `WriteZoneMult` 18, `svZoneMult` 7,
    `ZoneMultiplierType` 5 -> **0** each; `JAPrefectures` 4 -> 2, both in
    `logddx.pas`, compiled by nothing (F14, Q91).
  - **`DoingZoneMults` IS THE CONTEST'S ANSWER.** A class answer,
    `TContestBase.HasZoneMultiplier` (base False), with the nil-safe
    `ContestHasZoneMultiplier`: True at every station for the 18 contests
    whose trait stated a zone kind (17 overrides -- CQ WW CW and SSB share
    `TContestCQWWBase`'s); JIDX CW and SSB answer `IsJapaneseEntrant`, the
    private predicate their zone count, zone list and DX answers already
    ask -- the test `DescribeSession` stated `CQZones` under. INVARIANT:
    True exactly where `ZoneMultiplierCount` is above 0, asserted for every
    contest at every roster station. Read live against `Station`, as the
    DX and prefix answers are: a mid-session change of MY CALL without a
    CONTEST change is followed (the kind was resolved once by FoundContest;
    for JIDX the count and list already followed `Station`, so the three
    answers can no longer disagree).
  - **Its readers.** Per QSO, every site already holding the contest asks
    it, with no new `ActiveContest`: `LOGDUPE.SetMultFlags`
    (`contestRules`), `MainUnit.RecomputeQSOScoring` (the rescore),
    `EditableLog.GetMultArray` (the hint, per spot; asked once into a
    local beside `countsDX`) and the ADIF tail (`POSTUNIT`, the object it
    already fetched for the zone list). `SetUpRemainingMultiplierArrays`
    fetches the contest ONCE for both its zone questions. With no object
    in hand they ask the new `LOGEDIT.DoingZoneMults` (one
    `ActiveContest`, as `DoingDXMults`): `LogCfg`'s mult count, the
    remaining-mults cycle (`logsubs2`), the totals (`uTotal` x2), the
    matrix's `doing` line. `LOGEDIT.DoingAnyMults` asks it of the one
    contest it fetches; the session's domestic kind is the only field
    read left ahead of the fetch, so a zone-only contest (CQ WW) now
    costs one `ActiveContest` per score gather / WSJT-X decode where it
    cost none -- as every DX contest already did. LOGDUPE's debug line
    asks as its DX and prefix siblings do (debug level only). None runs
    per log row or per paint.
  - **The TRMASTER initial zone asks `ActiveContest`** (F22 is fixed at
    `a8186905`), like every other zone reader; once per initial exchange
    TRMASTER answers. `Test_TheITUQuestionDependsOnNoStation` stays: it is
    now why `HISTORY_PINS` (which ask `ContestIdentity`) pin what LOGEDIT
    offers. The matrix moved nowhere for it (below), the Croatian, IRTS
    and WRTC included.
  - **Evidence it is otherwise identical.** A script over all 186 frozen
    records (580 variants) predicted each variant's zone flag (the fourth
    `doing.*` word) from `HasZoneMultiplier` as the source states it
    (overrides read from the units, inherited along `class(TParent)`,
    `IsJapaneseEntrant` from MY CALL) -- **0 mismatches**; 18 records are
    True. The same script with the station test removed (JIDX answering
    True everywhere) gives **6** (JIDX CW and SSB at us, ve and dx), so it
    sees the rule. The matrix runs no JA station, so its True side is the
    unit pin's alone. The kind pin's zone column, before it was removed,
    gave exactly the 18 contests at us, ve and dx and none at us-host
    that `uTestZoneMultiplier`'s sets hold.
  - **Pins.** `uTestZoneMultiplier`: the 36 literal rows now also assert
    `HasZoneMultiplier = (count > 0)`; `Test_EveryContestHasItsPinnedZone
    Multiplier` asserts it for every ContestType at all seven stations
    against the literal sets AND against the count (the invariant), with
    literal per-station totals (18 at us, ve, dx, host, 9A and UA; 20 at
    JA). `uTestContestKindPin` lost its zone column (583 cells; 4 -> 3
    kinds), its per-member zone loop and the zone flag of its switch test;
    nothing in it was regenerated, and both `varying` counts stay at 5 (no
    contest varied in its zone kind at the pinned stations).
    `uTestContestSession` lost its zone assertions (JIDX's
    `DescribeSession`, the running-session writer loop) and the JIDX zone
    test; `uTestOffBandCredit` its zone-kind writes (Idaho has none);
    `uTestContestFactory`'s Jock White row asks `HasZoneMultiplier` and
    the count, 99. Unit tests: **147,540 passed, 0 failed** (150,100 at
    `a8186905`; the drop is the cross-check and the removed column, less
    the new has-checks).
  - **Matrix: re-freeze, one line per variant.** Every record loses exactly
    its `active.zonemult = ...` line(s) -- one per `### variant`, 580 in
    all -- and nothing else; `doing.domestic/dx/prefix/zone` keeps its
    format and values. Checked by running the whole matrix (186 records)
    into scratch with the final build: 186 of 186 equal their frozen record
    minus those lines, byte for byte (580 lines). Not frozen here.
  - **Narrowing 1264 and range 3, unchanged** (scratch `-B`; the
    incremental build crashed FPC, as at S3 and S4). `tr4wserver` builds.
    `Lint-ContestNameTests` 6, unchanged. Inventory (generated, then the
    tracked doc restored): rows **68**, shapes **6/0/12/50**, contests with
    rules outside the factory **48** -- unchanged, part 1 had moved every
    zone rule; shape-4 sites 89 -> **87** (82 comparisons, 5 `case`s),
    records 155 -> **153** (PROXY 50, SHARED 50, SHAPE 43, UNUSED 12 ->
    **10**); DescribeSession kind statements 37 -> **35** in 19 classes.

### S6 -- Domestic multipliers move into the classes (119 contests)

1. **Move.**
   - Add `DomesticMultiplierFromQTH(...)`. The base performs the domestic-file
     lookup; helpers from S2's `uDomesticKey`.
   - WYSIWYG (11), grid (11), IOTA, DOK and RDA (5) override it.
   - The grid-rover rules (`logedit:477`, `logsubs2:1307/1622/1635`,
     `logstuff:6259`) become a class answer, held by the ARRL VHF x3, CQVHF,
     OZHCRVHF and RTC as copies.
   - The mobile rewrite (`logsubs2:1611`) is a stated class answer for exactly
     today's 94 contests (2.6).
   - The legacy grid-field key compatibility in `uMults:211` stays in the
     sheet, keyed on a class answer.
2. **Delete.** `DomesticMultType` and its trait (357).
- *Risk:* medium-high: the widest reach, and the IN7QPNE composite keys on its
  own combined file (Q80). *Specialists:* `contest-scoring`, `lcl-ui`
  (`uWSJTX`, the need-mult hint), `file-formats` (`postunit:2402`),
  `log-database` (`DomMultQTH` is persisted).
- **PART 1 IS SPLIT IN TWO, BY FAMILY -- the domestic file versus the rest.**
  Done in one change, part 1 touches about 120 units: the 94 contests whose
  domestic QTH is looked up in a file each need a STATED answer for the two
  rules that ask `= DomesticFile` (the mobile rewrite, readiness), because
  the kind cannot be derived from the file name (2.6). The key itself does
  not: the domestic-file lookup is the base's answer. So part 1a moves
  every rule that is NOT the domestic file (25 contests); part 1b states the
  domestic-file answer for the 94; part 2 deletes the kind.
- **PART 1a (THE MOVE, NOT THE DOMESTIC FILE) DONE 2026-10-14, on
  `45ca8855` (uncommitted at hand-back).** Part 1b and part 2 are separate
  and later.
  - **The seams** (`TContestBase`, each with a nil-safe free function, nil
    being the classless DUMMYCONTEST, which ran `NoDomesticMults`):
    `DomesticMultiplierFromQTH(aText: Str20; var aMultiplier, aQTH: Str10;
    var aFound): TDomesticQTHAnswer` -- `TDomesticQTHAnswer =
    (dqaDecided, dqaLookUpDomesticFile)` is new in `uContestBase`; the base
    answers `dqaLookUpDomesticFile` and writes nothing, which is what every
    `DomesticFile` and `NumericID` session did. `DomesticMultiplierHint(aText:
    Str14): string` (base: the text). Four yes/no answers, base False:
    `HasGridSquareMultiplier`, `HasGridFieldMultiplier`,
    `DomesticQTHReplacesDXMultiplier`, `DomesticQTHIsNeverAGrid`.
  - **The 25 contests in 25 units.** WYSIWYG, the key and the DX guard:
    Arktika, BSCI, DARC Xmas, Gagarin Cup, GridLoc, IARU, OZCR-Z, UA4W,
    WRTC; the ALRS cup unless `CountsRDADistricts` (then RDA: key, hint,
    never-a-grid); the DARC 10 m for a DL entrant (`Station.MyCountry =
    'DL'`; else DOK). DOK, key and hint: WAG and the DARC 10 m for anyone
    but DL -- the test both `DescribeSession`s state the kind under. RDA:
    key, hint, never-a-grid. IOTA: the RSGB IOTA's key and hint, through
    its own `ReadIOTAReference` (one contest, so no helper). Grid square
    (key, hint, the flag): the ARRL VHF x3, CQ VHF, OZHCR VHF and RTC, as
    copies. Grid field (key, hint, the flag): the Russian Cups CW and SSB,
    TOEC, WW Digi, WWL.
  - **The leaf `uDomesticKey`** holds the four shapes more than one contest
    reads: `RDADistrictKey`, `DOKKey`, `GridSquareKey`, `GridFieldKey`,
    each its arm's test as it stood (the two copies agreed on every one).
    `GetContinentFromString` moved, unchanged, from ZoneCont to
    `utils_text`, because the IOTA class reads it and cannot reach ZoneCont;
    every caller already used `utils_text`.
  - **F6 -- TRANSCRIBED, NOT UNIFIED, AND NOT FIXED.** The two copies
    differed in control flow, not in the shape tests, so the shapes are
    shared and each copy's flow is kept where its rule now lives:
    GetDomQTH's IOTA arm (no Exit: a valid reference reaches the domestic
    file already found, an unknown continent reaches it not found, a
    malformed text ends the lookup) is the RSGB IOTA's
    `DomesticMultiplierFromQTH`, returning `dqaLookUpDomesticFile` with the
    key written; DomStringParse's DOK arm, which returned its local
    `TempMultiplier` unassigned when the text had no letter, is WAG's and
    the DARC 10 m's `DomesticMultiplierHint`, reading an unassigned local
    the same way (FPC warns, once in each). The fix is `Result := ''` in
    both, in a commit of its own. The IOTA hint's scratch use of
    `LOGWIND.ContinentString` became a local: nothing read the global, so
    that half of F6 changed no behaviour. `LOGWIND.ContinentString` now
    has one writer (FCONTEST) and no reader -- S1's.
  - **The engine readers.** `LOGDOM.GetDomQTH` keeps its head (outputs
    zeroed, `strU`, the `DoingDomesticMults` exit) and the file lookup, and
    asks `ContestDomesticMultiplierFromQTH(ActiveContest(Contest), ...)`
    between them. `LOGSTUFF.DomStringParse` is `strU` and
    `ContestDomesticMultiplierHint`. `= GridSquares`: `LOGEDIT.CallIsADupe`,
    `LOGSUBS2.ShowPartialCallMults` and `LogContact` (both of its tests,
    asked once), `LOGSTUFF.DisplayGridSquareStatus`. `= GridFields`:
    `uMults.IsDmMult`, whose parameter is now `aKeyedOnGridField: boolean`,
    `uWSJTX`'s station hint, and the factory's `IsNewMultiplierAnywhere`
    service (asking `GActive`, NOT `ActiveContest`: the service runs inside
    the active object's own scoring, and `ActiveContest` would rewrite its
    station mid-call). `= WYSIWYGDomestic`: `LOGDUPE.GetDXQTH`, on the object
    handed in. `<> RDADistrict`: the ADIF tail, on its `contestRules`.
    `uWSJTX` and `uContestFactory` no longer use `uContestSession`.
  - **What still reads the domestic kind (part 1b, part 2):**
    `ContestSession.DoingDomesticMults` (every `Doing` reader, and
    GetDomQTH's exit); `= DomesticFile` in `LOGSUBS2.LogContact`'s mobile
    rewrite and `uContestReadiness` (via `uProgramMain`);
    `TADIFImportSession.DomesticMult` (filled in MainUnit's ADIF import, read
    by the base `ApplyADIFImport` as `= GridSquares` -- the operator's open
    contest, so `HasGridSquareMultiplier` will answer it); the matrix's
    `active.domesticmult` line; FCONTEST's writes.
  - **Hot path.** GetDomQTH fetches the contest ONCE, after the no-domestic
    exit, so a contest with no domestic multiplier pays nothing new; its
    callers (the parse shapes, ~50) hold no object. The rescore does not
    call GetDomQTH except through `ctyLocateCallStripRover` for a slash call
    under a QP exchange (one fetch beside that routine's three Info lines).
    It does call `CallIsADupe` for every QSO, so there the ROVER TEST GOES
    FIRST and the contest is fetched only for a rover. `SetMultFlags` passes
    the object it holds. `LogContact` fetches once per live QSO. Not timed
    here.
  - **Pins, written BEFORE the move and run green on the old code.**
    `uTestDomesticMultiplier`, 11 entrants (us, ve, dx = DL, a New England
    host, UA outside and UA1 inside St Petersburg, JA, OK, ON, UR, YU) and 16
    texts chosen to read several ways (MO12 is an RDA district and a grid;
    EU12 an IOTA reference, a district and a grid; EU-12, EUAB, EU1234 and
    XX12 the IOTA arm's three other exits; 123 a DOK with no letter; an 18-
    character text for the 10- and 14-character cuts): 139 literal key rows
    and 137 literal hint rows over the 25 contests and seven domestic-file
    contests; every ContestType at every entrant against literal sets for
    the four flags, with literal per-station counts; and cross-checks of
    every ContestType x entrant x text against the frozen old routines
    (`LegacyDomesticKeyOfKind`, `LegacyHintOfKind`, `LegacyFlagOfKind`) under
    the resolved session kind, which go with part 2. The DOK hint for a text
    with no letter is not pinned -- there is no value to freeze. Old code
    (the Program functions returning the frozen rules): the whole run
    **217,934 passed, 0 failed**. After the move: ****217,933 passed, 1 failed** --
    `uTestOffBandCredit.Test_OffBandShowsNoMultiplierNeeded`, which wrote
    `WYSIWYGDomestic` into the session for Idaho (a kind Idaho never runs) so
    that GetDomQTH would take 'ADA' without a domestic file. Idaho's rule
    is the file now, so the test was corrected to give it its own session
    kind (`DomesticFile`) and Ada in the domestic table, removed again after;
    compiled, not re-run (the stage's two-run budget). The pins themselves
    all passed after the move**.
  - **Matrix: MEASURED IDENTICAL, all 186 records
    byte-for-byte against `frozen/`** (a scratch run of the scratch `-B` build, not the
    freeze script).
  - **Narrowing 1264 -> 1263**, **range 3** (scratch `-B`; the
    incremental build crashed FPC, as at S3-S5). The new code raises none
    (checked per file); the one that went is most likely an old IOTA arm's
    `UpperCase` into a ShortString -- not attributed against a HEAD build.
    `Lint-ContestNameTests` 6, unchanged.
  - **Inventory** (generated, then the tracked doc restored): rows 68 ->
    **61**; shapes 6/0/12/50 -> **6/0/12/43**; shape-4 sites 87 -> **68**
    (63 comparisons, 5 `case`s); records PROXY 50 -> **43**, SHARED 50 ->
    **38**, SHAPE 43, UNUSED 10; contests with rules outside the factory 48
    -> **44** (the ALRS cup, the DARC 10 m, the RSGB IOTA, WAG leave). The
    `judgements.ROUTINES` rows for GetDomQTH, DomStringParse and GetDXQTH,
    which no site matches now, are comments saying where the rules went.

- **PART 1b (THE DOMESTIC FILE) DONE 2026-10-14, on `25d2bf25`
  (uncommitted at hand-back).** Part 2 (the deletion) is separate and later.
  - **The seam.** `TContestBase.UsesDomesticFile: boolean` (base False),
    with the nil-safe `ContestUsesDomesticFile`: is the domestic QTH looked
    up in the contest's domestic file. STATED, not derived from the file
    name (2.6).
  - **How it is stated for 94 contests -- the least duplicative statement
    that still lets each contest own its rule.** Once per family where the
    rule genuinely is the family's: `TContestStateQSOPartyBase` (all 20
    parties -- each counts its .dom's counties and states; every trait said
    DomesticFile), `TContestARRLSSBase` (Sweepstakes CW and SSB) and
    `TContestNRAUBalticBase` (whose trait already sat there). Per class for
    the other 61, which share no family (`Result := True`). Where the
    entrant decides, the class's own station test, the one its
    `DescribeSession` states DomesticFile under: ARRL DX (`not
    CountsDXMultiplier`, on its family base), JIDX CW and SSB (`not
    IsJapaneseEntrant`), OK DX (`not OKOMStation`), UBA CW and SSB (`<>
    'ON'`), the Ukrainian DX (`<> 'UR'`), YU DX (`<> 'YU'`). 72 class units.
    **Why not a derived base:** the answer cannot come from the file name
    (2.6) and must not come from the trait, which part 2 deletes. **Why this
    shape pays at part 2:** "does this contest count a domestic
    multiplier" can then be `UsesDomesticFile` OR the shape answers the 25
    already state, so the 94 state ONE fact, once -- not a second
    `HasDomesticMultiplier` beside this one.
  - **The readers.** `LOGSUBS2.LogContact`'s mobile call/QTH rewrite asks
    `ContestUsesDomesticFile` of the contest it now fetches ONCE per QSO, at
    the rewrite, and shares with the two grid-square rover tests (which
    fetched it themselves at 1a) -- no new fetch.
    `uContestReadiness.CollectContestSettingsGaps` takes
    `aUsesDomesticFile: boolean` (was the `DomesticMultType`); uProgramMain
    asks the active contest once at start-up (`uContestBase` joins its uses
    just ahead of `uContestFactory`; of its interface it names only that
    function). The ADIF import: `TADIFImportSession.DomesticMult` is
    `CountsGridSquares: boolean`, filled by `MainUnit.ParseADIFRecord` from
    the open contest's `HasGridSquareMultiplier` (one `ActiveContest` per
    record: the import holds no object), read by the base `ApplyADIFImport`,
    its one reader; `NeutralADIFImportSession` answers False.
  - **What still reads the domestic kind (part 2):**
    `ContestSession.DoingDomesticMults` (every `Doing` reader and
    GetDomQTH's exit), the matrix's `active.domesticmult` line, the kind pin
    and the cross-checks, FCONTEST's writes, the trait and the
    `DescribeSession` statements.
  - **Pins, written BEFORE the move and run green on the old code**
    (`uTestDomesticMultiplier`, three tests added): every ContestType at the
    11 entrants against the literal set of 85 that use the file everywhere
    plus the nine station rules, with literal per-station counts (92 us,
    92 ve, 94 DL, 92 host, 94 UA, 94 UA1, 92 JA, 93 OK, 92 ON, 93 UR, 93 YU;
    94 at some station); a cross-check of every ContestType x entrant
    against the frozen old test (`kind = DomesticFile` under the resolved
    session kind), which goes with part 2; and the invariant that a contest
    using the file states no shape (its key hands every text to the file,
    writing nothing, and none of the four flags is set). Old code: **242,562
    passed, 0 failed**. After the move: **242,562 passed, 0 failed**.
    `uTestContestReadiness`'s seven calls and `uTestContestImport`'s
    grid-square session were rewritten to the new parameters, asserting
    the same results.
  - **Matrix: MEASURED IDENTICAL, all 186 records byte-for-byte against `frozen/`** (a scratch run of the scratch `-B`
    build, not the freeze script).
  - **Narrowing 1263, range 3, unchanged** (scratch `-B`).
    `Lint-ContestNameTests` 6, unchanged.
  - **Inventory** (generated, then the tracked doc restored): rows **61**,
    shapes **6/0/12/43**, contests outside the factory **44**, unchanged;
    shape-4 sites 68 -> **67** (the mobile rewrite; readiness and the import
    read a parameter, which the scan does not count); records SHARED 38 ->
    **37**, PROXY 43, SHAPE 43, UNUSED 10.

- **PART 2 (THE DELETION) DONE 2026-10-14, on `a37c3100` (uncommitted at
  hand-back).** `DomesticMultType` is gone, and with it the last multiplier
  kind.
  - **Deleted.** The enum (VC; 9 members -- `NumericID` ran for no
    contest). The trait `DomesticMultiplierType` / `GetDomesticMultiplierType`
    on `TContestBase` and its 178 overrides (ARRL Digi's carried a finding --
    its row reads `NoDomesticMults {GridFields}` -- kept as a comment where
    the override stood). `TSessionDefaults.DomesticMult` / `svDomesticMult`.
    `ContestSession`'s field, `DomesticMult`, `DoingDomesticMults` and
    `WriteDomesticMult` (two kinds remain in the session: `Exchange`,
    `InitialExchange`). FCONTEST's two writes. The 13 `DescribeSession`
    statements (ARRL DX, the ALRS cup, the DARC 10 m, JIDX CW and SSB, OK
    DX, UBA CW and SSB x2 each, the Ukrainian DX, WAG, YU DX). The matrix's
    `active.domesticmult` line. Parts 1a and 1b's cross-checks and frozen
    rules (`LegacyDomesticKeyOfKind`, `LegacyHintOfKind`,
    `LegacyFlagOfKind`, the four `*AgreesWithItsSessionKind` tests); the
    literal rows, the per-station sets and counts and the invariants stay.
    `uTestContestSession`'s OK/OM DX domestic-kind test, and its other
    kind assertions. Code-only occurrences (HEAD -> now, src and tests,
    logddx excluded): `DomesticMultType` 391, `NoDomesticMults` 289,
    `GetDomesticMultiplierType` 180, `WYSIWYGDomestic` 45, `GridSquares`
    28, `GridFields` 24, `DOKCodes` 11, `svDomesticMult` 10, `RDADistrict`
    9, `IOTADomestic` 7 -> **0** each. `logddx.pas` is untouched (Q91).
  - **`DoingDomesticMults` IS THE CONTEST'S ANSWER -- F23 CLOSED.**
    `TContestBase.HasDomesticMultiplier` (nil-safe
    `ContestHasDomesticMultiplier`) is COMPOSED ONCE, IN THE BASE, from what
    each contest already states: `UsesDomesticFile` or
    `HasGridSquareMultiplier` or `HasGridFieldMultiplier` or
    `DomesticQTHReplacesDXMultiplier` (WYSIWYG) or `DomesticQTHIsNeverAGrid`
    (RDA). So the 94 file contests and the 22 with a flagged shape state
    nothing more. The three whose shape has no flag override it: the RSGB
    IOTA (True), WAG (`Station.MyCountry <> 'DL'`, the test its key and
    hint ask) and the DARC 10 m (True: DOKs outside Germany, WYSIWYG for a
    DL entrant). Read live against `Station`, so a mid-session MY CALL
    change is followed by the gate and the rules alike.
  - **Its readers.** With the object in hand, `ContestHasDomesticMultiplier`:
    `LOGDUPE.SetMultFlags` (`contestRules`), `LOGSUBS2.LogContact` (the
    object 1b fetched for the mobile rewrite), `EditableLog.GetMultArray`
    (the hint, per spot), POSTUNIT's Cabrillo writer (`stationContest`,
    once per log), `MainUnit.ParseADIFRecord` (one fetch per record for
    both `CountsGridSquares` and `DoingDomesticMults`), and
    `LOGDOM.GetDomQTH`, which now fetches ONCE at its head for the
    no-domestic exit and the rule. With no object in hand, the new
    `LOGEDIT.DoingDomesticMults` (one `ActiveContest`, as `DoingZoneMults`):
    `LogCfg`, `uTotal` x2, `uEditQSO`, `MainUnit.ExchangeWindowChange` and
    `BuildLogRow`'s QTH column, `LOGSUBS2`'s remaining-mults cycle and
    `ShowPartialCallMults`, LOGEDIT's station information and initial
    exchange, the matrix's `doing` line. `LOGEDIT.DoingAnyMults` fetches
    once for all four answers. `uContestSession` left the uses of
    `LogCfg`, `uTotal`, `uEditQSO`, `LOGSUBS2` and `LOGDOM`.
  - **Hot path, honestly.** Per QSO with the object held -- `SetMultFlags`,
    `LogContact`, the hint, the Cabrillo line, the import record: no new
    `ActiveContest`. `GetDomQTH`: a domestic contest makes the one fetch it
    made since part 1, moved up; **a contest with no domestic multiplier now
    makes one per domestic-QTH lookup where the session field cost
    nothing** -- its ~50 callers (the parse shapes) hold no object. The
    rescore reaches `GetDomQTH` only for a slash call under a QSO-party
    exchange. `BuildLogRow` asks once per row built (the QTH column), the
    exchange window once per keystroke. Not timed here.
  - **Evidence it is identical.** A script
    (`predict_domestic.py`, scratch) read every class's six answers out of
    its unit, inherited them along `class(TParent)`, applied the base's
    composition AS ITS SOURCE STATES IT, evaluated each station test from
    the variant's MY CALL, and predicted the domestic word of
    `doing.domestic/dx/prefix/zone` for all **580** frozen variants:
    **0 mismatches** (374 TRUE). With WAG's station test removed: **1**
    (WAG at DL). With ARRL DX's `UsesDomesticFile` station test removed:
    **4** (both runnings at us and ve). OK DX's and JIDX's station tests
    move nothing there -- the matrix runs no OK or JA station; their side
    is the unit pin's.
  - **Pins.** `uTestDomesticMultiplier` gains
    `Test_EveryContestHasItsPinnedDomesticMultiplier` (every ContestType at
    11 entrants against the literal set; per-station counts 117 us, 117 ve,
    118 DL -- the frozen matrix's -- 117 host, 119 UA, 119 UA1, 117 JA, 118
    OK, 117 ON, 118 UR, 118 YU) and
    `Test_ADomesticMultiplierIsWhereAQTHIsRead` (for every ContestType at
    every entrant, `HasDomesticMultiplier` is True exactly where the
    contest uses its file or decides at least one text itself -- so the
    composition and the three overrides cannot drift from the shape
    answers). `uTestContestKindPin` lost its domestic column (583 cells;
    removed, not regenerated): `varying` 5 -> **3** at us/ve/dx (WAG and
    DARC10M varied only in the domestic kind; counted from the frozen
    matrix), 5 in the host state unchanged; its switch test is S0d's literal
    pair through `LOGEDIT.DoingDomesticMults` with `Contest` switched.
    Unit tests: **181,504 passed, 0 failed** (242,562 at `a37c3100`; the
    drop is the cross-checks, the removed column and the session writer
    loop, less the two new tests).
  - **Matrix: re-freeze, one line per variant.** Every record loses exactly
    its `active.domesticmult = ...` line -- one per `### variant`, 580 in
    all -- and nothing else. Checked by running the whole matrix (186
    records) into scratch with the final build: 186 of 186 equal their
    frozen record minus those lines, byte for byte. Not frozen here.
  - **Narrowing 1263, range 3, unchanged** (scratch `-B`). `tr4wserver`
    builds (VC touched). `Lint-ContestNameTests` 6, unchanged. Inventory
    (generated, then the tracked doc restored): rows **61**, shapes
    **6/0/12/43**, contests outside the factory **44** -- unchanged;
    shape-4 sites 67 -> **66**; records SHARED 37 -> **36**, PROXY 43,
    SHAPE 43, UNUSED 10; `DescribeSession` kind statements 35 -> **22**.
    The inventory's `DM` maps (`scan.ACTIVE`, `scan.SESSION`,
    `model.FIELD_GETTERS`, `kind-reach.ENUMS`) are gone.

### WHAT S7, S8 AND S9 INHERIT (written at S6's close, 2026-10-14)

All four multiplier kinds are gone (S3-S6). What is left of the session's
kinds is the EXCHANGE: `ExchangeType` (61 members) and
`InitialExchangeType` (15), each still a trait (`GetExchangeKind` 186
overrides, `GetInitialExchangeKind` 177) plus `DescribeSession` statements
(22 left, all exchange or initial exchange), resolved into
`ContestSession.Exchange` / `.InitialExchange`. Code reads, measured:
`ContestSession.Exchange` 50 in 10 files; `ContestSession.InitialExchange`
2 (LOGEDIT, one of them `... or (Contest = IARU)`) plus the matrix. The
inventory's 66 shape-4 sites (61 comparisons, 5 `case`s) are all exchange
kinds now.

- **S7 (exchange RULES out of the compare sites)** inherits unchanged in
  scope: the compare sites that test an `ExchangeType` to decide a RULE
  (blank exchange, park display, CQ WW RTTY's sent zone and state, FISTS's
  `CombineScore`, the rover and multi-QTH tests -- 25 and 21, F4 open for
  NY4I) become stated class answers for today's sets exactly. It no longer
  shares a site with a multiplier kind: every such test left with S3-S6.
  `MainUnit`'s rover/county paths are UI-only -- unit pins plus a bench
  item.
- **S8 (the initial exchange) still waits on Q50.** It inherits
  `InitialExchangeType`'s two LOGEDIT reads (`InitialExchangeEntry`'s
  `case`, and the zone test that names IARU), the Russian-oblast fallback
  `Contest in [RUSSIANDX, RDA, RU3AXMEMORIAL]` (F3: one of Q50's three
  spellings is already dead) and `Lint-ContestNameTests`' `logedit`
  ceiling (4 -> 0, `$TOTAL_FLOOR` lowered with it -- F14). The zone source
  for an initial exchange is already the class's
  (`InitialZoneFromCallHistory`, `ZoneMultiplierZones`, S5).
- **S9, RE-PLANNED BY Q92 (option 2, NY4I 2026-10-14):** NOT one
  `ExchangeShape` answer that the engine dispatches on, but the four
  exchange-shape machines -- `LOGSTUFF.ParseExchangeShape` (the parser),
  `LOGDUPE.SetUpExchangeInformation` (the field list),
  `uADIFExchange.FormatADIFExchangeOfKind` and
  `uCabrilloExchange.FormatCabrilloExchangeOfKind` -- become PLAIN NAMED
  HELPERS, one per shape, and each class's own overrides
  (`ParseReceivedExchange`, the field list, `GetADIFSentExchange` /
  `FormatCabrilloSentExchange` and their received halves) CALL the helper
  for its format explicitly -- once on a family base where a family shares
  one. No enum selects a helper (design 1.3). Then `ExchangeType`, the
  `GetExchangeKind` trait and `ContestSession.Exchange` can go the way the
  multiplier kinds went (a part 2), with `ActiveExchangeArray` (F13) and
  `TREE.LooksLikeAGrid`'s per-row read (S9f) re-answered by the class.
  S10 is moot. Expect it to be the largest stage: 61 shapes x 4 machines,
  and 186 classes to point at their helpers -- plan it as a move per
  machine (field list, ADIF, Cabrillo, parser), each pinned by the matrix's
  export, import and `parse` sections, then the deletion.

### S7 -- Exchange RULES out of the compare sites (2.1)

- Covered here: blank exchange, park display, CQ WW RTTY's sent zone and
  state, FISTS's `CombineScore`.
- **The rover and multi-QTH tests become one stated class answer each, for
  today's sets exactly (25 and 21).** The three-way disagreement with
  `SplitsRoverCallOnExport` (15) and the county line is F4, for NY4I. This
  stage must not change which contests strip.
- *Pins:* the matrix covers only the CQ WW RTTY messages and FISTS totals. The
  `MainUnit` paths are UI, so the class answers get unit pins and the bench
  gets one item (`docs/BENCH_QUEUE.md`).
- *Risk:* medium. *Specialists:* `lcl-ui`, `contest-scoring`.
- **DONE 2026-10-14, on `17902292` (uncommitted at hand-back), in one
  change, except the SS columns (F15).**
  - **The reads, classified.** `ContestSession.Exchange`, code only, logddx
    excluded: **51 reads in 10 files** (the "50" above counted MainUnit's
    two-on-one-line compare once). RULE, moved: **15** -- the rover 6 (and
    the rover routine's log line), several QTHs 2 and `ProcessReturn`'s 1,
    the park 1, a blank exchange 2 (MainUnit, LOGSTUFF), CQ WW RTTY 1
    (FCONTEST), and `uScoreTotals`' copy into
    `TScoreTotals.SessionExchange`, whose one reader was `CombineScore`'s
    FISTS test. RULE, BLOCKED: **2** -- `SetColumnsWidth`'s SS columns (F15
    waits for S1, which waits for Q50). SHAPE, left for S9: **24** --
    `PerQSOExchString`'s `case`, FCONTEST's sent-message `case`, LOGDUPE's
    FISTS field placement and history renders (6), LOGEDIT's history branch
    (15), `TREE.LooksLikeAGrid`. DATA handed on, left for S9: **10** -- the
    matrix line, the ADIF import session, POSTUNIT's three exporter
    hand-offs, LOGSTUFF's two `ExchangeModeAttribution`s and the parse
    session, uProgramMain's field list and readiness check. Rule or shape
    was judged by the plan's 2.1 table and by reading each site: a RULE is
    a sponsor's decision that happened to be keyed on how the exchange is
    spelled; a SHAPE reads the format itself. After: **36 reads** (MainUnit
    16 -> 4, LOGSTUFF 4 -> 3, FCONTEST 2 -> 1, uScoreTotals 1 -> 0).
    `kind-reach.py`'s compare records 44 -> **28**. Inside the factory,
    `CombineScore`'s test went; the Cabrillo context's `SessionExchange`,
    `ApplyADIFImport`'s grid shapes and POTA's are shapes (S9).
  - **The API** (`TContestBase`, base False, public; nil-safe
    `ContestStripsRoverCountyFromCall`, `ContestLogsSeveralQTHsFromOneEntry`,
    `ContestAcceptsBlankExchange`): `StripsRoverCountyFromCall`,
    `LogsSeveralQTHsFromOneEntry`, `AcceptsBlankExchange`,
    `SendsStateAfterZone`. The park lookup asks the existing
    `OffersParkTools` (True for POTA alone, pinned), of the contest's
    identity as the Tools menu does -- no station enters it. FISTS overrides
    `CombineWithMultipliers` (points alone; F12 closed), and
    `TScoreTotals.SessionExchange` is DELETED with its reader.
  - **Per contest, stated per class** (28 units). No family base: five
    parties on the state-party base (CA, CO, MN, OH, PA) never stripped, so
    the rover rule is not the family's (F4).
    - Rover AND several QTHs at every station (12): County Hunter (RSTQTH),
      Michigan, Missouri, North Carolina, TOEC, Wisconsin, New York,
      Tennessee, the ALRS cup, Indiana, BC, IN7QPNE (RSTDomesticQTH).
    - Rover at every station, never several (4): Florida, LABRE, Idaho,
      Delaware (RSTDomesticOrDXQTH).
    - Rover at every station, several only where DescribeSession states
      RSTDomesticQTH (6): the 7QP, the Salmon Run, Texas (`not
      CountsDXMultiplier`, out of the host state), Arizona (`not
      Station.InHostState`), NEQP (`not CountsDXMultiplier`, outside New
      England), ARRL 160 (`not CountsDXMultiplier`, outside an ARRL section
      country).
    - Both only where the entrant decides (3): the ARRL DX CW and SSB, on
      their base (`not CountsDXMultiplier`, not W or VE), the PACC (`not
      HasDXMultiplier`, not Dutch).
    - A blank exchange: BWQP, the General QSO, POTA. The state after the
      zone: CQ WW RTTY.
  - **The rover rules are unchanged -- evidence.** Both of today's sets,
    transcribed exactly (Q94 and Q90 open): 25 contests strip at some
    station, 21 take several QTHs, and the export's
    `SplitsRoverCallOnExport` (15) is untouched. Pinned literally for every
    ContestType at six entrants -- us, ve, dx (DL), a host-state MA station,
    a Dutch station (PA) and a KH6 station (an ARRL section country that is
    neither W nor VE, where ARRL 160 and the ARRL DX part company) -- with
    per-station counts (rover 23, 23, 25, 23, 24, 25; several 18, 18, 21,
    13, 20, 20) and the 25 and 21 at some station; RUN GREEN ON THE OLD
    CODE, where the program's answer was the old compare on the session
    shape `Kinds` resolves. A cross-check of every ContestType x entrant x
    rule against that frozen compare (`LegacyAnswer`) STAYS until S9 deletes
    the shape. The matrix's stations agree (a scratch script over `frozen/`:
    25 rover, 21 several, 3 blank). Inside the rover routines the order
    changed only between pure tests: the slash first, then the contest.
  - **One site deleted, not moved.** `ProcessReturn`'s split of the
    exchange into the `s1..s4` globals (for RSTDomesticQTH) had no
    observable effect: the four are read in one place, `ReturnInSAPOpMode`,
    which splits into them itself, unconditionally, first; no other unit
    reads them (a code-only search of every unit naming MainUnit).
  - **Per-QSO sites pass the object they hold:** the rescore
    (`RecomputeQSOScoring`'s `contestRules`) and the ADIF record parse
    (`ParseADIFRecord`'s `importContest`) call
    `LocateCallStrippingRoverCounty(aContest, ...)`; `ProcessExchange`
    fetches `ExchangeContest` ONCE for the blank gate and the parse (after
    `ParseArray`, as before); FoundContest asks `definition`. Live entry,
    the import loop and the matrix keep `ctyLocateCallStripRover`, which
    fetches `ActiveContest` only for a call with a '/'. ParametersOkay's
    blank test fetches only for a blank exchange, `ReturnInSAPOpMode` once
    per S&P Enter that reaches the test, and the park lookup asks the
    identity per keystroke. Not timed here.
  - **Pins:** `uTestExchangeRules` (new). Old code: **192,772 passed, 0
    failed** (181,504 and 11,268 more, which is 60 x 187 ContestTypes + 48
    -- every new check ran). After the move: **192,772 passed, 0 failed**.
    `uTestContestTotals`' FISTS case now asks FISTS (it handed CQ WW CW a
    FISTS session shape, a pairing the program never runs);
    `uTestContestDelawareQP`'s totals lost the deleted field.
  - **Matrix: MEASURED IDENTICAL, 186 of 186 byte-for-byte against
    `frozen/`** (a scratch run of the scratch `-B` build, not the freeze
    script). It covers CQ WW RTTY's messages and the FISTS totals; the rest
    is UI -- one bench item (`BENCH_QUEUE.md`).
  - **Narrowing 1263, range 3, unchanged** (scratch `-B`; the incremental
    build crashed FPC, as at S3-S6). `Lint-ContestNameTests` 6, unchanged.
    VC untouched, so `tr4wserver` was not rebuilt.
  - **Inventory** (generated, then the tracked doc restored): rows 61 ->
    **54**; shapes 6/0/12/43 -> **6/0/12/36**; shape-4 sites 66 -> **53**
    (48 comparisons, 5 `case`s); records PROXY 43 -> **36** (reach 1: 12 ->
    7), SHARED 36 -> **30**, SHAPE 43, UNUSED 10; contests with rules
    outside the factory 44 -> **41** (County Hunter, BWQP and the General
    QSO leave). The `judgements.ROUTINES` rows for ProcessExchange,
    ParametersOkay, ExchangeWindowChange, the two rover routines,
    ReturnInSAPOpMode and SetUpRSTMyZoneExchange, which no site matches
    now, are comments saying where the rules went.
  - **Not done -- the SS columns (F15).** `SetColumnsWidth` still tests
    `= QSONumberPrecedenceCheckDomesticQTHExchange`; it equals
    `ExchangeInformation.Precedence`/`.Check` only once S1 deletes
    `CheckAndChapterOrQTHExchange`, and S1 waits on Q50.

#### S7 follow-up DONE (2026-10-14): Q94 with Q90 -- the rover is a QSO party's

NY4I: *"yes QSO parties allow it but in any contest NY4I/7 or VP9/NY4I is a
valid call."* A `/suffix` is a county rover only in a QSO party, and there it
is BOTH stripped live and split on ADIF export. F4 is closed: the two sets
now agree, but for County Hunter.

- **Where it lives.** `SplitsRoverCallOnExport` moved from
  `TContestStateQSOPartyBase` (a getter and property) to a `TContestBase`
  virtual (base False) so a multi-state party can state it;
  `uContestRegistry.ContestSplitsRoverCallOnExport` asks
  `ContestIdentity(c)` directly. `TContestStateQSOPartyBase` answers True to
  BOTH, once; the 15 per-party split overrides and 14 per-party strip
  overrides are deleted. 7QP, NEQP and IN7QPNE (on `TContestBase`) state
  both on their classes. County Hunter keeps its strip and does not split (a
  recorded decision, not the ruling). The ARRL DX (both, on their base), ARRL
  160, PACC, LABRE, TOEC and the ALRS UA1DZ Cup lost their strip overrides.
  `LogsSeveralQTHsFromOneEntry` is a separate rule and is untouched.
- **Strip, 25 -> 24, at every station.** Gained: California, Colorado,
  Minnesota, Ohio, Pennsylvania, **Virginia** (in neither old set, so Q94's
  list did not name it; it is a state party). Lost: ARRL DX CW and SSB (were
  station-dependent), ARRL 160, PACC (station-dependent), LABRE, TOEC, ALRS.
- **Split, 15 -> 23.** Gained: Arizona, British Columbia, Virginia, the
  Salmon Run, New York, **7QP, NEQP, IN7QPNE** (QSO parties under the same
  ruling; the export only splits when the suffix equals the QSO's own QTH,
  so it is contest-agnostic). IN7QPNE's county-line import bypass stays
  False (#894) -- a rover is not a county line.
- **Pins.** `uTestExchangeRules`: the rover set is the ruling's 24 at every
  station (counts 24 x 6, 24 anywhere); its cross-check against the session
  shape now skips the rover rule, which disagrees with the shape on purpose
  for 13 contests. `uTestContestFactory`:
  `Test_FifteenPartiesSplitARoverCallOnExport` is
  `Test_EveryQSOPartySplitsARoverCallOnExport` (23, every state-party object,
  and strip = split for every contest but County Hunter); the old row's
  fifteen survive as `OLD_ROW_COUNTY_LINE_ALLOWED` for the county-line test.
  `uTestADIFFixtures`: IN7QPNE now splits. Old code **192,772 passed**; new
  code **191,859 passed, 0 failed** (-1,122 rover cross-checks, +209 split
  pins).
- **Narrowing 1263, range 3, unchanged** (a scratch `-B` build).
- **What the oracles should see** (not run here): the matrix's export never
  writes a `/county` call, so the split is invisible to it; its `imp rover`
  line (`KG1S/MON`) changes `cty=` where the strip changes AND the session's
  table knows `MON` -- ALRS and ARRL 160 stop stripping (K -> G), Virginia
  and Colorado start (`va_cty.dom`, `colorado_cty.dom` hold `MON`). No corpus
  set is a changed contest except the ARRL DX CW, whose W entrant never
  stripped.

### S8 -- Initial exchange moves into the classes (46 contests) -- the least pinned

- `InitialExchangeFromCall` becomes the live seam. The 46 contests call
  helpers: zone of call (CD then CTY), name, name and QTH, check and section,
  grid with heading, and custom (`Settings.Contest.CustomInitialExchangeString`
  through the station context).
- OZCR, RF Champ, IARU and the Russian trio move into their classes. Q50
  decides which Russian rule survives.
- *Lint:* `Lint-ContestNameTests`'s `logedit` ceiling goes 4 -> 0, and
  `$TOTAL_FLOOR` (5) is lowered in the same commit (F14).
- *Pins:* S0d's matrix section if it was feasible; otherwise unit pins over the
  helpers with a stub CD/CTY, and a bench item.
- *Risk:* **high.** UI-only, and no oracle at all today.
- *Specialists:* `contest-scoring`, `lcl-ui`.

### S9 -- The exchange shape becomes one class answer

**RE-PLANNED BY Q92 (option 2) -- see "WHAT S7, S8 AND S9 INHERIT".** The
first bullet below is the superseded single-answer design: the four
machines become named helpers the classes call, one machine per stage
(S9a the field list, then ADIF, Cabrillo and the parser), then a deletion
stage for `ExchangeType`, `GetExchangeKind` and `ContestSession.Exchange`.

- ~~`ExchangeShape(aStation)` replaces `GetExchangeKind` (373) and
  `TSessionDefaults.Exchange`. FCONTEST caches it in `ContestSession.Exchange`.~~
- `ActiveExchangeArray`: keep it, or replace its two log lines with RTTI
  `GetEnumName`. If deleted, check `Lint-SpellingTables`' floor of 24.
- *Matrix:* identical. *Risk:* low-medium.
- *Specialists:* `contest-scoring`, `build-release`.

#### S9a DONE (2026-10-14, on `6edaffc3`, committed `68076954`): THE FIELD LIST

The first machine: `LOGDUPE.SetUpExchangeInformation`, the `case` over the
session's exchange shape that marked `ExchangeInformationRecord`'s fields.

- **Measured first.**
  - **Its arms: 43**, carrying **55** labels of `ExchangeType`'s 61
    members. Six members had no arm and marked nothing: `UnknownExchange`,
    `NoExchangeReceived`, `RSTAndDOMESTICQTH`,
    `RSTAndSerialNumberAndGridandPossibleMemberNumber`,
    `RSTNameAndPossibleFOCNumber`, `RSTAndGridSquareOrRDAExchange`.
  - **Reach** (the frozen matrix's `active.exchange` lines, 186 contests x 3
    stations, which hold every value the 20 `DescribeSession` statements
    write): registered contests run **51 shapes**. **50** hit an arm --
    **39 live arms, 27 distinct field sets** -- and the 51st,
    `RSTAndGridSquareOrRDAExchange` (the UA4W Championship), hit none and
    marked nothing: **28 sets with the empty one**. Each shape's set was
    the same at every matrix station (checked: no shape printed two
    `exchange.fields`).
  - **Unreachable: 4 arms** (5 labels): `CheckAndChapterOrQTHExchange`
    (Chapter Check QTH -- the only set no live arm marks; S1/Q50),
    `QSONumberAndAgeExchange` (Age QSONumber), `RSTAndGrid3Exchange` (QTH
    alone), `RSTAndFOCNumberExchange` (RST Power); and the label
    `RSTQSONumberOrDomesticQTHExchange` inside a live arm. They are gone
    with the machine -- no helper was written for a set only they marked --
    and the members stay for the deletion stage. Recorded literally in the
    pin's frozen copy (`uTestExchangeFields.LegacyFields`).
  - **Station-dependent:** 12 contests choose their exchange by the
    station (11 classes, 20 `DescribeSession` statements). For **10** the
    field set moves with it -- ARRL DX CW/SSB, ARRL 160, JIDX CW/SSB, 7QP,
    NEQP, Arizona, Texas, the Salmon Run; California's and the PACC's two
    shapes carry one set each.
  - **Callers: ONE** -- `uProgramMain`, once at start-up, on
    `ContestSession.Exchange` (F19: a run-time CONTEST switch does not
    re-run it). Readers of the record it filled (unchanged):
    `LOGDUPE.ParseExchangeIntoContestExchange` (via `LOGSUBS2`'s log-string
    read), `LOGSTUFF.LogStringToRXData`, `LOGSUBS2`'s age message, POSTUNIT's
    ADIF RST and zone tags, `uExternalLogger`, the matrix.
- **The seam.** `TContestBase.GetReceivedExchangeFields:
  ExchangeInformationRecord` (protected virtual) behind the public property
  `ReceivedExchangeFields`, beside `GetExchangeKind`/`ExchangeKind` -- a
  getter, because a field list is what the contest IS at its station; and
  the nil-safe `ContestReceivedExchangeFields(aContest)`. A function
  returning the existing record rather than a `var` procedure: the record
  is replaced whole, so no field can survive from a previous answer. **The
  base marks nothing** (what the machine gave the classless DUMMYCONTEST) and
  dispatches on no enum.
- **The helpers: `uExchangeFields` (new leaf, VC only), 28 -- one per FIELD
  SET, not per shape.** The machine's arms already grouped shapes by set; a
  helper per shape would have been the same body up to ten times. Named for
  the fields they mark (`ExchangeFieldsRSTZone`,
  `ExchangeFieldsRSTQSONumberQTH`, ...), plus `ExchangeFieldsNone` and
  `ExchangeFieldsText` (the matrix's printer, lifted so the matrix and the
  pin spell a set one way).
- **The overrides: 184**, every registered contest stating its list.
  - 175 classes call one helper beside their `GetExchangeKind`,
    including the NRAU Baltic family base (two contests).
  - The ARRL DX family base (two contests) and eight classes test the
    station as their other answers do: ARRL DX `CountsDXMultiplier`; ARRL
    160, 7QP, NEQP, Texas, the Salmon Run `CountsDXMultiplier`; Arizona
    `Station.InHostState`; JIDX CW/SSB `IsJapaneseEntrant`.
  - California and the PACC state one helper, with a comment that both
    station shapes share it. The UA4W Championship states
    `ExchangeFieldsNone`, transcribed (F24).
- **The repoint.** `uProgramMain`: `ExchangeInformation :=
  ContestReceivedExchangeFields(ActiveContest(Contest))`, once, where the
  call stood. `SetUpExchangeInformation` is DELETED. The matrix prints
  `ExchangeFieldsText(ExchangeInformation)`; its own copy of the printer is
  deleted.
- **Pin: `uTestExchangeFields` (new).** Every ContestType at seven
  stations -- the matrix's three, a host-state MA station, a Dutch, a KH6
  and a **Japanese** station (no matrix station reaches JIDX's JA branch)
  -- against literals laid out from the frozen matrix's us column grouped
  by set, plus the station branches by hand; a count of distinct sets
  (28); a cross-check against a frozen copy of the machine on the session
  shape `uTestContestKindPin.Kinds` resolves (stays until the deletion
  stage); every helper's set literally. **OLD code (the program's answer
  = the machine on `Kinds`): 2,649 passed, 0 failed. NEW code: 2,649
  passed, 0 failed.** Suite **194,586 passed, 0 failed**, both runs. The
  identical private `MakeContest` in four pin units (and the fifth this
  would have been) is lifted to `uTestContestObjects.MakeContestOrNil`.
- **Build:** narrowing **1262** (ceiling 1262), range **3**, full `-B`.
  Matrix, corpus and lints NOT run here. **The matrix should be IDENTICAL:**
  its `exchange.fields` line is the same record, printed by the same text
  in the same order.
- **Inventory** (generated to check the tool, then the tracked doc
  restored): rows 29, contests 30 -- unchanged; shape-4 sites 28 -> **27**
  (`case`s 4 -> 3); records 87 -> **44** (SHAPE 43 -> **0**; PROXY 12,
  SHARED 22, UNUSED 10 unchanged). `scan.KIND_PARAMETERS` is empty,
  `judgements.SHAPE_MACHINES` lost the routine, and `generate.py`'s guard
  that the scan still reached it is deleted -- it would fail every run.
- **Not done here, on purpose.** The readers of `ExchangeInformation` still
  read the global start-up fills (F19); asking the contest at each reader
  is a later question. `GetExchangeKind` is still the trait every other
  machine reads.

#### S9b DONE (2026-10-14, on `e7007b63`, uncommitted at hand-back): THE ADIF EXPORT MACHINE

The third machine: `uADIFExchange.FormatADIFExchangeOfKind`, the `case` over
the session's exchange shape that built the MY-exchange (`STX_STRING`) of an
ADIF record -- plus the two other ADIF paths that read a kind.

- **Measured first.**
  - **Its arms: 31 shape arms and the "not yet implemented" arm (19 labels),
    32 in all, carrying 57 labels of `ExchangeType`'s 61 members, and an
    `else`.** Four members fell to the `else`: `UnknownExchange`,
    `NoExchangeReceived`, `ClassDomesticOrDXQTHExchange` and
    `QSONumberPrecedenceCheckDomesticQTHExchange` (the last two are the Field
    Days' and Sweepstakes', whose classes format their own).
  - **Reach.** 13 classes (4 family bases and 9 leaves) already overrode the
    seam and 8 leaves inherit one of the bases'; **168 classes reached the
    machine through `TContestBase`**, and between them run **49 distinct
    shapes** (the frozen matrix's `active.exchange` lines, plus the stations'
    `DescribeSession` values). **30 of the 32 arms are reached; 49 of the 57
    labels.** Unreached: the n4af `RSTQSONumberOrDomesticQTH` arm and
    `QSONumberAndAge`, and six labels of the not-implemented arm
    (`CheckAndChapterOrQTH`, `RSTAndGrid3`, `RSTAndDOMESTICQTH`,
    `RSTAndFOCNumber`, `RSTAndSerialNumberAndGridandPossibleMemberNumber`,
    `RSTNameAndPossibleFOCNumber`). The `else` is reached only by the
    classless DUMMYCONTEST. They go with the machine; their enum members stay
    for the deletion stage.
  - **By output.** The 26 working arms print **22 distinct layouts** (the
    RST and the state, `'%-3d %-7s'`, serves five arms). **13 shapes land in
    the not-implemented arm** (answer `None`, an Error logged each QSO; 14
    contests), and **three arms print the marker** (plan F25): five
    contests, plus DUMMYCONTEST.
  - **Station-dependent:** the session's exchange moves with the station
    for 12 contests (S9a), but **only the JIDX pair's STX_STRING moves with
    it** (a Japanese entrant receives a zone, anyone else a prefecture:
    `'%-3d %-7.2d'` versus `'%-3d %-7d'`). ARRL 160, 7QP, NEQP, Arizona,
    Texas, the Salmon Run, California and the PACC choose between two shapes
    that print the same text; ARRL DX has its own override.
  - **Callers: ONE** -- `TContestBase.FormatADIFSentExchange`, itself called
    once per record from `PostUnit.MyExchangeForExport`. **Overrides before
    the stage: 13** (the CQ WW, CQ WPX, ARRL SS and ARRL DX family bases;
    ARRL FD, Winter FD, FOC Marathon, Florida QP, General QSO, IARU, NA
    Sprint CW, PACC, PCC) -- none used the kind it was handed, and none
    called `inherited`.
  - **Other ADIF code that dispatched on a kind (2):**
    - **EXPORT:** `TContestPOTA.EmitADIFExchangeFields` asked
      `aSessionExchange in GRID_CARRYING_EXCHANGES` before writing a
      hunter's GRIDSQUARE. POTA's session exchange is `RSTAndPOTAPark`,
      which is in that set, and nothing else can set it: **the test was
      always true.** Deleted with the parameter.
    - **IMPORT:** the base's `ApplyADIFImport` read
      `aSession.Exchange in [RSTAndOrGrid, Grid2, RSTAndGrid3, Grid]`
      through `TADIFImportSession.Exchange` -- the OPEN contest's exchange
      (an operator can import another contest's log into the open one; that
      quirk is reproduced, not corrected). Replaced by the open contest's
      class answer, `TContestBase.ReceivesGridSquareExchange` (true for
      the nine contests whose trait is one of those shapes: the three ARRL
      VHF contests, CQ VHF, Stew Perry, ARRL Digi, WW Digi, Batavia FT8,
      Makrothen -- `RSTAndGrid3` is unreached). It is not
      `HasGridSquareMultiplier`: the five non-VHF contests carry a grid and
      count no grid multiplier. No ADIF import override read the kind.
- **The seam.** `TContestBase.GetADIFSentExchange(aMy, aQso)` (protected
  virtual) behind the public, **non-virtual** `FormatADIFSentExchange(aMy,
  aQso)` -- the same getter-behind-a-caller shape as S9a. **The kind
  parameter is gone from the seam**, from `EmitADIFExchangeFields`, and
  from `TADIFImportSession`. **The base answers `ADIFSentNotBuilt`** (the
  error marker): what the machine's `else` gave the classless DUMMYCONTEST,
  and the answer for a new contest that forgets it. Non-virtual wrapper,
  protected virtual: 168 classes could state it in the protected section
  beside `GetReceivedExchangeFields` without lowering a public method's
  visibility (FPC notes that).
- **The helpers: `uADIFExchange`, 24 -- one per distinct OUTPUT**, named for
  what they print (`ADIFSentRSTState`, `ADIFSentRSTQSONumber`, ...), same
  signature `(aMy, aQso)`. Two are not layouts: `ADIFSentNotImplemented`
  (`None`, logged) and `ADIFSentNotBuilt` (the marker). Each reads the
  station's fields through the machine's own width -- a `ShortString` of 20
  for the state, name and zone, 7 for the grid, 10 for the park -- so an
  over-long value is cut as it was (the pin feeds a 26-character state).
- **The overrides: 181** -- **168 new** (`GetADIFSentExchange`, beside
  `GetExchangeKind`/`GetReceivedExchangeFields`; 9 of them also
  `GetReceivesGridSquareExchange`) and **the 13 that already existed,
  renamed from `FormatADIFSentExchange` to `GetADIFSentExchange` with the
  unused parameter dropped**. The JIDX pair test `IsJapaneseEntrant`; the
  other 166 call one helper.
  - **Not repointed, on purpose:** seven of the 13 own overrides print what
    a helper prints (CQ WW, CQ WPX, Florida, ARRL DX, General QSO, IARU, NA
    Sprint CW) -- but none clips to the machine's widths, so calling the
    helper would change a 21-character state's output. They keep their own
    bodies; folding them is a one-line change per class once a sponsor's
    question (or NY4I) says a clipped value is fine.
- **The repoint.** `PostUnit.MyExchangeForExport` and the tail emitter drop
  `ContestSession.Exchange` from both calls; `MainUnit.ParseADIFRecord`
  sets `session.ReceivesGridSquare` from `ContestReceivesGridSquareExchange(
  ActiveContest(Contest))`. `FormatADIFExchangeOfKind` is DELETED, and
  `uADIFExchange` no longer uses `uCabrilloExchange` (it was the alias for
  `TMyStationExchange`; the type is `uContestBase`'s).
- **Unreachable branches deleted with the machine** (none changes an output
  any registered contest produces): the three arms above; the RoPoCo's
  postal-code branch (`contacts = 1`, a variable nothing assigned -- the
  helper prints the empty previous code the machine always printed); the
  `cMyState := 'DX'` write in the `RSTDomesticQTH` arm that nothing read.
  `ActiveExchangeArray` has no reader left (F13); it stays until the deletion
  stage because `Lint-SpellingTables`' floor is 24.
- **Pin: `uTestADIFSentExchange` (new).** Every ContestType at the seven
  roster stations (`uTestExchangeFields.TPinStation`, now exported) with
  **four inputs** -- a full exchange; an empty one; over-long values; a
  state of `TRC` -- against **literals made by running the OLD machine**
  (`TContestBase.FormatADIFSentExchange(my, qso, Kinds(c, station).Exchange)`,
  dumped to a file and laid out grouped by output: 32 groups plus the JIDX
  pair), a literal check of every helper, and the base's marker.
  `uTestADIFExchange` (the old arm-by-arm unit) now pins the helpers.
  **OLD code (a worktree of `e7007b63`, the pin with `ProgramSent` calling
  the three-argument seam and the two helper tests cut): 199,823 passed, 0
  failed -- 194,586 baseline + 5,236 STX_STRINGs + 1 count. NEW code: the
  same 5,236 + 1 unchanged, plus the helper test (96) and the base (4): 199,921
  passed, 0 failed.** The baseline's other deltas: `uTestADIFExchange` 12
  -> 11 (Grid and Grid2 are one helper), `uTestContestPOTA` -1 (the
  session-carries-no-grid case is unreachable and deleted).
- **Build:** narrowing **1262** (ceiling 1262), range **3**, full `-B`. The
  first build was 1263: `StrToIntDef(string(Str20(...)))` binds the
  AnsiString overload and warns -- written `AnsiString(Str20(...))`, as CQ
  WW's own override has it. Matrix, corpus and lints NOT run here.
  **The matrix should be IDENTICAL** (it shows no STX_STRING); **the corpus
  byte-diffs 13 contests' STX_STRING and the ADIF round-trip imports them
  back -- both should be IDENTICAL**; `Lint-ContestNameTests`' ceiling for
  `uADIFExchange` stays 0.
- **Inventory** (generated to check the tool, then the tracked doc
  restored): rows 29, contests 30 -- unchanged; shape-4 PROXY 12, SHARED
  22, SHAPE 0, UNUSED 10 unchanged. `judgements.SHAPE_MACHINES` lost the
  routine (two left: `ParseExchangeShape` and Cabrillo's `SetHisEx`), the
  `ROUTINES` row for `FormatADIFExchangeOfKind` is gone, the one remaining
  contest test in the file (TRC Digital, now in `ADIFSentRSTQSONumberState`)
  has its own `ROUTINES` row and an updated `SHAPE3` pattern. The tracked
  document needs a regeneration after the commit: the `uADIFExchange` row
  and the `postunit` line numbers move by one.
- **Not done here, on purpose.** The Cabrillo machine
  (`FormatCabrilloExchangeOfKind`, S9c) and the parser (S9d) still read the
  session's exchange; `TCabrilloQSOContext.SessionExchange` stays.

#### S9c DONE (2026-10-14, on `c54e0143`, uncommitted at hand-back): THE CABRILLO EXPORT MACHINE

The fourth machine: `uCabrilloExchange.FormatCabrilloExchangeOfKind`, the
`case` over the session's exchange shape that built the sent and received
exchange columns of a `QSO:` line.

- **Measured first.**
  - **Its arms: 31 shape arms and an `else`, carrying 38 labels** of
    `ExchangeType`'s 61 members. The `else` (the loud marker, Issue #1043)
    took the other 23.
  - **Reach** (the frozen matrix's `active.exchange` lines plus the
    stations' `DescribeSession` values, confirmed by running the OLD machine
    for every ContestType at seven stations): registered contests run **52
    shapes**. **35 of the 38 labels are reached; 3 arms are not**:
    `RSTAndGrid3Exchange`, `QSONumberAndAgeExchange` and the n4af
    `RSTQSONumberOrDomesticQTHExchange` arm. They went with the machine; the
    enum members stay for the deletion stage. **17 reached shapes have no
    arm** and land in the marker: `ClassDomesticOrDXQTH` and
    `QSONumberPrecedenceCheckDomesticQTH` (the Field Days' and Sweepstakes',
    whose classes format their own), `UnknownExchange` (the classless
    DUMMYCONTEST) and **14 more shapes that 15 registered contests run** (F26).
  - **By output.** The 28 working arms print **25 distinct sent layouts and
    27 distinct received layouts** (the RST and the state, `'%-3s %-7s'`,
    serves five arms on the sent side; the same RST-and-QTH layout serves two
    on the received side) -- the sent and received halves of an arm are
    independent, and the same received layout is paired with up to three
    different sent ones. The helper set adds the Ukraine Championship's and
    the Ural Cup's swapped-order pair (two copies of one body until now) and
    the marker: 27 sent + 29 received. 43 groups of contests share one pair of
    columns at every station.
  - **Station-dependent: 9 contests.** ARRL 160, the 7QP, Arizona, NEQP,
    Texas, the Salmon Run (a station in the host state / an ARRL-section
    country writes `RSTDomesticOrDXQTH`'s columns, anyone else
    `RSTDomesticQTH`'s -- the 'DX' fill in the sent state and the received
    QTH), JIDX CW and SSB (a Japanese entrant `RSTZone`'s, anyone else
    `RSTPrefecture`'s) and the PACC (a Dutch entrant `RSTAndQSONumberOr
    DomesticQTH`'s received column, anyone else `RSTDomesticQTH`'s). California
    and ARRL DX choose between shapes that print alike.
  - **Callers: ONE** -- `PostUnit.tGenerateLogPortionOfCabrilloFile`, once
    per QSO line, asking `exportContest.FormatCabrillo{Sent,Received}Exchange`.
    **Overrides before the stage: 20 classes** (4 family bases: ARRL DX, ARRL
    SS, CQ WW, CQ WPX; 16 leaves) -- **none used the kind it was handed**, and
    four (California, the RSGB IOTA, UK/EI, WW Digi) adjusted an input and
    called `inherited`, i.e. the machine. 33 method bodies in all.
  - **Other Cabrillo code that dispatched on a kind: none.** PostUnit's
    `qsoContext.SessionExchange := ContestSession.Exchange` was the one
    writer, the machine the one reader. (`ActiveExchange` has no reader left
    outside the engine's own parser; F13 stands.)
- **The seam.** `TContestBase.GetCabrilloSentExchange(aMy, aQso, aCtx)` and
  `GetCabrilloReceivedExchange` (protected virtual) behind the public,
  **non-virtual** `FormatCabrilloSentExchange` / `FormatCabrilloReceivedExchange`
  -- S9b's shape. **`TCabrilloQSOContext.SessionExchange` is deleted**: the
  kind no longer travels to the contest. **The base answers
  `CabrilloExchangeErrorMarker`** (both columns): what the machine's `else`
  gave the classless DUMMYCONTEST, and the loud answer for a new contest that
  forgets. The Error the machine logged (Issue #1043, sent half only, naming
  the contest) moved into the public sent caller, which knows the contest's
  name and logs when the column IS the marker -- whoever produced it, base or
  helper.
  - **PostUnit asks the object that holds the station.** `exportContest` is
    `ContestIdentity(Contest)`, whose station is never set; the old machine got
    the entrant through `ContestSession.Exchange`. The nine station-dependent
    classes test `Station`, so the two columns are asked of `stationContest`
    (`ActiveContest`) when the contest has a class, and of `exportContest`
    (the plain base) when it has none.
- **The helpers: `uCabrilloExchange`, 56 -- one per distinct COLUMN** (27 sent,
  `CabrilloSentRSTState`, ...; 29 received, `CabrilloReceivedRSTQTH`, ...),
  same `(aMy, aQso, aCtx)` signature, named for what they print. Two are not
  layouts: `CabrilloSentNotHandled` / `CabrilloReceivedNotHandled` (the
  marker). They read the strings the machine read (no ShortString clip, unlike
  S9b: the machine took its inputs as `string`) and keep the 'TRC' and 'PGA'
  tests, which name no contest (they have no ContestType; plan section 6).
- **The overrides: 364 method bodies in 182 classes' worth of seam** -- the 181
  classes that state `GetADIFSentExchange` plus the base. **329 are new**
  (161 classes x 2, and 7 methods added to classes that overrode only one
  column) and **33 are the machine-era overrides renamed** from
  `FormatCabrillo...Exchange` to `GetCabrillo...Exchange`. Of the 33: 18 now
  call a helper (ARRL DX, CQ WPX, CQ WW, the General QSO, IARU, NA Sprint CW,
  the Ukraine Championship and the Ural Cup both columns; FOC Marathon's
  received, Florida's sent), 4 adjust an input and call the helper where they
  called `inherited` (California, the RSGB IOTA, UK/EI, WW Digi) and **11 keep
  their own body** (both Field Days, Sweepstakes, DARC 10 m's received, FOC's
  sent, Florida's received, the PACC's sent, the PCC's sent). The nine
  station-dependent classes test `CountsDXMultiplier`, `Station.InHostState`,
  `IsJapaneseEntrant` or `HasDXMultiplier` -- the predicates S9a used for the
  field list -- 17 methods in all. **15 classes state the marker by name**
  (`CabrilloSentNotHandled`): ALL JA, ARCI, County Hunter, FISTS, Grid Loc,
  JA Long Prefecture, Kids Day, NZ Field Day, POTA, QCWA, QCWA Golden,
  TEN-TEN, the UA4W Championship, WWL, Xmas.
- **The repoint.** `PostUnit` drops the `SessionExchange` assignment and asks
  `stationContest`. `FormatCabrilloExchangeOfKind` is DELETED, and with it the
  nested `SetMyEx` / `SetHisEx` the inventory attributed the arms to.
- **Unreachable branches deleted with the machine** (none changes an output
  a registered contest produces): the three arms above, with their three unit
  tests; `uTestCabrilloExchange`'s `Test_D4ExchangesAreUnhandled` (the Field
  Days and Sweepstakes have classes that format their own; an operator can no
  longer state an exchange for a contest that does not run it).
- **Pin: `uTestCabrilloColumns` (new).** Every ContestType (187) at the seven
  roster stations (`uTestExchangeFields.TPinStation`) with **eight inputs** --
  a full exchange; an empty one; over-long values (and a first record); a
  state of TRC; a contest title of PGA; negative serials and an all-digit
  state; no his-QTH selected with a QTH on the QSO; a DX QTH with none on the
  QSO -- against **literals made by running the OLD machine**
  (`FormatCabrillo{Sent,Received}Exchange` with
  `ctx.SessionExchange := uTestContestKindPin.Kinds(c, station).Exchange`,
  dumped to a file and laid out grouped by output: 43 groups, four of them
  station-dependent), a check of every one of the 56 helpers against the
  literals of a contest that calls it, and the base's marker. **OLD code (a
  worktree of `c54e0143` with the pin calling the old seam and the helper
  test cut): 220,882 passed, 0 failed -- 199,921 baseline + 20,944 column
  pairs (187 x 7 x 8 x 2) + 1 count + 16 base. NEW code: the same 20,961
  unchanged, plus the helper test (448) -- 221,322 passed, 0 failed** after
  `uTestCabrilloExchange` lost its three arm tests and the D4 test (-10) and
  `uTestContestExport` gained the DUMMYCONTEST's two marker checks (+2).
  `uTestContestExport`'s context helper lost its kind argument (and its tests
  now name a contest that really runs the layout: the Pennsylvania QP, the Old
  New Year, the UBA).
- **Build:** narrowing **1260** (ceiling 1262 -- two conversions fewer: the
  CQ WW and IARU `StrToIntDef(AnsiString(...))` calls left their classes),
  range **3**, full `-B`. Matrix, corpus and lints NOT run here. **The
  matrix should be IDENTICAL** (it prints Cabrillo for every contest); **the
  corpus byte-diffs 13 contests' columns -- IDENTICAL.**
- **Inventory** (generated to check the tool, then the tracked doc restored):
  rows 29, contests 30 -- unchanged; shape-4 PROXY 12, SHARED 22, SHAPE 0,
  UNUSED 10 unchanged. `judgements.SHAPE_MACHINES` lost the routine (one left,
  `ParseExchangeShape`); its two `ROUTINES` rows are replaced by rows for the
  two helpers that still hold a TRC / PGA test, and the three `SHAPE3` rows
  follow the code (`aMy.MyState`, `aCtx.HisQTH`); `analyses.dead_arms` asks
  `GetCabrilloSentExchange`, and section 9.1 says its export half is empty. The
  tracked document needs a regeneration after the commit: four `uCabrilloExchange`
  rows and the `postunit` line numbers move.
- **Not done here, on purpose.** The parser (`ParseExchangeShape`, S9d) still
  reads the session's exchange; `ContestSession.Exchange`, `GetExchangeKind`
  and `ExchangeType` stay for it and for the deletion stage. The 11 own-body
  overrides were not folded into helpers where their output differs (both
  Field Days, Sweepstakes, DARC 10 m, FOC's sent column, Florida's received,
  PACC's and PCC's sent).

### S9b/S9c follow-up (2026-10-14): F25, F26, F27 -- NO SILENT ERRORS IN EXPORT

NY4I: *"F25 was an artifact where the ADIF exchange generation had an error. We should not have that now if the
contest class works. We should report an error as the silent error is not good."*

- **F25 fixed, F27 fixed, F26 reported** -- see the three rows of the F-table.
- **Silent-failure sites found and changed.** (1) `PostUnit.MyExchangeForExport`'s `try`/`except` that answered
  the marker, and its `not GoodLookingQSO` answer of the marker; (2) `TContestBase.GetADIFSentExchange` (the
  base) and `ADIFSentNotBuilt`, which answered the marker; (3) `ADIFSentNotImplemented`, which answered `None`
  with an Error that named neither the contest nor the QSO; (4) `tGenerateLogPortionOfCabrilloFile`'s `except`,
  which wrote a DEBUG line and returned False with a truncated file; (5) the Cabrillo marker, loud in the file but
  unreported to the operator and unnamed to the QSO in the log.
- **The record is still written; `STX_STRING` is left out.** An ADIF record with no `STX_STRING` and a logged Error
  beats one with a made-up value. The Cabrillo marker stays in the line (Issue #1043: a robot must reject it).
- **Once per export, not per QSO.** `PostUnit.BeginExchangeFailureReport` / `NoteExchangeFailure` /
  `ReportExchangeFailures` warn once through `showwarning` (log-only in a headless /EXPORT); the per-QSO line is
  the log.
- **Oracle effect (expected).** The contest matrix freezes the ADIF `STX_STRING`: the five F25 contests change from
  the placeholder to their layouts, and the fourteen F26 contests lose `<STX_STRING:4>None`. The 13 corpus sets
  contain none of the nineteen contests. The frozen matrix was NOT regenerated by the agent that made this change.

#### S9d DONE (2026-10-15, on `7c766854` -- the code of `1662e18b`; uncommitted at hand-back): THE PARSER MACHINE

The last machine: `LOGSTUFF.ParseExchangeShape`, the `case` over the exchange
kind that chose the engine's parser for a typed exchange -- and every other
reader of the session's kind on the parse and entry paths.

- **Measured first.**
  - **Its arms: 56, one label each**, of `ExchangeType`'s 61 members. Five
    members had no arm and answered False, calling nothing: `UnknownExchange`,
    `NoExchangeReceived`, `RSTAndDOMESTICQTH`,
    `RSTAndSerialNumberAndGridandPossibleMemberNumber`,
    `RSTNameAndPossibleFOCNumber`.
  - **Reach** (the frozen matrix's `active.exchange` lines, 186 contests x 3
    stations, confirmed by running every ContestType at the seven roster
    stations through the old seam): registered contests run **51 kinds**, and
    each reaches its own arm -- **51 arms reached, 51 distinct parse
    behaviours** (no two reached arms share a body; the one shared body,
    `ProcessRSTAndPowerExchange`, was also called by the unreached
    `RSTAndFOCNumberExchange` arm). The classless DUMMYCONTEST reached the
    no-arm path.
  - **Unreachable: 5 arms** -- `CheckAndChapterOrQTHExchange`,
    `QSONumberAndAgeExchange`, `RSTAndGrid3Exchange`, `RSTAndFOCNumberExchange`
    (n4af) and `RSTQSONumberOrDomesticQTHExchange` (n4af 4.53.2). They went with
    the machine, and so did the **four parsers only they called**
    (`ProcessCheckAndChapterOrQTHExchange`, `ProcessQSONumberAndAgeExchange`,
    `ProcessRSTAndGrid3Exchange`, `ProcessRSTQSONumberOrDomesticQTHExchange`,
    193 lines). The members stay for S9e.
  - **Callers: ONE builder** -- `LOGSTUFF.ProcessExchange` filled
    `session.ParseShape := @ParseExchangeShape` and `session.Exchange :=
    ContestSession.Exchange` -- and **eight calls** through the session: the
    base `TContestBase.ParseReceivedExchange`
    (`aSession.ParseShape(aSession.Exchange, ...)`) and seven explicit ones in
    five classes (Arktika Spring x2, the PCC x2, Canada Day, Canada Winter,
    LABRE).
  - **How each class reached it.** 13 classes overrode
    `ParseReceivedExchange` (the ARRL SS and state-party family bases; Arktika
    Spring, Canada Day, Canada Winter, IARU, IN7QPNE, LABRE, PCC, SAC CW, SAC
    SSB, the UA4W Championship, UK/EI), covering **33 contests**; **153
    contests reached the machine through the base alone**. Of the 33, 31 call
    `inherited` (some only on one branch); Arktika Spring and the PCC never did
    -- they chose between two parsers by the text and never parsed the kind the
    session held. IN7QPNE parses twice: its own, then its judging party's
    `ParseReceivedExchange` **handed IN7QPNE's session**, so the party's rules
    judged an exchange parsed in IN7QPNE's kind (the trap, below).
  - **Station-dependent: 12 contests (11 classes)** -- ARRL DX x2 (on the
    base), ARRL 160, Arizona, California, JIDX CW, JIDX SSB, NEQP, 7QP, Texas,
    the Salmon Run and the PACC: the kind, and so the parser, moves with the
    station. California and the PACC share one field set across their two
    kinds (S9a) but not one parser.
  - **Every other reader of the session's kind**, code only, logddx
    excluded: **31 reads of `ContestSession.Exchange` in 9 files**. On the
    parse and entry paths: `ProcessExchange`'s session (1), the
    improper-domestic-QTH refusal's two `ExchangeModeAttribution` calls
    (LOGSTUFF, 2), `MainUnit.PerQSOExchString`'s `case` (1), the readiness
    check (uProgramMain, 1, and the three kind sets of `uContestReadiness`
    behind it). The rest are listed for S9e below. LOGSUBS2 and uStateBridge
    read none.
- **The seam.** `uContestBase.TExchangeParsers` -- an ABSTRACT CLASS with one
  named method per format (`ParseRSTZone`, `ParseRSTDomesticQTH`, ...: 'Parse' +
  the member the arm answered, less 'Exchange', so a reader finds the old arm)
  -- replaces `TExchangeShapeParser` and the session's kind:
  `TReceivedExchangeSession` holds `Parsers` and **`ExchangeFormatOf`** where it
  held `Exchange` and `ParseShape`. A class, not a record of 51 function
  pointers: a test double that forgets one fails by name. LOGSTUFF's
  `TEngineExchangeParsers` implements it, each method the old arm's body
  unchanged (the text back into the `Str80` it was typed as, as the machine
  did at its head); one instance, made in LOGSTUFF's `initialization` (its old
  bare `begin` block, which could not have a `finalization`) and freed in its
  `finalization`.
  - **The format is a protected virtual,
    `TContestBase.ParseReceivedExchangeFormat(aText, aParsers, var aExch)`**
    (S9a-c's getter-behind-a-caller shape), and the base
    `ParseReceivedExchange` asks it -- of `aSession.ExchangeFormatOf` when set,
    else of itself. **The base format parses nothing and answers False**: what
    the machine gave DUMMYCONTEST, and the answer for a new contest that
    forgets (uTestExchangeParse fails for one). A RULE stays on
    `ParseReceivedExchange`, around the format; a FORMAT goes on the new
    virtual. That split is what kept the 13 rule overrides unchanged in shape:
    each still calls `inherited` for the plain parse.
  - **`ExchangeFormatOf` exists for IN7QPNE alone.** It hands its judging
    party the session with itself named there (unless a caller already named
    one), so the party's rules judge IN7QPNE's format. Without it Delaware's
    own format (`RSTDomesticOrDXQTH`) and the 7QP's and NEQP's at a host
    station would have replaced IN7QPNE's `RSTDomesticQTH` -- a behaviour
    change the old seam hid by passing the session's kind along.
- **The helpers: 51** -- one per reached arm, which is one per distinct parse
  behaviour (the arms already were). Each is called by at least one registered
  contest (the counts are the generator's: `ParseRSTQSONumber` 25 calls,
  `ParseRSTDomesticQTH` 21, `ParseRSTDomesticQTHOrQSONumber` 13, ... 20 of them
  by one class each; the counts include the station and text branches).
- **The overrides: 184 `ParseReceivedExchangeFormat`** -- the 184 classes that
  state `GetReceivedExchangeFields` (182 leaves, the ARRL DX and NRAU Baltic
  family bases), placed beside it: **171** call one helper, **11** test the
  station with the predicate their field list and Cabrillo columns already use
  (`CountsDXMultiplier`: ARRL 160, the ARRL DX base, NEQP, 7QP, Texas, the
  Salmon Run; `Station.InHostState`: Arizona, California; `IsJapaneseEntrant`:
  JIDX x2; `HasDXMultiplier`: the PACC), **2** choose by the text (Arktika
  Spring, the PCC -- their choice is their FORMAT, so it moved here and their
  `ParseReceivedExchange` overrides are DELETED; 13 rule overrides -> 11).
  Canada Day, Canada Winter and LABRE call `aSession.Parsers.ParseRSTQSONumber`
  / `ParseRSTDomesticQTH` by name where they called `ParseShape` with a kind.
  Six leaves gained `uContestBase` in their interface `uses` (the SS, CQ WW and
  CQ WPX leaves saw `TContestBase` only through their family unit).
- **The other readers on the parse and entry paths, moved (the S7 method --
  transcribed exactly as class answers, disagreements recorded).** Four new
  `TContestBase` public virtuals (base False), nil-safe `Contest...` wrappers,
  **139 overrides** in the same holder classes:
  - `ExchangeCarriesDomesticQTH` (87 classes, 89 contests; the ARRL DX base
    answers `not CountsDXMultiplier`) -- uContestReadiness's
    `DOMESTIC_QTH_EXCHANGES`, asked by the readiness check's MY STATE rule and
    by LOGSTUFF's improper-domestic-QTH refusal (`ExchangeModeAttribution`,
    which takes the boolean now; one `ExchangeContest` fetch, on the refusal
    path only);
  - `ExchangeCarriesZone` (27; JIDX x2 answer `IsJapaneseEntrant`) --
    `ZONE_EXCHANGES`, the MY ZONE rule;
  - `ExchangeCarriesGridSquare` (20) -- `GRID_EXCHANGES`, the MY GRID rule;
  - `PerQSOExchangeLeadsWithSerial` (5: California, Pennsylvania, Virginia,
    the Ural Cup, the Ukraine Championship) -- `MainUnit.PerQSOExchString`'s
    `case`, which takes the boolean now; `DrainPendingMultiQSORefs` asks once
    per drain, the logging site once per multi-ref entry.
  - The three sets are DELETED from `uContestReadiness`;
    `CollectContestSettingsGaps` takes three booleans where it took the kind,
    and uProgramMain asks `ActiveContest(Contest)` once for all four of its
    answers (and no longer uses `uContestSession`). F28 records why these are
    transcriptions, not judgements.
  - **After: 26 reads of `ContestSession.Exchange` in 6 files** (MainUnit 2,
    FCONTEST 1, LOGDUPE 6, LOGEDIT 15, TREE 1, uContestMatrix 1). **No kind
    read is left on the parse path**; the exact list, and what each needs, is
    S9e's below.
- **Pin: `uTestExchangeParse` (new), with the shared stub
  `uTestExchangeParserStub` (new).** Every ContestType (187) at the seven
  roster stations through `ParseReceivedExchange`, the engine's parsers a stub
  that records which one was asked and does something deterministic with the
  text (accept unless empty or holding '!', last word to the QTH, word count
  to the received number, a five-letter last word to the domestic QTH), over
  **66 rows** -- eleven texts (empty; `599 123`; `123`; `ARRL`; `599 CT`; a
  whole Sweepstakes exchange; the same swapped; `599 INMAR`; garbage; an
  over-long exchange; a lone `599`) x six worked stations (W1AW, a VE0, a PY, a
  UA live and not live, a G). Each row's whole outcome (parsers asked, accepted,
  message, QTH, domestic QTH, zone, number, zone asked, entry abandoned) against
  **literals made by running the OLD seam** -- `PinnedHelper` (the parser a
  plain exchange reaches, per contest and station, grouped by parser) and
  `PinnedCodes` (one character per row: plain, another parser, a precedence
  named, out of state, refused, abandoned, zone filled, QTH copied, parsed
  twice...; eleven patterns, all uniform across stations but the state
  parties' host station). A cross-check of the pinned parser against a frozen
  copy of the machine's arm on the session kind (`LegacyHelper` on
  `uTestContestKindPin.Kinds`) stays until S9e. The four answers: literal sets
  and station branches per answer, per-station counts, and a cross-check
  against the frozen sets on `Kinds`. Only the seam routine differs between
  the old run and the new (`ProgramParse`, `ProgramCarries`; the old bodies are
  quoted in their comments). **OLD: 221,370 (baseline) -> 310,363 with the
  parse pin (+88,993: 86,394 rows, 1,309 code lengths, 1,288 cross-checks, 2
  counts) -> 320,864 with the answers' pin on the old sets (+10,501: 5,236
  answers, 28 counts, 5,236 cross-checks, 1 count). NEW: 320,864 passed, 0
  failed.** `uTestContestParse`, `uTestContestDelawareQP` and
  `uTestContestIN7QPNE` lost their three private `StubParseShape` copies to the
  shared stub and assert parser NAMES where they asserted kinds (same check
  count); `uTestContestReadiness` hands booleans (same count).
- **Build:** narrowing **1260** (ceiling 1260), range **3**, full `-B`. Matrix,
  corpus and lints NOT run here. **The matrix should be IDENTICAL**: its parse
  section runs the real parsers through `ParametersOkay` for every contest, and
  the improper-QTH refusal text it freezes is the attribution moved here; the
  entry and import sections do not parse through this seam. **The corpus
  should be IDENTICAL** (export reads no parser) and the factory check too.
- **Inventory** (generated to check the tool, then the tracked doc restored):
  rows 29, contests 30, PROXY 12, SHAPE 0, UNUSED 10 -- unchanged; SHARED 22 ->
  **21**; shape-4 sites 27 -> **26** (`case`s 3 -> 2 -- `PerQSOExchString`'s).
  `judgements.SHAPE_MACHINES` is EMPTY (the set stays, documented, so widening
  the scan cannot table a machine's arms as rules); `generate.py`'s note says
  so. `scan.SESSION`'s `EXCHANGE` entry stays for S9e.

**WHAT S9e INHERITS -- EVERY REMAINING READER OF THE KIND (code only; logddx,
compiled by nothing, excluded -- it names `ActiveExchange` 26 times, Q91).**

| where | what it decides | what it needs |
|---|---|---|
| `MainUnit.SetColumnsWidth` (2) | the log's Precedence and Check columns, for Sweepstakes | F15 (updated): a class answer, or `ExchangeInformation.Check` -- equal today, since S9a left Sweepstakes the only set marking `Check`; NOT `.Precedence`, which ALL JA marks too. Both run once at start-up (F19) |
| `FCONTEST.FoundContest`'s sent-message `case` (1 read, 10 labels) | which default CW exchange messages set-up installs | F30 -- a design decision |
| `LOGDUPE.ParseExchangeIntoContestExchange` (1, FISTS) | where a log line's QTH, name and power sit | nothing: DEAD (F29); delete the chain |
| `LOGDUPE.GetInitialExchangeStringFromContestExchange` (5) | the initial exchange remembered from a logged QSO (CallsignsList) | S8 (Q50): a class answer or helpers for the history render |
| `LOGEDIT.InitialExchangeEntry` (15) | the initial exchange offered from history (the slash join, the zone-or-domestic strip, the SS leading zero, the JIDX prefecture lookup) | S8 (Q50) |
| `TREE.LooksLikeAGrid` (1, `uGridShape.GRID_CARRYING_EXCHANGES`) | whether a log column's word may be a grid, once per row per repaint | S9f: a class answer read once per paint, not per row; and F28's grid-set question |
| `uContestMatrix` `active.exchange` (1) | DATA: the matrix prints the session's kind | dropping the line re-freezes all 186 frozen files -- NY4I's call |
| writers and declarations | `FCONTEST.ApplyContestTraits` (`WriteExchange(aContest.ExchangeKind)`) and `ApplySessionDefaults` (`WriteExchange(aSession.Exchange)`); `TContestSession.FExchange` / `Exchange` / `WriteExchange`; `TSessionDefaults.FExchange` / `SetExchange` / `Exchange` (and `svExchange`); `TContestBase.GetExchangeKind` / `ExchangeKind` | delete with the last reader |
| the trait and the statements | **186** `GetExchangeKind` overrides; **20** `DescribeSession` `aSession.Exchange :=` statements in 11 classes (ARRL 160, the ARRL DX base, Arizona, California, JIDX x2, NEQP, the PACC, 7QP, Texas, the Salmon Run) | delete; each class's station test already states the same choice in its format, field list and columns |
| VC | `ExchangeType` (61 members); `ActiveExchangeArray` (F13; `Lint-SpellingTables`' floor of 24 falls with it) | delete |
| `uGridShape.GRID_CARRYING_EXCHANGES` | read by TREE above and pinned by `uTestContestPOTA` | goes with S9f |
| tests | the frozen cross-checks on `uTestContestKindPin.Kinds` -- `uTestExchangeFields` (`LegacyFields`), `uTestExchangeRules` (`LegacyAnswer`), `uTestExchangeParse` (`LegacyHelper`, `LegacyCarries`) -- and `uTestContestSession`, `uTestContestFactory`, `uTestContestPOTA`, `uTestContestDelawareQP`, `uTestDomesticMultiplier`, `uTestDXMultiplierKey`, `uTestPrefixMultiplierKey` (each names a kind or `Kinds`) | the cross-checks go with the kind, as each says; the literal pins stay |
| tools | `scan.SESSION`'s `EXCHANGE`; `tools/contest-factory-m11/kind-reach.py` | update with the deletion |

### S10 -- (optional, Q93) Reach-1 shapes become their contest's own

- For each of the 20 members in 1.1, lift its parser out of LOGSTUFF and
  override the four seams in its one class, then delete the member. That is
  about 80 arms leaving the machines, one contest per commit.
- Do it only on NY4I's word: these are formats, not rules, and the move buys
  vocabulary size, not ownership.

**Expected inventory after S9:** zero compiled shape-4 PROXY rows. The rows
left are the shape-1 rows in 6.1, the shape-3 rows, and `logddx`'s 25 unless
Q91 deletes it. `Lint-ContestNameTests` is left with `MainUnit:8045` and
`postunit:2990`.

---

## 5. Defects and contradictions found

| # | where | evidence |
|---|---|---|
| **F1** | `tools/contest-rules-inventory/scan.py` `effective_reach` | Reach is trait UNION FoundContest overrides, and those are 0 since M7a. `DescribeSession` is invisible, so 12 live records are classed UNUSED (1.4). The four shape machines are not scanned either, and one that is (`SetUpExchangeInformation`) is reported as 37 contest rules. **FIXED at S0a** -- and it was 25 rows (43 records), not 37 |
| **F2** | `uContestARRL10:201`, `uContestARRLFieldDay:454`, `uContestKCJ:226`, `uContestYBDX:239-240` | Five trait values the session never runs (1.3) -- inventory D8's shape. `uTestContestSession` pins three of them as its evidence that "a reader may not ask the trait". **FIXED at S2**: the five traits state what runs, the statements are gone, and the three tests ask JIDX, WAEDC and ARRL 160 |
| **F3** | `zonecont.pas:103`; `logedit.pas:2571-2594`; `uTestContestParse:622-633` | `TContestRussianDX`/`TContestRU3AXMemorial.InitialExchangeFromCall` is reached only through `GetVEInitialExchange`, which only the Section and QTH initial-exchange arms call. No contest runs either of them since S2 (reach 0). The live Russian oblast rule is LOGEDIT's fallback (`logedit:2650`, `Contest in [RUSSIANDX, RDA, RU3AXMEMORIAL]`), so one of Q50's three spellings is already dead and a unit test pins it |
| **F4** | `MainUnit:934-936`, `:975-977`, `:2061`, `:5988`; `logsubs2:1611`; `TContestStateQSOPartyBase.SplitsRoverCallOnExport` | "Is a slash suffix a county?" is decided by exchange shape live (25 contests) and by the class on export (15). The two sets disagree. Split on export but not stripped live: CA, CO, MN, OH, PA. Stripped live but not split: ALRS, ARRL160, ARRLDX x2, AZ, BC, COUNTYHUNTER, IN7QPNE, LABRE, NEQP, NY, PACC, Salmon Run, 7QP, TOEC. Related to Q90. **CLOSED 2026-10-14** by NY4I's ruling on Q94/Q90: every QSO party strips AND splits (state parties on their base; 7QP, NEQP, IN7QPNE on their classes), County Hunter strips only, nothing else does either -- see "S7 follow-up DONE" |
| **F5** | matrix `CROATIAN`/`CWOPEN` setup; `uContestCroatian:290` | CROATIAN has `zonemult = ITUZones` with `cty.zonemode = CQZoneMode`, and exports `<ITUZ:2>05` for W1AW, whose CQ zone is 5 (`qthzone=5`). CWOPEN has `CQZones` over `ITUZoneMode`. The zone multiplier's system and the CTY lookup's system disagree in one class |
| **F6** | `logstuff.pas:7120-7131`, `:7143`; `logwind.pas:531` | `DomStringParse`'s DOK arm returns the local `TempMultiplier` uninitialised when the text has no letter. Its IOTA arm uses the unit global `LOGWIND.ContinentString` as scratch: it declares no local, and the global's only other writer is FCONTEST, with no reader. The whole routine is a drifted copy of `logdom.GetDomQTH:227-330`. **S6 part 1a (2026-10-14): TRANSCRIBED, NOT FIXED.** The shape tests are shared (`uDomesticKey`); the IOTA fall-through is the RSGB IOTA's `DomesticMultiplierFromQTH`; the unassigned DOK hint is WAG's and the DARC 10 m's `DomesticMultiplierHint` (fix: `Result := ''` in both, its own commit); the scratch global became a local (no reader, so no change), and `LOGWIND.ContinentString` now has a writer and no reader |
| **F7** | `uMults.pas:264-275` versus `logdupe.pas:662-760` | The remaining-DX-countries filter knows 3 of the 14 DX-key rules. Two owners of "which countries count"; the UI effect was not measured |
| **F8** | `uContestCQWWCW:122` versus `uContestCQWWSSB:122` | The CQ WW pair, which shares a family base, states different initial exchanges (Custom versus Zone). Sponsor intent unknown |
| **F9** | `LogCfg:433-436` (once, `uProgramMain:2318`) versus `uSettingsEffects:353` | `Doing*` is derived once at start-up, while the kinds are rewritten by every FoundContest. Readers mix the two (`uScoreTotals:161-164` and `MainUnit:9542-9543` read the session; `logdupe`/`logsubs2` read `Doing*`). **MEASURED at S0d: they diverge** on a peer's run-time `CONTEST` change (CQ WW CW -> ARRL SS CW leaves `Doing*` at CQ WW's values). **FIXED at S2** by construction: the four are `ContestSession` answers computed from the kinds, with no store of their own. What start-up derived FROM them is still once-only -- F19 |
| **F10** | 1.1 | 26 members have been unreachable since S2 retired their only selector. This includes `User1`..`User5` and the VE/Section/QTH initial exchanges -- operator features that S2 removed without removing their arms |
| **F11** | 11 factory `ParseReceivedExchange` guards (1.2) | Each class's session exchange is the same in every matrix variant, and none states one in `DescribeSession` (L5), so `aSession.Exchange = X` is always True in the program. Only the unit tests' stub sessions reach the other branch. **FIXED at S2**: the 11 guards and the six test cases are deleted |
| **F12** | `uContestBase.pas:2718` | A reach-1 rule (FISTS) sits in the base's non-virtual `CombineScore`. **CLOSED at S7 (2026-10-14):** it is `TContestFISTS.CombineWithMultipliers`, and `TScoreTotals.SessionExchange` went with it |
| **F13** | `VC.pas:3359` | `ActiveExchangeArray` survived for two log lines (`uADIFExchange:403/413`). **Those went at S9b** (the machine is helpers now and its Error log no longer names the shape); the array has NO reader. It goes with the kind enums in the deletion stage, and `Lint-SpellingTables`' floor of 24 falls with it |
| **F14** | `Lint-ContestNameTests.ps1` `$TOTAL_FLOOR = 5`, 6 found | S8 removes 4. The floor must fall in the same commit, or the lint fails with "broken parser" |
| **F15** | `MainUnit:9514-9516`; `logdupe:1709-1715` | The SS-shape test duplicates `ExchangeInformation.Precedence`/`.Check`. They are equal once S1 removes `CheckAndChapterOrQTH`, the only other arm that sets `Check` |
| **F15a** | `MainUnit.SetColumnsWidth`; `uExchangeFields` | (S9d, an update to F15) **S9a removed F15's blocker for one column of two.** `ExchangeInformation.Check` is marked by one field set now, `ExchangeFieldsQSONumberPrecedenceCheckQTH` (Sweepstakes'), so the Check column's `= QSONumberPrecedenceCheckDomesticQTHExchange` equals `ExchangeInformation.Check` for every registered contest at every roster station. `.Precedence` is NOT a substitute for the Precedence column: `ExchangeFieldsRSTPrecedenceQTH` (ALL JA) marks it too, so asking it would show a precedence column in ALL JA -- a behaviour change for NY4I. Left for S9e: a class answer for both, or `.Check` for both with F19's once-at-start-up timing accepted |
| **F16** | inventory section 9.1; `analyses.dead_arms` | (S0a) The "export arms dead by default" table is EMPTY, and not because there are none: it reads `SetHisEx` / `FormatADIFExchangeOfKind` records, and those machines left the scan when their selector became a parameter (`aCtx.SessionExchange`, `aKind`). The same blindness as F1's three unscanned machines. Not fixed at S0a, which judges the machines SHAPE |
| **F17** | `uProgramMain:2701` versus `:2405` | (S0d) `CD.MasterFileExists` is set after the `/MATRIX` halt (and `/EXPORT`'s), so headless runs never open TRMASTER: `CD.GetEntry('W1AW')` answers "not found" while the shipped file holds W1AW. Every TRMASTER-sourced initial exchange is blank in the matrix |
| **F19** | `LogCfg` (once, `uProgramMain:2318`); `uProgramMain:2306-2307` versus `uSettingsEffects:353` | (S2) After F9's fix the `Doing*` answers follow a run-time contest switch, but what start-up DERIVED from them and from the exchange does not: `NumberDifferentMults`, `RemainingMultDisplay`, `Sheet.SheetInitAndLoad`, `SetUpExchangeInformation` and `SetColumnsWidth` run once. A peer's CONTEST line still leaves those describing the previous contest. Not measured on a bench. (S9a: `SetUpExchangeInformation` is deleted; its successor, the `ExchangeInformation := ContestReceivedExchangeFields(ActiveContest(Contest))` assignment, still runs once, in the same place) |
| **F20** | `TContestBase.PrefixMultiplierKey` (UBA, SAC, WAEDC, All Asian, OK DX, CQ MM, SAWW, YB DX) versus `ContestSession.DoingPrefixMults` | (S3) The key now asks `Station`, which `ActiveContest` refreshes on every call; whether `SetPrefix` is called at all still asks the session kind, fixed at set-up. They agree unless the entrant's country or continent changes mid-session without a CONTEST change (FoundContest is not re-run for MY CALL): then e.g. a UBA log started outside Belgium and switched to an ON call keeps `DoingPrefixMults` but gets no key. YB DX already read the live `Settings.My.Country` before S3. The end state (part 2, §3) asks the class for both, so this closes then. Not measured on a bench. **CLOSED at S3 part 2 (2026-10-14):** both now read `Station` -- `DoingPrefixMults` is `TContestBase.HasPrefixMultiplier` through `ActiveContest`, and the station-dependent keys ask it. The mid-session change is still not bench-checked |
| **F21** | `TContestBase.DXMultiplierKey` / `CountryMode` / `ListsRemainingDXCountry` (ARRL DX, ARRL 160, All Asian, JIDX, SAC, Helvetia, Croatian, WAG, UBA, WAE, PACC, RDA, ALRS, YU DX, the host-state parties) versus `ContestSession.DoingDXMults` | (S4 part 1) F20's shape, for the DX kind: the key and the remaining-mults filter ask `Station`, refreshed on every `ActiveContest` call, while whether `GetDXQTH` runs and whether the window lists DX countries at all still ask the session kind fixed at set-up. They agree unless the entrant's country, continent or host state changes mid-session without a CONTEST change. The country list is asked once, at set-up, so it cannot drift. Part 2 makes "does this contest count DX" a class answer, as S3 part 2 did for prefixes. Not measured on a bench. **CLOSED at S4 part 2 (2026-10-14):** all four read `Station` -- `DoingDXMults` is `TContestBase.HasDXMultiplier` (through `ActiveContest`, or on the object a per-QSO caller holds), and each station-dependent class's key, country list and answer ask one private predicate. The mid-session change is still not bench-checked |
| **F22** (**FIXED 2026-10-14**: `BestTwoLetters` zeroes `NumberBytes` on entry; 24 matrix records re-frozen, only `iex JA1ABC` moved, now showing its TRMASTER name/grid/zone) | `trdos/logscp.pas` `CallDatabase.BestTwoLetters` (also in D7, `C:\TR4W` logscp.pas:1196) | (S5 part 1, found by the matrix) **A call-history lookup of any call containing `JA` reads an uninitialised local.** The routine skips the `JA` pair with `Continue` and never assigns its `NumberBytes[CharPos]`, then returns the FIRST pair whose size equals the minimum -- so whatever the stack holds in that slot decides whether it picks the real smallest bucket or the `JA` bucket, which TRMASTER never fills (`trmaster_codec.bucket_pairs` excludes `JA`, as TR's own writer does), giving "not found". The residue is in practice the PREVIOUS lookup's `NumberBytes[1]`. Measured in the matrix fixture: DL1ABC's `DL` bucket is 23 bytes and JA1ABC's smallest real bucket (`A1`) is 23 bytes, so after a DL1ABC lookup JA1ABC is not found and the initial exchange falls through to CTY.DAT. In the frozen matrix JA1ABC's TRMASTER name is offered in ONE record (GRIDLOC, whose path leaves other residue), while DL1ABC's is offered in 22. S5 part 1's first build called `ActiveContest` between two lookups (InitialExchangeEntry's ITU test), which overwrote the slot, and JA1ABC was then FOUND in the Croatian, IRTS and WRTC (`trmaster=" 25"` -> `" 45"`, `" 45"` -> `" 25"`); proven by putting the old session test back beside an `ActiveContest` call, which moved the same lines. So the frozen JA1ABC `trmaster` value is the defect's, not a rule, and it holds only while nothing deep runs between lookups. Live effect: SCP partials (`LOGEDIT` :1812) and every TRMASTER field (name, zones, QTH, section, ...) for a JA-containing call depend on the call looked up before it. **Recommendation:** assign `NumberBytes[CharPos] := 0` before the `Continue` -- the routine's own convention ("we get zero if we had an illegal character"), so the `JA` pair is never chosen -- in its own commit with a deliberate matrix re-freeze (the JA1ABC `trmaster`/`logged`/`custom` columns move wherever TRMASTER contributes). After it, `InitialExchangeEntry` may ask `ActiveContest` like the other zone readers. **Held for S5:** that site asks `ContestIdentity` (shallow; its ITU answer is station-independent for every contest, pinned by `Test_TheITUQuestionDependsOnNoStation`), so S5 moves no output. **Done at S5 part 2:** it asks `ActiveContest`; the matrix moved nowhere. Related to Q95 only in that it surfaced on the zone question |
| **F23** | `TContestALRSUA1DZCup`, `TContestWAG`, `TContestDARC10M` `DomesticMultiplierFromQTH` / `DomesticMultiplierHint` / `DomesticQTHReplacesDXMultiplier` / `DomesticQTHIsNeverAGrid` versus `ContestSession.DoingDomesticMults` | (S6 part 1a) F20's shape, for the domestic kind: the three station-dependent classes' answers ask `Station`, refreshed on every `ActiveContest` call, while whether GetDomQTH asks at all (`DoingDomesticMults`) still asks the session kind fixed at set-up. They agree unless the entrant's country changes mid-session without a CONTEST change (WAG begun at a DL call and switched away keeps no domestic multiplier; begun elsewhere and switched to DL, it looks a DOK up in a domestic file it has none of, where the kind kept reading DOKs). Part 2 makes "does this contest count a domestic multiplier" a class answer, as S3-S5 part 2 did. Not measured on a bench **CLOSED at S6 part 2 (2026-10-14):** `DoingDomesticMults` is `TContestBase.HasDomesticMultiplier` (through `ActiveContest`, or on the object a per-QSO caller holds), composed from the answers these classes already state and overridden by WAG and the DARC 10 m with the same station test, so the gate and the rules read the same `Station`. The mid-session change is still not bench-checked |
| **F24** | `TContestUA4WChampionship.GetReceivedExchangeFields`; the deleted `LOGDUPE.SetUpExchangeInformation` | (S9a) **The UA4W Championship's received exchange marks no field.** Its shape, `RSTAndGridSquareOrRDAExchange`, had no arm in the machine, so start-up left `ExchangeInformation` all False for it: the log-string parses take no RST or QTH from a logged line, and the ADIF export's RST test (POSTUNIT) is False. Transcribed into its class as `ExchangeFieldsNone`, not fixed; the likely fix is `ExchangeFieldsRSTQTH` (it is an RST-and-grid-or-RDA exchange) -- a behaviour change for its own commit, with a matrix re-freeze. Three latent oddities of the machine, none observable: it cleared 13 of the record's 16 fields and left `Kids`, `TenTenNum` and `FOCNumber` (harmless -- it ran once over a zero-initialized global; every helper now clears all 16); its unreached `RSTAndGrid3Exchange` arm marked the QTH alone, no RST; and no arm ever marked `FOCNumber` or `ZoneOrSociety` (the FOC Marathon runs `RSTPower`, whose number lands in `Power`) |
| **F25** | `TContestCupRFCW/SSB/DIG`, `TContestCQWWRTTY`, `TContestYouthChampionshipRF`; `uADIFExchange` | **FIXED 2026-10-14 (NY4I: "F25 was an artifact where the ADIF exchange generation had an error. We should not have that now if the contest class works. We should report an error as the silent error is not good").** S9b found that five contests exported `Error generating my exchange` as the ADIF `STX_STRING` of every QSO: the old machine's format for three shapes raised and its own `try`/`except` swallowed it (`QSONumberAndGridSquare`, the Cup RF's three runnings, `'%-3s %-7s'` of a number; `RSTZoneAndPossibleDomesticQTHExchange`, CQ WW RTTY, `'%-3d %02u %-4s'` of a `ShortString` zone; `AgeAndQSONumberExchange`, the Youth Championship RF, three specifiers and two arguments). Each of the five now exports **what the same class prints in its Cabrillo sent column** (that column was never broken): Cup RF `ADIFSentQSONumberStateShort` (`'%.*d %-6.4s '`, serial then MY STATE, which is the grid the Cup RF sends), CQ WW RTTY `ADIFSentRSTZoneStateDX` (`'%-3d %.2u %-4s'`, state or `DX`), Youth Championship RF `ADIFSentStateQSONumber2` (`'%-2s %.*d '`). `ADIFSentNotBuilt` and `ADIFMyExchangeErrorMarker` are deleted: **no placeholder stands in for an exchange any more.** A getter that cannot build its string raises; `TContestBase.TryFormatADIFSentExchange` logs an Error naming the contest and the QSO, answers `''`, and PostUnit omits `STX_STRING` from that record and warns once per export. Open for NY4I: the Youth Championship RF's received column is `Age QSONumber`, so whether its SENT side really is state-and-serial (the Cabrillo column says so) is the sponsor's to confirm; the export now agrees with the Cabrillo file, which is the only content the tree knew |
| **F26** | `TContestARCI`, `TContestAllJA`, `TContestCountyHunter`, `TContestFISTS`, `TContestGridLoc`, `TContestJALongPrefect`, `TContestKidsDay`, `TContestJockWhiteFieldDay`, `TContestPOTA`, `TContestQCWA`, `TContestQCWAGolden`, `TContestTenTen`, `TContestUA4WChampionship`, `TContestWWL`, `TContestXmas`; `uCabrilloExchange.CabrilloSentNotHandled` | (S9c) **Fifteen registered contests write `ERROR EXCHANGE NOT HANDLED` in BOTH exchange columns of every `QSO:` line.** The old machine had no arm for 14 of their shapes (`KidsDay`, `NZFieldDay`, `NameAndPossibleGridSquare`, `NameQTHAndPossibleTenTenNumber`, `QSONumberNameChapterAndQTH`, `RSTALLJAPrefectureAndPrecedence`, `RSTAndGrid`, `RSTAndGridSquareOrRDA`, `RSTAndPOTAPark`, `RSTLongJAPrefecture`, `RSTPossibleDomesticQTHAndPower`, `RSTQSONumberAndRandomCharacters`, `RSTQTH`, `RSTQTHNameAndFistsNumberOrPower`) and its `else` wrote the marker (Issue #1043, deliberately loud). The same 14 shapes are the ADIF `None` list (F25). Transcribed, not fixed: each class states `CabrilloSentNotHandled` / `CabrilloReceivedNotHandled`, which is that answer by name; a fix needs each sponsor's column layout (POTA has no Cabrillo at all, so its answer may be right). The classless DUMMYCONTEST gets it from the base. **UPDATE 2026-10-14 (REPORTED, NOT FIXED; NY4I: the silent error is not good):** the Cabrillo marker stays in the file (deliberate, Issue #1043), but every such `QSO:` line now logs an Error naming the contest AND the QSO, the writer counts them, and the operator is warned ONCE per export (`PostUnit.ReportExchangeFailures`; log-only in a headless /EXPORT). The same fourteen shapes' ADIF `STX_STRING` used to be `None`; it is now LEFT OUT of the record (`ADIFSentNotImplemented` raises `EADIFExchangeNotImplemented`, reported the same way), because `None` is a value a robot reads as an exchange. No format was invented: each needs the sponsor's layout. The Cabrillo writer's `except` used to write a DEBUG line and return False with a truncated file; it is an Error plus a warning now |
| **F27** | `PostUnit.MyExchangeForExport:2344`, `TContestJIDXCW`/`TContestJIDXSSB.GetADIFSentExchange` | (S9c, found while reading how PostUnit reaches the station) **S9b's ADIF `STX_STRING` for the JIDX asks an object that has no station.** `MyExchangeForExport(aContest)` builds `my` from the active contest it is handed but then calls `ContestIdentity(Contest).FormatADIFSentExchange`, and the identity object is never given a station (`SetStation` runs only on `ActiveContest`'s object), so `IsJapaneseEntrant` is False at every entrant: a Japanese JIDX station exports the prefecture layout (`'%-3d %-7d'`) where the old machine, keyed on the session's exchange, exported the zone layout (`'%-3d %-7.2d'`). The other eight station-dependent contests print the same ADIF text at both shapes, so only JIDX moves. Neither the corpus (no JIDX set) nor the matrix (no STX_STRING) nor `uTestADIFSentExchange` (it builds the object WITH the station) sees it. **FIXED 2026-10-14: `PostUnit.MyExchangeForExport` asks `ExchangeContest(aContest)` -- the `ActiveContest` object when the contest has a class, else `ContestIdentity` -- and the Cabrillo writer asks the same function.** Only JIDX CW/SSB move (a scan of every `GetADIFSentExchange` found no other station test); the corpus and the matrix have no Japanese entrant, so neither sees it, and the unit pin builds the object with its station, so none of the three could. |
| **F28** | `TContestBase.ExchangeCarriesDomesticQTH` / `ExchangeCarriesZone` / `ExchangeCarriesGridSquare` (were `uContestReadiness`'s three sets); `ReceivesGridSquareExchange`; `uGridShape.GRID_CARRYING_EXCHANGES` | (S9d) **TRANSCRIBED, NOT JUDGED.** The readiness check reports an empty MY STATE, MY ZONE or MY GRID -- what the station SENDS -- from sets of RECEIVED exchange kinds, and S9d made each set a class answer for exactly the contests it held, so nothing changed. Two consequences are worth a ruling: (1) the proxy can be wrong for a station, e.g. a W or VE entrant in the CQ 160 contests runs `RSTZoneOrDomesticQTH`, which sits in both the domestic and the zone sets, so both MY STATE and MY ZONE are required of it though (by the sponsor's rules, unverified here) it sends only a state, and the improper-QTH refusal names MY COUNTRY for every domestic-QTH contest, not only those whose exchange MY COUNTRY chose (ARRL DX; the comment says it was written for it); (2) **the tree now has THREE grid sets that disagree**: `ExchangeCarriesGridSquare` (20 contests: the VHF/grid, Cup RF, RTC/Tesla/EU VHF family, Grid Loc, UA4W, WWL...), `ReceivesGridSquareExchange` (9, the ADIF import's) and `GRID_CARRYING_EXCHANGES` (TREE's per-row grid test; it holds BWQP's/General QSO's `RSTNameAndQTH` and POTA, and not the Cup RF or Grid Loc). A sent-exchange model would answer (1); S9f decides (2) for TREE. Not measured on a bench |
| **F29** | `LOGDUPE.ParseExchangeIntoContestExchange`; `LOGSUBS2.PushLogStringIntoEditableLogAndLogPopedQSO`, `LogBackCopy` | (S9d, found measuring the readers) **The FISTS log-line placement (`ContestSession.Exchange = RSTQTHNameAndFistsNumberOrPowerExchange`) is DEAD, and so is the routine.** `ParseExchangeIntoContestExchange`'s only caller is `PushLogStringIntoEditableLogAndLogPopedQSO`, whose callers are `LogBackCopy` -- which nothing calls -- and two lines inside a `{ }`-commented block; and `LogBackCopy` hands it a `;` note line, which the routine's head rejects. The plan's and the agent's list of `ExchangeInformation` readers (S9a: "`LOGDUPE.ParseExchangeIntoContestExchange` (via `LOGSUBS2`'s log-string read)") names a reader that never runs. S9e can delete the chain; not deleted here (no behaviour to move) |
| **F30** | `FCONTEST.FoundContest`'s sent-message `case ContestSession.Exchange of` | (S9d) **Moving it needs a design decision.** It chooses which of FCONTEST's default CW exchange-message routines set-up runs (`SetUpNameAndStateExchange`, `SetUpRSTQSONumberExchange`, `SetUpRSTMyStateExchange`, `SetUpRSTMyZoneExchange`), with `SentMyState` and the contest's `SuppressZoneExchangeMessages` / `SendsStateAfterZone` around it -- engine routines that write the CW memories, which a contest class cannot link. The S9d answer for the parsers (an engine-implemented service class the contest calls by name) fits, as would a class answer naming the message set (an enum again, which Q92 rejected for the machines). Reach: 10 labels; 93 contests run one of them at some matrix station, 86 at all three |
| **F31** | `TContestIN7QPNE.ParseReceivedExchange`; `TReceivedExchangeSession.ExchangeFormatOf` | (S9d) **IN7QPNE's party parse depended on the session's kind, invisibly.** It hands its judging party's `ParseReceivedExchange` the session it was handed, and until S9d that carried IN7QPNE's kind (`RSTDomesticQTH`), so Delaware's QSOs parsed as `RSTDomesticQTH`, not Delaware's own `RSTDomesticOrDXQTH`. S9d kept that exactly (`ExchangeFormatOf`). Whether a Delaware QSO in IN7QPNE should parse in Delaware's format (which accepts a DX QTH) is a sponsor question; how often the two formats disagree inside IN7QPNE was not measured, on a bench or otherwise |
| **F18** | `MainUnit:7976`, `:8031` | (S0d) `LoadinLog` adds the logged initial-exchange history only while `IntitialExLoaded` is False, and latches it True at its end. A second `LoadinLog` in one session -- the matrix's totals reload, and any in-session reload -- adds no history. Whether a live reload path (an import, a rescore) loses history this way was not measured |

Open questions to add to the design (next free number Q92):

- **Q92** -- keep `ExchangeType` as a shape vocabulary (0.1)?
- **Q93** -- S10?
- **Q94** -- F4's rover set.
- **Q95** -- F5.
- **Q96** -- F8.
- **Q50** -- F3 makes it a blocker for S1 and S8.

---

## 6. Out of scope -- what remains outside the factory after M11

| what | rows today | after M11 | needs |
|---|---|---|---|
| the shape-1 rows that are not initial-exchange rows | `MainUnit:8045` (RADIOYOC previous number at load), `postunit:2990` (Cup RF his-QTH) | unchanged | **M12**: session-state and Cabrillo seams |
| shape-3 string tests | 13 (TRC, PGA, EURASIA, LABRE name, CQ-WW and IARU off-time Q60, RAEM callsign, POTA SIG) | 12 (GAGARINCUP leaves at S3) | **M12** -- several are not contests at all (TRC, PGA) |
| the four exchange-shape machines and the shape readers | not rows (F1) | kept on purpose | none, if Q92 is yes |
| `FoundContest:943` sent-message defaults per shape | not a row | kept (shape) | none |
| `logddx.pas` -- 25 PROXY rows plus 3 `case`s | compiled by nothing | unchanged | Q91 (delete, or rebuild) |
| `RemainingMultiplierType`, `CountryModeType`, `ZoneModeType` | shared vocabularies | kept | none |

**M12 is warranted, but small:** the two shape-1 rows and the curated shape-3
rows.

---

## Appendix A -- `kind-reach.py` (commit at S0a as `tools/contest-factory-m11/kind-reach.py`)

**COMMITTED AT S0a, WITH ONE CHANGE** (section 4 S0a): the `DescribeSession`
half of `session_reach` calls the inventory's `scan.describe_session_statements`
rather than the line regex below, and `--inventory` reads the fixed reach, so
it is now a cross-check that reclassifies every record to its own class. The
listing below is the measuring version, kept as the record of how the plan's
figures were made; the committed file is the one to run.

Run L1 first. Every L2 and L9 figure above came from this script, re-run on
`f006acb2` as a check. It reports 10 `CASE` sites, 96 distinct engine `TEST`
lines plus 19 inside the factory, 26 members at reach 0 besides
`UnknownExchange`, and `INVENTORY` 123 sites, 229 records, 12
`LIVE-BUT-UNUSED`. It resolves `ROOT` from its own location, so it must sit at
the committed path.

```python
"""kind-reach.py -- M11's measurement: where the six kind enums are read, and
which contests reach each value (trait U frozen matrix U DescribeSession).

   python tools/contest-factory-m11/kind-reach.py <dump-dir> [--inventory]

<dump-dir> holds code/ and codestr/ from
tools/contest-rules-inventory/dump-code-only.ps1. logddx.pas (compiled by
nothing, M10 F14) is skipped. --inventory also runs the inventory's own
shape-4 scan and reclassifies its records with the session reach."""

import collections
import glob
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.join(ROOT, "tools", "contest-rules-inventory"))
import pascal   # noqa: E402
import scan     # noqa: E402
from model import Dump, Contests, Registry   # noqa: E402

# enum -> (row field, matrix line key, TSessionDefaults property)
ENUMS = {"ExchangeType": ("AE", "exchange", "EXCHANGE"),
         "InitialExchangeType": ("AIE", "initialexchange", "INITIALEXCHANGE"),
         "DXMultType": ("XM", "dxmult", "DXMULT"),
         "PrefixMultType": ("Pxm", "prefixmult", "PREFIXMULT"),
         "ZoneMultType": ("ZnM", "zonemult", "ZONEMULT"),
         "DomesticMultType": ("DM", "domesticmult", "DOMESTICMULT")}


def enum_members(vc, e):
   body = re.search(r"\b" + e + r"\s*=\s*\((.*?)\)\s*;", vc, re.S | re.I).group(1)
   return re.findall(r"[A-Za-z_]\w*", body)


def session_reach(dump, contests, reg):
   """{enum: {VALUE: {contests}}} -- trait U matrix U DescribeSession."""
   session = {e: collections.defaultdict(set) for e in ENUMS}
   for c in contests.real():
      for e, (f, _, _) in ENUMS.items():
         v = contests.field(c, f)
         if v:
            session[e][v.upper()].add(c)
   for path in glob.glob(os.path.join(ROOT, "tr4w", "test", "contest-matrix", "frozen", "*.matrix")):
      c = os.path.basename(path)[:-len(".matrix")]
      for line in open(path, encoding="latin-1"):
         m = re.match(r"active\.(\w+) = (\S+)", line)
         if not m:
            continue
         for e, (_, key, _) in ENUMS.items():
            if m.group(1) == key:
               session[e][m.group(2).upper()].add(c)
   field = {v[2]: e for e, v in ENUMS.items()}
   stated = collections.defaultdict(list)
   for rel in dump.factory():
      text = dump.text(rel)
      rt = pascal.routines_by_line(text)
      for ln, line in enumerate(text.split("\n"), 1):
         for m in re.finditer(r"aSession\.(\w+)\s*:=\s*(\w+)", line, re.I):
            r = rt.get(ln, "")
            if m.group(1).upper() in field and r.upper().endswith(".DESCRIBESESSION"):
               stated[r.split(".")[0].upper()].append((field[m.group(1).upper()], m.group(2)))
   for c, info in reg.classes.items():
      for k in info["chain"]:
         for e, v in stated.get(k, []):
            session[e][v.upper()].add(c)
   return session


def main():
   dump = Dump(sys.argv[1])
   contests = Contests(dump)
   reg = Registry(dump, contests)
   contests.adopt_class_facts(reg)
   vc = dump.text("tr4w/src/VC.pas")
   member_of = {}
   for e in ENUMS:
      for t in enum_members(vc, e):
         member_of[t.upper()] = e
   session = session_reach(dump, contests, reg)

   def reach(e, vals):
      out = set()
      for v in vals:
         out |= session[e].get(v.upper(), set())
      return out

   for rel in dump.files():
      if rel.endswith("logddx.pas"):
         continue
      text = dump.text(rel)
      toks = pascal.tokenize(text)
      rt = pascal.routines_by_line(text)
      labels = set()
      for i, (t, ln) in enumerate(toks):
         if t.upper() != "CASE":
            continue
         cs = pascal.walk_case(toks, i)
         arms = [(a["line"], [x for x in a["labels"] if x.upper() in member_of]) for a in cs.labelled_arms()]
         arms = [a for a in arms if a[1]]
         if arms:
            labels |= cs.label_tokens
            e = member_of[arms[0][1][0].upper()]
            print(f"CASE {rel}:{ln} {rt.get(ln)} [{cs.selector}] {len(arms)} arms")
            for aln, labs in arms:
               print(f"   :{aln} {','.join(labs)} reach={len(reach(e, labs))}")
      for i, (t, ln) in enumerate(toks):
         u = t.upper()
         # `Prefix` is also a local/field name all over the tree; its real
         # kind tests are SetPrefix's labels and MainUnit's `in` set.
         if u not in member_of or i in labels or u == "PREFIX" or i == 0 or toks[i - 1][0] == ".":
            continue
         prev = toks[i - 1][0]
         nxt = toks[i + 1][0] if i + 1 < len(toks) else ""
         lb = scan._enclosing_set(toks, i)
         in_set = lb is not None and lb > 0 and toks[lb - 1][0].upper() == "IN"
         if prev in ("=", "<>") or nxt in ("=", "<>") or in_set:
            print(f"TEST {rel}:{ln} {rt.get(ln)} {t} reach={len(reach(member_of[u], [t]))}")
   for e in ENUMS:
      for m in enum_members(vc, e):
         print(f"MEMBER {e} {m} reach={len(session[e].get(m.upper(), ()))}")

   if "--inventory" in sys.argv:
      sites, _ = scan.scan_sites(dump, contests)
      prox = scan.classify_proxies(sites, scan.effective_reach(contests, []), reg.registered())
      f2e = {v[0]: e for e, v in ENUMS.items()}
      print("INVENTORY sites", sum(1 for s in sites if s["shape"] == 4),
            "records", collections.Counter(p["class"] for p in prox))
      moved = collections.Counter()
      for p in prox:
         n = len(reach(f2e[p["field"]], p["values"]))
         now = "UNUSED" if n == 0 else ("PROXY" if n <= 3 else "SHARED")
         moved[(p["class"], now)] += 1
         if p["class"] == "UNUSED" and n:
            print(f"   LIVE-BUT-UNUSED {p['file']}:{p['line']} {p['values']}")
      print("INVENTORY reclassified", dict(moved))


if __name__ == "__main__":
   main()
```
