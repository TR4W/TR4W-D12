# What a contest owns -- DESIGN (nothing built)

**Status:** decision document, rewritten 2026-10-01 at `c2efdf18` to NY4I's
ruling of that day. The ruling **replaced** the strategy-and-registry model that
this document and [`QSO_POINT_METHOD_DESIGN.md`](QSO_POINT_METHOD_DESIGN.md)
(now SUPERSEDED) described. Its two still-live findings are restated in §7, so
this document stands alone. Owner: `contest-factory`, with `contest-scoring`,
`file-formats`, `log-database` and `settings-config`. Counts not measured here
cite the generated inventory,
[`CONTEST_RULES_OUTSIDE_FACTORY.md`](CONTEST_RULES_OUTSIDE_FACTORY.md).

**NY4I's question** was *what does a contest OWN, and what does it PICK from a
shared set?* **His answer, 2026-10-01:** it owns its rules outright and picks
nothing.

> *"if I have a field day class, all I really need to is call a function in the
> class that provides the qso info (so we see the mode, call, band, grid, etc)
> and the class returns the points."*

---

## 0. The model in ten lines

1. **A contest class OWNS ITS RULES**, as virtuals on `TContestBase`: scoring,
   exchange parsing and validation, ADIF import interpretation, ADIF and
   Cabrillo export, setup, total score and bonuses, and anything else
   contest-specific.
2. **NOTHING IS PICKED FROM A SHARED SET**, so there are no strategy objects and
   no registries for point methods, exchange, multiplier or initial-exchange
   kinds. Those enums were the legacy engine's way to reuse arms of one `case`.
   They have no job in a factory, so they die with the engine.
3. **Family bases** are for contests that genuinely are one family under one rule
   (`TContestStateQSOPartyBase`, the CW/SSB pairs, NRAU-Baltic).
4. **A new contest that resembles another starts as a COPY** of that class and
   owns it. That is ownership, not drift (§1.4).
5. **Helpers only for genuinely shared computation.** The class's own code calls
   them, and a helper is never selected, registered or named by an enum (§1.3).
6. **The scoring seam already has the target shape:** the four `QSO POINTS ...`
   overrides first, then the class, then the legacy case for a classless
   contest (§2).
7. **`QSO POINT METHOD` works for classless contests until the migration ends,
   then RETIRES** to `uCFG.RETIRED_COMMANDS`. The four overrides stay (§7).
8. **ADIF import is generic first.** A contest-blind importer captures the
   values, then the class interprets them after the whole record is read (§3.2).
9. **`FoundContest` reads the class**, which fills a defaults object and never
   writes a global (§4). Total score is `CombineScore` + `BonusPoints` (§5).
10. **"A contest has moved" is checkable** (§8.3). POTA is a class (§6).

---

## 1. The ownership model

### 1.1 Who owns what

**A contest's rules belong to its class and to nothing else.** The test from
`uContestStateQSOPartyBase`'s header still decides the cases that look shared:
*"could a sponsor change this next year without it being a different kind of
contest?"* If yes, the class owns it, and that covers nearly everything. What
remains is not a rule at all. It is arithmetic, or a fact about a file format
(how a Maidenhead grid becomes a distance, or how an ADIF tag is spelled). That
lives in a helper or in the format's own unit.

### 1.2 What a contest owns, and the seam for each

| concern | today | seam on the class (new unless marked) |
|---|---|---|
| per-QSO points | the class, for every registered contest (`logstuff.CalculateQSOPoints` hands over and `Exit`s) | `CalculateQSOPoints` (**existing -- this is the shape**) |
| identity: enum, display/friendly/Cabrillo name, ADIF id and former ids, WA7BNM, QRZ.RU, e-mail | the class, but **five exporters read `ContestsArray` directly** (inventory §1.4 fact 4, D9) | existing properties. The fix is making the exporters ask |
| sponsor parameters: county-line max, legal classes, host state, mult by band/mode, WARC allowed, dupe policy, off-time minimum, max contest dates | split across the class, `ContestsBooleanArray`, `FoundContest` arms and `postunit` | one property per fact |
| exchange parsing and validation | `ProcessExchange`'s `case ActiveExchange of`; the class's `ValidateClass` / `ValidateDXQTH` / `ValidateQTHCount` | `ParseReceivedExchange`, plus the existing validators |
| ADIF export: sent exchange and contest fields | `uADIFExchange` (the class when `FormatsExchange`); `postunit.EmitContestSpecificTailForExport` | `FormatADIFSentExchange` (existing), `EmitADIFContestFields` |
| ADIF import interpretation | `MainUnit.ApplyContestSpecificADIFTail`, `ProcessImportedSRX_String`, the `APP_N1MM_EXCHANGE1` arm of `uADIF.ApplyADIFFieldsToExchange` | `ApplyADIFImport` (§3.2) |
| Cabrillo: QSO columns, line layout, headers, mode string | `uCabrilloExchange` (the class when `FormatsExchange`); `postunit` | `FormatCabrillo...Exchange`, `CabrilloQSOLineFormat` (existing); `CabrilloHeaders`, `CabrilloModeString` |
| session setup: memories, settings defaults, domestic file and countries, band/mode | `FoundContest`'s 104 arms (inventory §5) | `DescribeSession` (§4) |
| total score and bonuses | `logedit.TotalScore`, plus D10's three places | `CombineScore`, `BonusPoints` (§5) |
| multipliers and dupes | `logdupe`, `logedit`, `uMults` | contest virtuals, named as each moves (`MultiplierValue`, `MarksDupes`, ...) |
| summary sheet, totals window, new-contest prompts | `postunit`, `uTotal`, `uNewContest` | `SummarySheetMultColumns`, `TotalsDisplay`, `NewContestPrompts` |

The seam names on the right are the generator's
(`tools/contest-rules-inventory/judgements.py`), with two deliberate
exceptions:

- **`DescribeSession` replaces its `ConfigureSession`.** The class fills a
  defaults object and does not configure anything.
- **`CombineScore` + `BonusPoints` replace its `CalculateTotalScore`.** The
  split keeps a bonus from being applied per QSO.

When those seams are built, the generator should take this document's names.
**A virtual is added when its responsibility actually moves, not in advance**
(`ADDING_A_CONTEST.md` §6).

**The class never reads a global.** The factory pushes the station in through
`TStationContext`, which grows a field when the first contest needs one. That
is what lets a unit test construct a contest and ask it a question without
booting TR4W.

### 1.3 A helper is not a strategy

The difference is who decides.

- **A helper is called BY the class's own code**, with the contest's own
  numbers, and the class can stop calling it at any time. It holds no rule
  identity and is never selected by an enum, a setting or a registry.
- **A strategy is chosen FOR the class.** That is what the ruling removes.

**The worked example is already live.** Several contests score by the distance
between the worked station's grid and ours. `uContestARRLDigi` calls
`LOGGRID.GetDistanceBetweenGrids` and then computes its own score from the
result. Its header records why it calls that helper rather than
`uGridDistance.GridHaversineKm`: the two differ numerically, and the contest
has to reproduce the arm it replaced. Choosing between two helpers is part of
the contest's rule.

**A helper is created only once real duplication appears**, which NY4I does not
expect per contest. This is `ADDING_A_CONTEST.md` step 2's *"lift first,
consolidate after"*. The largest candidates are `logstuff`'s
`Process...Exchange` routines, lifted into leaf units for `ParseReceivedExchange`
to call. **A helper reads no globals either**, so a TRDOS helper is lifted
before a class may call it. The precedent is `MarineOrAirMobileStation`, moved
to `uCallSignRoutines` for Virginia.

### 1.4 A copied class is ownership, not drift

A future contest that resembles an existing one (NY4I's example is a QSO party
like Florida's) **starts as a copy of that class, and the copy is entirely its
own.** Do not merge the copies, and do not extract a base for them because they
look alike.

**This does not break CLAUDE.md's "do not duplicate code" rule; it is outside
it.** That rule is about one rule held in two places, where a fix lands in one
copy and the other silently keeps the bug. Two contest classes are two rules
from two sponsors that happen to start out equal. When one sponsor changes its
rules, only that class should change. Merging them would rebuild the shared-arm
coupling the factory exists to remove.

A copied class says so in its header: what it was copied from, and that the
copy is deliberate. `ADDING_A_CONTEST.md` §1 already requires this ("say so in
the file -- otherwise somebody will extract it").

### 1.5 Families, and what `TContestFixedPoints` becomes

A base class is justified only for **a family**: contests under one rule, where
a rule change reaches every member by definition.

```
TContestBase
+-- TContestStateQSOPartyBase        county line, host state (abstract)
|   +-- one class per single-state party
+-- TContestARRLDXBase    -> CW, Phone
+-- TContestARRLSSBase    -> CW, SSB      (reparented off TContestFixedPoints)
+-- TContestCQWWBase      -> CW, SSB
+-- TContestCQWPXBase     -> CW, SSB
+-- TContestNASprintBase  -> CW, RTTY     new; both are TContestFixedPoints today
+-- TContestNRAUBalticBase -> CW, SSB     NY4I's ruling
+-- TContestARRLFieldDay, TContestWinterFieldDay    no shared base -- NY4I's ruling
+-- TContestSprintSSB                     its own contest, NOT an NA Sprint -- NY4I's ruling
+-- TContestPOTA, TContestGeneralQSO      section 6
+-- every other contest, directly
```

- **Every other two-mode pair follows the NRAU ruling.** That covers JIDX, All
  Asian, SAC, UBA, RSGB RoPoCo, King of Spain, DARC WAEDC, RF Championship,
  CQ 160, NAQP's three modes, the EU Sprints and Cup RF. A `Base` holds the
  contest, and each mode class states only its identity. **One class per
  `ContestType` and one `RegisterContest` per unit still hold** (Q7).
- **The multi-state parties (7QP, NEQP, IN7QPNE) stay open**, for the reason
  `uContestStateQSOPartyBase`'s header gives.

**`TContestFixedPoints` and `FixedModePoints` -- recommendation (Q12):**

- **Keep `FixedModePoints` as a helper.** It is a pure function of the mode and
  three numbers the contest supplies, which is exactly the §1.3 shape. 16 units
  call it (`rg -l "FixedModePoints\(" tr4w/src/contestFactory/*.pas`). The
  three numbers *are* the contest's rule.
- **Retire the `TContestFixedPoints` base.** It is a mechanism, not a family,
  and it spends the one base class Object Pascal gives. That is why Florida
  calls the function instead. Its 25 subclasses
  (`rg -l "class\(TContestFixedPoints\)"`) move to `TContestBase` or to their
  new family base, and each states its numbers in its own
  `CalculateQSOPoints`. Do it **in the commit that introduces each family
  base**, not as a sweep.
- **A rule that does not fit three numbers gets its own body.** Field Day is the
  recorded example: FM scores with phone, and digital scores two. Do not widen
  the helper to absorb such a rule.

---

## 2. Scoring -- the seam is already the target

`logstuff.CalculateQSOPoints` does exactly what the ruling describes. Read it
from `procedure CalculateQSOPoints(var RXData` downward:

1. The four `QSO POINTS DOMESTIC/DX CW/PHONE` settings each apply when they
   match the QSO, and each falls through when it does not. They are generic
   configuration, so they run **before** the class and a class cannot silently
   ignore them. **Kept.**
2. `if ActiveContest(Contest) <> nil` -- the class scores and the routine
   `Exit`s.
3. Otherwise `case ActiveQSOPointMethod of`, which is the legacy engine.

So `TContestBase.CalculateQSOPoints` is **the permanent seam**. The superseded
design would have deleted it. Since phase F, a contest with a class has ignored
`QSO POINT METHOD` for points, and under this ruling that is correct rather than
a gap.

**What is left on scoring:**

- **The legacy case is deleted at the endpoint**, together with the setting
  (§7.1, Q11). Until then it serves classless contests.
- **Ten sites outside the case still read `ActiveQSOPointMethod`**:
  `rg -n -i "ActiveQSOPointMethod" tr4w/src --glob '*.pas'`, dropping
  comments and `backup/` by eye. Each moves into the contest:

  | site | moves to |
  |---|---|
  | dupe marking, `logsubs2` (`AlwaysOnePointPerQSO`) | the contest's dupe-policy property (`MarksDupes`). Internet Sprint and Youth Championship RF reach it today |
  | exchange parsing, `logstuff` x3 (RAC, PCC, Arktika) and `zonecont` (RussianDX) | that contest's `ParseReceivedExchange` / initial exchange |
  | total-score formulas, `logedit` x5 (WAE, CupRF, ALRS, ChampionshipRF, OZHCR) | that contest's `CombineScore` (§5) |

  **This is a behaviour change for an operator who overrides today:** their
  `QSO POINT METHOD` currently reaches these sites even for a registered
  contest. Once a site moves, it no longer does.
- **13 legacy arms write a field other than `QSOPoints`**: `InhibitMults`,
  `DomMultQTH`, `DomesticMult`, `ZoneMult`, `Prefix` or `DXQTH`. A class that
  replaces one of them must write the same fields, so its proof compares the
  whole `ContestExchange`, not only the points.

---

## 3. The exchange -- one class holds every direction

### 3.1 Export, parse and import together

Today export is mostly keyed by exchange kind and import mostly by contest, and
only `test-adif-roundtrip.sh` (13 contests) ties the two together. Both
round-trip defects recorded in `ApplyContestSpecificADIFTail`'s comments were
one field the two directions disagreed about:

- the `59 8` QTH for IARU and CQ WW, where export prepends the RST and import
  did not strip it;
- an absent `ARRL_SECT` erasing the Winter Field Day section.

**Under ownership, export, parse and import interpretation are methods of ONE
class, so the agreement lives in one file.** A round-trip unit test per class
pins it: importing the class's own export returns the QSO's received fields.
The class is a leaf, so the test needs no booted program.

**Tag spellings are ADIF's, not the contest's.** The generic ADIF layer reads
and writes standard tags such as `ARRL_SECT`, `CHECK`, `PRECEDENCE` and `SIG`,
in both directions. The class decides what a value **means** for its contest.

**Validation is the contest's.** The existing protected helpers
(`ValidateCountAndLetterClass`, `ValidateDXQTHAllowing`) are §1.3 helpers. The
class supplies the legal values and calls them.

### 3.2 ADIF import: generic first, then the class

NY4I, 2026-10-01: a generic, contest-blind importer maps the standard tags and
**captures** the contest-dependent values. Then, **after the whole record has
been read**, the contest named by its `CONTEST_ID`
(`FindContestByADIFContestId`) interprets them through `ApplyADIFImport`. The
importer names no contest. No Cabrillo importer exists, and none is designed
here.

**`APP_N1MM_EXCHANGE1` is why the interpretation must wait for the whole
record.** `uADIF.ApplyADIFFieldsToExchange` interprets that tag per contest
today: class for the Field Days, power for FOC Marathon. That arm is
**order-dependent**, because `exch.ceContest` is set only when the loop reaches
`CONTEST_ID`, and ADIF fixes no field order. A record with the tag ahead of
`CONTEST_ID` is misread. Interpreting after the whole record is read fixes this
structurally. Pin it with a test in **both** tag orders. NY4I, 2026-10-01: not
fixed in place. It is done here, the right way (M5).

**Where today's pieces go:**

| today | becomes |
|---|---|
| `ApplyContestSpecificADIFTail` arms | `ApplyADIFImport` of each contest the arm names |
| its `else` (grid kinds, then the domestic QTH, then raw SRX) | the classless fallback while migrating; each contest that moves takes its own share |
| `ProcessImportedSRX_String` (Field Day) | the Field Day classes' `ApplyADIFImport` calling their own `ParseReceivedExchange` on the SRX text |
| `logstuff.ResolvePOTAParkFromADIF` (D5's fix, `3f9e3f28`) | POTA's `ApplyADIFImport` |
| `EmitContestSpecificTailForExport` arms | `EmitADIFContestFields` of each contest named. The no-op arm (D6) is deleted |
| the `Contest` tests inside the `uCabrilloExchange` / `uADIFExchange` arms (FOC, JIDX, PACC/SPDX, CQVHF, PCC, ...) | that contest's own formatter |
| `FormatsExchange` | stays as the per-contest opt-in while migrating. It is deleted at the endpoint, when every contest formats its own |
| `logddx` per-contest sample exchanges | the contest's `SampleExchange`, so the simulator exercises its parser |

**Arm boundaries are not contest boundaries.** For example, `ARRL160, CQ160CW,
CQ160SSB, UBACW, UBASSB` is a single import arm. Each contest the arm names gets
its own copy of the arm's body (§1.4), and the arm goes when the last of them
has moved.

---

## 4. Setup -- `FoundContest` reads the class

### 4.1 Today

`FoundContest` (`fcontest.pas`) does three things:

1. It assigns the seven `Active*` globals from `ContestsArray[Contest]`, and the
   by-band and by-mode flags from `ContestsBooleanArray`.
2. For a QSO party, it picks the in-state or out-of-state domestic file through
   `FoundMyStateInDomFile`.
3. It runs `case Contest of`: **104 arms naming 131 contests** (inventory §5).
   These assign `Active*`, `Settings.*`, CQ memories, domestic files and band.

The operator's `.cfg` rows are applied **after** that, by
`uSettingsEffects.ApplyMultiplierToken`. "Operator beats contest" is enforced
only by that ordering.

### 4.2 Target

`FoundContest`'s head asks `ContestDefinition(Contest)` for the contest object.
A classless contest gets a plain `TContestBase` that reads `ContestsArray`;
`uContestRegistry` already builds exactly that privately (`NewContestObject`),
so expose it rather than write a second one. The head pushes the station in
(including `InHostState`), the class's `DescribeSession` fills a
`TSessionDefaults`, and FCONTEST's `ApplySessionDefaults` is the only writer.
**Defaults are data, and the class never touches a global.**

- **The `Active*` globals are transitional.** While legacy code still reads them,
  the setup head writes them from the class's trait getters (`GetExchangeKind`,
  `GetQSOPointMethod`, the multiplier types) rather than from the array. That
  makes the class the single source, and nothing persists them or reads them
  back to decide anything. **The traits are not picks.** They are the class
  describing itself to the legacy engine in that engine's vocabulary. Each one
  is deleted once the last legacy reader of its global is gone.
- **In-state / out-of-state moves onto the class** as
  `TStationContext.InHostState`. It is computed by `uContestFactory`, the one
  unit allowed to read globals, from `FoundMyStateInDomFile`. That resolves
  **D8's six conditional disagreements**, which no single trait value could
  express.
- **D8's one unconditional disagreement is a decision, not a refactor:** Field
  Day's DX multiplier (Q1).
- **`ContestsArray` follows the class.** It is `array[ContestType]`, so rows
  cannot be removed one contest at a time. It goes at the endpoint (M10).
- **Today's arms overwrite the CQ memories and `CqExchangeCw` on every
  `FoundContest`.** Under `TSessionDefaults` those become defaults. Whether an
  operator-edited memory survives re-selecting the contest is Q9.

---

## 5. End of contest -- the final-score seam

There is **one** computation, `logedit.TotalScore`, and every consumer reads it:
the score display (`logwind`), the summary sheet and Cabrillo `CLAIMED-SCORE`
(`postunit`), the XML score report (`logsubs2`) and `uGetScores`
(`git ls-files 'tr4w/src/*.pas' | xargs rg -n -i -w "TotalScore"`). So the seam
goes in exactly one place, and nothing downstream changes.

```pascal
(* WHAT THE SCORE IS COMPUTED FROM. Filled by the application, which has the
   log; the contest never sees the log. A field arrives with the first contest
   that needs it, as in TStationContext. *)
TScoreTotals = record
   QSOPoints: longint;
   QTCPoints: longint;
   Mults: TMultTotals;              (* by band, mode and multiplier kind *)
   QSOsByBandMode: TQSOTotals;
   CategoryPower: string;
   BonusStationsWorked: integer;    (* Missouri; Salmon Run if implemented *)
   PeakHourCount: integer;          (* Missouri *)
end;

TContestBase = class
public
   (* THE SPONSOR'S FORMULA. The base: points times the sum of all multipliers,
      or points alone with no multipliers -- TotalScore's general case. *)
   function CombineScore(const aTotals: TScoreTotals): longint; virtual;

   (* APPLIED ONCE, AFTER CombineScore, NEVER PER QSO. The base adds nothing. *)
   function BonusPoints(const aTotals: TScoreTotals): longint; virtual;

   (* WHICH CALLS ARE BONUS STATIONS -- data, not a test. The application
      counts them; the contest prices them. *)
   property BonusStations: TContestIdList read GetBonusStations;
end;
```

This is `ADDING_A_CONTEST.md` §6's reserved `calculateTotalScore`, split in two
so that a bonus cannot be applied per QSO. **Final score = `CombineScore` +
`BonusPoints`.**

| today's `TotalScore` arm | goes to |
|---|---|
| ARRL Field Day (points only); Winter Field Day (band-mode mults x points x power factor) | `CombineScore` of each |
| WAE weighted mults; Cup RF / ALRS / RF Championship / Ukraine Championship / OZHCR `points + N x mults`; RSGB18; CUPURAL | `CombineScore` of each. Five of these read `ActiveQSOPointMethod` today (§2) |
| FISTS "mults don't work" short-circuit | `CombineScore` of FISTS |
| Missouri W0MA/K0GQ +100 each, plus peak hour | `BonusStations` + `BonusPoints` |
| Salmon Run W7DX (unimplemented, D10) | `BonusPoints`, **when NY4I says so** (Q5) |
| North Carolina +50 callsigns (D3) | **not a bonus.** The sponsor's current rules have none; it dies with the legacy arm |

**Bonuses are data plus a count, never a log query.** `ValidateQTHCount`'s
comment states why: a contest handed a list is one step from being handed the
log. Once it has the log, the order in which callers invoke it would change
what a log scores.

**The corpus sees this.** `golden_diff.py` keeps `CLAIMED-SCORE:`
(`ADDING_A_CONTEST.md` §4, corrected 2026-10-01). That value is arithmetic over
**stored** points and recomputed multipliers, so a `CombineScore` / `BonusPoints`
move IS visible for the 13 sets. A per-QSO point change still is not. None of
the three bonus contests has a corpus set (`ls tr4w/test/corpus`), so their
bonuses need a unit test over a hand-built `TScoreTotals` plus a
`BENCH_QUEUE.md` item.

---

## 6. POTA is a class

`POTA` appears as a word on 99 lines of `tr4w/src`
(`git ls-files 'tr4w/src/*.pas' | xargs rg -i -w POTA | wc -l`, 2026-10-01),
across `logstuff`, `MainUnit`, `postunit`, `uADIF`, `fcontest`, `uNewContest`,
the schema and the repository. It already has a `ContestType`, a `ContestsArray`
row, a setup arm and an ADIF tail.

**Recommendation: `TContestPOTA : TContestBase`** (Q6). The precedent is
`GENERALQSO`, which is registered without being a contest. A parallel
`TActivity` hierarchy would be a second identity space beside `ceContest`, the
same second-definition drift `ContestsArray` and `RadioParametersArray`
demonstrated. POTA's rules map onto the seams above:

- `SIG` / `SIG_INFO` / `POTA_REF` interpretation is its `ApplyADIFImport`, and
  its export is `EmitADIFContestFields`;
- the n-fer limit is `ValidateQTHCount`, and the n-fer is already one contact
  stored in N rows, like a county line;
- dupes allowed is its dupe-policy property;
- it emits no Cabrillo headers.

Introduce a `TActivityBase` only when a second activity (SOTA, WWFF) arrives and
shows what is genuinely shared.

---

## 7. The settings, and the two findings still live

### 7.1 `QSO POINT METHOD` retires; the four overrides stay

- **`QSO POINT METHOD` keeps working for classless contests until the migration
  ends.** A registered contest already ignores it for points (§2). At the
  endpoint it moves into `uCFG.RETIRED_COMMANDS`: accepted, logged once, and
  ignored. An old `.cfg` that names it then neither breaks nor raises the
  "invalid statement" dialog.
- **The four `QSO POINTS DOMESTIC/DX CW/PHONE` overrides stay.** They are
  generic, and they run before the class.
- **The other six sibling settings select from shared sets the same way.** These
  are `EXCHANGE RECEIVED`, the four multiplier commands and `INITIAL EXCHANGE`.
  Each stops affecting a contest once that rule moves into its class. Whether
  they retire with `QSO POINT METHOD` is Q4.

### 7.2 FINDING -- the spelling table selects the wrong method

This is the superseded design's Finding 1, re-verified 2026-10-01 against
`VC.pas`. `QSOPointMethodArray` is `array[QSOPointMethodType] of string`, and
`uSettingsEffects.ApplyMultiplierToken` assigns the **position** of the matching
spelling (`aTarget^ := Byte(i)`). The compiler checks the array's length, not
its order. `'LABRE'` sits at position 81 while `LABREQSOPointMethod` is ordinal
38, so entries 38-81 are shifted by one, and positions 124 and 125 are swapped.
That is **46 of 133 spellings**, and `OldNewYear` is unreachable by name
(`'ONY'` appears twice). The D7 tree has the same rotation, so this is **not a
port regression**.

| the operator writes | the method actually selected |
|---|---|
| `ONE PHONE TWO CW` | `TwoPhoneFourCW` |
| `ONE POINT PER QSO` | `AlwaysOnePointPerQSO` -- **dupes stop being marked**, even for a registered contest (§2) |
| `TWO POINTS PER QSO` | `OnePointPerQSO` |
| `SALMON RUN` / `STEW PERRY` / `LABRE` | `RDAQSOPointMethod` / `SLFivePointQSOMethod` / `RadioVHFFDQSOPointMethod` |

**It reaches a shipped file.** `target/dom/Idaho QSO Party.cfg` is a contest
configured as `CONTEST = NEQP` (which has no class) with
`QSO POINT METHOD = ONE PHONE TWO CW`. That selects `TwoPhoneFourCW`, whose arm
scores 4 per CW QSO and 2 per phone, where 2 and 1 were asked for, so every
claimed score doubles. **Found by reading the table, the token loop and the arm;
not reproduced on a run.** A unit test pinning the Idaho spelling would confirm
it.

**RULED (Q2), NY4I 2026-10-01: NOT fixed in place.** *"Today is of no consequence.
This is built for the end result not anything interim."* The rotated table belongs
to a setting that is retired at M10, and Idaho's mis-score belongs to a contest
that should not be borrowing NEQP at all. The end state is an **Idaho QSO Party
class** owning its own rules -- 1 point phone, 2 points CW or digital, county line
at most 2 (NY4I, 2026-10-01) -- at which point its `.cfg` no longer names a point
method and the table cannot touch it.

It changes what an existing `.cfg` selects, but the change is towards what the
operator wrote.

### 7.3 FINDING -- every corpus log stores all seven settings as sentinels

Re-measured 2026-10-01:

```bash
python -c "import sqlite3,glob; [print(f, sorted(set(sqlite3.connect(f).execute(\"select command,value,source from config where command in ('QSO POINT METHOD','EXCHANGE RECEIVED','DX MULTIPLIER','DOMESTIC MULTIPLIER','ZONE MULTIPLIER','PREFIX MULTIPLIER','INITIAL EXCHANGE')\")))) for f in sorted(glob.glob('tr4w/test/corpus/*/log.db'))]"
```

All 13 answer `NONE` for six of them and `UNKNOWN` for `EXCHANGE RECEIVED`, all
with source `contest`. `NONE` is a valid spelling (`NoQSOPointMethod`,
`NoDXMults`, ...). So any code that read a stored value as "the operator chose
this" would strip every corpus log of its points, multipliers and exchange.
This is the `DeriveCountry` trap: a persisted default reads back as a stated
value.

**It matters while `FoundContest` sets globals and the settings are applied
after it**, which means until M2 and, for classless contests, until the
endpoint. **Not established:** which code writes these rows, and why applying
them on open does not already break the logs. The corpus is green, so some path
does not apply them. Establish both before M2 changes where the `Active*` values
come from (Q3).

---

## 8. Migration

### 8.1 Which oracle sees what

| oracle | sees | blind to |
|---|---|---|
| `export-d12-corpus.sh` (24/0/2 **and** exit 0) | Cabrillo `QSO:` columns, ADIF records, **`CLAIMED-SCORE`** -- 13 registered contests | per-QSO points, parsing, setup, every classless contest |
| `test-contest-factory.sh` | rescored points against the frozen legacy output -- 13 logs | parsing, import, classless contests |
| `test-adif-roundtrip.sh` | import against our own export -- 13 sets | classless contests |
| unit tests (`Build-Tests.ps1 -Run`) | a contest class against fixtures, round-trip included | anything needing globals booted |
| frozen legacy fixture (new, one harness) | a contest's legacy arms on synthetic inputs, captured before they are deleted | correctness: it only proves "same as before" |
| bench / a real contest | whether a rule is **right**; the operator UI | -- |

**Every corpus set is a registered contest**, so the corpus says nothing about a
contest gaining its class. For one, capture its legacy behaviour **before** its
arms are deleted. Use ONE headless harness (like `/EXPORT`) that runs the legacy
points, parse and export for a named contest over a synthetic QSO matrix and
writes the whole `ContestExchange`. Freeze it once and never regenerate it.
Write one harness, not one per concern, because copies drift. A class changes
only its own contest, so the fixture is a per-contest proof, not the
shared-registration gate the superseded design needed.

### 8.2 The steps

Each step keeps the corpus at 24/0/2 with exit 0 and `test-contest-factory.sh`
at 13 identical, and lowers `Lint-ContestNameTests` ceilings in the same commit.
Each is behaviour-preserving unless marked.

| step | what | gate |
|---|---|---|
| **M0** | **Decide Q1 and Q3** (Q2 is ruled: no interim fix). Build the legacy-fixture harness (§8.1) | the harness |
| **M1** | **Identity read from the class.** The five exporters that read `ContestsArray` for names and ids ask the class (D9) | corpus (ADIF `CONTEST_ID`, Cabrillo `CONTEST:`); `test-adif-roundtrip.sh` |
| **M2** | **Setup head reads the class.** `ContestDefinition`, `InHostState`, `Active*` written from the class's traits. Arms stay. Freeze a setup fixture first: every `ContestType` x station variants (in-state/out, K/VE/DX) -> `Active*` and settings | setup fixture; corpus |
| **M3** | **Scoring finishes on the class.** The ten secondary `ActiveQSOPointMethod` readers move into their contests (§2; **behaviour change** for an operator override). Family bases arrive and `TContestFixedPoints` retires with them (§1.5) | `test-contest-factory.sh`; unit tests; `BENCH_QUEUE.md` |
| **M4** | **Exchange export.** Each contest formats its own Cabrillo and ADIF columns and emits its own ADIF contest fields. D4's dead arms and the D6 no-op go | corpus; per-class round-trip unit test |
| **M5** | **Exchange import and parse.** Generic importer, then `ApplyADIFImport` (§3.2), including the `APP_N1MM_EXCHANGE1` arm, pinned in both tag orders. `ParseReceivedExchange` per contest over lifted helpers. D1/D2's dead paths go | `test-adif-roundtrip.sh`; legacy fixture; `BENCH_QUEUE.md` for typed entry |
| **M6** | **Total score.** `TScoreTotals`, `CombineScore`, `BonusPoints`; `TotalScore`'s arms deleted; Missouri moved; Salmon Run per Q5 | corpus `CLAIMED-SCORE`; unit tests over totals |
| **M7** | **Session arms and the classless contests.** Each `FoundContest` arm becomes its contest's `DescribeSession`, and the arm is deleted. Classless contests gain a class: a family member, or a copy of the nearest class (§1.4) | setup fixture; legacy fixture; the arm count ratchets |
| **M8** | **Multipliers and dupes**, as contest virtuals | corpus `CLAIMED-SCORE`; legacy fixture |
| **M9** | **UI and the rest.** `NewContestPrompts`, `TotalsDisplay`, `SummarySheetMultColumns`, Cabrillo headers and mode string | bench (no automated gate sees the UI) |
| **M10** | **Endpoint.** Every `ContestType` registered (Q10). `QSO POINT METHOD` (and per Q4 its siblings) into `RETIRED_COMMANDS`. The legacy case, `ContestsArray`, `ContestsBooleanArray`, the traits and the `Active*` globals are deleted, along with `QSOPointMethodArray`, `FormatsExchange` and `Test_MovedRowValuesStillMatchTheArray` | corpus; factory gate; full unit run |

**Export comes before import and parse** because export is the only half the
corpus can see byte for byte. Once a class's export is pinned, its round-trip
test pins its import to it.

### 8.3 What "a contest has moved" means -- checkably

A contest has moved when **all** of these hold:

1. **The generated inventory reports zero rows naming it**, across shapes 1, 2,
   3 and 5, and in every shape-4 row of reach 1-3 that names it. A shape-4
   SHARED row (reach 4+) leaves when the last contest reaching it has moved.
2. **Its class states every row accessor as a literal**, and it is listed in
   `Test_MovedRowValuesStillMatchTheArray`.
3. **No `Contest`, `ceContest` or `SelectedContest` test names it outside the
   factory.** The `Lint-ContestNameTests` ceilings hold that per file.
4. **Its corpus set is green on all three scripts**, if it has one. If it has
   none, a unit test scores, formats and round-trips fixture QSOs through its
   class against its frozen legacy fixture, and `BENCH_QUEUE.md` carries the
   real-contest check.

The inventory generator is a **report**, not a gate (inventory §8.4), and item 1
is read from it.

---

## 9. Open questions for NY4I

Renumbered 2026-10-01. Each one names the question it came from: **Cn** from
this document before the rewrite, **old Qn** from `QSO_POINT_METHOD_DESIGN.md`.

- **Q1** (C2). ARRL Field Day's DX multiplier (inventory D8): the class says
  `ARRLDXCC`, while the arm says `NoDXMults` and wins. Which is right? Correct
  the class before M2 makes it the source.
- **Q2** (old Q2, Finding 1). **RULED 2026-10-01: no.** Nothing is fixed for the
  interim; the table retires with the setting, and Idaho gets its own class (§7.2).
- **Q3** (C1 + old Q1, Finding 2). Every corpus log stores the seven settings as
  `NONE` / `UNKNOWN`. Establish which code writes them and why they are not
  applied, before M2. Should a stored sentinel then read as "not stated"?
- **Q4** (new; the residue of C5). Do `EXCHANGE RECEIVED`, the four multiplier
  commands and `INITIAL EXCHANGE` retire with `QSO POINT METHOD` at the
  endpoint? **Recommended yes**, since they select from shared sets in the same
  way. The Idaho config uses three of them, so Idaho needs a `ContestType` and a
  class first (see Q8).
- **Q5** (C6). Should the Salmon Run W7DX bonus be implemented now, or stay
  recorded as missing? The bonuses-as-data shape (§5) is recommended.
- **Q6** (C7). POTA as a contest class (recommended, §6), keeping the root name
  `TContestBase`, with "contest" meaning "an operating event with rules" as
  `ContestType` already does?
- **Q7** (C8). Apply the NRAU ruling to every two-mode pair (§1.5), including
  pairs where one mode is rarely run?
- **Q8** (C9a, plus Idaho). Events with no `ContestType` are identified by
  string. These are `'TRC'`, `'PGA'`, `'EURASIA'` and `'DL-DX-RTTY'` (inventory
  D7), and Idaho, which is configured as NEQP plus overrides. Should each become
  a `ContestType` with a class, or be deleted?
- **Q9** (C9b). Should an operator-edited CQ memory survive re-selecting the
  contest (§4.2)?
- **Q10** (C11, narrowed). The retirement ruling implies that every live
  `ContestType` gets a class before the setting retires. May a `ContestType`
  that nobody runs be **deleted** instead of being given a class?
- **Q11** (C12 + old Q5). Some legacy arms are reached only through an
  operator's `QSO POINT METHOD` (D1-D4), and three kinds have no arm at all and
  score 0 (`SouthAmerican`, `IN`, `NYQPQP`). **Recommended:** keep them until
  the setting retires and delete them with it, rather than withdrawing selectable
  values one at a time.
- **Q12** (new; the ruling asked for it). Keep `FixedModePoints` as a helper and
  retire the `TContestFixedPoints` base as family bases arrive (§1.5)?
- **Q13** (old Q7, Finding 3). The OQP arm scores by the session's `ActiveMode`,
  not the QSO's own mode, so a rescore follows the radio. Fix it when OQP gains
  its class? (This is a behaviour change.)

**Answered by the ruling, and dropped:** C3 (`CreateOwned...`), C4 (the
exchange-field model), C5 (`EXCHANGE RECEIVED` as a strategy swap; its residue
is Q4), C10 (multiplier strategies last), old Q3 (the secondary readers all go
to the contest), old Q4 (point-table units), old Q6 (the overrides stay ahead of
the class).
