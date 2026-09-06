<#
.SYNOPSIS
   Compile one TR4W unit for x86_64-linux, to see what still binds it to Windows.

.DESCRIPTION
   The inner loop for the cross-platform work. It does NOT link and it does NOT
   produce anything shippable -- it answers one question: does this unit, and
   everything it uses, compile for a platform that is not Windows.

   Use it the way a linter is used. Point it at a unit you have just gated and
   read the first error; it names the exact identifier or unit that is still
   Windows-bound, which is a great deal more useful than reading the source and
   guessing.

   See docs/CROSS_COMPILING.md for how the toolchain was built.

.EXAMPLE
   .\tools\Compile-Linux.ps1 VC.pas
   .\tools\Compile-Linux.ps1 utils\uAnsiStr.pas -All
#>
[CmdletBinding()]
param(
   # Unit to compile, relative to tr4w\src (or an absolute path).
   [Parameter(Mandatory = $true, Position = 0)]
   [string] $Unit,

   # Show every error rather than just the first few.
   [switch] $All
)

$ErrorActionPreference = 'Stop'

$repo = Split-Path -Parent $PSScriptRoot
$fpc  = 'C:\fpcupdeluxe\fpcsrc\compiler\ppcrossx64.exe'
$rtl  = 'C:\fpcupdeluxe\fpcsrc\rtl\units\x86_64-linux'
$pkgs = 'C:\fpcupdeluxe\fpcsrc\packages'
$shim = Join-Path $repo 'tools\wsl-binutils'

if (-not (Test-Path $fpc)) {
   throw "No Linux cross compiler at $fpc. See docs/CROSS_COMPILING.md."
}
if (-not (Test-Path (Join-Path $shim 'x86_64-linux-as.exe'))) {
   throw "No binutils shim in $shim. See docs/CROSS_COMPILING.md."
}

$src = if ([System.IO.Path]::IsPathRooted($Unit)) { $Unit }
       else { Join-Path $repo "tr4w\src\$Unit" }
if (-not (Test-Path $src)) { throw "No such unit: $src" }

# Output goes to a scratch dir, never near the Windows build's units.
$out = Join-Path $env:TEMP 'tr4w-linux-units'
New-Item -ItemType Directory -Force -Path $out | Out-Null

$fu = @($rtl)
Get-ChildItem $pkgs -Directory | ForEach-Object {
   $d = Join-Path $_.FullName 'units\x86_64-linux'
   if (Test-Path $d) { $fu += $d }
}
$fu += 'C:\Lazarus\lcl', 'C:\Lazarus\lcl\widgetset', 'C:\Lazarus\lcl\forms',
       'C:\Lazarus\components\lazutils',
       (Join-Path $repo 'tr4w\include'),
       (Join-Path $repo 'tr4w\src'),
       (Join-Path $repo 'tr4w\src\utils'),
       $out

$a = @('-Tlinux', '-Px86_64', '-Mdelphi', '-XPx86_64-linux-', "-FE$out", "-FU$out",
       '-FiC:\Lazarus\lcl\include',
       "-Fi$(Join-Path $repo 'tr4w\src')")
foreach ($p in $fu) { $a += "-Fu$p" }

$env:PATH = "$shim;$env:PATH"
$output = & $fpc @a $src 2>&1

$problems = $output | Select-String -Pattern 'Error:|Fatal:'
if (-not $problems) {
   Write-Host "COMPILES FOR LINUX: $Unit" -ForegroundColor Green
   exit 0
}

Write-Host "still Windows-bound: $Unit" -ForegroundColor Yellow
if ($All) { $problems } else { $problems | Select-Object -First 6 }
exit 1
