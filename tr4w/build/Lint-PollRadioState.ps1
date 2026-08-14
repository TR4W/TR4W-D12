<#
.SYNOPSIS
   Fails the build when a radio driver has a PollRadioState body that can never run.

.DESCRIPTION
   The factory poll loop (uRadioPolling.pFactoryRadio) calls PollRadioState ONLY
   for radios whose requiresPolling is True:

       else if Assigned(ro) and ro.requiresPolling then
          ...
          ro.PollRadioState;

   So a driver that overrides PollRadioState with real work AND leaves
   requiresPolling False has written code that never executes. It compiles, it
   registers, it connects -- and the poll silently does nothing.

   That is not hypothetical. TTCIRadio shipped exactly this combination: its
   PollRadioState held an idle liveness ping that had never once fired, and the
   symptom only surfaced when a second job (the rit_offset repair GET) was added
   to the same routine and also did nothing.

   Audited at the time, the other push radios were fine, which is what makes
   this worth a lint rather than a comment:
     - TK4Radio      sets False in the ctor then True for the serial case
     - TFlexAPIRadio sets False and its PollRadioState is empty

   A driver is FLAGGED when all of these hold:
     1. it assigns requiresPolling := False
     2. it never assigns requiresPolling := True anywhere in the unit
     3. its PollRadioState override contains at least one executable statement

   Rule 2 keeps the conditional K4 pattern legal. Rule 3 keeps an intentionally
   empty override legal -- that is how a push radio says "nothing to do".

.PARAMETER SourceDir
   Root of the Pascal sources. Only src\radioFactory is scanned.

.PARAMETER FailOnViolation
   Default True. Pass -FailOnViolation:$false to report without failing.
#>
param(
    [string]$SourceDir = (Join-Path (Split-Path $PSScriptRoot -Parent) 'src'),
    [bool]$FailOnViolation = $true
)

$ErrorActionPreference = 'Stop'

$factoryDir = Join-Path $SourceDir 'radioFactory'
if (-not (Test-Path $factoryDir)) {
    Write-Error "Lint-PollRadioState: radioFactory directory not found: $factoryDir"
    exit 2
}

$violations = @()
$checked    = 0
$overrides  = 0    # PollRadioState implementations seen at all
$flagSeen   = 0    # files that mention requiresPolling at all

foreach ($file in Get-ChildItem -Path $factoryDir -Filter *.pas -File) {
    $text = Get-Content -Path $file.FullName -Raw

    # Strip { } and // comments so a commented-out assignment cannot mislead us.
    $code = [regex]::Replace($text, '\{[\s\S]*?\}', ' ')
    $code = [regex]::Replace($code, '//[^\r\n]*', ' ')

    # Counted for the floor and the summary BEFORE any filtering, so the report
    # can say what exists as well as what was judged.
    if ([regex]::IsMatch($code, 'procedure\s+T\w+\.PollRadioState\s*;', 'IgnoreCase')) { $overrides++ }
    if ([regex]::IsMatch($code, 'requiresPolling', 'IgnoreCase'))                      { $flagSeen++ }

    $setsFalse = [regex]::IsMatch($code, 'requiresPolling\s*:=\s*False\s*;', 'IgnoreCase')
    if (-not $setsFalse) { continue }

    $setsTrue = [regex]::IsMatch($code, 'requiresPolling\s*:=\s*True\s*;', 'IgnoreCase')
    if ($setsTrue) { continue }   # conditional (the K4 pattern) -- legal

    # Find the PollRadioState implementation and take its body.
    $m = [regex]::Match($code,
        'procedure\s+T\w+\.PollRadioState\s*;(?<decl>[\s\S]*?)\bbegin\b(?<body>[\s\S]*?)\bend\s*;',
        'IgnoreCase')
    if (-not $m.Success) { continue }   # no override -- inherits the base no-op

    $checked++
    $body = $m.Groups['body'].Value

    # Executable = anything left once whitespace is gone.
    if ($body.Trim().Length -gt 0) {
        $firstStatement = ($body -split "`n" | Where-Object { $_.Trim().Length -gt 0 } | Select-Object -First 1).Trim()
        $violations += [pscustomobject]@{
            File      = $file.Name
            Statement = $firstStatement
        }
    }
}

if ($violations.Count -gt 0) {
    Write-Output "Lint-PollRadioState: $($violations.Count) driver(s) have a PollRadioState that can NEVER run."
    Write-Output "  The factory poll loop only calls PollRadioState when requiresPolling = True."
    Write-Output ""
    foreach ($v in $violations) {
        Write-Output ("  {0}" -f $v.File)
        Write-Output ("      requiresPolling := False, but PollRadioState does: {0}" -f $v.Statement)
    }
    Write-Output ""
    Write-Output "  Fix: set requiresPolling := True (a repair/liveness tick is a legitimate"
    Write-Output "  reason -- it need not poll state), or empty the override if there is"
    Write-Output "  genuinely nothing to do."
    if ($FailOnViolation) { exit 1 }
    exit 0
}

# A FLOOR. Zero here does not mean "clean", it means this lint judged nothing --
# because requiresPolling was renamed, the drivers moved, or the polling model
# changed. Lint-RadioRegistry once reported "0 registrations, no collisions" and
# PASSED, which is the mistake being avoided; a guard that cannot fire must say
# so rather than print a reassuring line.
if ($overrides -eq 0 -or $flagSeen -eq 0) {
    Write-Output "Lint-PollRadioState: refusing to pass -- nothing to judge."
    Write-Output "  PollRadioState overrides found : $overrides"
    Write-Output "  files mentioning requiresPolling: $flagSeen"
    Write-Output "  Both should be non-zero in src\radioFactory. If the polling model changed,"
    Write-Output "  update this lint; if it is gone, delete it."
    exit 1
}

# SAY WHAT WAS FILTERED, not just what was judged. The old wording was
# "$checked override(s) checked", which reads as "there are no overrides" when
# $checked is 0 -- while 24 exist and were deliberately skipped as safe. A
# reader cannot tell a clean run from a broken lint without these numbers.
Write-Output ("Lint-PollRadioState: {0} override(s) present, {1} with an unconditional requiresPolling := False; none unreachable." -f $overrides, $checked)
exit 0
