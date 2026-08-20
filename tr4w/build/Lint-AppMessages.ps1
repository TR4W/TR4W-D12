<#
.SYNOPSIS
   Every message `uMainWindowProc.WindowProc` handles must be claimed by
   `uMainForm.IsTR4WsOwnMessage`, or it is silently never delivered.

.DESCRIPTION
   THE MECHANISM. Since the main window became an LCL form (Phase 3a) its window
   procedure is `TR4WFormSubclassProc`, which asks `IsTR4WsOwnMessage` whether
   TR4W wants a message. If the answer is no, the message chains to the LCL's
   own procedure -- which has never heard of TR4W's private messages and does
   nothing with them. The `case` label waiting in `WindowProc` never runs.

   NOTHING ABOUT THAT FAILS LOUDLY. There is no error, no log line, no compiler
   diagnostic; a worker thread posts, the post SUCCEEDS, and the update simply
   never happens. A `SendMessage` is worse: the sender blocks, gets a
   meaningless result, and carries on as though the work was done.

   WHAT IT COST BEFORE THIS EXISTED. The list was written as literal integers,
   with a comment explaining that this avoided depending on six more units.
   Measured 2026-08-20 -- FOUR of the eight messages were not being delivered:

     * WM_APP + 213 was claimed for WM_CTY_VERSION_CHECKED, which is
       WM_APP + 210. 213 is not any message at all, so the CTY.DAT version
       check result was thrown away.
     * WM_APP + 100 was claimed for WM_TRAYBALLON, which is WM_SOCK + 3 =
       $5F7. Tray icon clicks never reached their handler.
     * WM_PANEL_UPDATE (WM_APP + 230) was never added at all, so the radio
       panel marshalling seam delivered NOTHING from the day it was written.
       That is what kept RIT/XIT/SPLIT yellow on the bench, and it survived two
       confident wrong diagnoses before anyone looked here.
     * WM_USER_HEADLESS_SYNC_REPLACE (WM_USER + 200) was never added, so the
       multi-op log replace never ran on the UI thread and the requesting
       thread blocked to be told nothing.

   The values can no longer be wrong -- the list names the constants now. This
   lint covers what is left: MEMBERSHIP. A new `case WM_FOO:` in WindowProc that
   nobody adds to the allow-list.

   HOW IT READS THE SOURCE. Through build\PascalSource.psm1, so a commented-out
   case label is not mistaken for a live one -- the same parser the other lints
   use, and for the same reason.

   WHAT IT DELIBERATELY DOES NOT CHECK: a message claimed but not handled. That
   is harmless (TR4W's proc ignores it and returns), and forbidding it would
   fight the WM_SIZE / WM_COMMAND entries that are claimed in order to be
   chained to BOTH procedures.

.PARAMETER SourceDir
   The tr4w\src directory. Defaults to src beside this script's parent.
#>

param(
   [string] $SourceDir
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot 'PascalSource.psm1') -Force

if (-not $SourceDir) {
   $SourceDir = Join-Path (Split-Path -Parent $PSScriptRoot) 'src'
}
$SourceDir = [System.IO.Path]::GetFullPath($SourceDir).TrimEnd('\', '/')

$procPath = Join-Path $SourceDir 'uMainWindowProc.pas'
$formPath = Join-Path $SourceDir 'ui\lcl\uMainForm.pas'

foreach ($p in @($procPath, $formPath)) {
   if (-not (Test-Path -LiteralPath $p)) {
      Write-Output ("Lint-AppMessages: cannot find {0}" -f $p)
      exit 2
   }
}

# ---------------------------------------------------------------- the handlers

$code = @(Get-PascalCodeOnlyLines -Path $procPath)

$start = -1
for ($i = 0; $i -lt $code.Count; $i++) {
   if ($code[$i] -match '^\s*function\s+WindowProc\b') { $start = $i; break }
}
if ($start -lt 0) {
   Write-Output "Lint-AppMessages: could not find `function WindowProc` in uMainWindowProc.pas"
   exit 2
}

# Case labels only: at most a few levels of indent, one or more WM_ names, then
# a colon that is not `:=`. Nested `case` statements on wParam do not produce
# WM_-prefixed labels, so filtering on the prefix is enough.
$handled = New-Object System.Collections.Specialized.OrderedDictionary
for ($i = $start; $i -lt $code.Count; $i++) {
   $m = [regex]::Match($code[$i], '^\s{0,6}((?:WM_\w+\s*,\s*)*WM_\w+)\s*:(?!=)')
   if (-not $m.Success) { continue }
   foreach ($name in ($m.Groups[1].Value -split '\s*,\s*')) {
      if (-not $handled.Contains($name)) { $handled.Add($name, $i + 1) }
   }
}

if ($handled.Count -eq 0) {
   Write-Output "Lint-AppMessages: found no case labels in WindowProc -- the parser is wrong, not the code."
   exit 2
}

# ------------------------------------------------------------- the allow-list

$formCode = (Get-PascalCodeOnlyLines -Path $formPath) -join "`n"

$fnStart = $formCode.IndexOf('function IsTR4WsOwnMessage')
if ($fnStart -lt 0) {
   Write-Output "Lint-AppMessages: could not find IsTR4WsOwnMessage in uMainForm.pas"
   exit 2
}
$fnBody = $formCode.Substring($fnStart)
$fnEnd = $fnBody.IndexOf('end;')
if ($fnEnd -ge 0) { $fnBody = $fnBody.Substring(0, $fnEnd) }

$claimed = @{}
foreach ($m in [regex]::Matches($fnBody, '\bWM_\w+\b')) {
   $claimed[$m.Value] = $true
}

# ---------------------------------------------------------------------- report

$missing = @()
foreach ($name in $handled.Keys) {
   if (-not $claimed.ContainsKey($name)) {
      $missing += [pscustomobject]@{ Name = $name; Line = $handled[$name] }
   }
}

if ($missing.Count -gt 0) {
   Write-Output ("Lint-AppMessages: {0} message(s) handled by WindowProc but NOT claimed by IsTR4WsOwnMessage." -f $missing.Count)
   Write-Output ''
   foreach ($m in $missing) {
      Write-Output ("  {0}" -f $m.Name)
      Write-Output ("     handled at uMainWindowProc.pas:{0}, and will NEVER be delivered:" -f $m.Line)
      Write-Output  "     TR4WFormSubclassProc chains it to the LCL, which does not know it."
      Write-Output  "     Add it to IsTR4WsOwnMessage in src\ui\lcl\uMainForm.pas -- BY ITS"
      Write-Output  "     CONSTANT, adding its unit to that unit's implementation uses clause."
      Write-Output ''
   }
   exit 1
}

Write-Output ("Lint-AppMessages: {0} message(s) handled by WindowProc, all claimed." -f $handled.Count)
exit 0
