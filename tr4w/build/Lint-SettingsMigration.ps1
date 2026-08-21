<#
.SYNOPSIS
   Every ini->JSON setting migration is THREE edits. This checks all three landed.

.DESCRIPTION
   Moving one setting from tr4w.ini to settings\tr4w.json means:

     1. uCFG.pas          crS: csJSON          -- the ini loader stops applying it
     2. uSettingsDeclarations.pas
                          RegisterStoredSetting -- Preferences writes the store,
                                                   not the ini
     3. uRadioConfigApply.pas
                          MIGRATED_COMMANDS     -- an existing operator's ini
                                                   value is carried over ONCE

   Each omission fails DIFFERENTLY, and all three are silent:

     * csJSON without RegisterStoredSetting -- Preferences writes an ini nothing
       reads. The setting appears to save and is gone on restart.
     * RegisterStoredSetting without csJSON -- the ini remains a second, staler
       copy, and the loader applies it OVER the JSON one at startup.
     * either, without MIGRATED_COMMANDS -- an operator who already had the
       setting loses it on upgrade, silently reverting to the compiled default.

   None of those is visible in a build or a test run, which is why this exists.
   All three were verified in sync by hand on 2026-08-21 (166 csJSON rows, 77
   stored writers, 102 seeded commands, zero mismatches). This keeps them that
   way while the remaining 153 settings are migrated.

   IT READS COMMENT-STRIPPED SOURCE. Measuring MIGRATED_COMMANDS with a plain
   regex over the raw file on 2026-08-21 reported 51 settings missing from the
   seed list. The real answer was zero: an apostrophe inside a comment
   ("operator's") had swallowed the quoted strings around it. This tree has paid
   for that mistake more than once in one night.

.PARAMETER SelfTest
   Run the shared Pascal-reader fixtures and exit.
#>
param(
   [string] $SourceDir,
   [switch] $SelfTest
)

$ErrorActionPreference = 'Stop'

if (-not $SourceDir) {
   $SourceDir = Split-Path -Parent $PSScriptRoot
}

Import-Module (Join-Path $PSScriptRoot 'PascalSource.psm1') -Force

if ($SelfTest) {
   $failed = Invoke-PascalSourceSelfTest
   if ($failed -gt 0) {
      Write-Output ("Lint-SettingsMigration SELFTEST: {0} parser fixture(s) failed." -f $failed)
      exit 1
   }
   Write-Output 'Lint-SettingsMigration SELFTEST: the shared Pascal reader behaves as documented.'
   exit 0
}

$src = Join-Path $SourceDir 'src'
$cfgPath   = Join-Path $src 'uCFG.pas'
$declPath  = Join-Path $src 'uSettingsDeclarations.pas'
$applyPath = Join-Path $src 'uRadioConfigApply.pas'

foreach ($p in @($cfgPath, $declPath, $applyPath)) {
   if (-not (Test-Path -LiteralPath $p)) {
      Write-Output "Lint-SettingsMigration: missing $p"
      exit 1
   }
}

$cfg   = Get-PascalCodeOnlyText -Path $cfgPath
$decl  = Get-PascalCodeOnlyText -Path $declPath
$apply = Get-PascalCodeOnlyText -Path $applyPath

# --- the CFGCA rows and their status ---------------------------------------
$rows = @{}
foreach ($m in [regex]::Matches($cfg, "crCommand:\s*'([^']*)'\s*;(.*?)crS:\s*(cs[A-Za-z]+)", 'Singleline')) {
   $rows[$m.Groups[1].Value.ToUpper()] = $m.Groups[3].Value
}

# --- the two registration forms --------------------------------------------
$flatDecl = $decl -replace '\s+', ' '
$legacy = @([regex]::Matches($flatDecl, "RegisterLegacySetting\s*\(\s*'[^']*'\s*,\s*'([^']*)'") |
            ForEach-Object { $_.Groups[1].Value.ToUpper() })
$stored = @([regex]::Matches($flatDecl, "RegisterStoredSetting\s*\(\s*'[^']*'\s*,\s*'([^']*)'") |
            ForEach-Object { $_.Groups[1].Value.ToUpper() })

# --- the seed list ----------------------------------------------------------
$mm = [regex]::Match($apply, 'MIGRATED_COMMANDS[^=]*=\s*\((.*?)\)\s*;', 'Singleline')
if (-not $mm.Success) {
   Write-Output 'Lint-SettingsMigration: MIGRATED_COMMANDS not found in uRadioConfigApply.pas'
   exit 1
}
$migrated = @([regex]::Matches($mm.Groups[1].Value, "'([^']+)'") |
              ForEach-Object { $_.Groups[1].Value.ToUpper() })

# A FLOOR. Zero of anything means the parse broke, and a check that passes
# because it looked at nothing is worse than no check.
if ($rows.Count -lt 100 -or $stored.Count -lt 1 -or $migrated.Count -lt 1) {
   Write-Output ("Lint-SettingsMigration: parse looks wrong (rows={0} stored={1} seeded={2}) -- refusing to report a pass." -f $rows.Count, $stored.Count, $migrated.Count)
   exit 1
}

$problems = @()

foreach ($c in $stored) {
   if ($rows.ContainsKey($c) -and $rows[$c] -ne 'csJSON') {
      $problems += ("{0}: RegisterStoredSetting but crS is {1} -- the ini stays a second, staler copy and the loader applies it OVER the JSON value" -f $c, $rows[$c])
   }
   if ($migrated -notcontains $c) {
      $problems += ("{0}: RegisterStoredSetting but not in MIGRATED_COMMANDS -- an operator who already had this setting loses it on upgrade" -f $c)
   }
}

foreach ($c in $legacy) {
   if ($rows.ContainsKey($c) -and $rows[$c] -eq 'csJSON') {
      $problems += ("{0}: crS is csJSON but still RegisterLegacySetting -- Preferences writes an ini nothing reads; the setting appears to save and is gone on restart" -f $c)
   }
}

if ($problems.Count -gt 0) {
   $problems | ForEach-Object { Write-Output ("  " + $_) }
   Write-Output "Lint-SettingsMigration: a setting migration is half-done."
   Write-Output "  All three land together: crS: csJSON, RegisterStoredSetting, MIGRATED_COMMANDS."
   exit 1
}

# A RATCHET ON THE REMAINING COUNT.
#
# The three-way check above catches a HALF-DONE migration. It cannot catch one
# going BACKWARDS -- a setting moved from RegisterStoredSetting back to
# RegisterLegacySetting, or a NEW setting added on the ini path -- because such a
# change is internally consistent and passes every check above.
#
# NY4I asked for the counts to be linted as well as the ini writes, and this is
# why: 153 -> 42 was one night's work, and nothing else in the build would notice
# it drifting back. The number may FALL freely; raising it means editing this
# line, which is the point at which somebody has to explain themselves.
$LEGACY_CEILING = 20

if ($legacy.Count -gt $LEGACY_CEILING) {
   Write-Output ("Lint-SettingsMigration: {0} settings still write tr4w.ini; the ceiling is {1}." -f $legacy.Count, $LEGACY_CEILING)
   Write-Output "  A setting moved BACK to the ini, or a new one was added on the ini path."
   Write-Output "  New settings take RegisterStoredSetting + crS: csJSON + MIGRATED_COMMANDS."
   Write-Output "  If the increase is deliberate, raise the ceiling in this script and say why."
   exit 1
}

if ($legacy.Count -lt $LEGACY_CEILING) {
   Write-Output ("Lint-SettingsMigration: {0} on the ini, below the ceiling of {1} -- good. Lower the ceiling and commit it with the migration." -f $legacy.Count, $LEGACY_CEILING)
   exit 1
}

Write-Output ("Lint-SettingsMigration: {0} stored, {1} still on the ini (ceiling {3}), {2} seeded -- all three lists agree." -f $stored.Count, $legacy.Count, $migrated.Count, $LEGACY_CEILING)
exit 0
