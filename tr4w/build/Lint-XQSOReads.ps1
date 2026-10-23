<#
.SYNOPSIS
   Fail the build if production code reads the stored X-QSO flag (ceXQSO)
   anywhere but the few places that own it. "Is this an X-QSO" is ONE
   predicate: uContestBase.QSOIsXQSO, or uContestRegistry.LoggedQSOIsXQSO for
   a reader that holds only a record.

.DESCRIPTION
   WHY THIS EXISTS -- Q98 stage S1 (docs/CONTEST_OWNERSHIP_DESIGN.md 8.2v).
   NY4I: "automatic X-QSO is OK". An off-band or off-mode QSO is an X-QSO,
   and that is DERIVED, never stored: X-QSO = the operator's flag (ceXQSO, the
   log's is_xqso) OR the record's contest refusing its band or mode. A reader
   that tests ceXQSO directly sees only half of it -- it would export an
   off-band QSO as a plain QSO: line, count it in a total, or paint it as an
   ordinary row -- and nothing else fails, because the flag is a legal
   Boolean. So the reads are gated, and the predicate is the only way to ask.

   THE ALLOW-LIST -- the field's owners, each with its reason:

     contestFactory\uContestBase.pas   QSOIsXQSO itself -- the predicate
     uLogRepository.pas                binds and reads the is_xqso column
     uEditQSO.pas                      the operator's checkbox: his statement,
                                       shown and stored as he made it
     uContestMatrix.pas                prints the STORED flag (xqso=) -- the
                                       matrix pins what was stored
     VC.pas                            declares the field

   uADIF.pas IS ALLOWED ONLY TO WRITE IT -- `ceXQSO := True`, its import arms
   storing what the file states (CLAIMEDQSO 0, DXLOG_XQSO). Any other mention
   there is a read and fails.

   AN ALLOW-LISTED FILE THAT NO LONGER MENTIONS THE FIELD FAILS as stale, so
   the list only shrinks and the lint has a floor: a parse that finds nothing
   cannot pass.

   READ THROUGH PascalSource.psm1, so a comment or a string literal that names
   the field is not a mention. src only: a test may read anything.

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
# THE ALLOW-LIST. Never grow it without a reason a reviewer would accept: a
# new reader asks QSOIsXQSO / LoggedQSOIsXQSO.
# --------------------------------------------------------------------------
$ALLOWED = [ordered]@{
   'contestFactory\uContestBase.pas' = 'QSOIsXQSO -- the predicate'
   'uLogRepository.pas'              = 'binds and reads the is_xqso column'
   'uEditQSO.pas'                    = 'the operator''s checkbox -- his statement'
   'uContestMatrix.pas'              = 'prints the STORED flag (xqso=)'
   'VC.pas'                          = 'declares the field'
}
# Files that may WRITE the field and nothing more.
$WRITE_ONLY = [ordered]@{
   'uADIF.pas' = 'the import arms store what the file states'
}

$script:MentionRx = [regex]::new('(?<![\w])ceXQSO(?![\w])', 'IgnoreCase')
$script:WriteRx   = [regex]::new('(?<![\w])ceXQSO\s*:=', 'IgnoreCase')

# Every mention in one file's code-only text: line number and whether it is a
# write (an assignment to the field).
function Find-XQSOMentions
{
   param([string] $Text)

   $hits = @()
   $lines = $Text -split "`n"
   for ($i = 0; $i -lt $lines.Count; $i++)
   {
      $line = $lines[$i]
      $mentions = $script:MentionRx.Matches($line).Count
      if ($mentions -eq 0)
      {
         continue
      }
      $writes = $script:WriteRx.Matches($line).Count
      $hits += [pscustomobject]@{
         Line   = $i + 1
         Reads  = $mentions - $writes
         Writes = $writes
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
      '   if r.ceXQSO then'                       # line 5: a read
      '      begin'
      '      r.ceXQSO := True;'                   # line 7: a write
      '      end;'
      '   x := r.ceXQSOx;'                        # line 9: another identifier
      '   // r.ceXQSO in a comment'
      '   (* r.ceXQSO in a comment *)'
      '   s := ''r.ceXQSO in a string'';'
      '   r.CEXQSO := r.ceXQSO or b;'             # line 13: a write AND a read
      'end;'
      'end.'
   )
   $tmp = Join-Path ([IO.Path]::GetTempPath()) ('xqsoreads_' + [Guid]::NewGuid().ToString('N') + '.pas')
   try
   {
      [IO.File]::WriteAllText($tmp, ($fixture -join "`r`n"))
      $text = Get-PascalCodeOnlyText -Path $tmp -BlankStrings
      $got  = @(Find-XQSOMentions -Text $text | ForEach-Object { '{0}:{1}r{2}w' -f $_.Line, $_.Reads, $_.Writes })
   }
   finally
   {
      if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Force }
   }
   $expected = @('5:1r0w', '7:0r1w', '13:1r1w')

   $bad = 0
   if (($got -join ',') -ne ($expected -join ','))
   {
      $bad++
      Write-Host 'FIXTURE FAIL' -ForegroundColor Red
      Write-Host ('   expected: {0}' -f ($expected -join ', ')) -ForegroundColor Red
      Write-Host ('   got     : {0}' -f ($got -join ', ')) -ForegroundColor Red
   }
   elseif ($SelfTest)
   {
      Write-Host 'FIXTURE ok   reads, writes, comments, strings and look-alike identifiers told apart'
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
           Where-Object { (Test-Tr4wScannable $_.FullName) -and $_.FullName -notmatch '\\graphify-out\\' })
if ($files.Count -eq 0)
{
   Write-Host "Lint-XQSOReads: scanned ZERO files under $srcRoot -- that is a broken lint, not a pass." -ForegroundColor Red
   exit 1
}

$violations = @()
$seen = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
foreach ($f in $files)
{
   $rel  = $f.FullName.Substring($srcRoot.Length).TrimStart('\')
   $text = Get-PascalCodeOnlyText -Path $f.FullName -BlankStrings
   foreach ($hit in (Find-XQSOMentions -Text $text))
   {
      if ($ALLOWED.Contains($rel))
      {
         [void]$seen.Add($rel)
         continue
      }
      if ($WRITE_ONLY.Contains($rel))
      {
         [void]$seen.Add($rel)
         if ($hit.Reads -eq 0)
         {
            continue
         }
      }
      $violations += [pscustomobject]@{ File = $rel; Line = $hit.Line }
   }
}

$stale = @(@($ALLOWED.Keys) + @($WRITE_ONLY.Keys) | Where-Object { -not $seen.Contains($_) })

Write-Host ('Lint-XQSOReads: {0} file(s) scanned; {1} of {2} allowed owner(s) of ceXQSO found.' -f
            $files.Count, $seen.Count, ($ALLOWED.Count + $WRITE_ONLY.Count))

$failed = $false
if ($violations.Count -gt 0)
{
   $failed = $true
   foreach ($v in $violations)
   {
      Write-Host ('  {0}({1}): reads ceXQSO' -f $v.File, $v.Line) -ForegroundColor Red
   }
   Write-Host ''
   Write-Host ('Lint-XQSOReads FAILED -- {0} read(s) of the stored X-QSO flag.' -f $violations.Count) -ForegroundColor Red
   Write-Host 'An X-QSO is the operator''s flag OR the contest''s band/mode rule (Q98). Ask' -ForegroundColor Red
   Write-Host 'uContestBase.QSOIsXQSO, or uContestRegistry.LoggedQSOIsXQSO for a record.' -ForegroundColor Red
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
Write-Host 'Lint-XQSOReads: no read of ceXQSO outside its owners.'
exit 0
