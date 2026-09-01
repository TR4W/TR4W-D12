# Build logdump -- the binary-log dumper the corpus cross-check drives.
#
# THIS SCRIPT COULD NOT BUILD ANYTHING BEFORE 2026-09-01, on any machine but
# one.  It invoked Delphi 7's DCC32 against hardcoded absolute paths in
# C:\TR4W -- the D7 heritage tree, not this repository:
#
#     $DCC32   = "C:\Program Files (x86)\Borland\Delphi7\Bin\DCC32.EXE"
#     $PROJECT = "C:\TR4W\tr4w\test\logdump\logdump.lpr"
#     /UC:\TR4W\tr4w\src
#
# DCC32 was retired from this project long ago, `logdump.exe` is untracked, and
# the paths are somebody's machine.  So a fresh clone had a verification tool it
# could not produce, and the failure appears as "file not found" naming a
# directory the reader has never heard of.  CLAUDE.md's rule about hooks applies
# to build scripts for exactly this reason: a hardcoded path is a script that
# silently does not run.
#
# Now it discovers the toolchain like every other build script here and shares
# the unit search paths, so it cannot drift from the app build.

param(
   [switch] $Run   # build, then dump a corpus log as a smoke test
)

$ErrorActionPreference = 'Stop'

$here    = $PSScriptRoot
$tr4wDir = (Resolve-Path (Join-Path $here '..\..')).Path
$build   = Join-Path $tr4wDir 'build'

. (Join-Path $build 'Find-Toolchain.ps1')
. (Join-Path $build 'Get-SearchPaths.ps1')

$toolchain = Find-Tr4wToolchain

# The App target: logdump links VC.pas and uLogBinaryFile.pas, and VC pulls in
# the rest of src\. It needs no LCL, but asking for the Server target would
# deny it nothing it uses and would be a second opinion about the paths.
$unitPaths    = Get-Tr4wSearchPaths -Tr4wDir $tr4wDir -Toolchain $toolchain -For 'App'
$includePaths = Get-Tr4wIncludePaths -Tr4wDir $tr4wDir

$outDir = Join-Path (Split-Path $tr4wDir -Parent) 'build-out\logdump-i386-win32'
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

$args = @(
   '-Twin32', '-Pi386', '-Mdelphi', '-O1',
   "-FU$outDir",
   "-FE$here"
)
foreach ($p in $unitPaths)    { $args += "-Fu$p" }
foreach ($p in $includePaths) { $args += "-Fi$p" }
$args += (Join-Path $here 'logdump.lpr')

Write-Host "=== Compiling logdump ===" -ForegroundColor Cyan
Write-Host "  fpc : $($toolchain.FpcExe)"

$log = & $toolchain.FpcExe @args 2>&1
$rc = $LASTEXITCODE

$problems = @($log | Where-Object { $_ -match '(?i)\b(error|fatal)\b' })
if ($problems.Count -gt 0)
   {
   $problems | Select-Object -First 20 | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
   }

$exe = Join-Path $here 'logdump.exe'
if ($rc -ne 0 -or -not (Test-Path $exe))
   {
   Write-Host "=== BUILD FAILED ($rc) ===" -ForegroundColor Red
   exit 1
   }

Write-Host "=== BUILD OK ===" -ForegroundColor Green
Write-Host "  $exe"

if ($Run)
   {
   # A smoke test against a real D7-written fixture, because "it compiled" says
   # nothing about whether it can still read a log.
   $fixture = Join-Path $tr4wDir 'test\corpus\general_qso_2026_w1aw4\log.trw'
   if (-not (Test-Path $fixture))
      {
      Write-Host "  note: corpus fixture missing, skipping the smoke test" -ForegroundColor Yellow
      exit 0
      }

   Write-Host "=== Smoke test ===" -ForegroundColor Cyan
   $out = & $exe $fixture 2>&1
   if ($LASTEXITCODE -ne 0)
      {
      Write-Host "  logdump exited $LASTEXITCODE" -ForegroundColor Red
      exit 1
      }

   $records = @($out | Where-Object { $_ -match '"Call"' }).Count
   Write-Host "  $records QSO record(s) emitted from the general_qso fixture"
   if ($records -eq 0)
      {
      Write-Host "  a fixture that exports QSOs produced none -- that is a failure" -ForegroundColor Red
      exit 1
      }
   }

exit 0
