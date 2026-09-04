<#
.SYNOPSIS
   Fails if uMainForm.lfm has drifted from VC.pas's TWindows[] table.

.DESCRIPTION
   The main window's 43 status panels are DESIGNED components -- they are in the
   .lfm so that opening tr4w.lpi and pressing F12 shows them -- and they are
   GENERATED from TWindows[], which is still the layout the program computes
   from at run time.

   TWO COPIES OF A LAYOUT DRIFT, and this pair would drift silently: add a row
   to TWindows[] and the program positions an element that has no component, so
   a status readout never appears and nothing says why. Delete a row and the
   .lfm carries a panel nothing drives.

   The generator is the single source; this only asks whether the file on disk
   is what the generator would write. It is the same shape as the corpus:
   regenerate, compare, report the difference rather than repair it silently.

   Run tools/gen_main_elements.py to fix a failure.
#>

param(
   [string] $SourceDir = ''
)

$ErrorActionPreference = 'Stop'

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$repo = Split-Path (Split-Path $here -Parent) -Parent
$gen  = Join-Path $repo 'tools\gen_main_elements.py'

if (-not (Test-Path -LiteralPath $gen))
   {
   Write-Host "Lint-MainElements: SKIPPED -- no generator at $gen"
   exit 0
   }

# PYTHON IS NOT A BUILD REQUIREMENT for this tree, so a missing interpreter
# skips rather than fails.  A lint nobody can run is worse than one that says
# it did not run -- see the note on guards failing open in Run-Lints.
$python = Get-Command python -ErrorAction SilentlyContinue
if (-not $python)
   {
   Write-Host 'Lint-MainElements: SKIPPED -- python not on PATH'
   exit 0
   }

$out = & $python.Source $gen --check 2>&1
$rc  = $LASTEXITCODE

$out | ForEach-Object { Write-Host "  $_" }

if ($rc -ne 0)
   {
   Write-Host 'Lint-MainElements: uMainForm.lfm and VC.pas TWindows[] disagree.'
   Write-Host '  Run:  python tools\gen_main_elements.py'
   exit 1
   }

exit 0
