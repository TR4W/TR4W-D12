@echo off
REM ---------------------------------------------------------------------------
REM Build-Tests.cmd -- Build-Tests.ps1 from a plain cmd prompt.
REM
REM Windows ships with PowerShell script execution disabled; -ExecutionPolicy
REM Bypass applies to THIS process only and needs no elevation.
REM
REM %~dp0 is THIS script's directory, so it works from any current directory.
REM Pass -Run to execute the suite after building it -- that is the usual form:
REM     tr4w\build\Build-Tests.cmd -Run
REM
REM Exit code is the script's, so a failing test fails the cmd too.
REM ---------------------------------------------------------------------------
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Build-Tests.ps1" %*
exit /b %ERRORLEVEL%
