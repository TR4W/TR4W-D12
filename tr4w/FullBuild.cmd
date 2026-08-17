@echo off
REM ---------------------------------------------------------------------------
REM FullBuild.cmd -- FullBuild.ps1 from a plain cmd prompt.
REM
REM Windows ships with PowerShell script execution disabled (ExecutionPolicy
REM Restricted), so the documented `.\tr4w\FullBuild.ps1` fails on a machine
REM nobody has prepared.  -ExecutionPolicy Bypass applies to THIS process only:
REM it changes no machine setting and needs no elevation.
REM
REM %~dp0 is THIS script's directory, so it works from any current directory.
REM Arguments are forwarded, e.g.
REM     tr4w\FullBuild.cmd -BuildInstaller
REM
REM This is the same thing utils\Build.cmd and utils\BuildEnglishInstaller.cmd
REM do; it lives here so the path in docs\BUILD.md substitutes one-for-one.
REM
REM Exit code is the script's, so a failing lint or test fails the cmd too.
REM ---------------------------------------------------------------------------
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0FullBuild.ps1" %*
exit /b %ERRORLEVEL%
