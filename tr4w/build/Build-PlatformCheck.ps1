# Builds the platform conformance probe with FPC.
#
#   .\Build-PlatformCheck.ps1        # build
#   .\Build-PlatformCheck.ps1 -Run   # build, then run and report
#
# WHAT IT IS. A small program that asks the platform the questions TR4W's code
# already assumes the answers to, and fails when one of them is not what this
# build was written against. See tr4w\test\platform\tr4w_platformcheck.lpr for
# why it exists and, more importantly, for what it cannot do.
#
# NO LCL, ON PURPOSE. The headless probe links nothing from src\ and nothing
# from the widget set, so it runs on a machine with no display -- which is
# every CI box and every ssh into the Mac. The search path is deliberately
# minimal for the same reason: this program has to be trustworthy BEFORE
# anything else about a platform is, and every unit between it and the RTL is
# another way for it to fail for a reason that is not the answer it asked for.

param(
   [switch] $Run,
   [string] $Fpc = '',
   [string] $Laz = '',
   [string] $Cpu = 'i386',
   [string] $Os  = 'win32'
)

$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'Find-Toolchain.ps1')

$TR4W_DIR = Split-Path $PSScriptRoot -Parent
$REPO     = Split-Path $TR4W_DIR -Parent
$probeDir = Join-Path $TR4W_DIR 'test\platform'

$tc = Find-Tr4wToolchain -Fpc $Fpc -Laz $Laz -Cpu $Cpu -Os $Os -Quiet
if (-not $tc) { exit 2 }

$out = Join-Path $REPO "build-out\platformcheck-$Cpu-$Os"
$exe = Join-Path $probeDir 'tr4w_platformcheck.exe'

if (-not (Test-Path $out)) { New-Item -ItemType Directory -Path $out | Out-Null }

$fpcArgs = @('-Mdelphi', "-P$Cpu", "-T$Os", '-Sc', '-B', "-FU$out", "-o$exe",
             'tr4w_platformcheck.lpr')

Push-Location $probeDir
try
   {
   $output = & $tc.FpcExe @fpcArgs 2>&1
   $rc = $LASTEXITCODE
   }
finally
   {
   Pop-Location
   }

$log = Join-Path $REPO 'build-out\platformcheck-build.log'
$output | Out-File -FilePath $log -Encoding utf8

$errors = @($output | Select-String -Pattern '(^|\s)(Error|Fatal):' -AllMatches)

Write-Host "FPC platform-check build -- $Cpu-$Os"
Write-Host "errors+fatals : $($errors.Count)"
Write-Host "full output   : $log"

if ($rc -ne 0)
   {
   foreach ($e in $errors) { Write-Host "  $($e.Line.Trim())" }
   Write-Host ''
   Write-Host 'BUILD FAILED'
   exit 1
   }

Write-Host ''
Write-Host "BUILD OK -> $exe"

if ($Run)
   {
   Write-Host ''
   & $exe $out
   $runRc = $LASTEXITCODE

   if ($runRc -ne 0)
      {
      # A NON-ZERO EXIT IS A REAL RESULT AND MUST NOT BE SWALLOWED. The corpus
      # learned this the hard way -- it discarded the exit code while all
      # thirteen exports were dying with an access violation, and reported
      # green for two days (CLAUDE.md, Testing).
      Write-Host ''
      Write-Host "PLATFORM CHECK FAILED (exit $runRc)"
      exit $runRc
      }
   }

exit 0
