unit uTestQRZLogbook;
{$I ..\..\src\tr4w.inc}

(*
  THE QRZ LOGBOOK PROVIDER (issue 310).

  Every request here goes through the REAL THttpRequest.Send into a scripted
  transport (uTestFakeTransport): what is checked is what would be put on the
  wire and what the shared layer would log. No stubbed Send, no network, and NO
  REAL KEY: the key below is a made-up string.

  Pinned: the User-Agent, the form body (key, action, option, ADIF, URL-encoded),
  every RESULT class (OK, REPLACE, FAIL, AUTH, no LOGID, a count other than one,
  an unreadable answer), HTTP 401/403, 429, a 5xx, a network failure classified
  as nothing-sent or uncertain, the key scrubbed from every log line and absent
  from every header, and the durable replay rules: a new contact is an INSERT, an
  edit is delete-then-insert with OPTION=REPLACE, a delete sends the LOGID, a
  failed delete never inserts, and a failed insert after a delete is uncertain.

  NOT covered here, and bench-only (docs/BENCH_QUEUE.md): a real QRZ logbook.
*)

interface

uses
   uTR4WTestFramework;

type
   TQRZLogbookTests = class(TTestCase)
   protected
      procedure Test_UserAgent;
      procedure Test_ParseReply;
      procedure Test_RequestShape_KeyInFormBodyNeverInAHeader;
      procedure Test_Success_OkAndReplace;
      procedure Test_ConfirmationNeedsALogIdAndACountOfOne;
      procedure Test_FailIsARefusalOfThisContact;
      procedure Test_AuthStopsTheWorkerAndKeepsTheWork;
      procedure Test_HttpStatuses;
      procedure Test_RateLimit;
      procedure Test_NetworkFailure_Classified;
      procedure Test_KeyIsNeverLogged;
      procedure Test_Edit_IsDeleteThenInsert;
      procedure Test_Delete;
      procedure Test_FailedDelete_NeverInserts;
      procedure Test_DuplicateRefusal_IsDeliveredWithAnUnknownLogId;
      procedure Test_AMarkedContact_IsNeverDeletedOrReplaced;
      procedure Test_FailedInsertAfterDelete_IsUncertain;
      procedure Test_RecoverUpdatesAsUncertain;
      procedure Test_SetupRequired;
      procedure Test_Descriptors_AndDefinitionError;
      procedure Test_DestinationIdentity;
   public
      procedure RunAllTests; override;
   end;

implementation

uses
   Classes, SysUtils, httpprotocol, Log4D,
   uHTTPDownload, uHttpTransport, uExternalDelivery, uExternalDeliveryClient,
   uQRZLogbookClient, uQRZExternalLogger, uExternalLoggerConfig,
   uExternalLoggerRegistry, uAppStrings, Version, uTestFakeTransport;

const
   KEY = 'QRZFAKE-0123-4567-89AB';
   CALL = 'N0CALL';
   ADIF = '<CALL:4>W1AW<QSO_DATE:8>20261101<TIME_ON:6>123456<BAND:3>20m<EOR>';
   OK_ANSWER = 'RESULT=OK&LOGID=130877825&COUNT=1';

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

(* One delivery through the real Send. aFake is scripted by the caller first. *)
function Deliver(aFake: TFakeHttpTransport; const aJob: TDeliveryJob;
                 const aKey: string = KEY): TExternalDeliveryResult;
var
   client: TQRZLogbookClient;
begin
   SetHttpTransportForTest(aFake);
   client := TQRZLogbookClient.Create(CALL, aKey);
   try
      Result := client.Deliver(aJob);
   finally
      client.Free;
      SetHttpTransportForTest(nil);
   end;
end;

function NewJob: TDeliveryJob;
begin
   Result := Default(TDeliveryJob);
   Result.Payload := ADIF;
end;

function Scripted(aStatus: integer; const aBody: string): TFakeHttpTransport;
begin
   Result := TFakeHttpTransport.Create;
   Result.ScriptStatus := aStatus;
   Result.ScriptBody := UTF8Encode(aBody);
end;

(* Run one scripted answer for a new contact and return the classified result. *)
function Answer(aStatus: integer; const aBody: string): TExternalDeliveryResult;
var
   fake: TFakeHttpTransport;
begin
   fake := Scripted(aStatus, aBody);
   try
      Result := Deliver(fake, NewJob);
   finally
      fake.Free;
   end;
end;

(* The request body as the server would decode one field. *)
function BodyField(const aBody, aName: string): string;
var
   rest, pair: string;
   p: integer;
begin
   Result := '';
   rest := aBody;
   while rest <> '' do
      begin
      p := Pos('&', rest);
      if p = 0 then
         begin
         pair := rest;
         rest := '';
         end
      else
         begin
         pair := Copy(rest, 1, p - 1);
         Delete(rest, 1, p);
         end;
      if Copy(pair, 1, Length(aName) + 1) = aName + '=' then
         begin
         Result := UTF8Decode(HTTPDecode(UTF8Encode(Copy(pair, Length(aName) + 2, Length(pair)))));
         Exit;
         end;
      end;
end;

procedure TQRZLogbookTests.Test_UserAgent;
begin
   BeginTest('QRZ: the User-Agent is TR4W/<version> (CALL), under 128 characters');
   CheckEquals('TR4W/' + TR4W_CURRENTVERSION_NUMBER + ' (N0CALL)', QRZUserAgent('N0CALL'));
   CheckEquals('TR4W/' + TR4W_CURRENTVERSION_NUMBER, QRZUserAgent(''), 'no call, no brackets');
   CheckEquals(127, Length(QRZUserAgent(StringOfChar('X', 300))), 'cut to 127');
end;

procedure TQRZLogbookTests.Test_ParseReply;
var
   r: TQRZReply;
begin
   BeginTest('QRZ: the ampersand-separated answer is parsed, names in any case');
   r := QRZParseReply('RESULT=OK&LOGID=130877825&COUNT=1');
   CheckTrue(r.Valid, 'valid');
   CheckEquals('OK', r.Result);
   CheckEquals('130877825', r.LogId);
   CheckEquals(1, r.Count);
   r := QRZParseReply(' result=replace&logid=9&count=1' + #13#10);
   CheckEquals('REPLACE', r.Result, 'case and whitespace');
   r := QRZParseReply('RESULT=FAIL&REASON=unable to add qso');
   CheckEquals('FAIL', r.Result);
   CheckEquals('unable to add qso', r.Reason);
   CheckEquals(-1, r.Count, 'no count');
   CheckFalse(QRZParseReply('<html>oops</html>').Valid, 'not an answer');
   CheckFalse(QRZParseReply('').Valid, 'empty');
end;

procedure TQRZLogbookTests.Test_RequestShape_KeyInFormBodyNeverInAHeader;
var
   fake: TFakeHttpTransport;
   r: TExternalDeliveryResult;
begin
   BeginTest('QRZ: POST https://logbook.qrz.com/api, KEY and ACTION=INSERT and the ADIF in a form body, no Authorization input');
   DeclareCertificateChecking;
   fake := Scripted(200, OK_ANSWER);
   try
      r := Deliver(fake, NewJob);
      CheckEquals(1, fake.Calls, 'one request');
      CheckEquals('POST', fake.Last.Method);
      CheckEquals('https://logbook.qrz.com/api', fake.Last.URL);
      CheckEquals('application/x-www-form-urlencoded', fake.Last.ContentType);
      CheckEquals(QRZUserAgent(CALL), fake.Last.UserAgent, 'identifies TR4W and the operator');
      CheckEquals('', fake.Last.BearerToken, 'no bearer header: the server reads the body');
      CheckEquals('', fake.Last.Username, 'no Username, so no basic-auth header is made');
      CheckFalse(fake.Last.FollowRedirects, 'redirects are not followed, the key is in the body');
      CheckEquals(KEY, BodyField(FromWire(fake.Last.Body), 'KEY'), 'key');
      CheckEquals('INSERT', BodyField(FromWire(fake.Last.Body), 'ACTION'), 'action');
      CheckEquals(ADIF, BodyField(FromWire(fake.Last.Body), 'ADIF'), 'the ADIF survives the encoding');
      CheckEquals('', BodyField(FromWire(fake.Last.Body), 'OPTION'), 'a new contact does not ask to replace');
      CheckEquals(0, Pos('<', FromWire(fake.Last.Body)), 'the ADIF is URL-encoded on the wire');
   finally
      fake.Free;
   end;
end;

procedure TQRZLogbookTests.Test_Success_OkAndReplace;
var
   r: TExternalDeliveryResult;
begin
   BeginTest('QRZ: RESULT=OK and RESULT=REPLACE with a LOGID are confirmed, the LOGID is the remote identity');
   DeclareCertificateChecking;
   r := Answer(200, OK_ANSWER);
   CheckTrue(r.Outcome = doConfirmed, 'confirmed');
   CheckFalse(r.Pause, 'not paused');
   CheckEquals('', r.ErrorCode);
   CheckEquals(200, r.Status);
   CheckEquals('130877825', r.RemoteId, 'the LOGID, for a later edit or delete');
   r := Answer(200, 'RESULT=REPLACE&LOGID=42&COUNT=1');
   CheckTrue(r.Outcome = doConfirmed, 'REPLACE confirmed');
   CheckEquals('42', r.RemoteId);
   r := Answer(200, 'RESULT=OK&LOGID=43');
   CheckTrue(r.Outcome = doConfirmed, 'an absent COUNT is accepted');
end;

procedure TQRZLogbookTests.Test_ConfirmationNeedsALogIdAndACountOfOne;
var
   r: TExternalDeliveryResult;
begin
   BeginTest('QRZ: an OK that names no usable LOGID, or a count other than one, is not a confirmation');
   DeclareCertificateChecking;
   r := Answer(200, 'RESULT=OK&COUNT=1');
   CheckTrue(r.Outcome = doUncertain, 'no LOGID');
   CheckTrue(r.Pause, 'paused for review');
   CheckEquals('QRZ_LOGID_REQUIRED', r.ErrorCode);
   r := Answer(200, 'RESULT=OK&LOGID=abc&COUNT=1');
   CheckTrue(r.Outcome = doUncertain, 'a LOGID that is not a number');
   r := Answer(200, 'RESULT=OK&LOGID=0&COUNT=1');
   CheckTrue(r.Outcome = doUncertain, 'a LOGID of zero');
   r := Answer(200, 'RESULT=OK&LOGID=5&COUNT=2');
   CheckTrue(r.Outcome = doUncertain, 'more stored than sent: we cannot tell what happened');
   CheckEquals('', r.RemoteId, 'no remote identity is invented');
   r := Answer(200, 'not an answer');
   CheckTrue(r.Outcome = doUncertain, 'unreadable');
   CheckEquals('QRZ_INVALID_RESPONSE', r.ErrorCode);
   r := Answer(200, 'RESULT=SOMETHING');
   CheckTrue(r.Outcome = doUncertain, 'an unknown RESULT is uncertain');
   CheckEquals('QRZ_RESPONSE_REQUIRES_REVIEW', r.ErrorCode);
end;

procedure TQRZLogbookTests.Test_FailIsARefusalOfThisContact;
var
   r: TExternalDeliveryResult;
begin
   BeginTest('QRZ: RESULT=FAIL is a failure of this contact that leaves the destination running');
   DeclareCertificateChecking;
   r := Answer(200, 'RESULT=FAIL&REASON=Unable to add QSO to database');
   CheckTrue(r.Outcome = doFailed, 'failed');
   CheckFalse(r.Pause, 'not paused');
   CheckEquals('QRZ_REJECTED', r.ErrorCode, 'a fixed code, never the server''s words');
   CheckEquals('', r.RemoteId);
end;

procedure TQRZLogbookTests.Test_AuthStopsTheWorkerAndKeepsTheWork;
var
   r: TExternalDeliveryResult;
begin
   BeginTest('QRZ: RESULT=AUTH (bad key, no subscription) and HTTP 401/403 keep the work and pause the destination');
   DeclareCertificateChecking;
   r := Answer(200, 'RESULT=AUTH&REASON=invalid api key');
   CheckTrue(r.Outcome = doRetry, 'the work is kept for a replacement key');
   CheckTrue(r.Pause, 'the worker stops');
   CheckEquals('QRZ_AUTH_REQUIRED', r.ErrorCode);
   r := Answer(401, '');
   CheckTrue(r.Outcome = doRetry, '401');
   CheckTrue(r.Pause);
   CheckEquals('QRZ_AUTH_REQUIRED', r.ErrorCode);
   r := Answer(403, '');
   CheckEquals('QRZ_AUTH_REQUIRED', r.ErrorCode, '403');
end;

procedure TQRZLogbookTests.Test_HttpStatuses;
var
   r: TExternalDeliveryResult;
begin
   BeginTest('QRZ: a redirect or other 4xx is a failure that pauses; a 5xx may have been processed');
   DeclareCertificateChecking;
   r := Answer(404, '<html>not found</html>');
   CheckTrue(r.Outcome = doFailed, '404 failed');
   CheckTrue(r.Pause);
   CheckEquals('QRZ_HTTP_404', r.ErrorCode);
   r := Answer(302, '');
   CheckTrue(r.Outcome = doFailed, 'a redirect is not followed');
   CheckEquals('QRZ_REDIRECT', r.ErrorCode);
   r := Answer(500, 'RESULT=OK&LOGID=5&COUNT=1');
   CheckTrue(r.Outcome = doUncertain, '500: it may have been inserted, the body is not trusted');
   CheckTrue(r.Pause);
   CheckEquals('', r.RemoteId);
end;

procedure TQRZLogbookTests.Test_RateLimit;
var
   fake: TFakeHttpTransport;
   r: TExternalDeliveryResult;
begin
   BeginTest('QRZ: 429 is a retry after Retry-After seconds, 60 when there is none');
   DeclareCertificateChecking;
   fake := Scripted(429, '');
   try
      fake.ScriptRetryAfter := '17';
      r := Deliver(fake, NewJob);
      CheckTrue(r.Outcome = doRetry, 'retry');
      CheckFalse(r.Pause, 'not paused');
      CheckEquals(17, integer(r.RetrySeconds), 'the server''s seconds');
      CheckEquals('QRZ_RATE_LIMITED', r.ErrorCode);
   finally
      fake.Free;
   end;
end;

procedure TQRZLogbookTests.Test_NetworkFailure_Classified;
var
   fake: TFakeHttpTransport;
   r: TExternalDeliveryResult;
begin
   BeginTest('QRZ: a failure that proves nothing was sent is a retry; one that may have been sent is uncertain');
   DeclareCertificateChecking;
   fake := TFakeHttpTransport.Create;
   try
      fake.ScriptFailure := hfTlsUnavailable;
      r := Deliver(fake, NewJob);
      CheckTrue(r.Outcome = doRetry, 'TLS cannot start: retry');
      CheckFalse(r.Pause);
      CheckEquals('QRZ_TLS_UNAVAILABLE', r.ErrorCode);
      CheckEquals(300, integer(r.RetrySeconds));
      fake.ScriptFailure := hfTrustUnavailable;
      r := Deliver(fake, NewJob);
      CheckEquals('QRZ_CA_BUNDLE_MISSING', r.ErrorCode);
      fake.ScriptFailure := hfOther;
      fake.ScriptErrorClass := 'Exception';
      fake.ScriptErrorMessage := 'connection reset';
      r := Deliver(fake, NewJob);
      CheckTrue(r.Outcome = doUncertain, 'may have been sent: never replayed blindly');
      CheckTrue(r.Pause);
      CheckEquals('QRZ_RESPONSE_REQUIRES_REVIEW', r.ErrorCode);
   finally
      fake.Free;
   end;
end;

procedure TQRZLogbookTests.Test_KeyIsNeverLogged;
var
   lg: TLogLogger;
   keep: ILogAppender;
   oldLevel: TLogLevel;
   fake: TFakeHttpTransport;
   r: TExternalDeliveryResult;
   joined: string;
begin
   BeginTest('QRZ: the API key, which travels in the body, is in no log line; the body is logged with it starred');
   DeclareCertificateChecking;
   GCaptured := TStringList.Create;
   lg := TLogLogger.GetLogger('TR4WDebugLog.HTTP');
   oldLevel := lg.Level;
   lg.Level := All;
   keep := TCaptureAppender.Create('unit-test qrz capture');
   lg.AddAppender(keep);
   fake := Scripted(200, OK_ANSWER);
   try
      r := Deliver(fake, NewJob);
      CheckTrue(r.Outcome = doConfirmed, 'delivered');
      (* And a failure whose error text echoes the key. *)
      fake.ScriptFailure := hfOther;
      fake.ScriptErrorClass := 'Exception';
      fake.ScriptErrorMessage := 'rejected ' + KEY;
      r := Deliver(fake, NewJob);
      CheckTrue(r.Outcome = doUncertain, 'the failure is reported');
      CheckEquals(0, Pos(KEY, r.ErrorCode), 'and its code carries no key');
   finally
      lg.RemoveAppender(keep);
      lg.Level := oldLevel;
      fake.Free;
      joined := GCaptured.Text;
      FreeAndNil(GCaptured);
   end;
   CheckEquals(0, Pos(KEY, joined), 'the key is in none of the lines');
   CheckTrue(Pos('KEY=********', joined) > 0, 'the body is logged with the key masked: ' + joined);
   CheckTrue(Pos('POST https://logbook.qrz.com/api', joined) > 0, 'method and URL are logged: ' + joined);
   CheckEquals(0, Pos('Authorization', joined), 'no authorization header of any kind');
end;

procedure TQRZLogbookTests.Test_Edit_IsDeleteThenInsert;
var
   fake: TFakeHttpTransport;
   job: TDeliveryJob;
   r: TExternalDeliveryResult;
   body: string;
begin
   BeginTest('QRZ: an edit of a delivered contact deletes its LOGID, then inserts the new ADIF with OPTION=REPLACE');
   DeclareCertificateChecking;
   fake := Scripted(200, 'RESULT=OK&LOGID=555&COUNT=1');
   try
      job := NewJob;
      job.RemoteId := '130877825';
      r := Deliver(fake, job);
      CheckEquals(2, fake.Calls, 'a delete and an insert');
      body := FromWire(fake.Last.Body);
      CheckEquals('INSERT', BodyField(body, 'ACTION'), 'the last request is the insert');
      CheckEquals('REPLACE', BodyField(body, 'OPTION'));
      CheckEquals(ADIF, BodyField(body, 'ADIF'));
      CheckTrue(r.Outcome = doConfirmed, 'confirmed');
      CheckEquals('555', r.RemoteId, 'the new LOGID replaces the old');
      CheckFalse(r.Deleted, 'an edit is not a deletion');
   finally
      fake.Free;
   end;
end;

procedure TQRZLogbookTests.Test_Delete;
var
   fake: TFakeHttpTransport;
   job: TDeliveryJob;
   r: TExternalDeliveryResult;
   body: string;
begin
   BeginTest('QRZ: a delete sends ACTION=DELETE with the stored LOGID; one never delivered is cancelled locally');
   DeclareCertificateChecking;
   fake := Scripted(200, 'RESULT=OK&LOGIDS=130877825&COUNT=1');
   try
      job := NewJob;
      job.RemoteId := '130877825';
      job.Deleted := True;
      r := Deliver(fake, job);
      CheckEquals(1, fake.Calls, 'one request');
      body := FromWire(fake.Last.Body);
      CheckEquals('DELETE', BodyField(body, 'ACTION'));
      CheckEquals('130877825', BodyField(body, 'LOGIDS'));
      CheckEquals('', BodyField(body, 'ADIF'), 'no record is sent');
      CheckTrue(r.Outcome = doConfirmed, 'confirmed');
      CheckTrue(r.Deleted, 'marked deleted');
      job := NewJob;
      job.Deleted := True;
      r := Deliver(fake, job);
      CheckTrue(r.Outcome = doConfirmed, 'never delivered: cancelled locally');
      CheckEquals(1, fake.Calls, 'with no request');
   finally
      fake.Free;
   end;
end;

procedure TQRZLogbookTests.Test_FailedDelete_NeverInserts;
var
   fake: TFakeHttpTransport;
   job: TDeliveryJob;
   r: TExternalDeliveryResult;
begin
   BeginTest('QRZ: a refused delete never proceeds to the insert; a LOGID that is not a number is refused unsent');
   DeclareCertificateChecking;
   fake := Scripted(200, 'RESULT=FAIL&REASON=not found');
   try
      job := NewJob;
      job.RemoteId := '130877825';
      r := Deliver(fake, job);
      CheckEquals(1, fake.Calls, 'the delete only');
      CheckTrue(r.Outcome = doFailed, 'failed');
      CheckFalse(r.Pause, 'visible, and the destination keeps working');
      CheckEquals('QRZ_DELETE_REJECTED', r.ErrorCode);
      job.RemoteId := '12; DROP';
      r := Deliver(fake, job);
      CheckEquals(1, fake.Calls, 'nothing sent for a malformed LOGID');
      CheckEquals('QRZ_INVALID_LOGID', r.ErrorCode);
      CheckTrue(r.Pause);
      job.RemoteId := '130877825';
      fake.ScriptBody := UTF8Encode('RESULT=AUTH&REASON=key');
      r := Deliver(fake, job);
      CheckEquals('QRZ_AUTH_REQUIRED', r.ErrorCode, 'an AUTH on the delete');
   finally
      fake.Free;
   end;
end;

(* ASSUMED FROM THE GUIDE, never observed: the duplicate refusal text, and that a
   duplicate is a FAIL. The bench item in docs/BENCH_QUEUE.md confirms both. *)
procedure TQRZLogbookTests.Test_DuplicateRefusal_IsDeliveredWithAnUnknownLogId;
var
   r: TExternalDeliveryResult;
begin
   BeginTest('QRZ: a plain insert refused as a duplicate is delivered with an unknown LOGID; any other FAIL is not');
   DeclareCertificateChecking;
   r := Answer(200, 'RESULT=FAIL&REASON=Unable to add QSO to database: duplicate');
   CheckTrue(r.Outcome = doConfirmed, 'the QSO is already on QRZ');
   CheckFalse(r.Pause, 'not paused');
   CheckEquals('', r.ErrorCode);
   CheckEquals(QRZ_DUPLICATE_MARKER, r.RemoteId, 'a marker, not an invented LOGID');
   r := Answer(200, 'RESULT=FAIL&REASON=invalid call');
   CheckTrue(r.Outcome = doFailed, 'another refusal still fails');
   CheckEquals('QRZ_REJECTED', r.ErrorCode);
end;

procedure TQRZLogbookTests.Test_AMarkedContact_IsNeverDeletedOrReplaced;
var
   fake: TFakeHttpTransport;
   job: TDeliveryJob;
   r: TExternalDeliveryResult;
begin
   BeginTest('QRZ: an edit or delete of a contact whose LOGID is unknown sends nothing and fails visibly without pausing');
   DeclareCertificateChecking;
   fake := Scripted(200, OK_ANSWER);
   try
      job := NewJob;
      job.RemoteId := QRZ_DUPLICATE_MARKER;
      r := Deliver(fake, job);
      CheckEquals(0, fake.Calls, 'edit: nothing sent');
      CheckTrue(r.Outcome = doFailed);
      CheckFalse(r.Pause);
      CheckEquals('QRZ_LOGID_UNKNOWN', r.ErrorCode);
      job.Deleted := True;
      r := Deliver(fake, job);
      CheckEquals(0, fake.Calls, 'delete: nothing sent');
      CheckEquals('QRZ_LOGID_UNKNOWN', r.ErrorCode);
   finally
      fake.Free;
   end;
end;

procedure TQRZLogbookTests.Test_FailedInsertAfterDelete_IsUncertain;
var
   fake: TFakeHttpTransport;
   job: TDeliveryJob;
   r: TExternalDeliveryResult;
begin
   BeginTest('QRZ: when the delete took effect and the insert did not, the replacement is uncertain and pauses');
   DeclareCertificateChecking;
   fake := Scripted(200, 'RESULT=OK&LOGIDS=130877825&COUNT=1');
   try
      (* The one scripted answer serves both calls: an OK without a LOGID is the
         delete's good answer AND the insert's unusable one. *)
      job := NewJob;
      job.RemoteId := '130877825';
      r := Deliver(fake, job);
      CheckEquals(2, fake.Calls, 'delete, then insert');
      CheckTrue(r.Outcome = doUncertain, 'the insert named no LOGID');
      CheckTrue(r.Pause);
      CheckEquals('QRZ_REPLACEMENT_REQUIRES_REVIEW', r.ErrorCode);
   finally
      fake.Free;
   end;
end;

procedure TQRZLogbookTests.Test_RecoverUpdatesAsUncertain;
var
   client: TQRZLogbookClient;
begin
   BeginTest('QRZ: an edit is recovered as uncertain after a restart (it may have deleted)');
   client := TQRZLogbookClient.Create(CALL, KEY);
   try
      CheckTrue(client.RecoverUpdatesAsUncertain);
   finally
      client.Free;
   end;
end;

procedure TQRZLogbookTests.Test_SetupRequired;
var
   fake: TFakeHttpTransport;
   r: TExternalDeliveryResult;
begin
   BeginTest('QRZ: no key pauses with its own code and sends nothing');
   fake := TFakeHttpTransport.Create;
   try
      r := Deliver(fake, NewJob, '');
      CheckEquals('QRZ_SETUP_REQUIRED', r.ErrorCode);
      CheckTrue(r.Pause);
      CheckEquals(0, fake.Calls);
   finally
      fake.Free;
   end;
end;

procedure TQRZLogbookTests.Test_Descriptors_AndDefinitionError;
var
   registration: TExternalLoggerRegistration;
   fields: TLoggerFieldList;
   d: TExternalLoggerDefinition;
begin
   BeginTest('Descriptors: QRZ declares the logbook callsign, a secret key and the certificate choice');
   CheckTrue(FindExternalLoggerRegistration('QRZ', registration), 'registered');
   CheckEquals('QRZ Logbook', registration.DisplayName);
   fields := registration.CreateFields;
   try
      CheckEquals(3, fields.Count, 'callsign, key, certificate choice');
      CheckEquals(LF_LOGBOOK, fields[0].Key);
      CheckTrue(fields[0].Kind = lfkText, 'callsign is text');
      CheckTrue(fields[0].Required, 'callsign is required');
      CheckEquals(SLoggerFieldQRZCall, fields[0].Caption, 'translatable caption');
      CheckEquals(LF_API_KEY, fields[1].Key);
      CheckTrue(fields[1].Kind = lfkSecret, 'the key is a masked secret');
      CheckFalse(fields[1].Required, 'a locked vault leaves the key empty and the logger must still start');
      CheckEquals(SLoggerFieldQRZKey, fields[1].Caption);
      CheckEquals(LF_VERIFY_SERVER, fields[2].Key);
      CheckTrue(fields[2].Kind = lfkCheck, 'the certificate choice is a check box');
   finally
      fields.Free;
   end;
   BeginTest('Definition check: the callsign is required, the key is not');
   d := TExternalLoggerDefinition.Create;
   try
      d.ProviderId := 'QRZ';
      d.Name := 'Home';
      CheckTrue(ExternalLoggerDefinitionError(d) <> '', 'empty: refused');
      d.Logbook := CALL;
      CheckEquals('', ExternalLoggerDefinitionError(d), 'callsign alone: accepted without a key');
   finally
      d.Free;
   end;
end;

procedure TQRZLogbookTests.Test_DestinationIdentity;
var
   d: TExternalLoggerDefinition;
   first: string;
begin
   BeginTest('Destination identity: the callsign moves the queue, the key does not');
   d := TExternalLoggerDefinition.Create;
   try
      d.ProviderId := 'QRZ';
      d.Id := 'fixed';
      d.Logbook := CALL;
      d.ApiKey := KEY;
      first := d.DeliveryId;
      d.ApiKey := 'another-key';
      CheckEquals(first, d.DeliveryId, 'a replaced key keeps the backlog');
      d.Logbook := 'W1AW';
      CheckTrue(first <> d.DeliveryId, 'another callsign parks the old backlog');
   finally
      d.Free;
   end;
end;

procedure TQRZLogbookTests.RunAllTests;
begin
   Test_UserAgent;
   Test_ParseReply;
   Test_RequestShape_KeyInFormBodyNeverInAHeader;
   Test_Success_OkAndReplace;
   Test_ConfirmationNeedsALogIdAndACountOfOne;
   Test_FailIsARefusalOfThisContact;
   Test_AuthStopsTheWorkerAndKeepsTheWork;
   Test_HttpStatuses;
   Test_RateLimit;
   Test_NetworkFailure_Classified;
   Test_KeyIsNeverLogged;
   Test_Edit_IsDeleteThenInsert;
   Test_Delete;
   Test_FailedDelete_NeverInserts;
   Test_DuplicateRefusal_IsDeliveredWithAnUnknownLogId;
   Test_AMarkedContact_IsNeverDeletedOrReplaced;
   Test_FailedInsertAfterDelete_IsUncertain;
   Test_RecoverUpdatesAsUncertain;
   Test_SetupRequired;
   Test_Descriptors_AndDefinitionError;
   Test_DestinationIdentity;
end;

end.
