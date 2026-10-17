# Is the D7 ContestType a prefix of today's? (design 8.2u, "ContestType members").
# Q108 S1 (docs/CONTEST_OWNERSHIP_DESIGN.md 8.2u) -- a measurement, not a gate.
# Run from anywhere: powershell -NoProfile -File tools\contest-factory-q108\compare-d7-enum.ps1
param([string] $Now = '', [string] $D7 = 'C:\TR4W\tr4w\src\VC.pas')
$Repo = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
if ($Now -eq '') { $Now = Join-Path $Repo 'tr4w\src\VC.pas' }
Import-Module (Join-Path $Repo 'tr4w\build\PascalSource.psm1') -Force
function Get-Ordered([string] $path) {
   $text = Get-PascalCodeOnlyText -Path $path -BlankStrings
   $m = [regex]::Match($text, '(?is)(?<![\w.])ContestType\s*=\s*\((?<body>[^)]*)\)')
   if (-not $m.Success) { throw "no ContestType in $path" }
   $list = @()
   foreach ($item in $m.Groups['body'].Value.Split(',')) {
      $im = [regex]::Match($item, '^\s*([A-Za-z_]\w*)')
      if ($im.Success) { $list += $im.Groups[1].Value }
   }
   return ,$list
}
$a = Get-Ordered $D7
$b = Get-Ordered $Now
"D7 members: $($a.Count); now: $($b.Count)"
$firstDiff = -1
for ($i = 0; $i -lt [Math]::Min($a.Count, $b.Count); $i++) {
   if ($a[$i] -ine $b[$i]) { $firstDiff = $i; break }
}
if ($firstDiff -lt 0) { "the D7 enum is a PREFIX of today's: ordinals 0..$($a.Count - 1) agree" }
else {
   "FIRST DIFFERENCE at ordinal ${firstDiff}: D7 $($a[$firstDiff]) vs now $($b[$firstDiff])"
   $diffs = 0
   for ($i = 0; $i -lt [Math]::Min($a.Count, $b.Count); $i++) { if ($a[$i] -ine $b[$i]) { $diffs++ } }
   "ordinals that differ: $diffs"
}
"today's members after D7's count: " + (($b | Select-Object -Skip $a.Count) -join ', ')
$wfdNow = [Array]::IndexOf(($b | ForEach-Object { $_.ToUpperInvariant() }), 'WINTERFIELDDAY')
$wfdD7 = [Array]::IndexOf(($a | ForEach-Object { $_.ToUpperInvariant() }), 'WINTERFIELDDAY')
$alrsNow = [Array]::IndexOf(($b | ForEach-Object { $_.ToUpperInvariant() }), 'ALRS_UA1DZ_CUP')
"WINTERFIELDDAY: D7 $wfdD7, now $wfdNow; ALRS_UA1DZ_CUP now $alrsNow"
