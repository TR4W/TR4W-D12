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
   # Added 2026-09-09. These two are the reason the list matters: BOTH of
   # them compiled clean on Windows while being broken on Linux, because the
   # code that was wrong sits inside {$IFDEF LINUX} and {$IFNDEF WINDOWS}.
   #
   #   uAppPaths      a literal-eating edit left StringReplace(s, '', '/'),
   #                  an empty search string. Compiled, did nothing.
   #   uOpenSSLLoader fpSymlink got PChar, which is PWideChar in this
   #                  program's string mode, twice over.
   #
   # 22,841 passing Windows tests said nothing about either. A Linux compile
   # found both in one run each.
   @{ Unit = 'utils\uOpenSSLLoader.pas';    Since = '2026-09-09' }
   @{ Unit = 'utils\uHTTPDownload.pas';     Since = '2026-09-09' }
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
   # Added 2026-09-08 by the Windows-dependency sweep.
   #
   # uStickyKeys and GetWinVersionInfo are GATED, not converted, and they are
   # here for exactly that reason: a gate is a guess until a compiler
   # disagrees, and the {$ELSE} arm of a Windows-only unit is code that NO
   # Windows build ever compiles. GetWinVersionInfo's fallback -- the
   # {$I %FPCTARGETOS%} one -- had never been through a compiler until this
   # entry was added.
   @{ Unit = 'uStickyKeys.pas';       Since = '2026-09-08' }
   # uAudio is NEW code and pinned from birth -- the point of writing it was
   # that every platform decision about sound lives in one place, and a pin is
   # what keeps that true. Its Unix arm (aplay/paplay/afplay via RunProgram)
   # is code no Windows build compiles, so without this nothing would ever
   # read it.
   @{ Unit = 'utils' + [char]92 + 'uAudio.pas'; Since = '2026-09-08' }
   @{ Unit = 'GetWinVersionInfo.pas'; Since = '2026-09-08' }

   # MainUnit, ADDED 2026-09-08, AND IT IS NOT ONE UNIT.
   #
   # It is the top of the app's dependency graph, so this single entry compiles
   # most of src for x86_64-linux: TRDOS, the radio and rotator factories, the
   # LCL forms, the domain layer, Indy. Every other row above is reachable from
   # it. That makes this pin SLOW -- it is the whole tree, not a leaf -- and it
   # is worth it, because it is the only entry that can catch a regression in a
   # unit nobody thought to pin.
   #
   # WHAT IT TOOK, all of it invisible to a grep for `Windows.`:
   #   * TLVItem in the log-row builder -- a comctl32 struct used as a carrier
   #     for two values, replaced by the two values
   #   * THandle meaning two different types depending on uses-clause ORDER
   #     (LCLType redeclares it), which is why utils_file now names
   #     TFileHandle and VC names TLPTBaseAddress
   #   * a menu routine still taking Win32 MF_* flags although its body had
   #     been `item.Enabled := ...` for weeks
   #   * SetThreadPriority/CloseHandle on threads, where the RTL reaches the
   #     same Win32 call anyway
   #   * the plugin loader and the inpout32 load, both GATED rather than
   #     ported, because both are open product decisions
   #
   # IF THIS ROW FAILS, DO NOT DELETE IT. The failure is the finding. It means
   # a Windows dependency has been added somewhere in the tree, and the error
   # names the unit and the identifier.
   @{ Unit = 'MainUnit.pas';          Since = '2026-09-08' }

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
