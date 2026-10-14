param(
   [string[]] $Ids,
   [string] $Root = ([IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\tr4w'))),
   [switch] $Lines
)
Import-Module (Join-Path $PSScriptRoot '..\..\tr4w\build\PascalSource.psm1') -Force
$files = Get-TR4WPascalFiles -Root $Root
foreach ($id in $Ids) {
   $rx = [regex]::new('(?i)\b' + [regex]::Escape($id) + '\b')
   $wrx = [regex]::new('(?i)\b' + [regex]::Escape($id) + '\b\s*(\[[^\]]*\]\s*)?(\.\w+\s*)?:=')
   $total = 0
   $rows = @()
   foreach ($f in $files) {
      $text = Get-PascalCodeOnlyText -Path $f.FullName -BlankStrings
      if (-not $rx.IsMatch($text)) { continue }
      $ls = $text -split "`r`n|`n"
      $r = 0; $w = 0; $hits = @()
      for ($i = 0; $i -lt $ls.Length; $i++) {
         $n = $rx.Matches($ls[$i]).Count
         if ($n -gt 0) {
            $wn = $wrx.Matches($ls[$i]).Count
            $w += $wn; $r += ($n - $wn)
            $hits += ($i + 1)
         }
      }
      $rel = $f.FullName.Substring($Root.Length + 1)
      $rows += [pscustomobject]@{ File = $rel; Reads = $r; Writes = $w; Lines = ($hits -join ',') }
      $total += $r + $w
   }
   "== $id  (code-only occurrences: $total)"
   foreach ($row in ($rows | Sort-Object File)) {
      if ($Lines) {
         "   {0}  r={1} w={2}  @ {3}" -f $row.File, $row.Reads, $row.Writes, $row.Lines
      } else {
         "   {0}  r={1} w={2}" -f $row.File, $row.Reads, $row.Writes
      }
   }
}
