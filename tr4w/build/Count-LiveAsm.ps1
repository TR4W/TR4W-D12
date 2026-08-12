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

function Remove-PascalComments {
   param([string] $Source)
   $s = [regex]::Replace($Source, '(?s)\{.*?\}',     { param($m) ($m.Value -replace '[^\r\n]', ' ') })
   $s = [regex]::Replace($s,      '(?s)\(\*.*?\*\)', { param($m) ($m.Value -replace '[^\r\n]', ' ') })
   $s = [regex]::Replace($s,      '(?m)//[^\r\n]*',  { param($m) ($m.Value -replace '[^\r\n]', ' ') })
   return $s
}

$skipDir  = '\\include\\|\\dcu|dcu-cache|\\target\\|\\backup'
$skipFile = '\.bad$|\.bakup$|\.old$|~'

$total = 0
$files = Get-ChildItem -LiteralPath $Root -Recurse -Include *.pas,*.PAS,*.dpr,*.dpk,*.inc -ErrorAction SilentlyContinue |
   Where-Object { $_.FullName -notmatch $skipDir -and $_.Name -notmatch $skipFile }

foreach ($f in $files) {
   $raw   = [IO.File]::ReadAllText($f.FullName)
   $clean = Remove-PascalComments $raw
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
