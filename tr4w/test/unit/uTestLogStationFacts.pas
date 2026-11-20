(* EVERY STATION FACT IS WRITTEN TO THE QSO RECORD -- LOG SCHEMA 9 (NY4I,
  2026-11-17: "ALL MY_ VALUES GET WRITTEN TO THE QSO RECORD").

  Schema 3 kept our grid, state, section, park, IOTA and zones on the QSO and
  left the name, FD class, Sweepstakes check and precedence, postal code and
  FOC number to TODAY's settings at export. Found on the bench: a Sweepstakes
  precedence changed after logging rewrote the sent line of every QSO already
  in the log. WHAT IS PINNED HERE:

    the table       every TStationFact is kept in a column the qso table has,
                    or named as not per-QSO with a reason -- the omission
                    cannot happen silently again
    the capture     LogStoreCurrentMyFacts records each fact kept as typed
    the column      a round trip keeps each value (a Cyrillic name, a '07'
                    check); a captured empty is unknown; a never-captured row
                    reads nothing
    the migration   a schema-8 log gains the six columns in ONE commit, and is
                    marked for the backfill only when a row captured its station
    the backfill    fills exactly the captured rows' NULLs, once
    the reader      MyStationExchangeOfQSO sends the ROW's values; the
                    Sweepstakes sent line keeps the precedence it was logged
                    with after the setting changes
    the import      MY_NAME and MY_POSTAL_CODE are read; the four facts ADIF
                    has no tag for are the contest's *)
unit uTestLogStationFacts;

{$I ..\..\src\tr4w.inc}

interface

uses
   uTR4WTestFramework;

type
   TLogStationFactsTests = class(TTestCase)
   private
      FDir: string;
      function TempLogName(const aLeaf: string): string;
   protected
      procedure Test_EveryStationFactIsKeptOrExplained;
      procedure Test_TheStoreCapturesEveryFactKeptAsTyped;
      procedure Test_TheColumnsRoundTrip;
      procedure Test_ASchema8LogGainsTheColumnsInOneCommit;
      procedure Test_TheBackfillFillsOnlyCapturedRowsOnce;
      procedure Test_TheExportReadsTheRowNotToday;
      procedure Test_ASweepstakesPrecedenceChangedAfterLoggingIsNotSent;
      procedure Test_TheImportReadsWhatADIFCanName;
   public
      procedure RunAllTests; override;
   end;

implementation

uses
   SysUtils,
   VC,
   uLogDatabase, uLogSchema, uLogRepository,
   uQsoMyFacts,
   uSettingsModel,         (* Settings, TStationFact *)
   uStationFactRecord,     (* STATION_FACT_IN_RECORD *)
   uLogStore,              (* LogStoreCurrentMyFacts *)
   uContestBase,
   uContestRegistry,       (* ContestHandleOf, ContestIdentity *)
   uADIF,                  (* the import's parse steps *)
   uTestLatestContest,     (* MakeTestContestLog, DowngradeTestLog, ScrubTestLog, TestLogHasColumn *)
   uTestLogDatabase,       (* CommitFramesInWal *)
   uTestLogReceivedYear;   (* MakeRow, QueryText *)

const
   (* A Cyrillic name -- "Ivan" -- as UTF-16 code points, so this file stays
     ASCII. *)
   CYRILLIC_NAME = #$0418#$0432#$0430#$043D;

   PREC_SQL = 'SELECT group_concat(IFNULL(my_prec, ''N''), '','') ' +
              'FROM (SELECT my_prec FROM qso ORDER BY id)';
   CHECK_SQL = 'SELECT group_concat(IFNULL(my_check, ''N''), '','') ' +
               'FROM (SELECT my_check FROM qso ORDER BY id)';

type
   TOverrideState = record
      Stated: array[TStationFact] of boolean;
      Value: array[TStationFact] of string;
   end;

function SaveOverrides: TOverrideState;
var
   f: TStationFact;
begin
   for f := Low(TStationFact) to High(TStationFact) do
      begin
      Result.Stated[f] := Settings.My.HasContestOverride(f);
      Result.Value[f] := Settings.My.ContestOverride(f);
      end;
end;

procedure RestoreOverrides(const aState: TOverrideState);
var
   f: TStationFact;
begin
   for f := Low(TStationFact) to High(TStationFact) do
      begin
      if aState.Stated[f] then
         begin
         Settings.My.SetContestOverride(f, aState.Value[f]);
         end
      else
         begin
         Settings.My.ClearContestOverride(f);
         end;
      end;
end;

(* A distinctive value for each fact kept as typed. *)
function DistinctValue(aFact: TStationFact): string;
begin
   Result := '';
   case aFact of
      sfState:
         begin
         Result := 'NE';
         end;
      sfSection:
         begin
         Result := 'NNY';
         end;
      sfGrid:
         begin
         Result := 'EN01AB';
         end;
      sfName:
         begin
         Result := CYRILLIC_NAME;
         end;
      sfFdClass:
         begin
         Result := '3A';
         end;
      sfCheck:
         begin
         Result := '07';
         end;
      sfPrec:
         begin
         Result := 'Q';
         end;
      sfPark:
         begin
         Result := 'US-1234';
         end;
      sfIota:
         begin
         Result := 'NA-001';
         end;
      sfPostalCode:
         begin
         Result := 'K1A 0B1';
         end;
      sfFocNumber:
         begin
         Result := '1234';
         end;
   end;
end;

(* Captured facts carrying the six schema-9 values. *)
function SchemaNineFacts(aSource: TQsoMyFactsSource; const aPrec, aCheck: AnsiString): TQsoMyFacts;
begin
   Result := NotCapturedMyFacts;
   Result.Source := aSource;
   Result.Name := UTF8Encode(CYRILLIC_NAME);
   Result.FdClass := '2A';
   Result.Check := aCheck;
   Result.Prec := aPrec;
   Result.PostalCode := 'K1A 0B1';
   Result.FocNumber := '1234';
   (* And schema 13's two, so the same round trip holds them. *)
   Result.SentUnit := 'KIN';
   Result.RoverPlaces := 'KIN/QUE';
end;

procedure SaveRow(aRepo: TLogRepository; aSeed: integer; const aFacts: TQsoMyFacts;
                  aNote: boolean = False);
var
   rec: ContestExchange;
begin
   rec := MakeRow(aSeed, 255);
   if aNote then
      begin
      rec.ceRecordKind := rkNote;
      end;
   aRepo.SetNextMyFacts(aFacts);
   aRepo.SaveQSO(rec);
end;

function TLogStationFactsTests.TempLogName(const aLeaf: string): string;
begin
   if FDir = '' then
      begin
      FDir := IncludeTrailingPathDelimiter(GetTempDir) +
              'tr4w_stationfacts_' + IntToStr(GetProcessID);
      ForceDirectories(FDir);
      end;
   Result := IncludeTrailingPathDelimiter(FDir) + aLeaf;
   ScrubTestLog(Result);
end;

(* THE PIN THAT WOULD HAVE CAUGHT THIS. A TStationFact added to the
  enumeration does not compile until STATION_FACT_IN_RECORD has its row; this
  says the row is honest: a column the qso table really has, or a reason. *)
procedure TLogStationFactsTests.Test_EveryStationFactIsKeptOrExplained;
var
   fn: string;
   db: TLogDatabase;
   f: TStationFact;
   name: string;
   facts: TQsoMyFacts;
begin
   BeginTest('every station fact is kept on the QSO, or named as not per-QSO with a reason');
   fn := TempLogName('table.db');
   MakeTestContestLog(fn, ContestHandleOf(ARRLSSCW), '');
   db := TLogDatabase.Create;
   try
      db.Open(fn);
      for f := Low(TStationFact) to High(TStationFact) do
         begin
         name := 'fact ' + IntToStr(Ord(f)) + ' (' + STATION_FACT_IN_RECORD[f].Column + ')';
         if STATION_FACT_IN_RECORD[f].Keeping = sfkNotPerQso then
            begin
            CheckTrue(Trim(STATION_FACT_IN_RECORD[f].Reason) <> '',
                      name + ': not per-QSO, and says why');
            CheckEquals('', STATION_FACT_IN_RECORD[f].Column, name + ': and names no column');
            end
         else
            begin
            CheckTrue(STATION_FACT_IN_RECORD[f].Column <> '', name + ': names its column');
            CheckTrue(TestLogHasColumn(db, 'qso', STATION_FACT_IN_RECORD[f].Column),
                      name + ': a column a new log''s qso table has');
            end;

         (* A FACT KEPT AS TYPED ROUND-TRIPS THROUGH THE RECORD FIELD THE TABLE
           SENDS IT TO -- so the capture cannot drop one. *)
         if STATION_FACT_IN_RECORD[f].Keeping = sfkAsTyped then
            begin
            facts := NotCapturedMyFacts;
            RecordStationFactAsTyped(facts, f, DistinctValue(f));
            CheckEquals(DistinctValue(f), StationFactAsTypedOf(facts, f),
                        name + ': recorded and read back');
            end;
         end;
   finally
      db.Free;
   end;
   ScrubTestLog(fn);

   (* The three kept AS SENT, by name: the capture handles each one itself. *)
   CheckEquals('my_cq_zone', STATION_FACT_IN_RECORD[sfZone].Column, 'MY ZONE');
   CheckEquals('my_itu_zone', STATION_FACT_IN_RECORD[sfItuZone].Column, 'MY ITU ZONE');
   CheckEquals('year_sent', STATION_FACT_IN_RECORD[sfLicenseYear].Column,
               'MY LICENSE YEAR, as the contest sends it (issue 300)');
   CheckEquals('my_check', STATION_FACT_IN_RECORD[sfCheck].Column,
               'MY CHECK has a column of its own -- not year_sent (see uQsoMyFacts)');
end;

procedure TLogStationFactsTests.Test_TheStoreCapturesEveryFactKeptAsTyped;
var
   saved: TOverrideState;
   f: TStationFact;
   facts: TQsoMyFacts;
begin
   BeginTest('a QSO logged now records every fact kept as typed, as the contest resolves it');
   saved := SaveOverrides;
   try
      for f := Low(TStationFact) to High(TStationFact) do
         begin
         if STATION_FACT_IN_RECORD[f].Keeping = sfkAsTyped then
            begin
            Settings.My.SetContestOverride(f, DistinctValue(f));
            end;
         end;
      facts := LogStoreCurrentMyFacts;
      CheckEquals(Ord(mfsLogged), Ord(facts.Source), 'logged');
      for f := Low(TStationFact) to High(TStationFact) do
         begin
         if STATION_FACT_IN_RECORD[f].Keeping = sfkAsTyped then
            begin
            CheckEquals(DistinctValue(f), StationFactAsTypedOf(facts, f),
                        STATION_FACT_IN_RECORD[f].Column + ': the contest''s value now');
            end;
         end;
   finally
      RestoreOverrides(saved);
   end;
end;

procedure TLogStationFactsTests.Test_TheColumnsRoundTrip;
var
   fn: string;
   db: TLogDatabase;
   repo: TLogRepository;
   got, never: TQsoMyFacts;
begin
   BeginTest('the schema-9 columns round-trip; captured empty is unknown; never captured reads nothing');
   fn := TempLogName('roundtrip.db');
   MakeTestContestLog(fn, ContestHandleOf(ARRLSSCW), '');
   db := TLogDatabase.Create;
   try
      db.Open(fn);
      repo := TLogRepository.Create(db);
      try
         SaveRow(repo, 1, SchemaNineFacts(mfsLogged, 'A', '07'));
         SaveRow(repo, 2, SchemaNineFacts(mfsLogged, '', ''));
         never := SchemaNineFacts(mfsNotCaptured, 'B', '64');
         SaveRow(repo, 3, never);
         repo.Commit;

         CheckEquals('A,N,B', QueryText(db, PREC_SQL), 'as stored');
         CheckEquals('07,N,64', QueryText(db, CHECK_SQL), 'the check keeps its zero');

         CheckTrue(repo.LoadQSOMyFacts(repo.RowIdAtIndex(0), got), 'row 1');
         CheckEquals(Ord(mfsLogged), Ord(got.Source), 'captured');
         CheckEquals(CYRILLIC_NAME, UTF8Decode(got.Name), 'a Cyrillic name, intact');
         CheckEquals('2A', string(got.FdClass), 'the FD class');
         CheckEquals('07', string(got.Check), 'the check');
         CheckEquals('A', string(got.Prec), 'the precedence');
         CheckEquals('K1A 0B1', string(got.PostalCode), 'the postal code');
         CheckEquals('1234', string(got.FocNumber), 'the FOC number');
         CheckFalse(MyFactsValuesDiffer(got, SchemaNineFacts(mfsLogged, 'A', '07')),
                    'every value as written');

         CheckTrue(repo.LoadQSOMyFacts(repo.RowIdAtIndex(1), got), 'row 2');
         CheckEquals('', string(got.Prec), 'a captured empty precedence: unknown');

         CheckTrue(repo.LoadQSOMyFacts(repo.RowIdAtIndex(2), got), 'row 3');
         CheckEquals(Ord(mfsNotCaptured), Ord(got.Source), 'never captured');
         CheckEquals('', string(got.Prec), 'a never-captured row''s value is not read');

         (* EDIT QSO's WRITE carries the six. *)
         CheckTrue(repo.UpdateQSOMyFacts(repo.RowIdAtIndex(1),
                                         SchemaNineFacts(mfsEdited, 'U', '99')), 'an edit');
         repo.Commit;
         CheckTrue(repo.LoadQSOMyFacts(repo.RowIdAtIndex(1), got), 'row 2 again');
         CheckEquals(Ord(mfsEdited), Ord(got.Source), 'edited');
         CheckEquals('U', string(got.Prec), 'the edited precedence');
         CheckEquals('99', string(got.Check), 'the edited check');

         (* MyFactsValuesDiffer SEES EACH OF THE SIX -- the editor's test. *)
         got := SchemaNineFacts(mfsLogged, 'A', '07');
         never := got;
         never.FocNumber := '9';
         CheckTrue(MyFactsValuesDiffer(got, never), 'a FOC number changed');
         never := got;
         never.Name := 'TOM';
         CheckTrue(MyFactsValuesDiffer(got, never), 'a name changed');
      finally
         repo.Free;
      end;
   finally
      db.Free;
   end;
   ScrubTestLog(fn);
end;

procedure TLogStationFactsTests.Test_ASchema8LogGainsTheColumnsInOneCommit;
var
   fn, uncaptured: string;
   db: TLogDatabase;
   repo: TLogRepository;
   i: integer;
begin
   BeginTest('a schema-8 log gains the six columns and the backfill mark in one commit');
   fn := TempLogName('eight.db');
   MakeTestContestLog(fn, ContestHandleOf(ARRLSSCW), '');
   db := TLogDatabase.Create;
   try
      db.Open(fn);
      repo := TLogRepository.Create(db);
      try
         SaveRow(repo, 1, SchemaNineFacts(mfsLogged, 'A', '07'));
         SaveRow(repo, 2, NotCapturedMyFacts);
         repo.Commit;
      finally
         repo.Free;
      end;
   finally
      db.Free;
   end;
   DowngradeTestLog(fn, 8, Low(LOG_V3_QSO_COLUMNS));
   CheckFalse(FileExists(fn + '-wal'), 'precondition: no WAL is left by the fixture');

   db := TLogDatabase.Create;
   try
      db.Open(fn);
      CheckEquals(1, CommitFramesInWal(fn + '-wal'),
                  'the columns, the mark and the stamp: ONE commit');
      CheckEquals(LOG_SCHEMA_VERSION, db.SchemaVersion, 'stamped current (11 since the unused columns went)');
      for i := Low(LOG_V9_QSO_COLUMNS) to High(LOG_V9_QSO_COLUMNS) do
         begin
         CheckTrue(TestLogHasColumn(db, 'qso', string(LOG_V9_QSO_COLUMNS[i].Name)),
                   'the column ' + string(LOG_V9_QSO_COLUMNS[i].Name));
         end;
      CheckEquals('1', QueryText(db, 'SELECT value FROM session_state WHERE key = ''' +
                                     LOG_STATION_FACTS_BACKFILL_KEY + ''''),
                  'and the mark: a row had captured its station');
      CheckEquals('N,N', QueryText(db, PREC_SQL), 'no row holds a value yet');
   finally
      db.Free;
   end;
   ScrubTestLog(fn);

   (* A LOG WHOSE ROWS NEVER CAPTURED A STATION falls back anyway: no mark. *)
   uncaptured := TempLogName('eight-uncaptured.db');
   MakeTestContestLog(uncaptured, ContestHandleOf(ARRLSSCW), '');
   db := TLogDatabase.Create;
   try
      db.Open(uncaptured);
      repo := TLogRepository.Create(db);
      try
         SaveRow(repo, 1, NotCapturedMyFacts);
         repo.Commit;
      finally
         repo.Free;
      end;
   finally
      db.Free;
   end;
   DowngradeTestLog(uncaptured, 8, Low(LOG_V3_QSO_COLUMNS));
   db := TLogDatabase.Create;
   try
      db.Open(uncaptured);
      CheckTrue(TestLogHasColumn(db, 'qso', 'my_prec'), 'the column');
      CheckEquals('', QueryText(db, 'SELECT value FROM session_state WHERE key = ''' +
                                    LOG_STATION_FACTS_BACKFILL_KEY + ''''),
                  'no mark where no row captured a station');
   finally
      db.Free;
   end;
   ScrubTestLog(uncaptured);
end;

procedure TLogStationFactsTests.Test_TheBackfillFillsOnlyCapturedRowsOnce;
var
   fn: string;
   db: TLogDatabase;
   repo: TLogRepository;
   current: TQsoMyFacts;
begin
   BeginTest('the backfill fills the NULLs of the rows that captured a station, once');
   fn := TempLogName('backfill.db');
   MakeTestContestLog(fn, ContestHandleOf(ARRLSSCW), '');
   db := TLogDatabase.Create;
   try
      db.Open(fn);
      repo := TLogRepository.Create(db);
      try
         SaveRow(repo, 1, SchemaNineFacts(mfsLogged, '', ''));     (* filled *)
         SaveRow(repo, 2, SchemaNineFacts(mfsAssumed, '', ''));    (* a peer's: filled *)
         SaveRow(repo, 3, NotCapturedMyFacts);                     (* falls back: never *)
         SaveRow(repo, 4, SchemaNineFacts(mfsLogged, 'Q', '59'));  (* has one: kept *)
         SaveRow(repo, 5, SchemaNineFacts(mfsLogged, '', ''), True); (* a note: never *)
         repo.SaveSessionValue(LOG_STATION_FACTS_BACKFILL_KEY, '1');
         repo.Commit;

         current := SchemaNineFacts(mfsLogged, 'A', '07');
         CheckTrue(repo.BackfillStationFacts(current) >= 2, 'the captured QSO rows touched');
         repo.Commit;
         CheckEquals('A,A,N,Q,N', QueryText(db, PREC_SQL), 'exactly the captured NULLs');
         CheckEquals('07,07,N,59,N', QueryText(db, CHECK_SQL), 'the check alike');
         CheckEquals(-1, repo.BackfillStationFacts(SchemaNineFacts(mfsLogged, 'B', '64')),
                     'the mark is gone: never again');
         CheckEquals('A,A,N,Q,N', QueryText(db, PREC_SQL), 'nothing moved');

         (* AN EMPTY VALUE FILLS NOTHING -- the row exported nothing. *)
         repo.SaveSessionValue(LOG_STATION_FACTS_BACKFILL_KEY, '1');
         repo.Commit;
         current := SchemaNineFacts(mfsLogged, '', '');
         CheckTrue(repo.BackfillStationFacts(current) >= 0, 'ran');
         repo.Commit;
         CheckEquals('A,A,N,Q,N', QueryText(db, PREC_SQL), 'still nothing moved');
      finally
         repo.Free;
      end;
   finally
      db.Free;
   end;
   ScrubTestLog(fn);
end;

procedure TLogStationFactsTests.Test_TheExportReadsTheRowNotToday;
var
   session, my: TMyStationExchange;
begin
   BeginTest('the export reads each schema-9 value from the row, never from today');
   session := Default(TMyStationExchange);
   session.MyName := 'TODAY';
   session.MyFDClass := '9F';
   session.MyCheck := '99';
   session.MyPrec := 'B';
   session.MyPostalCode := 'TODAY';
   session.MyFOCNumber := '9999';

   my := MyStationExchangeOfQSO(session, SchemaNineFacts(mfsLogged, 'A', '07'), False, szkCQZone);
   CheckEquals(CYRILLIC_NAME, my.MyName, 'the row''s name, decoded');
   CheckEquals('2A', my.MyFDClass, 'the row''s class');
   CheckEquals('07', my.MyCheck, 'the row''s check');
   CheckEquals('A', my.MyPrec, 'the row''s precedence');
   CheckEquals('K1A 0B1', my.MyPostalCode, 'the row''s postal code');
   CheckEquals('1234', my.MyFOCNumber, 'the row''s FOC number');

   my := MyStationExchangeOfQSO(session, SchemaNineFacts(mfsLogged, '', ''), False, szkCQZone);
   CheckEquals('', my.MyPrec, 'a captured empty precedence: unknown, never today''s');

   my := MyStationExchangeOfQSO(session, SchemaNineFacts(mfsAssumed, 'A', '07'), False, szkCQZone);
   CheckEquals('A', my.MyPrec, 'a peer''s row: the values stamped when it arrived (ruling D)');

   my := MyStationExchangeOfQSO(session, NotCapturedMyFacts, False, szkCQZone);
   CheckEquals('B', my.MyPrec, 'a never-captured row: the session (ruling A)');
   CheckEquals('99', my.MyCheck, 'its check too');
end;

(* THE BENCH FINDING. A Sweepstakes QSO is logged with precedence A; the
  operator then changes MY PREC to B. The Cabrillo sent line built for that
  QSO -- from the stored row, through the exporter's own overlay -- still says
  A, and a QSO logged after the change says B. *)
procedure TLogStationFactsTests.Test_ASweepstakesPrecedenceChangedAfterLoggingIsNotSent;
var
   saved: TOverrideState;
   fn: string;
   db: TLogDatabase;
   repo: TLogRepository;
   qso: ContestExchange;
   facts: TQsoMyFacts;
   session, my: TMyStationExchange;
   ctx: TCabrilloQSOContext;
   sweepstakes: TContestBase;
   line: string;
begin
   BeginTest('Sweepstakes: a precedence changed after logging does not rewrite the sent line');
   saved := SaveOverrides;
   fn := TempLogName('sweepstakes.db');
   MakeTestContestLog(fn, ContestHandleOf(ARRLSSCW), '');
   sweepstakes := ContestIdentity(ContestHandleOf(ARRLSSCW));
   ctx := Default(TCabrilloQSOContext);
   db := TLogDatabase.Create;
   try
      db.Open(fn);
      repo := TLogRepository.Create(db);
      try
         Settings.My.SetContestOverride(sfPrec, 'A');
         Settings.My.SetContestOverride(sfCheck, '07');
         Settings.My.SetContestOverride(sfSection, 'WCF');

         (* LOGGED with A -- the capture the store makes for every QSO. *)
         qso := MakeRow(1, 255);
         qso.ceContest := ContestHandleOf(ARRLSSCW);
         qso.NumberSent := 12;
         repo.SetNextMyFacts(LogStoreCurrentMyFacts);
         repo.SaveQSO(qso);
         repo.Commit;

         (* THE OPERATOR CHANGES MY PREC, and logs another. *)
         Settings.My.SetContestOverride(sfPrec, 'B');
         qso := MakeRow(2, 255);
         qso.ceContest := ContestHandleOf(ARRLSSCW);
         qso.NumberSent := 13;
         repo.SetNextMyFacts(LogStoreCurrentMyFacts);
         repo.SaveQSO(qso);
         repo.Commit;

         (* THE EXPORT, later: today's session is B. *)
         session := Default(TMyStationExchange);
         session.MyPrec := Settings.My.ResolvedPrec;
         session.MyCheck := Settings.My.ResolvedCheck;
         session.MySection := Settings.My.ResolvedSection;
         CheckEquals('B', session.MyPrec, 'precondition: today''s precedence is B');

         CheckTrue(repo.LoadQSOMyFacts(repo.RowIdAtIndex(0), facts), 'the first QSO''s row');
         qso := MakeRow(1, 255);
         qso.ceContest := ContestHandleOf(ARRLSSCW);
         qso.NumberSent := 12;
         my := MyStationExchangeOfQSO(session, facts, False, szkCQZone);
         line := sweepstakes.FormatCabrilloSentExchange(my, qso, ctx);
         CheckEquals('12   A 07 WCF ', line, 'the first QSO still sent A');

         CheckTrue(repo.LoadQSOMyFacts(repo.RowIdAtIndex(1), facts), 'the second QSO''s row');
         qso.NumberSent := 13;
         my := MyStationExchangeOfQSO(session, facts, False, szkCQZone);
         line := sweepstakes.FormatCabrilloSentExchange(my, qso, ctx);
         CheckEquals('13   B 07 WCF ', line, 'the second QSO sent B');
      finally
         repo.Free;
      end;
   finally
      db.Free;
      RestoreOverrides(saved);
   end;
   ScrubTestLog(fn);
end;

procedure TLogStationFactsTests.Test_TheImportReadsWhatADIFCanName;
var
   fields: TADIFFieldList;
   temps: TADIFRecordTemps;
   qso: ContestExchange;
   facts, contest, chosen: TQsoMyFacts;
begin
   BeginTest('the import reads MY_NAME and MY_POSTAL_CODE; the rest are the contest''s');

   InitContestExchangeForParse(qso);
   ParseADIFFieldsList('<CALL:4>W1AW <BAND:3>20m <MODE:2>CW <QSO_DATE:8>20261001 ' +
                       '<TIME_ON:4>1200 <MY_GRIDSQUARE:4>EN01 <MY_NAME:3>Tom ' +
                       '<MY_POSTAL_CODE:5>68501 <EOR>', fields);
   ApplyADIFFieldsToExchange(fields, qso, temps);
   facts := MyFactsFromADIF(temps);
   CheckEquals(Ord(mfsImported), Ord(facts.Source), 'the file names our station');
   CheckEquals('Tom', string(facts.Name), 'MY_NAME, as written');
   CheckEquals('68501', string(facts.PostalCode), 'MY_POSTAL_CODE');

   (* MY_NAME ALONE NAMES THE OPERATOR, NOT THE STATION: nothing captured. *)
   InitContestExchangeForParse(qso);
   ParseADIFFieldsList('<CALL:4>W1AW <BAND:3>20m <MODE:2>CW <QSO_DATE:8>20261001 ' +
                       '<TIME_ON:4>1200 <MY_NAME:3>Tom <EOR>', fields);
   ApplyADIFFieldsToExchange(fields, qso, temps);
   CheckEquals(Ord(mfsNotCaptured), Ord(MyFactsFromADIF(temps).Source),
               'MY_NAME alone: the contest''s station is stamped');

   (* MY_POSTAL_CODE alone is a place: it counts. *)
   InitContestExchangeForParse(qso);
   ParseADIFFieldsList('<CALL:4>W1AW <BAND:3>20m <MODE:2>CW <QSO_DATE:8>20261001 ' +
                       '<TIME_ON:4>1200 <MY_POSTAL_CODE:5>68501 <EOR>', fields);
   ApplyADIFFieldsToExchange(fields, qso, temps);
   CheckEquals(Ord(mfsImported), Ord(MyFactsFromADIF(temps).Source),
               'MY_POSTAL_CODE alone names our station');

   (* THE OPERATOR KEEPS THE FILE'S: the four with no ADIF tag are the
      contest's, the two with one are the file's -- unknown when unnamed. *)
   contest := SchemaNineFacts(mfsLogged, 'A', '07');
   facts := NotCapturedMyFacts;
   facts.Source := mfsImported;
   facts.Grid := 'EN01';
   chosen := MyFactsForImport(facts, contest, True);
   CheckEquals(Ord(mfsImported), Ord(chosen.Source), 'the file''s');
   CheckEquals('A', string(chosen.Prec), 'precedence: the contest''s (no ADIF tag)');
   CheckEquals('07', string(chosen.Check), 'check: the contest''s');
   CheckEquals('2A', string(chosen.FdClass), 'FD class: the contest''s');
   CheckEquals('1234', string(chosen.FocNumber), 'FOC number: the contest''s');
   CheckEquals('', string(chosen.Name), 'the name the file did not name: unknown');
   CheckEquals('', string(chosen.PostalCode), 'the postal code likewise');

   (* THE CONTEST'S CHOSEN, or a file that named none: every value stamped. *)
   chosen := MyFactsForImport(facts, contest, False);
   CheckEquals(Ord(mfsStamped), Ord(chosen.Source), 'stamped');
   CheckEquals(CYRILLIC_NAME, UTF8Decode(chosen.Name), 'the contest''s name');
   CheckEquals('A', string(chosen.Prec), 'and precedence');
end;

procedure TLogStationFactsTests.RunAllTests;
begin
   Test_EveryStationFactIsKeptOrExplained;
   Test_TheStoreCapturesEveryFactKeptAsTyped;
   Test_TheColumnsRoundTrip;
   Test_ASchema8LogGainsTheColumnsInOneCommit;
   Test_TheBackfillFillsOnlyCapturedRowsOnce;
   Test_TheExportReadsTheRowNotToday;
   Test_ASweepstakesPrecedenceChangedAfterLoggingIsNotSent;
   Test_TheImportReadsWhatADIFCanName;
end;

end.
