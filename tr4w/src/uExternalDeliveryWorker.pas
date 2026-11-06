unit uExternalDeliveryWorker;
{$I tr4w.inc}

(* RULE FOR ANY WORKER THAT NOTIFIES ITS OWNER BY CALLBACK (peer review R1,
   2026-11-04; integrations agent): dispatch the callback WHILE HOLDING the
   lock ForgetOwner takes. A stalled worker is not joined at close, so it
   outlives its owner; a callback copied out and called after the lock is
   released can be in flight when ForgetOwner returns, and nothing can revoke
   it. The callback only queues work, never waits on the main thread. The owner
   calls RemoveAsyncCalls only AFTER ForgetOwner has returned. Pinned by
   TWRLDeliveryTests.TestNoticeForgetOwner. *)

interface

uses
   Classes, SysUtils, SyncObjs, uExternalDeliveryClient, uLogConnectionWatch, uLogDatabase,
   uExternalDelivery, uExternalLoggerService;

const
   (* THE WORKER'S BUSY WAIT: 1 s, half the main connection's
     (LOG_BUSY_TIMEOUT_MS). The junior partner gives up first and retries on
     its own clock; the main thread is the one an operator is waiting on. *)
   DELIVERY_WORKER_BUSY_TIMEOUT_MS = 1000;

   (* How many times one unit of the worker's work is retried after a busy
     failure before the worker stops (its pending work stays on disk). *)
   DELIVERY_WORKER_BUSY_ATTEMPTS = 5;

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
   TExternalDeliveryWorker = class(TThread)
   private
      FFileName, FAccount, FLoggerId: string;
      FWake: TEvent;
      FNoticeLock: TCriticalSection;
      FNotice: string;
      FOnNotice: TThreadMethod;
      FWatch: TLogConnectionWatch;
      (* WHAT THE OWNER MAY ASK AT ANY TIME (issue 226): is a request out, how
         the last delivery ended, and whether the worker has given up. Written
         by this thread, read by the main thread through FillSnapshot, both
         under FStatusLock. Never the notice (TakeNotice consumes that). *)
      FStatusLock: TCriticalSection;
      FBusy, FHalted, FHasResult: boolean;
      FLastOutcome: TDeliveryOutcome;
      FCode: string;
      procedure SetBusy(aBusy: boolean);
      procedure RecordResult(aOutcome: TDeliveryOutcome; const aCode: string);
      procedure MarkHalted(const aCode: string);
      (* AFTER A FAILURE INSIDE A TRANSACTION: roll it back, and say whether
        to try the unit of work again -- True for a busy failure within
        DELIVERY_WORKER_BUSY_ATTEMPTS (after a 50 ms pause), False otherwise, when
        the caller re-raises. Never lets a transaction outlive its failure. *)
      function RetryAfterBusy(aDatabase: TLogDatabase; E: Exception;
                              var aAttempts: integer): boolean;
   protected
      (* Records the worker's latest notice and tells the owner, under
        FNoticeLock. Protected so a test can drive it without a database. *)
      procedure Notice(const aText: string);
      procedure Execute; override;
      function NewClient: TExternalDeliveryClient; virtual; abstract;
   public
      constructor Create(const aFileName, aAccount, aLoggerId: string);
      destructor Destroy; override;
      procedure Wake;
      procedure RequestStop;
      function TakeNotice: string;
      (* Copies the status fields into aSnapshot (Busy, Halted, HasResult,
         LastOutcome, Code). Any thread. *)
      procedure FillSnapshot(var aSnapshot: TExternalLoggerSnapshot);
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
   DateUtils, sqldb, Log4D;

constructor TExternalDeliveryWorker.Create(const aFileName, aAccount, aLoggerId: string);
begin
   inherited Create(True);
   FFileName := aFileName;
   FAccount := aAccount;
   FLoggerId := aLoggerId;
   FWake := TEvent.Create(nil, False, False, '');
   FNoticeLock := TCriticalSection.Create;
   FStatusLock := TCriticalSection.Create;
   (* Created and registered HERE, on the main thread, so the registry is
     only ever changed by the thread that runs the watchdog. *)
   FWatch := TLogConnectionWatch.Create(aLoggerId + ' delivery worker');
   RegisterLogConnectionWatch(FWatch);
end;

destructor TExternalDeliveryWorker.Destroy;
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
   FStatusLock.Free;
   (* After the thread has ended, so its connection is closed and detached;
     the watch unregisters itself. *)
   FWatch.Free;
end;

function TExternalDeliveryWorker.RetryAfterBusy(aDatabase: TLogDatabase; E: Exception;
                                   var aAttempts: integer): boolean;
begin
   (* ROLLED BACK WHATEVER THE FAILURE WAS: a transaction that has failed is
     never left open for the next statement, or for the finally, to commit. *)
   aDatabase.Rollback;
   Inc(aAttempts);
   (* NOT cut short by Terminated: a settle carries a server's answer, and
     giving up on it would leave a sent contact to be judged "uncertain" on
     the next start. Five tries are bounded by the busy wait. *)
   Result := SQLiteIsBusy(E) and (aAttempts < DELIVERY_WORKER_BUSY_ATTEMPTS);
   if Result then
      begin
      FWake.WaitFor(50);
      end;
end;

procedure TExternalDeliveryWorker.Wake;
begin
   FWake.SetEvent;
end;

procedure TExternalDeliveryWorker.RequestStop;
begin
   Terminate;
   Wake;
end;

procedure TExternalDeliveryWorker.Notice(const aText: string);
var
   notifyOwner: boolean;
begin
   (* THE CALLBACK RUNS UNDER THE LOCK (2026-11-04, peer review R1). Copied
     out and called after Leave, a call could already be in flight when
     ForgetOwner returned, and the owner's RemoveAsyncCalls could not revoke
     it. Holding FNoticeLock across the call makes ForgetOwner wait for a call
     in progress, and no call starts after it returns. The method pointer is
     two words, so it is also never read half-written.

     THE INVARIANT THAT MAKES THAT SAFE: the callback must return promptly and
     must NOT wait on the main thread (ForgetOwner may be holding the main
     thread at this very lock: a wait there is a deadlock) and must not call
     TakeNotice (it would eat the notice just recorded).
     TWRLExternalLogger.QueueDeliveryNotice only queues an async call, which
     is neither. *)
   FNoticeLock.Enter;
   try
      notifyOwner := FNotice = '';
      FNotice := aText;
      if notifyOwner and Assigned(FOnNotice) then
         begin
         FOnNotice;
         end;
   finally
      FNoticeLock.Leave;
   end;
end;

procedure TExternalDeliveryWorker.SetBusy(aBusy: boolean);
begin
   FStatusLock.Enter;
   try
      FBusy := aBusy;
   finally
      FStatusLock.Leave;
   end;
end;

procedure TExternalDeliveryWorker.RecordResult(aOutcome: TDeliveryOutcome;
   const aCode: string);
begin
   FStatusLock.Enter;
   try
      FBusy := False;
      FHasResult := True;
      FLastOutcome := aOutcome;
      FCode := aCode;
   finally
      FStatusLock.Leave;
   end;
end;

procedure TExternalDeliveryWorker.MarkHalted(const aCode: string);
begin
   FStatusLock.Enter;
   try
      FBusy := False;
      FHalted := True;
      FCode := aCode;
   finally
      FStatusLock.Leave;
   end;
end;

procedure TExternalDeliveryWorker.FillSnapshot(var aSnapshot: TExternalLoggerSnapshot);
begin
   FStatusLock.Enter;
   try
      aSnapshot.Busy := FBusy;
      aSnapshot.Halted := FHalted;
      aSnapshot.HasResult := FHasResult;
      aSnapshot.LastOutcome := FLastOutcome;
      aSnapshot.Code := FCode;
   finally
      FStatusLock.Leave;
   end;
end;

procedure TExternalDeliveryWorker.ForgetOwner;
begin
   FNoticeLock.Enter;
   try
      FOnNotice := nil;
   finally
      FNoticeLock.Leave;
   end;
   FWatch.OnGiveUp := nil;
end;

function TExternalDeliveryWorker.TakeNotice: string;
begin
   FNoticeLock.Enter;
   try
      Result := FNotice;
      FNotice := '';
   finally
      FNoticeLock.Leave;
   end;
end;

procedure TExternalDeliveryWorker.Execute;
var
   database: TLogDatabase;
   delivery: TExternalDelivery;
   client: TExternalDeliveryClient;
   job: TDeliveryJob;
   answer: TExternalDeliveryResult;
   nowUTC, nextSend, due, delay: Int64;
   waitMs: Cardinal;
   log: TLogLogger;
   q: TSQLQuery;
   claimed, settled, done: boolean;
   settleAttempts, attempts: integer;
begin
   log := TLogLogger.GetLogger(FLoggerId);
   database := TLogDatabase.Create;
   delivery := nil;
   client := nil;
   try
      try
         (* The junior partner's wait, set before Open so it is the first
           pragma the connection runs; and the watch, so the main program's
           watchdog sees this connection's transactions. *)
         database.BusyTimeoutMs := DELIVERY_WORKER_BUSY_TIMEOUT_MS;
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
                  q.SQL.Text := 'SELECT value FROM session_state WHERE key = :key';
                  q.ParamByName('key').AsUTF8String := UTF8Encode(ExternalDeliveryGapKey(FLoggerId));
                  q.Open;
                  if not q.EOF then
                     begin
                     q.Close;
                     log.Warn('[ExternalDelivery] The log records an earlier capture gap; some past contact ' +
                        'was not queued for this destination. Clearing the marker; new contacts continue.');
                     q.SQL.Text := 'DELETE FROM session_state WHERE key = :key';
                     q.ParamByName('key').AsUTF8String := UTF8Encode(ExternalDeliveryGapKey(FLoggerId));
                     q.ExecSQL;
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
               delivery.RecoverInterrupted(FLoggerId, FAccount, client.RecoverUpdatesAsUncertain);
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
               log.Warn('[ExternalDelivery] The watchdog found a transaction left open; rolling it back');
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
               claimed := delivery.Claim(FLoggerId, FAccount, nowUTC, job);
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
               due := delivery.NextAttempt(FLoggerId, FAccount);
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
            SetBusy(True);
            answer := client.Deliver(job);
            if answer.OperatorNotice <> '' then
               begin
               (* Queued to the main thread by the owner; never shown from here. *)
               Notice(answer.OperatorNotice);
               end;
            if (answer.Status = 401) or (answer.Status = 403) then
               begin
               (* Retain work for a replacement credential, but stop this
                  worker below: authentication rejection is not retried in a loop. *)
               answer.Outcome := doRetry;
               answer.RetrySeconds := 60;
               end;
            RecordResult(answer.Outcome, answer.ErrorCode);
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
               log.Warn('[ExternalDelivery] Contact %s: %s (HTTP %d)',
                  [job.Key.Contact, answer.ErrorCode, answer.Status]);
               Notice(answer.ErrorCode);
               end;
            if answer.Pause or (answer.Status = 401) or (answer.Status = 403) then
               begin
               log.Error('[ExternalDelivery] Delivery paused: credentials or account access require attention');
               if answer.ErrorCode <> '' then
                  begin
                  MarkHalted(answer.ErrorCode);
                  Notice(answer.ErrorCode);
                  end
               else
                  begin
                  MarkHalted('AUTHENTICATION_REQUIRED');
                  Notice('AUTHENTICATION_REQUIRED');
                  end;
               Break;
               end;
            end;
      except
         on E: Exception do
            begin
            (* Do not log exception text: SQL and HTTP exceptions can carry
               contact contents. In-flight creation remains uncertain on reopen. *)
            log.Error('[ExternalDelivery] Delivery stopped (%s); pending work remains in the log', [E.ClassName]);
            MarkHalted(DELIVERY_STOPPED_CODE);
            Notice(DELIVERY_STOPPED_CODE);
            end;
      end;
   finally
      client.Free;
      delivery.Free;
      database.Free;
   end;
end;

end.
