<#
.SYNOPSIS
   Is tr4w\res\tr4w_languages.res made from the catalogues that are on disk NOW?
   And if not, make it so.

.DESCRIPTION
   WHY THIS EXISTS. tr4w_languages.res is a TRACKED binary that tr4w.lpr and the
   unit-test .lpr link with {$R}. It is generated from i18n\tr4w_<lang>.po by
   Make-LanguageRes.ps1, and until 2026-10-16 NOTHING RAN THAT SCRIPT. The .res
   was last built on 2026-09-21; two catalogue commits after it (2026-10-01 and
   2026-10-02) never reached any binary, on any platform, and no gate said so.

   THE TRIGGER IS CONTENT, NOT MTIME (NY4I: "have the build regenerate it
   automatically"). git sets file times at checkout, so "a .po is newer than the
   .res" is wrong both ways: a fresh clone is stale or current by accident of
   the checkout order. Instead the .res carries a STAMP, tr4w_languages.res.inputs:
   one sha256 per input file, written by Make-LanguageRes.ps1 beside the output.
   The build recomputes the same list from the tree and compares. Equal means
   the .res IS what the generator would produce from these inputs; anything else
   regenerates.

   WHY A STAMP AND NOT "REGENERATE EVERY BUILD". Measured 2026-10-16: the
   generator takes ~3 s and its output is byte-identical for identical inputs
   (two runs, same sha256), so regenerating every build WOULD be correct and
   would not dirty the tracked file. But the Linux and macOS builds cannot run
   it (no PowerShell guaranteed, and fpcres is a Windows-hosted step), and they
   need an answer to "is the committed .res current?" that does not need the
   generator. The stamp is that answer, and check-language-res.sh reads the SAME
   stamp. One definition of "current", two readers.

   WHAT IS HASHED. Every i18n\tr4w_*.po, Make-LanguageRes.ps1 and THIS file (the
   generator and the hashing rule are inputs too: change either and the output
   may change). Each file is hashed with CR bytes removed, so a checkout that
   converts line endings does not make a clone look stale. Lines are
   "<sha256>  <repo-relative path>", the order is ordinal by path, and
   check-language-res.sh computes the identical list with sha256sum.

   WHAT IS NOT HASHED, deliberately: the Lazarus lclstrconsts.<lang>.po files the
   generator also embeds. They belong to the machine's Lazarus install, not to
   this repository, so hashing them would make the same commit stamp differently
   on two correctly-configured machines. A Lazarus upgrade therefore does not
   regenerate by itself; run Make-LanguageRes.ps1 by hand after one.

   THE MODE LINE. The build always embeds unreviewed (fuzzy) entries. A .res made
   with -ReviewedOnly stamps "mode  reviewed-only", which does not match what the
   build expects, so the next build puts the default back. To make reviewed-only
   permanent, change the default here AND in check-language-res.sh.
#>

# The mode the BUILD produces. Make-LanguageRes.ps1 writes the same words.
$script:LanguageResModeDefault = 'fuzzy-included'

function Get-Tr4wFileHashNoCR
   {
   <# sha256 of a file with every CR byte removed. Latin-1 maps bytes to chars
      one-to-one, so the round trip through a string cannot alter anything but
      the CRs. #>
   param([string] $Path)

   $latin1 = [Text.Encoding]::GetEncoding(28591)
   $text   = $latin1.GetString([IO.File]::ReadAllBytes($Path)).Replace("`r", '')
   $sha    = [Security.Cryptography.SHA256]::Create()
   try
      {
      $hash = $sha.ComputeHash($latin1.GetBytes($text))
      }
   finally
      {
      $sha.Dispose()
      }
   return (($hash | ForEach-Object { $_.ToString('x2') }) -join '')
   }

function Get-Tr4wLanguageManifest
   {
   <# The list of inputs, one "<sha256>  <path>" line each, preceded by the mode
      line. This is the ONE definition; the stamp is this text and the check
      compares against it. #>
   param([string] $Repo, [string] $Mode = $script:LanguageResModeDefault)

   $rel = New-Object System.Collections.Generic.List[string]
   foreach ($po in (Get-ChildItem -Path (Join-Path $Repo 'i18n') -Filter 'tr4w_*.po'))
      {
      $rel.Add('i18n/' + $po.Name)
      }
   $rel.Sort([StringComparer]::Ordinal)
   $rel.Add('tr4w/build/Make-LanguageRes.ps1')
   $rel.Add('tr4w/build/LanguageResStamp.ps1')

   $lines = New-Object System.Collections.Generic.List[string]
   $lines.Add("mode  $Mode")
   foreach ($r in $rel)
      {
      $hash = Get-Tr4wFileHashNoCR (Join-Path $Repo ($r -replace '/', '\'))
      $lines.Add("$hash  $r")
      }
   return $lines.ToArray()
   }

function Write-Tr4wLanguageStamp
   {
   param([string] $Repo, [string] $ResPath, [string] $Mode)

   $header = '# tr4w_languages.res was generated from exactly these inputs (sha256, CRs removed).',
             '# Written by Make-LanguageRes.ps1; read by the build. See build\LanguageResStamp.ps1.'
   $body   = $header + (Get-Tr4wLanguageManifest -Repo $Repo -Mode $Mode)
   [IO.File]::WriteAllText("$ResPath.inputs", (($body -join "`n") + "`n"),
                           (New-Object Text.UTF8Encoding($false)))
   }

function Test-Tr4wLanguageRes
   {
   <# $null when the .res is current; otherwise the reason it is not. #>
   param([string] $Repo)

   $res   = Join-Path $Repo 'tr4w\res\tr4w_languages.res'
   $stamp = "$res.inputs"
   if (-not (Test-Path $res))   { return 'tr4w_languages.res is missing' }
   if (-not (Test-Path $stamp)) { return 'tr4w_languages.res.inputs is missing' }

   $have = @(Get-Content -Path $stamp | Where-Object { $_ -ne '' -and -not $_.StartsWith('#') })
   $want = @(Get-Tr4wLanguageManifest -Repo $Repo)
   for ($i = 0; $i -lt [math]::Max($have.Count, $want.Count); $i++)
      {
      $h = if ($i -lt $have.Count) { $have[$i].TrimEnd() } else { '(absent)' }
      $w = if ($i -lt $want.Count) { $want[$i] } else { '(absent)' }
      if ($h -ne $w)
         {
         $name = ($w -split '  ', 2)[-1]
         return "inputs changed since the .res was built: $name"
         }
      }
   if ((Get-Item $res).Length -eq 0) { return 'tr4w_languages.res is empty' }
   return $null
   }

function Sync-Tr4wLanguageRes
   {
   <# Called by every build that links the .res. Regenerates when the stamp does
      not match, and THROWS if it cannot -- never leaves a stale .res to be
      linked silently. #>
   param([string] $Repo)

   $why = Test-Tr4wLanguageRes -Repo $Repo
   if ($null -eq $why)
      {
      Write-Host '  language catalogues: tr4w_languages.res is current'
      return
      }

   Write-Host "  language catalogues: regenerating tr4w_languages.res ($why)"
   $global:LASTEXITCODE = 0
   & (Join-Path $PSScriptRoot 'Make-LanguageRes.ps1') -Repo $Repo -Quiet | ForEach-Object { Write-Host "    $_" }
   if ($LASTEXITCODE -ne 0)
      {
      throw "Make-LanguageRes.ps1 failed (exit $LASTEXITCODE); tr4w_languages.res is STALE and was not linked"
      }

   $why = Test-Tr4wLanguageRes -Repo $Repo
   if ($null -ne $why)
      {
      throw "Make-LanguageRes.ps1 ran but the .res is still not current ($why)"
      }
   Write-Host '  language catalogues: regenerated -- commit tr4w\res\tr4w_languages.res and .inputs together'
   }
