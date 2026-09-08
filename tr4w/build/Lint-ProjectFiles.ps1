<#
.SYNOPSIS
   Every file a project file names must exist. Fails the build when one does not.

.DESCRIPTION
   DELETING A UNIT TOUCHES TWO PLACES AND ONLY ONE OF THEM IS COMPILED.

   `tr4w.lpr` lists the units the build compiles, so an orphan there breaks the
   build immediately and gets fixed. `tr4w.lpi` is read by LAZARUS ONLY -- the
   command-line build never opens it -- so an orphan there is invisible to
   FullBuild.ps1, to the lints, to the unit tests and to CI. It surfaces the
   next time someone opens the IDE, as a modal:

       The file "...\src\ui\lcl\uMP3RecorderForm.pas" was not found.
       Ignore will go on loading the project, Abort will stop the loading.

   NY4I hit exactly that on 2026-09-07, once per orphan, and there were
   SEVENTEEN of them -- accumulated over months of deletions by several
   sessions, because nothing had ever checked. Two were from that day's MP3
   recorder removal; the other fifteen were older and had simply never been
   noticed, since whoever deleted the unit was building from the command line.

   That is the whole argument for this being a lint rather than a fix: the
   feedback arrives for the person who does the deletion, in the build they are
   already running, instead of for whoever opens Lazarus weeks later.

.PARAMETER Fix
   Prune the dead entries from the .lpi and renumber what is left. The .lpr is
   NEVER touched automatically -- an orphan there is a compile error with a
   real decision behind it (was the unit meant to be deleted, or is the path
   wrong?), and a script guessing is how a unit gets silently dropped from a
   build.
#>

param(
   [string] $ProjectDir = (Split-Path -Parent $PSScriptRoot),
   [switch] $Fix
)

$ErrorActionPreference = 'Stop'

$lpi = Join-Path $ProjectDir 'tr4w.lpi'
$problems = 0

# ---------------------------------------------------------------- the .lpr(s)
# Reported, never fixed. See the -Fix note above.
$programFiles = @(
   Join-Path $ProjectDir 'tr4w.lpr'
   Join-Path $ProjectDir 'tr4wserver\tr4wserver.lpr'
   Join-Path $ProjectDir 'test\unit\tr4w_unit_tests.lpr'
)

foreach ($lpr in $programFiles) {
   if (-not (Test-Path $lpr)) { continue }

   $dir  = Split-Path -Parent $lpr
   $text = [System.IO.File]::ReadAllText($lpr)

   # `uFoo in 'src\uFoo.pas',` -- the path is what matters, not the unit name.
   foreach ($m in [regex]::Matches($text, "in\s+'([^']+\.(?:pas|lpr|inc))'")) {
      $rel  = $m.Groups[1].Value
      $full = Join-Path $dir $rel
      if (-not (Test-Path $full)) {
         Write-Host ("  MISSING  {0}  ->  {1}" -f (Split-Path -Leaf $lpr), $rel)
         $problems++
      }
   }
}

# ---------------------------------------------------------------------- .lpi
if (Test-Path $lpi) {
   $text = [System.IO.File]::ReadAllText($lpi)

   $unitsMatch = [regex]::Match($text, '(?s)(<Units Count="(\d+)">)(.*?)(</Units>)')
   if (-not $unitsMatch.Success) {
      Write-Host '  Lint-ProjectFiles: tr4w.lpi has no <Units> block -- cannot check it.'
      exit 1
   }

   $body   = $unitsMatch.Groups[3].Value
   $blocks = [regex]::Matches($body, '(?s)(\s*)<Unit(\d+)>(.*?)</Unit\2>')

   if ($blocks.Count -eq 0) {
      Write-Host '  Lint-ProjectFiles: tr4w.lpi <Units> block parsed as empty -- refusing to touch it.'
      exit 1
   }

   $keep = New-Object System.Collections.ArrayList
   $dead = New-Object System.Collections.ArrayList

   foreach ($b in $blocks) {
      $inner = $b.Groups[3].Value
      $fn    = [regex]::Match($inner, '<Filename Value="([^"]+)"/>')
      if (-not $fn.Success) {
         # No filename at all: keep it rather than guess.
         [void]$keep.Add($b)
         continue
      }

      $rel  = $fn.Groups[1].Value
      $full = Join-Path $ProjectDir ($rel -replace '/', '\')
      if (Test-Path $full) {
         [void]$keep.Add($b)
      } else {
         [void]$dead.Add($rel)
      }
   }

   foreach ($d in $dead) {
      Write-Host ("  MISSING  tr4w.lpi  ->  {0}" -f $d)
   }

   if ($dead.Count -gt 0) {
      if ($Fix) {
         $sb = New-Object System.Text.StringBuilder
         for ($i = 0; $i -lt $keep.Count; $i++) {
            $b = $keep[$i]
            # Renumber: the tag index must match the entry's position, and the
            # opening and closing tags must agree or Lazarus rejects the file.
            [void]$sb.Append($b.Groups[1].Value)
            [void]$sb.Append("<Unit$i>")
            [void]$sb.Append($b.Groups[3].Value)
            [void]$sb.Append("</Unit$i>")
         }
         # Whatever trailed the last block (the newline + indent before </Units>).
         $lastEnd = $blocks[$blocks.Count - 1].Index + $blocks[$blocks.Count - 1].Length
         [void]$sb.Append($body.Substring($lastEnd))

         $newUnits = ('<Units Count="{0}">' -f $keep.Count) + $sb.ToString() + '</Units>'
         $text = $text.Remove($unitsMatch.Index, $unitsMatch.Length).Insert($unitsMatch.Index, $newUnits)

         [System.IO.File]::WriteAllText($lpi, $text)
         Write-Host ("  Lint-ProjectFiles: pruned {0} dead entr(ies); {1} unit(s) remain, renumbered." -f $dead.Count, $keep.Count)
      } else {
         $problems += $dead.Count
      }
   }
}

if ($problems -gt 0) {
   Write-Host ''
   Write-Host "Lint-ProjectFiles FAILED: $problems project-file entr(ies) name a file that does not exist."
   Write-Host '  An orphan in tr4w.lpi is INVISIBLE to the command-line build and shows up as a'
   Write-Host '  modal dialog the next time someone opens Lazarus, once per orphan.'
   Write-Host '  Prune them with:  .\build\Lint-ProjectFiles.ps1 -Fix'
   Write-Host '  An orphan in a .lpr is NOT auto-fixed: decide whether the unit should be'
   Write-Host '  deleted from the build or the path corrected, then edit it by hand.'
   exit 1
}

Write-Host '    Lint-ProjectFiles: every path in tr4w.lpi and the .lpr files exists.'
exit 0
