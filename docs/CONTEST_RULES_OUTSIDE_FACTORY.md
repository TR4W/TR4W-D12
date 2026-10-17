# Contest rules outside the contest factory -- an inventory

**GENERATED. Do not edit outside the marked hand-maintained blocks.**
Regenerate with `python tools/contest-rules-inventory/generate.py` (any working
directory). This copy was generated from commit `d329efe9` (2026-10-16).
Owner: `contest-factory`, with `contest-scoring` (the engine side of every row
below), `file-formats` (ADIF and Cabrillo rows) and `lcl-ui` (the UI rows).

**What it answers (NY4I):** every place outside `tr4w/src/contestFactory/`
where code applies a rule that belongs to a SPECIFIC contest -- behaviour that
should live in that contest's class. The worked example is
`MainUnit.ApplyContestSpecificADIFTail`, a `case exch.ceContest of` that
reinterprets imported ADIF per contest.

**Two kinds of text live here.** Everything outside a hand-maintained block is
regenerated from the tree on every run, so its numbers and line numbers are
those of the commit above. The hand-maintained blocks -- the headline
judgements, the seam notes, the bug and dead-code findings (section 7) and the
lint proposal (section 8) -- are judgement: the generator copies them verbatim
and cannot re-check them. Section 9 recomputes the measurements those findings
rest on, so a finding whose number has moved shows up there first.

---

## 1. Summary

### 1.1 By shape

| shape | what it is | sites | table rows | how measured |
|---|---|---:|---:|---|
| 1 | the global `Contest` compared, `in`-tested or cased | **0** in 0 files | 0 | `scan.py` (section 2.1). Rows > sites because a `case` is one site and one row per arm |
| 2 | a contest-typed FIELD or VARIABLE tested: `exch.ceContest`, `rec.ceContest`, `RXData.ceContest`, `SelectedContest` | **5** in 3 files | 5 | `scan.py` |
| 3 | a contest identified by a STRING: contest name/title, a station state, a sponsor or bonus callsign | **9** | 9 | `judgements.SHAPE3`, curated from `scan.string_candidates` (section 2.4) |
| 4 | an `Active*` proxy whose tested value reaches only 1-3 contests by default | **9** of 35 classified | 9 | `scan.classify_proxies` |
| 5 | `FoundContest`'s setup `case Contest of` | 1 case, **0 arms**, 0 contests | 0 | `scan.found_contest_arms` -- its own table, section 5 |

Shape 4 in full: the 22 `Active*` sites (21 comparisons, 1 `case`s) break
into 35 comparison-or-arm records --

| class | records | meaning |
|---|---:|---|
| PROXY, reach 1 | 3 | the tested value reaches exactly ONE contest by default -- a contest rule wearing a disguise |
| PROXY, reach 2-3 | 6 | mostly a CW/SSB pair or a family (ARRL SS, the Field Days, UBA, SAC, REF); **2** of them test a value whose NAME is generic (`ThreePointsPerQSO`, `GridExchange`, `RSTAgeExchange`, ...) and are flagged `GENERIC-NAMED` in the tables -- judge those individually. 0 reach-1 rows carry the same flag |
| PROXY for DUMMYCONTEST | 0 | `NoQSOPointMethod`, the sentinel; dropped |
| SHARED | 16 | reaches 4+ contests -- genuinely shared behaviour, **not a finding**, counted only |
| SHAPE | 0 | an arm of an exchange-SHAPE machine (`judgements.SHAPE_MACHINES`): a data format, kept on purpose by M11 (Q92), **not a finding**, counted only |
| UNUSED | 10 | reaches NO contest: neither a class's trait nor its `DescribeSession` states the value (the settings that could select one were retired at M10 S2) |

### 1.2 By category (table rows; section 4 has every row)

| category | s1 | s2 | s3 | s4 | total |
|---|---:|---:|---:|---:|---:|
| Scoring | 0 | 0 | 0 | 0 | 0 |
| Exchange parsing and validation | 0 | 4 | 1 | 9 | 14 |
| Dupe | 0 | 0 | 0 | 0 | 0 |
| Multipliers | 0 | 0 | 0 | 0 | 0 |
| ADIF import | 0 | 0 | 1 | 0 | 1 |
| ADIF export | 0 | 0 | 1 | 0 | 1 |
| Cabrillo export | 0 | 1 | 6 | 0 | 7 |
| Score, summary and totals | 0 | 0 | 0 | 0 | 0 |
| UI, display and the new-contest dialog | 0 | 0 | 0 | 0 | 0 |
| Setup (FoundContest / LogCfg) | 0 | 0 | 0 | 0 | 0 (+ 0 FoundContest arms, section 5) |
| Networking and score reporting | 0 | 0 | 0 | 0 | 0 |
| Other | 0 | 0 | 0 | 0 | 0 |
| **total** | **0** | **5** | **9** | **9** | **23** (+0) |

### 1.3 Top files (table rows, plus FoundContest's arms)

| file | rows |
|---|---:|
| `trdos/logedit.pas` | 10 |
| `uCabrilloExchange.pas` | 4 |
| `trdos/postunit.pas` | 3 |
| `trdos/logdupe.pas` | 2 |
| `MainUnit.pas` | 1 |
| `uADIFExchange.pas` | 1 |
| `uCallSignRoutines.pas` | 1 |
| `uPOTAReference.pas` | 1 |
| `trdos/fcontest.pas` | 0 (0 setup arms + 0) |

### 1.4 The headline facts

1. **24 of the 187 registered contests still have rules outside the factory.**
   With none: `ALLASIANCW`, `ALLASIANSSB`, `ALRS_UA1DZ_CUP`, `APSPRINT`, `ARCI`, `ARI_DX`, `ARKTIKA_SPRING`, `ARRL10`, `ARRL160`, `ARRLDIGI`, `ARRLDXCW`, `ARRLDXSSB`, `ARRLFIELDDAY`, `ARRLVHFJAN`, `ARRLVHFJUN`, `ARRLVHFSEP`, `ARRL_RTTY_ROUNDUP`, `ArizonaQsoParty`, `BALTIC`, `BATAVIA_FT8`, `BCQP`, `BSCI`, `BWQP`, `CANADA_DAY`, `CANADA_WINTER`, `CIS`, `COLORADOQSOPARTY`, `COUNTYHUNTER`, `CQ160CW`, `CQ160SSB`, `CQM`, `CQMM`, `CQVHF`, `CQWPXCW`, `CQWPXRTTY`, `CQWPXSSB`, `CQWWCW`, `CQWWRTTY`, `CQWWSSB`, `CROATIAN`, `CUPURAL`, `CWOPEN`, `CWOPS`, `DARC10M`, `DARCWAEDCCW`, `DARCWAEDCSSB`, `DARCXMAS`, `DELAWAREQSOPARTY`, `EUDX`, `EUROPEANHFC`, `EUROPEANVHF`, `EUSPRINT_AUTUMN_CW`, `EUSPRINT_AUTUMN_SSB`, `EUSPRINT_SPRING_CW`, `EUSPRINT_SPRING_SSB`, `FLORIDAQSOPARTY`, `FOCMARATHON`, `GACWWWSACW`, `GAGARINCUP`, `GENERALQSO`, `GRIDLOC`, `HADX`, `HELVETIA`, `IDAHOQSOPARTY`, `IN7QPNE`, `INQSOPARTY`, `INTERNETSPRINT`, `IOTA`, `IRTS`, `JALONGPREFECT`, `JTDX`, `KCJ`, `KIDSDAY`, `KINGOFSPAINCW`, `KINGOFSPAINSSB`, `KVP`, `LQP`, `LZDX`, `MAKROTHEN`, `MARCONIMEMORIAL`, `MICHQSOPARTY`, `MINI40`, `MINI80`, `MINITEST`, `MINNQSOPARTY`, `MOQSOPARTY`, `MST`, `MWC`, `NAQSOCW`, `NAQSORTTY`, `NAQSOSSB`, `NASPRINTCW`, `NASPRINTRTTY`, `NCCCSPRINT`, `NCQSOPARTY`, `NEBRASKAQSO`, `NEWENGLANDQSO`, `NYQP`, `NZFIELDDAY`, `OCEANIADXCW`, `OCEANIADXSSB`, `OKDX`, `OKOMSSB`, `OLDNEWYEAR`, `OZHCRVHF`, `PACC`, `PAQSOPARTY`, `PCC`, `QCWA`, `QCWAGOLDEN`, `R9W_UW9WK_MEMORIAL`, `RADIOMEMORY`, `RADIOVHFFD`, `RDA`, `REFCW`, `REFSSB`, `REGION1FIELDDAY`, `REGION1FIELDDAY_RCC_CW`, `REGION1FIELDDAY_RCC_SSB`, `RFASCHAMPIONSHIPCW`, `RSGB18`, `RSGB_ROPOCO_CW`, `RSGB_ROPOCO_SSB`, `RTC`, `RU3AXMEMORIAL`, `RUSSIANDX`, `SACCW`, `SACSSB`, `SALMONRUN`, `SASPRINT`, `SEVENQP`, `SOUTHAMERICANWW`, `SPDX`, `SPRINTSSB`, `SST`, `STEWPERRY`, `TENNESSEEQSOPARTY`, `TENTEN`, `TESLA`, `TEXASQSOPARTY`, `TOEC`, `UA4WCHAMPIONSHIP`, `UBACW`, `UBASSB`, `UCG`, `UKEI`, `UKRAINECHAMPIONSHIP`, `UKRAINIAN`, `UNDX`, `WAG`, `WINTERFIELDDAY`, `WISCONSINQSOPARTY`, `WRTC`, `WWDIGI`, `WWIH`, `WWL`, `WWPMC`, `XMAS`, `YBDX`, `YODX`, `YOTA`, `YOUTHCHAMPIONSHIPRF`, `YUDX`. The per-contest index (section 6)
   lists every site, registered contests first.

*Hand-maintained below -- judgement, not measurement. The generator preserves it verbatim and does not re-check it; its line numbers are as of when it was written.*

<!-- BEGIN HAND-MAINTAINED: headline-facts -->
2. **The factory owns per-QSO scoring (`logstuff.pas:6564`), class and DX-QTH
   validation (`:10920`, `:1518`), the QTH count (`:1999`), ADIF contest-id
   lookup on import, and -- since M4 (2026-10-01), for EVERY contest -- the
   Cabrillo and ADIF exchange columns, the Cabrillo line layout and the ADIF
   contest fields (`EmitADIFContestFields`, `ADIFPowerTag`,
   `WritesADIFContestId`). `FormatsExchange` is gone: PostUnit and uADIF ask
   `ContestIdentity`, and a contest with no export rule gets TContestBase's
   default, the shared arm for its session's exchange.** POTA and ARRL 160
   are still named in PostUnit's ADIF tail, each for a stated reason
   (CONTEST_OWNERSHIP_DESIGN.md 8.2e). Exchange parsing, multipliers, dupes,
   ADIF import, Cabrillo headers and mode string, the summary sheet, totals,
   the UI and session setup are still decided outside it.
3. **SUPERSEDED BY M2 (2026-10-01): `FoundContest`'s head now READS the
   traits**, through `FCONTEST.ApplyContestTraits` -- the operator's statement,
   else `ContestIdentity` (CONTEST_OWNERSHIP_DESIGN.md section 7.9). The arms
   still overwrite after it. What follows is the fact as it stood before M2.
   **The class's TRAITS are read by nobody outside the factory.** `ExchangeKind`,
   `QSOPointMethod`, `InitialExchangeKind` and the four multiplier types are
   overridden 156 times (section 9.2), and no unit outside
   `src/contestFactory/` reads any of them
   (`rg -n -i "\.(ExchangeKind|QSOPointMethod|DomesticMultiplierType|DXMultiplierType|ZoneMultiplierType|PrefixMultiplierType|InitialExchangeKind)\b"`
   outside the factory: zero hits). `FoundContest` sets every `Active*` global
   from `ContestsArray` and its own arms. So the table plus `FoundContest` is
   still the effective definition, and a class trait that disagrees is
   silently ignored -- one does (section 7, D8).
4. **Exporters read `ContestsArray`, not the class, for the contest's
   identity** -- `uADIF.EmitADIFRecord`, `postunit.GetCabrilloTagText`,
   `logsubs2` (lines 2720, 2988), `uGetScores:301`, `uHamScore:403`. Only ADIF
   IMPORT asks the class (`uContestRegistry.FindContestByADIFContestId`). The
   two disagree for 29 registered contests (section 7, D9).
5. ~~**An `Active*` value is a DEFAULT, not a fact.**~~ **NO OPERATOR
   OVERRIDE IS LEFT (M10 S2, 2026-10-14).** The operator's `.cfg` could set
   `EXCHANGE RECEIVED`, `QSO POINT METHOD`, `INITIAL EXCHANGE` and the four
   multiplier commands; all seven are now names in `uCFG.RETIRED_COMMANDS`
   (NY4I, Q4) -- accepted, reported once, no effect. So an `Active*` value is
   the contest's: its trait, then what its class states in `DescribeSession`.
   "Reach" in this document is therefore exact for the seven, not "with no
   operator override". It is still not a proof that an arm is dead.
<!-- END HAND-MAINTAINED: headline-facts -->

---

## 2. Method

**Scope.** `git ls-files 'tr4w/*.pas' 'tr4w/*.inc' 'tr4w/*.lpr'`, minus
`tr4w/include/` (vendored) and `tr4w/test/`, minus `src/contestFactory/`:
**450 files**. Using the tracked list excludes the gitignored `backup/`,
`graphify-out/` and `.claude/worktrees/` copies by construction.

**Parsing.** Every file is first reduced to CODE ONLY by
`tr4w/build/PascalSource.psm1` (`Get-PascalCodeOnlyText`, once with
`-BlankStrings` and once without), which preserves line numbers. Everything
structural is then done on TOKENS, not lines (`pascal.py`): a `case` is parsed
with a nesting counter (`begin`/`case`/`try`/`record`/`asm`/`repeat` open,
`end`/`until` close), so a nested case's arms are not counted as the outer
case's, and a label separated from its colon by a comment is still a label.
The first version treated `repeat` as flat and mis-read two arms of
`logddx.GetRandomDDXCallsign`; that is fixed and was checked by hand.

**The tool** is `tools/contest-rules-inventory/`:

| module | what it does |
|---|---|
| `generate.py` | the entry point: dumps, scans, renders, writes this file CRLF |
| `dump-code-only.ps1` | the two code-only copies, through `PascalSource.psm1` |
| `pascal.py` | tokens, the enclosing routine, operands, the ONE `case` walker |
| `model.py` | `VC.pas` (`ContestType`, `ContestTypeSA`), the factory registry, and each contest's row values as its class states them |
| `scan.py` | shapes 1-5 |
| `analyses.py` | the measurements behind sections 7 and 8 (section 9) |
| `judgements.py` | **the only opinions**: categories, seams, thresholds, the curated shape-3 list |
| `render.py` | this document, and the hand-maintained blocks it preserves |

Intermediates go to `build-out/contest-rules-inventory/` (gitignored), never
into the repository.

### 2.1 Shapes 1 and 2

A `ContestType` member used as a comparison operand, as a member of an `in`
set, or as a `case` label. The other operand decides the shape: the bare
global `Contest` is shape 1, anything else (a field, a parameter, a local) is
shape 2.

- **0 enum names collide with another enum's member** (`analyses.enum_collisions`),
  so a member in code is unambiguous -- **except** where a LOCAL or FIELD
  shares its spelling: `TENTEN` is a string field in `logscp.pas`, `rda` a
  parameter in `tree.pas`/`logstuff.pas`, `pCC` a parameter in
  `uDXLabPathfinder.pas`, `Iota` a property in `uSettingsModel.pas`. Those are
  excluded (a token followed by `:`, `[` or `.`, or preceded by `.`), and so are
  the `if TENTEN <> ''` tests in `logscp.pas` (a `with`-scoped field compared
  with a string, not the enum).
- Shape 1 is 0 `case` + 0 comparisons + 0 `in` tests = **0**.
  At `9acdc5bd` that was exactly the set `Lint-ContestNameTests.ps1 -List`
  printed. The lint has since been widened (`c3841b55`) to count by VALUE
  and one per `case` arm -- sections 9.4 and 9.5 are the comparable figures.
  The lint and this scanner are separate implementations, so a
  disagreement between them is worth a look.

### 2.2 Which contests have a class

`RegisterContest(<enum>, <class>)` in `src/contestFactory/`: **187**
(`model.Registry`, which also walks each class's ancestry). All 187 score through their own chain -- none falls through to `TContestBase`'s zero.

### 2.3 Shape 4 -- who reaches an `Active*` value

The reach of a value is each contest's own statement of it -- the single
value its class's getter returns, else `TContestBase`'s (188 contests;
`ContestsArray`, which held the same values, was deleted at M10 S8)
UNION every `Active* :=` inside `FoundContest`'s arms (0 assignments)
UNION every `aSession.<Kind> :=` its chain's `DescribeSession` states, under any condition
(22 statements in 11 classes; M11 S0a -- before it this
reach could not see `DescribeSession`, and called twelve live records UNUSED).
That over-approximates who uses a value, which is the safe direction for
deciding "only one contest uses this". Values are compared case-insensitively,
because Pascal is: `TWOPOINTSPERQSO` and `TwoPointsPerQSO` are one identifier.

**The thresholds are a judgement, stated as one** (`judgements.FAMILY_MAX`):
reach 1 is unambiguous; reach 2-3 is kept as PROXY because it is almost
always a CW/SSB pair or one sponsor's family; more is SHARED. The reach-2-3
rows whose value has a generic NAME (`judgements.GENERIC`) are flagged in the
tables rather than silently reclassified.

### 2.4 Shape 3 -- what was kept and what was not

`scan.string_candidates` matches every string literal against every contest
identity string (the `ContestTypeSA` spelling, and the class's DisplayName, ADIFContestId,
CabrilloName, DomesticFileName and FriendlyName): **38** hits today, and lists **11** lines
using a contest-name expression. Those are CANDIDATES; `judgements.SHAPE3` is
what was read and kept. The translation tables (`TC_UKRAINE = 'Ukraine'`
matching a DF name), `FoundContest` ASSIGNING a name, and emitting `'POTA'`
inside an already-POTA branch are not tests and were dropped; the lines that
TEST a name are kept. Sponsor and bonus callsigns were found with `rg` for
callsign-shaped literals compared with `Callsign`/`Call`.

Each kept site is located by a pattern and an expected match count, never by
line number, and **the generator fails if a count is not met** -- the code
has moved under a judgement and someone has to read it again. **If the two
candidate counts above change, re-read the candidates**: a new string test
is not added to the tables until a human adds it to `judgements.SHAPE3`.

### 2.5 Categories and seams -- the one judgement step

Each routine is assigned a category and a destination seam by hand, in
`judgements.ROUTINES`; 1 sites override their routine's category
(`judgements.SITE_OVERRIDES`, by pattern). Every other value in the tables is
computed, and **a site in a routine with no judgement stops the generator**
rather than landing in a default category. A seam that exists today is named
as a `TContestBase` virtual; anything else is **"new seam needed"**, and where
`docs/ADDING_A_CONTEST.md` section 6 already reserves a name
(`parseReceivedExchange`, `getReceivedExchangeFields`, `getMultiplierValue`,
`calculateTotalScore`, `getCabrilloHeaders`, `formatSentExchange`) that name
is used and marked `(s6)`.

---

## 3. How to read the tables

- **bold** contest = it has a class (registered). `class?` says whether all,
  none or some of the named contests have one.
- A `case` appears as one row per ARM that names a contest, with the arm's
  line; `@<line>` is the `case` itself.
- Shape-4 rows carry `reach N` -- how many contests reach the tested value by
  default -- and `GENERIC-NAMED` where the value's name is generic.

## 4. The sites, by category

### Scoring (0 rows)

None found.

### Exchange parsing and validation (14 rows)

| file:line | routine | shape | contest(s) -- **bold = has a class** | class? | seam | what |
|---|---|---|---|---|---|---|
| `MainUnit.pas:8072` | LoadinLog | 2 | **RADIOYOC** | all | new seam needed: SessionExchangeState (previous QSO number) | `LegacyContestOf(Contest)` compare |
| `trdos/logdupe.pas:1382` | GetInitialExchangeStringFromContestExchange | 4 | **ALLJA** | all | new seam needed: InitialExchangeFromHistory | reach 1: `AE` = RSTALLJAPrefectureAndPrecedenceExchange |
| `trdos/logdupe.pas:1405` | GetInitialExchangeStringFromContestExchange | 4 | **FISTS** | all | new seam needed: InitialExchangeFromHistory | reach 1: `AE` = RSTQTHNameAndFistsNumberOrPowerExchange |
| `trdos/logedit.pas:2481` | InitialExchangeEntry | 2 | **OZCR_O**, **OZCR_Z** | all | new seam needed: InitialExchangeFromHistory (InitialExchangeKind is the existing trait) | `LegacyContestOf(Contest)` in |
| `trdos/logedit.pas:2499` | InitialExchangeEntry | 2 | **RFCHAMPIONSHIPCW**, **RFCHAMPIONSHIPSSB** | all | new seam needed: InitialExchangeFromHistory (InitialExchangeKind is the existing trait) | `LegacyContestOf(Contest)` in |
| `trdos/logedit.pas:2619` | InitialExchangeEntry | 4 | **ARRLSSCW**, **ARRLSSSSB** | all | new seam needed: InitialExchangeFromHistory (InitialExchangeKind is the existing trait) | reach 2: `AIE` = CheckSectionInitialExchange (arm of case @2332) |
| `trdos/logedit.pas:2750` | InitialExchangeEntry | 4 | **CALQSOPARTY**, **VAQP** | all | new seam needed: InitialExchangeFromHistory (InitialExchangeKind is the existing trait) | reach 2 GENERIC-NAMED: `AE` = QSONumberDomesticOrDXQTHExchange |
| `trdos/logedit.pas:2753` | InitialExchangeEntry | 4 | **CUPRFCW**, **CUPRFDIG**, **CUPRFSSB** | all | new seam needed: InitialExchangeFromHistory (InitialExchangeKind is the existing trait) | reach 3: `AE` = QSONumberAndGridSquare |
| `trdos/logedit.pas:2758` | InitialExchangeEntry | 4 | **NRAUBALTICCW**, **NRAUBALTICSSB**, **OHIOQSOPARTY** | all | new seam needed: InitialExchangeFromHistory (InitialExchangeKind is the existing trait) | reach 3 GENERIC-NAMED: `AE` = RSTQSONumberAndDomesticQTHExchange |
| `trdos/logedit.pas:2759` | InitialExchangeEntry | 4 | **CQIR** | all | new seam needed: InitialExchangeFromHistory (InitialExchangeKind is the existing trait) | reach 1: `AE` = QSONumberAndPossibleDomesticQTHExchange |
| `trdos/logedit.pas:2775` | InitialExchangeEntry | 4 | **ARRLSSCW**, **ARRLSSSSB** | all | new seam needed: InitialExchangeFromHistory (InitialExchangeKind is the existing trait) | reach 2: `AE` = QSONumberPrecedenceCheckDomesticQTHEXchange |
| `trdos/logedit.pas:2787` | InitialExchangeEntry | 2 | **IARU** | all | new seam needed: InitialExchangeFromHistory (InitialExchangeKind is the existing trait) | `LegacyContestOf(Contest)` compare |
| `trdos/logedit.pas:2869` | InitialExchangeEntry | 4 | **JIDXCW**, **JIDXSSB** | all | new seam needed: InitialExchangeFromHistory (InitialExchangeKind is the existing trait) | reach 2: `AE` = RSTPrefectureExchange |
| `uCallSignRoutines.pas:724` | IsAGoodCall | 3 | **RAEM** | all | new seam needed: IsAcceptableCallsign | `Call = 'RAEM'` accepted as a callsign |

### Dupe (0 rows)

None found.

### Multipliers (0 rows)

None found.

### ADIF import (1 rows)

| file:line | routine | shape | contest(s) -- **bold = has a class** | class? | seam | what |
|---|---|---|---|---|---|---|
| `uPOTAReference.pas:163` | ResolvePOTAParkFromADIF | 3 | **POTA** | all | ApplyADIFImport (existing; TContestPOTA's helper, a leaf) | ADIF `SIG = 'POTA'` -- the park from `SIG_INFO` (D5, fixed in `3f9e3f28`); TContestPOTA's leaf |

### ADIF export (1 rows)

| file:line | routine | shape | contest(s) -- **bold = has a class** | class? | seam | what |
|---|---|---|---|---|---|---|
| `uADIFExchange.pas:321` | ADIFSentRSTQSONumberState | 3 | (none by default) | - | GetADIFSentExchange (existing, M11 S9b; TRC Digital has no ContestType) | `ClippedState(aMy) = 'TRC'` (was `cMyState = 'TRC'` until M11 S9b) |

### Cabrillo export (7 rows)

| file:line | routine | shape | contest(s) -- **bold = has a class** | class? | seam | what |
|---|---|---|---|---|---|---|
| `trdos/postunit.pas:3134` | tGenerateLogPortionOfCabrilloFile | 3 | **LABRE** | all | FormatCabrilloReceivedExchange / CabrilloQSOLineFormat / CabrilloModeString (existing; CabrilloModeString M9a) | `Settings.Contest.Name = 'LABRE'` |
| `trdos/postunit.pas:3148` | tGenerateLogPortionOfCabrilloFile | 2 | **CUPRFCW**, **CUPRFSSB** | all | FormatCabrilloReceivedExchange / CabrilloQSOLineFormat / CabrilloModeString (existing; CabrilloModeString M9a) | `LegacyContestOf(Contest)` in |
| `trdos/postunit.pas:3153` | tGenerateLogPortionOfCabrilloFile | 3 | (none by default) | - | FormatCabrilloReceivedExchange / CabrilloQSOLineFormat / CabrilloModeString (existing; CabrilloModeString M9a) | `Settings.Contest.Name = 'EURASIA'` -- see dead code |
| `uCabrilloExchange.pas:554` | CabrilloSentRSTQSONumberState | 3 | (none by default) | - | GetCabrilloSentExchange (existing, M11 S9c; TRC Digital and PGA have no ContestType) | `aMy.MyState = 'TRC'` -- TRC Digital, no ContestType (was `cMyState = 'TRC'` until M11 S9c) |
| `uCabrilloExchange.pas:558` | CabrilloSentRSTQSONumberState | 3 | (none by default) | - | GetCabrilloSentExchange (existing, M11 S9c; TRC Digital and PGA have no ContestType) | `ContestTitle = 'PGA'` -- no ContestType; operator-titled |
| `uCabrilloExchange.pas:792` | CabrilloReceivedRSTQSONumberQTH | 3 | (none by default) | - | GetCabrilloReceivedExchange (existing, M11 S9c; TRC Digital and PGA have no ContestType) | `ContestTitle = 'PGA'` -- no ContestType; operator-titled |
| `uCabrilloExchange.pas:796` | CabrilloReceivedRSTQSONumberQTH | 3 | (none by default) | - | GetCabrilloReceivedExchange (existing, M11 S9c; TRC Digital and PGA have no ContestType) | `aCtx.HisQTH = 'TRC'` (was `csQTHString = 'TRC'` until M11 S9c) |

### Score, summary and totals (0 rows)

None found.

### UI, display and the new-contest dialog (0 rows)

None found.

### Setup (FoundContest / LogCfg) (0 rows)

None found.

### Networking and score reporting (0 rows)

None found.

### Other (0 rows)

None found.

---

## 5. Setup -- `FoundContest`'s `case Contest of` (deleted 2026-10-14, when its last arm moved)

**0 arms naming 0 contests; 0 of those contests have a class**
(`scan.found_contest_arms`). The arm is where a
contest's session is configured, and it is the biggest single block of
contest identity outside the factory. Registered contests are listed first.

What an arm does is tagged by what it assigns: `Active*` (an exchange,
multiplier or point-method override of the `ContestsArray` row), `Settings`
(`Settings.<group>.<name>`), `CQmem` (`SetCQMemoryString` /
`SetEXMemoryString`), `domfile` (the domestic file and `AddDomesticCountry`
family), `band` (`ActiveBand` / `ActiveMode`), and `other:<target>` for
anything else. `calls only` = the arm assigns nothing and only calls
procedures.

*Hand-maintained below -- judgement, not measurement. The generator preserves it verbatim and does not re-check it; its line numbers are as of when it was written.*

<!-- BEGIN HAND-MAINTAINED: setup-seam -->
**Seam: new seam needed -- `ConfigureSession`** (the arm's body, as a virtual
the contest overrides). The `Active*` part of it is already DECLARED on the
class as traits and ignored (section 1.4, fact 3); moving an arm means making
`FoundContest` ask the class for those instead of the table, which is where
the in-state / out-of-state conditionals in section 7, D8 have to be resolved.

**M2 (2026-10-01) did the first half:** the HEAD asks the class
(`FCONTEST.ApplyContestTraits`). The arms are unchanged and still run after it;
the in-state conditionals stay in them until M7 gives the class a station
(`InHostState`). CONTEST_OWNERSHIP_DESIGN.md sections 7.9 and 8.2c.
<!-- END HAND-MAINTAINED: setup-seam -->

| lines | contest(s) -- **bold = has a class** | what the arm assigns |
|---|---|---|

---

## 6. Per-contest index

Every site from sections 4 and 5, by contest. Shape-4 rows are included for
every contest the tested value reaches (reach 1-3).

### 6.1 Registered contests -- rules that should already have moved

**24 of 187.** Sorted by number of sites. Registered contests with
**no** site outside the factory: `ALLASIANCW`, `ALLASIANSSB`, `ALRS_UA1DZ_CUP`, `APSPRINT`, `ARCI`, `ARI_DX`, `ARKTIKA_SPRING`, `ARRL10`, `ARRL160`, `ARRLDIGI`, `ARRLDXCW`, `ARRLDXSSB`, `ARRLFIELDDAY`, `ARRLVHFJAN`, `ARRLVHFJUN`, `ARRLVHFSEP`, `ARRL_RTTY_ROUNDUP`, `ArizonaQsoParty`, `BALTIC`, `BATAVIA_FT8`, `BCQP`, `BSCI`, `BWQP`, `CANADA_DAY`, `CANADA_WINTER`, `CIS`, `COLORADOQSOPARTY`, `COUNTYHUNTER`, `CQ160CW`, `CQ160SSB`, `CQM`, `CQMM`, `CQVHF`, `CQWPXCW`, `CQWPXRTTY`, `CQWPXSSB`, `CQWWCW`, `CQWWRTTY`, `CQWWSSB`, `CROATIAN`, `CUPURAL`, `CWOPEN`, `CWOPS`, `DARC10M`, `DARCWAEDCCW`, `DARCWAEDCSSB`, `DARCXMAS`, `DELAWAREQSOPARTY`, `EUDX`, `EUROPEANHFC`, `EUROPEANVHF`, `EUSPRINT_AUTUMN_CW`, `EUSPRINT_AUTUMN_SSB`, `EUSPRINT_SPRING_CW`, `EUSPRINT_SPRING_SSB`, `FLORIDAQSOPARTY`, `FOCMARATHON`, `GACWWWSACW`, `GAGARINCUP`, `GENERALQSO`, `GRIDLOC`, `HADX`, `HELVETIA`, `IDAHOQSOPARTY`, `IN7QPNE`, `INQSOPARTY`, `INTERNETSPRINT`, `IOTA`, `IRTS`, `JALONGPREFECT`, `JTDX`, `KCJ`, `KIDSDAY`, `KINGOFSPAINCW`, `KINGOFSPAINSSB`, `KVP`, `LQP`, `LZDX`, `MAKROTHEN`, `MARCONIMEMORIAL`, `MICHQSOPARTY`, `MINI40`, `MINI80`, `MINITEST`, `MINNQSOPARTY`, `MOQSOPARTY`, `MST`, `MWC`, `NAQSOCW`, `NAQSORTTY`, `NAQSOSSB`, `NASPRINTCW`, `NASPRINTRTTY`, `NCCCSPRINT`, `NCQSOPARTY`, `NEBRASKAQSO`, `NEWENGLANDQSO`, `NYQP`, `NZFIELDDAY`, `OCEANIADXCW`, `OCEANIADXSSB`, `OKDX`, `OKOMSSB`, `OLDNEWYEAR`, `OZHCRVHF`, `PACC`, `PAQSOPARTY`, `PCC`, `QCWA`, `QCWAGOLDEN`, `R9W_UW9WK_MEMORIAL`, `RADIOMEMORY`, `RADIOVHFFD`, `RDA`, `REFCW`, `REFSSB`, `REGION1FIELDDAY`, `REGION1FIELDDAY_RCC_CW`, `REGION1FIELDDAY_RCC_SSB`, `RFASCHAMPIONSHIPCW`, `RSGB18`, `RSGB_ROPOCO_CW`, `RSGB_ROPOCO_SSB`, `RTC`, `RU3AXMEMORIAL`, `RUSSIANDX`, `SACCW`, `SACSSB`, `SALMONRUN`, `SASPRINT`, `SEVENQP`, `SOUTHAMERICANWW`, `SPDX`, `SPRINTSSB`, `SST`, `STEWPERRY`, `TENNESSEEQSOPARTY`, `TENTEN`, `TESLA`, `TEXASQSOPARTY`, `TOEC`, `UA4WCHAMPIONSHIP`, `UBACW`, `UBASSB`, `UCG`, `UKEI`, `UKRAINECHAMPIONSHIP`, `UKRAINIAN`, `UNDX`, `WAG`, `WINTERFIELDDAY`, `WISCONSINQSOPARTY`, `WRTC`, `WWDIGI`, `WWIH`, `WWL`, `WWPMC`, `XMAS`, `YBDX`, `YODX`, `YOTA`, `YOUTHCHAMPIONSHIPRF`, `YUDX`.

*Hand-maintained below -- judgement, not measurement. The generator preserves it verbatim and does not re-check it; its line numbers are as of when it was written.*

<!-- BEGIN HAND-MAINTAINED: registered-first-reads -->
Worth reading first, because they are the ones the brief named:

- **New York's "DX is not a domestic multiplier"** -- `trdos/logdupe.pas:1276`
  (`DupeAndMultSheet.SetMultFlags`). The same rule, spelled three ways, for
  British Columbia (`:1272`, tests lower-case `'dx'`) and Indiana (`:1280`).
  All three are registered. Seam: `MultiplierValue (s6)`.
- **CQ WW / IARU / ARRL SS / the Field Days in the ADIF tail** --
  `MainUnit.pas:9997` (SS + both Field Days), `:10023` (CQ WW), `:10041`
  (IARU), plus `:9964` (GENERALQSO) and `:10098` (ARRL Digi). All registered.
  These are the IMPORT halves (M5). Their export twins in
  `trdos/postunit.pas` moved onto the classes at M4 (2026-10-01) as
  `EmitADIFContestFields`.
<!-- END HAND-MAINTAINED: registered-first-reads -->

| contest | sites outside the factory, by category |
|---|---|
| ARRLSSCW | **exchange** `trdos/logedit.pas:2619`, `trdos/logedit.pas:2775` |
| ARRLSSSSB | **exchange** `trdos/logedit.pas:2619`, `trdos/logedit.pas:2775` |
| CUPRFCW | **exchange** `trdos/logedit.pas:2753`; **cabrillo-export** `trdos/postunit.pas:3148` |
| CUPRFSSB | **exchange** `trdos/logedit.pas:2753`; **cabrillo-export** `trdos/postunit.pas:3148` |
| ALLJA | **exchange** `trdos/logdupe.pas:1382` |
| CALQSOPARTY | **exchange** `trdos/logedit.pas:2750` |
| CQIR | **exchange** `trdos/logedit.pas:2759` |
| CUPRFDIG | **exchange** `trdos/logedit.pas:2753` |
| FISTS | **exchange** `trdos/logdupe.pas:1405` |
| IARU | **exchange** `trdos/logedit.pas:2787` |
| JIDXCW | **exchange** `trdos/logedit.pas:2869` |
| JIDXSSB | **exchange** `trdos/logedit.pas:2869` |
| LABRE | **cabrillo-export** `trdos/postunit.pas:3134` |
| NRAUBALTICCW | **exchange** `trdos/logedit.pas:2758` |
| NRAUBALTICSSB | **exchange** `trdos/logedit.pas:2758` |
| OHIOQSOPARTY | **exchange** `trdos/logedit.pas:2758` |
| OZCR_O | **exchange** `trdos/logedit.pas:2481` |
| OZCR_Z | **exchange** `trdos/logedit.pas:2481` |
| POTA | **adif-import** `uPOTAReference.pas:163` |
| RADIOYOC | **exchange** `MainUnit.pas:8072` |
| RAEM | **exchange** `uCallSignRoutines.pas:724` |
| RFCHAMPIONSHIPCW | **exchange** `trdos/logedit.pas:2499` |
| RFCHAMPIONSHIPSSB | **exchange** `trdos/logedit.pas:2499` |
| VAQP | **exchange** `trdos/logedit.pas:2750` |

### 6.2 Contests with no class

**0** -- every contest without a class (187 non-sentinel enum values minus
187) appears at least once in section 4 or section 5.
Contests that exist only as an operator-configured name, with no
`ContestType` at all, appear only in the shape-3 rows: **TRC Digital** (`cMyState = 'TRC'`, 3 sites) and **PGA** (`ContestTitle = 'PGA'`, 2 sites).

| contest | sites outside the factory, by category |
|---|---|

---

*Hand-maintained below -- judgement, not measurement. The generator preserves it verbatim and does not re-check it; its line numbers are as of when it was written.*

<!-- BEGIN HAND-MAINTAINED: findings -->
## 7. Findings that look like bugs or dead code

"Dead by default" below means: no contest reaches it with its default
settings, because every contest that would has a class that answers first.
An operator's `EXCHANGE RECEIVED` or `QSO POINT METHOD` can still steer an
UNREGISTERED contest into it (section 1.4, fact 5), so these are dead by
default rather than unreachable -- which matters for how they are removed:
deleting one withdraws a value an operator could select.

### D1. `logstuff.ValidClass` after the class returns -- DELETED at M5b (2026-10-02)

**Gone.** `ValidClass` now asks every contest -- `ExchangeContest`, the active
contest's object else its identity -- and keeps no loop of its own; the four
`ARRLFIELDDAY` / `WINTERFIELDDAY` tests went with it (CONTEST_OWNERSHIP_DESIGN
§8.2g). What follows is the finding as it stood.

`logstuff.pas:10920` asks the class and `Exit`s. `ValidClass` is called only
from `ProcessClassAndDomesticOrDXQTHExchange`, whose two callers
(`logstuff.pas:10260`, the `ClassDomesticOrDXQTHExchange` arm, and
`MainUnit.pas:11429`, the Field Day arm of `ProcessImportedSRX_String`) are
reached only by ARRL Field Day and Winter Field Day, both registered. The
routine's own comment (`:10915`) says the same. So the legacy loop below
`:10929` -- including the four `contest = ARRLFIELDDAY / WINTERFIELDDAY` tests
at `:10937`, `:10938`, `:10966`, `:10970` -- is the shape the Florida Cabrillo
branches had before they were deleted. Removing it lowers `logstuff.pas`'s
lint ceiling from 14 to 10.

### D2. `ValidateDXQTH`'s fallback -- DELETED at M5b (2026-10-02)

**Gone**, with D1: the Field Day DX check asks `ExchangeContest.ValidateDXQTH`
and has no `TempString = 'DX'` chain of its own. The finding as it stood:

`logstuff.pas:1518` asks the class; the `else if TempString = 'DX'` legacy
path at `:1534` is reached only when the class is nil, and the same two
contests are the only ones that get here. Not a contest-name test, so no lint
change; same removal question as D1.

### D3. Ten scoring arms that only registered contests reach -- dead by default

`logstuff.CalculateQSOPoints` hands the QSO to the class and `Exit`s at
`:6564` before `case ActiveQSOPointMethod of` (`:6570`). These arms' point
methods reach only registered contests (section 9.1):

| arm | method | reached by |
|---|---|---|
| `logstuff.pas:6684` | `ARRLDXQSOPointMethod` | ARRLDXCW, ARRLDXSSB |
| `:6708` | `ARRLFieldDayQSOPointMethod` | ARRLFIELDDAY, WINTERFIELDDAY |
| `:6731` | `ARRLDIGIQSOPointMethod` | ARRLDIGI |
| `:7220` | `CQWWQSOPointMethod` | CQWWCW, CQWWSSB |
| `:7562` | `NCQSOPointMethod` | NCQSOPARTY |
| `:7611` | `BCQPQSOPointMethod` | BCQP |
| `:8499` | `SalmonRunQSOPointMethod` | SALMONRUN |
| `:8937` | `AlwaysOnePointPerQSO` | INTERNETSPRINT, YOUTHCHAMPIONSHIPRF |
| `:9369` | `ArktikaSpringQSOPointMethod` | ARKTIKA_SPRING |
| `:9738` | `VAQSOPOINTMETHOD` | VAQP |

The North Carolina arm is the sharpest case: it still awards +50 for seven
callsigns (`'N4T'` .. `'N4L'`, `:7577-7601`), and `uContestNorthCarolinaQP.pas`
records that the sponsor's current rules have no callsign bonus. **This is the
scoring-side twin of the retired Florida Cabrillo branches.** Under NY4I's
2026-10-01 ruling (`docs/CONTEST_OWNERSHIP_DESIGN.md`, which supersedes
`docs/QSO_POINT_METHOD_DESIGN.md`), each contest's class owns its scoring
outright and there are no shared point-method strategies. These ten arms are
now reachable only through an operator's `QSO POINT METHOD` in a classless
contest, so the recommendation there (its Q11) is to delete them together with
the whole case when that setting retires.

`AlwaysOnePointPerQSO` is NOT dead everywhere: `logsubs2.pas:1614` still reads
it to stop dupes being marked (section 4, Dupe), and that rule is live for
both of its registered contests.

### D4. Four export arms pre-empted by `FormatsExchange` -- dead by default

**DELETED AT M4 (2026-10-01).** Every contest formats its own export now, and
the shared arms are TContestBase's default; these two exchanges are run only
by contests that format their own, so an operator who states either for
another contest gets the unhandled marker. Pinned by
`uTestCabrilloExchange.Test_D4ExchangesAreUnhandled`. The record below is the
state at M3.

`uCabrilloExchange.pas:180` and `uADIFExchange.pas:258` hand the exchange to
the class and `Exit` when `FormatsExchange` is True (14 classes). These arms'
exchange types reach only such classes:

| arm | exchange | reached by |
|---|---|---|
| `uCabrilloExchange.pas:274`, `uADIFExchange.pas:326` | `QSONumberPrecedenceCheckDomesticQTHExchange` | ARRLSSCW, ARRLSSSSB |
| `uCabrilloExchange.pas:469`, `uADIFExchange.pas:436` | `ClassDomesticOrDXQTHExchange` | ARRLFIELDDAY, WINTERFIELDDAY |

### D5. BUG -- the POTA ADIF import can never use `SIG` / `SIG_INFO`

**FIXED in `3f9e3f28`** -- the rule is now `logstuff.ResolvePOTAParkFromADIF`,
pinned by `uTestRegexValidators`. The evidence below is the state at
`9acdc5bd`, kept as the record of why.

`MainUnit.pas:10075-10083`, the POTA arm of `ApplyContestSpecificADIFTail`:

```pascal
    POTA:
      if IsValidPOTAPark(temps.POTARef) then
         begin
         if Length(temps.POTARef) = 0 then
            begin
            if AnsiUpperCase(temps.SIG) = 'POTA' then
              if IsValidPOTAPark(temps.SIG_Info) then
```

`IsValidPOTAPark` (`logstuff.pas:11126`) exits False unless the length is 7
or 8, so inside the outer `if` the length is never 0 and the `SIG_INFO` branch
cannot run. An ADIF record that carries the park only as `SIG=POTA` /
`SIG_INFO=K-1234` -- which the header comment of this routine says is a
supported input -- falls to the `else` and is treated as a state. The
intended shape is almost certainly "POTA_REF if valid, else SIG_INFO if
`SIG = POTA` and valid, else a state". POTA has no class; this is a bug in
shared code whichever way the rule moves. **Not reproduced on a real file --
found by reading; an import test with a `SIG`-only record would confirm it.**

### D6. `postunit.pas:2415` -- a no-op arm identical to its `else`

**DELETED AT M4 (2026-10-01)**, with the comment above the case that described
a difference that did not exist. The record below is the state at M3.

`CQ160CW, CQ160SSB, NASPRINTCW, SPRINTSSB, NASPRINTRTTY, NAQSOCW, NAQSOSSB,
NAQSORTTY: ;` in `EmitContestSpecificTailForExport`. The `else` at `:2435` is
also empty, so the arm changes nothing, and the comment above the case
(`:2356`, "A few contests deliberately suppress any location field") describes
a difference that does not exist. It names two registered contests. Harmless;
it is an entry in the lint count that buys nothing.

### D7. String tests that cannot match with default settings

| site | test | why it cannot match by default |
|---|---|---|
| `trdos/logddx.pas:250` | `Settings.Contest.Name = 'Scandinavian Contest'` | `FoundContest` sets `Name` to the contest token, which for SAC is `'SAC-CW'` / `'SAC-SSB'` (`ContestTypeSA`); nothing assigns `'Scandinavian Contest'` |
| `trdos/logstuff.pas:7689`, `trdos/postunit.pas:3058` | `Settings.Contest.Name = 'EURASIA'` | no `ContestType` is spelled `EURASIA`; only an operator's `CONTEST NAME` could produce it |
| `trdos/logstuff.pas:7194` | `Settings.Contest.Title = 'DL-DX-RTTY'` | `SetContestTitle` (`fcontest.pas:2010`) builds `'<year> <name> <call>'`, which never equals a bare contest name; and the arm (`DLRTTY`) reaches no contest by default anyway |
| `trdos/logstuff.pas:8619` | `Settings.Contest.Title = 'YBDXDI-FT8'` then `RXCty = 'XYZ'` | the same title construction; AND `RXCty` is a CTY.DAT country id, and `'XYZ'` does not occur in `target/cty.dat` (`rg -c XYZ` : 0). Two independent reasons it cannot fire |

Each needs a decision rather than a deletion -- they may be deliberate hooks
for an operator-titled contest -- but none of them runs today.

### D8. A class trait that the engine overrides, unconditionally

`uContestARRLFieldDay.GetDXMultiplierType` returns `ARRLDXCC`;
`FoundContest`'s Field Day arm sets `ActiveDXMult := NoDXMults`
(`fcontest.pas:548`), and nothing reads the class value (section 1.4, fact 3).
One of them is wrong, and today it is the class that loses silently.
(Section 9.2: 156 trait overrides checked, 7 disagreements.)

**RESOLVED AT M2 (2026-10-01).** NY4I ruled (design Q1) that Field Day has no
multipliers: the class AND the row now say `NoDXMults`, corrected before the
head began reading the class. Section 9.2 no longer lists it.

The other six are **conditional**, not contradictory -- `FoundContest` picks
an exchange or DX multiplier on `FoundMyStateInDomFile` (in-state versus
out-of-state), and the class states only one branch: Arizona
(`fcontest.pas:495`), California (`:785`, `:791`), Salmon Run (`:1285-1291`),
Texas (`:1483-1490`). A single trait value cannot express these; that is a
design point for `ConfigureSession`, not a typo.

### D9. TR4W's own ADIF export does not re-import to its contest -- 139 contests, 29 of them registered

`uADIF.EmitADIFRecord` (`uADIF.pas:1535-1546`) writes `CONTEST_ID` from
`ContestsArray[].ADIFName`, falling back to the `ContestTypeSA` spelling when
that is blank. Import (`uADIF.pas:977` -> `uContestRegistry.FindContestByADIFContestId`)
matches only the class's `ADIFContestId` -- which defaults to the same
`ADIFName`, blank -- and `FormerADIFContestIds`. So for every contest with a
blank `ADIFName` the exported id resolves to nothing, and `exch.ceContest` is
left unchanged.

- **139 contests** have a blank `ADIFName` (excluding POTA and GENERALQSO,
  which write no `CONTEST_ID`); **29 are registered**, among them CQ WW CW/SSB,
  CQ WPX CW/SSB, ARRL DX CW/SSB, ARRL SS CW/SSB, IARU, NA Sprint CW/RTTY
  (section 9.3). Checked twice: the raw `VC.pas` rows
  for CQ-WW-CW (`:3883`) and IARU-HF (`:3906`) carry `ADIFName:''`, and the
  lookup has no `ContestTypeSA` path.
- **Not a regression.** The lookup before `bf395987` also matched `ADIFName`
  only.
- `uTestADIFRegression.pas:78` pins that `CQ-WW-CW` is EMITTED; nothing pins
  that it imports.
- **This is also a second source of a contest's identity.** Five exporters
  read `ContestsArray` directly (section 1.4, fact 4) while import asks the
  class. The fix belongs in the class (`ADIFContestId`, or the fallback listed
  in `FormerADIFContestIds`, whose own header already describes this fallback
  in the past tense) and in making the exporters ask the class.

### D10. Total-score bonuses have no seam, and live in three places

**RESOLVED at M6 (2026-10-02, ownership design 8.2h)** -- the seam is
`TContestBase.FinalScore` = `CombineScore` + `BonusPoints`. Missouri's stations
are its class's declared data (its live peak-hour tally is a preserved defect,
Q32); the Salmon Run W7DX bonus and the NC sweep are implemented. The
findings below are as written before.

- **Missouri** (registered): the bonus-station check is
  `logdupe.CheckMOQSOPartyBonusStation` (`logdupe.pas:1104`, `'W0MA'`,
  `'K0GQ'`), called from `logsubs2.LogContact:1735` (with the peak-hour count)
  and `MainUnit.LoadinLog:7920`, and applied in `logedit.TotalScore:2995`.
- **Salmon Run** (registered): the W7DX 500-point bonus is implemented
  **nowhere** -- `uContestWashingtonSalmonRun.pas:78-92` says so and why.
- **North Carolina**: see D3.

These three are the concrete demand for `calculateTotalScore`, which
`docs/ADDING_A_CONTEST.md` section 6 reserves.
<!-- END HAND-MAINTAINED: findings -->

---

*Hand-maintained below -- judgement, not measurement. The generator preserves it verbatim and does not re-check it; its line numbers are as of when it was written.*

<!-- BEGIN HAND-MAINTAINED: lint-proposal -->
## 8. What `Lint-ContestNameTests` cannot see, and how to widen it

**Proposals A and B below were ADOPTED in `c3841b55`** -- the lint now counts any
`ContestType` member as an operand (whatever the other operand is) and one per
contest-naming `case` arm; read its header for the rules it settled on. This
section is the reasoning as written at `9acdc5bd`; section 8.4 (shapes 3 and 4)
is still open.

### 8.1 The gaps

| shape | seen by the lint? | why not |
|---|---|---|
| 1 | yes -- 91 | |
| 1, a new ARM of an existing `case Contest of` | **no** | the case is counted once, by design (stated in the lint's header) |
| 2 | **no** | a qualified or non-`Contest` operand is excluded on purpose (`exch.ceContest`, `rec.ceContest`, `SelectedContest`) |
| 3 | **no** | the test is on a string |
| 4 | **no** | the test names an `Active*` value, not a contest |
| 5 | partly | `FoundContest`'s case counts as ONE; its 104 arms do not |

### 8.2 Proposal A -- count shape 2 (do this)

**Rule:** a `ContestType` member other than `DUMMYCONTEST`, used as a
comparison operand, as a member of an `in` set, or as a `case` label --
**whatever the other operand is** -- outside `src/contestFactory/`. This
replaces the operand test the lint makes today with a test on the VALUE, which
is what actually identifies a contest.

How, concretely:

- Read the member list from `VC.pas`'s `ContestType` declaration through
  `PascalSource.psm1`, and **fail closed** if it yields fewer than 150 names or
  if `ContestsArray` does not have one row per member.
- Exclude a member-named token that is a field or declaration (preceded by
  `.`, or followed by `:`, `[` or `.`) and a comparison whose other operand is
  a string literal -- the `TENTEN` / `rda` / `pCC` / `Iota` collisions in
  section 2.1. Put all four in the fixture.
- Count a `case` once, as today.

**Estimated new baseline: 105 in 15 files** (was 91 in 12). Measured by the
same scanner (section 9.4 has the current figures):

| file | today | widened |
|---|---:|---:|
| `MainUnit.pas` | 12 | **14** |
| `trdos/postunit.pas` | 15 | **18** |
| `uADIF.pas` | -- | **4** |
| `uNewContest.pas` | -- | **3** |
| `uExchangeBuilder.pas` | -- | **2** |
| the other ten files | unchanged | unchanged |

### 8.3 Proposal B -- count case ARMS, not cases (consider)

The lint's header gives the reason it counts the `case`: a line regex cannot
find where a case ends. A token-level nesting counter can, and section 2's
scanner does it. Counting arms that name a contest would make a new arm in
`FoundContest` or `ApplyContestSpecificADIFTail` fail the build instead of
passing unseen. The contest-naming arms today number **246** across 9 cases
(`FoundContest` 104, `uNewContest.ApplyContestChoice` 68,
`uNewContest.ApplyIAmIn` 23, `LogCfg.tSetupExchangeNumbers` 14,
`ApplyContestSpecificADIFTail` 13, `uExchangeBuilder.BuildRxExchangeText` 10,
`postunit.EmitContestSpecificTailForExport` 9, `logedit.GetMultArray` 4,
`ProcessImportedSRX_String` 1; section 9.5 has the current figures). The cost is a parser that must be right about
`repeat`/`until` and nested cases -- this audit got `repeat` wrong on its first
pass -- so it wants a fixture as thorough as the lint's existing one.

### 8.4 Shapes 3 and 4 -- a report, not a gate

- **Shape 3** is lintable for its narrow form: `Settings.Contest.Name`,
  `Settings.Contest.Title`, `ContestTitle` or `ContestTypeSA[...]` compared with
  `=`/`<>` or passed to `Pos`. Baseline **11** (section 2.4). Sponsor callsigns
  and station-state tests (`'TRC'`) are not generally lintable.
- **Shape 4** needs the contest table to judge, and its answer moves whenever a
  contest gains a class or `FoundContest` changes an arm. Better as a generated
  report -- the same way `docs/ARCHITECTURE_METRICS.md` is generated -- than as a
  ratchet: a new `if ActiveExchange = <single-contest value>` is the thing to
  catch, and a report listing reach-1 tests by file makes it visible without a
  ceiling that has to be re-derived every time the table changes.
<!-- END HAND-MAINTAINED: lint-proposal -->

---

## 9. Measurements behind sections 7 and 8 (generated)

Recomputed on every run, so a hand-maintained finding can be checked against
the tree without re-deriving it. A finding whose rows have gone from here has
probably been fixed; one whose rows have grown wants re-reading.

### 9.1 Legacy arms dead by default (D3, D4)

A `case ActiveQSOPointMethod of` arm in `CalculateQSOPoints` reached only by
registered contests (the class scores and `Exit`s first). The export half is
empty since M11 S9c: the shared export machines (`uCabrilloExchange` /
`uADIFExchange`) are deleted, and each class states its own columns through
`GetCabrilloSentExchange` (187 classes).

| arm | routine | value | reached by |
|---|---|---|---|

### 9.2 Class traits the engine contradicts (D8) -- retired

Retired at M10 S8 (2026-10-14). It compared each class's trait getters with
the `ContestsArray` row and `FoundContest`'s arms; the arms are gone (M7a)
and the row is deleted, so the class's getter is the only statement left.

### 9.3 Contest identity: what the class says, what the exporters emit (D9) -- retired

Retired at M10 S8. The exporters read the row's names until M1 and the class
since; the row is deleted, so there is nothing left to compare the class with.
`Test_EveryContestResolvesItsOwnADIFId` holds every id to its contest.

### 9.4 Shape 1 against shapes 1 + 2, per file (section 8.2)

Shape 1 (the global `Contest` only): **0** in 0 files. Shapes 1 + 2 (testing
the VALUE rather than the operand): **5** in 3 files. A `case` counts
once here; `Lint-ContestNameTests` counts its contest-naming arms instead (section 9.5).

| file | shape 1 | shapes 1 + 2 |
|---|---:|---:|
| `MainUnit.pas` | -- | **1** |
| `trdos/logedit.pas` | -- | **3** |
| `trdos/postunit.pas` | -- | **1** |

### 9.5 Contest-naming `case` arms (section 8.3)

**0** arms across 0 cases.

| case | routine | shape | contest-naming arms |
|---|---|---|---:|
