<#
.SYNOPSIS
   Catches a {$DIRECTIVE} quoted inside a { } comment, which ends the comment.

.DESCRIPTION
   A brace comment ends at the FIRST '}' it meets. So prose that quotes a
   directive --

       { ... behind one {$IFDEF WINDOWS} -- which is a change of position ... }

   -- closes at the directive's own brace, and everything after it becomes code.
   The compiler then reports a syntax error somewhere that looks unrelated to
   what was written:

       uPlatformProcess.pas(50,79) Fatal: Syntax error, "INTERFACE" expected but "-" found

   THAT IS A REAL BUILD BREAK FROM 2026-09-16, written while adding a paragraph
   ABOUT platform gates to a unit header. CLAUDE.md states the rule three ways
   -- every block comment uses (* *), never { } -- and it was still broken,
   which is the argument for a gate rather than another sentence.

   THE RULE IS NARROWER THAN "A DIRECTIVE IN A BRACE COMMENT", and vendored
   Indy is why. Indy comments out code containing directives by STRIPPING THE
   CLOSING BRACES:

       {
       LTerm := ToBytes(ATerminator, AByteEncoding
         {$IFDEF STRING_IS_ANSI, ADestEncoding{$ENDIF
         );
       }

   No '}' on those lines, so the enclosing comment survives to its own close and
   the unit compiles -- three such sites in IdIOHandler and IdNTLMv2 were the
   first thing this lint reported, and all three were working code. What is a
   defect is a directive that CLOSES ON THE SAME LINE: that brace ends the
   comment where it stands, and the prose after it becomes code.

   WHY NOT JUST LET THE COMPILER CATCH IT. It does, eventually, with a message
   that names neither the comment nor the directive and points at a column in
   a line that looks fine. This names the file, the line and the directive.

   WHAT IS NOT FLAGGED, deliberately:
     * a directive ON ITS OWN -- {$IFDEF WINDOWS} as code is the normal case;
     * a directive inside a (* *) comment -- that is the form CLAUDE.md asks
       for, and a '}' does not end it;
     * a '{' that opens a directive rather than a comment: {$I ..\tr4w.inc} is
       a directive, not a comment, so nothing inside it is scanned.

   THE SCAN IS A STATE MACHINE, not a regex, because "is this { a comment or a
   directive" and "am I inside a string literal" cannot be answered line by
   line. It mirrors the rules in PascalSource.psm1: a string literal is matched
   first so a brace inside one opens nothing, then {$...} and (*$...*) are
   directives, then { }, (* *) and // are comments.
#>
param(
   [string] $SourceDir
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Get-ScanExclusions.ps1')   # Test-Tr4wScannable

if (-not $SourceDir) {
   $SourceDir = Split-Path -Parent $PSScriptRoot
}

if (-not (Test-Path -LiteralPath $SourceDir -PathType Container)) {
   Write-Output "Lint-BraceComments: source directory not found: $SourceDir"
   exit 1
}

$extensions = @('.pas', '.lpr', '.dpr', '.dpk', '.inc')
$skipDir    = '\\\.git\\|\\build-out\\|\\graphify-out\\|\\release\\|\\backup|\\dcu'

$files = @(Get-ChildItem -LiteralPath $SourceDir -Recurse -File -ErrorAction SilentlyContinue |
           Where-Object { Test-Tr4wScannable $_.FullName } |
           Where-Object { $extensions -contains $_.Extension.ToLowerInvariant() -and
                          $_.FullName -notmatch $skipDir })

# A GUARD THAT MATCHES NOTHING MUST NOT PASS -- the same floor every other lint
# here carries, and the trap this session walked into with a corpus run that
# exported nothing and still exited 0.
if ($files.Count -eq 0) {
   Write-Output "Lint-BraceComments: NO files found under $SourceDir -- refusing to report a pass."
   exit 1
}

function Find-DirectiveInBraceComment {
   param([string[]] $Lines)

   $hits = @()
   $inBrace  = $false      # inside a { } comment
   $inParen  = $false      # inside a (* *) comment
   $openLine = 0

   for ($i = 0; $i -lt $Lines.Count; $i++) {
      $line = $Lines[$i]
      $p = 0
      while ($p -lt $line.Length) {
         $c = $line[$p]
         $next = if ($p + 1 -lt $line.Length) { $line[$p + 1] } else { [char]0 }

         if ($inBrace) {
            # A directive inside an open brace comment -- but only a defect if
            # it CLOSES on this line, because that '}' ends the comment and the
            # prose after it becomes code.
            if ($c -eq '{' -and $next -eq '$') {
               $end = $line.IndexOf('}', $p)
               if ($end -lt 0) {
                  # NO CLOSING BRACE: the comment survives, so nothing is
                  # broken. This is the vendored-Indy idiom -- code commented
                  # out with the directives' closing braces deliberately
                  # stripped, e.g.
                  #     {$IFDEF STRING_IS_ANSI, ADestEncoding{$ENDIF
                  # inside a { } block. Those units compile; flagging them
                  # would be a lint that fires on working code.
                  $p += 2
                  continue
               }
               $hits += [pscustomobject]@{
                  Line      = $i + 1
                  OpenedAt  = $openLine
                  Directive = $line.Substring($p, $end - $p + 1)
               }
               # The comment ends at that brace -- which IS the defect -- so
               # carry on scanning as code from just after it.
               $inBrace = $false
               $p = $end + 1
               continue
            }
            if ($c -eq '}') { $inBrace = $false; $p++; continue }
            $p++
            continue
         }

         if ($inParen) {
            if ($c -eq '*' -and $next -eq ')') { $inParen = $false; $p += 2; continue }
            $p++
            continue
         }

         # Not in a comment: a string literal first, so a brace inside one
         # opens nothing.
         if ($c -eq "'") {
            $p++
            while ($p -lt $line.Length) {
               if ($line[$p] -eq "'") {
                  if (($p + 1 -lt $line.Length) -and ($line[$p + 1] -eq "'")) { $p += 2; continue }
                  $p++
                  break
               }
               $p++
            }
            continue
         }

         if ($c -eq '/' -and $next -eq '/') { break }   # rest of line is a comment

         if ($c -eq '{') {
            if ($next -eq '$') {
               # A DIRECTIVE, not a comment. Skip to its close.
               $end = $line.IndexOf('}', $p)
               $p = if ($end -ge 0) { $end + 1 } else { $line.Length }
               continue
            }
            $inBrace  = $true
            $openLine = $i + 1
            $p++
            continue
         }

         if ($c -eq '(' -and $next -eq '*') {
            # (*$...*) is a directive; (* ... *) is a comment. Either way a
            # '}' inside it is harmless, so both are skipped the same way.
            $inParen = $true
            $p += 2
            continue
         }

         $p++
      }
   }
   return $hits
}

$violations = @()
foreach ($f in $files) {
   $lines = [IO.File]::ReadAllLines($f.FullName)
   foreach ($hit in (Find-DirectiveInBraceComment -Lines $lines)) {
      $violations += ("{0}:{1}  {2}   (comment opened at line {3})" -f
                      $f.Name, $hit.Line, $hit.Directive, $hit.OpenedAt)
   }
}

if ($violations.Count -gt 0) {
   $violations | ForEach-Object { Write-Output ("  " + $_) }
   Write-Output "Lint-BraceComments: a directive is quoted inside a { } comment, which ENDS it."
   Write-Output "  The '}' closes the comment and the rest of the prose becomes code, so the"
   Write-Output "  compiler reports a syntax error somewhere that looks unrelated."
   Write-Output "  Fix: write the directive without its braces in prose (IFDEF WINDOWS), or make"
   Write-Output "  the comment (* *) -- which is what CLAUDE.md asks for in the first place."
   exit 1
}

Write-Output ("Lint-BraceComments: {0} file(s) checked, no directive quoted inside a brace comment." -f $files.Count)
exit 0
