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
| `WA7BNMId`, `QRZRUId`, `SubmissionEmail`, `DomesticFileName`, `FriendlyName` | the array row |
| `PrefixMultiplierType`, `ZoneMultiplierType`, `DXMultiplierType`, `DomesticMultiplierType` | the array row |
| `InitialExchangeKind`, `ExchangeKind`, `QSOPointMethod` | the array row |
| `IsUSQSOParty`, `CountyLineAllowed` | the array row |
| `FormatsExchange` | **False** — see below |

**Everything defaults to `ContestsArray` on purpose.** A contest states what it
wants to own and inherits the rest, and a contest with no class is unaffected.
They are *accessors*, not a copied record: a copy would be a second definition
that drifts the moment the array is edited, which is exactly what
`RadioParametersArray` did before it was deleted.

### Methods — what a contest does

| method | base behaviour |
|---|---|
| `CalculateQSOPoints` | scores 0 (`NoQSOPointMethod` is a real value) |
| `ValidateClass` | accepts anything |
| `ValidateDXQTH` | accepts nothing |
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

### `TStationContext` — what scoring knows about us

`Station.MyCountry`, `.MyContinent`, `.MyZone`, `.MyZoneValid`.

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
| scoring | **`test-contest-factory.sh` only** — rescores each log through the factory and again through the legacy case via `/NOFACTORY`, and diffs |
| Cabrillo / ADIF exchange columns | **the golden corpus** — they are in the QSO lines, which `golden_diff.py` compares. Verified: `%-7s` → `%-8s` gives `FAIL arrl_fd cbr` |
| Cabrillo *header* | **nothing** — `golden_diff.py` drops header lines |
| exchange validation and parsing | **nothing** — no gate types an exchange |

So `ValidateClass` and `ValidateDXQTH` changes are unverified by any automated
gate and belong in `BENCH_QUEUE.md`.

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
