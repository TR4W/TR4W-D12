# Gates the build on every .lfm being streamable by the LCL.
#
# WHY A COMPILED CHECKER, when every other lint here is pure PowerShell.
#
# The question this asks -- "does this class publish this property, and is this
# a legal value for it" -- is answered correctly only by the RTTI the streaming
# loader itself consults.  A published property can be inherited through several
# ancestors, so grepping a class's own `published` block gives wrong answers in
# both directions.  So the checker is an FPC program that links the LCL and asks
# GetPropInfo / GetEnumValue, which makes it agree with the loader by
# construction rather than by care.  Source: build\lintlfm\lintlfm.lpr.
#
# WHAT IT CATCHES.  The FMX -> LCL port carries form resources between two
# component libraries whose properties only mostly overlap, and LCL streaming
# ABORTS AT THE FIRST BAD PROPERTY -- so a file with five defects costs five
# build-run-crash cycles, each one surfacing as a bare RTE 217 with no class and
# no message.  Worse, the IDE's "Fix LFM" dialog offers to REMOVE what it cannot
# resolve, which silently discards meaning (TRadioButton.GroupName is the live
# example: the LCL groups radio buttons by PARENT, so removing it fuses
# independent groups into one).
#
# FAILS CLOSED.  If FPC or the LCL units are missing this reports and exits
# non-zero rather than passing quietly -- a lint that cannot run must not look
# like a lint that found nothing.  Lint-RadioRegistry once reported
# "0 registrations, no collisions" and PASSED; that is the mistake being avoided.
#
#   powershell -File tr4w\build\Lint-LFMProperties.ps1 -SourceDir tr4w\src
#   powershell -File tr4w\build\Lint-LFMProperties.ps1 -SourceDir tr4w\src -Rebuild

param(
   # EMPTY means DISCOVER, via Find-Toolchain.ps1 -- the same discovery every
   # other script here uses.  These used to default to C:\FPC\3.2.2\... and
   # C:\Lazarus, which is the one hardcoded toolchain that survived the move to
   # Find-Toolchain, and it hid on any machine that happens to have those paths.
   # It was found by building on a clean box whose only Pascal install is the
   # 32-bit Lazarus, whose FPC lives at C:\lazarus\fpc\3.2.2: every other lint
   # passed, the app and the tests built, and this one lint failed -- so the
   # whole build failed on a machine that was correctly set up.
   [string] $SourceDir = (Join-Path $PSScriptRoot '..\src'),
   [string] $Fpc       = '',
   [string] $Laz       = '',
   [string] $Cpu       = 'i386',
   [string] $Os        = 'win32',
   [switch] $Rebuild
)

$ErrorActionPreference = 'Stop'

# Resolve before anything uses them.  A caller may still pin either one, and a
# pin is honoured exactly as Find-Toolchain honours FPC_HOME / LAZARUS_DIR.
if ((-not $Fpc) -or (-not $Laz))
   {
   . (Join-Path $PSScriptRoot 'Find-Toolchain.ps1')
   $tc = Find-Tr4wToolchain -Fpc $Fpc -Laz $Laz -Cpu $Cpu -Os $Os -Quiet
   if ($null -eq $tc)
      {
      Write-Host 'Lint-LFMProperties: no FPC + Lazarus able to target i386-win32.' -ForegroundColor Red
      Write-Host '  Find-Toolchain printed every path it tried. This lint needs FPC and the'
      Write-Host '  LCL to answer the question at all -- see the header.'
      exit 2
      }
   if (-not $Fpc) { $Fpc = $tc.FpcExe }
   if (-not $Laz) { $Laz = $tc.LazDir }
   }

$toolSrc = Join-Path $PSScriptRoot 'lintlfm\lintlfm.lpr'
$toolOut = Join-Path $PSScriptRoot 'lintlfm\units'
$toolExe = Join-Path $toolOut 'lintlfm.exe'

if (-not (Test-Path -LiteralPath $SourceDir))
   {
   Write-Host "Lint-LFMProperties: source directory not found: $SourceDir" -ForegroundColor Red
   exit 2
   }

$forms = @(Get-ChildItem -LiteralPath $SourceDir -Recurse -Filter '*.lfm' -File)

# A FLOOR, not just a pass/fail.  Zero .lfm files means the search moved or the
# port finished, and either way "checked nothing, all good" is a lie.
if ($forms.Count -eq 0)
   {
   Write-Host "Lint-LFMProperties: no .lfm files found under $SourceDir -- refusing to pass." -ForegroundColor Red
   Write-Host "  If the LCL forms moved, update this lint. If they are gone, delete it."
   exit 1
   }

# Rebuild when the source is newer than the binary, so an edit to the checker
# cannot be masked by a stale exe.
$needBuild = $Rebuild -or
             (-not (Test-Path -LiteralPath $toolExe)) -or
             ((Get-Item -LiteralPath $toolSrc).LastWriteTime -gt
              (Get-Item -LiteralPath $toolExe).LastWriteTime)

if ($needBuild)
   {
   if (-not (Test-Path -LiteralPath $Fpc))
      {
      Write-Host "Lint-LFMProperties: FPC not found at $Fpc" -ForegroundColor Red
      Write-Host "  This lint needs FPC + the LCL to answer the question at all -- see the header."
      exit 2
      }

   $lclUnits = Join-Path $Laz "lcl\units\$Cpu-$Os"
   if (-not (Test-Path -LiteralPath $lclUnits))
      {
      Write-Host "Lint-LFMProperties: no LCL units for $Cpu-$Os at $lclUnits" -ForegroundColor Red
      Write-Host "  C:\Lazarus carries i386 LCL units; an fpcupdeluxe x86_64-only install does not."
      exit 2
      }

   if (-not (Test-Path -LiteralPath $toolOut))
      {
      New-Item -ItemType Directory -Path $toolOut | Out-Null
      }

   $paths = @(
      $lclUnits
      Join-Path $lclUnits 'win32'
      Join-Path $Laz "components\lazutils\lib\$Cpu-$Os"
      Join-Path $Laz "packager\units\$Cpu-$Os"
   )

   $args = @("-M`delphi", "-P$Cpu", "-T$Os", '-B', "-FU$toolOut", "-o$toolExe")
   foreach ($p in $paths)
      {
      $args += "-Fu$p"
      }
   $args += $toolSrc

   Push-Location (Split-Path $toolSrc -Parent)
   try
      {
      $out = & $Fpc @args 2>&1
      $rc  = $LASTEXITCODE
      }
   finally
      {
      Pop-Location
      }

   if ($rc -ne 0)
      {
      Write-Host 'Lint-LFMProperties: the checker itself failed to build.' -ForegroundColor Red
      $out | Select-String 'Error:|Fatal:' | Select-Object -First 10 |
         ForEach-Object { Write-Host "  $($_.Line.Trim())" }
      exit 2
      }
   }

$result = & $toolExe @($forms.FullName) 2>&1
$rc = $LASTEXITCODE

$result | ForEach-Object { Write-Host $_ }

if ($rc -ne 0)
   {
   Write-Host ''
   Write-Host 'Lint-LFMProperties: the LCL cannot stream the above.' -ForegroundColor Red
   Write-Host 'Streaming aborts at the FIRST bad property, so expect more once these are fixed.'
   Write-Host 'Do NOT use the IDE''s "Fix LFM -> Remove all invalid properties" -- it discards'
   Write-Host 'meaning (TRadioButton.GroupName is grouping, not decoration).'
   exit 1
   }

exit 0
