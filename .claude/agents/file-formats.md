---
name: file-formats
description: File formats and data interchange — ADIF, Cabrillo, CTY.DAT, TRMASTER.DTA/Super Check Partial, and the binary log import path. Use for import/export defects, malformed output, header or field mapping questions, country-file updates, or anything the golden corpus byte-diffs.
tools: Read, Grep, Glob, Bash, Edit, Write
model: sonnet
---

You own every format TR4W reads from or writes to disk for interchange.

## Your files

| | |
|---|---|
| ADIF | `tr4w/src/uADIF.pas`, `uADIFExchange.pas` |
| Cabrillo | `uCabrillo.pas`, `uCabrilloExchange.pas`, `uCabrilloFormat.pas`, `uCabrilloHeader.pas` |
| Cabrillo export path | `tr4w/src/trdos/postunit.pas` |
| country file | `tr4w/src/uctydat.pas`, `uCTYUpdate.pas` |
| Super Check Partial | `tr4w/src/trdos/logscp.pas` (TRMASTER.DTA) |
| binary log import | `tr4w/src/domain/uLogBinaryFile.pas`, `uLogImport.pas` |
| TRMASTER tooling | `tr4w/tools/trmaster/` |

## You are the corpus's subject

**`bash tr4w/test/corpus/export-d12-corpus.sh` byte-diffs YOUR output** — 13 real
contest logs × ADIF and Cabrillo = 26 comparisons, against frozen D7
references. Baseline **`22 passed, 0 failed, 4 known-divergence, 0
awaiting-candidate`, and every export run must exit 0** (24/2 until
2026-10-16: Q54 -- winter_fd's Cabrillo writes its one FM QSO as `FM` where D7
wrote `PH` -- and Q76 -- michigan's ADIF writes four out-of-state stations'
own STATE where D7 wrote the host's `MI`). **A known difference is pinned LINE FOR LINE where it can be** --
`<set>/known.<kind>.diff`, read by `run-golden-diff.sh` AND `test-adif-roundtrip.sh` through ONE shared matcher, `tr4w/test/corpus/known-pin-lib.sh`: KNOWN only when the
changed lines are exactly the pinned ones, FAIL otherwise, FAIL when the pin
has gone stale. A slug row in `known-divergences.txt` excuses every difference
in BOTH of a set's artifacts; use one only for a cause with no known edge.

**THE INPUT IS A `log.db`, SINCE 2026-09-24 — a TR4W SQLite contest log, which
is what a contest IS here.** The `log.trw` and the `.CFG` invocation are gone by
NY4I's decision, not by discovery: *"we are so far past validating that fact...
the corpus can adopt the testing methodology of comparing a given `.db` file
produces an expected ADIF and Cabrillo file."* **The references stay D7-produced
and are NEVER regenerated** — that is the independent half, and regenerating one
turns the oracle into a tautology. If you think a ref must change, that is a
behaviour FINDING; report it with the diff.

**Binary-log import is covered by a UNIT TEST now, and only there** —
`uTestLogBinaryFile`, `uTestLogImport`, `uTestLogRepository`, reading the six D7
logs in `tr4w/test/unit/fixtures/binarylog/`. NY4I: *"that becomes a unit test
and not the corpus."* Do not put `.trw` fixtures back in the corpus.

**Log schema 10 (2026-11-19): byte 330 is `ceOffContest`** (the contest's
rule as stamped, `qso.is_off_contest`; `sReserved` is `string[42]` from 331).
`TLogBinaryReader.ReadNext` CLEARS it and `ImportBinaryLog` marks the new log
(`LOG_OFF_CONTEST_BACKFILL_KEY`) so the store stamps every row once the
contest is set up. **The Cabrillo and ADIF writers READ the stored answer**
(`uContestRegistry.StoredQSOIsXQSO`) and work no rule out; an ADIF import's
rows are stamped by `LogStoreAppendQSOs`. A CLAIMEDQSO 0 / XQSO=Y on import is
still the OPERATOR's flag (`ceXQSO`). See docs/LOG_SCHEMA.md.

**The record carries a received year since issue 298 stage 1 (2026-11-12)** --
`RcvdYear` (Word, 324) and `RcvdYearKnown` (326), carved from `sReserved` like
`ceXQSO`; still 376 bytes, no earlier offset moved. `TLogBinaryReader.ReadNext`
CLEARS both (a D7 log never wrote them), and `uLogImport` refills them from
`Zone` for a contest that kept its year there (`ContestKeepsYearInZoneSlot`).
ADIF and Cabrillo still read the zone slot until stage 3. **ADIF IMPORT TAKES
THE YEAR since stage 2 (2026-11-12)** -- in the contest's `ApplyADIFImport` (the
base, for any contest that states a `ReceivedYearKind`), never at the `CQZ` tag,
which may precede `CONTEST_ID`: `SRX_STRING` first (one word after the RST, as
TR4W writes it), else a `CQZ`/`ITUZ` value, through `StoreLicenceYear`. Before
that a TR4W EUHFC ADIF re-imported with NO year: TR4W writes no CQZ for those
contests. Expect the matrix's EUHFC/KVP import lines with a numeric SRX
(`srx.rst+number`, `rtty.dx`) to gain `zone=`. **EXPORT READS THE FIELD since
stage 3 (2026-11-12)**: a year contest's Cabrillo received column is
`CabrilloReceivedRSTYear` (`'%-3s %-7s'`, byte-identical for two digits, blank
for no year where the slot printed `255`), and its `SRX_STRING` is the RST and
the year from `RcvdYear` (the base `FormatADIFReceivedExchange` for a stated
kind) -- no longer the typed `ExchString`, which an Edit QSO change left
stale. No CQZ/ITUZ is written for EUHFC/KVP (`zmzNotCQOrITU`). `MY_CQ_ZONE` of
a NEW year-contest QSO is the call's CTY zone (`SessionMyCQZone`); rows
captured before keep the year they recorded.

**THE SENT YEAR IS THE ROW'S since log schema 8 (issue 300, 2026-11-13).** A
year contest's `STX_STRING` and Cabrillo sent column print `qso.year_sent`
(through `MyStationExchangeOfQSO`'s year kind), not the contest's current
`MY LICENSE YEAR`; an imported row with an `exchange_sent` still writes it back
verbatim. The ADIF import fills `year_sent` from the `STX_STRING`'s one word
after the RST, else the contest's year (`uContestBase.ApplyImportedSentYear`).
The canonical sent exchange (HamScore, UDP, `exchange_sent`) of a year contest
is the QSO's own sent RST and year -- `59 64` on phone, where the CW template
gave `599 64` on every mode (measured). Expect the matrix's EUHFC/KVP records
to move where they show a sent exchange.

Rules for running it:

- **Rebuild the app first**, and confirm TR4W is not running (`Get-Process -Name
  tr4w`) — a running instance collides on `target/` and every set falsely FAILs.
- **The exit code is part of the result.** `217` is FPC's unhandled exception;
  `3221225477` is an access violation. The artifacts are written before the exit,
  so a byte comparison alone cannot see a crash.
- **Run it, read the result, then commit.** Never chain the run and `git commit`
  in one shell block.
- Read `tr4w/target/tr4w.log` afterwards — a green 24/0/2 has hidden a
  missing-include warning before.

**The fixtures are `-text` in `.gitattributes` and must stay that way.** `ref.adi`
and `ref.cbr` are byte-diffed; git was previously EOL-converting them, so they
survived only on one machine's `core.autocrlf`. A differently-configured clone
would see failures that are purely a git artifact — **on the regression oracle
itself**.

**`log.db` is `binary` in `.gitattributes`** for the same reason one step
further: a page-structured database has nothing to give up by not being
diffable, and a guess about its type is not good enough for a regression input.

**The corpus is blind to scoring.** It proves the bytes, not the points.

## Cross-checks you have

**An independent ADIF validator (2026-10-23).** `tr4w/test/adif-validate/validate-adif-outputs.sh`
runs K1MU's validator, vendored in `tools/adifvalidator/` (`VENDORED.md` holds origin, commit and
every local patch -- it is Python with tabs; do not reindent), over the ADIF the corpus, the ADIF
round trip and the contest matrix produce. A `Compliance error` fails; `Consistency error`
findings are counted only. The corpus cannot do this job: the D7 references are themselves not
valid ADIF. `ADIF_SPEC_VERSION` (`uADIF`) is 3.1.8 (2026-11-19: it lists the MFSK submode JTTY, which TR4W now
writes as `MODE MFSK` + `SUBMODE JTTY`; 3.1.7/3.1.8 add no field), and `uTestADIF` pins every tag we write
against 3.1.6's field list, which is still the field list. The validator's JTTY and FT2 rows are recorded local patches (FT2: `eFT2`, appended after `eJTTY` 2026-11-19 for issues 88/122, written `MODE MFSK` + `SUBMODE FT2`, the 3.1.8 spelling; WSJT-X 3.3.0-beta6's source has no FT2, so no real file has been seen).
**adifmt (flwyd/adif-multitool v0.1.23, `go install`; NY4I 2026-11-19: it should supersede the vendored validator)** knows ADIF 3.1.8 and accepts `MFSK`/`JTTY`. `validate-adif-outputs.sh` runs it as an ADVISORY pass when it is on PATH or in `~/go/bin` (counts, first findings) and says so when it is absent; it is not the gate, because a clean clone cannot `go install` without a network fetch. It becomes the authority when its binary can be vendored (or CI installs a pinned version) and its STATE/DXCC and non-ASCII findings are triaged. A tag we write that the spec lacks is a finding to fix in the exporter, not
something to patch into the validator (`DOK` became `DARC_DOK` and `FOC_NUM` became
`APP_TR4W_FOC_NUM` on 2026-10-23; the import still reads the old names). **The export writes a
field only when its value has ADIF's shape** (`uADIF.IsADIFNumber`, `IsADIFGridSquare`,
`IsADIFIOTARef`, `ADIFZoneInRange`, `ADIFSectionOf`, `uARRLSections.IsADIFARRLSection`,
`uPOTAReference.IsValidPOTAPark`): an invalid one is omitted, never "fixed up", and the Cabrillo is
untouched. The validator gate's `known-findings-<source>.txt` pins excuse only synthetic matrix
input, and a pin that matches nothing fails. The generic DATA modes export as
`MODE RTTY` (NY4I, 2026-10-23) with `APP_TR4W_MODE_ASSUMED=Y` per record and a header line with the
count; import restores `eData` from the flag.

`tr4w/test/logdump/` dumps binary `.dat` logs to JSONL through the canonical
`ContestExchange`; `tr4w/test/python/verify_adif_export.py` cross-checks ADIF
export against it. The unit tests cover ADIF, Cabrillo, callsign routines,
multipliers, CTY.DAT, band lookup and CRC32.

## Watch for

- **State that leaks between exports.** `uADIFExchange` needed explicit
  `contacts := 0; pnr := 0; PreviousQTHString := ''` — a second export in one
  process inherited the first one's counters.
- **Ignored read results.** `logscp.pas` had three `sReadFile` calls whose result
  was discarded.
- **TRMASTER.DTA AND CALL HISTORY RELOAD IN PLACE (2026-11-20, `docs/LIVE_DATA_RELOAD.md`).**
  SCP serves from ONE `TTRMasterSnapshot` (the whole file in memory, NO open handle --
  a held handle is what stopped Windows replacing the file in use); `CD.ReplaceTRMasterFile`
  loads, checks, builds the operator-name set from the NEW file and flips both together;
  `InstallTRMasterSnapshot` is the only routine that sets `SCPIndexArray` / `SCPEndOfFile` /
  `DTAFileSize` / the three flags and it clears `CellBuffer` and `LastCallRecord` (GetEntry
  answers from that cache before reading). Call history is its own LAYER on each
  `TCallsignsList` entry (`HistoryExchange`), under the overlay the log and INITIAL.EX write
  (`InExchange` + `OwnStated`); `ExchangeOf` is the lookup order and
  `ReplaceCallHistory` the swap. A new SCP reader must go through the snapshot's `Data`,
  never open the file; a new reader of an entry's exchange must go through `ExchangeOf`.
  Everything runs on the main thread -- keep it so, or add a lock to BOTH stores.
- **EVERY FILE WE WRITE FOR THE OPERATOR GOES THROUGH `utils_file.OpenReportFile` /
  `CloseReportFile` (issue 313, M13 -- 2026-11-16).** The new file is `<name>.partial`
  and REPLACES the old one in one operation only when every write succeeded
  (`MoveFileExW` + `MOVEFILE_REPLACE_EXISTING` on Windows, because the RTL's `RenameFile`
  is `MoveFileW` and refuses to replace; `rename(2)` elsewhere). **The failure is kept
  PER HANDLE** (a slot table in `utils_file`, `ReportFileProblem(h)`): a failed write to
  any other file neither fails a report nor masks one. A report written with
  `Write`/`WriteLn` uses `OpenReportText` / `CloseReportText` -- a Text bound to the same
  checked handle, so the RTL still formats the bytes -- and PostUnit wraps both as
  `OpenExportTextNamed` / `CloseExportText` (which warn once and set `LastExportFailed`).
  **A `Text` report is closed with `CloseExportText`, NEVER `Close(t)`, and an early
  `Exit` after the open must abandon it (`CloseExportText(t, False)`).** Preview a
  report only when the close kept it. The hour, continent, country, first-call (two),
  zone and band-change reports, both `logscp` ASCII dumps and the band-map file are on
  it; `uTestPostUnitReports` pins seven reports' exact text (goldens made by the code
  before the move) and `uTestUtilsFile` the helper. A new `OpenFileForWrite` /
  `tOpenFileForWrite` for an export is the defect this bullet exists to prevent.
- **WHERE A DOWNLOADED DATA FILE GOES — and it is NOT where the shipped one is.** Alt-O
  (CTY.DAT), the TRMASTER.DTA download and the POTA park list all write to
  `uAppPaths.DownloadedDataFilePath`, the **settings** directory, and the lookup prefers that copy
  over the shipped one. `DataDir` is wrong on all three platforms: on Windows it is the working
  directory, which on a developer's machine is the repository (the tracked `tr4w/target/cty.dat`
  was being overwritten every time); on macOS it is inside the signed, notarized `.app`; on Linux
  an AppImage mounts read-only. `FCONTEST.SetUpFileNames` owns the order —
  **downloaded → contest directory → shipped** — and logs which tier answered. Compose the path in
  `uAppPaths` and nowhere else; `Lint-AppPaths` fails the build otherwise.
- **The corpus stays pinned to the TRACKED country file through `--settings`**, which moves the
  writable directory with it: the fixture directory holds no CTY.DAT, so the lookup falls to the
  shipped copy. **Verified 2026-09-24** by planting a bogus `CTY.DAT` in `tr4w/target/settings/`
  and re-running: still `24 passed, 0 failed, 2 known-divergence`, and all 26 exports logged
  `(shipped)`. If you ever make the corpus read a developer-writable location, you have turned the
  oracle into a machine-dependent test.
- **A download that reports success is not a reload.** `CTYDownloadFinished` reloaded
  `TR4W_CTY_FILENAME` — the file resolved at STARTUP — so on macOS it said *"downloaded…
  reloading… reloaded successfully"* having reloaded the old bundle copy. It repoints the name at
  the file it just wrote now.
- **An ADIF `CONTEST_ID` is resolved by the CONTEST FACTORY, not by `uADIF`.**
  `uADIF.GetContestByADIFName` only caches; the rule is
  `uContestRegistry.FindContestByADIFContestId` — input trimmed, a blank matches
  nothing, every contest's current id first, then each class's
  `FormerADIFContestIds`. A renamed id keeps its old spelling as a former id so
  operators' existing files still import (NY4I, 2026-09-29). It used to return a
  contest always and let the caller compare, which matched an **empty**
  CONTEST_ID to the first blank row.
- **Export and import ask ONE getter for a contest's `CONTEST_ID` (M1,
  2026-10-01).** `TContestBase.ADIFContestId` is `ADIFName`, else the enum's
  spelling, and `uADIF.EmitADIFRecord` writes
  `uContestRegistry.ContestIdentity(c).ADIFContestId` — the same object the
  lookup matches. Before M1 export spelled that fallback itself while the
  getter said `''`, so TR4W could not re-import its own export for 139 contests
  (inventory D9). `uTestADIFRegression.Test_ContestID_EveryContestReimportsItsOwnExport`
  pins every `ContestType`. The exceptions: POTA and GENERALQSO write no
  `CONTEST_ID` (an `in [...]` test in `uADIF`, waiting on a POTA class), and
  RSGB-ROLO is the row id of both RoLo runnings, so SSB reads back as CW. The
  external logger (DXKeeper) sends the same getter's id since M1 — it used to
  send the bare enum spelling. A contest that gains an id still lists its old
  enum spelling as a former one.
- **WHICH ADIF EXCHANGE TAGS A RECORD CARRIES IS THE CLASS'S (2026-10-17,
  NY4I: "We should not just be exporting all possible fields").**
  `uADIF.EmitADIFRecord` writes only the QSO's own fields (CALL, BAND, times,
  MODE, FREQ, STATE, OPERATOR, APP_TR4W_ID, the X-QSO flag) and asks the QSO's
  contest for the rest: `EmitADIFReportFields` (RST_SENT/RST_RCVD -- EVERY
  QSO'S, NY4I 2026-10-17 "Every QSO", never gated by the class) and
  `EmitADIFReceivedFields` (QTH, PRECEDENCE, CHECK, NAME, the `ADIFPowerTag`,
  SRX, STX, TEN_TEN, AGE). The latter's base writes exactly the fields the
  class's `ReceivedExchangeFields` declares; STX is the exception (ours, written
  whenever the QSO has a serial -- D7 wrote it for every contest). They are two
  methods because the record's order is part of the corpus's bytes. A station-
  dependent list (ARRL DX) needs the object that carries the station:
  `EmitADIFRecord(rec, aContest)` takes it, PostUnit passes `ActiveContest`,
  and it is used only for a QSO of its own contest (`IsContestOfQso`). D7
  wrote every non-empty field, so this is NOT a port: Winter Field Day's
  reference carries four stray PRECEDENCE and one stray NAME its class does
  not declare, accepted and pinned (NY4I: "Accept and pin") in
  `winter_fd_2025_w4ta/known.adi.diff` -- see
  `docs/CONTEST_OWNERSHIP_DESIGN.md` 8.2w. Pinned by
  `uTestADIFReceivedFields`. A new tag from the exchange goes in the class's
  field list, never back into uADIF.
- **THE EXCHANGE COLUMNS AND CONTEST FIELDS ARE THE CONTEST'S (M4,
  2026-10-01).** **THE CABRILLO COLUMNS ARE THE CLASSES' SINCE M11 S9c
  (2026-10-14):** `uCabrilloExchange` holds 56 named helpers (27 sent, 29
  received -- `CabrilloSentRSTState`, `CabrilloReceivedRSTQTH` ... one per
  distinct column, same `(aMy, aQso, aCtx)` signature) and every contest class
  states `GetCabrilloSentExchange` / `GetCabrilloReceivedExchange` by calling
  them -- no enum selects one, `FormatCabrilloExchangeOfKind` and
  `TCabrilloQSOContext.SessionExchange` are deleted, the base writes
  `CabrilloExchangeErrorMarker` in both columns, and the public non-virtual
  `FormatCabrilloSentExchange` logs the Error naming the contest. **PostUnit
  asks `ActiveContest` (the object holding the station), not `ContestIdentity`,
  when the contest has a class** -- nine contests' columns move with the
  entrant (ARRL 160, 7QP, Arizona, NEQP, Texas, Salmon Run, JIDX, PACC), and
  `ContestIdentity` has no station. Fifteen contests write the marker today
  (plan F26). Pinned by `uTestCabrilloColumns` (every ContestType x 7 stations
  x 8 inputs, literals made by the old machine). **THE ADIF `STX_STRING` IS THE CLASSES'
  SINCE M11 S9b (2026-10-14):** `uADIFExchange` holds 24 named helpers
  (`ADIFSentRSTState`, `ADIFSentRSTQSONumber` ... one per distinct OUTPUT,
  same `(aMy, aQso)` signature), and every contest class states
  `GetADIFSentExchange` by calling one -- no enum selects it. A helper reads
  the station's fields through the machine's own widths (20 for the state,
  name and zone, 7 for the grid, 10 for the park), so an over-long value is
  cut as it always was. **NO PLACEHOLDER STANDS IN FOR AN EXCHANGE (F25/F26/F27,
  2026-10-14; NY4I: "report an error as the silent error is not good").** The
  Cup RF CW/SSB/DIG, CQ WW RTTY and the Youth Championship RF export the text
  their own Cabrillo sent column prints (`ADIFSentQSONumberStateShort`,
  `ADIFSentRSTZoneStateDX`, `ADIFSentStateQSONumber2`); the old
  `Error generating my exchange` and `None` answers and `ADIFSentNotBuilt` /
  `ADIFMyExchangeErrorMarker` are DELETED. A contest with no layout (the base
  and the fourteen of F26) calls `ADIFSentNotImplemented`, which RAISES
  `EADIFExchangeNotImplemented`; the public non-virtual
  `TryFormatADIFSentExchange(aMy, aQso, out aSent, out aFailure)` catches that
  or any helper's exception, logs an Error naming the contest and the QSO
  (call, band, mode, time), answers False and `''`, and PostUnit leaves
  `STX_STRING` out of that record (`EmitADIFField` omits an empty value) and
  warns ONCE per export (`BeginExchangeFailureReport` / `NoteExchangeFailure` /
  `ReportExchangeFailures`, through `showwarning`, which is log-only in a
  headless /EXPORT). The Cabrillo marker `ERROR EXCHANGE NOT HANDLED` stays in
  the file (Issue #1043, deliberate) but is counted and reported the same way,
  and the Cabrillo writer's `except` is an Error plus a warning now, not a
  debug line. **A new `try ... except` returning a marker in an export path is
  the defect this paragraph exists to prevent.** `FormatADIFSentExchange(aMy,
  aQso)` is the same call for text only. **PostUnit's `ExchangeContest(aStation)`
  picks the object that formats the exchange: the `ActiveContest` object (it
  carries the station) when the contest has a class, else `ContestIdentity`** --
  F27: S9b asked `ContestIdentity` for the ADIF string, so a Japanese JIDX
  entrant exported the prefecture layout. Pinned by `uTestADIFSentExchange`
  (every ContestType x 7 stations x 4 inputs, plus the reporting test). The
  ADIF import's grid test is
  the open contest's `ReceivesGridSquareExchange`, not a kind. PostUnit asks
  `ContestIdentity(c)` for the `QSO:` layout, and `ExchangeContest` for the
  two Cabrillo columns and the `STX_STRING`, and the tail asks `EmitADIFContestFields` for the worked
  station's fields (ARRL_SECT, CLASS, DOK, IOTA, APP_TR4W_HQ, GRIDSQUARE);
  `uADIF.EmitADIFRecord` asks `ADIFPowerTag` (RX_PWR / FOC_NUM) and
  `WritesADIFContestId`. **Do not put a contest test back in these units** --
  the `Lint-ContestNameTests` ceiling for both exchange units is 0 now. POTA
  and ARRL 160 are the two contests the tail still names, with the reason
  beside each. A contest-field change shows in the corpus only for the 13
  sets; the contest matrix sees every contest, and
  `uTestContestExport.Test_RoundTripThroughTodaysImport` pins export against
  import, WAG's DOK and the RSGB IOTA's IOTA included (M5a: both are read
  back by their classes).
- **A QSO party's ADIF `STATE`/`CNTY` and the Cabrillo sent zone ask the
  CONTEST, not a table (M10 S6, 2026-10-14).** **STATE IS THE WORKED
  STATION'S, PER QSO, since Q76/Q89 (NY4I, 2026-10-16: "if you write STATE in
  ADIF, that is the state of the worked station"; the entrant's is
  MY_STATE).** `EmitADIFRecord` asks `uADIF.GetADIFStateForQSO(rec)` -- the
  class's `ADIFWorkedStationState` (base `''`): a party county gives its
  state (`ADIFCountyState`), an out-of-state station's state or a VE's
  province is written as itself when `uADIF.IsADIFPrimarySubdivision` allows
  that code for the station's CTY country (K: 48 states + DC; KL: AK; KH6:
  HI; VE: 13 provinces), DX or anything else gets none. The QTH judged is
  `uADIF.ADIFPartyQTHKey` -- the domestic table's key, else the logged QTH --
  because aliases (`CON`, NEQP's `AD`) can be any length while every county
  key is longer than two letters and every state/province key is two. D7's
  rule -- the HOST's state on every QSO with a QTH, `GetStateForContest` --
  is deleted; British Columbia, which wrote no STATE at all, now writes it.
  PostUnit's CNTY prefix is `ADIFCountyState` (so an out-of-state QSO writes
  no CNTY) and it writes CNTY only where `WritesADIFCounty` is True: every
  state party but BC (ADIF's CNTY enumeration defines nothing for Canada),
  no multi-state party. Pinned by `uTestContestExport.Test_ADIFStateIsTheWorkedStations`
  and `Test_EveryPartyAndOnlyAPartyWritesAState`. Corpus: michigan's four
  out-of-state records are pinned in `michigan_qp_2026_ny4i/known.adi.diff`.
  `postunit.ZoneSentForThisContest(aContest)` and the ADIF CQZ/ITUZ block
  ask ONE source, the contest's `ZoneMultiplierZones` (M11 S5; plan F4,
  which once had them on two), and the block's CTY-zone-mode fallback asks
  `ContestHasZoneMultiplier` on the same object (S5 part 2: the zone kind
  and `ZoneMultiplierType` are deleted). The Croatian writes a CQ zone as
  ITUZ and CW Open the inverse -- transcribed, F5/Q95 open.
  The county-line IMPORT asks the class since S7 (`ContestAllowsCountyLineOnImport`:
  Michigan stopped clearing the dupe flag; Arizona, BC, Virginia, Salmon Run
  and New York started). `uADIF.ResolveRoverCall` (rover call on EXPORT) still
  reads the row's `CountyLineAllowed` ON PURPOSE: a rover is not a county line,
  the class has no property for it, and S8 cannot delete the field until NY4I
  answers Q90.
- **THE ADIF IMPORT IS GENERIC FIRST, THEN THE CONTEST'S (M5a, 2026-10-01).**
  `uADIF.ApplyADIFFieldsToExchange` is contest-blind: it maps the standard tags
  and captures every tag whose meaning is the contest's into
  `TADIFRecordTemps` (a record that lives in `uContestBase` and is aliased in
  `uADIF`). After the WHOLE record is read, `ApplyADIFCommonImport` does what
  every contest wants (the operator, the received RST off SRX_STRING) and
  `ApplyADIFContestImport` asks `ContestIdentity(exch.ceContest).ApplyADIFImport`
  -- the base's default is the old classless `else`, keyed on a
  `TADIFImportSession` handed in as DATA (the open contest's grid-square,
  grid-exchange and domestic-multiplier answers `CountsGridSquares`,
  `ReceivesGridSquare` and `DoingDomesticMults` -- the session's domestic KIND
  and its "not none" until M11 S6, its exchange kind until S9b -- and the
  operator; the contest reads no global). **Do not read
  `exch.ceContest` inside `ApplyADIFFieldsToExchange`**: ADIF fixes no field
  order, and the `APP_N1MM_EXCHANGE1` arm that did is the order bug this
  replaced (`uTestContestImport.Test_N1MMTagOrderDoesNotMatter`). A new tag
  whose meaning is a contest's is a field of `TADIFRecordTemps` plus the enum
  entry and name in `uADIF`, and the interpretation goes in that class. Two
  classless contests still own an arm in `MainUnit.ApplyClasslessADIFImport`
  (POTA: design Q6; ARRL 160: its scoring needs the domestic-country list), and
  it is deleted when each gains a class. The contest matrix has an `== import`
  section (design 8.2f): a change to import shows there for every contest.
- **THE CABRILLO HEADER'S CONTEST LINES AND THE MODE COLUMN ARE THE
  CONTEST'S TOO (M9a, 2026-10-02).** PostUnit asks `CabrilloContestName`
  (General QSO's title), `RequiresCabrilloLocation` (ARRL 10, Winter Field
  Day), `CabrilloHeaderLinesBeforeTag` (Winter Field Day's `ARRL-SECTION:` /
  `X-EXCHANGE:` before `LOCATION:`, written through `UTF8Encode` -- X-EXCHANGE
  used to be an implicit ANSI conversion, identical for every legal FD class)
  and `CabrilloModeString` for every QSO line; the base calls
  `uCabrilloFormat.FormatCabrilloMode`, and PostUnit's inline copy of that
  helper is deleted. **HamScore's one-QSO line (`uCabrillo`) asks the QSO's
  contest's `CabrilloModeString` too, since Q54 (2026-10-16)**, so the file
  and HamScore cannot spell a mode differently; Winter Field Day's PH
  override is deleted (FM is `FM`, still scored as phone), and Delaware is
  the one contest left writing FM as PH. HamScore's own mode map
  (`MapModeForRTC`, dead since RTC 3.0) is deleted. The summary sheet asks
  `SummarySheet` and the hour report `ReportsRunningScore`. The corpus sees the
  header for its Winter Field Day and General QSO sets; nothing else does.
- **A BLANK CATEGORY-* STILL WRITES ITS LINE, BARE (2026-10-29, NY4I).**
  `uCbrSum.CabrilloHeaderTagLine` is the one rule: `TAG: value`, or
  `CATEGORY-OVERLAY:` (no trailing space) for any of the nine category tags
  with no value; every other blank tag is still left out. So a station that
  never stored `_CATEGORY-TIME` now gets a bare `CATEGORY-TIME:` line. Every
  category list ends in a blank "no category" item (`CategoryValuesFor`), and
  the summary window saves a chosen blank (it used to keep the old value). The
  corpus is unaffected: `golden_diff.py` drops the header except CLAIMED-SCORE,
  and every `rescored.cbr` already has all nine lines with values.
- **THE OPERATOR LIST IS ONE ROUTINE, `uOperatorList` (2026-10-25, NY4I, CQ WW SSB
  multi-op).** `OperatorListFromLog` (most contacts first; ties alphabetical, a TOTAL
  order; no TStringList sort, whose quicksort pivot is random) is what
  `uCbrSum.CabrilloTagText(ctOperators)` answers, so the Cabrillo `OPERATORS:` line,
  the 3830 report and the summary sheet cannot differ; the summary dialog's row is
  read-only and `_OPERATORS` is `ctrSave: False`. A "contact" is
  `LogRecordIsContact` -- rkQSO, not deleted, with a band and a mode -- which
  PostUnit's `GoodLookingQSO` now calls, so the list and the QSO lines count the same
  records (the 3830 report printed the stored field, and the old count included
  NOTE rows). The separator is still `, ` (`OPERATOR_LIST_SEPARATOR`): the D7
  references of winter_fd, arrl_fd and arrl_ss_ssb hold `A, B, C`, and the Cabrillo 3.0
  header is read as space-delimited -- changing it is NY4I's decision, and the
  corpus compares only QSO lines, not the header, but the frozen rescored.cbr would move.
  Pinned by `uTestOperatorList`.
- **THERE IS ONE CABRILLO HEADER STORE, `CABRILLOSECTION` (issue 74, 2026-11-22).**
  ERMAK is gone: `ErmakSpecification`, `cfErmakSpecification`, `ERMAKSECTION`,
  `ERMAK_` and the ERMAK overlay/category values are deleted. Until then a Russian
  MY CALL in ~22 flagged Russian contests (ALRS UA1DZ Cup, Arktika Spring, Cup RF,
  RDA, Gagarin...) read and wrote the header from `ERMAKREPORT` -- GUI only, set in
  `CreateMainWindow`, so no corpus, matrix or headless test ever saw it. Its
  OPERATORS line had already been restored by issue 326. `uRadioConfigStore` still
  maps `ERMAKREPORT` <-> `ermakHeader` so old settings files round-trip; nothing
  reads it. Pinned by `uTestOperatorList.Test_Header_StoreHasNoErmakSection`.
- **THE STATE SENT IS NOT MY STATE (M9a, design 7.11).** The Cabrillo sent
  column and the ADIF `STX_STRING` read `FCONTEST.SentMyState` -- MY STATE,
  unless the contest's set-up states what it sends instead (Canada Day/Winter
  and the Russian DX contests send none from outside; the Cup RF sends the
  grid). Never read `Settings.My.State` for a sent exchange.
- **`StateFromARRLSection` (`uARRLSections`) is the one section-to-state
  table** -- PostUnit's and Tree's layered copies were merged into it at M4.
  Since issue 275 (2026-11-15) the one-province RAC sections (AB BC MB NB NL
  NS PE QC SK) answer their province and GH answers ON; TER, NT, NWT, MDC, PR
  and VI answer none (NY4I: a state only when certain). Field Day / Winter FD
  ADIF therefore writes STATE for those VE QSOs. The N1MM UDP `<section>` is
  NOT an ADIF field: it sends the resolved section only where the contest's
  QTH is an ARRL section (`ExternalLoggerARRLSection`), else the QTH as logged.
- **CTY.DAT reloads.** A reload wrote past the end of the country table
  (`b56e1ef9`); the table is sized, and a reload is not a fresh start.
- **OUR STATION'S ADIF TAGS ARE THE RECORD'S, not the session's (log schema 3,
  stage 2, 2026-10-18).** Import reads STATION_CALLSIGN and the MY_* tags into
  the row's my_* columns (`uADIF.MyFactsFromADIF`); since log schema 9
  (2026-11-17) also MY_NAME and MY_POSTAL_CODE -- but MY_NAME ALONE does not
  count as naming our station (it names the operator), and the four schema-9
  facts ADIF has no tag for (FD class, check, precedence, FOC number) take the
  contest's even when the file's station is kept. Export does NOT yet write
  MY_NAME / MY_POSTAL_CODE (it would re-freeze the contest matrix). A record
  naming no MY_ tag
  is STAMPED with this contest's values, as a new QSO would be; a file that
  names some is reported, and the operator chooses (NY4I, 2026-10-18; headless
  keeps the file's). STX_STRING is the row's `exchange_sent`
  (`SentExchangeFromADIF`), never rebuilt from the live station. Export writes
  them AFTER the contest's tail (`EmitADIFMyStationFields`), and **a tag the
  contest already wrote wins** (POTA's park, MY_STATE, MY_DXCC). A row written
  before schema 3 writes exactly what it always did. `TContestTailEmitter` now
  takes the row's `TQsoMyFacts` and its `exchange_sent`. **Since stage 4 the
  sent exchange and our call are the record's too**: STX_STRING and the Cabrillo
  sent columns are built from the row's station, an imported row's STX_STRING
  is written back verbatim, and STATION_CALLSIGN / the `QSO:` call are the
  row's `my_call`, else the log's declared call, never today's ahead of them. Detail: `docs/SQLITE_LOG_SCHEMA_PLAN.md`
  §12h. `test-adif-roundtrip.sh` has a MY_ case.

- **THE EXPORT FILE NAMES ARE THE LOG'S (2026-10-26, NY4I).** `uLogDatabase.LogExportFileName(log,
  kind)` is the ONE rule: the log's name with `.adi`, `.log` or `.csv` (lowercase on every platform --
  case is real on Linux and macOS), in the log's directory. PostUnit's `NameReportsFileAfterLog`
  moves it into `tReportsFilename` for the ADIF, the Cabrillo and the CSV. The Cabrillo used to be
  `<MYCALL>.LOG`, so every contest of one operator overwrote the last; the per-band EDI is the one
  export still named by call. A sponsor who wants the call as the file name (Georgia QP, Russian DX)
  means a manual rename. **The corpus scripts that run the app in `tr4w/target` give a run a private
  stem (`$WORK`), so its Cabrillo is `"$WORK.log"` and nothing else** -- the folder-snapshot helpers
  are gone and `corpus_cleanup_on_exit` (corpus-lib.sh) removes `$WORK.*`, `$WORK-*` and `$EXE` on any
  exit. Pinned by `uTestLogDatabase.TestExportNames*`.

## A rover's QSO in the exports (issues 133/87, 2026-11-19)

- The sent exchange of a row with `my_rover_qth` sends THAT place in the
  state slot (`PostUnit.CurrentMyStationExchange(contest, facts, rec.ceRoverQTH)`
  -> `uContestBase.MyStationExchangeWithRoverPlace`): ADIF STX_STRING and the
  Cabrillo sent column. A row without one exports byte-for-byte as before.
- `my_county` (MY_CNTY) of such a row is the ADIF county the place lies in
  (`RoverPlaceADIFCounty`, the worked side's CNTY rule `ADIFCountyOfQSO`, lifted
  once). Since schema 13 the unit sent is `my_sent_unit` and `my_state` the
  host state; the Cabrillo QSO-line call is assembled (below).
- **THE COUNTY NAME IS THE PARTY'S COUNTY FILE'S (2026-11-20)**:
  `ADIFCountyOfQSO` asks `TContestBase.CountyFileCountyName(QTH)` (the party
  base reads its `<base>_cty.dom` once, beside the multi-province host map),
  NOT the session's multiplier list's AltName. An in-state session's list
  files every county under the host state (`Pin > Fl`), so an in-state
  station wrote no CNTY for an in-state county and no MY_CNTY. Out of state
  the answer is the list's, key for key (pinned). The key is the typed QTH,
  upper cased, cut to ten -- an ALIAS (Michigan's `PRES` for `Presq`) still
  names no county, as before. Names come from the SHIPPED file only: a name
  corrected in an operator's override `.dom` does not reach CNTY.
- **ONE CABRILLO PER ACTIVATION (rover step F, 2026-11-19)** where the class
  answers `TContestBase.SplitsCabrilloByActivation` (base False; HAWAII
  ALONE, its rules: "a separate log for each activation"), the log roved (one
  `LogSourceHasRoverQSO` query -- a log that never roved is not walked twice)
  and two places or more: `PostUnit.CreateCabrilloFile` writes
  `<log>-<place>.log` (`LogExportFileNameTagged`) per place. The place is the
  SENT column's (`CabrilloActivationPlaceOf` = `CurrentMyStationExchange(...)
  .MyState`: rover place, else the row's sent state), so file and column
  cannot disagree. Each file's CALLSIGN and EVERY QSO line carry the
  activation's call: the log's declared call + `/place` for a place that
  roved (a boundary row's stored joined call is NOT used), the plain call for
  a place only logged before roving (agent's choice; the rules are silent).
  EVERY file's CLAIMED-SCORE is the WHOLE log's (NY4I: "all part of the same
  score"; read once). The first file is previewed, one message names all; no
  SCP upload offer for a split log. Rules: `uCabrilloActivation` (leaf);
  pinned by `uTestCabrilloActivation` (registry walk + real export). An
  unsplit file's CALLSIGN is ALWAYS the call setting as set, never a roving
  call (NY4I, 2026-11-20: "It should just be my base callsign"; a KIN/QUE
  rover's header read NY4I/KIN/QUE); its QSO lines carry the assembled call.
  A SPLIT Hawaii file's header carrying its activation (AH7RF/KOH) is the one
  exception, kept because the sponsor treats each activation as a different
  station; NY4I may rule otherwise. Stale files from an earlier
  export (a plain `<log>.log`, a place no longer in the log) are not removed.
- **ONE ADIF RECORD PER CONTACT (issue 338, NY4I 2026-11-20).**
  `PostUnit.ExportToADIF` reads each row's `qso_set_id`
  (`uLogSource.LogSourceLastQsoSetId`) and `uADIF.MergeLinkedADIFContacts`
  folds a set's rows into its FIRST (its record, station, sent exchange,
  points and claimed flag; log order kept) -- only where the record's contest
  `WritesADIFCounty`, so POTA's n-fer stays one record per park. The first
  county is CNTY / MY_CNTY; `uADIF.LinkedCountyTags` writes the set's
  distinct counties per side: the STANDARD `USACA_COUNTIES` /
  `MY_USACA_COUNTIES` (`NY,KINGS:NY,QUEENS`) when a side has EXACTLY two, and
  `APP_TR4W_CNTY_ALT` / `APP_TR4W_MY_CNTY_ALT` (#338's form,
  `US_Counties:NY/KINGS;US_Counties:NY/QUEENS`, every county) whenever it has
  two or more. Knowingly inconsistent, NY4I's ruling. **The APP_ names are
  TEMPORARY** (`ADIF_APP_COUNTIES_ALT` / `ADIF_APP_MY_COUNTIES_ALT`, the one
  place): ADIF's CNTY_ALT / MY_CNTY_ALT are only proposed, and both
  validators reject them today (3.1.8's ALT enumeration holds NZ_Regions
  only). Two districts of one county name one county (no extras). The
  contest's second ADIF file (#272) and the external-logger hand-off stay one
  record per row. IMPORT does not re-expand them (deferred: the lists carry
  county NAMES, not the party's codes, and a Hawaii county does not map back
  to its districts). Cabrillo keeps one line per row.
- **THE CALL IS ASSEMBLED (log schema 13, ruling 6)**: `my_call` is the call
  setting as set (ADIF STATION_CALLSIGN); every Cabrillo writer signs
  `uLogSource.CabrilloCallFor` = `uQsoMyFacts.AssembledCall(my_call,
  my_rover_places)`; `TCabrilloActivations.ActivationCall` uses the same
  routine. A schema-12 rover row (my_call NY4I/KIN/QUE, no places) exports
  unchanged.

## Coordinate with

`contest-scoring` (Cabrillo is scored output) · `log-database` (import lands in
SQLite; the `.TRW` is import-only) · `contest-factory` (per-contest Cabrillo
fields).

An ADIF import resolves an ARRL section the way typed entry does (#265): `TADIFImportSession.ResolveDomesticQTH` (`LOGDUPE.DomesticQTHAndKeyOf`, set by `ParseADIFRecord`; nil in `NeutralADIFImportSession`) through `uContestBase.ImportDomesticQTH`, which Sweepstakes, Field Day and Winter Field Day call. QTHString stays as written. ARRL 160 and the base (QSO party) import do not yet. Field Day / WFD STATE is `uADIF.ADIFSectionStateOf` (the resolved section first, then QTHString).
