<#
.SYNOPSIS
   Lints the radio factory registrations for collisions that are INVISIBLE at
   compile time and silent at run time.

.DESCRIPTION
   uRadioRegistry.DoRegister stores registrations with AddOrSetValue and has no
   logger, so both of these fail quietly:

     * DUPLICATE DISPLAY NAME -- two models registered under one name. The radio
       selection list shows a single entry, so an owner of the un-named model
       finds no entry for their radio and concludes the build does not support
       it. (Real case: the IC-7851 was registered as 'Icom IC-7850'.) The rule
       is ONE REGISTRY ENTRY PER MODEL AN OPERATOR CAN BUY, however many models
       share an implementation class.

     * DUPLICATE REGISTRATION KEY -- the same enum member or string id
       registered twice. AddOrSetValue means the LAST registration silently
       wins and the first is discarded, so a radio can be driven by a class
       nobody expects.

   This is a static property of the source, which is why it belongs in a
   pre-build hook rather than a startup log line: registration happens in unit
   initialization, which runs BEFORE tr4w.dpr configures the log appender, so a
   warning logged from the registry would go nowhere.

.PARAMETER SourceDir
   Directory to scan recursively for .pas files. Defaults to the src directory
   next to this script's parent (i.e. tr4w\src).

.OUTPUTS
   One line per violation:  <file>:<line>: <message>
   Exit code 0 = clean, 1 = at least one violation (fails the build).
#>
[CmdletBinding()]
param(
   [string] $SourceDir
)

if (-not $SourceDir) {
   $SourceDir = Join-Path (Split-Path -Parent $PSScriptRoot) 'src'
}

if (-not (Test-Path -LiteralPath $SourceDir -PathType Container)) {
   Write-Error "Lint-RadioRegistry: source directory not found: $SourceDir"
   exit 1
}

# A registration looks like:
#   RegisterRadio(<enumMember>, <ctor>, '<displayName>', [links], port, flag);
#   RegisterRadioById('<id>',   <ctor>, '<displayName>', [links], port, flag);
#   RegisterHamLibOnlyRadio(<enumMember>, <ctor>, '<displayName>', hamlibID, serial);
# The ctor is an anonymous function containing no string literals (the HamLib-
# only closures pass the enum member, not a name, for exactly this reason), so
# the quoted literals appear in a predictable order: for the ById form the
# FIRST is the id and the SECOND is the display name; for the enum forms the
# FIRST is the display name.
$callPattern = [regex] '(?s)Register(?:HamLibOnly)?Radio(?<byId>ById)?\s*\(\s*(?<args>.*?)\)\s*;'

$registrations = @()

function Remove-PascalComments {
   param([string] $Source)
   # Blank out comments so a documentation EXAMPLE of a RegisterRadio call (there
   # is one in uRadioRegistry's own header) is not linted as a real registration.
   # Newlines are preserved so reported line numbers stay accurate.
   $s = [regex]::Replace($Source, '(?s)\{.*?\}', { param($m) ($m.Value -replace '[^\r\n]', ' ') })
   $s = [regex]::Replace($s, '(?m)//[^\r\n]*',  { param($m) ($m.Value -replace '[^\r\n]', ' ') })
   return $s
}

foreach ($file in Get-ChildItem -LiteralPath $SourceDir -Recurse -Filter *.pas) {
   $text = Get-Content -LiteralPath $file.FullName -Raw
   if (-not $text) { continue }
   $text = Remove-PascalComments $text

   foreach ($m in $callPattern.Matches($text)) {
      $args = $m.Groups['args'].Value
      $isById = $m.Groups['byId'].Success

      # Skip the declarations/forwards in uRadioRegistry itself and any
      # commented-out example: every real call passes an anonymous constructor
      # closure.  (The old test required a bracketed link set, which silently
      # excluded the RegisterHamLibOnlyRadio form -- it has no links argument.)
      if ($args -notmatch 'function\s*:') { continue }

      # @() is load-bearing: with a SINGLE literal, ForEach-Object returns a bare
      # string and $literals[0] would index its first CHARACTER, not the literal.
      $literals = @([regex]::Matches($args, "'([^']*)'") | ForEach-Object { $_.Groups[1].Value })
      if ($isById) {
         if ($literals.Count -lt 2) { continue }
         $key     = $literals[0]
         $display = $literals[1]
      }
      else {
         if ($literals.Count -lt 1) { continue }
         $key     = ($args -split ',')[0].Trim()
         $display = $literals[0]
      }

      # 1-based line number of this call, for a clickable message.
      $line = ($text.Substring(0, $m.Index) -split "`n").Count

      $registrations += [pscustomobject]@{
         File    = $file.FullName
         Line    = $line
         Key     = $key
         Display = $display
      }
   }
}

$violations = 0

# --- duplicate display names ------------------------------------------------
$registrations |
   Group-Object { $_.Display.Trim().ToLowerInvariant() } |
   Where-Object { $_.Count -gt 1 } |
   ForEach-Object {
      $group = $_.Group
      $keys  = ($group | ForEach-Object { $_.Key }) -join ', '
      foreach ($r in $group) {
         Write-Output ("{0}:{1}: duplicate radio display name '{2}' (registered for: {3}) - one model will be INVISIBLE in the radio selection list; give each model its own entry and name" -f $r.File, $r.Line, $r.Display, $keys)
         $violations++
      }
   }

# --- duplicate registration keys --------------------------------------------
$registrations |
   Group-Object { $_.Key.Trim().ToLowerInvariant() } |
   Where-Object { $_.Count -gt 1 } |
   ForEach-Object {
      $group = $_.Group
      foreach ($r in $group) {
         Write-Output ("{0}:{1}: duplicate radio registration key '{2}' - AddOrSetValue means the LAST registration silently wins and the earlier one is discarded" -f $r.File, $r.Line, $r.Key)
         $violations++
      }
   }

if ($violations -gt 0) {
   Write-Output ("Lint-RadioRegistry: {0} violation(s) across {1} registration(s)." -f $violations, $registrations.Count)
   exit 1
}

Write-Output ("Lint-RadioRegistry: {0} radio registrations, no collisions." -f $registrations.Count)
exit 0
