# Locates FPC and Lazarus on THIS machine. Dot-source it; it returns nothing and
# defines Find-Tr4wToolchain.
#
# WHY DISCOVERY RATHER THAN CONSTANTS.  Every build script here used to default
# to C:\FPC\3.2.2\bin\i386-win32\fpc.exe and C:\Lazarus, which is one
# developer's machine written into the build system. A clone on any other PC
# would need every path passed on every invocation.
#
# WHAT IT ACTUALLY CHECKS -- and this is the part that matters, because "fpc.exe
# exists" is not the question:
#
#   * a compiler that can TARGET i386-win32. fpc.exe is only a driver; the
#     backend is ppc386.exe (native) or ppcross386.exe (cross). An x86_64-only
#     install has neither, and TR4W is a Win32 program.
#   * an i386-win32 RTL (units\i386-win32\rtl\system.ppu).
#   * LCL units for i386-win32. This is exactly where the two Lazarus installs
#     on NY4I's machine differ: C:\Lazarus carries them, the fpcupdeluxe one is
#     x86_64-only and cannot build TR4W at all. Finding "a Lazarus" is not
#     enough; finding one with the right units is.
#
# Overrides, highest priority first: explicit -Fpc/-Laz parameters, then the
# FPC_HOME / LAZARUS_DIR environment variables, then discovery.
#
# FAILS LOUD AND SPECIFIC. On failure it reports every location it looked in,
# because "toolchain not found" with no list is the least useful build error
# there is.

function Find-Tr4wToolchain
   {
   param(
      [string] $Fpc = '',
      [string] $Laz = '',
      [string] $Cpu = 'i386',
      [string] $Os  = 'win32',
      [switch] $Quiet
   )

   $searched = [System.Collections.Generic.List[string]]::new()

   # ---------------------------------------------------------------- FPC ----
   function Test-FpcCandidate([string] $exe, [string] $cpuWanted, [string] $osWanted)
      {
      if ([string]::IsNullOrWhiteSpace($exe) -or -not (Test-Path -LiteralPath $exe -PathType Leaf))
         {
         return $null
         }

      $bin = Split-Path $exe -Parent

      # ppc386 = native i386 backend, ppcross386 = cross from another host.
      # Either will do; neither means this install cannot make a Win32 binary.
      $backend = @('ppc386.exe', 'ppcross386.exe') |
                 ForEach-Object { Join-Path $bin $_ } |
                 Where-Object { Test-Path -LiteralPath $_ } |
                 Select-Object -First 1

      if ($cpuWanted -eq 'i386' -and -not $backend)
         {
         return $null
         }

      # <root>\bin\<host>\fpc.exe -> <root>
      $root = Split-Path (Split-Path $bin -Parent) -Parent
      $rtl  = Join-Path $root "units\$cpuWanted-$osWanted\rtl\system.ppu"
      if (-not (Test-Path -LiteralPath $rtl))
         {
         return $null
         }

      return [pscustomobject]@{
         Exe     = $exe
         Bin     = $bin
         Root    = $root
         FpcRes  = Join-Path $bin 'fpcres.exe'
         Backend = $backend
      }
      }

   $fpcFound = $null

   $fpcCandidates = [System.Collections.Generic.List[string]]::new()

   if ($Fpc)          { $fpcCandidates.Add($Fpc) }
   if ($env:FPC_HOME)
      {
      # Accept either the compiler's own bin dir or the install root.
      $fpcCandidates.Add((Join-Path $env:FPC_HOME 'fpc.exe'))
      $fpcCandidates.Add((Join-Path $env:FPC_HOME "bin\$Cpu-$Os\fpc.exe"))
      }

   $onPath = Get-Command 'fpc.exe' -ErrorAction SilentlyContinue
   if ($onPath) { $fpcCandidates.Add($onPath.Source) }

   # Common layouts, newest version directory first so a machine with several
   # FPC versions picks the newest rather than an arbitrary one.
   foreach ($base in @('C:\FPC', 'C:\fpc', 'C:\fpcupdeluxe\fpc', 'C:\lazarus\fpc', 'C:\Lazarus\fpc'))
      {
      if (-not (Test-Path -LiteralPath $base)) { continue }
      $fpcCandidates.Add((Join-Path $base "bin\$Cpu-$Os\fpc.exe"))
      Get-ChildItem -LiteralPath $base -Directory -ErrorAction SilentlyContinue |
         Sort-Object Name -Descending |
         ForEach-Object { $fpcCandidates.Add((Join-Path $_.FullName "bin\$Cpu-$Os\fpc.exe")) }
      }

   foreach ($c in $fpcCandidates)
      {
      $searched.Add("  FPC: $c")
      $hit = Test-FpcCandidate $c $Cpu $Os
      if ($hit) { $fpcFound = $hit; break }
      }

   # ------------------------------------------------------------ Lazarus ----
   $lazFound = $null

   $lazCandidates = [System.Collections.Generic.List[string]]::new()
   if ($Laz)              { $lazCandidates.Add($Laz) }
   if ($env:LAZARUS_DIR)  { $lazCandidates.Add($env:LAZARUS_DIR) }
   foreach ($base in @('C:\Lazarus', 'C:\lazarus', 'C:\fpcupdeluxe\lazarus'))
      {
      $lazCandidates.Add($base)
      }

   foreach ($c in $lazCandidates)
      {
      if ([string]::IsNullOrWhiteSpace($c)) { continue }
      $units = Join-Path $c "lcl\units\$Cpu-$Os"
      $searched.Add("  LCL: $units")
      if (Test-Path -LiteralPath $units)
         {
         $lazFound = [pscustomobject]@{
            Dir      = $c
            LclUnits = $units
         }
         break
         }
      }

   # --------------------------------------------------------------- done ----
   if (-not $fpcFound -or -not $lazFound)
      {
      Write-Host ''
      Write-Host 'TOOLCHAIN NOT FOUND' -ForegroundColor Red
      if (-not $fpcFound)
         {
         Write-Host "  No FPC able to target $Cpu-$Os." -ForegroundColor Red
         Write-Host '  Needs fpc.exe with a ppc386/ppcross386 backend and an i386-win32 RTL.'
         Write-Host '  Set FPC_HOME, or pass -Fpc <path to fpc.exe>.'
         }
      if (-not $lazFound)
         {
         Write-Host "  No Lazarus with LCL units for $Cpu-$Os." -ForegroundColor Red
         Write-Host '  An x86_64-only install (fpcupdeluxe default) will NOT do -- TR4W is Win32.'
         Write-Host '  Set LAZARUS_DIR, or pass -Laz <lazarus dir>.'
         }
      Write-Host ''
      Write-Host 'Looked in:'
      $searched | ForEach-Object { Write-Host $_ }
      return $null
      }

   if (-not $Quiet)
      {
      Write-Host "  FPC     : $($fpcFound.Exe)"
      Write-Host "  Lazarus : $($lazFound.Dir)"
      }

   return [pscustomobject]@{
      FpcExe   = $fpcFound.Exe
      FpcBin   = $fpcFound.Bin
      FpcRoot  = $fpcFound.Root
      FpcRes   = $fpcFound.FpcRes
      LazDir   = $lazFound.Dir
      LclUnits = $lazFound.LclUnits
      Cpu      = $Cpu
      Os       = $Os
   }
   }
