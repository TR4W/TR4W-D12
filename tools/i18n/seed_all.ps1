<#
.SYNOPSIS
   Machine-seed every empty entry of the TR4W catalogues, one language at a
   time, against the LibreTranslate server.

.DESCRIPTION
   Runs `python tools/i18n/mt_seed.py --lang <X> --catalog <C> --url <U>` for
   each seedable language and catalogue, with a hard timeout per run, and
   prints a summary table at the end. Run it from anywhere; it changes to the
   repository root itself.

   WHAT IT CAN AND CANNOT TOUCH. mt_seed fills EMPTY entries only and marks
   each draft fuzzy. An entry with text -- reviewed or not -- is left alone,
   and this script never passes --reseed (that discards earlier machine drafts
   and would also clear any text a person typed and left flagged). So POLISH,
   which is under G0DVJ's finished review, only gains drafts for its empty
   entries: no reviewed Polish entry is ever touched.

   WHICH LANGUAGES. Every shipped language except Mongolian (MNG) and Serbian
   (SER): LibreTranslate's model source (Argos) has neither, so the server
   cannot translate them. Their catalogues are kept exactly as they are (NY4I,
   2026-11-21) in case models appear later; never delete or trim them.

   ONE RUN NEVER STALLS THE REST. Each mt_seed run gets its own process, an
   empty file as standard input (so nothing can wait on a keyboard), and a
   timeout (45 minutes by default). On expiry the process tree is killed, the
   run is reported as TIMEOUT, and the loop moves on. A failed run is reported
   and the loop moves on too. mt_seed writes the catalogue at the end of a run,
   so a killed run leaves that catalogue as it was.

   Logs: build-out\i18n-seed\<lang>-<catalog>.log -- the exit status, the time
   taken, and the tail of the run's output (the full output is beside it in
   .out / .err).

   AFTER SEEDING, REBUILD. The program embeds the catalogues through
   res\tr4w_languages.res, and Build-App.ps1 / Build-Tests.ps1 regenerate that
   when the catalogues' hashes change. Build once, then commit the changed
   i18n\*.po together with tr4w\res\tr4w_languages.res and its .inputs.
   (The help catalogues are read from help\ at run time and are not embedded.)

.PARAMETER Catalog
   tr4w (program strings), help (Preferences tooltips), or both (default).

.PARAMETER Url
   The LibreTranslate server.

.PARAMETER Lang
   Restrict to these TR4W language codes (e.g. -Lang GER,POL). MNG and SER are
   refused.

.PARAMETER TimeoutMinutes
   Per-run limit (default 45).

.PARAMETER DryRun
   Pass --dry-run to mt_seed: report what would be seeded, write nothing.

.EXAMPLE
   powershell -File tools\i18n\seed_all.ps1 -DryRun -Lang GER
   powershell -File tools\i18n\seed_all.ps1
   powershell -File tools\i18n\seed_all.ps1 -Catalog tr4w -Lang CHN,JPN,KOR
#>
[CmdletBinding()]
param(
   [ValidateSet('tr4w', 'help', 'both')]
   [string] $Catalog = 'both',
   [string] $Url = 'http://docker.bettersoftwaresolutions.com:5000',
   [string[]] $Lang = @(),
   [int] $TimeoutMinutes = 45,
   [switch] $DryRun
)

$ErrorActionPreference = 'Stop'

# The seedable languages and the file code each one's catalogue uses. Written
# out rather than read from pasconsts, because the point of the list is the
# DECISION about which languages the server can serve -- MNG and SER are absent
# on purpose (see the header).
$Seedable = [ordered]@{
   'CHN' = 'zh_CN'; 'CZE' = 'cs'; 'DAN' = 'da'; 'DUT' = 'nl'; 'ESP' = 'es'
   'FIN' = 'fi';    'FRA' = 'fr'; 'GER' = 'de'; 'GRE' = 'el'; 'ITA' = 'it'
   'JPN' = 'ja';    'KOR' = 'ko'; 'POL' = 'pl'; 'POR' = 'pt'; 'PTB' = 'pt_BR'
   'ROM' = 'ro';    'RUS' = 'ru'; 'SWE' = 'sv'; 'UKR' = 'uk'
}
$NotSeedable = @('MNG', 'SER')

$repo = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
Set-Location $repo

$python = (Get-Command python -ErrorAction SilentlyContinue)
if ($null -eq $python)
   {
   Write-Host 'seed_all: python is not on the PATH.' -ForegroundColor Red
   exit 2
   }

# Which languages: all seedable ones, or the -Lang subset (validated, so a typo
# fails here instead of silently seeding nothing).
$langs = @()
if ($Lang.Count -eq 0)
   {
   $langs = @($Seedable.Keys)
   }
else
   {
   foreach ($l in ($Lang | ForEach-Object { $_ -split ',' } | Where-Object { $_.Trim() -ne '' }))
      {
      $code = $l.Trim().ToUpperInvariant()
      if ($NotSeedable -contains $code)
         {
         Write-Host "seed_all: $code is not seedable -- the server has no model for it; its catalogue is kept as it is." -ForegroundColor Red
         exit 2
         }
      if (-not $Seedable.Contains($code))
         {
         Write-Host "seed_all: unknown language '$code'. Seedable: $($Seedable.Keys -join ' ')" -ForegroundColor Red
         exit 2
         }
      $langs += $code
      }
   }

$catalogs = @()
if ($Catalog -eq 'both')
   {
   $catalogs = @('tr4w', 'help')
   }
else
   {
   $catalogs = @($Catalog)
   }

$logDir = Join-Path $repo 'build-out\i18n-seed'
New-Item -ItemType Directory -Path $logDir -Force | Out-Null

# Standard input for every child: an empty file, so a prompt can never wait.
$emptyIn = Join-Path $logDir 'empty-stdin.txt'
[IO.File]::WriteAllText($emptyIn, '')

# How many live entries of a catalogue are still empty -- what a further run
# would try to seed. Asked of pofile, the same reader mt_seed uses. The code
# holds no double quotes, because Windows PowerShell 5.1 mangles them when it
# passes an argument to a native program.
$countCode = "import sys; sys.path.insert(0, 'tools/i18n'); import pofile; " +
             "es = [e for e in pofile.read_po(sys.argv[1]) if not e.obsolete and e.source.strip()]; " +
             "print(sum(1 for e in es if not e.target.strip()))"

function Get-EmptyCount
   {
   param([string] $Path)
   if (-not (Test-Path $Path))
      {
      return 'no file'
      }
   $n = & python -c $countCode $Path 2>$null
   if ($LASTEXITCODE -ne 0)
      {
      return '?'
      }
   return ($n | Select-Object -Last 1)
   }

function Stop-Tree
   {
   <# Kill a timed-out run AND its children. Process.Kill() alone leaves a
      child behind on Windows PowerShell 5.1, which has no Kill(entireProcessTree). #>
   param([System.Diagnostics.Process] $Process)
   & taskkill.exe /T /F /PID $Process.Id 2>&1 | Out-Null
   }

function Get-Tail
   {
   param([string] $Path, [int] $Lines = 40)
   if ((Test-Path $Path) -and ((Get-Item $Path).Length -gt 0))
      {
      return (Get-Content -Path $Path -Tail $Lines -Encoding UTF8)
      }
   return @()
   }

$env:PYTHONIOENCODING = 'utf-8'      # a redirected child would otherwise print CJK through cp1252 and crash
$results = New-Object System.Collections.Generic.List[object]

foreach ($l in $langs)
   {
   $code = $Seedable[$l]
   foreach ($c in $catalogs)
      {
      $po = Join-Path $repo ("i18n\{0}_{1}.po" -f $c, $code)
      $base = Join-Path $logDir ("{0}-{1}" -f $code, $c)
      $out = "$base.out"
      $err = "$base.err"
      $log = "$base.log"

      $argList = @('tools\i18n\mt_seed.py', '--lang', $l, '--catalog', $c, '--url', $Url)
      if ($DryRun)
         {
         $argList += '--dry-run'
         }

      Write-Host ("seed_all: {0} {1} ..." -f $l, $c)
      $started = Get-Date
      $status = ''
      $exit = $null
      try
         {
         $p = Start-Process -FilePath $python.Source -ArgumentList $argList `
                            -WorkingDirectory $repo -NoNewWindow -PassThru `
                            -RedirectStandardInput $emptyIn `
                            -RedirectStandardOutput $out -RedirectStandardError $err
         # Touching Handle keeps it open, without which Windows PowerShell 5.1
         # reports ExitCode as empty once the process is gone.
         $null = $p.Handle
         if ($p.WaitForExit($TimeoutMinutes * 60 * 1000))
            {
            $p.WaitForExit()                 # flush the redirected streams
            $exit = $p.ExitCode
            if ($exit -eq 0)
               {
               $status = 'ok'
               }
            else
               {
               $status = 'FAILED'
               }
            }
         else
            {
            Stop-Tree $p
            $status = 'TIMEOUT'
            }
         }
      catch
         {
         $status = 'NOT STARTED'
         [IO.File]::WriteAllText($err, $_.Exception.Message)
         }
      $seconds = [int]((Get-Date) - $started).TotalSeconds
      $empty = Get-EmptyCount $po

      $report = New-Object System.Collections.Generic.List[string]
      $report.Add("mt_seed --lang $l --catalog $c --url $Url$(if ($DryRun) { ' --dry-run' })")
      $report.Add("started $($started.ToString('yyyy-MM-dd HH:mm:ss')), $seconds s, status $status, exit $exit")
      $report.Add("entries still empty in $(Split-Path $po -Leaf): $empty")
      $report.Add('--- stdout (tail) ---')
      foreach ($line in (Get-Tail $out)) { $report.Add($line) }
      $report.Add('--- stderr (tail) ---')
      foreach ($line in (Get-Tail $err)) { $report.Add($line) }
      [IO.File]::WriteAllLines($log, $report, (New-Object Text.UTF8Encoding($false)))

      $results.Add([pscustomobject]@{
         Language = $l
         Catalog  = $c
         Status   = $status
         Exit     = $exit
         Seconds  = $seconds
         Empty    = $empty
      })
      Write-Host ("seed_all: {0} {1} {2} (exit {3}, {4} s, {5} still empty)" -f $l, $c, $status, $exit, $seconds, $empty)
      }
   }

Write-Host ''
$results | Format-Table -AutoSize Language, Catalog, Status, Exit, Seconds, Empty | Out-Host
Write-Host "Logs: $logDir"
if (-not $DryRun)
   {
   Write-Host 'Next: build once (Build-App.ps1) so res\tr4w_languages.res picks the text up, then commit the .po files with the .res and its .inputs.'
   }

$bad = @($results | Where-Object { $_.Status -ne 'ok' })
if ($bad.Count -gt 0)
   {
   exit 1
   }
exit 0
