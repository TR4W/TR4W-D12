<#
.SYNOPSIS
   Fail the build if a unit test turns a contest object back into its legacy
   ContestType member the silent way: ContestOf(...) (deleted), or the same
   thing spelled out, LegacyContestOf(HandleOf(...)).

.DESCRIPTION
   WHY THIS EXISTS -- issue #96 (2026-10-26).

   A contest registered by its id (Q108 S3: Georgia, URC, the test fixture)
   has no ContestType member, and LegacyContestOf answers DUMMYCONTEST for it.
   The registry walks in tr4w/test/unit took each walked object back to its
   member with uTestRegisteredContests.ContestOf and then asked about THAT --
   built its station, asked its identity, printed its name. For a by-id
   contest every one of those was "no contest", and the walk passed because
   nothing it asked happened to differ. It surfaced only when Georgia, a
   party, met a party-only branch (uTestContestExport.PartyQSO).

   ContestOf is deleted. A walk keeps the OBJECT, or HandleOf it, and reaches
   the frozen enum only through uTestRegisteredContests.IsLegacyContest (a
   handle comparison) or TryLegacyContestOf (False for a by-id contest, so
   the caller must say what such a contest is held to). This lint stops the
   old shape coming back under either spelling.

   THERE IS NO ALLOW-LIST: nothing needs either shape. A pin keyed by the enum
   names its member directly (ContestIdentity(CQWWCW)); it never derives one
   from an object.

   READ THROUGH PascalSource.psm1, so a comment or a string that names the
   shape is not a use. Scope: tr4w/test (src is Lint-ContestNameTests'
   business). Fails closed: the fixture must pass, and scanning zero files
   fails.

.EXAMPLE
   .\Lint-RegistryWalks.ps1
   .\Lint-RegistryWalks.ps1 -SelfTest
#>

param(
   [string] $SourceDir = (Join-Path (Split-Path $PSScriptRoot -Parent) 'test'),
   # Run the fixture and the parser's own fixtures, then stop.
   [switch] $SelfTest
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'PascalSource.psm1') -Force
. (Join-Path $PSScriptRoot 'Get-ScanExclusions.ps1')   # Test-Tr4wScannable -- IDE backup dirs are not source

# ContestOf as an identifier of its own -- LegacyContestOf and
# TryLegacyContestOf have a letter before it, so they do not match.
$script:ContestOfRx = [regex]::new('(?<![\w])ContestOf(?![\w])', 'IgnoreCase')
# The same derivation written out: an object's handle turned into a member.
$script:SpelledOutRx = [regex]::new('(?<![\w])LegacyContestOf\s*\(\s*HandleOf\s*\(', 'IgnoreCase')

# Every use in one file's code-only text: line number and which shape.
function Find-LegacyDerivations
{
   param([string] $Text)

   $hits = @()
   $lines = $Text -split "`n"
   for ($i = 0; $i -lt $lines.Count; $i++)
   {
      $line = $lines[$i]
      if ($script:ContestOfRx.IsMatch($line))
      {
         $hits += [pscustomobject]@{ Line = $i + 1; Shape = 'ContestOf' }
      }
      if ($script:SpelledOutRx.IsMatch($line))
      {
         $hits += [pscustomobject]@{ Line = $i + 1; Shape = 'LegacyContestOf(HandleOf' }
      }
   }
   return $hits
}

# --------------------------------------------------------------------------
# THE FIXTURE -- every shape, before any tree number is believed.
# --------------------------------------------------------------------------
function Invoke-FixtureCheck
{
   $fixture = @(
      'unit F;'
      'implementation'
      'procedure P(obj: TContestBase);'
      'begin'
      '   c := ContestOf(obj);'                              # line 5: the deleted helper
      '   c := LegacyContestOf(HandleOf(obj));'              # line 6: spelled out
      '   c := LegacyContestOf(x.ceContest);'                # line 7: a record's contest -- fine
      '   b := TryLegacyContestOf(obj, c);'                  # line 8: the replacement
      '   b := IsLegacyContest(obj, CQWWCW);'                # line 9: the replacement
      '   // c := ContestOf(obj) in a comment'
      '   (* LegacyContestOf(HandleOf(obj)) in a comment *)'
      '   s := ''ContestOf(obj) in a string'';'
      '   c := uTestRegisteredContests.ContestOf (obj);'     # line 13: qualified, spaced
      'end;'
      'end.'
   )
   $tmp = Join-Path ([IO.Path]::GetTempPath()) ('registrywalks_' + [Guid]::NewGuid().ToString('N') + '.pas')
   try
   {
      [IO.File]::WriteAllText($tmp, ($fixture -join "`r`n"))
      $text = Get-PascalCodeOnlyText -Path $tmp -BlankStrings
      $got  = @(Find-LegacyDerivations -Text $text | ForEach-Object { '{0}:{1}' -f $_.Line, $_.Shape })
   }
   finally
   {
      if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Force }
   }
   $expected = @('5:ContestOf', '6:LegacyContestOf(HandleOf', '13:ContestOf')

   $bad = 0
   if (($got -join ',') -ne ($expected -join ','))
   {
      $bad++
      Write-Host 'FIXTURE FAIL' -ForegroundColor Red
      Write-Host ('   expected: {0}' -f ($expected -join ', ')) -ForegroundColor Red
      Write-Host ('   got     : {0}' -f ($got -join ', ')) -ForegroundColor Red
   }
   elseif ($SelfTest)
   {
      Write-Host 'FIXTURE ok   both shapes found; the replacements, comments and strings left alone'
   }
   $bad += Invoke-PascalSourceSelfTest
   return $bad
}

if (-not (Test-Path -LiteralPath $SourceDir))
{
   Write-Host "Lint-RegistryWalks: test directory not found: $SourceDir -- that is a failure, not a pass." -ForegroundColor Red
   exit 1
}
$testRoot = (Resolve-Path -LiteralPath $SourceDir).Path.TrimEnd('\')

if ((Invoke-FixtureCheck) -ne 0)
{
   Write-Host 'Lint-RegistryWalks: the fixture failed -- the parse cannot be trusted, which is not a pass.' -ForegroundColor Red
   exit 1
}
if ($SelfTest)
{
   exit 0
}

$files = @(Get-TR4WPascalFiles -Root $testRoot |
           Where-Object { (Test-Tr4wScannable $_.FullName) -and $_.FullName -notmatch '\\graphify-out\\' })
if ($files.Count -eq 0)
{
   Write-Host "Lint-RegistryWalks: scanned ZERO files under $testRoot -- that is a broken lint, not a pass." -ForegroundColor Red
   exit 1
}

$violations = @()
foreach ($f in $files)
{
   $rel  = $f.FullName.Substring($testRoot.Length).TrimStart('\')
   $text = Get-PascalCodeOnlyText -Path $f.FullName -BlankStrings
   foreach ($hit in (Find-LegacyDerivations -Text $text))
   {
      $violations += [pscustomobject]@{ File = $rel; Line = $hit.Line; Shape = $hit.Shape }
   }
}

Write-Host ('Lint-RegistryWalks: {0} test file(s) scanned.' -f $files.Count)

if ($violations.Count -gt 0)
{
   foreach ($v in $violations)
   {
      Write-Host ('  {0}({1}): {2}' -f $v.File, $v.Line, $v.Shape) -ForegroundColor Red
   }
   Write-Host ''
   Write-Host ('Lint-RegistryWalks FAILED -- {0} object-to-legacy-member derivation(s).' -f $violations.Count) -ForegroundColor Red
   Write-Host 'A contest registered by its id has no ContestType member; this turns it into' -ForegroundColor Red
   Write-Host '"no contest" (issue #96). Keep the object or HandleOf it; ask' -ForegroundColor Red
   Write-Host 'uTestRegisteredContests.IsLegacyContest or TryLegacyContestOf.' -ForegroundColor Red
   exit 1
}
Write-Host 'Lint-RegistryWalks: no test derives a legacy member from a contest object.'
exit 0
