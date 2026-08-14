# Builds tr4wserver.dpr with FPC.
#
# NO LCL AND NO -WG. tr4wserver is a console program with no UI at all, so it
# links neither the widgetset nor any ui\ unit -- see Get-SearchPaths, which
# gives 'Server' a deliberately different list rather than one shared superset.
#
#   .\Build-Server.ps1

param(
   [string] $OutExe = '',
   [string] $Fpc = '',
   [string] $Laz = '',
   [string] $Cpu = 'i386',
   [string] $Os  = 'win32'
)

$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'Find-Toolchain.ps1')
. (Join-Path $PSScriptRoot 'Get-SearchPaths.ps1')

$TR4W_DIR   = Split-Path $PSScriptRoot -Parent
$REPO       = Split-Path $TR4W_DIR -Parent
$SERVER_DIR = Join-Path $TR4W_DIR 'tr4wserver'

$tc = Find-Tr4wToolchain -Fpc $Fpc -Laz $Laz -Cpu $Cpu -Os $Os -Quiet
if (-not $tc) { exit 2 }

$out = Join-Path $REPO "build-out\server-$Cpu-$Os"
$exe = if ($OutExe -ne '') { $OutExe } else { Join-Path $SERVER_DIR 'tr4wserver.exe' }

if (-not (Test-Path $out)) { New-Item -ItemType Directory -Path $out | Out-Null }

$fpcArgs = @("-Mdelphi", "-P$Cpu", "-T$Os", '-Sc', '-B', "-FU$out", "-o$exe")
foreach ($p in (Get-Tr4wSearchPaths -Tr4wDir $TR4W_DIR -Toolchain $tc -For Server)) { $fpcArgs += "-Fu$p" }
$fpcArgs += 'tr4wserver.dpr'

Push-Location $SERVER_DIR
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
$output | Out-File -FilePath (Join-Path $REPO 'build-out\server-build.log') -Encoding utf8

if ($rc -ne 0)
   {
   Write-Host "tr4wserver build FAILED (exit $rc)" -ForegroundColor Red
   $errLines | Select-Object -First 10 | ForEach-Object { Write-Host "  $($_.Line.Trim())" }
   exit 1
   }

Write-Host "BUILD OK -> $exe"
exit 0
