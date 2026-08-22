<#
.SYNOPSIS
   Every TForm lives in a .lfm, so a person can open it in the designer.

.DESCRIPTION
   NY4I, 2026-08-22: "your task is not to create LCL forms via code.  It is to
   create LCL forms via editor file which allows someone to manually edit a form
   in the future."

   A form built in code cannot be opened in the Lazarus designer at all.  Its
   layout can then only be changed by someone who reads Pascal, one SetBounds at
   a time, with no way to see the result without a rebuild -- which is most of
   what was wrong with the DLGTEMPLATE records this migration exists to remove.
   Replacing a hand-built Win32 dialog with a hand-built LCL form moves the
   problem instead of fixing it.

   So: every `T... = class(TForm)` must have a .lfm beside its unit.

   WHAT THIS DOES NOT FORBID.  Creating CONTROLS at run time is fine and
   sometimes required -- the Preferences settings pages are generated from CFGCA
   because those rows ARE data, and the main window positions its elements from
   a table times a runtime scale factor.  A designed .lfm and runtime-positioned
   children are not in conflict: the .lfm gives the form an editable identity and
   the loop still places what the table owns.  This checks the FORM, not its
   children.
#>
param(
   [string] $SourceDir
)

$ErrorActionPreference = 'Stop'

if (-not $SourceDir) {
   $SourceDir = Join-Path (Split-Path -Parent $PSScriptRoot) 'src'
}

# THE KNOWN EXCEPTION, and it is the one this migration still has to answer.
#
# TTR4WMainForm is built entirely in code (Phase 3a).  The plan's reasoning is
# real: the main window's 50 elements are placed at TWindows[e].mweiX * ws, where
# ws comes from the operator's font-size setting and the vertical origin is
# measured from the log at run time.  Freezing 50 positions into a .lfm would be
# a regression.
#
# But that argues against DESIGNING THE CHILDREN, not against the form itself
# having a .lfm.  A .lfm carrying the form's own properties, with the placement
# loop still owning the table-driven children, would satisfy both -- and is the
# open question recorded in docs/ROADMAP.md section 2.
#
# Until that is decided this stays as ONE NAMED exception rather than a silence.
# Do not add a second without NY4I.
$allowed = @{
   'uMainForm.pas' = 'TTR4WMainForm -- Phase 3a; the .lfm question is open, see ROADMAP section 2'
}

if (-not (Test-Path -LiteralPath $SourceDir -PathType Container)) {
   Write-Output "Lint-DesignedForms: source directory not found: $SourceDir"
   exit 1
}

# Get-TR4WPascalFiles, not a fresh enumeration: trdos uses UPPERCASE extensions
# and the shared helper is the one place that knows it.  A second file list here
# is how a lint quietly stops seeing a quarter of the tree.
Import-Module (Join-Path $PSScriptRoot 'PascalSource.psm1') -Force
$files = @(Get-TR4WPascalFiles -Root $SourceDir)

if ($files.Count -eq 0) {
   Write-Output "Lint-DesignedForms: NO Pascal files found under $SourceDir -- refusing to report a pass."
   exit 1
}

$opt       = [Text.RegularExpressions.RegexOptions]::IgnoreCase
$formClass = '\b(T\w+)\s*=\s*class\s*\(\s*TForm\s*\)'

$violations = @()
$designed   = 0
$excused    = 0

foreach ($f in $files) {
   $code = Get-PascalCodeOnlyText -Path $f.FullName
   $found = [regex]::Matches($code, $formClass, $opt)
   if ($found.Count -eq 0) { continue }

   $lfm = [IO.Path]::ChangeExtension($f.FullName, '.lfm')
   if (Test-Path -LiteralPath $lfm) {
      $designed += $found.Count
      continue
   }

   if ($allowed.ContainsKey($f.Name)) {
      $excused += $found.Count
      continue
   }

   foreach ($m in $found) {
      $violations += ("  {0}: {1} is a TForm with no {2}" -f
                      $f.Name, $m.Groups[1].Value, [IO.Path]::GetFileName($lfm))
   }
}

if ($violations.Count -gt 0) {
   $violations | ForEach-Object { Write-Output $_ }
   Write-Output "Lint-DesignedForms: a form was built in code instead of designed."
   Write-Output "  A code-built form cannot be opened in the Lazarus designer, so its layout"
   Write-Output "  can only be changed one SetBounds at a time by someone who reads Pascal."
   Write-Output "  Create the .lfm and let the designer own the layout. Runtime-positioned"
   Write-Output "  CHILDREN are fine -- this checks the form, not its controls."
   exit 1
}

Write-Output ("Lint-DesignedForms: {0} designed form(s) checked, {1} known exception(s)." -f $designed, $excused)
exit 0
