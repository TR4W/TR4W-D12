@echo off
rem Machine-seed ONE new program string in every language, against LibreTranslate.
rem
rem   tools\i18n\seed_one.cmd                         the key below (SNetPushedToServerTotal)
rem   tools\i18n\seed_one.cmd uappstrings.somekey     another key
rem   tools\i18n\seed_one.cmd uappstrings.somekey -DryRun
rem
rem It runs seed_all.ps1 with -Only, so it fills only that EMPTY entry (never a
rem translated one), skips Mongolian and Serbian (the server has no model for
rem them), and logs to build-out\i18n-seed. Afterwards run
rem tr4w\build\Lint-PoSpecifiers.ps1 and read the Japanese and Korean drafts.

setlocal
set KEY=%~1
if "%KEY%"=="" set KEY=uappstrings.snetpushedtoservertotal
set EXTRA=%~2

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0seed_all.ps1" -Catalog tr4w -Only %KEY% %EXTRA%
exit /b %ERRORLEVEL%
