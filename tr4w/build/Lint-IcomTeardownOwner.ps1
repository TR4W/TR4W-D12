<#
.SYNOPSIS
   Fails the build when an Icom-network reader thread tears its own transport down.

.DESCRIPTION
   THE INVARIANT. In uIcomNetworkTransport.pas, exactly one kind of thread may
   PERFORM a teardown: the owned timer thread (TimerTick), or an outside caller
   such as the polling thread. A routine that runs on an Indy UDP listener
   thread may only REQUEST one -- RequestTeardown -- and return.

   WHY A GATE RATHER THAN A COMMENT. Disconnect frees the TIdUDPServer whose
   listener thread is running the handler, and `Socket.Active := False` STOPS
   AND JOINS that listener. So a listener thread calling Disconnect waits for
   itself to finish, and it does so holding FLifecycleLock -- which means any
   other thread tearing the same transport down blocks behind it for ever.
   Shutdown and radio reconnection both wedge permanently.

   That is not a hypothetical shape: it shipped at the ICOM_PKT_DISCONNECT arm
   of HandleControlResponse and at the failed-stream-request arm of
   HandleStatusPacket, in the same file whose HandleLoginResponse carries a long
   comment explaining why it must not do exactly that. The rule was written
   down and one copy of it did not follow. Nothing in the compiler, the unit
   tests or the corpus can see the difference -- it needs either a radio that
   drops a session or this lint.

   THE LIST IS DELIBERATELY HAND-MAINTAINED. Which thread a routine runs on is
   not derivable from the text: it follows from TIdUDPServer.ThreadedEvent and
   the OnUDPRead assignment in CreateSockets. So the reader-thread routines are
   named here, and the lint REFUSES TO PASS if any named routine is missing
   from the file -- a rename that quietly drops coverage fails the build
   instead of reporting a clean run.

.PARAMETER SourceDir
   Root of the Pascal sources.

.PARAMETER FailOnViolation
   Default True. Pass -FailOnViolation:$false to report without failing.
#>
param(
    [string]$SourceDir = (Join-Path (Split-Path $PSScriptRoot -Parent) 'src'),
    [bool]$FailOnViolation = $true
)

$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot 'PascalSource.psm1') -Force

$unit = Join-Path $SourceDir 'uIcomNetworkTransport.pas'
if (-not (Test-Path -LiteralPath $unit)) {
    Write-Output "Lint-IcomTeardownOwner: refusing to pass -- unit not found: $unit"
    Write-Output "  If the Icom network transport moved, update this lint; if it is gone, delete it."
    exit 1
}

# EVERY ROUTINE THAT CAN BE REACHED FROM TIdUDPServer.OnUDPRead.
# HandleControlUDPRead and HandleCivUDPRead are the event handlers themselves;
# the rest are what they call, directly or transitively.
$readerRoutines = @(
    'HandleControlUDPRead'
    'HandleCivUDPRead'
    'HandleReceivedPacket'
    'HandleControlResponse'
    'HandlePingPacket'
    'HandleLoginResponse'
    'HandleCapabilities'
    'HandleStatusPacket'
    'HandleConnInfoPacket'
    'HandleTokenResponse'
    'HandleDataPacket'
    'HandleRetransmitRequest'
    'ExtractCivFrames'
)

# Comments blanked (so a note ABOUT Disconnect cannot fire) and string bodies
# blanked too (so a log message naming it cannot either).
$code = Get-PascalCodeOnlyText -Path $unit -BlankStrings

# Split the implementation section into one segment per routine. A nested
# routine stays inside its parent's segment, which is what we want -- it runs on
# the same thread.
$rx = [regex]'(?im)^\s*(?:procedure|function)\s+TIcomNetworkTransport\.(\w+)'
$starts = @()
foreach ($m in $rx.Matches($code)) {
    $starts += [pscustomobject]@{ Name = $m.Groups[1].Value; Index = $m.Index }
}

if ($starts.Count -eq 0) {
    Write-Output "Lint-IcomTeardownOwner: refusing to pass -- no TIcomNetworkTransport methods found."
    Write-Output "  The class was renamed or the parser no longer matches. Update this lint."
    exit 1
}

$bodies = @{}
for ($i = 0; $i -lt $starts.Count; $i++) {
    $from = $starts[$i].Index
    if ($i -lt $starts.Count - 1) {
        $to = $starts[$i + 1].Index
    }
    else {
        $to = $code.Length
    }
    # A name can appear twice (declaration in the class is excluded by the
    # anchor, but an overload would not be); concatenate rather than overwrite,
    # so coverage is never silently halved.
    $seg = $code.Substring($from, $to - $from)
    if ($bodies.ContainsKey($starts[$i].Name)) {
        $bodies[$starts[$i].Name] = $bodies[$starts[$i].Name] + "`r`n" + $seg
    }
    else {
        $bodies[$starts[$i].Name] = $seg
    }
}

# THE FLOOR: every named routine must exist.
$missing = @($readerRoutines | Where-Object { -not $bodies.ContainsKey($_) })
if ($missing.Count -gt 0) {
    Write-Output "Lint-IcomTeardownOwner: refusing to pass -- $($missing.Count) reader-thread routine(s) named by this lint do not exist:"
    foreach ($n in $missing) { Write-Output "    $n" }
    Write-Output "  A rename that drops coverage must fail, not pass quietly."
    Write-Output "  Fix the list in this script once you have confirmed which thread the new routine runs on."
    exit 1
}

# A BARE call: `Disconnect` as a statement, not `Something.Disconnect` and not
# the declaration or implementation header of Disconnect itself.
$callRx = [regex]'(?im)(?<![\.\w])Disconnect\s*;'

$violations = @()
foreach ($name in $readerRoutines) {
    $body = $bodies[$name]
    foreach ($m in $callRx.Matches($body)) {
        # Line number within the unit: count newlines up to the absolute offset.
        $abs = ($starts | Where-Object { $_.Name -eq $name } | Select-Object -First 1).Index + $m.Index
        $line = ($code.Substring(0, $abs) -split "`n").Count
        $violations += [pscustomobject]@{ Routine = $name; Line = $line }
    }
}

if ($violations.Count -gt 0) {
    Write-Output "Lint-IcomTeardownOwner: $($violations.Count) teardown(s) performed on an Indy listener thread."
    Write-Output ""
    foreach ($v in $violations) {
        Write-Output ("  uIcomNetworkTransport.pas:{0}  in {1}  calls Disconnect directly" -f $v.Line, $v.Routine)
    }
    Write-Output ""
    Write-Output "  Disconnect frees the TIdUDPServer whose listener thread is running this code,"
    Write-Output "  and deactivating it JOINS that thread -- so it waits for itself, holding"
    Write-Output "  FLifecycleLock, and every other thread tearing this transport down blocks"
    Write-Output "  behind it for ever."
    Write-Output ""
    Write-Output "  Fix: RequestTeardown('<why>'); and return. The timer thread performs it"
    Write-Output "  within one tick. See the note on FTeardownRequested."
    if ($FailOnViolation) { exit 1 }
    exit 0
}

Write-Output ("Lint-IcomTeardownOwner: {0} reader-thread routine(s) checked, {1} transport method(s) present; none performs its own teardown." -f $readerRoutines.Count, $starts.Count)
exit 0
