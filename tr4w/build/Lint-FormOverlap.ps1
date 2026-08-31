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

. (Join-Path $PSScriptRoot 'Get-ScanExclusions.ps1')   # Test-Tr4wScannable -- IDE backup dirs are not source

# TTabSheet/TPage join the list for the same reason TTabItem is already on it:
# the pages of a tab control are SUPPOSED to sit on top of each other, and
# flagging them would train the reader to ignore this lint.
$CONTAINERS = @('TLayout', 'TGroupBox', 'TTreeView', 'TTreeViewItem', 'TPanel',
                'TForm', 'TTabControl', 'TTabItem', 'TScrollBox', 'TVertScrollBox',
                'TPageControl', 'TTabSheet', 'TNotebook', 'TPage')

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
            # CW/CH are the CLIENT area -- what a child is actually laid inside.
            # They differ from W/H by the border and any caption, and on a form
            # ClientWidth is streamed AFTER Width, so it is the one that wins.
            CW = 0.0; CH = 0.0
            # A control the LCL positions itself. Its designed coordinates are
            # overwritten at run time, so measuring them means nothing.
            Align = 'alNone'
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

      # BOTH DIALECTS. FMX writes Position.X / Size.Width; the LCL writes plain
      # Left / Top / Width / Height. .lfm was added to the file filter without
      # teaching the parser that, so every LCL control parsed as 0x0 at (0,0),
      # the W>0 filter discarded all of them, and the lint reported "no overlaps"
      # having examined nothing. It passed over a real overlap on the Network page.
      if ($line -match '^Position\.X\s*=\s*([\d.]+)')  { $top.X = [double]$Matches[1] }
      elseif ($line -match '^Position\.Y\s*=\s*([\d.]+)')  { $top.Y = [double]$Matches[1] }
      elseif ($line -match '^Size\.Width\s*=\s*([\d.]+)')  { $top.W = [double]$Matches[1] }
      elseif ($line -match '^Size\.Height\s*=\s*([\d.]+)') { $top.H = [double]$Matches[1] }
      elseif ($line -match '^Left\s*=\s*(-?[\d.]+)')      { $top.X = [double]$Matches[1] }
      elseif ($line -match '^Top\s*=\s*(-?[\d.]+)')       { $top.Y = [double]$Matches[1] }
      elseif ($line -match '^Width\s*=\s*(-?[\d.]+)')     { $top.W = [double]$Matches[1] }
      elseif ($line -match '^Height\s*=\s*(-?[\d.]+)')    { $top.H = [double]$Matches[1] }
      elseif ($line -match '^ClientWidth\s*=\s*(-?[\d.]+)')  { $top.CW = [double]$Matches[1] }
      elseif ($line -match '^ClientHeight\s*=\s*(-?[\d.]+)') { $top.CH = [double]$Matches[1] }
      elseif ($line -match '^Align\s*=\s*(al[A-Za-z]+)')     { $top.Align = $Matches[1] }
   }

   return $nodes
}

function Test-Overlaps {
   param([string] $DisplayPath, [object[]] $Nodes)

   $violations = @()

   # Containers are excluded, and so is anything with no width -- see the
   # description for why each of those would otherwise be noise.
   $laid = @($Nodes | Where-Object { $CONTAINERS -notcontains $_.Type -and $_.W -gt 0 -and $_.H -gt 0 })
   $script:totalLaid += $laid.Count

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

function Test-OutOfBounds {
   <#
      A control whose right or bottom edge lies outside its PARENT'S CLIENT AREA
      is clipped.

      THE .lfm IS THE SHIPPED DEFAULT (NY4I, 2026-08-26): "the form is displayed
      with the height, width, left and top we set in the form editor, and that's
      the default. If the user resizes it, great." So a first run, with nothing
      saved, shows exactly what is in the file -- and on a modal dialog the
      operator may never think to resize it away.

      FOUND BY THIS, THE DAY IT WAS WRITTEN. A Lazarus "resave forms with i18n"
      pass rewrote all 37 .lfm files and left uAboutForm with ClientWidth = 320
      holding a memo, a URL label and an OK button that all end at x=384. All 23
      lints passed, including the sibling-overlap half of this one: the controls
      did not overlap EACH OTHER, they hung off the edge of the form.

      MEASURED AGAINST THE CLIENT AREA, NOT Width. They differ by the border and
      the caption, and on a form ClientWidth is streamed after Width and wins.
      Where a parent declares no client size -- most panels -- W/H is the best
      available and is what a child is laid inside anyway.

      ALIGNED CONTROLS ARE SKIPPED. alClient, alTop and friends are positioned
      by the LCL at run time; their designed coordinates are overwritten, so
      measuring them reports noise. That is the same lesson the sibling check
      learned from flattening the tree -- 22 false positives out of 23.
   #>
   param([string] $DisplayPath, [object[]] $Nodes)

   $violations = @()
   $byName = @{}
   foreach ($n in $Nodes) { $byName[$n.Name] = $n }

   # THE FORM'S OWN CHILDREN ONLY, and that restriction is the difference between
   # a lint and noise. A nested container is SIZED BY ITS PARENT AT RUN TIME: a
   # TTabSheet declares ClientHeight = 26 in the .lfm -- that is the tab strip --
   # and is then stretched to fill its page control. Measuring against declared
   # nested sizes reported 175 violations where the real count was 3.
   #
   # The form is the one container whose declared size IS what ships, which is
   # exactly what the canon covers.
   $root = $Nodes | Where-Object { $_.Parent -eq '(form)' } | Select-Object -First 1
   if (-not $root) { return $violations }

   foreach ($n in $Nodes) {
      if ($n.W -le 0 -or $n.H -le 0) { continue }
      if ($n.Align -ne 'alNone') { continue }
      if ($n.Parent -ne $root.Name) { continue }
      if (-not $byName.ContainsKey($n.Parent)) { continue }   # the root itself

      # THE LARGER OF THE TWO, AND THAT IS NOT A FUDGE -- IT IS MEASURED.
      #
      # A .lfm can carry both Width and ClientWidth, and they can disagree:
      # uAboutForm says Width = 400 and ClientWidth = 320. Reading the stream
      # order, ClientWidth comes last and looks like the winner, so the first
      # version of this check reported three controls hanging off that form.
      #
      # It is wrong. Built into a minimal LCL application with that exact
      # property sequence, the form reports ClientWidth = 400 at run time: the
      # declared 320 does not survive. So the effective area is the larger
      # value, and measuring against the smaller one condemns a form that
      # renders correctly.
      #
      # Which is the whole reason this is measured rather than reasoned about.
      $p = $byName[$n.Parent]
      $pw = [Math]::Max($p.CW, $p.W)
      $ph = [Math]::Max($p.CH, $p.H)

      if ($pw -gt 0 -and ($n.X + $n.W) -gt $pw) {
         $violations += ("{0}: '{1}' right edge {2} is outside '{3}' (client width {4})" -f `
            $DisplayPath, $n.Name, ($n.X + $n.W), $p.Name, $pw)
      }
      if ($ph -gt 0 -and ($n.Y + $n.H) -gt $ph) {
         $violations += ("{0}: '{1}' bottom edge {2} is outside '{3}' (client height {4})" -f `
            $DisplayPath, $n.Name, ($n.Y + $n.H), $p.Name, $ph)
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
$totalLaid = 0
# NOT the IDE's backup copies. Lazarus writes a previous revision into
# src/ui/lcl/backup/ every time it saves a form, so those are STALE BY
# DEFINITION -- and a stale layout failing the build is a false alarm about a
# file nothing compiles. Found when the bounds check reported 175 violations
# and most of them were in backup/.
$files = @(Get-ChildItem -Path $SourceDir -Recurse -File |
   Where-Object { $_.Extension -in '.fmx', '.lfm' -and $_.FullName -notmatch '\\backup\\' })
$violations = @()
$bounds = @()
foreach ($f in $files) {
   $nodes = Get-FmxControls -Lines (Get-Content -LiteralPath $f.FullName)
   $violations += Test-Overlaps -DisplayPath $f.FullName -Nodes $nodes
   $bounds   += Test-OutOfBounds -DisplayPath $f.FullName -Nodes $nodes
}

# Reported separately: they are different defects with different fixes. An
# overlap means two controls were placed on the same spot; out-of-bounds means
# the container is too small for what it holds.
if ($bounds.Count -gt 0) {
   $bounds | ForEach-Object { Write-Output $_ }
   Write-Output ("Lint-FormOverlap: {0} control(s) outside their parent's client area." -f $bounds.Count)
   Write-Output "  Resize the container in the form editor -- the .lfm is the shipped default,"
   Write-Output "  so a first run with nothing saved displays exactly this."
   exit 1
}

if ($violations.Count -gt 0) {
   $violations | ForEach-Object { Write-Output $_ }
   Write-Output ("Lint-FormOverlap: {0} overlapping control pair(s)." -f $violations.Count)
   exit 1
}

# THE COUNT OF CONTROLS, not just of files. "9 files checked" was true while
# the parser understood none of the LCL ones -- a clean result that had
# examined nothing. Saying how many controls were laid out makes that
# visible, and the floor below makes it fail rather than pass.
if ($totalLaid -lt 1) {
   Write-Output "Lint-FormOverlap: parsed 0 positioned controls -- the parser is not reading these files."
   exit 1
}
Write-Output ("Lint-FormOverlap: {0} form file(s), {1} positioned control(s) checked, no sibling controls overlap." -f $files.Count, $totalLaid)
exit 0
