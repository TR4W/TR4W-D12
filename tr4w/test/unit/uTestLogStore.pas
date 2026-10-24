unit uTestLogStore;

(* THE STORE ITSELF -- uLogStore, driven through its public entry points.

  The first suite to call uLogStore rather than model it. The suites beside
  it (LogRepository, LogImport, LogContestStatements) were written while
  uLogStore could not be linked here; the test program links MainUnit now,
  and uLogStore with it.

  WHAT IS PINNED: A WRITE NEVER ASSUMES THE .TRW ALREADY HOLDS IT.

  Until 2026-10-17 LogStoreAppendQSO had a branch for "the log was just
  migrated from the binary log on this very call". The premise was B2's:
  tAddQSOToLog wrote the .TRW FIRST and then called the store, so a migration
  triggered by the append had already imported the QSO being appended, and
  the branch UPDATED the newest imported row instead of inserting.
  LogStoreUpdateNewestQSO had the twin: it returned without writing, because
  the rewrite was "already in the binary log".

  Since B5 the .TRW is import-only and holds nothing this session logged, so
  both branches were wrong: the append OVERWROTE the last imported QSO and
  acknowledged the new one without storing it, and the rewrite was dropped.
  The program never reached either -- startup opens the log through
  LogStoreApplyContestConfig before any write -- but the store's contract
  cannot depend on its caller having opened it first. These tests make the
  write the first thing that touches the log, which is the case the branches
  were for.

  AND CLEAR LOG'S BACKUP (2026-10-23): its name rule, and that the backup is
  taken from the SQLite log alone -- it holds every row, an empty log
  included, with no .TRW beside it. *)

{$I ..\..\src\tr4w.inc}

interface

uses
   Classes, VC, uTR4WTestFramework;

type
   TLogStoreTests = class(TTestCase)
   private
      FDir: string;
      FSavedLogName: string;
      FSavedSilent: boolean;
      FTrw: string;
      FDb: string;
      (* A backup a test made, scrubbed by Restore with its .new/.bak. *)
      FBackup: string;
      (* A fresh copy of a D7 fixture in a scratch directory, with no .db
        beside it, made the log the store will open. *)
      procedure PrepareMigration(const aSet: string);
      procedure Restore;
      procedure ScrubDb;
      (* Every callsign in a binary log, in order, and its last record. *)
      procedure ReadBinaryLog(aCalls: TStringList; out aLast: ContestExchange);
      (* Every callsign the published log holds, in log order. *)
      procedure ReadLogCalls(aCalls: TStringList);
      (* Every callsign the database aDb holds, opened read-only. *)
      procedure ReadCallsFrom(const aDb: string; aCalls: TStringList);
      procedure CheckImportedIntact(aBinary, aLog: TStringList; const aWhat: string);
   protected
      procedure TestAnAppendThatMigratesTheLogInsertsTheQSO;
      procedure TestAnAppendAfterAnEarlierMigrationInsertsTheQSO;
      procedure TestARewriteThatMigratesTheLogRewritesTheNewestQSO;
      procedure TestTheClearBackupNameRule;
      procedure TestABackupBeforeClearHoldsTheLogAndNeedsNoTrw;
      procedure TestAnEmptyLogIsBackedUpBeforeClear;
      procedure TestTheGridReadsTheLogAfterABackup;
   public
      procedure RunAllTests; override;
   end;

implementation

uses
   SysUtils, utils_text, uLogStore, uLogDatabase, uLogRepository,
   uLogBinaryFile, uLogSource;

const
   (* 101 records, a DX zone contest -- the repository round-trip's log. *)
   FIXTURE_SET = 'cqww_ssb_2025_ny4i';
   NEW_CALL = 'N0NEW';

procedure TLogStoreTests.PrepareMigration(const aSet: string);
var
   source, target: TFileStream;
begin
   if FDir = '' then
      begin
      FDir := IncludeTrailingPathDelimiter(GetTempDir) +
              'tr4w_logstore_' + IntToStr(GetProcessID);
      ForceDirectories(FDir);
      end;

   (* THE STORE MUST START CLOSED, or EnsureOpen answers from the log it
     already has and nothing below is about a migration. *)
   LogStoreClose;

   FTrw := IncludeTrailingPathDelimiter(FDir) + aSet + '.trw';
   FDb := LogDatabaseFileName(FTrw);
   ScrubDb;

   source := TFileStream.Create(ExtractFilePath(ParamStr(0)) + 'fixtures' +
                                PathDelim + 'binarylog' + PathDelim + aSet +
                                '.trw', fmOpenRead or fmShareDenyWrite);
   try
      target := TFileStream.Create(FTrw, fmCreate);
      try
         target.CopyFrom(source, 0);
      finally
         target.Free;
      end;
   finally
      source.Free;
   end;

   FSavedLogName := CharBufferText(TR4W_LOG_FILENAME);
   SetCharBuffer(TR4W_LOG_FILENAME, FTrw);

   (* No operator: a failure must be a log line and a False, not a modal
     that hangs the run -- the rule Disable already keeps for headless use. *)
   FSavedSilent := tSilentExport;
   tSilentExport := True;
end;

procedure TLogStoreTests.ScrubDb;
const
   SUFFIXES: array[0..5] of string = ('', '-wal', '-shm', '-journal',
      '.importing', '.importing-wal');
var
   i: integer;
begin
   for i := Low(SUFFIXES) to High(SUFFIXES) do
      begin
      if FileExists(FDb + SUFFIXES[i]) then
         begin
         DeleteFile(FDb + SUFFIXES[i]);
         end;
      end;
end;

procedure TLogStoreTests.Restore;
const
   BACKUP_SUFFIXES: array[0..5] of string = ('', '.new', '.bak', '-wal', '-shm',
      '-journal');
var
   i: integer;
begin
   LogStoreClose;
   SetCharBuffer(TR4W_LOG_FILENAME, FSavedLogName);
   tSilentExport := FSavedSilent;
   ScrubDb;
   if FBackup <> '' then
      begin
      for i := Low(BACKUP_SUFFIXES) to High(BACKUP_SUFFIXES) do
         begin
         if FileExists(FBackup + BACKUP_SUFFIXES[i]) then
            begin
            DeleteFile(FBackup + BACKUP_SUFFIXES[i]);
            end;
         end;
      FBackup := '';
      end;
   if FileExists(FTrw) then
      begin
      DeleteFile(FTrw);
      end;
   (* Only succeeds when empty, which is the point: anything left in it is a
     file this suite failed to scrub, and stays to be seen. *)
   if RemoveDir(FDir) then
      begin
      FDir := '';
      end;
end;

procedure TLogStoreTests.ReadBinaryLog(aCalls: TStringList; out aLast: ContestExchange);
var
   reader: TLogBinaryReader;
   rec: ContestExchange;
begin
   FillChar(aLast, SizeOf(ContestExchange), 0);
   reader := TLogBinaryReader.Create(FTrw);
   try
      while reader.ReadNext(rec) do
         begin
         aCalls.Add(string(rec.Callsign));
         aLast := rec;
         end;
   finally
      reader.Free;
   end;
end;

procedure TLogStoreTests.ReadLogCalls(aCalls: TStringList);
begin
   ReadCallsFrom(FDb, aCalls);
end;

procedure TLogStoreTests.ReadCallsFrom(const aDb: string; aCalls: TStringList);
var
   db: TLogDatabase;
   repo: TLogRepository;
   rec: ContestExchange;
begin
   db := TLogDatabase.Create;
   try
      db.OpenReadOnly(aDb);
      repo := TLogRepository.Create(db);
      try
         repo.OpenSequentialRead;
         try
            while repo.ReadNext(rec) do
               begin
               aCalls.Add(string(rec.Callsign));
               end;
         finally
            repo.CloseSequentialRead;
         end;
      finally
         repo.Free;
      end;
   finally
      db.Free;
   end;
end;

procedure TLogStoreTests.CheckImportedIntact(aBinary, aLog: TStringList;
                                             const aWhat: string);
var
   i: integer;
begin
   for i := 0 to aBinary.Count - 1 do
      begin
      if i >= aLog.Count then
         begin
         Break;
         end;
      CheckEquals(aBinary[i], aLog[i],
                  aWhat + ': imported QSO ' + IntToStr(i + 1) + ' is intact');
      end;
end;

(* THE CASE THE DELETED BRANCH WAS FOR: the append is the first thing to open
  the log, so EnsureOpen migrates the .TRW on this very call. The new QSO is
  not in the .TRW, so it must be INSERTED -- and the newest imported QSO must
  survive. The old branch left 101 rows, the last of them overwritten with
  NEW_CALL. *)
procedure TLogStoreTests.TestAnAppendThatMigratesTheLogInsertsTheQSO;
var
   binary, log: TStringList;
   last, fresh: ContestExchange;
begin
   BeginTest('an append that migrates the log inserts the QSO and keeps every imported one');

   PrepareMigration(FIXTURE_SET);
   binary := TStringList.Create;
   log := TStringList.Create;
   try
      ReadBinaryLog(binary, last);
      CheckTrue(binary.Count > 1, 'the fixture holds records');
      CheckFalse(FileExists(FDb), 'there is no log yet -- the append migrates');

      fresh := last;
      fresh.Callsign := NEW_CALL;
      (* Its own exchange id, so it is not grouped with the last QSO as one
        county-line contact. *)
      fresh.id := 'test-logstore-new-qso';

      CheckTrue(LogStoreAppendQSO(fresh), 'the append reports the QSO logged');
      CheckTrue(LogStoreIsUsable, 'and the store is still usable');
      LogStoreClose;

      ReadLogCalls(log);
      CheckEquals(binary.Count + 1, log.Count,
                  'the log holds every imported QSO AND the new one');
      CheckImportedIntact(binary, log, 'after the migrating append');
      if log.Count > 0 then
         begin
         CheckEquals(NEW_CALL, log[log.Count - 1], 'the newest row is the new QSO');
         end;
   finally
      log.Free;
      binary.Free;
      Restore;
   end;
end;

(* The program's own order: the log is opened (and migrated) at startup, and
  the append comes later. Not the defect's path, but the same promise. *)
procedure TLogStoreTests.TestAnAppendAfterAnEarlierMigrationInsertsTheQSO;
var
   binary, log: TStringList;
   last, fresh: ContestExchange;
begin
   BeginTest('an append after the log was migrated by an earlier open inserts the QSO');

   PrepareMigration(FIXTURE_SET);
   binary := TStringList.Create;
   log := TStringList.Create;
   try
      ReadBinaryLog(binary, last);
      CheckTrue(LogStoreEnsureOpen, 'the open migrates the log');

      fresh := last;
      fresh.Callsign := NEW_CALL;
      fresh.id := 'test-logstore-new-qso';
      CheckTrue(LogStoreAppendQSO(fresh), 'the append reports the QSO logged');
      LogStoreClose;

      ReadLogCalls(log);
      CheckEquals(binary.Count + 1, log.Count,
                  'the log holds every imported QSO AND the new one');
      CheckImportedIntact(binary, log, 'after an append to a migrated log');
      if log.Count > 0 then
         begin
         CheckEquals(NEW_CALL, log[log.Count - 1], 'the newest row is the new QSO');
         end;
   finally
      log.Free;
      binary.Free;
      Restore;
   end;
end;

(* THE TWIN: rewriting the newest QSO (Alt-Y delete/restore, a QTC mark, the
  network's update) on the call that migrates the log. The rewrite is not in
  the .TRW, so it must be written. The old branch returned and dropped it. *)
procedure TLogStoreTests.TestARewriteThatMigratesTheLogRewritesTheNewestQSO;
var
   binary, log: TStringList;
   last, edited: ContestExchange;
begin
   BeginTest('rewriting the newest QSO on the open that migrates the log writes the rewrite');

   PrepareMigration(FIXTURE_SET);
   binary := TStringList.Create;
   log := TStringList.Create;
   try
      ReadBinaryLog(binary, last);
      CheckFalse(FileExists(FDb), 'there is no log yet -- the rewrite migrates');

      edited := last;
      edited.Callsign := NEW_CALL;
      LogStoreUpdateNewestQSO(edited);
      CheckTrue(LogStoreIsUsable, 'the store is still usable');
      LogStoreClose;

      ReadLogCalls(log);
      CheckEquals(binary.Count, log.Count, 'a rewrite adds no row');
      if log.Count > 0 then
         begin
         CheckEquals(NEW_CALL, log[log.Count - 1],
                     'and the newest row carries the rewrite');
         end;
      binary.Delete(binary.Count - 1);
      CheckImportedIntact(binary, log, 'after the migrating rewrite');
   finally
      log.Free;
      binary.Free;
      Restore;
   end;
end;

(* CLEAR LOG'S BACKUP NAME (2026-10-23): beside the log, the log's name less
  its final .db, " before clear ", the UTC moment as yyyy-mm-dd hhnnss, "Z.db".
  Pure, so it runs on every platform. *)
procedure TLogStoreTests.TestTheClearBackupNameRule;
var
   dir: string;
   moment: TDateTime;
   name: string;
begin
   BeginTest('Clear Log''s backup is named "<log> before clear <UTC>Z.db" beside the log');

   dir := 'logs' + PathDelim;
   moment := EncodeDate(2026, 10, 23) + EncodeTime(23, 1, 44, 0);

   CheckEquals(dir + 'CQ-WW-SSB 2026-10-19 NY4I before clear 2026-10-23 230144Z.db',
               LogStoreClearBackupFileName(dir + 'CQ-WW-SSB 2026-10-19 NY4I.db', moment),
               'the worked example, exactly');

   CheckEquals(dir + 'K.1 ABC.v2 before clear 2026-10-23 230144Z.db',
               LogStoreClearBackupFileName(dir + 'K.1 ABC.v2.db', moment),
               'only the final .db is removed; the other dots stay');

   CheckEquals(dir + 'LOG before clear 2026-10-23 230144Z.db',
               LogStoreClearBackupFileName(dir + 'LOG.DB', moment),
               'the .db is recognised in any case');

   CheckEquals(dir + 'log.sqlite before clear 2026-10-23 230144Z.db',
               LogStoreClearBackupFileName(dir + 'log.sqlite', moment),
               'a name not ending in .db keeps all of it');

   name := LogStoreClearBackupFileName(dir + 'x.db',
                                       EncodeDate(2027, 1, 2) + EncodeTime(3, 4, 5, 0));
   CheckEquals(dir + 'x before clear 2027-01-02 030405Z.db', name,
               'month, day, hour, minute and second are zero-padded');
   CheckEquals('Z.db', Copy(name, Length(name) - 3, 4), 'the name ends in Z.db');
   CheckEquals(dir, ExtractFilePath(name), 'and it lies in the log''s directory');
end;

(* THE BACKUP CLEAR LOG TAKES HOLDS THE LOG, AND IS TAKEN FROM SQLITE ALONE.
  The .TRW the log was migrated from is deleted BEFORE the backup, so a backup
  that read, copied or needed it could not succeed; and none is created. *)
procedure TLogStoreTests.TestABackupBeforeClearHoldsTheLogAndNeedsNoTrw;
var
   log, saved: TStringList;
   path, report: string;
   ok: boolean;
   qso: ContestExchange;
   i: integer;
begin
   BeginTest('the backup before Clear Log holds every row of the SQLite log and needs no .TRW');

   PrepareMigration(FIXTURE_SET);
   log := TStringList.Create;
   saved := TStringList.Create;
   try
      CheckTrue(LogStoreEnsureOpen, 'the open migrates the log');
      DeleteFile(FTrw);
      CheckFalse(FileExists(FTrw), 'the .TRW is gone before the backup');
      (* A READ through the sequential cursor first, as LoadinLog reads: the
        cursor is a fresh query, so preparing it starts sqldb's transaction
        and closing it ends nothing. When the snapshot ran on the live
        connection, VACUUM INTO refused that open transaction; it runs on a
        connection of its own now, and this keeps the case covered. (A kept,
        already-prepared statement would not do: it runs in autocommit and
        opens no sqldb transaction.) *)
      CheckTrue(LogSourceOpen, 'the log source opens');
      LogSourceRewind;
      CheckTrue(LogSourceNext(qso), 'and reads a QSO');
      LogSourceClose;

      (* Called first: as an argument beside the message, FPC may build the
        message before the call has filled report. *)
      ok := LogStoreBackupBeforeClear(path, report);
      CheckTrue(ok, 'the backup before clearing succeeds: ' + report);
      FBackup := path;
      CheckEquals(ExtractFilePath(FDb), ExtractFilePath(path),
                  'it is written beside the log');
      CheckTrue(FileExists(path), 'the backup exists at the path it names');
      CheckFalse(FileExists(path + '.new'), 'and nothing is left staged');
      CheckFalse(Pos('.trw', LowerCase(path)) > 0, 'its name is not the .TRW''s');
      CheckFalse(FileExists(FTrw), 'no .TRW was created');
      LogStoreClose;

      ReadLogCalls(log);
      (* Only when there is a file: opening a missing one raises, and a
        failure must be a FAIL line, not a crash that ends the run. *)
      if FileExists(path) then
         begin
         ReadCallsFrom(path, saved);
         end;
      CheckTrue(log.Count > 1, 'the log holds the migrated QSOs');
      CheckEquals(log.Count, saved.Count, 'the backup holds every row of the log');
      for i := 0 to log.Count - 1 do
         begin
         if i >= saved.Count then
            begin
            Break;
            end;
         CheckEquals(log[i], saved[i], 'backup row ' + IntToStr(i + 1));
         end;
   finally
      saved.Free;
      log.Free;
      Restore;
   end;
end;

(* AN EMPTY LOG IS STILL BACKED UP -- LogStoreBackup does not refuse it, and
  the file it writes opens and holds no rows. *)
procedure TLogStoreTests.TestAnEmptyLogIsBackedUpBeforeClear;
var
   saved: TStringList;
   path, report: string;
   ok: boolean;
begin
   BeginTest('an empty log is backed up before Clear Log, to a file that opens');

   PrepareMigration(FIXTURE_SET);
   DeleteFile(FTrw);
   saved := TStringList.Create;
   try
      CheckTrue(LogStoreEnsureOpen, 'with no .TRW the open makes a new, empty log');
      ok := LogStoreBackupBeforeClear(path, report);
      CheckTrue(ok, 'the backup of an empty log succeeds: ' + report);
      FBackup := path;
      LogStoreClose;

      CheckTrue(FileExists(path), 'the backup exists');
      if FileExists(path) then
         begin
         ReadCallsFrom(path, saved);
         CheckEquals(0, saved.Count, 'and opens, holding no rows');
         end;
   finally
      saved.Free;
      Restore;
   end;
end;

(* THE GRID STILL READS THE LOG AFTER A BACKUP (2026-10-24, CQ WW SSB).

  The periodic backup ran VACUUM INTO on the LIVE connection. SQLite resets
  every schema of the connection that runs a VACUUM, and FPC's connector
  prepares with the legacy sqlite3_prepare, which never re-prepares: so the
  repository's KEPT range query, the one the main log grid reads through,
  failed on every later run with "TLogConnection : not an error". The QSO
  was committed; the grid could no longer show it, until a restart.

  So the read goes through the grid's own path, LogSourceReadRange, BEFORE
  the backup (that prepares and caches the statement) and AFTER it. A QSO is
  appended first, committed by the store, so the snapshot is also shown to
  hold a row that has not been checkpointed out of the -wal. *)
procedure TLogStoreTests.TestTheGridReadsTheLogAfterABackup;
var
   binary, log, saved: TStringList;
   last, fresh: ContestExchange;
   rows: array[0..9] of ContestExchange;
   dest, report, failure: string;
   ok: boolean;
   n, i: integer;
begin
   BeginTest('the grid''s cached range read still reads the log after a backup');

   PrepareMigration(FIXTURE_SET);
   binary := TStringList.Create;
   log := TStringList.Create;
   saved := TStringList.Create;
   try
      ReadBinaryLog(binary, last);
      CheckTrue(LogStoreEnsureOpen, 'the open migrates the log');

      fresh := last;
      fresh.Callsign := NEW_CALL;
      fresh.id := 'test-logstore-backup-qso';
      CheckTrue(LogStoreAppendQSO(fresh), 'the append reports the QSO logged');

      n := LogSourceReadRange(0, rows);
      CheckEquals(Length(rows), n, 'the range read fills its rows before the backup');

      dest := IncludeTrailingPathDelimiter(FDir) + 'periodic backup.db';
      FBackup := dest;
      (* Called first: as an argument beside the message, FPC may build the
        message before the call has filled report. *)
      ok := LogStoreBackup(dest, report);
      CheckTrue(ok, 'the backup succeeds: ' + report);

      (* THE DEFECT: this raised ESQLDatabaseError on the old code. *)
      failure := '';
      n := 0;
      try
         n := LogSourceReadRange(0, rows);
      except
         on E: Exception do
            begin
            failure := E.ClassName + ': ' + E.Message;
            end;
      end;
      CheckEquals('', failure, 'the range read does not raise after the backup');
      CheckEquals(Length(rows), n, 'and fills its rows');
      if n > 0 then
         begin
         CheckEquals(binary[0], string(rows[0].Callsign),
                     'and the first row is the log''s first QSO');
         end;

      (* And again, from further in: the read is not fixed by one retry. *)
      failure := '';
      n := 0;
      try
         n := LogSourceReadRange(binary.Count - 4, rows);
      except
         on E: Exception do
            begin
            failure := E.ClassName + ': ' + E.Message;
            end;
      end;
      CheckEquals('', failure, 'a second range read after the backup does not raise');
      CheckEquals(5, n, 'and reads the last five rows, the new QSO among them');
      if n = 5 then
         begin
         CheckEquals(NEW_CALL, string(rows[4].Callsign), 'the last row is the new QSO');
         end;

      CheckTrue(LogStoreIsUsable, 'the store is still usable');
      LogStoreClose;

      ReadLogCalls(log);
      if FileExists(dest) then
         begin
         ReadCallsFrom(dest, saved);
         end;
      CheckEquals(binary.Count + 1, log.Count, 'the log holds every QSO');
      CheckEquals(log.Count, saved.Count, 'the backup holds every committed row');
      for i := 0 to log.Count - 1 do
         begin
         if i >= saved.Count then
            begin
            Break;
            end;
         CheckEquals(log[i], saved[i], 'backup row ' + IntToStr(i + 1));
         end;
   finally
      saved.Free;
      log.Free;
      binary.Free;
      Restore;
   end;
end;

procedure TLogStoreTests.RunAllTests;
begin
   TestTheClearBackupNameRule;
{$IFNDEF WINDOWS}
   (* SAID, NOT SILENT -- as the LogImport suite: these migrate a D7 binary
     log, which is a Windows migration path. *)
   WriteLn('  SKIPPED: migrates a D7 binary log, which is a Windows migration path.');
   Exit;
{$ENDIF}
   TestAnAppendThatMigratesTheLogInsertsTheQSO;
   TestAnAppendAfterAnEarlierMigrationInsertsTheQSO;
   TestARewriteThatMigratesTheLogRewritesTheNewestQSO;
   TestABackupBeforeClearHoldsTheLogAndNeedsNoTrw;
   TestAnEmptyLogIsBackedUpBeforeClear;
   TestTheGridReadsTheLogAfterABackup;
end;

end.
