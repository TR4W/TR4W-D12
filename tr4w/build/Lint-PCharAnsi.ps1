<#
.SYNOPSIS
   Lints Object Pascal source for D12-hazardous PChar casts of addresses and
   byte-indexing that were correct under D7 (PChar = 1-byte AnsiChar) but are
   silent, compiler-invisible bugs under D12 (PChar = 2-byte PWideChar).

.DESCRIPTION
   TR4W's data core is ANSI (ShortString / AnsiChar / on-disk records). Under
   D12, `PChar(@buf)` casts an ANSI buffer to a WIDE pointer, so:
     * `PChar(@rec)[i]` byte-walks step 2 bytes -> over-read / miscompare
       (this is exactly the RadioInfo-UDP-flood regression).
     * `PChar(@buf)` handed to a byte/ANSI consumer misreads the data.
   Prefer PAnsiChar for ANSI text, or PByte for raw byte walks.

   Deliberately narrow to keep false positives low: only the two address-cast
   / index patterns are flagged, not every `: PChar` declaration (those are
   handled by the one-time audit).  A genuinely-wide site can opt out with an
   inline `// lint:wide-ok` comment on the same line.

.PARAMETER Path
   One or more Pascal files to lint.

.OUTPUTS
   One line per violation:  <file>:<line>: <message>
   Exit code 0 = clean, 1 = at least one violation (handy for CI).
#>
[CmdletBinding()]
param(
   [Parameter(ValueFromRemainingArguments = $true)]
   [string[]] $Path
)

$violations = 0

foreach ($file in $Path) {
   if (-not (Test-Path -LiteralPath $file -PathType Leaf)) { continue }

   $lines = Get-Content -LiteralPath $file
   for ($i = 0; $i -lt $lines.Count; $i++) {

      $raw = $lines[$i]

      # Explicit opt-out for a genuinely-wide site.
      if ($raw -match 'lint:wide-ok') { continue }

      # Strip trailing comments, then trim (same approach as the begin/end linter).
      $code = $raw
      $code = $code -replace '//.*$', ''
      $code = $code -replace '\{[^}]*\}\s*$', ''
      $code = $code -replace '\(\*.*?\*\)\s*$', ''
      $code = $code.TrimEnd()
      if ($code -eq '') { continue }

      # Rule A: PChar(...)[  -- indexing a PChar cast is a byte-walk (2-byte stride in D12).
      if ($code -match '\bPChar\s*\([^)]*\)\s*\[') {
         Write-Output ("{0}:{1}: PChar(...)[i] byte-walk steps 2 bytes in D12; use PByte for raw bytes or PAnsiChar for ANSI text (line: {2})" -f $file, ($i + 1), $code.Trim())
         $violations++
         continue
      }

      # Rule B: PChar(@...) -- casting an address to a (now wide) PChar.
      if ($code -match '\bPChar\s*\(\s*@') {
         Write-Output ("{0}:{1}: PChar(@...) casts an ANSI buffer to a 2-byte wide pointer in D12; use PAnsiChar (or PByte), or add '// lint:wide-ok' if genuinely wide (line: {2})" -f $file, ($i + 1), $code.Trim())
         $violations++
      }
   }
}

if ($violations -gt 0) { exit 1 } else { exit 0 }
