(* AN OLDER LOG IS BACKED UP BEFORE IT IS UPGRADED (NY4I, 2026-11-19: "YES,
  opening an older log must take a BACKUP FIRST, before it is migrated").

  TLogDatabase.Open, with BeforeMigration assigned, reads the file's
  user_version on a read-only connection of its own BEFORE its write
  connection exists, and below LOG_SCHEMA_VERSION asks for a verified backup
  first; a False answer refuses the open with the file untouched. The
  program's answer is uLogStore's, over uLogBackup.BackUpLogBeforeUpgrade --
  which these tests call directly, into a scratch folder, NEVER
  uAppPaths.BackupDir. WHAT IS PINNED:

    the real file    a schema-10 log written by the schema-10 build
                     (fixtures/logdb/florida_qp_schema10.db) is upgraded, and
                     a backup named "<log> before schema 10 to <current>.db"
                     holds user_version 10 and every qso row as it was
    a failure        a backup folder that is a FILE refuses the open; the log
                     is byte-identical (MD5) and still schema 10
    current / twice  a current log asks nothing; an upgraded log opened again
                     takes no second backup
    never overwrite  a taken backup name gets a number, and the file already
                     there keeps its bytes
    not ours         a log from a newer build is refused by the read-only
                     probe and is never copied
    the name rule    LogBackupBaseName strips " before schema <n> to <m>" *)
unit uTestLogMigrationBackup;

{$I ..\..\src\tr4w.inc}

interface

uses
   uTR4WTestFramework;

type
   TLogMigrationBackupTests = class(TTestCase)
   private
      FDir: string;
      function ScratchDir(const aLeaf: string): string;
      function StagedFixture(const aDir: string): string;
   protected
      procedure Test_AnOlderLogIsBackedUpBeforeItIsUpgraded;
      procedure Test_AFailedBackupLeavesTheLogUntouched;
      procedure Test_ACurrentLogTakesNoBackup;
      procedure Test_UpgradingOnceTakesOneBackup;
      procedure Test_ATakenBackupNameIsNeverOverwritten;
      procedure Test_ALogFromANewerBuildIsNeverCopied;
      procedure Test_TheSchemaSuffixNeverStacks;
   public
      procedure RunAllTests; override;
   end;

implementation

uses
   SysUtils, Classes, md5, sqldb, sqlite3conn,
   uLogDatabase, uLogSchema, uLogBackup,
   uTestLatestContest,       (* ScrubTestLog *)
   uTestLogDroppedColumns;   (* RowsText, CopyFileBytes *)

const
   FIXTURE_LEAF = 'florida_qp_schema10.db';
   LOG_LEAF = 'florida_qp.db';
   BACKUP_LEAF = 'backup';
   QSO_ROWS_SQL = 'SELECT * FROM qso ORDER BY id';

var
   (* What the test hook writes into, and how often it was asked. *)
   GBackupFolder: string;
   GHookCalls: integer;
   GLastBackupPath: string;

(* THE TEST'S BeforeMigration: the program's backup, into a scratch folder. *)
function BackUpIntoTheScratchFolder(const aFileName: string;
   aFromVersion, aToVersion: integer; out aReport: string): boolean;
begin
   inc(GHookCalls);
   Result := BackUpLogBeforeUpgrade(aFileName, GBackupFolder, aFromVersion,
                                    aToVersion, GLastBackupPath, aReport);
end;

function FileMD5(const aPath: string): string;
begin
   Result := MD5Print(MD5File(aPath));
end;

(* The files in aDir, by name, sorted, '|'-separated. *)
function FilesIn(const aDir: string): string;
var
   found: TSearchRec;
   names: TStringList;
begin
   names := TStringList.Create;
   try
      names.Sorted := True;
      if FindFirst(IncludeTrailingPathDelimiter(aDir) + '*', faAnyFile, found) = 0 then
         begin
         try
            repeat
               if (found.Attr and faDirectory) = 0 then
                  begin
                  names.Add(found.Name);
                  end;
            until FindNext(found) <> 0;
         finally
            FindClose(found);
         end;
         end;
      names.Delimiter := '|';
      names.StrictDelimiter := True;
      Result := names.DelimitedText;
   finally
      names.Free;
   end;
end;

(* user_version and the qso rows of aFile, read without changing it. *)
procedure ReadLog(const aFile: string; out aVersion: integer; out aRows: string);
var
   db: TLogDatabase;
begin
   db := TLogDatabase.Create;
   try
      db.OpenReadOnly(aFile);
      aVersion := db.SchemaVersion;
      aRows := RowsText(db.Connection, QSO_ROWS_SQL);
   finally
      db.Free;
   end;
end;

(* A fresh, empty folder under this run's scratch directory. Only files these
  tests made are removed from it. *)
function TLogMigrationBackupTests.ScratchDir(const aLeaf: string): string;
var
   found: TSearchRec;
begin
   if FDir = '' then
      begin
      FDir := IncludeTrailingPathDelimiter(GetTempDir) +
              'tr4w_migration_backup_' + IntToStr(GetProcessID);
      ForceDirectories(FDir);
      end;
   Result := IncludeTrailingPathDelimiter(FDir) + aLeaf;
   ForceDirectories(Result);
   if FindFirst(IncludeTrailingPathDelimiter(Result) + '*', faAnyFile, found) = 0 then
      begin
      try
         repeat
            if (found.Attr and faDirectory) = 0 then
               begin
               DeleteFile(IncludeTrailingPathDelimiter(Result) + found.Name);
               end;
         until FindNext(found) <> 0;
      finally
         FindClose(found);
      end;
      end;
end;

(* A COPY of the tracked fixture in aDir, as LOG_LEAF -- never the fixture
  itself: TLogDatabase.Open WRITES. *)
function TLogMigrationBackupTests.StagedFixture(const aDir: string): string;
var
   fixture: string;
begin
   fixture := ExtractFilePath(ParamStr(0)) + 'fixtures' + PathDelim +
              'logdb' + PathDelim + FIXTURE_LEAF;
   CheckTrue(FileExists(fixture), 'the schema-10 fixture is beside the tests: ' + fixture);
   Result := IncludeTrailingPathDelimiter(aDir) + LOG_LEAF;
   ScrubTestLog(Result);
   CopyFileBytes(fixture, Result);
end;

procedure TLogMigrationBackupTests.Test_AnOlderLogIsBackedUpBeforeItIsUpgraded;
var
   dir, fn, expected: string;
   db: TLogDatabase;
   rowsBefore, backupRows, ignored: string;
   version, backupVersion: integer;
   why: string;
begin
   BeginTest('an older log is backed up, as it was, before it is upgraded');
   dir := ScratchDir('upgrade');
   fn := StagedFixture(dir);
   GBackupFolder := ScratchDir('upgrade' + PathDelim + BACKUP_LEAF);
   GHookCalls := 0;
   GLastBackupPath := '';

   ReadLog(fn, version, rowsBefore);
   CheckEquals(10, version, 'the fixture is schema 10');
   CheckTrue(rowsBefore <> '', 'the fixture holds QSOs');

   db := TLogDatabase.Create;
   try
      db.BeforeMigration := @BackUpIntoTheScratchFolder;
      db.Open(fn);
      CheckEquals(LOG_SCHEMA_VERSION, db.SchemaVersion, 'the log was upgraded');
   finally
      db.Free;
   end;

   CheckEquals(1, GHookCalls, 'the backup was asked for once');
   expected := IncludeTrailingPathDelimiter(GBackupFolder) + 'florida_qp before schema 10 to ' +
               IntToStr(LOG_SCHEMA_VERSION) + '.db';
   CheckEquals(expected, GLastBackupPath, 'the backup says what it is');
   CheckEquals(ExtractFileName(expected), FilesIn(GBackupFolder),
               'one file in the backup folder: no .new, no .bak, no sidecar');

   ReadLog(expected, backupVersion, backupRows);
   CheckEquals(10, backupVersion, 'the backup is the log as schema 10 left it');
   CheckTrue(backupRows = rowsBefore, 'the backup holds every qso row, unchanged');
   CheckTrue(StagedBackupIsSound(expected, why), 'the backup is sound: ' + why);

   ReadLog(fn, version, ignored);
   CheckEquals(LOG_SCHEMA_VERSION, version, 'the log itself is current');
end;

procedure TLogMigrationBackupTests.Test_AFailedBackupLeavesTheLogUntouched;
var
   dir, fn, before: string;
   db: TLogDatabase;
   raised: boolean;
   said: string;
   version: integer;
   ignored: string;
   blocker: TFileStream;
   raw: TLogConnection;
begin
   BeginTest('a backup that cannot be taken refuses the upgrade and leaves the log as it was');
   dir := ScratchDir('refused');
   fn := StagedFixture(dir);

   (* A FILE where the folder should be: the portable way to make the backup
     fail (the same device uTestLogStore uses for Clear Log). *)
   GBackupFolder := IncludeTrailingPathDelimiter(dir) + BACKUP_LEAF;
   if not FileExists(GBackupFolder) then
      begin
      blocker := TFileStream.Create(GBackupFolder, fmCreate);
      blocker.Free;
      end;
   GHookCalls := 0;

   (* ROLLBACK-JOURNAL MODE FIRST, or the MD5 below pins nothing about the
     order. The fixture is WAL already, so Open's journal_mode = WAL would
     rewrite no header byte of it, and an Open that asked for the backup
     AFTER its write connection would pass. A rollback-journal log (a
     network share) is the case the order protects: its header bytes 18 and
     19 go 1 to 2 the moment the write connection opens. TLogConnection's
     ExecutePragma is transaction-free; SQLite refuses to leave WAL inside a
     transaction. *)
   raw := TLogConnection.Create(nil);
   try
      raw.DatabaseName := UTF8Encode(fn);
      raw.Open;
      raw.ExecutePragma('PRAGMA journal_mode = DELETE');
      raw.Close;
   finally
      raw.Free;
   end;
   CheckEquals('', LogSidecarPresent(fn), 'the staged log has no sidecar before the open');

   before := FileMD5(fn);

   raised := False;
   said := '';
   db := TLogDatabase.Create;
   try
      db.BeforeMigration := @BackUpIntoTheScratchFolder;
      try
         db.Open(fn);
      except
         on E: ELogDatabaseError do
            begin
            raised := True;
            said := E.Message;
            end;
      end;
      CheckFalse(db.IsOpen, 'the refused log is not open');
   finally
      db.Free;
   end;

   CheckTrue(raised, 'the open was refused');
   CheckEquals(1, GHookCalls, 'the backup was asked for');
   CheckTrue(Pos('NOT upgraded', said) > 0, 'the refusal says the log was not upgraded: ' + said);
   CheckTrue(Pos('does not exist', said) > 0, 'and why: ' + said);
   CheckEquals(before, FileMD5(fn), 'the log is byte for byte as it was');
   CheckEquals('', LogSidecarPresent(fn), 'and nothing was left beside it');
   ReadLog(fn, version, ignored);
   CheckEquals(10, version, 'still schema 10');
end;

procedure TLogMigrationBackupTests.Test_ACurrentLogTakesNoBackup;
var
   dir, fn: string;
   db: TLogDatabase;
begin
   BeginTest('a current log asks for no backup');
   dir := ScratchDir('current');
   fn := IncludeTrailingPathDelimiter(dir) + 'current.db';
   ScrubTestLog(fn);
   GBackupFolder := ScratchDir('current' + PathDelim + BACKUP_LEAF);
   GHookCalls := 0;

   db := TLogDatabase.Create;
   try
      db.CreateNew(fn);
   finally
      db.Free;
   end;

   db := TLogDatabase.Create;
   try
      db.BeforeMigration := @BackUpIntoTheScratchFolder;
      db.Open(fn);
   finally
      db.Free;
   end;

   CheckEquals(0, GHookCalls, 'no backup was asked for');
   CheckEquals('', FilesIn(GBackupFolder), 'and none was written');
end;

procedure TLogMigrationBackupTests.Test_UpgradingOnceTakesOneBackup;
var
   dir, fn: string;
   db: TLogDatabase;
   pass: integer;
begin
   BeginTest('an upgraded log opened again takes no second backup');
   dir := ScratchDir('twice');
   fn := StagedFixture(dir);
   GBackupFolder := ScratchDir('twice' + PathDelim + BACKUP_LEAF);
   GHookCalls := 0;

   for pass := 1 to 2 do
      begin
      db := TLogDatabase.Create;
      try
         db.BeforeMigration := @BackUpIntoTheScratchFolder;
         db.Open(fn);
      finally
         db.Free;
      end;
      end;

   CheckEquals(1, GHookCalls, 'asked once, by the open that upgraded');
   CheckEquals('florida_qp before schema 10 to ' + IntToStr(LOG_SCHEMA_VERSION) + '.db',
               FilesIn(GBackupFolder), 'one backup');
end;

procedure TLogMigrationBackupTests.Test_ATakenBackupNameIsNeverOverwritten;
var
   dir, fn, taken, placeholderSum: string;
   db: TLogDatabase;
   placeholder: TStringList;
   version: integer;
   ignored: string;
begin
   BeginTest('a backup name already taken gets a number; the file there is kept');
   dir := ScratchDir('taken');
   fn := StagedFixture(dir);
   GBackupFolder := ScratchDir('taken' + PathDelim + BACKUP_LEAF);
   GHookCalls := 0;

   taken := IncludeTrailingPathDelimiter(GBackupFolder) + 'florida_qp before schema 10 to ' +
            IntToStr(LOG_SCHEMA_VERSION) + '.db';
   placeholder := TStringList.Create;
   try
      placeholder.Add('an earlier backup, not to be touched');
      placeholder.SaveToFile(taken);
   finally
      placeholder.Free;
   end;
   placeholderSum := FileMD5(taken);

   db := TLogDatabase.Create;
   try
      db.BeforeMigration := @BackUpIntoTheScratchFolder;
      db.Open(fn);
   finally
      db.Free;
   end;

   CheckEquals(ChangeFileExt(taken, '') + ' 2.db', GLastBackupPath, 'the next free number');
   CheckEquals(placeholderSum, FileMD5(taken), 'the earlier file is unchanged');
   CheckFalse(FileExists(taken + '.bak'), 'and was not displaced to .bak');
   ReadLog(GLastBackupPath, version, ignored);
   CheckEquals(10, version, 'the numbered file is the backup');
end;

procedure TLogMigrationBackupTests.Test_ALogFromANewerBuildIsNeverCopied;
var
   dir, fn: string;
   raw: TSQLite3Connection;
   trans: TSQLTransaction;
   db: TLogDatabase;
   raised: boolean;
begin
   BeginTest('a log from a newer build is refused before anything is copied');
   dir := ScratchDir('future');
   fn := StagedFixture(dir);
   GBackupFolder := ScratchDir('future' + PathDelim + BACKUP_LEAF);
   GHookCalls := 0;

   (* A raw connection, so the stamp is not itself an upgrade. *)
   raw := TSQLite3Connection.Create(nil);
   trans := TSQLTransaction.Create(nil);
   try
      raw.Transaction := trans;
      raw.DatabaseName := UTF8Encode(fn);
      raw.Open;
      raw.ExecuteDirect(UTF8Encode('PRAGMA user_version = ' + IntToStr(LOG_SCHEMA_VERSION + 1)));
      trans.Commit;
      raw.Close;
   finally
      trans.Free;
      raw.Free;
   end;

   raised := False;
   db := TLogDatabase.Create;
   try
      db.BeforeMigration := @BackUpIntoTheScratchFolder;
      try
         db.Open(fn);
      except
         on E: ELogDatabaseError do
            begin
            raised := True;
            end;
      end;
   finally
      db.Free;
   end;

   CheckTrue(raised, 'refused');
   CheckEquals(0, GHookCalls, 'no backup was asked for');
   CheckEquals('', FilesIn(GBackupFolder), 'nothing was copied');
end;

procedure TLogMigrationBackupTests.Test_TheSchemaSuffixNeverStacks;
begin
   BeginTest('LogBackupBaseName strips the schema suffix, and only its exact shape');
   CheckEquals('X', LogBackupBaseName('X before schema 10 to 12.db'), 'stripped');
   CheckEquals('X', LogBackupBaseName('X before schema 2 to 12 periodic.db'), 'with another suffix');
   CheckEquals('X before schema to 12', LogBackupBaseName('X before schema to 12.db'),
               'no from-version: kept');
   CheckEquals('X before schema 10 to', LogBackupBaseName('X before schema 10 to.db'),
               'no to-version: kept');
   CheckEquals('before schema 1 to 2', LogBackupBaseName('before schema 1 to 2.db'),
               'no leading space: kept');
end;

procedure TLogMigrationBackupTests.RunAllTests;
begin
   Test_AnOlderLogIsBackedUpBeforeItIsUpgraded;
   Test_AFailedBackupLeavesTheLogUntouched;
   Test_ACurrentLogTakesNoBackup;
   Test_UpgradingOnceTakesOneBackup;
   Test_ATakenBackupNameIsNeverOverwritten;
   Test_ALogFromANewerBuildIsNeverCopied;
   Test_TheSchemaSuffixNeverStacks;
end;

end.
