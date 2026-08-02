param(
    # Match FullBuild.ps1's path resolution so the two scripts can be run
    # standalone OR chained together. Defaults are derived from the script
    # location and the same env vars FullBuild.ps1 uses.
    [string]$ProjectRoot = (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent),

    # RAD Studio 23.0 (Delphi 12 Athens) bin directory -- contains rsvars.bat,
    # which puts msbuild and the D12 compiler on PATH. Override with
    # $env:STUDIO_BIN or -StudioBin.
    [string]$StudioBin = $(if ($env:STUDIO_BIN) { $env:STUDIO_BIN } else { "C:\Program Files (x86)\Embarcadero\Studio\23.0\bin" }),

    # DEPRECATED and IGNORED. The server no longer needs Delphi 7 -- it builds
    # under D12 via msbuild like everything else. Kept only so existing callers
    # that still pass -Delphi7Bin / -IndyRoot (FullBuild.ps1 and
    # .github/workflows/release.yml) do not fail with "parameter cannot be found".
    [string]$Delphi7Bin = '',
    [string]$IndyRoot   = ''
)

$ErrorActionPreference = "Continue"

$TR4W_DIR   = Join-Path $ProjectRoot "tr4w"
$SERVER_DIR = Join-Path $TR4W_DIR "tr4wserver"
$DPROJ      = Join-Path $SERVER_DIR "tr4wserver.dproj"
$RSVARS     = Join-Path $StudioBin "rsvars.bat"
$EXE        = Join-Path $SERVER_DIR "tr4wserver.exe"

Write-Host "=== Building TR4W Server (Delphi 12) ===" -ForegroundColor Cyan
Write-Host "Project: $DPROJ" -ForegroundColor Yellow
Write-Host "Output:  $EXE" -ForegroundColor Yellow
Write-Host ""

if (-not (Test-Path $RSVARS)) {
    Write-Host "rsvars.bat not found at: $RSVARS (set STUDIO_BIN or pass -StudioBin)" -ForegroundColor Red
    exit 2
}
if (-not (Test-Path $DPROJ)) {
    Write-Host "tr4wserver.dproj not found at: $DPROJ" -ForegroundColor Red
    exit 2
}
if ($Delphi7Bin -ne '' -or $IndyRoot -ne '') {
    Write-Host "  NOTE: -Delphi7Bin / -IndyRoot are accepted but IGNORED; the server builds under D12." -ForegroundColor DarkGray
}

# Same recipe as FullBuild.ps1's Invoke-MSBuild and tr4w/docs/D12_BUILD.md:
# rsvars.bat is a batch file, so it must be `call`ed inside cmd.exe to put
# msbuild on PATH; the && chain means msbuild only runs if rsvars succeeded, and
# cmd /c yields the exit code of the last command it ran.
#
# /t:Build (not Make) so the server is genuinely recompiled rather than skipped
# by an up-to-date check.
$cmd = "call `"$RSVARS`" && cd /d `"$SERVER_DIR`" && msbuild `"$DPROJ`" /t:Build /p:Config=Debug /p:Platform=Win32 /v:minimal"
& cmd.exe /c $cmd
$result = $LASTEXITCODE

Write-Host ""
if ($result -eq 0) {
    Write-Host "=== BUILD SUCCESSFUL ===" -ForegroundColor Green
    if (Test-Path $EXE) {
        $exeInfo = Get-Item $EXE
        Write-Host "TR4WSERVER.EXE Details:" -ForegroundColor Cyan
        Write-Host "  Size:     $($exeInfo.Length) bytes" -ForegroundColor White
        Write-Host "  Modified: $($exeInfo.LastWriteTime)" -ForegroundColor White
    }
} else {
    Write-Host "=== BUILD FAILED ===" -ForegroundColor Red
    Write-Host "Exit code: $result" -ForegroundColor Red
}

exit $result
