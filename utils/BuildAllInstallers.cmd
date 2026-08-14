@echo off
REM RETIRED 2026-08-13. There is no all-languages build any more.
REM
REM This passed -AllLanguages -BuildInstallers to FullBuild.ps1, producing eight
REM per-language installers. TR4W now builds ONE English binary and is moving to
REM resourcestrings, so both switches are gone (the surviving one is singular:
REM -BuildInstaller).
REM
REM Kept as a signpost rather than deleted -- see BuildAll.cmd.
echo.
echo BuildAllInstallers.cmd is retired -- TR4W builds one English installer now.
echo.
echo   utils\BuildEnglishInstaller.cmd    build app + tr4wserver + installer
echo.
exit /b 1
