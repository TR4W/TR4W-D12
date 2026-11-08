unit uTestACLog;
{$I ..\..\src\tr4w.inc}

(*
  THE AC LOG (N3FJP) PROVIDER (issue 33).

  The client talks to a REAL socket: an in-process TIdTCPServer on loopback
  plays AC Log's TCP API and records every byte it is sent, so what is pinned
  is what would go on the wire, with no network and no AC Log.

  Pinned: the exact bytes (the ADD command, its CR LF, the bare CR LF that ends
  the connection, UTF-8, an ADIF record that contains < > & and a non-ASCII
  letter), success as a hand-off marker, a closed port as a retry that does not
  pause, a failure after the connection was up as uncertain and paused, the
  edit/delete policy (the API has neither: a delivered contact fails visibly,
  nothing is sent), an incomplete setup, the descriptors and the definition
  check, the destination fingerprint, the registry entry, and the legacy
  EXTERNAL LOGGER = ACLOG token becoming an ACLOG definition.

  NOT covered here, and bench-only (docs/BENCH_QUEUE.md): a real AC Log. No
  reply to ADDADIFRECORD is documented, so none is simulated.
*)

interface

uses
   SyncObjs, Classes, SysUtils,
   IdTCPServer, IdContext, IdGlobal, IdIOHandler, IdTCPClient,
   uTR4WTestFramework, uACLogClient;

type
   TFailingACLogClient = class(TACLogClient)
   protected
      procedure SendFrames(aClient: TIdTCPClient; const aCommand: RawByteString); override;
   end;

   TACLogTests = class(TTestCase)
   private
      FServer:   TIdTCPServer;
      FLock:     TCriticalSection;
      FDone:     TEvent;
      FReceived: RawByteString;
      FHits:     integer;
      procedure ServerExecute(AContext: TIdContext);
      function  StartServer: Word;
      procedure StopServer;
      function  WaitForServer: boolean;
      function  Received: RawByteString;
   protected
      procedure Test_WireBytes;
      procedure Test_Success_IsAHandOffWithAMarker;
      procedure Test_ClosedPort_IsARetryNotAPause;
      procedure Test_FailureAfterConnect_IsUncertainAndPaused;
      procedure Test_EditAndDelete_Policy;
      procedure Test_SetupRequired;
      procedure Test_Descriptors_AndDefinitionError;
      procedure Test_DestinationIdentity;
      procedure Test_Registry;
      procedure Test_LegacyTokenMigrates;
   public
      procedure RunAllTests; override;
   end;

implementation

uses
   uExternalDelivery, uExternalDeliveryClient, uACLogExternalLogger,
   uExternalLoggerConfig, uExternalLoggerRegistry, uExternalLoggerFactory,
   uExternalLoggerBase, uExternalLoggerMigration, uSettingsModel, uAppStrings;

const
   ADIF_PLAIN = '<CALL:4>W1AW<QSO_DATE:8>20261101<TIME_ON:6>123456<BAND:3>20m<EOR>';

procedure TFailingACLogClient.SendFrames(aClient: TIdTCPClient;
   const aCommand: RawByteString);
begin
   raise Exception.Create('the write failed part-way');
end;

(* ---- loopback fixture ------------------------------------------------------ *)

procedure TACLogTests.ServerExecute(AContext: TIdContext);
var
   io: TIdIOHandler;
   raw: TIdBytes;
   rounds: integer;
   text: RawByteString;
   procedure Drain;
   var
      j: integer;
   begin
      while not io.InputBufferIsEmpty do
         begin
         raw := nil;
         io.ReadBytes(raw, io.InputBuffer.Size, False);
         for j := 0 to High(raw) do
            begin
            text := text + AnsiChar(raw[j]);
            end;
         end;
   end;
begin
   io := AContext.Connection.IOHandler;
   text := '';
   rounds := 0;
   try
      (* The client closes after its last write, which ends this loop. *)
      while rounds < 40 do
         begin
         Inc(rounds);
         io.CheckForDataOnSource(100);
         Drain;
         end;
   except
      on E: Exception do
         begin
         (* the peer closed: whatever arrived is already in the buffer *)
         end;
   end;
   Drain;
   FLock.Enter;
   try
      FReceived := text;
      Inc(FHits);
   finally
      FLock.Leave;
   end;
   FDone.SetEvent;
end;

function TACLogTests.StartServer: Word;
begin
   FHits := 0;
   FReceived := '';
   FDone.ResetEvent;
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

procedure TACLogTests.StopServer;
begin
   if FServer <> nil then
      begin
      FServer.Active := False;
      FreeAndNil(FServer);
      end;
end;

function TACLogTests.WaitForServer: boolean;
begin
   Result := FDone.WaitFor(5000) = wrSignaled;
end;

function TACLogTests.Received: RawByteString;
begin
   FLock.Enter;
   try
      Result := FReceived;
   finally
      FLock.Leave;
   end;
end;

function NewJob(const aAdif: string): TDeliveryJob;
begin
   Result := Default(TDeliveryJob);
   Result.Payload := aAdif;
end;

(* ---- the tests ------------------------------------------------------------- *)

procedure TACLogTests.Test_WireBytes;
var
   adif: string;
   expected: RawByteString;
begin
   BeginTest('AC Log wire: <CMD><ADDADIFRECORD><VALUE>record</VALUE></CMD> + CR LF, then a bare CR LF');
   CheckTrue(ACLogAddFrame(ADIF_PLAIN) =
      '<CMD><ADDADIFRECORD><VALUE>' + ADIF_PLAIN + '</VALUE></CMD>'#13#10,
      'plain record');
   CheckTrue(ACLogEndFrame = #13#10, 'the bare CR LF that ends the connection');

   BeginTest('AC Log wire: the record keeps < > & as they are, is UTF-8, and its CR LF never ends the line early');
   (* e-acute, spelled by code so the source file holds only ASCII. *)
   adif := '<CALL:4>W1AW<NAME:4>Jos' + string(WideChar($E9)) +
           '<NOTES:5>A&B<C>'#13#10'<EOR>'#13#10;
   expected := '<CMD><ADDADIFRECORD><VALUE>' +
               '<CALL:4>W1AW<NAME:4>Jos'#$C3#$A9 + '<NOTES:5>A&B<C>  <EOR>' +
               '</VALUE></CMD>'#13#10;
   CheckTrue(ACLogAddFrame(adif) = expected,
      'wire bytes differ: ' + string(ACLogAddFrame(adif)));
   CheckEquals(Length(expected) - 1, Pos(RawByteString(#13#10), ACLogAddFrame(adif)),
      'the only CR LF is the last two bytes');
end;

procedure TACLogTests.Test_Success_IsAHandOffWithAMarker;
var
   client: TACLogClient;
   r: TExternalDeliveryResult;
begin
   BeginTest('AC Log: a fully written command is confirmed with the local marker and the server saw the exact bytes');
   client := TACLogClient.Create('127.0.0.1', StartServer);
   try
      r := client.Deliver(NewJob(ADIF_PLAIN));
      CheckTrue(WaitForServer, 'the fixture saw the connection end');
   finally
      client.Free;
      StopServer;
   end;
   CheckTrue(r.Outcome = doConfirmed, 'confirmed (a hand-off, not an acknowledgement)');
   CheckFalse(r.Pause, 'not paused');
   CheckEquals('', r.ErrorCode);
   CheckEquals(ACLOG_ADDED_MARKER, r.RemoteId, 'a nonempty remote identity for the outbox');
   CheckTrue(Received = ACLogAddFrame(ADIF_PLAIN) + ACLogEndFrame,
      'bytes on the wire: ' + string(Received));
   CheckEquals(1, FHits, 'one connection for one delivery');
end;

procedure TACLogTests.Test_ClosedPort_IsARetryNotAPause;
var
   client: TACLogClient;
   r: TExternalDeliveryResult;
   port: Word;
begin
   BeginTest('AC Log not running / API off: nothing written, retry in 60 s, destination not paused');
   port := StartServer;
   StopServer;
   client := TACLogClient.Create('127.0.0.1', port);
   try
      r := client.Deliver(NewJob(ADIF_PLAIN));
   finally
      client.Free;
   end;
   CheckTrue(r.Outcome = doRetry, 'retry');
   CheckFalse(r.Pause, 'not paused');
   CheckEquals(ACLOG_RETRY_SECONDS, integer(r.RetrySeconds));
   CheckEquals('ACLOG_NOT_REACHABLE', r.ErrorCode);
   CheckEquals(0, r.Status);
   CheckEquals('', r.RemoteId);
end;

procedure TACLogTests.Test_FailureAfterConnect_IsUncertainAndPaused;
var
   client: TFailingACLogClient;
   r: TExternalDeliveryResult;
begin
   BeginTest('a failure after the connection was up may have written a partial record: uncertain and paused');
   client := TFailingACLogClient.Create('127.0.0.1', StartServer);
   try
      r := client.Deliver(NewJob(ADIF_PLAIN));
      CheckTrue(WaitForServer, 'the connection was made and ended');
   finally
      client.Free;
      StopServer;
   end;
   CheckTrue(r.Outcome = doUncertain, 'uncertain, never replayed blindly');
   CheckTrue(r.Pause, 'paused for review');
   CheckEquals('ACLOG_SEND_REQUIRES_REVIEW', r.ErrorCode);
   CheckEquals('', r.RemoteId);
end;

procedure TACLogTests.Test_EditAndDelete_Policy;
var
   client: TACLogClient;
   job: TDeliveryJob;
   r: TExternalDeliveryResult;
begin
   BeginTest('the API has no edit or delete: a delivered contact fails VISIBLY, sends nothing and does not pause; an undelivered one does not');
   client := TACLogClient.Create('127.0.0.1', StartServer);
   try
      job := NewJob(ADIF_PLAIN);
      job.RemoteId := ACLOG_ADDED_MARKER;
      r := client.Deliver(job);
      CheckTrue(r.Outcome = doFailed, 'an edit of a delivered contact fails');
      CheckEquals('ACLOG_EDIT_UNSUPPORTED', r.ErrorCode);
      CheckFalse(r.Pause, 'and does not halt the destination');
      CheckEquals(0, r.Status);
      job.Deleted := True;
      r := client.Deliver(job);
      CheckTrue(r.Outcome = doFailed, 'a delete of a delivered contact fails');
      CheckEquals('ACLOG_DELETE_UNSUPPORTED', r.ErrorCode);
      CheckFalse(r.Pause);
      job := NewJob(ADIF_PLAIN);
      job.Deleted := True;
      r := client.Deliver(job);
      CheckTrue(r.Outcome = doConfirmed, 'a delete of a contact never delivered is cancelled locally');
      Sleep(150);
      CheckEquals(0, FHits, 'no connection was made for any of the three');
   finally
      client.Free;
      StopServer;
   end;
end;

procedure TACLogTests.Test_SetupRequired;
var
   client: TACLogClient;
   r: TExternalDeliveryResult;
begin
   BeginTest('no host, or port 0: paused with its own code, nothing sent');
   client := TACLogClient.Create('', 1100);
   try
      r := client.Deliver(NewJob(ADIF_PLAIN));
   finally
      client.Free;
   end;
   CheckEquals('ACLOG_SETUP_REQUIRED', r.ErrorCode);
   CheckTrue(r.Pause);
   client := TACLogClient.Create('127.0.0.1', 0);
   try
      r := client.Deliver(NewJob(ADIF_PLAIN));
   finally
      client.Free;
   end;
   CheckEquals('ACLOG_SETUP_REQUIRED', r.ErrorCode);
   CheckTrue(r.Pause);
end;

procedure TACLogTests.Test_Descriptors_AndDefinitionError;
var
   registration: TExternalLoggerRegistration;
   fields: TLoggerFieldList;
   d: TExternalLoggerDefinition;
begin
   BeginTest('Descriptors: ACLog declares a required host and a port, nothing else');
   CheckTrue(FindExternalLoggerRegistration('ACLOG', registration), 'registered');
   CheckEquals('ACLog', registration.DisplayName);
   CheckEquals(1100, registration.DefaultPort, 'AC Log''s TCP API default');
   fields := registration.CreateFields;
   try
      CheckEquals(2, fields.Count);
      CheckEquals(LF_ADDRESS, fields[0].Key);
      CheckTrue(fields[0].Kind = lfkText, 'host is text');
      CheckTrue(fields[0].Required);
      CheckEquals(SLoggerFieldHost, fields[0].Caption, 'reuses the existing caption');
      CheckEquals(LF_PORT, fields[1].Key);
      CheckTrue(fields[1].Kind = lfkPort);
      CheckEquals(SLoggerFieldPort, fields[1].Caption);
   finally
      fields.Free;
   end;
   BeginTest('Definition check: host and a port in range are required');
   d := TExternalLoggerDefinition.Create;
   try
      d.ProviderId := 'ACLOG';
      d.Name := 'Shack';
      CheckTrue(ExternalLoggerDefinitionError(d) <> '', 'empty: refused');
      d.Address := 'localhost';
      CheckTrue(ExternalLoggerDefinitionError(d) <> '', 'no port: refused');
      d.Port := 70000;
      CheckTrue(ExternalLoggerDefinitionError(d) <> '', 'port out of range: refused');
      d.Port := 1100;
      CheckEquals('', ExternalLoggerDefinitionError(d), 'host and port: accepted');
      d.Address := '';
      CheckTrue(ExternalLoggerDefinitionError(d) <> '', 'no host: refused');
   finally
      d.Free;
   end;
end;

procedure TACLogTests.Test_DestinationIdentity;
var
   d: TExternalLoggerDefinition;
   first: string;
begin
   BeginTest('Destination identity: another host or port parks the old backlog');
   d := TExternalLoggerDefinition.Create;
   try
      d.ProviderId := 'ACLOG';
      d.Id := 'fixed';
      d.Address := 'localhost';
      d.Port := 1100;
      first := d.DeliveryId;
      d.Name := 'renamed';
      CheckEquals(first, d.DeliveryId, 'a rename keeps the backlog');
      d.Address := '192.168.1.20';
      CheckTrue(first <> d.DeliveryId, 'another host');
      d.Address := 'localhost';
      CheckEquals(first, d.DeliveryId, 'and back again');
      d.Port := 1101;
      CheckTrue(first <> d.DeliveryId, 'another port');
   finally
      d.Free;
   end;
end;

procedure TACLogTests.Test_Registry;
var
   i, count: integer;
   registration: TExternalLoggerRegistration;
   d: TExternalLoggerDefinition;
   service: TObject;
begin
   BeginTest('Registry: ACLOG is registered exactly once and builds the durable provider');
   count := 0;
   for i := 0 to ExternalLoggerProviderCount - 1 do
      begin
      if ExternalLoggerRegistration(i).Id = 'ACLOG' then
         begin
         Inc(count);
         end;
      end;
   CheckEquals(1, count, 'one registration');
   CheckTrue(FindExternalLoggerRegistration('DXKEEPER', registration));
   CheckEquals(DXKEEPER_DEFAULT_PORT, registration.DefaultPort, 'DXKeeper keeps 52001');
   d := TExternalLoggerDefinition.Create;
   try
      d.ProviderId := 'ACLOG';
      d.Name := 'AC Log';
      d.Address := 'localhost';
      d.Port := 1100;
      service := TExternalLoggerFactory.CreateLogger(d, 'A');
      try
         CheckTrue(service is TACLogExternalLogger, 'the factory builds the durable provider');
      finally
         service.Free;
      end;
   finally
      d.Free;
   end;
   BeginTest('the legacy lt_ACLog token is only vocabulary now: the factory reports it supported through the registry');
   CheckTrue(TExternalLoggerFactory.IsLoggerSupported(lt_ACLog), 'resolved by the ACLOG registration');
end;

procedure TACLogTests.Test_LegacyTokenMigrates;
var
   config: TExternalLoggerConfig;
   legacy: TExternalLoggerSettings;
begin
   BeginTest('EXTERNAL LOGGER = ACLOG becomes an ACLOG definition: its host, and AC Log''s port when none was chosen');
   config := TExternalLoggerConfig.Create;
   legacy := TExternalLoggerSettings.Create;
   try
      legacy.LoggerType := 'ACLOG';
      legacy.Address := '10.0.0.5';
      legacy.Enabled := True;
      CheckTrue(SeedExternalLoggers(config, legacy));
      CheckEquals(1, config.Definitions.Count, 'the token did not disappear');
      CheckEquals('ACLOG', config.Definitions[0].ProviderId);
      CheckEquals('10.0.0.5', config.Definitions[0].Address);
      CheckEquals(1100, config.Definitions[0].Port, 'the untouched DXKeeper default is not carried over');
      CheckEquals(1, config.ActiveIds.Count, 'enabled stays enabled');
      CheckEquals('', ExternalLoggerDefinitionError(config.Definitions[0]));
   finally
      legacy.Free;
      config.Free;
   end;
   BeginTest('a port the operator chose survives the migration; DXKeeper is unchanged');
   config := TExternalLoggerConfig.Create;
   legacy := TExternalLoggerSettings.Create;
   try
      legacy.LoggerType := 'ACLOG';
      legacy.Port := 1234;
      CheckTrue(SeedExternalLoggers(config, legacy));
      CheckEquals(1234, config.Definitions[0].Port);
   finally
      legacy.Free;
      config.Free;
   end;
   config := TExternalLoggerConfig.Create;
   legacy := TExternalLoggerSettings.Create;
   try
      legacy.LoggerType := 'DXKEEPER';
      CheckTrue(SeedExternalLoggers(config, legacy));
      CheckEquals(52001, config.Definitions[0].Port);
   finally
      legacy.Free;
      config.Free;
   end;
end;

procedure TACLogTests.RunAllTests;
begin
   FLock := TCriticalSection.Create;
   FDone := TEvent.Create(nil, True, False, '');
   try
      Test_WireBytes;
      Test_Success_IsAHandOffWithAMarker;
      Test_ClosedPort_IsARetryNotAPause;
      Test_FailureAfterConnect_IsUncertainAndPaused;
      Test_EditAndDelete_Policy;
      Test_SetupRequired;
      Test_Descriptors_AndDefinitionError;
      Test_DestinationIdentity;
      Test_Registry;
      Test_LegacyTokenMigrates;
   finally
      StopServer;
      FDone.Free;
      FLock.Free;
   end;
end;

end.
