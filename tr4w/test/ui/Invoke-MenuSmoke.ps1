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
#   .\Invoke-MenuSmoke.ps1 -Command 10111,10302  # just these
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

# A SINGLE PERSISTENT HARNESS CONFIG, and it is deliberately never deleted.
#
# These scripts used to stage smoke.cfg / drive.cfg / typing.cfg and remove them
# afterwards.  That corrupted the operator's settings: TR4W records the last
# configuration opened in settings\tr4w.json, so the store ended up naming a
# file the harness had just deleted -- and the open-contest dialog then HID its
# "most recent configuration" button, because that button only appears when the
# recorded file still exists (uNewContest.pas:180).  NY4I found it, 2026-08-18.
#
# One name, left in place, keeps the recorded path valid.

param(
   # Menu ids to post. The default set is deliberately SMALL and stable: the
   # windows most likely to be broken by a form conversion.
   #
   # 10405 (Missing Mults report) was here as "known-doubtful, wants an answer".
   # It got one on 2026-08-29: N4AF commented its menu row out back in 4.37.10,
   # the MULTS window shows the same thing, and the whole report is deleted.
   [int[]]  $Command = @(
      10111,   # Settings -> CAT and CW Keying (ShowPreferences -- the LCL form)
      10302,   # Alt+D dupe check (menu_alt_dupecheck -- LCL form, Phase 4a)
      10101,   # Tools -> Program message (menu_messages -- LCL form, Phase 4a)
      10104,   # LPT ports, Ctrl+Alt+L (menu_lpt -- LCL form, Phase 4b)
      10557,   # Window control, Ctrl+Alt+M (menu_windowsmanager -- LCL form, 4b)
      10416,   # CT1BOH report (menu_ctrl_ct1bohscreen -- LCL form, Phase 4b)
      10551    # Beacon monitor (menu_beaconsmonitor -- LCL form, Phase 4b).
               # NOTE: this one QSYs Radio 1 to 14100 kHz CW on open, as the
               # Win32 dialog also did. Harmless with no radio attached; do
               # not run the smoke suite mid-QSO on a live rig.
   ),
   # Commands that MUST produce a new top-level window.  Surviving is not
   # passing: a program that has stopped acting on its menu entirely survives
   # every command put to it, which is exactly how the 2026-08-18 regression got
   # past this runner and reached the bench.
   [int[]]  $ExpectsWindow = @(10111, 10302, 10101, 10104, 10557, 10416, 10551),
   [string] $Repo = (Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent),
   [string] $Exe,
   # A .cfg already in tr4w\target. Omit to stage one from the golden corpus.
   [string] $Config,
   [int]    $SettleMs = 8000,   # startup: config, CTY.DAT, main window
   [int]    $AfterMs  = 3000,   # time for the command to finish or to fault
   [switch] $KeepLog,
   # Passed to the program after the config path. The sweep in
   # Sweep-TextFit.ps1 uses it for --lang and --textfit; nothing else needs it.
   [string[]] $ExtraArgs = @()
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
$Exe = Resolve-TR4WExe -Exe $Exe -Repo $Repo

if (-not (Test-Path -LiteralPath $Exe))
   {
   Write-Output "Invoke-MenuSmoke: no build at $Exe -- run FullBuild.ps1 first"
   exit 1
   }

# Stage a config from the corpus rather than asking the caller to do it by hand.
# The corpus sets are the only contest data guaranteed present in a fresh clone,
# which is what makes this runnable on a CI runner as well as on the bench.
# This script's guard is now the SHARED one -- see UiDriver.psm1.  It was the
# only copy that had it; lifting it out is what gave the other two scripts a
# readable failure on a fresh clone.
$cfg = Resolve-TR4WHarnessConfig -Repo $Repo -TargetDir $target -Config $Config -Caller 'Invoke-MenuSmoke'
if ($cfg.Message) { Write-Output "Invoke-MenuSmoke: $($cfg.Message)" }
if ($cfg.Failure)
   {
   Write-Output "Invoke-MenuSmoke: $($cfg.Failure)"
   exit 1
   }
$configPath = $cfg.Path

try { Assert-NoRunningTR4W }
catch { Write-Output "Invoke-MenuSmoke: $_"; exit 1 }

$results = @()

foreach ($id in $Command)
   {
   $mark  = Get-TR4WLogMark -LogPath $log
   $start = Start-TR4WForDriving -Exe $Exe -TargetDir $target -ConfigPath $configPath -SettleMs $SettleMs -ExtraArgs $ExtraArgs

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
   # \bRTE\b, not RTE. Unanchored it matches "sta-RTE-d", so every ordinary
   # 'bandscope started' line was reported as a possible fault (2026-08-29:
   # seven notes on a run with nothing wrong). A guard that cries wolf on every
   # green run is one nobody reads on the run that matters.
   elseif ($written -match '(?im)^.*(\bRTE\b|Runtime error|\bEXCEPTION\b|Access violation).*$')
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
