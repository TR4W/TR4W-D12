<#
.SYNOPSIS
   Fails when a 64-bit build could write into the 32-bit program directory.

.DESCRIPTION
   WHY (issue 299, 2026-11-12). tr4w\target holds the i386 exe, tr4wconvert and the
   seven 32-bit DLLs that full.nsi ships; the x64 DLLs have the SAME FILE NAMES.
   FullBuild.ps1 used to pass -OutExe target\tr4w.exe for any -Cpu and Build-App
   stages DLLs beside the exe, so an x86_64 FullBuild would have overwritten the
   shipping 32-bit files. build\Get-StagingDir.ps1 now routes every non-i386 build
   to build-out\dist\<cpu>-<os> and Assert-Tr4wNotI386Path refuses the i386 paths.

   THIS LINT PINS IT, two ways:
     1. A FIXTURE of cases run through the real functions (floor: 14 cases). It
        must come out exact -- a guard that never throws, or throws on i386,
        both fail.
     2. A SOURCE CHECK that each build script still calls the guard and that
        FullBuild still takes its exe paths from the stage functions (floor: 4
        call sites), so the guard cannot be quietly un-wired.

   Reads files and runs functions only; compiles nothing.

   .\Lint-ArchStaging.ps1
#>
param(
   [string] $SourceDir = ''
)

$ErrorActionPreference = 'Stop'

$BUILD   = $PSScriptRoot
$TR4W    = Split-Path $BUILD -Parent
$failures = @()

. (Join-Path $BUILD 'Get-StagingDir.ps1')

# ---- 1. the fixture -------------------------------------------------------
function Test-Throws([string] $cpu, [string] $os, [string] $path)
   {
   try
      {
      Assert-Tr4wNotI386Path -Tr4wDir $TR4W -Cpu $cpu -Os $os -Path $path -What 'fixture'
      return $false
      }
   catch
      {
      return $true
      }
   }

$t = Join-Path $TR4W 'target'
$s = Join-Path $TR4W 'tr4wserver'
$cases = @(
   # cpu, os, path, must it be refused?
   @('x86_64', 'win64', (Join-Path $t 'tr4w.exe'),              $true),
   @('x86_64', 'win64', $t,                                     $true),
   @('x86_64', 'win64', ($t + '\'),                             $true),
   @('x86_64', 'win64', (Join-Path $t '..\target\tr4w.exe'),    $true),
   @('x86_64', 'win64', (Join-Path $t 'sub\dir\x.dll'),         $true),
   @('x86_64', 'win64', (Join-Path $TR4W 'TARGET\tr4w.exe'),    $true),
   @('x86_64', 'win64', (Join-Path $s 'tr4wserver.exe'),        $true),
   @('x86_64', 'win64', (Join-Path $t 'tr4wconvert.exe'),       $true),
   @('x86_64', 'win64', (Get-Tr4wStageDir -Tr4wDir $TR4W -Cpu x86_64 -Os win64), $false),
   @('x86_64', 'win64', (Join-Path (Get-Tr4wStageDir -Tr4wDir $TR4W -Cpu x86_64 -Os win64) 'tr4w.exe'), $false),
   @('x86_64', 'win64', (Get-Tr4wServerExePath -Tr4wDir $TR4W -Cpu x86_64 -Os win64), $false),
   @('x86_64', 'win64', (Join-Path $TR4W 'target-x86_64-win64\tr4w.exe'), $false),  # a sibling name, not under target\
   @('i386',   'win32', (Join-Path $t 'tr4w.exe'),              $false),
   @('i386',   'win32', (Join-Path $s 'tr4wserver.exe'),        $false)
)
if ($cases.Count -lt 14) { $failures += "fixture shrank below its floor of 14 (has $($cases.Count))" }

foreach ($c in $cases)
   {
   $threw = Test-Throws $c[0] $c[1] $c[2]
   if ($threw -ne $c[3])
      {
      $failures += "fixture: $($c[0])-$($c[1]) '$($c[2])' refused=$threw, expected $($c[3])"
      }
   }

# The stage functions themselves.
$i386Stage = Get-Tr4wStageDir -Tr4wDir $TR4W -Cpu i386 -Os win32
if ((Get-Tr4wFullPath $i386Stage) -ne (Get-Tr4wFullPath $t))
   { $failures += "i386 stage dir is '$i386Stage', must stay tr4w\target" }
$i386Server = Get-Tr4wServerExePath -Tr4wDir $TR4W -Cpu i386 -Os win32
if ((Get-Tr4wFullPath $i386Server) -ne (Get-Tr4wFullPath (Join-Path $s 'tr4wserver.exe')))
   { $failures += "i386 server path is '$i386Server', must stay tr4w\tr4wserver\tr4wserver.exe" }
$x64Stage = Get-Tr4wStageDir -Tr4wDir $TR4W -Cpu x86_64 -Os win64
if ((Test-Tr4wUnder -Path $x64Stage -Dir $t) -or (Test-Tr4wUnder -Path $x64Stage -Dir $s))
   { $failures += "x86_64 stage dir '$x64Stage' is inside an i386 directory" }

# ---- 2. the source check --------------------------------------------------
$sites = 0
foreach ($name in @('Build-App.ps1', 'Build-Server.ps1', 'Build-Convert.ps1', 'Build-Installer.ps1'))
   {
   $p = Join-Path $BUILD $name
   if (-not (Test-Path -LiteralPath $p)) { $failures += "$name not found"; continue }
   if ((Get-Content -LiteralPath $p -Raw) -match 'Assert-Tr4wNotI386Path') { $sites++ }
   else { $failures += "$name no longer calls Assert-Tr4wNotI386Path" }
   }
if ($sites -lt 4) { $failures += "guard call sites: $sites, floor is 4" }

$fb = Get-Content -LiteralPath (Join-Path $TR4W 'FullBuild.ps1') -Raw
if ($fb -notmatch 'Get-Tr4wStageDir')       { $failures += 'FullBuild.ps1 does not use Get-Tr4wStageDir' }
if ($fb -notmatch 'Get-Tr4wServerExePath')  { $failures += 'FullBuild.ps1 does not use Get-Tr4wServerExePath' }
if ($fb -match 'Join-Path \$TARGET_DIR ''(tr4w|tr4wconvert)\.exe''')
   { $failures += 'FullBuild.ps1 builds an exe path straight under $TARGET_DIR again' }

if ($failures.Count -gt 0)
   {
   Write-Host 'Lint-ArchStaging FAILED:' -ForegroundColor Red
   $failures | ForEach-Object { Write-Host "  $_" }
   exit 1
   }

Write-Host "Lint-ArchStaging: $($cases.Count) fixture cases, $sites guard call sites -- OK"
exit 0
