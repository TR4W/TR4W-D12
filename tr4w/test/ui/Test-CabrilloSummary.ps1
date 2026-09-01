<#
.SYNOPSIS
   Opens the Cabrillo station-information window and asserts that it built its
   rows, filled its drop-downs, and refuses to shrink past its content.

.DESCRIPTION
   WRITTEN BECAUSE THE PREVIOUS CONVERSION FAILED EXACTLY THIS WAY. Alt-P became
   a designed form and opened with the right title, the right three columns and
   NOT ONE ROW: removing the Win32 dialog proc removed the WM_INITDIALOG call
   that filled it, and nothing else noticed. This window is the same shape of
   risk and worse -- twenty-one rows and nine drop-downs, all built in code.

   Nothing else in the tree can see that. The corpus reads exported files (and
   it does cover this window's OTHER half: headless /EXPORT reads the same
   header through uCbrSum.CabrilloTagText with the window closed). The unit
   tests cannot construct a form. The lints check that handlers are wired, not
   that anything calls them.

   ASSERTING ON THE LOG, because the window is MODAL -- it blocks the main
   thread the moment it opens, and a cross-process read of a TComboBox's items
   is not available anyway. HandleShow reports what it built.

   THE MINIMUM SIZE IS CHECKED THE SAME WAY Alt-P's is, by asking the live
   window how small it will go. A form whose content is built in code has no
   designer geometry to fall back on, so this is the only version of that
   question worth asking.

   THE WINDOW IS MODAL AND IS NOT DISMISSED. Once ShowModal runs the program
   stops pumping the main window's queue, so a posted close would not be seen.
   The run reads the log and then kills the process, which is what
   Stop-TR4WForDriving does regardless.

   REQUIRES DEBUG LOGGING; passes -ExtraArgs DEBUG so it does not depend on the
   operator's DEBUG LOG LEVEL.

   .\Test-CabrilloSummary.ps1
#>

param(
   [string] $Repo = (Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent),
   [string] $Exe,
   [string] $Config,
   # TWENTY-ONE, the length of CabrilloTags. Not "at least one": a partial
   # build is the failure mode that looks healthy, and a floor of 1 would pass
   # it.
   [int]    $ExpectRows  = 21,
   # EIGHT tags carry a drop-down. Not nine: CategoriesArray has a value list
   # for CATEGORY-TRANSMITTER, but CabrilloTagsArray marks that tag ctrList
   # False, so it is a free-text edit and the five values ONE/TWO/... are never
   # offered. That mismatch is pre-existing and is REPORTED, not fixed -- see
   # the note in PostUnit where SetTransmittersId reads it.
   [int]    $ExpectLists = 8,
   # It must not shrink past its own content. The scroll box states 400 x 220
   # and the button strip is 44 tall, so the smallest client that still shows a
   # usable row is about 400 x 264; the expectations sit under that because the
   # probe reads the WINDOW and the arithmetic is on the CLIENT.
   [int]    $MinFloorWidth  = 380,
   [int]    $MinFloorHeight = 240,
   [int]    $SettleMs = 8000,
   [int]    $OpenMs   = 2500
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'UiDriver.psm1') -Force

# VC.pas:2517. Tools -> Edit Cabrillo Summary, which opens the window with NO
# export action (Issue #914) -- so the harness exercises the window without
# writing a Cabrillo file into the corpus directory as a side effect.
$MENU_EDIT_CABRILLO_SUMMARY = 10022

$target = Join-Path $Repo 'tr4w\target'
$Exe    = Resolve-TR4WExe -Exe $Exe -Repo $Repo

$cfg = Resolve-TR4WHarnessConfig -Repo $Repo -TargetDir $target -Config $Config -Caller 'Test-CabrilloSummary'
if ($cfg.Message) { Write-Output "Test-CabrilloSummary: $($cfg.Message)" }
if ($cfg.Failure)
   {
   Write-Output "Test-CabrilloSummary: $($cfg.Failure)"
   exit 1
   }
$Config = $cfg.Config

try { Assert-NoRunningTR4W } catch { Write-Output "Test-CabrilloSummary: $_"; exit 1 }

$log  = Join-Path $target 'tr4w.log'
$mark = Get-TR4WLogMark -LogPath $log

$started = Start-TR4WForDriving -Exe $Exe -TargetDir $target `
                                -ConfigPath (Join-Path $target $Config) `
                                -SettleMs $SettleMs -ExtraArgs 'DEBUG'
if ($started.Failure) { Write-Output "Test-CabrilloSummary: $($started.Failure)"; exit 1 }

$rc = 0

try
{
   Send-TR4WMenuCommand -Hwnd $started.Hwnd -Command $MENU_EDIT_CABRILLO_SUMMARY
   Start-Sleep -Milliseconds $OpenMs

   $written = Get-TR4WLogSince -LogPath $log -Mark $mark
   $hits = @($written -split "`n" |
             Where-Object { $_ -match '\[CbrSum\] built (\d+) row\(s\), (\d+) list\(s\), (\d+) empty, section=(\S+)' } |
             ForEach-Object {
                [pscustomobject]@{ Rows = [int]$Matches[1]; Lists = [int]$Matches[2]
                                   Empty = [int]$Matches[3]; Section = $Matches[4] }
             })

   if ($hits.Count -eq 0)
      {
      Write-Output 'Test-CabrilloSummary: FAIL -- the window never reported a build.'
      Write-Output '  Either it did not open, or HandleShow was not called -- which is'
      Write-Output '  the exact regression this test exists for.'
      $rc = 1
      }
   else
      {
      $last = $hits[-1]
      Write-Output ("  built {0} row(s), {1} list(s), {2} empty, section={3}" -f `
                    $last.Rows, $last.Lists, $last.Empty, $last.Section)

      if ($last.Rows -ne $ExpectRows)
         {
         Write-Output "Test-CabrilloSummary: FAIL -- $($last.Rows) row(s), expected $ExpectRows."
         $rc = 1
         }
      if ($last.Lists -ne $ExpectLists)
         {
         Write-Output "Test-CabrilloSummary: FAIL -- $($last.Lists) drop-down(s), expected $ExpectLists."
         Write-Output '  A ctrList tag built as an edit cannot offer the sponsor''s categories.'
         $rc = 1
         }
      if ($last.Empty -ne 0)
         {
         Write-Output "Test-CabrilloSummary: FAIL -- $($last.Empty) drop-down(s) have no items."
         Write-Output '  An empty list looks identical to a correct one until it is clicked.'
         $rc = 1
         }
      }

   # --- and it must not be shrinkable into uselessness ------------------------
   $win = Find-TR4WWindowByTitle -ProcessId $started.Process.Id `
                                 -Title 'Station information' -Exclude $started.Hwnd
   if ($win -eq [IntPtr]::Zero)
      {
      Write-Output 'Test-CabrilloSummary: FAIL -- the window could not be found by title.'
      $rc = 1
      }
   else
      {
      $floor = Measure-TR4WWindowFloor -Hwnd $win
      if ($null -eq $floor)
         {
         Write-Output 'Test-CabrilloSummary: FAIL -- GetWindowRect failed on the window.'
         $rc = 1
         }
      else
         {
         Write-Output ("  smallest it will go: {0} x {1}" -f $floor.Width, $floor.Height)
         if (($floor.Width -lt $MinFloorWidth) -or ($floor.Height -lt $MinFloorHeight))
            {
            Write-Output ("Test-CabrilloSummary: FAIL -- shrank to {0} x {1}, expected no smaller than {2} x {3}." -f `
                          $floor.Width, $floor.Height, $MinFloorWidth, $MinFloorHeight)
            $rc = 1
            }
         }
      }

   if ($rc -eq 0)
      {
      Write-Output 'Test-CabrilloSummary: PASS -- rows and lists built, and the window has a floor.'
      }
}
finally
{
   # Modal: it cannot be closed from out here, so the process goes.
   Stop-TR4WForDriving -Process $started.Process
}

exit $rc
