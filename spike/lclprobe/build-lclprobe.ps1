# Builds the LCL .lfm streaming probe for i386-win32.
#
# TR4W is a 32-bit program, so the probe is too -- Lazarus ships an x86_64 fpc
# binary but carries LCL units for BOTH targets, and their PPU format (207)
# matches C:\FPC\3.2.2, so our i386 compiler consumes them directly.  No
# cross-compiler and no Lazarus fpc needed.
#
# PowerShell rather than bash because Git Bash rewrites -Fu<path> arguments on
# the way to a native Windows binary, which is what made the first attempts
# report "Can't find unit Interfaces" against a path that plainly existed.

param(
   [string] $Fpc  = 'C:\FPC\3.2.2\bin\i386-win32\fpc.exe',
   [string] $Laz  = 'C:\Lazarus',
   [switch] $Run
)

$here = $PSScriptRoot

$unitPaths = @(
   "$Laz\lcl\units\i386-win32"
   "$Laz\lcl\units\i386-win32\win32"
   "$Laz\components\lazutils\lib\i386-win32"
   "$Laz\packager\units\i386-win32"
   $here
)

foreach ($p in $unitPaths)
   {
   if (-not (Test-Path $p))
      {
      Write-Host "missing unit path: $p" -ForegroundColor Red
      exit 1
      }
   }

$fpcArgs = @('-MObjFPC', '-Pi386', '-Twin32', '-B', "-FU$here", "-o$here\lclprobe.exe")
foreach ($p in $unitPaths) { $fpcArgs += "-Fu$p" }
$fpcArgs += "$here\lclprobe.lpr"

Push-Location $here
try
   {
   $out = & $Fpc @fpcArgs 2>&1
   $rc = $LASTEXITCODE
   }
finally
   {
   Pop-Location
   }

$errs = $out | Select-String -Pattern '\bError:|\bFatal:'
Write-Host "errors+fatals : $($errs.Count)"
if ($errs.Count -gt 0)
   {
   $errs | Select-Object -First 15 | ForEach-Object { Write-Host "  $($_.Line.Trim())" }
   }

# State the outcome explicitly -- a filtered pipeline that matches nothing
# prints nothing, which reads as success.
if ($rc -ne 0)
   {
   Write-Host "BUILD FAILED (exit $rc)" -ForegroundColor Red
   exit 1
   }

Write-Host "BUILD OK -> $here\lclprobe.exe"

if ($Run)
   {
   Write-Host ''
   & "$here\lclprobe.exe"
   Write-Host "probe exit code = $LASTEXITCODE"
   }
