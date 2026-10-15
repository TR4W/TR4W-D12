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

So: **scoring, multiplier and exchange-parsing changes deserve real-contest
testing.** The corpus is a strong net, not a proof. Say so in your report rather
than presenting a green corpus as proof a scoring change is right.

**`src/trdos/` is proven contest logic — avoid modifying unless necessary**, and
prefer new units in `src/`. The no-LCL half of that boundary was rescinded
(2026-08-23): TRDOS units may use the LCL directly. The rest stands — new
*behaviour* belongs in `src/`, and increasingly in the contest factory.

**`VC.pas` is the source of truth** for `ContestType` (120+ values), band and mode
enums, and colour schemes.

**The sent exchange is reconstructed, not stored** — `exchange_sent` exists in the
schema and nothing writes it (memory: `iaru-exchange-reads-station-state`). QTH is
a polymorphic field. Know which `MY` fields belong to the station and which to the
contest before moving one.

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
posting clients run on worker threads. **Missouri's peak-hour tally** is still
counted in `LogContact` only (`LiveSessionTally`, asked through
`TalliesLiveQSO`) -- a defect preserved on purpose, design Q32; the bonus
stations are counted over the view. `LoadinLog` and the view share one
predicate, `uContestBase.QSOCountsTowardTotals`. **Latent defect (Q37):**
`LOGGRID.ConvertGridToLatLon` reads a grid shorter than four characters past
its end, so a malformed-grid QSO's distance follows the heap.

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
refused. The matrix's `parse` section sees all of it; nothing sees the window
(`BENCH_QUEUE.md`).

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
setting. The one shipped `.cfg` it reached,
`target/dom/Idaho QSO Party.cfg`, no longer names a point method: Idaho is
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

## Coordinate with

`contest-factory` (behaviour is migrating there — check which side you are on) ·
`file-formats` (Cabrillo/ADIF are your output) · `log-database` (QSOs land in
SQLite) · `multi-op-network` (dupes and mults cross the network).
