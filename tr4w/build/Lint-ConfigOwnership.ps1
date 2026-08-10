<#
.SYNOPSIS
   Checks that every config key the radio library RENDERS still reaches the
   program -- either via CheckCommand (csOwned) or via the direct JSON applier
   (csJSON), and never via neither.

.DESCRIPTION
   Two editors now write the same settings. Preferences owns the radio library
   and renders it into the [Radio] ini keys; the Ctrl-J configuration-commands
   dialog lists those same keys and lets them be typed over. Whichever ran last
   wins, and nothing on either screen says so (NY4I, 2026-08-08).

   csOwned is the marking that resolves it: hidden from Ctrl-J, STILL APPLIED by
   CheckCommand.

   csJSON USED TO BE REJECTED OUTRIGHT HERE, and the reason is worth keeping,
   because it is still true wherever an applier is missing. CheckCommand treats
   csRem and csJSON as accepted-but-inert -- it returns True and exits without
   applying anything. At startup ApplyRadioToSlot runs with aPersist=False, so
   CheckCommand was for a long time the ONLY thing that configured the radios.
   Marking a row csJSON therefore disabled that setting entirely while every
   test still passed.

   THAT CHANGED WHEN THE DIRECT APPLIER LANDED (Set 1 of the RADIO ini->JSON
   retirement). ApplyJSONOwnedRadioKey in uRadioConfigApply.pas now assigns
   csJSON rows straight into the globals, so csJSON is legal -- BUT ONLY FOR A
   KEY THE APPLIER ACTUALLY HANDLES. A row flipped to csJSON with no matching
   case in the applier is the original silent failure exactly: stored correctly
   in JSON, shown correctly in Preferences, and never configuring anything.

   So the rule is no longer "csOwned or bust", it is "SOMETHING must apply
   this", and the lint reads the applier to find out which. That is the whole
   point of checking it here rather than trusting the pair to be edited
   together: the audit's rule is that the retirement and the applier ship in one
   commit, and this is what makes forgetting the applier a build failure instead
   of a bug report.

   THE KEY LIST IS DERIVED, not typed out: it comes from the KEYSPECS table in
   uRadioConfigLegacyMap.pas, which is what the renderer emits. A key added
   there is checked here automatically, which is the point -- the failure this
   guards against is someone adding a radio setting and not knowing that CFGCA
   needs marking too.

.PARAMETER SourceDir
   The src directory. Defaults to the one next to this script's parent.

.PARAMETER SelfTest
   Runs the rules against built-in fixtures instead of the source tree.

.OUTPUTS
   One line per violation. Exit code 0 = clean, 1 = at least one violation.
#>
[CmdletBinding()]
param(
   [string] $SourceDir,
   [switch] $SelfTest
)

# The suffixes the renderer emits, straight out of its KEYSPECS table.
function Get-RenderedSuffixes {
   param([string] $LegacyMapText)

   $result = @()
   $m = [regex]::Match($LegacyMapText, '(?s)KEYSPECS:\s*array\[[^\]]*\]\s*of\s*TKeySpec\s*=\s*\((.*?)\n   \);')
   if (-not $m.Success) {
      return $result
   }
   foreach ($k in [regex]::Matches($m.Groups[1].Value, "Suffix:\s*'([^']*)'")) {
      if ($k.Groups[1].Value -ne '') {
         $result += $k.Groups[1].Value
      }
   }
   return $result
}

# command name -> status, for every CFGCA row.
function Get-CommandStatuses {
   param([string] $CfgText)

   $map = @{}
   foreach ($m in [regex]::Matches($CfgText, "crCommand:\s*'([^']+)'.*?crS:\s*(cs\w+)")) {
      $map[$m.Groups[1].Value.ToUpper()] = $m.Groups[2].Value
   }
   return $map
}

# The key suffixes ApplyJSONOwnedRadioKey handles, read from its source.
#
# Derived rather than listed for the same reason the rendered suffixes are: a
# hand-maintained copy is a third place to keep in step, and it will not be.
function Get-AppliedSuffixes {
   param([string] $ApplyText)

   $result = @()
   foreach ($m in [regex]::Matches($ApplyText, "SameText\(aSuffix,\s*'([^']+)'\)")) {
      if ($result -notcontains $m.Groups[1].Value) {
         $result += $m.Groups[1].Value
      }
   }
   return $result
}

function Test-Ownership {
   param([string] $LegacyMapText, [string] $CfgText, [string] $ApplyText = '')

   $violations = @()
   $suffixes = Get-RenderedSuffixes -LegacyMapText $LegacyMapText
   $statuses = Get-CommandStatuses -CfgText $CfgText
   $applied  = Get-AppliedSuffixes -ApplyText $ApplyText

   if ($suffixes.Count -eq 0) {
      return @('Lint-ConfigOwnership: could not read KEYSPECS from uRadioConfigLegacyMap.pas - the lint is not checking anything')
   }

   # Key plus the suffix the applier would see. For the two shapes that are not
   # RADIO-prefixed the suffix IS the whole key, which is exactly what the
   # Pascal KeySuffix returns for them -- deliberately, so an unhandled one
   # falls into the applier's loud else-branch instead of matching by accident.
   $keys = @()
   foreach ($slot in @('ONE', 'TWO')) {
      foreach ($s in $suffixes) {
         $keys += [pscustomobject]@{ Key = "RADIO $slot $s"; Suffix = $s }
      }
      $keys += [pscustomobject]@{ Key = "KEYER RADIO $slot OUTPUT PORT"
                                  Suffix = "KEYER RADIO $slot OUTPUT PORT" }
      $keys += [pscustomobject]@{ Key = "POLL RADIO $slot"; Suffix = "POLL RADIO $slot" }
   }

   foreach ($k in $keys) {
      $u = $k.Key.ToUpper()
      if (-not $statuses.ContainsKey($u)) {
         $violations += "$($k.Key) is rendered by the radio library but has no CFGCA row"
         continue
      }
      $st = $statuses[$u]
      if ($st -eq 'csJSON') {
         # Legal ONLY if something applies it. CheckCommand will not.
         if ($applied -notcontains $k.Suffix) {
            $violations += "$($k.Key) is csJSON, which CheckCommand treats as INERT, and ApplyJSONOwnedRadioKey has no case for '$($k.Suffix)' - the setting would silently never reach the program; add the applier or use csOwned"
         }
      }
      elseif ($st -ne 'csOwned') {
         $violations += "$($k.Key) is $st, so Ctrl-J can still edit what Preferences owns - mark it csOwned"
      }
   }
   return $violations
}

# ---------------------------------------------------------------- self test --

function Invoke-SelfTest {
   $mapOK = @"
   KEYSPECS: array[0..1] of TKeySpec = (
      (Shape: ksRadioPrefixed;   Suffix: 'BAUD RATE'),
      (Shape: ksKeyerOutputPort; Suffix: '')
   );
"@

   $fixtures = @(
      @{ Name = 'all_owned'; Expect = 0
         Cfg = @"
 (crCommand: 'RADIO ONE BAUD RATE'; crS: csOwned),
 (crCommand: 'RADIO TWO BAUD RATE'; crS: csOwned),
 (crCommand: 'KEYER RADIO ONE OUTPUT PORT'; crS: csOwned),
 (crCommand: 'KEYER RADIO TWO OUTPUT PORT'; crS: csOwned),
 (crCommand: 'POLL RADIO ONE'; crS: csOwned),
 (crCommand: 'POLL RADIO TWO'; crS: csOwned),
"@ },

      # The state this lint was written for: still editable in Ctrl-J.
      @{ Name = 'one_still_csOld'; Expect = 1
         Cfg = @"
 (crCommand: 'RADIO ONE BAUD RATE'; crS: csOld),
 (crCommand: 'RADIO TWO BAUD RATE'; crS: csOwned),
 (crCommand: 'KEYER RADIO ONE OUTPUT PORT'; crS: csOwned),
 (crCommand: 'KEYER RADIO TWO OUTPUT PORT'; crS: csOwned),
 (crCommand: 'POLL RADIO ONE'; crS: csOwned),
 (crCommand: 'POLL RADIO TWO'; crS: csOwned),
"@ },

      # The dangerous one: hidden AND inert, with nothing else applying it.
      @{ Name = 'csJSON_without_an_applier_is_rejected'; Expect = 1
         Cfg = @"
 (crCommand: 'RADIO ONE BAUD RATE'; crS: csJSON),
 (crCommand: 'RADIO TWO BAUD RATE'; crS: csOwned),
 (crCommand: 'KEYER RADIO ONE OUTPUT PORT'; crS: csOwned),
 (crCommand: 'KEYER RADIO TWO OUTPUT PORT'; crS: csOwned),
 (crCommand: 'POLL RADIO ONE'; crS: csOwned),
 (crCommand: 'POLL RADIO TWO'; crS: csOwned),
"@ },

      # The same row, now legal, because the applier handles it. This pair is
      # the whole point of the lint: the ONLY difference between them is
      # whether ApplyJSONOwnedRadioKey names the suffix.
      @{ Name = 'csJSON_WITH_an_applier_is_allowed'; Expect = 0
         Apply = "if SameText(aSuffix, 'BAUD RATE') then"
         Cfg = @"
 (crCommand: 'RADIO ONE BAUD RATE'; crS: csJSON),
 (crCommand: 'RADIO TWO BAUD RATE'; crS: csJSON),
 (crCommand: 'KEYER RADIO ONE OUTPUT PORT'; crS: csOwned),
 (crCommand: 'KEYER RADIO TWO OUTPUT PORT'; crS: csOwned),
 (crCommand: 'POLL RADIO ONE'; crS: csOwned),
 (crCommand: 'POLL RADIO TWO'; crS: csOwned),
"@ },

      # Half-migrated: applier written for one suffix, a DIFFERENT row flipped.
      # Catches the copy-paste slip of flipping the wrong line.
      @{ Name = 'applier_for_the_wrong_suffix_is_rejected'; Expect = 1
         Apply = "if SameText(aSuffix, 'TCP PORT') then"
         Cfg = @"
 (crCommand: 'RADIO ONE BAUD RATE'; crS: csJSON),
 (crCommand: 'RADIO TWO BAUD RATE'; crS: csOwned),
 (crCommand: 'KEYER RADIO ONE OUTPUT PORT'; crS: csOwned),
 (crCommand: 'KEYER RADIO TWO OUTPUT PORT'; crS: csOwned),
 (crCommand: 'POLL RADIO ONE'; crS: csOwned),
 (crCommand: 'POLL RADIO TWO'; crS: csOwned),
"@ },

      @{ Name = 'missing_row'; Expect = 1
         Cfg = @"
 (crCommand: 'RADIO ONE BAUD RATE'; crS: csOwned),
 (crCommand: 'KEYER RADIO ONE OUTPUT PORT'; crS: csOwned),
 (crCommand: 'KEYER RADIO TWO OUTPUT PORT'; crS: csOwned),
 (crCommand: 'POLL RADIO ONE'; crS: csOwned),
 (crCommand: 'POLL RADIO TWO'; crS: csOwned),
"@ }
   )

   $failed = 0
   foreach ($f in $fixtures) {
      $apply = ''
      if ($f.ContainsKey('Apply')) { $apply = $f.Apply }
      $v = @(Test-Ownership -LegacyMapText $mapOK -CfgText $f.Cfg -ApplyText $apply)
      if ($v.Count -ne $f.Expect) {
         Write-Output ("SELFTEST FAIL {0}: expected {1}, got {2}" -f $f.Name, $f.Expect, $v.Count)
         $v | ForEach-Object { Write-Output ("   " + $_) }
         $failed++
      }
      else {
         Write-Output ("SELFTEST ok   {0} ({1} violation(s))" -f $f.Name, $v.Count)
      }
   }

   if ($failed -gt 0) {
      Write-Output ("Lint-ConfigOwnership SELFTEST: {0} fixture(s) failed." -f $failed)
      exit 1
   }
   Write-Output ("Lint-ConfigOwnership SELFTEST: all {0} fixtures behaved as documented." -f $fixtures.Count)
   exit 0
}

# --------------------------------------------------------------------- main --

if ($SelfTest) {
   Invoke-SelfTest
}

if (-not $SourceDir) {
   $SourceDir = Join-Path (Split-Path -Parent $PSScriptRoot) 'src'
}

$mapFile   = Join-Path $SourceDir 'uRadioConfigLegacyMap.pas'
$cfgFile   = Join-Path $SourceDir 'uCFG.pas'
$applyFile = Join-Path $SourceDir 'uRadioConfigApply.pas'

foreach ($f in @($mapFile, $cfgFile, $applyFile)) {
   if (-not (Test-Path -LiteralPath $f)) {
      Write-Output ("Lint-ConfigOwnership: not found: {0}" -f $f)
      exit 1
   }
}

$violations = @(Test-Ownership -LegacyMapText (Get-Content -LiteralPath $mapFile -Raw) `
                               -CfgText       (Get-Content -LiteralPath $cfgFile -Raw) `
                               -ApplyText     (Get-Content -LiteralPath $applyFile -Raw))

if ($violations.Count -gt 0) {
   $violations | ForEach-Object { Write-Output $_ }
   Write-Output ("Lint-ConfigOwnership: {0} violation(s)." -f $violations.Count)
   exit 1
}

Write-Output 'Lint-ConfigOwnership: every rendered radio key is applied - csOwned via CheckCommand, or csJSON with a direct applier.'
exit 0
