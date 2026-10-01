# Contest rules outside the contest factory -- an inventory

**GENERATED. Do not edit outside the marked hand-maintained blocks.**
Regenerate with `python tools/contest-rules-inventory/generate.py` (any working
directory). This copy was generated from commit `7d29ea05` (2026-10-01).
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
| 1 | the global `Contest` compared, `in`-tested or cased | **91** in 12 files | 106 | `scan.py` (section 2.1). Rows > sites because a `case` is one site and one row per arm |
| 2 | a contest-typed FIELD or VARIABLE tested: `exch.ceContest`, `rec.ceContest`, `RXData.ceContest`, `SelectedContest` | **14** in 5 files | 132 | `scan.py` |
| 3 | a contest identified by a STRING: contest name/title, a station state, a sponsor or bonus callsign | **24** | 24 | `judgements.SHAPE3`, curated from `scan.string_candidates` (section 2.4) |
| 4 | an `Active*` proxy whose tested value reaches only 1-3 contests by default | **281** of 508 classified | 281 | `scan.classify_proxies` |
| 5 | `FoundContest`'s setup `case Contest of` | 1 case, **104 arms**, 131 contests | 104 | `scan.found_contest_arms` -- its own table, section 5 |

Shape 4 in full: the 148 `Active*` sites (134 comparisons, 14 `case`s) break
into 508 comparison-or-arm records --

| class | records | meaning |
|---|---:|---|
| PROXY, reach 1 | 149 | the tested value reaches exactly ONE contest by default -- a contest rule wearing a disguise |
| PROXY, reach 2-3 | 132 | mostly a CW/SSB pair or a family (ARRL SS, the Field Days, UBA, SAC, REF); **24** of them test a value whose NAME is generic (`ThreePointsPerQSO`, `GridExchange`, `RSTAgeExchange`, ...) and are flagged `GENERIC-NAMED` in the tables -- judge those individually. 4 reach-1 rows carry the same flag |
| PROXY for DUMMYCONTEST | 1 | `NoQSOPointMethod`, the sentinel; dropped |
| SHARED | 157 | reaches 4+ contests -- genuinely shared behaviour, **not a finding**, counted only |
| UNUSED | 69 | reaches NO contest by default -- only an operator's `.cfg` setting can select it (section 1.4) |

### 1.2 By category (table rows; section 4 has every row)

| category | s1 | s2 | s3 | s4 | total |
|---|---:|---:|---:|---:|---:|
| Scoring | 3 | 0 | 10 | 96 | 109 |
| Exchange parsing and validation | 18 | 0 | 1 | 93 | 112 |
| Dupe | 0 | 0 | 0 | 1 | 1 |
| Multipliers | 9 | 0 | 1 | 22 | 32 |
| ADIF import | 0 | 16 | 1 | 2 | 19 |
| ADIF export | 5 | 13 | 1 | 17 | 36 |
| Cabrillo export | 21 | 0 | 7 | 15 | 43 |
| Score, summary and totals | 17 | 0 | 1 | 7 | 25 |
| UI, display and the new-contest dialog | 15 | 92 | 1 | 2 | 110 |
| Setup (FoundContest / LogCfg) | 17 | 0 | 0 | 1 | 18 (+ 104 FoundContest arms, section 5) |
| Networking and score reporting | 1 | 11 | 0 | 0 | 12 |
| Other | 0 | 0 | 1 | 25 | 26 |
| **total** | **106** | **132** | **24** | **281** | **543** (+104) |

### 1.3 Top files (table rows, plus FoundContest's arms)

| file | rows |
|---|---:|
| `trdos/logstuff.pas` | 163 |
| `trdos/fcontest.pas` | 108 (104 setup arms + 4) |
| `uNewContest.pas` | 92 |
| `trdos/logdupe.pas` | 44 |
| `trdos/logedit.pas` | 43 |
| `MainUnit.pas` | 41 |
| `trdos/postunit.pas` | 31 |
| `uCabrilloExchange.pas` | 30 |
| `trdos/logddx.pas` | 26 |
| `uADIFExchange.pas` | 22 |

### 1.4 The headline facts

1. **53 of the 56 registered contests still have rules outside the factory.**
   With none: `FLORIDAQSOPARTY`, `MARCONIMEMORIAL`, `MICHQSOPARTY`. The per-contest index (section 6)
   lists every site, registered contests first.

*Hand-maintained below -- judgement, not measurement. The generator preserves it verbatim and does not re-check it; its line numbers are as of when it was written.*

<!-- BEGIN HAND-MAINTAINED: headline-facts -->
2. **The factory owns per-QSO scoring (`logstuff.pas:6564`), class and DX-QTH
   validation (`:10920`, `:1518`), the QTH count (`:1999`), Arktika's
   Cabrillo line layout (`postunit.pas:3162`), ADIF contest-id lookup on
   import, and -- for the 14 contests whose class sets `FormatsExchange` --
   the Cabrillo and ADIF exchange columns. Nothing else.**
   Exchange parsing, multipliers, dupes, ADIF import, the ADIF contest tail,
   Cabrillo headers, the summary sheet, totals, the UI and session setup are
   still decided outside it for every contest, registered or not.
3. **The class's TRAITS are read by nobody outside the factory.** `ExchangeKind`,
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
**441 files**. Using the tracked list excludes the gitignored `backup/`,
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
- Shape 1 is 3 `case` + 74 comparisons + 14 `in` tests = **91**.
  At `9acdc5bd` that was exactly the set `Lint-ContestNameTests.ps1 -List`
  printed. The lint has since been widened (`c3841b55`) to count by VALUE
  and one per `case` arm -- sections 9.4 and 9.5 are the comparable figures.
  The lint and this scanner are separate implementations, so a
  disagreement between them is worth a look.

### 2.2 Which contests have a class

`RegisterContest(<enum>, <class>)` in `src/contestFactory/`: **56**
(`model.Registry`, which also walks each class's ancestry). All 56 score through their own chain -- none falls through to `TContestBase`'s zero.

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
CABName, DF and FriendlyName): **44** hits today, and lists **47** lines
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
`judgements.ROUTINES`; 2 sites override their routine's category
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

### Scoring (109 rows)

| file:line | routine | shape | contest(s) -- **bold = has a class** | class? | seam | what |
|---|---|---|---|---|---|---|
| `MainUnit.pas:7920` | LoadinLog | 1 | **MOQSOPARTY** | all | new seam needed: CalculateTotalScore (s6) | `Contest` compare |
| `trdos/logdupe.pas:1104` | CheckMOQSOPartyBonusStation | 3 | **MOQSOPARTY** | all | new seam needed: CalculateTotalScore (s6) | bonus callsigns `'W0MA'` / `'K0GQ'` |
| `trdos/logstuff.pas:6600` | CalculateQSOPoints | 4 | ALLASIANCW, ALLASIANSSB | none | CalculateQSOPoints (existing) | reach 2: `QP` = AllAsianQSOPointMethod (arm of case @6571) |
| `trdos/logstuff.pas:6650` | CalculateQSOPoints | 4 | ARCI | none | CalculateQSOPoints (existing) | reach 1: `QP` = ARCIQSOPointMethod (arm of case @6571) |
| `trdos/logstuff.pas:6666` | CalculateQSOPoints | 4 | ARI_DX | none | CalculateQSOPoints (existing) | reach 1: `QP` = ARIQSOPointMethod (arm of case @6571) |
| `trdos/logstuff.pas:6685` | CalculateQSOPoints | 4 | **ARRLDXCW**, **ARRLDXSSB** | all | CalculateQSOPoints (existing) | reach 2: `QP` = ARRLDXQSOPointMethod (arm of case @6571) |
| `trdos/logstuff.pas:6709` | CalculateQSOPoints | 4 | **ARRLFIELDDAY**, **IDAHOQSOPARTY**, **WINTERFIELDDAY** | all | CalculateQSOPoints (existing) | reach 3: `QP` = ARRLFieldDayQSOPointMethod (arm of case @6571) |
| `trdos/logstuff.pas:6732` | CalculateQSOPoints | 4 | **ARRLDIGI** | all | CalculateQSOPoints (existing) | reach 1: `QP` = ARRLDIGIQSOPointMethod (arm of case @6571) |
| `trdos/logstuff.pas:6746` | CalculateQSOPoints | 4 | ARRL160 | none | CalculateQSOPoints (existing) | reach 1: `QP` = ARRL160QSOPointMethod (arm of case @6571) |
| `trdos/logstuff.pas:6760` | CalculateQSOPoints | 4 | ARRL10 | none | CalculateQSOPoints (existing) | reach 1: `QP` = ARRL10QSOPointMethod (arm of case @6571) |
| `trdos/logstuff.pas:6777` | CalculateQSOPoints | 4 | ARRLVHFJAN, ARRLVHFJUN, ARRLVHFSEP | none | CalculateQSOPoints (existing) | reach 3: `QP` = ARRLVHFJUNPointMethod (arm of case @6571) |
| `trdos/logstuff.pas:6814` | CalculateQSOPoints | 4 | ALRS_UA1DZ_CUP | none | CalculateQSOPoints (existing) | reach 1: `QP` = ALRSUA1DZCupQSOPointMethod (arm of case @6571) |
| `trdos/logstuff.pas:6885` | CalculateQSOPoints | 4 | BALTIC | none | CalculateQSOPoints (existing) | reach 1: `QP` = BalticQSOPointMethod (arm of case @6571) |
| `trdos/logstuff.pas:6915` | CalculateQSOPoints | 4 | BWQP | none | CalculateQSOPoints (existing) | reach 1: `QP` = BWQPQSOPointMethod (arm of case @6571) |
| `trdos/logstuff.pas:6926` | CalculateQSOPoints | 4 | CIS | none | CalculateQSOPoints (existing) | reach 1: `QP` = CISQSOPointMethod (arm of case @6571) |
| `trdos/logstuff.pas:6950` | CalculateQSOPoints | 4 | CQ160CW, CQ160SSB | none | CalculateQSOPoints (existing) | reach 2: `QP` = CQ160QSOPointMethod (arm of case @6571) |
| `trdos/logstuff.pas:6969` | CalculateQSOPoints | 4 | CQM | none | CalculateQSOPoints (existing) | reach 1: `QP` = CQMQSOPointMethod (arm of case @6571) |
| `trdos/logstuff.pas:7024` | CalculateQSOPoints | 4 | CQVHF | none | CalculateQSOPoints (existing) | reach 1: `QP` = CQVHFQSOPointMethod (arm of case @6571) |
| `trdos/logstuff.pas:7108` | CalculateQSOPoints | 4 | **CQWPXCW**, **CQWPXSSB**, UCG | some: CQWPXCW, CQWPXSSB | CalculateQSOPoints (existing) | reach 3: `QP` = CQWPXQSOPointMethod (arm of case @6571) |
| `trdos/logstuff.pas:7144` | CalculateQSOPoints | 4 | CQWPXRTTY | none | CalculateQSOPoints (existing) | reach 1: `QP` = CQWPXRTTYQSOPointMethod (arm of case @6571) |
| `trdos/logstuff.pas:7195` | CalculateQSOPoints | 3 | (none by default) | - | CalculateQSOPoints (existing) | `Settings.Contest.Title = 'DL-DX-RTTY'` in the DLRTTY arm -- see dead code |
| `trdos/logstuff.pas:7221` | CalculateQSOPoints | 4 | **CQWWCW**, **CQWWSSB** | all | CalculateQSOPoints (existing) | reach 2: `QP` = CQWWQSOPointMethod (arm of case @6571) |
| `trdos/logstuff.pas:7240` | CalculateQSOPoints | 4 | CQWWRTTY, WWIH | none | CalculateQSOPoints (existing) | reach 2: `QP` = CQWWRTTYQSOPointMethod (arm of case @6571) |
| `trdos/logstuff.pas:7254` | CalculateQSOPoints | 4 | CROATIAN | none | CalculateQSOPoints (existing) | reach 1: `QP` = CroatianQSOPointMethod (arm of case @6571) |
| `trdos/logstuff.pas:7336` | CalculateQSOPoints | 4 | REGION1FIELDDAY | none | CalculateQSOPoints (existing) | reach 1: `QP` = EuropeanFieldDayQSOPointMethod (arm of case @6571) |
| `trdos/logstuff.pas:7492` | CalculateQSOPoints | 4 | FOCMARATHON | none | CalculateQSOPoints (existing) | reach 1: `QP` = FOCMarathonQSOPointMethod (arm of case @6571) |
| `trdos/logstuff.pas:7494` | CalculateQSOPoints | 3 | FOCMARATHON | none | CalculateQSOPoints (existing) | bonus callsign `'G4FOC'` |
| `trdos/logstuff.pas:7505` | CalculateQSOPoints | 4 | RADIOVHFFD | none | CalculateQSOPoints (existing) | reach 1: `QP` = RadioVHFFDQSOPointMethod (arm of case @6571) |
| `trdos/logstuff.pas:7537` | CalculateQSOPoints | 4 | MAKROTHEN | none | CalculateQSOPoints (existing) | reach 1: `QP` = MakrothenQSOPointMethod (arm of case @6571) |
| `trdos/logstuff.pas:7563` | CalculateQSOPoints | 4 | **NCQSOPARTY** | all | CalculateQSOPoints (existing) | reach 1: `QP` = NCQSOPointMethod (arm of case @6571) |
| `trdos/logstuff.pas:7578` | CalculateQSOPoints | 3 | **NCQSOPARTY** | all | CalculateQSOPoints (existing) | seven bonus callsigns `'N4T'`..`'N4L'` -- arm is dead, see dead code |
| `trdos/logstuff.pas:7612` | CalculateQSOPoints | 4 | **BCQP** | all | CalculateQSOPoints (existing) | reach 1: `QP` = BCQPQSOPointMethod (arm of case @6571) |
| `trdos/logstuff.pas:7626` | CalculateQSOPoints | 4 | IN7QPNE, **PAQSOPARTY** | some: PAQSOPARTY | CalculateQSOPoints (existing) | reach 2: `QP` = PAQSOPointMethod (arm of case @6571) |
| `trdos/logstuff.pas:7663` | CalculateQSOPoints | 4 | OZHCRVHF | none | CalculateQSOPoints (existing) | reach 1: `QP` = OZHCRVHFQSOPointMethod (arm of case @6571) |
| `trdos/logstuff.pas:7685` | CalculateQSOPoints | 4 | EUROPEANVHF | none | CalculateQSOPoints (existing) | reach 1: `QP` = EuropeanVHFQSOPointMethod (arm of case @6571) |
| `trdos/logstuff.pas:7690` | CalculateQSOPoints | 3 | (none by default) | - | CalculateQSOPoints (existing) | `Settings.Contest.Name = 'EURASIA'` in the EuropeanVHF arm -- see dead code |
| `trdos/logstuff.pas:7726` | CalculateQSOPoints | 4 | TESLA | none | CalculateQSOPoints (existing) | reach 1: `QP` = TeslaQSOPointMethod (arm of case @6571) |
| `trdos/logstuff.pas:7774` | CalculateQSOPoints | 4 | FISTS | none | CalculateQSOPoints (existing) | reach 1: `QP` = FistsQSOPointMethod (arm of case @6571) |
| `trdos/logstuff.pas:7784` | CalculateQSOPoints | 4 | HADX | none | CalculateQSOPoints (existing) | reach 1: `QP` = HADXQSOPointMethod (arm of case @6571) |
| `trdos/logstuff.pas:7805` | CalculateQSOPoints | 3 | (none by default) | - | CalculateQSOPoints (existing) | `DomesticQTH = 'TRC'` in the TRCDIGITAL arm |
| `trdos/logstuff.pas:7817` | CalculateQSOPoints | 3 | (none by default) | - | CalculateQSOPoints (existing) | `Settings.My.State = 'TRC'` |
| `trdos/logstuff.pas:7851` | CalculateQSOPoints | 4 | YUDX | none | CalculateQSOPoints (existing) | reach 1: `QP` = YUDXQSOPointMethod (arm of case @6571) |
| `trdos/logstuff.pas:7869` | CalculateQSOPoints | 4 | UKEI | none | CalculateQSOPoints (existing) | reach 1: `QP` = UKEIQSOPointMethod (arm of case @6571) |
| `trdos/logstuff.pas:7927` | CalculateQSOPoints | 4 | MWC | none | CalculateQSOPoints (existing) | reach 1: `QP` = MWCQP (arm of case @6571) |
| `trdos/logstuff.pas:7943` | CalculateQSOPoints | 4 | HELVETIA | none | CalculateQSOPoints (existing) | reach 1: `QP` = HelvetiaQSOPointMethod (arm of case @6571) |
| `trdos/logstuff.pas:7957` | CalculateQSOPoints | 4 | BSCI | none | CalculateQSOPoints (existing) | reach 1: `QP` = BSCIQSOPointMethod (arm of case @6571) |
| `trdos/logstuff.pas:7999` | CalculateQSOPoints | 4 | **IARU**, OZCR_Z | some: IARU | CalculateQSOPoints (existing) | reach 2: `QP` = IARUQSOPointMethod (arm of case @6571) |
| `trdos/logstuff.pas:8079` | CalculateQSOPoints | 4 | IOTA | none | CalculateQSOPoints (existing) | reach 1: `QP` = IOTAQSOPointMethod (arm of case @6571) |
| `trdos/logstuff.pas:8114` | CalculateQSOPoints | 4 | JIDXCW, JIDXSSB | none | CalculateQSOPoints (existing) | reach 2: `QP` = JapanInternationalDXQSOPointMethod (arm of case @6571) |
| `trdos/logstuff.pas:8187` | CalculateQSOPoints | 4 | KCJ | none | CalculateQSOPoints (existing) | reach 1: `QP` = KCJQSOPointMethod (arm of case @6571) |
| `trdos/logstuff.pas:8221` | CalculateQSOPoints | 4 | NZFIELDDAY | none | CalculateQSOPoints (existing) | reach 1: `QP` = NZFieldDayQSOPointMethod (arm of case @6571) |
| `trdos/logstuff.pas:8246` | CalculateQSOPoints | 4 | OKDX | none | CalculateQSOPoints (existing) | reach 1: `QP` = OKDXQSOPointMethod (arm of case @6571) |
| `trdos/logstuff.pas:8292` | CalculateQSOPoints | 4 | OKOMSSB | none | CalculateQSOPoints (existing) | reach 1: `QP` = OKOMSSBQSOPointMethod (arm of case @6571) |
| `trdos/logstuff.pas:8331` | CalculateQSOPoints | 4 | RAEM | none | CalculateQSOPoints (existing) | reach 1: `QP` = RAEMQSOPointMethod (arm of case @6571) |
| `trdos/logstuff.pas:8343` | CalculateQSOPoints | 3 | RAEM | none | CalculateQSOPoints (existing) | special callsign `'RAEM'` |
| `trdos/logstuff.pas:8358` | CalculateQSOPoints | 4 | CANADA_DAY, CANADA_WINTER | none | CalculateQSOPoints (existing) | reach 2: `QP` = RACQSOPointMethod (arm of case @6571) |
| `trdos/logstuff.pas:8390` | CalculateQSOPoints | 4 | RSGB18 | none | CalculateQSOPoints (existing) | reach 1: `QP` = RSGB160Method (arm of case @6571) |
| `trdos/logstuff.pas:8422` | CalculateQSOPoints | 4 | RDA | none | CalculateQSOPoints (existing) | reach 1: `QP` = RDAQSOPointMethod (arm of case @6571) |
| `trdos/logstuff.pas:8456` | CalculateQSOPoints | 4 | RU3AXMEMORIAL, RUSSIANDX | none | CalculateQSOPoints (existing) | reach 2: `QP` = RussianDXQSOPointMethod (arm of case @6571) |
| `trdos/logstuff.pas:8493` | CalculateQSOPoints | 1 | RU3AXMEMORIAL | none | CalculateQSOPoints (existing) | `Contest` compare |
| `trdos/logstuff.pas:8500` | CalculateQSOPoints | 4 | **SALMONRUN** | all | CalculateQSOPoints (existing) | reach 1: `QP` = SalmonRunQSOPointMethod (arm of case @6571) |
| `trdos/logstuff.pas:8512` | CalculateQSOPoints | 4 | SACCW, SACSSB | none | CalculateQSOPoints (existing) | reach 2: `QP` = ScandinavianQSOPointMethod (arm of case @6571) |
| `trdos/logstuff.pas:8552` | CalculateQSOPoints | 4 | YBDX | none | CalculateQSOPoints (existing) | reach 1: `QP` = IndonesianQSOPointMethod (arm of case @6571) |
| `trdos/logstuff.pas:8591` | CalculateQSOPoints | 4 | BATAVIA_FT8 | none | CalculateQSOPoints (existing) | reach 1: `QP` = YBFT8QP (arm of case @6571) |
| `trdos/logstuff.pas:8620` | CalculateQSOPoints | 3 | BATAVIA_FT8 | none | CalculateQSOPoints (existing) | `Settings.Contest.Title = 'YBDXDI-FT8'` in the YBFT8QP arm -- see dead code |
| `trdos/logstuff.pas:8638` | CalculateQSOPoints | 4 | SOUTHAMERICANWW | none | CalculateQSOPoints (existing) | reach 1: `QP` = SouthAmericanWWQSOPointMethod (arm of case @6571) |
| `trdos/logstuff.pas:8661` | CalculateQSOPoints | 4 | STEWPERRY | none | CalculateQSOPoints (existing) | reach 1: `QP` = StewPerryQSOPointMethod (arm of case @6571) |
| `trdos/logstuff.pas:8682` | CalculateQSOPoints | 4 | WWDIGI | none | CalculateQSOPoints (existing) | reach 1: `QP` = WWDigiQP (arm of case @6571) |
| `trdos/logstuff.pas:8689` | CalculateQSOPoints | 4 | RTC | none | CalculateQSOPoints (existing) | reach 1: `QP` = RTCQSOPointMethod (arm of case @6571) |
| `trdos/logstuff.pas:8726` | CalculateQSOPoints | 4 | TENTEN | none | CalculateQSOPoints (existing) | reach 1: `QP` = TenTenQSOPointMethod (arm of case @6571) |
| `trdos/logstuff.pas:8736` | CalculateQSOPoints | 4 | TOEC | none | CalculateQSOPoints (existing) | reach 1: `QP` = TOECQSOPointMethod (arm of case @6571) |
| `trdos/logstuff.pas:8752` | CalculateQSOPoints | 4 | UBACW, UBASSB | none | CalculateQSOPoints (existing) | reach 2: `QP` = UBAQSOPointMethod (arm of case @6571) |
| `trdos/logstuff.pas:8800` | CalculateQSOPoints | 4 | UKRAINIAN | none | CalculateQSOPoints (existing) | reach 1: `QP` = UkrainianQSOPointMethod (arm of case @6571) |
| `trdos/logstuff.pas:8829` | CalculateQSOPoints | 4 | OCEANIADXCW, OCEANIADXSSB | none | CalculateQSOPoints (existing) | reach 2: `QP` = VKZLQSOPointMethod (arm of case @6571) |
| `trdos/logstuff.pas:8846` | CalculateQSOPoints | 4 | WAG | none | CalculateQSOPoints (existing) | reach 1: `QP` = WAGQSOPointMethod (arm of case @6571) |
| `trdos/logstuff.pas:8874` | CalculateQSOPoints | 4 | DARCWAEDCCW, DARCWAEDCSSB | none | CalculateQSOPoints (existing) | reach 2: `QP` = WAEQSOPointMethod (arm of case @6571) |
| `trdos/logstuff.pas:8893` | CalculateQSOPoints | 4 | WWL | none | CalculateQSOPoints (existing) | reach 1: `QP` = WWLQSOPointMethod (arm of case @6571) |
| `trdos/logstuff.pas:8916` | CalculateQSOPoints | 4 | YODX | none | CalculateQSOPoints (existing) | reach 1: `QP` = YODXQSOPointMethod (arm of case @6571) |
| `trdos/logstuff.pas:8938` | CalculateQSOPoints | 4 | **INTERNETSPRINT**, **YOUTHCHAMPIONSHIPRF** | all | CalculateQSOPoints (existing) | reach 2 GENERIC-NAMED: `QP` = AlwaysOnePointPerQSO (arm of case @6571) |
| `trdos/logstuff.pas:8941` | CalculateQSOPoints | 4 | **CALQSOPARTY**, RADIOYOC, SPDX | some: CALQSOPARTY | CalculateQSOPoints (existing) | reach 3 GENERIC-NAMED: `QP` = ThreePointsPerQSO (arm of case @6571) |
| `trdos/logstuff.pas:8942` | CalculateQSOPoints | 4 | RSGB_ROPOCO_CW, RSGB_ROPOCO_SSB | none | CalculateQSOPoints (existing) | reach 2 GENERIC-NAMED: `QP` = TenPointsPerQSO (arm of case @6571) |
| `trdos/logstuff.pas:9006` | CalculateQSOPoints | 4 | CUPRFCW, CUPRFDIG, CUPRFSSB | none | CalculateQSOPoints (existing) | reach 3: `QP` = CupRFMethod (arm of case @6571) |
| `trdos/logstuff.pas:9050` | CalculateQSOPoints | 4 | UA4WCHAMPIONSHIP | none | CalculateQSOPoints (existing) | reach 1: `QP` = UA4WMethod (arm of case @6571) |
| `trdos/logstuff.pas:9101` | CalculateQSOPoints | 4 | RFCHAMPIONSHIPCW, RFCHAMPIONSHIPSSB | none | CalculateQSOPoints (existing) | reach 2: `QP` = ChampionshipRFMethod (arm of case @6571) |
| `trdos/logstuff.pas:9123` | CalculateQSOPoints | 4 | UKRAINECHAMPIONSHIP | none | CalculateQSOPoints (existing) | reach 1: `QP` = ChampionshipUkrMethod (arm of case @6571) |
| `trdos/logstuff.pas:9133` | CalculateQSOPoints | 4 | WWPMC | none | CalculateQSOPoints (existing) | reach 1: `QP` = WWPMCQSOPointMethod (arm of case @6571) |
| `trdos/logstuff.pas:9153` | CalculateQSOPoints | 4 | JTDX | none | CalculateQSOPoints (existing) | reach 1: `QP` = JTDXQSOPointMethod (arm of case @6571) |
| `trdos/logstuff.pas:9194` | CalculateQSOPoints | 4 | LABRE | none | CalculateQSOPoints (existing) | reach 1: `QP` = LABREQSOPointMethod (arm of case @6571) |
| `trdos/logstuff.pas:9232` | CalculateQSOPoints | 4 | LZDX | none | CalculateQSOPoints (existing) | reach 1: `QP` = LZDXQSOPointMethod (arm of case @6571) |
| `trdos/logstuff.pas:9265` | CalculateQSOPoints | 4 | OLDNEWYEAR | none | CalculateQSOPoints (existing) | reach 1: `QP` = OldNewYearQSOPointMethod (arm of case @6571) |
| `trdos/logstuff.pas:9285` | CalculateQSOPoints | 4 | RFASCHAMPIONSHIPCW | none | CalculateQSOPoints (existing) | reach 1: `QP` = ChampionshipRFASMethod (arm of case @6571) |
| `trdos/logstuff.pas:9301` | CalculateQSOPoints | 4 | REGION1FIELDDAY_RCC_CW, REGION1FIELDDAY_RCC_SSB | none | CalculateQSOPoints (existing) | reach 2: `QP` = RegionOneFieldDayRCCQSOPointMethod (arm of case @6571) |
| `trdos/logstuff.pas:9340` | CalculateQSOPoints | 4 | GACWWWSACW | none | CalculateQSOPoints (existing) | reach 1: `QP` = GACWWWSACWQSOPointMethod (arm of case @6571) |
| `trdos/logstuff.pas:9361` | CalculateQSOPoints | 4 | LQP | none | CalculateQSOPoints (existing) | reach 1: `QP` = LQPQSOPointMethod (arm of case @6571) |
| `trdos/logstuff.pas:9364` | CalculateQSOPoints | 3 | LQP | none | CalculateQSOPoints (existing) | `Name = 'LOCUST'` / `Callsign = 'K6VVA'` |
| `trdos/logstuff.pas:9370` | CalculateQSOPoints | 4 | **ARKTIKA_SPRING** | all | CalculateQSOPoints (existing) | reach 1: `QP` = ArktikaSpringQSOPointMethod (arm of case @6571) |
| `trdos/logstuff.pas:9382` | CalculateQSOPoints | 4 | REFCW, REFSSB | none | CalculateQSOPoints (existing) | reach 2: `QP` = REFQSOPointMethod (arm of case @6571) |
| `trdos/logstuff.pas:9399` | CalculateQSOPoints | 4 | RADIOMEMORY | none | CalculateQSOPoints (existing) | reach 1: `QP` = RadioMemoryQSOPointMethod (arm of case @6571) |
| `trdos/logstuff.pas:9414` | CalculateQSOPoints | 4 | PCC | none | CalculateQSOPoints (existing) | reach 1: `QP` = PCCQSOPointMethod (arm of case @6571) |
| `trdos/logstuff.pas:9444` | CalculateQSOPoints | 4 | UNDX | none | CalculateQSOPoints (existing) | reach 1: `QP` = UNDXQSOPointMethod (arm of case @6571) |
| `trdos/logstuff.pas:9466` | CalculateQSOPoints | 4 | KINGOFSPAINCW, KINGOFSPAINSSB | none | CalculateQSOPoints (existing) | reach 2: `QP` = KingOfSpainQSOPointMethod (arm of case @6571) |
| `trdos/logstuff.pas:9485` | CalculateQSOPoints | 4 | GAGARINCUP | none | CalculateQSOPoints (existing) | reach 1: `QP` = GagarinCupQSOPointMethod (arm of case @6571) |
| `trdos/logstuff.pas:9524` | CalculateQSOPoints | 4 | CQMM | none | CalculateQSOPoints (existing) | reach 1: `QP` = CQMMQSOPointMethod (arm of case @6571) |
| `trdos/logstuff.pas:9582` | CalculateQSOPoints | 4 | R9W_UW9WK_MEMORIAL | none | CalculateQSOPoints (existing) | reach 1: `QP` = R9WUW9WKMemorialQSOPointMethod (arm of case @6571) |
| `trdos/logstuff.pas:9593` | CalculateQSOPoints | 4 | WRTC | none | CalculateQSOPoints (existing) | reach 1: `QP` = WRTCQSOPointMethod (arm of case @6571) |
| `trdos/logstuff.pas:9739` | CalculateQSOPoints | 4 | **VAQP** | all | CalculateQSOPoints (existing) | reach 1: `QP` = VAQSOPOINTMETHOD (arm of case @6571) |
| `trdos/logstuff.pas:9755` | CalculateQSOPoints | 4 | EUDX, IRTS | none | CalculateQSOPoints (existing) | reach 2: `QP` = EUDXQSOPOINTMETHOD (arm of case @6571) |
| `trdos/logstuff.pas:9813` | CalculateQSOPoints | 4 | YOTA | none | CalculateQSOPoints (existing) | reach 1: `QP` = YOTAQSOPointMethod (arm of case @6571) |
| `trdos/logsubs2.pas:1735` | LogContact | 1 | **MOQSOPARTY** | all | new seam needed: CalculateTotalScore (s6) | `Contest` compare |

### Exchange parsing and validation (112 rows)

| file:line | routine | shape | contest(s) -- **bold = has a class** | class? | seam | what |
|---|---|---|---|---|---|---|
| `MainUnit.pas:922` | ctyLocateCallStripRover | 4 | **COUNTYHUNTER** | all | new seam needed: RoverCallRules | reach 1: `AE` = RSTQTHExchange |
| `MainUnit.pas:963` | DetectRoverSlashInCall | 4 | **COUNTYHUNTER** | all | new seam needed: RoverCallRules | reach 1: `AE` = RSTQTHExchange |
| `MainUnit.pas:2046` | ReturnInSAPOpMode | 4 | **COUNTYHUNTER** | all | new seam needed: RoverCallRules | reach 1: `AE` = RSTQTHEXCHANGE |
| `MainUnit.pas:4039` | ExchangeWindowChange | 4 | POTA | none | new seam needed: ReceivedExchangeFields (s6) | reach 1 GENERIC-NAMED: `AE` = RSTAndPOTAPark |
| `MainUnit.pas:7080` | ParametersOkay | 4 | BWQP, **GENERALQSO**, POTA | some: GENERALQSO | new seam needed: ValidateExchange | reach 3 GENERIC-NAMED: `AE` = RSTNameAndQTHExchange, RSTAndPOTAPark |
| `MainUnit.pas:7235` | ParametersOkay | 4 | UBACW, UBASSB | none | new seam needed: ValidateExchange | reach 2: `Pxm` = BelgiumPrefixes (arm of case @7234) |
| `MainUnit.pas:7239` | ParametersOkay | 4 | SACCW, SACSSB | none | new seam needed: ValidateExchange | reach 2: `Pxm` = SACDistricts (arm of case @7234) |
| `MainUnit.pas:7240` | ParametersOkay | 4 | YBDX | none | new seam needed: ValidateExchange | reach 1: `Pxm` = IndonesianDistricts (arm of case @7234) |
| `MainUnit.pas:7243` | ParametersOkay | 1 | YBDX | none | new seam needed: ValidateExchange | `Contest` compare |
| `MainUnit.pas:7249` | ParametersOkay | 4 | CQMM, **SASPRINT**, SOUTHAMERICANWW | some: SASPRINT | new seam needed: ValidateExchange | reach 3: `Pxm` = SouthAmericanPrefixes (arm of case @7234) |
| `MainUnit.pas:7253` | ParametersOkay | 4 | SOUTHAMERICANWW | none | new seam needed: ValidateExchange | reach 1: `Pxm` = NonSouthAmericanPrefixes (arm of case @7234) |
| `MainUnit.pas:7997` | LoadinLog | 1 | RADIOYOC | none | new seam needed: SessionExchangeState (previous QSO number) | `contest` compare |
| `trdos/logdom.pas:224` | DomQTHTableObject.GetDomQTH | 4 | ALRS_UA1DZ_CUP, RDA | none | new seam needed: ParseDomesticQTH | reach 2: `DM` = RDADistrict |
| `trdos/logdom.pas:247` | DomQTHTableObject.GetDomQTH | 4 | DARC10M, WAG | none | new seam needed: ParseDomesticQTH | reach 2: `DM` = DOKCodes |
| `trdos/logdom.pas:263` | DomQTHTableObject.GetDomQTH | 4 | IOTA | none | new seam needed: ParseDomesticQTH | reach 1: `DM` = IOTADomestic |
| `trdos/logdupe.pas:1632` | SetUpExchangeInformation | 4 | **ARRLFIELDDAY**, **WINTERFIELDDAY** | all | new seam needed: ReceivedExchangeFields (s6) (which fields the exchange carries) | reach 2: `AE` = ClassDomesticOrDXQTHExchange (arm of case @1624) |
| `trdos/logdupe.pas:1638` | SetUpExchangeInformation | 4 | **KIDSDAY** | all | new seam needed: ReceivedExchangeFields (s6) (which fields the exchange carries) | reach 1: `AE` = KidsDayExchange (arm of case @1624) |
| `trdos/logdupe.pas:1643` | SetUpExchangeInformation | 4 | CQMM, SOUTHAMERICANWW | none | new seam needed: ReceivedExchangeFields (s6) (which fields the exchange carries) | reach 2: `AE` = RSTAndContinentExchange (arm of case @1624) |
| `trdos/logdupe.pas:1649` | SetUpExchangeInformation | 4 | TENTEN | none | new seam needed: ReceivedExchangeFields (s6) (which fields the exchange carries) | reach 1: `AE` = NameQTHAndPossibleTenTenNumber (arm of case @1624) |
| `trdos/logdupe.pas:1662` | SetUpExchangeInformation | 4 | **GRIDLOC** | all | new seam needed: ReceivedExchangeFields (s6) (which fields the exchange carries) | reach 1: `AE` = NameAndPossibleGridSquareExchange (arm of case @1624) |
| `trdos/logdupe.pas:1668` | SetUpExchangeInformation | 4 | NZFIELDDAY | none | new seam needed: ReceivedExchangeFields (s6) (which fields the exchange carries) | reach 1: `AE` = NZFieldDayExchange (arm of case @1624) |
| `trdos/logdupe.pas:1675` | SetUpExchangeInformation | 4 | RAEM, RFASCHAMPIONSHIPCW | none | new seam needed: ReceivedExchangeFields (s6) (which fields the exchange carries) | reach 2: `AE` = QSONumberAndCoordinatesSum, QSONumberAndGeoCoordinates (arm of case @1624) |
| `trdos/logdupe.pas:1681` | SetUpExchangeInformation | 4 | RADIOYOC | none | new seam needed: ReceivedExchangeFields (s6) (which fields the exchange carries) | reach 1: `AE` = QSONumberAndPreviousQSONumber (arm of case @1624) |
| `trdos/logdupe.pas:1687` | SetUpExchangeInformation | 4 | R9W_UW9WK_MEMORIAL, RFCHAMPIONSHIPCW, RFCHAMPIONSHIPSSB | none | new seam needed: ReceivedExchangeFields (s6) (which fields the exchange carries) | reach 3: `AE` = QSONumberAndZone (arm of case @1624) |
| `trdos/logdupe.pas:1706` | SetUpExchangeInformation | 4 | **QCWA**, **QCWAGOLDEN** | all | new seam needed: ReceivedExchangeFields (s6) (which fields the exchange carries) | reach 2: `AE` = QSONumberNameChapterAndQTHExchange (arm of case @1624) |
| `trdos/logdupe.pas:1721` | SetUpExchangeInformation | 4 | **ARRLSSCW**, **ARRLSSSSB** | all | new seam needed: ReceivedExchangeFields (s6) (which fields the exchange carries) | reach 2: `AE` = QSONumberPrecedenceCheckDomesticQTHExchange (arm of case @1624) |
| `trdos/logdupe.pas:1729` | SetUpExchangeInformation | 4 | **YOUTHCHAMPIONSHIPRF** | all | new seam needed: ReceivedExchangeFields (s6) (which fields the exchange carries) | reach 1: `AE` = AgeAndQSONumberExchange (arm of case @1624) |
| `trdos/logdupe.pas:1740` | SetUpExchangeInformation | 4 | POTA | none | new seam needed: ReceivedExchangeFields (s6) (which fields the exchange carries) | reach 1 GENERIC-NAMED: `AE` = RSTAndPOTAPark (arm of case @1624) |
| `trdos/logdupe.pas:1746` | SetUpExchangeInformation | 4 | RADIOMEMORY | none | new seam needed: ReceivedExchangeFields (s6) (which fields the exchange carries) | reach 1: `AE` = RSTAgeAndPossibleSK (arm of case @1624) |
| `trdos/logdupe.pas:1753` | SetUpExchangeInformation | 4 | ALLASIANCW, ALLASIANSSB, YOTA | none | new seam needed: ReceivedExchangeFields (s6) (which fields the exchange carries) | reach 3 GENERIC-NAMED: `AE` = RSTAgeExchange (arm of case @1624) |
| `trdos/logdupe.pas:1759` | SetUpExchangeInformation | 4 | **ALLJA** | all | new seam needed: ReceivedExchangeFields (s6) (which fields the exchange carries) | reach 1: `AE` = RSTALLJAPrefectureAndPrecedenceExchange (arm of case @1624) |
| `trdos/logdupe.pas:1766` | SetUpExchangeInformation | 4 | ARCI | none | new seam needed: ReceivedExchangeFields (s6) (which fields the exchange carries) | reach 1: `AE` = RSTPossibleDomesticQTHAndPower (arm of case @1624) |
| `trdos/logdupe.pas:1773` | SetUpExchangeInformation | 4 | **ARRLDIGI**, WWDIGI | some: ARRLDIGI | new seam needed: ReceivedExchangeFields (s6) (which fields the exchange carries) | reach 2: `AE` = Grid2Exchange (arm of case @1624) |
| `trdos/logdupe.pas:1783` | SetUpExchangeInformation | 4 | BATAVIA_FT8, MAKROTHEN | none | new seam needed: ReceivedExchangeFields (s6) (which fields the exchange carries) | reach 2 GENERIC-NAMED: `AE` = GridExchange (arm of case @1624) |
| `trdos/logdupe.pas:1794` | SetUpExchangeInformation | 4 | RSGB_ROPOCO_CW, RSGB_ROPOCO_SSB | none | new seam needed: ReceivedExchangeFields (s6) (which fields the exchange carries) | reach 2: `AE` = RSTAndPostalCodeExchange (arm of case @1624) |
| `trdos/logdupe.pas:1823` | SetUpExchangeInformation | 4 | BWQP, **GENERALQSO** | some: GENERALQSO | new seam needed: ReceivedExchangeFields (s6) (which fields the exchange carries) | reach 2 GENERIC-NAMED: `AE` = RSTNameAndQTHExchange (arm of case @1624) |
| `trdos/logdupe.pas:1866` | SetUpExchangeInformation | 4 | FISTS | none | new seam needed: ReceivedExchangeFields (s6) (which fields the exchange carries) | reach 1: `AE` = RSTQTHNameAndFistsNumberOrPowerExchange (arm of case @1624) |
| `trdos/logdupe.pas:1875` | SetUpExchangeInformation | 4 | **XMAS** | all | new seam needed: ReceivedExchangeFields (s6) (which fields the exchange carries) | reach 1: `AE` = RSTQSONumberAndRandomCharactersExchange (arm of case @1624) |
| `trdos/logdupe.pas:1882` | SetUpExchangeInformation | 4 | CQWWRTTY | none | new seam needed: ReceivedExchangeFields (s6) (which fields the exchange carries) | reach 1: `AE` = RSTZoneAndPossibleDomesticQTHExchange (arm of case @1624) |
| `trdos/logdupe.pas:1902` | SetUpExchangeInformation | 4 | **JALONGPREFECT** | all | new seam needed: ReceivedExchangeFields (s6) (which fields the exchange carries) | reach 1: `AE` = RSTLongJAPrefectureExchange (arm of case @1624) |
| `trdos/logdupe.pas:1961` | ParseExchangeIntoContestExchange | 4 | FISTS | none | new seam needed: ParseReceivedExchange (s6) | reach 1: `AE` = RSTQTHNameAndFistsNumberOrPowerExchange |
| `trdos/logdupe.pas:2074` | GetInitialExchangeStringFromContestExchange | 4 | **ALLJA** | all | new seam needed: InitialExchangeFromHistory | reach 1: `AE` = RSTALLJAPrefectureAndPrecedenceExchange |
| `trdos/logdupe.pas:2097` | GetInitialExchangeStringFromContestExchange | 4 | FISTS | none | new seam needed: InitialExchangeFromHistory | reach 1: `AE` = RSTQTHNameAndFistsNumberOrPowerExchange |
| `trdos/logedit.pas:2239` | InitialExchangeEntry | 4 | **CQWWCW** | all | new seam needed: InitialExchangeFromHistory (InitialExchangeKind is the existing trait) | reach 1: `AIE` = CustomInitialExchange (arm of case @2237) |
| `trdos/logedit.pas:2386` | InitialExchangeEntry | 1 | OZCR_O, OZCR_Z | none | new seam needed: InitialExchangeFromHistory (InitialExchangeKind is the existing trait) | `Contest` in |
| `trdos/logedit.pas:2404` | InitialExchangeEntry | 1 | RFCHAMPIONSHIPCW, RFCHAMPIONSHIPSSB | none | new seam needed: InitialExchangeFromHistory (InitialExchangeKind is the existing trait) | `Contest` in |
| `trdos/logedit.pas:2521` | InitialExchangeEntry | 4 | **ARRLSSCW**, **ARRLSSSSB** | all | new seam needed: InitialExchangeFromHistory (InitialExchangeKind is the existing trait) | reach 2: `AIE` = CheckSectionInitialExchange (arm of case @2237) |
| `trdos/logedit.pas:2616` | InitialExchangeEntry | 1 | RDA, RU3AXMEMORIAL, RUSSIANDX | none | new seam needed: InitialExchangeFromHistory (InitialExchangeKind is the existing trait) | `Contest` in |
| `trdos/logedit.pas:2644` | InitialExchangeEntry | 4 | **CALQSOPARTY**, **VAQP** | all | new seam needed: InitialExchangeFromHistory (InitialExchangeKind is the existing trait) | reach 2 GENERIC-NAMED: `AE` = QSONumberDomesticOrDXQTHExchange |
| `trdos/logedit.pas:2647` | InitialExchangeEntry | 4 | CUPRFCW, CUPRFDIG, CUPRFSSB | none | new seam needed: InitialExchangeFromHistory (InitialExchangeKind is the existing trait) | reach 3: `AE` = QSONumberAndGridSquare |
| `trdos/logedit.pas:2652` | InitialExchangeEntry | 4 | NRAUBALTICCW, NRAUBALTICSSB, **OHIOQSOPARTY** | some: OHIOQSOPARTY | new seam needed: InitialExchangeFromHistory (InitialExchangeKind is the existing trait) | reach 3 GENERIC-NAMED: `AE` = RSTQSONumberAndDomesticQTHExchange |
| `trdos/logedit.pas:2653` | InitialExchangeEntry | 4 | **CQIR** | all | new seam needed: InitialExchangeFromHistory (InitialExchangeKind is the existing trait) | reach 1: `AE` = QSONumberAndPossibleDomesticQTHExchange |
| `trdos/logedit.pas:2669` | InitialExchangeEntry | 4 | **ARRLSSCW**, **ARRLSSSSB** | all | new seam needed: InitialExchangeFromHistory (InitialExchangeKind is the existing trait) | reach 2: `AE` = QSONumberPrecedenceCheckDomesticQTHEXchange |
| `trdos/logedit.pas:2681` | InitialExchangeEntry | 1 | **IARU** | all | new seam needed: InitialExchangeFromHistory (InitialExchangeKind is the existing trait) | `Contest` compare |
| `trdos/logedit.pas:2763` | InitialExchangeEntry | 4 | JIDXCW, JIDXSSB | none | new seam needed: InitialExchangeFromHistory (InitialExchangeKind is the existing trait) | reach 2: `AE` = RSTPrefectureExchange |
| `trdos/logstuff.pas:2779` | LooksLikeACallSign | 1 | PCC | none | new seam needed: IsAcceptableCallsign | `contest` compare |
| `trdos/logstuff.pas:4047` | ProcessRSTAndDomesticQTHExchange | 1 | **IARU** | all | new seam needed: ParseReceivedExchange (s6) | `CONTEST` compare |
| `trdos/logstuff.pas:4415` | ProcessRSTAndQSONumberExchange | 1 | SACCW | none | new seam needed: ParseReceivedExchange (s6) | `contest` compare |
| `trdos/logstuff.pas:4415` | ProcessRSTAndQSONumberExchange | 1 | SACSSB | none | new seam needed: ParseReceivedExchange (s6) | `contest` compare |
| `trdos/logstuff.pas:4842` | ProcessRSTQSONumberAndPossibleDomesticQTHExchange | 1 | UKEI | none | new seam needed: ParseReceivedExchange (s6) | `Contest` compare |
| `trdos/logstuff.pas:5308` | ProcessRSTAndQSONumberOrDomesticQTHExchange | 4 | CANADA_DAY, CANADA_WINTER | none | new seam needed: ParseReceivedExchange (s6) | reach 2: `QP` = RACQSOPointMethod |
| `trdos/logstuff.pas:5316` | ProcessRSTAndQSONumberOrDomesticQTHExchange | 4 | PCC | none | new seam needed: ParseReceivedExchange (s6) | reach 1: `QP` = PCCQSOPointMethod |
| `trdos/logstuff.pas:5334` | ProcessRSTAndQSONumberOrDomesticQTHExchange | 4 | **ARKTIKA_SPRING** | all | new seam needed: ParseReceivedExchange (s6) | reach 1: `QP` = ArktikaSpringQSOPointMethod |
| `trdos/logstuff.pas:5762` | ProcessRSTAndZoneExchange | 4 | **EUROPEANHFC**, **KVP** | all | new seam needed: ParseReceivedExchange (s6) | reach 2: `ZnM` = EUHFCYear |
| `trdos/logstuff.pas:10199` | ProcessRSTAndGridSquareOrRDAExchange | 1 | UA4WCHAMPIONSHIP | none | new seam needed: ParseReceivedExchange (s6) | `Contest` compare |
| `trdos/logstuff.pas:10204` | ProcessRSTAndGridSquareOrRDAExchange | 1 | ALRS_UA1DZ_CUP | none | new seam needed: ParseReceivedExchange (s6) | `Contest` compare |
| `trdos/logstuff.pas:10241` | ProcessExchange | 4 | BWQP, **GENERALQSO**, POTA | some: GENERALQSO | new seam needed: ParseReceivedExchange (s6), keyed today by the ExchangeKind trait | reach 3 GENERIC-NAMED: `AE` = RSTNameAndQTHExchange, RSTAndPOTAPark |
| `trdos/logstuff.pas:10249` | ProcessExchange | 4 | UA4WCHAMPIONSHIP | none | new seam needed: ParseReceivedExchange (s6), keyed today by the ExchangeKind trait | reach 1: `AE` = RSTAndGridSquareOrRDAExchange (arm of case @10247) |
| `trdos/logstuff.pas:10257` | ProcessExchange | 4 | **ARRLFIELDDAY**, **WINTERFIELDDAY** | all | new seam needed: ParseReceivedExchange (s6), keyed today by the ExchangeKind trait | reach 2: `AE` = ClassDomesticOrDXQTHExchange (arm of case @10247) |
| `trdos/logstuff.pas:10264` | ProcessExchange | 4 | **KIDSDAY** | all | new seam needed: ParseReceivedExchange (s6), keyed today by the ExchangeKind trait | reach 1: `AE` = KidsDayExchange (arm of case @10247) |
| `trdos/logstuff.pas:10267` | ProcessExchange | 4 | TENTEN | none | new seam needed: ParseReceivedExchange (s6), keyed today by the ExchangeKind trait | reach 1: `AE` = NameQTHAndPossibleTenTenNumber (arm of case @10247) |
| `trdos/logstuff.pas:10275` | ProcessExchange | 4 | **GRIDLOC** | all | new seam needed: ParseReceivedExchange (s6), keyed today by the ExchangeKind trait | reach 1: `AE` = NameAndPossibleGridSquareExchange (arm of case @10247) |
| `trdos/logstuff.pas:10282` | ProcessExchange | 4 | RAEM | none | new seam needed: ParseReceivedExchange (s6), keyed today by the ExchangeKind trait | reach 1: `AE` = QSONumberAndGeoCoordinates (arm of case @10247) |
| `trdos/logstuff.pas:10286` | ProcessExchange | 4 | RFASCHAMPIONSHIPCW | none | new seam needed: ParseReceivedExchange (s6), keyed today by the ExchangeKind trait | reach 1: `AE` = QSONumberAndCoordinatesSum (arm of case @10247) |
| `trdos/logstuff.pas:10290` | ProcessExchange | 4 | R9W_UW9WK_MEMORIAL, RFCHAMPIONSHIPCW, RFCHAMPIONSHIPSSB | none | new seam needed: ParseReceivedExchange (s6), keyed today by the ExchangeKind trait | reach 3: `AE` = QSONumberAndZone (arm of case @10247) |
| `trdos/logstuff.pas:10293` | ProcessExchange | 4 | **CALQSOPARTY**, **VAQP** | all | new seam needed: ParseReceivedExchange (s6), keyed today by the ExchangeKind trait | reach 2 GENERIC-NAMED: `AE` = QSONumberDomesticOrDXQTHExchange (arm of case @10247) |
| `trdos/logstuff.pas:10301` | ProcessExchange | 4 | CUPRFCW, CUPRFDIG, CUPRFSSB | none | new seam needed: ParseReceivedExchange (s6), keyed today by the ExchangeKind trait | reach 3: `AE` = QSONumberAndGridSquare (arm of case @10247) |
| `trdos/logstuff.pas:10305` | ProcessExchange | 4 | **QCWA**, **QCWAGOLDEN** | all | new seam needed: ParseReceivedExchange (s6), keyed today by the ExchangeKind trait | reach 2: `AE` = QSONumberNameChapterAndQTHExchange (arm of case @10247) |
| `trdos/logstuff.pas:10313` | ProcessExchange | 4 | ALLASIANCW, ALLASIANSSB, YOTA | none | new seam needed: ParseReceivedExchange (s6), keyed today by the ExchangeKind trait | reach 3 GENERIC-NAMED: `AE` = RSTAgeExchange (arm of case @10247) |
| `trdos/logstuff.pas:10320` | ProcessExchange | 4 | **YOUTHCHAMPIONSHIPRF** | all | new seam needed: ParseReceivedExchange (s6), keyed today by the ExchangeKind trait | reach 1: `AE` = AgeAndQSONumberExchange (arm of case @10247) |
| `trdos/logstuff.pas:10326` | ProcessExchange | 4 | RADIOMEMORY | none | new seam needed: ParseReceivedExchange (s6), keyed today by the ExchangeKind trait | reach 1: `AE` = RSTAgeAndPossibleSK (arm of case @10247) |
| `trdos/logstuff.pas:10329` | ProcessExchange | 4 | CQMM, SOUTHAMERICANWW | none | new seam needed: ParseReceivedExchange (s6), keyed today by the ExchangeKind trait | reach 2: `AE` = RSTAndContinentExchange (arm of case @10247) |
| `trdos/logstuff.pas:10332` | ProcessExchange | 4 | **ALLJA** | all | new seam needed: ParseReceivedExchange (s6), keyed today by the ExchangeKind trait | reach 1: `AE` = RSTALLJAPrefectureAndPrecedenceExchange (arm of case @10247) |
| `trdos/logstuff.pas:10336` | ProcessExchange | 4 | WWL | none | new seam needed: ParseReceivedExchange (s6), keyed today by the ExchangeKind trait | reach 1: `AE` = RSTAndGridExchange (arm of case @10247) |
| `trdos/logstuff.pas:10343` | ProcessExchange | 4 | BATAVIA_FT8, MAKROTHEN | none | new seam needed: ParseReceivedExchange (s6), keyed today by the ExchangeKind trait | reach 2 GENERIC-NAMED: `AE` = GridExchange (arm of case @10247) |
| `trdos/logstuff.pas:10346` | ProcessExchange | 4 | **ARRLDIGI**, WWDIGI | some: ARRLDIGI | new seam needed: ParseReceivedExchange (s6), keyed today by the ExchangeKind trait | reach 2: `AE` = Grid2Exchange (arm of case @10247) |
| `trdos/logstuff.pas:10353` | ProcessExchange | 4 | RSGB_ROPOCO_CW, RSGB_ROPOCO_SSB | none | new seam needed: ParseReceivedExchange (s6), keyed today by the ExchangeKind trait | reach 2: `AE` = RSTAndPostalCodeExchange (arm of case @10247) |
| `trdos/logstuff.pas:10356` | ProcessExchange | 4 | POTA | none | new seam needed: ParseReceivedExchange (s6), keyed today by the ExchangeKind trait | reach 1 GENERIC-NAMED: `AE` = RSTAndPOTAPark (arm of case @10247) |
| `trdos/logstuff.pas:10363` | ProcessExchange | 4 | REFCW, REFSSB | none | new seam needed: ParseReceivedExchange (s6), keyed today by the ExchangeKind trait | reach 2: `AE` = RSTAndQSONumberOrFrenchDepartmentExchange (arm of case @10247) |
| `trdos/logstuff.pas:10371` | ProcessExchange | 1 | LABRE | none | new seam needed: ParseReceivedExchange (s6), keyed today by the ExchangeKind trait | `Contest` compare |
| `trdos/logstuff.pas:10394` | ProcessExchange | 4 | BWQP, **GENERALQSO** | some: GENERALQSO | new seam needed: ParseReceivedExchange (s6), keyed today by the ExchangeKind trait | reach 2 GENERIC-NAMED: `AE` = RSTNameAndQTHExchange (arm of case @10247) |
| `trdos/logstuff.pas:10397` | ProcessExchange | 4 | ARCI | none | new seam needed: ParseReceivedExchange (s6), keyed today by the ExchangeKind trait | reach 1: `AE` = RSTPossibleDomesticQTHAndPower (arm of case @10247) |
| `trdos/logstuff.pas:10404` | ProcessExchange | 4 | JIDXCW, JIDXSSB | none | new seam needed: ParseReceivedExchange (s6), keyed today by the ExchangeKind trait | reach 2: `AE` = RSTPrefectureExchange (arm of case @10247) |
| `trdos/logstuff.pas:10410` | ProcessExchange | 4 | NZFIELDDAY | none | new seam needed: ParseReceivedExchange (s6), keyed today by the ExchangeKind trait | reach 1: `AE` = NZFieldDayExchange (arm of case @10247) |
| `trdos/logstuff.pas:10413` | ProcessExchange | 4 | NRAUBALTICCW, NRAUBALTICSSB, **OHIOQSOPARTY** | some: OHIOQSOPARTY | new seam needed: ParseReceivedExchange (s6), keyed today by the ExchangeKind trait | reach 3 GENERIC-NAMED: `AE` = RSTQSONumberAndDomesticQTHExchange (arm of case @10247) |
| `trdos/logstuff.pas:10417` | ProcessExchange | 4 | RADIOYOC | none | new seam needed: ParseReceivedExchange (s6), keyed today by the ExchangeKind trait | reach 1: `AE` = QSONumberAndPreviousQSONumber (arm of case @10247) |
| `trdos/logstuff.pas:10435` | ProcessExchange | 4 | **CQIR** | all | new seam needed: ParseReceivedExchange (s6), keyed today by the ExchangeKind trait | reach 1: `AE` = QSONumberAndPossibleDomesticQTHExchange (arm of case @10247) |
| `trdos/logstuff.pas:10440` | ProcessExchange | 4 | **XMAS** | all | new seam needed: ParseReceivedExchange (s6), keyed today by the ExchangeKind trait | reach 1: `AE` = RSTQSONumberAndRandomCharactersExchange (arm of case @10247) |
| `trdos/logstuff.pas:10444` | ProcessExchange | 4 | FISTS | none | new seam needed: ParseReceivedExchange (s6), keyed today by the ExchangeKind trait | reach 1: `AE` = RSTQTHNameAndFistsNumberOrPowerExchange (arm of case @10247) |
| `trdos/logstuff.pas:10448` | ProcessExchange | 4 | **COUNTYHUNTER** | all | new seam needed: ParseReceivedExchange (s6), keyed today by the ExchangeKind trait | reach 1: `AE` = RSTQTHExchange (arm of case @10247) |
| `trdos/logstuff.pas:10451` | ProcessExchange | 4 | CQWWRTTY | none | new seam needed: ParseReceivedExchange (s6), keyed today by the ExchangeKind trait | reach 1: `AE` = RSTZoneAndPossibleDomesticQTHExchange (arm of case @10247) |
| `trdos/logstuff.pas:10470` | ProcessExchange | 4 | **ARRLSSCW**, **ARRLSSSSB** | all | new seam needed: ParseReceivedExchange (s6), keyed today by the ExchangeKind trait | reach 2: `AE` = QSONumberPrecedenceCheckDomesticQTHExchange (arm of case @10247) |
| `trdos/logstuff.pas:10475` | ProcessExchange | 4 | **JALONGPREFECT** | all | new seam needed: ParseReceivedExchange (s6), keyed today by the ExchangeKind trait | reach 1: `AE` = RSTLongJAPrefectureExchange (arm of case @10247) |
| `trdos/logstuff.pas:10570` | DomStringParse | 4 | ALRS_UA1DZ_CUP, RDA | none | new seam needed: ParseDomesticQTH | reach 2: `DM` = RDADistrict |
| `trdos/logstuff.pas:10584` | DomStringParse | 4 | DARC10M, WAG | none | new seam needed: ParseDomesticQTH | reach 2: `DM` = DOKCodes |
| `trdos/logstuff.pas:10599` | DomStringParse | 4 | IOTA | none | new seam needed: ParseDomesticQTH | reach 1: `DM` = IOTADomestic |
| `trdos/logstuff.pas:10938` | ValidClass | 1 | **ARRLFIELDDAY** | all | ValidateClass (existing) -- already answers first; see dead code | `contest` compare |
| `trdos/logstuff.pas:10939` | ValidClass | 1 | **WINTERFIELDDAY** | all | ValidateClass (existing) -- already answers first; see dead code | `contest` compare |
| `trdos/logstuff.pas:10967` | ValidClass | 1 | **ARRLFIELDDAY** | all | ValidateClass (existing) -- already answers first; see dead code | `contest` compare |
| `trdos/logstuff.pas:10971` | ValidClass | 1 | **WINTERFIELDDAY** | all | ValidateClass (existing) -- already answers first; see dead code | `contest` compare |
| `trdos/zonecont.pas:92` | GetVEInitialExchange | 4 | RU3AXMEMORIAL, RUSSIANDX | none | new seam needed: InitialExchangeFromHistory | reach 2: `QP` = RussianDXQSOPointMethod |
| `uCallSignRoutines.pas:669` | IsAGoodCall | 3 | RAEM | none | new seam needed: IsAcceptableCallsign | `Call = 'RAEM'` accepted as a callsign |

### Dupe (1 rows)

| file:line | routine | shape | contest(s) -- **bold = has a class** | class? | seam | what |
|---|---|---|---|---|---|---|
| `trdos/logsubs2.pas:1614` | LogContact | 4 | **INTERNETSPRINT**, **YOUTHCHAMPIONSHIPRF** | all | new seam needed: MarksDupes (trait) | reach 2 GENERIC-NAMED: `QP` = AlwaysOnePointPerQSO |

### Multipliers (32 rows)

| file:line | routine | shape | contest(s) -- **bold = has a class** | class? | seam | what |
|---|---|---|---|---|---|---|
| `trdos/logdupe.pas:683` | GetDXQTH | 4 | ARRL10, ARRL160, **WINTERFIELDDAY** | some: WINTERFIELDDAY | DXMultiplierType (existing trait) + new seam needed: DXMultiplierRule | reach 3 GENERIC-NAMED: `XM` = ARRLDXCCWithNoARRLSections (arm of case @670) |
| `trdos/logdupe.pas:696` | GetDXQTH | 4 | ARI_DX | none | DXMultiplierType (existing trait) + new seam needed: DXMultiplierRule | reach 1: `XM` = ARRLDXCCWithNoIOrIS0 (arm of case @670) |
| `trdos/logdupe.pas:705` | GetDXQTH | 4 | JTDX | none | DXMultiplierType (existing trait) + new seam needed: DXMultiplierRule | reach 1: `XM` = ARRLDXCCWithNoJT (arm of case @670) |
| `trdos/logdupe.pas:716` | GetDXQTH | 4 | DARCWAEDCCW, DARCWAEDCSSB | none | DXMultiplierType (existing trait) + new seam needed: DXMultiplierRule | reach 2: `XM` = CQEuropeanCountries (arm of case @670) |
| `trdos/logdupe.pas:722` | GetDXQTH | 4 | UBACW, UBASSB | none | DXMultiplierType (existing trait) + new seam needed: DXMultiplierRule | reach 2: `XM` = CQUBAEuropeanCountries (arm of case @670) |
| `trdos/logdupe.pas:740` | GetDXQTH | 4 | BSCI | none | DXMultiplierType (existing trait) + new seam needed: DXMultiplierRule | reach 1: `XM` = BlackSeaCountries (arm of case @670) |
| `trdos/logdupe.pas:748` | GetDXQTH | 4 | PACC | none | DXMultiplierType (existing trait) + new seam needed: DXMultiplierRule | reach 1: `XM` = PACCCountriesAndPrefixes (arm of case @670) |
| `trdos/logdupe.pas:1272` | DupeAndMultSheet.SetMultFlags | 1 | **BCQP** | all | new seam needed: MultiplierValue (s6) | `Contest` compare |
| `trdos/logdupe.pas:1276` | DupeAndMultSheet.SetMultFlags | 1 | **NYQP** | all | new seam needed: MultiplierValue (s6) | `Contest` compare |
| `trdos/logdupe.pas:1280` | DupeAndMultSheet.SetMultFlags | 1 | **INQSOPARTY** | all | new seam needed: MultiplierValue (s6) | `Contest` compare |
| `trdos/logdupe.pas:1297` | DupeAndMultSheet.SetMultFlags | 1 | PCC | none | new seam needed: MultiplierValue (s6) | `contest` compare |
| `trdos/logdupe.pas:1307` | DupeAndMultSheet.SetMultFlags | 1 | NZFIELDDAY | none | new seam needed: MultiplierValue (s6) | `Contest` compare |
| `trdos/logdupe.pas:2256` | DupeAndMultSheet.SetUpRemainingMultiplierArrays | 4 | **EUROPEANHFC**, **KVP** | all | ZoneMultiplierType (existing trait) + new seam needed: RemainingMultList | reach 2: `ZnM` = EUHFCYear (arm of case @2254) |
| `trdos/logdupe.pas:2259` | DupeAndMultSheet.SetUpRemainingMultiplierArrays | 4 | NZFIELDDAY | none | ZoneMultiplierType (existing trait) + new seam needed: RemainingMultList | reach 1: `ZnM` = BranchZones (arm of case @2254) |
| `trdos/logdupe.pas:2260` | DupeAndMultSheet.SetUpRemainingMultiplierArrays | 4 | RFCHAMPIONSHIPCW, RFCHAMPIONSHIPSSB | none | ZoneMultiplierType (existing trait) + new seam needed: RemainingMultList | reach 2: `ZnM` = RFChampionchipZones (arm of case @2254) |
| `trdos/logedit.pas:1015` | EditableLog.GetMultArray | 1 | RFCHAMPIONSHIPCW, RFCHAMPIONSHIPSSB, RUSSIANDX | none | new seam needed: DomesticMultFromQTH | arm of `case Contest of` @1014 |
| `trdos/logedit.pas:1021` | EditableLog.GetMultArray | 1 | CUPURAL | none | new seam needed: DomesticMultFromQTH | arm of `case Contest of` @1014 |
| `trdos/logedit.pas:1024` | EditableLog.GetMultArray | 1 | RDA | none | new seam needed: DomesticMultFromQTH | arm of `case Contest of` @1014 |
| `trdos/logedit.pas:1030` | EditableLog.GetMultArray | 1 | YODX | none | new seam needed: DomesticMultFromQTH | arm of `case Contest of` @1014 |
| `trdos/logedit.pas:1471` | Add | 4 | **EUROPEANHFC**, **KVP** | all | ZoneMultiplierType (existing trait) + new seam needed: ZoneMultRule | reach 2: `ZnM` = EUHFCYear |
| `trdos/logedit.pas:3018` | SetPrefix | 4 | DARCWAEDCCW, DARCWAEDCSSB | none | PrefixMultiplierType (existing trait) + new seam needed: PrefixMultRule | reach 2: `Pxm` = CQNonEuropeanCountriesAndWAECallRegions (arm of case @3017) |
| `trdos/logedit.pas:3020` | SetPrefix | 4 | UBACW, UBASSB | none | PrefixMultiplierType (existing trait) + new seam needed: PrefixMultRule | reach 2: `Pxm` = BelgiumPrefixes (arm of case @3017) |
| `trdos/logedit.pas:3024` | SetPrefix | 4 | SACCW, SACSSB | none | PrefixMultiplierType (existing trait) + new seam needed: PrefixMultRule | reach 2: `Pxm` = SACDistricts (arm of case @3017) |
| `trdos/logedit.pas:3025` | SetPrefix | 4 | YBDX | none | PrefixMultiplierType (existing trait) + new seam needed: PrefixMultRule | reach 1: `Pxm` = IndonesianDistricts (arm of case @3017) |
| `trdos/logedit.pas:3027` | SetPrefix | 4 | CQMM, **SASPRINT**, SOUTHAMERICANWW | some: SASPRINT | PrefixMultiplierType (existing trait) + new seam needed: PrefixMultRule | reach 3: `Pxm` = SouthAmericanPrefixes (arm of case @3017) |
| `trdos/logedit.pas:3039` | SetPrefix | 4 | CQMM | none | PrefixMultiplierType (existing trait) + new seam needed: PrefixMultRule | reach 1: `Pxm` = SouthAndNorthAmericanPrefixes (arm of case @3017) |
| `trdos/logedit.pas:3044` | SetPrefix | 4 | SOUTHAMERICANWW | none | PrefixMultiplierType (existing trait) + new seam needed: PrefixMultRule | reach 1: `Pxm` = NonSouthAmericanPrefixes (arm of case @3017) |
| `trdos/logedit.pas:3049` | SetPrefix | 4 | JTDX | none | PrefixMultiplierType (existing trait) + new seam needed: PrefixMultRule | reach 1: `Pxm` = MongolianCallSignPrefix (arm of case @3017) |
| `trdos/logedit.pas:3059` | SetPrefix | 4 | GAGARINCUP | none | PrefixMultiplierType (existing trait) + new seam needed: PrefixMultRule | reach 1: `Pxm` = GCStation (arm of case @3017) |
| `trdos/logedit.pas:3061` | SetPrefix | 3 | GAGARINCUP | none | PrefixMultiplierType (existing trait) + new seam needed: PrefixMultRule | six GC-station callsigns (`'RK1G'`..`'UN/RA3VM'`) |
| `uMults.pas:268` | MultsObject.FillVisibleBytes | 4 | DARCWAEDCCW, DARCWAEDCSSB | none | DXMultiplierType (existing trait) + new seam needed: DXMultiplierRule | reach 2: `XM` = CQEuropeanCountries |
| `uMults.pas:271` | MultsObject.FillVisibleBytes | 4 | UBACW, UBASSB | none | DXMultiplierType (existing trait) + new seam needed: DXMultiplierRule | reach 2: `XM` = CQUBAEuropeanCountries |

### ADIF import (19 rows)

| file:line | routine | shape | contest(s) -- **bold = has a class** | class? | seam | what |
|---|---|---|---|---|---|---|
| `MainUnit.pas:9966` | ApplyContestSpecificADIFTail | 2 | **GENERALQSO** | all | new seam needed: ApplyADIFImport(const aTemps; var aQso) | arm of `case exch.ceContest of` @9965 |
| `MainUnit.pas:9977` | ApplyContestSpecificADIFTail | 2 | WAG | none | new seam needed: ApplyADIFImport(const aTemps; var aQso) | arm of `case exch.ceContest of` @9965 |
| `MainUnit.pas:9980` | ApplyContestSpecificADIFTail | 2 | ARRL160, CQ160CW, CQ160SSB, UBACW, UBASSB | none | new seam needed: ApplyADIFImport(const aTemps; var aQso) | arm of `case exch.ceContest of` @9965 |
| `MainUnit.pas:9983` | ApplyContestSpecificADIFTail | 2 | ARRL_RTTY_ROUNDUP | none | new seam needed: ApplyADIFImport(const aTemps; var aQso) | arm of `case exch.ceContest of` @9965 |
| `MainUnit.pas:9999` | ApplyContestSpecificADIFTail | 2 | **ARRLFIELDDAY**, **ARRLSSCW**, **ARRLSSSSB**, **WINTERFIELDDAY** | all | new seam needed: ApplyADIFImport(const aTemps; var aQso) | arm of `case exch.ceContest of` @9965 |
| `MainUnit.pas:10022` | ApplyContestSpecificADIFTail | 2 | CWOPS | none | new seam needed: ApplyADIFImport(const aTemps; var aQso) | arm of `case exch.ceContest of` @9965 |
| `MainUnit.pas:10025` | ApplyContestSpecificADIFTail | 2 | **CQWWCW**, **CQWWSSB** | all | new seam needed: ApplyADIFImport(const aTemps; var aQso) | arm of `case exch.ceContest of` @9965 |
| `MainUnit.pas:10040` | ApplyContestSpecificADIFTail | 2 | FOCMARATHON | none | new seam needed: ApplyADIFImport(const aTemps; var aQso) | arm of `case exch.ceContest of` @9965 |
| `MainUnit.pas:10043` | ApplyContestSpecificADIFTail | 2 | **IARU** | all | new seam needed: ApplyADIFImport(const aTemps; var aQso) | arm of `case exch.ceContest of` @9965 |
| `MainUnit.pas:10060` | ApplyContestSpecificADIFTail | 2 | NAQSOCW, NAQSORTTY, NAQSOSSB, NCCCSPRINT | none | new seam needed: ApplyADIFImport(const aTemps; var aQso) | arm of `case exch.ceContest of` @9965 |
| `MainUnit.pas:10067` | ApplyContestSpecificADIFTail | 2 | LZDX, OKDX, UKRAINIAN | none | new seam needed: ApplyADIFImport(const aTemps; var aQso) | arm of `case exch.ceContest of` @9965 |
| `MainUnit.pas:10077` | ApplyContestSpecificADIFTail | 2 | POTA | none | new seam needed: ApplyADIFImport(const aTemps; var aQso) | arm of `case exch.ceContest of` @9965 |
| `MainUnit.pas:10094` | ApplyContestSpecificADIFTail | 2 | **ARRLDIGI**, WWDIGI | some: ARRLDIGI | new seam needed: ApplyADIFImport(const aTemps; var aQso) | arm of `case exch.ceContest of` @9965 |
| `MainUnit.pas:10103` | ApplyContestSpecificADIFTail | 4 | **ARRLDIGI**, WWDIGI | some: ARRLDIGI | new seam needed: ApplyADIFImport(const aTemps; var aQso) | reach 2: `AE` = Grid2Exchange |
| `MainUnit.pas:10105` | ApplyContestSpecificADIFTail | 4 | BATAVIA_FT8, MAKROTHEN | none | new seam needed: ApplyADIFImport(const aTemps; var aQso) | reach 2 GENERIC-NAMED: `AE` = GridExchange |
| `MainUnit.pas:11421` | ProcessImportedSRX_String | 2 | **ARRLFIELDDAY**, **WINTERFIELDDAY** | all | new seam needed: ApplyADIFImport (SRX_STRING) | arm of `case exch.ceContest of` @11420 |
| `trdos/logstuff.pas:11185` | ResolvePOTAParkFromADIF | 3 | POTA | none | new seam needed: ApplyADIFImport (SIG / SIG_INFO) | ADIF `SIG = 'POTA'` -- the park from `SIG_INFO` (D5, fixed in `3f9e3f28`) |
| `uADIF.pas:1109` | ApplyADIFFieldsToExchange | 2 | **ARRLFIELDDAY**, **WINTERFIELDDAY** | all | new seam needed: ApplyADIFImport (APP_N1MM_EXCHANGE1) | `exch.ceContest` in |
| `uADIF.pas:1113` | ApplyADIFFieldsToExchange | 2 | FOCMARATHON | none | new seam needed: ApplyADIFImport (APP_N1MM_EXCHANGE1) | `exch.ceContest` in |

### ADIF export (36 rows)

| file:line | routine | shape | contest(s) -- **bold = has a class** | class? | seam | what |
|---|---|---|---|---|---|---|
| `trdos/postunit.pas:2292` | EmitContestSpecificTailForExport | 2 | POTA | none | new seam needed: EmitADIFContestFields(const aQso): string | `rec.ceContest` compare |
| `trdos/postunit.pas:2306` | EmitContestSpecificTailForExport | 2 | POTA | none | new seam needed: EmitADIFContestFields(const aQso): string | `rec.ceContest` compare |
| `trdos/postunit.pas:2360` | EmitContestSpecificTailForExport | 4 | ALRS_UA1DZ_CUP, RDA | none | new seam needed: EmitADIFContestFields(const aQso): string | reach 2: `DM` = RDADistrict |
| `trdos/postunit.pas:2369` | EmitContestSpecificTailForExport | 2 | WAG | none | new seam needed: EmitADIFContestFields(const aQso): string | arm of `case rec.ceContest of` @2368 |
| `trdos/postunit.pas:2371` | EmitContestSpecificTailForExport | 2 | ARRL160 | none | new seam needed: EmitADIFContestFields(const aQso): string | arm of `case rec.ceContest of` @2368 |
| `trdos/postunit.pas:2377` | EmitContestSpecificTailForExport | 2 | **ARRLFIELDDAY**, **WINTERFIELDDAY** | all | new seam needed: EmitADIFContestFields(const aQso): string | arm of `case rec.ceContest of` @2368 |
| `trdos/postunit.pas:2409` | EmitContestSpecificTailForExport | 2 | **ARRLSSCW**, **ARRLSSSSB** | all | new seam needed: EmitADIFContestFields(const aQso): string | arm of `case rec.ceContest of` @2368 |
| `trdos/postunit.pas:2415` | EmitContestSpecificTailForExport | 2 | CQ160CW, CQ160SSB, NAQSOCW, NAQSORTTY, NAQSOSSB, **NASPRINTCW**, **NASPRINTRTTY**, SPRINTSSB | some: NASPRINTCW, NASPRINTRTTY | new seam needed: EmitADIFContestFields(const aQso): string | arm of `case rec.ceContest of` @2368 |
| `trdos/postunit.pas:2418` | EmitContestSpecificTailForExport | 2 | POTA | none | new seam needed: EmitADIFContestFields(const aQso): string | arm of `case rec.ceContest of` @2368 |
| `trdos/postunit.pas:2427` | EmitContestSpecificTailForExport | 2 | IOTA | none | new seam needed: EmitADIFContestFields(const aQso): string | arm of `case rec.ceContest of` @2368 |
| `trdos/postunit.pas:2429` | EmitContestSpecificTailForExport | 2 | **IARU** | all | new seam needed: EmitADIFContestFields(const aQso): string | arm of `case rec.ceContest of` @2368 |
| `trdos/postunit.pas:2432` | EmitContestSpecificTailForExport | 2 | **ARRLDIGI**, BATAVIA_FT8, WWDIGI | some: ARRLDIGI | new seam needed: EmitADIFContestFields(const aQso): string | arm of `case rec.ceContest of` @2368 |
| `uADIF.pas:1535` | EmitADIFRecord | 2 | **GENERALQSO**, POTA | some: GENERALQSO | ADIFContestId (existing) / new seam needed: EmitADIFContestFields | `rec.ceContest` in |
| `uADIF.pas:1611` | EmitADIFRecord | 2 | FOCMARATHON | none | ADIFContestId (existing) / new seam needed: EmitADIFContestFields | `rec.ceContest` compare |
| `uADIFExchange.pas:272` | FormatADIFMyExchange | 4 | BWQP, **GENERALQSO** | some: GENERALQSO | FormatADIFSentExchange + FormatsExchange (existing) | reach 2 GENERIC-NAMED: `AE` = RSTNameAndQTHExchange (arm of case @265) |
| `uADIFExchange.pas:283` | FormatADIFMyExchange | 4 | RSGB_ROPOCO_CW, RSGB_ROPOCO_SSB | none | FormatADIFSentExchange + FormatsExchange (existing) | reach 2: `AE` = RSTAndPostalCodeExchange (arm of case @265) |
| `uADIFExchange.pas:318` | FormatADIFMyExchange | 4 | JIDXCW, JIDXSSB | none | FormatADIFSentExchange + FormatsExchange (existing) | reach 2: `AE` = RSTPrefectureExchange (arm of case @265) |
| `uADIFExchange.pas:326` | FormatADIFMyExchange | 4 | **ARRLSSCW**, **ARRLSSSSB** | all | FormatADIFSentExchange + FormatsExchange (existing) | reach 2: `AE` = QSONumberPrecedenceCheckDomesticQTHExchange (arm of case @265) |
| `uADIFExchange.pas:353` | FormatADIFMyExchange | 4 | RADIOMEMORY | none | FormatADIFSentExchange + FormatsExchange (existing) | reach 1: `AE` = RSTAgeAndPossibleSK (arm of case @265) |
| `uADIFExchange.pas:357` | FormatADIFMyExchange | 4 | ALLASIANCW, ALLASIANSSB, YOTA | none | FormatADIFSentExchange + FormatsExchange (existing) | reach 3 GENERIC-NAMED: `AE` = RSTAgeExchange (arm of case @265) |
| `uADIFExchange.pas:361` | FormatADIFMyExchange | 4 | **YOUTHCHAMPIONSHIPRF** | all | FormatADIFSentExchange + FormatsExchange (existing) | reach 1: `AE` = AgeAndQSONumberExchange (arm of case @265) |
| `uADIFExchange.pas:365` | FormatADIFMyExchange | 4 | POTA | none | FormatADIFSentExchange + FormatsExchange (existing) | reach 1 GENERIC-NAMED: `AE` = RSTAndPOTAPark (arm of case @265) |
| `uADIFExchange.pas:370` | FormatADIFMyExchange | 1 | FOCMARATHON | none | FormatADIFSentExchange + FormatsExchange (existing) | `Contest` compare |
| `uADIFExchange.pas:377` | FormatADIFMyExchange | 1 | FOCMARATHON | none | FormatADIFSentExchange + FormatsExchange (existing) | `Contest` compare |
| `uADIFExchange.pas:389` | FormatADIFMyExchange | 4 | CUPRFCW, CUPRFDIG, CUPRFSSB | none | FormatADIFSentExchange + FormatsExchange (existing) | reach 3: `AE` = QSONumberAndGridSquare (arm of case @265) |
| `uADIFExchange.pas:398` | FormatADIFMyExchange | 3 | (none by default) | - | FormatADIFSentExchange + FormatsExchange (existing) | `cMyState = 'TRC'` |
| `uADIFExchange.pas:409` | FormatADIFMyExchange | 4 | CQWWRTTY | none | FormatADIFSentExchange + FormatsExchange (existing) | reach 1: `AE` = RSTZoneAndPossibleDomesticQTHExchange (arm of case @265) |
| `uADIFExchange.pas:430` | FormatADIFMyExchange | 4 | RFASCHAMPIONSHIPCW | none | FormatADIFSentExchange + FormatsExchange (existing) | reach 1: `AE` = QSONumberAndCoordinatesSum (arm of case @265) |
| `uADIFExchange.pas:433` | FormatADIFMyExchange | 4 | RAEM | none | FormatADIFSentExchange + FormatsExchange (existing) | reach 1: `AE` = QSONumberAndGeoCoordinates (arm of case @265) |
| `uADIFExchange.pas:436` | FormatADIFMyExchange | 4 | **ARRLFIELDDAY**, **WINTERFIELDDAY** | all | FormatADIFSentExchange + FormatsExchange (existing) | reach 2: `AE` = ClassDomesticOrDXQTHExchange (arm of case @265) |
| `uADIFExchange.pas:444` | FormatADIFMyExchange | 4 | CQMM, SOUTHAMERICANWW | none | FormatADIFSentExchange + FormatsExchange (existing) | reach 2: `AE` = RSTAndContinentExchange (arm of case @265) |
| `uADIFExchange.pas:449` | FormatADIFMyExchange | 1 | CQVHF | none | FormatADIFSentExchange + FormatsExchange (existing) | `Contest` in |
| `uADIFExchange.pas:460` | FormatADIFMyExchange | 1 | PACC, SPDX | none | FormatADIFSentExchange + FormatsExchange (existing) | `Contest` in |
| `uADIFExchange.pas:472` | FormatADIFMyExchange | 4 | R9W_UW9WK_MEMORIAL, RFCHAMPIONSHIPCW, RFCHAMPIONSHIPSSB | none | FormatADIFSentExchange + FormatsExchange (existing) | reach 3: `AE` = QSONumberAndZone (arm of case @265) |
| `uADIFExchange.pas:480` | FormatADIFMyExchange | 4 | RADIOYOC | none | FormatADIFSentExchange + FormatsExchange (existing) | reach 1: `AE` = QSONumberAndPreviousQSONumber (arm of case @265) |
| `uADIFExchange.pas:491` | FormatADIFMyExchange | 1 | PCC | none | FormatADIFSentExchange + FormatsExchange (existing) | `Contest` compare |

### Cabrillo export (43 rows)

| file:line | routine | shape | contest(s) -- **bold = has a class** | class? | seam | what |
|---|---|---|---|---|---|---|
| `trdos/postunit.pas:2669` | GetCabrilloTagText | 1 | ARRL10 | none | CabrilloName (existing) + new seam needed: CabrilloHeaders (s6) | `Contest` compare |
| `trdos/postunit.pas:2669` | GetCabrilloTagText | 1 | **WINTERFIELDDAY** | all | CabrilloName (existing) + new seam needed: CabrilloHeaders (s6) | `Contest` compare |
| `trdos/postunit.pas:2691` | GetCabrilloTagText | 1 | **GENERALQSO** | all | CabrilloName (existing) + new seam needed: CabrilloHeaders (s6) | `Contest` compare |
| `trdos/postunit.pas:2730` | GetCabrilloTagText | 1 | **WINTERFIELDDAY** | all | CabrilloName (existing) + new seam needed: CabrilloHeaders (s6) | `Contest` compare |
| `trdos/postunit.pas:2890` | tGenerateLogPortionOfCabrilloFile | 1 | NAQSOCW | none | FormatCabrilloReceivedExchange / CabrilloQSOLineFormat (existing) + new seam needed: CabrilloModeString | `Contest` compare |
| `trdos/postunit.pas:2890` | tGenerateLogPortionOfCabrilloFile | 1 | NAQSOSSB | none | FormatCabrilloReceivedExchange / CabrilloQSOLineFormat (existing) + new seam needed: CabrilloModeString | `Contest` compare |
| `trdos/postunit.pas:2891` | tGenerateLogPortionOfCabrilloFile | 1 | NAQSORTTY | none | FormatCabrilloReceivedExchange / CabrilloQSOLineFormat (existing) + new seam needed: CabrilloModeString | `Contest` compare |
| `trdos/postunit.pas:3013` | tGenerateLogPortionOfCabrilloFile | 1 | **WINTERFIELDDAY** | all | FormatCabrilloReceivedExchange / CabrilloQSOLineFormat (existing) + new seam needed: CabrilloModeString | `Contest` compare |
| `trdos/postunit.pas:3034` | tGenerateLogPortionOfCabrilloFile | 3 | WWDIGI | none | FormatCabrilloReceivedExchange / CabrilloQSOLineFormat (existing) + new seam needed: CabrilloModeString | `Settings.Contest.Name = 'WWDIGI'` |
| `trdos/postunit.pas:3039` | tGenerateLogPortionOfCabrilloFile | 3 | LABRE | none | FormatCabrilloReceivedExchange / CabrilloQSOLineFormat (existing) + new seam needed: CabrilloModeString | `Settings.Contest.Name = 'LABRE'` |
| `trdos/postunit.pas:3053` | tGenerateLogPortionOfCabrilloFile | 1 | CUPRFCW, CUPRFSSB | none | FormatCabrilloReceivedExchange / CabrilloQSOLineFormat (existing) + new seam needed: CabrilloModeString | `Contest` in |
| `trdos/postunit.pas:3058` | tGenerateLogPortionOfCabrilloFile | 3 | (none by default) | - | FormatCabrilloReceivedExchange / CabrilloQSOLineFormat (existing) + new seam needed: CabrilloModeString | `Settings.Contest.Name = 'EURASIA'` -- see dead code |
| `trdos/postunit.pas:3063` | tGenerateLogPortionOfCabrilloFile | 1 | **CALQSOPARTY** | all | FormatCabrilloReceivedExchange / CabrilloQSOLineFormat (existing) + new seam needed: CabrilloModeString | `Contest` in |
| `uCabrilloExchange.pas:209` | SetHisEx | 4 | BWQP, **GENERALQSO** | some: GENERALQSO | FormatCabrilloSentExchange / FormatCabrilloReceivedExchange + FormatsExchange (existing) | reach 2 GENERIC-NAMED: `AE` = RSTNameAndQTHExchange (arm of case @195) |
| `uCabrilloExchange.pas:221` | SetHisEx | 4 | RSGB_ROPOCO_CW, RSGB_ROPOCO_SSB | none | FormatCabrilloSentExchange / FormatCabrilloReceivedExchange + FormatsExchange (existing) | reach 2: `AE` = RSTAndPostalCodeExchange (arm of case @195) |
| `uCabrilloExchange.pas:262` | SetHisEx | 4 | JIDXCW, JIDXSSB | none | FormatCabrilloSentExchange / FormatCabrilloReceivedExchange + FormatsExchange (existing) | reach 2: `AE` = RSTPrefectureExchange (arm of case @195) |
| `uCabrilloExchange.pas:274` | SetHisEx | 4 | **ARRLSSCW**, **ARRLSSSSB** | all | FormatCabrilloSentExchange / FormatCabrilloReceivedExchange + FormatsExchange (existing) | reach 2: `AE` = QSONumberPrecedenceCheckDomesticQTHExchange (arm of case @195) |
| `uCabrilloExchange.pas:307` | SetHisEx | 4 | RADIOMEMORY | none | FormatCabrilloSentExchange / FormatCabrilloReceivedExchange + FormatsExchange (existing) | reach 1: `AE` = RSTAgeAndPossibleSK (arm of case @195) |
| `uCabrilloExchange.pas:314` | SetHisEx | 4 | ALLASIANCW, ALLASIANSSB, YOTA | none | FormatCabrilloSentExchange / FormatCabrilloReceivedExchange + FormatsExchange (existing) | reach 3 GENERIC-NAMED: `AE` = RSTAgeExchange (arm of case @195) |
| `uCabrilloExchange.pas:321` | SetHisEx | 4 | **YOUTHCHAMPIONSHIPRF** | all | FormatCabrilloSentExchange / FormatCabrilloReceivedExchange + FormatsExchange (existing) | reach 1: `AE` = AgeAndQSONumberExchange (arm of case @195) |
| `uCabrilloExchange.pas:341` | SetHisEx | 1 | FOCMARATHON | none | FormatCabrilloSentExchange / FormatCabrilloReceivedExchange + FormatsExchange (existing) | `Contest` compare |
| `uCabrilloExchange.pas:348` | SetHisEx | 1 | FOCMARATHON | none | FormatCabrilloSentExchange / FormatCabrilloReceivedExchange + FormatsExchange (existing) | `Contest` compare |
| `uCabrilloExchange.pas:361` | SetHisEx | 4 | CUPRFCW, CUPRFDIG, CUPRFSSB | none | FormatCabrilloSentExchange / FormatCabrilloReceivedExchange + FormatsExchange (existing) | reach 3: `AE` = QSONumberAndGridSquare (arm of case @195) |
| `uCabrilloExchange.pas:368` | SetHisEx | 1 | UKRAINECHAMPIONSHIP | none | FormatCabrilloSentExchange / FormatCabrilloReceivedExchange + FormatsExchange (existing) | `Contest` compare |
| `uCabrilloExchange.pas:368` | SetHisEx | 1 | CUPURAL | none | FormatCabrilloSentExchange / FormatCabrilloReceivedExchange + FormatsExchange (existing) | `Contest` compare |
| `uCabrilloExchange.pas:381` | SetHisEx | 3 | (none by default) | - | FormatCabrilloSentExchange / FormatCabrilloReceivedExchange + FormatsExchange (existing) | `cMyState = 'TRC'` -- TRC Digital, no ContestType |
| `uCabrilloExchange.pas:385` | SetHisEx | 3 | (none by default) | - | FormatCabrilloSentExchange / FormatCabrilloReceivedExchange + FormatsExchange (existing) | `ContestTitle = 'PGA'` -- no ContestType; operator-titled |
| `uCabrilloExchange.pas:394` | SetHisEx | 1 | UKEI | none | FormatCabrilloSentExchange / FormatCabrilloReceivedExchange + FormatsExchange (existing) | `Contest` compare |
| `uCabrilloExchange.pas:400` | SetHisEx | 1 | IOTA | none | FormatCabrilloSentExchange / FormatCabrilloReceivedExchange + FormatsExchange (existing) | `Contest` compare |
| `uCabrilloExchange.pas:408` | SetHisEx | 1 | DARC10M | none | FormatCabrilloSentExchange / FormatCabrilloReceivedExchange + FormatsExchange (existing) | `Contest` compare |
| `uCabrilloExchange.pas:412` | SetHisEx | 3 | (none by default) | - | FormatCabrilloSentExchange / FormatCabrilloReceivedExchange + FormatsExchange (existing) | `ContestTitle = 'PGA'` -- no ContestType; operator-titled |
| `uCabrilloExchange.pas:416` | SetHisEx | 3 | (none by default) | - | FormatCabrilloSentExchange / FormatCabrilloReceivedExchange + FormatsExchange (existing) | `csQTHString = 'TRC'` |
| `uCabrilloExchange.pas:426` | SetHisEx | 4 | CQWWRTTY | none | FormatCabrilloSentExchange / FormatCabrilloReceivedExchange + FormatsExchange (existing) | reach 1: `AE` = RSTZoneAndPossibleDomesticQTHExchange (arm of case @195) |
| `uCabrilloExchange.pas:463` | SetHisEx | 4 | RFASCHAMPIONSHIPCW | none | FormatCabrilloSentExchange / FormatCabrilloReceivedExchange + FormatsExchange (existing) | reach 1: `AE` = QSONumberAndCoordinatesSum (arm of case @195) |
| `uCabrilloExchange.pas:469` | SetHisEx | 4 | **ARRLFIELDDAY**, **WINTERFIELDDAY** | all | FormatCabrilloSentExchange / FormatCabrilloReceivedExchange + FormatsExchange (existing) | reach 2: `AE` = ClassDomesticOrDXQTHExchange (arm of case @195) |
| `uCabrilloExchange.pas:481` | SetHisEx | 4 | RAEM | none | FormatCabrilloSentExchange / FormatCabrilloReceivedExchange + FormatsExchange (existing) | reach 1: `AE` = QSONumberAndGeoCoordinates (arm of case @195) |
| `uCabrilloExchange.pas:493` | SetHisEx | 4 | CQMM, SOUTHAMERICANWW | none | FormatCabrilloSentExchange / FormatCabrilloReceivedExchange + FormatsExchange (existing) | reach 2: `AE` = RSTAndContinentExchange (arm of case @195) |
| `uCabrilloExchange.pas:502` | SetHisEx | 1 | CQVHF | none | FormatCabrilloSentExchange / FormatCabrilloReceivedExchange + FormatsExchange (existing) | `Contest` in |
| `uCabrilloExchange.pas:513` | SetHisEx | 1 | PACC, SPDX | none | FormatCabrilloSentExchange / FormatCabrilloReceivedExchange + FormatsExchange (existing) | `Contest` in |
| `uCabrilloExchange.pas:548` | SetHisEx | 4 | R9W_UW9WK_MEMORIAL, RFCHAMPIONSHIPCW, RFCHAMPIONSHIPSSB | none | FormatCabrilloSentExchange / FormatCabrilloReceivedExchange + FormatsExchange (existing) | reach 3: `AE` = QSONumberAndZone (arm of case @195) |
| `uCabrilloExchange.pas:556` | SetHisEx | 1 | JIDXCW, JIDXSSB | none | FormatCabrilloSentExchange / FormatCabrilloReceivedExchange + FormatsExchange (existing) | `Contest` in |
| `uCabrilloExchange.pas:564` | SetHisEx | 4 | RADIOYOC | none | FormatCabrilloSentExchange / FormatCabrilloReceivedExchange + FormatsExchange (existing) | reach 1: `AE` = QSONumberAndPreviousQSONumber (arm of case @195) |
| `uCabrilloExchange.pas:575` | SetHisEx | 1 | PCC | none | FormatCabrilloSentExchange / FormatCabrilloReceivedExchange + FormatsExchange (existing) | `Contest` compare |

### Score, summary and totals (25 rows)

| file:line | routine | shape | contest(s) -- **bold = has a class** | class? | seam | what |
|---|---|---|---|---|---|---|
| `trdos/logedit.pas:2853` | TotalScore | 4 | FISTS | none | new seam needed: CalculateTotalScore (s6) | reach 1: `AE` = RSTQTHNameAndFistsNumberOrPowerExchange |
| `trdos/logedit.pas:2859` | TotalScore | 1 | **ARRLFIELDDAY** | all | new seam needed: CalculateTotalScore (s6) | `Contest` compare |
| `trdos/logedit.pas:2868` | TotalScore | 1 | **WINTERFIELDDAY** | all | new seam needed: CalculateTotalScore (s6) | `Contest` compare |
| `trdos/logedit.pas:2917` | TotalScore | 4 | DARCWAEDCCW, DARCWAEDCSSB | none | new seam needed: CalculateTotalScore (s6) | reach 2: `QP` = WAEQSOPointMethod |
| `trdos/logedit.pas:2920` | TotalScore | 4 | DARCWAEDCCW, DARCWAEDCSSB | none | new seam needed: CalculateTotalScore (s6) | reach 2: `XM` = CQEuropeanCountries |
| `trdos/logedit.pas:2951` | TotalScore | 1 | CUPURAL | none | new seam needed: CalculateTotalScore (s6) | `Contest` compare |
| `trdos/logedit.pas:2957` | TotalScore | 1 | RSGB18 | none | new seam needed: CalculateTotalScore (s6) | `Contest` compare |
| `trdos/logedit.pas:2962` | TotalScore | 4 | CUPRFCW, CUPRFDIG, CUPRFSSB | none | new seam needed: CalculateTotalScore (s6) | reach 3: `QP` = CupRFMethod |
| `trdos/logedit.pas:2968` | TotalScore | 4 | ALRS_UA1DZ_CUP | none | new seam needed: CalculateTotalScore (s6) | reach 1: `QP` = ALRSUA1DZCupQSOPointMethod |
| `trdos/logedit.pas:2974` | TotalScore | 4 | RFCHAMPIONSHIPCW, RFCHAMPIONSHIPSSB | none | new seam needed: CalculateTotalScore (s6) | reach 2: `QP` = ChampionshipRFMethod |
| `trdos/logedit.pas:2981` | TotalScore | 1 | UKRAINECHAMPIONSHIP | none | new seam needed: CalculateTotalScore (s6) | `Contest` in |
| `trdos/logedit.pas:2987` | TotalScore | 4 | OZHCRVHF | none | new seam needed: CalculateTotalScore (s6) | reach 1: `QP` = OZHCRVHFQSOPointMethod |
| `trdos/logedit.pas:2995` | TotalScore | 1 | **MOQSOPARTY** | all | new seam needed: CalculateTotalScore (s6) | `Contest` compare |
| `trdos/logedit.pas:3008` | TotalScore | 1 | CUPURAL | none | new seam needed: CalculateTotalScore (s6) | `Contest` compare |
| `trdos/postunit.pas:1077` | WriteScoreInformationToSummarySheet | 1 | **WINTERFIELDDAY** | all | new seam needed: SummarySheetMultColumns | `Contest` compare |
| `trdos/postunit.pas:1089` | WriteScoreInformationToSummarySheet | 1 | **WINTERFIELDDAY** | all | new seam needed: SummarySheetMultColumns | `Contest` compare |
| `trdos/postunit.pas:1118` | WriteScoreInformationToSummarySheet | 1 | **ARRLFIELDDAY** | all | new seam needed: SummarySheetMultColumns | `Contest` compare |
| `trdos/postunit.pas:1148` | CalculateTotals | 3 | **CQWWCW**, CQWWRTTY, **CQWWSSB** | some: CQWWCW, CQWWSSB | new seam needed: OffTimeMinimumMinutes | `Pos('CQ-WW', Settings.Contest.Name)` -- 60-minute off-time |
| `trdos/postunit.pas:1272` | CheckForNewContestDate | 1 | **GENERALQSO** | all | new seam needed: MaxContestDates | `Contest` compare |
| `trdos/postunit.pas:1446` | PrintHourTotals | 1 | CUPRFCW, CUPRFSSB, CUPURAL, RFCHAMPIONSHIPCW, RFCHAMPIONSHIPSSB, RU3AXMEMORIAL, UKRAINECHAMPIONSHIP | none | new seam needed: ShowsRunningScore | `Contest` in |
| `uTotal.pas:263` | UpdateTotals2 | 1 | OZCR_O | none | new seam needed: TotalsDisplay | `Contest` compare |
| `uTotal.pas:301` | UpdateTotals2 | 1 | **IARU** | all | new seam needed: TotalsDisplay | `Contest` compare |
| `uTotal.pas:327` | UpdateTotals2 | 1 | **IARU** | all | new seam needed: TotalsDisplay | `Contest` compare |
| `uTotal.pas:332` | UpdateTotals2 | 1 | RUSSIANDX | none | new seam needed: TotalsDisplay | `Contest` compare |
| `uTotal.pas:332` | UpdateTotals2 | 1 | RU3AXMEMORIAL | none | new seam needed: TotalsDisplay | `Contest` compare |

### UI, display and the new-contest dialog (110 rows)

| file:line | routine | shape | contest(s) -- **bold = has a class** | class? | seam | what |
|---|---|---|---|---|---|---|
| `MainUnit.pas:1747` | ReturnInCQOpMode | 1 | **GENERALQSO** | all | new seam needed: ShowsMultiplierStatus | `Contest` compare |
| `MainUnit.pas:4120` | CallWindowChange | 1 | WAG | none | new seam needed: OnCallsignChanged | `Contest` compare |
| `MainUnit.pas:4459` | CreateMainWindow | 3 | **CQWWCW**, CQWWRTTY, **CQWWSSB**, **IARU** | some: CQWWCW, CQWWSSB, IARU | new seam needed: UIFeatures (menus, QTC, off-time) | `Pos('CQ-WW'` / `'IARU-HF'` in `ContestTypeSA[Contest]` -- 60-minute off-time |
| `MainUnit.pas:4476` | CreateMainWindow | 1 | WRTC | none | new seam needed: UIFeatures (menus, QTC, off-time) | `Contest` compare |
| `MainUnit.pas:4492` | CreateMainWindow | 1 | DARCWAEDCCW, DARCWAEDCSSB | none | new seam needed: UIFeatures (menus, QTC, off-time) | `Contest` in |
| `MainUnit.pas:4505` | CreateMainWindow | 1 | POTA | none | new seam needed: UIFeatures (menus, QTC, off-time) | `Contest` compare |
| `MainUnit.pas:6460` | OpenTR4WWindow | 1 | WRTC | none | new seam needed: UIFeatures (hidden windows) | `Contest` compare |
| `MainUnit.pas:8243` | BuildLogRow | 1 | FOCMARATHON | none | new seam needed: LogColumns | `Contest` compare |
| `MainUnit.pas:9469` | SetColumnsWidth | 4 | **ARRLSSCW**, **ARRLSSSSB** | all | new seam needed: LogColumns | reach 2: `AE` = QSONumberPrecedenceCheckDomesticQTHExchange |
| `MainUnit.pas:9471` | SetColumnsWidth | 4 | **ARRLSSCW**, **ARRLSSSSB** | all | new seam needed: LogColumns | reach 2: `AE` = QSONumberPrecedenceCheckDomesticQTHExchange |
| `MainUnit.pas:9484` | SetColumnsWidth | 1 | FOCMARATHON | none | new seam needed: LogColumns | `Contest` compare |
| `MainUnit.pas:9488` | SetColumnsWidth | 1 | FOCMARATHON | none | new seam needed: LogColumns | `Contest` compare |
| `trdos/logedit.pas:1708` | EditableLog.SuperCheckPartial | 1 | WRTC | none | new seam needed: UIFeatures (SCP allowed) | `Contest` compare |
| `trdos/logedit.pas:1965` | ShowStationInformation | 1 | **GENERALQSO** | all | new seam needed: ShowsMultiplierStatus | `Contest` compare |
| `trdos/logstuff.pas:969` | BandChange | 1 | **GENERALQSO** | all | new seam needed: AllowsWARCBands | `CONTEST` compare |
| `trdos/logsubs2.pas:2482` | OperateContest | 1 | **GENERALQSO** | all | new seam needed: ShowsMultiplierStatus | `Contest` compare |
| `trdos/logsubs2.pas:2506` | OperateContest | 1 | **GENERALQSO** | all | new seam needed: ShowsMultiplierStatus | `Contest` compare |
| `trdos/logwind.pas:2421` | SetUpBandMapEntry | 1 | **GENERALQSO** | all | new seam needed: ShowsMultiplierStatus | `Contest` compare |
| `uNewContest.pas:169` | ApplyIAmIn | 2 | MWC | none | new seam needed: NewContestPrompts | arm of `case SelectedContest of` @168 |
| `uNewContest.pas:171` | ApplyIAmIn | 2 | **VAQP** | all | new seam needed: NewContestPrompts | arm of `case SelectedContest of` @168 |
| `uNewContest.pas:174` | ApplyIAmIn | 2 | ALRS_UA1DZ_CUP | none | new seam needed: NewContestPrompts | arm of `case SelectedContest of` @168 |
| `uNewContest.pas:177` | ApplyIAmIn | 2 | NEWENGLANDQSO | none | new seam needed: NewContestPrompts | arm of `case SelectedContest of` @168 |
| `uNewContest.pas:180` | ApplyIAmIn | 2 | ARRL10, ARRL160, **ARRLDXCW**, ARRL_RTTY_ROUNDUP | some: ARRLDXCW | new seam needed: NewContestPrompts | arm of `case SelectedContest of` @168 |
| `uNewContest.pas:193` | ApplyIAmIn | 2 | CQ160CW, CQ160SSB, CQWWRTTY | none | new seam needed: NewContestPrompts | arm of `case SelectedContest of` @168 |
| `uNewContest.pas:196` | ApplyIAmIn | 2 | IRTS | none | new seam needed: NewContestPrompts | arm of `case SelectedContest of` @168 |
| `uNewContest.pas:199` | ApplyIAmIn | 2 | CANADA_DAY, CANADA_WINTER | none | new seam needed: NewContestPrompts | arm of `case SelectedContest of` @168 |
| `uNewContest.pas:203` | ApplyIAmIn | 2 | REFCW, REFSSB | none | new seam needed: NewContestPrompts | arm of `case SelectedContest of` @168 |
| `uNewContest.pas:206` | ApplyIAmIn | 2 | CIS, RU3AXMEMORIAL, RUSSIANDX, UKRAINIAN, UNDX | none | new seam needed: NewContestPrompts | arm of `case SelectedContest of` @168 |
| `uNewContest.pas:209` | ApplyIAmIn | 2 | ARI_DX, HELVETIA, KINGOFSPAINCW, KINGOFSPAINSSB, PACC, UBACW, UBASSB | none | new seam needed: NewContestPrompts | arm of `case SelectedContest of` @168 |
| `uNewContest.pas:212` | ApplyIAmIn | 2 | **CQIR**, HADX, YUDX | some: CQIR | new seam needed: NewContestPrompts | arm of `case SelectedContest of` @168 |
| `uNewContest.pas:214` | ApplyIAmIn | 2 | GAGARINCUP | none | new seam needed: NewContestPrompts | arm of `case SelectedContest of` @168 |
| `uNewContest.pas:216` | ApplyIAmIn | 2 | UKEI | none | new seam needed: NewContestPrompts | arm of `case SelectedContest of` @168 |
| `uNewContest.pas:218` | ApplyIAmIn | 2 | DARC10M, **DARCXMAS**, WAG | some: DARCXMAS | new seam needed: NewContestPrompts | arm of `case SelectedContest of` @168 |
| `uNewContest.pas:220` | ApplyIAmIn | 2 | EUDX, LZDX, OKDX, OKOMSSB, RSGB18, SPDX, YODX | none | new seam needed: NewContestPrompts | arm of `case SelectedContest of` @168 |
| `uNewContest.pas:223` | ApplyIAmIn | 2 | RDA | none | new seam needed: NewContestPrompts | arm of `case SelectedContest of` @168 |
| `uNewContest.pas:225` | ApplyIAmIn | 2 | BSCI, **IARU** | some: IARU | new seam needed: NewContestPrompts | arm of `case SelectedContest of` @168 |
| `uNewContest.pas:228` | ApplyIAmIn | 2 | IOTA | none | new seam needed: NewContestPrompts | arm of `case SelectedContest of` @168 |
| `uNewContest.pas:231` | ApplyIAmIn | 2 | WWPMC | none | new seam needed: NewContestPrompts | arm of `case SelectedContest of` @168 |
| `uNewContest.pas:233` | ApplyIAmIn | 2 | POTA | none | new seam needed: NewContestPrompts | arm of `case SelectedContest of` @168 |
| `uNewContest.pas:235` | ApplyIAmIn | 2 | **ARKTIKA_SPRING**, PCC | some: ARKTIKA_SPRING | new seam needed: NewContestPrompts | arm of `case SelectedContest of` @168 |
| `uNewContest.pas:238` | ApplyIAmIn | 2 | JIDXCW, JIDXSSB | none | new seam needed: NewContestPrompts | arm of `case SelectedContest of` @168 |
| `uNewContest.pas:254` | ApplyContestChoice | 2 | **BCQP** | all | new seam needed: NewContestPrompts | `SelectedContest` compare |
| `uNewContest.pas:260` | ApplyContestChoice | 2 | LABRE | none | new seam needed: NewContestPrompts | arm of `case SelectedContest of` @259 |
| `uNewContest.pas:263` | ApplyContestChoice | 2 | **BCQP** | all | new seam needed: NewContestPrompts | arm of `case SelectedContest of` @259 |
| `uNewContest.pas:267` | ApplyContestChoice | 2 | **COLORADOQSOPARTY**, **MINNQSOPARTY** | all | new seam needed: NewContestPrompts | arm of `case SelectedContest of` @259 |
| `uNewContest.pas:272` | ApplyContestChoice | 2 | ALRS_UA1DZ_CUP | none | new seam needed: NewContestPrompts | arm of `case SelectedContest of` @259 |
| `uNewContest.pas:275` | ApplyContestChoice | 2 | EUSPRINT_AUTUMN_CW, EUSPRINT_AUTUMN_SSB, EUSPRINT_SPRING_CW, EUSPRINT_SPRING_SSB | none | new seam needed: NewContestPrompts | arm of `case SelectedContest of` @259 |
| `uNewContest.pas:277` | ApplyContestChoice | 2 | NZFIELDDAY | none | new seam needed: NewContestPrompts | arm of `case SelectedContest of` @259 |
| `uNewContest.pas:279` | ApplyContestChoice | 2 | **EUROPEANHFC** | all | new seam needed: NewContestPrompts | arm of `case SelectedContest of` @259 |
| `uNewContest.pas:281` | ApplyContestChoice | 2 | **KVP** | all | new seam needed: NewContestPrompts | arm of `case SelectedContest of` @259 |
| `uNewContest.pas:283` | ApplyContestChoice | 2 | RFCHAMPIONSHIPCW, RFCHAMPIONSHIPSSB | none | new seam needed: NewContestPrompts | arm of `case SelectedContest of` @259 |
| `uNewContest.pas:284` | ApplyContestChoice | 2 | RAEM | none | new seam needed: NewContestPrompts | arm of `case SelectedContest of` @259 |
| `uNewContest.pas:286` | ApplyContestChoice | 2 | OLDNEWYEAR | none | new seam needed: NewContestPrompts | arm of `case SelectedContest of` @259 |
| `uNewContest.pas:287` | ApplyContestChoice | 2 | RSGB_ROPOCO_CW, RSGB_ROPOCO_SSB | none | new seam needed: NewContestPrompts | arm of `case SelectedContest of` @259 |
| `uNewContest.pas:290` | ApplyContestChoice | 2 | RADIOMEMORY | none | new seam needed: NewContestPrompts | arm of `case SelectedContest of` @259 |
| `uNewContest.pas:291` | ApplyContestChoice | 2 | CQMM | none | new seam needed: NewContestPrompts | arm of `case SelectedContest of` @259 |
| `uNewContest.pas:293` | ApplyContestChoice | 2 | NRAUBALTICCW, NRAUBALTICSSB | none | new seam needed: NewContestPrompts | arm of `case SelectedContest of` @259 |
| `uNewContest.pas:294` | ApplyContestChoice | 2 | OZCR_O | none | new seam needed: NewContestPrompts | arm of `case SelectedContest of` @259 |
| `uNewContest.pas:297` | ApplyContestChoice | 2 | R9W_UW9WK_MEMORIAL | none | new seam needed: NewContestPrompts | arm of `case SelectedContest of` @259 |
| `uNewContest.pas:299` | ApplyContestChoice | 2 | CUPRFCW, CUPRFDIG, CUPRFSSB | none | new seam needed: NewContestPrompts | arm of `case SelectedContest of` @259 |
| `uNewContest.pas:300` | ApplyContestChoice | 2 | RFASCHAMPIONSHIPCW | none | new seam needed: NewContestPrompts | arm of `case SelectedContest of` @259 |
| `uNewContest.pas:301` | ApplyContestChoice | 2 | **ARRLDIGI**, ARRLVHFJAN, ARRLVHFJUN, ARRLVHFSEP, BATAVIA_FT8, CQVHF, MAKROTHEN, RTC, STEWPERRY, WWDIGI | some: ARRLDIGI | new seam needed: NewContestPrompts | arm of `case SelectedContest of` @259 |
| `uNewContest.pas:303` | ApplyContestChoice | 2 | EUROPEANVHF, OZHCRVHF, RADIOVHFFD | none | new seam needed: NewContestPrompts | arm of `case SelectedContest of` @259 |
| `uNewContest.pas:305` | ApplyContestChoice | 2 | TESLA | none | new seam needed: NewContestPrompts | arm of `case SelectedContest of` @259 |
| `uNewContest.pas:308` | ApplyContestChoice | 2 | NEWENGLANDQSO | none | new seam needed: NewContestPrompts | arm of `case SelectedContest of` @259 |
| `uNewContest.pas:310` | ApplyContestChoice | 2 | ARRL10, ARRL160, ARRL_RTTY_ROUNDUP, CQ160CW, CQ160SSB, CQWWRTTY | none | new seam needed: NewContestPrompts | arm of `case SelectedContest of` @259 |
| `uNewContest.pas:312` | ApplyContestChoice | 2 | RDA, RU3AXMEMORIAL, RUSSIANDX | none | new seam needed: NewContestPrompts | arm of `case SelectedContest of` @259 |
| `uNewContest.pas:313` | ApplyContestChoice | 2 | **CQIR** | all | new seam needed: NewContestPrompts | arm of `case SelectedContest of` @259 |
| `uNewContest.pas:314` | ApplyContestChoice | 2 | CANADA_DAY, CANADA_WINTER | none | new seam needed: NewContestPrompts | arm of `case SelectedContest of` @259 |
| `uNewContest.pas:315` | ApplyContestChoice | 2 | REFCW, REFSSB | none | new seam needed: NewContestPrompts | arm of `case SelectedContest of` @259 |
| `uNewContest.pas:316` | ApplyContestChoice | 2 | IRTS | none | new seam needed: NewContestPrompts | arm of `case SelectedContest of` @259 |
| `uNewContest.pas:317` | ApplyContestChoice | 2 | EUDX | none | new seam needed: NewContestPrompts | arm of `case SelectedContest of` @259 |
| `uNewContest.pas:319` | ApplyContestChoice | 2 | KINGOFSPAINCW, KINGOFSPAINSSB | none | new seam needed: NewContestPrompts | arm of `case SelectedContest of` @259 |
| `uNewContest.pas:320` | ApplyContestChoice | 2 | JIDXCW, JIDXSSB | none | new seam needed: NewContestPrompts | arm of `case SelectedContest of` @259 |
| `uNewContest.pas:321` | ApplyContestChoice | 2 | HELVETIA | none | new seam needed: NewContestPrompts | arm of `case SelectedContest of` @259 |
| `uNewContest.pas:322` | ApplyContestChoice | 2 | ARI_DX | none | new seam needed: NewContestPrompts | arm of `case SelectedContest of` @259 |
| `uNewContest.pas:323` | ApplyContestChoice | 2 | UNDX | none | new seam needed: NewContestPrompts | arm of `case SelectedContest of` @259 |
| `uNewContest.pas:324` | ApplyContestChoice | 2 | UKRAINIAN | none | new seam needed: NewContestPrompts | arm of `case SelectedContest of` @259 |
| `uNewContest.pas:325` | ApplyContestChoice | 2 | OKDX, OKOMSSB | none | new seam needed: NewContestPrompts | arm of `case SelectedContest of` @259 |
| `uNewContest.pas:327` | ApplyContestChoice | 2 | LZDX | none | new seam needed: NewContestPrompts | arm of `case SelectedContest of` @259 |
| `uNewContest.pas:328` | ApplyContestChoice | 2 | YODX | none | new seam needed: NewContestPrompts | arm of `case SelectedContest of` @259 |
| `uNewContest.pas:329` | ApplyContestChoice | 2 | HADX | none | new seam needed: NewContestPrompts | arm of `case SelectedContest of` @259 |
| `uNewContest.pas:330` | ApplyContestChoice | 2 | YUDX | none | new seam needed: NewContestPrompts | arm of `case SelectedContest of` @259 |
| `uNewContest.pas:331` | ApplyContestChoice | 2 | UKEI | none | new seam needed: NewContestPrompts | arm of `case SelectedContest of` @259 |
| `uNewContest.pas:332` | ApplyContestChoice | 2 | GAGARINCUP | none | new seam needed: NewContestPrompts | arm of `case SelectedContest of` @259 |
| `uNewContest.pas:334` | ApplyContestChoice | 2 | UBACW, UBASSB | none | new seam needed: NewContestPrompts | arm of `case SelectedContest of` @259 |
| `uNewContest.pas:335` | ApplyContestChoice | 2 | PACC | none | new seam needed: NewContestPrompts | arm of `case SelectedContest of` @259 |
| `uNewContest.pas:336` | ApplyContestChoice | 2 | DARC10M, **DARCXMAS**, WAG | some: DARCXMAS | new seam needed: NewContestPrompts | arm of `case SelectedContest of` @259 |
| `uNewContest.pas:337` | ApplyContestChoice | 2 | RSGB18 | none | new seam needed: NewContestPrompts | arm of `case SelectedContest of` @259 |
| `uNewContest.pas:338` | ApplyContestChoice | 2 | CIS | none | new seam needed: NewContestPrompts | arm of `case SelectedContest of` @259 |
| `uNewContest.pas:339` | ApplyContestChoice | 2 | SPDX | none | new seam needed: NewContestPrompts | arm of `case SelectedContest of` @259 |
| `uNewContest.pas:340` | ApplyContestChoice | 2 | BSCI, **IARU** | some: IARU | new seam needed: NewContestPrompts | arm of `case SelectedContest of` @259 |
| `uNewContest.pas:341` | ApplyContestChoice | 2 | IOTA | none | new seam needed: NewContestPrompts | arm of `case SelectedContest of` @259 |
| `uNewContest.pas:346` | ApplyContestChoice | 2 | WWPMC | none | new seam needed: NewContestPrompts | arm of `case SelectedContest of` @259 |
| `uNewContest.pas:347` | ApplyContestChoice | 2 | **ARKTIKA_SPRING**, PCC | some: ARKTIKA_SPRING | new seam needed: NewContestPrompts | arm of `case SelectedContest of` @259 |
| `uNewContest.pas:349` | ApplyContestChoice | 2 | NAQSOCW, NAQSORTTY, NAQSOSSB, SST | none | new seam needed: NewContestPrompts | arm of `case SelectedContest of` @259 |
| `uNewContest.pas:355` | ApplyContestChoice | 2 | CWOPEN, **MST** | some: MST | new seam needed: NewContestPrompts | arm of `case SelectedContest of` @259 |
| `uNewContest.pas:360` | ApplyContestChoice | 2 | CWOPS, LQP, NCCCSPRINT | none | new seam needed: NewContestPrompts | arm of `case SelectedContest of` @259 |
| `uNewContest.pas:366` | ApplyContestChoice | 2 | FOCMARATHON | none | new seam needed: NewContestPrompts | arm of `case SelectedContest of` @259 |
| `uNewContest.pas:372` | ApplyContestChoice | 2 | KCJ | none | new seam needed: NewContestPrompts | arm of `case SelectedContest of` @259 |
| `uNewContest.pas:377` | ApplyContestChoice | 2 | POTA | none | new seam needed: NewContestPrompts | arm of `case SelectedContest of` @259 |
| `uNewContest.pas:381` | ApplyContestChoice | 2 | **WINTERFIELDDAY** | all | new seam needed: NewContestPrompts | arm of `case SelectedContest of` @259 |
| `uNewContest.pas:387` | ApplyContestChoice | 2 | **ARRLFIELDDAY** | all | new seam needed: NewContestPrompts | arm of `case SelectedContest of` @259 |
| `uNewContest.pas:393` | ApplyContestChoice | 2 | **ARRLSSCW**, **ARRLSSSSB** | all | new seam needed: NewContestPrompts | arm of `case SelectedContest of` @259 |
| `uNewContest.pas:400` | ApplyContestChoice | 2 | **NASPRINTCW**, **NASPRINTRTTY**, SPRINTSSB | some: NASPRINTCW, NASPRINTRTTY | new seam needed: NewContestPrompts | arm of `case SelectedContest of` @259 |
| `uNewContest.pas:409` | ApplyContestChoice | 2 | UA4WCHAMPIONSHIP | none | new seam needed: NewContestPrompts | arm of `case SelectedContest of` @259 |
| `uNewContest.pas:412` | ApplyContestChoice | 2 | ALLASIANCW, ALLASIANSSB, YOTA, **YOUTHCHAMPIONSHIPRF** | some: YOUTHCHAMPIONSHIPRF | new seam needed: NewContestPrompts | arm of `case SelectedContest of` @259 |
| `uNewContest.pas:415` | ApplyContestChoice | 2 | UKRAINECHAMPIONSHIP | none | new seam needed: NewContestPrompts | arm of `case SelectedContest of` @259 |
| `uNewContest.pas:418` | ApplyContestChoice | 2 | **ARRLDXCW**, **ARRLDXSSB** | all | new seam needed: NewContestPrompts | arm of `case SelectedContest of` @259 |
| `uNewContest.pas:422` | ApplyContestChoice | 2 | CUPURAL | none | new seam needed: NewContestPrompts | arm of `case SelectedContest of` @259 |

### Setup (FoundContest / LogCfg) (18 rows)

| file:line | routine | shape | contest(s) -- **bold = has a class** | class? | seam | what |
|---|---|---|---|---|---|---|
| `trdos/LogCfg.pas:883` | tSetupExchangeNumbers | 1 | MAKROTHEN | none | new seam needed: SentExchangeFields / FormatSentExchange (s6) | arm of `case Contest of` @881 |
| `trdos/LogCfg.pas:888` | tSetupExchangeNumbers | 1 | RADIOMEMORY, **WISCONSINQSOPARTY** | some: WISCONSINQSOPARTY | new seam needed: SentExchangeFields / FormatSentExchange (s6) | arm of `case Contest of` @881 |
| `trdos/LogCfg.pas:890` | tSetupExchangeNumbers | 1 | LQP, NCCCSPRINT | none | new seam needed: SentExchangeFields / FormatSentExchange (s6) | arm of `case Contest of` @881 |
| `trdos/LogCfg.pas:894` | tSetupExchangeNumbers | 1 | CUPURAL, R9W_UW9WK_MEMORIAL, RFASCHAMPIONSHIPCW, RFCHAMPIONSHIPCW, RFCHAMPIONSHIPSSB, UKRAINECHAMPIONSHIP | none | new seam needed: SentExchangeFields / FormatSentExchange (s6) | arm of `case Contest of` @881 |
| `trdos/LogCfg.pas:896` | tSetupExchangeNumbers | 1 | ALLASIANCW, ALLASIANSSB, ALRS_UA1DZ_CUP, ARRL160, **ARRLDXCW**, OLDNEWYEAR, **SALMONRUN**, SEVENQP, **TENNESSEEQSOPARTY** | some: ARRLDXCW, SALMONRUN, TENNESSEEQSOPARTY | new seam needed: SentExchangeFields / FormatSentExchange (s6) | arm of `case Contest of` @881 |
| `trdos/LogCfg.pas:898` | tSetupExchangeNumbers | 1 | **CALQSOPARTY**, CUPRFCW, CUPRFSSB, **OHIOQSOPARTY**, RAEM, UA4WCHAMPIONSHIP | some: CALQSOPARTY, OHIOQSOPARTY | new seam needed: SentExchangeFields / FormatSentExchange (s6) | arm of `case Contest of` @881 |
| `trdos/LogCfg.pas:905` | tSetupExchangeNumbers | 1 | CQ160CW, CQ160SSB, **IARU**, JIDXCW, JIDXSSB, LZDX, OZCR_O, OZCR_Z | some: IARU | new seam needed: SentExchangeFields / FormatSentExchange (s6) | arm of `case Contest of` @881 |
| `trdos/LogCfg.pas:917` | tSetupExchangeNumbers | 1 | **CQIR** | all | new seam needed: SentExchangeFields / FormatSentExchange (s6) | arm of `case Contest of` @881 |
| `trdos/LogCfg.pas:929` | tSetupExchangeNumbers | 1 | NZFIELDDAY | none | new seam needed: SentExchangeFields / FormatSentExchange (s6) | arm of `case Contest of` @881 |
| `trdos/LogCfg.pas:933` | tSetupExchangeNumbers | 1 | OZHCRVHF, RADIOVHFFD | none | new seam needed: SentExchangeFields / FormatSentExchange (s6) | arm of `case Contest of` @881 |
| `trdos/LogCfg.pas:935` | tSetupExchangeNumbers | 1 | NRAUBALTICCW, NRAUBALTICSSB, RU3AXMEMORIAL, UBACW, UBASSB | none | new seam needed: SentExchangeFields / FormatSentExchange (s6) | arm of `case Contest of` @881 |
| `trdos/LogCfg.pas:937` | tSetupExchangeNumbers | 1 | HELVETIA, IOTA, PCC | none | new seam needed: SentExchangeFields / FormatSentExchange (s6) | arm of `case Contest of` @881 |
| `trdos/LogCfg.pas:939` | tSetupExchangeNumbers | 1 | EUSPRINT_AUTUMN_CW, EUSPRINT_AUTUMN_SSB, EUSPRINT_SPRING_CW, EUSPRINT_SPRING_SSB | none | new seam needed: SentExchangeFields / FormatSentExchange (s6) | arm of `case Contest of` @881 |
| `trdos/LogCfg.pas:945` | tSetupExchangeNumbers | 1 | CWOPEN | none | new seam needed: SentExchangeFields / FormatSentExchange (s6) | arm of `case Contest of` @881 |
| `trdos/fcontest.pas:299` | SetUpRSTMyZoneExchange | 4 | CQWWRTTY | none | new seam needed: ConfigureSession | reach 1: `AE` = RSTZoneAndPossibleDomesticQTHExchange |
| `trdos/fcontest.pas:1617` | FoundContest | 1 | CUPRFSSB | none | new seam needed: ConfigureSession (the FoundContest arm) | `Contest` compare |
| `trdos/fcontest.pas:1638` | FoundContest | 1 | RFCHAMPIONSHIPCW | none | new seam needed: ConfigureSession (the FoundContest arm) | `Contest` compare |
| `trdos/fcontest.pas:1871` | FoundContest | 1 | JIDXCW, JIDXSSB | none | new seam needed: ConfigureSession (the FoundContest arm) | `Contest` in |

### Networking and score reporting (12 rows)

| file:line | routine | shape | contest(s) -- **bold = has a class** | class? | seam | what |
|---|---|---|---|---|---|---|
| `trdos/logsubs2.pas:2762` | SendScoreToUDP | 1 | WRTC | none | new seam needed: ScoreReportMults | `Contest` compare |
| `uExchangeBuilder.pas:112` | BuildSentExchangeText | 2 | RTC | none | new seam needed: CanonicalSentExchange | `RXData.ceContest` compare |
| `uExchangeBuilder.pas:154` | BuildRxExchangeText | 2 | **CQWPXCW**, **CQWPXSSB**, DARCWAEDCCW | some: CQWPXCW, CQWPXSSB | new seam needed: CanonicalReceivedExchange | arm of `case RXData.ceContest of` @152 |
| `uExchangeBuilder.pas:158` | BuildRxExchangeText | 2 | **CQWWCW**, **CQWWSSB**, **IARU** | all | new seam needed: CanonicalReceivedExchange | arm of `case RXData.ceContest of` @152 |
| `uExchangeBuilder.pas:162` | BuildRxExchangeText | 2 | CQ160CW | none | new seam needed: CanonicalReceivedExchange | arm of `case RXData.ceContest of` @152 |
| `uExchangeBuilder.pas:168` | BuildRxExchangeText | 2 | **ARRLDXCW**, **ARRLDXSSB** | all | new seam needed: CanonicalReceivedExchange | arm of `case RXData.ceContest of` @152 |
| `uExchangeBuilder.pas:179` | BuildRxExchangeText | 2 | ALLASIANCW, ALLASIANSSB | none | new seam needed: CanonicalReceivedExchange | arm of `case RXData.ceContest of` @152 |
| `uExchangeBuilder.pas:183` | BuildRxExchangeText | 2 | CWOPS | none | new seam needed: CanonicalReceivedExchange | arm of `case RXData.ceContest of` @152 |
| `uExchangeBuilder.pas:193` | BuildRxExchangeText | 2 | NAQSOCW, NAQSORTTY, NAQSOSSB, SST | none | new seam needed: CanonicalReceivedExchange | arm of `case RXData.ceContest of` @152 |
| `uExchangeBuilder.pas:197` | BuildRxExchangeText | 2 | CWOPEN | none | new seam needed: CanonicalReceivedExchange | arm of `case RXData.ceContest of` @152 |
| `uExchangeBuilder.pas:205` | BuildRxExchangeText | 2 | RTC | none | new seam needed: CanonicalReceivedExchange | arm of `case RXData.ceContest of` @152 |
| `uExchangeBuilder.pas:211` | BuildRxExchangeText | 2 | **ARRLFIELDDAY**, **WINTERFIELDDAY** | all | new seam needed: CanonicalReceivedExchange | arm of `case RXData.ceContest of` @152 |

### Other (26 rows)

| file:line | routine | shape | contest(s) -- **bold = has a class** | class? | seam | what |
|---|---|---|---|---|---|---|
| `trdos/logddx.pas:250` | GetRandomDDXCallsign | 3 | SACCW, SACSSB | none | new seam needed: SimulatorRules (DDX) | `Settings.Contest.Name = 'Scandinavian Contest'` -- see dead code |
| `trdos/logddx.pas:296` | GetRandomDDXCallsign | 4 | ARI_DX | none | new seam needed: SimulatorRules (DDX) | reach 1: `XM` = ARRLDXCCWithNoIOrIS0 (arm of case @269) |
| `trdos/logddx.pas:311` | GetRandomDDXCallsign | 4 | DARCWAEDCCW, DARCWAEDCSSB | none | new seam needed: SimulatorRules (DDX) | reach 2: `XM` = CQEuropeanCountries (arm of case @269) |
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

## 5. Setup -- `FoundContest`'s `case Contest of` (`fcontest.pas:472`)

**104 arms naming 131 contests; 32 of those contests have a class**
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
<!-- END HAND-MAINTAINED: setup-seam -->

3 more shape-1 tests in `FoundContest` sit outside the case -- `fcontest.pas:1617` (`CUPRFSSB`), `fcontest.pas:1638` (`RFCHAMPIONSHIPCW`), `fcontest.pas:1871` (`JIDXCW`, `JIDXSSB`) --
and are in the Setup table in section 4.

| lines | contest(s) -- **bold = has a class** | what the arm assigns |
|---|---|---|
| `fcontest.pas:486-503` | **ArizonaQsoParty** | Active* 1, CQmem 2, Settings 4 |
| `fcontest.pas:504-522` | **NYQP** | Active* 1 |
| `fcontest.pas:523-532` | **BCQP** | Active* 1, domfile 1 |
| `fcontest.pas:533-544` | **WINTERFIELDDAY** | Active* 1, CQmem 2, Settings 4, domfile 1 |
| `fcontest.pas:545-558` | **ARRLFIELDDAY** | Active* 2, CQmem 2, Settings 5, domfile 1 |
| `fcontest.pas:619-624` | **ALLJA**, YOTA | band 1 |
| `fcontest.pas:625-631` | **JALONGPREFECT** | band 1 |
| `fcontest.pas:675-692` | **ARRLDXCW**, **ARRLDXSSB** | Active* 4, Settings 1, domfile 2 |
| `fcontest.pas:757-763` | **APSPRINT** | band 1 |
| `fcontest.pas:779-796` | **CALQSOPARTY** | Active* 2 |
| `fcontest.pas:892-899` | **GENERALQSO** | Settings 4 |
| `fcontest.pas:973-1007` | **INTERNETSPRINT** | CQmem 15, Settings 8, band 1, domfile 2 |
| `fcontest.pas:1014-1018` | **KIDSDAY** | Settings 1 |
| `fcontest.pas:1019-1041` | **KVP** | band 1 |
| `fcontest.pas:1042-1054` | **MINNQSOPARTY** | calls only |
| `fcontest.pas:1055-1058` | **MOQSOPARTY** | calls only |
| `fcontest.pas:1213-1220` | **QCWA** | domfile 3 |
| `fcontest.pas:1279-1297` | **SALMONRUN** | Active* 3 |
| `fcontest.pas:1323-1362` | **NASPRINTCW**, **NASPRINTRTTY** | CQmem 17, Settings 8, band 1, domfile 2 |
| `fcontest.pas:1403-1472` | **ARRLSSCW**, **ARRLSSSSB** | CQmem 21, Settings 7, domfile 1 |
| `fcontest.pas:1479-1495` | **TEXASQSOPARTY** | Active* 2 |
| `fcontest.pas:1522-1529` | **VAQP** | other:tAllowDupeQSOs 1 |
| `fcontest.pas:1550-1558` | **DARCXMAS** | Settings 2, domfile 1 |
| `fcontest.pas:1648-1655` | **MINITEST**, **MINI80** | Settings 3, band 1 |
| `fcontest.pas:1656-1663` | **MINI40** | Settings 3, band 1 |
| `fcontest.pas:1697-1705` | **YOUTHCHAMPIONSHIPRF** | Settings 3, band 1 |
| `fcontest.pas:1761-1765` | **CQIR** | domfile 1 |
| `fcontest.pas:1814-1822` | **ARRLDIGI** | Settings 3 |
| `fcontest.pas:474-485` | LABRE | CQmem 2, Settings 3 |
| `fcontest.pas:559-566` | CROATIAN | Active* 1 |
| `fcontest.pas:567-586` | JIDXSSB, JIDXCW | Active* 6, domfile 1 |
| `fcontest.pas:587-598` | SOUTHAMERICANWW | Active* 2 |
| `fcontest.pas:599-606` | STEWPERRY | Settings 3, band 1 |
| `fcontest.pas:607-618` | ALLASIANCW, ALLASIANSSB | Active* 2 |
| `fcontest.pas:632-637` | ARCI | domfile 1 |
| `fcontest.pas:638-645` | ARI_DX | domfile 3 |
| `fcontest.pas:646-657` | ARRL10 | Active* 1, Settings 1, band 1, domfile 2 |
| `fcontest.pas:658-674` | ARRL160 | Active* 3, domfile 1 |
| `fcontest.pas:693-713` | ARRL_RTTY_ROUNDUP | domfile 1 |
| `fcontest.pas:714-721` | WWDIGI | Settings 3 |
| `fcontest.pas:722-747` | RTC | CQmem 4, Settings 4 |
| `fcontest.pas:748-756` | ARRLVHFJUN, ARRLVHFSEP | Settings 2, band 1 |
| `fcontest.pas:764-771` | BALTIC | band 1 |
| `fcontest.pas:772-778` | BATAVIA_FT8 | Settings 3 |
| `fcontest.pas:797-819` | CIS | domfile 12 |
| `fcontest.pas:820-827` | CQ160SSB, CQ160CW | Settings 1, domfile 1 |
| `fcontest.pas:828-833` | CQM | Settings 1 |
| `fcontest.pas:834-862` | CQVHF | Settings 1, band 1 |
| `fcontest.pas:863-869` | EUSPRINT_SPRING_SSB, EUSPRINT_AUTUMN_CW, EUSPRINT_AUTUMN_SSB, EUSPRINT_SPRING_CW | band 1 |
| `fcontest.pas:870-880` | RADIOVHFFD | Settings 6, band 1 |
| `fcontest.pas:881-888` | EUROPEANVHF | Settings 1, band 1 |
| `fcontest.pas:889-891` | FOCMARATHON | Settings 1 |
| `fcontest.pas:900-904` | HADX | domfile 1 |
| `fcontest.pas:905-915` | IRTS | Active* 1, Settings 1, band 1, other:INITIALEXCHANGECURSORPOS 1 |
| `fcontest.pas:916-921` | EUDX | calls only |
| `fcontest.pas:922-931` | YUDX | Active* 2, domfile 1 |
| `fcontest.pas:932-949` | UKEI | domfile 9 |
| `fcontest.pas:950-959` | HELVETIA | Active* 1, domfile 1 |
| `fcontest.pas:960-964` | OZCR_Z | Settings 1 |
| `fcontest.pas:965-972` | GAGARINCUP | Settings 4 |
| `fcontest.pas:1008-1013` | KCJ | Active* 1, Settings 1 |
| `fcontest.pas:1059-1065` | MWC | band 1, domfile 1 |
| `fcontest.pas:1066-1074` | SST | Active* 1, Settings 3, domfile 1 |
| `fcontest.pas:1075-1109` | NAQSOCW, NAQSOSSB, NAQSORTTY | CQmem 15, Settings 7, domfile 1 |
| `fcontest.pas:1110-1137` | NEWENGLANDQSO | Active* 3, domfile 3, other:DXMultLimit 1, other:TempWord 1 |
| `fcontest.pas:1138-1155` | NRAUBALTICCW, NRAUBALTICSSB | band 1, domfile 13 |
| `fcontest.pas:1156-1162` | OKOMSSB | band 1, domfile 2 |
| `fcontest.pas:1163-1177` | OKDX | Active* 2, domfile 3 |
| `fcontest.pas:1178-1196` | PACC | Active* 3, Settings 1, domfile 3 |
| `fcontest.pas:1197-1212` | POTA | CQmem 2, Settings 5, other:tAllowDupeQSOs 1 |
| `fcontest.pas:1221-1227` | RAEM | Settings 1, band 1, other:InitialExchangeCursorPos 1 |
| `fcontest.pas:1228-1239` | CANADA_DAY, CANADA_WINTER | Settings 1, domfile 3 |
| `fcontest.pas:1240-1255` | RSGB_ROPOCO_CW, RSGB_ROPOCO_SSB | CQmem 6, Settings 4, band 1 |
| `fcontest.pas:1256-1266` | RDA | Active* 1, domfile 1, other:DomesticMultByBand 1 |
| `fcontest.pas:1267-1278` | RUSSIANDX, RU3AXMEMORIAL | Settings 1, domfile 2 |
| `fcontest.pas:1298-1309` | SACCW, SACSSB | Active* 2 |
| `fcontest.pas:1310-1316` | YBDX | Active* 2, band 1 |
| `fcontest.pas:1317-1322` | SPDX | domfile 1 |
| `fcontest.pas:1363-1402` | SPRINTSSB | CQmem 17, Settings 8, band 1, domfile 1 |
| `fcontest.pas:1473-1478` | TENTEN | domfile 1 |
| `fcontest.pas:1496-1512` | UBACW, UBASSB | Active* 5, Settings 1, band 1 |
| `fcontest.pas:1513-1521` | UKRAINIAN | Active* 1, domfile 1 |
| `fcontest.pas:1530-1549` | DARC10M | Active* 2, Settings 2, band 1, domfile 2 |
| `fcontest.pas:1559-1576` | WAG | Active* 2, Settings 1, domfile 1 |
| `fcontest.pas:1577-1607` | DARCWAEDCCW, DARCWAEDCSSB | Active* 2, Settings 2, band 1 |
| `fcontest.pas:1608-1613` | YODX | Settings 1, domfile 1 |
| `fcontest.pas:1614-1624` | CUPRFCW, CUPRFSSB, CUPRFDIG | Settings 2, band 2 |
| `fcontest.pas:1625-1629` | UA4WCHAMPIONSHIP | Settings 1 |
| `fcontest.pas:1630-1634` | R9W_UW9WK_MEMORIAL | Settings 1 |
| `fcontest.pas:1635-1647` | RFCHAMPIONSHIPCW, RFCHAMPIONSHIPSSB | Settings 1, band 2, other:DomesticMultByBand 1 |
| `fcontest.pas:1664-1669` | LZDX | band 1, domfile 1 |
| `fcontest.pas:1670-1687` | ALRS_UA1DZ_CUP | Active* 2, Settings 2, domfile 1, other:TempOblast 1 |
| `fcontest.pas:1688-1693` | OLDNEWYEAR | Settings 1, band 1 |
| `fcontest.pas:1694-1696` | CQWPXRTTY, WRTC | band 1 |
| `fcontest.pas:1706-1711` | RFASCHAMPIONSHIPCW | calls only |
| `fcontest.pas:1712-1733` | SEVENQP | Active* 3, other:DXMultLimit 1 |
| `fcontest.pas:1734-1739` | OZCR_O | Settings 2 |
| `fcontest.pas:1740-1754` | LQP, NCCCSPRINT | Settings 4, domfile 2, other:tAllowDupeQSOs 1 |
| `fcontest.pas:1755-1760` | JTDX | Active* 2 |
| `fcontest.pas:1766-1771` | UNDX | domfile 1 |
| `fcontest.pas:1772-1779` | KINGOFSPAINCW, KINGOFSPAINSSB | domfile 4 |
| `fcontest.pas:1780-1789` | CQMM | Active* 1, band 1, other:DXCCMultByBand 1 |
| `fcontest.pas:1790-1795` | OZHCRVHF | Settings 1 |
| `fcontest.pas:1796-1813` | PCC | Settings 2 |

---

## 6. Per-contest index

Every site from sections 4 and 5, by contest. Shape-4 rows are included for
every contest the tested value reaches (reach 1-3).

### 6.1 Registered contests -- rules that should already have moved

**53 of 56.** Sorted by number of sites. Registered contests with
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
  Their export twins are `trdos/postunit.pas:2377` (Field Days), `:2409` (SS),
  `:2429` (IARU), `:2432` (ARRL Digi).
<!-- END HAND-MAINTAINED: registered-first-reads -->

| contest | sites outside the factory, by category |
|---|---|
| WINTERFIELDDAY | **scoring** `trdos/logstuff.pas:6709`; **exchange** `trdos/logdupe.pas:1632`, `trdos/logstuff.pas:10257`, `trdos/logstuff.pas:10939`, `trdos/logstuff.pas:10971`; **multipliers** `trdos/logdupe.pas:683`; **adif-import** `MainUnit.pas:9999`, `MainUnit.pas:11421`, `uADIF.pas:1109`; **adif-export** `trdos/postunit.pas:2377`, `uADIFExchange.pas:436`; **cabrillo-export** `trdos/postunit.pas:2669`, `trdos/postunit.pas:2730`, `trdos/postunit.pas:3013`, `uCabrilloExchange.pas:469`; **score-summary** `trdos/logedit.pas:2868`, `trdos/postunit.pas:1077`, `trdos/postunit.pas:1089`; **ui** `uNewContest.pas:381`; **setup** `trdos/fcontest.pas:533`; **networking** `uExchangeBuilder.pas:211`; **other** `trdos/logddx.pas:606`, `trdos/logddx.pas:632`, `trdos/logddx.pas:653`, `trdos/logddx.pas:674`, `trdos/logddx.pas:705`, `trdos/logddx.pas:732`, `trdos/logddx.pas:753`, `trdos/logddx.pas:856`, `trdos/logddx.pas:907` |
| ARRLFIELDDAY | **scoring** `trdos/logstuff.pas:6709`; **exchange** `trdos/logdupe.pas:1632`, `trdos/logstuff.pas:10257`, `trdos/logstuff.pas:10938`, `trdos/logstuff.pas:10967`; **adif-import** `MainUnit.pas:9999`, `MainUnit.pas:11421`, `uADIF.pas:1109`; **adif-export** `trdos/postunit.pas:2377`, `uADIFExchange.pas:436`; **cabrillo-export** `uCabrilloExchange.pas:469`; **score-summary** `trdos/logedit.pas:2859`, `trdos/postunit.pas:1118`; **ui** `uNewContest.pas:387`; **setup** `trdos/fcontest.pas:545`; **networking** `uExchangeBuilder.pas:211`; **other** `trdos/logddx.pas:606`, `trdos/logddx.pas:632`, `trdos/logddx.pas:653`, `trdos/logddx.pas:674`, `trdos/logddx.pas:705`, `trdos/logddx.pas:732`, `trdos/logddx.pas:753`, `trdos/logddx.pas:856`, `trdos/logddx.pas:907` |
| ARRLSSCW | **exchange** `trdos/logdupe.pas:1721`, `trdos/logedit.pas:2521`, `trdos/logedit.pas:2669`, `trdos/logstuff.pas:10470`; **adif-import** `MainUnit.pas:9999`; **adif-export** `trdos/postunit.pas:2409`, `uADIFExchange.pas:326`; **cabrillo-export** `uCabrilloExchange.pas:274`; **ui** `MainUnit.pas:9469`, `MainUnit.pas:9471`, `uNewContest.pas:393`; **setup** `trdos/fcontest.pas:1403`; **other** `trdos/logddx.pas:605`, `trdos/logddx.pas:631`, `trdos/logddx.pas:652`, `trdos/logddx.pas:673`, `trdos/logddx.pas:704`, `trdos/logddx.pas:731`, `trdos/logddx.pas:752`, `trdos/logddx.pas:864`, `trdos/logddx.pas:1009` |
| ARRLSSSSB | **exchange** `trdos/logdupe.pas:1721`, `trdos/logedit.pas:2521`, `trdos/logedit.pas:2669`, `trdos/logstuff.pas:10470`; **adif-import** `MainUnit.pas:9999`; **adif-export** `trdos/postunit.pas:2409`, `uADIFExchange.pas:326`; **cabrillo-export** `uCabrilloExchange.pas:274`; **ui** `MainUnit.pas:9469`, `MainUnit.pas:9471`, `uNewContest.pas:393`; **setup** `trdos/fcontest.pas:1403`; **other** `trdos/logddx.pas:605`, `trdos/logddx.pas:631`, `trdos/logddx.pas:652`, `trdos/logddx.pas:673`, `trdos/logddx.pas:704`, `trdos/logddx.pas:731`, `trdos/logddx.pas:752`, `trdos/logddx.pas:864`, `trdos/logddx.pas:1009` |
| GENERALQSO | **exchange** `MainUnit.pas:7080`, `trdos/logdupe.pas:1823`, `trdos/logstuff.pas:10241`, `trdos/logstuff.pas:10394`; **adif-import** `MainUnit.pas:9966`; **adif-export** `uADIF.pas:1535`, `uADIFExchange.pas:272`; **cabrillo-export** `trdos/postunit.pas:2691`, `uCabrilloExchange.pas:209`; **score-summary** `trdos/postunit.pas:1272`; **ui** `MainUnit.pas:1747`, `trdos/logedit.pas:1965`, `trdos/logstuff.pas:969`, `trdos/logsubs2.pas:2482`, `trdos/logsubs2.pas:2506`, `trdos/logwind.pas:2421`; **setup** `trdos/fcontest.pas:892` |
| IARU | **scoring** `trdos/logstuff.pas:7999`; **exchange** `trdos/logedit.pas:2681`, `trdos/logstuff.pas:4047`; **adif-import** `MainUnit.pas:10043`; **adif-export** `trdos/postunit.pas:2429`; **score-summary** `uTotal.pas:301`, `uTotal.pas:327`; **ui** `MainUnit.pas:4459`, `uNewContest.pas:225`, `uNewContest.pas:340`; **setup** `trdos/LogCfg.pas:905`; **networking** `uExchangeBuilder.pas:158` |
| ARRLDIGI | **scoring** `trdos/logstuff.pas:6732`; **exchange** `trdos/logdupe.pas:1773`, `trdos/logstuff.pas:10346`; **adif-import** `MainUnit.pas:10094`, `MainUnit.pas:10103`; **adif-export** `trdos/postunit.pas:2432`; **ui** `uNewContest.pas:301`; **setup** `trdos/fcontest.pas:1814` |
| YOUTHCHAMPIONSHIPRF | **scoring** `trdos/logstuff.pas:8938`; **exchange** `trdos/logdupe.pas:1729`, `trdos/logstuff.pas:10320`; **dupe** `trdos/logsubs2.pas:1614`; **adif-export** `uADIFExchange.pas:361`; **cabrillo-export** `uCabrilloExchange.pas:321`; **ui** `uNewContest.pas:412`; **setup** `trdos/fcontest.pas:1697` |
| CALQSOPARTY | **scoring** `trdos/logstuff.pas:8941`; **exchange** `trdos/logedit.pas:2644`, `trdos/logstuff.pas:10293`; **cabrillo-export** `trdos/postunit.pas:3063`; **setup** `trdos/LogCfg.pas:898`, `trdos/fcontest.pas:779`; **other** `trdos/logddx.pas:860` |
| ARRLDXCW | **scoring** `trdos/logstuff.pas:6685`; **ui** `uNewContest.pas:180`, `uNewContest.pas:418`; **setup** `trdos/LogCfg.pas:896`, `trdos/fcontest.pas:675`; **networking** `uExchangeBuilder.pas:168` |
| CQIR | **exchange** `trdos/logedit.pas:2653`, `trdos/logstuff.pas:10435`; **ui** `uNewContest.pas:212`, `uNewContest.pas:313`; **setup** `trdos/LogCfg.pas:917`, `trdos/fcontest.pas:1761` |
| CQWWCW | **scoring** `trdos/logstuff.pas:7221`; **exchange** `trdos/logedit.pas:2239`; **adif-import** `MainUnit.pas:10025`; **score-summary** `trdos/postunit.pas:1148`; **ui** `MainUnit.pas:4459`; **networking** `uExchangeBuilder.pas:158` |
| VAQP | **scoring** `trdos/logstuff.pas:9739`; **exchange** `trdos/logedit.pas:2644`, `trdos/logstuff.pas:10293`; **ui** `uNewContest.pas:171`; **setup** `trdos/fcontest.pas:1522`; **other** `trdos/logddx.pas:860` |
| BCQP | **scoring** `trdos/logstuff.pas:7612`; **multipliers** `trdos/logdupe.pas:1272`; **ui** `uNewContest.pas:254`, `uNewContest.pas:263`; **setup** `trdos/fcontest.pas:523` |
| CQWWSSB | **scoring** `trdos/logstuff.pas:7221`; **adif-import** `MainUnit.pas:10025`; **score-summary** `trdos/postunit.pas:1148`; **ui** `MainUnit.pas:4459`; **networking** `uExchangeBuilder.pas:158` |
| KVP | **exchange** `trdos/logstuff.pas:5762`; **multipliers** `trdos/logdupe.pas:2256`, `trdos/logedit.pas:1471`; **ui** `uNewContest.pas:281`; **setup** `trdos/fcontest.pas:1019` |
| MOQSOPARTY | **scoring** `MainUnit.pas:7920`, `trdos/logdupe.pas:1104`, `trdos/logsubs2.pas:1735`; **score-summary** `trdos/logedit.pas:2995`; **setup** `trdos/fcontest.pas:1055` |
| ALLJA | **exchange** `trdos/logdupe.pas:1759`, `trdos/logdupe.pas:2074`, `trdos/logstuff.pas:10332`; **setup** `trdos/fcontest.pas:619` |
| ARKTIKA_SPRING | **scoring** `trdos/logstuff.pas:9370`; **exchange** `trdos/logstuff.pas:5334`; **ui** `uNewContest.pas:235`, `uNewContest.pas:347` |
| ARRLDXSSB | **scoring** `trdos/logstuff.pas:6685`; **ui** `uNewContest.pas:418`; **setup** `trdos/fcontest.pas:675`; **networking** `uExchangeBuilder.pas:168` |
| COUNTYHUNTER | **exchange** `MainUnit.pas:922`, `MainUnit.pas:963`, `MainUnit.pas:2046`, `trdos/logstuff.pas:10448` |
| EUROPEANHFC | **exchange** `trdos/logstuff.pas:5762`; **multipliers** `trdos/logdupe.pas:2256`, `trdos/logedit.pas:1471`; **ui** `uNewContest.pas:279` |
| QCWA | **exchange** `trdos/logdupe.pas:1706`, `trdos/logstuff.pas:10305`; **setup** `trdos/fcontest.pas:1213`; **other** `trdos/logddx.pas:862` |
| DARCXMAS | **ui** `uNewContest.pas:218`, `uNewContest.pas:336`; **setup** `trdos/fcontest.pas:1550` |
| GRIDLOC | **exchange** `trdos/logdupe.pas:1662`, `trdos/logstuff.pas:10275`; **other** `trdos/logddx.pas:859` |
| INTERNETSPRINT | **scoring** `trdos/logstuff.pas:8938`; **dupe** `trdos/logsubs2.pas:1614`; **setup** `trdos/fcontest.pas:973` |
| JALONGPREFECT | **exchange** `trdos/logdupe.pas:1902`, `trdos/logstuff.pas:10475`; **setup** `trdos/fcontest.pas:625` |
| KIDSDAY | **exchange** `trdos/logdupe.pas:1638`, `trdos/logstuff.pas:10264`; **setup** `trdos/fcontest.pas:1014` |
| NASPRINTCW | **adif-export** `trdos/postunit.pas:2415`; **ui** `uNewContest.pas:400`; **setup** `trdos/fcontest.pas:1323` |
| NASPRINTRTTY | **adif-export** `trdos/postunit.pas:2415`; **ui** `uNewContest.pas:400`; **setup** `trdos/fcontest.pas:1323` |
| OHIOQSOPARTY | **exchange** `trdos/logedit.pas:2652`, `trdos/logstuff.pas:10413`; **setup** `trdos/LogCfg.pas:898` |
| QCWAGOLDEN | **exchange** `trdos/logdupe.pas:1706`, `trdos/logstuff.pas:10305`; **other** `trdos/logddx.pas:862` |
| SALMONRUN | **scoring** `trdos/logstuff.pas:8500`; **setup** `trdos/LogCfg.pas:896`, `trdos/fcontest.pas:1279` |
| CQWPXCW | **scoring** `trdos/logstuff.pas:7108`; **networking** `uExchangeBuilder.pas:154` |
| CQWPXSSB | **scoring** `trdos/logstuff.pas:7108`; **networking** `uExchangeBuilder.pas:154` |
| MINNQSOPARTY | **ui** `uNewContest.pas:267`; **setup** `trdos/fcontest.pas:1042` |
| NCQSOPARTY | **scoring** `trdos/logstuff.pas:7563`, `trdos/logstuff.pas:7578` |
| NYQP | **multipliers** `trdos/logdupe.pas:1276`; **setup** `trdos/fcontest.pas:504` |
| SASPRINT | **exchange** `MainUnit.pas:7249`; **multipliers** `trdos/logedit.pas:3027` |
| XMAS | **exchange** `trdos/logdupe.pas:1875`, `trdos/logstuff.pas:10440` |
| APSPRINT | **setup** `trdos/fcontest.pas:757` |
| ArizonaQsoParty | **setup** `trdos/fcontest.pas:486` |
| COLORADOQSOPARTY | **ui** `uNewContest.pas:267` |
| IDAHOQSOPARTY | **scoring** `trdos/logstuff.pas:6709` |
| INQSOPARTY | **multipliers** `trdos/logdupe.pas:1280` |
| MINI40 | **setup** `trdos/fcontest.pas:1656` |
| MINI80 | **setup** `trdos/fcontest.pas:1648` |
| MINITEST | **setup** `trdos/fcontest.pas:1648` |
| MST | **ui** `uNewContest.pas:355` |
| PAQSOPARTY | **scoring** `trdos/logstuff.pas:7626` |
| TENNESSEEQSOPARTY | **setup** `trdos/LogCfg.pas:896` |
| TEXASQSOPARTY | **setup** `trdos/fcontest.pas:1479` |
| WISCONSINQSOPARTY | **setup** `trdos/LogCfg.pas:888` |

### 6.2 Contests with no class

**129** -- every contest without a class (185 non-sentinel enum values minus
56) appears at least once in section 4 or section 5.
Contests that exist only as an operator-configured name, with no
`ContestType` at all, appear only in the shape-3 rows: **TRC Digital** (`cMyState = 'TRC'`, 5 sites) and **PGA** (`ContestTitle = 'PGA'`, 2 sites).

| contest | sites outside the factory, by category |
|---|---|
| POTA | **exchange** `MainUnit.pas:4039`, `MainUnit.pas:7080`, `trdos/logdupe.pas:1740`, `trdos/logstuff.pas:10241`, `trdos/logstuff.pas:10356`; **adif-import** `MainUnit.pas:10077`, `trdos/logstuff.pas:11185`; **adif-export** `trdos/postunit.pas:2292`, `trdos/postunit.pas:2306`, `trdos/postunit.pas:2418`, `uADIF.pas:1535`, `uADIFExchange.pas:365`; **ui** `MainUnit.pas:4505`, `uNewContest.pas:233`, `uNewContest.pas:377`; **setup** `trdos/fcontest.pas:1197` |
| FOCMARATHON | **scoring** `trdos/logstuff.pas:7492`, `trdos/logstuff.pas:7494`; **adif-import** `MainUnit.pas:10040`, `uADIF.pas:1113`; **adif-export** `uADIF.pas:1611`, `uADIFExchange.pas:370`, `uADIFExchange.pas:377`; **cabrillo-export** `uCabrilloExchange.pas:341`, `uCabrilloExchange.pas:348`; **ui** `MainUnit.pas:8243`, `MainUnit.pas:9484`, `MainUnit.pas:9488`, `uNewContest.pas:366`; **setup** `trdos/fcontest.pas:889` |
| RFCHAMPIONSHIPCW | **scoring** `trdos/logstuff.pas:9101`; **exchange** `trdos/logdupe.pas:1687`, `trdos/logedit.pas:2404`, `trdos/logstuff.pas:10290`; **multipliers** `trdos/logdupe.pas:2260`, `trdos/logedit.pas:1015`; **adif-export** `uADIFExchange.pas:472`; **cabrillo-export** `uCabrilloExchange.pas:548`; **score-summary** `trdos/logedit.pas:2974`, `trdos/postunit.pas:1446`; **ui** `uNewContest.pas:283`; **setup** `trdos/LogCfg.pas:894`, `trdos/fcontest.pas:1635`, `trdos/fcontest.pas:1638` |
| RFCHAMPIONSHIPSSB | **scoring** `trdos/logstuff.pas:9101`; **exchange** `trdos/logdupe.pas:1687`, `trdos/logedit.pas:2404`, `trdos/logstuff.pas:10290`; **multipliers** `trdos/logdupe.pas:2260`, `trdos/logedit.pas:1015`; **adif-export** `uADIFExchange.pas:472`; **cabrillo-export** `uCabrilloExchange.pas:548`; **score-summary** `trdos/logedit.pas:2974`, `trdos/postunit.pas:1446`; **ui** `uNewContest.pas:283`; **setup** `trdos/LogCfg.pas:894`, `trdos/fcontest.pas:1635` |
| CUPRFSSB | **scoring** `trdos/logstuff.pas:9006`; **exchange** `trdos/logedit.pas:2647`, `trdos/logstuff.pas:10301`; **adif-export** `uADIFExchange.pas:389`; **cabrillo-export** `trdos/postunit.pas:3053`, `uCabrilloExchange.pas:361`; **score-summary** `trdos/logedit.pas:2962`, `trdos/postunit.pas:1446`; **ui** `uNewContest.pas:299`; **setup** `trdos/LogCfg.pas:898`, `trdos/fcontest.pas:1614`, `trdos/fcontest.pas:1617` |
| CUPRFCW | **scoring** `trdos/logstuff.pas:9006`; **exchange** `trdos/logedit.pas:2647`, `trdos/logstuff.pas:10301`; **adif-export** `uADIFExchange.pas:389`; **cabrillo-export** `trdos/postunit.pas:3053`, `uCabrilloExchange.pas:361`; **score-summary** `trdos/logedit.pas:2962`, `trdos/postunit.pas:1446`; **ui** `uNewContest.pas:299`; **setup** `trdos/LogCfg.pas:898`, `trdos/fcontest.pas:1614` |
| JIDXCW | **scoring** `trdos/logstuff.pas:8114`; **exchange** `trdos/logedit.pas:2763`, `trdos/logstuff.pas:10404`; **adif-export** `uADIFExchange.pas:318`; **cabrillo-export** `uCabrilloExchange.pas:262`, `uCabrilloExchange.pas:556`; **ui** `uNewContest.pas:238`, `uNewContest.pas:320`; **setup** `trdos/LogCfg.pas:905`, `trdos/fcontest.pas:567`, `trdos/fcontest.pas:1871` |
| JIDXSSB | **scoring** `trdos/logstuff.pas:8114`; **exchange** `trdos/logedit.pas:2763`, `trdos/logstuff.pas:10404`; **adif-export** `uADIFExchange.pas:318`; **cabrillo-export** `uCabrilloExchange.pas:262`, `uCabrilloExchange.pas:556`; **ui** `uNewContest.pas:238`, `uNewContest.pas:320`; **setup** `trdos/LogCfg.pas:905`, `trdos/fcontest.pas:567`, `trdos/fcontest.pas:1871` |
| ALLASIANCW | **scoring** `trdos/logstuff.pas:6600`; **exchange** `trdos/logdupe.pas:1753`, `trdos/logstuff.pas:10313`; **adif-export** `uADIFExchange.pas:357`; **cabrillo-export** `uCabrilloExchange.pas:314`; **ui** `uNewContest.pas:412`; **setup** `trdos/LogCfg.pas:896`, `trdos/fcontest.pas:607`; **networking** `uExchangeBuilder.pas:179`; **other** `trdos/logddx.pas:1061` |
| ALLASIANSSB | **scoring** `trdos/logstuff.pas:6600`; **exchange** `trdos/logdupe.pas:1753`, `trdos/logstuff.pas:10313`; **adif-export** `uADIFExchange.pas:357`; **cabrillo-export** `uCabrilloExchange.pas:314`; **ui** `uNewContest.pas:412`; **setup** `trdos/LogCfg.pas:896`, `trdos/fcontest.pas:607`; **networking** `uExchangeBuilder.pas:179`; **other** `trdos/logddx.pas:1061` |
| ALRS_UA1DZ_CUP | **scoring** `trdos/logstuff.pas:6814`; **exchange** `trdos/logdom.pas:224`, `trdos/logstuff.pas:10204`, `trdos/logstuff.pas:10570`; **adif-export** `trdos/postunit.pas:2360`; **score-summary** `trdos/logedit.pas:2968`; **ui** `uNewContest.pas:174`, `uNewContest.pas:272`; **setup** `trdos/LogCfg.pas:896`, `trdos/fcontest.pas:1670` |
| CQMM | **scoring** `trdos/logstuff.pas:9524`; **exchange** `MainUnit.pas:7249`, `trdos/logdupe.pas:1643`, `trdos/logstuff.pas:10329`; **multipliers** `trdos/logedit.pas:3027`, `trdos/logedit.pas:3039`; **adif-export** `uADIFExchange.pas:444`; **cabrillo-export** `uCabrilloExchange.pas:493`; **ui** `uNewContest.pas:291`; **setup** `trdos/fcontest.pas:1780` |
| CQWWRTTY | **scoring** `trdos/logstuff.pas:7240`; **exchange** `trdos/logdupe.pas:1882`, `trdos/logstuff.pas:10451`; **adif-export** `uADIFExchange.pas:409`; **cabrillo-export** `uCabrilloExchange.pas:426`; **score-summary** `trdos/postunit.pas:1148`; **ui** `MainUnit.pas:4459`, `uNewContest.pas:193`, `uNewContest.pas:310`; **setup** `trdos/fcontest.pas:299` |
| DARCWAEDCCW | **scoring** `trdos/logstuff.pas:8874`; **multipliers** `trdos/logdupe.pas:716`, `trdos/logedit.pas:3018`, `uMults.pas:268`; **score-summary** `trdos/logedit.pas:2917`, `trdos/logedit.pas:2920`; **ui** `MainUnit.pas:4492`; **setup** `trdos/fcontest.pas:1577`; **networking** `uExchangeBuilder.pas:154`; **other** `trdos/logddx.pas:311` |
| PCC | **scoring** `trdos/logstuff.pas:9414`; **exchange** `trdos/logstuff.pas:2779`, `trdos/logstuff.pas:5316`; **multipliers** `trdos/logdupe.pas:1297`; **adif-export** `uADIFExchange.pas:491`; **cabrillo-export** `uCabrilloExchange.pas:575`; **ui** `uNewContest.pas:235`, `uNewContest.pas:347`; **setup** `trdos/LogCfg.pas:937`, `trdos/fcontest.pas:1796` |
| RAEM | **scoring** `trdos/logstuff.pas:8331`, `trdos/logstuff.pas:8343`; **exchange** `trdos/logdupe.pas:1675`, `trdos/logstuff.pas:10282`, `uCallSignRoutines.pas:669`; **adif-export** `uADIFExchange.pas:433`; **cabrillo-export** `uCabrilloExchange.pas:481`; **ui** `uNewContest.pas:284`; **setup** `trdos/LogCfg.pas:898`, `trdos/fcontest.pas:1221` |
| RU3AXMEMORIAL | **scoring** `trdos/logstuff.pas:8456`, `trdos/logstuff.pas:8493`; **exchange** `trdos/logedit.pas:2616`, `trdos/zonecont.pas:92`; **score-summary** `trdos/postunit.pas:1446`, `uTotal.pas:332`; **ui** `uNewContest.pas:206`, `uNewContest.pas:312`; **setup** `trdos/LogCfg.pas:935`, `trdos/fcontest.pas:1267` |
| SOUTHAMERICANWW | **scoring** `trdos/logstuff.pas:8638`; **exchange** `MainUnit.pas:7249`, `MainUnit.pas:7253`, `trdos/logdupe.pas:1643`, `trdos/logstuff.pas:10329`; **multipliers** `trdos/logedit.pas:3027`, `trdos/logedit.pas:3044`; **adif-export** `uADIFExchange.pas:444`; **cabrillo-export** `uCabrilloExchange.pas:493`; **setup** `trdos/fcontest.pas:587` |
| UBACW | **scoring** `trdos/logstuff.pas:8752`; **exchange** `MainUnit.pas:7235`; **multipliers** `trdos/logdupe.pas:722`, `trdos/logedit.pas:3020`, `uMults.pas:271`; **adif-import** `MainUnit.pas:9980`; **ui** `uNewContest.pas:209`, `uNewContest.pas:334`; **setup** `trdos/LogCfg.pas:935`, `trdos/fcontest.pas:1496` |
| UBASSB | **scoring** `trdos/logstuff.pas:8752`; **exchange** `MainUnit.pas:7235`; **multipliers** `trdos/logdupe.pas:722`, `trdos/logedit.pas:3020`, `uMults.pas:271`; **adif-import** `MainUnit.pas:9980`; **ui** `uNewContest.pas:209`, `uNewContest.pas:334`; **setup** `trdos/LogCfg.pas:935`, `trdos/fcontest.pas:1496` |
| DARCWAEDCSSB | **scoring** `trdos/logstuff.pas:8874`; **multipliers** `trdos/logdupe.pas:716`, `trdos/logedit.pas:3018`, `uMults.pas:268`; **score-summary** `trdos/logedit.pas:2917`, `trdos/logedit.pas:2920`; **ui** `MainUnit.pas:4492`; **setup** `trdos/fcontest.pas:1577`; **other** `trdos/logddx.pas:311` |
| RDA | **scoring** `trdos/logstuff.pas:8422`; **exchange** `trdos/logdom.pas:224`, `trdos/logedit.pas:2616`, `trdos/logstuff.pas:10570`; **multipliers** `trdos/logedit.pas:1024`; **adif-export** `trdos/postunit.pas:2360`; **ui** `uNewContest.pas:223`, `uNewContest.pas:312`; **setup** `trdos/fcontest.pas:1256` |
| WAG | **scoring** `trdos/logstuff.pas:8846`; **exchange** `trdos/logdom.pas:247`, `trdos/logstuff.pas:10584`; **adif-import** `MainUnit.pas:9977`; **adif-export** `trdos/postunit.pas:2369`; **ui** `MainUnit.pas:4120`, `uNewContest.pas:218`, `uNewContest.pas:336`; **setup** `trdos/fcontest.pas:1559` |
| WWDIGI | **scoring** `trdos/logstuff.pas:8682`; **exchange** `trdos/logdupe.pas:1773`, `trdos/logstuff.pas:10346`; **adif-import** `MainUnit.pas:10094`, `MainUnit.pas:10103`; **adif-export** `trdos/postunit.pas:2432`; **cabrillo-export** `trdos/postunit.pas:3034`; **ui** `uNewContest.pas:301`; **setup** `trdos/fcontest.pas:714` |
| ARRL160 | **scoring** `trdos/logstuff.pas:6746`; **multipliers** `trdos/logdupe.pas:683`; **adif-import** `MainUnit.pas:9980`; **adif-export** `trdos/postunit.pas:2371`; **ui** `uNewContest.pas:180`, `uNewContest.pas:310`; **setup** `trdos/LogCfg.pas:896`, `trdos/fcontest.pas:658` |
| BATAVIA_FT8 | **scoring** `trdos/logstuff.pas:8591`, `trdos/logstuff.pas:8620`; **exchange** `trdos/logdupe.pas:1783`, `trdos/logstuff.pas:10343`; **adif-import** `MainUnit.pas:10105`; **adif-export** `trdos/postunit.pas:2432`; **ui** `uNewContest.pas:301`; **setup** `trdos/fcontest.pas:772` |
| CQ160CW | **scoring** `trdos/logstuff.pas:6950`; **adif-import** `MainUnit.pas:9980`; **adif-export** `trdos/postunit.pas:2415`; **ui** `uNewContest.pas:193`, `uNewContest.pas:310`; **setup** `trdos/LogCfg.pas:905`, `trdos/fcontest.pas:820`; **networking** `uExchangeBuilder.pas:162` |
| CUPRFDIG | **scoring** `trdos/logstuff.pas:9006`; **exchange** `trdos/logedit.pas:2647`, `trdos/logstuff.pas:10301`; **adif-export** `uADIFExchange.pas:389`; **cabrillo-export** `uCabrilloExchange.pas:361`; **score-summary** `trdos/logedit.pas:2962`; **ui** `uNewContest.pas:299`; **setup** `trdos/fcontest.pas:1614` |
| IOTA | **scoring** `trdos/logstuff.pas:8079`; **exchange** `trdos/logdom.pas:263`, `trdos/logstuff.pas:10599`; **adif-export** `trdos/postunit.pas:2427`; **cabrillo-export** `uCabrilloExchange.pas:400`; **ui** `uNewContest.pas:228`, `uNewContest.pas:341`; **setup** `trdos/LogCfg.pas:937` |
| R9W_UW9WK_MEMORIAL | **scoring** `trdos/logstuff.pas:9582`; **exchange** `trdos/logdupe.pas:1687`, `trdos/logstuff.pas:10290`; **adif-export** `uADIFExchange.pas:472`; **cabrillo-export** `uCabrilloExchange.pas:548`; **ui** `uNewContest.pas:297`; **setup** `trdos/LogCfg.pas:894`, `trdos/fcontest.pas:1630` |
| RFASCHAMPIONSHIPCW | **scoring** `trdos/logstuff.pas:9285`; **exchange** `trdos/logdupe.pas:1675`, `trdos/logstuff.pas:10286`; **adif-export** `uADIFExchange.pas:430`; **cabrillo-export** `uCabrilloExchange.pas:463`; **ui** `uNewContest.pas:300`; **setup** `trdos/LogCfg.pas:894`, `trdos/fcontest.pas:1706` |
| RUSSIANDX | **scoring** `trdos/logstuff.pas:8456`; **exchange** `trdos/logedit.pas:2616`, `trdos/zonecont.pas:92`; **multipliers** `trdos/logedit.pas:1015`; **score-summary** `uTotal.pas:332`; **ui** `uNewContest.pas:206`, `uNewContest.pas:312`; **setup** `trdos/fcontest.pas:1267` |
| YOTA | **scoring** `trdos/logstuff.pas:9813`; **exchange** `trdos/logdupe.pas:1753`, `trdos/logstuff.pas:10313`; **adif-export** `uADIFExchange.pas:357`; **cabrillo-export** `uCabrilloExchange.pas:314`; **ui** `uNewContest.pas:412`; **setup** `trdos/fcontest.pas:619`; **other** `trdos/logddx.pas:1061` |
| BWQP | **scoring** `trdos/logstuff.pas:6915`; **exchange** `MainUnit.pas:7080`, `trdos/logdupe.pas:1823`, `trdos/logstuff.pas:10241`, `trdos/logstuff.pas:10394`; **adif-export** `uADIFExchange.pas:272`; **cabrillo-export** `uCabrilloExchange.pas:209` |
| CQ160SSB | **scoring** `trdos/logstuff.pas:6950`; **adif-import** `MainUnit.pas:9980`; **adif-export** `trdos/postunit.pas:2415`; **ui** `uNewContest.pas:193`, `uNewContest.pas:310`; **setup** `trdos/LogCfg.pas:905`, `trdos/fcontest.pas:820` |
| CUPURAL | **multipliers** `trdos/logedit.pas:1021`; **cabrillo-export** `uCabrilloExchange.pas:368`; **score-summary** `trdos/logedit.pas:2951`, `trdos/logedit.pas:3008`, `trdos/postunit.pas:1446`; **ui** `uNewContest.pas:422`; **setup** `trdos/LogCfg.pas:894` |
| NZFIELDDAY | **scoring** `trdos/logstuff.pas:8221`; **exchange** `trdos/logdupe.pas:1668`, `trdos/logstuff.pas:10410`; **multipliers** `trdos/logdupe.pas:1307`, `trdos/logdupe.pas:2259`; **ui** `uNewContest.pas:277`; **setup** `trdos/LogCfg.pas:929` |
| RADIOMEMORY | **scoring** `trdos/logstuff.pas:9399`; **exchange** `trdos/logdupe.pas:1746`, `trdos/logstuff.pas:10326`; **adif-export** `uADIFExchange.pas:353`; **cabrillo-export** `uCabrilloExchange.pas:307`; **ui** `uNewContest.pas:290`; **setup** `trdos/LogCfg.pas:888` |
| RSGB_ROPOCO_CW | **scoring** `trdos/logstuff.pas:8942`; **exchange** `trdos/logdupe.pas:1794`, `trdos/logstuff.pas:10353`; **adif-export** `uADIFExchange.pas:283`; **cabrillo-export** `uCabrilloExchange.pas:221`; **ui** `uNewContest.pas:287`; **setup** `trdos/fcontest.pas:1240` |
| RSGB_ROPOCO_SSB | **scoring** `trdos/logstuff.pas:8942`; **exchange** `trdos/logdupe.pas:1794`, `trdos/logstuff.pas:10353`; **adif-export** `uADIFExchange.pas:283`; **cabrillo-export** `uCabrilloExchange.pas:221`; **ui** `uNewContest.pas:287`; **setup** `trdos/fcontest.pas:1240` |
| ARI_DX | **scoring** `trdos/logstuff.pas:6666`; **multipliers** `trdos/logdupe.pas:696`; **ui** `uNewContest.pas:209`, `uNewContest.pas:322`; **setup** `trdos/fcontest.pas:638`; **other** `trdos/logddx.pas:296` |
| ARRL10 | **scoring** `trdos/logstuff.pas:6760`; **multipliers** `trdos/logdupe.pas:683`; **cabrillo-export** `trdos/postunit.pas:2669`; **ui** `uNewContest.pas:180`, `uNewContest.pas:310`; **setup** `trdos/fcontest.pas:646` |
| DARC10M | **exchange** `trdos/logdom.pas:247`, `trdos/logstuff.pas:10584`; **cabrillo-export** `uCabrilloExchange.pas:408`; **ui** `uNewContest.pas:218`, `uNewContest.pas:336`; **setup** `trdos/fcontest.pas:1530` |
| FISTS | **scoring** `trdos/logstuff.pas:7774`; **exchange** `trdos/logdupe.pas:1866`, `trdos/logdupe.pas:1961`, `trdos/logdupe.pas:2097`, `trdos/logstuff.pas:10444`; **score-summary** `trdos/logedit.pas:2853` |
| GAGARINCUP | **scoring** `trdos/logstuff.pas:9485`; **multipliers** `trdos/logedit.pas:3059`, `trdos/logedit.pas:3061`; **ui** `uNewContest.pas:214`, `uNewContest.pas:332`; **setup** `trdos/fcontest.pas:965` |
| LZDX | **scoring** `trdos/logstuff.pas:9232`; **adif-import** `MainUnit.pas:10067`; **ui** `uNewContest.pas:220`, `uNewContest.pas:327`; **setup** `trdos/LogCfg.pas:905`, `trdos/fcontest.pas:1664` |
| MAKROTHEN | **scoring** `trdos/logstuff.pas:7537`; **exchange** `trdos/logdupe.pas:1783`, `trdos/logstuff.pas:10343`; **adif-import** `MainUnit.pas:10105`; **ui** `uNewContest.pas:301`; **setup** `trdos/LogCfg.pas:883` |
| NAQSOCW | **adif-import** `MainUnit.pas:10060`; **adif-export** `trdos/postunit.pas:2415`; **cabrillo-export** `trdos/postunit.pas:2890`; **ui** `uNewContest.pas:349`; **setup** `trdos/fcontest.pas:1075`; **networking** `uExchangeBuilder.pas:193` |
| NAQSORTTY | **adif-import** `MainUnit.pas:10060`; **adif-export** `trdos/postunit.pas:2415`; **cabrillo-export** `trdos/postunit.pas:2891`; **ui** `uNewContest.pas:349`; **setup** `trdos/fcontest.pas:1075`; **networking** `uExchangeBuilder.pas:193` |
| NAQSOSSB | **adif-import** `MainUnit.pas:10060`; **adif-export** `trdos/postunit.pas:2415`; **cabrillo-export** `trdos/postunit.pas:2890`; **ui** `uNewContest.pas:349`; **setup** `trdos/fcontest.pas:1075`; **networking** `uExchangeBuilder.pas:193` |
| PACC | **multipliers** `trdos/logdupe.pas:748`; **adif-export** `uADIFExchange.pas:460`; **cabrillo-export** `uCabrilloExchange.pas:513`; **ui** `uNewContest.pas:209`, `uNewContest.pas:335`; **setup** `trdos/fcontest.pas:1178` |
| RADIOYOC | **scoring** `trdos/logstuff.pas:8941`; **exchange** `MainUnit.pas:7997`, `trdos/logdupe.pas:1681`, `trdos/logstuff.pas:10417`; **adif-export** `uADIFExchange.pas:480`; **cabrillo-export** `uCabrilloExchange.pas:564` |
| SACCW | **scoring** `trdos/logstuff.pas:8512`; **exchange** `MainUnit.pas:7239`, `trdos/logstuff.pas:4415`; **multipliers** `trdos/logedit.pas:3024`; **setup** `trdos/fcontest.pas:1298`; **other** `trdos/logddx.pas:250` |
| SACSSB | **scoring** `trdos/logstuff.pas:8512`; **exchange** `MainUnit.pas:7239`, `trdos/logstuff.pas:4415`; **multipliers** `trdos/logedit.pas:3024`; **setup** `trdos/fcontest.pas:1298`; **other** `trdos/logddx.pas:250` |
| SPDX | **scoring** `trdos/logstuff.pas:8941`; **adif-export** `uADIFExchange.pas:460`; **cabrillo-export** `uCabrilloExchange.pas:513`; **ui** `uNewContest.pas:220`, `uNewContest.pas:339`; **setup** `trdos/fcontest.pas:1317` |
| UA4WCHAMPIONSHIP | **scoring** `trdos/logstuff.pas:9050`; **exchange** `trdos/logstuff.pas:10199`, `trdos/logstuff.pas:10249`; **ui** `uNewContest.pas:409`; **setup** `trdos/LogCfg.pas:898`, `trdos/fcontest.pas:1625` |
| UKEI | **scoring** `trdos/logstuff.pas:7869`; **exchange** `trdos/logstuff.pas:4842`; **cabrillo-export** `uCabrilloExchange.pas:394`; **ui** `uNewContest.pas:216`, `uNewContest.pas:331`; **setup** `trdos/fcontest.pas:932` |
| UKRAINECHAMPIONSHIP | **scoring** `trdos/logstuff.pas:9123`; **cabrillo-export** `uCabrilloExchange.pas:368`; **score-summary** `trdos/logedit.pas:2981`, `trdos/postunit.pas:1446`; **ui** `uNewContest.pas:415`; **setup** `trdos/LogCfg.pas:894` |
| WRTC | **scoring** `trdos/logstuff.pas:9593`; **ui** `MainUnit.pas:4476`, `MainUnit.pas:6460`, `trdos/logedit.pas:1708`; **setup** `trdos/fcontest.pas:1694`; **networking** `trdos/logsubs2.pas:2762` |
| CANADA_DAY | **scoring** `trdos/logstuff.pas:8358`; **exchange** `trdos/logstuff.pas:5308`; **ui** `uNewContest.pas:199`, `uNewContest.pas:314`; **setup** `trdos/fcontest.pas:1228` |
| CANADA_WINTER | **scoring** `trdos/logstuff.pas:8358`; **exchange** `trdos/logstuff.pas:5308`; **ui** `uNewContest.pas:199`, `uNewContest.pas:314`; **setup** `trdos/fcontest.pas:1228` |
| CQVHF | **scoring** `trdos/logstuff.pas:7024`; **adif-export** `uADIFExchange.pas:449`; **cabrillo-export** `uCabrilloExchange.pas:502`; **ui** `uNewContest.pas:301`; **setup** `trdos/fcontest.pas:834` |
| HELVETIA | **scoring** `trdos/logstuff.pas:7943`; **ui** `uNewContest.pas:209`, `uNewContest.pas:321`; **setup** `trdos/LogCfg.pas:937`, `trdos/fcontest.pas:950` |
| LABRE | **scoring** `trdos/logstuff.pas:9194`; **exchange** `trdos/logstuff.pas:10371`; **cabrillo-export** `trdos/postunit.pas:3039`; **ui** `uNewContest.pas:260`; **setup** `trdos/fcontest.pas:474` |
| LQP | **scoring** `trdos/logstuff.pas:9361`, `trdos/logstuff.pas:9364`; **ui** `uNewContest.pas:360`; **setup** `trdos/LogCfg.pas:890`, `trdos/fcontest.pas:1740` |
| NRAUBALTICCW | **exchange** `trdos/logedit.pas:2652`, `trdos/logstuff.pas:10413`; **ui** `uNewContest.pas:293`; **setup** `trdos/LogCfg.pas:935`, `trdos/fcontest.pas:1138` |
| NRAUBALTICSSB | **exchange** `trdos/logedit.pas:2652`, `trdos/logstuff.pas:10413`; **ui** `uNewContest.pas:293`; **setup** `trdos/LogCfg.pas:935`, `trdos/fcontest.pas:1138` |
| OKDX | **scoring** `trdos/logstuff.pas:8246`; **adif-import** `MainUnit.pas:10067`; **ui** `uNewContest.pas:220`, `uNewContest.pas:325`; **setup** `trdos/fcontest.pas:1163` |
| OZCR_O | **exchange** `trdos/logedit.pas:2386`; **score-summary** `uTotal.pas:263`; **ui** `uNewContest.pas:294`; **setup** `trdos/LogCfg.pas:905`, `trdos/fcontest.pas:1734` |
| OZHCRVHF | **scoring** `trdos/logstuff.pas:7663`; **score-summary** `trdos/logedit.pas:2987`; **ui** `uNewContest.pas:303`; **setup** `trdos/LogCfg.pas:933`, `trdos/fcontest.pas:1790` |
| RTC | **scoring** `trdos/logstuff.pas:8689`; **ui** `uNewContest.pas:301`; **setup** `trdos/fcontest.pas:722`; **networking** `uExchangeBuilder.pas:112`, `uExchangeBuilder.pas:205` |
| TENTEN | **scoring** `trdos/logstuff.pas:8726`; **exchange** `trdos/logdupe.pas:1649`, `trdos/logstuff.pas:10267`; **setup** `trdos/fcontest.pas:1473`; **other** `trdos/logddx.pas:858` |
| UKRAINIAN | **scoring** `trdos/logstuff.pas:8800`; **adif-import** `MainUnit.pas:10067`; **ui** `uNewContest.pas:206`, `uNewContest.pas:324`; **setup** `trdos/fcontest.pas:1513` |
| YBDX | **scoring** `trdos/logstuff.pas:8552`; **exchange** `MainUnit.pas:7240`, `MainUnit.pas:7243`; **multipliers** `trdos/logedit.pas:3025`; **setup** `trdos/fcontest.pas:1310` |
| YODX | **scoring** `trdos/logstuff.pas:8916`; **multipliers** `trdos/logedit.pas:1030`; **ui** `uNewContest.pas:220`, `uNewContest.pas:328`; **setup** `trdos/fcontest.pas:1608` |
| ARCI | **scoring** `trdos/logstuff.pas:6650`; **exchange** `trdos/logdupe.pas:1766`, `trdos/logstuff.pas:10397`; **setup** `trdos/fcontest.pas:632` |
| ARRL_RTTY_ROUNDUP | **adif-import** `MainUnit.pas:9983`; **ui** `uNewContest.pas:180`, `uNewContest.pas:310`; **setup** `trdos/fcontest.pas:693` |
| BSCI | **scoring** `trdos/logstuff.pas:7957`; **multipliers** `trdos/logdupe.pas:740`; **ui** `uNewContest.pas:225`, `uNewContest.pas:340` |
| CIS | **scoring** `trdos/logstuff.pas:6926`; **ui** `uNewContest.pas:206`, `uNewContest.pas:338`; **setup** `trdos/fcontest.pas:797` |
| EUDX | **scoring** `trdos/logstuff.pas:9755`; **ui** `uNewContest.pas:220`, `uNewContest.pas:317`; **setup** `trdos/fcontest.pas:916` |
| HADX | **scoring** `trdos/logstuff.pas:7784`; **ui** `uNewContest.pas:212`, `uNewContest.pas:329`; **setup** `trdos/fcontest.pas:900` |
| IRTS | **scoring** `trdos/logstuff.pas:9755`; **ui** `uNewContest.pas:196`, `uNewContest.pas:316`; **setup** `trdos/fcontest.pas:905` |
| JTDX | **scoring** `trdos/logstuff.pas:9153`; **multipliers** `trdos/logdupe.pas:705`, `trdos/logedit.pas:3049`; **setup** `trdos/fcontest.pas:1755` |
| KINGOFSPAINCW | **scoring** `trdos/logstuff.pas:9466`; **ui** `uNewContest.pas:209`, `uNewContest.pas:319`; **setup** `trdos/fcontest.pas:1772` |
| KINGOFSPAINSSB | **scoring** `trdos/logstuff.pas:9466`; **ui** `uNewContest.pas:209`, `uNewContest.pas:319`; **setup** `trdos/fcontest.pas:1772` |
| NCCCSPRINT | **adif-import** `MainUnit.pas:10060`; **ui** `uNewContest.pas:360`; **setup** `trdos/LogCfg.pas:890`, `trdos/fcontest.pas:1740` |
| OKOMSSB | **scoring** `trdos/logstuff.pas:8292`; **ui** `uNewContest.pas:220`, `uNewContest.pas:325`; **setup** `trdos/fcontest.pas:1156` |
| OLDNEWYEAR | **scoring** `trdos/logstuff.pas:9265`; **ui** `uNewContest.pas:286`; **setup** `trdos/LogCfg.pas:896`, `trdos/fcontest.pas:1688` |
| OZCR_Z | **scoring** `trdos/logstuff.pas:7999`; **exchange** `trdos/logedit.pas:2386`; **setup** `trdos/LogCfg.pas:905`, `trdos/fcontest.pas:960` |
| RADIOVHFFD | **scoring** `trdos/logstuff.pas:7505`; **ui** `uNewContest.pas:303`; **setup** `trdos/LogCfg.pas:933`, `trdos/fcontest.pas:870` |
| REFCW | **scoring** `trdos/logstuff.pas:9382`; **exchange** `trdos/logstuff.pas:10363`; **ui** `uNewContest.pas:203`, `uNewContest.pas:315` |
| REFSSB | **scoring** `trdos/logstuff.pas:9382`; **exchange** `trdos/logstuff.pas:10363`; **ui** `uNewContest.pas:203`, `uNewContest.pas:315` |
| RSGB18 | **scoring** `trdos/logstuff.pas:8390`; **score-summary** `trdos/logedit.pas:2957`; **ui** `uNewContest.pas:220`, `uNewContest.pas:337` |
| UNDX | **scoring** `trdos/logstuff.pas:9444`; **ui** `uNewContest.pas:206`, `uNewContest.pas:323`; **setup** `trdos/fcontest.pas:1766` |
| YUDX | **scoring** `trdos/logstuff.pas:7851`; **ui** `uNewContest.pas:212`, `uNewContest.pas:330`; **setup** `trdos/fcontest.pas:922` |
| ARRLVHFJUN | **scoring** `trdos/logstuff.pas:6777`; **ui** `uNewContest.pas:301`; **setup** `trdos/fcontest.pas:748` |
| ARRLVHFSEP | **scoring** `trdos/logstuff.pas:6777`; **ui** `uNewContest.pas:301`; **setup** `trdos/fcontest.pas:748` |
| CWOPEN | **ui** `uNewContest.pas:355`; **setup** `trdos/LogCfg.pas:945`; **networking** `uExchangeBuilder.pas:197` |
| CWOPS | **adif-import** `MainUnit.pas:10022`; **ui** `uNewContest.pas:360`; **networking** `uExchangeBuilder.pas:183` |
| EUROPEANVHF | **scoring** `trdos/logstuff.pas:7685`; **ui** `uNewContest.pas:303`; **setup** `trdos/fcontest.pas:881` |
| EUSPRINT_AUTUMN_CW | **ui** `uNewContest.pas:275`; **setup** `trdos/LogCfg.pas:939`, `trdos/fcontest.pas:863` |
| EUSPRINT_AUTUMN_SSB | **ui** `uNewContest.pas:275`; **setup** `trdos/LogCfg.pas:939`, `trdos/fcontest.pas:863` |
| EUSPRINT_SPRING_CW | **ui** `uNewContest.pas:275`; **setup** `trdos/LogCfg.pas:939`, `trdos/fcontest.pas:863` |
| EUSPRINT_SPRING_SSB | **ui** `uNewContest.pas:275`; **setup** `trdos/LogCfg.pas:939`, `trdos/fcontest.pas:863` |
| KCJ | **scoring** `trdos/logstuff.pas:8187`; **ui** `uNewContest.pas:372`; **setup** `trdos/fcontest.pas:1008` |
| MWC | **scoring** `trdos/logstuff.pas:7927`; **ui** `uNewContest.pas:169`; **setup** `trdos/fcontest.pas:1059` |
| NEWENGLANDQSO | **ui** `uNewContest.pas:177`, `uNewContest.pas:308`; **setup** `trdos/fcontest.pas:1110` |
| SPRINTSSB | **adif-export** `trdos/postunit.pas:2415`; **ui** `uNewContest.pas:400`; **setup** `trdos/fcontest.pas:1363` |
| SST | **ui** `uNewContest.pas:349`; **setup** `trdos/fcontest.pas:1066`; **networking** `uExchangeBuilder.pas:193` |
| STEWPERRY | **scoring** `trdos/logstuff.pas:8661`; **ui** `uNewContest.pas:301`; **setup** `trdos/fcontest.pas:599` |
| WWPMC | **scoring** `trdos/logstuff.pas:9133`; **ui** `uNewContest.pas:231`, `uNewContest.pas:346` |
| ARRLVHFJAN | **scoring** `trdos/logstuff.pas:6777`; **ui** `uNewContest.pas:301` |
| BALTIC | **scoring** `trdos/logstuff.pas:6885`; **setup** `trdos/fcontest.pas:764` |
| CQM | **scoring** `trdos/logstuff.pas:6969`; **setup** `trdos/fcontest.pas:828` |
| CQWPXRTTY | **scoring** `trdos/logstuff.pas:7144`; **setup** `trdos/fcontest.pas:1694` |
| CROATIAN | **scoring** `trdos/logstuff.pas:7254`; **setup** `trdos/fcontest.pas:559` |
| SEVENQP | **setup** `trdos/LogCfg.pas:896`, `trdos/fcontest.pas:1712` |
| TESLA | **scoring** `trdos/logstuff.pas:7726`; **ui** `uNewContest.pas:305` |
| WWL | **scoring** `trdos/logstuff.pas:8893`; **exchange** `trdos/logstuff.pas:10336` |
| GACWWWSACW | **scoring** `trdos/logstuff.pas:9340` |
| IN7QPNE | **scoring** `trdos/logstuff.pas:7626` |
| OCEANIADXCW | **scoring** `trdos/logstuff.pas:8829` |
| OCEANIADXSSB | **scoring** `trdos/logstuff.pas:8829` |
| REGION1FIELDDAY | **scoring** `trdos/logstuff.pas:7336` |
| REGION1FIELDDAY_RCC_CW | **scoring** `trdos/logstuff.pas:9301` |
| REGION1FIELDDAY_RCC_SSB | **scoring** `trdos/logstuff.pas:9301` |
| TOEC | **scoring** `trdos/logstuff.pas:8736` |
| UCG | **scoring** `trdos/logstuff.pas:7108` |
| WWIH | **scoring** `trdos/logstuff.pas:7240` |

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

### D1. `logstuff.ValidClass` after the class returns -- dead by default, 4 lint hits

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

### D2. `ValidateDXQTH`'s fallback -- dead by default, same reason

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
ActiveExchange of` arm in `SetHisEx` / `FormatADIFMyExchange` reached only by
classes whose `FormatsExchange` is True (14 classes).

| arm | routine | value | reached by |
|---|---|---|---|
| `trdos/logstuff.pas:6685` | CalculateQSOPoints | `ARRLDXQSOPointMethod` | ARRLDXCW, ARRLDXSSB |
| `trdos/logstuff.pas:6709` | CalculateQSOPoints | `ARRLFieldDayQSOPointMethod` | ARRLFIELDDAY, IDAHOQSOPARTY, WINTERFIELDDAY |
| `trdos/logstuff.pas:6732` | CalculateQSOPoints | `ARRLDIGIQSOPointMethod` | ARRLDIGI |
| `trdos/logstuff.pas:7221` | CalculateQSOPoints | `CQWWQSOPointMethod` | CQWWCW, CQWWSSB |
| `trdos/logstuff.pas:7563` | CalculateQSOPoints | `NCQSOPointMethod` | NCQSOPARTY |
| `trdos/logstuff.pas:7612` | CalculateQSOPoints | `BCQPQSOPointMethod` | BCQP |
| `trdos/logstuff.pas:8500` | CalculateQSOPoints | `SalmonRunQSOPointMethod` | SALMONRUN |
| `trdos/logstuff.pas:8938` | CalculateQSOPoints | `AlwaysOnePointPerQSO` | INTERNETSPRINT, YOUTHCHAMPIONSHIPRF |
| `trdos/logstuff.pas:9370` | CalculateQSOPoints | `ArktikaSpringQSOPointMethod` | ARKTIKA_SPRING |
| `trdos/logstuff.pas:9739` | CalculateQSOPoints | `VAQSOPOINTMETHOD` | VAQP |
| `uADIFExchange.pas:326` | FormatADIFMyExchange | `QSONumberPrecedenceCheckDomesticQTHExchange` | ARRLSSCW, ARRLSSSSB |
| `uADIFExchange.pas:436` | FormatADIFMyExchange | `ClassDomesticOrDXQTHExchange` | ARRLFIELDDAY, WINTERFIELDDAY |
| `uCabrilloExchange.pas:274` | SetHisEx | `QSONumberPrecedenceCheckDomesticQTHExchange` | ARRLSSCW, ARRLSSSSB |
| `uCabrilloExchange.pas:469` | SetHisEx | `ClassDomesticOrDXQTHExchange` | ARRLFIELDDAY, WINTERFIELDDAY |

### 9.2 Class traits the engine contradicts (D8)

**160** trait overrides checked (`GetQSOPointMethod`, `GetExchangeKind`,
`GetDomesticMultiplierType`, `GetDXMultiplierType`), each against the value the
ENGINE uses -- the last `FoundContest` arm assignment for the contest, else its
`ContestsArray` row. **7** disagree or could not be read:

| contest | getter | class says | engine uses | row | FoundContest arms |
|---|---|---|---|---|---|
| ARRLFIELDDAY | GETDXMULTIPLIERTYPE | `ARRLDXCC` | `NoDXMults` | `ARRLDXCC` | `NoDXMults` |
| ArizonaQsoParty | GETEXCHANGEKIND | `RSTDomesticOrDXQTHExchange` | `RSTDomesticQTHExchange` | `RSTDomesticOrDXQTHExchange` | `RSTDomesticQTHExchange` |
| CALQSOPARTY | GETEXCHANGEKIND | `QSONumberDomesticOrDXQTHExchange` | `QSONumberDomesticQTHExchange` | `QSONumberDomesticOrDXQTHExchange` | `QSONumberDomesticOrDXQTHExchange`, `QSONumberDomesticQTHExchange` |
| SALMONRUN | GETEXCHANGEKIND | `RSTDomesticOrDXQTHExchange` | `RSTDomesticQTHExchange` | `RSTDomesticOrDXQTHExchange` | `RSTDomesticOrDXQTHExchange`, `RSTDomesticQTHExchange` |
| SALMONRUN | GETDXMULTIPLIERTYPE | `NoDXMults` | `ARRLDXCCWithNoUSAOrCanada` | `NoDXMults` | `ARRLDXCCWithNoUSAOrCanada` |
| TEXASQSOPARTY | GETEXCHANGEKIND | `RSTDomesticOrDXQTHExchange` | `RSTDomesticQTHExchange` | `RSTDomesticOrDXQTHExchange` | `RSTDomesticQTHExchange` |
| TEXASQSOPARTY | GETDXMULTIPLIERTYPE | `NoDXMults` | `ARRLDXCCWithNoUSACanadaKH6OrKL7` | `NoDXMults` | `ARRLDXCCWithNoUSACanadaKH6OrKL7` |

### 9.3 Contest identity: what the class says, what the exporters emit (D9)

- **139** contests have a blank `ContestsArray` `ADIFName` (excluding
  GENERALQSO, POTA, which write no `CONTEST_ID`), so their exported id is the
  `ContestTypeSA` spelling and import cannot resolve it; **29** of them are
  registered: ALLJA, ARRLDIGI, ARRLDXCW, ARRLDXSSB, ARRLSSCW, ARRLSSSSB, COUNTYHUNTER, CQWPXCW, CQWPXSSB, CQWWCW, CQWWSSB, GRIDLOC, IARU, INTERNETSPRINT, JALONGPREFECT, KIDSDAY, KVP, MARCONIMEMORIAL, MINITEST, NASPRINTCW, NASPRINTRTTY, QCWA, QCWAGOLDEN, DARCXMAS, XMAS, YOUTHCHAMPIONSHIPRF, ARKTIKA_SPRING, SASPRINT, CQIR.
- 82 literal identity getters (`GetCabrilloName`, `GetADIFContestId`) were
  compared with what the exporters emit; **18** differ:

| contest | format | class says | exporter emits |
|---|---|---|---|
| ALLJA | ADIF | `` | `ALL JA` |
| ARKTIKA_SPRING | ADIF | `` | `ARKTIKA-SPRING` |
| ARRLDIGI | ADIF | `` | `ARRL-DIGI` |
| COUNTYHUNTER | ADIF | `` | `COUNTY HUNTER` |
| CQIR | ADIF | `` | `CQIR` |
| DARCXMAS | ADIF | `` | `DARC-XMAS` |
| GRIDLOC | ADIF | `` | `GRID LOC` |
| INTERNETSPRINT | ADIF | `` | `INTERNET SPRINT` |
| JALONGPREFECT | ADIF | `` | `JA LONG PREFECT` |
| KIDSDAY | ADIF | `` | `KIDS DAY` |
| KVP | ADIF | `` | `KVP` |
| MARCONIMEMORIAL | ADIF | `` | `MARCONI MEMORIAL` |
| MINITEST | ADIF | `` | `MINITEST` |
| QCWA | ADIF | `` | `QCWA` |
| QCWAGOLDEN | ADIF | `` | `QCWA GOLDEN` |
| SASPRINT | ADIF | `` | `SA-SPRINT` |
| XMAS | ADIF | `` | `XMAS` |
| YOUTHCHAMPIONSHIPRF | ADIF | `` | `SRR-JR` |

### 9.4 Shape 1 against shapes 1 + 2, per file (section 8.2)

Shape 1 (the global `Contest` only): **91** in 12 files. Shapes 1 + 2 (testing
the VALUE rather than the operand): **105** in 15 files. A `case` counts
once here; `Lint-ContestNameTests` counts its contest-naming arms instead (section 9.5).

| file | shape 1 | shapes 1 + 2 |
|---|---:|---:|
| `MainUnit.pas` | 12 | **14** |
| `trdos/LogCfg.pas` | 1 | 1 |
| `trdos/fcontest.pas` | 4 | 4 |
| `trdos/logdupe.pas` | 5 | 5 |
| `trdos/logedit.pas` | 14 | 14 |
| `trdos/logstuff.pas` | 14 | 14 |
| `trdos/logsubs2.pas` | 4 | 4 |
| `trdos/logwind.pas` | 1 | 1 |
| `trdos/postunit.pas` | 15 | **18** |
| `uADIF.pas` | -- | **4** |
| `uADIFExchange.pas` | 5 | 5 |
| `uCabrilloExchange.pas` | 11 | 11 |
| `uExchangeBuilder.pas` | -- | **2** |
| `uNewContest.pas` | -- | **3** |
| `uTotal.pas` | 5 | 5 |

### 9.5 Contest-naming `case` arms (section 8.3)

**246** arms across 9 cases.

| case | routine | shape | contest-naming arms |
|---|---|---|---:|
| `trdos/fcontest.pas:472` | FoundContest | 1 | 104 |
| `uNewContest.pas:259` | ApplyContestChoice | 2 | 68 |
| `uNewContest.pas:168` | ApplyIAmIn | 2 | 23 |
| `trdos/LogCfg.pas:881` | tSetupExchangeNumbers | 1 | 14 |
| `MainUnit.pas:9965` | ApplyContestSpecificADIFTail | 2 | 13 |
| `uExchangeBuilder.pas:152` | BuildRxExchangeText | 2 | 10 |
| `trdos/postunit.pas:2368` | EmitContestSpecificTailForExport | 2 | 9 |
| `trdos/logedit.pas:1014` | EditableLog.GetMultArray | 1 | 4 |
| `MainUnit.pas:11420` | ProcessImportedSRX_String | 2 | 1 |
