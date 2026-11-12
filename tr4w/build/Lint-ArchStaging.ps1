<#
.SYNOPSIS
   Fails when a runtime DLL is not 64-bit, or when the guard that refuses one has
   been un-wired from the build scripts.

.DESCRIPTION
   WHY. Windows TR4W is x86_64-win64 and nothing else (NY4I, 2026-11-12: "I have
   no plans to ever support 32 bit Windows OS"). A DLL of the wrong bitness is not
   reported as such: Windows says "module not found" naming a file sitting right
   there, or the loader dies with 0xC000007B before a line of TR4W runs and
   nothing reaches tr4w.log. build\Get-StagingDir.ps1 owns the one definition of
   the check (Get-Tr4wWrongArchDlls) and the machine word (0x8664).

   THIS LINT PINS IT, three ways:
     1. A FIXTURE: synthetic DLLs written to a scratch folder -- a good x64 PE, a
        32-bit PE, a PE with a bad signature and a file too short to be a PE --
        run through the real function (floor: 4 cases). It must name exactly the
        three bad ones; a guard that passes a 32-bit DLL, or refuses the good one,
        fails here.
     2. A SOURCE CHECK that Build-App.ps1 and Build-Tests.ps1 still call the
        guard (floor: 2 call sites), so it cannot be quietly un-wired.
     3. A PE CHECK of every *.dll in tr4w\target and in EVERY directory under
        tr4w\redist (floor: 12 DLLs), so a 32-bit set added beside the 64-bit one
        is read, not skipped. tr4w\redist\x86_64-win64 must exist.

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
# A minimal PE image: 'MZ', e_lfanew at 0x3C pointing at 0x80, 'PE\0\0', then the
# machine word. $sig lets a case break the signature.
function New-FixturePe([string] $path, [int] $machine, [uint32] $sig = 0x00004550)
   {
   $bytes = New-Object byte[] 0x100
   $bytes[0x3C] = 0x80
   [BitConverter]::GetBytes($sig).CopyTo($bytes, 0x80)
   [BitConverter]::GetBytes([uint16] $machine).CopyTo($bytes, 0x84)
   [IO.File]::WriteAllBytes($path, $bytes)
   }

$fixtureDir = Join-Path ([IO.Path]::GetTempPath()) ("tr4w-archstaging-" + [guid]::NewGuid().ToString('N'))
$cases = 0
try
   {
   New-Item -ItemType Directory -Path $fixtureDir -Force | Out-Null
   New-FixturePe (Join-Path $fixtureDir 'good64.dll')   0x8664
   New-FixturePe (Join-Path $fixtureDir 'bad32.dll')    0x014C
   New-FixturePe (Join-Path $fixtureDir 'badsig.dll')   0x8664 0x00004551
   [IO.File]::WriteAllBytes((Join-Path $fixtureDir 'tiny.dll'), [byte[]] (1, 2, 3))

   # The case count is what was actually written, and the two PE cases that matter
   # are read back by the header reader itself, so deleting 'bad32.dll' from the
   # lines above fails here instead of leaving a lint that passes on nothing.
   $cases = @(Get-ChildItem -LiteralPath $fixtureDir -Filter '*.dll' -File).Count
   if ($cases -lt 4) { $failures += "fixture shrank below its floor of 4 (has $cases)" }
   if ((Get-Tr4wPeMachine -Path (Join-Path $fixtureDir 'good64.dll')) -ne 0x8664) { $failures += 'fixture: good64.dll is not an x64 PE' }
   if ((Get-Tr4wPeMachine -Path (Join-Path $fixtureDir 'bad32.dll'))  -ne 0x014C) { $failures += 'fixture: bad32.dll is not an x86 PE' }

   $found = @(Get-Tr4wWrongArchDlls -Dir $fixtureDir | ForEach-Object { Split-Path ($_ -split ' is ')[0] -Leaf } | Sort-Object)
   $expected = @('bad32.dll', 'badsig.dll', 'tiny.dll')
   if (($found -join ',') -ne ($expected -join ','))
      {
      $failures += "fixture: the guard named [$($found -join ', ')], expected exactly [$($expected -join ', ')]"
      }
   }
finally
   {
   if (Test-Path -LiteralPath $fixtureDir) { Remove-Item -LiteralPath $fixtureDir -Recurse -Force -ErrorAction SilentlyContinue }
   }

# ---- 2. the source check --------------------------------------------------
$sites = 0
foreach ($name in @('Build-App.ps1', 'Build-Tests.ps1'))
   {
   $p = Join-Path $BUILD $name
   if (-not (Test-Path -LiteralPath $p)) { $failures += "$name not found"; continue }
   if ((Get-Content -LiteralPath $p -Raw) -match 'Get-Tr4wWrongArchDlls') { $sites++ }
   else { $failures += "$name no longer calls Get-Tr4wWrongArchDlls" }
   }
if ($sites -lt 2) { $failures += "guard call sites: $sites, floor is 2" }

# ---- 3. every runtime DLL in the tree is 64-bit ---------------------------
$dllCount = 0
$redistRoot = Join-Path $TR4W 'redist'
$dirs = @((Join-Path $TR4W 'target'))
if (Test-Path -LiteralPath $redistRoot)
   {
   $dirs += @(Get-ChildItem -LiteralPath $redistRoot -Directory | ForEach-Object { $_.FullName })
   }
if (-not (Test-Path -LiteralPath (Get-Tr4wRedistDir -Tr4wDir $TR4W)))
   {
   $failures += "runtime DLL directory not found: $(Get-Tr4wRedistDir -Tr4wDir $TR4W)"
   }

foreach ($d in $dirs)
   {
   if (-not (Test-Path -LiteralPath $d))
      {
      $failures += "runtime DLL directory not found: $d"
      continue
      }
   $dllCount += @(Get-ChildItem -LiteralPath $d -Filter '*.dll' -File).Count
   $failures += @(Get-Tr4wWrongArchDlls -Dir $d)
   }
if ($dllCount -lt 12) { $failures += "PE-checked $dllCount DLLs, floor is 12" }

# A 32-bit HamLib left under another name where a 64-bit exe could be pointed at it.
$t = Join-Path $TR4W 'target'
if (Test-Path -LiteralPath $t)
   {
   foreach ($stray in @(Get-ChildItem -LiteralPath $t -Filter 'libhamlib*' -File))
      {
      if ($stray.Name -ne 'libhamlib-4.dll') { $failures += "stray HamLib copy in tr4w\target: $($stray.Name)" }
      }
   }

if ($failures.Count -gt 0)
   {
   Write-Host 'Lint-ArchStaging FAILED:' -ForegroundColor Red
   $failures | ForEach-Object { Write-Host "  $_" }
   exit 1
   }

Write-Host "Lint-ArchStaging: $cases fixture cases, $sites guard call sites, $dllCount DLLs PE-checked -- OK"
exit 0
