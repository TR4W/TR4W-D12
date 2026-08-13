# Builds tr4w.dpr -- the APPLICATION -- with FPC.
#
# Why this exists, given that FMX has no FPC equivalent: the golden-master
# corpus drives `tr4w.exe "<contest>.CFG" /EXPORT`, and that path boots the
# contest, writes ADIF and Cabrillo, and Halt(0)s.  It never creates a form.
# So an FPC build with the FMX units excluded can still be asked the one
# question that matters most -- does the CONTEST ENGINE compute the same bytes
# under FPC as under Delphi -- without waiting for the LCL port.
#
# The result is deliberately ENGINE-ONLY and is not shippable: the four
# settings dialogs and the two spike commands are absent (tr4w.dpr and
# MainUnit carry the {$IFNDEF FPC} guards).  Do not hand this binary to a user.
#
#   .\fpc-build-app.ps1              # build
#   .\fpc-build-app.ps1 -Run         # build, then print the version banner

param(
   [string] $Mode = 'delphi',
   [string] $Cpu  = 'i386',
   [string] $Os   = 'win32',
   [string] $Fpc  = 'C:\FPC\3.2.2\bin\i386-win32\fpc.exe',
   [string] $Repo = 'C:\tr4w-d12',
   [switch] $Run
)

$app = Join-Path $Repo 'tr4w'
$src = Join-Path $app  'src'
$out = Join-Path $Repo "spike\units\app-$Cpu-$Os-$Mode"
$exe = Join-Path $out  'tr4w_fpc.exe'

if (-not (Test-Path $Fpc))
   {
   Write-Error "FPC not found at $Fpc"
   exit 1
   }

$fpcRoot = Split-Path (Split-Path (Split-Path $Fpc -Parent) -Parent) -Parent

if (-not (Test-Path $out))
   {
   New-Item -ItemType Directory -Path $out | Out-Null
   }

$searchPaths = @(
   $src
   Join-Path $src 'trdos'
   Join-Path $src 'utils'
   Join-Path $src 'lang'
   Join-Path $src 'radioFactory'
   Join-Path $src 'rotatorFactory'
   Join-Path $fpcRoot "units\$Cpu-$Os\regexpr"
   Join-Path $fpcRoot "units\$Cpu-$Os\fcl-json"
   Join-Path $app 'Include'
   Join-Path $app 'include\Core'
   Join-Path $app 'include\System'
   Join-Path $app 'include\Protocols'
)

# -Sc for C-style operators, -B to rebuild everything: an incremental FPC build
# across a compiler port has already produced one phantom result in this repo's
# history, and the app build is under two minutes.
$fpcArgs = @("-M$Mode", "-P$Cpu", "-T$Os", '-Sc', '-B', "-FU$out", "-o$exe")
foreach ($p in $searchPaths)
   {
   $fpcArgs += "-Fu$p"
   }
$fpcArgs += 'tr4w.dpr'

Push-Location $app
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
$report = Join-Path $Repo "spike\app-build-$Mode.txt"
$output | Out-File -FilePath $report -Encoding utf8

Write-Host "FPC application build -- $Cpu-$Os -M$Mode"
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
   & $exe /VERSION
   Write-Host "exit code = $LASTEXITCODE"
   }
