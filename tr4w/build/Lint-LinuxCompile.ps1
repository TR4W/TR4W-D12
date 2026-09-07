<#
.SYNOPSIS
   A pinned set of units must still compile for x86_64-linux.

.DESCRIPTION
   THE SUCCESSOR TO THE SERVER'S LCL EXCLUSION.

   Until 2026-09-06 tr4wserver was the one program in this tree with no widget
   set, and its unit search paths excluded the LCL deliberately. That exclusion
   was not tidiness -- it was the only AUTOMATIC check that a unit had not
   quietly grown a widget-set dependency, and it earned its keep twice: it
   caught VC.pas moving to LCLType within a minute, and its absence let the
   uCrashLog -> Forms edge hide for three days.

   tr4wserver is an LCL application now, so there is no program left without a
   widget set and that guard has nothing to guard. NY4I's call was to replace it
   with this: the same class of defect -- a unit quietly acquiring a platform
   dependency -- caught against the platform that now matters.

   WHAT IT ACTUALLY CHECKS. Every unit in the list below compiled for Linux on
   the day it was added. If one stops, something in it or in what it uses has
   bound itself to Windows, and this says which unit and which identifier.

   IT IS A RATCHET, NOT A TARGET. Add a unit the day it first compiles; never
   remove one to make the build pass. A unit that has to come off the list is a
   decision, and it belongs in the commit message.

.NOTES
   Skipped, loudly, when no cross compiler is installed -- see
   docs/CROSS_COMPILING.md for how to build one. A developer without it is not
   blocked; CI and anyone doing cross-platform work has it.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$repo    = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$compile = Join-Path $repo 'tools\Compile-Linux.ps1'
$fpc     = 'C:\fpcupdeluxe\fpcsrc\compiler\ppcrossx64.exe'

# THE PINNED LIST.  Each entry compiled for x86_64-linux on the date given.
$UNITS = @(
   @{ Unit = 'VC.pas';          Since = '2026-09-06' }   # the types unit: everything waits behind it
   @{ Unit = 'uBandLookup.pas'; Since = '2026-09-06' }
   @{ Unit = 'uCRC32.pas';      Since = '2026-09-06' }
   @{ Unit = 'uADIF.pas';       Since = '2026-09-06' }
   # Added 2026-09-07, the day the Windows gates went in.  Each of these was
   # Windows-only that morning: ComPortEnumerator is SetupAPI, uSerialPort is
   # the vendored FPC serial unit, uYCCCSO2R is HID.  They are here because
   # they COMPILED, not because the gate looked right.
   #
   # That distinction earned itself immediately: this check found that the
   # vendored serial merge had given SerBreak the Windows default (250) in an
   # interface whose Unix body declares 0, which no Windows build could see.
   @{ Unit = 'uAppPaths.pas';         Since = '2026-09-07' }
   @{ Unit = 'ComPortEnumerator.pas'; Since = '2026-09-07' }
   @{ Unit = 'uSerialPort.pas';       Since = '2026-09-07' }
   @{ Unit = 'uYCCCSO2R.pas';         Since = '2026-09-07' }
   @{ Unit = 'uWindowSnap.pas';       Since = '2026-09-07' }
   # Added 2026-09-07 by the LCLType sweep. None of these three used anything
   # from the Windows unit -- uRussiaOblasts named it as the SOLE entry in its
   # uses clause and is a callsign-prefix lookup table. Proven by compiling,
   # not by reading the uses clause.
   @{ Unit = 'uAccelerators.pas';     Since = '2026-09-07' }
   @{ Unit = 'cty.pas';               Since = '2026-09-07' }
   @{ Unit = 'uRussiaOblasts.pas';    Since = '2026-09-07' }

   # Added 2026-09-07 by CONVERTING the Win32 calls, not by gating them.
   # utils_file was a thin wrapper over CreateFileA/ReadFile/WriteFile and is
   # now SysUtils FileCreate/FileRead/FileWrite; uCTYDAT memory-mapped CTY.DAT
   # and now reads it into memory. The CHAIN is the point: uCallSignRoutines
   # was blocked by uCTYDAT, which was blocked by utils_file.
   # Note the subdirectory -- the script joins the name onto tr4w\src.
   @{ Unit = 'utils\utils_file.pas'; Since = '2026-09-07' }
   @{ Unit = 'uctydat.pas';           Since = '2026-09-07' }
   @{ Unit = 'uCallSignRoutines.pas'; Since = '2026-09-07' }

)

if (-not (Test-Path $fpc))
   {
   Write-Host "  Lint-LinuxCompile: SKIPPED -- no x86_64-linux compiler at $fpc"
   Write-Host "    See docs/CROSS_COMPILING.md. This is the successor to the server's"
   Write-Host "    LCL exclusion; without it nothing checks for new platform bindings."
   exit 0
   }

$failed = @()
foreach ($u in $UNITS)
   {
   & powershell -NoProfile -File $compile $u.Unit *> $null
   if ($LASTEXITCODE -ne 0)
      {
      $failed += $u
      }
   }

if ($failed.Count -gt 0)
   {
   Write-Host "Lint-LinuxCompile FAILED -- $($failed.Count) unit(s) no longer compile for Linux" -ForegroundColor Red
   foreach ($u in $failed)
      {
      Write-Host "    $($u.Unit)   (compiled for Linux since $($u.Since))" -ForegroundColor Red
      }
   Write-Host "  Run  .\tools\Compile-Linux.ps1 <unit>  to see which identifier binds it." -ForegroundColor Red
   Write-Host "  This is a RATCHET: do not remove a unit from the list to go green." -ForegroundColor Red
   exit 1
   }

Write-Host "  Lint-LinuxCompile: $($UNITS.Count) unit(s) still compile for x86_64-linux."
exit 0
