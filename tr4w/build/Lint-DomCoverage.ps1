# Lint-DomCoverage.ps1
#
# Every US QSO party TR4W defines must have BOTH of its domestic multiplier
# files in the installer.  Fails the build when one is missing -- and, since
# #88 round 3 (2026-10-26), when any .dom in target\dom holds an INCLUDE line
# the reader skips (see "an INCLUDE the reader will not follow" below).
#
# ---------------------------------------------------------------------------
# WHY THIS EXISTS
# ---------------------------------------------------------------------------
# fcontest.pas picks the .dom file at contest setup: in state, the party's
# InStateDomesticFileName (`<base>.dom`); out of state, its DomesticFileName,
# the county file (`<base>_cty.dom` -- Test_EveryQSOPartyNamesBothDomesticFiles
# holds the two names together).
#
# So one statement yields TWO filenames -- `<base>.dom` and `<base>_cty.dom`
# -- and only the base is spelled out by the class.  full.nsi lists dom files by
# name, so packaging one and forgetting the other is invisible: the installer
# builds, the file list looks plausible, and the gap only appears when someone
# in that state runs that contest.
#
# It has happened three times.  Measured against real installers:
#
#     tr4w_setup_4_130.4 (Jan 2024)   3 of 19 missing: PA, AZ, MO
#     current build (before this fix) 2 of 19 missing: PA, MO
#
# Arizona was fixed at some point between.  `pa.dom` had NEVER shipped -- it has
# been in target\dom since 2022-10 and in no installer.  Missouri repeated the
# pattern at the moment the contest was added in 2026-03: `missouri_cty.dom`
# went into full.nsi and `missouri.dom` did not.
#
# ---------------------------------------------------------------------------
# WHY IT READS THE CONTEST CLASSES RATHER THAN A LIST OF ITS OWN
# ---------------------------------------------------------------------------
# What the PROGRAM reads is each party class's InStateDomesticFileName -- a
# `function T<Class>.GetInStateDomesticFileName: string;` whose body is one
# `Result := '<base>';`.  A second list here would be one more thing to keep
# in lockstep, which is the defect this is meant to catch.  Writing a party
# class is what makes this check demand its files -- there is nothing else to
# remember.
#
# It read VC.pas's QSOParties table until M10 S8 (2026-10-14) deleted it; the
# classes had stated the same 22 names since S5, and the base reads no table
# since S6.
#
# IT FAILS CLOSED.  No factory directory, no statement found, fewer than
# $MinimumParties statements, or a statement this cannot read as one literal
# (a computed name would be a file this lint cannot check) -- each FAILS,
# never passes quietly.  TContestBase's own `Result := ''` is the one body
# skipped: it is the neutral answer of every contest that is not a party.
#
# Deliberately NOT a check that every file in target\dom is packaged: that
# directory holds superseded files (ubaold.dom), case-duplicates, non-.dom
# debris and at least one junk filename from a botched save.  Which of those
# ship is a curation decision and stays NY4I's.  This checks only the files the
# program will actually go looking for.
#
#   powershell -File tr4w\build\Lint-DomCoverage.ps1
#   powershell -File tr4w\build\Lint-DomCoverage.ps1 -Nsi <path> -FactoryDir <path>

param(
   [string] $Repo       = (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent),
   [string] $Nsi        = '',
   [string] $FactoryDir = '',
   [string] $DomDir     = ''
)

if (-not $Nsi)        { $Nsi        = Join-Path $Repo 'tr4w\build\full.nsi' }
if (-not $FactoryDir) { $FactoryDir = Join-Path $Repo 'tr4w\src\contestFactory' }
if (-not $DomDir)     { $DomDir     = Join-Path $Repo 'tr4w\target\dom' }

# THE FLOOR -- the party classes stating an in-state file at M10 S8
# (2026-10-14): 22.  Lower it only in the commit that deletes a party, naming
# the party; a parse that finds fewer has broken, not shrunk.
$MinimumParties = 22

Import-Module (Join-Path $PSScriptRoot 'PascalSource.psm1') -Force

foreach ($p in @($Nsi, $FactoryDir, $DomDir))
   {
   if (-not (Test-Path $p))
      {
      Write-Host "Lint-DomCoverage: not found -- $p" -ForegroundColor Red
      exit 1
      }
   }

# --- what the program will ask for -----------------------------------------
# Comments are stripped (PascalSource.psm1) and string literals kept, so a
# commented-out override is not counted and the literal is still readable.
$getterRx = [regex]::new(
   'function\s+(?<cls>T\w+)\s*\.\s*GetInStateDomesticFileName\s*:\s*string\s*;(?<body>.*?)\bend\s*;',
   'IgnoreCase, Singleline')
$literalRx = [regex]::new("^\s*begin\s*Result\s*:=\s*'(?<base>[^']*)'\s*;\s*$", 'IgnoreCase')

$entries = New-Object System.Collections.ArrayList
$unreadable = New-Object System.Collections.ArrayList
foreach ($f in Get-ChildItem -Path $FactoryDir -Filter '*.pas' -File)
   {
   $code = Get-PascalCodeOnlyText -Path $f.FullName
   foreach ($m in $getterRx.Matches($code))
      {
      $cls = $m.Groups['cls'].Value
      $lit = $literalRx.Match($m.Groups['body'].Value)
      if ($cls -ieq 'TContestBase')
         {
         # The neutral answer -- see the header.  It must still be the
         # empty literal; anything else is a base that names a file.
         if ((-not $lit.Success) -or ($lit.Groups['base'].Value -ne ''))
            {
            [void]$unreadable.Add("  $($f.Name): TContestBase.GetInStateDomesticFileName is not Result := ''")
            }
         continue
         }
      if ((-not $lit.Success) -or ($lit.Groups['base'].Value -eq ''))
         {
         [void]$unreadable.Add("  $($f.Name): $cls.GetInStateDomesticFileName is not one non-empty literal")
         continue
         }
      [void]$entries.Add([pscustomobject]@{ Base = $lit.Groups['base'].Value; Class = $cls })
      }
   }

if ($unreadable.Count -gt 0)
   {
   Write-Host "Lint-DomCoverage: cannot read every party's in-state file name:" -ForegroundColor Red
   $unreadable | ForEach-Object { Write-Host $_ -ForegroundColor Red }
   Write-Host "  A name this lint cannot read is a file it cannot check -- state it as one literal." -ForegroundColor Yellow
   exit 1
   }

if ($entries.Count -lt $MinimumParties)
   {
   # Fail loud rather than pass vacuously.  A lint that silently checks nothing
   # is worse than no lint -- it reads as a guarantee.
   Write-Host "Lint-DomCoverage: found $($entries.Count) in-state file statement(s) under $FactoryDir, floor $MinimumParties -- the getter moved or its shape changed." -ForegroundColor Red
   exit 1
   }

# --- what the installer packages -------------------------------------------
# Both the explicit `File ..\target\dom\x.dom` form and a wildcard are honoured,
# so this keeps working if the section is ever globbed.
$packaged = New-Object System.Collections.Generic.HashSet[string]
$wildcard = $false
foreach ($line in Get-Content $Nsi)
   {
   $m = [regex]::Match($line, '^\s*File\s+(?:/[^\s]+\s+)*"?(.*?dom[\\/][^"\s]+)"?\s*(?:;.*)?$')
   if (-not $m.Success) { continue }
   $leaf = Split-Path $m.Groups[1].Value -Leaf
   if ($leaf -match '[*?]') { $wildcard = $true; continue }
   [void]$packaged.Add($leaf.ToLowerInvariant())
   }

$onDisk = New-Object System.Collections.Generic.HashSet[string]
foreach ($f in Get-ChildItem -Path $DomDir -File)
   {
   [void]$onDisk.Add($f.Name.ToLowerInvariant())
   }

# --- an INCLUDE the reader will not follow ---------------------------------
# #88 round 3 (2026-10-26).  LogDom follows exactly `INCLUDE FILE <name>`
# (upper case, leading blanks allowed).  Any other line whose first word is
# INCLUDE, in any case, holds no `=` and so is skipped -- nc.dom's
# `INCLUDE S50.DOM` was skipped that way since D7, and no NC entrant could log
# a US state.  The reader now WARNS on such a line (LogDom.
# DomLineIsAnUnfollowedInclude); this fails the build on one, in every file in
# target\dom, because a warning in a log is read only after a contest goes
# wrong.  The same rule as the Pascal predicate: keep the two in step.
$includeProblems = New-Object System.Collections.ArrayList
foreach ($f in Get-ChildItem -Path $DomDir -File -Filter '*.dom')
   {
   $n = 0
   foreach ($line in Get-Content -LiteralPath $f.FullName)
      {
      $n++
      $trimmed = $line.TrimStart(' ', "`t")
      if ($trimmed.StartsWith('INCLUDE FILE', [System.StringComparison]::Ordinal)) { continue }
      $firstWord = ($trimmed -split ' ', 2)[0]
      if ($firstWord -ieq 'INCLUDE')
         {
         [void]$includeProblems.Add("  $($f.Name) line ${n}: '$line' -- only INCLUDE FILE <name> is followed")
         }
      }
   }

if ($includeProblems.Count -gt 0)
   {
   Write-Host ""
   Write-Host "Lint-DomCoverage: $($includeProblems.Count) .dom line(s) name an INCLUDE the reader skips:" -ForegroundColor Red
   $includeProblems | ForEach-Object { Write-Host $_ -ForegroundColor Red }
   Write-Host "  Write it as INCLUDE FILE <name>, upper case, or the file's states/provinces never load." -ForegroundColor Yellow
   exit 1
   }

# --- compare ---------------------------------------------------------------
$problems = New-Object System.Collections.ArrayList
foreach ($e in $entries)
   {
   $base  = $e.Base
   $state = $e.Class

   foreach ($pair in @(@{n = "$base.dom"; k = 'in-state'}, @{n = "$base`_cty.dom"; k = 'out-of-state'}))
      {
      $name = $pair.n.ToLowerInvariant()

      if (-not $onDisk.Contains($name))
         {
         [void]$problems.Add("  $state ($($pair.k)): $($pair.n) -- NOT IN target\dom at all")
         continue
         }
      if ((-not $wildcard) -and (-not $packaged.Contains($name)))
         {
         [void]$problems.Add("  $state ($($pair.k)): $($pair.n) -- in target\dom but NOT packaged by full.nsi")
         }
      }
   }

if ($problems.Count -gt 0)
   {
   Write-Host ""
   Write-Host "Lint-DomCoverage: $($problems.Count) domestic multiplier file(s) a defined QSO party needs are not shipping:" -ForegroundColor Red
   $problems | ForEach-Object { Write-Host $_ -ForegroundColor Red }
   Write-Host ""
   Write-Host "  set-up uses <base>.dom in-state and <base>_cty.dom out-of-state," -ForegroundColor Yellow
   Write-Host "  so BOTH must be in target\dom and named in full.nsi." -ForegroundColor Yellow
   exit 1
   }

$suffix = if ($wildcard) { ' (dom section is wildcarded; on-disk presence checked)' } else { '' }
Write-Host "Lint-DomCoverage: $($entries.Count) QSO party/parties checked, both dom files present for each$suffix."
exit 0
