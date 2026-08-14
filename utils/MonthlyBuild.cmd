@echo off
REM ===========================================================================
REM  MonthlyBuild.cmd  --  full monthly TR4W release.
REM
REM  A thin wrapper around tr4w\build\Invoke-Release.ps1 so you don't have to
REM  remember the PowerShell syntax.  The monthly build is the SUPERSET of an
REM  interim tag: it refreshes CTY.DAT + TRMASTER.DTA + TRCLUSTER.DAT, bumps
REM  Version.pas (number + date), builds locally INCLUDING the installer,
REM  commits, pushes the current branch, and tags v<version> -- which triggers
REM  the CI installer build.
REM
REM  Usage:
REM     utils\MonthlyBuild.cmd 5.0.1                 full monthly release
REM     utils\MonthlyBuild.cmd 5.0.1 -DryRun         rehearse: do everything
REM                                                  locally but do NOT commit,
REM                                                  push, or tag
REM     utils\MonthlyBuild.cmd 5.0.1 -SkipCty -SkipTrmaster
REM                                                  no data refresh (the
REM                                                  interim subset, but via the
REM                                                  script with a local build)
REM
REM  For a plain interim CI tag (no data refresh, no rebuild), prefer
REM  utils\TagIt.cmd <version> instead.
REM
REM  PORTED TO FPC 2026-08-13.  The branch and remote are DERIVED from the
REM  current branch's upstream rather than hardcoded to 'master' / 'origin' --
REM  in this clone `origin` is the Delphi 7 heritage repo, so the old form would
REM  have released into the wrong project.  There is no '-all' tag and no
REM  -EnglishOnly switch: TR4W builds one English binary.
REM
REM  Works from any clone location and any current directory: Invoke-Release.ps1
REM  derives the repo root from its own path.
REM ===========================================================================
powershell.exe -ExecutionPolicy Bypass -File "%~dp0..\tr4w\build\Invoke-Release.ps1" %*
