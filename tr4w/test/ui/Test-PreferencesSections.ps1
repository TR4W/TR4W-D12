# Walks EVERY navigation section in Preferences and reports what each one shows.
#
# The golden corpus and the unit tests are both blind to the UI, and a section
# that fails to populate does not raise -- it just comes up empty, which is
# exactly how the nav tree itself came up empty for a whole session without one
# line in the log.
#
# THE VERDICT COMES FROM THE FORM, NOT FROM WINDOW ENUMERATION.  SelectSection
# logs "[Prefs] section tag=N -> panel|placeholder" and this script reads that
# back, because from outside the process the two are indistinguishable: an LCL
# TLabel is a TGraphicControl with NO WINDOW HANDLE, so a placeholder-only
# section and a genuinely empty one both enumerate as zero children.  The
# control counts printed alongside are a secondary signal only.
#
#   .\fpc-sweep-prefs.ps1 -Config drive.cfg
#   .\fpc-sweep-prefs.ps1 -Config drive.cfg -KeepOpen
#
# Driven by keyboard against the real tree control rather than by clicking
# coordinates.  The LCL implements its own tree, so the native numpad-'*'
# expand-all does not exist here -- each step sends RIGHT (expands a collapsed
# parent, no-op on a leaf) then DOWN.

param(
   [string] $Repo = (Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent),
   # Defaults to the binary FullBuild.ps1 produces. Derived from this script's
   # own location so a clone anywhere works without arguments.
   [string] $Exe = (Join-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) 'target\tr4w.exe'),
   # NO DEFAULT ON PURPOSE.  This needs a contest config, and TR4W will not
   # create the main window without one -- it stops on the "Open configuration
   # file or start a new contest" dialog, and there is nothing to drive.
   # Any .cfg in tr4w\target works; a corpus set is the easy source:
   #     cp tr4w/test/corpus/cqww_ssb_2025_ny4i/log.cfg tr4w/target/drive.cfg
   #     cp tr4w/test/corpus/cqww_ssb_2025_ny4i/log.trw tr4w/target/drive.trw
   [Parameter(Mandatory = $true)]
   [string] $Config,
   [int]    $Steps  = 27,
   [switch] $KeepOpen
)

$target = Join-Path $Repo 'tr4w\target'
$log    = Join-Path $target 'tr4w.log'
$cfg    = Join-Path $target $Config

foreach ($p in @($Exe, $cfg))
   {
   if (-not (Test-Path $p))
      {
      Write-Error "missing: $p"
      exit 1
      }
   }

$stale = Get-Process -Name 'tr4w_fpc', 'tr4w' -ErrorAction SilentlyContinue
if ($stale)
   {
   Write-Error "TR4W already running (PID $($stale.Id -join ', ')) -- close it first"
   exit 1
   }

Add-Type -Namespace Sweep -Name U -MemberDefinition @'
public delegate bool EnumWindowsProc(System.IntPtr h, System.IntPtr p);
[DllImport("user32.dll")] public static extern bool EnumWindows(EnumWindowsProc cb, System.IntPtr p);
[DllImport("user32.dll")] public static extern bool EnumChildWindows(System.IntPtr h, EnumWindowsProc cb, System.IntPtr p);
[DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern int GetClassNameW(System.IntPtr h, System.Text.StringBuilder s, int n);
[DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern int GetWindowTextW(System.IntPtr h, System.Text.StringBuilder s, int n);
[DllImport("user32.dll")] public static extern int GetWindowThreadProcessId(System.IntPtr h, out int pid);
[DllImport("user32.dll")] public static extern bool IsWindowVisible(System.IntPtr h);
[DllImport("user32.dll")] public static extern bool PostMessageW(System.IntPtr h, uint m, System.IntPtr w, System.IntPtr l);
[DllImport("user32.dll")] public static extern System.IntPtr SendMessageW(System.IntPtr h, uint m, System.IntPtr w, System.IntPtr l);
[DllImport("user32.dll")] public static extern System.IntPtr SetFocus(System.IntPtr h);
[DllImport("user32.dll")] public static extern bool GetWindowRect(System.IntPtr h, ref RECT r);
public struct RECT { public int L, T, R, B; }
'@

function WinTextOf([IntPtr] $h)
   {
   $s = New-Object System.Text.StringBuilder 512
   [void][Sweep.U]::GetWindowTextW($h, $s, 512)
   return $s.ToString()
   }

function WinClassOf([IntPtr] $h)
   {
   $s = New-Object System.Text.StringBuilder 256
   [void][Sweep.U]::GetClassNameW($h, $s, 256)
   return $s.ToString()
   }

# Every visible child, as a single comparable fingerprint. Two sections that
# differ in any control differ here; the same section sampled twice does not.
function ContentOf([IntPtr] $root)
   {
   $script:acc = New-Object System.Collections.Generic.List[string]
   $cb = [Sweep.U+EnumWindowsProc]{
      param($h, $l)
      if ([Sweep.U]::IsWindowVisible($h))
         {
         $t = WinTextOf $h
         if ($t -ne '')
            {
            $script:acc.Add($t)
            }
         }
      return $true
   }
   [void][Sweep.U]::EnumChildWindows($root, $cb, [IntPtr]::Zero)
   return $script:acc
   }

function FindTop([int] $ProcessId, [string] $ClassWanted, [string] $TextMatch)
   {
   $script:hit = [IntPtr]::Zero
   $cb = [Sweep.U+EnumWindowsProc]{
      param($h, $l)
      $owner = 0
      [void][Sweep.U]::GetWindowThreadProcessId($h, [ref]$owner)
      if (($owner -eq $ProcessId) -and [Sweep.U]::IsWindowVisible($h))
         {
         $okClass = ($ClassWanted -eq '') -or ((WinClassOf $h) -eq $ClassWanted)
         $okText  = ($TextMatch   -eq '') -or ((WinTextOf  $h) -match $TextMatch)
         if ($okClass -and $okText)
            {
            $script:hit = $h
            return $false
            }
         }
      return $true
   }
   [void][Sweep.U]::EnumWindows($cb, [IntPtr]::Zero)
   return $script:hit
   }

$logMark = if (Test-Path $log) { (Get-Item $log).Length } else { 0 }

$proc = Start-Process -FilePath $Exe -WorkingDirectory $target -ArgumentList $cfg -PassThru
Write-Host "launched PID $($proc.Id)"

$main = [IntPtr]::Zero
$deadline = (Get-Date).AddSeconds(25)
while ((Get-Date) -lt $deadline -and $main -eq [IntPtr]::Zero)
   {
   if ($proc.HasExited)
      {
      Write-Host "DIED during startup (exit $($proc.ExitCode))"
      exit 1
      }
   Start-Sleep -Milliseconds 200
   $main = FindTop $proc.Id 'TR4W' ''
   }

if ($main -eq [IntPtr]::Zero)
   {
   Write-Host 'FAIL: main window never appeared'
   $proc.Kill()
   exit 1
   }

[void][Sweep.U]::PostMessageW($main, 0x0111, [IntPtr]10111, [IntPtr]::Zero)
Start-Sleep -Seconds 4

$prefs = FindTop $proc.Id '' 'Preferences'
if ($prefs -eq [IntPtr]::Zero)
   {
   Write-Host 'FAIL: Preferences never opened'
   $proc.Kill()
   exit 1
   }

# FOUND BY GEOMETRY, not by class name.  The LCL does NOT wrap the native tree
# control -- TTreeView is drawn by the LCL itself, so its window class is the
# generic 'Window' shared with every panel on the form and there is nothing to
# match on.  tvNav is the only child 170 px wide (uPrefsForm.lfm), which is
# what identifies it.
$script:tree = [IntPtr]::Zero
$cbT = [Sweep.U+EnumWindowsProc]{
   param($h, $l)
   if ((WinClassOf $h) -eq 'Window')
      {
      $rc = New-Object Sweep.U+RECT
      [void][Sweep.U]::GetWindowRect($h, [ref]$rc)
      if (($rc.R - $rc.L) -eq 170)
         {
         $script:tree = $h
         return $false
         }
      }
   return $true
}
[void][Sweep.U]::EnumChildWindows($prefs, $cbT, [IntPtr]::Zero)

if ($script:tree -eq [IntPtr]::Zero)
   {
   Write-Host 'FAIL: no 170px child in Preferences -- the nav tree is missing'
   $proc.Kill()
   exit 1
   }

[void][Sweep.U]::SetFocus($script:tree)

$WM_KEYDOWN = 0x0100
$VK_HOME    = 0x24
$VK_DOWN    = 0x28
$VK_RIGHT   = 0x27

[void][Sweep.U]::SendMessageW($script:tree, $WM_KEYDOWN, [IntPtr]$VK_HOME, [IntPtr]0)
Start-Sleep -Milliseconds 400

$seen    = @{}
$rows    = @()
$lastSig = ''

for ($i = 0; $i -lt $Steps; $i++)
   {
   if ($i -gt 0)
      {
      # RIGHT first: on a collapsed parent it expands (so children join the
      # walk), on a leaf it does nothing. BuildNavTree calls FullCollapse, so
      # without this the sweep would only ever see the 13 top-level items.
      [void][Sweep.U]::SendMessageW($script:tree, $WM_KEYDOWN, [IntPtr]$VK_RIGHT, [IntPtr]0)
      Start-Sleep -Milliseconds 120
      [void][Sweep.U]::SendMessageW($script:tree, $WM_KEYDOWN, [IntPtr]$VK_DOWN, [IntPtr]0)
      }
   Start-Sleep -Milliseconds 350

   if ($proc.HasExited)
      {
      Write-Host "DIED at step $i (exit $($proc.ExitCode))"
      exit 1
      }

   # Windowed controls only -- an LCL TLabel has no handle, so a label-only
   # section reads as 0 here. The panel/placeholder verdict comes from the
   # form's own log line instead; see below.
   $content = ContentOf $prefs
   $sig     = ($content -join '|')
   $changed = ($sig -ne $lastSig)
   $lastSig = $sig

   $rows += [pscustomobject]@{
      Step     = $i
      Controls = $content.Count
      Changed  = $changed
   }

   if (-not $seen.ContainsKey($sig))
      {
      $seen[$sig] = $true
      }
   }

Write-Host ''
Write-Host "distinct windowed-control sets : $($seen.Count) of $Steps steps"

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
         # The form's own verdict per section -- the only trustworthy source,
         # since a placeholder is a handle-less TLabel from outside.
         $sections = ($new -split "`n") | Select-String '\[Prefs\] section tag='
         $tags = @{}
         foreach ($s in $sections)
            {
            if ($s.Line -match 'tag=(\d+) -> (\w+)')
               {
               $tags[[int]$Matches[1]] = $Matches[2]
               }
            }
         Write-Host ''
         Write-Host "sections reported by the form   : $($tags.Count) distinct tags"
         Write-Host "  with a panel                  : $(($tags.Values | Where-Object { $_ -eq 'panel' }).Count)"
         Write-Host "  showing the placeholder       : $(($tags.Values | Where-Object { $_ -eq 'placeholder' }).Count)"
         Write-Host ''
         Write-Host ('  {0,-6} {1}' -f 'tag', 'result')
         foreach ($k in ($tags.Keys | Sort-Object))
            {
            Write-Host ('  {0,-6} {1}' -f $k, $tags[$k])
            }

         $bad = ($new -split "`n") | Select-String 'EReadError|Error reading|FAILED during|Invalid value|Unknown property|Exception'
         Write-Host ''
         if ($bad)
            {
            Write-Host '=== errors logged during the sweep ==='
            $bad | ForEach-Object { Write-Host "  $($_.Line.Trim())" }
            }
         else
            {
            Write-Host 'no form/streaming errors logged during the sweep'
            }
         }
      }
   finally
      {
      $fs.Dispose()
      }
   }

Write-Host ''
Write-Host "alive at end: $(-not $proc.HasExited)"

if (-not $KeepOpen -and -not $proc.HasExited)
   {
   $proc.Kill()
   $proc.WaitForExit(5000) | Out-Null
   }
