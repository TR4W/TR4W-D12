<#
.SYNOPSIS
   Types a county-line exchange into the running program and asserts that ONE
   exchange produced SEVERAL QSOs, each in its own county and all sharing the
   received serial number.

.DESCRIPTION
   Naming more than one county in a single exchange -- "32 SUTT/TEHA", a station
   working from a county line -- must log one QSO per county.  It reached only
   the RST-style QSO parties until 2026-08-31; the serial-number parties (CQP,
   PA, VA) validated the exchange, logged ONE QSO in the first county, and
   dropped the rest with no warning.  FoundDomesticQTH truncates at the '/', so
   nothing looked wrong.

   NOTHING AUTOMATED COULD SEE THAT, WHICH IS WHY THIS EXISTS.  The golden corpus
   reads finished ADIF and Cabrillo from logs written earlier, so it can only
   catch a change against a frozen reference -- there is no CQP set.  The unit
   tests cannot reach LOGSTUFF.PAS at all: the harness links only leaf units and
   the exchange parsers need the app's globals booted.  So the behaviour was
   verified by hand on a D7 build and by hand again here, twice, which is exactly
   the loop this script is meant to close.

   ASSERTING ON THE LOG, NOT ON THE LOG FILE.  [LogContact] emits one line per
   QSO actually written, and the pending-county drain calls LogContact once per
   queued county -- so the count, the counties and the serial are all readable
   without parsing a binary .dat or waiting for an export.  Reading the QSO back
   from the display would prove less and break on any layout change.

   THE CALLSIGN MUST BE A CALIFORNIA STATION for the CQP case: the exchange is
   QSONumberDomesticOrDXQTHExchange, and only the domestic branch parses
   counties.  W6TG is used by default for that reason.

   COUNTY ABBREVIATIONS ARE FOUR LETTERS in california_cty.dom -- SLUI is San
   Luis Obispo, MONT is Monterey.  SLO and MTY are not valid and will parse as
   nothing, which reads like a code failure and is not.

   REQUIRES DEBUG LOGGING; reports INCONCLUSIVE rather than FAIL without it.

   .\Test-CountyLineEntry.ps1
   .\Test-CountyLineEntry.ps1 -Call W6TG -Exchange "23 MADE/MARN/MARP/MEND" -ExpectCounties MADE,MARN,MARP,MEND
#>

param(
   [string]   $Repo = (Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent),
   [string]   $Exe,
   # Defaults to the CQP config this script stages; pass one to use your own.
   [string]   $Config,
   [string]   $Call     = 'W6TG',
   [string]   $Exchange = '32 SUTT/TEHA',
   # A COMMA-SEPARATED STRING, NOT string[].  PowerShell -File cannot bind an
   # array from the command line: "MADE,MARN" arrives as ONE element and the
   # comparison then fails against a county literally named "MADE,MARN".
   [string]   $ExpectCounties = 'SUTT,TEHA',
   [int]      $ExpectSerial   = 32,
   [int]      $SettleMs = 8000,
   [switch]   $KeepOpen,
   # Runs the whole set below instead of one case.  These are the cases NY4I
   # verified by hand on the D7 build; keeping them in one switch is what makes
   # them cheap enough to actually run before a release.
   [switch]   $AllCases,
   # THE NEGATIVE CONTROL.  Expect the exchange to be REFUSED: no QSO written
   # and the parser's own complaint in the log.  A suite that has never failed
   # has not been shown to be capable of failing.
   [switch]   $ExpectReject,
   # A token the exchange named that is NOT a known QTH.  The QSO still stands
   # on its valid counties, but the operator must be TOLD what was ignored --
   # a mistyped second county used to vanish in silence, costing a QSO nobody
   # could see was missing.
   [string]   $ExpectIgnored = '',
   # KEEP THE PREVIOUS RUN'S LOG instead of starting clean, so the next launch
   # RESUMES a contest rather than beginning one.  That is the only way to
   # exercise the shadow database's plain-reopen path: with the .TRW deleted the
   # record counts disagree, the drift check fires, and the shadow is REBUILT --
   # a different path that recreates the file.  Expect the QSO assertions to
   # fail on a repeat run with the same callsign (the counties are already in
   # the exchange window); this switch is for inspecting what a REOPEN does to
   # the database, not for asserting on the entry.
   [switch]   $KeepLog
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($AllCases)
   {
   # Re-invoked per case rather than looped in-process: each case needs a fresh
   # program and an empty log, which is exactly what one run of this script is.
   $cases = @(
      @{ Ex = '32 SUTT/TEHA';           Cty = 'SUTT,TEHA';           Nr = 32;  Note = 'two counties, slash, with the space an operator types' }
      @{ Ex = '32SUTT/TEHA';            Cty = 'SUTT,TEHA';           Nr = 32;  Note = 'same, typed hard against the number -- the digit-split path' }
      @{ Ex = '32 SUTT TEHA';           Cty = 'SUTT,TEHA';           Nr = 32;  Note = 'space-separated, no slash' }
      @{ Ex = '23 MADE/MARN/MARP/MEND'; Cty = 'MADE,MARN,MARP,MEND'; Nr = 23;  Note = 'four counties' }
      @{ Ex = '123 STAN';               Cty = 'STAN';                Nr = 123; Note = 'ordinary single county -- must still log exactly one' }
      # SLO and MTY are the abbreviations people REACH FOR and they are wrong:
      # california_cty.dom uses four letters, SLUI and MONT.  So this is both the
      # negative control and a real operator mistake.
      @{ Ex = '32 SLO/MTY';             Cty = '';                    Nr = 0;   Reject = $true; Note = 'INVALID counties -- must be refused, with a reason' }
      @{ Ex = '32 SLUI/MTY';            Cty = 'SLUI';                Nr = 32;  Ignored = 'MTY'; Note = 'one valid county, one typo -- log the good one, REPORT the bad one' }
   )
   $failed = 0
   foreach ($c in $cases)
      {
      Write-Output ''
      Write-Output ("=== {0}   ({1})" -f $c.Ex, $c.Note)
      if ($c.ContainsKey('Reject'))
         {
         & $PSCommandPath -Exchange $c.Ex -ExpectReject -Repo $Repo -Exe $Exe -Call $Call
         }
      else
         {
         $ignored = ''
         if ($c.ContainsKey('Ignored')) { $ignored = $c.Ignored }
         & $PSCommandPath -Exchange $c.Ex -ExpectCounties $c.Cty -ExpectSerial $c.Nr `
                          -ExpectIgnored $ignored -Repo $Repo -Exe $Exe -Call $Call
         }
      if ($LASTEXITCODE -ne 0) { $failed++ }
      }
   Write-Output ''
   if ($failed -gt 0)
      {
      Write-Output "Test-CountyLineEntry: $failed of $($cases.Count) case(s) FAILED"
      exit 1
      }
   Write-Output "Test-CountyLineEntry: all $($cases.Count) county-line cases PASS"
   exit 0
   }
Import-Module (Join-Path $PSScriptRoot 'UiDriver.psm1') -Force

# Split here rather than in the param block: PowerShell -File binds every
# argument as a STRING, so a comma list arrives as one element and the county
# comparison then looks for a county literally named "MADE,MARN,MARP,MEND".
$wantCounties = @($ExpectCounties -split ',' |
                  ForEach-Object { $_.Trim() } |
                  Where-Object { $_ -ne '' })

Add-Type -Namespace W -Name Cty -MemberDefinition @'
public delegate bool EnumProc(System.IntPtr h, System.IntPtr p);
[DllImport("user32.dll")] public static extern bool EnumChildWindows(System.IntPtr p, EnumProc cb, System.IntPtr l);
[DllImport("user32.dll")] public static extern int GetDlgCtrlID(System.IntPtr h);
[DllImport("user32.dll")] public static extern bool PostMessageW(System.IntPtr h, uint m, System.IntPtr w, System.IntPtr l);
[DllImport("user32.dll")] public static extern bool IsWindowVisible(System.IntPtr h);
'@

# VC.pas:471-472, the same ids Test-Typing.ps1 uses.
$CALLSIGNWINDOWID = 73
$EXCHANGEWINDOWID = 88
$WM_CHAR          = 0x0102
# VC.pas:2675.  Enter is delivered as an accelerator command, not a key.
$TR4W_ACCEL_VKRETURN = 10651

$target = Join-Path $Repo 'tr4w\target'
$Exe    = Resolve-TR4WExe -Exe $Exe -Repo $Repo

# A CQP config, WRITTEN RATHER THAN COPIED FROM THE BENCH MACHINE.  The corpus
# has no California set, and a harness that needs a file only one PC has is a
# harness that does not run on the CI runner.  Modelled on the Florida QP corpus
# config, which is the same shape.
if (-not $Config)
   {
   $Config  = 'uitest-cqp.cfg'
   $cqpPath = Join-Path $target $Config
   if (-not (Test-Path -LiteralPath $cqpPath))
      {
      # MY STATE is deliberately NOT California: an out-of-state entrant is the
      # side that RECEIVES a serial and a county, which is the case under test.
      $body = @(
         ';Written by Test-CountyLineEntry.ps1 -- safe to delete.'
         ''
         '[COMMANDS]'
         'MY CALL=NY4I'
         'MY STATE=FL'
         'CONTEST=CALIFORNIA QSO PARTY'
         'CATEGORY-OPERATOR=SINGLE-OP'
         'CATEGORY-BAND=ALL'
         'CATEGORY-MODE=SSB'
         'CATEGORY-POWER=HIGH'
         'CATEGORY-TRANSMITTER=ONE'
         'CATEGORY-ASSISTED=NON-ASSISTED'
      )
      # CRLF, like every other file this tree writes -- see Lint-LineEndings.
      [System.IO.File]::WriteAllText($cqpPath, (($body -join "`r`n") + "`r`n"))
      Write-Output "Test-CountyLineEntry: wrote $Config (California QSO Party)"
      }
   }

$cfgPath = Join-Path $target $Config
if (-not (Test-Path -LiteralPath $cfgPath))
   {
   Write-Output "Test-CountyLineEntry: no config at $cfgPath"
   exit 1
   }

# START FROM AN EMPTY LOG.  TR4W offers an initial exchange for a call it has
# already worked, so the SECOND run with the same callsign found the previous
# run's counties already in the exchange window and logged five QSOs instead
# of four.  Only this harness's own files are removed, never a real contest.
if (($Config -like 'uitest-*') -and (-not $KeepLog))
   {
   foreach ($ext in @('.TRW', '.RST', '.DAT', '.ADI', '.CBR'))
      {
      $stale = Join-Path $target ([System.IO.Path]::GetFileNameWithoutExtension($Config) + $ext)
      if (Test-Path -LiteralPath $stale) { Remove-Item -LiteralPath $stale -Force }
      }
   }

try { Assert-NoRunningTR4W } catch { Write-Output "Test-CountyLineEntry: $_"; exit 1 }

$log  = Join-Path $target 'tr4w.log'
$mark = Get-TR4WLogMark -LogPath $log

$started = Start-TR4WForDriving -Exe $Exe -TargetDir $target -ConfigPath $cfgPath -SettleMs $SettleMs -ExtraArgs 'DEBUG'
if ($started.Failure) { Write-Output "Test-CountyLineEntry: $($started.Failure)"; exit 1 }

$rc = 0

function Send-Text
{
   param([IntPtr] $Hwnd, [string] $Text)
   foreach ($ch in $Text.ToCharArray())
      {
      [void][W.Cty]::PostMessageW($Hwnd, $WM_CHAR, [IntPtr][int][char]$ch, [IntPtr]0)
      Start-Sleep -Milliseconds 40
      }
}

try
{
   # NAMED hCall / hExch, NOT call / exch.  PowerShell variable names are
   # CASE-INSENSITIVE, so $script:call and this script's own -Call parameter are
   # the SAME variable: the delegate overwrote the callsign with a window handle
   # and the run typed "41948776" into the call field.  Test-Typing.ps1 uses
   # $script:call safely only because its parameter is named $Text.
   $script:hCall = [IntPtr]::Zero
   $script:hExch = [IntPtr]::Zero
   $cb = [W.Cty+EnumProc]{
      param($h, $l)
      # CAST AT THE ASSIGNMENT. The delegate's untyped $h arrives boxed as a
      # String under StrictMode, and every later IntPtr call then fails to
      # convert it -- once here is cheaper than at each use.
      switch ([W.Cty]::GetDlgCtrlID($h)) {
         73 { $script:hCall = [IntPtr]$h }
         88 { $script:hExch = [IntPtr]$h }
      }
      return $true
   }
   # POLLED, NOT CHECKED ONCE.  Start-TR4WForDriving returns as soon as the MAIN
   # window exists, which is earlier than the entry fields being shown -- so a
   # single check passed when run alone and failed on the 3rd, 4th and 5th case
   # of -AllCases, where each launch follows a kill.  That reads as a program
   # fault and is a harness race.  Re-enumerated each pass because the handles
   # do not exist until the controls do.
   $callH    = [IntPtr]::Zero
   $exchH    = [IntPtr]::Zero
   $deadline = (Get-Date).AddMilliseconds(10000)

   while ((Get-Date) -lt $deadline)
      {
      $script:hCall = [IntPtr]::Zero
      $script:hExch = [IntPtr]::Zero
      [void][W.Cty]::EnumChildWindows($started.Hwnd, $cb, [IntPtr]::Zero)

      # NORMALISED HERE.  A value set inside the delegate comes back boxed as a
      # String however it was cast at the assignment, and every later IntPtr
      # call then refuses to convert it.  Int64 is the round trip that holds.
      $callH = [IntPtr][int64]"$script:hCall"
      $exchH = [IntPtr][int64]"$script:hExch"

      if (($callH -ne [IntPtr]::Zero) -and ($exchH -ne [IntPtr]::Zero) -and
          [W.Cty]::IsWindowVisible($callH))
         {
         break
         }
      Start-Sleep -Milliseconds 150
      }

   if ($callH -eq [IntPtr]::Zero -or $exchH -eq [IntPtr]::Zero)
      {
      Write-Output "Test-CountyLineEntry: FAIL -- callsign (id $CALLSIGNWINDOWID) or exchange (id $EXCHANGEWINDOWID) window never appeared"
      Stop-TR4WForDriving -Process $started.Process
      exit 1
      }
   if (-not [W.Cty]::IsWindowVisible($callH))
      {
      Write-Output 'Test-CountyLineEntry: FAIL -- the callsign window exists but never became VISIBLE'
      Stop-TR4WForDriving -Process $started.Process
      exit 1
      }

   Write-Output ("typing call '{0}' then exchange '{1}'" -f $Call, $Exchange)

   Send-Text -Hwnd $callH -Text $Call
   Start-Sleep -Milliseconds 400

   # THE OPERATOR'S SEQUENCE, NOT A SHORTCUT: call, Enter, exchange, Enter.
   # In CQ mode the first Enter sends the exchange and only the second logs the
   # QSO; sending one Enter after the exchange logged nothing and looked like a
   # parser failure.  ReturnInSAPOpMode traces itself, ReturnInCQOpMode does
   # not, which is how the mode in play was identified.
   Send-TR4WMenuCommand -Hwnd $started.Hwnd -Command $TR4W_ACCEL_VKRETURN
   Start-Sleep -Milliseconds 600

   # Posted straight at the exchange window rather than sending TAB: a
   # cross-process post cannot give a control real focus, so moving between
   # fields by keystroke is not reliable -- addressing the window by id is.
   Send-Text -Hwnd $exchH -Text $Exchange
   Start-Sleep -Milliseconds 400

   # RETURN IS AN ACCELERATOR, NOT A KEYSTROKE.  Posting WM_CHAR #13 at the
   # exchange window does nothing at all: Enter reaches the logger as a
   # WM_COMMAND carrying tr4w_accelerator_vkreturn (VC.pas:2675), which
   # MainUnit dispatches to ProcessReturn -> ReturnIn{CQ,SAP}OpMode ->
   # TryLogContact.  Sent at the MAIN window, like a menu command.
   Send-TR4WMenuCommand -Hwnd $started.Hwnd -Command $TR4W_ACCEL_VKRETURN
   Start-Sleep -Milliseconds 1500

   $written = Get-TR4WLogSince -LogPath $log -Mark $mark
   $qsos = @($written -split "`n" |
             Where-Object { $_ -match '\[LogContact\] QSO call=(\S+) qth=(\S*) rst=(-?\d+) nr=(-?\d+)' } |
             ForEach-Object {
                [pscustomobject]@{ Call = $Matches[1]; QTH = $Matches[2]; RST = [int]$Matches[3]; NR = [int]$Matches[4] }
             })

   if ($ExpectReject)
      {
      # The parser names itself when it refuses -- LOGSTUFF.PAS logs
      # "Improper Domestic QTH" and sets ExchangeErrorMessage.  Both halves are
      # asserted: a refusal that logged a QSO anyway is the silent-drop defect
      # this whole area exists to prevent.
      $complained = ($written -match 'Improper Domestic QTH')

      foreach ($q in $qsos)
         {
         Write-Output ("  logged (UNEXPECTED): call={0} qth={1} nr={2}" -f $q.Call, $q.QTH, $q.NR)
         }

      if ($qsos.Count -gt 0)
         {
         Write-Output "Test-CountyLineEntry: FAIL -- '$Exchange' was accepted and logged $($qsos.Count) QSO(s); it should have been refused."
         $rc = 1
         }
      elseif (-not $complained)
         {
         Write-Output "Test-CountyLineEntry: FAIL -- '$Exchange' logged no QSO, but the parser never reported an improper domestic QTH."
         Write-Output '  Silence is the failure mode here: the operator gets no QSO and no reason.'
         $rc = 1
         }
      else
         {
         Write-Output "Test-CountyLineEntry: PASS -- '$Exchange' was refused, and the parser said why."
         }
      }
   elseif ($qsos.Count -eq 0)
      {
      Write-Output 'Test-CountyLineEntry: INCONCLUSIVE -- no "[LogContact] QSO" line at all.'
      Write-Output '  Either nothing was logged, or debug logging is off.'
      Write-Output '  Set DEBUG LOG LEVEL = DEBUG under [COMMANDS] in settings\tr4w.ini and re-run.'
      $rc = 2
      }
   else
      {
      foreach ($q in $qsos)
         {
         Write-Output ("  logged: call={0} qth={1} nr={2}" -f $q.Call, $q.QTH, $q.NR)
         }

      $failures = New-Object System.Collections.Generic.List[string]

      if ($qsos.Count -ne $wantCounties.Count)
         {
         $failures.Add("expected $($wantCounties.Count) QSO(s) from one exchange, got $($qsos.Count)")
         }

      $gotCounties = @($qsos | ForEach-Object { $_.QTH.ToUpper() })
      # The ignored token is asserted alongside the QSOs, not instead of them:
      # logging the good county and reporting the bad one are both required, and
      # checking only one of the two would pass on the silent-drop behaviour.
      if ($ExpectIgnored -and ($written -notmatch "Ignored unrecognised QTH token\(s\): .*$([regex]::Escape($ExpectIgnored))"))
         {
         $failures.Add("'$ExpectIgnored' was not reported as an unrecognised QTH -- it was dropped silently")
         }

      foreach ($want in $wantCounties)
         {
         if ($gotCounties -notcontains $want.ToUpper())
            {
            $failures.Add("county $want was not logged (got: $($gotCounties -join ', '))")
            }
         }

      # THE SHARED SERIAL IS THE POINT, not a detail: every leg of a county-line
      # QSO is the same contact, so they all carry the number that station sent.
      foreach ($q in $qsos)
         {
         if ($q.NR -ne $ExpectSerial)
            {
            $failures.Add("QSO in $($q.QTH) carries serial $($q.NR), expected $ExpectSerial")
            }
         }

      Write-Output ''
      if ($failures.Count -gt 0)
         {
         foreach ($f in $failures) { Write-Output "  FAIL: $f" }
         Write-Output 'Test-CountyLineEntry: FAIL'
         $rc = 1
         }
      else
         {
         Write-Output ("Test-CountyLineEntry: PASS -- '{0}' logged {1} QSOs ({2}), all with serial {3}." -f `
                       $Exchange, $qsos.Count, ($gotCounties -join ' + '), $ExpectSerial)
         if ($ExpectIgnored) { Write-Output "  and reported the ignored token: $ExpectIgnored" }
         }
      }
}
finally
{
   if (-not $KeepOpen) { Stop-TR4WForDriving -Process $started.Process }
}

exit $rc
