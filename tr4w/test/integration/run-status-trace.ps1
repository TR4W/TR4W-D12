<#
.SYNOPSIS
   Builds and runs the radio status-pipeline trace, and diffs it against a
   recorded baseline.

.DESCRIPTION
   The A/B oracle for moving radio status off RadioObject.  It drives a fixed
   script of states through the REAL uRadioPolling.UpdateStatus and records
   every decision it makes as JSONL.

   Unlike run-bench.ps1 this needs no serial port, no virtual COM pair, no
   Python and no simulator: the sequence is scripted, so the output is a pure
   function of the code under test.  Two runs of the same build are
   byte-identical, which is what makes a diff meaningful.

   -Update rewrites the baseline.  Do that ONLY when a trace change is
   understood and intended -- the baseline is the record of what the status
   pipeline did before the refactor, and silently refreshing it discards the
   only evidence the behaviour was preserved.

.EXAMPLE
   .\run-status-trace.ps1                # build, run, diff against baseline
   .\run-status-trace.ps1 -Update        # accept the current output as baseline
#>
[CmdletBinding()]
param(
   [switch]$Update,
   [switch]$SkipBuild
)

$ErrorActionPreference = 'Stop'
$here     = Split-Path -Parent $MyInvocation.MyCommand.Path
$exe      = Join-Path $here 'tr4w_status_trace.exe'
$baseline = Join-Path $here 'status_trace_baseline.jsonl'
$actual   = Join-Path $here 'status_trace_actual.jsonl'

if (-not $SkipBuild) {
   $rsvars = 'C:\Program Files (x86)\Embarcadero\Studio\23.0\bin\rsvars.bat'
   if (-not (Test-Path $rsvars)) {
      throw "rsvars.bat not found at $rsvars -- adjust this script for your Delphi install."
   }
   Write-Host 'Building tr4w_status_trace...' -ForegroundColor Cyan
   # msbuild, not dcc32: DCC32 is retired on this branch (see CLAUDE.md).
   & cmd /c "call `"$rsvars`" && cd /d `"$here`" && msbuild tr4w_status_trace.lproj /t:Build /p:Config=Debug /p:Platform=Win32 /v:minimal /nologo"
   if ($LASTEXITCODE -ne 0) { throw "build failed ($LASTEXITCODE)" }
}

if (-not (Test-Path $exe)) { throw "missing $exe" }

# stdout is the JSONL; the step/event tally goes to stderr so it cannot
# contaminate a diff.
& $exe 1> $actual 2> "$actual.tally"
if ($LASTEXITCODE -ne 0) { throw "trace run failed ($LASTEXITCODE)" }
Write-Host ("trace: {0}" -f (Get-Content "$actual.tally" -Raw).Trim())

if ($Update -or -not (Test-Path $baseline)) {
   Copy-Item $actual $baseline -Force
   Write-Host "baseline written: $baseline" -ForegroundColor Yellow
   if (-not $Update) {
      Write-Host 'No baseline existed, so this run became it.  Nothing was compared.' -ForegroundColor Yellow
   }
   exit 0
}

$diff = Compare-Object (Get-Content $baseline) (Get-Content $actual)
if (-not $diff) {
   Write-Host 'STATUS TRACE: identical to baseline.' -ForegroundColor Green
   Remove-Item $actual, "$actual.tally" -Force -ErrorAction SilentlyContinue
   exit 0
}

Write-Host 'STATUS TRACE DIFFERS FROM BASELINE' -ForegroundColor Red
Write-Host ''
$diff | Select-Object -First 40 | ForEach-Object {
   $mark = if ($_.SideIndicator -eq '<=') { 'baseline' } else { 'actual  ' }
   Write-Host ("  {0}  {1}" -f $mark, $_.InputObject.Substring(0, [Math]::Min(140, $_.InputObject.Length)))
}
Write-Host ''
Write-Host ("{0} differing line(s).  Full output: {1}" -f $diff.Count, $actual)
Write-Host 'If this change is understood and intended, re-run with -Update.'
exit 1
