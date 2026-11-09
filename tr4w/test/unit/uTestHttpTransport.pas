unit uTestHttpTransport;
{$I ..\..\src\tr4w.inc}
(*
  THE HTTP TRANSPORT CONTRACT (docs/HTTP_TRANSPORT_DESIGN.md, sections 3.3 and 5).

  TWO KINDS OF TEST, AND NEITHER NEEDS THE INTERNET.

  1. The CONTRACT SUITE runs the lines of section 3.3 that need no TLS against
     a transport directly, over a scripted loopback HTTP server. At S1 the only
     transport is the generic one; at S2 the same checks are pointed at the
     Windows transport. Everything about TLS is NOT here: there is no HTTPS
     loopback server in the repository, and a platform transport's TLS
     correctness is a bench item (design, 5.4).

  2. The SHARED-LAYER tests give uHTTPDownload a TFakeHttpTransport and check
     what the shared layer decides: the scheme and bearer policy, the wire
     request it builds, that a transport's raw error text cannot reach a log or
     the operator unscrubbed, that a refused request makes no file, and that an
     empty registry fails closed.

  THE GENERIC TRANSPORT IS NAMED EXPLICITLY. A test that went through the
  registry would silently start testing a platform transport the day one is
  registered (design, 5: the registry must default to generic in this binary).
*)

interface

uses
   SyncObjs, Classes, SysUtils, Log4D,
   IdTCPServer, IdContext, IdGlobal,
   uHttpTransport,
   uTR4WTestFramework;

type
   THttpTransportTests = class(TTestCase)
   private
      FServer:  TIdTCPServer;
      FLock:    TCriticalSection;
      FHeaders: string;       (* lower-cased copy of the last request head *)
      FBody:    RawByteString;
      FPath:    string;
      FHits:    integer;
      (* WHICH TRANSPORT THE CONTRACT RUNS AGAINST. The contract tests are
        written once and RunContract runs them for each transport this
        platform has: the generic one always, and the WinHTTP one on Windows
        (design 5.3). FTag prefixes each test's name so a failure says which. *)
      FUseWinHttp: boolean;
      FTag:        string;
      FCutSlow:    boolean;   (* set by a test to end the /slow wait early *)
      function  NewTransport: TPlatformHttpTransport;
      procedure RunContract;
      procedure ServerExecute(AContext: TIdContext);
      function  StartServer: Word;
      procedure StopServer;
      function  Url(aPort: Word; const aPath: string): string;
   protected
      (* the contract, against the generic transport over loopback *)
      procedure Test_NothingSentTable;
      procedure Test_AnyStatusIsAnAnswerWhenAsked;
      procedure Test_OnlyOkIsAnAnswerWhenNotAsked;
      procedure Test_HeadersAndBodyBytes;
      procedure Test_BasicAuthIsPreemptive;
      procedure Test_ResponseHeadersAreReturned;
      procedure Test_ConditionalHeadersGoOutAndComeBack;
      procedure Test_ResponseCap;
      procedure Test_SinkReceivesTheBody;
      procedure Test_RedirectsOnlyWhenAsked;
      procedure Test_AGetStillFollowsARedirect;
      procedure Test_ARefusedConnectionIsNotProvedUnsent;
      procedure Test_TlsUnavailableIsProvedUnsent;
      procedure Test_ExecuteNeverRaisesAndClearsTheResult;
      procedure Test_BadUrlsAreFailuresNotExceptions;
      procedure Test_AnAttachedEmptyBodySendsContentLengthZero;
      procedure Test_TheBodyIsNotDecompressed;
      procedure Test_ASilentServerTimesOutAfterTheRequestWent;
      (* the registry *)
      procedure Test_RegistrySelectsOnceAndLogsOnce;
      procedure Test_ThePolicyChoosesTheTransport;
      procedure Test_TheSettingDefaultsToGenericAndTheSharedLayerReadsIt;
      (* the shared layer, over a fake transport *)
      procedure Test_SchemeAndBearerPolicyRefuseWithoutTheTransport;
      procedure Test_SendBuildsTheWireRequest;
      procedure Test_ThePostVerbDefaultsReachTheWire;
      procedure Test_TransportErrorTextCannotReachALogOrTheOperator;
      procedure Test_FailureKindsReachTheFlags;
      procedure Test_VerifyOffReachesTheWire;
      procedure Test_GetTextBuildsAGetAndReturnsTheBody;
      procedure Test_DownloadWritesTheFileAndARefusalMakesNone;
      procedure Test_ConditionalDownloadOutcomes;
      procedure Test_NoTransportFailsClosed;
   public
      procedure RunAllTests; override;
   end;

implementation

uses
   uHttpTransportGeneric,
   {$IFDEF WINDOWS}uHttpTransportWinHttp,{$ENDIF}
   uHTTPDownload, uOpenSSLLoader,
   uSettingsRegistry, uSettingsDeclarations, uSettingsModel, uTestFakeTransport;

const
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

procedure StartCapture(out aLogger: TLogLogger; out aAppender: ILogAppender;
                       out aOldLevel: TLogLevel);
begin
   GCaptured.Clear;
   aLogger   := TLogLogger.GetLogger('TR4WDebugLog.HTTP');
   aOldLevel := aLogger.Level;
   aLogger.Level := All;
   aAppender := TCaptureAppender.Create('unit-test http transport capture');
   aLogger.AddAppender(aAppender);
end;

procedure StopCapture(aLogger: TLogLogger; const aAppender: ILogAppender;
                      aOldLevel: TLogLevel);
begin
   aLogger.RemoveAppender(aAppender);
   aLogger.Level := aOldLevel;
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

(* ---- loopback HTTP fixture ---------------------------------------------------- *)

procedure THttpTransportTests.ServerExecute(AContext: TIdContext);
var
   line, head, reqLine, status, extra, path: string;
   contentLength, i, p: integer;
   raw, all, headBytes: TIdBytes;
   body, got: RawByteString;
begin
   reqLine := AContext.Connection.IOHandler.ReadLn;
   head := reqLine + #10;
   contentLength := 0;
   repeat
      line := AContext.Connection.IOHandler.ReadLn;
      if Pos('content-length:', LowerCase(line)) = 1 then
         begin
         contentLength := StrToIntDef(Trim(Copy(line, 16, 20)), 0);
         end;
      head := head + line + #10;
   until line = '';

   raw := nil;
   if contentLength > 0 then
      begin
      AContext.Connection.IOHandler.ReadBytes(raw, contentLength, False);
      end;
   got := '';
   SetLength(got, Length(raw));
   for i := 0 to High(raw) do
      begin
      got[i + 1] := AnsiChar(raw[i]);
      end;

   path := Copy(reqLine, Pos(' ', reqLine) + 1, MaxInt);
   p := Pos(' ', path);
   if p > 0 then
      begin
      path := Copy(path, 1, p - 1);
      end;

   status := '200 OK';
   extra  := '';
   body   := 'hello';
   if path = '/ok' then
      begin
      extra := 'X-Request-Id: req-1'#13#10'Retry-After: 7'#13#10;
      end
   else if path = '/missing' then
      begin
      status := '404 Not Found';
      body   := 'nope';
      end
   else if path = '/redir' then
      begin
      status := '302 Found';
      extra  := 'Location: /ok'#13#10;
      body   := '';
      end
   else if path = '/etag' then
      begin
      (* A conditional resource: a copy that names its ETag gets a bodiless 304. *)
      if Pos('if-none-match: "v1"', LowerCase(head)) > 0 then
         begin
         status := '304 Not Modified';
         extra  := 'ETag: "v1"'#13#10;
         body   := '';
         end
      else
         begin
         extra := 'ETag: "v1"'#13#10 +
                  'Last-Modified: Sat, 01 Nov 2025 00:00:00 GMT'#13#10 +
                  'Content-Type: text/plain'#13#10;
         body  := 'conditional body';
         end;
      end
   else if path = '/big' then
      begin
      body := StringOfChar('x', 100);
      end
   else if path = '/gz' then
      begin
      (* Says it is gzip and is not: a client that decompresses fails or alters it. *)
      extra := 'Content-Encoding: gzip'#13#10;
      body  := 'not-really-gzip';
      end
   else if path = '/slow' then
      begin
      (* The request has arrived and been recorded below only AFTER this wait,
        so record it first: a silent server is one that has READ the request. *)
      FLock.Enter;
      try
         FHeaders := LowerCase(head);
         FPath    := path;
         Inc(FHits);
      finally
         FLock.Leave;
      end;
      (* Silent for up to 5.5 s, in slices, so a test that has its answer can
        cut it short (FCutSlow) and StopServer does not wait out the rest. *)
      i := 0;
      while (i < 5500) and (not FCutSlow) do
         begin
         Sleep(25);
         Inc(i, 25);
         end;
      body := 'late';
      end
   else if path = '/echo' then
      begin
      body := got;
      end
   else
      begin
      status := '404 Not Found';
      body   := 'no such path';
      end;

   FLock.Enter;
   try
      FHeaders := LowerCase(head);
      FBody    := got;
      FPath    := path;
      Inc(FHits);
   finally
      FLock.Leave;
   end;

   headBytes := ToBytes('HTTP/1.1 ' + status + #13#10 + extra +
                        'Content-Length: ' + IntToStr(Length(body)) + #13#10 +
                        'Connection: close'#13#10#13#10, IndyTextEncoding_8Bit);
   SetLength(all, Length(headBytes) + Length(body));
   for i := 0 to High(headBytes) do
      begin
      all[i] := headBytes[i];
      end;
   for i := 1 to Length(body) do
      begin
      all[Length(headBytes) + i - 1] := Byte(body[i]);
      end;
   AContext.Connection.IOHandler.Write(all);
   AContext.Connection.Disconnect;
end;

function THttpTransportTests.StartServer: Word;
begin
   FHits := 0;
   FServer := TIdTCPServer.Create(nil);
   FServer.OnExecute := ServerExecute;
   with FServer.Bindings.Add do
      begin
      IP := '127.0.0.1';
      Port := 0;
      end;
   FServer.Active := True;
   Result := FServer.Bindings[0].Port;
end;

procedure THttpTransportTests.StopServer;
begin
   if FServer <> nil then
      begin
      FServer.Active := False;
      FreeAndNil(FServer);
      end;
end;

function THttpTransportTests.Url(aPort: Word; const aPath: string): string;
begin
   Result := 'http://127.0.0.1:' + IntToStr(aPort) + aPath;
end;

(* A GET wire request with the settings the old Get verbs used. *)
function NewGet(const aURL: string): THttpWireRequest;
begin
   Result := THttpWireRequest.Create;
   Result.Method          := 'GET';
   Result.URL             := aURL;
   Result.UserAgent       := 'TR4W-contract-test';
   Result.AcceptAnyStatus := True;
   Result.VerifyServer    := True;
   Result.ConnectMs       := 2000;
   Result.IOMs            := 2000;
end;

(* ---- the contract, against the generic transport ------------------------------- *)

procedure THttpTransportTests.Test_NothingSentTable;
var
   f:        THttpFailure;
   expected: boolean;
begin
   BeginTest(FTag + 'NothingSent: True only for the failures that PROVE no byte left, for every kind');
   for f := Low(THttpFailure) to High(THttpFailure) do
      begin
      expected := f in [hfTlsUnavailable, hfTrustUnavailable, hfVerificationUnavailable,
                        hfVerificationFailed, hfPlaintextNotAllowed, hfBadScheme,
                        hfAuthPolicy, hfNameNotResolved, hfCannotConnect,
                        hfConnectTimedOut];
      if expected then
         begin
         CheckTrue(NothingSent(f), HttpFailureName(f) + ' proves nothing was sent');
         end
      else
         begin
         CheckFalse(NothingSent(f), HttpFailureName(f) + ' may have been sent');
         end;
      end;
end;

procedure THttpTransportTests.Test_AnyStatusIsAnAnswerWhenAsked;
var
   t:   TPlatformHttpTransport;
   req: THttpWireRequest;
   res: THttpWireResult;
begin
   BeginTest(FTag + 'contract 4: with AcceptAnyStatus a 404 is an answer, not a failure');
   t := NewTransport;
   req := NewGet(Url(StartServer, '/missing'));
   res := THttpWireResult.Create;
   try
      t.Execute(req, nil, res);
      CheckTrue(res.Failure = hfNone, 'an answer arrived: ' + HttpFailureName(res.Failure));
      CheckEquals(404, res.StatusCode, 'with its status');
      CheckEquals('nope', string(res.Body), 'and its body');
      CheckFalse(NothingSent(res.Failure), 'and an answer is not "nothing sent"');
   finally
      res.Free;
      req.Free;
      t.Free;
      StopServer;
   end;
end;

procedure THttpTransportTests.Test_OnlyOkIsAnAnswerWhenNotAsked;
var
   t:   TPlatformHttpTransport;
   req: THttpWireRequest;
   res: THttpWireResult;
begin
   BeginTest(FTag + 'the Get verbs: only 200 is an answer; any other status is a failure with FPC''s words and the status');
   t := NewTransport;
   req := NewGet(Url(StartServer, '/missing'));
   req.AcceptAnyStatus := False;
   res := THttpWireResult.Create;
   try
      t.Execute(req, nil, res);
      CheckTrue(res.Failure = hfOther, 'a failure, may have been sent: ' + HttpFailureName(res.Failure));
      CheckEquals(404, res.StatusCode, 'the status that was answered is recorded');
      CheckTrue(Pos('Unexpected response status code: 404', res.ErrorMessage) > 0,
                'with the library''s own sentence, which operators have seen: ' + res.ErrorMessage);
   finally
      res.Free;
      req.Free;
      t.Free;
      StopServer;
   end;
end;

procedure THttpTransportTests.Test_HeadersAndBodyBytes;
var
   t:    TPlatformHttpTransport;
   req:  THttpWireRequest;
   res:  THttpWireResult;
   sent: RawByteString;
begin
   BeginTest(FTag + 'contract 10, 13: UA, Content-Type, Bearer, Accept-Encoding and the body BYTES (UTF-8) reach the server');
   sent := ToWire('caf' + #$00E9 + ' ok');
   t := NewTransport;
   req := NewGet(Url(StartServer, '/echo'));
   req.Method         := 'POST';
   req.ContentType    := 'application/json';
   req.BearerToken    := 'tok-123';
   req.AcceptEncoding := 'gzip,deflate';
   req.Body           := sent;
   req.HasBody        := True;
   res := THttpWireResult.Create;
   try
      t.Execute(req, nil, res);
      CheckTrue(res.Failure = hfNone, 'answered: ' + res.Detail);
      CheckEquals(Length(sent), Length(FBody), 'the server received every body byte');
      CheckTrue(FBody = sent, 'and they are the same bytes (not UTF-16, not ANSI)');
      CheckTrue(res.Body = sent, 'and the response body comes back byte for byte');
      CheckTrue(Pos('user-agent: tr4w-contract-test', FHeaders) > 0, 'User-Agent is the request''s');
      CheckTrue(Pos('content-type: application/json', FHeaders) > 0, 'Content-Type');
      CheckTrue(Pos('authorization: bearer tok-123', FHeaders) > 0, 'Authorization: Bearer');
      CheckTrue(Pos('accept-encoding: gzip,deflate', FHeaders) > 0, 'Accept-Encoding, and the body is not decompressed');
   finally
      res.Free;
      req.Free;
      t.Free;
      StopServer;
   end;
end;

procedure THttpTransportTests.Test_BasicAuthIsPreemptive;
var
   t:   TPlatformHttpTransport;
   req: THttpWireRequest;
   res: THttpWireResult;
begin
   BeginTest(FTag + 'contract 10: Basic auth is sent on the FIRST request, not after a 401 challenge');
   t := NewTransport;
   req := NewGet(Url(StartServer, '/ok'));
   req.Username := 'user';
   req.Password := 'pw';
   res := THttpWireResult.Create;
   try
      t.Execute(req, nil, res);
      CheckTrue(res.Failure = hfNone, 'answered: ' + res.Detail);
      CheckEquals(1, FHits, 'one request reached the server');
      (* base64 of user:pw *)
      CheckTrue(Pos('authorization: basic dxnlcjpwdw==', FHeaders) > 0, 'the header was already on it: ' + FHeaders);
   finally
      res.Free;
      req.Free;
      t.Free;
      StopServer;
   end;
end;

procedure THttpTransportTests.Test_ResponseHeadersAreReturned;
var
   t:   TPlatformHttpTransport;
   req: THttpWireRequest;
   res: THttpWireResult;
begin
   BeginTest(FTag + 'status text, Retry-After and X-Request-Id come back');
   t := NewTransport;
   req := NewGet(Url(StartServer, '/ok'));
   res := THttpWireResult.Create;
   try
      t.Execute(req, nil, res);
      CheckEquals(200, res.StatusCode, 'status');
      CheckEquals('OK', res.StatusText, 'reason phrase');
      CheckEquals('7', res.RetryAfter, 'Retry-After');
      CheckEquals('req-1', res.RequestId, 'X-Request-Id');
   finally
      res.Free;
      req.Free;
      t.Free;
      StopServer;
   end;
end;

procedure THttpTransportTests.Test_ConditionalHeadersGoOutAndComeBack;
var
   t:   TPlatformHttpTransport;
   req: THttpWireRequest;
   res: THttpWireResult;
   port: Word;
begin
   BeginTest(FTag + 'If-None-Match and If-Modified-Since go out when set; ETag, Last-Modified and Content-Type come back; a 304 has no body');
   t := NewTransport;
   port := StartServer;
   res := THttpWireResult.Create;
   try
      (* No condition: neither header is sent, and the validators come back. *)
      req := NewGet(Url(port, '/etag'));
      try
         t.Execute(req, nil, res);
      finally
         req.Free;
      end;
      CheckEquals(200, res.StatusCode, 'unconditional: status');
      CheckEquals('"v1"', res.ETag, 'ETag');
      CheckEquals('Sat, 01 Nov 2025 00:00:00 GMT', res.LastModified, 'Last-Modified');
      CheckEquals('text/plain', res.ContentType, 'Content-Type');
      CheckEquals('conditional body', string(res.Body), 'body');
      FLock.Enter;
      try
         CheckEquals(0, Pos('if-none-match', FHeaders), 'no If-None-Match when not set');
         CheckEquals(0, Pos('if-modified-since', FHeaders), 'no If-Modified-Since when not set');
      finally
         FLock.Leave;
      end;

      (* The ETag held: the server answers 304 with no body. *)
      req := NewGet(Url(port, '/etag'));
      req.IfNoneMatch     := '"v1"';
      req.IfModifiedSince := 'Sat, 01 Nov 2025 00:00:00 GMT';
      try
         t.Execute(req, nil, res);
      finally
         req.Free;
      end;
      CheckEquals(304, res.StatusCode, 'conditional: status');
      CheckTrue(res.Failure = hfNone, '304 is an answer, not a failure');
      CheckEquals('', string(res.Body), '304 has no body');
      FLock.Enter;
      try
         CheckTrue(Pos('if-none-match: "v1"', FHeaders) > 0, 'If-None-Match sent');
         CheckTrue(Pos('if-modified-since: sat, 01 nov 2025 00:00:00 gmt', FHeaders) > 0,
                   'If-Modified-Since sent');
      finally
         FLock.Leave;
      end;
   finally
      res.Free;
      t.Free;
      StopServer;
   end;
end;

procedure THttpTransportTests.Test_ResponseCap;
var
   t:   TPlatformHttpTransport;
   req: THttpWireRequest;
   res: THttpWireResult;
   port: Word;
begin
   BeginTest(FTag + 'contract 7: a response over MaxResponseBytes is hfResponseTooLarge (not provable unsent); 0 is unlimited');
   t := NewTransport;
   port := StartServer;
   req := NewGet(Url(port, '/big'));
   res := THttpWireResult.Create;
   try
      req.MaxResponseBytes := 10;
      t.Execute(req, nil, res);
      CheckTrue(res.Failure = hfResponseTooLarge, 'over the cap: ' + HttpFailureName(res.Failure));
      CheckFalse(NothingSent(res.Failure), 'an answer began, so the server saw the request');
      req.MaxResponseBytes := 0;
      t.Execute(req, nil, res);
      CheckTrue(res.Failure = hfNone, 'unlimited: ' + res.Detail);
      CheckEquals(100, Length(res.Body), 'the whole body');
   finally
      res.Free;
      req.Free;
      t.Free;
      StopServer;
   end;
end;

procedure THttpTransportTests.Test_SinkReceivesTheBody;
var
   t:    TPlatformHttpTransport;
   req:  THttpWireRequest;
   res:  THttpWireResult;
   sink: TMemoryStream;
begin
   BeginTest(FTag + 'a sink receives the body; the result then holds none');
   t := NewTransport;
   req := NewGet(Url(StartServer, '/ok'));
   res := THttpWireResult.Create;
   sink := TMemoryStream.Create;
   try
      t.Execute(req, sink, res);
      CheckTrue(res.Failure = hfNone, 'answered: ' + res.Detail);
      CheckEquals(5, sink.Size, 'the sink holds "hello"');
      CheckEquals(0, Length(res.Body), 'and the result does not');
   finally
      sink.Free;
      res.Free;
      req.Free;
      t.Free;
      StopServer;
   end;
end;

procedure THttpTransportTests.Test_RedirectsOnlyWhenAsked;
var
   t:   TPlatformHttpTransport;
   req: THttpWireRequest;
   res: THttpWireResult;
   port: Word;
begin
   BeginTest(FTag + 'contract 8: a redirect is followed only when FollowRedirects (Send''s any-status mode)');
   t := NewTransport;
   port := StartServer;
   req := NewGet(Url(port, '/redir'));
   res := THttpWireResult.Create;
   try
      req.FollowRedirects := False;
      t.Execute(req, nil, res);
      CheckTrue(res.Failure = hfNone, 'answered: ' + res.Detail);
      CheckEquals(302, res.StatusCode, 'not followed: the 302 itself is the answer');
      CheckEquals('', res.FinalURL, 'no hop followed, so no final address');
      req.FollowRedirects := True;
      t.Execute(req, nil, res);
      CheckTrue(res.Failure = hfNone, 'answered: ' + res.Detail);
      CheckEquals(200, res.StatusCode, 'followed to /ok');
      CheckEquals(Url(port, '/ok'), res.FinalURL, 'the address that answered, resolved from the relative Location');
      CheckEquals('hello', string(res.Body), 'and the final body');
   finally
      res.Free;
      req.Free;
      t.Free;
      StopServer;
   end;
end;

procedure THttpTransportTests.Test_AGetStillFollowsARedirect;
var
   t:   TPlatformHttpTransport;
   req: THttpWireRequest;
   res: THttpWireResult;
begin
   BeginTest(FTag + 'PINS TODAY''S BEHAVIOUR: the Get verbs (only 200 allowed) still FOLLOW a redirect, to any scheme');
   (* I expected FPC to raise on the 302 before following it, because the
     allowed list is [200]. It does not: the redirect is followed and the
     FINAL status is checked. So HttpGetText/Download follow redirects, as the
     design doc says (2.4), and nothing in TR4W checks the scheme of the target
     -- that is open question 5 / S1c. If S1c forbids an https-to-http hop,
     this test is the one that changes. *)
   t := NewTransport;
   req := NewGet(Url(StartServer, '/redir'));
   req.AcceptAnyStatus := False;
   req.FollowRedirects := True;
   res := THttpWireResult.Create;
   try
      t.Execute(req, nil, res);
      CheckTrue(res.Failure = hfNone, 'followed: ' + res.Detail);
      CheckEquals(200, res.StatusCode, 'the final status');
      CheckEquals('hello', string(res.Body), 'and the final body');
      CheckEquals(2, FHits, '/redir then /ok');
   finally
      res.Free;
      req.Free;
      t.Free;
      StopServer;
   end;
end;

procedure THttpTransportTests.Test_ARefusedConnectionIsNotProvedUnsent;
var
   t:   TPlatformHttpTransport;
   req: THttpWireRequest;
   res: THttpWireResult;
begin
   BeginTest(FTag + 'contract 3: a refused connection: the generic client cannot tell it from a reset and claims nothing; WinHTTP says ERROR_WINHTTP_CANNOT_CONNECT and may claim "not sent"');
   t := NewTransport;
   req := NewGet('http://127.0.0.1:1/probe');
   res := THttpWireResult.Create;
   try
      t.Execute(req, nil, res);
      if FUseWinHttp then
         begin
         CheckTrue(res.Failure = hfCannotConnect, 'hfCannotConnect: ' + HttpFailureName(res.Failure) + ' ' + res.Detail);
         CheckTrue(NothingSent(res.Failure), 'proved unsent (redirects are off)');
         (* With redirects on, the failure could belong to a SECOND request, so
           nothing is claimed. *)
         req.FollowRedirects := True;
         t.Execute(req, nil, res);
         CheckTrue(res.Failure = hfOther, 'with FollowRedirects the same refusal is hfOther: ' + HttpFailureName(res.Failure));
         CheckFalse(NothingSent(res.Failure), 'and claims nothing');
         end
      else
         begin
         CheckTrue(res.Failure = hfOther, 'hfOther: ' + HttpFailureName(res.Failure));
         CheckFalse(NothingSent(res.Failure), 'so a caller must treat it as possibly sent');
         end;
      CheckTrue(res.ErrorMessage <> '', 'with the library''s text for the log');
   finally
      res.Free;
      req.Free;
      t.Free;
   end;
end;

procedure THttpTransportTests.Test_TlsUnavailableIsProvedUnsent;
var
   t:   TPlatformHttpTransport;
   req: THttpWireRequest;
   res: THttpWireResult;
begin
   BeginTest(FTag + 'contract 3, 11: https with no usable TLS is hfTlsUnavailable and proved unsent');
   SetOpenSSLForcedUnavailable('test-only: forced unavailable for the contract');
   t := NewTransport;
   req := NewGet('https://tr4w-contract.invalid/x');
   res := THttpWireResult.Create;
   try
      t.Execute(req, nil, res);
      CheckTrue(res.Failure = hfTlsUnavailable, 'kind: ' + HttpFailureName(res.Failure));
      CheckTrue(NothingSent(res.Failure), 'proved unsent');
      CheckTrue(Pos('forced unavailable', res.ErrorMessage) > 0, 'with the loader''s diagnostic');
      CheckEquals(0, res.StatusCode, 'no answer');
   finally
      SetOpenSSLForcedUnavailable('');
      res.Free;
      req.Free;
      t.Free;
   end;
end;

(* THE URLS A TRANSPORT CANNOT USE are failures, never exceptions: an unusable
  scheme, no host, a bad port. (The shared layer vets the scheme first; this is
  the contract's "never raises" held by the transport itself.) *)
procedure THttpTransportTests.Test_BadUrlsAreFailuresNotExceptions;
const
   BAD: array[0..4] of string = (
      'ftp://127.0.0.1/x', 'http://', 'http:///nohost', 'http://127.0.0.1:0/x',
      'no-scheme-at-all');
var
   t:   TPlatformHttpTransport;
   req: THttpWireRequest;
   res: THttpWireResult;
   i:   integer;
begin
   BeginTest(FTag + 'contract 2: an unusable URL is a failure with a reason, and never an exception');
   t   := NewTransport;
   res := THttpWireResult.Create;
   try
      for i := Low(BAD) to High(BAD) do
         begin
         req := NewGet(BAD[i]);
         try
            t.Execute(req, nil, res);
            CheckTrue(res.Failure <> hfNone, BAD[i] + ' is a failure');
            CheckEquals(0, res.StatusCode, BAD[i] + ' got no answer');
         finally
            req.Free;
         end;
      end;
   finally
      res.Free;
      t.Free;
   end;
end;

(* An attached body, even an empty one, goes out with Content-Length: 0 on every
  verb. FPC's client always did it, and the WRL bodiless GET depends on the
  same bytes (HasBody, design 6 S1a). *)
procedure THttpTransportTests.Test_AnAttachedEmptyBodySendsContentLengthZero;
var
   t:   TPlatformHttpTransport;
   req: THttpWireRequest;
   res: THttpWireResult;
begin
   BeginTest(FTag + 'HasBody with an empty body sends Content-Length: 0, and no body means no Content-Length');
   t := NewTransport;
   req := NewGet(Url(StartServer, '/ok'));
   res := THttpWireResult.Create;
   try
      req.HasBody := True;
      req.Body    := '';
      t.Execute(req, nil, res);
      CheckTrue(res.Failure = hfNone, 'answered: ' + res.Detail);
      FLock.Enter;
      try
         CheckTrue(Pos('content-length: 0', FHeaders) > 0, 'Content-Length: 0 on the wire: ' + FHeaders);
      finally
         FLock.Leave;
      end;
      req.HasBody := False;
      t.Execute(req, nil, res);
      FLock.Enter;
      try
         CheckEquals(0, Pos('content-length', FHeaders), 'no body, no Content-Length: ' + FHeaders);
      finally
         FLock.Leave;
      end;
   finally
      res.Free;
      req.Free;
      t.Free;
      StopServer;
   end;
end;

(* CONTRACT 9: no automatic decompression. The server claims gzip and sends text
  that is not gzip: a client that tried to decode it would fail or change it. *)
procedure THttpTransportTests.Test_TheBodyIsNotDecompressed;
var
   t:   TPlatformHttpTransport;
   req: THttpWireRequest;
   res: THttpWireResult;
begin
   BeginTest(FTag + 'contract 9: a Content-Encoding: gzip response comes back exactly as sent');
   t := NewTransport;
   req := NewGet(Url(StartServer, '/gz'));
   req.AcceptEncoding := 'gzip,deflate';
   res := THttpWireResult.Create;
   try
      t.Execute(req, nil, res);
      CheckTrue(res.Failure = hfNone, 'answered: ' + res.Detail);
      CheckEquals('not-really-gzip', string(res.Body), 'the bytes the server sent');
      FLock.Enter;
      try
         CheckTrue(Pos('accept-encoding: gzip,deflate', FHeaders) > 0, 'and the request still offered it');
      finally
         FLock.Leave;
      end;
   finally
      res.Free;
      req.Free;
      t.Free;
      StopServer;
   end;
end;

(* CONTRACT 3 AND 5. The server READS the request and then says nothing for
  longer than the I/O timeout. The request went out, so the timeout is "may have
  been sent" (hfIOTimedOut for WinHTTP; the generic client calls it hfOther).

  THE TWO TRANSPORTS DIFFER ON HOW PRECISELY THE TIMEOUT IS KEPT, and the
  difference is measured, not assumed. The generic client returns at the
  timeout. WinHTTP enforces its timeouts on a COARSE CLOCK: with a 5.5 s silent
  server, IOMs of 200, 400, 1000 and 2500 ms all returned at 4000 ms (4016) and
  6000 ms returned at 8000 -- the value rounded UP to a multiple of 4 s
  (measured on Windows 11 build 26200, both options on the session and on the
  request, all three proxy modes, with a Python and an Indy server). So the
  assertion for WinHTTP is "it gives up, in a bounded time, and says
  hfIOTimedOut" -- not "at 400 ms". *)
procedure THttpTransportTests.Test_ASilentServerTimesOutAfterTheRequestWent;
var
   t:       TPlatformHttpTransport;
   req:     THttpWireRequest;
   res:     THttpWireResult;
   started: QWord;
   elapsed: QWord;
begin
   BeginTest(FTag + 'contract 5: IOMs bounds the wait for an answer; the timeout never claims "not sent"');
   t := NewTransport;
   FCutSlow := False;
   req := NewGet(Url(StartServer, '/slow'));
   req.IOMs := 400;
   res := THttpWireResult.Create;
   try
      started := GetTickCount64;
      t.Execute(req, nil, res);
      elapsed := GetTickCount64 - started;
      CheckTrue(res.Failure <> hfNone, 'a failure: ' + HttpFailureName(res.Failure));
      CheckFalse(NothingSent(res.Failure), 'the request had been read by the server: ' + HttpFailureName(res.Failure));
      if FUseWinHttp then
         begin
         CheckTrue(res.Failure = hfIOTimedOut, 'WinHTTP: hfIOTimedOut: ' + HttpFailureName(res.Failure) + ' ' + res.Detail);
         end;
      if FUseWinHttp then
         begin
         CheckTrue(elapsed < 5000, 'WinHTTP gave up at its coarse 4 s tick, before the server''s 5.5 s silence ends (' + IntToStr(elapsed) + ' ms)');
         end
      else
         begin
         CheckTrue(elapsed < 1400, 'it returned in about the timeout (' + IntToStr(elapsed) + ' ms)');
         end;
      FCutSlow := True;
      FLock.Enter;
      try
         CheckTrue(FHits >= 1, 'the server did receive the request');
      finally
         FLock.Leave;
      end;
   finally
      res.Free;
      req.Free;
      t.Free;
      StopServer;
   end;
end;

procedure THttpTransportTests.Test_ExecuteNeverRaisesAndClearsTheResult;
var
   t:   TPlatformHttpTransport;
   req: THttpWireRequest;
   res: THttpWireResult;
begin
   BeginTest(FTag + 'contract 2: Execute never raises, and starts from a clean result');
   t := NewTransport;
   req := NewGet('');
   res := THttpWireResult.Create;
   try
      res.StatusCode := 999;
      res.RetryAfter := 'stale';
      res.Body       := 'stale';
      t.Execute(req, nil, res);
      CheckTrue(res.Failure <> hfNone, 'an empty URL is a failure, not an exception');
      CheckEquals(0, res.StatusCode, 'the stale status is gone');
      CheckEquals('', res.RetryAfter, 'and the stale header');
      CheckEquals(0, Length(res.Body), 'and the stale body');
   finally
      res.Free;
      req.Free;
      t.Free;
   end;
end;

(* ---- the registry --------------------------------------------------------------- *)

(* The REAL WinHTTP transport is registered as preferred in this binary, so a
  test of the registry's own rules would have it competing with the fakes. These
  take it out for the test and put it back, exactly as it was. *)
procedure HideRealPlatformTransports;
begin
{$IFDEF WINDOWS}
   UnregisterHttpTransport(TWinHttpTransport);
{$ENDIF}
end;

procedure RestoreRealPlatformTransports;
begin
{$IFDEF WINDOWS}
   RegisterHttpTransport(TWinHttpTransport, True);
{$ENDIF}
end;

procedure THttpTransportTests.Test_RegistrySelectsOnceAndLogsOnce;
var
   lg:       TLogLogger;
   keep:     ILogAppender;
   oldLevel: TLogLevel;
   first, again: TPlatformHttpTransport;
begin
   BeginTest('registry: a preferred transport only if the policy asks AND it is Available; decided once, logged once');
   SetHttpTransportForTest(nil);
   HideRealPlatformTransports;
   ResetHttpTransportSelection;
   StartCapture(lg, keep, oldLevel);
   try
      first := ActiveHttpTransport(HTTP_TRANSPORT_GENERIC);
      CheckTrue(first <> nil, 'something is selected');
      CheckEquals('generic', first.Id, 'generic policy: the generic one, whatever platform transport is registered');
      again := ActiveHttpTransport(HTTP_TRANSPORT_GENERIC);
      CheckTrue(first = again, 'asked again: the same instance');
      CheckEquals(1, CountLinesWith('[HTTP] transport: generic'), 'logged once');

      (* A platform transport that cannot start here: named in a Warn, and the
        generic one is chosen. *)
      RegisterHttpTransport(TFakeUnavailablePlatform, True);
      ResetHttpTransportSelection;
      GCaptured.Clear;
      CheckEquals('generic', ActiveHttpTransport(HTTP_TRANSPORT_AUTO).Id, 'an unavailable preferred transport falls back to generic');
      CheckEquals(1, CountLinesWith('fake-unavailable'), 'and the log names the one that could not start');
      CheckTrue(CountLinesWith('cannot start') >= 1, 'and why');

      (* One that can start wins, when the policy asks for it. *)
      RegisterHttpTransport(TFakeAvailablePlatform, True);
      ResetHttpTransportSelection;
      CheckEquals('fake-available', ActiveHttpTransport(HTTP_TRANSPORT_AUTO).Id, 'an available preferred transport is chosen');

      (* Decided once: removing it does not change the answer for the same policy. *)
      UnregisterHttpTransport(TFakeAvailablePlatform);
      CheckEquals('fake-available', ActiveHttpTransport(HTTP_TRANSPORT_AUTO).Id, 'the decision is not re-made');
   finally
      StopCapture(lg, keep, oldLevel);
      UnregisterHttpTransport(TFakeAvailablePlatform);
      UnregisterHttpTransport(TFakeUnavailablePlatform);
      RestoreRealPlatformTransports;
      ResetHttpTransportSelection;
   end;
   CheckEquals('generic', ActiveHttpTransport(HTTP_TRANSPORT_GENERIC).Id, 'back to generic afterwards');
end;

(* THE POLICY IS WHAT CHOOSES (design 6, S2). Registering a platform transport
  must NOT make it the default: only auto and platform pick it, and a blank or
  unknown value is generic. A changed policy re-decides and logs again; the
  transport it replaced stays alive for a worker that may still be inside it. *)
procedure THttpTransportTests.Test_ThePolicyChoosesTheTransport;
var
   lg:       TLogLogger;
   keep:     ILogAppender;
   oldLevel: TLogLevel;
   generic:  TPlatformHttpTransport;
begin
   BeginTest('policy: generic, blank and unknown choose generic; auto and platform choose the preferred one; platform with none says so');
   SetHttpTransportForTest(nil);
   HideRealPlatformTransports;
   ResetHttpTransportSelection;
   StartCapture(lg, keep, oldLevel);
   try
      RegisterHttpTransport(TFakeAvailablePlatform, True);
      CheckEquals('generic', ActiveHttpTransport(HTTP_TRANSPORT_GENERIC).Id, 'generic');
      generic := ActiveHttpTransport(HTTP_TRANSPORT_GENERIC);
      CheckEquals('generic', ActiveHttpTransport('').Id, 'blank is generic');
      CheckEquals('generic', ActiveHttpTransport('nonsense').Id, 'unknown is generic');
      CheckTrue(generic = ActiveHttpTransport(''), 'blank and generic are the same decision: no re-decide');
      CheckEquals('fake-available', ActiveHttpTransport(HTTP_TRANSPORT_AUTO).Id, 'auto: the preferred one');
      CheckEquals('fake-available', ActiveHttpTransport('  PLATFORM ').Id, 'platform: the preferred one, case and spaces ignored');
      CheckEquals('generic', ActiveHttpTransport(HTTP_TRANSPORT_GENERIC).Id, 'and back to generic when the setting goes back');

      (* platform on a platform with none: generic, and a Warn that says so. *)
      UnregisterHttpTransport(TFakeAvailablePlatform);
      ResetHttpTransportSelection;
      GCaptured.Clear;
      CheckEquals('generic', ActiveHttpTransport(HTTP_TRANSPORT_PLATFORM).Id, 'platform with no platform transport is generic');
      CheckTrue(CountLinesWith('this platform has none') = 1, 'and the log says so');
      GCaptured.Clear;
      ResetHttpTransportSelection;
      CheckEquals('generic', ActiveHttpTransport(HTTP_TRANSPORT_AUTO).Id, 'auto with none is generic');
      CheckEquals(0, CountLinesWith('this platform has none'), 'and says nothing: that is what auto is');
   finally
      StopCapture(lg, keep, oldLevel);
      UnregisterHttpTransport(TFakeAvailablePlatform);
      RestoreRealPlatformTransports;
      ResetHttpTransportSelection;
   end;
end;

(* THE SETTING ITSELF: default generic, in the model and in the registry the
  shared layer reads; its vocabulary is the registry's three words. *)
procedure THttpTransportTests.Test_TheSettingDefaultsToGenericAndTheSharedLayerReadsIt;
var
   s:       TR4WSettings;
   setting: TSettingBase;
   values:  TArray<string>;
begin
   BeginTest('network.httpTransport: default generic; its vocabulary is generic, auto, platform; the shared layer can find it');
   s := TR4WSettings.Create;
   try
      CheckEquals('generic', s.Network.HttpTransport, 'a new settings object uses the generic transport');
      CheckTrue(s.TrySetByCommand('NETWORK HTTP TRANSPORT', 'auto'), 'set by command');
      CheckEquals('auto', s.Network.HttpTransport, 'the property took it');
      CheckFalse(s.TrySetByCommand('NETWORK HTTP TRANSPORT', 'curl'), 'a word outside the vocabulary is refused');
      CheckEquals('auto', s.Network.HttpTransport, 'and changes nothing');
   finally
      s.Free;
   end;

   DeclareAllSettings;
   setting := FindSetting('network.httpTransport');
   CheckTrue(setting <> nil, 'it is registered for Preferences and for uHTTPDownload.TransportPolicy');
   if setting <> nil then
      begin
      values := setting.AllowedValues;
      CheckEquals(3, Length(values), 'three values');
      CheckEquals('generic', values[0], 'generic first: the default');
      CheckEquals('auto', values[1], 'auto');
      CheckEquals('platform', values[2], 'platform');
      end;
end;

(* ---- the shared layer, over a fake transport ------------------------------------- *)

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

procedure THttpTransportTests.Test_SchemeAndBearerPolicyRefuseWithoutTheTransport;
var
   fake:    TFakeHttpTransport;
   request: THttpRequest;
begin
   BeginTest('the shared layer refuses plaintext, no scheme and a bad bearer BEFORE the transport is asked');
   fake := TFakeHttpTransport.Create;
   SetHttpTransportForTest(fake);
   try
      request := THttpRequest.Create('http://example.invalid/x');
      try
         CheckFalse(request.Send, 'plaintext without AllowInsecure');
         CheckTrue(request.Failure = hfPlaintextNotAllowed, 'kind: ' + HttpFailureName(request.Failure));
         CheckTrue(request.NothingSent, 'proved unsent');
         request.URL := 'ftp://example.invalid/x';
         CheckFalse(request.Send, 'no http scheme');
         CheckTrue(request.Failure = hfBadScheme, 'kind: ' + HttpFailureName(request.Failure));
         CheckTrue(request.NothingSent, 'proved unsent');
         request.URL := 'http://example.invalid/x';
         request.BearerToken := TOKEN;
         request.AllowInsecure := True;
         CheckFalse(request.Send, 'a bearer token over http');
         CheckTrue(request.Failure = hfAuthPolicy, 'kind: ' + HttpFailureName(request.Failure));
         CheckTrue(request.NothingSent, 'proved unsent');
         CheckEquals(0, Pos(TOKEN, request.FailReason), 'and the reason carries no token');
         request.URL := 'https://example.invalid/x';
         request.BearerToken := TOKEN + #13#10'Injected: yes';
         CheckFalse(request.Send, 'a token with a line break');
         CheckTrue(request.Failure = hfAuthPolicy, 'kind: ' + HttpFailureName(request.Failure));
         request.BearerToken := TOKEN;
         request.FollowRedirects := True;
         CheckFalse(request.Send, 'a bearer request that follows redirects');
         CheckTrue(request.Failure = hfAuthPolicy, 'kind: ' + HttpFailureName(request.Failure));
      finally
         request.Free;
      end;
      CheckEquals(0, fake.Calls, 'the transport was never asked');
   finally
      SetHttpTransportForTest(nil);
      fake.Free;
   end;
end;

procedure THttpTransportTests.Test_SendBuildsTheWireRequest;
var
   fake:    TFakeHttpTransport;
   request: THttpRequest;
begin
   BeginTest('Send hands the transport what the caller set, an empty body included');
   DeclareVerifyOn;
   fake := TFakeHttpTransport.Create;
   fake.ScriptStatus     := 201;
   fake.ScriptStatusText := 'Created';
   fake.ScriptRetryAfter := '30';
   fake.ScriptRequestId  := 'r-9';
   fake.ScriptBody       := ToWire('answer ' + #$00E9);
   SetHttpTransportForTest(fake);
   try
      request := THttpRequest.Create('https://api.invalid/v1/x');
      try
         request.Method         := 'DELETE';
         request.ContentType    := 'application/json';
         request.BearerToken    := TOKEN;
         request.UserAgent      := 'TR4W-test';
         request.ConnectMs      := 5000;
         request.IOMs           := 10000;
         request.MaxResponseBytes := 4096;
         CheckTrue(request.Send, 'an answer is True: ' + request.FailReason);
         CheckEquals(201, request.StatusCode, 'status');
         CheckEquals('Created', request.ResponseStatusText, 'status text');
         CheckEquals('30', request.RetryAfter, 'Retry-After');
         CheckEquals('r-9', request.RequestId, 'request id');
         CheckEquals('answer ' + #$00E9, request.Response, 'the body, decoded from UTF-8');
         CheckTrue(request.Failure = hfNone, 'no failure');
         CheckFalse(request.NothingSent, 'an answer is not "nothing sent"');
      finally
         request.Free;
      end;
      CheckEquals(1, fake.Calls, 'one call');
      CheckEquals('DELETE', fake.Last.Method, 'method');
      CheckEquals('https://api.invalid/v1/x', fake.Last.URL, 'URL');
      CheckEquals('TR4W-test', fake.Last.UserAgent, 'user agent');
      CheckEquals('application/json', fake.Last.ContentType, 'content type');
      CheckEquals(TOKEN, fake.Last.BearerToken, 'bearer token is sent to the transport (never logged)');
      CheckTrue(fake.Last.HasBody, 'an empty body is still attached: the old Content-Length: 0');
      CheckTrue(fake.Last.AcceptAnyStatus, 'every status is an answer');
      CheckTrue(fake.Last.VerifyServer, 'verification is on by default');
      CheckFalse(fake.Last.FollowRedirects, 'no redirects');
      CheckEquals(5000, fake.Last.ConnectMs, 'connect timeout');
      CheckEquals(10000, fake.Last.IOMs, 'io timeout');
      CheckTrue(fake.Last.MaxResponseBytes = 4096, 'cap');
      CheckFalse(fake.LastHadSink, 'collected in memory, no sink');
   finally
      SetHttpTransportForTest(nil);
      fake.Free;
   end;
end;

procedure THttpTransportTests.Test_ThePostVerbDefaultsReachTheWire;
var
   fake: TFakeHttpTransport;
   post: THttpPost;
begin
   BeginTest('THttpPost: redirects followed, no cap -- the defaults the existing POST callers rely on');
   DeclareVerifyOn;
   fake := TFakeHttpTransport.Create;
   fake.ScriptStatus := 200;
   SetHttpTransportForTest(fake);
   try
      post := THttpPost.Create('https://score.invalid/post/');
      try
         post.Body := 'a=b';
         CheckTrue(post.Send, 'answered');
      finally
         post.Free;
      end;
      CheckTrue(fake.Last.FollowRedirects, 'redirects followed');
      CheckTrue(fake.Last.MaxResponseBytes = 0, 'unlimited');
      CheckEquals('a=b', string(fake.Last.Body), 'form body');
      CheckEquals('application/x-www-form-urlencoded', fake.Last.ContentType, 'default content type');
   finally
      SetHttpTransportForTest(nil);
      fake.Free;
   end;
end;

procedure THttpTransportTests.Test_TransportErrorTextCannotReachALogOrTheOperator;
var
   lg:       TLogLogger;
   keep:     ILogAppender;
   oldLevel: TLogLevel;
   fake:     TFakeHttpTransport;
   request:  THttpRequest;
   joined:   string;
begin
   BeginTest('a transport''s raw error text echoing the token is scrubbed out of the log and the reason (design 3.1)');
   DeclareVerifyOn;
   fake := TFakeHttpTransport.Create;
   fake.ScriptFailure      := hfOther;
   fake.ScriptErrorClass   := 'ETestFault';
   fake.ScriptErrorMessage := 'server rejected key ' + TOKEN + ' for user';
   fake.ScriptStatus       := 0;
   SetHttpTransportForTest(fake);
   StartCapture(lg, keep, oldLevel);
   try
      request := THttpRequest.Create('https://api.invalid/x?k=' + TOKEN);
      try
         request.BearerToken := TOKEN;
         CheckFalse(request.Send, 'the request fails');
         CheckTrue(request.Failure = hfOther, 'kind: ' + HttpFailureName(request.Failure));
         CheckFalse(request.NothingSent, 'hfOther may have been sent');
         CheckEquals(0, Pos(TOKEN, request.FailReason), 'no token in the reason shown to the operator');
         CheckTrue(Pos('ETestFault', request.FailReason) > 0, 'the generic credentialed sentence names the class');
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
   CheckTrue(Pos('server rejected key', joined) > 0, 'the transport''s words are logged, around the mask');
   CheckTrue(Pos('api.invalid/x', joined) > 0, 'with the URL');
end;

procedure THttpTransportTests.Test_FailureKindsReachTheFlags;
var
   fake:    TFakeHttpTransport;
   request: THttpRequest;
begin
   BeginTest('a transport''s failure kind reaches Failure, the two old flags and NothingSent');
   DeclareVerifyOn;
   fake := TFakeHttpTransport.Create;
   SetHttpTransportForTest(fake);
   try
      request := THttpRequest.Create('https://api.invalid/x');
      try
         request.BearerToken := TOKEN;

         fake.ScriptFailure := hfTlsUnavailable;
         fake.ScriptErrorMessage := 'test-only: no ssl';
         CheckFalse(request.Send, 'tls unavailable');
         CheckTrue(request.TlsUnavailable, 'the TLS flag');
         CheckFalse(request.TrustBundleMissing, 'not the bundle flag');
         CheckTrue(request.NothingSent, 'proved unsent');

         fake.ScriptFailure := hfTrustUnavailable;
         fake.ScriptErrorMessage := 'test-only: no bundle';
         CheckFalse(request.Send, 'trust unavailable');
         CheckTrue(request.TrustBundleMissing, 'the bundle flag');
         CheckFalse(request.TlsUnavailable, 'not the TLS flag');
         CheckTrue(request.NothingSent, 'proved unsent');
         CheckTrue(Pos('REFUSED', request.FailReason) > 0, 'the operator sentence names the refusal');

         fake.ScriptFailure := hfVerificationUnavailable;
         fake.ScriptErrorMessage := 'test-only: no X509_check_host';
         CheckFalse(request.Send, 'verification unavailable');
         CheckFalse(request.TrustBundleMissing, 'not the bundle flag');
         CheckFalse(request.TlsUnavailable, 'not the TLS flag');
         CheckTrue(request.NothingSent, 'but still proved unsent');

         fake.ScriptFailure := hfConnectionLost;
         CheckFalse(request.Send, 'connection lost');
         CheckFalse(request.NothingSent, 'not provable');

         fake.ScriptFailure := hfNone;
         fake.ScriptStatus := 200;
         CheckTrue(request.Send, 'an answer');
         CheckFalse(request.TlsUnavailable or request.TrustBundleMissing, 'Send resets the flags');

         (* The flags are still WRITABLE: the existing stubs set them. *)
         request.TrustBundleMissing := True;
         CheckTrue(request.Failure = hfTrustUnavailable, 'writing the flag sets the kind');
         CheckTrue(request.NothingSent, 'so the stub reads as unsent');
         request.TrustBundleMissing := False;
         CheckTrue(request.Failure = hfNone, 'and clearing it clears the kind');
      finally
         request.Free;
      end;
   finally
      SetHttpTransportForTest(nil);
      fake.Free;
   end;
end;

procedure THttpTransportTests.Test_VerifyOffReachesTheWire;
var
   fake:    TFakeHttpTransport;
   request: THttpRequest;
   setting: TSettingBase;
begin
   BeginTest('network.verifyServerCertificates OFF reaches the transport as VerifyServer = False (and only for https)');
   DeclareAllSettings;
   setting := FindSetting('network.verifyServerCertificates');
   fake := TFakeHttpTransport.Create;
   fake.ScriptStatus := 200;
   SetHttpTransportForTest(fake);
   try
      if setting is TBoolSetting then
         begin
         TBoolSetting(setting).SetValue(False);
         end;
      request := THttpRequest.Create('https://api.invalid/x');
      try
         CheckTrue(request.Send, 'answered');
         CheckFalse(fake.Last.VerifyServer, 'the operator turned checking off');
      finally
         request.Free;
      end;
   finally
      if setting is TBoolSetting then
         begin
         TBoolSetting(setting).SetValue(True);
         end;
      SetHttpTransportForTest(nil);
      fake.Free;
   end;
end;

procedure THttpTransportTests.Test_GetTextBuildsAGetAndReturnsTheBody;
var
   fake:   TFakeHttpTransport;
   text, reason: string;
begin
   BeginTest('HttpGetText: a GET that follows redirects, accepts only 200, attaches no body, returns the text');
   DeclareVerifyOn;
   fake := TFakeHttpTransport.Create;
   fake.ScriptStatus := 200;
   fake.ScriptBody   := ToWire('{"v":1}');
   SetHttpTransportForTest(fake);
   try
      CheckTrue(HttpGetText('https://tr4w.invalid/version.json', text, reason, 'UA-1', 5000, 6000),
                'answered: ' + reason);
      CheckEquals('{"v":1}', text, 'the document');
      CheckEquals('GET', fake.Last.Method, 'method');
      CheckEquals('UA-1', fake.Last.UserAgent, 'user agent');
      CheckTrue(fake.Last.FollowRedirects, 'redirects asked for');
      CheckFalse(fake.Last.AcceptAnyStatus, 'only 200 is an answer');
      CheckFalse(fake.Last.HasBody, 'no body, so no Content-Length');
      CheckEquals(5000, fake.Last.ConnectMs, 'connect timeout');
      CheckEquals(6000, fake.Last.IOMs, 'io timeout');
      CheckTrue(fake.Last.VerifyServer, 'verification on');

      fake.ScriptFailure := hfTrustUnavailable;
      fake.ScriptErrorMessage := 'test-only: no bundle';
      CheckFalse(HttpGetText('https://tr4w.invalid/version.json', text, reason), 'refused');
      CheckTrue(Pos('REFUSED', reason) > 0, 'with the refusal sentence: ' + reason);
      CheckEquals('', text, 'and no text');
   finally
      SetHttpTransportForTest(nil);
      fake.Free;
   end;
end;

procedure THttpTransportTests.Test_DownloadWritesTheFileAndARefusalMakesNone;
var
   fake:   TFakeHttpTransport;
   folder, target, reason: string;
begin
   BeginTest('DownloadFileToPath: the file arrives atomically; a refusal or a failure leaves no .tmp and no target');
   DeclareVerifyOn;
   folder := IncludeTrailingPathDelimiter(GetTempDir(False)) + 'tr4w-transport-' +
             IntToStr(Random(100000000)) + PathDelim;
   ForceDirectories(folder);
   target := folder + 'file.dat';
   fake := TFakeHttpTransport.Create;
   fake.ScriptStatus := 200;
   fake.ScriptBody   := ToWire('payload');
   SetHttpTransportForTest(fake);
   try
      CheckTrue(DownloadFileToPath('https://tr4w.invalid/file.dat', target, reason),
                'downloaded: ' + reason);
      CheckTrue(fake.LastHadSink, 'streamed to a sink');
      CheckTrue(FileExists(target), 'the file is there');
      CheckFalse(FileExists(target + '.tmp'), 'and the .tmp is gone');
      SysUtils.DeleteFile(target);

      fake.ScriptFailure := hfTrustUnavailable;
      fake.ScriptErrorMessage := 'test-only: no bundle';
      CheckFalse(DownloadFileToPath('https://tr4w.invalid/file.dat', target, reason), 'refused');
      CheckFalse(FileExists(target), 'no target');
      CheckFalse(FileExists(target + '.tmp'), 'no .tmp left behind');

      fake.ScriptFailure := hfOther;
      fake.ScriptErrorClass := 'EFault';
      fake.ScriptErrorMessage := 'connection reset';
      CheckFalse(DownloadFileToPath('https://tr4w.invalid/file.dat', target, reason), 'failed');
      CheckEquals('connection reset', reason, 'with the library''s words as the reason');
      CheckFalse(FileExists(target + '.tmp'), 'no .tmp left behind');

      (* A failed download never replaces a good file. *)
      fake.ScriptFailure := hfNone;
      CheckTrue(DownloadFileToPath('https://tr4w.invalid/file.dat', target, reason), 'good again');
      fake.ScriptFailure := hfOther;
      CheckFalse(DownloadFileToPath('https://tr4w.invalid/file.dat', target, reason), 'failed again');
      CheckTrue(FileExists(target), 'the good file survives');
   finally
      SetHttpTransportForTest(nil);
      fake.Free;
      SysUtils.DeleteFile(target);
      SysUtils.DeleteFile(target + '.tmp');
      RemoveDir(folder);
   end;
end;

procedure THttpTransportTests.Test_ConditionalDownloadOutcomes;
var
   fake:   TFakeHttpTransport;
   folder, target, reason, etag, modified, ctype: string;
   status: integer;
   outcome: TConditionalDownloadOutcome;
begin
   BeginTest('DownloadFileConditional: outcomes, request headers, response validators, no leftover file');
   DeclareVerifyOn;
   folder := IncludeTrailingPathDelimiter(GetTempDir(False)) + 'tr4w-cond-' +
             IntToStr(Random(100000000)) + PathDelim;
   ForceDirectories(folder);
   target := folder + 'file.tmp';
   fake := TFakeHttpTransport.Create;
   SetHttpTransportForTest(fake);
   try
      (* 200: the body arrives, the validators come back, the request carried the condition. *)
      fake.ScriptStatus       := 200;
      fake.ScriptBody         := ToWire('payload');
      fake.ScriptETag         := '"abc"';
      fake.ScriptLastModified := 'Sat, 01 Nov 2025 00:00:00 GMT';
      fake.ScriptContentType  := 'text/plain';
      outcome := DownloadFileConditional('https://tr4w.invalid/f.txt', target, 'TR4W/test',
                                         '"old"', 'Fri, 31 Oct 2025 00:00:00 GMT',
                                         etag, modified, ctype, status, reason);
      CheckTrue(outcome = cdoUpdated, '200 is Updated');
      CheckTrue(FileExists(target), 'the body is in the target');
      CheckEquals('"abc"', etag, 'ETag back');
      CheckEquals('Sat, 01 Nov 2025 00:00:00 GMT', modified, 'Last-Modified back');
      CheckEquals('text/plain', ctype, 'Content-Type back');
      CheckEquals('"old"', fake.Last.IfNoneMatch, 'If-None-Match went out');
      CheckEquals('Fri, 31 Oct 2025 00:00:00 GMT', fake.Last.IfModifiedSince, 'If-Modified-Since went out');
      CheckEquals('TR4W/test', fake.Last.UserAgent, 'User-Agent as given');
      CheckTrue(fake.Last.AcceptAnyStatus, 'every status is an answer');
      CheckTrue(fake.Last.FollowRedirects, 'redirects followed');

      (* No condition held: neither header. *)
      DownloadFileConditional('https://tr4w.invalid/f.txt', target, 'TR4W/test', '', '',
                              etag, modified, ctype, status, reason);
      CheckEquals('', fake.Last.IfNoneMatch, 'no If-None-Match when none held');
      CheckEquals('', fake.Last.IfModifiedSince, 'no If-Modified-Since when none held');

      (* 304: nothing written, the target is removed. *)
      fake.ScriptStatus := 304;
      fake.ScriptBody   := '';
      outcome := DownloadFileConditional('https://tr4w.invalid/f.txt', target, 'TR4W/test',
                                         '"abc"', '', etag, modified, ctype, status, reason);
      CheckTrue(outcome = cdoNotModified, '304 is NotModified');
      CheckEquals(304, status, 'status 304');
      CheckFalse(FileExists(target), 'no file for a 304');

      (* 404 with a body: no file left. *)
      fake.ScriptStatus := 404;
      fake.ScriptBody   := ToWire('<html>not here</html>');
      outcome := DownloadFileConditional('https://tr4w.invalid/f.txt', target, 'TR4W/test',
                                         '', '', etag, modified, ctype, status, reason);
      CheckTrue(outcome = cdoNotFound, '404 is NotFound');
      CheckFalse(FileExists(target), 'the 404 page is not kept');

      (* 429 and 503: HttpError carrying the status. *)
      fake.ScriptStatus := 429;
      outcome := DownloadFileConditional('https://tr4w.invalid/f.txt', target, 'TR4W/test',
                                         '', '', etag, modified, ctype, status, reason);
      CheckTrue(outcome = cdoHttpError, '429 is HttpError');
      CheckEquals(429, status, 'status 429');
      CheckFalse(FileExists(target), 'no file for a 429');
      fake.ScriptStatus := 503;
      outcome := DownloadFileConditional('https://tr4w.invalid/f.txt', target, 'TR4W/test',
                                         '', '', etag, modified, ctype, status, reason);
      CheckTrue(outcome = cdoHttpError, '503 is HttpError');

      (* No answer: TransportFail with the reason, no file. *)
      fake.ScriptStatus       := 0;
      fake.ScriptFailure      := hfOther;
      fake.ScriptErrorClass   := 'EFault';
      fake.ScriptErrorMessage := 'connection reset';
      outcome := DownloadFileConditional('https://tr4w.invalid/f.txt', target, 'TR4W/test',
                                         '', '', etag, modified, ctype, status, reason);
      CheckTrue(outcome = cdoTransportFail, 'no answer is TransportFail');
      CheckEquals('connection reset', reason, 'with the reason');
      CheckFalse(FileExists(target), 'no file');

      (* Plain http is refused before the transport is asked. *)
      fake.Calls := 0;
      outcome := DownloadFileConditional('http://tr4w.invalid/f.txt', target, 'TR4W/test',
                                         '', '', etag, modified, ctype, status, reason);
      CheckTrue(outcome = cdoTransportFail, 'plaintext refused');
      CheckEquals(0, fake.Calls, 'the transport was not asked');
      CheckFalse(FileExists(target), 'no file');
   finally
      SetHttpTransportForTest(nil);
      fake.Free;
      SysUtils.DeleteFile(target);
      RemoveDir(folder);
   end;
end;

procedure THttpTransportTests.Test_NoTransportFailsClosed;
var
   request: THttpRequest;
   text, reason: string;
begin
   BeginTest('an empty registry fails closed with a reason, never an access violation');
   SetHttpTransportForTest(nil);
   UnregisterHttpTransport(TGenericHttpTransport);
   HideRealPlatformTransports;
   ResetHttpTransportSelection;
   try
      CheckTrue(ActiveHttpTransport(HTTP_TRANSPORT_GENERIC) = nil, 'nothing is selected');
      CheckTrue(ActiveHttpTransport(HTTP_TRANSPORT_AUTO) = nil, 'nor for auto');
      request := THttpRequest.Create('https://api.invalid/x');
      try
         CheckFalse(request.Send, 'the request fails');
         CheckTrue(request.FailReason <> '', 'and says why');
         CheckFalse(request.NothingSent, 'nothing is claimed');
      finally
         request.Free;
      end;
      CheckFalse(HttpGetText('https://api.invalid/x', text, reason), 'the GET verb too');
      CheckTrue(reason <> '', 'with a reason');
   finally
      RegisterHttpTransport(TGenericHttpTransport, False);
      RestoreRealPlatformTransports;
      ResetHttpTransportSelection;
   end;
   CheckEquals('generic', ActiveHttpTransport(HTTP_TRANSPORT_GENERIC).Id, 'the generic transport is back');
end;

(* A NEW instance of the transport under test. The contract tests call this and
  nothing else, so they cannot silently test the wrong transport (design 5.2:
  never go through the registry here). *)
function THttpTransportTests.NewTransport: TPlatformHttpTransport;
begin
   Result := nil;
{$IFDEF WINDOWS}
   if FUseWinHttp then
      begin
      Result := TWinHttpTransport.Create;
      end;
{$ENDIF}
   if Result = nil then
      begin
      Result := TGenericHttpTransport.Create;
      end;
end;

(* THE CONTRACT, once per transport this platform has. The TLS refusal test is
  the generic transport's alone (it forces OpenSSL unavailable, which WinHTTP
  does not use); TLS correctness for WinHTTP is a bench item (design 5.4). *)
procedure THttpTransportTests.RunContract;
begin
   Test_NothingSentTable;
   Test_AnyStatusIsAnAnswerWhenAsked;
   Test_OnlyOkIsAnAnswerWhenNotAsked;
   Test_HeadersAndBodyBytes;
   Test_BasicAuthIsPreemptive;
   Test_ResponseHeadersAreReturned;
   Test_ConditionalHeadersGoOutAndComeBack;
   Test_ResponseCap;
   Test_SinkReceivesTheBody;
   Test_RedirectsOnlyWhenAsked;
   Test_AGetStillFollowsARedirect;
   Test_ARefusedConnectionIsNotProvedUnsent;
   if not FUseWinHttp then
      begin
      Test_TlsUnavailableIsProvedUnsent;
      end;
   Test_ExecuteNeverRaisesAndClearsTheResult;
   Test_BadUrlsAreFailuresNotExceptions;
   Test_AnAttachedEmptyBodySendsContentLengthZero;
   Test_TheBodyIsNotDecompressed;
   Test_ASilentServerTimesOutAfterTheRequestWent;
end;

procedure THttpTransportTests.RunAllTests;
begin
   GCaptured := TStringList.Create;
   FLock := TCriticalSection.Create;
   try
      FUseWinHttp := False;
      FTag        := '';
      RunContract;
{$IFDEF WINDOWS}
      FUseWinHttp := True;
      FTag        := '[winhttp] ';
      RunContract;
      FUseWinHttp := False;
      FTag        := '';
{$ENDIF}
      Test_RegistrySelectsOnceAndLogsOnce;
      Test_ThePolicyChoosesTheTransport;
      Test_TheSettingDefaultsToGenericAndTheSharedLayerReadsIt;
      Test_SchemeAndBearerPolicyRefuseWithoutTheTransport;
      Test_SendBuildsTheWireRequest;
      Test_ThePostVerbDefaultsReachTheWire;
      Test_TransportErrorTextCannotReachALogOrTheOperator;
      Test_FailureKindsReachTheFlags;
      Test_VerifyOffReachesTheWire;
      Test_GetTextBuildsAGetAndReturnsTheBody;
      Test_DownloadWritesTheFileAndARefusalMakesNone;
      Test_ConditionalDownloadOutcomes;
      Test_NoTransportFailsClosed;
   finally
      StopServer;
      FreeAndNil(FLock);
      FreeAndNil(GCaptured);
   end;
end;

end.
