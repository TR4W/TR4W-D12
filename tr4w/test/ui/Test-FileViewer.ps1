<#
.SYNOPSIS
   Runs a report and asserts that the file viewer opens with the report's text
   in it, and that it will not shrink past its content.

.DESCRIPTION
   THE VIEWER IS WHERE EVERY EXPORT ENDS. Cabrillo, the summary sheet, EDI, and
   about a dozen reports all finish with FilePreview, so a viewer that opens
   empty makes every one of them look like it produced nothing. The Win32
   version loaded the file in a WM_TIMER handler and simply Exit'ed if the open
   failed, which is exactly the shape that shows an empty window and says
   nothing.

   DRIVEN THROUGH Tools -> Score by hour, because it is one menu command with no
   modal in the way: it writes a report from the loaded log and previews it. The
   Cabrillo path reaches the same window but only after the station-information
   form, which is modal and cannot be dismissed from out here.

   ASSERTING ON THE LOG, for the reason the other harnesses here do: the window
   is MODAL, so it blocks the main thread the moment it opens, and a
   cross-process read of a TMemo's text is not available anyway. HandleShow
   reports the line count and the file.

   REQUIRES DEBUG LOGGING; passes -ExtraArgs DEBUG so it does not depend on the
   operator's DEBUG LOG LEVEL.

   .\Test-FileViewer.ps1
#>

param(
   [string] $Repo = (Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent),
   [string] $Exe,
   [string] $Config,
   # A score-by-hour report over a real corpus log is dozens of lines. The floor
   # is deliberately well above 0 and well below the real count: 0 is the
   # regression (an empty viewer), and pinning the exact number would make this
   # test fail whenever the report's layout changes, which is not what it is
   # watching.
   [int]    $MinLines = 10,
   [int]    $MinFloorWidth  = 400,
   [int]    $MinFloorHeight = 240,
   [int]    $SettleMs = 8000,
   [int]    $OpenMs   = 3000
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'UiDriver.psm1') -Force

# VC.pas:2500.
$MENU_SCORE_BY_HOUR = 10005

$target = Join-Path $Repo 'tr4w\target'
$Exe    = Resolve-TR4WExe -Exe $Exe -Repo $Repo

$cfg = Resolve-TR4WHarnessConfig -Repo $Repo -TargetDir $target -Config $Config -Caller 'Test-FileViewer'
if ($cfg.Message) { Write-Output "Test-FileViewer: $($cfg.Message)" }
if ($cfg.Failure)
   {
   Write-Output "Test-FileViewer: $($cfg.Failure)"
   exit 1
   }
$Config = $cfg.Config

try { Assert-NoRunningTR4W } catch { Write-Output "Test-FileViewer: $_"; exit 1 }

$log  = Join-Path $target 'tr4w.log'
$mark = Get-TR4WLogMark -LogPath $log

$started = Start-TR4WForDriving -Exe $Exe -TargetDir $target `
                                -ConfigPath (Join-Path $target $Config) `
                                -SettleMs $SettleMs -ExtraArgs 'DEBUG'
if ($started.Failure) { Write-Output "Test-FileViewer: $($started.Failure)"; exit 1 }

$rc = 0

try
{
   Send-TR4WMenuCommand -Hwnd $started.Hwnd -Command $MENU_SCORE_BY_HOUR
   Start-Sleep -Milliseconds $OpenMs

   $written = Get-TR4WLogSince -LogPath $log -Mark $mark
   $hits = @($written -split "`n" |
             Where-Object { $_ -match '\[FileView\] (\d+) line\(s\), cabrillo=(\w+), file=(.*)$' } |
             ForEach-Object {
                [pscustomobject]@{ Lines = [int]$Matches[1]; Cabrillo = $Matches[2]
                                   File = $Matches[3].Trim() }
             })

   if ($hits.Count -eq 0)
      {
      Write-Output 'Test-FileViewer: FAIL -- the viewer never reported opening.'
      Write-Output '  Either the report did not run, or FilePreview no longer reaches the'
      Write-Output '  window -- which is the regression this test exists for.'
      $rc = 1
      }
   else
      {
      $last = $hits[-1]
      Write-Output ("  {0} line(s), cabrillo={1}" -f $last.Lines, $last.Cabrillo)
      Write-Output ("  file: {0}" -f $last.File)

      if ($last.Lines -lt $MinLines)
         {
         Write-Output "Test-FileViewer: FAIL -- $($last.Lines) line(s), expected at least $MinLines."
         Write-Output '  A viewer that opens empty makes every export look like it produced nothing.'
         $rc = 1
         }
      }

   # --- and it must not be shrinkable into uselessness ------------------------
   # Found by title, and the title IS the file being shown, so this doubles as a
   # check that the caption was assigned.
   $win = Find-TR4WWindowByTitle -ProcessId $started.Process.Id `
                                 -Title (Split-Path $target -Qualifier) -Exclude $started.Hwnd
   if ($win -eq [IntPtr]::Zero)
      {
      Write-Output 'Test-FileViewer: FAIL -- no window titled with a file path was found.'
      Write-Output '  The viewer titles itself with the file it is showing.'
      $rc = 1
      }
   else
      {
      $floor = Measure-TR4WWindowFloor -Hwnd $win
      if ($null -eq $floor)
         {
         Write-Output 'Test-FileViewer: FAIL -- GetWindowRect failed on the viewer.'
         $rc = 1
         }
      else
         {
         Write-Output ("  smallest it will go: {0} x {1}" -f $floor.Width, $floor.Height)
         if (($floor.Width -lt $MinFloorWidth) -or ($floor.Height -lt $MinFloorHeight))
            {
            Write-Output ("Test-FileViewer: FAIL -- shrank to {0} x {1}, expected no smaller than {2} x {3}." -f `
                          $floor.Width, $floor.Height, $MinFloorWidth, $MinFloorHeight)
            $rc = 1
            }
         }
      }

   if ($rc -eq 0)
      {
      Write-Output 'Test-FileViewer: PASS -- the report opened in the viewer, and it has a floor.'
      }
}
finally
{
   # Modal: it cannot be closed from out here, so the process goes.
   Stop-TR4WForDriving -Process $started.Process
}

exit $rc
