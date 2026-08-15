# Builds tr4w.dpr with FPC. The developer's inner loop; FullBuild.ps1 calls this
# for the release build too.
#
#   .\Build-App.ps1                 # full rebuild (-B), the safe default
#   .\Build-App.ps1 -Incremental    # seconds instead of minutes
#   .\Build-App.ps1 -Run            # then print the version banner
#
# INCREMENTAL IS FOR CHASING ONE DEFECT, not for believing a result. FPC's mtime
# rule cannot see a changed compiler switch, a changed .inc, or a define flip,
# and a stale incremental build has already cost this repo two sessions once (a
# phantom corpus crash that was nothing but out-of-date units). Full before you
# commit on it.

param(
   [switch]   $Incremental,
   [switch]   $Run,
   [string[]] $Defines = @(),
   # Where the linked binary goes. FullBuild overrides this to stage the release
   # build into target\ without disturbing the developer one.
   [string]   $OutExe = '',
   [string]   $Fpc = '',
   [string]   $Laz = '',
   [string]   $Cpu = 'i386',
   [string]   $Os  = 'win32'
)

$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'Find-Toolchain.ps1')
. (Join-Path $PSScriptRoot 'Get-SearchPaths.ps1')

$TR4W_DIR = Split-Path $PSScriptRoot -Parent
$REPO     = Split-Path $TR4W_DIR -Parent
$src      = Join-Path $TR4W_DIR 'src'

$tc = Find-Tr4wToolchain -Fpc $Fpc -Laz $Laz -Cpu $Cpu -Os $Os -Quiet
if (-not $tc) { exit 2 }

$out = Join-Path $REPO "build-out\app-$Cpu-$Os"
$exe = if ($OutExe -ne '') { $OutExe } else { Join-Path $out 'tr4w_fpc.exe' }

if (-not (Test-Path $out)) { New-Item -ItemType Directory -Path $out | Out-Null }

# -Sc  C-style operators.
# -WG  GUI subsystem. NOT cosmetic: the shipping binary has PE subsystem 2 and
#      FPC defaults to 3 (CONSOLE), so without it every launch pops a blank
#      console window beside the real one.
# -gl LINKS THE LINE-INFO UNIT, which is what turns a crash report from three
# raw addresses into file and line. Without it BackTraceStrFunc can only print
# $0040DC52, and the first real crash caught by uCrashLog (2026-08-15, an
# EAccessViolation on Ctrl-P) produced exactly that -- proof that the handler
# worked and that the addresses alone were not enough to act on.
#
# It costs exe size and nothing else: no slower code, no behaviour change. For a
# program whose users report crashes by email, a bigger binary that says WHERE is
# the right trade.
$fpcArgs = @("-Mdelphi", "-P$Cpu", "-T$Os", '-Sc', '-WG', '-gl', '-gw2', '-Xg', "-FU$out", "-o$exe")
if (-not $Incremental) { $fpcArgs += '-B' }
foreach ($d in $Defines) { $fpcArgs += "-d$d" }
foreach ($p in (Get-Tr4wSearchPaths -Tr4wDir $TR4W_DIR -Toolchain $tc -For App)) { $fpcArgs += "-Fu$p" }
$fpcArgs += 'tr4w.dpr'

# A DESIGNED FORM IS TWO FILES AND FPC ONLY WATCHES ONE. uPrefsForm.lfm is pulled
# in by {$R *.lfm} while uPrefsForm.pas compiles, so editing the LAYOUT leaves
# the .pas older than its unit file and an incremental build silently keeps the
# previous resource. Touching the .pas is the whole fix -- it uses exactly the
# mtime rule FPC already uses.
if ($Incremental)
   {
   foreach ($lfm in Get-ChildItem -Path $src -Recurse -Filter '*.lfm')
      {
      $pas = [System.IO.Path]::ChangeExtension($lfm.FullName, '.pas')
      if (Test-Path $pas)
         {
         $pasItem = Get-Item $pas
         if ($lfm.LastWriteTime -gt $pasItem.LastWriteTime)
            {
            $pasItem.LastWriteTime = $lfm.LastWriteTime
            Write-Host "  layout newer than code -- forcing recompile of $($pasItem.Name)"
            }
         }
      }
   }

Push-Location $TR4W_DIR
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
$report = Join-Path $REPO 'build-out\app-build.log'
$output | Out-File -FilePath $report -Encoding utf8

# Name the build kind every run. An incremental result read as a full one is the
# exact mistake the switch makes easy, so it is never left to memory.
$kind = if ($Incremental) { 'INCREMENTAL (no -B)' } else { 'full (-B)' }
Write-Host "FPC application build -- $Cpu-$Os -- $kind"
Write-Host "errors+fatals : $($errLines.Count)"
Write-Host "full output   : $report"

if ($errLines.Count -gt 0)
   {
   Write-Host ''
   Write-Host '=== first 20 ==='
   $errLines | Select-Object -First 20 | ForEach-Object { Write-Host "  $($_.Line.Trim())" }
   }

# State the outcome explicitly -- a filtered pipeline that matches nothing prints
# nothing, which reads as success.
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
   Write-Host ''
   & $exe /VERSION
   Write-Host "exit code = $LASTEXITCODE"
   }

exit 0
