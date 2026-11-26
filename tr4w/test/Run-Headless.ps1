# THE ONE WAY TO RUN TR4W BY HAND WITH NOBODY WATCHING IT.
#
# NY4I, 2026-11-26: a script ran /IMPORTLOG from Git Bash, which rewrote the
# switch into a path. TR4W started as for an operator, asked whether to download
# a country file, and waited all night.
#
# So this launcher always:
#   * runs from tr4w\target, where the tracked cty.dat is -- nothing is
#     downloaded, so a run does not depend on the network or on today's data;
#   * passes --unattended, so TR4W exits rather than ask a question;
#   * passes --settings pointing under build-out, never at the real settings;
#   * ends the process when the time limit runs out, and says so (exit 124).
#
# It starts the program itself, so no shell rewrites the arguments.
#
#   powershell -File tr4w\test\Run-Headless.ps1 /IMPORTLOG C:\logs\a.trw C:\logs\a.db
#
# FROM GIT BASH, prefix MSYS_NO_PATHCONV=1: bash rewrites a /switch before this
# script ever sees it.
#
# NOT FOR THE GUI HARNESS (tools\gui_test), which drives dialogs on purpose.

# PositionalBinding off: otherwise the first bare argument binds to -Exe.
[CmdletBinding(PositionalBinding = $false)]
param(
   [Parameter(Mandatory = $true, ValueFromRemainingArguments = $true)]
   [string[]]$Arguments,
   [string]$Exe,
   [string]$WorkingDirectory,
   [string]$Settings,
   [int]$TimeoutSeconds = 60
)

$ErrorActionPreference = 'Stop'

$tr4w = Split-Path -Parent $PSScriptRoot
$repo = Split-Path -Parent $tr4w
$target = Join-Path $tr4w 'target'

if (-not $Exe) {
   $Exe = Join-Path $target 'tr4w.exe'
   $built = Join-Path $repo 'build-out\app-x86_64-win64\tr4w_fpc.exe'
   if ((Test-Path $built) -and (Test-Path $Exe) -and
       ((Get-Item $built).LastWriteTime -gt (Get-Item $Exe).LastWriteTime)) {
      Write-Output "Run-Headless: REFUSING -- $Exe is older than $built. Copy it over first."
      exit 2
   }
}
if (-not (Test-Path $Exe)) {
   Write-Output "Run-Headless: no $Exe -- build the app first."
   exit 2
}
if (-not $WorkingDirectory) {
   $WorkingDirectory = $target
}
if (-not $Settings) {
   $folder = Join-Path $repo 'build-out\headless\settings'
   New-Item -ItemType Directory -Force $folder | Out-Null
   $Settings = Join-Path $folder 'tr4w.json'
}

$all = @($Arguments)
if ($all -notcontains '--settings') {
   $all += @('--settings', $Settings)
}
if ($all -notcontains '--unattended') {
   $all += '--unattended'
}
$quoted = $all | ForEach-Object { if ($_ -match '\s') { '"' + $_ + '"' } else { $_ } }

$process = Start-Process -FilePath $Exe -ArgumentList $quoted `
              -WorkingDirectory $WorkingDirectory -PassThru
# The handle must be taken while the process is alive, or ExitCode reads empty.
$null = $process.Handle

if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
   $process.Kill()
   $process.WaitForExit()
   Write-Output "Run-Headless: TIMED OUT after $TimeoutSeconds s; ended process $($process.Id)"
   exit 124
}

Write-Output "Run-Headless: exit $($process.ExitCode)"
exit $process.ExitCode
