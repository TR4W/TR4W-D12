# target/dom against full.nsi: tracked files, what a dom wildcard adds, debris.
# Q108 S1 (docs/CONTEST_OWNERSHIP_DESIGN.md 8.2u) -- a measurement, not a gate.
# Run from anywhere: powershell -NoProfile -File tools\contest-factory-q108\dom-inventory.ps1
param([string] $Repo = '')
if ($Repo -eq '') { $Repo = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path }
$nsi = Join-Path $Repo 'tr4w\build\full.nsi'
. (Join-Path $PSScriptRoot 'NsiDom.ps1')
$pset = Get-NsiDomPackaged -Nsi $nsi -DomDir (Join-Path $Repo 'tr4w\target\dom')
$packaged = @($pset)
"files packaged from dom\ (wildcards expanded against target\dom): $($packaged.Count)"
$tracked = @(git -C $Repo -c core.quotepath=false ls-files 'tr4w/target/dom')
"tracked files in target/dom: $($tracked.Count)"
$names = $tracked | ForEach-Object { Split-Path $_ -Leaf }
$domGlob = @($names | Where-Object { $_ -like '*.dom' })
"tracked files matching *.dom (case-insensitive): $($domGlob.Count)"
''
'== tracked *.dom NOT packaged today (what a dom\*.dom wildcard would ADD) =='
$domGlob | Where-Object { -not $pset.Contains($_) } | Sort-Object
''
'== packaged but not tracked =='
$tset = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
foreach ($n in $names) { [void]$tset.Add($n) }
$packaged | Where-Object { -not $tset.Contains($_) }
''
'== case-insensitive duplicates among tracked names =='
$names | Group-Object { $_.ToLowerInvariant() } | Where-Object Count -gt 1 | ForEach-Object { ($_.Group -join ' | ') }
''
'== tracked files that are not *.dom =='
$names | Where-Object { $_ -notlike '*.dom' }
