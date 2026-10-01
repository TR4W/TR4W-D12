# QSO point methods as factory strategies -- SUPERSEDED 2026-10-01

> **SUPERSEDED, 2026-10-01 -- DO NOT BUILD ANYTHING FROM THIS DOCUMENT.**
>
> **NY4I's ruling of that day:** a contest class OWNS its rules outright through
> virtuals on `TContestBase`. That covers scoring, exchange parsing, ADIF
> import interpretation, ADIF and Cabrillo export, setup, and total score and
> bonuses. There are **no shared strategy objects and no registries** for point
> methods, exchange kinds, multiplier kinds or initial exchange. The
> `QSOPointMethodType` enum was the legacy engine's way to reuse arms of one
> `case`, and in a factory it has no job: *"if I have a field day class, all I
> really need to is call a function in the class that provides the qso info ...
> and the class returns the points."* `QSO POINT METHOD` keeps working for
> classless contests until the migration ends, and is then **retired**. The
> four `QSO POINTS ...` overrides stay. Everything below about
> `TQSOPointMethod`, the registry, `TModeTablePoints`, the resolver, the
> operator "swapping" a method, and deleting `TContestBase.CalculateQSOPoints`
> is therefore **void**. That last one inverts: `CalculateQSOPoints` is the
> permanent seam.
>
> **Read [`CONTEST_OWNERSHIP_DESIGN.md`](CONTEST_OWNERSHIP_DESIGN.md) instead.**
> Only two findings here remain live, and both are restated there (§7.2, §7.3)
> so that document stands alone:
>
> - **Finding 1, the rotated `QSOPointMethodArray`.** It matters only until the
>   setting retires, but the recommendation there is to **fix it now**: the
>   shipped `target/dom/Idaho QSO Party.cfg` asks for `ONE PHONE TWO CW` and
>   gets `TwoPhoneFourCW`.
> - **Finding 2, the sentinels.** Every corpus log stores `NONE` / `UNKNOWN` for
>   all seven `Active*` settings, which stays relevant while `FoundContest` sets
>   globals.
>
> Finding 3 (OQP scores by the session's mode) survives as that document's Q13.
> The body below is kept unedited as the record of the superseded design and of
> the measurements behind it. Its Q1-Q7 are renumbered there with provenance.

**Status (as written):** design only, 2026-09-29, branch `contestFactory`. Nothing here
exists in code yet. Owner: `contest-scoring`, with `contest-factory` and
`settings-config`.

**The ruling this implements (NY4I, option b):** a point method is its own
strategy object in the factory. A contest names its DEFAULT method; the
`QSO POINT METHOD` setting swaps in a different one; the legacy
`case ActiveQSOPointMethod of` disappears. The quick fix -- defer to the class
only when the setting equals the contest's own method -- was rejected because
the override would die with the case: *"we do not go for quick fixes here."*
His example of a reusable rule: Field Day's 1 per phone, 2 per CW or digital.

## 0. The decision in ten lines

1. `TQSOPointMethod` -- an abstract class with one scoring method taking the QSO
   and a `TStationContext`. Stateless and immutable once constructed.
2. A registry keyed by the existing `QSOPointMethodType` enum, holding
   **instances**, self-registered from `initialization` like radios and contests.
3. "A number per mode" is ONE class, `TModeTablePoints`, holding
   `array[ModeType] of integer`. Its 16 enum values are 16 registered instances.
4. Every other arm becomes one class per enum value, one unit each.
5. **A contest never scores.** It names its default through the
   `QSOPointMethod` property it already states. `TContestBase.CalculateQSOPoints`
   is deleted at the end of the migration.
6. A contest-specific variation (RU3AX Memorial's phone doubling, the DL-DX-RTTY
   title test) becomes a constructor parameter, and that contest owns the
   instance it builds. No method ever asks which contest it is serving.
7. The order in the seam: the four `QSO POINTS ...` overrides, then the
   operator's method, then the contest's default.
8. "The operator chose" is read from the **setting's string**. It is never read
   from the global, which becomes a derived value that is never persisted.
9. The oracle for the migration is a **frozen legacy matrix**: every arm run
   once over a synthetic QSO matrix and written to a file, then compared against
   the strategies by a unit test. `test-contest-factory.sh` covers 13 real logs
   and cannot cover 130 arms.
10. **Two defects have to be decided first**, and both are measured in section 1:
    the setting's spelling table selects the WRONG method for 46 of its values,
    and every corpus log stores `QSO POINT METHOD = NONE`.

---

## 1. Measured inventory

Every number below comes from the script in the [appendix](#appendix-the-inventory-script),
which runs over **`PascalSource.psm1`'s code-only text**. A line regex was not
used. Nested cases and a brace comment between a label and its colon have
produced wrong counts here before. Reproduce with:

```bash
powershell -NoProfile -Command "Import-Module ./tr4w/build/PascalSource.psm1; [IO.File]::WriteAllText('$S/logstuff_code.txt', (Get-PascalCodeOnlyText -Path ./tr4w/src/trdos/logstuff.pas -BlankStrings))"
python qp_inventory.py "$S/logstuff_code.txt" tr4w/src/VC.pas
```

| measure | value |
|---|---:|
| values of `QSOPointMethodType` | 133 |
| arms of `case ActiveQSOPointMethod of` (one label each, no `else`) | 130 |
| enum values with no arm -- they score 0 through the reset at the top of the routine: `SouthAmericanQSOPointMethod`, `INQsoPoinrMethod`, `NYQPQP` | 3 |
| arms that are a **pure function of `Mode`** | 16 |
| arms that read **no station, contest or session state**. Helpers they call are not followed, so this is an upper bound | 40 |
| arms that read `Settings.My.*` | 75 |
| arms that read the bare `My*` globals (`MyContinent`, `MyZone`, ...) | 55 |
| arms that read `RXData.Band` / `RXData.Mode` | 28 / 19 |
| arms that read `Settings.Contest.*`: `DLRTTY`, `EuropeanVHF` (`Title`/`Name` compared to a contest name), `YBFT8QP`, `StewPerry` (`CategoryPower`) | 4 |
| arms that branch on the `Contest` enum: `RussianDX` (`Contest = RU3AXMEMORIAL`) | 1 |
| arms that read the SESSION mode instead of the QSO's: `OQP` (`ActiveMode`) | 1 |
| arms that call a TRDOS helper reading FCONTEST state: `ARRL160` (`DomesticCountryCall`) | 1 |
| arms that **write a field other than `QSOPoints`** -- `InhibitMults` (AllAsian, ARRLDX, JIDX, IRTS, RTC), `DomMultQTH` (MWCQP, ChampionshipRF, YouthChampionshipRF, YOTA), `DomesticMult` (UBA, Ukrainian), `ZoneMult` (NZFieldDay), `Prefix` (YL_ARCK_YL), `DXQTH` (IRTS) | 13 |

The 16 mode-only arms: `ARRLFieldDay`, `ARRL10`, `BCQP`, `PA`, `SalmonRun`,
`NoQSOPointMethod`, `AlwaysOnePointPerQSO`, `OnePointPerQSO`, `TwoPointsPerQSO`,
`ThreePointsPerQSO`, `TenPointsPerQSO`, `ThreePhoneFiveCWFourRTTY`,
`TwoPhoneFourCW`, `TwoPhoneThreeCW`, `OnePhoneTwoCW`, `ThreePhoneFiveCW`.

**The uContestBase header's argument measures small.** It says the enums "do
not compose" because arms branch on the contest anyway. That is 1 arm on the
enum and 3 on a contest title or name, out of 130. Section 3 turns each of the
four into a constructor parameter.

### What the factory holds today (working tree, 2026-09-29, still moving)

```bash
cd tr4w/src/contestFactory
rg -o "RegisterContest\(\s*\w+" *.pas | rg -v "uContestRegistry|aContest" | wc -l   # 55 contests
rg -l "class\(TContestFixedPoints\)" *.pas | wc -l                                   # 25 inherit it
rg -l "FixedModePoints\(" *.pas | rg -v uContestFixedPoints | wc -l                  # 17 units call it
rg -l -i "procedure T\w+\.CalculateQSOPoints" *.pas | wc -l                          # 28 (incl. base + FixedPoints)
```

### `ActiveQSOPointMethod` is not only a scoring switch

It is read at **10 live sites outside the case**. Each one means the setting
changes something other than points today:

| site | what an operator's QSO POINT METHOD changes there |
|---|---|
| `logsubs2.pas` (`AlwaysOnePointPerQSO`) | **dupes are not marked** |
| `logstuff.pas` `ProcessRSTAndQSONumberOrDomesticQTHExchange` x3 (`RAC`, `PCC`, `ArktikaSpring`) | **how the exchange is parsed** |
| `zonecont.pas` (`RussianDX`) | the initial exchange |
| `logedit.pas` x5 (`WAE`, `CupRF`, `ALRSUA1DZCup`, `ChampionshipRF`, `OZHCRVHF`) | **the total-score formula**: band weights, or points + N x mults instead of points x mults |

List them with `rg -n -i "ActiveQSOPointMethod" tr4w/src --glob '*.pas'`, then
drop the commented lines and the `backup/` hits by eye.

### FINDING 1 -- the setting's spelling table is rotated, and has been since D7

`QSOPointMethodArray` is `array[QSOPointMethodType] of string`, and
`ApplyMultiplierToken` assigns the **position** of the matching spelling. The
compiler checks the array's length. It does not check its order, and the order
is wrong. `'LABRE'` sits at position 81, when `LABREQSOPointMethod` is ordinal
38. That shifts every entry from 38 to 81 back by one. Positions 124 and 125
are swapped as well:

| the operator writes | the method actually selected |
|---|---|
| `ONE PHONE TWO CW` | `TwoPhoneFourCW` |
| `TWO POINTS PER QSO` | `OnePointPerQSO` |
| `ONE POINT PER QSO` | `AlwaysOnePointPerQSO` -- **dupes stop being marked** |
| `TWO PHONE THREE CW` | `ThreePhoneFiveCW` |
| `SALMON RUN` | `RDAQSOPointMethod` |
| `STEW PERRY` | `SLFivePointQSOMethod` |
| `LABRE` | `RadioVHFFDQSOPointMethod` |
| `MWCQP` / `BC QSO PARTY` | `BCQP` / `MWCQP` |

That is **46 of the 133 spellings**, and `OldNewYear` cannot be reached by
name at all (`'ONY'` appears twice). I confirmed the rotation two ways. First,
the anchors `KCJ` (37) and `LZ` (82) line up in both lists while the entries
between them do not. Second, the D7 tree at `C:\TR4W` has the same rotation
(`VC.pas`: enum lines 2940-2941 against array lines 3094 and 3137-3139). **It is
a D7 defect, not a port regression.** It stayed hidden because the setting is
rarely used, and because since the factory arrived a contest with a class
ignores the setting completely. Fixing it changes what an existing `.cfg`
selects -- **Q2**.

### FINDING 2 -- every corpus log stores the setting as `NONE`

```bash
python -c "import sqlite3,glob; [print(f, list(sqlite3.connect(f).execute(\"select value,source from config where command='QSO POINT METHOD'\"))) for f in glob.glob('tr4w/test/corpus/*/log.db')]"
```

All 13 answer `('NONE', 'contest')`, and all 13 were written 2026-09-24. `NONE`
is a valid spelling for `NoQSOPointMethod`. So a design that reads "a non-empty
setting means the operator chose" would **score every one of those logs zero**.
This is the `DeriveCountry` trap exactly: a default value was persisted, and it
reads back as a stated one. **Not established:** which code wrote it, and
whether applying it zeroes an interactive rescore of a classless contest today.
The frozen `rescored.*` baselines are nonzero, so the headless path at least
does not apply it. Both belong on the bench before slice 2 -- **Q1**.

### FINDING 3 -- the OQP arm scores by the session's mode

`OQPQSOPointMethod` tests `ActiveMode`, not `RXData.Mode`. A rescore or an
edited QSO therefore scores by whatever mode the radio is in now. The port
should fix this, and the fix changes scores -- **Q7**.

---

## 2. The shape

### The class

```pascal
(* ONE RULE FOR TURNING A QSO INTO POINTS. Stateless: everything it may read
   arrives as a parameter, so one instance serves every contest and every
   thread, and a unit test can construct one without booting TR4W. *)
TQSOPointMethod = class
private
   FKind: QSOPointMethodType;
   FToken: string;
protected
   (* THE TRAIT, NOT THE IDENTITY. logsubs2 asks "does this method ignore
      dupes", never "is this AlwaysOnePointPerQSO". *)
   function GetScoresDupes: boolean; virtual;
public
   constructor Create(aKind: QSOPointMethodType; const aToken: string);

   (* Writes aQso.QSOPoints. A method that ALSO writes a multiplier field --
      13 legacy arms do -- names that field in its class header, and the
      matrix test compares the whole record rather than just the points. *)
   procedure Score(var aQso: ContestExchange;
                   const aStation: TStationContext); virtual; abstract;

   property Kind: QSOPointMethodType read FKind;
   property Token: string read FToken;
   property ScoresDupes: boolean read GetScoresDupes;
end;
```

**The context is `TStationContext`**, and nothing else. It moves out of
`uContestBase` into a leaf unit, `uStationContext`, and `uContestBase` re-exports
it as an alias. `uCabrilloExchange` already does this for
`TMyStationExchange`. The record keeps the growth rule its header states: a
field arrives with the first method that needs it. From the table above, the
fields still to come are `MyCall`, `MyState`, `CategoryPower` and the domestic
country list. **A method must not read globals**, and that rule is what lets
it be unit tested. The helpers the arms call from TRDOS units
(`GetDistanceBetweenGrids` in `loggrid`, `DomesticCountryCall` in `zonecont`)
get lifted into leaf units first. `MarineOrAirMobileStation` already moved to
`uCallSignRoutines` for Virginia, and that is the precedent.

**The contest is not in the context.** A method that needs to know something
about the contest gets it as a constructor parameter. Section 3 explains why.

### The registry

`uQSOPointMethodRegistry`, shaped like `uContestRegistry`:

- `RegisterQSOPointMethod(aMethod)` keys the instance on `aMethod.Kind`. It
  **raises on a duplicate** and owns the instance, freeing it in `finalization`.
- `QSOPointMethodFor(aKind)` returns `nil` for a kind nobody has moved yet.
  That nil is **an ordinary answer during the migration**, and the caller falls
  through to the legacy case.
- `QSOPointMethodForToken(aToken)` is the setting's lookup. **The spelling moves
  onto the method**, and `QSOPointMethodArray` is deleted at the end. A spelling
  that lives beside its rule cannot rotate away from it, which is Finding 1's
  fix and the same lesson `RadioTypeToken` learned.

**Instances, not classes**, which differs from the contest registry on purpose.
A contest object carries a station snapshot and gets rebuilt. A method carries
nothing, so one shared instance per kind is right. It also lets one class
register 16 times with different data.

### The parameterised family: one class, a full table

```pascal
(* A NUMBER PER MODE -- all six modes, stated. The compiler refuses an array
   constant with a missing element, so no mode can silently default to 0. *)
TModePointTable = array[ModeType] of integer;   (* CW, Digital, Phone, Both, NoMode, FM *)

TModeTablePoints = class(TQSOPointMethod)
private
   FPoints: TModePointTable;
public
   constructor Create(aKind: QSOPointMethodType; const aToken: string;
                      const aPoints: TModePointTable);
   procedure Score(var aQso: ContestExchange;
                   const aStation: TStationContext); override;
end;

const
   (* ARRL Field Day: phone AND FM score 1; CW and digital score 2. *)
   ARRLFieldDayPoints: TModePointTable = (2, 2, 1, 2, 2, 1);
   (* BC and PA: "if Mode = PHONE" -- so digital scores the CW value. *)
   BCQPPoints: TModePointTable = (4, 4, 2, 4, 4, 4);

initialization
   RegisterQSOPointMethod(TModeTablePoints.Create(ARRLFieldDayQSOPointMethod,
                                                  'ARRL FD', ARRLFieldDayPoints));
   RegisterQSOPointMethod(TModeTablePoints.Create(BCQPQSOPointMethod,
                                                  'BC QSO PARTY', BCQPPoints));
```

**Why a table, and not `FixedModePoints(cw, phone, other)`:** among the 16
mode-only arms there are three shapes the three-number form cannot express.
Field Day puts FM with phone. `BCQP` and `PA` test `Mode = PHONE`, so digital
gets the **CW** value. `ThreePhoneFiveCWFourRTTY` gives digital its own number.
Three numbers can cover each of these only by accident, and the Field Day
failure would be silent. `ADDING_A_CONTEST.md` already records that Field Day
does not fit `TContestFixedPoints`.

**Enum value to instance:** every enum value with an arm gets **exactly one
registered instance**. The 16 mode-only values share one class. Each of the
other 114 gets its own class in its own unit, under
`src/contestFactory/pointMethods/`. The enum stays as the key, because the
contest row, the persisted setting and the 10 secondary sites all speak it.

---

## 3. How a contest relates to its method

**Decision: the contest names its method and never scores.**

| option | verdict |
|---|---|
| (a) the contest keeps a virtual `CalculateQSOPoints` that composes a method | **Rejected.** This is today's defect moved to a new place: any contest that overrides it bypasses the operator's choice again. The seam must call the method, not the contest |
| (b) every rule, even a contest-specific one, is a `TQSOPointMethod` registered under its enum value | **Chosen** as the general case |
| (c) a contest builds and owns an unregistered instance | **Chosen only for a parameterised variant** of a registered class |

- **The default comes from what the contest already states.** Under Step 3b,
  every class returns a literal from `GetQSOPointMethod`, and that literal is
  its default. `TContestBase` gains one virtual, `CreatePointMethod`. The base
  returns the registry's instance (not owned). A contest overrides it only to
  build a variant, and the contest owns and frees that variant.
- **A contest-specific rule is still a method.** NC's rare-county rule becomes
  `TNCQSOPoints`, registered under `NCQSOPointMethod`. The legacy case offers
  every method to every contest, and this keeps that: an operator can pick
  `NC QSO Party` anywhere, as today. The rare-county list is the NC method's
  data, not the contest's. Salmon Run is one of the mode-only table rows.
- **A variation becomes a constructor parameter.** `RussianDX` becomes
  `TRussianDXPoints.Create(..., aPhoneScoresDouble: boolean)`. The registered
  instance passes `False`, and `TContestRU3AXMemorial` builds its own with
  `True`. The `Title`/`Name` checks in `DLRTTY`, `EuropeanVHF` and `YBFT8QP` are
  handled the same way. **No method ever tests which contest it serves**, which
  is `ADDING_A_CONTEST.md`'s first rule applied one level down.
- **`CategoryPower` (StewPerry) is not a contest fact.** It describes the
  entry, so it goes into `TStationContext`.

When the operator overrides the method, a contest's variant is not used and the
registered instance is. That is the plain reading of "swap in a different
method".

---

## 4. The seam after migration

```pascal
procedure CalculateQSOPoints(var RXData: ContestExchange);
var
   method: TQSOPointMethod;
begin
   RXData.QSOPoints := 0;

   (* 1. The four QSO POINTS ... settings. Unchanged: each is partial and
         falls through when it does not apply. *)
   if ApplyFixedPointOverrides(RXData) then
      begin
      Exit;
      end;

   (* 2 and 3. The operator's method if one is set, else the contest's. The
         resolver caches its answer and is invalidated by the QSO_POINT_METHOD
         setting effect and by a contest change -- never per QSO. *)
   method := EffectiveQSOPointMethod;
   if method <> nil then
      begin
      method.Score(RXData, CurrentStation);
      Exit;
      end;

   (* Migration only: a kind that has no class yet. *)
   LegacyQSOPoints(RXData);
end;
```

The resolver's order: **the operator's kind** (the setting's token resolves to a
registered method) -> **the contest's method** (`ActiveContest.PointMethod`) ->
`nil`, which means legacy. While the migration runs, an override naming a kind
that has no class falls to the legacy case with the global set to that kind,
which is exactly what happens today.

### What "set" means

- **Read the setting's string, `Settings.Contest.QsoPointMethod`, and never the
  global.** Today the string already tells the two apart: it is `''` unless
  something wrote it, `ApplyMultiplierToken` ignores `''`, and the on-close
  capture writes the string back unchanged. The **global** is what mixes them
  up, because `FoundContest` and the setting effect both write it. The global
  becomes a **derived** value: the resolver writes it for the 10 secondary
  sites, and it is never persisted and never read back to decide anything.
- **The exception is Finding 2.** A stored `NONE` cannot be told apart from a
  deliberate choice. Recommendation (**Q1**): take `NoQSOPointMethod` out of the
  operator's vocabulary, so a stored `NONE` reads as "no override". A contest can
  still default to it. This follows the precedent of
  `SetDomesticFilename` healing existing logs.
- Preferences shows `''` as **"Contest default (<its method>)"**, so the default
  is visible and not a blank.

### The 10 secondary sites

During the migration they keep reading the global, which the resolver keeps
equal to the effective kind. That is today's behaviour exactly. Then each moves
to where it belongs (**Q3**):

| site | recommended home | why |
|---|---|---|
| dupe marking (`AlwaysOnePointPerQSO`) | `method.ScoresDupes` | it is about scoring, so it should follow the operator's choice |
| exchange parsing (RAC, PCC, Arktika), zonecont | the **contest** | changing the scoring should not change how an exchange is typed |
| total-score formulas in logedit | the **contest**, via the `calculateTotalScore` seam (`ADDING_A_CONTEST.md` section 6) | the sponsor's formula for combining points and multipliers belongs to the contest |

The second and third rows **change behaviour** for an operator who overrides
today.

---

## 5. Migration path

Each step is behaviour-preserving unless it says otherwise. Each one is gated,
and each one keeps `export-d12-corpus.sh` at `24/0/2` with exit 0 and
`test-contest-factory.sh` at 13 identical.

| step | what | the gate that sees it |
|---|---|---|
| **S0** | Decide Q1 and Q2. Add a unit test that pins **every** spelling to its kind. (The fix itself is a behaviour change.) | the unit test |
| **S1** | **Freeze the legacy matrix.** Extract the case into `LegacyQSOPoints` -- one mechanical TRDOS edit -- and add a headless `/POINTMATRIX` mode, like `/EXPORT`, that runs it for all 133 kinds. The inputs are a synthetic QSO matrix (every mode x bands x domestic/DX x continents x zones x grids) seeded with **the literal strings the arms compare against** (`N4T`, `3ODX`, county codes, contest titles), which the inventory script can harvest, crossed with station variants (K, VE, DL, JA, UA, ...; the four `Settings.Contest` values; `ActiveMode`). Write the **whole resulting `ContestExchange`** to `test/unit/fixtures/pointmatrix/legacy.jsonl`. **Frozen once, never regenerated**, like `rescored.adi`. **It must happen before any arm is deleted** | nothing yet. It is the oracle |
| **S2** | `TQSOPointMethod`, the registry, the `uStationContext` move, `TModeTablePoints` with its 16 rows. **Not wired.** | a unit test: every registered method reproduces its kind's rows in the matrix, field by field |
| **S3** | Wire the seam and the resolver. The contest's default is the registry's instance where one exists, else the class's own `CalculateQSOPoints`, else the legacy case | `test-contest-factory.sh`, which **catches Finding 2 if Q1 is wrong**; a unit test that the override beats the default; a `BENCH_QUEUE.md` item |
| **S4** | For each contest class with its own `CalculateQSOPoints`: prove over the matrix that it scores the same as the registered method (both sides are leaf units, so this is a plain unit test), then delete the override. **NC scores differently by ruling**: `TNCQSOPoints` takes the class's current rules and is recorded as a known divergence from the frozen legacy rows | unit test; `test-contest-factory.sh` |
| **S5** | Port the remaining arms in batches, easiest first: the QSO-only 40, then station-only, then the 4 contest-parameterised, then the arms that need a helper lifted (`loggrid`, `zonecont`). **An arm is deleted in the commit that registers its method**, since it is unreachable from then on | matrix unit test per method |
| **S6** | Re-home the 10 secondary sites (Q3). Delete `ActiveQSOPointMethod`, the case, `QSOPointMethodArray`, `TContestBase.CalculateQSOPoints`, `TContestFixedPoints`, `FixedModePoints` | corpus; factory gate; bench |

### Which oracle sees what

| | sees |
|---|---|
| golden corpus | **nothing about scoring.** `/EXPORT` sums the stored points |
| `test-contest-factory.sh` | 13 real logs -- about 13 kinds, and only the QSOs those logs contain |
| frozen matrix (new) | **all 130 arms**, but only on synthetic inputs, and only "same as TR4W did", never "correct" |
| unit tests | a strategy against the matrix; a class against a strategy |
| bench / real contest | the only check of whether a rule is **right**, and of the operator override in the UI |

**A green matrix proves equivalence to the old code, not correctness.** The
scoring rules still need a real contest.

---

## 6. What happens to `TContestFixedPoints` and `FixedModePoints`

Both are **deleted in S6**. Their rule survives as `TModeTablePoints` rows,
with the full six-mode table instead of three numbers.

- The 25 subclasses of `TContestFixedPoints` are reparented to `TContestBase`.
  They already state their `QSOPointMethod`, so their `SetPoints` call goes and
  nothing else changes. S4 checks, for each one, that `SetPoints` and the
  registered row agree on all six modes. Where a subclass has no
  `GetQSOPointMethod` (ARRL SS, General QSO, NA Sprint), its array `QP` is the
  answer, and the check applies to that.
- The 17 units that call `FixedModePoints` get the same treatment.
- **`uContestBase`'s header must be corrected in S2.** Its argument ("the unit
  is a contest, not a strategy enum") still holds for the contest as a whole.
  Scoring now has a second axis only because the operator selects it
  separately.

---

## 7. Risks, open questions, first slice

### Risks

- **Finding 2 zeroes the corpus logs** if S3 lands before Q1 is decided.
  `test-contest-factory.sh` would catch it. An operator's own logs would not
  have that protection.
- **The rescore visibly changes stored points** for any log whose override now
  takes effect. That is the intended result, but it will surprise operators.
- **Multi-op:** whether `QSO POINT METHOD` crosses the network, and whether two
  stations can then score one contest differently. Coordinate with
  `multi-op-network`.
- **The matrix only covers what the matrix contains.** Harvesting each arm's
  string literals narrows the gap. It does not close it.
- **Some arms write multiplier fields**, so an operator's point method can
  change multiplier bookkeeping today. The matrix preserves that, and Q3 decides
  whether it should stay.

### Open questions for NY4I

- **Q1.** A stored `NONE` in every existing log: treat it as "no override" and
  take `NONE` out of the operator's vocabulary?
- **Q2.** The rotated spelling table: fix it so each name selects its own method
  (which changes what existing `.cfg` files get), with a log line on load when a
  stored spelling now means something different?
- **Q3.** Should an override change dupe marking (recommended yes), exchange
  parsing (no) and the total-score formula (no)?
- **Q4.** 16 table rows in one unit, or one unit each to match "one
  registration per unit"? Recommendation: one unit, because they are rows of one
  class in the same way the radio registry holds per-model data.
- **Q5.** The three kinds with no arm (`SouthAmerican`, `IN`, `NYQPQP`) score 0
  today. Register them as zero, or remove them from the vocabulary?
- **Q6.** The four `QSO POINTS ...` settings: leave them as a layer ahead of the
  method (recommended), or make them a method of their own?
- **Q7.** Fix OQP to score by the QSO's own mode when it moves?

### Recommended first slice

**S0 + S2, plus the Field Day proof.** Pin the spelling table, build the base
class, the registry, the context move and `TModeTablePoints` with its 16 rows,
and unit-test each row against a literal six-mode table read out of its arm.
These 16 arms are small enough to state exhaustively, so the matrix is not
needed yet. That changes no behaviour. Slice 2 is **S1 + S3 restricted to the 16
table kinds**. After it, `QSO POINT METHOD = ARRL FD` scores Field Day's rule in
**any** contest -- NY4I's example -- and every other override behaves exactly as
it does today.

---

## Appendix: the inventory script

Run it over the code-only text as shown in section 1. Three-space indent, per
this tree's Python rule.

```python
import re
import sys

code_path, vc_path = sys.argv[1], sys.argv[2]
lines = open(code_path, encoding='latin-1').read().split('\n')

# Locate the case and the end of its routine rather than hard-coding lines.
start = next(i for i, l in enumerate(lines)
             if re.match(r'\s*case\s+ActiveQSOPointMethod\s+of', l, re.I))
end = next(i for i in range(start, len(lines))
           if re.match(r'(procedure|function)\s', lines[i]))
text = '\n'.join(lines[start:end])
toks = [(m.group(0), start + 1 + text.count('\n', 0, m.start()))
        for m in re.finditer(r":=|[A-Za-z_]\w*|\d+|\S", text)]

# Walk tokens tracking begin/case/try/record/asm ... end depth. A label is only
# an arm label at the OUTER case's depth and only once the previous arm has
# closed with ';' -- so nested cases and if/else cannot add arms.
openers = {'begin', 'case', 'try', 'record', 'asm'}
arms, cur, labels, depth, i = [], None, [], 1, 3
while i < len(toks):
   t, ln = toks[i]
   tl = t.lower()
   between = cur is None or cur['closed']
   if depth == 1:
      if tl == 'end':
         break
      if tl == 'else' and between:
         cur = {'label': '<else>', 'line': ln, 'closed': False}
         arms.append(cur)
         i += 1
         continue
      if t == ':' and labels:
         cur = {'label': ','.join(x for x in labels if x != ','),
                'line': labels_line, 'closed': False}
         arms.append(cur)
         labels = []
         i += 1
         continue
      if between and (re.match(r'[A-Za-z_]', t) and tl not in openers
                      or (t == ',' and labels)):
         if not labels:
            labels_line = ln
         labels.append(t)
         i += 1
         continue
   if tl in openers:
      depth += 1
   elif tl == 'end':
      depth -= 1
   if depth == 1 and t == ';' and cur is not None:
      cur['closed'] = True
   i += 1

bounds = [a['line'] for a in arms] + [end + 1]
for k, a in enumerate(arms):
   a['body'] = '\n'.join(lines[a['line'] - 1:bounds[k + 1] - 1])
print('arms:', len(arms))

def strip(s):
   s = re.sub(r'//[^\n]*', '', s)
   s = re.sub(r'\{[^}]*\}', '', s)
   return re.sub(r'\(\*.*?\*\)', '', s, flags=re.S)

vc = open(vc_path, encoding='latin-1').read()
e = vc.index('QSOPointMethodType =')
enum = [x.strip() for x in strip(vc[e:vc.index(');', e)]).split('(', 1)[1].split(',')
        if x.strip()]
armset = {a['label'].lower() for a in arms}
print('enum values:', len(enum), ' no arm:', [v for v in enum if v.lower() not in armset])

state = (r'Settings\s*\.|(?<![.\w])My(Continent|Zone|Country|Grid|State|Call)\w*\b'
         r'|\bDomesticCountryCall\b|(?<![.\w])Contest\b|\bActive(Mode|Band)\b')
reads = {
   'RXData.Mode': r'RXData\s*\.\s*Mode\b',
   'RXData.Band': r'RXData\s*\.\s*Band\b',
   'Settings.My.*': r'Settings\s*\.\s*My\s*\.',
   'bare My* globals': r'(?<![.\w])My(Continent|Zone|Country|Grid|State|Call)\w*\b',
   'Settings.Contest.*': r'Settings\s*\.\s*Contest\s*\.',
   'the Contest enum': r'(?<![.\w])Contest\b',
   'ActiveMode/ActiveBand': r'\bActive(Mode|Band)\b',
   'DomesticCountryCall': r'\bDomesticCountryCall\b',
}
for name, rx in reads.items():
   hit = [a['label'] for a in arms if re.search(rx, a['body'], re.I)]
   print('  reads %-22s %3d %s' % (name, len(hit), ' '.join(hit) if len(hit) <= 6 else ''))
print('no station/contest/session state:',
      len([a for a in arms if not re.search(state, a['body'], re.I)]))

field_write = r'RXData\s*\.\s*(\w+)\s*(?:\[[^\]]*\])?\s*:='
side = [a for a in arms
        if {x.lower() for x in re.findall(field_write, a['body'], re.I)} - {'qsopoints'}]
print('arms writing a field other than QSOPoints:', len(side))

# A pure function of the mode: no RXData field but Mode, no call, no RXCty
# (the routine's local copy of RXData.QTH.CountryID), no state.
def mode_only(a):
   fields = {x.lower() for x in re.findall(r'RXData\s*\.\s*(\w+)', a['body'], re.I)}
   calls = re.findall(r'[A-Za-z_]\w*\s*\(', a['body'])
   return (fields <= {'mode', 'qsopoints'} and not calls
           and not re.search(r'\bRXCty\b', a['body'], re.I)
           and not re.search(state, a['body'], re.I))
print('pure function of Mode:', len([a for a in arms if mode_only(a)]))
```
