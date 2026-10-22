# Every domestic file name a class can load, from the identity pin and the class source; flags any not on disk or not packaged.
# Q108 S1 (docs/CONTEST_OWNERSHIP_DESIGN.md 8.2u) -- a measurement, not a gate.
# Run from anywhere: powershell -NoProfile -File tools\contest-factory-q108\dom-named.ps1
param([string] $Repo = '')
if ($Repo -eq '') { $Repo = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path }
Import-Module (Join-Path $Repo 'tr4w\build\PascalSource.psm1') -Force
$nsi = Join-Path $Repo 'tr4w\build\full.nsi'
. (Join-Path $PSScriptRoot 'NsiDom.ps1')
$pset = Get-NsiDomPackaged -Nsi $nsi -DomDir (Join-Path $Repo 'tr4w\target\dom')
"distinct packaged dom names (wildcards expanded against target\dom): $($pset.Count)"
$disk = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
Get-ChildItem (Join-Path $Repo 'tr4w\target\dom') -File | ForEach-Object { [void]$disk.Add($_.Name) }

# 1. the identity pin's DomesticFile column (GetDomesticFileName of every contest)
$pin = [IO.File]::ReadAllText((Join-Path $Repo 'tr4w\test\unit\uTestContestIdentityPin.pas'))
$names = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
foreach ($m in [regex]::Matches($pin, "DomesticFile: '([^']+)'")) { [void]$names.Add($m.Groups[1].Value) }
"distinct GetDomesticFileName values (identity pin): $($names.Count)"

# 2. in-state names and DescribeSession DomesticFile statements, from the class source, code only
$inState = 0; $described = 0
foreach ($f in Get-ChildItem (Join-Path $Repo 'tr4w\src\contestFactory') -Filter *.pas) {
   $code = Get-PascalCodeOnlyText -Path $f.FullName
   foreach ($m in [regex]::Matches($code, "(?is)GetInStateDomesticFileName\s*:\s*string\s*;\s*begin\s*Result\s*:=\s*'([^']+)'")) { [void]$names.Add($m.Groups[1].Value); $inState++ }
   foreach ($m in [regex]::Matches($code, "(?i)\.DomesticFile\s*:=\s*'([^']*)'")) { if ($m.Groups[1].Value) { [void]$names.Add($m.Groups[1].Value) }; $described++ }
}
"in-state literals: $inState; DescribeSession DomesticFile := literal statements: $described"
"distinct names a class can load: $($names.Count)"
foreach ($n in ($names | Sort-Object)) {
   $file = $n
   if ($file -notmatch '\.dom$') { $file = "$n.dom" }
   $flags = @()
   if (-not $disk.Contains($file)) { $flags += 'NOT ON DISK' }
   if (-not $pset.Contains($file)) { $flags += 'NOT PACKAGED' }
   if ($flags.Count -gt 0) { '  {0,-20} {1}' -f $file, ($flags -join ', ') }
}
# non-literal DomesticFile statements
foreach ($f in Get-ChildItem (Join-Path $Repo 'tr4w\src\contestFactory') -Filter *.pas) {
   $code = Get-PascalCodeOnlyText -Path $f.FullName
   foreach ($m in [regex]::Matches($code, "(?i)\.DomesticFile\s*:=\s*(?!')([^;]+);")) { "  non-literal: $($f.Name): $($m.Groups[1].Value.Trim())" }
}
