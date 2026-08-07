<#
.SYNOPSIS
   Lints designed FMX forms whose navigation dispatches on Tag, for mistakes
   that are INVISIBLE at compile time and silent at run time.

.DESCRIPTION
   TPrefsForm selects a section by matching a nav item's Tag against the Tag on
   a panel in layContent -- no case statement and no lookup table, so adding a
   section is pure designer work. The cost of that simplicity is that the
   designer can now express states the compiler cannot see and the program will
   not complain about:

     * UNTAGGED NAV ITEM -- Tag defaults to 0 on every control ever dropped on a
       form, and 0 is the reserved "not a section" value. An item left at 0
       matches no panel, so the section silently shows the placeholder forever
       and looks like a section that has simply not been built yet.

     * DUPLICATE NAV TAG -- two nav items claiming one panel. Both rows appear
       to work; which one you get depends on nothing the operator can see.

     * DUPLICATE PANEL TAG -- two panels answering to one nav item. Both are
       made visible and draw on top of each other.

     * UNREACHABLE PANEL -- a tagged panel whose Tag matches no nav item. Dead
       UI: the section exists, is laid out, and cannot be navigated to.

   WHAT IS DELIBERATELY NOT A VIOLATION: a nav item with NO panel. That is the
   normal, intended state -- 13 of the 14 sections are exactly that today, and
   the placeholder is the designed answer for them. A linter that flagged those
   would fire thirteen times on a correct form and be ignored within a week,
   which is the failure Lint-PCharAnsi already had on its first run.

   SCOPE. A file is only examined if it contains at least one item named nav*.
   Tag is a general-purpose property and other forms are entitled to use it for
   anything; this lint has no opinion about a form that does not follow the
   convention.

.PARAMETER SourceDir
   Directory to scan recursively for .fmx files. Defaults to the src directory
   next to this script's parent (i.e. tr4w\src).

.PARAMETER SelfTest
   Runs the rules against built-in fixtures instead of the source tree, and
   fails if any rule does not behave as documented above. Extend the fixtures
   whenever you extend the rules -- a linter nobody trusts gets switched off.

.OUTPUTS
   One line per violation:  <file>:<line>: <message>
   Exit code 0 = clean, 1 = at least one violation (fails the build).
#>
[CmdletBinding()]
param(
   [string] $SourceDir,
   [switch] $SelfTest
)

# Parses one .fmx and returns the objects it declares, each with its Tag.
#
# The format nests, and `end` closes an object -- but `end` ALSO closes an item
# inside a collection property (CustomIcon = < item end >), which every TTabItem
# has. Counting those as objects would pop the stack early and attribute Tags to
# the wrong control, so collections are tracked and skipped.
function Get-FmxObjects {
   param([string] $Path)

   $objects = @()
   $stack = New-Object System.Collections.Generic.List[object]
   $collectionDepth = 0
   $lineNo = 0

   foreach ($raw in (Get-Content -LiteralPath $Path)) {
      $lineNo++
      $line = $raw.Trim()

      # Entering a collection property:  Foo = <
      if ($line -match '=\s*<\s*$') {
         $collectionDepth++
         continue
      }
      if ($collectionDepth -gt 0) {
         # A collection ends with '>' (often as 'end>'), possibly nested.
         if ($line -match '>\s*$') {
            $collectionDepth--
         }
         continue
      }

      if ($line -match '^object\s+([A-Za-z_][A-Za-z0-9_]*)\s*:\s*([A-Za-z_][A-Za-z0-9_]*)') {
         $obj = [pscustomobject]@{
            Name = $Matches[1]
            Type = $Matches[2]
            Tag  = 0            # Tag defaults to 0 and is omitted from the .fmx when it is 0
            Line = $lineNo
         }
         $objects += $obj
         $stack.Add($obj) | Out-Null
         continue
      }

      if ($line -eq 'end') {
         if ($stack.Count -gt 0) {
            $stack.RemoveAt($stack.Count - 1)
         }
         continue
      }

      # Tag belongs to the object currently open. Only a bare integer counts --
      # 'TagString' and 'TagFloat' are different properties.
      if ($line -match '^Tag\s*=\s*(-?\d+)\s*$') {
         if ($stack.Count -gt 0) {
            $stack[$stack.Count - 1].Tag = [int]$Matches[1]
         }
      }
   }

   return $objects
}

# Applies the four rules to one parsed form. Returns violation strings.
function Test-FormTags {
   param(
      [string] $DisplayPath,
      [object[]] $Objects
   )

   $violations = @()

   $navItems = @($Objects | Where-Object { $_.Name -like 'nav*' })
   if ($navItems.Count -eq 0) {
      # Not a tag-dispatched form. No opinion -- see SCOPE in the description.
      return $violations
   }

   foreach ($nav in $navItems) {
      if ($nav.Tag -eq 0) {
         $violations += ("{0}:{1}: nav item '{2}' has no Tag (0 is reserved for 'not a section'), so it can never match a panel and will silently show the placeholder" -f $DisplayPath, $nav.Line, $nav.Name)
      }
   }

   $navItems | Where-Object { $_.Tag -ne 0 } | Group-Object Tag | Where-Object { $_.Count -gt 1 } |
      ForEach-Object {
         $names = ($_.Group | ForEach-Object { $_.Name }) -join ', '
         foreach ($n in $_.Group) {
            $violations += ("{0}:{1}: duplicate nav Tag {2} on '{3}' (also: {4}) - two sections claiming one panel" -f $DisplayPath, $n.Line, $n.Tag, $n.Name, $names)
         }
      }

   # Everything else carrying a non-zero Tag is a section panel by convention.
   $panels = @($Objects | Where-Object { $_.Tag -ne 0 -and $_.Name -notlike 'nav*' })

   $panels | Group-Object Tag | Where-Object { $_.Count -gt 1 } |
      ForEach-Object {
         $names = ($_.Group | ForEach-Object { $_.Name }) -join ', '
         foreach ($p in $_.Group) {
            $violations += ("{0}:{1}: duplicate panel Tag {2} on '{3}' (also: {4}) - both panels are shown for one nav item" -f $DisplayPath, $p.Line, $p.Tag, $p.Name, $names)
         }
      }

   $navTags = @($navItems | ForEach-Object { $_.Tag })
   foreach ($p in $panels) {
      if ($navTags -notcontains $p.Tag) {
         $violations += ("{0}:{1}: panel '{2}' has Tag {3} but no nav item uses it - the section is laid out and unreachable" -f $DisplayPath, $p.Line, $p.Name, $p.Tag)
      }
   }

   # NOTE, deliberately absent: a nav item with no panel is NOT reported. It is
   # the intended state for every section not yet built. See the description.

   return $violations
}

# ---------------------------------------------------------------- self test --

function Invoke-SelfTest {
   $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("linttags_" + [Guid]::NewGuid().ToString('N'))
   New-Item -ItemType Directory -Path $tmp -Force | Out-Null

   # Each fixture: name, content, expected violation count.
   $fixtures = @(
      @{ Name = 'clean'; Expect = 0; Body = @'
object PrefsForm: TPrefsForm
  object lstNav: TListBox
    object navStation: TListBoxItem
      Tag = 1
      Text = 'Station'
    end
    object navHardware: TListBoxItem
      Tag = 2
      Text = 'Hardware'
    end
  end
  object layContent: TLayout
    object lblPlaceholder: TLabel
      Text = 'nothing here yet'
    end
    object layHardware: TLayout
      Tag = 2
    end
  end
end
'@ },

      # A nav item with no panel is the NORMAL case and must stay silent.
      @{ Name = 'nav_without_panel_is_legal'; Expect = 0; Body = @'
object PrefsForm: TPrefsForm
  object lstNav: TListBox
    object navStation: TListBoxItem
      Tag = 1
    end
    object navHardware: TListBoxItem
      Tag = 2
    end
    object navBackup: TListBoxItem
      Tag = 9
    end
  end
  object layContent: TLayout
    object layHardware: TLayout
      Tag = 2
    end
  end
end
'@ },

      @{ Name = 'untagged_nav_item'; Expect = 1; Body = @'
object PrefsForm: TPrefsForm
  object lstNav: TListBox
    object navStation: TListBoxItem
      Text = 'Station'
    end
  end
end
'@ },

      @{ Name = 'duplicate_nav_tag'; Expect = 2; Body = @'
object PrefsForm: TPrefsForm
  object lstNav: TListBox
    object navStation: TListBoxItem
      Tag = 3
    end
    object navBackup: TListBoxItem
      Tag = 3
    end
  end
end
'@ },

      @{ Name = 'duplicate_panel_tag'; Expect = 2; Body = @'
object PrefsForm: TPrefsForm
  object lstNav: TListBox
    object navHardware: TListBoxItem
      Tag = 2
    end
  end
  object layContent: TLayout
    object layHardware: TLayout
      Tag = 2
    end
    object layOther: TLayout
      Tag = 2
    end
  end
end
'@ },

      @{ Name = 'unreachable_panel'; Expect = 1; Body = @'
object PrefsForm: TPrefsForm
  object lstNav: TListBox
    object navHardware: TListBoxItem
      Tag = 2
    end
  end
  object layContent: TLayout
    object layGhost: TLayout
      Tag = 7
    end
  end
end
'@ },

      # No nav* items: out of scope, whatever the Tags say.
      @{ Name = 'not_a_nav_form'; Expect = 0; Body = @'
object RadioEditForm: TRadioEditForm
  object tabsTransport: TTabControl
    object tabSerial: TTabItem
      Tag = 5
      CustomIcon = <
        item
        end>
      Text = 'Serial'
    end
    object tabNetwork: TTabItem
      Tag = 5
      CustomIcon = <
        item
        end>
      Text = 'Network'
    end
  end
end
'@ },

      # A collection property must not confuse the object/end tracking: if it
      # did, layHardware's Tag would be attributed to the wrong control and the
      # panel would look unreachable.
      @{ Name = 'collection_does_not_break_parsing'; Expect = 0; Body = @'
object PrefsForm: TPrefsForm
  object lstNav: TListBox
    object navHardware: TListBoxItem
      Tag = 2
      CustomIcon = <
        item
        end>
      Text = 'Hardware'
    end
  end
  object layContent: TLayout
    object layHardware: TLayout
      Tag = 2
    end
  end
end
'@ }
   )

   $failed = 0
   foreach ($f in $fixtures) {
      $path = Join-Path $tmp ($f.Name + '.fmx')
      Set-Content -LiteralPath $path -Value $f.Body -Encoding ASCII
      $objs = Get-FmxObjects -Path $path
      $v = @(Test-FormTags -DisplayPath $f.Name -Objects $objs)
      if ($v.Count -ne $f.Expect) {
         Write-Output ("SELFTEST FAIL {0}: expected {1} violation(s), got {2}" -f $f.Name, $f.Expect, $v.Count)
         $v | ForEach-Object { Write-Output ("   " + $_) }
         $failed++
      }
      else {
         Write-Output ("SELFTEST ok   {0} ({1} violation(s))" -f $f.Name, $v.Count)
      }
   }

   Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue

   if ($failed -gt 0) {
      Write-Output ("Lint-FormTags SELFTEST: {0} fixture(s) failed." -f $failed)
      exit 1
   }
   Write-Output ("Lint-FormTags SELFTEST: all {0} fixtures behaved as documented." -f $fixtures.Count)
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
   Write-Output ("Lint-FormTags: source directory not found: {0}" -f $SourceDir)
   exit 1
}

$files = @(Get-ChildItem -LiteralPath $SourceDir -Recurse -Filter *.fmx -File |
           Where-Object { $_.FullName -notmatch '\\__history\\|\\__recovery\\' })

$violations = @()
$formsChecked = 0

foreach ($file in $files) {
   $objects = Get-FmxObjects -Path $file.FullName
   if (@($objects | Where-Object { $_.Name -like 'nav*' }).Count -gt 0) {
      $formsChecked++
   }
   $violations += Test-FormTags -DisplayPath $file.FullName -Objects $objects
}

if ($violations.Count -gt 0) {
   $violations | ForEach-Object { Write-Output $_ }
   Write-Output ("Lint-FormTags: {0} violation(s) across {1} tag-dispatched form(s)." -f $violations.Count, $formsChecked)
   exit 1
}

Write-Output ("Lint-FormTags: {0} .fmx file(s) checked, {1} tag-dispatched, no tag defects." -f $files.Count, $formsChecked)
exit 0
