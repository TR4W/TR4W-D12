<#
.SYNOPSIS
   Builds the bench programs in tr4w\test\bench.

.DESCRIPTION
   Same shape as Build-Tests.ps1 and the same search paths -- a bench program
   links the same leaf units the unit tests do.

   With no -Program it builds EVERY test\bench\bench_*.lpr, reports each, and
   exits non-zero if any fails. FullBuild.ps1 calls it that way, after the unit
   tests: bench_callsign failed to link for weeks (no Interfaces in its uses)
   because nothing built it. Running a bench program is still manual -- it asks
   a real radio a question -- but it must always BUILD.

   -Program <name> builds one. -Run needs a single -Program.
#>
param(
   [string] $SourceDir,
   [string] $Program = '',
   [switch] $Run,
   [string] $RunArgs
)

$ErrorActionPreference = 'Stop'

# A guard that finds nothing must fail, not pass. Five programs exist today.
$MIN_BENCH_PROGRAMS = 5

if ($Run -and -not $Program) {
   Write-Output 'FAIL: -Run needs a single -Program; it will not run every bench program.'
   exit 1
}

$TR4W_DIR = if ($SourceDir) { $SourceDir } else { Split-Path -Parent $PSScriptRoot }
. (Join-Path $PSScriptRoot 'Find-Toolchain.ps1')
. (Join-Path $PSScriptRoot 'Get-SearchPaths.ps1')

$tc    = Find-Tr4wToolchain
$bench = Join-Path $TR4W_DIR 'test\bench'
$test  = Join-Path $TR4W_DIR 'test\unit'
$out   = Join-Path (Split-Path -Parent $TR4W_DIR) 'build-out\bench'

if ($Program) {
   $programs = @($Program)
}
else {
   $programs = @(Get-ChildItem -Path $bench -Filter 'bench_*.lpr' |
                 Sort-Object Name | ForEach-Object { $_.BaseName })
   if ($programs.Count -lt $MIN_BENCH_PROGRAMS) {
      Write-Output ("FAIL: found {0} bench_*.lpr in {1}, expected at least {2}" -f `
                    $programs.Count, $bench, $MIN_BENCH_PROGRAMS)
      exit 1
   }
}

if (-not (Test-Path $out)) {
   New-Item -ItemType Directory -Path $out -Force | Out-Null
}

# Builds one program. Returns $true on success. Never calls exit, so the caller
# can report every program before deciding.
function Build-OneBench([string] $Name) {
   $exe = Join-Path $bench "$Name.exe"

   # A failed link must not leave last week's exe looking like a success.
   if (Test-Path $exe) { Remove-Item $exe -Force }

   # Always a full build here, so always clear first -- see Clear-Tr4wUnitOutput.
   $cleared = Clear-Tr4wUnitOutput -OutDir $out
   if ($cleared -gt 0) { Write-Host "  cleared $cleared stale artifact(s) from $out" }
   $fpcArgs = @('-Mdelphi', "-P$($tc.Cpu)", "-T$($tc.Os)", '-Sc', '-B', "-FU$out", "-o$exe")
   foreach ($p in (Get-Tr4wSearchPaths -Tr4wDir $TR4W_DIR -Toolchain $tc -For Tests -TestDir $test)) {
      $fpcArgs += "-Fu$p"
   }
   foreach ($p in (Get-Tr4wIncludePaths -Tr4wDir $TR4W_DIR)) { $fpcArgs += "-Fi$p" }
   $fpcArgs += "$Name.lpr"

   Push-Location $bench
   try {
      $output = & $tc.FpcExe @fpcArgs 2>&1
      $log = Join-Path (Split-Path -Parent $TR4W_DIR) "build-out\bench-build-$Name.log"
      $output | Out-File -FilePath $log -Encoding UTF8
      # FPC's diagnostic PREFIX, not the word anywhere: the first version counted
      # "range check error while evaluating constants" -- a WARNING -- as a build
      # failure. Same pattern Build-Tests.ps1 uses.
      $errors = @($output | Select-String -Pattern '\bError:|\bFatal:')
      Write-Output ("{0}: errors+fatals : {1}" -f $Name, $errors.Count)
      if ($errors.Count -gt 0) {
         $errors | Select-Object -First 10 | ForEach-Object { Write-Output ("  " + $_.Line.Trim()) }
         return $false
      }
      if (-not (Test-Path $exe)) {
         Write-Output "  no exe produced at $exe"
         return $false
      }
      Write-Output "BUILD OK -> $exe"
      return $true
   }
   finally {
      Pop-Location
   }
}

$failed = @()
foreach ($name in $programs) {
   if (-not (Build-OneBench $name)) { $failed += $name }
}

Write-Output ''
Write-Output ("bench programs: {0} built, {1} failed" -f ($programs.Count - $failed.Count), $failed.Count)
if ($failed.Count -gt 0) {
   Write-Output ("FAILED: " + ($failed -join ', '))
   exit 1
}

if ($Run) {
   Write-Output ''
   & (Join-Path $bench "$Program.exe") $RunArgs.Split(' ')
}
