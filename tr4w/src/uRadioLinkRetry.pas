unit uRadioLinkRetry;

(* THE RECONNECT BACK-OFF POLICY FOR ONE RADIO, IN ONE OBJECT.

  It was four assignments to a local integer scattered through the 700-line
  body of uRadioPolling.pFactoryRadio, and it had two bugs that only that
  scattering made possible -- both measured on NY4I's IC-7760 over LAN on
  2026-09-26, both with the log line that proves it:

     warn  Auth failed for IC7760 - check credentials; will retry every 60000 ms
     info  IC7760 retrying after authentication failure (waited 1000 ms)

  It announced sixty seconds and retried in one, eight times in nine seconds,
  each attempt a session the radio then has to expire.

  WHAT WENT WRONG, AND WHY IT IS A POLICY OBJECT NOW:

  1. An authentication rejection NECESSARILY drops the link -- so the "new
     disconnect, reset the back-off" arm ran immediately afterwards and put the
     interval back to one second.  Two statements, in different branches,
     disagreeing about the same variable.  NoteLinkDropped will not lower an
     interval an auth rejection raised, and that rule now has one home.

  2. The fact "the last attempt was REJECTED" was read off the transport
     (TIcomRadio.GetAuthFailed -> FNetworkTransport.AuthFailed), and reacting to
     a rejection FREES that transport.  So by the time the reconnect arm asked,
     the object that knew had been destroyed and the answer was False.  A fact
     about the ATTEMPT cannot live in something the attempt's failure destroys,
     so it is LATCHED here and cleared only by a link that actually came up.

  The interval is reported from DelayMs rather than from a constant, so the
  message and the wait cannot disagree again.

  NOTHING HERE SLEEPS OR LOOKS AT A CLOCK.  The caller owns the wait, in slices,
  so that a credential change or Reset Radio Ports interrupts it -- which is what
  makes the back-off interruptible.  This object is pure state, which is also why
  it is directly testable (test/unit/uTestRadioLinkRetry.pas). *)

{$I tr4w.inc}

interface

type
   TRadioLinkRetry = class(TObject)
   private
      FInitialDelayMs: integer;
      FMaxDelayMs:     integer;
      FAuthDelayMs:    integer;
      FDelayMs:        integer;
      FAuthRejected:   boolean;
      FAuthReported:   boolean;
   public
      constructor Create(const aInitialDelayMs, aMaxDelayMs, aAuthDelayMs: integer);

      (* The radio refused our credentials.  Latched: see the header. *)
      procedure NoteAuthRejected;

      (* True ONCE per run of authentication failures, so the operator is told
        clearly the first time and the retries stay quiet.  A run ends at
        NoteLinkUp. *)
      function TakeAuthReportDue: boolean;

      (* The link reached the radio's own "ready for business" state: clears the
        auth latch and puts the interval back to the initial one.

        Returns whether a failure was standing FOR THIS OBJECT, which is a
        per-attempt fact and deliberately NOT what clears the screen.  A
        corrected password REBUILDS the radio, so the thread that sees the
        successful login is usually not the one that saw the rejection; the
        display state therefore lives on the radio slot
        (RadioObject.LinkFailureShown) and outlives both of us.  Wiring a
        message-clear to this result is the 2026-09-26 defect written again. *)
      function NoteLinkUp: boolean;

      (* The link went away after having been up.  Resets the back-off UNLESS an
        authentication rejection stands, because that rejection is what dropped
        the link. *)
      procedure NoteLinkDropped;

      (* A connection attempt raised.  Exponential, capped -- and never below an
        interval an auth rejection has set. *)
      procedure NoteAttemptFailed;

      property DelayMs: integer read FDelayMs;
      property AuthRejected: boolean read FAuthRejected;
   end;

implementation

constructor TRadioLinkRetry.Create(const aInitialDelayMs, aMaxDelayMs, aAuthDelayMs: integer);
begin
   inherited Create;
   FInitialDelayMs := aInitialDelayMs;
   FMaxDelayMs     := aMaxDelayMs;
   FAuthDelayMs    := aAuthDelayMs;
   FDelayMs        := aInitialDelayMs;
   FAuthRejected   := False;
   FAuthReported   := False;
end;

procedure TRadioLinkRetry.NoteAuthRejected;
begin
   FAuthRejected := True;
   FDelayMs      := FAuthDelayMs;
end;

function TRadioLinkRetry.TakeAuthReportDue: boolean;
begin
   Result := FAuthRejected and (not FAuthReported);
   if Result then
      begin
      FAuthReported := True;
      end;
end;

function TRadioLinkRetry.NoteLinkUp: boolean;
begin
   Result        := FAuthRejected or FAuthReported;
   FAuthRejected := False;
   FAuthReported := False;
   FDelayMs      := FInitialDelayMs;
end;

procedure TRadioLinkRetry.NoteLinkDropped;
begin
   if FAuthRejected then
      begin
      Exit;
      end;
   FDelayMs := FInitialDelayMs;
end;

procedure TRadioLinkRetry.NoteAttemptFailed;
begin
   if FAuthRejected then
      begin
      Exit;
      end;
   FDelayMs := FDelayMs * 2;
   if FDelayMs > FMaxDelayMs then
      begin
      FDelayMs := FMaxDelayMs;
      end;
end;

end.
