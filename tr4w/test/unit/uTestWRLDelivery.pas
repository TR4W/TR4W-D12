unit uTestWRLDelivery;
{$I ..\..\src\tr4w.inc}

interface

uses
   SysUtils, sqldb, uTR4WTestFramework, uLogDatabase, uExternalDelivery,
   uWRLClient, uHTTPDownload;

type
   TWRLDeliveryTests = class(TTestCase)
   private
      FFileName: string;
      FDatabase: TLogDatabase;
      FDelivery: TExternalDelivery;
      function Key(const aContact: string = 'contact'): TDeliveryKey;
      procedure OpenFixture;
      procedure CloseFixture;
      function Field(const aName: AnsiString): string;
      procedure TestRevisions;
      procedure TestRecovery;
      procedure TestRollback;
      procedure TestDestinationsAndRetry;
      procedure TestMigration;
      procedure TestClient;
      procedure TestAuthenticationGuards;
      procedure TestADIFMapping;
      procedure TestSavedContactCapture;
      procedure TestClearingFields;
      procedure TestSecretType;
      procedure TestWorkerEditDuringHTTP;
      procedure TestFullContactAndCaptureCost;
      procedure TestMinimalPatch;
   public
      procedure RunAllTests; override;
   end;

implementation

uses
   fpjson, uJSON, uWRLContact, uWRLExternalLogger, uLogRepository,
   uSettingsModel, VC, LogDupe, SyncObjs, uWRLWorker, uQsoMyFacts,
   uContestRegistry, Tree;

type
   TStubRequest = class(THttpRequest)
   public
      function Send: boolean; override;
   end;

   TStubWRLClient = class(TWRLClient)
   protected
      function NewRequest(const aURL: string): THttpRequest; override;
   end;

   TStubWRLWorker = class(TWRLWorker)
   protected
      function NewClient: TWRLClient; override;
   end;

var
   StubStatus: integer;
   StubResponse, StubRetry, LastMethod, LastBody, LastURL: string;
   StubSent: boolean;
   StubInFlight, StubRelease: TEvent;
   StubMethods: string;

function TStubRequest.Send: boolean;
begin
   LastMethod := Method;
   LastBody := Body;
   LastURL := URL;
   StubMethods := StubMethods + Method + ' ';
   if StubInFlight <> nil then
      begin
      StubInFlight.SetEvent;
      StubRelease.WaitFor(5000);
      end;
   StatusCode := StubStatus;
   Response := StubResponse;
   RetryAfter := StubRetry;
   RequestId := 'test-request';
   Result := StubSent;
end;

function TStubWRLWorker.NewClient: TWRLClient;
begin
   Result := TStubWRLClient.Create('test-secret');
end;

function TStubWRLClient.NewRequest(const aURL: string): THttpRequest;
begin
   Result := TStubRequest.Create(aURL);
end;

function TWRLDeliveryTests.Key(const aContact: string): TDeliveryKey;
begin
   Result.Logger := 'WRL';
   Result.Account := 'account';
   Result.Logbook := 'book';
   Result.Contact := aContact;
end;

procedure TWRLDeliveryTests.OpenFixture;
begin
   FFileName := GetTempFileName;
   DeleteFile(FFileName);
   FDatabase := TLogDatabase.Create;
   FDatabase.CreateNew(FFileName);
   FDelivery := TExternalDelivery.Create(FDatabase);
end;

procedure TWRLDeliveryTests.CloseFixture;
begin
   FreeAndNil(FDelivery);
   FreeAndNil(FDatabase);
   DeleteFile(FFileName);
   DeleteFile(FFileName + '-wal');
   DeleteFile(FFileName + '-shm');
end;

function TWRLDeliveryTests.Field(const aName: AnsiString): string;
var
   q: TSQLQuery;
begin
   q := TSQLQuery.Create(nil);
   try
      q.Database := FDatabase.Connection;
      q.Transaction := FDatabase.Transaction;
      q.SQL.Text := 'SELECT ' + aName + ' FROM external_delivery ORDER BY contact LIMIT 1';
      q.Open;
      Result := UTF8Decode(q.Fields[0].AsUTF8String);
   finally
      q.Free;
   end;
end;

procedure TWRLDeliveryTests.TestRevisions;
var
   first, second, none: TDeliveryJob;
   counts: TDeliveryCounts;
begin
   BeginTest('an old completion cannot acknowledge a newer saved edit');
   OpenFixture;
   try
      FDelivery.Enqueue(Key, '{"call":"W1AW"}', False);
      FDatabase.Transaction.Commit;
      counts := ExternalDeliveryCounts(FFileName, 'WRL');
      CheckTrue(counts.Pending = 1, 'Preferences reads a fresh committed snapshot');
      CheckTrue(FDelivery.Claim('WRL', 'account', 0, first));
      FDatabase.Transaction.Commit;
      FDelivery.Enqueue(Key, '{"call":"W2AW"}', False);
      CheckFalse(FDelivery.Claim('WRL', 'account', 0, none), 'one flight per contact');
      FDelivery.Complete(first, doConfirmed, 'abcd-1234', '', '', 0);
      CheckEquals('pending', Field('state'));
      CheckEquals('1', Field('confirmed_revision'));
      CheckTrue(FDelivery.Claim('WRL', 'account', 0, second));
      CheckEquals('abcd-1234', second.RemoteId, 'create ID survives an overlapping edit');
      CheckEquals('{"call":"W2AW"}', second.Payload);
      FDelivery.Complete(first, doConfirmed, 'wrong-id', '', '', 0);
      CheckEquals('inflight', Field('state'), 'stale completion is ignored');
      CheckEquals('abcd-1234', Field('remote_id'));
      FDelivery.Complete(second, doConfirmed, '', '', '', 0);
      CheckEquals('synced', Field('state'));
      CheckEquals('2', Field('confirmed_revision'));
   finally
      CloseFixture;
   end;
end;

procedure TWRLDeliveryTests.TestRecovery;
var
   job: TDeliveryJob;
begin
   BeginTest('a crash after claiming POST leaves creation uncertain across restart');
   OpenFixture;
   try
      FDelivery.Enqueue(Key, '{"call":"W1AW"}', False);
      CheckTrue(FDelivery.Claim('WRL', 'account', 0, job));
      FDatabase.Transaction.Commit;
      FDelivery.Free;
      FDatabase.Close;
      FDatabase.Open(FFileName);
      FDelivery := TExternalDelivery.Create(FDatabase);
      FDelivery.RecoverInterrupted('WRL', 'account');
      CheckEquals('uncertain', Field('state'));
      FDelivery.Enqueue(Key, '{}', True);
      CheckEquals('{"call":"W1AW"}', Field('flight_payload'),
         'preserve the attempted contact even if the local QSO changes before recovery');
      CheckEquals('uncertain', Field('state'), 'deleting cannot erase an uncertain creation');
      CheckFalse(FDelivery.Claim('WRL', 'account', 999, job));
      FDelivery.Enqueue(Key('other'), '{}', False);
      CheckTrue(FDelivery.Claim('WRL', 'account', 999, job), 'unrelated contacts can proceed');
   finally
      CloseFixture;
   end;
end;

procedure TWRLDeliveryTests.TestRollback;
var
   job: TDeliveryJob;
begin
   BeginTest('delivery intent rolls back with its owning QSO transaction');
   OpenFixture;
   try
      FDelivery.Enqueue(Key, '{}', False);
      FDatabase.Transaction.Rollback;
      CheckFalse(FDelivery.Claim('WRL', 'account', 0, job));
   finally
      CloseFixture;
   end;
end;

procedure TWRLDeliveryTests.TestDestinationsAndRetry;
var
   job: TDeliveryJob;
   other: TDeliveryKey;
begin
   BeginTest('retry deadlines and account/logbook identity survive new edits');
   OpenFixture;
   try
      FDelivery.Enqueue(Key, '{}', False);
      CheckTrue(FDelivery.Claim('WRL', 'account', 0, job));
      FDelivery.Complete(job, doRetry, '', 'RATE_LIMITED', 'request', 120);
      FDelivery.Enqueue(Key, '{"call":"W1AW"}', False);
      CheckFalse(FDelivery.Claim('WRL', 'account', 119, job));
      CheckFalse(FDelivery.Claim('WRL', 'different-account', 120, job));
      CheckTrue(FDelivery.Claim('WRL', 'account', 120, job));
      other := Key;
      other.Logbook := 'new-book';
      FDelivery.Enqueue(other, '{}', False);
      CheckTrue(FDelivery.Claim('WRL', 'account', 120, job));
      CheckEquals('new-book', job.Key.Logbook, 'changing logbooks cannot retarget old work');
   finally
      CloseFixture;
   end;
end;

procedure TWRLDeliveryTests.TestMigration;
var
   job: TDeliveryJob;
begin
   BeginTest('schema 4 logs migrate delivery tables and preserve the log');
   OpenFixture;
   try
      FDatabase.Connection.ExecuteDirect('DROP TABLE external_delivery');
      FDatabase.Connection.ExecuteDirect('PRAGMA user_version = 4');
      FDatabase.Transaction.Commit;
      FDatabase.Close;
      FDatabase.Open(FFileName);
      FDelivery.Enqueue(Key, '{}', False);
      CheckTrue(FDelivery.Claim('WRL', 'account', 0, job));
      CheckEquals(5, FDatabase.SchemaVersion);
   finally
      CloseFixture;
   end;
end;

procedure TWRLDeliveryTests.TestClient;
var
   client: TWRLClient;
   job: TDeliveryJob;
   answer: TWRLResult;
   body: TJSONData;
begin
   BeginTest('WRL requests preserve destination, classify uncertainty and honor throttling');
   client := TStubWRLClient.Create('test-secret');
   try
      job := Default(TDeliveryJob);
      job.Key := Key;
      job.Payload := '{"call":"W1AW","logbookId":"wrong","freq":14.031}';
      StubSent := True;
      StubStatus := 201;
      StubRetry := '';
      StubResponse := '{"data":{"id":"abcd-1234"},"error":null}';
      answer := client.Deliver(job);
      CheckTrue(answer.Outcome = doConfirmed);
      CheckEquals('abcd-1234', answer.RemoteId);
      CheckEquals('POST', LastMethod);
      body := GetJSON(UTF8Encode(LastBody));
      try
         CheckEquals('book', UTF8Decode(TJSONObject(body).Get('logbookId', '')));
         CheckEquals('TR4W', UTF8Decode(TJSONObject(body).Get('programId', '')));
      finally
         body.Free;
      end;
      job.RemoteId := 'abcd-1234';
      answer := client.Deliver(job);
      CheckEquals('PATCH', LastMethod);
      CheckEquals(0, Pos('logbookId', LastBody), 'PATCH cannot move logbooks');
      CheckEquals(0, Pos('programId', LastBody));
      job.Deleted := True;
      StubResponse := '{"data":{"id":"abcd-1234","deleted":false},"error":null}';
      answer := client.Deliver(job);
      CheckTrue(answer.Outcome = doRetry, 'HTTP success alone is not a deletion receipt');
      StubResponse := '{"data":{"id":"abcd-1234","deleted":true},"error":null}';
      answer := client.Deliver(job);
      CheckTrue(answer.Outcome = doConfirmed);
      job.Deleted := False;
      job.RemoteId := '';
      StubSent := False;
      answer := client.Deliver(job);
      CheckTrue(answer.Outcome = doUncertain, 'lost POST response is never blindly retried');
      StubSent := True;
      StubStatus := 429;
      StubRetry := '123';
      answer := client.Deliver(job);
      CheckTrue(answer.Outcome = doRetry);
      CheckTrue(answer.RetrySeconds = 123);
      StubStatus := 500;
      answer := client.Deliver(job);
      CheckTrue(answer.Outcome = doUncertain, 'server failure may follow creation');
      StubStatus := 201;
      StubResponse := '{"data":{},"error":null}';
      answer := client.Deliver(job);
      CheckTrue(answer.Outcome = doUncertain, 'creation without ID requires review');
      StubResponse := '<html>invalid response</html>';
      answer := client.Deliver(job);
      CheckTrue(answer.Outcome = doUncertain);
      StubStatus := 401;
      StubResponse := '{"data":null,"error":{"code":"UNAUTHORIZED","message":"test-secret"}}';
      answer := client.Deliver(job);
      CheckTrue(answer.Outcome = doFailed);
      CheckEquals('UNAUTHORIZED', answer.ErrorCode);
      CheckEquals(0, Pos('test-secret', answer.ErrorCode));
      job.Deleted := True;
      LastMethod := '';
      answer := client.Deliver(job);
      CheckTrue(answer.Outcome = doConfirmed);
      CheckEquals('', LastMethod, 'unsent creation cancelled locally without an API request');
   finally
      client.Free;
   end;
end;

procedure TWRLDeliveryTests.TestAuthenticationGuards;
var
   request: THttpRequest;
begin
   BeginTest('bearer keys cannot be sent over HTTP, redirected or injected into headers');
   request := THttpRequest.Create('http://127.0.0.1:1');
   try
      request.BearerToken := 'test-secret';
      request.AllowInsecure := True;
      CheckFalse(request.Send);
      request.URL := 'https://127.0.0.1:1';
      request.FollowRedirects := True;
      CheckFalse(request.Send);
      request.FollowRedirects := False;
      request.BearerToken := 'test-secret'#13#10'Injected: yes';
      CheckFalse(request.Send);
      CheckEquals(0, Pos('test-secret', request.FailReason));
   finally
      request.Free;
   end;
end;

procedure TWRLDeliveryTests.TestADIFMapping;
var
   body: TJSONData;
   obj: TJSONObject;
begin
   BeginTest('WRL adapts contest-produced ADIF fields without a second contest policy');
   body := GetJSON(UTF8Encode(WRLContactFromADIF(
      '<CALL:4>W1AW<BAND:3>20m<FREQ:6>14.031<MODE:4>MFSK<SUBMODE:3>FT8' +
      '<QSO_DATE:8>20261030<TIME_ON:6>123456<TX_PWR:3>100' +
      '<MY_POTA_REF:15>US-0001,US-0002<POTA_REF:7>US-0003<EOR>', 'N1MM')));
   try
      obj := TJSONObject(body);
      CheckEquals('FT8', obj.Get('mode', UnicodeString('')));
      CheckEquals('N1MM', obj.Get('stationCallsign', UnicodeString('')));
      CheckTrue(obj.Find('freq').JSONType = jtNumber, 'MHz is numeric');
      CheckTrue(obj.Find('txPwr').JSONType = jtString, 'WRL watts is a string');
      CheckEquals(2, obj.Find('myActivities').Count, 'all emitted local park references');
      CheckEquals(1, obj.Find('theirActivities').Count);
      CheckTrue(obj.Find('dxcc') = nil, 'do not send a field absent from the request schema');
   finally
      body.Free;
   end;
end;

procedure TWRLDeliveryTests.TestSavedContactCapture;
var
   repository: TLogRepository;
   service: TWRLExternalLogger;
   rec: ContestExchange;
   rowId: Int64;
   q: TSQLQuery;
begin
   BeginTest('only the original computer captures delivery and failed capture preserves the QSO');
   OpenFixture;
   repository := TLogRepository.Create(FDatabase);
   service := TWRLExternalLogger.Create('account', 'book', 'test-secret', 'A', True);
   try
      rec := Default(ContestExchange);
      rec.Callsign := 'W1AW';
      rec.ceComputerID := 'B';
      rec.ceRecordKind := rkQSO;
      rec.ceQSO_Deleted := True;
      rowId := repository.SaveQSO(rec);
      service.CaptureSavedQso(FDatabase, repository, rowId, True);
      q := TSQLQuery.Create(nil);
      try
         q.Database := FDatabase.Connection;
         q.Transaction := FDatabase.Transaction;
         q.SQL.Text := 'SELECT COUNT(*) FROM external_delivery';
         q.Open;
         CheckEquals(0, q.Fields[0].AsInteger, 'receiving another computer''s row cannot upload it');
         q.Close;
         rec.ceComputerID := 'A';
         rowId := repository.SaveQSO(rec);
         service.CaptureSavedQso(FDatabase, repository, rowId, False);
         q.Open;
         CheckEquals(0, q.Fields[0].AsInteger, 'an old row is not implicitly backfilled');
         q.Close;
         service.CaptureSavedQso(FDatabase, repository, rowId, True);
         q.Open;
         CheckEquals(1, q.Fields[0].AsInteger, 'a locally created row is tracked');
         q.Close;
         FDatabase.Transaction.Commit;
         service.Free;
         service := TWRLExternalLogger.Create('account', 'book', '', 'A', True);
         rowId := repository.SaveQSO(rec);
         service.CaptureSavedQso(FDatabase, repository, rowId, True);
         q.Open;
         CheckEquals(2, q.Fields[0].AsInteger,
            'a temporarily unavailable API key must not discard pending contacts');
         q.Close;
         FDatabase.Transaction.Commit;
         FDatabase.Connection.ExecuteDirect('CREATE TRIGGER fail_delivery ' +
            'BEFORE INSERT ON external_delivery BEGIN ' +
            'SELECT RAISE(ABORT, ''injected delivery failure''); END');
         repository.Free;
         repository := TLogRepository.Create(FDatabase);
         rowId := repository.SaveQSO(rec);
         service.CaptureSavedQso(FDatabase, repository, rowId, True);
         FDatabase.Transaction.Commit;
         CheckTrue(repository.LoadQSO(rowId, rec), 'payload failure must not roll back the contact');
         rowId := repository.SaveQSO(rec);
         FDatabase.Transaction.Commit;
         CheckTrue(repository.LoadQSO(rowId, rec), 'subsequent contacts still save through the same repository');
         q.SQL.Text := 'SELECT value FROM session_state WHERE key = ''external_delivery_gap''';
         q.Open;
         CheckFalse(q.EOF, 'the synchronization gap survives restart');
      finally
         q.Free;
      end;
   finally
      service.Free;
      repository.Free;
      CloseFixture;
   end;
end;

procedure TWRLDeliveryTests.TestClearingFields;
var
   client: TWRLClient;
   job: TDeliveryJob;
   answer: TWRLResult;
begin
   BeginTest('unsupported field clearing cannot silently leave stale WRL data');
   client := TStubWRLClient.Create('test-secret');
   try
      job := Default(TDeliveryJob);
      job.Key := Key;
      job.RemoteId := 'abcd-1234';
      job.Payload := '{"gridsquare":null}';
      job.ConfirmedPayload := '{"gridsquare":"FN31"}';
      LastMethod := '';
      answer := client.Deliver(job);
      CheckTrue(answer.Outcome = doFailed);
      CheckEquals('FIELD_CLEAR_UNSUPPORTED', answer.ErrorCode);
      CheckEquals('', LastMethod, 'do not make a request known to be incomplete');
   finally
      client.Free;
   end;
end;

procedure TWRLDeliveryTests.TestSecretType;
var
   settings: TR4WSettings;
begin
   BeginTest('the WRL API key follows the common secret-storage contract');
   settings := TR4WSettings.Create;
   try
      CheckTrue(settings.CommandIsSecret('EXTERNAL LOGGER API KEY'));
      CheckFalse(settings.CommandIsSecret('EXTERNAL LOGGER LOGBOOK ID'));
   finally
      settings.Free;
   end;
end;

procedure TWRLDeliveryTests.TestWorkerEditDuringHTTP;
var
   worker: TWRLWorker;
   deadline: QWord;
   state: string;
begin
   BeginTest('a slow POST holds no database lock and a saved edit follows it as PATCH');
   OpenFixture;
   worker := nil;
   StubInFlight := TEvent.Create(nil, True, False, '');
   StubRelease := TEvent.Create(nil, True, False, '');
   try
      FDelivery.Enqueue(Key, '{"call":"W1AW"}', False);
      FDatabase.Transaction.Commit;
      StubSent := True;
      StubStatus := 201;
      StubRetry := '';
      StubResponse := '{"data":{"id":"abcd-1234"},"error":null}';
      StubMethods := '';
      worker := TStubWRLWorker.Create(FFileName, 'account', 'test-secret');
      worker.Start;
      CheckTrue(StubInFlight.WaitFor(5000) = wrSignaled, 'POST reaches the worker');
      FDelivery.Enqueue(Key, '{"call":"W2AW"}', False);
      FDatabase.Transaction.Commit;
      CheckEquals('inflight', Field('state'), 'main connection can save while HTTP waits');
      FDatabase.Transaction.Commit;
      StubRelease.SetEvent;
      deadline := GetTickCount64 + 5000;
      repeat
         state := Field('state');
         FDatabase.Transaction.Commit;
         if state = 'synced' then
            begin
            Break;
            end;
         Sleep(10);
      until GetTickCount64 >= deadline;
      CheckEquals('synced', state);
      worker.Free;
      worker := nil;
      CheckEquals('POST PATCH ', StubMethods, 'no overlapping or repeated creation');
      CheckEquals('2', Field('confirmed_revision'));
   finally
      StubRelease.SetEvent;
      worker.Free;
      FreeAndNil(StubRelease);
      FreeAndNil(StubInFlight);
      CloseFixture;
   end;
end;

procedure TWRLDeliveryTests.TestFullContactAndCaptureCost;
var
   repository: TLogRepository;
   service: TWRLExternalLogger;
   rec: ContestExchange;
   facts: TQsoMyFacts;
   rowId: Int64;
   body: TJSONData;
   start, baselineMs, deliveryMs: QWord;
   i: integer;
begin
   BeginTest('a saved contact uses the complete contest/export pipeline');
   OpenFixture;
   repository := TLogRepository.Create(FDatabase);
   service := TWRLExternalLogger.Create('account', 'book', 'test-secret', 'A', True);
   try
      rec := Default(ContestExchange);
      rec.Callsign := 'W1AW';
      rec.ceComputerID := 'A';
      rec.ceRecordKind := rkQSO;
      rec.ceContest := ContestHandleOf(GENERALQSO);
      rec.Band := Band20;
      rec.Mode := CW;
      rec.ExtMode := eCW;
      rec.Frequency := 14031000;
      rec.RSTSent := 599;
      rec.RSTReceived := 599;
      rec.tSysTime.qtYear := 26;
      rec.tSysTime.qtMonth := 10;
      rec.tSysTime.qtDay := 30;
      rec.tSysTime.qtHour := 12;
      facts := NotCapturedMyFacts;
      facts.Source := mfsLogged;
      facts.Call := 'NY4I';
      repository.SetNextMyFacts(facts);
      rowId := repository.SaveQSO(rec);
      service.CaptureSavedQso(FDatabase, repository, rowId, True);
      FDatabase.Transaction.Commit;
      CheckEquals('pending', Field('state'));
      body := GetJSON(UTF8Encode(Field('payload')));
      try
         CheckEquals('W1AW', TJSONObject(body).Get('call', UnicodeString('')));
         CheckEquals('NY4I', TJSONObject(body).Get('stationCallsign', UnicodeString('')));
         CheckEquals('CW', TJSONObject(body).Get('mode', UnicodeString('')));
      finally
         body.Free;
      end;
      FDatabase.Transaction.Commit;
      start := GetTickCount64;
      for i := 1 to 100 do
         begin
         repository.SetNextMyFacts(facts);
         repository.SaveQSO(rec);
         FDatabase.Transaction.Commit;
         end;
      baselineMs := GetTickCount64 - start;
      start := GetTickCount64;
      for i := 1 to 100 do
         begin
         repository.SetNextMyFacts(facts);
         rowId := repository.SaveQSO(rec);
         service.CaptureSavedQso(FDatabase, repository, rowId, True);
         FDatabase.Transaction.Commit;
         end;
      deliveryMs := GetTickCount64 - start;
      WriteLn('WRL capture measurement (100 local QSO commits): baseline=', baselineMs,
         'ms; with delivery intent=', deliveryMs, 'ms');
   finally
      service.Free;
      repository.Free;
      CloseFixture;
   end;
end;

procedure TWRLDeliveryTests.TestMinimalPatch;
var
   client: TWRLClient;
   job: TDeliveryJob;
   answer: TWRLResult;
   body: TJSONData;
begin
   BeginTest('PATCH preserves unrelated remote changes and skips unchanged snapshots');
   client := TStubWRLClient.Create('test-secret');
   try
      job := Default(TDeliveryJob);
      job.Key := Key;
      job.RemoteId := 'abcd-1234';
      job.ConfirmedPayload := '{"call":"W1AW","freq":14.031,"name":"Alice"}';
      job.Payload := '{"call":"W1AW","freq":14.041,"name":"Alice"}';
      StubSent := True;
      StubStatus := 200;
      StubResponse := '{"data":{"id":"abcd-1234"},"error":null}';
      answer := client.Deliver(job);
      CheckTrue(answer.Outcome = doConfirmed);
      body := GetJSON(UTF8Encode(LastBody));
      try
         CheckEquals(1, body.Count);
         CheckTrue(TJSONObject(body).Find('freq') <> nil);
      finally
         body.Free;
      end;
      LastMethod := '';
      job.Payload := job.ConfirmedPayload;
      answer := client.Deliver(job);
      CheckTrue(answer.Outcome = doConfirmed);
      CheckEquals('', LastMethod, 'no API call or quota cost when local values are unchanged');
   finally
      client.Free;
   end;
end;

procedure TWRLDeliveryTests.RunAllTests;
begin
   TestRevisions;
   TestRecovery;
   TestRollback;
   TestDestinationsAndRetry;
   TestMigration;
   TestClient;
   TestAuthenticationGuards;
   TestADIFMapping;
   TestSavedContactCapture;
   TestClearingFields;
   TestSecretType;
   TestWorkerEditDuringHTTP;
   TestFullContactAndCaptureCost;
   TestMinimalPatch;
end;

end.
