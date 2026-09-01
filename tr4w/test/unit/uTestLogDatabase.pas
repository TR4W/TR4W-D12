unit uTestLogDatabase;

(* THE CONTEST LOG DATABASE -- the first tests in TR4W that touch SQLite.

  These are REAL DATABASES, created in a temporary directory and deleted again,
  not mocks.  The thing worth testing here is whether our schema and our
  lifecycle survive contact with SQLite, and a mock would test neither.  They
  cost a few milliseconds each.

  IF THIS SUITE FAILS WITH "cannot open" AND NOTHING ELSE DOES, look for
  sqlite3.dll beside the test executable.  FPC's binding is dynamic, so a
  missing library is a run-time failure -- which is the whole reason
  DiagnoseSQLiteLoad exists, and why the architecture tests below run against
  real files rather than a contrived one. *)

{$I ..\..\src\tr4w.inc}

interface

uses
   uTR4WTestFramework;

type
   TLogDatabaseTests = class(TTestCase)
   private
      FDir: string;
      function TempLogName(const aLeaf: string): string;
      procedure Scrub(const aFileName: string);
   protected
      (* lifecycle *)
      procedure TestCreateNewMakesAFile;
      procedure TestCreateNewRefusesToClobber;
      procedure TestOpenRefusesAMissingFile;
      procedure TestReopenKeepsSchemaVersion;
      procedure TestCloseThenIsOpenIsFalse;

      (* the schema itself *)
      procedure TestEveryTableIsCreated;
      procedure TestQsoCarriesTheEventSourceColumns;
      procedure TestQsoCarriesEveryCrosswalkColumn;
      procedure TestConfigIsKeyValueAndRoundTrips;
      procedure TestMessageIsKeyedByKindModeAndKey;
      procedure TestDupeIndexExists;

      (* file identity *)
      procedure TestConnectionPragmasActuallyApply;
      procedure TestApplicationIdIsStamped;
      procedure TestForeignDatabaseIsRefused;
      procedure TestNewerSchemaIsRefused;

      (* integrity *)
      procedure TestIntegrityPassesOnAFreshLog;
      procedure TestIntegrityReportsAClosedLog;

      (* the leaf helpers *)
      procedure TestPEArchitectureOfTheSQLiteDLL;
      procedure TestPEArchitectureOfSomethingThatIsNotPE;
      procedure TestPEArchitectureOfAMissingFile;
      procedure TestDiagnosisNamesAMissingLibrary;
   public
      procedure RunAllTests; override;
   end;

implementation

uses
   SysUtils, Classes, sqldb, uLogDatabase, uLogSchema;

function TLogDatabaseTests.TempLogName(const aLeaf: string): string;
begin
   if FDir = '' then
      begin
      FDir := IncludeTrailingPathDelimiter(GetTempDir) +
              'tr4w_logdb_' + IntToStr(GetProcessID);
      ForceDirectories(FDir);
      end;
   Result := IncludeTrailingPathDelimiter(FDir) + aLeaf;
end;

(* WAL leaves -wal and -shm beside the database. A test that deleted only the
  .db would leave those behind and the NEXT run would open a database whose
  write-ahead log belongs to a file that no longer exists. *)
procedure TLogDatabaseTests.Scrub(const aFileName: string);
begin
   if FileExists(aFileName) then
      begin
      DeleteFile(aFileName);
      end;
   if FileExists(aFileName + '-wal') then
      begin
      DeleteFile(aFileName + '-wal');
      end;
   if FileExists(aFileName + '-shm') then
      begin
      DeleteFile(aFileName + '-shm');
      end;
end;

(* ---------------------------------------------------------------------------
  lifecycle
  --------------------------------------------------------------------------- *)

procedure TLogDatabaseTests.TestCreateNewMakesAFile;
var
   db: TLogDatabase;
   fn: string;
begin
   BeginTest('TestCreateNewMakesAFile');
   fn := TempLogName('create.db');
   Scrub(fn);

   db := TLogDatabase.Create;
   try
      db.CreateNew(fn);
      CheckTrue(db.IsOpen, 'a newly created log is open');
      CheckEquals(LOG_SCHEMA_VERSION, db.SchemaVersion,
                  'a new log carries the current schema version');
      CheckEquals(fn, db.FileName, 'the log remembers its own name');
   finally
      db.Free;
   end;

   CheckTrue(FileExists(fn), 'the database file exists on disk');
   Scrub(fn);
end;

procedure TLogDatabaseTests.TestCreateNewRefusesToClobber;
var
   db: TLogDatabase;
   fn: string;
   refused: boolean;
begin
   BeginTest('TestCreateNewRefusesToClobber');
   fn := TempLogName('clobber.db');
   Scrub(fn);

   db := TLogDatabase.Create;
   try
      db.CreateNew(fn);
   finally
      db.Free;
   end;

   (* THE CASE THAT MATTERS. A contest log is the operator's only copy of a
     weekend; "create" must not be a silent truncate. *)
   refused := False;
   db := TLogDatabase.Create;
   try
      try
         db.CreateNew(fn);
      except
         on E: ELogDatabaseError do
            begin
            refused := True;
            end;
      end;
   finally
      db.Free;
   end;

   CheckTrue(refused, 'creating over an existing log is refused');
   CheckTrue(FileExists(fn), 'and the existing log is still there');
   Scrub(fn);
end;

procedure TLogDatabaseTests.TestOpenRefusesAMissingFile;
var
   db: TLogDatabase;
   fn: string;
   refused: boolean;
begin
   BeginTest('TestOpenRefusesAMissingFile');
   fn := TempLogName('nosuch.db');
   Scrub(fn);

   refused := False;
   db := TLogDatabase.Create;
   try
      try
         db.Open(fn);
      except
         on E: ELogDatabaseError do
            begin
            refused := True;
            end;
      end;
   finally
      db.Free;
   end;

   (* SQLite would happily CREATE this file. An empty log that opens cleanly is
     worse than an error, because it looks like the contest was lost. *)
   CheckTrue(refused, 'opening a log that does not exist is refused');
   CheckFalse(FileExists(fn), 'and nothing was created by trying');
end;

procedure TLogDatabaseTests.TestReopenKeepsSchemaVersion;
var
   db: TLogDatabase;
   fn: string;
begin
   BeginTest('TestReopenKeepsSchemaVersion');
   fn := TempLogName('reopen.db');
   Scrub(fn);

   db := TLogDatabase.Create;
   try
      db.CreateNew(fn);
   finally
      db.Free;
   end;

   db := TLogDatabase.Create;
   try
      db.Open(fn);
      CheckTrue(db.IsOpen, 'an existing log reopens');
      CheckEquals(LOG_SCHEMA_VERSION, db.SchemaVersion,
                  'the schema version survives a close and reopen');
   finally
      db.Free;
   end;

   Scrub(fn);
end;

procedure TLogDatabaseTests.TestCloseThenIsOpenIsFalse;
var
   db: TLogDatabase;
   fn: string;
begin
   BeginTest('TestCloseThenIsOpenIsFalse');
   fn := TempLogName('close.db');
   Scrub(fn);

   db := TLogDatabase.Create;
   try
      db.CreateNew(fn);
      db.Close;
      CheckFalse(db.IsOpen, 'a closed log is not open');
      CheckEquals('', db.FileName, 'and it has forgotten its file name');
      CheckEquals(0, db.SchemaVersion,
                  'the version of a closed log is 0, not the last one read');
   finally
      db.Free;
   end;

   Scrub(fn);
end;

(* ---------------------------------------------------------------------------
  the schema
  --------------------------------------------------------------------------- *)

procedure TLogDatabaseTests.TestEveryTableIsCreated;
var
   db: TLogDatabase;
   q: TSQLQuery;
   fn: string;
   found: string;
begin
   BeginTest('TestEveryTableIsCreated');
   fn := TempLogName('tables.db');
   Scrub(fn);

   db := TLogDatabase.Create;
   try
      db.CreateNew(fn);

      q := TSQLQuery.Create(nil);
      try
         q.DataBase := db.Connection;
         q.SQL.Text := 'SELECT name FROM sqlite_master WHERE type = ''table'' ' +
                       'AND name NOT LIKE ''sqlite_%'' ORDER BY name';
         q.Open;
         found := '';
         while not q.EOF do
            begin
            found := found + q.Fields[0].AsString + ' ';
            q.Next;
            end;
         q.Close;
      finally
         q.Free;
      end;
   finally
      db.Free;
   end;

   (* EXHAUSTIVE AND IN ORDER, so a table added without a thought about this
     suite fails here rather than being noticed a release later. The contest
     .cfg moving into the log (NY4I, 2026-09-01) is why config and message are
     on this list. *)
   CheckEquals('config contest message qso ', found,
               'the log holds exactly the four tables the schema declares');
   Scrub(fn);
end;

procedure TLogDatabaseTests.TestQsoCarriesTheEventSourceColumns;
var
   db: TLogDatabase;
   q: TSQLQuery;
   fn: string;
   cols: string;
begin
   BeginTest('TestQsoCarriesTheEventSourceColumns');
   fn := TempLogName('cols.db');
   Scrub(fn);

   db := TLogDatabase.Create;
   try
      db.CreateNew(fn);
      q := TSQLQuery.Create(nil);
      try
         q.DataBase := db.Connection;
         q.SQL.Text := 'SELECT name FROM pragma_table_info(''qso'')';
         q.Open;
         cols := '';
         while not q.EOF do
            begin
            cols := cols + '|' + q.Fields[0].AsString;
            q.Next;
            end;
         q.Close;
      finally
         q.Free;
      end;
   finally
      db.Free;
   end;

   (* THE COLUMNS THAT EXIST BECAUSE OF ISSUE #2, pinned by name. Two of the four
     corpus known-divergences are the absence of exactly this -- the sent
     exchange being rebuilt from station globals at export time instead of being
     stored. If one of these is ever quietly dropped, the corpus would go green
     for the wrong reason. *)
   CheckTrue(Pos('|exchange_sent', cols) > 0,
             'the qso row stores what was SENT, verbatim');
   CheckTrue(Pos('|exchange_received', cols) > 0,
             'and what was COPIED, verbatim');

   (* Tier 3 -- the only things that can change WITHIN one log, a rover. *)
   CheckTrue(Pos('|my_grid', cols) > 0, 'my grid is per QSO, not per contest');
   CheckTrue(Pos('|my_state', cols) > 0, 'my state is per QSO');
   CheckTrue(Pos('|my_county', cols) > 0, 'my county is per QSO');

   (* The copied/derived split -- 4a. Both must exist or the rule that one
     outranks the other has nothing to rank. *)
   CheckTrue(Pos('|rcvd_zone', cols) > 0, 'the zone he SENT');
   CheckTrue(Pos('|cty_cq_zone', cols) > 0, 'and the zone CTY.DAT guessed');
   CheckTrue(Pos('|cty_itu_zone', cols) > 0, 'both zones, separately');

   (* Split working is not an edge case in a contest. *)
   CheckTrue(Pos('|freq_rx_hz', cols) > 0, 'a split QSO has two frequencies');
   Scrub(fn);
end;

(* EVERY COLUMN docs\CONTEST_EXCHANGE_CROSSWALK.md ADDED, pinned by name.

  The crosswalk exists because a ContestExchange field with no column is a
  silent data loss that no build and no test would report -- the import simply
  would not carry it. This is the other half of that guard: a column that
  quietly stops existing fails HERE rather than on somebody's contest log.

  Grouped in the order the crosswalk argues them, so a failure says which
  finding was undone. *)
procedure TLogDatabaseTests.TestQsoCarriesEveryCrosswalkColumn;
var
   db: TLogDatabase;
   q: TSQLQuery;
   fn: string;
   cols: string;

   procedure Pin(const aColumn: AnsiString; const aWhy: string);
   begin
      CheckTrue(Pos('|' + string(aColumn) + '|', cols) > 0, string(aColumn) + ' -- ' + aWhy);
   end;

begin
   BeginTest('TestQsoCarriesEveryCrosswalkColumn');
   fn := TempLogName('crosswalk.db');
   Scrub(fn);

   db := TLogDatabase.Create;
   try
      db.CreateNew(fn);
      q := TSQLQuery.Create(nil);
      try
         q.DataBase := db.Connection;
         q.SQL.Text := 'SELECT name FROM pragma_table_info(''qso'')';
         q.Open;
         cols := '|';
         while not q.EOF do
            begin
            cols := cols + q.Fields[0].AsString + '|';
            q.Next;
            end;
         q.Close;
      finally
         q.Free;
      end;
   finally
      db.Free;
   end;

   (* Identity. The pair is how two stations agree that two rows are the same
     contact, and computer_id is how a station knows which QSOs are its own. *)
   Pin('exchange_id',      'ContestExchange.id -- the EXCHANGE, shared by county-line QSOs');

   (* Split, stated rather than inferred (NY4I, 2026-09-01). freq_rx_hz is NOT
     NULL and equals freq_tx_hz when not split, so "what was I receiving on"
     needs no knowledge of split at all -- and NULL keeps its one meaning
     instead of standing for both "same as tx" and "not known". *)
   Pin('freq_rx_hz',       'always populated -- equals tx when not split');
   Pin('is_split',         'stated, not inferred from a NULL rx frequency');
   Pin('session_id',       'ceQSOID1 -- half the multi-op network identity');
   Pin('session_seq',      'ceQSOID2 -- the other half, and the WAE QTC link');
   Pin('computer_id',      'ceComputerID -- which station logged it');
   Pin('operator_id',      'ceOperatorID -- no live reader, kept for import fidelity');
   Pin('record_kind',      'ceRecordKind -- a log record is not always a QSO');

   (* The two states that are NOT deleted, and are not each other. *)
   Pin('is_xqso',          'ceXQSO -- kept for NIL protection, not claimed');
   Pin('is_skipped',       'ceQSO_Skiped -- read by the scoring paths');

   (* Multiplier outcome, per QSO. Not the multipliers TABLE, which stays out. *)
   Pin('mult_domestic',    'DomesticMult');
   Pin('mult_dx',          'DXMult');
   Pin('mult_prefix',      'PrefixMult');
   Pin('mult_zone',        'ZoneMult');
   Pin('inhibit_mults',    'InhibitMults');
   Pin('prefix_mult',      'the WPX prefix -- NOT dxcc_prefix from CTY.DAT');
   Pin('dx_mult',          'DXQTH as counted');
   Pin('domestic_mult',    'DomMultQTH as counted');
   Pin('domestic_qth',     'the CORRECTED QTH -- AF1 becomes AF-001');

   (* The overloaded field, split. *)
   Pin('rcvd_kids',        'Kids for rkQSO');
   Pin('qtc_call',         'Kids for rkQTCR/rkQTCS -- a callsign, not exchange text');

   (* The rest. *)
   Pin('sent_in_qtc',      'ceWasSendInQTC -- or the QSO goes out twice');
   Pin('name_sent',        'NameSent');
   Pin('mp3_recorded',     'MP3Record -- an MP3 exists on disk');
   Pin('clear_dupe_sheet', 'ceClearDupeSheet -- a stream marker, not UI state');
   Pin('clear_mult_sheet', 'ceClearMultSheet -- likewise');
   Pin('random_sent',      'RandomCharsSent -- the received side already had one');
   Pin('standard_call',    'QTH.StandardCall -- the resolved call');

   Scrub(fn);
end;

procedure TLogDatabaseTests.TestConfigIsKeyValueAndRoundTrips;
var
   db: TLogDatabase;
   q: TSQLQuery;
   fn: string;
   value: string;
   source: string;
begin
   BeginTest('TestConfigIsKeyValueAndRoundTrips');
   fn := TempLogName('config.db');
   Scrub(fn);

   db := TLogDatabase.Create;
   try
      db.CreateNew(fn);

      (* The commands a real contest .cfg carries. All five of these are crC: 0
        in CFGCA -- SaveNewContest does not write them -- and all five appear in
        the shipped "Idaho QSO Party.cfg". That is why config is key/value over
        the whole command namespace and not 29 columns. *)
      db.Connection.ExecuteDirect(
         'INSERT INTO config (command, value, source) VALUES ' +
         '(''EXCHANGE RECEIVED'', ''RST DOMESTIC OR DX QTH'', ''contest''),' +
         '(''DOMESTIC MULTIPLIER'', ''DOMESTIC FILE'', ''contest''),' +
         '(''QSO POINT METHOD'', ''ONE PHONE TWO CW'', ''contest''),' +
         '(''MULT BY BAND'', ''FALSE'', ''contest''),' +
         '(''LEADING ZEROS'', ''TRUE'', ''contest'')');
      db.Transaction.Commit;

      q := TSQLQuery.Create(nil);
      try
         q.DataBase := db.Connection;
         q.SQL.Text := 'SELECT value, source FROM config WHERE command = :c';
         q.ParamByName('c').AsString := 'QSO POINT METHOD';
         q.Open;
         value := q.Fields[0].AsString;
         source := q.Fields[1].AsString;
         q.Close;
      finally
         q.Free;
      end;
   finally
      db.Free;
   end;

   CheckEquals('ONE PHONE TWO CW', value,
               'a contest command round-trips through config');
   (* The precedence signal. With no .cfg file left there is nothing else to tell
     a contest setting from a station default. *)
   CheckEquals('contest', source, 'and it records that the CONTEST set it');
   Scrub(fn);
end;

procedure TLogDatabaseTests.TestMessageIsKeyedByKindModeAndKey;
var
   db: TLogDatabase;
   q: TSQLQuery;
   fn: string;
   cw: string;
   phone: string;
   collided: boolean;
begin
   BeginTest('TestMessageIsKeyedByKindModeAndKey');
   fn := TempLogName('messages.db');
   Scrub(fn);

   db := TLogDatabase.Create;
   try
      db.CreateNew(fn);

      (* CQMemory and EXMemory are array[CW..Phone, F1..AltF12] (LogCW.pas:56),
        so the same function key holds four different things. The primary key
        has to carry all three or Alt-P silently loses three quarters of them. *)
      db.Connection.ExecuteDirect(
         'INSERT INTO message (kind, mode, key_id, text) VALUES ' +
         '(''CQ'', ''CW'',    ''F1'', ''CQ TEST \  \ TEST''),' +
         '(''CQ'', ''PHONE'', ''F1'', ''CQ CONTEST''),' +
         '(''EX'', ''CW'',    ''F1'', ''5NN''),' +
         '(''EX'', ''PHONE'', ''F1'', ''59'')');
      db.Transaction.Commit;

      q := TSQLQuery.Create(nil);
      try
         q.DataBase := db.Connection;
         q.SQL.Text := 'SELECT text FROM message WHERE kind = ''CQ'' ' +
                       'AND mode = :m AND key_id = ''F1''';
         q.ParamByName('m').AsString := 'CW';
         q.Open;
         cw := q.Fields[0].AsString;
         q.Close;
         q.ParamByName('m').AsString := 'PHONE';
         q.Open;
         phone := q.Fields[0].AsString;
         q.Close;
      finally
         q.Free;
      end;

      (* The key really is composite -- prove it by collision rather than by
        reading the DDL back. *)
      collided := False;
      try
         db.Connection.ExecuteDirect(
            'INSERT INTO message (kind, mode, key_id, text) VALUES ' +
            '(''CQ'', ''CW'', ''F1'', ''a second CW F1'')');
         db.Transaction.Commit;
      except
         on E: Exception do
            begin
            collided := True;
            end;
      end;
   finally
      db.Free;
   end;

   CheckEquals('CQ TEST \  \ TEST', cw, 'the CW CQ memory for F1');
   CheckEquals('CQ CONTEST', phone, 'and the PHONE one, which is a different message');
   CheckTrue(collided, 'one message per (kind, mode, key)');
   Scrub(fn);
end;

procedure TLogDatabaseTests.TestDupeIndexExists;
var
   db: TLogDatabase;
   q: TSQLQuery;
   fn: string;
   n: integer;
begin
   BeginTest('TestDupeIndexExists');
   fn := TempLogName('index.db');
   Scrub(fn);

   db := TLogDatabase.Create;
   try
      db.CreateNew(fn);
      q := TSQLQuery.Create(nil);
      try
         q.DataBase := db.Connection;
         q.SQL.Text := 'SELECT COUNT(*) FROM sqlite_master ' +
                       'WHERE type = ''index'' AND name = ''idx_qso_dupe''';
         q.Open;
         n := q.Fields[0].AsInteger;
         q.Close;
      finally
         q.Free;
      end;
   finally
      db.Free;
   end;

   (* The dupe check runs on every keystroke. Section 9a says "no cache" on the
     strength of this index existing, so the index is load-bearing for a
     DESIGN decision, not only for speed. *)
   CheckEquals(1, n, 'the dupe check has its partial index');
   Scrub(fn);
end;

(* ---------------------------------------------------------------------------
  file identity
  --------------------------------------------------------------------------- *)

(* THE THREE CONNECTION-LEVEL PRAGMAS, READ BACK.

  They cannot go through TSQLConnection.ExecuteDirect: sqldb.pp:1492 starts a
  transaction unconditionally, and SQLite refuses journal_mode and synchronous
  inside one -- while SILENTLY IGNORING foreign_keys, which is the dangerous
  member of the three. So they go through TSQLite3Connection.execsql, the
  connector's own transaction-free path, reached by descending from it.

  This test exists because "requested" and "in force" are different things and
  the difference is invisible: a log whose foreign keys were quietly never
  switched on looks exactly like one where they were. *)
procedure TLogDatabaseTests.TestConnectionPragmasActuallyApply;
var
   db: TLogDatabase;
   fn: string;
begin
   BeginTest('TestConnectionPragmasActuallyApply');
   fn := TempLogName('pragmas.db');
   Scrub(fn);

   db := TLogDatabase.Create;
   try
      db.CreateNew(fn);

      (* On ordinary local storage this is 'wal'. It is READ BACK rather than
        assumed because SQLite refuses WAL on a network share and says nothing
        -- and a multi-op station is exactly where a log ends up on one. *)
      CheckEquals('wal', db.JournalMode,
                  'journal_mode is WAL on local storage');

      (* The silent one. ApplyPragmas raises if this comes back off, so reaching
        here at all is half the proof; asserting it states the other half. *)
      CheckTrue(db.ForeignKeysEnforced,
                'foreign key enforcement is actually ON, not merely requested');
   finally
      db.Free;
   end;

   Scrub(fn);
end;

procedure TLogDatabaseTests.TestApplicationIdIsStamped;
var
   db: TLogDatabase;
   q: TSQLQuery;
   fn: string;
   appId: integer;
begin
   BeginTest('TestApplicationIdIsStamped');
   fn := TempLogName('appid.db');
   Scrub(fn);

   db := TLogDatabase.Create;
   try
      db.CreateNew(fn);
      q := TSQLQuery.Create(nil);
      try
         q.DataBase := db.Connection;
         q.SQL.Text := 'PRAGMA application_id';
         q.Open;
         appId := q.Fields[0].AsInteger;
         q.Close;
      finally
         q.Free;
      end;
   finally
      db.Free;
   end;

   (* 'TR4W' at offset 68 of the file. *)
   CheckEquals(LOG_APPLICATION_ID, appId, 'a TR4W log says so in its header');
   CheckEquals($54523457, appId, 'and the value is literally ''TR4W''');
   Scrub(fn);
end;

procedure TLogDatabaseTests.TestForeignDatabaseIsRefused;
var
   db: TLogDatabase;
   fn: string;
   refused: boolean;
begin
   BeginTest('TestForeignDatabaseIsRefused');
   fn := TempLogName('foreign.db');
   Scrub(fn);

   (* Build a database that is stamped as somebody else's -- 'TR4Q', which is
     TR4QT's real id (Database.h:49). Question 8 settled that a TR4QT log is not
     an interop target, so it must be REFUSED rather than half-read. *)
   db := TLogDatabase.Create;
   try
      db.CreateNew(fn);
      db.Connection.ExecuteDirect('PRAGMA application_id = 1414681681');
      (* COMMIT, or Close rolls it back and this test silently passes a database
        that was never re-stamped -- which is how it failed the first time. *)
      db.Transaction.Commit;
      db.Close;
   finally
      db.Free;
   end;

   refused := False;
   db := TLogDatabase.Create;
   try
      try
         db.Open(fn);
      except
         on E: ELogDatabaseError do
            begin
            refused := True;
            end;
      end;
   finally
      db.Free;
   end;

   CheckTrue(refused, 'a database stamped by another program is refused');
   Scrub(fn);
end;

procedure TLogDatabaseTests.TestNewerSchemaIsRefused;
var
   db: TLogDatabase;
   fn: string;
   refused: boolean;
begin
   BeginTest('TestNewerSchemaIsRefused');
   fn := TempLogName('newer.db');
   Scrub(fn);

   db := TLogDatabase.Create;
   try
      db.CreateNew(fn);
      db.Connection.ExecuteDirect(
         Format('PRAGMA user_version = %d', [LOG_SCHEMA_VERSION + 1]));
      db.Transaction.Commit;
      db.Close;
   finally
      db.Free;
   end;

   refused := False;
   db := TLogDatabase.Create;
   try
      try
         db.Open(fn);
      except
         on E: ELogDatabaseError do
            begin
            refused := True;
            end;
      end;
   finally
      db.Free;
   end;

   (* A newer schema may carry columns this build cannot see; opening it
     read-write would drop them on the next write. *)
   CheckTrue(refused, 'a log from a newer TR4W is refused, not half-read');
   Scrub(fn);
end;

(* ---------------------------------------------------------------------------
  integrity
  --------------------------------------------------------------------------- *)

procedure TLogDatabaseTests.TestIntegrityPassesOnAFreshLog;
var
   db: TLogDatabase;
   fn: string;
   r: TIntegrityResult;
begin
   BeginTest('TestIntegrityPassesOnAFreshLog');
   fn := TempLogName('integrity.db');
   Scrub(fn);

   db := TLogDatabase.Create;
   try
      db.CreateNew(fn);
      r := db.CheckIntegrity;
   finally
      db.Free;
   end;

   CheckTrue(r.Ok, 'a log we just built passes its own integrity check');
   CheckEquals('', r.Report, 'and reports nothing');
   Scrub(fn);
end;

procedure TLogDatabaseTests.TestIntegrityReportsAClosedLog;
var
   db: TLogDatabase;
   r: TIntegrityResult;
begin
   BeginTest('TestIntegrityReportsAClosedLog');

   db := TLogDatabase.Create;
   try
      r := db.CheckIntegrity;
   finally
      db.Free;
   end;

   (* TR4QT returns early and calls it a pass (DataIntegrityManager.cpp, "Not an
     error, just skip the check"). A check that cannot run is not a check that
     passed, and this tree's rule is that a reported problem beats a silent
     one. *)
   CheckFalse(r.Ok, 'a check that could not run is not a pass');
   CheckTrue(r.Report <> '', 'and it says why');
end;

(* ---------------------------------------------------------------------------
  the leaf helpers -- what makes a missing DLL diagnosable
  --------------------------------------------------------------------------- *)

procedure TLogDatabaseTests.TestPEArchitectureOfTheSQLiteDLL;
var
   dll: string;
begin
   BeginTest('TestPEArchitectureOfTheSQLiteDLL');

   (* The DLL that is shipping, read as a file rather than loaded, and found the
     same way the program finds it. If this ever stops matching the build,
     SQLite fails at run time with "the specified module could not be found" --
     naming a file that is present. *)
   dll := SQLiteLibraryPath;

   if FileExists(dll) then
      begin
      CheckEquals(BuildArchitecture, DescribePEArchitecture(dll),
                  'the shipped sqlite3.dll matches the architecture we build');
      end
   else
      begin
      (* Not a failure: the suite may run somewhere the DLL has not been copied.
        Said out loud rather than silently skipped. *)
      CheckTrue(True, 'sqlite3.dll not found beside the tests; check skipped');
      end;
end;

procedure TLogDatabaseTests.TestPEArchitectureOfSomethingThatIsNotPE;
var
   fn: string;
   f: TStringList;
begin
   BeginTest('TestPEArchitectureOfSomethingThatIsNotPE');

   (* A bad download is the realistic case -- an HTML error page saved under a
     .dll name. It must come back as "not a PE", not as a wild machine word
     read out of whatever bytes happened to be at that offset. *)
   fn := TempLogName('notadll.dll');
   f := TStringList.Create;
   try
      f.Add('<html><head><title>404 Not Found</title></head></html>');
      f.SaveToFile(fn);
   finally
      f.Free;
   end;

   CheckEquals('', DescribePEArchitecture(fn), 'an HTML page is not a library');
   DeleteFile(fn);
end;

procedure TLogDatabaseTests.TestPEArchitectureOfAMissingFile;
begin
   BeginTest('TestPEArchitectureOfAMissingFile');
   CheckEquals('', DescribePEArchitecture(TempLogName('no_such_file.dll')),
               'a file that is not there has no architecture');
end;

procedure TLogDatabaseTests.TestDiagnosisNamesAMissingLibrary;
var
   msg: string;
begin
   BeginTest('TestDiagnosisNamesAMissingLibrary');

   msg := DiagnoseSQLiteLoad(TempLogName('nowhere\' + SQLITE_LIBRARY_NAME));

   (* The message has to name the file AND the path, because the operator's next
     action is to go and look there. *)
   CheckTrue(Pos(SQLITE_LIBRARY_NAME, msg) > 0,
             'the diagnosis names the library');
   CheckTrue(Pos('not found', msg) > 0,
             'and says it was not found');
end;

(* --------------------------------------------------------------------------- *)

procedure TLogDatabaseTests.RunAllTests;
begin
   TestCreateNewMakesAFile;
   TestCreateNewRefusesToClobber;
   TestOpenRefusesAMissingFile;
   TestReopenKeepsSchemaVersion;
   TestCloseThenIsOpenIsFalse;

   TestEveryTableIsCreated;
   TestQsoCarriesTheEventSourceColumns;
   TestQsoCarriesEveryCrosswalkColumn;
   TestConfigIsKeyValueAndRoundTrips;
   TestMessageIsKeyedByKindModeAndKey;
   TestDupeIndexExists;

   TestConnectionPragmasActuallyApply;
   TestApplicationIdIsStamped;
   TestForeignDatabaseIsRefused;
   TestNewerSchemaIsRefused;

   TestIntegrityPassesOnAFreshLog;
   TestIntegrityReportsAClosedLog;

   TestPEArchitectureOfTheSQLiteDLL;
   TestPEArchitectureOfSomethingThatIsNotPE;
   TestPEArchitectureOfAMissingFile;
   TestDiagnosisNamesAMissingLibrary;

   if (FDir <> '') and DirectoryExists(FDir) then
      begin
      RemoveDir(FDir);
      end;
end;

end.
