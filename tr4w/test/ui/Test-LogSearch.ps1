<#
.SYNOPSIS
   Opens Search Log, types a callsign into it, and asserts the search actually
   ran and found the QSOs that are in the log.

.DESCRIPTION
   THE WINDOW WAS A WIN32 MODAL DIALOG AND IS NOW AN LCL FORM (uLogSearchForm),
   so everything about how it finds and shows results changed at once.  Neither
   gate that normally protects this tree can see any of it: the golden corpus
   runs the headless /EXPORT path and never creates a window, and the unit tests
   link leaf units only and cannot reach the log or the UI.

   ASSERTING ON THE LOG, NOT ON THE SCREEN.  The form reports each search --

      [LogSearch] call="W1AW" op="" band=.. mode=.. -> 3 match(es) in 66 record(s), 4 ms

   -- so the count, the scan size and the timing are all readable without
   scraping pixels or depending on a layout that is expected to change.

   THE SEARCH IS SEEDED FROM THE CALL WINDOW, which is what the Win32 version
   did, so this types the callsign into the MAIN window first and then opens
   the search.  That covers the seeding path as well as the search itself.

   A CONFIG IS REQUIRED, as for every harness here: with no argument TR4W stops
   on the "Open configuration file or start a new contest" dialog and the main
   window -- the one that owns the menu -- is never created.

   .\Test-LogSearch.ps1
   .\Test-LogSearch.ps1 -Call W1AW -ExpectAtLeast 1
#>

param(
   [string] $Repo = '',
   [string] $Exe  = '',
   [string] $Config = '',
   # A callsign that is IN the corpus log staged below.  Substring, as the
   # window searches: 'W' would match many.
   [string] $Call = 'W',
   [int]    $ExpectAtLeast = 1,
   [int]    $SettleMs = 8000,
   [switch] $KeepOpen
)

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
Import-Module (Join-Path $here 'UiDriver.psm1') -Force

if (-not $Repo) { $Repo = Split-Path (Split-Path (Split-Path $here -Parent) -Parent) -Parent }
$target = Join-Path $Repo 'tr4w\target'
$log    = Join-Path $target 'tr4w.log'

$Exe = Resolve-TR4WExe -Exe $Exe -Repo $Repo
if (-not (Test-Path $Exe)) { Write-Output "Test-LogSearch: no exe at $Exe"; exit 1 }

# The corpus set is the easy source of a log with QSOs in it.
if (-not $Config)
   {
   $Config = 'uitest-search.cfg'
   $src    = Join-Path $Repo 'tr4w\test\corpus\cqww_ssb_2025_ny4i'
   Copy-Item (Join-Path $src 'log.cfg') (Join-Path $target $Config) -Force
   Copy-Item (Join-Path $src 'log.trw') (Join-Path $target 'uitest-search.trw') -Force
   }

$cfgPath = Join-Path $target $Config
if (-not (Test-Path $cfgPath)) { Write-Output "Test-LogSearch: no config at $cfgPath"; exit 1 }

try { Assert-NoRunningTR4W } catch { Write-Output "Test-LogSearch: $_"; exit 1 }

$MENU_SEARCHLOG = 10309    # VC.pas menu_alt_searchlog

$mark    = Get-TR4WLogMark -LogPath $log
$started = Start-TR4WForDriving -Exe $Exe -TargetDir $target -ConfigPath $cfgPath -SettleMs $SettleMs
if ($started.Failure) { Write-Output "Test-LogSearch: $($started.Failure)"; exit 1 }

try
   {
   # INTO THE CALL FIELD ITSELF, by its control id -- posting to the main
   # window does not reach it, which is the first thing this harness got wrong.
   $fields = Find-TR4WEntryFields -Hwnd $started.Hwnd
   if ($fields.Call -eq [IntPtr]::Zero)
      {
      Write-Output 'Test-LogSearch: FAIL -- the callsign window never appeared'
      exit 1
      }

   # The search seeds from CallWindowString, so the callsign is typed into the
   # MAIN window before the search is opened. That covers the seeding path too.
   Send-TR4WText -Hwnd $fields.Call -Text $Call
   Start-Sleep -Milliseconds 400

   Send-TR4WMenuCommand -Hwnd $started.Hwnd -Command $MENU_SEARCHLOG
   Start-Sleep -Milliseconds 2000

   $written = Get-TR4WLogSince -LogPath $log -Mark $mark

   if ($written -match '\[CRASH\]')
      {
      Write-Output 'Test-LogSearch: FAIL -- the program faulted opening or running the search'
      exit 1
      }

   $opened = @($written -split "`n" | Where-Object { $_ -match '\[LogSearch\] window opened' })
   if ($opened.Count -eq 0)
      {
      Write-Output 'Test-LogSearch: FAIL -- the window never reported opening'
      exit 1
      }

   $runs = @($written -split "`n" |
             Where-Object { $_ -match '\[LogSearch\] call="([^"]*)".*-> (\d+) match\(es\) in (\d+) record\(s\), (\d+) ms' } |
             ForEach-Object {
                [pscustomobject]@{ Call = $Matches[1]; Matches = [int]$Matches[2]
                                   Scanned = [int]$Matches[3]; Ms = [int]$Matches[4] }
             })

   if ($runs.Count -eq 0)
      {
      Write-Output 'Test-LogSearch: FAIL -- the window opened but no search ran'
      Write-Output "  (seeded callsign was '$Call'; an empty seed runs no search by design)"
      exit 1
      }

   $last = $runs[-1]
   if ($last.Scanned -le 0)
      {
      Write-Output "Test-LogSearch: FAIL -- the search scanned $($last.Scanned) records; the log was not read"
      exit 1
      }

   if ($last.Matches -lt $ExpectAtLeast)
      {
      Write-Output ("Test-LogSearch: FAIL -- '{0}' matched {1}, expected at least {2} (scanned {3})" -f `
                    $last.Call, $last.Matches, $ExpectAtLeast, $last.Scanned)
      exit 1
      }

   Write-Output ("Test-LogSearch: PASS -- '{0}' matched {1} of {2} record(s) in {3} ms" -f `
                 $last.Call, $last.Matches, $last.Scanned, $last.Ms)
   }
finally
   {
   if (-not $KeepOpen) { Stop-TR4WForDriving -Process $started.Process }
   }
