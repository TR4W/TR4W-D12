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
# ONE heaptrc REPORT IS EXCUSED, AND ONLY WHEN IT IS PROVEN FALSE (2026-10-14).
# heaptrc stores a live block's CRC-32 and the "released" marker $AAAAAAAA in
# the same header field and tests the marker first, so a live block whose CRC
# is $AAAAAAAA is reported "Marked memory ... released / freed again" the first
# time it is freed. The CRC covers only size, return addresses and tail, so
# the collision is FIXED PER BINARY and moves with any code change -- M10 S2
# hit it in SettingsFreshInstall, and -Lines (different addresses) did not.
# HeaptrcReport.ps1 recomputes the signature from what heaptrc printed and
# excuses the report only if it IS $AAAAAAAA; every other report still fails.
# The verifier checks itself against that very block before every use, and a
# failed self-check fails the run.
#
# AND THE RUN IS NOT ALLOWED TO HALT ON IT: HEAPTRC=nohalt is set for the
# checked run. With heaptrc's default haltonerror the false positive ended the
# run on the spot -- exit 1, the remaining suites never ran, and the unfreed
# count fell to whatever had leaked so far -- which is a gate that stops
# checking, not one that checks. A REAL error still fails it below, and
# heaptrc then exits 203, which is accepted only when every report it made
# was an excused collision and no test failed.
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
. (Join-Path $PSScriptRoot 'HeaptrcReport.ps1')   # the ReleaseSig collision check

$TR4W_DIR = Split-Path $PSScriptRoot -Parent
$REPO     = Split-Path $TR4W_DIR -Parent
$test     = Join-Path $TR4W_DIR 'test\unit'

$tc = Find-Tr4wToolchain -Fpc $Fpc -Laz $Laz -Cpu $Cpu -Os $Os -Quiet
if (-not $tc) { exit 2 }

# THE TEST BINARY LINKS THE SAME tr4w_languages.res THE APP DOES, and
# uTestUILanguage checks what it carries -- so it must be current here too, not
# only in Build-App.ps1. See build\LanguageResStamp.ps1.
. (Join-Path $PSScriptRoot 'LanguageResStamp.ps1')
try
   {
   Sync-Tr4wLanguageRes -Repo $REPO
   }
catch
   {
   Write-Host ''
   Write-Host "BUILD FAILED: $($_.Exception.Message)"
   exit 1
   }

# THE LEAK CEILING for -Checked: unfreed heap blocks at exit. Ratchets DOWN only.
# Measured 2026-10-14 (79,026 tests, 119 suites): 13,469, identical on two runs.
# -1 would mean "not yet measured" and is reported, never enforced.
$LEAK_CEILING = 13468

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
      $savedHeaptrc = $env:HEAPTRC
      if ($Checked)
         {
         # nohalt -- see the header: a heaptrc report must not end the run.
         $env:HEAPTRC = (('' + $savedHeaptrc) + ' nohalt').Trim()
         }
      $testOut = & $exe 2>&1
      $testRc  = $LASTEXITCODE
      }
   finally
      {
      $env:HEAPTRC = $savedHeaptrc
      $ErrorActionPreference = 'Stop'
      Pop-Location
      }

   $summary = $testOut | Select-String 'PASSED:' | Select-Object -Last 1
   if ($summary) { Write-Host "  $($summary.Line.Trim())" }

   $failed = $false

   # 203 IS heaptrc's "the heap had an error" exit, which it sets only when the
   # program would otherwise have exited 0 -- so every test passed. Whether
   # that error is real is decided by the corruption check below, not here.
   $heapExitOnly = $Checked -and ($testRc -eq 203) -and
                   ($null -ne $summary) -and ($summary.Line -match 'FAILED:\s*0\b')

   if (($testRc -ne 0) -and (-not $heapExitOnly))
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
         $allLines = @($text -split "`n" | ForEach-Object { $_.TrimEnd("`r") })

         # THE ReleaseSig COLLISION, PROVEN OR NOT EXCUSED. See the header and
         # HeaptrcReport.ps1. Fail closed if the verifier has drifted.
         $pointerSize = 4
         if ($Cpu -eq 'x86_64') { $pointerSize = 8 }
         $excused = @{}
         $collisions = 0
         $collisionKinds = @{}
         if (-not (Test-HeaptrcVerifier))
            {
            Write-Host "  CHECKED RUN FAILED: the heaptrc ReleaseSig verifier failed its own self-check -- HeaptrcReport.ps1 no longer matches heaptrc." -ForegroundColor Red
            $failed = $true
            }
         elseif ((('' + $env:HEAPTRC) -match 'tail_size') -or (('' + $savedHeaptrc) -match 'tail_size'))
            {
            # The verifier assumes heaptrc's default tail. Do not guess.
            Write-Host "  note: HEAPTRC sets tail_size -- no collision is excused this run" -ForegroundColor Yellow
            }
         else
            {
            for ($li = 0; $li -lt $allLines.Count; $li++)
               {
               if ($allLines[$li] -match '^\s*Marked memory at \$[0-9A-Fa-f]+ released')
                  {
                  $report = Read-HeaptrcReleasedReport -Lines $allLines -Index $li
                  if (Test-HeaptrcReleaseSigCollision -Report $report -PointerSize $pointerSize)
                     {
                     $excused[$report.FreedAgain] = $true
                     $collisions++
                     # One line per distinct allocation site: the same
                     # (size, stack) collides every time it is allocated.
                     $kind = "size $($report.Size), allocated from `$" +
                             ('{0:X8}' -f $report.Calls[0])
                     if ($collisionKinds.ContainsKey($kind))
                        {
                        $collisionKinds[$kind]++
                        }
                     else
                        {
                        $collisionKinds[$kind] = 1
                        }
                     }
                  }
               }
            foreach ($kind in $collisionKinds.Keys)
               {
               Write-Host ("  heaptrc ReleaseSig collision (NOT corruption), {0} report(s): {1} -- its CRC-32 signature is `$AAAAAAAA, heaptrc's 'released' marker" -f
                           $collisionKinds[$kind], $kind) -ForegroundColor Yellow
               }
            }

         $corrupt = @()
         for ($li = 0; $li -lt $allLines.Count; $li++)
            {
            if (($allLines[$li] -match $corruptionPattern) -and (-not $excused.ContainsKey($li)))
               {
               $corrupt += $allLines[$li]
               }
            }
         Write-Host "  heaptrc corruption reports: $($corrupt.Count)"

         # An error heaptrc counted that no pattern above names. 203 with
         # nothing recognised is not a pass.
         if ($heapExitOnly -and ($corrupt.Count -eq 0) -and ($collisions -eq 0))
            {
            Write-Host "  CHECKED RUN FAILED: heaptrc exited 203 (a heap error) and reported nothing this gate recognises. Full output: $checkedLog" -ForegroundColor Red
            $failed = $true
            }
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
