<#
.SYNOPSIS
   Builds and runs the TR4W radio bench test against the radiosim simulator.

.DESCRIPTION
   End-to-end check of a factory radio driver over a REAL serial port, with the
   simulator on the other half of a virtual pair.  This is the layer test/unit
   cannot reach: the reading thread, frame assembly, terminator stripping, and
   link liveness/recovery.

   Needs a virtual COM pair (VSPMGR or com0com) and Python with pyserial.
   Cannot run on CI, which is why it is a separate target from the unit tests.

   A green run proves the driver and the simulator are SELF-CONSISTENT and that
   the plumbing between them works.  It does NOT prove the driver is correct
   about a real radio -- only hardware, the CAT manual, or an independent
   implementation can do that.

.PARAMETER TR4WPort
   Port NUMBER (not name) that TR4W opens.  e.g. 36

.PARAMETER SimPort
   Port NAME that the simulator opens -- the OTHER half of the same pair.
   e.g. COM37

.EXAMPLE
   .\run-bench.ps1 -TR4WPort 36 -SimPort COM37
   .\run-bench.ps1 -TR4WPort 36 -SimPort COM37 -Model FTDX10
#>
[CmdletBinding()]
param(
   [Parameter(Mandatory = $true)][int]$TR4WPort,
   [Parameter(Mandatory = $true)][string]$SimPort,
   [string]$Model = 'FT991',
   [int]$Baud = 4800,
   [switch]$Rebuild
)

$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$exe = Join-Path $here 'tr4w_radio_bench.exe'
$repo = Resolve-Path (Join-Path $here '..\..\..')
$tools = Join-Path $repo 'tools'

if ($Rebuild -or -not (Test-Path $exe)) {
   Write-Host 'Building tr4w_radio_bench...' -ForegroundColor Cyan
   $rsvars = 'C:\Program Files (x86)\Embarcadero\Studio\23.0\bin\rsvars.bat'
   if (-not (Test-Path $rsvars)) {
      throw "rsvars.bat not found at $rsvars -- adjust this script for your Delphi install."
   }
   $paths = '..\..\src;..\..\src\lang;..\..\src\trdos;..\..\src\utils;' +
            '..\..\Include;..\..\include\Core;..\..\include\System;..\..\include\Protocols'
   Push-Location $here
   try {
      & cmd /c "call `"$rsvars`" && dcc32 -Q tr4w_radio_bench.lpr -U$paths -NSWinapi;System;System.Win;Data;Vcl -E."
      if ($LASTEXITCODE -ne 0) { throw "build failed ($LASTEXITCODE)" }
   } finally {
      Pop-Location
   }
}

# The simulator is launched by the EXE itself, so it must not already be running
# on this pair -- that is the most common cause of a confusing failure.
$busy = Get-Process -Name python -ErrorAction SilentlyContinue
if ($busy) {
   Write-Warning ("python.exe is running (PID {0}).  If that is a simulator on {1}, " -f
                  ($busy.Id -join ', '), $SimPort)
   Write-Warning "stop it first -- the bench starts its own and the port cannot be shared."
}

$env:TR4W_TEST_PORT = "$TR4WPort"
$env:TR4W_SIM_PORT  = $SimPort
$env:TR4W_SIM_MODEL = $Model
$env:TR4W_SIM_BAUD  = "$Baud"
$env:TR4W_TOOLS_DIR = $tools

Write-Host ("Bench: TR4W on COM{0}, {1} simulator on {2} at {3} baud" -f
            $TR4WPort, $Model, $SimPort, $Baud) -ForegroundColor Cyan
& $exe
exit $LASTEXITCODE
