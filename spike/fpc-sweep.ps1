# Compiles every TR4W unit with FPC and reports what fails, as a COUNT rather
# than an estimate.  This is the measurement behind the -MdelphiUnicode
# decision: the two known bills (Indy's non-Unicode FPC branch, and FPC's RTL
# binding generic Win32 names to ANSI) are both compile-time visible, so the
# compiler can enumerate them for us.
#
#   .\fpc-sweep.ps1                        # delphiunicode, i386-win32
#   .\fpc-sweep.ps1 -Mode delphi           # the 8-bit comparison run
#
# Deliberately NOT -B.  A full rebuild per unit would recompile the whole
# dependency cone ~260 times; reusing .ppu makes the sweep minutes instead of
# hours.  The cost is that a failed unit makes its dependents fail too, so the
# report separates CASCADE errors (can't find/use a unit that itself failed)
# from REAL ones.  Only the real column is a defect count.

param(
   [string] $Mode = 'delphiunicode',
   [string] $Cpu  = 'i386',
   [string] $Os   = 'win32',
   [string] $Fpc  = 'C:\FPC\3.2.2\bin\i386-win32\fpc.exe',
   [string] $Repo = 'C:\tr4w-d12'
)

$src = Join-Path $Repo 'tr4w\src'
$out = Join-Path $Repo "spike\units\sweep-$Cpu-$Os-$Mode"
$rpt = Join-Path $Repo "spike\sweep-$Mode.txt"

if (-not (Test-Path $Fpc))
   {
   Write-Error "FPC not found at $Fpc"
   exit 1
   }

$rtl = Join-Path (Split-Path (Split-Path (Split-Path $Fpc -Parent) -Parent) -Parent) "units\$Cpu-$Os\rtl\system.ppu"
if (-not (Test-Path $rtl))
   {
   Write-Error "No RTL for $Cpu-$Os -- expected $rtl"
   exit 1
   }

# Start clean: a stale .ppu from an earlier mode would be silently reused and
# the sweep would under-report.
if (Test-Path $out)
   {
   Remove-Item -Recurse -Force $out
   }
New-Item -ItemType Directory -Force $out | Out-Null

$searchPaths = @(
   $src
   Join-Path $src 'trdos'
   Join-Path $src 'utils'
   Join-Path $src 'radioFactory'
   Join-Path $Repo 'tr4w\Include'
   Join-Path $Repo 'tr4w\include\Core'
   Join-Path $Repo 'tr4w\include\System'
   Join-Path $Repo 'tr4w\include\Protocols'
)

$baseArgs = @("-M$Mode", "-P$Cpu", "-T$Os", '-Sc', '-Cn', '-Se99', "-FU$out")
foreach ($p in $searchPaths)
   {
   $baseArgs += "-Fu$p"
   }

# lang\ holds {$INCLUDE} fragments, not units -- they compile only as part of
# VC.pas.  The rest is editor debris.
$units = Get-ChildItem -Path $searchPaths[0..3] -Filter *.pas -File |
   Where-Object { $_.Name -notmatch '~|\.bak$|^LOGSUBS2~' } |
   Sort-Object Name

$results = @()
$i = 0

Push-Location $src
try
   {
   foreach ($u in $units)
      {
      $i++
      Write-Host ("[{0}/{1}] {2}" -f $i, $units.Count, $u.Name)

      $text = (& $Fpc @baseArgs $u.FullName 2>&1) -join "`n"
      $errs = [regex]::Matches($text, '(?m)^.*\b(Error|Fatal):.*$') |
                 ForEach-Object { $_.Value.Trim() } |
                 Where-Object { $_ -notmatch 'There were \d+ errors|Compilation aborted|returned an error exitcode' }

      # A unit that failed only because a dependency failed is not a defect.
      $cascade = $errs | Where-Object { $_ -match "Can't find unit|Can not find unit|error while linking" }
      $real    = $errs | Where-Object { $_ -notmatch "Can't find unit|Can not find unit|error while linking" }

      $results += [pscustomobject]@{
         Unit    = $u.Name
         Real    = $real.Count
         Cascade = $cascade.Count
         Errors  = $real
      }
      }
   }
finally
   {
   Pop-Location
   }

$clean   = ($results | Where-Object { $_.Real -eq 0 -and $_.Cascade -eq 0 }).Count
$failed  = $results | Where-Object { $_.Real -gt 0 }
$blocked = ($results | Where-Object { $_.Real -eq 0 -and $_.Cascade -gt 0 }).Count

$lines = @()
$lines += "FPC sweep -- $Cpu-$Os -M$Mode"
$lines += "units swept : $($units.Count)"
$lines += "clean       : $clean"
$lines += "real errors : $($failed.Count) units, $(($failed | Measure-Object Real -Sum).Sum) errors"
$lines += "blocked only: $blocked (dependency failed; not a defect)"
$lines += ''
$lines += '=== error text, most common first ==='

# Categorise by the message with positions stripped, so 40 instances of one
# defect shape read as one row.
$results.Errors |
   ForEach-Object { $_ -replace '^.*?\(\d+(,\d+)?\)\s*', '' } |
   Group-Object |
   Sort-Object Count -Descending |
   ForEach-Object { $lines += ("{0,5}  {1}" -f $_.Count, $_.Name) }

$lines += ''
$lines += '=== per unit ==='
foreach ($r in ($failed | Sort-Object Real -Descending))
   {
   $lines += ("{0,5} real  {1}" -f $r.Real, $r.Unit)
   foreach ($e in $r.Errors)
      {
      $lines += "         $e"
      }
   }

$lines | Set-Content -Path $rpt -Encoding UTF8
$lines | Select-Object -First 40
Write-Host ''
Write-Host "full report: $rpt"
