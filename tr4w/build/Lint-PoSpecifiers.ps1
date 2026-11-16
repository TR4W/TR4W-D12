<#
.SYNOPSIS
   Fails the build when a translation has lost, added or changed a format
   specifier of its English (review 2026-11-16, finding M19).

.DESCRIPTION
   WHY THIS EXISTS. TR4W formats through unchecked varargs, so a catalogue entry
   whose msgstr has lost its %d shows the operator no number, and one whose %d
   became %s dereferences an integer as a pointer. Four reviewed entries had lost
   a specifier -- two Ukrainian entries (the CQ total and the band-change count),
   two Mongolian entries one argument short -- and tools/i18n/po_lint.py had reported them for
   months, but it was in no gate.

   This runs `po_lint.py --specifiers` over every i18n/tr4w_*.po. That mode is the
   specifier rule ONLY (po_lint.same_specifiers: order matters unless every
   specifier carries an index): the rest of po_lint's report is a translator's
   backlog, not a crash, and is not gated here.

   CEILING 0. The baseline on 2026-11-16 was 4, all fixed in the same change, so
   any mismatch is new. The ceiling can only ever be 0; there is nothing to raise.

   FLOORS, so the gate cannot pass by comparing nothing: at least 15 catalogues
   and 20000 entries (measured: 21 and 27493). Fails closed without python, with
   a missing script, or with output it cannot read.

   The lint ignores -SourceDir; the repository root comes from this script's
   own location.
#>
param(
   [string] $Repo = (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent)
)

$ErrorActionPreference = 'Stop'

$CEILING = 0
$MIN_CATALOGUES = 15
$MIN_ENTRIES = 20000

$tool = Join-Path $Repo 'tools\i18n\po_lint.py'
$test = Join-Path $Repo 'tools\i18n\test_po_lint.py'

foreach ($p in @($tool, $test))
   {
   if (-not (Test-Path -LiteralPath $p))
      {
      Write-Host "Lint-PoSpecifiers: MISSING $p" -ForegroundColor Red
      exit 1
      }
   }

$python = Get-Command python -ErrorAction SilentlyContinue
if (-not $python)
   {
   Write-Host 'Lint-PoSpecifiers: python is not on PATH, so the catalogues cannot be checked. Failing closed.' -ForegroundColor Red
   exit 1
   }

# unittest reports on stderr, and Windows PowerShell turns a native stderr line
# into a terminating error under 'Stop'. The exit code is the verdict.
$ErrorActionPreference = 'Continue'
$output = & $python.Source -I $test 2>&1
$code = $LASTEXITCODE
if ($code -ne 0)
   {
   Write-Host (($output | Out-String).Trim())
   Write-Host "Lint-PoSpecifiers: po_lint's own tests FAILED (exit $code)." -ForegroundColor Red
   exit 1
   }

$output = & $python.Source -I $tool --specifiers 2>&1
$code = $LASTEXITCODE
$text = ($output | Out-String).Trim()

if ($text -notmatch 'po_lint --specifiers: (\d+) catalogue\(s\), (\d+) entries compared, (\d+) mismatch')
   {
   Write-Host $text
   Write-Host 'Lint-PoSpecifiers: the summary line is missing, so nothing is known about the catalogues. Failing closed.' -ForegroundColor Red
   exit 1
   }

$catalogues = [int] $Matches[1]
$entries = [int] $Matches[2]
$mismatches = [int] $Matches[3]

if (($catalogues -lt $MIN_CATALOGUES) -or ($entries -lt $MIN_ENTRIES))
   {
   Write-Host "Lint-PoSpecifiers: only $catalogues catalogues and $entries entries were compared (floors $MIN_CATALOGUES and $MIN_ENTRIES). A check that compares nothing passes everything. Failing closed." -ForegroundColor Red
   exit 1
   }

if (($mismatches -gt $CEILING) -or ($code -ne 0))
   {
   Write-Host $text
   Write-Host "Lint-PoSpecifiers: FAILED -- $mismatches specifier mismatch(es), ceiling $CEILING (exit $code). Restore the specifier in the translation; never raise the ceiling." -ForegroundColor Red
   exit 1
   }

Write-Host "Lint-PoSpecifiers: $catalogues catalogues, $entries entries compared, no specifier mismatch."
exit 0
