<#
.SYNOPSIS
   Pascal source files must have a LOWERCASE EXTENSION.

.DESCRIPTION
   THIS REPLACES A HOOK RULE, AND IT COMES FROM A REAL DEFECT.

   FPC resolves a unit by trying exactly three spellings of the file name:

       uses uCTYDAT  ->  uCTYDAT.pas      the name as written + lowercase ext
                         uctydat.pas      all lowercase
                         UCTYDAT.PAS      all uppercase, uppercase extension

   It matches those against a directory listing ITSELF rather than asking the
   operating system, so it behaves CASE-SENSITIVELY even where the filesystem
   does not. Measured 2026-09-07 on macOS -- a case-INSENSITIVE volume, where
   `uCTYDAT.PAS` was still invisible to `uses uCTYDAT` -- and again on native
   Linux, where it is invisible for the ordinary reason too.

   A MIXEDCASE BASE NAME IS FINE. `uCallSignRoutines.pas` resolves through the
   first spelling, because a uses clause names it identically. What resolves
   through NONE of the three is a mixed-case base with an UPPERCASE extension:
   `uCTYDAT.PAS`, and the 24 others this tree carried until today.

   CHECKING THE BASE NAME WOULD DEMAND RENAMING ~950 FILES, including the whole
   vendored Indy tree, to fix a problem none of them have. So this does not do
   that -- but there IS a second question that needs no renames at all, and
   until 2026-09-08 nothing asked it:

       DOES THE SPELLING IN THE USES CLAUSE RESOLVE TO THE FILE?

   `uses LogWind` finds logwind.pas through the lowercase attempt and is
   harmless. `uses uCallSigns` finds NOTHING, because the file is
   uCallsigns.pas and that matches none of the three. Same rule, different
   half of it, and the fix is one respelling rather than a rename.

   FOUND ON THE FIRST NATIVE LINUX COMPILE THIS TREE HAS EVER HAD. 618 uses
   spellings differ from their file's; only NINE could not resolve, and they
   had been invisible for as long as the only target was Windows.

   THE DIAGNOSTIC NAMES THE WRONG FILE, which is why this lint is worth more
   than the compiler that found it. FPC reported

       logwind.pas(33,3) Fatal: Can't find unit uCallSigns used by LogWind

   and logwind.pas line 33 says `uCallsigns` -- correctly. FPC registers the
   first spelling it meets and complains at the next unit to ask, so the file
   in the error is not the file to fix. This lint names the actual one.

   IT ONLY BITES WHEN THE UNIT IS A DEPENDENCY. Passed as the main file on the
   command line the name is used verbatim, which is why `uCTYDAT.PAS` compiled
   on its own and failed the moment uCallSignRoutines asked for it by name.

   AND THE WINDOWS-HOSTED LINUX CROSS-COMPILE CANNOT SEE IT. That compiler runs
   on Windows and inherits case-insensitive file lookup, so Lint-LinuxCompile
   passes either way. It took a NATIVE Unix host to surface -- which is what
   this lint now stands in for on the Windows build.

   WHAT REPLACED WHAT: .claude/hooks/enforce-pascal-glob.py used to BLOCK
   case-sensitive globs like --include=*.pas, because they silently skipped the
   25 uppercase files and had already produced one false "dead code" verdict.
   With those files renamed the glob rule protects nothing, so it is gone --
   but nothing stopped the next uppercase file being added. This is that half,
   and unlike a hook it fails the build.
#>

param(
   [string] $SourceDir = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = 'Stop'

$repo = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)

# Extensions FPC (or the LCL streamer) resolves by NAME rather than by a path
# written out in full.
$exts = @('.pas', '.pp', '.inc', '.lpr', '.lfm')

$bad = @()
$checked = 0

Get-ChildItem -Path $SourceDir -Recurse -File -ErrorAction SilentlyContinue |
   Where-Object {
      $exts -contains $_.Extension.ToLower() -and
      $_.FullName -notmatch '\\(backup|graphify-out|dcu-cache|build-out|lib)\\'
   } |
   ForEach-Object {
      $checked++
      if ($_.Extension -cne $_.Extension.ToLower()) {
         $bad += $_.FullName.Replace($repo + '\', '')
      }
   }

if ($bad.Count -gt 0) {
   Write-Host "Lint-UnitFileNames FAILED -- $($bad.Count) file(s) have an uppercase extension" -ForegroundColor Red
   Write-Host "  FPC tries <AsWritten>.pas, <lowercase>.pas and <UPPERCASE>.PAS -- and"
   Write-Host "  matches them itself, so it is case-sensitive even on a case-insensitive"
   Write-Host "  volume. A mixed-case base with an UPPERCASE extension matches none of"
   Write-Host "  the three, and the unit becomes invisible to every uses clause that names it."
   Write-Host "  Rename it (two steps on Windows, which is case-insensitive):"
   Write-Host "     git mv X.PAS X.pas.tmp  &&  git mv X.pas.tmp X.pas"
   foreach ($b in $bad | Sort-Object) { Write-Host "    $b" }
   exit 1
}

# =============================================================================
# CHECK 2: every uses-clause spelling must resolve to a real file.
# =============================================================================

Import-Module (Join-Path $PSScriptRoot 'PascalSource.psm1') -Force

# WHAT A NAME COULD RESOLVE TO. Built from the directories FPC is actually
# given by Get-SearchPaths -- src and everything under it, the vendored Indy
# tree, and test. A name that matches NOTHING here is an RTL, LCL or FCL unit
# and is none of this lint's business.
$byLower = @{}
foreach ($root in @((Join-Path $SourceDir 'src'),
                    (Join-Path $SourceDir 'include'),
                    (Join-Path $SourceDir 'test'))) {
   if (-not (Test-Path -LiteralPath $root)) { continue }
   Get-ChildItem -LiteralPath $root -Recurse -File -ErrorAction SilentlyContinue |
      Where-Object { @('.pas', '.pp') -contains $_.Extension.ToLowerInvariant() -and
                     $_.FullName -notmatch '\\(backup|graphify-out|build-out|lib)\\' } |
      ForEach-Object {
         $stem = [IO.Path]::GetFileNameWithoutExtension($_.Name)
         $key  = $stem.ToLowerInvariant()
         if (-not $byLower.ContainsKey($key)) { $byLower[$key] = @() }
         if ($byLower[$key] -cnotcontains $stem) { $byLower[$key] += $stem }
      }
}

# COMMENTS AND STRINGS BLANKED FIRST, through the shared reader -- a `uses`
# inside a commented-out block is not a uses clause, and this tree has many.
$usesRe = [regex] '(?is)(^|\s)uses\b(.*?);'
$wordRe = [regex] '[A-Za-z_][A-Za-z_0-9]*'

$unresolved = @()
$refs = 0
$scanned = 0

foreach ($f in (Get-TR4WPascalFiles -Root (Join-Path $SourceDir 'src'))) {
   if (@('.pas', '.lpr', '.dpr') -notcontains $f.Extension.ToLowerInvariant()) { continue }
   $scanned++
   $code = Get-PascalCodeOnlyText -Path $f.FullName
   foreach ($m in $usesRe.Matches($code)) {
      foreach ($w in $wordRe.Matches($m.Groups[2].Value)) {
         $name = $w.Value
         $key  = $name.ToLowerInvariant()
         if (-not $byLower.ContainsKey($key)) { continue }   # not one of ours
         $refs++
         # FPC's three attempts, and no others.
         $tries = @($name, $name.ToLowerInvariant(), $name.ToUpperInvariant())
         $hit = $false
         foreach ($actual in $byLower[$key]) {
            if ($tries -ccontains $actual) { $hit = $true; break }
         }
         if (-not $hit) {
            $unresolved += [pscustomobject]@{
               File    = $f.FullName.Replace($repo + '\', '')
               Written = $name
               Actual  = ($byLower[$key] | Sort-Object) -join ', '
            }
         }
      }
   }
}

# A GUARD THAT FINDS NOTHING BECAUSE IT LOOKED NOWHERE MUST NOT PASS.
# If the reader changes, or a directory moves, this check would go silently
# inert -- reporting "all resolve" over an empty set. The floor is well below
# the measured 2,600-odd references and well above zero.
$FLOOR = 500
if ($refs -lt $FLOOR) {
   Write-Host "Lint-UnitFileNames FAILED -- only $refs unit reference(s) seen across $scanned file(s)" -ForegroundColor Red
   Write-Host "  That is below the floor of $FLOOR, so this check looked at almost nothing."
   Write-Host "  Something changed in the file discovery or the uses-clause match -- FIX THAT."
   Write-Host "  Do not lower the floor to go green: a lint that reports 0 found and PASSES"
   Write-Host "  is worse than no lint, because it is believed."
   exit 1
}

if ($unresolved.Count -gt 0) {
   $n = ($unresolved | Select-Object File, Written -Unique).Count
   Write-Host "Lint-UnitFileNames FAILED -- $n uses-clause spelling(s) resolve to NO file" -ForegroundColor Red
   Write-Host "  FPC tries <AsWritten>.pas, <lowercase>.pas and <UPPERCASE>.PAS and nothing"
   Write-Host "  else. These match none of the three, so the unit is invisible on any"
   Write-Host "  case-sensitive host -- Linux, macOS, and FPC's own lookup even on Windows."
   Write-Host "  Respell the reference to match the file; Pascal identifiers are"
   Write-Host "  case-insensitive, so it changes nothing else."
   foreach ($u in ($unresolved | Sort-Object File, Written -Unique)) {
      Write-Host ("    {0,-46} uses {1,-24} file is {2}.pas" -f $u.File, $u.Written, $u.Actual)
   }
   exit 1
}

Write-Host "  Lint-UnitFileNames: $checked Pascal file(s) checked, every extension lowercase;"
Write-Host "    $refs unit reference(s) in $scanned file(s), every spelling resolves."
exit 0
