<#
.SYNOPSIS
   Checks that every config key the radio library RENDERS is marked csOwned in
   CFGCA -- hidden from Ctrl-J, but still applied.

.DESCRIPTION
   Two editors now write the same settings. Preferences owns the radio library
   and renders it into the [Radio] ini keys; the Ctrl-J configuration-commands
   dialog lists those same keys and lets them be typed over. Whichever ran last
   wins, and nothing on either screen says so (NY4I, 2026-08-08).

   csOwned is the marking that resolves it: hidden from Ctrl-J, STILL APPLIED by
   CheckCommand.

   csJSON WOULD BE WRONG HERE, and wrong in a way that is silent. CheckCommand
   treats csRem and csJSON as accepted-but-inert -- it returns True and exits
   without applying anything. The radio path depends on CheckCommand doing the
   applying: at startup ApplyRadioToSlot runs with aPersist=False, so
   CheckCommand is the ONLY thing that configures the radios. Marking these rows
   csJSON would disable every radio setting in the program while every test
   still passed. Hence this lint rejects csJSON on a rendered key explicitly
   rather than only demanding csOwned.

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

function Test-Ownership {
   param([string] $LegacyMapText, [string] $CfgText)

   $violations = @()
   $suffixes = Get-RenderedSuffixes -LegacyMapText $LegacyMapText
   $statuses = Get-CommandStatuses -CfgText $CfgText

   if ($suffixes.Count -eq 0) {
      return @('Lint-ConfigOwnership: could not read KEYSPECS from uRadioConfigLegacyMap.pas - the lint is not checking anything')
   }

   $keys = @()
   foreach ($slot in @('ONE', 'TWO')) {
      foreach ($s in $suffixes) { $keys += "RADIO $slot $s" }
      # The two shapes that are not RADIO-prefixed.
      $keys += "KEYER RADIO $slot OUTPUT PORT"
      $keys += "POLL RADIO $slot"
   }

   foreach ($k in $keys) {
      $u = $k.ToUpper()
      if (-not $statuses.ContainsKey($u)) {
         $violations += "$k is rendered by the radio library but has no CFGCA row"
         continue
      }
      $st = $statuses[$u]
      if ($st -eq 'csJSON') {
         $violations += "$k is csJSON, which CheckCommand treats as INERT - the radio would silently stop being configured; use csOwned"
      }
      elseif ($st -ne 'csOwned') {
         $violations += "$k is $st, so Ctrl-J can still edit what Preferences owns - mark it csOwned"
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

      # The dangerous one: hidden AND inert.
      @{ Name = 'csJSON_is_rejected'; Expect = 1
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
      $v = @(Test-Ownership -LegacyMapText $mapOK -CfgText $f.Cfg)
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

$mapFile = Join-Path $SourceDir 'uRadioConfigLegacyMap.pas'
$cfgFile = Join-Path $SourceDir 'uCFG.pas'

foreach ($f in @($mapFile, $cfgFile)) {
   if (-not (Test-Path -LiteralPath $f)) {
      Write-Output ("Lint-ConfigOwnership: not found: {0}" -f $f)
      exit 1
   }
}

$violations = @(Test-Ownership -LegacyMapText (Get-Content -LiteralPath $mapFile -Raw) `
                               -CfgText       (Get-Content -LiteralPath $cfgFile -Raw))

if ($violations.Count -gt 0) {
   $violations | ForEach-Object { Write-Output $_ }
   Write-Output ("Lint-ConfigOwnership: {0} violation(s)." -f $violations.Count)
   exit 1
}

Write-Output 'Lint-ConfigOwnership: every rendered radio key is csOwned - Ctrl-J cannot edit what Preferences owns.'
exit 0
