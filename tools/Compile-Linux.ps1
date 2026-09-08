<#
.SYNOPSIS
   Compile one TR4W unit for x86_64-linux, to see what still binds it to Windows.

.DESCRIPTION
   The inner loop for the cross-platform work. It does NOT link and it does NOT
   produce anything shippable -- it answers one question: does this unit, and
   everything it uses, compile for a platform that is not Windows.

   Use it the way a linter is used. Point it at a unit you have just gated and
   read the first error; it names the exact identifier or unit that is still
   Windows-bound, which is a great deal more useful than reading the source and
   guessing.

   See docs/CROSS_COMPILING.md for how the toolchain was built.

.EXAMPLE
   .\tools\Compile-Linux.ps1 VC.pas
   .\tools\Compile-Linux.ps1 utils\uAnsiStr.pas -All
#>
[CmdletBinding()]
param(
   # Unit to compile, relative to tr4w\src (or an absolute path).
   [Parameter(Mandatory = $true, Position = 0)]
   [string] $Unit,

   # Show every error rather than just the first few.
   [switch] $All
)

$ErrorActionPreference = 'Stop'

$repo = Split-Path -Parent $PSScriptRoot
$fpc  = 'C:\fpcupdeluxe\fpcsrc\compiler\ppcrossx64.exe'
$rtl  = 'C:\fpcupdeluxe\fpcsrc\rtl\units\x86_64-linux'
$pkgs = 'C:\fpcupdeluxe\fpcsrc\packages'
$shim = Join-Path $repo 'tools\wsl-binutils'

if (-not (Test-Path $fpc)) {
   throw "No Linux cross compiler at $fpc. See docs/CROSS_COMPILING.md."
}
if (-not (Test-Path (Join-Path $shim 'x86_64-linux-as.exe'))) {
   throw "No binutils shim in $shim. See docs/CROSS_COMPILING.md."
}

$src = if ([System.IO.Path]::IsPathRooted($Unit)) { $Unit }
       else { Join-Path $repo "tr4w\src\$Unit" }
if (-not (Test-Path $src)) { throw "No such unit: $src" }

# Output goes to a scratch dir, never near the Windows build's units.
$out = Join-Path $env:TEMP 'tr4w-linux-units'
New-Item -ItemType Directory -Force -Path $out | Out-Null

# ORDER IS LOAD-BEARING: FPC takes the FIRST unit of a given name it finds, and
# the names COLLIDE. packages\fv -- Free Vision, FPC's text-mode widget library
# -- ships a unit called `menus`, so with the packages ahead of Lazarus the
# LCL's own controls.pp resolved `Menus` to Free Vision's and died with
# "Identifier not found TPopupMenu" (2026-09-08). That reads as a broken LCL
# and is a search-path bug. fv also carries `objects`, `drivers` and `app`.
#
# So: the RTL, then our own output, then Lazarus, then TR4W, and the packages
# LAST, where they can still supply anything nothing above declares.
$fu = @($rtl, $out,
        'C:\Lazarus\lcl', 'C:\Lazarus\lcl\widgetset', 'C:\Lazarus\lcl\forms',
        # nonwin32: LAZARUS'S OWN NON-WINDOWS REPLACEMENTS, and leaving it out
        # made this probe report FALSE FAILURES (added 2026-09-08). It holds
        # messages.pp -- a `Messages` unit for every target that is not Win32 --
        # so `uses Messages` IS portable, and Lazarus even ships the compiled
        # .ppu on the Linux box.
        #
        # Without this path the probe said "Can't find unit Messages used by
        # uNewContest" while the NATIVE Linux compiler built the same unit
        # without complaint. I was one step from editing a unit that had
        # nothing wrong with it.
        #
        # A false failure is cheaper than a false pass, but it is still a wrong
        # answer and it wastes the reader's time in the direction of making the
        # code WORSE. THE NATIVE BOX IS THE AUTHORITY; this probe only has to
        # agree with it, and where they disagree the probe is what to fix.
        'C:\Lazarus\lcl\nonwin32',
        'C:\Lazarus\components\lazutils',
        # datetimectrls: uEditQSOForm uses TDateTimePicker, and this directory
        # holds its SOURCE. It is an ordinary LCL component -- pure Lazarus,
        # portable -- so its absence here made a portable form report
        # "Can't find unit DateTimePicker", which is the short-sighted-probe
        # failure the comment above describes rather than a Windows binding.
        # Added 2026-09-08. Note the only compiled units shipped with Lazarus
        # for it are i386-win32 and x86_64-win64, which is why the SOURCE path
        # is what matters: this build compiles it for linux itself.
        'C:\Lazarus\components\datetimectrls',
        (Join-Path $repo 'tr4w\include'),
        (Join-Path $repo 'tr4w\src'))
# EVERY source directory the app build uses, from the one list that defines
# them. Compiling a unit whose dependency lives in src\ui\lcl or src\trdos
# otherwise fails with "Can't find unit", which says nothing about whether the
# unit is portable -- it is the probe that is short-sighted, not the code.
foreach ($d in @('ui\lcl', 'trdos', 'utils', 'lang', 'domain',
                 'radioFactory', 'contestFactory', 'rotatorFactory')) {
   $fu += (Join-Path $repo "tr4w\src\$d")
}
# The vendored Indy 10.6.3.3, same three directories the app build uses.
foreach ($d in @('Core', 'System', 'Protocols')) {
   $fu += (Join-Path $repo "tr4w\include\$d")
}
Get-ChildItem $pkgs -Directory | ForEach-Object {
   $d = Join-Path $_.FullName 'units\x86_64-linux'
   if (Test-Path $d) { $fu += $d }
}

# -Sc: C-style operators. NOT for TR4W's sake -- nothing here writes `+=` --
# but for LAZARUS's. Any unit that reaches lazutils dies inside
# lazfileutils.pas(1362) on `Param+=Params[p]` with "Illegal expression", which
# reads as a defect in Lazarus rather than a missing switch on our side, and
# cost a diagnosis on 2026-09-08. -Mdelphi turns C operators off; the affected
# Lazarus units declare {$mode objfpc} but that does not turn them back on.
$a = @('-Tlinux', '-Px86_64', '-MObjFPC', '-Sc', '-XPx86_64-linux-', "-FE$out", "-FU$out",
       '-FiC:\Lazarus\lcl\include',
       '-FiC:\Lazarus\components\lazutils',
       "-Fi$(Join-Path $repo 'tr4w\src')")
foreach ($p in $fu) { $a += "-Fu$p" }

# STALE UNITS FROM A DIFFERENT SWITCH SET ARE INDISTINGUISHABLE FROM A DEFECT.
#
# FPC reuses a .ppu whose source has not changed, and it cannot see that the
# COMPILER SWITCHES changed -- the same rule that makes -Incremental unsafe
# after a define flip in Build-App. It cost an hour on 2026-09-08: the probe
# was switched from -Mdelphi to -MObjFPC (which the LCL requires -- Delphi mode
# packs sets to one byte, so Lazarus's own `Integer(AFont.Style)` in grids.pas
# will not compile) and the LCL STILL failed, because the scratch directory
# still held units built the old way. Clearing it by hand fixed it instantly.
#
# So the switches are stamped beside the units, and any change wipes them.
$stamp = Join-Path $out '.switches'
$want  = ($a -join ' ')
if ((-not (Test-Path $stamp)) -or ((Get-Content -LiteralPath $stamp -Raw) -ne $want)) {
   Write-Host 'Compile-Linux: compiler switches changed -- clearing cached units.' -ForegroundColor DarkGray
   Remove-Item (Join-Path $out '*') -Recurse -Force -ErrorAction SilentlyContinue
   Set-Content -LiteralPath $stamp -Value $want -NoNewline
}

$env:PATH = "$shim;$env:PATH"
$output = & $fpc @a $src 2>&1
$fpcExit = $LASTEXITCODE

# THE COMPILER'S EXIT CODE DECIDES. TEXT ONLY EXPLAINS.
#
# This used to grep $output for 'Error:|Fatal:' and call anything else a pass,
# which meant a run that produced NO OUTPUT AT ALL printed "COMPILES FOR LINUX"
# and exited 0. That is not a hypothetical shape in this project: CLAUDE.md
# records the golden corpus reporting "24 passed, 0 failed" for two days while
# all THIRTEEN of its export runs were dying with an access violation, because
# it too discarded the exit code.
#
# It matters more here than it did there, because Lint-LinuxCompile GATES THE
# BUILD on this exit code and reports "N unit(s) still compile for
# x86_64-linux". A wrong answer is not merely missed coverage; it is a green
# ratchet asserting something nobody checked.
#
# What the old form could not see: a compiler that crashed without the word
# Error, a binutils-shim failure worded differently, an empty $output from a
# process that never started, and a timeout.
#
# THE TEXT SCAN IS KEPT, but only to SHOW the reason -- and disagreement between
# the two is itself reported, because it means one of these assumptions is wrong
# and silently picking either answer would hide that.
$problems = $output | Select-String -Pattern 'Error:|Fatal:'

# NO "EMPTY OUTPUT MEANS IT DID NOTHING" GUARD. I wrote one and it was WRONG:
# a successful compile that reuses cached units prints nothing at all, so it
# failed every cache hit -- including the whole pinned list on the second run.
# The exit code already covers the case that guard was reaching for, because a
# compiler that never started does not exit 0.

if ($fpcExit -eq 0 -and $problems) {
   Write-Host "Compile-Linux: FPC exited 0 but its output names an error for $Unit." -ForegroundColor Red
   Write-Host "  The exit code and the text disagree. Reporting FAILURE, because"
   Write-Host "  whichever is right, this script's assumptions are not."
   $problems | Select-Object -First 6
   exit 1
}

if ($fpcExit -eq 0) {
   Write-Host "COMPILES FOR LINUX: $Unit" -ForegroundColor Green
   exit 0
}

if (-not $problems) {
   Write-Host "still Windows-bound: $Unit -- FPC exited $fpcExit" -ForegroundColor Yellow
   Write-Host "  No 'Error:' or 'Fatal:' line to quote. The whole output follows."
   $output
   exit 1
}

Write-Host "still Windows-bound: $Unit" -ForegroundColor Yellow
if ($All) { $problems } else { $problems | Select-Object -First 6 }
exit 1
