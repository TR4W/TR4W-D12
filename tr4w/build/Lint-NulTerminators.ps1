<#
.SYNOPSIS
   Fails the build on a hand-written NUL terminator after the end of a string.

.DESCRIPTION
   WHY THIS EXISTS (NY4I, 2026-11-02): "we are supposed to be out of the
   business of terminating our own strings". The program passes real strings;
   a NUL written one past the end of one is a Win32-era habit, from when the
   string was about to be handed to a PChar parameter.

   THE SHAPE FORBIDDEN, in code (comments and string literals excluded):

       Call[Ord(Call[0]) + 1] := #0;
       FileString[length(FileString) + 1] := #0;
       s[l + 1] := Chr(0);

   Two reasons it is wrong, not one. Nothing downstream wanted it: every site
   found handed the string to a Pascal routine, never to a PChar. And on a
   ShortString at its declared maximum, index Length + 1 is one byte PAST the
   variable -- a latent overrun nobody could see.

   WHAT TO WRITE INSTEAD. Nothing, when the callee takes a string. At a real
   PChar boundary, convert there (a temporary AnsiString passed to the call) and
   say why in a comment.

   NOT FLAGGED, deliberately: a NUL written at an index that is not "something
   + 1" -- a fixed-size wire field or a character buffer (uNet's ssCallsign,
   msCWMessage) is a byte layout, a different question.

   THE CEILING IS ZERO. A built-in fixture runs first, so a broken pattern
   fails rather than passing a clean tree; and MainUnit.pas must be in the scan,
   so a wrong -SourceDir cannot report a pass on nothing.

   .\Lint-NulTerminators.ps1              # the tree (Run-Lints passes -SourceDir)
   .\Lint-NulTerminators.ps1 -SelfTest    # the fixture only
#>
param(
   [string] $SourceDir,
   [switch] $SelfTest
)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'PascalSource.psm1') -Force
. (Join-Path $PSScriptRoot 'Get-ScanExclusions.ps1')   # Test-Tr4wScannable

if (-not $SourceDir) {
   $SourceDir = Split-Path -Parent $PSScriptRoot
}

# `<anything> + 1 ] := #0` -- also #00, #$0, #$00 and Chr(0).
$script:Shape = [regex] '(?i)\+\s*1\s*\]\s*:=\s*(?:#\$?0+\b|Chr\s*\(\s*0+\s*\))'

function Find-NulTerminators
{
   param([string] $Path)

   $code = Get-PascalCodeOnlyText -Path $Path -BlankStrings
   $hits = New-Object System.Collections.ArrayList
   foreach ($m in $script:Shape.Matches($code)) {
      $line = 1 + ($code.Substring(0, $m.Index) -split "`n").Count - 1
      [void] $hits.Add($line)
   }
   return @($hits)
}

function Invoke-NulTerminatorsSelfTest
{
   $fixture = @(
      'unit fixture;'
      'interface'
      'implementation'
      'procedure T;'
      'begin'
      '   Call[Ord(Call[0]) + 1] := #0;              // HIT'
      '   s[length(s) + 1] := #0;                    // HIT'
      '   s[l+1] := Chr(0);                          // HIT'
      '   s[l + 1] := #$00;                          // HIT'
      '   buf[n] := #0;'
      '   buf[n + 1] := ''x'';'
      '   buf[n + 1] := #10;'
      '   x := ''s[l + 1] := #0'';'
      '   // s[l + 1] := #0;'
      '   (* s[l + 1] := #0; *)'
      '   { s[l + 1] := #0; }'
      'end;'
      'end.'
   )

   $expected = @()
   for ($i = 0; $i -lt $fixture.Count; $i++) {
      if ($fixture[$i] -match '// HIT$') {
         $expected += ($i + 1)
      }
   }

   $tmp = Join-Path ([IO.Path]::GetTempPath()) ('lint-nul-' + [Guid]::NewGuid().ToString('N') + '.pas')
   try {
      [IO.File]::WriteAllText($tmp, ($fixture -join "`r`n") + "`r`n")
      $seen = Find-NulTerminators -Path $tmp
   }
   finally {
      Remove-Item -LiteralPath $tmp -ErrorAction SilentlyContinue
   }

   if ((@($seen) -join ',') -ne (@($expected) -join ',')) {
      Write-Host ("  self-test: expected hits at lines [{0}], got [{1}]" -f ($expected -join ','), ($seen -join ','))
      return $false
   }
   Write-Host ("Lint-NulTerminators: self-test OK ({0} expected hits, {1} reported)." -f $expected.Count, @($seen).Count)
   return $true
}

if (-not (Invoke-NulTerminatorsSelfTest)) {
   Write-Output "Lint-NulTerminators: SELF-TEST FAILED -- refusing to judge the tree."
   exit 1
}
if ($SelfTest) {
   exit 0
}

if (-not (Test-Path -LiteralPath $SourceDir -PathType Container)) {
   Write-Output "Lint-NulTerminators: source directory not found: $SourceDir"
   exit 1
}

$files = @(Get-TR4WPascalFiles -Root $SourceDir |
           Where-Object { (Test-Tr4wScannable $_.FullName) -and
                          $_.FullName -notmatch '\\graphify-out\\' })

if (-not ($files | Where-Object { $_.Name -ieq 'MainUnit.pas' })) {
   Write-Output ("Lint-NulTerminators: MainUnit.pas is not under '{0}' ({1} file(s)) -- wrong -SourceDir? Refusing to report a pass." -f $SourceDir, $files.Count)
   exit 1
}

$violations = New-Object System.Collections.ArrayList
foreach ($f in $files) {
   $hits = Find-NulTerminators -Path $f.FullName
   if ($hits.Count -gt 0) {
      $lines = [IO.File]::ReadAllLines($f.FullName)
      foreach ($h in $hits) {
         $rel = $f.FullName.Substring($SourceDir.TrimEnd('\').Length).TrimStart('\')
         [void] $violations.Add(("  {0}:{1}  {2}" -f $rel, $h, $lines[$h - 1].Trim()))
      }
   }
}

if ($violations.Count -gt 0) {
   $violations | ForEach-Object { Write-Output $_ }
   Write-Output ("Lint-NulTerminators: {0} hand-written NUL terminator(s) after a string." -f $violations.Count)
   Write-Output "  Delete it: nothing downstream wants it, and on a ShortString at its maximum"
   Write-Output "  length it writes one byte past the variable. At a real PChar boundary, convert"
   Write-Output "  there with a temporary AnsiString and say why."
   exit 1
}

Write-Output ("Lint-NulTerminators: {0} file(s) checked; no hand-written NUL terminator after a string." -f $files.Count)
exit 0
