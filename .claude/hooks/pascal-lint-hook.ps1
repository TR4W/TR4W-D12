<#
   Claude Code PostToolUse hook: after an Edit/Write/MultiEdit, run the committed
   Pascal linters on the file that was just edited, but report ONLY violations on
   lines that were actually changed this session -- i.e. the uncommitted diff vs
   HEAD (or the whole file if it is brand-new / untracked).  Pre-existing legacy
   violations in a file you merely touched are NOT reported.

   Linters run (both located worktree-relative, so this hook is portable across
   the D7 tree, the D12 tree, and any linked worktree):
     * Lint-PascalBeginEnd.ps1 (always) -- begin/end coding standard.
     * Lint-PCharAnsi.ps1 (self-gating) -- D12 PChar(@...) / byte-walk hazards.

   "Warn" mode: it never blocks the tool (the edit already happened); exit 2 just
   feeds the findings back to Claude as feedback to fix.  Any plumbing error
   exits 0 so the hook can never wedge the session.

   Scope: *.pas under tr4w\src and any *.lpr/*.dpr; skips include/Indy and *~
   backups.
#>
# Note: do NOT set $ErrorActionPreference = 'Stop' -- native git commands write
# warnings/errors to stderr (e.g. LF/CRLF notices, "untracked path"), and under
# 'Stop' PowerShell would turn those into terminating errors and crash the hook.

try {
   $raw = [Console]::In.ReadToEnd()
   if ([string]::IsNullOrWhiteSpace($raw)) { exit 0 }
   $json = $raw | ConvertFrom-Json -ErrorAction Stop
   $file = $json.tool_input.file_path
}
catch { exit 0 }   # never block on hook-plumbing problems

if ([string]::IsNullOrWhiteSpace($file)) { exit 0 }

$norm = $file -replace '/', '\'
# Run git against the worktree that actually contains the edited file (not a
# hardcoded repo path) so diff-scoping works in linked worktrees too.
$GitDir = Split-Path -Parent $file
if ($norm -match '~$')          { exit 0 }   # editor backup (e.g. PostUnit.PAS~)
if ($norm -match '\\include\\') { exit 0 }   # bundled Indy / third-party
$isPas = $norm -match '\.pas$'
# .lpr as well as .dpr: the program files were renamed on 2026-08-29 (this is
# FPC/Lazarus, the Delphi extension was a leftover), and a hook that still
# matched only .dpr had quietly stopped covering tr4w.lpr and the test program.
$isDpr = $norm -match '\.(lpr|dpr)$'
if (-not ($isPas -or $isDpr))   { exit 0 }
if ($isPas -and ($norm -notmatch '\\tr4w\\src\\')) { exit 0 }
if (-not (Test-Path -LiteralPath $file -PathType Leaf)) { exit 0 }

# Locate both linters in the edited file's OWN worktree (portable: works in the
# D7 tree, the D12 tree C:\tr4w-d12, and any linked worktree).
$wtRoot = & git -C $GitDir rev-parse --show-toplevel 2>$null
if (-not $wtRoot) { exit 0 }
$wtRootWin = $wtRoot -replace '/', '\'
$BeginEndLinter = Join-Path $wtRootWin 'tr4w\build\Lint-PascalBeginEnd.ps1'
$PCharLinter    = Join-Path $wtRootWin 'tr4w\build\Lint-PCharAnsi.ps1'

# Collect raw violations from every applicable linter.  Each linter emits one
# line per violation as  <file>:<line>: <message>  and exits non-zero if any.
$out = @()

if (Test-Path -LiteralPath $BeginEndLinter) {
   $r = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $BeginEndLinter $file
   if ($LASTEXITCODE -ne 0 -and $r) { $out += $r }
}

if (Test-Path -LiteralPath $PCharLinter) {
   $r = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $PCharLinter $file
   if ($LASTEXITCODE -ne 0 -and $r) { $out += $r }
}

if (-not $out -or $out.Count -eq 0) { exit 0 }   # clean

# Decide which lines count as "mine".
& git -C $GitDir ls-files --error-unmatch -- $file 1>$null 2>$null
$tracked = ($LASTEXITCODE -eq 0)

$report = @()
if (-not $tracked) {
   # Brand-new / untracked file: every line is new -> report all.
   $report = $out
}
else {
   # Tracked: keep only violations on lines changed vs HEAD (this session's diff).
   $changed = New-Object 'System.Collections.Generic.HashSet[int]'
   $diff = & git -C $GitDir diff -U0 HEAD -- $file 2>$null
   foreach ($dl in $diff) {
      if ($dl -match '^@@ -\d+(?:,\d+)? \+(\d+)(?:,(\d+))? @@') {
         $start = [int]$Matches[1]
         $count = if ($Matches[2]) { [int]$Matches[2] } else { 1 }
         for ($k = 0; $k -lt $count; $k++) { [void]$changed.Add($start + $k) }
      }
   }
   foreach ($o in $out) {
      if ($o -match ':(\d+): ') {
         if ($changed.Contains([int]$Matches[1])) { $report += $o }
      }
   }
}

if ($report.Count -gt 0) {
   [Console]::Error.WriteLine('Pascal lint found issues on lines you just changed:')
   foreach ($line in $report) { [Console]::Error.WriteLine('  ' + $line) }
   [Console]::Error.WriteLine("Fix these before continuing.  begin/end: wrap each if/for/while body (3-space, begin on its own line).  PChar(@...) / PChar(...)[i]: use PAnsiChar for ANSI text or PByte for raw byte walks (or add '// lint:wide-ok' if genuinely wide).")
   exit 2
}

exit 0
