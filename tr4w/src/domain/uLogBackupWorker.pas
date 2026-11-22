unit uLogBackupWorker;

(* THE PERIODIC BACKUP, OFF THE LOGGING THREAD (issue 350, 2026-11-21).

  WHY. The periodic backup -- a VACUUM INTO snapshot, an integrity check of
  the snapshot on its own connection, the publish by rename, and the local
  outbox copy for BACKUP DESTINATION -- ran inline in the Enter handler
  (LogContact -> logstuff.CountQsoTowardPeriodicBackup -> BackupLogNow), so
  the QSO that made it due waited for a whole-log copy and check before the
  entry was ready for the next call (docs/QSO_LOG_INTEGRITY_REVIEW.md,
  finding 4). The QSO itself is committed BEFORE that call; what the operator
  paid for was Enter-to-READY, not Enter-to-commit.

  WHAT RUNS HERE, on ONE worker thread per process:
     1. uLogBackup.TLogFileBackup.Run -- the same stage (.new), the same
        verification (StagedBackupIsSound, on its own read-only connection)
        and the same publish (displace to .bak, rename) as the synchronous
        path. Not a copy of it: the SAME class.
     2. after a successful publish, OnPublished (the program hands in
        uBackupCopyService.BackupCopySubmit, which copies the published file
        into the outbox under the copier's own lock).
  and the result goes to OnDone, ON THIS THREAD. The program's glue
  (uPeriodicBackupService) hops it to the main thread.

  ITS OWN CONNECTIONS, PER RUN. TLogFileBackup opens the log READ-ONLY for
  the snapshot and closes it when the run ends, so the worker holds no SQLite
  object between runs and never a long-lived read transaction (which would
  stop WAL checkpoints from resetting). Under WAL the main connection's
  commits are not blocked by it. The program only hands work here when the
  log IS in WAL (uLogStore.LogStoreJournalIsWal); otherwise it backs up
  synchronously as before.

  NOT WATCHED. uLogConnectionWatch rolls back or interrupts a SECOND
  connection that holds a transaction past 3 s. A VACUUM INTO of a large log
  can take longer and is harmless to the writer, so these connections take no
  Watch. Its one cost: the WAL cannot reset while the snapshot reads, so it
  may grow for that long.

  COALESCING, NOT A QUEUE. TBackupCoalescer is the whole rule and is pure: a
  request while idle starts a run; a request while a run is in progress is
  remembered ONCE (the "again" flag -- the newest request wins, so a second
  and a third make one more run, not two); a request while one is already
  waiting replaces it. A periodic backup is a snapshot of the log as it is
  NOW, so an older request is worth nothing once a newer one exists.

  SHUTDOWN (Stop / Destroy) WAITS FOR THE RUN IN PROGRESS. It is local disk,
  and the alternative is to abandon a thread that holds a SQLite connection.
  A request still WAITING is dropped: the next session's first QSO backs up
  anyway, because the published file's age is then over the limit
  (uLogBackup.PeriodicBackupDue). Nothing is lost or half-published either
  way: the publish is a rename of a VERIFIED file, and a .new left by a
  killed process is deleted by the next run's step 3 (TLogBackup.Run). There
  is deliberately NO blanket sweep at startup: Run KEEPS a verified .new,
  and names it, when the .bak displacement or the publish rename fails -- it
  is then the newest good copy there is.

  A leaf: RTL, SyncObjs and uLogBackup only -- no Forms, no logger. *)

{$I ..\tr4w.inc}

interface

uses
   Classes, SyncObjs;

type
   (* ONE BACKUP TO TAKE: which log, to which file, in which folder. Tag is
     the caller's, carried through untouched (logstuff puts the QSO count at
     the time of the request there). *)
   TLogBackupJob = class(TObject)
   public
      LogFile: string;
      BackupDir: string;
      Destination: string;
      Tag: integer;
      constructor Create(const aLogFile, aBackupDir, aDestination: string;
                         aTag: integer);
   end;

   (* WHAT A RUN CAME TO. Owned by whoever OnDone hands it to. *)
   TLogBackupResult = class(TObject)
   public
      LogFile: string;
      Destination: string;
      Tag: integer;
      Succeeded: boolean;
      Report: string;
      (* OnPublished's answer: True when the copy to BACKUP DESTINATION was
        queued, CopyDestination the folder; False with CopyWhy set when the
        queueing failed; False with CopyWhy empty when there is no
        destination. Untouched when the backup failed. *)
      CopyQueued: boolean;
      CopyDestination: string;
      CopyWhy: string;
   end;

   (* ON THE WORKER THREAD. The callee owns aResult and must free it. *)
   TLogBackupDone = procedure(aResult: TLogBackupResult) of object;

   (* ON THE WORKER THREAD, after a successful publish: queue aPath for the
     backup destination. The shape of uBackupCopyService.BackupCopySubmit. *)
   TLogBackupPublished = function(const aPath: string;
                                  out aDestination, aWhy: string): boolean;

   (* THE COALESCING RULE, pure -- no thread, no lock; the worker holds its
     lock around every call. *)
   TBackupCoalescer = class(TObject)
   private
      FPending: TLogBackupJob;
      FRunning: boolean;
   public
      destructor Destroy; override;
      (* Takes ownership of aJob. Replaces (and frees) a job already
        waiting. *)
      procedure Request(aJob: TLogBackupJob);
      (* The job to run next, or nil when none waits. Non-nil marks the
        coalescer running; the caller owns the job. *)
      function TakeNext: TLogBackupJob;
      (* The run that TakeNext started has ended. *)
      procedure Finished;
      (* Drop the waiting job, if any. *)
      procedure Discard;
      (* A run in progress, or a job waiting. *)
      function Busy: boolean;
      property Running: boolean read FRunning;
      (* While Running: the "again" flag. *)
      function HasPending: boolean;
   end;

   TLogBackupWorker = class;

   TLogBackupWorkerThread = class(TThread)
   private
      FOwner: TLogBackupWorker;
   protected
      procedure Execute; override;
   public
      constructor Create(aOwner: TLogBackupWorker);
   end;

   TLogBackupWorker = class(TObject)
   private
      FLock: TCriticalSection;
      FWake: TEvent;
      (* Manual reset: set while nothing runs and nothing waits. *)
      FIdle: TEvent;
      FCoalescer: TBackupCoalescer;
      FThread: TLogBackupWorkerThread;
      FOnDone: TLogBackupDone;
      FOnPublished: TLogBackupPublished;
      FStopping: boolean;
      procedure RunOne(aJob: TLogBackupJob);
      procedure Loop;
      function Stopping: boolean;
   public
      (* Starts the thread. aOnPublished may be nil (no copy step). *)
      constructor Create(aOnDone: TLogBackupDone; aOnPublished: TLogBackupPublished);
      (* Stop, then free. *)
      destructor Destroy; override;

      (* Takes ownership of aJob; returns at once. Ignored (and freed) once
        Stop has begun. *)
      procedure Request(aJob: TLogBackupJob);

      (* A run in progress or a request waiting. *)
      function Busy: boolean;

      (* Wait until nothing runs and nothing waits, at most aTimeoutMs. For
        tests and the bench; the program never waits on a backup. *)
      function WaitIdle(aTimeoutMs: Cardinal): boolean;

      (* Drop a waiting request, let the run in progress FINISH (verified and
        published, or reported failed), and end the thread. Unbounded: see
        the unit header. Idempotent. *)
      procedure Stop;
   end;

implementation

uses
   SysUtils, uLogBackup;

(* ---------------------------------------------------------------------------
  TLogBackupJob
  --------------------------------------------------------------------------- *)

constructor TLogBackupJob.Create(const aLogFile, aBackupDir, aDestination: string;
   aTag: integer);
begin
   inherited Create;
   (* Copied, not shared: the job crosses to another thread, and a string
     shared with the caller's would be released by whichever thread lets go
     last. The reference count is interlocked, so sharing is safe too; a copy
     simply makes the job owe nothing to its caller. *)
   LogFile := Copy(aLogFile, 1, Length(aLogFile));
   BackupDir := Copy(aBackupDir, 1, Length(aBackupDir));
   Destination := Copy(aDestination, 1, Length(aDestination));
   Tag := aTag;
end;

(* ---------------------------------------------------------------------------
  TBackupCoalescer
  --------------------------------------------------------------------------- *)

destructor TBackupCoalescer.Destroy;
begin
   FreeAndNil(FPending);
   inherited Destroy;
end;

procedure TBackupCoalescer.Request(aJob: TLogBackupJob);
begin
   if aJob = nil then
      begin
      Exit;
      end;
   (* The newest request wins: a snapshot is of the log as it is now. *)
   FreeAndNil(FPending);
   FPending := aJob;
end;

function TBackupCoalescer.TakeNext: TLogBackupJob;
begin
   Result := FPending;
   FPending := nil;
   FRunning := Result <> nil;
end;

procedure TBackupCoalescer.Finished;
begin
   FRunning := False;
end;

procedure TBackupCoalescer.Discard;
begin
   FreeAndNil(FPending);
end;

function TBackupCoalescer.Busy: boolean;
begin
   Result := FRunning or (FPending <> nil);
end;

function TBackupCoalescer.HasPending: boolean;
begin
   Result := FPending <> nil;
end;

(* ---------------------------------------------------------------------------
  TLogBackupWorkerThread
  --------------------------------------------------------------------------- *)

constructor TLogBackupWorkerThread.Create(aOwner: TLogBackupWorker);
begin
   FOwner := aOwner;
   FreeOnTerminate := False;
   inherited Create(False);
end;

procedure TLogBackupWorkerThread.Execute;
begin
   FOwner.Loop;
end;

(* ---------------------------------------------------------------------------
  TLogBackupWorker
  --------------------------------------------------------------------------- *)

constructor TLogBackupWorker.Create(aOnDone: TLogBackupDone;
   aOnPublished: TLogBackupPublished);
begin
   inherited Create;
   FOnDone := aOnDone;
   FOnPublished := aOnPublished;
   FLock := TCriticalSection.Create;
   FWake := TEvent.Create(nil, False, False, '');
   FIdle := TEvent.Create(nil, True, True, '');
   FCoalescer := TBackupCoalescer.Create;
   FThread := TLogBackupWorkerThread.Create(Self);
end;

destructor TLogBackupWorker.Destroy;
begin
   Stop;
   FreeAndNil(FThread);
   FreeAndNil(FCoalescer);
   FreeAndNil(FIdle);
   FreeAndNil(FWake);
   FreeAndNil(FLock);
   inherited Destroy;
end;

procedure TLogBackupWorker.Request(aJob: TLogBackupJob);
begin
   FLock.Acquire;
   try
      if FStopping then
         begin
         aJob.Free;
         Exit;
         end;
      FCoalescer.Request(aJob);
      FIdle.ResetEvent;
   finally
      FLock.Release;
   end;
   FWake.SetEvent;
end;

function TLogBackupWorker.Busy: boolean;
begin
   FLock.Acquire;
   try
      Result := FCoalescer.Busy;
   finally
      FLock.Release;
   end;
end;

function TLogBackupWorker.WaitIdle(aTimeoutMs: Cardinal): boolean;
begin
   Result := FIdle.WaitFor(aTimeoutMs) = wrSignaled;
end;

procedure TLogBackupWorker.Stop;
begin
   if FThread = nil then
      begin
      Exit;
      end;
   FLock.Acquire;
   try
      FStopping := True;
      FCoalescer.Discard;
   finally
      FLock.Release;
   end;
   FThread.Terminate;
   FWake.SetEvent;
   FThread.WaitFor;
end;

function TLogBackupWorker.Stopping: boolean;
begin
   FLock.Acquire;
   try
      Result := FStopping;
   finally
      FLock.Release;
   end;
end;

procedure TLogBackupWorker.Loop;
var
   job: TLogBackupJob;
begin
   (* FStopping, not TThread.Terminated: Terminated is protected, and the
     thread starts inside the constructor, before FThread is even assigned. *)
   while not Stopping do
      begin
      FWake.WaitFor(1000);
      repeat
         FLock.Acquire;
         try
            if FStopping then
               begin
               job := nil;
               end
            else
               begin
               job := FCoalescer.TakeNext;
               end;
            if job = nil then
               begin
               FIdle.SetEvent;
               end;
         finally
            FLock.Release;
         end;
         if job <> nil then
            begin
            try
               RunOne(job);
            finally
               job.Free;
            end;
            end;
      until job = nil;
      end;
end;

procedure TLogBackupWorker.RunOne(aJob: TLogBackupJob);
var
   outcome: TLogBackupResult;
   backup: TLogFileBackup;
   report: string;
begin
   outcome := TLogBackupResult.Create;
   try
      outcome.LogFile := aJob.LogFile;
      outcome.Destination := aJob.Destination;
      outcome.Tag := aJob.Tag;
      try
         if not DirectoryExists(aJob.BackupDir) then
            begin
            (* The synchronous path's sentence, asked first for the same
              reason: a VACUUM INTO a missing folder says only "unable to
              open". *)
            outcome.Report := BackupFolderMissingReport(aJob.BackupDir);
            end
         else
            begin
            backup := TLogFileBackup.Create(aJob.LogFile);
            try
               outcome.Succeeded := backup.Run(aJob.Destination, report);
               outcome.Report := report;
            finally
               backup.Free;
            end;
            end;

         if outcome.Succeeded and Assigned(FOnPublished) then
            begin
            outcome.CopyQueued := FOnPublished(aJob.Destination,
                                               outcome.CopyDestination,
                                               outcome.CopyWhy);
            end;
      except
         on E: Exception do
            begin
            (* Run never raises; the copy step or a constructor might. A
              published backup stays a success: only its copy failed. *)
            if outcome.Succeeded then
               begin
               outcome.CopyQueued := False;
               outcome.CopyWhy := E.Message;
               end
            else
               begin
               outcome.Report := Format('The backup to %s failed: %s',
                                        [aJob.Destination, E.Message]);
               end;
            end;
      end;
   finally
      (* FINISHED BEFORE THE REPORT, so a receiver that asks Busy while
        handling this result learns whether ANOTHER result will follow. *)
      FLock.Acquire;
      try
         FCoalescer.Finished;
      finally
         FLock.Release;
      end;
   end;

   if Assigned(FOnDone) then
      begin
      try
         FOnDone(outcome);
      except
         (* A receiver that raises must not end the worker; it owned the
           result, so whatever it did not free is lost, not freed twice. *)
      end;
      end
   else
      begin
      outcome.Free;
      end;
end;

end.
