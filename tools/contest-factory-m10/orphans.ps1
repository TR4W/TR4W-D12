param([string]$Unit, [int]$From, [int]$To)
Import-Module (Join-Path $PSScriptRoot '..\..\tr4w\build\PascalSource.psm1') -Force
$root = ([IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\tr4w')))
$files = Get-TR4WPascalFiles -Root $root
$texts = @{}
foreach ($f in $files) { $texts[$f.FullName] = Get-PascalCodeOnlyText -Path $f.FullName -BlankStrings }
$unitPath = (Resolve-Path $Unit).Path
$lines = $texts[$unitPath] -split "`r`n|`n"
$inside = ($lines[($From-1)..($To-1)] -join "`n")
$ids = [regex]::Matches($inside, '\b[A-Za-z_]\w{3,}\b') | ForEach-Object { $_.Value.ToLower() } | Sort-Object -Unique
# routines declared anywhere in the tree (implementation headers)
$decl = @{}
foreach ($k in $texts.Keys) {
   foreach ($m in [regex]::Matches($texts[$k], '(?im)^\s*(procedure|function)\s+([A-Za-z_]\w*)\s*[\(:;]')) {
      $decl[$m.Groups[2].Value.ToLower()] = $k.Substring($root.Length+1)
   }
}
foreach ($id in $ids) {
   if (-not $decl.ContainsKey($id)) { continue }
   $rx = [regex]::new('(?i)\b' + [regex]::Escape($id) + '\b')
   $outside = 0
   foreach ($k in $texts.Keys) {
      if ($k -eq $unitPath) {
         $before = ($lines[0..($From-2)] -join "`n"); $after = ($lines[$To..($lines.Length-1)] -join "`n")
         $outside += $rx.Matches($before).Count + $rx.Matches($after).Count
      } else { $outside += $rx.Matches($texts[$k]).Count }
   }
   $insideN = $rx.Matches($inside).Count
   "{0,-40} inside={1,3} outside={2,4}  declared in {3}" -f $id, $insideN, $outside, $decl[$id]
}
