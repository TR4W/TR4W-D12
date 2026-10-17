# The lines of one category (from measure-refs.ps1's CSV) that name a ContestType member.
# Q108 S1 (docs/CONTEST_OWNERSHIP_DESIGN.md 8.2u) -- a measurement, not a gate.
# Run from anywhere: powershell -NoProfile -File tools\contest-factory-q108\list-refs.ps1
param([string] $Repo = '', [string] $Cat = "other-src", [switch] $TypeToo, [string] $Csv = (Join-Path ([IO.Path]::GetTempPath()) 'q108-refs.csv'))
if ($Repo -eq '') { $Repo = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path }
Import-Module (Join-Path $Repo 'tr4w\build\PascalSource.psm1') -Force
$members = Get-PascalEnumMembers -Path (Join-Path $Repo 'tr4w\src\VC.pas') -TypeName 'ContestType'
$rx = [regex] '(?<![\w.$])[A-Za-z_]\w*'
foreach ($rel in (Import-Csv $Csv | Where-Object Cat -eq $Cat | ForEach-Object File)) {
   $p = Join-Path $Repo $rel
   $text = Get-PascalCodeOnlyText -Path $p -BlankStrings
   $lines = $text -split "`n"
   $orig = [IO.File]::ReadAllLines($p)
   for ($i = 0; $i -lt $lines.Count; $i++) {
      $hit = $false
      foreach ($m in $rx.Matches($lines[$i])) {
         if ($members.Contains($m.Value)) { $hit = $true }
         if ($TypeToo -and $m.Value -ieq 'ContestType') { $hit = $true }
      }
      if ($hit) { '{0}:{1}: {2}' -f $rel, ($i + 1), $orig[$i].Trim() }
   }
}
