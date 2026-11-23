<#
.SYNOPSIS
   Fails the build when a log-writing unit asks the RTL for the time itself.
   Every log timestamp comes from uLogTime (UTC, ISO order, 24-hour, with a Z).

.DESCRIPTION
   WHY THIS EXISTS (NY4I, 2026-11-23). Logs arrive from all over the world, so
   a log time is UTC with a Z -- and it is made in ONE place, so no two logs can
   disagree about what time it is. Before this, tr4w.log was stamped by Log4D
   (Now at the moment of formatting), the early-start trace by its own
   FormatDateTime, and the Telnet trace by a third.

   WHAT IS A VIOLATION. In a unit that writes a log line -- the list below --
   live code (comments and strings stripped) that names Now, UTCNow,
   FormatDateTime, DateTimeToStr, TimeToStr, DateToStr, GetLocalTime or
   GetSystemTime. The fix is LogUtcNow / LogTimeText / LogNowText from uLogTime,
   never a local format.

   THE FLOOR. Every listed file must exist (a renamed unit must not quietly drop
   out of the scan) and the built-in fixture must come out exact.

   .\Lint-LogTime.ps1             # the tree (Run-Lints passes the tr4w directory)
   .\Lint-LogTime.ps1 -SelfTest   # the fixture only
#>
param(
   [string] $SourceDir,
   [switch] $SelfTest
)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'PascalSource.psm1') -Force

if (-not $SourceDir) {
   $SourceDir = Split-Path -Parent $PSScriptRoot
}

# The units that write a log line or a log timestamp. Paths relative to tr4w.
$LOG_UNITS = @(
   'include\Log4D.pas',
   'src\uCrashLog.pas',
   'src\ui\lcl\uCrashLogLCL.pas',
   'src\uLogConfig.pas',
   'src\uTelnetTrace.pas'
)

$script:TimeCall = [regex] '(?i)(?<![\w.])(Now|UTCNow|FormatDateTime|DateTimeToStr|TimeToStr|DateToStr|GetLocalTime|GetSystemTime)(?![\w])'

function Find-TimeCalls
{
   param([string] $Path)

   $code = Get-PascalCodeOnlyText -Path $Path -BlankStrings
   $hits = New-Object System.Collections.ArrayList
   $lineNo = 1
   foreach ($line in ($code -split "`n")) {
      foreach ($m in $script:TimeCall.Matches($line)) {
         [void] $hits.Add([pscustomobject]@{ Line = $lineNo; Name = $m.Value })
      }
      $lineNo++
   }
   return @($hits)
}

function Invoke-LogTimeSelfTest
{
   $fixture = @(
      'unit fixture;'
      'interface'
      'implementation'
      'procedure T;'
      'begin'
      '   s := FormatDateTime(fmt, Now);              // HIT'
      '   x := UTCNow;                                // HIT'
      '   s := LogNowText;'
      '   s := LogTimeText(ev.TimeStamp);'
      '   n := Obj.Now;'
      '   n := NowPlaying;'
      '   Log(''Now'');'
      '   // Now'
      '   (* FormatDateTime *)'
      'end;'
      'end.'
   )

   $expected = @{}
   for ($i = 0; $i -lt $fixture.Count; $i++) {
      if ($fixture[$i] -match '// HIT$') { $expected[$i + 1] = $true }
   }

   $tmp = Join-Path ([IO.Path]::GetTempPath()) ('lint-logtime-' + [Guid]::NewGuid().ToString('N') + '.pas')
   try {
      [IO.File]::WriteAllText($tmp, ($fixture -join "`r`n") + "`r`n")
      $hits = Find-TimeCalls -Path $tmp
   }
   finally {
      Remove-Item -LiteralPath $tmp -ErrorAction SilentlyContinue
   }

   $seen = @{}
   foreach ($h in $hits) { $seen[$h.Line] = $true }
   $ok = ($seen.Count -eq $expected.Count)
   foreach ($k in $expected.Keys) { if (-not $seen.ContainsKey($k)) { $ok = $false } }
   if (-not $ok) {
      Write-Host "Lint-LogTime SELF-TEST FAILED: expected lines $(($expected.Keys | Sort-Object) -join ','), saw $(($seen.Keys | Sort-Object) -join ',')" -ForegroundColor Red
      exit 1
   }
}

Invoke-LogTimeSelfTest
if ($SelfTest) {
   Write-Host 'Lint-LogTime: self-test passed.'
   exit 0
}

$failures = New-Object System.Collections.ArrayList
foreach ($rel in $LOG_UNITS) {
   $path = Join-Path $SourceDir $rel
   if (-not (Test-Path -LiteralPath $path)) {
      [void] $failures.Add("$rel is listed in Lint-LogTime but does not exist -- update the list")
      continue
   }
   foreach ($h in (Find-TimeCalls -Path $path)) {
      [void] $failures.Add("${rel}:$($h.Line) uses $($h.Name) -- a log time comes from uLogTime (LogUtcNow / LogTimeText / LogNowText)")
   }
}

if ($failures.Count -gt 0) {
   Write-Host "Lint-LogTime: $($failures.Count) violation(s)" -ForegroundColor Red
   $failures | ForEach-Object { Write-Host "  $_" }
   exit 1
}

Write-Host "Lint-LogTime: $($LOG_UNITS.Count) log-writing units use no clock of their own."
exit 0
