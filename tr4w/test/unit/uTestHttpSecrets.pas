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
      procedure Test_FailureLineScrubsAnEchoedToken;
      procedure Test_TraceLineMasksTheBearerToken;
      procedure Test_SendNeverLogsTheTokenOnATransportFailure;
      procedure Test_TlsUnavailableNeverLogsTheTokenAndLogsOnce;
      procedure Test_TlsUnavailableIsARetryNotUncertain;
      procedure Test_WrlTlsUnavailableIsARetryNotUncertain;
   public
      procedure RunAllTests; override;
   end;

implementation

uses
   fphttpclient, uHTTPDownload, uOpenSSLLoader, uExternalDelivery, uExternalDeliveryClient, uClubLogClient, uWRLClient;

const
   (* Long enough for the mask to show two characters, and distinctive enough
     that its absence from a line means something. *)
   TOKEN = 'zq-FAKE-TOKEN-0123456789abcdef';

type
   TCaptureAppender = class(TLogCustomAppender)
   protected
      procedure DoAppend(const aMessage: string); override;
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
   BeginTest('MaskSecret: two characters and a length, less for a short secret');
   CheckEquals('ab...(36 chars)', MaskSecret('ab' + StringOfChar('x', 34)),
               'a long secret shows its first two characters and its length');
   CheckEquals('(3 chars)', MaskSecret('abc'), 'a short secret shows only its length');
   CheckEquals('(5 chars)', MaskSecret('abcde'), 'five is still short');
   CheckEquals('ab...(6 chars)', MaskSecret('abcdef'), 'six is the first long one');
   CheckEquals('(empty)', MaskSecret(''), 'an empty secret says so');
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

procedure THttpSecretsTests.RunAllTests;
begin
   GCaptured := TStringList.Create;
   try
      Test_MaskSecret;
      Test_ScrubSecret;
      Test_FailureLineScrubsAnEchoedToken;
      Test_TraceLineMasksTheBearerToken;
      Test_SendNeverLogsTheTokenOnATransportFailure;
      Test_TlsUnavailableNeverLogsTheTokenAndLogsOnce;
      Test_TlsUnavailableIsARetryNotUncertain;
      Test_WrlTlsUnavailableIsARetryNotUncertain;
   finally
      FreeAndNil(GCaptured);
   end;
end;

end.
