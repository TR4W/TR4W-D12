# Build-Installer.ps1 -- compile full.nsi into a TR4W installer.
#
# One implementation, called by FullBuild.ps1 (-BuildInstaller) and usable on its
# own against a STAGE directory that already holds the binaries -- which is how an
# installer can be built to a scratch directory without touching tr4w\target.
#
#   .\Build-Installer.ps1 -Version 5.0.37                       # 64-bit (shipping), as FullBuild does
#   .\Build-Installer.ps1 -Version 5.0.37 -StageDir <dir> -OutDir <scratch>   # 64-bit from a scratch stage
#   .\Build-Installer.ps1 -Version 5.0.37 -Cpu i386 -Os win32   # 32-bit: built, NOT shipped
#
# THE SHIPPING (x86_64) INSTALLER passes no architecture define, so full.nsi reads
# tr4w\target and tr4w\tr4wserver and writes build\release\tr4w_setup_<version>-x64.exe.
# Any other target adds /DTR4WARCH and /DTR4WSTAGE (its own stage, never target\).
#
# Reads only. Never runs the installer it builds.

param(
   [Parameter(Mandatory = $true)][string] $Version,
   # Empty = the shipping architecture (Get-StagingDir.ps1).
   [string] $Cpu = '',
   [string] $Os  = '',
   # Where this architecture's exe, DLLs and tr4wserver.exe were staged. Empty =
   # Get-Tr4wStageDir's answer. For the shipping target, empty means full.nsi
   # reads target\ itself; a value builds from that scratch stage instead.
   [string] $StageDir = '',
   # Empty = the script's own OutFile (tr4w\build\release\). Set it to build
   # somewhere else, e.g. a scratch directory.
   [string] $OutDir = '',
   [string] $NsisBin = '',
   [switch] $ExcludeSymbols
)

$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'Find-Toolchain.ps1')
. (Join-Path $PSScriptRoot 'Get-StagingDir.ps1')

$resolved = Resolve-Tr4wTarget -Cpu $Cpu -Os $Os
$Cpu = $resolved.Cpu
$Os  = $resolved.Os

$TR4W_DIR = Split-Path $PSScriptRoot -Parent
$nsi      = Join-Path $PSScriptRoot 'full.nsi'

# -NsisBin (or $env:NSIS_BIN) first, then the usual install locations. CI pins it
# explicitly so a release build cannot depend on where an installer happened to
# put things.
#
# The usual locations are searched on EVERY fixed drive, not just C:, via the same
# Get-Tr4wFixedDriveRoots that Find-Toolchain uses -- a PC whose tools live on D:
# is a normal PC, not a misconfiguration.
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
   Write-Host 'makensis.exe not found -- install NSIS, set NSIS_BIN, or omit -BuildInstaller' -ForegroundColor Red
   exit 1
   }
Write-Host "  makensis : $makensis"
if (-not (Test-Path $nsi)) { Write-Host "full.nsi not found at $nsi" -ForegroundColor Red; exit 1 }

# full.nsi refuses to build without /DTR4WVERSION, which is what stops a silently
# mis-versioned installer.
$nsisArgs = @("/DTR4WVERSION=$Version")

if ($ExcludeSymbols)
   {
   Write-Host "  symbols  : EXCLUDED -- release build"
   }
else
   {
   $nsisArgs += "/DINCLUDE_SYMBOLS"
   Write-Host "  symbols  : bundled (tr4w.dbg) -- testing build, pass -ExcludeSymbols for a public release"
   }

$isShipping = Test-Tr4wIsShippingTarget -Cpu $Cpu -Os $Os
$suffix = '-x64'

if ((-not $isShipping) -and ($Cpu -ne 'i386'))
   {
   Write-Host "no installer is defined for $Cpu-$Os (only x86_64-win64, shipping, and i386-win32)" -ForegroundColor Red
   exit 1
   }

if ((-not $isShipping) -or ($StageDir -ne ''))
   {
   # A stage is passed to full.nsi: always for the 32-bit installer (it has no
   # other source), and for a scratch 64-bit one. The shipping installer with no
   # -StageDir passes nothing and full.nsi reads tr4w\target itself.
   if ($StageDir -eq '') { $StageDir = Get-Tr4wStageDir -Tr4wDir $TR4W_DIR -Cpu $Cpu -Os $Os }
   $StageDir = Get-Tr4wFullPath $StageDir
   if (-not (Test-Path -LiteralPath $StageDir))
      {
      Write-Host "stage directory not found: $StageDir -- build the app first" -ForegroundColor Red
      exit 1
      }

   # THE 32-BIT INSTALLER MUST NOT BE ASSEMBLED FROM THE 64-BIT FILES. A stage
   # that is really tr4w\target would bundle the x64 exe into a 32-bit installer.
   try
      {
      Assert-Tr4wShippingPathOnly -Tr4wDir $TR4W_DIR -Cpu $Cpu -Os $Os -Path $StageDir -What 'installer payload'
      }
   catch
      {
      Write-Host $_.Exception.Message -ForegroundColor Red
      exit 1
      }

   $nsisArgs += "/DTR4WARCH=$Cpu"
   $nsisArgs += "/DTR4WSTAGE=$StageDir"
   Write-Host "  stage    : $StageDir"
   }
if ($Cpu -eq 'i386') { $suffix = '-x86' }

# /XOutFile AFTER the script name overrides the script's own OutFile, so the
# script keeps one name for each architecture and a scratch build can go
# anywhere. The file name matches full.nsi's (-x64 for the 64-bit installer).
$nsisTail = @()
if ($OutDir -ne '')
   {
   if (-not (Test-Path -LiteralPath $OutDir)) { New-Item -ItemType Directory -Path $OutDir -Force | Out-Null }
   $outFile = Join-Path (Get-Tr4wFullPath $OutDir) "tr4w_setup_$Version$suffix.exe"
   # Quoted so a directory with spaces in it survives makensis's own parsing.
   $nsisTail += ('/XOutFile "' + $outFile + '"')
   }

& $makensis @nsisArgs $nsi @nsisTail | Out-Host
if ($LASTEXITCODE -ne 0)
   {
   Write-Host 'NSIS installer build failed' -ForegroundColor Red
   exit 1
   }
exit 0
