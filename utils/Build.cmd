@echo off
REM Build TR4W (lints, unit tests, app, tr4wserver). No installer.
REM
REM Any arguments are forwarded to FullBuild.ps1, e.g.:
REM   utils\Build.cmd -BuildInstaller    also build the NSIS installer
REM   utils\Build.cmd -SkipTests         app only (prints a warning)
REM
REM %~dp0 is THIS script's directory, so it works from anywhere -- including
REM from utils\ itself, which is where it lives. The previous version passed a
REM bare relative 'tr4w\FullBuild.ps1' and only worked if the current directory
REM happened to be the repo root.
powershell.exe -ExecutionPolicy Bypass -File "%~dp0..\tr4w\FullBuild.ps1" %*
