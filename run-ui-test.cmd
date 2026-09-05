@echo off
REM ---------------------------------------------------------------------------
REM  Run one of the TR4W GUI-driving harnesses in tr4w\test\ui.
REM
REM    run-ui-test.cmd                              Test-Typing.ps1 (the default)
REM    run-ui-test.cmd -Text W1AW                   Test-Typing.ps1, other callsign
REM    run-ui-test.cmd Invoke-MenuSmoke.ps1         a named harness
REM    run-ui-test.cmd Invoke-MenuSmoke.ps1 -Command 10111
REM
REM  A first argument ending in .ps1 names the harness; everything else is
REM  passed through to it unchanged.
REM
REM  These harnesses LAUNCH AND CLOSE THE REAL PROGRAM.  Close TR4W first --
REM  the harness refuses to run against an instance it did not start, because
REM  it would drive the wrong one and read the wrong log.
REM ---------------------------------------------------------------------------
setlocal EnableDelayedExpansion

set "UIDIR=%~dp0tr4w\test\ui"
set "SCRIPT=Test-Typing.ps1"

set "FIRST=%~1"
if defined FIRST if /i "!FIRST:~-4!"==".ps1" (
   set "SCRIPT=%~1"
   shift
)

set "ARGS="
:collect
if "%~1"=="" goto :run
set "ARGS=!ARGS! %1"
shift
goto :collect

:run
if not exist "%UIDIR%\%SCRIPT%" (
   echo ERROR: no such harness: %UIDIR%\%SCRIPT%
   echo Available:
   dir /b "%UIDIR%\*.ps1"
   exit /b 1
)

echo Running %SCRIPT% %ARGS%
powershell -NoProfile -ExecutionPolicy Bypass -File "%UIDIR%\%SCRIPT%" %ARGS%
exit /b %ERRORLEVEL%
