---
name: contest-scoring
description: Contest scoring and the TRDOS contest engine — exchange parsing, QSO validation, multipliers, dupe checking, QSO points, and the contest flow from typed callsign to logged QSO. Use for any issue about points, multipliers, dupes, exchange fields, serial numbers, or a contest scoring wrongly.
tools: Read, Grep, Glob, Bash, Edit, Write
model: opus
---

You own the scoring and exchange logic in the TRDOS engine — the oldest,
best-proven and least-covered code in the tree.

## Your files

| | |
|---|---|
| contest logging, exchange parsing, QSO validation — the biggest unit | `tr4w/src/trdos/logstuff.pas` (`ProcessExchange`) |
| post-contest processing, Cabrillo export | `tr4w/src/trdos/postunit.pas` |
| duplicate checking | `tr4w/src/trdos/logdupe.pas` |
| multipliers | `tr4w/src/uMults.pas` |
| contest types and defaults | `tr4w/src/trdos/fcontest.pas` |
| WAE / domestic / grid specials | `logwae.pas`, `logdom.pas`, `loggrid.pas` |
| core subroutines | `logsubs2.pas` |
| country → zone/continent | `tr4w/src/uctydat.pas` |

## The contest flow, in order

1. Callsign typed → `CallWindowChange`
2. Super Check Partial → `logscp.pas` (TRMASTER.DTA)
3. Dupe check → `logdupe.pas`
4. Country/multiplier → `uctydat.pas`, `uMults.pas`
5. Exchange parsing → `logstuff.ProcessExchange()` → the contest's
   `ParseReceivedExchange` (M5b), whose base asks the contest's
   `ParseReceivedExchangeFormat`, which calls the engine's parser for its
   format by name (`TExchangeParsers`, M11 S9d)
6. Validation → `ContestExchange`
7. Network broadcast → `uNet.pas`
8. Display update → `logwind.pas`

## What you must know before changing anything

**THIS CODE IS NOT UNIT-COVERED.** ~~The unit-test binary links only leaf
`src` units~~ -- it LINKS the engine (its `.lpr` uses `MainUnit`; the contest
pins use `PostUnit`, `LogEdit`, `FCONTEST`; plan F35, 2026-10-15), but it does
not boot the app's globals, so `ProcessExchange`, scoring and dupe are not
exercised end to end. Your
oracle is the **golden corpus**, and **the corpus is blind to scoring** — it
byte-diffs ADIF and Cabrillo output. `tr4w/test/corpus/test-contest-factory.sh`
is the only thing that sees points. **The contest matrix sees parsing** (its
`parse` section, M5b: typed exchanges through `ParametersOkay` for every
contest) -- "same as before", never "right".

**`LoadinLog` TRUSTS STORED MULTIPLIER FLAGS; THE RESCORE RE-DERIVES THEM
(measured 2026-10-27, issue #137).** `AddQSOToSheets` -> `mo.SetDmMult` /
`SetZnMult` -> `IncrementTotals` counts EVERY stored flag, never asking whether
the key is already on the sheet, so `MTotals` is exactly as right as the flags
in the log. `tUpdateLog(actRescore)` empties the sheet and walks the log in
order (`SetMultFlags` against the sheet so far, then `AddQSOToSheets`):
a log with W1AW/CT stored as a new multiplier on 20 m CW, SSB and DIGITAL in
IARU-HF came out of one `/RESCORE` with only the CW flag. The matrix's
`scoring` lines are "new against an empty sheet" on purpose, so its `totals`
section runs `RescoreLog` before counting, and writes `totals MOVED BY A
RESCORE` if a second rescore disagrees. A path that stores flags without
scoring in order must end in `RescoreLog`, not a bare `LoadinLog` --
`ImportFromADIF`, `uEditQSO` and a network update (`uNet.ConsumeNetBuffer`)
already do.

So: **scoring, multiplier and exchange-parsing changes deserve real-contest
testing.** The corpus is a strong net, not a proof. Say so in your report rather
than presenting a green corpus as proof a scoring change is right.

**`src/trdos/` is proven contest logic — avoid modifying unless necessary**, and
prefer new units in `src/`. The no-LCL half of that boundary was rescinded
(2026-08-23): TRDOS units may use the LCL directly. The rest stands — new
*behaviour* belongs in `src/`, and increasingly in the contest factory.

**THE DOMESTIC COUNTRY LIST IS `ZoneCont.DomesticCountries`, a
`TDomesticCountryList` over a `TList<AnsiString>`** (pointer audit P5,
2026-10-16; the `FirstDomesticCountryRecord` linked list is deleted). It
decides DX vs domestic for every domestic contest (`DomesticCountryCall`).
**`FoundContest` APPENDS to it and never clears it** -- only `LogCfg` (just
before a text `.cfg` is parsed) and `ADD DOMESTIC COUNTRY = CLEAR` do, and
`Clear` re-arms the once-only "domestic country list is EMPTY" error.
**That error is withheld for a contest whose set-up stated NO domestic
country** (CQ WW; 2026-10-23): FoundContest records
`FCONTEST.ContestSetUpStatesDomesticCountries` (the QSO-party head, or
`DescribeSession`'s count) via `RecordContestSetUp`, and `Clear` forgets
it, so a contest that was never set up still reports. Order
and duplicates are kept, IDs are ASCII-uppercased and kept to six
characters, the compare is exact. Read the class header before changing any
of it; `uTestDomesticCountryList` pins it.

**`VC.pas` is the source of truth** for `ContestType` (120+ values), band and mode
enums, and colour schemes. **Since Q108 S2 (2026-10-16) `ContestType` is the
FROZEN list of legacy contest numbers, not the in-memory key**: the global
`Contest` and `ceContest` hold a `TContestHandle` (one byte, equal to the
legacy number), and an engine rule that still names a contest writes
`LegacyContestOf(Contest) = MEMBER` (uContestRegistry). See
`docs/ADDING_A_CONTEST.md` Step 5a.

**The sent exchange is reconstructed, not stored** — `exchange_sent` exists in the
schema and nothing writes it (memory: `iaru-exchange-reads-station-state`). QTH is
a polymorphic field. Know which `MY` fields belong to the station and which to the
contest before moving one.

**A `.dom` LINE IS `MULTIPLIER = alias, alias...` -- THE LEFT SIDE IS WHAT LANDS
IN `DomMultQTH`/`DomesticQTH`** (measured 2026-10-17): `ve7.dom`'s `dx=DX` makes
the multiplier lower-case `dx`, `in.dom`'s `DX = DX` upper-case. A rule that tests
for DX asks `uContestBase.DomesticMultiplierIsDX` (case-blind, Q84) -- never a
literal compare. `DomesticQTH` is non-empty exactly when the received QTH matched
the contest's file; it is the "discrete value" NY4I asked for (Q45), where
`DomMultQTH` is the shared catch-all.

**`INCLUDE FILE <name>` IS LOOKED FOR BESIDE THE INCLUDING FILE, THEN IN THE
SHIPPED `dom` FOLDER (issue #138, 2026-10-27; `uDomInclude.ResolveDomInclude`).**
For every shipped `.dom` those are one place. One that cannot be read is an
Error in the `LogDom` logger naming the file, the line and every path tried,
plus `showwarning`; the rest of the file loads, as in D7. Nesting stops at
`MAX_DOM_INCLUDE_DEPTH` (8), so a circle ends. **A warning in the unit-test
binary is logged, never a dialog** (`VC.WarningsHaveNoOperator`, set by
`tr4w_unit_tests.lpr`): before that, a missing include queued a modal and the
first test that pumped messages (StatusAndNotice) hung the suite for ever.
`Lint-DomCoverage` fails a shipped `INCLUDE FILE` naming a file not in
`target\dom`. `uTestShippedDom.LoadShippedDomFollowingIncludes` still RAISES
on a missing file, and an exception escaping a test aborts the whole run.

**THE DUPE KEY IS THE CALL AS LOGGED -- PLUS, WHERE THE CONTEST SAYS SO, WHAT
IT SENT (Q118, 2026-10-17).** `CALL/county` is its own key already (Q73,
`uTestRoverDupeKey`). NY4I: *"New QSO per county"*, then *"All state parties"* --
in every state QSO party the same call on the same band and mode with a
different received QTH is a new QSO. There are two virtuals:
`TContestBase.DupeKeyIncludesReceivedQTH` (base False,
`TContestStateQSOPartyBase` True) and `DupeKeyTour` (base ''; RADIO-YOC names
its 30-minute tour from the QSO's logged time, Q136 2026-10-22, so a repeat in
another tour is a new QSO); the non-virtual `DupeKeyQualifier` derives the
key text from the record (`DomesticQTH`, else `QTHString`, then #1 + the tour). 7QP, NEQP and IN7QPNE
are not on that base and are not covered (open). **A logged QSO's dupe question
is `EditableLog.QSOIsADupe(rx)` and its write is `LOGEDIT.AddQSOToDupeSheets`**
-- LogContact, the loader and the rescore all go through them; never call
`CallsignsList.AddCallsign` or `CallIsADupe` for a logged QSO again, or the
qualified sheet (`uCallsigns.QualifiedDupes`) falls out of step. Clear with
`ClearAllDupeSheets`. **BEFORE THE EXCHANGE EXISTS, THE CALL ALONE (NY4I,
2026-10-18, narrowing Q118):** *"If we consider it a dupe until that second
contact with a new county comes in, that is a reasonable compromise"* -- and
*"It is easier to just work the dupe than argue the point"*: the call-window DUPE
is information, not a gate. WindowDupeCheck, ShowInformation (B4, so AUTO DUPE
CQ), ReturnInSAPOpMode (AUTO DUPE S&P), the inactive-radio dupe panel and every
colour-only site (band map, SCP, spots, WSJT-X, MMTTY) ask `CallIsADupe`, exactly
their pre-Q118 lines. The 2026-10-17 "hint, don't block" layer
(`CallIsADupeBeforeExchange`, `CallWindowIsADupe`, `ShowWorkedFromOtherQTHs`,
`WorkedQualifiers`) is WITHDRAWN and deleted -- do not bring a received-QTH test
back to a pre-exchange site. `QualifiedDupes` is one flat dictionary keyed call +
#0 + QTH. The bit rule both sheets share is `MarkDupeBits` / `DupeBitsSay`.

**Measure before you build a refusal.** FD-DX was recorded "not built" and typed
entry already refused it: a domestic call goes to `FoundDomesticQTH`, and
`arrlsect.dom` has no `DX`. Run the typed text through the matrix's parse section
(a temporary row in `uContestMatrix.MATRIX_PARSE_CASES`, removed before the
freeze) first. **A unit test can drive the REAL parsers too:**
`uTestExchangeWordOrder` / `uTestFieldDaySectionRefusal` call `ParametersOkay`
with a shipped `.dom` loaded -- `uTestExchangeParse` is a STUB of the parsers
and cannot see a defect inside one.

**WORD ORDER (2026-11-04, issues #174/#169/#170).** Sweepstakes reads a
precedence joined to digits, EITHER ORDER, as precedence + SERIAL: `U123`,
`U12`, `A99`, `M43`, `43M` -- NY4I: *"a check would NEVER be entered with the
precedence next to it without a space. The only thing we accept without a
space is the <serial><precedence>."* So `80 WCF U12` reads serial 12, check
80. **A NUMBER TOUCHING A PRECEDENCE IS ALWAYS THE SERIAL, NO EXCEPTION**
(NY4I: *"a99ct would always be serial number 99, so the lone 5 would have to
be a mal-sent check"*; *"check will always be two digits"*). `A99CT 123` is
serial 99 and a bad check, refused `Check must be two digits (123)`
(`SExchangeCheckNotTwoDigits`, from `TSweepstakesFields.BadCheck`). The fold
meets words last first, so a joined word DISPLACES a serial a bare number took
(`NumberFromBareWord`, `TakeJoinedSerial`) -- no pre-pass; the
`SerialElsewhere` one of a few hours was deleted. `123A99CT` keeps D7's serial
123 / check 99 (both touch the letter: flagged to NY4I). **THE CALL CORRECTION
RUNS BEFORE THE CLASS:** `MainUnit.ParametersOkay` (CALLSIGN UPDATE ENABLE on)
takes the LAST word that `LooksLikeACallSign`; if the contest's
`RefusesCallFromExchangeWord` says it is its exchange (SS: precedence +
digits + a SECTION of the dom file -- `A99CT`, `U80WCF`; not `A9XYZ`), the
entry is refused with `SExchangeCallOrExchange` ("enter 99A CT").
`uTestExchangeWordOrder.Test_SweepstakesEveryOrdering` drives every ordering
of 25 token sets through `ParametersOkay`, update on and off, against an
independent two-stage model (set `TR4W_SS_ORDERING_REPORT` to a path to dump
every reading). A check joined to its section (`31CT`) is unchanged as a word. An unknown section
through this parser is refused with NO message (pre-existing, not this
change), and so is a missing serial (`M 31 CT`); a refused entry with NO
check says `SExchangeNoCheck` (`A99CT`, `123 A CT`) and with no section
`SExchangeNoSection` (`A99 32`) -- after the no-precedence and bad-check
reasons, in the class (#174 bench, 2026-11-04). `ParseNameAndDomesticOrDXQTH` (NAQP x3, CWOps, SST, Colorado,
Locust, Minnesota) tries `QTH NAME` only when the name-first reading found no
QTH, the entry is exactly two words, and the first word is a QTH -- `DE CA` is
still Del in California. NA Sprint's `FL TOM 4` was already right: QTH,
domestic QTH and the domestic multiplier (pinned). **AN AMBIGUOUS SS SERIAL
IS REFUSED (NY4I, 2026-11-04):** a standalone precedence word, no word
joining digits to a precedence (`43M`, `U123`, `A99`, `A99CT`), no bare
1/3/4-digit number, and EITHER exactly two bare two-digit numbers OR bare
two-digit numbers plus check-then-section words (`99CT`) coming to exactly
two, where a check-then-section word counts ONLY with a bare two-digit
number typed AFTER it (`A 99CT 32` ambiguous; `42 M W1AW 31CT` and
`32 A 99CT` read in the base order serial-prec-call-check-section, NY4I's
bench) -> `TContestARRLSSBase`
refuses with `SExchangeAmbiguousSerial` ("enter 43M or 31M"), so
`43 M W1AW 31 CT` no longer logs by position. The test is
`uExchangeTokens.SweepstakesSerialIsAmbiguous`, which COUNTS the reading
each word took (`ProcessSweepstakesEntry` returns a `TSweepstakesWordKind`)
-- do not write a second SS word grammar beside it. It runs AFTER the
inherited parse so `aExch` is filled as before (QSL MODE = QSL AND LOG logs
whatever the parse wrote, ignoring the answer).

**The rescore re-derives a record's country ONLY for a contest with a prefix,
zone or DX multiplier** (`MainUnit.RecomputeQSOScoring`). Taking a multiplier away
(Winter FD's DX, Q38) therefore also stops the rescore re-stamping the country --
the record's stored one stands, and anything exported from it (WFD's `DXCC` tag)
follows the stored value.

**A STATED `MY ZONE` IS A CQ ZONE, AND `Station.MyZone` CARRIES IT AS STATED IN
EVERY ZONE MODE (issue #222, 2026-11-05).** Only an UNSTATED zone is derived in
the contest's zone mode, so an ITU-zone rule that compares `Station.MyZone`
works at every matrix station (none states a zone) and is wrong for an operator
who typed `MY ZONE = 5`: IARU scored W1AW (ITU 8, his own ITU zone) 3, not 1.
A rule that needs MY ITU ZONE asks `TContestBase.ScoringMyITUZone` -- the QSO's
recorded `my_itu_zone` (`ScoringMyFacts`) when the row captured its station,
else `Station.MyITUZone`, the session service. ONE engine answer,
`uContestFactory.SessionMyITUZone` (stated MY ITU ZONE, else CTY.DAT's for MY
CALL, else 0), feeds that service, the `my_itu_zone` capture
(`LogStoreCurrentMyFacts`) and `PostUnit.ZoneSentForThisContest` -- so a QSO
scored live (entry scores before the row is written, with no facts) and the same
row rescored later cannot disagree. 0 is unknown and matches no zone.
`TContestBSCI` reads it too since issue #225 (WA7BNM ref 470: "1 point per QSO
with same ITU Zone"; DXLog `BSCC.txt` agrees). **`TContestOZCRZ` STILL reads
`Station.MyZone`, ON PURPOSE**: no sponsor text is readable (none in the tree,
QRZ.RU 182 unreachable, no WA7BNM entry, no DXLog file), so the transcribed D7
rule stands, pinned by `uTestITUZoneContests.Test_OZCRZStillComparesTheStatedMyZone`
until NY4I rules. No other ITU-zone class compares a zone (Croatian, Gagarin,
LZDX score by country/continent; OZCR-O is 1 a QSO); Jock White's
`Station.MyZone` is an NZART branch, not a zone. Every continent/country arm
reads the live `Station.MyContinent`/`MyCountry`; `ScoreQSO` overlays only the
grid from the record.

**THE ZONE A CONTEST SENDS IS ONE RULE (issue #225, 2026-11-06):**
`uContestBase.ZoneTextSent(zones, MyITUZone service, MY ZONE text)` -- the ITU
zone in a `zmzITUZones` contest when it is known, else the MY ZONE text. The
export (`PostUnit.ZoneSentForThisContest`) and FoundContest's default CW
exchange messages (`FCONTEST.SetUpRSTMyZoneExchange`, handed the zone by
`TEngineExchangeMessageWriters`, which holds the contest FoundContest fetched
once) both ask `uContestFactory.SessionZoneTextSent`; a class's
`CQExchangeDefault` asks `TContestBase.SentZoneText(aStation)` (IARU, OZCR-Z,
OZCR-O, LZDX). Before it, a stated CQ `MY ZONE = 5` went on the air as `599 5`
in IARU while the log exported ITU 8. NOTE the writers overwrite the CQ/S&P
exchanges unconditionally at FoundContest's foot, so `CQExchangeDefault` only
fills what is still empty afterwards. **Still open:** WRTC sends a zone
(`WriteRSTStateOrZone`) but is `NoZoneMults`, so it sends and exports the MY
ZONE text (a CQ zone when stated) inside IARU HF.

## `FoundContest` READS STATION STATE, so what it reads must already be set

**`MY COUNTRY` IS DERIVED — do not "add" a derivation.** `FoundContest` calls
`RecalculateMyCountryContinentAndZoneNew(Settings.My.Call)` before its
`case Contest of`, and `TMySettings.DeriveCountry` writes without latching
`CountryWasSet`, so a stated value always wins and a derived one is recomputed
each run. **Never persist a derived value**: it reads back as stated and
permanently blocks re-derivation — that is the defect `DeriveCountry` exists to
fix (a latched derivation once exported `59 15` against zone 5).

**`FoundContest`'s HEAD READS THE CONTEST CLASS, NOT THE ARRAYS (M2,
2026-10-01).** One resolver, `ApplyContestTraits`, writes the session's
kinds (`ContestSession`, below -- the `Active*` globals until M10 S9), the
by-band/mode flags and the CTY zone list: the operator's
statement, else `ContestIdentity(Contest)`. A statement made BEFORE the
`CONTEST` line now stands (it used to be overwritten); what a contest states
in its `DescribeSession` (M7a -- every contest that has a class; a classless
contest's arm otherwise) still runs after the head and still overwrites. Three defects went with it:
**no station was ever in state for a QSO party** (`'DOM'` + name, no
separator -- now `uAppPaths.ShippedDomFilePath`, shared with `LogCfg` and
`logdom`'s INCLUDE), **`CTY.ctyZoneMode` was 255** for every contest without
the CQ bit (a Boolean cast; now `TContestBase.ZoneMode`, ITU unless the bit is
set, as in D7 -- so MY ZONE derives an ITU zone where it read 0), and **NEQP
crashed** on an empty MY STATE (a `PWORD` read of a UnicodeString). Design doc
§7.9 / §8.2c. **`nc_cty.dom` holds provinces, DC and the states, not only
NC's counties** -- a Canadian or DC station is now "in state" for NC (Q14,
NY4I's call).

**THE ORDER THE SETTINGS ARRIVE IN IS PART OF THE CONTEST'S CORRECTNESS.**
`ARRLDXCW/ARRLDXSSB` branches on `Settings.My.Country = 'K' or 'VE'` to choose
between a power exchange and a domestic-QTH exchange. Until 2026-09-20
`LogStoreApplyContestConfig` applied `CONTEST` first (whose effect runs
`FoundContest`) and the config rows after — unordered — so on a log opened from
its `.db` the country was derived from an **empty** `MY CALL` and the exchange
decision was taken from it. The re-derivation at the foot of that routine fixes
the country and **cannot retract the decision**. `MY CALL` is now hoisted ahead
of `CONTEST`. Bench symptom: ARRL DX SSB rejected `K` (a kilowatt) from an
Italian station as an "Improper domestic QTH".

**A CONTEST-SCOPED SETTING HOLDS A NAME, NEVER A RESOLVED PATH** — those rows are
captured into the contest `.db` and re-applied on every open, so a path pins a
log to one machine and one install. `DOMESTIC FILENAME` held a full path and
`FoundContest` APPENDED to it, producing
`<run N>/dom\<stored path from run N-1>`; under an AppImage, whose mount point is
new every launch, that broke on the second run. `FoundContest` is idempotent for
it now and `TContestSettings.SetDomesticFilename` reduces any path to its name,
which also heals existing logs.

## Oracles

```bash
bash tr4w/test/corpus/export-d12-corpus.sh        # 24/0/2 AND exit 0
bash tr4w/test/corpus/test-contest-factory.sh     # scoring
bash tr4w/test/contest-matrix/run-contest-matrix.sh  # every ContestType, classless included
```

Rebuild the app first; confirm TR4W is not running. Run, read, **then** commit —
never in one shell block.

`tr4w/test/logdump/` dumps binary `.dat` logs to JSONL through the canonical
`ContestExchange`, and `tr4w/test/python/verify_adif_export.py` cross-checks ADIF
against it.

## Where this engine's rules are going

Each rule moves into the contest's own class, which **owns** it outright (NY4I,
2026-10-01; `docs/CONTEST_OWNERSHIP_DESIGN.md`). It does **not** move into
shared point-method, exchange or multiplier strategies.
`docs/QSO_POINT_METHOD_DESIGN.md` is SUPERSEDED.

**For a contest WITH a class, `logstuff.CalculateQSOPoints` hands over FIRST**
to the class's `ScoreQSO` (M3, 2026-10-01), which runs the band check and the
four `QSO POINTS ...` overrides itself. Below that line the routine is the
classless path only -- DUMMYCONTEST, the one `ContestType` without a class:
the same `uContestBase.ApplyQSOPointOverride`, then 0. **The legacy
`case ActiveQSOPointMethod` is DELETED (M10 S3, 2026-10-14)**, with every
locally-unused unit it pulled in; its arms live on in their classes, in git
history and in the D7 tree. Do not add a band check, an override or a rule
there for a classed contest -- it would never run. **`QSO POINT METHOD` is retired
(M10 S2, 2026-10-14)** -- a name in `uCFG.RETIRED_COMMANDS`, no effect -- and
**the point method is gone as a concept (M10 S4, 2026-10-14)**:
`QSOPointMethodType`, the row's `QP` column, the class trait and
`ActiveQSOPointMethod` are deleted.

**Dupe marking no longer reads the point method** -- `logsubs2` asks
`ContestIdentity(Contest).MarksDupes`. **Nor does exchange parsing (M5b,
2026-10-02):** RAC, PCC and Arktika's branches and RussianDX's initial
exchange are their classes' own now. **Nor does the final score (M6,
2026-10-02)**: `logedit.TotalScore`'s five point-method formulas are their
contests' `CombineWithMultipliers` -- nine of those contests gained classes for
it. **`ActiveQSOPointMethod` itself is DELETED** (M10 S4) -- it had no reader
left after S3.

**`TotalScore` IS ONE FUNCTION AND ASKS THE CONTEST (M6).** It gathers a
`TScoreTotals` (`uScoreTotals.GatherScoreTotals`: stored points, QTCs, the
sheet's multiplier and QSO counts, the scored band, the session's facts) and
asks `FinalScore(totals, view)` = `CombineScore` + `BonusPoints`, the view a
read-only `TLoggedQSOView` of the log, kept in memory beside the totals
(`uScoreTotals`: emptied in `DisposeOfMemoryAndZeroTotals`, filled in
`LoadinLog` and `LogContact` -- a per-score database read was measured at
~130 us a row). Every reader of the score
-- display, summary, Cabrillo `CLAIMED-SCORE`, XML report, both posting
clients -- reads `TotalScore`. **Do not put a formula or a bonus back in it.**
The one contest still named there, with its reason: RSGB 1.8 MHz, whose
per-QSO arm reads the multiplier sheet (`mo.isdmmult`), which no class can be
handed (design Q33). Off the main thread `TotalScore` returns the last
main-thread score: the final score reads SQLite and `ActiveContest`, and the
posting clients run on worker threads. **No bonus is counted as QSOs are
logged (Q32, built 2026-10-17):** Missouri's peak-hour bonus is its
`BonusPoints` over the view, from each QSO's logged time and band, valid QSOs
only, capped at 250 -- `TalliesLiveQSO` and `LOGDUPE.LiveSessionTally`, the
live-only tally a reopened log lost, are deleted. Do not bring a session
count back. `LoadinLog`, the view and the summary sheet
(`postunit.TallySummaryTotals`, 2026-10-17 -- it had counted flagged X-QSOs)
share one predicate, `uContestBase.QSOCountsTowardTotals`; never re-test the
record kind, deleted or `ceXQSO` beside it. A rescored X-QSO keeps no points,
dupe or multiplier flag (`uContestBase.ClearXQSOScoring`, Q51), and the
four-flag clear is ONE routine, `ClearMultiplierFlags`. **A malformed grid is never measured
(Q37, built 2026-10-17):** `uGridShape.IsGoodLookingGrid` (Tree's
`GoodLookingGrid` rule, lifted -- the predicate the grid parsers refuse a typed
grid by) gates LOGGRID's distance (0), heading (-1) and lat/lon; it read past
the end of a short grid and followed the heap. ALRS's log of 0 is guarded in
its class. Not built: the ADIF import refusal (no per-contest "which field is
my grid" answer, and ARRL Digi imports into `DomesticQTH` while it scores
`QTHString`), and RTC's `GridHaversineKm`, which was already bounded.

**`ProcessExchange` ASKS THE CONTEST (M5b).** It keeps the contest-blind
tokenising gate (`ParseArray`), then calls
`ExchangeContest.ParseReceivedExchange` (the active contest's object, else its
identity -- never nil) with a `TReceivedExchangeSession`: the engine's parsers
(`Parsers`, a `uContestBase.TExchangeParsers` -- one named method per format,
LOGSTUFF's `TEngineExchangeParsers`), `ExchangeFormatOf` (nil from the engine;
IN7QPNE alone sets it, so its judging party's rules judge IN7QPNE's format),
and engine services (`ZoneOfCall`, `IsDomesticQTH`, `CallWindowHasCall`,
`AbandonEntry`). **THE PARSER MACHINE IS GONE (M11 S9d, 2026-10-15)**:
`ParseExchangeShape`, the `case` over the kind, became those 51 named methods
(its five unreached arms and the four parsers only they called are deleted),
and every registered contest states `ParseReceivedExchangeFormat` (184
overrides; the base parses nothing and answers False, DUMMYCONTEST's answer).
A FORMAT goes there; a RULE goes on `ParseReceivedExchange`, around it, calling
`inherited` or a parser by name. **Do not put a contest test back inside an
engine parser, and do not add a kind parameter to the seam.** No parser names a
contest any more (the UA4W Championship's QTH-is-domestic rule is its class's,
2026-10-14). `ValidClass` and the Field Day DX check ask the contest with no fallback (D1/D2
deleted). Word cutting a class also needs (`ParseExchange`, `ProcessSSEntry`,
the single-word test) is LIFTED to `uExchangeTokens` and called by both.
**Two refusals NY4I ruled (design 7.10)**: Sweepstakes without a precedence
says so; a state party's out-of-state station working a non-host station is
refused. **Every improper-domestic-QTH refusal goes through ONE routine,
`LOGSTUFF.RefuseDomesticQTH` (2026-10-23)**, the Field Days' "Invalid ARRL
Section" (`TC_INVALIDARRLSECTION`, a stem like the others) included: the historical stem plus one brief
reason on screen ("(CT: work GA stations only)", "(X not in <file>.dom)",
"(no QTH)", "(MY COUNTRY is empty)"), the full sentence in the log; wording in
`uContestReadiness.DomesticQTHRefusalReason`. Do not write a refusal message at
a parse site. The matrix's `parse` section sees all of it; nothing sees the window
(`BENCH_QUEUE.md`). **Since Q107 (2026-10-16) the host-area refusal is also
SCORING**: a logged out-of-area x non-host QSO (import, peer, rescore) scores
0 and earns no multiplier, through the class's `CreditsWorkedStation` --
`ScoreQSO` asks it after the band, `SetMultFlags` exits on it after its band
exit. Both sides call `uContestBase.HostAreaRuleCredits` with the record's
`QTHString` and the engine's table, `LOGDUPE.DomesticTableKnowsQTH` (moved
from LOGSTUFF's `ParseSessionIsDomesticQTH`; handed to the typed session AND
to `TStationContext.IsDomesticQTH`). The rescore (`RecomputeQSOScoring`)
reaches it with no extra code: it reads no stored flag or points. Note that
`DomesticTableKnowsQTH` -> `GetDomQTH` calls `ActiveContest` itself, so it
re-stamps the active object's station from inside that object's scoring --
benign (same values), but it costs a `CurrentStation` per call.

**THE SHEET KEEPS THE STATE; THE CONTEST DECLARES THE RULES (M8,
2026-10-02, ownership doc §8.2l).** `logdupe.SetMultFlags` names no contest:
after the band question it asks `ContestCountsMultiplier(ActiveContest(Contest),
RXData, kind)` per kind -- the class's `CountsAsMultiplier` (BC/NY/Indiana
`DX`, the PCC's own-country prefix, the Jock White own branch and branch 00)
-- and only then the sheet whether the multiplier is NEW. The need-multiplier
hint's call-to-domestic-multiplier (`LogEdit.GetMultArray`) is the class's
`DomesticMultiplierFromCall`, handed the engine's lookups. **Do not put a
contest test back in the sheet.** **`SetPrefix` IS NO LONGER A KIND ARM
(M11 S3 part 1, 2026-10-14):** it asks the class's `PrefixMultiplierKey`
through `ContestPrefixMultiplierKey(ActiveContest(Contest), ...)`, once per
QSO, and assigns only on True (False leaves a stored prefix alone -- the
rescore depends on it). ZoneCont's three prefix computations are the leaf
`uPrefixMultiplierKey` now. **`PrefixMultType` IS DELETED (M11 S3 part 2,
2026-10-14)** -- enum, trait, session field, `WritePrefixMult`, the
`DescribeSession` statements and the matrix's `active.prefixmult` line.
Whether a contest has a prefix multiplier at all is the class's
`HasPrefixMultiplier` (base False), asked as `LOGEDIT.DoingPrefixMults`
(`ContestHasPrefixMultiplier(ActiveContest(Contest))`) or, where the
object is in hand, `ContestHasPrefixMultiplier(obj)`: live against
`Station`, like the key, so F20 is closed. Do not bring back a stored
"doing prefix" flag. **`GetDXQTH` IS NO LONGER A KIND ARM EITHER (M11 S4
part 1, 2026-10-14):** `GetDXQTH(aContest, var RXData)` keeps its ENGINE head
(COUNT DOMESTIC COUNTRIES, the WYSIWYG domestic QTH, the domestic-country
call) and then asks the class's `DXMultiplierKey` through
`ContestDXMultiplierKey`, assigning only on True. **It takes the contest
OBJECT, never fetches it:** every caller already asks the contest something
else for the same QSO, so it fetches `ActiveContest(Contest)` ONCE and passes
it -- `LOGEDIT.SetDXQTHAndPrefix` (the entry paths: `ParametersOkay`'s two
exits, WSJT-X), `SetPrefix(aContest, ...)`, the rescore
(`RecomputeQSOScoring`) and the hint (`GetMultArray`). Do not add a call that
fetches it again: `ActiveContest` rebuilds the station each time. The CTY
country list is the class's `CountryMode` (asked by `uSettingsEffects`
straight after FoundContest) and the remaining-mults window's filter its
`ListsRemainingDXCountry` (`mo.FillVisibleBytes(aContest)`), which reproduces
the window's old filters ONLY (F7). **`DXMultType` IS DELETED (M11 S4
part 2, 2026-10-14)** -- enum, trait, session field, `WriteDXMult`,
`TSessionDefaults.DXMult`, `TScoreTotals.SessionDXMult`, the
`DescribeSession` statements and the matrix's `active.dxmult` line.
`CountryModeType` stays: the ARRL/CQ list is data. Whether a contest has a
DX multiplier at all is the class's `HasDXMultiplier` (base False), asked
as `LOGEDIT.DoingDXMults` or, where the object is in hand (`SetMultFlags`,
the rescore, `SetDXQTHAndPrefix`, `GetMultArray`, `FillVisibleBytes`),
`ContestHasDXMultiplier(obj)`: live against `Station`, like the key, so F21
is closed. Where the entrant decides, it is the SAME private predicate the
key and the list ask. "Counts any multiplier" is ONE function,
`LOGEDIT.DoingAnyMults(aContest)` (the score's totals and the WSJT-X decode
gate), fetching the contest at most once. Do not bring back a stored "doing
DX" flag. `LOGDUPE.GetNumber` went with the PACC arm, to
`uContestPACC.PACCCallAreaDigit` -- not the same routine as
`uCallSignRoutines.GetNumber`. **THE ZONE KIND'S RULES ARE THE CLASS'S TOO
(M11 S5 part 1, 2026-10-14):** the zone count (LOGDUPE), the zone list (the
hint, the ITU initial zone, `ZoneSentForThisContest(aContest)`, the ADIF
CQZ/ITUZ tag) and zero-based numbering (the zone window) ask
`ContestZoneMultiplierCount` / `ContestZoneMultiplierZones` /
`ContestNumbersZonesFromZero` -- the per-QSO site passing the object it
holds. **`ZoneMultType` IS DELETED (M11 S5 part 2, 2026-10-14)** -- enum,
trait, session field, `WriteZoneMult`, `svZoneMult`, JIDX's two
`DescribeSession` statements and the matrix's `active.zonemult` line.
Whether a contest has a zone multiplier at all is the class's
`HasZoneMultiplier` (base False; True exactly where `ZoneMultiplierCount`
is above 0 -- pinned), asked as `LOGEDIT.DoingZoneMults` or, where the
object is in hand (`SetMultFlags`, the rescore, `GetMultArray`, the ADIF
tail, `SetUpRemainingMultiplierArrays`), `ContestHasZoneMultiplier(obj)`:
live against `Station`. JIDX asks `IsJapaneseEntrant`, the predicate its
zone and DX answers ask. Do not bring back a stored "doing zone" flag.
`ZoneModeType` / `cfCQZoneMode` STAY -- the CTY lookup's zone system.
**Never answer the
zone LIST from `ZoneMode` or the reverse** -- the Croatian counts ITU zones
over a CQ zone mode, CW Open the inverse (F5, Q95 open, pinned in
`uTestZoneMultiplier`). LOGSTUFF's EUHFC range arm was vacuous and is gone;
so are its dead JAPrefectures arms. **The TRMASTER initial zone
(`InitialExchangeEntry`) asks `ActiveContest` like every other zone reader
(M11 S5 part 2).** It asked `ContestIdentity` at part 1 because of plan
F22: `LOGSCP.BestTwoLetters` never assigned the slot of the `JA` pair it
skips, so whether a call containing `JA` was FOUND in TRMASTER depended on
stack residue from the previous lookup, and an `ActiveContest` call between
lookups moved three matrix records (Croatian, IRTS, WRTC `iex JA1ABC`).
**F22 IS FIXED (2026-10-14)**: the routine zeroes its array on entry, and
the switch moved no matrix record. The choice is
`uContestBase.InitialZoneFromCallHistory`. **THE DOMESTIC QTH'S SHAPE IS
THE CLASS'S (M11 S6 part 1, first half, 2026-10-14):** `LOGDOM.GetDomQTH`
keeps its engine head (outputs zeroed, `strU`, the `DoingDomesticMults`
exit) and the domestic-FILE lookup, and between them asks
`ContestDomesticMultiplierFromQTH(ActiveContest(Contest), ...)` -- ONE fetch,
after the exit, because its ~50 callers (the parse shapes) hold no contest.
`dqaDecided` ends it; `dqaLookUpDomesticFile` runs the file lookup WITH
whatever the rule wrote (the RSGB IOTA's fall-through, F6, kept exactly).
`LOGSTUFF.DomStringParse` is `strU` + `ContestDomesticMultiplierHint`.
`= GridSquares` (CallIsADupe -- ROVER TEST FIRST, the rescore asks it per
QSO --, ShowPartialCallMults, LogContact once per QSO,
DisplayGridSquareStatus), `= GridFields` (`uMults.IsDmMult`'s new
`aKeyedOnGridField`, uWSJTX, the factory's sheet service -- which asks
`GActive`, not `ActiveContest`, because it runs inside the active object's
scoring), `= WYSIWYGDomestic` (GetDXQTH, on the object handed in) and
`<> RDADistrict` (the ADIF tail, on its `contestRules`) are class answers.
`GetContinentFromString` moved, unchanged, from ZoneCont to `utils_text`.
**THE DOMESTIC FILE IS THE CLASS'S ANSWER (M11 S6 part 1b):**
`LogContact`'s mobile call/QTH rewrite asks `ContestUsesDomesticFile` of the
contest it fetches once per QSO (shared with the grid-square rover tests);
`uContestReadiness.CollectContestSettingsGaps` takes `aUsesDomesticFile`;
`TADIFImportSession.DomesticMult` is `CountsGridSquares`, filled by
`ParseADIFRecord` from the open contest's `HasGridSquareMultiplier`.
**`DomesticMultType` IS DELETED (M11 S6 part 2, 2026-10-14)**, and with it
the LAST multiplier kind: "does it count a domestic multiplier" is
`TContestBase.HasDomesticMultiplier`, composed in the base from
`UsesDomesticFile` and the four shape answers (the RSGB IOTA, WAG and the
DARC 10 m override it), asked as `LOGEDIT.DoingDomesticMults` or, where the
object is in hand, `ContestHasDomesticMultiplier(obj)` -- `SetMultFlags`,
`LogContact`, the hint (`GetMultArray`), the Cabrillo writer
(`stationContest`) and the ADIF import (one fetch per record for both its
answers). **`GetDomQTH` fetches the contest ONCE, at its head, for the
no-domestic exit and the rule** -- a contest with no domestic multiplier
pays one `ActiveContest` per domestic-QTH lookup where the session field
cost nothing; the rescore reaches it only for a slash call under a QSO-party
exchange. `LOGEDIT.DoingAnyMults` fetches once for all four answers.
`BuildLogRow`'s QTH column and the exchange window ask
`DoingDomesticMults` (a fetch per row built / per keystroke). **`UsesBand` is asked at four places now** -- points,
multipliers, `TCallsignsList.AddCallsign`/`CallsignIsDupe` (an off-band QSO
marks no dupe bit and is never a dupe; the M3-found `AllBands` gap is FIXED),
and the hint (`DetermineIfNewMult`, `uContestBase.CreditedBands`).
`EditableLog.CallIsADupe` no longer pre-translates the band and mode -- a copy
of what `CallsignIsDupe` does, which hid the real band from the question.
`DetermineIfNewDomesticMult` asked with `AllBands` answers for `ActiveBand`
(it had said "not needed" for every Idaho county). RSGB 1.8 MHz is still
classless: its points read the sheet (`mo.isdmmult`), Q33.

**Its spelling table WAS rotated** -- `QSOPointMethodArray` selected the wrong
method for 46 spellings, a D7 defect -- **and is DELETED at M10 S2** with the
setting. The one `.cfg` it reached, `target/dom/Idaho QSO Party.cfg`
(never shipped, and deleted 2026-10-15 -- `target/dom` is `.dom` only), had
stopped naming a point method: Idaho is
`IDAHOQSOPARTY` with its own class since 2026-10-01 (ownership doc §7.2). **No
`.cfg` borrows another contest's type** -- an event is a `ContestType` and a
class.

**THE SESSION'S KINDS LIVE IN ONE OBJECT, ONE AT A TIME (M10 S9a,
2026-10-14).** `uContestSession.ContestSession` -- a `TContestSession`
created once in that leaf unit's initialization, never replaced, read-only
properties, written ONLY by FCONTEST's set-up path (`ApplyContestTraits`,
then `ApplySessionDefaults`) through `Write*` methods -- not `Set*`, which
`TSessionDefaults` already uses for what a contest STATES. Main thread only,
as the globals were. **It holds two kinds -- `Exchange` and
`InitialExchange`** (`PrefixMult` was deleted at M11 S3 part 2, `DXMult`
at M11 S4 part 2, `ZoneMult` at M11 S5 part 2, `DomesticMult` at M11 S6
part 2 -- no multiplier kind is left)
(were `LOGWIND.ActiveExchange`, `ActiveInitialExchange`,
`ActivePrefixMult`, `ActiveZoneMult`, `VC.ActiveDXMult`,
`LOGDOM.ActiveDomesticMult`; S9a-f). **No `Active*` kind global is left --
M10 IS COMPLETE (2026-10-14).** Do not add one back: a new reader asks
`ContestSession`, a new writer does not exist. `ContestSession.Exchange`'s
zero is `UnknownExchange` (the global's `= NoExchangeReceived` initializer
was commented out). ~~`tree.LooksLikeAGrid` reads it once per log row per
repaint~~ -- it never ran per row (plan F33), and since M11 S9e part 1 it
asks the contest (below); its contest question still comes first, ahead of
any string work. **What M11 inherits:** the two EXCHANGE kind enums
(`ExchangeType`, `InitialExchangeType`; S3-S6 deleted the four multiplier
kinds) and their engine arms -- the four exchange-shape machines (parser,
field list, ADIF, Cabrillo), the compare sites (S7) and the initial
exchange (S8, Q50) -- every one reading `ContestSession`. **S7 IS DONE
(2026-10-14): the compare sites that decided a RULE ask the contest** --
the rover county (`StripsRoverCountyFromCall`, both MainUnit routines; the
rescore and the ADIF parse pass the object they hold), several QTHs in one
S&P entry (`LogsSeveralQTHsFromOneEntry`), a blank exchange
(`AcceptsBlankExchange`, ParametersOkay and ProcessExchange -- one
`ExchangeContest` fetch, after `ParseArray` as before), the park lookup
(`OffersParkTools`), CQ WW RTTY's state after the zone
(`SendsStateAfterZone`, which the zone classes now pass to the message
writer themselves)
and FISTS's points-alone (its own `CombineWithMultipliers`;
`TScoreTotals.SessionExchange` is deleted). `ProcessReturn`'s split into
the `s1..s4` globals was deleted: its only reader re-splits first. **Still
reading the shape after S9e part 1 (21 reads in 3 files, plan "WHAT S8 +
S9e PART 2 DELETE"): the history renders (LOGEDIT's `InitialExchangeEntry`
15, LOGDUPE's `GetInitialExchangeStringFromContestExchange` 5 -- S8/Q50)
and the matrix's `active.exchange` line.** Do not add a new rule test of
`ContestSession.Exchange`; add a class answer. **S9e PART 1 IS DONE
(2026-10-15):** `SetColumnsWidth`'s SS columns ask the field list
(`uExchangeFields.ExchangeFieldsShowPrecedenceColumn` = precedence AND
check, so ALL JA still shows none; `...ShowCheckColumn`; F15/F15a);
LOGDUPE's dead FISTS log-line parse and its dead chain (`LogBackCopy`,
`PushLogStringIntoEditableLogAndLogPopedQSO`, `PutContactIntoLogFile`,
LOGSTUFF's `ProcessPartialCallAndInitialExchange`) are DELETED (F29);
**FoundContest's sent-message `case` is the contest's
`WriteDefaultExchangeMessages(aMessages: TExchangeMessageWriters)`** (F30):
five named writers (`WriteNameAndState`, `WriteRSTQSONumber`,
`WriteRSTStateOrQSONumber`, `WriteRSTZone`, `WriteRSTStateOrZone`)
implemented by FCONTEST's `TEngineExchangeMessageWriters`, the S9d
technique; asked of `ActiveContest(Contest)` at FoundContest's foot; the
base writes none; 92 overrides; `SuppressZoneExchangeMessages` is deleted
(the JIDX simply write none); and **`TREE.LooksLikeAGrid` asks
`ContestIdentity(Contest).ExchangeTextMayHoldGridSquare`** (18 contests;
`uGridShape.GRID_CARRYING_EXCHANGES` is deleted). That one asks the
IDENTITY on purpose -- a class ANSWER no station decides, pinned
station-independent by `uTestExchangeKindReaders`, with no station rebuild
per call; it is not a repointed kind read, and a class that ever answers
it from `Station` must move it to `ActiveContest`. The tree now has FOUR
grid answers that disagree (F28/F34). **S9 MOVES THE FOUR MACHINES
ONE PER STAGE (Q92, NY4I option 2): each becomes NAMED HELPERS the class's
own override CALLS -- no enum selects one.** **S9a IS DONE (2026-10-14): THE
FIELD LIST.** `LOGDUPE.SetUpExchangeInformation` is DELETED; every
registered contest states `GetReceivedExchangeFields` (public property
`ReceivedExchangeFields`), calling the `uExchangeFields` helper named for
the fields it marks (one helper per FIELD SET -- 28 with the empty one --
not per shape, since the machine's arms already grouped shapes by set).
The base marks NOTHING, so a new contest that forgets it is silently
fieldless -- the UA4W Championship is, transcribed (plan F24). Where the
station decides the exchange (ARRL DX on its base, ARRL 160, JIDX x2, 7QP,
NEQP, Arizona, Texas, the Salmon Run) the override tests the same `Station`
predicate as its other answers. `uProgramMain` assigns
`LOGDUPE.ExchangeInformation := ContestReceivedExchangeFields(
ActiveContest(Contest))` once, as before; the matrix prints it through
`uExchangeFields.ExchangeFieldsText`. Pinned by `uTestExchangeFields`
(every ContestType at seven stations, and a frozen copy of the machine as
the cross-check until S9's deletion stage). **S9b IS DONE (2026-10-14): THE
ADIF `STX_STRING`.** `uADIFExchange.FormatADIFExchangeOfKind` is DELETED;
every registered contest states `GetADIFSentExchange` (public non-virtual
caller `FormatADIFSentExchange(aMy, aQso)` -- the kind parameter is gone from
it and from `EmitADIFExchangeFields`), calling one of 24 `uADIFExchange`
helpers named for what they print (one per OUTPUT: the RST-and-state layout
served five arms). The base RAISES (no placeholder string exists any more), so
a new contest that forgets it exports NO `STX_STRING` and logs an Error per QSO
plus one warning per export (F25 fixed, F26 reported, 2026-10-14; the Cup RF x3,
CQ WW RTTY and the Youth Championship RF now export what their Cabrillo sent
column prints). The ADIF import's kind test became the open
contest's `ReceivesGridSquareExchange`. Pinned by `uTestADIFSentExchange`.
**S9c IS DONE (2026-10-14): THE CABRILLO COLUMNS** -- each contest states
`GetCabrilloSentExchange` / `GetCabrilloReceivedExchange`, calling
`uCabrilloExchange` helpers; pinned by `uTestCabrilloColumns`.
**S9d IS DONE (2026-10-15): THE PARSER.** `LOGSTUFF.ParseExchangeShape` is
DELETED: its 51 reached arms are the named methods of
`uContestBase.TExchangeParsers` (LOGSTUFF's `TEngineExchangeParsers`, one
instance, made in LOGSTUFF's `initialization`), and every registered contest
states `ParseReceivedExchangeFormat` -- 171 call one parser, 11 test the
station with their field list's predicate, Arktika Spring and the PCC choose
by the text (their `ParseReceivedExchange` overrides are gone). The session
carries `Parsers` and `ExchangeFormatOf`, no kind. The other parse/entry-path
kind readers are class answers: `ExchangeCarriesDomesticQTH` (the readiness
MY STATE rule and LOGSTUFF's improper-QTH attribution), `ExchangeCarriesZone`,
`ExchangeCarriesGridSquare` (the readiness rules; `uContestReadiness` takes
booleans and its three kind sets are deleted -- transcribed, not judged, F28:
the tree has three grid sets that disagree) and `PerQSOExchangeLeadsWithSerial`
(`MainUnit.PerQSOExchString`). Pinned by `uTestExchangeParse` (every ContestType
at seven stations x 66 typed rows through a stub of the parsers,
`uTestExchangeParserStub`, shared with `uTestContestParse` and the Delaware and
IN7QPNE tests). **IN7QPNE's trap (F31):** its party parsed in IN7QPNE's
KIND because the session carried it; `ExchangeFormatOf` keeps that.
**The CTY country list (`ctyCountryMode`) is set in the
CONTEST setting's effect, straight after `FoundContest` returns** (plan F5)
-- from the contest's `CountryMode` (`ContestCountryMode(ActiveContest(
Contest))`) since M11 S4, from `ContestSession.DXMult` before -- its only
live caller, so the order is right; a new caller of `FoundContest` must set
it too.
**Never repoint a kind reader to `ContestIdentity(Contest)`** (a class
ANSWER pinned station-independent, like the grid one above, is not a kind
read): the kind is the SESSION's value, and 24 contests run a kind their trait does not state at a
matrix station, 32 at some station (M11 S2; counted with the prefix, DX
and zone kinds, all since deleted) -- JIDX CW: trait
`NoInitialExchange`, a JA station runs `ZoneInitialExchange`;
ARRL DX CW: trait `RSTPowerExchange`, a DL station runs
`RSTDomesticQTHExchange`. (OK/OM DX's domestic kind was the third example;
it is the class's `UsesDomesticFile` since M11 S6.)
**One statement per kind per class (M11 S2):** a kind a class runs at EVERY
station is its trait, never an unconditional `DescribeSession` restatement --
KCJ, YBDX, ARRL 10 and Field Day were aligned that way, and 12 restatements
deleted. `DescribeSession` states a kind only where the STATION decides it.
**ALL FOUR `Doing*Mults` ARE THE CONTEST'S ANSWERS (M11 S2-S6, plan F9):**
the LOGDUPE globals LogCfg set once at start-up are gone, because a peer's
CONTEST line (`uSettingsEffects` -> `FoundContest`) left them describing the
previous contest; M11 S2 made them session answers computed from the
kinds, and S3-S6 part 2 made each the contest's own (`LOGEDIT.Doing*Mults`,
`TContestBase.Has*Multiplier`), live against the station -- no store
anywhere to go stale. Do not bring one back. Pinned by
`uTestContestKindPin.Test_DoingFlagsFollowEveryContestSwitch` (S0d's CQ WW
-> ARRL SS pair) and the four `uTest*Multiplier*` units.
**Still once-only after a run-time switch (F19):** what start-up derived
FROM them -- `NumberDifferentMults`, `RemainingMultDisplay`,
`Sheet.SheetInitAndLoad` (LogCfg) and the `ExchangeInformation`
assignment (the contest's `ReceivedExchangeFields` since M11 S9a) /
`SetColumnsWidth` (`uProgramMain`). **A parse rule does not test the
session's shape (M11 S2, F11), and since S9d cannot:** the session carries
no kind. A rule that depends on the station or the text tests those, as the
format overrides do. **`ZoneSentForThisContest`
and the ADIF CQZ/ITUZ tag have ONE source** -- the session since S9c (plan
F4), the contest's `ZoneMultiplierZones` since M11 S5 (and whether it
has a zone multiplier at all, `ContestHasZoneMultiplier`, on the same
object); keep them on one. **`trdos/logddx.pas` is compiled by
NOTHING** (it uses a `Country9` that never existed; plan F14): an edit
there passes every build, so do not count a repoint in it as verified -- it
still names `ActiveExchange` 26 times, untouched by NY4I's decision (Q91).
~~`logdupe.SetUpExchangeInformation`'s parameter is `aExchangeKind`~~ -- the
routine is deleted (M11 S9a), and `scan.py`'s `KIND_PARAMETERS` is empty.
**Moving a kind? Add it to `tools/contest-rules-inventory/scan.py`'s
`SESSION` map in the same commit**, or its shape-4 rows vanish from the
inventory in silence.

## The three dupe/multiplier stores are classes (pointer audit P8, 2026-10-17)

`uMults.mo` (`TMultsObject`), its `PrfList`/`DomList` (`TSortedStringList`)
and `uCallsigns.CallsignsList` (`TCallsignsList`) are classes over
`TObjectList`s, created in their units' `initialization` and freed at
`finalization`; a test makes its own with `Create`/`Free`, never
`FillChar` + `Init`. Nobody reaches their storage: ask `AltName[]`,
`Dupes[]`, `Get`, `Count`. **A `TDupesArray` stops at `NoMode`, so any
mode that indexes one goes through `uSortedStringList.DupeSlot`** (FM ->
Phone) -- `AddCallsign` indexed it with FM until P8 and wrote into the
entry's CALL, reached by the rescore, which passes a record's stored mode.
Pinned by `uTestSortedStringList` and `uTestCallsignsList`.

**A ZONE IS STORED, LISTED AND COLOURED AT ITS OWN NUMBER (issue 267,
2026-11-10).** The remaining-zones walk is `mo.RemainingZoneIndices(count,
fromZero, includeWorked, band, mode)`: 0..count-1 for a contest that
`NumbersZonesFromZero` (EUHFC/KVP years 00..99), else 1..count, asking and
listing the SAME index. `ShowRemMultsInWindow` used to ask zone i and list
i - 1 (D7), so erase mode hid each year by the next year's cell. Pinned in
`uTestMults`. **A refused RST-and-zone entry leaves `Zone` untouched**
(`ProcessRSTAndZoneExchange`, in LOGSTUFF's interface for
`uTestZoneEntryRefusal`), and in CQ zone mode it refuses every zone above
40 -- 50..59 used to pass (NY4I: "there are only 40 CQ zones"). Its sibling `ProcessRSTZoneAndPossibleDomesticQTHExchange`
still writes before refusing (open).

## The sheet also COUNTS each multiplier's workings (issue 12, 2026-11-07)

The bits in `mo` say worked-or-not and are set by the FIRST working only (a
flag is set by `SetMultFlags` only when the multiplier is new). The band map's
red / orange / no `M` needs how many times, so `mo` also holds a dictionary,
`mo.CountWorked` / `mo.WorkedCount`, keyed (kind, multiplier -- case-blind, ten
characters, as `TSortedStringList` compares --, band key, mode key). **Written
ONLY by `LOGDUPE.CountWorkedMultipliers`, from `AddQSOToSheets`** (live, loader
and rescore all reach it, in log order), skipping `ceDupe` and
`ceClearMultSheet`; **emptied by `mo.ClearAllMults`** with the bits. A delete is
a reload (`LoadinLog` / `RescoreLog` -> `DisposeOfMemoryAndZeroTotals`), so there
is no decrement. **The credit chain is ONE function,
`LOGDUPE.MultiplierKindsCredited`** (X-QSO, band, `CreditsWorkedStation`, and per
kind key + `Has*Multiplier` + `CountsAsMultiplier`), lifted out of `SetMultFlags`
so the count and the flags cannot disagree; **the band/mode key is ONE pair,
`MultiplierSheetBand` / `MultiplierSheetMode`** (the `dmbbAllBand` overrides
included), used by `SetMultFlags` and the spot read. The count is WRITTEN like
the bits -- the real band and mode plus the `AllBands`/`Both` cells -- so the
scope is applied only at the read. Their
scope is `Settings.Mult.ByBand`/`ByMode`, which IS the class's answer:
FoundContest writes it from the trait (`cfMultByBand`/`cfMultByMode`,
`ApplyContestTraits`), then `DescribeSession` (`svMultByBand` -- Arizona in
state, ALRS), with an operator's stated MULT BY BAND / MULT BY MODE winning over
the trait. Do not key a count on `ContestIdentity(...).MultByBand` directly: it
misses the DescribeSession and operator layers the bit sheet obeys. Cost: one
`ActiveContest` per non-dupe QSO in `AddQSOToSheets` (loader and rescore
included). Pinned by `uTestSpotCommentMultiplier.Test_Count_*`.

## The needs strips are recomputed after a QSO is logged (issue #100, 2026-10-26)

"QSO needs for" / "Mult needs for" are computed from `CallsignsList` and
`mo` by `LOGEDIT.ShowNeedsForCall` -- the needs half of
`ShowStationInformation`, ONE routine; do not copy its body. **`LogContact`
asks it again** after the sheets have the QSO, through
`LOGSUBS2.RefreshNeedsAfterLoggedQSO(call, MyComputer, TailEnding)`, which
does nothing for a peer's QSO or while tail-ending (the strips already show
the NEXT call). Until then nothing did: the post-log `ShowStationInformation`
in `TryLogContact` met the `StationInformationCall` latch, which D7 e569269f
(4.91.1, 2020) moved to be cleared only AFTER it, so the strips showed the
bands from before the QSO. That dead call is deleted. **Do not move the latch
clear back into `LogContact`** -- that brings the rest of
`ShowStationInformation` back on every logged QSO, which is what the 2020
change stopped. A test of the strips must set `NumberDifferentMults` (LogCfg
counts it at start-up; at 0 the Mult strip is never written). Pinned by
`uTestStatusAndNotice.Test_LoggingAQSOTakesItsBandOutOfTheNeedsStrips`.
`LOGSTUFF.ShowQSOStatusCall` is dead (cleared in `LogContact`, read nowhere).

**THE "MULT NEEDS FOR" HEADER IS THE CONTEST'S HINT OF THE REMEMBERED
EXCHANGE, NOT THE QSO'S `DomMultQTH`** (NY4I bench, ARRL SS, 2026-11-04).
`ShowNeedsForCall` reads `CallsignsList.GetIniitialExchange(call)` -- built by
`LOGDUPE.GetInitialExchangeStringFromContestExchange` for the PREFILL, so it
joins every field the field list marks (SS: `18 UT`) -- and shows
`DomStringParse` of it = the class's `DomesticMultiplierHint`, whose base
answers the text WHOLE. The header read `18 UT` while the QSO's
`DomesticQTH`/`DomMultQTH` and the sheet were `Ut`/`UT` (arrlsect.dom: `Ut =
UT`). `LogContact`'s own `ShowDomesticMultiplierStatus(RXData.DomMultQTH)` is
gated on MULT BY BAND / BY MODE and does not run for SS. Fixed for SS only:
`TContestARRLSSBase.DomesticMultiplierHint` answers `ScanSweepstakesExchange`'s
section. **Do not "fix" the prefill text** -- check + section is right there.
Other contests whose remembered text carries a field before the QTH (NAQP's
`TOM CA`, by reading) and the alias-vs-multiplier gap (`WF` filed as `WcF`)
are issue 207. Pinned by
`uTestStatusAndNotice.Test_TheSweepstakesMultHeaderNamesTheSection` and
`uTestExchangeWordOrder.Test_SweepstakesMultiplierHintIsTheSection`.

**ISSUE 207 (2026-11-05): FOR A `UsesDomesticFile` CONTEST THE HINT IS MAPPED
TO THE MULTIPLIER KEY** -- `LOGDUPE.DomesticMultiplierOfRememberedExchange`:
the whole hint through the table (`DomesticKeyOfQTH`), else the LAST word that
maps (the QTH follows every other field the remembered text can lead with, so
NAQP `DE CA` is CA), else the hint unchanged (YOTA's age IS its multiplier).
A contest with no domestic file keeps its own hint. Measured first, through a
temporary matrix section, never frozen: 58 contests had a header that was not
the multiplier; the rule fixed 851 rows, broke none, met no two-word tie. ONE
routine for the header (`LOGSTUFF.DomStringParse`) AND the spot section hint
(`LOGEDIT.DomesticKeyKnownForCall`, issue 83): **never map the key a second
time** -- a key is not always its own alias (michigan_cty.dom `Presq = PRES`,
georgia_cty.dom `Ga`, iaruhq.dom `sara`). `DomStringParse` answers the key AS
THE LIST SPELLS IT (`Ut`, `WcF`) -- the strip's lookup; the header upper-cases
it for display in `ShowDomesticMultiplierStatus` (that also upper-cases
LogContact's MULT-BY-BAND call). An empty hint now shows the CALL's status
(`ShowMultiplierStatus`), not the last header. Not fixed: aliases over ten
characters or with a blank (#208), ALL JA's NUL
precedence in the prefill (#210), RF Championship / Minnesota DX remembering no
QTH (#211). Standing test: `uTestStatusAndNotice.
Test_TheMultHeaderIsTheMultiplierInEveryDomesticFileContest` (every registered
domestic-file contest, every alias of its top file, a QSO with every non-QTH
field filled, the header and the lookup) and `Test_TheMultHeaderPinsOfIssue207`;
the spot pin is `uTestSpotCommentMultiplier.Test_Hint_OurOwnKnowledgeOverrulesTheComment`.
**THE HEADER'S GATE IS THE CONTEST'S, NOT A LENGTH (issue 209, NY4I
2026-11-05):** `ShowDomesticMultiplierStatus` asks
`ContestIsValidDomesticMultiplier(ActiveContest(Contest), text)` =
`TContestBase.IsValidDomesticMultiplier` (base: non-empty; two characters or
more where `HasGridSquareMultiplier`/`HasGridFieldMultiplier` -- the old
answer for WSJT-X's `AnsiLeftStr(grid, 2)`). D7's `length < 2` (Gavin 2016,
`6961582d`, no reason; the WLI code had none) hid SP DX's and King of Spain's
one-letter provinces. No class overrides it; do not bring a length test back.
**A MULTIPLIER COMPUTED FROM THE CALL REACHES THE STRIP THROUGH THE CLASS'S
`DomesticMultiplierFromCall`, NOT THE HEADER GATE** (NY4I 2026-11-05, measured
the same day): a contest that remembers no exchange text (RST + number) gets
`ShowMultiplierStatus(call)` -- the header NAMES THE CALL, as CQ WW's does --
and `GetMultArray` asks the class for the key. MWC answered '' until then, so
its strip was empty for every call; it now answers its scoring letter (seven
classes answer it: Russian DX, RF Championship x2, Ural Cup, RDA, YO DX, MWC).
LogContact's `RXData.DomesticQTH <> ''` gate and `logsubs2`'s
`length(WindowString) < 2` were NOT changed. **IARU HF and WRTC take any
received text as their HQ multiplier**, so a remembered zone alone (`8 ` -- the
builder appends `' ' + QTH` even when the QTH is empty) hinted as an HQ; their
`DomesticMultiplierHint` answers '' for it now (`uDomesticKey.IsZoneNumberOnly`;
NY4I: the ITU zone comes from the call, as in CQ WW), so the header names the
call. **A PRIOR CONTACT'S ZONE TRUMPS THE CALL'S (#213, built 2026-11-05):**
`GetMultArray` asks `CallsignsList.GetLoggedZone(call)` -- the zone of the most
recently LOGGED QSO with that call, written by `LOGEDIT.AddQSOToDupeSheets`
(live, loader and rescore, each in log order; only QSOs on the current dupe
sheet; cleared by `ClearDupes`) -- before `ctyGetCQZone`/`ctyGetITUZone`. The
strip, the call-window MULT flag and the spot hint all reach it through
`GetMultArray`; do not read the CTY zone beside it. **A REMEMBERED TEXT THE
DOMESTIC FILE MAPS NOTHING IN IS EMPTIED (#209 option 1, NY4I 2026-11-05):**
`DomesticMultiplierOfRememberedExchange` blanks the hint, so the header names
the call, unless `TContestBase.UnmappedHintIsTheMultiplier` (base False) says
the field IS the multiplier -- YOTA alone (its age; `YOTA.dom`'s lines have no
`=`, so its table maps nothing). SRR-JR is NOT included: its multiplier is the
oblast (`russian.dom`), its scoring never counts the age. Measured: 29 contests'
headers move from a bare field to the call. A header test needs the session's
table loaded -- the SS header test had none and passed only on the old rule.
**`mo.dom` is deleted (#208)**: no contest, `.dom` INCLUDE or D7 row named it.
**A `.dom` line `QTH > MULT = aliases` gives DomesticQTH `QTH` and multiplier
`MULT`** (florida.dom `Alc > Fl = ALC`: each county counts as Florida) -- a
probe that takes the left side as the key miscounts every such line.

**Corpus baselines (#206, 2026-11-05).** A re-freeze of `rescored.*` needs a WRITTEN reason per set in
`tr4w/test/corpus/REFREEZE_NOTES.md`; an unexplained difference is a possible scoring regression and stays
red. **Headless runs (`/RESCORE`, `/EXPORT`) read only the `settings` section of the settings file, never
the legacy `commands` bucket**, so station facts in a fixture (grid, state, zone, name) must sit in
`settings` -- and each one changes an export (State -> IARU `59 FL`, Zone -> IARU points, Name -> General
`59 TOM`), so the fixture states only the grid. The 12-vs-16 IARU claimed score was a stated MY ZONE (a CQ
zone) compared against ITU zones, not CTY.DAT.

## Coordinate with

`contest-factory` (behaviour is migrating there — check which side you are on) ·
`file-formats` (Cabrillo/ADIF are your output) · `log-database` (QSOs land in
SQLite) · `multi-op-network` (dupes and mults cross the network).
