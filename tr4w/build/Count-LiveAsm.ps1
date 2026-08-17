# Counts LIVE inline-assembly blocks in TR4W sources.
#
# Why this exists: a raw `grep asm` reports 40 blocks across 23 units, and that
# number is wrong in a way that makes the remaining work look far larger than it
# is. Most of those hits are text sitting inside { } or (* *) comment blocks --
# old implementations left in place rather than deleted. This blanks comments
# first (preserving newlines so line numbers stay usable) and counts only what
# the compiler actually sees.
#
# It also scans .dpr / .dpk / .inc, not just .pas: tr4w.dpr carried one of the
# largest live blocks in the tree and a .pas-only search missed it entirely.
#
#   .\Count-LiveAsm.ps1              # summary per file
#   .\Count-LiveAsm.ps1 -Detail      # plus the first line of each block

param(
   [string] $Root   = (Split-Path -Parent $PSScriptRoot),
   [switch] $Detail
)

# The comment stripper MOVED to build\PascalSource.psm1 (2026-08-17), and the
# one that used to stand here is GONE rather than moved: it was a three-line
# regex that blanked `(?s)\{.*?\}` unconditionally, so a `{` inside a string
# literal opened a comment running to the next `}` and blanked live code with
# it. For a counter whose entire job is "how much inline asm is left" that fails
# OPEN -- it under-reports, and under-reporting reads as progress. The careful
# reader had existed in Lint-PCharAnsi.ps1 the whole time and never propagated
# here, which is the ordinary way a copy goes wrong.
Import-Module (Join-Path $PSScriptRoot 'PascalSource.psm1') -Force

$total = 0
$files = Get-TR4WPascalFiles -Root $Root

foreach ($f in $files) {
   $raw   = [IO.File]::ReadAllText($f.FullName)
   $clean = Get-PascalCodeOnlyText -Path $f.FullName
   $hits  = [regex]::Matches($clean, '(?im)^[ \t]*asm\b')
   if ($hits.Count -eq 0) { continue }

   $total += $hits.Count
   $rel = $f.FullName.Substring($Root.Length).TrimStart('\')
   "{0,3}  {1}" -f $hits.Count, $rel

   if ($Detail) {
      $srcLines = $raw -split "`n"
      foreach ($h in $hits) {
         $line = ($clean.Substring(0, $h.Index) -split "`n").Count
         "       {0,6}: {1}" -f $line, $srcLines[$line - 1].Trim()
      }
   }
}

if ($total -eq 0) {
   "Count-LiveAsm: no live inline assembly."
}
else {
   "Count-LiveAsm: {0} live asm block(s)." -f $total
}
