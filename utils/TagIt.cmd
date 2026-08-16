:: TagIt.cmd -- the shim NY4I actually runs. Real work lives in TagIt.ps1:
:: verify the tag matches the COMMITTED Version.pas (the same guard release.yml
:: applies), then create and push the tag to the current branch's own upstream --
:: NOT origin/master, which in this clone is the Delphi 7 heritage repository.
::
:: BOTH SPELLINGS WORK, and that is the point of the parsing below. This used to
:: pass "-Tag %1" and nothing else, so calling it the way the tag is actually
:: written down --
::
::     TagIt.cmd -Tag v5.0.1
::
:: -- expanded to "-Tag -Tag v5.0.1" and PowerShell answered "Missing an argument
:: for parameter 'Tag'", which says nothing about the real problem. Accept the
:: bare form (the historical usage, TagIt.cmd 4.147.26) and the named form alike.
@echo off
setlocal

:: CAPTURE OUR OWN DIRECTORY BEFORE ANY shift. `shift` moves %0 too, so after it
:: %~dp0 is no longer this script's folder -- it becomes the directory of what
:: used to be %1. That turned the launch path into C:\tr4w-d12\TagIt.ps1 and
:: PowerShell reported a missing .ps1 rather than anything about arguments.
set "HERE=%~dp0"

if "%~1"=="" goto :usage

:: Strip a leading -Tag / --Tag / /Tag so both calling styles reach the same
:: place. Parenthesised deliberately: in batch, `if cond shift & goto :x` runs
:: the goto UNCONDITIONALLY -- `&` separates commands at the top level and is not
:: governed by the if.
set "ARG=%~1"
if /i "%ARG%"=="-Tag"  (shift)
if /i "%ARG%"=="--Tag" (shift)
if /i "%ARG%"=="/Tag"  (shift)

set "TAGVALUE=%~1"
if "%TAGVALUE%"=="" goto :usage

powershell -ExecutionPolicy Bypass -File "%HERE%TagIt.ps1" -Tag "%TAGVALUE%"
exit /b %ERRORLEVEL%

:usage
echo Usage: TagIt.cmd ^<version^>
echo    or: TagIt.cmd -Tag ^<version^>
echo.
echo Example: TagIt.cmd 5.0.1        (a leading "v" is accepted either way)
echo.
echo The version must match TR4W_CURRENTVERSION_NUMBER in the COMMITTED
echo tr4w\src\Version.pas, and the branch must already be pushed.
exit /b 1
