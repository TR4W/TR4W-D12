# Counts, code-only (PascalSource.psm1), every method IMPLEMENTATION of the
# given names in src/contestFactory, and prints unit, class.method per hit.
param(
   [string] $Root = (Join-Path $PSScriptRoot '..\..\tr4w'),
   [string[]] $Names = @('UsesBand', 'RunsInMode', 'CreditsBonusMode', 'CreditsWorkedStation', 'MarksDupes')
)
Import-Module (Join-Path $Root 'build\PascalSource.psm1') -Force
$dir = Join-Path $Root 'src\contestFactory'
$files = Get-ChildItem -LiteralPath $dir -Filter '*.pas'
foreach ($n in $Names)
{
   $rx = [regex]::new('(?im)^\s*(function|procedure)\s+(T\w+)\.' + $n + '\b')
   $hits = @()
   foreach ($f in $files)
   {
      $t = Get-PascalCodeOnlyText -Path $f.FullName
      foreach ($m in $rx.Matches($t))
      {
         $hits += ('{0}  {1}' -f $f.Name, $m.Groups[2].Value)
      }
   }
   Write-Output ('== {0}: {1} implementations' -f $n, $hits.Count)
   $hits | ForEach-Object { Write-Output ('   ' + $_) }
}
