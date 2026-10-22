<#
.SYNOPSIS
   Fail the build unless every contest unit is linked where it belongs: a
   factory unit in BOTH tr4w.lpr and the unit-test program, a test fixture in
   the unit-test program ONLY.

.DESCRIPTION
   A CONTEST UNIT THAT IS NOT LINKED IS A CONTEST THAT DOES NOT EXIST, AND
   NOTHING SAYS SO (Q108 S3, 2026-10-17; docs/CONTEST_OWNERSHIP_DESIGN.md
   8.2u). A contest registers itself from its unit's initialization section,
   so the only thing that puts it in a program is the program's uses clause.
   Leave it out of tr4w.lpr and the application simply has no such contest;
   leave it out of the test program and every registry walk passes without
   it. Once contests register by id (RegisterContestById) there is no enum
   member whose absence a test could notice, so this is the guard.

   AND THE OTHER DIRECTION: a contest registered by a unit under tr4w/test --
   the unit tests' by-id fixture -- must never reach the application or the
   server. The contest matrix checks the same of the running application's
   registry; this checks the program files, before anything is built.

   THE RULES, per unit whose INITIALIZATION section calls RegisterContest or
   RegisterContestById (read the way the compiler sees it, PascalSource.psm1):

     tr4w/src/contestFactory/*   in tr4w.lpr AND tr4w_unit_tests.lpr,
                                 and NOT in tr4wserver.lpr
     tr4w/test/**                in tr4w_unit_tests.lpr ONLY
     anywhere else under src     a failure: registrations belong in the factory

   A unit is "in" a program when the program's uses clause names its file
   (`uFoo in '<path>'`, resolved against the program's directory, as
   Lint-ProjectFiles reads it), comments stripped -- a commented-out line
   links nothing.

   FAILS CLOSED: a program file missing, fewer than $FACTORY_FLOOR registering
   factory units found, or the fixture failing is a failure, never a pass.

.EXAMPLE
   .\Lint-ContestUnitsLinked.ps1
   .\Lint-ContestUnitsLinked.ps1 -SelfTest
#>

param(
   # tr4w\ -- the directory holding tr4w.lpr. Run-Lints passes it.
   [string] $SourceDir = (Split-Path $PSScriptRoot -Parent),
   [switch] $SelfTest
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'PascalSource.psm1') -Force
. (Join-Path $PSScriptRoot 'Get-ScanExclusions.ps1')   # Test-Tr4wScannable -- IDE backup dirs are not source

# Measured 2026-10-17: 187 factory units register a contest. Far below it on
# purpose -- no contest added or removed edits this -- and far above zero, so a
# scan that found nothing cannot pass.
$FACTORY_FLOOR = 150

# --------------------------------------------------------------------------
# THE READERS
# --------------------------------------------------------------------------

# Does this code-only text register a contest from its initialization section?
function Test-RegistersAContest
{
   param([string] $CodeOnlyText)

   $m = [regex]::Match($CodeOnlyText, '(?im)^\s*initialization\b')
   if (-not $m.Success) { return $false }
   $tail = $CodeOnlyText.Substring($m.Index)
   return [regex]::IsMatch($tail, '(?i)(?<![\w.])RegisterContest(?:ById)?\s*\(')
}

# The full paths a program file's uses clause links, lower-cased.
function Get-LinkedPaths
{
   param([string] $ProgramFile, [string] $CodeWithStrings)

   $dir = Split-Path -Parent $ProgramFile
   $set = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
   foreach ($m in [regex]::Matches($CodeWithStrings, "(?i)\bin\s+'([^']+\.pas)'"))
   {
      $rel = $m.Groups[1].Value -replace '/', '\'
      [void]$set.Add([IO.Path]::GetFullPath((Join-Path $dir $rel)))
   }
   return ,$set
}

# THE RULES. Each unit is a full path; each program a set of full paths.
# Returns one line per violation.
function Get-LinkageViolations
{
   param($FactoryUnits, $TestUnits, $OtherUnits, $App, $Tests, $Server)

   $out = @()
   foreach ($u in $FactoryUnits)
   {
      if (-not $App.Contains($u))   { $out += ('{0}: a contest unit missing from tr4w.lpr -- the application has no such contest' -f $u) }
      if (-not $Tests.Contains($u)) { $out += ('{0}: a contest unit missing from tr4w_unit_tests.lpr -- no test sees it' -f $u) }
      if ($Server.Contains($u))     { $out += ('{0}: a contest unit in tr4wserver.lpr -- the server links no contest' -f $u) }
   }
   foreach ($u in $TestUnits)
   {
      if (-not $Tests.Contains($u)) { $out += ('{0}: a test fixture contest missing from tr4w_unit_tests.lpr' -f $u) }
      if ($App.Contains($u))        { $out += ('{0}: a TEST FIXTURE contest linked into tr4w.lpr -- it must never reach the application' -f $u) }
      if ($Server.Contains($u))     { $out += ('{0}: a test fixture contest linked into tr4wserver.lpr' -f $u) }
   }
   foreach ($u in $OtherUnits)
   {
      $out += ('{0}: registers a contest outside src\contestFactory -- a contest''s class lives in the factory' -f $u)
   }
   return ,$out
}

function New-PathSet
{
   param([string[]] $Paths)
   $set = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
   foreach ($p in $Paths) { [void]$set.Add($p) }
   return ,$set
}

# --------------------------------------------------------------------------
# THE FIXTURE
# --------------------------------------------------------------------------
function Invoke-FixtureCheck
{
   $bad = 0

   # The initialization reader.
   $cases = @(
      @{ Text = "unit A;`ninterface`nimplementation`ninitialization`n   RegisterContest(XMAS, TContestXmas);`nend."; Want = $true }
      @{ Text = "unit B;`ninitialization`n   RegisterContestById(SOME_ID, TFoo);`nend."; Want = $true }
      @{ Text = "unit C;`nprocedure RegisterContest(aContest: ContestType; aCls: TContestClass);`ninitialization`n   Lock := TCriticalSection.Create;`nend."; Want = $false }
      @{ Text = "unit D;`nimplementation`n   RegisterContest(XMAS, TContestXmas);`nend."; Want = $false }
      @{ Text = "unit E;`ninitialization`n   Registry.RegisterContest(XMAS, TX);`nend."; Want = $false }
   )
   foreach ($c in $cases)
   {
      if ((Test-RegistersAContest -CodeOnlyText $c.Text) -ne $c.Want)
      {
         $bad++
         Write-Host ('FIXTURE FAIL: registration reader answered {0} for: {1}' -f (-not $c.Want), ($c.Text -replace "`n", ' | ')) -ForegroundColor Red
      }
   }

   # The program-file reader: a commented-out line links nothing.
   $tmpDir = Join-Path ([IO.Path]::GetTempPath()) ('unitslinked_' + [Guid]::NewGuid().ToString('N'))
   New-Item -ItemType Directory -Path $tmpDir -Force | Out-Null
   try
   {
      $lpr = Join-Path $tmpDir 'p.lpr'
      [IO.File]::WriteAllText($lpr, (@(
         'program p;'
         'uses'
         "   uOne in 'src\uOne.pas',"
         "   // uTwo in 'src\uTwo.pas',"
         "   (* uThree in 'src\uThree.pas', *)"
         "   uFour in 'src/sub/uFour.pas';"
         'begin'
         'end.') -join "`r`n"))
      $code = Get-PascalCodeOnlyText -Path $lpr
      $linked = Get-LinkedPaths -ProgramFile $lpr -CodeWithStrings $code
      $want = @((Join-Path $tmpDir 'src\uOne.pas'), (Join-Path $tmpDir 'src\sub\uFour.pas'))
      if ($linked.Count -ne 2 -or -not $linked.Contains($want[0]) -or -not $linked.Contains($want[1]))
      {
         $bad++
         Write-Host ('FIXTURE FAIL: the program reader linked [{0}]' -f (@($linked) -join ', ')) -ForegroundColor Red
      }
   }
   finally
   {
      Remove-Item -LiteralPath $tmpDir -Recurse -Force -ErrorAction SilentlyContinue
   }

   # The rules: every violation kind is reported, and a correct tree passes.
   $f1 = 'C:\x\src\contestFactory\uA.pas'; $f2 = 'C:\x\src\contestFactory\uB.pas'
   $t1 = 'C:\x\test\unit\uFix.pas';        $o1 = 'C:\x\src\uStray.pas'
   $good = Get-LinkageViolations -FactoryUnits @($f1) -TestUnits @($t1) -OtherUnits @() `
                                 -App (New-PathSet @($f1)) -Tests (New-PathSet @($f1, $t1)) -Server (New-PathSet @())
   if ($good.Count -ne 0)
   {
      $bad++
      Write-Host ('FIXTURE FAIL: a correct tree reported {0} violation(s)' -f $good.Count) -ForegroundColor Red
   }
   $all = Get-LinkageViolations -FactoryUnits @($f1, $f2) -TestUnits @($t1) -OtherUnits @($o1) `
                                -App (New-PathSet @($f1, $t1)) -Tests (New-PathSet @($f2)) -Server (New-PathSet @($f2))
   # f1 missing from tests; f2 missing from app; f2 in server; t1 missing from
   # tests; t1 in app; o1 stray -- six.
   if ($all.Count -ne 6)
   {
      $bad++
      Write-Host ('FIXTURE FAIL: expected 6 violations, got {0}:' -f $all.Count) -ForegroundColor Red
      $all | ForEach-Object { Write-Host "   $_" -ForegroundColor Red }
   }

   if ($SelfTest -and $bad -eq 0)
   {
      Write-Host 'FIXTURE ok   the registration reader, the program reader (comments link nothing) and all six violation kinds'
   }
   $bad += Invoke-PascalSourceSelfTest
   return $bad
}

$fixtureFailures = Invoke-FixtureCheck
if ($fixtureFailures -ne 0)
{
   Write-Host 'Lint-ContestUnitsLinked: the fixture failed -- the check cannot be trusted, which is not a pass.' -ForegroundColor Red
   exit 1
}
if ($SelfTest)
{
   exit 0
}

# --------------------------------------------------------------------------
# THE TREE
# --------------------------------------------------------------------------
$root = (Resolve-Path -LiteralPath $SourceDir).Path.TrimEnd('\')
$programs = [ordered]@{
   App    = Join-Path $root 'tr4w.lpr'
   Tests  = Join-Path $root 'test\unit\tr4w_unit_tests.lpr'
   Server = Join-Path $root 'tr4wserver\tr4wserver.lpr'
}
$linked = @{}
foreach ($k in $programs.Keys)
{
   if (-not (Test-Path -LiteralPath $programs[$k]))
   {
      Write-Host ('Lint-ContestUnitsLinked: {0} not found -- that is a failure, not a pass.' -f $programs[$k]) -ForegroundColor Red
      exit 1
   }
   $linked[$k] = Get-LinkedPaths -ProgramFile $programs[$k] -CodeWithStrings (Get-PascalCodeOnlyText -Path $programs[$k])
}

$factoryDir = Join-Path $root 'src\contestFactory'
$testDir    = Join-Path $root 'test'
$factory = @(); $tests = @(); $other = @()
foreach ($f in @(Get-TR4WPascalFiles -Root (Join-Path $root 'src')) + @(Get-TR4WPascalFiles -Root $testDir))
{
   if ($f.Extension -ine '.pas') { continue }
   if (-not (Test-Tr4wScannable $f.FullName)) { continue }
   if ($f.FullName -match '\\graphify-out\\') { continue }
   if (-not (Test-RegistersAContest -CodeOnlyText (Get-PascalCodeOnlyText -Path $f.FullName -BlankStrings))) { continue }

   $full = [IO.Path]::GetFullPath($f.FullName)
   if ((Split-Path -Parent $full) -ieq $factoryDir)
   {
      $factory += $full
   }
   elseif ($full.StartsWith($testDir + '\', [StringComparison]::OrdinalIgnoreCase))
   {
      $tests += $full
   }
   else
   {
      $other += $full
   }
}

if ($factory.Count -lt $FACTORY_FLOOR)
{
   Write-Host ('Lint-ContestUnitsLinked FAILED -- found only {0} factory units that register a contest (floor {1}). A broken scan, not a clean tree.' -f $factory.Count, $FACTORY_FLOOR) -ForegroundColor Red
   exit 1
}

$violations = Get-LinkageViolations -FactoryUnits $factory -TestUnits $tests -OtherUnits $other `
                                    -App $linked.App -Tests $linked.Tests -Server $linked.Server

Write-Host ('Lint-ContestUnitsLinked: {0} factory contest unit(s), {1} test fixture contest unit(s), {2} elsewhere.' -f $factory.Count, $tests.Count, $other.Count)
if ($violations.Count -gt 0)
{
   foreach ($v in $violations)
   {
      Write-Host ('  ' + $v.Substring($root.Length).TrimStart('\')) -ForegroundColor Red
   }
   Write-Host ''
   Write-Host ('Lint-ContestUnitsLinked FAILED -- {0} contest unit(s) linked in the wrong place.' -f $violations.Count) -ForegroundColor Red
   Write-Host 'A contest is in a program only if its unit is in that program''s uses clause.' -ForegroundColor Red
   Write-Host 'A factory contest goes in tr4w.lpr AND test\unit\tr4w_unit_tests.lpr; a test' -ForegroundColor Red
   Write-Host 'fixture goes in the test program only -- docs/ADDING_A_CONTEST.md.' -ForegroundColor Red
   exit 1
}
Write-Host 'Lint-ContestUnitsLinked: every contest unit is linked where it belongs.'
exit 0
