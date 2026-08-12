# Compiles TR4W units with FPC 3.2.2 for the Lazarus/FPC portability spike.
#
# This is a MEASUREMENT harness, not a build: -Cn stops before linking, so it
# answers "does this unit and its dependency cone compile" and nothing else.
# Nothing it produces is linked into TR4W -- FPC .ppu/.o and Delphi .dcu are
# unrelated formats.  See docs/FPC_SPIKE_LOG.md.
#
#   .\fpc-compile.ps1 VC.pas
#   .\fpc-compile.ps1 radioFactory\uFactoryRadioBase.pas
#
# -Mdelphi gives an 8-bit `string`; -MdelphiUnicode matches Delphi 12's UTF-16.
# Which mode TR4W should target is still an open decision, so pass -Mode to try
# both against the same source.

param(
   [Parameter(Mandatory = $true)] [string] $Unit,
   [string] $Mode = 'delphi',
   [string] $Fpc  = 'C:\lazarus\fpc\3.2.2\bin\x86_64-win64\fpc.exe',
   [string] $Repo = 'C:\tr4w-d12'
)

$src = Join-Path $Repo 'tr4w\src'
$out = Join-Path $Repo 'spike\units'

$searchPaths = @(
   $src
   Join-Path $src 'trdos'
   Join-Path $src 'utils'
   Join-Path $src 'lang'
   Join-Path $src 'radioFactory'
   # The vendored Indy 10.6.3.3 -- the same directories tr4w.dproj lists in
   # DCC_UnitSearchPath.  It compiles unmodified; see the spike log, step 6.
   Join-Path $Repo 'tr4w\Include'
   Join-Path $Repo 'tr4w\include\Core'
   Join-Path $Repo 'tr4w\include\System'
   Join-Path $Repo 'tr4w\include\Protocols'
)

$args = @("-M$Mode", '-Sc', '-B', '-Cn', "-FU$out")
foreach ($p in $searchPaths)
   {
   $args += "-Fu$p"
   }
$args += $Unit

Push-Location $src
try
   {
   & $Fpc @args 2>&1 |
      Select-String -Pattern 'Error|Fatal|lines compiled' |
      Select-Object -First 25
   }
finally
   {
   Pop-Location
   }
