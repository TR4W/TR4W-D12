# Runs every gating lint, once, from one place.
#
# WHY THIS EXISTS.  The lint list lived only in tr4w.dproj's PreBuildEvent, so
# it gated the DELPHI build and nothing else.  As FPC becomes the shipping
# toolchain that arrangement silently drops all of them: an FPC build would be
# green with a duplicate radio registration, an LF source file, an unwired form
# event or an unstreamable .lfm.  A gate that only one of two build paths runs
# is not a gate.
#
# So the list lives here and both paths call it.  Adding a lint means editing
# ONE array, not remembering a second place.
#
#   powershell -File tr4w\build\Run-Lints.ps1
#   powershell -File tr4w\build\Run-Lints.ps1 -SkipSlow    # omit the FPC-built ones
#
# Exit code is the number of lints that failed, so a caller can test -ne 0.
# Every lint runs even after one fails: seeing all the problems at once is the
# whole point of a batch, and a lint that only ever reports the first defect is
# the exact frustration this repo has already paid for once with .lfm streaming.

param(
   [string] $Tr4wDir  = (Join-Path $PSScriptRoot '..'),
   [switch] $SkipSlow,
   [switch] $Quiet
)

$ErrorActionPreference = 'Continue'

# RESOLVED, NOT JOINED.  The default $Tr4wDir is the literal string
# "<repo>/tr4w/build/.." -- a path with an unresolved ".." still in it.
# Split-Path is TEXTUAL, so `Split-Path -Parent` on that strips the last
# segment, which is the ".." itself, and hands back the BUILD folder instead
# of the repository root.
#
# That is not hypothetical: Lint-PathEscapes was invoked that way and so
# scanned 33 files in the build folder rather than the 1200 in the tree. It
# reported a clean pass while two corrupted paths sat in src -- the lint that
# exists precisely to catch backslash-t corruption could not see the source
# (found 2026-08-21).
#
# Forward slashes above on purpose: a Windows path written with backslashes
# in a comment is the very thing this lint fires on, and it fired on the
# first draft of this note.
$Tr4wDir = (Resolve-Path -LiteralPath $Tr4wDir).Path
$repoRoot = (Resolve-Path -LiteralPath (Join-Path $Tr4wDir '..')).Path

$src   = Join-Path $Tr4wDir 'src'
$build = $PSScriptRoot

# NeedsFpc marks the lints that compile a helper (see Lint-LFMProperties) and so
# cost seconds rather than milliseconds on a cold run.
$lints = @(
   @{ Name = 'Lint-RadioRegistry';   Arg = $src;     NeedsFpc = $false }
   @{ Name = 'Lint-PollRadioState';  Arg = $src;     NeedsFpc = $false }
   @{ Name = 'Lint-PCharAnsi';       Arg = $src;     NeedsFpc = $false }
   @{ Name = 'Lint-LineEndings';     Arg = $Tr4wDir; NeedsFpc = $false }
   # The BOM's sibling, and it took six silent losses in one session to earn its
   # place: line endings were gated, encoding was not. $Tr4wDir because tr4w.dpr
   # and the test .dpr files carry BOMs too and live outside src\.
   @{ Name = 'Lint-BOM';             Arg = $Tr4wDir; NeedsFpc = $false }
   @{ Name = 'Lint-FormTags';        Arg = $src;     NeedsFpc = $false }
   @{ Name = 'Lint-FormFields';      Arg = $src;     NeedsFpc = $false }
   @{ Name = 'Lint-FormOverlap';     Arg = $src;     NeedsFpc = $false }
   @{ Name = 'Lint-FormEvents';      Arg = $src;     NeedsFpc = $false }
   @{ Name = 'Lint-FormDefaults';    Arg = $src;     NeedsFpc = $false }
   @{ Name = 'Lint-ConfigOwnership'; Arg = $src;     NeedsFpc = $false }
   # Pins the Edit QSO form against the dialog template it was generated from.
   # $Tr4wDir because it needs res\ and test\ui\ as well as src\.
   @{ Name = 'Lint-EditQSOTemplate'; Arg = $Tr4wDir; NeedsFpc = $false }
   # The Win32-UI burn-down ratchet. $Tr4wDir, not $src: tr4w.dpr creates windows
   # too and lives one level up, and a ratchet that cannot see the program's own
   # entry point would let new Win32 UI in through the door it does not watch.
   @{ Name = 'Lint-Win32Dialogs';    Arg = $Tr4wDir; NeedsFpc = $false; Extra = @('-Group', 'ui') }
   # THE INI RULE, as a gate rather than a document. NY4I: "Only json should be
   # used except for the contest.cfg." That rule had drifted twice by 2026-08-21,
   # both times because checking it meant believing a document. It catches BOTH
   # spellings -- the Win32 profile API and TIniFile -- because an audit that
   # searched only for the first missed seven sites.
   @{ Name = 'Lint-IniUsage';        Arg = $Tr4wDir; NeedsFpc = $false }
   # A setting migration is THREE edits -- csJSON, RegisterStoredSetting, and
   # MIGRATED_COMMANDS -- and each omission fails differently and silently.
   # 153 settings still have to make that move; this is what keeps them honest.
   @{ Name = 'Lint-SettingsMigration'; Arg = $Tr4wDir; NeedsFpc = $false }
   # A Windows path written through a backslash-interpreting tool loses its
   # backslash-t to
   # a literal TAB: 'settings\tr4w.json' becomes 'settings<TAB>r4w.json'. It
   # compiles, it tests clean, and it is invisible in a diff -- it has landed in
   # this tree at least seven times, every one of them agent-written. $ProjectRoot
   # rather than $Tr4wDir because docs\ and the repo-root markdown get it too.
   @{ Name = 'Lint-DesignedForms';   Arg = $src;      NeedsFpc = $false }
   @{ Name = 'Lint-OneConfigWriter'; Arg = $src;      NeedsFpc = $false }
   @{ Name = 'Lint-PathEscapes';     Arg = $repoRoot; NeedsFpc = $false }
   # THE SAME RATCHET, SECOND GROUP -- phase 8, the Win32 the program speaks
   # OUTSIDE its windows: the ini API, serial, the registry, raw threads and
   # events, audio, LPT. Phase 7 does not touch any of it, and none of it
   # compiles on GTK or Cocoa. Separate baseline because it is a separate
   # phase: mixing the two would mean a dialog conversion and a serial
   # abstraction moving one number that neither could be read from.
   @{ Name = 'Lint-Win32Dialogs';    Arg = $Tr4wDir; NeedsFpc = $false; Extra = @('-Group', 'platform') }
   # Every message WindowProc handles must be claimed by IsTR4WsOwnMessage, or
   # the LCL swallows it. Four were being dropped when this was written, one of
   # them since the day the marshalling seam was built.
   @{ Name = 'Lint-AppMessages';     Arg = $src;     NeedsFpc = $false }
   @{ Name = 'Lint-LFMProperties';   Arg = $src;     NeedsFpc = $true  }
)

$failed  = 0
$ran     = 0
$skipped = 0

# ---------------------------------------------------------------------------
# LAUNCH ALL, THEN COLLECT -- the lints run CONCURRENTLY.
#
# Measured before changing anything: the ten lints do about 5 seconds of work
# between them, and Run-Lints took 47. The difference is process startup --
# powershell.exe costs roughly four seconds to start and this spawned one per
# lint, serially. So 42 of those 47 seconds were Windows loading PowerShell ten
# times, not any lint reading any file.
#
# Each lint still gets its OWN process, which is not incidental: several call
# exit to report a failure, and exit inside a dot-sourced or call-operator script
# terminates the caller. Isolation is why they were spawned in the first place;
# only the serialisation was accidental.
#
# NOTHING IS SKIPPED to achieve this. Every lint still reads every file it read
# before -- NY4I: "I will never change testing for speed".
# ---------------------------------------------------------------------------
$queue  = New-Object System.Collections.ArrayList
$tmpDir = Join-Path ([IO.Path]::GetTempPath()) ("tr4w-lints-" + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tmpDir -Force | Out-Null

foreach ($lint in $lints)
   {
   $path = Join-Path $build "$($lint.Name).ps1"

   # A MISSING LINT IS A FAILURE, not a skip.  A renamed or deleted script that
   # quietly stopped running is indistinguishable from a clean tree otherwise.
   if (-not (Test-Path -LiteralPath $path))
      {
      Write-Host "$($lint.Name): SCRIPT NOT FOUND at $path" -ForegroundColor Red
      $failed++
      continue
      }

   if ($SkipSlow -and $lint.NeedsFpc)
      {
      Write-Host "$($lint.Name): skipped (-SkipSlow)" -ForegroundColor DarkGray
      $skipped++
      continue
      }

   # LAUNCHED, NOT AWAITED. See the note above the loop.
   $outFile = Join-Path $tmpDir ("lint-$($queue.Count)-out.txt")
   $errFile = Join-Path $tmpDir ("lint-$($queue.Count)-err.txt")
   $proc = Start-Process -FilePath 'powershell' `
                         -ArgumentList (@('-NoProfile', '-ExecutionPolicy', 'Bypass',
                                          '-File', $path, '-SourceDir', $lint.Arg) +
                                        # Optional per-entry switches, so one script can be
                                        # listed twice with different arguments rather than
                                        # being copied into a sibling that would drift.
                                        $(if ($lint.ContainsKey('Extra')) { $lint.Extra } else { @() })) `
                         -NoNewWindow -PassThru `
                         -RedirectStandardOutput $outFile `
                         -RedirectStandardError  $errFile

   # TOUCH .Handle, or ExitCode reads back EMPTY.
   #
   # Windows PowerShell 5.1 releases the process handle once the child exits,
   # and $proc.ExitCode is then $null -- so every lint reported
   # "FAILED (exit )" while its own output said it passed. Reading .Handle here
   # caches it and keeps ExitCode readable after WaitForExit.
   #
   # It reproduces only under 5.1. The first verification of this runner ran
   # under pwsh 7, where it works, while FullBuild spawns powershell.exe -- so a
   # green lint check and a build that could not pass its own lints coexisted.
   $null = $proc.Handle

   $queue.Add([pscustomobject]@{
      Name    = $lint.Name
      Proc    = $proc
      OutFile = $outFile
      ErrFile = $errFile
   }) | Out-Null
   }

# ---------------------------------------------------------------------------
# Collect, IN THE ORDER THEY WERE LAUNCHED. Parallel execution must not mean
# interleaved output: a lint report that changes order between runs cannot be
# diffed, and the eye stops trusting it.
# ---------------------------------------------------------------------------
foreach ($job in $queue)
   {
   $job.Proc.WaitForExit()
   $rc  = $job.Proc.ExitCode
   $ran++

   $out = @()
   foreach ($f in @($job.OutFile, $job.ErrFile))
      {
      if (Test-Path -LiteralPath $f)
         {
         $out += (Get-Content -LiteralPath $f -ErrorAction SilentlyContinue)
         }
      }
   $out = $out | Where-Object { $_ -ne $null -and $_.Trim() -ne '' }

   if ($rc -ne 0)
      {
      $failed++
      Write-Host ''
      Write-Host "=== $($job.Name) FAILED (exit $rc) ===" -ForegroundColor Red
      $out | ForEach-Object { Write-Host "  $_" }
      }
   elseif (-not $Quiet)
      {
      $out | ForEach-Object { Write-Host "  $_" }
      }
   }

Remove-Item -LiteralPath $tmpDir -Recurse -Force -ErrorAction SilentlyContinue

Write-Host ''
if ($failed -eq 0)
   {
   Write-Host "Run-Lints: $ran lint(s) passed$(if ($skipped) { ", $skipped skipped" })." -ForegroundColor Green
   }
else
   {
   Write-Host "Run-Lints: $failed of $($ran + $failed) lint(s) FAILED." -ForegroundColor Red
   }

exit $failed
