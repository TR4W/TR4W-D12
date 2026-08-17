# Reading Pascal source the way the COMPILER sees it -- comments and string
# literals removed, directives kept.
#
# WHY THIS IS A MODULE. Three consumers needed it and two had already written
# their own, which had drifted in a way that matters:
#
#   * Lint-PCharAnsi.ps1 carried the careful version below. Its own header
#     records why: an earlier version stripped only TRAILING `//` comments, fired
#     on four "violations" inside a commented-out TS-850 block in LOGRADIO.PAS,
#     "and a linter that fires on commented-out code is one people learn to
#     ignore, which is worse than no linter."
#   * Count-LiveAsm.ps1 carried a three-line regex version instead. It blanks
#     `(?s)\{.*?\}` unconditionally, so a `{` inside a STRING LITERAL opens a
#     comment that runs to the next `}` -- silently blanking live code. For a
#     counter whose whole job is "how much inline asm is left", that fails OPEN:
#     it under-reports, and under-reporting reads as progress.
#
# The fix that had been made once never reached the copy that needed it, which
# is the ordinary way this goes. Both now call in here, and so does
# Lint-Win32Dialogs.ps1, whose burn-down counts would have the same fail-open
# shape as the asm counter.
#
# Three things this must not get wrong:
#   * `{$IFDEF}` / `(*$...*)` are DIRECTIVES, not comments -- the code they guard
#     is live and must still be seen.
#   * a brace inside a string literal ('{') opens nothing.
#   * `//` inside a string literal ('http://...') comments out nothing.

Set-StrictMode -Version Latest

# One line, carrying block-comment state across calls.
# $State is a [ref] holding '' | '{' | '(*'.
function Get-PascalCodeOnlyLine
{
   param(
      [Parameter(Mandatory = $true)][AllowEmptyString()][string] $Line,
      [Parameter(Mandatory = $true)][ref] $State
   )

   $out = New-Object System.Text.StringBuilder
   $i = 0
   $inStr = $false

   while ($i -lt $Line.Length) {
      $c  = $Line[$i]
      $c2 = if ($i + 1 -lt $Line.Length) { $Line[$i + 1] } else { "`0" }

      # IF/ELSEIF, NOT switch. `continue` inside a PowerShell `switch` continues
      # the SWITCH, not the enclosing loop -- so the original (a switch with
      # `$i++; continue` in each arm) fell through to the rest of the loop body
      # and appended the very character it had just stepped over. The effect was
      # every OTHER character of a block comment surviving into the "code-only"
      # text:
      #
      #   raw   "          assume this to be the precedence. }"
      #   code  "     asm hst etepeeec.}"
      #
      # which is where Count-LiveAsm's two phantom asm blocks came from
      # (LOGSTUFF.PAS:3005 and networkmessageutils.pas:170). It also means
      # Lint-PCharAnsi, which carried this code, was scanning half-blanked
      # comment text for the whole time it claimed to have solved exactly this
      # problem. Found 2026-08-17 while lifting the reader into this module.
      # BLANK, do not delete. Both readers must agree, and the one-pass regex
      # blanks -- so dropping the characters here would shift every column on a
      # line that contains a comment and make the two disagree on the module's
      # own promise that positions are preserved. Caught by the shared fixtures.
      if ($State.Value -eq '{') {
         if ($c -eq '}') { $State.Value = '' }
         [void]$out.Append(' ')
         $i++
         continue
      }
      if ($State.Value -eq '(*') {
         if ($c -eq '*' -and $c2 -eq ')') { $State.Value = ''; [void]$out.Append('  '); $i += 2 }
         else { [void]$out.Append(' '); $i++ }
         continue
      }

      if ($inStr) {
         if ($c -eq "'") { $inStr = $false }
         [void]$out.Append($c)
         $i++
         continue
      }

      if ($c -eq "'") { $inStr = $true; [void]$out.Append($c); $i++; continue }
      if ($c -eq '/' -and $c2 -eq '/') { break }                      # rest of line
      if ($c -eq '{') {
         if ($c2 -eq '$') { [void]$out.Append($c); $i++; continue }   # directive: live code
         $State.Value = '{'; [void]$out.Append(' '); $i++; continue
      }
      if ($c -eq '(' -and $c2 -eq '*') {
         if (($i + 2 -lt $Line.Length) -and $Line[$i + 2] -eq '$') {
            [void]$out.Append($c); $i++; continue                     # directive: live code
         }
         $State.Value = '(*'; [void]$out.Append('  '); $i += 2; continue
      }

      [void]$out.Append($c)
      $i++
   }

   return $out.ToString()
}

# A whole file, as an array of code-only lines. Index N is source line N+1 --
# comment text is blanked rather than removed, so line numbers stay usable in
# any message the caller prints.
#
# Built on the fast text form, then split. The obvious implementation -- call
# the per-line state machine for every line and collect -- is what made this
# unusable as a build gate; see Get-PascalCodeOnlyText.
function Get-PascalCodeOnlyLines
{
   param([Parameter(Mandatory = $true)][string] $Path)
   return (Get-PascalCodeOnlyText -Path $Path) -split "`r`n|`n"
}

# The same thing as one string, newlines preserved -- but in ONE .NET regex pass
# rather than character by character in PowerShell.
#
# WHY BOTH EXIST. Get-PascalCodeOnlyLine is a hand-written state machine, which
# is the readable way to state the rules and the right shape for a caller that
# already walks lines. It is also far too slow to scan the whole tree: ~500,000
# lines of char-at-a-time PowerShell took 21 s under pwsh 7 and 266 s under
# Windows PowerShell 5.1 -- and 5.1 is what Run-Lints actually spawns, so a lint
# built on it read as a hang and would have been the first thing disabled.
#
# The alternation below does the same job in native code. ORDER IS THE WHOLE
# TRICK and it is the same order the state machine checks in:
#
#   1. a string literal -- matched FIRST and kept, so a '{' or '//' inside one
#      opens nothing;
#   2. a {$...} or (*$...*) DIRECTIVE -- kept, because the code it guards is live;
#   3. a { } or (* *) comment, and a // to end of line -- blanked.
#
# Pascal has no nested brace comments, so [^}]* is exact rather than a
# simplification. An unterminated comment at EOF matches nothing and is left
# alone, which is the safe direction: it shows up as code, not as silence.
$script:PascalTokenRx = [regex]::new(
   "'(?:[^']|'')*'" +                      # 1. string literal (doubled '' inside)
   '|\{\$[^}]*\}' +                        # 2a. brace directive
   '|\(\*\$.*?\*\)' +                      # 2b. paren directive
   '|\{[^}]*\}' +                          # 3a. brace comment
   '|\(\*.*?\*\)' +                        # 3b. paren comment
   '|//[^\r\n]*',                          # 3c. line comment
   [System.Text.RegularExpressions.RegexOptions]::Singleline)

function Get-PascalCodeOnlyText
{
   param([Parameter(Mandatory = $true)][string] $Path)

   $text = [IO.File]::ReadAllText($Path)
   return $script:PascalTokenRx.Replace($text, {
      param($m)
      $v = $m.Value
      # Strings and directives survive untouched; everything else is blanked to
      # spaces with its newlines preserved, so line numbers stay usable.
      if ($v[0] -eq "'") { return $v }
      if ($v.Length -gt 1 -and $v[1] -eq '$') { return $v }                       # {$...}
      if ($v.Length -gt 2 -and $v[0] -eq '(' -and $v[2] -eq '$') { return $v }    # (*$...*)
      return ($v -replace '[^\r\n]', ' ')
   })
}

# The source files a lint should look at: TR4W's own Pascal, excluding vendored
# code, build output and editor debris. Shared for the same reason as the parser
# -- three scripts had three slightly different exclusion lists.
function Get-TR4WPascalFiles
{
   param([Parameter(Mandatory = $true)][string] $Root)

   $skipDir  = '\\include\\|\\dcu|dcu-cache|\\target\\|\\backup|\\build-out\\'
   $skipFile = '\.bad$|\.bakup$|\.old$|~'
   $keepExt  = @('.pas', '.dpr', '.dpk', '.inc')

   # FILTER ON THE EXTENSION, NOT `-Include`. With an absolute -LiteralPath and
   # no wildcard, `-Include` is SILENTLY IGNORED under Windows PowerShell 5.1 --
   # it returned all 1,425 entries under this tree, directories included, while
   # pwsh 7 returned the 412 Pascal files. A lint whose file set depends on which
   # host spawned it produces counts that cannot be reconciled, which for a
   # ratchet is worse than no ratchet: the same tree "grew" under 5.1 and was
   # clean under 7.
   #
   # Lint-PCharAnsi.ps1 had already learned a neighbouring version of this and
   # switched to `.Extension` -- see its comment about `uTelnet.pas.bad`. The
   # lesson had simply never been written down anywhere shared.
   #
   # -File also matters: without it the 5.1 result included DIRECTORIES, and
   # ReadAllText on a directory throws.
   #
   # Exact extensions also exclude a real piece of debris this exposed:
   # `tr4w\tr4w.d494 dpr`, a tracked July-2026 snapshot of tr4w.dpr whose
   # extension is " dpr" with a space. It matched the old wildcard and added a
   # phantom call site to three separate counts.
   return @(Get-ChildItem -LiteralPath $Root -Recurse -File -ErrorAction SilentlyContinue |
            Where-Object { $keepExt -contains $_.Extension.ToLowerInvariant() -and
                           $_.FullName -notmatch $skipDir -and
                           $_.Name -notmatch $skipFile })
}

# Fixtures for the parser itself. Exported so every consumer's -SelfTest can run
# them: the reader is shared now, so its tests should be too rather than each
# lint testing it separately (or, as happened, none of them testing it at all).
# Returns the number of failures and writes a line per fixture.
function Invoke-PascalSourceSelfTest
{
   $cases = @(
      # name, source lines, expected code-only lines
      @{ Name = 'plain code survives'
         In   = @("x := 1;")
         Out  = @("x := 1;") },

      @{ Name = 'trailing // is removed'
         In   = @("x := 1; // set it")
         Out  = @("x := 1; ") },

      # THE BUG THIS MODULE WAS BORN FROM. Every character of a multi-line brace
      # comment must go, not every other one.
      @{ Name = 'multi-line brace comment is fully blanked'
         In   = @("{ Okay, we have this and", "  assume it to be so. }", "begin")
         Out  = @("", "", "begin") },

      # Note the COLUMN: the comment is blanked, not deleted, so `begin` stays
      # where it was. Both readers must agree on that -- they did not until
      # 2026-08-17, when the per-line one was dropping comment characters
      # instead of replacing them.
      @{ Name = 'multi-line (* *) comment is fully blanked'
         In   = @("(* first", "   second *) begin")
         Out  = @("", "             begin") },

      # A directive is live code -- the lints must still see what it guards.
      @{ Name = 'brace directive is kept'
         In   = @("{`$IFDEF FPC}")
         Out  = @("{`$IFDEF FPC}") },

      # A brace inside a string opens nothing; getting this wrong blanks live
      # code to the next '}' anywhere in the file.
      @{ Name = 'brace inside a string literal opens nothing'
         In   = @("s := '{';", "asm")
         Out  = @("s := '{';", "asm") },

      @{ Name = '// inside a string comments out nothing'
         In   = @("u := 'http://x';")
         Out  = @("u := 'http://x';") }
   )

   # BOTH implementations, same fixtures. There are two readers -- the per-line
   # state machine and the one-pass regex that replaced it in the hot path -- and
   # testing only the readable one would leave the one that does the actual work
   # unverified. They must agree, and the fixtures are the definition of "agree".
   $tmp = Join-Path ([IO.Path]::GetTempPath()) ("pascalsrc_" + [Guid]::NewGuid().ToString('N') + ".pas")

   $failed = 0
   foreach ($c in $cases) {
      # Compare TRIMMED, because blanking preserves column positions and the
      # expectation is about what SURVIVES, not about the padding.
      $expTrim = @($c.Out | ForEach-Object { $_.TrimEnd() })

      $state = ''
      $ref   = [ref] $state
      $byLine = New-Object 'System.Collections.Generic.List[string]'
      foreach ($line in $c.In) { [void]$byLine.Add((Get-PascalCodeOnlyLine -Line $line -State $ref)) }
      $lineTrim = @($byLine | ForEach-Object { $_.TrimEnd() })

      [IO.File]::WriteAllText($tmp, ($c.In -join "`r`n"))
      $textTrim = @((Get-PascalCodeOnlyLines -Path $tmp) | ForEach-Object { $_.TrimEnd() })

      $okLine = ($lineTrim -join '|') -eq ($expTrim -join '|')
      $okText = ($textTrim -join '|') -eq ($expTrim -join '|')

      if ($okLine -and $okText) {
         Write-Host ("PARSER ok   {0}" -f $c.Name)
      }
      else {
         $failed++
         Write-Host ("PARSER FAIL {0}  (per-line: {1}, one-pass: {2})" -f $c.Name, $okLine, $okText)
         Write-Host ("   expected : {0}" -f ($expTrim -join ' | '))
         Write-Host ("   per-line : {0}" -f ($lineTrim -join ' | '))
         Write-Host ("   one-pass : {0}" -f ($textTrim -join ' | '))
      }
   }

   if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Force }
   return $failed
}

Export-ModuleMember -Function Get-PascalCodeOnlyLine, Get-PascalCodeOnlyLines,
                              Get-PascalCodeOnlyText, Get-TR4WPascalFiles,
                              Invoke-PascalSourceSelfTest
