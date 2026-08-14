# TR4W — Build & Test Recipe

> **Renamed from `D12_BUILD.md` on 2026-08-13.** The file is deliberately named for the *job*
> rather than the *compiler*, because it has now gone stale twice — once when D7 gave way to
> Delphi 12, and again when Delphi 12 gave way to FreePascal.

**Toolchain: FreePascal 3.2.2 + the Lazarus LCL.** Delphi is behind us. The FPC build passes the
unit tests (3978/0) and the golden corpus (22/0/4), runs the LCL UI, and is what ships.

## Prerequisites

Install these; nothing else is configured by hand.

- **FPC able to target i386-win32** — `fpc.exe` plus a `ppc386`/`ppcross386` backend and an
  i386-win32 RTL. `fpc.exe` is only a *driver*; an x86_64-only install has no i386 backend and
  cannot build TR4W.
- **Lazarus carrying LCL units for i386-win32** (`<lazarus>\lcl\units\i386-win32`). An
  **x86_64-only install — the fpcupdeluxe default — will not do.**
- **NSIS** (`makensis.exe`), only for `-BuildInstaller`.
- Indy 10.6.3.3 is **vendored** in `tr4w\include`. Nothing to install.

Locations are **discovered**, not configured. `tr4w\build\Find-Toolchain.ps1` searches PATH, the
usual install roots, and the `FPC_HOME` / `LAZARUS_DIR` environment variables, and prints every
path it tried when it fails. Pin them explicitly on CI:

```powershell
$env:FPC_HOME    = 'C:\FPC\3.2.2'
$env:LAZARUS_DIR = 'C:\Lazarus'
```

**A pin is authoritative.** If `FPC_HOME`/`LAZARUS_DIR` (or `-Fpc`/`-Laz`) names something that
cannot build TR4W, the build **fails** naming what was rejected — it does not quietly fall back to
another install. That distinction matters on a runner, where a silent substitution means you are
shipping from a toolchain nobody configured.

## Everything at once

```powershell
.\tr4w\FullBuild.ps1                    # lints -> unit tests -> app -> tr4wserver
.\tr4w\FullBuild.ps1 -BuildInstaller    # + the NSIS installer
```

Or the wrappers, which work from any directory:

```bat
utils\Build.cmd
utils\BuildEnglishInstaller.cmd
```

Order is deliberate: **a failing test stops the build before it produces a binary anyone could
ship.** The version comes from `tr4w\src\Version.pas`; the script *fails* rather than defaulting if
it cannot parse it, and afterwards checks the linked `tr4w.exe` actually reports that version — so
a version resource that failed to link cannot ship silently.

**One build, English only.** The nine per-language variants are gone; translation moves to
`resourcestring`. Don't reintroduce a language loop.

## Iterating

```powershell
.\tr4w\build\Build-App.ps1                 # full rebuild (-B), the safe default
.\tr4w\build\Build-App.ps1 -Incremental    # seconds instead of minutes
.\tr4w\build\Build-Tests.ps1 -Run          # build the suite, then run it
.\tr4w\build\Build-Server.ps1              # tr4wserver
```

- **`-Incremental` is for chasing one defect, not for believing a result.** FPC's mtime rule cannot
  see a changed compiler switch, a changed `.inc`, or a define flip. Do a full build before you
  commit on anything.
- **A designed form is two files and FPC only watches the `.pas`.** Editing a `.lfm` leaves the
  `.pas` older than its unit file, so an incremental build silently keeps the previous resource.
  `Build-App.ps1` touches a `.pas` whose `.lfm` is newer to compensate.
- Intermediate output goes to `build-out\` at the repo root (gitignored). Binaries land where they
  ship: `tr4w\target\tr4w.exe` and `tr4w\tr4wserver\tr4wserver.exe`.
- **The unit-test exe must live in `tr4w\test\unit\`** — several suites resolve their data relative
  to `ParamStr(0)`, not the working directory (`fixtures\`, `..\..\target\cty.dat`). Built anywhere
  else you get 30 red CTYDAT tests and a bare RTE 217, neither of which names the real cause.

## Lints

`tr4w\build\Run-Lints.ps1` runs all ten, and `FullBuild.ps1` calls it. They previously lived only in
`tr4w.dproj`'s PreBuildEvent, so msbuild ran them and **nothing else did** — an FPC build saw none.
Add a lint by editing the one array in that script.

`Lint-LFMProperties` is the odd one out: it compiles a small FPC helper (`build\lintlfm\`) that links
the LCL and asks the same RTTI the form loader uses, because "does this class publish this property,
and is this a legal value for it" cannot be answered by grepping a `published` block. It fails
*closed* if FPC or the LCL is missing — a lint that cannot run must not look like a lint that found
nothing.

## Unit tests

3978 tests, 0 failures is the baseline. The DUnit-compatible runner links the leaf `src` units
(ADIF, Cabrillo, callsign, mults, CTY.DAT, band, CRC32, grid/distance, text/file/math, Icom CI-V,
Flex, freq/time). It does **not** exercise the TRDOS contest engine, which needs the app's globals
booted — so `ProcessExchange`, scoring and dupe are covered by the corpus below, not here.

It does currently link the LCL, transitively: a suite links `uCAT`, and `uCAT` uses `uPrefsForm`.
That is worth removing at the `uCAT` seam — a unit-test binary should not depend on a UI toolkit.

## Golden-master corpus (the regression oracle)

How we prove a change is behaviour-preserving. It runs the app's headless export
(`tr4w.exe "<contest>.CFG" /EXPORT` — boots the contest, writes ADIF + Cabrillo, then `Halt`s before
any GUI or network init) for each corpus set and byte-diffs both artifacts against frozen **D7**
references.

**Rebuild the app first**, then from the repo root:

```bash
bash tr4w/test/corpus/export-d12-corpus.sh            # all sets, then sweep
bash tr4w/test/corpus/export-d12-corpus.sh <slug>     # one set (smoke test)
TR4W_EXE=other.exe bash tr4w/test/corpus/export-d12-corpus.sh   # a different binary in target\
```

- **Baseline: `22 passed, 0 failed, 4 known-divergence, 0 awaiting-candidate`.** That is GREEN.
- Fail-loud: a set with a reference but no *fresh* candidate is a **FAIL**, so a stale or aborted
  export cannot mask a gap.

### ⚠ Collision guard (important)

The corpus launches `tr4w.exe` once per set and uses `tr4w\target\`. **If you are running TR4W,
every set collides and reports FAIL** — a false alarm, seen twice (once as `8/22`, once as `0/22`).
TR4W is single-instance: the second process hits the mutex and exits *before* the `/EXPORT` handler,
so it writes nothing. Check first:

```powershell
$p = Get-Process -Name tr4w, tr4w_fpc -ErrorAction SilentlyContinue
if ($p) { "RUNNING (pid $($p.Id)) -- HOLD the corpus" } else { "not running -- safe" }
```

**Run the corpus, read the result, THEN commit.** Never chain the corpus run and `git commit` in one
shell block — a false FAIL then looks committed.

## Proving a clone builds

```powershell
.\tr4w\build\Test-FreshClone.ps1 -WithInstaller
```

Clones HEAD to a temp directory, builds with **no arguments**, asserts the artifacts exist, and
diffs the binary sizes against the working tree's. That last check is not decoration: it caught an
untracked `tr4wserver.res` being linked into the shipping server binary, making it 152 KB larger
here than in any clone. Nothing visible from inside the working tree could have shown that.

## Quick reference

| Task | Command | Green signal |
|------|---------|--------------|
| Everything | `.\tr4w\FullBuild.ps1` | `BUILD SUCCESSFUL` |
| Everything + installer | `.\tr4w\FullBuild.ps1 -BuildInstaller` | `tr4w_setup_<version>.exe` |
| Iterate | `.\tr4w\build\Build-App.ps1 -Incremental` | `BUILD OK` |
| Unit tests | `.\tr4w\build\Build-Tests.ps1 -Run` | `PASSED: 3978  FAILED: 0` |
| Lints only | `.\tr4w\build\Run-Lints.ps1` | `10 lint(s) passed` |
| Corpus oracle | `bash tr4w/test/corpus/export-d12-corpus.sh` | `22 passed, 0 failed, 4 known-divergence` |
| Clone-and-build | `.\tr4w\build\Test-FreshClone.ps1 -WithInstaller` | `FRESH CLONE OK` |
| App binary | — | `tr4w\target\tr4w.exe` |

---

## ~~Delphi 12 (superseded 2026-08-13)~~

~~Kept only so an old build can be reproduced for comparison. `tr4w\FullBuild-D12-deprecated.ps1`
is the matching script. **Do not run it and `FullBuild.ps1` in the same tree** — they write the same
file names from different compilers.~~

~~Prerequisite: RAD Studio / Delphi 12 Athens at `C:\Program Files (x86)\Embarcadero\Studio\23.0`.
`rsvars.bat` is a **batch** file and must be `call`ed first to put msbuild on PATH.~~

```bat
call "C:\Program Files (x86)\Embarcadero\Studio\23.0\bin\rsvars.bat"
cd /d C:\tr4w-d12\tr4w
msbuild tr4w.dproj /t:Make /p:Config=Debug /p:Platform=Win32 /v:minimal /nologo
echo EXITCODE=%ERRORLEVEL%
```

~~`/t:Make` is incremental; `/t:Build` is a full rebuild and was required before committing anything
that changed a class hierarchy, because `Make` skips up-to-date units and hides a `W1020`
missing-abstract-method warning. DCUs landed in `src\`.~~

~~`tr4w.dpr` is shared by both toolchains — the LCL and FMX unit sets are selected by `{$IFDEF FPC}`
in its uses clause, which is why the Delphi build still works at all. `tr4w.cfg` / `tr4w.dof` are D7
leftovers and editing them does nothing.~~
