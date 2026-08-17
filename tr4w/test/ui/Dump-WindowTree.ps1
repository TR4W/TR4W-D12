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

param(
   # Post this WM_COMMAND and dump what it produced. Omit to dump as-launched.
   [int]    $Command,
   # Attach to an already-running TR4W instead of launching one.
   [int]    $ProcessId,
   [string] $Out,
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

   $direct = @()
   foreach ($k in $kids)
      {
      $p = [Win32.Tree]::GetDlgCtrlID($k)   # touched to keep the call ordering obvious
      $null = $p
      $facts = Get-WindowFacts -Hwnd $k
      $direct += $facts
      }
   return $direct
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
      Copy-Item (Join-Path $set 'log.cfg') (Join-Path $target 'smoke.cfg') -Force
      Copy-Item (Join-Path $set 'log.trw') (Join-Path $target 'smoke.trw') -Force
      $Config = 'smoke.cfg'
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
