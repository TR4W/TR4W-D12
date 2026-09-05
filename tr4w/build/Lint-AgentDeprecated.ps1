<#
.SYNOPSIS
   Guards the //AGENT_DEPRECATED marker: it must sit on genuinely commented-out
   code, and the marked lines stay visible so they get swept rather than settle.

.DESCRIPTION
   THE CONVENTION (NY4I, 2026-09-05). When a conversion makes a line dead --
   a Win32 call whose window is now an LCL control, say -- the line may be
   COMMENTED rather than deleted, so the old behaviour can still be compared
   against the new one when something looks wrong:

     //Windows.SetWindowTextA(QSONeedWindowsHandles1[Band], BandStringsArray[Band]); //AGENT_DEPRECATED

   WHAT THIS DOES *NOT* NEED TO DO, and the reason is worth stating because the
   obvious reading of the request is wrong: Lint-Win32Dialogs does not need
   teaching to skip these. It already counts CODE ONLY -- PascalSource.psm1
   strips comments and string literals before anything is matched. Measured
   2026-09-05 with a two-line fixture, one commented and one live:
   CreateWindowEx counted 1, not 2. A commented line is invisible to it with or
   without the marker.

   WHAT THE MARKER IS ACTUALLY FOR, then, is the hole that comment-blindness
   opens. Because the Win32 counts ignore comments, COMMENTING OUT LIVE CODE
   LOWERS THEM. A ratchet that falls because work was hidden looks exactly like
   a ratchet that falls because work was done. The marker says which happened,
   and this lint keeps it honest:

     1. A line carrying the marker MUST be commented out. A marker on live code
        is either a mistake or a ratchet being gamed; either way it fails.
     2. The marked lines are COUNTED AND LISTED on every build, so a pile of
        them cannot quietly become permanent. They are a staging post on the
        way to deletion, not a destination.

   Deleting is still the default. Mark a line only when the old code genuinely
   helps diagnose the new -- and delete it once the replacement has been
   exercised.

.PARAMETER SourceDir
   The tr4w directory. Defaults to this script's parent.

.PARAMETER SelfTest
   Run the rules against built-in fixtures instead of the tree.
#>
[CmdletBinding()]
param(
   [string] $SourceDir = (Split-Path -Parent $PSScriptRoot),
   [switch] $SelfTest
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$MARKER = 'AGENT_DEPRECATED'

function Test-Line
{
   <#
     Returns $true when the line is a legal use of the marker: the marker is
     present AND the code before it is commented out.

     A Pascal line comment is `//`; the marker itself is written as a trailing
     `//AGENT_DEPRECATED`, so the test is whether a `//` appears BEFORE the
     marker's own one. Brace and (* *) forms count too -- a line inside a block
     comment is not code either.
   #>
   param([string] $Line)

   $idx = $Line.IndexOf($MARKER)
   if ($idx -lt 0) { return $true }          # no marker, not our business

   $before = $Line.Substring(0, $idx)

   # The marker's own '//' is immediately before it; look for a comment opener
   # earlier than that.
   $trimmed = $before.TrimEnd()
   if ($trimmed.EndsWith('//')) { $trimmed = $trimmed.Substring(0, $trimmed.Length - 2) }

   return ($trimmed -match '//') -or ($trimmed -match '\{') -or ($trimmed -match '\(\*')
}

if ($SelfTest)
{
   $fixtures = @(
      @{ Name = 'commented line with marker is legal'; Expect = $true
         Line = '   //Windows.SetWindowTextA(h, s); //AGENT_DEPRECATED' }
      @{ Name = 'LIVE line with marker is a violation'; Expect = $false
         Line = '   Windows.SetWindowTextA(h, s); //AGENT_DEPRECATED' }
      @{ Name = 'brace-commented line with marker is legal'; Expect = $true
         Line = '   { Windows.SetWindowTextA(h, s); } //AGENT_DEPRECATED' }
      @{ Name = 'line without the marker is ignored'; Expect = $true
         Line = '   Windows.SetWindowTextA(h, s);' }
   )

   $failed = 0
   foreach ($f in $fixtures)
   {
      $got = Test-Line $f.Line
      if ($got -ne $f.Expect)
         {
         Write-Output ("  SELFTEST FAIL: {0} -- expected {1}, got {2}" -f $f.Name, $f.Expect, $got)
         $failed++
         }
   }

   if ($failed -gt 0)
      {
      Write-Output "Lint-AgentDeprecated SELFTEST: $failed fixture(s) failed."
      exit 1
      }
   Write-Output ("Lint-AgentDeprecated SELFTEST: all {0} fixtures behaved as documented." -f $fixtures.Count)
   exit 0
}

# ACCEPT EITHER THE tr4w DIRECTORY OR src ITSELF. Run-Lints hands its lints
# different roots -- some the repo, some tr4w, some tr4w\src -- and the first
# wiring of this one appended 'src' to a path that already ended in it. The
# script then reported "nothing to check" and EXITED 0, so Run-Lints counted a
# pass for a lint that had examined no files at all. That is the fail-open
# shape this tree has been bitten by before (see Lint-RadioRegistry's floor).
$src = $SourceDir
if (Test-Path -LiteralPath (Join-Path $SourceDir 'src'))
   {
   $src = Join-Path $SourceDir 'src'
   }

if (-not (Test-Path -LiteralPath $src))
   {
   Write-Output "Lint-AgentDeprecated: FAILED -- no source directory at $src."
   exit 1
   }

# The IDE's backup copies and the graphify cache are stale snapshots of real
# units; they are gitignored and are not the tree.  Counting them reports work
# that was finished days ago -- exactly what sent NY4I looking for a
# CreateQSONeedWindows that had already been deleted.
# @() SO ONE MATCH OR NONE STILL HAS .Count. Under StrictMode a bare
# Get-ChildItem returns a scalar when it finds exactly one file and $null when
# it finds none, and $files.Count then THROWS -- which is how the floor below
# came to print an error and still exit 0, the very fail-open it exists to stop.
$files = @(Get-ChildItem -LiteralPath $src -Recurse -File -Include *.pas, *.PAS, *.lpr, *.inc |
   Where-Object { $_.FullName -notmatch '\\backup\\' -and $_.FullName -notmatch '\\graphify-out\\' })

# A FLOOR, so "clean" can never mean "looked at nothing". This tree has ~440
# Pascal files; anything under a hundred means the path or the filter is wrong,
# not that the code is tidy.
if ($files.Count -lt 100)
   {
   Write-Output ("Lint-AgentDeprecated: FAILED -- only {0} source file(s) found under {1}." -f $files.Count, $src)
   Write-Output '  That is the SCRIPT being wrong, not the source. A lint that examines'
   Write-Output '  nothing reports no violations and passes, which is worse than no lint.'
   exit 1
   }

$violations = @()
$marked = @()

foreach ($f in $files)
{
   $n = 0
   foreach ($line in [System.IO.File]::ReadAllLines($f.FullName))
   {
      $n++
      if ($line -notmatch $MARKER) { continue }

      $rel = $f.FullName.Substring($SourceDir.Length).TrimStart('\')
      if (Test-Line $line)
         {
         $marked += ("{0}:{1}" -f $rel, $n)
         }
      else
         {
         $violations += ("{0}:{1}: {2}" -f $rel, $n, $line.Trim())
         }
   }
}

if ($violations.Count -gt 0)
{
   Write-Output ''
   foreach ($v in $violations) { Write-Output "  $v" }
   Write-Output ''
   Write-Output ("Lint-AgentDeprecated: {0} line(s) marked //$MARKER that are NOT commented out." -f $violations.Count)
   Write-Output '  The marker means "this code is dead and kept only for comparison".'
   Write-Output '  On a LIVE line it is either a mistake or a Win32 count being lowered by'
   Write-Output '  hiding work rather than doing it -- the counts ignore comments, so a'
   Write-Output '  commented-out call is already invisible to them.'
   exit 1
}

if ($marked.Count -eq 0)
   {
   Write-Output ("Lint-AgentDeprecated: {0} file(s) checked, no deprecated lines pending deletion." -f $files.Count)
   exit 0
   }

Write-Output ("Lint-AgentDeprecated: {0} line(s) awaiting deletion, all correctly commented." -f $marked.Count)
foreach ($m in $marked) { Write-Output "    $m" }
exit 0
