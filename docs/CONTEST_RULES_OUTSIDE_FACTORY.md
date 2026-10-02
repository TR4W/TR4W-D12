# Contest rules outside the contest factory -- an inventory

**GENERATED. Do not edit outside the marked hand-maintained blocks.**
Regenerate with `python tools/contest-rules-inventory/generate.py` (any working
directory). This copy was generated from commit `25e25461` (2026-10-02).
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
| 1 | the global `Contest` compared, `in`-tested or cased | **52** in 10 files | 67 | `scan.py` (section 2.1). Rows > sites because a `case` is one site and one row per arm |
| 2 | a contest-typed FIELD or VARIABLE tested: `exch.ceContest`, `rec.ceContest`, `RXData.ceContest`, `SelectedContest` | **10** in 5 files | 110 | `scan.py` |
| 3 | a contest identified by a STRING: contest name/title, a station state, a sponsor or bonus callsign | **22** | 22 | `judgements.SHAPE3`, curated from `scan.string_candidates` (section 2.4) |
| 4 | an `Active*` proxy whose tested value reaches only 1-3 contests by default | **201** of 367 classified | 201 | `scan.classify_proxies` |
| 5 | `FoundContest`'s setup `case Contest of` | 1 case, **104 arms**, 131 contests | 104 | `scan.found_contest_arms` -- its own table, section 5 |

Shape 4 in full: the 127 `Active*` sites (116 comparisons, 11 `case`s) break
into 367 comparison-or-arm records --

| class | records | meaning |
|---|---:|---|
| PROXY, reach 1 | 111 | the tested value reaches exactly ONE contest by default -- a contest rule wearing a disguise |
| PROXY, reach 2-3 | 90 | mostly a CW/SSB pair or a family (ARRL SS, the Field Days, UBA, SAC, REF); **13** of them test a value whose NAME is generic (`ThreePointsPerQSO`, `GridExchange`, `RSTAgeExchange`, ...) and are flagged `GENERIC-NAMED` in the tables -- judge those individually. 2 reach-1 rows carry the same flag |
| PROXY for DUMMYCONTEST | 1 | `NoQSOPointMethod`, the sentinel; dropped |
| SHARED | 107 | reaches 4+ contests -- genuinely shared behaviour, **not a finding**, counted only |
| UNUSED | 58 | reaches NO contest by default -- only an operator's `.cfg` setting can select it (section 1.4) |

### 1.2 By category (table rows; section 4 has every row)

| category | s1 | s2 | s3 | s4 | total |
|---|---:|---:|---:|---:|---:|
| Scoring | 1 | 0 | 9 | 96 | 106 |
| Exchange parsing and validation | 7 | 0 | 1 | 54 | 62 |
| Dupe | 0 | 0 | 0 | 0 | 0 |
| Multipliers | 9 | 0 | 1 | 22 | 32 |
| ADIF import | 0 | 2 | 1 | 0 | 3 |
| ADIF export | 0 | 5 | 1 | 1 | 7 |
| Cabrillo export | 6 | 0 | 6 | 0 | 12 |
| Score, summary and totals | 11 | 0 | 1 | 0 | 12 |
| UI, display and the new-contest dialog | 15 | 92 | 1 | 2 | 110 |
| Setup (FoundContest / LogCfg) | 17 | 0 | 0 | 1 | 18 (+ 104 FoundContest arms, section 5) |
| Networking and score reporting | 1 | 11 | 0 | 0 | 12 |
| Other | 0 | 0 | 1 | 25 | 26 |
| **total** | **67** | **110** | **22** | **201** | **400** (+104) |

### 1.3 Top files (table rows, plus FoundContest's arms)

| file | rows |
|---|---:|
| `trdos/logstuff.pas` | 114 |
| `trdos/fcontest.pas` | 108 (104 setup arms + 4) |
| `uNewContest.pas` | 92 |
| `trdos/logdupe.pas` | 43 |
| `trdos/logedit.pas` | 30 |
| `MainUnit.pas` | 26 |
| `trdos/logddx.pas` | 26 |
| `trdos/postunit.pas` | 19 |
| `trdos/LogCfg.pas` | 14 |
| `uExchangeBuilder.pas` | 11 |

### 1.4 The headline facts

1. **99 of the 102 registered contests still have rules outside the factory.**
   With none: `FLORIDAQSOPARTY`, `MARCONIMEMORIAL`, `MICHQSOPARTY`. The per-contest index (section 6)
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
5. **An `Active*` value is a DEFAULT, not a fact.** The operator's `.cfg` can
   set `EXCHANGE RECEIVED`, `QSO POINT METHOD` and the four multiplier commands
   (`uSettingsEffects.ApplyMultiplierToken`). The one shipped contest config
   that did (`target/dom/Idaho QSO Party.cfg`, borrowing NEQP) no longer does:
   Idaho is `IDAHOQSOPARTY` with a class since 2026-10-01. So "reach" in
   this document means "the contests that reach this value with no operator
   override". That is the right basis for deciding where a rule belongs; it is
   not a proof that an arm is dead.
<!-- END HAND-MAINTAINED: headline-facts -->

---

## 2. Method

**Scope.** `git ls-files 'tr4w/*.pas' 'tr4w/*.inc' 'tr4w/*.lpr'`, minus
`tr4w/include/` (vendored) and `tr4w/test/`, minus `src/contestFactory/`:
**448 files**. Using the tracked list excludes the gitignored `backup/`,
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
| `model.py` | `VC.pas` (`ContestType`, `ContestsArray`, `ContestTypeSA`) and the factory registry |
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
- Shape 1 is 3 `case` + 42 comparisons + 7 `in` tests = **52**.
  At `9acdc5bd` that was exactly the set `Lint-ContestNameTests.ps1 -List`
  printed. The lint has since been widened (`c3841b55`) to count by VALUE
  and one per `case` arm -- sections 9.4 and 9.5 are the comparable figures.
  The lint and this scanner are separate implementations, so a
  disagreement between them is worth a look.

### 2.2 Which contests have a class

`RegisterContest(<enum>, <class>)` in `src/contestFactory/`: **102**
(`model.Registry`, which also walks each class's ancestry). All 102 score through their own chain -- none falls through to `TContestBase`'s zero.

### 2.3 Shape 4 -- who reaches an `Active*` value

The reach of a value is each contest's `ContestsArray` row
(186 enum values against 186 rows, matched by position)
UNION every `Active* :=` inside `FoundContest`'s arms (71 assignments).
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
identity string (the `ContestTypeSA` spelling, and the row's Name, ADIFName,
CABName, DF and FriendlyName): **50** hits today, and lists **37** lines
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

### Scoring (106 rows)

| file:line | routine | shape | contest(s) -- **bold = has a class** | class? | seam | what |
|---|---|---|---|---|---|---|
| `trdos/logstuff.pas:6403` | CalculateQSOPoints | 4 | ALLASIANCW, ALLASIANSSB | none | CalculateQSOPoints (existing) | reach 2: `QP` = AllAsianQSOPointMethod (arm of case @6374) |
| `trdos/logstuff.pas:6453` | CalculateQSOPoints | 4 | ARCI | none | CalculateQSOPoints (existing) | reach 1: `QP` = ARCIQSOPointMethod (arm of case @6374) |
| `trdos/logstuff.pas:6469` | CalculateQSOPoints | 4 | ARI_DX | none | CalculateQSOPoints (existing) | reach 1: `QP` = ARIQSOPointMethod (arm of case @6374) |
| `trdos/logstuff.pas:6488` | CalculateQSOPoints | 4 | **ARRLDXCW**, **ARRLDXSSB** | all | CalculateQSOPoints (existing) | reach 2: `QP` = ARRLDXQSOPointMethod (arm of case @6374) |
| `trdos/logstuff.pas:6512` | CalculateQSOPoints | 4 | **ARRLFIELDDAY**, **IDAHOQSOPARTY**, **WINTERFIELDDAY** | all | CalculateQSOPoints (existing) | reach 3: `QP` = ARRLFieldDayQSOPointMethod (arm of case @6374) |
| `trdos/logstuff.pas:6535` | CalculateQSOPoints | 4 | **ARRLDIGI** | all | CalculateQSOPoints (existing) | reach 1: `QP` = ARRLDIGIQSOPointMethod (arm of case @6374) |
| `trdos/logstuff.pas:6549` | CalculateQSOPoints | 4 | ARRL160 | none | CalculateQSOPoints (existing) | reach 1: `QP` = ARRL160QSOPointMethod (arm of case @6374) |
| `trdos/logstuff.pas:6563` | CalculateQSOPoints | 4 | ARRL10 | none | CalculateQSOPoints (existing) | reach 1: `QP` = ARRL10QSOPointMethod (arm of case @6374) |
| `trdos/logstuff.pas:6580` | CalculateQSOPoints | 4 | ARRLVHFJAN, ARRLVHFJUN, ARRLVHFSEP | none | CalculateQSOPoints (existing) | reach 3: `QP` = ARRLVHFJUNPointMethod (arm of case @6374) |
| `trdos/logstuff.pas:6617` | CalculateQSOPoints | 4 | **ALRS_UA1DZ_CUP** | all | CalculateQSOPoints (existing) | reach 1: `QP` = ALRSUA1DZCupQSOPointMethod (arm of case @6374) |
| `trdos/logstuff.pas:6688` | CalculateQSOPoints | 4 | BALTIC | none | CalculateQSOPoints (existing) | reach 1: `QP` = BalticQSOPointMethod (arm of case @6374) |
| `trdos/logstuff.pas:6718` | CalculateQSOPoints | 4 | BWQP | none | CalculateQSOPoints (existing) | reach 1: `QP` = BWQPQSOPointMethod (arm of case @6374) |
| `trdos/logstuff.pas:6729` | CalculateQSOPoints | 4 | CIS | none | CalculateQSOPoints (existing) | reach 1: `QP` = CISQSOPointMethod (arm of case @6374) |
| `trdos/logstuff.pas:6753` | CalculateQSOPoints | 4 | **CQ160CW**, **CQ160SSB** | all | CalculateQSOPoints (existing) | reach 2: `QP` = CQ160QSOPointMethod (arm of case @6374) |
| `trdos/logstuff.pas:6772` | CalculateQSOPoints | 4 | CQM | none | CalculateQSOPoints (existing) | reach 1: `QP` = CQMQSOPointMethod (arm of case @6374) |
| `trdos/logstuff.pas:6827` | CalculateQSOPoints | 4 | CQVHF | none | CalculateQSOPoints (existing) | reach 1: `QP` = CQVHFQSOPointMethod (arm of case @6374) |
| `trdos/logstuff.pas:6911` | CalculateQSOPoints | 4 | **CQWPXCW**, **CQWPXSSB**, UCG | some: CQWPXCW, CQWPXSSB | CalculateQSOPoints (existing) | reach 3: `QP` = CQWPXQSOPointMethod (arm of case @6374) |
| `trdos/logstuff.pas:6947` | CalculateQSOPoints | 4 | CQWPXRTTY | none | CalculateQSOPoints (existing) | reach 1: `QP` = CQWPXRTTYQSOPointMethod (arm of case @6374) |
| `trdos/logstuff.pas:6998` | CalculateQSOPoints | 3 | (none by default) | - | CalculateQSOPoints (existing) | `Settings.Contest.Title = 'DL-DX-RTTY'` in the DLRTTY arm -- see dead code |
| `trdos/logstuff.pas:7024` | CalculateQSOPoints | 4 | **CQWWCW**, **CQWWSSB** | all | CalculateQSOPoints (existing) | reach 2: `QP` = CQWWQSOPointMethod (arm of case @6374) |
| `trdos/logstuff.pas:7043` | CalculateQSOPoints | 4 | CQWWRTTY, WWIH | none | CalculateQSOPoints (existing) | reach 2: `QP` = CQWWRTTYQSOPointMethod (arm of case @6374) |
| `trdos/logstuff.pas:7057` | CalculateQSOPoints | 4 | **CROATIAN** | all | CalculateQSOPoints (existing) | reach 1: `QP` = CroatianQSOPointMethod (arm of case @6374) |
| `trdos/logstuff.pas:7141` | CalculateQSOPoints | 4 | REGION1FIELDDAY | none | CalculateQSOPoints (existing) | reach 1: `QP` = EuropeanFieldDayQSOPointMethod (arm of case @6374) |
| `trdos/logstuff.pas:7297` | CalculateQSOPoints | 4 | **FOCMARATHON** | all | CalculateQSOPoints (existing) | reach 1: `QP` = FOCMarathonQSOPointMethod (arm of case @6374) |
| `trdos/logstuff.pas:7299` | CalculateQSOPoints | 3 | **FOCMARATHON** | all | CalculateQSOPoints (existing) | bonus callsign `'G4FOC'` |
| `trdos/logstuff.pas:7310` | CalculateQSOPoints | 4 | RADIOVHFFD | none | CalculateQSOPoints (existing) | reach 1: `QP` = RadioVHFFDQSOPointMethod (arm of case @6374) |
| `trdos/logstuff.pas:7342` | CalculateQSOPoints | 4 | MAKROTHEN | none | CalculateQSOPoints (existing) | reach 1: `QP` = MakrothenQSOPointMethod (arm of case @6374) |
| `trdos/logstuff.pas:7368` | CalculateQSOPoints | 4 | **NCQSOPARTY** | all | CalculateQSOPoints (existing) | reach 1: `QP` = NCQSOPointMethod (arm of case @6374) |
| `trdos/logstuff.pas:7383` | CalculateQSOPoints | 3 | **NCQSOPARTY** | all | CalculateQSOPoints (existing) | seven bonus callsigns `'N4T'`..`'N4L'` -- arm is dead, see dead code |
| `trdos/logstuff.pas:7417` | CalculateQSOPoints | 4 | **BCQP** | all | CalculateQSOPoints (existing) | reach 1: `QP` = BCQPQSOPointMethod (arm of case @6374) |
| `trdos/logstuff.pas:7431` | CalculateQSOPoints | 4 | IN7QPNE, **PAQSOPARTY** | some: PAQSOPARTY | CalculateQSOPoints (existing) | reach 2: `QP` = PAQSOPointMethod (arm of case @6374) |
| `trdos/logstuff.pas:7468` | CalculateQSOPoints | 4 | **OZHCRVHF** | all | CalculateQSOPoints (existing) | reach 1: `QP` = OZHCRVHFQSOPointMethod (arm of case @6374) |
| `trdos/logstuff.pas:7490` | CalculateQSOPoints | 4 | EUROPEANVHF | none | CalculateQSOPoints (existing) | reach 1: `QP` = EuropeanVHFQSOPointMethod (arm of case @6374) |
| `trdos/logstuff.pas:7495` | CalculateQSOPoints | 3 | (none by default) | - | CalculateQSOPoints (existing) | `Settings.Contest.Name = 'EURASIA'` in the EuropeanVHF arm -- see dead code |
| `trdos/logstuff.pas:7531` | CalculateQSOPoints | 4 | TESLA | none | CalculateQSOPoints (existing) | reach 1: `QP` = TeslaQSOPointMethod (arm of case @6374) |
| `trdos/logstuff.pas:7579` | CalculateQSOPoints | 4 | FISTS | none | CalculateQSOPoints (existing) | reach 1: `QP` = FistsQSOPointMethod (arm of case @6374) |
| `trdos/logstuff.pas:7589` | CalculateQSOPoints | 4 | HADX | none | CalculateQSOPoints (existing) | reach 1: `QP` = HADXQSOPointMethod (arm of case @6374) |
| `trdos/logstuff.pas:7610` | CalculateQSOPoints | 3 | (none by default) | - | CalculateQSOPoints (existing) | `DomesticQTH = 'TRC'` in the TRCDIGITAL arm |
| `trdos/logstuff.pas:7622` | CalculateQSOPoints | 3 | (none by default) | - | CalculateQSOPoints (existing) | `Settings.My.State = 'TRC'` |
| `trdos/logstuff.pas:7656` | CalculateQSOPoints | 4 | YUDX | none | CalculateQSOPoints (existing) | reach 1: `QP` = YUDXQSOPointMethod (arm of case @6374) |
| `trdos/logstuff.pas:7674` | CalculateQSOPoints | 4 | **UKEI** | all | CalculateQSOPoints (existing) | reach 1: `QP` = UKEIQSOPointMethod (arm of case @6374) |
| `trdos/logstuff.pas:7734` | CalculateQSOPoints | 4 | MWC | none | CalculateQSOPoints (existing) | reach 1: `QP` = MWCQP (arm of case @6374) |
| `trdos/logstuff.pas:7750` | CalculateQSOPoints | 4 | HELVETIA | none | CalculateQSOPoints (existing) | reach 1: `QP` = HelvetiaQSOPointMethod (arm of case @6374) |
| `trdos/logstuff.pas:7764` | CalculateQSOPoints | 4 | BSCI | none | CalculateQSOPoints (existing) | reach 1: `QP` = BSCIQSOPointMethod (arm of case @6374) |
| `trdos/logstuff.pas:7806` | CalculateQSOPoints | 4 | **IARU**, OZCR_Z | some: IARU | CalculateQSOPoints (existing) | reach 2: `QP` = IARUQSOPointMethod (arm of case @6374) |
| `trdos/logstuff.pas:7886` | CalculateQSOPoints | 4 | **IOTA** | all | CalculateQSOPoints (existing) | reach 1: `QP` = IOTAQSOPointMethod (arm of case @6374) |
| `trdos/logstuff.pas:7921` | CalculateQSOPoints | 4 | JIDXCW, JIDXSSB | none | CalculateQSOPoints (existing) | reach 2: `QP` = JapanInternationalDXQSOPointMethod (arm of case @6374) |
| `trdos/logstuff.pas:7994` | CalculateQSOPoints | 4 | KCJ | none | CalculateQSOPoints (existing) | reach 1: `QP` = KCJQSOPointMethod (arm of case @6374) |
| `trdos/logstuff.pas:8028` | CalculateQSOPoints | 4 | **NZFIELDDAY** | all | CalculateQSOPoints (existing) | reach 1: `QP` = NZFieldDayQSOPointMethod (arm of case @6374) |
| `trdos/logstuff.pas:8053` | CalculateQSOPoints | 4 | **OKDX** | all | CalculateQSOPoints (existing) | reach 1: `QP` = OKDXQSOPointMethod (arm of case @6374) |
| `trdos/logstuff.pas:8099` | CalculateQSOPoints | 4 | OKOMSSB | none | CalculateQSOPoints (existing) | reach 1: `QP` = OKOMSSBQSOPointMethod (arm of case @6374) |
| `trdos/logstuff.pas:8138` | CalculateQSOPoints | 4 | RAEM | none | CalculateQSOPoints (existing) | reach 1: `QP` = RAEMQSOPointMethod (arm of case @6374) |
| `trdos/logstuff.pas:8150` | CalculateQSOPoints | 3 | RAEM | none | CalculateQSOPoints (existing) | special callsign `'RAEM'` |
| `trdos/logstuff.pas:8165` | CalculateQSOPoints | 4 | **CANADA_DAY**, **CANADA_WINTER** | all | CalculateQSOPoints (existing) | reach 2: `QP` = RACQSOPointMethod (arm of case @6374) |
| `trdos/logstuff.pas:8197` | CalculateQSOPoints | 4 | RSGB18 | none | CalculateQSOPoints (existing) | reach 1: `QP` = RSGB160Method (arm of case @6374) |
| `trdos/logstuff.pas:8229` | CalculateQSOPoints | 4 | RDA | none | CalculateQSOPoints (existing) | reach 1: `QP` = RDAQSOPointMethod (arm of case @6374) |
| `trdos/logstuff.pas:8263` | CalculateQSOPoints | 4 | **RU3AXMEMORIAL**, **RUSSIANDX** | all | CalculateQSOPoints (existing) | reach 2: `QP` = RussianDXQSOPointMethod (arm of case @6374) |
| `trdos/logstuff.pas:8300` | CalculateQSOPoints | 1 | **RU3AXMEMORIAL** | all | CalculateQSOPoints (existing) | `Contest` compare |
| `trdos/logstuff.pas:8307` | CalculateQSOPoints | 4 | **SALMONRUN** | all | CalculateQSOPoints (existing) | reach 1: `QP` = SalmonRunQSOPointMethod (arm of case @6374) |
| `trdos/logstuff.pas:8319` | CalculateQSOPoints | 4 | **SACCW**, **SACSSB** | all | CalculateQSOPoints (existing) | reach 2: `QP` = ScandinavianQSOPointMethod (arm of case @6374) |
| `trdos/logstuff.pas:8359` | CalculateQSOPoints | 4 | YBDX | none | CalculateQSOPoints (existing) | reach 1: `QP` = IndonesianQSOPointMethod (arm of case @6374) |
| `trdos/logstuff.pas:8398` | CalculateQSOPoints | 4 | **BATAVIA_FT8** | all | CalculateQSOPoints (existing) | reach 1: `QP` = YBFT8QP (arm of case @6374) |
| `trdos/logstuff.pas:8427` | CalculateQSOPoints | 3 | **BATAVIA_FT8** | all | CalculateQSOPoints (existing) | `Settings.Contest.Title = 'YBDXDI-FT8'` in the YBFT8QP arm -- see dead code |
| `trdos/logstuff.pas:8445` | CalculateQSOPoints | 4 | SOUTHAMERICANWW | none | CalculateQSOPoints (existing) | reach 1: `QP` = SouthAmericanWWQSOPointMethod (arm of case @6374) |
| `trdos/logstuff.pas:8468` | CalculateQSOPoints | 4 | STEWPERRY | none | CalculateQSOPoints (existing) | reach 1: `QP` = StewPerryQSOPointMethod (arm of case @6374) |
| `trdos/logstuff.pas:8489` | CalculateQSOPoints | 4 | **WWDIGI** | all | CalculateQSOPoints (existing) | reach 1: `QP` = WWDigiQP (arm of case @6374) |
| `trdos/logstuff.pas:8496` | CalculateQSOPoints | 4 | RTC | none | CalculateQSOPoints (existing) | reach 1: `QP` = RTCQSOPointMethod (arm of case @6374) |
| `trdos/logstuff.pas:8533` | CalculateQSOPoints | 4 | TENTEN | none | CalculateQSOPoints (existing) | reach 1: `QP` = TenTenQSOPointMethod (arm of case @6374) |
| `trdos/logstuff.pas:8543` | CalculateQSOPoints | 4 | TOEC | none | CalculateQSOPoints (existing) | reach 1: `QP` = TOECQSOPointMethod (arm of case @6374) |
| `trdos/logstuff.pas:8559` | CalculateQSOPoints | 4 | **UBACW**, **UBASSB** | all | CalculateQSOPoints (existing) | reach 2: `QP` = UBAQSOPointMethod (arm of case @6374) |
| `trdos/logstuff.pas:8607` | CalculateQSOPoints | 4 | **UKRAINIAN** | all | CalculateQSOPoints (existing) | reach 1: `QP` = UkrainianQSOPointMethod (arm of case @6374) |
| `trdos/logstuff.pas:8636` | CalculateQSOPoints | 4 | OCEANIADXCW, OCEANIADXSSB | none | CalculateQSOPoints (existing) | reach 2: `QP` = VKZLQSOPointMethod (arm of case @6374) |
| `trdos/logstuff.pas:8653` | CalculateQSOPoints | 4 | **WAG** | all | CalculateQSOPoints (existing) | reach 1: `QP` = WAGQSOPointMethod (arm of case @6374) |
| `trdos/logstuff.pas:8681` | CalculateQSOPoints | 4 | **DARCWAEDCCW**, **DARCWAEDCSSB** | all | CalculateQSOPoints (existing) | reach 2: `QP` = WAEQSOPointMethod (arm of case @6374) |
| `trdos/logstuff.pas:8700` | CalculateQSOPoints | 4 | WWL | none | CalculateQSOPoints (existing) | reach 1: `QP` = WWLQSOPointMethod (arm of case @6374) |
| `trdos/logstuff.pas:8723` | CalculateQSOPoints | 4 | YODX | none | CalculateQSOPoints (existing) | reach 1: `QP` = YODXQSOPointMethod (arm of case @6374) |
| `trdos/logstuff.pas:8745` | CalculateQSOPoints | 4 | **INTERNETSPRINT**, **YOUTHCHAMPIONSHIPRF** | all | CalculateQSOPoints (existing) | reach 2 GENERIC-NAMED: `QP` = AlwaysOnePointPerQSO (arm of case @6374) |
| `trdos/logstuff.pas:8748` | CalculateQSOPoints | 4 | **CALQSOPARTY**, RADIOYOC, SPDX | some: CALQSOPARTY | CalculateQSOPoints (existing) | reach 3 GENERIC-NAMED: `QP` = ThreePointsPerQSO (arm of case @6374) |
| `trdos/logstuff.pas:8749` | CalculateQSOPoints | 4 | RSGB_ROPOCO_CW, RSGB_ROPOCO_SSB | none | CalculateQSOPoints (existing) | reach 2 GENERIC-NAMED: `QP` = TenPointsPerQSO (arm of case @6374) |
| `trdos/logstuff.pas:8813` | CalculateQSOPoints | 4 | **CUPRFCW**, **CUPRFDIG**, **CUPRFSSB** | all | CalculateQSOPoints (existing) | reach 3: `QP` = CupRFMethod (arm of case @6374) |
| `trdos/logstuff.pas:8857` | CalculateQSOPoints | 4 | UA4WCHAMPIONSHIP | none | CalculateQSOPoints (existing) | reach 1: `QP` = UA4WMethod (arm of case @6374) |
| `trdos/logstuff.pas:8908` | CalculateQSOPoints | 4 | **RFCHAMPIONSHIPCW**, **RFCHAMPIONSHIPSSB** | all | CalculateQSOPoints (existing) | reach 2: `QP` = ChampionshipRFMethod (arm of case @6374) |
| `trdos/logstuff.pas:8930` | CalculateQSOPoints | 4 | **UKRAINECHAMPIONSHIP** | all | CalculateQSOPoints (existing) | reach 1: `QP` = ChampionshipUkrMethod (arm of case @6374) |
| `trdos/logstuff.pas:8940` | CalculateQSOPoints | 4 | WWPMC | none | CalculateQSOPoints (existing) | reach 1: `QP` = WWPMCQSOPointMethod (arm of case @6374) |
| `trdos/logstuff.pas:8960` | CalculateQSOPoints | 4 | JTDX | none | CalculateQSOPoints (existing) | reach 1: `QP` = JTDXQSOPointMethod (arm of case @6374) |
| `trdos/logstuff.pas:9001` | CalculateQSOPoints | 4 | **LABRE** | all | CalculateQSOPoints (existing) | reach 1: `QP` = LABREQSOPointMethod (arm of case @6374) |
| `trdos/logstuff.pas:9039` | CalculateQSOPoints | 4 | **LZDX** | all | CalculateQSOPoints (existing) | reach 1: `QP` = LZDXQSOPointMethod (arm of case @6374) |
| `trdos/logstuff.pas:9072` | CalculateQSOPoints | 4 | OLDNEWYEAR | none | CalculateQSOPoints (existing) | reach 1: `QP` = OldNewYearQSOPointMethod (arm of case @6374) |
| `trdos/logstuff.pas:9092` | CalculateQSOPoints | 4 | RFASCHAMPIONSHIPCW | none | CalculateQSOPoints (existing) | reach 1: `QP` = ChampionshipRFASMethod (arm of case @6374) |
| `trdos/logstuff.pas:9108` | CalculateQSOPoints | 4 | REGION1FIELDDAY_RCC_CW, REGION1FIELDDAY_RCC_SSB | none | CalculateQSOPoints (existing) | reach 2: `QP` = RegionOneFieldDayRCCQSOPointMethod (arm of case @6374) |
| `trdos/logstuff.pas:9147` | CalculateQSOPoints | 4 | GACWWWSACW | none | CalculateQSOPoints (existing) | reach 1: `QP` = GACWWWSACWQSOPointMethod (arm of case @6374) |
| `trdos/logstuff.pas:9168` | CalculateQSOPoints | 4 | **LQP** | all | CalculateQSOPoints (existing) | reach 1: `QP` = LQPQSOPointMethod (arm of case @6374) |
| `trdos/logstuff.pas:9171` | CalculateQSOPoints | 3 | **LQP** | all | CalculateQSOPoints (existing) | `Name = 'LOCUST'` / `Callsign = 'K6VVA'` |
| `trdos/logstuff.pas:9177` | CalculateQSOPoints | 4 | **ARKTIKA_SPRING** | all | CalculateQSOPoints (existing) | reach 1: `QP` = ArktikaSpringQSOPointMethod (arm of case @6374) |
| `trdos/logstuff.pas:9189` | CalculateQSOPoints | 4 | REFCW, REFSSB | none | CalculateQSOPoints (existing) | reach 2: `QP` = REFQSOPointMethod (arm of case @6374) |
| `trdos/logstuff.pas:9206` | CalculateQSOPoints | 4 | RADIOMEMORY | none | CalculateQSOPoints (existing) | reach 1: `QP` = RadioMemoryQSOPointMethod (arm of case @6374) |
| `trdos/logstuff.pas:9221` | CalculateQSOPoints | 4 | **PCC** | all | CalculateQSOPoints (existing) | reach 1: `QP` = PCCQSOPointMethod (arm of case @6374) |
| `trdos/logstuff.pas:9251` | CalculateQSOPoints | 4 | UNDX | none | CalculateQSOPoints (existing) | reach 1: `QP` = UNDXQSOPointMethod (arm of case @6374) |
| `trdos/logstuff.pas:9273` | CalculateQSOPoints | 4 | KINGOFSPAINCW, KINGOFSPAINSSB | none | CalculateQSOPoints (existing) | reach 2: `QP` = KingOfSpainQSOPointMethod (arm of case @6374) |
| `trdos/logstuff.pas:9292` | CalculateQSOPoints | 4 | GAGARINCUP | none | CalculateQSOPoints (existing) | reach 1: `QP` = GagarinCupQSOPointMethod (arm of case @6374) |
| `trdos/logstuff.pas:9331` | CalculateQSOPoints | 4 | CQMM | none | CalculateQSOPoints (existing) | reach 1: `QP` = CQMMQSOPointMethod (arm of case @6374) |
| `trdos/logstuff.pas:9389` | CalculateQSOPoints | 4 | R9W_UW9WK_MEMORIAL | none | CalculateQSOPoints (existing) | reach 1: `QP` = R9WUW9WKMemorialQSOPointMethod (arm of case @6374) |
| `trdos/logstuff.pas:9400` | CalculateQSOPoints | 4 | WRTC | none | CalculateQSOPoints (existing) | reach 1: `QP` = WRTCQSOPointMethod (arm of case @6374) |
| `trdos/logstuff.pas:9546` | CalculateQSOPoints | 4 | **VAQP** | all | CalculateQSOPoints (existing) | reach 1: `QP` = VAQSOPOINTMETHOD (arm of case @6374) |
| `trdos/logstuff.pas:9562` | CalculateQSOPoints | 4 | EUDX, IRTS | none | CalculateQSOPoints (existing) | reach 2: `QP` = EUDXQSOPOINTMETHOD (arm of case @6374) |
| `trdos/logstuff.pas:9620` | CalculateQSOPoints | 4 | YOTA | none | CalculateQSOPoints (existing) | reach 1: `QP` = YOTAQSOPointMethod (arm of case @6374) |

### Exchange parsing and validation (62 rows)

| file:line | routine | shape | contest(s) -- **bold = has a class** | class? | seam | what |
|---|---|---|---|---|---|---|
| `MainUnit.pas:928` | ctyLocateCallStripRover | 4 | **COUNTYHUNTER** | all | new seam needed: RoverCallRules | reach 1: `AE` = RSTQTHExchange |
| `MainUnit.pas:969` | DetectRoverSlashInCall | 4 | **COUNTYHUNTER** | all | new seam needed: RoverCallRules | reach 1: `AE` = RSTQTHExchange |
| `MainUnit.pas:2052` | ReturnInSAPOpMode | 4 | **COUNTYHUNTER** | all | new seam needed: RoverCallRules | reach 1: `AE` = RSTQTHEXCHANGE |
| `MainUnit.pas:4045` | ExchangeWindowChange | 4 | POTA | none | new seam needed: ReceivedExchangeFields (s6) | reach 1 GENERIC-NAMED: `AE` = RSTAndPOTAPark |
| `MainUnit.pas:7096` | ParametersOkay | 4 | BWQP, **GENERALQSO**, POTA | some: GENERALQSO | new seam needed: ValidateExchange | reach 3 GENERIC-NAMED: `AE` = RSTNameAndQTHExchange, RSTAndPOTAPark |
| `MainUnit.pas:7251` | ParametersOkay | 4 | **UBACW**, **UBASSB** | all | new seam needed: ValidateExchange | reach 2: `Pxm` = BelgiumPrefixes (arm of case @7250) |
| `MainUnit.pas:7255` | ParametersOkay | 4 | **SACCW**, **SACSSB** | all | new seam needed: ValidateExchange | reach 2: `Pxm` = SACDistricts (arm of case @7250) |
| `MainUnit.pas:7256` | ParametersOkay | 4 | YBDX | none | new seam needed: ValidateExchange | reach 1: `Pxm` = IndonesianDistricts (arm of case @7250) |
| `MainUnit.pas:7259` | ParametersOkay | 1 | YBDX | none | new seam needed: ValidateExchange | `Contest` compare |
| `MainUnit.pas:7265` | ParametersOkay | 4 | CQMM, **SASPRINT**, SOUTHAMERICANWW | some: SASPRINT | new seam needed: ValidateExchange | reach 3: `Pxm` = SouthAmericanPrefixes (arm of case @7250) |
| `MainUnit.pas:7269` | ParametersOkay | 4 | SOUTHAMERICANWW | none | new seam needed: ValidateExchange | reach 1: `Pxm` = NonSouthAmericanPrefixes (arm of case @7250) |
| `MainUnit.pas:8018` | LoadinLog | 1 | RADIOYOC | none | new seam needed: SessionExchangeState (previous QSO number) | `contest` compare |
| `trdos/logdom.pas:224` | DomQTHTableObject.GetDomQTH | 4 | **ALRS_UA1DZ_CUP**, RDA | some: ALRS_UA1DZ_CUP | new seam needed: ParseDomesticQTH | reach 2: `DM` = RDADistrict |
| `trdos/logdom.pas:247` | DomQTHTableObject.GetDomQTH | 4 | **DARC10M**, **WAG** | all | new seam needed: ParseDomesticQTH | reach 2: `DM` = DOKCodes |
| `trdos/logdom.pas:263` | DomQTHTableObject.GetDomQTH | 4 | **IOTA** | all | new seam needed: ParseDomesticQTH | reach 1: `DM` = IOTADomestic |
| `trdos/logdupe.pas:1647` | SetUpExchangeInformation | 4 | **ARRLFIELDDAY**, **WINTERFIELDDAY** | all | new seam needed: ReceivedExchangeFields (s6) (which fields the exchange carries) | reach 2: `AE` = ClassDomesticOrDXQTHExchange (arm of case @1639) |
| `trdos/logdupe.pas:1653` | SetUpExchangeInformation | 4 | **KIDSDAY** | all | new seam needed: ReceivedExchangeFields (s6) (which fields the exchange carries) | reach 1: `AE` = KidsDayExchange (arm of case @1639) |
| `trdos/logdupe.pas:1658` | SetUpExchangeInformation | 4 | CQMM, SOUTHAMERICANWW | none | new seam needed: ReceivedExchangeFields (s6) (which fields the exchange carries) | reach 2: `AE` = RSTAndContinentExchange (arm of case @1639) |
| `trdos/logdupe.pas:1664` | SetUpExchangeInformation | 4 | TENTEN | none | new seam needed: ReceivedExchangeFields (s6) (which fields the exchange carries) | reach 1: `AE` = NameQTHAndPossibleTenTenNumber (arm of case @1639) |
| `trdos/logdupe.pas:1677` | SetUpExchangeInformation | 4 | **GRIDLOC** | all | new seam needed: ReceivedExchangeFields (s6) (which fields the exchange carries) | reach 1: `AE` = NameAndPossibleGridSquareExchange (arm of case @1639) |
| `trdos/logdupe.pas:1683` | SetUpExchangeInformation | 4 | **NZFIELDDAY** | all | new seam needed: ReceivedExchangeFields (s6) (which fields the exchange carries) | reach 1: `AE` = NZFieldDayExchange (arm of case @1639) |
| `trdos/logdupe.pas:1690` | SetUpExchangeInformation | 4 | RAEM, RFASCHAMPIONSHIPCW | none | new seam needed: ReceivedExchangeFields (s6) (which fields the exchange carries) | reach 2: `AE` = QSONumberAndCoordinatesSum, QSONumberAndGeoCoordinates (arm of case @1639) |
| `trdos/logdupe.pas:1696` | SetUpExchangeInformation | 4 | RADIOYOC | none | new seam needed: ReceivedExchangeFields (s6) (which fields the exchange carries) | reach 1: `AE` = QSONumberAndPreviousQSONumber (arm of case @1639) |
| `trdos/logdupe.pas:1702` | SetUpExchangeInformation | 4 | R9W_UW9WK_MEMORIAL, **RFCHAMPIONSHIPCW**, **RFCHAMPIONSHIPSSB** | some: RFCHAMPIONSHIPCW, RFCHAMPIONSHIPSSB | new seam needed: ReceivedExchangeFields (s6) (which fields the exchange carries) | reach 3: `AE` = QSONumberAndZone (arm of case @1639) |
| `trdos/logdupe.pas:1721` | SetUpExchangeInformation | 4 | **QCWA**, **QCWAGOLDEN** | all | new seam needed: ReceivedExchangeFields (s6) (which fields the exchange carries) | reach 2: `AE` = QSONumberNameChapterAndQTHExchange (arm of case @1639) |
| `trdos/logdupe.pas:1736` | SetUpExchangeInformation | 4 | **ARRLSSCW**, **ARRLSSSSB** | all | new seam needed: ReceivedExchangeFields (s6) (which fields the exchange carries) | reach 2: `AE` = QSONumberPrecedenceCheckDomesticQTHExchange (arm of case @1639) |
| `trdos/logdupe.pas:1744` | SetUpExchangeInformation | 4 | **YOUTHCHAMPIONSHIPRF** | all | new seam needed: ReceivedExchangeFields (s6) (which fields the exchange carries) | reach 1: `AE` = AgeAndQSONumberExchange (arm of case @1639) |
| `trdos/logdupe.pas:1755` | SetUpExchangeInformation | 4 | POTA | none | new seam needed: ReceivedExchangeFields (s6) (which fields the exchange carries) | reach 1 GENERIC-NAMED: `AE` = RSTAndPOTAPark (arm of case @1639) |
| `trdos/logdupe.pas:1761` | SetUpExchangeInformation | 4 | RADIOMEMORY | none | new seam needed: ReceivedExchangeFields (s6) (which fields the exchange carries) | reach 1: `AE` = RSTAgeAndPossibleSK (arm of case @1639) |
| `trdos/logdupe.pas:1768` | SetUpExchangeInformation | 4 | ALLASIANCW, ALLASIANSSB, YOTA | none | new seam needed: ReceivedExchangeFields (s6) (which fields the exchange carries) | reach 3 GENERIC-NAMED: `AE` = RSTAgeExchange (arm of case @1639) |
| `trdos/logdupe.pas:1774` | SetUpExchangeInformation | 4 | **ALLJA** | all | new seam needed: ReceivedExchangeFields (s6) (which fields the exchange carries) | reach 1: `AE` = RSTALLJAPrefectureAndPrecedenceExchange (arm of case @1639) |
| `trdos/logdupe.pas:1781` | SetUpExchangeInformation | 4 | ARCI | none | new seam needed: ReceivedExchangeFields (s6) (which fields the exchange carries) | reach 1: `AE` = RSTPossibleDomesticQTHAndPower (arm of case @1639) |
| `trdos/logdupe.pas:1788` | SetUpExchangeInformation | 4 | **ARRLDIGI**, **WWDIGI** | all | new seam needed: ReceivedExchangeFields (s6) (which fields the exchange carries) | reach 2: `AE` = Grid2Exchange (arm of case @1639) |
| `trdos/logdupe.pas:1798` | SetUpExchangeInformation | 4 | **BATAVIA_FT8**, MAKROTHEN | some: BATAVIA_FT8 | new seam needed: ReceivedExchangeFields (s6) (which fields the exchange carries) | reach 2 GENERIC-NAMED: `AE` = GridExchange (arm of case @1639) |
| `trdos/logdupe.pas:1809` | SetUpExchangeInformation | 4 | RSGB_ROPOCO_CW, RSGB_ROPOCO_SSB | none | new seam needed: ReceivedExchangeFields (s6) (which fields the exchange carries) | reach 2: `AE` = RSTAndPostalCodeExchange (arm of case @1639) |
| `trdos/logdupe.pas:1838` | SetUpExchangeInformation | 4 | BWQP, **GENERALQSO** | some: GENERALQSO | new seam needed: ReceivedExchangeFields (s6) (which fields the exchange carries) | reach 2 GENERIC-NAMED: `AE` = RSTNameAndQTHExchange (arm of case @1639) |
| `trdos/logdupe.pas:1881` | SetUpExchangeInformation | 4 | FISTS | none | new seam needed: ReceivedExchangeFields (s6) (which fields the exchange carries) | reach 1: `AE` = RSTQTHNameAndFistsNumberOrPowerExchange (arm of case @1639) |
| `trdos/logdupe.pas:1890` | SetUpExchangeInformation | 4 | **XMAS** | all | new seam needed: ReceivedExchangeFields (s6) (which fields the exchange carries) | reach 1: `AE` = RSTQSONumberAndRandomCharactersExchange (arm of case @1639) |
| `trdos/logdupe.pas:1897` | SetUpExchangeInformation | 4 | CQWWRTTY | none | new seam needed: ReceivedExchangeFields (s6) (which fields the exchange carries) | reach 1: `AE` = RSTZoneAndPossibleDomesticQTHExchange (arm of case @1639) |
| `trdos/logdupe.pas:1917` | SetUpExchangeInformation | 4 | **JALONGPREFECT** | all | new seam needed: ReceivedExchangeFields (s6) (which fields the exchange carries) | reach 1: `AE` = RSTLongJAPrefectureExchange (arm of case @1639) |
| `trdos/logdupe.pas:1976` | ParseExchangeIntoContestExchange | 4 | FISTS | none | new seam needed: ParseReceivedExchange (s6) | reach 1: `AE` = RSTQTHNameAndFistsNumberOrPowerExchange |
| `trdos/logdupe.pas:2089` | GetInitialExchangeStringFromContestExchange | 4 | **ALLJA** | all | new seam needed: InitialExchangeFromHistory | reach 1: `AE` = RSTALLJAPrefectureAndPrecedenceExchange |
| `trdos/logdupe.pas:2112` | GetInitialExchangeStringFromContestExchange | 4 | FISTS | none | new seam needed: InitialExchangeFromHistory | reach 1: `AE` = RSTQTHNameAndFistsNumberOrPowerExchange |
| `trdos/logedit.pas:2244` | InitialExchangeEntry | 4 | **CQWWCW** | all | new seam needed: InitialExchangeFromHistory (InitialExchangeKind is the existing trait) | reach 1: `AIE` = CustomInitialExchange (arm of case @2242) |
| `trdos/logedit.pas:2391` | InitialExchangeEntry | 1 | OZCR_O, OZCR_Z | none | new seam needed: InitialExchangeFromHistory (InitialExchangeKind is the existing trait) | `Contest` in |
| `trdos/logedit.pas:2409` | InitialExchangeEntry | 1 | **RFCHAMPIONSHIPCW**, **RFCHAMPIONSHIPSSB** | all | new seam needed: InitialExchangeFromHistory (InitialExchangeKind is the existing trait) | `Contest` in |
| `trdos/logedit.pas:2526` | InitialExchangeEntry | 4 | **ARRLSSCW**, **ARRLSSSSB** | all | new seam needed: InitialExchangeFromHistory (InitialExchangeKind is the existing trait) | reach 2: `AIE` = CheckSectionInitialExchange (arm of case @2242) |
| `trdos/logedit.pas:2621` | InitialExchangeEntry | 1 | RDA, **RU3AXMEMORIAL**, **RUSSIANDX** | some: RU3AXMEMORIAL, RUSSIANDX | new seam needed: InitialExchangeFromHistory (InitialExchangeKind is the existing trait) | `Contest` in |
| `trdos/logedit.pas:2649` | InitialExchangeEntry | 4 | **CALQSOPARTY**, **VAQP** | all | new seam needed: InitialExchangeFromHistory (InitialExchangeKind is the existing trait) | reach 2 GENERIC-NAMED: `AE` = QSONumberDomesticOrDXQTHExchange |
| `trdos/logedit.pas:2652` | InitialExchangeEntry | 4 | **CUPRFCW**, **CUPRFDIG**, **CUPRFSSB** | all | new seam needed: InitialExchangeFromHistory (InitialExchangeKind is the existing trait) | reach 3: `AE` = QSONumberAndGridSquare |
| `trdos/logedit.pas:2657` | InitialExchangeEntry | 4 | **NRAUBALTICCW**, **NRAUBALTICSSB**, **OHIOQSOPARTY** | all | new seam needed: InitialExchangeFromHistory (InitialExchangeKind is the existing trait) | reach 3 GENERIC-NAMED: `AE` = RSTQSONumberAndDomesticQTHExchange |
| `trdos/logedit.pas:2658` | InitialExchangeEntry | 4 | **CQIR** | all | new seam needed: InitialExchangeFromHistory (InitialExchangeKind is the existing trait) | reach 1: `AE` = QSONumberAndPossibleDomesticQTHExchange |
| `trdos/logedit.pas:2674` | InitialExchangeEntry | 4 | **ARRLSSCW**, **ARRLSSSSB** | all | new seam needed: InitialExchangeFromHistory (InitialExchangeKind is the existing trait) | reach 2: `AE` = QSONumberPrecedenceCheckDomesticQTHEXchange |
| `trdos/logedit.pas:2686` | InitialExchangeEntry | 1 | **IARU** | all | new seam needed: InitialExchangeFromHistory (InitialExchangeKind is the existing trait) | `Contest` compare |
| `trdos/logedit.pas:2768` | InitialExchangeEntry | 4 | JIDXCW, JIDXSSB | none | new seam needed: InitialExchangeFromHistory (InitialExchangeKind is the existing trait) | reach 2: `AE` = RSTPrefectureExchange |
| `trdos/logstuff.pas:5581` | ProcessRSTAndZoneExchange | 4 | **EUROPEANHFC**, **KVP** | all | new seam needed: ParseReceivedExchange (s6) | reach 2: `ZnM` = EUHFCYear |
| `trdos/logstuff.pas:10012` | ProcessRSTAndGridSquareOrRDAExchange | 1 | UA4WCHAMPIONSHIP | none | new seam needed: ParseReceivedExchange (s6) | `Contest` compare |
| `trdos/logstuff.pas:10344` | ProcessExchange | 4 | BWQP, **GENERALQSO**, POTA | some: GENERALQSO | new seam needed: ParseReceivedExchange (s6), keyed today by the ExchangeKind trait | reach 3 GENERIC-NAMED: `AE` = RSTNameAndQTHExchange, RSTAndPOTAPark |
| `trdos/logstuff.pas:10438` | DomStringParse | 4 | **ALRS_UA1DZ_CUP**, RDA | some: ALRS_UA1DZ_CUP | new seam needed: ParseDomesticQTH | reach 2: `DM` = RDADistrict |
| `trdos/logstuff.pas:10452` | DomStringParse | 4 | **DARC10M**, **WAG** | all | new seam needed: ParseDomesticQTH | reach 2: `DM` = DOKCodes |
| `trdos/logstuff.pas:10467` | DomStringParse | 4 | **IOTA** | all | new seam needed: ParseDomesticQTH | reach 1: `DM` = IOTADomestic |
| `uCallSignRoutines.pas:674` | IsAGoodCall | 3 | RAEM | none | new seam needed: IsAcceptableCallsign | `Call = 'RAEM'` accepted as a callsign |

### Dupe (0 rows)

None found.

### Multipliers (32 rows)

| file:line | routine | shape | contest(s) -- **bold = has a class** | class? | seam | what |
|---|---|---|---|---|---|---|
| `trdos/logdupe.pas:695` | GetDXQTH | 4 | ARRL10, ARRL160, **WINTERFIELDDAY** | some: WINTERFIELDDAY | DXMultiplierType (existing trait) + new seam needed: DXMultiplierRule | reach 3 GENERIC-NAMED: `XM` = ARRLDXCCWithNoARRLSections (arm of case @682) |
| `trdos/logdupe.pas:708` | GetDXQTH | 4 | ARI_DX | none | DXMultiplierType (existing trait) + new seam needed: DXMultiplierRule | reach 1: `XM` = ARRLDXCCWithNoIOrIS0 (arm of case @682) |
| `trdos/logdupe.pas:717` | GetDXQTH | 4 | JTDX | none | DXMultiplierType (existing trait) + new seam needed: DXMultiplierRule | reach 1: `XM` = ARRLDXCCWithNoJT (arm of case @682) |
| `trdos/logdupe.pas:728` | GetDXQTH | 4 | **DARCWAEDCCW**, **DARCWAEDCSSB** | all | DXMultiplierType (existing trait) + new seam needed: DXMultiplierRule | reach 2: `XM` = CQEuropeanCountries (arm of case @682) |
| `trdos/logdupe.pas:734` | GetDXQTH | 4 | **UBACW**, **UBASSB** | all | DXMultiplierType (existing trait) + new seam needed: DXMultiplierRule | reach 2: `XM` = CQUBAEuropeanCountries (arm of case @682) |
| `trdos/logdupe.pas:752` | GetDXQTH | 4 | BSCI | none | DXMultiplierType (existing trait) + new seam needed: DXMultiplierRule | reach 1: `XM` = BlackSeaCountries (arm of case @682) |
| `trdos/logdupe.pas:760` | GetDXQTH | 4 | **PACC** | all | DXMultiplierType (existing trait) + new seam needed: DXMultiplierRule | reach 1: `XM` = PACCCountriesAndPrefixes (arm of case @682) |
| `trdos/logdupe.pas:1287` | DupeAndMultSheet.SetMultFlags | 1 | **BCQP** | all | new seam needed: MultiplierValue (s6) | `Contest` compare |
| `trdos/logdupe.pas:1291` | DupeAndMultSheet.SetMultFlags | 1 | **NYQP** | all | new seam needed: MultiplierValue (s6) | `Contest` compare |
| `trdos/logdupe.pas:1295` | DupeAndMultSheet.SetMultFlags | 1 | **INQSOPARTY** | all | new seam needed: MultiplierValue (s6) | `Contest` compare |
| `trdos/logdupe.pas:1312` | DupeAndMultSheet.SetMultFlags | 1 | **PCC** | all | new seam needed: MultiplierValue (s6) | `contest` compare |
| `trdos/logdupe.pas:1322` | DupeAndMultSheet.SetMultFlags | 1 | **NZFIELDDAY** | all | new seam needed: MultiplierValue (s6) | `Contest` compare |
| `trdos/logdupe.pas:2271` | DupeAndMultSheet.SetUpRemainingMultiplierArrays | 4 | **EUROPEANHFC**, **KVP** | all | ZoneMultiplierType (existing trait) + new seam needed: RemainingMultList | reach 2: `ZnM` = EUHFCYear (arm of case @2269) |
| `trdos/logdupe.pas:2274` | DupeAndMultSheet.SetUpRemainingMultiplierArrays | 4 | **NZFIELDDAY** | all | ZoneMultiplierType (existing trait) + new seam needed: RemainingMultList | reach 1: `ZnM` = BranchZones (arm of case @2269) |
| `trdos/logdupe.pas:2275` | DupeAndMultSheet.SetUpRemainingMultiplierArrays | 4 | **RFCHAMPIONSHIPCW**, **RFCHAMPIONSHIPSSB** | all | ZoneMultiplierType (existing trait) + new seam needed: RemainingMultList | reach 2: `ZnM` = RFChampionchipZones (arm of case @2269) |
| `trdos/logedit.pas:1020` | EditableLog.GetMultArray | 1 | **RFCHAMPIONSHIPCW**, **RFCHAMPIONSHIPSSB**, **RUSSIANDX** | all | new seam needed: DomesticMultFromQTH | arm of `case Contest of` @1019 |
| `trdos/logedit.pas:1026` | EditableLog.GetMultArray | 1 | **CUPURAL** | all | new seam needed: DomesticMultFromQTH | arm of `case Contest of` @1019 |
| `trdos/logedit.pas:1029` | EditableLog.GetMultArray | 1 | RDA | none | new seam needed: DomesticMultFromQTH | arm of `case Contest of` @1019 |
| `trdos/logedit.pas:1035` | EditableLog.GetMultArray | 1 | YODX | none | new seam needed: DomesticMultFromQTH | arm of `case Contest of` @1019 |
| `trdos/logedit.pas:1476` | Add | 4 | **EUROPEANHFC**, **KVP** | all | ZoneMultiplierType (existing trait) + new seam needed: ZoneMultRule | reach 2: `ZnM` = EUHFCYear |
| `trdos/logedit.pas:2892` | SetPrefix | 4 | **DARCWAEDCCW**, **DARCWAEDCSSB** | all | PrefixMultiplierType (existing trait) + new seam needed: PrefixMultRule | reach 2: `Pxm` = CQNonEuropeanCountriesAndWAECallRegions (arm of case @2891) |
| `trdos/logedit.pas:2894` | SetPrefix | 4 | **UBACW**, **UBASSB** | all | PrefixMultiplierType (existing trait) + new seam needed: PrefixMultRule | reach 2: `Pxm` = BelgiumPrefixes (arm of case @2891) |
| `trdos/logedit.pas:2898` | SetPrefix | 4 | **SACCW**, **SACSSB** | all | PrefixMultiplierType (existing trait) + new seam needed: PrefixMultRule | reach 2: `Pxm` = SACDistricts (arm of case @2891) |
| `trdos/logedit.pas:2899` | SetPrefix | 4 | YBDX | none | PrefixMultiplierType (existing trait) + new seam needed: PrefixMultRule | reach 1: `Pxm` = IndonesianDistricts (arm of case @2891) |
| `trdos/logedit.pas:2901` | SetPrefix | 4 | CQMM, **SASPRINT**, SOUTHAMERICANWW | some: SASPRINT | PrefixMultiplierType (existing trait) + new seam needed: PrefixMultRule | reach 3: `Pxm` = SouthAmericanPrefixes (arm of case @2891) |
| `trdos/logedit.pas:2913` | SetPrefix | 4 | CQMM | none | PrefixMultiplierType (existing trait) + new seam needed: PrefixMultRule | reach 1: `Pxm` = SouthAndNorthAmericanPrefixes (arm of case @2891) |
| `trdos/logedit.pas:2918` | SetPrefix | 4 | SOUTHAMERICANWW | none | PrefixMultiplierType (existing trait) + new seam needed: PrefixMultRule | reach 1: `Pxm` = NonSouthAmericanPrefixes (arm of case @2891) |
| `trdos/logedit.pas:2923` | SetPrefix | 4 | JTDX | none | PrefixMultiplierType (existing trait) + new seam needed: PrefixMultRule | reach 1: `Pxm` = MongolianCallSignPrefix (arm of case @2891) |
| `trdos/logedit.pas:2933` | SetPrefix | 4 | GAGARINCUP | none | PrefixMultiplierType (existing trait) + new seam needed: PrefixMultRule | reach 1: `Pxm` = GCStation (arm of case @2891) |
| `trdos/logedit.pas:2935` | SetPrefix | 3 | GAGARINCUP | none | PrefixMultiplierType (existing trait) + new seam needed: PrefixMultRule | six GC-station callsigns (`'RK1G'`..`'UN/RA3VM'`) |
| `uMults.pas:268` | MultsObject.FillVisibleBytes | 4 | **DARCWAEDCCW**, **DARCWAEDCSSB** | all | DXMultiplierType (existing trait) + new seam needed: DXMultiplierRule | reach 2: `XM` = CQEuropeanCountries |
| `uMults.pas:271` | MultsObject.FillVisibleBytes | 4 | **UBACW**, **UBASSB** | all | DXMultiplierType (existing trait) + new seam needed: DXMultiplierRule | reach 2: `XM` = CQUBAEuropeanCountries |

### ADIF import (3 rows)

| file:line | routine | shape | contest(s) -- **bold = has a class** | class? | seam | what |
|---|---|---|---|---|---|---|
| `MainUnit.pas:9964` | ApplyClasslessADIFImport | 2 | ARRL160 | none | new seam needed: ApplyADIFImport -- needs a POTA / ARRL 160 class | arm of `case exch.ceContest of` @9963 |
| `MainUnit.pas:9967` | ApplyClasslessADIFImport | 2 | POTA | none | new seam needed: ApplyADIFImport -- needs a POTA / ARRL 160 class | arm of `case exch.ceContest of` @9963 |
| `trdos/logstuff.pas:10981` | ResolvePOTAParkFromADIF | 3 | POTA | none | new seam needed: ApplyADIFImport (SIG / SIG_INFO) | ADIF `SIG = 'POTA'` -- the park from `SIG_INFO` (D5, fixed in `3f9e3f28`) |

### ADIF export (7 rows)

| file:line | routine | shape | contest(s) -- **bold = has a class** | class? | seam | what |
|---|---|---|---|---|---|---|
| `trdos/postunit.pas:2304` | EmitContestSpecificTailForExport | 2 | POTA | none | EmitADIFContestFields (existing) | `rec.ceContest` compare |
| `trdos/postunit.pas:2312` | EmitContestSpecificTailForExport | 2 | POTA | none | EmitADIFContestFields (existing) | `rec.ceContest` compare |
| `trdos/postunit.pas:2377` | EmitContestSpecificTailForExport | 4 | **ALRS_UA1DZ_CUP**, RDA | some: ALRS_UA1DZ_CUP | EmitADIFContestFields (existing) | reach 2: `DM` = RDADistrict |
| `trdos/postunit.pas:2386` | EmitContestSpecificTailForExport | 2 | ARRL160 | none | EmitADIFContestFields (existing) | arm of `case rec.ceContest of` @2385 |
| `trdos/postunit.pas:2392` | EmitContestSpecificTailForExport | 2 | POTA | none | EmitADIFContestFields (existing) | arm of `case rec.ceContest of` @2385 |
| `uADIF.pas:1651` | EmitADIFRecord | 2 | POTA | none | ADIFContestId / WritesADIFContestId / ADIFPowerTag (existing) | `rec.ceContest` compare |
| `uADIFExchange.pas:271` | FormatADIFExchangeOfKind | 3 | (none by default) | - | FormatADIFSentExchange (existing; this is the base's default) | `cMyState = 'TRC'` |

### Cabrillo export (12 rows)

| file:line | routine | shape | contest(s) -- **bold = has a class** | class? | seam | what |
|---|---|---|---|---|---|---|
| `trdos/postunit.pas:2637` | GetCabrilloTagText | 1 | ARRL10 | none | CabrilloName (existing) + new seam needed: CabrilloHeaders (s6) | `Contest` compare |
| `trdos/postunit.pas:2637` | GetCabrilloTagText | 1 | **WINTERFIELDDAY** | all | CabrilloName (existing) + new seam needed: CabrilloHeaders (s6) | `Contest` compare |
| `trdos/postunit.pas:2653` | GetCabrilloTagText | 1 | **GENERALQSO** | all | CabrilloName (existing) + new seam needed: CabrilloHeaders (s6) | `Contest` compare |
| `trdos/postunit.pas:2692` | GetCabrilloTagText | 1 | **WINTERFIELDDAY** | all | CabrilloName (existing) + new seam needed: CabrilloHeaders (s6) | `Contest` compare |
| `trdos/postunit.pas:2974` | tGenerateLogPortionOfCabrilloFile | 1 | **WINTERFIELDDAY** | all | FormatCabrilloReceivedExchange / CabrilloQSOLineFormat (existing) + new seam needed: CabrilloModeString | `Contest` compare |
| `trdos/postunit.pas:2999` | tGenerateLogPortionOfCabrilloFile | 3 | **LABRE** | all | FormatCabrilloReceivedExchange / CabrilloQSOLineFormat (existing) + new seam needed: CabrilloModeString | `Settings.Contest.Name = 'LABRE'` |
| `trdos/postunit.pas:3013` | tGenerateLogPortionOfCabrilloFile | 1 | **CUPRFCW**, **CUPRFSSB** | all | FormatCabrilloReceivedExchange / CabrilloQSOLineFormat (existing) + new seam needed: CabrilloModeString | `Contest` in |
| `trdos/postunit.pas:3018` | tGenerateLogPortionOfCabrilloFile | 3 | (none by default) | - | FormatCabrilloReceivedExchange / CabrilloQSOLineFormat (existing) + new seam needed: CabrilloModeString | `Settings.Contest.Name = 'EURASIA'` -- see dead code |
| `uCabrilloExchange.pas:299` | SetHisEx | 3 | (none by default) | - | FormatCabrilloSentExchange / FormatCabrilloReceivedExchange (existing; this is the base's default) | `cMyState = 'TRC'` -- TRC Digital, no ContestType |
| `uCabrilloExchange.pas:303` | SetHisEx | 3 | (none by default) | - | FormatCabrilloSentExchange / FormatCabrilloReceivedExchange (existing; this is the base's default) | `ContestTitle = 'PGA'` -- no ContestType; operator-titled |
| `uCabrilloExchange.pas:314` | SetHisEx | 3 | (none by default) | - | FormatCabrilloSentExchange / FormatCabrilloReceivedExchange (existing; this is the base's default) | `ContestTitle = 'PGA'` -- no ContestType; operator-titled |
| `uCabrilloExchange.pas:318` | SetHisEx | 3 | (none by default) | - | FormatCabrilloSentExchange / FormatCabrilloReceivedExchange (existing; this is the base's default) | `csQTHString = 'TRC'` |

### Score, summary and totals (12 rows)

| file:line | routine | shape | contest(s) -- **bold = has a class** | class? | seam | what |
|---|---|---|---|---|---|---|
| `trdos/logedit.pas:2876` | TotalScore | 1 | RSGB18 | none | new seam needed: CalculateTotalScore (s6) | `Contest` compare |
| `trdos/postunit.pas:1085` | WriteScoreInformationToSummarySheet | 1 | **WINTERFIELDDAY** | all | new seam needed: SummarySheetMultColumns | `Contest` compare |
| `trdos/postunit.pas:1097` | WriteScoreInformationToSummarySheet | 1 | **WINTERFIELDDAY** | all | new seam needed: SummarySheetMultColumns | `Contest` compare |
| `trdos/postunit.pas:1126` | WriteScoreInformationToSummarySheet | 1 | **ARRLFIELDDAY** | all | new seam needed: SummarySheetMultColumns | `Contest` compare |
| `trdos/postunit.pas:1156` | CalculateTotals | 3 | **CQWWCW**, CQWWRTTY, **CQWWSSB** | some: CQWWCW, CQWWSSB | new seam needed: OffTimeMinimumMinutes | `Pos('CQ-WW', Settings.Contest.Name)` -- 60-minute off-time |
| `trdos/postunit.pas:1280` | CheckForNewContestDate | 1 | **GENERALQSO** | all | new seam needed: MaxContestDates | `Contest` compare |
| `trdos/postunit.pas:1454` | PrintHourTotals | 1 | **CUPRFCW**, **CUPRFSSB**, **CUPURAL**, **RFCHAMPIONSHIPCW**, **RFCHAMPIONSHIPSSB**, **RU3AXMEMORIAL**, **UKRAINECHAMPIONSHIP** | all | new seam needed: ShowsRunningScore | `Contest` in |
| `uTotal.pas:263` | UpdateTotals2 | 1 | OZCR_O | none | new seam needed: TotalsDisplay | `Contest` compare |
| `uTotal.pas:301` | UpdateTotals2 | 1 | **IARU** | all | new seam needed: TotalsDisplay | `Contest` compare |
| `uTotal.pas:327` | UpdateTotals2 | 1 | **IARU** | all | new seam needed: TotalsDisplay | `Contest` compare |
| `uTotal.pas:332` | UpdateTotals2 | 1 | **RUSSIANDX** | all | new seam needed: TotalsDisplay | `Contest` compare |
| `uTotal.pas:332` | UpdateTotals2 | 1 | **RU3AXMEMORIAL** | all | new seam needed: TotalsDisplay | `Contest` compare |

### UI, display and the new-contest dialog (110 rows)

| file:line | routine | shape | contest(s) -- **bold = has a class** | class? | seam | what |
|---|---|---|---|---|---|---|
| `MainUnit.pas:1753` | ReturnInCQOpMode | 1 | **GENERALQSO** | all | new seam needed: ShowsMultiplierStatus | `Contest` compare |
| `MainUnit.pas:4126` | CallWindowChange | 1 | **WAG** | all | new seam needed: OnCallsignChanged | `Contest` compare |
| `MainUnit.pas:4465` | CreateMainWindow | 3 | **CQWWCW**, CQWWRTTY, **CQWWSSB**, **IARU** | some: CQWWCW, CQWWSSB, IARU | new seam needed: UIFeatures (menus, QTC, off-time) | `Pos('CQ-WW'` / `'IARU-HF'` in `ContestTypeSA[Contest]` -- 60-minute off-time |
| `MainUnit.pas:4483` | CreateMainWindow | 1 | WRTC | none | new seam needed: UIFeatures (menus, QTC, off-time) | `Contest` compare |
| `MainUnit.pas:4499` | CreateMainWindow | 1 | **DARCWAEDCCW**, **DARCWAEDCSSB** | all | new seam needed: UIFeatures (menus, QTC, off-time) | `Contest` in |
| `MainUnit.pas:4512` | CreateMainWindow | 1 | POTA | none | new seam needed: UIFeatures (menus, QTC, off-time) | `Contest` compare |
| `MainUnit.pas:6467` | OpenTR4WWindow | 1 | WRTC | none | new seam needed: UIFeatures (hidden windows) | `Contest` compare |
| `MainUnit.pas:8264` | BuildLogRow | 1 | **FOCMARATHON** | all | new seam needed: LogColumns | `Contest` compare |
| `MainUnit.pas:9484` | SetColumnsWidth | 4 | **ARRLSSCW**, **ARRLSSSSB** | all | new seam needed: LogColumns | reach 2: `AE` = QSONumberPrecedenceCheckDomesticQTHExchange |
| `MainUnit.pas:9486` | SetColumnsWidth | 4 | **ARRLSSCW**, **ARRLSSSSB** | all | new seam needed: LogColumns | reach 2: `AE` = QSONumberPrecedenceCheckDomesticQTHExchange |
| `MainUnit.pas:9499` | SetColumnsWidth | 1 | **FOCMARATHON** | all | new seam needed: LogColumns | `Contest` compare |
| `MainUnit.pas:9503` | SetColumnsWidth | 1 | **FOCMARATHON** | all | new seam needed: LogColumns | `Contest` compare |
| `trdos/logedit.pas:1713` | EditableLog.SuperCheckPartial | 1 | WRTC | none | new seam needed: UIFeatures (SCP allowed) | `Contest` compare |
| `trdos/logedit.pas:1970` | ShowStationInformation | 1 | **GENERALQSO** | all | new seam needed: ShowsMultiplierStatus | `Contest` compare |
| `trdos/logstuff.pas:982` | BandChange | 1 | **GENERALQSO** | all | new seam needed: AllowsWARCBands | `CONTEST` compare |
| `trdos/logsubs2.pas:2497` | OperateContest | 1 | **GENERALQSO** | all | new seam needed: ShowsMultiplierStatus | `Contest` compare |
| `trdos/logsubs2.pas:2521` | OperateContest | 1 | **GENERALQSO** | all | new seam needed: ShowsMultiplierStatus | `Contest` compare |
| `trdos/logwind.pas:2421` | SetUpBandMapEntry | 1 | **GENERALQSO** | all | new seam needed: ShowsMultiplierStatus | `Contest` compare |
| `uNewContest.pas:169` | ApplyIAmIn | 2 | MWC | none | new seam needed: NewContestPrompts | arm of `case SelectedContest of` @168 |
| `uNewContest.pas:171` | ApplyIAmIn | 2 | **VAQP** | all | new seam needed: NewContestPrompts | arm of `case SelectedContest of` @168 |
| `uNewContest.pas:174` | ApplyIAmIn | 2 | **ALRS_UA1DZ_CUP** | all | new seam needed: NewContestPrompts | arm of `case SelectedContest of` @168 |
| `uNewContest.pas:177` | ApplyIAmIn | 2 | NEWENGLANDQSO | none | new seam needed: NewContestPrompts | arm of `case SelectedContest of` @168 |
| `uNewContest.pas:180` | ApplyIAmIn | 2 | ARRL10, ARRL160, **ARRLDXCW**, **ARRL_RTTY_ROUNDUP** | some: ARRLDXCW, ARRL_RTTY_ROUNDUP | new seam needed: NewContestPrompts | arm of `case SelectedContest of` @168 |
| `uNewContest.pas:193` | ApplyIAmIn | 2 | **CQ160CW**, **CQ160SSB**, CQWWRTTY | some: CQ160CW, CQ160SSB | new seam needed: NewContestPrompts | arm of `case SelectedContest of` @168 |
| `uNewContest.pas:196` | ApplyIAmIn | 2 | IRTS | none | new seam needed: NewContestPrompts | arm of `case SelectedContest of` @168 |
| `uNewContest.pas:199` | ApplyIAmIn | 2 | **CANADA_DAY**, **CANADA_WINTER** | all | new seam needed: NewContestPrompts | arm of `case SelectedContest of` @168 |
| `uNewContest.pas:203` | ApplyIAmIn | 2 | REFCW, REFSSB | none | new seam needed: NewContestPrompts | arm of `case SelectedContest of` @168 |
| `uNewContest.pas:206` | ApplyIAmIn | 2 | CIS, **RU3AXMEMORIAL**, **RUSSIANDX**, **UKRAINIAN**, UNDX | some: RU3AXMEMORIAL, RUSSIANDX, UKRAINIAN | new seam needed: NewContestPrompts | arm of `case SelectedContest of` @168 |
| `uNewContest.pas:209` | ApplyIAmIn | 2 | ARI_DX, HELVETIA, KINGOFSPAINCW, KINGOFSPAINSSB, **PACC**, **UBACW**, **UBASSB** | some: PACC, UBACW, UBASSB | new seam needed: NewContestPrompts | arm of `case SelectedContest of` @168 |
| `uNewContest.pas:212` | ApplyIAmIn | 2 | **CQIR**, HADX, YUDX | some: CQIR | new seam needed: NewContestPrompts | arm of `case SelectedContest of` @168 |
| `uNewContest.pas:214` | ApplyIAmIn | 2 | GAGARINCUP | none | new seam needed: NewContestPrompts | arm of `case SelectedContest of` @168 |
| `uNewContest.pas:216` | ApplyIAmIn | 2 | **UKEI** | all | new seam needed: NewContestPrompts | arm of `case SelectedContest of` @168 |
| `uNewContest.pas:218` | ApplyIAmIn | 2 | **DARC10M**, **DARCXMAS**, **WAG** | all | new seam needed: NewContestPrompts | arm of `case SelectedContest of` @168 |
| `uNewContest.pas:220` | ApplyIAmIn | 2 | EUDX, **LZDX**, **OKDX**, OKOMSSB, RSGB18, SPDX, YODX | some: LZDX, OKDX | new seam needed: NewContestPrompts | arm of `case SelectedContest of` @168 |
| `uNewContest.pas:223` | ApplyIAmIn | 2 | RDA | none | new seam needed: NewContestPrompts | arm of `case SelectedContest of` @168 |
| `uNewContest.pas:225` | ApplyIAmIn | 2 | BSCI, **IARU** | some: IARU | new seam needed: NewContestPrompts | arm of `case SelectedContest of` @168 |
| `uNewContest.pas:228` | ApplyIAmIn | 2 | **IOTA** | all | new seam needed: NewContestPrompts | arm of `case SelectedContest of` @168 |
| `uNewContest.pas:231` | ApplyIAmIn | 2 | WWPMC | none | new seam needed: NewContestPrompts | arm of `case SelectedContest of` @168 |
| `uNewContest.pas:233` | ApplyIAmIn | 2 | POTA | none | new seam needed: NewContestPrompts | arm of `case SelectedContest of` @168 |
| `uNewContest.pas:235` | ApplyIAmIn | 2 | **ARKTIKA_SPRING**, **PCC** | all | new seam needed: NewContestPrompts | arm of `case SelectedContest of` @168 |
| `uNewContest.pas:238` | ApplyIAmIn | 2 | JIDXCW, JIDXSSB | none | new seam needed: NewContestPrompts | arm of `case SelectedContest of` @168 |
| `uNewContest.pas:254` | ApplyContestChoice | 2 | **BCQP** | all | new seam needed: NewContestPrompts | `SelectedContest` compare |
| `uNewContest.pas:260` | ApplyContestChoice | 2 | **LABRE** | all | new seam needed: NewContestPrompts | arm of `case SelectedContest of` @259 |
| `uNewContest.pas:263` | ApplyContestChoice | 2 | **BCQP** | all | new seam needed: NewContestPrompts | arm of `case SelectedContest of` @259 |
| `uNewContest.pas:267` | ApplyContestChoice | 2 | **COLORADOQSOPARTY**, **MINNQSOPARTY** | all | new seam needed: NewContestPrompts | arm of `case SelectedContest of` @259 |
| `uNewContest.pas:272` | ApplyContestChoice | 2 | **ALRS_UA1DZ_CUP** | all | new seam needed: NewContestPrompts | arm of `case SelectedContest of` @259 |
| `uNewContest.pas:275` | ApplyContestChoice | 2 | EUSPRINT_AUTUMN_CW, EUSPRINT_AUTUMN_SSB, EUSPRINT_SPRING_CW, EUSPRINT_SPRING_SSB | none | new seam needed: NewContestPrompts | arm of `case SelectedContest of` @259 |
| `uNewContest.pas:277` | ApplyContestChoice | 2 | **NZFIELDDAY** | all | new seam needed: NewContestPrompts | arm of `case SelectedContest of` @259 |
| `uNewContest.pas:279` | ApplyContestChoice | 2 | **EUROPEANHFC** | all | new seam needed: NewContestPrompts | arm of `case SelectedContest of` @259 |
| `uNewContest.pas:281` | ApplyContestChoice | 2 | **KVP** | all | new seam needed: NewContestPrompts | arm of `case SelectedContest of` @259 |
| `uNewContest.pas:283` | ApplyContestChoice | 2 | **RFCHAMPIONSHIPCW**, **RFCHAMPIONSHIPSSB** | all | new seam needed: NewContestPrompts | arm of `case SelectedContest of` @259 |
| `uNewContest.pas:284` | ApplyContestChoice | 2 | RAEM | none | new seam needed: NewContestPrompts | arm of `case SelectedContest of` @259 |
| `uNewContest.pas:286` | ApplyContestChoice | 2 | OLDNEWYEAR | none | new seam needed: NewContestPrompts | arm of `case SelectedContest of` @259 |
| `uNewContest.pas:287` | ApplyContestChoice | 2 | RSGB_ROPOCO_CW, RSGB_ROPOCO_SSB | none | new seam needed: NewContestPrompts | arm of `case SelectedContest of` @259 |
| `uNewContest.pas:290` | ApplyContestChoice | 2 | RADIOMEMORY | none | new seam needed: NewContestPrompts | arm of `case SelectedContest of` @259 |
| `uNewContest.pas:291` | ApplyContestChoice | 2 | CQMM | none | new seam needed: NewContestPrompts | arm of `case SelectedContest of` @259 |
| `uNewContest.pas:293` | ApplyContestChoice | 2 | **NRAUBALTICCW**, **NRAUBALTICSSB** | all | new seam needed: NewContestPrompts | arm of `case SelectedContest of` @259 |
| `uNewContest.pas:294` | ApplyContestChoice | 2 | OZCR_O | none | new seam needed: NewContestPrompts | arm of `case SelectedContest of` @259 |
| `uNewContest.pas:297` | ApplyContestChoice | 2 | R9W_UW9WK_MEMORIAL | none | new seam needed: NewContestPrompts | arm of `case SelectedContest of` @259 |
| `uNewContest.pas:299` | ApplyContestChoice | 2 | **CUPRFCW**, **CUPRFDIG**, **CUPRFSSB** | all | new seam needed: NewContestPrompts | arm of `case SelectedContest of` @259 |
| `uNewContest.pas:300` | ApplyContestChoice | 2 | RFASCHAMPIONSHIPCW | none | new seam needed: NewContestPrompts | arm of `case SelectedContest of` @259 |
| `uNewContest.pas:301` | ApplyContestChoice | 2 | **ARRLDIGI**, ARRLVHFJAN, ARRLVHFJUN, ARRLVHFSEP, **BATAVIA_FT8**, CQVHF, MAKROTHEN, RTC, STEWPERRY, **WWDIGI** | some: ARRLDIGI, BATAVIA_FT8, WWDIGI | new seam needed: NewContestPrompts | arm of `case SelectedContest of` @259 |
| `uNewContest.pas:303` | ApplyContestChoice | 2 | EUROPEANVHF, **OZHCRVHF**, RADIOVHFFD | some: OZHCRVHF | new seam needed: NewContestPrompts | arm of `case SelectedContest of` @259 |
| `uNewContest.pas:305` | ApplyContestChoice | 2 | TESLA | none | new seam needed: NewContestPrompts | arm of `case SelectedContest of` @259 |
| `uNewContest.pas:308` | ApplyContestChoice | 2 | NEWENGLANDQSO | none | new seam needed: NewContestPrompts | arm of `case SelectedContest of` @259 |
| `uNewContest.pas:310` | ApplyContestChoice | 2 | ARRL10, ARRL160, **ARRL_RTTY_ROUNDUP**, **CQ160CW**, **CQ160SSB**, CQWWRTTY | some: ARRL_RTTY_ROUNDUP, CQ160CW, CQ160SSB | new seam needed: NewContestPrompts | arm of `case SelectedContest of` @259 |
| `uNewContest.pas:312` | ApplyContestChoice | 2 | RDA, **RU3AXMEMORIAL**, **RUSSIANDX** | some: RU3AXMEMORIAL, RUSSIANDX | new seam needed: NewContestPrompts | arm of `case SelectedContest of` @259 |
| `uNewContest.pas:313` | ApplyContestChoice | 2 | **CQIR** | all | new seam needed: NewContestPrompts | arm of `case SelectedContest of` @259 |
| `uNewContest.pas:314` | ApplyContestChoice | 2 | **CANADA_DAY**, **CANADA_WINTER** | all | new seam needed: NewContestPrompts | arm of `case SelectedContest of` @259 |
| `uNewContest.pas:315` | ApplyContestChoice | 2 | REFCW, REFSSB | none | new seam needed: NewContestPrompts | arm of `case SelectedContest of` @259 |
| `uNewContest.pas:316` | ApplyContestChoice | 2 | IRTS | none | new seam needed: NewContestPrompts | arm of `case SelectedContest of` @259 |
| `uNewContest.pas:317` | ApplyContestChoice | 2 | EUDX | none | new seam needed: NewContestPrompts | arm of `case SelectedContest of` @259 |
| `uNewContest.pas:319` | ApplyContestChoice | 2 | KINGOFSPAINCW, KINGOFSPAINSSB | none | new seam needed: NewContestPrompts | arm of `case SelectedContest of` @259 |
| `uNewContest.pas:320` | ApplyContestChoice | 2 | JIDXCW, JIDXSSB | none | new seam needed: NewContestPrompts | arm of `case SelectedContest of` @259 |
| `uNewContest.pas:321` | ApplyContestChoice | 2 | HELVETIA | none | new seam needed: NewContestPrompts | arm of `case SelectedContest of` @259 |
| `uNewContest.pas:322` | ApplyContestChoice | 2 | ARI_DX | none | new seam needed: NewContestPrompts | arm of `case SelectedContest of` @259 |
| `uNewContest.pas:323` | ApplyContestChoice | 2 | UNDX | none | new seam needed: NewContestPrompts | arm of `case SelectedContest of` @259 |
| `uNewContest.pas:324` | ApplyContestChoice | 2 | **UKRAINIAN** | all | new seam needed: NewContestPrompts | arm of `case SelectedContest of` @259 |
| `uNewContest.pas:325` | ApplyContestChoice | 2 | **OKDX**, OKOMSSB | some: OKDX | new seam needed: NewContestPrompts | arm of `case SelectedContest of` @259 |
| `uNewContest.pas:327` | ApplyContestChoice | 2 | **LZDX** | all | new seam needed: NewContestPrompts | arm of `case SelectedContest of` @259 |
| `uNewContest.pas:328` | ApplyContestChoice | 2 | YODX | none | new seam needed: NewContestPrompts | arm of `case SelectedContest of` @259 |
| `uNewContest.pas:329` | ApplyContestChoice | 2 | HADX | none | new seam needed: NewContestPrompts | arm of `case SelectedContest of` @259 |
| `uNewContest.pas:330` | ApplyContestChoice | 2 | YUDX | none | new seam needed: NewContestPrompts | arm of `case SelectedContest of` @259 |
| `uNewContest.pas:331` | ApplyContestChoice | 2 | **UKEI** | all | new seam needed: NewContestPrompts | arm of `case SelectedContest of` @259 |
| `uNewContest.pas:332` | ApplyContestChoice | 2 | GAGARINCUP | none | new seam needed: NewContestPrompts | arm of `case SelectedContest of` @259 |
| `uNewContest.pas:334` | ApplyContestChoice | 2 | **UBACW**, **UBASSB** | all | new seam needed: NewContestPrompts | arm of `case SelectedContest of` @259 |
| `uNewContest.pas:335` | ApplyContestChoice | 2 | **PACC** | all | new seam needed: NewContestPrompts | arm of `case SelectedContest of` @259 |
| `uNewContest.pas:336` | ApplyContestChoice | 2 | **DARC10M**, **DARCXMAS**, **WAG** | all | new seam needed: NewContestPrompts | arm of `case SelectedContest of` @259 |
| `uNewContest.pas:337` | ApplyContestChoice | 2 | RSGB18 | none | new seam needed: NewContestPrompts | arm of `case SelectedContest of` @259 |
| `uNewContest.pas:338` | ApplyContestChoice | 2 | CIS | none | new seam needed: NewContestPrompts | arm of `case SelectedContest of` @259 |
| `uNewContest.pas:339` | ApplyContestChoice | 2 | SPDX | none | new seam needed: NewContestPrompts | arm of `case SelectedContest of` @259 |
| `uNewContest.pas:340` | ApplyContestChoice | 2 | BSCI, **IARU** | some: IARU | new seam needed: NewContestPrompts | arm of `case SelectedContest of` @259 |
| `uNewContest.pas:341` | ApplyContestChoice | 2 | **IOTA** | all | new seam needed: NewContestPrompts | arm of `case SelectedContest of` @259 |
| `uNewContest.pas:346` | ApplyContestChoice | 2 | WWPMC | none | new seam needed: NewContestPrompts | arm of `case SelectedContest of` @259 |
| `uNewContest.pas:347` | ApplyContestChoice | 2 | **ARKTIKA_SPRING**, **PCC** | all | new seam needed: NewContestPrompts | arm of `case SelectedContest of` @259 |
| `uNewContest.pas:349` | ApplyContestChoice | 2 | **NAQSOCW**, **NAQSORTTY**, **NAQSOSSB**, SST | some: NAQSOCW, NAQSORTTY, NAQSOSSB | new seam needed: NewContestPrompts | arm of `case SelectedContest of` @259 |
| `uNewContest.pas:355` | ApplyContestChoice | 2 | CWOPEN, **MST** | some: MST | new seam needed: NewContestPrompts | arm of `case SelectedContest of` @259 |
| `uNewContest.pas:360` | ApplyContestChoice | 2 | **CWOPS**, **LQP**, **NCCCSPRINT** | all | new seam needed: NewContestPrompts | arm of `case SelectedContest of` @259 |
| `uNewContest.pas:366` | ApplyContestChoice | 2 | **FOCMARATHON** | all | new seam needed: NewContestPrompts | arm of `case SelectedContest of` @259 |
| `uNewContest.pas:372` | ApplyContestChoice | 2 | KCJ | none | new seam needed: NewContestPrompts | arm of `case SelectedContest of` @259 |
| `uNewContest.pas:377` | ApplyContestChoice | 2 | POTA | none | new seam needed: NewContestPrompts | arm of `case SelectedContest of` @259 |
| `uNewContest.pas:381` | ApplyContestChoice | 2 | **WINTERFIELDDAY** | all | new seam needed: NewContestPrompts | arm of `case SelectedContest of` @259 |
| `uNewContest.pas:387` | ApplyContestChoice | 2 | **ARRLFIELDDAY** | all | new seam needed: NewContestPrompts | arm of `case SelectedContest of` @259 |
| `uNewContest.pas:393` | ApplyContestChoice | 2 | **ARRLSSCW**, **ARRLSSSSB** | all | new seam needed: NewContestPrompts | arm of `case SelectedContest of` @259 |
| `uNewContest.pas:400` | ApplyContestChoice | 2 | **NASPRINTCW**, **NASPRINTRTTY**, **SPRINTSSB** | all | new seam needed: NewContestPrompts | arm of `case SelectedContest of` @259 |
| `uNewContest.pas:409` | ApplyContestChoice | 2 | UA4WCHAMPIONSHIP | none | new seam needed: NewContestPrompts | arm of `case SelectedContest of` @259 |
| `uNewContest.pas:412` | ApplyContestChoice | 2 | ALLASIANCW, ALLASIANSSB, YOTA, **YOUTHCHAMPIONSHIPRF** | some: YOUTHCHAMPIONSHIPRF | new seam needed: NewContestPrompts | arm of `case SelectedContest of` @259 |
| `uNewContest.pas:415` | ApplyContestChoice | 2 | **UKRAINECHAMPIONSHIP** | all | new seam needed: NewContestPrompts | arm of `case SelectedContest of` @259 |
| `uNewContest.pas:418` | ApplyContestChoice | 2 | **ARRLDXCW**, **ARRLDXSSB** | all | new seam needed: NewContestPrompts | arm of `case SelectedContest of` @259 |
| `uNewContest.pas:422` | ApplyContestChoice | 2 | **CUPURAL** | all | new seam needed: NewContestPrompts | arm of `case SelectedContest of` @259 |

### Setup (FoundContest / LogCfg) (18 rows)

| file:line | routine | shape | contest(s) -- **bold = has a class** | class? | seam | what |
|---|---|---|---|---|---|---|
| `trdos/LogCfg.pas:877` | tSetupExchangeNumbers | 1 | MAKROTHEN | none | new seam needed: SentExchangeFields / FormatSentExchange (s6) | arm of `case Contest of` @875 |
| `trdos/LogCfg.pas:882` | tSetupExchangeNumbers | 1 | RADIOMEMORY, **WISCONSINQSOPARTY** | some: WISCONSINQSOPARTY | new seam needed: SentExchangeFields / FormatSentExchange (s6) | arm of `case Contest of` @875 |
| `trdos/LogCfg.pas:884` | tSetupExchangeNumbers | 1 | **LQP**, **NCCCSPRINT** | all | new seam needed: SentExchangeFields / FormatSentExchange (s6) | arm of `case Contest of` @875 |
| `trdos/LogCfg.pas:888` | tSetupExchangeNumbers | 1 | **CUPURAL**, R9W_UW9WK_MEMORIAL, RFASCHAMPIONSHIPCW, **RFCHAMPIONSHIPCW**, **RFCHAMPIONSHIPSSB**, **UKRAINECHAMPIONSHIP** | some: CUPURAL, RFCHAMPIONSHIPCW, RFCHAMPIONSHIPSSB, UKRAINECHAMPIONSHIP | new seam needed: SentExchangeFields / FormatSentExchange (s6) | arm of `case Contest of` @875 |
| `trdos/LogCfg.pas:890` | tSetupExchangeNumbers | 1 | ALLASIANCW, ALLASIANSSB, **ALRS_UA1DZ_CUP**, ARRL160, **ARRLDXCW**, OLDNEWYEAR, **SALMONRUN**, SEVENQP, **TENNESSEEQSOPARTY** | some: ALRS_UA1DZ_CUP, ARRLDXCW, SALMONRUN, TENNESSEEQSOPARTY | new seam needed: SentExchangeFields / FormatSentExchange (s6) | arm of `case Contest of` @875 |
| `trdos/LogCfg.pas:892` | tSetupExchangeNumbers | 1 | **CALQSOPARTY**, **CUPRFCW**, **CUPRFSSB**, **OHIOQSOPARTY**, RAEM, UA4WCHAMPIONSHIP | some: CALQSOPARTY, CUPRFCW, CUPRFSSB, OHIOQSOPARTY | new seam needed: SentExchangeFields / FormatSentExchange (s6) | arm of `case Contest of` @875 |
| `trdos/LogCfg.pas:899` | tSetupExchangeNumbers | 1 | **CQ160CW**, **CQ160SSB**, **IARU**, JIDXCW, JIDXSSB, **LZDX**, OZCR_O, OZCR_Z | some: CQ160CW, CQ160SSB, IARU, LZDX | new seam needed: SentExchangeFields / FormatSentExchange (s6) | arm of `case Contest of` @875 |
| `trdos/LogCfg.pas:911` | tSetupExchangeNumbers | 1 | **CQIR** | all | new seam needed: SentExchangeFields / FormatSentExchange (s6) | arm of `case Contest of` @875 |
| `trdos/LogCfg.pas:923` | tSetupExchangeNumbers | 1 | **NZFIELDDAY** | all | new seam needed: SentExchangeFields / FormatSentExchange (s6) | arm of `case Contest of` @875 |
| `trdos/LogCfg.pas:927` | tSetupExchangeNumbers | 1 | **OZHCRVHF**, RADIOVHFFD | some: OZHCRVHF | new seam needed: SentExchangeFields / FormatSentExchange (s6) | arm of `case Contest of` @875 |
| `trdos/LogCfg.pas:929` | tSetupExchangeNumbers | 1 | **NRAUBALTICCW**, **NRAUBALTICSSB**, **RU3AXMEMORIAL**, **UBACW**, **UBASSB** | all | new seam needed: SentExchangeFields / FormatSentExchange (s6) | arm of `case Contest of` @875 |
| `trdos/LogCfg.pas:931` | tSetupExchangeNumbers | 1 | HELVETIA, **IOTA**, **PCC** | some: IOTA, PCC | new seam needed: SentExchangeFields / FormatSentExchange (s6) | arm of `case Contest of` @875 |
| `trdos/LogCfg.pas:933` | tSetupExchangeNumbers | 1 | EUSPRINT_AUTUMN_CW, EUSPRINT_AUTUMN_SSB, EUSPRINT_SPRING_CW, EUSPRINT_SPRING_SSB | none | new seam needed: SentExchangeFields / FormatSentExchange (s6) | arm of `case Contest of` @875 |
| `trdos/LogCfg.pas:939` | tSetupExchangeNumbers | 1 | CWOPEN | none | new seam needed: SentExchangeFields / FormatSentExchange (s6) | arm of `case Contest of` @875 |
| `trdos/fcontest.pas:312` | SetUpRSTMyZoneExchange | 4 | CQWWRTTY | none | new seam needed: ConfigureSession | reach 1: `AE` = RSTZoneAndPossibleDomesticQTHExchange |
| `trdos/fcontest.pas:1701` | FoundContest | 1 | **CUPRFSSB** | all | new seam needed: ConfigureSession (the FoundContest arm) | `Contest` compare |
| `trdos/fcontest.pas:1722` | FoundContest | 1 | **RFCHAMPIONSHIPCW** | all | new seam needed: ConfigureSession (the FoundContest arm) | `Contest` compare |
| `trdos/fcontest.pas:1955` | FoundContest | 1 | JIDXCW, JIDXSSB | none | new seam needed: ConfigureSession (the FoundContest arm) | `Contest` in |

### Networking and score reporting (12 rows)

| file:line | routine | shape | contest(s) -- **bold = has a class** | class? | seam | what |
|---|---|---|---|---|---|---|
| `trdos/logsubs2.pas:2771` | SendScoreToUDP | 1 | WRTC | none | new seam needed: ScoreReportMults | `Contest` compare |
| `uExchangeBuilder.pas:112` | BuildSentExchangeText | 2 | RTC | none | new seam needed: CanonicalSentExchange | `RXData.ceContest` compare |
| `uExchangeBuilder.pas:154` | BuildRxExchangeText | 2 | **CQWPXCW**, **CQWPXSSB**, **DARCWAEDCCW** | all | new seam needed: CanonicalReceivedExchange | arm of `case RXData.ceContest of` @152 |
| `uExchangeBuilder.pas:158` | BuildRxExchangeText | 2 | **CQWWCW**, **CQWWSSB**, **IARU** | all | new seam needed: CanonicalReceivedExchange | arm of `case RXData.ceContest of` @152 |
| `uExchangeBuilder.pas:162` | BuildRxExchangeText | 2 | **CQ160CW** | all | new seam needed: CanonicalReceivedExchange | arm of `case RXData.ceContest of` @152 |
| `uExchangeBuilder.pas:168` | BuildRxExchangeText | 2 | **ARRLDXCW**, **ARRLDXSSB** | all | new seam needed: CanonicalReceivedExchange | arm of `case RXData.ceContest of` @152 |
| `uExchangeBuilder.pas:179` | BuildRxExchangeText | 2 | ALLASIANCW, ALLASIANSSB | none | new seam needed: CanonicalReceivedExchange | arm of `case RXData.ceContest of` @152 |
| `uExchangeBuilder.pas:183` | BuildRxExchangeText | 2 | **CWOPS** | all | new seam needed: CanonicalReceivedExchange | arm of `case RXData.ceContest of` @152 |
| `uExchangeBuilder.pas:193` | BuildRxExchangeText | 2 | **NAQSOCW**, **NAQSORTTY**, **NAQSOSSB**, SST | some: NAQSOCW, NAQSORTTY, NAQSOSSB | new seam needed: CanonicalReceivedExchange | arm of `case RXData.ceContest of` @152 |
| `uExchangeBuilder.pas:197` | BuildRxExchangeText | 2 | CWOPEN | none | new seam needed: CanonicalReceivedExchange | arm of `case RXData.ceContest of` @152 |
| `uExchangeBuilder.pas:205` | BuildRxExchangeText | 2 | RTC | none | new seam needed: CanonicalReceivedExchange | arm of `case RXData.ceContest of` @152 |
| `uExchangeBuilder.pas:211` | BuildRxExchangeText | 2 | **ARRLFIELDDAY**, **WINTERFIELDDAY** | all | new seam needed: CanonicalReceivedExchange | arm of `case RXData.ceContest of` @152 |

### Other (26 rows)

| file:line | routine | shape | contest(s) -- **bold = has a class** | class? | seam | what |
|---|---|---|---|---|---|---|
| `trdos/logddx.pas:250` | GetRandomDDXCallsign | 3 | **SACCW**, **SACSSB** | all | new seam needed: SimulatorRules (DDX) | `Settings.Contest.Name = 'Scandinavian Contest'` -- see dead code |
| `trdos/logddx.pas:296` | GetRandomDDXCallsign | 4 | ARI_DX | none | new seam needed: SimulatorRules (DDX) | reach 1: `XM` = ARRLDXCCWithNoIOrIS0 (arm of case @269) |
| `trdos/logddx.pas:311` | GetRandomDDXCallsign | 4 | **DARCWAEDCCW**, **DARCWAEDCSSB** | all | new seam needed: SimulatorRules (DDX) | reach 2: `XM` = CQEuropeanCountries (arm of case @269) |
| `trdos/logddx.pas:605` | GetRandomDomesticQTH | 4 | **ARRLSSCW**, **ARRLSSSSB** | all | new seam needed: SimulatorRules (DDX) | reach 2: `AE` = QSONumberPrecedenceCheckDomesticQTHExchange |
| `trdos/logddx.pas:606` | GetRandomDomesticQTH | 4 | **ARRLFIELDDAY**, **WINTERFIELDDAY** | all | new seam needed: SimulatorRules (DDX) | reach 2: `AE` = ClassDomesticOrDXQTHExchange |
| `trdos/logddx.pas:631` | GetRandomDomesticQTH | 4 | **ARRLSSCW**, **ARRLSSSSB** | all | new seam needed: SimulatorRules (DDX) | reach 2: `AE` = QSONumberPrecedenceCheckDomesticQTHExchange |
| `trdos/logddx.pas:632` | GetRandomDomesticQTH | 4 | **ARRLFIELDDAY**, **WINTERFIELDDAY** | all | new seam needed: SimulatorRules (DDX) | reach 2: `AE` = ClassDomesticOrDXQTHExchange |
| `trdos/logddx.pas:652` | GetRandomDomesticQTH | 4 | **ARRLSSCW**, **ARRLSSSSB** | all | new seam needed: SimulatorRules (DDX) | reach 2: `AE` = QSONumberPrecedenceCheckDomesticQTHExchange |
| `trdos/logddx.pas:653` | GetRandomDomesticQTH | 4 | **ARRLFIELDDAY**, **WINTERFIELDDAY** | all | new seam needed: SimulatorRules (DDX) | reach 2: `AE` = ClassDomesticOrDXQTHExchange |
| `trdos/logddx.pas:673` | GetRandomDomesticQTH | 4 | **ARRLSSCW**, **ARRLSSSSB** | all | new seam needed: SimulatorRules (DDX) | reach 2: `AE` = QSONumberPrecedenceCheckDomesticQTHExchange |
| `trdos/logddx.pas:674` | GetRandomDomesticQTH | 4 | **ARRLFIELDDAY**, **WINTERFIELDDAY** | all | new seam needed: SimulatorRules (DDX) | reach 2: `AE` = ClassDomesticOrDXQTHExchange |
| `trdos/logddx.pas:704` | GetRandomDomesticQTH | 4 | **ARRLSSCW**, **ARRLSSSSB** | all | new seam needed: SimulatorRules (DDX) | reach 2: `AE` = QSONumberPrecedenceCheckDomesticQTHExchange |
| `trdos/logddx.pas:705` | GetRandomDomesticQTH | 4 | **ARRLFIELDDAY**, **WINTERFIELDDAY** | all | new seam needed: SimulatorRules (DDX) | reach 2: `AE` = ClassDomesticOrDXQTHExchange |
| `trdos/logddx.pas:731` | GetRandomDomesticQTH | 4 | **ARRLSSCW**, **ARRLSSSSB** | all | new seam needed: SimulatorRules (DDX) | reach 2: `AE` = QSONumberPrecedenceCheckDomesticQTHExchange |
| `trdos/logddx.pas:732` | GetRandomDomesticQTH | 4 | **ARRLFIELDDAY**, **WINTERFIELDDAY** | all | new seam needed: SimulatorRules (DDX) | reach 2: `AE` = ClassDomesticOrDXQTHExchange |
| `trdos/logddx.pas:752` | GetRandomDomesticQTH | 4 | **ARRLSSCW**, **ARRLSSSSB** | all | new seam needed: SimulatorRules (DDX) | reach 2: `AE` = QSONumberPrecedenceCheckDomesticQTHExchange |
| `trdos/logddx.pas:753` | GetRandomDomesticQTH | 4 | **ARRLFIELDDAY**, **WINTERFIELDDAY** | all | new seam needed: SimulatorRules (DDX) | reach 2: `AE` = ClassDomesticOrDXQTHExchange |
| `trdos/logddx.pas:856` | GetNextCallFromReadInLog | 4 | **ARRLFIELDDAY**, **WINTERFIELDDAY** | all | new seam needed: SimulatorRules (DDX) | reach 2: `AE` = ClassDomesticOrDXQTHExchange |
| `trdos/logddx.pas:858` | GetNextCallFromReadInLog | 4 | TENTEN | none | new seam needed: SimulatorRules (DDX) | reach 1: `AE` = NameQTHAndPossibleTenTenNumber |
| `trdos/logddx.pas:859` | GetNextCallFromReadInLog | 4 | **GRIDLOC** | all | new seam needed: SimulatorRules (DDX) | reach 1: `AE` = NameAndPossibleGridSquareExchange |
| `trdos/logddx.pas:860` | GetNextCallFromReadInLog | 4 | **CALQSOPARTY**, **VAQP** | all | new seam needed: SimulatorRules (DDX) | reach 2 GENERIC-NAMED: `AE` = QSONumberDomesticOrDXQTHExchange |
| `trdos/logddx.pas:862` | GetNextCallFromReadInLog | 4 | **QCWA**, **QCWAGOLDEN** | all | new seam needed: SimulatorRules (DDX) | reach 2: `AE` = QSONumberNameChapterAndQTHExchange |
| `trdos/logddx.pas:864` | GetNextCallFromReadInLog | 4 | **ARRLSSCW**, **ARRLSSSSB** | all | new seam needed: SimulatorRules (DDX) | reach 2: `AE` = QSONumberPrecedenceCheckDomesticQTHExchange |
| `trdos/logddx.pas:907` | DDXExchange | 4 | **ARRLFIELDDAY**, **WINTERFIELDDAY** | all | new seam needed: SimulatorRules (DDX) | reach 2: `AE` = ClassDomesticOrDXQTHExchange (arm of case @905) |
| `trdos/logddx.pas:1009` | DDXExchange | 4 | **ARRLSSCW**, **ARRLSSSSB** | all | new seam needed: SimulatorRules (DDX) | reach 2: `AE` = QSONumberPrecedenceCheckDomesticQTHExchange (arm of case @905) |
| `trdos/logddx.pas:1061` | DDXExchange | 4 | ALLASIANCW, ALLASIANSSB, YOTA | none | new seam needed: SimulatorRules (DDX) | reach 3 GENERIC-NAMED: `AE` = RSTAgeExchange (arm of case @905) |

---

## 5. Setup -- `FoundContest`'s `case Contest of` (`fcontest.pas:547`)

**104 arms naming 131 contests; 73 of those contests have a class**
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

3 more shape-1 tests in `FoundContest` sit outside the case -- `fcontest.pas:1701` (`CUPRFSSB`), `fcontest.pas:1722` (`RFCHAMPIONSHIPCW`), `fcontest.pas:1955` (`JIDXCW`, `JIDXSSB`) --
and are in the Setup table in section 4.

| lines | contest(s) -- **bold = has a class** | what the arm assigns |
|---|---|---|
| `fcontest.pas:549-560` | **LABRE** | CQmem 2, Settings 3 |
| `fcontest.pas:561-578` | **ArizonaQsoParty** | Active* 1, CQmem 2, Settings 4 |
| `fcontest.pas:579-597` | **NYQP** | Active* 1 |
| `fcontest.pas:598-607` | **BCQP** | Active* 1, domfile 1 |
| `fcontest.pas:608-619` | **WINTERFIELDDAY** | Active* 1, CQmem 2, Settings 4, domfile 1 |
| `fcontest.pas:620-633` | **ARRLFIELDDAY** | Active* 2, CQmem 2, Settings 5, domfile 1 |
| `fcontest.pas:634-641` | **CROATIAN** | Active* 1 |
| `fcontest.pas:694-699` | **ALLJA**, YOTA | band 1 |
| `fcontest.pas:700-706` | **JALONGPREFECT** | band 1 |
| `fcontest.pas:750-767` | **ARRLDXCW**, **ARRLDXSSB** | Active* 4, Settings 1, domfile 2 |
| `fcontest.pas:768-788` | **ARRL_RTTY_ROUNDUP** | domfile 1 |
| `fcontest.pas:789-796` | **WWDIGI** | Settings 3 |
| `fcontest.pas:832-838` | **APSPRINT** | band 1 |
| `fcontest.pas:847-853` | **BATAVIA_FT8** | Settings 3 |
| `fcontest.pas:854-871` | **CALQSOPARTY** | Active* 2 |
| `fcontest.pas:895-902` | **CQ160SSB**, **CQ160CW** | Settings 1, domfile 1 |
| `fcontest.pas:964-966` | **FOCMARATHON** | Settings 1 |
| `fcontest.pas:967-974` | **GENERALQSO** | Settings 4 |
| `fcontest.pas:1007-1024` | **UKEI** | domfile 9 |
| `fcontest.pas:1048-1082` | **INTERNETSPRINT** | CQmem 15, Settings 8, band 1, domfile 2 |
| `fcontest.pas:1089-1093` | **KIDSDAY** | Settings 1 |
| `fcontest.pas:1094-1116` | **KVP** | band 1 |
| `fcontest.pas:1117-1129` | **MINNQSOPARTY** | calls only |
| `fcontest.pas:1130-1133` | **MOQSOPARTY** | calls only |
| `fcontest.pas:1150-1184` | **NAQSOCW**, **NAQSOSSB**, **NAQSORTTY** | CQmem 15, Settings 7, domfile 1 |
| `fcontest.pas:1222-1239` | **NRAUBALTICCW**, **NRAUBALTICSSB** | band 1, domfile 13 |
| `fcontest.pas:1247-1261` | **OKDX** | Active* 2, domfile 3 |
| `fcontest.pas:1262-1280` | **PACC** | Active* 3, Settings 1, domfile 3 |
| `fcontest.pas:1297-1304` | **QCWA** | domfile 3 |
| `fcontest.pas:1312-1323` | **CANADA_DAY**, **CANADA_WINTER** | Settings 1, domfile 3 |
| `fcontest.pas:1351-1362` | **RUSSIANDX**, **RU3AXMEMORIAL** | Settings 1, domfile 2 |
| `fcontest.pas:1363-1381` | **SALMONRUN** | Active* 3 |
| `fcontest.pas:1382-1393` | **SACCW**, **SACSSB** | Active* 2 |
| `fcontest.pas:1407-1446` | **NASPRINTCW**, **NASPRINTRTTY** | CQmem 17, Settings 8, band 1, domfile 2 |
| `fcontest.pas:1447-1486` | **SPRINTSSB** | CQmem 17, Settings 8, band 1, domfile 1 |
| `fcontest.pas:1487-1556` | **ARRLSSCW**, **ARRLSSSSB** | CQmem 21, Settings 7, domfile 1 |
| `fcontest.pas:1563-1579` | **TEXASQSOPARTY** | Active* 2 |
| `fcontest.pas:1580-1596` | **UBACW**, **UBASSB** | Active* 5, Settings 1, band 1 |
| `fcontest.pas:1597-1605` | **UKRAINIAN** | Active* 1, domfile 1 |
| `fcontest.pas:1606-1613` | **VAQP** | other:tAllowDupeQSOs 1 |
| `fcontest.pas:1614-1633` | **DARC10M** | Active* 2, Settings 2, band 1, domfile 2 |
| `fcontest.pas:1634-1642` | **DARCXMAS** | Settings 2, domfile 1 |
| `fcontest.pas:1643-1660` | **WAG** | Active* 2, Settings 1, domfile 1 |
| `fcontest.pas:1661-1691` | **DARCWAEDCCW**, **DARCWAEDCSSB** | Active* 2, Settings 2, band 1 |
| `fcontest.pas:1698-1708` | **CUPRFCW**, **CUPRFSSB**, **CUPRFDIG** | Settings 2, band 2 |
| `fcontest.pas:1719-1731` | **RFCHAMPIONSHIPCW**, **RFCHAMPIONSHIPSSB** | Settings 1, band 2, other:DomesticMultByBand 1 |
| `fcontest.pas:1732-1739` | **MINITEST**, **MINI80** | Settings 3, band 1 |
| `fcontest.pas:1740-1747` | **MINI40** | Settings 3, band 1 |
| `fcontest.pas:1748-1753` | **LZDX** | band 1, domfile 1 |
| `fcontest.pas:1754-1771` | **ALRS_UA1DZ_CUP** | Active* 2, Settings 2, domfile 1, other:TempOblast 1 |
| `fcontest.pas:1781-1789` | **YOUTHCHAMPIONSHIPRF** | Settings 3, band 1 |
| `fcontest.pas:1824-1838` | **LQP**, **NCCCSPRINT** | Settings 4, domfile 2, other:tAllowDupeQSOs 1 |
| `fcontest.pas:1845-1849` | **CQIR** | domfile 1 |
| `fcontest.pas:1874-1879` | **OZHCRVHF** | Settings 1 |
| `fcontest.pas:1880-1897` | **PCC** | Settings 2 |
| `fcontest.pas:1898-1906` | **ARRLDIGI** | Settings 3 |
| `fcontest.pas:642-661` | JIDXSSB, JIDXCW | Active* 6, domfile 1 |
| `fcontest.pas:662-673` | SOUTHAMERICANWW | Active* 2 |
| `fcontest.pas:674-681` | STEWPERRY | Settings 3, band 1 |
| `fcontest.pas:682-693` | ALLASIANCW, ALLASIANSSB | Active* 2 |
| `fcontest.pas:707-712` | ARCI | domfile 1 |
| `fcontest.pas:713-720` | ARI_DX | domfile 3 |
| `fcontest.pas:721-732` | ARRL10 | Active* 1, Settings 1, band 1, domfile 2 |
| `fcontest.pas:733-749` | ARRL160 | Active* 3, domfile 1 |
| `fcontest.pas:797-822` | RTC | CQmem 4, Settings 4 |
| `fcontest.pas:823-831` | ARRLVHFJUN, ARRLVHFSEP | Settings 2, band 1 |
| `fcontest.pas:839-846` | BALTIC | band 1 |
| `fcontest.pas:872-894` | CIS | domfile 12 |
| `fcontest.pas:903-908` | CQM | Settings 1 |
| `fcontest.pas:909-937` | CQVHF | Settings 1, band 1 |
| `fcontest.pas:938-944` | EUSPRINT_SPRING_SSB, EUSPRINT_AUTUMN_CW, EUSPRINT_AUTUMN_SSB, EUSPRINT_SPRING_CW | band 1 |
| `fcontest.pas:945-955` | RADIOVHFFD | Settings 6, band 1 |
| `fcontest.pas:956-963` | EUROPEANVHF | Settings 1, band 1 |
| `fcontest.pas:975-979` | HADX | domfile 1 |
| `fcontest.pas:980-990` | IRTS | Active* 1, Settings 1, band 1, other:INITIALEXCHANGECURSORPOS 1 |
| `fcontest.pas:991-996` | EUDX | calls only |
| `fcontest.pas:997-1006` | YUDX | Active* 2, domfile 1 |
| `fcontest.pas:1025-1034` | HELVETIA | Active* 1, domfile 1 |
| `fcontest.pas:1035-1039` | OZCR_Z | Settings 1 |
| `fcontest.pas:1040-1047` | GAGARINCUP | Settings 4 |
| `fcontest.pas:1083-1088` | KCJ | Active* 1, Settings 1 |
| `fcontest.pas:1134-1140` | MWC | band 1, domfile 1 |
| `fcontest.pas:1141-1149` | SST | Active* 1, Settings 3, domfile 1 |
| `fcontest.pas:1185-1221` | NEWENGLANDQSO | Active* 3, domfile 3, other:DXMultLimit 1, other:NewEnglandState 1 |
| `fcontest.pas:1240-1246` | OKOMSSB | band 1, domfile 2 |
| `fcontest.pas:1281-1296` | POTA | CQmem 2, Settings 5, other:tAllowDupeQSOs 1 |
| `fcontest.pas:1305-1311` | RAEM | Settings 1, band 1, other:InitialExchangeCursorPos 1 |
| `fcontest.pas:1324-1339` | RSGB_ROPOCO_CW, RSGB_ROPOCO_SSB | CQmem 6, Settings 4, band 1 |
| `fcontest.pas:1340-1350` | RDA | Active* 1, domfile 1, other:DomesticMultByBand 1 |
| `fcontest.pas:1394-1400` | YBDX | Active* 2, band 1 |
| `fcontest.pas:1401-1406` | SPDX | domfile 1 |
| `fcontest.pas:1557-1562` | TENTEN | domfile 1 |
| `fcontest.pas:1692-1697` | YODX | Settings 1, domfile 1 |
| `fcontest.pas:1709-1713` | UA4WCHAMPIONSHIP | Settings 1 |
| `fcontest.pas:1714-1718` | R9W_UW9WK_MEMORIAL | Settings 1 |
| `fcontest.pas:1772-1777` | OLDNEWYEAR | Settings 1, band 1 |
| `fcontest.pas:1778-1780` | CQWPXRTTY, WRTC | band 1 |
| `fcontest.pas:1790-1795` | RFASCHAMPIONSHIPCW | calls only |
| `fcontest.pas:1796-1817` | SEVENQP | Active* 3, other:DXMultLimit 1 |
| `fcontest.pas:1818-1823` | OZCR_O | Settings 2 |
| `fcontest.pas:1839-1844` | JTDX | Active* 2 |
| `fcontest.pas:1850-1855` | UNDX | domfile 1 |
| `fcontest.pas:1856-1863` | KINGOFSPAINCW, KINGOFSPAINSSB | domfile 4 |
| `fcontest.pas:1864-1873` | CQMM | Active* 1, band 1, other:DXCCMultByBand 1 |

---

## 6. Per-contest index

Every site from sections 4 and 5, by contest. Shape-4 rows are included for
every contest the tested value reaches (reach 1-3).

### 6.1 Registered contests -- rules that should already have moved

**99 of 102.** Sorted by number of sites. Registered contests with
**no** site outside the factory: `FLORIDAQSOPARTY`, `MARCONIMEMORIAL`, `MICHQSOPARTY`.

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
| WINTERFIELDDAY | **scoring** `trdos/logstuff.pas:6512`; **exchange** `trdos/logdupe.pas:1647`; **multipliers** `trdos/logdupe.pas:695`; **cabrillo-export** `trdos/postunit.pas:2637`, `trdos/postunit.pas:2692`, `trdos/postunit.pas:2974`; **score-summary** `trdos/postunit.pas:1085`, `trdos/postunit.pas:1097`; **ui** `uNewContest.pas:381`; **setup** `trdos/fcontest.pas:608`; **networking** `uExchangeBuilder.pas:211`; **other** `trdos/logddx.pas:606`, `trdos/logddx.pas:632`, `trdos/logddx.pas:653`, `trdos/logddx.pas:674`, `trdos/logddx.pas:705`, `trdos/logddx.pas:732`, `trdos/logddx.pas:753`, `trdos/logddx.pas:856`, `trdos/logddx.pas:907` |
| ARRLSSCW | **exchange** `trdos/logdupe.pas:1736`, `trdos/logedit.pas:2526`, `trdos/logedit.pas:2674`; **ui** `MainUnit.pas:9484`, `MainUnit.pas:9486`, `uNewContest.pas:393`; **setup** `trdos/fcontest.pas:1487`; **other** `trdos/logddx.pas:605`, `trdos/logddx.pas:631`, `trdos/logddx.pas:652`, `trdos/logddx.pas:673`, `trdos/logddx.pas:704`, `trdos/logddx.pas:731`, `trdos/logddx.pas:752`, `trdos/logddx.pas:864`, `trdos/logddx.pas:1009` |
| ARRLSSSSB | **exchange** `trdos/logdupe.pas:1736`, `trdos/logedit.pas:2526`, `trdos/logedit.pas:2674`; **ui** `MainUnit.pas:9484`, `MainUnit.pas:9486`, `uNewContest.pas:393`; **setup** `trdos/fcontest.pas:1487`; **other** `trdos/logddx.pas:605`, `trdos/logddx.pas:631`, `trdos/logddx.pas:652`, `trdos/logddx.pas:673`, `trdos/logddx.pas:704`, `trdos/logddx.pas:731`, `trdos/logddx.pas:752`, `trdos/logddx.pas:864`, `trdos/logddx.pas:1009` |
| ARRLFIELDDAY | **scoring** `trdos/logstuff.pas:6512`; **exchange** `trdos/logdupe.pas:1647`; **score-summary** `trdos/postunit.pas:1126`; **ui** `uNewContest.pas:387`; **setup** `trdos/fcontest.pas:620`; **networking** `uExchangeBuilder.pas:211`; **other** `trdos/logddx.pas:606`, `trdos/logddx.pas:632`, `trdos/logddx.pas:653`, `trdos/logddx.pas:674`, `trdos/logddx.pas:705`, `trdos/logddx.pas:732`, `trdos/logddx.pas:753`, `trdos/logddx.pas:856`, `trdos/logddx.pas:907` |
| GENERALQSO | **exchange** `MainUnit.pas:7096`, `trdos/logdupe.pas:1838`, `trdos/logstuff.pas:10344`; **cabrillo-export** `trdos/postunit.pas:2653`; **score-summary** `trdos/postunit.pas:1280`; **ui** `MainUnit.pas:1753`, `trdos/logedit.pas:1970`, `trdos/logstuff.pas:982`, `trdos/logsubs2.pas:2497`, `trdos/logsubs2.pas:2521`, `trdos/logwind.pas:2421`; **setup** `trdos/fcontest.pas:967` |
| RFCHAMPIONSHIPCW | **scoring** `trdos/logstuff.pas:8908`; **exchange** `trdos/logdupe.pas:1702`, `trdos/logedit.pas:2409`; **multipliers** `trdos/logdupe.pas:2275`, `trdos/logedit.pas:1020`; **score-summary** `trdos/postunit.pas:1454`; **ui** `uNewContest.pas:283`; **setup** `trdos/LogCfg.pas:888`, `trdos/fcontest.pas:1719`, `trdos/fcontest.pas:1722` |
| IARU | **scoring** `trdos/logstuff.pas:7806`; **exchange** `trdos/logedit.pas:2686`; **score-summary** `uTotal.pas:301`, `uTotal.pas:327`; **ui** `MainUnit.pas:4465`, `uNewContest.pas:225`, `uNewContest.pas:340`; **setup** `trdos/LogCfg.pas:899`; **networking** `uExchangeBuilder.pas:158` |
| RFCHAMPIONSHIPSSB | **scoring** `trdos/logstuff.pas:8908`; **exchange** `trdos/logdupe.pas:1702`, `trdos/logedit.pas:2409`; **multipliers** `trdos/logdupe.pas:2275`, `trdos/logedit.pas:1020`; **score-summary** `trdos/postunit.pas:1454`; **ui** `uNewContest.pas:283`; **setup** `trdos/LogCfg.pas:888`, `trdos/fcontest.pas:1719` |
| RU3AXMEMORIAL | **scoring** `trdos/logstuff.pas:8263`, `trdos/logstuff.pas:8300`; **exchange** `trdos/logedit.pas:2621`; **score-summary** `trdos/postunit.pas:1454`, `uTotal.pas:332`; **ui** `uNewContest.pas:206`, `uNewContest.pas:312`; **setup** `trdos/LogCfg.pas:929`, `trdos/fcontest.pas:1351` |
| UBACW | **scoring** `trdos/logstuff.pas:8559`; **exchange** `MainUnit.pas:7251`; **multipliers** `trdos/logdupe.pas:734`, `trdos/logedit.pas:2894`, `uMults.pas:271`; **ui** `uNewContest.pas:209`, `uNewContest.pas:334`; **setup** `trdos/LogCfg.pas:929`, `trdos/fcontest.pas:1580` |
| UBASSB | **scoring** `trdos/logstuff.pas:8559`; **exchange** `MainUnit.pas:7251`; **multipliers** `trdos/logdupe.pas:734`, `trdos/logedit.pas:2894`, `uMults.pas:271`; **ui** `uNewContest.pas:209`, `uNewContest.pas:334`; **setup** `trdos/LogCfg.pas:929`, `trdos/fcontest.pas:1580` |
| ALRS_UA1DZ_CUP | **scoring** `trdos/logstuff.pas:6617`; **exchange** `trdos/logdom.pas:224`, `trdos/logstuff.pas:10438`; **adif-export** `trdos/postunit.pas:2377`; **ui** `uNewContest.pas:174`, `uNewContest.pas:272`; **setup** `trdos/LogCfg.pas:890`, `trdos/fcontest.pas:1754` |
| CUPRFSSB | **scoring** `trdos/logstuff.pas:8813`; **exchange** `trdos/logedit.pas:2652`; **cabrillo-export** `trdos/postunit.pas:3013`; **score-summary** `trdos/postunit.pas:1454`; **ui** `uNewContest.pas:299`; **setup** `trdos/LogCfg.pas:892`, `trdos/fcontest.pas:1698`, `trdos/fcontest.pas:1701` |
| DARCWAEDCCW | **scoring** `trdos/logstuff.pas:8681`; **multipliers** `trdos/logdupe.pas:728`, `trdos/logedit.pas:2892`, `uMults.pas:268`; **ui** `MainUnit.pas:4499`; **setup** `trdos/fcontest.pas:1661`; **networking** `uExchangeBuilder.pas:154`; **other** `trdos/logddx.pas:311` |
| CUPRFCW | **scoring** `trdos/logstuff.pas:8813`; **exchange** `trdos/logedit.pas:2652`; **cabrillo-export** `trdos/postunit.pas:3013`; **score-summary** `trdos/postunit.pas:1454`; **ui** `uNewContest.pas:299`; **setup** `trdos/LogCfg.pas:892`, `trdos/fcontest.pas:1698` |
| DARCWAEDCSSB | **scoring** `trdos/logstuff.pas:8681`; **multipliers** `trdos/logdupe.pas:728`, `trdos/logedit.pas:2892`, `uMults.pas:268`; **ui** `MainUnit.pas:4499`; **setup** `trdos/fcontest.pas:1661`; **other** `trdos/logddx.pas:311` |
| FOCMARATHON | **scoring** `trdos/logstuff.pas:7297`, `trdos/logstuff.pas:7299`; **ui** `MainUnit.pas:8264`, `MainUnit.pas:9499`, `MainUnit.pas:9503`, `uNewContest.pas:366`; **setup** `trdos/fcontest.pas:964` |
| RUSSIANDX | **scoring** `trdos/logstuff.pas:8263`; **exchange** `trdos/logedit.pas:2621`; **multipliers** `trdos/logedit.pas:1020`; **score-summary** `uTotal.pas:332`; **ui** `uNewContest.pas:206`, `uNewContest.pas:312`; **setup** `trdos/fcontest.pas:1351` |
| WAG | **scoring** `trdos/logstuff.pas:8653`; **exchange** `trdos/logdom.pas:247`, `trdos/logstuff.pas:10452`; **ui** `MainUnit.pas:4126`, `uNewContest.pas:218`, `uNewContest.pas:336`; **setup** `trdos/fcontest.pas:1643` |
| ARRLDXCW | **scoring** `trdos/logstuff.pas:6488`; **ui** `uNewContest.pas:180`, `uNewContest.pas:418`; **setup** `trdos/LogCfg.pas:890`, `trdos/fcontest.pas:750`; **networking** `uExchangeBuilder.pas:168` |
| CQ160CW | **scoring** `trdos/logstuff.pas:6753`; **ui** `uNewContest.pas:193`, `uNewContest.pas:310`; **setup** `trdos/LogCfg.pas:899`, `trdos/fcontest.pas:895`; **networking** `uExchangeBuilder.pas:162` |
| IOTA | **scoring** `trdos/logstuff.pas:7886`; **exchange** `trdos/logdom.pas:263`, `trdos/logstuff.pas:10467`; **ui** `uNewContest.pas:228`, `uNewContest.pas:341`; **setup** `trdos/LogCfg.pas:931` |
| NZFIELDDAY | **scoring** `trdos/logstuff.pas:8028`; **exchange** `trdos/logdupe.pas:1683`; **multipliers** `trdos/logdupe.pas:1322`, `trdos/logdupe.pas:2274`; **ui** `uNewContest.pas:277`; **setup** `trdos/LogCfg.pas:923` |
| PCC | **scoring** `trdos/logstuff.pas:9221`; **multipliers** `trdos/logdupe.pas:1312`; **ui** `uNewContest.pas:235`, `uNewContest.pas:347`; **setup** `trdos/LogCfg.pas:931`, `trdos/fcontest.pas:1880` |
| BATAVIA_FT8 | **scoring** `trdos/logstuff.pas:8398`, `trdos/logstuff.pas:8427`; **exchange** `trdos/logdupe.pas:1798`; **ui** `uNewContest.pas:301`; **setup** `trdos/fcontest.pas:847` |
| BCQP | **scoring** `trdos/logstuff.pas:7417`; **multipliers** `trdos/logdupe.pas:1287`; **ui** `uNewContest.pas:254`, `uNewContest.pas:263`; **setup** `trdos/fcontest.pas:598` |
| CALQSOPARTY | **scoring** `trdos/logstuff.pas:8748`; **exchange** `trdos/logedit.pas:2649`; **setup** `trdos/LogCfg.pas:892`, `trdos/fcontest.pas:854`; **other** `trdos/logddx.pas:860` |
| CQ160SSB | **scoring** `trdos/logstuff.pas:6753`; **ui** `uNewContest.pas:193`, `uNewContest.pas:310`; **setup** `trdos/LogCfg.pas:899`, `trdos/fcontest.pas:895` |
| CQIR | **exchange** `trdos/logedit.pas:2658`; **ui** `uNewContest.pas:212`, `uNewContest.pas:313`; **setup** `trdos/LogCfg.pas:911`, `trdos/fcontest.pas:1845` |
| CQWWCW | **scoring** `trdos/logstuff.pas:7024`; **exchange** `trdos/logedit.pas:2244`; **score-summary** `trdos/postunit.pas:1156`; **ui** `MainUnit.pas:4465`; **networking** `uExchangeBuilder.pas:158` |
| DARC10M | **exchange** `trdos/logdom.pas:247`, `trdos/logstuff.pas:10452`; **ui** `uNewContest.pas:218`, `uNewContest.pas:336`; **setup** `trdos/fcontest.pas:1614` |
| KVP | **exchange** `trdos/logstuff.pas:5581`; **multipliers** `trdos/logdupe.pas:2271`, `trdos/logedit.pas:1476`; **ui** `uNewContest.pas:281`; **setup** `trdos/fcontest.pas:1094` |
| LQP | **scoring** `trdos/logstuff.pas:9168`, `trdos/logstuff.pas:9171`; **ui** `uNewContest.pas:360`; **setup** `trdos/LogCfg.pas:884`, `trdos/fcontest.pas:1824` |
| LZDX | **scoring** `trdos/logstuff.pas:9039`; **ui** `uNewContest.pas:220`, `uNewContest.pas:327`; **setup** `trdos/LogCfg.pas:899`, `trdos/fcontest.pas:1748` |
| SACCW | **scoring** `trdos/logstuff.pas:8319`; **exchange** `MainUnit.pas:7255`; **multipliers** `trdos/logedit.pas:2898`; **setup** `trdos/fcontest.pas:1382`; **other** `trdos/logddx.pas:250` |
| SACSSB | **scoring** `trdos/logstuff.pas:8319`; **exchange** `MainUnit.pas:7255`; **multipliers** `trdos/logedit.pas:2898`; **setup** `trdos/fcontest.pas:1382`; **other** `trdos/logddx.pas:250` |
| VAQP | **scoring** `trdos/logstuff.pas:9546`; **exchange** `trdos/logedit.pas:2649`; **ui** `uNewContest.pas:171`; **setup** `trdos/fcontest.pas:1606`; **other** `trdos/logddx.pas:860` |
| ARRLDIGI | **scoring** `trdos/logstuff.pas:6535`; **exchange** `trdos/logdupe.pas:1788`; **ui** `uNewContest.pas:301`; **setup** `trdos/fcontest.pas:1898` |
| ARRLDXSSB | **scoring** `trdos/logstuff.pas:6488`; **ui** `uNewContest.pas:418`; **setup** `trdos/fcontest.pas:750`; **networking** `uExchangeBuilder.pas:168` |
| CANADA_DAY | **scoring** `trdos/logstuff.pas:8165`; **ui** `uNewContest.pas:199`, `uNewContest.pas:314`; **setup** `trdos/fcontest.pas:1312` |
| CANADA_WINTER | **scoring** `trdos/logstuff.pas:8165`; **ui** `uNewContest.pas:199`, `uNewContest.pas:314`; **setup** `trdos/fcontest.pas:1312` |
| CQWWSSB | **scoring** `trdos/logstuff.pas:7024`; **score-summary** `trdos/postunit.pas:1156`; **ui** `MainUnit.pas:4465`; **networking** `uExchangeBuilder.pas:158` |
| CUPRFDIG | **scoring** `trdos/logstuff.pas:8813`; **exchange** `trdos/logedit.pas:2652`; **ui** `uNewContest.pas:299`; **setup** `trdos/fcontest.pas:1698` |
| CUPURAL | **multipliers** `trdos/logedit.pas:1026`; **score-summary** `trdos/postunit.pas:1454`; **ui** `uNewContest.pas:422`; **setup** `trdos/LogCfg.pas:888` |
| EUROPEANHFC | **exchange** `trdos/logstuff.pas:5581`; **multipliers** `trdos/logdupe.pas:2271`, `trdos/logedit.pas:1476`; **ui** `uNewContest.pas:279` |
| LABRE | **scoring** `trdos/logstuff.pas:9001`; **cabrillo-export** `trdos/postunit.pas:2999`; **ui** `uNewContest.pas:260`; **setup** `trdos/fcontest.pas:549` |
| NRAUBALTICCW | **exchange** `trdos/logedit.pas:2657`; **ui** `uNewContest.pas:293`; **setup** `trdos/LogCfg.pas:929`, `trdos/fcontest.pas:1222` |
| NRAUBALTICSSB | **exchange** `trdos/logedit.pas:2657`; **ui** `uNewContest.pas:293`; **setup** `trdos/LogCfg.pas:929`, `trdos/fcontest.pas:1222` |
| OKDX | **scoring** `trdos/logstuff.pas:8053`; **ui** `uNewContest.pas:220`, `uNewContest.pas:325`; **setup** `trdos/fcontest.pas:1247` |
| OZHCRVHF | **scoring** `trdos/logstuff.pas:7468`; **ui** `uNewContest.pas:303`; **setup** `trdos/LogCfg.pas:927`, `trdos/fcontest.pas:1874` |
| PACC | **multipliers** `trdos/logdupe.pas:760`; **ui** `uNewContest.pas:209`, `uNewContest.pas:335`; **setup** `trdos/fcontest.pas:1262` |
| UKEI | **scoring** `trdos/logstuff.pas:7674`; **ui** `uNewContest.pas:216`, `uNewContest.pas:331`; **setup** `trdos/fcontest.pas:1007` |
| UKRAINECHAMPIONSHIP | **scoring** `trdos/logstuff.pas:8930`; **score-summary** `trdos/postunit.pas:1454`; **ui** `uNewContest.pas:415`; **setup** `trdos/LogCfg.pas:888` |
| UKRAINIAN | **scoring** `trdos/logstuff.pas:8607`; **ui** `uNewContest.pas:206`, `uNewContest.pas:324`; **setup** `trdos/fcontest.pas:1597` |
| WWDIGI | **scoring** `trdos/logstuff.pas:8489`; **exchange** `trdos/logdupe.pas:1788`; **ui** `uNewContest.pas:301`; **setup** `trdos/fcontest.pas:789` |
| YOUTHCHAMPIONSHIPRF | **scoring** `trdos/logstuff.pas:8745`; **exchange** `trdos/logdupe.pas:1744`; **ui** `uNewContest.pas:412`; **setup** `trdos/fcontest.pas:1781` |
| ALLJA | **exchange** `trdos/logdupe.pas:1774`, `trdos/logdupe.pas:2089`; **setup** `trdos/fcontest.pas:694` |
| ARKTIKA_SPRING | **scoring** `trdos/logstuff.pas:9177`; **ui** `uNewContest.pas:235`, `uNewContest.pas:347` |
| ARRL_RTTY_ROUNDUP | **ui** `uNewContest.pas:180`, `uNewContest.pas:310`; **setup** `trdos/fcontest.pas:768` |
| COUNTYHUNTER | **exchange** `MainUnit.pas:928`, `MainUnit.pas:969`, `MainUnit.pas:2052` |
| DARCXMAS | **ui** `uNewContest.pas:218`, `uNewContest.pas:336`; **setup** `trdos/fcontest.pas:1634` |
| NAQSOCW | **ui** `uNewContest.pas:349`; **setup** `trdos/fcontest.pas:1150`; **networking** `uExchangeBuilder.pas:193` |
| NAQSORTTY | **ui** `uNewContest.pas:349`; **setup** `trdos/fcontest.pas:1150`; **networking** `uExchangeBuilder.pas:193` |
| NAQSOSSB | **ui** `uNewContest.pas:349`; **setup** `trdos/fcontest.pas:1150`; **networking** `uExchangeBuilder.pas:193` |
| NCCCSPRINT | **ui** `uNewContest.pas:360`; **setup** `trdos/LogCfg.pas:884`, `trdos/fcontest.pas:1824` |
| QCWA | **exchange** `trdos/logdupe.pas:1721`; **setup** `trdos/fcontest.pas:1297`; **other** `trdos/logddx.pas:862` |
| SALMONRUN | **scoring** `trdos/logstuff.pas:8307`; **setup** `trdos/LogCfg.pas:890`, `trdos/fcontest.pas:1363` |
| CQWPXCW | **scoring** `trdos/logstuff.pas:6911`; **networking** `uExchangeBuilder.pas:154` |
| CQWPXSSB | **scoring** `trdos/logstuff.pas:6911`; **networking** `uExchangeBuilder.pas:154` |
| CROATIAN | **scoring** `trdos/logstuff.pas:7057`; **setup** `trdos/fcontest.pas:634` |
| CWOPS | **ui** `uNewContest.pas:360`; **networking** `uExchangeBuilder.pas:183` |
| GRIDLOC | **exchange** `trdos/logdupe.pas:1677`; **other** `trdos/logddx.pas:859` |
| INTERNETSPRINT | **scoring** `trdos/logstuff.pas:8745`; **setup** `trdos/fcontest.pas:1048` |
| JALONGPREFECT | **exchange** `trdos/logdupe.pas:1917`; **setup** `trdos/fcontest.pas:700` |
| KIDSDAY | **exchange** `trdos/logdupe.pas:1653`; **setup** `trdos/fcontest.pas:1089` |
| MINNQSOPARTY | **ui** `uNewContest.pas:267`; **setup** `trdos/fcontest.pas:1117` |
| NASPRINTCW | **ui** `uNewContest.pas:400`; **setup** `trdos/fcontest.pas:1407` |
| NASPRINTRTTY | **ui** `uNewContest.pas:400`; **setup** `trdos/fcontest.pas:1407` |
| NCQSOPARTY | **scoring** `trdos/logstuff.pas:7368`, `trdos/logstuff.pas:7383` |
| NYQP | **multipliers** `trdos/logdupe.pas:1291`; **setup** `trdos/fcontest.pas:579` |
| OHIOQSOPARTY | **exchange** `trdos/logedit.pas:2657`; **setup** `trdos/LogCfg.pas:892` |
| QCWAGOLDEN | **exchange** `trdos/logdupe.pas:1721`; **other** `trdos/logddx.pas:862` |
| SASPRINT | **exchange** `MainUnit.pas:7265`; **multipliers** `trdos/logedit.pas:2901` |
| SPRINTSSB | **ui** `uNewContest.pas:400`; **setup** `trdos/fcontest.pas:1447` |
| APSPRINT | **setup** `trdos/fcontest.pas:832` |
| ArizonaQsoParty | **setup** `trdos/fcontest.pas:561` |
| COLORADOQSOPARTY | **ui** `uNewContest.pas:267` |
| IDAHOQSOPARTY | **scoring** `trdos/logstuff.pas:6512` |
| INQSOPARTY | **multipliers** `trdos/logdupe.pas:1295` |
| MINI40 | **setup** `trdos/fcontest.pas:1740` |
| MINI80 | **setup** `trdos/fcontest.pas:1732` |
| MINITEST | **setup** `trdos/fcontest.pas:1732` |
| MOQSOPARTY | **setup** `trdos/fcontest.pas:1130` |
| MST | **ui** `uNewContest.pas:355` |
| PAQSOPARTY | **scoring** `trdos/logstuff.pas:7431` |
| TENNESSEEQSOPARTY | **setup** `trdos/LogCfg.pas:890` |
| TEXASQSOPARTY | **setup** `trdos/fcontest.pas:1563` |
| WISCONSINQSOPARTY | **setup** `trdos/LogCfg.pas:882` |
| XMAS | **exchange** `trdos/logdupe.pas:1890` |

### 6.2 Contests with no class

**83** -- every contest without a class (185 non-sentinel enum values minus
102) appears at least once in section 4 or section 5.
Contests that exist only as an operator-configured name, with no
`ContestType` at all, appear only in the shape-3 rows: **TRC Digital** (`cMyState = 'TRC'`, 5 sites) and **PGA** (`ContestTitle = 'PGA'`, 2 sites).

| contest | sites outside the factory, by category |
|---|---|
| POTA | **exchange** `MainUnit.pas:4045`, `MainUnit.pas:7096`, `trdos/logdupe.pas:1755`, `trdos/logstuff.pas:10344`; **adif-import** `MainUnit.pas:9967`, `trdos/logstuff.pas:10981`; **adif-export** `trdos/postunit.pas:2304`, `trdos/postunit.pas:2312`, `trdos/postunit.pas:2392`, `uADIF.pas:1651`; **ui** `MainUnit.pas:4512`, `uNewContest.pas:233`, `uNewContest.pas:377`; **setup** `trdos/fcontest.pas:1281` |
| RDA | **scoring** `trdos/logstuff.pas:8229`; **exchange** `trdos/logdom.pas:224`, `trdos/logedit.pas:2621`, `trdos/logstuff.pas:10438`; **multipliers** `trdos/logedit.pas:1029`; **adif-export** `trdos/postunit.pas:2377`; **ui** `uNewContest.pas:223`, `uNewContest.pas:312`; **setup** `trdos/fcontest.pas:1340` |
| ARRL160 | **scoring** `trdos/logstuff.pas:6549`; **multipliers** `trdos/logdupe.pas:695`; **adif-import** `MainUnit.pas:9964`; **adif-export** `trdos/postunit.pas:2386`; **ui** `uNewContest.pas:180`, `uNewContest.pas:310`; **setup** `trdos/LogCfg.pas:890`, `trdos/fcontest.pas:733` |
| ALLASIANCW | **scoring** `trdos/logstuff.pas:6403`; **exchange** `trdos/logdupe.pas:1768`; **ui** `uNewContest.pas:412`; **setup** `trdos/LogCfg.pas:890`, `trdos/fcontest.pas:682`; **networking** `uExchangeBuilder.pas:179`; **other** `trdos/logddx.pas:1061` |
| ALLASIANSSB | **scoring** `trdos/logstuff.pas:6403`; **exchange** `trdos/logdupe.pas:1768`; **ui** `uNewContest.pas:412`; **setup** `trdos/LogCfg.pas:890`, `trdos/fcontest.pas:682`; **networking** `uExchangeBuilder.pas:179`; **other** `trdos/logddx.pas:1061` |
| CQMM | **scoring** `trdos/logstuff.pas:9331`; **exchange** `MainUnit.pas:7265`, `trdos/logdupe.pas:1658`; **multipliers** `trdos/logedit.pas:2901`, `trdos/logedit.pas:2913`; **ui** `uNewContest.pas:291`; **setup** `trdos/fcontest.pas:1864` |
| CQWWRTTY | **scoring** `trdos/logstuff.pas:7043`; **exchange** `trdos/logdupe.pas:1897`; **score-summary** `trdos/postunit.pas:1156`; **ui** `MainUnit.pas:4465`, `uNewContest.pas:193`, `uNewContest.pas:310`; **setup** `trdos/fcontest.pas:312` |
| JIDXCW | **scoring** `trdos/logstuff.pas:7921`; **exchange** `trdos/logedit.pas:2768`; **ui** `uNewContest.pas:238`, `uNewContest.pas:320`; **setup** `trdos/LogCfg.pas:899`, `trdos/fcontest.pas:642`, `trdos/fcontest.pas:1955` |
| JIDXSSB | **scoring** `trdos/logstuff.pas:7921`; **exchange** `trdos/logedit.pas:2768`; **ui** `uNewContest.pas:238`, `uNewContest.pas:320`; **setup** `trdos/LogCfg.pas:899`, `trdos/fcontest.pas:642`, `trdos/fcontest.pas:1955` |
| RAEM | **scoring** `trdos/logstuff.pas:8138`, `trdos/logstuff.pas:8150`; **exchange** `trdos/logdupe.pas:1690`, `uCallSignRoutines.pas:674`; **ui** `uNewContest.pas:284`; **setup** `trdos/LogCfg.pas:892`, `trdos/fcontest.pas:1305` |
| SOUTHAMERICANWW | **scoring** `trdos/logstuff.pas:8445`; **exchange** `MainUnit.pas:7265`, `MainUnit.pas:7269`, `trdos/logdupe.pas:1658`; **multipliers** `trdos/logedit.pas:2901`, `trdos/logedit.pas:2918`; **setup** `trdos/fcontest.pas:662` |
| ARI_DX | **scoring** `trdos/logstuff.pas:6469`; **multipliers** `trdos/logdupe.pas:708`; **ui** `uNewContest.pas:209`, `uNewContest.pas:322`; **setup** `trdos/fcontest.pas:713`; **other** `trdos/logddx.pas:296` |
| ARRL10 | **scoring** `trdos/logstuff.pas:6563`; **multipliers** `trdos/logdupe.pas:695`; **cabrillo-export** `trdos/postunit.pas:2637`; **ui** `uNewContest.pas:180`, `uNewContest.pas:310`; **setup** `trdos/fcontest.pas:721` |
| GAGARINCUP | **scoring** `trdos/logstuff.pas:9292`; **multipliers** `trdos/logedit.pas:2933`, `trdos/logedit.pas:2935`; **ui** `uNewContest.pas:214`, `uNewContest.pas:332`; **setup** `trdos/fcontest.pas:1040` |
| WRTC | **scoring** `trdos/logstuff.pas:9400`; **ui** `MainUnit.pas:4483`, `MainUnit.pas:6467`, `trdos/logedit.pas:1713`; **setup** `trdos/fcontest.pas:1778`; **networking** `trdos/logsubs2.pas:2771` |
| HELVETIA | **scoring** `trdos/logstuff.pas:7750`; **ui** `uNewContest.pas:209`, `uNewContest.pas:321`; **setup** `trdos/LogCfg.pas:931`, `trdos/fcontest.pas:1025` |
| OZCR_O | **exchange** `trdos/logedit.pas:2391`; **score-summary** `uTotal.pas:263`; **ui** `uNewContest.pas:294`; **setup** `trdos/LogCfg.pas:899`, `trdos/fcontest.pas:1818` |
| R9W_UW9WK_MEMORIAL | **scoring** `trdos/logstuff.pas:9389`; **exchange** `trdos/logdupe.pas:1702`; **ui** `uNewContest.pas:297`; **setup** `trdos/LogCfg.pas:888`, `trdos/fcontest.pas:1714` |
| RFASCHAMPIONSHIPCW | **scoring** `trdos/logstuff.pas:9092`; **exchange** `trdos/logdupe.pas:1690`; **ui** `uNewContest.pas:300`; **setup** `trdos/LogCfg.pas:888`, `trdos/fcontest.pas:1790` |
| RTC | **scoring** `trdos/logstuff.pas:8496`; **ui** `uNewContest.pas:301`; **setup** `trdos/fcontest.pas:797`; **networking** `uExchangeBuilder.pas:112`, `uExchangeBuilder.pas:205` |
| UA4WCHAMPIONSHIP | **scoring** `trdos/logstuff.pas:8857`; **exchange** `trdos/logstuff.pas:10012`; **ui** `uNewContest.pas:409`; **setup** `trdos/LogCfg.pas:892`, `trdos/fcontest.pas:1709` |
| YBDX | **scoring** `trdos/logstuff.pas:8359`; **exchange** `MainUnit.pas:7256`, `MainUnit.pas:7259`; **multipliers** `trdos/logedit.pas:2899`; **setup** `trdos/fcontest.pas:1394` |
| YODX | **scoring** `trdos/logstuff.pas:8723`; **multipliers** `trdos/logedit.pas:1035`; **ui** `uNewContest.pas:220`, `uNewContest.pas:328`; **setup** `trdos/fcontest.pas:1692` |
| YOTA | **scoring** `trdos/logstuff.pas:9620`; **exchange** `trdos/logdupe.pas:1768`; **ui** `uNewContest.pas:412`; **setup** `trdos/fcontest.pas:694`; **other** `trdos/logddx.pas:1061` |
| BSCI | **scoring** `trdos/logstuff.pas:7764`; **multipliers** `trdos/logdupe.pas:752`; **ui** `uNewContest.pas:225`, `uNewContest.pas:340` |
| BWQP | **scoring** `trdos/logstuff.pas:6718`; **exchange** `MainUnit.pas:7096`, `trdos/logdupe.pas:1838`, `trdos/logstuff.pas:10344` |
| CIS | **scoring** `trdos/logstuff.pas:6729`; **ui** `uNewContest.pas:206`, `uNewContest.pas:338`; **setup** `trdos/fcontest.pas:872` |
| EUDX | **scoring** `trdos/logstuff.pas:9562`; **ui** `uNewContest.pas:220`, `uNewContest.pas:317`; **setup** `trdos/fcontest.pas:991` |
| FISTS | **scoring** `trdos/logstuff.pas:7579`; **exchange** `trdos/logdupe.pas:1881`, `trdos/logdupe.pas:1976`, `trdos/logdupe.pas:2112` |
| HADX | **scoring** `trdos/logstuff.pas:7589`; **ui** `uNewContest.pas:212`, `uNewContest.pas:329`; **setup** `trdos/fcontest.pas:975` |
| IRTS | **scoring** `trdos/logstuff.pas:9562`; **ui** `uNewContest.pas:196`, `uNewContest.pas:316`; **setup** `trdos/fcontest.pas:980` |
| JTDX | **scoring** `trdos/logstuff.pas:8960`; **multipliers** `trdos/logdupe.pas:717`, `trdos/logedit.pas:2923`; **setup** `trdos/fcontest.pas:1839` |
| KINGOFSPAINCW | **scoring** `trdos/logstuff.pas:9273`; **ui** `uNewContest.pas:209`, `uNewContest.pas:319`; **setup** `trdos/fcontest.pas:1856` |
| KINGOFSPAINSSB | **scoring** `trdos/logstuff.pas:9273`; **ui** `uNewContest.pas:209`, `uNewContest.pas:319`; **setup** `trdos/fcontest.pas:1856` |
| MAKROTHEN | **scoring** `trdos/logstuff.pas:7342`; **exchange** `trdos/logdupe.pas:1798`; **ui** `uNewContest.pas:301`; **setup** `trdos/LogCfg.pas:877` |
| OKOMSSB | **scoring** `trdos/logstuff.pas:8099`; **ui** `uNewContest.pas:220`, `uNewContest.pas:325`; **setup** `trdos/fcontest.pas:1240` |
| OLDNEWYEAR | **scoring** `trdos/logstuff.pas:9072`; **ui** `uNewContest.pas:286`; **setup** `trdos/LogCfg.pas:890`, `trdos/fcontest.pas:1772` |
| OZCR_Z | **scoring** `trdos/logstuff.pas:7806`; **exchange** `trdos/logedit.pas:2391`; **setup** `trdos/LogCfg.pas:899`, `trdos/fcontest.pas:1035` |
| RADIOMEMORY | **scoring** `trdos/logstuff.pas:9206`; **exchange** `trdos/logdupe.pas:1761`; **ui** `uNewContest.pas:290`; **setup** `trdos/LogCfg.pas:882` |
| RADIOVHFFD | **scoring** `trdos/logstuff.pas:7310`; **ui** `uNewContest.pas:303`; **setup** `trdos/LogCfg.pas:927`, `trdos/fcontest.pas:945` |
| RSGB18 | **scoring** `trdos/logstuff.pas:8197`; **score-summary** `trdos/logedit.pas:2876`; **ui** `uNewContest.pas:220`, `uNewContest.pas:337` |
| RSGB_ROPOCO_CW | **scoring** `trdos/logstuff.pas:8749`; **exchange** `trdos/logdupe.pas:1809`; **ui** `uNewContest.pas:287`; **setup** `trdos/fcontest.pas:1324` |
| RSGB_ROPOCO_SSB | **scoring** `trdos/logstuff.pas:8749`; **exchange** `trdos/logdupe.pas:1809`; **ui** `uNewContest.pas:287`; **setup** `trdos/fcontest.pas:1324` |
| SPDX | **scoring** `trdos/logstuff.pas:8748`; **ui** `uNewContest.pas:220`, `uNewContest.pas:339`; **setup** `trdos/fcontest.pas:1401` |
| TENTEN | **scoring** `trdos/logstuff.pas:8533`; **exchange** `trdos/logdupe.pas:1664`; **setup** `trdos/fcontest.pas:1557`; **other** `trdos/logddx.pas:858` |
| UNDX | **scoring** `trdos/logstuff.pas:9251`; **ui** `uNewContest.pas:206`, `uNewContest.pas:323`; **setup** `trdos/fcontest.pas:1850` |
| YUDX | **scoring** `trdos/logstuff.pas:7656`; **ui** `uNewContest.pas:212`, `uNewContest.pas:330`; **setup** `trdos/fcontest.pas:997` |
| ARCI | **scoring** `trdos/logstuff.pas:6453`; **exchange** `trdos/logdupe.pas:1781`; **setup** `trdos/fcontest.pas:707` |
| ARRLVHFJUN | **scoring** `trdos/logstuff.pas:6580`; **ui** `uNewContest.pas:301`; **setup** `trdos/fcontest.pas:823` |
| ARRLVHFSEP | **scoring** `trdos/logstuff.pas:6580`; **ui** `uNewContest.pas:301`; **setup** `trdos/fcontest.pas:823` |
| CQVHF | **scoring** `trdos/logstuff.pas:6827`; **ui** `uNewContest.pas:301`; **setup** `trdos/fcontest.pas:909` |
| CWOPEN | **ui** `uNewContest.pas:355`; **setup** `trdos/LogCfg.pas:939`; **networking** `uExchangeBuilder.pas:197` |
| EUROPEANVHF | **scoring** `trdos/logstuff.pas:7490`; **ui** `uNewContest.pas:303`; **setup** `trdos/fcontest.pas:956` |
| EUSPRINT_AUTUMN_CW | **ui** `uNewContest.pas:275`; **setup** `trdos/LogCfg.pas:933`, `trdos/fcontest.pas:938` |
| EUSPRINT_AUTUMN_SSB | **ui** `uNewContest.pas:275`; **setup** `trdos/LogCfg.pas:933`, `trdos/fcontest.pas:938` |
| EUSPRINT_SPRING_CW | **ui** `uNewContest.pas:275`; **setup** `trdos/LogCfg.pas:933`, `trdos/fcontest.pas:938` |
| EUSPRINT_SPRING_SSB | **ui** `uNewContest.pas:275`; **setup** `trdos/LogCfg.pas:933`, `trdos/fcontest.pas:938` |
| KCJ | **scoring** `trdos/logstuff.pas:7994`; **ui** `uNewContest.pas:372`; **setup** `trdos/fcontest.pas:1083` |
| MWC | **scoring** `trdos/logstuff.pas:7734`; **ui** `uNewContest.pas:169`; **setup** `trdos/fcontest.pas:1134` |
| NEWENGLANDQSO | **ui** `uNewContest.pas:177`, `uNewContest.pas:308`; **setup** `trdos/fcontest.pas:1185` |
| RADIOYOC | **scoring** `trdos/logstuff.pas:8748`; **exchange** `MainUnit.pas:8018`, `trdos/logdupe.pas:1696` |
| REFCW | **scoring** `trdos/logstuff.pas:9189`; **ui** `uNewContest.pas:203`, `uNewContest.pas:315` |
| REFSSB | **scoring** `trdos/logstuff.pas:9189`; **ui** `uNewContest.pas:203`, `uNewContest.pas:315` |
| SST | **ui** `uNewContest.pas:349`; **setup** `trdos/fcontest.pas:1141`; **networking** `uExchangeBuilder.pas:193` |
| STEWPERRY | **scoring** `trdos/logstuff.pas:8468`; **ui** `uNewContest.pas:301`; **setup** `trdos/fcontest.pas:674` |
| WWPMC | **scoring** `trdos/logstuff.pas:8940`; **ui** `uNewContest.pas:231`, `uNewContest.pas:346` |
| ARRLVHFJAN | **scoring** `trdos/logstuff.pas:6580`; **ui** `uNewContest.pas:301` |
| BALTIC | **scoring** `trdos/logstuff.pas:6688`; **setup** `trdos/fcontest.pas:839` |
| CQM | **scoring** `trdos/logstuff.pas:6772`; **setup** `trdos/fcontest.pas:903` |
| CQWPXRTTY | **scoring** `trdos/logstuff.pas:6947`; **setup** `trdos/fcontest.pas:1778` |
| SEVENQP | **setup** `trdos/LogCfg.pas:890`, `trdos/fcontest.pas:1796` |
| TESLA | **scoring** `trdos/logstuff.pas:7531`; **ui** `uNewContest.pas:305` |
| GACWWWSACW | **scoring** `trdos/logstuff.pas:9147` |
| IN7QPNE | **scoring** `trdos/logstuff.pas:7431` |
| OCEANIADXCW | **scoring** `trdos/logstuff.pas:8636` |
| OCEANIADXSSB | **scoring** `trdos/logstuff.pas:8636` |
| REGION1FIELDDAY | **scoring** `trdos/logstuff.pas:7141` |
| REGION1FIELDDAY_RCC_CW | **scoring** `trdos/logstuff.pas:9108` |
| REGION1FIELDDAY_RCC_SSB | **scoring** `trdos/logstuff.pas:9108` |
| TOEC | **scoring** `trdos/logstuff.pas:8543` |
| UCG | **scoring** `trdos/logstuff.pas:6911` |
| WWIH | **scoring** `trdos/logstuff.pas:7043` |
| WWL | **scoring** `trdos/logstuff.pas:8700` |

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
registered contests (the class scores and `Exit`s first), and a `case
ActiveExchange of` arm in the shared export arms (`uCabrilloExchange` /
`uADIFExchange`, TContestBase's default since M4) reached only by classes that
format their own exchange (19 classes).

| arm | routine | value | reached by |
|---|---|---|---|
| `trdos/logstuff.pas:6488` | CalculateQSOPoints | `ARRLDXQSOPointMethod` | ARRLDXCW, ARRLDXSSB |
| `trdos/logstuff.pas:6512` | CalculateQSOPoints | `ARRLFieldDayQSOPointMethod` | ARRLFIELDDAY, IDAHOQSOPARTY, WINTERFIELDDAY |
| `trdos/logstuff.pas:6535` | CalculateQSOPoints | `ARRLDIGIQSOPointMethod` | ARRLDIGI |
| `trdos/logstuff.pas:6617` | CalculateQSOPoints | `ALRSUA1DZCupQSOPointMethod` | ALRS_UA1DZ_CUP |
| `trdos/logstuff.pas:6753` | CalculateQSOPoints | `CQ160QSOPointMethod` | CQ160CW, CQ160SSB |
| `trdos/logstuff.pas:7024` | CalculateQSOPoints | `CQWWQSOPointMethod` | CQWWCW, CQWWSSB |
| `trdos/logstuff.pas:7057` | CalculateQSOPoints | `CroatianQSOPointMethod` | CROATIAN |
| `trdos/logstuff.pas:7297` | CalculateQSOPoints | `FOCMarathonQSOPointMethod` | FOCMARATHON |
| `trdos/logstuff.pas:7368` | CalculateQSOPoints | `NCQSOPointMethod` | NCQSOPARTY |
| `trdos/logstuff.pas:7417` | CalculateQSOPoints | `BCQPQSOPointMethod` | BCQP |
| `trdos/logstuff.pas:7468` | CalculateQSOPoints | `OZHCRVHFQSOPointMethod` | OZHCRVHF |
| `trdos/logstuff.pas:7674` | CalculateQSOPoints | `UKEIQSOPointMethod` | UKEI |
| `trdos/logstuff.pas:7886` | CalculateQSOPoints | `IOTAQSOPointMethod` | IOTA |
| `trdos/logstuff.pas:8028` | CalculateQSOPoints | `NZFieldDayQSOPointMethod` | NZFIELDDAY |
| `trdos/logstuff.pas:8053` | CalculateQSOPoints | `OKDXQSOPointMethod` | OKDX |
| `trdos/logstuff.pas:8165` | CalculateQSOPoints | `RACQSOPointMethod` | CANADA_DAY, CANADA_WINTER |
| `trdos/logstuff.pas:8263` | CalculateQSOPoints | `RussianDXQSOPointMethod` | RU3AXMEMORIAL, RUSSIANDX |
| `trdos/logstuff.pas:8307` | CalculateQSOPoints | `SalmonRunQSOPointMethod` | SALMONRUN |
| `trdos/logstuff.pas:8319` | CalculateQSOPoints | `ScandinavianQSOPointMethod` | SACCW, SACSSB |
| `trdos/logstuff.pas:8398` | CalculateQSOPoints | `YBFT8QP` | BATAVIA_FT8 |
| `trdos/logstuff.pas:8489` | CalculateQSOPoints | `WWDigiQP` | WWDIGI |
| `trdos/logstuff.pas:8559` | CalculateQSOPoints | `UBAQSOPointMethod` | UBACW, UBASSB |
| `trdos/logstuff.pas:8607` | CalculateQSOPoints | `UkrainianQSOPointMethod` | UKRAINIAN |
| `trdos/logstuff.pas:8653` | CalculateQSOPoints | `WAGQSOPointMethod` | WAG |
| `trdos/logstuff.pas:8681` | CalculateQSOPoints | `WAEQSOPointMethod` | DARCWAEDCCW, DARCWAEDCSSB |
| `trdos/logstuff.pas:8745` | CalculateQSOPoints | `AlwaysOnePointPerQSO` | INTERNETSPRINT, YOUTHCHAMPIONSHIPRF |
| `trdos/logstuff.pas:8747` | CalculateQSOPoints | `TwoPointsPerQSO` | ARRLSSCW, ARRLSSSSB, COLORADOQSOPARTY, INQSOPARTY, MINNQSOPARTY, NRAUBALTICCW, NRAUBALTICSSB, XMAS |
| `trdos/logstuff.pas:8813` | CalculateQSOPoints | `CupRFMethod` | CUPRFCW, CUPRFDIG, CUPRFSSB |
| `trdos/logstuff.pas:8908` | CalculateQSOPoints | `ChampionshipRFMethod` | RFCHAMPIONSHIPCW, RFCHAMPIONSHIPSSB |
| `trdos/logstuff.pas:8930` | CalculateQSOPoints | `ChampionshipUkrMethod` | UKRAINECHAMPIONSHIP |
| `trdos/logstuff.pas:9001` | CalculateQSOPoints | `LABREQSOPointMethod` | LABRE |
| `trdos/logstuff.pas:9039` | CalculateQSOPoints | `LZDXQSOPointMethod` | LZDX |
| `trdos/logstuff.pas:9168` | CalculateQSOPoints | `LQPQSOPointMethod` | LQP |
| `trdos/logstuff.pas:9177` | CalculateQSOPoints | `ArktikaSpringQSOPointMethod` | ARKTIKA_SPRING |
| `trdos/logstuff.pas:9221` | CalculateQSOPoints | `PCCQSOPointMethod` | PCC |
| `trdos/logstuff.pas:9546` | CalculateQSOPoints | `VAQSOPOINTMETHOD` | VAQP |

### 9.2 Class traits the engine contradicts (D8)

**344** trait overrides checked (`GetQSOPointMethod`, `GetExchangeKind`,
`GetDomesticMultiplierType`, `GetDXMultiplierType`), each against the value the
ENGINE uses -- the last `FoundContest` arm assignment for the contest, else its
`ContestsArray` row. **22** disagree or could not be read:

| contest | getter | class says | engine uses | row | FoundContest arms |
|---|---|---|---|---|---|
| ALRS_UA1DZ_CUP | GETDOMESTICMULTIPLIERTYPE | `WYSIWYGDomestic` | `RDADistrict` | `WYSIWYGDomestic` | `RDADistrict` |
| ALRS_UA1DZ_CUP | GETDXMULTIPLIERTYPE | `CQDXCC` | `NoDXMults` | `CQDXCC` | `NoDXMults` |
| ArizonaQsoParty | GETEXCHANGEKIND | `RSTDomesticOrDXQTHExchange` | `RSTDomesticQTHExchange` | `RSTDomesticOrDXQTHExchange` | `RSTDomesticQTHExchange` |
| CALQSOPARTY | GETEXCHANGEKIND | `QSONumberDomesticOrDXQTHExchange` | `QSONumberDomesticQTHExchange` | `QSONumberDomesticOrDXQTHExchange` | `QSONumberDomesticOrDXQTHExchange`, `QSONumberDomesticQTHExchange` |
| CROATIAN | GETDXMULTIPLIERTYPE | `NoDXMults` | `CQDXCC` | `NODXMULTS` | `CQDXCC` |
| DARC10M | GETDOMESTICMULTIPLIERTYPE | `WYSIWYGDomestic` | `DOKCodes` | `WYSIWYGDomestic` | `DOKCodes` |
| DARCWAEDCCW | GETDXMULTIPLIERTYPE | `NoDXMults` | `CQEuropeanCountries` | `NoDXMults` | `CQEuropeanCountries` |
| DARCWAEDCSSB | GETDXMULTIPLIERTYPE | `NoDXMults` | `CQEuropeanCountries` | `NoDXMults` | `CQEuropeanCountries` |
| OKDX | GETDOMESTICMULTIPLIERTYPE | `NoDomesticMults` | `DomesticFile` | `NoDomesticMults` | `DomesticFile` |
| PACC | GETEXCHANGEKIND | `RSTAndQSONumberOrDomesticQTHExchange` | `RSTDomesticQTHExchange` | `RSTAndQSONumberOrDomesticQTHExchange` | `RSTAndQSONumberOrDomesticQTHExchange`, `RSTDomesticQTHExchange` |
| PACC | GETDXMULTIPLIERTYPE | `NoDXMults` | `PACCCountriesAndPrefixes` | `NoDXMults` | `PACCCountriesAndPrefixes` |
| SACCW | GETDXMULTIPLIERTYPE | `NoDXMults` | `ARRLDXCC` | `NoDXMults` | `ARRLDXCC` |
| SACSSB | GETDXMULTIPLIERTYPE | `NoDXMults` | `ARRLDXCC` | `NoDXMults` | `ARRLDXCC` |
| SALMONRUN | GETEXCHANGEKIND | `RSTDomesticOrDXQTHExchange` | `RSTDomesticQTHExchange` | `RSTDomesticOrDXQTHExchange` | `RSTDomesticOrDXQTHExchange`, `RSTDomesticQTHExchange` |
| SALMONRUN | GETDXMULTIPLIERTYPE | `NoDXMults` | `ARRLDXCCWithNoUSAOrCanada` | `NoDXMults` | `ARRLDXCCWithNoUSAOrCanada` |
| TEXASQSOPARTY | GETEXCHANGEKIND | `RSTDomesticOrDXQTHExchange` | `RSTDomesticQTHExchange` | `RSTDomesticOrDXQTHExchange` | `RSTDomesticQTHExchange` |
| TEXASQSOPARTY | GETDXMULTIPLIERTYPE | `NoDXMults` | `ARRLDXCCWithNoUSACanadaKH6OrKL7` | `NoDXMults` | `ARRLDXCCWithNoUSACanadaKH6OrKL7` |
| UBACW | GETDXMULTIPLIERTYPE | `CQUBAEuropeanCountries` | `CQDXCC` | `CQUBAEuropeanCountries` | `CQDXCC` |
| UBASSB | GETDXMULTIPLIERTYPE | `CQUBAEuropeanCountries` | `CQDXCC` | `CQUBAEuropeanCountries` | `CQDXCC` |
| UKRAINIAN | GETDOMESTICMULTIPLIERTYPE | `DomesticFile` | `NoDomesticMults` | `DomesticFile` | `NoDomesticMults` |
| WAG | GETDOMESTICMULTIPLIERTYPE | `NoDomesticMults` | `DOKCodes` | `NoDomesticMults` | `DOKCodes` |
| WAG | GETDXMULTIPLIERTYPE | `NoDXMults` | `CQDXCC` | `NoDXMults` | `CQDXCC` |

### 9.3 Contest identity: what the class says, what the exporters emit (D9)

- **139** contests have a blank `ContestsArray` `ADIFName` (excluding
  GENERALQSO, POTA, which write no `CONTEST_ID`), so their exported id is the
  `ContestTypeSA` spelling and import cannot resolve it; **71** of them are
  registered: ALLJA, ARRLDIGI, ARRLDXCW, ARRLDXSSB, ARRLSSCW, ARRLSSSSB, COUNTYHUNTER, CQ160CW, CQ160SSB, CQWPXCW, CQWPXSSB, CQWWCW, CQWWSSB, CROATIAN, CUPRFCW, CUPRFSSB, CUPRFDIG, CUPURAL, FOCMARATHON, GRIDLOC, UKEI, IARU, INTERNETSPRINT, IOTA, JALONGPREFECT, KIDSDAY, KVP, LABRE, LZDX, MARCONIMEMORIAL, MINITEST, NAQSOCW, NAQSOSSB, NAQSORTTY, NASPRINTCW, NASPRINTRTTY, NCCCSPRINT, NRAUBALTICCW, NRAUBALTICSSB, OKDX, PACC, QCWA, QCWAGOLDEN, CANADA_WINTER, RFCHAMPIONSHIPCW, RFCHAMPIONSHIPSSB, RUSSIANDX, SACCW, SACSSB, UBACW, UBASSB, UKRAINECHAMPIONSHIP, UKRAINIAN, DARCWAEDCCW, DARCWAEDCSSB, DARCXMAS, WAG, XMAS, YOUTHCHAMPIONSHIPRF, RU3AXMEMORIAL, LQP, ARKTIKA_SPRING, PCC, DARC10M, SASPRINT, OZHCRVHF, CANADA_DAY, CQIR, ALRS_UA1DZ_CUP, BATAVIA_FT8, WWDIGI.
- 174 literal identity getters (`GetCabrilloName`, `GetADIFContestId`) were
  compared with what the exporters emit; **0** differ.

### 9.4 Shape 1 against shapes 1 + 2, per file (section 8.2)

Shape 1 (the global `Contest` only): **52** in 10 files. Shapes 1 + 2 (testing
the VALUE rather than the operand): **62** in 13 files. A `case` counts
once here; `Lint-ContestNameTests` counts its contest-naming arms instead (section 9.5).

| file | shape 1 | shapes 1 + 2 |
|---|---:|---:|
| `MainUnit.pas` | 11 | **12** |
| `trdos/LogCfg.pas` | 1 | 1 |
| `trdos/fcontest.pas` | 4 | 4 |
| `trdos/logdupe.pas` | 5 | 5 |
| `trdos/logedit.pas` | 8 | 8 |
| `trdos/logstuff.pas` | 3 | 3 |
| `trdos/logsubs2.pas` | 3 | 3 |
| `trdos/logwind.pas` | 1 | 1 |
| `trdos/postunit.pas` | 11 | **14** |
| `uADIF.pas` | -- | **1** |
| `uExchangeBuilder.pas` | -- | **2** |
| `uNewContest.pas` | -- | **3** |
| `uTotal.pas` | 5 | 5 |

### 9.5 Contest-naming `case` arms (section 8.3)

**227** arms across 8 cases.

| case | routine | shape | contest-naming arms |
|---|---|---|---:|
| `trdos/fcontest.pas:547` | FoundContest | 1 | 104 |
| `uNewContest.pas:259` | ApplyContestChoice | 2 | 68 |
| `uNewContest.pas:168` | ApplyIAmIn | 2 | 23 |
| `trdos/LogCfg.pas:875` | tSetupExchangeNumbers | 1 | 14 |
| `uExchangeBuilder.pas:152` | BuildRxExchangeText | 2 | 10 |
| `trdos/logedit.pas:1019` | EditableLog.GetMultArray | 1 | 4 |
| `MainUnit.pas:9963` | ApplyClasslessADIFImport | 2 | 2 |
| `trdos/postunit.pas:2385` | EmitContestSpecificTailForExport | 2 | 2 |
