# Adding a New Contest to TR4W

*Source: distilled from the RTC (Real-Time Contest) work, May 2026, issue #902. Read this before adding any new contest definition.*

---

## 1. Mental model

A "contest" in TR4W is a `ContestType` enum value and **a class that owns its rules** -- its names and ids, its exchange and multiplier kinds, its flags, its scoring, its set-up and its prompts (`docs/ADDING_A_CONTEST.md`, `docs/CONTEST_OWNERSHIP_DESIGN.md`). **There is no metadata row any more**: `ContestsArray`, `ContestsBooleanArray` and `QSOParties` were deleted at M10 S8 (2026-10-14), after every class had stated their values (S5). `VC.pas` keeps the enum and one parallel array, `ContestTypeSA` (the spelling a `.cfg`'s `CONTEST =` line matches).

The vast majority of plumbing — exchange parsing, Cabrillo formatting, dupe handling, ADIF export, multiplier tracking — already exists for the common exchange shapes. **Reuse before writing new parsers.**

---

## 2. Anatomy of a contest definition

> **SINCE Q108 S3 (2026-10-17) THE `ContestType` ENUM IS FROZEN, AND A NEW
> CONTEST HAS NO ENTRY IN `VC.pas`.** `Lint-FrozenContestNumbers` fails the
> build if a member is added -- appended included -- removed, reordered or
> renamed. A new contest registers by its string id
> (`RegisterContestById`), and **no real contest may do so until Q108 S4**
> is in -- see `ADDING_A_CONTEST.md`, "A NEW CONTEST REGISTERS BY ITS ID".
> The table below describes the 188 LEGACY contests, which is how every
> existing contest was added; S5 rewrites this document.

`VC.pas` holds **two** entries per LEGACY contest, in the same position:

| Where | What it holds |
|---|---|
| `ContestType` enum | The new enum value (e.g. `RTC`) -- **appended**, because the ordinal is persisted |
| `ContestTypeSA` | The enum's spelling: what a `.cfg`'s `CONTEST =` line is matched against, what the SQLite log stores, and every name getter's neutral fallback. **Never reuse a spelling for another contest**; a renamed one keeps its old spelling in `uContestNames.LEGACY_CONTEST_NAMES` (`ADDING_A_CONTEST.md` Step 3c) |

Everything else is the contest's class, in `src/contestFactory/` -- read
[`ADDING_A_CONTEST.md`](ADDING_A_CONTEST.md). A state QSO party also ships
both `.dom` files (`<base>.dom` and `<base>_cty.dom`) in `full.nsi`, which
`Lint-DomCoverage` checks against each party class's
`InStateDomesticFileName`.

**A new QSO-points formula touches no shared table.** `QSOPointMethodType`, its
spelling table and the row's `QP:` column are gone (M10 S2-S4, 2026-10-14): a
contest's scoring is its class's `CalculateQSOPoints` -- see
[`ADDING_A_CONTEST.md`](ADDING_A_CONTEST.md). There is no point method to set.

~~**Adding to the end of the enum is the safe move**~~ — **not any more (Q108 S3): the enum is frozen.** Appending kept existing binary log files, config files and the multi-op packet compatible, but an appended member would now collide with the handles the registry gives contests registered by id, which start one above the last member. Reordering the enum would break those files, and still would.

### Where the old row's fields went (M10 S8)

For reading a pre-S8 commit, or a contest transcribed from one. Each field of
the deleted `ContestsArray` row is a `TContestBase` getter the class states:

| old row field | the class states |
|---|---|
| `Name` / `FriendlyName` | `GetDisplayName`, `GetFriendlyName` |
| `ADIFName` / `CABName` | `GetADIFContestId`, `GetCabrilloName` |
| `Email` / `DF` | `GetSubmissionEmail`, `GetDomesticFileName` |
| `WA7BNM` / `QRZRUID` | `GetWA7BNMId`, `GetQRZRUId` |
| `PxM` `ZnM` `XM` `DM` | `HasPrefixMultiplier` and `PrefixMultiplierKey` (the prefix KIND and `GetPrefixMultiplierType` were deleted at M11 S3), `HasZoneMultiplier` and `ZoneMultiplierCount` (plus `ZoneMultiplierZones` for CQ or ITU zones and `NumbersZonesFromZero`; the zone KIND and `GetZoneMultiplierType` were deleted at M11 S5), `HasDXMultiplier` and `DXMultiplierKey` (plus `CountryMode` for DXCC only; the DX KIND and `GetDXMultiplierType` were deleted at M11 S4), `UsesDomesticFile` for a `.DOM` lookup, or the shape answers (`DomesticMultiplierFromQTH`, `DomesticMultiplierHint`, `HasGridSquareMultiplier`, `HasGridFieldMultiplier`, `DomesticQTHReplacesDXMultiplier`, `DomesticQTHIsNeverAGrid`); `HasDomesticMultiplier` is composed from them in the base (the domestic KIND and `GetDomesticMultiplierType` were deleted at M11 S6) |
| `AIE` / `AE` | `GetInitialExchangeKind`, `GetExchangeKind`, and `GetReceivedExchangeFields` (the fields that exchange carries, calling a `uExchangeFields` helper -- M11 S9a; the base marks none) |
| `P` (the `QSOParties` index) | `GetIsUSQSOParty`, `GetHostState`, `GetInStateDomesticFileName`, `GetQSOPartyArea` |
| `CountyLineAllowed` | the import's county line is `TContestStateQSOPartyBase.CountyLineAllowed` (S7); the rover split on ADIF export is `TContestBase.SplitsRoverCallOnExport` (S8), True for every QSO party since Q90/Q94 (2026-10-14) -- a state party inherits it from its base |
| the `ContestsBooleanArray` word (`ciQB`, `ciQM`, `ciMB`, `ciMM`, `ciErmak`, `ciVHFEnabled`, `ciCQZoneMode`, `ciCDC`, `ciRTC`) | `GetFlags: TContestFlags` -- `cfQSOByBand`, `cfQSOByMode`, `cfMultByBand`, `cfMultByMode`, `cfErmakSpecification`, `cfVHFBandsEnabled`, `cfCQZoneMode`, `cfCountsDomesticCountries`, `cfRTCCapable` |

A getter a class does not state answers DUMMYCONTEST's neutral row (M10 S6):
`[]`, the `No*` kinds, `''`, 0, and the enum's spelling for the names. A
mixed-mode contest with per-band dupes (RTC, WWDIGI) states
`[cfQSOByBand, cfMultByBand]`.

---

## 3. Reusable subsystems — check before adding new

### Exchange types (`VC.pas:3144+`)

There are ~50 exchange types. **Almost any common shape is already covered.** Examples:

| Shape | Use |
|---|---|
| `RST + serial + grid` | `RSTQSONumberAndGridSquareExchange` |
| `serial + grid` (no RST) | `QSONumberAndGridSquare` |
| `grid only` | `GridExchange`, `Grid2Exchange` |
| `RST + grid` | `RSTAndGridExchange` |
| `RST + serial` | `RSTQSONumberExchange` |
| `RST + serial + state/QTH` | `RSTQSONumberAndDomesticQTHExchange` |
| `name + state` | `NameAndDomesticOrDXQTHExchange` |
| `RST + zone` | `RSTZoneExchange` |

Each exchange type already has:
- A `ProcessXxxExchange` parser in `logstuff.pas`
- Dispatch in `logstuff.pas:ProcessExchange` case statement (~line 8691)
- Dupe handling in `logdupe.pas`
- Cabrillo writer for both MY-EXCH and HIS-EXCH in `postunit.pas` (case statements around lines 2603 and 4121)
- ADIF export support in `postunit.pas:GetMyExchangeForExport`

**If you find an existing exchange type that matches, you write zero new parsing/serialization code.**

### QSO points -- the contest's class, not an enum

Until 2026-10-14 a contest named one of ~130 `QSOPointMethodType` values and
`logstuff.pas:CalculateQSOPoints` had a `case` arm per value. The arm moved into
each contest's class (M3 onward), the `case` was deleted at M10 S3 and the
enum at M10 S4. Score your contest in its class's `CalculateQSOPoints`
(`ADDING_A_CONTEST.md`); a computation genuinely shared by several contests is
a helper the class calls (`FixedModePoints`, `LOGGRID.GetDistanceBetweenGrids`).

### Domestic multipliers -- the class states them (M11 S6, 2026-10-14)

There is no domestic-multiplier enum any more (`DomesticMultType` was deleted
at M11 S6 part 2). The class says what a received domestic QTH means:

- **a `.DOM` file lookup** (US states, JA prefectures, a party's counties ...)
  -- override `UsesDomesticFile` (or inherit it: every state QSO party does
  from `TContestStateQSOPartyBase`);
- **a grid square / grid field** -- override `DomesticMultiplierFromQTH` and
  `DomesticMultiplierHint` with `uDomesticKey.GridSquareKey` /
  `GridFieldKey`, and `HasGridSquareMultiplier` / `HasGridFieldMultiplier`;
- **the text as typed (WYSIWYG)** -- `DomesticMultiplierFromQTH` and
  `DomesticQTHReplacesDXMultiplier`;
- **an RDA district / a DOK / an IOTA reference** -- copy RDA's, WAG's or the
  RSGB IOTA's overrides;
- **none** -- state nothing.

`HasDomesticMultiplier` is composed from those answers in the base; a shape
with no flag of its own (DOK, IOTA) overrides it. Pin the answers in
`uTestDomesticMultiplier`.

### Initial exchange auto-prefill (`InitialExchangeType`, `VC.pas:561`)

- `GridInitialExchange` — auto-prefill grid from cty.dat lookup (great for grid contests)
- `NameQTHInitialExchange` — auto-prefill name+QTH from SCP database
- `SectionInitialExchange` / `CheckSectionInitialExchange` — ARRL sections
- `ZoneInitialExchange` — CQ/ITU zone
- `NoInitialExchange` — operator types everything

---

## 4. Behavior knobs in `fcontest.pas`

> **STALE SINCE M7a (2026-10-02).** FoundContest's `case Contest of` is
> deleted: a contest states its session -- bands, modes, memories, exchange
> strings -- in its class's `DescribeSession` (`ADDING_A_CONTEST.md`, "How a
> contest describes its session"). The knobs below are still what the
> session applies; where they are set is the class.

`fcontest.pas:OpenContest` had a giant case statement (`case Contest of`) where contest-specific defaults lived. Most contests don't need an entry — the metadata row drives behavior. Add a case branch only if you need to:

### Band/mode group toggles (coarse-grained)

| Flag | Effect |
|---|---|
| `HFBandEnable := False;` | Disable all HF bands |
| `VHFBandsEnabled := True;` | Enable VHF |
| `WARCBandsEnabled := False;` | **Disable 30/17/12m only.** Enforced in band-switch and spot filters. |
| `DigitalModeEnable := True;` | Enable digital mode infrastructure |
| `ActiveBand := Band20;` | Initial band |
| `ActiveMode := CW;` | Initial mode |

**There is no per-band toggle** (no `Band160Enable`, etc.) and **no per-mode disable**. If your contest restricts to specific bands or modes, enforce it in the QSO-points method by setting `RXData.QSOPoints := 0; RXData.InhibitMults := True;` for out-of-rules QSOs. See the RTC scoring branch in `logstuff.pas` for the pattern.

### Function-key memories and SAP exchange strings

For CW, set defaults via:

```pascal
CQExchange := ' # ' + MyGrid;                       // F3 in CQ mode (SAP send)
RepeatSearchAndPounceExchange := ' # ' + MyGrid;
SearchAndPounceExchange := ' # ' + MyGrid;
SetCQMemoryString(CW, F3, '# ' + MyGrid);           // F3 transmits this in CQ mode
SetEXMemoryString(CW, F4, 'NR # ' + MyGrid);        // F4 in exchange-send mode
SetEXMemoryString(CW, F5, '@ DE \ # ' + MyGrid);    // F5 full call+exchange repeat
SetEXMemoryString(CW, AltF4, 'NR?');
SetEXCaptionMemoryString(CW, F4, 'NR');             // status-line label
```

**Placeholders that get substituted at send time:**
- `#` → next serial number
- `\` → my call (`MyCall`)
- `@` → his call (call currently in the call window)
- `^` → space-suppressed concatenation (e.g. `CQ^TEST` = `CQTEST`)

**Variables substituted at FCONTEST init time** (one-shot, not live):
- `MyGrid`, `MyState`, `MyName`, `MyZone`, `Code599` (`'5NN'` or `'599'` depending on lang)

If the operator changes `MyGrid` mid-contest, function-key memories don't update — same as for `MyZone`. Document this where it matters.

**Phone (SSB) memories** are typically WAV file paths (`CQF1.WAV` etc.) set by `cfgdef.pas` defaults. Per-contest Phone defaults are uncommon.

### Reuse the helper procedures

`fcontest.pas` has helpers like `SetUpRSTQSONumberExchange`, `SetUpRSTMyStateExchange`, `SetUpRSTMyZoneExchange`, `SetUpNameAndStateExchange`. They're called from the exchange dispatch in `FoundContest` (`case ContestSession.Exchange of` -- the session's resolved exchange kind, `ActiveExchange` until M10 S9f; grep for it rather than trust a line number). If your exchange type matches an existing helper, inheritance is automatic — you may not need to set memories at all.

---

## 5. UI: `uNewContest.pas`

The new-contest dialog asks for an operator-specific value depending on what the contest needs. The dispatch is in `OnCreate` (around line 408). Add your contest to one of:

| Branch | Prompt |
|---|---|
| `TC_ENTERYOURFOURDIGITGRIDSQUARE, icmyGrid` | 4-char grid (e.g. FN20) |
| `TC_ENTERYOURSIXDIGITGRIDSQUARE, icmyGrid` | 6-char grid (e.g. FN20XR) |
| `TC_RFAS, icMyQTH` | (specialty) |

If your contest doesn't need a special prompt, it falls through to the generic flow. No edit needed in that case.

---

## 6. Common pitfalls

### a) The one parallel array must stay aligned

`ContestType` and `ContestTypeSA` are indexed by the same enum. **Always append in the same position** — if you put the new contest at the end of the enum, its spelling goes at the end of `ContestTypeSA`. The other two parallel tables (`ContestsArray`, `ContestsBooleanArray`) are gone (M10 S8), and `Lint-NoContestTables` fails the build if a new hand-typed `array[ContestType]` table appears.

### b) The `cMyGrid` ShortString → PChar trap

This bit RTC. `MyGrid` is a `ShortString` (length byte + chars). To pass to `wsprintf` with `%s`, the code copies into a `Str20`, then writes `#0` somewhere to null-terminate. Old `postunit.pas` hardcoded `TempGrid[7] := #0` (assumed 6-char) and `TempGrid[5] := #0` (assumed 4-char) — both wrong for the other length and they leaked uninitialized stack memory into the Cabrillo output.

**Correct idiom:** `TempGrid[Length(MyGrid) + 1] := #0;` — null at the byte right after the actual content. Works for any length. Fixed in both `postunit.pas:2349` and `postunit.pas:4051` during RTC work.

### c) `QSONumberAndGridSquare` vs `RSTQSONumberAndGridSquareExchange`

Same shape but different Cabrillo writers:
- `QSONumberAndGridSquare` writes from `cMyState` — so the FCONTEST block has to do `MyState := MyGrid;` (RF-CUP-CW does this).
- `RSTQSONumberAndGridSquareExchange` writes from `cMyGrid` directly — no `MyState := MyGrid` needed.

Pick the right one based on whether RST is in the exchange. RST is *optional* per many rule sets, but most contests still want it in the Cabrillo record per WSJT/N1MM convention.

### d) `GetDistanceBetweenGrids` is not Haversine

`loggrid.pas:GetDistanceBetweenGrids` pads 4-char grids to 6-char with `'LL'` (= 11/24 of the way through the sub-square, **not** the center) and uses `Calc_GeoDist`, a Vincenty/Andoyer-style iterative geodesic. Most rules cite the Haversine formula and the geometric **center** of the 4-char square.

For contests that require the rules-spec distance value, write a small dedicated helper (`RTCGridDistance` in `loggrid.pas` is the template) that:
1. Pads to grid CENTER algebraically: `lat = -90 + lat_field*10 + lat_sq*1 + 0.5; lon = -180 + lon_field*20 + lon_sq*2 + 1.0`
2. Uses pure Haversine with `R = 6371 km` and `ArcTan2` (already available via `utils_math.pas`)
3. Returns `Double` so tier boundaries compare exactly (no integer-rounding off-by-one near the boundary)

**Calibration fixture:** FN36 → DM18 = `3664.72 km` (the RTC rules cite this).

### e) Modes are a small set, with surprises

`ModeType = (CW, Digital, Phone, Both, NoMode, FM)`. Note `Phone` is SSB+AM (NOT FM). `FM` is its own value. `Digital` covers FT8/FT4/RTTY/PSK/etc. Use `[CW, Phone]` to mean "CW or SSB only" in scoring branches.

### f) Bands enum order is not what you'd expect

`BandType = (Band160, Band80, Band40, Band20, Band15, Band10, Band30, Band17, Band12, Band6, ...)`. The WARC bands (`Band30, Band17, Band12`) come **after** `Band10`, not in frequency order. Watch this if you're filtering by band range.

Also, the `BandTypeToUDPContactBand` array in `logsubs2.pas:94` had three WARC entries with wrong MHz labels (`'30'/'17'/'12'` instead of `'10'/'18'/'24'`) — fixed during the RTC branch. The values are MHz designators (e.g. `'7'`, `'14'`, `'21'`, `'28'`), NOT meter-band names.

### g) Don't bump version

Howie's build process owns `Version.pas` bumps. Leave version untouched.

### h) Build command

```
powershell.exe -ExecutionPolicy Bypass -File FullBuild.ps1
```

Never invoke `DCC32.EXE` directly. If the link step fails with `Could not create output file 'tr4w.exe'`, TR4W is still running on your machine — close it and rebuild.

---

## 7. End-to-end checklist (paste into your PR description)

Working through a new contest, in dependency order:

- [ ] Identify the contest's exchange shape — find a matching existing `ExchangeType` (`VC.pas:3144+`)
- [ ] Identify the multipliers -- each is a class answer now (`Has*Multiplier` and its key; see the table above), not an enum
- [ ] Write the QSO-points rule in the contest's class (`CalculateQSOPoints`, `ADDING_A_CONTEST.md`) -- there is no point-method enum since M10 S4
  - [ ] If distance-based, sanity-check against rules' published fixture
- [ ] Add the contest itself to `VC.pas`:
  - [ ] `ContestType` enum (append at end)
  - [ ] `ContestTypeSA` spelling (append at end)
- [ ] Write its class (`ADDING_A_CONTEST.md`): names and ids, kinds, `GetFlags` (`cfQSOByBand/cfQSOByMode/cfMultByBand/cfMultByMode`, ...) -- no `VC.pas` row exists to fill in
- [ ] If the contest needs init defaults, state them in its class's `DescribeSession` (FoundContest's `case Contest of` is gone since M7a)
  - [ ] Band/mode group toggles (`HFBandEnable`, `WARCBandsEnabled`, `VHFBandsEnabled`, `DigitalModeEnable`)
  - [ ] `ActiveBand`, `ActiveMode` defaults
  - [ ] CW function-key memories and SAP exchange strings if non-trivial
  - [ ] `MyState := MyGrid` ONLY if exchange is `QSONumberAndGridSquare` (not `RSTQSONumberAndGridSquareExchange`)
- [ ] If grid-based, add the contest to the 4-char or 6-char grid prompt in `uNewContest.pas:OnCreate`
- [ ] Per-band/per-mode rule enforcement (no infrastructure for this — enforce in the points method by setting `QSOPoints := 0; InhibitMults := True;` for out-of-rules QSOs)
- [ ] Build clean: `powershell.exe -ExecutionPolicy Bypass -File FullBuild.ps1`
- [ ] Manual test: start a contest, log a few QSOs spanning the rule edges (in-rules, out-of-rules band, out-of-rules mode, mult boundary). Inspect the Cabrillo and ADIF outputs.
- [ ] Update the issue with summary + remaining gaps
- [ ] Do NOT push or open a PR until the user has tested in-program and approved.

---

## 8. Worked example: RTC commit shape

For reference, the full RTC change set covered:

| File | Change |
|---|---|
| `VC.pas` | 6 array entries (enum + 5 arrays) |
| `loggrid.pas` | new `RTCGridDistance` Haversine helper (40 lines) |
| `logstuff.pas` | new `RTCQSOPointMethod:` case branch + 1 new local var (historical: the case and the enum are gone since M10 S3/S4; it is `uContestRTC` now) |
| `fcontest.pas` | `RTC:` case with `WARCBandsEnabled` and CW function-key defaults |
| `uNewContest.pas` | 1-word edit: add `RTC` to the 4-char-grid prompt |
| `postunit.pas` | (bug fix surfaced by RTC, not strictly RTC) `cMyGrid` null-terminator |

Total: ~120 lines of code spread across 6 files. **No new exchange parser, no new Cabrillo writer, no new dupe logic, no new ADIF code.** All reused.
