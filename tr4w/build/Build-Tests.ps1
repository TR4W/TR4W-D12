# Builds the unit-test suite with FPC.
#
#   .\Build-Tests.ps1          # build
#   .\Build-Tests.ps1 -Run     # build, then run and report PASSED/FAILED
#   .\Build-Tests.ps1 -Checked -Run
#                              # the CHECKED build -- see below
#   .\Build-Tests.ps1 -Checked -Lines -Run
#                              # ...with source lines in heaptrc traces (SLOW)
#
# -Checked: THE SAME SUITE, COMPILED TO MAKE UNDEFINED BEHAVIOUR DETERMINISTIC.
#
#   -gt   trash local variables: every local is filled with a non-zero pattern on
#         entry, so a read of an uninitialised local (an unassigned managed
#         function result, say) is wrong EVERY run instead of right by luck.
#   -gh   heaptrc: every heap block is tracked; at exit it reports blocks that
#         were overwritten, freed twice, or freed with the wrong size, and
#         lists the ones never freed.
#
# -Lines adds -gw3 -gl so a heaptrc trace names a source line instead of an
# address. IT IS OFF BY DEFAULT BECAUSE heaptrc SYMBOLISES EVERY UNFREED BLOCK AT
# EXIT, and the suite leaves ~13,500 of them (see $LEAK_CEILING): measured
# 2026-10-14, plain -gl (stabs) did ~5 lines/s and was abandoned after 30
# minutes; -gw3 (DWARF) took ~9 minutes just for the leak dump; with neither
# the whole checked run is about 2 minutes. Use -Lines to DIAGNOSE a corruption
# report, not to gate on.
#
# HEAPTRC=keepreleased=1 IS NOT USED, deliberately: it never reuses a freed
# block, the suite allocates 1.08 GB cumulatively across 67 million blocks, and
# in a 32-bit process that runs out of address space (access violation partway
# through SettingsModel), while the FlexDiscovery heap-growth test fails because
# freed blocks stay resident. Both are artifacts, not defects.
#
# Why it exists: commit 0ec5d43d fixed an intermittent unit-test crash whose
# causes were an instance-sized FillChar over an old-style object with virtuals
# (it wiped the VMT pointer) and a managed function result that was never
# assigned. Both are invisible in a normal build and deterministic here.
#
# SEPARATE OUTPUT, SEPARATE BINARY, so it never races the normal build:
#   build-out\tests-checked-<cpu>-<os>\   and   test\unit\tr4w_unit_tests_checked.exe
# The search paths are NOT restated: they come from Get-SearchPaths.ps1, as for
# the normal build.
#
# WHAT FAILS THE RUN
#   - a failing test or a crash (non-zero exit), as in the normal run
#   - heaptrc CORRUPTION: any "Wrong size", "Wrong signature", "Marked memory
#     ... invalid", "freed again at", "Error in heap memory list", "error in
#     linked list" or "does not point to valid memory block" line
#   - the heaptrc summary ("Heap dump by heaptrc unit") ABSENT from the output.
#     That is a failure, not a pass: a checked run that did not check is the
#     guard that fails open.
#   - the unfreed-block count rising above $LEAK_CEILING below
# Leaks are a RATCHET, not a failure: the count is printed on every run and may
# only go down. When it drops, lower $LEAK_CEILING and commit it with the fix.
#
# -CR (object checks) IS DELIBERATELY LEFT OUT: it does not compile Log4D.pas
# (a "Class Of ILogAppender" is not a TClass, line ~1728), and Log4D is
# vendored, so the answer is not to edit it.
#
# THE EXE LANDS IN test\unit, NOT beside the unit files, and that is a
# requirement of the suite rather than a preference. Several suites locate their
# data relative to the BINARY:
#
#   uTestADIFFixtures : ExtractFilePath(ParamStr(0)) + 'fixtures\...'
#   uTestCTYDAT       : ExtractFilePath(ParamStr(0)) + '..\..\target\cty.dat'
#
# Both resolve only from tr4w\test\unit. Built anywhere else the result is 30
# red CTYDAT tests plus a bare RTE 217 in ADIFFixtures, and neither points at
# the real cause.

param(
   [switch] $Run,
   [switch] $Checked,
   [switch] $Lines,
   [string] $Fpc = '',
   [string] $Laz = '',
   [string] $Cpu = 'i386',
   [string] $Os  = 'win32'
)

$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'Find-Toolchain.ps1')
. (Join-Path $PSScriptRoot 'Get-SearchPaths.ps1')

$TR4W_DIR = Split-Path $PSScriptRoot -Parent
$REPO     = Split-Path $TR4W_DIR -Parent
$test     = Join-Path $TR4W_DIR 'test\unit'

$tc = Find-Tr4wToolchain -Fpc $Fpc -Laz $Laz -Cpu $Cpu -Os $Os -Quiet
if (-not $tc) { exit 2 }

# THE LEAK CEILING for -Checked: unfreed heap blocks at exit. Ratchets DOWN only.
# Measured 2026-10-14 (79,026 tests, 119 suites): 13,469, identical on two runs.
# -1 would mean "not yet measured" and is reported, never enforced.
$LEAK_CEILING = 13469

if ($Checked)
   {
   $out = Join-Path $REPO "build-out\tests-checked-$Cpu-$Os"
   $exe = Join-Path $test 'tr4w_unit_tests_checked.exe'
   $logName = 'tests-checked-build.log'
   }
else
   {
   $out = Join-Path $REPO "build-out\tests-$Cpu-$Os"
   $exe = Join-Path $test 'tr4w_unit_tests_fpc.exe'
   $logName = 'tests-build.log'
   }

if (-not (Test-Path $out)) { New-Item -ItemType Directory -Path $out | Out-Null }

# Always a full build here, so always clear first -- see Clear-Tr4wUnitOutput.
$cleared = Clear-Tr4wUnitOutput -OutDir $out
if ($cleared -gt 0) { Write-Host "  cleared $cleared stale artifact(s) from $out" }
$fpcArgs = @("-Mdelphi", "-P$Cpu", "-T$Os", '-Sc', '-B', "-FU$out", "-o$exe")
if ($Checked)
   {
   $fpcArgs += @('-gt', '-gh')
   if ($Lines)
      {
      $fpcArgs += @('-gw3', '-gl')
      }
   }
foreach ($p in (Get-Tr4wSearchPaths -Tr4wDir $TR4W_DIR -Toolchain $tc -For Tests -TestDir $test))
   {
   $fpcArgs += "-Fu$p"
   }
foreach ($p in (Get-Tr4wIncludePaths -Tr4wDir $TR4W_DIR)) { $fpcArgs += "-Fi$p" }
$fpcArgs += 'tr4w_unit_tests.lpr'

Push-Location $test
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
$report = Join-Path $REPO "build-out\$logName"
$output | Out-File -FilePath $report -Encoding utf8

$kind = if ($Checked) { ' (CHECKED: -gt -gh' + $(if ($Lines) { ' -gw3 -gl' } else { '' }) + ')' } else { '' }
Write-Host "FPC unit-test build -- $Cpu-$Os$kind"
Write-Host "errors+fatals : $($errLines.Count)"
Write-Host "full output   : $report"

if ($errLines.Count -gt 0)
   {
   Write-Host ''
   Write-Host '=== first 20 ==='
   $errLines | Select-Object -First 20 | ForEach-Object { Write-Host "  $($_.Line.Trim())" }
   }

if ($rc -ne 0)
   {
   Write-Host ''
   Write-Host "BUILD FAILED (exit $rc)"
   exit 1
   }

Write-Host ''
Write-Host "BUILD OK -> $exe"

# THE TEST EXE CANNOT START WITHOUT THESE, and the failure is silent.
#
# libhamlib-4.dll is a LOAD-TIME import of the test binary (the radio-factory
# suites link the HamLib IDs), so Windows resolves it before a single line of
# our code runs. The exe must live in test\unit -- several suites resolve their
# data from ParamStr(0) -- but the DLLs ship in target\, so nothing put them
# side by side and nothing ever noticed.
#
# It went unnoticed because the machine this was developed on has an unrelated
# HamLib checkout (C:\projects\hamlib\bin) on PATH, which satisfied the import
# by accident. Anywhere else -- a CI runner, a new contributor's PC -- the exe
# dies with STATUS_DLL_NOT_FOUND (exit -1073741515) before printing anything,
# so FullBuild reports "unit tests failed" with no failing test to look at.
# Found by building on a clean box, which is exactly what Test-FreshClone is
# for and exactly what it could not see while running here.
#
# sqlite3.dll is a DIFFERENT SHAPE of the same problem and is here for a
# different reason. It is NOT a load-time import -- FPC's binding resolves
# through LoadLibrary at run time (sqlite3.inc: Sqlite3Lib = 'sqlite3.dll') --
# so the exe starts fine without it and then the LogDatabase suite dies partway
# through with an unhandled exception, which reads like a broken test rather
# than a missing file. Copied for the same reason as the rest: the tests run
# from test\unit and the DLLs ship in target\.
$runtimeDlls = @(
   'libhamlib-4.dll',      # the load-time import itself
   'libgcc_s_dw2-1.dll',   # ...and what it needs in turn
   'libwinpthread-1.dll',
   'libusb-1.0.dll',
   'sqlite3.dll',          # the contest log; run-time bound, see above

   # THE OpenSSL PAIR IS HERE SO A TEST CAN REACH THE CASE AFTER IT LOADS.
   # uTestTLSRefusal pins that an HTTPS request whose verification cannot
   # be set up is REFUSED rather than sent unverified. Without these,
   # CheckScheme refuses one step earlier -- 'TLS unavailable' -- and the
   # test passes without ever running the code it exists for. cacert.pem is
   # deliberately NOT copied: a missing trusted-root bundle IS the fixture.
   'libeay32.dll',
   'ssleay32.dll'
)
$dllSrc = Join-Path $PSScriptRoot '..\target'
$dllDst = Split-Path $exe -Parent
foreach ($d in $runtimeDlls)
   {
   $src = Join-Path $dllSrc $d
   if (Test-Path -LiteralPath $src)
      {
      Copy-Item -LiteralPath $src -Destination $dllDst -Force
      }
   else
      {
      # Report rather than fail: only libhamlib-4.dll is strictly load-time, and
      # a tree without the others should say so rather than die here.
      Write-Host "  note: $d not found in target\ -- tests may not start" -ForegroundColor Yellow
      }
   }

if ($Run)
   {
   Push-Location $test
   try
      {
      # 2>&1: heaptrc writes its report to stderr. Under Stop, Windows
      # PowerShell turns the first stderr line of a native command into a
      # terminating error, so relax it for this one call.
      $ErrorActionPreference = 'Continue'
      $testOut = & $exe 2>&1
      $testRc  = $LASTEXITCODE
      }
   finally
      {
      $ErrorActionPreference = 'Stop'
      Pop-Location
      }

   $summary = $testOut | Select-String 'PASSED:' | Select-Object -Last 1
   if ($summary) { Write-Host "  $($summary.Line.Trim())" }

   $failed = $false

   if ($testRc -ne 0)
      {
      $testOut | Select-String '\[FAIL\]' | Select-Object -First 20 |
         ForEach-Object { Write-Host "  $($_.Line.Trim())" -ForegroundColor Red }
      Write-Host "  tests failed or crashed (exit $testRc)" -ForegroundColor Red
      $failed = $true
      }

   if ($Checked)
      {
      $checkedLog = Join-Path $REPO 'build-out\tests-checked-run.log'
      $testOut | ForEach-Object { "$_" } | Out-File -FilePath $checkedLog -Encoding utf8
      $text = ($testOut | ForEach-Object { "$_" }) -join "`n"

      # FAIL CLOSED: no heaptrc summary means the checked run did not check
      # (heaptrc not linked, output lost, process killed before exit).
      $unfreedMatch = [regex]::Match($text, '(?m)^\s*(\d+)\s+unfreed memory blocks\s*:')
      if ((-not $text.Contains('Heap dump by heaptrc unit')) -or (-not $unfreedMatch.Success))
         {
         Write-Host "  CHECKED RUN FAILED: no heaptrc summary in the output -- the run did not check anything." -ForegroundColor Red
         Write-Host "  full output: $checkedLog"
         $failed = $true
         }
      else
         {
         $unfreed = [int] $unfreedMatch.Groups[1].Value

         # CORRUPTION, as opposed to a leak. These are the strings heaptrc.pp
         # prints (checked against the 3.2.2 heaptrc.o).
         $corruptionPattern = 'Wrong size :|Wrong signature|Marked memory at .* invalid|freed again at|Error in heap memory list|error in linked list|does not point to valid memory block|points into invalid memory block|More memory blocks than expected'
         $corrupt = @($text -split "`n" | Where-Object { $_ -match $corruptionPattern })
         Write-Host "  heaptrc corruption reports: $($corrupt.Count)"
         if ($corrupt.Count -gt 0)
            {
            $corrupt | Select-Object -First 20 | ForEach-Object { Write-Host "    $($_.Trim())" -ForegroundColor Red }
            Write-Host "  CHECKED RUN FAILED: heap corruption. Full output: $checkedLog" -ForegroundColor Red
            $failed = $true
            }

         if ($LEAK_CEILING -lt 0)
            {
            Write-Host "  heaptrc unfreed blocks: $unfreed (ceiling NOT SET -- set `$LEAK_CEILING = $unfreed in this script)"
            }
         else
            {
            Write-Host "  heaptrc unfreed blocks: $unfreed (ceiling $LEAK_CEILING)"
            if ($unfreed -gt $LEAK_CEILING)
               {
               Write-Host "  CHECKED RUN FAILED: $unfreed unfreed blocks, ceiling is $LEAK_CEILING. Full output: $checkedLog" -ForegroundColor Red
               $failed = $true
               }
            elseif ($unfreed -lt $LEAK_CEILING)
               {
               Write-Host "  down from $LEAK_CEILING -- lower `$LEAK_CEILING in this script and commit it with the fix."
               }
            }
         }
      }

   if ($failed) { exit 1 }
   }

exit 0
