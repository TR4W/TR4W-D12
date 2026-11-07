unit uTestCloudlog;
{$I ..\..\src\tr4w.inc}

(*
  THE CLOUDLOG / WAVELOG PROVIDER (issue 204).

  Every request here goes through the REAL THttpRequest.Send into a scripted
  transport (uTestFakeTransport), so what is checked is what would be put on the
  wire and what the shared layer would log: no stubbed Send, no network.

  Pinned: success on both servers' answers (201 and the count), a count that
  does not match what was sent, 400 abort, 401, 403, 200 status:failed, 429
  with and without Retry-After, a network failure classified as nothing-sent or
  uncertain, an http:// address refused, the key scrubbed from every log line
  and absent from every header, the request body, and the edit/delete policy:
  neither server has an edit or delete call, so an edit or a delete of a contact
  already delivered is a visible failure that does not pause the destination.

  NOT covered here, and bench-only (docs/BENCH_QUEUE.md): a real Cloudlog and a
  real Wavelog instance.
*)

interface

uses
   uTR4WTestFramework;

type
   TCloudlogTests = class(TTestCase)
   protected
      procedure Test_UrlIsBasePlusApiQso;
      procedure Test_RequestShape_KeyInBodyNeverInAHeader;
      procedure Test_Success_Cloudlog;
      procedure Test_Success_Wavelog;
      procedure Test_CountMismatch_IsARefusalNotAConfirmation;
      procedure Test_Http400Abort_IsARefusalOfThisContact;
      procedure Test_Http401And403_StopTheWorkerAndKeepTheWork;
      procedure Test_Status200Failed_IsAMalformedRequest;
      procedure Test_RateLimit_RetriesAfterTheServersSeconds;
      procedure Test_NetworkFailure_Classified;
      procedure Test_OtherStatuses;
      procedure Test_KeyIsNeverLogged;
      procedure Test_EditAndDelete_Policy;
      procedure Test_Descriptors_AndDefinitionError;
      procedure Test_DestinationIdentity;
   public
      procedure RunAllTests; override;
   end;

implementation

uses
   Classes, SysUtils, fpjson, jsonparser, Log4D,
   uJSON, uHTTPDownload, uHttpTransport, uExternalDelivery, uExternalDeliveryClient,
   uCloudlogClient, uCloudlogExternalLogger, uExternalLoggerConfig,
   uExternalLoggerRegistry, uAppStrings, uSettingsRegistry, uSettingsDeclarations,
   uTestFakeTransport;

const
   KEY = 'wl-FAKE-KEY-0123456789abcdef';
   BASE = 'https://log.example.test';
   PROFILE = '7';
   ADIF = '<CALL:4>W1AW<QSO_DATE:8>20261101<TIME_ON:6>123456<BAND:3>20m<EOR>';

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

(* Certificate checking on, as an operator's default, so an https request
  reaches the scripted transport instead of being decided by this machine. *)
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

(* One delivery of one new contact through the real Send. aFake is scripted by
  the caller first; aBase lets a test use an http:// address. *)
function Deliver(aFake: TFakeHttpTransport; const aJob: TDeliveryJob;
                 const aBase: string = BASE): TExternalDeliveryResult;
var
   client: TCloudlogClient;
begin
   SetHttpTransportForTest(aFake);
   client := TCloudlogClient.Create(aBase, PROFILE, KEY);
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

(* Run one scripted answer and return the classified result. *)
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

procedure TCloudlogTests.Test_UrlIsBasePlusApiQso;
begin
   BeginTest('Cloudlog: the request address is the base plus /api/qso, slashes tidied');
   CheckEquals('https://h.test/api/qso', CloudlogQsoUrl('https://h.test'), 'plain base');
   CheckEquals('https://h.test/api/qso', CloudlogQsoUrl('https://h.test///'), 'trailing slashes');
   CheckEquals('https://h.test/index.php/api/qso', CloudlogQsoUrl(' https://h.test/index.php/ '),
               'an index.php instance');
end;

procedure TCloudlogTests.Test_RequestShape_KeyInBodyNeverInAHeader;
var
   fake: TFakeHttpTransport;
   r: TExternalDeliveryResult;
   root: TJSONData;
begin
   BeginTest('Cloudlog: POST <base>/api/qso with the key in the JSON body, no Authorization input');
   DeclareVerifyOn;
   fake := Scripted(201, '{"status":"created","imported_count":1,"messages":[]}');
   try
      r := Deliver(fake, NewJob);
      CheckEquals(1, fake.Calls, 'one request');
      CheckEquals('POST', fake.Last.Method);
      CheckEquals(BASE + '/api/qso', fake.Last.URL);
      CheckEquals('application/json', fake.Last.ContentType);
      CheckEquals('', fake.Last.BearerToken, 'no bearer header: the server reads the body');
      CheckEquals('', fake.Last.Username, 'no Username, so no basic-auth header is made');
      CheckFalse(fake.Last.FollowRedirects, 'redirects are not followed, the key is in the body');
      CheckTrue(fake.Last.MaxResponseBytes >= 65536, 'room for the echoed ADIF in a 201');
      root := GetJSON(UTF8Encode(FromWire(fake.Last.Body)));
      try
         CheckTrue(root.JSONType = jtObject, 'the body is a JSON object');
         CheckEquals(KEY, JSONGetStr(TJSONObject(root), 'key', ''), 'key');
         CheckEquals(PROFILE, JSONGetStr(TJSONObject(root), 'station_profile_id', ''),
                     'station profile');
         CheckEquals('adif', JSONGetStr(TJSONObject(root), 'type', ''), 'type');
         CheckEquals(ADIF, JSONGetStr(TJSONObject(root), 'string', ''), 'the ADIF');
      finally
         root.Free;
      end;
   finally
      fake.Free;
   end;
end;

procedure TCloudlogTests.Test_Success_Cloudlog;
var
   r: TExternalDeliveryResult;
begin
   BeginTest('Cloudlog: 201 created with imported_count 1 is confirmed, with the local marker');
   DeclareVerifyOn;
   r := Answer(201, '{"status":"created","type":"adif","string":"x","imported_count":1,"messages":[]}');
   CheckTrue(r.Outcome = doConfirmed, 'confirmed');
   CheckFalse(r.Pause, 'not paused');
   CheckEquals('', r.ErrorCode);
   CheckEquals(201, r.Status);
   CheckEquals(CLOUDLOG_CREATED_MARKER, r.RemoteId,
               'a nonempty remote identity, or the outbox refuses to settle a creation');
end;

procedure TCloudlogTests.Test_Success_Wavelog;
var
   r: TExternalDeliveryResult;
begin
   BeginTest('Wavelog: 201 created with adif_count 1 and adif_errors 0 is confirmed');
   DeclareVerifyOn;
   r := Answer(201, '{"status":"created","type":"adif","string":"x","adif_count":1,"adif_errors":0,"messages":[""]}');
   CheckTrue(r.Outcome = doConfirmed, 'confirmed');
   CheckFalse(r.Pause);
   CheckEquals(CLOUDLOG_CREATED_MARKER, r.RemoteId);
end;

procedure TCloudlogTests.Test_CountMismatch_IsARefusalNotAConfirmation;
var
   r: TExternalDeliveryResult;
begin
   BeginTest('a 201 that took nothing is a refusal, not a confirmation (Cloudlog answers 201 to a duplicate)');
   DeclareVerifyOn;
   r := Answer(201, '{"status":"created","imported_count":0,"messages":["Duplicate for W1AW"]}');
   CheckTrue(r.Outcome = doFailed, 'Cloudlog imported_count 0: failed');
   CheckFalse(r.Pause, 'one refused contact does not stop the destination');
   CheckEquals('CLOUDLOG_IMPORT_REJECTED', r.ErrorCode);
   CheckEquals('', r.RemoteId, 'no remote identity is invented');
   r := Answer(201, '{"status":"created","adif_count":0,"adif_errors":0,"messages":[""]}');
   CheckTrue(r.Outcome = doFailed, 'Wavelog adif_count 0 (the call was skipped): failed');
   CheckEquals('CLOUDLOG_IMPORT_REJECTED', r.ErrorCode);
   r := Answer(201, '{"status":"created","adif_count":1,"adif_errors":1}');
   CheckTrue(r.Outcome = doFailed, 'Wavelog adif_errors > 0: failed');
   r := Answer(201, '{"status":"created","imported_count":2}');
   CheckTrue(r.Outcome = doUncertain, 'more imported than sent: we cannot tell what happened');
   CheckTrue(r.Pause, 'and it pauses for review');
   r := Answer(201, '{"status":"created"}');
   CheckTrue(r.Outcome = doUncertain, 'no count at all is not a confirmation');
   CheckEquals('CLOUDLOG_RESPONSE_REQUIRES_REVIEW', r.ErrorCode);
   r := Answer(201, 'not json');
   CheckTrue(r.Outcome = doUncertain, 'an unreadable 201 is uncertain');
   CheckEquals('CLOUDLOG_INVALID_RESPONSE', r.ErrorCode);
end;

procedure TCloudlogTests.Test_Http400Abort_IsARefusalOfThisContact;
var
   r: TExternalDeliveryResult;
begin
   BeginTest('Wavelog 400 status abort is a failure of this contact that leaves the destination running');
   DeclareVerifyOn;
   r := Answer(400, '{"status":"abort","adif_count":1,"adif_errors":1,"messages":["Duplicate"]}');
   CheckTrue(r.Outcome = doFailed, 'failed');
   CheckFalse(r.Pause, 'not paused');
   CheckEquals('CLOUDLOG_IMPORT_REJECTED', r.ErrorCode);
   CheckEquals(400, r.Status);
   r := Answer(400, '{"status":"something else"}');
   CheckTrue(r.Outcome = doFailed, 'any other 400 is failed');
   CheckTrue(r.Pause, 'but pauses: it is not the import refusing a contact');
   CheckEquals('CLOUDLOG_HTTP_400', r.ErrorCode);
   r := Answer(400, '<html>bad request</html>');
   CheckTrue(r.Outcome = doFailed, 'an unreadable 400 is still a refusal');
end;

procedure TCloudlogTests.Test_Http401And403_StopTheWorkerAndKeepTheWork;
var
   r: TExternalDeliveryResult;
begin
   BeginTest('401 (key, station profile, STATION_CALLSIGN) and 403 (read-only key) carry their status for the worker to halt on');
   DeclareVerifyOn;
   r := Answer(401, '{"status":"failed","reason":"station id does not belong to the API key owner."}');
   CheckTrue(r.Outcome = doFailed, '401 failed');
   CheckEquals(401, r.Status, 'the worker halts on 401 and keeps the work');
   CheckEquals('CLOUDLOG_UNAUTHORIZED', r.ErrorCode);
   r := Answer(403, '{"status":"failed","reason":"API key does not have write permissions"}');
   CheckTrue(r.Outcome = doFailed, '403 failed');
   CheckEquals(403, r.Status);
   CheckEquals('CLOUDLOG_READ_ONLY_KEY', r.ErrorCode);
end;

procedure TCloudlogTests.Test_Status200Failed_IsAMalformedRequest;
var
   r: TExternalDeliveryResult;
begin
   BeginTest('HTTP 200 with status failed (wrong JSON) is failed and pauses');
   DeclareVerifyOn;
   r := Answer(200, '{"status":"failed","reason":"wrong JSON"}');
   CheckTrue(r.Outcome = doFailed, 'failed');
   CheckTrue(r.Pause, 'a malformed request is a defect: the destination pauses');
   CheckEquals('CLOUDLOG_REQUEST_REFUSED', r.ErrorCode);
   r := Answer(200, '');
   CheckTrue(r.Outcome = doUncertain, 'an empty 200 (Cloudlog does that for type other than adif) is uncertain');
end;

procedure TCloudlogTests.Test_RateLimit_RetriesAfterTheServersSeconds;
var
   fake: TFakeHttpTransport;
   r: TExternalDeliveryResult;
begin
   BeginTest('429 is a retry after Retry-After seconds, 60 when there is none');
   DeclareVerifyOn;
   fake := Scripted(429, '{"status":"failed"}');
   try
      fake.ScriptRetryAfter := '17';
      r := Deliver(fake, NewJob);
      CheckTrue(r.Outcome = doRetry, 'retry');
      CheckFalse(r.Pause, 'not paused');
      CheckEquals(17, integer(r.RetrySeconds), 'the server''s seconds');
      CheckEquals('CLOUDLOG_RATE_LIMITED', r.ErrorCode);
      CheckEquals(429, r.Status);
      fake.ScriptRetryAfter := '';
      r := Deliver(fake, NewJob);
      CheckEquals(60, integer(r.RetrySeconds), 'the default');
   finally
      fake.Free;
   end;
end;

procedure TCloudlogTests.Test_NetworkFailure_Classified;
var
   fake: TFakeHttpTransport;
   r: TExternalDeliveryResult;
begin
   BeginTest('a failure that proves nothing was sent is a retry; one that may have been sent is uncertain; http:// is refused');
   DeclareVerifyOn;
   fake := TFakeHttpTransport.Create;
   try
      fake.ScriptFailure := hfTlsUnavailable;
      r := Deliver(fake, NewJob);
      CheckTrue(r.Outcome = doRetry, 'TLS cannot start: retry');
      CheckFalse(r.Pause);
      CheckEquals('CLOUDLOG_TLS_UNAVAILABLE', r.ErrorCode);
      CheckEquals(300, integer(r.RetrySeconds));
      CheckEquals(0, r.Status, 'nothing was sent');
      fake.ScriptFailure := hfOther;
      fake.ScriptErrorClass := 'Exception';
      fake.ScriptErrorMessage := 'connection reset';
      r := Deliver(fake, NewJob);
      CheckTrue(r.Outcome = doUncertain, 'may have been sent: never replayed blindly');
      CheckTrue(r.Pause);
      CheckEquals('CLOUDLOG_RESPONSE_REQUIRES_REVIEW', r.ErrorCode);
   finally
      fake.Free;
   end;
   fake := TFakeHttpTransport.Create;
   try
      r := Deliver(fake, NewJob, 'http://192.168.1.5');
      CheckEquals(0, fake.Calls, 'plain http never reaches the transport (the key is in the body)');
      CheckTrue(r.Outcome = doFailed, 'refused');
      CheckTrue(r.Pause);
      CheckEquals('CLOUDLOG_URL_REFUSED', r.ErrorCode);
      r := Deliver(fake, NewJob, 'log.example.test');
      CheckEquals('CLOUDLOG_URL_REFUSED', r.ErrorCode, 'no scheme');
   finally
      fake.Free;
   end;
end;

procedure TCloudlogTests.Test_OtherStatuses;
var
   r: TExternalDeliveryResult;
begin
   BeginTest('404 and a redirect are failures that pause (wrong address); a 5xx may have imported');
   DeclareVerifyOn;
   r := Answer(404, '<html>not found</html>');
   CheckTrue(r.Outcome = doFailed, '404 failed');
   CheckTrue(r.Pause);
   CheckEquals('CLOUDLOG_HTTP_404', r.ErrorCode);
   r := Answer(302, '');
   CheckTrue(r.Outcome = doFailed, 'a redirect is not followed');
   CheckEquals('CLOUDLOG_REDIRECT', r.ErrorCode);
   r := Answer(500, '<html>error</html>');
   CheckTrue(r.Outcome = doUncertain, '500: the import may have run');
   CheckTrue(r.Pause);
end;

procedure TCloudlogTests.Test_KeyIsNeverLogged;
var
   lg: TLogLogger;
   keep: ILogAppender;
   oldLevel: TLogLevel;
   fake: TFakeHttpTransport;
   r: TExternalDeliveryResult;
   joined: string;
begin
   BeginTest('the API key, which travels in the body, is in no log line; the body is logged with it starred');
   DeclareVerifyOn;
   GCaptured := TStringList.Create;
   lg := TLogLogger.GetLogger('TR4WDebugLog.HTTP');
   oldLevel := lg.Level;
   lg.Level := All;
   keep := TCaptureAppender.Create('unit-test cloudlog capture');
   lg.AddAppender(keep);
   fake := Scripted(201, '{"status":"created","imported_count":1}');
   try
      r := Deliver(fake, NewJob);
      CheckTrue(r.Outcome = doConfirmed, 'delivered');
      (* And a failure whose error text echoes the key. *)
      fake.ScriptFailure := hfOther;
      fake.ScriptErrorClass := 'Exception';
      fake.ScriptErrorMessage := 'rejected ' + KEY;
      r := Deliver(fake, NewJob);
      CheckTrue(r.Outcome = doUncertain, 'the failure is reported');
   finally
      lg.RemoveAppender(keep);
      lg.Level := oldLevel;
      fake.Free;
      joined := GCaptured.Text;
      FreeAndNil(GCaptured);
   end;
   CheckEquals(0, Pos(KEY, joined), 'the key is in none of the lines: ' + joined);
   CheckTrue(Pos('"********"', joined) > 0, 'the body is logged with the key masked: ' + joined);
   CheckTrue(Pos('POST ' + BASE + '/api/qso', joined) > 0, 'method and URL are logged: ' + joined);
   CheckEquals(0, Pos('Authorization', joined), 'no authorization header of any kind: ' + joined);
end;

procedure TCloudlogTests.Test_EditAndDelete_Policy;
var
   fake: TFakeHttpTransport;
   job: TDeliveryJob;
   r: TExternalDeliveryResult;
begin
   BeginTest('neither server can edit or delete: a delivered contact fails VISIBLY and sends nothing; an undelivered one does not');
   DeclareVerifyOn;
   fake := Scripted(201, '{"status":"created","imported_count":1}');
   try
      job := NewJob;
      job.RemoteId := CLOUDLOG_CREATED_MARKER;
      r := Deliver(fake, job);
      CheckTrue(r.Outcome = doFailed, 'an edit of a delivered contact fails, never reports success');
      CheckEquals('CLOUDLOG_EDIT_UNSUPPORTED', r.ErrorCode);
      CheckFalse(r.Pause, 'and does not halt the destination');
      CheckEquals(0, r.Status, 'no API budget used');
      CheckEquals(0, fake.Calls, 'nothing was sent: a re-POST would be refused as a duplicate or add a second row');
      job.Deleted := True;
      r := Deliver(fake, job);
      CheckTrue(r.Outcome = doFailed, 'a delete of a delivered contact fails');
      CheckEquals('CLOUDLOG_DELETE_UNSUPPORTED', r.ErrorCode);
      CheckFalse(r.Pause);
      CheckEquals(0, fake.Calls, 'still nothing sent');
      job := NewJob;
      job.Deleted := True;
      r := Deliver(fake, job);
      CheckTrue(r.Outcome = doConfirmed, 'a delete of a contact never delivered is cancelled locally');
      CheckEquals(0, fake.Calls, 'with no request');
      job := NewJob;
      r := Deliver(fake, job);
      CheckTrue(r.Outcome = doConfirmed, 'an edit of a contact never delivered (its create was refused) is a create');
      CheckEquals(1, fake.Calls, 'one request');
   finally
      fake.Free;
   end;
   BeginTest('an incomplete setup pauses with its own code and sends nothing');
   fake := TFakeHttpTransport.Create;
   try
      r := Deliver(fake, NewJob, '');
      CheckEquals('CLOUDLOG_SETUP_REQUIRED', r.ErrorCode);
      CheckTrue(r.Pause);
      CheckEquals(0, fake.Calls);
   finally
      fake.Free;
   end;
end;

procedure TCloudlogTests.Test_Descriptors_AndDefinitionError;
var
   registration: TExternalLoggerRegistration;
   fields: TLoggerFieldList;
   d: TExternalLoggerDefinition;
begin
   BeginTest('Descriptors: Cloudlog / Wavelog declares the address, a secret key and the station profile id');
   CheckTrue(FindExternalLoggerRegistration('CLOUDLOG', registration), 'registered');
   CheckEquals('Cloudlog / Wavelog', registration.DisplayName);
   fields := registration.CreateFields;
   try
      CheckEquals(3, fields.Count);
      CheckEquals(LF_URL, fields[0].Key);
      CheckTrue(fields[0].Kind = lfkText, 'address is text');
      CheckTrue(fields[0].Required, 'address is required');
      CheckEquals(SLoggerFieldCloudlogUrl, fields[0].Caption, 'translatable caption');
      CheckEquals(LF_API_KEY, fields[1].Key);
      CheckTrue(fields[1].Kind = lfkSecret, 'the key is a masked secret');
      CheckFalse(fields[1].Required, 'a locked vault leaves the key empty and the logger must still start');
      CheckEquals(LF_LOGBOOK, fields[2].Key);
      CheckTrue(fields[2].Required, 'the station profile is required');
      CheckEquals(SLoggerFieldCloudlogProfile, fields[2].Caption);
   finally
      fields.Free;
   end;
   BeginTest('Definition check: address and profile are required, the key is not');
   d := TExternalLoggerDefinition.Create;
   try
      d.ProviderId := 'CLOUDLOG';
      d.Name := 'Shack';
      CheckTrue(ExternalLoggerDefinitionError(d) <> '', 'empty: refused');
      d.URL := BASE;
      CheckTrue(ExternalLoggerDefinitionError(d) <> '', 'no profile: refused');
      d.Logbook := PROFILE;
      CheckEquals('', ExternalLoggerDefinitionError(d), 'address and profile: accepted without a key');
   finally
      d.Free;
   end;
end;

procedure TCloudlogTests.Test_DestinationIdentity;
var
   d: TExternalLoggerDefinition;
   first: string;
begin
   BeginTest('Destination identity: the address and the profile move the queue, the key does not');
   d := TExternalLoggerDefinition.Create;
   try
      d.ProviderId := 'CLOUDLOG';
      d.Id := 'fixed';
      d.URL := BASE;
      d.Logbook := PROFILE;
      d.ApiKey := KEY;
      first := d.DeliveryId;
      d.ApiKey := 'another-key';
      CheckEquals(first, d.DeliveryId, 'a replaced key keeps the backlog');
      d.URL := 'https://other.example.test';
      CheckTrue(first <> d.DeliveryId, 'another address parks the old backlog');
      d.URL := BASE;
      d.Logbook := '8';
      CheckTrue(first <> d.DeliveryId, 'another station profile parks it too');
   finally
      d.Free;
   end;
end;

procedure TCloudlogTests.RunAllTests;
begin
   Test_UrlIsBasePlusApiQso;
   Test_RequestShape_KeyInBodyNeverInAHeader;
   Test_Success_Cloudlog;
   Test_Success_Wavelog;
   Test_CountMismatch_IsARefusalNotAConfirmation;
   Test_Http400Abort_IsARefusalOfThisContact;
   Test_Http401And403_StopTheWorkerAndKeepTheWork;
   Test_Status200Failed_IsAMalformedRequest;
   Test_RateLimit_RetriesAfterTheServersSeconds;
   Test_NetworkFailure_Classified;
   Test_OtherStatuses;
   Test_KeyIsNeverLogged;
   Test_EditAndDelete_Policy;
   Test_Descriptors_AndDefinitionError;
   Test_DestinationIdentity;
end;

end.
