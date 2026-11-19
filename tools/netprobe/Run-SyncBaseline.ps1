# P0 oracle for docs/TR4WSERVER_SQLITE_DESIGN.md section 9.
#
# For each netprobe case, start a FRESH tr4wserver in an empty directory, run the
# case with fixed QSO ids (--seed-ids), download the sync-port stream the way a
# station does (4-byte size + the header record + the records) and compare its
# MD5 with the recorded baseline. A server change that alters one byte of what a
# station would download fails here.
#
#   .\Run-SyncBaseline.ps1 -Exe <tr4wserver.exe>             # check
#   .\Run-SyncBaseline.ps1 -Exe <tr4wserver.exe> -Record     # (re)write baselines
#
# -Exe is a BUILT server. Build one OUTSIDE the tree so no tracked file is
# touched:  tr4w\build\Build-Server.ps1 -OutExe <scratch>\tr4wserver.exe
#
# Nothing in tr4w\target or tr4w\tr4wserver is touched: every case runs in a
# scratch directory (AppDir is the working directory, so the ini, SERVERLOG.TRW,
# tr4wserver.log and tr4wserver.lock all land there).
#
# -Port is the main port; the sync port is -Port + 1. Refuses to run while a
# server already listens on it.

param(
   [string] $Exe = '',
   [string] $PyServer = '',   # path to TR4WServerPy's tr4wserver.py, instead of -Exe
   [switch] $Record,
   [int] $Port = 1161,
   [string[]] $Cases = @('catchup', 'restock', 'edit', 'dup', 'serial'),
   [string] $Work = ''
)

$ErrorActionPreference = 'Stop'

$here = $PSScriptRoot
$probe = Join-Path $here 'netprobe.py'
$baselines = Join-Path $here 'baselines'
if (($Exe -eq '') -eq ($PyServer -eq '')) { Write-Host 'give exactly one of -Exe or -PyServer'; exit 2 }
if ($Exe -ne '' -and -not (Test-Path $Exe)) { Write-Host "no server exe: $Exe"; exit 2 }
if ($PyServer -ne '' -and -not (Test-Path $PyServer)) { Write-Host "no server script: $PyServer"; exit 2 }
if ($PyServer -ne '' -and $Record) { Write-Host 'refusing -Record with -PyServer: the baselines are the in-tree server'; exit 2 }
if ($Work -eq '') { $Work = Join-Path ([IO.Path]::GetTempPath()) 'netprobe-sync-baseline' }
New-Item -ItemType Directory -Force -Path $baselines | Out-Null

# A fixed id base, far from the clock seeds, one block per case so two cases
# never share an id even though each runs on an empty server.
$seeds = @{ catchup = 1000000; restock = 2000000; edit = 3000000; dup = 4000000; serial = 5000000 }

function Test-Listening([int] $p) {
   $c = New-Object System.Net.Sockets.TcpClient
   try { $c.Connect('127.0.0.1', $p); return $true } catch { return $false } finally { $c.Close() }
}

if (Test-Listening $Port) { Write-Host "something already listens on port $Port"; exit 2 }

$failed = 0
$rows = @()
foreach ($case in $Cases) {
   $dir = Join-Path $Work $case
   if (Test-Path $dir) { Remove-Item -Recurse -Force $dir }
   New-Item -ItemType Directory -Force -Path $dir | Out-Null
   $lockout = if ($case -eq 'serial') { 1 } else { 0 }
   $ini = "[TR4WSERVER]`r`nPORT=$Port`r`nSERIAL NUMBER LOCKOUT=$lockout`r`n"
   [IO.File]::WriteAllText((Join-Path $dir 'TR4WSERVER.INI'), $ini)

   if ($PyServer -ne '') {
      # The Python server takes its ini from -c and keeps SERVERLOG.TRW in the
      # working directory, so the scratch directory holds everything. No -I:
      # isolated mode would drop the script's own directory from sys.path.
      $server = Start-Process -FilePath 'python' -ArgumentList @($PyServer, '-c', (Join-Path $dir 'TR4WSERVER.INI')) -WorkingDirectory $dir -PassThru -WindowStyle Hidden
   }
   else {
      $server = Start-Process -FilePath $Exe -WorkingDirectory $dir -PassThru
   }
   try {
      $up = $false
      for ($i = 0; $i -lt 50 -and -not $up; $i++) {
         Start-Sleep -Milliseconds 200
         $up = Test-Listening $Port
      }
      if (-not $up) { throw "the server did not listen on $Port" }

      $dump = Join-Path $dir 'sync.bin'
      $args = @('-I', $probe, '--port', $Port, '--case', $case, '--label', 'baseline',
                '--burst', 30, '--restock-big', 0, '--seed-ids', $seeds[$case],
                '--dump-sync', $dump)
      & python @args | Out-Host
      $probeExit = $LASTEXITCODE
      if (-not (Test-Path $dump)) { throw "netprobe wrote no sync stream (exit $probeExit)" }
   }
   finally {
      if ($server -and -not $server.HasExited) { Stop-Process -Id $server.Id -Force }
      Start-Sleep -Milliseconds 500
   }

   $size = (Get-Item $dump).Length
   $md5 = (Get-FileHash -Algorithm MD5 $dump).Hash.ToLower()
   $line = "$md5  $size  $case"
   $rows += $line
   $recorded = Join-Path $baselines "$case.sync.md5"
   if ($Record) {
      Set-Content -Path $recorded -Value $line -Encoding ascii
      Copy-Item $dump (Join-Path $baselines "$case.sync.bin") -Force
      Write-Host "RECORDED $line"
   }
   else {
      if (-not (Test-Path $recorded)) { Write-Host "FAIL $case : no baseline"; $failed++; continue }
      $want = (Get-Content $recorded -Raw).Trim()
      if ($want -eq $line) { Write-Host "PASS $line" }
      else { Write-Host "FAIL $case : got [$line] want [$want]"; $failed++ }
   }
}

Write-Host "SUMMARY: $failed failed"
if ($failed -gt 0) { exit 1 }
exit 0
