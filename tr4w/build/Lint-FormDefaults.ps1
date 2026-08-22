<#
.SYNOPSIS
   Every designed form must have a way out with the keyboard, and an OK button
   must answer Enter.

.DESCRIPTION
   A Win32 DialogBox gives Escape and Enter away for free. The dialog manager
   synthesises IDCANCEL from Escape and IDOK from Enter, so every one of the ~23
   modals being converted in Phase 4 has that behaviour today WITHOUT ANY CODE
   SAYING SO.

   An LCL TForm does not. Escape activates the button whose Cancel is True and
   does nothing when there is none; Enter activates the button whose Default is
   True and does nothing when there is none. Neither is a default.

   SO THE BEHAVIOUR IS LOST BY OMISSION, AND NOTHING COMPLAINS. It compiles, the
   form opens, every button works with the mouse, the smoke runner sees a window
   appear -- and Escape silently stops closing the dialog. NY4I found it by
   pressing Escape on the program-message chooser (2026-08-18); the same check
   then showed THREE forms converted before it had the same gap, including two
   with a perfectly good btnCancel that Escape could not reach.

   That is the exact shape this repo keeps getting caught by: a behaviour that
   was implicit in the old mechanism, has no representation in the new one, and
   leaves no diagnostic. It is worth a gate rather than a habit, because Phase 4
   has roughly twenty more forms to go.

   THE RULES, deliberately few:

   1. ESCAPE -- every form must have an escape path: a control with
      `Cancel = True`, or `KeyPreview = True` (the form handles the key itself,
      which is what a form with no Cancel button has to do).

   2. ENTER -- a form that HAS an OK button must give it `Default = True`.
      Forms with no OK button are not required to have a default, because there
      is no single obvious action to bind Enter to.

   What this does NOT check: that the handlers do the right thing. Lint-FormEvents
   already refuses an unwired handler, and what the handler DOES is a bench
   question.

   .\Lint-FormDefaults.ps1
   .\Lint-FormDefaults.ps1 -SourceDir C:\tr4w-d12\tr4w
#>

param(
   # The directory to scan, NOT the repo root: Run-Lints passes tr4w\src, the
   # same as every other form lint. The first version joined 'src' onto this and
   # asked for tr4w\src\src, which threw a raw PowerShell exception instead of
   # reporting anything.
   [string] $SourceDir = (Join-Path (Split-Path $PSScriptRoot -Parent) 'src')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $SourceDir -PathType Container)) {
   Write-Output "Lint-FormDefaults: source directory not found: $SourceDir"
   exit 1
}

$forms = @(Get-ChildItem -LiteralPath $SourceDir -Recurse -File |
           Where-Object { $_.Extension -eq '.lfm' })

# A FLOOR. Zero forms scanned means the path or the filter is wrong, and a lint
# that reports "no defects" because it looked at nothing is worse than no lint --
# this repo has been bitten by exactly that before.
if ($forms.Count -eq 0) {
   Write-Output "Lint-FormDefaults: NO .lfm files found under $SourceDir -- refusing to report a pass."
   exit 1
}

# NOT EVERY FORM IS A DIALOG, and this lint's whole premise is about dialogs:
# "a Win32 DialogBox closed on Escape for free, this one does not".
#
# The MAIN WINDOW is not a dialog and MUST NOT close on Escape.  In TR4W, Escape
# clears the callsign field and aborts CW that is being sent -- an operator hits
# it constantly, mid-contest, and a main window that took it as "close" would end
# the session.  Demanding an escape path here would be demanding a defect.
#
# Named rather than pattern-matched: "is this a dialog" is not something a .lfm
# states, and guessing it from the presence of an OK button would quietly excuse
# any form that happens to lack one.
#
# EXPECT THIS LIST TO GROW to about twenty as the tw_ tool windows convert --
# band map, master, remaining mults, telnet and the rest are all docked panels
# that must not close on Escape.  A tool window belongs here; a dialog never
# does, and the difference is worth stating per entry rather than assuming.
$notDialogs = @(
   'uMainForm.lfm',          # the main window
   'uFunctionKeysForm.lfm'   # a docked tw_ TOOL WINDOW, and the first of ~20 to
                             # convert.  Escape belongs to the callsign field
                             # while this window is on screen; closing the F-key
                             # row on it would be a defect, not a courtesy.
)

$problems = New-Object System.Collections.ArrayList

foreach ($f in $forms) {
   if ($notDialogs -contains $f.Name) { continue }

   $text = Get-Content -LiteralPath $f.FullName -Raw

   $hasCancel     = $text -match '(?m)^\s*Cancel\s*=\s*True\s*$'
   $hasKeyPreview = $text -match '(?m)^\s*KeyPreview\s*=\s*True\s*$'
   $hasDefault    = $text -match '(?m)^\s*Default\s*=\s*True\s*$'

   # "Has an OK button" is asked of the OBJECT NAME, not the caption: captions
   # are set from language constants at run time on several of these forms, so a
   # caption test would simply miss them.
   $hasOKButton   = $text -match '(?m)^\s*object\s+btnOK\s*:\s*T\w*Button\s*$'

   if (-not ($hasCancel -or $hasKeyPreview)) {
      [void]$problems.Add(("{0}: NO ESCAPE PATH -- no control with Cancel = True, and KeyPreview is not True." -f $f.Name))
      [void]$problems.Add( "    A Win32 DialogBox closed on Escape for free. This form does not.")
      [void]$problems.Add( "    Fix: Cancel = True on the cancel/close button, or KeyPreview = True")
      [void]$problems.Add( "    plus an OnKeyDown that closes on VK_ESCAPE when there is no such button.")
   }

   if ($hasOKButton -and (-not $hasDefault)) {
      [void]$problems.Add(("{0}: btnOK is not Default -- Enter will not activate it." -f $f.Name))
      [void]$problems.Add( "    Fix: Default = True on btnOK.")
   }
}

if ($problems.Count -gt 0) {
   Write-Output "Lint-FormDefaults: keyboard defaults missing on designed form(s)."
   $problems | ForEach-Object { Write-Output ("  " + $_) }
   exit 1
}

Write-Output ("Lint-FormDefaults: {0} designed form(s) checked, every one closes on Escape and every OK button answers Enter." -f $forms.Count)
exit 0
