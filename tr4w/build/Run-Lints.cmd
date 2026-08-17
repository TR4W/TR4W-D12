@echo off
REM ---------------------------------------------------------------------------
REM Run-Lints.cmd -- Run-Lints.ps1 from a plain cmd prompt.
REM
REM Windows ships with PowerShell script execution disabled; -ExecutionPolicy
REM Bypass applies to THIS process only and needs no elevation.
REM
REM %~dp0 is THIS script's directory, so it works from any current directory.
REM Arguments are forwarded, e.g. -SkipSlow / -Quiet.
REM
REM Exit code is the script's, so a failing lint fails the cmd too.
REM ---------------------------------------------------------------------------
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Run-Lints.ps1" %*
exit /b %ERRORLEVEL%
