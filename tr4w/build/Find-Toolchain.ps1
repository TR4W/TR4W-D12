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
# WHERE IT LOOKS.  Every FIXED drive, not just C:.  The install roots below are
# relative names crossed with each fixed drive root, because "C:" is not a fact
# about the user's machine -- it was a fact about the machine this script was
# written on.  N4AF hit exactly that on 2026-08-19: a correct 32-bit FPC +
# Lazarus install on a PC whose tools live on D:, reported as TOOLCHAIN NOT
# FOUND with no hint that the drive was the problem.
#
# Overrides, highest priority first: explicit -Fpc/-Laz parameters, then the
# FPC_HOME / LAZARUS_DIR environment variables, then discovery.
#
# FAILS LOUD AND SPECIFIC. On failure it reports every location it looked in,
# because "toolchain not found" with no list is the least useful build error
# there is.

# Roots of every fixed local drive, C:\ first -- e.g. @('C:\', 'D:\').
#
# FIXED ONLY.  A removable or optical drive would make discovery depend on what
# happens to be plugged in, and an unready network drive can stall Test-Path for
# seconds on every build.  IsReady also excludes a locked BitLocker volume.
#
# C:\ is emitted first and unconditionally, so this can never find LESS than the
# hardcoded C: list it replaced, and the common case is still tested first.
#
# It lives in this file because FullBuild.ps1 already dot-sources it and is the
# only other caller (NSIS discovery).  A third caller is the moment to give it
# its own file -- not before.
function Get-Tr4wFixedDriveRoots
   {
   $roots = [System.Collections.Generic.List[string]]::new()
   $roots.Add('C:\')

   try
      {
      [System.IO.DriveInfo]::GetDrives() |
         Where-Object { $_.DriveType -eq [System.IO.DriveType]::Fixed -and $_.IsReady } |
         ForEach-Object { $_.RootDirectory.FullName } |
         Sort-Object |
         ForEach-Object {
            # -notcontains is case-insensitive, which is what we want here: C:\
            # must not be added twice because GetDrives spells it differently.
            if ($roots -notcontains $_) { $roots.Add($_) }
         }
      }
   catch
      {
      # Enumeration failed.  C:\ alone is exactly the old behaviour, so degrade
      # to it rather than failing a build over a drive-listing hiccup.
      }

   return $roots
   }

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

   # AN EXPLICIT PIN IS AUTHORITATIVE, NOT A FIRST GUESS.
   #
   # If -Fpc or FPC_HOME names something, that is the ONLY thing tried: a
   # rejected pin fails the run rather than silently falling through to some
   # other install. Discovery running as a fallback would defeat the entire
   # point of pinning on CI -- the build would succeed while using a toolchain
   # nobody configured, which is far worse than failing. (Measured 2026-08-13:
   # before this, -Laz <an x86_64-only Lazarus> quietly resolved to C:\Lazarus.)
   #
   # Either spelling is accepted -- fpc.exe itself or the directory holding it.
   # CI passes an FPC_HOME directory, a developer usually pastes the exe path,
   # and rejecting one of them is a pointless failure to explain.
   $fpcPin = if ($Fpc) { $Fpc } elseif ($env:FPC_HOME) { $env:FPC_HOME } else { '' }

   if ($fpcPin)
      {
      $fpcCandidates.Add($fpcPin)
      $fpcCandidates.Add((Join-Path $fpcPin 'fpc.exe'))
      $fpcCandidates.Add((Join-Path $fpcPin "bin\$Cpu-$Os\fpc.exe"))
      }
   else
      {
      $onPath = Get-Command 'fpc.exe' -ErrorAction SilentlyContinue
      if ($onPath) { $fpcCandidates.Add($onPath.Source) }

      # Common layouts, on every fixed drive, newest version directory first so a
      # machine with several FPC versions picks the newest rather than arbitrary.
      #
      # Windows paths are case-insensitive, so the old list's 'C:\FPC' + 'C:\fpc'
      # pair named ONE directory.  Kept as a single entry here: crossing a
      # duplicate with every drive pads the not-found listing without testing
      # anything new.
      foreach ($drive in Get-Tr4wFixedDriveRoots)
         {
         foreach ($rel in @('FPC', 'fpcupdeluxe\fpc', 'Lazarus\fpc'))
            {
            $base = Join-Path $drive $rel

            # Added even when $base does not exist, so a wrong-drive install
            # shows up in the 'Looked in' list instead of being skipped in
            # silence.  That listing is the entire diagnostic a remote user has.
            $fpcCandidates.Add((Join-Path $base "bin\$Cpu-$Os\fpc.exe"))

            if (-not (Test-Path -LiteralPath $base)) { continue }
            Get-ChildItem -LiteralPath $base -Directory -ErrorAction SilentlyContinue |
               Sort-Object Name -Descending |
               ForEach-Object { $fpcCandidates.Add((Join-Path $_.FullName "bin\$Cpu-$Os\fpc.exe")) }
            }
         }
      }

   foreach ($c in $fpcCandidates)
      {
      $searched.Add("  FPC: $c")
      $hit = Test-FpcCandidate $c $Cpu $Os
      if ($hit) { $fpcFound = $hit; break }
      }

   # ------------------------------------------------------------ Lazarus ----
   $lazFound = $null

   # Same rule as FPC above: a pin is authoritative, never a first guess.
   $lazPin = if ($Laz) { $Laz } elseif ($env:LAZARUS_DIR) { $env:LAZARUS_DIR } else { '' }

   $lazCandidates = [System.Collections.Generic.List[string]]::new()
   if ($lazPin)
      {
      $lazCandidates.Add($lazPin)
      }
   else
      {
      foreach ($drive in Get-Tr4wFixedDriveRoots)
         {
         foreach ($rel in @('Lazarus', 'fpcupdeluxe\lazarus'))
            {
            $lazCandidates.Add((Join-Path $drive $rel))
            }
         }
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
         if ($fpcPin)
            {
            Write-Host "  PINNED FPC REJECTED: $fpcPin" -ForegroundColor Red
            Write-Host "  It has no ppc386/ppcross386 backend or no $Cpu-$Os RTL, so it cannot"
            Write-Host '  build TR4W. Discovery is NOT attempted when a pin is given -- fix the'
            Write-Host '  pin or clear FPC_HOME / -Fpc to search instead.'
            }
         else
            {
            Write-Host "  No FPC able to target $Cpu-$Os." -ForegroundColor Red
            Write-Host '  Needs fpc.exe with a ppc386/ppcross386 backend and an i386-win32 RTL.'
            Write-Host '  Set FPC_HOME, or pass -Fpc <path to fpc.exe or its directory>.'
            }
         }
      if (-not $lazFound)
         {
         if ($lazPin)
            {
            Write-Host "  PINNED LAZARUS REJECTED: $lazPin" -ForegroundColor Red
            Write-Host "  It carries no LCL units for $Cpu-$Os. An x86_64-only install (the"
            Write-Host '  fpcupdeluxe default) cannot build TR4W, which is Win32. Discovery is'
            Write-Host '  NOT attempted when a pin is given -- fix the pin or clear LAZARUS_DIR.'
            }
         else
            {
            Write-Host "  No Lazarus with LCL units for $Cpu-$Os." -ForegroundColor Red
            Write-Host '  An x86_64-only install (fpcupdeluxe default) will NOT do -- TR4W is Win32.'
            Write-Host '  Set LAZARUS_DIR, or pass -Laz <lazarus dir>.'
            }
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
