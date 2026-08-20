<#
.SYNOPSIS
   Reports commented-out CODE across the TR4W tree, so a removal sweep can be
   sized and ordered before it is started.

.DESCRIPTION
   NOT a lint and NOT wired into the build. It answers one question -- "how much
   commented-out code is there, and where is the worst of it" -- and it is meant
   to be read by a person deciding what to delete.

   WHY IT USES build\PascalSource.psm1 AND DOES NOT PARSE ANYTHING ITSELF.
   On 2026-08-20 a throwaway scanner written for this exact question reported
   that 24.7% of the tree was commented out, with VC.pas at 96%. Both numbers
   were nonsense. The scanner did not understand a brace inside a string literal
   -- and `{OutsideStateDOMFile:'MINNESOTA';  }` is not even the hard case --
   so its nesting depth went positive somewhere in the file and never came back,
   after which EVERY REMAINING LINE counted as commented. It ended VC.pas two
   braces deep.

   The module already knows the three rules that matter, and has paid for them:

      * `{$IFDEF}` and `(*$...*)` are DIRECTIVES, not comments.
      * a brace inside a string literal opens nothing.
      * `//` inside a string literal ('http://...') comments out nothing.

   It also carries `(* *)` state, which the throwaway version did not handle at
   all -- NY4I raised exactly that gap.

   TWO THINGS THIS REPORT DOES THAT A LINE COUNT CANNOT.

   1. It separates commented-out CODE from PROSE. A tree whose GPL headers and
      explanatory comments are counted as dead code produces a number nobody can
      act on. Classification is per BLOCK, not per line, so one semicolon in a
      paragraph does not make the paragraph code.

   2. It reports files where the comment state does not return to neutral at end
      of file. That is either a genuine unterminated comment or a parser gap, and
      in both cases the file's numbers are UNSAFE -- so they are quarantined and
      reported separately rather than folded into a total. This is the check
      whose absence produced the 24.7%.

.PARAMETER SourceDir
   Root to scan. Defaults to the tr4w tree containing this script.

.PARAMETER MinBlock
   Only report blocks of at least this many consecutive commented lines.
   Default 8 -- below that it is usually a disabled line or two, not a removal
   candidate.

.PARAMETER Top
   How many blocks to list. Default 25. Use -Detail for all of them.

.PARAMETER Detail
   List every block that meets -MinBlock, not just the top N.

.PARAMETER CodeRatio
   Fraction of a block's lines that must look like Pascal for the block to be
   called code rather than prose. Default 0.34.

.PARAMETER Csv
   Also write every reported block to this path as CSV, for sorting elsewhere.

.EXAMPLE
   .\build\Report-CommentedCode.ps1
   .\build\Report-CommentedCode.ps1 -MinBlock 20 -Csv commented.csv
#>

param(
   [string] $SourceDir,
   [int]    $MinBlock  = 8,
   [int]    $Top       = 25,
   [switch] $Detail,
   [double] $CodeRatio = 0.34,
   [string] $Csv
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot 'PascalSource.psm1') -Force

if (-not $SourceDir) {
   $SourceDir = Split-Path -Parent $PSScriptRoot
}
if (-not (Test-Path -LiteralPath $SourceDir)) {
   Write-Error ("Report-CommentedCode: no such directory: {0}" -f $SourceDir)
   exit 2
}

# --------------------------------------------------------------------------
# Does this commented-away text look like Pascal CODE rather than English?
#
# DELIBERATELY NARROW. The costly mistake here is calling documentation dead
# code, because that inflates the number the sweep is planned against and puts
# prose on the deletion list. Every pattern below is one that ordinary English
# does not produce:
#
#   * `:=`               -- an assignment; nothing else uses it.
#   * a trailing `;`     -- the single strongest Pascal signal. English
#                           sentences do not end in a semicolon; statements do.
#   * a bare block word  -- a line that is only `begin` / `end;` / `try`.
#   * a declaration head -- `procedure Foo` / `function Foo`.
#
# NOT included, and on purpose: `if`/`then`/`for`/`of`. "If the window is
# disabled, then ..." is a sentence this script must not claim is code, and
# every early draft of this list got that wrong.
# --------------------------------------------------------------------------
function Test-LooksLikePascalCode
{
   param([Parameter(Mandatory = $true)][AllowEmptyString()][string] $Text)

   $t = $Text.Trim()
   if ($t -eq '') { return $false }

   # Strip the comment markers themselves so `// x := 1` is judged on `x := 1`.
   $t = $t -replace '^\s*//+', ''
   $t = $t -replace '^\s*\{', ''
   $t = $t -replace '\}\s*$', ''
   $t = $t -replace '^\s*\(\*', ''
   $t = $t -replace '\*\)\s*$', ''
   $t = $t.Trim()
   if ($t -eq '') { return $false }

   if ($t -match ':=')                                     { return $true }
   if ($t -match ';\s*$')                                  { return $true }
   if ($t -match '^(begin|end;?|else|try|finally|except|repeat)$') { return $true }
   if ($t -match '^(procedure|function|constructor|destructor)\s+\w') { return $true }

   return $false
}

# --------------------------------------------------------------------------
# One file -> its blocks of consecutive fully-commented lines.
#
# "Fully commented" means the sanitized line is empty while the raw line is not.
# A TRAILING comment on a live statement is not interesting here: nobody deletes
# those in a sweep, and counting them would drown the blocks that matter.
# --------------------------------------------------------------------------
function Get-CommentedBlocks
{
   param(
      [Parameter(Mandatory = $true)][string] $Path
   )

   $lines = [System.IO.File]::ReadAllLines($Path)
   $state = ''

   $blocks  = New-Object System.Collections.ArrayList
   $runFrom = 0
   $runText = New-Object System.Collections.ArrayList

   function Close-Run
   {
      param($From, $Text, $Blocks)

      if ($Text.Count -eq 0) { return }

      $codeCount = 0
      foreach ($t in $Text) {
         if (Test-LooksLikePascalCode -Text $t) { $codeCount++ }
      }

      [void]$Blocks.Add([pscustomobject]@{
         FirstLine = $From
         LastLine  = $From + $Text.Count - 1
         Lines     = $Text.Count
         CodeLines = $codeCount
         Sample    = ($Text | Where-Object { $_.Trim() -ne '' } | Select-Object -First 1)
      })
   }

   for ($i = 0; $i -lt $lines.Count; $i++) {
      $raw = $lines[$i]

      $stateBefore = $state

      $ref   = [ref] $state
      $code  = (Get-PascalCodeOnlyLine -Line $raw -State $ref)
      $state = $ref.Value

      # A BLANK LINE INSIDE A BLOCK COMMENT IS PART OF THE COMMENT.
      #
      # The obvious test -- "raw is not blank and the sanitized line is" --
      # breaks a run at every empty line, and commented-out code is FULL of
      # empty lines because it was formatted code before it was commented. The
      # first draft split HELP.PAS's single 387-line commented-out procedure
      # body into a dozen fragments, the largest 42 lines, which understated
      # exactly the blocks this report exists to surface.
      #
      # $stateBefore is the state ENTERING the line, so a line that arrives
      # already inside a { } or (* *) is part of the run whether or not it has
      # any characters on it.
      $isCommented = ($stateBefore -ne '') -or
                     (($raw.Trim() -ne '') -and ($code.Trim() -eq ''))

      if ($isCommented) {
         if ($runText.Count -eq 0) { $runFrom = $i + 1 }
         [void]$runText.Add($raw)
      }
      else {
         Close-Run -From $runFrom -Text $runText -Blocks $blocks
         $runText.Clear()
      }
   }
   Close-Run -From $runFrom -Text $runText -Blocks $blocks

   return [pscustomobject]@{
      Blocks     = $blocks
      TotalLines = $lines.Count
      # '' means the scanner returned to neutral. Anything else means an
      # unterminated { or (* at end of file -- see the quarantine below.
      EndState   = $state
   }
}

# --------------------------------------------------------------------------

$files = @(Get-TR4WPascalFiles -Root $SourceDir)
if ($files.Count -eq 0) {
   Write-Error ("Report-CommentedCode: no Pascal files under {0}" -f $SourceDir)
   exit 2
}

$all        = New-Object System.Collections.ArrayList
$suspect    = New-Object System.Collections.ArrayList
$totalLines = 0
$codeLines  = 0
$proseLines = 0

foreach ($f in $files) {
   $r = Get-CommentedBlocks -Path $f.FullName

   if ($r.EndState -ne '') {
      # QUARANTINED, NOT COUNTED. The state machine is mid-comment at end of
      # file, so every line after the opener was classified as commented and the
      # file's numbers mean nothing. Folding them into a total is precisely the
      # error this script exists to avoid.
      [void]$suspect.Add([pscustomobject]@{
         File     = $f.FullName.Substring($SourceDir.Length).TrimStart('\')
         EndState = $r.EndState
      })
      continue
   }

   $totalLines += $r.TotalLines

   foreach ($b in $r.Blocks) {
      $isCode = ($b.Lines -gt 0) -and
                (($b.CodeLines / $b.Lines) -ge $CodeRatio) -and
                ($b.CodeLines -ge 2)

      if ($isCode) { $codeLines += $b.Lines } else { $proseLines += $b.Lines }

      if ($b.Lines -ge $MinBlock -and $isCode) {
         [void]$all.Add([pscustomobject]@{
            Lines  = $b.Lines
            File   = $f.FullName.Substring($SourceDir.Length).TrimStart('\')
            First  = $b.FirstLine
            Last   = $b.LastLine
            Code   = $b.CodeLines
            Sample = $(if ($b.Sample) { $b.Sample.Trim() } else { '' })
         })
      }
   }
}

$sorted = @($all | Sort-Object -Property Lines -Descending)

Write-Output ''
Write-Output ('Report-CommentedCode -- {0}' -f $SourceDir)
Write-Output ('   files scanned            : {0}' -f ($files.Count - $suspect.Count))
Write-Output ('   source lines             : {0}' -f $totalLines)
if ($totalLines -gt 0) {
   Write-Output ('   commented-out CODE lines : {0}  ({1:N1}%)' -f $codeLines, (100.0 * $codeLines / $totalLines))
   Write-Output ('   comment PROSE lines      : {0}  ({1:N1}%)' -f $proseLines, (100.0 * $proseLines / $totalLines))
}
Write-Output ('   removal-candidate blocks : {0}  (>= {1} lines)' -f $sorted.Count, $MinBlock)
Write-Output ''

if ($suspect.Count -gt 0) {
   # LOUD, because these are the files whose numbers a naive tool would have
   # invented rather than skipped.
   Write-Output ('*** {0} file(s) EXCLUDED -- comment state unterminated at end of file.' -f $suspect.Count)
   Write-Output '    Either a genuine unterminated comment or a gap in the parser.'
   Write-Output '    Their line counts are NOT in the totals above.'
   foreach ($s in $suspect) {
      Write-Output ('      {0}   (open {1})' -f $s.File, $s.EndState)
   }
   Write-Output ''
}

$show = $(if ($Detail) { $sorted } else { $sorted | Select-Object -First $Top })

if ($show.Count -gt 0) {
   Write-Output 'Largest blocks of commented-out code:'
   Write-Output ''
   foreach ($b in $show) {
      Write-Output ('  {0,5} lines  {1}:{2}-{3}' -f $b.Lines, $b.File, $b.First, $b.Last)
      if ($b.Sample -ne '') {
         $sample = $b.Sample
         if ($sample.Length -gt 78) { $sample = $sample.Substring(0, 78) + '...' }
         Write-Output ('            | {0}' -f $sample)
      }
   }
   if (-not $Detail -and $sorted.Count -gt $Top) {
      Write-Output ''
      Write-Output ('  ... and {0} more. Use -Detail for all, or -Csv to sort elsewhere.' -f ($sorted.Count - $Top))
   }
   Write-Output ''
}

Write-Output 'By file, worst first:'
Write-Output ''
$byFile = @($sorted | Group-Object -Property File |
            ForEach-Object {
               [pscustomobject]@{
                  File   = $_.Name
                  Blocks = $_.Count
                  Lines  = ($_.Group | Measure-Object -Property Lines -Sum).Sum
               }
            } | Sort-Object -Property Lines -Descending)

foreach ($g in ($byFile | Select-Object -First $(if ($Detail) { $byFile.Count } else { 20 }))) {
   Write-Output ('  {0,6} lines in {1,3} block(s)   {2}' -f $g.Lines, $g.Blocks, $g.File)
}
Write-Output ''

if ($Csv) {
   $sorted | Export-Csv -LiteralPath $Csv -NoTypeInformation -Encoding UTF8
   Write-Output ('CSV written: {0}' -f $Csv)
}

# A REPORT, not a gate: always 0 so nothing can wire this into a build and make
# a judgement call fail someone's compile.
exit 0
