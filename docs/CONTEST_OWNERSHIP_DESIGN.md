# What a contest owns -- DESIGN (M0-M10 built; M11 next; see §8.2)

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
| identity: enum, display/friendly/Cabrillo name, ADIF id and former ids, WA7BNM, QRZ.RU, e-mail | **the class, and every consumer asks it** (M1, done 2026-10-01) through `uContestRegistry.ContestIdentity`. An ADIF id two contests share (RSGB-ROLO) is told apart by the record's MODE once the record is read (M7b batch 2, §8.2k) | existing properties (**existing**); `RunsInMode` (M7b batch 2) |
| sponsor parameters: county-line max, legal classes, host state, mult by band/mode, WARC allowed, dupe policy, off-time minimum, max contest dates | split across the class, `ContestsBooleanArray`, `FoundContest` arms and `postunit` | one property per fact |
| exchange parsing and validation | **the class, for every contest** (M5b, done 2026-10-02): `logstuff.ProcessExchange` asks it after the contest-blind gate; the base parses the session's shape through the engine's `ParseExchangeShape`, handed in as data. The UA4W Championship's rule, held in LOGSTUFF at M5b (§8.2g), is its class's since 2026-10-14 (§8.2p) | `ParseReceivedExchange`, `MayBeACallsign`, `InitialExchangeFromCall` (**existing**), plus the validators |
| ADIF export: sent exchange and contest fields | **the class, for every contest** (M4, done 2026-10-01): PostUnit and uADIF ask `ContestIdentity`; the base's default is uADIFExchange's shared arm for the session's exchange. ARRL 160 left PostUnit's tail at M7b (§8.2j) and POTA, the last contest named there, when it gained its class (§8.2o) | `FormatADIFSentExchange`, `EmitADIFContestFields`, `EmitADIFExchangeFields` (POTA, §8.2o), `ADIFPowerTag`, `WritesADIFContestId` (**existing**) |
| ADIF import interpretation | **the class, for every contest** (M5a, 2026-10-01): `uADIF.ApplyADIFContestImport` asks `ContestIdentity` after the whole record is read; the base's default is the old classless `else`. ARRL 160's arm moved to its class at M7b (§8.2j) and POTA's at §8.2o, which deleted `MainUnit.ApplyClasslessADIFImport` | `ApplyADIFImport` (**existing**, §3.2) |
| Cabrillo: QSO columns, line layout, headers, mode string | columns and line layout: **the class, for every contest** (M4), the base's default being uCabrilloExchange's shared arm; the contest-specific header lines and the mode column: **the class** (M9a, §8.2m); the general header: `postunit` | `FormatCabrillo...Exchange`, `CabrilloQSOLineFormat` (existing); `CabrilloContestName`, `RequiresCabrilloLocation`, `CabrilloHeaderLinesBeforeTag`, `CabrilloModeString` (**existing**, M9a) |
| session setup: memories, settings defaults, domestic file and countries, band/mode | **the class, for every contest that has one** (M7a, done 2026-10-02): `FoundContest` asks `DescribeSession` and `FCONTEST.ApplySessionDefaults` writes it; LogCfg's CQ-exchange default is `CQExchangeDefault`. M7b gave the classless contests classes (batch 1, thirty-nine, §8.2j; batch 2, forty, §8.2k); `FoundContest`'s `case` is gone: POTA's arm became its `DescribeSession` (§8.2o) and the UA4W Championship's, the last, its own (§8.2p) | `DescribeSession`, `CQExchangeDefault` (**existing**, §4, §8.2i) |
| total score and bonuses | **the class, for every contest** (M6, done 2026-10-02): `logedit.TotalScore` gathers the totals and asks `FinalScore`, and names no contest: RSGB 1.8 MHz's "times one", held there at M6 (§8.2h), is its `CombineWithMultipliers` (§8.2p) | `FinalScore` = `CombineScore` + `BonusPoints`; `CombineWithMultipliers`, `BonusStations` (**existing**, §5) |
| multipliers and dupes | **the sheet keeps the state; the class declares the rules** (M8, done 2026-10-02, §8.2l): the kinds and by-band/by-mode traits, `UsesBand` (now asked by the dupe sheet and the need-multiplier hint too), `CountsAsMultiplier` (asked by `logdupe.SetMultFlags`), `MarksDupes`, and the hint's `DomesticMultiplierFromCall`. A multiplier KIND's arm stays in the sheet until the multiplier commands retire (Q4). RSGB 1.8 MHz's scoring ASKS the sheet, read-only, through the station context (7.13, §8.2p) | `CountsAsMultiplier`, `DomesticMultiplierFromCall` (**existing**, M8); `MarksDupes`, `UsesBand` (**existing**); `TStationContext.IsNewMultiplierAnywhere` (**existing**, §8.2p); the multiplier KEY at M10 |
| summary sheet, totals window, new-contest prompts, hour report, HamScore's canonical exchanges, score-posting labels, operating aids, the QTC menu | **the class, as data the UI renders** (M9a, done 2026-10-02, §8.2m); uNewContest names no contest (POTA's arms moved at §8.2o, RSGB 1.8's and the UA4W Championship's at §8.2p, and `ClasslessPrompts` is deleted); POTA's park menu rows are `OffersParkTools` | `SummarySheet`, `TotalsDisplay`, `DescribeNewContestPrompts`, `ReportsRunningScore`, `CanonicalReceived/SentExchange`, `ScorePostingMultiplierType`, `PermittedOperatingAids`, `OffersQTCs` (**existing**, M9a) |
| the New Contest drop-down's name and place, call entry's contest status, the ten-date warning, WARC band stepping, the FOC# log column, a frequency warning | **the class, as data the UI renders** (M9b, done 2026-10-02, §8.2n); the off-time minimum stays named (Q60) | `DisplayName`, `IsActive`, `ShowsContestStatus`, `MaximumContestDates`, `BandStepIncludesWARC`, `PowerFieldIsFOCNumber`, `CallEntryFrequencyWarning` (**existing**, M9b) |

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

### 1.5 Families, and what `TContestFixedPoints` became

A base class is justified only for **a family**: contests under one rule, where
a rule change reaches every member by definition.

**As built at M3 (2026-10-01).** `Test_EveryClassSitsOnTheBaseOrAFamily` holds
this list closed: every registered class's parent is `TContestBase` or one of
these bases, and each base sits on `TContestBase` itself.

```
TContestBase
+-- TContestStateQSOPartyBase        county line, host state (abstract)
|   +-- one class per single-state party
+-- TContestARRLDXBase    -> CW, Phone
+-- TContestARRLSSBase    -> CW, SSB      (reparented off TContestFixedPoints at M3)
+-- TContestCQWWBase      -> CW, SSB
+-- TContestCQWPXBase     -> CW, SSB
+-- TContestNRAUBalticBase -> CW, SSB     NY4I's ruling; built at M3
+-- TContestNASprintCW, TContestNASprintRTTY      SIBLINGS, no base (DECIDED at M3, §8.2d; Q7)
+-- TContestARRLFieldDay, TContestWinterFieldDay    no shared base -- NY4I's ruling
+-- TContestSprintSSB                     its own contest, NOT an NA Sprint -- NY4I's ruling; built at M3
+-- TContestPOTA, TContestGeneralQSO      section 6 (POTA built 2026-10-13, §8.2o)
+-- the M7b classes -- CQ WPX RTTY, CQ WW RTTY, 7QP, NEQP, the JIDX, All
|   Asian and Oceania pairs, the EU Sprints, the ARRL VHF runnings and the
|   rest -- each directly: no family, DECIDED on evidence (§8.2j); batch 2's
|   forty the same -- UCG and WWIH copy CQ's arms, the King of Spain, REF,
|   RoPoCo and Region 1 RCC pairs are siblings (§8.2k)
+-- every other contest, directly -- 24 of the 25 former TContestFixedPoints
    subclasses among them (the 25th was TContestARRLSSBase), each calling
    FixedModePoints
```

- **Every other two-mode pair follows the NRAU ruling.** That covers JIDX, All
  Asian, SAC, UBA, RSGB RoPoCo, King of Spain, DARC WAEDC, RF Championship,
  CQ 160, NAQP's three modes, the EU Sprints and Cup RF. A `Base` holds the
  contest, and each mode class states only its identity. **One class per
  `ContestType` and one `RegisterContest` per unit still hold** (Q7).
  **That extension is Q7 and is NOT applied yet** (M3): NY4I's ruling names
  NRAU-Baltic, and none of the pairs listed has a class. The one existing
  pair it would have reached, the NA Sprint CW/RTTY, was left as siblings on
  evidence (§8.2d).
- **The multi-state parties (7QP, NEQP) stay open**, for the reason
  `uContestStateQSOPartyBase`'s header gives. Since M7b 7QP and NEQP each
  have a class on `TContestBase`, keeping exactly today's behaviour; whether
  they share a base is Q40 (§8.2j). IN7QPNE is not a family member either:
  it is a COMPOSITE that holds the four party contests and delegates each
  QSO (7.14, §8.2r).

**`TContestFixedPoints` and `FixedModePoints` -- recommendation (Q12).
DONE at M3, 2026-10-01 (§8.2d):** the base is deleted, the helper kept in
`uContestFixedPoints`, and all 25 subclasses moved -- as one step rather than
per family, because only one of them (ARRL SS) had a family, and its base
already existed. The bullets below are the reasoning, kept.

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
  | exchange parsing, `logstuff` `ProcessRSTAndQSONumberOrDomesticQTHExchange` x3 (RAC: CANADA_WINTER/CANADA_DAY; PCC; Arktika Spring) | that contest's `ParseReceivedExchange` | **MOVED, M5b** (§8.2g) |
  | initial exchange, `zonecont.GetVEInitialExchange` (RussianDX: RDXC, RU3AX MEMORIAL -- a UA oblast) | that contest's `InitialExchangeFromCall` | **MOVED, M5b** (§8.2g) |
  | total-score formulas, `logedit.TotalScore` x5 (WAE weighted mults; CupRF +100, ALRS +300, ChampionshipRF +50, OZHCR +1000 per mult) | that contest's `CombineWithMultipliers` (§5) | **MOVED, M6** (§8.2h) |

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

**DONE at M5a (§8.2f).** **`APP_N1MM_EXCHANGE1` is why the interpretation must
wait for the whole record.** `uADIF.ApplyADIFFieldsToExchange` interprets that tag per contest
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
| `ProcessImportedSRX_String` (Field Day) | ~~the Field Day classes' `ApplyADIFImport` calling their own `ParseReceivedExchange` on the SRX text~~ -- **deleted at M5a, it had no caller** (§8.2f); M5b made the import stop calling DX a section instead (Q25, §8.2g) |
| `logstuff.ResolvePOTAParkFromADIF` (D5's fix, `3f9e3f28`) | POTA's `ApplyADIFImport` -- **DONE** 2026-10-13; the helper is the leaf `uPOTAReference` (§8.2o) |
| `EmitContestSpecificTailForExport` arms | `EmitADIFContestFields` of each contest named. The no-op arm (D6) is deleted. **DONE at M4** but for POTA and ARRL 160 (§8.2e); ARRL 160's moved at M7b (§8.2j), POTA's on 2026-10-13 (§8.2o) |
| the `Contest` tests inside the `uCabrilloExchange` / `uADIFExchange` arms (FOC, JIDX, PACC/SPDX, CQVHF, PCC, ...) | that contest's own formatter. **DONE at M4**; JIDX's, CQ VHF's and SP DX's were dead and were deleted |
| `FormatsExchange` | ~~stays as the per-contest opt-in while migrating~~. **DELETED at M4**: every contest is asked, and the base's answer is the shared arm |
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

**Item 3 changed at M7a (2026-10-02, §8.2i).** Every arm for a contest that
has a class is that class's `DescribeSession`; the `case` holds the classless
contests' arms only.

### 4.2 Target

**BUILT at M7a (2026-10-02, §8.2i)**, as below with three refinements: the
contest object is `ContestIdentity` (M1's accessor serves as
`ContestDefinition`); the defaults object is `TSessionDefaults`, a class
because each value has a third state, NOT STATED; and the station arrives as
`DescribeSession`'s parameter, `uContestFactory.CurrentStation`, because the
identity object carries none. `InHostState` was already in it (M5b).

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

**BUILT AT M6 (2026-10-02, §8.2h).** There is **one** computation,
`logedit.TotalScore`, and every consumer reads it: the score display
(`logwind`), the summary sheet and Cabrillo `CLAIMED-SCORE` (`postunit`), the
XML score report (`logsubs2`) and the two score-posting clients (`uGetScores`,
`uHamScore`) (`git ls-files 'tr4w/src/*.pas' | xargs rg -n -i -w "TotalScore"`).
So the seam went in exactly one place, and nothing downstream changed.

`TotalScore` gathers the totals and asks the session's contest:

```
final score = contest.FinalScore(totals, view)
            = CombineScore(totals) + BonusPoints(totals, view)
```

| piece | where | what |
|---|---|---|
| `TScoreTotals` | `uContestBase` | a RECORD -- an interface parameter, pure data. QSO points (the log's stored points; a single-band entry's band only), QTC points, the sheet's multiplier counts and the QSO counts by band, mode and kind, the scored band, and the session's facts (counts multipliers? its exchange, its DX multiplier) |
| `TLoggedQSOView` | `uContestBase` | an ABSTRACT CLASS with `Count` and `QSO(i)` and nothing that writes: the whole log, every record `QSOCountsTowardTotals` accepts (the set the log's loader counts, dupes included). The application's is a `TLoggedQSOList` **kept beside the totals** (`uScoreTotals`): emptied with them, filled by the log's loader and by live entry, so it costs memory, not a database read per score; a test hands in its own |
| `GatherScoreTotals`, `ResetLoggedQSOs` / `AddLoggedQSO`, `ContestFinalScore` | `uScoreTotals` (new, `src/`) | the application's half: the sheet and counters into the record; the view kept where the totals are kept; the active contest (else its identity) asked |
| `FinalScore` | `TContestBase`, **not virtual** | the one entry point; a bonus cannot be folded into the formula or applied per QSO |
| `CombineScore` | `TContestBase`, **not virtual** | a TEMPLATE: a session with no multiplier, or the FISTS exchange, scores its points -- TotalScore's first two tests, which name no contest -- otherwise `CombineWithMultipliers` |
| `CombineWithMultipliers` | protected virtual | the base is TotalScore's general case: points times the sum of every multiplier kind on the scored band |
| `BonusPoints` | virtual | the base pays the DECLARED bonus stations over the view (`BonusStations`, `TBonusStation`: call, points, once or once per mode); a contest with a rule of its own overrides and adds `inherited` |
| `CountsTowardBonus`, `CreditsBonusMode` | protected virtual | which contacts and which modes a declared station is paid for (base: every contact, every mode) |
| `TalliesLiveQSO` | virtual | **a preserved defect, not a seam to use** -- Missouri's live-only peak-hour count (Q32) |

| today's `TotalScore` arm | went to |
|---|---|
| ARRL Field Day (points only); Winter Field Day (band-mode mults x points x power factor) | `CombineWithMultipliers` of each |
| WAE weighted mults; Cup RF / ALRS / RF Championship / Ukraine Championship / OZHCR `points + N x mults`; Ural Cup | `CombineWithMultipliers` of each. **Nine of these contests had no class** and gained one (§8.2h) |
| RSGB 1.8 MHz "times one" | ~~stays named in `TotalScore`~~ -- `CombineWithMultipliers` of RSGB 1.8, since 2026-10-14 (Q33 ruled; §8.2p) |
| FISTS "mults don't work" short-circuit | **the template** -- it keys on the session's EXCHANGE, not on a contest |
| Missouri W0MA/K0GQ +100 each | `BonusStations` of Missouri, counted over the whole log |
| Missouri peak hour | `TalliesLiveQSO` + Missouri's `BonusPoints` -- **unchanged, including its defect** (Q32) |
| Salmon Run W7DX | **IMPLEMENTED** (Q5): a declared station, 500 once per mode, CW and phone, a single-mode entry once |
| North Carolina +50 callsigns (D3) | **not a bonus** -- gone with the legacy arm (2026-09-29). The sponsor's Rarest-of-NC **sweep** (+500 once, five of ten counties) is **IMPLEMENTED** as NC's `BonusPoints` |
| Idaho dormant county (7.5) | **IMPLEMENTED** as Idaho's `BonusPoints`, fixed stations; the rover is Q34 |

**Bonuses are declared data plus a read-only view, never a log query of the
contest's own making.** The design said "data plus a count" here before 7.7
was decided; 7.7's read-only view is what was built, because a count the
application computed would have needed the application to know each bonus
rule. The contest still cannot reach the log: it is handed a view that only
reads, and the order in which callers ask it cannot change what a log scores,
because every answer is computed from the whole log.

**The corpus sees this.** `golden_diff.py` keeps `CLAIMED-SCORE:`
(`ADDING_A_CONTEST.md` §4). That value is arithmetic over **stored** points and
recomputed multipliers, so a `CombineScore` / `BonusPoints` move IS visible for
the 13 sets -- and stayed byte-identical at M6, the Winter and ARRL Field Day
sets included. The contest matrix's `totals` section (M6) sees it for every
contest. None of the four bonus contests has a corpus set, and the matrix's
synthetic QSOs trigger none of the bonuses, so **their proof is
`uTestContestTotals`** plus a `BENCH_QUEUE.md` item.

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

**BUILT 2026-10-13 (§8.2o)** on NY4I's ruling of Q6: *"yes, make POTA a
contest class. while it is not a contest per se, just like with GENERAL QSO,
we treat it that way."* `TContestPOTA` sits on `TContestBase`. Of the four
bullets above, the first two are built as written; the n-fer stayed the
engine's (its queue is the `RSTAndPOTAPark` exchange shape's, which is
LOGSTUFF's until M10, Q4) and no limit was added, because none existed to
transcribe; dupes allowed is its `DescribeSession` (`AllowDupeQSOs`), as the
arm wrote it. The three helpers were lifted as leaves -- `uPOTAReference` and
`uGridShape` -- rather than handed in as services: each is pure.

*History, kept for the reasoning:* **NOT BUILT AT M4, on evidence (DECIDED, §8.2e).** M4 offered POTA a class for
its export alone. It was declined: Q6 is NY4I's and still open; POTA's export
leans on three TRDOS helpers a class may not call (`logstuff.IsValidPOTAPark`,
and `Tree.LooksLikeAState` and `Tree.LooksLikeAGrid`, the last of which reads
the `ActiveExchange` global), so a class would first need three lifts; and a
registered class takes over scoring and validation the moment it exists. So
POTA's three tail tests in PostUnit and its `CONTEST_ID` test in uADIF stay,
and are the next thing to move when Q6 is answered.

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
2026-10-01) -- ~~which does NOT hold today for a contest whose QSOs are not
counted per band~~ **HOLDS SINCE M8 (2026-10-02, §8.2l)**: until then
`TCallsignsList.AddCallsign` marked the `AllBands` bit for every logged QSO,
off-band included (§8.2d). It now marks no dupe bit for an off-band QSO,
and `CallsignIsDupe` calls no off-band QSO a dupe. No shipped contest
reached the defect -- Idaho counts QSOs per band -- and the unit tests pin
it with QSO-by-band turned off.

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

~~**Not covered yet:** the "is this a new multiplier" display hints
(`EditableLog.DetermineIfNewMult` and its neighbours) read the multiplier sheet
directly. They can still highlight an off-band call as a needed multiplier,
although logging it gives no credit.~~ **COVERED AT M8 (§8.2l):**
`DetermineIfNewMult` answers no on an off-band band, the needs strip clears
every band the contest does not use (`uContestBase.CreditedBands`), and the
"new multiplier" indicator stays off while the operator is on one. Hiding WARC from band stepping
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
nothing else moved.

**The dormant-county bonus LANDED at M6 (2026-10-02, §8.2h)**, from the
sponsor's "2027 Bonus" table: an in-state station whose MY STATE county is
listed earns its 500 or 1000 once the log holds ten valid QSOs (not dupes, on
an Idaho band). A rover is scored as a fixed station in its MY STATE county
-- no QSO records the county it was sent from (Q34); the sponsor's two pages
differ on ten against more than ten (Q35).

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

~~Lands with the UI work (M9b)~~ **LANDED at M9b (2026-10-02, §8.2n).** The
summary window's CATEGORY-POWER row writes `Settings.Contest.CategoryPower`
through `SetCFGCommandValue`; `uCbrSum.CabrilloTagText` answers the header's
CATEGORY-POWER from the setting; a change with QSOs logged rescores through the
Rescore command (`MainUnit.RescoreLog`) and shows a notice. The New Contest
dialog sets it as before and never reminds.

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
~~none does today~~ -- **one does, measured at M6**: RSGB 1.8 MHz's arm pays 7
for a contact that is a new multiplier on the sheet (`mo.isdmmult` /
`mo.isdxmult`). ~~It is the reason that contest has no class yet~~ -- NY4I ruled
(7.13) that stage 1 may ASK the sheet read-only, and the class was built on
2026-10-14 (§8.2p).

**Stage 3 LANDED at M6 (2026-10-02)** -- `FinalScore` = `CombineScore` +
`BonusPoints`, the contest handed a `TScoreTotals` and a read-only
`TLoggedQSOView` (§5, §8.2h).

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
  resolver alone moved 0 of 185 records. **DONE at M7a (§8.2i):** each of
  those classes states both branches in `DescribeSession` on
  `aStation.InHostState`.
- **D8's UNCONDITIONAL DISAGREEMENT, Field Day's DX multiplier, was corrected
  first (Q1):** both the class and the row now say `NoDXMults`, so the value
  the head starts from is the value the arm ends with.
- **The in-state test keeps D7's rule**: MY STATE is a key of the county file.
  It differs in one way: the comparison ignores case. EnumDOM2 upper-cased the
  line but not MY STATE, and a county code is not case-significant anywhere
  else. **The rule takes the data at its word**, and one file abuses it (Q14).

### 7.10 RULED (NY4I, 2026-10-02): exchange validation refuses an invalid station

- **QSO parties -- out-of-state works only the host state** (answers Q14). *"In QSO
  parties, out of state stations usually only log the state county. It's not valid
  for a fl station to work an Idaho or VE station in the NC QSO party."* In-state
  stations work everyone. This is the DEFAULT on the state-QSO-party base; a party
  whose sponsor differs overrides it. So `nc_cty.dom` holds NC's 100 counties only.
- **An invalid station is REFUSED, with an error** -- *"It's an invalid station so
  we should refuse to log it and show an error like we would with an invalid
  county"* -- *"or with a bad ARRL section"*. NOT the off-band treatment (7.4):
  off-band is a legal QSO with no contest impact; this is an exchange that is not
  valid for the contest.
- **Sweepstakes without a precedence** (Q19): *"A sweepstakes entry should not have
  been logged without a precedence"* -- refused at entry. The blank-not-NUL export
  (defect #4) stays as the safe output for a record already in a log.
- **Field Day DX export** (Q20): `CLASS` is whatever was logged (usually `1D`);
  `ARRL_SECT` is never written for DX (*"class and section are different"*);
  `SRX_STRING` is the full received exchange, `1D DX`.
- **OPEN:** NY4I also wrote *"or DX on field day"* alongside the bad-section
  example; asked whether that is an existing-error example or a ruling to refuse
  DX in Field Day (which would contradict 7.1). Until answered, Field Day keeps
  accepting `DX`.

~~Lands in M5b (parsing and validation move onto the classes).~~ **LANDED at
M5b, 2026-10-02 (§8.2g)**, but for the OPEN item, which is unchanged: Field Day
still accepts `DX`.

- The QSO-party default is `TContestStateQSOPartyBase.ParseReceivedExchange`;
  no party overrides it (every class's header and code was read for an
  exception, and the NC sponsor's page was read: *"Stations outside of North
  Carolina (Non-NC) work NC stations only"*). `nc_cty.dom` is the hundred
  counties of the sponsor's abbreviation list.
- Sweepstakes: `TContestARRLSSBase.ParseReceivedExchange` names the missing
  precedence. The shape parser already refused such an exchange -- silently.
- Field Day DX export and import: `FormatADIFReceivedExchange`,
  `EmitADIFContestFields` and `ApplyADIFImport` on both Field Day classes.

### 7.11 DECIDED (2026-10-02, delegated): a contest never writes a station setting (Q39)

Canada Day/Winter blank MY STATE for an outside station and the Russian cups put
the grid there -- moved exactly in M7a (`db6c1477`). MY STATE is a STATION fact
stored in `tr4w.json`, so a later settings save can carry the contest's value out
of the contest. End state: the contest states its SENT exchange in a
contest-scoped value (TSessionDefaults / the contest log, never the station
bucket), and MY STATE stays what the operator set. Lands with the sent-exchange
and Cabrillo-header work (M9); behaviour of the sent exchange must not change.

**LANDED at M9a (2026-10-02, §8.2m).** `TSessionDefaults.SentState` (was
`MyState`) is held by FCONTEST as the session's (`SentMyState`), every reader
of the sent exchange asks it, and MY STATE is never written by set-up --
`Test_SetUpNeverWritesMyState`; the matrix's setup section moved in exactly
the seven contests that state one, and nowhere else. A transient MY ZONE write
in one shared set-up routine is Q57.

### 7.12 RULED (NY4I, 2026-10-13): station facts are a DEFAULT a contest may override (Q28)

*"Add my CQ zone to the station context. But it can be overridden. Case in point: I take my
laptop to CQ zone 3 in Utah for a contest, so just that contest is CQ zone 3. So just as with
things like state and section, we use station config as a default but allow the override at
contest selection time."* So MY CQ ZONE, MY STATE and MY SECTION (and the like) resolve as: the
contest's override if the contest has one, else the station configuration. The override is
chosen at contest selection (New Contest dialog), stored with the CONTEST (its log), and never
written to `tr4w.json`. This is also where 7.11's SentState belongs. UA4W reads MY CQ ZONE from
the station context through this resolver.

**LANDED 2026-10-13.** No contest gained a class. UA4W is not built here --
it was built on 2026-10-14 (§8.2p).

**Measured first.** Every station fact the New Contest dialog can ask for
(`TNewContestField`) was a `TMySettings` property. `TMySettings` is not
contest-scoped, so it is streamed into `settings/tr4w.json`. The dialog's
values, a contest `.cfg`'s and the log's own rows on reopen all reached
those properties through `CheckCommand(.., True)` and `TrySetByCommand`.
Any later `SaveSettings` in the session wrote the contest's value into the
station's file. Those saves are a Preferences edit (`TModelSetting.TrySetText`),
the insert-mode toggle (`MainUnit`), and a changed value through
`ApplyAndStoreCommand`. So this was a 7.11-class defect for all twelve
dialog fields, not only MY STATE. MY ZONE had one more effect: setting it by
name latched `ZoneWasSet`, so the station's zone stopped following MY CALL
for good.

| fact | command(s) | dialog field | today's readers |
|---|---|---|---|
| state | MY STATE, MY QTH | yes | legacy scoring arms, in-state test, sent state fallback, cluster token |
| section | MY SECTION | yes | station context, Cabrillo/ADIF, score posting, cluster token |
| CQ zone | MY ZONE | yes | station context, legacy scoring, zone messages, Cabrillo zone, readiness, cluster token |
| ITU zone | MY ITU ZONE | no (a `.cfg` can state it) | IARU's sent zone, score posting |
| grid | MY GRID | yes | distance scoring, beam headings, Cabrillo/ADIF/EDI, readiness, cluster token |
| name, FD class, check, prec | MY NAME, MY FD CLASS, MY CHECK, MY PREC | yes | station context, Cabrillo/ADIF, CW macros, cluster tokens |
| park, IOTA, postal code, FOC number | MY PARK, MY IOTA, MY POSTAL CODE, MY FOC NUMBER | yes | POTA normalising and export, CW macro, Cabrillo/ADIF |

**The mechanism.**

- **Storage in the program.** `TMySettings` holds an override per
  `TStationFact` beside each published property. The overrides are not
  published, so they are never streamed. The published property stays the
  station's value. Preferences and `tr4w.json` see only that value.
- **The resolver.** `TMySettings.Resolved(aFact)` returns the override if
  the contest stated one, else the station's value. The readers use it
  through `ResolvedState`, `ResolvedZone`, `ResolvedItuZone` and so on.
- **The channels.** `uCFG.ApplyContestStatement` is the one route for the
  three contest channels: `LogCfg` (the `.cfg`), `uNewContestCommands`
  (the dialog's queue), and `LogStoreApplyContestConfig` (the log's rows).
  A station fact becomes `TryOverrideForContest`. Anything else is the
  `CheckCommand(.., True)` it always was. Every station channel is unchanged:
  Preferences, a peer, the startup load and the converter still write the
  property. `ClearContestCFGCommands` clears the overrides with the
  provenance tracker, so both reset at the same two moments.
- **Storage in the log.** This reuses 7.8's shape. A `contest` row is a
  statement and absence means the station decides.
  `uLogContestStatements.CaptureStationFactRows` writes the override as
  `contest` while it is stated. Otherwise it writes the station's value as
  `station`, the record every station row has always been. On reopen, a
  `contest` row is routed to the override before the no-op skip. The skip
  compares against the station's value, so without that order an override
  equal to the station would have been demoted to `station` at the next
  close. **The demotion `settings-config` records as open for station rows
  therefore cannot happen to a station fact.**
- **A log written before this** holds the same rows. A `.cfg` or dialog
  value was captured as `contest`, so it reads exactly as it was in force
  before. A log with no such row resolves to the station's value, which is
  also today's behaviour.

**Readers repointed** (every `Settings.My.<fact>` outside the station's own
editors and the settings unit):

- `uContestFactory.CurrentStation`. This is the station context, so every
  class sees the resolved values.
- `FCONTEST`: the `SentMyState` fallback, `FoundMyStateInDomFile`, and the
  name and zone messages.
- `PostUnit`: `CurrentMyStationExchange`, which Cabrillo and ADIF use;
  `ZoneSentForThisContest`; and the EDI and Cabrillo locator lines.
- `LOGSTUFF`'s scoring arms (68 sites, mostly grid distance and the
  classless state rules).
- `LOGEDIT`'s and `LOGWIND`'s beam heading and distance.
- `LogSend`'s CW name and postal-code macros.
- `uExchangeBuilder`; `uGetScores` (section, grid, ITU zone).
- `uTelnet`'s `MY_*` tokens.
- `MainUnit`'s and `uLogStore`'s park.
- `uProgramMain`'s grid prompt and readiness check.
- `uContestMatrix` records a fact as the contest has it, so the matrix
  still shows the `.cfg`'s station lines.

**MY CQ ZONE in the station context.** `TStationContext.MyZone`,
`MyZoneValid` and `MyZoneText` already existed and were read from MY ZONE,
which is the CQ zone. They now read `ResolvedZone`, and their declaration
says they are MY CQ ZONE, resolved. A second field would have been a second
copy of one fact. ~~UA4W can read `aStation.MyZone`.~~ **WRONG, measured
2026-10-14 (§8.2p):** an UNSTATED MY ZONE is derived in the CONTEST'S zone
mode, so in an ITU-zone contest -- the UA4W Championship is one -- `MyZone` is
the ITU zone (the matrix's K0AAA, VE3AAA and DL1AAA carry 7, 4 and 28 there),
and IARU relies on exactly that. UA4W reads the `MyCQZone` service instead:
the stated zone, else MY CALL's CQ zone. Q69 asks whether MY ZONE should
always be the CQ zone.

**DECIDED: 7.11's SentState is NOT folded into the override. It is layered
on top of it.** `SentMyState` is the contest's `SentState` when set-up
stated one, else the resolved MY STATE. There are two reasons:

1. The override is the OPERATOR's statement of where the station is. The
   in-state test (`FoundMyStateInDomFile`) reads it, and so do the cluster
   tokens. `SentState` is the contest's RULE about what to send, and it is
   computed again at each set-up. Canada Day's blank is not a location, and
   the in-state test must not see it.
2. Routing set-up's value into the override would make it a stored
   statement in the log. That is the exact mistake 7.8 forbids:
   *never route contest set-up through `TrySetByCommand`*.

**Q57 was implemented with this, by necessity.** `SetUpRSTMyZoneExchange`
used to write "zone state" into MY ZONE and put it back. With the readers
on the resolver, that transient station write would have been ignored
whenever a zone override was stated, and the state would have been dropped
from CQ WW RTTY's messages. It now builds the text in a local variable. The
messages are byte-identical, MY ZONE is never written, and `ZoneWasSet` is
no longer latched. One old edge also goes: with an empty MY ZONE, the old
code left "` FL`" in MY ZONE for good.

**A Preferences edit during a contest** changes the station's value. A
contest that overrode that fact keeps its override for that contest. A
contest that did not override it follows the edit at once. Preferences
shows the station's value and says nothing about the override (Q66).

**Tests:** `uTestStationFactOverrides` (new) covers:

- every member is a published property reached by a command;
- the default;
- an override wins and leaves the station, `ZoneWasSet` and the JSON alone;
- MY QTH is MY STATE;
- a cleared override;
- a Preferences edit mid-contest;
- refused values and names that are not facts;
- the capture's rows;
- a reopen, including no demotion at the second capture;
- a pre-7.12 log, both with a `contest` row and without one;
- `CurrentStation` carrying zone 3 and grid DN40;
- `SentMyState` falling back to the resolved state;
- `ClearContestCFGCommands` clearing the overrides.

`uTestNewContestCommands` now asserts that the dialog's class and section
are overrides and that the station's values are untouched. It also checks
that a save mid-contest keeps the station's class and section on disk.

**Questions this raised:** Q65-Q68 (§9).

### 7.13 RULED (NY4I, 2026-10-13): per-QSO scoring may ask the sheet read-only (Q33)

*"All multipliers are based on what was worked before ... when I work KP4N in a WPX contest
where prefix is a multiplier, the prior QSOs are always relevant."* 7.7's "stage 1 is a pure
function of the QSO and the station" is CORRECTED: a contest whose points depend on multiplier
status (RSGB 1.8 MHz: 7 for a new multiplier) is handed a READ-ONLY "is this a new multiplier"
answer from the shared sheet. A scoring rule still never writes the sheet or reads the log.

**LANDED 2026-10-14 (§8.2p):** `TStationContext.IsNewMultiplierAnywhere`, a read-only
SERVICE (the shape of `IsDomesticCountryCall`), and RSGB 1.8 MHz's class reads it.

### 7.14 RULED (NY4I, 2026-10-13): IN7QPNE is a composite; Delaware gets its own contest

- IN7QPNE is a logging convenience for FOUR same-weekend parties: Indiana, 7th call area (7QP),
  New England (NEQP) and Delaware. *"When I work a New England station, the rules for the New
  England QSO party apply even though I'm working underneath the combined IN7QPNE."* Each QSO
  is judged by the rules of the party the WORKED station is in; the class delegates per QSO to
  that party's class. Today's code is one rule set, so this is new behaviour, not a
  transcription.
- ONE combined Cabrillo under the IN7QPNE name; the same log goes to all four sponsors, each
  extracts its own QSOs. An IN7QPNE entrant uses the IN7QPNE name, not a component's.
- NOT posted to HamScore or the contest scoreboard. Score display is not required (nice-to-have:
  show the score of the party just worked).
- **Delaware QSO Party becomes its own contest** (type + class), from
  https://www.fsarc.org/qsoparty/rules-2024.html and .../cabrillo.htm: all HF except WARC plus
  6 m and up; DE works everyone, non-DE works DE only; exchange RST + county (DE) or RST +
  state/province/DX; points by ENTRANT location (inside DE 1/2/2 phone/digital/CW, outside
  10/20/20); multipliers once per band (DE: states, provinces, DXCC; non-DE: NDE, KDE, SDE);
  dupes per band per mode; county line = two QSOs; a DE mobile changing county is a new
  station; score = points x mults x power (>100 W x1, <=100 W x2, <=5 W x3) + 50 electronic
  bonus (decided: always applies); Cabrillo needs ARRL-SECTION:/LOCATION:, modes CW/PH/RY;
  ADIF and Cabrillo id DE-QSO-PARTY (ADIF 3.1.7).

**Delaware LANDED 2026-10-14 (§8.2q)**: `DELAWAREQSOPARTY`, `TContestDelawareQP`.
**The IN7QPNE composite LANDED 2026-10-14 (§8.2r)**: `TContestIN7QPNE` routes each
QSO to its party's class; the routing rule, the seam-by-seam table and the
superseded "transcribe today" instruction are there.

### 7.15 RULED (NY4I, 2026-10-13): legacy arms only QSO POINT METHOD reaches are deleted (Q11)

They, and the three point kinds with no arm (SouthAmerican, IN, NYQPQP), go with the setting at
M10.

### 8.1 Which oracle sees what

| oracle | sees | blind to |
|---|---|---|
| `export-d12-corpus.sh` (24/0/2 **and** exit 0) | Cabrillo `QSO:` columns, ADIF records, **`CLAIMED-SCORE`** -- 13 registered contests | per-QSO points, parsing, setup, every classless contest |
| `test-contest-factory.sh` | rescored points against the frozen legacy output -- 13 logs | parsing, import, classless contests |
| `test-adif-roundtrip.sh` | import against our own export -- 13 sets | classless contests |
| unit tests (`Build-Tests.ps1 -Run`) | a contest class against fixtures, round-trip included | anything needing globals booted |
| frozen legacy fixture -- **built (M0, 2026-10-01)**: `tr4w/test/contest-matrix/run-contest-matrix.sh` | every `ContestType` x four station variants: set-up, per-QSO scoring, the real exporters' Cabrillo/ADIF output, ADIF import (M5a) and typed-exchange parsing through `ParametersOkay` (M5b) (`ADDING_A_CONTEST.md` §4) | correctness: it only proves "same as before"; and the entry WINDOW -- whether a refusal's message shows |
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
| **M3** | **DONE 2026-10-01 (§8.2d).** **Scoring finishes on the class.** `ScoreQSO`, the one entry point (§7.7); the dupe-marking reader moved to `MarksDupes` (**behaviour change** for an operator override); the off-band multiplier pin; `TContestFixedPoints` retired (`FixedModePoints` kept as a helper); the NRAU-Baltic family base; classes for NRAU-Baltic CW/SSB, Sprint SSB, Locust and the Jock White Field Day. The other secondary readers are scheduled where their rule lives -- parsing M5, total score M6 (§2) | the contest matrix; unit tests; `test-contest-factory.sh` |
| **M4** | **DONE 2026-10-01 (§8.2e).** **Exchange export.** Each contest formats its own Cabrillo and ADIF columns and emits its own ADIF contest fields, asked through `ContestIdentity`; `FormatsExchange` deleted. Eleven contests gained classes to hold a rule an exporter named. D4's dead arms and the D6 no-op deleted; defect #4 fixed. POTA and ARRL 160 left named in PostUnit, with reasons | corpus; per-class round-trip unit test |
| **M5a** | **DONE 2026-10-01 (§8.2f).** **ADIF import.** Generic importer, then `ApplyADIFImport` (§3.2), including the `APP_N1MM_EXCHANGE1` arm, pinned in both tag orders. Thirteen contests gained classes; `ApplyContestSpecificADIFTail` and the dead `ProcessImportedSRX_String` deleted; defect #6 fixed; WAG's DOK and IOTA's IOTA read back. ARRL 160 and POTA keep an arm | `test-adif-roundtrip.sh`; the matrix's `import` section; the corpus; per-class unit tests |
| **M5b** | **DONE 2026-10-02 (§8.2g).** **Exchange parse.** `ParseReceivedExchange` per contest, the base reaching the engine's shape parsers through the session as data; the matrix gained a `parse` section first. Seven contests gained classes; D1/D2 deleted; NY4I's 7.10 refusals; Field Day DX export and import (Q20, Q25); `nc_cty.dom` to the sponsor's counties (Q14). UA4W stays named in LOGSTUFF, with its reason | the matrix's `parse` section; `uTestContestParse`; `BENCH_QUEUE.md` for typed entry |
| **M6** | **DONE 2026-10-02 (§8.2h).** **Total score.** The matrix gained a `totals` section first. `TScoreTotals`, the read-only view, `FinalScore` = `CombineScore` + `BonusPoints`; `TotalScore`'s arms deleted but RSGB 1.8's (Q33); nine contests gained classes; Missouri moved with its live tally preserved (Q32); the NC sweep, the Salmon Run W7DX bonus (Q5) and Idaho's dormant county implemented | corpus `CLAIMED-SCORE`; the matrix's `totals` section; `uTestContestTotals` |
| **M7a** | **DONE 2026-10-02 (§8.2i).** **Session arms of the registered contests.** `DescribeSession` filling a `TSessionDefaults`, one applier (`FCONTEST.ApplySessionDefaults`); all 55 arms naming a registered contest moved and were deleted; LogCfg's CQ-exchange defaults became `CQExchangeDefault`; D8 resolved by stating both branches; Winter Field Day's DX multiplier row and class made the effective value. No contest gained a class | the matrix (185 identical, no re-freeze); corpus; `uTestContestSession` |
| **M7b** | **The classless contests.** Each gains a class -- a family member, or a copy of the nearest class (§1.4) -- and its `FoundContest` and LogCfg arms become its `DescribeSession` and `CQExchangeDefault`. **Batch 1 DONE 2026-10-02 (§8.2j)**: thirty-nine contests, no new family; ARRL 160 handed the domestic-country lookup as a station-context service, so its import and export arms left MainUnit and PostUnit; the All Asian's former ADIF id `AL-ASIAN-DX-PHONE` went in with `ALLASIANSSB`'s class. **Batch 2 DONE 2026-10-02 (§8.2k)**: the other forty, no new family; two session values and the caption memories joined `TSessionDefaults`; `PortableStation` lifted from Tree; the RoPoCo runnings told apart on import by MODE (`RunsInMode`, a decided change). Classless on purpose: POTA (Q6 -- ruled a class 2026-10-13, §8.2o), UA4W (Q28) and RSGB 1.8 (Q33) -- both ruled and built 2026-10-14, §8.2p -- and IN7QPNE (NY4I; a composite, 7.14) | the matrix (only `contest.class =` moves; RoPoCo's phone import lines, by decision); the arm count ratchets to 0 |
| **M8** | **DONE 2026-10-02 (§8.2l).** **Multipliers and dupes**, as contest-declared rules over the shared sheet (§7.7 stage 2). `CountsAsMultiplier` and `DomesticMultiplierFromCall`; the five `SetMultFlags` rules and the four hint arms moved; YB DX's no-op deleted with ParametersOkay's copy of `SetPrefix`; the off-band dupe gap and need-multiplier hint fixed (§7.4). Multiplier-KIND arms stay in the sheet until Q4; RSGB 1.8 still classless (Q33) | corpus `CLAIMED-SCORE`; the matrix; `uTestContestMultipliers`, `uTestOffBandCredit` |
| **M9a** | **DONE 2026-10-02 (§8.2m).** **What the display and the reports show**, as data the UI asks for: the New Contest prompts, the totals window, the summary sheet, the hour report, the Cabrillo header lines and mode column, HamScore's canonical exchanges, the score-posting labels, WRTC's operating aids and the QTC menu; design 7.11 (MY STATE never written by set-up); every class states its display name, Cabrillo name and ADIF id | the matrix (only the 7.11 setting lines move); corpus; `uTestContestDisplay`; `BENCH_QUEUE.md` |
| **M9b** | **DONE 2026-10-02 (§8.2n).** **The UI itself.** The New Contest drop-down shows `DisplayName`, active contests first and inactive ones marked (`IsActive`; SA Sprint and Locust); CATEGORY-POWER is one value and a change rescores (7.6); General QSO's display rules, the FOC log columns and WAG's call-window warning are the contest's. The off-time minimum stays named -- its two readers disagree (Q60) | `uTestContestUI`; the matrix and corpus unchanged; `BENCH_QUEUE.md` (no automated gate sees the UI) |
| **Q6 / POTA** | **DONE 2026-10-13 (§8.2o).** POTA gains its class on NY4I's ruling: its FoundContest arm, its ADIF import, its three ADIF tail tests, uADIF's CONTEST_ID test, the New Contest prompts and the park menu rows move; `ApplyClasslessADIFImport` is deleted; three TRDOS helpers are lifted as leaves. Four contests are classless on purpose now | the matrix (only `contest.class =` moves); corpus; `uTestContestPOTA`; `BENCH_QUEUE.md` |
| **Q28 / Q33** | **DONE 2026-10-14 (§8.2p).** The UA4W Championship and RSGB 1.8 MHz gain classes on NY4I's rulings (7.12, 7.13): two read-only station-context SERVICES, `MyCQZone` and `IsNewMultiplierAnywhere`; FoundContest's and LogCfg's last `case Contest of` deleted, LOGSTUFF's UA4W parse rule, LOGEDIT's "times one" and uNewContest's `ClasslessPrompts` moved. Only IN7QPNE (7.14) and DUMMYCONTEST stay classless -- IN7QPNE's composite class followed the same day (§8.2r), leaving DUMMYCONTEST | the matrix (only `contest.class =` expected to move); `uTestContestFactory`, `uTestContestTotals`, `uTestContestParse` |
| **M10** | **DONE 2026-10-14 (§8.2s; plan S0-S9f, "M10 COMPLETE" at its top).** Every `ContestType` but DUMMYCONTEST has a class, the seven settings are retired, the legacy case, the point method and the tables are deleted, and the six `Active*` kind globals are one session object. The kind TRAITS and ENUMS remain, for M11. As planned: **Endpoint.** Every `ContestType` registered (Q10). `QSO POINT METHOD` (and per Q4 its siblings) into `RETIRED_COMMANDS`. The legacy case, `ContestsArray`, `ContestsBooleanArray`, the traits and the `Active*` globals are deleted, along with `QSOPointMethodArray`, `FormatsExchange` and `Test_MovedRowValuesStillMatchTheArray`. **Runs as the staged plan S0-S9 (§8.2s, `CONTEST_FACTORY_M10_PLAN.md`)**; the KIND enums go at M11 | corpus; factory gate; full unit run; the matrix per stage |
| **M11** | **The kinds move into the classes.** The multiplier and exchange KIND arms that survive M10 (about 80, on the session object S9 builds) move into the classes that use them, and the six kind enums are deleted (§8.2s) | the matrix; corpus; unit run |

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
| 4 | ARRL SS Cabrillo writes a NUL for an empty precedence | **FIXED M4.** A one-column blank (`TContestARRLSSBase`'s `PrecedenceColumn`); every later column keeps its place. Matrix: ARRLSSCW and ARRLSSSSB, the two sparse QSOs per variant. Whether such a QSO should export at all is Q19 |
| 5 | COLORADOQSOPARTY's row is shifted: `Email` holds `'colorado_cty'`, `DF` is `''` | **FIXED M2**, row and class together; no neighbouring row is shifted. Matrix: Colorado's us-host input only |
| 6 | REF's `FrenchID` AVs on an empty `CountryID` (latent) | **FIXED M5a.** `uCallSignRoutines.FrenchID` tests the length first; `Test_FrenchID` pins `''`, `F`, `FR`, `TM`, `TK` |

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

### 8.2d M3 -- what it covered (2026-10-01; DONE)

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

**M3's second part (same day): the family bases, and `TContestFixedPoints`
retires.**

**DECIDED: `TContestFixedPoints` is deleted; `FixedModePoints` stays, in
`uContestFixedPoints`, as the helper (Q12).** Measured first:
`rg -l "class\(TContestFixedPoints\)"` gave 25 subclasses. Each now states its
own numbers in its own protected `CalculateQSOPoints`
(`aQso.QSOPoints := FixedModePoints(aQso.Mode, cw, phone, other)`), with the
two-argument `SetPoints(cw, phone)` written out as `other = phone` -- what the
base's default did. Where they went:

| moved to | contests |
|---|---|
| `TContestBase`, directly (24) | AP Sprint, All JA, County Hunter, CQIR, DARC Xmas, European HFC, General QSO, Grid Loc, Internet Sprint, JA Long Prefect, Kids Day, KVP, Marconi Memorial, Mini-Test 40, Mini-Test 80, Minitest, MST, NA Sprint CW, NA Sprint RTTY, QCWA, QCWA Golden, SA Sprint, XMAS, SRR-JR |
| its existing family base | `TContestARRLSSBase` itself (CW and SSB beneath it): the family states the two points, on `TContestBase` |

It was one step, not one per family as §1.5 first proposed, because only ARRL
SS had a family and its base already existed. Nothing moved:
`Test_FixedPointContestsTranscribeTheirArms` pins every number including
digital and FM, and the matrix records of all 25 are identical.

**DECIDED: one family is introduced, NRAU-Baltic, and no other.**
`TContestNRAUBalticBase` holds the contest -- every shared row field and the
TwoPointsPerQSO rule, written as `FixedModePoints(mode, 2, 2, 2)` so that a
per-mode change is a change of numbers -- and `TContestNRAUBalticCW` /
`...SSB` state only what differs: display, Cabrillo and ADIF names, WA7BNM
id, friendly name. NY4I's ruling is the evidence: *"a NRAU_Baltic base class
then the derived SSB and CW respectively"*, *"in case they ever decide to
change points per mode."*

**DECIDED: the NA Sprint CW and RTTY stay SIBLINGS -- no `TContestNASprintBase`
(§1.5 had drawn one).** Evidence: NY4I's ruling names NRAU-Baltic only, and
extending it to every pair is Q7, still open; their rows already differ
(domestic file `naqp` for CW, `s49p8` for RTTY), so TR4W's own data does not
treat them as one rule; and the CW class owns its export while RTTY's does
not. A base would either carry CW's formatters into RTTY (an export move M4
has not made) or hold one constant. The Minitest trio and the two QCWA rows
were already decided siblings and stay so. If NY4I answers Q7 yes, the NA
Sprint base is a small, mechanical follow-up.

**The contests held from earlier slices, each a class on its own terms:**

| `ContestType` | class | parent | scoring transcribed from |
|---|---|---|---|
| `NRAUBALTICCW` / `NRAUBALTICSSB` | `TContestNRAUBalticCW` / `...SSB` | `TContestNRAUBalticBase` | `TwoPointsPerQSO`: 2 |
| `SPRINTSSB` | `TContestSprintSSB` | `TContestBase` -- NY4I: *"a different contest with a different sponsor so keep it separate"* | `OnePointPerQSO`: 1 |
| `LQP` | `TContestLocustQP` | `TContestBase` -- a QSO party by name only; `uContestStateQSOPartyBase`'s header no longer lists it | `LQPQSOPointMethod`: 1000, 5000 if the name is `LOCUST` or the call `K6VVA` |
| `NZFIELDDAY` | `TContestJockWhiteFieldDay` | `TContestBase` | `NZFieldDayQSOPointMethod`: ZL 5 CW / 3 otherwise, else 10; and **`ZoneMult := False`** for our own branch (`Station.MyZone`, 0 when unset -- what the arm's `StrToIntDef(MY ZONE, 0)` gave) |

Each states its whole row as literals and is in
`Test_MovedRowValuesStillMatchTheArray`. None states its bands, so none joins
the exception list of `Test_EveryOtherContestStillCreditsEveryBand`. None
formats its own exchange (M4) or parses it (M5). postunit's no-op arm that
names `SPRINTSSB` beside the NA Sprints (D6) was checked and left for M4; no
contest-name test was added anywhere, so no `Lint-ContestNameTests` ceiling
moves.

**ONE DELIBERATE CHANGE, outside every oracle: `NZ FIELD DAY` now imports.**
The Jock White Field Day's ADIF id was renamed to `JW-FD` on 2026-09-29 while
it had no class, and `ADDING_A_CONTEST.md` recorded that its old export
spelling could not resolve for exactly that reason. With a class it carries
`FormerADIFContestIds = ['NZ FIELD DAY']`, per NY4I's standing ruling
(*"Yes support old spellings"*). Export never writes it.
`Test_ADIFIdsResolveOldAndNew` and `Test_NoADIFIdIsClaimedTwice` pin it.

**Gates, run 2026-10-01:** unit tests 0 failed; narrowing 1335 and range
warnings 4, both at their ceilings and unchanged. **The contest matrix:
180 identical, 5 differing -- LQP, NRAUBALTICCW, NRAUBALTICSSB, NZFIELDDAY,
SPRINTSSB -- and in each the ONLY changed lines are `contest.class =`** (three
variants each, `(none -- the legacy engine)` becoming the new class). Every
set-up, scoring (points and every multiplier flag, `ZoneMult` included) and
export line is byte-identical, which is the proof the transcriptions are
exact. Those five records need re-freezing for the identity line alone,
with that reason; it was not done in this change.

**Sponsor-rule questions this raised -- NY4I's, recorded, not acted on:**

- **Q15** NRAU-Baltic: the contest calendar lists Cabrillo names `NRAU-CW` /
  `NRAU-SSB`; TR4W sends `NRAU-BALTIC-CW` / `NRAU-BALTIC-SSB`. Which is right?
- **Q16** Sprint SSB: it is its own contest, but its row's ADIF/Cabrillo name
  is `NA-SPRINT-SSB` and its friendly name *"North American Sprint, SSB"*.
  Should either change to the sponsor's own name (https://ssbsprint.com/rules/)?
  Its `XM: NoDXMults` with the `naqp` domestic file also differs from the NA
  Sprints' North American DXCC multiplier -- intended?
- **Q17** Locust: the calendar describes CW only, 80 and 40 m, no
  multipliers. The legacy arm scores every mode and band, and the row counts
  domestic multipliers from `naqp`. State the bands (`UsesBand`) and drop the
  multipliers, or leave an inactive contest as it was?
- **Q18** Jock White Field Day, against
  https://www.nzart.org.nz/activities/contests/jwfd: are ZL contacts 5 CW /
  3 phone and non-ZL 10 still the rule? Digital and FM score 3 today (they
  fall in "not CW"). The own-branch multiplier is suppressed in two places
  (the class, and `logdupe.SetMultFlags`, which also skips zone 00): does
  the sponsor count one's own branch at all?

### 8.2e M4 -- what it covered (2026-10-01)

**Every contest formats its own export, and every exporter asks it.** PostUnit's
Cabrillo writer and ADIF tail, and `uADIF.EmitADIFRecord`, ask
`uContestRegistry.ContestIdentity(c)` -- the registered class, else a plain
`TContestBase`. There is no switch deciding WHETHER a contest formats its
export; `FormatsExchange` is deleted, with every assertion about it.

| seam on `TContestBase` | what it answers | the base's answer |
|---|---|---|
| `FormatCabrilloSentExchange` / `...Received...` `(aMy, aQso, aCtx: TCabrilloQSOContext)` | the two Cabrillo exchange columns | `uCabrilloExchange.FormatCabrilloExchangeOfKind` for `aCtx.SessionExchange` |
| `FormatADIFSentExchange(aMy, aQso, aSessionExchange)` | ADIF `STX_STRING` | `uADIFExchange.FormatADIFExchangeOfKind` |
| `EmitADIFContestFields(aQso)` | the worked station's contest fields, after `CNTY` | nothing |
| `ADIFPowerTag` | which tag carries the QSO's `Power` | `RX_PWR` (FOC Marathon: `FOC_NUM`) |
| `WritesADIFContestId` | whether `CONTEST_ID` is written | True (General QSO: False) |
| `CabrilloQSOLineFormat` | the `QSO:` line | unchanged, now always asked |

`TCabrilloQSOContext` carries what the exporter has decided before it asks:
the formatted RSTs, the chosen his-QTH, the previous record's QTH and the
previous good QSO's received number (RSGB RoPoCo and Radio YOC send them
back), the record number, and the contest title. The YOC arm used to write
its "previous number" back through a var parameter; the exporter's own
`previousqsonr`, always equal and never read until now, is what it is handed.

**DECIDED: the base's default keys on the SESSION's exchange, not the
contest's `ExchangeKind` trait.** The brief said trait; the measurement said
no. In the M0 matrix, twelve contests' `ActiveExchange` differs from their row
in some station variant, because FCONTEST's arms set it per station after the
head: ARRL DX CW/SSB, ARRL 160, 7QP, Arizona, California, NEQP, Texas, Salmon
Run, JIDX CW/SSB, PACC -- measured by comparing every `active.exchange =` line
in `tr4w/test/contest-matrix/frozen/*.matrix` with that contest's `AE` in
`ContestsArray`. Keying on the trait would have changed those
contests' Cabrillo, and an operator's `EXCHANGE RECEIVED` line would have
stopped reaching it. So the exporter hands the session's exchange in as data
-- the contest still reads no global -- and when M7 turns the arms into
`DescribeSession`, the session's exchange becomes the class's own answer.

**DECIDED: the shared arms stay in uCabrilloExchange and uADIFExchange, as the
base's helpers.** They are what an exchange SHAPE looks like and name no
contest; the base calls them, nothing selects them. Moving forty arms into
`uContestBase` would have been the same bytes with a larger diff and the
golden-line tests repointed for nothing.

**The contest-named export branches, measured** (`Lint-ContestNameTests -List`
on uCabrilloExchange, uADIFExchange, postunit and uADIF at `e931f27a`, plus the
string tests in the same routines):

| branch | where it went |
|---|---|
| FOC Marathon's membership number (Cabrillo x2, ADIF x2), uADIF's `FOC_NUM` | `TContestFOCMarathon` -- sent columns, `ADIFPowerTag` |
| Ukraine Championship / Ural Cup QTH-first order | `TContestUkraineChampionship`, `TContestUralCup` (copies, §1.4) |
| UK/EI `'--'` for no QTH | `TContestUKEI` (adjusts the context, calls inherited) |
| RSGB IOTA `'------'` for no island; ADIF `IOTA` | `TContestRSGBIOTA` |
| DARC 10 m's received column | `TContestDARC10M` |
| PACC's serial in the state column (Cabrillo, ADIF) | `TContestPACC` -- reached because FCONTEST sets PACC's session to `RSTDomesticQTHExchange` |
| PCC's sent branch and its `'/M'` | `TContestPCC`; the `'/M'` branch was the PCC's alone and left the shared arm |
| CQ VHF in `RSTDomesticQTHExchange` (both exporters) | **deleted, dead**: CQ VHF runs `RSTAndOrGridExchange` in every variant |
| SP DX in the same arm (both exporters) | **deleted, dead**: SP DX runs `RSTDomesticQTHOrQSONumberExchange` |
| JIDX in `RSTZoneExchange` | **deleted, dead**: JIDX runs `RSTPrefectureExchange` |
| D4: Sweepstakes' and the Field Days' shared arms | **deleted**; only those three contests run the exchanges, and each formats its own |
| PostUnit tail: WAG `DOK`, Field Days, Sweepstakes `ARRL_SECT`, IARU `APP_TR4W_HQ`, IOTA, `ARRLDIGI, WWDIGI, BATAVIA_FT8` `GRIDSQUARE` | each contest's `EmitADIFContestFields`; the Field Day arm is copied into both Field Days |
| PostUnit tail: D6 no-op (NA Sprints, SSB Sprint, CQ 160, NAQP) | **deleted** |
| uADIF `ceContest in [POTA, GENERALQSO]` | `WritesADIFContestId` for General QSO; POTA stays named (below) |
| PostUnit Cabrillo: `Contest in [CALQSOPARTY]` his-QTH | `TContestCaliforniaQP.FormatCabrilloReceivedExchange` |
| PostUnit Cabrillo: `Settings.Contest.Name = 'WWDIGI'` his-QTH | `TContestWWDigi.FormatCabrilloReceivedExchange` |
| PostUnit Cabrillo: NAQP `TransmitterIDPos` | **deleted**: written, never read |

**Eleven contests gained a class to hold those rules** -- FOCMARATHON,
UKRAINECHAMPIONSHIP, CUPURAL, UKEI, IOTA, DARC10M, PACC, PCC, WAG, WWDIGI,
BATAVIA_FT8 -- each on `TContestBase`, each stating its whole row
(`Test_MovedRowValuesStillMatchTheArray`) and transcribing its scoring arm,
because a registered class is that contest's scorer too. `TStationContext`
grew the three fields those arms read: `MyState` (IOTA, PCC), `ContestTitle`
(Batavia's dead `'YBDXDI-FT8'` test, D7) and `LogClockUTCHour` -- a FUNCTION,
because UK/EI's arm reads the logging clock through `tGetSystemTime`, which
refreshes a global; copying the hour into every station refresh would have
spread that side effect to every contest. **`LogClockUTCHour` WAS DELETED THE
SAME DAY** when Q21 was decided: the rule reads the QSO's recorded time, and
the station context carries no clock.

*(Superseded for both: ARRL 160 left at M7b, §8.2j; POTA on 2026-10-13, §8.2o.)*
**DECIDED: POTA and ARRL 160 stay named in PostUnit's ADIF tail.** POTA: see
§6 -- Q6 is open and its export needs three TRDOS helpers lifted first. ARRL
160: its only export rule is one `ARRL_SECT` arm, but a class must also score
it, and its arm asks `ZoneCont.DomesticCountryCall` -- a CTY lookup of the call
against the domestic-country list -- which no contest can yet be handed; that
list becomes the contest's at M8. Each is one line of the tail's `case`, with
the reason beside it.

**NOT MOVED, AND WHY.** The CUP RF CW/SSB his-QTH test in the Cabrillo writer
(two classes and the CupRF distance table for one line, and it leaves out
CUP RF DIGITAL -- Q23); LABRE's and EURASIA's `Settings.Contest.Name` tests and
the shared arms' `'TRC'` / `'PGA'` tests (no ContestType -- Q8); the Cabrillo
headers and Winter Field Day's FM mode string (M9); the summary sheet (M6, M9).

**`GetStateFromSection` WAS TWO LAYERED COPIES AND IS ONE LEAF.** The Field
Days need STATE from the section, and a class may not call TRDOS. PostUnit's
function (modern names) fell back to Tree's (states, older names); nothing
else called either. Both are `uARRLSections.StateFromARRLSection`, pinned by
`Test_StateFromARRLSection`, and both originals are deleted.

**DEFECT #4 FIXED** (§8.2a): Sweepstakes writes a one-column blank, not a NUL,
for a QSO with no received precedence. **THE FIELD DAY RULING IS PINNED**
(Q1): a QSO whose QTH is `DX` puts DX in the Cabrillo section position and
writes no `ARRL_SECT` -- nor `STATE`, `DXCC` or `CLASS`, which is the arm's
behaviour and Q20 -- for both Field Days
(`Test_FieldDayDXIsNeverAnARRLSection`).

**THE ROUND TRIP** (`uTestContestExport.Test_RoundTripThroughTodaysImport`):
for 27 contests -- every class with an export rule of its own -- one QSO is
written through `EmitADIFRecord` plus the class's `STX_STRING` and contest
fields, read back through `ApplyADIFFieldsToExchange`, and compared: call,
band, mode, both RSTs, both serials, QTH, precedence, check, name,
`CONTEST_ID`, power (or `FOC_NUM`), `STX_STRING`, and `ARRL_SECT` / `CLASS` /
`STATE` / `APP_TR4W_HQ` / `GRIDSQUARE` where the contest writes them. WAG's
`DOK` and the RSGB IOTA's `IOTA` go out and do not come back -- uADIF has no
arm for either -- and the test pins that they go out; reading them is M5's.

**BEHAVIOUR CHANGES OUTSIDE EVERY ORACLE**, all in what an operator's
statement reaches, as M3's dupe policy was:

- a contest whose class owns a column formats it whatever the operator's
  `EXCHANGE RECEIVED` says -- as the fourteen `FormatsExchange` classes always
  did; it now also covers the FOC, Ukraine/Ural, PACC and PCC sent columns
  and the DARC 10 m, UK/EI, IOTA, California and WW Digi received ones;
- an operator who states Sweepstakes' or the Field Days' exchange for another
  contest gets the unhandled marker (Cabrillo) or `ADIFMyExchangeErrorMarker`
  (ADIF) rather than a line laid out for a contest he is not running;
- WW Digi's received QTH no longer follows an operator's `CONTEST NAME`;
- an ADIF exchange with no shared arm now logs an Error; the bytes are the
  same marker as before.

**Gates, run 2026-10-01 (full build).** Unit tests 0 failed (`ContestExport`
is new). Narrowing 1335 -> 1331, range warnings 4, both measured against a
HEAD build of the same tree. `Lint-ContestNameTests`: postunit 26 -> 15, uadif
4 -> 3, uadifexchange 5 -> 0, ucabrilloexchange 11 -> 0. Golden corpus 24
passed, 0 failed, 2 known-divergence, every export exit 0. **The contest
matrix: 171 identical, 14 differing.** The eleven new classes differ in
`contest.class =` ONLY (diffed with that line excluded: empty), which is the
transcription proof; ARRLSSCW and ARRLSSSSB in the defect #4 lines only.
**CROATIAN differed too, and that is not this change**: every one of its point
values doubled and nothing else moved, because the legacy Croatian arm doubles
points when `tGetSystemTime` reads 23:00-04:59 UTC and the run was at 23:05
UTC. It is classless and untouched here; it is NOT re-frozen (Q21).

~~**FINDING: the matrix is wall-clock dependent for CROATIAN** between 23:00
and 05:00 UTC.~~ **FIXED with Q21 (below)**: both rules read the QSO's recorded
time and the matrix stamps its QSOs 12:xx UTC, so the run no longer depends on
when it is made. Proved by running it at 23:45 UTC.

**Sponsor-rule questions this raised -- NY4I's, recorded, not acted on:**

- **Q19** Sweepstakes: a QSO with no received precedence now exports a blank
  column. Should such a QSO be exported at all, or as an X-QSO?
- **Q20** Field Day: a DX station sends a class (`1D DX`), but the export
  writes no ADIF `CLASS` for a DX QSO -- the arm skips every field when the
  QTH is `DX`. Write `CLASS` for DX?
- ~~**Q21** Two scoring rules read the LOGGING CLOCK, not the QSO's time:
  Croatian (doubles 23:00-04:59 UTC) and UK/EI (a UK/EI station doubles 01-04
  UTC). A rescore at night doubles a whole log. Should both read the QSO's
  own time?~~ **DECIDED AND FIXED, 2026-10-01.** NY4I: *"the event source is
  the wall clock recorded in the QSO."* Both rules read `aQso.tSysTime.qtHour`
  (UTC, stamped by `tGetQSOSystemTime` when the QSO is logged, or read from
  `TIME_ON` by ADIF import), so rescore, edit, import and a multi-op merge
  score the hour the QSO happened in. Stage 1 stays pure (§7.7): no clock, no
  global.
  - **Croatian gained a class**, `uContestCroatian` on `TContestBase`, with
    its row (`Test_MovedRowValuesStillMatchTheArray`) and its whole arm
    transcribed in order -- a 9A station's two steps still `Exit` before the
    doubling, as they always did. Its only other named site,
    `FCONTEST.FoundContest`'s `CROATIAN` arm (CQ DXCC for a 9A station), is
    set-up and waits for M7.
  - **UK/EI's class** reads the QSO's hour; `TStationContext.LogClockUTCHour`
    and its plumbing in `uContestFactory` (and that unit's `MainUnit` use)
    are deleted.
  - **The two legacy arms in `logstuff`** read `RXData.tSysTime` too. Neither
    contest reaches them now; an operator's `QSO POINT METHOD` on a classless
    contest still can, and no scoring path anywhere reads the clock.
  - **THE LIVE PATH HAD TO MOVE, AND THIS IS THE PART A REVIEW WOULD MISS.**
    Live scoring (`MainUnit.ParametersOkay`) ran BEFORE `LogContact` stamped
    the QSO's time, on a cleared record whose hour is 00 -- inside both
    windows. `ParametersOkay` now stamps `RData.tSysTime` before it scores;
    `LogContact` stamps again at the write, as it always has. Live scoring
    therefore reads the same instant the old clock read gave it.
    **Residual, recorded:** a QSO whose Enter and write straddle an hour
    boundary (seconds, or longer for a tail-ended QSO) can score by one hour
    and be recorded in the next -- exactly what live scoring did before; a
    rescore settles it by the recorded hour.
  - **Pinned:** `Test_CroatianDoublesByTheQSOsRecordedHour` (22:59 / 23:00 /
    00:00 / 04:59 / 05:00) and `Test_UKEIDoublesByTheQSOsRecordedHour`
    (00:59 / 01:00 / 04:59 / 05:00, and only a UK/EI station). Each asserts
    both sides of its window in one run, so no clock could satisfy both.
  - **The matrix:** CROATIAN differs in `contest.class =` only (diffed with
    that line excluded: empty), UK/EI not at all; run at 23:45 UTC, inside
    the old window.
- **Q22** PACC: its row says `RSTAndQSONumberOrDomesticQTHExchange`, every
  PACC session runs `RSTDomesticQTHExchange` (FCONTEST's arm). Which should
  the class state when M7 moves the arm?
- **Q23** CUP RF: the Cabrillo writer takes the QSO's own QTH for the CW and
  SSB runnings but not for CUP RF DIGITAL. Intended?

### 8.2f M5a -- what it covered (2026-10-01)

**Each contest interprets its own ADIF import.** The generic importer names no
contest; once the WHOLE record is read, the contest its `CONTEST_ID` names
interprets what was captured, through `TContestBase.ApplyADIFImport(aTemps,
aSession, var aExch)` -- the other half of M4's `EmitADIFContestFields`.
`MainUnit.ApplyContestSpecificADIFTail` is DELETED, and so is the
`APP_N1MM_EXCHANGE1` arm of `uADIF.ApplyADIFFieldsToExchange`.

| piece | where it lives now |
|---|---|
| standard tags -> standard fields; every contest-dependent tag captured as text | `uADIF.ApplyADIFFieldsToExchange`, contest-blind (no `ceContest` read except to store the contest `CONTEST_ID` names) |
| `TADIFRecordTemps`, the captured text | `uContestBase`, aliased in `uADIF`. New: `DOK`, `IOTA`, `N1MM_Exchange1` |
| `TADIFImportSession` -- the session's exchange, domestic-multiplier kind, whether it counts domestic multipliers, and the operator | `uContestBase`, handed in as DATA (the contest reads no global), built by `ParseADIFRecord` from `ActiveExchange`, `ActiveDomesticMult`, `DoingDomesticMults`, `CurrentOperator` |
| the operator fill and the RST off `SRX_STRING` -- every contest | `uADIF.ApplyADIFCommonImport`, before the contest is asked |
| the contest's own rule | `ApplyADIFImport`; the base's default is the old classless `else` |
| the two classless arms | `MainUnit.ApplyClasslessADIFImport` -- **ARRL 160 and POTA only**, each deleted when it gains a class |

**Arms moved, and to whom.** Each arm that named several contests was copied
into each (§1.4):

| arm | contests | now |
|---|---|---|
| GENERALQSO | General QSO | `TContestGeneralQSO` |
| WAG | WAG | `TContestWAG` (+ reads `DOK`) |
| ARRL160, CQ160CW, CQ160SSB, UBACW, UBASSB | five | `TContestCQ160CW`, `...SSB`, `TContestUBACW`, `...SSB` (new); ARRL 160 stays, below |
| ARRL_RTTY_ROUNDUP | one | `TContestARRLRTTYRoundup` (new) |
| ARRLSSCW, ARRLSSSSB, WINTERFIELDDAY, ARRLFIELDDAY | four | `TContestARRLSSBase` (the family), `TContestARRLFieldDay`, `TContestWinterFieldDay` (+ N1MM's class tag) |
| CWOPS | one | `TContestCWOps` (new) |
| CQWWCW, CQWWSSB | two | `TContestCQWWBase` (the family) |
| FOCMARATHON | one | `TContestFOCMarathon` (+ N1MM's number) |
| IARU | one | `TContestIARU` |
| NAQSOCW, NAQSOSSB, NAQSORTTY, NCCCSPRINT | four | `TContestNAQPCW`, `...SSB`, `...RTTY`, `TContestNCCCSprint` (new) |
| UKRAINIAN, OKDX, LZDX | three | `TContestUkrainianDX`, `TContestOKDX`, `TContestLZDX` (new) |
| WWDIGI, ARRLDIGI | two | `TContestWWDigi`, `TContestARRLDigi` |
| RSGB IOTA | (had no arm) | `TContestRSGBIOTA` reads `IOTA` |
| ARRL160 | one | **stays** in `ApplyClasslessADIFImport` -- see below |
| POTA | one | **stays**, same place -- see below |

**Thirteen contests gained classes**, each stating its whole row
(`Test_MovedRowValuesStillMatchTheArray`) and transcribing its scoring arm,
because a registered class is that contest's scorer too: CQ 160 CW/SSB, UBA
CW/SSB, the ARRL RTTY Roundup, CWOPS, NAQP CW/SSB/RTTY, the NCCC Sprint,
Ukrainian DX, OK/OM DX and LZ DX. Six score one point a QSO; the other seven
read `Station.MyCountry` / `Station.MyContinent` and the leaf
`uCallSignRoutines` (`UBACountry`, `OKOMStation`). The ARRL RTTY Roundup's row
has no `AIE` field, so its class states none and the array still answers.
**The matrix proves them: the thirteen records differ in `contest.class =`
only** -- every set-up, scoring and export line is byte-identical.

*(Superseded for both: ARRL 160's arm moved at M7b, §8.2j; POTA's on 2026-10-13, §8.2o, which deleted the routine.)*
**DECIDED: POTA AND ARRL 160 KEEP THEIR ARM IN `MainUnit`.** POTA has no class
(Q6, NY4I's and open), and its arm calls `logstuff.ResolvePOTAParkFromADIF` and
`Tree.LooksLikeAState`, which a class may not reach. ARRL 160's class would
have to score it, and its arm asks `ZoneCont.DomesticCountryCall` -- the same
reason M4 left it named in PostUnit. `ApplyClasslessADIFImport` is the one
place both are named, with the reason beside each, and it is deleted when the
last of them gains a class.

**DECIDED: `ProcessImportedSRX_String` WAS DELETED, NOT MOVED.** It parsed a
Field Day `SRX_STRING` into a class and a section and **nothing called it** --
no caller anywhere in the tree -- so a Field Day import never did what the
design said it would. §3.2's plan (the Field Day classes' `ApplyADIFImport`
calling their own `ParseReceivedExchange`) would be a behaviour change and is
M5b's. Its only other caller of `ProcessClassAndDomesticOrDXQTHExchange` is
`logstuff`'s own, so **D1/D2 are unchanged and stay M5b's**; the inventory's
`MainUnit.pas:11429` site is gone.

**THE N1MM TAG IS RESOLVED BY CONSTRUCTION.** `APP_N1MM_EXCHANGE1` is captured
(`temps.N1MM_Exchange1`) and the contest named by the record's `CONTEST_ID`
reads it after the whole record is in, so field order cannot matter.
`uTestContestImport.Test_N1MMTagOrderDoesNotMatter` pins both orders for ARRL
Field Day, Winter Field Day, the FOC Marathon and a contest that ignores the
tag. **The frozen record showed the bug before it was fixed**
(`n1mm.fd.before` and `n1mm.foc.before` in the step-1 freeze): with the tag
AHEAD of `CONTEST_ID`, the record was interpreted for the SESSION's contest --
`n1mm.foc.before` in an ARRL Field Day session put N1MM's FOC number into the
class -- while the AFTER order was right, so the two spellings of one record
disagreed.

**DECIDED: STANDARD `CLASS` WINS OVER N1MM'S TAG, which fills a gap.** The old
arm let whichever of the two arrived last win. N1MM writes its tag INSTEAD of
the standard one, so a record with both agrees in practice; the rule makes the
answer independent of the order they were written in.

**DECIDED (NY4I to confirm, Q24): THE FOC MARATHON NOW READS N1MM'S TAG.** The
old arm read it into `Power` and then the contest's own arm overwrote `Power`
with `FOC_NUM`, empty or not, so the tag never counted in either order -- frozen
as `n1mm.foc.after` having no power. `FOC_NUM` still wins; the tag fills in a
record with no `FOC_NUM`; a record with neither comes in with an empty number
exactly as before. This is the one place M5a goes beyond preserving behaviour
for the tag, and it is the intent of the arm.

**DECIDED: RSGB-ROLO IS NOT RESOLVED BY MODE (yet).** CW and SSB share the id
by ADIF's own definition and `FindContestByADIFContestId` still answers the
lowest `ContestType`, the CW running. Resolving by mode needs a mode-set
answer on the class, and neither RoPoCo contest has a class: two new classes
(and a transcription each) to change the `ceContest` of a QSO whose rows, point
method (`TenPointsPerQSO`) and exchange are identical -- so nothing
observable would move. It belongs to M7, when the pair gains classes.

**DEFECT #6 FIXED** (§8.2a): `uCallSignRoutines.FrenchID` read `ID[1]` of an
empty string. Both callers hand it a `QTH.CountryID`, empty whenever the
country lookup found nothing. Fixed where it lives, pinned by
`Test_FrenchID`.

**THE ROUND TRIP** (`uTestContestExport.Test_RoundTripThroughTodaysImport`) now
reads the contest's interpretation too, and the two fields M4 recorded as
written-but-not-read are read: WAG's `DOK` is its QTH again (before M5a it came
back as the received RST, `599`, because the arm took the raw `SRX_STRING`) and
the RSGB IOTA's `IOTA` is its domestic QTH. FOC's number is read back into
`Power`.

**ONE NEW TAG, `DOK`,** joined `TADIF_Fields` and `ADIF_FIELD_NAMES`;
`IOTA` was already in the enum with no arm, so every IOTA record logged "present
but no handler" and now does not.

**NOT DONE, AND WHY -- Q1's import half (a Field Day DX station is not a
section).** *(Done at M5b, §8.2g -- NY4I's 7.10 ruling made the decision
this paragraph waited for.)* M4 stopped the export writing `ARRL_SECT` for a DX station. The
import still turns `QTH=DX` into `DomesticQTH='DX'` (frozen: `section.dx`),
because Q1 says the Field Day exchange must model section and DX as distinct
and **`QTHString` is not the representation**, and nothing else is yet: that is
a ContestExchange field (or a `DXQTH` use) and a rescore consequence, so it is
a decision for NY4I and a change beyond M5a's allowed set.

**Gates, run 2026-10-01.** Unit tests 0 failed (`ContestImport` is new);
narrowing 1331 -> 1306 (explicit `ShortString` conversions in the moved arms --
thirteen copied arms added none) and range warnings 4, both measured on a full
build; golden corpus 24 passed, 0 failed, 2 known-divergence, every export
exit 0; `test-adif-roundtrip.sh` 13 of 13. `Lint-ContestNameTests`: mainunit
26 -> 14, uadif 3 -> 1. **The matrix:** the import capture (frozen BEFORE
anything moved, with every pre-existing section proved byte-identical -- 185
files, 31,680 lines added, none deleted) then changes only in the categories
above. Against that freeze: no set-up, scoring or export line moved in any
contest; `contest.class =` moved in the thirteen new classes; the `import`
section moved in `n1mm.fd.before` (183 contests -- all but the two Field Days),
`n1mm.foc.before` and `n1mm.foc.after` (all 185), `society` (WAG, RSGB IOTA),
WAG's export read-back, and the FOC Marathon's own `n1mm.own.*`.

**Sponsor-rule questions this raised -- NY4I's, recorded, not acted on:**

- **Q24** the FOC Marathon reads N1MM's `APP_N1MM_EXCHANGE1` as the membership
  number when the record has no `FOC_NUM` -- the intent of the old arm, never
  effective. Confirm.
- **Q25** Field Day (Q1's import half, above): where does DX live if it is not
  `QTHString`, and may a DX QSO's import stop counting as a section multiplier?
- **Q26** WAG's import keeps `SRX_STRING` (the received RST, `599`) as the QTH
  for a record with no `DOK` -- a foreign WAG log's QTH is its RST. Parsing the
  exchange is M5b; is the right answer for a record with neither the `DOK` nor a
  typed exchange an empty QTH?

### 8.2g M5b -- what it covered (2026-10-02)

**Each contest parses and validates its own received exchange.**
`logstuff.ProcessExchange` keeps the contest-blind tokenising gate
(`ParseArray`) and then asks `TContestBase.ParseReceivedExchange(aText,
aSession, var aExch, out aErrorMessage)` of `ExchangeContest` -- the active
contest's object, else its identity; never nil. A refusal's reason goes where
every exchange error goes (`ExchangeErrorMessage`) and shows like an improper
county.

| piece | where it lives now |
|---|---|
| the tokenising gate (`ParseArray`) | `ProcessExchange`, contest-blind, unchanged |
| one parser per exchange SHAPE | `logstuff.ParseExchangeShape(aShape, ...)` -- the old `case ActiveExchange of`, keyed on the shape it is handed; it names no contest |
| `TReceivedExchangeSession` -- the session's exchange, the shape parser, and the engine services a rule needs (`ZoneOfCall`, `IsDomesticQTH`, `CallWindowHasCall`, `AbandonEntry`) | `uContestBase`, handed in as DATA, as `TADIFImportSession` is |
| the contest's own rule | `ParseReceivedExchange`; the base's default is `aSession.ParseShape(aSession.Exchange, ...)` |
| word cutting a class also needs | `uExchangeTokens` (new leaf): `SplitExchangeInThree` (`ParseExchange`), `ProcessSweepstakesEntry` + `ScanSweepstakesExchange` (`ProcessSSEntry`), `IsSingleNonNumericToken` -- LIFTED line for line; LOGSTUFF calls them too |
| `TStationContext` | grew `MyCall` and `InHostState` (FCONTEST's own in-state answer, `StationInHostState`) |

**DECIDED: THE BASE'S DEFAULT REACHES THE ENGINE'S SHAPE PARSERS THROUGH THE
SESSION, AS DATA -- THEY ARE NOT LIFTED YET.** The brief's base default is
"today's shared per-exchange-kind behaviour keyed on the session's exchange
passed as data". That behaviour is about fifty `Process...Exchange` routines
that read the domestic QTH table, CTY.DAT, `DefaultRST`, the county-line queue
and `ExchangeErrorMessage`; a class may not call TRDOS (§1.3) and a class unit
is linked by the unit-test binary, so it cannot name LOGSTUFF. Handing the
engine's parser in -- a function value in the session record -- keeps the
class reading no global (a test hands it a stub, `uTestContestParse`) and
moves no parser that no rule needed moved. Each shape parser is lifted when a
contest that owns it needs its pieces, as `uExchangeTokens` was lifted for
UK/EI, IARU and Sweepstakes. The alternative, a trait the engine asks inside
each shape parser, would have put a contest question back inside shared code.

**DECIDED: AN OVERRIDE APPLIES ITS RULE UNDER THE SHAPE IT WAS WRITTEN FOR.**
Every rule that moved was a branch inside one shape's parser, reached only when
the session ran that shape (RAC/PCC/Arktika inside
`ProcessRSTAndQSONumberOrDomesticQTHExchange`, UK/EI inside
`...PossibleDomesticQTHExchange`, SAC inside `ProcessRSTAndQSONumberExchange`,
IARU inside `ProcessRSTAndDomesticQTHExchange` under
`RSTZoneOrSocietyExchange`, LABRE in the case arm). Each override tests
`aSession.Exchange` for that shape and otherwise calls `inherited`. With no
`EXCHANGE RECEIVED` statement that is exact; with one, a contest's rule no
longer follows the operator into a shape it was never written for.

**BEHAVIOUR CHANGES OUTSIDE EVERY ORACLE**, as at M3/M4: RAC, PCC and Arktika's
branches read `ActiveQSOPointMethod`, and the RussianDX initial exchange did
too, so an operator's `QSO POINT METHOD` line reached them in ANY contest; they
now follow the contest. `ValidClass`'s loop and the Field Day DX fallback
(D1/D2) answered a classless contest with an operator-stated Field Day
exchange; that contest now gets the base's validators (any class; no DX QTH).

**The rules, and where each went:**

| rule (where it stood) | now |
|---|---|
| RAC: a VE0 station sends a serial (`ActiveQSOPointMethod = RACQSOPointMethod`) | `TContestCanadaDay`, `TContestCanadaWinter` (new, copies -- §1.4) |
| PCC: letters a QTH, digits a serial (point method) | `TContestPCC.ParseReceivedExchange` |
| Arktika Spring: digits and blanks a serial (point method) | `TContestArktikaSpring.ParseReceivedExchange` |
| LABRE: a PY station sends a state (`Contest = LABRE`, ProcessExchange) | `TContestLABRE` (new) |
| IARU: a society's one word fills the zone from the call (`Contest = IARU`) | `TContestIARU.ParseReceivedExchange`, through `ZoneOfCall` |
| UK/EI: a UK/EI station must send more than one word (`Contest = UKEI`) | `TContestUKEI.ParseReceivedExchange` |
| SAC: a Russian station entered live is abandoned (`contest = SACCW/SACSSB`) | `TContestSACCW`, `TContestSACSSB` (new, siblings -- Q7), through `CallWindowHasCall` and `AbandonEntry` |
| PCC: `N/X` is not a callsign (`LooksLikeACallSign`) | `TContestPCC.MayBeACallsign` (new seam), asked through `ContestIdentity` -- LOGDVP calls it too, maybe off the main thread |
| RussianDX: a Russian station's initial exchange is its oblast (`zonecont.GetVEInitialExchange`, point method) | `TContestRussianDX`, `TContestRU3AXMemorial` (new, copies) `.InitialExchangeFromCall` (new seam) |
| ALRS-UA1DZ's oblast domestic QTH, in the grid-or-RDA shape | **DELETED, dead by default**: ALRS runs `RSTDomesticQTHExchange` in every variant (row and matrix), so the shape was reached only by an operator's `EXCHANGE RECEIVED` -- M4's rule for dead arms |
| D1 `ValidClass`'s letter loop, D2 the `TempString = 'DX'` chain | **DELETED** -- every contest is asked, no fallback |

**Seven contests gained classes**, each stating its whole row
(`Test_MovedRowValuesStillMatchTheArray`) and transcribing its scoring arm:
Canada Day, Canada Winter, SAC CW, SAC SSB, LABRE, Russian DX and the RU3AX
Memorial. The RU3AX phone doubling, a `Contest = RU3AXMEMORIAL` test inside the
shared RussianDX arm, is the RU3AX class's own line.

**DECIDED: THE UA4W CHAMPIONSHIP'S RULE STAYS NAMED IN LOGSTUFF, with its
reason beside it.** Its parse rule is one line (the QTH is the domestic QTH),
but a class is the contest's scorer too, and the UA4W arm scores by
`ctyGetCQZone(MY CALL)` -- a CTY lookup that swaps the global zone list while
it runs, which no class can be handed. The same reason ARRL 160 kept its arms
at M4 and M5a. It moves with a station-context answer for the CQ zone of MY
CALL (Q28). **Moved 2026-10-14 (§8.2p)**, with that answer as the
`TStationContext.MyCQZone` service.

**NY4I's RULINGS (7.10), and the evidence they rest on:**

- **Sweepstakes without a precedence is refused WITH A MESSAGE.** The shape
  parser already refused it -- it accepts only when serial, precedence, check
  and section are all present -- but SILENTLY. `TContestARRLSSBase` names
  `Missing precedence (Q A B U M S)` when the parse refused and the engine's
  own reading of the words (`ScanSweepstakesExchange`, the lifted
  `ProcessSSEntry`) found no precedence. Pinned by
  `Test_SweepstakesNamesAMissingPrecedence`.
- **A QSO party's out-of-state station may work only host-state stations.**
  `TContestStateQSOPartyBase.ParseReceivedExchange`: out of state
  (`Station.InHostState` False) and accepted by the shape, but a received QTH
  the session's domestic table does not know (`IsDomesticQTH` -- for an
  out-of-state station the host's county file) is refused with `Out of state:
  work <host> stations only`. **Asked of the table, not read off
  `DomesticQTH`**: the DX branch never writes it, so a value left by an
  earlier attempt would pass as a county (pinned). The table's own placeholder
  `XXX` is accepted as before. **No class overrides the default**: every party
  class's header and code was read for an exception, and the sponsors that
  could be read state the rule -- NC (*"Stations outside of North Carolina
  (Non-NC) work NC stations only"*), California (*"Non-CA to non-CA contacts
  do not count for QSO credit"*), Salmon Run (*"Stations outside Washington
  state work only Washington state stations"*), British Columbia (*"work only
  BC stations"*), Arizona (*"a valid contact ... between an Arizona station
  and any other station"*), Florida and Idaho (their objects). The rest are
  Q29.
- **Field Day DX export** (Q20): a DX QSO writes `CLASS` (the logged class),
  no `ARRL_SECT`, `STATE` or `DXCC`, and `SRX_STRING` is the class and `DX`
  -- through a new seam, `FormatADIFReceivedExchange`, whose base is the
  RST-or-not choice PostUnit's tail made. `Test_FieldDayDXIsNeverAnARRLSection`.
- **Field Day DX import** (Q25, closed): a QTH of `DX`, in `<QTH>` or in
  another logger's `ARRL_SECT`, stays the QSO's QTH and is never its domestic
  QTH -- what the live parse already did. `Test_FieldDayImportDXIsNotASection`.
- **Field Day keeps accepting DX** (the OPEN item).
- **NC's county file is the sponsor's hundred counties** (Q14, closed).
  `nc_cty.dom` lost its `INCLUDE S50`, DC, the provinces and `Alc` (not an NC
  county), checked against the sponsor's abbreviation PDF
  (`Test_NCCountyFileIsTheSponsorsList`); the DC and province lines moved into
  `nc.dom` in the position they were reached from, so an IN-STATE station's
  table answers exactly as before but for `Alc`. A VE station is no longer
  "in state" for NC. `Test_EveryPartyCountyFileHoldsOnlyCounties` holds every
  party's county file to counties.

**TWO DETERMINISM FINDINGS, fixed in step 1 before anything moved.** The parse
capture came out different on two runs of one binary. (1) The CQ WW RTTY
shape (`ProcessRSTZoneAndPossibleDomesticQTHExchange`) handed `ValidRST` an
uninitialised `FirstStringRST` in its two-word branch -- the same in D7 -- so
`599 14`, refused either way by the shape's later length test, left a
different RS(T) and zone behind each run; it is assigned before both branches
now. (2) ALRS-UA1DZ's scoring takes a grid distance from a QTH that is not a
grid and gets a different number each run, so the parse lines record no
points (the scoring section owns points, on fixed times).

**THE MATRIX.** Step 1 appended a `parse` section (66 typed exchanges through
`MainUnit.ParametersOkay`, per contest and variant) and froze it: 185 files,
39,168 lines added, none deleted, every earlier section byte-identical after
stripping the new one (scripted), and a second full run 185 identical. Against
that freeze, after the move: **168 identical**; `contest.class` only in the
seven new classes; the parse verdict only (`ok`, `err`, and the two fields
`ParametersOkay` writes only after an accept, `exch` and the default
`rst.rcvd`) in ARRL SS CW/SSB (165 lines each -- the message) and the
Colorado, Florida, Idaho, Minnesota (45 each) and Virginia (33) parties --
the out-of-state refusal, in the `us`, `ve` and `dx` variants and never in
`us-host`; the Field Days' `section.dx` import (`domqth=DX` gone); and NC,
whose data changed (the `us-host` station is `ALA` now; the `ve` station is
out of state). **No other line moved.**

**Gates:** narrowing 1306 -> see the commit; range 4; `Lint-ContestNameTests`
logstuff 14 -> 3 (300 -> 289 in all).

**Sponsor-rule and design questions this raised -- NY4I's:**

- **Q27** SAC refuses a Russian station (UA, UA2, UA9, EU) entered live by
  clearing the entry, SILENTLY -- transcribed as it was. Under 7.10 ("an
  invalid station is refused, with an error") should it show a message? And is
  a Russian station really not workable in SAC, or only not a multiplier?
- **Q28** UA4W: may the station context carry MY CALL's CQ zone, so the UA4W
  Championship can have a class (and its parse rule leave LOGSTUFF)?
- **Q29** Out-of-state rule, sponsors NOT checked (no rules page reachable, or
  no sentence found): Michigan, Minnesota, Missouri, Texas, Ohio,
  Pennsylvania, New York, Virginia, Wisconsin, Tennessee, Colorado, Indiana.
  The default applies to all of them; does any sponsor let out-of-state
  stations work each other?
- **Q30** Winter Field Day's `MX` (a DX QTH it accepts) still exports as
  `ARRL_SECT` and imports as a section. Is `MX` "DX" for the 7.10 ruling?
- **Q31** Sweepstakes says `Missing precedence` for ANY refused exchange with
  no precedence in it -- `599` alone included. Wording acceptable?

### 8.2h M6 -- what it covered (2026-10-02)

**Each contest owns its final score and its bonuses.** `logedit.TotalScore`
gathers the totals (`uScoreTotals.GatherScoreTotals`) and asks the session's
contest -- its class, else its identity -- for `FinalScore(totals, view)`,
which is `CombineScore` plus `BonusPoints` (§5 has the pieces). Every reader of
the score reads `TotalScore`, so the display, the summary sheet, the Cabrillo
`CLAIMED-SCORE`, the XML score report and both score-posting clients changed
together.

**Step 1 froze the totals first.** The matrix gained a `totals` section per
contest and variant -- the log the scoring section wrote, reloaded through
`MainUnit.LoadinLog` (what `/EXPORT`'s start runs), then the QSO points, the
QTCs, the QSO and multiplier counts by band and mode, `TotalScore`, and the
`CLAIMED-SCORE:` line of a Cabrillo file written after the reload. Frozen
with `--reason "M6: add totals capture before scoring totals move"`: 185
files, 29,282 lines added, none deleted; every earlier section byte-identical
after stripping the new one (scripted, per variant), and a second full run
185 identical.

**DECIDED (delegated), and the evidence for each:**

- **`TScoreTotals` IS A RECORD; THE VIEW IS A CLASS.** The totals are the
  argument of three virtuals and carry no behaviour -- the interface-parameter
  exemption CLAUDE.md grants, as `TCabrilloQSOContext` uses. The view is an
  abstract class with read methods only, so a contest CANNOT write to what it
  is handed; an array would have been mutable.
- **THE VIEW IS KEPT BESIDE THE TOTALS, NOT READ FROM THE DATABASE PER
  SCORE -- MEASURED.** The first build read the SQLite log on the first
  question. Timed on a 5,000-QSO log: 659 ms in one statement, 676 ms in runs
  of 256 -- the cost is decoding a row, about 130 us, not the query. With
  `TotalScore` running after every logged QSO, a 1,500-QSO Missouri log would
  have paused about 200 ms on each Enter. So `uScoreTotals` keeps a
  `TLoggedQSOList` exactly where the totals are kept: emptied in LOGDUPE's
  `DisposeOfMemoryAndZeroTotals`, filled by `LoadinLog` beside
  `AddQSOToSheets`, and extended by `LogContact` where it counts a new QSO.
  Every path found that changes a logged QSO (editor, rescore, import,
  deletion, network update) already ends in `LoadinLog`, because the totals
  need it too -- so the view and the totals can never describe two different
  logs. The view is still read-only to the contest, and still the whole log.
- **`CombineScore` IS A TEMPLATE, `FinalScore` IS NOT VIRTUAL** -- `ScoreQSO`'s
  shape (7.7). TotalScore's first two tests (a session with no multiplier, and
  the FISTS exchange, scores its points) named no contest and ran ahead of
  every contest's arm; as a template no override can skip them, so every
  formula that moved kept its order exactly.
- **BONUSES ARE DECLARED DATA WHERE THEY ARE THE SAME SHAPE, AND THE CLASS'S
  OWN CODE WHERE THEY ARE NOT.** Missouri's W0MA/K0GQ and the Salmon Run's W7DX
  are one shape -- "a contact with this call pays N, once or once per mode" --
  so they are `TBonusStation` rows the base evaluates over the view; the two
  differ only in which contacts and modes count (`CountsTowardBonus`,
  `CreditsBonusMode`). North Carolina's sweep and Idaho's dormant county share
  nothing with them or each other, so each is its class's `BonusPoints`, over
  the same view, adding `inherited`. A rule language to express those two
  would be the shared strategy §1 rules out.
- **OFF THE MAIN THREAD, `TotalScore` RETURNS THE LAST MAIN-THREAD SCORE.** The
  score-posting clients build their reports on worker threads (`uHamScore`'s
  uploader calls `uGetScores.BuildDynamicResultsXml`). The final score now
  reads the log through the store's one SQLite connection and the object
  `ActiveContest` owns; neither may be shared across threads. The main thread
  recomputes after every QSO, so the posted score is the one on the screen.
- **MISSOURI'S PEAK-HOUR TALLY IS PRESERVED, DEFECT AND ALL (Q32).** Live entry
  counted each 80/40 m QSO logged 1400-1959 UTC (to 250) and added it; the
  log's loader never counted it, so the same log scored differently live and
  reopened (and `/EXPORT` never had it). Zero change was the brief, and no
  single function of the log can reproduce a value that depends on when the
  program started. So the RULE is the class's (`TalliesLiveQSO`, the cap in its
  `BonusPoints`), the COUNT is still the engine's
  (`LOGDUPE.LiveSessionTally`, `TScoreTotals.LiveSessionTally`), and the seam
  says it is a defect to delete. WA7BNM's summary of the sponsor's rules has no
  such bonus.
- **RSGB 1.8 MHz STAYS NAMED IN `TotalScore` (Q33).** Its "times one" is one
  line, but a class is the contest's scorer too, and its per-QSO arm
  (`RSGB160Method`) pays 7 for a contact that is a new multiplier ON THE SHEET
  -- `mo.isdmmult` / `mo.isdxmult`. **That is a finding against 7.7's
  measurement** ("every point rule TR4W has is a function of the QSO and our
  station"): this one reads the multiplier sheet. Its class waits for M8.
- **WINTER FIELD DAY READS THE QSO COUNTS, NOT THE TOTALS WINDOW'S COPY.**
  `TotalScore` read `LogEdit.QTotals`, a snapshot `uTotal.UpdateTotals2` takes
  of `QSOTotals`; the class reads `TScoreTotals.QSOs`, filled from `QSOTotals`
  itself. Every reload path refreshes the snapshot first (`UpdateWindows`), so
  the gated values agree -- the Winter Field Day corpus set's 42364 is
  unchanged; live, the display can no longer read a snapshot one QSO behind.
- **THE RF CHAMPIONSHIP'S POINTS TABLE IS LIFTED** to `uRFChampionshipPoints`,
  read by both runnings' classes and by LOGSTUFF's arm (reachable through
  `QSO POINT METHOD` until M10) -- one table, as `uExchangeTokens` at M5b.

**Nine contests gained classes**, each stating its whole row
(`Test_MovedRowValuesStillMatchTheArray`) and transcribing its scoring arm: RF
Cup CW, SSB and digital; RF Championship CW and SSB; WAE CW and SSB (siblings,
Q7); OZHCR VHF; ALRS UA1DZ Cup. Their formulas went to
`CombineWithMultipliers`, as did ARRL Field Day's, Winter Field Day's, the Ural
Cup's and the Ukraine Championship's on their existing classes.

**THE MATRIX after the move: 176 identical; 8 differ in `contest.class` only**
(the RF Cups, RF Championships, WAEs and OZHCR -- scripted per category); **and
ALRS differs in one more place, which is a finding, not a transcription.**
Its record moved one QSO's points per variant (`us` 43 -> 42, `ve` 37 -> 38)
and the totals by the same 1. The QSO is the empty-QTH one, and the frozen
LEGACY record already scored three QSOs with IDENTICAL inputs (MY STATE `KS`,
empty QTH, not Russian) 43, 42 and 42 -- the class scores them 42, 42, 42. The
cause is `LOGGRID.ConvertGridToLatLon`: the arm hands it `'' + 'LL'`, a
two-character grid, which it reads at indexes 3 to 6 -- past the end of the
string, into whatever the heap holds. So that QSO's points were never a
function of the QSO; they follow the heap, and a class calling the same
function from another frame sees another heap. `CLAIMED-SCORE` = points +
300 x 17 multipliers both before and after: the formula moved exactly. Q37.

**BEHAVIOUR CHANGES OUTSIDE EVERY ORACLE**, as at M3-M5b:

- An operator's `QSO POINT METHOD` line no longer reaches the final score: the
  five formulas read `ActiveQSOPointMethod`, so `QSO POINT METHOD = WAE` once
  weighted any contest's multipliers. They are their contests' own now.
- Missouri's bonus stations are counted over the log: a deleted or X-QSO
  W0MA contact no longer pays until the next restart (the reload already
  said so). And Missouri's bonus is added even when an operator's statements
  leave the session with no multiplier, where TotalScore's short-circuit
  skipped it.
- Off the main thread the score is the last one the main thread computed.

**Gates:** golden corpus **24 / 0 / 2, exit 0** (13 sets exported); unit tests
0 failed (`uTestContestTotals`, new); narrowing 1301 -> 1301, range 4 -> 4;
`Lint-ContestNameTests` 289 -> 281 -- logedit 17 -> 11, mainunit 14 -> 13,
logsubs2 4 -> 3.

**Sponsor-rule and design questions this raised -- NY4I's:** Q32-Q37, §9.

### 8.2i M7a -- what it covered (2026-10-02)

**Every `FoundContest` arm for a contest that HAS A CLASS moved onto that
class.** 102 contests are registered (`rg "RegisterContest\(" tr4w/src/contestFactory`);
55 arms named them, and all 55 are gone from FCONTEST -- the `case` keeps
only the arms of classless contests. No contest gained a class. LogCfg's
per-contest CQ-exchange defaults moved the same way. NY4I delegated the
design forks; each DECIDED entry rests on the evidence given with it.

**DECIDED: the seam is `TContestBase.DescribeSession(const aStation:
TStationContext; aSession: TSessionDefaults)`, and the defaults object is a
CLASS, not a record.**

- Every value a set-up states has THREE states -- stated True, stated False,
  NOT STATED -- and the third is the one that preserves behaviour: an arm that
  named no exchange left the head's exchange (the trait, or the operator's
  statement) untouched. A record field has two states; "not stated" cannot be
  spelled as a value of `ExchangeType`, `WarcEnabled` or MY STATE, and an
  empty MY STATE is a real statement (Canada Day blanks a non-VE station's).
  So each setter records that its value was stated, and the applier writes
  only those. It also owns two ORDERED lists -- the domestic countries and the
  memories. That is behaviour, so it is a class (CLAUDE.md: prefer a class to
  a record). Its one element type, `TSessionMemory`, IS a record: it is the
  interface parameter the object hands the applier, pure data.
- `TSessionDefaults` lives in `uContestBase`, beside the other seam types.
  One member of `TSessionValue` per value a REGISTERED contest's arm wrote
  (exchange, three multiplier kinds, band, mode, `DomesticMultByBand`,
  `tAllowDupeQSOs`; the settings; MY STATE; the domestic file; the seven CW
  messages; the shared RST-and-serial memories). The classless arms write
  more -- a zone multiplier, an initial exchange, the R150S list -- and those
  join when their contest gains a class (M7b), by the same growth rule as
  `TStationContext`.
- **The class writes no global and reads only `aStation`.** It is asked of
  `ContestIdentity(Contest)`, which carries no station, so the station is a
  parameter -- `uContestFactory.CurrentStation`, now exported, the same
  snapshot scoring is handed. `TStationContext` gained `MyName`, `MyFDClass`,
  `MySection`, `MyPrec`, `MyCheck` (the messages are built from them) and
  `MyZoneText` (LogCfg sent the zone's TEXT; `'05'` is not `5`).
- **The memory keys are named, not coded** (`TSessionMemoryKey`): the
  engine's codes are TRDOS constants (Tree's `F1 = CHR(112)`) and a class does
  not reach into TRDOS for them. FCONTEST's applier translates.
- **The domestic-country groups are constants in `uContestBase`**
  (`DomesticCountriesKVE`, `...KVEKH6KL`, `...ARRLSections`, `...Russia`).
  FCONTEST's `Add_KVE`, `Add_KVEKH6KL`, `AddARRLSectionDomesticCountries` and
  `AddRussianDomesticCountrys` -- still called by the QSO-party head and the
  classless arms -- loop over the same constants, so each group is written
  once and read by both sides.

**DECIDED: ONE APPLIER, `FCONTEST.ApplySessionDefaults`, at the arms' old
position, and today's precedence exactly.** `FoundContest` asks EVERY contest
-- a classless one's identity is a plain `TContestBase`, whose
`DescribeSession` states nothing -- after the head (`ApplyContestTraits`, the
operator's statements, the in-state decision) and before the closing
`case ActiveExchange`. Then the classless `case` runs. A stated value
overwrites unconditionally, as the arm did: it beats a statement made before
the CONTEST line and loses to one made after it (the M2 behaviour, §7.9,
unchanged). Order inside the applier: engine choices, settings, MY STATE,
domestic file, countries (the contest's order), the shared RST-and-serial
memories, the contest's memories (its order), the messages. No arm wrote a
value that another value read, so the order is not a rule; a memory written
twice keeps its last value because the list is ordered.

**DECIDED: LogCfg's CQ-exchange defaults are a SIBLING virtual,
`CQExchangeDefault(const aStation): string`, not a field of the defaults
object.** `tSetupExchangeNumbers` runs once the whole configuration is read,
after `FoundContest`, and builds the text from MY STATE / NAME / ZONE / GRID
as they stand THEN -- a station line may follow the CONTEST line. A value
captured at `DescribeSession` would be the wrong snapshot. LogCfg asks
`ContestIdentity(Contest).CQExchangeDefault(CurrentStation)` first (the base
offers `''`, which is what LogCfg gave every contest it did not name) and its
`case` keeps the classless arms. Four arms went whole; six lost their
registered labels and stay for the classless contests beside them. The ARRL
DX phone running offers nothing -- LogCfg named `ARRLDXCW` only, so the
default is on the CW class, not the family base.

**D8 IS RESOLVED FOR EVERY REGISTERED CONTEST.** A choice that depends on the
station is stated BOTH WAYS in `DescribeSession`: Arizona, California, the
Salmon Run and Texas on `aStation.InHostState` (FoundContest's own in-state
answer since M5b, so `FoundMyStateInDomFile` is no longer called per arm);
ARRL DX, Croatian, PACC, SAC, UBA, Ukrainian, DARC 10 m, WAG, OKDX and ALRS on
the station's country or oblast; the WAEDC on its continent. The traits keep
saying what the contest IS, the same for everyone; inventory section 9.2's
"engine uses" column read the arms, which are gone.
`Test_PartiesDescribeBothSidesOfTheStateLine` pins each side of the four state
lines, and that each side states NOTHING of the other's.

**DECIDED: WINTER FIELD DAY'S DX MULTIPLIER -- row, class and session now say
`ARRLDXCCWithNoARRLSections`, the value every session ran.** The row said
`ARRLDXCC`; the arm overwrote it with `ARRLDXCCWithNoARRLSections` on every
set-up, so the row's value was never in force -- D8's shape, as Field Day's
was before Q1. Following M2's Field Day precedent, the class
(`GetDXMultiplierType`) and the VC.pas row were changed to the effective
value, and `DescribeSession` still states it, so a pre-CONTEST `DX
MULTIPLIER` line is still overwritten as before. **No behaviour changed** --
nothing reads the trait but `ApplyContestTraits`, whose value the describe
overwrites. Field Day was already consistent (Q1): row, class and session all
`NoDXMults`. `Test_FieldDayDXMultipliersAreWhatTheSessionRuns` pins both. Q38
asks whether Winter Field Day should count a DX multiplier at all.

**Not changed, on purpose:**

- Field Day still ACCEPTS a DX station (7.10's OPEN item).
- The All Asian's former ADIF id `AL-ASIAN-DX-PHONE` (NY4I ruled
  `ALL-ASIAN-DX-PHONE` correct; the old spelling must still import) goes in
  with `ALLASIANSSB`'s class at M7b. Both All Asian contests are classless,
  so their arm stays in FCONTEST, and M7a created no class. *(Done at M7b
  batch 1, §8.2j.)*
- An operator-edited memory is still overwritten each time the contest is set
  up (Q9) -- the arms did that, and the applier does it the same way.
- The QSO-party head (`MultipliersIsCounties`, the in/out-of-state file and
  contest name, `Add_KVEKH6KL`) is trait-driven, not an arm, and stays.

**Transcription notes.** Two arms added a country twice (UK/EI's `GM`, DARC
10 m's `DL`); the duplicates are kept. Four memories the arms wrote twice
(Sweepstakes' and the NA Sprints' CQ Alt-F1, Sweepstakes' exchange Alt-F7,
NAQP's CQ Alt-F1) are written once, with the surviving value -- the memory
holds only the last write. ALRS's oblast is zero-filled first, as its
scoring already does; the arm's `Str2` was never initialised, so a call with
no oblast read whatever the stack held. Every memory now reaches the engine
through `UTF8Encode` once, in the applier; four arms passed a UnicodeString
straight to the `ShortString` parameter instead. Identical for every ASCII
value (every callsign, section and state), and it is why narrowing fell.

**Gates:** the contest matrix **185 identical, 0 differing** -- every section,
set-up included, with no re-freeze and no class line moved; golden corpus
**24 / 0 / 2, exit 0** (13 sets exported); unit tests 0 failed
(`uTestContestSession`, new: the base states nothing for every classless
contest, a stated value is distinguishable from an unstated one, D8's four
state lines, ARRL DX's two kinds of station, the Field Days' DX multipliers,
Canada Day's blank MY STATE, and LogCfg's defaults including the contests it
never named). `Lint-ContestNameTests` 281 -> 220: fcontest 107 -> 50, logcfg
14 -> 10, its parse-sanity floor 228 -> 180. Narrowing 1301 -> 1291, range
4 -> 4.

**Questions this raised -- NY4I's:** Q38, Q39 (§9).

### 8.2j M7b batch 1 -- what it covered (2026-10-02)

**Thirty-nine classless contests gained a class**, each transcribing its row
and EVERY legacy arm that named it -- scoring, its `FoundContest` arm (now
`DescribeSession`), its LogCfg CQ-exchange arm (now `CQExchangeDefault`), and
ARRL 160's import and export arms -- with each moved arm deleted from shared
code. NY4I approved the batch and delegated its design forks; each DECIDED
entry rests on the evidence given with it.

The contests: 7QP, All Asian CW/SSB, ARCI, ARI DX, ARRL 10, ARRL 160, ARRL
VHF January/June/September, Baltic, BWQP, CIS, CQ-M, CQ VHF, CQ WPX RTTY, CQ
WW RTTY, the four EU Sprints, European VHF, Tesla, FISTS, GACW WWSA, Gagarin
Cup, HA DX, YU DX, Helvetia, JIDX CW/SSB, JT DX, KCJ, NEQP, Oceania DX CW/SSB,
Old New Year, OZCHR teams and OZCHR. Held back on purpose: POTA (Q6), the UA4W
Championship (Q28), RSGB 1.8 MHz (Q33), IN7QPNE (deferred by NY4I) and the
second half of the enum (RADIOVHFFD onward).

**DECIDED: NO NEW FAMILY BASE, AND NONE JOINS AN EXISTING ONE.** All
thirty-nine sit on `TContestBase`; `Test_EveryClassSitsOnTheBaseOrAFamily`'s
list is unchanged and `Test_M7bContestsAreSiblingsOnTheBase` pins each.

- **CQ WPX RTTY is not under `TContestCQWPXBase`**, nor **CQ WW RTTY under
  `TContestCQWWBase`.** Each base holds its CW and SSB runnings under ONE
  rule: its point method (CQWPX's band table; CQ WW's own-country 0 and North
  America 2) and, for WPX, its own Cabrillo and ADIF columns. The RTTY
  contests score by other arms (`CQWPXRTTYQSOPointMethod`: no band table, an
  80/40 m doubling; `CQWWRTTYQSOPointMethod`: own country 1, no NA rule), CQ WW
  RTTY sends a state and counts domestic multipliers, and both have always
  exported and imported through the shared arms. Under the bases they would
  inherit rules that are not theirs and change -- same sponsor, different
  rule.
- **The two-mode pairs and the series stay siblings** -- JIDX CW/SSB, All
  Asian CW/SSB, Oceania CW/SSB, the four EU Sprints, the three ARRL VHF
  runnings. JIDX is the strongest case for a family (identical rows bar the
  names, one arm, one set-up arm), which is exactly NY4I's open Q7; the brief
  said default to siblings while Q7 is open, so each is a copy it owns
  (Â§1.4), saying so in its header. The others already differ in their rows
  (All Asian's former id; Oceania's QRZ.RU ids; the EU Sprints' friendly
  names; the ARRL VHF ADIF ids, and January has never had the set-up the
  other two get).
- **OZCHR teams and OZCHR are not a family either**: their point methods,
  domestic and DX multipliers and set-up already differ.

**DECIDED: THE MULTI-STATE PARTIES ARE THEIR OWN CLASSES ON `TContestBase`,
AND THEIR BEHAVIOUR IS EXACTLY TODAY'S.** `TContestStateQSOPartyBase`'s
out-of-state refusal (7.10) and county-line rule assume one host state, and
neither 7QP nor NEQP has ever been held to them.

- **7QP's row says `P: 10`, so set-up has always run the party head for it**
  -- the in-state test against `seven_cty`, the in-state file `seven`, the
  `(in state)` contest name, K/VE/KH6/KL -- and its class states
  `IsUSQSOParty = True` to keep that. Its arm's own `FoundMyStateInDomFile`
  call is `aStation.InHostState` now: FoundContest's in-state answer, the same
  question on the same data. Its `HostState` is `''` ('7th area' is not a
  state). `Test_EveryStatePartyNamesItsState` -- "nothing outside the party
  base claims to be a party" -- gained one named exception for it, with the
  reason.
- **NEQP has `P: 0`** and never ran the party head; its class states both
  sides of the New England test (MY STATE's first two characters, D7's rule as
  M2 restored it, defect #3) -- `NEQSOW1`, county-or-DX, DXCC without
  W/VE/KH6/KL7 inside; `NEQSO`, a county, outside -- with the DX multiplier
  limit and K/VE/KH6/KL on both.
- **The design question is Q40.** Neither enforces a county-line maximum
  (7QP's sponsor allows four, ADDING_A_CONTEST.md's worksheet), nothing did
  before, and IN7QPNE is still classless.

**DECIDED: ARRL 160's domestic-country lookup is a SERVICE on the station
context**, `TStationContext.IsDomesticCountryCall`
(`TDomesticCountryCallTest`), filled by `uContestFactory.CurrentStation` with
a wrapper over `ZoneCont.DomesticCountryCall` -- the shape M5b's
`TReceivedExchangeSession` hands its engine services in. The class reads no
global; a test hands it a stub (`Test_ARRL160AsksTheDomesticCountryService`).
**nil means "not domestic"**, which is what the engine answers for an empty
list, so a FillChar'd station cannot crash a class. The same shape is the
obvious answer to Q28 (MY CALL's CQ zone for the UA4W Championship). With the
class in place, PostUnit's ARRL 160 `ARRL_SECT` arm is its
`EmitADIFContestFields` and `MainUnit.ApplyClasslessADIFImport`'s ARRL 160
arm is its `ApplyADIFImport`; POTA is the only contest left named in either.

**DECIDED: the session values the classless arms wrote join `TSessionValue`**,
by M7a's growth rule, each with its line in `FCONTEST.ApplySessionDefaults`:
`InitialExchange` and `ZoneMult` (JIDX, JT DX, KCJ -- `ActiveInitialExchange`,
`ActiveZoneMult`), `DXMultLimit` (7QP, NEQP), `R150SMode` (CQ-M, Gagarin Cup,
OZCHR teams), and **`SuppressZoneExchangeMessages`**: FoundContest's closing
`case ActiveExchange` skipped `SetUpRSTMyZoneExchange` for
`Contest in [JIDXCW, JIDXSSB]`; the JIDX classes state the flag (both
branches), and FoundContest reads it before freeing the session. It withholds
the zone exchanges' messages only, exactly what the named test withheld.

**DECIDED: LogCfg's repeat S&P default is a sibling virtual,
`RepeatSPExchangeDefault(aStation)`** (base `''`), for the reason
`CQExchangeDefault` is one: the EU Sprints' arm set `tSPExchange := '@' +
tCQExchange`, and LogCfg uses it only where REPEAT S&P EXCHANGE is still
empty. The EU Sprint classes answer `'@' + CQExchangeDefault(aStation)`.

**DECIDED: the CQ-M okrug test is lifted, not handed in.**
`LOGSTUFF.InSameFederalOkrug` read MY CALL and called leaf routines only
(`GetOblast`, `uRussiaOblasts`); it is `uCallSignRoutines.InSameFederalOkrug(
aMyCall, aHisCall)` now, line for line, and LOGSTUFF's legacy arm calls it
too -- one function, two callers (`Test_CQMOkrugRuleIsTheLiftedHelper`). Its
deleted copy is also the two narrowing conversions the ceiling fell by.

**DECIDED: the European VHF contest reads the session's contest name as data**
-- `TStationContext.ContestName` (`Settings.Contest.Name`) -- for its arm's
`'EURASIA'` test (an event with no ContestType, Q8). Transcribed, not judged.

**ONE LINE OF ONE ARM DID NOT MOVE, ON PURPOSE.** Tesla's arm ended in
`LOGWIND.DisplayTotalScore`, a repaint of the score panel from inside scoring.
It is display, not a rule; a class may not reach the display layer, and every
path that logs a QSO repaints the score after scoring it. The legacy arm still
has it (reachable through `QSO POINT METHOD` until M10).

**ALLASIANSSB.** NY4I ruled `ALL-ASIAN-DX-PHONE` correct and the row was
corrected on 2026-10-01 (`e1c6f873`, re-frozen then for that contest alone),
so **its export does not move at M7b**. What M7b adds is the class that can
carry the former id: `FormerADIFContestIds = ['AL-ASIAN-DX-PHONE']`, so a file
TR4W exported before that day imports to the contest
(`Test_ADIFIdsResolveOldAndNew`; `Test_NoADIFIdIsClaimedTwice` holds it
unique).

**Transcription notes.** Every class states its whole row
(`Test_MovedRowValuesStillMatchTheArray`); several enum spellings look nothing
like their identifier (JTDX `MONGOLIAN DX`, OLDNEWYEAR `RADIO-ONY`, OZCR_O
`OZCHR-TEAMS`, OZCR_Z `OZCHR`, NEWENGLANDQSO `NEQP`). The ARRL September VHF
running is named `'VHF QSO JUNE'` because the arm named both; the OZCHR names
are literal `?` characters (the Cyrillic was lost before this tree); both
transcribed (Q41, Q42). The commented-out D7 arms for CQ WW RTTY and BWQP in
FoundContest were deleted with the live ones. OZCHR's scoring is a copy of
`TContestIARU`'s (Â§1.4). `uTestContestImport.Test_ClasslessDefault` moved from
ARRL 10 to RSGB 1.8 MHz, which stays classless.

**Gates, run 2026-10-02 on a full build.** The contest matrix: **146
identical, 39 differing, and in each of the 39 the ONLY changed lines are
`contest.class =`** -- compared with that line excluded, by script, record by
record; no other line moved in any of the 185 records, and no record outside
the batch moved at all. ALLASIANSSB is among the 39 like the rest: its export
already said `ALL-ASIAN-DX-PHONE` (e1c6f873). Those 39 need re-freezing for the
identity line alone, with that reason. Golden corpus **24 passed, 0 failed, 2
known-divergence, every export exit 0** (13 sets); `test-adif-roundtrip.sh`
**13 passed**; unit tests **0 failed** (44,315 passed).
`Lint-ContestNameTests` 220 -> 189: fcontest 50 -> 25, logcfg 10 -> 6,
mainunit 13 -> 12, postunit 15 -> 14; its floor 180 -> 150. Narrowing 1291 ->
1289, range 4 -> 4.

**Not changed, on purpose:** the initial-exchange test that names the two
OZCHR contests in `LOGEDIT` (an R3x call gets no zone initial exchange -- the
RF Championships are named in the same routine and stayed at M5b/M6), the
OZCHR teams' mode-split display in `uTotal`, All Asian's arm in
`uExchangeBuilder` (HamScore's received exchange) and ARRL 10 beside Winter
Field Day in PostUnit's Cabrillo-header location check, and the New Contest
dialog's prompts (`uNewContest`) -- each a seam not built yet (M9), where
registered contests are still named too. **[M9a, §8.2m: the totals window,
`uExchangeBuilder`, the Cabrillo-header check and the prompts are their
classes' now; LOGEDIT's initial exchange stays (Q50).]**

### 8.2k M7b batch 2 -- what it covered (2026-10-02)

**Forty classless contests gained a class** -- every contest left classless
after batch 1 but the five that stay so on purpose: POTA (Q6), the UA4W
Championship (Q28), RSGB 1.8 MHz (Q33), IN7QPNE (deferred by NY4I) and
DUMMYCONTEST. Measured, not listed: the enum minus every `RegisterContest`
call, comments stripped, is exactly those five now
(`Test_M7bBatch2ContestsAreSiblingsOnTheBase` holds it). Each class states its
row and transcribes every legacy arm that named it -- its scoring arm, its
`FoundContest` arm (now `DescribeSession`) and its LogCfg CQ-exchange arm (now
`CQExchangeDefault`) -- and each moved arm is deleted. NY4I approved the batch
and delegated its design forks; each DECIDED entry rests on its evidence.

The contests: Radio VHF FD, RAEM, RDA, Region 1 Field Day and its RCC CW/SSB
runnings, AS-CHAMP (RFAS CW), RSGB RoPoCo CW/SSB, YB DX, South American WW, SP
DX, Stew Perry, Ten-Ten, TOEC, UCG, WWL, WW PMC, YO DX, UN DX, King of Spain
CW/SSB, WRTC, R9W-UW9WK Memorial, Radio Memory, REF CW/SSB, Black Sea Cup,
CQMM, CW Open, Makrothen, WWIH, Radio YOC, OK/OM SSB, MWC, IRTS, EUDX, YOTA,
SST and RTC.

**DECIDED: NO NEW FAMILY BASE, AND NONE JOINS AN EXISTING ONE.** All forty
sit on `TContestBase`.

- **UCG scores by the CQ WPX arm and WWIH by the CQ WW RTTY arm, and neither
  joins the class that owns that arm.** `TContestCQWPXBase` is CQ's two
  runnings under CQ's rules, its own Cabrillo and ADIF columns among them;
  UCG has always exported through the shared RST-and-serial arm. WWIH's arm
  is `TContestCQWWRTTY`'s, a batch-1 sibling of another sponsor. Each arm is
  a COPY its contest owns (§1.4).
- **The pairs are siblings while Q7 is open** -- King of Spain CW/SSB and REF
  CW/SSB (identical rows bar names and ids), RSGB RoPoCo CW/SSB (one shared
  set-up arm), and the two Region 1 Field Day RCC runnings (identical rows).
  The plain Region 1 Field Day scores by another arm (each society's table)
  and is no family with them. **IRTS and EUDX** share a scoring arm by their
  rows and nothing else -- another sponsor, another set-up -- so they are
  copies. **OK/OM SSB** is not the OK/OM DX class's sibling: that one scores
  by `OKDXQSOPointMethod`.

**DECIDED: THE LAST SESSION VALUES THE ARMS WROTE JOIN `TSessionDefaults`**, by
M7a's growth rule, each with its line in `FCONTEST.ApplySessionDefaults`:

- `InitialExchangeCursorAtStart` (IRTS, RAEM) -- LOGWIND's
  `InitialExchangeCursorPos := AtStart`. A flag, not the engine's
  `InitialExchangeCursorPosType`, which is TRDOS's to declare; the applier
  writes the global, exactly what the arm wrote (not the setting).
- `DXCCMultByBand` (CQMM's `dmbbAllBand`), the DXCC twin of
  `DomesticMultByBand`.
- **Caption memories** (`smbExchangeCaption`, `SetExchangeCaptionMemory`) -- the
  RTC arm captioned exchange F4 `NR` and F5 `Cl+Ex` through
  `SetEXCaptionMemoryString`. In the same ordered memory list, so they apply
  after the memories they label, as in the arm.

**DECIDED: `PortableStation` IS LIFTED, NOT HANDED IN.** The Region 1 Field
Day's arm calls `Tree.PortableStation`, a pure function of the call. It is
`uCallSignRoutines.PortableStation(const aCall: string)` now, line for line,
and Tree's copy is deleted -- the legacy arm has one caller of the one
function (`Test_PortableStationIsTheLiftedHelper`). No other batch-2 rule
needed an engine fact: every station fact the arms read (`Settings.My.Country`,
`MyContinent`, MY STATE / GRID / NAME, CATEGORY-POWER) was already on
`TStationContext`, and LOGGRID (`GetDistanceBetweenGrids`, `RTCGridDistance`,
`LooksLikeAGeoCoordinates`) is the helper the grid classes already call.

**DECIDED: THE RSGB RoPoCo RUNNINGS ARE TOLD APART ON IMPORT BY THE RECORD'S
MODE -- a behaviour change, made on purpose.** ADIF's id for both is
`RSGB-ROLO` (ADIF's own definition), and the id alone has always resolved to
the CW running -- so a phone QSO TR4W exported for the SSB running imported
to the CW one (`uTestADIFRegression` carried it as its one exception). With
both classes in place a contest can say which modes it is:
`TContestBase.RunsInMode` (base: every mode; the CW running `CW`, the SSB
running `Phone`). `uContestRegistry.ContestOfADIFRecordMode` asks the
contests that share the resolved contest's id, in enum order, which runs in
the record's mode; the first is the answer, and when none does the id's own
answer stands. `uADIF.ApplyADIFFieldsToExchange` asks it once the whole
record is read (so tag order cannot matter), and only for a contest that
came FROM the id. `FindContestByADIFContestId` is unchanged: an id alone
still answers the CW running. A contest that shares no id cannot move --
the base runs in every mode. Considered and rejected: refining in
`ApplyADIFImport` (a class re-pointing a record to its sibling, by name); and
resolving by the open session's contest (not a fact of the record).
`RunsInMode` is an identity question only; it scores nothing.

**What the matrix shows for it, verified line by line by script:** in the two
RoPoCo records, and nowhere else, 30 import lines each moved -- the ten phone
imports (FM included) in each of three variants -- and each moved ONLY in its
`contest=` token: the CW record's phone imports now resolve to the SSB
running, the SSB record's now resolve to itself. The CW record moves too
because it exports phone QSOs under the same id; that is the rule working,
not a leak. The round-trip test covers both runnings (the SSB running is
exported as a phone QSO).

**ONE TRANSCRIPTION CHOSE WHAT THE CODE DOES OVER HOW IT READ.** Ten-Ten's arm
is `if TenTenNum <> -1 then 2 else 1`, and `TenTenNum` is a Word whose "no
number" is MAXWORD: the comparison is never false (FPC: "Comparison might be
always true", one of the four range warnings the build ratchets), so every
Ten-Ten QSO has scored 2. The class says `QSOPoints := 2` and records why, so
the range ceiling did not rise; the legacy arm keeps its warning until M10.
What the rule should be is Q46.

**Transcribed, not judged, and recorded in each class:** EUDX and IRTS test
"he is in the EU" as `DomMultQTH[4] <> ''`, a character against the empty
string -- never equal, so every QSO scores as with an EU station (the frozen
matrix: 10 for all seventeen; Q45). RTC's arm keeps its own band and mode
rule (0 and `InhibitMults`); CQMM's and WRTC's score 0 off 80-10 m and still
earn multipliers -- none states `UsesBand` (Q44). MWC walks a ten-character
copy of the call to the call's full length; the Region 1 Field Day reads MY
COUNTRY's first character without a length check; the RCC runnings score 4
for a one-character call -- all as the arms did (Q47). IRTS scores by
`EUDXQSOPointMethod`, its row's, not by `IRTSQSOPointMethod`, which only an
operator's `QSO POINT METHOD` line reaches (inventory D3).

**Design Q37 reaches four of these classes**: Radio VHF FD and Makrothen (an
empty received grid, whenever MY GRID is set), Stew Perry and WWL (a received
grid of one to three characters). RTC is not reached: `GridHaversineKm`
bounds a short grid. The grid handling is untouched and each class says so.

**Not changed, on purpose -- seams not built yet:** WRTC's three display
rules (the main menu, `OpenTR4WWindow`, LOGEDIT's Super Check Partial) and its
score-posting multipliers in LOGSUBS2 (M9) **[done at M9a, §8.2m:
`PermittedOperatingAids` and `ScorePostingMultiplierType`]**; YB DX in `MainUnit.ParametersOkay`'s
Indonesian-district prefix rule, RDA and YO DX in LOGEDIT's new-multiplier
check, and RDA beside the Russian DX contests in LOGEDIT's initial-exchange
fallback (M8 -- the Russian DX contests, registered since M5b, are named in
the same routines); Radio YOC in MainUnit's log loader (the previous received
number -- engine state, not a rule); **[M8, §8.2l: the YB DX test was a
no-op and is deleted; RDA's and YO DX's new-multiplier arms are their
classes' `DomesticMultiplierFromCall`; RDA's initial-exchange fallback is an
exchange rule and stays (Q50)]**; SST, CW Open and RTC in
`uExchangeBuilder`'s HamScore exchanges (M9, beside fourteen registered
contests); and the New Contest dialog's prompts (`uNewContest`, M9) **[both
done at M9a, §8.2m]**. The
`TENTEN` in LOGSCP, LOGWIND and LOGEDIT is TRMASTER's Ten-Ten field and the
`'RAEM'` in `IsAGoodCall` a callsign -- neither is the contest.

**Transcription notes.** The generator that wrote the forty units parsed each
row out of `VC.pas`; several enum spellings are not their identifier (RDA
`RDAC`, RFASCHAMPIONSHIPCW `AS-CHAMP`, YODX `YO-DX-HF`, BSCI `BLACK SEA CUP`,
MAKROTHEN `MAKROTHEN-RTTY`, OKOMSSB `OK-OM DX SSB`), and
`Test_MovedRowValuesStillMatchTheArray` holds all forty. The commented-out
FoundContest arms for REFCW and RADIOMEMORY were deleted with the live ones,
and LogCfg's commented `JTDX, REGION1FIELDDAY, ...` line and its now-unused
`Grid` local (MAKROTHEN's) with them. BSCI's `Val` of MY ZONE is
`Station.MyZone`, the IARU class's precedent (FPC's `Val` gives 0 on failure,
as the snapshot does).

**Gates, run 2026-10-02 on a full build.** The contest matrix: **145
identical, 40 differing**; compared with `contest.class =` excluded, by script,
38 records are identical and the two RoPoCo records differ only in their 30
phone import lines' `contest=` token each (above); no record outside the
batch moved. Re-freeze the 40 for that reason. Golden corpus **24 passed, 0
failed, 2 known-divergence, every export exit 0** (13 sets);
`test-adif-roundtrip.sh` **13 passed**; unit tests **0 failed** (46,161
passed). `Lint-ContestNameTests` 189 -> 161: fcontest 25 -> 2, logcfg 6 -> 1;
its floor 150 -> 130. Narrowing 1289 -> 1287 (Tree's `PortableStation`), range
4 -> 4.

**Questions this raised -- NY4I's:** Q44-Q47 (§9).

### 8.2l M8 -- what it covered (2026-10-02)

**Multipliers and dupes are contest-declared rules over the shared sheet** --
stage 2 of §7.7: the sheet (`logdupe`, `uMults`, `uCallsigns`) keeps the
state, and the contest declares what counts. NY4I approved M8 and delegated
its design forks; each DECIDED entry rests on its evidence.

**MEASURED FIRST -- every multiplier and dupe rule outside the factory.**
Shapes 1/2 from `Lint-ContestNameTests -List` (161 at the start), shapes 3/4
from the inventory's Multipliers table, and the `Active*Mult` reach
re-measured from the classes' traits and `DescribeSession` assignments (a
script over `src/contestFactory`; reach = contests stating the value):

| rule | where | shape | contests | classified | M8 |
|---|---|---|---|---|---|
| a `DX` QTH earns no multiplier | `logdupe.SetMultFlags` | 1 | BCQP (`'dx'`), NYQP, INQSOPARTY | contest rule | **moved** -- `CountsAsMultiplier` |
| own country's prefix is no multiplier | `SetMultFlags` | 1 | PCC | contest rule | **moved** |
| own branch and branch 00 are no zone multiplier | `SetMultFlags` | 1 | NZFIELDDAY | contest rule | **moved** |
| the domestic multiplier a call implies (the hint) | `LogEdit.GetMultArray` | 1 | RUSSIANDX with RF Championship CW/SSB, CUPURAL, RDA, YODX | contest rule | **moved** -- `DomesticMultiplierFromCall` |
| an Indonesian entrant re-sets the prefix | `MainUnit.ParametersOkay` | 1 | YBDX | a no-op (below) | **deleted** |
| a Russian call's oblast as the initial exchange when none was found | `LogEdit` initial exchange, `Contest in [RUSSIANDX, RDA, RU3AXMEMORIAL]` | 1 | three | an EXCHANGE rule, not a multiplier one | stays -- it has drifted from `InitialExchangeFromCall` (Q50) |
| the zone initial exchange (OZCR, RF Championship), IARU's first word | `LogEdit` initial exchange | 1 | four | exchange rules | stays (M9, the initial-exchange seam) |
| points times one | `LogEdit.TotalScore` | 1 | RSGB18 | final score | stays (Q33) |
| totals-window captions (OZCR_O, IARU, RUSSIANDX, RU3AX), summary sheet (Winter FD), score posting (WRTC) | `uTotal`, `postunit`, `logsubs2` | 1 | several | display | M9 -- **done at M9a** (§8.2m) |
| the six GC stations | `LogEdit.SetPrefix` | 3 | GAGARINCUP | the `GCStation` KIND's arm | stays with its kind |
| reach-1-3 KINDS: `ARRLDXCCWithNoIOrIS0` (ARI), `ARRLDXCCWithNoJT` (JTDX), `CQUBAEuropeanCountries` (UBA), `BlackSeaCountries` (BSCI), `PACCCountriesAndPrefixes` (PACC), `CQEuropeanCountries` (WAEDC), `CQDXCCWithNoUSAOrCanada` (CQ 160); `BelgiumPrefixes`, `SouthAmericanPrefixes`, `MongolianCallSignPrefix`, `GCStation`, `IndonesianDistricts`, `SACDistricts`, `NonSouthAmericanPrefixes`, `SouthAndNorthAmericanPrefixes`, `CQNonEuropeanCountriesAndWAECallRegions`; `EUHFCYear`, `BranchZones`, `RFChampionchipZones`; `RDADistrict`, `DOKCodes`, `IOTADomestic` | `GetDXQTH`, `SetPrefix`, `SetUpRemainingMultiplierArrays`, `LogEdit.Add`, `uMults.FillVisibleBytes`, `logdom.GetDomQTH` | 4 | 1-3 each | contest rules in disguise -- but see DECIDED | stay keyed on the kind until Q4 |
| a rover is never a dupe in a grid contest | `LogEdit.CallIsADupe`, `logsubs2` | 4 | `GridSquares`, 6 | SHARED: engine behaviour on a kind | stays |
| a QSO-party mobile's county | `logsubs2` | 4 | `DomesticFile`, 86 | SHARED | stays |
| dupes per band and per mode; whether repeats are marked at all | `CallsignIsDupe`, `logsubs2` | -- | every | declared (`QSOByBand`, `QSOByMode`, `MarksDupes`) | already the contest's |

**No dupe rule outside the factory names a contest** -- the inventory's Dupe
category was 0 rows, and reading the dupe code found none either.

**DECIDED: TWO SEAMS, BOTH ASKED BY THE SHEET, NEITHER HANDED THE SHEET.**

- `TContestBase.CountsAsMultiplier(aQso, aKind): boolean` (base True) --
  does this QSO earn a multiplier of this kind AT ALL. `SetMultFlags` asks
  it per kind through `uContestBase.ContestCountsMultiplier(ActiveContest(
  Contest), ...)` (nil answers True, as `ContestCreditsBand` does), after the
  band question and before the sheet's "is it new". `aKind` is the sheet's own
  `RemainingMultiplierType` (`rmDomestic`/`rmDX`/`rmZone`/`rmPrefix`), the
  type `TScoreMultTotals` already keys by kind -- not a new enum. Asked of
  `ActiveContest` because the PCC's and the Jock White rules read the
  station. Each of the five rules was an early `exit` or a `False`; a False
  answer leaves the flag cleared, which is the same thing.
- `TContestBase.DomesticMultiplierFromCall(aCall, aLookups): string` (base
  `''`) -- the hint's. Asked of `ContestIdentity` (no station needed). What
  only the engine holds arrives as `TMultiplierHintLookups` (the remembered
  initial exchange, CTY.DAT's grid), the shape of M5b's
  `TReceivedExchangeSession`.
- Considered and rejected: one `MultiplierKey(aQso, aKind)` virtual with the
  shared kind `case` as its base -- the base would have to reach TRDOS's
  `GetDXQTH`/`SetPrefix`, which read globals, and it would move no rule (next
  entry). And a dupe-key virtual "alongside MarksDupes" -- no contest's own
  dupe rule exists to put in it (§1.2: a virtual is added when its
  responsibility moves).

**DECIDED: A REACH-1-3 MULTIPLIER KIND STAYS IN THE SHEET, KEYED ON THE KIND,
UNTIL THE MULTIPLIER COMMANDS RETIRE (Q4).** They are contest rules in
disguise -- the inventory's reading -- but each arm is ALSO the meaning of an
operator's statement: `uSettingsEffects.ApplyMultiplierToken` lets `DX
MULTIPLIER`, `PREFIX MULTIPLIER`, `ZONE MULTIPLIER` and `DOMESTIC
MULTIPLIER` select ANY kind for ANY contest, and M2 made that statement beat
the contest's trait. Moving `BlackSeaCountries` into the Black Sea Cup's
class would leave the arm behind for the operator's statement -- two
definitions, the drift CLAUDE.md forbids. When Q4 retires the commands, each
kind moves into the class(es) that declare it and the kind enums die with
the engine (§0.2). The contest already DECLARES its kind (M2's traits, M7's
`DescribeSession`), which is the half of stage 2 that can move now.

**DECIDED: YB DX's TEST IS DELETED, NOT MOVED -- IT DID NOTHING.** In
`ParametersOkay`'s `IndonesianDistricts` arm, `if (Contest = YBDX) and
IndonesianCountry(MY COUNTRY) then SetPrefix(RData)` follows `RData.Prefix :=
IndonesianDistrict(RData.QTH)`, and `SetPrefix`'s `IndonesianDistricts` arm
is that same assignment. The same in D7 (`MainUnit.pas:5225`). What it was
meant to do is Q48. The `case ActivePrefixMult of` it sat in was itself a
COPY of six of `SetPrefix`'s arms, run unconditionally after `if
DoingPrefixMults then SetPrefix`: it is replaced by one `SetPrefix` call when
`DoingPrefixMults` is on or the kind is one of those six -- exactly the cases
either copy ran in, and every `SetPrefix` arm assigns from the QTH or the
call alone, so running it once is running it twice.

**THE OFF-BAND FIXES (§7.4) -- the only behaviour M8 changes, and only for a
contest that states its bands (Idaho is the only one).**

- **Dupes.** `TCallsignsList.AddCallsign` marks no dupe bit for a QSO on a
  band the contest does not use (it still counts as a QSO with the station),
  and `CallsignIsDupe` answers False for one -- both through
  `ContestCreditsBand(ContestIdentity(Contest), Band)`. `ContestIdentity`,
  not `ActiveContest`: the band list is what the contest IS, and the dupe
  check is asked by the band map, the spot clients and WSJT-X, where
  `ActiveContest` (which frees and rebuilds its object) is not safe.
  `EditableLog.CallIsADupe` turned the band into the `AllBands` key BEFORE
  calling -- a copy of what `CallsignIsDupe` does on entry, so it changed
  nothing except hiding the real band from the new question; the copy is
  deleted.
- **The hint.** `DetermineIfNewMult` answers False on an off-band band (the
  radio's, a spot's); the needs strip clears those bands
  (`uContestBase.CreditedBands`, which keeps the `AllBands` key); the "new
  multiplier" indicator stays off while the operator is on one.
- **A defect found on the way, fixed with it.** `DetermineIfNewDomesticMult`
  asked with `AllBands` (the not-per-band strip) handed `SetMultFlags` a QSO
  ON `AllBands`, which a contest that states its bands does not credit -- so
  since `1e4f66f9` the Idaho county strip said "not needed" for every county.
  The band such a hint is for is the one the operator is on, and that is
  what it asks now.
- **Pinned** in `uTestOffBandCredit`: Idaho with QSO-by-band OFF (the case no
  shipped contest reaches) -- 30 m makes no 20 m dupe, 30 m is never a dupe,
  20 m does make 40 m a dupe (the control) -- and per band as Idaho ships;
  CQ WW CW (every band) still marks a 30 m QSO, exactly as before;
  `CreditedBands` against Idaho's list band by band; `DetermineIfNewMult`
  needed on 20 m and not on 30 m with the real CTY.DAT; the domestic strip on
  20 m (needed -- the defect) and on 30 m (not).

**`uTestContestMultipliers`** pins each moved rule against its arm (BC's
lower-case `'dx'` included) and every other contest's base answer for both
seams -- a ratchet, as `Test_EveryOtherContestStillCreditsEveryBand` is.
`uTestContestObjects` holds the test helpers `Make`/`NoStation`, lifted out of
`uTestContestTotals` and `uTestContestSession` rather than copied a third
time.

**RSGB 1.8 MHz STAYS CLASSLESS (Q33).** M8's seam is a contest DECLARING
which QSOs count; RSGB 1.8's points READ the sheet (`mo.isdmmult` /
`mo.isdxmult`: 7 for a multiplier unworked on the sheet). What it needs,
measured: a read-only sheet query handed to scoring with the station -- "is
domestic key X / DX country N unworked" over ALL bands and BOTH modes,
whatever the session's by-band and by-mode keys, and whether or not DX
multipliers are on (its arm asks both) -- and NY4I's yes to widening stage 1
for a history-dependent point rule (§7.7). Nothing was built for it.

**Gates, run 2026-10-02 on a full build.** The contest matrix: **185
identical, 0 differing** -- a per-section comparison script found 0 changed
lines in every category. **The off-band fixes move NO record, and that is the
matrix's blindness, not their absence**: it scores each QSO against an EMPTY
sheet and records no dupe verdict and no hint, and Idaho's three off-band QSOs
per variant (2 m FM, 30 m CW, 6 m phone) already scored 0 with every
multiplier flag false (§7.5). The unit tests are what see them;
`BENCH_QUEUE.md` carries the window. Golden corpus **24 passed, 0 failed, 2
known-divergence, every export exit 0** (13 sets); `test-adif-roundtrip.sh`
**13 passed**; unit tests **0 failed** (46,591 passed). `Lint-ContestNameTests`
161 -> 151: logdupe 5 -> 0, logedit 11 -> 7, mainunit 12 -> 11; its floor
130 -> 120. Narrowing 1287 -> 1281 (GetMultArray's four Str10 conversions,
ParametersOkay's two copied `SetPrefix` arms), range 4 -> 4. Nothing to
re-freeze.

**Questions this raised -- NY4I's:** Q48-Q51 (§9); Q33 updated.

### 8.2m M9a -- what it covered (2026-10-02)

**Everything a contest owns that feeds the display and the reports is on its
class, as DATA the UI asks for.** No class touches a form, a canvas or a
global: the New Contest dialog, the totals window, the summary sheet, the hour
report, the Cabrillo writer, the score-posting clients and the WRTC menus ask
the contest (`ContestIdentity`) and render the answer. And design 7.11 landed:
**set-up never writes MY STATE**. NY4I approved M9a and delegated its design
forks; each DECIDED entry rests on the evidence given with it. No contest
gained a class.

**MEASURED FIRST** -- `Lint-ContestNameTests -List` at 69828f2a (151 in 12
files), the inventory's UI, score/summary/totals, Cabrillo-export and
networking tables, and every reader of `Settings.My.State`:

| site | contests | seam (on `TContestBase`) | moved |
|---|---|---|---|
| `uNewContest.ApplyIAmIn` / `ApplyContestChoice`, two `case SelectedContest of` (92 arms and the party head's BCQP test) | 115 registered contests (and two no-op arms), 3 classless | `DescribeNewContestPrompts(TNewContestPrompts)` | 87 of its 92 tests; POTA, RSGB 1.8 and the UA4W Championship stay (`ClasslessPrompts`) |
| `uTotal.UpdateTotals2` | OZCR_O, IARU, RUSSIANDX, RU3AX | `TotalsDisplay` (`TTotalsDisplay`) | all 5 |
| `PostUnit.WriteScoreInformationToSummarySheet` | WINTERFIELDDAY x2, ARRLFIELDDAY | `SummarySheet` (`TSummarySheetLayout`) | all 3 |
| `PostUnit.PrintHourTotals` | the Cup RF CW/SSB, Ural Cup, Ukraine Championship, RF Championship CW/SSB, RU3AX | `ReportsRunningScore` | 1 |
| PostUnit's Cabrillo header: the LOCATION guard, General QSO's name, Winter Field Day's section lines | ARRL10, WINTERFIELDDAY, GENERALQSO | `RequiresCabrilloLocation`, `CabrilloContestName`, `CabrilloHeaderLinesBeforeTag` | all 4 |
| PostUnit's Cabrillo QSO lines: FM as PH | WINTERFIELDDAY | `CabrilloModeString` | 1 |
| `uExchangeBuilder` (HamScore, the UDP contact broadcast, the log's `exchange_sent`) | 19 contests, RTC's sent side | `CanonicalReceivedExchange`, `CanonicalSentExchange` | all 11 |
| LOGSUBS2's score-posting XML | WRTC | `ScorePostingMultiplierType` | 1 |
| `MainUnit.CreateMainWindow` menus, `OpenTR4WWindow`, LOGEDIT's Super Check Partial | WRTC | `PermittedOperatingAids` (`TOperatingAid`) | all 3 |
| `MainUnit.CreateMainWindow`'s QTC menu | DARCWAEDCCW..DARCWAEDCSSB | `OffersQTCs` | 1 |
| every set-up that blanked or replaced MY STATE | Canada Day/Winter, Russian DX, RU3AX, Cup RF CW/SSB/DIG | `TSessionDefaults.SentState` -- 7.11 | all 7 |

**DECIDED: THE PROMPTS ARE ORDERED STEPS IN THE DIALOG'S OWN TERMS, IN A CLASS
(`TNewContestPrompts`).** Each step is what one statement of an arm did: offer a
field's row, offer it with a comment, show the "I am in" box. Two lists: on
choosing the contest, and on ticking its box. Considered and rejected: a SET of
fields plus one comment -- the dialog hands rows out in the ORDER fields are
asked and the last comment wins, and those orders differ (NAQP asks MY STATE
then MY NAME, CWops the other way), so a set would lose behaviour. A class for
`TSessionDefaults`' reason (it owns ordered lists); its element
`TNewContestPrompt` is a record, the interface parameter. The field list moved
from uNewContest (`InitialCommands`, deleted) to `uContestBase.TNewContestField`
-- same members, same order -- because a contest has to name a field and may
not reach into a UI unit.

**DECIDED: THE CLASS STATES ITS WORDS, AS THE `TC_` RESOURCESTRINGS THE ARMS
USED.** A contest owns its wording; it is read when the dialog asks, so a
loaded translation still reaches the screen. Considered and rejected: a
text-key enum the dialog maps to strings -- a shared set of wording, which §0.2
retires. "I am in %s" (`TC_IAMIN`) stays the DIALOG's words: a contest states
the region (`OfferIAmIn`), and the two that set the whole caption say so
(`OfferIAmInCaption`: IOTA's island station; POTA's Activator, classless).

**DECIDED: THE QSO-PARTY HEAD IS THE BASE'S, KEYED ON THE TRAIT, NAMING THE
QSOParties AREA.** The dialog put up the county-or-state row for any contest
whose row has a P, but BC. The base does it for `IsUSQSOParty` (equal to P for
every class -- `Test_MovedRowValuesStillMatchTheArray`), so IN7QPNE, classless,
keeps it; British Columbia overrides without `inherited`; Colorado and
Minnesota call `inherited` and add MY NAME. **The area is the QSOParties
entry, NOT `HostState`**: `USQSOPartyStateName` answers only a two-letter
state, so the 7QP's '7th area' and IN7QPNE came out blank. The new test caught
it on its first run.

**THE PROOF.** `uTestContestDisplay.Test_NewContestPromptsAreTheDialogsArms`
renders every contest's prompts -- all 185, class or not -- and compares them
with `ExpectedOnChoice` / `ExpectedWhenTicked`, which were GENERATED by a parse
of the two `case`s at 69828f2a, not from the classes; the party head is
computed in the test from the row's P and the table, as the dialog computed
it. The classes themselves were generated from the same parse, and the parse
was read against the source arm by arm. Arms that named several contests are
copies (§1.4), each class saying which others shared it; the Sweepstakes and
NRAU-Baltic runnings, identical in both lists, are their family base's. Two
no-op arms (MWC, VAQP in the ticked case) did nothing and have no override.

**DECIDED: THE TOTALS WINDOW AND THE SUMMARY SHEET READ RECORDS**
(`TTotalsDisplay`, `TSummarySheetLayout`) -- one getter each, pure data, the
interface-parameter exemption. Each override starts from `inherited` and states
what differs. ARRL Field Day's summary states its QSO points as the claimed
score, one column further in, as its arm did.

**DECIDED: THE CABRILLO HEADER IS PER TAG, KEYED ON THE TAG'S NAME.** Winter
Field Day's two lines come before `LOCATION:`; the writer asks every tag. The
key is the Cabrillo spelling (`LOCATION`), not `uCbrSum.CabrilloTags` -- a UI
unit a class may not reach. The general header stays PostUnit's (CATEGORY-POWER
is M9b, 7.6). **The class's lines are written through `UTF8Encode`**, as the
ARRL-SECTION line always was; `X-EXCHANGE:` went through an implicit ANSI
conversion before -- identical for every legal FD class (`1A`..), and narrowing
fell by one.

**DECIDED: THE CABRILLO MODE COLUMN'S BASE CALLS `uCabrilloFormat.FormatCabrilloMode`,
AND POSTUNIT'S INLINE COPY OF IT IS DELETED.** The helper existed, was unit
tested, and already took the "FM is phone" flag Winter Field Day needs; PostUnit
had written it out a second time with the contest test inside. HamScore's
one-QSO line (`uCabrillo`) calls the helper with no override, so it writes
Winter Field Day's FM as `FM` where the file writes `PH` -- unchanged, Q54.

**DECIDED: THE CANONICAL EXCHANGES ARE THE CONTEST'S; THE SHARED PIECES ARE A
LEAF.** `uExchangeBuilder` keeps its two entry points, reads the session's
settings (the CQ exchange template, MY GRID), asks the QSO's contest -- the
`case` keyed on `ceContest` too -- and collapses the received form, as every
arm was. Its helpers (`CollapseWhitespace`, the default RST, the template
rebuild) moved line for line to `uCanonicalExchange` (VC, SysUtils, StrUtils),
which the classes call. The arms that named both runnings of a family are the
family base's (CQ WPX, CQ WW, ARRL DX); the WAEDC's CW running and CQ 160's CW
running alone were named, and alone override. The base's received form is the
exchange as typed; its sent form is the template, `#` our serial, `5NN` as 599.

**DECIDED: WRTC'S THREE TESTS ARE ONE FACT -- THE OPERATING AIDS IT FORBIDS --
AND IT IS THE CONTEST'S, NOT M9b's.** The menu greying, the windows refused and
the Super Check Partial skipped all said "WRTC is unassisted"; which aids a
sponsor forbids is a rule. `TOperatingAid` names three (Super Check Partial,
DX cluster, score posting); which WINDOW is which aid is UI wiring and stays in
MainUnit (`OperatingAidOfWindow`). The WAE QTC menu in the same block is
`OffersQTCs`. Tesla's `DisplayTotalScore` repaint stays where M7b left it:
display, not a rule.

**DECIDED: SCORE POSTING ASKS A LABEL PER KIND, AND '' POSTS NONE.** The base's
labels are the four LOGSUBS2 always posted; WRTC's class holds its own two and
the all-modes-row rule. **Finding: the writer walks CW, digital and phone rows
only, so the all-modes row never comes and WRTC has never posted a multiplier**
-- transcribed, Q55.

**DECIDED (design 7.11): THE STATE SENT IS THE SESSION'S, AND MY STATE IS NEVER
WRITTEN BY SET-UP.**

- `TSessionDefaults.MyState` is `SentState` (`svSentState`): what the contest
  sends where MY STATE goes. FCONTEST's applier holds it for the session
  (`ApplyContestSentState`); `FCONTEST.SentMyState` answers it when stated, else
  MY STATE; FoundContest clears it at its head, so the next contest starts from
  MY STATE. Exported for `Test_SetUpNeverWritesMyState`, which runs every
  contest's set-up for three stations and asserts MY STATE untouched.
- **Every reader of the SENT exchange was found and repointed:** set-up's
  exchange messages (`SetUpRSTMyStateExchange`, `SetUpNameAndStateExchange`,
  `SetUpRSTMyZoneExchange`, the closing `case ActiveExchange`), LogCfg's UA4W
  default, the CW `&` macro (LogSend), PostUnit's Cabrillo sent column and ADIF
  `STX_STRING`, uGetScores' posted state, the readiness check, and
  `CurrentStation.MyState` -- so every class's `CQExchangeDefault` and scoring
  sees what it saw.
- **Not repointed, and why:** LOGSTUFF's legacy scoring arms (reachable only by
  a classless contest, which never states a sent state; they die at M10); the
  in-state test (`FoundMyStateInDomFile` -- where the station IS); uTelnet's
  `MY_STATE` script token and Preferences (the station's own value, not the
  exchange).
- **The precedence, decided on evidence:** the contest's sent state stands for
  the session it describes. Considered: clearing it whenever MY STATE is written,
  which would have kept "a later MY STATE line wins" exactly. Rejected: the log's
  reopen re-applies its captured STATION rows after CONTEST
  (`LogStoreApplyContestConfig`), and a log captured by this build holds the
  operator's MY STATE -- so any change of MY STATE between sessions would clear
  the contest's state and send the stale one, where the old build re-blanked on
  every set-up. What changes instead: a MY STATE statement after the CONTEST
  line, or a mid-session Preferences edit, no longer reaches these seven
  contests' sent exchange (Q56).
- **The setup section of the matrix moves, and only there:** `setting.MY STATE`
  and its alias `setting.MY QTH` now show the station's value in these seven
  contests' records, in exactly the variants whose set-up stated one.

**Found on the way, not changed (Q57):** `SetUpRSTMyZoneExchange` writes MY
ZONE (zone + state) and restores it -- a transient station write, and the
write marks MY ZONE operator-stated (`TMySettings.SetZone` sets `FZoneWasSet`)
for CQ WW RTTY whenever MY STATE is set.

**DECIDED (NY4I's ruling, enforced): EVERY CLASS STATES ITS DISPLAY NAME,
CABRILLO NAME AND ADIF ID.** Fifteen classes inherited `CabrilloName`,
`ADIFContestId` and `FriendlyName` from the row (the ARRL DX, Sweepstakes, CQ
WW and CQ WPX runnings, Florida, Michigan, General QSO, IARU, the NA Sprints,
Winter Field Day); each now states the value the row gave it. **`DisplayName`
is the human name, the `FriendlyName` where the row has one**: 56 classes
whose display name was their enum spelling now say their friendly name, and 12
whose hand-written display name differed from it now say it too (the old names
are Q52); 47 rows have no friendly name, so their display name is still the
enum spelling (Q53). `DisplayName` has no reader outside the tests until M9b
renders it, so no output moved. **The detection:**
`Test_EveryClassStatesItsIdentity` reaches each protected getter as a
descendant does and compares its code with the parent class's -- a family base
stating a name would give two contests one name -- with a negative control (the
ARRL DX base, which states none) proving the comparison can fail; the
enum-spelled list is a ratchet.

**Left for M9b and later, with the step each waits for** (the 34 contest-name
tests still in shared code):

- the New Contest drop-down showing `DisplayName`, and CATEGORY-POWER as one
  value (7.6) -- M9b, the UI;
- General QSO's display rules -- multiplier and QSO status, station
  information and possible calls (MainUnit, LOGEDIT, LOGSUBS2 x2, LOGWIND), the
  ten-date warning (PostUnit) and WARC band stepping (LOGSTUFF) -- one question
  first: is General QSO a contest at all (it is a log)? M9b;
- the FOC Marathon's log columns (MainUnit x3) -- a `LogColumns` seam; WAG's
  call-window frequency warning (MainUnit); the CQ WW / IARU off-time minimum,
  a string test on the name (MainUnit, PostUnit) -- M9b;
- the classless arms: ~~POTA~~ (done 2026-10-13, §8.2o) (MainUnit x2, PostUnit x3, uADIF, FCONTEST,
  uNewContest x2; Q6), the UA4W Championship (FCONTEST, LogCfg, LOGSTUFF,
  uNewContest; Q28), RSGB 1.8 (LOGEDIT, uNewContest x2; Q33);
- LOGEDIT's initial-exchange rules (OZCHR, RF Championship, Russian DX, IARU;
  Q50), Radio YOC's loader (engine state), the Cup RF his-QTH in the Cabrillo
  writer (Q23), the legacy RU3AX doubling in LOGSTUFF (dead, M10).

**Gates, run 2026-10-02 on a full build.** The contest matrix: **178 identical, 7
differing** -- Canada Day, Canada Winter, the Cup RF CW/SSB/digital, Russian DX
and RU3AX. Compared by script with `setting.MY STATE` and its alias
`setting.MY QTH` excluded, **no other line moved in any of the seven**, and no
record outside them moved at all. The moved lines are exactly the variants
whose set-up stated a sent state (Canada: the us variant; the Russian DX
contests: us and ve; the Cup RF: all three), now showing the station's value
-- 7.11 working. Re-freeze the seven for that reason. Golden corpus **24
passed, 0 failed, 2 known-divergence, 13 sets exported, exit 0** -- it pins
Winter Field Day's header lines and FM-as-PH column and General QSO's
`CONTEST:` name through the new seams; `test-adif-roundtrip.sh` **13
passed**; unit tests **0 failed** (54,700 passed; `uTestContestDisplay`
new). `Lint-ContestNameTests` 151 -> 34: unewcontest 92 -> 5, uexchangebuilder
11 -> 0, utotal 5 -> 0, postunit 14 -> 5, mainunit 11 -> 8, logedit 7 -> 6,
logsubs2 3 -> 2; its floor 120 -> 27. Narrowing 1281 -> 1279 (measured file by
file against a HEAD build: PostUnit's X-EXCHANGE line, LOGSUBS2's second
`<mult>` loop), range 4 -> 4.

**Questions this raised -- NY4I's:** Q52-Q57 (§9).

### 8.2n M9b -- what it covered (2026-10-02)

**The UI itself asks the contest.** NY4I approved M9b and delegated its design
forks; each DECIDED entry rests on the evidence given with it. No contest
gained a class. Three of NY4I's rulings are implemented: the drop-down shows
the display name, inactive contests go to the bottom, and CATEGORY-POWER is
one value with the last touch winning (7.6).

| site | contests | seam / change | moved |
|---|---|---|---|
| `uNewContestForm.FillContests` -- `all.Add(ContestTypeSA[ct])`, a `Sorted` combo, and `uNewContest` reading the caption back through `GetContestFromString` | all | `DisplayName`, the new `IsActive`; `uContestChoices` (order, mark); the form holds a `ContestType` per line | -- (no contest-name test) |
| `MainUnit` call entry, `LOGEDIT.ShowStationInformation`, `LOGSUBS2` x2, `LOGWIND` -- `Contest <> GENERALQSO` around the status displays | General QSO | `ShowsContestStatus` | 5 |
| `PostUnit.CheckForNewContestDate` -- the ten-date warning | General QSO | `MaximumContestDates` (base 10, 0 never) | 1 |
| `LOGSTUFF` band stepping -- WARC skipped unless General QSO | General QSO | `BandStepIncludesWARC` | 1 |
| `MainUnit` log columns -- `Contest = / <> FOCMARATHON` x3 | FOC Marathon | `PowerFieldIsFOCNumber` | 3 |
| `MainUnit.CallWindowChange` -- `if Contest = WAG then WagCheck` | WAG | `CallEntryFrequencyWarning(aFreqKHz)`; `WagCheck` is `ShowCallEntryFrequencyWarning` | 1 |
| the Cabrillo summary's `_CATEGORY-POWER` header-store copy; PostUnit's 3830 report reading it | all | one value, `Settings.Contest.CategoryPower` (7.6) | -- |
| `MainUnit` / `PostUnit` off-time minimum -- `pos('CQ-WW', ...)` / `'IARU-HF'` | CQ WW x3, IARU | **NOT MOVED** -- Q60 | -- |

**DECIDED: THE DROP-DOWN HOLDS A `ContestType` PER LINE, AND THE TOKEN IS
STILL WHAT IS WRITTEN.** `TfrmNewContest.FContests[i]` is line i's contest,
filled in the same loop as `Items` from one `TContestChoices` -- a typed field
the view owns, not an `Objects[]` cast and not the caption read back.
`SelectedContest` answers the identity; `ContestName` still answers
`ContestTypeSA`, because it names the log file and is the `CONTEST` command's
value -- choosing by display name writes exactly what choosing by token did.
**The combo's `Sorted` is off** (the `.lfm`): a sorted combo reorders `Items`
behind the array.

**DECIDED: THE ORDER IS ACTIVE FIRST, THEN BY DISPLAY NAME** (case-insensitive,
`UnicodeCompareText` -- the platform's collation, as a sorted LCL list uses),
a tie by the enum. The Win32 combo sorted the tokens (`CBS_SORT`); sorting by
what the operator reads is the only order that helps him find it. Considered
and rejected: grouping by sponsor or by mode -- no contest states either, and
inventing a grouping is a design of its own.

**DECIDED: AN INACTIVE CONTEST IS MARKED `'%s (inactive)'`** -- `SContestInactive`,
a resourcestring, so a translation reaches it -- and listed last. `IsActive` is
a property on `TContestBase` (base True), stated False on SA Sprint and Locust
only, on NY4I's word; Q59 asks for others. It changes nothing else: an
inactive contest's log opens and scores as before.

**DECIDED: THE DISPLAY NAMES ARE NOT TRANSLATED.** They are the sponsors'
proper names, and the same names are the friendly names the summary sheet's
`CONTEST:` line and the log database carry -- a translation there would change
output. The dialog's other captions are translated from `TC_`/`RC_` constants
(`HandleShow`), which is where its translatable words are.

**DECIDED: A SHARED DISPLAY NAME IS TOLD APART BY THE TOKEN IN BRACKETS.**
`uTestContestUI` found it on its first run: WRTC's row gives it IARU's friendly
name, so IARU-HF and WRTC were two identical lines -- a contest an operator
could not pick, the radio list's "a duplicate display name makes a model
invisible". Each such line adds its token (`IARU HF World Championship [WRTC]`);
a unique name is bare. Brackets, not words: nothing to translate. Considered and
rejected: renaming WRTC here -- its display name is its friendly name (NY4I's
M9a ruling), which is the summary sheet's `CONTEST:` line, so that is NY4I's
(Q58). The pair is held as a ratchet.

**DECIDED (7.6): CATEGORY-POWER IS `Settings.Contest.CategoryPower`, AND THE
SUMMARY WINDOW WRITES IT.**

- `uCbrSum`: `_CATEGORY-POWER` is no longer saved to the header store
  (`ctrSave` False), and `CabrilloTagText(ctCategoryPower)` answers the setting
  when the window is closed -- so the Cabrillo header, the 3830 report (which
  read the store directly; repointed) and the log's entry declaration all read
  the one value scoring reads. A `_CATEGORY-POWER` left in `tr4w.json` is inert.
- **The evidence the two disagreed:** the golden corpus's `arrl_digi` log says
  `CATEGORY-POWER=LOW`; its exported Cabrillo header said `HIGH`, from the
  corpus settings' header store. After M9b it says `LOW` (and `winter_fd`, also
  LOW, likewise) -- the score was always LOW's. **This is the one output
  change**, and the corpus does not compare the header (`golden_diff.py` keeps
  `QSO:`, `X-QSO:` and `CLAIMED-SCORE:` only), so it stays green.
- `uCabrilloSummaryForm.CommitCategoryPower` applies the row through
  `SetCFGCommandValue('CATEGORY-POWER', ...)` -- the route every settings screen
  takes (applies, records the operator's statement, tells a multi-op peer) --
  **before** the export action runs, so the file's CLAIMED-SCORE is scored with
  the power its header declares, and again on close (every exit saves, as it
  always did; the second call finds nothing changed).
- **The decision is `uCategoryPowerChange.DecideCategoryPowerChange`** --
  unchanged (same power, or text that is no power), set (no QSOs logged), set
  and rescore (QSOs logged). Re-saving the same value does nothing, so closing
  the window never rescores by accident.
- **The rescore is the existing Rescore command.** `tUpdateLog(actRescore);
  LoadinLog;` was written out at four sites (the menu, the QSO editor, ADIF
  import, a multi-op update); it is `MainUnit.RescoreLog` now and all four call
  it, with the summary window the fifth. No new rescore was written.
- **The reminder is a NOTICE** (`QuickDisplay`, the main window's 30-second
  strip): *"CATEGORY-POWER is now %s -- the scoring category changed and the
  log was rescored."* (`SCategoryPowerChangedRescored`). Considered and
  rejected: a modal confirm -- NY4I's ruling is that the change is allowed
  ("let it be changed"), so a question would be a block with an extra click;
  the notice is the app's own channel for an event announcement. It shows only
  with QSOs logged: with none there is no category to have changed, which is
  also why the New Contest dialog, which sets the first value, never shows it.

**DECIDED: GENERAL QSO'S DISPLAY RULES ARE THREE TRAITS, NOT ONE "IS A LOG"
FLAG.** `ShowsContestStatus`, `MaximumContestDates`, `BandStepIncludesWARC` --
each names what the UI does with it, so a contest other than General QSO can
answer one without the others. This answers 8.2m's "is General QSO a contest at
all?" only as far as the UI needs: whatever NY4I decides, these are the facts.
`MainUnit`'s site also hides the possible calls for General QSO and `LOGSUBS2`'s
does not -- transcribed as it stood.

**DECIDED: THE FOC MARATHON'S COLUMN IS A FACT ABOUT ITS EXCHANGE**
(`PowerFieldIsFOCNumber`): the member number rides in the power field
(`RSTPowerExchange`; its ADIF import fills `Power` from `FOC_NUM`, M5a), so the
log shows FOC# instead of PWR. The column itself stays MainUnit's. The PWR
column's Enable is left untouched for the FOC Marathon, exactly as the two
tests left it.

**DECIDED: WAG'S WARNING IS THE CONTEST'S WINDOWS AND WORDS**
(`CallEntryFrequencyWarning(aFreqKHz)`, '' for none): the seven ranges moved
as they stood, every bound exclusive (7080 kHz, between two windows, does not
warn), and the words are `TC_WAGWarn`, read when asked. Which radio, and
showing it as a notice, stay MainUnit's (`ShowCallEntryFrequencyWarning`).

**NOT MOVED, WITH THE REASON: THE OFF-TIME MINIMUM (Q60).** It is a sponsor
rule and the seam would be one integer -- but its two readers disagree:
`MainUnit.CreateMainWindow` uses 60 minutes for CQ WW *and IARU HF* (4.115.4),
`PostUnit.CalculateTotals` 60 for CQ WW only, keyed on `Settings.Contest.Name`
(so a stated `CONTEST NAME` changes it). The same in D7. One value would change
one reader's output for IARU -- a sponsor question, not a UI move.

**Gates, run 2026-10-02 on a full build.** The contest matrix **185
identical, 0 differing** -- no re-freeze. Golden corpus **24
passed, 0 failed, 2 known-divergence, 13 sets exported, exit 0**;
`test-adif-roundtrip.sh` **13 passed**; unit tests **0 failed** (78,271 passed;
`uTestContestUI` new). `Lint-ContestNameTests` 34 -> 23: mainunit 8 -> 3,
logedit 6 -> 5, logsubs2 2 -> 0, logwind 1 -> 0, postunit 5 -> 4, logstuff
3 -> 2; its floor 27 -> 18. Narrowing 1279 -> 1277 (both in the drop-down:
`TStringList.Add` of a native string, and the caption into
`GetContestFromString`'s ShortString), range 4 -> 4. i18n: two resourcestrings
(`SContestInactive`, `SCategoryPowerChangedRescored`) entered all 22
catalogues through `po_merge --pot` from a two-entry scratch template, fuzzy
and empty; every catalogue +2 entries, reviewed and with-text counts unchanged,
the diff adds lines only.

**Questions this raised -- NY4I's:** Q58-Q61 (§9).

### 8.2o POTA -- what it covered (2026-10-13; Q6)

NY4I ruled Q6 the same day: *"yes, make POTA a contest class. while it is not
a contest per se, just like with GENERAL QSO, we treat it that way."*
`TContestPOTA` (`uContestPOTA`) sits on `TContestBase`, beside General QSO, and
transcribes **exactly** what the program did for POTA. No family base (§6:
none until a second activity arrives).

**EVERY SITE, MEASURED FIRST** (`rg -i -w POTA tr4w/src`, the lint's `-List`,
and the identifiers the arms called) and classified:

| site | kind | where it went |
|---|---|---|
| `FCONTEST.FoundContest`'s `POTA:` arm | rule (set-up) | `DescribeSession` -- dupes allowed, auto-dupe off both ways, contest name `POTA`, WARC on, CW F1/F2, the QSL message. Its last line, `InitOperatorNameSet`, is engine work: a REQUEST, `TSessionDefaults.UseOperatorNameSet`, which the applier runs last, where the arm did |
| `MainUnit.ApplyClasslessADIFImport` | rule (import) | `ApplyADIFImport`, without `inherited` -- the arm replaced the base's default. **The routine is deleted**: POTA was its last contest |
| PostUnit's tail, `<> POTA` / `= POTA` around the SRX_STRING | rule (export) | the new seam `EmitADIFExchangeFields` (base: the `SRX_STRING` alone) and `FormatADIFReceivedExchange` (the park, else the typed exchange) |
| PostUnit's location `case`, `POTA:` arm | rule (export) | `EmitADIFContestFields` -- `SIG`, `SIG_INFO`, `POTA_REF` for a park |
| uADIF's `rec.ceContest <> POTA` | rule (export) | `WritesADIFContestId` False |
| uNewContest's two `POTA:` arms | rule (UI as data) | `DescribeNewContestPrompts` -- `OfferIAmInCaption('Activator')`, MY PARK when ticked |
| MainUnit's `Contest <> POTA` menu test | UI | the new trait `OffersParkTools` (base False), as `OffersQTCs` |
| LOGSTUFF's `OnePointPerQSO` arm | rule (scoring) | `CalculateQSOPoints`, `FixedModePoints(1, 1, 1)` |
| `logstuff.IsValidPOTAPark`, `ResolvePOTAParkFromADIF`; `Tree.LooksLikeAState` | TRDOS helpers | LIFTED to the leaf `uPOTAReference`, originals deleted; LOGSTUFF's POTA shape parser calls them there |
| `Tree.LooksLikeAPOTAPark` | TRDOS alias | DELETED -- one line calling `IsValidPOTAPark`; PostUnit's POTA tests were its only callers |
| `Tree.LooksLikeAGrid` (reads `ActiveExchange`) | TRDOS helper | its two halves LIFTED to the leaf `uGridShape` -- `GRID_CARRYING_EXCHANGES` and `LooksLikeGridSquare`; Tree's two grid tests ask both (one copy of the shape where there were two); the class is handed the session's exchange as data |
| the `RSTAndPOTAPark` exchange SHAPE: LOGSTUFF's parser (`ProcessRSTAndPOTAPark`), `ExchangeInformation`, ParametersOkay's blank-exchange test, the park-name display | engine (shape) | **STAYS** -- shapes name no contest and retire with the shared sets at M10 (Q4). The base's `ParseReceivedExchange` already hands the session's shape to it |
| the n-fer queue (`uPOTAParks`), `TryLogContact`'s drain, Repeat POTA Parks | engine | **STAYS**, untouched -- one contact, one row per park in one QSO set, exactly as before |
| the park list, its download, the schema's `my_park`/`rcvd_park` | POTA DATA | **STAYS** |

**WHY LEAVES, NOT SERVICES.** All three helpers are pure functions of their
text (the grid test once its global is a parameter), so a station-context
service would have been a function pointer to code the class can simply call.
`IsValidPOTAPark` lost its two debug lines per call -- a leaf does not reach the
program's logger. `ResolvePOTAParkFromADIF`'s `AnsiUpperCase` became
`UpperCase`: no non-ASCII letter upper-cases to P, O, T or A, so the answer is
the same, without narrowing the tag through an AnsiString.

**ONE BUILDER FOR `TMyStationExchange`.** POTA's activation fields read MY PARK,
which PostUnit filled in two drifted copies (the Cabrillo writer never set
`MyPark`); a third reader made it `PostUnit.CurrentMyStationExchange`. No
Cabrillo formatter reads `MyPark`, so no file moved.

**THE PROOF.** The contest matrix: **184 identical, 1 differing (POTA)**, and
POTA's record compared by script with the `contest.class =` line excluded is
**byte-identical** (805 lines; the three variants' class lines are the only
difference). Its synthetic QSOs carry no park, so `uTestContestPOTA` pins the
branches it cannot reach: the activation block for a park, a state, a grid (in a
session that carries one and one that does not) and nothing; the park tags; the
import for `POTA_REF`, `SIG`/`SIG_INFO`, a state and neither; the set-up value
for value; one point every mode; the park tools on POTA alone; the base's
exchange block for every other contest; both leaves. The New Contest table in
`uTestContestDisplay` gained POTA's two arms by hand. Golden corpus **24
passed, 0 failed, 2 known-divergence, 13 sets exported, exit 0**;
`test-adif-roundtrip.sh` **13 passed**; unit tests **0 failed** (78,757
passed). `Lint-ContestNameTests` 23 -> 14: mainunit 3 -> 1, fcontest 2 -> 1,
postunit 4 -> 1, uadif 1 -> 0, unewcontest 5 -> 3; floor 18 -> 11. Narrowing
1277 -> 1271, range 4 -> 4.

**ONE VISIBLE CHANGE, BY THE M9a RULE:** the New Contest drop-down lists POTA by
its display name, *"Parks on the Air(r) Logging"*, where the classless identity
showed *"POTA"* (Q64).

**Questions this raised -- NY4I's:** Q62-Q64 (§9).

### 8.2p The UA4W Championship and RSGB 1.8 MHz -- what it covered (2026-10-14; Q28, Q33)

The last two contests held classless on purpose gained classes, each on
`TContestBase` like the M7b siblings: `TContestUA4WChampionship`
(`uContestUA4WChampionship`) and `TContestRSGB18` (`uContestRSGB18`). Each
states its whole row as literals (`Test_MovedRowValuesStillMatchTheArray`) and
its identity in the leaf (`Test_EveryClassStatesItsIdentity`; both display
names are the enum's spelling, `R4W-CHAMP` and `RSGB-160`, and joined that
ratchet). **Classless now: IN7QPNE (a composite, 7.14 -- the next step) and
DUMMYCONTEST.**

**EVERY SITE, MEASURED FIRST** (`rg -i -w` for both enum members over
`tr4w/src`) and classified:

| site | contest | kind | where it went |
|---|---|---|---|
| LOGSTUFF's `UA4WMethod` arm | UA4W | rule (scoring) | `CalculateQSOPoints`, transcribed but for the zone's SOURCE (below). The arm stayed for `QSO POINT METHOD` until it was deleted at M10 S3 (7.15) |
| `FCONTEST.FoundContest`'s `UA4WCHAMPIONSHIP:` arm | UA4W | rule (set-up) | `DescribeSession` -- 15-minute minitours. **The `case` is deleted**: it was the last arm |
| `LogCfg.tSetupExchangeNumbers`'s `UA4WCHAMPIONSHIP:` | UA4W | rule (set-up) | `CQExchangeDefault` -- `' # '` + the state sent. **The `case` is deleted**: it was the last label |
| `LOGSTUFF.ProcessRSTAndGridSquareOrRDAExchange`'s `Contest = UA4WCHAMPIONSHIP` | UA4W | rule (parse) | `ParseReceivedExchange`: the base's parse, then, under the shape it was written for, a found QTH is the domestic QTH |
| uNewContest's `ClasslessPrompts`, `UA4WCHAMPIONSHIP:` | UA4W | rule (UI as data) | `DescribeNewContestPrompts` -- the RDA-or-grid comment on MY QTH, the literal as it stood |
| LOGSTUFF's `RSGB160Method` arm | RSGB 1.8 | rule (scoring) | `CalculateQSOPoints`, asking the sheet through `IsNewMultiplierAnywhere`. The arm stayed for `QSO POINT METHOD` until it was deleted at M10 S3 |
| `LOGEDIT.TotalScore`'s `Contest = RSGB18` | RSGB 1.8 | rule (final score) | `CombineWithMultipliers` = the points. `TotalScore` names no contest now |
| uNewContest's `ClasslessPrompts`, both `RSGB18:` arms | RSGB 1.8 | rule (UI as data) | `DescribeNewContestPrompts` -- the UK box, then the district. **`ClasslessPrompts` is deleted** |
| `MainUnit`'s `ERMAK_BIT` read of `ContestsBooleanArray` | UA4W (the only ERMAK row) | trait, not a name test | **STAYS** -- a row flag read by the Cabrillo menu, no seam yet |

**THE ZONE: `MyZone` IS NOT THE CQ ZONE IN AN ITU-ZONE CONTEST -- MEASURED.**
The legacy arm asked `ctyGetCQZone(MY CALL)`; 7.12 said a class could read
`TStationContext.MyZone` instead. It cannot, here. An UNSTATED MY ZONE is
derived by `FCONTEST.RecalculateMyCountryContinentAndZoneNew` AFTER
`ApplyContestTraits` has set CTY's zone mode from the contest's row, and the UA4W
Championship's row is ITU (`ciCQZoneMode0`). The frozen matrix shows it: K0AAA,
VE3AAA and DL1AAA carry MY ZONE **7, 4 and 28** -- their ITU zones -- where their
CQ zones are 4, 4 and 14. The rule's 18 and 19 are CQ zones (Siberia), so a
class reading `MyZone` would never pay the bonus to an unstated Siberian
station. `MyZone` cannot simply become the CQ zone either: IARU compares it with
the worked ITU zone.

**DECIDED (end state per 7.12): a SERVICE, `TStationContext.MyCQZone`** --
the STATED zone (the contest's override, or the station's typed MY ZONE,
`ZoneWasSet`), else the CQ zone CTY.DAT gives MY CALL. Supplied by
`uContestFactory.EngineMyCQZone`; asked only on the one branch that needs it, as
the arm did, so the CTY swap is no more frequent than before. **One deliberate
difference from the arm:** a STATED zone now wins (NY4I's laptop in CQ zone 3);
the arm ignored it. With nothing stated the two agree exactly. Q69 asks whether
MY ZONE itself should always be the CQ zone; Q70 asks NY4I to confirm the
difference.

**THE SHEET: `TStationContext.IsNewMultiplierAnywhere`** (7.13) -- a read-only
SERVICE, the shape of `IsDomesticCountryCall`. `nmkDomestic` asks
`mo.IsDmMult(DomMultQTH, AllBands, Both, ActiveDomesticMult)`, `nmkDX` asks
`mo.IsDXMult(QTH.Country, AllBands, Both)` -- the arm's own calls, transcribed
exactly: the sheet's all-band, both-mode row, ignoring the session's
by-band/by-mode keys. The class keeps the arm's order and its empty-QTH test.
`nil` is "no sheet": nothing is new, 2 points.

**THE FINAL SCORE.** `CombineScore` is a non-virtual template, so the
"times one" is `CombineWithMultipliers` = `ContestPoints`. Its two earlier
branches (no multipliers counted; the FISTS exchange) also return
`ContestPoints`, and RSGB 1.8 declares no bonus station, so `FinalScore` equals
the old arm in every case.

**EXPECTED MATRIX EFFECT** (stated before the gates were run; the caller runs
them): **only `contest.class =` moves**, in all three variants of each record.
UA4W: none of the 17 synthetic QSOs has a `4W` call and no variant's MY CALL is
in `4W`, so the zone branch is never reached; the CQ exchange, minitours,
prompts and parse are value-for-value. RSGB 1.8: every QSO is scored against
the same sheet through the same entry point and still pays 7; the totals are the
points either way. A re-freeze for those two contests carries that reason.

**TESTS.** `uTestContestFactory`: `Test_UA4WAsksForMyCQZone` (every branch;
`MyZone` set to 18 with the service answering 16 pays no bonus; the service is
asked only on its branch; no service is zone 0) and
`Test_RSGB18AsksTheSheetReadOnly` (domestic first, then DX; no domestic QTH
skips the domestic question; a QSO that is NOT a new multiplier scores 2; no
service scores 2); the classless ratchet is now DUMMYCONTEST and IN7QPNE.
`uTestContestTotals.Test_RSGB18ScoresItsPointsAlone`;
`uTestContestParse.Test_UA4WQTHIsTheDomesticQTH`; `uTestContestDisplay`
gained both contests' prompts and both enum-spelled names;
`uTestContestImport.Test_ClasslessDefault` asks a plain `TContestBase` now (it
borrowed RSGB 1.8 while that was classless). `EngineMyCQZone` and
`EngineIsNewMultiplierAnywhere` read the program's globals, so they are
reachable from the matrix only, not from the unit tests.

**RATCHETS.** `Lint-ContestNameTests` 14 -> 7: fcontest 1 -> 0, logcfg 1 -> 0,
unewcontest 3 -> 0 (all unlisted), logstuff 2 -> 1, logedit 5 -> 4; floor
11 -> 5. Narrowing 1271 and range 4 on a full build, both unchanged. The
contest-rules inventory's scanner accepts a `FoundContest` with no
`case Contest of` (the end state) and its SHAPE3 `'TRC'` pattern follows 7.12's
`ResolvedState` (it had stopped matching at c3986877).

**Questions this raised -- NY4I's:** Q69-Q71 (§9).

### 8.2q The Delaware QSO Party -- what it covered (2026-10-14; 7.14)

A NEW contest, not a moved one -- the second after Idaho (8.2d). NY4I ruled it
into existence on 2026-10-13 (7.14). `TContestDelawareQP`
(`uContestDelawareQP`) sits on `TContestStateQSOPartyBase`: one host state,
county multipliers for everyone outside it, and "non-DE stations work DE
stations only", which is the base's 7.10 refusal unchanged. It knows nothing
of IN7QPNE; the composite, when it is built, delegates to it per QSO.

**THE ENUM IS APPENDED** after `IDAHOQSOPARTY`, never inserted. Checked, not
assumed: the ordinal is written as `Ord(RxData.ceContest)` into HamScore's
`<contestnr>` (`logsubs2`), and `ceContest` is a one-byte field of the
`ContestExchange` records the binary log and the multi-op packet carry
(`VC.pas`); the SQLite log stores `ContestTypeSA`'s spelling
(`uLogRepository`). `Test_DelawareIsAnAppendedStateParty` pins
`Ord(DELAWAREQSOPARTY) = Ord(IDAHOQSOPARTY) + 1`.

**WHAT WAS ADDED.**

| piece | where |
|---|---|
| the member, `ContestTypeSA` `'DELAWARE QSO PARTY'`, the row, the flag word (QB1 QM1 MB1 MM0 VHF1) | `VC.pas` |
| `QSOParties` entry 22, `delaware` / `DE` | `VC.pas` (`QSOPartiesCount` 21 -> 22) |
| the class, one `RegisterContest` | `uContestDelawareQP`; both `.lpr` files |
| `delaware.dom` (NEW, in state): the county file FIRST, then `S50`, `P13` | `target/dom`, `full.nsi` (`Lint-DomCoverage`) |
| `delaware_cty.dom` (rewritten): `NDE > De = NDE,^New Castle` etc. | it said `NDE = NDE,...`, so an in-state include would have made each county its own multiplier; the `>` form maps all three to `De` in state and keeps each county out of state (`MultipliersIsCounties`), as Idaho's file does |
| a template `.cfg`, `CONTEST = DELAWARE QSO PARTY`, overriding nothing | `target/dom/Delaware QSO Party.cfg` -- **`*.CFG` is gitignored; it needs `git add -f`, as Idaho's did** |

**THE RULES AND WHERE EACH LANDED** (the class header carries them in full):

| rule | seam |
|---|---|
| HF but WARC, 6 m and up | `UsesBand`: 160-10 m without 30/17/12, and 6 m through light. 60 m has no `BandType` |
| points by the ENTRANT's location: in DE 1/2/2 phone/digital/CW, outside 10/20/20; FM is phone | `CalculateQSOPoints` on `Station.InHostState` (set-up's in-state answer, from MY STATE resolved, 7.12) |
| multipliers once per band; DE counts states, provinces, DXCC; others the three counties | row `MB1 MM0`; `delaware.dom` / `delaware_cty.dom`; DX `ARRLDXCCWithNoUSACanadaKH6OrKL7` (Texas's value: Alaska and Hawaii are states here); `DescribeSession` states `NoDXMults` for an out-of-state entrant |
| dupes once per band per mode | row `QB1 QM1` |
| a county-line station is two QSOs | `GetCountyLineCountiesMax` = 2 |
| non-DE x non-DE refused with an error | the family base's `ParseReceivedExchange` (7.10), no override |
| exchange RST + county / state / province / DX | `RSTDomesticOrDXQTHExchange` for both sides; the shared Cabrillo and ADIF arms |
| score = points x mults x power + 50 | `CombineWithMultipliers` (`inherited` x `DelawarePowerMultiplier`), `BonusPoints` (`inherited` + 50) |
| Cabrillo `DE-QSO-PARTY`, modes CW/PH/RY, `LOCATION:` required | identity getters; `CabrilloModeString` (every digital mode RY, FM PH); `RequiresCabrilloLocation` |
| ADIF `DE-QSO-PARTY` | `GetADIFContestId`; import resolves it back |
| CQ exchange | `CQExchangeDefault` = `' 5NN '` + the sent state (a DE station's county) |

**DECISIONS TAKEN (delegated):**

- **CATEGORY-POWER maps to the sponsor's three power multipliers as HIGH x1,
  LOW x2, QRP x3** -- the one store (7.6), `Station.MyPower`. The sponsor's
  boundaries are "over 100 W", "100 W or less" and "5 W or less"; TR4W's LOW
  and QRP categories are the Cabrillo ones, and an entrant whose LOW was over
  100 W would be misdeclaring the Cabrillo category too.
- **The 50-point electronic bonus always applies** (NY4I, given with the
  brief): TR4W submits electronically. It is added after the formula, to an
  empty log as well.
- **One exchange for both sides of the state line.** Arizona and Texas narrow
  an out-of-state session to `RSTDomesticQTHExchange`; that refuses the same
  exchanges with the shape's improper-county message, where the base's
  refusal says "Out of state: work DE stations only". Not copied.
- **The QSO line is the shared arm's**, which is the sponsor's column order;
  no override.
- **`QSO POINT METHOD` reads `ARRLFieldDayQSOPointMethod`**, Idaho's value
  and reason: a description in the legacy vocabulary that nothing scores by.

**NOT IN THE CLASS, AND WHY:** a DE mobile that changes county is a new
station -- a dupe-KEY rule, with no seam (8.2l); and the LOCATION header's
value, which the operator types (the class only refuses a file without one).
Both are questions below.

**TESTS.** `uTestContestDelawareQP` (new) pins every rule above: the appended
ordinal and the family base; points for both locations and every mode; the
band list through `UsesBand` and `ContestCreditsBand`, WARC scoring 0 for both
locations; the set-up traits and `DescribeSession` both ways; both county files
(exactly NDE/KDE/SDE, each mapped to `De`, no `INCLUDE`; the in-state file's
three includes in order and no line the reader would take as an entry); the
county line (2 accepted, 3 refused); the refusal both ways; the score at each
power with the bonus, a single-band entry and an empty log; Cabrillo; the ADIF
id round trip; the CQ exchange. Ratchets edited in the same change:
`Test_EveryOtherContestStillCreditsEveryBand` (Delaware states its bands),
`Test_MovedRowValuesStillMatchTheArray`, `Test_ADIFIdsResolveOldAndNew`, and
`Test_CabrilloHeaderAndMode` (a LOCATION required; FM as PH and FT8 as RY).
`ShippedDomDir` -- a third copy was due -- is lifted to `uTestContestObjects`
and the two copies in `uTestContestFactory` and `uTestContestParse` are
deleted.

**EXPECTED MATRIX EFFECT** (stated before any gate ran; the caller runs them):
one NEW record, `DELAWAREQSOPARTY`, reported **unfrozen**; every other record
byte-identical (no shared code changed behaviour -- the edits outside the
factory are the enum, the three `VC.pas` rows and the `QSOParties` entry, all
appended). Freezing it is a deliberate act with that reason. Golden corpus,
factory check and round trip: unchanged (no corpus set is Delaware).
`Lint-ContestNameTests` stays at 7: no contest is named outside the factory.
`docs/CONTEST_RULES_OUTSIDE_FACTORY.md` is generated from `git ls-files` --
regenerate after the commit.

**FINDING, NOT CHANGED: an in-state entrant's ADIF STATE is the host state for
every QSO with a QTH.** `uADIF.EmitADIFRecord` writes
`STATE = GetStateForContest(rec.ceContest)` whenever `QTHString` is set, so a
DE station working Pennsylvania exports `STATE:DE` beside `QTH:PA`. That is
every single-state party's behaviour today (Florida, Idaho, ...), not
Delaware's; Q76 asks it.

**Questions this raised -- NY4I's:** Q72-Q76 (§9).

### 8.2r IN7QPNE, the composite -- what it covered (2026-10-14; 7.14)

The last real contest without a class. `TContestIN7QPNE` (`uContestIN7QPNE`)
sits on `TContestBase` and holds the four component CONTESTS -- Indiana
(`INQSOPARTY`), 7QP (`SEVENQP`), NEQP (`NEWENGLANDQSO`) and Delaware
(`DELAWAREQSOPARTY`, §8.2q) -- and hands each QSO to the one it belongs to.
That is composition of whole contests, which 7.14 asks for; it is not a
strategy and not a registry of rules. **NEW BEHAVIOUR, BY RULING**: until
now IN7QPNE was classless and scored every QSO by one merged rule (its own
files, `PAQSOPointMethod`: phone 1, else 2).

**SUPERSEDED.** The commission for this step cites an earlier instruction,
"Q11 option (a): transcribe IN7QPNE exactly as it is today". That wording is
not written in this document or in `CONTEST_FACTORY_OPEN_QUESTIONS.md` (this
document's Q11 is the `QSO POINT METHOD`-only arms, ruled at 7.15). It is
recorded here as superseded by 7.14 so nobody rebuilds the merged rule from
it.

**THE ROUTING RULE.** A QSO is judged by the party of the worked station's
county, as the session's domestic table resolved it (`DomesticQTH`). The
session loads IN7QPNE's own files, and every county key in
`in7qpne_cty.dom` names its party by its spelling:

| party | key | example |
|---|---|---|
| Indiana | `IN` + three letters | `INADA` |
| 7QP | `AZ ID MT NV OR UT WA WY` + three | `Azaph` |
| New England | `CT MA ME NH RI VT` + three | `MEAnd`, `CTCap` |
| Delaware | `NDE`, `KDE`, `SDE` | `NDE` |

Measured: every key of `in7qpne_cty.dom` routes to exactly one party (three
to Delaware), and no key the in-area file adds -- the states and provinces
of `S50`/`P14`, all two letters, and `dx` -- routes to any. Indiana's,
7QP's and Delaware's OWN county files route to their party too.
`uTestContestIN7QPNE` reads the shipped files and holds all of it.

**WHY THE COMBINED FILE'S SPELLING, NOT THE COMPONENTS' FILES.** They do not
agree for New England: `neqso.dom` spells a county county-first (`AndME`),
`in7qpne_cty.dom` state-first (`MEAnd`), and the combined file carries
Connecticut's planning regions (`CTCap`) where NEQP's carries eight
counties. The session can only hold the combined file's keys, so the
routing reads its convention. Which file is right for NEQP is sponsor data
(Q81).

**NO PARTY, AND OVERLAP.** A QSO whose QTH is in no party -- a state, a
province, DX, or nothing -- is judged by the ENTRANT's own party when the
entrant is in one (an in-state station works everyone in all four parties).
The entrant's party is MY STATE (resolved, 7.12) routed by the same rule,
when set-up found it in state. When the entrant is in none, the QSO is in
no party: refused when typed, with the out-of-state reason every
single-state party gives (7.10) naming the four areas; a logged one scores 0
and earns no multiplier. **Overlap cannot happen**: the four areas share no
state, and the spellings above are disjoint.

**EACH PARTY'S REFUSAL COMPOSES BY CONSTRUCTION.** Indiana's and Delaware's
out-of-state rule (the family base, 7.10) refuses a QTH outside the host's
counties. A QSO routed to a party is either that party's county, which the
rule accepts, or a no-party QTH with the entrant IN that party, where the
rule does not apply. 7QP and NEQP have no refusal. The component's own
`ParseReceivedExchange` still runs, so a rule a component gains later
applies here unchanged.

**THE COMPONENTS ARE OWNED, NOT `ContestIdentity`.** One set per composite
instance, made through `ContestClassFor` and freed with it. The identity
instances are shared, read from worker threads, and carry no station by
contract -- but a component must be handed one to score (Delaware's points
read `InHostState`). So the composite pushes its own station into its own
components per delegation, with `InHostState` saying whether the entrant is
in THAT party. A missing component class raises at construction rather than
scoring a party 0 in silence.

**THE SEAMS, ONE BY ONE.**

| seam | answer |
|---|---|
| `ScoreQSO` / `CalculateQSOPoints` | **per QSO** -- the judging party's whole `ScoreQSO` (its band check first, so Delaware's WARC scores 0); 0 for no party |
| `CountsAsMultiplier` | **per QSO** -- the judging party's answer on the judging party's bands (`ContestCreditsBand(component, ...)` -- the composite's own `UsesBand` cannot route, so this is the only place a party's bands reach the multipliers); False for no party |
| `ParseReceivedExchange` | **per QSO** -- the session's shape parses (that finds the county); no party refuses; otherwise the judging party parses from the record as it arrived. The shape runs twice on success, safe because every shape clears the county-line queue first |
| `UsesBand` (dupe sheet, need-multiplier hint) | **cannot delegate** -- asked with a band and no QSO. The composite credits every band; a Delaware WARC QSO is on the dupe sheet and the hint (harmless: dupes are per call, band and mode) |
| `ValidateQTHCount` (county lines) | **cannot delegate** -- asked with a count and no QTH. The composite allows any number (IN and DE say 2, 7QP 4, unenforced before too) -- Q82 |
| `MarksDupes`, the dupe key | composite's own; all four parties mark dupes per band per mode, as the row does, so the one session rule IS each party's |
| `MultByBand`, `MultByMode`, `VHFBandsEnabled`, zone mode, domestic countries | **cannot delegate** -- one session value. The row's kept: multipliers once per contest, no VHF. Delaware differs (per band, VHF on) -- Q79 |
| which multiplier a QTH counts AS | **cannot delegate** -- the session's one domestic table names it. Each county is its own multiplier; an in-area entrant's states, provinces and one `dx` count too. The parties' own files differ (7QP in state maps its counties to their state) -- Q80; the multiplier KEY is Q4/M10 |
| `DomesticMultiplierFromCall` | composite's own (base `''`); every component says `''` too |
| `DescribeSession`, `CQExchangeDefault`, `DescribeNewContestPrompts` | composite's own, unchanged: states nothing, offers no CQ exchange, the base's QSO-party prompt naming IN7QPNE. The components' per-station choices (7QP's, NEQP's and Delaware's DX multipliers for an in-state entrant) are session values -- Q79 |
| identity, `CabrilloContestName` | composite's own: `IN7QPNE-QSO-PARTY`, never a component's name (7.14) |
| Cabrillo columns, mode column, QSO line, `RequiresCabrilloLocation` | composite's own -- ONE log in one layout. Delaware's RY-for-every-digital-mode and its LOCATION requirement are not applied -- Q79 |
| ADIF export and import (`Format*`, `Emit*`, `ApplyADIFImport`) | composite's own (the base's), id `IN7QPNE-QSO-PARTY`, kept. `HostState` is stated `''`, so no host `STATE` is written |
| `FinalScore` (`CombineWithMultipliers`, `BonusPoints`) | composite's own: the base formula over the combined totals -- a number that is no party's score. Delaware's power multiplier and +50 are not applied. The ruling requires no combined score; no display seam carries a per-party one -- Q77 |
| `PermittedOperatingAids` | composite's own: Super Check Partial and the cluster, **no score posting** (7.14) |

**DECISIONS TAKEN (delegated):**

- **The HamScore uploader now asks the contest.** `PermittedOperatingAids`
  greyed only the post-scores window and its menu row; `uHamScore` asked
  nothing, so WRTC's "no score posting" never reached HamScore and IN7QPNE
  would have been posted whenever `HAMSCORE ENABLE` was on.
  `uHamScore.ContestPermitsScorePosting` now gates the per-QSO queue, the
  resync's `<deletelog>` and every cycle (which posts `<dynamicresults>` even
  with no QSOs). It names no contest. **This changes WRTC too** -- Q83.
- **The refusal reuses `SExchangeOutOfStateWorksHostOnly`** with the four
  areas ("Out of state: work IN, 7th area, NE or DE stations only"); no new
  resourcestring.
- **The row's `QSO POINT METHOD` value stays `PAQSOPointMethod`**: a
  description nothing scores by, retiring with the setting (7.15).
- **Nothing classless was left to delete.** No `case` arm, test or `if`
  outside `VC.pas` named IN7QPNE. LOGSTUFF's `PAQSOPointMethod` arm stays: the
  Pennsylvania value's legacy arm, reached now only by an operator's
  `QSO POINT METHOD` (7.15, M10).

**TESTS.** `uTestContestIN7QPNE` (new): the class and its components; routing
for each party, case and blanks ignored, and the non-counties; the shipped
files' keys (above); one points case per party, each equal to that party's
own class and to the number its rule gives; the entrant's party for a
no-party QSO and no party for an entrant outside; multipliers per party
(Indiana's DX rule, Delaware's bands, nothing for no party); the dupe traits
of all four against the session's, and Delaware's two divergent traits
pinned as findings; the parse (a party's county, Delaware's own refusal
proving the component parsed, the out-of-area refusal, an in-area entrant
working Florida, a shape refusal standing); Cabrillo and ADIF names and the
round trip; no score posting. Ratchets edited in the same change:
`Test_M7bBatch2ContestsAreSiblingsOnTheBase` (one classless contest left),
`Test_TheBaseStatesNothing`'s floor, `Test_EveryStatePartyNamesItsState`
(IN7QPNE beside 7QP), `Test_MovedRowValuesStillMatchTheArray`,
`Test_EveryOtherContestCountsEveryMultiplier`,
`Test_OperatingAidsAndScorePosting`.

**EXPECTED MATRIX EFFECT** (stated before any gate ran). Only `IN7QPNE.matrix`
moves, and in it only:

- `contest.class =` in all four variants;
- **scoring, the three variants outside the four areas** (`us`, `ve`, `dx`):
  every synthetic QSO's QTH is a state, a province, DX or nothing, so every
  QSO is in no party -- `pts=0` for all seventeen, and the `mult.dom` flag
  `TRUE` -> `FALSE` on the eight QSOs that had it;
- **scoring, `us-host`** (MY STATE `Azaph`, a 7QP entrant): every QSO is
  judged by 7QP -- CW 2 -> 3, phone 1 -> 2, FM and digital 2 unchanged, 30 m
  scored like any band; multiplier flags unchanged;
- **totals**: outside, the points, every multiplier line, the total score and
  `CLAIMED-SCORE` go to 0; in `us-host`, points 27 -> 41 and the score
  216 -> 328 with the multipliers unchanged (if the reload rescores, which
  the frozen 27 = the scoring section's sum says it does).

Unchanged: identity's other lines, set-up, both exports, import and parse.
Golden corpus, factory check and round trip: unchanged (no corpus set is
IN7QPNE). `Lint-ContestNameTests` stays at 7 -- `uHamScore` names no
contest. `docs/CONTEST_RULES_OUTSIDE_FACTORY.md` is generated from
`git ls-files`: regenerate after the commit.

**Questions this raised -- NY4I's:** Q77-Q84 (§9).

### 8.2s M10 -- the adopted plan, and two decisions (2026-10-14)

M10 is too wide for one commit, so it runs as the staged plan in
[`CONTEST_FACTORY_M10_PLAN.md`](CONTEST_FACTORY_M10_PLAN.md) (S0-S9), one
gated commit per stage. That plan carries the measurements and the commands
behind them (`tools/contest-factory-m10/`).

**The decisive question, answered twice.** Does any class still reach the
legacy scoring case? **No.** `LOGSTUFF.CalculateQSOPoints` calls
`ActiveContest(Contest).ScoreQSO` and exits, and `ActiveContest` is nil only
for a contest with no registered class -- DUMMYCONTEST alone (186
registrations, 187 members). A second, different check found no class calling
back into it: the factory units name `LOGSTUFF.CalculateQSOPoints` in comments
only ("transcribed from its arm"). So deleting the case changes no registered
contest's score; DUMMYCONTEST gets a guard (the four `QSO POINTS ...`
overrides, then 0), not a class.

**DECIDED -- county-line import asks the class (plan S7).** The import path's
"clear the dupe flag on a county-line repeat" reads the `ContestsArray` row,
while the class owns the county-line rule; they disagree for six parties
(Michigan's row says yes and its class says no, and its header already calls
the row wrong; Arizona, BC, Virginia, Salmon Run and New York the other way).
Two owners of one rule is the shape this migration removes, and the class is
the owner the operator's live entry already obeys. A behaviour change on
import for those six, re-frozen with that reason.

**DECIDED -- the six KIND enums outlive M10: M11.** The multiplier and
exchange kinds (`ActiveExchange`, the four multiplier kinds, the initial
exchange) are SESSION facts -- 27 contests run with a session kind that is not
their trait (plan §1.4), so a reader cannot simply ask `ContestIdentity` -- and
about 80 surviving engine arms run on them. M10 turns the six globals into one
session object with one writer (plan S9). Moving the kinds' arms into the
classes, and then deleting the enums, is **M11**, a step of its own. The M10
row's promise to delete "the traits" therefore means the point-method trait
and the tables, not the kind enums.

**S2 DONE 2026-10-14 (Q4):** the seven shared-set settings are names in `uCFG.RETIRED_COMMANDS` -- gone from the model, Preferences, the peers' list and `ReplayContestStatements`; stored log rows are set aside on read and deleted at the next capture; the four `QSO POINTS ...` overrides stay (plan S2).

**S3 DONE 2026-10-14 (7.15, Q11):** the legacy `case ActiveQSOPointMethod of` is deleted; `logstuff.CalculateQSOPoints` hands a classed contest to `ScoreQSO`, and the classless DUMMYCONTEST gets the four `QSO POINTS ...` overrides, then 0 (plan S3).

**S4 DONE 2026-10-14:** the point method is deleted as a concept -- `QSOPointMethodType`, the row's `QP` column, `TContestBase.QSOPointMethod` with its 167 overrides, and `ActiveQSOPointMethod`; `MarksDupes` is the constant True in the base, equal to the old row answer for every contest because the only two `AlwaysOnePointPerQSO` rows are its two False overriders (plan S4).

**S5 DONE 2026-10-14:** every registered class states what it inherited -- the 82 non-neutral row values of 15 contests in their leaves, the 22 parties' in-state files, and the nine flag bits as ONE set, `GetFlags: TContestFlags` (the per-flag getters answer from it and are no longer virtual; the five CW/SSB pair families state it on their base); a party's prompt area is the class property `QSOPartyArea`, the HostState on the state-party base. The base still reads the tables, so nothing changed; S6 makes it neutral (plan S5).

**S6 DONE 2026-10-14:** the base reads no table -- its row getters answer DUMMYCONTEST's neutral row (`GetFlags` `[]`; `QSOPartyAreaName` and `VC.USQSOPartyStateName` deleted) -- and the outside readers ask the class: MainUnit's ERMAK menu, uHamScore's RTC upload, `postunit.ZoneSentForThisContest` (the CONTEST's zone kind, still not the session's -- F4, for S9), the matrix's contest list, and `uADIF.GetStateForContest`, which asks `QSOPartyArea` with the old two-letter test rather than `HostState` so British Columbia still writes no STATE (whether it should is an open question for NY4I, recorded in plan S6).

**S7 DONE 2026-10-14:** `ContestAllowsCountyLineOnImport` asks the state-party class (Michigan stops clearing the dupe flag on an imported county-line repeat; Arizona, BC, Virginia, Salmon Run and New York start); the rover export (`uADIF.ResolveRoverCall`) deliberately stays on the row because a rover is not a county line -- open question Q90 (plan S7).

**S8 DONE 2026-10-14:** the tables are deleted -- `ContestsArray`, `ContestsBooleanArray`, `QSOParties`, `TContestInfo` and the flag constants (`ContestTypeSA` stays); the rover split on ADIF export, the row's last reader, is `TContestStateQSOPartyBase.SplitsRoverCallOnExport`, True for exactly the fifteen parties the row named (proved equal for every contest before the deletion; Q90 still open); every test that read a table reads its literal, and the S0 pin is gone with what it compared against (plan S8).

**S9a DONE 2026-10-14:** the session object exists -- `uContestSession.ContestSession`, a `TContestSession` created once in the unit's initialization and never replaced, written only by FCONTEST's set-up path through `Write*` methods (main thread; read-only properties) -- and holds its first kind, `InitialExchange` (was `LOGWIND.ActiveInitialExchange`, 6 code-only occurrences, 3 readers); `logdupe.SetUpExchangeInformation`'s parameter that shadowed `ActiveExchange` is renamed `aExchangeKind` ahead of S9f (plan S9a).

**S9b DONE 2026-10-14:** the session holds `PrefixMult` (was `LOGDUPE.ActivePrefixMult`, 9 code-only occurrences -> 0, written by `WritePrefixMult` from FCONTEST's two set-up writes); YBDX pins why a reader may not ask the class -- trait `NoPrefixMults`, runs `IndonesianDistricts` (plan S9b).

**S9c DONE 2026-10-14:** the session holds `ZoneMult` (was `LOGWIND.ActiveZoneMult`, 19 -> 0), and **F4 is decided for the session**: `postunit.ZoneSentForThisContest` asks `ContestSession.ZoneMult`, as the ADIF CQZ/ITUZ block does -- no output changes, because the only zone kind a contest states over its trait (JIDX, JA station: `CQZones` over `NoZoneMults`) never reaches its ITUZones test; `logddx.pas` is found to be compiled by nothing (F14) (plan S9b/S9c).

**S9d DONE 2026-10-14:** the session holds `DXMult` (was `VC.ActiveDXMult`, 19 code-only occurrences outside the uncompiled `logddx.pas` -> 0; the declaration itself is deleted from `VC`). **F5 is kept, repointed and checked for order:** the CONTEST setting's effect derives `CTY.ctyCountryMode` from `ContestSession.DXMult` straight after `FoundContest` returns -- its only live caller, since `LOGMENU`'s is in a unit nothing links -- so it reads the kind set-up just resolved, as it read the global; no pre-existing ordering defect. ARRL 10 pins why a reader may not ask the class -- trait `ARRLDXCCWithNoUSACanadaKH6OrKL7`, runs `ARRLDXCCWithNoARRLSections` (plan S9d).

**S9e DONE 2026-10-14:** the session holds `DomesticMult` (was `LOGDOM.ActiveDomesticMult`, 38 -> 0 outside `logddx.pas`); **F8 closed** -- `logdom.DomQTHInit`, a runtime writer of the global with no caller anywhere in `tr4w/`, is deleted with the D7 initialization block that once called it. `uContestFactory` and `uWSJTX` no longer link `LogDom`, which they used for that global alone. OK/OM DX pins the session -- trait `NoDomesticMults`, a W station runs `DomesticFile` (plan S9e).

**S9f DONE 2026-10-14 -- M10 COMPLETE:** the session holds `Exchange` (was `LOGWIND.ActiveExchange`, 54 code-only occurrences outside the uncompiled `logddx.pas` -> 0; its zero is `UnknownExchange`, as the global's was), so all six kind globals are gone; `tree.LooksLikeAGrid`'s per-row read is one call and a field load, still ahead of any string work; ARRL DX pins the session -- trait `RSTPowerExchange`, a DL station runs `RSTDomesticQTHExchange`. M11 inherits the six kind enums and their ~80 engine arms, every one now reading `ContestSession` (plan S9f and its "M10 COMPLETE" summary).

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
- **Q4** **RULED 2026-10-13 (NY4I): YES -- `QSO POINT METHOD`, `EXCHANGE RECEIVED`, the four multiplier commands and `INITIAL EXCHANGE` all retire at M10** (`RETIRED_COMMANDS`: accepted, logged once, no effect). NY4I: *"Since we will be able to enter contests faster, we can retire the user entering their own contests. That is a desired feature by the user community but we can revisit another way to do it."* So **user-defined contests are a FUTURE FEATURE**, to be designed separately (not by bending an existing contest through these settings). Original question follows.
- **Q4** (new; the residue of C5). Do `EXCHANGE RECEIVED`, the four multiplier
  commands and `INITIAL EXCHANGE` retire with `QSO POINT METHOD` at the
  endpoint? **Recommended yes**, since they select from shared sets in the same
  way. ~~The Idaho config uses three of them~~ -- no longer: Idaho has its
  `ContestType` and class (2026-10-01, §7.2) and its `.cfg` sets none of them.
  **M8 depends on it:** the reach-1-3 multiplier KINDS stay in the sheet
  because these commands can state any of them for any contest (§8.2l).
- **Q5** (C6). Should the Salmon Run W7DX bonus be implemented now, or stay
  recorded as missing? The bonuses-as-data shape (§5) is recommended.
  **CLOSED: IMPLEMENTED at M6** (§8.2h) on the sponsor's current rules -- 500
  once per mode, CW and phone, a single-mode entry once.
- **Q6** **RULED 2026-10-13 (NY4I): YES -- POTA becomes a contest class.** "While it is not a contest per se, just like with GENERAL QSO, we treat it that way." **LANDED the same day (§8.2o): `TContestPOTA`.** Original question follows.
- **Q6** (C7). POTA as a contest class (recommended, §6), keeping the root name
  `TContestBase`, with "contest" meaning "an operating event with rules" as
  `ContestType` already does?
- **Q7** (C8). Apply the NRAU ruling to every two-mode pair (§1.5), including
  pairs where one mode is rarely run? **Still open after M3**, which applied
  it to NRAU-Baltic only and left the NA Sprint CW/RTTY as siblings, citing
  this question (§8.2d). Does the NA Sprint pair get a base?
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
  **DONE at M3 under the delegation (§8.2d)** -- the helper kept, the base
  deleted.
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
  scoring, so it is NY4I's decision. **RULED (7.10) and DONE at M5b
  (§8.2g):** the hundred counties of the sponsor's list; DC and the provinces
  moved into `nc.dom`.

- **Q15-Q18** (M3, sponsor rules): NRAU-Baltic's Cabrillo names, the Sprint
  SSB's names and multipliers, Locust's bands and multipliers, and the Jock
  White Field Day's points and own-branch multiplier. Stated in full at the
  end of §8.2d, where the classes that raised them are recorded.

- **Q24-Q26** (M5a, import): the FOC Marathon's N1MM tag now landing, Field
  Day's DX import (Q1's other half), and WAG's QTH for a record with no DOK.
  Stated in full at the end of §8.2f. **Q25 is answered and done at M5b**
  (§8.2g): DX is the QTH and never the domestic QTH, on import as on entry.

- **Q27-Q31** (M5b, parse): SAC's silent refusal of a Russian station, the
  UA4W Championship's class, the out-of-state rule for the sponsors not read,
  Winter Field Day's `MX`, and the Sweepstakes message's wording. Stated in
  full at the end of §8.2g. **Q14 is answered and done** (§8.2g, 7.10).

- **Q32-Q37** (M6, the final score). Stated in full here, because §8.2h
  points to them:
  - **Q32** Missouri's peak-hour tally (+1 per 80/40 m QSO logged 1400-1959
    UTC, to 250) is counted only in live entry and lost on every reopen and
    `/EXPORT`. WA7BNM's summary of the sponsor's rules has no such bonus (W0MA
    and K0GQ +100 each, and +100 for an electronic log). Is it a sponsor rule?
    If yes, it becomes a rule over the view (and the reopened score changes);
    if no, it is deleted. Either way `TalliesLiveQSO` goes.
  - **Q33** RSGB 1.8 MHz scores 7 for a contact that is a new multiplier on the
    sheet. May a class be handed the sheet's "is this a new multiplier"
    question (M8), so this contest can have a class and leave `TotalScore`?
    **M8 did not build it** (§8.2l): its seam is the contest DECLARING which
    QSOs count, not READING the sheet; this needs a read-only query over all
    bands and both modes, and a yes to a history-dependent stage-1 rule.
  - **Q34** Idaho's rover: a rover earns a dormant-county bonus per county it
    activates, but no QSO records the county it was SENT FROM. Add a per-QSO
    "my county" field (log schema, entry, ADIF `MY_CNTY`), or leave rovers
    scored as fixed stations in their MY STATE county?
  - **Q35** Idaho's threshold: the rovers page says "makes 10 valid QSO's",
    the rules page "MORE THAN 10 contacts". Ten is implemented, from 7.5. And
    the rovers page says "Only counties listed in RED are eligible" while its
    table lists BLUE 500-point counties beside red 1000-point ones; all are
    paid. Which reading is the sponsor's?
  - **Q36** Locust: `TContestLocustQP` scores 5000 per QSO with K6VVA or name
    LOCUST, multiplied like any QSO point. Is that the sponsor's rule, or a
    once-only bonus after multiplication (which would be `BonusPoints`)?
  - **Q37** `LOGGRID.ConvertGridToLatLon` reads a grid shorter than four
    characters past its end (an ALRS QSO with an empty QTH hands it `'LL'`), so
    such a QSO's points follow the heap -- identical QSOs scored 43, 42, 42.
    Bounding it is a behaviour change for every grid contest's malformed
    grids. Fix it (what should a malformed grid score?), and re-freeze ALRS
    with that reason?

- **Q38-Q39** (M7a, set-up):
  - **Q38** Winter Field Day's score is points times band-modes times the power
    factor -- it counts no DX multiplier -- yet its session counts
    `ARRLDXCCWithNoARRLSections` (now also its row and class, the value every
    session ran; §8.2i). Field Day was ruled to have no multipliers (Q1). Is
    the sponsor's rule that Winter Field Day has none either (`NoDXMults`, a
    behaviour change for the remaining-multiplier display only), or does it
    keep the DXCC count?
  - **Q39** Three set-ups write MY STATE, a STATION setting (`TMySettings` is
    not contest-scoped, so a later save of the station's settings can carry the
    contest's value into `settings/tr4w.json`): Canada Day/Winter and the Russian DX contests blank
    it for a station outside their country, the Russian cups replace it with
    the grid. That is today's behaviour, moved exactly; but a contest
    overwriting the operator's state can outlive the contest. Should the
    sent exchange carry the contest's value instead (a contest-scoped field),
    leaving MY STATE alone?

- **Q40-Q43** (M7b batch 1):
  - **Q40** The multi-state parties. 7QP and NEQP have their own classes on
    `TContestBase` (Â§8.2j), keeping today's behaviour: 7QP is a party to
    set-up by its row (in-state test, `seven`/`seven_cty`), NEQP chooses by MY
    STATE's first two characters, and neither is held to the single-state
    base's out-of-state refusal (7.10) or a county-line maximum. Should they
    (with IN7QPNE) share a multi-state party base, which state's county rule
    applies on a line between two states, and does 7QP's sponsor maximum of
    four counties get enforced?
  - **Q41** ARRL VHF: the September running is set up with the contest name
    `'VHF QSO JUNE'` (the June arm named both), and the January running has
    never been set up at all -- no 6 m start, HF bands left on. Intended?
  - **Q42** OZCHR: both contests' session names are literal question marks
    (`'????-??????? ...'`); the Cyrillic was lost before this tree. Restore it
    (from D7's source at `C:\TR4W`, or the sponsor), or name them in Latin?
  - **Q43** Q7 now has concrete members: JIDX CW/SSB (identical but for the
    names -- the NRAU-Baltic shape exactly), All Asian CW/SSB, Oceania CW/SSB,
    the four EU Sprints and the three ARRL VHF runnings are siblings (copies)
    until Q7 is answered. Which, if any, are one contest under one rule?

- **Q44-Q47** (M7b batch 2):
  - **Q44** Three contests state their bands inside the scoring arm, not as
    `UsesBand`. RTC scores 0 AND inhibits the multiplier off 40/20/15/10 m
    and off CW/phone; CQMM (off 80-10 m) and WRTC (off 80-10 m) score 0 but
    still EARN the multiplier. NY4I's off-band ruling (7.4) is 0 points and
    no multiplier. Should each state `UsesBand` (RTC also a mode rule), which
    changes CQMM's and WRTC's multipliers for an off-band QSO?
  - **Q45** EUDX and IRTS test "is the worked station in the EU" as
    `DomMultQTH[4] <> ''` -- a character against the empty string, never
    equal -- so every QSO scores as an EU contact (10, or 2 for our own
    country when we are in an EU region). The sponsor's table needs a real
    EU test. What should it read (the domestic file's region code?), and
    is the fix wanted now (a re-freeze of both contests)?
  - **Q46** Ten-Ten scores 2 for every QSO: its arm's `TenTenNum <> -1` is
    never false on a Word. The intent reads "2 with a Ten-Ten number, 1
    without" (`<> MAXWORD`). Fix it (a behaviour change for QSOs with no
    number)?
  - **Q47** Three preserved read-past shapes, harmless for real calls: MWC
    walks a ten-character copy of the call to the call's full length; the
    Region 1 Field Day reads MY COUNTRY's first character with no length
    check; the RCC runnings score 4 for a one-character call. Bound them when
    each contest is next touched (no scored QSO moves)?

- **Q48-Q51** (M8, multipliers and dupes):
  - **Q48** YB DX: `ParametersOkay` re-set an Indonesian entrant's prefix
    multiplier to the value it already had -- a no-op, also in D7, deleted
    (§8.2l). What was it meant to do: does an Indonesian entrant count a
    different multiplier (prefixes rather than districts?) by the sponsor's
    rules?
  - **Q49** BC QSO Party: "a DX station earns no multiplier" tests the
    lower-case `'dx'`, but the in-province file maps `dx=DX`
    (`target/dom/ve7.dom` line 2), so the multiplier is `DX` and the rule
    never fires; New York and Indiana test `DX`. Should BC's be `DX`? (A
    scoring change for in-province BC logs with DX contacts; moved exactly
    at M8.)
  - **Q50** "A Russian call's oblast" is written three ways that disagree:
    `InitialExchangeFromCall` (Russian DX, RU3AX -- the CTY.DAT country
    starts `UA`, standard call format), LOGEDIT's initial-exchange fallback
    (Russian DX, RDA, RU3AX -- `RussianID` of the country, raw call) and the
    need-multiplier hint (Russian DX, RF Championships -- `RussianID` of the
    CALL). They differ for an `R...` entity outside `UA`. Make it one helper
    each contest calls? The fallback stayed in LOGEDIT at M8: it is an
    exchange rule, not a multiplier one.
  - **Q51** An off-band QSO marks no dupe bit (M8), so the off-band band's
    dupe sheet and the Stations window's `+` no longer show it -- consistent
    with "not a dupe", but those are also "worked there" displays. Keep it so
    (recommended: one rule), or keep a worked-there mark that is not a dupe?

- **Q52-Q57** (M9a, the display and the reports, §8.2m):
  - **Q52** Twelve classes had a hand-written display name that is not the
    row's friendly name; M9a made every display name the friendly name, as
    asked. The old ones: ARRL International DX Contest - CW / - Phone, ARRL
    Sweepstakes - CW / - Phone, CQ WPX - CW / - SSB, CQ World Wide DX - CW /
    - SSB, North American Sprint - CW / - RTTY, ARRL International Digital
    Contest, General QSO. The friendly names are shorter ("ARRL Inter. DX
    Contest, CW", "General QSO/DX Logging"). Which should the New Contest
    drop-down show (M9b)? If the longer, should `FriendlyName` change with it
    -- it also feeds the summary sheet's `CONTEST:` line and the log
    database's friendly name, so that is an output change.
  - **Q53** Forty-seven contests' rows have no friendly name, so their display
    name is still their enum spelling (`ALRS-UA1DZ-CUP`, `RF-CUP-CW`, `UKEI`,
    `YOUTHCHAMPIONSHIPRF`, ...; the list is
    `uTestContestDisplay.ENUM_SPELLED_DISPLAY_NAMES`). Human names for the
    drop-down, please -- each one given leaves the ratchet list.
  - **Q54** HamScore's one-QSO Cabrillo line (`uCabrillo`) writes Winter
    Field Day's FM contacts as `FM`; the Cabrillo file writes `PH`. Should
    HamScore ask the contest's `CabrilloModeString` too? (A HamScore change.)
  - **Q55** WRTC's score-posting XML has never carried a multiplier: its rule
    posts HQ and country on the all-modes row, and the writer walks only the
    CW, digital and phone rows. Post them per mode, add the all-modes row, or
    leave it (WRTC posts no live score anyway -- its aids forbid it)?
  - **Q56** (DECIDED under the delegation; for confirmation) A contest's
    sent state stands for the whole session: a MY STATE statement after the
    CONTEST line, or a Preferences edit mid-contest, no longer reaches the
    sent exchange of Canada Day/Winter, the Russian DX contests or the Cup RF
    (§8.2m says why: a log's reopen re-applies the station's captured MY
    STATE). Was "a later MY STATE wins" relied on anywhere?
  - **Q57** `SetUpRSTMyZoneExchange` (CQ WW RTTY's zone-and-state exchange)
    writes MY ZONE as "zone state" while it builds the messages and then
    restores it -- a contest writing a station setting, briefly; and because
    `SetZone` records an operator statement, MY ZONE stays marked stated
    after the restore. Build the messages from a local instead (MY ZONE
    derived from MY CALL would then stay derived -- a behaviour change only
    for a later MY CALL change)?

- **Q58-Q61** (M9b, the UI itself, §8.2n):
  - **Q58** WRTC's row carries IARU's friendly name, "IARU HF World
    Championship", so its display name equals IARU-HF's and the drop-down
    tells them apart only by token ("... [IARU-HF]", "... [WRTC]"). A name of
    WRTC's own? It becomes its `FriendlyName` too -- the summary sheet's
    `CONTEST:` line and the log database's friendly name, an output change.
  - **Q59** `IsActive` is False for SA Sprint and Locust only. Any others?
  - **Q60** The off-time minimum: `MainUnit` uses 60 minutes for CQ WW and
    IARU HF, `PostUnit`'s operating time 60 for CQ WW only (by contest NAME).
    Which is right for IARU HF? Once ruled, one `MinimumOffTimeMinutes` on the
    class and both readers ask it.
  - **Q61** CATEGORY-ASSISTED, -BAND, -MODE and -OPERATOR have the same
    two-store shape CATEGORY-POWER had: the summary window starts from the
    setting, but writes MODE to its header-store copy and the other three
    nowhere, so headless /EXPORT reads a stale or absent copy (`uLogStore`'s
    entry declaration says so). One value each, as 7.6 did for power (no
    rescore -- no contest scores by them)?

- **Q62-Q64** (POTA's class, §8.2o):
  - **Q62** A POTA hunter who sends a Canadian province exports `DXCC 291`
    (the USA) beside `STATE ON`: the tail hard-coded 291 for anything
    `LooksLikeAState` accepts, and that list holds the provinces. Moved
    exactly. Write 1 (Canada) for a province, or leave DXCC to the CTY
    lookup of the call as every other contest does?
  - **Q63** The New Contest dialog's POTA box is captioned with the literal
    `'Activator'`, not a `TC_` string, so no catalogue can translate it.
    Moved as it stood. Give it a resourcestring?
  - **Q64** The New Contest drop-down now shows POTA as "Parks on the Air(r)
    Logging" -- its friendly name, by the M9a rule that a class's
    `DisplayName` is its human name -- where the classless identity showed
    "POTA". Keep it, or should POTA be the exception whose drop-down line is
    its short name?

- **Q69-Q71** (the UA4W Championship's and RSGB 1.8's classes, §8.2p):
  - **Q69** MY ZONE, when nobody states it, is derived in the CONTEST'S zone
    mode, so in an ITU-zone contest it is the ITU zone (K0AAA carries 7, not
    4, in the UA4W Championship). 7.12 calls it MY CQ ZONE, and IARU relies on
    the ITU reading. Should MY ZONE always be the CQ zone, with ITU-zone
    contests reading MY ITU ZONE? That changes IARU's set-up and messages for
    an unstated zone, so it would be its own step. Until then the UA4W class
    asks `TStationContext.MyCQZone`.
  - **Q70** The UA4W Championship's 18-19 bonus now uses a STATED zone first
    (your 7.12 ruling), where the legacy arm always used MY CALL's CQ zone.
    With no zone stated the two agree. A zone typed for this contest is taken
    as a CQ zone, as MY ZONE's command says. Confirm?
  - **Q71** RSGB 1.8 MHz is a 160 m contest, but its row and class credit every
    band (`UsesBand` is the base's), and its new-multiplier question looks
    across all bands and both modes, as the legacy arm did. Should the class
    state `UsesBand` = 160 m only (an off-band QSO would then score 0 and earn
    no multiplier, 7.4)? And the UA4W Championship's prompt is a literal that
    no catalogue translates and that differs from `TC_ENTERYOURRDAIDORGRID`
    ("for UA1A stations" against "for Russian stations"); which wording, and
    should it become a translatable string?

- **Q72-Q76** (the Delaware QSO Party's class, §8.2q):
  - **Q72** Bands. The class credits 160, 80, 40, 20, 15 and 10 m and every
    band from 6 m up, light included, from "all HF bands except WARC, plus
    6 m and up". 160 m is MF and light is not "m"; both are a reading of the
    summary, not of the sponsor's page. Confirm both (an off-band QSO scores 0
    and earns no multiplier, 7.4).
  - **Q73** "A DE mobile that changes county is a new station." TR4W's dupe
    sheet keys on the call, band and mode, and there is no dupe-key seam
    (8.2l), so a mobile's second county is a dupe unless the operator works
    it as a county line. Build a contest dupe-key seam (the QSO's received
    county joins the key for a state party), or leave it to the operator?
  - **Q74** The Cabrillo header must carry `ARRL-SECTION:` or `LOCATION:` --
    DE for a DE station, the state or section otherwise, DX for DX. The class
    makes the writer refuse a file with no LOCATION; the operator types it.
    Should the class supply it (DE when in state, else the sent state, else
    DX), as Winter Field Day writes its `ARRL-SECTION:` line?
  - **Q75** No WA7BNM calendar id or submission address is recorded for the
    Delaware QSO Party: the class states 0 and '', so its calendar menu item
    is disabled. What are they?
  - **Q76** For every single-state party, an IN-STATE entrant's ADIF export
    writes `STATE` as the HOST state for every QSO with a QTH
    (`uADIF.EmitADIFRecord`): a DE station working Pennsylvania exports
    `STATE:DE` beside `QTH:PA`. Should `STATE` be the host state only when
    the QTH is a host county (a contest seam), and the worked state otherwise?

- **Q77-Q84** (IN7QPNE, the composite, §8.2r):
  - **Q77** The score. The ruling needs no combined score and would like the
    score of the party just worked. No display seam carries more than one
    score, so the window, the summary and `CLAIMED-SCORE` show the base
    formula over the combined log -- a number that is no sponsor's score.
    Build a per-party score seam (the contest names its parties' scores
    from the totals and the view), or claim nothing in Cabrillo?
  - **Q78** An in-area entrant working another party's station is judged by
    the WORKED party only, per the ruling. Its own sponsor may count that
    QSO too (an Indiana station working Arizona has an Arizona multiplier in
    the Indiana QSO Party). The same log goes to every sponsor, so their
    scoring is unaffected; TR4W's points show only the worked party's.
    Confirm.
  - **Q79** Session values that differ by party, kept at IN7QPNE's row:
    multipliers once per contest (Delaware: per band), no VHF (7QP and
    Delaware: on), one `dx` domestic multiplier for DX (7QP, NEQP and
    Delaware in state: DXCC entities), no Cabrillo LOCATION required and
    `DG` for FT8 (Delaware: required, `RY`), and no power multiplier or
    +50 bonus. Which should the combined session adopt?
  - **Q80** Which multiplier a QTH counts as is the session's one domestic
    table: every county is its own multiplier, and an in-area entrant's
    states, provinces and `dx`. The parties' own files differ (7QP in state
    maps its counties to their state). A per-party multiplier key needs a
    seam (Q4/M10). Wanted?
  - **Q81** New England's county spellings: `in7qpne_cty.dom` spells them
    state-first (`MEAnd`) and has Connecticut's planning regions (`CTCap`);
    NEQP's own `neqso.dom` spells them county-first (`AndME`) with eight CT
    counties. Which is current for NEQP? IN7QPNE's routing reads the
    combined file's convention.
  - **Q82** County lines: Indiana and Delaware allow two, 7QP four. The
    county-line check is asked with a count and no county, so the composite
    cannot route it and allows any number (as before). Pass the counties'
    party to the check, or leave it?
  - **Q83** The HamScore uploader now asks the contest whether it may post,
    so WRTC stops posting to HamScore too (its rule already said no live
    score posting; only the post-scores window obeyed it). Confirm WRTC.
  - **Q84** Indiana's "DX is no multiplier" rule compares `DX` in capitals.
    Indiana's own `in.dom` says `DX = DX`; IN7QPNE's in-area file says
    `dx = dx`, so an Indiana entrant's DX QSO in IN7QPNE earns its one `dx`
    multiplier. Spell the combined file's line `DX`, or make the rule
    ignore case (BC's is spelled `dx`)?

- **Q19-Q23** (M4, export): Sweepstakes' empty precedence, a Field Day DX
  station's class in ADIF, the two scoring rules that read the logging clock
  (Croatian, UK/EI -- Q21, DECIDED and FIXED 2026-10-01), PACC's row exchange
  against its session's, and CUP RF
  DIGITAL's received QTH. Stated in full at the end of §8.2e.

**Answered by the ruling, and dropped:** C3 (`CreateOwned...`), C4 (the
exchange-field model), C5 (`EXCHANGE RECEIVED` as a strategy swap; its residue
is Q4), C10 (multiplier strategies last), old Q3 (the secondary readers all go
to the contest), old Q4 (point-table units), old Q6 (the overrides stay ahead of
the class).
