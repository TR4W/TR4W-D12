<#
.SYNOPSIS
   Enforces the rule: nothing reads or writes tr4w.ini. JSON is the store.

.DESCRIPTION
   NY4I, 2026-08-17: "Nothing should use the INI file again. I am not sure how
   much clearer I can make that rule."  And 2026-08-21: "Only json should be
   used except for the contest.cfg."

   That rule had drifted twice by 2026-08-21 -- once in the documentation, once
   in NY4I's own recollection -- and both times because the only way to check it
   was to believe a document. This makes it a build answer instead.

   WHY IT CATCHES TWO MECHANISMS, WHICH IS THE WHOLE POINT.  An audit on
   2026-08-21 counted 26 call sites by searching for GetPrivateProfileString /
   WritePrivateProfileString. It MISSED SEVEN MORE that reach the same file
   through TIniFile -- tr4w.dpr, uRadioConfigApply (x3), uPrefsForm (x2),
   uTR4WConfigFile. A rule enforced against one spelling of the offence is not
   enforced.

   WHAT COUNTS AS A VIOLATION: any Win32 profile-API call, or any
   TIniFile.Create, whose target is tr4w.ini.

   WHAT DOES NOT:
     * the contest .cfg (TR4W_CFG_FILENAME) -- exempt by decision, it is going
       to an SQLite3 contest file, not to JSON;
     * tr4wserver.ini -- a different program's config;
     * commands_help_*.ini -- shipped read-only documentation, not state;
     * anything under test\ -- fixtures write their own ini files on purpose.

   THE ALLOW-LIST IS THE REMAINING DEBT, and it is meant to shrink to nothing.
   Each entry carries WHY it is still there, so "is this finished?" is answered
   by reading one file rather than by trusting anyone's memory.

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
      Write-Output ("Lint-IniUsage SELFTEST: {0} parser fixture(s) failed." -f $failed)
      exit 1
   }
   Write-Output 'Lint-IniUsage SELFTEST: the shared Pascal reader behaves as documented.'
   exit 0
}

# THE REMAINING DEBT. Key is 'unit.pas:LINE-ish anchor' -- matched on the unit
# name plus a distinctive fragment, NOT on a line number, because line numbers
# move and a stale allow-list entry silently re-permits the wrong site.
$allowed = @(
   @{ Unit = 'uCFG.pas';            Match = '_COMMANDS';    Why = 'the last 3 legacy rows: CLEAR DUPE SHEET (an action trigger), BAND and SINGLE BAND SCORE (contest-owned, going to the SQLite contest file).' }
   @{ Unit = 'MainUnit.pas';        Match = '_COMMANDS';    Why = 'same: the [COMMANDS] remainder, incl. the key-rename helper.' }
   @{ Unit = 'uNewContest.pas';     Match = '_COMMANDS';    Why = 'reads MAIN CALLSIGN from the [COMMANDS] remainder.' }
   @{ Unit = 'uBandPlanForm.pas';   Match = 'BAND PLAN';    Why = 'multi-valued section with no JSON home yet; one ini line per band.' }
   @{ Unit = 'uCabrilloHeader.pas'; Match = '';             Why = 'ONE-TIME seed of the JSON store from an existing ini, per installation.' }
   @{ Unit = 'uTR4WConfigFile.pas'; Match = '';             Why = 'the seed reader that uCabrilloHeader uses; same one-time path.' }
   @{ Unit = 'uPrefsForm.pas';      Match = '';             Why = 'reads the legacy stores once to offer a migration; does not write.' }
   @{ Unit = 'uRadioConfigApply.pas'; Match = '';           Why = 'reads the legacy radio ini once to seed the library; the WRITES were removed 2026-08-21.' }
   # tr4w.dpr USED to be on this list, and is the example of how an entry should
   # leave it. It read [COMMANDS] DEBUG LOG LEVEL from the ini to configure the
   # logger before the config system existed -- but that key is a csJSON row, so
   # the ini was a STALE source: an operator who set the level in Preferences got
   # their old value for the earliest lines, or the compiled default on a station
   # with no ini at all. It now reads the store through
   # uTR4WConfigFile.StartupLogLevel, so the entry is GONE rather than excused
   # (NY4I, 2026-08-21: "solve it another way with reading the json file").
)

if (-not (Test-Path -LiteralPath $SourceDir -PathType Container)) {
   Write-Output "Lint-IniUsage: source directory not found: $SourceDir"
   exit 1
}

$files = @(Get-TR4WPascalFiles -Root $SourceDir)
if ($files.Count -eq 0) {
   Write-Output "Lint-IniUsage: NO Pascal files found under $SourceDir -- refusing to report a pass."
   exit 1
}

# IGNORECASE on every match: Pascal identifiers are not case-sensitive and .NET
# regex is. The sibling ratchet shipped with exactly that hole on 2026-08-21.
$opt   = [Text.RegularExpressions.RegexOptions]::IgnoreCase
$win32 = '\b(Get|Write)PrivateProfile[A-Za-z]*\s*\('
$tini  = '\bTIniFile\.Create\s*\('

$violations = @()
$allowedHits = 0

foreach ($f in $files) {
   # Test fixtures write their own ini files deliberately.
   if ($f.FullName -match '\\test\\') { continue }

   $text  = Get-PascalCodeOnlyText -Path $f.FullName
   $lines = $text.Split("`n")

   foreach ($pattern in @($win32, $tini)) {
      foreach ($m in [regex]::Matches($text, $pattern, $opt)) {
         $n = ($text.Substring(0, $m.Index).Split("`n")).Count

         # The target may be an argument on a following line -- read a small window.
         $to = [Math]::Min($n + 2, $lines.Count) - 1
         $window = ($lines[($n - 1)..$to] -join ' ') -replace '\s+', ' '

         # Not tr4w.ini? Not this lint's business.
         $isOurs = ($window -match 'TR4W_INI_FILENAME') -or ($window -match "'tr4w\.ini'")
         if (-not $isOurs) { continue }

         $hit = $allowed | Where-Object {
            $_.Unit -eq $f.Name -and ($_.Match -eq '' -or $window -match [regex]::Escape($_.Match))
         }
         if ($hit) { $allowedHits++; continue }

         $violations += ("{0}:{1}  {2}" -f $f.Name, $n, $window.Trim().Substring(0, [Math]::Min(90, $window.Trim().Length)))
      }
   }
}

if ($violations.Count -gt 0) {
   $violations | ForEach-Object { Write-Output ("  " + $_) }
   Write-Output "Lint-IniUsage: tr4w.ini is read or written above, and it must not be."
   Write-Output "  settings\tr4w.json is the store. The contest .cfg is exempt; tr4wserver.ini is another program."
   Write-Output "  If a site is genuinely legitimate, add it to `$allowed in this script WITH A REASON."
   exit 1
}

Write-Output ("Lint-IniUsage: {0} file(s) checked, no new tr4w.ini access; {1} known site(s) still on the allow-list." -f $files.Count, $allowedHits)
exit 0
