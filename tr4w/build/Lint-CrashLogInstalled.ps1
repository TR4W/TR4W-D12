<#
.SYNOPSIS
   Every program this tree SHIPS must install the crash reporter. Fails the
   build when one does not.

.DESCRIPTION
   LINKING THE REPORTER IS NOT INSTALLING IT, AND NOTHING FAILED WHEN ONE OF THE
   TWO PROGRAMS DID ONLY THE FIRST.

   uCrashLog reaches tr4wserver through tr4wserverUnit -> TF, so the Darwin
   server binary carried 45 of its symbols and the unit was plainly compiled in.
   No call installed it: measured 2026-09-27, InstallCrashLog had NO LIVE CALLER
   ANYWHERE IN THE TREE -- every occurrence was its declaration, its
   implementation, or a comment -- and the only live installation was
   uProgramMain's InstallCrashLogLCL. A tr4wserver crash therefore produced
   nothing at all.

   CLAUDE.md had asserted the opposite for weeks ("tr4wserver calls
   InstallCrashLog and now gets crash logging, which it never had"), which is the
   reason it survived: the claim was believed, and there was no gate to disagree
   with it. Nothing about a missing call breaks a build, a test, or the corpus.
   A crash reporter is the one subsystem whose absence is invisible precisely
   when you need it.

   So this asserts the call exists, per program, by reading the source.

   WHAT COUNTS AS INSTALLED. A live -- that is, not commented out -- call to
   InstallCrashLog or InstallCrashLogLCL, in the program file itself or in any
   unit it names in its uses clause. One level of indirection is deliberate and
   sufficient: tr4w.lpr installs from uProgramMain, which it names, and a chain
   deeper than that would be hiding the most order-sensitive call in the program
   somewhere nothing points at.

   THE UNIT-TEST BINARY IS IN SCOPE, AND THE FIRST DRAFT OF THIS LINT HAD THAT
   WRONG. It was listed as must-NOT-install, reasoned from the framework already
   catching exceptions itself -- and the lint promptly failed, because
   uTestStatusAndNotice.EnsureMainForm calls InstallCrashLog on purpose and says
   at length why.

   THE REASON HAS NOTHING TO DO WITH CRASH REPORTING. InstallCrashLog is what
   records the main thread id, so OnMainThread is a lie until it runs: a test
   binary that skips it finds every uMainForm guard reporting "off the main
   thread", SetElementText deferring every write and SetStatusText dropping every
   one -- silently, because ReportOffMainThread also stays quiet while the id is
   zero. So the install is load-bearing for tests that have nothing to do with
   faults, and the lint requires it.

   That is worth keeping because it is the more interesting shape: the reporter
   is not only a reporter. Something that looks purely diagnostic turned out to
   own a fact the UI layer reads.

   THE FLOORS. A guard that passes on an empty search is worse than none, so
   this fails rather than passes when it cannot see its subject: no .lpr files
   found at all, a named program file missing, uCrashLog.pas missing, or a .lpr
   in a shipping location that is not classified below. That last one is the
   ratchet -- a new program cannot skip the decision by simply existing.

.PARAMETER SourceDir
   The tr4w directory. The repository root is its parent.
#>

param(
   [string] $SourceDir = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot 'PascalSource.psm1') -Force

$tr4wDir  = (Resolve-Path -LiteralPath $SourceDir).Path
$repoRoot = (Resolve-Path -LiteralPath (Join-Path $tr4wDir '..')).Path

$problems = 0

# ---------------------------------------------------------------------------
# THE SUBJECT OF THE LINT. If this unit is not here the whole check is
# meaningless, so its absence is a failure and not a pass.
# ---------------------------------------------------------------------------
$crashUnit = Join-Path $tr4wDir 'src\uCrashLog.pas'
if (-not (Test-Path -LiteralPath $crashUnit))
   {
   Write-Host "Lint-CrashLogInstalled FAILED: src\uCrashLog.pas not found at $crashUnit."
   Write-Host '  Nothing can be checked without it. If the reporter was renamed or removed,'
   Write-Host '  update this lint in the same commit.'
   exit 1
   }

# ---------------------------------------------------------------------------
# THE CLASSIFICATION. Two shipping programs, and everything else exempt BY
# LOCATION with the reason stated once rather than per file.
#
# Exempt-by-location is not laziness: test\, tools\ and build\ hold diagnostic
# probes, one-shot converters and lint helpers. They are run at a console by a
# developer who is watching, several are built by scripts no gate runs at all
# (CLAUDE.md records that nothing runs Build-Bench), and a crash reporter buys
# them nothing a visible stack trace does not already give.
# ---------------------------------------------------------------------------
$required = @(
   @{ Lpr = 'tr4w\tr4w.lpr';                  Why = 'the application' }
   @{ Lpr = 'tr4w\tr4wserver\tr4wserver.lpr'; Why = 'the multi-op server' }
   # NOT for crash reporting -- for GMainThreadId. See the header.
   @{ Lpr = 'tr4w\test\unit\tr4w_unit_tests.lpr'
      Why = 'OnMainThread is false everywhere until InstallCrashLog has run' }
)

# Nothing is currently expected NOT to install. The list is kept rather than
# deleted: a program that deliberately abstains needs somewhere to say so, and
# the alternative is an exemption expressed by silence.
$forbidden = @()

$exemptRx = '\\test\\|\\tools\\|\\build\\|\\docs\\'

# ---------------------------------------------------------------------------
# DISCOVERY, so a NEW program cannot skip the decision by existing quietly.
# ---------------------------------------------------------------------------
# .claude\worktrees holds OTHER CHECKOUTS of this repository -- another agent's
# working copy, days out of date -- so their program files are not this tree's to
# judge. CLAUDE.md makes the same point about src\backup and src\graphify-out:
# a hand-run search finds them and every lint has to exclude them.
$skipRx = '\\build-out\\|\\backup|\\graphify-out\\|\\dcu|\\worktrees\\'
$allLpr = @(Get-ChildItem -LiteralPath $repoRoot -Recurse -File -Filter '*.lpr' `
               -ErrorAction SilentlyContinue |
            Where-Object { $_.FullName -notmatch $skipRx })

if ($allLpr.Count -eq 0)
   {
   Write-Host "Lint-CrashLogInstalled FAILED: no .lpr files found under $repoRoot."
   Write-Host '  That is a broken search, not a clean tree -- this repository has more than'
   Write-Host '  twenty program files. Check the path passed as -SourceDir.'
   exit 1
   }

# ---------------------------------------------------------------------------
# Does a program install the reporter? Comment-blind by construction:
# Get-PascalCodeOnlyText blanks comments and leaves code, so a commented-out
# call -- or this lint's own header quoted in a source file -- cannot satisfy it.
# ---------------------------------------------------------------------------
# A DECLARATION IS NOT A CALL, and the first draft of this lint could not tell
# them apart: it reported that tr4w.lpr "installs from src\uCrashLog.pas", having
# matched `procedure InstallCrashLog;` -- the declaration of the very thing being
# looked for. A lint that is satisfied by the existence of the procedure it is
# checking for calls is satisfied always.
#
# Two guards, because either alone is thin. The lookbehind rejects a procedure or
# function heading, and the candidate list below drops the two units that DEFINE
# the installers: uCrashLogLCL legitimately calls InstallCrashLog, but that is
# the installer's own implementation, not a program installing anything.
$callRx = '(?i)(?<!\b(?:procedure|function)\s{1,8})\bInstallCrashLog(?:LCL)?\s*(?:;|\()'
$definers = @('ucrashlog.pas', 'ucrashloglcl.pas')

function Get-UsesUnitPaths
   {
   param([string] $LprPath)

   $dir  = Split-Path -Parent $LprPath
   $code = Get-PascalCodeOnlyText -Path $LprPath
   $m    = [regex]::Match($code, '(?is)\buses\b(.*?);')
   if (-not $m.Success) { return @() }

   $paths = New-Object System.Collections.ArrayList

   # `uFoo in 'src\uFoo.pas'` -- the path is given, so use it.
   foreach ($q in [regex]::Matches($m.Groups[1].Value, "in\s+'([^']+)'"))
      {
      $full = Join-Path $dir $q.Groups[1].Value
      if (Test-Path -LiteralPath $full) { [void]$paths.Add((Resolve-Path -LiteralPath $full).Path) }
      }

   # A bare unit name resolves off the search path, which this script does not
   # have. Look it up by file name under src\ instead -- case-insensitively,
   # because Pascal identifiers are and this tree spells them several ways.
   $bare = $m.Groups[1].Value -replace "in\s+'[^']*'", ''
   foreach ($tok in [regex]::Matches($bare, '(?m)^[\s,]*([A-Za-z_][A-Za-z0-9_]*)'))
      {
      $name = $tok.Groups[1].Value
      $hit  = Get-ChildItem -LiteralPath (Join-Path $tr4wDir 'src') -Recurse -File `
                 -Filter "$name.pas" -ErrorAction SilentlyContinue |
              Where-Object { $_.FullName -notmatch $skipRx } |
              Select-Object -First 1
      if ($hit) { [void]$paths.Add($hit.FullName) }
      }

   return ($paths | Select-Object -Unique)
   }

function Find-InstallSite
   {
   param([string] $LprPath)

   $candidates = @($LprPath) + (Get-UsesUnitPaths -LprPath $LprPath)
   foreach ($f in $candidates)
      {
      if (-not (Test-Path -LiteralPath $f)) { continue }
      if ($definers -contains (Split-Path -Leaf $f).ToLowerInvariant()) { continue }
      $code = Get-PascalCodeOnlyText -Path $f
      if ([regex]::IsMatch($code, $callRx))
         {
         return $f
         }
      }
   return $null
   }

# ------------------------------------------------------- the required programs
foreach ($r in $required)
   {
   $full = Join-Path $repoRoot $r.Lpr
   if (-not (Test-Path -LiteralPath $full))
      {
      Write-Host ("  MISSING PROGRAM  {0}  ({1})" -f $r.Lpr, $r.Why)
      Write-Host '      A named program file is gone. Either it was renamed -- fix this lint in'
      Write-Host '      the same commit -- or the tree is broken.'
      $problems++
      continue
      }

   $site = Find-InstallSite -LprPath $full
   if ($site)
      {
      Write-Host ("    {0}: installs from {1}" -f $r.Lpr, `
                  ($site.Substring($repoRoot.Length).TrimStart('\')))
      }
   else
      {
      Write-Host ("  NOT INSTALLED  {0}  ({1})" -f $r.Lpr, $r.Why)
      Write-Host '      This program links uCrashLog but nothing calls InstallCrashLog or'
      Write-Host '      InstallCrashLogLCL, so a crash in it produces NOTHING. Add the call'
      Write-Host '      to the program body, right after the log appender is configured.'
      $problems++
      }
   }

# ------------------------------------------------------ the forbidden programs
foreach ($f in $forbidden)
   {
   $full = Join-Path $repoRoot $f.Lpr
   if (-not (Test-Path -LiteralPath $full))
      {
      Write-Host ("  MISSING PROGRAM  {0}  (expected NOT to install)" -f $f.Lpr)
      $problems++
      continue
      }

   $site = Find-InstallSite -LprPath $full
   if ($site)
      {
      Write-Host ("  UNEXPECTED INSTALL  {0}  ->  {1}" -f $f.Lpr, `
                  ($site.Substring($repoRoot.Length).TrimStart('\')))
      Write-Host ("      {0}." -f $f.Why)
      Write-Host '      If that has been reconsidered, move this entry from $forbidden to'
      Write-Host '      $required and say why in the commit -- do not just delete the row.'
      $problems++
      }
   else
      {
      Write-Host ("    {0}: does not install, as intended" -f $f.Lpr)
      }
   }

# --------------------------------------------- anything shipping and unclassified
$known = @()
$known += $required  | ForEach-Object { (Join-Path $repoRoot $_.Lpr).ToLowerInvariant() }
$known += $forbidden | ForEach-Object { (Join-Path $repoRoot $_.Lpr).ToLowerInvariant() }

foreach ($lpr in $allLpr)
   {
   if ($known -contains $lpr.FullName.ToLowerInvariant()) { continue }
   if ($lpr.FullName -match $exemptRx) { continue }

   Write-Host ("  UNCLASSIFIED  {0}" -f $lpr.FullName.Substring($repoRoot.Length).TrimStart('\'))
   Write-Host '      A program file outside test\, tools\, build\ and docs\ is a program this'
   Write-Host '      tree SHIPS, and it has to say whether it installs the crash reporter.'
   Write-Host '      Add it to $required or $forbidden in this script, with a reason.'
   $problems++
   }

if ($problems -gt 0)
   {
   Write-Host ''
   Write-Host "Lint-CrashLogInstalled FAILED: $problems problem(s)."
   Write-Host '  Linking uCrashLog is not installing it. The server linked the reporter for'
   Write-Host '  months with nothing calling it, and nothing failed -- which is exactly why'
   Write-Host '  this gate exists.'
   exit 1
   }

Write-Host ("    Lint-CrashLogInstalled: {0} shipping program(s) install the reporter, " -f $required.Count) -NoNewline
Write-Host ("{0} deliberately do not, {1} .lpr scanned." -f $forbidden.Count, $allLpr.Count)
exit 0
