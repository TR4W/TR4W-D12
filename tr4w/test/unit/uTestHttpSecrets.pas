unit uTestHttpSecrets;
{$I ..\..\src\tr4w.inc}
(*
  A CREDENTIAL NEVER REACHES A LOG, AND TLS THAT CANNOT START IS NOT "UNCERTAIN".

  NY4I, 2026-11-05: the HTTP layer logs the URL and the exception of a failed
  request -- credentialed or not -- and masks the bearer token. What makes that
  safe is uHTTPDownload.ScrubSecret, and what pins it is here: a fake token is
  pushed through every line the layer writes, the lines are captured with a
  Log4D appender, and the token must appear in none of them.

  The success trace of a BEARER request cannot be driven end to end here: a
  bearer request must be https, and the test binary has no OpenSSL beside it.
  RequestTraceLine, the one function that builds that line, is tested directly,
  and Send's use of it is covered by the non-bearer request below.

  TLS unavailable is forced through SetOpenSSLForcedUnavailable so the test does
  not depend on what the machine has installed.
*)

interface

uses
   SysUtils, Classes, Log4D, uTR4WTestFramework;

type
   THttpSecretsTests = class(TTestCase)
   protected
      procedure Test_MaskSecret;
      procedure Test_ScrubSecret;
      procedure Test_DebugLogsTheRequestWeSendWithoutSecrets;
      procedure Test_NothingReceivedIsEverLogged;
      procedure Test_FailureLineScrubsAnEchoedToken;
      procedure Test_TraceLineMasksTheBearerToken;
      procedure Test_SendNeverLogsTheTokenOnATransportFailure;
      procedure Test_TlsUnavailableNeverLogsTheTokenAndLogsOnce;
      procedure Test_TlsUnavailableIsARetryNotUncertain;
      procedure Test_WrlTlsUnavailableIsARetryNotUncertain;
      procedure Test_BundleLookupOrder;
      procedure Test_NoBundleSetsTheFlagLogsOnceAndKeepsTheTokenOut;
      procedure Test_ClubLogMissingBundleIsARetryAndAlertsOnce;
      procedure Test_WrlMissingBundleIsARetryAndAlertsOnce;
      procedure Test_AlertIsOncePerService;
   public
      procedure RunAllTests; override;
   end;

implementation

uses
   fphttpclient, uHTTPDownload, uOpenSSLLoader, uExternalDelivery, uExternalDeliveryClient, uClubLogClient, uWRLClient,
   uTLSTrust, uSettingsRegistry, uSettingsDeclarations, uHttpTransport,
   uTestFakeTransport;

const
   (* Long enough for the mask to show two characters, and distinctive enough
     that its absence from a line means something. *)
   TOKEN = 'zq-FAKE-TOKEN-0123456789abcdef';
   PASSWORD = 'pw-FAKE-PASSWORD-9876543210';

type
   TCaptureAppender = class(TLogCustomAppender)
   protected
      procedure DoAppend(const aMessage: string); override;
   end;

   (* A request that behaves as the real one does when cacert.pem is missing:
     refused, nothing sent, no status. Deterministic whatever this machine has
     installed. *)
   TNoBundleRequest = class(THttpRequest)
   public
      function Send: boolean; override;
   end;

   TClubNoBundle = class(TClubLogClient)
   protected
      function NewRequest: THttpRequest; override;
   end;

   TWrlNoBundle = class(TWRLClient)
   protected
      function NewRequest(const aURL: string): THttpRequest; override;
   end;

function TNoBundleRequest.Send: boolean;
begin
   Result := False;
   StatusCode := 0;
   FailReason := 'stub: no bundle';
   TrustBundleMissing := True;
end;

function TClubNoBundle.NewRequest: THttpRequest;
begin
   Result := TNoBundleRequest.Create('https://clublog.org/api/v1/qso');
end;

function TWrlNoBundle.NewRequest(const aURL: string): THttpRequest;
begin
   Result := TNoBundleRequest.Create(aURL);
end;

(* A fresh empty folder under the temp directory, with a trailing separator. *)
function MakeTempFolder: string;
begin
   Result := IncludeTrailingPathDelimiter(GetTempDir(False)) + 'tr4w-cabundle-'
             + IntToStr(Random(100000000)) + PathDelim;
   ForceDirectories(Result);
end;

procedure PutBundle(const aFolder: string);
var
   f: TStringList;
begin
   f := TStringList.Create;
   try
      f.Add('not a real bundle');
      f.SaveToFile(aFolder + 'cacert.pem');
   finally
      f.Free;
   end;
end;

procedure RemoveTempFolder(const aFolder: string);
begin
   SysUtils.DeleteFile(aFolder + 'cacert.pem');
   RemoveDir(aFolder);
end;

var
   GCaptured: TStringList = nil;

procedure TCaptureAppender.DoAppend(const aMessage: string);
begin
   if (GCaptured <> nil) and (Trim(aMessage) <> '') then
      begin
      GCaptured.Add(aMessage);
      end;
end;

function CountLinesWith(const aMark: string): integer;
var
   i: integer;
begin
   Result := 0;
   for i := 0 to GCaptured.Count - 1 do
      begin
      if Pos(aMark, GCaptured[i]) > 0 then
         begin
         Inc(Result);
         end;
      end;
end;

(* Attach a capture to the HTTP layer's logger at every level. *)
procedure StartCapture(out aLogger: TLogLogger; out aAppender: ILogAppender;
                       out aOldLevel: TLogLevel);
begin
   GCaptured.Clear;
   aLogger   := TLogLogger.GetLogger('TR4WDebugLog.Download');
   aOldLevel := aLogger.Level;
   aLogger.Level := All;
   aAppender := TCaptureAppender.Create('unit-test http capture');
   aLogger.AddAppender(aAppender);
end;

procedure StopCapture(aLogger: TLogLogger; const aAppender: ILogAppender;
                      aOldLevel: TLogLevel);
begin
   aLogger.RemoveAppender(aAppender);
   aLogger.Level := aOldLevel;
end;

procedure THttpSecretsTests.Test_MaskSecret;
begin
   BeginTest('MaskSecret: a fixed ********, no prefix and no length');
   CheckEquals('********', MaskSecret('ab' + StringOfChar('x', 34)),
               'a long secret shows nothing of itself');
   CheckEquals('********', MaskSecret('abc'), 'a short secret is the same');
   CheckEquals('********', MaskSecret('a'), 'one character too');
   CheckEquals('(empty)', MaskSecret(''), 'an empty secret says so');
end;

(* Turn certificate checking on, as an operator's default, so an https request
  reaches the fake transport rather than being decided by this machine. *)
procedure DeclareVerifyOn;
var
   setting: TSettingBase;
begin
   DeclareAllSettings;
   setting := FindSetting('network.verifyServerCertificates');
   if setting is TBoolSetting then
      begin
      TBoolSetting(setting).SetValue(True);
      end;
end;

procedure THttpSecretsTests.Test_DebugLogsTheRequestWeSendWithoutSecrets;
var
   lg:       TLogLogger;
   keep:     ILogAppender;
   oldLevel: TLogLevel;
   fake:     TFakeHttpTransport;
   request:  THttpRequest;
   joined:   string;
begin
   BeginTest('DEBUG logs method, URL, headers and body; no bearer token, no password');
   DeclareVerifyOn;
   fake := TFakeHttpTransport.Create;
   SetHttpTransportForTest(fake);
   StartCapture(lg, keep, oldLevel);
   try
      request := THttpRequest.Create('https://api.invalid/v1/contacts?k=' + TOKEN);
      try
         request.Method      := 'POST';
         request.ContentType := 'application/json';
         request.UserAgent   := 'TR4W-test';
         request.BearerToken := TOKEN;
         request.Username    := 'someone';
         request.Password    := PASSWORD;
         request.Body        := '{"callsign":"W1AW","key":"' + TOKEN + '","pw":"' + PASSWORD + '"}';
         CheckTrue(request.Send, 'an answer: ' + request.FailReason);
      finally
         request.Free;
      end;
      (* And a failure whose error text echoes both secrets. *)
      fake.ScriptFailure      := hfOther;
      fake.ScriptErrorClass   := 'Exception';
      fake.ScriptErrorMessage := 'bad ' + TOKEN + ' and ' + PASSWORD;
      request := THttpRequest.Create('https://api.invalid/v1/contacts');
      try
         request.BearerToken := TOKEN;
         request.Password    := PASSWORD;
         CheckFalse(request.Send, 'the failure is reported');
         CheckEquals(0, Pos(TOKEN, request.FailReason), 'no token in the reason');
         CheckEquals(0, Pos(PASSWORD, request.FailReason), 'no password in the reason');
      finally
         request.Free;
      end;
   finally
      StopCapture(lg, keep, oldLevel);
      SetHttpTransportForTest(nil);
      fake.Free;
   end;
   joined := GCaptured.Text;
   CheckEquals(0, Pos(TOKEN, joined), 'the token is in none of the lines: ' + joined);
   CheckEquals(0, Pos(PASSWORD, joined), 'the password is in none of the lines: ' + joined);
   CheckTrue(Pos('[HTTP] request POST https://api.invalid/v1/contacts?k=********', joined) > 0,
             'method and URL, scrubbed: ' + joined);
   CheckTrue(Pos('Authorization: Bearer ********', joined) > 0, 'the bearer header, starred');
   CheckTrue(Pos('User-Agent: TR4W-test', joined) > 0, 'User-Agent');
   CheckTrue(Pos('Content-Type: application/json', joined) > 0, 'Content-Type');
   CheckTrue(Pos('Authorization: Basic someone:********', joined) > 0, 'the basic header, starred');
   CheckTrue(Pos('Body: {"callsign":"W1AW","key":"********","pw":"********"}', joined) > 0,
             'the body, scrubbed');
   CheckEquals(2, CountLinesWith('[HTTP] request'), 'two requests, one request line each');
end;

procedure THttpSecretsTests.Test_NothingReceivedIsEverLogged;
var
   lg:       TLogLogger;
   keep:     ILogAppender;
   oldLevel: TLogLevel;
   fake:     TFakeHttpTransport;
   request:  THttpRequest;
   text, reason: string;
   ok:       boolean;
begin
   BeginTest('a response body and headers never reach the logger, at any level');
   DeclareVerifyOn;
   fake := TFakeHttpTransport.Create;
   fake.ScriptStatus     := 400;
   fake.ScriptStatusText := 'STATUSTEXT-MARKER';
   fake.ScriptRetryAfter := 'RETRYAFTER-MARKER';
   fake.ScriptRequestId  := 'REQUESTID-MARKER';
   fake.ScriptBody       := ToWire('RESPONSEBODY-MARKER');
   SetHttpTransportForTest(fake);
   StartCapture(lg, keep, oldLevel);
   try
      request := THttpRequest.Create('https://api.invalid/v1/x');
      try
         request.BearerToken := TOKEN;
         CheckTrue(request.Send, 'a 400 is an answer');
         CheckEquals('RESPONSEBODY-MARKER', request.Response, 'the caller still gets it');
      finally
         request.Free;
      end;
      ok := HttpGetText('https://api.invalid/v1/y', text, reason);
      CheckTrue(ok, 'the GET verb answers too');
      CheckEquals('RESPONSEBODY-MARKER', text, 'and returns the text');
   finally
      StopCapture(lg, keep, oldLevel);
      SetHttpTransportForTest(nil);
      fake.Free;
   end;
   CheckTrue(GCaptured.Count > 0, 'the requests themselves were logged');
   CheckEquals(0, Pos('MARKER', GCaptured.Text), 'nothing received is logged: ' + GCaptured.Text);
end;

procedure THttpSecretsTests.Test_ScrubSecret;
var
   masked: string;
begin
   BeginTest('ScrubSecret: raw and URL-encoded occurrences, empty is a no-op');
   masked := MaskSecret('a b/c+d=e&f-secret');
   CheckEquals('x ' + masked + ' y ' + masked,
               ScrubSecret('x a b/c+d=e&f-secret y a b/c+d=e&f-secret', 'a b/c+d=e&f-secret'),
               'every raw occurrence goes');
   CheckEquals('?k=' + masked,
               ScrubSecret('?k=' + UTF8Decode(EncodeURLElement(UTF8Encode('a b/c+d=e&f-secret'))),
                           'a b/c+d=e&f-secret'),
               'the URL-encoded form goes too');
   CheckEquals('nothing to hide', ScrubSecret('nothing to hide', ''),
               'an empty secret leaves the text alone');
   CheckEquals('', ScrubSecret('', TOKEN), 'empty text stays empty');
end;

procedure THttpSecretsTests.Test_FailureLineScrubsAnEchoedToken;
var
   e:    Exception;
   line: string;
begin
   BeginTest('a server error text that echoes the token is scrubbed');
   e := Exception.Create('400 Bad Request: invalid key ' + TOKEN + ' for user');
   try
      line := RequestFailureLine('POST', 'https://example.invalid/api?key=' + TOKEN,
                                 e, TOKEN, '');
   finally
      e.Free;
   end;
   CheckEquals(0, Pos(TOKEN, line), 'the token is nowhere in: ' + line);
   CheckTrue(Pos('POST https://example.invalid/api', line) = 1, 'method and URL are logged');
   CheckTrue(Pos('Exception', line) > 0, 'the exception class is logged');
   CheckTrue(Pos('invalid key', line) > 0, 'and the message, around the mask');
end;

procedure THttpSecretsTests.Test_TraceLineMasksTheBearerToken;
var
   line: string;
begin
   BeginTest('the trace line shows the URL and a masked bearer token');
   line := RequestTraceLine('POST', 'https://clublog.org/api/v1/qso', TOKEN, '');
   CheckEquals('POST https://clublog.org/api/v1/qso Authorization: Bearer '
               + MaskSecret(TOKEN), line, 'method, URL, masked token');
   CheckEquals(0, Pos(TOKEN, line), 'and not the token');
   line := RequestTraceLine('GET', 'https://h/x?k=' + TOKEN, TOKEN, '');
   CheckEquals(0, Pos(TOKEN, line), 'a token that strayed into the URL is scrubbed');
end;

procedure THttpSecretsTests.Test_SendNeverLogsTheTokenOnATransportFailure;
var
   lg:       TLogLogger;
   keep:     ILogAppender;
   oldLevel: TLogLevel;
   request:  THttpRequest;
   joined:      string;
begin
   BeginTest('a real failing Send logs the URL and nothing of the secret');
   StartCapture(lg, keep, oldLevel);
   try
      (* A closed loopback port refuses at once. Sensitive + Password stand in
        for the credential; the token also rides in the URL so the scrub has
        something to do. *)
      request := THttpRequest.Create('http://127.0.0.1:1/probe?k=' + TOKEN);
      try
         request.Method         := 'POST';
         request.Password       := TOKEN;
         request.Username       := 'user';
         request.Sensitive      := True;
         request.AllowInsecure  := True;
         request.ConnectMs      := 2000;
         request.IOMs           := 2000;
         CheckFalse(request.Send, 'the connection is refused');
         CheckFalse(request.TlsUnavailable, 'and that is not a TLS problem');
         CheckEquals(0, Pos(TOKEN, request.FailReason), 'the reason carries no token');
      finally
         request.Free;
      end;
   finally
      StopCapture(lg, keep, oldLevel);
   end;
   joined := GCaptured.Text;
   CheckTrue(GCaptured.Count >= 2, 'a trace line and a failure line were written');
   CheckEquals(0, Pos(TOKEN, joined), 'the token is in none of the lines: ' + joined);
   CheckTrue(Pos('127.0.0.1:1/probe', joined) > 0, 'the URL is logged');
end;

procedure THttpSecretsTests.Test_TlsUnavailableNeverLogsTheTokenAndLogsOnce;
var
   lg:       TLogLogger;
   keep:     ILogAppender;
   oldLevel: TLogLevel;
   request:  THttpRequest;
   i, tlsLines: integer;
   joined:      string;
begin
   BeginTest('TLS unavailable: no token in the log, and the diagnostic once');
   SetOpenSSLForcedUnavailable('test-only: forced unavailable ' + IntToStr(Random(1000000)));
   StartCapture(lg, keep, oldLevel);
   try
      for i := 1 to 3 do
         begin
         request := THttpRequest.Create('https://tr4w-http-secrets.invalid/p?k=' + TOKEN);
         try
            request.BearerToken := TOKEN;
            CheckFalse(request.Send, 'the request is refused');
            CheckTrue(request.TlsUnavailable, 'and flagged as TLS unavailable');
            CheckEquals(0, request.StatusCode, 'no answer');
            CheckEquals(0, Pos(TOKEN, request.FailReason), 'no token in the reason');
         finally
            request.Free;
         end;
         end;
   finally
      StopCapture(lg, keep, oldLevel);
      SetOpenSSLForcedUnavailable('');
   end;
   joined := GCaptured.Text;
   CheckEquals(0, Pos(TOKEN, joined), 'the token is in none of the lines: ' + joined);
   tlsLines := 0;
   for i := 0 to GCaptured.Count - 1 do
      begin
      if Pos('TLS unavailable', GCaptured[i]) > 0 then
         begin
         Inc(tlsLines);
         end;
      end;
   CheckEquals(1, tlsLines, 'three refused requests, one diagnostic line');
end;

procedure THttpSecretsTests.Test_TlsUnavailableIsARetryNotUncertain;
var
   client: TClubLogClient;
   job:    TDeliveryJob;
   answer: TExternalDeliveryResult;
begin
   BeginTest('Club Log: TLS unavailable is a retry with its own code, not uncertain');
   SetOpenSSLForcedUnavailable('test-only: forced unavailable for classification');
   client := TClubLogClient.Create('W1AW', TOKEN);
   try
      job := Default(TDeliveryJob);
      job.Payload := '<CALL:4>W1AW<EOR>';
      answer := client.Deliver(job);
   finally
      client.Free;
      SetOpenSSLForcedUnavailable('');
   end;
   CheckTrue(answer.Outcome = doRetry, 'outcome is retry, not uncertain or failed');
   CheckFalse(answer.Pause, 'the worker is not paused for review');
   CheckEquals('CLUBLOG_TLS_UNAVAILABLE', answer.ErrorCode, 'with its own error code');
   CheckEquals(0, answer.Status, 'no HTTP status: nothing was sent');
   CheckTrue(answer.RetrySeconds > 0, 'and a retry delay');
end;

procedure THttpSecretsTests.Test_WrlTlsUnavailableIsARetryNotUncertain;
var
   client: TWRLClient;
   job:    TDeliveryJob;
   answer: TExternalDeliveryResult;
begin
   BeginTest('WRL: a POST with TLS unavailable is a retry, not uncertain');
   SetOpenSSLForcedUnavailable('test-only: forced unavailable for WRL classification');
   client := TWRLClient.Create(TOKEN);
   try
      job := Default(TDeliveryJob);
      job.Key.Logbook := 'logbook-1';
      job.Payload := '{"callsign":"W1AW"}';
      answer := client.Deliver(job);
   finally
      client.Free;
      SetOpenSSLForcedUnavailable('');
   end;
   CheckTrue(answer.Outcome = doRetry, 'a POST is retried: nothing was sent');
   CheckEquals('WRL_TLS_UNAVAILABLE', answer.ErrorCode, 'with its own error code');
   CheckEquals(0, answer.Status, 'no HTTP status');
end;

procedure THttpSecretsTests.Test_BundleLookupOrder;
var
   dataDir, progDir, missingDir: string;
begin
   BeginTest('cacert.pem: data directory first, the program folder as a fallback, else none');
   dataDir    := MakeTempFolder;
   progDir    := MakeTempFolder;
   missingDir := MakeTempFolder;
   try
      SetTrustBundleFolders(dataDir, progDir);

      CheckFalse(TrustBundleUsable, 'neither folder has the file');
      CheckEquals(dataDir + 'cacert.pem', TrustBundlePath,
                  'and the path named is the data directory''s');
      CheckTrue(Pos(dataDir + 'cacert.pem', TrustBundleSearchPlaces) > 0, 'the places list the data folder');
      CheckTrue(Pos(progDir + 'cacert.pem', TrustBundleSearchPlaces) > 0, 'and the program folder');

      PutBundle(progDir);
      CheckTrue(TrustBundleUsable, 'only beside the program: usable');
      CheckEquals(progDir + 'cacert.pem', TrustBundlePath, 'and that is the one used');

      PutBundle(dataDir);
      CheckEquals(dataDir + 'cacert.pem', TrustBundlePath, 'both: the data directory wins');

      SysUtils.DeleteFile(dataDir + 'cacert.pem');
      CheckEquals(progDir + 'cacert.pem', TrustBundlePath, 'removed again: back to the program folder');

      (* The same folder twice is one place, not two. *)
      SetTrustBundleFolders(progDir, progDir);
      CheckEquals(progDir + 'cacert.pem', TrustBundleSearchPlaces, 'a repeated folder is listed once');

      SetTrustBundleFolders(missingDir, '');
      CheckFalse(TrustBundleUsable, 'a single empty folder: none');
   finally
      SetTrustBundleFolders('', '');
      RemoveTempFolder(dataDir);
      RemoveTempFolder(progDir);
      RemoveTempFolder(missingDir);
   end;
end;

procedure THttpSecretsTests.Test_NoBundleSetsTheFlagLogsOnceAndKeepsTheTokenOut;
var
   lg:       TLogLogger;
   keep:     ILogAppender;
   oldLevel: TLogLevel;
   request:  THttpRequest;
   emptyA, emptyB: string;
   i:        integer;
   joined:   string;
begin
   BeginTest('no bundle: Send sets TrustBundleMissing, nothing is sent, one Error line, no token');
   DeclareVerifyOn;
   emptyA := MakeTempFolder;
   emptyB := MakeTempFolder;
   SetTrustBundleFolders(emptyA, emptyB);
   StartCapture(lg, keep, oldLevel);
   try
      for i := 1 to 3 do
         begin
         request := THttpRequest.Create('https://tr4w-http-secrets.invalid/p?k=' + TOKEN);
         try
            request.BearerToken := TOKEN;
            CheckFalse(request.Send, 'the request is refused');
            if EnsureOpenSSL then
               begin
               CheckTrue(request.TrustBundleMissing, 'and flagged as a missing bundle');
               CheckFalse(request.TlsUnavailable, 'which is not TLS unavailable');
               end
            else
               begin
               (* This machine cannot load OpenSSL at all, which is the other
                 nothing-sent case; the bundle is never reached. *)
               CheckTrue(request.TlsUnavailable, 'no OpenSSL here: TLS unavailable instead');
               end;
            CheckEquals(0, request.StatusCode, 'no answer');
            CheckEquals(0, Pos(TOKEN, request.FailReason), 'no token in the reason');
         finally
            request.Free;
         end;
         end;
   finally
      StopCapture(lg, keep, oldLevel);
      SetTrustBundleFolders('', '');
      RemoveTempFolder(emptyA);
      RemoveTempFolder(emptyB);
   end;
   joined := GCaptured.Text;
   CheckEquals(0, Pos(TOKEN, joined), 'the token is in none of the lines: ' + joined);
   if EnsureOpenSSL then
      begin
      CheckEquals(1, CountLinesWith('[HTTP] REFUSING'),
                  'three refused requests, one Error line');
      end;
end;

procedure THttpSecretsTests.Test_ClubLogMissingBundleIsARetryAndAlertsOnce;
var
   client: TClubNoBundle;
   job:    TDeliveryJob;
   first, second: TExternalDeliveryResult;
begin
   BeginTest('Club Log: a missing bundle is a retry with its own code, and the operator hears once');
   ResetTrustBundleLatches;
   client := TClubNoBundle.Create('W1AW', TOKEN);
   try
      job := Default(TDeliveryJob);
      job.Payload := '<CALL:4>W1AW<EOR>';
      first  := client.Deliver(job);
      second := client.Deliver(job);
   finally
      client.Free;
   end;
   CheckTrue(first.Outcome = doRetry, 'outcome is retry, not uncertain or failed');
   CheckFalse(first.Pause, 'the worker is not paused for review');
   CheckEquals('CLUBLOG_CA_BUNDLE_MISSING', first.ErrorCode, 'with its own error code');
   CheckEquals(0, first.Status, 'no HTTP status: nothing was sent');
   CheckEquals(300, first.RetrySeconds, 'and the same 300 s as TLS unavailable');
   CheckTrue(Pos('cacert.pem', first.OperatorNotice) > 0, 'the first answer carries the notice');
   CheckTrue(Pos('Club Log', first.OperatorNotice) > 0, 'naming the service');
   CheckEquals(0, Pos(TOKEN, first.OperatorNotice), 'and no token');
   CheckEquals('', second.OperatorNotice, 'the second answer carries none');
   CheckEquals('CLUBLOG_CA_BUNDLE_MISSING', second.ErrorCode, 'though it is classified the same');
   ResetTrustBundleLatches;
end;

procedure THttpSecretsTests.Test_WrlMissingBundleIsARetryAndAlertsOnce;
var
   client: TWrlNoBundle;
   job:    TDeliveryJob;
   first, second: TExternalDeliveryResult;
begin
   BeginTest('WRL: a POST with a missing bundle is a retry, and the operator hears once');
   ResetTrustBundleLatches;
   client := TWrlNoBundle.Create(TOKEN);
   try
      job := Default(TDeliveryJob);
      job.Key.Logbook := 'logbook-1';
      job.Payload := '{"callsign":"W1AW"}';
      first  := client.Deliver(job);
      second := client.Deliver(job);
   finally
      client.Free;
   end;
   CheckTrue(first.Outcome = doRetry, 'a POST is retried: nothing was sent');
   CheckEquals('WRL_CA_BUNDLE_MISSING', first.ErrorCode, 'with its own error code');
   CheckEquals(0, first.Status, 'no HTTP status');
   CheckEquals(300, first.RetrySeconds, 'and 300 s');
   CheckTrue(Pos('World Radio League', first.OperatorNotice) > 0, 'the first answer names the service');
   CheckEquals(0, Pos(TOKEN, first.OperatorNotice), 'and no token');
   CheckEquals('', second.OperatorNotice, 'the second answer carries none');
   ResetTrustBundleLatches;
end;

procedure THttpSecretsTests.Test_AlertIsOncePerService;
var
   lg:       TLogLogger;
   keep:     ILogAppender;
   oldLevel: TLogLevel;
   dataDir, progDir, text: string;
begin
   BeginTest('the alert text names the places looked and the service, once each, and is logged once');
   dataDir := MakeTempFolder;
   progDir := MakeTempFolder;
   SetTrustBundleFolders(dataDir, progDir);
   ResetTrustBundleLatches;
   StartCapture(lg, keep, oldLevel);
   try
      text := TrustBundleAlertText('Club Log');
      CheckTrue(Pos(dataDir + 'cacert.pem', text) > 0, 'the data location is named');
      CheckTrue(Pos(progDir + 'cacert.pem', text) > 0, 'and the program location');
      CheckTrue(Pos('uploads to Club Log are paused', text) > 0, 'and what is paused');
      CheckEquals('', TrustBundleAlertText('Club Log'), 'the same service again: nothing');
      CheckEquals('', TrustBundleAlertText('Club Log'), 'and again');
      CheckTrue(TrustBundleAlertText('World Radio League') <> '', 'another service is told');
   finally
      StopCapture(lg, keep, oldLevel);
      ResetTrustBundleLatches;
      SetTrustBundleFolders('', '');
      RemoveTempFolder(dataDir);
      RemoveTempFolder(progDir);
   end;
   CheckEquals(2, CountLinesWith('cacert.pem was not found'), 'two services, two log lines, no repeats');
end;

procedure THttpSecretsTests.RunAllTests;
begin
   GCaptured := TStringList.Create;
   try
      Test_MaskSecret;
      Test_ScrubSecret;
      Test_DebugLogsTheRequestWeSendWithoutSecrets;
      Test_NothingReceivedIsEverLogged;
      Test_FailureLineScrubsAnEchoedToken;
      Test_TraceLineMasksTheBearerToken;
      Test_SendNeverLogsTheTokenOnATransportFailure;
      Test_TlsUnavailableNeverLogsTheTokenAndLogsOnce;
      Test_TlsUnavailableIsARetryNotUncertain;
      Test_WrlTlsUnavailableIsARetryNotUncertain;
      Test_BundleLookupOrder;
      Test_NoBundleSetsTheFlagLogsOnceAndKeepsTheTokenOut;
      Test_ClubLogMissingBundleIsARetryAndAlertsOnce;
      Test_WrlMissingBundleIsARetryAndAlertsOnce;
      Test_AlertIsOncePerService;
   finally
      FreeAndNil(GCaptured);
   end;
end;

end.
