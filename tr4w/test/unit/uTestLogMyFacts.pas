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
      (* StartStore's scratch log, and what it put aside. *)
      FTrw: string;
      FDb: string;
      FSavedLogName: string;
      FSavedSilent: boolean;
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
      (* One ADIF record through the import's own readers. *)
      procedure ParseOneRecord(const aADIF: string; out aQso: ContestExchange;
                               out aFacts: TQsoMyFacts; out aSent: AnsiString);
      (* The store pointed at a scratch copy of a D7 fixture, and back. *)
      procedure StartStore(const aLeaf: string);
      procedure StopStore;
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
      procedure TestASchema2LogNeedsBothMigrationsAtOnce;
      (* the repository *)
      procedure TestTheFactsAreCapturedOnInsert;
      procedure TestTheNextSaveIsNotCaptured;
      procedure TestAnEditKeepsThem;
      procedure TestTheEditorWriteChangesThem;
      procedure TestARescoreAndANetworkUpdateKeepThem;
      procedure TestAnAppendBatchCarriesEachRowsOwn;
      (* the ADIF import and export -- stage 2 *)
      procedure TestTheImportReadsEveryMYTag;
      procedure TestAnAbsentTagIsUnknownNotTodaysValue;
      procedure TestSigInfoIsAParkOnlyUnderPOTA;
      procedure TestAStationCallAloneNamesNoStation;
      procedure TestTheImportRule;
      procedure TestTheImportReportsWhatDiffers;
      procedure TestADXCCCodeMapsToOnePlainEntity;
      procedure TestTheSentExchangeIsTheRecordsSTXString;
      procedure TestANeverCapturedRowWritesNoMYTags;
      procedure TestACapturedRowWritesItsTagsInOrder;
      procedure TestATagTheContestWroteIsNotWrittenTwice;
      procedure TestTheStationCallFollowsTheOperatorRule;
      procedure TestTheMYTagsSurviveARoundTrip;
      (* the export reads the record -- stage 4 *)
      procedure TestTheExportCallFollowsTheRecord;
      procedure TestAnImportedQSOSentWhatItsFileSays;
      procedure TestTheSentExchangeIsBuiltFromTheRecord;
      (* the store *)
      procedure TestTheStoreCapturesOurStationAtTheMomentOfTheQSO;
      procedure TestTheEditorReadsAndWritesThroughTheStore;
      procedure TestAnImportBatchNeverTakesTheLiveStation;
      procedure TestANoteRecordsNoStation;
      procedure TestAPeersEditKeepsItsProvenance;
   public
      procedure RunAllTests; override;
   end;

implementation

uses
   (* The ADIF readers and writer -- FIRST, so the units below still win
     any name it shares with them. *)
   uADIF,
   (* TMyStationExchange and MyStationExchangeOfQSO -- the stage-4 builder. *)
   uContestBase,
   SysUtils, sqldb, utils_text, uSettingsModel,
   uLogDatabase, uLogSchema, uLogRepository, uLogStore,
   uLogNote,   (* SetNoteText -- a note's text *)
   (* DowngradeTestLog and TestLogHasColumn -- the shared fixture helpers *)
   uTestLatestContest;

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

(* A REAL DOWNGRADE: a log created at the current schema, every later
  addition DROPPED and user_version set back -- so the file is what a
  schema-2 build wrote, not a hand-built imitation of it.

  IT USED TO DROP ONLY THE v3 COLUMNS (R4, 2026-10-23), and left schema 4's
  message.edited in place: every "schema-2" log here was a 2 + 4 hybrid, so
  nothing tested a 2 -> 4 open that has to make both changes at once. The
  shared DowngradeTestLog removes every later addition. *)
procedure TLogMyFactsTests.DowngradeToSchema2(const aFileName: string;
                                              aFirstDropped: integer);
begin
   DowngradeTestLog(aFileName, 2, aFirstDropped);
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
   BeginTest('a new log is schema 3 or later and its qso table ends with the v3 columns');
   (* 4 since Q113 added message.edited; the qso table is unchanged by it. *)
   CheckTrue(LOG_SCHEMA_VERSION >= 3, 'the schema this build writes includes v3');
   fn := TempLogName('new3.db');
   Scrub(fn);

   db := TLogDatabase.Create;
   try
      db.CreateNew(fn);
      CheckEquals(LOG_SCHEMA_VERSION, db.SchemaVersion, 'a new log is stamped current');
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
   BeginTest('opening a schema-2 log stamps the current schema into the file, which older builds refuse');
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
      CheckEquals(LOG_SCHEMA_VERSION, db.SchemaVersion,
                  'after one Open the FILE says the current schema -- a schema-2 build refuses it');
   finally
      db.Free;
   end;
   Scrub(fn);
end;

(* R4: A GENUINE SCHEMA-2 LOG NEEDS BOTH LATER MIGRATIONS IN ONE OPEN -- the
  v3 my_* columns AND v4's message.edited -- and keeps the rows it had in
  both tables. Every earlier "schema-2" fixture still carried
  message.edited, so this open was never tested. A second open is a no-op. *)
procedure TLogMyFactsTests.TestASchema2LogNeedsBothMigrationsAtOnce;
var
   db: TLogDatabase;
   repo: TLogRepository;
   qso, back: ContestExchange;
   fn: string;
   rowId: Int64;
   q: TSQLQuery;
   columnsAfterFirst: string;
begin
   BeginTest('a schema-2 log gains the v3 AND v4 columns in one open, keeping its rows');
   fn := TempLogName('migrate2to4.db');
   Scrub(fn);

   db := TLogDatabase.Create;
   try
      db.CreateNew(fn);
      repo := TLogRepository.Create(db);
      try
         MakeQSO(qso, 2);
         rowId := repo.SaveQSO(qso);
         repo.SaveMessage('CQ', 'CW', 'F3', 'WRITTEN BY SCHEMA 2', 'CAP2');
         repo.Commit;
      finally
         repo.Free;
      end;
   finally
      db.Free;
   end;

   DowngradeTestLog(fn, 2, Low(LOG_V3_QSO_COLUMNS));
   db := TLogDatabase.Create;
   try
      db.OpenReadOnly(fn);
      CheckEquals(2, db.SchemaVersion, 'the fixture is stamped 2');
      CheckFalse(TestLogHasColumn(db, 'qso', 'my_source'), 'with no v3 column');
      CheckFalse(TestLogHasColumn(db, 'message', 'edited'),
                 'and no v4 column -- a genuine schema-2 file');
   finally
      db.Free;
   end;

   db := TLogDatabase.Create;
   try
      db.Open(fn);
      CheckEquals(LOG_SCHEMA_VERSION, db.SchemaVersion, 'one open migrates 2 to current');
      CheckTrue(TestLogHasColumn(db, 'qso', 'my_source'), 'the v3 columns are added');
      CheckTrue(TestLogHasColumn(db, 'message', 'edited'), 'and the v4 column');
      repo := TLogRepository.Create(db);
      try
         CheckTrue(repo.LoadQSO(rowId, back), 'the QSO row survived');
         CheckEquals(string(qso.Callsign), string(back.Callsign), 'intact');
      finally
         repo.Free;
      end;
      q := TSQLQuery.Create(nil);
      try
         q.DataBase := db.Connection;
         q.UsePrimaryKeyAsKey := False;
         q.SQL.Text := 'SELECT text, caption, edited FROM message ' +
                       'WHERE kind = ''CQ'' AND mode = ''CW'' AND key_id = ''F3''';
         q.Open;
         CheckFalse(q.EOF, 'the message row survived');
         CheckEquals('WRITTEN BY SCHEMA 2', q.Fields[0].AsString, 'its text');
         CheckEquals('CAP2', q.Fields[1].AsString, 'its caption');
         CheckEquals(0, q.Fields[2].AsInteger,
                     'and it is not an edit: an older build never recorded one');
         q.Close;
      finally
         q.Free;
      end;
   finally
      db.Free;
   end;
   columnsAfterFirst := QsoColumnNames(fn);

   (* IDEMPOTENT: a second open finds nothing to do and fails on nothing. *)
   db := TLogDatabase.Create;
   try
      db.Open(fn);
      CheckEquals(LOG_SCHEMA_VERSION, db.SchemaVersion, 'a second open keeps the version');
   finally
      db.Free;
   end;
   CheckEquals(columnsAfterFirst, QsoColumnNames(fn), 'and adds no column');
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
            repo.AppendBatch(appends, failedAt);
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

(* --------------------------------------------------------------- the ADIF *)

(* One ADIF record through the import's own steps: the lexer, the generic
  field mapping, and the two stage-2 readers. *)
procedure TLogMyFactsTests.ParseOneRecord(const aADIF: string;
                                          out aQso: ContestExchange;
                                          out aFacts: TQsoMyFacts;
                                          out aSent: AnsiString);
var
   fields: TADIFFieldList;
   temps: TADIFRecordTemps;
begin
   InitContestExchangeForParse(aQso);
   ParseADIFFieldsList(aADIF, fields);
   ApplyADIFFieldsToExchange(fields, aQso, temps);
   aFacts := MyFactsFromADIF(temps);
   aSent := SentExchangeFromADIF(temps);
end;

const
   (* EVERY MY_* TAG THE IMPORT READS, each a different value. *)
   ADIF_WITH_MY_TAGS =
      '<CALL:4>W1AW <BAND:3>20m <MODE:2>CW <QSO_DATE:8>20261001 ' +
      '<TIME_ON:4>1200 <OPERATOR:5>K9OPS <STATION_CALLSIGN:6>NY4I/R ' +
      '<MY_GRIDSQUARE:6>EN01ab <MY_STATE:2>ne <MY_CNTY:3>LAN ' +
      '<MY_ARRL_SECT:2>NE <MY_IOTA:6>NA-001 <MY_CQ_ZONE:1>4 ' +
      '<MY_ITU_ZONE:1>7 <MY_DXCC:3>291 <MY_POTA_REF:7>US-1234 ' +
      '<STX_STRING:6>599 NE <EOR>';

   (* NOTHING OF OURS -- the shape of every D7 reference in the corpus. *)
   ADIF_WITHOUT_MY_TAGS =
      '<CALL:4>W1AW <BAND:3>20m <MODE:2>CW <QSO_DATE:8>20261001 ' +
      '<TIME_ON:4>1200 <EOR>';

procedure TLogMyFactsTests.TestTheImportReadsEveryMYTag;
var
   qso: ContestExchange;
   facts: TQsoMyFacts;
   sent: AnsiString;
begin
   BeginTest('an ADIF import reads every MY_ tag into the row''s station, as imported');
   ParseOneRecord(ADIF_WITH_MY_TAGS, qso, facts, sent);
   CheckEquals(Ord(mfsImported), Ord(facts.Source), 'the source is the file');
   CheckEquals('NY4I/R', string(facts.Call), 'STATION_CALLSIGN is our call as signed');
   CheckEquals('EN01ab', string(facts.Grid), 'MY_GRIDSQUARE, as written');
   CheckEquals('NE', string(facts.State), 'MY_STATE');
   CheckEquals('LAN', string(facts.County), 'MY_CNTY');
   CheckEquals('NE', string(facts.Section), 'MY_ARRL_SECT');
   CheckEquals('NA-001', string(facts.Iota), 'MY_IOTA');
   CheckEquals(4, facts.CQZone, 'MY_CQ_ZONE');
   CheckEquals(7, facts.ITUZone, 'MY_ITU_ZONE');
   CheckEquals('K', string(facts.Country), 'MY_DXCC 291 is the CTY entity K');
   CheckEquals('US-1234', string(facts.Park), 'MY_POTA_REF is the park');
   CheckEquals('', string(facts.Continent), 'ADIF carries no continent of ours');
   CheckEquals('K9OPS', string(qso.ceOperator), 'and OPERATOR is still the operator');
end;

(* A RECORD THAT NAMES NO MY_ FIELD SAYS NOTHING ABOUT OUR STATION -- NY4I,
  2026-10-18, replacing stage 2's "imported, unknown": the IMPORTER then gives
  it this contest's values (TestTheImportRule...). The reader itself borrows
  nothing: the station's grid is set while the record is read, to prove it. *)
procedure TLogMyFactsTests.TestAnAbsentTagIsUnknownNotTodaysValue;
var
   qso: ContestExchange;
   facts: TQsoMyFacts;
   sent: AnsiString;
   savedGrid: string;
begin
   BeginTest('a record with no MY_ tags names no station, and the reader borrows none');
   savedGrid := Settings.My.Grid;
   Settings.My.Grid := 'FN31PR';
   try
      ParseOneRecord(ADIF_WITHOUT_MY_TAGS, qso, facts, sent);
   finally
      Settings.My.Grid := savedGrid;
   end;
   CheckEquals(Ord(mfsNotCaptured), Ord(facts.Source),
               'the file named no station of ours, and says so');
   CheckFalse(MyFactsValuesDiffer(facts, NotCapturedMyFacts),
              'and nothing was borrowed from settings by the reader');
   CheckEquals('', string(sent), 'and it sent nothing the file says');
end;

procedure TLogMyFactsTests.TestAStationCallAloneNamesNoStation;
var
   qso: ContestExchange;
   facts: TQsoMyFacts;
   sent: AnsiString;
begin
   BeginTest('STATION_CALLSIGN alone is not a MY_ field: the record names no station');
   ParseOneRecord('<CALL:4>W1AW <OPERATOR:5>K9OPS <STATION_CALLSIGN:4>NY4I <EOR>',
                  qso, facts, sent);
   CheckEquals(Ord(mfsNotCaptured), Ord(facts.Source),
               'written whenever someone else operated; it says nothing of where');
end;

(* NY4I'S IMPORT RULE (2026-10-18), POINT BY POINT -- the pure part,
  uQsoMyFacts.MyFactsForImport and the report's two questions. *)
procedure TLogMyFactsTests.TestTheImportRule;
var
   contest, fileFacts, partial, got: TQsoMyFacts;
begin
   BeginTest('an import gives a QSO the contest''s station unless the operator keeps the file''s');
   contest := SampleFacts;
   contest.Grid := 'EM17';
   contest.State := 'KS';

   (* 1. THE FILE NAMED NONE: the contest's, stamped, as a new QSO. *)
   got := MyFactsForImport(NotCapturedMyFacts, contest, True);
   CheckEquals(Ord(mfsStamped), Ord(got.Source), '1: named none -- stamped');
   CheckEquals('EM17', string(got.Grid), '1: with the contest''s grid');
   got := MyFactsForImport(NotCapturedMyFacts, contest, False);
   CheckEquals('EM17', string(got.Grid), '1: whatever the answer was');

   (* 2. THE FILE NAMED SOME: yes keeps the file's, no stamps the contest's. *)
   fileFacts := SampleFacts;
   fileFacts.Source := mfsImported;
   got := MyFactsForImport(fileFacts, contest, True);
   CheckEquals(Ord(mfsImported), Ord(got.Source), '2 yes: imported');
   CheckEquals('EN01AB', string(got.Grid), '2 yes: the file''s grid');
   got := MyFactsForImport(fileFacts, contest, False);
   CheckEquals(Ord(mfsStamped), Ord(got.Source), '2 no: stamped');
   CheckEquals('EM17', string(got.Grid), '2 no: the contest''s grid');
   CheckEquals('KS', string(got.State), '2 no: and every other field the contest''s');

   (* 4. SOME MY_ TAGS BUT NO GRID: yes leaves the grid UNKNOWN; no stamps it. *)
   partial := NotCapturedMyFacts;
   partial.Source := mfsImported;
   partial.State := 'NE';
   got := MyFactsForImport(partial, contest, True);
   CheckEquals('', string(got.Grid), '4 yes: the grid the file did not name is unknown');
   CheckEquals('NE', string(got.State), '4 yes: and the state it named is kept');
   got := MyFactsForImport(partial, contest, False);
   CheckEquals('EM17', string(got.Grid), '4 no: the grid is the contest''s');
   CheckEquals('KS', string(got.State), '4 no: as is the state');
end;

(* THE REPORT: which fields a file named, and where they differ from the
  contest's -- only the fields it named, case aside. *)
procedure TLogMyFactsTests.TestTheImportReportsWhatDiffers;
var
   contest, fileFacts: TQsoMyFacts;
   differing: TMyFactFields;
begin
   BeginTest('the import reports the MY_ fields a file names and those that differ');
   contest := SampleFacts;
   fileFacts := NotCapturedMyFacts;
   fileFacts.Source := mfsImported;
   fileFacts.Grid := 'EN02AB';
   fileFacts.State := 'ne';
   CheckTrue(MyFactsFieldsPresent(fileFacts) = [mffGrid, mffState],
             'the file named a grid and a state, nothing else');
   differing := MyFactsFieldsDiffering(fileFacts, contest);
   CheckTrue(differing = [mffGrid], 'the grid differs; NE against ne does not');
   CheckTrue(MyFactsFieldsPresent(NotCapturedMyFacts) = [],
             'a record that named nothing names no field');
   CheckTrue(MyFactsFieldsDiffering(contest, contest) = [],
             'the contest''s own values differ from nothing');
   CheckEquals('MY_GRIDSQUARE', MyFactFieldTag(mffGrid), 'a field''s ADIF tag');
   CheckEquals('4', string(MyFactFieldValue(contest, mffCQZone)), 'a zone as text');
end;

procedure TLogMyFactsTests.TestSigInfoIsAParkOnlyUnderPOTA;
var
   qso: ContestExchange;
   facts: TQsoMyFacts;
   sent: AnsiString;
begin
   BeginTest('MY_SIG_INFO is our park only under MY_SIG POTA');
   ParseOneRecord('<CALL:4>W1AW <MY_SIG:4>POTA <MY_SIG_INFO:7>US-0002 <EOR>',
                  qso, facts, sent);
   CheckEquals('US-0002', string(facts.Park), 'under POTA it is the park');
   ParseOneRecord('<CALL:4>W1AW <MY_SIG:4>SOTA <MY_SIG_INFO:9>W4G/NG-001 <EOR>',
                  qso, facts, sent);
   CheckEquals('', string(facts.Park), 'a SOTA summit is not a park');
   ParseOneRecord('<CALL:4>W1AW <MY_SIG:4>POTA <MY_SIG_INFO:7>US-0002 ' +
                  '<MY_POTA_REF:7>US-1234 <EOR>', qso, facts, sent);
   CheckEquals('US-1234', string(facts.Park), 'and MY_POTA_REF wins when both are there');
end;

procedure TLogMyFactsTests.TestADXCCCodeMapsToOnePlainEntity;
begin
   BeginTest('a MY_DXCC code maps to the one plain CTY entity that carries it');
   CheckEquals('K', string(CTYEntityOfADIFDXCC(291)), '291 is K');
   CheckEquals('VE', string(CTYEntityOfADIFDXCC(1)), '1 is VE');
   (* '*GM/s' (Shetland) is credited to 279 with 'GM'; a starred prefix is a
     CTY-only region, not an entity of its own. *)
   CheckEquals('GM', string(CTYEntityOfADIFDXCC(279)), '279 is GM, not *GM/s');
   CheckEquals('', string(CTYEntityOfADIFDXCC(0)), '0 is no entity');
   CheckEquals('', string(CTYEntityOfADIFDXCC(9999)), 'an unknown code is unknown');
end;

(* THE D3 FIX AT THE READER: the sent exchange is the record's STX_STRING. *)
procedure TLogMyFactsTests.TestTheSentExchangeIsTheRecordsSTXString;
var
   qso: ContestExchange;
   facts: TQsoMyFacts;
   sent: AnsiString;
begin
   BeginTest('an imported QSO sent what its STX_STRING says, and nothing else');
   ParseOneRecord(ADIF_WITH_MY_TAGS, qso, facts, sent);
   CheckEquals('599 NE', string(sent), 'STX_STRING, verbatim');
end;

procedure TLogMyFactsTests.TestANeverCapturedRowWritesNoMYTags;
var
   qso: ContestExchange;
begin
   BeginTest('a row that never recorded its station writes no MY_ tag of its own');
   MakeQSO(qso, 1);
   qso.ceOperator := 'K9OPS';
   CheckEquals('', EmitADIFMyStationFields(qso, NotCapturedMyFacts, ''),
               'nothing -- so a pre-schema-3 log exports exactly as it did');
end;

procedure TLogMyFactsTests.TestACapturedRowWritesItsTagsInOrder;
var
   qso: ContestExchange;
begin
   BeginTest('a captured row writes its own MY_ tags, in a fixed order');
   MakeQSO(qso, 1);
   qso.ceOperator := 'K9OPS';
   CheckEquals('<STATION_CALLSIGN:6>NY4I/R <MY_GRIDSQUARE:6>EN01AB ' +
               '<MY_STATE:2>NE <MY_CNTY:3>LAN <MY_ARRL_SECT:2>NE ' +
               '<MY_IOTA:6>NA-001 <MY_CQ_ZONE:1>4 <MY_ITU_ZONE:1>7 ' +
               '<MY_DXCC:3>291 <MY_SIG:4>POTA <MY_SIG_INFO:7>US-1234 ' +
               '<MY_POTA_REF:7>US-1234 ',
               EmitADIFMyStationFields(qso, SampleFacts, ''),
               'every value the row holds, the park last');
end;

procedure TLogMyFactsTests.TestATagTheContestWroteIsNotWrittenTwice;
var
   qso: ContestExchange;
   tags: string;
begin
   BeginTest('a MY_ tag the contest already wrote is not written again');
   MakeQSO(qso, 1);
   (* POTA writes its park, and MY_STATE and MY_DXCC from its park list. *)
   tags := EmitADIFMyStationFields(qso, SampleFacts,
                                   '<MY_SIG:4>POTA <MY_SIG_INFO:7>US-1234 ' +
                                   '<MY_POTA_REF:7>US-1234 <MY_STATE:2>ME <MY_DXCC:3>291 ');
   CheckEquals(0, Pos('<MY_STATE:', tags), 'MY_STATE is the contest''s');
   CheckEquals(0, Pos('<MY_DXCC:', tags), 'MY_DXCC is the contest''s');
   CheckEquals(0, Pos('<MY_SIG', tags), 'and so is the park');
   CheckEquals(0, Pos('<MY_POTA_REF:', tags), 'all of it');
   CheckTrue(Pos('<MY_GRIDSQUARE:', tags) > 0, 'the rest are still written');
   (* STATE is the worked station's and must not hide MY_STATE. *)
   tags := EmitADIFMyStationFields(qso, SampleFacts, '<STATE:2>CT ');
   CheckTrue(Pos('<MY_STATE:', tags) > 0, 'STATE is not MY_STATE');
end;

procedure TLogMyFactsTests.TestTheStationCallFollowsTheOperatorRule;
var
   qso: ContestExchange;
   facts: TQsoMyFacts;
begin
   BeginTest('STATION_CALLSIGN is written when someone else operated, as it always was');
   MakeQSO(qso, 1);
   facts := SampleFacts;
   qso.ceOperator := 'NY4I/R';
   CheckEquals(0, Pos('STATION_CALLSIGN', EmitADIFMyStationFields(qso, facts, '')),
               'not when the operator is the station');
   qso.ceOperator := '';
   CheckEquals(0, Pos('STATION_CALLSIGN', EmitADIFMyStationFields(qso, facts, '')),
               'not when no operator is recorded');
   qso.ceOperator := 'K9OPS';
   CheckTrue(Pos('<STATION_CALLSIGN:6>NY4I/R', EmitADIFMyStationFields(qso, facts, '')) > 0,
             'and from the record''s call when someone else did');
end;

(* IMPORT, THEN EXPORT, THEN IMPORT AGAIN: our station survives the trip. *)
procedure TLogMyFactsTests.TestTheMYTagsSurviveARoundTrip;
var
   qso, again: ContestExchange;
   facts, back: TQsoMyFacts;
   sent: AnsiString;
   records: TContestExchangeArray;
   recordFacts: TQsoMyFactsArray;
   adif, body: string;
   at: integer;
begin
   BeginTest('MY_ tags imported, exported and imported again come back unchanged');
   ParseOneRecord(ADIF_WITH_MY_TAGS, qso, facts, sent);

   SetLength(records, 1);
   records[0] := qso;
   SetLength(recordFacts, 1);
   recordFacts[0] := facts;
   adif := ExportADIFToString(records, recordFacts, nil, 'roundtrip', nil);

   (* The record after the header. *)
   at := Pos('<EOH>', UpperCase(adif));
   CheckTrue(at > 0, 'the export has a header');
   body := Copy(adif, at + 5, MaxInt);
   ParseOneRecord(body, again, back, sent);
   CheckFactsEqual(facts, back, 'the station after the round trip');
   CheckEquals('W1AW', string(again.Callsign), 'and the QSO is the same QSO');
end;

(* ------------------------------------------- the export reads the record *)

(* D5: OUR CALL ON A LOGGED QSO IS THE RECORD'S, then the log's, then today's. *)
procedure TLogMyFactsTests.TestTheExportCallFollowsTheRecord;
var
   facts: TQsoMyFacts;
begin
   BeginTest('a logged QSO''s call is its own, else the log''s declared, else today''s');
   facts := SampleFacts;
   CheckEquals('NY4I/R', string(ExportCallOf(facts, 'NY4I', 'K9NOW')),
               'the call the QSO recorded -- a rover''s, suffix and all');
   facts.Call := '';
   CheckEquals('NY4I', string(ExportCallOf(facts, 'NY4I', 'K9NOW')),
               'a QSO that recorded no call: the call the log declared');
   CheckEquals('NY4I', string(ExportCallOf(NotCapturedMyFacts, 'NY4I', 'K9NOW')),
               'a QSO from before schema 3: the log''s, not today''s');
   CheckEquals('K9NOW', string(ExportCallOf(NotCapturedMyFacts, '', 'K9NOW')),
               'and today''s only when the log declared none');
end;

(* AN IMPORTED QSO'S STX_STRING IS WRITTEN BACK AS ITS FILE SAID IT. *)
procedure TLogMyFactsTests.TestAnImportedQSOSentWhatItsFileSays;
var
   facts: TQsoMyFacts;
begin
   BeginTest('an imported QSO''s sent exchange is its file''s; a live one''s is rebuilt');
   facts := SampleFacts;
   facts.Source := mfsImported;
   CheckEquals('1 TOM FL', string(RecordedSentExchange(facts, '1 TOM FL')),
               'imported with the file''s station: what the file sent');
   facts.Source := mfsStamped;
   CheckEquals('1 TOM FL', string(RecordedSentExchange(facts, '1 TOM FL')),
               'imported and given the contest''s station: still what the file sent');
   CheckEquals('', string(RecordedSentExchange(facts, '')),
               'a file that carried no STX_STRING: built');
   facts.Source := mfsLogged;
   CheckEquals('', string(RecordedSentExchange(facts, '599 05')),
               'logged here: exchange_sent is the canonical spelling, so built');
   facts.Source := mfsEdited;
   CheckEquals('', string(RecordedSentExchange(facts, '1 TOM FL')),
               'an operator corrected its station: built from the correction');
   CheckEquals('', string(RecordedSentExchange(NotCapturedMyFacts, '1 TOM FL')),
               'a row from before schema 3: the session''s, as before');
end;

(* THE SENT EXCHANGE OF A LOGGED QSO, FROM ITS RECORD. *)
procedure TLogMyFactsTests.TestTheSentExchangeIsBuiltFromTheRecord;
var
   session, got: TMyStationExchange;
   facts: TQsoMyFacts;
begin
   BeginTest('a logged QSO''s sent exchange is built from where its station was');
   session := Default(TMyStationExchange);
   session.MyState := 'FL';
   session.MyGrid := 'EL88';
   session.MyName := 'TOM';
   session.MyZone := '05';
   session.MySection := 'WCF';
   session.MyPark := 'US-0001';
   session.MyCheck := '72';

   got := MyStationExchangeOfQSO(session, NotCapturedMyFacts, True, False);
   CheckEquals('FL', got.MyState, 'never captured: the session''s state');
   CheckEquals('EL88', got.MyGrid, 'never captured: the session''s grid');
   CheckEquals('05', got.MyZone, 'never captured: the session''s zone, as typed');

   facts := SampleFacts;   (* EN01AB, NE, section NE, park US-1234, CQ 4, ITU 7 *)
   got := MyStationExchangeOfQSO(session, facts, True, False);
   CheckEquals('EN01AB', got.MyGrid, 'the QSO''s grid');
   CheckEquals('NE', got.MyState, 'the QSO''s state, where the session sends MY STATE');
   CheckEquals('NE', got.MySection, 'the QSO''s section');
   CheckEquals('US-1234', got.MyPark, 'the QSO''s park');
   CheckEquals('4', got.MyZone, 'the QSO''s CQ zone');
   CheckEquals('TOM', got.MyName, 'the name the record holds no column for: the session''s');
   CheckEquals('72', got.MyCheck, 'and the check');

   got := MyStationExchangeOfQSO(session, facts, False, True);
   CheckEquals('FL', got.MyState,
               'a contest that sends something else in the state slot keeps it');
   CheckEquals('7', got.MyZone, 'an ITU-zone contest sends the QSO''s ITU zone');

   facts.CQZone := 5;
   got := MyStationExchangeOfQSO(session, facts, True, False);
   CheckEquals('05', got.MyZone, 'the same zone keeps the session''s text: 05, not 5');

   facts.CQZone := 0;
   facts.Grid := '';
   got := MyStationExchangeOfQSO(session, facts, True, False);
   CheckEquals('', got.MyZone, 'an unknown zone is sent as none, never the session''s');
   CheckEquals('', got.MyGrid, 'an unknown grid likewise');
end;

(* -------------------------------------------------------------- the store *)

(* A D7 fixture copied to a scratch .trw and made the store's log -- driven
  exactly as uTestLogStore drives it, so the first write migrates it and the
  log holds 101 rows that never recorded a station. *)
procedure TLogMyFactsTests.StartStore(const aLeaf: string);
var
   source, target: TFileStream;
begin
   LogStoreClose;
   FTrw := TempLogName(aLeaf);
   FDb := LogDatabaseFileName(FTrw);
   Scrub(FDb);
   source := TFileStream.Create(ExtractFilePath(ParamStr(0)) + 'fixtures' +
                                PathDelim + 'binarylog' + PathDelim + FIXTURE_SET +
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
   FSavedSilent := tSilentExport;
   SetCharBuffer(TR4W_LOG_FILENAME, FTrw);
   (* A failure is a log line and a False, not a modal. *)
   tSilentExport := True;
end;

procedure TLogMyFactsTests.StopStore;
begin
   LogStoreClose;
   SetCharBuffer(TR4W_LOG_FILENAME, FSavedLogName);
   tSilentExport := FSavedSilent;
   Scrub(FDb);
   if FileExists(FTrw) then
      begin
      DeleteFile(FTrw);
      end;
end;

(* THE STORE, AS A QSO IS LOGGED: one QSO this station logged, and one that
  arrived from a multi-op peer, beside 101 migrated rows. *)
procedure TLogMyFactsTests.TestTheStoreCapturesOurStationAtTheMomentOfTheQSO;
var
   savedGrid, savedOverride: string;
   savedStated: boolean;
   qso: ContestExchange;
   facts: TQsoMyFacts;
   logDb: TLogDatabase;
   repo: TLogRepository;
   ourGrid: AnsiString;
   q: TSQLQuery;
   qsoPeerSerial: integer;
begin
   BeginTest('the store records our station as it was when each QSO was logged');

   StartStore(FIXTURE_SET + '.trw');
   savedGrid := Settings.My.Grid;
   savedStated := Settings.My.HasContestOverride(sfGrid);
   savedOverride := Settings.My.ContestOverride(sfGrid);
   try
      (* THE STATION'S GRID, with no contest override in the way. *)
      Settings.My.ClearContestOverride(sfGrid);
      Settings.My.Grid := 'EN01AB';
      ourGrid := UTF8Encode(Settings.My.ResolvedGrid);

      MakeQSO(qso, 1);
      qso.ceComputerID := Settings.Computer.Id;
      (* What the exchange builder falls back to with no CQ template, so a
        sent exchange is built for BOTH rows unless the store refuses one. *)
      qso.ExchString := '599 05';
      CheckTrue(LogStoreAppendQSO(qso), 'our QSO is logged');

      (* THE ROVER MOVES -- and the next QSO is a peer's. *)
      Settings.My.Grid := 'EN02AB';
      MakeQSO(qso, 2);
      (* THE PEER'S SERIAL, which only the packet's record knows. *)
      qso.NumberSent := 4321;
      qsoPeerSerial := qso.NumberSent;
      qso.ExchString := '599 05';
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
         logDb.OpenReadOnly(FDb);
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

         (* D4 (stage 5): WHAT EACH ROW SENT. Ours, built as it was logged;
           the peer's, unknown -- the V1 packet does not carry it, and this
           station's CQ template is not the peer's. *)
         q := TSQLQuery.Create(nil);
         try
            q.DataBase := logDb.Connection;
            q.UsePrimaryKeyAsKey := False;
            q.SQL.Text := 'SELECT IFNULL(exchange_sent, ''<null>''), ' +
                          'IFNULL(serial_sent, -1) FROM qso ORDER BY id ' +
                          'LIMIT 2 OFFSET 101';
            q.Open;
            CheckTrue(q.Fields[0].AsString <> '<null>',
                      'our QSO recorded the exchange it sent');
            q.Next;
            CheckEquals('<null>', q.Fields[0].AsString,
                        'a peer''s QSO records no sent exchange of ours');
            CheckEquals(qsoPeerSerial, q.Fields[1].AsInteger,
                        'and keeps the peer''s own serial, from the packet''s record');
            q.Close;
         finally
            q.Free;
         end;
      finally
         logDb.Free;
      end;
   finally
      Settings.My.Grid := savedGrid;
      if savedStated then
         begin
         Settings.My.SetContestOverride(sfGrid, savedOverride);
         end;
      StopStore;
   end;
end;

(* EDIT QSO's TWO CALLS, as the editor makes them: read our station at a
  record position, and write the QSO and its station back as one transaction. *)
procedure TLogMyFactsTests.TestTheEditorReadsAndWritesThroughTheStore;
var
   qso: ContestExchange;
   facts, edited: TQsoMyFacts;
   logDb: TLogDatabase;
   repo: TLogRepository;
   back: ContestExchange;
begin
   BeginTest('Edit QSO reads and writes our station through the store');

   StartStore(FIXTURE_SET + '-edit.trw');
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
         logDb.OpenReadOnly(FDb);
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
      StopStore;
   end;
end;

(* THE D3 FIX, THROUGH THE STORE: an ADIF import's batch writes each row's
  OWN sent exchange and station -- and a row whose file said nothing sends
  nothing, though this station has a CQ exchange and a grid of its own. *)
procedure TLogMyFactsTests.TestAnImportBatchNeverTakesTheLiveStation;
var
   appends: TLogQsoAppends;
   qso: ContestExchange;
   facts: TQsoMyFacts;
   failedAt: integer;
   failure: string;
   logDb: TLogDatabase;
   repo: TLogRepository;
   q: TSQLQuery;
   savedGrid: string;
begin
   BeginTest('an import batch writes each row''s own sent exchange and station, never the live ones');

   StartStore(FIXTURE_SET + '-import.trw');
   savedGrid := Settings.My.Grid;
   try
      Settings.My.Grid := 'FN31PR';
      appends := TLogQsoAppends.Create;
      try
         MakeQSO(qso, 1);
         facts := SampleFacts;
         facts.Source := mfsImported;
         appends.Add(qso, facts, '599 NE');
         MakeQSO(qso, 2);
         facts := NotCapturedMyFacts;
         facts.Source := mfsImported;
         appends.Add(qso, facts, '');
         CheckTrue(LogStoreAppendQSOs(appends, failedAt, failure),
                   'the batch is written: ' + failure);
      finally
         appends.Free;
      end;
      LogStoreClose;

      logDb := TLogDatabase.Create;
      try
         logDb.OpenReadOnly(FDb);
         repo := TLogRepository.Create(logDb);
         try
            CheckEquals(103, repo.QSOCount, '101 migrated QSOs and the two imported');
            CheckTrue(repo.LoadQSOMyFacts(repo.RowIdAtIndex(101), facts), 'row 1');
            CheckEquals(Ord(mfsImported), Ord(facts.Source), 'row 1 is imported');
            CheckEquals('EN01AB', string(facts.Grid), 'with its file''s grid');
            CheckTrue(repo.LoadQSOMyFacts(repo.RowIdAtIndex(102), facts), 'row 2');
            CheckEquals('', string(facts.Grid),
                        'row 2''s file named no grid, and it does not get today''s');
         finally
            repo.Free;
         end;

         q := TSQLQuery.Create(nil);
         try
            q.DataBase := logDb.Connection;
            q.UsePrimaryKeyAsKey := False;
            q.SQL.Text := 'SELECT IFNULL(exchange_sent, ''<null>'') FROM qso ' +
                          'ORDER BY id LIMIT 2 OFFSET 101';
            q.Open;
            CheckEquals('599 NE', q.Fields[0].AsString, 'row 1 sent its STX_STRING');
            q.Next;
            CheckEquals('<null>', q.Fields[0].AsString,
                        'row 2 sent nothing -- not this station''s exchange (D3)');
            q.Close;
         finally
            q.Free;
         end;
      finally
         logDb.Free;
      end;
   finally
      Settings.My.Grid := savedGrid;
      StopStore;
   end;
end;

(* A NOTE IS NOT A QSO (stage 5): no station of ours, no exchange we sent. *)
procedure TLogMyFactsTests.TestANoteRecordsNoStation;
var
   note: ContestExchange;
   facts: TQsoMyFacts;
   logDb: TLogDatabase;
   repo: TLogRepository;
   q: TSQLQuery;
begin
   BeginTest('a note in the log records no station of ours and no sent exchange');
   StartStore(FIXTURE_SET + '-note.trw');
   try
      MakeQSO(note, 1);
      note.ceRecordKind := rkNote;
      note.ceComputerID := Settings.Computer.Id;
      SetNoteText(note, 'a note, not a contact');
      CheckTrue(LogStoreAppendQSO(note), 'the note is logged');
      LogStoreClose;

      logDb := TLogDatabase.Create;
      try
         logDb.OpenReadOnly(FDb);
         repo := TLogRepository.Create(logDb);
         try
            CheckTrue(repo.LoadQSOMyFacts(repo.RowIdAtIndex(101), facts), 'the note''s row');
            CheckEquals(Ord(mfsNotCaptured), Ord(facts.Source),
                        'a note records no station of ours');
         finally
            repo.Free;
         end;
         q := TSQLQuery.Create(nil);
         try
            q.DataBase := logDb.Connection;
            q.UsePrimaryKeyAsKey := False;
            q.SQL.Text := 'SELECT IFNULL(exchange_sent, ''<null>''), record_kind ' +
                          'FROM qso ORDER BY id LIMIT 1 OFFSET 101';
            q.Open;
            CheckEquals('NOTE', UpperCase(q.Fields[1].AsString), 'the row is the note');
            CheckEquals('<null>', q.Fields[0].AsString, 'and it sent nothing');
            q.Close;
         finally
            q.Free;
         end;
      finally
         logDb.Free;
      end;
   finally
      StopStore;
   end;
end;

(* A PEER'S EDIT OF ITS OWN QSO (NET_EDITEDQSO -> FindAndUpdateQSOInLog ->
  LogStoreUpdateQSOBySessionIds) changes what the QSO says and nothing about
  our station: the row stays ASSUMED, its exchange_sent stays as it was, and
  nothing is re-stamped from this station. *)
procedure TLogMyFactsTests.TestAPeersEditKeepsItsProvenance;
var
   db: TLogDatabase;
   repo: TLogRepository;
   qso: ContestExchange;
   facts, assumed: TQsoMyFacts;
   q: TSQLQuery;
   fn: string;
   rowId: Int64;
begin
   BeginTest('a peer''s edit of its QSO keeps the row assumed and its sent exchange');
   fn := TempLogName('peeredit.db');
   Scrub(fn);
   db := TLogDatabase.Create;
   try
      db.CreateNew(fn);
      repo := TLogRepository.Create(db);
      try
         MakeQSO(qso, 1);
         assumed := SampleFacts;
         assumed.Source := mfsAssumed;
         repo.SetNextMyFacts(assumed);
         repo.SetNextSentExchange('599 KS');
         rowId := repo.SaveQSO(qso);
         repo.Commit;

         (* THE PEER EDITS IT: a different serial and points. *)
         qso.NumberSent := 77;
         qso.QSOPoints := 3;
         CheckTrue(repo.UpdateQSOBySessionIds(qso.ceQSOID1, qso.ceQSOID2, qso),
                   'the network update found the row');
         repo.Commit;

         CheckTrue(repo.LoadQSOMyFacts(rowId, facts), 'the row is there');
         CheckFactsEqual(assumed, facts, 'its station after the peer''s edit');
         q := TSQLQuery.Create(nil);
         try
            q.DataBase := db.Connection;
            q.UsePrimaryKeyAsKey := False;
            q.SQL.Text := 'SELECT IFNULL(exchange_sent, ''<null>''), serial_sent ' +
                          'FROM qso WHERE id = ' + IntToStr(rowId);
            q.Open;
            CheckEquals('599 KS', q.Fields[0].AsString, 'its sent exchange is untouched');
            CheckEquals(77, q.Fields[1].AsInteger, 'and the edit itself landed');
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
   TestASchema2LogNeedsBothMigrationsAtOnce;

   TestTheFactsAreCapturedOnInsert;
   TestTheNextSaveIsNotCaptured;
   TestAnEditKeepsThem;
   TestTheEditorWriteChangesThem;
   TestARescoreAndANetworkUpdateKeepThem;
   TestAnAppendBatchCarriesEachRowsOwn;
   TestAPeersEditKeepsItsProvenance;

   TestTheImportReadsEveryMYTag;
   TestAnAbsentTagIsUnknownNotTodaysValue;
   TestSigInfoIsAParkOnlyUnderPOTA;
   TestAStationCallAloneNamesNoStation;
   TestTheImportRule;
   TestTheImportReportsWhatDiffers;
   TestADXCCCodeMapsToOnePlainEntity;
   TestTheSentExchangeIsTheRecordsSTXString;
   TestANeverCapturedRowWritesNoMYTags;
   TestACapturedRowWritesItsTagsInOrder;
   TestATagTheContestWroteIsNotWrittenTwice;
   TestTheStationCallFollowsTheOperatorRule;
   TestTheMYTagsSurviveARoundTrip;
   TestTheExportCallFollowsTheRecord;
   TestAnImportedQSOSentWhatItsFileSays;
   TestTheSentExchangeIsBuiltFromTheRecord;

{$IFDEF WINDOWS}
   (* As the LogStore suite: these migrate a D7 binary log, which is a
     Windows migration path. *)
   TestTheStoreCapturesOurStationAtTheMomentOfTheQSO;
   TestTheEditorReadsAndWritesThroughTheStore;
   TestAnImportBatchNeverTakesTheLiveStation;
   TestANoteRecordsNoStation;
{$ELSE}
   WriteLn('  SKIPPED (store half): migrates a D7 binary log, a Windows migration path.');
{$ENDIF}

   if (FDir <> '') and RemoveDir(FDir) then
      begin
      FDir := '';
      end;
end;

end.
