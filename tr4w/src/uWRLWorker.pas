unit uWRLWorker;
{$I tr4w.inc}

interface

uses
   Classes, SyncObjs, uWRLClient;

type
   (* Owns its SQLDB connection and HTTP client on its own thread. No database
      transaction spans an HTTP request. Wake is only a hint: startup always
      scans durable work and retries have their own persisted deadlines. *)
   TWRLWorker = class(TThread)
   private
      FFileName, FAccount, FApiKey: string;
      FWake: TEvent;
      FNoticeLock: TCriticalSection;
      FNotice: string;
      FOnNotice: TThreadMethod;
      procedure Notice(const aText: string);
   protected
      procedure Execute; override;
      function NewClient: TWRLClient; virtual;
   public
      constructor Create(const aFileName, aAccount, aApiKey: string);
      destructor Destroy; override;
      procedure Wake;
      procedure RequestStop;
      function TakeNotice: string;
      property OnNotice: TThreadMethod read FOnNotice write FOnNotice;
   end;

implementation

uses
   SysUtils, DateUtils, sqldb, uLogDatabase, uExternalDelivery, Log4D;

function SQLiteBusy(aError: ESQLDatabaseError): boolean;
begin
   Result := ((aError.ErrorCode and $FF) = 5) or ((aError.ErrorCode and $FF) = 6);
end;

constructor TWRLWorker.Create(const aFileName, aAccount, aApiKey: string);
begin
   inherited Create(True);
   FFileName := aFileName;
   FAccount := aAccount;
   FApiKey := aApiKey;
   FWake := TEvent.Create(nil, False, False, '');
   FNoticeLock := TCriticalSection.Create;
end;

destructor TWRLWorker.Destroy;
begin
   Terminate;
   if FWake <> nil then
      begin
      FWake.SetEvent;
      end;
   (* HTTP has 5s connect / 10s I/O limits. Never free the event, client or
      connection underneath a running request. Unsent work stays on disk. *)
   if not Suspended then
      begin
      WaitFor;
      end;
   inherited Destroy;
   FWake.Free;
   FNoticeLock.Free;
end;

procedure TWRLWorker.Wake;
begin
   FWake.SetEvent;
end;

procedure TWRLWorker.RequestStop;
begin
   Terminate;
   Wake;
end;

procedure TWRLWorker.Notice(const aText: string);
var
   notifyOwner: boolean;
begin
   FNoticeLock.Enter;
   try
      notifyOwner := FNotice = '';
      FNotice := aText;
   finally
      FNoticeLock.Leave;
   end;
   if notifyOwner and Assigned(FOnNotice) then
      begin
      FOnNotice;
      end;
end;

function TWRLWorker.TakeNotice: string;
begin
   FNoticeLock.Enter;
   try
      Result := FNotice;
      FNotice := '';
   finally
      FNoticeLock.Leave;
   end;
end;

function TWRLWorker.NewClient: TWRLClient;
begin
   Result := TWRLClient.Create(FApiKey);
end;

procedure TWRLWorker.Execute;
var
   database: TLogDatabase;
   delivery: TExternalDelivery;
   client: TWRLClient;
   job: TDeliveryJob;
   answer: TWRLResult;
   nowUTC, nextSend, due, delay: Int64;
   waitMs: Cardinal;
   log: TLogLogger;
   q: TSQLQuery;
   claimed, settled: boolean;
   settleAttempts: integer;
begin
   log := TLogLogger.GetLogger('WRL');
   database := TLogDatabase.Create;
   delivery := nil;
   client := nil;
   try
      try
         database.Open(FFileName);
         database.Connection.ExecutePragma('PRAGMA busy_timeout = 1000');
         (* A capture gap means some earlier contact was not queued. This feed
            only sends NEW contacts onward and never reconciles history, so the
            marker is reported once, cleared, and delivery carries on. Leaving
            it in place stopped every later contact for good. *)
         q := TSQLQuery.Create(nil);
         try
            q.Database := database.Connection;
            q.Transaction := database.Transaction;
            q.SQL.Text := 'SELECT value FROM session_state WHERE key = ''external_delivery_gap''';
            q.Open;
            if not q.EOF then
               begin
               log.Warn('[WRL] The log records an earlier capture gap; some past contact ' +
                  'was not queued for WRL. Clearing the marker; new contacts continue.');
               database.Connection.ExecuteDirect(
                  'DELETE FROM session_state WHERE key = ''external_delivery_gap''');
               end;
         finally
            q.Free;
            if database.Transaction.Active then
               begin
               database.Transaction.Commit;
               end;
         end;
         delivery := TExternalDelivery.Create(database);
         client := NewClient;
         delivery.RecoverInterrupted('WRL', FAccount);
         database.Transaction.Commit;
         nextSend := 0;
         while not Terminated do
            begin
            nowUTC := DateTimeToUnix(Now, False);
            if nowUTC < nextSend then
               begin
               delay := nextSend - nowUTC;
               if delay > 3600 then
                  begin
                  delay := 3600;
                  end;
               FWake.WaitFor(Cardinal(delay * 1000));
               Continue;
               end;
            try
               claimed := delivery.Claim('WRL', FAccount, nowUTC, job);
            except
               on E: ESQLDatabaseError do
                  begin
                  if not SQLiteBusy(E) then
                     begin
                     raise;
                     end;
                  (* A WAL read snapshot cannot be upgraded after another
                     connection committed. Release it, then retry from current
                     data. No HTTP request has been made at this point. *)
                  database.Rollback;
                  FWake.WaitFor(50);
                  Continue;
                  end;
            end;
            if not claimed then
               begin
               due := delivery.NextAttempt('WRL', FAccount);
               database.Transaction.Commit;
               waitMs := High(Cardinal);
               if due >= 0 then
                  begin
                  delay := due - nowUTC;
                  if delay < 1 then
                     begin
                     delay := 1;
                     end;
                  if delay > 3600 then
                     begin
                     delay := 3600;
                     end;
                  waitMs := Cardinal(delay * 1000);
                  end;
               FWake.WaitFor(waitMs);
               Continue;
               end;
            database.Transaction.Commit;
            if Terminated then
               begin
               (* No request was attempted; leave the snapshot pending. *)
               delivery.Complete(job, doRetry, '', '', '', 0);
               database.Transaction.Commit;
               Break;
               end;
            answer := client.Deliver(job);
            if (answer.Status = 401) or (answer.Status = 403) then
               begin
               (* Retain work for a replacement credential, but stop this
                  worker below: authentication rejection is not retried in a loop. *)
               answer.Outcome := doRetry;
               answer.RetrySeconds := 60;
               end;
            nowUTC := DateTimeToUnix(Now, False);
            nextSend := nowUTC + 1;  (* at most 60 writes/minute *)
            if answer.Status = 0 then
               begin
               nextSend := nowUTC;  (* local cancellation/validation used no API budget *)
               end;
            if (answer.Outcome in [doRetry, doUncertain]) and
               ((answer.Status = 0) or (answer.Status >= 500)) then
               begin
               nextSend := nowUTC + 60;
               end;
            due := 0;
            if answer.Outcome = doRetry then
               begin
               due := nowUTC + answer.RetrySeconds;
               if due <= nowUTC then
                  begin
                  due := nowUTC + 1;
                  end;
               if answer.Status = 429 then
                  begin
                  nextSend := due;
                  end;
               end;
            settled := False;
            settleAttempts := 0;
            repeat
               try
                  delivery.Complete(job, answer.Outcome, answer.RemoteId,
                     answer.ErrorCode, answer.RequestId, due);
                  database.Transaction.Commit;
                  settled := True;
               except
                  on E: ESQLDatabaseError do
                     begin
                     Inc(settleAttempts);
                     if not SQLiteBusy(E) or (settleAttempts >= 5) then
                        begin
                        raise;
                        end;
                     database.Rollback;
                     FWake.WaitFor(50);
                     end;
               end;
            until settled;
            if answer.Outcome in [doUncertain, doFailed] then
               begin
               log.Warn('[WRL] Contact %s: %s (HTTP %d)',
                  [job.Key.Contact, answer.ErrorCode, answer.Status]);
               Notice(answer.ErrorCode);
               end;
            if (answer.Status = 401) or (answer.Status = 403) then
               begin
               log.Error('[WRL] Delivery paused: credentials or account access require attention');
               Notice('AUTHENTICATION_REQUIRED');
               Break;
               end;
            end;
      except
         on E: Exception do
            begin
            (* Do not log exception text: SQL and HTTP exceptions can carry
               contact contents. In-flight creation remains uncertain on reopen. *)
            log.Error('[WRL] Delivery stopped (%s); pending work remains in the log', [E.ClassName]);
            Notice('DELIVERY_STOPPED');
            end;
      end;
   finally
      client.Free;
      delivery.Free;
      database.Free;
   end;
end;

end.
