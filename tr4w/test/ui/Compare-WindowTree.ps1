<#
.SYNOPSIS
   Diff a live window tree against a committed baseline, and FAIL on anything
   that is not a documented source of noise.

.DESCRIPTION
   Dump-WindowTree.ps1 produces the tree; baselines\README.md explains what it
   normalizes and why. What did not exist until now was a comparer, so every
   conversion was checked by reading two JSON files side by side. That is fine
   once and skipped by the fifth window.

   THIS IS THE UI'S EQUIVALENT OF THE CORPUS. The corpus proves the contest
   engine still writes the same bytes; this proves the operator still sees the
   same controls in the same places. Neither proves the other, and the Win32 to
   LCL conversion is invisible to the corpus entirely.

   WHY IT MATCHES ON STRUCTURE AND REPORTS TEXT SEPARATELY. A conversion is
   allowed to change a caption (translation, a relabelled button) but is NOT
   allowed to lose a control, move one, or resize one. So nodes are keyed by
   class, control id and sibling ordinal -- never by text -- and a text change
   on a node that still matches is reported as a CAPTION difference rather than
   a structural one. Callers that expect captions to move (a language check)
   pass -IgnoreText.

   WHAT IT DELIBERATELY DOES NOT CATCH: colour, font, z-order, and anything
   drawn rather than placed in a window. A converted grid that renders its own
   cells is one node here. Do not read a pass as "the window looks right".

.PARAMETER Baseline
   Committed baseline JSON, normally under test\ui\baselines\.

.PARAMETER Actual
   A dump to compare. Omit and pass -ProcessId to dump a running TR4W first.

.PARAMETER ProcessId
   Attach to an already-running TR4W and dump it.

   YOU ALMOST CERTAINLY WANT THIS RATHER THAN LETTING THE SCRIPT LAUNCH ONE.
   Measured 2026-08-27: a process started from a non-interactive agent shell
   gets MainWindowHandle = 0 and never acquires a visible window, while a
   process started by the logged-on user in the SAME session and window station
   is fully enumerable. So the app has to be started interactively; the harness
   attaches to it.

.EXAMPLE
   # you start TR4W, then:
   .\Compare-WindowTree.ps1 -Baseline .\baselines\main-window.json `
                            -ProcessId (Get-Process tr4w_fpc).Id
#>
param(
   [Parameter(Mandatory = $true)]
   [string] $Baseline,
   [string] $Actual,
   [int]    $ProcessId,
   # Compare placement only. Use for a translated build, where every caption is
   # expected to differ and only the layout has to survive.
   [switch] $IgnoreText,
   # Geometry slack in pixels. The layout is a table times a runtime scale
   # factor (see baselines\README.md), so a font-size setting that differs from
   # the capture's moves everything slightly. Default 0: report it.
   [int]    $Tolerance = 0,
   [switch] $Quiet
)

$ErrorActionPreference = 'Stop'

# Created by Windows and by the DDE/IME machinery, not by TR4W. They come and
# go between runs; baselines\README.md lists them for the same reason.
$script:NoiseClasses = @(
   'tooltips_class32', 'DDEMLEvent', 'DDEMLMom', 'MSCTFIME UI', 'IME'
)

function Test-NoiseNode
   {
   param($Node)
   return $script:NoiseClasses -contains $Node.Class
   }

function Get-NodeKey
   {
   # Class + control id + ordinal among siblings sharing that pair.
   #
   # NOT the caption: the caption is the thing under test. Keying on it would
   # make a renamed button look like one control removed and another added,
   # which is the least useful way to report a rename.
   param($Node, [int] $Ordinal)
   return ('{0}#{1}[{2}]' -f $Node.Class, $Node.Id, $Ordinal)
   }

function Get-KeyedChildren
   {
   param($Nodes)
   $seen = @{}
   $out  = [ordered]@{}
   foreach ($n in @($Nodes))
      {
      if (Test-NoiseNode $n)
         {
         continue
         }
      $stem = '{0}#{1}' -f $n.Class, $n.Id
      if (-not $seen.ContainsKey($stem))
         {
         $seen[$stem] = 0
         }
      $key = Get-NodeKey -Node $n -Ordinal $seen[$stem]
      $seen[$stem] = $seen[$stem] + 1
      $out[$key] = $n
      }
   return $out
   }

$script:Findings = New-Object System.Collections.ArrayList

function Add-Finding
   {
   param([string] $Kind, [string] $Path, [string] $Detail)
   [void] $script:Findings.Add([pscustomobject]@{
      Kind   = $Kind
      Path   = $Path
      Detail = $Detail
   })
   }

function Compare-Node
   {
   param($Expected, $Actual, [string] $Path)

   # The main window's caption carries the version and the contest name, so it
   # differs on every release and every .cfg. README.md calls this out as the
   # first source of noise; comparing it would make the baseline unusable.
   $isRoot = ($Path -notmatch '/')

   if (-not $IgnoreText -and -not $isRoot)
      {
      if ($Expected.Text -ne $Actual.Text)
         {
         Add-Finding -Kind 'CAPTION' -Path $Path `
                     -Detail ("'{0}' -> '{1}'" -f $Expected.Text, $Actual.Text)
         }
      }

   foreach ($f in @('Visible', 'Enabled'))
      {
      if ($Expected.$f -ne $Actual.$f)
         {
         Add-Finding -Kind 'STATE' -Path $Path `
                     -Detail ("{0} {1} -> {2}" -f $f, $Expected.$f, $Actual.$f)
         }
      }

   foreach ($f in @('Left', 'Top', 'Width', 'Height'))
      {
      $delta = [Math]::Abs([int] $Expected.$f - [int] $Actual.$f)
      if ($delta -gt $Tolerance)
         {
         Add-Finding -Kind 'GEOMETRY' -Path $Path `
                     -Detail ("{0} {1} -> {2}  (delta {3})" -f $f, $Expected.$f, $Actual.$f, $delta)
         }
      }

   $expChildren = Get-KeyedChildren $Expected.Children
   $actChildren = Get-KeyedChildren $Actual.Children

   foreach ($key in $expChildren.Keys)
      {
      $childPath = "$Path/$key"
      if (-not $actChildren.Contains($key))
         {
         Add-Finding -Kind 'MISSING' -Path $childPath `
                     -Detail ("baseline had '{0}'" -f $expChildren[$key].Text)
         continue
         }
      Compare-Node -Expected $expChildren[$key] -Actual $actChildren[$key] -Path $childPath
      }

   foreach ($key in $actChildren.Keys)
      {
      if (-not $expChildren.Contains($key))
         {
         Add-Finding -Kind 'ADDED' -Path "$Path/$key" `
                     -Detail ("now present: '{0}'" -f $actChildren[$key].Text)
         }
      }
   }

# ---------------------------------------------------------------- entry point

if (-not (Test-Path $Baseline))
   {
   throw "No baseline at $Baseline"
   }

if (-not $Actual)
   {
   if (-not $ProcessId)
      {
      throw 'Pass -Actual <dump.json> or -ProcessId <pid> of a running TR4W. See the .PARAMETER notes: the app must be started interactively, not by this script.'
      }
   $Actual = Join-Path ([IO.Path]::GetTempPath()) ('tr4w-tree-{0}.json' -f $ProcessId)
   & (Join-Path $PSScriptRoot 'Dump-WindowTree.ps1') -ProcessId $ProcessId -NoHandles -Out $Actual | Out-Null
   }

if (-not (Test-Path $Actual))
   {
   throw "No dump at $Actual"
   }

# -Encoding UTF8 on BOTH, explicitly. Dump-WindowTree writes UTF-8; Windows
# PowerShell 5.1 -- which is all the CI runner has -- reads with the machine's
# ANSI codepage unless told otherwise. Inheriting that would decode a non-ASCII
# caption differently in the two files and report a CAPTION difference that
# exists only in the reader. The committed baseline already carries a U+FFFD, so
# this path is live, not hypothetical.
$expTops = Get-KeyedChildren (Get-Content $Baseline -Raw -Encoding UTF8 | ConvertFrom-Json)
$actTops = Get-KeyedChildren (Get-Content $Actual   -Raw -Encoding UTF8 | ConvertFrom-Json)

foreach ($key in $expTops.Keys)
   {
   if (-not $actTops.Contains($key))
      {
      Add-Finding -Kind 'MISSING' -Path $key `
                  -Detail ("top-level window '{0}' is gone" -f $expTops[$key].Text)
      continue
      }
   Compare-Node -Expected $expTops[$key] -Actual $actTops[$key] -Path $key
   }

foreach ($key in $actTops.Keys)
   {
   if (-not $expTops.Contains($key))
      {
      Add-Finding -Kind 'ADDED' -Path $key `
                  -Detail ("new top-level window '{0}'" -f $actTops[$key].Text)
      }
   }

if (-not $Quiet)
   {
   if ($script:Findings.Count -eq 0)
      {
      Write-Host ("Compare-WindowTree: no differences ({0} vs {1})" -f `
                  (Split-Path $Baseline -Leaf), (Split-Path $Actual -Leaf))
      }
   else
      {
      $script:Findings |
         Sort-Object Kind, Path |
         ForEach-Object { Write-Host ("  {0,-9} {1}  {2}" -f $_.Kind, $_.Path, $_.Detail) }
      Write-Host ""
      Write-Host ("Compare-WindowTree: {0} difference(s)." -f $script:Findings.Count)
      Write-Host "A conversion may legitimately change CAPTION rows. MISSING, ADDED,"
      Write-Host "GEOMETRY and STATE rows are the ones that mean a control was lost,"
      Write-Host "gained, moved or greyed -- explain every one before committing."
      }
   }

exit ([int] ($script:Findings.Count -gt 0))
