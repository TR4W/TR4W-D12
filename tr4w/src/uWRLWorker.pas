unit uWRLWorker;
{$I tr4w.inc}

interface

uses
   Classes, SysUtils, SyncObjs, uWRLClient, uLogConnectionWatch, uLogDatabase;

const
   (* THE WORKER'S BUSY WAIT: 1 s, half the main connection's
     (LOG_BUSY_TIMEOUT_MS). The junior partner gives up first and retries on
     its own clock; the main thread is the one an operator is waiting on. *)
   WRL_WORKER_BUSY_TIMEOUT_MS = 1000;

   (* How many times one unit of the worker's work is retried after a busy
     failure before the worker stops (its pending work stays on disk). *)
   WRL_WORKER_BUSY_ATTEMPTS = 5;

type
   (* Owns its SQLDB connection and HTTP client on its own thread. No database
      transaction spans an HTTP request. Wake is only a hint: startup always
      scans durable work and retries have their own persisted deadlines.

      TRANSACTION DISCIPLINE (audited 2026-10-31). Every transaction is a
      claim, a settle, the startup recovery or the capture-gap clear, each
      ended by Commit before anything else happens -- before HTTP and before
      any wait. A failure inside one rolls it back (RetryAfterBusy, or the
      database's Close in the finally, which rolls back what is open). Its
      connection reports to Watch, so the main program's watchdog sees any
      transaction that stays open (uLogConnectionWatch). *)
   TWRLWorker = class(TThread)
   private
      FFileName, FAccount, FApiKey: string;
      FWake: TEvent;
      FNoticeLock: TCriticalSection;
      FNotice: string;
      FOnNotice: TThreadMethod;
      FWatch: TLogConnectionWatch;
      procedure Notice(const aText: string);
      (* AFTER A FAILURE INSIDE A TRANSACTION: roll it back, and say whether
        to try the unit of work again -- True for a busy failure within
        WRL_WORKER_BUSY_ATTEMPTS (after a 50 ms pause), False otherwise, when
        the caller re-raises. Never lets a transaction outlive its failure. *)
      function RetryAfterBusy(aDatabase: TLogDatabase; E: Exception;
                              var aAttempts: integer): boolean;
   protected
      procedure Execute; override;
      function NewClient: TWRLClient; virtual;
   public
      constructor Create(const aFileName, aAccount, aApiKey: string);
      destructor Destroy; override;
      procedure Wake;
      procedure RequestStop;
      function TakeNotice: string;
      (* For a worker its owner abandons without freeing (a stalled one left
        at close): nothing it does from now on calls back into the owner. *)
      procedure ForgetOwner;
      property OnNotice: TThreadMethod read FOnNotice write FOnNotice;
      (* Registered with the watchdog from Create to Destroy. Its OnGiveUp
        belongs to the owner. *)
      property Watch: TLogConnectionWatch read FWatch;
   end;

implementation

uses
   DateUtils, sqldb, uExternalDelivery, Log4D;

constructor TWRLWorker.Create(const aFileName, aAccount, aApiKey: string);
begin
   inherited Create(True);
   FFileName := aFileName;
   FAccount := aAccount;
   FApiKey := aApiKey;
   FWake := TEvent.Create(nil, False, False, '');
   FNoticeLock := TCriticalSection.Create;
   (* Created and registered HERE, on the main thread, so the registry is
     only ever changed by the thread that runs the watchdog. *)
   FWatch := TLogConnectionWatch.Create('WRL delivery worker');
   RegisterLogConnectionWatch(FWatch);
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
   (* After the thread has ended, so its connection is closed and detached;
     the watch unregisters itself. *)
   FWatch.Free;
end;

function TWRLWorker.RetryAfterBusy(aDatabase: TLogDatabase; E: Exception;
                                   var aAttempts: integer): boolean;
begin
   (* ROLLED BACK WHATEVER THE FAILURE WAS: a transaction that has failed is
     never left open for the next statement, or for the finally, to commit. *)
   aDatabase.Rollback;
   Inc(aAttempts);
   (* NOT cut short by Terminated: a settle carries a server's answer, and
     giving up on it would leave a sent contact to be judged "uncertain" on
     the next start. Five tries are bounded by the busy wait. *)
   Result := SQLiteIsBusy(E) and (aAttempts < WRL_WORKER_BUSY_ATTEMPTS);
   if Result then
      begin
      FWake.WaitFor(50);
      end;
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
   callback: TThreadMethod;
begin
   (* The callback is copied under the lock: ForgetOwner clears it from the
     main thread, and a method pointer is two words, so an unlocked read
     could see half of each. *)
   FNoticeLock.Enter;
   try
      notifyOwner := FNotice = '';
      FNotice := aText;
      callback := FOnNotice;
   finally
      FNoticeLock.Leave;
   end;
   if notifyOwner and Assigned(callback) then
      begin
      callback;
      end;
end;

procedure TWRLWorker.ForgetOwner;
begin
   FNoticeLock.Enter;
   try
      FOnNotice := nil;
   finally
      FNoticeLock.Leave;
   end;
   FWatch.OnGiveUp := nil;
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
   claimed, settled, done: boolean;
   settleAttempts, attempts: integer;
begin
   log := TLogLogger.GetLogger('WRL');
   database := TLogDatabase.Create;
   delivery := nil;
   client := nil;
   try
      try
         (* The junior partner's wait, set before Open so it is the first
           pragma the connection runs; and the watch, so the main program's
           watchdog sees this connection's transactions. *)
         database.BusyTimeoutMs := WRL_WORKER_BUSY_TIMEOUT_MS;
         database.Connection.Watch := FWatch;
         database.Open(FFileName);
         (* A capture gap means some earlier contact was not queued. This feed
            only sends NEW contacts onward and never reconciles history, so the
            marker is reported once, cleared, and delivery carries on. Leaving
            it in place stopped every later contact for good.

            COMMITTED OR ROLLED BACK, NEVER EITHER BY DEFAULT (2026-10-31).
            The finally here used to commit whatever was open, after a failure
            too, and a busy failure killed the worker. Now a busy is retried
            and anything else rolls back and stops the worker as before. *)
         attempts := 0;
         done := False;
         repeat
            try
               q := TSQLQuery.Create(nil);
               try
                  q.Database := database.Connection;
                  q.Transaction := database.Transaction;
                  q.SQL.Text := 'SELECT value FROM session_state WHERE key = ''external_delivery_gap''';
                  q.Open;
                  if not q.EOF then
                     begin
                     q.Close;
                     log.Warn('[WRL] The log records an earlier capture gap; some past contact ' +
                        'was not queued for WRL. Clearing the marker; new contacts continue.');
                     database.Connection.ExecuteDirect(
                        'DELETE FROM session_state WHERE key = ''external_delivery_gap''');
                     end;
               finally
                  q.Free;
               end;
               database.EndTransaction;
               done := True;
            except
               on E: Exception do
                  begin
                  if not RetryAfterBusy(database, E, attempts) then
                     begin
                     raise;
                     end;
                  end;
            end;
         until done;

         delivery := TExternalDelivery.Create(database);
         client := NewClient;
         attempts := 0;
         done := False;
         repeat
            try
               delivery.RecoverInterrupted('WRL', FAccount);
               database.Transaction.Commit;
               done := True;
            except
               on E: Exception do
                  begin
                  if not RetryAfterBusy(database, E, attempts) then
                     begin
                     raise;
                     end;
                  end;
            end;
         until done;
         nextSend := 0;
         while not Terminated do
            begin
            (* THE WATCHDOG ASKED (uLogConnectionWatch, step 1). Between
              statements, so whatever is open is ours to end. *)
            if FWatch.TakeRollbackRequest then
               begin
               log.Warn('[WRL] The watchdog found a transaction left open; rolling it back');
               database.Rollback;
               end;
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
                  if not SQLiteIsBusy(E) then
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
                  on E: Exception do
                     begin
                     if not RetryAfterBusy(database, E, settleAttempts) then
                        begin
                        raise;
                        end;
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
