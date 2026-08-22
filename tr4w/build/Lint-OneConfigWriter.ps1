<#
.SYNOPSIS
   settings\tr4w.json has exactly ONE writer.

.DESCRIPTION
   The file holds several libraries: the radio store's own sections, the keyer
   library, and the UDP settings.  uTR4WConfigFile.SaveConfig is the only
   routine that knows that -- it PRESERVES the sections it was not given, so
   SaveConfig(file, store, nil, nil) writes one library and leaves the rest
   alone.

   TRadioConfigStore.SaveToFile writes that store's sections AND NOTHING ELSE.
   Pointed at the configuration file it does not fail, it does not warn, and it
   does not look wrong at the call site -- it silently DELETES the keyer library
   and the UDP settings.

   Two callers did exactly that on 2026-08-21: saving a band plan, or answering
   the legacy-ini prompt, would have wiped every configured keyer.  Neither was
   caught by a compiler, a test or a review; the file simply came back smaller.

   NY4I, 2026-08-22: "two paths to write anything is a bad idea."

   So this lint fails on SaveToFile applied to any of the names that resolve to
   the configuration file.  It deliberately does NOT flag SaveToFile in general:
   TStringList.SaveToFile is ordinary and common, and a lint that fires on
   innocent code gets ignored.
#>
param(
   [string] $SourceDir
)

$ErrorActionPreference = 'Stop'

if (-not $SourceDir) {
   $SourceDir = Join-Path (Split-Path -Parent $PSScriptRoot) 'src'
}

Import-Module (Join-Path $PSScriptRoot 'PascalSource.psm1') -Force

# The spellings that resolve to settings\tr4w.json.  Extending this list is
# fine; each addition should name a real variable or function.
$targets = @('TR4WConfigFileName', 'StoreFileName', 'aStoreFileName', 'RadioStoreFileName')

# SaveToFile is DECLARED and used legitimately here.
$allowed = @('uRadioConfigStore.pas', 'uTR4WConfigFile.pas')

$pattern = '\.SaveToFile\s*\(\s*(' + ($targets -join '|') + ')\b'
$opt     = [Text.RegularExpressions.RegexOptions]::IgnoreCase

if (-not (Test-Path -LiteralPath $SourceDir -PathType Container)) {
   Write-Output "Lint-OneConfigWriter: source directory not found: $SourceDir"
   exit 1
}

$files = @(Get-TR4WPascalFiles -Root $SourceDir)
if ($files.Count -eq 0) {
   Write-Output "Lint-OneConfigWriter: NO Pascal files found under $SourceDir -- refusing to report a pass."
   exit 1
}

$violations = @()
foreach ($f in $files) {
   if ($allowed -contains $f.Name) { continue }
   $code = Get-PascalCodeOnlyText -Path $f.FullName
   foreach ($m in [regex]::Matches($code, $pattern, $opt)) {
      $line = ($code.Substring(0, $m.Index) -split "`n").Count
      $violations += ("  {0}:{1}  {2}" -f $f.Name, $line, $m.Value.Trim())
   }
}

if ($violations.Count -gt 0) {
   $violations | ForEach-Object { Write-Output $_ }
   Write-Output "Lint-OneConfigWriter: tr4w.json must be written through SaveConfig, not SaveToFile."
   Write-Output "  SaveToFile writes the radio store's sections ONLY -- it drops the keyer"
   Write-Output "  library and the UDP settings, silently and without failing."
   Write-Output "  Use:  SaveConfig(<file>, <store>, nil, nil)   -- it preserves what it is not given."
   exit 1
}

Write-Output ("Lint-OneConfigWriter: {0} file(s) checked, tr4w.json has one writer." -f $files.Count)
exit 0
