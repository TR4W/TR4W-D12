# Lint-DomCoverage.ps1
#
# Every US QSO party TR4W defines must have BOTH of its domestic multiplier
# files in the installer.  Fails the build when one is missing.
#
# ---------------------------------------------------------------------------
# WHY THIS EXISTS
# ---------------------------------------------------------------------------
# FCONTEST.PAS picks the .dom file at contest setup like this:
#
#     if FoundMyStateInDomFile then                       // operator IS in-state
#        TempDomesticQTHDataFileName := QSOParties[...].InsideStateDOMFile
#     else                                                // operator is NOT
#        TF.Format(TmpBuf, '%s_cty', QSOParties[...].InsideStateDOMFile)
#
# So one table entry yields TWO filenames -- `<base>.dom` and `<base>_cty.dom`
# -- and only the second is spelled out anywhere.  full.nsi lists dom files by
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
# WHY IT READS VC.pas RATHER THAN A LIST OF ITS OWN
# ---------------------------------------------------------------------------
# The QSOParties table is what the PROGRAM reads.  A second list here would be
# one more thing to keep in lockstep, which is the defect this is meant to
# catch.  Adding a QSO party to VC.pas is what makes this check demand its
# files -- there is nothing else to remember.
#
# Deliberately NOT a check that every file in target\dom is packaged: that
# directory holds superseded files (ubaold.dom), case-duplicates, non-.dom
# debris and at least one junk filename from a botched save.  Which of those
# ship is a curation decision and stays NY4I's.  This checks only the files the
# program will actually go looking for.
#
#   powershell -File tr4w\build\Lint-DomCoverage.ps1
#   powershell -File tr4w\build\Lint-DomCoverage.ps1 -Nsi <path> -VcPas <path>

param(
   [string] $Repo   = (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent),
   [string] $Nsi    = '',
   [string] $VcPas  = '',
   [string] $DomDir = ''
)

if (-not $Nsi)    { $Nsi    = Join-Path $Repo 'tr4w\build\full.nsi' }
if (-not $VcPas)  { $VcPas  = Join-Path $Repo 'tr4w\src\VC.pas' }
if (-not $DomDir) { $DomDir = Join-Path $Repo 'tr4w\target\dom' }

foreach ($p in @($Nsi, $VcPas, $DomDir))
   {
   if (-not (Test-Path $p))
      {
      Write-Host "Lint-DomCoverage: not found -- $p" -ForegroundColor Red
      exit 1
      }
   }

# --- what the program will ask for -----------------------------------------
$vc = Get-Content $VcPas -Raw
$entries = [regex]::Matches($vc, "\(InsideStateDOMFile:'([^']+)';.*?StateName:'([^']+)'\)")

if ($entries.Count -eq 0)
   {
   # Fail loud rather than pass vacuously.  A lint that silently checks nothing
   # is worse than no lint -- it reads as a guarantee.
   Write-Host "Lint-DomCoverage: parsed 0 QSOParties entries from VC.pas -- the table moved or its shape changed." -ForegroundColor Red
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

# --- compare ---------------------------------------------------------------
$problems = New-Object System.Collections.ArrayList
foreach ($e in $entries)
   {
   $base  = $e.Groups[1].Value
   $state = $e.Groups[2].Value

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
   Write-Host "  FCONTEST.PAS uses <base>.dom in-state and <base>_cty.dom out-of-state," -ForegroundColor Yellow
   Write-Host "  so BOTH must be in target\dom and named in full.nsi." -ForegroundColor Yellow
   exit 1
   }

$suffix = if ($wildcard) { ' (dom section is wildcarded; on-disk presence checked)' } else { '' }
Write-Host "Lint-DomCoverage: $($entries.Count) QSO party/parties checked, both dom files present for each$suffix."
exit 0
