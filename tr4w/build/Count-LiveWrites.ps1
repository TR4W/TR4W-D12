# Counts LIVE raw file-WRITE calls in TR4W's program sources (tr4w\src), outside
# the two units that own where a file goes and how it is written.
#
# WHY THIS EXISTS (issue 165, 2026-11-20). NY4I installed TR4W in
# C:\Program Files\TR4W and every write failed: the settings, tr4w.log, the
# contest log. The fix put the decision of WHERE a written file lives in one
# unit, uAppPaths (WrittenFileDir / WrittenFilePath / BesideContestLogFilePath
# and the accessors under them), and the safe write of a text file in one
# routine, uFileText.WriteAllTextUTF8 / TryWriteAllTextUTF8 (write <name>.new,
# then rename, the old file whole at every instant). NY4I: "all writes should be
# centralized as much as possible, or at least the path name generation."
#
# A TEXT LINT CANNOT DECIDE PATH PROVENANCE -- whether the name handed to a
# FileCreate was built by uAppPaths three calls earlier is a data-flow question,
# not a pattern. So this is the honest version: it counts the RAW WRITE CALLS
# per file outside uAppPaths and uFileText, and RATCHETS the total. A new raw
# write anywhere fails the build until it goes through the wrapper (or an
# existing one is converted to make room, with the ceiling lowered).
#
#   .\Count-LiveWrites.ps1             # per file, the live count
#   .\Count-LiveWrites.ps1 -Detail     # plus every line, so each can be triaged
#   .\Count-LiveWrites.ps1 -SelfTest   # the fixture only
#   .\Count-LiveWrites.ps1 -Gate       # what Run-Lints runs: fails over the ceiling
#
# WHAT IT COUNTS, called bare or unit-qualified (SysUtils., FileUtil.):
#
#   fmCreate, fmOpenWrite, fmOpenReadWrite   a TFileStream or FileOpen for writing
#   FileCreate(                              the RTL's create
#   Rewrite( / Append(<var>)                 Pascal text-file writes
#   .SaveToFile(                             TStrings, TStream, ... saves
#   CopyFile(                                a copy's destination is a write
#   RenameFile(                              a rename is a write to the folder
#   OpenFileForWrite( / tOpenFileForWrite(   utils_file's create
#
# WHAT IT DOES NOT COUNT, on purpose:
#   * comments and string literals (PascalSource.psm1, -BlankStrings);
#   * a METHOD reached through a dot -- FOps.CopyFile(...), list.Append(x): the
#     write is counted where the method makes the raw call;
#   * a declaration -- `function FileCreate(`, `procedure CopyFile(`.
#   * SQLite, Indy and Log4D: they open their own files and are not rewritten
#     (Log4D is under include\, which the file set skips).
#
# THE FLOOR, as in Count-LiveMove: a counter that matched nothing reports a clean
# zero. Every run counts a fixture first and refuses a tree number if that is not
# exact, and refuses when src\MainUnit.pas is not in the file set.
#
# PowerShell, so like every lint it does not run on the Linux/macOS builders
# (build-unix.sh reports the lints as not-run). It reads text; nothing about it
# depends on the platform the program is built for.

param(
   # -SourceDir is the name Run-Lints.ps1 passes to every lint: the tr4w folder.
   [Alias('SourceDir')]
   [string] $Root   = (Split-Path -Parent $PSScriptRoot),
   [switch] $Detail,
   [switch] $SelfTest,
   [switch] $Gate
)

# THE CEILING (issue 165, 2026-11-20). Ratchets DOWN only: when the count falls,
# lower this in the same commit; never raise it. Route a new write through
# uAppPaths + uFileText instead.
# 42 at birth: the residual list is in the issue 165 commit message, each site
# with why it is not converted yet.
# 40 -> 39, 2026-11-26: MainUnit.OpenLogFile (the .TRW opened read-write)
# deleted with the other .TRW file routines (issue 385).
$WRITE_CEILING = 39
# Floors for -Gate: fewer than these means the reader failed, not that the tree
# is clean.
$FILE_FLOOR  = 300
$COUNT_FLOOR = 20

Import-Module (Join-Path $PSScriptRoot 'PascalSource.psm1') -Force

# The two units that own the answer. BY FILE NAME, so a clone anywhere matches.
$OWNERS = @('uAppPaths.pas', 'uFileText.pas')

$q   = '(?:(?:SysUtils|FileUtil|System)\s*\.\s*)?'
$not = '(?<![\w.])(?<!(?:procedure|function)\s+)'
$script:LiveRx = [regex]::new(
   '(?i)' +
   '(\bfmCreate\b|\bfmOpenWrite\b|\bfmOpenReadWrite\b' +
   '|' + $not + $q + '(?:FileCreate|Rewrite|CopyFile|RenameFile|t?OpenFileForWrite)\s*\(' +
   '|' + $not + $q + 'Append\s*\(\s*\w+\s*\)' +
   '|(?<!(?:procedure|function)\s+[\w.]*)\.\s*SaveToFile\s*\()')

function Get-LiveWriteHits
{
   param([Parameter(Mandatory = $true)][string] $Path)

   $clean = Get-PascalCodeOnlyText -Path $Path -BlankStrings
   $hits  = @($script:LiveRx.Matches($clean))
   # Append( IS ALSO A COMMON LOCAL ROUTINE NAME (uCommandHelp has one). It is
   # a text-file write only in a unit that Assigns a text file, so elsewhere
   # it is not counted.
   if ($clean -notmatch '(?i)\bAssign(?:File)?\s*\(') {
      $hits = @($hits | Where-Object { $_.Value -notmatch '(?i)^Append' })
   }
   if ($hits.Count -eq 0) { return @() }

   $lineStarts = New-Object 'System.Collections.Generic.List[int]'
   $lineStarts.Add(0)
   foreach ($nl in [regex]::Matches($clean, "`n")) {
      $lineStarts.Add($nl.Index + 1)
   }

   $result = @()
   foreach ($h in $hits) {
      $lo = 0; $hi = $lineStarts.Count - 1
      while ($lo -lt $hi) {
         $mid = [int][math]::Ceiling(($lo + $hi) / 2)
         if ($lineStarts[$mid] -le $h.Index) { $lo = $mid } else { $hi = $mid - 1 }
      }
      $result += [pscustomobject]@{
         Line = $lo + 1
         Call = ($h.Value -replace '\s+', '')
      }
   }
   return $result
}

# THE FIXTURE. Exactly NINE lines are live and marked LIVE; the rest are traps.
function Invoke-LiveWriteSelfTest
{
   $fixture = @(
      "unit fixture;",
      "procedure P;",
      "begin",
      "   s := TFileStream.Create(n, fmCreate);        // LIVE 1",
      "   h := FileCreate(n);                          // LIVE 2",
      "   AssignFile(f, n); Rewrite(f);                // LIVE 3",
      "   Append(f);                                   // LIVE 4",
      "   list.SaveToFile(n);                          // LIVE 5",
      "   FileUtil.CopyFile(a, b, [], False);          // LIVE 6 -- qualified",
      "   SysUtils.RenameFile(a, b);                   // LIVE 7",
      "   tOpenFileForWrite(h, n);                     // LIVE 8",
      "   s := TFileStream.Create(n, fmOpenReadWrite); // LIVE 9",
      "   // FileCreate(n);                            line comment",
      "   { list.SaveToFile(n); }                      brace comment",
      "   (* Rewrite(f); *)                            paren comment",
      "   m := 'FileCreate(n) failed';                 string literal",
      "   FOps.CopyFile(a, b);                         a method",
      "   list.Append(x);                              a TStrings method",
      "   s := TFileStream.Create(n, fmOpenRead);      a read",
      "   CopyFileName := 1; RenameFiles := 2;         look-alikes",
      "end;",
      "function FileCreate(const n: string): THandle; a declaration",
      "procedure CopyFile(const a, b: string);       a declaration",
      "procedure TOps.RenameFile(const a: string);   a method declaration",
      "procedure TStore.SaveToFile(const n: string);  a method declaration"
   )
   $expected = 9

   $tmp = Join-Path ([IO.Path]::GetTempPath()) ("livewrites_" + [Guid]::NewGuid().ToString('N') + ".pas")
   try {
      [IO.File]::WriteAllText($tmp, ($fixture -join "`r`n"))
      $got = @(Get-LiveWriteHits -Path $tmp)
   }
   finally {
      if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Force }
   }

   $ok = ($got.Count -eq $expected)
   if (-not $ok) {
      Write-Output ("Count-LiveWrites SELFTEST FAIL: expected {0} live write(s), got {1}:" -f $expected, $got.Count)
      foreach ($g in $got) {
         Write-Output ("   fixture line {0}: {1}   <- {2}" -f $g.Line, $g.Call, $fixture[$g.Line - 1].Trim())
      }
   }
   return $ok
}

# ---------------------------------------------------------------------------

if (-not (Invoke-LiveWriteSelfTest)) {
   Write-Output 'Count-LiveWrites: the fixture is wrong, so no tree count is reported.'
   exit 1
}
if ($SelfTest) {
   Write-Output 'Count-LiveWrites SELFTEST: the fixture''s 9 live writes counted exactly; every trap ignored.'
   exit 0
}

$srcRoot = Join-Path $Root 'src'
$files   = @(Get-TR4WPascalFiles -Root $srcRoot)

if (-not ($files | Where-Object { $_.Name -ieq 'MainUnit.pas' })) {
   Write-Output ("Count-LiveWrites: src\MainUnit.pas is not under '{0}' -- wrong -SourceDir? Refusing to report." -f $Root)
   exit 1
}

$srcRoot = $srcRoot.TrimEnd('\')
$total   = 0
$units   = 0

foreach ($f in ($files | Sort-Object FullName)) {
   if ($OWNERS -contains $f.Name) { continue }

   $hits = @(Get-LiveWriteHits -Path $f.FullName)
   if ($hits.Count -eq 0) { continue }

   $total += $hits.Count
   $units++
   if ($Gate) { continue }

   $rel = $f.FullName.Substring($srcRoot.Length).TrimStart('\')
   "{0,3}  {1}" -f $hits.Count, $rel
   if ($Detail) {
      $srcLines = [IO.File]::ReadAllLines($f.FullName)
      foreach ($h in $hits) {
         "       {0,6}: {1}" -f $h.Line, $srcLines[$h.Line - 1].Trim()
      }
   }
}

if ($Gate) {
   if ($files.Count -lt $FILE_FLOOR -or $total -lt $COUNT_FLOOR) {
      Write-Output ("Count-LiveWrites: only {0} file(s) / {1} live write(s) found -- floors are {2} / {3}. The reader or the root is broken; failing." -f $files.Count, $total, $FILE_FLOOR, $COUNT_FLOOR)
      exit 1
   }
   Write-Output ("Count-LiveWrites: {0} raw write call(s) outside uAppPaths/uFileText across {1} unit(s) (ceiling {2})" -f $total, $units, $WRITE_CEILING)
   if ($total -gt $WRITE_CEILING) {
      Write-Output ("Count-LiveWrites FAILED: {0} is over the ceiling of {1}. Build the path with uAppPaths.WrittenFilePath / BesideContestLogFilePath and write a text file with uFileText.TryWriteAllTextUTF8. Do not raise the ceiling." -f $total, $WRITE_CEILING)
      Write-Output '   .\tr4w\build\Count-LiveWrites.ps1 -Detail   lists every site.'
      exit 1
   }
   if ($total -lt $WRITE_CEILING) {
      Write-Output ("   down from {0} -- lower `$WRITE_CEILING in tr4w\build\Count-LiveWrites.ps1 to {1} and commit it with the fix." -f $WRITE_CEILING, $total)
   }
   exit 0
}

""
"Count-LiveWrites: {0} raw write call(s) outside uAppPaths/uFileText across {1} unit(s)." -f $total, $units
