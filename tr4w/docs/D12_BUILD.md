# TR4W — Delphi 12 Build & Test Recipe

The **actual working** build/test/oracle commands used during the D12 modernization.
(The `DCC32.EXE` recipe in the top-level `CLAUDE.md` is the old D7 command line — for D12
use the `msbuild` recipe below.)

## Prerequisites

- **RAD Studio / Delphi 12 Athens** installed at `C:\Program Files (x86)\Embarcadero\Studio\23.0`
  (Studio version `23.0` = Delphi 12). Adjust the path if installed elsewhere.
- `rsvars.bat` sets up the command-line compiler environment; every build **must** `call` it first.
- Windows; `msbuild` comes from the RAD Studio toolchain (rsvars puts it on PATH).

## Build the app (32-bit)

`rsvars.bat` is a **batch** file, so these run under **cmd.exe**. From an agent, invoke via
`cmd.exe /c` (Bash tool) or a small `.cmd` wrapper. Raw commands:

```bat
call "C:\Program Files (x86)\Embarcadero\Studio\23.0\bin\rsvars.bat"
cd /d C:\tr4w-d12\tr4w
msbuild tr4w.dproj /t:Make /p:Config=Debug /p:Platform=Win32 /v:minimal /nologo
echo EXITCODE=%ERRORLEVEL%
```

- **`/t:Make` = incremental** (only changed units + dependents; no `-B` full rebuild).
  Editing a widely-used unit (`VC`, `TF`, `tree`, `LOGWIND`, `LOGSTUFF`) cascades a large recompile.
- DCUs land in `src\` (the `.dproj` sets no `DCC_DcuOutput`). **Do not** delete DCUs or add cache wipes.
- Success = `EXITCODE=0`. Errors print as `src\Foo.pas(NNN): error E20xx: ...`.
- Output binary: **`tr4w/target/tr4w.exe`**.

One-liner form (Bash tool, `dangerouslyDisableSandbox` not needed — it's a normal build):

```bash
cmd.exe /c 'call "C:\Program Files (x86)\Embarcadero\Studio\23.0\bin\rsvars.bat" && cd /d C:\tr4w-d12\tr4w && msbuild tr4w.dproj /t:Make /p:Config=Debug /p:Platform=Win32 /v:minimal /nologo & echo EXITCODE=%ERRORLEVEL%'
```

Filter output to just errors/exit with `... | Select-String -Pattern "error|E20|F20|EXITCODE"` (PowerShell)
or `grep -E "error|E20|F20|EXITCODE"` (Bash).

## Build the unit tests

```bat
call "C:\Program Files (x86)\Embarcadero\Studio\23.0\bin\rsvars.bat"
cd /d C:\tr4w-d12\tr4w\test\unit
msbuild tr4w_unit_tests.dproj /t:Make /p:Config=Debug /p:Platform=Win32 /v:minimal /nologo
echo BUILD_EXIT=%ERRORLEVEL%
```

The DUnit-compatible runner links only the pure/leaf `src` units (ADIF, Cabrillo, callsign, mults,
CTY.DAT, band, CRC32, grid/distance, text/file/math, Icom CI-V, Flex, freq/time). It does **not**
link the TRDOS contest engine (needs the app's globals booted), so `ProcessExchange`/scoring/dupe
are not unit-covered — the corpus below is their regression net.

## Golden-master corpus (the regression oracle)

This is how we prove a change is behavior-preserving. It runs the app's headless batch-export mode
(`tr4w.exe "<contest>.CFG" /EXPORT`, added in `tr4w.dpr` — boots the contest, writes `<log>.ADI` +
`<CALL>.LOG` with a `-D12` banner, then `Halt`s before GUI/network init) for each corpus set and
byte-diffs the ADIF + Cabrillo (`QSO:`/`X-QSO:`/`CLAIMED-SCORE:` lines) against the frozen **D7** refs.

**Always rebuild the app first**, then, from `C:\tr4w-d12`:

```bash
bash tr4w/test/corpus/export-d12-corpus.sh                 # all sets, then sweep
bash tr4w/test/corpus/export-d12-corpus.sh <slug>          # one set (smoke test)
```

- **Baseline: `22 passed, 0 failed, 4 known-divergence, 0 awaiting-candidate`.** That is GREEN.
- Fail-loud (`GOLDEN_STRICT`): a set with a ref but no *fresh* candidate is a **FAIL** (a stale/aborted
  export can't mask a gap).

### ⚠ Collision guard (important)

The corpus launches `tr4w.exe` once per set and uses `tr4w/target/`. **If the user is running TR4W,
every set collides and reports FAIL** (a false alarm — seen twice, once as `8/22`, once as `0/22`).
**Before every corpus run**, check:

```powershell
$p = Get-Process -Name tr4w -ErrorAction SilentlyContinue
if ($p) { "tr4w RUNNING (pid $($p.Id)) -- HOLD the corpus" } else { "not running -- safe" }
```

If it's running, wait / ask the user to close it. **Also: run the corpus, read the result, THEN commit**
— do not chain the corpus run and `git commit` in one shell block (a false FAIL then looks committed).

## Quick reference

| Task | Command (after `call rsvars.bat`) | Green signal |
|------|-----------------------------------|--------------|
| Build app | `cd /d C:\tr4w-d12\tr4w & msbuild tr4w.dproj /t:Make /p:Config=Debug /p:Platform=Win32` | `EXITCODE=0` |
| Build tests | `cd /d ...\test\unit & msbuild tr4w_unit_tests.dproj /t:Make ...` | `BUILD_EXIT=0` |
| Corpus oracle | `bash tr4w/test/corpus/export-d12-corpus.sh` (rebuild first; guard tr4w not running) | `22 passed, 0 failed, 4 known-divergence` |
| App binary | — | `tr4w/target/tr4w.exe` |
