<#
.SYNOPSIS
   Runs the Object Pascal style lint over ONLY the Pascal files you have changed,
   so new and edited code is held to the standard without the legacy tree
   blocking every build.

.DESCRIPTION
   build\Lint-PascalBeginEnd.ps1 currently reports ~1489 violations across 96 of
   the 154 files in src, so wiring it in wholesale would fail every build on day
   one. The rule people actually care about is that NEW code is correct, which is
   what this script enforces: it lints the files that are modified or untracked in
   the working tree and ignores everything else.

   Deliberately scoped to the WORKING TREE (uncommitted work) rather than a diff
   against some baseline branch. That gives feedback while the code is being
   written, and it means a file stops being linted once it is committed clean --
   the legacy tree is never dragged in.

   Fails open, never blocking a build for infrastructure reasons: if git is
   missing, this is not a work tree, or nothing Pascal has changed, it exits 0.

.PARAMETER ProjectDir
   The tr4w project directory (the one containing src\ and build\). Defaults to
   this script's parent.

.OUTPUTS
   One line per violation:  <file>:<line>: <message>
   Exit code 0 = clean / nothing to check, 1 = at least one violation.
#>
[CmdletBinding()]
param(
   [string] $ProjectDir
)

if (-not $ProjectDir) {
   $ProjectDir = Split-Path -Parent $PSScriptRoot
}

$linter = Join-Path $ProjectDir 'build\Lint-PascalBeginEnd.ps1'
if (-not (Test-Path -LiteralPath $linter -PathType Leaf)) {
   Write-Output "Lint-ChangedPascal: linter not found ($linter) - skipping."
   exit 0
}

# --- locate the work tree; fail open if git is unavailable -------------------
$git = Get-Command git -ErrorAction SilentlyContinue
if (-not $git) {
   Write-Output 'Lint-ChangedPascal: git not on PATH - skipping.'
   exit 0
}

$repoRoot = & git -C $ProjectDir rev-parse --show-toplevel 2>$null
if ($LASTEXITCODE -ne 0 -or -not $repoRoot) {
   Write-Output 'Lint-ChangedPascal: not a git work tree - skipping.'
   exit 0
}
$repoRoot = $repoRoot.Trim()

# --- collect changed + untracked Pascal files --------------------------------
$changed = @()
$changed += & git -C $repoRoot diff --name-only HEAD -- '*.pas' 2>$null
$changed += & git -C $repoRoot ls-files --others --exclude-standard -- '*.pas' 2>$null

$srcDir = [System.IO.Path]::GetFullPath((Join-Path $ProjectDir 'src'))

$targets = $changed |
   Where-Object { $_ } |
   ForEach-Object { [System.IO.Path]::GetFullPath((Join-Path $repoRoot $_)) } |
   Where-Object { $_.StartsWith($srcDir, [System.StringComparison]::OrdinalIgnoreCase) } |
   Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } |   # skip deletions
   Sort-Object -Unique

if (-not $targets -or $targets.Count -eq 0) {
   Write-Output 'Lint-ChangedPascal: no changed Pascal files - nothing to check.'
   exit 0
}

$output = & powershell -NoProfile -ExecutionPolicy Bypass -File $linter @targets 2>&1
$violations = @($output | Where-Object { $_ -match ':\d+:' })

foreach ($line in $violations) {
   Write-Output $line
}

if ($violations.Count -gt 0) {
   Write-Output ("Lint-ChangedPascal: {0} style violation(s) in {1} changed file(s). See CLAUDE.md for the begin/end rules." -f $violations.Count, $targets.Count)
   exit 1
}

Write-Output ("Lint-ChangedPascal: {0} changed Pascal file(s), no style violations." -f $targets.Count)
exit 0
