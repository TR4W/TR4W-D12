@echo off
REM ---------------------------------------------------------------------------
REM Build-App.cmd -- Build-App.ps1 from a plain cmd prompt.
REM
REM Windows ships with PowerShell script execution disabled, so the documented
REM `.\tr4w\build\Build-App.ps1` fails on an unprepared machine.
REM -ExecutionPolicy Bypass applies to THIS process only -- it changes no
REM machine setting and needs no elevation.
REM
REM %~dp0 is THIS script's directory, so it works from any current directory.
REM All arguments are forwarded, e.g.
REM     tr4w\build\Build-App.cmd -Incremental
REM     tr4w\build\Build-App.cmd -Run
REM
REM Exit code is the script's: 0 on success, 2 if no toolchain was found.
REM ---------------------------------------------------------------------------
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Build-App.ps1" %*
exit /b %ERRORLEVEL%
