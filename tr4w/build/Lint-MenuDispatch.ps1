# Every menu row must have a handler.
#
# WHY, and why BEFORE the TMainMenu migration (docs\MENU_ACTIONLIST_PLAN.md,
# Phase 0): the menu is 180 numeric ids wired to a 920-line `case menuID of`,
# and NOTHING checks that the two agree. A row whose id has no handler is a
# menu item the operator can click that does nothing -- silently, no error, no
# log line. The compiler cannot see it; neither can a human reading either file
# alone.
#
# Run it BEFORE the migration starts. Anything it reports now is a defect that
# exists TODAY; found after the move, the same finding would look like
# conversion damage and cost a bisect.
#
# IT HAS TO UNDERSTAND THREE DISPATCH SHAPES, and the first draft understood
# only one and called 40 correctly-handled rows dead:
#
#   menu_options:                                            a plain label
#   menu_a, menu_b:                                          comma-separated
#   menu_alt_increment_time_1..menu_alt_increment_time_0:    a SUBRANGE
#
# plus a RANGE GUARD ahead of the case -- `if LowordWparam >= menu_windows_bandmap
# then if LowordWparam <= menu_windows_hamscore then` -- which hands the whole
# tw_ window block to OpenTR4WWindow by arithmetic, 25 rows with no label
# between them. That guard is the same `10199 + Ord(ID)` coupling Phase 2
# removes; when it goes, this arm of the lint goes with it.
#
# Ranges are why ids are resolved to NUMBERS from VC.pas rather than by name.
#
# A lint that cries wolf gets switched off, so the failing condition is narrow:
# a menu row whose id no label, range or guard covers.
#
# Source-level and deterministic -- no running program, so it can gate a build.
# Pair it with test\ui\Dump-Menu.ps1, which reads the LIVE menu and therefore
# also sees what runtime EnableMenuItem / DeleteMenu / ModifyMenu calls did.
#
# ---------------------------------------------------------------------------
# SECOND CHECK, ADDED 2026-09-08: A CAPTION PER ROW, AND NO MORE.
#
# The captions cannot live in the array -- they are resourcestrings, and a
# resourcestring cannot appear in a typed constant -- so InitializeMenuText
# assigns them BY POSITION into a second, parallel sequence:
#
#     Inc(i); T_MENU_ARRAY[i].mrText := RC_STATIONS;
#
# Nothing ties the two together. Delete a row and leave its caption behind and
# every caption after it lands on the row before its own, silently: the menu
# still opens, every item still works, and every label is wrong. The last
# assignment then writes one element PAST the end of the array, with range
# checking off.
#
# THIS IS NOT HYPOTHETICAL AND IT IS NOT RARE. Three times now:
#
#   2026-08-28  Check for Updates came off the menu -- About then read
#               "Check for Updates". Fixed by hand, with a comment asking the
#               next author to remember.
#   2026-09-07  Help -> Contents went with the CHM help ({$IFDEF LANG_RUS});
#               two captions stayed. Invisible -- no build here compiles that
#               arm -- and it left T_MENU_ARRAY_SIZE counting three added rows
#               against one, so no Russian build could have compiled at all.
#   2026-09-07  The MP3 recorder was deleted; RC_MP3REC stayed. NY4I saw the
#               menu bar read "File Settings Windows MMTTY - Band Rescore -
#               Clear multsheet in all logs" the next day.
#
# The comment failed twice, so this counts instead -- separately for the base
# build and for the LANG_RUS arm, which is the one no compiler here ever sees.

param(
   # tr4w\src, the way every other lint is invoked by Run-Lints.ps1.  The repo
   # root is derived from it rather than passed separately, so there is one
   # argument to keep right instead of two.
   [string] $SourceDir = (Join-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) 'tr4w\src')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Comments blanked, DIRECTIVES KEPT -- which is what makes the {$IFDEF LANG_RUS}
# arm countable, and what stops the {$IFDEF LANG_RUS} written inside a prose
# comment in uMenu.pas from being read as a real one. A hand-rolled parser
# without this got exactly that wrong while the defect above was diagnosed.
Import-Module (Join-Path $PSScriptRoot 'PascalSource.psm1') -Force

$menuPas = Join-Path $SourceDir 'uMenu.pas'
$mainPas = Join-Path $SourceDir 'MainUnit.pas'
$vcPas   = Join-Path $SourceDir 'VC.pas'

foreach ($f in @($menuPas, $mainPas, $vcPas))
   {
   if (-not (Test-Path -LiteralPath $f))
      {
      Write-Output "Lint-MenuDispatch: cannot find $f"
      exit 1
      }
   }

# ------------------------------------------------------------- the values ---
# menu_* -> its number, from VC.pas (`menu_exit = 10002;`).
$value = @{}
foreach ($m in [regex]::Matches((Get-Content -LiteralPath $vcPas -Raw),
                                '(?im)^\s*(menu_[A-Za-z0-9_]+)\s*=\s*(\d+)\s*;'))
   {
   $value[$m.Groups[1].Value] = [int]$m.Groups[2].Value
   }
if ($value.Count -eq 0)
   {
   Write-Output 'Lint-MenuDispatch: parsed NO menu_* constants from VC.pas -- the parser is broken, not the code'
   exit 1
   }

# --------------------------------------------------------------- the rows ---
# `(mrText: RC_EXIT; mrId: menu_exit),`. MAXWORD / MAXWORD-1 / MAXWORD-2 are the
# popup structure sentinels and 0 is a separator; none is a command.
$rowIds = @{}
foreach ($m in [regex]::Matches((Get-Content -LiteralPath $menuPas -Raw),
                                '(?im)^\s*\(mrText:.*?;\s*mrId:\s*(menu_[A-Za-z0-9_]+)\s*\)'))
   {
   $rowIds[$m.Groups[1].Value] = $true
   }
if ($rowIds.Count -eq 0)
   {
   Write-Output 'Lint-MenuDispatch: parsed NO menu rows from uMenu.pas -- the parser is broken, not the code'
   exit 1
   }

# --------------------------------------------------------------- the arms ---
# Scoped to ProcessMenu's body, so the hundreds of other menu_* references in
# MainUnit (EnableMenuItem calls, the toolbar dispatch) are not counted.
$mainLines = Get-Content -LiteralPath $mainPas
$handled   = @{}     # id NUMBER -> $true
$armCount  = 0
$inProc    = $false

function Add-IdRange
{
   param([hashtable] $Set, [int] $A, [int] $B)
   # The constant table is not sorted by value, so do not assume A < B.
   $lo = [Math]::Min($A, $B)
   $hi = [Math]::Max($A, $B)
   for ($v = $lo; $v -le $hi; $v++) { $Set[$v] = $true }
}

for ($i = 0; $i -lt $mainLines.Count; $i++)
   {
   $line = $mainLines[$i]

   if (-not $inProc)
      {
      if ($line -match '^procedure ProcessMenu\(menuID: integer\);\s*$')
         {
         # The BODY, not the forward declaration: the body is followed by
         # var or begin. Look ahead rather than guessing.
         for ($j = $i + 1; $j -lt [Math]::Min($i + 6, $mainLines.Count); $j++)
            {
            if ($mainLines[$j] -match '^\s*(var|begin)\s*$')        { $inProc = $true; break }
            if ($mainLines[$j] -match '^\s*(procedure|function)\s') { break }
            }
         }
      continue
      }

   if ($line -match '^end;\s*$') { break }

   # The range guard ahead of the case -- see the header.
   if ($line -match '>=\s*(menu_[A-Za-z0-9_]+)')
      {
      $lo = $Matches[1]
      for ($j = $i; $j -lt [Math]::Min($i + 3, $mainLines.Count); $j++)
         {
         if ($mainLines[$j] -match '<=\s*(menu_[A-Za-z0-9_]+)')
            {
            $hi = $Matches[1]
            if ($value.ContainsKey($lo) -and $value.ContainsKey($hi))
               {
               Add-IdRange -Set $handled -A $value[$lo] -B $value[$hi]
               $armCount++
               }
            break
            }
         }
      continue
      }

   # A case label: single, comma-separated, or a subrange with '..'.
   if ($line -match '^\s*((?:menu_[A-Za-z0-9_]+\s*(?:\.\.\s*menu_[A-Za-z0-9_]+\s*)?,\s*)*menu_[A-Za-z0-9_]+\s*(?:\.\.\s*menu_[A-Za-z0-9_]+)?)\s*:(?!=)')
      {
      foreach ($part in ($Matches[1] -split ',\s*'))
         {
         $part = $part.Trim()
         if ($part -match '^(menu_[A-Za-z0-9_]+)\s*\.\.\s*(menu_[A-Za-z0-9_]+)$')
            {
            if ($value.ContainsKey($Matches[1]) -and $value.ContainsKey($Matches[2]))
               {
               Add-IdRange -Set $handled -A $value[$Matches[1]] -B $value[$Matches[2]]
               $armCount++
               }
            }
         elseif ($value.ContainsKey($part))
            {
            $handled[$value[$part]] = $true
            $armCount++
            }
         }
      }
   }

if ($armCount -eq 0)
   {
   # Fail loudly rather than pass vacuously: a lint that silently matched
   # nothing reports "no defects" for ever.
   Write-Output 'Lint-MenuDispatch: found NO handlers in ProcessMenu -- the parser is broken, not the code'
   exit 1
   }

# -------------------------------------------------------------- the checks ---
$undeclared = @($rowIds.Keys | Where-Object { -not $value.ContainsKey($_) } | Sort-Object)
$dead       = @($rowIds.Keys |
                Where-Object { $value.ContainsKey($_) -and (-not $handled.ContainsKey($value[$_])) } |
                Sort-Object)

if ($undeclared.Count -gt 0)
   {
   Write-Output ("Lint-MenuDispatch: {0} menu row(s) name an id VC.pas does not declare:" -f $undeclared.Count)
   foreach ($id in $undeclared) { Write-Output "    $id" }
   exit 1
   }

if ($dead.Count -gt 0)
   {
   Write-Output ("Lint-MenuDispatch: {0} menu row(s) have NO handler -- clicking them does nothing:" -f $dead.Count)
   foreach ($id in $dead) { Write-Output ("    {0}  (id {1})" -f $id, $value[$id]) }
   exit 1
   }

# --------------------------------------------------- rows vs captions -------
# Counted per conditional arm: index 0 is the code every build compiles, index
# 1 is that plus the {$IFDEF LANG_RUS} rows. Both must balance.
$codeLines = Get-PascalCodeOnlyLines -Path $menuPas

$rusDepth = 0        # >0 while inside {$IFDEF LANG_RUS}
$inArray  = ''       # 'T' or 'E' while inside an array literal, else ''
$inInit   = $false   # inside InitializeMenuText

$rows    = @{ 'T' = @(0, 0); 'E' = @(0, 0) }
$caption = @{ 'T' = @(0, 0); 'E' = @(0, 0) }

function Add-Count
{
   param([hashtable] $Set, [string] $Which, [int] $RusDepth)
   # Outside the guard a row counts in BOTH arms; inside it, only in LANG_RUS.
   if ($RusDepth -eq 0) { $Set[$Which][0]++ }
   $Set[$Which][1]++
}

foreach ($line in $codeLines)
   {
   # COUNTED, NOT MATCHED ONCE PER LINE, because T_MENU_ARRAY_SIZE opens and
   # closes the guard on ONE line -- `176 + 1 {$IFDEF LANG_RUS} + 1{$ENDIF} + 2
   # ...`. Treating that line as an open left the guard stuck on for the rest
   # of the file and the base-build count came out zero. (Caught by the floor
   # below, which is the argument for having one.)
   $opens  = ([regex]::Matches($line, '\{\$IFDEF\s+LANG_RUS\s*\}')).Count
   $closes = ([regex]::Matches($line, '\{\$(ENDIF|IFEND)')).Count
   if ($opens -gt 0 -or $closes -gt 0)
      {
      # A directive line carries no row and no caption, so nothing is lost by
      # settling the depth and moving on. Only decrement into a guard that is
      # actually open: an {$ENDIF} closing some other conditional must not
      # cancel this one.
      $rusDepth += $opens
      $rusDepth -= [Math]::Min($closes, $rusDepth)
      continue
      }

   if ($line -match '^\s*(T|E)_MENU_ARRAY\s*:\s*array')
      {
      $inArray = $Matches[1]
      continue
      }
   if ($inArray -ne '' -and $line -match '^\s*\)\s*;')
      {
      $inArray = ''
      continue
      }

   if ($line -match '^procedure\s+InitializeMenuText') { $inInit = $true }
   if ($inInit -and $line -match '^end;')              { $inInit = $false }

   if ($inArray -ne '' -and $line -match '(?i)mrText\s*:.*;\s*mrId\s*:')
      {
      Add-Count -Set $rows -Which $inArray -RusDepth $rusDepth
      continue
      }

   if ($inInit -and $line -match '(?i)Inc\(i\);\s*(T|E)_MENU_ARRAY\[i\]\.mrText\s*:=')
      {
      Add-Count -Set $caption -Which $Matches[1] -RusDepth $rusDepth
      }
   }

# Fail loudly rather than pass vacuously -- the floor every lint here has.
if ($rows['T'][0] -lt 100 -or $caption['T'][0] -lt 100)
   {
   Write-Output ("Lint-MenuDispatch: parsed {0} row(s) and {1} caption(s) from uMenu.pas -- the parser is broken, not the code" -f
                 $rows['T'][0], $caption['T'][0])
   exit 1
   }

$armName    = @('the base build', 'the LANG_RUS build')
$mismatched = @()
foreach ($which in @('T', 'E'))
   {
   for ($arm = 0; $arm -lt 2; $arm++)
      {
      if ($rows[$which][$arm] -ne $caption[$which][$arm])
         {
         $mismatched += ("    {0}_MENU_ARRAY, {1}: {2} row(s) but {3} caption assignment(s)" -f
                         $which, $armName[$arm], $rows[$which][$arm], $caption[$which][$arm])
         }
      }
   }

if ($mismatched.Count -gt 0)
   {
   Write-Output 'Lint-MenuDispatch: the menu rows and their captions have drifted apart.'
   Write-Output '  InitializeMenuText assigns captions BY POSITION, so one spare or missing'
   Write-Output '  assignment shifts every caption after it onto the wrong row -- and the'
   Write-Output '  last one then writes past the end of the array.'
   foreach ($m in $mismatched) { Write-Output $m }
   exit 1
   }

Write-Output ("  Lint-MenuDispatch: {0} menu row(s), {1} handler(s), {2} id(s) reachable -- every row is handled." -f
              $rowIds.Count, $armCount, $handled.Count)
Write-Output ("  Lint-MenuDispatch: {0}+{1} row(s) carry {2}+{3} caption(s) -- one each, both arms." -f
              $rows['T'][0], $rows['E'][0], $caption['T'][0], $caption['E'][0])
exit 0
