<#
.SYNOPSIS
   Fails the build on a bare System.Val call. Every text-to-number conversion with
   a code goes through utils_text.ValChecked.

.DESCRIPTION
   WHY THIS EXISTS (issue 299, 2026-11-12). On Win64, FPC 3.2.2's
   Val(s, longintVar, code) is NOT range-checked: fpc_Val_SInt_* work in a
   64-bit ValSInt (rtl/inc/sstrings.inc) and a base-10 result is cut down to the
   destination with no check. Measured with the same source on both targets:

       Val('99999999999', L, Code)    i386: L = 0, Code = 10
                                      x64 : L = 1215752191, Code = 0

   so an 11-digit QSO number was accepted. Byte/Word/SmallInt/ShortInt were never
   checked on either bitness. utils_text.ValChecked parses into an Int64 and
   enforces the destination's range (overloads take VAR parameters of the exact
   type, so a type with no overload fails to compile).

   WHAT IS A VIOLATION. Any call to Val -- not a method (.Val), not a longer
   identifier, not inside a comment or string -- in any Pascal file under the
   tree, except utils_text.pas, which holds the helper's own calls.

   WHY EVERY Val AND NOT ONLY THOSE INTO A NARROW DESTINATION. The destination's
   type cannot be read by a token walk (a field of a record, a var parameter, an
   inherited Result), and "narrow" is exactly the case that is wrong; the helper
   also has Int64 and Double overloads, so there is nothing to excuse.

   THE RATCHET. $CEILINGS names the files that still hold bare calls, with the
   count; a file may not exceed it, and a file BELOW it fails too ("lower the
   ceiling"), so the table only shrinks. Every entry carries its reason.

   NOT COVERED, and said so: the RTL's own StrToInt, StrToIntDef and TryStrToInt
   sit on the same routine and have the same Win64 hole (measured; see
   docs/64_BIT_TASKLIST.md). They are not a Val call and are not counted here.

   THE FLOORS. A lint that matched nothing must not pass: a built-in fixture
   with known hits and non-hits must come out exact, the scan must include
   src\MainUnit.pas, and it must see at least $MIN_FILES files.

   .\Lint-BareVal.ps1             # the tree (Run-Lints passes the tr4w directory)
   .\Lint-BareVal.ps1 -SelfTest   # the fixture only
   .\Lint-BareVal.ps1 -List       # every remaining bare call
#>
param(
   [string] $SourceDir,
   [switch] $SelfTest,
   [switch] $List
)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'PascalSource.psm1') -Force
. (Join-Path $PSScriptRoot 'Get-ScanExclusions.ps1')   # Test-Tr4wScannable

if (-not $SourceDir) {
   $SourceDir = Split-Path -Parent $PSScriptRoot
}

$MIN_FILES = 500

# The helper's own home. Its Val calls ARE the implementation.
$EXEMPT = @('utils_text.pas')

# File name -> allowed bare calls, and why. Empty means none.
$CEILINGS = @{
   # NOT CONVERTED BY THIS CHANGE: another agent had uSettingsModel.pas open
   # (the tailcat session) and the instruction was not to touch it. Three integer
   # destinations (a zone and two counts) and one Double. Convert in the next
   # change that has the file, then delete this row.
   'uSettingsModel.pas' = 4
}

$script:ValCall = [regex] '(?i)(?<![\w.])Val\s*\('

function Get-LineNumber
{
   param([string] $Text, [int] $Index)

   $n = 1
   for ($i = 0; $i -lt $Index; $i++) {
      if ($Text[$i] -eq "`n") { $n++ }
   }
   return $n
}

function Find-BareVal
{
   param([string] $Path)

   $code = Get-PascalCodeOnlyText -Path $Path -BlankStrings
   $hits = New-Object System.Collections.ArrayList
   foreach ($m in $script:ValCall.Matches($code)) {
      [void] $hits.Add([pscustomobject]@{ Index = $m.Index; Line = (Get-LineNumber -Text $code -Index $m.Index) })
   }
   return @($hits)
}

function Invoke-BareValSelfTest
{
   $fixture = @(
      'unit fixture;'
      'interface'
      'implementation'
      'procedure T(const s: string);'
      'var n: integer; code: integer;'
      'begin'
      '   Val(s, n, code);                           // HIT'
      '   val (s, n, code);                          // HIT'
      '   if code = 0 then Val(s, n, code);          // HIT'
      '   ValChecked(s, n, code);'
      '   n := Evaluate(s);'
      '   n := Obj.Val(s);'
      '   n := Self.Val (s);'
      '   n := ValidateIt(s);'
      '   n := StrToIntDef(s, 0);'
      '   Log(''Val(s, n, code)'');'
      '   // Val(s, n, code);'
      '   (* Val(s, n, code); *)'
      '   { Val(s, n, code); }'
      'end;'
      'end.'
   )

   $expected = @{}
   for ($i = 0; $i -lt $fixture.Count; $i++) {
      if ($fixture[$i] -match '// HIT$') { $expected[$i + 1] = $true }
   }

   $tmp = Join-Path ([IO.Path]::GetTempPath()) ('lint-bareval-' + [Guid]::NewGuid().ToString('N') + '.pas')
   try {
      [IO.File]::WriteAllText($tmp, ($fixture -join "`r`n") + "`r`n")
      $hits = Find-BareVal -Path $tmp
   }
   finally {
      Remove-Item -LiteralPath $tmp -ErrorAction SilentlyContinue
   }

   $ok = $true
   $seen = @{}
   foreach ($h in $hits) {
      $seen[$h.Line] = $true
      if (-not $expected.ContainsKey($h.Line)) {
         Write-Host ("  self-test: UNEXPECTED hit at fixture line {0}: {1}" -f $h.Line, $fixture[$h.Line - 1].Trim())
         $ok = $false
      }
   }
   foreach ($line in $expected.Keys) {
      if (-not $seen.ContainsKey($line)) {
         Write-Host ("  self-test: MISSED hit at fixture line {0}: {1}" -f $line, $fixture[$line - 1].Trim())
         $ok = $false
      }
   }
   if ($hits.Count -ne $expected.Count) { $ok = $false }
   if ($ok) {
      Write-Host ("Lint-BareVal: self-test OK ({0} expected hits, {1} reported)." -f $expected.Count, $hits.Count)
   }
   return $ok
}

if (-not (Invoke-BareValSelfTest)) {
   Write-Output "Lint-BareVal: SELF-TEST FAILED -- refusing to judge the tree."
   exit 1
}
if ($SelfTest) {
   exit 0
}

if (-not (Test-Path -LiteralPath $SourceDir -PathType Container)) {
   Write-Output "Lint-BareVal: source directory not found: $SourceDir"
   exit 1
}

$files = @(Get-TR4WPascalFiles -Root $SourceDir |
           Where-Object { (Test-Tr4wScannable $_.FullName) -and
                          $_.FullName -notmatch '\\graphify-out\\' })

if (-not ($files | Where-Object { $_.Name -ieq 'MainUnit.pas' })) {
   Write-Output ("Lint-BareVal: MainUnit.pas is not under '{0}' ({1} file(s)) -- wrong -SourceDir? Refusing to report a pass." -f $SourceDir, $files.Count)
   exit 1
}
if ($files.Count -lt $MIN_FILES) {
   Write-Output ("Lint-BareVal: only {0} file(s) scanned (floor {1}). Refusing to report a pass." -f $files.Count, $MIN_FILES)
   exit 1
}

$failures = New-Object System.Collections.ArrayList
$total = 0
$perFile = @{}
foreach ($f in $files) {
   if ($EXEMPT -contains $f.Name) { continue }
   $hits = Find-BareVal -Path $f.FullName
   if ($hits.Count -eq 0) { continue }
   $total += $hits.Count
   $perFile[$f.Name] = $hits.Count
   $lines = [IO.File]::ReadAllLines($f.FullName)
   $allowed = 0
   if ($CEILINGS.ContainsKey($f.Name)) { $allowed = $CEILINGS[$f.Name] }
   if ($List -or $hits.Count -gt $allowed) {
      foreach ($h in $hits) {
         $rel = $f.FullName.Substring($SourceDir.TrimEnd('\').Length).TrimStart('\')
         $text = ("  {0}:{1}  {2}" -f $rel, $h.Line, $lines[$h.Line - 1].Trim())
         if ($hits.Count -gt $allowed) { [void] $failures.Add($text) } else { Write-Output $text }
      }
   }
}

foreach ($name in $CEILINGS.Keys) {
   $have = 0
   if ($perFile.ContainsKey($name)) { $have = $perFile[$name] }
   if ($have -lt $CEILINGS[$name]) {
      [void] $failures.Add(("  {0}: ceiling is {1} but only {2} bare Val call(s) remain -- lower it (delete the row at 0)." -f $name, $CEILINGS[$name], $have))
   }
}

if ($failures.Count -gt 0) {
   $failures | ForEach-Object { Write-Output $_ }
   Write-Output "Lint-BareVal: bare System.Val call(s). On Win64 Val is not range-checked for a"
   Write-Output "  Longint/Cardinal destination (Val('99999999999') gives Code 0 and a truncated value)."
   Write-Output "  Use utils_text.ValChecked -- same arguments, same Code, the range enforced."
   exit 1
}

Write-Output ("Lint-BareVal: {0} file(s) scanned; {1} bare Val call(s), all within a recorded ceiling." -f $files.Count, $total)
exit 0
