# Lint-ContestNameTests.ps1 -- SHARED CODE MAY NOT ASK "WHICH CONTEST IS THIS".
#
# BEHAVIOUR THAT DEPENDS ON THE CONTEST BELONGS IN THE CONTEST'S CLASS, under
# tr4w/src/contestFactory/. A shared unit that tests the global by name --
#
#     if Contest = FLORIDAQSOPARTY then
#     if Contest in [SPDX, PACC] then
#     case Contest of
#
# -- is a second definition of that contest, living somewhere the contest's own
# file never mentions. Deleting or changing the contest then leaves the branch
# behind, and nothing says so. That is the same shape as a base radio class
# asking which model it is (CLAUDE.md, "Two hard rules").
#
# THIS IS A RATCHET, NOT A BAN. The tree already holds hundreds of these and
# they cannot all move at once. The rule is: no file may gain one, and a file
# that has lost some gets its ceiling lowered so they cannot come back.
#
# ------------------------------------------------------------------------
# WHAT IS COUNTED
# ------------------------------------------------------------------------
#
#   Contest = X          Contest <> X          X = Contest          X <> Contest
#   Contest in [...]                            (one per test, however long the set)
#   case Contest of                             (ONE PER CASE STATEMENT, not per arm)
#
# WHY THE CASE, NOT ITS ARMS. Counting arms means knowing where the case ends,
# and CLAUDE.md records that a line regex reports 188 arms where 91 exist once a
# nested case is involved. So the case is the unit. The limit is stated rather
# than hidden: a NEW ARM added to an existing `case Contest of` is not caught.
# The case itself already carries the debt, and its arms are what a reviewer
# reading the diff will see.
#
# ------------------------------------------------------------------------
# WHAT IS NOT COUNTED, and each is in the fixture
# ------------------------------------------------------------------------
#
#   * DUMMYCONTEST comparisons. `Contest <> DUMMYCONTEST` asks "is a contest
#     loaded at all", not which one -- the sentinel, not a contest's identity.
#   * a comparison against something QUALIFIED or CALLED: `Contest = ce.Contest`,
#     `s^.liContest = Contest`, `Contest = Foo(x)`. Two values being compared,
#     not a value being named.
#   * qualified members and lookalikes: ActiveContest, aContest, ce.ceContest,
#     Contest.Something, ContestsArray[Contest].
#   * assignment, `Contest := X`.
#   * anything in a comment or a string literal -- PascalSource.psm1 strips both
#     and the fixture proves a brace comment BETWEEN the tokens still counts.
#
# SCOPE. tr4w/src, minus src/contestFactory/ (where the test is legitimate),
# and minus every backup / __history path (Get-ScanExclusions.ps1). tr4w/test is
# NOT scanned: a test names the contest it is testing, which is its job.
#
# ------------------------------------------------------------------------
# IT FAILS CLOSED
# ------------------------------------------------------------------------
#
#   * the fixture must pass BEFORE any tree number is believed;
#   * scanning zero files fails;
#   * a total below $TOTAL_FLOOR fails -- that is a broken parser, not progress.
#     The floor is set well below today's count, so honest progress passes.

[CmdletBinding()]
param(
   [string] $SourceDir = '',
   # Print every counted line, so a ceiling can be worked down.
   [switch] $List,
   # Print the baseline table as PowerShell, ready to paste over $CEILINGS.
   [switch] $Emit,
   [switch] $SelfTest
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

Import-Module (Join-Path $PSScriptRoot 'PascalSource.psm1') -Force
. (Join-Path $PSScriptRoot 'Get-ScanExclusions.ps1')   # Test-Tr4wScannable

# --------------------------------------------------------------------------
# THE CEILINGS -- path relative to src, lower case, backslashes.
# Lower one when work lands; NEVER raise one. A file not listed has ceiling 0.
# --------------------------------------------------------------------------
$CEILINGS = @{
   # Measured 2026-09-29: 91 in 12 files (-Emit prints this table).
   'mainunit.pas'          = 12
   'trdos\fcontest.pas'    = 4
   'trdos\logcfg.pas'      = 1
   'trdos\logdupe.pas'     = 5
   'trdos\logedit.pas'     = 14
   'trdos\logstuff.pas'    = 14
   'trdos\logsubs2.pas'    = 4
   'trdos\logwind.pas'     = 1
   'trdos\postunit.pas'    = 15
   'uadifexchange.pas'     = 5
   'ucabrilloexchange.pas' = 11
   'utotal.pas'            = 5
}

# Well below the count at the time of writing, and far above what a parser that
# read nothing would find. See "It fails closed".
$TOTAL_FLOOR = 60

# --------------------------------------------------------------------------
# THE COUNT. Input is CODE-ONLY text (comments and strings already handled).
# --------------------------------------------------------------------------

# The right-hand side of a forward comparison: a bare identifier that is not
# followed by a qualifier, a call or an index. Whether it is DUMMYCONTEST is
# decided in code so the exclusion is visible.
$script:ForwardRx = [regex]::new(
   '(?<![\w.^])Contest\s*(?:=|<>)\s*(?<rhs>[A-Za-z_]\w*)(?![\w.(\[^])',
   'IgnoreCase')

# The reversed form. The LEFT operand must be a bare identifier too, so
# `s^.liContest = Contest` and `GRepository.LogContest <> Contest` -- a field
# compared with the global -- are not contest-name tests.
$script:ReverseRx = [regex]::new(
   '(?<![\w.^])(?<lhs>[A-Za-z_]\w*)\s*(?:=|<>)\s*Contest(?![\w.(\[^]|\s*:=)',
   'IgnoreCase')

$script:InRx = [regex]::new(
   '(?<![\w.^])Contest\s+in\b', 'IgnoreCase')

$script:CaseRx = [regex]::new(
   '(?<![\w.^])case\s+Contest\s+of\b', 'IgnoreCase')

function Get-ContestNameTests
{
   param([Parameter(Mandatory = $true)][string] $Path)

   # -BlankStrings: 'Contest = X' inside a message is not a test.
   $text = Get-PascalCodeOnlyText -Path $Path -BlankStrings
   $hits = New-Object System.Collections.ArrayList

   $add = {
      param($index, $kind)
      $line = 1 + ([regex]::Matches($text.Substring(0, $index), "`n")).Count
      [void]$hits.Add([pscustomobject]@{ Line = $line; Kind = $kind })
   }

   foreach ($m in $script:ForwardRx.Matches($text))
   {
      if ($m.Groups['rhs'].Value -ine 'DUMMYCONTEST') { & $add $m.Index 'compare' }
   }
   foreach ($m in $script:ReverseRx.Matches($text))
   {
      if ($m.Groups['lhs'].Value -ine 'DUMMYCONTEST') { & $add $m.Index 'compare' }
   }
   foreach ($m in $script:InRx.Matches($text))   { & $add $m.Index 'in' }
   foreach ($m in $script:CaseRx.Matches($text)) { & $add $m.Index 'case' }

   return @($hits | Sort-Object Line)
}

# --------------------------------------------------------------------------
# THE FIXTURE. Every shape, counted and excluded. Each line carries its
# expected count in a trailing tag so a failure names the line.
# --------------------------------------------------------------------------
function Invoke-FixtureCheck
{
   # Lines marked <<1 must yield exactly one hit; lines marked <<0 none.
   # The tag is inside a // comment, which the stripper removes.
   $fixture = @(
      'begin'
      '   if Contest = FLORIDAQSOPARTY then x;                  // <<1'
      '   if Contest <> PCC then x;                             // <<1'
      '   if contest=spdx then x;                               // <<1  no spaces, lower case'
      '   if Contest in [SPDX, PACC] then x;                    // <<1'
      '   if not (Contest in [SPDX]) then x;                    // <<1'
      '   if PACC = Contest then x;                             // <<1  reversed'
      '   if PACC <> Contest then x;                            // <<1  reversed'
      '   case Contest of                                       // <<1  the case, not its arms'
      '      SPDX: x;'
      '      PACC: x;'
      '   end;'
      '   if Contest {a brace comment} = {and another} CQWW then x;   // <<1'
      '   if (Contest (* paren comment *) <> CQWW) then x;      // <<1'
      '   if Contest ='
      '      SPDX then x;                                       // <<0  see below: the hit is on the line above'
      '   if Contest <> DUMMYCONTEST then x;                    // <<0  sentinel'
      '   if Contest = DummyContest then x;                     // <<0  sentinel, any case'
      '   if DUMMYCONTEST = Contest then x;                     // <<0  sentinel, reversed'
      '   if Contest = ce.ceContest then x;                     // <<0  qualified operand'
      '   if s^.liContest = Contest then x;                     // <<0  qualified operand'
      '   if GRepository.LogContest <> Contest then x;          // <<0  qualified operand'
      '   if Contest = Foo(x) then x;                           // <<0  call'
      '   if ActiveContest = SPDX then x;                       // <<0  lookalike'
      '   if aContest = SPDX then x;                            // <<0  lookalike'
      '   if ce.ceContest = SPDX then x;                        // <<0  qualified'
      '   if Contest.Name = ''x'' then x;                       // <<0  member'
      '   y := ContestsArray[Contest];                          // <<0  index'
      '   Contest := SPDX;                                      // <<0  assignment'
      '   x := Contest;                                         // <<0  read'
      '   s := ''Contest = SPDX'';                              // <<0  string literal'
      '   // if Contest = SPDX then x;                          <<0  line comment'
      '   (* if Contest in [SPDX] then x; *)                    // <<0'
      '   { case Contest of }                                   // <<0'
      'end;'
   )

   $tmp = Join-Path ([IO.Path]::GetTempPath()) ("contestnames_" + [Guid]::NewGuid().ToString('N') + ".pas")
   [IO.File]::WriteAllText($tmp, ($fixture -join "`r`n"))
   try
   {
      $hits = @(Get-ContestNameTests -Path $tmp)
   }
   finally
   {
      Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
   }

   $bad = 0

   # The two-line case: `Contest =` at the end of a line, the value on the next.
   # It IS a hit (on the first line), so its own marker says so in words; the
   # <<0 on the following line is about THAT line, which has no hit of its own.
   # Expected hits, by 1-based line, are derived from the <<1 tags plus that one.
   $expected = New-Object System.Collections.ArrayList
   for ($i = 0; $i -lt $fixture.Count; $i++)
   {
      if ($fixture[$i] -match '<<1') { [void]$expected.Add($i + 1) }
      if ($fixture[$i] -match '^\s+if Contest =$') { [void]$expected.Add($i + 1) }
   }
   $expected = @($expected | Sort-Object)
   $got      = @($hits | ForEach-Object { $_.Line } | Sort-Object)

   if (($expected -join ',') -ne ($got -join ','))
   {
      $bad++
      Write-Host 'FIXTURE FAIL' -ForegroundColor Red
      Write-Host ('   expected hits on lines: {0}' -f ($expected -join ', '))
      Write-Host ('   got hits on lines     : {0}' -f ($got -join ', '))
      foreach ($n in (Compare-Object $expected $got | ForEach-Object { $_.InputObject } | Sort-Object -Unique))
      {
         Write-Host ('   disagree at line {0}: {1}' -f $n, $fixture[[int]$n - 1].Trim())
      }
   }
   elseif ($SelfTest)
   {
      Write-Host ('FIXTURE ok   {0} hit(s) on lines {1}' -f $got.Count, ($got -join ', '))
   }

   $bad += Invoke-PascalSourceSelfTest
   return $bad
}

# The fixture runs BEFORE any tree number is believed.
$fixtureFailures = Invoke-FixtureCheck
if ($fixtureFailures -ne 0)
{
   Write-Host 'Lint-ContestNameTests: the fixture failed -- the parse cannot be trusted, which is not a pass.' -ForegroundColor Red
   exit 1
}
if ($SelfTest) { exit 0 }

# --------------------------------------------------------------------------
# THE TREE.
# --------------------------------------------------------------------------
if ($SourceDir -eq '') { $SourceDir = Join-Path (Split-Path -Parent $PSScriptRoot) 'src' }
$srcRoot = (Resolve-Path -LiteralPath $SourceDir).Path.TrimEnd('\')

$files = @(Get-ChildItem -LiteralPath $srcRoot -Recurse -File |
           Where-Object { ($_.Extension -ieq '.pas' -or $_.Extension -ieq '.inc') -and
                          (Test-Tr4wScannable $_.FullName) -and
                          $_.FullName -notmatch '\\contestFactory\\' -and
                          $_.FullName -notmatch '\\graphify-out\\' -and
                          $_.Name -notmatch '~' })

if ($files.Count -eq 0)
{
   Write-Host "Lint-ContestNameTests: scanned ZERO files under $srcRoot -- that is a broken lint, not a pass." -ForegroundColor Red
   exit 1
}

$counts = @{}
$lines  = @{}
$total  = 0
foreach ($f in $files)
{
   $rel  = $f.FullName.Substring($srcRoot.Length).TrimStart('\').ToLowerInvariant()
   $hits = @(Get-ContestNameTests -Path $f.FullName)
   if ($hits.Count -gt 0)
   {
      $counts[$rel] = $hits.Count
      $lines[$rel]  = $hits
      $total       += $hits.Count
   }
}

if ($Emit)
{
   foreach ($k in ($counts.Keys | Sort-Object))
   {
      Write-Host ("   '{0}' = {1}" -f $k, $counts[$k])
   }
   Write-Host ("# total {0} in {1} file(s), {2} scanned" -f $total, $counts.Count, $files.Count)
   exit 0
}

if ($List)
{
   foreach ($k in ($counts.Keys | Sort-Object))
   {
      foreach ($h in $lines[$k]) { Write-Host ('{0}:{1}  {2}' -f $k, $h.Line, $h.Kind) }
   }
}

$failed  = $false
$dropped = @()

foreach ($k in ($counts.Keys | Sort-Object))
{
   $ceiling = 0
   if ($CEILINGS.ContainsKey($k)) { $ceiling = $CEILINGS[$k] }
   if ($counts[$k] -gt $ceiling)
   {
      $failed = $true
      $why = if ($CEILINGS.ContainsKey($k)) { "ceiling $ceiling" } else { 'a file with no ceiling' }
      Write-Host ('   {0}: {1} contest-name test(s), {2}' -f $k, $counts[$k], $why) -ForegroundColor Red
      foreach ($h in $lines[$k]) { Write-Host ('      line {0}  {1}' -f $h.Line, $h.Kind) -ForegroundColor Red }
   }
   elseif ($counts[$k] -lt $ceiling)
   {
      $dropped += ('{0}: {1} (ceiling {2})' -f $k, $counts[$k], $ceiling)
   }
}
# A ceilinged file that now has none is progress too, and is not in $counts.
foreach ($k in ($CEILINGS.Keys | Sort-Object))
{
   if (-not $counts.ContainsKey($k) -and $CEILINGS[$k] -gt 0)
   {
      $dropped += ('{0}: 0 (ceiling {1})' -f $k, $CEILINGS[$k])
   }
}

Write-Host ''
Write-Host ('Lint-ContestNameTests: {0} contest-name test(s) in {1} file(s), {2} file(s) scanned, floor {3}.' -f
            $total, $counts.Count, $files.Count, $TOTAL_FLOOR)

if ($total -lt $TOTAL_FLOOR)
{
   Write-Host ("Lint-ContestNameTests FAILED -- only $total found, below the floor of $TOTAL_FLOOR. " +
               'That is a broken parse, not progress. If the tests were genuinely moved, lower the floor with them.') -ForegroundColor Red
   exit 1
}

if ($dropped.Count -gt 0)
{
   Write-Host 'These files are BELOW their ceiling -- lower it so the tests cannot come back:' -ForegroundColor Yellow
   foreach ($d in $dropped) { Write-Host "   $d" -ForegroundColor Yellow }
}

if ($failed)
{
   Write-Host ''
   Write-Host 'Lint-ContestNameTests FAILED -- shared code is testing the contest by name.' -ForegroundColor Red
   Write-Host '  What differs about a contest belongs in its class under src/contestFactory/,' -ForegroundColor Red
   Write-Host '  reached through a virtual, not in a branch here. See docs/ADDING_A_CONTEST.md.' -ForegroundColor Red
   exit 1
}

Write-Host 'Lint-ContestNameTests: no file has gained a contest-name test.' -ForegroundColor Green
exit 0
