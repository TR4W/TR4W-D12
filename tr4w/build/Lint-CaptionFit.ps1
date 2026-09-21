<#
.SYNOPSIS
   A button, check box or radio button whose caption is its entire content must
   size itself to that caption. Fails the build when a new one does not.

.DESCRIPTION
   NY4I, on macOS, 5.0.19: "save and close button is exceeding its border". The
   Preferences OK button is 85px wide and reads "Save and clo".

   NOTHING IN THIS TREE COULD HAVE CAUGHT THAT. It compiles, it streams,
   Lint-LFMProperties says every property is legal, Lint-FormOverlap says no two
   controls collide -- and 85 is a perfectly sensible number that happens to be
   wrong. The only detector was an operator squinting at a button.

   THE MEASUREMENT, taken 2026-09-21 with an LCL probe on each platform, in the
   form's own font, for the caption 'Save and close':

      Windows i386    text 77px   the widget set would choose 103px
      macOS aarch64   text 85px   the widget set would choose 107px

   85px of text in an 85px button is not "tight", it is clipped: a cocoa push
   button insets its title inside the bezel, so the glyphs had less than 85px
   before they were drawn. Windows' 77px fitted, which is why this shipped.

   AND IT IS ABOUT TO GET MUCH WORSE. 22,493 unreviewed translations went in at
   ace143d6 and have never been rendered anywhere. The same probe, same button,
   on macOS: Spanish 115px, German 163px, Russian 147px. Every one of those is a
   caption in an 85px box.

   SO THIS LINT DOES NOT MEASURE TEXT. THAT IS THE POINT.

   A Windows-hosted lint cannot know cocoa or gtk2 font metrics, and this
   repository has already retired one check for exactly that -- Lint-LinuxCompile
   passed uCTYDAT.PAS while a native Unix compiler could not open it. A check
   whose failure mode is a QUIETER PASS is worth less than none, because it is
   believed.

   What is host-independent, and true in every language, is the SHAPE: a control
   that is only a caption, given a number instead of being asked how wide it
   needs to be. AutoSize is the LCL's own answer and it is measured by the
   widget set that is actually running. A control that autosizes cannot clip on
   any platform in any language, so this lint makes the defect UNREPRESENTABLE
   rather than merely detected.

   Constraints.MinWidth is the companion, not an alternative: it stops a 'Save'
   button shrinking to the width of the word. Set both.

   SCOPED TO CONTROLS WHOSE CAPTION IS THEIR WHOLE CONTENT, deliberately.
   A TLabel with AutoSize = False is usually a fixed column in a deliberate
   layout -- a right-aligned field label, a paragraph with WordWrap -- and
   autosizing it would move its neighbours. 283 labels in this tree turn
   AutoSize off and most of them are right to. Labels are the RUN-TIME audit's
   job (src/ui/lcl/uTextFitAudit.pas, --textfit), which measures on the platform
   that is running and can tell a snug label from a clipped one. This lint takes
   only the cases where autosizing is always correct.

   THE CEILING IS A RATCHET. 159 such controls predate this lint and converting
   them all is a layout change across 22 forms, not a lint's business. The
   ceiling stops the pile GROWING, and every one converted should lower it.

   NO COMMENT STRIPPING IS NEEDED and PascalSource.psm1 is deliberately not
   used: this reads .lfm, which is streamed data with no comment syntax. There
   is no such thing as a commented-out control -- a control either exists in the
   file or it does not.

.PARAMETER SourceDir
   Root to scan. Defaults to the repository's tr4w/src.

.PARAMETER Ceiling
   The ratchet. Overriding it upward is how this lint stops working.

.PARAMETER SelfTest
   Runs the rule against built-in fixtures instead of the tree.

.OUTPUTS
   One line per fixed-width captioned control. Exit 0 = at or under the
   ceiling, 1 = over.
#>
[CmdletBinding()]
param(
   [string] $SourceDir,
   [int]    $Ceiling = 159,
   [switch] $SelfTest
)

. (Join-Path $PSScriptRoot 'Get-ScanExclusions.ps1')   # Test-Tr4wScannable

# A CAPTION IS THE WHOLE CONTENT OF THESE, and their width means nothing else.
# TGroupBox and TPanel are absent on purpose: their width is a container size
# that other controls are laid out inside, so autosizing one moves its children.
$CAPTION_IS_EVERYTHING = @('TButton', 'TBitBtn', 'TSpeedButton', 'TCheckBox',
                           'TRadioButton', 'TToggleBox')

# AUTOSIZE'S DEFAULT IS NOT THE SAME FOR ALL OF THEM, and getting this wrong
# makes the lint demand AutoSize = True on a control that already autosizes.
# A TCheckBox defaults to True, so the .lfm only mentions it to turn it OFF --
# which is why 116 check boxes looked like violations on the first run and were
# not: their designed Width is a designer artifact the widget set overrides.
# A TButton defaults to False, so silence there IS the fixed width.
$AUTOSIZE_DEFAULT_TRUE = @('TCheckBox', 'TRadioButton', 'TToggleBox')

function Get-CaptionControls
{
<#
   Every control in one .lfm, with the properties that decide whether it can
   size itself. Nesting is tracked because an 'end' closes the innermost
   object, and a form is objects all the way down.
#>
   param([string] $DisplayPath, [string[]] $Lines)

   $stack   = New-Object System.Collections.Generic.List[object]
   $current = $null
   $found   = @()

   foreach ($raw in $Lines)
      {
      $line = $raw.Trim()

      if ($line -match '^object\s+([A-Za-z_][A-Za-z0-9_]*)\s*:\s*([A-Za-z_][A-Za-z0-9_]*)\s*$')
         {
         if ($null -ne $current) { $stack.Add($current) | Out-Null }
         $current = [pscustomobject]@{
            File     = $DisplayPath
            Name     = $Matches[1]
            Type     = $Matches[2]
            Caption  = ''
            AutoSize = $false
            AutoSizeIsFalse = $false
            MinWidth = 0
            Width    = 0
         }
         continue
         }

      if ($line -eq 'end')
         {
         if ($null -ne $current)
            {
            $found += $current
            if ($stack.Count -gt 0)
               {
               $current = $stack[$stack.Count - 1]
               $stack.RemoveAt($stack.Count - 1)
               }
            else
               {
               $current = $null
               }
            }
         continue
         }

      if ($null -eq $current) { continue }

      # The first line of a caption is enough to know there IS one, which is all
      # this rule asks; a long caption continues on following lines.
      if ($line -match "^Caption\s*=\s*'(.*)")            { $current.Caption  = $Matches[1] }
      elseif ($line -match '^AutoSize\s*=\s*True\s*$')    { $current.AutoSize = $true }
      elseif ($line -match '^AutoSize\s*=\s*False\s*$')   { $current.AutoSizeIsFalse = $true }
      elseif ($line -match '^Constraints\.MinWidth\s*=\s*(\d+)') { $current.MinWidth = [int]$Matches[1] }
      elseif ($line -match '^Width\s*=\s*(\d+)')          { $current.Width    = [int]$Matches[1] }
      }

   return $found
}

function Test-CaptionFit
{
   param([object[]] $Controls)

   $bad = @()
   foreach ($c in $Controls)
      {
      if ($CAPTION_IS_EVERYTHING -notcontains $c.Type) { continue }
      if ([string]::IsNullOrWhiteSpace($c.Caption))    { continue }
      if ($AUTOSIZE_DEFAULT_TRUE -contains $c.Type)
         {
         # Only an explicit False pins it.
         if (-not $c.AutoSizeIsFalse) { continue }
         }
      elseif ($c.AutoSize)
         {
         continue
         }
      $bad += $c
      }
   return $bad
}

if ($SelfTest)
   {
   $fixture = @(
      'object FixtureForm: TFixtureForm',
      '  object btnFixed: TButton',
      '    Width = 85',
      "    Caption = 'Save and close'",
      '  end',
      '  object btnSized: TButton',
      '    Width = 85',
      '    AutoSize = True',
      '    Constraints.MinWidth = 85',
      "    Caption = 'Save and close'",
      '  end',
      '  object btnNoCaption: TButton',
      '    Width = 26',
      '  end',
      '  object lblFixed: TLabel',
      '    Width = 200',
      '    AutoSize = False',
      "    Caption = 'A label is not this lint''s business'",
      '  end',
      '  object chkDefaulted: TCheckBox',
      '    Width = 105',
      "    Caption = 'A check box autosizes unless told not to'",
      '  end',
      '  object gbOuter: TGroupBox',
      "    Caption = 'A container is not either'",
      '    object chkInner: TCheckBox',
      '      Width = 105',
      '      AutoSize = False',
      "      Caption = 'Show server log content'",
      '    end',
      '  end',
      'end'
   )

   $parsed = Get-CaptionControls -DisplayPath '(fixture)' -Lines $fixture
   $hits   = Test-CaptionFit -Controls $parsed
   $names  = (($hits | ForEach-Object { $_.Name }) | Sort-Object) -join ','

   # btnFixed and chkInner. The nested one proves the stack unwinds; the other
   # four prove each exemption -- sized, uncaptioned, not a button, and a check
   # box left at its autosizing default.
   if ($names -ne 'btnFixed,chkInner')
      {
      Write-Output "Lint-CaptionFit SELFTEST FAILED: expected 'btnFixed,chkInner', got '$names'"
      exit 1
      }
   Write-Output 'Lint-CaptionFit: self-test passed.'
   exit 0
   }

if (-not $SourceDir)
   {
   $SourceDir = Join-Path (Split-Path $PSScriptRoot -Parent) 'src'
   }
if (-not (Test-Path -LiteralPath $SourceDir))
   {
   Write-Output "Lint-CaptionFit: source directory not found: $SourceDir"
   exit 1
   }

$files = @(Get-ChildItem -LiteralPath $SourceDir -Filter '*.lfm' -Recurse |
           Where-Object { Test-Tr4wScannable $_.FullName })

$all = @()
foreach ($f in $files)
   {
   $all += Get-CaptionControls -DisplayPath $f.FullName -Lines (Get-Content -LiteralPath $f.FullName)
   }

$captioned = @($all | Where-Object {
   ($CAPTION_IS_EVERYTHING -contains $_.Type) -and
   (-not [string]::IsNullOrWhiteSpace($_.Caption))
})
$violations = @(Test-CaptionFit -Controls $all)

# A FLOOR, because a guard that passes by finding nothing is not a guard. That
# has happened in this repository: a lint reporting "0 found" and exiting 0
# while its parser understood none of the files it was handed.
if ($files.Count -lt 1)
   {
   Write-Output "Lint-CaptionFit: found 0 .lfm files under $SourceDir -- nothing was checked."
   exit 1
   }
if ($captioned.Count -lt 100)
   {
   Write-Output ("Lint-CaptionFit: parsed only {0} captioned button-like control(s) from {1} form file(s)." -f $captioned.Count, $files.Count)
   Write-Output '  There were 223 on 2026-09-21. The parser is not reading these files.'
   exit 1
   }

if ($violations.Count -gt $Ceiling)
   {
   # EVERY ONE IS LISTED, because the newest is not identifiable from a count
   # and the author has to find theirs. Sorted by file so two runs diff cleanly.
   $violations | Sort-Object File, Name | ForEach-Object {
      $cap = $_.Caption -replace "'.*$", ''
      Write-Output ("  {0}: {1} ({2}) width {3} -- caption '{4}'" -f `
                    (Split-Path $_.File -Leaf), $_.Name, $_.Type, $_.Width, $cap)
   }
   Write-Output ''
   Write-Output ("Lint-CaptionFit: {0} fixed-width captioned control(s), ceiling is {1}." -f $violations.Count, $Ceiling)
   Write-Output '  A button, check box or radio button is ONLY its caption, so a hand-typed'
   Write-Output '  width is a guess at one font, on one platform, in one language. In the .lfm:'
   Write-Output ''
   Write-Output '      AutoSize = True'
   Write-Output '      Constraints.MinWidth = <the width it has today>'
   Write-Output ''
   Write-Output '  MinWidth keeps it from shrinking; AutoSize lets the widget set that is'
   Write-Output '  actually running decide when it must grow. If it sits in a row of'
   Write-Output '  right-aligned buttons, chain them with AnchorSideRight/asrLeft so that'
   Write-Output '  growing one moves the others -- uPrefsForm btnOK/btnCancel/btnApply is'
   Write-Output '  the pattern.'
   exit 1
   }

if ($violations.Count -lt $Ceiling)
   {
   Write-Output ("Lint-CaptionFit: {0} fixed-width captioned control(s) -- below the ceiling of {1}." -f $violations.Count, $Ceiling)
   Write-Output "  LOWER THE CEILING in $($MyInvocation.MyCommand.Name) to $($violations.Count) so the ratchet holds."
   exit 0
   }

Write-Output ("Lint-CaptionFit: {0} form file(s), {1} captioned button-like control(s) checked, {2} still fixed-width (at the ceiling)." -f `
              $files.Count, $captioned.Count, $violations.Count)
exit 0
