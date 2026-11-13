<#
.SYNOPSIS
   Runs the block-stdin-readers hook's own tests (issue 289). Fails the build if
   the hook stops refusing a bare interpreter that waits on standard input.

.DESCRIPTION
   WHY THIS EXISTS. .claude/hooks/block-stdin-readers.py is the only thing between
   an agent and a shell that waits on standard input for ever (2026-10-14: 1 day
   0 h 21 m). It failed open once -- `python - --version` was not refused -- and
   nothing noticed, because nothing tested it. The tests are
   .claude/hooks/test-block-stdin-readers.py; they run the real hook as a
   subprocess with the PreToolUse JSON read from a FILE, and never run any of the
   commands they judge, so they cannot hang.

   FAILS CLOSED. No python on PATH, a missing hook or test file, a non-zero exit
   or no "passed" summary line each fail the lint; the tests themselves also
   fail below a floor on the number of cases.

   The lint ignores -SourceDir (Run-Lints passes none for it); the repository
   root comes from this script's own location.
#>
param(
   [string] $Repo = (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent)
)

$ErrorActionPreference = 'Stop'

$test = Join-Path $Repo '.claude\hooks\test-block-stdin-readers.py'
$hook = Join-Path $Repo '.claude\hooks\block-stdin-readers.py'

foreach ($p in @($test, $hook))
   {
   if (-not (Test-Path -LiteralPath $p))
      {
      Write-Host "Lint-StdinHook: MISSING $p" -ForegroundColor Red
      exit 1
      }
   }

$python = Get-Command python -ErrorAction SilentlyContinue
if (-not $python)
   {
   Write-Host 'Lint-StdinHook: python is not on PATH, so the hook cannot be tested. Failing closed.' -ForegroundColor Red
   exit 1
   }

# The test script never reads standard input, and feeds the hook from files.
$output = & $python.Source -I $test 2>&1
$code = $LASTEXITCODE
$text = ($output | Out-String).Trim()

if (($code -ne 0) -or ($text -notmatch 'tests: \d+ passed'))
   {
   Write-Host $text
   Write-Host "Lint-StdinHook: FAILED (exit $code)." -ForegroundColor Red
   exit 1
   }

Write-Host "Lint-StdinHook: $text"
exit 0
