@echo off
REM ---------------------------------------------------------------------------
REM Build-Server.cmd -- Build-Server.ps1 (tr4wserver) from a plain cmd prompt.
REM
REM Windows ships with PowerShell script execution disabled; -ExecutionPolicy
REM Bypass applies to THIS process only and needs no elevation.
REM
REM %~dp0 is THIS script's directory, so it works from any current directory.
REM Arguments are forwarded, e.g. -OutExe / -Fpc / -Laz.
REM
REM Exit code is the script's: 0 on success, 2 if no toolchain was found.
REM ---------------------------------------------------------------------------
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Build-Server.ps1" %*
exit /b %ERRORLEVEL%
