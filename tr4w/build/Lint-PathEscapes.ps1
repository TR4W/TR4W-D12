<#
.SYNOPSIS
   Catches Windows paths corrupted by backslash-escape interpretation.

.DESCRIPTION
   Writing settings\tr4w.json through a tool that interprets backslash escapes
   turns the \t into a LITERAL TAB, leaving "settings<TAB>r4w.json" in the file.
   It survives review because a tab and a backslash-t look identical in most
   editors and diffs, and nothing else complains: the compiler is happy (a tab
   is a legal character in a Pascal string), the tests pass, and the damage only
   shows when a human reads the log line or the comment.

   IT HAS HAPPENED AT LEAST FIVE TIMES IN THIS TREE. Three were repaired on
   2026-08-20 (see that day's commit), NY4I repaired two more in
   docs\BENCH_QUEUE.md on 2026-08-21, and two more went into SOURCE the same day
   -- uCFG.pas's csJSON error message and uBandPlanForm's header comment -- which
   is what prompted this lint. Every one was written by an agent, and every one
   was invisible until someone read the text.

   THE SIGNATURE IS NARROW ON PURPOSE. A tab followed by a letter is far too
   broad here: the lang files align comment tables with tabs, uCommctrl carries
   pasted MSDN tables, and full.nsi indents with them. What is unambiguous is a
   tab followed by the tail of a path this project actually uses -- every path in
   TR4W contains tr4w, target or tools, so \t before one of those is the
   corruption and nothing else. Measured 2026-08-21: this pattern matched
   exactly the two real defects across src, tr4w.dpr and docs, and nothing else.

   THE REAL FIX IS UPSTREAM, and it belongs in whatever writes the file: use a
   raw string, or double the backslash, or write the path with forward slashes.
   This lint is the backstop for when that is forgotten.
#>
param(
   [string] $SourceDir
)

$ErrorActionPreference = 'Stop'

if (-not $SourceDir) {
   $SourceDir = Split-Path -Parent $PSScriptRoot
}

# The tails of the paths this project uses. Extending the list is fine; each
# addition should be checked for false positives against the whole tree first.
$tails = @('r4w', 'arget', 'ools')
$tab   = [char]9
$pattern = $tab + '(' + ($tails -join '|') + ')'

$extensions = @('.pas', '.dpr', '.dpk', '.inc', '.lfm', '.md', '.ps1', '.psm1')
$skipDir    = '\\\.git\\|\\build-out\\|\\graphify-out\\|\\release\\|\\backup|\\dcu'

if (-not (Test-Path -LiteralPath $SourceDir -PathType Container)) {
   Write-Output "Lint-PathEscapes: source directory not found: $SourceDir"
   exit 1
}

$files = @(Get-ChildItem -LiteralPath $SourceDir -Recurse -File -ErrorAction SilentlyContinue |
           Where-Object { $extensions -contains $_.Extension.ToLowerInvariant() -and
                          $_.FullName -notmatch $skipDir })

if ($files.Count -eq 0) {
   Write-Output "Lint-PathEscapes: NO files found under $SourceDir -- refusing to report a pass."
   exit 1
}

$violations = @()
foreach ($f in $files) {
   $n = 0
   foreach ($line in [IO.File]::ReadAllLines($f.FullName)) {
      $n++
      if ($line -cmatch $pattern) {
         $shown = $line.Trim() -replace $tab, '<TAB>'
         $violations += ("{0}:{1}  {2}" -f $f.Name, $n, $shown.Substring(0, [Math]::Min(88, $shown.Length)))
      }
   }
}

if ($violations.Count -gt 0) {
   $violations | ForEach-Object { Write-Output ("  " + $_) }
   Write-Output "Lint-PathEscapes: a Windows path has been corrupted -- \t became a literal TAB."
   Write-Output "  'settings\tr4w.json' written through a backslash-interpreting tool becomes"
   Write-Output "  'settings<TAB>r4w.json'. Fix the text, and fix the WRITER: raw strings, doubled"
   Write-Output "  backslashes, or forward slashes."
   exit 1
}

Write-Output ("Lint-PathEscapes: {0} file(s) checked, no backslash-escape corruption." -f $files.Count)
exit 0
