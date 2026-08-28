<#
.SYNOPSIS
   Find controls whose text does not fit, in a given language.

.DESCRIPTION
   The layout was drawn for English. A translation is routinely 20-40% longer --
   'Cancel' is 'Cancelar', 'Band map' is 'Mapa de bandas' -- and the first anyone
   knows about it is a clipped caption in a screenshot. That is the review NY4I
   has been doing by eye, one language at a time.

   THIS MEASURES RATHER THAN ESTIMATES. Every control is asked for its own font
   (WM_GETFONT), that font is selected into a DC, and GetTextExtentPoint32W
   returns the width Windows will actually paint. Guessing from character counts
   would be wrong in both directions: a proportional font makes 'Illlll' narrow
   and 'WWWWWW' wide, and the fonts here differ per control -- the main window
   uses a fixed font for the log and a proportional one for labels.

   WHAT COUNTS AS CLIPPED. Text wider than the control's CLIENT area, with a
   small allowance for the border and padding a control draws inside it. Buttons
   and labels are reported; edit boxes and list boxes are not, because their
   content scrolls by design and being wider than the box is normal.

   WHAT IT CANNOT SEE. Anything drawn rather than placed: owner-drawn list items,
   the main window's painted elements, grid cells. Those need eyes. It also
   cannot tell you a translation is WRONG -- only that it does not fit.

   RUN IT AGAINST A DEFUZZED CATALOGUE (tools/i18n/po_defuzz.py --install) or
   nearly everything will still be English and it will find nothing.

.EXAMPLE
   .\Test-TextFit.ps1 -Lang es
   .\Test-TextFit.ps1 -Lang it -Slack 0
#>
param(
   [string] $Lang = '',
   # Pixels of headroom before a control counts as clipped. A button reserves a
   # few pixels for its focus rectangle and a label for its border, so zero
   # reports controls that are merely snug.
   [int]    $Slack = 4,
   [int]    $ProcessId,
   [int]    $SettleMs = 9000,
   [string] $Exe,
   [switch] $Quiet
)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'UiDriver.psm1') -Force

Add-Type @"
using System;
using System.Runtime.InteropServices;
using System.Text;

public class TextFit
{
   [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc cb, IntPtr p);
   [DllImport("user32.dll")] public static extern bool EnumChildWindows(IntPtr h, EnumProc cb, IntPtr p);
   [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
   [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
   [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetWindowTextW(IntPtr h, StringBuilder s, int n);
   [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetClassNameW(IntPtr h, StringBuilder s, int n);
   [DllImport("user32.dll")] public static extern bool GetClientRect(IntPtr h, out RECT r);
   [DllImport("user32.dll")] public static extern IntPtr GetDC(IntPtr h);
   [DllImport("user32.dll")] public static extern int ReleaseDC(IntPtr h, IntPtr dc);
   [DllImport("user32.dll")] public static extern IntPtr SendMessageW(IntPtr h, uint m, IntPtr w, IntPtr l);
   [DllImport("gdi32.dll")] public static extern IntPtr SelectObject(IntPtr dc, IntPtr o);
   [DllImport("gdi32.dll", CharSet=CharSet.Unicode)] public static extern bool GetTextExtentPoint32W(IntPtr dc, string s, int c, out SIZE sz);

   public delegate bool EnumProc(IntPtr h, IntPtr p);
   [StructLayout(LayoutKind.Sequential)] public struct RECT { public int L, T, R, B; }
   [StructLayout(LayoutKind.Sequential)] public struct SIZE { public int cx, cy; }

   public const uint WM_GETFONT = 0x0031;

   // The width Windows will actually paint, in the control's OWN font.
   public static int TextWidth(IntPtr hwnd, string text)
   {
      if (String.IsNullOrEmpty(text)) return 0;
      IntPtr dc = GetDC(hwnd);
      if (dc == IntPtr.Zero) return -1;
      try
      {
         IntPtr font = SendMessageW(hwnd, WM_GETFONT, IntPtr.Zero, IntPtr.Zero);
         IntPtr old  = IntPtr.Zero;
         if (font != IntPtr.Zero) old = SelectObject(dc, font);
         SIZE sz;
         bool ok = GetTextExtentPoint32W(dc, text, text.Length, out sz);
         if (old != IntPtr.Zero) SelectObject(dc, old);
         return ok ? sz.cx : -1;
      }
      finally { ReleaseDC(hwnd, dc); }
   }

   public static int ClientWidth(IntPtr hwnd)
   {
      RECT r;
      if (!GetClientRect(hwnd, out r)) return -1;
      return r.R - r.L;
   }
}
"@

# Content that scrolls is SUPPOSED to exceed its box; reporting it is noise.
$script:Scrolls = @('Edit', 'ListBox', 'ComboBox', 'ComboLBox', 'RichEdit',
                    'RICHEDIT50W', 'SysListView32', 'SysTreeView32',
                    'LCLListBox', 'Memo')

function Test-Scrolling
   {
   param([string] $Class)
   foreach ($c in $script:Scrolls)
      {
      if ($Class -like "*$c*") { return $true }
      }
   return $false
   }

$script:Findings = New-Object System.Collections.ArrayList

function Measure-Tree
   {
   param([IntPtr] $Root, [string] $WindowTitle)

   $walk = {
      param($h, $l)
      if ([TextFit]::IsWindowVisible($h))
         {
         $t = New-Object Text.StringBuilder 512
         [void][TextFit]::GetWindowTextW($h, $t, 512)
         $text = $t.ToString()
         if ($text.Trim().Length -gt 0)
            {
            $c = New-Object Text.StringBuilder 256
            [void][TextFit]::GetClassNameW($h, $c, 256)
            $cls = $c.ToString()
            if (-not (Test-Scrolling $cls))
               {
               $need = [TextFit]::TextWidth($h, $text)
               $have = [TextFit]::ClientWidth($h)
               if (($need -gt 0) -and ($have -gt 0) -and ($need -gt ($have - $Slack)))
                  {
                  [void]$script:Findings.Add([pscustomobject]@{
                     Window = $WindowTitle
                     Class  = $cls
                     Text   = $text
                     Needs  = $need
                     Has    = $have
                     Over   = $need - $have
                  })
                  }
               }
            }
         }
      return $true
   }
   [void][TextFit]::EnumChildWindows($Root, $walk, [IntPtr]::Zero)
   }

# ------------------------------------------------------------------ entry point

$launched = $null
try
   {
   if (-not $ProcessId)
      {
      $repo   = Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent
      $target = Join-Path $repo 'tr4w\target'
      if (-not $Exe) { $Exe = Join-Path $repo 'build-out\app-i386-win32\tr4w_fpc.exe' }
      $args = @()
      if ($Lang) { $args = @('--lang', $Lang) }
      $cfg = Join-Path $target 'uitest.cfg'
      if (-not (Test-Path $cfg)) { throw "no uitest.cfg in $target -- run Dump-WindowTree.ps1 once to stage one" }
      $launched = Start-TR4WForDriving -Exe $Exe -TargetDir $target -ConfigPath $cfg -SettleMs $SettleMs -ExtraArgs $args
      if ($launched.Failure) { throw "TR4W did not start: $($launched.Failure)" }
      $ProcessId = $launched.Process.Id
      }

   $tops = @()
   [void][TextFit]::EnumWindows({ param($h, $l)
      $pid2 = 0
      [void][TextFit]::GetWindowThreadProcessId($h, [ref]$pid2)
      if (($pid2 -eq $ProcessId) -and [TextFit]::IsWindowVisible($h))
         {
         $t = New-Object Text.StringBuilder 512
         [void][TextFit]::GetWindowTextW($h, $t, 512)
         $script:tops += [pscustomobject]@{ H = $h; Title = $t.ToString() }
         }
      return $true }, [IntPtr]::Zero)

   foreach ($w in $script:tops) { Measure-Tree -Root $w.H -WindowTitle $w.Title }
   }
finally
   {
   if ($launched) { Stop-TR4WForDriving -Process $launched.Process }
   }

if (-not $Quiet)
   {
   $label = if ($Lang) { $Lang } else { 'the compiled-in English' }
   if ($script:Findings.Count -eq 0)
      {
      Write-Host ("Test-TextFit: nothing clipped in {0}." -f $label)
      }
   else
      {
      $script:Findings |
         Sort-Object -Property Over -Descending |
         ForEach-Object {
            Write-Host ("  {0,4}px over  {1,-16} {2}" -f $_.Over, $_.Class, $_.Text)
         }
      Write-Host ""
      Write-Host ("Test-TextFit: {0} control(s) whose text does not fit in {1}." -f
                  $script:Findings.Count, $label)
      Write-Host "Owner-drawn content is not measured here -- see the notes at the top."
      }
   }

exit ([int] ($script:Findings.Count -gt 0))
