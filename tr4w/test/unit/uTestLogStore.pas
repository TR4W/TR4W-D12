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
  included, with no .TRW beside it. Since 2026-10-24 (issue #98 step 1) it
  is written to a backup folder, never beside the log, its name never
  stacks, and a folder that cannot be made fails the backup.

  AND THAT WHAT IS DELETED STAYS DELETED ON DISK (2026-10-24): a cleared
  log holds no row once the program lets go of it, read by a connection
  that is not the store's; the clear is committed before the close; and a
  QSO deleted through Edit QSO is still flagged after a reopen and is
  neither counted nor exported. *)

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
      (* ONE NUMBER FROM THE FILE aDb, asked through a connection of the
        test's own -- TLogDatabase.OpenReadOnly, never the store's. aSql
        selects one integer. *)
      function ScalarFromFile(const aDb, aSql: string): Int64;
      (* The contest row of the file aDb, read the same way. *)
      procedure ReadContestRow(const aDb: string; out aType, aCall, aGuid: string);
      (* Which SQLite sidecars lie beside aDb now, by name; '' for none. *)
      function SidecarsBeside(const aDb: string): string;
      (* THE BACKUP FOLDER A TEST HANDS LogStoreBackupBeforeClear: 'backup'
        inside this suite's scratch directory, created here -- the program
        passes uAppPaths.BackupDir, which is under the settings and must not
        be written by a test. Restore removes it once it is empty. *)
      function ScratchBackupDir: string;
      (* Its name, without creating it. *)
      function ScratchBackupDirName: string;
      (* The names of the files in aDir, sorted, one per line. *)
      function FilesIn(const aDir: string): string;
   protected
      procedure TestAnAppendThatMigratesTheLogInsertsTheQSO;
      procedure TestAnAppendAfterAnEarlierMigrationInsertsTheQSO;
      procedure TestARewriteThatMigratesTheLogRewritesTheNewestQSO;
      procedure TestTheClearBackupNameRule;
      procedure TestThePeriodicBackupNameRule;
      procedure TestAPeriodicBackupGoesToTheFolderItIsGiven;
      procedure TestABackupBeforeClearHoldsTheLogAndNeedsNoTrw;
      procedure TestAnEmptyLogIsBackedUpBeforeClear;
      procedure TestABackupFolderThatCannotBeMadeFailsTheBackup;
      procedure TestTheGridReadsTheLogAfterABackup;
      procedure TestAClearedLogIsEmptyOnDiskAfterClose;
      procedure TestAClearIsCommittedBeforeTheLogIsClosed;
      procedure TestADeletedQSOStaysDeletedAndIsNotExported;
   public
      procedure RunAllTests; override;
   end;

implementation

uses
   SysUtils, utils_text, uLogStore, uLogDatabase, uLogRepository,
   uLogBinaryFile, uLogSource,
   sqldb,      (* TSQLQuery -- ScalarFromFile and ReadContestRow *)
   uLogNote,   (* SetNoteText -- a NOTE record, as MainUnit's note command makes *)
   PostUnit;   (* ExportToADIF -- the export a deleted QSO must not reach *)

const
   (* 101 records, a DX zone contest -- the repository round-trip's log. *)
   FIXTURE_SET = 'cqww_ssb_2025_ny4i';
   NEW_CALL = 'N0NEW';
   SQL_ALL_ROWS     = 'SELECT COUNT(*) FROM qso';
   SQL_NOTE_ROWS    = 'SELECT COUNT(*) FROM qso WHERE record_kind = ''NOTE''';
   SQL_DELETED_ROWS = 'SELECT COUNT(*) FROM qso WHERE deleted <> 0';

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
   (* ExportToADIF writes the log's name with .ADI beside the .trw. *)
   if FileExists(ChangeFileExt(FTrw, '.ADI')) then
      begin
      DeleteFile(ChangeFileExt(FTrw, '.ADI'));
      end;
   if FileExists(FTrw) then
      begin
      DeleteFile(FTrw);
      end;
   (* Only succeeds when empty, which is the point: anything left in it is a
     file this suite failed to scrub, and stays to be seen. The backup folder
     first, because it lies inside FDir. *)
   if (FDir <> '') and DirectoryExists(ScratchBackupDirName) then
      begin
      RemoveDir(ScratchBackupDirName);
      end;
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

(* A CONNECTION OF ITS OWN, so what it reads is what the FILE holds: another
  connection sees only what has been COMMITTED (WAL included), never the
  store's open transaction. Read-only, so it writes nothing to the file --
  but on a WAL-mode log it can leave a -wal behind, which is why every test
  below looks for sidecars BEFORE it reads through here. *)
function TLogStoreTests.ScalarFromFile(const aDb, aSql: string): Int64;
var
   db: TLogDatabase;
   q: TSQLQuery;
begin
   Result := -1;
   db := TLogDatabase.Create;
   try
      db.OpenReadOnly(aDb);
      q := TSQLQuery.Create(nil);
      try
         q.DataBase := db.Connection;
         q.Transaction := db.Transaction;
         q.UsePrimaryKeyAsKey := False;
         q.SQL.Text := aSql;
         q.Open;
         if not q.EOF then
            begin
            Result := q.Fields[0].AsLargeInt;
            end;
         q.Close;
      finally
         q.Free;
      end;
   finally
      db.Free;
   end;
end;

procedure TLogStoreTests.ReadContestRow(const aDb: string; out aType, aCall, aGuid: string);
var
   db: TLogDatabase;
   q: TSQLQuery;
begin
   aType := '';
   aCall := '';
   aGuid := '';
   db := TLogDatabase.Create;
   try
      db.OpenReadOnly(aDb);
      q := TSQLQuery.Create(nil);
      try
         q.DataBase := db.Connection;
         q.Transaction := db.Transaction;
         q.UsePrimaryKeyAsKey := False;
         q.SQL.Text := 'SELECT contest_type, my_call, guid FROM contest WHERE id = 1';
         q.Open;
         if not q.EOF then
            begin
            aType := q.Fields[0].AsString;
            aCall := q.Fields[1].AsString;
            aGuid := q.Fields[2].AsString;
            end;
         q.Close;
      finally
         q.Free;
      end;
   finally
      db.Free;
   end;
end;

function TLogStoreTests.SidecarsBeside(const aDb: string): string;
const
   SIDECARS: array[0..2] of string = ('-wal', '-shm', '-journal');
var
   i: integer;
begin
   Result := '';
   for i := Low(SIDECARS) to High(SIDECARS) do
      begin
      if FileExists(aDb + SIDECARS[i]) then
         begin
         Result := Result + ' ' + SIDECARS[i];
         end;
      end;
end;

function TLogStoreTests.ScratchBackupDirName: string;
begin
   Result := IncludeTrailingPathDelimiter(FDir) + 'backup';
end;

function TLogStoreTests.ScratchBackupDir: string;
begin
   Result := ScratchBackupDirName;
   ForceDirectories(Result);
end;

function TLogStoreTests.FilesIn(const aDir: string): string;
var
   found: TSearchRec;
   names: TStringList;
begin
   names := TStringList.Create;
   try
      names.Sorted := True;
      if FindFirst(IncludeTrailingPathDelimiter(aDir) + '*', faAnyFile, found) = 0 then
         begin
         repeat
            if (found.Attr and faDirectory) = 0 then
               begin
               names.Add(found.Name);
               end;
         until FindNext(found) <> 0;
         FindClose(found);
         end;
      Result := names.Text;
   finally
      names.Free;
   end;
end;

(* How many times aNeedle occurs in aText. *)
function CountOccurrences(const aNeedle, aText: string): integer;
var
   p: integer;
   rest: string;
begin
   Result := 0;
   rest := aText;
   p := Pos(aNeedle, rest);
   while p > 0 do
      begin
      Inc(Result);
      rest := Copy(rest, p + Length(aNeedle), MaxInt);
      p := Pos(aNeedle, rest);
      end;
end;

(* Do the raw bytes of aFile contain aText anywhere -- live pages, free
  pages, anything? A byte search, not a query: it asks what is ON THE DISK,
  which no SELECT can. *)
function FileHoldsText(const aFile: string; const aText: AnsiString): boolean;
var
   stream: TBytesStream;
   bytes: TBytes;
   i, j: integer;
   matched: boolean;
begin
   Result := False;
   stream := TBytesStream.Create;
   try
      stream.LoadFromFile(aFile);
      bytes := stream.Bytes;
      for i := 0 to integer(stream.Size) - Length(aText) do
         begin
         matched := True;
         for j := 1 to Length(aText) do
            begin
            if bytes[i + j - 1] <> Ord(aText[j]) then
               begin
               matched := False;
               Break;
               end;
            end;
         if matched then
            begin
            Result := True;
            Exit;
            end;
         end;
   finally
      stream.Free;
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

(* CLEAR LOG'S BACKUP NAME (2026-10-23; moved to the backup folder
  2026-10-24, issue #98 step 1): IN THE BACKUP FOLDER, the log's file name
  less its final .db and less any earlier " before clear <stamp>Z", then
  " before clear ", the UTC moment as yyyy-mm-dd hhnnss, "Z.db". Pure, so it
  runs on every platform. *)
procedure TLogStoreTests.TestTheClearBackupNameRule;
var
   logs, backups: string;
   moment: TDateTime;
   name: string;
begin
   BeginTest('Clear Log''s backup is "<log> before clear <UTC>Z.db" in the backup folder');

   logs := 'logs' + PathDelim;
   backups := 'settings' + PathDelim + 'backup' + PathDelim;
   moment := EncodeDate(2026, 10, 23) + EncodeTime(23, 1, 44, 0);

   CheckEquals(backups + 'CQ-WW-SSB 2026-10-19 NY4I before clear 2026-10-23 230144Z.db',
               LogStoreClearBackupFileName(logs + 'CQ-WW-SSB 2026-10-19 NY4I.db',
                                           backups, moment),
               'the worked example, exactly');

   CheckEquals(backups + 'K.1 ABC.v2 before clear 2026-10-23 230144Z.db',
               LogStoreClearBackupFileName(logs + 'K.1 ABC.v2.db', backups, moment),
               'only the final .db is removed; the other dots stay');

   CheckEquals(backups + 'LOG before clear 2026-10-23 230144Z.db',
               LogStoreClearBackupFileName(logs + 'LOG.DB', backups, moment),
               'the .db is recognised in any case');

   CheckEquals(backups + 'log.sqlite before clear 2026-10-23 230144Z.db',
               LogStoreClearBackupFileName(logs + 'log.sqlite', backups, moment),
               'a name not ending in .db keeps all of it');

   name := LogStoreClearBackupFileName(logs + 'x.db', backups,
                                       EncodeDate(2027, 1, 2) + EncodeTime(3, 4, 5, 0));
   CheckEquals(backups + 'x before clear 2027-01-02 030405Z.db', name,
               'month, day, hour, minute and second are zero-padded');
   CheckEquals('Z.db', Copy(name, Length(name) - 3, 4), 'the name ends in Z.db');
   CheckEquals(backups, ExtractFilePath(name),
               'and it lies in the backup folder, not the log''s directory');

   CheckEquals(backups + 'x before clear 2026-10-23 230144Z.db',
               LogStoreClearBackupFileName(logs + 'x.db', 'settings' + PathDelim + 'backup',
                                           moment),
               'a backup folder named without its trailing separator gains one');

   CheckEquals(backups + 'x before clear 2026-10-23 230144Z.db',
               LogStoreClearBackupFileName('x.db', backups, moment),
               'a log named with no directory at all');

   (* NAMES NEVER STACK. *)
   CheckEquals(backups + 'POTA K-1234 before clear 2026-10-23 230144Z.db',
               LogStoreClearBackupFileName(logs + 'POTA K-1234 before clear 2026-10-22 101500Z.db',
                                           backups, moment),
               'a log that is itself a pre-clear backup is named for the log it came from');

   CheckEquals(backups + 'POTA before clear 2026-10-23 230144Z.db',
               LogStoreClearBackupFileName(logs + 'POTA before clear 2026-10-21 000000Z'
                                           + ' before clear 2026-10-22 101500Z.db',
                                           backups, moment),
               'a name that stacked before the rule loses every suffix');

   CheckEquals(backups + 'POTA before clear 2026-10-22 before clear 2026-10-23 230144Z.db',
               LogStoreClearBackupFileName(logs + 'POTA before clear 2026-10-22.db',
                                           backups, moment),
               'words that only look like the suffix are part of the log''s name');

   CheckEquals(backups + 'POTA before clear 2026-10-22 10150XZ before clear 2026-10-23 230144Z.db',
               LogStoreClearBackupFileName(logs + 'POTA before clear 2026-10-22 10150XZ.db',
                                           backups, moment),
               'a stamp with a non-digit in it is not a stamp');
end;

(* THE PERIODIC BACKUP'S NAME (issue #98 step 2): IN THE BACKUP FOLDER,
  "<log> periodic.db", one per log -- where 'logback.db' had been one name
  every contest overwrote. The base is the same rule as Clear Log's, so
  NEITHER SUFFIX STACKS ON THE OTHER, in either order. *)
procedure TLogStoreTests.TestThePeriodicBackupNameRule;
var
   logs, backups: string;
   moment: TDateTime;
begin
   BeginTest('the periodic backup is "<log> periodic.db" in the backup folder, and never stacks');

   logs := 'logs' + PathDelim;
   backups := 'settings' + PathDelim + 'backup' + PathDelim;
   moment := EncodeDate(2026, 10, 23) + EncodeTime(23, 1, 44, 0);

   CheckEquals(backups + 'CQ-WW-SSB 2026-10-19 NY4I periodic.db',
               LogStorePeriodicBackupFileName(logs + 'CQ-WW-SSB 2026-10-19 NY4I.db', backups),
               'the worked example, exactly');
   CheckEquals(backups + 'LOG periodic.db',
               LogStorePeriodicBackupFileName(logs + 'LOG.DB', 'settings' + PathDelim + 'backup'),
               'the .db in any case, and a folder without its separator');
   CheckEquals(backups + 'x periodic.db',
               LogStorePeriodicBackupFileName('x.db', backups),
               'a log named with no directory at all');

   (* NEITHER SUFFIX STACKS. *)
   CheckEquals(backups + 'POTA periodic.db',
               LogStorePeriodicBackupFileName(logs + 'POTA periodic.db', backups),
               'a periodic backup opened as a log is named for the log it came from');
   CheckEquals(backups + 'POTA periodic.db',
               LogStorePeriodicBackupFileName(logs + 'POTA periodic periodic.db', backups),
               'a stacked periodic suffix goes entirely');
   CheckEquals(backups + 'POTA periodic.db',
               LogStorePeriodicBackupFileName(logs + 'POTA before clear 2026-10-22 101500Z periodic.db',
                                              backups),
               'a pre-clear suffix under a periodic one goes too');
   CheckEquals(backups + 'POTA periodic.db',
               LogStorePeriodicBackupFileName(logs + 'POTA periodic before clear 2026-10-22 101500Z.db',
                                              backups),
               'and a periodic suffix under a pre-clear one');
   CheckEquals(backups + 'POTA before clear 2026-10-23 230144Z.db',
               LogStoreClearBackupFileName(logs + 'POTA periodic.db', backups, moment),
               'clearing a log opened from a periodic backup names the log it came from');

   (* ONLY THE EXACT SUFFIX. *)
   CheckEquals(backups + 'Periodic periodic.db',
               LogStorePeriodicBackupFileName(logs + 'Periodic.db', backups),
               'a log called Periodic keeps its name: the suffix has a leading space');
   CheckEquals(backups + 'Sprint PERIODIC periodic.db',
               LogStorePeriodicBackupFileName(logs + 'Sprint PERIODIC.db', backups),
               'and is matched in the case it is written');
end;

(* THE PERIODIC BACKUP GOES TO THE FOLDER IT IS GIVEN, AND THE LOG'S
  DIRECTORY GAINS NOTHING -- the Open dialog lists every .db there, which is
  how 'logback.db' came to be listed as a contest. The second backup displaces
  the first to .bak (TLogBackup's publish, kept). *)
procedure TLogStoreTests.TestAPeriodicBackupGoesToTheFolderItIsGiven;
var
   saved: TStringList;
   path, secondPath, report, contestFiles: string;
   ok: boolean;
begin
   BeginTest('the periodic backup is written to the folder it is given, never beside the log');

   PrepareMigration(FIXTURE_SET);
   saved := TStringList.Create;
   try
      CheckTrue(LogStoreEnsureOpen, 'the open migrates the log');
      contestFiles := FilesIn(FDir);

      ok := LogStoreBackupPeriodic(ScratchBackupDir, path, report);
      CheckTrue(ok, 'the periodic backup succeeds: ' + report);
      FBackup := path;
      CheckEquals(IncludeTrailingPathDelimiter(ScratchBackupDirName) + FIXTURE_SET + ' periodic.db',
                  path, 'it is "<log> periodic.db" in the backup folder');
      CheckEquals(contestFiles, FilesIn(FDir), 'the log''s directory gains no file from it');
      CheckEquals(LogStorePeriodicBackupPath(ScratchBackupDirName), path,
                  'and it is the name the program asks for at open');

      ok := LogStoreBackupPeriodic(ScratchBackupDir, secondPath, report);
      CheckTrue(ok, 'a second periodic backup succeeds: ' + report);
      CheckEquals(path, secondPath, 'to the same name -- one per log');
      CheckTrue(FileExists(path + '.bak'), 'the first is kept as .bak');
      CheckFalse(FileExists(path + '.new'), 'and nothing is left staged');
      CheckEquals(contestFiles, FilesIn(FDir), 'still nothing beside the log');
      LogStoreClose;

      if FileExists(path) then
         begin
         ReadCallsFrom(path, saved);
         end;
      CheckTrue(saved.Count > 1, 'the backup holds the log''s QSOs');
   finally
      saved.Free;
      Restore;
   end;
end;

(* THE BACKUP CLEAR LOG TAKES HOLDS THE LOG, AND IS TAKEN FROM SQLITE ALONE.
  The .TRW the log was migrated from is deleted BEFORE the backup, so a backup
  that read, copied or needed it could not succeed; and none is created. *)
procedure TLogStoreTests.TestABackupBeforeClearHoldsTheLogAndNeedsNoTrw;
var
   log, saved: TStringList;
   path, report, contestFiles: string;
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

      (* THE CONTEST DIRECTORY GAINS NOTHING (issue #98 step 1): the Open
        dialog lists every .db there, so a backup beside the log was listed
        as a contest. Its files are named before the backup and after. *)
      contestFiles := FilesIn(FDir);

      (* Called first: as an argument beside the message, FPC may build the
        message before the call has filled report. *)
      ok := LogStoreBackupBeforeClear(ScratchBackupDir, path, report);
      CheckTrue(ok, 'the backup before clearing succeeds: ' + report);
      FBackup := path;
      CheckEquals(IncludeTrailingPathDelimiter(ScratchBackupDirName), ExtractFilePath(path),
                  'it is written to the backup folder');
      CheckEquals(contestFiles, FilesIn(FDir),
                  'and the log''s directory gains no file from it');
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
      ok := LogStoreBackupBeforeClear(ScratchBackupDir, path, report);
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

(* A BACKUP FOLDER THAT CANNOT BE MADE IS A FAILED BACKUP, AND THE LOG IS LEFT
  ALONE (issue #98 step 1).

  Made deterministic on every platform by a FILE occupying the folder's name:
  ForceDirectories cannot turn it into a directory, which is exactly what
  uAppPaths.BackupDir meets when it cannot create the folder. The backup must
  answer False with a report, write nothing anywhere -- in particular NOT fall
  back to beside the log -- and the log must still hold every row, because
  MainUnit.ClearLog clears only after a backup that answered True. *)
procedure TLogStoreTests.TestABackupFolderThatCannotBeMadeFailsTheBackup;
var
   blocker: TFileStream;
   blockerName, path, report, contestFiles: string;
   ok: boolean;
   before: Int64;
begin
   BeginTest('a backup folder that cannot be made fails the backup and leaves the log as it was');

   PrepareMigration(FIXTURE_SET);
   blockerName := IncludeTrailingPathDelimiter(FDir) + 'backup-blocked';
   try
      CheckTrue(LogStoreEnsureOpen, 'the open migrates the log');
      before := ScalarFromFile(FDb, SQL_ALL_ROWS);
      CheckTrue(before > 1, 'the log holds its rows');

      blocker := TFileStream.Create(blockerName, fmCreate);
      blocker.Free;
      ForceDirectories(blockerName);
      CheckFalse(DirectoryExists(blockerName),
                 'with a file in the way, the folder cannot be made');

      contestFiles := FilesIn(FDir);
      ok := LogStoreBackupBeforeClear(blockerName, path, report);
      CheckFalse(ok, 'the backup fails');
      CheckTrue(report <> '', 'and says why: ' + report);
      CheckTrue(Pos(blockerName, report) > 0, 'naming the folder');
      CheckFalse(FileExists(path), 'no backup file exists at the path it named');
      CheckFalse(FileExists(path + '.new'), 'and nothing is staged there');
      CheckEquals(contestFiles, FilesIn(FDir),
                  'and nothing was written beside the log instead');
      CheckTrue(LogStoreIsUsable, 'the store is still usable');
      CheckEquals(before, ScalarFromFile(FDb, SQL_ALL_ROWS),
                  'and the log still holds every row');
   finally
      if FileExists(blockerName) then
         begin
         DeleteFile(blockerName);
         end;
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

(* CLEAR LOG EMPTIES THE FILE, AND THE FILE STAYS EMPTY (2026-10-24).

  NY4I ran Clear Log in POTA, quit, restarted and saw four QSOs. The log
  and tr4w.log showed the clear had worked and the file he opened was Clear
  Log's backup. The tests above prove the BACKUP holds the rows; nothing
  proved the CLEARED LOG is empty ON DISK once the program has let go of it.

  The program's order (MainUnit.ClearLog): LogStoreBackupBeforeClear, then
  LogStoreClearAllQSOs. Then the program closes (LogStoreClose), and the
  file is read by a connection that is NOT the store's. The log holds every
  kind of row first -- QSOs, a NOTE, a soft-deleted QSO -- because DELETE
  FROM qso must take them all.

  THE .TRW STAYS BESIDE THE LOG ON PURPOSE. A reopen of an empty log must
  open the database, not re-import the binary log it was migrated from;
  that would bring every QSO back, which is the symptom being ruled out. *)
procedure TLogStoreTests.TestAClearedLogIsEmptyOnDiskAfterClose;
var
   path, report, sidecars: string;
   typeBefore, callBefore, guidBefore, typeAfter, callAfter, guidAfter: string;
   ok, residue: boolean;
   note, qso, newest: ContestExchange;
   before, notes, deleted: Int64;
begin
   BeginTest('Clear Log leaves the log file with no rows of any kind once the program closes it');

   PrepareMigration(FIXTURE_SET);
   try
      CheckTrue(LogStoreEnsureOpen, 'the open migrates the log');

      (* A NOTE, as MainUnit's note command logs one. *)
      note := Default(ContestExchange);
      note.ceRecordKind := rkNote;
      SetNoteText(note, 'a note logged before Clear Log');
      CheckTrue(LogStoreAppendQSO(note), 'a note is logged');

      (* A SOFT-DELETED QSO, as Edit QSO leaves one. *)
      CheckTrue(LogSourceReadAtIndex(0, qso), 'the first QSO reads');
      qso.ceQSO_Deleted := True;
      LogStoreUpdateQSOAtIndex(0, qso);
      CheckTrue(LogStoreIsUsable, 'the store is usable after the delete');

      (* A callsign whose bytes are searched for in the file afterwards. *)
      CheckTrue(LogSourceReadFromEnd(2, newest), 'the newest QSO before the note reads');

      before := ScalarFromFile(FDb, SQL_ALL_ROWS);
      notes := ScalarFromFile(FDb, SQL_NOTE_ROWS);
      deleted := ScalarFromFile(FDb, SQL_DELETED_ROWS);
      CheckTrue(before > 2, 'the file holds the log''s rows before the clear');
      CheckEquals(1, notes, 'the file holds the note');
      CheckEquals(1, deleted, 'and the deleted QSO');
      ReadContestRow(FDb, typeBefore, callBefore, guidBefore);
      CheckTrue(typeBefore <> '', 'the contest row names a contest');
      CheckTrue(guidBefore <> '', 'and carries the log''s guid');

      (* MainUnit.ClearLog's two calls, in its order. *)
      ok := LogStoreBackupBeforeClear(ScratchBackupDir, path, report);
      CheckTrue(ok, 'the backup before clearing succeeds: ' + report);
      FBackup := path;
      CheckTrue(LogStoreClearAllQSOs, 'the clear reports success');
      LogStoreClose;

      (* SIDECARS FIRST, before anything opens the file to look: a read-only
        connection to a WAL-mode log leaves its own -wal behind. With none,
        the .db alone is the log -- the WAL was checkpointed into it and
        removed when the store's connection, the last one, closed cleanly. So
        no stray -wal or -journal can carry the deleted rows back in. *)
      sidecars := SidecarsBeside(FDb);
      CheckEquals('', sidecars, 'after the close nothing lies beside the log');

      (* AND THE BYTES. REPORTED, NOT ASSERTED: SQLite's DELETE frees the
        pages without overwriting them unless secure_delete is on, which this
        log does not set and which the shipped library decides by default.
        So the rows are gone from every query while old bytes may survive on
        free pages until reused. Said here so that is known, not discovered. *)
      residue := FileHoldsText(FDb, AnsiString(newest.Callsign));
      if residue then
         begin
         WriteLn('  NOTE: "', string(newest.Callsign), '" is still present in the ',
                 'cleared file''s bytes (no secure_delete; ',
                 ScalarFromFile(FDb, 'SELECT freelist_count FROM pragma_freelist_count()'),
                 ' free pages); no query can read it.');
         end
      else
         begin
         WriteLn('  NOTE: "', string(newest.Callsign), '" is not present anywhere in ',
                 'the cleared file''s bytes.');
         end;

      CheckEquals(0, ScalarFromFile(FDb, SQL_ALL_ROWS),
                  'the cleared file holds no row in qso, of any record kind');
      CheckEquals(0, ScalarFromFile(FDb, SQL_NOTE_ROWS), 'no note');
      CheckEquals(0, ScalarFromFile(FDb, SQL_DELETED_ROWS), 'no deleted QSO');

      ReadContestRow(FDb, typeAfter, callAfter, guidAfter);
      CheckEquals(typeBefore, typeAfter, 'the contest row keeps its contest');
      CheckEquals(callBefore, callAfter, 'and its call');
      CheckEquals(guidBefore, guidAfter, 'and its identity');

      if FileExists(path) then
         begin
         CheckEquals(before, ScalarFromFile(path, SQL_ALL_ROWS),
                     'the backup still holds every row the log had');
         CheckEquals(1, ScalarFromFile(path, SQL_NOTE_ROWS), 'the note among them');
         end
      else
         begin
         CheckTrue(False, 'the backup exists at ' + path);
         end;

      (* THE PROGRAM'S OWN VIEW, ON THE NEXT START. *)
      CheckTrue(FileExists(FTrw), 'the .TRW the log came from is still beside it');
      CheckTrue(LogStoreEnsureOpen, 'the cleared log reopens');
      CheckEquals(0, LogSourceRecordCount, 'the log source counts no record');
      if LogStoreRepository <> nil then
         begin
         CheckEquals(0, LogStoreRepository.RecordCount, 'the repository counts no row');
         CheckEquals(0, LogStoreRepository.QSOCount, 'and no QSO');
         end;
      CheckTrue(LogSourceOpen, 'the log source opens');
      LogSourceRewind;
      CheckFalse(LogSourceNext(qso), 'and reads nothing');
      LogSourceClose;
   finally
      Restore;
   end;
end;

(* THE CLEAR IS COMMITTED WHEN LogStoreClearAllQSOs RETURNS -- not at close.

  Read from a connection of the test's own while the store still holds the
  log open. Another connection sees only committed data, so an empty answer
  here means a crash straight after Clear Log could not bring the rows back:
  there is nothing uncommitted left for a rollback to undo. *)
procedure TLogStoreTests.TestAClearIsCommittedBeforeTheLogIsClosed;
var
   path, report: string;
   ok: boolean;
   before: Int64;
begin
   BeginTest('Clear Log is committed before the program closes the log');

   PrepareMigration(FIXTURE_SET);
   try
      CheckTrue(LogStoreEnsureOpen, 'the open migrates the log');
      before := ScalarFromFile(FDb, SQL_ALL_ROWS);
      CheckTrue(before > 1, 'another connection sees the log''s rows');

      ok := LogStoreBackupBeforeClear(ScratchBackupDir, path, report);
      CheckTrue(ok, 'the backup before clearing succeeds: ' + report);
      FBackup := path;
      CheckTrue(LogStoreClearAllQSOs, 'the clear reports success');
      CheckTrue(LogStoreIsUsable, 'and the store is still usable');

      CheckEquals(0, ScalarFromFile(FDb, SQL_ALL_ROWS),
                  'with the store still open, another connection sees no row');
      if FileExists(path) then
         begin
         CheckEquals(before, ScalarFromFile(path, SQL_ALL_ROWS),
                     'and the backup holds them all');
         end;
   finally
      Restore;
   end;
end;

(* ONE QSO DELETED THROUGH EDIT QSO STAYS DELETED, AND NOTHING COUNTS OR
  EXPORTS IT.

  WHAT "DELETED" MEANS IN THE FILE: A FLAG, NOT A REMOVAL. uEditQSO sets
  ceQSO_Deleted and calls LogStoreUpdateQSOAtIndex, which rewrites the row
  with deleted = 1 (Alt-Y's LogStoreUpdateNewestQSO writes the same column).
  The row and its data stay in qso -- the D7 binary log kept deleted
  records too, and Edit QSO can bring one back. So this pins the flag
  surviving a close and a reopen, and every reader that must leave it out:
  the repository's QSO count, the log reader's "good" filter, and the ADIF
  export, which is exported before the delete as well so the check is shown
  to see the QSO when it is there. *)
procedure TLogStoreTests.TestADeletedQSOStaysDeletedAndIsNotExported;
var
   calls: TStringList;
   good: array of boolean;
   rec: ContestExchange;
   adif: TStringList;
   adiFile, target, tag, sidecars: string;
   total, liveBefore, goodBefore, goodAfter, index, i, j, n: integer;
   rowId: Int64;
begin
   BeginTest('a QSO deleted through Edit QSO stays deleted on disk and is not counted or exported');

   PrepareMigration(FIXTURE_SET);
   calls := TStringList.Create;
   adif := TStringList.Create;
   try
      CheckTrue(LogStoreEnsureOpen, 'the open migrates the log');

      (* Every record, and whether the export would take it. *)
      SetLength(good, 0);
      CheckTrue(LogSourceOpen, 'the log source opens');
      LogSourceRewind;
      while LogSourceNext(rec) do
         begin
         calls.Add(string(rec.Callsign));
         SetLength(good, Length(good) + 1);
         good[High(good)] := uLogBinaryFile.GoodLookingQSO(rec);
         end;
      LogSourceClose;
      total := calls.Count;
      goodBefore := 0;
      for i := 0 to High(good) do
         begin
         if good[i] then
            begin
            Inc(goodBefore);
            end;
         end;

      (* A QSO the export takes, whose call is in the log once and plain, so
        its ADIF CALL field is unambiguous. From the middle of the log. *)
      index := -1;
      i := total div 2;
      while (index < 0) and (i < total) do
         begin
         target := calls[i];
         n := 0;
         if good[i]                    and
            (Pos('/', target) = 0)     and
            (Length(target) >= 3)      then
            begin
            for j := 0 to total - 1 do
               begin
               if calls[j] = target then
                  begin
                  Inc(n);
                  end;
               end;
            end;
         if n = 1 then
            begin
            index := i;
            end;
         Inc(i);
         end;
      CheckTrue(index >= 0, 'the fixture has a QSO with a call of its own');
      if index < 0 then
         begin
         Exit;
         end;
      target := calls[index];
      tag := '<CALL:' + IntToStr(Length(target)) + '>' + target + ' ';
      adiFile := ChangeFileExt(FTrw, '.ADI');

      liveBefore := -1;
      if LogStoreRepository <> nil then
         begin
         liveBefore := LogStoreRepository.QSOCount;
         end;

      PostUnit.ExportToADIF;
      CheckTrue(FileExists(adiFile), 'the export before the delete writes its file');
      if FileExists(adiFile) then
         begin
         adif.LoadFromFile(adiFile);
         CheckEquals(goodBefore, CountOccurrences('<CALL:', adif.Text),
                     'before the delete the export holds every good QSO');
         CheckEquals(1, CountOccurrences(tag, adif.Text),
                     'and the QSO about to be deleted, once');
         DeleteFile(adiFile);
         end;

      (* UEDITQSO'S WRITE: the record as read, its deleted box ticked. *)
      CheckTrue(LogSourceReadAtIndex(index, rec), 'the QSO reads by its index');
      rec.ceQSO_Deleted := True;
      LogStoreUpdateQSOAtIndex(index, rec);
      CheckTrue(LogStoreIsUsable, 'the store is usable after the delete');
      LogStoreClose;

      sidecars := SidecarsBeside(FDb);
      CheckEquals('', sidecars, 'after the close nothing lies beside the log');

      (* THE FILE, through a connection of the test's own. *)
      rowId := ScalarFromFile(FDb, 'SELECT id FROM qso ORDER BY id LIMIT 1 OFFSET ' +
                              IntToStr(index));
      CheckTrue(rowId > 0, 'the deleted QSO''s row is still in the file');
      CheckEquals(total, ScalarFromFile(FDb, SQL_ALL_ROWS),
                  'a delete removes no row: it is a flag');
      CheckEquals(1, ScalarFromFile(FDb, 'SELECT deleted FROM qso WHERE id = ' +
                                    IntToStr(rowId)),
                  'the row is marked deleted on disk');
      CheckEquals(1, ScalarFromFile(FDb, SQL_DELETED_ROWS), 'and it is the only one');

      (* THE PROGRAM'S VIEW, AFTER A RESTART. *)
      CheckTrue(LogStoreEnsureOpen, 'the log reopens');
      CheckEquals(total, LogSourceRecordCount, 'the log source still counts every record');
      if LogStoreRepository <> nil then
         begin
         CheckEquals(liveBefore - 1, LogStoreRepository.QSOCount,
                     'the repository''s QSO count leaves the deleted QSO out');
         end;
      CheckTrue(LogSourceReadAtIndex(index, rec), 'the deleted QSO still reads by index');
      CheckTrue(rec.ceQSO_Deleted, 'and reads back deleted');
      CheckEquals(target, string(rec.Callsign), 'with its data intact');
      CheckFalse(uLogBinaryFile.GoodLookingQSO(rec), 'so the export filter refuses it');

      goodAfter := 0;
      CheckTrue(LogSourceOpen, 'the log source opens');
      LogSourceRewind;
      while LogSourceNext(rec) do
         begin
         if uLogBinaryFile.GoodLookingQSO(rec) then
            begin
            Inc(goodAfter);
            CheckFalse(string(rec.Callsign) = target,
                       'the sequential reader''s good QSOs leave the deleted one out');
            end;
         end;
      LogSourceClose;
      CheckEquals(goodBefore - 1, goodAfter, 'one good QSO fewer');

      PostUnit.ExportToADIF;
      CheckTrue(FileExists(adiFile), 'the export after the delete writes its file');
      if FileExists(adiFile) then
         begin
         adif.LoadFromFile(adiFile);
         CheckEquals(goodBefore - 1, CountOccurrences('<CALL:', adif.Text),
                     'the export holds one QSO fewer');
         CheckEquals(0, CountOccurrences(tag, adif.Text),
                     'and not the deleted one');
         end;
   finally
      adif.Free;
      calls.Free;
      Restore;
   end;
end;

procedure TLogStoreTests.RunAllTests;
begin
   TestTheClearBackupNameRule;
   TestThePeriodicBackupNameRule;
   TestAPeriodicBackupGoesToTheFolderItIsGiven;
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
   TestABackupFolderThatCannotBeMadeFailsTheBackup;
   TestTheGridReadsTheLogAfterABackup;
   TestAClearedLogIsEmptyOnDiskAfterClose;
   TestAClearIsCommittedBeforeTheLogIsClosed;
   TestADeletedQSOStaysDeletedAndIsNotExported;
end;

end.
