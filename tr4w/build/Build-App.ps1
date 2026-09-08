# Builds tr4w.lpr with FPC. The developer's inner loop; FullBuild.ps1 calls this
# for the release build too.
#
#   .\Build-App.ps1                 # full rebuild (-B), the safe default
#   .\Build-App.ps1 -Incremental    # seconds instead of minutes
#   .\Build-App.ps1 -Run            # then print the version banner
#
# INCREMENTAL IS FOR CHASING ONE DEFECT, not for believing a result. FPC's mtime
# rule cannot see a changed compiler switch, a changed .inc, or a define flip,
# and a stale incremental build has already cost this repo two sessions once (a
# phantom corpus crash that was nothing but out-of-date units). Full before you
# commit on it.

param(
   [switch]   $Incremental,
   [switch]   $Run,
   [string[]] $Defines = @(),
   # Where the linked binary goes. FullBuild overrides this to stage the release
   # build into target\ without disturbing the developer one.
   [string]   $OutExe = '',
   [string]   $Fpc = '',
   [string]   $Laz = '',
   [string]   $Cpu = 'i386',
   [string]   $Os  = 'win32'
)

$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'Find-Toolchain.ps1')
. (Join-Path $PSScriptRoot 'Get-SearchPaths.ps1')

$TR4W_DIR = Split-Path $PSScriptRoot -Parent
$REPO     = Split-Path $TR4W_DIR -Parent
$src      = Join-Path $TR4W_DIR 'src'

$tc = Find-Tr4wToolchain -Fpc $Fpc -Laz $Laz -Cpu $Cpu -Os $Os -Quiet
if (-not $tc) { exit 2 }

$out = Join-Path $REPO "build-out\app-$Cpu-$Os"
$exe = if ($OutExe -ne '') { $OutExe } else { Join-Path $out 'tr4w_fpc.exe' }

if (-not (Test-Path $out)) { New-Item -ItemType Directory -Path $out | Out-Null }

# -Sc  C-style operators.
# -WG  GUI subsystem. NOT cosmetic: the shipping binary has PE subsystem 2 and
#      FPC defaults to 3 (CONSOLE), so without it every launch pops a blank
#      console window beside the real one.
# -gl LINKS THE LINE-INFO UNIT, which is what turns a crash report from three
# raw addresses into file and line. Without it BackTraceStrFunc can only print
# $0040DC52, and the first real crash caught by uCrashLog (2026-08-15, an
# EAccessViolation on Ctrl-P) produced exactly that -- proof that the handler
# worked and that the addresses alone were not enough to act on.
#
# It costs exe size and nothing else: no slower code, no behaviour change. For a
# program whose users report crashes by email, a bigger binary that says WHERE is
# the right trade.
$fpcArgs = @("-Mdelphi", "-P$Cpu", "-T$Os", '-Sc', '-WG', '-gl', '-gw2', '-Xg', "-FU$out", "-o$exe")
if (-not $Incremental)
   {
   $fpcArgs += '-B'
   # -B alone is not a full rebuild: it cannot see a unit whose .ppu merely
   # LOOKS current, and a renamed file keeps its old mtime. See
   # Clear-Tr4wUnitOutput for the day that cost.
   $cleared = Clear-Tr4wUnitOutput -OutDir $out
   if ($cleared -gt 0) { Write-Host "  cleared $cleared stale artifact(s) from $out" }
   }
foreach ($d in $Defines) { $fpcArgs += "-d$d" }
foreach ($p in (Get-Tr4wSearchPaths -Tr4wDir $TR4W_DIR -Toolchain $tc -For App)) { $fpcArgs += "-Fu$p" }
foreach ($p in (Get-Tr4wIncludePaths -Tr4wDir $TR4W_DIR)) { $fpcArgs += "-Fi$p" }
$fpcArgs += 'tr4w.lpr'

# A DESIGNED FORM IS TWO FILES AND FPC ONLY WATCHES ONE. uPrefsForm.lfm is pulled
# in by {$R *.lfm} while uPrefsForm.pas compiles, so editing the LAYOUT leaves
# the .pas older than its unit file and an incremental build silently keeps the
# previous resource. Touching the .pas is the whole fix -- it uses exactly the
# mtime rule FPC already uses.
if ($Incremental)
   {
   foreach ($lfm in Get-ChildItem -Path $src -Recurse -Filter '*.lfm')
      {
      $pas = [System.IO.Path]::ChangeExtension($lfm.FullName, '.pas')
      if (Test-Path $pas)
         {
         $pasItem = Get-Item $pas
         if ($lfm.LastWriteTime -gt $pasItem.LastWriteTime)
            {
            $pasItem.LastWriteTime = $lfm.LastWriteTime
            Write-Host "  layout newer than code -- forcing recompile of $($pasItem.Name)"
            }
         }
      }
   }

Push-Location $TR4W_DIR
try
   {
   $output = & $tc.FpcExe @fpcArgs 2>&1
   $rc = $LASTEXITCODE
   }
finally
   {
   Pop-Location
   }

$errLines = $output | Select-String -Pattern '\bError:|\bFatal:'
$report = Join-Path $REPO 'build-out\app-build.log'
$output | Out-File -FilePath $report -Encoding utf8

# Name the build kind every run. An incremental result read as a full one is the
# exact mistake the switch makes easy, so it is never left to memory.
$kind = if ($Incremental) { 'INCREMENTAL (no -B)' } else { 'full (-B)' }
Write-Host "FPC application build -- $Cpu-$Os -- $kind"
Write-Host "errors+fatals : $($errLines.Count)"
Write-Host "full output   : $report"

if ($errLines.Count -gt 0)
   {
   Write-Host ''
   Write-Host '=== first 20 ==='
   $errLines | Select-Object -First 20 | ForEach-Object { Write-Host "  $($_.Line.Trim())" }
   }

# ---------------------------------------------------------------------------
# THE ALWAYS-FALSE RATCHET.
#
# "Comparison might be always false due to range of constant and expression" is
# the compiler telling us a branch is DEAD.  On 2026-08-22 it was saying so
# eleven times and the build passed anyway; five of those were real, silently
# broken features:
#
#   the log's column widths never saved   (HDN_ENDTRACKW)
#   FrmSetFocus never ran, twice          (NM_RELEASEDCAPTURE)
#   two file-dialog handlers never ran    (CDN_HELP, CDN_SELCHANGE)
#
# All five had the same cause: NMHDR.code is UNSIGNED as FPC's Windows unit
# declares it, while every NM_/HDN_/CDN_ constant is NEGATIVE.  Delphi declares
# that field signed, so this is a class of defect the FPC port INTRODUCED, and
# it fails silently in every case -- the feature simply never happens.
#
# A count, not a list, so the ratchet is one number to argue about.  Lower it
# whenever you fix one; raising it needs a reason in the commit message.
# WHETHER THE COUNTS BELOW MEAN ANYTHING.
#
# FPC emits a warning only for a unit it RECOMPILES.  An incremental build
# touches a handful of units, so a count taken from its output is a fraction of
# the tree's real total -- and a build that failed part way through is a
# fraction of even that.  Neither number can be compared against a ceiling.
#
# This was not theoretical.  $NARROW_CEILING had been ratcheted down to a value
# a full build could not meet, so `main` did not build; and an aborted build in
# the same session printed "1133 (ceiling 1427) -- down from 1427, lower it",
# which is a guard asking to be weakened on the strength of a failure.
#
# So: judge only a build that was FULL and that SUCCEEDED.  Anything else
# reports its count as indicative and neither fails nor invites a lower ceiling.
$countsAreComplete = (-not $Incremental) -and ($rc -eq 0)
$countsCaveat = if ($Incremental) { 'INCREMENTAL build -- only recompiled units are counted' }
                elseif ($rc -ne 0) { 'build FAILED -- units after the error were never compiled' }
                else { '' }

$WARN_CEILING = 6

$warnLines = $output | Select-String -Pattern 'Comparison might be always (false|true)'
Write-Host "range warnings: $($warnLines.Count) (ceiling $WARN_CEILING)"
if ($countsCaveat) { Write-Host "  NOT JUDGED: $countsCaveat" }

if ($countsAreComplete -and ($warnLines.Count -gt $WARN_CEILING))
   {
   Write-Host ''
   $warnLines | ForEach-Object { Write-Host "  $($_.Line.Trim())" }
   Write-Host ''
   Write-Host "BUILD FAILED: $($warnLines.Count) always-false/true comparisons, ceiling is $WARN_CEILING."
   Write-Host '  Each one is a branch the compiler can prove never runs, or always does.'
   Write-Host '  The usual cause here is an UNSIGNED field compared against a NEGATIVE'
   Write-Host '  constant -- NMHDR.code against NM_/HDN_/CDN_. Cast the field: Integer(x) = NM_FOO.'
   exit 1
   }

if ($countsAreComplete -and ($warnLines.Count -lt $WARN_CEILING))
   {
   Write-Host "  down from $WARN_CEILING -- lower `$WARN_CEILING in this script and commit it with the fix."
   }

# ---------------------------------------------------------------------------
# A SECOND RATCHET: STRING CONVERSIONS THAT CAN LOSE CHARACTERS.
#
# tr4w.inc makes `string` UnicodeString for all 426 units, while the TRDOS core
# still declares bounded ShortStrings (CallString, GridString, Str14...) and the
# LCL and the Win32 boundary speak AnsiString. Every assignment across that line
# is a conversion, and the compiler says which ones can lose something:
#
#   ...to "CallString"    -- TRUNCATION past the declared length
#   ...to "AnsiString"    -- the non-ASCII characters go through the ANSI
#                            codepage. That is the mojibake WinAnsi was
#                            written for in 9f388029, and 45dc430c in the log
#                            headers -- WinAnsi itself is gone (2026-09-07),
#                            because the Win32 '...A' calls it fed are gone
#                            too. LclText, for text going to the LCL, is what
#                            is left.
#
# NOT INVISIBLE -- the compiler warns on every one. But they sit inside 5,600
# warnings, and nobody reads 5,600 warnings, so in practice they are silent.
# NY4I asked whether the AnsiString event-signature trap was a general issue
# (2026-08-28); it is, and this is the size of it.
#
# COUNTED, NOT FIXED. Auditing 1,400 sites is its own piece of work -- it is
# already the "PChar -> PAnsiChar proactive audit" on the roadmap. What this
# stops is the number GROWING while that waits, which is the same bargain the
# Win32 baselines make.
#
# 1425 -> 1432 on 2026-08-29, for dialog 73 becoming a designed form. The whole
# +7 is net of two things: ten Caption assignments in uServerLogForm, and three
# returned by the uCAT prune. A converted form assigns its captions from the
# RC_/TC_ constants -- which is the POINT, an .lfm caption ships as English in
# every language -- and Caption is TTranslateString, an AnsiString because the
# LCL is compiled with 8-bit strings while tr4w.inc puts every unit of ours in
# UnicodeStrings. So each assignment narrows. There are 139 of these tree-wide
# and they all have that one cause; they will go together or not at all, and a
# form that avoided them would be a form whose text cannot be translated.
#
# RE-BASELINED 1427 -> 1462 ON 2026-09-05, AND THAT IS NOT A REGRESSION BEING
# WAVED THROUGH. 1427 was never a number a full build produced: measured on the
# committed tree, with none of this change present, a full build reports 1461.
# The ceiling had been ratcheted down against an INCREMENTAL build, which counts
# only the units it recompiled -- so `main` did not build at all, and had not
# for several commits. The guard above is the actual fix; this is the number it
# should have been holding.
#
# The +1 that this change adds is one Caption assignment in uMainGrids, and it
# is the same unavoidable narrowing as the other 139: the LCL is compiled with
# 8-bit strings, tr4w.inc puts our units in UnicodeStrings, and TCaption is an
# AnsiString. Every other new boundary in the change was typed as TCaption so
# the conversion happens once, at the control, instead of at each caller.
$NARROW_CEILING = 1456

$narrowLines = $output | Select-String -Pattern 'Implicit string type conversion with potential data loss'
Write-Host "narrowing string conversions: $($narrowLines.Count) (ceiling $NARROW_CEILING)"
if ($countsCaveat) { Write-Host "  NOT JUDGED: $countsCaveat" }

if ($countsAreComplete -and ($narrowLines.Count -gt $NARROW_CEILING))
   {
   Write-Host ''
   $narrowLines | Select-Object -First 15 | ForEach-Object { Write-Host "  $($_.Line.Trim())" }
   Write-Host ''
   Write-Host "BUILD FAILED: $($narrowLines.Count) narrowing conversions, ceiling is $NARROW_CEILING."
   Write-Host '  Each one can lose characters: to a bounded ShortString it TRUNCATES, to'
   Write-Host '  AnsiString it mangles anything outside the ANSI codepage. Convert'
   Write-Host '  explicitly at the boundary -- uAnsiStr.LclText for text going to the LCL,'
   Write-Host '  which is UTF-8 -- rather than letting the assignment do it silently.'
   exit 1
   }

if ($countsAreComplete -and ($narrowLines.Count -lt $NARROW_CEILING))
   {
   Write-Host "  down from $NARROW_CEILING -- lower `$NARROW_CEILING in this script and commit it with the fix."
   }

# State the outcome explicitly -- a filtered pipeline that matches nothing prints
# nothing, which reads as success.
if ($rc -ne 0)
   {
   Write-Host ''
   Write-Host "BUILD FAILED (exit $rc)"
   exit 1
   }

# THE BINARY NEEDS ITS DLLs BESIDE IT, AND THEY MUST MATCH ITS ARCHITECTURE.
#
# WHY THIS EXISTS.  build-out/app-<cpu>-<os>/ held only .o/.ppu files and the
# linked exe -- no DLLs.  Windows searches the EXE'S OWN DIRECTORY first, then
# system dirs, then the CURRENT directory, then PATH.  target/tr4w.exe sits
# beside its seven DLLs so it resolves them on the first step and is immune to
# the environment; the build-out binary resolved NOTHING there and fell through
# to PATH.
#
# That is not hypothetical.  A WSJT-X install puts C:/WSJT/wsjtx/bin on the
# MACHINE path -- present every boot, for every process, whether or not WSJT-X
# is running -- and it ships a 64-bit libhamlib-4.dll.  A 32-bit TR4W handed a
# 64-bit DLL dies in the LOADER with 0xC000007B (STATUS_INVALID_IMAGE_FORMAT).
#
# AND NOTHING IN TR4W CAN REPORT THAT.  libhamlib-4.dll is a STATIC import (37
# `external HAMLIB_DLL` declarations in uHamLibDirect.pas put it in the PE
# import table), so the loader resolves it before a single line of our code
# runs.  No log line, no message box, no crash handler -- tr4w.log and
# tr4w-early.log are both empty for this failure.  The check therefore has to
# happen HERE, at build time, because at run time it is already too late.
#
# ARCHITECTURE IS DERIVED FROM $Cpu, NEVER HARDCODED.  TR4W is moving to 64-bit,
# and at that point the mismatch INVERTS: the 32-bit DLLs become the wrong ones.
# A check written as "64-bit is bad" would then pass the broken case and fail
# the good one, which is worse than no check at all.
function Get-PEMachineType
   {
   param([Parameter(Mandatory = $true)][string] $Path)

   $fs = [IO.File]::OpenRead($Path)
   try
      {
      $br = New-Object IO.BinaryReader($fs)
      $fs.Position = 0x3C
      $peOffset = $br.ReadInt32()
      if ($peOffset -le 0 -or $peOffset -ge $fs.Length - 6) { return 0 }
      $fs.Position = $peOffset
      if ($br.ReadUInt32() -ne 0x00004550) { return 0 }    # the PE signature
      return [int] $br.ReadUInt16()
      }
   finally
      {
      $fs.Dispose()
      }
   }

$MACHINE_NAMES = @{ 0x014C = 'x86 (32-bit)'; 0x8664 = 'x64 (64-bit)'; 0x01C0 = 'ARM'; 0xAA64 = 'ARM64' }
$expectMachine = switch ($Cpu)
   {
   'i386'   { 0x014C }
   'x86_64' { 0x8664 }
   default  { 0 }
   }

$dllSource = Join-Path $TR4W_DIR 'target'
$exeDir    = Split-Path $exe -Parent
$staged    = 0
$badArch   = @()

$dlls = @()
if (Test-Path $dllSource) { $dlls = @(Get-ChildItem -Path $dllSource -Filter '*.dll' -File) }

# VALIDATE EVERY DLL BEFORE STAGING ANY OF THEM, and that order is the whole
# point rather than a tidiness preference. The first cut of this checked and
# copied in one pass, so a rejected DLL had ALREADY been written next to the
# binary by the time the build failed -- leaving build-out poisoned with the
# very file the guard had just refused, ready to fail the next launch with the
# 0xC000007B this exists to prevent. Measured 2026-09-05: the negative-control
# run did exactly that, and the next harness run inherited it.
foreach ($dll in $dlls)
   {
   if ($expectMachine -eq 0) { break }
   $m = Get-PEMachineType -Path $dll.FullName
   if ($m -ne 0 -and $m -ne $expectMachine)
      {
      $got  = if ($MACHINE_NAMES.ContainsKey($m))             { $MACHINE_NAMES[$m] }             else { "0x{0:X4}" -f $m }
      $want = if ($MACHINE_NAMES.ContainsKey($expectMachine)) { $MACHINE_NAMES[$expectMachine] } else { "0x{0:X4}" -f $expectMachine }
      $badArch += "  $($dll.Name) is $got, but this build targets $want"
      }
   }

if ($badArch.Count -gt 0)
   {
   Write-Host ''
   Write-Host 'BUILD FAILED: a shipped runtime DLL is the wrong architecture.'
   $badArch | ForEach-Object { Write-Host $_ }
   Write-Host ''
   Write-Host '  These are loaded by the Windows LOADER, before any TR4W code runs, so a'
   Write-Host '  mismatch is a bare 0xC000007B at launch with NOTHING written to tr4w.log.'
   Write-Host "  Replace the file(s) in $dllSource with builds for this target."
   Write-Host '  Nothing was staged -- the output directory is unchanged.'
   exit 1
   }

# Same directory means the binary already sits with its DLLs (FullBuild links
# straight into target). Nothing to stage.
if ($exeDir -ne $dllSource)
   {
   foreach ($dll in $dlls)
      {
      $dest = Join-Path $exeDir $dll.Name
      $need = -not (Test-Path $dest)
      if (-not $need)
         {
         $d = Get-Item $dest
         $need = ($d.Length -ne $dll.Length) -or ($d.LastWriteTimeUtc -lt $dll.LastWriteTimeUtc)
         }
      if ($need)
         {
         Copy-Item -LiteralPath $dll.FullName -Destination $dest -Force
         $staged++
         }
      }
   }

if ($staged -gt 0)
   {
   Write-Host "  staged $staged runtime DLL(s) beside $([IO.Path]::GetFileName($exe))"
   }

Write-Host ''
Write-Host "BUILD OK -> $exe"

if ($Run)
   {
   Write-Host ''
   & $exe /VERSION
   Write-Host "exit code = $LASTEXITCODE"
   }

exit 0
