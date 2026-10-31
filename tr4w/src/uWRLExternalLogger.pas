unit uWRLExternalLogger;
{$I tr4w.inc}

interface

uses
   VC, uQsoDispatcher, uExternalLoggerService, uLogDatabase, uLogRepository,
   uWRLWorker, uLogConnectionWatch, ExtCtrls;

type
   TWRLExternalLogger = class(TExternalLoggerService)
   private
      FAccount, FLogbook, FApiKey, FFileName: string;
      FComputerId: AnsiChar;
      FEnabled, FPaused: boolean;
      FWorker: TWRLWorker;
      FReported: boolean;
      FLocalNotice: string;
      (* THE WATCHDOG (uLogConnectionWatch) -- a main-thread LCL timer, 1 s,
        alive while a worker is. It lives HERE because this is the only owner
        of a secondary connection, and its last resort (stop the worker,
        start another) is this owner's to take. *)
      FWatchdog: TTimer;
      (* A worker the watchdog gave up on: asked to stop, not yet exited. It
        is freed, and a new one started, once it has (never waited for on the
        main thread -- it may be stuck in the very statement that stalled). *)
      FStalled: TWRLWorker;
      procedure QueueDeliveryNotice;
      procedure ShowDeliveryNotice(aData: PtrInt);
      procedure StartWorker;
      procedure WatchdogTick(Sender: TObject);
      procedure WorkerStalled(aWatch: TLogConnectionWatch);
   public
      constructor Create(const aAccount, aLogbook, aApiKey: string;
                         aComputerId: AnsiChar; aEnabled: boolean);
      destructor Destroy; override;
      function PrepareOp(const aKind: TQsoMessageKind; const ce: ContestExchange;
                         out aCommand1: string; out aCommand2: string): TQsoExternalOp; override;
      procedure SubmitOp(const aOp: TQsoExternalOp; const aCommand1: string;
                         const aCommand2: string; const aDescription: string); override;
      function LookupCallsign(ce: ContestExchange): integer; override;
      procedure CaptureSavedQso(aDatabase: TLogDatabase; aRepository: TLogRepository;
                                aRowId: Int64; aNew: boolean); override;
      procedure AfterLogCommit(aDatabase: TLogDatabase); override;
      procedure LogClosed; override;
   end;

implementation

uses
   SysUtils, sqldb, uQsoMyFacts, uExternalDelivery, uWRLContact, PostUnit, Log4D,
   uAppStrings, TF, Forms;

constructor TWRLExternalLogger.Create(const aAccount, aLogbook, aApiKey: string;
   aComputerId: AnsiChar; aEnabled: boolean);
begin
   inherited Create;
   FAccount := aAccount;
   FLogbook := aLogbook;
   FApiKey := aApiKey;
   FComputerId := aComputerId;
   FEnabled := aEnabled;
end;

destructor TWRLExternalLogger.Destroy;
begin
   LogClosed;
   inherited Destroy;
end;

function TWRLExternalLogger.PrepareOp(const aKind: TQsoMessageKind;
   const ce: ContestExchange; out aCommand1: string; out aCommand2: string): TQsoExternalOp;
begin
   aCommand1 := '';
   aCommand2 := '';
   Result := xoNone;  (* Delivery was captured with the QSO, not in this volatile queue. *)
end;

procedure TWRLExternalLogger.SubmitOp(const aOp: TQsoExternalOp;
   const aCommand1, aCommand2, aDescription: string);
begin
end;

function TWRLExternalLogger.LookupCallsign(ce: ContestExchange): integer;
begin
   Result := -1;
end;

procedure TWRLExternalLogger.CaptureSavedQso(aDatabase: TLogDatabase;
   aRepository: TLogRepository; aRowId: Int64; aNew: boolean);
var
   rec: ContestExchange;
   facts: TQsoMyFacts;
   sent: AnsiString;
   key: TDeliveryKey;
   destinations: array of TDeliveryKey;
   i: integer;
   payload: string;
   q: TSQLQuery;
   delivery: TExternalDelivery;
   savepointOpen: boolean;
begin
   if not FEnabled or FPaused or (FAccount = '') or (FLogbook = '') then
      begin
      Exit;
      end;
   if not aRepository.LoadQSO(aRowId, rec) or (rec.ceRecordKind <> rkQSO) then
      begin
      Exit;
      end;
   savepointOpen := False;
   try
      aDatabase.Connection.ExecuteDirect('SAVEPOINT external_capture');
      savepointOpen := True;
      key.Logger := 'WRL';
      key.Account := FAccount;
      key.Logbook := FLogbook;
      q := TSQLQuery.Create(nil);
      try
         q.Database := aDatabase.Connection;
         q.Transaction := aDatabase.Transaction;
         q.UsePrimaryKeyAsKey := False;
         q.SQL.Text := 'SELECT guid FROM qso WHERE id = :id';
         q.ParamByName('id').AsLargeInt := aRowId;
         q.Open;
         key.Contact := UTF8Decode(q.Fields[0].AsUTF8String);
         q.Close;
         (* An existing binding is the original uploader's durable ownership.
            It survives an edited computer ID and a changed setup destination. *)
         q.SQL.Text := 'SELECT account, logbook FROM external_delivery ' +
            'WHERE logger = ''WRL'' AND contact = :contact';
         q.ParamByName('contact').AsUTF8String := UTF8Encode(key.Contact);
         q.Open;
         SetLength(destinations, 0);
         while not q.EOF do
            begin
            i := Length(destinations);
            SetLength(destinations, i + 1);
            destinations[i] := key;
            destinations[i].Account := UTF8Decode(q.FieldByName('account').AsUTF8String);
            destinations[i].Logbook := UTF8Decode(q.FieldByName('logbook').AsUTF8String);
            q.Next;
            end;
         q.Close;
         if Length(destinations) = 0 then
            begin
            if not aNew or not QsoWasLoggedHere(rec.ceComputerID, FComputerId) then
               begin
               (* No implicit backfill and no upload of a peer-owned row. *)
               aDatabase.Connection.ExecuteDirect('RELEASE SAVEPOINT external_capture');
               Exit;
               end;
            SetLength(destinations, 1);
            destinations[0] := key;
            end;
      finally
         q.Free;
      end;
      payload := '{}';
      if not rec.ceQSO_Deleted then
         begin
         aRepository.LoadQSOMyFacts(aRowId, facts, sent);
         payload := WRLContactFromADIF(ADIFContactForExternal(rec, facts, sent),
            UTF8Decode(facts.Call));
         end;
      delivery := TExternalDelivery.Create(aDatabase);
      try
         for i := 0 to High(destinations) do
            begin
            delivery.Enqueue(destinations[i], payload, rec.ceQSO_Deleted);
            end;
      finally
         delivery.Free;
      end;
      aDatabase.Connection.ExecuteDirect('RELEASE SAVEPOINT external_capture');
   except
      on E: Exception do
         begin
         FPaused := True;
         if savepointOpen then
            begin
            (* If SQLite aborted the outer transaction, this raises too: the
               caller must then report LOCAL save failure rather than success. *)
            aDatabase.Connection.ExecuteDirect('ROLLBACK TO SAVEPOINT external_capture');
            aDatabase.Connection.ExecuteDirect('RELEASE SAVEPOINT external_capture');
            aRepository.ReprepareAfterSavepointRollback;
            end;
         try
            aDatabase.Connection.ExecuteDirect(
               'INSERT OR REPLACE INTO session_state(key, value) ' +
               'VALUES (''external_delivery_gap'', ''1'')');
         except
            on markerError: Exception do
               begin
               TLogLogger.GetLogger('WRL').Error(
                  '[WRL] Could not persist the synchronization-gap marker (%s)',
                  [markerError.ClassName]);
               end;
         end;
         TLogLogger.GetLogger('WRL').Error(
            '[WRL] Delivery capture paused (%s); local logging continues. ' +
            'Review delivery before resuming synchronization.', [E.ClassName]);
         end;
   end;
end;

procedure TWRLExternalLogger.AfterLogCommit(aDatabase: TLogDatabase);
begin
   if FPaused then
      begin
      if FWorker <> nil then
         begin
         FWorker.RequestStop;
         end;
      ShowDeliveryNotice(0);
      Exit;
      end;
   if not FEnabled then
      begin
      Exit;
      end;
   if (FAccount = '') or (FLogbook = '') or (FApiKey = '') then
      begin
      (* A temporarily unavailable vault must not discard delivery intent.
         Capture still queues contacts when their destination is known. *)
      FLocalNotice := 'WRL_SETUP_REQUIRED';
      ShowDeliveryNotice(0);
      Exit;
      end;
   if (FWorker <> nil) and (FFileName <> aDatabase.FileName) then
      begin
      LogClosed;
      end;
   if (FWorker = nil) and (FStalled = nil) then
      begin
      (* ~~PRAGMA busy_timeout = 250 on the MAIN connection~~ stood here until
        2026-10-31. It was the main connection's only busy wait, set only
        after its first commit, and it LOWERED that wait for the rest of the
        session. Every connection now gets its wait at open
        (TLogDatabase.BusyTimeoutMs; LOG_BUSY_TIMEOUT_MS for the main one),
        and the worker, the junior partner, a shorter one of its own. *)
      FFileName := aDatabase.FileName;
      StartWorker;
      end;
   if FWorker <> nil then
      begin
      FWorker.Wake;
      end;
end;

procedure TWRLExternalLogger.StartWorker;
begin
   FWorker := TWRLWorker.Create(FFileName, FAccount, FApiKey);
   FWorker.OnNotice := QueueDeliveryNotice;
   FWorker.Watch.OnGiveUp := WorkerStalled;
   if FWatchdog = nil then
      begin
      FWatchdog := TTimer.Create(nil);
      FWatchdog.Interval := 1000;
      FWatchdog.OnTimer := WatchdogTick;
      end;
   FWatchdog.Enabled := True;
   FWorker.Start;
end;

procedure TWRLExternalLogger.WatchdogTick(Sender: TObject);
var
   events: TLogWatchEvents;
   i: integer;
begin
   events := RunLogWatchdog(GetTickCount64);
   for i := 0 to High(events) do
      begin
      TLogLogger.GetLogger('WRL').Warn('[LogWatchdog] %s', [events[i]]);
      end;

   (* THE LAST RESORT'S SECOND HALF: the stopped worker has exited, so its
     connection is closed and its lock gone. Pending deliveries are durable
     in external_delivery, so a new worker simply carries on. *)
   if (FStalled <> nil) and FStalled.Finished then
      begin
      FreeAndNil(FStalled);
      if FFileName <> '' then
         begin
         TLogLogger.GetLogger('WRL').Warn('[LogWatchdog] the stalled WRL worker has ' +
            'exited; starting a new one');
         StartWorker;
         FWorker.Wake;
         end;
      end;
end;

procedure TWRLExternalLogger.WorkerStalled(aWatch: TLogConnectionWatch);
begin
   (* On the main thread, from the watchdog. The worker is NOT waited for
     here: it may be inside the statement that will not finish, and the main
     thread is the operator's. It is asked to stop, and the tick above frees
     it once it has. Its connection is never closed from this thread --
     sqldb objects belong to the thread that made them. *)
   if (FWorker = nil) or (aWatch <> FWorker.Watch) then
      begin
      Exit;
      end;
   TLogLogger.GetLogger('WRL').Error('[LogWatchdog] the WRL worker''s transaction will ' +
      'not end; stopping the worker. Pending deliveries remain in the log.');
   FWorker.RequestStop;
   FStalled := FWorker;
   FWorker := nil;
end;

procedure TWRLExternalLogger.QueueDeliveryNotice;
begin
   (* Called on the worker. The callback only queues a main-thread notice.
      LogClosed joins the worker before removing this owner's queued calls. *)
   Application.QueueAsyncCall(ShowDeliveryNotice, 0);
end;

procedure TWRLExternalLogger.ShowDeliveryNotice(aData: PtrInt);
var
   notice: string;
begin
   if FReported then
      begin
      Exit;
      end;
   notice := '';
   if FLocalNotice <> '' then
      begin
      notice := FLocalNotice;
      end
   else if FPaused then
      begin
      notice := 'SYNCHRONIZATION_GAP';
      end
   else if FWorker <> nil then
      begin
      notice := FWorker.TakeNotice;
      end;
   if notice <> '' then
      begin
      FReported := True;
      if not tSilentExport then
         begin
         showwarning(UTF8Decode(Format(SWRLDeliveryIssue, [UTF8Encode(notice)])));
         end;
      end;
end;

procedure TWRLExternalLogger.LogClosed;
begin
   FreeAndNil(FWatchdog);
   FreeAndNil(FWorker);
   (* A worker the watchdog gave up on is freed only if it has exited.
     Otherwise it is left, not waited for: freeing it would block the close
     on the statement that stalled it. It holds a connection that the
     process's exit releases. *)
   if FStalled <> nil then
      begin
      if FStalled.Finished then
         begin
         FreeAndNil(FStalled);
         end
      else
         begin
         TLogLogger.GetLogger('WRL').Error('[LogWatchdog] a stalled WRL worker had ' +
            'not exited by the close; left running');
         FStalled.ForgetOwner;
         FStalled := nil;
         end;
      end;
   Application.RemoveAsyncCalls(Self);
   FFileName := '';
   FPaused := False;
   FReported := False;
   FLocalNotice := '';
end;

end.
