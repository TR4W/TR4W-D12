# Drives the FPC build's MENU from outside the program.
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
#   .\fpc-run-menu.ps1 -Command 10111        # open Preferences
#   .\fpc-run-menu.ps1 -Command 10111 -KeepOpen
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
   [string] $Repo    = 'C:\tr4w-d12',
   [string] $Exe     = 'C:\tr4w-d12\spike\units\app-i386-win32-delphi\tr4w_fpc.exe',
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

$target = Join-Path $Repo 'tr4w\target'
$log    = Join-Path $target 'tr4w.log'

if (-not (Test-Path $Exe))
   {
   Write-Error "No FPC build at $Exe -- run fpc-build-app.ps1 first"
   exit 1
   }

# A second instance dies on the single-instance mutex and would look exactly
# like the crash being investigated.
$stale = Get-Process -Name 'tr4w_fpc', 'tr4w' -ErrorAction SilentlyContinue
if ($stale)
   {
   Write-Error "TR4W is already running (PID $($stale.Id -join ', ')) -- close it first"
   exit 1
   }

# ENUMERATE BY PID, do not FindWindow by class.  Two reasons, and the first is
# not a preference: FindWindowW('TR4W', nil) returns 0 against this program even
# while EnumWindows reports a visible top-level window of exactly that class
# (measured 2026-08-13, 20 s of polling, both the A and W entry points).  The
# second reason stands on its own -- a class-name search would just as happily
# return a DIFFERENT TR4W that happened to be running, and the whole point here
# is to drive the build that was just compiled.
Add-Type -Namespace Win32 -Name U -MemberDefinition @'
public delegate bool EnumWindowsProc(IntPtr h, IntPtr p);
[DllImport("user32.dll")]
public static extern bool EnumWindows(EnumWindowsProc cb, IntPtr p);
[DllImport("user32.dll", CharSet = CharSet.Unicode)]
public static extern int GetClassNameW(IntPtr h, System.Text.StringBuilder s, int n);
[DllImport("user32.dll")]
public static extern int GetWindowThreadProcessId(IntPtr h, out int pid);
[DllImport("user32.dll")]
public static extern bool IsWindowVisible(IntPtr h);
[DllImport("user32.dll")]
public static extern bool PostMessageW(IntPtr hWnd, uint msg, IntPtr wp, IntPtr lp);
'@

function Find-MainWindow([int] $ProcessId)
   {
   $found = [IntPtr]::Zero
   $cb = [Win32.U+EnumWindowsProc]{
      param($h, $l)
      $owner = 0
      [void][Win32.U]::GetWindowThreadProcessId($h, [ref]$owner)
      if (($owner -eq $ProcessId) -and [Win32.U]::IsWindowVisible($h))
         {
         $cls = New-Object System.Text.StringBuilder 256
         [void][Win32.U]::GetClassNameW($h, $cls, 256)
         if ($cls.ToString() -eq 'TR4W')
            {
            $script:found = $h
            return $false
            }
         }
      return $true
   }
   $script:found = [IntPtr]::Zero
   [void][Win32.U]::EnumWindows($cb, [IntPtr]::Zero)
   return $script:found
   }

$logMark = if (Test-Path $log) { (Get-Item $log).Length } else { 0 }

if (-not (Test-Path (Join-Path $target $Config)))
   {
   Write-Error "No config at $(Join-Path $target $Config) -- see the header"
   exit 1
   }

# PASS AN ABSOLUTE PATH.  TR4W copies this argument into TR4W_CFG_FILENAME with
# lstrcpyA and never expands it (tr4w.dpr ~881), and FCONTEST then derives
# TR4W_LOG_PATH_NAME from it by scanning backwards for a '\'.  Given a bare
# relative name there is no '\' to find, so what should be a DIRECTORY ends up
# as the base name and every path built from it is wrong -- the reports file
# lands as "uidriveNY4I.LOG" instead of "NY4I.LOG", and CTY.DAT, TRMASTER.DTA,
# SERVERLOG.TMP and the rest are mis-derived the same way.  Measured both ways
# 2026-08-13.  The underlying fragility is TR4W's and pre-dates FPC; passing a
# full path here keeps the harness from manufacturing bug reports.
$configPath = Join-Path $target $Config
$proc = Start-Process -FilePath $Exe -WorkingDirectory $target `
                      -ArgumentList $configPath -PassThru
Write-Host "launched PID $($proc.Id) from $target with $configPath"

# Poll for the window rather than sleeping a fixed time -- startup cost varies
# with CTY.DAT and the log size, and a fixed wait either wastes time or posts
# into a window that does not exist yet.
$hwnd    = [IntPtr]::Zero
$deadline = (Get-Date).AddMilliseconds($SettleMs)
while ((Get-Date) -lt $deadline)
   {
   if ($proc.HasExited)
      {
      Write-Host "DIED during startup -- exit code $($proc.ExitCode)"
      exit 1
      }
   $hwnd = Find-MainWindow $proc.Id
   if ($hwnd -ne [IntPtr]::Zero)
      {
      break
      }
   Start-Sleep -Milliseconds 100
   }

if ($hwnd -eq [IntPtr]::Zero)
   {
   Write-Host 'FAIL: main window never appeared'
   if (-not $proc.HasExited)
      {
      $proc.Kill()
      }
   exit 1
   }

Write-Host ("main window 0x{0:X} -- posting WM_COMMAND {1}" -f [int64]$hwnd, $Command)
[void][Win32.U]::PostMessageW($hwnd, 0x0111, [IntPtr]$Command, [IntPtr]::Zero)

Start-Sleep -Milliseconds $AfterMs

$alive = -not $proc.HasExited
if ($alive)
   {
   Write-Host "ALIVE after command $Command"
   }
else
   {
   Write-Host "DIED after command $Command -- exit code $($proc.ExitCode)"
   }

# Only the lines this run added.  tr4w.log is a rolling file that accumulates
# across sessions, and tailing a fixed number of lines has already shown a
# previous run's error as if it were this one's.
if (Test-Path $log)
   {
   $fs = [System.IO.File]::Open($log, 'Open', 'Read', 'ReadWrite')
   try
      {
      if ($fs.Length -gt $logMark)
         {
         [void]$fs.Seek($logMark, 'Begin')
         $reader = New-Object System.IO.StreamReader($fs)
         $new = $reader.ReadToEnd()
         Write-Host ''
         Write-Host '=== log written by this run ==='
         Write-Host $new
         }
      else
         {
         Write-Host ''
         Write-Host '(no new log output)'
         }
      }
   finally
      {
      $fs.Dispose()
      }
   }

if ($alive -and -not $KeepOpen)
   {
   $proc.Kill()
   $proc.WaitForExit(5000) | Out-Null
   }

if (-not $alive)
   {
   exit 1
   }
