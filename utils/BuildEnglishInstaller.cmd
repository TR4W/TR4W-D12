@echo off
REM Build TR4W and its installer.
REM
REM %~dp0 is THIS script's directory, so it works from anywhere -- including
REM double-clicked, or run from utils\ itself, which is where it lives. The
REM previous version passed a bare relative 'tr4w\FullBuild.ps1' and only worked
REM if the current directory happened to be the repo root.
REM
REM The switch is -BuildInstaller (singular). It was -BuildInstallers while
REM TR4W built one installer per language; there is one English build now.
powershell.exe -ExecutionPolicy Bypass -File "%~dp0..\tr4w\FullBuild.ps1" -BuildInstaller %*
