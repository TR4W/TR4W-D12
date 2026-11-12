# Builds tr4wconvert.lpr with FPC.
#
# tr4wconvert carries an operator's old configuration into the files TR4W reads,
# as a separate act rather than as part of starting the program (NY4I,
# 2026-09-12). It is a genuine console program -- no widget set, no form -- so
# unlike Build-Server.ps1 it does NOT pass -WG, and that omission is deliberate
# rather than inherited: a converter run from a command prompt should write to
# that prompt.
#
# IT USES THE App SEARCH PATH, not Server's. Not because it needs the LCL, but
# because Get-SearchPaths defines three lists for three targets and this is a
# fourth; borrowing App's is one line and a wrong list is a link failure, while
# inventing a fourth is a list somebody has to remember to maintain. If the unit
# graph here ever stops being a strict subset of the app's, give it its own
# entry there rather than adding paths here.
#
#   .\Build-Convert.ps1

param(
   [string] $OutExe = '',
   [string] $Fpc = '',
   [string] $Laz = '',
   [switch] $Run
)

$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'Find-Toolchain.ps1')
. (Join-Path $PSScriptRoot 'Get-SearchPaths.ps1')
. (Join-Path $PSScriptRoot 'Get-StagingDir.ps1')

$Cpu = $script:Tr4wCpu
$Os  = $script:Tr4wOs

$TR4W_DIR    = Split-Path $PSScriptRoot -Parent
$REPO        = Split-Path $TR4W_DIR -Parent
$CONVERT_DIR = Join-Path $TR4W_DIR 'tools\tr4wconvert'

$tc = Find-Tr4wToolchain -Fpc $Fpc -Laz $Laz -Quiet
if (-not $tc) { exit 2 }

$out = Join-Path $REPO "build-out\convert-$Cpu-$Os"
# The default lands in tr4w\target, beside the exe and the DLLs full.nsi ships.
$exe = if ($OutExe -ne '') { $OutExe } else { Join-Path (Join-Path $TR4W_DIR 'target') 'tr4wconvert.exe' }
$exeDirectory = Split-Path $exe -Parent
if (-not (Test-Path $exeDirectory)) { New-Item -ItemType Directory -Path $exeDirectory -Force | Out-Null }

if (-not (Test-Path $out)) { New-Item -ItemType Directory -Path $out | Out-Null }

# Always a full build, so always clear first -- see Clear-Tr4wUnitOutput.
$cleared = Clear-Tr4wUnitOutput -OutDir $out
if ($cleared -gt 0) { Write-Host "  cleared $cleared stale artifact(s) from $out" }

# -gl for the same reason the app and the server carry it: a crash report of
# bare addresses is a report nobody can act on.
$fpcArgs = @("-Mdelphi", "-P$Cpu", "-T$Os", '-Sc', '-gl', '-B', "-FU$out", "-o$exe")
foreach ($p in (Get-Tr4wSearchPaths -Tr4wDir $TR4W_DIR -Toolchain $tc -For App)) { $fpcArgs += "-Fu$p" }
foreach ($p in (Get-Tr4wIncludePaths -Tr4wDir $TR4W_DIR)) { $fpcArgs += "-Fi$p" }
$fpcArgs += 'tr4wconvert.lpr'

Push-Location $CONVERT_DIR
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
$report = Join-Path $REPO 'build-out\convert-build.log'
$output | Out-File -FilePath $report -Encoding utf8

Write-Host "FPC tr4wconvert build -- $Cpu-$Os"
Write-Host "errors+fatals : $($errLines.Count)"
Write-Host "full output   : $report"

if ($rc -ne 0)
   {
   Write-Host ''
   Write-Host '=== first 20 ==='
   $errLines | Select-Object -First 20 | ForEach-Object { Write-Host "  $($_.Line.Trim())" }
   Write-Host "tr4wconvert build FAILED (exit $rc)" -ForegroundColor Red
   exit 1
   }

Write-Host "BUILD OK -> $exe" -ForegroundColor Green

if ($Run)
   {
   Write-Host ''
   & $exe --help
   }
