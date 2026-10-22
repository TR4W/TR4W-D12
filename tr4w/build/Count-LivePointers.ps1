# Counts LIVE pointer usage in TR4W sources, by category.
#
# WHY THIS EXISTS. docs/POINTER_AUDIT.md (tracking issue #89) inventories every
# DOS/Win32-shaped pointer idiom left in the tree -- hand-built linked lists,
# manual heap, casts, untyped buffers, identities smuggled through Objects[] or
# lParam, old-style objects -- and schedules their removal as packets P1..P16.
# Every packet is measured by this script (packet P0). A raw grep cannot be the
# measure: this tree documents its conversions in prose, so `^`, `@` and
# `Pointer` appear in comments ABOUT the work far more often than in code doing
# it. The same failure Count-LivePChar.ps1 and Count-LiveMove.ps1 record.
#
#   .\Count-LivePointers.ps1                # the per-category table
#   .\Count-LivePointers.ps1 -Detail        # plus every hit, file:line
#   .\Count-LivePointers.ps1 -Rule C3-deref -Detail   # one category's hits
#   .\Count-LivePointers.ps1 -Out hits.tsv  # every hit as a TSV, for triage
#   .\Count-LivePointers.ps1 -SelfTest      # the fixture only
#
# SCOPE. Get-TR4WPascalFiles over tr4w\ (src, tr4wserver, test, tools, build),
# which already skips include\ (vendored Indy, Log4D), backup, target,
# build-out and dcu. Additionally skipped here: graphify-out (a cache) and
# __history (IDE snapshots). Every match is against Get-PascalCodeOnlyText
# -BlankStrings -- comments removed, string-literal contents blanked, {$...}
# directives kept as live code -- NEVER the raw text.
#
# THE RULES are the audit's appendix, verbatim. Their known imprecision is
# stated there and repeated here so nobody trusts a row further than it goes:
# C3-inc-dec-ptr matches integer indices named p...; C3-deref counts a `^` in a
# type declaration too; C6-ptr-named counts every mention, not every type;
# C3-untyped-param can catch a typed parameter split across two lines. The big
# rows (C3-deref, C3-addr-of, C6-ptr-named) say WHERE TO LOOK, not how much
# work there is.
#
# THE FLOOR. A counter reporting 0 because it matched nothing is worse than no
# counter -- CLAUDE.md, "guards must not fail open". So every run, not only
# -SelfTest, first counts a built-in fixture whose hits are known PER RULE, and
# refuses to report a tree number if any rule is not exact. It also refuses
# when the file set does not contain src\MainUnit.pas (what a wrong -Root looks
# like: zero files, zero hits, a green-looking answer), and when the tree total
# is zero.
#
# THIS IS A MEASUREMENT, NOT A GATE. It is not in Run-Lints and has no ceiling.
# The audit's packets move the numbers; this script only reports them.

param(
   [string] $Root   = (Split-Path -Parent $PSScriptRoot),
   [string] $Rule   = '',
   [string] $Out    = '',
   [switch] $Detail,
   [switch] $SelfTest
)

Import-Module (Join-Path $PSScriptRoot 'PascalSource.psm1') -Force

# category -> .NET regex over code-only text. (?i) everywhere: Pascal
# identifiers are case-insensitive. Verbatim from docs/POINTER_AUDIT.md.
$script:Rules = [ordered]@{
   # 1. linked structures
   'C1-ptrtype-decl'   = '(?im)^\s*(\w+)\s*=\s*\^\s*(\w+)\s*;'
   'C1-link-field'     = '(?i)\b(\w*(?:Next|Prev|Previous|Left|Right|Parent|Child|Link|Sibling)\w*)\s*:\s*(\^\s*\w+|\w*Ptr\b|\w*Pointer\b|P[A-Z]\w*)'
   # 2. manual heap
   'C2-heap'           = '(?i)(?<![\w.])(GetMem|FreeMem|ReallocMem|ReAllocMem|AllocMem|StrAlloc|StrDispose|StrNew|GlobalAlloc|GlobalFree|LocalAlloc|LocalFree|VirtualAlloc|HeapAlloc|HeapFree|GetMemory|FreeMemory)\s*\('
   'C2-new-dispose'    = '(?i)(?<![\w.])(New|Dispose)\s*\('
   # 3. pointer arithmetic, casts, untyped parameters
   'C3-pointer-cast'   = '(?i)(?<![\w.])Pointer\s*\('
   'C3-int-of-ptr'     = '(?i)(?<![\w.])(Integer|Cardinal|LongInt|LongWord|DWORD|DWord|NativeInt|NativeUInt|PtrInt|PtrUInt|SizeInt|SizeUInt|Int64|QWord)\s*\(\s*(@|Pointer\s*\(|Self\b|Sender\b|\w*(Ptr|P|Pointer)\s*\))'
   'C3-typed-ptr-type' = '(?i)(?<![\w.])(PByte|PWord|PInteger|PCardinal|PLongInt|PLongWord|PDWORD|PSmallInt|PShortInt|PBoolean|PSingle|PDouble|PInt64|PQWord|PPointer|PByteArray|PWordArray|PIntegerArray|PtrUInt|PtrInt)\b'
   'C3-addr-of'        = '(?i)(?<![\w.@])@\s*[A-Za-z_]'
   'C3-deref'          = '(?i)[\w\])]\s*\^'
   'C3-inc-dec-ptr'    = '(?i)(?<![\w.])(Inc|Dec)\s*\(\s*(P\w*|\w*Ptr|\w*Pointer)\s*[,)]'
   'C3-untyped-param'  = '(?i)[(;]\s*(?:var|const|out|constref)\s+\w+(?:\s*,\s*\w+)*\s*(?=[;)])'
   'C3-memcmp'         = '(?i)(?<![\w.])(CompareMem|CompareByte|CompareWord|CompareDWord|FillByte|FillWord|FillDWord|IndexByte)\s*\('
   'C3-s1'             = '(?i)@\s*\w+(\.\w+)*\s*\[\s*(1|0)\s*\]'
   # 5. an identity carried by a pointer, a tag or a message parameter
   'C5-tobject-cast'   = '(?i)(?<![\w.])TObject\s*\('
   'C5-objects'        = '(?i)\.Objects\s*\[|\bAddObject\s*\(|\bInsertObject\s*\('
   'C5-tag'            = '(?i)\.Tag\b'
   'C5-lparam'         = '(?i)\b(lParam|wParam|LPARAM|WPARAM)\b'
   'C5-data'           = '(?i)\.Data\s*:=|\bTNode\b|\.Data\s*\)'
   # 6. old-style objects and pointer-to-record plumbing
   'C6-object-type'    = '(?i)=\s*(packed\s+)?object\b'
   'C6-ptr-named'      = '(?i)\b\w+Ptr\b'
   # 7. procedure variables and untyped code pointers
   'C7-proc-type'      = '(?i)=\s*(reference\s+to\s+)?(procedure|function)\b'
   'C7-pointer-word'   = '(?i)(?<![\w.])Pointer\b(?!\s*\()'
}

# Compiled once; the tree is ~800 files and 22 rules.
$script:Compiled = [ordered]@{}
foreach ($k in $script:Rules.Keys) {
   $script:Compiled[$k] = [regex]::new($script:Rules[$k])
}

# Returns one object per hit in a file: Rule, Line, Match.
function Get-LivePointerHits
{
   param([Parameter(Mandatory = $true)][string] $Path)

   $clean = Get-PascalCodeOnlyText -Path $Path -BlankStrings

   # Line starts from ONE native regex pass, then a binary search per hit.
   # Not a character loop: PascalSource.psm1 records what char-at-a-time
   # PowerShell costs over this tree under 5.1 -- minutes, which reads as a hang.
   $lineStarts = New-Object 'System.Collections.Generic.List[int]'
   $lineStarts.Add(0)
   foreach ($nl in [regex]::Matches($clean, "`n")) {
      $lineStarts.Add($nl.Index + 1)
   }

   $result = New-Object 'System.Collections.Generic.List[object]'
   foreach ($k in $script:Compiled.Keys) {
      foreach ($m in $script:Compiled[$k].Matches($clean)) {
         $idx = $lineStarts.BinarySearch($m.Index)
         if ($idx -lt 0) {
            $idx = (-bnot $idx) - 1
         }
         $result.Add([pscustomobject]@{
            Rule  = $k
            Line  = $idx + 1
            Match = (($m.Value -replace '\s+', ' ').Trim())
         })
      }
   }
   return $result
}

# THE FIXTURE. Every rule has a known, non-zero count, and every line after
# `end;` of the live block is a trap the counter must not fall into. The
# expected table is checked rule by rule, so a rule that silently stops
# matching fails here rather than reporting a smaller number.
function Invoke-LivePointerSelfTest
{
   $fixture = @(
      "unit fixture;",
      "type",
      "   PNode = ^TNode;",
      "   TNode = record Next: PNode; end;",
      "   TOld = object end;",
      "   TCb = procedure(var buf);",
      "var NodePtr: PNode; p: Pointer;",
      "begin",
      "   New(NodePtr); GetMem(p, 4);",
      "   NodePtr^.Next := nil; p := Pointer(NodePtr);",
      "   i := Integer(@x); q := @y[1];",
      "   Inc(pBuf, 2); b := PByte(p)^; Dispose(NodePtr);",
      "   if CompareMem(a, b, 4) then o := TObject(i);",
      "   L.AddObject('x', o); L.Objects[0] := nil; Tag := Form.Tag;",
      "   SendMessage(h, 0, wParam, lParam); Item.Data := nil;",
      "   // New(NodePtr); p^ := 1; @x                 line comment",
      "   s := 'Dispose(p) @x ^ Pointer( TObject(';     // string literal",
      "   t := 'it''s GetMem(p, 1)';                    // a doubled quote",
      "   (* GetMem(p, 1); TObject(x); AddObject(",
      "      FooPtr^ := nil; *)",
      "   { NodePtr^ := nil; }",
      "   NewItem(1); Renew(x); List.New(x); Obj.Dispose(1);",
      "end."
   )
   $expected = [ordered]@{
      'C1-ptrtype-decl'   = 1
      'C1-link-field'     = 1
      'C2-heap'           = 1
      'C2-new-dispose'    = 2
      'C3-pointer-cast'   = 1
      'C3-int-of-ptr'     = 1
      'C3-typed-ptr-type' = 1
      'C3-addr-of'        = 2
      'C3-deref'          = 2
      'C3-inc-dec-ptr'    = 1
      'C3-untyped-param'  = 1
      'C3-memcmp'         = 1
      'C3-s1'             = 1
      'C5-tobject-cast'   = 1
      'C5-objects'        = 2
      'C5-tag'            = 1
      'C5-lparam'         = 2
      'C5-data'           = 1
      'C6-object-type'    = 1
      'C6-ptr-named'      = 5
      'C7-proc-type'      = 1
      'C7-pointer-word'   = 1
   }

   $tmp = Join-Path ([IO.Path]::GetTempPath()) ("livepointers_" + [Guid]::NewGuid().ToString('N') + ".pas")
   try {
      [IO.File]::WriteAllText($tmp, ($fixture -join "`r`n"))
      $got = @(Get-LivePointerHits -Path $tmp)
   }
   finally {
      if (Test-Path -LiteralPath $tmp) {
         Remove-Item -LiteralPath $tmp -Force
      }
   }

   $ok = $true
   foreach ($k in $script:Rules.Keys) {
      if (-not $expected.Contains($k)) {
         Write-Output ("Count-LivePointers SELFTEST FAIL: rule {0} has no expected count in the fixture." -f $k)
         $ok = $false
         continue
      }
      $hits = @($got | Where-Object { $_.Rule -eq $k })
      if ($hits.Count -ne $expected[$k]) {
         $ok = $false
         Write-Output ("Count-LivePointers SELFTEST FAIL: {0} expected {1}, got {2}:" -f $k, $expected[$k], $hits.Count)
         foreach ($h in $hits) {
            Write-Output ("   fixture line {0}: '{1}'   <- {2}" -f $h.Line, $h.Match, $fixture[$h.Line - 1].Trim())
         }
      }
   }
   return $ok
}

# The audit's columns: where a hit lives decides who owns it.
function Get-PointerArea
{
   param([string] $Relative)

   if ($Relative -match '^src\\') {
      return 'src'
   }
   if ($Relative -match '^tr4wserver\\') {
      return 'server'
   }
   if ($Relative -match '^test\\') {
      return 'test'
   }
   return 'other'
}

# ---------------------------------------------------------------------------

if (-not (Invoke-LivePointerSelfTest)) {
   Write-Output 'Count-LivePointers: the fixture is wrong, so no tree count is reported.'
   exit 1
}
if ($SelfTest) {
   Write-Output ('Count-LivePointers SELFTEST: all {0} rules counted the fixture exactly; every trap ignored.' -f $script:Rules.Count)
   exit 0
}
if ($Rule -and -not $script:Rules.Contains($Rule)) {
   Write-Output ("Count-LivePointers: no rule named '{0}'. Rules: {1}" -f $Rule, ($script:Rules.Keys -join ', '))
   exit 1
}

$Root  = (Resolve-Path -LiteralPath $Root).Path.TrimEnd('\')
$files = @(Get-TR4WPascalFiles -Root $Root | Where-Object {
   $_.FullName -notmatch '\\graphify-out\\|\\__history\\' })

# The second floor: a wrong -Root scans nothing and reports a clean zero.
if (-not ($files | Where-Object { $_.FullName -match '\\src\\MainUnit\.pas$' })) {
   Write-Output ("Count-LivePointers: src\MainUnit.pas is not under '{0}' -- wrong -Root? Refusing to report." -f $Root)
   exit 1
}

$areas  = @('src', 'server', 'test', 'other')
$counts = @{}
foreach ($k in $script:Rules.Keys) {
   $counts[$k] = @{ src = 0; server = 0; test = 0; other = 0 }
}

$tsv = $null
if ($Out) {
   $tsv = New-Object System.Text.StringBuilder
   [void]$tsv.AppendLine("rule`tfile`tline`tmatch`tsource")
}

$grand = 0
foreach ($f in $files) {
   $hits = @(Get-LivePointerHits -Path $f.FullName)
   if ($hits.Count -eq 0) {
      continue
   }
   $rel  = $f.FullName.Substring($Root.Length).TrimStart('\')
   $area = Get-PointerArea -Relative $rel
   $srcLines = $null
   if ($Detail -or $tsv) {
      $srcLines = [IO.File]::ReadAllLines($f.FullName)
   }
   foreach ($h in $hits) {
      $counts[$h.Rule][$area]++
      $grand++
      if ($Rule -and ($h.Rule -ne $Rule)) {
         continue
      }
      if ($Detail -or $tsv) {
         $src = ''
         if ($h.Line -le $srcLines.Count) {
            $src = $srcLines[$h.Line - 1].Trim() -replace "`t", ' '
         }
         if ($Detail) {
            "{0,-18} {1}:{2}: {3}" -f $h.Rule, $rel, $h.Line, $src
         }
         if ($tsv) {
            [void]$tsv.AppendLine(("{0}`t{1}`t{2}`t{3}`t{4}" -f $h.Rule, $rel, $h.Line, $h.Match, $src))
         }
      }
   }
}

# The third floor: a tree this size with no pointer usage at all is a broken
# reader, not a finished audit.
if ($grand -eq 0) {
   Write-Output 'Count-LivePointers: zero hits across the tree -- the reader is broken. Refusing to report.'
   exit 1
}

if ($tsv) {
   [IO.File]::WriteAllText($Out, $tsv.ToString())
   "Hits written to {0}" -f $Out
}

""
"{0,-18} {1,7} {2,7} {3,7} {4,7} {5,7}" -f 'rule', 'src', 'server', 'test', 'other', 'total'
foreach ($k in $script:Rules.Keys) {
   if ($Rule -and ($k -ne $Rule)) {
      continue
   }
   $c = $counts[$k]
   $t = $c.src + $c.server + $c.test + $c.other
   "{0,-18} {1,7} {2,7} {3,7} {4,7} {5,7}" -f $k, $c.src, $c.server, $c.test, $c.other, $t
}
""
"Count-LivePointers: {0} hit(s) across {1} file(s) scanned." -f $grand, $files.Count
