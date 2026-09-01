<#
.SYNOPSIS
   Opens the Alt-P programmable-message window in the running program and
   asserts it actually has rows in it.

.DESCRIPTION
   WRITTEN BECAUSE THE CONVERSION FAILED EXACTLY THIS WAY. uAltP became a
   designed form (uAltPForm) and the window opened with the right title, the
   right three columns and NOT ONE ROW: removing the Win32 dialog proc removed
   the WM_INITDIALOG call that filled it, and nothing else noticed. Everything
   visible was correct, which is what made it read as missing data rather than a
   missing call.

   Nothing else in the tree can see that. The corpus reads exported files, the
   unit tests cannot construct a form, and the lints check that handlers are
   wired -- not that anything calls them.

   ASSERTING ON THE LOG, for the reason the other harnesses here do: the window
   is MODAL, so it blocks the main thread the moment it opens, and a
   cross-process read of a TListView's items is not available anyway.
   DisplaymessagesList reports what it built.

   THE WINDOW IS MODAL AND IS NOT DISMISSED. Once ShowModal runs, the program
   stops pumping the main window's queue, so a posted close would not be seen.
   The run reads the log and then kills the process, which is what
   Stop-TR4WForDriving does regardless.

   REQUIRES DEBUG LOGGING; passes -ExtraArgs DEBUG so it does not depend on the
   operator's DEBUG LOG LEVEL.

   .\Test-AltPWindow.ps1
   .\Test-AltPWindow.ps1 -MinRows 36
#>

param(
   [string] $Repo = (Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent),
   [string] $Exe,
   [string] $Config,
   # TWELVE, because the window shows ONE BANK of function keys -- F1..F12,
   # Control F1..F12 or Alt F1..F12 (NY4I, 2026-08-31: the Control and Alt
   # banks are rarely programmed and made a 36-row list of mostly empties).
   # A floor of 1 would still pass if the filter broke and produced one row,
   # so the floor is the bank size. The 'other messages' window is not a bank
   # and builds 9 or 13; pass -MinRows for that.
   [int]    $MinRows  = 12,
   [int]    $SettleMs = 8000,
   [int]    $OpenMs   = 2500
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'UiDriver.psm1') -Force

# VC.pas:2577. By id, not by walking the menu -- the id is stable and the menu
# text is translated.
$MENU_ALT_P = 10317

$target = Join-Path $Repo 'tr4w\target'
$Exe    = Resolve-TR4WExe -Exe $Exe -Repo $Repo

$cfg = Resolve-TR4WHarnessConfig -Repo $Repo -TargetDir $target -Config $Config -Caller 'Test-AltPWindow'
if ($cfg.Message) { Write-Output "Test-AltPWindow: $($cfg.Message)" }
if ($cfg.Failure)
   {
   Write-Output "Test-AltPWindow: $($cfg.Failure)"
   exit 1
   }
$Config = $cfg.Config

try { Assert-NoRunningTR4W } catch { Write-Output "Test-AltPWindow: $_"; exit 1 }

$log  = Join-Path $target 'tr4w.log'
$mark = Get-TR4WLogMark -LogPath $log

$started = Start-TR4WForDriving -Exe $Exe -TargetDir $target `
                                -ConfigPath (Join-Path $target $Config) `
                                -SettleMs $SettleMs -ExtraArgs 'DEBUG'
if ($started.Failure) { Write-Output "Test-AltPWindow: $($started.Failure)"; exit 1 }

$rc = 0

try
{
   Send-TR4WMenuCommand -Hwnd $started.Hwnd -Command $MENU_ALT_P
   Start-Sleep -Milliseconds $OpenMs

   $written = Get-TR4WLogSince -LogPath $log -Mark $mark
   $hits = @($written -split "`n" |
             Where-Object { $_ -match '\[AltP\] filled (\d+) row\(s\), window=(\d+) mode=(\d+), selecting (-?\d+)' } |
             ForEach-Object {
                [pscustomobject]@{ Rows = [int]$Matches[1]; Window = $Matches[2]
                                   Mode = $Matches[3]; Selected = [int]$Matches[4] }
             })

   if ($hits.Count -eq 0)
      {
      Write-Output 'Test-AltPWindow: FAIL -- the window never reported a fill.'
      Write-Output '  Either Alt-P did not open, or DisplaymessagesList was not called --'
      Write-Output '  which is the exact regression this test exists for.'
      $rc = 1
      }
   else
      {
      $last = $hits[-1]
      Write-Output ("  filled {0} row(s), window={1} mode={2}, selection={3}" -f `
                    $last.Rows, $last.Window, $last.Mode, $last.Selected)

      if ($last.Rows -lt $MinRows)
         {
         Write-Output "Test-AltPWindow: FAIL -- $($last.Rows) row(s), expected at least $MinRows."
         Write-Output '  The window opens with its columns and title correct and no data.'
         $rc = 1
         }
      else
         {
         Write-Output "Test-AltPWindow: PASS -- Alt-P opened with $($last.Rows) row(s)."
         }
      }
}
finally
{
   # Modal: it cannot be closed from out here, so the process goes.
   Stop-TR4WForDriving -Process $started.Process
}

exit $rc
