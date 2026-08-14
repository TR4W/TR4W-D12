@echo off
REM RETIRED 2026-08-13. There is no all-languages build any more.
REM
REM This passed -AllLanguages to FullBuild.ps1, which compiled eight non-English
REM variants each with its own DCU cache. TR4W now builds ONE English binary and
REM is moving to resourcestrings for translation, so the switch no longer exists
REM and passing it is an error rather than a no-op.
REM
REM Kept as a signpost rather than deleted, because a cryptic "parameter cannot
REM be found" from muscle memory is a worse outcome than this message. Delete it
REM once nobody reaches for it.
echo.
echo BuildAll.cmd is retired -- TR4W builds one English binary now.
echo.
echo   utils\Build.cmd                    build app + tr4wserver
echo   utils\BuildEnglishInstaller.cmd    the above + the NSIS installer
echo.
exit /b 1
