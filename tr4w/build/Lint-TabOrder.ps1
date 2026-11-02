<#
.SYNOPSIS
   Fails if a designed form's TabOrder disagrees with its reading order.

.DESCRIPTION
   An .lfm stores a TabOrder per windowed control and nothing ties it to where
   the control sits.  The numbers are the order the controls were CREATED in,
   so moving a control in the designer leaves Tab jumping around the page --
   the Preferences window shipped that way on nearly every page (NY4I,
   2026-11-02), and every value was individually legal, so nothing saw it.

   The rule, the column declarations and the ratchet for forms not yet fixed
   are in tools/lfm_taborder.py and build/lint-taborder.txt.  To fix a form:

      python tools\lfm_taborder.py fix --config tr4w\build\lint-taborder.txt <form>.lfm

   Only TRACKED .lfm files are judged (git ls-files), so the IDE's backup\
   copies are never read.
#>

param(
   [string] $SourceDir = ''
)

$ErrorActionPreference = 'Stop'

$here   = Split-Path -Parent $MyInvocation.MyCommand.Path
$repo   = Split-Path (Split-Path $here -Parent) -Parent
$tool   = Join-Path $repo 'tools\lfm_taborder.py'
$config = Join-Path $here 'lint-taborder.txt'

if (-not (Test-Path -LiteralPath $tool))
   {
   Write-Host "Lint-TabOrder: FAILED -- no checker at $tool"
   exit 1
   }

# PYTHON IS NOT A BUILD REQUIREMENT for this tree, so a missing interpreter
# skips, loudly, rather than fails -- the same rule as Lint-MainElements.
$python = Get-Command python -ErrorAction SilentlyContinue
if (-not $python)
   {
   Write-Host 'Lint-TabOrder: SKIPPED -- python not on PATH'
   exit 0
   }

$files = @(& git -C $repo ls-files '*.lfm' | ForEach-Object { Join-Path $repo $_ })
if ($LASTEXITCODE -ne 0 -or $files.Count -eq 0)
   {
   Write-Host 'Lint-TabOrder: FAILED -- git ls-files found no .lfm files'
   exit 1
   }

$out = & $python.Source $tool check --config $config @files 2>&1
$rc  = $LASTEXITCODE

$out | ForEach-Object { Write-Host "  $_" }

if ($rc -ne 0)
   {
   Write-Host 'Lint-TabOrder: a form tabs out of reading order (or the allow-list is stale).'
   Write-Host '  Fix:  python tools\lfm_taborder.py fix --config tr4w\build\lint-taborder.txt <form>.lfm'
   exit 1
   }

exit 0
