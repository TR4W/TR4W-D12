<#
.SYNOPSIS
   Fail the build if the ContestType enum's ORDERED member list changes --
   a member added, removed, reordered or renamed.

.DESCRIPTION
   THE ENUM IS FROZEN (Q108 S3, 2026-10-17; docs/CONTEST_OWNERSHIP_DESIGN.md
   8.2u). A ContestType member's POSITION is a persisted number: the byte in
   every binary .TRW record, every multi-op packet, the server's own log and
   the log-compare packet, and a contest's handle in memory is that number
   (VC.TContestHandle). An insertion renumbers every contest after it in every
   file ever written; even an append now collides with the handles the
   registry gives contests that register by id, which start one above the
   last member.

   SO A NEW CONTEST HAS NO MEMBER. It registers by its string id --
   uContestRegistry.RegisterContestById, docs/ADDING_A_CONTEST.md -- and this
   lint is what makes that the only way.

   WHAT IS COMPARED: the members read from VC.pas the way the compiler sees
   them (PascalSource.psm1: comments and strings stripped), in declaration
   order, upper-cased (Pascal is case-insensitive, so a case-only respelling
   changes nothing), joined by LF, hashed with SHA-256, against the hash and
   the count written below. A hash rather than the list, so this script is not
   a second copy of the enum; the first and last members are written too, so
   a failure can say which end moved.

   ContestTypeSA, the members' stored spellings, is frozen in LENGTH by the
   compiler (array[ContestType]); a legacy contest may still be RENAMED there
   under ADDING_A_CONTEST.md Step 3c's alias rule, which this lint does not
   see and does not forbid.

   FAILS CLOSED: VC.pas missing, the enum not found, or the fixture failing is
   a failure, never a quiet pass. The fixture proves an append, a removal, a
   swap and a rename each change the hash, a case-only respelling and a
   comment inside the declaration do not, and the parse keeps the order.

.EXAMPLE
   .\Lint-FrozenContestNumbers.ps1
   .\Lint-FrozenContestNumbers.ps1 -SelfTest
#>

param(
   [string] $SourceDir = (Join-Path (Split-Path $PSScriptRoot -Parent) 'src'),
   [switch] $SelfTest
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'PascalSource.psm1') -Force

# --------------------------------------------------------------------------
# THE FROZEN LIST -- measured 2026-10-17 at a5afe844 (Q108 S3). NEVER EDIT
# THESE to clear a failure: a failure means a persisted number moved.
# --------------------------------------------------------------------------
$FROZEN_COUNT  = 188
$FROZEN_FIRST  = 'DUMMYCONTEST'
$FROZEN_LAST   = 'NEBRASKAQSO'
$FROZEN_SHA256 = '9579451bebcdfbfacdcd704b748bda149e2aea1c4b290e82c7e07394159b5be7'

function Get-MemberListHash
{
   param([string[]] $Members)

   $text  = (($Members | ForEach-Object { $_.ToUpperInvariant() }) -join "`n")
   $sha   = [System.Security.Cryptography.SHA256]::Create()
   try
   {
      $bytes = $sha.ComputeHash([System.Text.Encoding]::ASCII.GetBytes($text))
   }
   finally
   {
      $sha.Dispose()
   }
   return (($bytes | ForEach-Object { $_.ToString('x2') }) -join '')
}

# --------------------------------------------------------------------------
# THE FIXTURE -- the parse and the hash, before any tree answer is believed.
# --------------------------------------------------------------------------
function Invoke-FixtureCheck
{
   $bad = 0

   $fixture = @(
      'unit F;'
      'interface'
      'type'
      '   TFixtureContest = ('
      '      FIRSTONE,'
      '      // SLASHED,'
      '      SECONDONE, (* STARRED, *)'
      '      { BRACED, }'
      '      ThirdOne'
      '      );'
      'implementation'
      'end.'
   )
   $tmp = Join-Path ([IO.Path]::GetTempPath()) ('frozencontests_' + [Guid]::NewGuid().ToString('N') + '.pas')
   try
   {
      [IO.File]::WriteAllText($tmp, ($fixture -join "`r`n"))
      $got = Get-PascalEnumMemberList -Path $tmp -TypeName 'TFixtureContest'
   }
   finally
   {
      if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Force }
   }
   if (($got -join ',') -ne 'FIRSTONE,SECONDONE,ThirdOne')
   {
      $bad++
      Write-Host ('FIXTURE FAIL: the parse read [{0}], expected [FIRSTONE,SECONDONE,ThirdOne] in order' -f ($got -join ',')) -ForegroundColor Red
   }

   $base = @('A', 'B', 'C')
   $h = Get-MemberListHash -Members $base
   $mustDiffer = [ordered]@{
      'an append'  = @('A', 'B', 'C', 'D')
      'a removal'  = @('A', 'C')
      'a swap'     = @('A', 'C', 'B')
      'a rename'   = @('A', 'BB', 'C')
      'an insert'  = @('A', 'X', 'B', 'C')
   }
   foreach ($k in $mustDiffer.Keys)
   {
      if ((Get-MemberListHash -Members $mustDiffer[$k]) -eq $h)
      {
         $bad++
         Write-Host ('FIXTURE FAIL: {0} did not change the hash' -f $k) -ForegroundColor Red
      }
   }
   if ((Get-MemberListHash -Members @('a', 'b', 'C')) -ne $h)
   {
      $bad++
      Write-Host 'FIXTURE FAIL: a case-only respelling changed the hash' -ForegroundColor Red
   }

   if ($SelfTest -and $bad -eq 0)
   {
      Write-Host 'FIXTURE ok   the parse keeps order and skips comments; append, removal, swap, rename and insert all change the hash; case does not'
   }

   $bad += Invoke-PascalSourceSelfTest
   return $bad
}

$fixtureFailures = Invoke-FixtureCheck
if ($fixtureFailures -ne 0)
{
   Write-Host 'Lint-FrozenContestNumbers: the fixture failed -- the check cannot be trusted, which is not a pass.' -ForegroundColor Red
   exit 1
}
if ($SelfTest)
{
   exit 0
}

# --------------------------------------------------------------------------
# THE TREE
# --------------------------------------------------------------------------
$vc = Join-Path $SourceDir 'VC.pas'
if (-not (Test-Path -LiteralPath $vc))
{
   Write-Host "Lint-FrozenContestNumbers: VC.pas not found at $vc -- that is a failure, not a pass." -ForegroundColor Red
   exit 1
}
$members = Get-PascalEnumMemberList -Path $vc -TypeName 'ContestType'
if ($members.Count -eq 0)
{
   Write-Host 'Lint-FrozenContestNumbers: no ContestType declaration read from VC.pas -- a broken read, not a pass.' -ForegroundColor Red
   exit 1
}

$hash = Get-MemberListHash -Members $members
$first = $members[0]
$last = $members[$members.Count - 1]

if (($members.Count -eq $FROZEN_COUNT) -and ($hash -eq $FROZEN_SHA256))
{
   Write-Host ('Lint-FrozenContestNumbers: ContestType is the frozen list -- {0} members, {1} .. {2}.' -f $members.Count, $first, $last)
   exit 0
}

Write-Host ''
Write-Host 'Lint-FrozenContestNumbers FAILED -- the ContestType enum is not the frozen list.' -ForegroundColor Red
Write-Host ('   frozen : {0} members, {1} .. {2}, sha256 {3}' -f $FROZEN_COUNT, $FROZEN_FIRST, $FROZEN_LAST, $FROZEN_SHA256) -ForegroundColor Red
Write-Host ('   now    : {0} members, {1} .. {2}, sha256 {3}' -f $members.Count, $first, $last, $hash) -ForegroundColor Red
Write-Host '   A member''s position is a persisted contest number (a .TRW record, a multi-op' -ForegroundColor Red
Write-Host '   packet, the server''s log), and every contest after an inserted or removed' -ForegroundColor Red
Write-Host '   member would change number. A NEW CONTEST HAS NO MEMBER: register it by its' -ForegroundColor Red
Write-Host '   id with RegisterContestById -- docs/ADDING_A_CONTEST.md. Do not edit the hash.' -ForegroundColor Red
Write-Host '   (git diff tr4w/src/VC.pas shows what moved.)' -ForegroundColor Red
exit 1
