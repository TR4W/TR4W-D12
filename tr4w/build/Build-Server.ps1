# Builds tr4wserver.lpr with FPC.
#
# NO LCL AND NO -WG. tr4wserver is a console program with no UI at all, so it
# links neither the widgetset nor any ui\ unit -- see Get-SearchPaths, which
# gives 'Server' a deliberately different list rather than one shared superset.
#
#   .\Build-Server.ps1

param(
   [string] $OutExe = '',
   [string] $Fpc = '',
   [string] $Laz = '',
   [string] $Cpu = 'i386',
   [string] $Os  = 'win32'
)

$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'Find-Toolchain.ps1')
. (Join-Path $PSScriptRoot 'Get-SearchPaths.ps1')

$TR4W_DIR   = Split-Path $PSScriptRoot -Parent
$REPO       = Split-Path $TR4W_DIR -Parent
$SERVER_DIR = Join-Path $TR4W_DIR 'tr4wserver'

$tc = Find-Tr4wToolchain -Fpc $Fpc -Laz $Laz -Cpu $Cpu -Os $Os -Quiet
if (-not $tc) { exit 2 }

$out = Join-Path $REPO "build-out\server-$Cpu-$Os"
$exe = if ($OutExe -ne '') { $OutExe } else { Join-Path $SERVER_DIR 'tr4wserver.exe' }

if (-not (Test-Path $out)) { New-Item -ItemType Directory -Path $out | Out-Null }

# Always a full build here, so always clear first -- see Clear-Tr4wUnitOutput.
$cleared = Clear-Tr4wUnitOutput -OutDir $out
if ($cleared -gt 0) { Write-Host "  cleared $cleared stale artifact(s) from $out" }
# -dTR4W_NO_LCL IS GONE, and it lived for about two hours.
#
# It existed because tr4wserver was the one program in this tree with no widget
# set, so VC.pas had to be told where to read HWND from. tr4wserver is an LCL
# application now (2026-09-06) and reads LCLType like everything else, so the
# define has nothing to select and VC's branch on it is deleted with it.
$fpcArgs = @("-Mdelphi", "-P$Cpu", "-T$Os", '-Sc', '-B', "-FU$out", "-o$exe")
foreach ($p in (Get-Tr4wSearchPaths -Tr4wDir $TR4W_DIR -Toolchain $tc -For Server)) { $fpcArgs += "-Fu$p" }
foreach ($p in (Get-Tr4wIncludePaths -Tr4wDir $TR4W_DIR)) { $fpcArgs += "-Fi$p" }
$fpcArgs += 'tr4wserver.lpr'

Push-Location $SERVER_DIR
try
   {
   $output = & $tc.FpcExe @fpcArgs 2>&1
   $rc = $LASTEXITCODE
   }
finally
   {
   Pop-Location
   }

$errLines = $output | Select-String -Pattern '\bError:|\bFatal:'
$output | Out-File -FilePath (Join-Path $REPO 'build-out\server-build.log') -Encoding utf8

if ($rc -ne 0)
   {
   Write-Host "tr4wserver build FAILED (exit $rc)" -ForegroundColor Red
   $errLines | Select-Object -First 10 | ForEach-Object { Write-Host "  $($_.Line.Trim())" }
   exit 1
   }

# -----------------------------------------------------------------------------
# THE BINARY MUST CONTAIN ITS DIALOG TEMPLATE.
#
# tr4wserver IS a dialog -- its entire program body is DialogBox(hInstance,
# MAKEINTRESOURCE(100), ...). DialogBox returns -1 for a template it cannot
# find, so a binary built without the resource starts, exits 0, shows no window
# and writes nothing anywhere. It looks exactly like a program that was asked to
# quit.
#
# That shipped for sixteen days. FPC resolves {$R} by BASENAME, the dialog
# resource and the Lazarus project resource were both called tr4wserver.res, and
# the compiler linked whichever it found first -- silently, with the link
# succeeding either way. Renaming one file fixed it; this makes the fix hold.
#
# Reads the PE resource directory rather than running anything.
# -----------------------------------------------------------------------------
# THE SPECIFIC ID, not "does it have any dialog". A widget set brings its own --
# tr4w.exe carries an LCL one called LAZ_PIC_DIALOG_TEMPLATE -- so "some dialog
# is present" is a check that passes on the wrong resource. Ask for the template
# the program actually opens.
function Test-PEHasDialogId
{
   param([string] $Path, [uint32] $Id)

   $b = [System.IO.File]::ReadAllBytes($Path)
   $pe = [BitConverter]::ToInt32($b, 0x3c)
   $nsec = [BitConverter]::ToUInt16($b, $pe + 6)
   $optSize = [BitConverter]::ToUInt16($b, $pe + 20)
   $sec = $pe + 24 + $optSize

   for ($i = 0; $i -lt $nsec; $i++)
      {
      $o = $sec + $i * 40
      $name = [Text.Encoding]::ASCII.GetString($b, $o, 8).TrimEnd([char]0)
      if ($name -ne '.rsrc') { continue }

      $raw = [BitConverter]::ToInt32($b, $o + 20)
      $named = [BitConverter]::ToUInt16($b, $raw + 12)
      $ids   = [BitConverter]::ToUInt16($b, $raw + 14)
      for ($e = 0; $e -lt ($named + $ids); $e++)
         {
         $tid = [BitConverter]::ToUInt32($b, $raw + 16 + $e * 8)
         $off = [BitConverter]::ToUInt32($b, $raw + 20 + $e * 8)
         # RT_DIALOG = 5. The high bit marks a name rather than an id.
         if (($tid -band 0x80000000) -ne 0 -or $tid -ne 5) { continue }

         # Second level: the names/ids within this type.
         $sub = $raw + ($off -band 0x7fffffff)
         $n2 = [BitConverter]::ToUInt16($b, $sub + 12)
         $i2 = [BitConverter]::ToUInt16($b, $sub + 14)
         for ($e2 = 0; $e2 -lt ($n2 + $i2); $e2++)
            {
            $nid = [BitConverter]::ToUInt32($b, $sub + 16 + $e2 * 8)
            if (($nid -band 0x80000000) -eq 0 -and $nid -eq $Id) { return $true }
            }
         }
      }
   return $false
}

# THE DIALOG ASSERTION IS RETIRED WITH THE DIALOG (2026-09-06).
#
# It checked that DIALOG 100 was really in the linked binary, because the whole
# program was DialogBox(hInstance, MAKEINTRESOURCE(100), ...) and a missing
# template made it start, exit 0 and show nothing -- which happened, and stayed
# invisible for weeks. tr4wserver is an LCL application now: its window is
# uServerForm.lfm, streamed by the LCL, and a missing form is a loud run-time
# error rather than a silent exit.
#
# Test-PEHasDialogId is kept above and unused ON PURPOSE. It is forty lines of
# PE resource-directory walking that took real effort to get right, the client
# still ships dialog resources, and deleting it would mean writing it again.

Write-Host "BUILD OK -> $exe"
exit 0
