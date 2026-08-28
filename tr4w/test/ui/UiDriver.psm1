# Shared driving of a running TR4W from outside the process.
#
# WHY A MODULE.  Invoke-MenuCommand.ps1 drives ONE menu command; the Win32-to-LCL
# migration needs the same launch/find-window/post/report cycle over a LIST of
# commands, as the per-phase gate. That is one behaviour with two front ends, and
# the alternative -- a second script carrying its own copy of the P/Invoke block,
# the EnumWindows search and the log slicing -- is three copies of the awkward
# parts to keep in step. The single-command script keeps its interface; both call
# in here.
#
# The hard-won details all live below and are documented where they sit:
# enumerate by PID rather than FindWindow, pass an ABSOLUTE config path, and read
# only the log bytes this run appended.

Set-StrictMode -Version Latest

Add-Type -Namespace Win32 -Name UiDrv -MemberDefinition @'
public delegate bool EnumWindowsProc(System.IntPtr h, System.IntPtr p);
[DllImport("user32.dll")]
public static extern bool EnumWindows(EnumWindowsProc cb, System.IntPtr p);
[DllImport("user32.dll", CharSet = CharSet.Unicode)]
public static extern int GetClassNameW(System.IntPtr h, System.Text.StringBuilder s, int n);
[DllImport("user32.dll")]
public static extern int GetWindowThreadProcessId(System.IntPtr h, out int pid);
[DllImport("user32.dll")]
public static extern bool IsWindowVisible(System.IntPtr h);
[DllImport("user32.dll")]
public static extern bool PostMessageW(System.IntPtr hWnd, uint msg, System.IntPtr wp, System.IntPtr lp);
'@

# ENUMERATE BY PID, do not FindWindow by class. Two reasons, and the first is not
# a preference: FindWindowW('TR4W', nil) returns 0 against this program even while
# EnumWindows reports a visible top-level window of exactly that class (measured
# 2026-08-13, 20 s of polling, both the A and W entry points). The second reason
# stands on its own -- a class-name search would just as happily return a
# DIFFERENT TR4W that happened to be running, and the whole point is to drive the
# build that was just compiled.
function Find-TR4WMainWindow
{
   param([Parameter(Mandatory = $true)][int] $ProcessId)

   $script:uiDrvFound = [IntPtr]::Zero
   $cb = [Win32.UiDrv+EnumWindowsProc]{
      param($h, $l)
      $owner = 0
      [void][Win32.UiDrv]::GetWindowThreadProcessId($h, [ref]$owner)
      if (($owner -eq $ProcessId) -and [Win32.UiDrv]::IsWindowVisible($h))
         {
         # CLASS 'TR4W' *OR* 'Window'. Phase 3a made the main window an LCL
         # TForm, and an LCL form's Win32 class is 'Window' -- hardcoded in the
         # widgetset, with no override. The old name is still accepted so this
         # harness can drive a pre-3a binary for comparison.
         #
         # 'Window' is not distinctive, so the other two filters carry the
         # weight: the window must belong to THIS process and be visible, which
         # excludes the LCL's own invisible 0x0 helper window of the same class.
         $cls = New-Object System.Text.StringBuilder 256
         [void][Win32.UiDrv]::GetClassNameW($h, $cls, 256)
         if (($cls.ToString() -eq 'TR4W') -or ($cls.ToString() -eq 'Window'))
            {
            $script:uiDrvFound = $h
            return $false
            }
         }
      return $true
   }
   [void][Win32.UiDrv]::EnumWindows($cb, [IntPtr]::Zero)
   return $script:uiDrvFound
}

# Refuses when TR4W is already running: a second instance dies on the
# single-instance mutex and would look exactly like the crash being investigated.
function Assert-NoRunningTR4W
{
   $stale = Get-Process -Name 'tr4w', 'tr4w_fpc' -ErrorAction SilentlyContinue
   if ($stale)
      {
      throw "TR4W is already running (PID $($stale.Id -join ', ')) -- close it first"
      }
}

# Launches TR4W on a config and waits for the main window.
#
# PASS AN ABSOLUTE CONFIG PATH. TR4W copies the argument into TR4W_CFG_FILENAME
# with lstrcpyA and never expands it (tr4w.dpr ~881); FCONTEST then derives
# TR4W_LOG_PATH_NAME from it by scanning backwards for a '\'. Given a bare
# relative name there is no '\' to find, so what should be a DIRECTORY ends up as
# the base name and every path built from it is wrong. Measured both ways
# 2026-08-13. The fragility is TR4W's and pre-dates FPC; an absolute path here
# keeps the harness from manufacturing bug reports.
function Start-TR4WForDriving
{
   param(
      [Parameter(Mandatory = $true)][string] $Exe,
      [Parameter(Mandatory = $true)][string] $TargetDir,
      [Parameter(Mandatory = $true)][string] $ConfigPath,
      [int] $SettleMs = 8000,
      # Anything else the run needs, such as --lang es. The config path stays
      # first: uProgramMain takes the first NON-SWITCH argument as the contest
      # file, so a switch may follow it but must not precede it.
      [string[]] $ExtraArgs = @()
   )

   $argv = @($ConfigPath) + $ExtraArgs
   $proc = Start-Process -FilePath $Exe -WorkingDirectory $TargetDir `
                         -ArgumentList $argv -PassThru

   # Poll rather than sleep a fixed time -- startup cost varies with CTY.DAT and
   # the log size, and a fixed wait either wastes time or posts into a window
   # that does not exist yet.
   $hwnd     = [IntPtr]::Zero
   $deadline = (Get-Date).AddMilliseconds($SettleMs)
   while ((Get-Date) -lt $deadline)
      {
      if ($proc.HasExited)
         {
         return [pscustomobject]@{ Process = $proc; Hwnd = [IntPtr]::Zero; Failure = "died during startup, exit code $($proc.ExitCode)" }
         }
      $hwnd = Find-TR4WMainWindow -ProcessId $proc.Id
      if ($hwnd -ne [IntPtr]::Zero)
         {
         return [pscustomobject]@{ Process = $proc; Hwnd = $hwnd; Failure = $null }
         }
      Start-Sleep -Milliseconds 100
      }

   return [pscustomobject]@{ Process = $proc; Hwnd = [IntPtr]::Zero; Failure = 'main window never appeared' }
}

function Send-TR4WMenuCommand
{
   param(
      [Parameter(Mandatory = $true)][IntPtr] $Hwnd,
      [Parameter(Mandatory = $true)][int]    $Command
   )
   [void][Win32.UiDrv]::PostMessageW($Hwnd, 0x0111, [IntPtr]$Command, [IntPtr]::Zero)
}

function Stop-TR4WForDriving
{
   param([Parameter(Mandatory = $true)] $Process)

   if (-not $Process.HasExited)
      {
      try { $Process.Kill() } catch { }
      try { $Process.WaitForExit(5000) | Out-Null } catch { }
      }
}

# Only the bytes this run appended. tr4w.log is a rolling file that accumulates
# across sessions, and tailing a fixed number of lines has already shown a
# PREVIOUS run's error as if it were this one's.
function Get-TR4WLogMark
{
   param([Parameter(Mandatory = $true)][string] $LogPath)
   if (Test-Path -LiteralPath $LogPath) { return (Get-Item -LiteralPath $LogPath).Length }
   return 0
}

function Get-TR4WLogSince
{
   param(
      [Parameter(Mandatory = $true)][string] $LogPath,
      [Parameter(Mandatory = $true)][long]   $Mark
   )

   if (-not (Test-Path -LiteralPath $LogPath)) { return '' }
   # Opened with ReadWrite sharing: TR4W may still hold the file open.
   $fs = [System.IO.File]::Open($LogPath, 'Open', 'Read', 'ReadWrite')
   try
      {
      if ($fs.Length -le $Mark) { return '' }
      [void]$fs.Seek($Mark, 'Begin')
      $reader = New-Object System.IO.StreamReader($fs)
      return $reader.ReadToEnd()
      }
   finally
      {
      $fs.Dispose()
      }
}

# THE HARNESS CONFIG, in one place.
#
# TR4W cannot create its main window without a contest open -- it stops on the
# "Open configuration file or start a new contest" dialog -- and the main window
# is what owns the menu and every control these scripts look at. So every
# driving script needs a .cfg, and they all staged one the same way.
#
# THEY HAD THREE COPIES OF THAT, AND THE COPIES HAD DRIFTED (found 2026-08-26).
# Invoke-MenuSmoke had grown a guard for "the corpus set is not there" that
# reported the problem and exited; Dump-WindowTree and Test-Typing never got it
# and died on a raw Copy-Item error instead -- on a fresh clone, which is
# precisely where a harness has to explain itself. The guard is kept here, so
# the fix reaches every caller.
#
# Returns Failure rather than throwing, matching Start-TR4WForDriving.  It emits
# NOTHING to the pipeline: a PowerShell function returns everything it writes, so
# a progress line here comes back as PART OF THE RESULT, and the caller's
# $cfg.Failure then fails with "property cannot be found on this object".  The
# progress line is returned as .Message for the caller to print.
function Resolve-TR4WHarnessConfig
{
   param(
      [Parameter(Mandatory = $true)][string] $Repo,
      [Parameter(Mandatory = $true)][string] $TargetDir,
      # An existing .cfg name in tr4w\target. Empty stages one from the corpus.
      [string] $Config,
      [string] $Caller = 'harness'
   )

   $staged = $false
   $message = $null

   if (-not $Config)
      {
      # The corpus sets are the only contest data guaranteed present in a fresh
      # clone, which is what makes these runnable on a CI runner as well as on
      # the bench.
      $set = Join-Path $Repo 'tr4w\test\corpus\cqww_ssb_2025_ny4i'
      if (-not (Test-Path -LiteralPath (Join-Path $set 'log.cfg')))
         {
         return [pscustomobject]@{ Config = $null; Path = $null; Staged = $false; Message = $null
                                   Failure = "no corpus set at $set to stage a config from -- pass -Config" }
         }

      Copy-Item (Join-Path $set 'log.cfg') (Join-Path $TargetDir 'uitest.cfg') -Force
      Copy-Item (Join-Path $set 'log.trw') (Join-Path $TargetDir 'uitest.trw') -Force
      $Config = 'uitest.cfg'
      $staged = $true
      $message = "staged $Config from the corpus set cqww_ssb_2025_ny4i"
      }

   $path = Join-Path $TargetDir $Config
   if (-not (Test-Path -LiteralPath $path))
      {
      return [pscustomobject]@{ Config = $null; Path = $null; Staged = $false; Message = $null
                                Failure = "no config at $path" }
      }

   return [pscustomobject]@{ Config = $Config; Path = $path; Staged = $staged
                             Message = $message; Failure = $null }
}

Export-ModuleMember -Function Find-TR4WMainWindow, Assert-NoRunningTR4W,
                              Start-TR4WForDriving, Send-TR4WMenuCommand,
                              Stop-TR4WForDriving, Get-TR4WLogMark, Get-TR4WLogSince,
                              Resolve-TR4WHarnessConfig
