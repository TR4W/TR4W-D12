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
  were for. *)

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
      (* A fresh copy of a D7 fixture in a scratch directory, with no .db
        beside it, made the log the store will open. *)
      procedure PrepareMigration(const aSet: string);
      procedure Restore;
      procedure ScrubDb;
      (* Every callsign in a binary log, in order, and its last record. *)
      procedure ReadBinaryLog(aCalls: TStringList; out aLast: ContestExchange);
      (* Every callsign the published log holds, in log order. *)
      procedure ReadLogCalls(aCalls: TStringList);
      procedure CheckImportedIntact(aBinary, aLog: TStringList; const aWhat: string);
   protected
      procedure TestAnAppendThatMigratesTheLogInsertsTheQSO;
      procedure TestAnAppendAfterAnEarlierMigrationInsertsTheQSO;
      procedure TestARewriteThatMigratesTheLogRewritesTheNewestQSO;
   public
      procedure RunAllTests; override;
   end;

implementation

uses
   SysUtils, utils_text, uLogStore, uLogDatabase, uLogRepository,
   uLogBinaryFile;

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
begin
   LogStoreClose;
   SetCharBuffer(TR4W_LOG_FILENAME, FSavedLogName);
   tSilentExport := FSavedSilent;
   ScrubDb;
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
var
   db: TLogDatabase;
   repo: TLogRepository;
   rec: ContestExchange;
begin
   db := TLogDatabase.Create;
   try
      db.OpenReadOnly(FDb);
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

procedure TLogStoreTests.RunAllTests;
begin
{$IFNDEF WINDOWS}
   (* SAID, NOT SILENT -- as the LogImport suite: these migrate a D7 binary
     log, which is a Windows migration path. *)
   WriteLn('  SKIPPED: migrates a D7 binary log, which is a Windows migration path.');
   Exit;
{$ENDIF}
   TestAnAppendThatMigratesTheLogInsertsTheQSO;
   TestAnAppendAfterAnEarlierMigrationInsertsTheQSO;
   TestARewriteThatMigratesTheLogRewritesTheNewestQSO;
end;

end.
