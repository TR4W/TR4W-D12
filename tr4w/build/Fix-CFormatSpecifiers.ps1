<#
.SYNOPSIS
   Respell C-style zero-pad specifiers (%0<n>) as RTL precision (%.<n>).

.DESCRIPTION
   MEASURED on fpc 3.2.2 with -Mdelphi, not read from a manual:

       SysUtils.Format('%02d', [5])   ->  ' 5'     the 0 is a WIDTH digit
       SysUtils.Format('%.2d', [5])   ->  '05'     precision zero-pads
       SysUtils.Format('%03d', [12])  ->  ' 12'
       SysUtils.Format('%.3d', [12])  ->  '012'

   C's printf reads that leading 0 as a zero-pad FLAG, so every `%0<n>` in this
   tree meant zero-padding. Two kinds of site are affected and one was ALREADY
   WRONG before any of this:

     TF.Format(...)       went to wsprintfA, so it zero-padded. Once TF calls
                          the RTL these must be respelled or the output changes.

     SysUtils.Format(...) already went to the RTL, so these have been emitting
                          ' 12' where '012' was meant -- including ADIF and
                          Cabrillo exchange fields. Respelling FIXES them.

   WHY THIS IS A SCRIPT IN build\ RATHER THAN A ONE-OFF.  The first attempt was
   a plain regex over the file text and it rewrote COMMENTS -- turning a note
   that read "Delphi 7 Format('%06d') pads with spaces" into one that says
   "%.6d pads with spaces", which is false. Several were historical notes in
   the rotator and radio drivers explaining what the wire format used to be.
   That is the same trap CLAUDE.md records for COUNT(*): the comment and the
   code are the same characters and only the context differs.

   So this uses build\PascalSource.psm1 -- the module the lints use -- to know
   which spans are code, and edits only those. Run with -WhatIf to see the
   changes without making them.
#>

param(
   [string] $SourceDir = (Join-Path (Split-Path -Parent $PSScriptRoot) 'src'),
   [switch] $WhatIf
)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'PascalSource.psm1') -Force

$repo = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$total = 0
$files = 0

Get-ChildItem -Path $SourceDir -Recurse -File |
   Where-Object {
      $_.Extension -match '^\.(pas|lpr)$' -and
      $_.FullName -notmatch '\\(backup|graphify-out)\\'
   } |
   ForEach-Object {
      $path = $_.FullName
      $raw  = [System.IO.File]::ReadAllText($path)
      # Code-only view, line by line, so a literal inside a comment is invisible.
      $code = Get-PascalCodeOnlyLines -Path $path
      $orig = [System.IO.File]::ReadAllLines($path)

      $hits = 0
      $out  = New-Object System.Collections.ArrayList
      for ($i = 0; $i -lt $orig.Count; $i++) {
         $line = $orig[$i]
         $codeLine = if ($i -lt $code.Count) { $code[$i] } else { '' }

         # Only touch a line whose CODE half carries the specifier.
         if ($codeLine -match "%-?0\d" -or $codeLine -match "%-?0\.") {
            $new = [regex]::Replace($line, "%(-?)0(\d+)", '%$1.$2')
            $new = [regex]::Replace($new, "%(-?)0\.", '%$1.')
            if ($new -ne $line) {
               $hits++
               $line = $new
            }
         }
         [void]$out.Add($line)
      }

      if ($hits -gt 0) {
         $files++
         $total += $hits
         Write-Host ("  {0,-32} {1}" -f $_.Name, $hits)
         if (-not $WhatIf) {
            # CRLF, and no trailing-newline surprise: match what was read.
            $nl = if ($raw -match "`r`n") { "`r`n" } else { "`n" }
            $text = ($out -join $nl)
            if ($raw.EndsWith($nl)) { $text += $nl }
            # PRESERVE THE BOM. WriteAllText with no encoding writes UTF-8
            # WITHOUT one, and 72 files in this tree are pinned as having a BOM
            # by Lint-BOM -- MainUnit among them. Losing it failed the build on
            # the first run of this script.
            $hadBom = $false
            $head = [System.IO.File]::ReadAllBytes($path)
            if ($head.Length -ge 3 -and $head[0] -eq 0xEF -and $head[1] -eq 0xBB -and $head[2] -eq 0xBF) { $hadBom = $true }
            $enc = New-Object System.Text.UTF8Encoding($hadBom)
            [System.IO.File]::WriteAllText($path, $text, $enc)
         }
      }
   }

Write-Host ""
if ($WhatIf) {
   Write-Host "Fix-CFormatSpecifiers: $total specifier(s) in $files file(s) WOULD be respelled."
} else {
   Write-Host "Fix-CFormatSpecifiers: $total specifier(s) respelled in $files file(s)."
}
