<#
.SYNOPSIS
   Fails when a non-shipping (32-bit) build could write into the shipping program
   directory, or when a runtime DLL is the wrong architecture for where it sits.

.DESCRIPTION
   WHY (issue 299, 2026-11-12). tr4w\target holds the SHIPPING (x86_64-win64) exe,
   tr4wconvert and runtime DLLs that full.nsi ships; the 32-bit DLLs have the SAME
   FILE NAMES. build\Get-StagingDir.ps1 names the shipping architecture once,
   routes every other build to build-out\dist\<cpu>-<os> and
   Assert-Tr4wShippingPathOnly refuses the shipping paths to it.

   THIS LINT PINS IT, three ways:
     1. A FIXTURE of cases run through the real functions (floor: 14 cases). It
        must come out exact -- a guard that never throws, or throws on the
        shipping architecture, both fail.
     2. A SOURCE CHECK that each build script still calls the guard and that
        FullBuild still takes its exe paths from the stage functions (floor: 4
        call sites), so the guard cannot be quietly un-wired.
     3. A PE CHECK of every *.dll in tr4w\target and in each tr4w\redist\<cpu>-<os>
        against that directory's architecture (floor: 12 DLLs). Windows reports a
        wrong-bitness DLL as "module not found", so the machine word is read from
        the header, never trusted from a name.

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

$shipCpu = $script:Tr4wShippingCpu
$shipOs  = $script:Tr4wShippingOs
$otherCpu = 'i386'
$otherOs  = 'win32'

# ---- 1. the fixture -------------------------------------------------------
function Test-Throws([string] $cpu, [string] $os, [string] $path)
   {
   try
      {
      Assert-Tr4wShippingPathOnly -Tr4wDir $TR4W -Cpu $cpu -Os $os -Path $path -What 'fixture'
      return $false
      }
   catch
      {
      return $true
      }
   }

$t = Join-Path $TR4W 'target'
$s = Join-Path $TR4W 'tr4wserver'
$otherStage = Get-Tr4wStageDir -Tr4wDir $TR4W -Cpu $otherCpu -Os $otherOs
$cases = @(
   # cpu, os, path, must it be refused?
   @($otherCpu, $otherOs, (Join-Path $t 'tr4w.exe'),              $true),
   @($otherCpu, $otherOs, $t,                                     $true),
   @($otherCpu, $otherOs, ($t + '\'),                             $true),
   @($otherCpu, $otherOs, (Join-Path $t '..\target\tr4w.exe'),    $true),
   @($otherCpu, $otherOs, (Join-Path $t 'sub\dir\x.dll'),         $true),
   @($otherCpu, $otherOs, (Join-Path $TR4W 'TARGET\tr4w.exe'),    $true),
   @($otherCpu, $otherOs, (Join-Path $s 'tr4wserver.exe'),        $true),
   @($otherCpu, $otherOs, (Join-Path $t 'tr4wconvert.exe'),       $true),
   @($otherCpu, $otherOs, $otherStage,                            $false),
   @($otherCpu, $otherOs, (Join-Path $otherStage 'tr4w.exe'),     $false),
   @($otherCpu, $otherOs, (Get-Tr4wServerExePath -Tr4wDir $TR4W -Cpu $otherCpu -Os $otherOs), $false),
   @($otherCpu, $otherOs, (Join-Path $TR4W 'target-i386-win32\tr4w.exe'), $false),  # a sibling name, not under target\
   @($shipCpu,  $shipOs,  (Join-Path $t 'tr4w.exe'),              $false),
   @($shipCpu,  $shipOs,  (Join-Path $s 'tr4wserver.exe'),        $false)
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
$shipStage = Get-Tr4wStageDir -Tr4wDir $TR4W -Cpu $shipCpu -Os $shipOs
if ((Get-Tr4wFullPath $shipStage) -ne (Get-Tr4wFullPath $t))
   { $failures += "shipping stage dir is '$shipStage', must be tr4w\target" }
$shipServer = Get-Tr4wServerExePath -Tr4wDir $TR4W -Cpu $shipCpu -Os $shipOs
if ((Get-Tr4wFullPath $shipServer) -ne (Get-Tr4wFullPath (Join-Path $s 'tr4wserver.exe')))
   { $failures += "shipping server path is '$shipServer', must be tr4w\tr4wserver\tr4wserver.exe" }
if ((Test-Tr4wUnder -Path $otherStage -Dir $t) -or (Test-Tr4wUnder -Path $otherStage -Dir $s))
   { $failures += "$otherCpu stage dir '$otherStage' is inside a shipping directory" }
$resolved = Resolve-Tr4wTarget -Cpu '' -Os ''
if (($resolved.Cpu -ne $shipCpu) -or ($resolved.Os -ne $shipOs))
   { $failures += "an empty -Cpu/-Os must resolve to $shipCpu-$shipOs, got $($resolved.Cpu)-$($resolved.Os)" }
$resolved = Resolve-Tr4wTarget -Cpu 'i386' -Os ''
if (($resolved.Cpu -ne 'i386') -or ($resolved.Os -ne 'win32'))
   { $failures += "-Cpu i386 alone must resolve to i386-win32, got $($resolved.Cpu)-$($resolved.Os)" }

# ---- 2. the source check --------------------------------------------------
$sites = 0
foreach ($name in @('Build-App.ps1', 'Build-Server.ps1', 'Build-Convert.ps1', 'Build-Installer.ps1'))
   {
   $p = Join-Path $BUILD $name
   if (-not (Test-Path -LiteralPath $p)) { $failures += "$name not found"; continue }
   if ((Get-Content -LiteralPath $p -Raw) -match 'Assert-Tr4wShippingPathOnly') { $sites++ }
   else { $failures += "$name no longer calls Assert-Tr4wShippingPathOnly" }
   }
if ($sites -lt 4) { $failures += "guard call sites: $sites, floor is 4" }

$fb = Get-Content -LiteralPath (Join-Path $TR4W 'FullBuild.ps1') -Raw
if ($fb -notmatch 'Get-Tr4wStageDir')       { $failures += 'FullBuild.ps1 does not use Get-Tr4wStageDir' }
if ($fb -notmatch 'Get-Tr4wServerExePath')  { $failures += 'FullBuild.ps1 does not use Get-Tr4wServerExePath' }
if ($fb -match 'Join-Path \$TARGET_DIR ''(tr4w|tr4wconvert)\.exe''')
   { $failures += 'FullBuild.ps1 builds an exe path straight under $TARGET_DIR again' }

# ---- 3. every runtime DLL is the architecture of the directory it sits in --
$dllCount = 0
$dirs = @(
   @($t, $shipCpu),
   @((Get-Tr4wRedistDir -Tr4wDir $TR4W -Cpu $shipCpu -Os $shipOs), $shipCpu),
   @((Get-Tr4wRedistDir -Tr4wDir $TR4W -Cpu $otherCpu -Os $otherOs), $otherCpu)
)
foreach ($d in $dirs)
   {
   if (-not (Test-Path -LiteralPath $d[0]))
      {
      $failures += "runtime DLL directory not found: $($d[0])"
      continue
      }
   $want = Get-Tr4wExpectedPeMachine -Cpu $d[1]
   foreach ($f in @(Get-ChildItem -LiteralPath $d[0] -Filter '*.dll' -File))
      {
      $dllCount++
      $m = Get-Tr4wPeMachine -Path $f.FullName
      if ($m -ne $want)
         {
         $got = if ($m -eq 0) { 'not a PE image' } else { Get-Tr4wPeMachineName -Machine $m }
         $failures += "$($f.FullName) is $got, expected $(Get-Tr4wPeMachineName -Machine $want)"
         }
      }
   }
if ($dllCount -lt 12) { $failures += "PE-checked $dllCount DLLs, floor is 12" }

# A 32-bit HamLib left under another name where a 64-bit exe could be pointed at it.
foreach ($stray in @(Get-ChildItem -LiteralPath $t -Filter 'libhamlib*' -File))
   {
   if ($stray.Name -ne 'libhamlib-4.dll') { $failures += "stray HamLib copy in tr4w\target: $($stray.Name)" }
   }

if ($failures.Count -gt 0)
   {
   Write-Host 'Lint-ArchStaging FAILED:' -ForegroundColor Red
   $failures | ForEach-Object { Write-Host "  $_" }
   exit 1
   }

Write-Host "Lint-ArchStaging: $($cases.Count) fixture cases, $sites guard call sites, $dllCount DLLs PE-checked -- OK"
exit 0
