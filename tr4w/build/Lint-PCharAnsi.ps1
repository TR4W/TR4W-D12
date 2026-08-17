<#
.SYNOPSIS
   Lints Object Pascal source for PChar casts of addresses and byte-indexing
   that were correct under D7 (PChar = 1-byte AnsiChar) but are silent,
   compiler-invisible bugs wherever PChar is 2-byte PWideChar.

   STILL LIVE UNDER FPC -- the D12 in the old wording made this read like a
   Delphi-era leftover. It is not. tr4w.inc sets {$MODESWITCH UnicodeStrings},
   so PChar is wide under FPC exactly as it was under Delphi 12, and every
   hazard below applies unchanged. Only the name was stale.

.DESCRIPTION
   TR4W's data core is ANSI (ShortString / AnsiChar / on-disk records). With a
   wide PChar, `PChar(@buf)` casts an ANSI buffer to a WIDE pointer, so:
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
# Two INVOCATION MODES, kept apart by explicit parameter sets:
#
#   Lint-PCharAnsi.ps1 a.pas b.pas       <- Files (default): the PostToolUse
#                                           hook and ad-hoc calls, bare paths
#   Lint-PCharAnsi.ps1 -SourceDir src    <- Tree: the msbuild PreBuildEvent
#
# Parameter SETS, not declaration order.  A ValueFromRemainingArguments
# parameter is never given a position, so simply listing $Path first does NOT
# make it positional -- $SourceDir claimed position 0 either way, and
# `Lint-PCharAnsi.ps1 foo.pas` bound foo.pas to -SourceDir and failed with
# "source directory not found".  That broke the pre-existing lint hook.
[CmdletBinding(DefaultParameterSetName = 'Files')]
param(
   [Parameter(ParameterSetName = 'Files', Position = 0,
              ValueFromRemainingArguments = $true)]
   [string[]] $Path,

   [Parameter(ParameterSetName = 'Tree', Mandatory = $true)]
   [string] $SourceDir
)

if ($SourceDir) {
   if (-not (Test-Path -LiteralPath $SourceDir -PathType Container)) {
      Write-Error "Lint-PCharAnsi: source directory not found: $SourceDir"
      exit 2
   }
   # Filter on the EXTENSION, not -Include.  With an absolute -LiteralPath,
   # `-Include *.pas` also matches `uTelnet.pas.bad` and
   # `SysUtils.pas.d7-shadow` -- retired files that are not compiled and never
   # will be -- so the first wired build failed on dead code.  (It does not
   # match them with a RELATIVE path, which is why this passed when run by hand
   # and failed under msbuild.)  `.Extension` is exact and has no such quirk.
   #
   # include\ is VENDORED (Indy, pcre): third-party code we do not own and will
   # not annotate.  Everything under src\ is ours and is linted.
   $Path = @(Get-ChildItem -LiteralPath $SourceDir -Recurse -File |
                Where-Object { $_.Extension -ieq '.pas' -and
                               $_.FullName -notmatch '\\include\\' } |
                Select-Object -ExpandProperty FullName)
}

# The code-only reader MOVED to build\PascalSource.psm1 (2026-08-17), unchanged.
# It was the careful implementation of the three rules below and a second, naive
# copy had grown in Count-LiveAsm.ps1; a third consumer (Lint-Win32Dialogs) made
# it time to lift it out. The module header records what the naive copy got
# wrong. The rules it must not break, kept here because this is the lint whose
# false positives paid for them:
#
#   * `{$IFDEF}` / `(*$...*)` are DIRECTIVES, not comments -- the code they
#     guard is live and must still be linted.
#   * a brace inside a string literal ('{') opens nothing.
#   * `//` inside a string literal ('http://...') comments out nothing.
#
# An earlier version stripped only TRAILING single-line comments, could not see
# a `{ ... }` block spanning lines, and reported four "violations" inside a
# commented-out TS-850 block in LOGRADIO.PAS. A linter that fires on
# commented-out code is one people learn to ignore, which is worse than no
# linter.
Import-Module (Join-Path $PSScriptRoot 'PascalSource.psm1') -Force

Set-Alias Get-CodeOnly Get-PascalCodeOnlyLine

$violations = 0

foreach ($file in $Path) {
   if (-not (Test-Path -LiteralPath $file -PathType Leaf)) { continue }

   $lines = Get-Content -LiteralPath $file
   $state = ''
   for ($i = 0; $i -lt $lines.Count; $i++) {

      $raw = $lines[$i]

      # Sanitize FIRST and unconditionally -- the state machine has to see every
      # line, including ones we go on to skip, or a `{` on a skipped line leaves
      # the scanner out of step for the rest of the file.
      $ref  = [ref] $state
      $code = (Get-CodeOnly -Line $raw -State $ref).TrimEnd()
      $state = $ref.Value

      # Explicit opt-out for a genuinely-wide site.
      if ($raw -match 'lint:wide-ok') { continue }
      if ($code -eq '') { continue }

      # Rule A: PChar(...)[  -- indexing a PChar cast is a byte-walk (2-byte stride when wide).
      if ($code -match '\bPChar\s*\([^)]*\)\s*\[') {
         Write-Output ("{0}:{1}: PChar(...)[i] byte-walk steps 2 bytes when PChar is wide; use PByte for raw bytes or PAnsiChar for ANSI text (line: {2})" -f $file, ($i + 1), $code.Trim())
         $violations++
         continue
      }

      # Rule B: PChar(@...) -- casting an address to a (now wide) PChar.
      if ($code -match '\bPChar\s*\(\s*@') {
         Write-Output ("{0}:{1}: PChar(@...) casts an ANSI buffer to a 2-byte wide pointer; use PAnsiChar (or PByte), or add '// lint:wide-ok' if genuinely wide (line: {2})" -f $file, ($i + 1), $code.Trim())
         $violations++
      }
   }
}

if ($violations -gt 0) { exit 1 }

# Say so on success, like the other two wired lints -- a gate that prints
# nothing when it passes is indistinguishable from one that never ran.
if ($SourceDir) {
   Write-Output ("Lint-PCharAnsi: {0} source files checked, no wide-PChar hazards." -f $Path.Count)
}
exit 0
