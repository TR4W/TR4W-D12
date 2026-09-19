# Counts LIVE raw-memory calls -- Move, FillChar, and their relatives -- in
# TR4W sources.
#
# WHY THIS EXISTS. docs/MODERNIZATION_ROADMAP.md section 4.1 (the portability
# axis) triages every Move / FillChar / ZeroMemory site into three shapes:
#
#   (a) a record or buffer clear      -> field initialisation
#   (b) a string copy                 -> plain assignment
#   (c) genuine byte framing          -> TBytes
#
# NY4I's rule, from docs/64_BIT_TASKLIST.md: byte I/O stays byte I/O, but Move
# is not how to express it. The triage needs a number it can trust, and the raw
# grep is not one: this tree documents its conversions in prose, so the word
# Move appears in comments ABOUT the work far more often than in code doing it.
# That is the same failure Count-LivePChar.ps1 and Count-LiveAsm.ps1 record.
#
#   .\Count-LiveMove.ps1             # summary per file, per routine, raw vs live
#   .\Count-LiveMove.ps1 -Detail     # plus every line, so each can be triaged
#   .\Count-LiveMove.ps1 -SelfTest   # the fixture only
#
# WHAT IT COUNTS. The routines below, called bare or qualified by a unit name
# (System.Move, Windows.ZeroMemory). Chosen by grepping the tree, not by guess:
#
#   Move, FillChar                     the RTL pair; nearly every live hit
#   ZeroMemory, CopyMemory,            the Win32 macros over them. Measured
#   MoveMemory, FillMemory,            2026-09-18 they occur ONLY in comments,
#   RtlMoveMemory, RtlZeroMemory       which is why they are counted: a new one
#                                      should show up, not hide
#   FillByte, FillWord,                the RTL's typed fills. None in the tree;
#   FillDWord, FillQWord               counted for the same reason
#
# WHAT IT DOES NOT COUNT, on purpose:
#
#   * a METHOD called Move -- `List.Move(i, j)`, `procedure TFoo.Move`. Only a
#     unit qualifier (System., Windows., SysUtils.) is allowed before the name.
#     TList.Move reorders items; it is not raw memory.
#   * look-alike identifiers -- MoveTo, MoveWindow, RemoveX, OnMouseMove. The
#     match is word-bounded.
#   * StrPCopy / StrPLCopy / StrLCopy. They copy a string INTO a character
#     buffer, which is the PChar audit's territory (Count-LivePChar.ps1) and a
#     different conversion: the buffer itself is what goes, not the call.
#
# THE FLOOR. A counter reporting 0 because it matched nothing is worse than no
# counter -- CLAUDE.md, "guards must not fail open". So every run, not only
# -SelfTest, first counts a built-in fixture whose live calls are known, and
# refuses to report a tree number if that is not exact. It also refuses when
# the file set does not contain src\MainUnit.pas, which is what a wrong -Root
# looks like: zero files, zero hits, and a green-looking answer.
#
# THIS IS A MEASUREMENT, NOT A GATE. It is not in Run-Lints and has no ceiling.
# The count is not supposed to reach zero on its own schedule: each site is
# converted by the specialist who owns it, and a (c) byte-framing site becomes
# TBytes, not nothing.

param(
   [string] $Root   = (Split-Path -Parent $PSScriptRoot),
   [switch] $Detail,
   [switch] $SelfTest
)

# The shared reader, with -BlankStrings: a string literal that reads
# 'Move failed' is not a call. See PascalSource.psm1 for why the reader is
# shared rather than copied.
Import-Module (Join-Path $PSScriptRoot 'PascalSource.psm1') -Force

$ROUTINES = @(
   'Move', 'FillChar',
   'ZeroMemory', 'CopyMemory', 'MoveMemory', 'FillMemory',
   'RtlMoveMemory', 'RtlZeroMemory',
   'FillByte', 'FillWord', 'FillDWord', 'FillQWord'
)

$alt = ($ROUTINES -join '|')

# LIVE: not preceded by a word character or a dot, EXCEPT a unit qualifier.
# The optional qualifier is matched FIRST so `System.Move` is one hit, not
# rejected for its dot.
$script:LiveRx = [regex]::new(
   '(?i)(?<![\w.])(?:(?:System|Windows|SysUtils)\s*\.\s*)?\b(' + $alt + ')\b(?!\s*\.)',
   [System.Text.RegularExpressions.RegexOptions]::None)

# RAW: what a hand-run `grep -iw` sees -- every word-bounded mention, in
# comments, strings and method names alike. Printed beside the live number so
# the over-report is measured rather than asserted.
$script:RawRx = [regex]::new('(?i)\b(' + $alt + ')\b')

# Returns one object per live hit in a file.
function Get-LiveMoveHits
{
   param([Parameter(Mandatory = $true)][string] $Path)

   $clean = Get-PascalCodeOnlyText -Path $Path -BlankStrings
   $hits  = $script:LiveRx.Matches($clean)
   if ($hits.Count -eq 0) { return @() }

   # Line starts from ONE native regex pass, then a binary search per hit.
   # Not a character loop: PascalSource.psm1 records what char-at-a-time
   # PowerShell costs over this tree under 5.1 -- minutes, which reads as a hang.
   $lineStarts = New-Object 'System.Collections.Generic.List[int]'
   $lineStarts.Add(0)
   foreach ($nl in [regex]::Matches($clean, "`n")) {
      $lineStarts.Add($nl.Index + 1)
   }

   $result = @()
   foreach ($h in $hits) {
      $lo = 0; $hi = $lineStarts.Count - 1
      while ($lo -lt $hi) {
         $mid = [int][math]::Ceiling(($lo + $hi) / 2)
         if ($lineStarts[$mid] -le $h.Index) { $lo = $mid } else { $hi = $mid - 1 }
      }
      $result += [pscustomobject]@{
         Line    = $lo + 1
         Routine = $h.Groups[1].Value
      }
   }
   return $result
}

# THE FIXTURE. Each line says what it is. Exactly SIX are live and they are
# marked LIVE; everything else is a trap the counter must not fall into.
function Invoke-LiveMoveSelfTest
{
   $fixture = @(
      "unit fixture;",
      "procedure P;",
      "begin",
      "   Move(a, b, SizeOf(a));                    // LIVE 1",
      "   FillChar(r, SizeOf(r), 0);                // LIVE 2",
      "   System.Move(a, b, 4);                     // LIVE 3 -- qualified",
      "   windows.ZeroMemory(@r, SizeOf(r));        // LIVE 4 -- qualified, lower case",
      "   fillchar (r, 4, 0); MOVE(x, y, 1);        // LIVE 5 and 6 -- case, space before paren",
      "   // Move(a, b, 4);                         line comment",
      "   { FillChar(r, SizeOf(r), 0); }            brace comment",
      "   (* ZeroMemory(@r, 4);",
      "      Move(a, b, 4); *)                      multi-line paren comment",
      "   {",
      "   CopyMemory(@a, @b, 4);",
      "   }",
      "   s := 'Move(a, b, 4) failed';              // string literal",
      "   t := 'it''s FillChar(x)';                 // string with a doubled quote",
      "   List.Move(1, 2);                          // a METHOD, not raw memory",
      "   MoveTo(1, 2); MoveWindow(h); RemoveX;     // look-alikes",
      "   OnMouseMove := nil; FillCharacter := 1;   // look-alikes",
      "   Move.Foo := 1;                            // Move as a record, not a call",
      "end;",
      "procedure TFoo.Move(i: integer);             // a method declaration",
      "begin",
      "end;"
   )
   $expected = 6

   $tmp = Join-Path ([IO.Path]::GetTempPath()) ("livemove_" + [Guid]::NewGuid().ToString('N') + ".pas")
   try {
      [IO.File]::WriteAllText($tmp, ($fixture -join "`r`n"))
      $got = @(Get-LiveMoveHits -Path $tmp)
   }
   finally {
      if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Force }
   }

   $ok = ($got.Count -eq $expected)
   if (-not $ok) {
      Write-Output ("Count-LiveMove SELFTEST FAIL: expected {0} live call(s), got {1}:" -f $expected, $got.Count)
      foreach ($g in $got) {
         Write-Output ("   fixture line {0}: {1}   <- {2}" -f $g.Line, $g.Routine, $fixture[$g.Line - 1].Trim())
      }
   }
   return $ok
}

# ---------------------------------------------------------------------------

if (-not (Invoke-LiveMoveSelfTest)) {
   Write-Output 'Count-LiveMove: the fixture is wrong, so no tree count is reported.'
   exit 1
}
if ($SelfTest) {
   Write-Output 'Count-LiveMove SELFTEST: the fixture''s 6 live calls counted exactly; every trap ignored.'
   exit 0
}

$files = Get-TR4WPascalFiles -Root $Root

# The second floor: a wrong -Root scans nothing and reports a clean zero.
if (-not ($files | Where-Object { $_.Name -ieq 'MainUnit.pas' })) {
   Write-Output ("Count-LiveMove: src\MainUnit.pas is not under '{0}' -- wrong -Root? Refusing to report." -f $Root)
   exit 1
}

$total     = 0
$rawTotal  = 0
$rawFiles  = 0
$units     = 0
$byRoutine = @{}

foreach ($f in $files) {
   $raw     = [IO.File]::ReadAllText($f.FullName)
   $rawHits = $script:RawRx.Matches($raw).Count
   if ($rawHits -gt 0) { $rawTotal += $rawHits; $rawFiles++ }

   $hits = @(Get-LiveMoveHits -Path $f.FullName)
   if ($hits.Count -eq 0) { continue }

   $total += $hits.Count
   $units++
   foreach ($h in $hits) {
      $key = $h.Routine.ToLowerInvariant()
      if ($byRoutine.ContainsKey($key)) { $byRoutine[$key]++ } else { $byRoutine[$key] = 1 }
   }

   $rel = $f.FullName.Substring($Root.Length).TrimStart('\')
   "{0,3}  {1}" -f $hits.Count, $rel

   if ($Detail) {
      $srcLines = $raw -split "`n"
      foreach ($h in $hits) {
         "       {0,6}: {1}" -f $h.Line, $srcLines[$h.Line - 1].Trim()
      }
   }
}

""
"By routine (live):"
foreach ($r in $ROUTINES) {
   $n = 0
   if ($byRoutine.ContainsKey($r.ToLowerInvariant())) { $n = $byRoutine[$r.ToLowerInvariant()] }
   "   {0,-14} {1,4}" -f $r, $n
}
""
"Raw grep (word-bounded, comments and strings included): {0} mention(s) across {1} file(s)." -f $rawTotal, $rawFiles
"Count-LiveMove: {0} live call(s) across {1} unit(s)." -f $total, $units
