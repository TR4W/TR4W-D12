# Lint-FormatArgs.ps1 -- a RAW POINTER may not be a Format argument.
#
# ---------------------------------------------------------------------------
# WHAT THIS CATCHES, AND WHY IT IS NOT A STYLE RULE
# ---------------------------------------------------------------------------
#
# An `array of const` element built from `@something` enters the variant array
# as vtPointer. Format's %s accepts vtString, vtAnsiString, vtPChar, vtChar,
# vtWideString and vtUnicodeString -- NOT vtPointer -- and FPC reports that
# TYPE mismatch as
#
#     Invalid argument index in format "%s is a dupe and will be logged ..."
#
# which reads like a specifier-counting bug and is nothing of the sort. It is
# a MODAL DIALOG in front of an operator, mid-contest, offering "OK to ignore
# and risk data corruption" -- and it only appears when that particular message
# fires, so it is found one bench session at a time.
#
# NY4I, 2026-09-14, on being shown the dupe message: "We need a better way to
# handle these ... We cannot debug these one at a time."
#
# Eight call sites were live when this was written, every one an
# operator-facing message: the dupe warning, "you already worked in", improper
# syntax, "invalid statement in config file", "unable to find", the WAE QTC
# QRV prompt and the CQ repeat notice.
#
# ---------------------------------------------------------------------------
# WHY A SCAN RATHER THAN RTTI
# ---------------------------------------------------------------------------
#
# A test harness cannot enumerate Format CALL SITES -- RTTI describes types,
# not call sites, and a runtime check only sees the calls a test happens to
# execute, which is the "one at a time" problem again. The argument list is
# only visible in the SOURCE, so the source is where it gets checked.
#
# A runtime guard is still worth having for the residue (a wrong specifier
# COUNT, which no static scan can settle), but it is the second line, not the
# first.
#
# ---------------------------------------------------------------------------
# BALANCED BRACKETS, NOT A REGEX
# ---------------------------------------------------------------------------
#
# The argument that matters looks like
#
#     [@RXData.Callsign[1]]
#
# and a [^\]]* pattern stops at the INNER ']' -- so the naive regex misses
# precisely the case being hunted. That is not hypothetical: the first version
# of this scan reported 4 hits, all of them harmless, and missed all 8 real
# ones. Bracket depth is counted here.

param([string] $SourceDir = (Join-Path (Split-Path $PSScriptRoot -Parent) ''))

Set-StrictMode -Version Latest
Import-Module (Join-Path $PSScriptRoot 'PascalSource.psm1') -Force

$root = if ($SourceDir) { $SourceDir } else { Split-Path $PSScriptRoot -Parent }

$call = [regex]::new('(?i)\b(?:SysUtils\.|Windows\.)?(?:Format|WideFormat)\s*\(')

# Casts that give the argument a type Format understands.
$safe = [regex]::new('(?i)^\s*(PAnsiChar|PChar|PWideChar|string|AnsiString|' +
                     'UnicodeString|WideString|ShortString|RawByteString)\s*\(')

function Get-TopLevelArrays([string] $text, [int] $start)
{
   $out = New-Object System.Collections.Generic.List[string]
   $depth = 0
   $i = $start
   while ($i -lt $text.Length)
      {
      $c = $text[$i]
      if ($c -eq '(') { $depth++ }
      elseif ($c -eq ')') { $depth--; if ($depth -le 0) { break } }
      elseif ($c -eq '[' -and $depth -ge 1)
         {
         $b = 0
         $j = $i
         while ($j -lt $text.Length)
            {
            if ($text[$j] -eq '[') { $b++ }
            elseif ($text[$j] -eq ']')
               {
               $b--
               if ($b -eq 0) { $out.Add($text.Substring($i + 1, $j - $i - 1)); $i = $j; break }
               }
            $j++
            }
         if ($j -ge $text.Length) { break }
         }
      $i++
      }
   return $out
}

function Split-TopLevel([string] $s)
{
   $out = New-Object System.Collections.Generic.List[string]
   $cur = New-Object System.Text.StringBuilder
   $p = 0; $b = 0
   foreach ($ch in $s.ToCharArray())
      {
      if     ($ch -eq '(') { $p++ }
      elseif ($ch -eq ')') { $p-- }
      elseif ($ch -eq '[') { $b++ }
      elseif ($ch -eq ']') { $b-- }
      if ($ch -eq ',' -and $p -eq 0 -and $b -eq 0)
         { $out.Add($cur.ToString()); $cur = New-Object System.Text.StringBuilder }
      else { [void]$cur.Append($ch) }
      }
   if ($cur.Length -gt 0) { $out.Add($cur.ToString()) }
   return $out
}

$files = Get-TR4WPascalFiles -Root $root |
         Where-Object { $_.FullName -notmatch '\\graphify-out\\|\\backup\\' }

$bad = New-Object System.Collections.Generic.List[string]
$scanned = 0

foreach ($f in $files)
   {
   $scanned++
   $lines = Get-PascalCodeOnlyLines -Path $f.FullName
   for ($i = 0; $i -lt $lines.Count; $i++)
      {
      if (-not $call.IsMatch($lines[$i])) { continue }
      $last = [Math]::Min($i + 5, $lines.Count - 1)
      $window = ($lines[$i..$last] -join ' ')
      foreach ($m in $call.Matches($lines[$i]))
         {
         foreach ($arr in (Get-TopLevelArrays $window ($m.Index + $m.Length - 1)))
            {
            foreach ($a in (Split-TopLevel $arr))
               {
               $t = $a.Trim()
               if (-not $t.StartsWith('@')) { continue }
               if ($safe.IsMatch($t)) { continue }
               $rel = $f.FullName.Replace((Split-Path $root -Parent) + '\', '')
               $bad.Add(("    {0}:{1}" -f $rel, ($i + 1)))
               $bad.Add(("        argument: {0}" -f $t))
               }
            }
         }
      }
   }

if ($bad.Count -gt 0)
   {
   Write-Host ''
   Write-Host 'Lint-FormatArgs FAILED: a raw pointer is being passed to Format.'
   $bad | ForEach-Object { Write-Host $_ }
   Write-Host ''
   Write-Host '  @x enters an array of const as vtPointer, and %s REFUSES vtPointer.'
   Write-Host '  FPC reports it as "Invalid argument index in format", in a modal'
   Write-Host '  dialog, in front of an operator, only when that message fires.'
   Write-Host ''
   Write-Host '  Pass the VALUE: a ShortString goes in as vtString and carries its'
   Write-Host '  own length. @Foo[1] is never the right answer.'
   exit 1
   }

Write-Host ("  Lint-FormatArgs: {0} file(s) checked, no raw pointer reaches a Format argument." -f $scanned)
exit 0
