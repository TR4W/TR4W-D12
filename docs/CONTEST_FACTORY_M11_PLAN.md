# M11 -- the kinds move into the classes: a staged, measured plan

**Status: PLAN, S0 DONE. S0a, S0b and S0d are DONE (2026-10-14, at
`95e127a5`); S0c is DONE (2026-10-14, on `3b4c0777`, its re-freeze NY4I's);
S2 is DONE (2026-10-14, on `c749f2c5`) except its F15 and F6 bullets, which
wait (section 4 S2); S3 is DONE -- part 1 (the move) on `42a999c1`, part 2
(the deletion) on `cbcba524`, both 2026-10-14; S4 part 1 (the move) is DONE
on `3c8ce116` (2026-10-14), its part 2 (the deletion) not built; S1 and S5 on
are not built.** See section 4 S0 for
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

- `ExchangeShape(aStation)` replaces `GetExchangeKind` (373) and
  `TSessionDefaults.Exchange`. FCONTEST caches it in `ContestSession.Exchange`.
- `ActiveExchangeArray`: keep it, or replace its two log lines with RTTI
  `GetEnumName`. If deleted, check `Lint-SpellingTables`' floor of 24.
- *Matrix:* identical. *Risk:* low-medium.
- *Specialists:* `contest-scoring`, `build-release`.

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
| **F4** | `MainUnit:934-936`, `:975-977`, `:2061`, `:5988`; `logsubs2:1611`; `TContestStateQSOPartyBase.SplitsRoverCallOnExport` | "Is a slash suffix a county?" is decided by exchange shape live (25 contests) and by the class on export (15). The two sets disagree. Split on export but not stripped live: CA, CO, MN, OH, PA. Stripped live but not split: ALRS, ARRL160, ARRLDX x2, AZ, BC, COUNTYHUNTER, IN7QPNE, LABRE, NEQP, NY, PACC, Salmon Run, 7QP, TOEC. Related to Q90 |
| **F5** | matrix `CROATIAN`/`CWOPEN` setup; `uContestCroatian:290` | CROATIAN has `zonemult = ITUZones` with `cty.zonemode = CQZoneMode`, and exports `<ITUZ:2>05` for W1AW, whose CQ zone is 5 (`qthzone=5`). CWOPEN has `CQZones` over `ITUZoneMode`. The zone multiplier's system and the CTY lookup's system disagree in one class |
| **F6** | `logstuff.pas:7120-7131`, `:7143`; `logwind.pas:531` | `DomStringParse`'s DOK arm returns the local `TempMultiplier` uninitialised when the text has no letter. Its IOTA arm uses the unit global `LOGWIND.ContinentString` as scratch: it declares no local, and the global's only other writer is FCONTEST, with no reader. The whole routine is a drifted copy of `logdom.GetDomQTH:227-330` |
| **F7** | `uMults.pas:264-275` versus `logdupe.pas:662-760` | The remaining-DX-countries filter knows 3 of the 14 DX-key rules. Two owners of "which countries count"; the UI effect was not measured |
| **F8** | `uContestCQWWCW:122` versus `uContestCQWWSSB:122` | The CQ WW pair, which shares a family base, states different initial exchanges (Custom versus Zone). Sponsor intent unknown |
| **F9** | `LogCfg:433-436` (once, `uProgramMain:2318`) versus `uSettingsEffects:353` | `Doing*` is derived once at start-up, while the kinds are rewritten by every FoundContest. Readers mix the two (`uScoreTotals:161-164` and `MainUnit:9542-9543` read the session; `logdupe`/`logsubs2` read `Doing*`). **MEASURED at S0d: they diverge** on a peer's run-time `CONTEST` change (CQ WW CW -> ARRL SS CW leaves `Doing*` at CQ WW's values). **FIXED at S2** by construction: the four are `ContestSession` answers computed from the kinds, with no store of their own. What start-up derived FROM them is still once-only -- F19 |
| **F10** | 1.1 | 26 members have been unreachable since S2 retired their only selector. This includes `User1`..`User5` and the VE/Section/QTH initial exchanges -- operator features that S2 removed without removing their arms |
| **F11** | 11 factory `ParseReceivedExchange` guards (1.2) | Each class's session exchange is the same in every matrix variant, and none states one in `DescribeSession` (L5), so `aSession.Exchange = X` is always True in the program. Only the unit tests' stub sessions reach the other branch. **FIXED at S2**: the 11 guards and the six test cases are deleted |
| **F12** | `uContestBase.pas:2718` | A reach-1 rule (FISTS) sits in the base's non-virtual `CombineScore` |
| **F13** | `VC.pas:3406` | `ActiveExchangeArray` survives for two log lines (`uADIFExchange:403/413`) |
| **F14** | `Lint-ContestNameTests.ps1` `$TOTAL_FLOOR = 5`, 6 found | S8 removes 4. The floor must fall in the same commit, or the lint fails with "broken parser" |
| **F15** | `MainUnit:9514-9516`; `logdupe:1709-1715` | The SS-shape test duplicates `ExchangeInformation.Precedence`/`.Check`. They are equal once S1 removes `CheckAndChapterOrQTH`, the only other arm that sets `Check` |
| **F16** | inventory section 9.1; `analyses.dead_arms` | (S0a) The "export arms dead by default" table is EMPTY, and not because there are none: it reads `SetHisEx` / `FormatADIFExchangeOfKind` records, and those machines left the scan when their selector became a parameter (`aCtx.SessionExchange`, `aKind`). The same blindness as F1's three unscanned machines. Not fixed at S0a, which judges the machines SHAPE |
| **F17** | `uProgramMain:2701` versus `:2405` | (S0d) `CD.MasterFileExists` is set after the `/MATRIX` halt (and `/EXPORT`'s), so headless runs never open TRMASTER: `CD.GetEntry('W1AW')` answers "not found" while the shipped file holds W1AW. Every TRMASTER-sourced initial exchange is blank in the matrix |
| **F19** | `LogCfg` (once, `uProgramMain:2318`); `uProgramMain:2306-2307` versus `uSettingsEffects:353` | (S2) After F9's fix the `Doing*` answers follow a run-time contest switch, but what start-up DERIVED from them and from the exchange does not: `NumberDifferentMults`, `RemainingMultDisplay`, `Sheet.SheetInitAndLoad`, `SetUpExchangeInformation` and `SetColumnsWidth` run once. A peer's CONTEST line still leaves those describing the previous contest. Not measured on a bench |
| **F20** | `TContestBase.PrefixMultiplierKey` (UBA, SAC, WAEDC, All Asian, OK DX, CQ MM, SAWW, YB DX) versus `ContestSession.DoingPrefixMults` | (S3) The key now asks `Station`, which `ActiveContest` refreshes on every call; whether `SetPrefix` is called at all still asks the session kind, fixed at set-up. They agree unless the entrant's country or continent changes mid-session without a CONTEST change (FoundContest is not re-run for MY CALL): then e.g. a UBA log started outside Belgium and switched to an ON call keeps `DoingPrefixMults` but gets no key. YB DX already read the live `Settings.My.Country` before S3. The end state (part 2, §3) asks the class for both, so this closes then. Not measured on a bench. **CLOSED at S3 part 2 (2026-10-14):** both now read `Station` -- `DoingPrefixMults` is `TContestBase.HasPrefixMultiplier` through `ActiveContest`, and the station-dependent keys ask it. The mid-session change is still not bench-checked |
| **F21** | `TContestBase.DXMultiplierKey` / `CountryMode` / `ListsRemainingDXCountry` (ARRL DX, ARRL 160, All Asian, JIDX, SAC, Helvetia, Croatian, WAG, UBA, WAE, PACC, RDA, ALRS, YU DX, the host-state parties) versus `ContestSession.DoingDXMults` | (S4 part 1) F20's shape, for the DX kind: the key and the remaining-mults filter ask `Station`, refreshed on every `ActiveContest` call, while whether `GetDXQTH` runs and whether the window lists DX countries at all still ask the session kind fixed at set-up. They agree unless the entrant's country, continent or host state changes mid-session without a CONTEST change. The country list is asked once, at set-up, so it cannot drift. Part 2 makes "does this contest count DX" a class answer, as S3 part 2 did for prefixes. Not measured on a bench |
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
