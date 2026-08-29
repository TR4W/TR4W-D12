<#
.SYNOPSIS
   Fail the build if production code declares a hand-typed table indexed by a
   radio enum.

.DESCRIPTION
   WHY THIS EXISTS. TR4W carried two of these for years:

     RadioParametersArray   : array[InterfacedRadioType] of TRadioParameters
     InterfacedRadioTypeSA  : array[InterfacedRadioType] of PAnsiChar

   Both were maintained by hand beside the enum in VC.pas -- two copies of one
   list -- and both had to be extended for every radio added. That is not merely
   untidy. On 2026-08-28 the name table was found to be ONE ROW OUT OF STEP with
   the enum: missing TS140, carrying a TS530 the enum never had. Both were 101
   entries long, so it compiled. It re-synchronised further down, so only a
   four-model window was wrong. Nothing failed.

   The result: an operator whose config said TS440 got the TS-140 driver, TS450
   got the TS-440, and TS140 could not be selected at all.

   The drift is invisible by construction. A parallel array indexed by an enum
   cannot report that it has slipped -- it can only be the wrong LENGTH, and
   these were not.

   So the shape is banned in production code. The factory owns per-model data:
   a radio states its own name, address, capabilities and serial defaults in its
   own unit, and uRadioRegistry answers questions about it. Adding a radio
   should touch that radio's file and nothing else.

   WHAT IS NOT FLAGGED, and why:

     * a `var` array of the same shape -- gTokenStore, gCapCache -- is a runtime
       CACHE. It holds no typed data, code fills it, and nobody maintains its
       contents by hand, so it cannot drift. The danger is a typed CONSTANT with
       a literal element list, one entry per radio, in enum order. So the test
       is the shape PLUS an initialiser;
     * anything inside a block comment, including this repository's own
       explanations of the two deleted arrays. A linter that fires on commented
       code gets ignored;
     * test units. A frozen historical list is what a regression pin IS, and a
       pin that drifts fails rather than misleads.

.EXAMPLE
   .\Lint-NoRadioTables.ps1
   .\Lint-NoRadioTables.ps1 -SourceDir ..\src
#>

param(
   [string] $SourceDir = (Join-Path (Split-Path $PSScriptRoot -Parent) 'src'),
   [switch] $Quiet
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Enums that name a radio model. A table indexed by one of these is a per-model
# data table, whatever it happens to be called.
$enums   = @('InterfacedRadioType')
$pattern = 'array\s*\[\s*(' + ($enums -join '|') + ')\s*\]'

$findings = @()
$scanned  = 0

foreach ($f in Get-ChildItem -Path $SourceDir -Recurse -Include *.pas,*.PAS,*.inc,*.dpr)
   {
   $scanned++
   $lines = @(Get-Content -LiteralPath $f.FullName)
   $inComment = $false
   $n = 0

   foreach ($line in $lines)
      {
      $n++
      $wasInComment = $inComment

      # Track { } and (* *) state across lines before judging anything.
      $probe = $line
      while ($probe -ne '')
         {
         if (-not $inComment)
            {
            $o1 = $probe.IndexOf('{')
            $o2 = $probe.IndexOf('(*')
            if ($o1 -lt 0 -and $o2 -lt 0) { break }
            $o = if ($o1 -lt 0) { $o2 } elseif ($o2 -lt 0) { $o1 } else { [Math]::Min($o1, $o2) }
            $inComment = $true
            $probe = $probe.Substring($o + 1)
            }
         else
            {
            $c1 = $probe.IndexOf('}')
            $c2 = $probe.IndexOf('*)')
            if ($c1 -lt 0 -and $c2 -lt 0) { break }
            $c = if ($c1 -lt 0) { $c2 + 1 } elseif ($c2 -lt 0) { $c1 } else { [Math]::Min($c1, $c2 + 1) }
            $inComment = $false
            $probe = $probe.Substring($c + 1)
            }
         }

      if ($line -notmatch $pattern) { continue }
      if ($wasInComment) { continue }
      if ($line.TrimStart().StartsWith('//')) { continue }

      # An initialiser is what makes it hand-maintained data. It may sit on this
      # line ('= (') or on one of the next two, since these declarations wrap.
      $hasInit = $false
      for ($k = 0; $k -lt 3; $k++)
         {
         $idx = [Math]::Min($n - 1 + $k, $lines.Count - 1)
         if ($lines[$idx] -match '=\s*\(' -or $lines[$idx] -match '^\s*\(\s*$') { $hasInit = $true; break }
         }
      if (-not $hasInit) { continue }

      $findings += [pscustomobject]@{
         File = $f.FullName.Substring($SourceDir.Length).TrimStart('\')
         Line = $n
         Text = $line.Trim()
      }
      }
   }

if (-not $Quiet)
   {
   # A lint that scans nothing and reports success is worse than no lint.
   if ($scanned -eq 0)
      {
      Write-Host "Lint-NoRadioTables: NO FILES SCANNED under $SourceDir -- that is a failure, not a pass."
      exit 1
      }

   if ($findings.Count -eq 0)
      {
      Write-Host ("Lint-NoRadioTables: {0} file(s) checked, no hand-typed per-model radio tables." -f $scanned)
      }
   else
      {
      foreach ($x in $findings)
         {
         Write-Host ("  {0}({1}): {2}" -f $x.File, $x.Line, $x.Text)
         }
      Write-Host ''
      Write-Host ("Lint-NoRadioTables: {0} hand-typed table(s) indexed by a radio enum." -f $findings.Count)
      Write-Host 'A table like this must be extended by hand for every radio and cannot report'
      Write-Host 'that it has drifted from the enum. Two of them did exactly that, and four'
      Write-Host 'Kenwoods selected the wrong driver for it. Put the data on the radio class'
      Write-Host 'and ask uRadioRegistry -- see docs/ADDING_A_RADIO.md.'
      }
   }

exit ([int] ($findings.Count -gt 0))
