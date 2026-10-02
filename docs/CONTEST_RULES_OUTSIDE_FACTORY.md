# Contest rules outside the contest factory -- an inventory

**GENERATED. Do not edit outside the marked hand-maintained blocks.**
Regenerate with `python tools/contest-rules-inventory/generate.py` (any working
directory). This copy was generated from commit `674992df` (2026-10-02).
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
| 1 | the global `Contest` compared, `in`-tested or cased | **23** in 8 files | 22 | `scan.py` (section 2.1). Rows > sites because a `case` is one site and one row per arm |
| 2 | a contest-typed FIELD or VARIABLE tested: `exch.ceContest`, `rec.ceContest`, `RXData.ceContest`, `SelectedContest` | **7** in 4 files | 10 | `scan.py` |
| 3 | a contest identified by a STRING: contest name/title, a station state, a sponsor or bonus callsign | **22** | 22 | `judgements.SHAPE3`, curated from `scan.string_candidates` (section 2.4) |
| 4 | an `Active*` proxy whose tested value reaches only 1-3 contests by default | **188** of 362 classified | 188 | `scan.classify_proxies` |
| 5 | `FoundContest`'s setup `case Contest of` | 1 case, **2 arms**, 2 contests | 2 | `scan.found_contest_arms` -- its own table, section 5 |

Shape 4 in full: the 127 `Active*` sites (117 comparisons, 10 `case`s) break
into 362 comparison-or-arm records --

| class | records | meaning |
|---|---:|---|
| PROXY, reach 1 | 109 | the tested value reaches exactly ONE contest by default -- a contest rule wearing a disguise |
| PROXY, reach 2-3 | 79 | mostly a CW/SSB pair or a family (ARRL SS, the Field Days, UBA, SAC, REF); **13** of them test a value whose NAME is generic (`ThreePointsPerQSO`, `GridExchange`, `RSTAgeExchange`, ...) and are flagged `GENERIC-NAMED` in the tables -- judge those individually. 3 reach-1 rows carry the same flag |
| PROXY for DUMMYCONTEST | 1 | `NoQSOPointMethod`, the sentinel; dropped |
| SHARED | 103 | reaches 4+ contests -- genuinely shared behaviour, **not a finding**, counted only |
| UNUSED | 70 | reaches NO contest by default -- only an operator's `.cfg` setting can select it (section 1.4) |

### 1.2 By category (table rows; section 4 has every row)

| category | s1 | s2 | s3 | s4 | total |
|---|---:|---:|---:|---:|---:|
| Scoring | 1 | 0 | 9 | 96 | 106 |
| Exchange parsing and validation | 6 | 0 | 1 | 47 | 54 |
| Dupe | 0 | 0 | 0 | 0 | 0 |
| Multipliers | 0 | 0 | 1 | 15 | 16 |
| ADIF import | 0 | 1 | 1 | 0 | 2 |
| ADIF export | 0 | 4 | 1 | 1 | 6 |
| Cabrillo export | 1 | 0 | 6 | 0 | 7 |
| Score, summary and totals | 2 | 0 | 1 | 0 | 3 |
| UI, display and the new-contest dialog | 11 | 5 | 1 | 2 | 19 |
| Setup (FoundContest / LogCfg) | 1 | 0 | 0 | 1 | 2 (+ 2 FoundContest arms, section 5) |
| Networking and score reporting | 0 | 0 | 0 | 0 | 0 |
| Other | 0 | 0 | 1 | 26 | 27 |
| **total** | **22** | **10** | **22** | **188** | **242** (+2) |

### 1.3 Top files (table rows, plus FoundContest's arms)

| file | rows |
|---|---:|
| `trdos/logstuff.pas` | 113 |
| `trdos/logdupe.pas` | 37 |
| `trdos/logddx.pas` | 27 |
| `trdos/logedit.pas` | 20 |
| `MainUnit.pas` | 16 |
| `trdos/postunit.pas` | 9 |
| `uNewContest.pas` | 5 |
| `uCabrilloExchange.pas` | 4 |
| `trdos/fcontest.pas` | 3 (2 setup arms + 1) |
| `trdos/logsubs2.pas` | 2 |

### 1.4 The headline facts

1. **144 of the 181 registered contests still have rules outside the factory.**
   With none: `APSPRINT`, `ARRL_RTTY_ROUNDUP`, `ArizonaQsoParty`, `COLORADOQSOPARTY`, `CWOPEN`, `CWOPS`, `DARC10M`, `DARCXMAS`, `EUSPRINT_AUTUMN_CW`, `EUSPRINT_AUTUMN_SSB`, `EUSPRINT_SPRING_CW`, `EUSPRINT_SPRING_SSB`, `FLORIDAQSOPARTY`, `INQSOPARTY`, `MARCONIMEMORIAL`, `MICHQSOPARTY`, `MINI40`, `MINI80`, `MINITEST`, `MINNQSOPARTY`, `MOQSOPARTY`, `MST`, `NAQSOCW`, `NAQSORTTY`, `NAQSOSSB`, `NASPRINTCW`, `NASPRINTRTTY`, `NCCCSPRINT`, `NEWENGLANDQSO`, `NYQP`, `PACC`, `SEVENQP`, `SPRINTSSB`, `SST`, `TENNESSEEQSOPARTY`, `TEXASQSOPARTY`, `WISCONSINQSOPARTY`. The per-contest index (section 6)
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
**449 files**. Using the tracked list excludes the gitignored `backup/`,
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
- Shape 1 is 2 `case` + 17 comparisons + 4 `in` tests = **23**.
  At `9acdc5bd` that was exactly the set `Lint-ContestNameTests.ps1 -List`
  printed. The lint has since been widened (`c3841b55`) to count by VALUE
  and one per `case` arm -- sections 9.4 and 9.5 are the comparable figures.
  The lint and this scanner are separate implementations, so a
  disagreement between them is worth a look.

### 2.2 Which contests have a class

`RegisterContest(<enum>, <class>)` in `src/contestFactory/`: **181**
(`model.Registry`, which also walks each class's ancestry). All 181 score through their own chain -- none falls through to `TContestBase`'s zero.

### 2.3 Shape 4 -- who reaches an `Active*` value

The reach of a value is each contest's `ContestsArray` row
(186 enum values against 186 rows, matched by position)
UNION every `Active* :=` inside `FoundContest`'s arms (0 assignments).
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
CABName, DF and FriendlyName): **41** hits today, and lists **24** lines
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
| `trdos/logstuff.pas:6404` | CalculateQSOPoints | 4 | **ALLASIANCW**, **ALLASIANSSB** | all | CalculateQSOPoints (existing) | reach 2: `QP` = AllAsianQSOPointMethod (arm of case @6375) |
| `trdos/logstuff.pas:6454` | CalculateQSOPoints | 4 | **ARCI** | all | CalculateQSOPoints (existing) | reach 1: `QP` = ARCIQSOPointMethod (arm of case @6375) |
| `trdos/logstuff.pas:6470` | CalculateQSOPoints | 4 | **ARI_DX** | all | CalculateQSOPoints (existing) | reach 1: `QP` = ARIQSOPointMethod (arm of case @6375) |
| `trdos/logstuff.pas:6489` | CalculateQSOPoints | 4 | **ARRLDXCW**, **ARRLDXSSB** | all | CalculateQSOPoints (existing) | reach 2: `QP` = ARRLDXQSOPointMethod (arm of case @6375) |
| `trdos/logstuff.pas:6513` | CalculateQSOPoints | 4 | **ARRLFIELDDAY**, **IDAHOQSOPARTY**, **WINTERFIELDDAY** | all | CalculateQSOPoints (existing) | reach 3: `QP` = ARRLFieldDayQSOPointMethod (arm of case @6375) |
| `trdos/logstuff.pas:6536` | CalculateQSOPoints | 4 | **ARRLDIGI** | all | CalculateQSOPoints (existing) | reach 1: `QP` = ARRLDIGIQSOPointMethod (arm of case @6375) |
| `trdos/logstuff.pas:6550` | CalculateQSOPoints | 4 | **ARRL160** | all | CalculateQSOPoints (existing) | reach 1: `QP` = ARRL160QSOPointMethod (arm of case @6375) |
| `trdos/logstuff.pas:6564` | CalculateQSOPoints | 4 | **ARRL10** | all | CalculateQSOPoints (existing) | reach 1: `QP` = ARRL10QSOPointMethod (arm of case @6375) |
| `trdos/logstuff.pas:6581` | CalculateQSOPoints | 4 | **ARRLVHFJAN**, **ARRLVHFJUN**, **ARRLVHFSEP** | all | CalculateQSOPoints (existing) | reach 3: `QP` = ARRLVHFJUNPointMethod (arm of case @6375) |
| `trdos/logstuff.pas:6618` | CalculateQSOPoints | 4 | **ALRS_UA1DZ_CUP** | all | CalculateQSOPoints (existing) | reach 1: `QP` = ALRSUA1DZCupQSOPointMethod (arm of case @6375) |
| `trdos/logstuff.pas:6689` | CalculateQSOPoints | 4 | **BALTIC** | all | CalculateQSOPoints (existing) | reach 1: `QP` = BalticQSOPointMethod (arm of case @6375) |
| `trdos/logstuff.pas:6719` | CalculateQSOPoints | 4 | **BWQP** | all | CalculateQSOPoints (existing) | reach 1: `QP` = BWQPQSOPointMethod (arm of case @6375) |
| `trdos/logstuff.pas:6730` | CalculateQSOPoints | 4 | **CIS** | all | CalculateQSOPoints (existing) | reach 1: `QP` = CISQSOPointMethod (arm of case @6375) |
| `trdos/logstuff.pas:6754` | CalculateQSOPoints | 4 | **CQ160CW**, **CQ160SSB** | all | CalculateQSOPoints (existing) | reach 2: `QP` = CQ160QSOPointMethod (arm of case @6375) |
| `trdos/logstuff.pas:6773` | CalculateQSOPoints | 4 | **CQM** | all | CalculateQSOPoints (existing) | reach 1: `QP` = CQMQSOPointMethod (arm of case @6375) |
| `trdos/logstuff.pas:6828` | CalculateQSOPoints | 4 | **CQVHF** | all | CalculateQSOPoints (existing) | reach 1: `QP` = CQVHFQSOPointMethod (arm of case @6375) |
| `trdos/logstuff.pas:6912` | CalculateQSOPoints | 4 | **CQWPXCW**, **CQWPXSSB**, **UCG** | all | CalculateQSOPoints (existing) | reach 3: `QP` = CQWPXQSOPointMethod (arm of case @6375) |
| `trdos/logstuff.pas:6948` | CalculateQSOPoints | 4 | **CQWPXRTTY** | all | CalculateQSOPoints (existing) | reach 1: `QP` = CQWPXRTTYQSOPointMethod (arm of case @6375) |
| `trdos/logstuff.pas:6999` | CalculateQSOPoints | 3 | (none by default) | - | CalculateQSOPoints (existing) | `Settings.Contest.Title = 'DL-DX-RTTY'` in the DLRTTY arm -- see dead code |
| `trdos/logstuff.pas:7025` | CalculateQSOPoints | 4 | **CQWWCW**, **CQWWSSB** | all | CalculateQSOPoints (existing) | reach 2: `QP` = CQWWQSOPointMethod (arm of case @6375) |
| `trdos/logstuff.pas:7044` | CalculateQSOPoints | 4 | **CQWWRTTY**, **WWIH** | all | CalculateQSOPoints (existing) | reach 2: `QP` = CQWWRTTYQSOPointMethod (arm of case @6375) |
| `trdos/logstuff.pas:7058` | CalculateQSOPoints | 4 | **CROATIAN** | all | CalculateQSOPoints (existing) | reach 1: `QP` = CroatianQSOPointMethod (arm of case @6375) |
| `trdos/logstuff.pas:7142` | CalculateQSOPoints | 4 | **REGION1FIELDDAY** | all | CalculateQSOPoints (existing) | reach 1: `QP` = EuropeanFieldDayQSOPointMethod (arm of case @6375) |
| `trdos/logstuff.pas:7298` | CalculateQSOPoints | 4 | **FOCMARATHON** | all | CalculateQSOPoints (existing) | reach 1: `QP` = FOCMarathonQSOPointMethod (arm of case @6375) |
| `trdos/logstuff.pas:7300` | CalculateQSOPoints | 3 | **FOCMARATHON** | all | CalculateQSOPoints (existing) | bonus callsign `'G4FOC'` |
| `trdos/logstuff.pas:7311` | CalculateQSOPoints | 4 | **RADIOVHFFD** | all | CalculateQSOPoints (existing) | reach 1: `QP` = RadioVHFFDQSOPointMethod (arm of case @6375) |
| `trdos/logstuff.pas:7343` | CalculateQSOPoints | 4 | **MAKROTHEN** | all | CalculateQSOPoints (existing) | reach 1: `QP` = MakrothenQSOPointMethod (arm of case @6375) |
| `trdos/logstuff.pas:7369` | CalculateQSOPoints | 4 | **NCQSOPARTY** | all | CalculateQSOPoints (existing) | reach 1: `QP` = NCQSOPointMethod (arm of case @6375) |
| `trdos/logstuff.pas:7384` | CalculateQSOPoints | 3 | **NCQSOPARTY** | all | CalculateQSOPoints (existing) | seven bonus callsigns `'N4T'`..`'N4L'` -- arm is dead, see dead code |
| `trdos/logstuff.pas:7418` | CalculateQSOPoints | 4 | **BCQP** | all | CalculateQSOPoints (existing) | reach 1: `QP` = BCQPQSOPointMethod (arm of case @6375) |
| `trdos/logstuff.pas:7432` | CalculateQSOPoints | 4 | IN7QPNE, **PAQSOPARTY** | some: PAQSOPARTY | CalculateQSOPoints (existing) | reach 2: `QP` = PAQSOPointMethod (arm of case @6375) |
| `trdos/logstuff.pas:7469` | CalculateQSOPoints | 4 | **OZHCRVHF** | all | CalculateQSOPoints (existing) | reach 1: `QP` = OZHCRVHFQSOPointMethod (arm of case @6375) |
| `trdos/logstuff.pas:7491` | CalculateQSOPoints | 4 | **EUROPEANVHF** | all | CalculateQSOPoints (existing) | reach 1: `QP` = EuropeanVHFQSOPointMethod (arm of case @6375) |
| `trdos/logstuff.pas:7496` | CalculateQSOPoints | 3 | (none by default) | - | CalculateQSOPoints (existing) | `Settings.Contest.Name = 'EURASIA'` in the EuropeanVHF arm -- see dead code |
| `trdos/logstuff.pas:7532` | CalculateQSOPoints | 4 | **TESLA** | all | CalculateQSOPoints (existing) | reach 1: `QP` = TeslaQSOPointMethod (arm of case @6375) |
| `trdos/logstuff.pas:7580` | CalculateQSOPoints | 4 | **FISTS** | all | CalculateQSOPoints (existing) | reach 1: `QP` = FistsQSOPointMethod (arm of case @6375) |
| `trdos/logstuff.pas:7590` | CalculateQSOPoints | 4 | **HADX** | all | CalculateQSOPoints (existing) | reach 1: `QP` = HADXQSOPointMethod (arm of case @6375) |
| `trdos/logstuff.pas:7611` | CalculateQSOPoints | 3 | (none by default) | - | CalculateQSOPoints (existing) | `DomesticQTH = 'TRC'` in the TRCDIGITAL arm |
| `trdos/logstuff.pas:7623` | CalculateQSOPoints | 3 | (none by default) | - | CalculateQSOPoints (existing) | `Settings.My.State = 'TRC'` |
| `trdos/logstuff.pas:7657` | CalculateQSOPoints | 4 | **YUDX** | all | CalculateQSOPoints (existing) | reach 1: `QP` = YUDXQSOPointMethod (arm of case @6375) |
| `trdos/logstuff.pas:7675` | CalculateQSOPoints | 4 | **UKEI** | all | CalculateQSOPoints (existing) | reach 1: `QP` = UKEIQSOPointMethod (arm of case @6375) |
| `trdos/logstuff.pas:7735` | CalculateQSOPoints | 4 | **MWC** | all | CalculateQSOPoints (existing) | reach 1: `QP` = MWCQP (arm of case @6375) |
| `trdos/logstuff.pas:7751` | CalculateQSOPoints | 4 | **HELVETIA** | all | CalculateQSOPoints (existing) | reach 1: `QP` = HelvetiaQSOPointMethod (arm of case @6375) |
| `trdos/logstuff.pas:7765` | CalculateQSOPoints | 4 | **BSCI** | all | CalculateQSOPoints (existing) | reach 1: `QP` = BSCIQSOPointMethod (arm of case @6375) |
| `trdos/logstuff.pas:7807` | CalculateQSOPoints | 4 | **IARU**, **OZCR_Z** | all | CalculateQSOPoints (existing) | reach 2: `QP` = IARUQSOPointMethod (arm of case @6375) |
| `trdos/logstuff.pas:7887` | CalculateQSOPoints | 4 | **IOTA** | all | CalculateQSOPoints (existing) | reach 1: `QP` = IOTAQSOPointMethod (arm of case @6375) |
| `trdos/logstuff.pas:7922` | CalculateQSOPoints | 4 | **JIDXCW**, **JIDXSSB** | all | CalculateQSOPoints (existing) | reach 2: `QP` = JapanInternationalDXQSOPointMethod (arm of case @6375) |
| `trdos/logstuff.pas:7995` | CalculateQSOPoints | 4 | **KCJ** | all | CalculateQSOPoints (existing) | reach 1: `QP` = KCJQSOPointMethod (arm of case @6375) |
| `trdos/logstuff.pas:8029` | CalculateQSOPoints | 4 | **NZFIELDDAY** | all | CalculateQSOPoints (existing) | reach 1: `QP` = NZFieldDayQSOPointMethod (arm of case @6375) |
| `trdos/logstuff.pas:8054` | CalculateQSOPoints | 4 | **OKDX** | all | CalculateQSOPoints (existing) | reach 1: `QP` = OKDXQSOPointMethod (arm of case @6375) |
| `trdos/logstuff.pas:8100` | CalculateQSOPoints | 4 | **OKOMSSB** | all | CalculateQSOPoints (existing) | reach 1: `QP` = OKOMSSBQSOPointMethod (arm of case @6375) |
| `trdos/logstuff.pas:8139` | CalculateQSOPoints | 4 | **RAEM** | all | CalculateQSOPoints (existing) | reach 1: `QP` = RAEMQSOPointMethod (arm of case @6375) |
| `trdos/logstuff.pas:8151` | CalculateQSOPoints | 3 | **RAEM** | all | CalculateQSOPoints (existing) | special callsign `'RAEM'` |
| `trdos/logstuff.pas:8166` | CalculateQSOPoints | 4 | **CANADA_DAY**, **CANADA_WINTER** | all | CalculateQSOPoints (existing) | reach 2: `QP` = RACQSOPointMethod (arm of case @6375) |
| `trdos/logstuff.pas:8198` | CalculateQSOPoints | 4 | RSGB18 | none | CalculateQSOPoints (existing) | reach 1: `QP` = RSGB160Method (arm of case @6375) |
| `trdos/logstuff.pas:8230` | CalculateQSOPoints | 4 | **RDA** | all | CalculateQSOPoints (existing) | reach 1: `QP` = RDAQSOPointMethod (arm of case @6375) |
| `trdos/logstuff.pas:8264` | CalculateQSOPoints | 4 | **RU3AXMEMORIAL**, **RUSSIANDX** | all | CalculateQSOPoints (existing) | reach 2: `QP` = RussianDXQSOPointMethod (arm of case @6375) |
| `trdos/logstuff.pas:8301` | CalculateQSOPoints | 1 | **RU3AXMEMORIAL** | all | CalculateQSOPoints (existing) | `Contest` compare |
| `trdos/logstuff.pas:8308` | CalculateQSOPoints | 4 | **SALMONRUN** | all | CalculateQSOPoints (existing) | reach 1: `QP` = SalmonRunQSOPointMethod (arm of case @6375) |
| `trdos/logstuff.pas:8320` | CalculateQSOPoints | 4 | **SACCW**, **SACSSB** | all | CalculateQSOPoints (existing) | reach 2: `QP` = ScandinavianQSOPointMethod (arm of case @6375) |
| `trdos/logstuff.pas:8360` | CalculateQSOPoints | 4 | **YBDX** | all | CalculateQSOPoints (existing) | reach 1: `QP` = IndonesianQSOPointMethod (arm of case @6375) |
| `trdos/logstuff.pas:8399` | CalculateQSOPoints | 4 | **BATAVIA_FT8** | all | CalculateQSOPoints (existing) | reach 1: `QP` = YBFT8QP (arm of case @6375) |
| `trdos/logstuff.pas:8428` | CalculateQSOPoints | 3 | **BATAVIA_FT8** | all | CalculateQSOPoints (existing) | `Settings.Contest.Title = 'YBDXDI-FT8'` in the YBFT8QP arm -- see dead code |
| `trdos/logstuff.pas:8446` | CalculateQSOPoints | 4 | **SOUTHAMERICANWW** | all | CalculateQSOPoints (existing) | reach 1: `QP` = SouthAmericanWWQSOPointMethod (arm of case @6375) |
| `trdos/logstuff.pas:8469` | CalculateQSOPoints | 4 | **STEWPERRY** | all | CalculateQSOPoints (existing) | reach 1: `QP` = StewPerryQSOPointMethod (arm of case @6375) |
| `trdos/logstuff.pas:8490` | CalculateQSOPoints | 4 | **WWDIGI** | all | CalculateQSOPoints (existing) | reach 1: `QP` = WWDigiQP (arm of case @6375) |
| `trdos/logstuff.pas:8497` | CalculateQSOPoints | 4 | **RTC** | all | CalculateQSOPoints (existing) | reach 1: `QP` = RTCQSOPointMethod (arm of case @6375) |
| `trdos/logstuff.pas:8534` | CalculateQSOPoints | 4 | **TENTEN** | all | CalculateQSOPoints (existing) | reach 1: `QP` = TenTenQSOPointMethod (arm of case @6375) |
| `trdos/logstuff.pas:8544` | CalculateQSOPoints | 4 | **TOEC** | all | CalculateQSOPoints (existing) | reach 1: `QP` = TOECQSOPointMethod (arm of case @6375) |
| `trdos/logstuff.pas:8560` | CalculateQSOPoints | 4 | **UBACW**, **UBASSB** | all | CalculateQSOPoints (existing) | reach 2: `QP` = UBAQSOPointMethod (arm of case @6375) |
| `trdos/logstuff.pas:8608` | CalculateQSOPoints | 4 | **UKRAINIAN** | all | CalculateQSOPoints (existing) | reach 1: `QP` = UkrainianQSOPointMethod (arm of case @6375) |
| `trdos/logstuff.pas:8637` | CalculateQSOPoints | 4 | **OCEANIADXCW**, **OCEANIADXSSB** | all | CalculateQSOPoints (existing) | reach 2: `QP` = VKZLQSOPointMethod (arm of case @6375) |
| `trdos/logstuff.pas:8654` | CalculateQSOPoints | 4 | **WAG** | all | CalculateQSOPoints (existing) | reach 1: `QP` = WAGQSOPointMethod (arm of case @6375) |
| `trdos/logstuff.pas:8682` | CalculateQSOPoints | 4 | **DARCWAEDCCW**, **DARCWAEDCSSB** | all | CalculateQSOPoints (existing) | reach 2: `QP` = WAEQSOPointMethod (arm of case @6375) |
| `trdos/logstuff.pas:8701` | CalculateQSOPoints | 4 | **WWL** | all | CalculateQSOPoints (existing) | reach 1: `QP` = WWLQSOPointMethod (arm of case @6375) |
| `trdos/logstuff.pas:8724` | CalculateQSOPoints | 4 | **YODX** | all | CalculateQSOPoints (existing) | reach 1: `QP` = YODXQSOPointMethod (arm of case @6375) |
| `trdos/logstuff.pas:8746` | CalculateQSOPoints | 4 | **INTERNETSPRINT**, **YOUTHCHAMPIONSHIPRF** | all | CalculateQSOPoints (existing) | reach 2 GENERIC-NAMED: `QP` = AlwaysOnePointPerQSO (arm of case @6375) |
| `trdos/logstuff.pas:8749` | CalculateQSOPoints | 4 | **CALQSOPARTY**, **RADIOYOC**, **SPDX** | all | CalculateQSOPoints (existing) | reach 3 GENERIC-NAMED: `QP` = ThreePointsPerQSO (arm of case @6375) |
| `trdos/logstuff.pas:8750` | CalculateQSOPoints | 4 | **RSGB_ROPOCO_CW**, **RSGB_ROPOCO_SSB** | all | CalculateQSOPoints (existing) | reach 2 GENERIC-NAMED: `QP` = TenPointsPerQSO (arm of case @6375) |
| `trdos/logstuff.pas:8814` | CalculateQSOPoints | 4 | **CUPRFCW**, **CUPRFDIG**, **CUPRFSSB** | all | CalculateQSOPoints (existing) | reach 3: `QP` = CupRFMethod (arm of case @6375) |
| `trdos/logstuff.pas:8858` | CalculateQSOPoints | 4 | UA4WCHAMPIONSHIP | none | CalculateQSOPoints (existing) | reach 1: `QP` = UA4WMethod (arm of case @6375) |
| `trdos/logstuff.pas:8909` | CalculateQSOPoints | 4 | **RFCHAMPIONSHIPCW**, **RFCHAMPIONSHIPSSB** | all | CalculateQSOPoints (existing) | reach 2: `QP` = ChampionshipRFMethod (arm of case @6375) |
| `trdos/logstuff.pas:8931` | CalculateQSOPoints | 4 | **UKRAINECHAMPIONSHIP** | all | CalculateQSOPoints (existing) | reach 1: `QP` = ChampionshipUkrMethod (arm of case @6375) |
| `trdos/logstuff.pas:8941` | CalculateQSOPoints | 4 | **WWPMC** | all | CalculateQSOPoints (existing) | reach 1: `QP` = WWPMCQSOPointMethod (arm of case @6375) |
| `trdos/logstuff.pas:8961` | CalculateQSOPoints | 4 | **JTDX** | all | CalculateQSOPoints (existing) | reach 1: `QP` = JTDXQSOPointMethod (arm of case @6375) |
| `trdos/logstuff.pas:9002` | CalculateQSOPoints | 4 | **LABRE** | all | CalculateQSOPoints (existing) | reach 1: `QP` = LABREQSOPointMethod (arm of case @6375) |
| `trdos/logstuff.pas:9040` | CalculateQSOPoints | 4 | **LZDX** | all | CalculateQSOPoints (existing) | reach 1: `QP` = LZDXQSOPointMethod (arm of case @6375) |
| `trdos/logstuff.pas:9073` | CalculateQSOPoints | 4 | **OLDNEWYEAR** | all | CalculateQSOPoints (existing) | reach 1: `QP` = OldNewYearQSOPointMethod (arm of case @6375) |
| `trdos/logstuff.pas:9093` | CalculateQSOPoints | 4 | **RFASCHAMPIONSHIPCW** | all | CalculateQSOPoints (existing) | reach 1: `QP` = ChampionshipRFASMethod (arm of case @6375) |
| `trdos/logstuff.pas:9109` | CalculateQSOPoints | 4 | **REGION1FIELDDAY_RCC_CW**, **REGION1FIELDDAY_RCC_SSB** | all | CalculateQSOPoints (existing) | reach 2: `QP` = RegionOneFieldDayRCCQSOPointMethod (arm of case @6375) |
| `trdos/logstuff.pas:9148` | CalculateQSOPoints | 4 | **GACWWWSACW** | all | CalculateQSOPoints (existing) | reach 1: `QP` = GACWWWSACWQSOPointMethod (arm of case @6375) |
| `trdos/logstuff.pas:9169` | CalculateQSOPoints | 4 | **LQP** | all | CalculateQSOPoints (existing) | reach 1: `QP` = LQPQSOPointMethod (arm of case @6375) |
| `trdos/logstuff.pas:9172` | CalculateQSOPoints | 3 | **LQP** | all | CalculateQSOPoints (existing) | `Name = 'LOCUST'` / `Callsign = 'K6VVA'` |
| `trdos/logstuff.pas:9178` | CalculateQSOPoints | 4 | **ARKTIKA_SPRING** | all | CalculateQSOPoints (existing) | reach 1: `QP` = ArktikaSpringQSOPointMethod (arm of case @6375) |
| `trdos/logstuff.pas:9190` | CalculateQSOPoints | 4 | **REFCW**, **REFSSB** | all | CalculateQSOPoints (existing) | reach 2: `QP` = REFQSOPointMethod (arm of case @6375) |
| `trdos/logstuff.pas:9207` | CalculateQSOPoints | 4 | **RADIOMEMORY** | all | CalculateQSOPoints (existing) | reach 1: `QP` = RadioMemoryQSOPointMethod (arm of case @6375) |
| `trdos/logstuff.pas:9222` | CalculateQSOPoints | 4 | **PCC** | all | CalculateQSOPoints (existing) | reach 1: `QP` = PCCQSOPointMethod (arm of case @6375) |
| `trdos/logstuff.pas:9252` | CalculateQSOPoints | 4 | **UNDX** | all | CalculateQSOPoints (existing) | reach 1: `QP` = UNDXQSOPointMethod (arm of case @6375) |
| `trdos/logstuff.pas:9274` | CalculateQSOPoints | 4 | **KINGOFSPAINCW**, **KINGOFSPAINSSB** | all | CalculateQSOPoints (existing) | reach 2: `QP` = KingOfSpainQSOPointMethod (arm of case @6375) |
| `trdos/logstuff.pas:9293` | CalculateQSOPoints | 4 | **GAGARINCUP** | all | CalculateQSOPoints (existing) | reach 1: `QP` = GagarinCupQSOPointMethod (arm of case @6375) |
| `trdos/logstuff.pas:9332` | CalculateQSOPoints | 4 | **CQMM** | all | CalculateQSOPoints (existing) | reach 1: `QP` = CQMMQSOPointMethod (arm of case @6375) |
| `trdos/logstuff.pas:9390` | CalculateQSOPoints | 4 | **R9W_UW9WK_MEMORIAL** | all | CalculateQSOPoints (existing) | reach 1: `QP` = R9WUW9WKMemorialQSOPointMethod (arm of case @6375) |
| `trdos/logstuff.pas:9401` | CalculateQSOPoints | 4 | **WRTC** | all | CalculateQSOPoints (existing) | reach 1: `QP` = WRTCQSOPointMethod (arm of case @6375) |
| `trdos/logstuff.pas:9547` | CalculateQSOPoints | 4 | **VAQP** | all | CalculateQSOPoints (existing) | reach 1: `QP` = VAQSOPOINTMETHOD (arm of case @6375) |
| `trdos/logstuff.pas:9563` | CalculateQSOPoints | 4 | **EUDX**, **IRTS** | all | CalculateQSOPoints (existing) | reach 2: `QP` = EUDXQSOPOINTMETHOD (arm of case @6375) |
| `trdos/logstuff.pas:9621` | CalculateQSOPoints | 4 | **YOTA** | all | CalculateQSOPoints (existing) | reach 1: `QP` = YOTAQSOPointMethod (arm of case @6375) |

### Exchange parsing and validation (54 rows)

| file:line | routine | shape | contest(s) -- **bold = has a class** | class? | seam | what |
|---|---|---|---|---|---|---|
| `MainUnit.pas:928` | ctyLocateCallStripRover | 4 | **COUNTYHUNTER** | all | new seam needed: RoverCallRules | reach 1: `AE` = RSTQTHExchange |
| `MainUnit.pas:969` | DetectRoverSlashInCall | 4 | **COUNTYHUNTER** | all | new seam needed: RoverCallRules | reach 1: `AE` = RSTQTHExchange |
| `MainUnit.pas:2052` | ReturnInSAPOpMode | 4 | **COUNTYHUNTER** | all | new seam needed: RoverCallRules | reach 1: `AE` = RSTQTHEXCHANGE |
| `MainUnit.pas:4045` | ExchangeWindowChange | 4 | POTA | none | new seam needed: ReceivedExchangeFields (s6) | reach 1 GENERIC-NAMED: `AE` = RSTAndPOTAPark |
| `MainUnit.pas:7145` | ParametersOkay | 4 | **BWQP**, **GENERALQSO**, POTA | some: BWQP, GENERALQSO | new seam needed: ValidateExchange | reach 3 GENERIC-NAMED: `AE` = RSTNameAndQTHExchange, RSTAndPOTAPark |
| `MainUnit.pas:8063` | LoadinLog | 1 | **RADIOYOC** | all | new seam needed: SessionExchangeState (previous QSO number) | `contest` compare |
| `trdos/logdom.pas:224` | DomQTHTableObject.GetDomQTH | 4 | **RDA** | all | new seam needed: ParseDomesticQTH | reach 1: `DM` = RDADistrict |
| `trdos/logdom.pas:263` | DomQTHTableObject.GetDomQTH | 4 | **IOTA** | all | new seam needed: ParseDomesticQTH | reach 1: `DM` = IOTADomestic |
| `trdos/logdupe.pas:1633` | SetUpExchangeInformation | 4 | **ARRLFIELDDAY**, **WINTERFIELDDAY** | all | new seam needed: ReceivedExchangeFields (s6) (which fields the exchange carries) | reach 2: `AE` = ClassDomesticOrDXQTHExchange (arm of case @1625) |
| `trdos/logdupe.pas:1639` | SetUpExchangeInformation | 4 | **KIDSDAY** | all | new seam needed: ReceivedExchangeFields (s6) (which fields the exchange carries) | reach 1: `AE` = KidsDayExchange (arm of case @1625) |
| `trdos/logdupe.pas:1644` | SetUpExchangeInformation | 4 | **CQMM**, **SOUTHAMERICANWW** | all | new seam needed: ReceivedExchangeFields (s6) (which fields the exchange carries) | reach 2: `AE` = RSTAndContinentExchange (arm of case @1625) |
| `trdos/logdupe.pas:1650` | SetUpExchangeInformation | 4 | **TENTEN** | all | new seam needed: ReceivedExchangeFields (s6) (which fields the exchange carries) | reach 1: `AE` = NameQTHAndPossibleTenTenNumber (arm of case @1625) |
| `trdos/logdupe.pas:1663` | SetUpExchangeInformation | 4 | **GRIDLOC** | all | new seam needed: ReceivedExchangeFields (s6) (which fields the exchange carries) | reach 1: `AE` = NameAndPossibleGridSquareExchange (arm of case @1625) |
| `trdos/logdupe.pas:1669` | SetUpExchangeInformation | 4 | **NZFIELDDAY** | all | new seam needed: ReceivedExchangeFields (s6) (which fields the exchange carries) | reach 1: `AE` = NZFieldDayExchange (arm of case @1625) |
| `trdos/logdupe.pas:1676` | SetUpExchangeInformation | 4 | **RAEM**, **RFASCHAMPIONSHIPCW** | all | new seam needed: ReceivedExchangeFields (s6) (which fields the exchange carries) | reach 2: `AE` = QSONumberAndCoordinatesSum, QSONumberAndGeoCoordinates (arm of case @1625) |
| `trdos/logdupe.pas:1682` | SetUpExchangeInformation | 4 | **RADIOYOC** | all | new seam needed: ReceivedExchangeFields (s6) (which fields the exchange carries) | reach 1: `AE` = QSONumberAndPreviousQSONumber (arm of case @1625) |
| `trdos/logdupe.pas:1688` | SetUpExchangeInformation | 4 | **R9W_UW9WK_MEMORIAL**, **RFCHAMPIONSHIPCW**, **RFCHAMPIONSHIPSSB** | all | new seam needed: ReceivedExchangeFields (s6) (which fields the exchange carries) | reach 3: `AE` = QSONumberAndZone (arm of case @1625) |
| `trdos/logdupe.pas:1707` | SetUpExchangeInformation | 4 | **QCWA**, **QCWAGOLDEN** | all | new seam needed: ReceivedExchangeFields (s6) (which fields the exchange carries) | reach 2: `AE` = QSONumberNameChapterAndQTHExchange (arm of case @1625) |
| `trdos/logdupe.pas:1722` | SetUpExchangeInformation | 4 | **ARRLSSCW**, **ARRLSSSSB** | all | new seam needed: ReceivedExchangeFields (s6) (which fields the exchange carries) | reach 2: `AE` = QSONumberPrecedenceCheckDomesticQTHExchange (arm of case @1625) |
| `trdos/logdupe.pas:1730` | SetUpExchangeInformation | 4 | **YOUTHCHAMPIONSHIPRF** | all | new seam needed: ReceivedExchangeFields (s6) (which fields the exchange carries) | reach 1: `AE` = AgeAndQSONumberExchange (arm of case @1625) |
| `trdos/logdupe.pas:1741` | SetUpExchangeInformation | 4 | POTA | none | new seam needed: ReceivedExchangeFields (s6) (which fields the exchange carries) | reach 1 GENERIC-NAMED: `AE` = RSTAndPOTAPark (arm of case @1625) |
| `trdos/logdupe.pas:1747` | SetUpExchangeInformation | 4 | **RADIOMEMORY** | all | new seam needed: ReceivedExchangeFields (s6) (which fields the exchange carries) | reach 1: `AE` = RSTAgeAndPossibleSK (arm of case @1625) |
| `trdos/logdupe.pas:1754` | SetUpExchangeInformation | 4 | **ALLASIANCW**, **ALLASIANSSB**, **YOTA** | all | new seam needed: ReceivedExchangeFields (s6) (which fields the exchange carries) | reach 3 GENERIC-NAMED: `AE` = RSTAgeExchange (arm of case @1625) |
| `trdos/logdupe.pas:1760` | SetUpExchangeInformation | 4 | **ALLJA** | all | new seam needed: ReceivedExchangeFields (s6) (which fields the exchange carries) | reach 1: `AE` = RSTALLJAPrefectureAndPrecedenceExchange (arm of case @1625) |
| `trdos/logdupe.pas:1767` | SetUpExchangeInformation | 4 | **ARCI** | all | new seam needed: ReceivedExchangeFields (s6) (which fields the exchange carries) | reach 1: `AE` = RSTPossibleDomesticQTHAndPower (arm of case @1625) |
| `trdos/logdupe.pas:1774` | SetUpExchangeInformation | 4 | **ARRLDIGI**, **WWDIGI** | all | new seam needed: ReceivedExchangeFields (s6) (which fields the exchange carries) | reach 2: `AE` = Grid2Exchange (arm of case @1625) |
| `trdos/logdupe.pas:1784` | SetUpExchangeInformation | 4 | **BATAVIA_FT8**, **MAKROTHEN** | all | new seam needed: ReceivedExchangeFields (s6) (which fields the exchange carries) | reach 2 GENERIC-NAMED: `AE` = GridExchange (arm of case @1625) |
| `trdos/logdupe.pas:1795` | SetUpExchangeInformation | 4 | **RSGB_ROPOCO_CW**, **RSGB_ROPOCO_SSB** | all | new seam needed: ReceivedExchangeFields (s6) (which fields the exchange carries) | reach 2: `AE` = RSTAndPostalCodeExchange (arm of case @1625) |
| `trdos/logdupe.pas:1824` | SetUpExchangeInformation | 4 | **BWQP**, **GENERALQSO** | all | new seam needed: ReceivedExchangeFields (s6) (which fields the exchange carries) | reach 2 GENERIC-NAMED: `AE` = RSTNameAndQTHExchange (arm of case @1625) |
| `trdos/logdupe.pas:1867` | SetUpExchangeInformation | 4 | **FISTS** | all | new seam needed: ReceivedExchangeFields (s6) (which fields the exchange carries) | reach 1: `AE` = RSTQTHNameAndFistsNumberOrPowerExchange (arm of case @1625) |
| `trdos/logdupe.pas:1876` | SetUpExchangeInformation | 4 | **XMAS** | all | new seam needed: ReceivedExchangeFields (s6) (which fields the exchange carries) | reach 1: `AE` = RSTQSONumberAndRandomCharactersExchange (arm of case @1625) |
| `trdos/logdupe.pas:1883` | SetUpExchangeInformation | 4 | **CQWWRTTY** | all | new seam needed: ReceivedExchangeFields (s6) (which fields the exchange carries) | reach 1: `AE` = RSTZoneAndPossibleDomesticQTHExchange (arm of case @1625) |
| `trdos/logdupe.pas:1903` | SetUpExchangeInformation | 4 | **JALONGPREFECT** | all | new seam needed: ReceivedExchangeFields (s6) (which fields the exchange carries) | reach 1: `AE` = RSTLongJAPrefectureExchange (arm of case @1625) |
| `trdos/logdupe.pas:1962` | ParseExchangeIntoContestExchange | 4 | **FISTS** | all | new seam needed: ParseReceivedExchange (s6) | reach 1: `AE` = RSTQTHNameAndFistsNumberOrPowerExchange |
| `trdos/logdupe.pas:2075` | GetInitialExchangeStringFromContestExchange | 4 | **ALLJA** | all | new seam needed: InitialExchangeFromHistory | reach 1: `AE` = RSTALLJAPrefectureAndPrecedenceExchange |
| `trdos/logdupe.pas:2098` | GetInitialExchangeStringFromContestExchange | 4 | **FISTS** | all | new seam needed: InitialExchangeFromHistory | reach 1: `AE` = RSTQTHNameAndFistsNumberOrPowerExchange |
| `trdos/logedit.pas:2269` | InitialExchangeEntry | 4 | **CQWWCW** | all | new seam needed: InitialExchangeFromHistory (InitialExchangeKind is the existing trait) | reach 1: `AIE` = CustomInitialExchange (arm of case @2267) |
| `trdos/logedit.pas:2416` | InitialExchangeEntry | 1 | **OZCR_O**, **OZCR_Z** | all | new seam needed: InitialExchangeFromHistory (InitialExchangeKind is the existing trait) | `Contest` in |
| `trdos/logedit.pas:2434` | InitialExchangeEntry | 1 | **RFCHAMPIONSHIPCW**, **RFCHAMPIONSHIPSSB** | all | new seam needed: InitialExchangeFromHistory (InitialExchangeKind is the existing trait) | `Contest` in |
| `trdos/logedit.pas:2551` | InitialExchangeEntry | 4 | **ARRLSSCW**, **ARRLSSSSB** | all | new seam needed: InitialExchangeFromHistory (InitialExchangeKind is the existing trait) | reach 2: `AIE` = CheckSectionInitialExchange (arm of case @2267) |
| `trdos/logedit.pas:2646` | InitialExchangeEntry | 1 | **RDA**, **RU3AXMEMORIAL**, **RUSSIANDX** | all | new seam needed: InitialExchangeFromHistory (InitialExchangeKind is the existing trait) | `Contest` in |
| `trdos/logedit.pas:2674` | InitialExchangeEntry | 4 | **CALQSOPARTY**, **VAQP** | all | new seam needed: InitialExchangeFromHistory (InitialExchangeKind is the existing trait) | reach 2 GENERIC-NAMED: `AE` = QSONumberDomesticOrDXQTHExchange |
| `trdos/logedit.pas:2676` | InitialExchangeEntry | 4 | **CUPURAL**, **PAQSOPARTY**, **UKRAINECHAMPIONSHIP** | all | new seam needed: InitialExchangeFromHistory (InitialExchangeKind is the existing trait) | reach 3: `AE` = QSONumberDomesticQTHExchange |
| `trdos/logedit.pas:2677` | InitialExchangeEntry | 4 | **CUPRFCW**, **CUPRFDIG**, **CUPRFSSB** | all | new seam needed: InitialExchangeFromHistory (InitialExchangeKind is the existing trait) | reach 3: `AE` = QSONumberAndGridSquare |
| `trdos/logedit.pas:2682` | InitialExchangeEntry | 4 | **NRAUBALTICCW**, **NRAUBALTICSSB**, **OHIOQSOPARTY** | all | new seam needed: InitialExchangeFromHistory (InitialExchangeKind is the existing trait) | reach 3 GENERIC-NAMED: `AE` = RSTQSONumberAndDomesticQTHExchange |
| `trdos/logedit.pas:2683` | InitialExchangeEntry | 4 | **CQIR** | all | new seam needed: InitialExchangeFromHistory (InitialExchangeKind is the existing trait) | reach 1: `AE` = QSONumberAndPossibleDomesticQTHExchange |
| `trdos/logedit.pas:2699` | InitialExchangeEntry | 4 | **ARRLSSCW**, **ARRLSSSSB** | all | new seam needed: InitialExchangeFromHistory (InitialExchangeKind is the existing trait) | reach 2: `AE` = QSONumberPrecedenceCheckDomesticQTHEXchange |
| `trdos/logedit.pas:2711` | InitialExchangeEntry | 1 | **IARU** | all | new seam needed: InitialExchangeFromHistory (InitialExchangeKind is the existing trait) | `Contest` compare |
| `trdos/logstuff.pas:5582` | ProcessRSTAndZoneExchange | 4 | **EUROPEANHFC**, **KVP** | all | new seam needed: ParseReceivedExchange (s6) | reach 2: `ZnM` = EUHFCYear |
| `trdos/logstuff.pas:9975` | ProcessRSTAndGridSquareOrRDAExchange | 1 | UA4WCHAMPIONSHIP | none | new seam needed: ParseReceivedExchange (s6) | `Contest` compare |
| `trdos/logstuff.pas:10307` | ProcessExchange | 4 | **BWQP**, **GENERALQSO**, POTA | some: BWQP, GENERALQSO | new seam needed: ParseReceivedExchange (s6), keyed today by the ExchangeKind trait | reach 3 GENERIC-NAMED: `AE` = RSTNameAndQTHExchange, RSTAndPOTAPark |
| `trdos/logstuff.pas:10401` | DomStringParse | 4 | **RDA** | all | new seam needed: ParseDomesticQTH | reach 1: `DM` = RDADistrict |
| `trdos/logstuff.pas:10430` | DomStringParse | 4 | **IOTA** | all | new seam needed: ParseDomesticQTH | reach 1: `DM` = IOTADomestic |
| `uCallSignRoutines.pas:699` | IsAGoodCall | 3 | **RAEM** | all | new seam needed: IsAcceptableCallsign | `Call = 'RAEM'` accepted as a callsign |

### Dupe (0 rows)

None found.

### Multipliers (16 rows)

| file:line | routine | shape | contest(s) -- **bold = has a class** | class? | seam | what |
|---|---|---|---|---|---|---|
| `trdos/logdupe.pas:695` | GetDXQTH | 4 | **WINTERFIELDDAY** | all | DXMultiplierType (existing trait) + new seam needed: DXMultiplierRule | reach 1 GENERIC-NAMED: `XM` = ARRLDXCCWithNoARRLSections (arm of case @682) |
| `trdos/logdupe.pas:701` | GetDXQTH | 4 | **ARCI**, **ARRL10** | all | DXMultiplierType (existing trait) + new seam needed: DXMultiplierRule | reach 2: `XM` = ARRLDXCCWithNoUSACanadaKH6OrKL7 (arm of case @682) |
| `trdos/logdupe.pas:708` | GetDXQTH | 4 | **ARI_DX** | all | DXMultiplierType (existing trait) + new seam needed: DXMultiplierRule | reach 1: `XM` = ARRLDXCCWithNoIOrIS0 (arm of case @682) |
| `trdos/logdupe.pas:717` | GetDXQTH | 4 | **JTDX** | all | DXMultiplierType (existing trait) + new seam needed: DXMultiplierRule | reach 1: `XM` = ARRLDXCCWithNoJT (arm of case @682) |
| `trdos/logdupe.pas:734` | GetDXQTH | 4 | **UBACW**, **UBASSB** | all | DXMultiplierType (existing trait) + new seam needed: DXMultiplierRule | reach 2: `XM` = CQUBAEuropeanCountries (arm of case @682) |
| `trdos/logdupe.pas:752` | GetDXQTH | 4 | **BSCI** | all | DXMultiplierType (existing trait) + new seam needed: DXMultiplierRule | reach 1: `XM` = BlackSeaCountries (arm of case @682) |
| `trdos/logdupe.pas:2257` | DupeAndMultSheet.SetUpRemainingMultiplierArrays | 4 | **EUROPEANHFC**, **KVP** | all | ZoneMultiplierType (existing trait) + new seam needed: RemainingMultList | reach 2: `ZnM` = EUHFCYear (arm of case @2255) |
| `trdos/logdupe.pas:2260` | DupeAndMultSheet.SetUpRemainingMultiplierArrays | 4 | **NZFIELDDAY** | all | ZoneMultiplierType (existing trait) + new seam needed: RemainingMultList | reach 1: `ZnM` = BranchZones (arm of case @2255) |
| `trdos/logdupe.pas:2261` | DupeAndMultSheet.SetUpRemainingMultiplierArrays | 4 | **RFCHAMPIONSHIPCW**, **RFCHAMPIONSHIPSSB** | all | ZoneMultiplierType (existing trait) + new seam needed: RemainingMultList | reach 2: `ZnM` = RFChampionchipZones (arm of case @2255) |
| `trdos/logedit.pas:1499` | Add | 4 | **EUROPEANHFC**, **KVP** | all | ZoneMultiplierType (existing trait) + new seam needed: ZoneMultRule | reach 2: `ZnM` = EUHFCYear |
| `trdos/logedit.pas:2919` | SetPrefix | 4 | **UBACW**, **UBASSB** | all | PrefixMultiplierType (existing trait) + new seam needed: PrefixMultRule | reach 2: `Pxm` = BelgiumPrefixes (arm of case @2916) |
| `trdos/logedit.pas:2926` | SetPrefix | 4 | **CQMM**, **SASPRINT** | all | PrefixMultiplierType (existing trait) + new seam needed: PrefixMultRule | reach 2: `Pxm` = SouthAmericanPrefixes (arm of case @2916) |
| `trdos/logedit.pas:2948` | SetPrefix | 4 | **JTDX** | all | PrefixMultiplierType (existing trait) + new seam needed: PrefixMultRule | reach 1: `Pxm` = MongolianCallSignPrefix (arm of case @2916) |
| `trdos/logedit.pas:2958` | SetPrefix | 4 | **GAGARINCUP** | all | PrefixMultiplierType (existing trait) + new seam needed: PrefixMultRule | reach 1: `Pxm` = GCStation (arm of case @2916) |
| `trdos/logedit.pas:2960` | SetPrefix | 3 | **GAGARINCUP** | all | PrefixMultiplierType (existing trait) + new seam needed: PrefixMultRule | six GC-station callsigns (`'RK1G'`..`'UN/RA3VM'`) |
| `uMults.pas:271` | MultsObject.FillVisibleBytes | 4 | **UBACW**, **UBASSB** | all | DXMultiplierType (existing trait) + new seam needed: DXMultiplierRule | reach 2: `XM` = CQUBAEuropeanCountries |

### ADIF import (2 rows)

| file:line | routine | shape | contest(s) -- **bold = has a class** | class? | seam | what |
|---|---|---|---|---|---|---|
| `MainUnit.pas:10008` | ApplyClasslessADIFImport | 2 | POTA | none | new seam needed: ApplyADIFImport -- needs a POTA / ARRL 160 class | arm of `case exch.ceContest of` @10007 |
| `trdos/logstuff.pas:10944` | ResolvePOTAParkFromADIF | 3 | POTA | none | new seam needed: ApplyADIFImport (SIG / SIG_INFO) | ADIF `SIG = 'POTA'` -- the park from `SIG_INFO` (D5, fixed in `3f9e3f28`) |

### ADIF export (6 rows)

| file:line | routine | shape | contest(s) -- **bold = has a class** | class? | seam | what |
|---|---|---|---|---|---|---|
| `trdos/postunit.pas:2315` | EmitContestSpecificTailForExport | 2 | POTA | none | EmitADIFContestFields (existing) | `rec.ceContest` compare |
| `trdos/postunit.pas:2323` | EmitContestSpecificTailForExport | 2 | POTA | none | EmitADIFContestFields (existing) | `rec.ceContest` compare |
| `trdos/postunit.pas:2390` | EmitContestSpecificTailForExport | 4 | **RDA** | all | EmitADIFContestFields (existing) | reach 1: `DM` = RDADistrict |
| `trdos/postunit.pas:2399` | EmitContestSpecificTailForExport | 2 | POTA | none | EmitADIFContestFields (existing) | arm of `case rec.ceContest of` @2398 |
| `uADIF.pas:1692` | EmitADIFRecord | 2 | POTA | none | ADIFContestId / WritesADIFContestId / ADIFPowerTag (existing) | `rec.ceContest` compare |
| `uADIFExchange.pas:271` | FormatADIFExchangeOfKind | 3 | (none by default) | - | FormatADIFSentExchange (existing; this is the base's default) | `cMyState = 'TRC'` |

### Cabrillo export (7 rows)

| file:line | routine | shape | contest(s) -- **bold = has a class** | class? | seam | what |
|---|---|---|---|---|---|---|
| `trdos/postunit.pas:2978` | tGenerateLogPortionOfCabrilloFile | 3 | **LABRE** | all | FormatCabrilloReceivedExchange / CabrilloQSOLineFormat / CabrilloModeString (existing; CabrilloModeString M9a) | `Settings.Contest.Name = 'LABRE'` |
| `trdos/postunit.pas:2992` | tGenerateLogPortionOfCabrilloFile | 1 | **CUPRFCW**, **CUPRFSSB** | all | FormatCabrilloReceivedExchange / CabrilloQSOLineFormat / CabrilloModeString (existing; CabrilloModeString M9a) | `Contest` in |
| `trdos/postunit.pas:2997` | tGenerateLogPortionOfCabrilloFile | 3 | (none by default) | - | FormatCabrilloReceivedExchange / CabrilloQSOLineFormat / CabrilloModeString (existing; CabrilloModeString M9a) | `Settings.Contest.Name = 'EURASIA'` -- see dead code |
| `uCabrilloExchange.pas:299` | SetHisEx | 3 | (none by default) | - | FormatCabrilloSentExchange / FormatCabrilloReceivedExchange (existing; this is the base's default) | `cMyState = 'TRC'` -- TRC Digital, no ContestType |
| `uCabrilloExchange.pas:303` | SetHisEx | 3 | (none by default) | - | FormatCabrilloSentExchange / FormatCabrilloReceivedExchange (existing; this is the base's default) | `ContestTitle = 'PGA'` -- no ContestType; operator-titled |
| `uCabrilloExchange.pas:314` | SetHisEx | 3 | (none by default) | - | FormatCabrilloSentExchange / FormatCabrilloReceivedExchange (existing; this is the base's default) | `ContestTitle = 'PGA'` -- no ContestType; operator-titled |
| `uCabrilloExchange.pas:318` | SetHisEx | 3 | (none by default) | - | FormatCabrilloSentExchange / FormatCabrilloReceivedExchange (existing; this is the base's default) | `csQTHString = 'TRC'` |

### Score, summary and totals (3 rows)

| file:line | routine | shape | contest(s) -- **bold = has a class** | class? | seam | what |
|---|---|---|---|---|---|---|
| `trdos/logedit.pas:2901` | TotalScore | 1 | RSGB18 | none | new seam needed: CalculateTotalScore (s6) | `Contest` compare |
| `trdos/postunit.pas:1166` | CalculateTotals | 3 | **CQWWCW**, **CQWWRTTY**, **CQWWSSB** | all | new seam needed: OffTimeMinimumMinutes | `Pos('CQ-WW', Settings.Contest.Name)` -- 60-minute off-time |
| `trdos/postunit.pas:1290` | CheckForNewContestDate | 1 | **GENERALQSO** | all | new seam needed: MaxContestDates | `Contest` compare |

### UI, display and the new-contest dialog (19 rows)

| file:line | routine | shape | contest(s) -- **bold = has a class** | class? | seam | what |
|---|---|---|---|---|---|---|
| `MainUnit.pas:1753` | ReturnInCQOpMode | 1 | **GENERALQSO** | all | new seam needed: ShowsMultiplierStatus | `Contest` compare |
| `MainUnit.pas:4126` | CallWindowChange | 1 | **WAG** | all | new seam needed: OnCallsignChanged | `Contest` compare |
| `MainUnit.pas:4467` | CreateMainWindow | 3 | **CQWWCW**, **CQWWRTTY**, **CQWWSSB**, **IARU** | all | PermittedOperatingAids / OffersQTCs (existing, M9a) + new seam needed: UIFeatures (off-time, POTA menus) | `Pos('CQ-WW'` / `'IARU-HF'` in `ContestTypeSA[Contest]` -- 60-minute off-time |
| `MainUnit.pas:4526` | CreateMainWindow | 1 | POTA | none | PermittedOperatingAids / OffersQTCs (existing, M9a) + new seam needed: UIFeatures (off-time, POTA menus) | `Contest` compare |
| `MainUnit.pas:8309` | BuildLogRow | 1 | **FOCMARATHON** | all | new seam needed: LogColumns | `Contest` compare |
| `MainUnit.pas:9529` | SetColumnsWidth | 4 | **ARRLSSCW**, **ARRLSSSSB** | all | new seam needed: LogColumns | reach 2: `AE` = QSONumberPrecedenceCheckDomesticQTHExchange |
| `MainUnit.pas:9531` | SetColumnsWidth | 4 | **ARRLSSCW**, **ARRLSSSSB** | all | new seam needed: LogColumns | reach 2: `AE` = QSONumberPrecedenceCheckDomesticQTHExchange |
| `MainUnit.pas:9544` | SetColumnsWidth | 1 | **FOCMARATHON** | all | new seam needed: LogColumns | `Contest` compare |
| `MainUnit.pas:9548` | SetColumnsWidth | 1 | **FOCMARATHON** | all | new seam needed: LogColumns | `Contest` compare |
| `trdos/logedit.pas:1995` | ShowStationInformation | 1 | **GENERALQSO** | all | new seam needed: ShowsMultiplierStatus | `Contest` compare |
| `trdos/logstuff.pas:983` | BandChange | 1 | **GENERALQSO** | all | new seam needed: AllowsWARCBands | `CONTEST` compare |
| `trdos/logsubs2.pas:2497` | OperateContest | 1 | **GENERALQSO** | all | new seam needed: ShowsMultiplierStatus | `Contest` compare |
| `trdos/logsubs2.pas:2521` | OperateContest | 1 | **GENERALQSO** | all | new seam needed: ShowsMultiplierStatus | `Contest` compare |
| `trdos/logwind.pas:2421` | SetUpBandMapEntry | 1 | **GENERALQSO** | all | new seam needed: ShowsMultiplierStatus | `Contest` compare |
| `uNewContest.pas:192` | ClasslessPrompts | 2 | POTA | none | DescribeNewContestPrompts (existing, M9a) -- needs a POTA / RSGB 1.8 / UA4W class | arm of `case SelectedContest of` @191 |
| `uNewContest.pas:196` | ClasslessPrompts | 2 | RSGB18 | none | DescribeNewContestPrompts (existing, M9a) -- needs a POTA / RSGB 1.8 / UA4W class | arm of `case SelectedContest of` @191 |
| `uNewContest.pas:205` | ClasslessPrompts | 2 | RSGB18 | none | DescribeNewContestPrompts (existing, M9a) -- needs a POTA / RSGB 1.8 / UA4W class | arm of `case SelectedContest of` @204 |
| `uNewContest.pas:209` | ClasslessPrompts | 2 | POTA | none | DescribeNewContestPrompts (existing, M9a) -- needs a POTA / RSGB 1.8 / UA4W class | arm of `case SelectedContest of` @204 |
| `uNewContest.pas:213` | ClasslessPrompts | 2 | UA4WCHAMPIONSHIP | none | DescribeNewContestPrompts (existing, M9a) -- needs a POTA / RSGB 1.8 / UA4W class | arm of `case SelectedContest of` @204 |

### Setup (FoundContest / LogCfg) (2 rows)

| file:line | routine | shape | contest(s) -- **bold = has a class** | class? | seam | what |
|---|---|---|---|---|---|---|
| `trdos/LogCfg.pas:888` | tSetupExchangeNumbers | 1 | UA4WCHAMPIONSHIP | none | new seam needed: SentExchangeFields / FormatSentExchange (s6) | arm of `case Contest of` @885 |
| `trdos/fcontest.pas:377` | SetUpRSTMyZoneExchange | 4 | **CQWWRTTY** | all | new seam needed: ConfigureSession | reach 1: `AE` = RSTZoneAndPossibleDomesticQTHExchange |

### Networking and score reporting (0 rows)

None found.

### Other (27 rows)

| file:line | routine | shape | contest(s) -- **bold = has a class** | class? | seam | what |
|---|---|---|---|---|---|---|
| `trdos/logddx.pas:250` | GetRandomDDXCallsign | 3 | **SACCW**, **SACSSB** | all | new seam needed: SimulatorRules (DDX) | `Settings.Contest.Name = 'Scandinavian Contest'` -- see dead code |
| `trdos/logddx.pas:287` | GetRandomDDXCallsign | 4 | **ARCI**, **ARRL10**, **WINTERFIELDDAY** | all | new seam needed: SimulatorRules (DDX) | reach 3 GENERIC-NAMED: `XM` = ARRLDXCCWithNoUSACanadaKH6OrKL7, ARRLDXCCWithNoARRLSections (arm of case @269) |
| `trdos/logddx.pas:296` | GetRandomDDXCallsign | 4 | **ARI_DX** | all | new seam needed: SimulatorRules (DDX) | reach 1: `XM` = ARRLDXCCWithNoIOrIS0 (arm of case @269) |
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
| `trdos/logddx.pas:858` | GetNextCallFromReadInLog | 4 | **TENTEN** | all | new seam needed: SimulatorRules (DDX) | reach 1: `AE` = NameQTHAndPossibleTenTenNumber |
| `trdos/logddx.pas:859` | GetNextCallFromReadInLog | 4 | **GRIDLOC** | all | new seam needed: SimulatorRules (DDX) | reach 1: `AE` = NameAndPossibleGridSquareExchange |
| `trdos/logddx.pas:860` | GetNextCallFromReadInLog | 4 | **CALQSOPARTY**, **VAQP** | all | new seam needed: SimulatorRules (DDX) | reach 2 GENERIC-NAMED: `AE` = QSONumberDomesticOrDXQTHExchange |
| `trdos/logddx.pas:861` | GetNextCallFromReadInLog | 4 | **CUPURAL**, **PAQSOPARTY**, **UKRAINECHAMPIONSHIP** | all | new seam needed: SimulatorRules (DDX) | reach 3: `AE` = QSONumberDomesticQTHExchange |
| `trdos/logddx.pas:862` | GetNextCallFromReadInLog | 4 | **QCWA**, **QCWAGOLDEN** | all | new seam needed: SimulatorRules (DDX) | reach 2: `AE` = QSONumberNameChapterAndQTHExchange |
| `trdos/logddx.pas:864` | GetNextCallFromReadInLog | 4 | **ARRLSSCW**, **ARRLSSSSB** | all | new seam needed: SimulatorRules (DDX) | reach 2: `AE` = QSONumberPrecedenceCheckDomesticQTHExchange |
| `trdos/logddx.pas:907` | DDXExchange | 4 | **ARRLFIELDDAY**, **WINTERFIELDDAY** | all | new seam needed: SimulatorRules (DDX) | reach 2: `AE` = ClassDomesticOrDXQTHExchange (arm of case @905) |
| `trdos/logddx.pas:1009` | DDXExchange | 4 | **ARRLSSCW**, **ARRLSSSSB** | all | new seam needed: SimulatorRules (DDX) | reach 2: `AE` = QSONumberPrecedenceCheckDomesticQTHExchange (arm of case @905) |
| `trdos/logddx.pas:1061` | DDXExchange | 4 | **ALLASIANCW**, **ALLASIANSSB**, **YOTA** | all | new seam needed: SimulatorRules (DDX) | reach 3 GENERIC-NAMED: `AE` = RSTAgeExchange (arm of case @905) |

---

## 5. Setup -- `FoundContest`'s `case Contest of` (`fcontest.pas:898`)

**2 arms naming 2 contests; 0 of those contests have a class**
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
| `fcontest.pas:945-974` | POTA | CQmem 2, Settings 5, other:tAllowDupeQSOs 1 |
| `fcontest.pas:975-982` | UA4WCHAMPIONSHIP | Settings 1 |

---

## 6. Per-contest index

Every site from sections 4 and 5, by contest. Shape-4 rows are included for
every contest the tested value reaches (reach 1-3).

### 6.1 Registered contests -- rules that should already have moved

**144 of 181.** Sorted by number of sites. Registered contests with
**no** site outside the factory: `APSPRINT`, `ARRL_RTTY_ROUNDUP`, `ArizonaQsoParty`, `COLORADOQSOPARTY`, `CWOPEN`, `CWOPS`, `DARC10M`, `DARCXMAS`, `EUSPRINT_AUTUMN_CW`, `EUSPRINT_AUTUMN_SSB`, `EUSPRINT_SPRING_CW`, `EUSPRINT_SPRING_SSB`, `FLORIDAQSOPARTY`, `INQSOPARTY`, `MARCONIMEMORIAL`, `MICHQSOPARTY`, `MINI40`, `MINI80`, `MINITEST`, `MINNQSOPARTY`, `MOQSOPARTY`, `MST`, `NAQSOCW`, `NAQSORTTY`, `NAQSOSSB`, `NASPRINTCW`, `NASPRINTRTTY`, `NCCCSPRINT`, `NEWENGLANDQSO`, `NYQP`, `PACC`, `SEVENQP`, `SPRINTSSB`, `SST`, `TENNESSEEQSOPARTY`, `TEXASQSOPARTY`, `WISCONSINQSOPARTY`.

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
| ARRLSSCW | **exchange** `trdos/logdupe.pas:1722`, `trdos/logedit.pas:2551`, `trdos/logedit.pas:2699`; **ui** `MainUnit.pas:9529`, `MainUnit.pas:9531`; **other** `trdos/logddx.pas:605`, `trdos/logddx.pas:631`, `trdos/logddx.pas:652`, `trdos/logddx.pas:673`, `trdos/logddx.pas:704`, `trdos/logddx.pas:731`, `trdos/logddx.pas:752`, `trdos/logddx.pas:864`, `trdos/logddx.pas:1009` |
| ARRLSSSSB | **exchange** `trdos/logdupe.pas:1722`, `trdos/logedit.pas:2551`, `trdos/logedit.pas:2699`; **ui** `MainUnit.pas:9529`, `MainUnit.pas:9531`; **other** `trdos/logddx.pas:605`, `trdos/logddx.pas:631`, `trdos/logddx.pas:652`, `trdos/logddx.pas:673`, `trdos/logddx.pas:704`, `trdos/logddx.pas:731`, `trdos/logddx.pas:752`, `trdos/logddx.pas:864`, `trdos/logddx.pas:1009` |
| WINTERFIELDDAY | **scoring** `trdos/logstuff.pas:6513`; **exchange** `trdos/logdupe.pas:1633`; **multipliers** `trdos/logdupe.pas:695`; **other** `trdos/logddx.pas:287`, `trdos/logddx.pas:606`, `trdos/logddx.pas:632`, `trdos/logddx.pas:653`, `trdos/logddx.pas:674`, `trdos/logddx.pas:705`, `trdos/logddx.pas:732`, `trdos/logddx.pas:753`, `trdos/logddx.pas:856`, `trdos/logddx.pas:907` |
| ARRLFIELDDAY | **scoring** `trdos/logstuff.pas:6513`; **exchange** `trdos/logdupe.pas:1633`; **other** `trdos/logddx.pas:606`, `trdos/logddx.pas:632`, `trdos/logddx.pas:653`, `trdos/logddx.pas:674`, `trdos/logddx.pas:705`, `trdos/logddx.pas:732`, `trdos/logddx.pas:753`, `trdos/logddx.pas:856`, `trdos/logddx.pas:907` |
| GENERALQSO | **exchange** `MainUnit.pas:7145`, `trdos/logdupe.pas:1824`, `trdos/logstuff.pas:10307`; **score-summary** `trdos/postunit.pas:1290`; **ui** `MainUnit.pas:1753`, `trdos/logedit.pas:1995`, `trdos/logstuff.pas:983`, `trdos/logsubs2.pas:2497`, `trdos/logsubs2.pas:2521`, `trdos/logwind.pas:2421` |
| CQWWRTTY | **scoring** `trdos/logstuff.pas:7044`; **exchange** `trdos/logdupe.pas:1883`; **score-summary** `trdos/postunit.pas:1166`; **ui** `MainUnit.pas:4467`; **setup** `trdos/fcontest.pas:377` |
| FOCMARATHON | **scoring** `trdos/logstuff.pas:7298`, `trdos/logstuff.pas:7300`; **ui** `MainUnit.pas:8309`, `MainUnit.pas:9544`, `MainUnit.pas:9548` |
| RDA | **scoring** `trdos/logstuff.pas:8230`; **exchange** `trdos/logdom.pas:224`, `trdos/logedit.pas:2646`, `trdos/logstuff.pas:10401`; **adif-export** `trdos/postunit.pas:2390` |
| ARCI | **scoring** `trdos/logstuff.pas:6454`; **exchange** `trdos/logdupe.pas:1767`; **multipliers** `trdos/logdupe.pas:701`; **other** `trdos/logddx.pas:287` |
| BWQP | **scoring** `trdos/logstuff.pas:6719`; **exchange** `MainUnit.pas:7145`, `trdos/logdupe.pas:1824`, `trdos/logstuff.pas:10307` |
| CQWWCW | **scoring** `trdos/logstuff.pas:7025`; **exchange** `trdos/logedit.pas:2269`; **score-summary** `trdos/postunit.pas:1166`; **ui** `MainUnit.pas:4467` |
| FISTS | **scoring** `trdos/logstuff.pas:7580`; **exchange** `trdos/logdupe.pas:1867`, `trdos/logdupe.pas:1962`, `trdos/logdupe.pas:2098` |
| RAEM | **scoring** `trdos/logstuff.pas:8139`, `trdos/logstuff.pas:8151`; **exchange** `trdos/logdupe.pas:1676`, `uCallSignRoutines.pas:699` |
| RFCHAMPIONSHIPCW | **scoring** `trdos/logstuff.pas:8909`; **exchange** `trdos/logdupe.pas:1688`, `trdos/logedit.pas:2434`; **multipliers** `trdos/logdupe.pas:2261` |
| RFCHAMPIONSHIPSSB | **scoring** `trdos/logstuff.pas:8909`; **exchange** `trdos/logdupe.pas:1688`, `trdos/logedit.pas:2434`; **multipliers** `trdos/logdupe.pas:2261` |
| UBACW | **scoring** `trdos/logstuff.pas:8560`; **multipliers** `trdos/logdupe.pas:734`, `trdos/logedit.pas:2919`, `uMults.pas:271` |
| UBASSB | **scoring** `trdos/logstuff.pas:8560`; **multipliers** `trdos/logdupe.pas:734`, `trdos/logedit.pas:2919`, `uMults.pas:271` |
| ALLASIANCW | **scoring** `trdos/logstuff.pas:6404`; **exchange** `trdos/logdupe.pas:1754`; **other** `trdos/logddx.pas:1061` |
| ALLASIANSSB | **scoring** `trdos/logstuff.pas:6404`; **exchange** `trdos/logdupe.pas:1754`; **other** `trdos/logddx.pas:1061` |
| ARI_DX | **scoring** `trdos/logstuff.pas:6470`; **multipliers** `trdos/logdupe.pas:708`; **other** `trdos/logddx.pas:296` |
| ARRL10 | **scoring** `trdos/logstuff.pas:6564`; **multipliers** `trdos/logdupe.pas:701`; **other** `trdos/logddx.pas:287` |
| BATAVIA_FT8 | **scoring** `trdos/logstuff.pas:8399`, `trdos/logstuff.pas:8428`; **exchange** `trdos/logdupe.pas:1784` |
| CALQSOPARTY | **scoring** `trdos/logstuff.pas:8749`; **exchange** `trdos/logedit.pas:2674`; **other** `trdos/logddx.pas:860` |
| COUNTYHUNTER | **exchange** `MainUnit.pas:928`, `MainUnit.pas:969`, `MainUnit.pas:2052` |
| CQMM | **scoring** `trdos/logstuff.pas:9332`; **exchange** `trdos/logdupe.pas:1644`; **multipliers** `trdos/logedit.pas:2926` |
| CQWWSSB | **scoring** `trdos/logstuff.pas:7025`; **score-summary** `trdos/postunit.pas:1166`; **ui** `MainUnit.pas:4467` |
| CUPRFCW | **scoring** `trdos/logstuff.pas:8814`; **exchange** `trdos/logedit.pas:2677`; **cabrillo-export** `trdos/postunit.pas:2992` |
| CUPRFSSB | **scoring** `trdos/logstuff.pas:8814`; **exchange** `trdos/logedit.pas:2677`; **cabrillo-export** `trdos/postunit.pas:2992` |
| EUROPEANHFC | **exchange** `trdos/logstuff.pas:5582`; **multipliers** `trdos/logdupe.pas:2257`, `trdos/logedit.pas:1499` |
| GAGARINCUP | **scoring** `trdos/logstuff.pas:9293`; **multipliers** `trdos/logedit.pas:2958`, `trdos/logedit.pas:2960` |
| IARU | **scoring** `trdos/logstuff.pas:7807`; **exchange** `trdos/logedit.pas:2711`; **ui** `MainUnit.pas:4467` |
| IOTA | **scoring** `trdos/logstuff.pas:7887`; **exchange** `trdos/logdom.pas:263`, `trdos/logstuff.pas:10430` |
| JTDX | **scoring** `trdos/logstuff.pas:8961`; **multipliers** `trdos/logdupe.pas:717`, `trdos/logedit.pas:2948` |
| KVP | **exchange** `trdos/logstuff.pas:5582`; **multipliers** `trdos/logdupe.pas:2257`, `trdos/logedit.pas:1499` |
| NZFIELDDAY | **scoring** `trdos/logstuff.pas:8029`; **exchange** `trdos/logdupe.pas:1669`; **multipliers** `trdos/logdupe.pas:2260` |
| PAQSOPARTY | **scoring** `trdos/logstuff.pas:7432`; **exchange** `trdos/logedit.pas:2676`; **other** `trdos/logddx.pas:861` |
| RADIOYOC | **scoring** `trdos/logstuff.pas:8749`; **exchange** `MainUnit.pas:8063`, `trdos/logdupe.pas:1682` |
| RU3AXMEMORIAL | **scoring** `trdos/logstuff.pas:8264`, `trdos/logstuff.pas:8301`; **exchange** `trdos/logedit.pas:2646` |
| TENTEN | **scoring** `trdos/logstuff.pas:8534`; **exchange** `trdos/logdupe.pas:1650`; **other** `trdos/logddx.pas:858` |
| UKRAINECHAMPIONSHIP | **scoring** `trdos/logstuff.pas:8931`; **exchange** `trdos/logedit.pas:2676`; **other** `trdos/logddx.pas:861` |
| VAQP | **scoring** `trdos/logstuff.pas:9547`; **exchange** `trdos/logedit.pas:2674`; **other** `trdos/logddx.pas:860` |
| YOTA | **scoring** `trdos/logstuff.pas:9621`; **exchange** `trdos/logdupe.pas:1754`; **other** `trdos/logddx.pas:1061` |
| ALLJA | **exchange** `trdos/logdupe.pas:1760`, `trdos/logdupe.pas:2075` |
| ARRLDIGI | **scoring** `trdos/logstuff.pas:6536`; **exchange** `trdos/logdupe.pas:1774` |
| BSCI | **scoring** `trdos/logstuff.pas:7765`; **multipliers** `trdos/logdupe.pas:752` |
| CUPRFDIG | **scoring** `trdos/logstuff.pas:8814`; **exchange** `trdos/logedit.pas:2677` |
| CUPURAL | **exchange** `trdos/logedit.pas:2676`; **other** `trdos/logddx.pas:861` |
| GRIDLOC | **exchange** `trdos/logdupe.pas:1663`; **other** `trdos/logddx.pas:859` |
| LABRE | **scoring** `trdos/logstuff.pas:9002`; **cabrillo-export** `trdos/postunit.pas:2978` |
| LQP | **scoring** `trdos/logstuff.pas:9169`, `trdos/logstuff.pas:9172` |
| MAKROTHEN | **scoring** `trdos/logstuff.pas:7343`; **exchange** `trdos/logdupe.pas:1784` |
| NCQSOPARTY | **scoring** `trdos/logstuff.pas:7369`, `trdos/logstuff.pas:7384` |
| OZCR_Z | **scoring** `trdos/logstuff.pas:7807`; **exchange** `trdos/logedit.pas:2416` |
| QCWA | **exchange** `trdos/logdupe.pas:1707`; **other** `trdos/logddx.pas:862` |
| QCWAGOLDEN | **exchange** `trdos/logdupe.pas:1707`; **other** `trdos/logddx.pas:862` |
| R9W_UW9WK_MEMORIAL | **scoring** `trdos/logstuff.pas:9390`; **exchange** `trdos/logdupe.pas:1688` |
| RADIOMEMORY | **scoring** `trdos/logstuff.pas:9207`; **exchange** `trdos/logdupe.pas:1747` |
| RFASCHAMPIONSHIPCW | **scoring** `trdos/logstuff.pas:9093`; **exchange** `trdos/logdupe.pas:1676` |
| RSGB_ROPOCO_CW | **scoring** `trdos/logstuff.pas:8750`; **exchange** `trdos/logdupe.pas:1795` |
| RSGB_ROPOCO_SSB | **scoring** `trdos/logstuff.pas:8750`; **exchange** `trdos/logdupe.pas:1795` |
| RUSSIANDX | **scoring** `trdos/logstuff.pas:8264`; **exchange** `trdos/logedit.pas:2646` |
| SACCW | **scoring** `trdos/logstuff.pas:8320`; **other** `trdos/logddx.pas:250` |
| SACSSB | **scoring** `trdos/logstuff.pas:8320`; **other** `trdos/logddx.pas:250` |
| SOUTHAMERICANWW | **scoring** `trdos/logstuff.pas:8446`; **exchange** `trdos/logdupe.pas:1644` |
| WAG | **scoring** `trdos/logstuff.pas:8654`; **ui** `MainUnit.pas:4126` |
| WWDIGI | **scoring** `trdos/logstuff.pas:8490`; **exchange** `trdos/logdupe.pas:1774` |
| YOUTHCHAMPIONSHIPRF | **scoring** `trdos/logstuff.pas:8746`; **exchange** `trdos/logdupe.pas:1730` |
| ALRS_UA1DZ_CUP | **scoring** `trdos/logstuff.pas:6618` |
| ARKTIKA_SPRING | **scoring** `trdos/logstuff.pas:9178` |
| ARRL160 | **scoring** `trdos/logstuff.pas:6550` |
| ARRLDXCW | **scoring** `trdos/logstuff.pas:6489` |
| ARRLDXSSB | **scoring** `trdos/logstuff.pas:6489` |
| ARRLVHFJAN | **scoring** `trdos/logstuff.pas:6581` |
| ARRLVHFJUN | **scoring** `trdos/logstuff.pas:6581` |
| ARRLVHFSEP | **scoring** `trdos/logstuff.pas:6581` |
| BALTIC | **scoring** `trdos/logstuff.pas:6689` |
| BCQP | **scoring** `trdos/logstuff.pas:7418` |
| CANADA_DAY | **scoring** `trdos/logstuff.pas:8166` |
| CANADA_WINTER | **scoring** `trdos/logstuff.pas:8166` |
| CIS | **scoring** `trdos/logstuff.pas:6730` |
| CQ160CW | **scoring** `trdos/logstuff.pas:6754` |
| CQ160SSB | **scoring** `trdos/logstuff.pas:6754` |
| CQIR | **exchange** `trdos/logedit.pas:2683` |
| CQM | **scoring** `trdos/logstuff.pas:6773` |
| CQVHF | **scoring** `trdos/logstuff.pas:6828` |
| CQWPXCW | **scoring** `trdos/logstuff.pas:6912` |
| CQWPXRTTY | **scoring** `trdos/logstuff.pas:6948` |
| CQWPXSSB | **scoring** `trdos/logstuff.pas:6912` |
| CROATIAN | **scoring** `trdos/logstuff.pas:7058` |
| DARCWAEDCCW | **scoring** `trdos/logstuff.pas:8682` |
| DARCWAEDCSSB | **scoring** `trdos/logstuff.pas:8682` |
| EUDX | **scoring** `trdos/logstuff.pas:9563` |
| EUROPEANVHF | **scoring** `trdos/logstuff.pas:7491` |
| GACWWWSACW | **scoring** `trdos/logstuff.pas:9148` |
| HADX | **scoring** `trdos/logstuff.pas:7590` |
| HELVETIA | **scoring** `trdos/logstuff.pas:7751` |
| IDAHOQSOPARTY | **scoring** `trdos/logstuff.pas:6513` |
| INTERNETSPRINT | **scoring** `trdos/logstuff.pas:8746` |
| IRTS | **scoring** `trdos/logstuff.pas:9563` |
| JALONGPREFECT | **exchange** `trdos/logdupe.pas:1903` |
| JIDXCW | **scoring** `trdos/logstuff.pas:7922` |
| JIDXSSB | **scoring** `trdos/logstuff.pas:7922` |
| KCJ | **scoring** `trdos/logstuff.pas:7995` |
| KIDSDAY | **exchange** `trdos/logdupe.pas:1639` |
| KINGOFSPAINCW | **scoring** `trdos/logstuff.pas:9274` |
| KINGOFSPAINSSB | **scoring** `trdos/logstuff.pas:9274` |
| LZDX | **scoring** `trdos/logstuff.pas:9040` |
| MWC | **scoring** `trdos/logstuff.pas:7735` |
| NRAUBALTICCW | **exchange** `trdos/logedit.pas:2682` |
| NRAUBALTICSSB | **exchange** `trdos/logedit.pas:2682` |
| OCEANIADXCW | **scoring** `trdos/logstuff.pas:8637` |
| OCEANIADXSSB | **scoring** `trdos/logstuff.pas:8637` |
| OHIOQSOPARTY | **exchange** `trdos/logedit.pas:2682` |
| OKDX | **scoring** `trdos/logstuff.pas:8054` |
| OKOMSSB | **scoring** `trdos/logstuff.pas:8100` |
| OLDNEWYEAR | **scoring** `trdos/logstuff.pas:9073` |
| OZCR_O | **exchange** `trdos/logedit.pas:2416` |
| OZHCRVHF | **scoring** `trdos/logstuff.pas:7469` |
| PCC | **scoring** `trdos/logstuff.pas:9222` |
| RADIOVHFFD | **scoring** `trdos/logstuff.pas:7311` |
| REFCW | **scoring** `trdos/logstuff.pas:9190` |
| REFSSB | **scoring** `trdos/logstuff.pas:9190` |
| REGION1FIELDDAY | **scoring** `trdos/logstuff.pas:7142` |
| REGION1FIELDDAY_RCC_CW | **scoring** `trdos/logstuff.pas:9109` |
| REGION1FIELDDAY_RCC_SSB | **scoring** `trdos/logstuff.pas:9109` |
| RTC | **scoring** `trdos/logstuff.pas:8497` |
| SALMONRUN | **scoring** `trdos/logstuff.pas:8308` |
| SASPRINT | **multipliers** `trdos/logedit.pas:2926` |
| SPDX | **scoring** `trdos/logstuff.pas:8749` |
| STEWPERRY | **scoring** `trdos/logstuff.pas:8469` |
| TESLA | **scoring** `trdos/logstuff.pas:7532` |
| TOEC | **scoring** `trdos/logstuff.pas:8544` |
| UCG | **scoring** `trdos/logstuff.pas:6912` |
| UKEI | **scoring** `trdos/logstuff.pas:7675` |
| UKRAINIAN | **scoring** `trdos/logstuff.pas:8608` |
| UNDX | **scoring** `trdos/logstuff.pas:9252` |
| WRTC | **scoring** `trdos/logstuff.pas:9401` |
| WWIH | **scoring** `trdos/logstuff.pas:7044` |
| WWL | **scoring** `trdos/logstuff.pas:8701` |
| WWPMC | **scoring** `trdos/logstuff.pas:8941` |
| XMAS | **exchange** `trdos/logdupe.pas:1876` |
| YBDX | **scoring** `trdos/logstuff.pas:8360` |
| YODX | **scoring** `trdos/logstuff.pas:8724` |
| YUDX | **scoring** `trdos/logstuff.pas:7657` |

### 6.2 Contests with no class

**4** -- every contest without a class (185 non-sentinel enum values minus
181) appears at least once in section 4 or section 5.
Contests that exist only as an operator-configured name, with no
`ContestType` at all, appear only in the shape-3 rows: **TRC Digital** (`cMyState = 'TRC'`, 5 sites) and **PGA** (`ContestTitle = 'PGA'`, 2 sites).

| contest | sites outside the factory, by category |
|---|---|
| POTA | **exchange** `MainUnit.pas:4045`, `MainUnit.pas:7145`, `trdos/logdupe.pas:1741`, `trdos/logstuff.pas:10307`; **adif-import** `MainUnit.pas:10008`, `trdos/logstuff.pas:10944`; **adif-export** `trdos/postunit.pas:2315`, `trdos/postunit.pas:2323`, `trdos/postunit.pas:2399`, `uADIF.pas:1692`; **ui** `MainUnit.pas:4526`, `uNewContest.pas:192`, `uNewContest.pas:209`; **setup** `trdos/fcontest.pas:945` |
| UA4WCHAMPIONSHIP | **scoring** `trdos/logstuff.pas:8858`; **exchange** `trdos/logstuff.pas:9975`; **ui** `uNewContest.pas:213`; **setup** `trdos/LogCfg.pas:888`, `trdos/fcontest.pas:975` |
| RSGB18 | **scoring** `trdos/logstuff.pas:8198`; **score-summary** `trdos/logedit.pas:2901`; **ui** `uNewContest.pas:196`, `uNewContest.pas:205` |
| IN7QPNE | **scoring** `trdos/logstuff.pas:7432` |

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
| `trdos/logstuff.pas:6404` | CalculateQSOPoints | `AllAsianQSOPointMethod` | ALLASIANCW, ALLASIANSSB |
| `trdos/logstuff.pas:6454` | CalculateQSOPoints | `ARCIQSOPointMethod` | ARCI |
| `trdos/logstuff.pas:6470` | CalculateQSOPoints | `ARIQSOPointMethod` | ARI_DX |
| `trdos/logstuff.pas:6489` | CalculateQSOPoints | `ARRLDXQSOPointMethod` | ARRLDXCW, ARRLDXSSB |
| `trdos/logstuff.pas:6513` | CalculateQSOPoints | `ARRLFieldDayQSOPointMethod` | ARRLFIELDDAY, IDAHOQSOPARTY, WINTERFIELDDAY |
| `trdos/logstuff.pas:6536` | CalculateQSOPoints | `ARRLDIGIQSOPointMethod` | ARRLDIGI |
| `trdos/logstuff.pas:6550` | CalculateQSOPoints | `ARRL160QSOPointMethod` | ARRL160 |
| `trdos/logstuff.pas:6564` | CalculateQSOPoints | `ARRL10QSOPointMethod` | ARRL10 |
| `trdos/logstuff.pas:6581` | CalculateQSOPoints | `ARRLVHFJUNPointMethod` | ARRLVHFJAN, ARRLVHFJUN, ARRLVHFSEP |
| `trdos/logstuff.pas:6618` | CalculateQSOPoints | `ALRSUA1DZCupQSOPointMethod` | ALRS_UA1DZ_CUP |
| `trdos/logstuff.pas:6689` | CalculateQSOPoints | `BalticQSOPointMethod` | BALTIC |
| `trdos/logstuff.pas:6719` | CalculateQSOPoints | `BWQPQSOPointMethod` | BWQP |
| `trdos/logstuff.pas:6730` | CalculateQSOPoints | `CISQSOPointMethod` | CIS |
| `trdos/logstuff.pas:6754` | CalculateQSOPoints | `CQ160QSOPointMethod` | CQ160CW, CQ160SSB |
| `trdos/logstuff.pas:6773` | CalculateQSOPoints | `CQMQSOPointMethod` | CQM |
| `trdos/logstuff.pas:6828` | CalculateQSOPoints | `CQVHFQSOPointMethod` | CQVHF |
| `trdos/logstuff.pas:6912` | CalculateQSOPoints | `CQWPXQSOPointMethod` | CQWPXCW, CQWPXSSB, UCG |
| `trdos/logstuff.pas:6948` | CalculateQSOPoints | `CQWPXRTTYQSOPointMethod` | CQWPXRTTY |
| `trdos/logstuff.pas:7025` | CalculateQSOPoints | `CQWWQSOPointMethod` | CQWWCW, CQWWSSB |
| `trdos/logstuff.pas:7044` | CalculateQSOPoints | `CQWWRTTYQSOPointMethod` | CQWWRTTY, WWIH |
| `trdos/logstuff.pas:7058` | CalculateQSOPoints | `CroatianQSOPointMethod` | CROATIAN |
| `trdos/logstuff.pas:7142` | CalculateQSOPoints | `EuropeanFieldDayQSOPointMethod` | REGION1FIELDDAY |
| `trdos/logstuff.pas:7284` | CalculateQSOPoints | `EuropeanSprintQSOPointMethod` | EUSPRINT_AUTUMN_CW, EUSPRINT_AUTUMN_SSB, EUSPRINT_SPRING_CW, EUSPRINT_SPRING_SSB |
| `trdos/logstuff.pas:7298` | CalculateQSOPoints | `FOCMarathonQSOPointMethod` | FOCMARATHON |
| `trdos/logstuff.pas:7311` | CalculateQSOPoints | `RadioVHFFDQSOPointMethod` | RADIOVHFFD |
| `trdos/logstuff.pas:7343` | CalculateQSOPoints | `MakrothenQSOPointMethod` | MAKROTHEN |
| `trdos/logstuff.pas:7369` | CalculateQSOPoints | `NCQSOPointMethod` | NCQSOPARTY |
| `trdos/logstuff.pas:7418` | CalculateQSOPoints | `BCQPQSOPointMethod` | BCQP |
| `trdos/logstuff.pas:7469` | CalculateQSOPoints | `OZHCRVHFQSOPointMethod` | OZHCRVHF |
| `trdos/logstuff.pas:7491` | CalculateQSOPoints | `EuropeanVHFQSOPointMethod` | EUROPEANVHF |
| `trdos/logstuff.pas:7532` | CalculateQSOPoints | `TeslaQSOPointMethod` | TESLA |
| `trdos/logstuff.pas:7580` | CalculateQSOPoints | `FistsQSOPointMethod` | FISTS |
| `trdos/logstuff.pas:7590` | CalculateQSOPoints | `HADXQSOPointMethod` | HADX |
| `trdos/logstuff.pas:7657` | CalculateQSOPoints | `YUDXQSOPointMethod` | YUDX |
| `trdos/logstuff.pas:7675` | CalculateQSOPoints | `UKEIQSOPointMethod` | UKEI |
| `trdos/logstuff.pas:7735` | CalculateQSOPoints | `MWCQP` | MWC |
| `trdos/logstuff.pas:7751` | CalculateQSOPoints | `HelvetiaQSOPointMethod` | HELVETIA |
| `trdos/logstuff.pas:7765` | CalculateQSOPoints | `BSCIQSOPointMethod` | BSCI |
| `trdos/logstuff.pas:7807` | CalculateQSOPoints | `IARUQSOPointMethod` | IARU, OZCR_Z |
| `trdos/logstuff.pas:7887` | CalculateQSOPoints | `IOTAQSOPointMethod` | IOTA |
| `trdos/logstuff.pas:7922` | CalculateQSOPoints | `JapanInternationalDXQSOPointMethod` | JIDXCW, JIDXSSB |
| `trdos/logstuff.pas:7995` | CalculateQSOPoints | `KCJQSOPointMethod` | KCJ |
| `trdos/logstuff.pas:8029` | CalculateQSOPoints | `NZFieldDayQSOPointMethod` | NZFIELDDAY |
| `trdos/logstuff.pas:8054` | CalculateQSOPoints | `OKDXQSOPointMethod` | OKDX |
| `trdos/logstuff.pas:8100` | CalculateQSOPoints | `OKOMSSBQSOPointMethod` | OKOMSSB |
| `trdos/logstuff.pas:8139` | CalculateQSOPoints | `RAEMQSOPointMethod` | RAEM |
| `trdos/logstuff.pas:8166` | CalculateQSOPoints | `RACQSOPointMethod` | CANADA_DAY, CANADA_WINTER |
| `trdos/logstuff.pas:8230` | CalculateQSOPoints | `RDAQSOPointMethod` | RDA |
| `trdos/logstuff.pas:8264` | CalculateQSOPoints | `RussianDXQSOPointMethod` | RU3AXMEMORIAL, RUSSIANDX |
| `trdos/logstuff.pas:8308` | CalculateQSOPoints | `SalmonRunQSOPointMethod` | SALMONRUN |
| `trdos/logstuff.pas:8320` | CalculateQSOPoints | `ScandinavianQSOPointMethod` | SACCW, SACSSB |
| `trdos/logstuff.pas:8360` | CalculateQSOPoints | `IndonesianQSOPointMethod` | YBDX |
| `trdos/logstuff.pas:8399` | CalculateQSOPoints | `YBFT8QP` | BATAVIA_FT8 |
| `trdos/logstuff.pas:8446` | CalculateQSOPoints | `SouthAmericanWWQSOPointMethod` | SOUTHAMERICANWW |
| `trdos/logstuff.pas:8469` | CalculateQSOPoints | `StewPerryQSOPointMethod` | STEWPERRY |
| `trdos/logstuff.pas:8490` | CalculateQSOPoints | `WWDigiQP` | WWDIGI |
| `trdos/logstuff.pas:8497` | CalculateQSOPoints | `RTCQSOPointMethod` | RTC |
| `trdos/logstuff.pas:8534` | CalculateQSOPoints | `TenTenQSOPointMethod` | TENTEN |
| `trdos/logstuff.pas:8544` | CalculateQSOPoints | `TOECQSOPointMethod` | TOEC |
| `trdos/logstuff.pas:8560` | CalculateQSOPoints | `UBAQSOPointMethod` | UBACW, UBASSB |
| `trdos/logstuff.pas:8608` | CalculateQSOPoints | `UkrainianQSOPointMethod` | UKRAINIAN |
| `trdos/logstuff.pas:8637` | CalculateQSOPoints | `VKZLQSOPointMethod` | OCEANIADXCW, OCEANIADXSSB |
| `trdos/logstuff.pas:8654` | CalculateQSOPoints | `WAGQSOPointMethod` | WAG |
| `trdos/logstuff.pas:8682` | CalculateQSOPoints | `WAEQSOPointMethod` | DARCWAEDCCW, DARCWAEDCSSB |
| `trdos/logstuff.pas:8701` | CalculateQSOPoints | `WWLQSOPointMethod` | WWL |
| `trdos/logstuff.pas:8724` | CalculateQSOPoints | `YODXQSOPointMethod` | YODX |
| `trdos/logstuff.pas:8746` | CalculateQSOPoints | `AlwaysOnePointPerQSO` | INTERNETSPRINT, YOUTHCHAMPIONSHIPRF |
| `trdos/logstuff.pas:8748` | CalculateQSOPoints | `TwoPointsPerQSO` | ARRLSSCW, ARRLSSSSB, COLORADOQSOPARTY, INQSOPARTY, MINNQSOPARTY, NRAUBALTICCW, NRAUBALTICSSB, XMAS |
| `trdos/logstuff.pas:8749` | CalculateQSOPoints | `ThreePointsPerQSO` | CALQSOPARTY, RADIOYOC, SPDX |
| `trdos/logstuff.pas:8750` | CalculateQSOPoints | `TenPointsPerQSO` | RSGB_ROPOCO_CW, RSGB_ROPOCO_SSB |
| `trdos/logstuff.pas:8770` | CalculateQSOPoints | `TwoPhoneThreeCW` | CQIR, SEVENQP, TENNESSEEQSOPARTY, TEXASQSOPARTY |
| `trdos/logstuff.pas:8780` | CalculateQSOPoints | `OnePhoneTwoCW` | ArizonaQsoParty, FLORIDAQSOPARTY, KVP, MICHQSOPARTY, MOQSOPARTY, NEWENGLANDQSO, NYQP, OHIOQSOPARTY, QCWA, QCWAGOLDEN, WISCONSINQSOPARTY |
| `trdos/logstuff.pas:8814` | CalculateQSOPoints | `CupRFMethod` | CUPRFCW, CUPRFDIG, CUPRFSSB |
| `trdos/logstuff.pas:8909` | CalculateQSOPoints | `ChampionshipRFMethod` | RFCHAMPIONSHIPCW, RFCHAMPIONSHIPSSB |
| `trdos/logstuff.pas:8931` | CalculateQSOPoints | `ChampionshipUkrMethod` | UKRAINECHAMPIONSHIP |
| `trdos/logstuff.pas:8941` | CalculateQSOPoints | `WWPMCQSOPointMethod` | WWPMC |
| `trdos/logstuff.pas:8961` | CalculateQSOPoints | `JTDXQSOPointMethod` | JTDX |
| `trdos/logstuff.pas:9002` | CalculateQSOPoints | `LABREQSOPointMethod` | LABRE |
| `trdos/logstuff.pas:9040` | CalculateQSOPoints | `LZDXQSOPointMethod` | LZDX |
| `trdos/logstuff.pas:9073` | CalculateQSOPoints | `OldNewYearQSOPointMethod` | OLDNEWYEAR |
| `trdos/logstuff.pas:9093` | CalculateQSOPoints | `ChampionshipRFASMethod` | RFASCHAMPIONSHIPCW |
| `trdos/logstuff.pas:9109` | CalculateQSOPoints | `RegionOneFieldDayRCCQSOPointMethod` | REGION1FIELDDAY_RCC_CW, REGION1FIELDDAY_RCC_SSB |
| `trdos/logstuff.pas:9148` | CalculateQSOPoints | `GACWWWSACWQSOPointMethod` | GACWWWSACW |
| `trdos/logstuff.pas:9169` | CalculateQSOPoints | `LQPQSOPointMethod` | LQP |
| `trdos/logstuff.pas:9178` | CalculateQSOPoints | `ArktikaSpringQSOPointMethod` | ARKTIKA_SPRING |
| `trdos/logstuff.pas:9190` | CalculateQSOPoints | `REFQSOPointMethod` | REFCW, REFSSB |
| `trdos/logstuff.pas:9207` | CalculateQSOPoints | `RadioMemoryQSOPointMethod` | RADIOMEMORY |
| `trdos/logstuff.pas:9222` | CalculateQSOPoints | `PCCQSOPointMethod` | PCC |
| `trdos/logstuff.pas:9252` | CalculateQSOPoints | `UNDXQSOPointMethod` | UNDX |
| `trdos/logstuff.pas:9274` | CalculateQSOPoints | `KingOfSpainQSOPointMethod` | KINGOFSPAINCW, KINGOFSPAINSSB |
| `trdos/logstuff.pas:9293` | CalculateQSOPoints | `GagarinCupQSOPointMethod` | GAGARINCUP |
| `trdos/logstuff.pas:9332` | CalculateQSOPoints | `CQMMQSOPointMethod` | CQMM |
| `trdos/logstuff.pas:9390` | CalculateQSOPoints | `R9WUW9WKMemorialQSOPointMethod` | R9W_UW9WK_MEMORIAL |
| `trdos/logstuff.pas:9401` | CalculateQSOPoints | `WRTCQSOPointMethod` | WRTC |
| `trdos/logstuff.pas:9547` | CalculateQSOPoints | `VAQSOPOINTMETHOD` | VAQP |
| `trdos/logstuff.pas:9563` | CalculateQSOPoints | `EUDXQSOPOINTMETHOD` | EUDX, IRTS |
| `trdos/logstuff.pas:9621` | CalculateQSOPoints | `YOTAQSOPointMethod` | YOTA |

### 9.2 Class traits the engine contradicts (D8)

**661** trait overrides checked (`GetQSOPointMethod`, `GetExchangeKind`,
`GetDomesticMultiplierType`, `GetDXMultiplierType`), each against the value the
ENGINE uses -- the last `FoundContest` arm assignment for the contest, else its
`ContestsArray` row. **0** disagree or could not be read:

| contest | getter | class says | engine uses | row | FoundContest arms |
|---|---|---|---|---|---|

### 9.3 Contest identity: what the class says, what the exporters emit (D9)

- **139** contests have a blank `ContestsArray` `ADIFName` (excluding
  GENERALQSO, POTA, which write no `CONTEST_ID`), so their exported id is the
  `ContestTypeSA` spelling and import cannot resolve it; **137** of them are
  registered: ALLJA, ARCI, ARI_DX, ARRL10, ARRLDIGI, ARRL160, ARRLDXCW, ARRLDXSSB, ARRLSSCW, ARRLSSSSB, ARRLVHFSEP, BALTIC, BWQP, CIS, COUNTYHUNTER, CQ160CW, CQ160SSB, CQM, CQVHF, CQWPXCW, CQWPXSSB, CQWPXRTTY, CQWWCW, CQWWSSB, CROATIAN, CUPRFCW, CUPRFSSB, CUPRFDIG, CUPURAL, EUSPRINT_SPRING_CW, EUROPEANVHF, TESLA, FISTS, FOCMARATHON, GACWWWSACW, GAGARINCUP, GRIDLOC, YUDX, UKEI, HELVETIA, IARU, INTERNETSPRINT, IOTA, JIDXCW, JIDXSSB, JALONGPREFECT, JTDX, KCJ, KIDSDAY, KVP, LABRE, LZDX, MARCONIMEMORIAL, MINITEST, NAQSOCW, NAQSOSSB, NAQSORTTY, NASPRINTCW, NASPRINTRTTY, NCCCSPRINT, NEWENGLANDQSO, NRAUBALTICCW, NRAUBALTICSSB, OCEANIADXCW, OCEANIADXSSB, OKDX, OLDNEWYEAR, OZCR_O, OZCR_Z, PACC, QCWA, QCWAGOLDEN, CANADA_WINTER, RADIOVHFFD, RAEM, RDA, REGION1FIELDDAY, REGION1FIELDDAY_RCC_CW, REGION1FIELDDAY_RCC_SSB, RFCHAMPIONSHIPCW, RFCHAMPIONSHIPSSB, RFASCHAMPIONSHIPCW, RUSSIANDX, SACCW, YBDX, SACSSB, SOUTHAMERICANWW, SPDX, TENTEN, TOEC, UBACW, UBASSB, UCG, UKRAINECHAMPIONSHIP, UKRAINIAN, DARCWAEDCCW, DARCWAEDCSSB, DARCXMAS, WAG, WWL, WWPMC, XMAS, YODX, YOUTHCHAMPIONSHIPRF, RU3AXMEMORIAL, LQP, ARKTIKA_SPRING, UNDX, KINGOFSPAINCW, KINGOFSPAINSSB, WRTC, R9W_UW9WK_MEMORIAL, PCC, RADIOMEMORY, DARC10M, REFCW, REFSSB, BSCI, CQMM, SASPRINT, OZHCRVHF, CANADA_DAY, CQWWRTTY, MAKROTHEN, EUSPRINT_SPRING_SSB, EUSPRINT_AUTUMN_CW, EUSPRINT_AUTUMN_SSB, CQIR, WWIH, ALRS_UA1DZ_CUP, RADIOYOC, OKOMSSB, BATAVIA_FT8, WWDIGI, MWC, IRTS, EUDX.
- 362 literal identity getters (`GetCabrilloName`, `GetADIFContestId`) were
  compared with what the exporters emit; **1** differ:

| contest | format | class says | exporter emits |
|---|---|---|---|
| GENERALQSO | ADIF | `GENERAL QSO` | `` |

### 9.4 Shape 1 against shapes 1 + 2, per file (section 8.2)

Shape 1 (the global `Contest` only): **23** in 8 files. Shapes 1 + 2 (testing
the VALUE rather than the operand): **30** in 10 files. A `case` counts
once here; `Lint-ContestNameTests` counts its contest-naming arms instead (section 9.5).

| file | shape 1 | shapes 1 + 2 |
|---|---:|---:|
| `MainUnit.pas` | 7 | **8** |
| `trdos/LogCfg.pas` | 1 | 1 |
| `trdos/fcontest.pas` | 1 | 1 |
| `trdos/logedit.pas` | 6 | 6 |
| `trdos/logstuff.pas` | 3 | 3 |
| `trdos/logsubs2.pas` | 2 | 2 |
| `trdos/logwind.pas` | 1 | 1 |
| `trdos/postunit.pas` | 2 | **5** |
| `uADIF.pas` | -- | **1** |
| `uNewContest.pas` | -- | **2** |

### 9.5 Contest-naming `case` arms (section 8.3)

**10** arms across 6 cases.

| case | routine | shape | contest-naming arms |
|---|---|---|---:|
| `uNewContest.pas:204` | ClasslessPrompts | 2 | 3 |
| `trdos/fcontest.pas:898` | FoundContest | 1 | 2 |
| `uNewContest.pas:191` | ClasslessPrompts | 2 | 2 |
| `MainUnit.pas:10007` | ApplyClasslessADIFImport | 2 | 1 |
| `trdos/LogCfg.pas:885` | tSetupExchangeNumbers | 1 | 1 |
| `trdos/postunit.pas:2398` | EmitContestSpecificTailForExport | 2 | 1 |
