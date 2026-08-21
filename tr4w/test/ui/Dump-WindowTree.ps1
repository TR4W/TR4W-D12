# Dumps the window tree of a running TR4W as JSON. READ-ONLY -- it enumerates
# and reads, and never posts, moves, closes or types.
#
# WHY THIS IS THE MIGRATION'S MEASURING STICK. The win32 widgetset gives LCL
# controls REAL HWNDs, so the same script dumps a hand-built Win32 dialog and its
# LCL replacement and the two are directly comparable. That is the "diff it
# window by window" instrument: capture a baseline before converting a form,
# convert it, dump again, diff.
#
# DIFF CAPTIONS AND GEOMETRY, NOT IDS. A converted form's control ids will not
# match the Win32 dialog's and are not expected to; what must survive a
# conversion is what the operator sees and where it is.
#
#   .\Dump-WindowTree.ps1 -Out before.json                    # main window only
#   .\Dump-WindowTree.ps1 -Command 10111 -Out prefs.json      # open it, then dump
#   .\Dump-WindowTree.ps1 -ProcessId 1234 -Out now.json       # attach to a running one
#
# Top-level windows are included, not just children: a modal dialog is a
# top-level owned window, so a child-only walk would miss the very thing most of
# these dumps are taken to look at.

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
   # Post this WM_COMMAND and dump what it produced. Omit to dump as-launched.
   [int]    $Command,
   # Attach to an already-running TR4W instead of launching one.
   [int]    $ProcessId,
   [string] $Out,
   # Drop the HWNDs. They are different on every run, so a committed baseline
   # that carried them would diff as "everything changed" and be useless for the
   # one job baselines have. Use this whenever the output is going to be
   # committed under test\ui\baselines\.
   [switch] $NoHandles,
   [string] $Repo = (Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent),
   [string] $Exe,
   [string] $Config,
   [int]    $SettleMs = 8000,
   [int]    $AfterMs  = 2500,
   [switch] $KeepOpen
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot 'UiDriver.psm1') -Force

Add-Type -Namespace Win32 -Name Tree -MemberDefinition @'
public delegate bool EnumProc(System.IntPtr h, System.IntPtr p);
[DllImport("user32.dll")]
public static extern bool EnumWindows(EnumProc cb, System.IntPtr p);
[DllImport("user32.dll")]
public static extern bool EnumChildWindows(System.IntPtr parent, EnumProc cb, System.IntPtr p);
[DllImport("user32.dll", CharSet = CharSet.Unicode)]
public static extern int GetClassNameW(System.IntPtr h, System.Text.StringBuilder s, int n);
[DllImport("user32.dll", CharSet = CharSet.Unicode)]
public static extern int GetWindowTextW(System.IntPtr h, System.Text.StringBuilder s, int n);
[DllImport("user32.dll")]
public static extern int GetWindowThreadProcessId(System.IntPtr h, out int pid);
[DllImport("user32.dll")]
public static extern bool IsWindowVisible(System.IntPtr h);
[DllImport("user32.dll")]
public static extern bool IsWindowEnabled(System.IntPtr h);
[DllImport("user32.dll")]
public static extern int GetDlgCtrlID(System.IntPtr h);
[DllImport("user32.dll")]
public static extern bool GetWindowRect(System.IntPtr h, out RECT r);
public struct RECT { public int Left, Top, Right, Bottom; }
'@

function Get-WindowFacts
{
   param([IntPtr] $Hwnd)

   $cls = New-Object System.Text.StringBuilder 256
   [void][Win32.Tree]::GetClassNameW($Hwnd, $cls, 256)
   $txt = New-Object System.Text.StringBuilder 1024
   [void][Win32.Tree]::GetWindowTextW($Hwnd, $txt, 1024)
   $r = New-Object Win32.Tree+RECT
   [void][Win32.Tree]::GetWindowRect($Hwnd, [ref]$r)

   return [pscustomobject]@{
      Handle  = ('0x{0:X}' -f [int64]$Hwnd)
      Class   = $cls.ToString()
      Text    = $txt.ToString()
      Id      = [Win32.Tree]::GetDlgCtrlID($Hwnd)
      Visible = [Win32.Tree]::IsWindowVisible($Hwnd)
      Enabled = [Win32.Tree]::IsWindowEnabled($Hwnd)
      Left    = $r.Left
      Top     = $r.Top
      Width   = $r.Right - $r.Left
      Height  = $r.Bottom - $r.Top
      Children = @()
   }
}

function Get-ChildTree
{
   param([IntPtr] $Parent)

   $kids = New-Object System.Collections.ArrayList
   $cb = [Win32.Tree+EnumProc]{
      param($h, $l)
      [void]$kids.Add($h)
      return $true
   }
   # EnumChildWindows recurses on its own, which would flatten the tree. Keep
   # only DIRECT children -- a control's position is meaningful relative to its
   # parent, and a flat list cannot express that.
   [void][Win32.Tree]::EnumChildWindows($Parent, $cb, [IntPtr]::Zero)

   # A List, and `, $result` on return. A bare `return @()` hands back $null,
   # and `@($null)` is an array of ONE $null -- so a window with no children
   # reported "1 child(ren)" and the -NoHandles pass then tried to set a
   # property on nothing. The comma keeps PowerShell from unwrapping a
   # one-element array on the way out, too.
   $direct = New-Object 'System.Collections.Generic.List[object]'
   foreach ($k in $kids)
      {
      [void]$direct.Add((Get-WindowFacts -Hwnd $k))
      }
   return ,$direct.ToArray()
}

function Get-ProcessWindows
{
   param([int] $Pid2)

   $tops = New-Object System.Collections.ArrayList
   $cb = [Win32.Tree+EnumProc]{
      param($h, $l)
      $owner = 0
      [void][Win32.Tree]::GetWindowThreadProcessId($h, [ref]$owner)
      if ($owner -eq $Pid2) { [void]$tops.Add($h) }
      return $true
   }
   [void][Win32.Tree]::EnumWindows($cb, [IntPtr]::Zero)

   $result = @()
   foreach ($t in $tops)
      {
      $facts = Get-WindowFacts -Hwnd $t
      $facts.Children = Get-ChildTree -Parent $t
      $result += $facts
      }
   return $result
}

$target = Join-Path $Repo 'tr4w\target'
if (-not $Exe) { $Exe = Join-Path $target 'tr4w.exe' }

$launched = $null

if ($ProcessId)
   {
   $pidToDump = $ProcessId
   }
else
   {
   if (-not (Test-Path -LiteralPath $Exe))
      {
      Write-Output "Dump-WindowTree: no build at $Exe -- run FullBuild.ps1 first"
      exit 1
      }
   try { Assert-NoRunningTR4W }
   catch { Write-Output "Dump-WindowTree: $_"; exit 1 }

   if (-not $Config)
      {
      $set = Join-Path $Repo 'tr4w\test\corpus\cqww_ssb_2025_ny4i'
      Copy-Item (Join-Path $set 'log.cfg') (Join-Path $target 'uitest.cfg') -Force
      Copy-Item (Join-Path $set 'log.trw') (Join-Path $target 'uitest.trw') -Force
      $Config = 'uitest.cfg'
      }
   $configPath = Join-Path $target $Config

   $launched = Start-TR4WForDriving -Exe $Exe -TargetDir $target -ConfigPath $configPath -SettleMs $SettleMs
   if ($launched.Failure)
      {
      Write-Output "Dump-WindowTree: $($launched.Failure)"
      Stop-TR4WForDriving -Process $launched.Process
      exit 1
      }
   $pidToDump = $launched.Process.Id

   if ($Command)
      {
      Send-TR4WMenuCommand -Hwnd $launched.Hwnd -Command $Command
      Start-Sleep -Milliseconds $AfterMs
      }
   }

# try/finally around everything after the launch. Without it a failure here
# leaves TR4W running, and the NEXT run refuses on the single-instance guard --
# which reads as "the harness is broken" when the harness is fine and the last
# run simply did not clean up. Cost one debugging cycle to learn.
try
{

$tree = Get-ProcessWindows -Pid2 $pidToDump

# -NoHandles means "this dump is going into a committed baseline", so it strips
# EVERYTHING that varies between two runs of an unchanged program -- not just the
# handles it is named for.
#
# WHY THIS GREW: the first committed baseline diffed 472 lines against a healthy
# build. 466 of them were absolute screen coordinates, which move whenever the
# window does (tr4w.pos records its position), and the rest were the wall clock.
# A baseline that can never match is not a weak gate, it is an ignored one -- so
# it fails exactly like a lint that reports "0 found" and passes.
#
#   - Handles      : different every run by definition.
#   - Left / Top   : made RELATIVE TO THE TOP-LEVEL WINDOW. This keeps the thing
#                    worth checking -- where a control sits within the layout --
#                    and drops the thing that is not: where the user last
#                    dragged the window. Width and Height are already absolute
#                    sizes and stay as they are.
#   - Text         : times of day are masked. HH:MM and HH:MM:SS only; anything
#                    else is left alone, because masking broadly would hide the
#                    captions this dump exists to notice.
if ($NoHandles)
   {
   # RECURSIVE, and it has to be. The first attempt normalized the top level and
   # its direct children only, and two consecutive runs still differed -- on a
   # clock that sits at depth 3. ConvertTo-Json is called with -Depth 8 for the
   # same reason: this tree is not two levels deep.
   function Repair-Node
      {
      param($Node, [int] $OriginX, [int] $OriginY)

      $Node.Handle = ''
      $Node.Left   = $Node.Left - $OriginX
      $Node.Top    = $Node.Top  - $OriginY
      $Node.Text   = ($Node.Text -replace '\b\d{1,2}:\d{2}(:\d{2})?\b', '<time>')
      # DATES TOO.  The main window shows dd-MM-yy, so a baseline that masks
      # only clock times still drifts once a day -- which is the same defect as
      # the one the time mask was added for, just on a slower clock.
      $Node.Text   = ($Node.Text -replace '\b\d{2}-\d{2}-\d{2,4}\b', '<date>')
      foreach ($c in @($Node.Children)) { Repair-Node -Node $c -OriginX $OriginX -OriginY $OriginY }
      }

   foreach ($w in $tree)
      {
      Repair-Node -Node $w -OriginX $w.Left -OriginY $w.Top
      }
   }
$json = $tree | ConvertTo-Json -Depth 8

if ($Out)
   {
   $json | Set-Content -LiteralPath $Out -Encoding UTF8
   Write-Output ("Dump-WindowTree: {0} top-level window(s) -> {1}" -f $tree.Count, $Out)
   }
else
   {
   Write-Output $json
   }

# A one-line summary of the top-level windows, because that is the question most
# dumps are taken to answer: did a window appear at all?
foreach ($w in $tree)
   {
   # @() around Children: a single child comes back as a bare object, not an
   # array, and .Count on it throws under StrictMode.
   Write-Output ("  top-level  {0,-24} '{1}'  {2}x{3}  {4} child(ren)  visible={5}" -f
                 $w.Class, $w.Text, $w.Width, $w.Height, @($w.Children).Count, $w.Visible)
   }

}
finally
{
   if ($launched -and -not $KeepOpen)
      {
      Stop-TR4WForDriving -Process $launched.Process
      }
}
exit 0
