unit uTestRadioLinkRetry;
{$I ..\..\src\tr4w.inc}

(* THE RECONNECT BACK-OFF, PINNED -- AND EVERY CASE HERE IS A MEASURED DEFECT.

  NY4I's IC-7760 over LAN, 2026-09-26, with a deliberately wrong password.  The
  log announced one interval and waited another:

     warn  Auth failed for IC7760 - check credentials; will retry every 60000 ms
     info  IC7760 retrying after authentication failure (waited 1000 ms)

  Eight logins in nine seconds, each one a session the radio then has to expire.
  Two separate statements were putting the interval back to one second, and a
  third bug meant the 60 s was often never chosen at all, because the fact "the
  last attempt was rejected" was read off a transport that reacting to the
  rejection had already freed.

  So the cases that matter are the ORDERINGS, not the arithmetic:
  Test_AuthIntervalSurvivesTheDropItCauses is the defect NY4I measured, and
  Test_LinkUpIsWhatClearsTheFailure is the transition the stale
  "Auth failed - check credentials" on his screen proves was never reached. *)

interface

uses
   SysUtils, uTR4WTestFramework, uRadioLinkRetry;

type
   TRadioLinkRetryTests = class(TTestCase)
   protected
      procedure Test_StartsAtTheInitialInterval;
      procedure Test_AttemptFailureBacksOffAndCaps;
      procedure Test_AuthRejectionTakesTheAuthInterval;
      procedure Test_AuthIntervalSurvivesTheDropItCauses;
      procedure Test_AuthIntervalIsNotDoubled;
      procedure Test_ReportedOncePerRunOfFailures;
      procedure Test_LinkUpIsWhatClearsTheFailure;
      procedure Test_LinkUpWithNoFailureAsksForNoClear;
      procedure Test_ARunEndsAtLinkUpSoTheNextIsReported;
   public
      procedure RunAllTests; override;
   end;

implementation

const
   (* The three uRadioPolling.pFactoryRadio passes in. *)
   INITIAL_MS = 1000;
   MAX_MS     = 30000;
   AUTH_MS    = 60000;

function NewRetry: TRadioLinkRetry;
begin
   Result := TRadioLinkRetry.Create(INITIAL_MS, MAX_MS, AUTH_MS);
end;

procedure TRadioLinkRetryTests.Test_StartsAtTheInitialInterval;
var
   r: TRadioLinkRetry;
begin
   r := NewRetry;
   try
      CheckEquals(INITIAL_MS, r.DelayMs, 'a fresh radio waits the initial interval');
      CheckFalse(r.AuthRejected, 'nothing has been rejected yet');
      CheckFalse(r.TakeAuthReportDue, 'there is nothing to report');
   finally
      r.Free;
   end;
end;

procedure TRadioLinkRetryTests.Test_AttemptFailureBacksOffAndCaps;
var
   r: TRadioLinkRetry;
   i: integer;
begin
   r := NewRetry;
   try
      r.NoteAttemptFailed;
      CheckEquals(2000, r.DelayMs, 'the first failure doubles 1s');
      r.NoteAttemptFailed;
      CheckEquals(4000, r.DelayMs, 'and doubles again');

      for i := 1 to 20 do
         begin
         r.NoteAttemptFailed;
         end;
      CheckEquals(MAX_MS, r.DelayMs, 'and is capped, never unbounded');
   finally
      r.Free;
   end;
end;

procedure TRadioLinkRetryTests.Test_AuthRejectionTakesTheAuthInterval;
var
   r: TRadioLinkRetry;
begin
   r := NewRetry;
   try
      r.NoteAuthRejected;
      CheckTrue(r.AuthRejected, 'the rejection is latched, not read off a transport');
      CheckEquals(AUTH_MS, r.DelayMs, 'bad credentials do not fix themselves in a second');
   finally
      r.Free;
   end;
end;

(* THE DEFECT NY4I MEASURED.  An authentication rejection necessarily drops the
  link, so the "new disconnect, reset the back-off" arm ran immediately after
  the auth arm had chosen 60 s and put it back to 1 s. *)
procedure TRadioLinkRetryTests.Test_AuthIntervalSurvivesTheDropItCauses;
var
   r: TRadioLinkRetry;
begin
   r := NewRetry;
   try
      r.NoteAuthRejected;
      r.NoteLinkDropped;
      CheckEquals(AUTH_MS, r.DelayMs,
                  'the drop an auth rejection causes must not reset its interval');
      CheckTrue(r.AuthRejected, 'and the rejection still stands');
   finally
      r.Free;
   end;
end;

procedure TRadioLinkRetryTests.Test_AuthIntervalIsNotDoubled;
var
   r: TRadioLinkRetry;
begin
   r := NewRetry;
   try
      r.NoteAuthRejected;
      r.NoteAttemptFailed;
      CheckEquals(AUTH_MS, r.DelayMs,
                  'the auth interval is a floor, not a starting point to double');
   finally
      r.Free;
   end;
end;

procedure TRadioLinkRetryTests.Test_ReportedOncePerRunOfFailures;
var
   r: TRadioLinkRetry;
begin
   r := NewRetry;
   try
      r.NoteAuthRejected;
      CheckTrue(r.TakeAuthReportDue, 'the operator is told clearly the first time');
      r.NoteAuthRejected;
      CheckFalse(r.TakeAuthReportDue, 'and not once per retry -- that is wallpaper');
      r.NoteAuthRejected;
      CheckFalse(r.TakeAuthReportDue, 'still quiet');
   finally
      r.Free;
   end;
end;

(* THE STATE TRANSITION THE STALE MESSAGE PROVES WAS NEVER REACHED.  NoteLinkUp
  returning True is the ONLY thing that clears the banner and the panel, and it
  must not depend on a flag the caller could have reset. *)
procedure TRadioLinkRetryTests.Test_LinkUpIsWhatClearsTheFailure;
var
   r: TRadioLinkRetry;
begin
   r := NewRetry;
   try
      r.NoteAuthRejected;
      CheckTrue(r.TakeAuthReportDue, 'reported');

      CheckTrue(r.NoteLinkUp, 'coming up after a failure asks for the display to clear');
      CheckFalse(r.AuthRejected, 'the radio accepted the credentials');
      CheckEquals(INITIAL_MS, r.DelayMs, 'and the back-off starts over');

      CheckFalse(r.NoteLinkUp, 'a second link-up has nothing left to clear');
   finally
      r.Free;
   end;
end;

(* A rejection that was LATCHED but never reported -- the connected branch sees
  one before the report arm runs -- still has to clear the state. *)
procedure TRadioLinkRetryTests.Test_LinkUpWithNoFailureAsksForNoClear;
var
   r: TRadioLinkRetry;
begin
   r := NewRetry;
   try
      CheckFalse(r.NoteLinkUp, 'a radio that simply connected says nothing');

      r.NoteAuthRejected;
      CheckTrue(r.NoteLinkUp, 'an unreported rejection is still a state to leave');
   finally
      r.Free;
   end;
end;

procedure TRadioLinkRetryTests.Test_ARunEndsAtLinkUpSoTheNextIsReported;
var
   r: TRadioLinkRetry;
begin
   r := NewRetry;
   try
      r.NoteAuthRejected;
      CheckTrue(r.TakeAuthReportDue, 'first run reported');
      r.NoteLinkUp;

      (* The session expired and the radio refused the next login. *)
      r.NoteAuthRejected;
      CheckTrue(r.TakeAuthReportDue,
                'a NEW run of failures is reported again -- silence would be worse');
      CheckEquals(AUTH_MS, r.DelayMs, 'and backs off again');
   finally
      r.Free;
   end;
end;

procedure TRadioLinkRetryTests.RunAllTests;
begin
   Test_StartsAtTheInitialInterval;
   Test_AttemptFailureBacksOffAndCaps;
   Test_AuthRejectionTakesTheAuthInterval;
   Test_AuthIntervalSurvivesTheDropItCauses;
   Test_AuthIntervalIsNotDoubled;
   Test_ReportedOncePerRunOfFailures;
   Test_LinkUpIsWhatClearsTheFailure;
   Test_LinkUpWithNoFailureAsksForNoClear;
   Test_ARunEndsAtLinkUpSoTheNextIsReported;
end;

end.
