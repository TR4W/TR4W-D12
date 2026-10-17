# Hand-maintained aggregate counts, count arrays, enum walks and contest set constants in the unit tests.
# Q108 S1 (docs/CONTEST_OWNERSHIP_DESIGN.md 8.2u) -- a measurement, not a gate.
# Run from anywhere: powershell -NoProfile -File tools\contest-factory-q108\measure-counts.ps1
param([string] $Repo = '')
if ($Repo -eq '') { $Repo = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path }
Import-Module (Join-Path $Repo 'tr4w\build\PascalSource.psm1') -Force
$members = Get-PascalEnumMembers -Path (Join-Path $Repo 'tr4w\src\VC.pas') -TypeName 'ContestType'
$files = Get-ChildItem (Join-Path $Repo 'tr4w\test\unit') -Filter 'uTest*.pas'
$rxCheck = [regex] "(?is)CheckEquals\(\s*(?<n>\d+(\s*\*\s*\d+)*)\s*,(?<expr>[^;]*?),\s*'(?<msg>[^']*(''[^']*)*)'"
$rxArr = [regex] '(?is)(?<name>[A-Z_][A-Z_0-9]*)\s*:\s*array\s*\[(?<idx>[^\]]*)\]\s*of\s*integer\s*=\s*\((?<body>[^;]*?)\)\s*;'
$rxLoop = [regex] '(?i)for\s+\w+\s*:=\s*(Low|Succ)\s*\(\s*(ContestType|DUMMYCONTEST|Low\s*\(\s*ContestType\s*\))\s*\)'
$rxSet = [regex] '(?is)(?<name>[A-Z_][A-Z_0-9]*)\s*:\s*(set\s+of\s+ContestType|array\s*\[[^\]]*\]\s*of\s+ContestType|array\s*\[[^\]]*\]\s*of\s+TContestSet)\s*='
$total = 0; $totalArr = 0; $totalLoops = 0; $totalSets = 0
foreach ($f in $files) {
   $code = Get-PascalCodeOnlyText -Path $f.FullName      # comments out, strings kept
   $hits = @()
   foreach ($m in $rxCheck.Matches($code)) {
      $msg = $m.Groups['msg'].Value
      $n = $m.Groups['n'].Value
      $first = [int](($n -split '\*')[0].Trim())
      if ($first -ge 14 -and $msg -match '(?i)contest|part(y|ies)|station|pinned|writing|reading|shown') {
         $line = ($code.Substring(0, $m.Index) -split "`n").Count
         $hits += ('    {0}: CheckEquals({1}, ... ''{2}'')' -f $line, $n, $msg)
      }
   }
   $arrs = @()
   foreach ($m in $rxArr.Matches($code)) {
      if ($m.Groups['name'].Value -match '(?i)COUNT') {
         $line = ($code.Substring(0, $m.Index) -split "`n").Count
         $arrs += ('    {0}: {1}: array[{2}] of integer' -f $line, $m.Groups['name'].Value, $m.Groups['idx'].Value)
      }
   }
   $loops = $rxLoop.Matches($code).Count
   $sets = @()
   foreach ($m in $rxSet.Matches($code)) { $sets += $m.Groups['name'].Value }
   if ($hits.Count -or $arrs.Count -or $loops -or $sets.Count) {
      '{0}: {1} count check(s), {2} count array(s), {3} enum walk(s), {4} contest set/list constant(s)' -f $f.Name, $hits.Count, $arrs.Count, $loops, $sets.Count
      $hits; $arrs
      if ($sets.Count) { '    sets/lists: ' + ($sets -join ', ') }
      $total += $hits.Count; $totalArr += $arrs.Count; $totalLoops += $loops; $totalSets += $sets.Count
   }
}
''
"TOTAL: $total aggregate count checks, $totalArr count arrays, $totalLoops enum walks, $totalSets contest set/list constants"
