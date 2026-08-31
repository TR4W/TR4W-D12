<#
.SYNOPSIS
   Opens Preferences in the running program and asserts the CW output dropdown
   resolved every radio it was handed, and offered CW by CAT where the radio
   declares it.

.DESCRIPTION
   THE REGRESSION THIS GUARDS IS A SILENT ONE, and it shipped.  FillCWOutputCombo
   took the radio's DISPLAY NAME and resolved it with a name-only lookup, while
   the interactive path handed it the combo's tag -- which is the radio's ID.  A
   radio id is a GUID and its name is an operator-chosen label, so the two can
   never coincide: the lookup returned nil, the whole radio-relative block was
   skipped, and neither "CW by CAT" nor the radio keyer port was offered.

   Nothing failed.  The dropdown was simply two entries short, and it looked for
   all the world like the radio lacked a capability it declares.  NY4I found it
   on the bench with an IC-7100 on 2026-08-31; no lint, unit test or corpus set
   could have seen it, because all of them are blind to the UI.

   ASSERTING ON THE LOG, NOT ON THE COMBO'S CONTENTS.  Reading the items back
   cross-process is not available: an LCL TComboBox keeps its item TAGS in a side
   list inside the process, and CB_GETLBTEXT needs a buffer in the target's
   address space.  So the form says what it did and this reads that back -- the
   same contract Test-Typing.ps1 uses, and for the same reason.

   THE CAPABILITY IS NOT RE-ENCODED HERE.  The form logs declaresCAT from the
   very call it uses to decide, so this asserts an internal invariant -- "if the
   radio declares CW by CAT, the operator was offered it" -- rather than keeping
   a second list of which radios can key over CAT.  A second list would drift,
   and that is the class of defect this file exists to catch.

   WHAT IT COVERS: the profile-load path, which fills both slots' dropdowns when
   Preferences opens.  The interactive radio-change path shares the same routine
   and the same log line, so a re-break there shows up as UNRESOLVED too -- but
   driving a combo selection cross-process needs real focus, which a posted
   message cannot give, so that path is not exercised here.  Stated plainly
   rather than left to be assumed.

   REQUIRES DEBUG LOGGING.  Without it the form runs and says nothing, and this
   reports INCONCLUSIVE rather than a failure that is really a config difference.

   .\Test-CWOutputCombo.ps1
   .\Test-CWOutputCombo.ps1 -Config "CALIFORNIA QSO PARTY.CFG"
#>

param(
   [string] $Repo = (Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent),
   [string] $Exe,
   [string] $Config,
   [int]    $SettleMs = 8000,
   # How long to let Preferences build itself before reading the log.  The form
   # fills combos on show; 2.5s is generous on the slowest machine measured.
   [int]    $PrefsMs  = 2500,
   [switch] $KeepOpen
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'UiDriver.psm1') -Force

# VC.pas:2534.  By id, not by walking the menu: the id is stable and the menu
# text is translated.
$MENU_RADIO_PREFERENCES = 10111

$target = Join-Path $Repo 'tr4w\target'
$Exe    = Resolve-TR4WExe -Exe $Exe -Repo $Repo

$cfg = Resolve-TR4WHarnessConfig -Repo $Repo -TargetDir $target -Config $Config -Caller 'Test-CWOutputCombo'
if ($cfg.Message) { Write-Output "Test-CWOutputCombo: $($cfg.Message)" }
if ($cfg.Failure)
   {
   Write-Output "Test-CWOutputCombo: $($cfg.Failure)"
   exit 1
   }
$Config = $cfg.Config

try { Assert-NoRunningTR4W } catch { Write-Output "Test-CWOutputCombo: $_"; exit 1 }

$log  = Join-Path $target 'tr4w.log'
$mark = Get-TR4WLogMark -LogPath $log

$started = Start-TR4WForDriving -Exe $Exe -TargetDir $target `
                                -ConfigPath (Join-Path $target $Config) -SettleMs $SettleMs -ExtraArgs 'DEBUG'
if ($started.Failure) { Write-Output "Test-CWOutputCombo: $($started.Failure)"; exit 1 }

$rc = 0

try
{
   Send-TR4WMenuCommand -Hwnd $started.Hwnd -Command $MENU_RADIO_PREFERENCES
   Start-Sleep -Milliseconds $PrefsMs

   $written = Get-TR4WLogSince -LogPath $log -Mark $mark
   $lines   = @($written -split "`n" | Where-Object { $_ -match '\[Prefs\] CW output combo:' })

   if ($lines.Count -eq 0)
      {
      Write-Output 'Test-CWOutputCombo: INCONCLUSIVE -- no "[Prefs] CW output combo" line at all.'
      Write-Output '  Either Preferences did not open, or debug logging is off.'
      Write-Output '  Set DEBUG LOG LEVEL = DEBUG under [COMMANDS] in settings\tr4w.ini and re-run.'
      $rc = 2
      }
   else
      {
      # The form logs the resolution, then the item list, per combo -- so the
      # offering that belongs to a radio is the next offering line after it.
      $pending  = $null
      $failures = New-Object System.Collections.Generic.List[string]
      $checked  = 0

      foreach ($line in $lines)
         {
         if ($line -match 'radio id=(\S+) UNRESOLVED')
            {
            $failures.Add("radio id $($Matches[1]) did not resolve -- the name/id defect is back")
            $pending = $null
            continue
            }

         if ($line -match 'radio id=(\S+) resolved name=(.+?) registryId=(\S+) declaresCAT=(\S+)')
            {
            $pending = [pscustomobject]@{
               Id = $Matches[1]; Name = $Matches[2].Trim()
               RegistryId = $Matches[3]; DeclaresCAT = ($Matches[4].Trim() -eq 'True')
            }
            continue
            }

         if ($line -match 'offering \[(.*)\]')
            {
            $offering = $Matches[1]
            if ($null -ne $pending)
               {
               $checked++
               $hasCAT = ($offering -match 'CW by CAT')
               Write-Output ("  {0} ({1}): declaresCAT={2}, offered=[{3}]" -f `
                             $pending.Name, $pending.RegistryId, $pending.DeclaresCAT, $offering)

               if ($pending.DeclaresCAT -and (-not $hasCAT))
                  {
                  $failures.Add("$($pending.Name) ($($pending.RegistryId)) declares CW by CAT but it was NOT offered")
                  }
               if ((-not $pending.DeclaresCAT) -and $hasCAT)
                  {
                  $failures.Add("$($pending.Name) ($($pending.RegistryId)) does NOT declare CW by CAT but it was offered")
                  }
               $pending = $null
               }
            }
         }

      Write-Output ''
      Write-Output ("radios checked: {0}" -f $checked)

      if ($checked -eq 0 -and $failures.Count -eq 0)
         {
         # Both slots empty is a legitimate profile state, but it proves nothing,
         # so do not report it as a pass.
         Write-Output 'Test-CWOutputCombo: INCONCLUSIVE -- Preferences opened but no profile slot named a radio.'
         Write-Output '  Select a profile with radios assigned, or pass -Config for one that has them.'
         $rc = 2
         }
      elseif ($failures.Count -gt 0)
         {
         foreach ($f in $failures) { Write-Output "  FAIL: $f" }
         Write-Output 'Test-CWOutputCombo: FAIL'
         $rc = 1
         }
      else
         {
         Write-Output 'Test-CWOutputCombo: PASS -- every radio id resolved, and CW by CAT matched what each radio declares.'
         }
      }
}
finally
{
   if (-not $KeepOpen) { Stop-TR4WForDriving -Process $started.Process }
}

exit $rc
