# Lint-BindKeys -- every settings key a control binds to must exist in the registry.
#
# WHY. FBindings.Bind(control, 'settings.key') takes the key as a PLAIN STRING.
# Mistype it and nothing fails to compile: the control binds to nothing, it still
# appears in Preferences, the operator still edits it, and it silently stops
# saving. There is no diagnostic anywhere -- not at build, not at run time, not
# in the log.
#
# WHAT IT UNBLOCKS, which is the real reason it exists now. The settings key
# space and the Preferences nav tree disagree about hierarchy: bandmap.* is a
# top-level prefix while Band Map is a CHILD of Operating in the tree, so
# uRadioConfigStore.SectionParent is a hand-maintained table that must match the
# tree by eye (docs/OWED_BEFORE_CROSS_PLATFORM.md item 1b). The fix is to rename
# the prefixes so the grouping is derivable again and there is ONE declaration of
# the hierarchy -- and renaming ~77 literal strings is only safe once a mistyped
# one fails the build. This lint first, then the rename, then the hierarchy.
#
# It is CLEAN as of 2026-08-31: 77 keys bound, 229 declared, 0 orphans. That is
# the point -- it is a guard against a class of silent defect, not a repair.
#
# SCOPE. It checks that a bound key EXISTS. It does not check that the key is the
# RIGHT one for that control: binding a checkbox to another setting's key passes
# here and is Lint-SettingsMigration's and the operator's problem.

[CmdletBinding()]
param(
   [string] $SourceDir = (Join-Path (Split-Path $PSScriptRoot -Parent) 'src')
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Get-ScanExclusions.ps1')   # Test-Tr4wScannable -- IDE backup dirs are not source

$prefs = Join-Path $SourceDir 'ui\lcl\uPrefsForm.pas'
$declFiles = @(
   (Join-Path $SourceDir 'uSettingsDeclarations.pas'),
   (Join-Path $SourceDir 'uSettingsLegacy.pas')
)

foreach ($f in (@($prefs) + $declFiles))
{
   if (-not (Test-Path $f))
   {
      Write-Host "  Lint-BindKeys: FAILED -- missing $f" -ForegroundColor Red
      exit 1
   }
}

# --- keys the registry declares -------------------------------------------
$declared = @{}
foreach ($f in $declFiles)
{
   $text = Get-Content -LiteralPath $f -Raw
   foreach ($m in [regex]::Matches($text, "Register\w*Setting\(\s*'([^']+)'"))
   {
      $declared[$m.Groups[1].Value] = $true
   }
}

if ($declared.Count -eq 0)
{
   # FAILS CLOSED. A pattern that stops matching would otherwise report a clean
   # pass for ever -- the shape of guard this tree has been bitten by before.
   Write-Host "  Lint-BindKeys: FAILED -- parsed 0 registered settings; the pattern is broken, not the code." -ForegroundColor Red
   exit 1
}

# --- keys the form binds --------------------------------------------------
$prefsText = Get-Content -LiteralPath $prefs -Raw
$bound = @{}
foreach ($m in [regex]::Matches($prefsText, "Bind\(\s*\w+\s*,\s*'([^']+)'"))
{
   $bound[$m.Groups[1].Value] = $true
}

if ($bound.Count -eq 0)
{
   Write-Host "  Lint-BindKeys: FAILED -- parsed 0 Bind() keys; the pattern is broken, not the code." -ForegroundColor Red
   exit 1
}

$orphans = @($bound.Keys | Where-Object { -not $declared.ContainsKey($_) } | Sort-Object)

if ($orphans.Count -gt 0)
{
   Write-Host "  Lint-BindKeys: $($orphans.Count) bound key(s) are not declared in the settings registry." -ForegroundColor Red
   foreach ($k in $orphans)
   {
      Write-Host "    $k"
   }
   Write-Host ""
   Write-Host "  A control bound to an unknown key edits nothing and saves nothing, silently."
   Write-Host "  Either fix the spelling at the Bind() call, or declare the setting with"
   Write-Host "  RegisterStoredSetting in uSettingsDeclarations.pas."
   exit 1
}

Write-Host ("  Lint-BindKeys: {0} bound key(s) checked against {1} registered setting(s), all resolve." -f `
            $bound.Count, $declared.Count)
exit 0
