<#
.SYNOPSIS
   Checks that every published control field on a designed FMX form has a
   component of that name in the .fmx -- a mismatch is nil at run time, with no
   compile error.

.DESCRIPTION
   Streaming binds a control to a field by EXACT NAME MATCH. A published field
   with no matching component in the resource is simply never assigned, so it
   stays nil and the first line that touches it access-violates -- typically
   deep inside a Load routine, far from anything that looks like the cause.

   That is not hypothetical. TfrmKeyerEdit declared lblWKFirstExt/edtWKFirstExt
   and the hand-authored .fmx never emitted them; the form built clean, opened
   clean, and crashed on Add at the one line that used the field (NY4I,
   2026-08-07). Nothing in the toolchain says a word: not the compiler, because
   the field is a legitimate declaration; not the designer, because it never saw
   the .pas; not the other lints.

   THE CHECK IS DELIBERATELY ONE-WAY. A field with no component is an error. A
   COMPONENT WITH NO FIELD IS FINE -- that is what the IDE produces when you drop
   a control and do not reference it (uFMXDesignedProbe has exactly that, a
   Button1 with an event handler and no field), and flagging it would fire on
   correct forms.

.PARAMETER SourceDir
   Directory to scan recursively for .fmx files. Defaults to the src directory
   next to this script's parent (i.e. tr4w\src).

.PARAMETER SelfTest
   Runs the rules against built-in fixtures instead of the source tree.

.OUTPUTS
   One line per violation:  <file>: field '<name>' has no component
   Exit code 0 = clean, 1 = at least one violation (fails the build).
#>
[CmdletBinding()]
param(
   [string] $SourceDir,
   [switch] $SelfTest
)

# The published section is everything between `= class(TForm)` and the first
# visibility keyword -- Delphi's implicit-published region on a TPersistent
# descendant, which is exactly what the streamer can bind to.
function Get-PublishedControlFields {
   param([string] $PasText)

   $result = @()
   $m = [regex]::Match($PasText, '=\s*class\(TForm\)(.*?)^\s*(private|protected|public|strict)\b',
                       [Text.RegularExpressions.RegexOptions]::Singleline -bor
                       [Text.RegularExpressions.RegexOptions]::Multiline)
   if (-not $m.Success) {
      return $result
   }

   # `lbl: TLabel;` and the comma form `rbData7, rbData8: TRadioButton;`.
   # Methods are skipped because they do not match `<names> : T<type> ;`.
   foreach ($f in [regex]::Matches($m.Groups[1].Value,
                   '^\s{4,}([A-Za-z_][A-Za-z0-9_]*(?:\s*,\s*[A-Za-z_][A-Za-z0-9_]*)*)\s*:\s*T[A-Za-z0-9_]+\s*;',
                   [Text.RegularExpressions.RegexOptions]::Multiline)) {
      foreach ($n in $f.Groups[1].Value -split ',') {
         $result += $n.Trim()
      }
   }
   return $result
}

# Methods declared in the published region -- the only ones TWriter can bind an
# event to. `procedure Foo(Sender: TObject);` / `function Foo: boolean;`
function Get-PublishedMethodNames {
   param([string] $PasText)

   $result = @()
   $m = [regex]::Match($PasText, '=\s*class\(TForm\)(.*?)^\s*(private|protected|public|strict)\b',
                       [Text.RegularExpressions.RegexOptions]::Singleline -bor
                       [Text.RegularExpressions.RegexOptions]::Multiline)
   if (-not $m.Success) {
      return $result
   }

   foreach ($f in [regex]::Matches($m.Groups[1].Value,
                   '^\s*(?:procedure|function)\s+([A-Za-z_][A-Za-z0-9_]*)',
                   [Text.RegularExpressions.RegexOptions]::Multiline -bor
                   [Text.RegularExpressions.RegexOptions]::IgnoreCase)) {
      $result += $f.Groups[1].Value
   }
   return $result
}

# Every `OnSomething = Handler` the resource asks the streamer to bind.
function Get-ResourceEventHandlers {
   param([string] $FmxText)
   $names = @()
   foreach ($m in [regex]::Matches($FmxText, '^\s*On[A-Za-z0-9_]*\s*=\s*([A-Za-z_][A-Za-z0-9_]*)\s*$',
                                   [Text.RegularExpressions.RegexOptions]::Multiline)) {
      $names += $m.Groups[1].Value
   }
   return $names
}

function Get-ResourceComponentNames {
   param([string] $FmxText)
   $names = @()
   foreach ($m in [regex]::Matches($FmxText, 'object\s+([A-Za-z_][A-Za-z0-9_]*)\s*:')) {
      $names += $m.Groups[1].Value
   }
   return $names
}

function Test-FormFields {
   param([string] $DisplayPath, [string] $PasText, [string] $FmxText)

   $violations = @()
   $fields = Get-PublishedControlFields -PasText $PasText
   $inRes  = Get-ResourceComponentNames -FmxText $FmxText

   foreach ($f in $fields) {
      if ($inRes -notcontains $f) {
         $violations += ("{0}: published field '{1}' has no component of that name in the .fmx - it will be nil at run time" -f $DisplayPath, $f)
      }
   }

   # THE OTHER DIRECTION, and the same silent failure. A .fmx stores an event as
   # the NAME of a published method. Declared anywhere else -- private, public,
   # or not at all -- it does not resolve, and the FORM FAILS TO LOAD with
   # "Error reading <control>.OnChange: Invalid property value". Nothing catches
   # it at compile time: the method is a perfectly legal declaration, just not in
   # a region the streamer can see (NY4I, 2026-08-08, cbxRadio1.OnChange).
   $methods = Get-PublishedMethodNames -PasText $PasText
   foreach ($h in (Get-ResourceEventHandlers -FmxText $FmxText)) {
      if ($methods -notcontains $h) {
         $violations += ("{0}: .fmx binds an event to '{1}', which is not a PUBLISHED method - the form will fail to load" -f $DisplayPath, $h)
      }
   }

   return $violations
}

# ---------------------------------------------------------------- self test --

function Invoke-SelfTest {
   $fixtures = @(
      @{ Name = 'matched'; Expect = 0
         Pas = "type`r`n  TfrmX = class(TForm)`r`n    lblA: TLabel;`r`n    edtB: TEdit;`r`n  private`r`n  end;"
         Fmx = "object frmX: TfrmX`r`n  object lblA: TLabel`r`n  end`r`n  object edtB: TEdit`r`n  end`r`nend" },

      @{ Name = 'field_without_component'; Expect = 1
         Pas = "type`r`n  TfrmX = class(TForm)`r`n    lblA: TLabel;`r`n    edtMissing: TEdit;`r`n  private`r`n  end;"
         Fmx = "object frmX: TfrmX`r`n  object lblA: TLabel`r`n  end`r`nend" },

      # The comma form must expand, or a second name on one line goes unchecked.
      @{ Name = 'comma_declared_fields'; Expect = 1
         Pas = "type`r`n  TfrmX = class(TForm)`r`n    optOne, optTwo: TRadioButton;`r`n  private`r`n  end;"
         Fmx = "object frmX: TfrmX`r`n  object optOne: TRadioButton`r`n  end`r`nend" },

      # A COMPONENT WITH NO FIELD IS LEGAL -- the IDE produces exactly this.
      @{ Name = 'component_without_field_is_fine'; Expect = 0
         Pas = "type`r`n  TfrmX = class(TForm)`r`n    lblA: TLabel;`r`n  private`r`n  end;"
         Fmx = "object frmX: TfrmX`r`n  object lblA: TLabel`r`n  end`r`n  object Button1: TButton`r`n  end`r`nend" },

      # Only the PUBLISHED section counts: a private control field is not
      # streamed and must not be demanded of the resource.
      # An event bound to a method the streamer cannot see.
      @{ Name = 'handler_not_published'; Expect = 1
         Pas = "type`r`n  TfrmX = class(TForm)`r`n    lblA: TLabel;`r`n    procedure HandleOK(Sender: TObject);`r`n  private`r`n    procedure HandlePrivate(Sender: TObject);`r`n  end;"
         Fmx = "object frmX: TfrmX`r`n  object lblA: TLabel`r`n    OnChange = HandlePrivate`r`n  end`r`nend" },

      @{ Name = 'handler_published_is_fine'; Expect = 0
         Pas = "type`r`n  TfrmX = class(TForm)`r`n    lblA: TLabel;`r`n    procedure HandleOK(Sender: TObject);`r`n  private`r`n  end;"
         Fmx = "object frmX: TfrmX`r`n  object lblA: TLabel`r`n    OnChange = HandleOK`r`n  end`r`nend" },

      @{ Name = 'private_fields_ignored'; Expect = 0
         Pas = "type`r`n  TfrmX = class(TForm)`r`n    lblA: TLabel;`r`n  private`r`n    lblPrivate: TLabel;`r`n  end;"
         Fmx = "object frmX: TfrmX`r`n  object lblA: TLabel`r`n  end`r`nend" }
   )

   $failed = 0
   foreach ($f in $fixtures) {
      $v = @(Test-FormFields -DisplayPath $f.Name -PasText $f.Pas -FmxText $f.Fmx)
      if ($v.Count -ne $f.Expect) {
         Write-Output ("SELFTEST FAIL {0}: expected {1}, got {2}" -f $f.Name, $f.Expect, $v.Count)
         $v | ForEach-Object { Write-Output ("   " + $_) }
         $failed++
      }
      else {
         Write-Output ("SELFTEST ok   {0} ({1} violation(s))" -f $f.Name, $v.Count)
      }
   }

   if ($failed -gt 0) {
      Write-Output ("Lint-FormFields SELFTEST: {0} fixture(s) failed." -f $failed)
      exit 1
   }
   Write-Output ("Lint-FormFields SELFTEST: all {0} fixtures behaved as documented." -f $fixtures.Count)
   exit 0
}

# --------------------------------------------------------------------- main --

if ($SelfTest) {
   Invoke-SelfTest
}

if (-not $SourceDir) {
   $SourceDir = Join-Path (Split-Path -Parent $PSScriptRoot) 'src'
}

if (-not (Test-Path -LiteralPath $SourceDir)) {
   Write-Output ("Lint-FormFields: source directory not found: {0}" -f $SourceDir)
   exit 1
}

$files = @(Get-ChildItem -LiteralPath $SourceDir -Recurse -Filter *.fmx -File |
           Where-Object { $_.FullName -notmatch '\\__history\\|\\__recovery\\' })

$violations = @()
$checked = 0

foreach ($fmx in $files) {
   $pas = [IO.Path]::ChangeExtension($fmx.FullName, '.pas')
   if (-not (Test-Path -LiteralPath $pas)) {
      # A .fmx with no .pas beside it is not a designed form this lint can check.
      continue
   }
   $checked++
   $violations += Test-FormFields -DisplayPath $fmx.FullName `
                                  -PasText (Get-Content -LiteralPath $pas -Raw) `
                                  -FmxText (Get-Content -LiteralPath $fmx.FullName -Raw)
}

if ($violations.Count -gt 0) {
   $violations | ForEach-Object { Write-Output $_ }
   Write-Output ("Lint-FormFields: {0} violation(s) across {1} designed form(s)." -f $violations.Count, $checked)
   exit 1
}

Write-Output ("Lint-FormFields: {0} designed form(s) checked, every published field has a component." -f $checked)
exit 0
