# What a contest owns, and what it picks -- DESIGN (nothing built)

**Status:** decision document, 2026-10-01, branch `contestFactory` at
`9acdc5bd`. Nothing here exists in code. Owner: `contest-factory`, with
`contest-scoring` (the engine side of every seam below), `file-formats`
(Cabrillo/ADIF), `log-database` (contest parameters land in SQLite) and
`settings-config` (operator overrides).

**Read with:** [`QSO_POINT_METHOD_DESIGN.md`](QSO_POINT_METHOD_DESIGN.md) (the
point-method axis; NY4I chose its option b; its Q1-Q7 are open and are
referenced here, never restated) and
[`CONTEST_RULES_OUTSIDE_FACTORY.md`](CONTEST_RULES_OUTSIDE_FACTORY.md) (the
inventory -- every count below that is not measured here cites it).

**NY4I's question:** *what does a contest OWN, and what does it PICK from a
shared set?*

---

## 0. The decision in twelve lines

1. **A contest OWNS** its identity, its sponsor's parameters, its session setup,
   its score formula and bonuses, its Cabrillo headers and its operator prompts.
   These are virtuals on the contest class and nowhere else.
2. **A contest PICKS** a strategy on each of four axes: **point method**,
   **exchange kind**, **multiplier kinds**, **initial exchange**. Each axis is a
   registry of stateless strategy objects keyed by the enum that already names
   it.
3. **One exchange kind owns parse, validation, Cabrillo columns, ADIF export AND
   ADIF import.** Import and export live in one class, so they cannot drift, and
   a round-trip unit test pins that per kind.
4. **A quirk is a variant, never a branch.** The contest builds and owns a
   variant of a shared strategy (a subclass or a constructor parameter). No
   strategy and no base ever asks which contest it serves.
5. **The operator's override swaps a strategy wholesale.** Resolution order on
   every axis: the operator's stated choice, then the contest's (variant or
   registered), then legacy while migrating. This is the point-method rule
   generalised.
6. **`FoundContest` stops being a definition.** Its head reads the class, not
   `ContestsArray`. Each arm becomes the contest's `DescribeSession`, which
   fills a defaults object that FCONTEST applies. **A class never writes a
   global.**
7. **`Active*` become derived values.** They are written by one resolver, never
   persisted, and never read back to decide anything.
8. **Total score is a seam with two halves:** `CombineScore` (the sponsor's
   formula) and `BonusPoints` (applied once, after combination). Both read a
   totals record that the application fills. The contest is never handed the
   log.
9. **Base classes are for what a contest IS.** That means a family (two runnings
   of one contest) or a trait only one kind of contest can express. Mechanism
   moves into strategies, so `TContestFixedPoints` goes as the point-method doc
   says.
10. **POTA is a class like any other.** `GENERALQSO` is the precedent.
11. **"A contest has moved" is checkable:** the generated inventory has zero rows
    naming it, its row values are pinned, and the ceilings are lowered in the
    same commit.
12. **The oracle for every axis is a frozen legacy matrix from ONE headless
    harness**, plus the existing corpus and round-trip scripts. Section 7 gives
    the order.

---

## 1. The ownership model

### 1.1 The test for which side a concern is on

From `uContestStateQSOPartyBase`'s header, which is already the working rule:
*"could a sponsor change this next year without it being a different kind of
contest?"*

- **Yes:** the contest owns it. Examples are the county-line maximum, the bonus
  stations, the CQ memory text and which class letters are legal.
- **No, it is how a kind of thing works:** it is a shared strategy. Examples are
  how an RST-plus-serial exchange parses, what an ARRL section's ADIF tag is,
  and how "a number per mode" scores.

### 1.2 What a contest owns outright

| concern | today | seam on the contest (new unless marked) |
|---|---|---|
| identity: enum, display/friendly/Cabrillo name, ADIF id and former ids, WA7BNM, QRZ.RU, e-mail | the class (accessors exist), but **five exporters read `ContestsArray` directly** (inventory §1.4 fact 4, D9) | existing properties. The fix is making the exporters ask |
| sponsor parameters: county-line max, legal classes, host state, QSO/mult by band or mode (`ContestsBooleanArray`), WARC allowed, dupe policy, off-time minimum, max contest dates | split across the class, the `ContestsBooleanArray` row, `FoundContest` arms and `postunit` | properties, one per fact, on the contest (or the family base that alone can express it) |
| session setup: CQ/exchange memories, settings defaults, domestic file and domestic countries, default band/mode | `FoundContest`'s 104 arms (inventory §5) | `DescribeSession` (§3) |
| score formula and bonuses | `logedit.TotalScore`, plus D10's three places | `CombineScore`, `BonusPoints` (§4) |
| Cabrillo headers, Cabrillo mode string, the QSO-line layout | `postunit` branches; the layout is already `CabrilloQSOLineFormat` | `CabrilloHeaders`, `CabrilloModeString`; the line layout is existing |
| summary-sheet and totals-window columns | `postunit`, `uTotal` (inventory "Score, summary and totals") | `SummaryColumns`, `TotalsDisplay` |
| what the new-contest dialog asks the operator | `uNewContest`, 92 rows (inventory §1.3) | `OperatorPrompts`. It is derived mostly from the exchange kind's sent fields (§2.2) |

### 1.3 What a contest picks

| axis | key | registry | the contest states | doc |
|---|---|---|---|---|
| point method | `QSOPointMethodType` | `uQSOPointMethodRegistry` | `QSOPointMethod` (exists) | **`QSO_POINT_METHOD_DESIGN.md` -- authoritative** |
| exchange kind | `ExchangeType` | `uExchangeKindRegistry` | `ExchangeKind` (exists) | §2 |
| multiplier kinds | `DomesticMultType`, `DXMultType`, `PrefixMultType`, `ZoneMultType` | one registry per type | the four properties (exist) | §7, step M7 -- **last** |
| initial exchange | `InitialExchangeType` | `uInitialExchangeRegistry` | `InitialExchangeKind` (exists) | §7, with M4 |

**The traits the classes already state are the picks.** Inventory §1.4 fact 3:
they are overridden 156 times and read by nobody outside the factory. This
design does not add a second way of naming a pick. It makes the existing
properties the ones that are read.

### 1.4 How a contest overrides a strategy for a quirk

There is one pattern, and it is the same on every axis. Ownership is decided
**by which method produced the object**, so it cannot be got wrong with a flag:

```pascal
TContestBase = class
protected
   (* A VARIANT OF A SHARED STRATEGY THAT THIS CONTEST BUILDS AND OWNS.

      nil -- the ordinary answer -- means "the registered one", which the
      registry owns and nobody else frees. Anything non-nil returned here is
      freed by this contest's destructor. The base never asks which contest
      it is: a contest with a quirk overrides, and the rest inherit nil. *)
   function CreateOwnedExchangeKind: TExchangeKind; virtual;
   function CreateOwnedPointMethod: TQSOPointMethod; virtual;
end;

(* FLORIDA NAMES A DX STATION BY ITS DXCC PREFIX in the Cabrillo received
   column, where every other contest on its exchange kind writes the DXQTH
   text (uContestStateQSOPartyBase's header). That is a variant of the shared
   kind with one parameter, not a branch inside it. *)
function TContestFloridaQP.CreateOwnedExchangeKind: TExchangeKind;
begin
   Result := TRSTDomesticOrDXQTHKind.Create(RSTDomesticOrDXQTHExchange,
                                            dxColumnIsPrefix);
end;
```

This **amends `QSO_POINT_METHOD_DESIGN.md` section 3 slightly.** Its
`CreatePointMethod` returns either the registry's instance (not owned) or a
variant (owned) from one virtual, and the caller cannot tell which. Splitting it
into `CreateOwned...` plus a registry fallback removes that ambiguity (**C3**).

---

## 2. The exchange strategy

### 2.1 What exists today, by direction

| direction | where | keyed by |
|---|---|---|
| parse and validate | `logstuff.ProcessExchange` `case ActiveExchange of`, dispatching to the `Process...Exchange` functions (`rg -c -i "^function Process\w*Exchange" tr4w/src/trdos/logstuff.pas`); class `ValidateClass` / `ValidateDXQTH` / `ValidateQTHCount` | exchange kind, plus contest tests inside arms |
| Cabrillo columns | `uCabrilloExchange.SetMyEx/SetHisEx` `case ActiveExchange of`; the class when `FormatsExchange` | kind, plus 11 shape-1 and 4 shape-3 rows in this unit alone (inventory, Cabrillo export) |
| ADIF sent exchange | `uADIFExchange.FormatADIFMyExchange` `case ActiveExchange of`; the class when `FormatsExchange` | kind, plus `Contest` tests (FOC, CQVHF, PACC/SPDX, PCC) |
| ADIF contest fields | `postunit.EmitContestSpecificTailForExport` `case rec.ceContest of` (ARRL_SECT, CHECK, PRECEDENCE, SIG, ...) | **contest** |
| ADIF import | `uADIF.ApplyADIFFieldsToExchange` (generic), then `MainUnit.ApplyContestSpecificADIFTail` `case exch.ceContest of` with an `else` keyed by `ActiveExchange` / `ActiveDomesticMult`, then `ProcessImportedSRX_String` (Field Day re-parse) | **contest**, then kind |
| sample exchanges for the simulator | `logddx` (inventory "Other") | contest |

**The asymmetry is the defect.** Export is mostly keyed by kind and import
mostly by contest. Nothing ties the two together except
`test-adif-roundtrip.sh`, which can only see the 13 corpus contests. The
round-trip defects recorded in `ApplyContestSpecificADIFTail`'s own comments
(the `59 8` QTH for IARU and CQ WW, where export prepends the RST and import did
not strip it; and an absent `ARRL_SECT` erasing the Winter Field Day section)
are both one field that the two directions disagreed about.

### 2.2 The shape: a field model, and a kind made of fields

**Two levels**, because the drift happens at the level of a FIELD, not a kind.
ARRL Sweepstakes and the two Field Days have different exchange kinds, yet they
share one import arm, because they share one field: the ARRL section and its
`ARRL_SECT` tag.

```pascal
(* ONE FIELD OF AN EXCHANGE, AND THE ONE PLACE ITS ADIF TAG IS NAMED.
   Reads and writes that tag in both directions, so a field cannot be exported
   under one tag and imported from another. *)
TExchangeField = class
public
   procedure WriteADIF(const aQso: ContestExchange;
                       aOut: TADIFFieldWriter); virtual; abstract;
   procedure ReadADIF(const aIn: TADIFRecordTemps;
                      var aQso: ContestExchange); virtual; abstract;
end;

(* ONE KIND OF EXCHANGE: an ordered list of received fields, an ordered list of
   sent fields, the parser, and the Cabrillo column layout. Stateless once
   constructed, like a point method. *)
TExchangeKind = class
public
   function Parse(const aText: string;
                  var aQso: ContestExchange;
                  const aStation: TStationContext;
                  out aError: string): boolean; virtual; abstract;

   function CabrilloSent(const aMy: TMyStationExchange;
                         const aQso: ContestExchange;
                         const aRSTSent: string): string; virtual; abstract;
   function CabrilloReceived(const aMy: TMyStationExchange;
                             const aQso: ContestExchange;
                             const aRSTReceived: string;
                             const aHisQTH: string): string; virtual; abstract;

   (* ADIF, BOTH DIRECTIONS. The defaults walk the field lists, so a kind that
      states its fields is round-trippable without writing either routine. A
      kind overrides only where the legacy bytes demand it. *)
   procedure WriteADIF(const aMy: TMyStationExchange;
                       const aQso: ContestExchange;
                       aOut: TADIFFieldWriter); virtual;
   procedure ReadADIF(const aIn: TADIFRecordTemps;
                      var aQso: ContestExchange); virtual;

   property ReceivedFields: TExchangeFieldList read FReceived;
   property SentFields: TExchangeFieldList read FSent;
end;
```

**Validation stays split.** The kind owns the *shape* (a count, then a letter).
The contest owns the *legal values* (which letters). That is
`ValidateCountAndLetterClass` today, and it is the right split. The kind calls
the contest's `ValidateClass` / `ValidateDXQTH` / `ValidateQTHCount` through a
narrow interface it is handed, never through the contest's identity.

### 2.3 Where today's pieces go

| today | becomes |
|---|---|
| `FormatsExchange` and the three `Format...Exchange` virtuals on 14 classes | **deleted.** Each body moves into the kind it implements. A contest-only quirk becomes that contest's `CreateOwnedExchangeKind` variant |
| `uCabrilloExchange` / `uADIFExchange` `case ActiveExchange of` arms | `CabrilloSent/Received` and `WriteADIF` of the kind named by the arm |
| the `Contest` tests inside those arms (FOC, JIDX, PACC/SPDX, CQVHF, PCC, UKEI, IOTA, DARC10M, ...) | a variant owned by that contest |
| the `'TRC'` / `'PGA'` string tests (no `ContestType`) | **C9**. They cannot be a variant of a contest that does not exist |
| `postunit.EmitContestSpecificTailForExport` arms | `WriteADIF` of the fields involved (ARRL_SECT, CHECK, PRECEDENCE, CQZ, SIG). The no-op arm (D6) is deleted |
| `ApplyContestSpecificADIFTail` arms | `ReadADIF` of the contest's kind or fields |
| its `else`: grid kinds, then `DoingDomesticMults` (the QTH tag, else the alpha prefix of SRX), then raw SRX | the **default** `ReadADIF` of the grid kinds and the domestic-QTH kinds respectively. The `else` is already a kind dispatch spelled as `if ActiveExchange = ...` |
| `ProcessImportedSRX_String` (Field Day) | the Field Day kinds' `ReadADIF` calling their own `Parse` on the SRX text. Import then re-parses with the same parser the operator's keystrokes use |
| `logddx` per-contest sample exchanges | a kind's `SampleExchange`, so the simulator exercises every registered parser |

**What replaces the `FormatsExchange` switch:** nothing per contest. The opt-in
moves from "this contest has been moved" to "this **kind** is registered".
Exporters call the effective kind (§2.4) unconditionally. A kind with no
registration is `nil`, and nil falls to the legacy `case` during migration
exactly as `ActiveContest = nil` does today.

**That move widens the blast radius, and that is deliberate.** Registering a
kind takes over its export for every contest of that kind, including the
classless ones that no corpus set covers. That is why each kind's registration
is gated on the frozen matrix (§7), not on the corpus alone.

**The import arm to kind mapping is a measurement still owed.** Several import
arms group contests that may not share a kind: `ARRL160, CQ160CW, CQ160SSB,
UBACW, UBASSB` is one arm. Before an arm is deleted, list the kind of each
contest it names. Where two contests of one kind import differently, one of them
is a variant. Do not assume the arm boundaries are kind boundaries.

### 2.4 The operator's override

`EXCHANGE RECEIVED` swaps the whole kind: parse, Cabrillo, ADIF and import. This
is the plain reading of "swap", the same one the point-method doc uses (**C5**).
The resolver order is the point-method doc's section 4: the operator's stated
kind, then the contest's variant, then the registered kind, then legacy. "Stated"
is subject to **C1**: see §3.3 for why every corpus log would read as
"operator chose".

### 2.5 The anti-drift guarantee, as a test

For each registered kind, a unit test builds QSOs from the kind's frozen matrix
rows and asserts **`ReadADIF(WriteADIF(q))` equals `q` on the kind's received
fields.** The kind is a leaf class, so this needs no booted program. It is the
property `test-adif-roundtrip.sh` checks for 13 logs, extended to every kind.

---

## 3. Setup -- `FoundContest` becomes reads of the class

### 3.1 Today

`FoundContest` (`fcontest.pas`, `function FoundContest`) does three things:

1. It assigns the seven `Active*` globals from `ContestsArray[Contest]`, and the
   by-band/by-mode flags from `ContestsBooleanArray`.
2. For a QSO party (`P <> 0`), it picks the in-state or out-of-state domestic
   file through `FoundMyStateInDomFile`.
3. It runs `case Contest of`: **104 arms naming 131 contests** (inventory §5),
   assigning `Active*`, `Settings.*`, CQ memories, domestic files and band.

The operator's `.cfg` rows are applied **after** that, by
`uSettingsEffects.SettingChanged` → `ApplyMultiplierToken`. So "operator beats
contest" is enforced today only by **ordering**.

### 3.2 Target

```pascal
   (* THE CONTEST IS THE SOURCE. A contest with no class answers through a plain
      TContestBase reading ContestsArray -- uContestRegistry already builds
      exactly that object privately (NewContestObject); expose it rather than
      writing a second one. *)
   def := ContestDefinition(Contest);
   def.SetStation(SessionStation);    (* includes InHostState -- see below *)

   (* DEFAULTS AS DATA. The class fills it and never touches a global, so a
      test can construct a contest and read its session without booting TR4W. *)
   defaults := TSessionDefaults.Create;
   try
      def.DescribeSession(defaults);
      ApplySessionDefaults(defaults);   (* FCONTEST: the only writer *)
   finally
      defaults.Free;
   end;

   (* AND THE PICKS, THROUGH ONE RESOLVER: operator, then contest, then legacy.
      The resolver writes the Active* globals for the code that still reads
      them; nothing persists them and nothing reads them back to decide. *)
   ResolveContestStrategies(def);
```

- **The in-state / out-of-state conditional moves onto the class** as
  `TStationContext.InHostState`. It is computed by `uContestFactory`, the one
  unit allowed to read globals, from `FoundMyStateInDomFile`. Then Arizona's
  `GetExchangeKind` can return `RSTDomesticQTHExchange` when it is false. This
  resolves the **six conditional disagreements in D8**: a single trait value
  could not express them, but a trait that reads the station can.
- **The one unconditional disagreement in D8 is a decision, not a refactor.**
  Field Day's class says `ARRLDXCC`, while its arm says `NoDXMults`, and the arm
  wins silently (**C2**).
- **The class becomes the source, and the array follows.** Until every
  `ContestType` has a class, `ContestsArray` stays as the base's fallback. It is
  `array[ContestType]` (`VC.pas`), so rows cannot be removed one contest at a
  time. The array goes when the base getters can become abstract, which is the
  radio factory's `Lint-NoRadioTables` endpoint (**C11**).

### 3.3 The operator's override -- "operator chose" versus "contest default"

The point-method doc's rule applies to all seven `Active*` settings. **Read the
setting's string, never the global.** The resolver derives the global.

**Measured for this document:** the sentinel problem behind point-method
Finding 2 is not limited to `QSO POINT METHOD`. Every corpus log stores all
seven, with the source `contest`:

```bash
python -c "import sqlite3,glob; [print(f, list(sqlite3.connect(f).execute(\"select command,value from config where command in ('QSO POINT METHOD','EXCHANGE RECEIVED','DX MULTIPLIER','DOMESTIC MULTIPLIER','ZONE MULTIPLIER','PREFIX MULTIPLIER','INITIAL EXCHANGE')\"))) for f in sorted(glob.glob('tr4w/test/corpus/*/log.db'))]"
```

All 13 answer `NONE` for six of them and `UNKNOWN` for `EXCHANGE RECEIVED`.
Under a "non-empty means the operator chose" rule, every corpus log would lose
its multipliers and its exchange, as well as its points. **Not established:**
which code writes these rows, and why applying them on open does not already
break the logs. The corpus is green, so some path does not apply them. Both
belong with point-method Q1, and **C1** asks for one answer covering all seven.

### 3.4 `DescribeSession` and operator-edited memories

Today the arm overwrites `Settings.Messages.CqExchangeCw` and the CQ memories on
every `FoundContest`, and the stored rows re-impose the operator's text
afterwards because of ordering. With `TSessionDefaults`, those are **defaults**.
The same "the operator stated it" rule decides whether they apply. Whether an
operator-edited memory should survive a contest re-selection is **C9b**.

---

## 4. End of contest -- the final-score seam

### 4.1 Where it hooks

There is **one** computation, `logedit.TotalScore`, and every consumer reads
it: the score display (`logwind`), the summary sheet (`postunit`), Cabrillo
`CLAIMED-SCORE` (`postunit`, `GetCabrilloTagText`), the XML score report
(`logsubs2`) and `uGetScores`. Measured with:

```bash
git ls-files 'tr4w/src/*.pas' | xargs rg -n -i -w "TotalScore"
```

So the seam goes in exactly one place, and nothing downstream changes.

```pascal
(* WHAT THE SCORE IS COMPUTED FROM. Filled by the application, which has the
   log; the contest never sees the log. It grows the way TStationContext does:
   a field arrives with the first contest that needs it. *)
TScoreTotals = record
   QSOPoints: longint;
   QTCPoints: longint;
   Mults: TMultTotals;              (* by band, mode and multiplier kind *)
   QSOsByBandMode: TQSOTotals;
   CategoryPower: string;
   BonusStationsWorked: integer;    (* Missouri; Salmon Run when implemented *)
   PeakHourCount: integer;          (* Missouri *)
end;

TContestBase = class
public
   (* THE SPONSOR'S FORMULA. The base: points times the sum of all multiplier
      kinds, or points alone when the contest has no multipliers -- which is
      TotalScore's general case, with its contest arms removed. *)
   function CombineScore(const aTotals: TScoreTotals): longint; virtual;

   (* APPLIED ONCE, AFTER CombineScore, AND NEVER PER QSO. The base adds
      nothing. *)
   function BonusPoints(const aTotals: TScoreTotals): longint; virtual;

   (* WHICH CALLS ARE BONUS STATIONS -- data, not a test. The application
      counts them into BonusStationsWorked; the contest prices them. *)
   property BonusStations: TContestIdList read GetBonusStations;
end;
```

**Final score = `CombineScore` + `BonusPoints`.** Each of today's
`TotalScore` arms has a home:

| arm | goes to |
|---|---|
| ARRL Field Day: points only; Winter Field Day: band-mode mults × points × power factor | `CombineScore` of each (separate classes, per NY4I's Field Day ruling) |
| WAE weighted mults; Cup RF / ALRS / RF Championship / Ukraine Championship / OZHCR `points + N × mults`; RSGB18; CUPURAL | `CombineScore` of each contest. The `ActiveQSOPointMethod` tests there are point-method doc §1's "total-score formula" sites, and its Q3 already recommends the contest |
| FISTS "mults don't work" short-circuit | `CombineScore` of FISTS |
| Missouri W0MA/K0GQ +100 each, plus peak hour | `BonusStations` + `BonusPoints` |
| Salmon Run W7DX (unimplemented, D10) | `BonusPoints`, **when NY4I says so** (**C6**) |
| North Carolina +50 callsigns (D3, scoring side) | **not a bonus.** The sponsor's current rules have none (inventory D3); it dies with the legacy arm |

**Why bonuses are data plus a count, not a log query.** `ValidateQTHCount`'s
comment states the rule: a contest that was handed a list would be one step from
being handed the log. The order in which callers invoke factory methods would
then change what a log scores.

### 4.2 What the golden corpus sees

**`golden_diff.py` keeps `CLAIMED-SCORE`.** Its Cabrillo filter retains `QSO:`,
`X-QSO:` and `CLAIMED-SCORE:` lines (`tr4w/test/python/golden_diff.py`, the
filter around its "Keep the QSO: / X-QSO: records ... PLUS CLAIMED-SCORE"
docstring). `CLAIMED-SCORE` is arithmetic over **stored** points and recomputed
multipliers. So:

- **a `CombineScore` / `BonusPoints` move IS visible to the corpus** for the 13
  sets: a wrong formula moves `CLAIMED-SCORE`;
- **a point-rule change is still NOT visible**, because the stored points do not
  move (`test-contest-factory.sh`'s header says so);
- **`ADDING_A_CONTEST.md` §4 is slightly wrong.** Its row "Cabrillo header --
  nothing -- `golden_diff.py` drops header lines" should say "except
  `CLAIMED-SCORE`". That is a one-line fix for whoever next edits it, not for
  this document.

None of the three bonus contests (Missouri, Salmon Run, NC) has a corpus set
(`ls tr4w/test/corpus`), so their bonuses need a unit test over a hand-built
`TScoreTotals` plus a `BENCH_QUEUE.md` item.

---

## 5. Families

### 5.1 The rule once strategies carry the mechanisms

A base class is justified for one of two reasons only:

- **(a) a family:** two runnings of one contest, where a rule change reaches
  both by definition (`ADDING_A_CONTEST.md` §1);
- **(b) a trait only one kind of contest can express**, where putting it on the
  root let the wrong contests state it. `TContestStateQSOPartyBase`'s county
  line is the worked example: Arktika Spring and ARRL Digital had stated one.

**A shared mechanism is no longer a base.** It is a strategy.
`TContestFixedPoints` was a mechanism base. The point-method doc deletes it in
its S6 and reparents its subclasses. That is the first application of this rule.

### 5.2 The hierarchy after the move

```
TContestBase
├── TContestStateQSOPartyBase        (b) county line, host state (abstract)
│   └── one class per single-state party
├── TContestARRLDXBase    → CW, Phone          (a)
├── TContestARRLSSBase    → CW, SSB            (a)  reparented off TContestFixedPoints
├── TContestCQWWBase      → CW, SSB            (a)
├── TContestCQWPXBase     → CW, SSB            (a)
├── TContestNASprintBase  → CW, RTTY           (a)  new; both are TContestFixedPoints today
├── TContestNRAUBalticBase → CW, SSB           (a)  NY4I's ruling
├── TContestARRLFieldDay, TContestWinterFieldDay    no shared base -- NY4I's ruling
├── TContestSprintSSB                          its own contest, NOT an NA Sprint -- NY4I's ruling
├── TContestPOTA, TContestGeneralQSO           §6
└── every other contest, directly
```

- **Every other two-mode pair follows the NRAU ruling.** That covers JIDX,
  All Asian, SAC, UBA, RSGB RoPoCo, King of Spain, DARC WAEDC, RF Championship,
  CQ 160, NAQP's three modes, the EU Sprints and Cup RF: a `Base` holds the
  contest, and each mode class states only its identity. **One class per
  `ContestType` and one `RegisterContest` per unit still hold** (**C8**).
- **No "sprint" mechanism base and no "DX contest" base.** No rule has been
  identified that a sprint sponsor or a DX sponsor could not change. If one is
  found it arrives as a strategy or a trait, not as a speculative base.
- **The multi-state parties (7QP, NEQP, IN7QPNE) stay open**, for the reason
  `uContestStateQSOPartyBase`'s header gives. Nothing here changes that.

### 5.3 Ordering against the point-method migration

Reparenting off `TContestFixedPoints` happens in the point-method doc's S6. A
new family base (NA Sprint, NRAU, the pairs) should be introduced **after**
that, or as part of it. Putting a family base under `TContestFixedPoints` would
create a two-step reparent.

---

## 6. POTA

**Measured:** 99 lines in `tr4w/src` name `POTA` as a word (`git ls-files
'tr4w/src/*.pas' | xargs rg -i -w POTA | wc -l`). They are spread across
`logstuff`, `MainUnit`, `postunit`, `uADIF`, `fcontest`, `uNewContest`, the
schema and the repository. It already has a `ContestType`, a `ContestsArray`
row (`AE: RSTAndPOTAPark`, `QP: OnePointPerQSO`, no multipliers), a setup arm
(dupes allowed, auto-dupe off) and an ADIF tail (`SIG`/`MY_SIG`).

| option | for | against |
|---|---|---|
| **(a) a contest class, `TContestPOTA : TContestBase`** | it is already a `ContestType` end to end. The base's "none" answers (no multipliers, base `CombineScore`) are correct for it. Its n-fer is the county-line mechanism already: `uLogRepository` writes both as one contact in N rows. **`GENERALQSO` is already registered and is not a contest either** | the root is named "contest" |
| (b) a parallel `TActivity` hierarchy | names the difference | a second registry, a second identity space beside `ceContest`, and every exporter asks two questions. This is the second-definition drift `ContestsArray` and `RadioParametersArray` both demonstrated |
| (c) leave it in shared code | no work | keeps ~99 `POTA` tests where the factory exists to remove them |

**Recommendation: (a).** What POTA needs maps onto seams this document already
creates:

- `RSTAndPOTAPark` as an exchange kind whose park field owns `SIG`/`SIG_INFO`
  in both directions. That is the same pair whose import was broken (inventory
  D5, being fixed concurrently in `MainUnit` as this is written).
- `ValidateQTHCount` for the n-fer limit.
- A dupe-policy property (shared with VAQP and LQP/NCCC, which also set
  `tAllowDupeQSOs`).
- `CabrilloHeaders` that says "none".

Introduce a `TActivityBase` only when a second activity (SOTA, WWFF) arrives
and shows what is genuinely shared. That is the same discipline as the
multi-state parties. Whether to rename the root is **C7**.

---

## 7. Migration order

### 7.1 Which oracle sees what

| oracle | sees | blind to |
|---|---|---|
| `export-d12-corpus.sh` (24/0/2 **and** exit 0) | Cabrillo `QSO:` columns, ADIF records, **`CLAIMED-SCORE`** -- 13 registered contests only | per-QSO points, parsing, setup, every classless contest |
| `test-contest-factory.sh` | rescored points against the frozen legacy output -- 13 logs | parsing, import, classless contests |
| `test-adif-roundtrip.sh` | import against our own export -- 13 sets | classless contests |
| unit tests (`Build-Tests.ps1 -Run`) | any leaf strategy or contest class against fixtures | anything needing globals booted |
| **frozen legacy matrix (new)** | every arm of an axis on synthetic inputs, classless contests included | correctness: it only proves "same as before" |
| bench / a real contest | whether a rule is **right**; the operator UI | -- |

**Every one of the 13 corpus sets is a registered contest**
(`ls tr4w/test/corpus`). The corpus says nothing about a classless contest.
That is why a shared strategy's registration is gated on a matrix, not on the
corpus.

**ONE harness, not one per axis.** The point-method doc proposes a headless
`/POINTMATRIX`. Generalise it to `/MATRIX <axis>` (points, parse, export,
import, setup), with one input generator and one JSONL writer. Each axis's
fixture is frozen once and never regenerated. Five copies of a harness would
drift exactly the way the code they test did.

### 7.2 The steps

Each step is behaviour-preserving unless marked otherwise. Each keeps the corpus
at 24/0/2 with exit 0 and `test-contest-factory.sh` at 13 identical, and each
lowers `Lint-ContestNameTests` ceilings in the same commit.

| step | what | inventory category | gate |
|---|---|---|---|
| **M0** | Decide C1, C2, C3. Promote the inventory scripts to `tools/contest-rules-inventory/` (in progress, by another agent). Widen the lint: shape 2 and per-case arms (inventory §8.2, §8.3; also in progress) | -- | the lint's own fixture |
| **M1** | **Identity read from the class.** The five exporters that read `ContestsArray` for names and ids ask the class (D9). The ADIF id fallback is fixed in the class | Networking, ADIF/Cabrillo identity rows | corpus (ADIF `CONTEST_ID`, Cabrillo `CONTEST:`); `test-adif-roundtrip.sh` |
| **M2** | **Point methods**: `QSO_POINT_METHOD_DESIGN.md` S0-S6, unchanged, running in parallel | Scoring | that document's gates |
| **M3** | **Setup head reads the class.** `ContestDefinition`, `InHostState`, the resolver writing `Active*`. Arms stay and still assign. Freeze the **setup matrix** first: every `ContestType` × station variants (in-state/out, K/VE/DX) → `Active*` + settings | Setup | setup matrix unit test; corpus |
| **M4** | **Exchange kinds, export first.** Field model, kind registry, Cabrillo + ADIF export per kind, from the frozen export matrix. Then delete `FormatsExchange` and D4's dead arms. Initial-exchange strategies alongside | ADIF export, Cabrillo export | export matrix; corpus; round-trip unit test per kind |
| **M5** | **Exchange kinds, import and parse.** `ReadADIF` replaces `ApplyContestSpecificADIFTail` arm by arm, after the arm-to-kind measurement (§2.3). `Parse` replaces `ProcessExchange`'s arms from the frozen parse matrix. Delete D1/D2's dead paths. **Also `uADIF.ApplyADIFFieldsToExchange`'s `APP_N1MM_EXCHANGE1` arm (class for the Field Days, power for FOC Marathon):** the generic importer must not name a contest -- capture the tag into `temps` and let the contest's `ReadADIF` interpret it. It is ALSO order-dependent today: `exch.ceContest` is set only when the loop reaches `CONTEST_ID`, and ADIF fixes no field order, so the tag before `CONTEST_ID` is misread. Interpreting after the whole record is read fixes that structurally; pin it with a test in both tag orders. NY4I, 2026-10-01: not fixed in place -- done here, the right way | ADIF import, Exchange parsing | import + parse matrices; `test-adif-roundtrip.sh`; `BENCH_QUEUE.md` for typed entry |
| **M6** | **Total score.** `TScoreTotals`, `CombineScore`, `BonusPoints`; `TotalScore`'s arms deleted. Missouri's bonus moved; Salmon Run per C6 | Score, summary and totals | corpus (`CLAIMED-SCORE`); unit tests over totals |
| **M7** | **Session arms.** Each `FoundContest` arm becomes that contest's traits + `DescribeSession`, and the arm is deleted. Classless contests gain a class here, mostly as pairs per §5.2 | Setup (the 104 arms) | setup matrix; the arm count ratchets |
| **M8** | **Multiplier kinds**, same pattern as M4 | Multipliers, Dupe | a multiplier matrix; corpus `CLAIMED-SCORE` |
| **M9** | **UI and the rest.** `OperatorPrompts` for `uNewContest`, `TotalsDisplay`, `SummaryColumns`, Cabrillo headers and mode string | UI, Cabrillo headers, Other | bench (no automated gate sees the UI) |
| **M10** | **Endpoint.** Every `ContestType` registered, base getters abstract, `ContestsArray` / `ContestsBooleanArray` / the `Active*` enums' cases deleted, `Test_MovedRowValuesStillMatchTheArray` deleted | -- | corpus; factory gate; full unit run |

**Why export comes before import and parse:** export is the only half the corpus
can see byte for byte. Once a kind's export is pinned, its round-trip test pins
import to it.

### 7.3 What "a contest has moved" means -- checkably

A contest has moved when **all** of the following hold:

1. **The generated inventory reports zero rows naming it**, across shapes 1, 2,
   3 and 5 and every shape-4 row of reach 1-3 that names it. Shape-4 SHARED
   rows (reach 4+) are not per-contest. They leave when their strategy
   registers.
2. **Its class states every row accessor as a literal**, and it is listed in
   `Test_MovedRowValuesStillMatchTheArray`.
3. **Its picks are read.** The setup matrix shows the effective `Active*` equal
   to the class's traits, with no arm overriding them.
4. **Its quirks are variants.** No `Contest`, `ceContest` or `SelectedContest`
   test names it outside the factory. Lint shapes 1 and 2 (after M0) hold that
   per file.
5. **Its corpus set is green on all three scripts**, if it has one. If it has
   none, a unit test scores, formats and round-trips a fixture QSO through its
   class and strategies, and `BENCH_QUEUE.md` carries the real-contest check.

The `Lint-ContestNameTests` ceilings are the ratchet on 4. The inventory
generator is a **report**, not a gate (inventory §8.4), and it is what 1 is
read from.

---

## 8. Open questions for NY4I

These are separate from the point-method doc's Q1-Q7, which are referenced, not
repeated.

- **C1.** All seven `Active*` settings are stored as `NONE` / `UNKNOWN` (source
  `contest`) in every corpus log (§3.3). Should point-method **Q1**'s answer
  ("a stored sentinel means no override") apply to all seven?
- **C2.** ARRL Field Day's DX multiplier (inventory D8): the class says
  `ARRLDXCC`, while the arm says `NoDXMults` and wins. Which is right? The class
  is changed to match before M3 makes the class the source.
- **C3.** Strategy ownership: split the point-method doc's `CreatePointMethod`
  into `CreateOwned...` (owned, nil by default) plus a registry fallback, the
  same shape on every axis (§1.4)?
- **C4.** The exchange model: two levels, with ADIF tags bound per **field**
  (recommended, §2.2), or per kind only?
- **C5.** Does `EXCHANGE RECEIVED` swap parse, export AND import together
  (recommended), mirroring "swap in a different method"?
- **C6.** Final score: bonuses as declared data plus an application-computed
  count, never a log query (§4.1). And should the Salmon Run W7DX bonus be
  implemented now, or stay recorded as missing?
- **C7.** POTA as a contest class (recommended, §6). Keep the root name
  `TContestBase`, with "contest" meaning "an operating event with rules" as
  `ContestType` already does?
- **C8.** Apply the NRAU ruling to every two-mode pair (§5.2), including pairs
  where one mode is rarely run?
- **C9.** (a) The `'TRC'` / `'PGA'` / `'EURASIA'` / `'DL-DX-RTTY'` string tests
  (inventory D7, Cabrillo rows) name events with no `ContestType`. Should they
  become `ContestType`s with classes, or be deleted? (b) Should an
  operator-edited CQ memory survive re-selecting the contest (§3.4)?
- **C10.** Multiplier strategies last (M8), with the four enum traits as the
  contract until then?
- **C11.** The endpoint: **every** `ContestType` gets a class and
  `ContestsArray` is deleted (M10), rather than classless contests reading the
  array indefinitely?
- **C12.** The dead-by-default arms (inventory D1-D4) withdraw an
  operator-selectable value when deleted. Delete each in the commit that
  registers the strategy replacing it, as point-method S5 does?
