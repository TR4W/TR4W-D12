@echo off
REM ---------------------------------------------------------------------------
REM Test-FreshClone.cmd -- Test-FreshClone.ps1 from a plain cmd prompt.
REM
REM Clones this repo to a temporary directory and builds it there, which is the
REM check that "clone and run one command" really works on this machine.
REM
REM Windows ships with PowerShell script execution disabled; -ExecutionPolicy
REM Bypass applies to THIS process only and needs no elevation.
REM
REM %~dp0 is THIS script's directory, so it works from any current directory.
REM Arguments are forwarded, e.g.
REM     tr4w\build\Test-FreshClone.cmd -WithInstaller
REM     tr4w\build\Test-FreshClone.cmd -Dest C:\temp\tr4w-clone -Keep
REM
REM Exit code is the script's, so a failed fresh clone fails the cmd too.
REM ---------------------------------------------------------------------------
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Test-FreshClone.ps1" %*
exit /b %ERRORLEVEL%
