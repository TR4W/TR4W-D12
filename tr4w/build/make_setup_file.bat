@echo off
rem ---------------------------------------------------------------------------
rem Build the TR4W installer.
rem
rem This script used to run UPX and makensis directly:
rem
rem     upx.exe ..\target\tr4w.exe --lzma
rem     "D:\Program Files\NSIS\makensisw.exe" full.nsi
rem
rem That stopped working some time ago -- the NSIS path is a D: drive that does
rem not exist on current machines -- and, worse, it invoked full.nsi WITHOUT
rem /DTR4WVERSION, so it silently fell back to a hardcoded version string that
rem had drifted to 4.148.1 while src\Version.pas said 4.149.0.  full.nsi now
rem refuses to build without the define rather than mis-version an installer.
rem
rem FullBuild.ps1 is the single packaging path: it derives the version from
rem src\Version.pas, builds the app (and tr4wserver, which the installer
rem bundles), runs UPX when asked, and passes /DTR4WVERSION to NSIS.
rem
rem Kept as a thin shim because the repo's CLAUDE.md documents this filename as
rem the way to build an installer.
rem
rem   -UseUpx      compress with UPX --lzma, as the old script always did
rem   -AllLanguages  also build the 8 non-ENG installers
rem ---------------------------------------------------------------------------

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\FullBuild.ps1" -BuildInstallers -UseUpx %*
if errorlevel 1 (
    echo.
    echo === INSTALLER BUILD FAILED ===
)
pause
