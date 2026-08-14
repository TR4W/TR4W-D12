# Proves the acceptance criterion: a clone of HEAD, on a machine with FPC and
# Lazarus installed, builds the setup .exe with no arguments and no setup.
#
# WHY THIS IS A SCRIPT AND NOT A BELIEF.  Every path-independence bug looks
# identical from inside the working tree: it works. The failure only appears on
# a different machine or a different directory, usually to someone else, usually
# after a rename. Running it here, deliberately, is the only way the guarantee
# stays true.
#
# It has already earned its place: the first run found that an UNTRACKED file
# (tr4wserver.res, sitting in the working tree) was being linked into the
# shipping server binary, making it 152 KB larger than any clone would produce.
# Nothing in the working tree could have shown that.
#
#   .\Test-FreshClone.ps1                  # clone HEAD, build app + server
#   .\Test-FreshClone.ps1 -WithInstaller   # ...and the NSIS installer
#   .\Test-FreshClone.ps1 -Keep            # leave the clone for inspection
#
# The clone is LOCAL (git clone <repo>), so it tests path independence and
# tracked-file completeness -- not the GitHub remote. That is the right scope:
# those are the two things that actually break.

param(
   [string] $Dest = '',
   [switch] $WithInstaller,
   [switch] $Keep
)

$ErrorActionPreference = 'Stop'

$TR4W_DIR = Split-Path $PSScriptRoot -Parent
$REPO     = Split-Path $TR4W_DIR -Parent

if (-not $Dest)
   {
   $Dest = Join-Path $env:TEMP ('tr4w-freshclone-' + [System.IO.Path]::GetRandomFileName().Substring(0, 8))
   }

Write-Host "=== Fresh-clone acceptance test ===" -ForegroundColor Cyan
Write-Host "  source : $REPO"
Write-Host "  clone  : $Dest"

# Warn rather than fail: uncommitted work is normal mid-session, but the clone
# will NOT contain it, so a pass here says nothing about those edits.
$dirty = & git -C $REPO status --porcelain --untracked-files=no
if ($dirty)
   {
   Write-Host ''
   Write-Host "  NOTE: $(@($dirty).Count) tracked file(s) modified but not committed." -ForegroundColor Yellow
   Write-Host '        The clone tests HEAD, so those changes are not covered.' -ForegroundColor Yellow
   }

if (Test-Path $Dest) { Remove-Item -Recurse -Force $Dest }

& git clone --quiet --local $REPO $Dest
if ($LASTEXITCODE -ne 0)
   {
   Write-Host 'FAILED: git clone' -ForegroundColor Red
   exit 1
   }

$args = @()
if ($WithInstaller) { $args += '-BuildInstaller' }

Write-Host ''
Write-Host "  running: FullBuild.ps1 $($args -join ' ')  (no other arguments)" -ForegroundColor Cyan
Write-Host ''

$build = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Dest 'tr4w\FullBuild.ps1') @args 2>&1
$rc = $LASTEXITCODE

$build | ForEach-Object { Write-Host "  $_" }

Write-Host ''
if ($rc -ne 0)
   {
   Write-Host "=== FRESH CLONE FAILED (exit $rc) ===" -ForegroundColor Red
   Write-Host "  clone kept at $Dest for inspection"
   exit 1
   }

# Check the artifacts exist rather than trusting the exit code -- a build that
# reports success and produces nothing is the failure this is guarding against.
$expected = @(
   @{ Path = Join-Path $Dest 'tr4w\target\tr4w.exe';                Name = 'tr4w.exe' }
   @{ Path = Join-Path $Dest 'tr4w\tr4wserver\tr4wserver.exe';      Name = 'tr4wserver.exe' }
)
if ($WithInstaller)
   {
   $expected += @{ Path = Join-Path $Dest 'tr4w\build\release'; Name = 'installer'; Wildcard = 'tr4w_setup_*.exe' }
   }

$missing = 0
foreach ($e in $expected)
   {
   if ($e.Wildcard)
      {
      $hit = Get-ChildItem -Path $e.Path -Filter $e.Wildcard -ErrorAction SilentlyContinue | Select-Object -First 1
      if ($hit) { Write-Host "  OK  $($hit.Name) ($([int]($hit.Length / 1KB)) KB)" -ForegroundColor Green }
      else      { Write-Host "  MISSING  $($e.Name)" -ForegroundColor Red; $missing++ }
      }
   elseif (Test-Path $e.Path)
      {
      Write-Host "  OK  $($e.Name) ($([int]((Get-Item $e.Path).Length / 1KB)) KB)" -ForegroundColor Green
      }
   else
      {
      Write-Host "  MISSING  $($e.Name)" -ForegroundColor Red
      $missing++
      }
   }

# COMPARE THE BINARIES against the ones built in the working tree, when they
# exist. A size difference means the working tree is contributing something the
# clone does not have -- an untracked file being linked, which is exactly the
# defect this test was written after.
$localApp  = Join-Path $TR4W_DIR 'target\tr4w.exe'
$localSrv  = Join-Path $TR4W_DIR 'tr4wserver\tr4wserver.exe'
$pairs = @(
   @{ Local = $localApp; Fresh = (Join-Path $Dest 'tr4w\target\tr4w.exe');           Name = 'tr4w.exe' }
   @{ Local = $localSrv; Fresh = (Join-Path $Dest 'tr4w\tr4wserver\tr4wserver.exe'); Name = 'tr4wserver.exe' }
)

$drift = 0
foreach ($p in $pairs)
   {
   if ((Test-Path $p.Local) -and (Test-Path $p.Fresh))
      {
      $a = (Get-Item $p.Local).Length
      $b = (Get-Item $p.Fresh).Length
      if ($a -ne $b)
         {
         Write-Host ''
         Write-Host "  DRIFT: $($p.Name) is $a bytes here but $b in the clone." -ForegroundColor Yellow
         Write-Host '         Something in the working tree is affecting the build that a clone'
         Write-Host '         does not have -- usually an untracked file being linked.'
         $drift++
         }
      }
   }

if (-not $Keep)
   {
   Remove-Item -Recurse -Force $Dest -ErrorAction SilentlyContinue
   }
else
   {
   Write-Host ''
   Write-Host "  clone kept at $Dest"
   }

Write-Host ''
if ($missing -gt 0)
   {
   Write-Host '=== FRESH CLONE FAILED: build reported success but artifacts are missing ===' -ForegroundColor Red
   exit 1
   }

if ($drift -gt 0)
   {
   Write-Host '=== FRESH CLONE BUILT, BUT DIFFERS FROM THE WORKING TREE ===' -ForegroundColor Yellow
   exit 2
   }

Write-Host '=== FRESH CLONE OK -- clone, build, ship ===' -ForegroundColor Green
exit 0
