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
   [ValidateSet('ui','platform')]
   [string] $Group = 'ui',
   [switch] $SelfTest
)

Set-StrictMode -Version Latest
Import-Module (Join-Path $PSScriptRoot 'PascalSource.psm1') -Force

if (-not $BaselineFile) {
   # ONE BASELINE PER GROUP -- see the platform table below for why they are
   # not merged.
   $BaselineFile = if ($Group -eq 'platform') {
      Join-Path $PSScriptRoot 'win32-platform-baseline.json'
   } else {
      Join-Path $PSScriptRoot 'win32-ui-baseline.json'
   }
}

# WHAT IS COUNTED, and why each one is here.
#
# Word boundaries matter: without `\b`, `DialogBox\s*\(` also matches the tail of
# `tDialogBox(` and every site is counted twice, which would make the baseline a
# number nobody could reconcile against the source.
$patterns = [ordered]@{
   # THE HANDLE ITSELF, and the only number here that has to reach ZERO.
   #
   # NY4I, 2026-08-23: "I do not believe we should be using those after win32 is
   # gone."  Right, and it is the honest scalar for this whole phase -- the call
   # counts below fall as dialogs convert, but a converted form that still
   # passes an HWND around has moved its widgets and not its architecture.  An
   # HWND cannot exist on GTK or Cocoa, so every one is either a real Win32
   # boundary or work that is not finished.
   #
   # \bHWND\b does NOT match HWND_TOP, HWND_TOPMOST or PHWND: `_` and the
   # surrounding letters are word characters, so the boundary fails.  Those are
   # constants and a pointer type, not the type itself, and counting them would
   # make the number one nobody could reconcile against the source.
   'type.HWND'                 = '\bHWND\b'

   # THE MAIN WINDOW'S HANDLE REGISTRY, counted separately because type.HWND
   # CANNOT SEE IT.  That pattern matches where the TYPE NAME appears --
   # declarations, parameters, casts -- so `wh: array[TMainWindowElement] of
   # HWND` is one match however many places index it.  Converting nineteen
   # wh[mweCall] / wh[mweExchange] sites to the TEdit objects moved type.HWND by
   # exactly zero, which is true and useless.
   #
   # This is the number that moves when a control stops being reached by handle,
   # and it is the one to drive down: 24 elements, and it can only reach zero
   # when every main-window control is an LCL object.  See
   # docs/MAIN_WINDOW_CONTROL_CROSSWALK.md for which are ready.
   'array.wh'                  = '\bwh\[mwe'

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

# THE PLATFORM GROUP -- PHASE 8, added 2026-08-21 (NY4I: "add the lint counters
# for phase 8").
#
# The UI group above measures phase 7. This one measures what phase 7 does NOT
# buy: the Win32 the program still speaks OUTSIDE its windows. None of it stops
# an LCL build here and all of it stops a build on GTK or Cocoa, so it is
# exactly the surface the end state has to reach zero on -- see "THE END STATE"
# at the top of the plan.
#
# SEPARATE BASELINE ON PURPOSE, not a bigger table. The two groups are different
# phases with different owners and different done-criteria: mixing them would
# mean a UI conversion and a serial-port abstraction moving one number, and
# neither could be read.
#
# GROUPED BY WHAT HAPPENS TO THEM, because the three are not the same work:
#   REPLACE  -- an RTL/LCL equivalent exists; mechanical, drive to 0.
#   ABSTRACT -- genuinely differs per OS; drive to 0 behind a seam.
#   GUARD    -- stays Windows-only; drive into {$IFDEF WINDOWS}, not to 0.
$platformPatterns = [ordered]@{
   # --- REPLACE ------------------------------------------------------------
   # The ini API has no Mac/Linux equivalent at all. docs/CFG_MIGRATION_PLAN.md
   # owns the replacement; this counts what is left to move.
   'ini.Read'          = '\bGetPrivateProfile[A-Za-z]*\s*\('
   'ini.Write'         = '\bWritePrivateProfile[A-Za-z]*\s*\('
   # wsprintfA -- the RTL has Format. TF.pas holds most of them.
   'wsprintf'          = '\bwsprintf[AW]?\s*\('
   # WinExec/ShellExecute -> OpenDocument (LazFileUtils) or TProcess.
   'process.Launch'    = '\b(WinExec|ShellExecute[AW]?|CreateProcess[AW]?)\s*\('
   # Raw thread and event handles -> TThread and TEvent (syncobjs). Counted as
   # two kinds because the thread bodies and the signalling move separately.
   'thread.Create'     = '\bCreateThread\s*\('
   'thread.Event'      = '\b(CreateEvent[AW]?|SetEvent|ResetEvent|WaitForSingleObject)\s*\('

   # Asking Windows ABOUT a window: its class, its style bits, its text.  These
   # are the ones that read as harmless because they only QUERY -- and they are
   # how a Windows-only assumption gets written into code that has no other
   # reason to be Windows-only.
   #
   # Added 2026-08-22 after RefreshMainWindowColors was written with
   # GetClassNameA and a literal 'SysListView32' to work out which elements were
   # list views.  It passed every lint, because none of them were looking.  The
   # fix was for CreateListView to record what it creates; the fact belongs to
   # the code that knows it, not to a question put to the window manager.
   'window.Query'      = '\b(GetClassName[AW]?|\bGetWindowLong[AW]?|\bGetWindowText[AW]?|\bGetWindowTextLength[AW]?)\s*\('

   # --- ABSTRACT -----------------------------------------------------------
   # The serial API behind uSerialPort. CreateFile is deliberately NOT counted:
   # it opens ordinary files too, so it cannot be attributed without reading
   # each site, and a ratchet built on a number nobody can reconcile is worse
   # than no ratchet (the lesson this file already learned about tDialogBox).
   'serial.CommAPI'    = '\b(SetCommState|GetCommState|SetCommTimeouts|GetCommTimeouts|BuildCommDCB[AW]?|SetupComm|PurgeComm|EscapeCommFunction|ClearCommError)\s*\('
   # Port enumeration and version info. Needs a per-OS implementation, not a
   # translation. TRegistry is a TYPE, hence no call parenthesis.
   'registry'          = '\bTRegistry\b|\b(RegOpenKey[A-Za-z]*|RegQueryValue[A-Za-z]*|RegSetValue[A-Za-z]*|RegEnumValue[A-Za-z]*|RegCloseKey)\s*\('

   # --- GUARD (stays Windows-only; the target is a deliberate IFDEF) --------
   'audio.MMSystem'    = '\b(waveOut[A-Za-z]+|waveIn[A-Za-z]+|mciSendCommand[AW]?|mciSendString[AW]?)\s*\('
   # inpout32 LPT keying -- KEPT deliberately (NY4I 2026-08-17), so this number
   # is not expected to reach zero. It is here to notice the surface SPREADING
   # beyond uIO/LPT.pas, which is what would make the guard expensive to draw.
   'lpt.inpout32'      = '\b(Out32|Inp32|IsInpOutDriverOpen)\s*\(|inpout32'
   # MMTTY is out-of-process and Windows-only by nature.
   'mmtty.WindowMsg'   = '\bRegisterWindowMessage[AW]?\s*\('
}

# FILES A GIVEN KIND DOES NOT APPLY TO.
#
# Only type.HWND needs this, and only for the two units that are TRANSLATIONS OF
# THE WINDOWS API rather than TR4W code: uCommctrl.pas is commctrl.h and
# MMSystem.pas is mmsystem.h.  Their HWNDs are the API declaring its own
# signatures -- PFNPROPSHEETCALLBACK takes an HWND because Windows says so --
# and no amount of LCL work removes one.  They go when the last consumer does,
# whole.
#
# It matters because they are 899 of the 1543: counting them makes the ratchet
# 58% inert, so a real reduction of twenty in TR4W's own code would round to
# nothing.  Excluded, the number is what it claims to be -- TR4W's own use of a
# handle that cannot exist on GTK or Cocoa.
$patternFileExclusions = @{
   'type.HWND' = '(?i)\\(uCommctrl|MMSystem)\.pas$'
}

$patternGroups = [ordered]@{
   'ui'       = $patterns
   'platform' = $platformPatterns
}

if (-not $patternGroups.Contains($Group)) {
   Write-Output "Lint-Win32Dialogs: unknown -Group '$Group'."
   exit 1
}
$patterns = $patternGroups[$Group]
$groupNoun = if ($Group -eq 'ui') { 'Win32 UI' } else { 'non-UI Win32 platform' }

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

# API HEADER TRANSLATIONS ARE NOT CALL SITES.
#
# src\MMSystem.pas is a translation of Windows' mmsystem.h -- 61 of its lines
# match audio.MMSystem, every one of them a `function waveOutOpen(...)`
# DECLARATION rather than TR4W calling anything. Counting them made the first
# platform baseline read 49 for a family with 12 real uses, and a ratchet whose
# number nobody can reconcile against the source is worse than no ratchet (the
# same lesson this file learned about tDialogBox being double-counted).
#
# The UI group is unaffected -- it names no API this unit declares -- but the
# exclusion is applied to both so the two groups cannot disagree about which
# files exist.
$files = @($files | Where-Object { $_.Name -ne 'MMSystem.pas' })
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
      if ($patternFileExclusions.ContainsKey($k) -and
          ($f.FullName -match $patternFileExclusions[$k])) {
         continue
      }
      # IGNORECASE, AND IT IS NOT OPTIONAL: PASCAL IDENTIFIERS ARE NOT
      # CASE-SENSITIVE AND .NET REGEX IS.
      #
      # Found 2026-08-21 while adding the platform group, by a discrepancy no
      # one would have chased otherwise: the lint reported ONE wsprintf call
      # site and grep -i found twelve. The others are spelled the same way and
      # matched -- what differed was nothing; the miss was `Shellexecute` with a
      # lowercase e, `Winexec`, and the trdos units' own spellings. TR4W spells
      # the same identifier three ways between declaration, assignment and use,
      # which CLAUDE.md warns about for exactly this reason.
      #
      # A ratchet that cannot see a differently-cased call is a ratchet with a
      # hole in it: new Win32 could be added through the one door it does not
      # watch, and the count would still read "none above baseline".
      $m = [regex]::Matches($text, $patterns[$k],
                            [Text.RegularExpressions.RegexOptions]::IgnoreCase)
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
   Write-Output ("Lint-Win32Dialogs[{2}]: baseline rewritten -- {0} call site(s) across {1} kind(s)." -f $total, $counts.Count, $Group)
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
      $grew += ("{0}: {1} call site(s), baseline {2} -- NEW {4} code was added. Recent: {3}" -f $k, $counts[$k], $was, $sites, $groupNoun)
   }
   elseif ($counts[$k] -lt $was) {
      $shrank += ("{0}: {1}, was {2}" -f $k, $counts[$k], $was)
   }
}

if ($grew.Count -gt 0) {
   $grew | ForEach-Object { Write-Output ("  " + $_) }
   Write-Output ("Lint-Win32Dialogs[{1}]: the {0} surface GREW. It is being retired -- see THE END STATE in the migration plan." -f $groupNoun, $Group)
   if ($Group -eq 'ui') {
      Write-Output "  Build new UI as an LCL designed form under src\ui\lcl\."
   }
   else {
      Write-Output "  Use the RTL/LCL equivalent (Format, TThread/TEvent, TProcess, the JSON store), or put it behind a platform seam."
   }
   exit 1
}

if ($shrank.Count -gt 0) {
   $shrank | ForEach-Object { Write-Output ("  " + $_) }
   Write-Output "Lint-Win32Dialogs: counts went DOWN -- good, but the baseline is now stale."
   Write-Output ("Run:  .\build\Lint-Win32Dialogs.ps1 -Group {0} -UpdateBaseline   and commit it with the conversion." -f $Group)
   exit 1
}

Write-Output ("Lint-Win32Dialogs[{2}]: {0} {3} call site(s) across {1} file(s), none above baseline." -f $total, $files.Count, $Group, $groupNoun)
exit 0
