<#
.SYNOPSIS
   Fail the build if a config spelling table contains a duplicate or blank
   entry, so that one of its enum values becomes unreachable by name.

.DESCRIPTION
   WHAT A SPELLING TABLE IS. Every enumerated setting in tr4w.ini and in a
   contest .cfg is written as TEXT -- 'SERIAL 7', 'ARRL DX', 'TCP/IP'. uCFG's
   ListParamArray pairs each such setting with a hand-written array of those
   spellings, indexed by the enum, and TF.GetValueFromArray walks it looking for
   the operator's word. There are 54 of those pairings over 40 distinct tables.

   WHAT GOES WRONG. GetValueFromArray returns THE FIRST MATCH. So if two entries
   in one table carry the same word, the second enum value cannot be selected
   from a config file at all -- and the first one is chosen in its place. There
   is no error, no warning, and no compiler diagnostic: the table is declared
   `array[SomeEnum] of PAnsiChar`, so its LENGTH is enforced and its CONTENTS
   are not.

   THIS IS NOT HYPOTHETICAL. It is the same failure the radio tables had, which
   Lint-NoRadioTables exists for: a name table one row out of step meant a config
   saying TS440 got the TS-140 driver, for four Kenwoods, for years, silently.
   A duplicate spelling is that bug with a shorter reach and the same shape.

   A BLANK ENTRY IS THE SAME DEFECT WEARING A DIFFERENT HAT. An empty spelling
   matches an empty command value, so a malformed line in a config file selects
   whichever enum value happens to carry it.

   WHAT IS NOT CHECKED, and cannot be. That each spelling means what its ordinal
   means. Nothing in the tree can answer that: it is the second definition
   problem, and the real fix is for the table to be GENERATED from the enum
   rather than typed beside it. uRadioRegistry.RadioTypeTokensA already is --
   which is why this lint reports it as generated rather than treating it as a
   gap. See docs\CFG_ARRAY_ELIMINATION.md.

   THE COMPARISON IS CASE-INSENSITIVE, because GetValueFromArray's is. It folds
   case with StrIComp, and has since the SINGLE BAND SCORE incident of
   2026-08-16, so 'All' and 'ALL' in one table are a duplicate here too.

.EXAMPLE
   .\Lint-SpellingTables.ps1
   .\Lint-SpellingTables.ps1 -SourceDir ..\src
#>

param(
   [string] $SourceDir = (Join-Path (Split-Path $PSScriptRoot -Parent) 'src'),
   [switch] $Quiet
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Get-ScanExclusions.ps1')   # Test-Tr4wScannable

# ---------------------------------------------------------------------------
# ACCEPTED, WITH A REASON EACH. A baseline, not an exemption list: a NEW
# duplicate fails even in a table named here.
# ---------------------------------------------------------------------------
$known = @{
   # Two entries spell 'ONY', at ordinals 29 and 85. The second is commented
   # OldNewYearQSOPointMethod and is the one unreachable by name; the first
   # carries no provenance comment at all, which is the only reason to suspect
   # it is the mistake. ALREADY DOCUMENTED at TF.pas, in the note explaining
   # that folding case created no NEW ambiguity.
   #
   # NOT FIXED HERE ON PURPOSE. Which ordinal 'ONY' should select decides which
   # scoring rule a contest runs under, the golden corpus is blind to scoring,
   # and this is NY4I's call.
   'QSOPointMethodArray' = @('ONY')
}

# A table that no longer has a literal list is not a gap. RadioTypeTokensA is a
# `var` the registry FILLS from the enum -- the shape this whole class of defect
# is supposed to end up as -- so there is nothing here to check and its absence
# is the good outcome.
#
# LanguageVocabulary (uEmbeddedTranslations, 2026-09-19) is the same shape: a
# function that builds the display language's values from the RCDATA names of
# the catalogues the binary carries. Its leading '' is "System default" on a
# STRING setting -- a value, not a spelling that selects an enum ordinal.
$generated = @('RadioTypeTokensA', 'LanguageVocabulary')

# The floor. A lint that resolves nothing and reports success is worse than no
# lint, and this one reaches its subjects through two layers of parsing, so it
# states how many it MUST find.
# LOWERED 36 -> 31 on 2026-09-14, WITH THE FIVE TABLES ACCOUNTED FOR ONE BY
# ONE. A floor that is lowered because a number did not come out is not a
# floor, so each of the five that left the subject set is named:
#
#   MP3RecorderDurationSA           deleted -- the recorder went 2026-09-07;
#                                   this only existed to keep a withdrawn row
#                                   structurally valid.
#   CallWindowPositionTypeSA        deleted -- CALL WINDOW POSITION is a
#   FootSwitchModeTypeStringArray   deleted -- FOOT SWITCH MODE is a
#                                   withdrawn command (RETIRED_COMMANDS), and
#                                   nothing but the parser ever read either.
#   tCertificateSA                  deleted -- the Cabrillo summary dialog
#                                   edits Certificate directly; the spellings
#                                   had no reader.
#   PortTypeSA                      KEPT, but it is not a config vocabulary
#                                   any more: SERIAL n is abandoned and a port
#                                   is its OS name. Its one remaining reader
#                                   formats a log line.
#
# All five were reached ONLY through ListParamArray, which went with the last
# CFGCA row. The 31 that remain are registered vocabularies, and that is the
# shape this lint was always aiming at.
$minimumTables = 31

# ---------------------------------------------------------------------------
# The literals of a Pascal initialiser, AND NOTHING FROM A COMMENT.
#
# A regex over the whole declaration is wrong, and it was wrong here first: the
# fixture proving this lint had teeth carried the word it duplicated inside its
# own explanatory comment, and the lint counted it as a table entry.  A linter
# that reads commented text reports work that does not exist, and gets ignored.
#
# So this walks the text with three states -- in a string, in a comment, in
# neither -- rather than pattern-matching it.  '' inside a string is an escaped
# quote and does not end it.
# ---------------------------------------------------------------------------
function Get-PascalLiterals([string] $Body)
   {
   $out = @()
   $i = 0
   $n = $Body.Length

   while ($i -lt $n)
      {
      $ch = $Body[$i]

      if ($ch -eq "'")
         {
         $sb = New-Object System.Text.StringBuilder
         $i++
         while ($i -lt $n)
            {
            if ($Body[$i] -eq "'")
               {
               if ((($i + 1) -lt $n) -and ($Body[$i + 1] -eq "'"))
                  {
                  [void] $sb.Append("'")
                  $i += 2
                  continue
                  }
               $i++
               break
               }
            [void] $sb.Append($Body[$i])
            $i++
            }
         $out += $sb.ToString()
         continue
         }

      if (($ch -eq '/') -and (($i + 1) -lt $n) -and ($Body[$i + 1] -eq '/'))
         {
         while (($i -lt $n) -and ($Body[$i] -ne "`n")) { $i++ }
         continue
         }

      if ($ch -eq '{')
         {
         while (($i -lt $n) -and ($Body[$i] -ne '}')) { $i++ }
         $i++
         continue
         }

      if (($ch -eq '(') -and (($i + 1) -lt $n) -and ($Body[$i + 1] -eq '*'))
         {
         $i += 2
         while (($i + 1) -lt $n)
            {
            if (($Body[$i] -eq '*') -and ($Body[$i + 1] -eq ')')) { $i += 2; break }
            $i++
            }
         continue
         }

      $i++
      }

   return $out
   }

$cfgPath = Join-Path $SourceDir 'uCFG.pas'
if (-not (Test-Path -LiteralPath $cfgPath))
   {
   Write-Host "Lint-SpellingTables: uCFG.pas not found under $SourceDir -- that is a failure, not a pass."
   exit 1
   }

# --- ListParamArray IS GONE, 2026-09-14, and so is the pass that read it ---
#
# This lint began by walking `lpArray: @NAME` entries in uCFG's ListParamArray,
# because that table was where a setting's spellings were reached from. The
# last CFGCA row left on 2026-09-14 and the table went with it.
#
# NOTHING IS LOST, and the transition was visible while it happened: a table
# whose row moved stopped being pointed at by ListParamArray and started being
# pointed at by a RegisterSettingAllowedValues call, which the pass below
# already followed. The FLOOR is what kept that honest -- six tables lost their
# guard in silence on 2026-09-13 and the floor is what reported it.
$wanted = New-Object 'System.Collections.Generic.HashSet[string]'

# --- find each declaration and read its literals ---------------------------
$findings = @()
$resolved = 0
$missing  = @()
$entries  = 0

$sources = @(Get-ChildItem -Path $SourceDir -Recurse -Include *.pas,*.inc |
             Where-Object { Test-Tr4wScannable $_.FullName })

$text = @{}
foreach ($f in $sources)
   {
   $text[$f.FullName] = (Get-Content -LiteralPath $f.FullName -Raw)
   }

# --- and the tables that have LEFT ListParamArray ---------------------------
#
# A setting's spelling table now lives with its type, and is registered by name:
#
#    RegisterSettingAllowedValues('MainWindow.RateDisplay', RATE_DISPLAY_SPELLINGS);
#
# THE GUARD HAS TO FOLLOW IT. A duplicate or blank spelling makes an enum value
# unreachable by name wherever the table lives, and five tables left in one
# session -- which showed up here only as the FLOOR failing, because a table
# nothing points at is a table this lint stops checking.
#
# ANYWHERE, NOT JUST uSettingsModel. A SUBSYSTEM publishes its own vocabulary:
# uExternalLoggerFactory registers ExternalLoggerTypeSA, because the logger owns
# its taxonomy and the settings model does not. Scanning one file missed it, and
# four spellings lost their guard silently.
#
# A BARE IDENTIFIER, OR ONE WRAPPED IN PAnsiCharVocabulary.
#
# IntegerVocabulary(SCP_MINIMUM_LETTERS_ARRAY) is deliberately NOT followed: an
# allow-list of numbers has no spellings to check for duplicates or blanks.
#
# PAnsiCharVocabulary was followed here for a few hours on 2026-09-13, while
# the Cabrillo category tables were still PAnsiChar. They are string arrays now
# and register as bare identifiers again, so the wrapper is only still matched
# in case another one appears.
#
# IT WAS FOUND BY THE FLOOR, which is what the floor is for. Those six tables
# used to be reached through `lpArray: @NAME` in ListParamArray; their rows left
# CFGCA on 2026-09-13 and the slots were nil'd, so the only remaining pointer at
# them was a registration this regex did not match -- and six tables lost their
# duplicate/blank guard in silence.
foreach ($p in $text.Keys)
   {
   foreach ($m in [regex]::Matches($text[$p],
      "RegisterSettingAllowedValues\s*\(\s*'[^']*'\s*,\s*(?:PAnsiCharVocabulary\s*\(\s*)?(\w+)\s*\)"))
      {
      [void] $wanted.Add($m.Groups[1].Value)
      }
   }

foreach ($name in @($wanted | Sort-Object))
   {
   if ($generated -contains $name) { continue }

   $body = $null
   foreach ($p in $text.Keys)
      {
      # `of PAnsiChar {string} =` occurs, so anything between the element type
      # and the '=' is skipped rather than assumed absent.
      $rx = '\b' + [regex]::Escape($name) +
            '\s*:\s*array\s*\[[^\]]*\]\s*of\s*(?:PAnsiChar|PChar|string|ShortString)\b[^=]*=\s*\((?<body>.*?)\)\s*;'
      $m = [regex]::Match($text[$p], $rx, 'Singleline, IgnoreCase')
      if ($m.Success) { $body = $m.Groups['body'].Value; break }
      }

   if ($null -eq $body) { $missing += $name; continue }

   $resolved++
   $lits = @(Get-PascalLiterals $body)
   $entries += $lits.Count

   $seen = @{}
   $index = -1
   foreach ($s in $lits)
      {
      $index++
      $key = $s.Trim().ToUpperInvariant()

      if ($key -eq '')
         {
         $findings += "$name ordinal $index is BLANK -- an empty config value would select it"
         continue
         }

      if ($seen.ContainsKey($key))
         {
         $allowed = $known.ContainsKey($name) -and ($known[$name] -contains $s.Trim())
         if (-not $allowed)
            {
            $findings += ("{0} ordinal {1} repeats '{2}' from ordinal {3} -- ordinal {1} cannot be selected by name" -f
                          $name, $index, $s.Trim(), $seen[$key])
            }
         continue
         }
      $seen[$key] = $index
      }
   }

if ($Quiet) { if ($findings.Count -gt 0) { exit 1 } else { exit 0 } }

if ($missing.Count -gt 0)
   {
   Write-Host 'Lint-SpellingTables: ListParamArray names a table with no declaration this lint can read:'
   foreach ($n in $missing) { Write-Host "      $n" }
   Write-Host '   Either the declaration moved, or its shape changed. Both need a human, not a pass.'
   exit 1
   }

if ($resolved -lt $minimumTables)
   {
   Write-Host ("Lint-SpellingTables: resolved only {0} table(s), floor is {1} -- the parse is failing quietly." -f
               $resolved, $minimumTables)
   exit 1
   }

if ($findings.Count -eq 0)
   {
   Write-Host ("Lint-SpellingTables: {0} table(s), {1} spelling(s) checked, every enum value reachable by name." -f
               $resolved, $entries)
   exit 0
   }

foreach ($x in $findings) { Write-Host "   $x" }
Write-Host ''
Write-Host 'Lint-SpellingTables: a duplicate or blank spelling makes an enum value unreachable'
Write-Host '   from a config file, and GetValueFromArray takes the FIRST match instead. There is'
Write-Host '   no compiler diagnostic for this: the array is bounded by the enum, so its LENGTH'
Write-Host '   is enforced and its CONTENTS are not.'
exit 1
