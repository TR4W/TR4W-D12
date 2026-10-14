<#
.SYNOPSIS
   Fail the build if production code declares a hand-typed table indexed by
   ContestType -- except the tables M10 has not deleted yet, which are named.

.DESCRIPTION
   WHY THIS EXISTS. It is Lint-NoRadioTables one enum over, for the same
   reason. A typed constant `array[ContestType] of ...` with a literal element
   list is a second definition of what a contest is, maintained by hand in enum
   order beside the enum. It can only be the wrong LENGTH, never visibly the
   wrong ORDER, and the radio tables proved what that costs: one row out of
   step, four Kenwoods on the wrong driver, nothing failed.

   The contest factory is the answer: a contest states its own data in its own
   class, and uContestRegistry answers questions about it. M10
   (docs/CONTEST_FACTORY_M10_PLAN.md) deletes the last of the tables; this
   lint stops a new one arriving while that happens.

   THE ALLOW-LIST SHRINKS, AND THE LINT FORCES IT TO. Each entry names the
   stage that removes it. An entry whose table is no longer found FAILS the
   lint as stale -- so the commit that deletes a table must delete its entry,
   and the list cannot quietly outlive what it describes. The same check is
   the lint's floor: today it must find all three, so a parse that finds
   nothing cannot pass.

   WHAT IS FLAGGED: a declaration whose type is `array[...]` indexed by
   ContestType -- `array[ContestType]`, `array[Low(ContestType)..High(...)]`,
   or a range of its members such as `array[CQWWCW..CQWWSSB]` -- or by a
   named type declared that way, AND that carries an initialiser (`= (...)`),
   const or var alike, wrapped across lines or not.

   WHAT IS NOT FLAGGED, and why:

     * a declaration with no initialiser -- uContestRegistry's GRegistry and
       GIdentity are runtime caches, filled by code, and cannot drift;
     * an array OF contests indexed by something else (`array[0..3] of
       ContestType`) -- a list, not a table of per-contest data;
     * anything in a comment or a string literal -- the text is read through
       PascalSource.psm1, the way the compiler sees it;
     * test units: the scan is src only. A frozen list is what a pin IS.

   FAILS CLOSED: VC.pas missing, fewer than $MEMBER_FLOOR ContestType members
   read from it, zero files scanned, the built-in fixture failing, or an
   allow-listed table not found -- each is a failure, never a quiet pass.

.EXAMPLE
   .\Lint-NoContestTables.ps1
   .\Lint-NoContestTables.ps1 -SelfTest
   .\Lint-NoContestTables.ps1 -SourceDir ..\src
#>

param(
   [string] $SourceDir = (Join-Path (Split-Path $PSScriptRoot -Parent) 'src'),
   # Run the fixture and the parser's own fixtures, then stop.
   [switch] $SelfTest
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'PascalSource.psm1') -Force
. (Join-Path $PSScriptRoot 'Get-ScanExclusions.ps1')   # Test-Tr4wScannable -- IDE backup dirs are not source

# --------------------------------------------------------------------------
# THE ALLOW-LIST -- the tables M10 has not deleted yet, all in VC.pas. Shrink
# it in the commit that deletes a table; never grow it.
# --------------------------------------------------------------------------
$ALLOWED = [ordered]@{
   # The row per contest. Plan S5 transcribes what classes still inherit,
   # S6 stops the base reading it, S8 deletes it.
   'ContestsArray'        = 'plan S8 deletes it'
   # The flag word per contest (QSO/mult by band/mode, ERMAK, VHF, zone mode,
   # domestic countries, RTC). Same route as ContestsArray.
   'ContestsBooleanArray' = 'plan S8 deletes it'
   # The enum's own spelling. It stays after M10: the base's name getters fall
   # back to it, and it is what a .cfg's CONTEST = line is matched against.
   'ContestTypeSA'        = 'stays after M10 -- the enum''s spelling'
}
$ALLOWED_FILE = 'VC.pas'

# Measured 2026-10-14: 187 members, DUMMYCONTEST included. The floor is the
# one Lint-ContestNameTests uses; a short read is a broken read.
$MEMBER_FLOOR = 130

# --------------------------------------------------------------------------
# THE DETECTION -- over code-only text (comments blanked, strings blanked,
# newlines kept so a line number is still a line number).
# --------------------------------------------------------------------------
function Test-ContestIndex
{
   param([string] $Index, $Members)

   foreach ($tok in [regex]::Matches($Index, '[A-Za-z_]\w*'))
   {
      if ($tok.Value -ieq 'ContestType') { return $true }
      if ($Members.Contains($tok.Value)) { return $true }
   }
   return $false
}

$script:NamedTypeRx = [regex]::new(
   '(?<![\w.])(?<type>[A-Za-z_]\w*)\s*=\s*(?:packed\s+)?array\s*\[(?<idx>[^\]]*)\]',
   'IgnoreCase')
$script:ArrayDeclRx = [regex]::new(
   '(?<![\w.])(?<name>[A-Za-z_]\w*)\s*:\s*(?:packed\s+)?array\s*\[(?<idx>[^\]]*)\]\s*of\b[^;=]*?=',
   'IgnoreCase')
$script:TypedDeclRx = [regex]::new(
   '(?<![\w.])(?<name>[A-Za-z_]\w*)\s*:\s*(?<tref>[A-Za-z_]\w*)\s*=',
   'IgnoreCase')

# The named array types indexed by ContestType, in one file's text.
function Get-ContestIndexedTypeNames
{
   param([string] $Text, $Members)

   $names = @()
   foreach ($m in $script:NamedTypeRx.Matches($Text))
   {
      if (Test-ContestIndex -Index $m.Groups['idx'].Value -Members $Members)
      {
         $names += $m.Groups['type'].Value
      }
   }
   return $names
}

# The initialised declarations in one file's text that are contest tables.
function Find-ContestTables
{
   param([string] $Text, $Members, $TypeNames)

   $hits = @()
   foreach ($m in $script:ArrayDeclRx.Matches($Text))
   {
      if (Test-ContestIndex -Index $m.Groups['idx'].Value -Members $Members)
      {
         $hits += [pscustomobject]@{
            Name = $m.Groups['name'].Value
            Line = 1 + ([regex]::Matches($Text.Substring(0, $m.Index), "`n")).Count
         }
      }
   }
   foreach ($m in $script:TypedDeclRx.Matches($Text))
   {
      if ($TypeNames.Contains($m.Groups['tref'].Value))
      {
         $hits += [pscustomobject]@{
            Name = $m.Groups['name'].Value
            Line = 1 + ([regex]::Matches($Text.Substring(0, $m.Index), "`n")).Count
         }
      }
   }
   return $hits
}

function New-NameSet
{
   # the comma stops PowerShell enumerating an EMPTY set into $null on return
   return ,(New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase))
}

# --------------------------------------------------------------------------
# THE FIXTURE. Every shape, flagged and not flagged. Run before any tree
# number is believed.
# --------------------------------------------------------------------------
function Invoke-FixtureCheck
{
   param($Members)

   $fixture = @(
      'unit F;'
      'interface'
      'type'
      '   TPerContest = array[ContestType] of integer;'
      '   TSomeContests = array[DUMMYCONTEST..ALLJA] of byte;'
      'const'
      '   Flagged1: array[ContestType] of integer ='
      '      (1, 2);'
      '   Flagged2 : packed array [ ContestType ] of string = (''a'');'
      '   Flagged3: TPerContest = (0);'
      '   Flagged4: TSomeContests = (0);'
      '   Flagged5: array[Low(ContestType)..High(ContestType)] of Word = (0);'
      '   Flagged6: array[CQWWCW..CQWWSSB] of Word = (0, 1);'
      '   Flagged7: array[ContestType] of integer'
      '      = (3);'
      '   ListOfContests: array[0..1] of ContestType = (CQWWCW, CQWWSSB);'
      '   ByBand: array[BandType] of integer = (0);'
      '   // Slashed: array[ContestType] of integer = (0);'
      '   { Braced: array[ContestType] of integer = (0); }'
      '   (* Starred: array[ContestType] of integer = (0); *)'
      '   Quoted = ''Q: array[ContestType] of integer = (0);'';'
      'var'
      '   Cache: array[ContestType] of TObject;'
      '   Wrapped:'
      '      array[ContestType] of integer;'
      '   Typed: TPerContest;'
      'implementation'
      'end.'
   )
   $expected = @('Flagged1', 'Flagged2', 'Flagged3', 'Flagged4', 'Flagged5', 'Flagged6', 'Flagged7')

   $tmp = Join-Path ([IO.Path]::GetTempPath()) ('nocontesttables_' + [Guid]::NewGuid().ToString('N') + '.pas')
   try
   {
      [IO.File]::WriteAllText($tmp, ($fixture -join "`r`n"))
      $text  = Get-PascalCodeOnlyText -Path $tmp -BlankStrings
      $types = New-NameSet
      foreach ($t in (Get-ContestIndexedTypeNames -Text $text -Members $Members)) { [void]$types.Add($t) }
      $got = @(Find-ContestTables -Text $text -Members $Members -TypeNames $types | ForEach-Object { $_.Name } | Sort-Object)
   }
   finally
   {
      if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Force }
   }

   $bad = 0
   if (($got -join ',') -ne (($expected | Sort-Object) -join ','))
   {
      $bad++
      Write-Host 'FIXTURE FAIL' -ForegroundColor Red
      Write-Host ('   expected: {0}' -f ($expected -join ', ')) -ForegroundColor Red
      Write-Host ('   got     : {0}' -f ($got -join ', ')) -ForegroundColor Red
   }
   elseif ($SelfTest)
   {
      Write-Host ('FIXTURE ok   {0} table(s) flagged, every other shape passed' -f $got.Count)
   }

   $bad += Invoke-PascalSourceSelfTest
   return $bad
}

# --------------------------------------------------------------------------
# THE MEMBER LIST, THEN THE FIXTURE, BEFORE ANY TREE NUMBER IS BELIEVED.
# --------------------------------------------------------------------------
if (-not (Test-Path -LiteralPath $SourceDir))
{
   Write-Host "Lint-NoContestTables: source directory not found: $SourceDir -- that is a failure, not a pass." -ForegroundColor Red
   exit 1
}
$srcRoot = (Resolve-Path -LiteralPath $SourceDir).Path.TrimEnd('\')

$vc = Join-Path $srcRoot $ALLOWED_FILE
if (-not (Test-Path -LiteralPath $vc))
{
   Write-Host "Lint-NoContestTables: $ALLOWED_FILE not found at $vc -- cannot read the ContestType enum." -ForegroundColor Red
   exit 1
}
$members = Get-PascalEnumMembers -Path $vc -TypeName 'ContestType'
if ($members.Count -lt $MEMBER_FLOOR)
{
   $msg = 'Lint-NoContestTables FAILED -- read only {0} ContestType members from {1} (floor {2}). ' -f $members.Count, $ALLOWED_FILE, $MEMBER_FLOOR
   Write-Host ($msg + 'A short member set misses ranged tables; that is a broken read, not a clean tree.') -ForegroundColor Red
   exit 1
}

$fixtureFailures = Invoke-FixtureCheck -Members $members
if ($fixtureFailures -ne 0)
{
   Write-Host 'Lint-NoContestTables: the fixture failed -- the parse cannot be trusted, which is not a pass.' -ForegroundColor Red
   exit 1
}
if ($SelfTest)
{
   Write-Host ('{0} ContestType members read.' -f $members.Count)
   exit 0
}

# --------------------------------------------------------------------------
# THE TREE. Two passes: named types may be declared in one unit and used in
# another.
# --------------------------------------------------------------------------
$files = @(Get-TR4WPascalFiles -Root $srcRoot |
           Where-Object { (Test-Tr4wScannable $_.FullName) -and $_.FullName -notmatch '\\graphify-out\\' })
if ($files.Count -eq 0)
{
   Write-Host "Lint-NoContestTables: scanned ZERO files under $srcRoot -- that is a broken lint, not a pass." -ForegroundColor Red
   exit 1
}

$texts = @{}
$types = New-NameSet
foreach ($f in $files)
{
   $text = Get-PascalCodeOnlyText -Path $f.FullName -BlankStrings
   $texts[$f.FullName] = $text
   foreach ($t in (Get-ContestIndexedTypeNames -Text $text -Members $members)) { [void]$types.Add($t) }
}

$violations = @()
$allowedSeen = New-NameSet
foreach ($f in $files)
{
   $rel = $f.FullName.Substring($srcRoot.Length).TrimStart('\')
   foreach ($hit in (Find-ContestTables -Text $texts[$f.FullName] -Members $members -TypeNames $types))
   {
      if (($rel -ieq $ALLOWED_FILE) -and $ALLOWED.Contains($hit.Name))
      {
         [void]$allowedSeen.Add($hit.Name)
         continue
      }
      $violations += [pscustomobject]@{ File = $rel; Line = $hit.Line; Name = $hit.Name }
   }
}

$stale = @($ALLOWED.Keys | Where-Object { -not $allowedSeen.Contains($_) })

Write-Host ('Lint-NoContestTables: {0} file(s) scanned, {1} ContestType members, {2} of {3} allow-listed table(s) found.' -f
            $files.Count, $members.Count, $allowedSeen.Count, $ALLOWED.Count)
foreach ($k in $ALLOWED.Keys)
{
   Write-Host ('   allowed  {0}\{1} -- {2}' -f $ALLOWED_FILE, $k, $ALLOWED[$k])
}

$failed = $false
if ($violations.Count -gt 0)
{
   $failed = $true
   foreach ($v in $violations)
   {
      Write-Host ('  {0}({1}): {2} is a hand-typed table indexed by ContestType' -f $v.File, $v.Line, $v.Name) -ForegroundColor Red
   }
   Write-Host ''
   Write-Host ('Lint-NoContestTables FAILED -- {0} hand-typed table(s) indexed by ContestType.' -f $violations.Count) -ForegroundColor Red
   Write-Host 'A table like this is a second list of the contests, kept in enum order by hand,' -ForegroundColor Red
   Write-Host 'and it cannot report that it has drifted. Put the data on the contest''s class' -ForegroundColor Red
   Write-Host 'and ask uContestRegistry -- see docs/ADDING_A_CONTEST.md.' -ForegroundColor Red
}
if ($stale.Count -gt 0)
{
   $failed = $true
   $msg = 'Lint-NoContestTables FAILED -- allow-listed but not found: {0}. ' -f ($stale -join ', ')
   Write-Host ($msg + 'If the table was deleted, delete its entry in the same commit; if it was not, the parse is broken.') -ForegroundColor Red
}

if ($failed)
{
   exit 1
}
Write-Host 'Lint-NoContestTables: no hand-typed ContestType table outside the allow-list.'
exit 0
