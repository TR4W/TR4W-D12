# References to contest identifiers (ContestTypeSA, ceContest, ...) by category, code only.
# Q108 S1 (docs/CONTEST_OWNERSHIP_DESIGN.md 8.2u) -- a measurement, not a gate.
# Run from anywhere: powershell -NoProfile -File tools\contest-factory-q108\measure-idents.ps1
param([string] $Repo = '', [string[]] $Idents = @('ContestTypeSA', 'Contest', 'ContestIdentity', 'ActiveContest', 'ContestClassFor', 'RegisterContest', 'ceContest', 'GetContestFromString', 'ContestFromName', 'TryContestFromName'))
if ($Repo -eq '') { $Repo = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path }
Import-Module (Join-Path $Repo 'tr4w\build\PascalSource.psm1') -Force
$tracked = @{}
foreach ($f in (git -C $Repo ls-files)) { $tracked[(Join-Path $Repo ($f -replace '/', '\')).ToLowerInvariant()] = $true }
$files = Get-TR4WPascalFiles -Root (Join-Path $Repo 'tr4w') | Where-Object { $tracked.ContainsKey($_.FullName.ToLowerInvariant()) }
$res = @{}
foreach ($id in $Idents) { $res[$id] = @{} }
foreach ($f in $files) {
   $text = Get-PascalCodeOnlyText -Path $f.FullName -BlankStrings
   $rel = $f.FullName.Substring($Repo.Length + 1)
   $cat = 'other-src'
   if ($rel -match '\\test\\') { $cat = 'test' }
   elseif ($rel -match '\\contestFactory\\') { $cat = 'factory' }
   elseif ($rel -match '\\tr4wserver\\') { $cat = 'server' }
   foreach ($id in $Idents) {
      # bare identifier: not preceded by '.' (a field access) and not part of a longer word
      $n = ([regex]::Matches($text, '(?i)(?<![\w.])' + [regex]::Escape($id) + '(?!\w)')).Count
      if ($n -gt 0) {
         if (-not $res[$id].ContainsKey($cat)) { $res[$id][$cat] = @(0, 0) }
         $res[$id][$cat] = @(($res[$id][$cat][0] + $n), ($res[$id][$cat][1] + 1))
      }
   }
}
foreach ($id in $Idents) {
   $parts = foreach ($k in ($res[$id].Keys | Sort-Object)) { '{0}: {1} refs / {2} files' -f $k, $res[$id][$k][0], $res[$id][$k][1] }
   '{0,-20} {1}' -f $id, ($parts -join ';  ')
}
