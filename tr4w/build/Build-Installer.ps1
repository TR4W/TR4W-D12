# Build-Installer.ps1 -- compile full.nsi into a TR4W installer.
#
# One implementation, called by FullBuild.ps1 (-BuildInstaller) and usable on its
# own against a STAGE directory that already holds the binaries -- which is how an
# installer can be built to a scratch directory without touching tr4w\target.
#
#   .\Build-Installer.ps1 -Version 5.0.37                       # as FullBuild does
#   .\Build-Installer.ps1 -Version 5.0.37 -StageDir <dir> -OutDir <scratch>   # from a scratch stage
#
# THE INSTALLER IS 64-BIT ONLY (there is no 32-bit Windows build). With no
# -StageDir, full.nsi reads tr4w\target and tr4w\tr4wserver itself and writes
# build\release\tr4w_setup_<version>-x64.exe.
#
# Reads only. Never runs the installer it builds.

param(
   [Parameter(Mandatory = $true)][string] $Version,
   # Where the exe, DLLs and tr4wserver.exe were staged. Empty means full.nsi
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

$suffix = '-x64'

if ($StageDir -ne '')
   {
   # A scratch stage is passed to full.nsi; with none, full.nsi reads tr4w\target.
   $StageDir = Get-Tr4wFullPath $StageDir
   if (-not (Test-Path -LiteralPath $StageDir))
      {
      Write-Host "stage directory not found: $StageDir -- build the app first" -ForegroundColor Red
      exit 1
      }

   $nsisArgs += "/DTR4WSTAGE=$StageDir"
   Write-Host "  stage    : $StageDir"
   }

# /XOutFile AFTER the script name overrides the script's own OutFile, so a
# scratch build can go anywhere. The file name matches full.nsi's (-x64).
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
