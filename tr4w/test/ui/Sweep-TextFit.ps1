<#
.SYNOPSIS
   Open every converted window in every language and report the text that does
   not fit.

.DESCRIPTION
   THE PROBLEM THIS AUTOMATES. The layout was drawn for English. A translation
   is routinely 20-40% longer -- 'Cancel' is 'Cancelar', 'Foot switch' is
   'Przelacznik nozny' -- and the first anyone knows about it is a clipped
   caption in a screenshot. NY4I has been finding these by eye, one language and
   one window at a time, and reports German is among the worst.

   WHY IT MEASURES FROM INSIDE THE PROGRAM. Test-TextFit.ps1 walks the window
   tree from outside and reported NOTHING clipped in German -- a false negative,
   because a TLabel is a TGraphicControl with no window handle and most captions
   in the converted forms are labels. uTextFitAudit asks the same question from
   inside, where Screen.Forms reaches every form and Controls reaches every
   child, handle or not. This script drives that audit; it does not re-implement
   it.

   WHY IT OPENS WINDOWS. A form that has never been constructed has no controls
   to measure, so a one-shot walk at startup sees exactly one form. The audit
   installs a form-added handler, so every window opened while it runs is
   measured as it appears -- which is what Invoke-MenuSmoke is for here.

   WHY IT DEFUZZES FIRST. Make-LanguageRes drops fuzzy entries and the run time
   refuses them again, so against the shipping catalogues nearly every string is
   still English and there is nothing to overrun. po_defuzz --install writes a
   copy with the flags removed BESIDE THE EXE, where it wins over the embedded
   resource. That copy is for measurement only -- it is not a build, and the
   words in it are unreviewed machine output. Layout truth, not language truth.

   WHAT IT CANNOT SEE. Anything painted rather than placed: the main window's
   own elements, owner-drawn list items, grid cells. Those still need eyes.
   And it cannot tell you a translation is WRONG -- only that it does not fit.

.EXAMPLE
   .\Sweep-TextFit.ps1                      # every installed language
   .\Sweep-TextFit.ps1 -Lang de,pl          # just these two
   .\Sweep-TextFit.ps1 -SkipInstall         # catalogues already defuzzed
#>

param(
   # Language codes as they appear in i18n\tr4w_<code>.po. Empty means every
   # catalogue that has one.
   [string[]] $Lang = @(),
   [string]   $Repo = (Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent),
   [string]   $Exe,
   # Skip the po_defuzz step. Use when the languages are already installed and
   # you are re-running the measurement.
   [switch]   $SkipInstall,
   # Forwarded to Invoke-MenuSmoke. Its default set is the converted windows.
   [int[]]    $Command,
   [switch]   $Quiet
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$target = Join-Path $Repo 'tr4w\target'
if (-not $Exe) { $Exe = Join-Path $Repo 'build-out\app-i386-win32\tr4w_fpc.exe' }
if (-not (Test-Path $Exe)) { throw "no exe at $Exe -- build first" }

# THE CATALOGUE HAS TO SIT BESIDE THE BINARY WE ACTUALLY RUN.
# uEmbeddedTranslations resolves its path from ExtractFilePath(ParamStr(0)), so
# installing into tr4w\target while running the build-out binary would measure
# the EMBEDDED catalogue instead -- and that one has every fuzzy entry dropped,
# so almost nothing is translated and nothing overruns. A clean sweep for
# entirely the wrong reason.
$exeDir = Split-Path $Exe -Parent

$logPath = Join-Path $target 'tr4w.log'
$i18n    = Join-Path $Repo 'i18n'
$defuzz  = Join-Path $Repo 'tools\i18n\po_defuzz.py'

if (-not $Lang -or $Lang.Count -eq 0)
   {
   $Lang = Get-ChildItem (Join-Path $i18n 'tr4w_*.po') |
              ForEach-Object { $_.BaseName -replace '^tr4w_', '' } |
              Where-Object { $_ -ne 'en' } |
              Sort-Object
   }

# THE LOG IS THE CHANNEL, AND IT ROLLS.
#
# This read the log by byte offset -- remember the length before a language,
# read the tail afterwards. That silently loses findings, because tr4w.log is a
# TLogRollingFileAppender: at 10 MB it becomes tr4w.log.1 and a fresh tr4w.log
# starts. A sweep of twenty languages writes ~19 MB, so it WILL roll, and every
# language whose runs straddled the roll reported a handful of findings instead
# of its real count. Measured 2026-08-28: Danish 2 and Greek 0 against Finnish
# 34, all four of which have an empty catalogue and must therefore produce the
# SAME English baseline. The low numbers read like good news.
#
# So give each language its own logs instead of trying to slice a shared one.
# Nothing is running between languages, so moving the files aside is safe, and
# they are kept as evidence rather than deleted.
$logDir = Join-Path $Repo 'build-out\textfit-logs'
New-Item -ItemType Directory -Force $logDir | Out-Null

function Move-LogsAside
{
   param([string] $Name)
   $dest = Join-Path $logDir $Name
   New-Item -ItemType Directory -Force $dest | Out-Null
   Get-ChildItem (Join-Path $target 'tr4w.log*') -ErrorAction SilentlyContinue |
      ForEach-Object { Move-Item -LiteralPath $_.FullName -Destination (Join-Path $dest $_.Name) -Force }
   return $dest
}

function Read-RunLogs
{
   param([string] $Dir)
   $lines = @()
   # tr4w.log.1 first: it holds the OLDER half of a run that rolled.
   foreach ($f in @('tr4w.log.1', 'tr4w.log'))
      {
      $p = Join-Path $Dir $f
      if (Test-Path -LiteralPath $p) { $lines += (Get-Content -LiteralPath $p) }
      }
   return $lines
}

$results = @()
$coverage = @()

# Whatever was in target\ before the sweep belongs to the operator, not to us.
[void](Move-LogsAside '_before')

foreach ($code in $Lang)
   {
   $po = Join-Path $i18n ("tr4w_{0}.po" -f $code)
   if (-not (Test-Path $po))
      {
      Write-Host ("  {0,-6} SKIPPED -- no catalogue" -f $code)
      continue
      }

   if (-not $SkipInstall)
      {
      & python $defuzz $po --install --exe-dir $exeDir 2>&1 | Out-Null
      if ($LASTEXITCODE -ne 0) { throw "po_defuzz failed for $code" }
      }

   $smokeArgs = @{
      Repo       = $Repo
      Exe        = $Exe
      ExtraArgs  = @('--lang', $code, '--textfit')
      # The default 3s was not always enough for Preferences to appear -- about
      # a third of the languages measured ~290 captions instead of ~750 because
      # that one window never opened. More time is a mitigation, not the fix;
      # see the DISTRUST item in BENCH_QUEUE.md.
      AfterMs    = 6000
   }
   if ($Command) { $smokeArgs['Command'] = $Command }

   # KEEP THE RUNNER'S OWN OUTPUT. It went to Out-Null, which threw away the
   # only account of what the menu commands actually did -- so when Preferences
   # failed to open there was nothing left to say so.
   $smokeOut = Join-Path $logDir ('{0}-menusmoke.txt' -f $code)
   & (Join-Path $PSScriptRoot 'Invoke-MenuSmoke.ps1') @smokeArgs 2>&1 |
      Out-File -FilePath $smokeOut -Encoding utf8
   $smokeFailed = ($LASTEXITCODE -ne 0)

   $runDir = Move-LogsAside $code
   $lines = Read-RunLogs -Dir $runDir
   # 'TextFit: <form>.<control> needs Npx, has Npx -- "caption"'
   $hits = $lines | Where-Object { $_ -match 'TextFit: .*(needs \d+px|needing \d+px)' }

   $seen = @{}
   foreach ($h in $hits)
      {
      # A wrapped label overflows DOWNWARDS, and says so differently.
      if ($h -match 'TextFit: (\S+) wraps to (\d+) line\(s\) needing (\d+)px of height, has (\d+)px, slack (\d+)px -- "(.*)')
         {
         $key = '{0}|{1}' -f $matches[1], $matches[6]
         if (-not $seen.ContainsKey($key))
            {
            $seen[$key] = $true
            $results += [pscustomobject]@{
               Lang    = $code
               Control = $matches[1]
               Needs   = [int]$matches[3]
               Has     = [int]$matches[4]
               Over    = [int]$matches[3] - [int]$matches[4]
               Slack   = [int]$matches[5]
               Caption = ('[wraps to {0} lines] {1}' -f $matches[2], $matches[6])
            }
            }
         continue
         }
      # No '$' anchor: a caption may contain a line break (the function-key
      # messages do), so the log line does not end at the closing quote and an
      # anchored pattern drops exactly the findings most likely to be real.
      if ($h -match 'TextFit: (\S+) needs (\d+)px, has (\d+)px, slack (\d+)px -- "(.*)')
         {
         $key = '{0}|{1}' -f $matches[1], $matches[5]
         if ($seen.ContainsKey($key)) { continue }
         $seen[$key] = $true
         $results += [pscustomobject]@{
            Lang    = $code
            Control = $matches[1]
            Needs   = [int]$matches[2]
            Has     = [int]$matches[3]
            Over    = [int]$matches[2] - [int]$matches[3]
            Slack   = [int]$matches[4]
            Caption = $matches[5]
         }
         }
      }

   # HOW MUCH WAS LOOKED AT, printed beside what was found. A language that
   # measured 40 captions and found none is good news; one that measured 0 is a
   # broken run wearing the same number, and that is the mistake this harness
   # has already made twice.
   $measured = 0
   $forms = 0
   foreach ($l in $lines)
      {
      if ($l -match 'TextFit: \S* -- (\d+) caption\(s\) measured')
         {
         $forms++
         $measured += [int]$matches[1]
         }
      }

   $note = if ($smokeFailed) { '  (menu smoke reported a failure)' } else { '' }
   Write-Host ("  {0,-6} {1,4} of {2,4} caption(s) do not fit, across {3,3} form(s){4}" -f
               $code, $seen.Count, $measured, $forms, $note)
   if ($measured -eq 0)
      {
      Write-Host ("         NOTHING WAS MEASURED -- see {0}" -f $runDir)
      }
   $coverage += [pscustomobject]@{ Lang = $code; Measured = $measured; LogDir = $runDir }
   }

if (-not $Quiet)
   {
   Write-Host ''
   if ($results.Count -eq 0)
      {
      Write-Host 'Sweep-TextFit: nothing clipped in any language measured.'
      Write-Host 'That is only credible if the catalogues were defuzzed -- see the notes at the top.'
      }
   else
      {
      # A caption whose Over is <= 0 is not clipped: it is inside the audit's
      # 6px allowance for the border and padding a control draws inside itself.
      # Worth printing -- a translation one word longer will clip it -- but
      # calling it '-5px over' is nonsense, so say what it is.
      $results | Sort-Object -Property Over -Descending |
         ForEach-Object {
            $how = if ($_.Over -gt 0) { '{0,4}px over ' -f $_.Over }
                   else               { '        snug' }
            # THE VERDICT, not just the measurement. The auditor now reports how
            # much room the control has to grow before it hits its neighbour, so
            # a finding can say which KIND of work it needs instead of leaving a
            # reader to open the form and look:
            #
            #   WIDEN  the slack covers the shortfall -- a one-line .lfm change
            #   LAYOUT it does not -- something has to move, or the text has to
            #          get shorter. A reviewer shortening a verbose machine
            #          translation is a legitimate fix and costs nothing, since
            #          a fuzzy entry cannot ship until a human clears it.
            $fix = if ($_.Over -le 0)            { '     ' }
                   elseif ($_.Slack -ge $_.Over) { 'WIDEN' }
                   else                          { 'LAYOUT' }
            Write-Host ("  {0,-6} {1} {2,-6} slack {3,4}px  {4,-34} {5}" -f
                        $_.Lang, $how, $fix, $_.Slack, $_.Control, $_.Caption)
         }
      $clipped = @($results | Where-Object { $_.Over -gt 0 })
      $widen   = @($clipped | Where-Object { $_.Slack -ge $_.Over })
      $langs   = @($results | Select-Object -ExpandProperty Lang -Unique)
      Write-Host ''
      Write-Host ("Sweep-TextFit: {0} clipped and {1} snug caption(s) across {2} language(s)." -f
                  $clipped.Count, ($results.Count - $clipped.Count), $langs.Count)
      Write-Host ("  {0} can be fixed by WIDENING the control; {1} need LAYOUT work or shorter text." -f
                  $widen.Count, ($clipped.Count - $widen.Count))
      Write-Host 'Painted content is not measured -- see the notes at the top.'
      }
   }

# A FLOOR, because a language that measured almost nothing reports almost no
# findings and that reads like a pass.
#
# Every language walks the same windows, so the number of captions measured
# should barely vary between them. When it does, a window did not open --
# measured 2026-08-28: Finnish saw 280 captions to Danish's 747 because
# Preferences never appeared, and the menu-smoke runner did not object. The
# best run is the yardstick; anything under half of it is not a result.
if ($coverage.Count -gt 1)
   {
   $best = ($coverage | Measure-Object -Property Measured -Maximum).Maximum
   $thin = @($coverage | Where-Object { $_.Measured -lt ($best / 2) })
   if ($thin.Count -gt 0)
      {
      Write-Host ''
      Write-Host ("SUSPECT: {0} language(s) measured less than half of the best run ({1} captions)." -f
                  $thin.Count, $best)
      Write-Host 'A window did not open. Their finding counts are NOT a pass.'
      $thin | ForEach-Object {
         Write-Host ("  {0,-6} {1,4} captions   {2}" -f $_.Lang, $_.Measured, $_.LogDir)
      }
      }
   }

$results | Export-Csv -NoTypeInformation -Path (Join-Path $Repo 'build-out\textfit-sweep.csv')
Write-Host ('  full results: {0}' -f (Join-Path $Repo 'build-out\textfit-sweep.csv'))

exit ([int] ($results.Count -gt 0))
