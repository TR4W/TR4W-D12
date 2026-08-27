# Builds the unit-test suite with FPC.
#
#   .\Build-Tests.ps1          # build
#   .\Build-Tests.ps1 -Run     # build, then run and report PASSED/FAILED
#
# THE EXE LANDS IN test\unit, NOT beside the unit files, and that is a
# requirement of the suite rather than a preference. Several suites locate their
# data relative to the BINARY:
#
#   uTestADIFFixtures : ExtractFilePath(ParamStr(0)) + 'fixtures\...'
#   uTestCTYDAT       : ExtractFilePath(ParamStr(0)) + '..\..\target\cty.dat'
#
# Both resolve only from tr4w\test\unit. Built anywhere else the result is 30
# red CTYDAT tests plus a bare RTE 217 in ADIFFixtures, and neither points at
# the real cause.

param(
   [switch] $Run,
   [string] $Fpc = '',
   [string] $Laz = '',
   [string] $Cpu = 'i386',
   [string] $Os  = 'win32'
)

$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'Find-Toolchain.ps1')
. (Join-Path $PSScriptRoot 'Get-SearchPaths.ps1')

$TR4W_DIR = Split-Path $PSScriptRoot -Parent
$REPO     = Split-Path $TR4W_DIR -Parent
$test     = Join-Path $TR4W_DIR 'test\unit'

$tc = Find-Tr4wToolchain -Fpc $Fpc -Laz $Laz -Cpu $Cpu -Os $Os -Quiet
if (-not $tc) { exit 2 }

$out = Join-Path $REPO "build-out\tests-$Cpu-$Os"
$exe = Join-Path $test 'tr4w_unit_tests_fpc.exe'

if (-not (Test-Path $out)) { New-Item -ItemType Directory -Path $out | Out-Null }

# Always a full build here, so always clear first -- see Clear-Tr4wUnitOutput.
$cleared = Clear-Tr4wUnitOutput -OutDir $out
if ($cleared -gt 0) { Write-Host "  cleared $cleared stale artifact(s) from $out" }
$fpcArgs = @("-Mdelphi", "-P$Cpu", "-T$Os", '-Sc', '-B', "-FU$out", "-o$exe")
foreach ($p in (Get-Tr4wSearchPaths -Tr4wDir $TR4W_DIR -Toolchain $tc -For Tests -TestDir $test))
   {
   $fpcArgs += "-Fu$p"
   }
foreach ($p in (Get-Tr4wIncludePaths -Tr4wDir $TR4W_DIR)) { $fpcArgs += "-Fi$p" }
$fpcArgs += 'tr4w_unit_tests.dpr'

Push-Location $test
try
   {
   $output = & $tc.FpcExe @fpcArgs 2>&1
   $rc = $LASTEXITCODE
   }
finally
   {
   Pop-Location
   }

$errLines = $output | Select-String -Pattern '\bError:|\bFatal:'
$report = Join-Path $REPO 'build-out\tests-build.log'
$output | Out-File -FilePath $report -Encoding utf8

Write-Host "FPC unit-test build -- $Cpu-$Os"
Write-Host "errors+fatals : $($errLines.Count)"
Write-Host "full output   : $report"

if ($errLines.Count -gt 0)
   {
   Write-Host ''
   Write-Host '=== first 20 ==='
   $errLines | Select-Object -First 20 | ForEach-Object { Write-Host "  $($_.Line.Trim())" }
   }

if ($rc -ne 0)
   {
   Write-Host ''
   Write-Host "BUILD FAILED (exit $rc)"
   exit 1
   }

Write-Host ''
Write-Host "BUILD OK -> $exe"

# THE TEST EXE CANNOT START WITHOUT THESE, and the failure is silent.
#
# libhamlib-4.dll is a LOAD-TIME import of the test binary (the radio-factory
# suites link the HamLib IDs), so Windows resolves it before a single line of
# our code runs. The exe must live in test\unit -- several suites resolve their
# data from ParamStr(0) -- but the DLLs ship in target\, so nothing put them
# side by side and nothing ever noticed.
#
# It went unnoticed because the machine this was developed on has an unrelated
# HamLib checkout (C:\projects\hamlib\bin) on PATH, which satisfied the import
# by accident. Anywhere else -- a CI runner, a new contributor's PC -- the exe
# dies with STATUS_DLL_NOT_FOUND (exit -1073741515) before printing anything,
# so FullBuild reports "unit tests failed" with no failing test to look at.
# Found by building on a clean box, which is exactly what Test-FreshClone is
# for and exactly what it could not see while running here.
$runtimeDlls = @(
   'libhamlib-4.dll',      # the load-time import itself
   'libgcc_s_dw2-1.dll',   # ...and what it needs in turn
   'libwinpthread-1.dll',
   'libusb-1.0.dll'
)
$dllSrc = Join-Path $PSScriptRoot '..\target'
$dllDst = Split-Path $exe -Parent
foreach ($d in $runtimeDlls)
   {
   $src = Join-Path $dllSrc $d
   if (Test-Path -LiteralPath $src)
      {
      Copy-Item -LiteralPath $src -Destination $dllDst -Force
      }
   else
      {
      # Report rather than fail: only libhamlib-4.dll is strictly load-time, and
      # a tree without the others should say so rather than die here.
      Write-Host "  note: $d not found in target\ -- tests may not start" -ForegroundColor Yellow
      }
   }

if ($Run)
   {
   Push-Location $test
   try
      {
      $testOut = & $exe 2>&1
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
      exit 1
      }
   }

exit 0
