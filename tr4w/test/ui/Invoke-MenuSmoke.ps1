# The per-phase GUI gate for the Win32-to-LCL migration.
#
# Posts a list of WM_COMMAND ids at the running program and asserts it survives
# each one. That is a low bar deliberately: the corpus and the unit tests are
# blind to the UI -- the corpus runs the headless /EXPORT path and never creates
# a window -- so "the program is still alive after opening this window" is the
# first thing worth automating, and it is exactly the fault class the LCL port
# produces (an exception escaping into the main loop is a bare RTE with no class
# under FPC, and it kills the contest log).
#
# THIS DOES NOT LOOK AT THE WINDOW. It cannot tell you a form is laid out right,
# or that a control is missing. Pair it with Dump-WindowTree.ps1 for geometry and
# with an eye diff for anything painted. Say so when quoting a green run.
#
#   .\Invoke-MenuSmoke.ps1                       # the default id set
#   .\Invoke-MenuSmoke.ps1 -Command 10111,10405  # just these
#   .\Invoke-MenuSmoke.ps1 -KeepLog              # print each run's log output
#
# ONE PROCESS PER COMMAND, on purpose. Most of these ids open a MODAL dialog, and
# a second WM_COMMAND posted while a modal loop is pumping would be dispatched
# into the main window anyway -- opening a nested dialog and reporting a failure
# that belongs to the harness. Isolation costs ~6 s per id and makes every result
# attributable.
#
# A CONFIG IS REQUIRED and this script will make one: with no contest open TR4W
# stops on the "Open configuration file or start a new contest" dialog and the
# main window -- the one that owns the menu -- is never created. -Config uses an
# existing file instead; otherwise a corpus set is staged into target\ as
# smoke.cfg / smoke.trw.

param(
   # Menu ids to post. The default set is deliberately SMALL and stable: the
   # windows most likely to be broken by a form conversion, plus one that is
   # known-doubtful and wants an answer (10405 -- see below).
   [int[]]  $Command = @(
      10111,   # Settings -> CAT and CW Keying (ShowPreferences -- the LCL form)
      10405    # Tools -> Missing Mults report (menu_ctrl_missmultsreport)
   ),
   # Commands that MUST produce a new top-level window.  Surviving is not
   # passing: a program that has stopped acting on its menu entirely survives
   # every command put to it, which is exactly how the 2026-08-18 regression got
   # past this runner and reached the bench.
   [int[]]  $ExpectsWindow = @(10111),
   [string] $Repo = (Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent),
   [string] $Exe,
   # A .cfg already in tr4w\target. Omit to stage one from the golden corpus.
   [string] $Config,
   [int]    $SettleMs = 8000,   # startup: config, CTY.DAT, main window
   [int]    $AfterMs  = 3000,   # time for the command to finish or to fault
   [switch] $KeepLog
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot 'UiDriver.psm1') -Force

Add-Type -Namespace Win32 -Name Smoke -MemberDefinition @'
public delegate bool EnumProc(System.IntPtr h, System.IntPtr p);
[DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc cb, System.IntPtr p);
[DllImport("user32.dll")] public static extern int GetWindowThreadProcessId(System.IntPtr h, out int pid);
[DllImport("user32.dll")] public static extern bool IsWindowVisible(System.IntPtr h);
'@

# Visible top-level windows belonging to one process. The COUNT is the check:
# a command that is supposed to open something must increase it.
function Get-VisibleTopLevelCount
{
   param([int] $ProcessId)
   $script:smokeCount = 0
   $cb = [Win32.Smoke+EnumProc]{
      param($h, $l)
      $owner = 0
      [void][Win32.Smoke]::GetWindowThreadProcessId($h, [ref]$owner)
      if (($owner -eq $ProcessId) -and [Win32.Smoke]::IsWindowVisible($h)) { $script:smokeCount++ }
      return $true
   }
   [void][Win32.Smoke]::EnumWindows($cb, [IntPtr]::Zero)
   return $script:smokeCount
}

$target = Join-Path $Repo 'tr4w\target'
$log    = Join-Path $target 'tr4w.log'
if (-not $Exe) { $Exe = Join-Path $target 'tr4w.exe' }

if (-not (Test-Path -LiteralPath $Exe))
   {
   Write-Output "Invoke-MenuSmoke: no build at $Exe -- run FullBuild.ps1 first"
   exit 1
   }

# Stage a config from the corpus rather than asking the caller to do it by hand.
# The corpus sets are the only contest data guaranteed present in a fresh clone,
# which is what makes this runnable on a CI runner as well as on the bench.
if (-not $Config)
   {
   $set = Join-Path $Repo 'tr4w\test\corpus\cqww_ssb_2025_ny4i'
   if (-not (Test-Path -LiteralPath (Join-Path $set 'log.cfg')))
      {
      Write-Output "Invoke-MenuSmoke: no corpus set at $set to stage a config from -- pass -Config"
      exit 1
      }
   Copy-Item (Join-Path $set 'log.cfg') (Join-Path $target 'smoke.cfg') -Force
   Copy-Item (Join-Path $set 'log.trw') (Join-Path $target 'smoke.trw') -Force
   $Config = 'smoke.cfg'
   Write-Output "staged $Config from the corpus set cqww_ssb_2025_ny4i"
   }

$configPath = Join-Path $target $Config
if (-not (Test-Path -LiteralPath $configPath))
   {
   Write-Output "Invoke-MenuSmoke: no config at $configPath"
   exit 1
   }

try { Assert-NoRunningTR4W }
catch { Write-Output "Invoke-MenuSmoke: $_"; exit 1 }

$results = @()

foreach ($id in $Command)
   {
   $mark  = Get-TR4WLogMark -LogPath $log
   $start = Start-TR4WForDriving -Exe $Exe -TargetDir $target -ConfigPath $configPath -SettleMs $SettleMs

   if ($start.Failure)
      {
      # A startup failure is NOT attributable to the command -- say which it is,
      # rather than reporting a window that was never asked to open.
      $results += [pscustomobject]@{ Command = $id; Result = 'STARTUP'; Detail = $start.Failure }
      Stop-TR4WForDriving -Process $start.Process
      continue
      }

   $before = Get-VisibleTopLevelCount -ProcessId $start.Process.Id
   Send-TR4WMenuCommand -Hwnd $start.Hwnd -Command $id
   Start-Sleep -Milliseconds $AfterMs

   if ($start.Process.HasExited)
      {
      $results += [pscustomobject]@{ Command = $id; Result = 'DIED'; Detail = "exit code $($start.Process.ExitCode)" }
      }
   else
      {
      $after = Get-VisibleTopLevelCount -ProcessId $start.Process.Id
      if (($ExpectsWindow -contains $id) -and ($after -le $before))
         {
         # THE ASSERTION THAT MATTERS. Menu commands stopped reaching TR4W at all
         # when the main window became an LCL form -- the LCL delivers a raw
         # HMENU's WM_COMMAND as CN_COMMAND -- and every command still "passed"
         # here because the process was perfectly alive throughout.
         $results += [pscustomobject]@{ Command = $id; Result = 'NO WINDOW'
                                        Detail = "expected a new top-level window; still $after" }
         }
      else
         {
         $results += [pscustomobject]@{ Command = $id; Result = 'ALIVE'
                                        Detail = if ($after -gt $before) { "+$($after - $before) window(s)" } else { '' } }
         }
      }

   $written = Get-TR4WLogSince -LogPath $log -Mark $mark
   if ($KeepLog -and $written)
      {
      Write-Output ''
      Write-Output "=== log written while driving $id ==="
      Write-Output $written
      }
   # An RTE that does NOT kill the process still matters -- report it even when
   # the answer is ALIVE, because a silently-logged fault is the shape this
   # migration produces most.
   elseif ($written -match '(?m)^.*(RTE|Runtime error|EXCEPTION|Access violation).*$')
      {
      Write-Output ("  note: command {0} logged '{1}'" -f $id, $Matches[0].Trim())
      }

   Stop-TR4WForDriving -Process $start.Process
   }

Write-Output ''
$results | Format-Table -AutoSize | Out-String | Write-Output

$bad = @($results | Where-Object { $_.Result -ne 'ALIVE' })
if ($bad.Count -gt 0)
   {
   Write-Output ("Invoke-MenuSmoke: {0} of {1} command(s) did not survive." -f $bad.Count, $results.Count)
   exit 1
   }

Write-Output ("Invoke-MenuSmoke: {0} command(s) survived; the {1} expected to open a window did. Still NOT a check that any window is CORRECT." -f $results.Count, @($ExpectsWindow).Count)
exit 0
