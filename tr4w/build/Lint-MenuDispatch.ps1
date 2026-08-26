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

param(
   # tr4w\src, the way every other lint is invoked by Run-Lints.ps1.  The repo
   # root is derived from it rather than passed separately, so there is one
   # argument to keep right instead of two.
   [string] $SourceDir = (Join-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) 'tr4w\src')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

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

Write-Output ("  Lint-MenuDispatch: {0} menu row(s), {1} handler(s), {2} id(s) reachable -- every row is handled." -f
              $rowIds.Count, $armCount, $handled.Count)
exit 0
