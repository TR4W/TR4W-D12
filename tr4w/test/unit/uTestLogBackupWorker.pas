unit uTestLogBackupWorker;

(* THE PERIODIC BACKUP OFF THE LOGGING THREAD (issue 350) --
  src/domain/uLogBackupWorker.pas.

  TWO HALVES.
     TBackupCoalescerTests  the pure rule: a request while idle runs; requests
                            while a run is under way make ONE more run, with
                            the newest request's values; a waiting request is
                            dropped by Discard.
     TLogBackupWorkerTests  the real thread over a REAL log in a scratch
                            folder: the published file verifies, the log's
                            own connection stays open and commits while the
                            worker reads, a missing folder is reported, the
                            copy step runs only after a publish, and Stop
                            leaves no staged file behind.

  WHY THE STORE'S GLUE IS NOT DRIVEN HERE. uPeriodicBackupService hops each
  result to the main thread with Application.QueueAsyncCall, which this
  program does not pump. The worker's OWN callback (the one the glue
  installs) is what these tests catch, with an event to wait on. Never
  BackupDir: a scratch folder under the system temp directory only. *)

{$I ..\..\src\tr4w.inc}

interface

uses
   uTR4WTestFramework;

type
   TBackupCoalescerTests = class(TTestCase)
   protected
      procedure TestAnIdleRequestRunsOnce;
      procedure TestRequestsDuringARunMakeOneMoreRunWithTheNewest;
      procedure TestTwoWaitingRequestsAreOne;
      procedure TestDiscardDropsTheWaitingRequest;
   public
      procedure RunAllTests; override;
   end;

   TLogBackupWorkerTests = class(TTestCase)
   private
      FDir: string;
      function TempName(const aLeaf: string): string;
      procedure Scrub(const aPath: string);
   protected
      procedure TestTheWorkerPublishesAVerifiedBackupOfAnOpenLog;
      procedure TestAMissingFolderIsReportedAndNothingIsWritten;
      procedure TestTheCopyStepRunsOnlyAfterAPublish;
      procedure TestStopLeavesNoStagedFile;
   public
      procedure RunAllTests; override;
   end;

implementation

uses
   SysUtils, Classes, SyncObjs, sqldb, VC, uLogDatabase, uLogRepository,
   uLogBackup, uLogBackupWorker;

(* ---------------------------------------------------------------------------
  TBackupCoalescerTests
  --------------------------------------------------------------------------- *)

function Job(aTag: integer): TLogBackupJob;
begin
   Result := TLogBackupJob.Create('log.db', 'dir', 'dest.db', aTag);
end;

procedure TBackupCoalescerTests.TestAnIdleRequestRunsOnce;
var
   c: TBackupCoalescer;
   j: TLogBackupJob;
begin
   BeginTest('a request while idle runs once, and then the coalescer is idle');
   c := TBackupCoalescer.Create;
   try
      CheckFalse(c.Busy, 'a new coalescer is idle');
      CheckTrue(c.TakeNext = nil, 'and has nothing to run');
      CheckFalse(c.Running, 'taking nothing does not start a run');

      c.Request(Job(7));
      CheckTrue(c.Busy, 'a request makes it busy');
      j := c.TakeNext;
      try
         CheckTrue(j <> nil, 'the request is taken');
         CheckEquals(7, j.Tag, 'with its values');
         CheckTrue(c.Running, 'and a run is under way');
         CheckFalse(c.HasPending, 'nothing waits behind it');
      finally
         j.Free;
      end;
      c.Finished;
      CheckFalse(c.Busy, 'finished: idle again');
      CheckTrue(c.TakeNext = nil, 'and nothing more runs');
   finally
      c.Free;
   end;
end;

procedure TBackupCoalescerTests.TestRequestsDuringARunMakeOneMoreRunWithTheNewest;
var
   c: TBackupCoalescer;
   j: TLogBackupJob;
begin
   BeginTest('requests during a run make ONE more run, with the newest values');
   c := TBackupCoalescer.Create;
   try
      c.Request(Job(1));
      j := c.TakeNext;
      j.Free;
      CheckTrue(c.Running, 'the first run is under way');

      c.Request(Job(2));
      c.Request(Job(3));
      CheckTrue(c.HasPending, 'the "again" flag is set');

      c.Finished;
      CheckTrue(c.Busy, 'finished, but a request waits');
      j := c.TakeNext;
      try
         CheckTrue(j <> nil, 'so one more run starts');
         CheckEquals(3, j.Tag, 'with the newest request''s values');
      finally
         j.Free;
      end;
      c.Finished;
      CheckTrue(c.TakeNext = nil, 'and only one: the second request was not queued');
      CheckFalse(c.Busy, 'idle');
   finally
      c.Free;
   end;
end;

procedure TBackupCoalescerTests.TestTwoWaitingRequestsAreOne;
var
   c: TBackupCoalescer;
   j: TLogBackupJob;
begin
   BeginTest('two requests before any run are one run');
   c := TBackupCoalescer.Create;
   try
      c.Request(Job(10));
      c.Request(Job(11));
      j := c.TakeNext;
      try
         CheckEquals(11, j.Tag, 'the newer one');
      finally
         j.Free;
      end;
      c.Finished;
      CheckTrue(c.TakeNext = nil, 'and nothing after it');
   finally
      c.Free;
   end;
end;

procedure TBackupCoalescerTests.TestDiscardDropsTheWaitingRequest;
var
   c: TBackupCoalescer;
begin
   BeginTest('Discard drops a waiting request (what Stop does)');
   c := TBackupCoalescer.Create;
   try
      c.Request(Job(5));
      c.Discard;
      CheckFalse(c.Busy, 'nothing waits');
      CheckTrue(c.TakeNext = nil, 'and nothing runs');
      (* Freed with a request waiting: the destructor frees it (heaptrc). *)
      c.Request(Job(6));
   finally
      c.Free;
   end;
end;

procedure TBackupCoalescerTests.RunAllTests;
begin
   TestAnIdleRequestRunsOnce;
   TestRequestsDuringARunMakeOneMoreRunWithTheNewest;
   TestTwoWaitingRequestsAreOne;
   TestDiscardDropsTheWaitingRequest;
end;

(* ---------------------------------------------------------------------------
  TLogBackupWorkerTests
  --------------------------------------------------------------------------- *)

type
   (* Catches the worker's results on the worker thread. *)
   TResultCatcher = class(TObject)
   public
      Lock: TCriticalSection;
      Arrived: TEvent;
      Results: TList;
      constructor Create;
      destructor Destroy; override;
      procedure Received(aResult: TLogBackupResult);
      function Count: integer;
      function Last: TLogBackupResult;
   end;

var
   GPublishedPaths: TStringList = nil;

(* The copy step, as the program's BackupCopySubmit would be: it only
  records what it was handed. *)
function RecordPublished(const aPath: string; out aDestination, aWhy: string): boolean;
begin
   GPublishedPaths.Add(aPath);
   aDestination := 'X:\copies';
   aWhy := '';
   Result := True;
end;

constructor TResultCatcher.Create;
begin
   inherited Create;
   Lock := TCriticalSection.Create;
   Arrived := TEvent.Create(nil, True, False, '');
   Results := TList.Create;
end;

destructor TResultCatcher.Destroy;
var
   i: integer;
begin
   for i := 0 to Results.Count - 1 do
      begin
      TLogBackupResult(Results[i]).Free;
      end;
   Results.Free;
   Arrived.Free;
   Lock.Free;
   inherited Destroy;
end;

procedure TResultCatcher.Received(aResult: TLogBackupResult);
begin
   Lock.Acquire;
   try
      Results.Add(aResult);
   finally
      Lock.Release;
   end;
   Arrived.SetEvent;
end;

function TResultCatcher.Count: integer;
begin
   Lock.Acquire;
   try
      Result := Results.Count;
   finally
      Lock.Release;
   end;
end;

function TResultCatcher.Last: TLogBackupResult;
begin
   Lock.Acquire;
   try
      Result := nil;
      if Results.Count > 0 then
         begin
         Result := TLogBackupResult(Results[Results.Count - 1]);
         end;
   finally
      Lock.Release;
   end;
end;

function TLogBackupWorkerTests.TempName(const aLeaf: string): string;
begin
   if FDir = '' then
      begin
      FDir := IncludeTrailingPathDelimiter(GetTempDir) +
              'tr4w_backupworker_' + IntToStr(GetProcessID);
      ForceDirectories(FDir);
      end;
   Result := IncludeTrailingPathDelimiter(FDir) + aLeaf;
end;

procedure TLogBackupWorkerTests.Scrub(const aPath: string);
const
   SUFFIXES: array[0..5] of string = ('', '.new', '.bak', '-wal', '-shm', '-journal');
var
   i: integer;
begin
   for i := Low(SUFFIXES) to High(SUFFIXES) do
      begin
      if FileExists(aPath + SUFFIXES[i]) then
         begin
         DeleteFile(aPath + SUFFIXES[i]);
         end;
      end;
end;

(* aCount QSOs written to the log behind aRepo and committed; the database
  is left OPEN, as the store's would be. *)
procedure MakeLog(aRepo: TLogRepository; aCount: integer);
var
   rec: ContestExchange;
   i: integer;
begin
   rec := Default(ContestExchange);
   rec.Callsign := 'W1AW';
   rec.ceRecordKind := rkQSO;
   for i := 1 to aCount do
      begin
      aRepo.SaveQSO(rec);
      end;
   aRepo.Commit;
end;

function QsoCount(const aPath: string): integer;
var
   db: TLogDatabase;
   q: TSQLQuery;
begin
   Result := -1;
   db := TLogDatabase.Create;
   try
      db.OpenReadOnly(aPath);
      q := TSQLQuery.Create(nil);
      try
         q.Database := db.Connection;
         q.Transaction := db.Transaction;
         q.SQL.Text := 'SELECT COUNT(*) FROM qso';
         q.Open;
         Result := q.Fields[0].AsInteger;
         q.Close;
      finally
         q.Free;
      end;
   finally
      db.Free;
   end;
end;

procedure TLogBackupWorkerTests.TestTheWorkerPublishesAVerifiedBackupOfAnOpenLog;
var
   db: TLogDatabase;
   repo: TLogRepository;
   worker: TLogBackupWorker;
   catcher: TResultCatcher;
   src, dest, why: string;
   rec: ContestExchange;
   outcome: TLogBackupResult;
begin
   BeginTest('the worker publishes a verified backup while the log stays open and writing');
   src := TempName('open-src.db');
   dest := TempName('open-src periodic.db');
   Scrub(src);
   Scrub(dest);

   catcher := TResultCatcher.Create;
   db := TLogDatabase.Create;
   try
      db.CreateNew(src);
      repo := TLogRepository.Create(db);
      try
         MakeLog(repo, 50);

         worker := TLogBackupWorker.Create(catcher.Received, nil);
         try
            worker.Request(TLogBackupJob.Create(src, FDir, dest, 50));

            (* THE LOG'S OWN CONNECTION KEEPS WRITING while the worker reads
              -- under WAL nothing here waits on it. *)
            rec := Default(ContestExchange);
            rec.Callsign := 'K1ABC';
            rec.ceRecordKind := rkQSO;
            repo.SaveQSO(rec);
            repo.Commit;

            CheckTrue(worker.WaitIdle(30000), 'the run ends');
         finally
            worker.Free;
         end;
      finally
         repo.Free;
      end;

      CheckEquals(1, catcher.Count, 'one result');
      outcome := catcher.Last;
      CheckTrue(outcome <> nil, 'there is a result');
      if outcome <> nil then
         begin
         CheckTrue(outcome.Succeeded, 'it backed up: ' + outcome.Report);
         CheckEquals('Log backed up to ' + dest + '.', outcome.Report, 'the synchronous path''s sentence');
         CheckEquals(50, outcome.Tag, 'the tag comes back');
         CheckFalse(outcome.CopyQueued, 'no copy step was given');
         end;
   finally
      db.Free;
      catcher.Free;
   end;

   CheckFalse(FileExists(dest + '.new'), 'no staged file is left');
   CheckTrue(StagedBackupIsSound(dest, why), 'the published backup verifies: ' + why);
   (* 50 committed before the request; the 51st may or may not have made the
     snapshot -- both are a consistent log. *)
   CheckTrue(QsoCount(dest) >= 50, 'and holds every QSO committed before the request');

   Scrub(src);
   Scrub(dest);
end;

procedure TLogBackupWorkerTests.TestAMissingFolderIsReportedAndNothingIsWritten;
var
   db: TLogDatabase;
   worker: TLogBackupWorker;
   catcher: TResultCatcher;
   src, missing, dest: string;
begin
   BeginTest('a missing backup folder is reported with the synchronous sentence');
   src := TempName('nofolder-src.db');
   missing := TempName('no-such-folder');
   dest := IncludeTrailingPathDelimiter(missing) + 'x periodic.db';
   Scrub(src);

   catcher := TResultCatcher.Create;
   db := TLogDatabase.Create;
   try
      db.CreateNew(src);
      worker := TLogBackupWorker.Create(catcher.Received, RecordPublished);
      try
         GPublishedPaths.Clear;
         worker.Request(TLogBackupJob.Create(src, missing, dest, 0));
         CheckTrue(worker.WaitIdle(30000), 'the run ends');
      finally
         worker.Free;
      end;
      CheckEquals(1, catcher.Count, 'one result');
      if catcher.Last <> nil then
         begin
         CheckFalse(catcher.Last.Succeeded, 'it failed');
         CheckEquals(BackupFolderMissingReport(missing), catcher.Last.Report, 'and says why');
         end;
      CheckEquals(0, GPublishedPaths.Count, 'nothing was handed to the copy step');
      CheckFalse(DirectoryExists(missing), 'the folder was not created');
   finally
      db.Free;
      catcher.Free;
   end;
   Scrub(src);
end;

procedure TLogBackupWorkerTests.TestTheCopyStepRunsOnlyAfterAPublish;
var
   db: TLogDatabase;
   worker: TLogBackupWorker;
   catcher: TResultCatcher;
   src, dest: string;
begin
   BeginTest('the copy step is handed the PUBLISHED file, after the publish');
   src := TempName('copy-src.db');
   dest := TempName('copy-src periodic.db');
   Scrub(src);
   Scrub(dest);

   catcher := TResultCatcher.Create;
   db := TLogDatabase.Create;
   try
      db.CreateNew(src);
      worker := TLogBackupWorker.Create(catcher.Received, RecordPublished);
      try
         GPublishedPaths.Clear;
         worker.Request(TLogBackupJob.Create(src, FDir, dest, 0));
         CheckTrue(worker.WaitIdle(30000), 'the run ends');
      finally
         worker.Free;
      end;
      CheckEquals(1, GPublishedPaths.Count, 'one copy was asked for');
      if GPublishedPaths.Count = 1 then
         begin
         CheckEquals(dest, GPublishedPaths[0], 'of the published file');
         end;
      if catcher.Last <> nil then
         begin
         CheckTrue(catcher.Last.Succeeded, 'it backed up: ' + catcher.Last.Report);
         CheckTrue(catcher.Last.CopyQueued, 'and the result says it was queued');
         CheckEquals('X:\copies', catcher.Last.CopyDestination, 'for that folder');
         end;
   finally
      db.Free;
      catcher.Free;
   end;
   Scrub(src);
   Scrub(dest);
end;

procedure TLogBackupWorkerTests.TestStopLeavesNoStagedFile;
var
   db: TLogDatabase;
   repo: TLogRepository;
   worker: TLogBackupWorker;
   catcher: TResultCatcher;
   src, dest, why: string;
begin
   BeginTest('Stop waits for the run in progress and leaves no staged file');
   src := TempName('stop-src.db');
   dest := TempName('stop-src periodic.db');
   Scrub(src);
   Scrub(dest);

   catcher := TResultCatcher.Create;
   db := TLogDatabase.Create;
   try
      db.CreateNew(src);
      repo := TLogRepository.Create(db);
      try
         MakeLog(repo, 200);
      finally
         repo.Free;
      end;
      worker := TLogBackupWorker.Create(catcher.Received, nil);
      try
         worker.Request(TLogBackupJob.Create(src, FDir, dest, 1));
         worker.Request(TLogBackupJob.Create(src, FDir, dest, 2));
         (* Whether the first had started is the scheduler's business; what
           is pinned is the state Stop leaves. *)
         worker.Stop;
         CheckFalse(worker.Busy, 'nothing runs or waits after Stop');
         worker.Request(TLogBackupJob.Create(src, FDir, dest, 3));
         CheckFalse(worker.Busy, 'a request after Stop is refused');
      finally
         worker.Free;
      end;
      CheckTrue(catcher.Count <= 1, 'at most the run in progress reported');
   finally
      db.Free;
      catcher.Free;
   end;

   CheckFalse(FileExists(dest + '.new'), 'no staged file is left');
   if FileExists(dest) then
      begin
      CheckTrue(StagedBackupIsSound(dest, why), 'a published file is a verified one: ' + why);
      end;
   Scrub(src);
   Scrub(dest);
end;

procedure TLogBackupWorkerTests.RunAllTests;
begin
   GPublishedPaths := TStringList.Create;
   try
      TestTheWorkerPublishesAVerifiedBackupOfAnOpenLog;
      TestAMissingFolderIsReportedAndNothingIsWritten;
      TestTheCopyStepRunsOnlyAfterAPublish;
      TestStopLeavesNoStagedFile;
   finally
      FreeAndNil(GPublishedPaths);
   end;

   if (FDir <> '') and DirectoryExists(FDir) then
      begin
      RemoveDir(FDir);
      end;
end;

end.
