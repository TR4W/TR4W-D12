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

   So this checks the EXTENSION only. Checking the base name too would demand
   renaming ~950 files, including the whole vendored Indy tree, to fix a
   problem none of them have.

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

Write-Host "  Lint-UnitFileNames: $checked Pascal file(s) checked, every extension lowercase."
exit 0
