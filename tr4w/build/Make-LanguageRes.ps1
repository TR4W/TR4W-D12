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
   notes and the `#:` SOURCE references (path:line tokens) -- comments no run
   time reads. It KEEPS every identifier, because that is what LazUtils matches
   on, and it keeps `msgctxt`. Dropping either would silently translate nothing.

   Until 2026-10-16 it dropped a WHOLE `#:` line that ended in a line number,
   identifier and all, and passed several identifiers through in one entry,
   where LazUtils keeps only the last. See Write-TrimmedCatalogue for the shape
   it emits now and why.

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
   RUN BY THE BUILD (2026-10-16). Build-App.ps1 and Build-Tests.ps1 call
   Sync-Tr4wLanguageRes (LanguageResStamp.ps1), which regenerates the .res when
   the input hashes in tr4w_languages.res.inputs no longer match the tree. Until
   then NOTHING ran this script and two catalogue commits never reached a binary.
   Running it by hand is still fine (and is how to pick up a Lazarus upgrade,
   whose lclstrconsts catalogues are embedded but deliberately not hashed).

   This script writes the stamp beside its output ("<out>.inputs"). The .res is
   committed so a fresh clone builds without needing LibreTranslate or python,
   and the stamp is committed with it: the Linux and macOS builds cannot run
   this script, and check-language-res.sh fails them when the stamp is stale.
   Commit BOTH files together.

   The output is byte-identical for identical inputs (measured 2026-10-16).
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

. (Join-Path $PSScriptRoot 'LanguageResStamp.ps1')

$i18n =Join-Path $Repo 'i18n'
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

function Get-CandidateRank
   {
   <# Which of two entries claiming one key ships: one WITH a translation
      beats one without, then a REVIEWED one beats a fuzzy one. A tie keeps
      the first seen -- the pas2po entry, in source order, ahead of the
      copies po_merge appended later. #>
   param($Candidate)
   $rank = 0
   if ($Candidate.HasText)     { $rank += 2 }
   if (-not $Candidate.Fuzzy)  { $rank += 1 }
   return $rank
   }

function Write-TrimmedCatalogue
   {
   <# Keep msgctxt, msgid, msgstr and EVERY IDENTIFIER. Drop translator notes,
      the pas2po source references (path:line tokens) and obsolete entries.

      The `#,` flag line is never emitted, which is what lets a fuzzy entry
      through the run-time gate -- see the FUZZY note in the file header.

      ONE IDENTIFIER PER EMITTED ENTRY, AND ONE ENTRY PER IDENTIFIER, because
      that is the only shape LazUtils reads correctly (translations.pas,
      ReadPOText/FillItem, measured 2026-10-16):

        * every `#: ` line OVERWRITES the entry's identifier, so a block naming
          a form property AND a resourcestring kept only the last one;
        * a `#:` line is the identifier WHOLE, so a line that also carries a
          source reference (`#: utr4wstrings:tc_x tr4w/src/...pas:8`) is no
          usable key -- and this script used to drop such a line outright,
          leaving the entry with no key at all;
        * a later entry with the same identifier REPLACES the earlier one, so
          a stale fuzzy copy appended by a merge silently shadowed a reviewed
          translation: Polish showed "POLISH" for "Polski", and 202 Polish
          entries shipped codepage-damaged text over reviewed text.

      So each identifier token is collected separately, and the entry is
      emitted once per identifier under `#: <identifier>`. Where two entries
      claim one identifier, Get-CandidateRank picks the one that ships. The .po
      files are not changed; their twins are catalogue debt for po_dedupe.

      Returns: reviewed entries emitted, fuzzy entries emitted, and how many
      identifiers had a competing entry (shadowed). #>
   param([string] $Source, [string] $Dest, [bool] $IncludeFuzzy)

   $script:fuzzy = $false
   $script:shadowed = 0
   $out   = New-Object System.Collections.Generic.List[string]
   $block = New-Object System.Collections.Generic.List[string]   # the entry's msg lines
   $keys  = New-Object System.Collections.Generic.List[string]   # its identifiers
   # Output in order of first appearance: a keyed slot holds the winning entry
   # for its identifier; an entry with no identifier (the header) keeps its place.
   $slots  = New-Object System.Collections.Generic.List[object]
   $slotOf = New-Object 'System.Collections.Generic.Dictionary[string,int]'

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
      if ($block.Count -eq 0)
         {
         $keys.Clear(); $script:fuzzy = $false; return
         }
      $hasText = Test-HasTranslation $block
      # Unchanged rule: a reviewed entry ships; a fuzzy one ships when it has
      # text and fuzzy is wanted -- emitted WITHOUT the flag line, which is the
      # only way past translations.pas:1223. The source .po keeps its marker.
      $eligible = (-not $script:fuzzy) -or ($IncludeFuzzy -and $hasText)
      if ($eligible)
         {
         $body = $block.ToArray()
         if ($keys.Count -eq 0)
            {
            $slots.Add([pscustomobject]@{ Key = $null; Body = $body; Fuzzy = $script:fuzzy; HasText = $hasText })
            }
         foreach ($k in $keys)
            {
            $cand = [pscustomobject]@{ Key = $k; Body = $body; Fuzzy = $script:fuzzy; HasText = $hasText }
            if (-not $slotOf.ContainsKey($k))
               {
               $slotOf[$k] = $slots.Count
               $slots.Add($cand)
               }
            else
               {
               $script:shadowed++
               $at = $slotOf[$k]
               if ((Get-CandidateRank $cand) -gt (Get-CandidateRank $slots[$at]))
                  {
                  $slots[$at] = $cand
                  }
               }
            }
         }
      $block.Clear()
      $keys.Clear()
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
         # EVERY TOKEN, not the whole line: a line may hold an identifier and a
         # source reference together. A source reference is a path or ends in
         # a line number; anything else is an identifier. LazUtils turns ':'
         # into '.' and lower-cases, so the key is normalised the same way --
         # 'utr4wstrings:tc_x' and 'utr4wstrings.tc_x' are ONE key.
         foreach ($tok in ($line.Substring(2).Trim() -split '\s+'))
            {
            if (($tok -eq '') -or ($tok -match '[/\\]') -or ($tok -match ':\d+$')) { continue }
            $k = $tok.Replace(':', '.').ToLowerInvariant()
            if (-not $keys.Contains($k)) { $keys.Add($k) }
            }
         continue
         }
      if ($line.StartsWith('#')) { continue }
      $block.Add($line)
      }
   Flush

   $kept = 0
   $fuzzyKept = 0
   foreach ($s in $slots)
      {
      if ($null -ne $s.Key) { $out.Add('#: ' + $s.Key) }
      $out.AddRange([string[]] $s.Body)
      $out.Add('')
      if ($s.Fuzzy) { $fuzzyKept++ } else { $kept++ }
      }

   [IO.File]::WriteAllLines($Dest, $out, (New-Object Text.UTF8Encoding($false)))
   return @($kept, $fuzzyKept, $script:shadowed)
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
   $shadowed = $counts[2]
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
      # 'twins' = identifiers more than one .po entry claims; one ships, by
      # Get-CandidateRank. Reported so the catalogue debt stays visible.
      Write-Host ("  {0,-6} {1,5} reviewed + {2,5} unreviewed  {3,4} KB  {4,4} twins" -f $lang, $kept, $fuzzy, $kb, $shadowed)
      }
   }

$rc = Join-Path $work 'tr4w_languages.rc'
[IO.File]::WriteAllLines($rc, $rcLines, (New-Object Text.UTF8Encoding($false)))

New-Item -ItemType Directory -Force -Path (Split-Path $res -Parent) | Out-Null
& $fpcres -of res -o $res $rc 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0 -or -not (Test-Path $res)) { throw "fpcres failed on $rc" }

Remove-Item -Recurse -Force $work -ErrorAction SilentlyContinue

# The stamp is written LAST, so an interrupted run leaves a .res that does not
# match its stamp (or no stamp) and the next build regenerates it.
Remove-Item -Force "$res.inputs" -ErrorAction SilentlyContinue
$stampMode = if ($ReviewedOnly) { 'reviewed-only' } else { $script:LanguageResModeDefault }
Write-Tr4wLanguageStamp -Repo $Repo -ResPath $res -Mode $stampMode

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
