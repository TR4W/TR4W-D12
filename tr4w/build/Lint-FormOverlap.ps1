<#
.SYNOPSIS
   Fails the build when two sibling controls on a designed form overlap.

.DESCRIPTION
   NY4I opened the DX Cluster page and found "Collect spots from the cluster"
   printed on top of "Connect at startup", with the explanatory note printed
   through the "After connecting, send" row. Both were mine: I inserted new
   controls into a panel and did not move the ones already there.

   THE COMPILER CANNOT SEE THIS. A .fmx is data; two controls at the same
   Position.Y are as valid as any other arrangement, and the only symptom is a
   screenshot. That makes it exactly the sort of thing a lint should own -- and
   the reason this exists is that hand-editing .fmx coordinates, which is how
   panels get built here, makes the mistake easy and silent.

   SIBLINGS ONLY, and that is the whole subtlety. FMX coordinates are relative
   to the PARENT, so a control inside a TGroupBox shares a coordinate space with
   its group-mates and NOT with the panel's own controls. A checker that
   flattens the tree reports the entire Hardware page as broken -- the first
   version of this did, 22 false positives out of 23 -- so nesting is tracked
   and only controls with the same parent are compared.

   WHAT IS DELIBERATELY NOT CHECKED:
     * containers (TLayout, TGroupBox) -- a container is SUPPOSED to contain
       things, and section panels all share the content area by design, since
       exactly one is visible at a time.
     * zero-width controls -- not laid out yet, or sized at runtime.
     * controls on different parents, however they look on screen.

.PARAMETER SourceDir
   The src directory. Defaults to the one next to this script's parent.

.PARAMETER SelfTest
   Runs the rules against built-in fixtures instead of the source tree.

.OUTPUTS
   One line per overlapping pair. Exit code 0 = clean, 1 = at least one.
#>
[CmdletBinding()]
param(
   [string] $SourceDir,
   [switch] $SelfTest
)

$CONTAINERS = @('TLayout', 'TGroupBox', 'TTreeView', 'TTreeViewItem', 'TPanel',
                'TForm', 'TTabControl', 'TTabItem', 'TScrollBox', 'TVertScrollBox')

function Get-FmxControls {
   param([string[]] $Lines)

   $stack = New-Object System.Collections.Generic.List[object]
   $nodes = @()

   foreach ($raw in $Lines) {
      $line = $raw.Trim()

      if ($line -match '^object\s+([A-Za-z_][A-Za-z0-9_]*)\s*:\s*([A-Za-z_][A-Za-z0-9_]*)') {
         $parent = '(form)'
         if ($stack.Count -gt 0) { $parent = $stack[$stack.Count - 1].Name }
         $node = [pscustomobject]@{
            Name = $Matches[1]; Type = $Matches[2]; Parent = $parent
            X = 0.0; Y = 0.0; W = 0.0; H = 0.0
         }
         $nodes += $node
         $stack.Add($node) | Out-Null
         continue
      }

      if ($line -eq 'end') {
         if ($stack.Count -gt 0) { $stack.RemoveAt($stack.Count - 1) }
         continue
      }

      if ($stack.Count -eq 0) { continue }
      $top = $stack[$stack.Count - 1]

      if ($line -match '^Position\.X\s*=\s*([\d.]+)')  { $top.X = [double]$Matches[1] }
      elseif ($line -match '^Position\.Y\s*=\s*([\d.]+)')  { $top.Y = [double]$Matches[1] }
      elseif ($line -match '^Size\.Width\s*=\s*([\d.]+)')  { $top.W = [double]$Matches[1] }
      elseif ($line -match '^Size\.Height\s*=\s*([\d.]+)') { $top.H = [double]$Matches[1] }
   }

   return $nodes
}

function Test-Overlaps {
   param([string] $DisplayPath, [object[]] $Nodes)

   $violations = @()

   # Containers are excluded, and so is anything with no width -- see the
   # description for why each of those would otherwise be noise.
   $laid = @($Nodes | Where-Object { $CONTAINERS -notcontains $_.Type -and $_.W -gt 0 -and $_.H -gt 0 })

   foreach ($group in ($laid | Group-Object Parent)) {
      $items = @($group.Group)
      for ($i = 0; $i -lt $items.Count; $i++) {
         for ($j = $i + 1; $j -lt $items.Count; $j++) {
            $a = $items[$i]; $b = $items[$j]
            $xo = ($a.X -lt ($b.X + $b.W)) -and ($b.X -lt ($a.X + $a.W))
            $yo = ($a.Y -lt ($b.Y + $b.H)) -and ($b.Y -lt ($a.Y + $a.H))
            if ($xo -and $yo) {
               $violations += ("{0}: '{1}' ({2},{3} {4}x{5}) overlaps '{6}' ({7},{8} {9}x{10}) inside {11}" -f `
                  $DisplayPath, $a.Name, $a.X, $a.Y, $a.W, $a.H, $b.Name, $b.X, $b.Y, $b.W, $b.H, $group.Name)
            }
         }
      }
   }

   return $violations
}

# ---------------------------------------------------------------- self test --

function Invoke-SelfTest {
   $fixtures = @(
      @{ Name = 'clean'; Expect = 0; Body = @'
object Form1: TForm
  object layOne: TLayout
    object lblA: TLabel
      Position.X = 12.000000000000000000
      Position.Y = 8.000000000000000000
      Size.Width = 100.000000000000000000
      Size.Height = 17.000000000000000000
    end
    object lblB: TLabel
      Position.X = 12.000000000000000000
      Position.Y = 30.000000000000000000
      Size.Width = 100.000000000000000000
      Size.Height = 17.000000000000000000
    end
  end
end
'@ },

      # The DX Cluster failure: a control inserted at a Y already in use.
      @{ Name = 'same_row_overlap'; Expect = 1; Body = @'
object Form1: TForm
  object layOne: TLayout
    object chkA: TCheckBox
      Position.X = 12.000000000000000000
      Position.Y = 118.000000000000000000
      Size.Width = 460.000000000000000000
      Size.Height = 22.000000000000000000
    end
    object chkB: TCheckBox
      Position.X = 12.000000000000000000
      Position.Y = 118.000000000000000000
      Size.Width = 460.000000000000000000
      Size.Height = 22.000000000000000000
    end
  end
end
'@ },

      # A wide heading running into the second column -- the Station page.
      @{ Name = 'column_bleed'; Expect = 1; Body = @'
object Form1: TForm
  object layOne: TLayout
    object lblLeft: TLabel
      Position.X = 12.000000000000000000
      Position.Y = 8.000000000000000000
      Size.Width = 400.000000000000000000
      Size.Height = 17.000000000000000000
    end
    object lblRight: TLabel
      Position.X = 380.000000000000000000
      Position.Y = 8.000000000000000000
      Size.Width = 280.000000000000000000
      Size.Height = 17.000000000000000000
    end
  end
end
'@ },

      # THE FALSE POSITIVE THIS LINT WAS ALMOST SHIPPED WITH.  A group box's
      # children are positioned relative to the GROUP, so they may sit at
      # coordinates that look like the panel's own controls.  Different parents,
      # not a violation.
      @{ Name = 'nested_is_not_an_overlap'; Expect = 0; Body = @'
object Form1: TForm
  object layOne: TLayout
    object lstThing: TListBox
      Position.X = 12.000000000000000000
      Position.Y = 30.000000000000000000
      Size.Width = 420.000000000000000000
      Size.Height = 150.000000000000000000
    end
    object grpBox: TGroupBox
      Position.X = 12.000000000000000000
      Position.Y = 195.000000000000000000
      Size.Width = 540.000000000000000000
      Size.Height = 260.000000000000000000
      object cbxInside: TComboBox
        Position.X = 12.000000000000000000
        Position.Y = 26.000000000000000000
        Size.Width = 200.000000000000000000
        Size.Height = 22.000000000000000000
      end
    end
  end
end
'@ },

      # Section panels all fill the content area and take turns being visible.
      @{ Name = 'sibling_panels_are_not_an_overlap'; Expect = 0; Body = @'
object Form1: TForm
  object layContent: TLayout
    object layA: TLayout
      Position.X = 0.000000000000000000
      Position.Y = 0.000000000000000000
      Size.Width = 675.000000000000000000
      Size.Height = 572.000000000000000000
    end
    object layB: TLayout
      Position.X = 0.000000000000000000
      Position.Y = 0.000000000000000000
      Size.Width = 675.000000000000000000
      Size.Height = 572.000000000000000000
    end
  end
end
'@ }
   )

   $failed = 0
   foreach ($f in $fixtures) {
      $nodes = Get-FmxControls -Lines ($f.Body -split "`r?`n")
      $v = @(Test-Overlaps -DisplayPath $f.Name -Nodes $nodes)
      if ($v.Count -ne $f.Expect) {
         Write-Output ("SELFTEST FAIL {0}: expected {1}, got {2}" -f $f.Name, $f.Expect, $v.Count)
         $v | ForEach-Object { Write-Output ("   " + $_) }
         $failed++
      }
      else {
         Write-Output ("SELFTEST ok   {0} ({1} overlap(s))" -f $f.Name, $v.Count)
      }
   }

   if ($failed -gt 0) {
      Write-Output ("Lint-FormOverlap SELFTEST: {0} fixture(s) failed." -f $failed)
      exit 1
   }
   Write-Output ("Lint-FormOverlap SELFTEST: all {0} fixtures behaved as documented." -f $fixtures.Count)
   exit 0
}

# --------------------------------------------------------------------- main --

if ($SelfTest) {
   Invoke-SelfTest
}

if (-not $SourceDir) {
   $SourceDir = Join-Path (Split-Path -Parent $PSScriptRoot) 'src'
}

# .fmx AND .lfm.  The two designers write the same object/property/end grammar,
# so this lint reads both -- verified 2026-08-13 by running it over the LCL
# forms renamed to .fmx and getting identical, sensible answers. Filtering on
# .fmx alone meant that as each form was ported to the LCL it silently dropped
# out of this gate, which is how a designed-form defect gets shipped.
$files = @(Get-ChildItem -Path $SourceDir -Recurse -File | Where-Object { $_.Extension -in '.fmx', '.lfm' })
$violations = @()
foreach ($f in $files) {
   $nodes = Get-FmxControls -Lines (Get-Content -LiteralPath $f.FullName)
   $violations += Test-Overlaps -DisplayPath $f.FullName -Nodes $nodes
}

if ($violations.Count -gt 0) {
   $violations | ForEach-Object { Write-Output $_ }
   Write-Output ("Lint-FormOverlap: {0} overlapping control pair(s)." -f $violations.Count)
   exit 1
}

Write-Output ("Lint-FormOverlap: {0} .fmx file(s) checked, no sibling controls overlap." -f $files.Count)
exit 0
