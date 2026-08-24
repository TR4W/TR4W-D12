# Lint-DomainPurity -- the domain layer stays a domain layer.
#
# WHY THIS EXISTS AT ALL, and why it shipped WITH the first domain unit rather
# than after it: every time this tree has needed several files to agree, the
# answer has been a lint and never a convention -- Lint-FormDefaults,
# Lint-FormEvents, Lint-SettingsMigration, Lint-Win32Dialogs. Without one, a
# `uses Forms` arrives in the domain inside a month, in a commit that is about
# something else entirely, and nothing points at it.
#
# THE RULE: no unit under src\domain\ may reference the widget set, the Windows
# unit, the window-handle array, or a main-window element.
#
# Classes, SysUtils and SyncObjs ARE allowed. They are the FCL and the RTL, not
# the LCL -- available on every platform TR4W will target.
#
# See docs\DOMAIN_LAYER_SEQUENCE.md for what the layer is for and the order the
# rest of it arrives in.

param(
   [string]$SourceDir = (Join-Path $PSScriptRoot '..\src\domain')
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path $SourceDir)) {
   Write-Host "  Lint-DomainPurity: no $SourceDir yet, nothing to check."
   exit 0
}

# Unit names that mean "this is not domain code any more".
$forbiddenUnits = @(
   'Forms', 'Controls', 'Graphics', 'StdCtrls', 'ExtCtrls', 'ComCtrls',
   'Grids', 'Dialogs', 'Menus', 'Buttons', 'LCLType', 'LCLIntf', 'LMessages',
   'Windows', 'Messages', 'CommCtrl', 'uCommctrl', 'ShellAPI'
)

# Identifiers that mean the same thing even without a uses clause.
$forbiddenTokens = @(
   @{ Pattern = '\bwh\s*\['      ; What = 'the window-handle array wh[]' },
   @{ Pattern = '\bmwe[A-Z]\w*'  ; What = 'a main-window element (mwe*)'  },
   @{ Pattern = '\bHWND\b'       ; What = 'HWND'                          },
   @{ Pattern = '\bTR4WMainForm\b'; What = 'the main form'                }
)

$violations = @()
$files = Get-ChildItem -Path $SourceDir -Recurse -Include *.pas, *.PAS, *.inc

foreach ($f in $files) {
   $lineNo = 0
   $inBlockComment = $false

   foreach ($raw in (Get-Content -LiteralPath $f.FullName)) {
      $lineNo++
      $line = $raw

      # Strip comments before matching. A lint that fires on prose gets ignored,
      # and this file's own header names every forbidden unit.
      if ($inBlockComment) {
         if ($line -match '\}') { $line = $line -replace '^[^}]*\}', ''; $inBlockComment = $false }
         else { continue }
      }
      $line = $line -replace '\{[^}]*\}', ''
      $line = $line -replace '\(\*.*?\*\)', ''
      if ($line -match '\{') { $line = $line -replace '\{.*$', ''; $inBlockComment = $true }
      $line = $line -replace '//.*$', ''
      if ([string]::IsNullOrWhiteSpace($line)) { continue }

      foreach ($u in $forbiddenUnits) {
         if ($line -match "(?i)(^|[\s,])$([regex]::Escape($u))\s*[,;]") {
            $violations += "$($f.Name):$lineNo uses $u"
         }
      }

      foreach ($t in $forbiddenTokens) {
         if ($line -match $t.Pattern) {
            $violations += "$($f.Name):$lineNo references $($t.What)"
         }
      }
   }
}

if ($violations.Count -gt 0) {
   Write-Host ''
   Write-Host 'Lint-DomainPurity: the domain layer reached into the UI.' -ForegroundColor Red
   foreach ($v in $violations) { Write-Host "    $v" -ForegroundColor Red }
   Write-Host ''
   Write-Host '  A domain unit holds STATE. Deciding what that state looks like --'
   Write-Host '  a caption, a colour, which control -- belongs in src\ui\lcl\, and'
   Write-Host '  reaching the UI from a worker thread is what this layer exists to'
   Write-Host '  make impossible. See docs\DOMAIN_LAYER_SEQUENCE.md.'
   exit 1
}

Write-Host "  Lint-DomainPurity: $($files.Count) domain file(s) checked, no UI references."
exit 0
