# Get-StagingDir.ps1 -- where each architecture's build output is STAGED, and the
# guard that keeps a 64-bit build out of the 32-bit program directory.
#
# Dot-source it:  . (Join-Path $PSScriptRoot 'Get-StagingDir.ps1')
#
# WHY THIS EXISTS (issue 299, found 2026-11-12 while proving the x64 build).
#
# tr4w\target is the i386 PROGRAM directory: tr4w.exe, tr4wconvert.exe and the
# seven 32-bit runtime DLLs live there, and full.nsi reads them from there. Three
# build scripts used to write into it (or beside it) whatever -Cpu they were given:
#
#   FullBuild.ps1     passed -OutExe target\tr4w.exe for ANY cpu
#   Build-App.ps1     stages the DLLs next to the exe, so an exe in target\ made it
#                     copy the x64 DLLs OVER the 32-bit ones (the DLL names are
#                     identical in both bitnesses -- see tr4w\redist\README.md)
#   Build-Server.ps1  defaults to tr4w\tr4wserver\tr4wserver.exe, the file full.nsi
#                     ships for i386
#   Build-Convert.ps1 defaults to tr4w\target\tr4wconvert.exe
#
# So a 64-bit build would have replaced the shipping 32-bit files with 64-bit ones
# of the same names, silently, and the 32-bit installer would then have bundled
# them. Nothing would have said so: Windows reports the mismatch as "module not
# found" naming a file that is sitting right there.
#
# THE RULE: i386-win32 keeps writing exactly where it always has. Every other
# target writes ONLY under  <repo>\build-out\dist\<cpu>-<os>\  (gitignored, with
# the rest of build-out). Assert-Tr4wNotI386Path throws when a non-i386 build is
# pointed at the i386 locations, so a direct -OutExe cannot get round it.
# Lint-ArchStaging.ps1 pins this, with a fixture.

function Get-Tr4wFullPath
   {
   param([Parameter(Mandatory = $true)][string] $Path)

   return [IO.Path]::GetFullPath($Path).TrimEnd('\', '/')
   }

function Test-Tr4wIsI386Win32
   {
   param([string] $Cpu, [string] $Os)

   return ($Cpu -eq 'i386') -and ($Os -eq 'win32')
   }

# The directory a build's exe and runtime files are staged into.
# i386-win32 -> tr4w\target (unchanged); anything else -> build-out\dist\<cpu>-<os>.
function Get-Tr4wStageDir
   {
   param(
      [Parameter(Mandatory = $true)][string] $Tr4wDir,
      [Parameter(Mandatory = $true)][string] $Cpu,
      [Parameter(Mandatory = $true)][string] $Os
   )

   if (Test-Tr4wIsI386Win32 -Cpu $Cpu -Os $Os)
      {
      return (Join-Path $Tr4wDir 'target')
      }
   return (Join-Path (Split-Path $Tr4wDir -Parent) "build-out\dist\$Cpu-$Os")
   }

# Where tr4wserver.exe goes. i386 keeps tr4w\tr4wserver\ (full.nsi reads it
# there); other targets keep it beside the rest of their stage.
function Get-Tr4wServerExePath
   {
   param(
      [Parameter(Mandatory = $true)][string] $Tr4wDir,
      [Parameter(Mandatory = $true)][string] $Cpu,
      [Parameter(Mandatory = $true)][string] $Os
   )

   if (Test-Tr4wIsI386Win32 -Cpu $Cpu -Os $Os)
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

# THE GUARD. Throws when a non-i386-win32 build would write into tr4w\target or
# tr4w\tr4wserver. $What names the file in the message ("-OutExe", "staging dir").
function Assert-Tr4wNotI386Path
   {
   param(
      [Parameter(Mandatory = $true)][string] $Tr4wDir,
      [Parameter(Mandatory = $true)][string] $Cpu,
      [Parameter(Mandatory = $true)][string] $Os,
      [Parameter(Mandatory = $true)][string] $Path,
      [string] $What = 'output'
   )

   if (Test-Tr4wIsI386Win32 -Cpu $Cpu -Os $Os) { return }

   foreach ($i386Dir in @((Join-Path $Tr4wDir 'target'), (Join-Path $Tr4wDir 'tr4wserver')))
      {
      if (Test-Tr4wUnder -Path $Path -Dir $i386Dir)
         {
         throw ("REFUSED: a $Cpu-$Os build would write its $What to '$Path', which is inside " +
                "'$i386Dir' -- the 32-bit program directory that full.nsi ships. " +
                "Stage it under '$(Get-Tr4wStageDir -Tr4wDir $Tr4wDir -Cpu $Cpu -Os $Os)' instead.")
         }
      }
   }
