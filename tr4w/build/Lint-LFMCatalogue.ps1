<#
.SYNOPSIS
   Fails the build when a designed form's caption has no entry in some language
   catalogue (issue 145).

.DESCRIPTION
   WHY THIS EXISTS. A designed form's text reached the catalogues only through
   the .lrj the Lazarus IDE writes when a form is saved IN THE IDE. Forms are
   mostly edited as text, so every control added or renamed since a form's last
   IDE save had no entry: 60 captions on 2026-11-15, nine forms with no .lrj at
   all, lblLanguage among them. TPOTranslator finds nothing to translate and the
   English shows in every language; nothing warned and nothing failed.

   tools/i18n/lfm_harvest.py reads the .lfm files themselves, so it does not
   depend on the IDE. This lint runs its tests first (the parser decides which
   identifier each caption has; a wrong one is a silent miss), then its --check:
   every Caption/Hint/Text/TextHint/Title of every form must be claimed by a
   live entry in every i18n/tr4w_*.po. An empty fuzzy entry counts -- that is
   the correct state for a new caption. A caption the .lfm marks as a run-time
   placeholder (its own control name, or '(assigned at run time)') is skipped.
   A caption reworded since its entry was written is printed as a WARNING and
   does not fail (fixing one rewrites an entry: docs/I18N_TOOLS.md).

   THE FIX IT PRINTS is additive and the only safe route:
      python tools/i18n/lfm_harvest.py --pot <scratch>.pot
      python tools/i18n/po_merge.py --pot <scratch>.pot --apply --add-only
   Never pas2po, never updatepofiles against tr4w_laz.pot.

   FAILS CLOSED. No python on PATH, a missing script, a failing test or a
   check that cannot read a form or a catalogue each fail the lint.

   The lint ignores -SourceDir (Run-Lints passes none for it); the repository
   root comes from this script's own location.
#>
param(
   [string] $Repo = (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent)
)

$ErrorActionPreference = 'Stop'

$tool = Join-Path $Repo 'tools\i18n\lfm_harvest.py'
$test = Join-Path $Repo 'tools\i18n\test_lfm_harvest.py'

foreach ($p in @($tool, $test))
   {
   if (-not (Test-Path -LiteralPath $p))
      {
      Write-Host "Lint-LFMCatalogue: MISSING $p" -ForegroundColor Red
      exit 1
      }
   }

$python = Get-Command python -ErrorAction SilentlyContinue
if (-not $python)
   {
   Write-Host 'Lint-LFMCatalogue: python is not on PATH, so the catalogues cannot be checked. Failing closed.' -ForegroundColor Red
   exit 1
   }

# unittest reports on stderr, and Windows PowerShell turns a native stderr
# line into a terminating error under 'Stop'. The exit code is the verdict.
$ErrorActionPreference = 'Continue'
$output = & $python.Source -I $test 2>&1
$code = $LASTEXITCODE
if ($code -ne 0)
   {
   Write-Host (($output | Out-String).Trim())
   Write-Host "Lint-LFMCatalogue: the harvester's own tests FAILED (exit $code)." -ForegroundColor Red
   exit 1
   }

$output = & $python.Source -I $tool --check 2>&1
$code = $LASTEXITCODE
$text = ($output | Out-String).Trim()
Write-Host $text

if (($code -ne 0) -or ($text -notmatch 'lfm_harvest: OK'))
   {
   Write-Host "Lint-LFMCatalogue: FAILED (exit $code)." -ForegroundColor Red
   exit 1
   }

exit 0
