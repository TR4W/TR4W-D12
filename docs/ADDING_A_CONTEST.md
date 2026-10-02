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
`TContestCQWPXBase`, `TContestNRAUBalticBase`: two runnings of ONE contest,
where a rule change reaches both by definition. Compare that with the two Field
Days, which are two contests run by different organisations.

**A shared MECHANISM is not a family, and gets a helper, not a base.**
`TContestFixedPoints` was such a base ("a number per mode", ~25 unrelated
sponsors) and **retired at M3 (2026-10-01)**: it spent the one base class
Object Pascal gives on arithmetic. The arithmetic survives as the
`FixedModePoints` function, which a class calls from its own
`CalculateQSOPoints`. `Test_EveryClassSitsOnTheBaseOrAFamily` holds the list of
bases closed -- a new base fails it until it is added there, which is the moment
to ask whether it is a family. A contest that merely RESEMBLES another starts as
a copy it owns (`CONTEST_OWNERSHIP_DESIGN.md` §1.4).

### Properties for what a contest IS, methods for what it DOES

Declared once in `TContestBase` as `property X: T read GetX`, with a **virtual**
getter. A descendant overrides `GetX`, never re-declares the property, and puts
the override in a **`protected`** section — a Pascal class body with no
visibility section defaults to `public`, which would make both `X.CabrilloName`
and `X.GetCabrilloName` callable.

`CalculateQSOPoints`, `ValidateClass`, `ValidateDXQTH` and the exchange
formatters take arguments and do work, so they stay methods.

### Scoring: override `CalculateQSOPoints`, call `ScoreQSO` (M3, 2026-10-01)

**`ScoreQSO(var aQso)` is the one public scoring entry point** -- non-virtual,
on `TContestBase`. It zeroes the points, scores an off-band QSO 0
(`UsesBand`), applies the operator's four `QSO POINTS ...` overrides
(`Station.PointOverrides`), and only then calls the contest's rule.

**A contest overrides `CalculateQSOPoints`, which is `protected`**, and
declares its override in a **`protected`** section too -- a `public`
redeclaration would let a caller score while skipping the band check and the
overrides. Never repeat the band rule or the overrides in it; state the bands
in `UsesBand`. Tests call `ScoreQSO`, never the rule directly.

---

## 2. How to add a contest

### Step 1 — read the contest's row in `ContestsArray` (`VC.pas`)

Everything TR4W currently knows about a contest is one row. ARRL Field Day's:

```pascal
Email: 'fieldday@arrl.org';  DF: 'arrlsect';  WA7BNM: 57;  QRZRUID: 0;
Pxm: NoPrefixMults;  ZnM: NoZoneMults;  AIE: NoInitialExchange;
{DM: NoDomesticMults;}  P: 0;  AE: ClassDomesticOrDXQTHExchange;
XM: NoDXMults;  QP: ARRLFieldDayQSOPointMethod;
ADIFName: 'ARRL-FIELD-DAY';  CABName: 'ARRL-FD';  FriendlyName: 'ARRL Field Day'
```

(`XM` said `ARRLDXCC` until 2026-10-01. NY4I ruled that Field Day has no
multipliers, and the row and the class were corrected together.)

Two fields are the thread to pull:

| field | leads to |
|---|---|
| `QP:` | the arm of `case ActiveQSOPointMethod of` in `LOGSTUFF.CalculateQSOPoints` |
| `AE:` | the arm of `case ActiveExchange of` in `LOGSTUFF.ProcessExchange`, which names a `Process...Exchange` function — the exchange parsing |

`AE:` is also what the contest's EXPORT looks like by default -- through the
SESSION's exchange, which is `AE:` unless FCONTEST's arm or the operator
changes it: `TContestBase` formats the Cabrillo columns and the ADIF
`STX_STRING` with the shared arm for that exchange
(`uCabrilloExchange.FormatCabrilloExchangeOfKind`,
`uADIFExchange.FormatADIFExchangeOfKind`). Those arms name no contest; a rule
of your contest's goes in your class (section 3, "How a contest formats its
export").

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
a helper, `FixedModePoints` (`uContestFixedPoints`). Most will not.

**A fixed-points contest, since M3 (2026-10-01)**, sits on `TContestBase` (or
its real family base) and says its numbers in its own rule:

```pascal
protected
   procedure CalculateQSOPoints(var aQso: ContestExchange); override;
...
procedure TContestKVP.CalculateQSOPoints(var aQso: ContestExchange);
begin
   aQso.QSOPoints := FixedModePoints(aQso.Mode, 2, 1, 1);   (* CW, phone, other *)
end;
```

The third number is digital AND FM. A two-branch legacy arm
(`if Mode = CW then X else Y`) gives them the phone value, so pass it twice.
`uContestKVP.pas` and `uContestCQIR.pas` are worked examples, and
`Test_FixedPointContestsTranscribeTheirArms` is where the numbers are pinned.

**And check the helper actually fits before calling it.** Field Day looked like
a fixed-points contest and is not: it counts FM *with* phone and leaves
digital at two, which "CW / Phone / everything else" cannot express. Either FM
would have scored 2 or digital 1, in a contest where nobody would check the FM
ones. Such a contest writes its own body; do not widen the helper.

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

**THREE FIELDS ARE BLANK IN THE ARRAY AND BLANK IS NOT THE ANSWER.** `CABName`,
`FriendlyName` and `ADIFName` all mean *"use `ContestTypeSA[ct]`"* when empty —
the array says so itself — so a class transcribing one as `''` silently produces
a blank `CONTEST:` header line, a nameless contest in the selection UI, or an
ADIF id that nothing exports. **`ADIFName` joined the other two at M1
(2026-10-01).** It used to be read as "blank means no ADIF id", while ADIF export
wrote the enum's spelling anyway — so import, which matches the class's
`ADIFContestId`, could never resolve TR4W's own export for 139 contests
(inventory D9). The id is now what export writes, by construction.

`uTestContestFactory.Test_MovedRowValuesStillMatchTheArray` is the guard. It
compares each class's literals against a plain `TContestBase` on the same
`ContestType` — the same accessor, so the two-step fallbacks are included — and
it caught exactly that `FriendlyName` mistake while Arktika Spring was written.
Add your contest to it, and delete the whole test when `ContestsArray` goes,
because at that point there is nothing left to compare against.

**EVERY CLASS STATES ITS DISPLAY NAME, CABRILLO NAME AND ADIF ID ITSELF** (NY4I's
ruling, enforced since M9a, 2026-10-02): override `GetDisplayName`,
`GetCabrilloName` and `GetADIFContestId` in YOUR class, not in a family base --
a base stating a name would give two contests one name. **The display name is
the HUMAN name**, the row's `FriendlyName` where it has one (the New Contest
drop-down will show it, M9b); `FriendlyName` is stated too.
`uTestContestDisplay.Test_EveryClassStatesItsIdentity` fails a class whose getter
is its parent's, and holds the list of contests whose display name is still
their enum spelling (no `FriendlyName` in the row -- design Q53) as a ratchet:
**a new contest may not join it.**

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
| `ADIFContestId` | `ADIFName`, or the enum's spelling when blank. **It is what ADIF export writes AND what import matches** (M1) — one getter, so a file TR4W exported always reads back to its contest. POTA and GENERALQSO still answer, though export writes no `CONTEST_ID` for them (`WritesADIFContestId` for General QSO; POTA by name in `uADIF`, pending a POTA class — design Q6) |
| `FormerADIFContestIds` | **empty.** Every CONTEST_ID the contest was exported under before a rename — import accepts them, export never writes them (NY4I, 2026-09-29: *"Yes support old spellings"*). **When you rename an ADIF id, put the old one here in the same change.** That includes the enum spelling when the id used to be BLANK, because export fell back to `ContestTypeSA` then. Whitespace-only differences need no entry: `uContestRegistry.FindContestByADIFContestId` trims its input, tries every contest's current id first and former ids second, and never matches a blank. A contest with **no class** cannot carry one — which is why NZ Field Day's former export spelling `NZ FIELD DAY` did not resolve until its class (`uContestJockWhiteFieldDay`, M3) arrived to carry it |
| `WA7BNMId`, `QRZRUId`, `SubmissionEmail`, `DomesticFileName`, `FriendlyName` | the array row |
| `PrefixMultiplierType`, `ZoneMultiplierType`, `DXMultiplierType`, `DomesticMultiplierType` | the array row |
| `InitialExchangeKind`, `ExchangeKind`, `QSOPointMethod` | the array row |
| `IsUSQSOParty` | the array row (`P <> 0`) |
| `ADIFPowerTag` | `RX_PWR` -- the ADIF tag the QSO's `Power` field goes to. FOC Marathon says `FOC_NUM`, because its parser puts the membership number there (M4) |
| `WritesADIFContestId` | True. General QSO says False -- an operating mode, not a contest (M4). POTA is still excluded by name in `uADIF` until it has a class (design Q6) |
| `QSOByBand`, `QSOByMode`, `MultByBand`, `MultByMode`, `VHFBandsEnabled`, `CountsDomesticCountries` | `ContestsBooleanArray`'s bits. **Set-up reads these** (M2) |
| `ZoneMode` | `CQZoneMode` when the array's CQ bit is set, else `ITUZoneMode` -- D7's rule, stated rather than cast (the cast gave 255, design §8.2a #2). **Set-up reads it** |
| `InStateDomesticFileName` | a QSO party's in-state file -- the `QSOParties` entry the row's `P` indexes; `''` otherwise. `DomesticFileName` is the party's county file, which every other station loads and which the in-state test reads |
| `MarksDupes` | the dupe policy: True unless the row's `QP` is `AlwaysOnePointPerQSO` ("ignores dupes"). **`logsubs2` reads it** through `ContestIdentity` when a QSO is logged (M3) -- an operator's `QSO POINT METHOD` no longer reaches it. Internet Sprint and SRR-JR state False |

**SET-UP ASKS THE CONTEST, SINCE M2 (2026-10-01).** `FCONTEST.FoundContest`'s
head writes the seven `Active*` globals, the flags above, the zone list and the
domestic file from `uContestRegistry.ContestIdentity(Contest)` -- your class --
through one resolver, `FCONTEST.ApplyContestTraits`, and an **operator's
statement beats your value** whatever the line order. So a trait override is
no longer inert: **changing one changes the contest's set-up**, and the
contest matrix will show it. What your class states in `DescribeSession`
(below) runs after the head and wins where it assigns, exactly as the arms it
replaced did; a classless contest's FoundContest arm still does the same.
Design §7.9, §8.2i.
| `HostState` | **`USQSOPartyStateName`** -- derived from the array's `P` index, which is the one place a QSO party's state is written down. `''` for every contest that has no host state, which is a real answer |

**`CountyLineCountiesMax` and `CountyLineAllowed` ARE NOT ON THE BASE** — they
moved to `TContestStateQSOPartyBase` on 2026-09-29 and are listed with it below.
NY4I: *"Arktika Spring is clearly not a qso party so I am not sure why that
would be in the conversation of two counties"*, and *"ARRL-DIGI is not of course
either."* A county line is a QSO-party concept, and on the root every contest in
the program could state one — three classes did, two of which have no counties.
| ~~`FormatsExchange`~~ | **DELETED at M4 (2026-10-01).** Every contest formats its own export -- see "How a contest formats its export" below |
| `CabrilloQSOLineFormat` | `CabrilloQSOLineFormatDefault` — the layout of a whole `QSO:` line, which is NOT the exchange columns. Arktika Spring is the one contest that overrides it, with a narrower line that uses only four of the five arguments; its columns are the base's. PostUnit asks every contest, so the constant exists once |

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
| 7QP | **4** | *"County-line contacts may be logged with one entry showing all counties or with separate entries for each county."* -- four being the intersection of four counties meeting at right angles | `uContestSevenQP` since M7b, on `TContestBase` -- multi-state, so NOT on the party base, and the maximum is NOT enforced (nothing enforced it before; design Q40) |
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
| `ScoreQSO` | **not virtual** -- the one public scoring entry point: zero, band check, the four overrides, then `CalculateQSOPoints` (section 1) |
| `CalculateQSOPoints` | **protected**. Scores 0 (`NoQSOPointMethod` is a real value). Asked only by `ScoreQSO`, so never about a QSO on a band the contest does not use, nor one an override already scored |
| `UsesBand` | **every band**, which is today's behaviour. A contest that states its bands overrides it, and a QSO on any other band is then logged, scores 0 (even under a `QSO POINTS ...` override) and earns no multiplier. Asked through `ContestCreditsBand` by `ScoreQSO` and `logdupe.SetMultFlags` -- and since M8 by the dupe sheet (`TCallsignsList.AddCallsign` marks no dupe bit for it, `CallsignIsDupe` calls none a dupe) and the need-multiplier hint (`LogEdit`, through `CreditedBands`). Idaho is the first overrider (`CONTEST_OWNERSHIP_DESIGN.md` §7.4) |
| `CountsAsMultiplier` | **True for every QSO and kind** -- whether a QSO earns a multiplier of a kind AT ALL, asked by `logdupe.SetMultFlags` (through `ContestCountsMultiplier`) before the sheet says whether it is new. The BC, New York and Indiana parties (a `DX` QTH), the PCC (its own country's prefix) and the Jock White Field Day (its own branch, and branch 00) override it (M8, below) |
| `DomesticMultiplierFromCall` | `''` -- the domestic multiplier a CALL implies before any exchange is typed, for the need-multiplier hint (`LogEdit.GetMultArray`). The Russian DX contest and the RF Championships (a Russian call's oblast), the Ural Cup (CTY.DAT's grid), RDA and YO DX (the remembered exchange) override it (M8, below) |
| `ParseReceivedExchange` | the engine's shared parse for the SESSION's exchange shape, `aSession.ParseShape(aSession.Exchange, ...)` -- see "How a contest parses and validates" below (M5b) |
| `MayBeACallsign` | every word may be a call (the PCC says `N/X` is not) |
| `InitialExchangeFromCall` | no answer (the Russian DX contests give a Russian station's oblast) |
| `FormatADIFReceivedExchange` | the ADIF `SRX_STRING`: the received RST in front of the typed exchange when the session's exchange carries an RST, else the typed exchange (the Field Days write a DX station's `1D DX`) |
| `ValidateClass` | accepts anything. Since M5b every contest is asked, a classless one through its identity -- `LOGSTUFF.ValidClass`'s own letter loop is deleted (inventory D1) |
| `ValidateDXQTH` | accepts nothing. Asked of every contest the same way; the fallback copy in LOGSTUFF is deleted (inventory D2) |
| `ValidateQTHCount` | **always True, and that is behaviour-preserving by construction.** TR4W has never counted QTHs for any contest, so "no opinion" states what the program does rather than being a permissive placeholder. Takes a COUNT and never a list: the application tokenised the exchange and already has the number, so handing the contest the QTHs would be the first step toward handing it the log. **Virtual**, and `TContestStateQSOPartyBase` is its only overrider |
| `FormatCabrilloSentExchange` / `FormatCabrilloReceivedExchange` | the shared arm for the session's exchange (`TCabrilloQSOContext.SessionExchange`) -- `uCabrilloExchange.FormatCabrilloExchangeOfKind` |
| `FormatADIFSentExchange` | the shared arm for the session's exchange -- `uADIFExchange.FormatADIFExchangeOfKind` |
| `EmitADIFContestFields` | nothing -- `uADIF.EmitADIFRecord` has already written the generic `QTH` |
| `FinalScore` | **not virtual** -- the one final score: `CombineScore` + `BonusPoints`. `LogEdit.TotalScore` is its only caller (M6, below) |
| `CombineScore` | **not virtual** -- the points for a session with no multiplier or the FISTS exchange, else `CombineWithMultipliers` |
| `CombineWithMultipliers` | **protected** -- the points (QTCs included) times the sum of every multiplier kind on the scored band |
| `BonusPoints` | the declared `BonusStations` over the view, else 0 |
| `BonusStations` / `CountsTowardBonus` / `CreditsBonusMode` | none / every contact / every mode |
| `TalliesLiveQSO` | false -- a preserved Missouri defect (design Q32); do not override it |
| `RunsInMode` | **every mode**. An IDENTITY question, asked only of an ADIF record whose `CONTEST_ID` two contests share: once the whole record is read, the first contest sharing the id that runs in the record's mode is its contest (`uContestRegistry.ContestOfADIFRecordMode`). The RSGB RoPoCo runnings are the only overriders (CW and phone; M7b batch 2, design §8.2k). It scores nothing |
| `DescribeSession` | states nothing -- see "How a contest describes its session" (M7a) |
| `CQExchangeDefault` / `RepeatSPExchangeDefault` | `''` -- LogCfg's default CQ and repeat S&P exchanges, used only where the operator has none (M7a; the repeat at M7b, for the EU Sprints) |

### How a contest formats its export (M4, 2026-10-01)

**EVERY CONTEST IS ASKED.** PostUnit's Cabrillo writer and ADIF tail, and
`uADIF.EmitADIFRecord`, call `uContestRegistry.ContestIdentity(c)` -- your
class, or a plain `TContestBase` for a contest with none -- and there is no
opt-in switch any more. A contest with no export rule of its own simply
inherits the base's answer, which is the shared arm for its session's
exchange: what an RST-and-serial or a name-and-QTH line LOOKS LIKE. Those arms
name no contest, and must not start to: **a rule that is your contest's goes
in your class.**

- **Your own columns**: override `FormatCabrilloSentExchange` and/or
  `FormatCabrilloReceivedExchange`, and `FormatADIFSentExchange` for the
  `STX_STRING`. Reproduce the widths exactly -- Cabrillo is a column format.
  `uContestFOCMarathon`, `uContestPCC`, `uContestARRLSSBase` are examples.
- **Only an input differs** (a placeholder for an absent QTH, the QSO's own
  QTH instead of the exporter's choice): copy the context, change the field,
  and call `inherited` -- the shared arm still lays out the line.
  `uContestUKEI`, `uContestCaliforniaQP`, `uContestWWDigi`.
- **Your ADIF fields** (a section, a society, a DOK, a grid): override
  `EmitADIFContestFields` and call `uADIF.EmitADIFField` -- the tag spelling is
  ADIF's, the meaning is yours. `uContestARRLFieldDay` (and its copy in
  `uContestWinterFieldDay`), `uContestWAG`, `uContestIARU`.
- **What the exporter decides stays the exporter's**: the formatted RSTs, the
  chosen his-QTH, the previous record's values, the session's exchange --
  `TCabrilloQSOContext`. Your class reads no global to format a line.

**And pin it**: golden strings in `uTestContestExport`, and a row in its
round trip (`Test_RoundTripThroughTodaysImport`) for anything that writes ADIF.
The golden corpus byte-diffs the 13 contests that have a set; the contest
matrix sees every contest's export.

### How a contest owns its ADIF import (M5a, 2026-10-01)

**IMPORT IS GENERIC FIRST, THEN YOURS.** `uADIF.ApplyADIFFieldsToExchange`
names no contest: it maps the standard tags (`CALL`, `BAND`, `MODE`, the RSTs,
`SRX`, `STX`, `QTH`, `CLASS`, `CQZ`/`ITUZ` ...) to the standard fields and
CAPTURES every tag whose meaning is a contest's into `TADIFRecordTemps` -- the
raw text, as ADIF carried it. Once the WHOLE record is read, the contest its
`CONTEST_ID` names interprets them: `TContestBase.ApplyADIFImport(aTemps,
aSession, var aExch)`. Because it runs after the last tag, **the order a
logger wrote its tags in cannot change the answer**; the `APP_N1MM_EXCHANGE1`
arm that read `exch.ceContest` as it went by is the bug that proved why
(`Test_N1MMTagOrderDoesNotMatter` pins both orders).

- **Do nothing** and you get the base's default -- the old classless `else`:
  a grid exchange takes `GRIDSQUARE`, a contest with domestic multipliers
  takes the `QTH` tag (else the letters leading `SRX_STRING`), anything else
  keeps `SRX_STRING` as the exchange.
- **Your own rule**: override `ApplyADIFImport` and write the fields your
  contest keeps. The operator and the received RST are already taken care of
  for every contest before you are asked (`ApplyADIFCommonImport`): `ExchString`
  is `SRX_STRING` with the received RST off the front, and `ceOperator` is
  filled. Call `inherited` only for the cases you do not handle.
  `uContestARRLSSBase`, `uContestARRLFieldDay`, `uContestCQWWBase`,
  `uContestIARU`, `uContestUkrainianDX` are examples; **an arm that named
  several contests is copied into each** (design 1.4).
- **A tag the generic importer does not capture yet** is a field of
  `TADIFRecordTemps`, an entry in `TADIF_Fields` and `ADIF_FIELD_NAMES` (their
  order MUST match), and a `temps.X := fieldValue` arm in `uADIF`. WAG's `DOK`
  and the RSGB IOTA's `IOTA` were added this way, so the two contests read back
  what they write.
- **The session arrives as data** (`TADIFImportSession`: the session's exchange
  and domestic-multiplier kind, whether it counts domestic multipliers, the
  operator) -- your class reads no global, so a unit test constructs it and
  asks. **THE SESSION IS THE OPEN CONTEST'S, NOT NECESSARILY YOURS**: an operator
  can import another contest's log, and the base's default has always read the
  session for whatever contest the record names.
- **Pin it**: `uTestContestImport` for the arm, and a row in
  `uTestContestExport.Test_RoundTripThroughTodaysImport` for anything you export
  that you must read back.

One contest with no class keeps an arm in `MainUnit.ApplyClasslessADIFImport`
for a stated reason (POTA: design Q6 is open). It is deleted when POTA gains a
class. ARRL 160's arm stood there too until M7b, when its class was handed the
domestic-country lookup its scoring needs as a station-context service
(`TStationContext.IsDomesticCountryCall`).

### How a contest parses and validates its received exchange (M5b, 2026-10-02)

**THE CUTTING IS GENERIC, THE MEANING IS YOURS.** `LOGSTUFF.ProcessExchange` --
what live entry's `ParametersOkay`, the log-line reader and the sender all call
-- runs the contest-blind tokenising gate (`ParseArray`) and then asks the
contest: `TContestBase.ParseReceivedExchange(aText, aSession, var aExch, out
aErrorMessage)`. True accepts and False refuses. A refusal that names a reason
puts it in `aErrorMessage`, and the engine shows it exactly as it shows an
improper county or a bad ARRL section (`ExchangeErrorMessage`, the main
window's notice line).

- **Do nothing** and you get the base: `aSession.ParseShape(aSession.Exchange,
  ...)` -- the engine's shared parser for the SESSION's exchange shape
  (`LOGSTUFF.ParseExchangeShape`, the old `case ActiveExchange of`, which names
  no contest).
- **Your own rule**: override and call `inherited` (or `aSession.ParseShape`
  with another shape) for what you do not decide yourself. The worked examples:
  RAC's `uContestCanadaDay` (a VE0 station's serial), `uContestPCC` and
  `uContestArktikaSpring` (choose between two shapes), `uContestLABRE` (a PY
  station's state), `uContestIARU` (fills the zone after the parse),
  `uContestUKEI` and `uContestSACCW` (refuse before it), `uContestARRLSSBase`
  (names a missing precedence after it), `uContestStateQSOPartyBase` (refuses an
  out-of-state station working another one -- NY4I's ruling, design 7.10).
- **Apply your rule under the shape it was written for** -- test
  `aSession.Exchange` -- and defer otherwise. Every rule that moved at M5b was
  a branch inside one shape's parser; guarding on the shape is what kept the
  move exact.
- **The session is DATA** (`TReceivedExchangeSession`): the session's exchange,
  the shape parser, and the engine services a rule needs -- `ZoneOfCall` (CTY),
  `IsDomesticQTH` (the loaded domestic table), `CallWindowHasCall` and
  `AbandonEntry` (live entry). Your class reads no global; a unit test hands it
  stubs (`uTestContestParse`). **A service is added when the first rule needs
  one**, like a `TStationContext` field.
- **Word cutting a class needs is in `uExchangeTokens`**, LIFTED from LOGSTUFF
  line for line (`SplitExchangeInThree`, `ProcessSweepstakesEntry`,
  `IsSingleNonNumericToken`) and called by both, so the engine and the class
  cut one way. Do not write a "tidier" splitter: it would hand your rule a
  different word than the parser saw.
- **Two more seams**: `MayBeACallsign` (a word of the exchange that looks like a
  call and is not one -- the PCC's `N/X`) and `InitialExchangeFromCall` (an
  initial exchange known from the call alone -- the Russian DX contests'
  oblast).
- **Pin it** in `uTestContestParse`, and know the matrix's `parse` section
  (section 4) sees what the engine did with the same typed text.

Typed entry itself -- that a refusal SHOWS its message, that a valid exchange
logs -- is seen by no gate; `docs/BENCH_QUEUE.md` carries it.

### How a contest owns its final score and bonuses (M6, 2026-10-02)

**ONE FUNCTION IS THE SCORE.** `LogEdit.TotalScore` gathers the totals the
program holds (`uScoreTotals.GatherScoreTotals`) and asks your contest
`FinalScore(totals, view)` -- and the score display, the summary sheet, the
Cabrillo `CLAIMED-SCORE`, the XML score report and both score-posting
clients all read `TotalScore`. Your class never sees the sheet, the globals
or the database:

```
FinalScore = CombineScore(aTotals) + BonusPoints(aTotals, aView)     (not virtual)
CombineScore: session with no multiplier, or the FISTS exchange -> the points  (not virtual)
              otherwise -> CombineWithMultipliers(aTotals)                    (yours)
```

- **Do nothing** and you get the general case: the points (QTCs included)
  times the sum of every multiplier kind, on the band a single-band entry
  scores or on all bands. No bonus.
- **Your sponsor combines them otherwise**: override the protected
  `CombineWithMultipliers`. `ContestPoints(aTotals)` and
  `SummedMultipliers(aTotals)` are the two pieces of the general case, for
  you to call. `uContestWinterFieldDay` (band-mode multiplier x power),
  `uContestDARCWAEDCCW` (weighted by band), `uContestUralCup`,
  `uContestCupRFCW` (points + 100 per multiplier).
- **A bonus station** -- "a contact with this call pays N, once or once per
  mode": declare it in `GetBonusStations` (a `TBonusStation` row), and the
  base pays it over the whole log. Say which contacts count
  (`CountsTowardBonus`; the base takes every one, dupes included) and which
  modes pay (`CreditsBonusMode`). `uContestMissouriQP`,
  `uContestWashingtonSalmonRun`.
- **Any other bonus** -- override `BonusPoints`, add `inherited`, and compute
  yours from the view. `uContestNorthCarolinaQP` (the sweep),
  `uContestIdahoQP` (the dormant county).
- **What you are handed**: `TScoreTotals` -- the stored QSO points, QTC
  points, the multiplier and QSO counts by band, mode and kind, the scored
  band, and the SESSION's facts (does it count multipliers, its exchange, its
  DX multiplier) -- and a `TLoggedQSOView`: every logged record that counts
  toward the totals (`QSOCountsTowardTotals`), read-only, in log order. The
  application keeps it in memory beside the totals (`uScoreTotals` -- reading
  the database per score was measured at ~130 us a row), so walking it is
  cheap; do not cache anything from it in your class.
- **A BONUS IS NEVER DECIDED AS A QSO IS LOGGED** (design 7.7): decided from
  the whole log at the end, it is the same however the log was reached --
  live, reloaded, rescored, edited or merged. `TalliesLiveQSO` is the one
  exception, and it is a defect kept for Missouri (design Q32): do not use it.
- **A field you need and nobody has** goes into `TScoreTotals` (filled in
  `GatherScoreTotals`) or `TStationContext`, with the first rule that needs
  it. The Salmon Run's single-mode rule brought `MyCategoryMode`.
- **Pin it** in `uTestContestTotals` with a hand-built `TScoreTotals` and a
  `TLoggedQSOList`, at the bonus's edges (nine QSOs and ten; four counties and
  five; one mode and two). The matrix's `totals` section sees the formula for
  every contest; a bonus its synthetic QSOs do not trigger needs the unit
  test and a `docs/BENCH_QUEUE.md` item.

### How a contest describes its session (M7a, 2026-10-02)

**SET-UP IS DATA YOUR CLASS HANDS OVER, NOT GLOBALS IT WRITES.**
`FCONTEST.FoundContest` asks `ContestIdentity(Contest).DescribeSession(
aStation, aSession)` once per set-up -- after the head has applied your traits
and the operator's statements and decided whether the station is in a QSO
party's host state -- and `FCONTEST.ApplySessionDefaults`, the only writer,
applies what you stated. Then the closing exchange set-up runs. Your class
reads `aStation` only: the identity object it is asked of carries no station.

- **Do nothing** and nothing is stated: the session is exactly what the head
  made of your traits. That is what most contests want.
- **State what your contest sets** on `aSession` (a `TSessionDefaults`):
  - the engine choices that vary by station -- `Exchange`, `DomesticMult`,
    `DXMult`, `PrefixMult`, `Band`, `Mode`, `DomesticMultByBand`,
    `AllowDupeQSOs`;
  - the session's settings -- `WARCEnabled`, `QSOByMode`, `MultByBand`,
    `LiteralDomesticQTH`, `SprintQSYRule`, `MinitourDuration`, ... each the
    setting of the same name;
  - the CW messages (`CQExchangeCW`, `SPExchangeCW`, `QSLCW`, ...) and the
    function-key memories (`SetCQMemory(CW, smkF1, ...)`,
    `SetExchangeMemory`), built from `aStation` -- `MyName`, `MyState`,
    `MyFDClass`, `MySection`, `MyPrec`, `MyCheck`, `MyCall`;
  - the domestic countries, in order (`AddDomesticCountry`, or a shared group
    -- `AddDomesticCountries(DomesticCountriesKVE)`; the groups are
    `uContestBase` constants that FCONTEST's own helpers read too);
  - the domestic file (`DomesticFile`, no extension), what your contest
    SENDS where MY STATE goes when it blanks or replaces it (`SentState` --
    the session's, never MY STATE itself, since M9a), the contest name;
  - since M7b: the initial exchange and the zone multiplier
    (`InitialExchange`, `ZoneMult`), the DX multiplier limit (`DXMultLimit`),
    the R150S list (`R150SMode`), and `SuppressZoneExchangeMessages` -- the
    JIDX contests' refusal of the zone-exchange messages FoundContest's
    closing set-up would otherwise write (it named them there);
  - since M7b batch 2: the initial exchange's cursor at the start
    (`InitialExchangeCursorAtStart` -- IRTS, RAEM), the DXCC multiplier by
    band (`DXCCMultByBand` -- CQMM), and an exchange memory's CAPTION
    (`SetExchangeCaptionMemory` -- the RTC's `NR` and `Cl+Ex`), which goes in
    the same ordered list as the memories.
- **A STATED VALUE IS STATED, EVEN WHEN IT IS FALSE OR EMPTY**, and an
  unstated one is left alone -- so state only what your contest sets, and
  never restate a trait "to be safe": a stated value overwrites a statement
  the operator made before the CONTEST line, as the arms always did.
- **A CHOICE THAT DEPENDS ON THE STATION IS STATED BOTH WAYS**, on
  `aStation.InHostState` (a state party's in-state station), the station's
  country or continent. A trait cannot vary per station; that was inventory
  D8. `uContestArizonaQP`, `uContestTexasQP`, `uContestARRLDXBase`.
- **A value nobody has stated yet** joins `TSessionValue` with the first
  contest that needs it, and FCONTEST's applier gains its line -- the same
  growth rule as `TStationContext`.

**THE DEFAULT CQ EXCHANGE IS A SIBLING, `CQExchangeDefault(aStation)`** -- and
the default REPEAT S&P exchange its twin, `RepeatSPExchangeDefault` (M7b) --
asked
by `LogCfg.tSetupExchangeNumbers` once the whole configuration is read (a
station line can follow CONTEST). It is a default in the strict sense -- LogCfg
uses it only where CQ EXCHANGE is still empty -- and the base offers `''`.

**Pin it** in `uTestContestSession` (hand it a station, read back what it
stated, both sides of any station-dependent choice). The matrix's `setup`
section sees the applied result for every contest and variant.

### How a contest declares its multipliers and dupe policy (M8, 2026-10-02)

**THE SHEET KEEPS THE STATE; YOUR CLASS DECLARES THE RULES** -- stage 2 of
`CONTEST_OWNERSHIP_DESIGN.md` §7.7. Whether a multiplier was worked before,
and whether a call was, is the shared sheet's question (`logdupe`,
`uMults`, `uCallsigns`); it never moves into a class and a class is never
handed the sheet. What your class says is which QSOs COUNT, as data and
virtuals the sheet asks:

| you declare | with | the sheet asks it |
|---|---|---|
| the multiplier kinds | the four traits (`DomesticMultiplierType`, `DXMultiplierType`, `ZoneMultiplierType`, `PrefixMultiplierType`), or per station in `DescribeSession` | set-up writes them to the session; the sheet keys every multiplier on them |
| per band / per mode | `MultByBand`, `MultByMode`, `QSOByBand`, `QSOByMode` (and `DomesticMultByBand`, `DXCCMultByBand` in `DescribeSession`) | the sheet's band and mode keys |
| the bands at all | `UsesBand` | points, multipliers, dupes and the hint all ask it (§7.4) |
| a QSO that earns no multiplier of a kind | `CountsAsMultiplier(aQso, aKind)` | `SetMultFlags`, before the sheet's "is it new" |
| whether a repeat is marked a dupe | `MarksDupes` | `logsubs2` as the QSO is logged |
| the domestic multiplier a call implies, for the hint | `DomesticMultiplierFromCall(aCall, aLookups)` | `LogEdit.GetMultArray` when no exchange is typed |

- **`CountsAsMultiplier` is about the QSO, never the log.** "A DX station
  is no multiplier", "our own country's prefixes do not count", "our own
  branch does not count" -- each a sponsor rule. `aKind` is `rmDomestic`,
  `rmDX`, `rmZone` or `rmPrefix`. Read the station from `Station` (MY
  COUNTRY, MY ZONE); the object `SetMultFlags` asks is `ActiveContest`, so
  its station is current. **Do not restate your band list here** --
  `SetMultFlags` asks `UsesBand` first, as `ScoreQSO` does.
- **`DomesticMultiplierFromCall` is a HINT.** What the QSO earns is decided
  from the typed exchange. What only the engine holds -- the exchange the log
  remembers for a call, CTY.DAT's grid -- arrives in `aLookups` (a
  `TMultiplierHintLookups`); a nil lookup answers `''`. Asked of
  `ContestIdentity`, so it reads no station.
- **There is no dupe-key virtual, deliberately** (DECIDED at M8). Every dupe
  rule outside the factory is either one of the declarations above or a
  shared rule keyed on a multiplier KIND many contests use (a rover in a grid
  contest is never a dupe -- `GridSquares`, six contests). A seam is added
  when a contest's own dupe rule moves.
- **A multiplier KIND's arm stays in the sheet** even when one contest uses
  it (`BlackSeaCountries`, `GCStation`, ...): the four multiplier commands
  let an operator state ANY kind for ANY contest, so the arm is the meaning
  of that statement, not a copy of the contest's rule. It moves into the
  class when those commands retire (design Q4, M10). Do not copy it into
  your class now -- that would be two definitions.

**Pin it** in `uTestContestMultipliers` (each override, and the base for
every other contest, which is a ratchet: a contest that gains a rule joins
its list in the same commit). The matrix's `scoring` line records every
multiplier flag for every contest and variant, and the corpus's
`CLAIMED-SCORE` the counts for its thirteen logs.

### How a contest tells the display and the reports (M9a, 2026-10-02)

**THE CONTEST ANSWERS WITH DATA; THE UI RENDERS IT.** A class never touches a
form, a canvas or a global. Each seam below stood as a test of a contest's
name in the unit that renders it, and every base answer is what that unit did
for a contest it did not name -- so state nothing, and your contest renders as
every other does. All are asked of `ContestIdentity` (no station) except
`CabrilloHeaderLinesBeforeTag`, which is handed one.

| you state | with | who asks |
|---|---|---|
| what the New Contest dialog asks for | `DescribeNewContestPrompts(aPrompts)` -- `AskField`, `AskFieldWithComment`, `OfferIAmIn`, `OfferIAmInCaption`, and `AskFieldWithCommentWhenInside` for the ticked box. **ORDER MATTERS**: rows are handed out in the order fields are asked, and the last comment wins. The base asks a US state party for its county or state; call `inherited` to keep that | `uNewContest` (M9b renders the display name in the drop-down) |
| the totals window's labels and mode shares | `GetTotalsDisplay` (`TTotalsDisplay`) -- start from `inherited` | `uTotal.UpdateTotals2` |
| the summary sheet's counting | `GetSummarySheet` (`TSummarySheetLayout`) | `PostUnit.WriteScoreInformationToSummarySheet` |
| whether the hour report carries a running score | `GetReportsRunningScore` | `PostUnit.PrintHourTotals` |
| the Cabrillo `CONTEST:` name, a required LOCATION, extra header lines, the mode column | `CabrilloContestName`, `GetRequiresCabrilloLocation`, `CabrilloHeaderLinesBeforeTag`, `CabrilloModeString` | PostUnit's Cabrillo writer |
| the canonical exchanges a scoreboard is sent | `CanonicalReceivedExchange`, `CanonicalSentExchange` -- build from `uCanonicalExchange`'s helpers (`RSTReceivedText`, `CollapseWhitespace`, `CanonicalFromCQTemplate`) | `uExchangeBuilder` -- HamScore, the UDP contact broadcast, the log's `exchange_sent` |
| the score-posting XML's multiplier labels | `ScorePostingMultiplierType` ('' posts none) | `LOGSUBS2`'s dynamic results |
| the operating aids it forbids | `GetPermittedOperatingAids` (`TOperatingAid`) | the menus, `OpenTR4WWindow`, `LOGEDIT`'s Super Check Partial |
| whether it has QTCs | `GetOffersQTCs` | the QTC menu |

**WHAT YOU SEND WHERE MY STATE GOES IS `TSessionDefaults.SentState`** (was
`MyState` until M9a). It is the SESSION's (`FCONTEST.SentMyState`) and never
written into MY STATE -- the operator's setting in `settings/tr4w.json` (design
7.11). Every reader of the sent exchange asks `SentMyState`; a new one must too.

**Pin it** in `uTestContestDisplay`: each override, and the base for every other
contest as a ratchet. The New Contest prompts are compared, for every contest,
against a table generated from the dialog's own arms. No oracle but the
corpus's Cabrillo header (Winter Field Day, General QSO) sees any of this, so a
change here needs a `BENCH_QUEUE.md` entry too.

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
| `TContestNRAUBalticBase` | family | the NRAU-Baltic contest, CW and SSB -- NY4I's ruling (2026-10-01), built at M3. The base holds every shared row field and the points; each mode class states only its names and calendar id. **The template for any other two-mode pair, once Q7 says that pair is a family** |
| ~~`TContestFixedPoints`~~ | ~~mechanism~~ | **retired at M3 (2026-10-01).** Its rule lives on as the helper `FixedModePoints`, called from a class's own `CalculateQSOPoints` (section 2, step 2) |
| `TContestStateQSOPartyBase` | mechanism | the single-state QSO parties. `IsUSQSOParty` is stated rather than read from the `P` index; `GetHostState` is **abstract**, so a state party that forgets its state cannot be instantiated; and **the whole county-line rule lives here** — `CountyLineCountiesMax` (virtual, defaulting to `CountyLineCountiesUnlimited` **unconditionally**, never read from the array's boolean), `CountyLineAllowed` (derived, **not** virtual, so it cannot contradict the count), the `CountyLineCountiesUnlimited` constant, and the `ValidateQTHCount` override that enforces the maximum. Deliberately NOT here: NAQP and the Locust QSO Party (QSO parties by name only -- Locust is `uContestLocustQP` on `TContestBase`), and 7QP / NEQP / IN7QPNE (multi-state, unresolved -- 7QP and NEQP have their own classes on `TContestBase` since M7b, design Q40). Its members are whatever descends from it -- `grep -l TContestStateQSOPartyBase tr4w/src/contestFactory/*.pas` -- and only the ones whose sponsor rule has been read state a county-line maximum, each quoting it |

**THE DEFECT THAT MOVED IT, because the shape will look tempting again.** While
the rule was on `TContestBase`, the inherited maximum read
`ContestsArray[c].CountyLineAllowed` — a boolean that most rows do not carry, so
it answered **0**, and 0 refuses a second QTH. The effect was that **acquiring a
class of any kind started rejecting a two-QTH exchange**, for contests with no
counties at all; Arktika Spring hit it the day it was moved, while the comment
at the `logstuff.pas` call site asserted the opposite. The array's boolean
carries no *limit*, so the only honest reading of it was never a number — which
is why the party base's default is unconditional and the array is not consulted.

**Siblings, not families, on evidence (M3, design §8.2d).** The NA Sprint CW
and RTTY have no base: their rows already differ (domestic file) and only CW
owns its export; whether they become a family is NY4I's Q7. The three Minitest
rows and the two QCWA rows are siblings for the same kind of reason. **The SSB
Sprint is not an NA Sprint at all** -- a different sponsor (NY4I, 2026-10-01)
-- and is its own class, `uContestSprintSSB`, on `TContestBase`.

**And the thirty-nine of M7b batch 1 are all on `TContestBase`** (design
§8.2j): CQ WPX RTTY and CQ WW RTTY score by other arms than their CW/SSB
families, so those bases would change them; 7QP and NEQP are MULTI-STATE
parties, which the single-state base's rules do not fit (7QP's row still makes
set-up treat it as a party -- `IsUSQSOParty`); the JIDX, All Asian and Oceania
pairs, the EU Sprints and the ARRL VHF runnings are copies until Q7 says
otherwise.

**So are the forty of M7b batch 2** (design §8.2k). UCG scores by the CQ WPX
arm and WWIH by the CQ WW RTTY arm, but neither is that sponsor's contest and
both have always exported through the shared arms -- so each COPIES the arm
rather than joining its owner. The King of Spain, REF and RSGB RoPoCo CW/SSB
pairs and the two Region 1 Field Day RCC runnings are siblings until Q7; IRTS
and EUDX share a scoring arm by their rows and nothing else, so they are
copies too. M7b ends with five contests classless on purpose -- POTA, the UA4W
Championship, RSGB 1.8 MHz, IN7QPNE and DUMMYCONTEST --
and `Test_M7bBatch2ContestsAreSiblingsOnTheBase` fails if a sixth appears.

### `TStationContext` — what scoring knows about us

`Station.MyCountry`, `.MyContinent`, `.MyZone`, `.MyZoneValid`, `.MyGrid`,
`.MyPower`, `.PointOverrides`, since M4 `.MyState` (IOTA, PCC -- since M9a
the state SENT in the session, `FCONTEST.SentMyState`, which is MY STATE unless
the contest's set-up stated another) and
`.ContestTitle` (Batavia FT8), since M5b `.MyCall` and `.InHostState`,
since M6 `.MyCategoryMode` (the Salmon Run's single-mode rule -- its zero
value is CW, which is what an operator who never chooses one exports), and
since M7b `.ContestName` (the European VHF contest's `'EURASIA'` test) and a
SERVICE, `.IsDomesticCountryCall` (ARRL 160's CTY lookup against the session's
domestic countries; nil means "not domestic", what the engine answers for an
empty list -- so guard on `Assigned`), and
since M7a `.MyName`, `.MyFDClass`, `.MySection`, `.MyPrec`, `.MyCheck` and
`.MyZoneText` (MY ZONE as text -- what a message SENDS; compare zones with
`.MyZone`). `uContestFactory.CurrentStation` fills it; set-up is handed the
same snapshot as a parameter of `DescribeSession`. ~~`.LogClockUTCHour`~~ is **gone** (2026-10-01,
design Q21) -- see the next paragraph.

**A TIME-OF-DAY RULE READS THE QSO'S RECORDED TIME, NEVER THE CLOCK.** NY4I,
2026-10-01: *"the event source is the wall clock recorded in the QSO."* Read
`aQso.tSysTime` (UTC, as stamped when the QSO was logged or read from
`TIME_ON` on import). A rule that asks the PC's clock scores by when the
button was pressed: a rescore, an edit, an import or a multi-op merge at
23:30 UTC doubled every Croatian QSO until it was fixed. `TStationContext`
carries no clock and must not grow one. The live path stamps the QSO before
it is scored (`MainUnit.ParametersOkay`), so live scoring sees the same hour.
Test such a rule on BOTH sides of its window in one run -- no clock can
satisfy both -- and pin the edges (`Test_CroatianDoublesByTheQSOsRecordedHour`,
`Test_UKEIDoublesByTheQSOsRecordedHour`).

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
| Cabrillo *header* | **nothing, EXCEPT `CLAIMED-SCORE:`** — `golden_diff.py` drops every other header line (`golden_diff.py:87-88` keeps that one). It is arithmetic over the log's STORED points, so a per-QSO scoring change still does not move it; a change to the total-score formula or a bonus does (corrected 2026-10-01). For every contest, **the contest matrix's `totals` section** (M6) |
| exchange validation and parsing | **the contest matrix's `parse` section** (M5b) -- a fixed list of typed exchanges through the real `ParametersOkay`, for every contest; and `uTestContestParse` for a class's own rule. **Nothing sees the window**: whether a refusal's message reaches the screen, and whether the caret lands after the bad token, are `BENCH_QUEUE.md`'s |
| set-up, per-QSO scoring and export of **every** `ContestType`, classless included | **the contest matrix** — `bash tr4w/test/contest-matrix/run-contest-matrix.sh` (below) |

So a parse change is seen as "same as before" by the matrix and as "right" by
nobody -- a refusal NY4I ruled (design 7.10) is a re-freeze with that reason,
and the typed-entry check belongs in `BENCH_QUEUE.md`.

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
| `setup` | the seven `Active*`, the CTY modes, every engine global `FoundContest` writes, the domestic countries, the county-line answer, the CW memories, **every setting that differs from a fresh settings object** | M2, M7a (185 identical, no re-freeze), M7b |
| `scoring` | per synthetic QSO (17: CW, phone, FM, RTTY, FT8; 160 to 2 m incl. 30 m and 6 m; every continent; a sparse exchange), every field `/RESCORE` writes -- through `MainUnit.RecomputeQSOScoring`, the rescore's own body | M3, M8 |
| `export.adif` / `export.cabrillo` | those QSOs appended to a scratch log, then the **real** `ExportToADIF` and `CreateCabrilloFile`: every ADIF record, and the Cabrillo `CONTEST:` and `QSO:` lines | M1, M4 |
| `import` (M5a) | the records the export just wrote, read back through the real import path (`MainUnit.ParseADIFRecord`, what `ImportFromADIF` and the WSJT-X reader call), **plus 38 synthetic foreign-logger records** carrying the contest-dependent tags (SRX_STRING with and without an RST, STATE, ARRL_SECT, VE_PROV, CNTY, GRIDSQUARE, SIG/SIG_INFO/POTA_REF, FOC_NUM, CQZ/ITUZ, DOK, IOTA, N1MM's tag BEFORE and AFTER `CONTEST_ID` ...). Each line lists every `ContestExchange` field the import moved off a cleared record | M5a |
| `totals` (M6) | the log the scoring section wrote, **reloaded** through `MainUnit.LoadinLog` (what `/EXPORT`'s start runs), then the QSO points, QTCs, QSO and multiplier counts by band and mode, `LogEdit.TotalScore` and the `CLAIMED-SCORE:` line of a Cabrillo file written after the reload. Appended LAST and frozen before the first total-score rule moved | M6 |
| `parse` (M5b) | **66 typed exchanges** through `MainUnit.ParametersOkay` -- the routine live entry's Enter calls -- with the call in the call window and the band and mode in force: every exchange SHAPE well-formed (serials, states, zones, names, powers, ages, grids, classes and sections, Sweepstakes' four fields, counties and a county line from the contest's own domestic file, prefectures, oblasts, departments, parks) and then the malformed and edge cases (missing and extra fields, the wrong order, a bad section or county, DX, a serial with letters, Sweepstakes without a precedence, an out-of-state station's own state). Each line: accepted or refused, the message and token a refusal shows, the counties a county line queued, and every field the parse set -- **not the points**, which are the scoring section's, and not the QSO's time and GUID, which come from the clock | M5b |

One process per contest and variant, because `FoundContest` is not idempotent --
see the unit header. About five minutes for the whole matrix.

**PARSING IS CAPTURED (M5b, 2026-10-02)**, appended LAST and frozen before the
first parse arm moved, with every earlier section proved byte-identical. Two
findings made it deterministic first: the CQ WW RTTY shape handed `ValidRST` an
uninitialised word (`FirstStringRST`, the same in D7), so `599 14` -- refused
either way -- left different fields behind on every run -- fixed; and
ALRS-UA1DZ's grid-distance scoring of a QTH
that is not a grid gave a different number every run -- which is why the parse
lines carry no points.

**The N1MM cases name a contest that is not the session's** (`ARRL-FIELD-DAY`,
`FOC MARATHON`, as literal ADIF text): a record is only misread when the contest
in force at the tag is not the contest the record names. The record that pinned
the old order bug is `n1mm.fd.before` in the step-1 freeze, and its fix is in
the re-freeze that followed (design 8.2f).

**It asserts "same as before", never "correct".** The frozen records in
`tr4w/test/contest-matrix/frozen/` are this program's own output. Defects
present on the day of the freeze are pinned exactly as faithfully as correct
rules -- two of them were visible in the first freeze (`NEWENGLANDQSO`'s `dx`
variant crashed in set-up; `cty.zonemode` read 255 for most contests). Both
were fixed on purpose at M2 and re-frozen with a reason, for only the contests
they reached (design §8.2c) -- the procedure below.

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

~~**RUN IT OUTSIDE 23:00-05:00 UTC, or expect CROATIAN to differ**~~ -- **NO
LONGER TRUE (fixed 2026-10-01, design Q21).** The Croatian and UK/EI night
rules read the QSO's recorded time, and the matrix stamps its QSOs 12:xx UTC,
so the run is independent of the time of day. Verified by running it at
23:45 UTC: CROATIAN differed in `contest.class =` only. A CROATIAN record whose
points all doubled now means a real regression, not the clock.

Comparing a rescore against the D7 references was tried as a scoring gate and
rejected: 7 of the 13 logs move when rescored, before any factory work, because
our CTY.DAT is not the one D7 used. That is unexplored and recorded in
`test-contest-factory.sh`'s header.

---

## 5. Where the truth lives

| question | answer |
|---|---|
| what does this contest score | its class's `ScoreQSO` (asked by `LOGSTUFF.CalculateQSOPoints`), else that routine's legacy case |
| what does its session start from | its traits (`FCONTEST.ApplyContestTraits`), the operator's statements, then its class's `DescribeSession` applied by `FCONTEST.ApplySessionDefaults` (M7a); a classless contest's `FoundContest` arm. LogCfg's default CQ exchange is `CQExchangeDefault` |
| what is its final score | its class's `FinalScore` (asked by `LOGEDIT.TotalScore`, which every score reader reads), else the base's general formula through its identity -- section 3, M6 |
| what is its exchange | its `AE` in `ContestsArray` (the SESSION's exchange, after its `DescribeSession` -- or a classless contest's `FoundContest` arm) → `LOGSTUFF.ProcessExchange` → its class's `ParseReceivedExchange` (M5b), whose base parses that shape with `LOGSTUFF.ParseExchangeShape` |
| its Cabrillo / ADIF name, friendly name, calendar ids | **`uContestRegistry.ContestIdentity(c)`** — its class, else a plain `TContestBase` reading the row. Never nil, owned by the registry, and every consumer outside the factory asks it (M1). Do not read `ContestsArray` or spell `ContestTypeSA` as a fallback for one of these: that is the copy M1 removed seven of |
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
- ~~`parseReceivedExchange`~~ -- **BUILT at M5b** as `ParseReceivedExchange`
  (section 3). `formatSentExchange` is M4's `FormatCabrillo...` /
  `FormatADIFSentExchange`
- `getMultiplierTypes` / `getMultiplierValue` -- **partly built at M8**:
  which QSOs count is `CountsAsMultiplier`, and the hint's call-to-multiplier
  `DomesticMultiplierFromCall` (section 3). The multiplier KEY itself -- the
  `case` arms of `GetDXQTH`, `SetPrefix` and the remaining-multiplier lists
  -- stays keyed on the KIND until the four multiplier commands retire (Q4)
- ~~`calculateTotalScore`~~ -- **BUILT at M6** as `FinalScore` = `CombineScore` +
  `BonusPoints` (section 3)
- `getCabrilloHeaders` -- **partly built at M9a**: the contest-specific lines
  (`CabrilloHeaderLinesBeforeTag`, `RequiresCabrilloLocation`,
  `CabrilloContestName`) and the mode column (`CabrilloModeString`, section 3).
  The general header (CATEGORY-*, the summary tags) is still PostUnit's and the
  Cabrillo summary dialog's, and CATEGORY-POWER's one value is M9b (design 7.6)
- an order-agnostic parser. TR4W **does** parse out of order today — the
  "flips it around if given in section class order" block in
  `ProcessClassAndDomesticOrDXQTHExchange` — but per-arm, not as a shared
  facility like TR4QT's `SmartExchangeParser`.

**These are added when the responsibility is actually moved**, not in advance. A
virtual nobody calls is a decision nobody has made.

One thing from TR4QT's guide worth knowing before writing a validator: **`FL` is
a valid *state* but not a *section*** — Florida is NFL/WCF/SFL. Use a state test
for ARRL DX and NAQP, a section test for Sweepstakes and Field Day.
