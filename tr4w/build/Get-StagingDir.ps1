# Get-StagingDir.ps1 -- where each architecture's build output is STAGED, the one
# place that names the SHIPPING architecture, and the guard that keeps any other
# architecture out of the shipping program directory.
#
# Dot-source it:  . (Join-Path $PSScriptRoot 'Get-StagingDir.ps1')
#
# THE SHIPPING ARCHITECTURE IS x86_64-win64 (issue 299, flipped 2026-11-12; NY4I:
# "you can make the 64 bit version the default now" and "I want 32 bit to go
# away"). It is named ONCE, in the two constants below, and everything else in
# the build asks these functions rather than writing "x86_64" or "i386".
#
# WHY THERE IS A GUARD AT ALL.
#
# tr4w\target is the SHIPPING program directory: tr4w.exe, tr4wconvert.exe and the
# runtime DLLs live there, and full.nsi reads them from there. The DLLs of the
# two bitnesses have the SAME FILE NAMES (sqlite3.dll, libhamlib-4.dll, ...), so a
# build of the other architecture that staged beside its exe in target\ would
# silently replace the shipping DLLs with ones of the wrong bitness, and Windows
# reports that as "module not found" naming a file sitting right there. Four build
# scripts write into or beside it (FullBuild, Build-App, Build-Server,
# Build-Convert).
#
# THE RULE: the shipping architecture stages into tr4w\target (and
# tr4w\tr4wserver\tr4wserver.exe). Every other target writes ONLY under
# <repo>\build-out\dist\<cpu>-<os>\  (gitignored, with the rest of build-out).
# Assert-Tr4wShippingPathOnly throws when a non-shipping build is pointed at the
# shipping locations, so a direct -OutExe cannot get round it.
# Lint-ArchStaging.ps1 pins this, with a fixture, and PE-checks every DLL.
#
# THE RUNTIME DLLs of EVERY architecture live in tr4w\redist\<cpu>-<os>\ (see
# redist\README.md). target\ holds a COPY of the shipping architecture's set, so
# the program runs from the tree; Build-App.ps1 and Build-Tests.ps1 stage from
# redist\ for any architecture and never from target\.

$script:Tr4wShippingCpu = 'x86_64'
$script:Tr4wShippingOs  = 'win64'
$script:Tr4wShippingPeMachine = 0x8664

function Get-Tr4wFullPath
   {
   param([Parameter(Mandatory = $true)][string] $Path)

   return [IO.Path]::GetFullPath($Path).TrimEnd('\', '/')
   }

function Test-Tr4wIsShippingTarget
   {
   param([string] $Cpu, [string] $Os)

   return ($Cpu -eq $script:Tr4wShippingCpu) -and ($Os -eq $script:Tr4wShippingOs)
   }

# Fills in whatever a script was not given: no -Cpu means the shipping
# architecture, and -Cpu alone implies its Windows target (i386 -> win32,
# x86_64 -> win64). Returns a hashtable { Cpu; Os }.
function Resolve-Tr4wTarget
   {
   param([string] $Cpu, [string] $Os)

   if ($Cpu -eq '') { $Cpu = $script:Tr4wShippingCpu }
   if ($Os -eq '')
      {
      if ($Cpu -eq 'i386') { $Os = 'win32' } else { $Os = 'win64' }
      }
   return @{ Cpu = $Cpu; Os = $Os }
}

# The PE machine word a given target's binaries carry: 0x014C (x86), 0x8664 (x64),
# 0 for a target this project does not build for Windows.
function Get-Tr4wExpectedPeMachine
   {
   param([string] $Cpu)

   switch ($Cpu)
      {
      'i386'   { return 0x014C }
      'x86_64' { return 0x8664 }
      default  { return 0 }
      }
   }

# The PE machine word of a file, 0 if it is not a PE image. Read from the header,
# never trusted from a file name: rigctld.exe once sat in target\ as x86_64 while
# the documents called it 32-bit.
function Get-Tr4wPeMachine
   {
   param([Parameter(Mandatory = $true)][string] $Path)

   $fs = [IO.File]::OpenRead($Path)
   try
      {
      $br = New-Object IO.BinaryReader($fs)
      if ($fs.Length -lt 0x40) { return 0 }
      $fs.Position = 0x3C
      $peOffset = $br.ReadInt32()
      if ($peOffset -le 0 -or $peOffset -ge $fs.Length - 6) { return 0 }
      $fs.Position = $peOffset
      if ($br.ReadUInt32() -ne 0x00004550) { return 0 }    # the PE signature
      return [int] $br.ReadUInt16()
      }
   finally
      {
      $fs.Dispose()
      }
   }

function Get-Tr4wPeMachineName
   {
   param([int] $Machine)

   switch ($Machine)
      {
      0x014C  { return 'x86 (32-bit)' }
      0x8664  { return 'x64 (64-bit)' }
      0x01C0  { return 'ARM' }
      0xAA64  { return 'ARM64' }
      default { return ('0x{0:X4}' -f $Machine) }
      }
   }

# Where an architecture's runtime DLLs are kept: tr4w\redist\<cpu>-<os>.
function Get-Tr4wRedistDir
   {
   param(
      [Parameter(Mandatory = $true)][string] $Tr4wDir,
      [Parameter(Mandatory = $true)][string] $Cpu,
      [Parameter(Mandatory = $true)][string] $Os
   )

   return (Join-Path $Tr4wDir "redist\$Cpu-$Os")
}

# The directory a build's exe and runtime files are staged into.
# The shipping architecture -> tr4w\target; anything else -> build-out\dist\<cpu>-<os>.
function Get-Tr4wStageDir
   {
   param(
      [Parameter(Mandatory = $true)][string] $Tr4wDir,
      [Parameter(Mandatory = $true)][string] $Cpu,
      [Parameter(Mandatory = $true)][string] $Os
   )

   if (Test-Tr4wIsShippingTarget -Cpu $Cpu -Os $Os)
      {
      return (Join-Path $Tr4wDir 'target')
      }
   return (Join-Path (Split-Path $Tr4wDir -Parent) "build-out\dist\$Cpu-$Os")
   }

# Where tr4wserver.exe goes. The shipping architecture keeps tr4w\tr4wserver\
# (full.nsi reads it there); other targets keep it beside the rest of their stage.
function Get-Tr4wServerExePath
   {
   param(
      [Parameter(Mandatory = $true)][string] $Tr4wDir,
      [Parameter(Mandatory = $true)][string] $Cpu,
      [Parameter(Mandatory = $true)][string] $Os
   )

   if (Test-Tr4wIsShippingTarget -Cpu $Cpu -Os $Os)
      {
      return (Join-Path $Tr4wDir 'tr4wserver\tr4wserver.exe')
      }
   return (Join-Path (Get-Tr4wStageDir -Tr4wDir $Tr4wDir -Cpu $Cpu -Os $Os) 'tr4wserver.exe')
   }

# True when $Path is $Dir itself or anything beneath it. Full paths, ordinal
# case-insensitive (Windows), so '..\target\', 'TARGET' and 'target\.' all match.
function Test-Tr4wUnder
   {
   param([string] $Path, [string] $Dir)

   $p = Get-Tr4wFullPath $Path
   $d = Get-Tr4wFullPath $Dir
   if ($p.Equals($d, [StringComparison]::OrdinalIgnoreCase)) { return $true }
   return $p.StartsWith($d + '\', [StringComparison]::OrdinalIgnoreCase)
}

# THE GUARD. Throws when a NON-shipping build would write into tr4w\target or
# tr4w\tr4wserver. $What names the file in the message ("-OutExe", "staging dir").
function Assert-Tr4wShippingPathOnly
   {
   param(
      [Parameter(Mandatory = $true)][string] $Tr4wDir,
      [Parameter(Mandatory = $true)][string] $Cpu,
      [Parameter(Mandatory = $true)][string] $Os,
      [Parameter(Mandatory = $true)][string] $Path,
      [string] $What = 'output'
   )

   if (Test-Tr4wIsShippingTarget -Cpu $Cpu -Os $Os) { return }

   foreach ($shippingDir in @((Join-Path $Tr4wDir 'target'), (Join-Path $Tr4wDir 'tr4wserver')))
      {
      if (Test-Tr4wUnder -Path $Path -Dir $shippingDir)
         {
         throw ("REFUSED: a $Cpu-$Os build would write its $What to '$Path', which is inside " +
                "'$shippingDir' -- the $script:Tr4wShippingCpu-$script:Tr4wShippingOs program directory that full.nsi ships. " +
                "Stage it under '$(Get-Tr4wStageDir -Tr4wDir $Tr4wDir -Cpu $Cpu -Os $Os)' instead.")
         }
      }
   }
