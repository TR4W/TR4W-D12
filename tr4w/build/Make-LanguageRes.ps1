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

   FUZZY ENTRIES SHIP, AND THAT IS A DECISION, NOT AN OVERSIGHT (NY4I,
   2026-09-19 and again 2026-09-21): "languages are still being reviewed so we
   want to ship with what we have for now and use them fuzzy or not", and
   "Did you allow the program to use the fuzzy translations? We want to show
   the non-reviewed as well for testing."

   THERE ARE TWO GATES AND THIS ONE SCRIPT OPENS BOTH, because opening one
   alone changes nothing an operator can see:

     1. this script used to DROP a fuzzy entry outright, so the binary could
        not carry it; and
     2. LazUtils refuses a fuzzy entry at run time -- translations.pas:1223,
        "Load translation only if it exists and is NOT fuzzy" -- which is
        library code, not ours to edit.

   Both are cleared by EMITTING THE ENTRY WITHOUT ITS `#,` FLAG LINE. The
   trimmed copy carries the text; nothing downstream can tell it was fuzzy.

   THE `.po` FILES ARE NOT TOUCHED. The fuzzy marker is the record that a
   string is unreviewed and it belongs to the translator's workflow -- Poedit,
   po_merge and the Chinese salvage all depend on it (see CLAUDE.md on
   tr4w_zh_CN.po). Only the SHIPPED COPY loses the flag.

   HOW TO TURN IT BACK OFF when review finishes: run with -ReviewedOnly and
   commit the .res. That restores the pre-2026-09-21 behaviour exactly -- a
   binary carrying only human-approved text.

   A fuzzy entry with an EMPTY translation is still dropped either way: it
   carries no text, and shipping it would only add bytes.

.NOTES
   Not called by FullBuild yet. Run it when a catalogue changes; the .res is
   committed so a fresh clone builds without needing LibreTranslate or python.
#>

param(
   [string] $Repo    = (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent),
   [string] $OutRes  = '',
   # Ship only entries a human has reviewed -- the behaviour before
   # 2026-09-21. See the FUZZY note above for why the default is the other way.
   [switch] $ReviewedOnly,
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
      how they are told apart) and obsolete entries.

      The `#,` flag line is never emitted, which is what lets a fuzzy entry
      through the run-time gate -- see the FUZZY note in the file header.

      Returns a two-element array: reviewed entries kept, fuzzy entries kept. #>
   param([string] $Source, [string] $Dest, [bool] $IncludeFuzzy)

   $script:kept  = 0     # PER CALL. Module scope made it cumulative, so the
   $script:fuzzyKept = 0 #  counts read 1431, 1452, 1453 ... across languages.
   $script:fuzzy = $false
   $out  = New-Object System.Collections.Generic.List[string]
   $block = New-Object System.Collections.Generic.List[string]

   function Test-HasTranslation {
      <# Is this block's msgstr non-empty? The value may continue over several
         quoted lines, so the quoted parts from `msgstr` onward are joined. #>
      param($Lines)
      $seen = $false
      $text = ''
      foreach ($l in $Lines)
         {
         if ($l -match '^msgstr') { $seen = $true }
         elseif (-not $seen) { continue }
         elseif (-not $l.StartsWith('"')) { break }
         foreach ($m in [regex]::Matches($l, '"((?:[^"\\]|\\.)*)"')) { $text += $m.Groups[1].Value }
         }
      return ($text.Trim() -ne '')
   }

   function Flush {
      if ($block.Count -eq 0) { $script:fuzzy = $false; return }
      if (-not $script:fuzzy)
         {
         $out.AddRange($block); $out.Add(''); $script:kept++
         }
      elseif ($IncludeFuzzy -and (Test-HasTranslation $block))
         {
         # Emitted WITHOUT the flag line, which is the only way past
         # translations.pas:1223. The source .po keeps its marker.
         $out.AddRange($block); $out.Add(''); $script:fuzzyKept++
         }
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
   return @($script:kept, $script:fuzzyKept)
   }

$rcLines = New-Object System.Collections.Generic.List[string]
$total = 0
$totalFuzzy = 0

foreach ($po in (Get-ChildItem -Path $i18n -Filter 'tr4w_*.po' | Sort-Object Name))
   {
   $lang = $po.BaseName -replace '^tr4w_', ''
   $trim = Join-Path $work ("$lang.po")
   $counts = Write-TrimmedCatalogue -Source $po.FullName -Dest $trim `
                                    -IncludeFuzzy (-not $ReviewedOnly)
   $kept  = $counts[0]
   $fuzzy = $counts[1]
   $total += $kept
   $totalFuzzy += $fuzzy

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
      Write-Host ("  {0,-6} {1,5} reviewed + {2,5} unreviewed  {3,4} KB" -f $lang, $kept, $fuzzy, $kb)
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
Write-Host ("Make-LanguageRes: {0} reviewed + {1} unreviewed entries across {2} language(s) -> {3} ({4} KB)" -f `
   $total, $totalFuzzy, $ours, (Split-Path $res -Leaf), $size)
Write-Host ("  plus {0} Lazarus catalogue(s), so the LCL own strings translate too" -f $lcls)
if ($ReviewedOnly)
   {
   Write-Host "  -ReviewedOnly: fuzzy entries were dropped; the binary carries only approved text."
   }
else
   {
   Write-Host ("  UNREVIEWED TEXT SHIPS. {0} entries were fuzzy in the .po and are embedded" -f $totalFuzzy)
   Write-Host "  without the flag, which is what gets them past translations.pas:1223."
   Write-Host "  NY4I asked for this while the languages are under review; the .po files keep"
   Write-Host "  their markers, and -ReviewedOnly puts the gate back."
   }
