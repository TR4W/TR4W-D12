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
. (Join-Path $PSScriptRoot 'Get-ScanExclusions.ps1')   # Test-Tr4wScannable -- IDE backup dirs are not source


if (-not (Test-Path $SourceDir)) {
   Write-Host "  Lint-DomainPurity: no $SourceDir yet, nothing to check."
   exit 0
}

# Unit names that mean "this is not domain code any more".
$forbiddenUnits = @(
   'Forms', 'Controls', 'Graphics', 'StdCtrls', 'ExtCtrls', 'ComCtrls',
   'Grids', 'Dialogs', 'Menus', 'Buttons', 'LCLType', 'LCLIntf', 'LMessages',
   'Windows', 'Messages', 'CommCtrl', 'ShellAPI'
   # 'uCommctrl' stood in this list and was removed 2026-09-08: the unit is
   # deleted, so the entry could never fire.  FPC's own 'CommCtrl' stays --
   # that one still exists and is still forbidden in domain code.
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
   # WHICH DELIMITER CLOSES THE COMMENT WE ARE INSIDE: '', '}' or '*)'.
   #
   # IT TRACKED ONLY { } UNTIL 2026-09-10, AND CLAUDE.md MANDATES (* *).  So
   # this lint could see across only the comment style the repository forbids,
   # and a multi-line (* *) comment was scanned AS CODE.  It fired on the prose
   # "OFF WINDOWS, SAY NOTHING ABOUT A PATH WE CANNOT KNOW" in uLogDatabase,
   # because ' WINDOWS,' matches the uses-clause pattern exactly.
   #
   # A lint that reads commented text reports work that does not exist and gets
   # ignored -- which is the one failure mode a guard cannot survive.
   $blockCloser = ''

   foreach ($raw in (Get-Content -LiteralPath $f.FullName)) {
      $lineNo++
      $line = $raw

      # Strip comments before matching. This file's own header names every
      # forbidden unit, so scanning prose would flag the lint itself.
      if ($blockCloser -ne '') {
         $at = $line.IndexOf($blockCloser)
         if ($at -ge 0) {
            $line = $line.Substring($at + $blockCloser.Length)
            $blockCloser = ''
         }
         else { continue }
      }

      $line = $line -replace '\{[^}]*\}', ''
      $line = $line -replace '\(\*.*?\*\)', ''

      # Whichever opener comes FIRST decides, so a '{' inside an unclosed
      # (* *) does not end it early -- and vice versa.
      $ob = $line.IndexOf('{')
      $op = $line.IndexOf('(*')
      if ($ob -ge 0 -and ($op -lt 0 -or $ob -lt $op)) {
         $line = $line.Substring(0, $ob); $blockCloser = '}'
      }
      elseif ($op -ge 0) {
         $line = $line.Substring(0, $op); $blockCloser = '*)'
      }

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
