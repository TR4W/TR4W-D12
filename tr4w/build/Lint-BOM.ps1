<#
.SYNOPSIS
   Gates the build on the UTF-8 BOM state of Pascal sources.

.DESCRIPTION
   THE FAILURE THIS EXISTS FOR.  On 2026-08-20 six Pascal files silently lost
   their BOM in one session -- VC.pas, MainUnit.pas (twice), tr4w_unit_tests.lpr,
   HELP.PAS and LogCfg.pas -- between an editor save and a read-modify-write
   script. EXACTLY ONE produced a diagnostic:

      VC.pas(259,19) Fatal: It is not possible to include a file that starts
      with an UTF-8 BOM in a module that uses a different code page

   The other five were silent, and were only found by diffing the first three
   bytes against git HEAD by hand. `Lint-LineEndings` already gates CRLF; nothing
   gated the BOM, even though CLAUDE.md names it as a silent-corruption trap.

   WHY A BOM MATTERS HERE.  A no-BOM file is read in the build machine's ANSI
   codepage. In a COMMENT that is harmless -- which is why 44 files in this tree
   are non-ASCII UTF-8 with no BOM and compile perfectly. In a STRING LITERAL it
   corrupts the text, and differently on differently-configured machines. That is
   the rule behind CLAUDE.md's "src\lang\*.pas are UTF-8 *with a BOM* and must
   stay that way".

   THREE RULES, and the split between hard errors and a pinned set is deliberate.

   RULE A (hard) -- A BOM THAT LIES.  The file starts with EF BB BF, declaring
   UTF-8, but the bytes after it are not valid UTF-8. Whatever reads it is
   guaranteed to be wrong. One known exception, listed below with its reason.

   RULE B (hard) -- INCLUDE-CHAIN MISMATCH.  A file with no BOM that `{$I}`s a
   file WITH one. This is the exact VC.pas fatal above. Zero occurrences today,
   so it can fail closed.

   RULE C (pinned set) -- THE BOM SET DOES NOT DRIFT.  73 files carry a BOM; the
   list is checked in beside this script. Losing one FAILS. Gaining one that is
   not listed also fails, so the list cannot quietly go stale -- the fix is to
   add it deliberately with `-UpdateManifest`, which is a reviewable diff.

   WHY A PINNED SET RATHER THAN A DERIVED RULE.  The obvious rule -- "any file
   with non-ASCII must have a BOM" -- was measured before it was written, and it
   is WRONG: 44 files would fail on day one because their non-ASCII is in
   comments. Narrowing it to "non-ASCII in a STRING LITERAL" still leaves 13
   pre-existing violations (em-dashes in log messages, a Cyrillic button caption
   in uCbrSum.pas). A gate that cannot pass on the day it is written cannot be
   wired into the build, and those 13 are a separate piece of work. The pinned
   set catches the thing that actually went wrong -- an edit CHANGING a file's
   BOM state -- with no false positives at all.

.PARAMETER SourceDir
   Root to scan. Defaults to the tr4w tree containing this script.

.PARAMETER UpdateManifest
   Rewrite the pinned set from what is on disk. Use ONLY when a BOM change is
   intended, and commit the manifest diff with the change that caused it.

.EXAMPLE
   .\build\Lint-BOM.ps1
   .\build\Lint-BOM.ps1 -UpdateManifest     # after a deliberate BOM change
#>

param(
   [string] $SourceDir,
   [switch] $UpdateManifest
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Get-ScanExclusions.ps1')   # Test-Tr4wScannable -- IDE backup dirs are not source


Import-Module (Join-Path $PSScriptRoot 'PascalSource.psm1') -Force

if (-not $SourceDir) {
   $SourceDir = Split-Path -Parent $PSScriptRoot
}

# NORMALISE, and this is not defensive padding. Run-Lints passes
# $Tr4wDir = (Join-Path $PSScriptRoot '..'), i.e. "...\tr4w\build\..", which is a
# perfectly good path to open a file with but is NOT a prefix of the FullName
# that Get-ChildItem returns. Get-RelPath below trims by LENGTH, so the
# unnormalised form silently produced nonsense relative paths and the lint threw.
# It passed standalone and failed only under Run-Lints -- which is the argument
# for proving a gate fires the way the build actually calls it.
$SourceDir = [System.IO.Path]::GetFullPath($SourceDir).TrimEnd('\', '/')

if (-not (Test-Path -LiteralPath $SourceDir)) {
   Write-Output ("Lint-BOM: no such directory: {0}" -f $SourceDir)
   exit 2
}

$ManifestPath = Join-Path $PSScriptRoot 'bom-manifest.txt'

# RULE A's one exception. src\lang\tr4w_consts_chn.pas carries a BOM over bytes
# that are not valid UTF-8. CHN was decided out (CLAUDE.md, "POL and CHN were
# already decided-out") and the compile-time language matrix is not built by
# anything, so the file is inert -- but deleting or re-encoding it is a decision
# about the I18N work, not something a lint should force. Listed here so it is a
# known exception rather than an unexplained pass.
$RuleAExceptions = @(
   'src\lang\tr4w_consts_chn.pas'
)

$BOM = [byte[]](0xEF, 0xBB, 0xBF)

function Get-RelPath
{
   param([string] $Full)
   $r = $Full.Substring($SourceDir.Length).TrimStart('\', '/')
   return $r.Replace('/', '\')
}

function Test-HasBom
{
   param([byte[]] $Bytes)
   if ($Bytes.Length -lt 3) { return $false }
   return ($Bytes[0] -eq $BOM[0]) -and ($Bytes[1] -eq $BOM[1]) -and ($Bytes[2] -eq $BOM[2])
}

function Test-IsValidUtf8
{
   param([byte[]] $Bytes, [int] $Offset)

   # Strict decoder: throwOnInvalidBytes, so an ANSI high byte raises rather
   # than silently becoming U+FFFD. That silent substitution is what makes this
   # class of bug invisible in the first place.
   $enc = New-Object System.Text.UTF8Encoding($false, $true)
   try {
      [void]$enc.GetString($Bytes, $Offset, $Bytes.Length - $Offset)
      return $true
   }
   catch {
      return $false
   }
}

# ---------------------------------------------------------------- the file set

# Get-TR4WPascalFiles is the shared list every lint uses (.pas/.dpr/.dpk/.inc,
# vendored and build output excluded). It does NOT carry .lpr -- one file,
# build\lintlfm\lintlfm.lpr -- and a BOM rule should not have a hole in it, so
# that extension is unioned in here rather than by widening the shared helper
# and shifting every other lint's counts.
$files = @(Get-TR4WPascalFiles -Root $SourceDir)
$lpr = @(Get-ChildItem -LiteralPath $SourceDir -Recurse -File -Filter '*.lpr' -ErrorAction SilentlyContinue | Where-Object { Test-Tr4wScannable $_.FullName } |
         Where-Object { $_.FullName -notmatch '\\build-out\\|\\backup' })
$files = @($files) + @($lpr)

$info = @{}
foreach ($f in $files) {
   $bytes = [System.IO.File]::ReadAllBytes($f.FullName)
   $info[$f.FullName] = [pscustomobject]@{
      Rel   = Get-RelPath $f.FullName
      Bytes = $bytes
      Bom   = Test-HasBom $bytes
   }
}

$withBom = @($info.Values | Where-Object { $_.Bom } | Select-Object -ExpandProperty Rel | Sort-Object)

# ------------------------------------------------------------- -UpdateManifest

if ($UpdateManifest) {
   $header = @(
      '# Files that MUST carry a UTF-8 BOM. Checked by build\Lint-BOM.ps1.',
      '#',
      '# This is a PINNED SET, not a derived rule: an edit that drops a BOM is',
      '# silent, and on 2026-08-20 six files lost one in a single session with',
      '# only one of them producing a compiler diagnostic.',
      '#',
      '# Regenerate with:  .\build\Lint-BOM.ps1 -UpdateManifest',
      '# Do that ONLY for an intended BOM change, and commit the diff with it.',
      ''
   )
   $out = $header + $withBom
   [System.IO.File]::WriteAllLines($ManifestPath, $out, (New-Object System.Text.UTF8Encoding($false)))
   Write-Output ("Lint-BOM: manifest rewritten -- {0} file(s) pinned." -f $withBom.Count)
   exit 0
}

$violations = New-Object System.Collections.ArrayList

# -------------------------------------------------------- RULE A: a lying BOM

foreach ($i in $info.Values) {
   if (-not $i.Bom) { continue }
   if ($RuleAExceptions -contains $i.Rel) { continue }
   if (-not (Test-IsValidUtf8 $i.Bytes 3)) {
      [void]$violations.Add(("{0}: has a UTF-8 BOM but the bytes after it are NOT valid UTF-8. The BOM is lying about the encoding; anything that reads this file is wrong." -f $i.Rel))
   }
}

# ------------------------------------------- RULE B: include-chain BOM mismatch

$byLower = @{}
foreach ($i in $info.Values) { $byLower[$i.Rel.ToLowerInvariant()] = $i }

# SINGLE-quoted, and that is not a style choice. In a double-quoted string
# PowerShell expands `$I` -- and `$i` is the loop variable a few lines below, so
# the pattern became "\{\@{Rel=src\uIO.pas; Bytes=System.Byte[]...}" and the cast
# to [regex] threw "Insufficient hexadecimal digits". A `$` in a regex must be
# quoted single, always.
$incRe = [regex]'(?i)\{\$I(?:NCLUDE)?\s+''?([^}''\s]+)''?\s*\}'

foreach ($i in $info.Values) {
   if ($i.Bom) { continue }        # an includer WITH a BOM is fine

   $enc = New-Object System.Text.UTF8Encoding($false, $false)
   $text = $enc.GetString($i.Bytes)

   foreach ($m in $incRe.Matches($text)) {
      $target = $m.Groups[1].Value
      $dir = Split-Path -Parent (Join-Path $SourceDir $i.Rel)
      $cand = [System.IO.Path]::GetFullPath((Join-Path $dir $target))
      $rel = (Get-RelPath $cand).ToLowerInvariant()
      if (-not $byLower.ContainsKey($rel)) { continue }
      if ($byLower[$rel].Bom) {
         [void]$violations.Add(("{0}: has NO BOM but includes {1}, which HAS one. FPC refuses this -- 'not possible to include a file that starts with an UTF-8 BOM in a module that uses a different code page'. Give the includer a BOM, or take it off the include." -f $i.Rel, $byLower[$rel].Rel))
      }
   }
}

# --------------------------------------------------- RULE C: the set is pinned

if (-not (Test-Path -LiteralPath $ManifestPath)) {
   Write-Output ("Lint-BOM: no manifest at {0}." -f $ManifestPath)
   Write-Output "          Create it once with:  .\build\Lint-BOM.ps1 -UpdateManifest"
   exit 1
}

$pinned = @(Get-Content -LiteralPath $ManifestPath |
            Where-Object { $_.Trim() -ne '' -and -not $_.TrimStart().StartsWith('#') } |
            ForEach-Object { $_.Trim() })

$pinnedSet = @{}
foreach ($p in $pinned) { $pinnedSet[$p.ToLowerInvariant()] = $true }
$actualSet = @{}
foreach ($p in $withBom) { $actualSet[$p.ToLowerInvariant()] = $true }

foreach ($p in $pinned) {
   if (-not $actualSet.ContainsKey($p.ToLowerInvariant())) {
      # The file may also simply be gone -- say which, because "lost its BOM"
      # and "was deleted" need different fixes.
      $full = Join-Path $SourceDir $p
      if (Test-Path -LiteralPath $full) {
         [void]$violations.Add(("{0}: LOST ITS UTF-8 BOM. It is pinned in build\bom-manifest.txt. An editor almost certainly rewrote it -- in Notepad++ the status bar reads 'UTF-8' where it should read 'UTF-8-BOM'. Restore it, or update the manifest if the removal was intended." -f $p))
      }
      else {
         [void]$violations.Add(("{0}: pinned in build\bom-manifest.txt but the file no longer exists. Re-run with -UpdateManifest if it was deliberately deleted." -f $p))
      }
   }
}

foreach ($p in $withBom) {
   if (-not $pinnedSet.ContainsKey($p.ToLowerInvariant())) {
      [void]$violations.Add(("{0}: has a UTF-8 BOM but is not pinned in build\bom-manifest.txt. If that is intended, re-run with -UpdateManifest and commit the manifest diff alongside." -f $p))
   }
}

# ---------------------------------------------------------------------- report

if ($violations.Count -gt 0) {
   Write-Output ("Lint-BOM: {0} violation(s)." -f $violations.Count)
   Write-Output ''
   foreach ($v in $violations) {
      Write-Output ("  " + $v)
      Write-Output ''
   }
   exit 1
}

Write-Output ("Lint-BOM: {0} source file(s) checked, {1} BOM(s) pinned and intact." -f $files.Count, $withBom.Count)
exit 0
