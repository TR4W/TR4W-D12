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
      procedure Test_StationInfoUrl;
      procedure Test_ParseStations;
      procedure Test_FindOutcomeText;
      procedure Test_FindRequestShape_AndRefusals;
      procedure Test_FindKeyInThePathIsNeverLogged;
      procedure Test_FindIsADeclaredFinderOnTheProfileRow;
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
                 const aBase: string = BASE;
                 aAllowInsecure: boolean = False): TExternalDeliveryResult;
var
   client: TCloudlogClient;
begin
   SetHttpTransportForTest(aFake);
   client := TCloudlogClient.Create(aBase, PROFILE, KEY);
   client.AllowInsecure := aAllowInsecure;
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
   CheckEquals('CLOUDLOG_STATION_NOT_OWNED', r.ErrorCode, 'the reason names the cause');
   CheckTrue(r.Pause, 'still paused');
   r := Answer(401, '{"status":"failed","reason":"station callsign does not match station callsign in station profile."}');
   CheckEquals(401, r.Status);
   CheckEquals('CLOUDLOG_CALLSIGN_MISMATCH', r.ErrorCode);
   r := Answer(401, '{"status":"failed","reason":"missing or invalid api key"}');
   CheckEquals('CLOUDLOG_KEY_REJECTED', r.ErrorCode);
   r := Answer(401, '{"status":"failed","reason":"missing api key"}');
   CheckEquals('CLOUDLOG_KEY_REJECTED', r.ErrorCode);
   r := Answer(401, '{"status":"failed","reason":"QSO Call is empty."}');
   CheckEquals('CLOUDLOG_UNAUTHORIZED', r.ErrorCode, 'an unlisted reason keeps the generic code');
   r := Answer(401, '<html>no</html>');
   CheckEquals('CLOUDLOG_UNAUTHORIZED', r.ErrorCode, 'an unreadable body keeps the generic code');
   r := Answer(401, '');
   CheckEquals('CLOUDLOG_UNAUTHORIZED', r.ErrorCode, 'no body keeps the generic code');
   CheckEquals('CLOUDLOG_UNAUTHORIZED', CloudlogUnauthorizedCode('[1,2]'), 'a non-object body');
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
      CheckEquals('CLOUDLOG_INSECURE_URL_REFUSED', r.ErrorCode, 'plain http has its own code (2026-11-24)');
      CheckEquals(SLoggerPlainHttpRefusedNotice, r.OperatorNotice, 'and is SAID, once, through the owner');
      r := Deliver(fake, NewJob, 'log.example.test');
      CheckEquals('CLOUDLOG_URL_REFUSED', r.ErrorCode, 'no scheme');
      CheckEquals('', r.OperatorNotice, 'no notice for a scheme-less address');
   finally
      fake.Free;
   end;
   (* THE OPERATOR TICKED "Allow insecure": the same address now reaches the wire. *)
   fake := Scripted(201, '{"status":"created","imported_count":1}');
   try
      r := Deliver(fake, NewJob, 'http://192.168.1.5', True);
      CheckEquals(1, fake.Calls, 'Allow insecure: plain http is sent');
      CheckTrue(r.Outcome = doConfirmed, 'and the contact is delivered');
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
   r := Answer(303, '');
   CheckTrue(r.Outcome = doUncertain, '303 means the POST was handled (issue 255): uncertain, never "nothing imported"');
   CheckTrue(r.Pause, 'and paused');
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
      CheckEquals(5, fields.Count, 'address, key, profile, certificate choice (issue 256), allow insecure (2026-11-24)');
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
      CheckEquals(LF_VERIFY_SERVER, fields[3].Key);
      CheckTrue(fields[3].Kind = lfkCheck, 'the certificate choice is a check box');
      CheckEquals(LF_ALLOW_INSECURE, fields[4].Key, 'allow insecure follows it');
      CheckTrue(fields[4].Kind = lfkCheck, 'a check box, off by default');
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

(* ---- The editor's Find... (station_info), 2026-11-24 ---- *)

(* One Find through LoadCloudlogStations, the loader the editor runs, with the
   editor's unsaved values in a work copy. *)
function FindStations(aFake: TFakeHttpTransport; const aBase, aKey: string;
                      aAllowInsecure: boolean;
                      const aChoices: TLoggerChoices): string;
var
   d: TExternalLoggerDefinition;
begin
   SetHttpTransportForTest(aFake);
   d := TExternalLoggerDefinition.Create;
   try
      d.ProviderId := 'CLOUDLOG';
      d.Name := 'Shack';
      d.URL := aBase;
      d.ApiKey := aKey;
      d.AllowInsecure := aAllowInsecure;
      d.VerifyServer := True;
      Result := LoadCloudlogStations(d, aChoices);
   finally
      d.Free;
      SetHttpTransportForTest(nil);
   end;
end;

const
   STATIONS_BODY =
      '[{"station_id":"2","station_profile_name":"Home-EL88","station_callsign":"NY4I","station_gridsquare":"EL88","station_active":"1"},' +
      '{"station_id":3,"station_profile_name":"Old QTH","station_callsign":"NY4I","station_active":"0"}]';

procedure TCloudlogTests.Test_StationInfoUrl;
begin
   BeginTest('Find: the address is the base plus /api/station_info/ plus the key as one path segment');
   CheckEquals('https://h.test/api/station_info/abc123', CloudlogStationInfoUrl('https://h.test', 'abc123'));
   CheckEquals('https://h.test/api/station_info/abc123', CloudlogStationInfoUrl(' https://h.test/// ', 'abc123'),
               'trailing slashes and blanks tidied');
   CheckEquals('https://h.test/index.php/api/station_info/abc123',
               CloudlogStationInfoUrl('https://h.test/index.php/', 'abc123'), 'an index.php instance');
   CheckEquals('https://h.test/api/station_info/' + EncodeUrlSegment('a/b c'),
               CloudlogStationInfoUrl('https://h.test', 'a/b c'), 'a key with / or a blank cannot add path segments');
   CheckTrue(Pos('a/b', CloudlogStationInfoUrl('https://h.test', 'a/b c')) = 0, 'the slash is encoded');
end;

procedure TCloudlogTests.Test_ParseStations;
var
   c: TLoggerChoices;
begin
   BeginTest('Find: the station list parses numeric and string ids, inactive flags, and tolerates the rest');
   c := TLoggerChoices.Create;
   try
      CheckTrue(CloudlogParseStations(STATIONS_BODY, c), 'a list');
      CheckEquals(2, c.Count);
      CheckEquals('2', c.Value[0], 'string id');
      CheckEquals('2 - Home-EL88 (NY4I)', c.Display[0]);
      CheckEquals('3', c.Value[1], 'numeric id');
      CheckEquals('3 - Old QTH (NY4I) [' + SLoggerFindInactive + ']', c.Display[1], 'inactive is marked');
   finally
      c.Free;
   end;
   c := TLoggerChoices.Create;
   try
      CheckTrue(CloudlogParseStations(
         '[{"station_id":"5"},{"station_id":6,"station_active":0,"station_profile_name":"P"},' +
         '{"station_id":7,"station_active":false},{"station_id":8,"station_active":true,"x":{"y":1},"station_country":"USA"},' +
         '{"station_id":9,"station_active":null,"station_profile_name":null,"station_callsign":null},{"station_id":"","station_profile_name":"no id"},' +
         '{"station_profile_name":"missing id"},{"station_id":"abc"},"junk",42,{"station_id":10,"station_callsign":"W1AW"}]', c),
         'tolerant');
      CheckEquals(6, c.Count, 'ids 5..10: a missing, empty or non-numeric id and non-objects are skipped');
      CheckEquals('5', c.Display[0], 'only an id');
      CheckEquals('6 - P [' + SLoggerFindInactive + ']', c.Display[1], 'numeric 0');
      CheckEquals('7 [' + SLoggerFindInactive + ']', c.Display[2], 'boolean false');
      CheckEquals('8', c.Display[3], 'true and extra Wavelog fields');
      CheckEquals('9', c.Display[4], 'null is not marked');
      CheckEquals('10 (W1AW)', c.Display[5], 'no name');
   finally
      c.Free;
   end;
   c := TLoggerChoices.Create;
   try
      CheckTrue(CloudlogParseStations('[]', c), 'an empty list is a list');
      CheckEquals(0, c.Count);
      CheckFalse(CloudlogParseStations('{"status":"failed","reason":"missing or invalid api key"}', c), 'an object');
      CheckFalse(CloudlogParseStations('<html>nope</html>', c), 'html');
      CheckFalse(CloudlogParseStations('', c), 'nothing');
   finally
      c.Free;
   end;
end;

procedure TCloudlogTests.Test_FindOutcomeText;
var
   c: TLoggerChoices;
   f: THttpFailure;

   function Say(aFailure: THttpFailure; aStatus: integer; const aBody: string): string;
   begin
      c.Clear;
      Result := CloudlogFindOutcomeText(aFailure, aStatus, aBody, c);
   end;
begin
   BeginTest('Find: every outcome reads as one sentence, success as none');
   c := TLoggerChoices.Create;
   try
      CheckEquals('', Say(hfNone, 200, STATIONS_BODY), 'success');
      CheckEquals(SLoggerFindEmpty, Say(hfNone, 200, '[]'), 'empty list');
      CheckEquals(SLoggerFindNotList, Say(hfNone, 200, '<html>login</html>'), 'not JSON');
      CheckEquals(SLoggerFindNotList, Say(hfNone, 200, '{"a":1}'), 'not a list');
      CheckEquals(SLoggerFind401, Say(hfNone, 401, '{"status":"failed","reason":"missing or invalid api key"}'), '401');
      CheckEquals(SLoggerFind404, Say(hfNone, 404, ''), '404 mentions index.php');
      CheckTrue(Pos('/index.php', SLoggerFind404) > 0, 'the 404 sentence names /index.php');
      CheckEquals(SLoggerWhyCloudlogRedirect, Say(hfNone, 302, ''), 'a redirect');
      CheckEquals(UnicodeFormat(SLoggerFindHttp, [500]), Say(hfNone, 500, ''), 'other status');
      CheckEquals(SLoggerFindPlainHttp, Say(hfPlaintextNotAllowed, 0, ''), 'plain http is said');
      CheckEquals(SLoggerFindBadAddress, Say(hfBadScheme, 0, ''), 'bad scheme');
      CheckEquals(SLoggerFindSecure, Say(hfTrustUnavailable, 0, ''), 'no CA bundle');
      CheckEquals(SLoggerFindSecure, Say(hfVerificationFailed, 0, ''), 'certificate refused');
      CheckEquals(SLoggerFindNoAnswer, Say(hfCannotConnect, 0, ''), 'cannot connect');
      for f := Low(THttpFailure) to High(THttpFailure) do
         begin
         if f <> hfNone then
            begin
            CheckTrue(Say(f, 0, '') <> '', 'a failure kind always has a sentence');
            end;
         end;
   finally
      c.Free;
   end;
end;

procedure TCloudlogTests.Test_FindRequestShape_AndRefusals;
var
   fake: TFakeHttpTransport;
   c: TLoggerChoices;
   text: string;
begin
   BeginTest('Find: ONE read-only GET of station_info with the editor''s values; refusals send nothing');
   DeclareVerifyOn;
   c := TLoggerChoices.Create;
   fake := Scripted(200, STATIONS_BODY);
   try
      text := FindStations(fake, BASE + '/index.php/', KEY, False, c);
      CheckEquals('', text, 'found');
      CheckEquals(2, c.Count);
      CheckEquals(1, fake.Calls, 'one request');
      CheckEquals('GET', fake.Last.Method);
      CheckEquals(BASE + '/index.php/api/station_info/' + EncodeUrlSegment(KEY), fake.Last.URL);
      CheckEquals(KEY, fake.Last.Password, 'the key is named so it is scrubbed');
      CheckEquals('', fake.Last.Username, 'no basic-auth header');
      CheckEquals('', fake.Last.BearerToken, 'no bearer header');
      CheckFalse(fake.Last.FollowRedirects, 'a redirect is reported, not followed');
      CheckTrue(fake.Last.ConnectMs > 0, 'a connect timeout is set');
      CheckTrue(fake.Last.IOMs > 0, 'a read timeout is set');
      CheckTrue(fake.Last.VerifyServer, 'the editor''s certificate choice');
      (* Plain http: refused in words unless the editor's box is ticked. *)
      c.Clear;
      CheckEquals(SLoggerFindPlainHttp, FindStations(fake, 'http://192.168.1.5', KEY, False, c),
                  'plain http without Allow insecure');
      CheckEquals(1, fake.Calls, 'nothing was sent');
      c.Clear;
      CheckEquals('', FindStations(fake, 'http://192.168.1.5', KEY, True, c), 'plain http with it');
      CheckEquals(2, fake.Calls, 'now it was sent');
      CheckEquals(2, c.Count);
      (* Empty address or key: nothing sent. *)
      CheckEquals(SLoggerFindNoKey, FindStations(fake, BASE, '', False, c), 'no key');
      CheckEquals(SLoggerFindNoAddress, FindStations(fake, '  ', KEY, False, c), 'no address');
      CheckEquals(2, fake.Calls, 'no request for either');
      (* 401 and 404 through the real Send. *)
      fake.ScriptStatus := 401;
      fake.ScriptBody := '{"status":"failed","reason":"missing or invalid api key"}';
      c.Clear;
      CheckEquals(SLoggerFind401, FindStations(fake, BASE, KEY, False, c), '401');
      fake.ScriptStatus := 404;
      CheckEquals(SLoggerFind404, FindStations(fake, BASE, KEY, False, c), '404');
      fake.ScriptStatus := 0;
      fake.ScriptFailure := hfCannotConnect;
      CheckEquals(SLoggerFindNoAnswer, FindStations(fake, BASE, KEY, False, c), 'cannot connect');
      (* A failed 401 body is the one the delivery classifier maps to KEY_REJECTED. *)
      CheckEquals('CLOUDLOG_KEY_REJECTED',
                  CloudlogUnauthorizedCode('{"status":"failed","reason":"missing or invalid api key"}'));
   finally
      fake.Free;
      c.Free;
   end;
end;

procedure TCloudlogTests.Test_FindKeyInThePathIsNeverLogged;
const
   PATHKEY = 'wl/PATH+KEY 0123';
var
   lg: TLogLogger;
   keep: ILogAppender;
   oldLevel: TLogLevel;
   fake: TFakeHttpTransport;
   c: TLoggerChoices;
   request: THttpRequest;
   joined, enc, shown: string;
begin
   BeginTest('Find: the key in the URL PATH is in no log line (success, 401, error text, refusal, redirect), raw or encoded');
   DeclareVerifyOn;
   enc := EncodeUrlSegment(PATHKEY);
   CheckTrue(enc <> PATHKEY, 'the test key needs encoding, so both forms are exercised');
   GCaptured := TStringList.Create;
   lg := TLogLogger.GetLogger('TR4WDebugLog.HTTP');
   oldLevel := lg.Level;
   lg.Level := All;
   keep := TCaptureAppender.Create('unit-test cloudlog find capture');
   lg.AddAppender(keep);
   c := TLoggerChoices.Create;
   fake := Scripted(200, STATIONS_BODY);
   try
      CheckEquals('', FindStations(fake, BASE, PATHKEY, False, c), 'a 200');
      fake.ScriptStatus := 401;
      fake.ScriptBody := '{"status":"failed"}';
      FindStations(fake, BASE, PATHKEY, False, c);
      (* A transport failure whose text echoes the whole URL, key and all. *)
      fake.ScriptStatus := 0;
      fake.ScriptFailure := hfOther;
      fake.ScriptErrorClass := 'Exception';
      fake.ScriptErrorMessage := 'GET ' + BASE + '/api/station_info/' + enc + ' failed; key ' + PATHKEY;
      FindStations(fake, BASE, PATHKEY, False, c);
      (* The shared layer's own refusal line for plain http. *)
      fake.ScriptFailure := hfNone;
      fake.ScriptStatus := 200;
      FindStations(fake, 'http://192.168.1.5', PATHKEY, False, c);
      (* A redirect whose Location and final address carry the key. *)
      fake.ScriptStatus := 302;
      fake.ScriptLocation := BASE + '/other/station_info/' + enc;
      fake.ScriptFinalURL := BASE + '/other/station_info/' + enc;
      FindStations(fake, BASE, PATHKEY, False, c);
      (* FinalURL, which a caller may show, is scrubbed too. *)
      SetHttpTransportForTest(fake);
      request := THttpRequest.Create(CloudlogStationInfoUrl(BASE, PATHKEY));
      try
         request.Method := 'GET';
         request.Password := PATHKEY;
         request.Sensitive := True;
         request.FollowRedirects := True;
         request.Send;
         shown := request.FinalURL + ' ' + request.ErrorDetail + ' ' + request.FailReason;
      finally
         request.Free;
         SetHttpTransportForTest(nil);
      end;
   finally
      lg.RemoveAppender(keep);
      lg.Level := oldLevel;
      fake.Free;
      c.Free;
      joined := GCaptured.Text;
      FreeAndNil(GCaptured);
   end;
   CheckTrue(Pos('station_info/', joined) > 0, 'the requests were logged: ' + joined);
   CheckEquals(0, Pos(PATHKEY, joined), 'the raw key is in no line: ' + joined);
   CheckEquals(0, Pos(enc, joined), 'the encoded key is in no line: ' + joined);
   CheckTrue(Pos('/api/station_info/********', joined) > 0, 'the path shows the mask: ' + joined);
   CheckEquals(0, Pos(PATHKEY, shown), 'FinalURL and the error text hold no raw key: ' + shown);
   CheckEquals(0, Pos(enc, shown), 'nor the encoded key: ' + shown);
end;

procedure TCloudlogTests.Test_FindIsADeclaredFinderOnTheProfileRow;
var
   registration: TExternalLoggerRegistration;
   fields: TLoggerFieldList;
begin
   BeginTest('Find: the profile row stays a plain text row and DECLARES the finder; the editor names no provider');
   CheckTrue(FindExternalLoggerRegistration('CLOUDLOG', registration), 'registered');
   fields := registration.CreateFields;
   try
      CheckTrue(fields[2].Kind = lfkText, 'still text, not a choice');
      CheckFalse(Assigned(fields[2].Loader), 'it has no choice loader');
      CheckTrue(Assigned(fields[2].Finder), 'it has the finder');
      CheckFalse(Assigned(fields[0].Finder), 'no other row has one');
   finally
      fields.Free;
   end;
   CheckTrue(FindExternalLoggerRegistration('WRL', registration), 'WRL registered');
   fields := registration.CreateFields;
   try
      CheckTrue(fields.Find(LF_LOGBOOK).Kind = lfkChoice, 'WRL''s logbook is still a choice');
      CheckFalse(Assigned(fields.Find(LF_LOGBOOK).Finder), 'with no finder');
   finally
      fields.Free;
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
   Test_StationInfoUrl;
   Test_ParseStations;
   Test_FindOutcomeText;
   Test_FindRequestShape_AndRefusals;
   Test_FindKeyInThePathIsNeverLogged;
   Test_FindIsADeclaredFinderOnTheProfileRow;
end;

end.
