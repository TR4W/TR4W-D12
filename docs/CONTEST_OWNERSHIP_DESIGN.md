# What a contest owns -- DESIGN (M0-M8 built; see §8.2)

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
| exchange parsing and validation | **the class, for every contest** (M5b, done 2026-10-02): `logstuff.ProcessExchange` asks it after the contest-blind gate; the base parses the session's shape through the engine's `ParseExchangeShape`, handed in as data. The UA4W Championship's rule stays named in LOGSTUFF (§8.2g) | `ParseReceivedExchange`, `MayBeACallsign`, `InitialExchangeFromCall` (**existing**), plus the validators |
| ADIF export: sent exchange and contest fields | **the class, for every contest** (M4, done 2026-10-01): PostUnit and uADIF ask `ContestIdentity`; the base's default is uADIFExchange's shared arm for the session's exchange. POTA still named in PostUnit's tail (§8.2e); ARRL 160 left it at M7b (§8.2j) | `FormatADIFSentExchange`, `EmitADIFContestFields`, `ADIFPowerTag`, `WritesADIFContestId` (**existing**) |
| ADIF import interpretation | **the class, for every contest** (M5a, 2026-10-01): `uADIF.ApplyADIFContestImport` asks `ContestIdentity` after the whole record is read; the base's default is the old classless `else`. POTA still keeps an arm in `MainUnit.ApplyClasslessADIFImport` (§8.2f); ARRL 160's moved to its class at M7b (§8.2j) | `ApplyADIFImport` (**existing**, §3.2) |
| Cabrillo: QSO columns, line layout, headers, mode string | columns and line layout: **the class, for every contest** (M4), the base's default being uCabrilloExchange's shared arm; headers and mode string: `postunit` | `FormatCabrillo...Exchange`, `CabrilloQSOLineFormat` (existing); `CabrilloHeaders`, `CabrilloModeString` (M9) |
| session setup: memories, settings defaults, domestic file and countries, band/mode | **the class, for every contest that has one** (M7a, done 2026-10-02): `FoundContest` asks `DescribeSession` and `FCONTEST.ApplySessionDefaults` writes it; LogCfg's CQ-exchange default is `CQExchangeDefault`. M7b gave the classless contests classes (batch 1, thirty-nine, §8.2j; batch 2, forty, §8.2k); `FoundContest`'s `case` keeps only the arms of POTA and the UA4W Championship, classless on purpose | `DescribeSession`, `CQExchangeDefault` (**existing**, §4, §8.2i) |
| total score and bonuses | **the class, for every contest** (M6, done 2026-10-02): `logedit.TotalScore` gathers the totals and asks `FinalScore`. RSGB 1.8 MHz is still named there, with its reason (§8.2h) | `FinalScore` = `CombineScore` + `BonusPoints`; `CombineWithMultipliers`, `BonusStations` (**existing**, §5) |
| multipliers and dupes | **the sheet keeps the state; the class declares the rules** (M8, done 2026-10-02, §8.2l): the kinds and by-band/by-mode traits, `UsesBand` (now asked by the dupe sheet and the need-multiplier hint too), `CountsAsMultiplier` (asked by `logdupe.SetMultFlags`), `MarksDupes`, and the hint's `DomesticMultiplierFromCall`. A multiplier KIND's arm stays in the sheet until the multiplier commands retire (Q4). RSGB 1.8 MHz still reads the sheet in its scoring (Q33) | `CountsAsMultiplier`, `DomesticMultiplierFromCall` (**existing**, M8); `MarksDupes`, `UsesBand` (**existing**); the multiplier KEY at M10 |
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
+-- TContestPOTA, TContestGeneralQSO      section 6 (POTA not built)
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
- **The multi-state parties (7QP, NEQP, IN7QPNE) stay open**, for the reason
  `uContestStateQSOPartyBase`'s header gives. Since M7b 7QP and NEQP each
  have a class on `TContestBase`, keeping exactly today's behaviour; whether
  they share a base is Q40 (§8.2j).

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
| `logstuff.ResolvePOTAParkFromADIF` (D5's fix, `3f9e3f28`) | POTA's `ApplyADIFImport` |
| `EmitContestSpecificTailForExport` arms | `EmitADIFContestFields` of each contest named. The no-op arm (D6) is deleted. **DONE at M4** but for POTA and ARRL 160 (§8.2e); ARRL 160's moved at M7b (§8.2j) |
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
| RSGB 1.8 MHz "times one" | **stays named in `TotalScore`, with its reason** (Q33): its per-QSO arm reads the multiplier sheet, which no class can be handed |
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

**NOT BUILT AT M4, on evidence (DECIDED, §8.2e).** M4 offered POTA a class for
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
~~none does today~~ -- **one does, measured at M6**: RSGB 1.8 MHz's arm pays 7
for a contact that is a new multiplier on the sheet (`mo.isdmmult` /
`mo.isdxmult`). It is the reason that contest has no class yet (Q33, §8.2h).

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
| **M7b** | **The classless contests.** Each gains a class -- a family member, or a copy of the nearest class (§1.4) -- and its `FoundContest` and LogCfg arms become its `DescribeSession` and `CQExchangeDefault`. **Batch 1 DONE 2026-10-02 (§8.2j)**: thirty-nine contests, no new family; ARRL 160 handed the domestic-country lookup as a station-context service, so its import and export arms left MainUnit and PostUnit; the All Asian's former ADIF id `AL-ASIAN-DX-PHONE` went in with `ALLASIANSSB`'s class. **Batch 2 DONE 2026-10-02 (§8.2k)**: the other forty, no new family; two session values and the caption memories joined `TSessionDefaults`; `PortableStation` lifted from Tree; the RoPoCo runnings told apart on import by MODE (`RunsInMode`, a decided change). Classless on purpose: POTA (Q6), UA4W (Q28), RSGB 1.8 (Q33), IN7QPNE (NY4I) | the matrix (only `contest.class =` moves; RoPoCo's phone import lines, by decision); the arm count ratchets to 0 |
| **M8** | **DONE 2026-10-02 (§8.2l).** **Multipliers and dupes**, as contest-declared rules over the shared sheet (§7.7 stage 2). `CountsAsMultiplier` and `DomesticMultiplierFromCall`; the five `SetMultFlags` rules and the four hint arms moved; YB DX's no-op deleted with ParametersOkay's copy of `SetPrefix`; the off-band dupe gap and need-multiplier hint fixed (§7.4). Multiplier-KIND arms stay in the sheet until Q4; RSGB 1.8 still classless (Q33) | corpus `CLAIMED-SCORE`; the matrix; `uTestContestMultipliers`, `uTestOffBandCredit` |
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
CALL (Q28).

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
registered contests are still named too.

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
score-posting multipliers in LOGSUBS2 (M9); YB DX in `MainUnit.ParametersOkay`'s
Indonesian-district prefix rule, RDA and YO DX in LOGEDIT's new-multiplier
check, and RDA beside the Russian DX contests in LOGEDIT's initial-exchange
fallback (M8 -- the Russian DX contests, registered since M5b, are named in
the same routines); Radio YOC in MainUnit's log loader (the previous received
number -- engine state, not a rule); **[M8, §8.2l: the YB DX test was a
no-op and is deleted; RDA's and YO DX's new-multiplier arms are their
classes' `DomesticMultiplierFromCall`; RDA's initial-exchange fallback is an
exchange rule and stays (Q50)]**; SST, CW Open and RTC in
`uExchangeBuilder`'s HamScore exchanges (M9, beside fourteen registered
contests); and the New Contest dialog's prompts (`uNewContest`, M9). The
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
| totals-window captions (OZCR_O, IARU, RUSSIANDX, RU3AX), summary sheet (Winter FD), score posting (WRTC) | `uTotal`, `postunit`, `logsubs2` | 1 | several | display | M9 |
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
  **M8 depends on it:** the reach-1-3 multiplier KINDS stay in the sheet
  because these commands can state any of them for any contest (§8.2l).
- **Q5** (C6). Should the Salmon Run W7DX bonus be implemented now, or stay
  recorded as missing? The bonuses-as-data shape (§5) is recommended.
  **CLOSED: IMPLEMENTED at M6** (§8.2h) on the sponsor's current rules -- 500
  once per mode, CW and phone, a single-mode entry once.
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
