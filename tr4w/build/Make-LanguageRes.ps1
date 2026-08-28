<#
.SYNOPSIS
   Compile the .po catalogues into one .res so the binary carries every language.

.DESCRIPTION
   THE DECISION THIS IMPLEMENTS. TR4W translates by REPLACING resourcestrings at
   run time from a .po, and a .po has to come from somewhere. Two places were
   possible: a file beside the exe, or a resource inside it. NY4I chose inside
   (2026-08-26), on the grounds that the language data is already embedded today
   via {$R res\tr4w_<lang>.res} and a loose file is one more thing to lose.

   Measured: 16 catalogues are ~1.0 MB trimmed, against a 5.6 MB binary. One
   6.6 MB exe speaks sixteen languages where today 5.6 MB speaks one and nine
   languages means nine builds.

   WHAT IS TRIMMED, AND WHY IT IS SAFE. The shipped copy drops `#.` translator
   notes and the `#:` SOURCE references that end in a line number -- comments no
   run time reads. It KEEPS the `#:` identifier line, because that is what
   LazUtils matches on, and it keeps `msgctxt`. Dropping either would silently
   translate nothing.

   FUZZY ENTRIES ARE DROPPED ENTIRELY. The run time already refuses them
   (translations.pas: "Load translation only if it exists and is NOT fuzzy"), so
   shipping them costs bytes to be ignored. It also means the resource contains
   only text a human has approved -- which is the same guarantee po2pas gives
   the Pascal side.

.NOTES
   Not called by FullBuild yet. Run it when a catalogue changes; the .res is
   committed so a fresh clone builds without needing LibreTranslate or python.
#>

param(
   [string] $Repo    = (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent),
   [string] $OutRes  = '',
   [switch] $Quiet
)

$ErrorActionPreference = 'Stop'

$i18n = Join-Path $Repo 'i18n'
$res  = if ($OutRes -ne '') { $OutRes } else { Join-Path $Repo 'tr4w\res\tr4w_languages.res' }
$work = Join-Path ([IO.Path]::GetTempPath()) ("tr4wlang_" + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $work | Out-Null

. (Join-Path $PSScriptRoot 'Find-Toolchain.ps1')
$tc = Find-Tr4wToolchain -Quiet
if (-not $tc) { exit 2 }

# fpcres, which Find-Toolchain already located -- deriving a second path to it
# would be a second answer to a question that has one.
#
# -of res IS NOT OPTIONAL. Without it fpcres targets COFF by default and rejects
# the .rc with "No known file format detected for file ...", which reads like a
# corrupt input rather than a wrong output format and cost a detour through
# windres -- whose own preprocessor needs a cc1 this FPC bundle does not ship.
$fpcres = $tc.FpcRes
if (-not $fpcres -or -not (Test-Path $fpcres)) { throw "fpcres.exe not found: '$fpcres'" }

function Write-TrimmedCatalogue
   {
   <# Keep msgctxt, msgid, msgstr and the IDENTIFIER #: line. Drop translator
      notes, the pas2po source references (they end in a line number, which is
      how they are told apart), obsolete entries and anything still fuzzy. #>
   param([string] $Source, [string] $Dest)

   $script:kept  = 0     # PER CALL. Module scope made it cumulative, so the
   $script:fuzzy = $false #  counts read 1431, 1452, 1453 ... across languages.
   $out  = New-Object System.Collections.Generic.List[string]
   $block = New-Object System.Collections.Generic.List[string]

   function Flush {
      if ($block.Count -eq 0) { return }
      if (-not $script:fuzzy) { $out.AddRange($block); $out.Add(''); $script:kept++ }
      $block.Clear()
      $script:fuzzy = $false
   }

   foreach ($line in [IO.File]::ReadLines($Source, [Text.Encoding]::UTF8))
      {
      if ($line -eq '') { Flush; continue }
      if ($line.StartsWith('#~')) { continue }                       # obsolete
      if ($line.StartsWith('#.')) { continue }                       # translator note
      if ($line.StartsWith('#,')) { if ($line -match 'fuzzy') { $script:fuzzy = $true }; continue }
      if ($line.StartsWith('#:'))
         {
         # a pas2po source reference ends in a line number; the identifier does not
         if ($line -match ':\d+\s*$') { continue }
         $block.Add($line); continue
         }
      if ($line.StartsWith('#')) { continue }
      $block.Add($line)
      }
   Flush

   [IO.File]::WriteAllLines($Dest, $out, (New-Object Text.UTF8Encoding($false)))
   return $script:kept
   }

$rcLines = New-Object System.Collections.Generic.List[string]
$total = 0

foreach ($po in (Get-ChildItem -Path $i18n -Filter 'tr4w_*.po' | Sort-Object Name))
   {
   $lang = $po.BaseName -replace '^tr4w_', ''
   $trim = Join-Path $work ("$lang.po")
   $kept = Write-TrimmedCatalogue -Source $po.FullName -Dest $trim
   $total += $kept

   # RCDATA named TR4W_<LANG> in upper case -- the runtime asks for exactly that.
   # Forward slashes in the path: the resource compiler treats a backslash as an
   # escape, which is the same corruption Lint-PathEscapes exists to catch.
   $rcLines.Add(("TR4W_{0} RCDATA ""{1}""" -f $lang.ToUpper(), ($trim -replace '\\', '/')))

   # AND THE LCL OWN CATALOGUE FOR THE SAME LANGUAGE.
   #
   # Lazarus ships lclstrconsts.<lang>.po -- standard buttons, common dialogs,
   # RTL error text -- already translated by its own translators.
   # SetDefaultLang loaded it automatically; LoadEmbeddedTranslation replaced
   # SetDefaultLang and did not, so every LCL-supplied string has been showing
   # in English in every language. Found 2026-08-27, chasing why our own &Yes
   # was translated worse than the one Lazarus already ships.
   #
   # Embedded UNTRIMMED: these are finished upstream translations, not our
   # machine-seeded entries, so there are no fuzzy flags of ours to drop.
   $lcl = Join-Path $tc.LazDir ("lcl\languages\lclstrconsts.$lang.po")
   if (Test-Path $lcl)
      {
      $lclCopy = Join-Path $work ("lcl_$lang.po")
      Copy-Item $lcl $lclCopy -Force
      $rcLines.Add(("LCL_{0} RCDATA ""{1}""" -f $lang.ToUpper(), ($lclCopy -replace '\\', '/')))
      }
   if (-not $Quiet)
      {
      $kb = [math]::Round((Get-Item $trim).Length / 1KB)
      Write-Host ("  {0,-6} {1,5} reviewed entr{2}  {3,4} KB" -f $lang, $kept, $(if ($kept -eq 1) { 'y' } else { 'ies' }), $kb)
      }
   }

$rc = Join-Path $work 'tr4w_languages.rc'
[IO.File]::WriteAllLines($rc, $rcLines, (New-Object Text.UTF8Encoding($false)))

New-Item -ItemType Directory -Force -Path (Split-Path $res -Parent) | Out-Null
& $fpcres -of res -o $res $rc 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0 -or -not (Test-Path $res)) { throw "fpcres failed on $rc" }

Remove-Item -Recurse -Force $work -ErrorAction SilentlyContinue

$size = [math]::Round((Get-Item $res).Length / 1KB)
$ours = ($rcLines | Where-Object { $_ -like "TR4W_*" }).Count
$lcls = ($rcLines | Where-Object { $_ -like "LCL_*" }).Count
Write-Host ("Make-LanguageRes: {0} reviewed entries across {1} language(s) -> {2} ({3} KB)" -f `
   $total, $ours, (Split-Path $res -Leaf), $size)
Write-Host ("  plus {0} Lazarus catalogue(s), so the LCL own strings translate too" -f $lcls)
