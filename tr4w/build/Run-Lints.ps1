# Runs every gating lint, once, from one place.
#
# WHY THIS EXISTS.  The lint list lived only in tr4w.dproj's PreBuildEvent, so
# it gated the DELPHI build and nothing else.  As FPC becomes the shipping
# toolchain that arrangement silently drops all of them: an FPC build would be
# green with a duplicate radio registration, an LF source file, an unwired form
# event or an unstreamable .lfm.  A gate that only one of two build paths runs
# is not a gate.
#
# So the list lives here and both paths call it.  Adding a lint means editing
# ONE array, not remembering a second place.
#
#   powershell -File tr4w\build\Run-Lints.ps1
#   powershell -File tr4w\build\Run-Lints.ps1 -SkipSlow    # omit the FPC-built ones
#
# Exit code is the number of lints that failed, so a caller can test -ne 0.
# Every lint runs even after one fails: seeing all the problems at once is the
# whole point of a batch, and a lint that only ever reports the first defect is
# the exact frustration this repo has already paid for once with .lfm streaming.

param(
   [string] $Tr4wDir  = (Join-Path $PSScriptRoot '..'),
   [switch] $SkipSlow,
   [switch] $Quiet
)

$ErrorActionPreference = 'Continue'

$src   = Join-Path $Tr4wDir 'src'
$build = $PSScriptRoot

# NeedsFpc marks the lints that compile a helper (see Lint-LFMProperties) and so
# cost seconds rather than milliseconds on a cold run.
$lints = @(
   @{ Name = 'Lint-RadioRegistry';   Arg = $src;     NeedsFpc = $false }
   @{ Name = 'Lint-PollRadioState';  Arg = $src;     NeedsFpc = $false }
   @{ Name = 'Lint-PCharAnsi';       Arg = $src;     NeedsFpc = $false }
   @{ Name = 'Lint-LineEndings';     Arg = $Tr4wDir; NeedsFpc = $false }
   @{ Name = 'Lint-FormTags';        Arg = $src;     NeedsFpc = $false }
   @{ Name = 'Lint-FormFields';      Arg = $src;     NeedsFpc = $false }
   @{ Name = 'Lint-FormOverlap';     Arg = $src;     NeedsFpc = $false }
   @{ Name = 'Lint-FormEvents';      Arg = $src;     NeedsFpc = $false }
   @{ Name = 'Lint-ConfigOwnership'; Arg = $src;     NeedsFpc = $false }
   @{ Name = 'Lint-LFMProperties';   Arg = $src;     NeedsFpc = $true  }
)

$failed  = 0
$ran     = 0
$skipped = 0

foreach ($lint in $lints)
   {
   $path = Join-Path $build "$($lint.Name).ps1"

   # A MISSING LINT IS A FAILURE, not a skip.  A renamed or deleted script that
   # quietly stopped running is indistinguishable from a clean tree otherwise.
   if (-not (Test-Path -LiteralPath $path))
      {
      Write-Host "$($lint.Name): SCRIPT NOT FOUND at $path" -ForegroundColor Red
      $failed++
      continue
      }

   if ($SkipSlow -and $lint.NeedsFpc)
      {
      Write-Host "$($lint.Name): skipped (-SkipSlow)" -ForegroundColor DarkGray
      $skipped++
      continue
      }

   $out = & powershell -NoProfile -ExecutionPolicy Bypass -File $path -SourceDir $lint.Arg 2>&1
   $rc  = $LASTEXITCODE
   $ran++

   if ($rc -ne 0)
      {
      $failed++
      Write-Host ''
      Write-Host "=== $($lint.Name) FAILED (exit $rc) ===" -ForegroundColor Red
      $out | ForEach-Object { Write-Host "  $_" }
      }
   elseif (-not $Quiet)
      {
      $out | ForEach-Object { Write-Host "  $_" }
      }
   }

Write-Host ''
if ($failed -eq 0)
   {
   Write-Host "Run-Lints: $ran lint(s) passed$(if ($skipped) { ", $skipped skipped" })." -ForegroundColor Green
   }
else
   {
   Write-Host "Run-Lints: $failed of $($ran + $failed) lint(s) FAILED." -ForegroundColor Red
   }

exit $failed
