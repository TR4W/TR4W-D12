unit uTestLogMyFacts;

(* OUR STATION, AS IT WAS FOR EACH QSO -- log schema 3 (NY4I, 2026-10-18).

  "Our grid is an event source along with all the MY_ values for the contest
  where needed. The QSO record should have all the MY_ values (such as
  MY_GRID)." These pin the four rulings that shape it:

    A  a row never captured (my_source NULL) is distinguishable from a
       captured row with an unknown value;
    B  Edit QSO can change them, and nothing else that writes a row can;
    D  a multi-op peer's QSO records THIS station's values, marked assumed;
    E  schema 3, migrated in place by ALTER TABLE, with the consequence that
       an older build can no longer open a log this one has opened.

  THREE LAYERS, each where it can be reached: the leaf rules (uQsoMyFacts),
  the database and repository against real files, and the store through its
  public entry points -- the capture at the moment of the QSO and the
  editor's read and write. *)

{$I ..\..\src\tr4w.inc}

interface

uses
   Classes, VC, uTR4WTestFramework, uQsoMyFacts;

type
   TLogMyFactsTests = class(TTestCase)
   private
      FDir: string;
      function TempLogName(const aLeaf: string): string;
      procedure Scrub(const aFileName: string);
      procedure MakeQSO(out aQso: ContestExchange; aSeed: integer);
      function SampleFacts: TQsoMyFacts;
      (* The qso table's column names, in table order, '|'-joined. *)
      function QsoColumnNames(const aFileName: string): string;
      (* Takes a log back to schema 2 on disk: drops the v3 columns from
        aFirstDropped on, and stamps user_version 2. *)
      procedure DowngradeToSchema2(const aFileName: string; aFirstDropped: integer);
      procedure CheckFactsEqual(const aExpected, aActual: TQsoMyFacts; const aWhat: string);
   protected
      (* the leaf *)
      procedure TestEverySourceTokenRoundTrips;
      procedure TestAnUnknownSourceTokenIsNotReadAsNeverCaptured;
      procedure TestValuesDifferIgnoresTheSource;
      procedure TestAPeerQSOWasNotLoggedHere;
      (* the schema *)
      procedure TestANewLogIsSchema3AndEndsWithTheV3Columns;
      procedure TestASchema2LogMigratesAndKeepsItsRows;
      procedure TestAMigrationLeavesAColumnAlreadyThere;
      procedure TestOpeningAnOlderLogStampsTheNewSchema;
      (* the repository *)
      procedure TestTheFactsAreCapturedOnInsert;
      procedure TestTheNextSaveIsNotCaptured;
      procedure TestAnEditKeepsThem;
      procedure TestTheEditorWriteChangesThem;
      procedure TestARescoreAndANetworkUpdateKeepThem;
      procedure TestAnAppendBatchCarriesEachRowsOwn;
      (* the store *)
      procedure TestTheStoreCapturesOurStationAtTheMomentOfTheQSO;
      procedure TestTheEditorReadsAndWritesThroughTheStore;
   public
      procedure RunAllTests; override;
   end;

implementation

uses
   SysUtils, sqldb, utils_text, uSettingsModel,
   uLogDatabase, uLogSchema, uLogRepository, uLogStore;

const
   (* 101 records -- the store suite's log. *)
   FIXTURE_SET = 'cqww_ssb_2025_ny4i';

(* --------------------------------------------------------------- helpers *)

function TLogMyFactsTests.TempLogName(const aLeaf: string): string;
begin
   if FDir = '' then
      begin
      FDir := IncludeTrailingPathDelimiter(GetTempDir) +
              'tr4w_myfacts_' + IntToStr(GetProcessID);
      ForceDirectories(FDir);
      end;
   Result := IncludeTrailingPathDelimiter(FDir) + aLeaf;
end;

procedure TLogMyFactsTests.Scrub(const aFileName: string);
const
   SUFFIXES: array[0..4] of string = ('', '-wal', '-shm', '-journal', '.importing');
var
   i: integer;
begin
   for i := Low(SUFFIXES) to High(SUFFIXES) do
      begin
      if FileExists(aFileName + SUFFIXES[i]) then
         begin
         DeleteFile(aFileName + SUFFIXES[i]);
         end;
      end;
end;

procedure TLogMyFactsTests.MakeQSO(out aQso: ContestExchange; aSeed: integer);
begin
   (* Initialised, not cleared with FillChar -- the Count-LiveMove ratchet. *)
   aQso := Default(ContestExchange);
   aQso.ceRecordKind := rkQSO;
   aQso.ceContest := NoContest;
   aQso.id := 'myfacts' + IntToStr(aSeed);
   aQso.ceQSOID1 := 3000 + aSeed;
   aQso.ceQSOID2 := 4000 + aSeed;
   aQso.tSysTime.qtYear := 26;
   aQso.tSysTime.qtMonth := 10;
   aQso.tSysTime.qtDay := 1 + aSeed;
   aQso.tSysTime.qtHour := 12;
   aQso.tSysTime.qtMinute := aSeed;
   aQso.Callsign := 'W' + IntToStr(aSeed) + 'XYZ';
   aQso.Frequency := 14025000 + aSeed;
   aQso.Band := Band20;
   aQso.Mode := CW;
   aQso.ExtMode := eCW;
   aQso.NumberReceived := -1;
   aQso.NumberSent := -1;
   aQso.Prefecture := 255;
   aQso.Zone := 255;
   aQso.QTH.Zone := 255;
   aQso.TenTenNum := 65535;
end;

(* EVERY FIELD SET, AND EACH DIFFERENT -- so a swapped pair cannot pass. *)
function TLogMyFactsTests.SampleFacts: TQsoMyFacts;
begin
   Result := NotCapturedMyFacts;
   Result.Source := mfsLogged;
   Result.Call := 'NY4I/R';
   Result.Grid := 'EN01AB';
   Result.State := 'NE';
   Result.County := 'LAN';
   Result.Section := 'NE';
   Result.Park := 'US-1234';
   Result.Iota := 'NA-001';
   Result.Country := 'K';
   Result.Continent := 'NA';
   Result.CQZone := 4;
   Result.ITUZone := 7;
end;

procedure TLogMyFactsTests.CheckFactsEqual(const aExpected, aActual: TQsoMyFacts;
                                           const aWhat: string);
begin
   CheckEquals(Ord(aExpected.Source), Ord(aActual.Source), aWhat + ': source');
   CheckEquals(string(aExpected.Call), string(aActual.Call), aWhat + ': call');
   CheckEquals(string(aExpected.Grid), string(aActual.Grid), aWhat + ': grid');
   CheckEquals(string(aExpected.State), string(aActual.State), aWhat + ': state');
   CheckEquals(string(aExpected.County), string(aActual.County), aWhat + ': county');
   CheckEquals(string(aExpected.Section), string(aActual.Section), aWhat + ': section');
   CheckEquals(string(aExpected.Park), string(aActual.Park), aWhat + ': park');
   CheckEquals(string(aExpected.Iota), string(aActual.Iota), aWhat + ': IOTA');
   CheckEquals(string(aExpected.Country), string(aActual.Country), aWhat + ': country');
   CheckEquals(string(aExpected.Continent), string(aActual.Continent), aWhat + ': continent');
   CheckEquals(aExpected.CQZone, aActual.CQZone, aWhat + ': CQ zone');
   CheckEquals(aExpected.ITUZone, aActual.ITUZone, aWhat + ': ITU zone');
end;

function TLogMyFactsTests.QsoColumnNames(const aFileName: string): string;
var
   db: TLogDatabase;
   q: TSQLQuery;
begin
   Result := '';
   db := TLogDatabase.Create;
   try
      db.OpenReadOnly(aFileName);
      q := TSQLQuery.Create(nil);
      try
         q.DataBase := db.Connection;
         q.UsePrimaryKeyAsKey := False;
         q.SQL.Text := 'SELECT name FROM pragma_table_info(''qso'') ORDER BY cid';
         q.Open;
         while not q.EOF do
            begin
            Result := Result + '|' + q.Fields[0].AsString;
            q.Next;
            end;
         q.Close;
      finally
         q.Free;
      end;
   finally
      db.Free;
   end;
end;

(* A REAL DOWNGRADE, as TestAnOlderLogGainsTheSessionTable makes one: a log
  created at the current schema with the v3 columns DROPPED and user_version
  set back -- so the file is what a schema-2 build wrote, not a hand-built
  imitation of it. ALTER TABLE DROP COLUMN needs SQLite 3.35; the shipped
  library is 3.53. *)
procedure TLogMyFactsTests.DowngradeToSchema2(const aFileName: string;
                                              aFirstDropped: integer);
var
   db: TLogDatabase;
   i: integer;
begin
   db := TLogDatabase.Create;
   try
      db.Open(aFileName);
      for i := aFirstDropped to High(LOG_V3_QSO_COLUMNS) do
         begin
         db.Connection.ExecuteDirect(UTF8Encode('ALTER TABLE qso DROP COLUMN ' +
                                                string(LOG_V3_QSO_COLUMNS[i].Name)));
         end;
      db.Transaction.Commit;
      db.Connection.ExecuteDirect('PRAGMA user_version = 2');
      db.Transaction.Commit;
   finally
      db.Free;
   end;
end;

(* -------------------------------------------------------------- the leaf *)

procedure TLogMyFactsTests.TestEverySourceTokenRoundTrips;
var
   s: TQsoMyFactsSource;
begin
   BeginTest('every my_source token reads back as the source it was written for');
   for s := Low(TQsoMyFactsSource) to High(TQsoMyFactsSource) do
      begin
      CheckEquals(Ord(s), Ord(TokenToMyFactsSource(MyFactsSourceToken(s))),
                  'source ' + IntToStr(Ord(s)));
      end;
   (* NOT CAPTURED IS NULL -- the token is empty, and BindText stores an
     empty token as NULL, which is what a pre-schema-3 row holds. *)
   CheckEquals('', string(MyFactsSourceToken(mfsNotCaptured)),
               'never captured is written as no token at all');
end;

procedure TLogMyFactsTests.TestAnUnknownSourceTokenIsNotReadAsNeverCaptured;
begin
   BeginTest('a my_source token this build does not know is not "never captured"');
   (* "Never captured" would let a reader replace the row's values with
     today's; a stated value of unknown provenance must not be. *)
   CheckEquals(Ord(mfsEdited), Ord(TokenToMyFactsSource('from-a-hand-edit')),
               'read as stated by an operator');
end;

procedure TLogMyFactsTests.TestValuesDifferIgnoresTheSource;
var
   a, b: TQsoMyFacts;
begin
   BeginTest('MyFactsValuesDiffer compares the values and not where they came from');
   a := SampleFacts;
   b := a;
   b.Source := mfsAssumed;
   CheckFalse(MyFactsValuesDiffer(a, b), 'the same values from another source');
   b := a;
   b.Grid := 'EN02AB';
   CheckTrue(MyFactsValuesDiffer(a, b), 'a grid changed');
   b := a;
   b.ITUZone := 8;
   CheckTrue(MyFactsValuesDiffer(a, b), 'an ITU zone changed');
   b := a;
   b.Continent := 'EU';
   CheckTrue(MyFactsValuesDiffer(a, b), 'a continent changed, though no form shows it');
end;

procedure TLogMyFactsTests.TestAPeerQSOWasNotLoggedHere;
begin
   BeginTest('a QSO carrying another station''s computer id was not logged here');
   CheckTrue(QsoWasLoggedHere(#0, #0), 'single-op: no id on either side');
   CheckTrue(QsoWasLoggedHere('A', 'A'), 'our own id');
   CheckFalse(QsoWasLoggedHere('B', 'A'), 'a peer''s id');
   CheckFalse(QsoWasLoggedHere('B', #0), 'a peer''s QSO on a station with no id');
end;

(* ------------------------------------------------------------ the schema *)

procedure TLogMyFactsTests.TestANewLogIsSchema3AndEndsWithTheV3Columns;
var
   db: TLogDatabase;
   fn, names, tail: string;
   i: integer;
begin
   BeginTest('a new log is schema 3 and its qso table ends with the v3 columns');
   CheckEquals(3, LOG_SCHEMA_VERSION, 'the schema this build writes');
   fn := TempLogName('new3.db');
   Scrub(fn);

   db := TLogDatabase.Create;
   try
      db.CreateNew(fn);
      CheckEquals(3, db.SchemaVersion, 'a new log is stamped 3');
   finally
      db.Free;
   end;

   names := QsoColumnNames(fn);
   tail := '';
   for i := Low(LOG_V3_QSO_COLUMNS) to High(LOG_V3_QSO_COLUMNS) do
      begin
      tail := tail + '|' + string(LOG_V3_QSO_COLUMNS[i].Name);
      end;
   (* LAST, IN THIS ORDER -- the order ALTER TABLE ADD COLUMN gives a
     migrated log, so the two cannot differ. *)
   CheckEquals(tail, Copy(names, Length(names) - Length(tail) + 1, MaxInt),
               'the CREATE TABLE ends with LOG_V3_QSO_COLUMNS, in order');
   CheckTrue(Pos('|my_grid|', names) > 0, 'my_grid, from schema 1, is still there');
   Scrub(fn);
end;

procedure TLogMyFactsTests.TestASchema2LogMigratesAndKeepsItsRows;
var
   db: TLogDatabase;
   repo: TLogRepository;
   qso, back: ContestExchange;
   facts: TQsoMyFacts;
   fn, fresh, fnFresh: string;
   rowId: Int64;
begin
   BeginTest('a schema-2 log gains the my_* columns on open, and keeps every row');
   fn := TempLogName('migrate2.db');
   fnFresh := TempLogName('fresh3.db');
   Scrub(fn);
   Scrub(fnFresh);

   (* The shape a new log has -- what the migrated one must match. *)
   db := TLogDatabase.Create;
   try
      db.CreateNew(fnFresh);
   finally
      db.Free;
   end;
   fresh := QsoColumnNames(fnFresh);

   db := TLogDatabase.Create;
   try
      db.CreateNew(fn);
      repo := TLogRepository.Create(db);
      try
         MakeQSO(qso, 1);
         qso.QSOPoints := 3;
         rowId := repo.SaveQSO(qso);
         repo.Commit;
      finally
         repo.Free;
      end;
   finally
      db.Free;
   end;

   DowngradeToSchema2(fn, Low(LOG_V3_QSO_COLUMNS));
   CheckEquals(0, Pos('|my_source', QsoColumnNames(fn)),
               'the fixture really is schema 2: no my_source');

   db := TLogDatabase.Create;
   try
      db.Open(fn);
      CheckEquals(LOG_SCHEMA_VERSION, db.SchemaVersion, 'migrated to the current schema');
      repo := TLogRepository.Create(db);
      try
         CheckTrue(repo.LoadQSO(rowId, back), 'the row survived the migration');
         CheckEquals('W1XYZ', string(back.Callsign), 'its callsign is intact');
         CheckEquals(3, back.QSOPoints, 'and its points');
         CheckTrue(repo.LoadQSOMyFacts(rowId, facts), 'its my_* columns read');
         (* RULING A: an old row is NEVER CAPTURED, so a reader falls back to
           the session -- it is not a captured row with unknown values. *)
         CheckEquals(Ord(mfsNotCaptured), Ord(facts.Source),
                     'an old row reads as never captured');
      finally
         repo.Free;
      end;
   finally
      db.Free;
   end;

   CheckEquals(fresh, QsoColumnNames(fn),
               'the migrated table matches a new one, column for column');
   Scrub(fn);
   Scrub(fnFresh);
end;

procedure TLogMyFactsTests.TestAMigrationLeavesAColumnAlreadyThere;
var
   db: TLogDatabase;
   fn: string;
begin
   BeginTest('a schema-2 log that already has some v3 columns migrates the rest');
   fn := TempLogName('partial.db');
   Scrub(fn);
   db := TLogDatabase.Create;
   try
      db.CreateNew(fn);
   finally
      db.Free;
   end;
   (* my_call and my_section stay; the rest go. *)
   DowngradeToSchema2(fn, 2);

   db := TLogDatabase.Create;
   try
      db.Open(fn);
      CheckEquals(LOG_SCHEMA_VERSION, db.SchemaVersion,
                  'opens and migrates -- the guard skipped the columns present');
   finally
      db.Free;
   end;
   CheckTrue(Pos('|my_source', QsoColumnNames(fn)) > 0, 'and added the missing ones');
   Scrub(fn);
end;

(* THE CONSEQUENCE NY4I ACCEPTED, PINNED AT THE ONLY END THIS BUILD CAN REACH.
  An older build cannot run here; what it does with a newer log is
  VerifyIdentity's refusal of user_version > its own, pinned for this build
  by TestNewerSchemaIsRefused. What THIS build must be seen to do is the other
  half: opening a schema-2 log -- for anything, an /EXPORT included -- writes
  3 into it. That is what turns an ordinary open into "older builds can no
  longer read this file". *)
procedure TLogMyFactsTests.TestOpeningAnOlderLogStampsTheNewSchema;
var
   db: TLogDatabase;
   fn: string;
begin
   BeginTest('opening a schema-2 log stamps 3 into the file, which older builds refuse');
   fn := TempLogName('stamp.db');
   Scrub(fn);
   db := TLogDatabase.Create;
   try
      db.CreateNew(fn);
   finally
      db.Free;
   end;
   DowngradeToSchema2(fn, Low(LOG_V3_QSO_COLUMNS));

   (* READ-ONLY DOES NOT MIGRATE -- the door for a file that must not change. *)
   db := TLogDatabase.Create;
   try
      db.OpenReadOnly(fn);
      CheckEquals(2, db.SchemaVersion, 'OpenReadOnly leaves a schema-2 log at 2');
   finally
      db.Free;
   end;

   db := TLogDatabase.Create;
   try
      db.Open(fn);
   finally
      db.Free;
   end;

   db := TLogDatabase.Create;
   try
      db.OpenReadOnly(fn);
      CheckEquals(3, db.SchemaVersion,
                  'after one Open the FILE says 3 -- a schema-2 build refuses it');
   finally
      db.Free;
   end;
   Scrub(fn);
end;

(* -------------------------------------------------------- the repository *)

procedure TLogMyFactsTests.TestTheFactsAreCapturedOnInsert;
var
   db: TLogDatabase;
   repo: TLogRepository;
   qso: ContestExchange;
   facts: TQsoMyFacts;
   fn: string;
   rowId: Int64;
begin
   BeginTest('SetNextMyFacts is what the insert writes, every field');
   fn := TempLogName('capture.db');
   Scrub(fn);
   db := TLogDatabase.Create;
   try
      db.CreateNew(fn);
      repo := TLogRepository.Create(db);
      try
         MakeQSO(qso, 1);
         repo.SetNextMyFacts(SampleFacts);
         rowId := repo.SaveQSO(qso);
         repo.Commit;
      finally
         repo.Free;
      end;
   finally
      db.Free;
   end;

   db := TLogDatabase.Create;
   try
      db.Open(fn);
      repo := TLogRepository.Create(db);
      try
         CheckTrue(repo.LoadQSOMyFacts(rowId, facts), 'the row is there');
         CheckFactsEqual(SampleFacts, facts, 'after a reopen');
      finally
         repo.Free;
      end;
   finally
      db.Free;
   end;
   Scrub(fn);
end;

procedure TLogMyFactsTests.TestTheNextSaveIsNotCaptured;
var
   db: TLogDatabase;
   repo: TLogRepository;
   qso: ContestExchange;
   facts: TQsoMyFacts;
   q: TSQLQuery;
   fn: string;
   secondId: Int64;
begin
   BeginTest('one QSO''s station is not the next one''s, and not captured is NULL everywhere');
   fn := TempLogName('cleared.db');
   Scrub(fn);
   db := TLogDatabase.Create;
   try
      db.CreateNew(fn);
      repo := TLogRepository.Create(db);
      try
         MakeQSO(qso, 1);
         repo.SetNextMyFacts(SampleFacts);
         repo.SaveQSO(qso);
         MakeQSO(qso, 2);
         secondId := repo.SaveQSO(qso);
         repo.Commit;

         CheckTrue(repo.LoadQSOMyFacts(secondId, facts), 'the second row is there');
         CheckEquals(Ord(mfsNotCaptured), Ord(facts.Source),
                     'the second save was given nothing, so captured nothing');

         q := TSQLQuery.Create(nil);
         try
            q.DataBase := db.Connection;
            q.UsePrimaryKeyAsKey := False;
            q.SQL.Text := 'SELECT ' +
               'my_county IS NULL AND my_grid IS NULL AND my_state IS NULL AND ' +
               'my_call IS NULL AND my_section IS NULL AND my_park IS NULL AND ' +
               'my_iota IS NULL AND my_country IS NULL AND my_continent IS NULL AND ' +
               'my_cq_zone IS NULL AND my_itu_zone IS NULL AND my_source IS NULL ' +
               'FROM qso WHERE id = ' + IntToStr(secondId);
            q.Open;
            CheckEquals(1, q.Fields[0].AsInteger,
                        'every my_* column of a row never captured is NULL, as an old row''s');
            q.Close;
         finally
            q.Free;
         end;
      finally
         repo.Free;
      end;
   finally
      db.Free;
   end;
   Scrub(fn);
end;

procedure TLogMyFactsTests.TestAnEditKeepsThem;
var
   db: TLogDatabase;
   repo: TLogRepository;
   qso: ContestExchange;
   facts: TQsoMyFacts;
   fn: string;
   rowId: Int64;
begin
   BeginTest('an ordinary update of the QSO leaves our station as captured');
   fn := TempLogName('edit.db');
   Scrub(fn);
   db := TLogDatabase.Create;
   try
      db.CreateNew(fn);
      repo := TLogRepository.Create(db);
      try
         MakeQSO(qso, 1);
         repo.SetNextMyFacts(SampleFacts);
         rowId := repo.SaveQSO(qso);
         repo.Commit;

         qso.Callsign := 'K9EDIT';
         qso.QSOPoints := 9;
         CheckTrue(repo.UpdateQSO(rowId, qso), 'the update found the row');
         repo.Commit;

         CheckTrue(repo.LoadQSOMyFacts(rowId, facts), 'the row is there');
         CheckFactsEqual(SampleFacts, facts, 'after UpdateQSO');
      finally
         repo.Free;
      end;
   finally
      db.Free;
   end;
   Scrub(fn);
end;

procedure TLogMyFactsTests.TestTheEditorWriteChangesThem;
var
   db: TLogDatabase;
   repo: TLogRepository;
   qso, back: ContestExchange;
   facts, edited: TQsoMyFacts;
   fn: string;
   rowId: Int64;
begin
   BeginTest('UpdateQSOMyFacts writes every my_* column and its source, and nothing else');
   fn := TempLogName('editor.db');
   Scrub(fn);
   db := TLogDatabase.Create;
   try
      db.CreateNew(fn);
      repo := TLogRepository.Create(db);
      try
         MakeQSO(qso, 1);
         repo.SetNextMyFacts(SampleFacts);
         rowId := repo.SaveQSO(qso);
         repo.Commit;

         edited := SampleFacts;
         edited.Source := mfsEdited;
         edited.Grid := 'EN02CD';
         edited.County := '';
         edited.CQZone := 0;
         CheckTrue(repo.UpdateQSOMyFacts(rowId, edited), 'the update found the row');
         CheckFalse(repo.UpdateQSOMyFacts(rowId + 100, edited),
                    'and says so when there is no row');
         repo.Commit;
      finally
         repo.Free;
      end;
   finally
      db.Free;
   end;

   db := TLogDatabase.Create;
   try
      db.Open(fn);
      repo := TLogRepository.Create(db);
      try
         CheckTrue(repo.LoadQSOMyFacts(rowId, facts), 'the row is there');
         CheckFactsEqual(edited, facts, 'after the editor''s write');
         CheckTrue(repo.LoadQSO(rowId, back), 'and the QSO');
         CheckEquals('W1XYZ', string(back.Callsign), 'whose own fields it did not touch');
      finally
         repo.Free;
      end;
   finally
      db.Free;
   end;
   Scrub(fn);
end;

procedure TLogMyFactsTests.TestARescoreAndANetworkUpdateKeepThem;
var
   db: TLogDatabase;
   repo: TLogRepository;
   qso: ContestExchange;
   facts: TQsoMyFacts;
   updates: TLogRowUpdates;
   fn: string;
   rowId: Int64;
begin
   BeginTest('the rescore''s batch and the network update leave our station as captured');
   fn := TempLogName('rescore.db');
   Scrub(fn);
   db := TLogDatabase.Create;
   try
      db.CreateNew(fn);
      repo := TLogRepository.Create(db);
      try
         MakeQSO(qso, 1);
         repo.SetNextMyFacts(SampleFacts);
         rowId := repo.SaveQSO(qso);
         repo.Commit;

         (* THE RESCORE: the whole-log batch, by row id. *)
         qso.QSOPoints := 12;
         updates := TLogRowUpdates.Create;
         try
            updates.Add(rowId, qso);
            repo.WriteBatch(updates);
         finally
            updates.Free;
         end;
         CheckTrue(repo.LoadQSOMyFacts(rowId, facts), 'the row is there');
         CheckFactsEqual(SampleFacts, facts, 'after the rescore''s batch');

         (* THE NETWORK UPDATE: matched on the session pair. *)
         qso.QSOPoints := 13;
         CheckTrue(repo.UpdateQSOBySessionIds(qso.ceQSOID1, qso.ceQSOID2, qso),
                   'the network update found the row');
         repo.Commit;
         CheckTrue(repo.LoadQSOMyFacts(rowId, facts), 'the row is still there');
         CheckFactsEqual(SampleFacts, facts, 'after the network update');
      finally
         repo.Free;
      end;
   finally
      db.Free;
   end;
   Scrub(fn);
end;

procedure TLogMyFactsTests.TestAnAppendBatchCarriesEachRowsOwn;
var
   db: TLogDatabase;
   repo: TLogRepository;
   qso: ContestExchange;
   facts: TQsoMyFacts;
   appends: TLogQsoAppends;
   fn: string;
   failedAt: integer;
begin
   BeginTest('an append batch writes each row''s own station, or none');
   fn := TempLogName('append.db');
   Scrub(fn);
   db := TLogDatabase.Create;
   try
      db.CreateNew(fn);
      repo := TLogRepository.Create(db);
      try
         appends := TLogQsoAppends.Create;
         try
            MakeQSO(qso, 1);
            facts := SampleFacts;
            facts.Source := mfsImported;
            appends.Add(qso, facts);
            MakeQSO(qso, 2);
            appends.Add(qso);
            repo.AppendBatch(appends, nil, failedAt);
         finally
            appends.Free;
         end;
         CheckEquals(-1, failedAt, 'every row went in');

         CheckTrue(repo.LoadQSOMyFacts(repo.RowIdAtIndex(0), facts), 'row 1');
         CheckEquals(Ord(mfsImported), Ord(facts.Source), 'row 1 carries its file''s station');
         CheckEquals('EN01AB', string(facts.Grid), 'row 1''s grid');
         CheckTrue(repo.LoadQSOMyFacts(repo.RowIdAtIndex(1), facts), 'row 2');
         CheckEquals(Ord(mfsNotCaptured), Ord(facts.Source),
                     'row 2 was given none, so has none -- not row 1''s');
      finally
         repo.Free;
      end;
   finally
      db.Free;
   end;
   Scrub(fn);
end;

(* ------------------------------------------------------------- the store *)

(* THE STORE, AS A QSO IS LOGGED -- driven exactly as uTestLogStore drives it:
  a D7 fixture copied to a scratch .trw is the log, so the first append
  migrates it. That gives all three kinds of row in one file: 101 migrated
  rows (never captured -- a binary log records none of this), one QSO this
  station logged, and one that arrived from a multi-op peer. *)
procedure TLogMyFactsTests.TestTheStoreCapturesOurStationAtTheMomentOfTheQSO;
var
   trw, db, savedLogName, savedGrid, savedOverride: string;
   savedSilent, savedStated: boolean;
   source, target: TFileStream;
   qso: ContestExchange;
   facts: TQsoMyFacts;
   logDb: TLogDatabase;
   repo: TLogRepository;
   ourGrid: AnsiString;
begin
   BeginTest('the store records our station as it was when each QSO was logged');

   LogStoreClose;
   trw := TempLogName(FIXTURE_SET + '.trw');
   db := LogDatabaseFileName(trw);
   Scrub(db);
   source := TFileStream.Create(ExtractFilePath(ParamStr(0)) + 'fixtures' +
                                PathDelim + 'binarylog' + PathDelim + FIXTURE_SET +
                                '.trw', fmOpenRead or fmShareDenyWrite);
   try
      target := TFileStream.Create(trw, fmCreate);
      try
         target.CopyFrom(source, 0);
      finally
         target.Free;
      end;
   finally
      source.Free;
   end;

   savedLogName := CharBufferText(TR4W_LOG_FILENAME);
   savedSilent := tSilentExport;
   savedGrid := Settings.My.Grid;
   savedStated := Settings.My.HasContestOverride(sfGrid);
   savedOverride := Settings.My.ContestOverride(sfGrid);
   SetCharBuffer(TR4W_LOG_FILENAME, trw);
   tSilentExport := True;
   try
      (* THE STATION'S GRID, with no contest override in the way. *)
      Settings.My.ClearContestOverride(sfGrid);
      Settings.My.Grid := 'EN01AB';
      ourGrid := UTF8Encode(Settings.My.ResolvedGrid);

      MakeQSO(qso, 1);
      qso.ceComputerID := Settings.Computer.Id;
      CheckTrue(LogStoreAppendQSO(qso), 'our QSO is logged');

      (* THE ROVER MOVES -- and the next QSO is a peer's. *)
      Settings.My.Grid := 'EN02AB';
      MakeQSO(qso, 2);
      if Settings.Computer.Id = 'B' then
         begin
         qso.ceComputerID := 'C';
         end
      else
         begin
         qso.ceComputerID := 'B';
         end;
      CheckTrue(LogStoreAppendQSO(qso), 'a peer''s QSO is logged');

      (* AND THE SETTING MOVES AGAIN, which no stored QSO may follow. *)
      Settings.My.Grid := 'EN03AB';
      LogStoreClose;

      logDb := TLogDatabase.Create;
      try
         logDb.OpenReadOnly(db);
         repo := TLogRepository.Create(logDb);
         try
            CheckEquals(103, repo.QSOCount, '101 migrated QSOs and the two logged');

            CheckTrue(repo.LoadQSOMyFacts(repo.RowIdAtIndex(0), facts), 'a migrated row');
            CheckEquals(Ord(mfsNotCaptured), Ord(facts.Source),
                        'a QSO migrated from the binary log was never captured');

            CheckTrue(repo.LoadQSOMyFacts(repo.RowIdAtIndex(101), facts), 'our QSO');
            CheckEquals(Ord(mfsLogged), Ord(facts.Source), 'our QSO is ours, logged');
            CheckEquals(string(ourGrid), string(facts.Grid),
                        'and holds the grid in effect WHEN IT WAS LOGGED');
            CheckEquals(Settings.My.Call, string(facts.Call), 'and our call as signed');

            CheckTrue(repo.LoadQSOMyFacts(repo.RowIdAtIndex(102), facts), 'the peer''s QSO');
            CheckEquals(Ord(mfsAssumed), Ord(facts.Source),
                        'a peer''s QSO carries this station''s values, MARKED assumed');
            CheckEquals('EN02AB', string(facts.Grid),
                        'the values in effect here when it arrived');
         finally
            repo.Free;
         end;
      finally
         logDb.Free;
      end;
   finally
      LogStoreClose;
      Settings.My.Grid := savedGrid;
      if savedStated then
         begin
         Settings.My.SetContestOverride(sfGrid, savedOverride);
         end;
      SetCharBuffer(TR4W_LOG_FILENAME, savedLogName);
      tSilentExport := savedSilent;
      Scrub(db);
      if FileExists(trw) then
         begin
         DeleteFile(trw);
         end;
   end;
end;

(* EDIT QSO's TWO CALLS, as the editor makes them: read our station at a
  record position, and write the QSO and its station back as one transaction. *)
procedure TLogMyFactsTests.TestTheEditorReadsAndWritesThroughTheStore;
var
   trw, db, savedLogName: string;
   savedSilent: boolean;
   source, target: TFileStream;
   qso: ContestExchange;
   facts, edited: TQsoMyFacts;
   logDb: TLogDatabase;
   repo: TLogRepository;
   back: ContestExchange;
begin
   BeginTest('Edit QSO reads and writes our station through the store');

   LogStoreClose;
   trw := TempLogName(FIXTURE_SET + '-edit.trw');
   db := LogDatabaseFileName(trw);
   Scrub(db);
   source := TFileStream.Create(ExtractFilePath(ParamStr(0)) + 'fixtures' +
                                PathDelim + 'binarylog' + PathDelim + FIXTURE_SET +
                                '.trw', fmOpenRead or fmShareDenyWrite);
   try
      target := TFileStream.Create(trw, fmCreate);
      try
         target.CopyFrom(source, 0);
      finally
         target.Free;
      end;
   finally
      source.Free;
   end;

   savedLogName := CharBufferText(TR4W_LOG_FILENAME);
   savedSilent := tSilentExport;
   SetCharBuffer(TR4W_LOG_FILENAME, trw);
   tSilentExport := True;
   try
      MakeQSO(qso, 1);
      qso.ceComputerID := Settings.Computer.Id;
      CheckTrue(LogStoreAppendQSO(qso), 'a QSO is logged');

      CheckTrue(LogStoreReadMyFactsAtIndex(0, facts), 'a migrated row reads');
      CheckEquals(Ord(mfsNotCaptured), Ord(facts.Source),
                  'and the editor is told it was never recorded');

      CheckTrue(LogStoreReadMyFactsAtIndex(101, facts), 'our QSO reads');
      CheckEquals(Ord(mfsLogged), Ord(facts.Source), 'as logged');

      edited := facts;
      edited.Source := mfsEdited;
      edited.Grid := 'FN31PR';
      qso.QSOPoints := 7;
      LogStoreUpdateQSOAtIndex(101, qso, edited);
      CheckTrue(LogStoreIsUsable, 'the store is still usable after the edit');

      CheckTrue(LogStoreReadMyFactsAtIndex(101, facts), 'our QSO reads again');
      CheckFactsEqual(edited, facts, 'the editor''s values, through the store');
      LogStoreClose;

      logDb := TLogDatabase.Create;
      try
         logDb.OpenReadOnly(db);
         repo := TLogRepository.Create(logDb);
         try
            CheckTrue(repo.LoadQSOMyFacts(repo.RowIdAtIndex(101), facts), 'after a close');
            CheckEquals('FN31PR', string(facts.Grid), 'the edit was committed');
            CheckTrue(repo.LoadQSO(repo.RowIdAtIndex(101), back), 'and the QSO');
            CheckEquals(7, back.QSOPoints, 'whose own edit went with it');
         finally
            repo.Free;
         end;
      finally
         logDb.Free;
      end;
   finally
      LogStoreClose;
      SetCharBuffer(TR4W_LOG_FILENAME, savedLogName);
      tSilentExport := savedSilent;
      Scrub(db);
      if FileExists(trw) then
         begin
         DeleteFile(trw);
         end;
   end;
end;

procedure TLogMyFactsTests.RunAllTests;
begin
   TestEverySourceTokenRoundTrips;
   TestAnUnknownSourceTokenIsNotReadAsNeverCaptured;
   TestValuesDifferIgnoresTheSource;
   TestAPeerQSOWasNotLoggedHere;

   TestANewLogIsSchema3AndEndsWithTheV3Columns;
   TestASchema2LogMigratesAndKeepsItsRows;
   TestAMigrationLeavesAColumnAlreadyThere;
   TestOpeningAnOlderLogStampsTheNewSchema;

   TestTheFactsAreCapturedOnInsert;
   TestTheNextSaveIsNotCaptured;
   TestAnEditKeepsThem;
   TestTheEditorWriteChangesThem;
   TestARescoreAndANetworkUpdateKeepThem;
   TestAnAppendBatchCarriesEachRowsOwn;

{$IFDEF WINDOWS}
   (* As the LogStore suite: these migrate a D7 binary log, which is a
     Windows migration path. *)
   TestTheStoreCapturesOurStationAtTheMomentOfTheQSO;
   TestTheEditorReadsAndWritesThroughTheStore;
{$ELSE}
   WriteLn('  SKIPPED (store half): migrates a D7 binary log, a Windows migration path.');
{$ENDIF}

   if (FDir <> '') and RemoveDir(FDir) then
      begin
      FDir := '';
      end;
end;

end.
