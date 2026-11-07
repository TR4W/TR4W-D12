unit uDurableExternalLogger;
{$I tr4w.inc}

interface

uses
   VC, uQsoDispatcher, uExternalLoggerService, uLogDatabase, uLogRepository, uQsoMyFacts,
   uExternalDeliveryWorker, uLogConnectionWatch, ExtCtrls;

type
   TDurableExternalLogger = class(TExternalLoggerService)
   protected
      FLoggerId, FPassword: string;
      FAccount, FLogbook, FApiKey, FFileName: string;
      FComputerId: AnsiChar;
      FEnabled, FPaused: boolean;
      FWorker: TExternalDeliveryWorker;
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
      FStalled: TExternalDeliveryWorker;
      procedure QueueDeliveryNotice;
      procedure ShowDeliveryNotice(aData: PtrInt);
      procedure StartWorker;
      procedure WatchdogTick(Sender: TObject);
      procedure WorkerStalled(aWatch: TLogConnectionWatch);
   public
      function BuildPayload(const aRecord: ContestExchange; const aFacts: TQsoMyFacts;
                            const aSent: AnsiString): string; virtual; abstract;
      function CreateWorker: TExternalDeliveryWorker; virtual; abstract;
   public
      constructor Create(const aLoggerId, aAccount, aLogbook, aApiKey: string;
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
      procedure RequestStop; override;
      procedure SetActive(aActive: boolean); override;
      procedure FillSnapshot(var aSnapshot: TExternalLoggerSnapshot); override;
      function QueuesCommands: boolean; override;
      function StopFinished: boolean; override;
      procedure DetachOwner; override;
   end;

implementation

uses
   SysUtils, sqldb, uExternalDelivery,  PostUnit, Log4D,
   uAppStrings, TF, Forms;

constructor TDurableExternalLogger.Create(const aLoggerId, aAccount, aLogbook, aApiKey: string;
   aComputerId: AnsiChar; aEnabled: boolean);
begin
   inherited Create;
   FLoggerId := aLoggerId;
   FAccount := aAccount;
   FLogbook := aLogbook;
   FApiKey := aApiKey;
   FComputerId := aComputerId;
   FEnabled := aEnabled;
end;

destructor TDurableExternalLogger.Destroy;
begin
   LogClosed;
   inherited Destroy;
end;

function TDurableExternalLogger.PrepareOp(const aKind: TQsoMessageKind;
   const ce: ContestExchange; out aCommand1: string; out aCommand2: string): TQsoExternalOp;
begin
   aCommand1 := '';
   aCommand2 := '';
   Result := xoNone;  (* Delivery was captured with the QSO, not in this volatile queue. *)
end;

procedure TDurableExternalLogger.SubmitOp(const aOp: TQsoExternalOp;
   const aCommand1, aCommand2, aDescription: string);
begin
end;

function TDurableExternalLogger.LookupCallsign(ce: ContestExchange): integer;
begin
   Result := -1;
end;

procedure TDurableExternalLogger.CaptureSavedQso(aDatabase: TLogDatabase;
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
   if (not FEnabled and aNew) or FPaused or (FAccount = '') or (FLogbook = '') then
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
      key.Logger := FLoggerId;
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
            'WHERE logger = :logger AND contact = :contact';
         q.ParamByName('logger').AsUTF8String := UTF8Encode(FLoggerId);
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
            if not FEnabled or not aNew or not QsoWasLoggedHere(rec.ceComputerID, FComputerId) then
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
         payload := BuildPayload(rec, facts, sent);
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
            q := TSQLQuery.Create(nil);
            try
               q.Database := aDatabase.Connection;
               q.Transaction := aDatabase.Transaction;
               q.SQL.Text := 'INSERT OR REPLACE INTO session_state(key, value) VALUES (:key, ''1'')';
               q.ParamByName('key').AsUTF8String := UTF8Encode(ExternalDeliveryGapKey(FLoggerId));
               q.ExecSQL;
            finally
               q.Free;
            end;
         except
            on markerError: Exception do
               begin
               TLogLogger.GetLogger(FLoggerId).Error(
                  '[ExternalDelivery] Could not persist the synchronization-gap marker (%s)',
                  [markerError.ClassName]);
               end;
         end;
         TLogLogger.GetLogger(FLoggerId).Error(
            '[ExternalDelivery] Delivery capture paused (%s); local logging continues. ' +
            'Review delivery before resuming synchronization.', [E.ClassName]);
         end;
   end;
end;

procedure TDurableExternalLogger.AfterLogCommit(aDatabase: TLogDatabase);
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
      FLocalNotice := 'LOGGER_SETUP_REQUIRED';
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

procedure TDurableExternalLogger.StartWorker;
begin
   FWorker := CreateWorker;
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

procedure TDurableExternalLogger.WatchdogTick(Sender: TObject);
var
   events: TLogWatchEvents;
   i: integer;
begin
   events := nil;
   if FWorker <> nil then
      begin
      events := RunLogWatchdog(GetTickCount64, FWorker.Watch);
      end;
   for i := 0 to High(events) do
      begin
      TLogLogger.GetLogger(FLoggerId).Warn('[LogWatchdog] %s', [events[i]]);
      end;

   (* THE LAST RESORT'S SECOND HALF: the stopped worker has exited, so its
     connection is closed and its lock gone. Pending deliveries are durable
     in external_delivery, so a new worker simply carries on. *)
   if (FStalled <> nil) and FStalled.Finished then
      begin
      FreeAndNil(FStalled);
      if (FFileName <> '') and FEnabled then
         begin
         TLogLogger.GetLogger(FLoggerId).Warn('[LogWatchdog] the old delivery worker has ' +
            'exited; starting a new one');
         StartWorker;
         FWorker.Wake;
         end;
      end;
end;

procedure TDurableExternalLogger.WorkerStalled(aWatch: TLogConnectionWatch);
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
   TLogLogger.GetLogger(FLoggerId).Error('[LogWatchdog] the delivery worker''s transaction will ' +
      'not end; stopping the worker. Pending deliveries remain in the log.');
   FWorker.RequestStop;
   FStalled := FWorker;
   FWorker := nil;
end;

procedure TDurableExternalLogger.QueueDeliveryNotice;
begin
   (* Called on the worker, under the worker's notice lock, so it must stay
      this small: it only queues a main-thread notice and never waits on the
      main thread. LogClosed frees the live worker (a join), and for a stalled
      one calls ForgetOwner, which waits out a call in flight; only then does
      it remove this owner's queued calls. *)
   Application.QueueAsyncCall(ShowDeliveryNotice, 0);
end;

procedure TDurableExternalLogger.ShowDeliveryNotice(aData: PtrInt);
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
         showwarning(DisplayName + ': ' + notice);
         end;
      end;
end;

procedure TDurableExternalLogger.RequestStop;
begin
   if FWorker <> nil then
      begin
      FWorker.RequestStop;
      end;
   if FStalled <> nil then
      begin
      FStalled.RequestStop;
      end;
end;

(* Main thread. Issue 233: this is also how Save switches a RUNNING logger.

   ON only sets the flag: the worker starts on the next AfterLogCommit (Save
   calls it, so the pending outbox resumes at once), and contacts logged while
   it was off were never captured and stay unsent -- no backfill.

   OFF asks the worker to stop and parks it in FStalled, the slot a worker
   waits in until it has exited. It is NEVER waited for here (an HTTP request
   may be out, and this is the operator's thread): the worker finishes and
   settles the delivery it holds, then leaves; WatchdogTick frees it. Unsent
   work stays in the outbox, untouched, for the next enable. Capture of an
   EDIT or DELETE of an already-bound contact continues, as the design says. *)
procedure TDurableExternalLogger.SetActive(aActive: boolean);
begin
   FEnabled := aActive;
   if (not aActive) and (FWorker <> nil) then
      begin
      FWorker.RequestStop;
      (* FStalled is nil whenever FWorker is not: StartWorker runs only when
         both are, and WorkerStalled moves one into the other. *)
      FStalled := FWorker;
      FWorker := nil;
      end;
end;

(* Main thread, so FPaused, FLocalNotice and the worker pointers cannot change
   under it; the worker's own fields are read under its status lock. A worker
   that has exited without halting (the log closed) is simply not running. *)
procedure TDurableExternalLogger.FillSnapshot(var aSnapshot: TExternalLoggerSnapshot);
begin
   if FWorker <> nil then
      begin
      FWorker.FillSnapshot(aSnapshot);
      aSnapshot.WorkerRunning := not FWorker.Finished;
      end
   else if FStalled <> nil then
      begin
      aSnapshot.Halted := True;
      aSnapshot.Code := 'DELIVERY_STALLED';
      end;
   if FPaused then
      begin
      aSnapshot.Halted := True;
      aSnapshot.Code := 'SYNCHRONIZATION_GAP';
      end
   else if FLocalNotice <> '' then
      begin
      aSnapshot.Halted := True;
      aSnapshot.Code := FLocalNotice;
      end;
end;

function TDurableExternalLogger.QueuesCommands: boolean;
begin
   Result := False;  // uses its durable outbox, not a second in-memory command queue
end;

function TDurableExternalLogger.StopFinished: boolean;
begin
   Result := ((FWorker = nil) or FWorker.Finished) and
      ((FStalled = nil) or FStalled.Finished);
end;

procedure TDurableExternalLogger.DetachOwner;
begin
   FreeAndNil(FWatchdog);
   if FWorker <> nil then
      begin
      FWorker.ForgetOwner;
      end;
   if FStalled <> nil then
      begin
      FStalled.ForgetOwner;
      end;
   Application.RemoveAsyncCalls(Self);
end;

procedure TDurableExternalLogger.LogClosed;
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
         TLogLogger.GetLogger(FLoggerId).Error('[LogWatchdog] a stalled WRL worker had ' +
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
