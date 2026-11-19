# P0 oracle, part 2: a .TRW fixture round trip through the server.
#
# Put a .TRW file in a fresh server's directory as SERVERLOG.TRW, start the
# server on it, download the sync-port stream the way a station does, and
# require   stream == (4-byte native-order size) + the file, byte for byte.
# That is what a station relies on today (docs/TR4WSERVER_SQLITE_DESIGN.md
# section 4.4), and it is the equality a SQLite store must reproduce after an
# import (P2: "import/export MD5 round trip").
#
#   .\Run-TrwRoundTrip.ps1 -Exe <tr4wserver.exe>                  # the recorded baselines
#   .\Run-TrwRoundTrip.ps1 -Exe <tr4wserver.exe> -Fixture a.TRW   # any server log
#
# With no -Fixture it uses baselines\*.sync.bin with the leading 4-byte size
# cut off: each of those IS a server log (header record + records) written by
# the real server. The server is never allowed to rewrite the fixture: it runs on
# a copy in a scratch directory.

param(
   [Parameter(Mandatory = $true)] [string] $Exe,
   [string[]] $Fixture = @(),
   [int] $Port = 1162,
   [string] $Work = ''
)

$ErrorActionPreference = 'Stop'

$here = $PSScriptRoot
$probe = Join-Path $here 'netprobe.py'
if (-not (Test-Path $Exe)) { Write-Host "no server exe: $Exe"; exit 2 }
if ($Work -eq '') { $Work = Join-Path ([IO.Path]::GetTempPath()) 'netprobe-trw-roundtrip' }

function Test-Listening([int] $p) {
   $c = New-Object System.Net.Sockets.TcpClient
   try { $c.Connect('127.0.0.1', $p); return $true } catch { return $false } finally { $c.Close() }
}

if (Test-Listening $Port) { Write-Host "something already listens on port $Port"; exit 2 }

# name -> bytes of the .TRW
$trw = [ordered]@{}
if ($Fixture.Count -eq 0) {
   foreach ($f in Get-ChildItem (Join-Path $here 'baselines') -Filter '*.sync.bin') {
      $all = [IO.File]::ReadAllBytes($f.FullName)
      $trw[$f.Name -replace '\.sync\.bin$', ''] = $all[4..($all.Length - 1)]
   }
}
else {
   foreach ($f in $Fixture) { $trw[[IO.Path]::GetFileName($f)] = [IO.File]::ReadAllBytes($f) }
}

$failed = 0
foreach ($name in $trw.Keys) {
   $dir = Join-Path $Work $name
   if (Test-Path $dir) { Remove-Item -Recurse -Force $dir }
   New-Item -ItemType Directory -Force -Path $dir | Out-Null
   [IO.File]::WriteAllText((Join-Path $dir 'TR4WSERVER.INI'),
      "[TR4WSERVER]`r`nPORT=$Port`r`nSERIAL NUMBER LOCKOUT=0`r`n")
   [IO.File]::WriteAllBytes((Join-Path $dir 'SERVERLOG.TRW'), $trw[$name])

   $server = Start-Process -FilePath $Exe -WorkingDirectory $dir -PassThru
   try {
      $up = $false
      for ($i = 0; $i -lt 50 -and -not $up; $i++) {
         Start-Sleep -Milliseconds 200
         $up = Test-Listening $Port
      }
      if (-not $up) { throw "the server did not listen on $Port" }
      $dump = Join-Path $dir 'sync.bin'
      & python -I $probe --port $Port --case none --label roundtrip --dump-sync $dump | Out-Host
   }
   finally {
      if ($server -and -not $server.HasExited) { Stop-Process -Id $server.Id -Force }
      Start-Sleep -Milliseconds 500
   }

   $want = [byte[]]([BitConverter]::GetBytes([uint32] $trw[$name].Length) + $trw[$name])
   $got = if (Test-Path $dump) { [IO.File]::ReadAllBytes($dump) } else { [byte[]]@() }
   $same = ($got.Length -eq $want.Length) -and
           ((Get-FileHash -Algorithm MD5 -InputStream ([IO.MemoryStream]::new($got))).Hash -eq
            (Get-FileHash -Algorithm MD5 -InputStream ([IO.MemoryStream]::new($want))).Hash)
   if ($same) { Write-Host "PASS $name ($($got.Length) bytes)" }
   else { Write-Host "FAIL $name : stream $($got.Length) bytes, file+size $($want.Length) bytes"; $failed++ }
}

Write-Host "SUMMARY: $failed failed"
if ($failed -gt 0) { exit 1 }
exit 0
