# Fails the build when ContestExchange is treated as RAW BYTES outside the
# places that are allowed to, and says where.
#
# WHY (issue 386, NY4I's ruling: ContestExchange stays a RECORD -- a value type
# with no managed field -- and gains methods; it is not converted to a class).
# A byte operation on the record is right only while the record is plain data
# laid out the way the code assumes. Every new FillChar, Move, CompareMem or raw
# read of it is one more place that must be found before the record may change
# shape (batch B of issue 386 frees it from the D7 376-byte layout). The ways the
# program SHOULD say these things are the record's own methods:
#
#   FillChar(x, SizeOf(ContestExchange), 0)      ->  x.Clear
#   CompareMem(@a, @b, SizeOf(ContestExchange))  ->  a.SameBytes(b)
#
# WHAT IS A HIT. A call to one of $VERBS whose arguments
#   (a) mention SizeOf(ContestExchange) or SizeOfContestExchange, or
#   (b) name, as a WHOLE argument (optionally @x or x^), a variable, parameter,
#       field or function Result that THE SAME FILE declares `: ContestExchange`;
# and every `file of ContestExchange` declaration.
#
# WHAT A TEXT LINT CANNOT SEE -- said plainly, because a green run is not a proof:
#   * a variable of the type declared in ANOTHER unit and used here by its bare
#     name (a global such as logsubs2's TempRXData used from MainUnit), or reached
#     through a pointer (ContestExchangePtr, ContestExchangeArray) or a `with`;
#   * a size written as a NUMBER (376) or as SizeOf of a variable of another unit;
#   * a routine with an UNTYPED buffer parameter that is not in $VERBS (uNet's
#     SendToNet(var buf; Len), utils_file's wrappers are in; others are not);
#   * an OVERLAY of part of the record: uLogNote writes and reads a note through
#     the bytes from Prefix onward (Move / FillChar on aQso.Prefix with
#     NOTE_MAX_LENGTH). A field argument is deliberately not a hit, so that is
#     invisible here; uTestLogNote pins it.
#   * a name declared ContestExchange in one routine and as something else in
#     another routine of the same file is treated as ContestExchange everywhere
#     in that file (a false hit, never a missed one).
# The compile guard in VC.pas (TContestExchangeMustStayUnmanaged) and the
# IsManagedType test cover what matters most of that: a managed field.
#
# THE ALLOW-LIST IS A RATCHET. Each file it names may hold AT MOST its count;
# more fails, fewer asks for the number to be lowered in the same commit. A file
# not listed may hold none.
#
#   .\Lint-ContestExchangeBytes.ps1              # gate (what Run-Lints runs)
#   .\Lint-ContestExchangeBytes.ps1 -Detail      # every hit, allowed or not
#   .\Lint-ContestExchangeBytes.ps1 -SelfTest    # the fixture only
#
# It FAILS CLOSED: the fixture runs first on every run, and the run refuses when
# it scans too few files or cannot find VC.pas declaring the record.

param(
   [Alias('SourceDir')]
   [string] $Root = (Split-Path -Parent $PSScriptRoot),
   [switch] $Detail,
   [switch] $SelfTest
)

# Relative path (from the tr4w directory) -> the most hits it may hold, and why.
# Batch B of issue 386 is to empty the rows marked BATCH B.
$ALLOWED = [ordered]@{
   # The record's own method: SameBytes compares SizeOf(ContestExchange) bytes.
   'src\VC.pas'                          = 1
   # BATCH B: the .TRW importer reads 376 raw bytes straight into the live record
   # (and clears it first). It is to read a FROZEN copy of the D7 record instead.
   'src\uLogBinaryFile.pas'              = 2
   # BATCH B: AskConvertLog (v1.5/v1.6 .TRW upgrader) declares a typed
   # `file of ContestExchange` and writes it twice. It has NO CALLER (searched
   # 2026-11-26); delete it.
   'src\MainUnit.pas'                    = 3
   # The test of Clear fills the record with $FF first, on purpose.
   'test\unit\uTestLogBinaryFile.pas'    = 1
   # BATCH B: builds .TRW files to import by streaming the live record; to
   # stream the frozen D7 record instead.
   'test\unit\uTestLogReceivedYear.pas'  = 6
   # BATCH B: writes a fake SERVERLOG.TRW record by its size (uServerLogHealth).
   'test\unit\uTestServerLogHealth.pas'  = 1
}

$VERBS = @(
   'FillChar', 'Move', 'CompareMem', 'CompareByte', 'ZeroMemory', 'CopyMemory',
   'FileRead', 'FileWrite', 'BlockRead', 'BlockWrite',
   'ReadBuffer', 'WriteBuffer', 'Read', 'Write',
   'sReadFile', 'sWriteFile', 'tWriteFile'
)
$FILE_FLOOR = 300

Import-Module (Join-Path $PSScriptRoot 'PascalSource.psm1') -Force

$script:CallRx = [regex]::new('(?i)(?<![\w])(?:\w+\s*\.\s*)?\b(' + ($VERBS -join '|') + ')\s*\(')
$script:SizeRx = [regex]::new('(?i)\bSizeOf\s*\(\s*ContestExchange\s*\)|\bSizeOfContestExchange\b')
$script:DeclRx = [regex]::new('(?i)\b([A-Za-z_]\w*(?:\s*,\s*[A-Za-z_]\w*)*)\s*:\s*ContestExchange(?!\w)')
# A routine heading: name, an optional parameter list (no nested parentheses in
# this tree's headings), and for a function its result type in group 1.
$script:FuncRx = [regex]::new('(?i)\bfunction\s+[\w.]+\s*(?:\([^)]*\))?\s*:\s*ContestExchange(?!\w)')
$script:FuncHeadRx = [regex]::new('(?i)\b(?:function|procedure)\s+[\w.]+\s*(?:\([^)]*\))?\s*(?::\s*(\w+))?')
$script:FileRx = [regex]::new('(?i)\bfile\s+of\s+ContestExchange(?!\w)')

# The text of the argument list that opens at $open (the index of '('), up to
# its matching ')'. Strings are already blanked, so parentheses are code.
function Get-ArgumentText([string] $Text, [int] $Open)
{
   $depth = 0
   for ($i = $Open; $i -lt $Text.Length; $i++) {
      $c = $Text[$i]
      if ($c -eq '(') { $depth++ }
      elseif ($c -eq ')') {
         $depth--
         if ($depth -eq 0) { return $Text.Substring($Open + 1, $i - $Open - 1) }
      }
      if ($i - $Open -gt 2000) { break }
   }
   return $Text.Substring($Open + 1, [Math]::Min(200, $Text.Length - $Open - 1))
}

# Top-level comma split.
function Split-Arguments([string] $ArgText)
{
   $parts = New-Object 'System.Collections.Generic.List[string]'
   $depth = 0
   $start = 0
   for ($i = 0; $i -lt $ArgText.Length; $i++) {
      $c = $ArgText[$i]
      if ($c -eq '(' -or $c -eq '[') { $depth++ }
      elseif ($c -eq ')' -or $c -eq ']') { $depth-- }
      elseif ($c -eq ',' -and $depth -eq 0) {
         $parts.Add($ArgText.Substring($start, $i - $start).Trim())
         $start = $i + 1
      }
   }
   $parts.Add($ArgText.Substring($start).Trim())
   return $parts
}

function Get-LineOf([System.Collections.Generic.List[int]] $Starts, [int] $Index)
{
   $lo = 0; $hi = $Starts.Count - 1
   while ($lo -lt $hi) {
      $mid = [int][math]::Ceiling(($lo + $hi) / 2)
      if ($Starts[$mid] -le $Index) { $lo = $mid } else { $hi = $mid - 1 }
   }
   return $lo + 1
}

# One object per hit in a file.
function Get-ExchangeByteHits([string] $Path)
{
   $clean = Get-PascalCodeOnlyText -Path $Path -BlankStrings

   $names = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
   foreach ($m in $script:DeclRx.Matches($clean)) {
      foreach ($n in ($m.Groups[1].Value -split ',')) { [void]$names.Add($n.Trim()) }
   }
   if ($script:FuncRx.IsMatch($clean)) { [void]$names.Add('Result') }
   # Keywords the declaration pattern can pick up before a colon are not names.
   foreach ($k in @('var', 'const', 'out', 'function', 'procedure', 'property')) { [void]$names.Remove($k) }

   $starts = New-Object 'System.Collections.Generic.List[int]'
   $starts.Add(0)
   foreach ($nl in [regex]::Matches($clean, "`n")) { $starts.Add($nl.Index + 1) }

   $result = @()
   foreach ($c in $script:CallRx.Matches($clean)) {
      $open = $c.Index + $c.Length - 1
      $argText = Get-ArgumentText $clean $open
      $hit = $script:SizeRx.IsMatch($argText)
      if (-not $hit -and $names.Count -gt 0) {
         foreach ($a in (Split-Arguments $argText)) {
            $bare = $a.Trim()
            if ($bare.StartsWith('@')) { $bare = $bare.Substring(1).Trim() }
            if ($bare.EndsWith('^')) { $bare = $bare.Substring(0, $bare.Length - 1).Trim() }
            if ($bare -match '^[A-Za-z_]\w*$' -and $names.Contains($bare)) {
               # Result is the record only inside a function that returns it:
               # ask the nearest function heading above the call.
               if ($bare -ieq 'Result') {
                  $head = $null
                  foreach ($fh in $script:FuncHeadRx.Matches($clean.Substring(0, $c.Index))) { $head = $fh }
                  if (-not $head -or $head.Groups[1].Value -ine 'ContestExchange') { continue }
               }
               $hit = $true
               break
            }
         }
      }
      if ($hit) {
         $result += [pscustomobject]@{ Line = (Get-LineOf $starts $c.Index); What = $c.Groups[1].Value }
      }
   }
   foreach ($f in $script:FileRx.Matches($clean)) {
      $result += [pscustomobject]@{ Line = (Get-LineOf $starts $f.Index); What = 'file of' }
   }
   return $result
}

function Invoke-SelfTest
{
   $fixture = @(
      "unit fixture;",
      "var",
      "   q, other: ContestExchange;",
      "   p: ContestExchangePtr;",
      "   n: integer;",
      "   f: file of ContestExchange;                   // HIT 1 -- a typed file",
      "function Make: ContestExchange;",
      "begin",
      "   FillChar(Result, SizeOf(Result), 0);           // HIT 2 -- Result of the type",
      "end;",
      "function Other(a: integer; b: ContestExchange): TSomethingElse;",
      "begin",
      "   FillChar(Result, SizeOf(Result), 0);           // Result of ANOTHER type: not a hit",
      "end;",
      "function Made(a: integer; var b: integer): ContestExchange;",
      "begin",
      "   FillChar(Result, SizeOf(Result), 0);           // HIT 8 -- several parameters",
      "end;",
      "procedure P(var aRec: ContestExchange);",
      "begin",
      "   FillChar(q, SizeOf(ContestExchange), 0);       // HIT 3 -- by the type's size",
      "   FillChar(other, SizeOf(other), 0);             // HIT 4 -- by a declared name",
      "   if CompareMem(@q, @aRec, 376) then n := 1;    // HIT 5 -- @name",
      "   Move(p^, q, SizeOfContestExchange);           // HIT 6 -- the constant",
      "   stream.Read(aRec, 376);                        // HIT 7 -- a stream method",
      "   FillChar(q.Callsign, SizeOf(q.Callsign), 0);   // a FIELD: not a hit",
      "   FillChar(n, SizeOf(n), 0);                     // another type: not a hit",
      "   q.Clear;                                       // the method: not a hit",
      "   if q.SameBytes(other) then n := 2;            // the method: not a hit",
      "   // FillChar(q, SizeOf(ContestExchange), 0);    line comment",
      "   (* Move(q, other, SizeOf(ContestExchange)); *) paren comment",
      "   s := 'FillChar(q, SizeOf(ContestExchange), 0)'; // string",
      "   ReadLn(t, q);                                  // look-alike verb",
      "end;"
   )
   $expected = 8
   $tmp = Join-Path ([IO.Path]::GetTempPath()) ("cebytes_" + [Guid]::NewGuid().ToString('N') + ".pas")
   try {
      [IO.File]::WriteAllText($tmp, ($fixture -join "`r`n"))
      $got = @(Get-ExchangeByteHits $tmp)
   }
   finally {
      if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Force }
   }
   # THE REPORT IS COLLECTED, NOT WRITTEN, and the function returns ONLY the
   # boolean. A Write-Output in here would join the return value into an
   # array, which is truthy -- so a failing fixture would read as a pass. That
   # happened (2026-11-26): the fixture "passed" while name matching was broken.
   $script:SelfTestReport = @()
   if ($got.Count -ne $expected) {
      $script:SelfTestReport += ("Lint-ContestExchangeBytes SELFTEST FAIL: expected {0} hit(s), got {1}:" -f $expected, $got.Count)
      foreach ($g in $got) { $script:SelfTestReport += ("   fixture line {0}: {1}   <- {2}" -f $g.Line, $g.What, $fixture[$g.Line - 1].Trim()) }
      return $false
   }
   return $true
}

# ---------------------------------------------------------------------------

$selfTestOk = Invoke-SelfTest
if ($selfTestOk -isnot [bool] -or -not $selfTestOk) {
   $script:SelfTestReport | ForEach-Object { Write-Output $_ }
   Write-Output 'Lint-ContestExchangeBytes: the fixture is wrong, so the tree is not judged.'
   exit 1
}
if ($SelfTest) {
   Write-Output 'Lint-ContestExchangeBytes SELFTEST: the fixture''s 8 hits found exactly; every trap ignored.'
   exit 0
}

$Root  = (Resolve-Path -LiteralPath $Root).Path.TrimEnd('\')
$files = Get-TR4WPascalFiles -Root $Root
$vc = $files | Where-Object { $_.Name -ieq 'VC.pas' } | Select-Object -First 1
if ($files.Count -lt $FILE_FLOOR -or -not $vc -or
    -not ([IO.File]::ReadAllText($vc.FullName) -match '(?i)\bContestExchange\s*=\s*record\b')) {
   Write-Output ("Lint-ContestExchangeBytes: {0} file(s) under '{1}', VC.pas declaring the record {2}. The root or the reader is wrong; failing." -f $files.Count, $Root, $(if ($vc) { 'not found in it' } else { 'missing' }))
   exit 1
}

$failed = $false
$lower  = @()
$seen   = @{}
$total  = 0
foreach ($f in $files) {
   $hits = @(Get-ExchangeByteHits $f.FullName)
   if ($hits.Count -eq 0) { continue }
   $rel = $f.FullName.Substring($Root.Length).TrimStart('\')
   $total += $hits.Count
   $seen[$rel] = $hits.Count
   # NOT $allowed: PowerShell names are case-insensitive, so that would BE
   # $ALLOWED and the first file would overwrite the list.
   $allowance = 0
   foreach ($k in $ALLOWED.Keys) { if ($k -ieq $rel) { $allowance = $ALLOWED[$k] } }
   $over = $hits.Count -gt $allowance
   if ($over -or $Detail) {
      $src = [IO.File]::ReadAllLines($f.FullName)
      Write-Output ("{0}  {1} hit(s), allowed {2}" -f $rel, $hits.Count, $allowance)
      foreach ($h in $hits) { Write-Output ("   {0,6}: {1}" -f $h.Line, $src[$h.Line - 1].Trim()) }
   }
   if ($over) { $failed = $true }
}
foreach ($k in $ALLOWED.Keys) {
   $n = 0
   foreach ($s in $seen.Keys) { if ($s -ieq $k) { $n = $seen[$s] } }
   if ($n -lt $ALLOWED[$k]) { $lower += ("   {0}: {1} -> {2}" -f $k, $ALLOWED[$k], $n) }
}

Write-Output ("Lint-ContestExchangeBytes: {0} byte operation(s) on ContestExchange across {1} file(s) scanned" -f $total, $files.Count)
if ($failed) {
   Write-Output 'Lint-ContestExchangeBytes FAILED: clear it with .Clear, compare it with .SameBytes, or read it field by field. Do not widen the allow-list (issue 386).'
   exit 1
}
if ($lower.Count -gt 0) {
   Write-Output 'Lint-ContestExchangeBytes FAILED: the allow-list is a ratchet -- lower these in tr4w\build\Lint-ContestExchangeBytes.ps1 with the change:'
   $lower | ForEach-Object { Write-Output $_ }
   exit 1
}
exit 0
