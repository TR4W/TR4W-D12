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

# THE LOG IS THE CHANNEL, so read only what each run appends to it. Truncating
# it instead would throw away whatever the operator was looking at, and the
# audit is not the only thing writing here.
function Get-LogLength
{
   if (Test-Path $logPath) { return (Get-Item $logPath).Length }
   return 0
}

function Read-LogSince
{
   param([long] $Offset)
   if (-not (Test-Path $logPath)) { return @() }
   $fs = [IO.File]::Open($logPath, 'Open', 'Read', 'ReadWrite')
   try
      {
      if ($Offset -gt $fs.Length) { $Offset = 0 }   # log rolled under us
      [void]$fs.Seek($Offset, 'Begin')
      $sr = New-Object IO.StreamReader($fs)
      return $sr.ReadToEnd() -split "`r?`n"
      }
   finally { $fs.Dispose() }
}

$results = @()

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

   $before = Get-LogLength
   $smokeArgs = @{
      Repo       = $Repo
      Exe        = $Exe
      ExtraArgs  = @('--lang', $code, '--textfit')
   }
   if ($Command) { $smokeArgs['Command'] = $Command }

   & (Join-Path $PSScriptRoot 'Invoke-MenuSmoke.ps1') @smokeArgs 2>&1 | Out-Null
   $smokeFailed = ($LASTEXITCODE -ne 0)

   $lines = Read-LogSince -Offset $before
   # 'TextFit: <form>.<control> needs Npx, has Npx -- "caption"'
   $hits = $lines | Where-Object { $_ -match 'TextFit: .*needs \d+px' }

   $seen = @{}
   foreach ($h in $hits)
      {
      if ($h -match 'TextFit: (\S+) needs (\d+)px, has (\d+)px -- "(.*)"$')
         {
         $key = '{0}|{1}' -f $matches[1], $matches[4]
         if ($seen.ContainsKey($key)) { continue }
         $seen[$key] = $true
         $results += [pscustomobject]@{
            Lang    = $code
            Control = $matches[1]
            Needs   = [int]$matches[2]
            Has     = [int]$matches[3]
            Over    = [int]$matches[2] - [int]$matches[3]
            Caption = $matches[4]
         }
         }
      }

   $note = if ($smokeFailed) { '  (menu smoke reported a failure)' } else { '' }
   Write-Host ("  {0,-6} {1,4} caption(s) do not fit{2}" -f $code, $seen.Count, $note)
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
            Write-Host ("  {0,-6} {1}  {2,-34} {3}" -f
                        $_.Lang, $how, $_.Control, $_.Caption)
         }
      $clipped = @($results | Where-Object { $_.Over -gt 0 })
      $langs   = @($results | Select-Object -ExpandProperty Lang -Unique)
      Write-Host ''
      Write-Host ("Sweep-TextFit: {0} clipped and {1} snug caption(s) across {2} language(s)." -f
                  $clipped.Count, ($results.Count - $clipped.Count), $langs.Count)
      Write-Host 'Painted content is not measured -- see the notes at the top.'
      }
   }

$results | Export-Csv -NoTypeInformation -Path (Join-Path $Repo 'build-out\textfit-sweep.csv')
Write-Host ('  full results: {0}' -f (Join-Path $Repo 'build-out\textfit-sweep.csv'))

exit ([int] ($results.Count -gt 0))
