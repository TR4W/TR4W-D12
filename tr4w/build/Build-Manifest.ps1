# Build-Manifest.ps1 -- compile W11.manifest into Win11.res.
#
# ---------------------------------------------------------------------------
# WHY THIS IS ITS OWN SCRIPT (2026-09-14)
# ---------------------------------------------------------------------------
#
# It used to live inline in FullBuild.ps1, and Build-App.ps1 did not do it at
# all. `tr4w.lpr` links {$R 'Win11.res'} unconditionally, so an iterating
# developer running Build-App.ps1 got whatever Win11.res happened to be left in
# build-out from some earlier run -- INCLUDING FOR A DIFFERENT ARCHITECTURE.
#
# That is not hypothetical. On 2026-09-14 the first x86_64-win64 binary failed
# at launch with
#
#     The application was unable to start correctly (0xc000007b).
#
# The manifest in the tree had already been corrected to
# processorArchitecture="*", and the manifest INSIDE THE BINARY was still the
# old 2733-byte x86 one, because nothing in Build-App rebuilt it. Two rebuilds
# were spent on a file the build was not reading.
#
# FullBuild's own comment above this block already recorded the ancestor of the
# same bug -- "a source file that looks live and is not". The fix then was to
# compile it in FullBuild; the fix now is to compile it wherever the exe is
# produced, from ONE implementation.
#
# Dot-source this and call Build-Tr4wManifest.

function Build-Tr4wManifest
{
   param(
      [Parameter(Mandatory = $true)] [string] $Tr4wDir,
      [Parameter(Mandatory = $true)] [string] $FpcRes,
      [switch] $Quiet
   )

   $manRc  = Join-Path $Tr4wDir 'Win11.rc'
   $manRes = Join-Path $Tr4wDir 'Win11.res'
   $manXml = Join-Path $Tr4wDir 'W11.manifest'

   if (-not (Test-Path $manXml)) { throw "W11.manifest not found at $manXml" }
   if (-not (Test-Path $manRc))  { throw "Win11.rc not found at $manRc" }
   if (-not (Test-Path $FpcRes)) { throw "fpcres not found at $FpcRes" }

   # WELL-FORMED XML FIRST, before it is compiled into anything.
   #
   # A malformed manifest does not fail the build, does not fail fpcres, and
   # does not warn: it produces an exe that Windows REFUSES TO START, with
   # "the application failed to start because its side-by-side configuration is
   # incorrect" and no clue which file is at fault. A double hyphen inside an
   # XML comment is illegal and no editor flags it -- that shipped once, and it
   # was written a second time on 2026-09-14 by someone documenting the rule.
   try
      {
      [xml]$null = Get-Content -LiteralPath $manXml -Raw
      }
   catch
      {
      throw "W11.manifest is not well-formed XML: $($_.Exception.Message)"
      }

   & $FpcRes -i $manRc -o $manRes -of res 2>&1 | Out-Null
   if ($LASTEXITCODE -ne 0) { throw 'fpcres could not compile Win11.rc' }

   $manBytes = [IO.File]::ReadAllBytes($manRes)
   $manText  = [Text.Encoding]::ASCII.GetString($manBytes)

   # A FLOOR on the result. fpcres is happy to emit a resource that does not
   # contain the manifest at all if the .rc reference cannot be resolved, and
   # an unthemed build looks like a styling opinion rather than a missing file.
   if ($manText -notmatch 'Common-Controls')
      {
      throw 'Win11.res does not contain the Common-Controls v6 dependency -- visual styles would be off'
      }

   # AND A FLOOR ON THE ARCHITECTURE FIELD, which is the 2026-09-14 lesson.
   #
   # A side-by-side dependency is resolved BY ARCHITECTURE, so an x86
   # Common-Controls assembly cannot be satisfied inside an x64 process and the
   # loader answers 0xC000007B -- which reads as a 32/64-bit DLL mix-up and is
   # not one. "*" means "whatever this process is" and serves both builds.
   if ($manText -match 'processorArchitecture="x86"')
      {
      throw 'W11.manifest pins processorArchitecture="x86" -- that cannot load in an x64 process (0xC000007B). Use "*".'
      }

   if (-not $Quiet)
      {
      Write-Host "  Win11.res ($($manBytes.Length) bytes, visual styles declared, architecture-neutral)"
      }
   return $manRes
}
