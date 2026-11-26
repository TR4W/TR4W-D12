# THAT AN UNATTENDED RUN ENDS BY ITSELF -- against the built program, because
# only a running program can show that nothing waits (the command-line rules
# themselves are pinned in unit\uTestStartupArgs).
#
# Every case goes through Run-Headless.ps1, so a failure is a time-out (124) and
# never a hang.
#
# THE LOCK CASE SHOWS ONE DIALOG FOR A FEW SECONDS: it needs a second TR4W that
# holds the single-instance lock, and this script ends that one itself.
#
#   powershell -File tr4w\test\Test-Unattended.ps1

$ErrorActionPreference = 'Stop'

if (Get-Process tr4w* -ErrorAction SilentlyContinue) {
   Write-Output 'Test-Unattended: TR4W is running -- close it first.'
   exit 2
}

$tr4w = Split-Path -Parent $PSScriptRoot
$repo = Split-Path -Parent $tr4w
$target = Join-Path $tr4w 'target'
$launcher = Join-Path $PSScriptRoot 'Run-Headless.ps1'
$work = Join-Path $repo 'build-out\headless\test'
if (Test-Path $work) {
   Remove-Item -Recurse -Force $work -Confirm:$false
}
New-Item -ItemType Directory -Force $work | Out-Null

$trw = Join-Path $work 'sample.trw'
Copy-Item (Join-Path $PSScriptRoot 'unit\fixtures\binarylog\arrl_fd_2026_ny4i.trw') $trw
$notALog = Join-Path $work 'not-a-log.txt'
Set-Content -Path $notALog -Value 'this is not a contest log'

$script:failures = 0

function Test-Run {
   param([string]$Name, [int]$Expected, [string[]]$AppArguments, [string]$From)

   if (-not $From) {
      $From = $target
   }
   $output = & powershell -NoProfile -File $launcher -WorkingDirectory $From -TimeoutSeconds 45 @AppArguments
   $code = $LASTEXITCODE
   if ($code -eq $Expected) {
      Write-Output "  PASS  $Name (exit $code)"
   }
   else {
      Write-Output "  FAIL  $Name -- expected $Expected, got $code. $output"
      $script:failures++
   }
}

# The line that waited all night: the rewritten switch, from the repository root.
Test-Run 'a rewritten switch is refused' 5 `
   @('C:/Program Files/Git/IMPORTLOG', $trw, (Join-Path $work 'a.db')) $repo

Test-Run 'a file that is not a log does not wait' 5 @($notALog)

Test-Run '/IMPORTLOG still imports' 0 @('/IMPORTLOG', $trw, (Join-Path $work 'b.db'))

if (-not (Test-Path (Join-Path $work 'b.db'))) {
   Write-Output '  FAIL  /IMPORTLOG wrote no database'
   $script:failures++
}

# A second instance holding the lock: started as for an operator, on a file it
# will refuse with a message box, and left standing at that box.
$holderSettings = Join-Path $work 'holder.json'
$holder = Start-Process -FilePath (Join-Path $target 'tr4w.exe') -WorkingDirectory $target `
             -ArgumentList @("`"$notALog`"", '--settings', "`"$holderSettings`"") -PassThru
try {
   Start-Sleep -Seconds 5
   if ($holder.HasExited) {
      Write-Output '  FAIL  the lock holder exited, so the lock case proves nothing'
      $script:failures++
   }
   else {
      Test-Run '/IMPORTLOG beside another TR4W exits, with no warning box' 3 `
         @('/IMPORTLOG', $trw, (Join-Path $work 'c.db'))
   }
}
finally {
   if (-not $holder.HasExited) {
      $holder.Kill()
      $holder.WaitForExit()
   }
}

if ($script:failures -gt 0) {
   Write-Output "Test-Unattended: $($script:failures) FAILED"
   exit 1
}
Write-Output 'Test-Unattended: all passed'
exit 0
