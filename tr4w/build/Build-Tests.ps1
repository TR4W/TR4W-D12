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

$fpcArgs = @("-Mdelphi", "-P$Cpu", "-T$Os", '-Sc', '-B', "-FU$out", "-o$exe")
foreach ($p in (Get-Tr4wSearchPaths -Tr4wDir $TR4W_DIR -Toolchain $tc -For Tests -TestDir $test))
   {
   $fpcArgs += "-Fu$p"
   }
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
