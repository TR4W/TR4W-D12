# Adding a contest to the TR4W contest factory

A working guide for the developer moving a contest out of the legacy `case`
statements and into its own class. Keep it current — **every time you add a
virtual or a seam, add it to the tables below.** The point is that the next
person can find out what the base already handles without reading the base.

This is the contest counterpart of
[`ADDING_A_RADIO.md`](ADDING_A_RADIO.md), and deliberately the same shape: the
radio factory is the model NY4I asked this one to follow.

---

## 1. The rules that matter

### A base class must NEVER ask which contest it is

```pascal
// NO -- this is the bug the whole design exists to prevent
if Contest = WINTERFIELDDAY then ...

// YES -- the contest overrides; the base states the general case
function TContestWinterFieldDay.GetCabrilloName: string;
```

Identical to the radio factory's rule with different nouns, and it came from the
same place: three defects in one afternoon there all had the shape
`if RadioModel in [FT857, FT897]`. Every `if contest = ...` inside shared code is
a contest whose rule is written somewhere it cannot be found from its own file.

### One class per contest, and one `RegisterContest` per unit

Even when two contests are identical today. **ARRL Field Day and Winter Field
Day score exactly the same and are still separate classes** — NY4I, 2026-09-02:

> *"I would diverge winter field day and arrl field day. They keep diverging with
> rule changes each year."*

That is an operational argument and it beats the tidiness one. A shared base
makes every future divergence a refactor at the exact moment somebody is making a
small change before a contest weekend. TR4QT reaches the same conclusion:
`ARRLFieldDayContest` and `WinterFieldDayContest` are separate there too, with no
base between them.

**So duplication between two contests is sometimes correct**, and where it is, say
so in the file — otherwise somebody will extract it.

### A family base is for what genuinely cannot differ

`TContestARRLDXBase` (CW + Phone), `TContestARRLSSBase`, `TContestCQWWBase`,
`TContestCQWPXBase`: two runnings of ONE contest, where a rule change reaches
both by definition. Compare that with the two Field Days, which are two contests
run by different organisations.

`TContestFixedPoints` is the other kind — a base for a shared MECHANISM
("a number per mode") rather than a shared contest.

### Properties for what a contest IS, methods for what it DOES

Declared once in `TContestBase` as `property X: T read GetX`, with a **virtual**
getter. A descendant overrides `GetX`, never re-declares the property, and puts
the override in a **`protected`** section — a Pascal class body with no
visibility section defaults to `public`, which would make both `X.CabrilloName`
and `X.GetCabrilloName` callable.

`CalculateQSOPoints`, `ValidateClass`, `ValidateDXQTH` and the exchange
formatters take arguments and do work, so they stay methods.

---

## 2. How to add a contest

### Step 1 — read the contest's row in `ContestsArray` (`VC.pas`)

Everything TR4W currently knows about a contest is one row. ARRL Field Day's:

```pascal
Email: 'fieldday@arrl.org';  DF: 'arrlsect';  WA7BNM: 57;  QRZRUID: 0;
Pxm: NoPrefixMults;  ZnM: NoZoneMults;  AIE: NoInitialExchange;
{DM: NoDomesticMults;}  P: 0;  AE: ClassDomesticOrDXQTHExchange;
XM: ARRLDXCC;  QP: ARRLFieldDayQSOPointMethod;
ADIFName: 'ARRL-FIELD-DAY';  CABName: 'ARRL-FD';  FriendlyName: 'ARRL Field Day'
```

Two fields are the thread to pull:

| field | leads to |
|---|---|
| `QP:` | the arm of `case ActiveQSOPointMethod of` in `LOGSTUFF.CalculateQSOPoints` |
| `AE:` | the arm of `case ActiveExchange of` in `LOGSTUFF.ProcessExchange`, which names a `Process...Exchange` function — the exchange parsing |

`AE:` also selects the arm in `uCabrilloExchange.FormatCabrilloExchange` and in
`uADIFExchange.FormatADIFMyExchange` — the two export formats.

**Watch for a commented-out field.** Field Day's row has `{DM: ...}`, so its
domestic-multiplier value comes from whatever the record initialises to rather
than from anyone choosing it. Do **not** override such a field with a guess:
leave it reading the array and say why.

### Step 2 — decide whether the `QP` or `AE` is worth sharing

NY4I, 2026-09-02:

> *"You can make the determination if the QP function in question is common to
> enough contests for it to have its own uQSOPointsHelper... Same goes for the AE
> parameter... We could then resolve duplications later and see if consolidation
> in a class helper makes sense."*

**Lift first, consolidate after.** Ten of the 127 scoring arms are "a number per
mode" and cover more contests than the other 117 combined — that one earned
`TContestFixedPoints`. Most will not.

**And check the family actually fits before reusing it.** Field Day looked like a
`TContestFixedPoints` contest and is not: it counts FM *with* phone and leaves
digital at two, which "CW / Phone / everything else" cannot express. Either FM
would have scored 2 or digital 1, in a contest where nobody would check the FM
ones.

### Step 3 — write the unit

`src/contestFactory/uContest<Name>.pas`. Copy
[`uContestARRLFieldDay.pas`](../tr4w/src/contestFactory/uContestARRLFieldDay.pas)
— it is the worked example and covers every seam that exists today.

Override only what the contest actually owns; everything else inherits, and the
inherited answer reads `ContestsArray`, so a half-moved contest still behaves.

### Step 3b — state the contest's row in the class

NY4I, 2026-09-29, pointing at a contest's `ContestsArray` row: *"all the info in
[the row] should go into the contest class."*

So a class overrides the row accessors with LITERALS rather than letting them
default to `ContestsArray[FContest]`. Copy
[`uContestARRLFieldDay.pas`](../tr4w/src/contestFactory/uContestARRLFieldDay.pas)
or either of the two newest,
[`uContestArktikaSpring.pas`](../tr4w/src/contestFactory/uContestArktikaSpring.pas)
and [`uContestARRLDigi.pas`](../tr4w/src/contestFactory/uContestARRLDigi.pas):
each quotes its array row verbatim in a comment and then states every field.

**DO NOT delete the array row.** It still answers for every contest that has no
class, and for every accessor a class chooses not to override.

**TWO FIELDS ARE BLANK IN THE ARRAY AND BLANK IS NOT THE ANSWER.** `CABName` and
`FriendlyName` both mean *"use `ContestTypeSA[ct]`"* when empty — the array says
so itself — so a class transcribing them as `''` silently produces a blank
`CONTEST:` header line and a nameless contest in the selection UI. `ADIFName` is
the opposite: empty there is a real answer, because ADIF defines no id.

`uTestContestFactory.Test_MovedRowValuesStillMatchTheArray` is the guard. It
compares each class's literals against a plain `TContestBase` on the same
`ContestType` — the same accessor, so the two-step fallbacks are included — and
it caught exactly that `FriendlyName` mistake while Arktika Spring was written.
Add your contest to it, and delete the whole test when `ContestsArray` goes,
because at that point there is nothing left to compare against.

### Step 4 — register and list it

```pascal
initialization
   RegisterContest(ARRLFIELDDAY, TContestARRLFieldDay);
```

`RegisterContest` **raises** on a duplicate. Two units claiming one contest is a
programming error, and last-wins would hide it while first-wins would make the
behaviour depend on the `.lpr`'s uses order — which nobody reads as an ordering.

Then add the unit to `tr4w/tr4w.lpr`. That and the unit itself are the only
shared files a contest touches; the search path already covers
`src/contestFactory`.

### Step 5 — prove it

**Run `test-contest-factory.sh` before and after.** It must stay
`13 identical, 0 differing`.

---

## 3. What the base offers today

### Properties — what a contest is

| property | default |
|---|---|
| `DisplayName` | the enum's spelling |
| `CabrilloName` | `CABName`, or the enum's spelling when blank |
| `ADIFContestId` | `ADIFName` (blank is a real answer — some contests have none) |
| `FormerADIFContestIds` | **empty.** Every CONTEST_ID the contest was exported under before a rename — import accepts them, export never writes them (NY4I, 2026-09-29: *"Yes support old spellings"*). **When you rename an ADIF id, put the old one here in the same change.** That includes the enum spelling when the id used to be BLANK, because export fell back to `ContestTypeSA` then. Whitespace-only differences need no entry: `uContestRegistry.FindContestByADIFContestId` trims its input, tries every contest's current id first and former ids second, and never matches a blank. A contest with **no class** cannot carry one — which is why NZ Field Day's former export spelling `NZ FIELD DAY` does not resolve |
| `WA7BNMId`, `QRZRUId`, `SubmissionEmail`, `DomesticFileName`, `FriendlyName` | the array row |
| `PrefixMultiplierType`, `ZoneMultiplierType`, `DXMultiplierType`, `DomesticMultiplierType` | the array row |
| `InitialExchangeKind`, `ExchangeKind`, `QSOPointMethod` | the array row |
| `IsUSQSOParty` | the array row (`P <> 0`) |
| `HostState` | **`USQSOPartyStateName`** -- derived from the array's `P` index, which is the one place a QSO party's state is written down. `''` for every contest that has no host state, which is a real answer |

**`CountyLineCountiesMax` and `CountyLineAllowed` ARE NOT ON THE BASE** — they
moved to `TContestStateQSOPartyBase` on 2026-09-29 and are listed with it below.
NY4I: *"Arktika Spring is clearly not a qso party so I am not sure why that
would be in the conversation of two counties"*, and *"ARRL-DIGI is not of course
either."* A county line is a QSO-party concept, and on the root every contest in
the program could state one — three classes did, two of which have no counties.
| `FormatsExchange` | **False** — see below |
| `CabrilloQSOLineFormat` | `CabrilloQSOLineFormatDefault` — the layout of a whole `QSO:` line, which is NOT the exchange columns. Arktika Spring is the one contest that overrides it, with a narrower line that uses only four of the five arguments. **Deliberately not gated by `FormatsExchange`**: a contest can own the line without owning the columns, and Arktika Spring shares its exchange arm with contests that have no class. PostUnit uses the same constant when there is no class, so there is one copy of the layout |

**Everything defaults to `ContestsArray` on purpose.** A contest states what it
wants to own and inherits the rest, and a contest with no class is unaffected.
They are *accessors*, not a copied record: a copy would be a second definition
that drifts the moment the array is edited, which is exactly what
`RadioParametersArray` did before it was deleted.

#### The county-line worksheet -- numbers established from sponsor rules

**A number here has been read out of a sponsor's published rules by NY4I and is
not a guess.** It is recorded because the party it describes may have no class
yet: a number established today and implemented next month is otherwise lost in
a transcript. **A party absent from this table is not "unlimited by decision"** --
it is simply not looked up yet, and `CountyLineCountiesUnlimited` preserves
today's behaviour exactly while that stays true.

| party | max | the rule, as the sponsor writes it | class |
|---|---:|---|---|
| Florida QSO Party | **2** | *"Florida stations on a county line (maximum of two counties) may be claimed as a separate QSO and multiplier from each county."* | `uContestFloridaQP` |
| Michigan QSO Party | **0** | *"No station may claim simultaneous operation in more than one county, state, or province."* | `uContestMichiganQP` |
| Indiana QSO Party | **2** | two counties at once (NY4I, 2026-09-29) | `uContestIndianaQP` |
| 7QP | **4** | *"County-line contacts may be logged with one entry showing all counties or with separate entries for each county."* -- four being the intersection of four counties meeting at right angles | none yet; multi-state, see below |
| California QSO Party | **4** | a four-county junction is claimable -- NY4I, 2026-09-29: "4 since that is the intersection of 4 counties with common 90 degree angle borders" | `uContestCaliforniaQP` |
| North Carolina QSO Party | **2** | *"A maximum of two counties may be worked simultaneously under this provision."* -- https://ncqsoparty.org/rules/ | `uContestNorthCarolinaQP` |
| New York QSO Party | **2** | NY4I 2026-09-29: *"NY allows up to 2 counties on a county line."* | `uContestNewYorkQP` |
| Idaho QSO Party | **2** | NY4I 2026-10-01: *"ID QP allows up to 2 counties on a county line."* Scoring per NY4I the same day: 1 point phone, 2 points CW or digital | `uContestIdahoQP` -- a new `ContestType`, `IDAHOQSOPARTY` (2026-10-01). The sponsor agrees: *"Idaho stations on a county line may be claimed as a QSO and a multiplier from each county (2 QSO's and 2 multipliers)."* -- https://www.idahoqsoparty.org/rules.htm. Until then it was a `.cfg` borrowing `CONTEST = NEQP` |
| Washington State Salmon Run | **2** | *"In the case of 3-county or more intersections, and in accordance with the MARAC rules, only one county line consisting of two counties may be run at a time."* -- https://salmonrun.wwdxc.org/rules/ | `uContestWashingtonSalmonRun` |

**THE ARRAY'S FLAG DISAGREES WITH THE RULES FOR HALF OF THESE.** Michigan's row
says `CountyLineAllowed: True` and the sponsor forbids the practice outright.
7QP, New York and the Salmon Run are the opposite case: their rows carry **no**
`CountyLineAllowed` field, so it reads `False`, and all three allow a county
line. Florida, Indiana, California and North Carolina say `True` and agree.
~~"Every other number above confirms what the array already says"~~ stood here
and was already wrong about 7QP when it was written. That is the argument for
doing the lookup rather than trusting the flag.

**AND `IN7QPNE` CARRIES NO `CountyLineAllowed` FIELD AT ALL** (`VC.pas:4033`),
so it reads as `False` -- while two of the four events it combines allow a
county line (Indiana two, 7QP four). A combined entry that forbids what its
components permit is a defect, not a policy; it is left alone here because the
multi-state parties are unresolved (see `uContestStateQSOPartyBase`'s header),
and fixing the flag without deciding whose county rule applies would only move
the wrongness.

### Methods — what a contest does

| method | base behaviour |
|---|---|
| `CalculateQSOPoints` | scores 0 (`NoQSOPointMethod` is a real value) |
| `ValidateClass` | accepts anything |
| `ValidateDXQTH` | accepts nothing |
| `ValidateQTHCount` | **always True, and that is behaviour-preserving by construction.** TR4W has never counted QTHs for any contest, so "no opinion" states what the program does rather than being a permissive placeholder. Takes a COUNT and never a list: the application tokenised the exchange and already has the number, so handing the contest the QTHs would be the first step toward handing it the log. **Virtual**, and `TContestStateQSOPartyBase` is its only overrider |
| `FormatCabrilloSentExchange` / `...Received...` / `FormatADIFSentExchange` | `''`, and only called when `FormatsExchange` is True |

**`FormatsExchange` is False by default and that matters.** A contest whose
*scoring* has been moved must not silently take over its *export* as well. Each
responsibility arrives when it is actually lifted.

### Protected helpers — mechanism, not rules

| helper | for |
|---|---|
| `ValidateCountAndLetterClass` | "count then one letter" — `2A`, `1O`. The contest supplies the legal letters and the message |
| `ValidateDXQTHAllowing` | `DX` and empty always pass; the contest supplies whatever else it allows |

The split is deliberate: **splitting digits from letters cannot differ between
contests; which letters are legal can.** Duplicating the parse into every class
would duplicate the part that cannot differ.

### Family and mechanism bases that exist today

| base | kind | holds |
|---|---|---|
| `TContestARRLDXBase`, `TContestARRLSSBase`, `TContestCQWWBase`, `TContestCQWPXBase` | family | two runnings of one contest |
| `TContestFixedPoints` | mechanism | "a number per mode". Its rule is also a plain function, `FixedModePoints`, so a contest that already has a family base can call it instead of inheriting it -- Object Pascal has one base class to spend |
| `TContestStateQSOPartyBase` | mechanism | the single-state QSO parties. `IsUSQSOParty` is stated rather than read from the `P` index; `GetHostState` is **abstract**, so a state party that forgets its state cannot be instantiated; and **the whole county-line rule lives here** — `CountyLineCountiesMax` (virtual, defaulting to `CountyLineCountiesUnlimited` **unconditionally**, never read from the array's boolean), `CountyLineAllowed` (derived, **not** virtual, so it cannot contradict the count), the `CountyLineCountiesUnlimited` constant, and the `ValidateQTHCount` override that enforces the maximum. Deliberately NOT here: NAQP (a QSO party by name only), and 7QP / NEQP / IN7QPNE (multi-state, unresolved). Its members are whatever descends from it -- `grep -l TContestStateQSOPartyBase tr4w/src/contestFactory/*.pas` -- and only the ones whose sponsor rule has been read state a county-line maximum, each quoting it |

**THE DEFECT THAT MOVED IT, because the shape will look tempting again.** While
the rule was on `TContestBase`, the inherited maximum read
`ContestsArray[c].CountyLineAllowed` — a boolean that most rows do not carry, so
it answered **0**, and 0 refuses a second QTH. The effect was that **acquiring a
class of any kind started rejecting a two-QTH exchange**, for contests with no
counties at all; Arktika Spring hit it the day it was moved, while the comment
at the `logstuff.pas` call site asserted the opposite. The array's boolean
carries no *limit*, so the only honest reading of it was never a number — which
is why the party base's default is unconditional and the array is not consulted.

### `TStationContext` — what scoring knows about us

`Station.MyCountry`, `.MyContinent`, `.MyZone`, `.MyZoneValid`, `.MyGrid`.

`MyGrid` arrived with ARRL-DIGI, whose points are a function of BOTH grids and
only one of them is on the QSO. That is the growth rule the record states: a
field arrives with the first contest that needs it.

**Pushed in by the factory, never read from globals.** An earlier version had the
base reach into `LOGWIND`, which put the display layer in the dependency graph of
every contest class *and* of anything that wanted to ask a contest a question —
`uCabrilloExchange` and `uADIFExchange` are dependency-light on purpose and have
unit tests. A contest class depends on `VC`, `SysUtils` and the string constants,
which means **a test can construct one and ask it to score a QSO without starting
TR4W.**

`MyZoneValid` exists so a contest can tell "zone 0" from "no zone set". The
legacy arms `Val(MyZone, ...)` per QSO and ignore the error code.

---

## 4. Which oracle sees what — read this before believing a green run

**The golden corpus is BLIND to scoring.** Measured, not assumed: change ARRL DX
from 3 points a QSO to 7, rebuild, and `export-d12-corpus.sh` still reports
`24 passed, 0 failed`. `/EXPORT` reads the QSO points **stored in the log** and
never recomputes them.

| change | caught by |
|---|---|
| scoring | **`test-contest-factory.sh` only** — rescores each log through the factory and diffs against that set's **frozen** `rescored.adi` / `rescored.cbr` -- the legacy output, captured once by `freeze-rescore-baseline.sh`. **`/NOFACTORY` was DELETED 2026-09-29**: it could only work while both paths existed, and the contests were all moving inside two weeks. The frozen bytes are OUR OWN former output, so this gate says the factory agrees with what TR4W did before the move -- not that either answer is correct |
| Cabrillo / ADIF exchange columns | **the golden corpus** — they are in the QSO lines, which `golden_diff.py` compares. Verified: `%-7s` → `%-8s` gives `FAIL arrl_fd cbr` |
| Cabrillo *header* | **nothing, EXCEPT `CLAIMED-SCORE:`** — `golden_diff.py` drops every other header line (`golden_diff.py:87-88` keeps that one). It is arithmetic over the log's STORED points, so a per-QSO scoring change still does not move it; a change to the total-score formula or a bonus does (corrected 2026-10-01) |
| exchange validation and parsing | **nothing** — no gate types an exchange |
| set-up, per-QSO scoring and export of **every** `ContestType`, classless included | **the contest matrix** — `bash tr4w/test/contest-matrix/run-contest-matrix.sh` (below) |

So `ValidateClass` and `ValidateDXQTH` changes are unverified by any automated
gate and belong in `BENCH_QUEUE.md`.

### The contest matrix -- the legacy fixture (milestone M0, built 2026-10-01)

**What it is.** One headless harness, `tr4w.exe <cfg> /MATRIX <out> <ordinal>`
(`src/uContestMatrix.pas`), driven by `tr4w/test/contest-matrix/`. For every
`ContestType` but `DUMMYCONTEST` -- the program lists them itself with
`/MATRIXLIST`, so nothing names a contest -- and for four station variants
(`us` K0AAA/KS, `us-host` for a contest with a host state, `ve` VE3AAA/ON,
`dx` DL1AAA), it boots the contest through the ordinary `.cfg` path and records:

| section | what | the milestone it gates |
|---|---|---|
| `identity` | requested vs selected `ContestType`, the class or none | M1 |
| `setup` | the seven `Active*`, the CTY modes, every engine global `FoundContest` writes, the domestic countries, the county-line answer, the CW memories, **every setting that differs from a fresh settings object** | M2, M7 |
| `scoring` | per synthetic QSO (17: CW, phone, FM, RTTY, FT8; 160 to 2 m incl. 30 m and 6 m; every continent; a sparse exchange), every field `/RESCORE` writes -- through `MainUnit.RecomputeQSOScoring`, the rescore's own body | M3, M8 |
| `export.adif` / `export.cabrillo` | those QSOs appended to a scratch log, then the **real** `ExportToADIF` and `CreateCabrilloFile`: every ADIF record, and the Cabrillo `CONTEST:` and `QSO:` lines | M1, M4 |

One process per contest and variant, because `FoundContest` is not idempotent --
see the unit header. About five minutes for the whole matrix.

**NOT captured yet: parsing and ADIF import** -- the synthetic QSOs arrive with
their exchange fields filled, the way a stored QSO does. That is M5's section,
marked as an extension point in `uContestMatrix`; add and freeze it **before**
the first parse arm moves.

**It asserts "same as before", never "correct".** The frozen records in
`tr4w/test/contest-matrix/frozen/` are this program's own output. Defects
present on the day of the freeze are pinned exactly as faithfully as correct
rules -- two of them are visible in the first freeze (`NEWENGLANDQSO`'s `dx`
variant crashes in set-up; `cty.zonemode` reads 255 for most contests).

**NEVER RE-FREEZE TO CLEAR A RED RUN.** `run-contest-matrix.sh` only compares
and never writes the frozen files. A record that moved is a finding: find out
why. Only a rule that changed **on purpose** -- a sponsor's change, or a defect
fixed deliberately -- justifies `freeze-contest-matrix.sh --reason "..."
IDENTIFIER...`, for the contests that change reaches and no others, with the
reason and what moved in the commit message. The script refuses to run without
a reason. A new `ContestType` is frozen the same way, by name.

It fails closed: no contests captured, a frozen record with no fresh one, a
fresh record never frozen, or any byte difference exits 1. A record carrying
`RUN FAILED` or `RAISED` passes only if it said so when frozen, and is listed on
every run.

Comparing a rescore against the D7 references was tried as a scoring gate and
rejected: 7 of the 13 logs move when rescored, before any factory work, because
our CTY.DAT is not the one D7 used. That is unexplored and recorded in
`test-contest-factory.sh`'s header.

---

## 5. Where the truth lives

| question | answer |
|---|---|
| what does this contest score | its class, else `LOGSTUFF.CalculateQSOPoints` |
| what is its exchange | its `AE` in `ContestsArray` → `LOGSTUFF.ProcessExchange` |
| its Cabrillo / ADIF name | its class, else `ContestsArray` |
| what D7 did | the D7 tree at `C:\TR4W` — read it, never mirror a fix back into it |
| how TR4QT decomposes a contest | `C:\projects\tr4qt\docs\CONTEST_DEVELOPMENT.md` and `src/contests/` |

### On TR4QT

**Useful for STRUCTURE, and not an authority on rules.** It is a
reimplementation, not a specification, and not independent corroboration. Its
`ARRLDXBase` says *"W/VE stations may ONLY work DX stations"* and means it
literally — the contact cannot be logged. TR4W logs it at zero points with
`InhibitMults`. NY4I, 2026-09-02:

> *"when TR4QT says we do not work them... we will not allow it to be logged. But
> they would be zero points as TR4W does today."*

TR4W's behaviour is what a move must preserve. Whether TR4W *should* refuse
instead is a decision, queued in `BENCH_QUEUE.md`.

---

## 6. Not built yet

Named here so nobody assumes they exist. TR4QT's `ContestBase` has all of them
and is the target shape:

- `getReceivedExchangeFields` / `getSentExchangeFields` — a structured
  description of the exchange
- `parseReceivedExchange` / `formatSentExchange`
- `getMultiplierTypes` / `getMultiplierValue`
- `calculateTotalScore`
- `getCabrilloHeaders`
- an order-agnostic parser. TR4W **does** parse out of order today — the
  "flips it around if given in section class order" block in
  `ProcessClassAndDomesticOrDXQTHExchange` — but per-arm, not as a shared
  facility like TR4QT's `SmartExchangeParser`.

**These are added when the responsibility is actually moved**, not in advance. A
virtual nobody calls is a decision nobody has made.

One thing from TR4QT's guide worth knowing before writing a validator: **`FL` is
a valid *state* but not a *section*** — Florida is NFL/WCF/SFL. Use a state test
for ARRL DX and NAQP, a section test for Sweepstakes and Field Day.
