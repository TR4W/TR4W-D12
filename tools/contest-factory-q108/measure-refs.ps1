# ContestType member and type-name references per file, by category; writes the CSV list-refs.ps1 reads.
# Q108 S1 (docs/CONTEST_OWNERSHIP_DESIGN.md 8.2u) -- a measurement, not a gate.
# Run from anywhere: powershell -NoProfile -File tools\contest-factory-q108\measure-refs.ps1
param([string] $Repo = '', [string] $Csv = (Join-Path ([IO.Path]::GetTempPath()) 'q108-refs.csv'))
if ($Repo -eq '') { $Repo = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path }
Import-Module (Join-Path $Repo 'tr4w\build\PascalSource.psm1') -Force

$members = Get-PascalEnumMembers -Path (Join-Path $Repo 'tr4w\src\VC.pas') -TypeName 'ContestType'
"ContestType members: $($members.Count)"

$tracked = @{}
foreach ($f in (git -C $Repo ls-files)) { $tracked[(Join-Path $Repo ($f -replace '/', '\')).ToLowerInvariant()] = $true }

$files = Get-TR4WPascalFiles -Root (Join-Path $Repo 'tr4w') | Where-Object { $tracked.ContainsKey($_.FullName.ToLowerInvariant()) }
$rx = [regex] '(?<![\w.$])[A-Za-z_]\w*'
$rows = @()
foreach ($f in $files) {
   $text = Get-PascalCodeOnlyText -Path $f.FullName -BlankStrings
   $n = 0
   $distinct = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
   foreach ($m in $rx.Matches($text)) {
      if ($members.Contains($m.Value)) { $n++; [void]$distinct.Add($m.Value) }
   }
   $typeRefs = ([regex]::Matches($text, '(?i)(?<![\w.])ContestType(?!\w)')).Count
   if ($n -gt 0 -or $typeRefs -gt 0) {
      $rel = $f.FullName.Substring($Repo.Length + 1)
      $cat = 'other-src'
      if ($rel -match '\\test\\') { $cat = 'test' }
      elseif ($rel -match '\\contestFactory\\') { $cat = 'factory' }
      elseif ($rel -match 'VC\.pas$') { $cat = 'VC' }
      $rows += [pscustomobject]@{ Cat = $cat; File = $rel; MemberRefs = $n; Distinct = $distinct.Count; TypeRefs = $typeRefs }
   }
}
''
'== by category =='
$rows | Group-Object Cat | ForEach-Object {
   '{0,-10} files={1,4} memberRefs={2,6} typeRefs={3,5}' -f $_.Name, $_.Count, ($_.Group | Measure-Object MemberRefs -Sum).Sum, ($_.Group | Measure-Object TypeRefs -Sum).Sum
}
''
'== other-src files =='
$rows | Where-Object Cat -eq 'other-src' | Sort-Object MemberRefs -Descending | Format-Table -AutoSize | Out-String -Width 200
'== test files, top 40 by member refs =='
$rows | Where-Object Cat -eq 'test' | Sort-Object MemberRefs -Descending | Select-Object -First 40 | Format-Table -AutoSize | Out-String -Width 200
'== factory files referencing >1 distinct member, or the type =='
$rows | Where-Object { $_.Cat -eq 'factory' -and ($_.Distinct -gt 1 -or $_.TypeRefs -gt 0) } | Sort-Object MemberRefs -Descending | Format-Table -AutoSize | Out-String -Width 200
$rows | Export-Csv -NoTypeInformation $Csv
