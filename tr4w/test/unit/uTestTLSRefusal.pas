unit uTestTLSRefusal;
{$I ..\..\src\tr4w.inc}
(*
  AN HTTPS REQUEST THAT CANNOT BE VERIFIED IS NOT SENT.

  This exists because of a specific defect, found in review (Codex,
  2026-09-11) and not by any test here. uHTTPDownload's ApplyTLSVerification
  was a PROCEDURE: when UseVerifiedTLS could not be configured it logged an
  error and returned, and all three verbs then made the request anyway --
  unverified.

  THE CASE THAT MATTERS IS NOT THE OPT-OUT. An operator who turns checking off
  has chosen that. This fired when they had checking ON and the trusted-root
  bundle was missing, unreadable, or OpenSSL would not load. HamScore posts a
  username and password over that path.

  WHAT THIS FIXTURE IS. The test binary lives in test\unit, and cacert.pem and
  the OpenSSL pair are shipped into target\ -- not next to this exe. So
  verification genuinely CANNOT be set up here, which is the condition under
  test, reproduced by where the binary sits rather than by mocking anything.
  The first test asserts that precondition instead of assuming it, so a future
  change that puts a bundle beside the test exe reports plainly that the
  fixture no longer reproduces the case rather than passing on vacuum.

  WHY THE HOST IS .invalid (RFC 2606). No GET can succeed against it under any
  circumstances, so a passing result cannot mean "the request went out and
  happened to work". And the two outcomes are distinguishable in the REASON: a
  refusal names verification, while a request that was actually attempted
  comes back with a resolve or connect failure.
*)

interface

uses
   SysUtils, fphttpclient, uTR4WTestFramework,
   uTLSTrust, uHTTPDownload, uSettingsRegistry, uSettingsDeclarations;

type
   TTLSRefusalTests = class(TTestCase)
   protected
      procedure Test_VerificationCannotBeSetUpHere;
      procedure Test_AnUnverifiableRequestIsRefused;
      procedure Test_TurningVerificationOffIsStillAWayThrough;
   public
      procedure RunAllTests; override;
   end;

implementation

const
   (* Reserved by RFC 2606: it can never resolve. *)
   UNREACHABLE = 'https://tr4w-tls-refusal-test.invalid/version.json';

   SETTING_KEY = 'network.verifyServerCertificates';

   (* The stable middle of SDownloadCannotVerify. Matching the formatted whole
     would pin the wording of a resourcestring a translator may change. *)
   REFUSAL_MARK = 'could not be verified';

(* Does the reason say the request was REFUSED over verification, as opposed
  to attempted and failed? *)
function ReadsAsARefusal(const aReason: string): boolean;
begin
   Result := Pos(REFUSAL_MARK, aReason) > 0;
end;

procedure TTLSRefusalTests.Test_VerificationCannotBeSetUpHere;
var
   http:   TFPHTTPClient;
   reason: string;
begin
   BeginTest('the fixture: verified TLS cannot be configured beside this exe');

   http := TFPHTTPClient.Create(nil);
   try
      CheckFalse(UseVerifiedTLS(http, reason),
                 'no cacert.pem and no OpenSSL pair sit next to the test '
                 + 'binary, so verification cannot be set up -- if this now '
                 + 'passes, something was copied into test\unit and the two '
                 + 'tests below no longer reproduce the case they exist for');
      CheckTrue(reason <> '', 'and the failure says why');
   finally
      http.Free;
   end;
end;

procedure TTLSRefusalTests.Test_AnUnverifiableRequestIsRefused;
var
   body:   string;
   reason: string;
   s:      TSettingBase;
begin
   BeginTest('an unverifiable request is refused, not sent unverified');

   s := FindSetting(SETTING_KEY);
   if s is TBoolSetting then
      begin
      TBoolSetting(s).SetValue(True);
      end;

   CheckFalse(HttpGetText(UNREACHABLE, body, reason), 'the GET does not succeed');
   CheckTrue(ReadsAsARefusal(reason),
             'and it failed because verification could not be set up, NOT '
             + 'because an unverified request went out and could not connect '
             + '-- reason was: ' + reason);
   CheckEquals('', body, 'nothing came back');
end;

procedure TTLSRefusalTests.Test_TurningVerificationOffIsStillAWayThrough;
var
   body:   string;
   reason: string;
   s:      TSettingBase;
begin
   (* THE ESCAPE HATCH HAS TO KEEP WORKING. Failing closed is only defensible
     because an operator who decides they do not want checking can say so. If
     this ever starts reading as a refusal too, the setting has stopped
     meaning anything. *)
   BeginTest('the explicit opt-out still gets past the refusal');

   s := FindSetting(SETTING_KEY);
   if not (s is TBoolSetting) then
      begin
      CheckTrue(False, SETTING_KEY + ' is not declared as a boolean setting');
      Exit;
      end;

   TBoolSetting(s).SetValue(False);
   try
      (* It still fails -- the host cannot resolve -- but for a TRANSPORT
        reason, which is the distinction being pinned. *)
      CheckFalse(HttpGetText(UNREACHABLE, body, reason), 'the host is unreachable');
      CheckFalse(ReadsAsARefusal(reason),
                 'and it was NOT refused over verification -- reason was: '
                 + reason);
   finally
      TBoolSetting(s).SetValue(True);
   end;
end;

procedure TTLSRefusalTests.RunAllTests;
begin
   (* network.verifyServerCertificates has to EXIST before either of the last
     two tests means anything -- FindSetting returns nil otherwise and the
     opt-out cannot be exercised at all. DeclareAllSettings is idempotent. *)
   DeclareAllSettings;
   Test_VerificationCannotBeSetUpHere;
   Test_AnUnverifiableRequestIsRefused;
   Test_TurningVerificationOffIsStillAWayThrough;
end;

end.
