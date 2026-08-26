<#
.SYNOPSIS
   Fails the build when a source file the RAD Studio IDE co-owns has line
   endings that are not exactly CRLF -- a bare LF, or a stray CR.
.DESCRIPTION
   .gitattributes governs what git WRITES on checkout and STORES on commit. It
   cannot stop a tool -- an editor, a script, an AI assistant -- from writing a
   file with LF endings straight into the working tree, and git will not
   rewrite it on the next checkout because the content already normalises to
   the same blob. So the wrong endings can sit in the tree indefinitely.

   That is not cosmetic here. The IDE's form designer inserts code by BYTE
   OFFSET. Against an LF file every line boundary is off by one byte, and
   adding an event handler splices the new declaration into the middle of an
   identifier. On 2026-08-05 that produced, in one save:

       procedure btnCloseClick(Sende
     procedure FormCreate(Sender: TObject);r: TObject);

   Nothing was deleted -- the text landed at the wrong place. The unit no
   longer compiled and the damage read like file corruption. 150 tracked .pas
   files were sitting in the tree with LF endings at the time, VC.pas included,
   each one primed for the same splice.

   This lint is the tripwire: a bad file is caught by the build, before the
   IDE can splice it.

   THE MIRROR DEFECT: A STRAY CR.  Until 2026-08-26 this lint counted only
   bare LF, so it was blind to the opposite corruption and reported "all
   CRLF" over four form units that were not.  The shape is CR CR LF, and it
   is self-perpetuating:

       working file   ...HandleClose<CR><CR><LF>
       git add        CRLF->LF on the trailing pair, leaving <CR><LF> IN THE BLOB
       checkout       LF->CRLF on every LF, restoring <CR><CR><LF>

   So `git status` reports clean, the file round-trips unchanged, and every
   fresh clone reproduces it.  It arrives when generated content already
   carrying a CR is written through a path that then appends CRLF -- which is
   how uHamScoreForm, uPostScoresForm and uIntercomForm (.pas and .lfm) were
   committed on 2026-08-25 and went unnoticed for a day.

   It matters for the same reason a bare LF does: byte offsets.  A stray CR
   shifts every offset after it by one, in a tree where the designer inserts
   by byte offset.
.PARAMETER SourceDir
   Root directory to scan. Scanned recursively.
.PARAMETER Fix
   Rewrite offending files to CRLF instead of failing. Off by default: a lint
   that silently edits source is not a lint. Intended for the one-off cleanup.
.PARAMETER SelfTest
   Prove BOTH defects are detected and repaired, then exit. No fixture tree in
   the repo to drift; the cases live with the code that must catch them.
.OUTPUTS
   One line per offending file: <file>: <n> bare LF, <n> bare CR
   Exit code 1 if any file offends, 0 otherwise.
#>
[CmdletBinding(DefaultParameterSetName = 'Scan')]
param(
   [Parameter(Mandatory = $true, ParameterSetName = 'Scan', Position = 0)]
   [string] $SourceDir,

   [Parameter(ParameterSetName = 'Scan')]
   [switch] $Fix,

   [Parameter(Mandatory = $true, ParameterSetName = 'SelfTest')]
   [switch] $SelfTest
)

$ErrorActionPreference = 'Stop'

# Byte-level on purpose: reading the file as text would let .NET normalise the
# very thing being measured, and would drag encoding/BOM handling into a
# question that is purely about three byte values.
function Measure-Bytes([byte[]] $bytes)
   {
   $bareLF = 0
   $bareCR = 0
   for ($i = 0; $i -lt $bytes.Length; $i++)
      {
      if ($bytes[$i] -eq 0x0A)
         {
         if (($i -eq 0) -or ($bytes[$i - 1] -ne 0x0D))
            {
            $bareLF++
            }
         }
      elseif ($bytes[$i] -eq 0x0D)
         {
         if (($i -eq $bytes.Length - 1) -or ($bytes[$i + 1] -ne 0x0A))
            {
            $bareCR++
            }
         }
      }
   return [PSCustomObject]@{ BareLF = $bareLF; BareCR = $bareCR }
   }

# Collapse a run of CR immediately before an LF to one CRLF, and promote a
# bare LF to CRLF.  Byte-level, so no encoding is applied and no BOM moves --
# Lint-BOM pins 71 of those and this must not disturb one.
#
# A LONE CR -- no LF after it -- IS LEFT ALONE DELIBERATELY.  It is not a line
# ending this toolchain emits, and rewriting it would corrupt whatever it
# actually is.  It still fails the scan, so the operator is told rather than
# quietly given a file that was 'fixed'.
function Repair-Bytes([byte[]] $bytes)
   {
   $out = New-Object System.Collections.Generic.List[byte]
   $i   = 0
   while ($i -lt $bytes.Length)
      {
      if ($bytes[$i] -eq 0x0D)
         {
         $j = $i
         while (($j -lt $bytes.Length) -and ($bytes[$j] -eq 0x0D))
            {
            $j++
            }
         if (($j -lt $bytes.Length) -and ($bytes[$j] -eq 0x0A))
            {
            $out.Add(0x0D)
            $out.Add(0x0A)
            $i = $j + 1
            continue
            }
         while ($i -lt $j)
            {
            $out.Add(0x0D)
            $i++
            }
         continue
         }
      if ($bytes[$i] -eq 0x0A)
         {
         $out.Add(0x0D)
         $out.Add(0x0A)
         $i++
         continue
         }
      $out.Add($bytes[$i])
      $i++
      }
   return $out.ToArray()
   }

if ($SelfTest)
   {
   # Both defect classes, and the one case that must be reported but NOT
   # rewritten.  These live here rather than as files in the tree: a fixture
   # tree is itself subject to the corruption being tested for.
   $cases = @(
      @{ Name = 'clean CRLF';       In = @(0x41,0x0D,0x0A);                LF = 0; CR = 0 }
      @{ Name = 'bare LF';          In = @(0x41,0x0A);                     LF = 1; CR = 0 }
      @{ Name = 'doubled CR';       In = @(0x41,0x0D,0x0D,0x0A);           LF = 0; CR = 1 }
      @{ Name = 'tripled CR';       In = @(0x41,0x0D,0x0D,0x0D,0x0A);      LF = 0; CR = 2 }
      @{ Name = 'mixed LF + CRCR';  In = @(0x41,0x0D,0x0D,0x0A,0x42,0x0A); LF = 1; CR = 1 }
      @{ Name = 'lone CR (reported, never rewritten)'
         In = @(0x41,0x0D,0x42,0x0D,0x0A); LF = 0; CR = 1; NoRepair = $true }
   )

   $bad = 0
   foreach ($c in $cases)
      {
      $bytes = [byte[]] $c.In
      $m = Measure-Bytes $bytes
      if (($m.BareLF -ne $c.LF) -or ($m.BareCR -ne $c.CR))
         {
         Write-Host "  FAIL detect [$($c.Name)]: got $($m.BareLF) LF / $($m.BareCR) CR, want $($c.LF) / $($c.CR)"
         $bad++
         continue
         }
      $r = Measure-Bytes ([byte[]] (Repair-Bytes $bytes))
      $isClean = ($r.BareLF -eq 0) -and ($r.BareCR -eq 0)
      if ($isClean -eq [bool] $c.NoRepair)
         {
         Write-Host "  FAIL repair [$($c.Name)]: after repair $($r.BareLF) LF / $($r.BareCR) CR"
         $bad++
         continue
         }
      Write-Host "  ok: $($c.Name)"
      }

   if ($bad -gt 0)
      {
      Write-Host "Lint-LineEndings: SELF-TEST FAILED ($bad of $($cases.Count) case(s))."
      exit 1
      }
   Write-Host "Lint-LineEndings: self-test passed ($($cases.Count) case(s))."
   exit 0
   }

# The extensions the IDE opens, parses and rewrites. Deliberately NOT every
# text file: .sh must stay LF (Git Bash), and .md/.json/.py are never touched
# by the designer, so forcing CRLF on them would be noise without a reason.
#
# .lfm/.lpi joined the list on 2026-08-13 with the first Lazarus project. The
# Lazarus designer rewrites a .lfm on every form save, which is the same
# co-ownership that put .fmx and .dfm here -- the toolchain changed, the hazard
# did not.
#
# .ps1/.psm1 joined on 2026-08-21, for a DIFFERENT reason than the designer.
# These are the build and lint scripts, and they are increasingly written and
# edited by tooling rather than by hand -- which is exactly how six of them
# ended up LF or MIXED (Lint-SettingsMigration.ps1 was 28 CRLF and 130 LF)
# without anything noticing. This lint passed the whole time because it was not
# looking at them: the gate that catches a corrupted source file did not watch
# the gate. A mixed-ending script makes git warn on every touch and makes a diff
# unreadable, and neither symptom points at the cause.
$extensions = @('.pas', '.dpr', '.dpk', '.inc', '.dproj', '.bdsproj', '.fmx', '.dfm', '.rc',
                '.lfm', '.lpi', '.ps1', '.psm1')

if (-not (Test-Path -LiteralPath $SourceDir))
   {
   Write-Error "Lint-LineEndings: source directory not found: $SourceDir"
   exit 2
   }

$offenders = @()
$scanned   = 0

Get-ChildItem -LiteralPath $SourceDir -Recurse -File | Where-Object {
   $extensions -contains $_.Extension.ToLowerInvariant()
} | ForEach-Object {
   $scanned++
   $m = Measure-Bytes ([System.IO.File]::ReadAllBytes($_.FullName))

   if (($m.BareLF -gt 0) -or ($m.BareCR -gt 0))
      {
      $offenders += [PSCustomObject]@{
         Path   = $_.FullName
         BareLF = $m.BareLF
         BareCR = $m.BareCR
      }
      }
}

# A GUARD THAT MATCHES NOTHING MUST NOT PASS.  A wrong -SourceDir, or an
# extension list that stopped matching, is indistinguishable from a clean tree
# in the output -- and this lint's whole job is to be the thing that noticed.
if ($scanned -eq 0)
   {
   Write-Host "Lint-LineEndings: NO FILES MATCHED under $SourceDir -- refusing to pass."
   exit 1
   }

if ($offenders.Count -eq 0)
   {
   Write-Host "Lint-LineEndings: $scanned file(s) checked, all CRLF -- no bare LF, no stray CR."
   exit 0
   }

if ($Fix)
   {
   $unrepaired = 0
   foreach ($o in $offenders)
      {
      $after = [byte[]] (Repair-Bytes ([System.IO.File]::ReadAllBytes($o.Path)))
      [System.IO.File]::WriteAllBytes($o.Path, $after)

      # VERIFY THE REPAIR.  A rewrite that silently failed is worse than none:
      # the file now looks dealt with, and the next reader trusts it.
      $m = Measure-Bytes ([System.IO.File]::ReadAllBytes($o.Path))
      if (($m.BareLF -gt 0) -or ($m.BareCR -gt 0))
         {
         Write-Host "NOT FIXED: $($o.Path) -- $($m.BareLF) bare LF, $($m.BareCR) stray CR remain"
         $unrepaired++
         }
      else
         {
         Write-Host "fixed: $($o.Path) ($($o.BareLF) bare LF, $($o.BareCR) stray CR)"
         }
      }
   Write-Host "Lint-LineEndings: rewrote $($offenders.Count) file(s) to CRLF."
   if ($unrepaired -gt 0)
      {
      Write-Host "Lint-LineEndings: $unrepaired file(s) still offend -- a lone CR is reported, never rewritten."
      exit 1
      }
   exit 0
   }

foreach ($o in $offenders)
   {
   Write-Host "$($o.Path): $($o.BareLF) bare LF, $($o.BareCR) stray CR"
   }

Write-Host ""
Write-Host "Lint-LineEndings: $($offenders.Count) file(s) of $scanned have wrong line endings."
Write-Host "Code is inserted by BYTE OFFSET here; a bare LF or a stray CR shifts every offset after it."
Write-Host "Fix with:  powershell -File tr4w\build\Lint-LineEndings.ps1 -SourceDir tr4w\src -Fix"
exit 1
