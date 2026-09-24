---
name: file-formats
description: File formats and data interchange — ADIF, Cabrillo, CTY.DAT, TRMASTER.DTA/Super Check Partial, and the binary log import path. Use for import/export defects, malformed output, header or field mapping questions, country-file updates, or anything the golden corpus byte-diffs.
tools: Read, Grep, Glob, Bash, Edit, Write
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
references. Baseline **`24 passed, 0 failed, 2 known-divergence, 0
awaiting-candidate`, and every export run must exit 0.**

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
- **CTY.DAT reloads.** A reload wrote past the end of the country table
  (`b56e1ef9`); the table is sized, and a reload is not a fresh start.

## Coordinate with

`contest-scoring` (Cabrillo is scored output) · `log-database` (import lands in
SQLite; the `.TRW` is import-only) · `contest-factory` (per-contest Cabrillo
fields).
