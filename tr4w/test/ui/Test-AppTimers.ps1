<#
.SYNOPSIS
   The one-second timer is actually ticking.

.DESCRIPTION
   WHY THIS EXISTS. TR4W's four periodic timers were Win32 SetTimer calls
   against tr4whandle, the main form's HWND, with WNDPROC-style callbacks. They
   are LCL TTimers now (src\ui\lcl\uAppTimers.pas), which is what lets them
   exist off Windows at all -- SetTimer and TIMERPROC have no GTK or Cocoa
   equivalent.

   A TIMER THAT SILENTLY STOPS LOOKS EXACTLY LIKE A WORKING PROGRAM. Nothing
   fails, nothing logs, no test notices: the clock simply freezes, the rate
   display stops moving, and an operator finds out mid-contest. That is the
   whole reason for driving a real binary here.

   HOW IT PROVES IT. The one-second tick calls UpdateTimeAndRateDisplays, which
   writes TR4WMainForm.pnlFullTime.Caption. A TPanel is a windowed control, so
   the caption is readable from outside the process: sample every captioned
   child, wait, sample again, and require that something changed. The clock is
   the only thing on that form that changes on its own with no operator and no
   radio, which is what makes the assertion safe rather than flaky.

   WHAT IT DOES NOT COVER. The other three timers -- auto-CQ, the 30-second
   quick-display clear, and the 250 ms multi-op CW status -- need a contest in
   progress, a keyer, or a network peer. Their conversion shares this one's
   mechanism, so a failure here almost certainly means all four are dead; a
   pass here does not prove those three individually.
#>

param(
   # An existing .cfg in tr4w\target. Empty stages one from the corpus.
   [string] $Config,
   # How long to wait between samples. Must be more than one second.
   [int] $GapSeconds = 4
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot 'UiDriver.psm1') -Force

$repo      = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
$targetDir = Join-Path $repo 'tr4w\target'

if ($GapSeconds -lt 2)
   {
   Write-Host 'Test-AppTimers: -GapSeconds must be at least 2' -ForegroundColor Red
   exit 2
   }

function Get-CaptionedChildren
{
   param([System.IntPtr] $Parent)

   $script:appTimerTexts = @{}
   $cb = [Win32.UiDrv+EnumChildProc]{
      param($c, $l)
      $sb = New-Object System.Text.StringBuilder 256
      [void][Win32.UiDrv]::GetWindowTextW($c, $sb, 256)
      $t = $sb.ToString()
      if ($t)
         {
         $script:appTimerTexts[[string]$c] = $t
         }
      return $true
   }
   [void][Win32.UiDrv]::EnumChildWindows($Parent, $cb, [IntPtr]::Zero)
   return $script:appTimerTexts
}

Assert-NoRunningTR4W

$exe = Resolve-TR4WExe -Repo $repo
$cfg = Resolve-TR4WHarnessConfig -Repo $repo -TargetDir $targetDir -Config $Config `
                                 -Caller 'Test-AppTimers'
if ($cfg.Failure)
   {
   Write-Host "Test-AppTimers: $($cfg.Failure)" -ForegroundColor Red
   exit 2
   }
if ($cfg.Message)
   {
   Write-Host "Test-AppTimers: $($cfg.Message)"
   }

$run = Start-TR4WForDriving -Exe $exe -TargetDir $targetDir -ConfigPath $cfg.Path
if ($run.Failure)
   {
   Write-Host "Test-AppTimers: $($run.Failure)" -ForegroundColor Red
   Stop-TR4WForDriving -Process $run.Process
   exit 2
   }

try
   {
   # Settle past a second boundary before the first sample, so a slow start-up
   # cannot be mistaken for a stopped clock.
   Start-Sleep -Seconds 2
   $before = Get-CaptionedChildren -Parent $run.Hwnd
   Start-Sleep -Seconds $GapSeconds
   $after  = Get-CaptionedChildren -Parent $run.Hwnd
   }
finally
   {
   Stop-TR4WForDriving -Process $run.Process
   if ($cfg.Staged)
      {
      Remove-Item (Join-Path $targetDir 'uitest.cfg') -ErrorAction SilentlyContinue
      Remove-Item (Join-Path $targetDir 'uitest.trw') -ErrorAction SilentlyContinue
      }
   }

$changed = @()
foreach ($k in $before.Keys)
   {
   if ($after.ContainsKey($k) -and ($before[$k] -ne $after[$k]))
      {
      $changed += ("  {0}  ->  {1}" -f $before[$k], $after[$k])
      }
   }

Write-Host ("Test-AppTimers: sampled {0} captioned control(s), {1} s apart" -f $before.Count, $GapSeconds)

if ($before.Count -eq 0)
   {
   Write-Host 'Test-AppTimers: INCONCLUSIVE -- no captioned children found at all;' -ForegroundColor Yellow
   Write-Host '  the window tree is not what this expects, so nothing was tested.' -ForegroundColor Yellow
   exit 2
   }

if ($changed.Count -eq 0)
   {
   Write-Host 'Test-AppTimers: FAILED -- nothing on the main window changed.' -ForegroundColor Red
   Write-Host '  The one-second timer is not firing: uAppTimers atOneSecond, started' -ForegroundColor Red
   Write-Host '  in uProgramMain, calling MainUnit.OneSecondTick.' -ForegroundColor Red
   exit 1
   }

Write-Host 'Test-AppTimers: PASS -- the one-second tick is updating the display'
$changed | ForEach-Object { Write-Host $_ }
exit 0
