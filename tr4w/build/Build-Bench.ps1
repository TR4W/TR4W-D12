<#
.SYNOPSIS
   Builds the benchmark programs in tr4w\test\bench.

.DESCRIPTION
   Same shape as Build-Tests.ps1 and the same search paths -- a benchmark links
   the same leaf units the unit tests do. Kept separate because a benchmark is
   not a gate: it answers a question ("how long does this take?") and nothing in
   the build depends on its result.
#>
param(
   [string] $SourceDir,
   [string] $Program = 'bench_callsign',
   [switch] $Run,
   [string] $RunArgs
)

$ErrorActionPreference = 'Stop'

$TR4W_DIR = if ($SourceDir) { $SourceDir } else { Split-Path -Parent $PSScriptRoot }
. (Join-Path $PSScriptRoot 'Find-Toolchain.ps1')
. (Join-Path $PSScriptRoot 'Get-SearchPaths.ps1')

$tc    = Find-Tr4wToolchain
$bench = Join-Path $TR4W_DIR 'test\bench'
$test  = Join-Path $TR4W_DIR 'test\unit'
$out   = Join-Path (Split-Path -Parent $TR4W_DIR) 'build-out\bench'

if (-not (Test-Path $out)) {
   New-Item -ItemType Directory -Path $out -Force | Out-Null
}

$exe = Join-Path $bench "$Program.exe"

# Always a full build here, so always clear first -- see Clear-Tr4wUnitOutput.
$cleared = Clear-Tr4wUnitOutput -OutDir $out
if ($cleared -gt 0) { Write-Host "  cleared $cleared stale artifact(s) from $out" }
$fpcArgs = @('-Mdelphi', "-P$($tc.Cpu)", "-T$($tc.Os)", '-Sc', '-B', "-FU$out", "-o$exe")
foreach ($p in (Get-Tr4wSearchPaths -Tr4wDir $TR4W_DIR -Toolchain $tc -For Tests -TestDir $test)) {
   $fpcArgs += "-Fu$p"
}
foreach ($p in (Get-Tr4wIncludePaths -Tr4wDir $TR4W_DIR)) { $fpcArgs += "-Fi$p" }
$fpcArgs += "$Program.dpr"

Push-Location $bench
try {
   $output = & $tc.FpcExe @fpcArgs 2>&1
   $log = Join-Path (Split-Path -Parent $TR4W_DIR) 'build-out\bench-build.log'
   $output | Out-File -FilePath $log -Encoding UTF8
   # FPC's diagnostic PREFIX, not the word anywhere: the first version counted
   # "range check error while evaluating constants" -- a WARNING -- as a build
   # failure. Same pattern Build-Tests.ps1 uses.
   $errors = @($output | Select-String -Pattern '\bError:|\bFatal:')
   Write-Output ("errors+fatals : {0}" -f $errors.Count)
   if ($errors.Count -gt 0) {
      $errors | Select-Object -First 10 | ForEach-Object { Write-Output ("  " + $_.Line.Trim()) }
      exit 1
   }
   Write-Output "BUILD OK -> $exe"
}
finally {
   Pop-Location
}

if ($Run) {
   Write-Output ''
   & $exe $RunArgs.Split(' ')
}
