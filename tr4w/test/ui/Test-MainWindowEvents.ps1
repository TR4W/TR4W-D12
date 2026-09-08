<#
.SYNOPSIS
   The three main-window behaviours that stopped being Win32 messages: edge
   snapping, drag-by-body, and closing the program.

.DESCRIPTION
   WHY THIS EXISTS. TR4W used to subclass its own form's HWND and answer nine
   raw messages. All nine are LCL events now, and three of them are things only
   an operator normally exercises:

     WM_WINDOWPOSCHANGING  ->  WMWindowPosChanging (message LM_WINDOWPOSCHANGING)
     WM_LBUTTONDOWN        ->  OnMouseDown
     WM_CLOSE              ->  OnCloseQuery

   Nothing else in the tree can see whether they still work. The compiler is
   happy either way -- an `.lfm` that never wired OnCloseQuery, or a handler
   declared outside the published region so the streamer cannot find it, both
   build clean and both leave a program that cannot be closed. That exact
   failure happened on 2026-08-18 and was found by NY4I on the bench, not by a
   gate.

   THE BODY DRAG IS NOW DRIVEN FOR REAL. It used to hand the drag to the
   system's own move loop (SC_MOVE), which cannot be driven from outside the
   process without seizing the mouse -- so all this could check was that a
   press was SURVIVED. TR4W moves the window itself now, in
   OnMouseDown/Move/Up, and those fire on POSTED messages: down, a few moves,
   up, and the window is expected to have travelled by the offset asked for.

   That is why the handlers convert with ClientToScreen on the event's own
   X,Y rather than reading Mouse.CursorPos -- CursorPos would follow the
   physical pointer, and this test moves no pointer at all.

   WHAT SNAP PROVES. SetWindowPos is an ordinary API call, so it generates a
   real WM_WINDOWPOSCHANGING in the target process; if the handler is not
   reached the window simply lands where it was put. A near-edge move is
   therefore a positive test, and the mid-screen move beside it is the control:
   it fails if the handler snaps things it should leave alone.
#>

param(
   # An existing .cfg in tr4w\target. Empty stages one from the corpus.
   [string] $Config
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot 'UiDriver.psm1') -Force

$repo      = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
$targetDir = Join-Path $repo 'tr4w\target'

$SNAP        = 20        # must match the handler's own constant
# NOZORDER and NOACTIVATE, but NOT NOSIZE -- the size is passed for real.
#
# WM_WINDOWPOSCHANGING's cx and cy are DOCUMENTED AS IGNORED when SWP_NOSIZE is
# set, and an ordinary SetWindowPos(..., 0, 0, SWP_NOSIZE) leaves them zero. The
# handler's far-edge arms need the window's size, so a NOSIZE move cannot
# exercise them at all: the distance comes out a screen width wrong and nothing
# snaps, which looks exactly like a handler that is not being reached. A drag --
# the case these arms exist for -- always carries a real size, so the test
# carries one too.
$SWP_QUIET   = 0x0004 -bor 0x0010
$WM_CLOSE    = 0x0010
$WM_MOUSEMOVE = 0x0200
$WM_LBTNDOWN = 0x0201
$WM_LBTNUP   = 0x0202
$BM_CLICK    = 0x00F5

function Get-Rect
{
   param([System.IntPtr] $Hwnd)
   $r = New-Object Win32.UiDrv+RECT
   if (-not [Win32.UiDrv]::GetWindowRect($Hwnd, [ref]$r))
      {
      throw 'GetWindowRect failed'
      }
   return $r
}

# One mouse message, with the coordinates packed the way Windows packs them.
# wParam carries the button state -- 1 = MK_LBUTTON -- which the LCL reads to
# build the Shift set, and a MOUSEMOVE with no button is how a drag is proved
# to have ENDED.
function Send-Mouse
{
   param([System.IntPtr] $Hwnd, [int] $Msg, [int] $X, [int] $Y, [int] $Button)
   $lp = ($Y -shl 16) -bor ($X -band 0xFFFF)
   [void][Win32.UiDrv]::PostMessageW($Hwnd, $Msg, [IntPtr]$Button, [IntPtr]$lp)
}

function Move-To
{
   param([System.IntPtr] $Hwnd, [int] $X, [int] $Y, [int] $W, [int] $H)
   [void][Win32.UiDrv]::SetWindowPos($Hwnd, [IntPtr]::Zero, $X, $Y, $W, $H, $SWP_QUIET)
   Start-Sleep -Milliseconds 250
   return (Get-Rect -Hwnd $Hwnd)
}

$failures = @()
function Check
{
   param([string] $What, [bool] $Ok, [string] $Detail)
   if ($Ok)
      {
      Write-Host ("  PASS  {0}" -f $What)
      }
   else
      {
      Write-Host ("  FAIL  {0} -- {1}" -f $What, $Detail) -ForegroundColor Red
      $script:failures += $What
      }
}

Assert-NoRunningTR4W

$exe = Resolve-TR4WExe -Repo $repo
$cfg = Resolve-TR4WHarnessConfig -Repo $repo -TargetDir $targetDir -Config $Config `
                                 -Caller 'Test-MainWindowEvents'
if ($cfg.Failure)
   {
   Write-Host "Test-MainWindowEvents: $($cfg.Failure)" -ForegroundColor Red
   exit 2
   }
if ($cfg.Message)
   {
   Write-Host "Test-MainWindowEvents: $($cfg.Message)"
   }

$run = Start-TR4WForDriving -Exe $exe -TargetDir $targetDir -ConfigPath $cfg.Path
if ($run.Failure)
   {
   Write-Host "Test-MainWindowEvents: $($run.Failure)" -ForegroundColor Red
   Stop-TR4WForDriving -Process $run.Process
   exit 2
   }

$hwnd = $run.Hwnd
$logPath = Join-Path $targetDir 'tr4w.log'
$mark = Get-TR4WLogMark -LogPath $logPath

try
   {
   $before = Get-Rect -Hwnd $hwnd
   $w = $before.R - $before.L
   $h = $before.B - $before.T

   # ---------------------------------------------------------------- the control
   #
   # THE POSITION IS COMPUTED, NOT HARDCODED, AND THAT IS THE POINT OF THE
   # FIX. It used to ask for 300,220 and assert the window stayed -- but
   # whether 220 is "mid-screen" depends on the WINDOW HEIGHT and the work
   # area, and on a 1032-tall work area with an 806-tall window the far-edge
   # snap target is 226. So 220 was SIX PIXELS INSIDE the bottom snap band,
   # the handler correctly pulled it to 226, and the control case reported a
   # regression in working code (2026-09-07).
   #
   # Centred instead, which is clear of all four bands by construction for any
   # window that fits on the screen at all.
   Add-Type -AssemblyName System.Windows.Forms
   $wa0 = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea
   $ctlX = [int](($wa0.Left + $wa0.Right - $w) / 2)
   $ctlY = [int](($wa0.Top + $wa0.Bottom - $h) / 2)
   $r = Move-To -Hwnd $hwnd -X $ctlX -Y $ctlY -W $w -H $h
   Check 'a mid-screen move is left alone' `
         (($r.L -eq $ctlX) -and ($r.T -eq $ctlY)) `
         ("asked for $ctlX,$ctlY and got $($r.L),$($r.T) -- window ${w}x${h}, " +
          "work area $($wa0.Left),$($wa0.Top)..$($wa0.Right),$($wa0.Bottom)")

   # ------------------------------------------------------- snap to left and top
   $r = Move-To -Hwnd $hwnd -X ($SNAP - 5) -Y ($SNAP - 5) -W $w -H $h
   Check 'near the left and top edges it goes flush' `
         (($r.L -eq 0) -and ($r.T -eq 0)) `
         ("asked for $($SNAP - 5),$($SNAP - 5) and got $($r.L),$($r.T)")

   # ------------------------------------------ snap to the work area's far edges
   Add-Type -AssemblyName System.Windows.Forms
   $wa = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea

   $r = Move-To -Hwnd $hwnd -X ($wa.Right - $w - ($SNAP - 5)) -Y ($wa.Bottom - $h - ($SNAP - 5)) -W $w -H $h
   Check 'near the work area right and bottom it goes flush' `
         ((($r.L + $w) -eq $wa.Right) -and (($r.T + $h) -eq $wa.Bottom)) `
         ("right edge $($r.L + $w) vs $($wa.Right), bottom $($r.T + $h) vs $($wa.Bottom)")

   # ------------------------------------------------- a press that is NOT a drag
   #
   # The control for the drag below: down and up at the same point must leave
   # the window exactly where it was. A handler that moves on the press alone
   # passes a drag test and fails this one.
   $r = Move-To -Hwnd $hwnd -X 300 -Y 220 -W $w -H $h
   Send-Mouse -Hwnd $hwnd -Msg $WM_LBTNDOWN -X 40 -Y 40 -Button 1
   Send-Mouse -Hwnd $hwnd -Msg $WM_LBTNUP   -X 40 -Y 40 -Button 0
   Start-Sleep -Milliseconds 400
   if ($run.Process.HasExited)
      {
      Check 'a left-button press on the body is survived' $false `
            "the process died, exit code $($run.Process.ExitCode)"
      }
   else
      {
      $r2 = Get-Rect -Hwnd $hwnd
      Check 'a press with no movement does not move the window' `
            (($r2.L -eq $r.L) -and ($r2.T -eq $r.T)) `
            "the window moved to $($r2.L),$($r2.T) with nobody dragging it"
      }

   # ------------------------------------------------------- dragging by the body
   #
   # Mid-screen, and a distance well clear of SNAP in both directions, so this
   # measures the drag and nothing else. Several moves rather than one, because
   # a handler that only reads the FIRST move looks correct with a single step.
   #
   # THE CLIENT COORDINATE IS COMPENSATED FOR HOW FAR THE WINDOW HAS ALREADY
   # MOVED, AND IT MUST BE. A drag is anchored in SCREEN space: hold the mouse
   # still and the window stops, however far it has travelled. So when the
   # window moves out from under a stationary pointer, the CLIENT coordinate
   # that pointer reports changes by the same amount in the opposite direction
   # -- which is exactly what the handler's ClientToScreen undoes.
   #
   # Posting a fixed client coordinate instead simulates a pointer glued to the
   # window, which no mouse does. It compounds: four steps of 30 px moved the
   # window 30, then 60, then 90, then 120 -- 300 px for a 120 px drag
   # (measured 2026-09-07). That looked like a handler defect and was a test
   # that modelled the wrong thing.
   $DX = 120
   $DY = 90
   $r = Move-To -Hwnd $hwnd -X 400 -Y 300 -W $w -H $h
   if (-not $run.Process.HasExited)
      {
      Send-Mouse -Hwnd $hwnd -Msg $WM_LBTNDOWN -X 60 -Y 60 -Button 1
      foreach ($step in 1..4)
         {
         $now = Get-Rect -Hwnd $hwnd
         Send-Mouse -Hwnd $hwnd -Msg $WM_MOUSEMOVE `
                    -X (60 + [int]($DX * $step / 4) - ($now.L - $r.L)) `
                    -Y (60 + [int]($DY * $step / 4) - ($now.T - $r.T)) -Button 1
         Start-Sleep -Milliseconds 80
         }
      $now = Get-Rect -Hwnd $hwnd
      Send-Mouse -Hwnd $hwnd -Msg $WM_LBTNUP `
                 -X (60 + $DX - ($now.L - $r.L)) `
                 -Y (60 + $DY - ($now.T - $r.T)) -Button 0
      Start-Sleep -Milliseconds 400
      }

   if ($run.Process.HasExited)
      {
      Check 'dragging the body moves the window' $false `
            "the process died, exit code $($run.Process.ExitCode)"
      }
   else
      {
      $r2 = Get-Rect -Hwnd $hwnd
      Check 'dragging the body moves the window by the drag distance' `
            ((($r2.L - $r.L) -eq $DX) -and (($r2.T - $r.T) -eq $DY)) `
            ("asked to move by $DX,$DY and it moved by " +
             "$($r2.L - $r.L),$($r2.T - $r.T)")

      # And the button is released: a further move with no button down must be
      # ignored. A handler that never clears its dragging flag leaves the
      # window following the mouse forever, which is the worst way to find out.
      Send-Mouse -Hwnd $hwnd -Msg $WM_MOUSEMOVE -X 400 -Y 400 -Button 0
      Start-Sleep -Milliseconds 300
      $r3 = Get-Rect -Hwnd $hwnd
      Check 'a move after the button is released does not drag' `
            (($r3.L -eq $r2.L) -and ($r3.T -eq $r2.T)) `
            "the window kept moving after mouse-up, to $($r3.L),$($r3.T)"
      }

   # ------------------------------------------------------------------- the close
   if (-not $run.Process.HasExited)
      {
      [void][Win32.UiDrv]::PostMessageW($hwnd, $WM_CLOSE, [IntPtr]::Zero, [IntPtr]::Zero)

      # ExitProgram asks first. The dialog is QuestionDlg('TR4W', ...), so it is
      # found by title like any other -- excluding the main window, which has the
      # same one.
      $dlg = Find-TR4WWindowByTitle -ProcessId $run.Process.Id -Title 'TR4W' `
                                    -Exclude $hwnd -TimeoutMs 6000
      Check 'closing asks the operator first' `
            ($dlg -ne [IntPtr]::Zero) `
            'no confirmation window appeared -- OnCloseQuery was never called'

      if ($dlg -ne [IntPtr]::Zero)
         {
         # Click Yes rather than posting a keystroke: a default button answers
         # Enter only if something in the dialog has focus, which is not
         # guaranteed for a window this process did not activate.
         $yes = [IntPtr]::Zero
         $cb = [Win32.UiDrv+EnumChildProc]{
            param($c, $l)
            $sb = New-Object System.Text.StringBuilder 256
            [void][Win32.UiDrv]::GetWindowTextW($c, $sb, 256)
            if ($sb.ToString().Replace('&', '') -match '^\s*Yes\s*$')
               {
               $script:yesBtn = $c
               return $false
               }
            return $true
         }
         $script:yesBtn = [IntPtr]::Zero
         [void][Win32.UiDrv]::EnumChildWindows($dlg, $cb, [IntPtr]::Zero)
         $yes = $script:yesBtn

         Check 'the confirmation has a Yes button' `
               ($yes -ne [IntPtr]::Zero) 'no child button reads Yes'

         if ($yes -ne [IntPtr]::Zero)
            {
            [void][Win32.UiDrv]::PostMessageW($yes, $BM_CLICK, [IntPtr]::Zero, [IntPtr]::Zero)
            $gone = $run.Process.WaitForExit(20000)
            Check 'answering Yes exits the program' $gone `
                  'the process was still running 20 s after Yes'
            if ($gone)
               {
               Check 'and it exits cleanly' ($run.Process.ExitCode -eq 0) `
                     "exit code $($run.Process.ExitCode)"
               }
            }
         }
      }
   }
finally
   {
   $tail = Get-TR4WLogSince -LogPath $logPath -Mark $mark
   Stop-TR4WForDriving -Process $run.Process
   if ($cfg.Staged)
      {
      Remove-Item (Join-Path $targetDir 'uitest.cfg') -ErrorAction SilentlyContinue
      Remove-Item (Join-Path $targetDir 'uitest.trw') -ErrorAction SilentlyContinue
      }
   }

if ($failures.Count -gt 0)
   {
   Write-Host ''
   Write-Host ("Test-MainWindowEvents: FAILED -- {0} of the converted behaviours" -f $failures.Count) -ForegroundColor Red
   foreach ($f in $failures)
      {
      Write-Host ("  {0}" -f $f) -ForegroundColor Red
      }
   exit 1
   }

Write-Host ''
Write-Host 'Test-MainWindowEvents: PASS -- snap, press and close all behave as LCL events'
exit 0
