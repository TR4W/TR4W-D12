<#
.SYNOPSIS
   Burn-down ratchet for the Win32 UI surface. Counts may only go DOWN.

.DESCRIPTION
   TR4W is converting ~45 hand-built Win32 windows to LCL designed forms, for
   macOS and Linux. That is a long migration, and the failure mode of a long
   migration is not that the old code survives -- it is that NEW Win32 UI keeps
   being added while the old is removed, so the total never moves and nobody
   notices until someone counts.

   So this counts the call sites of every way TR4W creates a window or a control
   in code, compares them against a committed baseline, and FAILS if any of them
   grew. It is the one mechanism that makes the migration monotonic.

   IT ALSO FAILS WHEN A COUNT DROPS. That is not pedantry: a ratchet that
   silently tolerates a lower number is loose, and the next regression back up
   to the old baseline passes. A conversion is expected to update the baseline in
   its own commit -- `-UpdateBaseline` does it -- which also gives the migration
   a per-commit record of what it actually removed.

.PARAMETER UpdateBaseline
   Rewrite the baseline from the current counts. Use this in the SAME commit as
   the conversion that lowered them, never on its own.

.PARAMETER SelfTest
   Check the shared Pascal reader this lint depends on, then exit.

.NOTES
   Counts come from CODE ONLY -- comments and string literals are stripped by
   build\PascalSource.psm1. Counting raw text would report commented-out Win32
   code as live and make the remaining work look larger than it is, which is the
   same mistake Count-LiveAsm.ps1 was written to avoid.
#>

param(
   [string] $SourceDir = (Split-Path -Parent $PSScriptRoot),
   [string] $BaselineFile,
   [switch] $UpdateBaseline,
   [switch] $SelfTest
)

Set-StrictMode -Version Latest
Import-Module (Join-Path $PSScriptRoot 'PascalSource.psm1') -Force

if (-not $BaselineFile) {
   $BaselineFile = Join-Path $PSScriptRoot 'win32-ui-baseline.json'
}

# WHAT IS COUNTED, and why each one is here.
#
# Word boundaries matter: without `\b`, `DialogBox\s*\(` also matches the tail of
# `tDialogBox(` and every site is counted twice, which would make the baseline a
# number nobody could reconcile against the source.
$patterns = [ordered]@{
   # Window creation -- the surfaces themselves.
   'CreateModalDialog'         = '\bCreateModalDialog\s*\('
   'tDialogBox'                = '\btDialogBox\s*\('
   'DialogBox*'                = '\bDialogBox(Param|IndirectParam)?\s*\('
   'CreateDialogIndirectParam' = '\bCreateDialogIndirectParam\s*\('
   'CreateDialogParam'         = '\bCreateDialogParam\s*\('
   'CreateWindowEx'            = '\bCreateWindowEx[AW]?\s*\('
   # The TF control factories -- what every WM_INITDIALOG builds its controls
   # with. These are the volume, and they are what Phase 7 finally deletes.
   'TF.CreateStatic'           = '\bCreateStatic\s*\('
   'TF.CreateButton'           = '\bCreateButton\s*\('
   'TF.CreateEdit'             = '\bCreateEdit\s*\('
   'TF.CreateComboBox'         = '\bCreateComboBox\s*\('
   'TF.CreateListBox'          = '\bCreateListBox\s*\('
   'TF.CreateListView2'        = '\bCreateListView2\s*\('
   'TF.CreateOwnerDrawListBox' = '\bCreateOwnerDrawListBox\s*\('
   'TF.CreateRichEdit'         = '\bCreateRichEdit\s*\('
   'CreateOKCancelButtons'     = '\bCreateOKCancelButtons\s*\('
   # THE MAIN WINDOW'S OWN SURFACE, added 2026-08-18. NY4I named the
   # done-criterion for Phase 7 directly: "before we call this done, the above
   # SetMainWindowText will be moved to something like edLocator.Text := ..".
   #
   # That is checkable rather than remembered, so it is checked here. These
   # three are how the ~43 display elements of the main window are built and
   # written today -- raw Win32 statics from the placement loop at
   # MainUnit.pas:3304, addressed through wh[] by element, never by control.
   # Phase 7 drives all three to ZERO; until then the ratchet stops them
   # growing, and the number is the honest measure of how much of that phase
   # is left.
   #
   # It is not bookkeeping. Reading a field's text through this path is what
   # produced the ShortString overruns fixed in 56a8ae97 and c523ac6b: a
   # property assignment carries its own length and cannot express that bug.
   'SetMainWindowText'         = '\bSetMainWindowText\s*\('
   'tCreateStaticWindow'       = '\btCreateStaticWindow\s*\('
   'CreateTR4WStaticWindow'    = '\bCreateTR4WStaticWindow(ID)?\s*\('
}

if ($SelfTest) {
   $failed = Invoke-PascalSourceSelfTest
   if ($failed -gt 0) {
      Write-Output ("Lint-Win32Dialogs SELFTEST: {0} parser fixture(s) failed." -f $failed)
      exit 1
   }
   Write-Output 'Lint-Win32Dialogs SELFTEST: the shared Pascal reader behaves as documented.'
   exit 0
}

if (-not (Test-Path -LiteralPath $SourceDir -PathType Container)) {
   Write-Output "Lint-Win32Dialogs: source directory not found: $SourceDir"
   exit 1
}

# @() around the result: PowerShell unwraps a one-element array on return, and
# `.Count` on the bare FileInfo throws under StrictMode -- so a directory holding
# exactly one Pascal file crashed the lint.
$files = @(Get-TR4WPascalFiles -Root $SourceDir)
if ($files.Count -eq 0) {
   # A FLOOR. Zero files scanned means the path or the filter is wrong, and a
   # ratchet that reports "nothing grew" because it looked at nothing is worse
   # than no ratchet.
   Write-Output "Lint-Win32Dialogs: NO Pascal files found under $SourceDir -- refusing to report a pass."
   exit 1
}

$counts = [ordered]@{}
foreach ($k in $patterns.Keys) { $counts[$k] = 0 }

# Per-file detail, so a growth can be attributed without a second search.
$where = @{}

# ONE REGEX PASS PER FILE PER PATTERN, not per LINE per pattern.
#
# The first version matched 15 patterns against every line of 412 files -- some
# 7 million regex calls -- and took over ten minutes, which would have made the
# build unusable and the lint the first thing anyone disabled. Matching the
# whole file text at once is 15 calls per file and finishes in seconds. Line
# numbers are computed only for the matches actually found (191 of them), by
# counting newlines before the match, so the reporting costs nothing.
foreach ($f in $files) {
   $text = Get-PascalCodeOnlyText -Path $f.FullName
   $rel  = $f.FullName.Substring($SourceDir.Length).TrimStart('\')
   foreach ($k in $patterns.Keys) {
      $m = [regex]::Matches($text, $patterns[$k])
      if ($m.Count -eq 0) { continue }
      $counts[$k] = $counts[$k] + $m.Count
      if (-not $where.ContainsKey($k)) {
         # A List for the same reason as the reader: `+=` on an array is O(n^2),
         # and this is the reporting path a growing count walks.
         $where[$k] = New-Object 'System.Collections.Generic.List[string]'
      }
      foreach ($hit in $m) {
         # PARENTHESES around the line expression: `-f` binds tighter than `+`,
         # so `"{0}:{1}" -f $rel, $n + 1` formats with $n and then CONCATENATES
         # "1" -- line 3 was reported as "a.pas:31".
         $line = ($text.Substring(0, $hit.Index).Split("`n")).Count
         [void]$where[$k].Add(("{0}:{1}" -f $rel, $line))
      }
   }
}

$total = 0
foreach ($k in $counts.Keys) { $total += $counts[$k] }

if ($UpdateBaseline) {
   $counts | ConvertTo-Json | Set-Content -LiteralPath $BaselineFile -Encoding UTF8
   Write-Output ("Lint-Win32Dialogs: baseline rewritten -- {0} call site(s) across {1} kind(s)." -f $total, $counts.Count)
   Write-Output "Commit it with the conversion that lowered it, not on its own."
   exit 0
}

if (-not (Test-Path -LiteralPath $BaselineFile)) {
   Write-Output "Lint-Win32Dialogs: no baseline at $BaselineFile -- create it with -UpdateBaseline."
   exit 1
}

$baseline = Get-Content -LiteralPath $BaselineFile -Raw | ConvertFrom-Json

$grew    = @()
$shrank  = @()
foreach ($k in $counts.Keys) {
   $was = if ($baseline.PSObject.Properties.Name -contains $k) { [int]$baseline.$k } else { -1 }
   if ($was -lt 0) {
      # A NEW kind of Win32 UI call appeared in the pattern list without a
      # baseline entry. Treat it as growth: silently accepting it would let the
      # list grow while the ratchet reported nothing.
      $grew += ("{0}: {1} call site(s), and no baseline entry -- add one with -UpdateBaseline" -f $k, $counts[$k])
   }
   elseif ($counts[$k] -gt $was) {
      $sites = if ($where.ContainsKey($k)) { ($where[$k] | Select-Object -Last 5) -join ', ' } else { '' }
      $grew += ("{0}: {1} call site(s), baseline {2} -- NEW Win32 UI was added. Recent: {3}" -f $k, $counts[$k], $was, $sites)
   }
   elseif ($counts[$k] -lt $was) {
      $shrank += ("{0}: {1}, was {2}" -f $k, $counts[$k], $was)
   }
}

if ($grew.Count -gt 0) {
   $grew | ForEach-Object { Write-Output ("  " + $_) }
   Write-Output ("Lint-Win32Dialogs: the Win32 UI surface GREW. It is being retired -- build new UI as an LCL designed form under src\ui\lcl\.")
   exit 1
}

if ($shrank.Count -gt 0) {
   $shrank | ForEach-Object { Write-Output ("  " + $_) }
   Write-Output "Lint-Win32Dialogs: counts went DOWN -- good, but the baseline is now stale."
   Write-Output "Run:  .\build\Lint-Win32Dialogs.ps1 -UpdateBaseline   and commit it with the conversion."
   exit 1
}

Write-Output ("Lint-Win32Dialogs: {0} Win32 UI call site(s) across {1} file(s), none above baseline." -f $total, $files.Count)
exit 0
