<#
.SYNOPSIS
   Fails the build when a unit resolves a file path from the binary's directory
   or the working directory instead of asking uAppPaths.

.DESCRIPTION
   TWO RULES DISAGREED AND ONE OF THEM WAS INVISIBLE. `ExtractFilePath(ParamStr(0))`
   is the BINARY's directory; `GetCurrentDir` is the WORKING directory. The
   shipped layout hides the difference, because FullBuild puts tr4w.exe in
   target\ beside the data -- but the binary is developed and run from
   build-out\ with the working directory set to target\, and there the two point
   at different places.

   That is not hypothetical: it left the Server drop-down on the DX Cluster page
   empty while the DX Cluster window listed servers out of the same
   TRCLUSTER.DAT (NY4I, 2026-08-30). One asked ParamStr(0) and did not find the
   file; the other asked the working directory and did. Nothing failed, nothing
   logged, and the two disagreed in silence.

   `uAppPaths` settled it -- DataFilePath / SettingsFilePath / LogFilePath --
   and the six ParamStr(0) sites were repointed at it. THIS LINT IS WHAT KEEPS
   THEM REPOINTED. A raw path rule is one line, it looks obviously correct in
   review, and it comes back the moment someone needs a file in a hurry.

   IT MATTERS MORE OFF WINDOWS, which is the whole reason uAppPaths is a unit
   and not a constant. On macOS the binary sits in App.app/Contents/MacOS while
   read-only data belongs in Contents/Resources, and the bundle is code-signed,
   so writing beside the binary breaks the signature. On Linux the binary is in
   /usr/bin and its data in /usr/share. A raw ParamStr(0) compiles perfectly on
   both and is wrong on both.

   WHAT IS ALLOWED, and why each one:

     src\uAppPaths.pas      OWNS both rules. It is the one place that is
                            supposed to name them.

     src\uProgramMain.pas   Initialises the legacy TR4W_PATH_NAME global from
                            GetCurrentDirectoryA. That global still has ~38 call
                            sites; until they move to uAppPaths this assignment
                            is the definition of the working-directory rule and
                            deleting it would break every one of them. Remove
                            this exemption when TR4W_PATH_NAME goes.

   Comments and string literals are NOT matched -- the rationale for uAppPaths
   is itself written in prose that names both rules, and a lint that fires on
   its own explanation gets switched off.

.PARAMETER SourceDir
   Root of the Pascal sources (tr4w\src).

.PARAMETER FailOnViolation
   Default True. Pass -FailOnViolation:$false to report without failing.
#>

param(
   [string] $SourceDir = (Join-Path (Split-Path $PSScriptRoot -Parent) 'src'),
   [bool]   $FailOnViolation = $true
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $SourceDir))
   {
   Write-Output "Lint-AppPaths: source directory not found: $SourceDir"
   exit 1
   }

# The IDE's backup copies are not source -- the same exclusion every other lint
# uses, from one definition.
$exclusions = Join-Path $PSScriptRoot 'Get-ScanExclusions.ps1'
if (Test-Path -LiteralPath $exclusions) { . $exclusions }

# BY FILE NAME, not by path, so a clone anywhere matches.
$allowed = @('uAppPaths.pas', 'uProgramMain.pas')

# ParamStr(0) is only a path rule when a directory is taken from it. ParamStr(0)
# on its own is a legitimate thing to log or show, and several units do.
$patterns = @(
   @{ Name = 'ExtractFilePath(ParamStr(0))'; Rx = 'ExtractFilePath\s*\(\s*ParamStr\s*\(\s*0\s*\)' }
   @{ Name = 'ExtractFileDir(ParamStr(0))';  Rx = 'ExtractFileDir\s*\(\s*ParamStr\s*\(\s*0\s*\)' }
   @{ Name = 'GetCurrentDir';                Rx = '\bGetCurrentDir\b' }
   @{ Name = 'GetCurrentDirectory';          Rx = '\bGetCurrentDirectory[AW]?\b' }
)

$files = Get-ChildItem -LiteralPath $SourceDir -Recurse -File |
         Where-Object { $_.Extension -match '^\.(pas|PAS|lpr|inc)$' }

if (Get-Command Test-Tr4wScannable -ErrorAction SilentlyContinue)
   {
   $files = $files | Where-Object { Test-Tr4wScannable $_.FullName }
   }

$violations = New-Object System.Collections.Generic.List[object]
$allowedHits = 0
$scanned     = 0

foreach ($f in $files)
   {
   $scanned++
   $text  = Get-Content -LiteralPath $f.FullName -Raw
   $lines = $text -split "`r?`n"

   # Block-comment state carried across lines, because the rationale for this
   # rule is written inside one.
   $inBrace = $false
   $inParen = $false

   for ($i = 0; $i -lt $lines.Count; $i++)
      {
      $line = $lines[$i]

      # Strip comments and string literals before matching. Done character-wise
      # rather than by regex: '{' inside a string and a quote inside a comment
      # both occur in this tree, and either one breaks a naive strip.
      $code = New-Object System.Text.StringBuilder
      $inStr = $false
      for ($c = 0; $c -lt $line.Length; $c++)
         {
         $ch   = $line[$c]
         $next = if ($c + 1 -lt $line.Length) { $line[$c + 1] } else { [char]0 }

         if ($inBrace) { if ($ch -eq '}') { $inBrace = $false }; continue }
         if ($inParen) { if ($ch -eq '*' -and $next -eq ')') { $inParen = $false; $c++ }; continue }
         if ($inStr)   { if ($ch -eq "'") { $inStr = $false }; continue }

         if ($ch -eq "'")                      { $inStr = $true;   continue }
         if ($ch -eq '{')                      { $inBrace = $true; continue }
         if ($ch -eq '(' -and $next -eq '*')   { $inParen = $true; $c++; continue }
         if ($ch -eq '/' -and $next -eq '/')   { break }

         [void]$code.Append($ch)
         }

      $stripped = $code.ToString()
      if ($stripped.Trim().Length -eq 0) { continue }

      foreach ($p in $patterns)
         {
         if ($stripped -match $p.Rx)
            {
            if ($allowed -contains $f.Name)
               {
               $allowedHits++
               }
            else
               {
               $violations.Add([pscustomobject]@{
                  File = $f.FullName.Substring($SourceDir.Length).TrimStart('\')
                  Line = $i + 1
                  What = $p.Name
                  Text = $stripped.Trim()
               })
               }
            }
         }
      }
   }

if ($violations.Count -gt 0)
   {
   Write-Output "Lint-AppPaths: $($violations.Count) site(s) resolve a path without uAppPaths."
   Write-Output ''
   foreach ($v in $violations)
      {
      Write-Output ("  {0}({1}): {2}" -f $v.File, $v.Line, $v.What)
      Write-Output ("      {0}" -f $v.Text)
      }
   Write-Output ''
   Write-Output '  Fix: ask uAppPaths for the path, choosing by the KIND of file --'
   Write-Output '    DataFilePath     shipped and read-only (CTY.DAT, TRMASTER.DTA, dom\)'
   Write-Output '    SettingsFilePath writable per-operator (tr4w.json, tr4w.ini, tr4w.pos)'
   Write-Output '    LogFilePath      writable and possibly large (tr4w.log, contest logs)'
   Write-Output ''
   Write-Output '  The three are the same directory on Windows and three different ones'
   Write-Output '  everywhere else, so the choice is not cosmetic even though it looks it.'
   if ($FailOnViolation) { exit 1 }
   exit 0
   }

# A FLOOR. Zero violations is only good news if this lint could have found one.
# If uAppPaths stops naming the rules it owns, the scan has moved or the unit
# has been rewritten, and a clean line here would be false comfort --
# Lint-RadioRegistry once reported "0 registrations, no collisions" and PASSED.
if ($scanned -eq 0 -or $allowedHits -eq 0)
   {
   Write-Output 'Lint-AppPaths: refusing to pass -- nothing to judge.'
   Write-Output "  files scanned                     : $scanned"
   Write-Output "  path rules seen in the owning units: $allowedHits"
   Write-Output '  Both should be non-zero: uAppPaths.pas names ExtractFilePath(ParamStr(0))'
   Write-Output '  and GetCurrentDir in its own bodies, and uProgramMain.pas initialises'
   Write-Output '  TR4W_PATH_NAME from GetCurrentDirectoryA. If that changed, update this'
   Write-Output '  lint; if uAppPaths is gone, delete it.'
   exit 1
   }

Write-Output ("Lint-AppPaths: {0} file(s) scanned, {1} path rule(s) in uAppPaths/uProgramMain where they belong; no raw path resolution elsewhere." -f $scanned, $allowedHits)
exit 0
