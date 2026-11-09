<#
.SYNOPSIS
   Fails the build when a URL appears in the tree that build\referenced-urls.txt
   does not list, or lists one the tree no longer carries. Offline.

.DESCRIPTION
   WHY THIS EXISTS (issue 248). Check-ReferencedUrls.ps1 probes every URL TR4W
   references before a release. A probe is only as good as its list, and a list
   kept from memory goes stale the day someone adds an endpoint. This is the
   half that needs no network: every URL literal under src, tools, build,
   tr4wserver and tr4w.lpr must be in the data file, so a new endpoint cannot
   be added without being listed (and therefore probed).

   Both directions fail, the way a pin does here: a URL in the tree and not in
   the table, and a table row whose URL is nowhere in the tree (STALE).

   FAIL-CLOSED: a table that cannot be read, a table or a scan under its floor,
   or a rule violation (see ReferencedUrls.psm1; supercheckhistory.com must be
   probe 'skip') all exit 1. A built-in fixture runs first.

   .\Lint-ReferencedUrls.ps1              # the tree (Run-Lints passes -SourceDir)
   .\Lint-ReferencedUrls.ps1 -SelfTest    # the fixture only
#>
param(
   [string] $SourceDir,
   [switch] $SelfTest
)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'ReferencedUrls.psm1') -Force
. (Join-Path $PSScriptRoot 'Get-ScanExclusions.ps1')   # Test-Tr4wScannable

if (-not $SourceDir)
   {
   $SourceDir = Split-Path -Parent $PSScriptRoot
   }

$FLOOR_FOUND     = 40   # distinct URLs the scan must find
$FLOOR_ENTRIES   = 40   # rows the table must hold
$FLOOR_ENDPOINTS = 12   # of them, kind endpoint

# The three files that define the thing carry fixture URLs on purpose.
$OWN_FILES = @('Lint-ReferencedUrls.ps1', 'Check-ReferencedUrls.ps1', 'ReferencedUrls.psm1')
$EXTENSIONS = @('.pas', '.inc', '.lpr', '.lfm', '.ps1', '.psm1', '.sh', '.py', '.cmd', '.nsi')

function Invoke-SelfTest
{
   $ok = $true

   # 1. The extractor: what is a URL, and what is trimmed off it.
   $text = "see https://a.example.org/x/y. and (http://b.example.net/p?q=1); " +
           "'https://c.example.com/dl/?' {https://d.example.com/z} " +
           "http://... https://host/path http://x https://e.example.com/`$(`$m[1]) " +
           "https://a.example.org/x/y"
   $want = @('https://a.example.org/x/y', 'http://b.example.net/p?q=1', 'https://c.example.com/dl/',
             'https://d.example.com/z', 'https://e.example.com/')
   $got = @(Find-UrlLiteralsInText $text)
   if (($got -join '|') -ne ($want -join '|'))
      {
      Write-Host ("  self-test: extractor expected [{0}] got [{1}]" -f ($want -join ' '), ($got -join ' '))
      $ok = $false
      }

   # 2. The rules: one good row, then a row for each way a table can be wrong.
   function Row($u, $k, $p, $o, $a) { [pscustomobject] @{ Url = $u; Kind = $k; Probe = $p; Owner = $o; Arg = $a; Allow = ''; Line = 1 } }
   $good = @(Row 'https://a.example.org/' 'endpoint' 'head' 'uX' '')
   if (@(Test-UrlTableRules $good).Count -ne 0)
      {
      Write-Host '  self-test: a good table was rejected'
      $ok = $false
      }
   $bad = @(
      (Row 'https://a.example.org/' 'endpoint' 'head' 'uX' ''),
      (Row 'https://a.example.org/' 'endpoint' 'head' 'uX' ''),             # duplicate
      (Row 'https://b.example.org/' 'bogus'    'head' 'uX' ''),             # kind
      (Row 'https://c.example.org/' 'endpoint' 'nope' 'uX' ''),             # probe
      (Row 'https://d.example.org/' 'endpoint' 'head' ''   ''),             # owner
      (Row 'https://e.example.org/' 'endpoint' 'skip' 'uX' ''),             # skip, no reason
      (Row 'https://f.example.org/' 'endpoint' 'none' 'uX' ''),             # endpoint never 'none'
      (Row 'https://g.example.org/' 'template' 'sample' 'uX' ''),           # sample without URL
      (Row 'https://supercheckhistory.com/x' 'endpoint' 'head' 'uX' ''),    # the never-contact host
      (Row 'not a url' 'doc' 'head' 'uX' ''))                               # not a URL
   $nErr = @(Test-UrlTableRules $bad).Count
   if ($nErr -ne 9)
      {
      Write-Host "  self-test: expected 9 rule errors from the bad table, got $nErr"
      $ok = $false
      }
   return $ok
}

if (-not (Invoke-SelfTest))
   {
   Write-Output 'Lint-ReferencedUrls: SELF-TEST FAILED -- refusing to judge the tree.'
   exit 1
   }
if ($SelfTest)
   {
   Write-Output 'Lint-ReferencedUrls: self-test OK.'
   exit 0
   }

$tablePath = Join-Path $PSScriptRoot 'referenced-urls.txt'
try
   {
   $entries = @(Read-UrlTable $tablePath)
   }
catch
   {
   Write-Output "Lint-ReferencedUrls: $($_.Exception.Message)"
   exit 1
   }

$roots = @('src', 'tools', 'build', 'tr4wserver') | ForEach-Object { Join-Path $SourceDir $_ }
if (-not (Test-Path -LiteralPath (Join-Path $SourceDir 'src\MainUnit.pas')))
   {
   Write-Output "Lint-ReferencedUrls: src\MainUnit.pas is not under '$SourceDir' -- wrong -SourceDir? Refusing to report a pass."
   exit 1
   }

$files = New-Object System.Collections.ArrayList
foreach ($r in $roots)
   {
   if (Test-Path -LiteralPath $r)
      {
      foreach ($f in (Get-ChildItem -LiteralPath $r -Recurse -File -ErrorAction SilentlyContinue))
         {
         if (($EXTENSIONS -contains $f.Extension.ToLowerInvariant()) -and
             ($OWN_FILES -notcontains $f.Name) -and
             ($f.Length -lt 5MB) -and
             (Test-Tr4wScannable $f.FullName))
            {
            [void] $files.Add($f)
            }
         }
      }
   }
$lpr = Join-Path $SourceDir 'tr4w.lpr'
if (Test-Path -LiteralPath $lpr)
   {
   [void] $files.Add((Get-Item -LiteralPath $lpr))
   }

$found = @{}      # url -> first "relative path:line"
foreach ($f in $files)
   {
   $text = [IO.File]::ReadAllText($f.FullName)
   foreach ($u in (Find-UrlLiteralsInText $text))
      {
      if (-not $found.ContainsKey($u))
         {
         $idx  = $text.IndexOf($u)
         $line = 1 + ($text.Substring(0, $idx) -split "`n").Count - 1
         $found[$u] = ('{0}:{1}' -f $f.FullName.Substring($SourceDir.TrimEnd('\').Length).TrimStart('\'), $line)
         }
      }
   }

$problems = New-Object System.Collections.ArrayList
foreach ($e in @(Test-UrlTableRules $entries))
   {
   [void] $problems.Add("  table: $e")
   }
$listed = @{}
foreach ($e in $entries)
   {
   $listed[$e.Url] = $true
   }
foreach ($u in ($found.Keys | Sort-Object))
   {
   if (-not $listed.ContainsKey($u))
      {
      [void] $problems.Add("  UNLISTED  $u   ($($found[$u]))")
      }
   }
foreach ($e in $entries)
   {
   if (-not $found.ContainsKey($e.Url))
      {
      [void] $problems.Add("  STALE     $($e.Url)   (table line $($e.Line); nowhere in the tree)")
      }
   }

$nEndpoints = @($entries | Where-Object { $_.Kind -eq 'endpoint' }).Count
if ($found.Count -lt $FLOOR_FOUND)
   {
   [void] $problems.Add("  scan found only $($found.Count) URL(s), floor $FLOOR_FOUND -- is the scan reading the tree?")
   }
if ($entries.Count -lt $FLOOR_ENTRIES)
   {
   [void] $problems.Add("  table holds only $($entries.Count) row(s), floor $FLOOR_ENTRIES")
   }
if ($nEndpoints -lt $FLOOR_ENDPOINTS)
   {
   [void] $problems.Add("  table holds only $nEndpoints endpoint row(s), floor $FLOOR_ENDPOINTS")
   }

if ($problems.Count -gt 0)
   {
   $problems | ForEach-Object { Write-Output $_ }
   Write-Output ("Lint-ReferencedUrls: {0} problem(s). Add a new URL to build\referenced-urls.txt" -f $problems.Count)
   Write-Output '  (kind endpoint if the program contacts it) or delete a stale row.'
   exit 1
   }

Write-Output ("Lint-ReferencedUrls: {0} file(s), {1} URL(s) found, {2} listed ({3} endpoint); table and tree agree." -f $files.Count, $found.Count, $entries.Count, $nEndpoints)
exit 0
