# Builds tr4w_unit_tests.dpr with FPC.
#
# This is the Gate B milestone that matters most: the unit-test EXE links the
# leaf src units and NOT the main window, so a green run is direct evidence that
# FPC-compiled TR4W computes the same ANSWERS -- 3892 tests under Delphi against
# 3892 under FPC -- rather than merely that the tree compiles.
#
# Mode defaults to `delphi` (8-bit string), NOT delphiunicode, because that is
# the invocation Gate A proved: the vendored Indy sets Delphi mode on itself but
# its conditionals follow FPC_UNICODESTRINGS, which a command-line
# -MdelphiUnicode sets and Indy's own mode reset does not clear.  Our units
# declare the modeswitch for themselves via src\tr4w.inc.
#
#   .\fpc-build-tests.ps1                  # 8-bit, i386-win32
#   .\fpc-build-tests.ps1 -Mode delphiunicode
#   .\fpc-build-tests.ps1 -Run             # build then run the tests

param(
   [string] $Mode = 'delphi',
   [string] $Cpu  = 'i386',
   [string] $Os   = 'win32',
   [string] $Fpc  = 'C:\FPC\3.2.2\bin\i386-win32\fpc.exe',
   [string] $Repo = 'C:\tr4w-d12',
   [switch] $Run
)

$src  = Join-Path $Repo 'tr4w\src'
$test = Join-Path $Repo 'tr4w\test\unit'
$out  = Join-Path $Repo "spike\units\tests-$Cpu-$Os-$Mode"
$exe  = Join-Path $out  'tr4w_unit_tests_fpc.exe'

if (-not (Test-Path $Fpc))
   {
   Write-Error "FPC not found at $Fpc"
   exit 1
   }

$fpcRoot = Split-Path (Split-Path (Split-Path $Fpc -Parent) -Parent) -Parent
$rtl = Join-Path $fpcRoot "units\$Cpu-$Os\rtl\system.ppu"
if (-not (Test-Path $rtl))
   {
   Write-Error "No RTL for $Cpu-$Os -- expected $rtl"
   exit 1
   }

if (-not (Test-Path $out))
   {
   New-Item -ItemType Directory -Path $out | Out-Null
   }

$searchPaths = @(
   $test
   $src
   Join-Path $src 'trdos'
   Join-Path $src 'utils'
   Join-Path $src 'lang'
   Join-Path $src 'radioFactory'
   Join-Path $src 'ui\fmx'
   # regexpr supplies TRegExpr, which uRegex.pas uses in place of TPerlRegEx --
   # the vendored PCRE library is twenty Borland-format .obj files and FPC's
   # linker cannot read them.
   Join-Path $fpcRoot "units\$Cpu-$Os\regexpr"
   # fcl-json supplies fpjson/jsonparser, which uJSON.pas shims onto the
   # System.JSON spellings the config stores are written against.
   Join-Path $fpcRoot "units\$Cpu-$Os\fcl-json"
   Join-Path $Repo 'tr4w\Include'
   Join-Path $Repo 'tr4w\include\Core'
   Join-Path $Repo 'tr4w\include\System'
   Join-Path $Repo 'tr4w\include\Protocols'
)

$fpcArgs = @("-M$Mode", "-P$Cpu", "-T$Os", '-Sc', '-B', "-FU$out", "-o$exe")
foreach ($p in $searchPaths)
   {
   $fpcArgs += "-Fu$p"
   }
$fpcArgs += 'tr4w_unit_tests.dpr'

Push-Location $test
try
   {
   $output = & $Fpc @fpcArgs 2>&1
   $rc = $LASTEXITCODE
   }
finally
   {
   Pop-Location
   }

$errLines = $output | Select-String -Pattern '\bError:|\bFatal:'
$report = Join-Path $Repo "spike\tests-build-$Mode.txt"
$output | Out-File -FilePath $report -Encoding utf8

Write-Host "FPC unit-test build -- $Cpu-$Os -M$Mode"
Write-Host "errors+fatals : $($errLines.Count)"
Write-Host "full output   : $report"

if ($errLines.Count -gt 0)
   {
   Write-Host ''
   Write-Host '=== first 20 ==='
   $errLines | Select-Object -First 20 | ForEach-Object { Write-Host "  $($_.Line.Trim())" }
   }

# State the outcome explicitly -- a filtered pipeline that matches nothing
# prints nothing, which reads as success.
if ($rc -ne 0)
   {
   Write-Host ''
   Write-Host "BUILD FAILED (exit $rc)"
   exit 1
   }

Write-Host ''
Write-Host "BUILD OK -> $exe"

if ($Run)
   {
   Write-Host ''
   & $exe
   Write-Host "test exit code = $LASTEXITCODE"
   }
