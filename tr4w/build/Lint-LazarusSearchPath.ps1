<#
   Lint-LazarusSearchPath -- the IDE project must search where the build searches.

   WHY THIS EXISTS. tr4w.lpi carries its OWN unit search path, in
   OtherUnitFiles, and that is a SECOND COPY of the list Get-SearchPaths.ps1
   owns. CLAUDE.md says the search paths are defined once "for three targets
   that genuinely differ ... They previously existed in three copies and had
   already drifted." The .lpi is a fourth copy, and on 2026-09-03 it drifted
   too: src\domain and src\contestFactory had been added to the build months
   and weeks earlier and never to the project, so a clean build in Lazarus
   failed with

      uNewContest.pas(80,3) Error: Cannot find uLogNaming used by uNewContest

   THE FAILURE MODE IS THE POINT. The PowerShell build is green, every test
   passes, the corpus passes -- and the IDE cannot compile the program at all.
   Nothing connects the two until somebody opens Lazarus, which may be days
   later and is nobody's routine. A developer meeting it has no reason to
   suspect a search path; the error names a unit that plainly exists.

   WHAT IT CHECKS. Every src subdirectory Get-SearchPaths.ps1 adds for the App
   target must appear in the .lpi's OtherUnitFiles. Not the reverse: the .lpi
   legitimately carries IDE-only entries (component packages, the Lazarus
   directory) that the command-line build has no use for.

   HOW IT READS THE AUTHORITATIVE LIST. By parsing the `$paths.Add((Join-Path
   $src '...'))` lines rather than calling Get-Tr4wSearchPaths, which requires
   a resolved toolchain -- a lint that needs FPC present to check a text file
   would be skipped on exactly the machine that has the problem.

   IT FAILS CLOSED. Finding no directories at all means the parse broke, not
   that everything is fine; a guard that reports "0 found" and passes is the
   defect this repo has already been bitten by once.
#>

param(
   [string] $Tr4wDir = (Split-Path $PSScriptRoot -Parent)
)

$ErrorActionPreference = 'Stop'

$searchPathsFile = Join-Path $PSScriptRoot 'Get-SearchPaths.ps1'
$lpiFile         = Join-Path $Tr4wDir 'tr4w.lpi'

foreach ($f in @($searchPathsFile, $lpiFile))
   {
   if (-not (Test-Path $f))
      {
      Write-Host "Lint-LazarusSearchPath: cannot find $f" -ForegroundColor Red
      exit 1
      }
   }

# The authoritative list: every `Join-Path $src '<name>'` in Get-SearchPaths.ps1.
$expected = [System.Collections.Generic.List[string]]::new()
foreach ($line in (Get-Content -LiteralPath $searchPathsFile))
   {
   if ($line -match "Join-Path\s+\`$src\s+'([^']+)'")
      {
      $name = $matches[1] -replace '\\', '/'
      if (-not $expected.Contains($name))
         {
         $expected.Add($name)
         }
      }
   }

# THE FLOOR. No matches means the pattern stopped matching, which is a broken
# lint, not a clean tree.
if ($expected.Count -lt 5)
   {
   Write-Host ("Lint-LazarusSearchPath: only {0} source directories found in " +
               "Get-SearchPaths.ps1 -- the parse is broken, not the project." -f $expected.Count) -ForegroundColor Red
   exit 1
   }

$lpi = Get-Content -LiteralPath $lpiFile -Raw
if ($lpi -notmatch 'OtherUnitFiles Value="([^"]*)"')
   {
   Write-Host "Lint-LazarusSearchPath: tr4w.lpi has no OtherUnitFiles entry." -ForegroundColor Red
   exit 1
   }

$actual = $matches[1] -split ';' | ForEach-Object { ($_ -replace '\\', '/').Trim() }

$missing = @()
foreach ($name in $expected)
   {
   # "src/domain" as the build spells it; the .lpi spells it relative to tr4w\.
   $wanted = "src/$name"
   if ($actual -notcontains $wanted)
      {
      $missing += $wanted
      }
   }

if ($missing.Count -gt 0)
   {
   Write-Host ""
   Write-Host "Lint-LazarusSearchPath FAILED" -ForegroundColor Red
   Write-Host ""
   Write-Host "  tr4w.lpi's OtherUnitFiles is missing directories the command-line"
   Write-Host "  build searches. Lazarus will fail to find units that FullBuild.ps1"
   Write-Host "  compiles without complaint:"
   Write-Host ""
   foreach ($m in $missing)
      {
      Write-Host "    $m" -ForegroundColor Yellow
      }
   Write-Host ""
   Write-Host "  Add them to OtherUnitFiles in tr4w.lpi, in the same order as"
   Write-Host "  build\Get-SearchPaths.ps1 lists them."
   Write-Host ""
   exit 1
   }

Write-Host ("Lint-LazarusSearchPath: tr4w.lpi searches all {0} source directories." -f $expected.Count)
exit 0
