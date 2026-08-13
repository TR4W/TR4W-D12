# Inserts {$I tr4w.inc} immediately after a unit's `unit X;` line.
#
# The include path is computed from where the unit sits relative to src, so
# trdos\ and utils\ and radioFactory\ units get ..\tr4w.inc and src\ units get
# tr4w.inc.  Delphi resolves an include relative to the FILE doing the
# including, not to a search path, so this has to be right per directory.
#
# Idempotent: a unit that already has the include is left alone and reported.
#
#   .\add-prelude.ps1 uTotal.pas
#   .\add-prelude.ps1 trdos\LOGSTUFF.PAS utils\uWinTimer.pas

param(
   [Parameter(Mandatory = $true, ValueFromRemainingArguments = $true)]
   [string[]] $Units,
   [string] $Repo = 'C:\tr4w-d12'
)

$src = Join-Path $Repo 'tr4w\src'

foreach ($u in $Units)
   {
   $path = if ([IO.Path]::IsPathRooted($u)) { $u } else { Join-Path $src $u }

   if (-not (Test-Path $path))
      {
      Write-Host "MISSING  $u"
      continue
      }

   $text = [IO.File]::ReadAllText($path)

   if ($text -match '(?im)^\s*\{\$I\s+[^}]*tr4w\.inc\}')
      {
      Write-Host "already  $u"
      continue
      }

   # Depth below src decides the relative path back to src\tr4w.inc.
   $dir = Split-Path $path -Parent
   $rel = $dir.Substring($src.Length).Trim('\')
   $depth = if ($rel -eq '') { 0 } else { ($rel -split '\\').Count }
   $incPath = if ($depth -eq 0) { 'tr4w.inc' } else { (('..\' * $depth) + 'tr4w.inc') }

   # Match the unit's OWN declaration, not the word 'unit' in a banner comment.
   $m = [regex]::Match($text, '(?im)^\s*unit\s+[A-Za-z_][A-Za-z0-9_]*\s*;')
   if (-not $m.Success)
      {
      Write-Host "NO UNIT LINE  $u"
      continue
      }

   $insertAt = $m.Index + $m.Length
   $text = $text.Substring(0, $insertAt) + "`r`n{`$I $incPath}" + $text.Substring($insertAt)
   [IO.File]::WriteAllText($path, $text)
   Write-Host ("OK       {0}  <- {{`$I {1}}}" -f $u, $incPath)
   }
