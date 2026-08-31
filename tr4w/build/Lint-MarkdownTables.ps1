<#
.SYNOPSIS
   Find markdown tables a text editor has hard-wrapped into nonsense.

.DESCRIPTION
   A markdown table is one row per line. An editor set to wrap at a column will
   happily split a long row across two, and the result is not a table any more --
   it renders as a run of broken cells, and it can split a word in half:

       | **Target          | Windows + Linux + macOS, full desktop parity |
       | platforms**       |                                              |
       | **Contributo      | **Open to community contributors** -- anyone |
       | rs**              | and build                                    |

   That is a real example from docs\TOOLCHAIN_SWOT_LAZARUS_VS_DELPHI.md
   (2026-08-28). NY4I hit the same thing earlier with a different editor, which
   is what makes it worth a lint rather than a reminder: it is the TOOL doing
   it, silently, to a file that still looks plausible in a diff.

   WHAT IT CHECKS. Inside a table -- a header row, then a separator row of
   dashes -- every row must have the same number of cells as the header. A row
   with fewer is the tell-tale of a wrap.

   WHAT IT DOES NOT CHECK. Alignment, padding or column widths: those are
   cosmetic and vary by author. Fenced code blocks are skipped entirely, since a
   pipe there is just a pipe.
#>

param(
   [string] $Root
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Get-ScanExclusions.ps1')   # Test-Tr4wScannable -- IDE backup dirs are not source


$here = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $Root) { $Root = Split-Path (Split-Path $here -Parent) -Parent }

function Get-CellCount
   {
   param([string] $Line)
   # Trim the outer pipes, then count the separators between cells. An escaped
   # \| is a literal and does not divide anything.
   $t = $Line.Trim()
   $t = $t -replace '\\|', "`u{0001}"
   $t = $t.Trim('|')
   return ($t -split '\|').Count
   }

$bad = @()
$files = Get-ChildItem -Path $Root -Filter '*.md' -Recurse -File | Where-Object { Test-Tr4wScannable $_.FullName } |
         Where-Object { $_.FullName -notmatch 'build-out|backup|[.]git' }

foreach ($f in $files)
   {
   $lines  = Get-Content -LiteralPath $f.FullName -Encoding UTF8
   $inCode = $false
   $header = -1
   $cells  = 0

   for ($i = 0; $i -lt $lines.Count; $i++)
      {
      $line = $lines[$i]

      if ($line -match '^\s*```') { $inCode = -not $inCode; continue }
      if ($inCode) { continue }

      if ($line -notmatch '^\s*\|') { $header = -1; continue }

      # A separator row of dashes turns the line above it into a header.
      if ($line -match '^\s*\|[\s:\-|]+\|\s*$' -and $line -match '-')
         {
         if ($i -gt 0 -and $lines[$i - 1] -match '^\s*\|')
            {
            $header = $i - 1
            $cells  = Get-CellCount $lines[$header]
            }
         continue
         }

      if ($header -ge 0)
         {
         # AN UNCLOSED BOLD MARKER INSIDE A CELL. This is the signature that
         # actually catches a wrap, and cell counting is not:
         #
         #     | **Target          | Windows + Linux + macOS ... |
         #     | platforms**       |                             |
         #
         # BOTH of those lines have two cells, so a count check passes them
         # happily -- verified before shipping this, on exactly that text. What
         # gives it away is that the wrap cut through '**Target platforms**',
         # leaving one '**' in each half. A cell that opens bold must close it.
         foreach ($cell in ($line.Trim().Trim('|') -split '\|'))
            {
            $marks = ([regex]::Matches($cell, '\*\*')).Count
            if (($marks % 2) -ne 0)
               {
               $bad += [pscustomobject]@{
                  File = $f.FullName.Substring($Root.Length + 1)
                  Line = $i + 1
                  Want = 'bold closed in the cell'
                  Got  = "$marks marker(s)"
                  Text = $line.Trim()
               }
               }
            }

         # FEWER CELLS ONLY, and that is deliberate. A wrapped row is always
         # SHORT -- the tail went to the next line. A row with MORE cells is a
         # pipe inside inline code, which several tables here use on purpose
         # (`RIG_TARGETABLE_FREQ | RIG_TARGETABLE_MODE`); flagging those would
         # bury the real thing under noise a reader learns to skip.
         $n = Get-CellCount $line
         if ($n -lt $cells)
            {
            $bad += [pscustomobject]@{
               File = $f.FullName.Substring($Root.Length + 1)
               Line = $i + 1
               Want = "$cells cell(s)"
               Got  = $n
               Text = $line.Trim()
            }
            }
         }
      }
   }

if ($bad.Count -gt 0)
   {
   Write-Output ("Lint-MarkdownTables: {0} row(s) are SHORT of their header -- a wrapped table." -f $bad.Count)
   Write-Output ''
   foreach ($b in $bad)
      {
      Write-Output ("  {0}:{1}  {2}, got {3}" -f $b.File, $b.Line, $b.Want, $b.Got)
      Write-Output ("     {0}" -f $b.Text.Substring(0, [Math]::Min(90, $b.Text.Length)))
      }
   Write-Output ''
   Write-Output 'Turn OFF hard word-wrap for markdown in the editor, and rejoin the split rows.'
   exit 1
   }

Write-Output ("Lint-MarkdownTables: {0} file(s) checked, every table row matches its header." -f $files.Count)
exit 0
