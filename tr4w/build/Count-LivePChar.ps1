# Counts LIVE PChar / PAnsiChar / PWideChar mentions in TR4W sources.
#
# WHY THIS EXISTS, and it is the same reason Count-LiveAsm.ps1 does: a raw grep
# is wrong by roughly a factor of ten, and in the direction that makes the
# remaining work look enormous. Measured 2026-09-16 over tr4w\src:
#
#     raw grep                424 mentions across 82 files
#     comment-stripped         44 mentions across 13 units
#
# The difference is not subtle and it is not noise. This tree DOCUMENTS its
# pointer removal heavily -- unit headers, CLAUDE.md-style rationale blocks,
# //AGENT_DEPRECATED lines -- so the word PAnsiChar appears far more often in
# prose ABOUT the work than in code doing it. A reader who greps gets a number
# that says the job has barely started.
#
# Count-LiveAsm exists because a raw count there failed the other way (it
# over-reported too, and its header records that under-reporting "reads as
# progress"). Both scripts answer the same question: what does the COMPILER
# see.
#
#   .\Count-LivePChar.ps1            # summary per file
#   .\Count-LivePChar.ps1 -Detail    # plus every line, so each can be judged
#
# THIS IS A MEASUREMENT, NOT A GATE. It is deliberately not in Run-Lints and
# has no ceiling: the count is not supposed to reach zero. Every remaining
# mention was audited line by line on 2026-09-16 and each is a foreign-API
# declaration or a call into one -- HamLib's C bindings, the Win32 credential
# API, OpenSSL's loader, SetupAPI, fpSymlink (whose RTL declaration takes
# pchar, with no string overload anywhere in FPC 3.2.2), FindResource, and the
# WIDE font entry points. None takes a pointer of a temporary. CLAUDE.md's own
# rule is that a pointer belongs INSIDE the transport where the bytes are
# written, so a floor is the correct end state and a ratchet to zero would be
# a lie about what the code should look like.
#
# WHAT A RISE MEANS. If this number goes up, the question is not "remove it"
# but "is the new one at a real boundary, with its reason beside it". That is
# a judgement, which is why this prints a list rather than a verdict.

param(
   [string] $Root   = (Split-Path -Parent $PSScriptRoot),
   [switch] $Detail
)

# The shared reader -- NOT a local regex. Count-LiveAsm's header records what
# went wrong when this logic was copied instead of shared: a three-line
# `(?s)\{.*?\}` blanked from a brace inside a STRING LITERAL to the next close
# brace, taking live code with it. The same trap is worse here, because a
# PAnsiChar cast sits inside expressions full of quotes.
Import-Module (Join-Path $PSScriptRoot 'PascalSource.psm1') -Force

# Get-TR4WPascalFiles, not a .pas glob, and it matters twice over. It covers
# .lpr -- the PROGRAM files live outside src and hold their own uses clauses --
# and it excludes \include\, which is vendored Indy and Log4D. Those are third
# party: their pointers are not ours to remove and counting them would bury the
# number that can actually be acted on.
$files = Get-TR4WPascalFiles -Root $Root

$total = 0
$units = 0

foreach ($f in $files) {
   $raw   = [IO.File]::ReadAllText($f.FullName)
   $clean = Get-PascalCodeOnlyText -Path $f.FullName
   $hits  = [regex]::Matches($clean, '(?i)\bP(Ansi|Wide)?Char\b')
   if ($hits.Count -eq 0) { continue }

   $total += $hits.Count
   $units++
   $rel = $f.FullName.Substring($Root.Length).TrimStart('\')
   "{0,3}  {1}" -f $hits.Count, $rel

   if ($Detail) {
      $srcLines = $raw -split "`n"
      foreach ($h in $hits) {
         $line = ($clean.Substring(0, $h.Index) -split "`n").Count
         "       {0,6}: {1}" -f $line, $srcLines[$line - 1].Trim()
      }
   }
}

if ($total -eq 0) {
   "Count-LivePChar: no live PChar of any kind."
}
else {
   "Count-LivePChar: {0} live mention(s) across {1} unit(s)." -f $total, $units
}
