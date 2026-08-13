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
# NY4I chose delphiunicode; -Mode remains so the two can be compared on the
# same source.
#
# TARGET: i386-win32 by default, NOT the host's x86_64.  The golden-master
# corpus byte-diffs binary logs whose record layout depends on pointer width
# and the pinned -$A8 alignment, so a 64-bit build cannot run that gate.
#
# COMPILER: c:\FPC is a NATIVE i386 install -- ppc386.exe is itself a 32-bit
# binary under WOW64, exactly like Delphi's own DCC32.EXE.  Nothing is
# cross-compiled.
#
# This is not a preference either.  Win64 -> i386 cross-compilation is
# REFUSED by FPC: on x86_64-win64 `Extended` is only 64-bit, and folding
# i386's 80-bit float constants at 64-bit precision would silently change
# results, so the build stops at fpcdefs.inc:288.  Both x86_64 installs on
# this machine (c:\lazarus, c:\fpcupdeluxe) are therefore unusable for our
# target.  Pinned absolutely rather than resolved through PATH, because
# picking the wrong tree fails as a confusing .ppu or unit-not-found error
# that never names the real cause.

param(
   [Parameter(Mandatory = $true)] [string] $Unit,
   [string] $Mode = 'delphiunicode',
   [string] $Cpu  = 'i386',
   [string] $Os   = 'win32',
   [string] $Fpc  = 'C:\FPC\3.2.2\bin\i386-win32\fpc.exe',
   [string] $Repo = 'C:\tr4w-d12'
)

$src = Join-Path $Repo 'tr4w\src'

# One output directory per target AND mode.  FPC will happily read a .ppu built
# for another CPU or string model out of a shared directory and fail somewhere
# far from the cause.
$out = Join-Path $Repo "spike\units\$Cpu-$Os-$Mode"

$searchPaths = @(
   $src
   Join-Path $src 'trdos'
   Join-Path $src 'utils'
   Join-Path $src 'lang'
   Join-Path $src 'radioFactory'
   # The vendored Indy 10.6.3.3 -- the same directories tr4w.dproj lists in
   # DCC_UnitSearchPath.  It compiles unmodified under -Mdelphi but NOT under
   # -MdelphiUnicode: Indy's own FPC branch is not UnicodeString-enabled.
   # See the spike log, steps 6 and 9.
   Join-Path $Repo 'tr4w\Include'
   Join-Path $Repo 'tr4w\include\Core'
   Join-Path $Repo 'tr4w\include\System'
   Join-Path $Repo 'tr4w\include\Protocols'
)

# Fail loudly on a missing toolchain rather than emitting a diagnostic that
# blames the source.  The UNITS are the real evidence a target is usable: the
# cross compiler binary alone cannot compile anything without an RTL.
if (-not (Test-Path $Fpc))
   {
   Write-Error "FPC not found at $Fpc"
   exit 1
   }

# fpc.exe lives at <root>\bin\<hostcpu>\fpc.exe, so the install root is three
# levels up, not two.
$fpcRoot = Split-Path (Split-Path (Split-Path $Fpc -Parent) -Parent) -Parent
$rtl = Join-Path $fpcRoot "units\$Cpu-$Os\rtl\system.ppu"
if (-not (Test-Path $rtl))
   {
   Write-Error @"
No RTL for $Cpu-$Os -- expected $rtl
This target is not installed.  Add it from the fpcupdeluxe cross-compile
selectors (CPU=$Cpu, OS=$Os), which also fetches the $Cpu-$Os binutils.
"@
   exit 1
   }

if (-not (Test-Path $out))
   {
   New-Item -ItemType Directory -Path $out | Out-Null
   }

$args = @("-M$Mode", "-P$Cpu", "-T$Os", '-Sc', '-B', '-Cn', "-FU$out")
foreach ($p in $searchPaths)
   {
   $args += "-Fu$p"
   }
$args += $Unit

Push-Location $src
try
   {
   $output = & $Fpc @args 2>&1
   $rc = $LASTEXITCODE

   $output |
      Select-String -Pattern 'Error|Fatal|lines compiled' |
      Select-Object -First 25

   # A filtered pipeline that matches nothing prints nothing, which reads as
   # success.  Always state the outcome.
   if ($rc -ne 0)
      {
      Write-Host "FAILED (exit $rc) -- $Unit for $Cpu-$Os -M$Mode"
      }
   }
finally
   {
   Pop-Location
   }
