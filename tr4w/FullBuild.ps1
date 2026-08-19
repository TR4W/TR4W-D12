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
   # Leave the ~46 MB tr4w.dbg OUT of the installer. Symbols are bundled by
   # default while the build is going to bench testers (NY4I, 2026-08-16), so
   # an address in their log can be turned into a file and a line without
   # shipping them a second download. Pass this for a public release.
   [switch] $ExcludeSymbols,
   [switch] $SkipTests,
   [switch] $SkipLints,
   [string] $Repo = (Split-Path $PSScriptRoot -Parent),
   # Empty by default: Find-Toolchain discovers FPC and Lazarus and honours
   # FPC_HOME / LAZARUS_DIR. Pass these only to force a particular install.
   [string] $Fpc  = '',
   [string] $Laz  = '',
   # NSIS directory (the one containing makensis.exe). Also read from
   # $env:NSIS_BIN. Only consulted when -BuildInstaller is given.
   [string] $NsisBin = '',
   [string] $Cpu  = 'i386',
   [string] $Os   = 'win32'
)

$ErrorActionPreference = 'Stop'

$TR4W_DIR    = $PSScriptRoot
$BUILD_DIR   = Join-Path $TR4W_DIR 'build'
$TARGET_DIR  = Join-Path $TR4W_DIR 'target'
$SERVER_DIR  = Join-Path $TR4W_DIR 'tr4wserver'
$VERSION_PAS = Join-Path $TR4W_DIR 'src\Version.pas'

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
# Toolchain. Resolved up front so a missing or wrong-architecture install fails
# in one second with a list of where it looked, rather than three minutes into a
# compile with "can't find unit Forms".
# ---------------------------------------------------------------------------
Phase 'Toolchain'

. (Join-Path $BUILD_DIR 'Find-Toolchain.ps1')

$tc = Find-Tr4wToolchain -Fpc $Fpc -Laz $Laz -Cpu $Cpu -Os $Os
if (-not $tc) { Fail 'no FPC + Lazarus able to target this platform (see above)' }

$FPCRES = $tc.FpcRes
if (-not (Test-Path $FPCRES)) { Fail "fpcres not found at $FPCRES" }

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
# The application manifest.
#
# COMPILED HERE rather than shipped as a checked-in .res, because that is what
# it was: tr4w.dpr links {$R 'Win11.res'} and NOTHING rebuilt it, so editing
# W11.manifest changed nothing at all. The same shape as tr4w.cfg and tr4w.dof
# -- a source file that looks live and is not -- and it hid the fact that the
# manifest never asked for Common-Controls v6, which is why every stock control
# rendered unthemed on Windows 11.
#
# Now the .manifest is the source of record and the .res is a build artifact.
# ---------------------------------------------------------------------------
Phase 'Manifest resource'

$manRc  = Join-Path $TR4W_DIR 'Win11.rc'
$manRes = Join-Path $TR4W_DIR 'Win11.res'
$manXml = Join-Path $TR4W_DIR 'W11.manifest'

if (-not (Test-Path $manXml)) { Fail "W11.manifest not found at $manXml" }

# WELL-FORMED XML FIRST, before it is compiled into anything.
#
# A malformed manifest does not fail the build, does not fail fpcres, and does
# not warn: it produces an exe that Windows REFUSES TO START, with
# "the application failed to start because its side-by-side configuration is
# incorrect" and no clue which file is at fault. That is exactly what shipped
# from this script the first time -- a double hyphen inside an XML comment,
# which is illegal and which no editor flags.
#
# The grep further down proves the dependency is PRESENT; this proves the file
# is PARSEABLE. Neither implies the other, and only the pair keeps a build that
# cannot launch from looking green.
try
   {
   [xml]$null = Get-Content -LiteralPath $manXml -Raw
   }
catch
   {
   Fail "W11.manifest is not well-formed XML: $($_.Exception.Message)"
   }

& $FPCRES -i $manRc -o $manRes -of res 2>&1 | Out-Host
if ($LASTEXITCODE -ne 0) { Fail 'fpcres could not compile Win11.rc' }

# A FLOOR on the result. fpcres is happy to emit a resource that does not
# contain the manifest at all if the .rc reference cannot be resolved, and an
# unthemed build looks like a styling opinion rather than a missing file.
$manBytes = [IO.File]::ReadAllBytes($manRes)
$manText  = [Text.Encoding]::ASCII.GetString($manBytes)
if ($manText -notmatch 'Common-Controls')
   {
   Fail 'Win11.res does not contain the Common-Controls v6 dependency -- visual styles would be off'
   }
Write-Host "  Win11.res ($($manBytes.Length) bytes, visual styles declared)"

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

   & (Join-Path $BUILD_DIR 'Build-Tests.ps1') -Cpu $Cpu -Os $Os -Fpc $tc.FpcExe -Laz $tc.LazDir | Out-Host
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

& (Join-Path $BUILD_DIR 'Build-App.ps1') `
      -Cpu $Cpu -Os $Os -Fpc $tc.FpcExe -Laz $tc.LazDir `
      -Defines @('LANG_ENG', 'VERSIONINFO_RES') `
      -OutExe $appExe | Out-Host

if ($LASTEXITCODE -ne 0) { Fail 'application build failed' }
if (-not (Test-Path $appExe)) { Fail "application binary missing at $appExe" }

$vi = (Get-Item $appExe).VersionInfo
Write-Host "  tr4w.exe $($vi.FileVersion) ($([int]((Get-Item $appExe).Length / 1KB)) KB)"

# THE .dbg IS THE RELEASE'S SYMBOLS AND HAS TO BE KEPT WITH IT.
#
# -gl -gw2 -Xg puts the line-number info in tr4w.dbg beside the exe rather than
# inside it: 4.5 MB stays 4.5 MB and the symbols are ~46 MB alongside. That file
# is what turns an emailed "$0040DC52" into a file and a line, and it is valid
# ONLY for the exact binary it was linked with -- rebuild and the addresses in an
# operator's log become unresolvable for good.
#
# It is deliberately NOT put in the installer (46 MB for something almost no user
# needs). Two ways to use it, both proven 2026-08-15: hand the matching .dbg to
# an operator with a hard fault and have them drop it beside tr4w.exe, or keep it
# here and resolve their addresses yourself -- the address is identical whether
# the file is present or not, and a missing .dbg degrades to bare addresses
# rather than failing.
$appDbg = [System.IO.Path]::ChangeExtension($appExe, '.dbg')
if (Test-Path -LiteralPath $appDbg) {
   Write-Host ("  tr4w.dbg {0} MB -- ARCHIVE THIS WITH THE RELEASE" -f `
               [int]((Get-Item $appDbg).Length / 1MB))
} else {
   Write-Host "  tr4w.dbg MISSING -- crash reports from this build cannot be resolved" `
              -ForegroundColor Yellow
}

# ---------------------------------------------------------------------------
# THE MANIFEST AS THE LOADER WILL SEE IT.
#
# Checking W11.manifest before compiling proves the SOURCE is good. It does not
# prove what ended up inside the exe, and the exe is what Windows parses. When a
# double hyphen inside an XML comment made the manifest malformed, fpcres
# compiled it happily, the presence grep found "Common-Controls" because the
# string was there regardless, 10 lints passed and 4007 tests passed -- and the
# binary would not start at all:
#
#   "The application failed to start because its side-by-side configuration is
#    incorrect."
#
# So this reads RT_MANIFEST back OUT of the linked binary, parses it, and
# requires the dependency. It is the cheapest check that can tell a build which
# runs from a build which merely links, and it is the only one here that looks at
# the artifact rather than at its inputs.
# ---------------------------------------------------------------------------
function Assert-EmbeddedManifest
   {
   param([string] $ExePath)

   Add-Type -Namespace TR4W -Name Res -MemberDefinition @'
[DllImport("kernel32.dll", SetLastError=true, CharSet=CharSet.Unicode)] public static extern IntPtr LoadLibraryExW(string f, IntPtr h, uint flags);
[DllImport("kernel32.dll", SetLastError=true)] public static extern IntPtr FindResourceW(IntPtr h, IntPtr name, IntPtr type);
[DllImport("kernel32.dll", SetLastError=true)] public static extern IntPtr LoadResource(IntPtr h, IntPtr res);
[DllImport("kernel32.dll", SetLastError=true)] public static extern IntPtr LockResource(IntPtr d);
[DllImport("kernel32.dll", SetLastError=true)] public static extern uint SizeofResource(IntPtr h, IntPtr res);
[DllImport("kernel32.dll", SetLastError=true)] public static extern bool FreeLibrary(IntPtr h);
'@ -ErrorAction SilentlyContinue

   $LOAD_LIBRARY_AS_DATAFILE = 0x2
   $RT_MANIFEST              = 24
   $CREATEPROCESS_MANIFEST   = 1

   $h = [TR4W.Res]::LoadLibraryExW($ExePath, [IntPtr]::Zero, $LOAD_LIBRARY_AS_DATAFILE)
   if ($h -eq [IntPtr]::Zero)
      {
      # RETURN after every Fail. Fail currently exits, so these are redundant
      # today -- and that is exactly the assumption worth not making: the
      # no-manifest case below ran on past its Fail, dereferenced a null pointer
      # and then printed "manifest verified". A check that keeps going after
      # deciding it failed is worse than no check.
      Fail "could not open $ExePath to read its manifest"
      return
      }

   try
      {
      $r = [TR4W.Res]::FindResourceW($h, [IntPtr]$CREATEPROCESS_MANIFEST, [IntPtr]$RT_MANIFEST)
      if ($r -eq [IntPtr]::Zero)
         {
         Fail "$ExePath has no application manifest -- Win11.res did not link"
         return
         }

      $size = [TR4W.Res]::SizeofResource($h, $r)
      $ptr  = [TR4W.Res]::LockResource([TR4W.Res]::LoadResource($h, $r))
      $buf  = New-Object byte[] $size
      [Runtime.InteropServices.Marshal]::Copy($ptr, $buf, 0, $size)
      $xmlText = [Text.Encoding]::UTF8.GetString($buf)
      }
   finally
      {
      [void][TR4W.Res]::FreeLibrary($h)
      }

   try
      {
      [xml]$null = $xmlText
      }
   catch
      {
      Fail ("the manifest embedded in $ExePath is not well-formed XML: " +
            "$($_.Exception.Message) -- Windows will refuse to start it")
      return
      }

   if ($xmlText -notmatch 'Common-Controls')
      {
      Fail "the manifest embedded in $ExePath does not request Common-Controls v6 -- visual styles would be off"
      return
      }

   Write-Host "  manifest verified in the binary (parses, visual styles declared)"
   }

Assert-EmbeddedManifest -ExePath $appExe


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

$serverExe = Join-Path $SERVER_DIR 'tr4wserver.exe'

& (Join-Path $BUILD_DIR 'Build-Server.ps1') `
      -Cpu $Cpu -Os $Os -Fpc $tc.FpcExe -Laz $tc.LazDir `
      -OutExe $serverExe | Out-Host

if ($LASTEXITCODE -ne 0) { Fail 'tr4wserver build failed' }
if (-not (Test-Path $serverExe)) { Fail "tr4wserver binary missing at $serverExe" }

Write-Host "  tr4wserver.exe ($([int]((Get-Item $serverExe).Length / 1KB)) KB)"

# ---------------------------------------------------------------------------
# Installer.
# ---------------------------------------------------------------------------
if ($BuildInstaller)
   {
   Phase 'Installer'

   $nsi = Join-Path $BUILD_DIR 'full.nsi'

   # -NsisBin (or $env:NSIS_BIN) first, then the usual install locations. CI
   # pins it explicitly so a release build cannot depend on where an installer
   # happened to put things.
   #
   # The usual locations are searched on EVERY fixed drive, not just C:, via the
   # same Get-Tr4wFixedDriveRoots that Find-Toolchain uses -- a PC whose tools
   # live on D: is a normal PC, not a misconfiguration, and hardcoding C: made
   # it look like NSIS was missing when it was merely elsewhere.
   $nsisCandidates = @()
   if ($NsisBin)      { $nsisCandidates += (Join-Path $NsisBin      'makensis.exe') }
   if ($env:NSIS_BIN) { $nsisCandidates += (Join-Path $env:NSIS_BIN 'makensis.exe') }
   foreach ($drive in Get-Tr4wFixedDriveRoots)
      {
      $nsisCandidates += (Join-Path $drive 'Program Files (x86)\NSIS\makensis.exe')
      $nsisCandidates += (Join-Path $drive 'Program Files\NSIS\makensis.exe')
      }

   $makensis = $nsisCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1

   if (-not $makensis)
      {
      Write-Host '  looked in:' -ForegroundColor Red
      $nsisCandidates | ForEach-Object { Write-Host "    $_" }
      Fail 'makensis.exe not found -- install NSIS, set NSIS_BIN, or omit -BuildInstaller'
      }
   Write-Host "  makensis : $makensis"
   if (-not (Test-Path $nsi)) { Fail "full.nsi not found at $nsi" }

   # full.nsi refuses to build without /DTR4WVERSION, which is what stops a
   # silently mis-versioned installer.
   $nsisArgs = @("/DTR4WVERSION=$TR4W_VERSION")
   if ($ExcludeSymbols) {
      Write-Host "  symbols  : EXCLUDED -- release build"
   } else {
      $nsisArgs += "/DINCLUDE_SYMBOLS"
      Write-Host "  symbols  : bundled (tr4w.dbg) -- testing build, "  `
                 "pass -ExcludeSymbols for a public release"
   }
   & $makensis $nsisArgs $nsi | Out-Host
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
