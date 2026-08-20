<#
.SYNOPSIS
   Runs the Edit QSO field round-trip: puts a probe value through every input
   control and fails if any does not come back unchanged.

.DESCRIPTION
   WHY THIS EXISTS, AND WHY A LINT WOULD NOT DO.

   Lint-EditQSOTemplate proves the WIRING -- that every control id in dialog 46
   reaches the component it should, and that the editable/inert check box split
   matches the template's style bits. It reads files, so it cannot prove that a
   VALUE survives the trip through a realised control.

   That is exactly what went wrong in 4f0339d4. The .lfm carried MaxLength for
   the fields the Win32 dialog limited with EM_SETLIMITTEXT, and those are not
   the same thing: EM_SETLIMITTEXT limits TYPING and never touched
   SetDlgItemText, while an LCL TEdit truncates on assignment. A callsign longer
   than twelve characters loaded short and was saved short -- silent corruption
   of the contest log, in the dialog whose job is editing it, with correct
   wiring and a correct-looking .lfm throughout.

   It also only happened once the control had a WINDOW HANDLE. A check against a
   form that was constructed but never realised would have passed. So the run is
   done by the real binary, with handles forced.

   HOW IT RUNS.  `tr4w.exe /FIELDCHECK` does the work and exits with the number
   of fields that failed. The arm sits before the single-instance mutex and
   before any config or log is touched, so this needs no contest, disturbs no
   settings, and runs while TR4W is already open. It takes about a second.

   PROVEN TO FAIL.  Backing out the MaxLength fix and re-running reports ten
   fields with their exact before/after lengths -- callsign, both RSTs, zone,
   check, age, Ten-Ten, prefecture, computer id, precedence. A check nobody has
   watched fail is not a check.

.PARAMETER Exe
   The binary to run. Defaults to the build output, then tr4w\target\tr4w.exe.

.OUTPUTS
   The report, and exit code 0 = every field survived.
#>
[CmdletBinding()]
param(
   [string] $Exe,
   [string] $WorkDir
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$tr4w = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$repo = Split-Path $tr4w -Parent

if (-not $Exe) {
   foreach ($candidate in @(
      (Join-Path $repo 'build-out\app-i386-win32\tr4w_fpc.exe'),
      (Join-Path $tr4w 'target\tr4w.exe'))) {
      if (Test-Path $candidate) { $Exe = $candidate; break }
   }
}
if (-not $Exe -or -not (Test-Path $Exe)) {
   Write-Output 'Invoke-FieldCheck: no tr4w binary found -- build first.'
   exit 1
}

# A scratch directory, because the binary writes its report into the working
# directory and this must not litter the repo.
if (-not $WorkDir) { $WorkDir = Join-Path ([IO.Path]::GetTempPath()) 'tr4w-fieldcheck' }
New-Item -ItemType Directory -Force -Path $WorkDir | Out-Null

$report = Join-Path $WorkDir 'editqso-fieldcheck.txt'
if (Test-Path $report) { Remove-Item $report -Force }

Write-Output "Invoke-FieldCheck: $Exe"
$proc = Start-Process -FilePath $Exe -ArgumentList '/FIELDCHECK' -WorkingDirectory $WorkDir -Wait -PassThru
$code = $proc.ExitCode

if (Test-Path $report) {
   Get-Content $report | ForEach-Object { Write-Output "  $_" }
} else {
   Write-Output '  (no report written)'
}

if ($code -ne 0) {
   Write-Output "Invoke-FieldCheck: FAILED -- exit $code."
   Write-Output '  A field that does not survive a set/get will not survive the log either.'
   exit 1
}

Write-Output 'Invoke-FieldCheck: every field round-tripped.'
exit 0
