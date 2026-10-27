# Lint-DomFileCase.ps1
#
# Every .dom file a contest class names must exist in target\dom with EXACTLY
# the spelling the class uses -- and so must every file a .dom INCLUDEs.
#
# ---------------------------------------------------------------------------
# WHY THIS EXISTS (issue #141, 2026-10-27)
# ---------------------------------------------------------------------------
# Windows does not care about case and Linux does. The tree shipped
# IDAHO.DOM, IDAHO_CTY.DOM and IN7QPNE.dom while the classes asked for
# 'idaho', 'idaho_cty' and 'in7qpne'. The PROGRAM never noticed, because every
# reader goes through uAppPaths.ExistingDataFile, which matches case off
# Windows -- but three unit tests used a bare FileExists, so the Linux suite
# failed with nine lines (and the run was green, a separate defect). The
# case-tolerant lookup is a safety net for a file an operator drops in by
# hand; it is not a licence to ship a name that disagrees with its own class.
# A Windows build cannot see the difference, so a Windows gate has to compare
# the spelling itself, ordinal and case-sensitive.
#
# WHAT IT READS: the contest classes, comments stripped and string literals
# kept (PascalSource.psm1) --
#    * every `Result := '<name>'` in a GetDomesticFileName or
#      GetInStateDomesticFileName body, and
#    * every `.DomesticFile := '<name>'` (a DescribeSession statement) --
# and each name must be on disk as `<name>.dom`. Then every
# `INCLUDE FILE <name>` line of every .dom in target\dom, one level, must name
# a file on disk by the same exact spelling. Ten legacy class names and 95
# legacy INCLUDE lines are upper case against lower-case files; they are
# pinned and ratcheted below, not waved through (see $LegacyNames).
#
# IT FAILS CLOSED: no factory directory, no dom directory, or fewer than the
# floors below (a parse that finds fewer has broken, not shrunk) fail.
#
#   powershell -File tr4w\build\Lint-DomFileCase.ps1
#   powershell -File tr4w\build\Lint-DomFileCase.ps1 -SelfTest

param(
   [string] $Repo       = (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent),
   [string] $FactoryDir = '',
   [string] $DomDir     = '',
   [switch] $SelfTest
)

if (-not $FactoryDir) { $FactoryDir = Join-Path $Repo 'tr4w\src\contestFactory' }
if (-not $DomDir)     { $DomDir     = Join-Path $Repo 'tr4w\target\dom' }

# THE FLOORS, measured 2026-10-27: 103 distinct class-named files (floor 90)
# and 109 INCLUDE lines (floor 100). Lower them only in the commit that
# deletes the contests.
$MinimumNames    = 90
$MinimumIncludes = 100

# THE LEGACY SPELLINGS -- ten class names that are UPPER case while the file
# is lower case (S48P14DC is also stored in settings as typed). Every reader
# resolves them through uAppPaths.ExistingDataFile, so they work on Linux, and
# changing a class literal changes a value that tests and saved settings pin.
# They are PINNED rather than renamed: a name not in this list must match its
# file exactly, a pin that matches nothing (or now matches exactly) FAILS so
# the list can only shrink. Do not add to it; rename the file instead.
$LegacyNames = @(
   'S48P14DC.dom', 'EUDX.dom', 'GC.dom', 'JIDX.dom', 'NEQSOW1.dom',
   'NEQSO.dom', 'OKOM.dom', 'PACCPA.dom', 'PACC.dom', 'YOTA.dom'
)

# THE INCLUDE RATCHET -- 95 INCLUDE FILE lines were written upper case
# (INCLUDE FILE S50.DOM) against lower-case files in the D7 era; the loader
# follows them case-tolerantly. A NEW line must be exact; the count may only
# fall. Lower the ceiling when it does, never raise it.
$INCLUDE_CEILING = 95

Import-Module (Join-Path $PSScriptRoot 'PascalSource.psm1') -Force

$getterRx  = [regex]::new(
   'function\s+T\w+\s*\.\s*Get(?:InState)?DomesticFileName\s*:\s*string\s*;(?<body>.*?)\bend\s*;',
   'IgnoreCase, Singleline')
$resultRx  = [regex]::new("\bResult\s*:=\s*'(?<n>[^']*)'", 'IgnoreCase')
$sessionRx = [regex]::new("\.DomesticFile\s*:=\s*'(?<n>[^']*)'", 'IgnoreCase')

# The names a body of (comment-stripped) Pascal asks for.
function Get-DomNames([string] $code)
   {
   $names = New-Object System.Collections.ArrayList
   foreach ($m in $getterRx.Matches($code))
      {
      foreach ($r in $resultRx.Matches($m.Groups['body'].Value))
         {
         if ($r.Groups['n'].Value -ne '') { [void]$names.Add($r.Groups['n'].Value) }
         }
      }
   foreach ($s in $sessionRx.Matches($code))
      {
      if ($s.Groups['n'].Value -ne '') { [void]$names.Add($s.Groups['n'].Value) }
      }
   return ,$names
   }

# Names missing from a directory listing under an ORDINAL, case-sensitive
# comparison. -cnotin is case-sensitive; -notin is not.
function Get-CaseMismatches([string[]] $wanted, [string[]] $onDisk)
   {
   $bad = New-Object System.Collections.ArrayList
   foreach ($w in $wanted)
      {
      if ($onDisk -cnotcontains $w) { [void]$bad.Add($w) }
      }
   return ,$bad
   }

if ($SelfTest)
   {
   # A fixture with one honest name, one wrong-case name, one session name and
   # a name inside a comment, which must not count.
   $fixture = @"
function TContestA.GetDomesticFileName: string;
begin
   Result := 'alpha_cty';
end;
function TContestA.GetInStateDomesticFileName: string;
begin
   Result := 'Alpha';
end;
procedure TContestA.DescribeSession(aSession: TSessionDefaults);
begin
   aSession.DomesticFile := 'beta';
end;
(* Result := 'gamma' *)
"@
   # Get-PascalCodeOnlyText reads a file, so the fixture is written to one.
   $tmp = Join-Path ([IO.Path]::GetTempPath()) ("domcase-selftest-" + [Guid]::NewGuid().ToString('N') + '.pas')
   [IO.File]::WriteAllText($tmp, $fixture)
   try
      {
      $code = Get-PascalCodeOnlyText -Path $tmp
      }
   finally
      {
      Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
      }
   $names = Get-DomNames $code
   $disk  = @('alpha_cty.dom', 'alpha.dom', 'beta.dom')
   $bad   = Get-CaseMismatches ($names | ForEach-Object { "$_.dom" }) $disk
   if (($names.Count -ne 3) -or ($bad.Count -ne 1) -or ($bad[0] -cne 'Alpha.dom'))
      {
      Write-Host "Lint-DomFileCase: SELF-TEST FAILED -- names=$($names.Count) (want 3), mismatches=$($bad.Count) (want 1: Alpha.dom)." -ForegroundColor Red
      exit 1
      }
   Write-Host 'Lint-DomFileCase: self-test OK (3 names read, 1 case mismatch reported, comment ignored).'
   exit 0
   }

foreach ($p in @($FactoryDir, $DomDir))
   {
   if (-not (Test-Path -LiteralPath $p))
      {
      Write-Host "Lint-DomFileCase: not found -- $p" -ForegroundColor Red
      exit 1
      }
   }

$onDisk = @(Get-ChildItem -LiteralPath $DomDir -File | ForEach-Object { $_.Name })

# --- what the classes ask for ----------------------------------------------
$asked = New-Object System.Collections.ArrayList
foreach ($f in Get-ChildItem -LiteralPath $FactoryDir -Filter '*.pas' -File)
   {
   $code = Get-PascalCodeOnlyText -Path $f.FullName
   foreach ($n in (Get-DomNames $code))
      {
      [void]$asked.Add([pscustomobject]@{ File = "$n.dom"; From = $f.Name })
      }
   }

$distinct = @($asked | ForEach-Object { $_.File } | Sort-Object -Unique)
if ($distinct.Count -lt $MinimumNames)
   {
   Write-Host "Lint-DomFileCase: read $($distinct.Count) class-named file(s) under $FactoryDir, floor $MinimumNames -- the getters moved or their shape changed." -ForegroundColor Red
   exit 1
   }

$problems = New-Object System.Collections.ArrayList
$pinsUsed = @{}
foreach ($a in $asked)
   {
   if ($onDisk -cnotcontains $a.File)
      {
      $near = @($onDisk | Where-Object { $_ -ieq $a.File })
      if ($LegacyNames -ccontains $a.File)
         {
         if ($near.Count -gt 0)
            {
            $pinsUsed[$a.File] = $true
            continue
            }
         }
      if ($near.Count -gt 0)
         {
         [void]$problems.Add("  $($a.From): names $($a.File), but target\dom holds $($near[0]) -- rename the file (git mv) to the class's spelling.")
         }
      else
         {
         [void]$problems.Add("  $($a.From): names $($a.File), which is not in target\dom at all.")
         }
      }
   }

# --- what the .dom files include --------------------------------------------
foreach ($pin in $LegacyNames)
   {
   if (-not $pinsUsed.ContainsKey($pin))
      {
      [void]$problems.Add("  legacy pin $pin matches nothing (no class names it, or it now matches its file exactly) -- remove it from `$LegacyNames.")
      }
   }

$includes = 0
$looseIncludes = New-Object System.Collections.ArrayList
foreach ($f in Get-ChildItem -LiteralPath $DomDir -File -Filter '*.dom')
   {
   $n = 0
   foreach ($line in Get-Content -LiteralPath $f.FullName)
      {
      $n++
      $trimmed = $line.TrimStart(' ', "`t")
      if ($trimmed.StartsWith('INCLUDE FILE', [System.StringComparison]::Ordinal))
         {
         $includes++
         $target = $trimmed.Substring('INCLUDE FILE'.Length).Trim()
         if (($target -ne '') -and ($onDisk -cnotcontains $target))
            {
            $near = @($onDisk | Where-Object { $_ -ieq $target })
            if ($near.Count -gt 0)
               {
               [void]$looseIncludes.Add("  $($f.Name) line ${n}: INCLUDE FILE $target, but target\dom holds $($near[0]) -- spell it exactly.")
               }
            }
         }
      }
   }

if ($looseIncludes.Count -gt $INCLUDE_CEILING)
   {
   [void]$problems.Add("  $($looseIncludes.Count) INCLUDE FILE line(s) differ in case from their file, ceiling $INCLUDE_CEILING -- a NEW include must spell the file exactly:")
   $looseIncludes | ForEach-Object { [void]$problems.Add($_) }
   }
elseif ($looseIncludes.Count -lt $INCLUDE_CEILING)
   {
   Write-Host "Lint-DomFileCase: loose INCLUDE lines fell to $($looseIncludes.Count) -- lower `$INCLUDE_CEILING from $INCLUDE_CEILING." -ForegroundColor Yellow
   }

if ($includes -lt $MinimumIncludes)
   {
   Write-Host "Lint-DomFileCase: read $includes INCLUDE FILE line(s) in $DomDir, floor $MinimumIncludes -- the include syntax or the directory changed." -ForegroundColor Red
   exit 1
   }

if ($problems.Count -gt 0)
   {
   Write-Host ''
   Write-Host "Lint-DomFileCase: $($problems.Count) .dom name(s) differ from the file on disk in case:" -ForegroundColor Red
   $problems | ForEach-Object { Write-Host $_ -ForegroundColor Red }
   Write-Host '  Windows hides this and Linux does not (issue #141): the name and the file must agree EXACTLY.' -ForegroundColor Yellow
   exit 1
   }

Write-Host "Lint-DomFileCase: $($distinct.Count) class-named .dom file(s) checked ($($LegacyNames.Count) pinned legacy spellings), $includes INCLUDE line(s) read ($($looseIncludes.Count) loose, ceiling $INCLUDE_CEILING)."
exit 0
