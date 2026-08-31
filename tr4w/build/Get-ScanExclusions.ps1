# Get-ScanExclusions -- the one definition of "this file is not ours to lint".
#
# WHY THIS FILE EXISTS. Two lints carried the exclusion regex as a literal
# ('\\__history\\|\\__recovery\\') and the other twelve carried nothing, so a
# directory the IDE creates was linted by some checks and not others -- which is
# the "copies drift, and the drift is invisible" case CLAUDE.md warns about,
# already at two copies before this.
#
# WHAT IT EXCLUDES, and all three are IDE-generated copies of source that no
# build compiles:
#
#   __history\   Delphi's editor backups.
#   __recovery\  Delphi's crash recovery.
#   backup\      LAZARUS's editor backups, and the one that actually bit.
#
# THE LAZARUS ONE, MEASURED 2026-08-31. src\ui\lcl\backup held 39 stale .lfm
# copies, so the form lints reported 78 designed forms against 39 tracked and
# lintlfm checked 13,187 properties instead of 6,594 -- half of everything those
# five checks validated was duplicates of files nothing compiles. Deleting the
# directory is NOT a fix: Lazarus recreates it on every save, and it is
# gitignored, so it never appears in git status. It came back within hours of
# being deleted, during an ordinary IDE session.
#
# IT IS ALSO A CORRECTNESS RISK, not only noise: Lint-LineEndings and Lint-BOM
# FAIL THE BUILD on a bad file, and a backup copy is a file nobody edits and
# nobody can fix -- a stale LF copy would have blocked the build with no way to
# clear it short of deleting a directory the IDE immediately recreates.
#
# ADDING TO THIS LIST IS A CLAIM that the directory holds generated copies, not
# source. Anything a build compiles must never be listed here -- an exclusion is
# indistinguishable from a passing check.

# Matched against a FULL PATH with backslash separators, case-insensitively
# (PowerShell -notmatch is case-insensitive by default, which is what we want:
# the IDEs are inconsistent about case).
$script:TR4W_SCAN_EXCLUDE = '\\__history\\|\\__recovery\\|\\backup\\'

function Test-Tr4wScannable
{
   <#
   .SYNOPSIS
      True when a path is TR4W source rather than an IDE-generated copy.
   .EXAMPLE
      Get-ChildItem -Recurse -File | Where-Object { Test-Tr4wScannable $_.FullName }
   #>
   param([Parameter(Mandatory)] [string] $FullName)

   return ($FullName -notmatch $script:TR4W_SCAN_EXCLUDE)
}
