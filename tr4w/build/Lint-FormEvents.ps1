<#
.SYNOPSIS
   Checks that every published event handler on a designed FMX form is actually
   wired -- a handler nothing calls compiles clean and silently does nothing.

.DESCRIPTION
   An event handler reaches its control in exactly one of two ways: the .fmx
   names it (OnChange = edtFooChange), or code assigns it (OnShow := FormShow).
   A published method that neither does is just an unused method. The compiler
   cannot complain -- it is a legitimate declaration -- and no other lint looks.

   That is not hypothetical, and it is not cosmetic. On 2026-08-11 the
   Preferences form had ten per-item editor controls with no OnChange in the
   .fmx: CaptureSelectedCluster and CaptureSelectedRotator existed, were
   correct, and were never called. Every keystroke in a cluster's Name, Log in
   as, Password and After-connecting box -- and in every rotator field except
   its type -- was discarded on save. NY4I found it by typing a password and
   noticing the list row had not changed.

   The failure mode is the worst kind: the form builds, opens, looks right,
   accepts typing, and throws it away.

   THE CHECK IS ONE-WAY, for the same reason Lint-FormFields is. A published
   handler that nothing wires is an error. An .fmx event naming a method that
   does not exist is NOT checked here -- that one already fails loudly at
   stream time with an "unknown property" error, so it cannot ship unnoticed.

   Scope is deliberately narrow: only methods matching the designed-handler
   signature, procedure Name(Sender: TObject), on a class that has a .fmx.
   Ordinary helpers are none of this lint's business.

.PARAMETER SourceDir
   Directory to scan recursively for .fmx files. Defaults to the src directory
   next to this script's parent (i.e. tr4w\src).

.PARAMETER SelfTest
   Runs the rules against built-in fixtures instead of the source tree.

.OUTPUTS
   One line per violation:  <file>: handler '<name>' is declared but never wired
   Exit code 0 = clean, 1 = at least one violation (fails the build).
#>
[CmdletBinding()]
param(
   [string] $SourceDir,
   [switch] $SelfTest
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Strip Pascal comments and string literals before looking for assignments, so
# that a handler named only inside a comment does not read as wired. Without
# this the lint would be defeated by the very comment explaining why a handler
# is unused -- which is exactly the sort of false clean that makes a linter
# get ignored.
function Remove-PascalNoise {
   param([string] $Text)

   $out = New-Object System.Text.StringBuilder
   $i = 0
   $n = $Text.Length

   while ($i -lt $n) {
      $c = $Text[$i]

      if ($c -eq '{') {
         while ($i -lt $n -and $Text[$i] -ne '}') { $i++ }
         $i++
         [void]$out.Append(' ')
         continue
      }

      if ($c -eq '(' -and $i + 1 -lt $n -and $Text[$i + 1] -eq '*') {
         $i += 2
         while ($i + 1 -lt $n -and -not ($Text[$i] -eq '*' -and $Text[$i + 1] -eq ')')) { $i++ }
         $i += 2
         [void]$out.Append(' ')
         continue
      }

      if ($c -eq '/' -and $i + 1 -lt $n -and $Text[$i + 1] -eq '/') {
         while ($i -lt $n -and $Text[$i] -ne "`n") { $i++ }
         [void]$out.Append("`n")
         continue
      }

      if ($c -eq "'") {
         $i++
         while ($i -lt $n -and $Text[$i] -ne "'") { $i++ }
         $i++
         [void]$out.Append(" '' ")
         continue
      }

      [void]$out.Append($c)
      $i++
   }

   return $out.ToString()
}

# Every handler-shaped method declared in the unit: procedure X(Sender: TObject).
function Get-DeclaredHandlers {
   param([string] $PasText)

   $clean = Remove-PascalNoise -Text $PasText
   $names = New-Object System.Collections.Generic.List[string]

   foreach ($m in [regex]::Matches($clean,
      '(?im)^\s*procedure\s+([A-Za-z_]\w*)\s*\(\s*Sender\s*:\s*TObject\s*\)\s*;')) {
      $name = $m.Groups[1].Value
      if (-not $names.Contains($name)) { [void]$names.Add($name) }
   }

   return , $names.ToArray()
}

# Wired by the resource: OnAnything = HandlerName
function Get-FmxWiredHandlers {
   param([string] $FmxText)

   $names = New-Object System.Collections.Generic.List[string]
   foreach ($m in [regex]::Matches($FmxText, '(?im)^\s*On\w+\s*=\s*([A-Za-z_]\w*)\s*$')) {
      $name = $m.Groups[1].Value
      if (-not $names.Contains($name)) { [void]$names.Add($name) }
   }
   return , $names.ToArray()
}

# Wired by code: OnShow := FormShow, or handed to anything as a value.
# Deliberately loose -- a handler referenced anywhere in executable code is
# doing something, and this lint only exists to catch the ones referenced
# NOWHERE. A loose test here costs a missed defect; a tight one costs false
# positives, and a linter that cries wolf is a linter people switch off.
function Get-CodeReferencedHandlers {
   param([string] $PasText, [string[]] $Candidates)

   $clean = Remove-PascalNoise -Text $PasText
   $used = New-Object System.Collections.Generic.List[string]

   foreach ($name in $Candidates) {
      # Any occurrence beyond the declaration itself counts as a reference.
      #
      # The implementation header is NOT subtracted, because the lookbehind
      # already excludes it: it is spelled T<Class>.<Name>, and a dotted name
      # never matches. Subtracting it as well was this lint's own first bug --
      # it made every code-assigned handler look unreferenced, which its
      # self-test caught on the first run. A linter needs a fixture for the
      # case it is about to get wrong, not only for the code it is checking.
      $refs = [regex]::Matches($clean, "(?i)(?<![\w.])$([regex]::Escape($name))(?![\w])")
      $decl = [regex]::Matches($clean,
         "(?im)^\s*procedure\s+$([regex]::Escape($name))\s*\(")

      if ($refs.Count -gt $decl.Count) {
         [void]$used.Add($name)
      }
   }

   return , $used.ToArray()
}

function Test-FormPair {
   param([string] $FmxText, [string] $PasText)

   $declared = Get-DeclaredHandlers      -PasText $PasText
   $inFmx    = Get-FmxWiredHandlers      -FmxText $FmxText
   $inCode   = Get-CodeReferencedHandlers -PasText $PasText -Candidates $declared

   $violations = New-Object System.Collections.Generic.List[string]
   foreach ($name in $declared) {
      if ($inFmx -contains $name) { continue }
      if ($inCode -contains $name) { continue }
      [void]$violations.Add($name)
   }

   return , $violations.ToArray()
}

# ---------------------------------------------------------------- self test --

if ($SelfTest) {
   $fixtures = @(
      @{ Name = 'wired_in_fmx_is_clean'
         Fmx  = "object Form1: TForm1`r`n  object edtA: TEdit`r`n    OnChange = edtAChange`r`n  end`r`nend"
         Pas  = "procedure edtAChange(Sender: TObject);`r`nprocedure TForm1.edtAChange(Sender: TObject);`r`nbegin`r`nend;"
         Want = 0 }

      @{ Name = 'declared_but_never_wired_is_caught'
         Fmx  = "object Form1: TForm1`r`n  object edtA: TEdit`r`n  end`r`nend"
         Pas  = "procedure edtAChange(Sender: TObject);`r`nprocedure TForm1.edtAChange(Sender: TObject);`r`nbegin`r`nend;"
         Want = 1 }

      @{ Name = 'assigned_in_code_is_clean'
         Fmx  = "object Form1: TForm1`r`nend"
         Pas  = "procedure FormShow(Sender: TObject);`r`nprocedure TForm1.FormShow(Sender: TObject);`r`nbegin`r`nend;`r`nprocedure TForm1.Create;`r`nbegin`r`n  OnShow := FormShow;`r`nend;"
         Want = 0 }

      # The one that matters most: a comment explaining the handler must not
      # count as wiring it. This is how a lint quietly stops working.
      @{ Name = 'named_only_in_a_comment_is_still_caught'
         Fmx  = "object Form1: TForm1`r`nend"
         Pas  = "// edtAChange is called by the designer`r`nprocedure edtAChange(Sender: TObject);`r`nprocedure TForm1.edtAChange(Sender: TObject);`r`nbegin`r`nend;"
         Want = 1 }

      @{ Name = 'named_only_in_a_string_is_still_caught'
         Fmx  = "object Form1: TForm1`r`nend"
         Pas  = "procedure edtAChange(Sender: TObject);`r`nprocedure TForm1.edtAChange(Sender: TObject);`r`nbegin`r`n  Log('edtAChange');`r`nend;"
         Want = 1 }

      # A non-handler signature is none of this lint's business.
      @{ Name = 'ordinary_method_is_not_checked'
         Fmx  = "object Form1: TForm1`r`nend"
         Pas  = "procedure LoadEverything;`r`nprocedure TForm1.LoadEverything;`r`nbegin`r`nend;"
         Want = 0 }

      @{ Name = 'the_real_defect_ten_unwired_editors'
         Fmx  = "object Form1: TForm1`r`n  object cbxA: TComboEdit`r`n    OnChange = cbxAChange`r`n  end`r`n  object edtB: TEdit`r`n  end`r`nend"
         Pas  = "procedure cbxAChange(Sender: TObject);`r`nprocedure edtBChange(Sender: TObject);`r`nprocedure TForm1.cbxAChange(Sender: TObject);`r`nbegin`r`nend;`r`nprocedure TForm1.edtBChange(Sender: TObject);`r`nbegin`r`nend;"
         Want = 1 }
   )

   $failed = 0
   foreach ($f in $fixtures) {
      $got = (Test-FormPair -FmxText $f.Fmx -PasText $f.Pas).Count
      if ($got -ne $f.Want) {
         Write-Host ("Lint-FormEvents SELFTEST FAIL {0}: expected {1}, got {2}" -f $f.Name, $f.Want, $got)
         $failed++
      }
   }

   if ($failed -gt 0) {
      Write-Host "Lint-FormEvents: $failed self-test(s) failed."
      exit 1
   }

   Write-Host ("Lint-FormEvents: {0} self-test(s) passed." -f $fixtures.Count)
   exit 0
}

# -------------------------------------------------------------- the real run --

if (-not $SourceDir) {
   $SourceDir = Join-Path (Split-Path -Parent $PSScriptRoot) 'src'
}

if (-not (Test-Path -LiteralPath $SourceDir)) {
   Write-Host "Lint-FormEvents: source directory not found: $SourceDir"
   exit 1
}

$violations = 0
$forms = 0

# .fmx AND .lfm.  The two designers write the same object/property/end grammar,
# so this lint reads both -- verified 2026-08-13 by running it over the LCL
# forms renamed to .fmx and getting identical, sensible answers. Filtering on
# .fmx alone meant that as each form was ported to the LCL it silently dropped
# out of this gate, which is how a designed-form defect gets shipped.
foreach ($fmx in Get-ChildItem -LiteralPath $SourceDir -Recurse -File | Where-Object { $_.Extension -in '.fmx', '.lfm' }) {
   $pas = [System.IO.Path]::ChangeExtension($fmx.FullName, '.pas')
   if (-not (Test-Path -LiteralPath $pas)) { continue }

   $forms++
   $bad = Test-FormPair -FmxText (Get-Content -LiteralPath $fmx.FullName -Raw) `
                        -PasText (Get-Content -LiteralPath $pas -Raw)

   foreach ($name in $bad) {
      Write-Host ("{0}: handler '{1}' is declared but never wired" -f $fmx.Name, $name)
      $violations++
   }
}

if ($violations -gt 0) {
   Write-Host "Lint-FormEvents: $violations unwired handler(s). A handler nothing calls silently does nothing."
   exit 1
}

Write-Host "Lint-FormEvents: $forms designed form(s) checked, every handler is wired."
exit 0
