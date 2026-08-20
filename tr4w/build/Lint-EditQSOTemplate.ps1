<#
.SYNOPSIS
   Checks the Edit QSO form against the dialog template it was generated from,
   in three directions: resource, id table, and .lfm.

.DESCRIPTION
   uEditQSOForm is the only converted dialog that WRITES TO THE CONTEST LOG, and
   it still addresses its controls by the Win32 ids the save path always used --
   deliberately, so SaveQSOToEditableLog's ~340 lines kept their shape instead of
   being rewritten against named controls (NY4I, approved 2026-08-19).

   The price of that decision is one table, EDITQSO_FIELDS, mapping id to
   component name. Nothing in the compiler checks it. A typo'd id or a renamed
   component does not fail to build -- it reads the WRONG BOX, and the first
   symptom is a QSO in the log with someone else's field in it.

   So this lint asserts the three artifacts agree:

     1. EVERY CONTROL IN THE TEMPLATE HAS EXACTLY ONE ROW in EDITQSO_FIELDS.
        A control that exists in the resource and not in the table is a field
        the form cannot address at all.

     2. EVERY ROW NAMES A COMPONENT THAT EXISTS in the .lfm, and no two rows
        name the same one. A row pointing at nothing reads as an empty field --
        which, for a numeric, is indistinguishable from a legitimate zero.

     3. THE EDITABLE/INERT SPLIT MATCHES THE STYLE BITS. In the template exactly
        three check boxes are BS_AUTOCHECKBOX -- S&P, Deleted, X-QSO -- and
        exactly those three are read back on save. The other seven are
        BS_CHECKBOX, which Windows does not toggle on click; the LCL has no such
        thing, so they carry Enabled = False instead. If that split ever drifts,
        either an operator can change a scoring flag that is then discarded, or
        a flag they SHOULD be able to change goes read-only. Both are silent.

   WHEN TO DELETE THIS. It couples the .lfm to a resource template the migration
   intends to stop shipping. While both exist they must agree; when dialog 46 is
   removed from tr4w_eng.RES, delete this lint in the same commit rather than
   leaving it to fail mysteriously.

.PARAMETER SelfTest
   Runs the rules against built-in fixtures and fails if any rule does not
   behave as documented. Extend the fixtures whenever you extend the rules.

.OUTPUTS
   One line per violation. Exit code 0 = clean, 1 = at least one.
#>
[CmdletBinding()]
param(
   [string] $SourceDir,
   [switch] $SelfTest
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Run-Lints passes -SourceDir to every lint. This one wants tr4w\ rather than
# tr4w\src, because it reads res\, src\ui\lcl\ and test\ui\ together.
if (-not $SourceDir) { $SourceDir = Split-Path $PSScriptRoot -Parent }
$Tr4wDir = $SourceDir

$resFile = Join-Path $Tr4wDir 'res\tr4w_eng.res'
$pasFile = Join-Path $Tr4wDir 'src\ui\lcl\uEditQSOForm.pas'
$lfmFile = Join-Path $Tr4wDir 'src\ui\lcl\uEditQSOForm.lfm'
$DIALOG  = 46

# BS_CHECKBOX = 2, BS_AUTOCHECKBOX = 3, in the low nibble of the control style.
$BS_TYPEMASK     = 0x0F
$BS_CHECKBOX     = 2
$BS_AUTOCHECKBOX = 3

# ---------------------------------------------------------------- rule engine
# Each rule takes the three parsed artifacts and returns violation strings, so
# SelfTest can drive them against fixtures instead of the real files.
function Get-Violations {
   param($Template, $Table, $Lfm)

   $out = @()

   $tableById = @{}
   foreach ($row in $Table) {
      if ($tableById.ContainsKey($row.Id)) {
         $out += "EDITQSO_FIELDS: id $($row.Id) appears twice"
      } else {
         $tableById[$row.Id] = $row.Name
      }
   }

   # 1 -- template -> table
   foreach ($c in $Template) {
      if (-not $tableById.ContainsKey($c.Id)) {
         $out += "control $($c.Id) ($($c.Class)) is in dialog $DIALOG but not in EDITQSO_FIELDS"
      }
   }
   $templateIds = @{}
   foreach ($c in $Template) { $templateIds[$c.Id] = $true }
   foreach ($id in $tableById.Keys) {
      if (-not $templateIds.ContainsKey($id)) {
         $out += "EDITQSO_FIELDS names id $id, which dialog $DIALOG does not have"
      }
   }

   # 2 -- table -> .lfm
   $seenName = @{}
   foreach ($row in $Table) {
      if (-not $Lfm.ContainsKey($row.Name)) {
         $out += "EDITQSO_FIELDS id $($row.Id) names '$($row.Name)', which is not in the .lfm"
      }
      if ($seenName.ContainsKey($row.Name)) {
         $out += "EDITQSO_FIELDS: '$($row.Name)' is claimed by ids $($seenName[$row.Name]) and $($row.Id)"
      } else {
         $seenName[$row.Name] = $row.Id
      }
   }

   # 3 -- the editable/inert split
   foreach ($c in $Template) {
      if ($c.Class -ne 'BUTTON') { continue }
      $kind = $c.Style -band $BS_TYPEMASK
      if ($kind -ne $BS_CHECKBOX -and $kind -ne $BS_AUTOCHECKBOX) { continue }
      if (-not $tableById.ContainsKey($c.Id)) { continue }

      $name = $tableById[$c.Id]
      if (-not $Lfm.ContainsKey($name)) { continue }
      $disabled = $Lfm[$name].Disabled

      if ($kind -eq $BS_CHECKBOX -and -not $disabled) {
         $out += "$name (id $($c.Id)) is BS_CHECKBOX -- an indicator the save path never reads -- but is not Enabled = False, so the operator can change it and lose the change"
      }
      if ($kind -eq $BS_AUTOCHECKBOX -and $disabled) {
         $out += "$name (id $($c.Id)) is BS_AUTOCHECKBOX -- the save path reads it back -- but is Enabled = False, so it can never be changed"
      }
   }

   return $out
}

# ---------------------------------------------------------------- parsers
function Get-Table {
   param([string] $Path)
   $rows = @()
   foreach ($m in [regex]::Matches((Get-Content -Raw $Path), "\(Id:\s*(\d+);\s*Name:\s*'([^']+)'\)")) {
      $rows += [pscustomobject]@{ Id = [int]$m.Groups[1].Value; Name = $m.Groups[2].Value }
   }
   return $rows
}

function Get-Lfm {
   param([string] $Path)
   $map = @{}
   $current = $null
   foreach ($line in (Get-Content $Path)) {
      $m = [regex]::Match($line, '^\s*object\s+(\w+):\s*(\w+)\s*$')
      if ($m.Success) {
         $current = $m.Groups[1].Value
         $map[$current] = [pscustomobject]@{ Class = $m.Groups[2].Value; Disabled = $false }
         continue
      }
      if ($current -and $line -match '^\s*Enabled\s*=\s*False\s*$') {
         $map[$current].Disabled = $true
      }
      if ($line -match '^\s*end\s*$') { $current = $null }
   }
   return $map
}

if ($SelfTest) {
   $tpl = @(
      [pscustomobject]@{ Id = 125; Class = 'BUTTON'; Style = 0x50018503 }   # AUTO
      [pscustomobject]@{ Id = 156; Class = 'BUTTON'; Style = 0x50010002 }   # plain
      [pscustomobject]@{ Id = 118; Class = 'EDIT';   Style = 0x50010088 }
   )
   $tbl = @(
      [pscustomobject]@{ Id = 125; Name = 'chkSAP' }
      [pscustomobject]@{ Id = 156; Name = 'chkDXMult' }
      [pscustomobject]@{ Id = 118; Name = 'edtCallsign' }
   )
   $lfm = @{
      chkSAP      = [pscustomobject]@{ Class = 'TCheckBox'; Disabled = $false }
      chkDXMult   = [pscustomobject]@{ Class = 'TCheckBox'; Disabled = $true }
      edtCallsign = [pscustomobject]@{ Class = 'TEdit';     Disabled = $false }
   }

   $fail = 0
   $v = @(Get-Violations $tpl $tbl $lfm)
   if ($v.Count -ne 0) { Write-Output "SELFTEST: clean fixture reported $($v.Count):"; $v | ForEach-Object { Write-Output "   $_" }; $fail++ }

   # an inert box left editable must be caught
   $bad = @{ chkSAP = $lfm.chkSAP; chkDXMult = [pscustomobject]@{ Class='TCheckBox'; Disabled=$false }; edtCallsign = $lfm.edtCallsign }
   if (@(Get-Violations $tpl $tbl $bad).Count -eq 0) { Write-Output 'SELFTEST: an editable BS_CHECKBOX was not caught'; $fail++ }

   # an editable box greyed must be caught
   $bad2 = @{ chkSAP = [pscustomobject]@{ Class='TCheckBox'; Disabled=$true }; chkDXMult = $lfm.chkDXMult; edtCallsign = $lfm.edtCallsign }
   if (@(Get-Violations $tpl $tbl $bad2).Count -eq 0) { Write-Output 'SELFTEST: a disabled BS_AUTOCHECKBOX was not caught'; $fail++ }

   # a missing table row must be caught
   if (@(Get-Violations $tpl @($tbl | Where-Object Id -ne 118) $lfm).Count -eq 0) { Write-Output 'SELFTEST: a missing table row was not caught'; $fail++ }

   # a row naming nothing must be caught
   $tbl2 = @([pscustomobject]@{ Id=125; Name='chkSAP' }, [pscustomobject]@{ Id=156; Name='chkTypo' }, [pscustomobject]@{ Id=118; Name='edtCallsign' })
   if (@(Get-Violations $tpl $tbl2 $lfm).Count -eq 0) { Write-Output 'SELFTEST: a row naming a missing component was not caught'; $fail++ }

   if ($fail -gt 0) { Write-Output "Lint-EditQSOTemplate: $fail self-test(s) FAILED."; exit 1 }
   Write-Output 'Lint-EditQSOTemplate: self-test passed.'
   exit 0
}

foreach ($f in $resFile, $pasFile, $lfmFile) {
   if (-not (Test-Path $f)) { Write-Output "Lint-EditQSOTemplate: missing $f"; exit 1 }
}

# The template comes from the exporter, which is the one parser for this format.
$exporter = Join-Path $Tr4wDir 'test\ui\Export-DialogTemplate.ps1'
if (-not (Test-Path $exporter)) { Write-Output "Lint-EditQSOTemplate: missing $exporter"; exit 1 }

$dump = & $exporter -ResFile $resFile -Id $DIALOG | Out-String
$template = @()
foreach ($m in [regex]::Matches($dump, '(?m)^\s*(\d+)\s+(\S+)\s+-?\d+\s+-?\d+\s+-?\d+\s+-?\d+\s+0x([0-9A-F]{8})')) {
   $template += [pscustomobject]@{
      Id    = [int]$m.Groups[1].Value
      Class = $m.Groups[2].Value
      Style = [Convert]::ToUInt32($m.Groups[3].Value, 16)
   }
}
if ($template.Count -eq 0) { Write-Output 'Lint-EditQSOTemplate: parsed 0 controls from the exporter output'; exit 1 }

$violations = @(Get-Violations $template @(Get-Table $pasFile) (Get-Lfm $lfmFile))

if ($violations.Count -gt 0) {
   $violations | ForEach-Object { Write-Output "  $_" }
   Write-Output "Lint-EditQSOTemplate: $($violations.Count) disagreement(s) between dialog $DIALOG, EDITQSO_FIELDS and the .lfm."
   exit 1
}

Write-Output "Lint-EditQSOTemplate: dialog $DIALOG, EDITQSO_FIELDS and the .lfm agree on $($template.Count) control(s)."
exit 0
