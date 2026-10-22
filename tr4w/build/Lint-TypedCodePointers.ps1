<#
.SYNOPSIS
   Fails the build when `@Routine` is handed to a slot whose procedural type
   the compiler would otherwise check.

.DESCRIPTION
   WHY THIS EXISTS (pointer audit D2 / packet P1, 2026-10-16). TF.tCreateThread
   took an untyped Pointer and its trampoline called the target as
   `function(Pointer): DWORD; stdcall`. Ten of the fifteen targets were
   parameterless register-convention procedures, which on i386 left the stack
   four bytes off on return: the trampoline then wrote the thread parameter
   (nil) into FS:[0] -- the thread's exception-chain head -- and restored
   EBX/ESI/EDI from the wrong slots. The fix typed the parameter
   (TF.TTR4WThreadStart), and the same was done for uProcessCommand's command
   table (TCommandHandler).

   TYPING IT IS NOT ENOUGH ON ITS OWN, and that is what this lint is for. In
   {$MODE Delphi}, `@Routine` is an UNTYPED pointer, and FPC 3.2.2 accepts an
   untyped pointer for a procedural-typed parameter or field WITHOUT checking
   the signature -- with or without {$T+}. Measured with a three-line probe:

       Take(@Bad);   compiles     (Bad has the wrong signature)
       Take(Bad);    Error: Incompatible type for arg no. 1

   So the call sites name the routine bare, and one `@` put back would make the
   whole check silently absent again. This fails on that `@`.

   THE SLOTS CHECKED -- each a place whose type is a procedural type:
     tCreateThread( @X ...      TF.TTR4WThreadStart
     caAddress: @X              uProcessCommand.TCommandHandler

   THE FLOORS. A guard that matched nothing must not pass: the fixture must
   come out exact, the scan must include src\MainUnit.pas, and each slot must
   be found at least its floor's number of times -- so a renamed routine or a
   broken pattern fails rather than reporting a clean tree.

   .\Lint-TypedCodePointers.ps1             # the tree (Run-Lints passes -SourceDir)
   .\Lint-TypedCodePointers.ps1 -SelfTest   # the fixture only
#>
param(
   [string] $SourceDir,
   [switch] $SelfTest
)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'PascalSource.psm1') -Force
. (Join-Path $PSScriptRoot 'Get-ScanExclusions.ps1')   # Test-Tr4wScannable

if (-not $SourceDir) {
   $SourceDir = Split-Path -Parent $PSScriptRoot
}

# Name, the slot (any use), the violation (an @ in it), and the floor. Floors
# measured 2026-10-16: 17 tCreateThread (15 calls plus TF's two declarations)
# and 82 caAddress (81 command-table rows plus the field's declaration).
$script:Slots = @(
   [pscustomobject]@{ Name = 'tCreateThread'; Floor = 10
                      Any  = [regex] '(?i)(?<![\w.])tCreateThread\s*\('
                      Bad  = [regex] '(?i)(?<![\w.])tCreateThread\s*\(\s*@' }
   [pscustomobject]@{ Name = 'caAddress';     Floor = 50
                      Any  = [regex] '(?i)(?<![\w.])caAddress\s*:(?!=)'
                      Bad  = [regex] '(?i)(?<![\w.])caAddress\s*:\s*@' }
)

function Get-LineNumber
{
   param([string] $Text, [int] $Index)

   $n = 1
   for ($i = 0; $i -lt $Index; $i++) {
      if ($Text[$i] -eq "`n") { $n++ }
   }
   return $n
}

function Find-UntypedCodePointer
{
   param([string] $Path)

   $code   = Get-PascalCodeOnlyText -Path $Path -BlankStrings
   $hits   = New-Object System.Collections.ArrayList
   $counts = @{}
   foreach ($s in $script:Slots) {
      $counts[$s.Name] = $s.Any.Matches($code).Count
      foreach ($m in $s.Bad.Matches($code)) {
         [void] $hits.Add([pscustomobject]@{ Slot = $s.Name
                                             Line = (Get-LineNumber -Text $code -Index $m.Index) })
      }
   }
   return @{ Hits = @($hits); Counts = $counts }
}

function Invoke-TypedCodePointersSelfTest
{
   $fixture = @(
      'unit fixture;'
      'implementation'
      'const'
      '   T: array[0..2] of TRow = ('
      '      (caCommand: ''A''; caAddress: DoA),'
      '      (caCommand: ''B''; caAddress: @DoB),          // HIT caAddress'
      '      (caCommand: ''C''; caAddress:  @ DoC));       // HIT caAddress'
      'begin'
      '   tCreateThread(Body, id);'
      '   h := tCreateThread(@Body, id);                  // HIT tCreateThread'
      '   tCreateThread( @Body, id, False, @Self);        // HIT tCreateThread'
      '   tCreateThread(Body, id, False, @Self);'
      '   x.caAddress := @DoA;'
      '   // tCreateThread(@Body, id);'
      '   (* caAddress: @DoB *)'
      '   s := ''tCreateThread(@Body'';'
      'end.'
   )

   $expected = @{}
   for ($i = 0; $i -lt $fixture.Count; $i++) {
      if ($fixture[$i] -match '// HIT (\w+)$') {
         $expected[$i + 1] = $Matches[1]
      }
   }

   $tmp = Join-Path ([IO.Path]::GetTempPath()) ('lint-typedcode-' + [Guid]::NewGuid().ToString('N') + '.pas')
   try {
      [IO.File]::WriteAllText($tmp, ($fixture -join "`r`n") + "`r`n")
      $r = Find-UntypedCodePointer -Path $tmp
   }
   finally {
      Remove-Item -LiteralPath $tmp -ErrorAction SilentlyContinue
   }

   $ok = ($r.Hits.Count -eq $expected.Count)
   foreach ($h in $r.Hits) {
      if ((-not $expected.ContainsKey($h.Line)) -or ($expected[$h.Line] -ne $h.Slot)) {
         Write-Host ("  self-test: UNEXPECTED {0} at fixture line {1}: {2}" -f $h.Slot, $h.Line, $fixture[$h.Line - 1].Trim())
         $ok = $false
      }
   }
   foreach ($line in $expected.Keys) {
      if (-not (@($r.Hits | Where-Object { $_.Line -eq $line }).Count)) {
         Write-Host ("  self-test: MISSED {0} at fixture line {1}: {2}" -f $expected[$line], $line, $fixture[$line - 1].Trim())
         $ok = $false
      }
   }
   # The slot counters are part of the floor, so they are pinned too: four
   # tCreateThread calls in code, and three caAddress rows (the assignment
   # `x.caAddress := @DoA` is not a row -- the := is excluded).
   if ($r.Counts['tCreateThread'] -ne 4 -or $r.Counts['caAddress'] -ne 3) {
      Write-Host ("  self-test: slot counts tCreateThread={0} caAddress={1}, expected 4 and 3" -f
                  $r.Counts['tCreateThread'], $r.Counts['caAddress'])
      $ok = $false
   }
   if ($ok) {
      Write-Host ("Lint-TypedCodePointers: self-test OK ({0} expected hits)." -f $expected.Count)
   }
   return $ok
}

if (-not (Invoke-TypedCodePointersSelfTest)) {
   Write-Output "Lint-TypedCodePointers: SELF-TEST FAILED -- refusing to judge the tree."
   exit 1
}
if ($SelfTest) {
   exit 0
}

if (-not (Test-Path -LiteralPath $SourceDir -PathType Container)) {
   Write-Output "Lint-TypedCodePointers: source directory not found: $SourceDir"
   exit 1
}

$files = @(Get-TR4WPascalFiles -Root $SourceDir |
           Where-Object { (Test-Tr4wScannable $_.FullName) -and
                          $_.FullName -notmatch '\\graphify-out\\' })

if (-not ($files | Where-Object { $_.Name -ieq 'MainUnit.pas' })) {
   Write-Output ("Lint-TypedCodePointers: MainUnit.pas is not under '{0}' ({1} file(s)) -- wrong -SourceDir? Refusing to report a pass." -f $SourceDir, $files.Count)
   exit 1
}

$violations = New-Object System.Collections.ArrayList
$totals = @{}
foreach ($s in $script:Slots) { $totals[$s.Name] = 0 }
foreach ($f in $files) {
   $r = Find-UntypedCodePointer -Path $f.FullName
   foreach ($s in $script:Slots) { $totals[$s.Name] += $r.Counts[$s.Name] }
   if ($r.Hits.Count -gt 0) {
      $lines = [IO.File]::ReadAllLines($f.FullName)
      $rel = $f.FullName.Substring($SourceDir.TrimEnd('\').Length).TrimStart('\')
      foreach ($h in $r.Hits) {
         [void] $violations.Add(("  {0}:{1}  [{2}]  {3}" -f $rel, $h.Line, $h.Slot, $lines[$h.Line - 1].Trim()))
      }
   }
}

$short = @($script:Slots | Where-Object { $totals[$_.Name] -lt $_.Floor })
if ($short.Count -gt 0) {
   foreach ($s in $short) {
      Write-Output ("Lint-TypedCodePointers: only {0} use(s) of {1} found (floor {2}) -- renamed, or the pattern is broken. Refusing to report a pass." -f $totals[$s.Name], $s.Name, $s.Floor)
   }
   exit 1
}

if ($violations.Count -gt 0) {
   $violations | ForEach-Object { Write-Output $_ }
   Write-Output ("Lint-TypedCodePointers: {0} routine(s) passed as @Routine to a procedural-typed slot." -f $violations.Count)
   Write-Output "  In Delphi mode @Routine is an UNTYPED pointer, so the compiler does not check"
   Write-Output "  the signature. Name the routine bare -- tCreateThread(MyThreadProc, id) -- and"
   Write-Output "  give it the slot's shape. See docs/POINTER_AUDIT.md, D2."
   exit 1
}

$summary = (@($script:Slots | ForEach-Object { '{0} {1}' -f $totals[$_.Name], $_.Name }) -join ', ')
Write-Output ("Lint-TypedCodePointers: {0} file(s); {1}; no @Routine in a typed slot." -f $files.Count, $summary)
exit 0
