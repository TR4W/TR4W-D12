<#
.SYNOPSIS
   Fail the build if production code reads a stored X-QSO field (ceXQSO, the
   operator's flag; ceOffContest, the contest's rule as stamped) anywhere but
   the few places that own it, OR works the contest's rule out anywhere but
   the places that SET the stored value. A reader of a logged QSO asks ONE
   thing: uContestRegistry.StoredQSOIsXQSO (or StoredQSOCountsTowardTotals).

.DESCRIPTION
   WHY THIS EXISTS -- Q98 stage S1 (docs/CONTEST_OWNERSHIP_DESIGN.md 8.2v),
   and log schema 10 (NY4I, 2026-11-19).

   An X-QSO is the operator's flag (ceXQSO, the log's is_xqso) OR the contest
   refusing the QSO by its own band/mode/host-area rule. Until schema 10 the
   second half was DERIVED every time a reader asked; NY4I ruled that it is
   decided when the QSO is LOGGED and STORED (ceOffContest, is_off_contest),
   and that every reader simply reads it: "Otherwise we have business rules
   being derived at cabrillo generation." So there are two fences:

   FENCE 1 -- THE FIELDS. A reader that tests ceXQSO or ceOffContest by hand
   sees only half of the answer: it would export an automatic X-QSO as a plain
   QSO: line, count it in a total, or paint it as an ordinary row -- and
   nothing else fails, because each field is a legal Boolean.

     ceXQSO        contestFactory\uContestBase.pas      QSOIsXQSO, the judge
                   contestFactory\uContestRegistry.pas  StoredQSOIsXQSO
                   uLogRepository.pas                   binds and reads is_xqso
                   uEditQSO.pas                         the operator's checkbox
                   uContestMatrix.pas                   prints the STORED flag
                   VC.pas                               declares the field
                   uLogBinaryFile.pas                   the frozen D7 record has
                                                        it; the .TRW converter
                                                        carries it
                   uADIF.pas (WRITE ONLY)               the import arms store
                                                        what the file states
     ceOffContest  contestFactory\uContestRegistry.pas  StampOffContest writes
                                                        it, StoredQSOIsXQSO reads
                   uLogRepository.pas                   binds and reads
                                                        is_off_contest
                   uEditQSO.pas                         greys the box when only
                                                        the rule says X-QSO
                   VC.pas                               declares the field

   FENCE 2 -- THE JUDGE. QSOIsOffContest, QSOIsXQSO, LoggedQSOIsXQSO,
   QSOCountsTowardTotals and StampOffContest work the contest's rule out NOW.
   They belong only where the stored value is SET -- a QSO logged, the
   rescore, an import, an edit saved, a record arriving from the network --
   and in the scoring that runs at those same moments. A call of any of them
   in another unit is read-time rule evaluation coming back, and fails.

     contestFactory\uContestBase.pas      the rule and the judge; scoring
     contestFactory\uContestRegistry.pas  LoggedQSOIsXQSO, StampOffContest
     trdos\logsubs2.pas                   LogContact stamps and counts the
                                          QSO being logged
     trdos\logdupe.pas                    the multipliers of a QSO being
                                          scored
     MainUnit.pas                         the rescore's stamp; the loader's
                                          contest-blind (nil) test
     uEditQSO.pas                         the save re-stamps
     uLogStore.pas                        every append, a peer's edit, the
                                          one-shot stamp of a migrated log
     uGetServerLog.pas                    the server's records as they arrive

   AN ALLOW-LISTED FILE THAT NO LONGER MENTIONS WHAT IT IS LISTED FOR FAILS as
   stale, so the lists only shrink and the lint has a floor: a parse that
   finds nothing cannot pass.

   READ THROUGH PascalSource.psm1, so a comment or a string literal that names
   a field or a routine is not a mention, and a look-alike identifier
   (StoredQSOIsXQSO, ceXQSOx) is not one either. src only: a test may read
   anything.

.EXAMPLE
   .\Lint-XQSOReads.ps1
   .\Lint-XQSOReads.ps1 -SelfTest
#>

param(
   [string] $SourceDir = (Join-Path (Split-Path $PSScriptRoot -Parent) 'src'),
   # Run the fixture and the parser's own fixtures, then stop.
   [switch] $SelfTest
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'PascalSource.psm1') -Force
. (Join-Path $PSScriptRoot 'Get-ScanExclusions.ps1')   # Test-Tr4wScannable -- IDE backup dirs are not source

# --------------------------------------------------------------------------
# FENCE 1 -- THE STORED FIELDS AND THEIR OWNERS. Never grow a list without a
# reason a reviewer would accept: a new reader asks StoredQSOIsXQSO.
# --------------------------------------------------------------------------
$FIELDS = [ordered]@{
   'ceXQSO' = @{
      Allowed   = [ordered]@{
         'contestFactory\uContestBase.pas'     = 'QSOIsXQSO -- the judge'
         'contestFactory\uContestRegistry.pas' = 'StoredQSOIsXQSO -- the reader''s predicate'
         'uLogRepository.pas'                  = 'binds and reads the is_xqso column'
         'uEditQSO.pas'                        = 'the operator''s checkbox -- his statement'
         'uContestMatrix.pas'                  = 'prints the STORED flag (xqso=)'
         'VC.pas'                              = 'declares the field'
         'uLogBinaryFile.pas'                  = 'the frozen D7 record declares it; the converter carries what the file states'
      }
      WriteOnly = [ordered]@{
         'uADIF.pas' = 'the import arms store what the file states'
      }
   }
   'ceOffContest' = @{
      Allowed   = [ordered]@{
         'contestFactory\uContestRegistry.pas' = 'StampOffContest writes it; StoredQSOIsXQSO reads it'
         'uLogRepository.pas'                  = 'binds and reads the is_off_contest column'
         'uEditQSO.pas'                        = 'greys the X-QSO box when only the rule says so'
         'VC.pas'                              = 'declares the field'
      }
      # uLogBinaryFile left this table with issue 386 batch B (2026-11-26): the
      # .TRW converter starts from Clear and never names the field.
      WriteOnly = [ordered]@{
      }
   }
}

# --------------------------------------------------------------------------
# FENCE 2 -- THE JUDGE: the routines that work the contest's rule out now,
# and the units that SET the stored value (or score at that same moment).
# --------------------------------------------------------------------------
$JUDGE_ROUTINES = @('QSOIsOffContest', 'QSOIsXQSO', 'LoggedQSOIsXQSO',
                    'QSOCountsTowardTotals', 'StampOffContest')
$JUDGES = [ordered]@{
   'contestFactory\uContestBase.pas'     = 'the rule and the judge; scoring asks them'
   'contestFactory\uContestRegistry.pas' = 'LoggedQSOIsXQSO and StampOffContest'
   'trdos\logsubs2.pas'                  = 'LogContact stamps and counts the QSO being logged'
   'trdos\logdupe.pas'                   = 'the multipliers of a QSO being scored'
   'MainUnit.pas'                        = 'the rescore stamps; the loader''s contest-blind nil test'
   'uEditQSO.pas'                        = 'the save re-stamps'
   'uLogStore.pas'                       = 'every append, a peer''s edit, the one-shot stamp'
   'uGetServerLog.pas'                   = 'the server''s records as they arrive'
}

function New-WordRegex
{
   param([string] $Name, [string] $Tail = '')
   return [regex]::new('(?<![\w])' + [regex]::Escape($Name) + '(?![\w])' + $Tail, 'IgnoreCase')
}

# Every mention of field $Field in one file's code-only text: line number and
# whether it is a write (an assignment to the field).
function Find-FieldMentions
{
   param([string] $Text, [string] $Field)

   $mentionRx = New-WordRegex -Name $Field
   $writeRx   = New-WordRegex -Name $Field -Tail '\s*:='
   $hits = @()
   $lines = $Text -split "`n"
   for ($i = 0; $i -lt $lines.Count; $i++)
   {
      $line = $lines[$i]
      $mentions = $mentionRx.Matches($line).Count
      if ($mentions -eq 0)
      {
         continue
      }
      $writes = $writeRx.Matches($line).Count
      $hits += [pscustomobject]@{
         Line   = $i + 1
         Reads  = $mentions - $writes
         Writes = $writes
      }
   }
   return $hits
}

# Built ONCE: the lint reads every line of every file under src.
$script:JudgeRx = @($JUDGE_ROUTINES | ForEach-Object {
   [pscustomobject]@{ Name = $_; Rx = (New-WordRegex -Name $_) }
})

# Every line of one file's code-only text that names a judge routine.
function Find-JudgeMentions
{
   param([string] $Text)

   $hits = @()
   $lines = $Text -split "`n"
   for ($i = 0; $i -lt $lines.Count; $i++)
   {
      foreach ($judge in $script:JudgeRx)
      {
         if ($judge.Rx.IsMatch($lines[$i]))
         {
            $hits += [pscustomobject]@{ Line = $i + 1; Routine = $judge.Name }
         }
      }
   }
   return $hits
}

# --------------------------------------------------------------------------
# THE FIXTURE -- every shape, before any tree number is believed.
# --------------------------------------------------------------------------
function Invoke-FixtureCheck
{
   $fixture = @(
      'unit F;'
      'implementation'
      'procedure P(var r: ContestExchange);'
      'begin'
      '   if r.ceXQSO then'                                  # line 5: a read
      '      begin'
      '      r.ceXQSO := True;'                              # line 7: a write
      '      end;'
      '   x := r.ceXQSOx;'                                   # line 9: another identifier
      '   // r.ceXQSO in a comment'
      '   (* r.ceXQSO and QSOIsXQSO(c, r) in a comment *)'
      '   s := ''r.ceXQSO and LoggedQSOIsXQSO(r) in a string'';'
      '   r.CEXQSO := r.ceXQSO or b;'                        # line 13: a write AND a read
      '   r.ceOffContest := False;'                          # line 14: a write of the stamp
      '   if r.ceOffContest then x := 1;'                    # line 15: a read of the stamp
      '   y := StoredQSOIsXQSO(r);'                          # line 16: the reader's door, not a judge
      '   z := QSOIsXQSO(c, r);'                             # line 17: the judge
      '   StampOffContest(r);'                               # line 18: the stamp
      '   w := StoredQSOCountsTowardTotals(r);'              # line 19: the reader's door, not a judge
      '   v := qsoisoffcontest(c, r);'                       # line 20: the rule, any case
      'end;'
      'end.'
   )
   $tmp = Join-Path ([IO.Path]::GetTempPath()) ('xqsoreads_' + [Guid]::NewGuid().ToString('N') + '.pas')
   try
   {
      [IO.File]::WriteAllText($tmp, ($fixture -join "`r`n"))
      $text = Get-PascalCodeOnlyText -Path $tmp -BlankStrings
      $gotX = @(Find-FieldMentions -Text $text -Field 'ceXQSO' |
                ForEach-Object { '{0}:{1}r{2}w' -f $_.Line, $_.Reads, $_.Writes })
      $gotO = @(Find-FieldMentions -Text $text -Field 'ceOffContest' |
                ForEach-Object { '{0}:{1}r{2}w' -f $_.Line, $_.Reads, $_.Writes })
      $gotJ = @(Find-JudgeMentions -Text $text |
                ForEach-Object { '{0}:{1}' -f $_.Line, $_.Routine })
   }
   finally
   {
      if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Force }
   }
   $expectedX = @('5:1r0w', '7:0r1w', '13:1r1w')
   $expectedO = @('14:0r1w', '15:1r0w')
   $expectedJ = @('17:QSOIsXQSO', '18:StampOffContest', '20:QSOIsOffContest')

   $bad = 0
   foreach ($case in @(
         @{ Name = 'ceXQSO';       Got = $gotX; Expected = $expectedX },
         @{ Name = 'ceOffContest'; Got = $gotO; Expected = $expectedO },
         @{ Name = 'judge calls';  Got = $gotJ; Expected = $expectedJ }))
   {
      if (($case.Got -join ',') -ne ($case.Expected -join ','))
      {
         $bad++
         Write-Host ('FIXTURE FAIL ({0})' -f $case.Name) -ForegroundColor Red
         Write-Host ('   expected: {0}' -f ($case.Expected -join ', ')) -ForegroundColor Red
         Write-Host ('   got     : {0}' -f ($case.Got -join ', ')) -ForegroundColor Red
      }
   }
   if (($bad -eq 0) -and $SelfTest)
   {
      Write-Host 'FIXTURE ok   reads, writes, judge calls, comments, strings and look-alike identifiers told apart'
   }
   $bad += Invoke-PascalSourceSelfTest
   return $bad
}

if (-not (Test-Path -LiteralPath $SourceDir))
{
   Write-Host "Lint-XQSOReads: source directory not found: $SourceDir -- that is a failure, not a pass." -ForegroundColor Red
   exit 1
}
$srcRoot = (Resolve-Path -LiteralPath $SourceDir).Path.TrimEnd('\')

if ((Invoke-FixtureCheck) -ne 0)
{
   Write-Host 'Lint-XQSOReads: the fixture failed -- the parse cannot be trusted, which is not a pass.' -ForegroundColor Red
   exit 1
}
if ($SelfTest)
{
   exit 0
}

$files = @(Get-TR4WPascalFiles -Root $srcRoot |
           Where-Object { (Test-Tr4wScannable $_.FullName) })
if ($files.Count -eq 0)
{
   Write-Host "Lint-XQSOReads: scanned ZERO files under $srcRoot -- that is a broken lint, not a pass." -ForegroundColor Red
   exit 1
}

$violations = @()
$seen = @{}
foreach ($field in $FIELDS.Keys)
{
   $seen[$field] = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
}
$judgesSeen = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)

foreach ($f in $files)
{
   $rel  = $f.FullName.Substring($srcRoot.Length).TrimStart('\')
   $text = Get-PascalCodeOnlyText -Path $f.FullName -BlankStrings

   foreach ($field in $FIELDS.Keys)
   {
      $allowed   = $FIELDS[$field].Allowed
      $writeOnly = $FIELDS[$field].WriteOnly
      foreach ($hit in (Find-FieldMentions -Text $text -Field $field))
      {
         if ($allowed.Contains($rel))
         {
            [void]$seen[$field].Add($rel)
            continue
         }
         if ($writeOnly.Contains($rel))
         {
            [void]$seen[$field].Add($rel)
            if ($hit.Reads -eq 0)
            {
               continue
            }
         }
         $violations += [pscustomobject]@{ File = $rel; Line = $hit.Line; What = ('reads {0}' -f $field) }
      }
   }

   foreach ($hit in (Find-JudgeMentions -Text $text))
   {
      if ($JUDGES.Contains($rel))
      {
         [void]$judgesSeen.Add($rel)
         continue
      }
      $violations += [pscustomobject]@{ File = $rel; Line = $hit.Line; What = ('calls {0} -- works the contest''s rule out at read time' -f $hit.Routine) }
   }
}

$stale = @()
foreach ($field in $FIELDS.Keys)
{
   foreach ($owner in (@($FIELDS[$field].Allowed.Keys) + @($FIELDS[$field].WriteOnly.Keys)))
   {
      if (-not $seen[$field].Contains($owner))
      {
         $stale += ('{0} ({1})' -f $owner, $field)
      }
   }
}
foreach ($judge in $JUDGES.Keys)
{
   if (-not $judgesSeen.Contains($judge))
   {
      $stale += ('{0} (judge)' -f $judge)
   }
}

$ownerCount = 0
$ownerSeen = 0
foreach ($field in $FIELDS.Keys)
{
   $ownerCount += $FIELDS[$field].Allowed.Count + $FIELDS[$field].WriteOnly.Count
   $ownerSeen  += $seen[$field].Count
}
Write-Host ('Lint-XQSOReads: {0} file(s) scanned; {1} of {2} field owner(s) and {3} of {4} judge unit(s) found.' -f
            $files.Count, $ownerSeen, $ownerCount, $judgesSeen.Count, $JUDGES.Count)

$failed = $false
if ($violations.Count -gt 0)
{
   $failed = $true
   foreach ($v in $violations)
   {
      Write-Host ('  {0}({1}): {2}' -f $v.File, $v.Line, $v.What) -ForegroundColor Red
   }
   Write-Host ''
   Write-Host ('Lint-XQSOReads FAILED -- {0} violation(s).' -f $violations.Count) -ForegroundColor Red
   Write-Host 'An X-QSO is the operator''s flag OR the contest''s rule AS STORED when the QSO' -ForegroundColor Red
   Write-Host 'was logged or last rescored (log schema 10). A reader asks' -ForegroundColor Red
   Write-Host 'uContestRegistry.StoredQSOIsXQSO or StoredQSOCountsTowardTotals; only the units' -ForegroundColor Red
   Write-Host 'that SET the stored value may work the rule out (docs/LOG_SCHEMA.md).' -ForegroundColor Red
}
if ($stale.Count -gt 0)
{
   $failed = $true
   $msg = 'Lint-XQSOReads FAILED -- allow-listed but no mention found: {0}. ' -f ($stale -join ', ')
   Write-Host ($msg + 'Delete the entry if the use went; if it did not, the parse is broken.') -ForegroundColor Red
}
if ($failed)
{
   exit 1
}
Write-Host 'Lint-XQSOReads: no read of a stored X-QSO field outside its owners, and no rule worked out outside the units that set it.'
exit 0
