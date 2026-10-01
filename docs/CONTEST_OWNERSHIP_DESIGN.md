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
| per-QSO points | the class, for every registered contest (`logstuff.CalculateQSOPoints` hands over to `ScoreQSO` and `Exit`s) | `ScoreQSO`, the one public entry point, over the protected `CalculateQSOPoints` (**existing**, M3, §7.7) |
| dupe policy (does a repeated contact get marked as a dupe) | the class, asked by `logsubs2` through `ContestIdentity` (M3) | `MarksDupes` (**existing**) |
| the bands it uses (an off-band QSO is logged, scores 0, earns no multiplier) | the class; base says every band | `UsesBand` (**existing**, §7.4) |
| identity: enum, display/friendly/Cabrillo name, ADIF id and former ids, WA7BNM, QRZ.RU, e-mail | **the class, and every consumer asks it** (M1, done 2026-10-01) through `uContestRegistry.ContestIdentity` | existing properties (**existing**) |
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

**Since M3 (2026-10-01) the order lives on the class**, in
`TContestBase.ScoreQSO` -- non-virtual, the one public scoring entry point
(§7.7):

1. `QSOPoints := 0`.
2. A band the contest does not use scores 0 (`UsesBand`, through
   `ContestCreditsBand`, §7.4), and nothing below is asked.
3. The four `QSO POINTS DOMESTIC/DX CW/PHONE` settings each apply when they
   match the QSO, and each falls through when it does not. They are the
   station's statement, handed to the class in
   `TStationContext.PointOverrides`, and applied by
   `uContestBase.ApplyQSOPointOverride`. **Kept.**
4. Otherwise the contest's own rule, the **protected** `CalculateQSOPoints`.

`logstuff.CalculateQSOPoints` asks `ActiveContest(Contest).ScoreQSO` first
and `Exit`s. What follows it there is the classless path only: the same
`ApplyQSOPointOverride` (fed by `uContestFactory.CurrentQSOPointOverrides`,
the one reader of the four settings), then `case ActiveQSOPointMethod of`, the
legacy engine. Its band check was deleted -- a classless contest uses every
band, so it could never refuse one.

So `CalculateQSOPoints` is still **the permanent seam** for a contest's rule;
`ScoreQSO` is how everything reaches it. Since phase F, a contest with a class
has ignored `QSO POINT METHOD` for points, and under this ruling that is
correct rather than a gap.

**What is left on scoring:**

- **The legacy case is deleted at the endpoint**, together with the setting
  (§7.1, Q11). Until then it serves classless contests.
- **Ten sites outside the case still read `ActiveQSOPointMethod`**:
  `rg -n -i "ActiveQSOPointMethod" tr4w/src --glob '*.pas'`, dropping
  comments and `backup/` by eye. Each moves into the contest:

  | site | moves to | status |
  |---|---|---|
  | dupe marking, `logsubs2` (`AlwaysOnePointPerQSO`) | the contest's dupe-policy property (`MarksDupes`). Internet Sprint and Youth Championship RF reach it today | **MOVED, M3** (§8.2d) |
  | exchange parsing, `logstuff` `ProcessRSTAndQSONumberOrDomesticQTHExchange` x3 (RAC: CANADA_WINTER/CANADA_DAY; PCC; Arktika Spring) | that contest's `ParseReceivedExchange` | **M5** |
  | initial exchange, `zonecont.GetVEInitialExchange` (RussianDX: RDXC, RU3AX MEMORIAL -- a UA oblast) | that contest's initial exchange | **M5** |
  | total-score formulas, `logedit.TotalScore` x5 (WAE weighted mults; CupRF +100, ALRS +300, ChampionshipRF +50, OZHCR +1000 per mult) | that contest's `CombineScore` (§5) | **M6** |

  Measured 2026-10-01 at M3 with `rg -i -w ActiveQSOPointMethod tr4w/src`:
  those are every rule reader. The rest are its writers (`fcontest`'s set-up
  head, `uSettingsEffects`), its declaration, the matrix's diagnostic print,
  and comments.

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

**Item 1 and the head of item 2 changed at M2 (2026-10-01, §7.9, §8.2c).** The
head no longer reads `ContestsArray` or `ContestsBooleanArray`: one resolver,
`FCONTEST.ApplyContestTraits`, writes every head value from the operator's
statement, else `ContestIdentity(Contest)`. Item 3, the arms, is unchanged and
still runs after it.

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
  express. **Deferred to M7 (DECIDED at M2, §7.9):** the head asks
  `ContestIdentity`, which carries no station, and the arms that branch on
  in-state still run after it, so today's values survive without it.
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

**It reached a shipped file** (until 2026-10-01 -- see DONE below). `target/dom/Idaho QSO Party.cfg` was a contest
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
**AND NO `.cfg` BORROWS ANOTHER CONTEST'S TYPE** (NY4I, 2026-10-01: *"The only
contest that should say CONTEST = NEQP is the NEQP"*). An event is a `ContestType`
and a class of its own, never a `.cfg` naming a look-alike and overriding its
settings. Measured 2026-10-01: of the 15 tracked `.cfg` files, Idaho's is the ONLY
one that borrows -- the 13 corpus logs and `tr4wserver.cfg` do not -- and there is
no Idaho `ContestType` at all; the file arrived with D7 4.129.1 (`f93d06dc`)
alongside `IDAHO.DOM` / `IDAHO_CTY.DOM`. The end state adds `IDAHOQSOPARTY` with its
class, and the `.cfg` names it.

**DONE 2026-10-01.** `IDAHOQSOPARTY` is appended to `ContestType` (the ordinal is
persisted by the `.TRW` record, the multi-op packet and HamScore's
`<contestnr>`), with QSOParties entry 21 (`idaho`, `ID`), and
`uContestIdahoQP` owns its rules on `TContestStateQSOPartyBase`. The `.cfg` is
now `MY CALL` and `CONTEST = IDAHO QSO PARTY` and overrides nothing. The class
header records the sponsor sources and the changes from the NEQP-borrowing
setup: the DX multiplier the sponsor requires and NEQP's row did not have, the
in-state `.dom` whose `INCLUDE` lines had never loaded (they lacked `FILE`, and
one named a `P3.DOM` that does not exist), and ADIF/Cabrillo id `ID-QSO-PARTY`.
There is deliberately **no** former ADIF id: old Idaho logs were exported as
NEQP and cannot be told apart from NEQP's.

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

**Established and fixed in M2a, 2026-10-01 (§7.8).** The dumping capture wrote
the rows. The equality skip hid them: they were applied only when the value in
force differed, and a sentinel never differed except after a `.cfg` had stated
the setting (D2). The rows stay in the tracked fixtures, but the reader no
longer treats them as statements.

---

## 8. Migration

### 7.4 A QSO on a band the contest does not use scores ZERO -- it is not refused

NY4I, 2026-10-01: *"No WARC so just mark it as zero points. That is useful if say
during the contest, we want to work a new country we need unrelated to the
contest. I would not want to disallow an operator from logging but we should not
score it."* And not an automatic X-QSO either: *"that would be confusing to an op
to not know why the qso was in gray so let's not go that far."* *"This rule
applies to basically any contest. When we submit the qso info to the factory if
it saw the band was 30m, it should return 0 points."*

So the CONTEST owns the bands it uses, and the scoring call answers 0 for any
other band. The QSO is logged normally. Idaho (160/80/40/20/15/10 m) is the
first contest to state it.

**And no multiplier credit either** (NY4I, 2026-10-01: *"correct, no multiplier
credit for off-band QSOs"*). A new country worked on 30 m during a contest
without WARC is in the log, scores 0 and counts no multiplier.

**And no need-multiplier hint** (NY4I, 2026-10-01: *"off-band should not impact
need multiplier. It is really a one-off with no impact on the contest at all."*).
Today `EditableLog.DetermineIfNewMult` and its neighbours read the mult sheet and
can still flag an off-band call as a needed multiplier; they must ask the same
band question the scoring does (M8 multipliers / M9 display).

**Nor does it mark a multiplier worked** (NY4I, 2026-10-01: *"if I work an off-band
multiplier, it should not make it appear worked when I find the same mult
on-band"*). `1e4f66f9` clears an off-band QSO's mult flags inside
`SetMultFlags`, and the sheet marks a multiplier only from flags set there.
**PINNED at M3** (`uTestOffBandCredit`, through the real `Sheet.SetMultFlags` and
`AddQSOToSheets`): an off-band Idaho QSO with a new county leaves it new on-band.
"Shows as needed" (the display hints) is still M8/M9, below. **And an off-band
QSO is not a dupe and makes no later on-band QSO a dupe** (NY4I confirmed,
2026-10-01) -- **which does NOT hold today for a contest whose QSOs are not
counted per band**: `TCallsignsList.AddCallsign` marks the `AllBands` bit for
every logged QSO, off-band included (§8.2d). No shipped contest reaches it,
because Idaho counts QSOs per band; it is M8's.

**LANDED 2026-10-01.** The seam is **`TContestBase.UsesBand(aBand): boolean`**,
a virtual whose base answers `True` for every band. That is exactly what every
contest did before, so only a contest that overrides changes. Idaho is the only
overrider. The engine asks it through one helper,
**`uContestBase.ContestCreditsBand(aContest, aBand)`**, which also answers
`True` for `nil` (a classless contest). It asks at both places credit is
decided:

| credit | where | why there |
|---|---|---|
| points | `TContestBase.ScoreQSO` since M3 (`logstuff.CalculateQSOPoints` until then), **before** the four `QSO POINTS ...` overrides | the ruling is 0, so an override must not score an off-band QSO either; the class's `CalculateQSOPoints` is then never asked about one |
| multipliers | `logdupe` `DupeAndMultSheet.SetMultFlags`, after the four flags are cleared and after the `DomMultQTH` fill | every multiplier flag is set there: live entry, the rescore, the editable log and the multiplier alarm. `AddQSOToSheets` marks the sheet only for a flag set there. The QSO keeps the QTH it was worked with; only its credit goes |

Neither site names a contest, so no `Lint-ContestNameTests` ceiling moves.
`Test_EveryOtherContestStillCreditsEveryBand` pins the default for every other
registered contest. It is a ratchet: a contest that states its bands joins its
exception list in the same commit. Each contest's own band list is that
contest's own move.

**Not covered yet:** the "is this a new multiplier" display hints
(`EditableLog.DetermineIfNewMult` and its neighbours) read the multiplier sheet
directly. They can still highlight an off-band call as a needed multiplier,
although logging it gives no credit. Hiding WARC from band stepping
(`WarcEnabled`) is a `FoundContest` arm and belongs to `DescribeSession` (§4).

### 7.5 Idaho QSO Party rulings owed to the class (NY4I, 2026-10-01)

- **QRP means OUR power** -- the entrant's Cabrillo `CATEGORY-POWER` from the New
  Contest dialog. Sponsor: *"ALL QRP QSO's count 5 points. voice, CW, digital"*,
  QRP being 5 W output or less.
- **Dormant-county bonus** (https://www.idahoqsoparty.org/idaho_rovers.htm): an
  Idaho station operating FROM a listed county earns that county's bonus (500 /
  1000 / 1500) once it makes 10 valid QSOs there. A final-score bonus -- M6.
- **No WARC**: 0 points, per 7.4.
- Rules: https://www.idahoqsoparty.org/rules.htm

**LANDED 2026-10-01, except the bonus.** `TContestIdahoQP.UsesBand` names
160/80/40/20/15/10 m. Every other band, including WARC, 6 m and VHF, scores 0
and earns no multiplier. QRP is read from **`TStationContext.MyPower`**, which
`uContestFactory.CurrentStation` fills from `Settings.Contest.CategoryPower`.
The New Contest dialog applies its `CATEGORY-POWER` choice as a command, and the
settings model aliases that command to this property. Stew Perry's legacy arm
reads the same value. For a QRP entrant every in-band QSO scores 5, whatever
its mode, and LOW and HIGH score 2/1/2/1. The contest matrix re-froze
IDAHOQSOPARTY alone for this change. Its 2 m, 30 m and 6 m QSOs went to
`pts=0` with every multiplier flag false, in all four station variants, and
nothing else moved. The dormant-county bonus waits for M6.

### 7.6 The entrant's power is ONE value, and the last touch wins

NY4I, 2026-10-01. Today two stores hold it: `Settings.Contest.CategoryPower`
(set by the New Contest dialog, read by scoring through `TStationContext.MyPower`)
and the Cabrillo summary's own `_CATEGORY-POWER`. The end state has one:

- **The last touch point wins.** *"If they select QRP right before cabrillo
  generation, we have to assume they know what they are doing."* The summary
  writes the same setting scoring reads, and a change rescores the log.
- **It may change mid-contest**, or be set late. *"Maybe we remind them of that
  mid-contest but let it be changed"* -- a reminder that it changes the scoring
  class, never a block.

Lands with the Cabrillo-header and UI work (M9).

### 7.7 DECIDED (2026-10-01): three scoring stages, one entry point each

NY4I delegated the stage boundaries (*"the stages are your choosing"*) after
asking how rules relative to OTHER QSOs work if the class sees one QSO. The
measurement that decides it: the legacy per-QSO scoring (`logstuff.pas`
`CalculateQSOPoints`, ~3,300 lines) reads **no** log and **no** mult sheet -- every
point rule TR4W has is a function of the QSO and our station. History-dependent
rules already live elsewhere: dupes and mults in the sheet (`logdupe`), once-only
bonuses scattered (Missouri, inventory D10).

| stage | question | the class gets | examples |
|---|---|---|---|
| 1 per QSO -- `ScoreQSO` | what is this contact worth? | the QSO and the station context, nothing else | mode points, distance, county line, off-band 0, QRP 5 |
| 2 running state -- dupes and mults | dupe? new multiplier? | the contest DECLARES the rules (by band, by mode, which fields); the shared sheet keeps the state | Idaho once per mode; CQ WW per band |
| 3 end of contest -- `CombineScore` + `BonusPoints` (M6) | what is the final score? | a READ-ONLY view of the whole log | NC sweep, Idaho dormant county, W7DX, Missouri, a rare county worth 500 once |

Why stage 1 never sees the log: "first QSO with W7DX gets 500" changes meaning
under rescore, delete, edit and a multi-op merge; a bonus computed at the end from
the whole log is the same however it was reached. Stage 1 also stays pure, which
is what lets the matrix and unit tests pin it -- and the sponsors themselves write
these as bonuses on top of the QSO total. A live "+500" for the operator is a
display question answered from stage 3's view, not a reason to move the bonus.
If a contest ever genuinely needs history in one QSO's points, widen stage 1 then;
none does today.

**`ScoreQSO` is the ONE public scoring entry point** (NY4I: *"yes one public entry
point"*): a non-virtual template on `TContestBase` -- band check (`UsesBand`), then
the four `QSO POINTS` station overrides, then the protected virtual
`CalculateQSOPoints`. Every caller -- engine, rescore, matrix, tests -- gets the
order; nothing can score while skipping the band check. `UsesBand` stays public
because stages 2 and the need-mult display must ask the same question.
**LANDED at M3, 2026-10-01** -- shape and callers in §8.2d.

### 7.8 DECIDED (2026-10-01): Q3 -- the log stores only what the OPERATOR stated

Evidence (investigation, 2026-10-01): the seven stored `NONE`/`UNKNOWN` rows are
`TR4WSettings` constructor defaults written by `uLogStore.CaptureConfiguration`
(on create/rebuild and every clean close); `FoundContest` sets the globals and
never those properties; the rows are harmless only because the apply skips a
value equal to the property; nothing distinguishes "operator chose NONE" from
"nobody chose". Since 2026-09-13/14 every log records defaults, not rules, and
overwrites older logs' real values on close.

Decided: the contest log's `config` table holds **only operator-stated
overrides**; **absence means the contest class decides**. The stated/not-stated
fact lives on the setting (a was-set flag, the `MyContinentIsSet` pattern);
`CaptureConfiguration` writes a contest-scoped row only when set and deletes it
when cleared. For a log written before the flag, a stored value equal to the
constructor default reads as not stated. Lands in M2, because once the class
supplies these values the equality skip no longer protects the contest.

**LANDED 2026-10-01 (M2a).** Scoring is unchanged: the contest matrix stays
185 identical, and `FoundContest` still sets the globals.

- **The flag** is `TR4WSettings.CommandIsStated(cmd)` in `uSettingsModel`. It
  is one set of property paths, so every alias of a setting shares it, and it
  applies to every contest-scoped group (`IsContestScoped`). It answers False
  for a station setting.
  - **Set by `TrySetByCommand`.** Every channel that reaches a setting by name
    is an operator speaking: the `.cfg`, the New Contest queue, Preferences,
    Alt-P, a multi-op peer, and the log's own statements on reopen. Contest
    set-up assigns the properties directly, so it never sets the flag.
  - **Not set by `TrySetUnstated`.** Its one caller is the station bucket (see
    below).
  - **Cleared by `SetCommandStated(cmd, False)`.** No control offers "back to
    the contest's value" yet.
- **The capture** is `uLogContestStatements.CaptureContestStatements`, called
  from `uLogStore.CaptureConfiguration`. It writes a stated contest-scoped row
  and deletes every other one. It never writes `CONTEST`. It marks the log by
  setting `session_state.configHoldsStatementsOnly = 1`. The station rows are
  untouched.
- **The read** is `KeepOnlyStatements`, called from
  `LogStoreApplyContestConfig`.
  - **A marked log:** every row is a statement. This includes a stated
    `NONE`, which matters because Field Day has no multipliers (Q1).
  - **An unmarked log** (every log written before this, including the corpus
    fixtures): a contest-scoped row equal to the constructor default is
    dropped and logged, and deleted at the next interactive capture. A
    non-default row is applied and flagged.
  - **When a statement already equals the value in force**, the skip still
    records it as stated.
- **D2 is closed by construction.** A stored sentinel is no longer a
  statement, so it cannot overwrite a `.cfg` line. This is pinned by
  `uTestLogContestStatements`. It was also checked end to end: a copy of
  `cqww_ssb_2025_ny4i/log.db` plus a `.cfg` stating `QSO POINT METHOD` gives
  that method in `active.qsopointmethod`, not `NoQSOPointMethod`.
- **The station bucket is not a statement.** The `commands/contest` values
  (for example `INITIAL EXCHANGE = ZONE` on NY4I's station and in the corpus
  settings) come from three writers, measured 2026-10-01:
  - the one-time `tr4w.ini` seed;
  - `ApplyPeerCommand`;
  - one Preferences control, `MY CONTINENT` on the Station page, which goes
    through `ApplyAndStoreCommand`.

  Every other contest-scoped setting in Preferences is a `TModelSetting` and
  writes no bucket entry. None of these writers speaks for the contest that is
  open, so `ApplyStoredCommands` applies the values unstated, and never over a
  setting already stated for the open contest. They stay in force for the
  session, and the log no longer captures them as the contest's.

**Q-M2a (NY4I): the contest section of the station bucket.** It has no
writer that speaks for a contest. Should it:

1. keep applying as a station default, which is today's behaviour;
2. be converted once into the open log as statements; or
3. retire, so the contest decides?

**Q-M2b (NY4I): `MY CONTINENT` is a station fact in a contest-scoped
group.** It is `Contest.MyContinent`, yet the Station page edits it. Under
M2a it stays in force every interactive session from the bucket, but a NEW
log no longer captures it. A headless `/EXPORT` of that log therefore derives
the continent from the callsign. That only matters for a station whose
stated continent differs from the derived one. The fix is to move it to
`TMySettings`, so it goes into `settings/tr4w.json` with the other `MY`
fields. That changes the settings file's shape, so it was not done here.

### 7.9 DECIDED (2026-10-01, M2): what set-up starts from, and in what order

NY4I delegated the design forks of M2. Each decision below rests on the
evidence given with it.

- **ONE RESOLVER: `FCONTEST.ApplyContestTraits(aContest)`**, called by
  `FoundContest`'s head with `ContestIdentity(Contest)`. It is the only writer
  of the seven `Active*` globals, of `Settings.Qso.ByMode/ByBand`,
  `Settings.Mult.ByMode/ByBand`, `Settings.Bands.VhfEnabled`,
  `Settings.Contest.CountDomesticCountries` and of `CTY.ctyZoneMode`. The head
  then takes the domestic file from the same object (`DomesticFileName`, and
  `InStateDomesticFileName` for an in-state party station).
- **THE PRECEDENCE: the operator's statement, else the contest.**
  - A setting that IS its property (the flags, `DOMESTIC FILENAME`) is not
    assigned when `CommandIsStated`.
  - The seven tokens are assigned from the class, then every stated one is
    **replayed** through `uSettingsEffects.ReplayContestStatements`, which runs
    the same arm a `.cfg` line runs (`ApplyTokenSetting`), side effects
    included. Replaying rather than "leave the global alone" is necessary: the
    log's reapply records a statement equal to the value in force without
    assigning, so no setter ran and the global can hold the contest's value.
    The order is fixed, with `INITIAL EXCHANGE` last because the `ZONE
    MULTIPLIER` arm sets the initial exchange as a side effect.
  - `TR4WSettings.PathIsStated(path)` was added for the replay, which knows
    paths rather than names. `CommandIsStated` now calls it, so the lookup
    exists once. `Test_ContestSetUpAsksRealContestScopedNames` checks every
    name and path set-up asks.
- **A STATEMENT BEFORE THE `CONTEST` LINE NOW STANDS. This is a behaviour
  change, and it removes a defect.** Before M2 the head overwrote such a
  statement for every one of these values. "Operator beats contest" held only
  when the operator's line came after `CONTEST`. It now holds whatever the
  line order. Verified with one-off runs (not frozen): `ARRL-10` with `QSO
  POINT METHOD`, `MULT BY BAND`, `ZONE MULTIPLIER = CQ ZONES` and `DOMESTIC
  FILENAME` stated before `CONTEST` keeps all four, and the zone statement
  brings its zone list and initial exchange. **A per-contest arm still
  overwrites a pre-`CONTEST` statement, exactly as before**, because the arms
  run after the head. For example, `ARRL-10`'s arm sets its DX multiplier and
  Field Day's arm sets `NoDXMults`. That moves with each arm at M7. A line
  after `CONTEST` is unchanged: its setter still runs last. The matrix and
  every corpus `.cfg` state none of these values before `CONTEST` (measured),
  so neither oracle moves.
- **THE ZONE LIST IS A CLASS TRAIT: `TContestBase.ZoneMode`** (defect #2). It
  is "CQ zones or ITU zones", a fact about the contest. The base reads the
  array legend, which is D7's rule, and a class states it when it moves.
  `QSOByBand`, `QSOByMode`, `MultByBand`, `MultByMode`, `VHFBandsEnabled` and
  `CountsDomesticCountries` joined it for the same reason. They are one
  property per fact (§1.2, "sponsor parameters") and each defaults to
  `ContestsBooleanArray`.
- **A QSO PARTY'S TWO FILES ARE TWO CLASS FACTS.** `DomesticFileName` is the
  host's county file: every other station loads it, and the in-state test
  reads it. `InStateDomesticFileName` is the in-state file. Until M2 the head
  spelled the out-of-state name a second way, as the in-state name plus
  `_cty`. It now uses `DomesticFileName`, which is equal for every party once
  Colorado's row is fixed. `Test_EveryQSOPartyNamesBothDomesticFiles` pins
  the two together and checks that both files ship.
- **`InHostState` WAITS FOR M7, AND THE ARMS KEEP D8's SIX CONDITIONALS.**
  `ContestIdentity` carries no station; it answers what a contest IS. An
  answer that varies with the station belongs to `DescribeSession` (§4.2).
  Each conditional arm (AZ, CQP, Salmon Run, TX and the rest) still runs after
  the head and still overwrites the head's value, so the class can keep
  stating one branch without changing behaviour. The matrix confirmed it: the
  resolver alone moved 0 of 185 records.
- **D8's UNCONDITIONAL DISAGREEMENT, Field Day's DX multiplier, was corrected
  first (Q1):** both the class and the row now say `NoDXMults`, so the value
  the head starts from is the value the arm ends with.
- **The in-state test keeps D7's rule**: MY STATE is a key of the county file.
  It differs in one way: the comparison ignores case. EnumDOM2 upper-cased the
  line but not MY STATE, and a county code is not case-significant anywhere
  else. **The rule takes the data at its word**, and one file abuses it (Q14).

### 8.1 Which oracle sees what

| oracle | sees | blind to |
|---|---|---|
| `export-d12-corpus.sh` (24/0/2 **and** exit 0) | Cabrillo `QSO:` columns, ADIF records, **`CLAIMED-SCORE`** -- 13 registered contests | per-QSO points, parsing, setup, every classless contest |
| `test-contest-factory.sh` | rescored points against the frozen legacy output -- 13 logs | parsing, import, classless contests |
| `test-adif-roundtrip.sh` | import against our own export -- 13 sets | classless contests |
| unit tests (`Build-Tests.ps1 -Run`) | a contest class against fixtures, round-trip included | anything needing globals booted |
| frozen legacy fixture -- **built (M0, 2026-10-01)**: `tr4w/test/contest-matrix/run-contest-matrix.sh` | every `ContestType` x four station variants: set-up, per-QSO scoring, and the real exporters' Cabrillo/ADIF output (`ADDING_A_CONTEST.md` §4) | correctness: it only proves "same as before"; parsing and import until M5 adds them |
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
| **M0** | **DONE `93fbc053`.** Q1/Q2 ruled, Q3 decided (§7.8). Build the legacy-fixture harness (§8.1) | the harness |
| **M1** | **DONE 2026-10-01 (§8.2b).** **Identity read from the class.** The five exporters that read `ContestsArray` for names and ids ask the class (D9) | corpus (ADIF `CONTEST_ID`, Cabrillo `CONTEST:`); `test-adif-roundtrip.sh` |
| **M2** | **DONE 2026-10-01 (§7.9, §8.2c).** **Setup head reads the class.** `FCONTEST.ApplyContestTraits`: the operator's statement, else `ContestIdentity` (M1's accessor serves as `ContestDefinition`). `Active*` and the head's flags come from the class's traits. Arms stay. Defects #1, #2, #3 and #5 fixed. `InHostState` deferred to M7 | the contest matrix; corpus |
| **M3** | **PARTIAL 2026-10-01 (§8.2d).** **Scoring finishes on the class.** DONE: `ScoreQSO`, the one entry point (§7.7); the dupe-marking reader moved to `MarksDupes` (**behaviour change** for an operator override); the off-band multiplier pin. The other secondary readers are scheduled where their rule lives -- parsing M5, total score M6 (§2). OPEN: family bases arrive and `TContestFixedPoints` retires with them (§1.5) | `test-contest-factory.sh`; unit tests; `BENCH_QUEUE.md` |
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

### 8.2a Defects the M0 matrix pinned, and the step that fixes each

Frozen as today's behaviour by `93fbc053`, NOT fixed in place (NY4I: build for the
end state). Each is fixed by the step that rewrites its code, and that step
re-freezes only the contests the fix reaches, with the reason:

| # | defect | fixed in |
|---|---|---|
| 1 | no station is ever in-state for a QSO party: `FoundMyStateInDomFile` builds `'DOM' + DF + '.DOM'` with no separator (D7: `'%sDOM\%s.DOM'`) -- port regression | **FIXED M2.** `uAppPaths.ShippedDomFilePath` (now the one composition for all three dom readers: FCONTEST, `LogCfg`, `logdom`'s INCLUDE) and `uDomFileKeys` (EnumDOM2's rule, unit-tested). Matrix: the 21 parties' us-host variants are now in state, plus NC's ve variant -- see §7.9 |
| 2 | CTY zone mode 255 in 500 of 575 records: `ZoneModeType(<boolean>)` at `fcontest.pas:421`; no `uctydat` arm matches, zone 0 | **FIXED M2.** `TContestBase.ZoneMode`, the array legend's rule (bit set CQ, clear ITU) -- D7's. Matrix: 160 contests; MY ZONE now derives an ITU zone, and with it the zone memories, sent zones and four contests' sparse-QSO points |
| 3 | NEQP crashes in setup with an empty MY STATE (`PWORD` of an empty string; can never match ME/NH since `string` is 2-byte) | **FIXED M2.** A string comparison of MY STATE's first two characters (D7's rule). Matrix: the dx variant records |
| 4 | ARRL SS Cabrillo writes a NUL for an empty precedence | M4 |
| 5 | COLORADOQSOPARTY's row is shifted: `Email` holds `'colorado_cty'`, `DF` is `''` | **FIXED M2**, row and class together; no neighbouring row is shifted. Matrix: Colorado's us-host input only |
| 6 | REF's `FrenchID` AVs on an empty `CountryID` (latent) | M5 |

### 8.2b M1 -- what it covered (2026-10-01)

**One answer per identity question, owned by the contest, and every consumer
outside the factory asks it.** The accessor is
`uContestRegistry.ContestIdentity(c)`: the registered class, else a plain
`TContestBase` reading the row. It is never nil, the registry owns it (one
instance per contest, built on first ask, thread-safe because the score-posting
clients ask from worker threads), and it carries no station -- `ActiveContest`
stays the scoring object, and its `nil` for a classless contest is right for
behaviour and wrong for a name, which is why this is a second accessor.

| consumer | read before | asks now |
|---|---|---|
| `uADIF.EmitADIFRecord` (ADIF `CONTEST_ID`) | `ADIFName`, else `ContestTypeSA` | `ADIFContestId` |
| `postunit` Cabrillo header (`CONTEST:`) | `CABName`, else `ContestTypeSA` | `CabrilloName` |
| `postunit.ContestFriendlyParens` (summary sheet, score report) | raw `FriendlyName` | `FriendlyName`, shown when it is not the enum spelling |
| `logsubs2` UDP score broadcast `<contest>` | `ADIFName`, else `ContestTypeSA` | `ADIFContestId` |
| `logsubs2` UDP contact broadcast `<contestname>` | the ACTIVE contest's `CABName`, else the QSO's `ContestTypeSA` -- two contests in one rule | the QSO's `CabrilloName` |
| `uGetScores` `<contest>` | `ADIFName`, else `ContestTypeSA` | `ADIFContestId` |
| `uHamScore.RenderDeleteLogBody` | `ADIFName`, else `ContestTypeSA` | `ADIFContestId` |
| `uExternalLogger` (DXKeeper) `CONTEST_ID` | bare `ContestTypeSA` | `ADIFContestId` -- **a behaviour change**, see below |
| `uLogRepository.SetContest` friendly name | `FriendlyName`, else the token | `FriendlyName` |
| `MainUnit` calendar menus (enable + URL) | `QRZRUID`, `WA7BNM` | `QRZRUId`, `WA7BNMId` |

**Seven hand-written copies of "the field, else the enum's spelling" are gone**;
the rule is stated once per field in `TContestBase`. Nothing reads
`SubmissionEmail` (the MAPI send was removed 2026-09-08) or `DisplayName`
outside the factory.

**D9 is closed.** `TContestBase.GetADIFContestId` is now "`ADIFName`, else the
enum's spelling" -- what export always wrote -- and the eighteen classes that
transcribed a blank as `''` state their spelling. Export and import ask the
same getter, so they agree by construction: every `ContestType` round-trips
except DUMMYCONTEST (not a contest), POTA and GENERALQSO (export writes no
`CONTEST_ID`; that `in [POTA, GENERALQSO]` test in `uADIF` moves when POTA has
a class, Q6), and RSGB_ROPOCO_SSB, whose row shares `RSGB-ROLO` with the CW
running and reads back as CW. **No new collision**: no enum spelling equals
another contest's id or former id (measured, and pinned by
`Test_OnlyRSGBRoloSharesACurrentADIFId`). "A current id beats a former id" is
unchanged, and is now what keeps Idaho off `NEQP`: `NEQP` is NEQP's current id.

**What M1 changed on purpose, with no oracle to see it.** DXKeeper now receives
the contest's ADIF id rather than the enum spelling, which differs for the 34
contests whose row states an `ADIFName` other than their spelling (ARRL Field
Day sent `ARRL-FD`; it now sends `ARRL-FIELD-DAY`, as export does). And the UDP
contact broadcast names the QSO's contest consistently; it differs from before
only when a QSO's contest is not the active one.

**Gates:** the contest matrix 185 identical; `test-adif-roundtrip.sh` 13/0/0;
`Lint-ContestNameTests` unchanged (M1 removed fallback copies, not contest-name
tests). The score-posting and UDP ids have no oracle, so
`Test_IdentityIsWhatTheExportersWroteBeforeM1` pins every getter over every
`ContestType` to what the removed copies produced.

**Not M1:** the `ContestTypeSA` *token* reads -- the `.cfg`/database key, the
contest-selection lists, and diagnostic messages -- are the enum's own
spelling, not a class property, and `ContestTypeSA` does not retire at M10.
`MainUnit`'s `pos('CQ-WW', ...)` off-time test is a sponsor rule (M2/M7).
`test/logdump` still keeps its own diverged rule (`'CONTEST_' + ordinal`), and
`verify_adif_export.py`'s note on `CONTEST_ID` predates the fallback.

### 8.2c M2 -- what it covered (2026-10-01)

The decisions are in §7.9. Each change was matrix-run on its own, and only the
contests it reached were re-frozen, with a reason:

| change | contests re-frozen | what moved |
|---|---|---|
| the resolver, with Field Day's DX multiplier corrected first | **none** (185 identical) | nothing -- every class trait equals the row except Field Day's, and its arm wins |
| #2 zone list | 160 (every contest without the CQ bit) | `cty.zonemode` 255 -> `ITUZoneMode`; MY ZONE derives the station's ITU zone (K0AAA 7, DL1AAA 28) where it read 0; `qthzone` is CTY's ITU zone; the zone exchange memories, `STX_STRING` and the Cabrillo sent zone follow MY ZONE; sparse-QSO points move for IARU, BSCI and OZCR_Z (a zone-0 exchange no longer "matches" a zone-0 station); NZ Field Day's VE zone flag |
| #5 Colorado's row | COLORADOQSOPARTY | the matrix's us-host input only: its MY STATE is the county file's first key, `Ada`, where the empty DF made it fall back to `CO` |
| #1 in-state | the 21 parties with a host index | every us-host variant is in state: `(in state)`, the in-state domestic file, `MultipliersIsCounties` FALSE, and the in-state branch of each conditional arm. Also NCQSOPARTY's **ve** variant (Q14) |
| #3 NEQP | NEWENGLANDQSO | the dx variant records -- outside New England -- instead of `RUN FAILED: exit 217` |

**Also measured, not frozen:** an NEQP station with MY STATE `ME` now gets
`NEQSOW1.dom`, `RSTDomesticOrDXQTHExchange` and
`ARRLDXCCWithNoUSACanadaKH6OrKL7`. The matrix has no variant for that, because
NEQP has no host index.

**Ceilings:** narrowing 1337 -> 1335. The in-state test and `LogCfg`'s domestic
path stopped going through `AnsiChar` buffers. `Lint-ContestNameTests` did not
move: the resolver names no contest, and the NEQP arm was already one.

**Not M2:** the per-contest arms (M7), `InHostState` (M7), and the CW memories
an in-state AZ or Salmon Run station gets. Its exchange,
`RSTDomesticOrDXQTHExchange`, has no arm in `FoundContest`'s closing
`case ActiveExchange`, so its F3-F5 memories are left blank. That is what D7
did for an in-state station, and nobody saw it because nobody was in state.

### 8.2d M3 -- what it covered (2026-10-01; PARTIAL)

NY4I delegated M3's design forks. Each DECIDED entry rests on the evidence
given with it.

**DECIDED: `ScoreQSO` is a non-virtual PROCEDURE on a `var ContestExchange`,
and `CalculateQSOPoints` is protected.**

- A procedure, not a function returning points, because a contest's rule
  writes more than the points: ARRL DX inhibits a W/VE-to-W/VE contact's
  multipliers, and the matrix's scoring line exists because thirteen legacy
  arms write `InhibitMults`, `DomMultQTH`, `DomesticMult`, `ZoneMult`,
  `Prefix` or `DXQTH`. A function would read as pure and hide those writes.
- Non-virtual, so no contest can reorder the steps; protected
  `CalculateQSOPoints`, so nothing outside the hierarchy can score while
  skipping them. All 28 overrides moved from `public` to `protected` with it
  -- a public redeclaration in a descendant would reopen the bypass.

**DECIDED: the four overrides reach the class as data, with a `Stated` flag.**
`TStationContext.PointOverrides` (`TQSOPointOverrides`, four
`TQSOPointOverride = (Stated, Points)`), filled by
`uContestFactory.CurrentQSOPointOverrides`. Not the setting's `-1` sentinel:
that would make the record's zero value "every QSO scores 0", and every test
FillChars a station. **The rule is written once**,
`uContestBase.ApplyQSOPointOverride`, called by `ScoreQSO` and by the classless
engine path -- a second copy in `ScoreQSO` would have been two definitions of
one rule.

**Callers.** One production caller of the class: `logstuff.CalculateQSOPoints`,
which every scoring path goes through (live entry, `uEditQSO`, the rescore,
`MainUnit.RecomputeQSOScoring` and so the contest matrix). The unit tests call
`ScoreQSO`; their `PointsOnBand` helper, which reproduced the engine's order,
is deleted -- `PointsFor` now takes an optional band and calls `ScoreQSO`.

**DECIDED: the dupe policy is `TContestBase.MarksDupes`**, read by `logsubs2`
through `ContestIdentity(Contest)` (what a contest IS -- it carries no station
-- and it answers for classless contests too). The base reads the row:
`QP <> AlwaysOnePointPerQSO`, exactly what the global held with no override
stated. Internet Sprint and the Youth Championship of Russia, the two rows that
say `AlwaysOnePointPerQSO`, state `False`.
`Test_MarksDupesIsTheRowsDupePolicy` checks every `ContestType` against the
row.

**The secondary readers, sorted by where their rule lives** (§2's table):
dupe marking moved now (stage 2's dupe rule, §7.7); the three exchange-parsing
tests and the RussianDX initial exchange go to M5 with `ParseReceivedExchange`;
the five `TotalScore` formulas go to M6 with `CombineScore`. Moving those now
would mean inventing their seams ahead of the milestone that designs them --
"a virtual is added when its responsibility actually moves" (§1.2).

**BEHAVIOUR CHANGE, stated explicitly.** Before M3 an operator's
`QSO POINT METHOD` line also switched dupe marking: a spelling that selects
`AlwaysOnePointPerQSO` -- `ONE POINT PER QSO` does, through the rotated
spelling table (§7.2) -- turned dupe marking OFF for any contest, and
stating anything else for Internet Sprint or SRR-JR turned it ON. **Now dupe
marking follows the contest and ignores that line.** This is the end state --
the setting retires at M10 -- and it is the same thing that happened to points
at phase F. The other secondary readers still follow an operator's statement
until M5/M6. With no statement, nothing changed: the matrix stayed 185
identical.

**PINNED: an off-band multiplier does not mark the multiplier worked**
(§7.4). `uTestOffBandCredit` drives the real `Sheet.SetMultFlags` and
`Sheet.AddQSOToSheets` on the program's `uMults.mo`, Idaho, mult by mode: 30 m
Ada gets no flag and the sheet counts nothing; 20 m Ada is still new; 40 m Ada
is NOT new (the positive control -- without it the second assertion would pass
on a sheet that never marks anything).

**FOUND, recorded for M8 -- the dupe half of §7.4 does not hold in general.**
`logsubs2.LogContact` adds every logged QSO to `CallsignsList`, and
`TCallsignsList.AddCallsign` sets the `AllBands` bit with no band question. For
a contest whose QSOs are **not** counted per band, an off-band QSO therefore
makes a later on-band QSO with the same station a dupe, and is itself marked a
dupe of an earlier on-band one. No shipped contest reaches it: the only contest
that states its bands, Idaho, counts QSOs per band. It needs the same
`ContestCreditsBand` question at `AddCallsign` (and in `CallIsADupe`), with a
pin through `CallsignsList` -- a leaf unit, so the test program can drive it.

**Gates:** the contest matrix 185 identical; unit tests 0 failed; narrowing
1335 and range warnings 4, both unchanged; `Lint-ContestNameTests` unchanged --
M3 moved point-method tests, not contest-name tests, so no ceiling moves.

**Not M3 yet:** the family bases and the retirement of `TContestFixedPoints`
(§1.5), which this row of §8.2 also names.

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

- **Q1** (C2). **RULED 2026-10-01 (NY4I): ARRL Field Day has NO multipliers at all.**
  `NoDXMults` (the setup arm) is right and the class's `ARRLDXCC` is wrong; the
  class is corrected before M2 makes it the source. **Done at M2: the class and
  the row both say `NoDXMults`** (`Test_FieldDayHasNoDXMultiplier`). A DX station CAN be worked:
  it sends a class and `DX` (e.g. `1D DX`) where a US station sends a section
  (`1A WCF`). **DX IS NOT AN ARRL SECTION.** It goes in the section POSITION of
  the Cabrillo QSO line but NOT in ADIF's `ARRL_SECT` -- the Field Day class
  already emits it that way. NY4I: legacy used one `QTHString` for both, which
  is why the interchange worked, *"but I find it better to be explicit about the
  source and never call DX an ARRL section."* So the Field Day exchange models
  section and DX as distinct (M4 export, M5 import/parse); `QTHString` is not
  the representation.
- **Q2** (old Q2, Finding 1). **RULED 2026-10-01: no.** Nothing is fixed for the
  interim; the table retires with the setting, and Idaho gets its own class (§7.2).
- **Q3** (C1 + old Q1, Finding 2). Every corpus log stores the seven settings as
  `NONE` / `UNKNOWN`. Establish which code writes them and why they are not
  applied, before M2. Should a stored sentinel then read as "not stated"?
- **Q4** (new; the residue of C5). Do `EXCHANGE RECEIVED`, the four multiplier
  commands and `INITIAL EXCHANGE` retire with `QSO POINT METHOD` at the
  endpoint? **Recommended yes**, since they select from shared sets in the same
  way. ~~The Idaho config uses three of them~~ -- no longer: Idaho has its
  `ContestType` and class (2026-10-01, §7.2) and its `.cfg` sets none of them.
- **Q5** (C6). Should the Salmon Run W7DX bonus be implemented now, or stay
  recorded as missing? The bonuses-as-data shape (§5) is recommended.
- **Q6** (C7). POTA as a contest class (recommended, §6), keeping the root name
  `TContestBase`, with "contest" meaning "an operating event with rules" as
  `ContestType` already does?
- **Q7** (C8). Apply the NRAU ruling to every two-mode pair (§1.5), including
  pairs where one mode is rarely run?
- **Q8** (C9a, plus Idaho). Events with no `ContestType` are identified by
  string. These are `'TRC'`, `'PGA'`, `'EURASIA'` and `'DL-DX-RTTY'` (inventory
  D7). Should each become a `ContestType` with a class, or be deleted?
  **Idaho is answered** -- it became `IDAHOQSOPARTY` with a class on
  2026-10-01 (§7.2).
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

- **Q14** (M2, sponsor data). **`nc_cty.dom`, the North Carolina file
  out-of-state stations load, is not a list of NC counties.** It includes
  `S50.DOM` (the states) and declares `Dc` and the thirteen Canadian
  provinces, then the counties. The sponsor's out-of-state multipliers are the
  100 counties (https://ncqsoparty.org/rules/), but the frozen matrix shows an
  out-of-state NC entrant scoring `CT` and `ON` as domestic multipliers. Now
  that in-state detection works (defect #1), the same file also makes a DC or
  Canadian station that states its own S/P (`ON`) "in state" for NC, and the
  matrix's ve variant moved that way. D7 used the same rule on the same file.
  `nc.dom`, the in-state list, already includes `S50`, `P13` and
  `NC_CTY.DOM`. **Should `nc_cty.dom` hold the 100 counties only?** That
  would correct both. It is a data change that moves NC's out-of-state
  scoring, so it is NY4I's decision.

**Answered by the ruling, and dropped:** C3 (`CreateOwned...`), C4 (the
exchange-field model), C5 (`EXCHANGE RECEIVED` as a strategy swap; its residue
is Q4), C10 (multiplier strategies last), old Q3 (the secondary readers all go
to the contest), old Q4 (point-table units), old Q6 (the overrides stay ahead of
the class).
