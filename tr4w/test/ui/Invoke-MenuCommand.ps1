# Drives the FPC build's MENU from outside the program -- ONE command.
#
# The golden corpus and the unit tests are both blind to the UI -- the corpus
# runs the headless /EXPORT path and never creates a window -- so a GUI defect
# in the LCL port can only be found by running the program and operating it.
# This does the operating: launch, wait for the main window, post one
# WM_COMMAND, then report whether the process survived and what it logged.
#
# ALWAYS BY CONTROL ID, never by clicking a screen position: an id is the same
# under Delphi and under FPC, which is what makes the two builds comparable
# window by window.
#
#   .\Invoke-MenuCommand.ps1 -Command 10111 -Config drive.cfg
#   .\Invoke-MenuCommand.ps1 -Command 10111 -Config drive.cfg -KeepOpen
#
# For a LIST of commands as a per-phase gate, use Invoke-MenuSmoke.ps1, which
# stages its own config. The launch, window search and log slicing they share
# live in UiDriver.psm1 -- one behaviour, two front ends. They were duplicated
# briefly and that is exactly what the module exists to prevent.
#
# A CONFIG FILE IS REQUIRED, and this is not an accident of the script: with no
# argument TR4W stops on the "Open configuration file or start a new contest"
# dialog and the main window -- the one that owns the menu -- is never created.
# There is nothing to post a WM_COMMAND to until a contest is open.
#
# The exit status answers one question -- did the program still exist after the
# command -- because the fault this was written for (RTE 217 on Preferences)
# killed the process rather than raising anything the program could see.

param(
   [Parameter(Mandatory = $true)]
   [int]    $Command,
   [string] $Repo = (Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent),
   # Defaults to the binary FullBuild.ps1 produces. Derived from this script's
   # own location so a clone anywhere works without arguments.
   # EMPTY BY DEFAULT, resolved below. It used to name target\tr4w.exe outright
   # -- the SHIPPED binary, not the one just built -- which is the defect fixed
   # in the rest of the harness by 50ec17ba and missed here. A menu test driving
   # last month's install proves nothing about the tree.
   [string] $Exe = '',
   # NO DEFAULT ON PURPOSE.  This needs a contest config, and TR4W will not
   # create the main window without one -- it stops on the "Open configuration
   # file or start a new contest" dialog, and there is nothing to drive.
   # Any .cfg in tr4w\target works; a corpus set is the easy source:
   #     cp tr4w/test/corpus/cqww_ssb_2025_ny4i/log.cfg tr4w/target/drive.cfg
   #     cp tr4w/test/corpus/cqww_ssb_2025_ny4i/log.trw tr4w/target/drive.trw
   [Parameter(Mandatory = $true)]
   [string] $Config,
   [int]    $SettleMs = 4000,   # startup: config, CTY.DAT, main window
   [int]    $AfterMs  = 3000,   # time for the command to finish or to fault
   [switch] $KeepOpen
)

Import-Module (Join-Path $PSScriptRoot 'UiDriver.psm1') -Force

$target = Join-Path $Repo 'tr4w\target'
$log    = Join-Path $target 'tr4w.log'

$Exe = Resolve-TR4WExe -Exe $Exe -Repo $Repo
if (-not (Test-Path $Exe))
   {
   Write-Error "No FPC build at $Exe -- run FullBuild.ps1 first"
   exit 1
   }

# A second instance dies on the single-instance mutex and would look exactly
# like the crash being investigated.
try { Assert-NoRunningTR4W }
catch { Write-Error "$_"; exit 1 }

$logMark = Get-TR4WLogMark -LogPath $log

if (-not (Test-Path (Join-Path $target $Config)))
   {
   Write-Error "No config at $(Join-Path $target $Config) -- see the header"
   exit 1
   }

# An ABSOLUTE path -- see Start-TR4WForDriving in UiDriver.psm1 for why a bare
# relative name mis-derives every path TR4W builds from it.
$configPath = Join-Path $target $Config
$started = Start-TR4WForDriving -Exe $Exe -TargetDir $target -ConfigPath $configPath -SettleMs $SettleMs
Write-Host "launched PID $($started.Process.Id) from $target with $configPath"

if ($started.Failure)
   {
   Write-Host "FAIL: $($started.Failure)"
   Stop-TR4WForDriving -Process $started.Process
   exit 1
   }

Write-Host ("main window 0x{0:X} -- posting WM_COMMAND {1}" -f [int64]$started.Hwnd, $Command)
Send-TR4WMenuCommand -Hwnd $started.Hwnd -Command $Command

Start-Sleep -Milliseconds $AfterMs

$alive = -not $started.Process.HasExited
if ($alive)
   {
   Write-Host "ALIVE after command $Command"
   }
else
   {
   Write-Host "DIED after command $Command -- exit code $($started.Process.ExitCode)"
   }

# Only the lines this run added.  tr4w.log is a rolling file that accumulates
# across sessions, and tailing a fixed number of lines has already shown a
# previous run's error as if it were this one's.
$written = Get-TR4WLogSince -LogPath $log -Mark $logMark
if ($written)
   {
   Write-Host ''
   Write-Host '=== log written by this run ==='
   Write-Host $written
   }
else
   {
   Write-Host ''
   Write-Host '(no new log output)'
   }

if ($alive -and -not $KeepOpen)
   {
   Stop-TR4WForDriving -Process $started.Process
   }

if (-not $alive)
   {
   exit 1
   }
