# Get-StagingDir.ps1 -- the one place that names the Windows target, and the
# PE-bitness helpers every build script uses to refuse a wrong-architecture DLL.
#
# Dot-source it:  . (Join-Path $PSScriptRoot 'Get-StagingDir.ps1')
#
# WINDOWS TR4W IS x86_64-win64 AND NOTHING ELSE. NY4I, 2026-11-12: "I have no
# plans to ever support 32 bit Windows OS". Until that day an i386-win32 build
# was kept behind -Cpu i386 as a safety net; the per-architecture staging that
# kept the two bitnesses apart (a second stage directory, a guard refusing a
# 32-bit build the shipping directory) went with it. What stays is the part that
# was never about i386: a DLL of the wrong bitness is not reported by Windows as
# a bitness problem, it is "module not found" naming a file sitting right there,
# or a bare 0xC000007B from the loader with nothing in tr4w.log. So the machine
# word is read from each DLL's PE header and compared with $script:Tr4wPeMachine
# -- never trusted from a name.
#
# THE RUNTIME DLLs live in tr4w\redist\x86_64-win64\ (see redist\README.md);
# tr4w\target holds a COPY so the program runs from the tree, and is never a
# source. Build-App.ps1 and Build-Tests.ps1 stage from redist\.
# Lint-ArchStaging.ps1 pins all of this, with a fixture.

$script:Tr4wCpu       = 'x86_64'
$script:Tr4wOs        = 'win64'
$script:Tr4wPeMachine = 0x8664

function Get-Tr4wFullPath
   {
   param([Parameter(Mandatory = $true)][string] $Path)

   return [IO.Path]::GetFullPath($Path).TrimEnd('\', '/')
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

# THE GUARD, ONE DEFINITION. Every *.dll in $Dir must be a PE image of the
# Windows target's machine word. Returns one message per offender (empty = all
# good), so a caller can print the list, fail, or count. A file that is not a PE
# image at all is an offender too -- fail closed.
function Get-Tr4wWrongArchDlls
   {
   param([Parameter(Mandatory = $true)][string] $Dir)

   $bad = @()
   foreach ($f in @(Get-ChildItem -LiteralPath $Dir -Filter '*.dll' -File))
      {
      $m = Get-Tr4wPeMachine -Path $f.FullName
      if ($m -ne $script:Tr4wPeMachine)
         {
         $got  = if ($m -eq 0) { 'not a PE image' } else { Get-Tr4wPeMachineName -Machine $m }
         $want = Get-Tr4wPeMachineName -Machine $script:Tr4wPeMachine
         $bad += "$($f.FullName) is $got, expected $want"
         }
      }
   return $bad
}

# Where the runtime DLLs are kept: tr4w\redist\x86_64-win64.
function Get-Tr4wRedistDir
   {
   param([Parameter(Mandatory = $true)][string] $Tr4wDir)

   return (Join-Path $Tr4wDir "redist\$script:Tr4wCpu-$script:Tr4wOs")
}
