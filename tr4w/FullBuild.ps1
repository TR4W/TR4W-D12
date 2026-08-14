# TR4W full build -- FreePascal / Lazarus LCL, English, one binary.
#
# Replaces the Delphi 12 script, which is kept as FullBuild-D12-deprecated.ps1
# for reference only. Do not run both: they produce the same file names from
# different toolchains.
#
# WHY THIS IS SO MUCH SHORTER THAN THE ONE IT REPLACES
#
# The D12 script spent most of its 1145 lines on things this one does not do:
#   * NINE language variants, each a separate compile with its own DCU cache,
#     optionally in parallel across git worktrees. TR4W is moving to ONE build
#     with resourcestrings (NY4I, 2026-08-13), so there is no language loop and
#     no per-language VERSIONINFO table. The I18N work arrives separately.
#   * rsvars.bat, DCU cache hygiene, and brcc32 -- all Delphi-specific.
#
# WHAT IT ADDS THAT THE D12 SCRIPT NEVER NEEDED
#
# The nine gating lints lived in tr4w.dproj's PreBuildEvent, so msbuild ran them
# and nothing else did. An FPC build saw none of them. They are invoked here
# explicitly, through build\Run-Lints.ps1, or moving toolchains would have
# silently dropped every gate this repo has built.
#
# ORDER IS DELIBERATE: lints, then unit tests, then the app. A failing test must
# stop the build BEFORE it produces a binary someone could ship -- that rule is
# inherited from the D12 script and is the reason it existed.
#
#   .\FullBuild.ps1                    # lints + tests + app + server
#   .\FullBuild.ps1 -BuildInstaller    # + NSIS installer
#   .\FullBuild.ps1 -SkipTests         # app only; prints a warning
#
# Exit code 0 only if every requested step succeeded.

param(
   [switch] $BuildInstaller,
   [switch] $SkipTests,
   [switch] $SkipLints,
   [string] $Repo = (Split-Path $PSScriptRoot -Parent),
   [string] $Fpc  = 'C:\FPC\3.2.2\bin\i386-win32\fpc.exe',
   [string] $Laz  = 'C:\Lazarus',
   [string] $Cpu  = 'i386',
   [string] $Os   = 'win32'
)

$ErrorActionPreference = 'Stop'

$TR4W_DIR    = $PSScriptRoot
$BUILD_DIR   = Join-Path $TR4W_DIR 'build'
$TARGET_DIR  = Join-Path $TR4W_DIR 'target'
$SERVER_DIR  = Join-Path $TR4W_DIR 'tr4wserver'
$VERSION_PAS = Join-Path $TR4W_DIR 'src\Version.pas'
$SPIKE       = Join-Path $Repo 'spike'
$FPCRES      = Join-Path (Split-Path $Fpc -Parent) 'fpcres.exe'

function Fail([string] $msg)
   {
   Write-Host ''
   Write-Host "=== BUILD FAILED: $msg ===" -ForegroundColor Red
   exit 1
   }

function Phase([string] $name)
   {
   Write-Host ''
   Write-Host "=== $name ===" -ForegroundColor Cyan
   }

# ---------------------------------------------------------------------------
# Preconditions. Checked up front so a missing toolchain fails in one second
# rather than three minutes into a compile.
# ---------------------------------------------------------------------------
if (-not (Test-Path $Fpc))    { Fail "FPC not found at $Fpc" }
if (-not (Test-Path $FPCRES)) { Fail "fpcres not found at $FPCRES" }

$lclUnits = Join-Path $Laz "lcl\units\$Cpu-$Os"
if (-not (Test-Path $lclUnits))
   {
   # Naming the likely cause: an fpcupdeluxe install is commonly x86_64-only,
   # and TR4W targets Win32.
   Fail "No LCL units for $Cpu-$Os at $lclUnits (an x86_64-only Lazarus cannot build this)"
   }

# ---------------------------------------------------------------------------
# Version. src\Version.pas is the single source of truth -- the installer
# refuses to build without it, so a mis-versioned release cannot be produced by
# forgetting a flag.
# ---------------------------------------------------------------------------
$versionLine = Select-String -Path $VERSION_PAS `
                             -Pattern "TR4W_CURRENTVERSION_NUMBER\s*=\s*'([^']+)'" |
               Select-Object -First 1

if (-not ($versionLine -and $versionLine.Matches[0].Groups[1].Value))
   {
   # NOT a fallback to 0.0.0. The D12 script defaulted and warned; a release
   # stamped 0.0.0 is worse than no release, and this is a two-line fix.
   Fail "could not parse TR4W_CURRENTVERSION_NUMBER from $VERSION_PAS"
   }

$TR4W_VERSION = $versionLine.Matches[0].Groups[1].Value
$vp = $TR4W_VERSION.Split('.')
$vMajor = $vp[0]
$vMinor = if ($vp.Count -gt 1) { $vp[1] } else { '0' }
$vBuild = if ($vp.Count -gt 2) { $vp[2] } else { '0' }

Write-Host "TR4W $TR4W_VERSION -- FPC $Cpu-$Os, English, LCL" -ForegroundColor Green

# ---------------------------------------------------------------------------
# VERSIONINFO. Compiled with fpcres, NOT windres: windres shells out to a C
# preprocessor (cc1) that the FPC distribution does not ship, and fails with
# "cannot execute 'cc1'". fpcres parses .rc itself.
#
# tr4w.dpr links this only under {$IFDEF VERSIONINFO_RES}, so the define below
# and this file travel together.
# ---------------------------------------------------------------------------
Phase 'Version resource'

$rcPath  = Join-Path $TR4W_DIR 'tr4w_versioninfo.rc'
$resPath = Join-Path $TR4W_DIR 'tr4w_versioninfo.res'

$rc = @"
1 VERSIONINFO
 FILEVERSION $vMajor,$vMinor,$vBuild,0
 PRODUCTVERSION $vMajor,$vMinor,$vBuild,0
 FILEOS 0x4
 FILETYPE 0x1
{
 BLOCK "StringFileInfo"
 {
  BLOCK "040904E4"
  {
   VALUE "CompanyName",      "TR4W Project (n4af / ny4i)\0"
   VALUE "FileDescription",  "TR4W (TRLOG 4 Windows) Contest Logging Application\0"
   VALUE "FileVersion",      "$vMajor.$vMinor.$vBuild.0\0"
   VALUE "InternalName",     "tr4w\0"
   VALUE "LegalCopyright",   "Free software under GNU GPL v2 or later\0"
   VALUE "OriginalFilename", "tr4w.exe\0"
   VALUE "ProductName",      "TR4W\0"
   VALUE "ProductVersion",   "$vMajor.$vMinor.$vBuild\0"
  }
 }
 BLOCK "VarFileInfo"
 {
  VALUE "Translation", 0x0409, 1252
 }
}
"@

# CRLF EXPLICITLY, not whatever this script file happens to be saved with. The
# here-string above carries THIS file's line endings, so an LF-saved
# FullBuild.ps1 silently emitted an LF .rc -- which Lint-LineEndings then failed
# the build on, on the very first run of this script. Normalising here makes the
# output independent of how the generator was saved.
$rcLines = $rc -split "`r?`n"
[System.IO.File]::WriteAllText($rcPath,
                               ($rcLines -join "`r`n") + "`r`n",
                               [System.Text.Encoding]::ASCII)
& $FPCRES -i $rcPath -o $resPath -of res 2>&1 | Out-Host
if ($LASTEXITCODE -ne 0) { Fail 'fpcres could not compile tr4w_versioninfo.rc' }
Write-Host "  tr4w_versioninfo.res ($((Get-Item $resPath).Length) bytes)"

# ---------------------------------------------------------------------------
# Lints.
# ---------------------------------------------------------------------------
if ($SkipLints)
   {
   Write-Host ''
   Write-Host 'Lints SKIPPED (-SkipLints) -- do not ship this build.' -ForegroundColor Yellow
   }
else
   {
   Phase 'Lints'
   & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $BUILD_DIR 'Run-Lints.ps1') | Out-Host
   if ($LASTEXITCODE -ne 0) { Fail "$LASTEXITCODE lint(s) failed" }
   }

# ---------------------------------------------------------------------------
# Unit tests, BEFORE the app.
# ---------------------------------------------------------------------------
if ($SkipTests)
   {
   Write-Host ''
   Write-Host 'Unit tests SKIPPED (-SkipTests) -- do not ship this build.' -ForegroundColor Yellow
   }
else
   {
   Phase 'Unit tests'

   & (Join-Path $SPIKE 'fpc-build-tests.ps1') -Cpu $Cpu -Os $Os -Fpc $Fpc -Repo $Repo -Laz $Laz | Out-Host
   if ($LASTEXITCODE -ne 0) { Fail 'unit test build failed' }

   # Run from tr4w\test\unit: several suites resolve their data relative to the
   # BINARY (ExtractFilePath(ParamStr(0)) + 'fixtures\' and '..\..\target\'),
   # which is why fpc-build-tests.ps1 emits the exe there.
   $testExe = Join-Path $TR4W_DIR 'test\unit\tr4w_unit_tests_fpc.exe'
   if (-not (Test-Path $testExe)) { Fail "unit test binary missing at $testExe" }

   Push-Location (Split-Path $testExe -Parent)
   try
      {
      $testOut = & $testExe 2>&1
      $testRc  = $LASTEXITCODE
      }
   finally
      {
      Pop-Location
      }

   $summary = $testOut | Select-String 'PASSED:' | Select-Object -Last 1
   if ($summary) { Write-Host "  $($summary.Line.Trim())" }

   if ($testRc -ne 0)
      {
      $testOut | Select-String '\[FAIL\]' | Select-Object -First 20 |
         ForEach-Object { Write-Host "  $($_.Line.Trim())" -ForegroundColor Red }
      Fail 'unit tests failed -- app build aborted'
      }
   }

# ---------------------------------------------------------------------------
# The application.
#
# LANG_ENG selects res\tr4w_eng.res and the ENG string table; VERSIONINFO_RES
# links the resource built above. Both were verified to link under FPC -- the
# .res files are standard Win32 RES and FPC consumes the Delphi-produced ones
# unchanged.
# ---------------------------------------------------------------------------
Phase 'Application'

$appExe = Join-Path $TARGET_DIR 'tr4w.exe'

& (Join-Path $SPIKE 'fpc-build-app.ps1') `
      -Cpu $Cpu -Os $Os -Fpc $Fpc -Repo $Repo -Laz $Laz `
      -Defines @('LANG_ENG', 'VERSIONINFO_RES') `
      -OutExe $appExe | Out-Host

if ($LASTEXITCODE -ne 0) { Fail 'application build failed' }
if (-not (Test-Path $appExe)) { Fail "application binary missing at $appExe" }

$vi = (Get-Item $appExe).VersionInfo
Write-Host "  tr4w.exe $($vi.FileVersion) ($([int]((Get-Item $appExe).Length / 1KB)) KB)"

if ($vi.FileVersion -notlike "$vMajor.$vMinor.$vBuild*")
   {
   # The stamp is the one thing a user can check without running anything, and
   # a silent mismatch here means the resource did not link.
   Fail "tr4w.exe reports $($vi.FileVersion) but Version.pas says $TR4W_VERSION"
   }

# ---------------------------------------------------------------------------
# TR4WServer.
# ---------------------------------------------------------------------------
Phase 'TR4WServer'

$serverOut = Join-Path $Repo "spike\units\server-$Cpu-$Os"
$serverExe = Join-Path $SERVER_DIR 'tr4wserver.exe'

if (-not (Test-Path $serverOut))
   {
   New-Item -ItemType Directory -Path $serverOut | Out-Null
   }

$src = Join-Path $TR4W_DIR 'src'
$fpcRoot = Split-Path (Split-Path (Split-Path $Fpc -Parent) -Parent) -Parent

$serverPaths = @(
   $src
   Join-Path $src 'trdos'
   Join-Path $src 'utils'
   Join-Path $src 'lang'
   Join-Path $src 'radioFactory'
   Join-Path $src 'rotatorFactory'
   Join-Path $fpcRoot "units\$Cpu-$Os\regexpr"
   Join-Path $fpcRoot "units\$Cpu-$Os\fcl-json"
   Join-Path $TR4W_DIR 'Include'
   Join-Path $TR4W_DIR 'include\Core'
   Join-Path $TR4W_DIR 'include\System'
   Join-Path $TR4W_DIR 'include\Protocols'
)

# No LCL and no -WG: the server is a console program with no UI at all.
$serverArgs = @('-Mdelphi', "-P$Cpu", "-T$Os", '-Sc', '-B', "-FU$serverOut", "-o$serverExe")
foreach ($p in $serverPaths)
   {
   $serverArgs += "-Fu$p"
   }
$serverArgs += 'tr4wserver.dpr'

Push-Location $SERVER_DIR
try
   {
   $serverOutput = & $Fpc @serverArgs 2>&1
   $serverRc = $LASTEXITCODE
   }
finally
   {
   Pop-Location
   }

if ($serverRc -ne 0)
   {
   $serverOutput | Select-String 'Error:|Fatal:' | Select-Object -First 10 |
      ForEach-Object { Write-Host "  $($_.Line.Trim())" -ForegroundColor Red }
   Fail 'tr4wserver build failed'
   }

Write-Host "  tr4wserver.exe ($([int]((Get-Item $serverExe).Length / 1KB)) KB)"

# ---------------------------------------------------------------------------
# Installer.
# ---------------------------------------------------------------------------
if ($BuildInstaller)
   {
   Phase 'Installer'

   $nsi = Join-Path $BUILD_DIR 'full.nsi'
   $makensis = @(
      'C:\Program Files (x86)\NSIS\makensis.exe'
      'C:\Program Files\NSIS\makensis.exe'
   ) | Where-Object { Test-Path $_ } | Select-Object -First 1

   if (-not $makensis) { Fail 'makensis.exe not found -- install NSIS or omit -BuildInstaller' }
   if (-not (Test-Path $nsi)) { Fail "full.nsi not found at $nsi" }

   # full.nsi refuses to build without /DTR4WVERSION, which is what stops a
   # silently mis-versioned installer.
   & $makensis "/DTR4WVERSION=$TR4W_VERSION" $nsi | Out-Host
   if ($LASTEXITCODE -ne 0) { Fail 'NSIS installer build failed' }
   }

Write-Host ''
Write-Host "=== BUILD SUCCESSFUL -- TR4W $TR4W_VERSION ===" -ForegroundColor Green
Write-Host "  app    : $appExe"
Write-Host "  server : $serverExe"
if ($SkipTests -or $SkipLints)
   {
   Write-Host '  NOTE   : gates were skipped -- not a shippable build.' -ForegroundColor Yellow
   }
exit 0
