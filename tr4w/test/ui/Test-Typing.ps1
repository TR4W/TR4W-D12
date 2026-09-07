<#
.SYNOPSIS
   Types a callsign into the running program and asserts it arrived.

.DESCRIPTION
   The regression Phase 3b risks is specific and severe: THE CALLSIGN FIELD
   STOPS ACCEPTING TYPING. It is severe because it happens mid-contest, and it
   is easy to cause because the keyboard routing does not live in the control --
   it lives in TR4W's message loop, which compares Msg.HWND against wh[mweCall]
   and wh[mweExchange] in thirteen places and calls CallWindowKeyDownProc.

   When those controls become LCL controls their keystrokes arrive at their own
   OnKeyDown instead, and the loop's comparisons are DELETED rather than moved.
   Nothing the compiler, the unit tests or the corpus can see would notice if a
   path were missed.

   So: post WM_CHAR at the callsign window exactly as the keyboard would, let it
   travel the real path -- GetMessage in TR4W's own loop, the Msg.HWND
   comparison, CallWindowKeyDownProc -- and assert on TR4W'S OWN TRACE LINE,
   "[CallWindowKeyDownProc] Key pressed = X".

   ASSERTING ON THE LOG, NOT ON THE FIELD'S TEXT, and that is the whole
   difference between a test that means something and one that passes for the
   wrong reason.  Reading the Edit back with WM_GETTEXT was the first attempt and
   it reported an EMPTY field while the keystrokes were in fact being routed
   perfectly -- a cross-process post cannot give the control real focus, so its
   own default insertion never happens.  A test written that way would have
   failed on a healthy program, been "fixed" by loosening it, and then proved
   nothing.

   The trace line is also the RIGHT observable for what comes next: when the
   callsign window becomes an LCL TEdit its OnKeyDown calls the same handler, so
   this test keeps working across the conversion it exists to guard.  If the
   handler stops being reached, the line disappears and the test fails -- which
   is exactly the regression.

   WHY PostMessage AND NOT SendInput: PostMessage puts the message on the
   thread's queue, which is where GetMessage collects it, so the routing under
   test runs unchanged. SendInput would depend on real focus and on no other
   window being in front, which makes the test flaky for no gain.

   NOT COVERED, deliberately: this proves a character REACHES the field. It does
   not prove the QSO logs, the dupe check runs, or the exchange parses. Those
   need the contest engine, and the corpus already covers the engine.

   .\Test-Typing.ps1
   .\Test-Typing.ps1 -Text W1AW
#>

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
   [string] $Text = 'NY4I',
   [string] $Repo = (Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent),
   [string] $Exe,
   [string] $Config,
   [int]    $SettleMs = 8000
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'UiDriver.psm1') -Force

# VC.pas:471-472. By CONTROL ID, never by position or tab order: an id is stable
# across builds and across the Win32-to-LCL conversion, which is the whole point
# of being able to compare the two.
$CALLSIGNWINDOWID = 73
$EXCHANGEWINDOWID = 88

function Get-VisibleChildCount
{
   param([IntPtr] $Parent)
   $script:visCount = 0
   $cb = [Win32.UiDrv+EnumChildProc]{
      param($h, $l)
      if ([Win32.UiDrv]::IsWindowVisible($h)) { $script:visCount++ }
      return $true
   }
   [void][Win32.UiDrv]::EnumChildWindows($Parent, $cb, [IntPtr]::Zero)
   return $script:visCount
}

$target = Join-Path $Repo 'tr4w\target'
$Exe = Resolve-TR4WExe -Exe $Exe -Repo $Repo

# Shared -- see UiDriver.psm1.  This copy had no guard for a missing corpus
# set and died on a raw Copy-Item error; the shared one reports it.
$cfg = Resolve-TR4WHarnessConfig -Repo $Repo -TargetDir $target -Config $Config -Caller 'Test-Typing'
if ($cfg.Message) { Write-Output "Test-Typing: $($cfg.Message)" }
if ($cfg.Failure)
   {
   Write-Output "Test-Typing: $($cfg.Failure)"
   exit 1
   }
$Config = $cfg.Config

try { Assert-NoRunningTR4W } catch { Write-Output "Test-Typing: $_"; exit 1 }

$log  = Join-Path $target 'tr4w.log'
$mark = Get-TR4WLogMark -LogPath $log

$started = Start-TR4WForDriving -Exe $Exe -TargetDir $target `
                                -ConfigPath (Join-Path $target $Config) -SettleMs $SettleMs
if ($started.Failure) { Write-Output "Test-Typing: $($started.Failure)"; exit 1 }

try
{
   # SHARED AND POLLED -- see Find-TR4WEntryFields in UiDriver.psm1.
   #
   # This was a private single-shot enumeration, and it was the older half of a
   # drifted copy: the shared one was extracted on 2026-09-04 carrying three
   # corrections this one never received, the first of which is exactly the
   # failure seen here. Start-TR4WForDriving returns when the MAIN window
   # exists, which is earlier than the entry fields are shown, so a check that
   # looks only once reports "exists but is NOT VISIBLE" -- the precise symptom
   # of the bench defect this test guards, raised against a healthy program.
   #
   # Measured 2026-09-05: reproducible at the default -SettleMs 8000, and a pass
   # at 20000. That is a harness race wearing the costume of a regression.
   #
   # THE VISIBILITY ASSERTION BELOW IS DELIBERATELY KEPT. The helper polls and
   # then returns whatever it has, so a field that genuinely never appears still
   # reaches that check and still fails in this test's own words.
   $fields = Find-TR4WEntryFields -Hwnd $started.Hwnd `
                                  -CallId $CALLSIGNWINDOWID -ExchangeId $EXCHANGEWINDOWID
   $script:call = $fields.Call
   $script:exch = $fields.Exchange

   if ($script:call -eq [IntPtr]::Zero) {
      Write-Output "Test-Typing: FAIL -- no control with id $CALLSIGNWINDOWID (the callsign window) under the main window"
      exit 1
   }
   # VISIBLE, not merely present.  The LCL will not show a form's child controls
   # while the form's own Visible is False, and TR4W shows its main window with a
   # raw SetWindowPos the LCL cannot see -- so the entry fields existed at the
   # right id, size and position and were never drawn.  NY4I found that on the
   # bench, 2026-08-18; every check here passed, because none of them looked.
   if (-not [Win32.UiDrv]::IsWindowVisible($script:call)) {
      Write-Output "Test-Typing: FAIL -- the callsign window exists but is NOT VISIBLE"
      Stop-TR4WForDriving -Process $started.Process
      exit 1
   }
   Write-Output ("callsign window found and visible: id {0}" -f $CALLSIGNWINDOWID)

   $script:beforeTyping = Get-VisibleChildCount -Parent $started.Hwnd

   # WM_CHAR posted AT THE CALLSIGN WINDOW so Msg.HWND matches wh[mweCall] when
   # TR4W's loop collects it. Shared -- Send-TR4WText was character-for-character
   # this loop.
   Send-TR4WText -Hwnd $script:call -Text $Text -PerCharMs 60
   Start-Sleep -Milliseconds 800

   # Only what this run appended -- tr4w.log accumulates across sessions.
   # THE CALLSIGN ALSO HAS TO REACH THE DISPLAY, not just the handler.
   #
   # Typing a call makes TR4W reveal its QSO-need and multiplier-need windows
   # -- the "QSO needs for W8UHY: CW: 160 80 40 20 15 10" panel.  Those are raw
   # statics in their own arrays, shown with ShowWindow from LOGEDIT, and
   # nothing else here watches them.  NY4I reported them missing on 2026-08-18;
   # they proved present on the current build and absent on a stale one, which
   # is exactly the ambiguity a check removes.
   #
   # Counting VISIBLE children rather than naming windows: which ones appear
   # depends on the contest, the band plan and what has already been worked,
   # none of which this test should encode.  That MORE became visible is the
   # invariant.
   $afterTyping = Get-VisibleChildCount -Parent $started.Hwnd
   Write-Output ("visible children: {0} before typing, {1} after" -f $script:beforeTyping, $afterTyping)
   if ($afterTyping -le $script:beforeTyping) {
      Write-Output 'Test-Typing: FAIL -- typing a callsign revealed NO additional windows.'
      Write-Output '  The QSO-need / multiplier-need panels are the ones expected to appear.'
      Stop-TR4WForDriving -Process $started.Process
      exit 1
   }

   $written = Get-TR4WLogSince -LogPath $log -Mark $mark
   $seen = @($written -split "`n" |
             Where-Object { $_ -match '\[CallWindowKeyDownProc\] Key pressed = (.)' } |
             ForEach-Object { $Matches[1] })

   Write-Output ("typed '{0}'  ->  the loop routed [{1}]" -f $Text, ($seen -join ''))

   # REQUIRES TRACE LOGGING. Without it the handler runs and says nothing, and
   # this test would report a failure that is really a configuration difference
   # -- so say which it is.
   if ($seen.Count -eq 0) {
      Write-Output 'Test-Typing: INCONCLUSIVE -- no CallWindowKeyDownProc trace at all.'
      # NOT tr4w.ini, and NOT the contest .cfg. The level is a STRUCTURED
      # store key -- StartupLogLevel reads root['logging']['level'] out of
      # settings\tr4w.json during start-up. tr4w.ini stores nothing any
      # more, and a DEBUG LOG LEVEL line in the .cfg is accepted and logged
      # as "overrides the stored value for this contest" while changing
      # nothing: the logger's level is already fixed by then (measured
      # 2026-09-06 -- 86 debug lines, zero trace).
      Write-Output '  Set "level" : "TRACE" in the logging section of settings\tr4w.json and re-run.'
      $rc = 2
   }
   elseif (($seen -join '') -eq $Text.ToUpper()) {
      Write-Output 'Test-Typing: PASS -- every keystroke reached CallWindowKeyDownProc, in order'
      $rc = 0
   }
   else {
      Write-Output ("Test-Typing: FAIL -- expected [{0}]" -f $Text.ToUpper())
      $rc = 1
   }
}
finally
{
   Stop-TR4WForDriving -Process $started.Process
}
exit $rc
