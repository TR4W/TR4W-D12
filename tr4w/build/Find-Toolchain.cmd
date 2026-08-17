@echo off
REM ---------------------------------------------------------------------------
REM Find-Toolchain.cmd -- "what will the build actually use?", from a plain
REM cmd prompt.
REM
REM WHY THIS EXISTS.  Windows ships with PowerShell script execution disabled
REM (ExecutionPolicy Restricted), so the documented
REM
REM     . .\tr4w\build\Find-Toolchain.ps1 ; Find-Tr4wToolchain
REM
REM fails on a machine nobody has prepared -- which is precisely the machine you
REM are running this on.  -ExecutionPolicy Bypass applies to THIS process only:
REM it changes no machine setting and needs no elevation.
REM
REM WHY -Command AND NOT -File.  Find-Toolchain.ps1 is a LIBRARY.  Running it
REM does nothing at all -- it only defines Find-Tr4wToolchain.  So this wrapper
REM dot-sources it and calls the function, which is what the .ps1's own header
REM tells you to do.
REM
REM Arguments are forwarded to the function, e.g.
REM     tr4w\build\Find-Toolchain.cmd -Fpc C:\FPC\3.2.2 -Laz C:\Lazarus
REM
REM Those arguments are parsed by PowerShell, not by cmd, because of the
REM -Command above.  A path containing spaces therefore needs SINGLE quotes:
REM     tr4w\build\Find-Toolchain.cmd -Laz 'C:\Program Files\Lazarus'
REM The -File wrappers beside this one (Build-App.cmd and friends) take the
REM ordinary cmd double quotes instead.
REM
REM Exit code: 0 if a usable i386-win32 toolchain was found, 2 if not (the
REM function returns $null and has already printed every path it tried).
REM ---------------------------------------------------------------------------
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ". '%~dp0Find-Toolchain.ps1'; $tc = Find-Tr4wToolchain %*; if (-not $tc) { exit 2 }; $tc | Format-List; exit 0"
exit /b %ERRORLEVEL%
