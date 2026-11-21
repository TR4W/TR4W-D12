# Lint-ControlHints -- how many input controls on the editor forms have NO
# tooltip source, per form, held to a ceiling that only goes down.
#
# WHY THIS EXISTS. A tooltip is the operator's in-place help, and a designed
# control gets one only if someone wires it: a Hint in the .lfm, or code that
# sets one. Nothing else notices a control without one -- it looks perfectly
# normal on screen. The radio editor had 34 input controls and one wired
# tooltip (the poll rate) until 2026-11-21. This lint prints, per form, the
# controls with no hint source, which is the honest answer to "how many
# tooltips are we missing", and fails when a form gets WORSE.
#
# WHAT COUNTS AS AN INPUT CONTROL: an object in the form's .lfm whose class is
# in $INPUT_TYPES below. A control marked ReadOnly = True is not an input and
# is skipped. TListBox is deliberately NOT counted: on these forms a list box
# is a record selector (the cluster, rotator and UDP lists), not a setting.
#
# WHAT COUNTS AS A HINT SOURCE, for a control named N:
#   - the .lfm gives N a non-empty Hint;
#   - the .pas, read the way the compiler sees it (comments stripped, through
#     PascalSource.psm1), contains
#        ApplyCommandHelpHint(N, ...)
#        N.Hint :=
#        HintFromHelp(N, L, ...)        -- the radio editor's table; N and L both
#   - uPrefsForm only, the routes that already call ApplyCommandHelpHint:
#        Bind(N, ...)                   -- TSettingBindings (a registered setting)
#        AddHandWiredToSearchIndex(n, '<COMMAND>', N)
#        MakeStationField('<COMMAND>', N)   -- the Station table, indexed the same way
#     AddStoreBackedToSearchIndex is NOT a hint source: it indexes, it sets no hint.
#
# WHAT IT DOES NOT MEASURE, so nobody reads more into a pass than is there:
#   - WHETHER THE TEXT EXISTS. It measures WIRING. A control wired to a command
#     that has no msgctxt in i18n/help_en.po still shows no tooltip; Bind() of a
#     setting with no legacy command name likewise. uTestCommandHelp pins the
#     registered settings' text; this lint does not read the catalogue.
#   - CONTROLS CREATED AT RUN TIME (the external logger editor's provider rows,
#     the generated Preferences pages). Only what the .lfm declares is counted.
#   - A hint reaching a control indirectly (a loop over a list of controls
#     built elsewhere). Such a control is reported unhinted; wire it by name.
#
# THE RATCHET. Each form has a ceiling in $CEILINGS. A count ABOVE its ceiling
# fails the build; a count BELOW it is reported so the ceiling can be lowered.
# Ceilings only go down. A form listed here whose files are missing fails, as
# does a form that parses to zero controls -- a parser that silently matches
# nothing would report a clean pass forever.
#
#   powershell -File tr4w\build\Lint-ControlHints.ps1

[CmdletBinding()]
param(
   [string] $SourceDir = ''
)

$ErrorActionPreference = 'Stop'

# RESOLVED IN THE BODY, not in the param default. Measured 2026-11-21 on the
# development machine (Windows PowerShell 5.1, started from the agent's shell):
# a hand run of `powershell -File` with no -SourceDir failed in the param
# default with an empty $PSScriptRoot, and Lint-SearchIndex fails the same
# way. Run-Lints passes the folder explicitly, so only a hand run needed this.
if ($SourceDir -eq '')
{
   $SourceDir = Join-Path (Split-Path $PSScriptRoot -Parent) 'src'
}

Import-Module (Join-Path $PSScriptRoot 'PascalSource.psm1') -Force

# Lower one when tooltips land; NEVER raise one. Measured 2026-11-21, after
# every form was wired. A non-zero ceiling is a list of DELIBERATE exemptions,
# each named here with its reason:
#   uPrefsForm  edtSearch -- the search box; its TextHint ("Search settings")
#                            is its help, and a tooltip would cover the results.
$CEILINGS = [ordered]@{
   'uRadioEditForm'          = 0
   'uKeyerEditForm'          = 0
   'uPrefsForm'              = 1
   'uExternalLoggersForm'    = 0
   'uUDPDestinationEditForm' = 0
   'uSetupWizardForm'        = 0
}

$INPUT_TYPES = @(
   'TEdit', 'TComboBox', 'TCheckBox', 'TRadioButton', 'TRadioGroup',
   'TCheckGroup', 'TSpinEdit', 'TFloatSpinEdit', 'TSpinEditEx',
   'TFloatSpinEditEx', 'TMaskEdit', 'TTrackBar', 'TMemo', 'TToggleBox',
   'TDateTimePicker', 'TColorBox', 'TColorButton', 'TLabeledEdit',
   'TEditButton', 'TFileNameEdit', 'TDirectoryEdit', 'TComboBoxEx',
   'TCheckComboBox', 'TUpDown', 'TCheckListBox'
)

# ---------------------------------------------------------------------------
# The .lfm: every input control, and whether it carries its own Hint.
#
# The .lfm is indentation-structured. A property line belongs to the innermost
# object still open; 'end' at an object's own indent closes it.
# ---------------------------------------------------------------------------
function Get-LfmInputControls
{
   param([string] $Path)

   $result = New-Object System.Collections.ArrayList
   $stack  = New-Object System.Collections.ArrayList

   foreach ($line in [IO.File]::ReadAllLines($Path))
   {
      if ($line -match '^(\s*)(object|inherited|inline)\s+(\w+)\s*:\s*(\w+)')
      {
         $entry = [pscustomobject]@{
            Indent   = $Matches[1].Length
            Name     = $Matches[3]
            Type     = $Matches[4]
            HasHint  = $false
            ReadOnly = $false
         }
         [void] $stack.Add($entry)
         if ($INPUT_TYPES -contains $entry.Type)
         {
            [void] $result.Add($entry)
         }
         continue
      }

      if ($line -match '^(\s*)end\s*$')
      {
         $indent = $Matches[1].Length
         while ($stack.Count -gt 0 -and $stack[$stack.Count - 1].Indent -ge $indent)
         {
            $stack.RemoveAt($stack.Count - 1)
         }
         continue
      }

      if ($stack.Count -eq 0)
      {
         continue
      }
      $owner = $stack[$stack.Count - 1]

      # Hint = '' is no hint; any other value (a string, or a string that
      # continues on the next line) is one.
      if ($line -match '^\s*Hint\s*=\s*(.*)$')
      {
         $value = $Matches[1].Trim()
         if ($value -ne "''")
         {
            $owner.HasHint = $true
         }
         continue
      }
      if ($line -match '^\s*ReadOnly\s*=\s*True\s*$')
      {
         $owner.ReadOnly = $true
      }
   }

   return ,$result
}

# ---------------------------------------------------------------------------
# The .pas: every control name that reaches a hint.
# ---------------------------------------------------------------------------
function Get-PasHintedNames
{
   param(
      [string] $Path,
      [bool]   $IsPrefs
   )

   $code  = Get-PascalCodeOnlyText -Path $Path
   $names = @{}

   $patterns = @(
      'ApplyCommandHelpHint\(\s*(\w+)',
      '\b(\w+)\.Hint\s*:=',
      'HintFromHelp\(\s*(\w+)\s*,\s*(\w+)'
   )
   if ($IsPrefs)
   {
      $patterns += @(
         '\bBind\(\s*(\w+)\s*,',
         'AddHandWiredToSearchIndex\(\s*\w+\s*,\s*''[^'']*''\s*,\s*(\w+)\s*\)',
         'MakeStationField\(\s*''[^'']*''\s*,\s*(\w+)\s*\)'
      )
   }

   foreach ($pattern in $patterns)
   {
      foreach ($m in [regex]::Matches($code, $pattern, 'IgnoreCase'))
      {
         for ($g = 1; $g -lt $m.Groups.Count; $g++)
         {
            if ($m.Groups[$g].Success)
            {
               $names[$m.Groups[$g].Value.ToLowerInvariant()] = $true
            }
         }
      }
   }
   return $names
}

# ---------------------------------------------------------------------------
# Count, report, judge.
# ---------------------------------------------------------------------------
$lclDir   = Join-Path (Join-Path $SourceDir 'ui') 'lcl'
$failed   = $false
$broken   = $false
$dropped  = @()
$totalIn  = 0
$totalOut = 0

Write-Host ''
Write-Host 'Lint-ControlHints: input controls with no tooltip source, per form'
Write-Host ''

foreach ($form in $CEILINGS.Keys)
{
   $lfm = Join-Path $lclDir ($form + '.lfm')
   $pas = Join-Path $lclDir ($form + '.pas')
   if (-not (Test-Path -LiteralPath $lfm) -or -not (Test-Path -LiteralPath $pas))
   {
      Write-Host ("   {0}: FAILED -- missing {0}.lfm or {0}.pas under {1}" -f $form, $lclDir) -ForegroundColor Red
      $broken = $true
      continue
   }

   # Assigned first, then unrolled: the function returns its list as ONE
   # object, and piping that straight on would filter the list, not its items.
   $parsed   = Get-LfmInputControls -Path $lfm
   $controls = @($parsed | ForEach-Object { $_ } | Where-Object { -not $_.ReadOnly })
   if ($controls.Count -eq 0)
   {
      Write-Host ("   {0}: FAILED -- parsed 0 input controls from the .lfm; the parser is broken, not the form." -f $form) -ForegroundColor Red
      $broken = $true
      continue
   }

   $hinted   = Get-PasHintedNames -Path $pas -IsPrefs ($form -eq 'uPrefsForm')
   $unhinted = @($controls | Where-Object {
      (-not $_.HasHint) -and (-not $hinted.ContainsKey($_.Name.ToLowerInvariant()))
   })

   $totalIn  += $controls.Count
   $totalOut += $unhinted.Count
   $ceiling   = $CEILINGS[$form]

   $colour  = 'Gray'
   $verdict = ''
   if ($unhinted.Count -gt $ceiling)
   {
      $failed  = $true
      $colour  = 'Red'
      $verdict = "  ABOVE ceiling $ceiling"
   }
   elseif ($unhinted.Count -lt $ceiling)
   {
      $dropped += ('{0}: {1} (ceiling {2})' -f $form, $unhinted.Count, $ceiling)
   }

   Write-Host ('   {0,-24} {1,4} of {2,4} input controls unhinted (ceiling {3}){4}' -f
               $form, $unhinted.Count, $controls.Count, $ceiling, $verdict) -ForegroundColor $colour
   if ($unhinted.Count -gt 0)
   {
      $list = ($unhinted | Sort-Object Name | ForEach-Object { $_.Name }) -join ', '
      Write-Host ('      ' + $list) -ForegroundColor DarkGray
   }
}

Write-Host ''
Write-Host ('Lint-ControlHints: {0} of {1} input controls across {2} forms have no tooltip source.' -f
            $totalOut, $totalIn, $CEILINGS.Count)

if ($dropped.Count -gt 0)
{
   Write-Host 'These forms are BELOW their ceiling -- lower it so the gaps cannot come back:' -ForegroundColor Yellow
   foreach ($d in $dropped)
   {
      Write-Host "   $d" -ForegroundColor Yellow
   }
}

if ($broken)
{
   Write-Host 'Lint-ControlHints FAILED -- a form could not be read (see above).' -ForegroundColor Red
   exit 1
}

if ($failed)
{
   Write-Host ''
   Write-Host 'Lint-ControlHints FAILED -- a form has MORE unhinted input controls than its ceiling.' -ForegroundColor Red
   Write-Host 'Give the new control a tooltip: ApplyCommandHelpHint(<control>, help, ''<COMMAND>'') with an entry'
   Write-Host 'in i18n/help_en.po, or a Hint in the .lfm. Do not raise the ceiling.'
   exit 1
}

exit 0
