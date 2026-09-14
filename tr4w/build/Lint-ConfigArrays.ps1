# Lint-ConfigArrays.ps1 -- THE CONFIG ARRAY FAMILY IS A RATCHET NOW.
#
# WHY THIS EXISTS, and it is a question NY4I asked rather than a tidy-up.
#
# On 2026-09-11 he found `if FloppyFileSaveFrequency > 0 then` in logsubs2 and
# asked why a config value was still a raw global. The honest answer was: it is
# one of 303, nothing had moved it, AND NOTHING ANYWHERE WOULD HAVE TOLD HIM.
#
#   * Standing at the call site there is no signal. The declaration is a plain
#     `integer` in logstuff.pas and looks like any other global.
#   * The only thing that knows it is configuration is a row 300 lines into
#     uCFG that stores its ADDRESS.
#   * The build had no opinion at all. A row that has not migrated was not
#     reported, warned about, or counted anywhere an author would see it.
#
# So the only measure of progress was a number somebody chose to quote, which
# is exactly how a session that migrated 24 settings and retired 98 dead rows
# got described as "122 rows gone" and left him confused about what had
# actually moved.
#
# THIS PRINTS THE NUMBERS ON EVERY BUILD AND REFUSES TO LET THEM RISE.
#
# ------------------------------------------------------------------------
# WHAT IS COUNTED, AND WHY THESE FIVE
# ------------------------------------------------------------------------
#
# All five are the same mistake wearing different names: a const array holding
# the ADDRESS of a global, so that a table can write through it. That is the
# construction the settings work is removing, and it is why `Config` had to be
# a record -- @Config.Field resolves at link time and a property does not.
#
#   CFGCA                 the config commands. crAddress: @global
#   ArrayRecordArray      discrete allow-lists.  arVar: @global
#   ListParamArray        enum spelling lists.   lpVar: @global
#   CommandsProcArray     crP -- the redraw handlers
#   AdditionalProcsArray  crA -- the "additional proc" hooks
#
# THE LAST TWO ARE DIFFERENT IN KIND AND ARE COUNTED ANYWAY. They hold code
# addresses rather than data addresses, and they are what a property SETTER
# replaces: a crP is a hand-typed index into a 13-entry table, and a wrong one
# compiles. EXTERNAL LOGGER ENABLED carried crA: 23 -- the WSJT-X hook -- for
# exactly that reason. Every setting that moves to uSettingsModel takes its
# hook with it, so these fall as the others do.
#
# ------------------------------------------------------------------------
# COMMENTS DO NOT COUNT
# ------------------------------------------------------------------------
#
# uCFG is full of commented-out rows, and they are NOT the same set as the
# retired ones -- a distinction that has already produced a wrong answer here
# (K1EA NETWORK ENABLE is commented out, so it was never accepted, unlike a
# csRem row which was). PascalSource.psm1 strips comments and string literals
# in one regex pass; this uses it rather than inventing a counting method.
#
# ------------------------------------------------------------------------
# IT FAILS CLOSED
# ------------------------------------------------------------------------
#
# AND THE FIRST RUN ALREADY CORRECTED A NUMBER THAT HAD BEEN REPORTED TO NY4I.
# A plain grep for crCommand said 386 rows and 310 raw globals; stripping
# comments first gives 369 and 303. The difference is commented-out rows,
# which are NOT the same set as retired ones and must not be counted as live
# work. That is the whole reason this reuses PascalSource rather than grepping.
#
# ------------------------------------------------------------------------
# THE RATCHET REACHED ZERO -- 2026-09-14 -- AND THIS BECAME THE GUARD
# ------------------------------------------------------------------------
#
# CFGCA held 415 rows when this lint was written and holds none: the array,
# CFGRecord, CommandsArraySize and all four positional side tables are deleted.
# Every ceiling below is 0.
#
# SO THE QUESTION IT ASKS HAS INVERTED. It used to be "has a number risen",
# which needed a floor as well, because a count of zero from a broken parser
# looks exactly like a count of zero from finished work -- the failure mode
# recorded in the agent memory `guards-must-not-fail-open`. Now zero IS the
# answer, and ANY occurrence fails.
#
# THE PARSE IS STILL PROVEN, and it has to be, for the same reason: a lint that
# reports nothing because it read nothing must not report success. It checks
# that uCFG.pas was read and yielded a plausible amount of code before
# believing a count of zero.
#
# AND IT SCANS THE WHOLE TREE, not just uCFG. The array cannot come back
# "correctly" in another unit either -- what is being prevented is the SHAPE:
# a const table holding the address of a global so that something can write
# through it.

[CmdletBinding()]
param(
   # Print the remaining rows for one measure, so the worklist is readable
   # rather than just a number. -List CFGCA is the useful one.
   [string] $List = ''
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

Import-Module (Join-Path $PSScriptRoot 'PascalSource.psm1') -Force

$root   = Split-Path -Parent $PSScriptRoot          # ...\tr4w
$uCFG   = Join-Path $root 'src\uCFG.pas'

if (-not (Test-Path $uCFG))
{
   Write-Host "Lint-ConfigArrays: cannot find $uCFG" -ForegroundColor Red
   exit 1
}

# uCFG ALONE PROVES THE PARSE; THE TREE IS WHAT IS GUARDED. The shape cannot
# come back in another unit either, and putting it in one would be the obvious
# way to get past a lint that only reads uCFG.
$cfgCode = Get-PascalCodeOnlyLines -Path $uCFG

. (Join-Path $PSScriptRoot 'Get-ScanExclusions.ps1')   # Test-Tr4wScannable

$code = @($cfgCode)
foreach ($f in @(Get-ChildItem -Path (Join-Path $root 'src') -Recurse -Include *.pas,*.inc |
                 Where-Object { Test-Tr4wScannable $_.FullName }))
{
   if ($f.FullName -eq $uCFG) { continue }
   $code += @(Get-PascalCodeOnlyLines -Path $f.FullName)
}

# --------------------------------------------------------------------------
# THE CEILINGS.
#
# Lower one when work lands; NEVER raise one. A rise means a new setting was
# added to the array instead of to uSettingsModel, which is the thing this
# lint exists to stop.
#
# The Floor is what the count must not drop below without the ceiling dropping
# too -- i.e. it catches a broken parser, not progress.
# --------------------------------------------------------------------------
$measures = @(
   @{ Name    = 'CFGCA rows'
      Pattern = 'crCommand:'
      Ceiling = 0
      Note    = 'a const row naming a command -- the array is GONE, keep it gone' }

   @{ Name    = 'CFGCA rows writing a raw global'
      Pattern = 'crAddress:\s*@'
      Ceiling = 0
      Note    = 'a table writing through the address of a global' }

   @{ Name    = 'ArrayRecordArray entries'
      Pattern = 'arVar:\s*@'
      Ceiling = 0
      Note    = 'discrete allow-lists -- a subrange type or a registered vocabulary now' }

   @{ Name    = 'ListParamArray entries'
      Pattern = 'lpVar:\s*@'
      Ceiling = 0
      Note    = 'enum spelling lists -- the subsystem registers its own vocabulary now' }

   @{ Name    = 'CommandsProcArray handlers'
      Pattern = '^\s*@\w+.*(//.*)?$'
      Ceiling = 0
      Note    = 'crP -- a property setter, which cannot point at the wrong handler'
      Section = 'CommandsProcArray' }

   @{ Name    = 'AdditionalProcsArray hooks'
      Pattern = '^\s*@\w+.*(//.*)?$'
      Ceiling = 0
      Note    = 'crA -- an effect in uSettingsEffects, which runs however the value was set'
      Section = 'AdditionalProcsArray' }
)

# A section-scoped count: from the array's declaration to the closing ');'.
function Measure-Section
{
   param([string[]] $Lines, [string] $Section, [string] $Pattern)

   $inside = $false
   $n = 0
   foreach ($line in $Lines)
   {
      if (-not $inside)
      {
         if ($line -match "$Section\s*:\s*array") { $inside = $true }
         continue
      }
      if ($line -match '^\s*\)\s*;') { break }
      if ($line -match $Pattern) { $n++ }
   }
   return $n
}

# THE PARSE, PROVEN BEFORE ANY ZERO IS BELIEVED. uCFG is a large unit and
# always will be -- it is still the config parser -- so a handful of lines back
# from the stripper means the stripper failed, not that the file emptied.
if ($cfgCode.Count -lt 200)
{
   Write-Host ("Lint-ConfigArrays: uCFG.pas yielded only {0} code line(s) -- the " +
               "parse failed, which is not a pass." -f $cfgCode.Count) -ForegroundColor Red
   exit 1
}

$failed  = $false
$results = @()

foreach ($m in $measures)
{
   if ($m.ContainsKey('Section'))
   {
      $count = Measure-Section -Lines $code -Section $m.Section -Pattern $m.Pattern
   }
   else
   {
      $count = ($code | Select-String -Pattern $m.Pattern -AllMatches |
                  ForEach-Object { $_.Matches.Count } | Measure-Object -Sum).Sum
      if ($null -eq $count) { $count = 0 }
   }

   $status = 'gone'

   if ($count -gt $m.Ceiling)
   {
      # Every ceiling is 0, so this is "the shape came back".
      $status = 'CAME BACK'
      $failed = $true
   }

   $results += [pscustomobject]@{
      Measure = $m.Name
      Count   = $count
      Ceiling = $m.Ceiling
      Status  = $status
      Note    = $m.Note
   }
}

Write-Host ''
Write-Host 'Lint-ConfigArrays -- the config array family' -ForegroundColor Cyan
foreach ($r in $results)
{
   $colour = switch ($r.Status)
   {
      'gone'        { 'Gray' }
      'CAME BACK'   { 'Red' }
      default       { 'Yellow' }
   }
   Write-Host ('   {0,-34} {1,4} / {2,4}   {3}' -f $r.Measure, $r.Count, $r.Ceiling, $r.Status) `
              -ForegroundColor $colour
   Write-Host ('       {0}' -f $r.Note) -ForegroundColor DarkGray
}

# --------------------------------------------------------------------------
# -List: turn the number into a worklist.
# --------------------------------------------------------------------------
if ($List -ne '')
{
   Write-Host ''
   switch ($List)
   {
      'CFGCA' {
         Write-Host 'Commands still writing a raw global:' -ForegroundColor Cyan
         foreach ($line in $code)
         {
            if ($line -match "crCommand:\s*'([^']+)'" -and $line -match 'crAddress:\s*@(\w[\w.]*)')
            {
               $cmd = [regex]::Match($line, "crCommand:\s*'([^']+)'").Groups[1].Value
               $var = [regex]::Match($line, 'crAddress:\s*@([\w.]+)').Groups[1].Value
               Write-Host ('   {0,-44} {1}' -f $cmd, $var)
            }
         }
      }
      default {
         Write-Host "Unknown -List '$List'. Known: CFGCA" -ForegroundColor Yellow
      }
   }
}

Write-Host ''
if ($failed)
{
   Write-Host 'Lint-ConfigArrays FAILED -- the config array shape is back.' -ForegroundColor Red
   Write-Host '  A const table holding the ADDRESS of a global, so that something' -ForegroundColor Red
   Write-Host '  can write through it, is what the settings migration removed. A' -ForegroundColor Red
   Write-Host '  setting is a published property on uSettingsModel: its name is the' -ForegroundColor Red
   Write-Host '  property path, its bounds are its type, and its side effect is its' -ForegroundColor Red
   Write-Host '  setter. See docs/CFG_ARRAY_ELIMINATION.md.' -ForegroundColor Red
   exit 1
}

Write-Host 'Lint-ConfigArrays: the config arrays are gone and have not come back.' -ForegroundColor Green
exit 0
