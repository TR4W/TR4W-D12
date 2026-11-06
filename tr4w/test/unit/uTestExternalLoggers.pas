unit uTestExternalLoggers;
{$I ..\..\src\tr4w.inc}
interface
uses uTR4WTestFramework;
type
   TExternalLoggersTests = class(TTestCase)
   public
      procedure RunAllTests; override;
   end;
implementation
uses Classes, SysUtils, SyncObjs, sqldb, VC, uExternalDeliveryWorker,
   uExternalLoggerMigration, uSettingsModel, uExternalLoggersForm, uQsoMyFacts, uJSON, uKeychain, uExternalLoggerConfig,
   uExternalLoggers, uExternalLoggerService, uQsoDispatcher,
   uExternalLoggerFactory, uExternalLoggerRegistry, uClubLogClient,
   uClubLogExternalLogger, uWRLExternalLogger, uHTTPDownload,
   uExternalDeliveryClient, uExternalDelivery, uLogDatabase, uLogRepository;
type
   TRecordingService = class(TExternalLoggerService)
   public
      Calls: integer;
      Fail, PrepareFail: boolean;
      LastOp: TQsoExternalOp;
      function PrepareOp(const aKind: TQsoMessageKind; const ce: ContestExchange;
         out aCommand1, aCommand2: string): TQsoExternalOp; override;
      procedure SubmitOp(const aOp: TQsoExternalOp;
         const aCommand1, aCommand2, aDescription: string); override;
      function LookupCallsign(ce: ContestExchange): integer; override;
   end;
   TClubRequest = class(THttpRequest)
   public
      function Send: boolean; override;
   end;
   TClubClientProbe = class(TClubLogClient)
   protected
      function NewRequest: THttpRequest; override;
   end;
   TCaptureService = class(TWRLExternalLogger)
   protected
      function BuildPayload(const aRecord: ContestExchange; const aFacts: TQsoMyFacts;
         const aSent: AnsiString): string; override;
   end;
   TGateClient = class(TExternalDeliveryClient)
   public
      Entered, Gate: TEvent;
      function Deliver(const aJob: TDeliveryJob): TExternalDeliveryResult; override;
   end;
   TGateWorker = class(TExternalDeliveryWorker)
   private
      FEntered, FGate: TEvent;
   protected
      function NewClient: TExternalDeliveryClient; override;
   public
      constructor Create(const aFile, aScope: string; aEntered, aGate: TEvent);
   end;
var
   Bodies, URLs, Replies, Methods, Tokens: TStringList;
   ReplyCode: integer;
function TCaptureService.BuildPayload(const aRecord: ContestExchange;
   const aFacts: TQsoMyFacts; const aSent: AnsiString): string;
begin
   Result := string(aRecord.Callsign);
end;
constructor TGateWorker.Create(const aFile, aScope: string; aEntered, aGate: TEvent);
begin
   inherited Create(aFile, 'account', aScope);
   FEntered := aEntered;
   FGate := aGate;
end;
function TGateWorker.NewClient: TExternalDeliveryClient;
var
   client: TGateClient;
begin
   client := TGateClient.Create;
   client.Entered := FEntered;
   client.Gate := FGate;
   Result := client;
end;
function TGateClient.Deliver(const aJob: TDeliveryJob): TExternalDeliveryResult;
begin
   Entered.SetEvent;
   if Gate <> nil then
      begin
      Gate.WaitFor(10000);
      end;
   Result := Default(TExternalDeliveryResult);
   Result.Outcome := doConfirmed;
   Result.RemoteId := 'fixture-remote';
end;
function TRecordingService.PrepareOp(const aKind: TQsoMessageKind;
   const ce: ContestExchange; out aCommand1, aCommand2: string): TQsoExternalOp;
begin
   if PrepareFail then
      begin
      raise EInvalidOp.Create('fixture preparation failed');
      end;
   aCommand1 := string(ce.Callsign);
   aCommand2 := 'replacement';
   Result := xoSingle;
   if aKind = qmEdited then
      begin
      Result := xoReplace;
      end;
end;
procedure TRecordingService.SubmitOp(const aOp: TQsoExternalOp;
   const aCommand1, aCommand2, aDescription: string);
begin
   Inc(Calls);
   LastOp := aOp;
   if Fail then
      begin
      raise EInvalidOp.Create('fixture');
      end;
end;
function TRecordingService.LookupCallsign(ce: ContestExchange): integer;
begin
   Result := -1;
end;
function TClubRequest.Send: boolean;
begin
   URLs.Add(AnsiString(URL));
   Bodies.Add(AnsiString(Body));
   Methods.Add(AnsiString(Method));
   Tokens.Add(AnsiString(BearerToken));
   StatusCode := ReplyCode;
   Response := string(Replies[0]);
   if Copy(Response, 1, 7) = 'HEADER:' then
      begin
      ResponseStatusText := Copy(Response, 8, MaxInt);
      Response := '';
      end;
   Replies.Delete(0);
   Result := True;
end;
function TClubClientProbe.NewRequest: THttpRequest;
begin
   Result := TClubRequest.Create('https://clublog.org/api/v1/qso');
end;
procedure TExternalLoggersTests.RunAllTests;
const
   ORIGINAL = '<CALL:4>W1AW<QSO_DATE:8>20261101<TIME_ON:6>123456<BAND:3>20m<EOR>';
   EDITED = '<CALL:5>W2XYZ<QSO_DATE:8>20261102<TIME_ON:6>010203<BAND:3>40m<EOR>';
var
   config, copy: TExternalLoggerConfig;
   a, b: TExternalLoggerDefinition;
   root: TJSONObject;
   manager: TExternalLoggers;
   first, second, inactive: TRecordingService;
   message: TQsoMessage;
   rec: ContestExchange;
   client: TClubClientProbe;
   job, other: TDeliveryJob;
   answer: TExternalDeliveryResult;
   database: TLogDatabase;
   delivery: TExternalDelivery;
   key: TDeliveryKey;
   path, originalId, error: string;
   service: TExternalLoggerService;
   legacy: TExternalLoggerSettings;
   form: TExternalLoggersForm;
   workerA, workerB: TGateWorker;
   gate, enteredA, enteredB: TEvent;
   start, deadline: QWord;
   counts: TDeliveryCounts;
   snapshot: TExternalLoggerSnapshot;
   serviceA, serviceB: TWRLExternalLogger;
   repository: TLogRepository;
   query: TSQLQuery;
   rowId: Int64;
begin
   BeginTest('definitions preserve activation order, IDs and vault-only credentials');
   InstallTestKeychain;
   config := TExternalLoggerConfig.Create;
   copy := TExternalLoggerConfig.Create;
   try
      config.Present := True;
      a := TExternalLoggerDefinition.Create;
      a.Name := 'First';
      a.ProviderId := 'WRL';
      a.Account := 'account';
      a.Logbook := 'book';
      a.ApiKey := 'fixture-secret';
      config.Definitions.Add(a);
      b := TExternalLoggerDefinition.Create;
      b.Assign(a);
      b.Id := 'second';
      b.Name := 'Second';
      config.Definitions.Add(b);
      config.ActiveIds.Add(AnsiString(b.Id));
      config.ActiveIds.Add(AnsiString(a.Id));
      CheckTrue(config.Validate(error));
      originalId := a.DeliveryId;
      a.Name := 'Renamed';
      CheckEquals(originalId, a.DeliveryId, 'rename does not change queue ownership');
      a.Logbook := 'different-book';
      CheckTrue(originalId <> a.DeliveryId, 'destination change parks old backlog');
      root := TJSONObject.Create;
      try
         config.SaveJSON(root);
         CheckEquals(0, Pos('fixture-secret', root.ToJSON));
         copy.LoadJSON(root);
         CheckEquals(b.Id, string(copy.ActiveIds[0]));
         CheckEquals('fixture-secret', copy.Definitions[0].ApiKey);
         CheckEquals(a.Id, copy.Definitions[0].Id);
      finally
         root.Free;
      end;
      copy.ActiveIds.Add(AnsiString(b.Id));
      CheckFalse(copy.Validate(error), 'duplicate active IDs are refused');
      copy.ActiveIds.Clear;
      CheckTrue(copy.Validate(error), 'empty list deliberately disables all destinations');
      service := TExternalLoggerFactory.CreateLogger(a, 'A');
      CheckTrue(service is TWRLExternalLogger);
      service.Free;
      a.ProviderId := 'CLUBLOG';
      service := TExternalLoggerFactory.CreateLogger(a, 'A');
      CheckTrue(service is TClubLogExternalLogger, 'third provider uses the registry');
      service.Free;
   finally
      copy.Free;
      config.Free;
   end;

   BeginTest('migration runs once and an explicit empty active list stays disabled');
   config := TExternalLoggerConfig.Create;
   legacy := TExternalLoggerSettings.Create;
   try
      legacy.LoggerType := 'WRL';
      legacy.AccountId := 'account';
      legacy.LogbookId := 'book';
      legacy.Enabled := True;
      CheckTrue(SeedExternalLoggers(config, legacy));
      CheckEquals(1, config.Definitions.Count);
      originalId := config.Definitions[0].Id;
      CheckTrue(config.Definitions[0].LegacySecretPending);
      config.ActiveIds.Clear;
      CheckFalse(SeedExternalLoggers(config, legacy));
      CheckEquals(0, config.ActiveIds.Count);
      CheckEquals(originalId, config.Definitions[0].Id);
   finally
      legacy.Free;
      config.Free;
   end;
   BeginTest('native logger editor streams its provider list; its rows are pinned in uTestExternalLoggerFields');
   form := TExternalLoggersForm.Create(nil);
   try
      CheckTrue(form.cbProvider.Items.IndexOf('CLUBLOG') >= 0);
      CheckTrue(form.cbProvider.Items.IndexOf('WRL') >= 0);
      CheckTrue(form.cbProvider.Items.IndexOf('DXKEEPER') >= 0);
   finally
      form.Free;
   end;

   BeginTest('manager contains one enqueue failure and preserves per-destination operations');
   manager := TExternalLoggers.Create;
   first := TRecordingService.Create;
   second := TRecordingService.Create;
   manager.Add('first', first);
   manager.Add('second', second);
   inactive := TRecordingService.Create;
   manager.Add('inactive', inactive, False);
   first.Fail := True;
   message := TQsoMessage.Create(qmEdited, 'W1AW');
   try
      rec := Default(ContestExchange);
      rec.Callsign := 'W1AW';
      manager.PrepareMessage(message, rec);
      CheckEquals('first', message.ExtDeliveries[0].TargetId);
      CheckEquals('second', message.ExtDeliveries[1].TargetId);
      manager.SubmitMessage(message);
      CheckEquals(1, first.Calls);
      CheckEquals(1, second.Calls, 'one failed destination cannot skip the next');
      CheckTrue(second.LastOp = xoReplace);
      CheckEquals(2, Length(message.ExtDeliveries), 'inactive destinations allocate no command slot');
      CheckEquals(0, inactive.Calls);
      first.Fail := False;
      first.PrepareFail := True;
      manager.PrepareMessage(message, rec);
      manager.SubmitMessage(message);
      CheckEquals(1, first.Calls, 'failed preparation is not submitted');
      CheckEquals(2, second.Calls, 'failed preparation does not lose the next destination');
      (* Issue 226: a snapshot by DELIVERY id; the started-active flag is the
         composite's, the rest the service's. *)
      CheckTrue(manager.StateSnapshot('first', snapshot), 'a running destination');
      CheckTrue(snapshot.Active, 'started switched on');
      CheckTrue(manager.StateSnapshot('inactive', snapshot));
      CheckFalse(snapshot.Active, 'started switched off');
      CheckFalse(manager.StateSnapshot('nobody', snapshot), 'not a running destination');
      CheckFalse(snapshot.Active);
   finally
      message.Free;
      manager.Free;
   end;

   BeginTest('Club Log bearer JSON API creates, replaces and deletes by qsoid');
   Bodies := TStringList.Create;
   URLs := TStringList.Create;
   Replies := TStringList.Create;
   Methods := TStringList.Create;
   Tokens := TStringList.Create;
   client := TClubClientProbe.Create('NY4I', 'fixture-token');
   try
      ReplyCode := 201;
      job := Default(TDeliveryJob);
      job.Payload := ORIGINAL;
      Replies.Add('{"status":"created","qsoid":123456789}');
      answer := client.Deliver(job);
      CheckTrue(answer.Outcome = doConfirmed);
      CheckEquals('123456789', answer.RemoteId);
      CheckEquals('https://clublog.org/api/v1/qso', string(URLs[0]));
      CheckEquals('POST', string(Methods[0]));
      CheckEquals('fixture-token', string(Tokens[0]));
      root := TJSONObject.ParseJSONValue(string(Bodies[0])) as TJSONObject;
      try
         CheckEquals('NY4I', JSONGetStr(root, 'call', ''));
         CheckEquals(ORIGINAL, JSONGetStr(root, 'adif', ''));
         CheckTrue(root.GetValue('email') = nil);
         CheckTrue(root.GetValue('password') = nil);
      finally
         root.Free;
      end;
      job.RemoteId := answer.RemoteId;
      job.ConfirmedPayload := ORIGINAL;
      job.Payload := EDITED;
      ReplyCode := 200;
      Replies.Add('{"status":"deleted"}');
      Replies.Add('{"status":"updated","qsoid":987654321}');
      answer := client.Deliver(job);
      CheckTrue(answer.Outcome = doConfirmed);
      CheckEquals('987654321', answer.RemoteId);
      CheckEquals('https://clublog.org/api/v1/qso/123456789', string(URLs[1]));
      CheckEquals('DELETE', string(Methods[1]));
      CheckEquals('', string(Bodies[1]), 'delete sends only the saved remote ID');
      CheckEquals('POST', string(Methods[2]));
      job.RemoteId := answer.RemoteId;
      job.ConfirmedPayload := EDITED;
      job.Deleted := True;
      Replies.Add('{"status":"deleted"}');
      answer := client.Deliver(job);
      CheckTrue(answer.Outcome = doConfirmed);
      CheckEquals('https://clublog.org/api/v1/qso/987654321', string(URLs[3]));
      ReplyCode := 403;
      Replies.Add('do not expose server text: fixture-token');
      job.Deleted := False;
      answer := client.Deliver(job);
      CheckTrue(answer.Pause, 'credential rejection stops the destination');
      CheckEquals(5, Bodies.Count, 'failed delete cannot be followed by a create');
      CheckEquals(0, Pos('fixture-token', answer.ErrorCode));
      ReplyCode := 201;
      job.RemoteId := '';
      Replies.Add('{"status":"created","qsoid":null,"test_mode":true}');
      answer := client.Deliver(job);
      CheckTrue(answer.Outcome = doConfirmed, 'test mode counts as successful delivery');
      CheckEquals('', answer.ErrorCode);
      CheckEquals('clublog:test-mode', answer.RemoteId);
      CheckTrue(not answer.Pause, 'test token does not stop the queue');
      job.RemoteId := answer.RemoteId;
      Replies.Add('{"status":"created","qsoid":null,"test_mode":true}');
      answer := client.Deliver(job);
      CheckTrue(answer.Outcome = doConfirmed, 'test-mode edit validates another upload');
      CheckEquals('POST', string(Methods[Methods.Count - 1]));
      CheckEquals('https://clublog.org/api/v1/qso', string(URLs[URLs.Count - 1]));
      job.Deleted := True;
      answer := client.Deliver(job);
      CheckTrue(answer.Outcome = doConfirmed, 'test-mode delete has nothing remote to delete');
      CheckEquals(0, Replies.Count);
      job.Deleted := False;
      ReplyCode := 201;
      Replies.Add('{"status":"created","qsoid":2468}');
      answer := client.Deliver(job);
      CheckTrue(answer.Outcome = doConfirmed, 'test contact can become a real upload later');
      CheckEquals('2468', answer.RemoteId);
      CheckEquals('POST', string(Methods[Methods.Count - 1]));
      job.RemoteId := '';
      Replies.Add('{"status":"rejected","qsoid":null,"test_mode":true}');
      answer := client.Deliver(job);
      CheckTrue(answer.Outcome <> doConfirmed, 'test flag alone cannot turn rejection into success');
      Replies.Add('{"status":"created","qsoid":null}');
      answer := client.Deliver(job);
      CheckTrue(answer.Outcome = doUncertain, 'missing qsoid needs reconciliation');
      Replies.Add('unexpected success response');
      answer := client.Deliver(job);
      CheckTrue(answer.Outcome = doUncertain);
      CheckTrue(client.RecoverUpdatesAsUncertain);
      ReplyCode := 429;
      Replies.Add('{"error":"rate_limited"}');
      answer := client.Deliver(job);
      CheckTrue(answer.Outcome = doRetry);
      CheckTrue(not answer.Pause);
      CheckTrue(answer.RetrySeconds >= 60);
      job.RemoteId := '123456789';
      ReplyCode := 404;
      Replies.Add('{"error":"not_found"}');
      answer := client.Deliver(job);
      CheckTrue(answer.Outcome = doFailed, 'unknown remote ID stops replacement');
      CheckTrue(answer.Pause);
      job.RemoteId := 'uploaded';
      answer := client.Deliver(job);
      CheckEquals('CLUBLOG_INVALID_QSOID', answer.ErrorCode);
      job.RemoteId := '';
      job.Deleted := True;
      answer := client.Deliver(job);
      CheckTrue(answer.Outcome = doConfirmed, 'unsent create can be cancelled locally');
   finally
      client.Free;
      Tokens.Free;
      Methods.Free;
      Replies.Free;
      URLs.Free;
      Bodies.Free;
   end;

   BeginTest('durable claims and recovery are isolated by destination');
   path := string(GetTempFileName);
   DeleteFile(path);
   database := TLogDatabase.Create;
   try
      database.CreateNew(path);
      delivery := TExternalDelivery.Create(database);
      try
         key := Default(TDeliveryKey);
         key.Logger := 'WRL/first';
         key.Account := 'same-account';
         key.Logbook := 'same-book';
         key.Contact := 'contact';
         delivery.Enqueue(key, ORIGINAL, False);
         key.Logger := 'WRL/second';
         delivery.Enqueue(key, EDITED, False);
         database.EndTransaction;
         CheckTrue(delivery.Claim('WRL/first', 'same-account', 0, job));
         database.EndTransaction;
         CheckTrue(delivery.Claim('WRL/second', 'same-account', 0, other));
         database.EndTransaction;
         delivery.RecoverInterrupted('WRL/first', 'same-account');
         database.EndTransaction;
         delivery.Complete(other, doConfirmed, 'second-remote', '', '', 0);
         database.EndTransaction;
         CheckFalse(delivery.Claim('WRL/first', 'same-account', 0, job),
            'interrupted creation is uncertain, never replayed blindly');
         database.EndTransaction;
      finally
         delivery.Free;
      end;
   finally
      database.Free;
      DeleteFile(path);
      DeleteFile(path + '-wal');
      DeleteFile(path + '-shm');
   end;
   BeginTest('legacy adoption preserves confirmed delivery and unsafe update recovery is isolated');
   path := string(GetTempFileName);
   DeleteFile(path);
   database := TLogDatabase.Create;
   try
      database.CreateNew(path);
      delivery := TExternalDelivery.Create(database);
      try
         key := Default(TDeliveryKey);
         key.Logger := 'WRL';
         key.Account := 'account';
         key.Logbook := 'book';
         key.Contact := 'contact';
         delivery.Enqueue(key, ORIGINAL, False);
         database.EndTransaction;
         CheckTrue(delivery.Claim('WRL', 'account', 0, job));
         delivery.Complete(job, doConfirmed, 'existing-remote', '', '', 0);
         database.EndTransaction;
         key.Account := 'other-account';
         delivery.Enqueue(key, ORIGINAL, False);
         database.EndTransaction;
         delivery.MigrateLogger('WRL', 'modern', 'account', 'book');
         database.EndTransaction;
         counts := ExternalDeliveryCounts(path, 'modern');
         CheckTrue(counts.Synced = 1, 'adoption does not resend a confirmed contact');
         counts := ExternalDeliveryCounts(path, 'WRL');
         CheckTrue(counts.Pending = 1, 'another account is not adopted');
         key.Account := 'account';
         key.Logger := 'modern';
         delivery.Enqueue(key, EDITED, False);
         database.EndTransaction;
         CheckTrue(delivery.Claim('modern', 'account', 0, job));
         CheckEquals('existing-remote', job.RemoteId);
         database.EndTransaction;
         delivery.RecoverInterrupted('modern', 'account', True);
         database.EndTransaction;
         counts := ExternalDeliveryCounts(path, 'modern');
         CheckTrue(counts.Uncertain = 1, 'interrupted replace may already have created a new identity');
      finally
         delivery.Free;
      end;
   finally
      database.Free;
      DeleteFile(path);
      DeleteFile(path + '-wal');
      DeleteFile(path + '-shm');
   end;

   BeginTest('capture updates only its own binding and inactive destinations keep existing changes');
   path := string(GetTempFileName);
   DeleteFile(path);
   database := TLogDatabase.Create;
   serviceA := TCaptureService.Create('account', 'book', '', 'A', True, 'first');
   serviceB := TCaptureService.Create('account', 'book', '', 'A', True, 'second');
   try
      database.CreateNew(path);
      repository := TLogRepository.Create(database);
      query := TSQLQuery.Create(nil);
      try
         rec := Default(ContestExchange);
         rec.Callsign := 'W1AW';
         rec.ceRecordKind := rkQSO;
         rec.ceComputerID := 'A';
         rec.ceQSO_Deleted := True;
         rowId := repository.SaveQSO(rec);
         serviceA.CaptureSavedQso(database, repository, rowId, True);
         serviceB.CaptureSavedQso(database, repository, rowId, True);
         rec.ceQSO_Deleted := False;
         repository.UpdateQSO(rowId, rec);
         serviceB.SetActive(False);
         serviceB.CaptureSavedQso(database, repository, rowId, False);
         repository.Commit;
         query.Database := database.Connection;
         query.Transaction := database.Transaction;
         query.SQL.Text := 'SELECT logger, revision FROM external_delivery ORDER BY logger';
         query.Open;
         CheckEquals('first', string(query.Fields[0].AsUTF8String));
         CheckEquals(1, query.Fields[1].AsInteger);
         query.Next;
         CheckEquals('second', string(query.Fields[0].AsUTF8String));
         CheckEquals(2, query.Fields[1].AsInteger, 'inactive binding still records edits/deletes');
         query.Next;
         CheckTrue(query.EOF, 'exactly one row per destination, no cross-instance capture');
         query.Close;
         database.EndTransaction;
         rowId := repository.SaveQSO(rec);
         serviceB.CaptureSavedQso(database, repository, rowId, True);
         repository.Commit;
         query.SQL.Text := 'SELECT COUNT(*) FROM external_delivery';
         query.Open;
         CheckEquals(2, query.Fields[0].AsInteger, 'inactive destination does not acquire a new QSO');
      finally
         query.Free;
         repository.Free;
      end;
   finally
      serviceA.Free;
      serviceB.Free;
      database.Free;
      DeleteFile(path);
      DeleteFile(path + '-wal');
      DeleteFile(path + '-shm');
   end;

   BeginTest('a blocked HTTP destination holds no writer lock and does not delay another worker');
   path := string(GetTempFileName);
   DeleteFile(path);
   database := TLogDatabase.Create;
   gate := TEvent.Create(nil, True, False, '');
   enteredA := TEvent.Create(nil, True, False, '');
   enteredB := TEvent.Create(nil, True, False, '');
   workerA := nil;
   workerB := nil;
   try
      database.CreateNew(path);
      delivery := TExternalDelivery.Create(database);
      try
         key := Default(TDeliveryKey);
         key.Logger := 'blocked';
         key.Account := 'account';
         key.Logbook := 'book';
         key.Contact := 'first';
         delivery.Enqueue(key, ORIGINAL, False);
         key.Logger := 'healthy';
         delivery.Enqueue(key, EDITED, False);
         database.EndTransaction;
         workerA := TGateWorker.Create(path, 'blocked', enteredA, gate);
         workerA.Start;
         CheckTrue(enteredA.WaitFor(3000) = wrSignaled);
         start := GetTickCount64;
         key.Contact := 'second';
         delivery.Enqueue(key, EDITED, False);
         database.EndTransaction;
         WriteLn('External logger capture while HTTP blocked: ', GetTickCount64 - start, ' ms');
         CheckTrue(GetTickCount64 - start < 500, 'network wait must not hold the local writer lock');
         workerB := TGateWorker.Create(path, 'healthy', enteredB, nil);
         workerB.Start;
         CheckTrue(enteredB.WaitFor(3000) = wrSignaled);
         deadline := GetTickCount64 + 3000;
         repeat
            counts := ExternalDeliveryCounts(path, 'healthy');
            if counts.Synced >= 2 then
               begin
               Break;
               end;
            Sleep(10);
         until GetTickCount64 >= deadline;
         CheckTrue(counts.Synced >= 2, 'healthy destination drains while first destination is blocked');
         counts := ExternalDeliveryCounts(path, 'blocked');
         CheckTrue(counts.InFlight = 1);
         (* Issue 226: the worker says what it is doing, without a database. *)
         snapshot := Default(TExternalLoggerSnapshot);
         workerA.FillSnapshot(snapshot);
         CheckTrue(snapshot.Busy, 'a request is out');
         CheckFalse(snapshot.HasResult, 'nothing has settled yet');
         CheckFalse(snapshot.Halted);
         gate.SetEvent;
         deadline := GetTickCount64 + 3000;
         repeat
            workerA.FillSnapshot(snapshot);
            if snapshot.HasResult then
               begin
               Break;
               end;
            Sleep(10);
         until GetTickCount64 >= deadline;
         CheckTrue(snapshot.HasResult, 'the settled delivery is recorded');
         CheckFalse(snapshot.Busy, 'the request is over');
         CheckTrue(snapshot.LastOutcome = doConfirmed, 'confirmed');
         CheckEquals('', snapshot.Code, 'a confirmed delivery has no code');
      finally
         delivery.Free;
      end;
   finally
      gate.SetEvent;
      workerA.Free;
      workerB.Free;
      enteredA.Free;
      enteredB.Free;
      gate.Free;
      database.Free;
      DeleteFile(path);
      DeleteFile(path + '-wal');
      DeleteFile(path + '-shm');
   end;
end;
end.
