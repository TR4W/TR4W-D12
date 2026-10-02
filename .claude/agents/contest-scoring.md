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
   `ParseReceivedExchange` (M5b), whose base is `logstuff.ParseExchangeShape`
6. Validation → `ContestExchange`
7. Network broadcast → `uNet.pas`
8. Display update → `logwind.pas`

## What you must know before changing anything

**THIS CODE IS NOT UNIT-COVERED.** The unit-test binary links only leaf `src`
units; `ProcessExchange`, scoring and dupe need the app's globals booted. Your
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
2026-10-01).** One resolver, `ApplyContestTraits`, writes the `Active*`
globals, the by-band/mode flags and the CTY zone list: the operator's
statement, else `ContestIdentity(Contest)`. A statement made BEFORE the
`CONTEST` line now stands (it used to be overwritten); the per-contest arms
still run after the head and still overwrite. Three defects went with it:
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
classless path only: the same `uContestBase.ApplyQSOPointOverride`, then the
`case ActiveQSOPointMethod`. Do not add a band check or an override there for
a classed contest -- it would never run. **`QSO POINT METHOD` is retired at
the end of the migration.**

**Dupe marking no longer reads the point method** -- `logsubs2` asks
`ContestIdentity(Contest).MarksDupes`. **Nor does exchange parsing (M5b,
2026-10-02):** RAC, PCC and Arktika's branches and RussianDX's initial
exchange are their classes' own now. The point-method readers left in the
engine are `logedit.TotalScore`'s five formulas, for M6.

**`ProcessExchange` ASKS THE CONTEST (M5b).** It keeps the contest-blind
tokenising gate (`ParseArray`), then calls
`ExchangeContest.ParseReceivedExchange` (the active contest's object, else its
identity -- never nil) with a `TReceivedExchangeSession`: the session's
exchange, `ParseExchangeShape` (the old `case ActiveExchange of`, now keyed on
the shape it is HANDED and naming no contest), and engine services
(`ZoneOfCall`, `IsDomesticQTH`, `CallWindowHasCall`, `AbandonEntry`). **Do not
put a contest test back inside a shape parser** -- a contest's parse rule is an
override on its class, under the shape it was written for. The one still named,
with its reason: the UA4W Championship in `ProcessRSTAndGridSquareOrRDAExchange`
(its class would have to score it, and its arm asks `ctyGetCQZone(MY CALL)`).
`ValidClass` and the Field Day DX check ask the contest with no fallback (D1/D2
deleted). Word cutting a class also needs (`ParseExchange`, `ProcessSSEntry`,
the single-word test) is LIFTED to `uExchangeTokens` and called by both.
**Two refusals NY4I ruled (design 7.10)**: Sweepstakes without a precedence
says so; a state party's out-of-state station working a non-host station is
refused. The matrix's `parse` section sees all of it; nothing sees the window
(`BENCH_QUEUE.md`). **Known latent defect (M8):**
`TCallsignsList.AddCallsign` marks `AllBands` for an off-band QSO, so for a
contest not counting QSOs per band an off-band contact would make a later
on-band one a dupe (ownership doc §8.2d).

**Its spelling table is rotated:** `QSOPointMethodArray` selects the wrong
method for 46 spellings, a D7 defect. The one shipped `.cfg` it reached,
`target/dom/Idaho QSO Party.cfg`, no longer names a point method: Idaho is
`IDAHOQSOPARTY` with its own class since 2026-10-01 (ownership doc §7.2). **No
`.cfg` borrows another contest's type** -- an event is a `ContestType` and a
class.

## Coordinate with

`contest-factory` (behaviour is migrating there — check which side you are on) ·
`file-formats` (Cabrillo/ADIF are your output) · `log-database` (QSOs land in
SQLite) · `multi-op-network` (dupes and mults cross the network).
