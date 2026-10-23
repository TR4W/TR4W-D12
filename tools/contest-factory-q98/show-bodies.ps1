# Prints, code-only, the body of every implementation of a method name in
# src/contestFactory (from its header to the first line that is exactly 'end;').
param(
   [string] $Root = (Join-Path $PSScriptRoot '..\..\tr4w'),
   [string] $Name = 'UsesBand'
)
Import-Module (Join-Path $Root 'build\PascalSource.psm1') -Force
$dir = Join-Path $Root 'src\contestFactory'
$rx = [regex]::new('^\s*(function|procedure)\s+(T\w+)\.' + $Name + '\b', 'IgnoreCase')
foreach ($f in Get-ChildItem -LiteralPath $dir -Filter '*.pas')
{
   $lines = Get-PascalCodeOnlyLines -Path $f.FullName
   for ($i = 0; $i -lt $lines.Count; $i++)
   {
      if ($rx.IsMatch($lines[$i]))
      {
         Write-Output ('---- {0}:{1}' -f $f.Name, ($i + 1))
         $j = $i
         while ($j -lt $lines.Count)
         {
            if ($lines[$j].Trim() -ne '') { Write-Output $lines[$j] }
            if ($lines[$j] -match '^end;') { break }
            $j++
         }
      }
   }
}
