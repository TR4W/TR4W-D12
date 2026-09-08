<#
.SYNOPSIS
   WinAnsi -> LclText where the result is a TF.Format format string.

.DESCRIPTION
   NY4I: "if I was writing an LCL application from scratch, would I include
   WinAnsi calls for some reason? If not, then we need to get rid of them and
   do whatever we would do in an LCL application written from scratch."

   No, you would not. WinAnsi converts UTF-16 into the machine's ANSI code page
   for a Win32 '...A' entry point. An LCL application has none: it builds a
   string, calls SysUtils.Format, and assigns it to a control.

   IT EXISTED BECAUSE THE CHAIN BELOW IT WAS WIN32, and that chain has now
   collapsed:

       WinAnsi          fed a PAnsiChar
         PAnsiChar      because TF.Format took one
           TF.Format    because it WAS wsprintfA -- a user32 export

   TF.Format is Pascal over SysUtils.Format as of 2026-09-07. So at the 42
   sites where WinAnsi's result is a FORMAT STRING, it is no longer merely
   unnecessary -- it is WRONG. It hands cp1252 bytes to the RTL, which tags
   them with DefaultSystemCodePage (UTF-8), and the text ends up in an LCL
   control that wants UTF-8. That is the doubled-accent bug WinAnsi was written
   to prevent, arriving from the other direction.

   LclText is the existing helper for exactly this: UTF8Encode, no code-page
   tag, already used for LCL-bound text. Same shape of call, right encoding.

   WHAT THIS DOES NOT TOUCH, because each needs a decision rather than a sweep:
     9  sites feeding a genuine Win32 ...A call (lstrcpynA and friends) -- the
        WIN32 CALL is what should go there, and WinAnsi with it
     4  sites feeding a socket, where the wire encoding is the question
    15  others

   Comment-aware, via PascalSource.psm1: an earlier blanket regex in this tree
   rewrote 102 comments, and this file exists partly so that is not repeated.
#>

param(
   [string] $SourceDir = (Join-Path (Split-Path -Parent $PSScriptRoot) 'src'),
   [switch] $WhatIf
)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'PascalSource.psm1') -Force

$repo  = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
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
      $code = Get-PascalCodeOnlyLines -Path $path
      $orig = [System.IO.File]::ReadAllLines($path)

      $hits = 0
      $out  = New-Object System.Collections.ArrayList
      for ($i = 0; $i -lt $orig.Count; $i++) {
         $line = $orig[$i]
         $codeLine = if ($i -lt $code.Count) { $code[$i] } else { '' }

         # Only where the CODE half both calls WinAnsi and is a Format call.
         if ($codeLine -match 'WinAnsi\s*\(' -and $codeLine -match 'Format\s*\(') {
            $new = $line -replace 'WinAnsi\s*\(', 'LclText('
            if ($new -ne $line) { $hits++; $line = $new }
         }
         [void]$out.Add($line)
      }

      if ($hits -gt 0) {
         $files++
         $total += $hits
         Write-Host ("  {0,-30} {1}" -f $_.Name, $hits)
         if (-not $WhatIf) {
            $nl = if ($raw -match "`r`n") { "`r`n" } else { "`n" }
            $text = ($out -join $nl)
            if ($raw.EndsWith($nl)) { $text += $nl }
            # Preserve a BOM if the file had one -- 72 files here are pinned.
            $head = [System.IO.File]::ReadAllBytes($path)
            $hadBom = ($head.Length -ge 3 -and $head[0] -eq 0xEF -and $head[1] -eq 0xBB -and $head[2] -eq 0xBF)
            [System.IO.File]::WriteAllText($path, $text, (New-Object System.Text.UTF8Encoding($hadBom)))
         }
      }
   }

Write-Host ""
if ($WhatIf) {
   Write-Host "Fix-WinAnsiFormat: $total call(s) in $files file(s) WOULD become LclText."
} else {
   Write-Host "Fix-WinAnsiFormat: $total call(s) in $files file(s) now use LclText."
}
