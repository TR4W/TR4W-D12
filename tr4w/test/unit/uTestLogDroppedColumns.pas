(* SIXTEEN UNUSED qso COLUMNS REMOVED -- LOG SCHEMA 11 (issue 94, NY4I,
  2026-11-19: my_* is OUR station and rcvd_* the worked one, and "as long as
  that is consistent, I do not see why we would keep those fields").

  The columns (uLogSchema.LOG_V11_DROPPED_QSO_COLUMNS) were never written or
  read by any build. The migration REBUILDS the table rather than using ALTER
  TABLE DROP COLUMN (see uLogSchema's note on 11 for why). WHAT IS PINNED HERE:

    the real file   a schema-10 log WRITTEN BY THE SCHEMA-10 BUILD
                    (fixtures/logdb/florida_qp_schema10.db: the corpus's
                    florida_qp log, migrated 2 -> 10 by a headless /EXPORT of
                    the 5.0.44 tree, county-line rows sharing a qso_set_id,
                    is_off_contest stamped) is rebuilt in ONE commit: every
                    kept column of every row is unchanged, the sixteen are
                    gone even where a value was written into one, the
                    AUTOINCREMENT high-water mark survives a gap above
                    max(id), the qso table and its indexes are a new log's in
                    sqlite_master, and a second open changes nothing
    refusals        a trigger on qso, or a column this program never made,
                    stops the migration before ANY change: the file reads as
                    it did
    the constants   a new log has none of the sixteen, and LOG_QSO_INDEXES is
                    exactly the qso indexes LOG_SCHEMA_STATEMENTS creates

  The older-schema paths (2 to 9) go through the same rebuild in the suites
  that own them (uTestLogMyFacts, uTestLogReceivedYear, uTestLogYearSent,
  uTestLogStationFacts, uTestLogOffContest), whose fixtures DowngradeTestLog
  now gives the sixteen columns back; and the corpus migrates its thirteen
  schema-2 logs through it on every run. *)
unit uTestLogDroppedColumns;

{$I ..\..\src\tr4w.inc}

interface

uses
   sqldb, uTR4WTestFramework;

(* EVERY FIELD OF EVERY ROW of aSql, as one text: fields by ',', rows by '|',
  NULL as NULL. Also uTestLogMigrationBackup's, to compare a backup's rows
  with the original's. *)
function RowsText(aConnection: TSQLConnection; const aSql: string): string;

(* aSource's bytes into a new aTarget. *)
procedure CopyFileBytes(const aSource, aTarget: string);

type
   TLogDroppedColumnsTests = class(TTestCase)
   private
      FDir: string;
      function TempLogName(const aLeaf: string): string;
      function StagedFixture(const aLeaf: string): string;
   protected
      procedure Test_ANewLogHasNoneOfTheSixteen;
      procedure Test_TheRebuildIndexesAreTheSchemasIndexes;
      procedure Test_ARealSchema10LogIsRebuiltInOneCommit;
      procedure Test_ATriggerOnQsoRefusesTheMigration;
      procedure Test_AColumnWeNeverMadeRefusesTheMigration;
   public
      procedure RunAllTests; override;
   end;

implementation

uses
   SysUtils, Classes, sqlite3conn,
   uLogDatabase, uLogSchema,
   uTestLatestContest,   (* ScrubTestLog, TestLogHasColumn *)
   uTestLogDatabase;     (* CommitFramesInWal *)

const
   FIXTURE_LEAF = 'florida_qp_schema10.db';

   (* The qso table and its indexes as sqlite_master stores them. *)
   QSO_MASTER_SQL = 'SELECT name, sql FROM sqlite_master WHERE tbl_name = ''qso'' ' +
                    'AND sql IS NOT NULL ORDER BY name';

(* EVERY FIELD OF EVERY ROW of aSql, as one text: fields by ',', rows by '|',
  NULL as NULL. Read field by field, NEVER as one group_concat: sqlite3conn
  cuts an expression's text at 255 characters without a word (see
  TLogDatabase.PragmaRowsAsText), and a comparison of two cut texts proves
  nothing. A declared TEXT column is a memo field and is read whole. *)
function RowsText(aConnection: TSQLConnection; const aSql: string): string;
var
   q: TSQLQuery;
   i: integer;
   row: string;
begin
   Result := '';
   q := TSQLQuery.Create(nil);
   try
      q.DataBase := aConnection;
      q.UsePrimaryKeyAsKey := False;
      q.SQL.Text := aSql;
      q.Open;
      while not q.EOF do
         begin
         row := '';
         for i := 0 to q.Fields.Count - 1 do
            begin
            if i > 0 then
               begin
               row := row + ',';
               end;
            if q.Fields[i].IsNull then
               begin
               row := row + 'NULL';
               end
            else
               begin
               row := row + q.Fields[i].AsString;
               end;
            end;
         if Result <> '' then
            begin
            Result := Result + '|';
            end;
         Result := Result + row;
         q.Next;
         end;
      q.Close;
   finally
      q.Free;
   end;
end;

(* The first column of the first row of aSql, as text; '' for none. *)
function ScalarOf(aConnection: TSQLConnection; const aSql: string): string;
var
   q: TSQLQuery;
begin
   Result := '';
   q := TSQLQuery.Create(nil);
   try
      q.DataBase := aConnection;
      q.UsePrimaryKeyAsKey := False;
      q.SQL.Text := aSql;
      q.Open;
      if not q.EOF then
         begin
         Result := q.Fields[0].AsString;
         end;
      q.Close;
   finally
      q.Free;
   end;
end;

(* A CONNECTION THAT IS NOT TLogDatabase, so opening a file does not migrate
  it: the way to change a fixture, or read it, as the build before saw it.
  Rollback-journal mode, as the fixture is, so it leaves no -wal behind. *)
type
   TRawLog = class
   private
      FConnection: TSQLite3Connection;
      FTransaction: TSQLTransaction;
   public
      constructor Create(const aFileName: string);
      destructor Destroy; override;
      procedure Exec(const aSql: string);
      function Scalar(const aSql: string): string;
      function Rows(const aSql: string): string;
      procedure Commit;
   end;

constructor TRawLog.Create(const aFileName: string);
begin
   inherited Create;
   FConnection := TSQLite3Connection.Create(nil);
   FTransaction := TSQLTransaction.Create(nil);
   FConnection.Transaction := FTransaction;
   FTransaction.DataBase := FConnection;
   FConnection.DatabaseName := UTF8Encode(aFileName);
   FConnection.Open;
end;

destructor TRawLog.Destroy;
begin
   if FTransaction.Active then
      begin
      FTransaction.Rollback;
      end;
   FConnection.Close;
   FTransaction.Free;
   FConnection.Free;
   inherited Destroy;
end;

procedure TRawLog.Exec(const aSql: string);
begin
   FConnection.ExecuteDirect(UTF8Encode(aSql));
end;

function TRawLog.Scalar(const aSql: string): string;
begin
   Result := ScalarOf(FConnection, aSql);
end;

function TRawLog.Rows(const aSql: string): string;
begin
   Result := RowsText(FConnection, aSql);
end;

procedure TRawLog.Commit;
begin
   FTransaction.Commit;
end;

procedure CopyFileBytes(const aSource, aTarget: string);
var
   source, target: TFileStream;
begin
   source := TFileStream.Create(aSource, fmOpenRead or fmShareDenyWrite);
   try
      target := TFileStream.Create(aTarget, fmCreate);
      try
         target.CopyFrom(source, 0);
      finally
         target.Free;
      end;
   finally
      source.Free;
   end;
end;

const
   QSO_COLUMNS_SQL = 'SELECT name FROM pragma_table_info(''qso'') ORDER BY cid';

(* The columns of qso in a NEW log, in order, '|'-separated (RowsText). *)
function NewLogQsoColumns(const aFileName: string): string;
var
   db: TLogDatabase;
begin
   ScrubTestLog(aFileName);
   db := TLogDatabase.Create;
   try
      db.CreateNew(aFileName);
      Result := RowsText(db.Connection, QSO_COLUMNS_SQL);
   finally
      db.Free;
   end;
end;

(* EVERY ROW, EVERY ONE OF aColumns ('|'-separated) -- read through RowsText,
  the whole content of what the rebuild keeps, as one comparable text. *)
function QsoContentSql(const aColumns: string): string;
begin
   Result := 'SELECT "' + StringReplace(aColumns, '|', '", "', [rfReplaceAll]) +
             '" FROM qso ORDER BY id';
end;

function TLogDroppedColumnsTests.TempLogName(const aLeaf: string): string;
begin
   if FDir = '' then
      begin
      FDir := IncludeTrailingPathDelimiter(GetTempDir) +
              'tr4w_dropped_' + IntToStr(GetProcessID);
      ForceDirectories(FDir);
      end;
   Result := IncludeTrailingPathDelimiter(FDir) + aLeaf;
   ScrubTestLog(Result);
end;

(* A COPY of the tracked fixture under aLeaf -- never the fixture itself:
  TLogDatabase.Open WRITES. PathDelim, not a backslash (see uTestLogImport). *)
function TLogDroppedColumnsTests.StagedFixture(const aLeaf: string): string;
var
   fixture: string;
begin
   fixture := ExtractFilePath(ParamStr(0)) + 'fixtures' + PathDelim +
              'logdb' + PathDelim + FIXTURE_LEAF;
   CheckTrue(FileExists(fixture), 'the schema-10 fixture is beside the tests: ' + fixture);
   Result := TempLogName(aLeaf);
   CopyFileBytes(fixture, Result);
end;

procedure TLogDroppedColumnsTests.Test_ANewLogHasNoneOfTheSixteen;
var
   fn: string;
   db: TLogDatabase;
   i: integer;
begin
   BeginTest('a new log has none of the sixteen removed columns');
   fn := TempLogName('new.db');
   db := TLogDatabase.Create;
   try
      db.CreateNew(fn);
      CheckEquals(LOG_SCHEMA_VERSION, db.SchemaVersion, 'a new log is stamped current');
      for i := Low(LOG_V11_DROPPED_QSO_COLUMNS) to High(LOG_V11_DROPPED_QSO_COLUMNS) do
         begin
         CheckFalse(TestLogHasColumn(db, 'qso', string(LOG_V11_DROPPED_QSO_COLUMNS[i].Name)),
                    string(LOG_V11_DROPPED_QSO_COLUMNS[i].Name) + ' is not in a new log');
         end;
      (* What replaced them, and what is NOT one of them. *)
      CheckTrue(TestLogHasColumn(db, 'qso', 'rcvd_qth'), 'a received QTH of any kind is rcvd_qth');
      CheckTrue(TestLogHasColumn(db, 'qso', 'rcvd_year'), 'rcvd_year is written and read: kept');
      CheckTrue(TestLogHasColumn(db, 'qso', 'cty_cq_zone'), 'the CQ zone CTY.DAT gave is kept');
   finally
      db.Free;
   end;
   ScrubTestLog(fn);
end;

(* THE REBUILD PUTS BACK EXACTLY THE INDEXES A NEW LOG HAS. LOG_QSO_INDEXES
  names the same constants LOG_SCHEMA_STATEMENTS runs; this pins that no
  index on qso is created by the one and missed by the other. *)
procedure TLogDroppedColumnsTests.Test_TheRebuildIndexesAreTheSchemasIndexes;
var
   i, j: integer;
   found: boolean;
   onQso: integer;
begin
   BeginTest('LOG_QSO_INDEXES is every qso index the schema creates, and only those');
   onQso := 0;
   for i := Low(LOG_SCHEMA_STATEMENTS) to High(LOG_SCHEMA_STATEMENTS) do
      begin
      if (Pos('CREATE INDEX', string(LOG_SCHEMA_STATEMENTS[i])) = 1) and
         (Pos(' ON qso(', string(LOG_SCHEMA_STATEMENTS[i])) > 0) then
         begin
         Inc(onQso);
         found := False;
         for j := Low(LOG_QSO_INDEXES) to High(LOG_QSO_INDEXES) do
            begin
            if LOG_QSO_INDEXES[j] = LOG_SCHEMA_STATEMENTS[i] then
               begin
               found := True;
               end;
            end;
         CheckTrue(found, 'the rebuild recreates: ' + string(LOG_SCHEMA_STATEMENTS[i]));
         end;
      end;
   CheckEquals(Length(LOG_QSO_INDEXES), onQso, 'and recreates nothing the schema does not');

   found := False;
   for i := Low(LOG_SCHEMA_STATEMENTS) to High(LOG_SCHEMA_STATEMENTS) do
      begin
      if LOG_SCHEMA_STATEMENTS[i] = LOG_QSO_TABLE then
         begin
         found := True;
         end;
      end;
   CheckTrue(found, 'a new log and the rebuild create qso from the one text');
end;

(* THE REAL SCHEMA-10 FILE. Before the open, through a connection that does
  not migrate: a value written into two of the sixteen (so the removal is
  proved, not assumed from an all-NULL column), and the AUTOINCREMENT mark
  raised above max(id), as Clear Log or a deleted last row leaves it. *)
procedure TLogDroppedColumnsTests.Test_ARealSchema10LogIsRebuiltInOneCommit;
var
   fn, freshFn: string;
   raw: TRawLog;
   db: TLogDatabase;
   keptColumns, contentColumns, contentBefore, freshMaster: string;
   i: integer;
begin
   BeginTest('a real schema-10 log is rebuilt without the sixteen, in one commit');
   freshFn := TempLogName('fresh.db');
   keptColumns := NewLogQsoColumns(freshFn);
   (* THE FIXTURE'S OWN COLUMNS: a new log's, less what came after schema 11
     (schema 12's my_rover_qth, the last) -- the fixture has none of it to
     compare, and the migration leaves it NULL. *)
   contentColumns := StringReplace(keptColumns, '|' + string(LOG_V12_QSO_ROVER_QTH_COLUMN.Name),
                                   '', []);
   db := TLogDatabase.Create;
   try
      db.OpenReadOnly(freshFn);
      freshMaster := RowsText(db.Connection, QSO_MASTER_SQL);
   finally
      db.Free;
   end;
   ScrubTestLog(freshFn);
   CheckTrue(Pos('idx_qso_unsent_udp', freshMaster) > 0,
             'precondition: the new log''s qso text and indexes were read whole');

   fn := StagedFixture('florida10.db');
   raw := TRawLog.Create(fn);
   try
      CheckEquals('10', raw.Scalar('PRAGMA user_version'), 'precondition: the fixture is schema 10');
      CheckEquals('5', raw.Scalar('SELECT count(id) FROM qso'), 'precondition: five rows');
      CheckEquals('2', raw.Scalar('SELECT count(id) FROM qso WHERE qso_set_id = ' +
                                  '(SELECT qso_set_id FROM qso WHERE id = 1)'),
                  'precondition: a county-line pair shares a qso_set_id');
      raw.Exec('UPDATE qso SET rcvd_state = ''FL'', cty_itu_zone = 8 WHERE id = 1');
      raw.Exec('UPDATE sqlite_sequence SET seq = 50 WHERE name = ''qso''');
      raw.Commit;
      contentBefore := raw.Rows(QsoContentSql(contentColumns));
      CheckEquals('1|1|0|0|0', raw.Rows('SELECT is_off_contest FROM qso ORDER BY id'),
                  'precondition: the schema-10 build stamped the county-line pair');
   finally
      raw.Free;
   end;
   CheckEquals(4, Length(contentBefore) - Length(StringReplace(contentBefore, '|', '', [rfReplaceAll])),
               'precondition: all five rows were read');
   CheckFalse(FileExists(fn + '-wal'), 'precondition: no WAL beside the fixture');

   db := TLogDatabase.Create;
   try
      db.Open(fn);
      CheckEquals(1, CommitFramesInWal(fn + '-wal'),
                  'the rebuild and the stamp: ONE commit');
      CheckEquals(LOG_SCHEMA_VERSION, db.SchemaVersion, 'stamped current');
      for i := Low(LOG_V11_DROPPED_QSO_COLUMNS) to High(LOG_V11_DROPPED_QSO_COLUMNS) do
         begin
         CheckFalse(TestLogHasColumn(db, 'qso', string(LOG_V11_DROPPED_QSO_COLUMNS[i].Name)),
                    string(LOG_V11_DROPPED_QSO_COLUMNS[i].Name) + ' is gone');
         end;
      CheckEquals(keptColumns, RowsText(db.Connection, QSO_COLUMNS_SQL),
                  'the columns are a new log''s, in its order');
      CheckEquals(contentBefore, RowsText(db.Connection, QsoContentSql(contentColumns)),
                  'every kept column of every row is as it was');
      CheckEquals('1|1|0|0|0', RowsText(db.Connection, 'SELECT is_off_contest FROM qso ORDER BY id'),
                  'the stored rule, the LAST column, came across');
      CheckEquals('50', ScalarOf(db.Connection,
                                 'SELECT seq FROM sqlite_sequence WHERE name = ''qso'''),
                  'the AUTOINCREMENT mark survives: no id is handed out twice');
      CheckEquals('', ScalarOf(db.Connection,
                               'SELECT name FROM sqlite_sequence WHERE name <> ''qso'''),
                  'and the old table left no sequence row behind');
      CheckEquals(freshMaster, RowsText(db.Connection, QSO_MASTER_SQL),
                  'the qso table and its indexes are a new log''s, text for text');
      CheckEquals('ok', ScalarOf(db.Connection, 'PRAGMA integrity_check'), 'integrity');
      CheckEquals('', ScalarOf(db.Connection, 'PRAGMA foreign_key_check'), 'foreign keys');
   finally
      db.Free;
   end;

   (* A SECOND OPEN: current, nothing rebuilt again. *)
   db := TLogDatabase.Create;
   try
      db.Open(fn);
      CheckEquals(0, CommitFramesInWal(fn + '-wal'), 'a second open commits nothing');
      CheckEquals(LOG_SCHEMA_VERSION, db.SchemaVersion, 'still current');
      CheckEquals(contentBefore, RowsText(db.Connection, QsoContentSql(contentColumns)),
                  'and the content is untouched');
   finally
      db.Free;
   end;
   ScrubTestLog(fn);
end;

(* A TRIGGER ON qso WOULD BE DROPPED WITH THE OLD TABLE. This program makes
  none, so one in the file is not its to destroy: the open is refused, and
  nothing about the file changed. *)
procedure TLogDroppedColumnsTests.Test_ATriggerOnQsoRefusesTheMigration;
var
   fn: string;
   raw: TRawLog;
   db: TLogDatabase;
   refused: boolean;
begin
   BeginTest('a trigger on qso refuses the schema-11 rebuild, changing nothing');
   fn := StagedFixture('trigger10.db');
   raw := TRawLog.Create(fn);
   try
      raw.Exec('CREATE TRIGGER someone_elses AFTER INSERT ON qso BEGIN SELECT 1; END');
      raw.Commit;
   finally
      raw.Free;
   end;

   refused := False;
   db := TLogDatabase.Create;
   try
      try
         db.Open(fn);
      except
         on E: ELogDatabaseError do
            begin
            refused := Pos('trigger someone_elses', E.Message) > 0;
            end;
      end;
   finally
      db.Free;
   end;
   CheckTrue(refused, 'refused, and the message names the trigger');

   raw := TRawLog.Create(fn);
   try
      CheckEquals('10', raw.Scalar('PRAGMA user_version'), 'still schema 10');
      CheckEquals('rcvd_state', raw.Scalar('SELECT name FROM pragma_table_info(''qso'') ' +
                                           'WHERE name = ''rcvd_state'''),
                  'the columns are all still there');
      CheckEquals('someone_elses', raw.Scalar('SELECT name FROM sqlite_master WHERE type = ''trigger'''),
                  'and so is the trigger');
   finally
      raw.Free;
   end;
   ScrubTestLog(fn);
end;

(* A COLUMN THIS PROGRAM NEVER MADE is not one of the sixteen, and the new
  table has nowhere to put it: the copy names it, fails, and the whole
  migration rolls back -- never a silent loss of someone's data. *)
procedure TLogDroppedColumnsTests.Test_AColumnWeNeverMadeRefusesTheMigration;
var
   fn: string;
   raw: TRawLog;
   db: TLogDatabase;
   refused: boolean;
begin
   BeginTest('a column this program never made fails the rebuild whole');
   fn := StagedFixture('foreign10.db');
   raw := TRawLog.Create(fn);
   try
      raw.Exec('ALTER TABLE qso ADD COLUMN someone_elses TEXT');
      raw.Exec('UPDATE qso SET someone_elses = ''keep me''');
      raw.Commit;
   finally
      raw.Free;
   end;

   refused := False;
   db := TLogDatabase.Create;
   try
      try
         db.Open(fn);
      except
         on E: Exception do
            begin
            refused := True;
            end;
      end;
   finally
      db.Free;
   end;
   CheckTrue(refused, 'the open is refused');

   raw := TRawLog.Create(fn);
   try
      CheckEquals('10', raw.Scalar('PRAGMA user_version'), 'still schema 10');
      CheckEquals('qso', raw.Scalar('SELECT name FROM sqlite_master WHERE name LIKE ''qso%'' ' +
                                    'AND type = ''table'''),
                  'one qso table, under its own name');
      CheckEquals('5', raw.Scalar('SELECT count(id) FROM qso WHERE someone_elses = ''keep me'''),
                  'and the column, with its values, is still there');
      CheckEquals('rcvd_state', raw.Scalar('SELECT name FROM pragma_table_info(''qso'') ' +
                                           'WHERE name = ''rcvd_state'''),
                  'as are the sixteen');
   finally
      raw.Free;
   end;
   ScrubTestLog(fn);
end;

procedure TLogDroppedColumnsTests.RunAllTests;
begin
   Test_ANewLogHasNoneOfTheSixteen;
   Test_TheRebuildIndexesAreTheSchemasIndexes;
   Test_ARealSchema10LogIsRebuiltInOneCommit;
   Test_ATriggerOnQsoRefusesTheMigration;
   Test_AColumnWeNeverMadeRefusesTheMigration;
end;

end.
