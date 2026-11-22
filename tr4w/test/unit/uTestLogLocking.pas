unit uTestLogLocking;

(* A LOCKED CONTEST LOG, AT THE DATABASE LEVEL (2026-10-31).

  tr4w.log, 2026-10-31: the program crashed at startup with an unhandled
  "database is locked" on the main thread, in the same millisecond the WRL
  worker -- its own connection -- committed; and at close the configuration
  capture failed the same way with the worker already stopped. Both are one
  mechanism, pinned here first: sqldb leaves a read transaction open after a
  read, and a write from that old snapshot fails AT ONCE with
  SQLITE_BUSY_SNAPSHOT once another connection has committed, whatever the
  busy timeout.

  WHAT IS PINNED:
    - the busy classifier answers from the CODE, for a sqldb statement, for a
      pragma (TLogConnection.ExecutePragma) and through the stale snapshot;
    - TLogDatabase.EndTransaction is the cure for the stale snapshot;
    - the lock probe sees a held write lock and a free one;
    - the WRL worker rolls its transaction back when a statement inside it
      fails, and the log is not left locked;
    - the watchdog asks, then interrupts, and an interrupted stalled
      transaction is freed -- no long sleep: the clock is the test's;
    - (2026-11-18, a full disk) a failed COMMIT carries SQLite's code, and
      SQLiteWriteFailure tells a write the disk refused from everything else.

  The store-level halves (a QSO and the session state after another
  connection commits, a held lock at open, the verification check) are in
  uTestLogStore, which has the store's fixture.

  EVERY FILE IS A TEMPORARY ONE. Nothing here touches tr4w/target. *)

{$I ..\..\src\tr4w.inc}

interface

uses
   uTR4WTestFramework;

type
   TLogLockingTests = class(TTestCase)
   private
      FFileName: string;
      procedure NewLog;
      procedure DropLog;
      (* A raw connection holding the write lock (BEGIN IMMEDIATE). *)
      function HoldWriteLock: TObject;
      procedure ReleaseWriteLock(var aHolder: TObject);
   protected
      procedure TestBusyIsRecognisedOnEveryPath;
      procedure TestAStaleSnapshotFailsAtOnceAndEndingItCures;
      procedure TestTheProbeSeesAHeldLock;
      procedure TestTheWorkerRollsBackWhenAStatementFails;
      procedure TestTheWatchdogFreesAStalledTransaction;
      (* A FULL DISK (2026-11-18): the COMMIT's failure carries its code, and
        the classifier that decides read-only versus stand down. *)
      procedure TestAFailedCommitCarriesItsCode;
      procedure TestTheWriteFailureClassifier;
      (* ISSUE 351 (a), 2026-11-21: what a connection READ BACK is judged by
        one pure rule, and a real open reads back what it asked for. *)
      procedure TestTheDurabilityRule;
      procedure TestAnOpenReadsBackFullAndWal;
   public
      procedure RunAllTests; override;
   end;

implementation

uses
   SysUtils, Classes, SyncObjs, sqldb, sqlite3conn, uLogDatabase,
   uLogConnectionWatch, uWRLWorker;

const
   (* A few ms: a held lock must cost the test almost nothing. *)
   TEST_BUSY_MS = 20;

type
   (* A SECONDARY CONNECTION THAT STALLS: it takes the write lock with an
     INSERT and then runs a statement that does not finish on its own (a
     recursive count bounded far beyond what the test waits for). Whatever
     ends it, it rolls back, as the worker's own handlers do, and records the
     SQLite code of what stopped it. *)
   TStallingThread = class(TThread)
   private
      FFileName: string;
      FWatch: TLogConnectionWatch;
      FCode: integer;
      FFailure: string;
   protected
      procedure Execute; override;
   public
      constructor Create(const aFileName: string; aWatch: TLogConnectionWatch);
      property Code: integer read FCode;
      property Failure: string read FFailure;
   end;

constructor TStallingThread.Create(const aFileName: string; aWatch: TLogConnectionWatch);
begin
   inherited Create(True);
   FFileName := aFileName;
   FWatch := aWatch;
   FCode := -1;
end;

procedure TStallingThread.Execute;
var
   db: TLogDatabase;
   q: TSQLQuery;
begin
   db := TLogDatabase.Create;
   try
      try
         db.BusyTimeoutMs := TEST_BUSY_MS;
         db.Connection.Watch := FWatch;
         db.Open(FFileName);
         db.Connection.ExecuteDirect(
            'INSERT INTO session_state(key, value) VALUES (''stall'', ''1'')');
         q := TSQLQuery.Create(nil);
         try
            q.DataBase := db.Connection;
            q.Transaction := db.Transaction;
            q.UsePrimaryKeyAsKey := False;
            q.SQL.Text := 'WITH RECURSIVE c(n) AS (SELECT 1 UNION ALL ' +
                          'SELECT n + 1 FROM c WHERE n < 100000000) ' +
                          'SELECT count(n) FROM c';
            q.Open;
            FCode := 0;
         finally
            q.Free;
         end;
      except
         on E: Exception do
            begin
            FCode := SQLiteErrorCode(E);
            FFailure := E.Message;
            db.Rollback;
            end;
      end;
   finally
      db.Free;
   end;
end;

procedure TLogLockingTests.NewLog;
var
   db: TLogDatabase;
begin
   FFileName := UniqueTempFileName('tr4wlock');
   DeleteFile(FFileName);
   db := TLogDatabase.Create;
   try
      db.CreateNew(FFileName);
   finally
      db.Free;
   end;
end;

procedure TLogLockingTests.DropLog;
begin
   DeleteFile(FFileName + '-wal');
   DeleteFile(FFileName + '-shm');
   DeleteFile(FFileName);
end;

function TLogLockingTests.HoldWriteLock: TObject;
var
   holder: TLogConnection;
begin
   holder := TLogConnection.Create(nil);
   holder.DatabaseName := AnsiString(FFileName);
   holder.OpenFlags := [sofReadWrite];
   holder.Open;
   holder.ExecutePragma('BEGIN IMMEDIATE');
   Result := holder;
end;

procedure TLogLockingTests.ReleaseWriteLock(var aHolder: TObject);
begin
   if aHolder <> nil then
      begin
      TLogConnection(aHolder).ExecutePragma('ROLLBACK');
      FreeAndNil(aHolder);
      end;
end;

procedure TLogLockingTests.TestBusyIsRecognisedOnEveryPath;
var
   db: TLogDatabase;
   holder: TObject;
   statementBusy, pragmaBusy, otherBusy: boolean;
begin
   BeginTest('a held write lock is recognised as busy from a statement and a pragma, by code');
   NewLog;
   holder := nil;
   db := TLogDatabase.Create;
   try
      db.BusyTimeoutMs := TEST_BUSY_MS;
      db.Open(FFileName);
      holder := HoldWriteLock;

      statementBusy := False;
      try
         db.Connection.ExecuteDirect(
            'INSERT INTO session_state(key, value) VALUES (''a'', ''1'')');
      except
         on E: Exception do
            begin
            statementBusy := SQLiteIsBusy(E);
            end;
      end;
      db.Rollback;
      CheckTrue(statementBusy, 'a sqldb write meeting the lock is busy');

      pragmaBusy := False;
      try
         db.Connection.ExecutePragma('BEGIN IMMEDIATE');
      except
         on E: Exception do
            begin
            pragmaBusy := SQLiteIsBusy(E);
            end;
      end;
      CheckTrue(pragmaBusy, 'a pragma meeting the lock is busy (ExecutePragma carries the code)');

      (* And a failure that is not a lock is not called one. *)
      otherBusy := True;
      try
         db.Connection.ExecutePragma('THIS IS NOT SQL');
      except
         on E: Exception do
            begin
            otherBusy := SQLiteIsBusy(E);
            end;
      end;
      CheckFalse(otherBusy, 'a syntax error is not busy');
   finally
      ReleaseWriteLock(holder);
      db.Free;
      DropLog;
   end;
end;

procedure TLogLockingTests.TestAStaleSnapshotFailsAtOnceAndEndingItCures;
var
   main, other: TLogDatabase;
   q: TSQLQuery;
   busyCode: integer;
   started: QWord;
   elapsed: QWord;
begin
   BeginTest('a write from a stale read snapshot fails at once; EndTransaction first cures it');
   NewLog;
   main := TLogDatabase.Create;
   other := TLogDatabase.Create;
   try
      (* A LONG wait on the main connection: the point is that it is not used. *)
      main.BusyTimeoutMs := 2000;
      main.Open(FFileName);
      other.BusyTimeoutMs := TEST_BUSY_MS;
      other.Open(FFileName);

      (* The main connection reads, and sqldb leaves the transaction open. *)
      q := TSQLQuery.Create(nil);
      try
         q.DataBase := main.Connection;
         q.Transaction := main.Transaction;
         q.UsePrimaryKeyAsKey := False;
         q.SQL.Text := 'SELECT count(key) FROM session_state';
         q.Open;
         q.Close;
      finally
         q.Free;
      end;
      CheckTrue(main.Transaction.Active, 'the read left a transaction open');

      (* The other connection commits, as the WRL worker does. *)
      other.Connection.ExecuteDirect(
         'INSERT INTO session_state(key, value) VALUES (''worker'', ''1'')');
      other.Transaction.Commit;

      busyCode := 0;
      started := GetTickCount64;
      try
         main.Connection.ExecuteDirect(
            'INSERT INTO session_state(key, value) VALUES (''main'', ''1'')');
      except
         on E: Exception do
            begin
            if SQLiteIsBusy(E) then
               begin
               busyCode := SQLiteErrorCode(E);
               end;
            end;
      end;
      elapsed := GetTickCount64 - started;
      main.Rollback;
      CheckEquals(517, busyCode, 'the write fails with SQLITE_BUSY_SNAPSHOT');
      CheckTrue(elapsed < 1000, 'at once -- the 2 s busy wait does not help (' +
                IntToStr(elapsed) + ' ms)');

      (* THE CURE: read again, the other commits again, then end the read
        transaction before writing. *)
      q := TSQLQuery.Create(nil);
      try
         q.DataBase := main.Connection;
         q.Transaction := main.Transaction;
         q.UsePrimaryKeyAsKey := False;
         q.SQL.Text := 'SELECT count(key) FROM session_state';
         q.Open;
         q.Close;
      finally
         q.Free;
      end;
      other.Connection.ExecuteDirect(
         'INSERT INTO session_state(key, value) VALUES (''worker2'', ''1'')');
      other.Transaction.Commit;
      main.EndTransaction;
      busyCode := 0;
      try
         main.Connection.ExecuteDirect(
            'INSERT INTO session_state(key, value) VALUES (''main'', ''1'')');
         main.Transaction.Commit;
      except
         on E: Exception do
            begin
            busyCode := SQLiteErrorCode(E);
            main.Rollback;
            end;
      end;
      CheckEquals(0, busyCode, 'after EndTransaction the write succeeds');
   finally
      other.Free;
      main.Free;
      DropLog;
   end;
end;

procedure TLogLockingTests.TestTheProbeSeesAHeldLock;
var
   holder: TObject;
   detail: string;
begin
   BeginTest('the lock probe reports a held write lock, and a free one');
   NewLog;
   holder := nil;
   try
      CheckTrue(ProbeLogWriteLock(FFileName, TEST_BUSY_MS, detail) = llpFree,
                'nothing holds it: free (' + detail + ')');
      holder := HoldWriteLock;
      CheckTrue(ProbeLogWriteLock(FFileName, TEST_BUSY_MS, detail) = llpHeld,
                'another connection holds it: held');
      ReleaseWriteLock(holder);
      CheckTrue(ProbeLogWriteLock(FFileName, TEST_BUSY_MS, detail) = llpFree,
                'released: free again (' + detail + ')');
      CheckTrue(ProbeLogWriteLock(FFileName + '.absent', TEST_BUSY_MS, detail) = llpUnknown,
                'a missing file is not probed, and not created');
      CheckFalse(FileExists(FFileName + '.absent'), 'no file was made');
   finally
      ReleaseWriteLock(holder);
      DropLog;
   end;
end;

procedure TLogLockingTests.TestTheWorkerRollsBackWhenAStatementFails;
var
   db: TLogDatabase;
   worker: TWRLWorker;
   deadline: QWord;
   detail, state: string;
   q: TSQLQuery;
begin
   BeginTest('a WRL worker statement that fails inside a transaction is rolled back; the log is not left locked');
   NewLog;
   worker := nil;
   db := TLogDatabase.Create;
   try
      db.BusyTimeoutMs := TEST_BUSY_MS;
      db.Open(FFileName);
      (* A pending delivery, and a trigger that makes the worker's claim --
        the UPDATE to inflight, inside its transaction -- fail. *)
      db.Connection.ExecuteDirect(
         'INSERT INTO external_delivery (logger, account, logbook, contact, revision, ' +
         'payload, deleted, state) VALUES (''WRL'', ''account'', ''book'', ''c1'', 1, ' +
         '''{}'', 0, ''pending'')');
      db.Connection.ExecuteDirect(
         'CREATE TRIGGER fail_claim BEFORE UPDATE ON external_delivery ' +
         'WHEN NEW.state = ''inflight'' BEGIN SELECT RAISE(ABORT, ''injected''); END');
      db.Transaction.Commit;

      worker := TWRLWorker.Create(FFileName, 'account', 'test-secret');
      worker.Start;
      deadline := GetTickCount64 + 10000;
      while (not worker.Finished) and (GetTickCount64 < deadline) do
         begin
         Sleep(5);
         end;
      CheckTrue(worker.Finished, 'the worker stopped on the injected failure');
      FreeAndNil(worker);

      CheckTrue(ProbeLogWriteLock(FFileName, TEST_BUSY_MS, detail) = llpFree,
                'the log is not left locked (' + detail + ')');
      q := TSQLQuery.Create(nil);
      try
         q.DataBase := db.Connection;
         q.Transaction := db.Transaction;
         q.UsePrimaryKeyAsKey := False;
         q.SQL.Text := 'SELECT state FROM external_delivery WHERE contact = ''c1''';
         q.Open;
         state := q.Fields[0].AsString;
         q.Close;
      finally
         q.Free;
      end;
      db.EndTransaction;
      CheckEquals('pending', state, 'the failed claim was rolled back: still pending');
   finally
      worker.Free;
      db.Free;
      DropLog;
   end;
end;

procedure TLogLockingTests.TestTheWatchdogFreesAStalledTransaction;
var
   watch: TLogConnectionWatch;
   stall: TStallingThread;
   deadline, lastPoke: QWord;
   began, before: Int64;
   events: TLogWatchEvents;
   detail: string;
begin
   BeginTest('the watchdog asks, then interrupts, and a stalled transaction is freed');
   NewLog;
   watch := TLogConnectionWatch.Create('test stalling connection');
   RegisterLogConnectionWatch(watch);
   stall := nil;
   try
      before := LogWatchInterventionCount;
      stall := TStallingThread.Create(FFileName, watch);
      stall.Start;

      (* Wait for the stalled transaction to exist. The INSERT holds the write
        lock, so once the probe says held, the long statement is under way. *)
      deadline := GetTickCount64 + 5000;
      repeat
         Sleep(5);
      until (ProbeLogWriteLock(FFileName, 1, detail) = llpHeld) or
            (GetTickCount64 > deadline) or stall.Finished;
      began := watch.BeganAt;
      CheckTrue(began <> 0, 'the watch saw the transaction begin');

      (* THE CLOCK IS THE TEST'S: below the threshold, nothing happens. *)
      events := RunLogWatchdog(began + LOG_WATCH_THRESHOLD_MS - 1);
      CheckEquals(0, Length(events), 'under the threshold: no intervention');

      events := RunLogWatchdog(began + LOG_WATCH_THRESHOLD_MS);
      CheckEquals(1, Length(events), 'at the threshold: one intervention');
      CheckTrue(watch.Stage = lwsAskedToRollBack, 'step 1: asked to roll back');

      events := RunLogWatchdog(began + LOG_WATCH_THRESHOLD_MS + LOG_WATCH_GRACE_MS);
      CheckEquals(1, Length(events), 'after the grace: one more');
      CheckTrue(watch.Stage = lwsInterrupted, 'step 2: interrupted');

      (* sqlite3_interrupt reaches only a RUNNING statement, so it is repeated
        until the thread is out -- a bounded wait, not a sleep. *)
      deadline := GetTickCount64 + 10000;
      lastPoke := GetTickCount64;
      while (not stall.Finished) and (GetTickCount64 < deadline) do
         begin
         if GetTickCount64 - lastPoke >= 20 then
            begin
            watch.Interrupt;
            lastPoke := GetTickCount64;
            end;
         Sleep(2);
         end;
      CheckTrue(stall.Finished, 'the stalled statement ended');
      CheckEquals(9, stall.Code and $FF, 'it ended by SQLITE_INTERRUPT: ' + stall.Failure);
      CheckEquals(0, integer(watch.OpenForMs(GetTickCount64)),
                  'and its transaction is closed');
      CheckTrue(ProbeLogWriteLock(FFileName, TEST_BUSY_MS, detail) = llpFree,
                'the log is free again (' + detail + ')');
      CheckEquals(2, integer(LogWatchInterventionCount - before),
                  'two interventions counted');
      CheckEquals('', LogWatchLongTransactions(GetTickCount64, 0),
                  'no long transaction is reported now');
   finally
      if stall <> nil then
         begin
         stall.WaitFor;
         stall.Free;
         end;
      watch.Free;
      DropLog;
   end;
end;

(* A FAILED COMMIT CARRIES SQLite's CODE (2026-11-18). COMMIT goes through
  sqlite3conn's execsql, which raised a plain EDatabaseError with no code --
  measured on NY4I's full D: drive, "EDatabaseError -- database or disk is
  full" -- so nothing could tell a full disk at COMMIT from corruption.
  TLogConnection.Commit re-raises it with the code. The failure used here is a
  deferred foreign key, which SQLite checks only AT the commit: on the old
  code this test reads code 0 and class EDatabaseError. *)
procedure TLogLockingTests.TestAFailedCommitCarriesItsCode;
const
   SQLITE_CONSTRAINT_CODE = 19;
var
   db: TLogDatabase;
   code: integer;
   failureClass: string;
   kind: TLogWriteFailure;
begin
   BeginTest('a COMMIT that fails raises ESQLDatabaseError carrying SQLite''s code');
   NewLog;
   db := TLogDatabase.Create;
   try
      db.Open(FFileName);
      db.Connection.ExecuteDirect('CREATE TABLE commit_trap_parent (id INTEGER PRIMARY KEY)');
      db.Connection.ExecuteDirect(
         'CREATE TABLE commit_trap (parent_id INTEGER REFERENCES ' +
         'commit_trap_parent(id) DEFERRABLE INITIALLY DEFERRED)');
      db.Transaction.Commit;

      db.Connection.ExecuteDirect('INSERT INTO commit_trap (parent_id) VALUES (-1)');
      code := -1;
      failureClass := '';
      kind := lwfDiskFull;
      try
         db.Transaction.Commit;
      except
         on E: Exception do
            begin
            code := SQLiteErrorCode(E);
            failureClass := E.ClassName;
            kind := SQLiteWriteFailure(E);
            end;
      end;
      db.Rollback;

      CheckEquals('ESQLDatabaseError', failureClass, 'the COMMIT failed, as ESQLDatabaseError');
      CheckEquals(SQLITE_CONSTRAINT_CODE, code and $FF,
                  'carrying SQLite''s code: SQLITE_CONSTRAINT (' + IntToStr(code) + ')');
      CheckTrue(kind = lwfNone, 'and a constraint is not a write the disk refused');
   finally
      db.Free;
      DropLog;
   end;
end;

(* Which failures leave the log READABLE (read-only) and which stand the
  store down -- asked of the code alone. *)
function WriteFailureOfCode(aCode: integer): TLogWriteFailure;
var
   e: ESQLDatabaseError;
begin
   e := ESQLDatabaseError.CreateFmt('%s', ['test'], nil, aCode, '');
   try
      Result := SQLiteWriteFailure(e);
   finally
      e.Free;
   end;
end;

procedure TLogLockingTests.TestTheWriteFailureClassifier;
const
   SQLITE_IOERR_WRITE_CODE     = 778;    (* IOERR | 3 shl 8 *)
   SQLITE_IOERR_FSYNC_CODE     = 1034;   (* IOERR | 4 shl 8 *)
   SQLITE_IOERR_READ_CODE      = 266;    (* IOERR | 1 shl 8 *)
   SQLITE_IOERR_SHORTREAD_CODE = 522;    (* IOERR | 2 shl 8 *)
   SQLITE_IOERR_CORRUPTFS_CODE = 8458;   (* IOERR | 33 shl 8 *)
   SQLITE_BUSY_SNAPSHOT_CODE   = 517;
   SQLITE_FK_CODE              = 787;    (* CONSTRAINT_FOREIGNKEY *)
var
   wrapped: ELogDatabaseError;
   plain: Exception;
begin
   BeginTest('a full disk and a write error leave the log readable; corruption and the rest do not');

   CheckTrue(WriteFailureOfCode(13) = lwfDiskFull, 'SQLITE_FULL is a full disk');
   CheckTrue(WriteFailureOfCode(10) = lwfWriteError, 'SQLITE_IOERR is a write error');
   CheckTrue(WriteFailureOfCode(SQLITE_IOERR_WRITE_CODE) = lwfWriteError, 'IOERR_WRITE too');
   CheckTrue(WriteFailureOfCode(SQLITE_IOERR_FSYNC_CODE) = lwfWriteError, 'IOERR_FSYNC too');
   CheckTrue(WriteFailureOfCode(8) = lwfWriteError, 'SQLITE_READONLY too');

   CheckTrue(WriteFailureOfCode(11) = lwfNone, 'SQLITE_CORRUPT is NOT: the log is damaged');
   CheckTrue(WriteFailureOfCode(26) = lwfNone, 'SQLITE_NOTADB is NOT');
   CheckTrue(WriteFailureOfCode(SQLITE_IOERR_READ_CODE) = lwfNone, 'a READ error is NOT');
   CheckTrue(WriteFailureOfCode(SQLITE_IOERR_SHORTREAD_CODE) = lwfNone, 'a short read is NOT');
   CheckTrue(WriteFailureOfCode(SQLITE_IOERR_CORRUPTFS_CODE) = lwfNone,
             'a damaged file system is NOT');
   CheckTrue(WriteFailureOfCode(5) = lwfNone, 'a busy log is NOT (it has its own branch)');
   CheckTrue(WriteFailureOfCode(SQLITE_BUSY_SNAPSHOT_CODE) = lwfNone, 'nor a stale snapshot');
   CheckTrue(WriteFailureOfCode(SQLITE_FK_CODE) = lwfNone, 'a constraint is NOT');
   CheckTrue(WriteFailureOfCode(0) = lwfNone, 'no code at all is NOT');

   wrapped := ELogDatabaseError.Create('test');
   plain := Exception.Create('database or disk is full');
   try
      wrapped.SQLiteCode := 13;
      CheckTrue(SQLiteWriteFailure(wrapped) = lwfDiskFull, 'the code is read through a re-wrap');
      CheckTrue(SQLiteWriteFailure(plain) = lwfNone, 'and never from the message text');
   finally
      wrapped.Free;
      plain.Free;
   end;
end;

procedure TLogLockingTests.TestTheDurabilityRule;
var
   w: TLogDurabilityWarnings;
begin
   BeginTest('synchronous below FULL, a journal that is not WAL and an old or unreadable SQLite are each warned about');

   CheckEquals(3053000, SQLiteVersionNumber('3.53.0'), 'a version reads as SQLITE_VERSION_NUMBER does');
   CheckEquals(3027000, SQLiteVersionNumber('3.27.0'), 'the minimum');
   CheckEquals(0, SQLiteVersionNumber(''), 'empty is not a version');
   CheckEquals(0, SQLiteVersionNumber('3.53'), 'two parts are not a version');
   CheckEquals(0, SQLiteVersionNumber('3.53.0.1'), 'four parts are not a version');
   CheckEquals(0, SQLiteVersionNumber('3.x.0'), 'a letter is not a version');
   CheckEquals(0, SQLiteVersionNumber('3.1000.0'), 'a part above 999 is refused');

   w := LogDurabilityWarnings('wal', LOG_SYNCHRONOUS_FULL, '3.45.1', False);
   CheckEquals(0, Length(w), 'FULL, WAL and 3.45.1: nothing to say');

   w := LogDurabilityWarnings('WAL', 3, '3.27.0', False);
   CheckEquals(0, Length(w), 'EXTRA is not weaker than FULL; the case of WAL does not matter');

   w := LogDurabilityWarnings('wal', 1, '3.45.1', False);
   CheckEquals(1, Length(w), 'NORMAL on a write connection is warned about');
   CheckTrue(Pos('synchronous', w[0]) > 0, 'and the warning names synchronous');

   w := LogDurabilityWarnings('wal', -1, '3.45.1', True);
   CheckEquals(0, Length(w), 'a read-only connection never sets synchronous, so it is not judged');

   w := LogDurabilityWarnings('delete', LOG_SYNCHRONOUS_FULL, '3.45.1', False);
   CheckEquals(1, Length(w), 'the rollback journal is said');
   CheckTrue(Pos('journal_mode', w[0]) > 0, 'and named');

   w := LogDurabilityWarnings('wal', LOG_SYNCHRONOUS_FULL, '3.26.0', False);
   CheckEquals(1, Length(w), 'an SQLite without VACUUM INTO is warned about');

   w := LogDurabilityWarnings('wal', LOG_SYNCHRONOUS_FULL, '', False);
   CheckEquals(1, Length(w), 'an unreadable version is warned about');

   w := LogDurabilityWarnings('delete', 0, 'nonsense', False);
   CheckEquals(3, Length(w), 'three shortfalls, three sentences');
end;

procedure TLogLockingTests.TestAnOpenReadsBackFullAndWal;
var
   db: TLogDatabase;
begin
   BeginTest('an open reads back synchronous FULL, WAL and the loaded SQLite version');
   NewLog;
   db := TLogDatabase.Create;
   try
      db.Open(FFileName);
      CheckEquals(LOG_SYNCHRONOUS_FULL, db.Synchronous, 'synchronous is read back as FULL');
      CheckTrue(SameText(db.JournalMode, 'wal'), 'journal_mode is WAL on a local file');
      CheckTrue(SQLiteVersionNumber(db.SQLiteVersion) >= LOG_MIN_SQLITE_VERSION,
                'the loaded SQLite (' + db.SQLiteVersion + ') reads and is new enough');
      CheckEquals(0, Length(LogDurabilityWarnings(db.JournalMode, db.Synchronous,
                                                  db.SQLiteVersion, db.IsReadOnly)),
                  'so the store has nothing to warn about');
      db.Close;
      db.OpenReadOnly(FFileName);
      CheckEquals(-1, db.Synchronous, 'a read-only connection does not read synchronous');
      CheckTrue(db.SQLiteVersion <> '', 'but it does read the version');
   finally
      db.Free;
      DropLog;
   end;
end;

procedure TLogLockingTests.RunAllTests;
begin
   TestBusyIsRecognisedOnEveryPath;
   TestAStaleSnapshotFailsAtOnceAndEndingItCures;
   TestTheProbeSeesAHeldLock;
   TestTheWorkerRollsBackWhenAStatementFails;
   TestTheWatchdogFreesAStalledTransaction;
   TestAFailedCommitCarriesItsCode;
   TestTheWriteFailureClassifier;
   TestTheDurabilityRule;
   TestAnOpenReadsBackFullAndWal;
end;

end.
