# Dumps the LIVE menu of a running TR4W as JSON. READ-ONLY -- it walks and
# reads, and never posts a command or opens a window.
#
# WHY THIS EXISTS: it is the ORACLE for the TMainMenu + TActionList migration
# (docs\MENU_ACTIONLIST_PLAN.md, Phase 0). Capture it before touching the menu,
# capture it again after each phase, diff. Same instrument as
# Dump-WindowTree.ps1 is for forms.
#
# IT READS THE MENU WINDOWS ACTUALLY HAS, not the table the menu is built from.
# That distinction is the whole point and it is the lesson from
# Dump-Accelerators.ps1, which read the live accelerator table out of the binary
# and found that 25 of 97 bindings were displayed by NO menu row. Parsing
# T_MENU_ARRAY out of uMenu.pas would be checking the source against itself:
# the captions are the thing under test, so they cannot also be the oracle.
#
# It therefore also captures what RUNTIME code did to the menu after it was
# built -- the EnableMenuItem, DeleteMenu and ModifyMenu calls in MainUnit that
# grey the QRZ.ru and WA7BNM calendar entries, drop the POTA rows and rewrite
# the Cabrillo caption. Those are invisible to any source-level tool.
#
#   .\Dump-Menu.ps1 -Out before.json      # launch, dump, close
#   .\Dump-Menu.ps1 -ProcessId 1234       # attach to a running TR4W
#   .\Dump-Menu.ps1                       # dump to stdout as a readable tree
#
# A CONFIG IS REQUIRED, because TR4W creates no main window without a contest
# open -- and the main window is what owns the menu. Staged from the corpus by
# Resolve-TR4WHarnessConfig unless -Config names one.

param(
   [string] $Repo = (Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent),
   [string] $Exe,
   # A .cfg already in tr4w\target. Omit to stage one from the golden corpus.
   [string] $Config,
   # Attach to an already-running TR4W instead of launching one.
   [int]    $ProcessId,
   [string] $Out,
   [int]    $SettleMs = 8000
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot 'UiDriver.psm1') -Force

Add-Type -Namespace Win32 -Name MenuDump -MemberDefinition @'
[DllImport("user32.dll")] public static extern System.IntPtr GetMenu(System.IntPtr hWnd);
[DllImport("user32.dll")] public static extern int GetMenuItemCount(System.IntPtr hMenu);
[DllImport("user32.dll")] public static extern System.IntPtr GetSubMenu(System.IntPtr hMenu, int nPos);
[DllImport("user32.dll")] public static extern int GetMenuItemID(System.IntPtr hMenu, int nPos);
[DllImport("user32.dll")] public static extern int GetMenuState(System.IntPtr hMenu, int uId, uint uFlags);
[DllImport("user32.dll", CharSet = CharSet.Unicode)]
public static extern int GetMenuStringW(System.IntPtr hMenu, int uIDItem,
                                        System.Text.StringBuilder lpString, int nMaxCount, uint uFlag);
'@

# MF_BYPOSITION throughout. Addressing by COMMAND ID cannot reach a popup (a
# submenu has no id) and would silently skip every one of them.
$MF_BYPOSITION = 0x00000400
$MF_GRAYED     = 0x00000001
$MF_DISABLED   = 0x00000002
$MF_CHECKED    = 0x00000008
$MF_SEPARATOR  = 0x00000800

function Get-MenuTree
{
   param(
      [Parameter(Mandatory = $true)][IntPtr] $Menu,
      [string] $Path = ''
   )

   $items = @()
   $count = [Win32.MenuDump]::GetMenuItemCount($Menu)
   if ($count -le 0) { return $items }

   for ($i = 0; $i -lt $count; $i++)
      {
      $buf = New-Object System.Text.StringBuilder 512
      [void][Win32.MenuDump]::GetMenuStringW($Menu, $i, $buf, 512, $MF_BYPOSITION)
      $raw = $buf.ToString()

      # THE CAPTION CARRIES ITS OWN SHORTCUT, tab-separated -- CreateTR4WMenu
      # appends #9 + AcceleratorDisplayFor(id). Split them so a diff can tell
      # "the label changed" from "the key changed"; the program itself does the
      # same split when it reads a window's title back out of its menu item.
      $tab      = $raw.IndexOf([char]9)
      $caption  = if ($tab -ge 0) { $raw.Substring(0, $tab) } else { $raw }
      $shortcut = if ($tab -ge 0) { $raw.Substring($tab + 1) } else { '' }

      $state = [Win32.MenuDump]::GetMenuState($Menu, $i, $MF_BYPOSITION)
      $sub   = [Win32.MenuDump]::GetSubMenu($Menu, $i)
      $id    = [Win32.MenuDump]::GetMenuItemID($Menu, $i)

      $kind = 'item'
      if (($state -band $MF_SEPARATOR) -ne 0) { $kind = 'separator' }
      elseif ($sub -ne [IntPtr]::Zero)        { $kind = 'popup' }

      $here = if ($Path) { "$Path > $caption" } else { $caption }

      $node = [ordered]@{
         Path     = $here
         Kind     = $kind
         Caption  = $caption
         Shortcut = $shortcut
         # A popup has no command id; GetMenuItemID reports -1. Recorded as
         # null rather than -1 so a diff does not read it as a real command.
         Id       = if ($kind -eq 'item') { $id } else { $null }
         Enabled  = (($state -band ($MF_GRAYED -bor $MF_DISABLED)) -eq 0)
         Checked  = (($state -band $MF_CHECKED) -ne 0)
         Children = @()
      }

      if ($kind -eq 'popup')
         {
         $node.Children = @(Get-MenuTree -Menu $sub -Path $here)
         }

      $items += [pscustomobject]$node
      }

   return $items
}

function Write-MenuTree
{
   param($Nodes, [int] $Depth = 0)
   foreach ($n in $Nodes)
      {
      $pad = ' ' * ($Depth * 3)
      if ($n.Kind -eq 'separator')
         {
         Write-Output ("{0}---" -f $pad)
         }
      else
         {
         $flags = ''
         if (-not $n.Enabled) { $flags += ' [greyed]' }
         if ($n.Checked)      { $flags += ' [checked]' }
         $idText = if ($null -eq $n.Id) { '     ' } else { '{0,5}' -f $n.Id }
         Write-Output ("{0} {1}{2,-40} {3}{4}" -f $idText, $pad, $n.Caption, $n.Shortcut, $flags)
         }
      Write-MenuTree -Nodes $n.Children -Depth ($Depth + 1)
      }
}

$target = Join-Path $Repo 'tr4w\target'
if (-not $Exe)
   {
   # The same binary Build-App.ps1 refreshes, which is what the operator runs.
   $Exe = Join-Path $Repo 'build-out\app-i386-win32\tr4w_fpc.exe'
   if (-not (Test-Path -LiteralPath $Exe)) { $Exe = Join-Path $target 'tr4w.exe' }
   }

$launched = $null

if ($ProcessId)
   {
   $hwnd = Find-TR4WMainWindow -ProcessId $ProcessId
   if ($hwnd -eq [IntPtr]::Zero)
      {
      Write-Output "Dump-Menu: no TR4W main window in process $ProcessId"
      exit 1
      }
   }
else
   {
   if (-not (Test-Path -LiteralPath $Exe))
      {
      Write-Output "Dump-Menu: no build at $Exe -- run FullBuild.ps1 first"
      exit 1
      }

   $cfg = Resolve-TR4WHarnessConfig -Repo $Repo -TargetDir $target -Config $Config -Caller 'Dump-Menu'
   if ($cfg.Message) { Write-Output "Dump-Menu: $($cfg.Message)" }
   if ($cfg.Failure)
      {
      Write-Output "Dump-Menu: $($cfg.Failure)"
      exit 1
      }

   try { Assert-NoRunningTR4W }
   catch { Write-Output "Dump-Menu: $_"; exit 1 }

   $launched = Start-TR4WForDriving -Exe $Exe -TargetDir $target -ConfigPath $cfg.Path -SettleMs $SettleMs
   if ($launched.Failure)
      {
      Write-Output "Dump-Menu: $($launched.Failure)"
      Stop-TR4WForDriving -Process $launched.Process
      exit 1
      }
   $hwnd = $launched.Hwnd
   }

try
   {
   $menu = [Win32.MenuDump]::GetMenu($hwnd)
   if ($menu -eq [IntPtr]::Zero)
      {
      # NOT a harness fault to hide: the main window having no menu at all is
      # exactly the regression this script would be run to catch.
      Write-Output 'Dump-Menu: the main window has NO MENU (GetMenu returned 0)'
      exit 1
      }

   $tree = @(Get-MenuTree -Menu $menu)

   # Counted, because "the diff is empty" and "the walk found nothing" look the
   # same in a file.
   $items = 0
   $stack = New-Object System.Collections.Stack
   foreach ($n in $tree) { $stack.Push($n) }
   while ($stack.Count -gt 0)
      {
      $n = $stack.Pop()
      if ($n.Kind -eq 'item') { $items++ }
      foreach ($c in $n.Children) { $stack.Push($c) }
      }

   if ($Out)
      {
      ($tree | ConvertTo-Json -Depth 12) | Set-Content -LiteralPath $Out -Encoding UTF8
      Write-Output ("Dump-Menu: {0} top-level popup(s), {1} command item(s) -> {2}" -f $tree.Count, $items, $Out)
      }
   else
      {
      Write-MenuTree -Nodes $tree
      Write-Output ''
      Write-Output ("Dump-Menu: {0} top-level popup(s), {1} command item(s)" -f $tree.Count, $items)
      }
   }
finally
   {
   if ($launched) { Stop-TR4WForDriving -Process $launched.Process }
   }
