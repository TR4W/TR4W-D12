<#
.SYNOPSIS
   Fails the build on an address or a pointer narrowed to a 32-bit integer.

.DESCRIPTION
   WHY THIS EXISTS (pointer audit D3 / packet P2, 2026-10-16). docs/
   64_BIT_TASKLIST.md recorded "pointer truncation -- casts: 0, DONE". That scan
   looked for Pointer(Integer(...)) -- an integer WIDENED back into a pointer.
   It could not see the opposite direction, which is the one that loses bits:

       SendMessage(..., EM_SETCHARFORMAT, SCF_SELECTION, integer(@MMTTY.mmttyCF));
       ShowLogCompare(integer(s));        (* s: PLogFileInformation *)

   Five such sites were live when it was written. On i386 a pointer IS 32
   bits, so every one is invisible -- no build, test or corpus run can see it
   -- and on x86_64 each hands its consumer the low half of an address. The
   x86_64 COMPILER does not catch it either: an explicit cast is a request,
   not a mistake, as far as FPC is concerned.

   WHAT IS A VIOLATION. A cast to integer, longint, cardinal, longword, dword,
   word, smallint, shortint or byte, applied to:

     R1  an address              integer(@x)        integer( @a.b[1] )
     R2  an untyped pointer      integer(Pointer(x))
         or a class reference    integer(Self)
     R3  a variable, field or parameter DECLARED in the same file with a
         pointer type -- ^T, Pointer, a P-prefixed type (PFoo, PChar), or a
         ...Ptr / ...Pointer type -- cast on its own: integer(s)

   WHAT TO WRITE INSTEAD, in order of preference: no cast at all (a typed
   parameter -- ShowLogCompare takes PLogFileInformation now); a pointer-sized
   integer where an integer is the contract (LPARAM / WPARAM for a window
   message, PtrInt / PtrUInt otherwise).

   WHAT IS NOT FLAGGED, deliberately:
     * PtrInt / PtrUInt / NativeInt / NativeUInt / LPARAM / WPARAM / Int64 /
       QWord of an address -- those are wide enough on every target;
     * a typed-pointer pun, PInteger(@x)^ -- a different question (the
       Move/PChar audits own reinterpretation), and it narrows nothing;
     * anything inside a comment or a string literal -- PascalSource.psm1's
       code-only text is what is scanned, so a comment QUOTING the bad form
       (as this tree's comments often do) is not a hit.

   R3 IS PER FILE, NOT PER ROUTINE. A name declared with a pointer type
   anywhere in the file counts everywhere in it. That can only OVER-report; if
   it ever does, rename the integer, which is the clearer fix anyway.

   THE FLOORS. A lint that matched nothing must not pass (CLAUDE.md, "guards
   must not fail open"). Every run, before the tree:
     * a built-in fixture with known hits and known non-hits must come out
       exactly -- so a broken pattern fails rather than passing a clean tree;
     * the scan must include src\MainUnit.pas -- a wrong -SourceDir scans
       nothing and reports zero;
     * R3 must have collected at least $MIN_POINTER_NAMES pointer-typed names
       across the tree -- so a broken declaration reader fails.

   .\Lint-PointerTruncation.ps1              # the tree (Run-Lints passes -SourceDir)
   .\Lint-PointerTruncation.ps1 -SelfTest    # the fixture only
#>
param(
   [string] $SourceDir,
   [switch] $SelfTest
)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'PascalSource.psm1') -Force
. (Join-Path $PSScriptRoot 'Get-ScanExclusions.ps1')   # Test-Tr4wScannable

if (-not $SourceDir) {
   $SourceDir = Split-Path -Parent $PSScriptRoot
}

# Measured 2026-10-16: 208 pointer-typed names (distinct per file, summed)
# across the 819 files under tr4w. The floor only has to be far above zero --
# a broken declaration reader finds none -- and well below that.
$MIN_POINTER_NAMES = 100

$narrow = '(?:integer|longint|cardinal|longword|dword|word|smallint|shortint|byte)'

$script:R1 = [regex] ('(?i)(?<![\w.])' + $narrow + '\s*\(\s*@')
$script:R2 = [regex] ('(?i)(?<![\w.])' + $narrow + '\s*\(\s*(?:Pointer\s*\(|Self\s*\))')
# A declaration list `a, b : <pointer type>` -- the names, then the type.
$script:Decl = [regex] ('(?i)(?<![\w.])(?<names>[A-Za-z_]\w*(?:\s*,\s*[A-Za-z_]\w*)*)\s*:\s*' +
                        '(?<type>\^\s*\w+|Pointer\b|(?-i:P[A-Z]\w*)|\w+Ptr\b|\w+Pointer\b)')
$script:R3Prefix = '(?i)(?<![\w.])' + $narrow + '\s*\(\s*'

function Get-LineNumber
{
   param([string] $Text, [int] $Index)

   $n = 1
   for ($i = 0; $i -lt $Index; $i++) {
      if ($Text[$i] -eq "`n") { $n++ }
   }
   return $n
}

# THE ONE SCAN, used by the fixture and the tree alike so they cannot drift.
# Returns @{ Hits = ...; Names = <count of pointer-typed names found> }.
function Find-PointerTruncation
{
   param([string] $Path)

   $code = Get-PascalCodeOnlyText -Path $Path -BlankStrings
   $hits = New-Object System.Collections.ArrayList

   foreach ($m in $script:R1.Matches($code)) {
      [void] $hits.Add([pscustomobject]@{ Rule = 'R1'; Index = $m.Index; Text = $m.Value })
   }
   foreach ($m in $script:R2.Matches($code)) {
      [void] $hits.Add([pscustomobject]@{ Rule = 'R2'; Index = $m.Index; Text = $m.Value })
   }

   $names = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
   foreach ($m in $script:Decl.Matches($code)) {
      foreach ($n in ($m.Groups['names'].Value -split '\s*,\s*')) {
         if ($n -ne '') { [void] $names.Add($n) }
      }
   }
   if ($names.Count -gt 0) {
      $alt = (@($names) | ForEach-Object { [regex]::Escape($_) }) -join '|'
      $r3 = [regex] ($script:R3Prefix + '(?:' + $alt + ')\s*\)')
      foreach ($m in $r3.Matches($code)) {
         [void] $hits.Add([pscustomobject]@{ Rule = 'R3'; Index = $m.Index; Text = $m.Value })
      }
   }

   foreach ($h in $hits) {
      $h | Add-Member -NotePropertyName Line -NotePropertyValue (Get-LineNumber -Text $code -Index $h.Index)
   }
   return @{ Hits = @($hits | Sort-Object Index); Names = $names.Count }
}

# ---------------------------------------------------------------------------
# THE FIXTURE. Every line ending `// HIT <rule>` must be reported with that
# rule, and nothing else may be.
# ---------------------------------------------------------------------------
function Invoke-PointerTruncationSelfTest
{
   $fixture = @(
      'unit fixture;'
      'interface'
      'implementation'
      'type'
      '   PRec = ^TRec;'
      '   TRec = record a: integer; end;'
      'var'
      '   g: TRec;'
      '   p, q: PRec;'
      '   raw: Pointer;'
      '   rp: ^TRec;'
      '   n, Count: integer;'
      'procedure T(aInfo: PRec);'
      'begin'
      '   n := integer(@g);                          // HIT R1'
      '   n := LongInt( @g.a );                      // HIT R1'
      '   n := DWORD(Pointer(p));                    // HIT R2'
      '   n := cardinal(p);                          // HIT R3'
      '   n := integer(aInfo);                       // HIT R3'
      '   n := integer(raw);                         // HIT R3'
      '   n := integer(rp);                          // HIT R3'
      '   n := PtrInt(@g);'
      '   n := PtrUInt(p);'
      '   n := LPARAM(@g);'
      '   n := PInteger(@g)^;'
      '   n := integer(Count);'
      '   n := integer(p^.a);'
      '   n := MyInteger(@g);'
      '   n := Length(''integer(@g)'');'
      '   // n := integer(@g);'
      '   (* n := integer(p); *)'
      '   { n := cardinal(@g); }'
      'end;'
      'end.'
   )

   $expected = @{}
   for ($i = 0; $i -lt $fixture.Count; $i++) {
      if ($fixture[$i] -match '// HIT (R\d)$') {
         $expected[$i + 1] = $Matches[1]
      }
   }

   $tmp = Join-Path ([IO.Path]::GetTempPath()) ('lint-ptrtrunc-' + [Guid]::NewGuid().ToString('N') + '.pas')
   try {
      [IO.File]::WriteAllText($tmp, ($fixture -join "`r`n") + "`r`n")
      $r = Find-PointerTruncation -Path $tmp
   }
   finally {
      Remove-Item -LiteralPath $tmp -ErrorAction SilentlyContinue
   }

   $ok = $true
   $seen = @{}
   foreach ($h in $r.Hits) {
      $seen[$h.Line] = $h.Rule
      if (-not $expected.ContainsKey($h.Line)) {
         Write-Host ("  self-test: UNEXPECTED {0} at fixture line {1}: {2}" -f $h.Rule, $h.Line, $fixture[$h.Line - 1].Trim())
         $ok = $false
      }
      elseif ($expected[$h.Line] -ne $h.Rule) {
         Write-Host ("  self-test: line {0} reported {1}, expected {2}" -f $h.Line, $h.Rule, $expected[$h.Line])
         $ok = $false
      }
   }
   foreach ($line in $expected.Keys) {
      if (-not $seen.ContainsKey($line)) {
         Write-Host ("  self-test: MISSED {0} at fixture line {1}: {2}" -f $expected[$line], $line, $fixture[$line - 1].Trim())
         $ok = $false
      }
   }
   if ($r.Hits.Count -ne $expected.Count) {
      $ok = $false
   }
   if ($ok) {
      Write-Host ("Lint-PointerTruncation: self-test OK ({0} expected hits, {1} reported)." -f $expected.Count, $r.Hits.Count)
   }
   return $ok
}

if (-not (Invoke-PointerTruncationSelfTest)) {
   Write-Output "Lint-PointerTruncation: SELF-TEST FAILED -- refusing to judge the tree."
   exit 1
}
if ($SelfTest) {
   exit 0
}

if (-not (Test-Path -LiteralPath $SourceDir -PathType Container)) {
   Write-Output "Lint-PointerTruncation: source directory not found: $SourceDir"
   exit 1
}

$files = @(Get-TR4WPascalFiles -Root $SourceDir |
           Where-Object { (Test-Tr4wScannable $_.FullName) -and
                          $_.FullName -notmatch '\\graphify-out\\' })

if (-not ($files | Where-Object { $_.Name -ieq 'MainUnit.pas' })) {
   Write-Output ("Lint-PointerTruncation: MainUnit.pas is not under '{0}' ({1} file(s)) -- wrong -SourceDir? Refusing to report a pass." -f $SourceDir, $files.Count)
   exit 1
}

$violations = New-Object System.Collections.ArrayList
$totalNames = 0
foreach ($f in $files) {
   $r = Find-PointerTruncation -Path $f.FullName
   $totalNames += $r.Names
   if ($r.Hits.Count -gt 0) {
      $lines = [IO.File]::ReadAllLines($f.FullName)
      foreach ($h in $r.Hits) {
         $rel = $f.FullName.Substring($SourceDir.TrimEnd('\').Length).TrimStart('\')
         [void] $violations.Add(("  {0}:{1}  [{2}]  {3}" -f $rel, $h.Line, $h.Rule, $lines[$h.Line - 1].Trim()))
      }
   }
}

if ($totalNames -lt $MIN_POINTER_NAMES) {
   Write-Output ("Lint-PointerTruncation: only {0} pointer-typed name(s) found across {1} file(s) (floor {2}) -- the declaration reader is broken. Refusing to report a pass." -f $totalNames, $files.Count, $MIN_POINTER_NAMES)
   exit 1
}

if ($violations.Count -gt 0) {
   $violations | ForEach-Object { Write-Output $_ }
   Write-Output ("Lint-PointerTruncation: {0} address(es) or pointer(s) narrowed to a 32-bit integer." -f $violations.Count)
   Write-Output "  On x86_64 each one hands its consumer the low half of an address, and nothing"
   Write-Output "  on i386 can see it. Pass a typed pointer instead, or LPARAM / WPARAM / PtrInt /"
   Write-Output "  PtrUInt where an integer is the contract. See docs/POINTER_AUDIT.md, D3."
   exit 1
}

Write-Output ("Lint-PointerTruncation: {0} file(s), {1} pointer-typed name(s) checked; no pointer narrowed to a 32-bit integer." -f $files.Count, $totalNames)
exit 0
