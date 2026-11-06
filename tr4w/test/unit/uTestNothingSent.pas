unit uTestNothingSent;
{$I ..\..\src\tr4w.inc}
(*
  A REQUEST THAT PROVABLY SENT NOTHING IS NOT "UNCERTAIN" (issue 224, S1b).

  Club Log and World Radio League used to classify by two flags, TlsUnavailable
  and TrustBundleMissing. Other refusals also sent nothing and set neither, so
  they fell through to doUncertain -- which parks a delivery for a human
  (docs/HTTP_TRANSPORT_DESIGN.md 2.3). The clients now classify by
  THttpRequest.NothingSent, and these are the pins for the three paths that
  changed:

     the bearer gate (a token needing https, no redirects, no line break)
     a plaintext or scheme-less URL
     verification that cannot be set up although the bundle is fine

  plus the guard on the other side: a failure that MAY have been sent keeps the
  conservative answer it always had, and the CA-bundle OperatorNotice is raised
  for the trust-unavailable reason and no other.

  THE DECISIONS (the design said "retry / failed"; this is which, and why):

     bearer gate             doRetry, PAUSED, *_AUTH_POLICY. It is the credential
                             class: the worker already turns a 401 into
                             retry-and-stop "for a replacement credential".
                             Nothing is lost, and a retry cannot cure it alone,
                             so the worker stops and says so.
     plaintext / no scheme   doFailed, PAUSED, *_URL_REFUSED. A malformed request:
                             the URL is hard-coded https in both clients, so this
                             is a programming defect, and failing each delivery
                             in turn would burn the queue.
     verification unavailable doRetry, 300 s, *_VERIFICATION_UNAVAILABLE. Cured by
                             an updated OpenSSL or by the operator's own setting
                             (read on every request), so it waits like the bundle.
     any other proved kind   doRetry, 300 s, *_NOT_SENT.
*)

interface

uses
   SysUtils, uTR4WTestFramework;

type
   TNothingSentTests = class(TTestCase)
   protected
      procedure Test_BearerGateIsARetryThatPauses;
      procedure Test_PlaintextAndNoSchemeAreFailedAndPause;
      procedure Test_VerificationUnavailableIsARetryWithoutANotice;
      procedure Test_OnlyTrustUnavailableRaisesTheBundleNotice;
      procedure Test_OtherProvedKindsAreARetry;
      procedure Test_AFailureThatMayHaveBeenSentStaysConservative;
      procedure Test_ExistingCodesAreUnchanged;
   public
      procedure RunAllTests; override;
   end;

implementation

uses
   uHttpTransport, uHTTPDownload, uExternalDelivery, uExternalDeliveryClient,
   uClubLogClient, uWRLClient, uTLSTrust, uSettingsRegistry, uSettingsDeclarations,
   uTestFakeTransport;

const
   TOKEN = 'zq-FAKE-TOKEN-0123456789abcdef';

var
   (* The kind the stub request reports. A unit variable, not a field, so the
     client subclasses below can stay one line. *)
   GStubKind: THttpFailure = hfNone;

type
   (* A request that refuses the way a real one does for GStubKind: no status, no
     body, the kind set. Deterministic whatever this machine has installed. *)
   TKindRequest = class(THttpRequest)
   public
      function Send: boolean; override;
   end;

   TClubKind = class(TClubLogClient)
   protected
      function NewRequest: THttpRequest; override;
   end;

   TWrlKind = class(TWRLClient)
   protected
      function NewRequest(const aURL: string): THttpRequest; override;
   end;

function TKindRequest.Send: boolean;
begin
   Result     := False;
   StatusCode := 0;
   FailReason := 'stub';
   Failure    := GStubKind;
end;

function TClubKind.NewRequest: THttpRequest;
begin
   Result := TKindRequest.Create('https://clublog.org/api/v1/qso');
end;

function TWrlKind.NewRequest(const aURL: string): THttpRequest;
begin
   Result := TKindRequest.Create(aURL);
end;

(* One Club Log delivery and one WRL POST delivery for the same stub kind. *)
procedure DeliverBoth(aKind: THttpFailure; out aClub, aWrl: TExternalDeliveryResult);
var
   club: TClubKind;
   wrl:  TWrlKind;
   job:  TDeliveryJob;
begin
   GStubKind := aKind;
   club := TClubKind.Create('W1AW', TOKEN);
   wrl  := TWrlKind.Create(TOKEN);
   try
      job := Default(TDeliveryJob);
      job.Payload := '<CALL:4>W1AW<EOR>';
      aClub := club.Deliver(job);
      job := Default(TDeliveryJob);
      job.Key.Logbook := 'logbook-1';
      job.Payload := '{"callsign":"W1AW"}';
      aWrl := wrl.Deliver(job);
   finally
      wrl.Free;
      club.Free;
      GStubKind := hfNone;
   end;
end;

procedure TNothingSentTests.Test_BearerGateIsARetryThatPauses;
var
   club: TClubLogClient;
   wrl:  TWRLClient;
   job:  TDeliveryJob;
   a, b: TExternalDeliveryResult;
begin
   BeginTest('the bearer gate (a token with a line break, through the REAL Send) is a paused retry, not uncertain');
   (* A token with a line break is refused by the real gate before any network
     is touched, so no stub is needed: this is the real path end to end. *)
   club := TClubLogClient.Create('W1AW', TOKEN + #13#10'Injected: yes');
   wrl  := TWRLClient.Create(TOKEN + #13#10'Injected: yes');
   try
      job := Default(TDeliveryJob);
      job.Payload := '<CALL:4>W1AW<EOR>';
      a := club.Deliver(job);
      job := Default(TDeliveryJob);
      job.Key.Logbook := 'logbook-1';
      job.Payload := '{"callsign":"W1AW"}';
      b := wrl.Deliver(job);
   finally
      wrl.Free;
      club.Free;
   end;
   CheckTrue(a.Outcome = doRetry, 'Club Log: retry, not uncertain');
   CheckTrue(a.Pause, 'Club Log: the worker stops for the credential');
   CheckEquals('CLUBLOG_AUTH_POLICY', a.ErrorCode, 'Club Log: its own code');
   CheckEquals(0, a.Status, 'Club Log: nothing was sent');
   CheckEquals('', a.OperatorNotice, 'Club Log: no CA-bundle notice');
   CheckTrue(b.Outcome = doRetry, 'WRL: a POST is a retry, not uncertain');
   CheckTrue(b.Pause, 'WRL: the worker stops for the credential');
   CheckEquals('WRL_AUTH_POLICY', b.ErrorCode, 'WRL: its own code');
   CheckEquals(0, b.Status, 'WRL: nothing was sent');
   CheckEquals('', b.OperatorNotice, 'WRL: no CA-bundle notice');
end;

procedure TNothingSentTests.Test_PlaintextAndNoSchemeAreFailedAndPause;
var
   club, wrl: TExternalDeliveryResult;
   kind: THttpFailure;
begin
   BeginTest('a plaintext or scheme-less request is failed (not uncertain), pauses, and has its own code');
   for kind in [hfPlaintextNotAllowed, hfBadScheme] do
      begin
      DeliverBoth(kind, club, wrl);
      CheckTrue(club.Outcome = doFailed, 'Club Log ' + HttpFailureName(kind) + ': failed');
      CheckTrue(club.Pause, 'Club Log: paused');
      CheckEquals('CLUBLOG_URL_REFUSED', club.ErrorCode, 'Club Log: its own code');
      CheckEquals('', club.OperatorNotice, 'Club Log: no notice');
      CheckTrue(wrl.Outcome = doFailed, 'WRL ' + HttpFailureName(kind) + ': a POST is failed, not uncertain');
      CheckTrue(wrl.Pause, 'WRL: paused');
      CheckEquals('WRL_URL_REFUSED', wrl.ErrorCode, 'WRL: its own code');
      CheckEquals('', wrl.OperatorNotice, 'WRL: no notice');
      end;
end;

procedure TNothingSentTests.Test_VerificationUnavailableIsARetryWithoutANotice;
var
   fake: TFakeHttpTransport;
   club: TClubLogClient;
   wrl:  TWRLClient;
   job:  TDeliveryJob;
   a, b: TExternalDeliveryResult;
   setting: TSettingBase;
begin
   BeginTest('verification that cannot be set up (bundle fine), through the REAL Send: a retry, 300 s, no notice');
   DeclareAllSettings;
   setting := FindSetting('network.verifyServerCertificates');
   if setting is TBoolSetting then
      begin
      TBoolSetting(setting).SetValue(True);
      end;
   ResetTrustBundleLatches;
   fake := TFakeHttpTransport.Create;
   fake.ScriptFailure      := hfVerificationUnavailable;
   fake.ScriptErrorMessage := 'test-only: no X509_check_host';
   SetHttpTransportForTest(fake);
   club := TClubLogClient.Create('W1AW', TOKEN);
   wrl  := TWRLClient.Create(TOKEN);
   try
      job := Default(TDeliveryJob);
      job.Payload := '<CALL:4>W1AW<EOR>';
      a := club.Deliver(job);
      job := Default(TDeliveryJob);
      job.Key.Logbook := 'logbook-1';
      job.Payload := '{"callsign":"W1AW"}';
      b := wrl.Deliver(job);
   finally
      wrl.Free;
      club.Free;
      SetHttpTransportForTest(nil);
      fake.Free;
   end;
   CheckTrue(a.Outcome = doRetry, 'Club Log: retry, not uncertain');
   CheckFalse(a.Pause, 'Club Log: not paused for review');
   CheckEquals('CLUBLOG_VERIFICATION_UNAVAILABLE', a.ErrorCode, 'Club Log: its own code');
   CheckEquals(300, a.RetrySeconds, 'Club Log: 300 s like the other setup problems');
   CheckEquals(0, a.Status, 'Club Log: nothing was sent');
   CheckEquals('', a.OperatorNotice, 'Club Log: the CA bundle is fine, so no CA-bundle notice');
   CheckTrue(b.Outcome = doRetry, 'WRL: a POST is a retry, not uncertain');
   CheckEquals('WRL_VERIFICATION_UNAVAILABLE', b.ErrorCode, 'WRL: its own code');
   CheckEquals(300, b.RetrySeconds, 'WRL: 300 s');
   CheckEquals('', b.OperatorNotice, 'WRL: no notice');
end;

procedure TNothingSentTests.Test_OnlyTrustUnavailableRaisesTheBundleNotice;
var
   club, wrl: TExternalDeliveryResult;
   kind: THttpFailure;
begin
   BeginTest('the CA-bundle OperatorNotice is raised for hfTrustUnavailable and for no other kind');
   for kind := Low(THttpFailure) to High(THttpFailure) do
      begin
      ResetTrustBundleLatches;
      DeliverBoth(kind, club, wrl);
      if kind = hfTrustUnavailable then
         begin
         CheckTrue(Pos('Club Log', club.OperatorNotice) > 0, 'Club Log is told, naming itself');
         CheckTrue(Pos('World Radio League', wrl.OperatorNotice) > 0, 'WRL is told, naming itself');
         end
      else
         begin
         CheckEquals('', club.OperatorNotice, 'Club Log, ' + HttpFailureName(kind) + ': no notice');
         CheckEquals('', wrl.OperatorNotice, 'WRL, ' + HttpFailureName(kind) + ': no notice');
         end;
      end;
   ResetTrustBundleLatches;
end;

procedure TNothingSentTests.Test_OtherProvedKindsAreARetry;
var
   club, wrl: TExternalDeliveryResult;
   kind: THttpFailure;
begin
   BeginTest('any other kind that proves nothing was sent (connect failed, name not resolved, certificate rejected) is a retry');
   for kind in [hfNameNotResolved, hfCannotConnect, hfConnectTimedOut, hfVerificationFailed] do
      begin
      DeliverBoth(kind, club, wrl);
      CheckTrue(club.Outcome = doRetry, 'Club Log ' + HttpFailureName(kind) + ': retry');
      CheckFalse(club.Pause, 'Club Log: not paused');
      CheckEquals('CLUBLOG_NOT_SENT', club.ErrorCode, 'Club Log: code');
      CheckEquals(300, club.RetrySeconds, 'Club Log: 300 s');
      CheckTrue(wrl.Outcome = doRetry, 'WRL ' + HttpFailureName(kind) + ': a POST is a retry, not uncertain');
      CheckEquals('WRL_NOT_SENT', wrl.ErrorCode, 'WRL: code');
      end;
end;

procedure TNothingSentTests.Test_AFailureThatMayHaveBeenSentStaysConservative;
var
   club, wrl: TExternalDeliveryResult;
   kind: THttpFailure;
begin
   BeginTest('a failure that may have been sent keeps the conservative answer: uncertain for a POST');
   for kind in [hfNone, hfOther, hfConnectionLost, hfIOTimedOut, hfTlsLibraryFault,
                hfResponseTooLarge, hfCancelled] do
      begin
      DeliverBoth(kind, club, wrl);
      CheckTrue(club.Outcome = doUncertain, 'Club Log ' + HttpFailureName(kind) + ': uncertain');
      CheckTrue(club.Pause, 'Club Log: needs review');
      CheckEquals('CLUBLOG_RESPONSE_REQUIRES_REVIEW', club.ErrorCode, 'Club Log: code');
      CheckTrue(wrl.Outcome = doUncertain, 'WRL ' + HttpFailureName(kind) + ': a POST is uncertain');
      CheckEquals('DELIVERY_UNCONFIRMED', wrl.ErrorCode, 'WRL: code');
      end;
end;

procedure TNothingSentTests.Test_ExistingCodesAreUnchanged;
var
   club, wrl: TExternalDeliveryResult;
begin
   BeginTest('the two classifications issue 221 built are unchanged: TLS unavailable and a missing bundle');
   DeliverBoth(hfTlsUnavailable, club, wrl);
   CheckTrue(club.Outcome = doRetry, 'Club Log TLS: retry');
   CheckFalse(club.Pause, 'Club Log TLS: not paused');
   CheckEquals('CLUBLOG_TLS_UNAVAILABLE', club.ErrorCode, 'Club Log TLS: code');
   CheckEquals(300, club.RetrySeconds, 'Club Log TLS: 300 s');
   CheckEquals('WRL_TLS_UNAVAILABLE', wrl.ErrorCode, 'WRL TLS: code');
   CheckEquals(300, wrl.RetrySeconds, 'WRL TLS: 300 s');
   ResetTrustBundleLatches;
   DeliverBoth(hfTrustUnavailable, club, wrl);
   CheckTrue(club.Outcome = doRetry, 'Club Log bundle: retry');
   CheckFalse(club.Pause, 'Club Log bundle: not paused');
   CheckEquals('CLUBLOG_CA_BUNDLE_MISSING', club.ErrorCode, 'Club Log bundle: code');
   CheckEquals('WRL_CA_BUNDLE_MISSING', wrl.ErrorCode, 'WRL bundle: code');
   CheckEquals(300, wrl.RetrySeconds, 'WRL bundle: 300 s');
   ResetTrustBundleLatches;
end;

procedure TNothingSentTests.RunAllTests;
begin
   Test_BearerGateIsARetryThatPauses;
   Test_PlaintextAndNoSchemeAreFailedAndPause;
   Test_VerificationUnavailableIsARetryWithoutANotice;
   Test_OnlyTrustUnavailableRaisesTheBundleNotice;
   Test_OtherProvedKindsAreARetry;
   Test_AFailureThatMayHaveBeenSentStaysConservative;
   Test_ExistingCodesAreUnchanged;
end;

end.
