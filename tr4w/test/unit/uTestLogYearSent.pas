(* THE LICENCE YEAR A QSO SENT IS ITS ROW'S -- issue 300, LOG SCHEMA 8
  (NY4I, 2026-11-13: "a QSO record depends on nothing but its own row").

  Until schema 8 a QSO logged in a contest that sends the year (the European
  HF Championship, KVP) recorded no year, and every export sent the contest's
  CURRENT year for it. qso.year_sent holds the year as the contest sends it
  (85, 1985, or a count), NULL when it sent none. WHAT IS PINNED HERE:

    the rule        SentLicenseYearValue is SentLicenseYearText's number;
                    SentYearSourceOf says where a new row's year comes from
                    (ours, a peer's, a file's, none)
    the reader      MyStationExchangeOfQSO sends the ROW's year; a captured
                    row with none sends none (never ours); a never-captured
                    row with none falls back to the session (ruling A); 0 is
                    the year 00
    the column      a round trip keeps 0 apart from NULL, and a
                    never-captured row's year is read
    the migration   a schema-7 log gains year_sent in ONE commit and is
                    marked for the backfill when it holds rows, not when empty
    the backfill    fills exactly the rows whose export was rebuilt from the
                    session, never a peer's or a file's, and runs once
    the correction  the Preferences correction touches this station's QSOs
                    that sent the old year, and nothing else
    Edit / import   ApplyEditedSentYear and ApplyImportedSentYear

  The scope test that pinned the OLD behaviour ("a logged QSO exports the
  contest's current year") is flipped in uTestLicenseYearScope. *)
unit uTestLogYearSent;

{$I ..\..\src\tr4w.inc}

interface

uses
   uTR4WTestFramework;

type
   TLogYearSentTests = class(TTestCase)
   private
      FDir: string;
      function TempLogName(const aLeaf: string): string;
   protected
      procedure Test_TheValueIsTheTextsNumber;
      procedure Test_WhereANewRowsYearComesFrom;
      procedure Test_TheExportSendsTheRowsYear;
      procedure Test_TheColumnKeepsZeroApartFromNone;
      procedure Test_ASchema7LogGainsTheColumnInOneCommit;
      procedure Test_TheBackfillFillsOnlyRebuiltRowsOnce;
      procedure Test_TheCorrectionTouchesOnlyOurOldYear;
      procedure Test_TheCorrectionIsOfferedOnlyForAChangeAsSent;
      procedure Test_EditAndImportReadTheYearByTheKind;
   public
      procedure RunAllTests; override;
   end;

implementation

uses
   SysUtils,
   VC,
   uLogDatabase, uLogSchema, uLogRepository,
   uQsoMyFacts,
   uContestBase,
   uContestRegistry,       (* ContestHandleOf *)
   uLicenseYearChange,     (* LicenseYearCorrectionOf *)
   uTestLatestContest,     (* MakeTestContestLog, DowngradeTestLog, ScrubTestLog, TestLogHasColumn *)
   uTestLogDatabase,       (* CommitFramesInWal *)
   uTestLogReceivedYear;   (* MakeRow, QueryText *)

const
   YEAR_SENT_SQL = 'SELECT group_concat(IFNULL(year_sent, ''N''), '','') ' +
                   'FROM (SELECT year_sent FROM qso ORDER BY id)';

function TLogYearSentTests.TempLogName(const aLeaf: string): string;
begin
   if FDir = '' then
      begin
      FDir := IncludeTrailingPathDelimiter(GetTempDir) +
              'tr4w_yearsent_' + IntToStr(GetProcessID);
      ForceDirectories(FDir);
      end;
   Result := IncludeTrailingPathDelimiter(FDir) + aLeaf;
   ScrubTestLog(Result);
end;

(* Facts of aSource with a year (aYear >= 0) or none (aYear < 0). *)
function Facts(aSource: TQsoMyFactsSource; aYear: integer): TQsoMyFacts;
begin
   Result := NotCapturedMyFacts;
   Result.Source := aSource;
   SetFactsYearSent(Result, aYear >= 0, aYear);
end;

(* One QSO row saved with its station and sent exchange; aKind 'NOTE' writes a
  note record instead. *)
procedure SaveRow(aRepo: TLogRepository; aSeed: integer; const aFacts: TQsoMyFacts;
                  const aSent: AnsiString; aNote: boolean = False);
var
   rec: ContestExchange;
begin
   rec := MakeRow(aSeed, 255);
   if aNote then
      begin
      rec.ceRecordKind := rkNote;
      end;
   aRepo.SetNextMyFacts(aFacts);
   aRepo.SetNextSentExchange(aSent);
   aRepo.SaveQSO(rec);
end;

procedure TLogYearSentTests.Test_TheValueIsTheTextsNumber;
var
   v: integer;
begin
   BeginTest('SentLicenseYearValue is the number SentLicenseYearText writes');
   CheckTrue(SentLicenseYearValue(rykTwoDigitYear, '1964', 2026, v), 'a four-digit setting');
   CheckEquals(64, v, 'two digits of it');
   CheckTrue(SentLicenseYearValue(rykTwoDigitYear, '64', 2026, v), 'a two-digit setting');
   CheckEquals(64, v, 'the same');
   CheckTrue(SentLicenseYearValue(rykTwoDigitYear, '2000', 2026, v), 'the year 2000');
   CheckEquals(0, v, '00 is the number 0, a real year');
   CheckEquals('00', SentLicenseYearText(rykTwoDigitYear, '2000', 2026), 'written 00');
   CheckTrue(SentLicenseYearValue(rykFourDigitYear, '85', 2026, v), 'two digits, four-digit kind');
   CheckEquals(1985, v, 'the year itself');
   CheckTrue(SentLicenseYearValue(rykYearsLicensed, '1985', 2026, v), 'a count from a year');
   CheckEquals(41, v, 'years licensed');
   CheckFalse(SentLicenseYearValue(rykTwoDigitYear, '', 2026, v), 'no setting: none');
   CheckEquals(NO_RECEIVED_YEAR, v, 'and the value says none');
   CheckFalse(SentLicenseYearValue(rykNone, '1985', 2026, v), 'a contest that sends none');
   CheckEquals('', SentLicenseYearText(rykNone, '1985', 2026), 'and writes none');
end;

procedure TLogYearSentTests.Test_WhereANewRowsYearComesFrom;
begin
   BeginTest('SentYearSourceOf: ours, a peer''s, a file''s, or none');
   CheckEquals(Ord(sysThisStation), Ord(SentYearSourceOf(True, mfsLogged)), 'logged here');
   CheckEquals(Ord(sysThisStation), Ord(SentYearSourceOf(True, mfsEdited)), 'edited here');
   CheckEquals(Ord(sysPeer), Ord(SentYearSourceOf(True, mfsAssumed)),
               'a peer''s QSO: the peer''s year, never ours');
   CheckEquals(Ord(sysFile), Ord(SentYearSourceOf(True, mfsImported)), 'imported');
   CheckEquals(Ord(sysFile), Ord(SentYearSourceOf(True, mfsStamped)), 'stamped');
   CheckEquals(Ord(sysNone), Ord(SentYearSourceOf(True, mfsNotCaptured)), 'a note');
   CheckEquals(Ord(sysNone), Ord(SentYearSourceOf(False, mfsLogged)),
               'a contest that sends no year');
end;

procedure TLogYearSentTests.Test_TheExportSendsTheRowsYear;
var
   session, my: TMyStationExchange;
begin
   BeginTest('the export sends the year the ROW sent, formatted by the kind');
   session := Default(TMyStationExchange);
   session.MyZone := '90';     (* the contest's year NOW *)

   my := MyStationExchangeOfQSO(session, Facts(mfsLogged, 64), False,
                                szkStatedMyZone, rykTwoDigitYear);
   CheckEquals('64', my.MyZone, 'a logged row: its own year, not the contest''s 90');

   my := MyStationExchangeOfQSO(session, Facts(mfsLogged, 0), False,
                                szkStatedMyZone, rykTwoDigitYear);
   CheckEquals('00', my.MyZone, 'the year 00 is a year');

   my := MyStationExchangeOfQSO(session, Facts(mfsAssumed, -1), False,
                                szkStatedMyZone, rykTwoDigitYear);
   CheckEquals('90', my.MyZone,
               'a peer''s row with no year (the packet carries none): the session''s, ' +
               'as before schema 8 -- the column stays NULL, nothing is invented');

   my := MyStationExchangeOfQSO(session, Facts(mfsLogged, -1), False,
                                szkStatedMyZone, rykTwoDigitYear);
   CheckEquals('', my.MyZone, 'a row logged here that sent none: none');

   my := MyStationExchangeOfQSO(session, Facts(mfsNotCaptured, -1), False,
                                szkStatedMyZone, rykTwoDigitYear);
   CheckEquals('90', my.MyZone, 'a never-captured row with no year: the session (ruling A)');

   my := MyStationExchangeOfQSO(session, Facts(mfsNotCaptured, 75), False,
                                szkStatedMyZone, rykTwoDigitYear);
   CheckEquals('75', my.MyZone, 'a backfilled never-captured row: its own year');

   my := MyStationExchangeOfQSO(session, Facts(mfsLogged, 1964), False,
                                szkStatedMyZone, rykFourDigitYear);
   CheckEquals('1964', my.MyZone, 'a four-digit contest writes four digits');

   session.MyZone := '5';
   my := MyStationExchangeOfQSO(session, Facts(mfsLogged, 64), False, szkCQZone);
   CheckEquals('', my.MyZone,
               'a zone contest (the default kind) is untouched by a year: zone 0 is unknown');
end;

procedure TLogYearSentTests.Test_TheColumnKeepsZeroApartFromNone;
var
   fn: string;
   db: TLogDatabase;
   repo: TLogRepository;
   got: TQsoMyFacts;
begin
   BeginTest('year_sent round-trips: 0 is a year, NULL is none, a never-captured row''s is read');
   fn := TempLogName('roundtrip.db');
   MakeTestContestLog(fn, ContestHandleOf(EUROPEANHFC), '');
   db := TLogDatabase.Create;
   try
      db.Open(fn);
      repo := TLogRepository.Create(db);
      try
         SaveRow(repo, 1, Facts(mfsLogged, 0), '');
         SaveRow(repo, 2, Facts(mfsLogged, -1), '');
         SaveRow(repo, 3, Facts(mfsNotCaptured, 85), '');
         repo.Commit;

         CheckEquals('0,N,85', QueryText(db, YEAR_SENT_SQL), 'as stored');
         CheckTrue(repo.LoadQSOMyFacts(repo.RowIdAtIndex(0), got), 'row 1');
         CheckTrue(got.YearSentKnown, '0 reads as a year');
         CheckEquals(0, got.YearSent, 'the year 00');
         CheckTrue(repo.LoadQSOMyFacts(repo.RowIdAtIndex(1), got), 'row 2');
         CheckFalse(got.YearSentKnown, 'NULL reads as none');
         CheckTrue(repo.LoadQSOMyFacts(repo.RowIdAtIndex(2), got), 'row 3');
         CheckEquals(Ord(mfsNotCaptured), Ord(got.Source), 'still never captured');
         CheckTrue(got.YearSentKnown and (got.YearSent = 85), 'but its year is read');

         (* EDIT QSO's WRITE, for a year alone: the station stays never
           captured, the year changes. *)
         got := Facts(mfsNotCaptured, 90);
         CheckTrue(repo.UpdateQSOMyFacts(repo.RowIdAtIndex(2), got), 'the edit''s write');
         repo.Commit;
         CheckEquals('0,N,90', QueryText(db, YEAR_SENT_SQL), 'the year corrected');
         CheckEquals('', QueryText(db, 'SELECT IFNULL(my_source, '''') FROM qso ' +
                                       'ORDER BY id LIMIT 1 OFFSET 2'),
                     'and my_source is still NULL');
      finally
         repo.Free;
      end;
   finally
      db.Free;
   end;
   ScrubTestLog(fn);
end;

procedure TLogYearSentTests.Test_ASchema7LogGainsTheColumnInOneCommit;
var
   fn, empty: string;
   db: TLogDatabase;
   repo: TLogRepository;
begin
   BeginTest('a schema-7 log gains year_sent and the backfill mark in one commit');
   fn := TempLogName('seven.db');
   MakeTestContestLog(fn, ContestHandleOf(EUROPEANHFC), '');
   db := TLogDatabase.Create;
   try
      db.Open(fn);
      repo := TLogRepository.Create(db);
      try
         SaveRow(repo, 1, Facts(mfsLogged, -1), '');
         repo.Commit;
      finally
         repo.Free;
      end;
   finally
      db.Free;
   end;
   DowngradeTestLog(fn, 7, Low(LOG_V3_QSO_COLUMNS));
   CheckFalse(FileExists(fn + '-wal'), 'precondition: no WAL is left by the fixture');

   db := TLogDatabase.Create;
   try
      db.Open(fn);
      CheckEquals(1, CommitFramesInWal(fn + '-wal'), 'the column, the mark and the stamp: ONE commit');
      CheckEquals(8, db.SchemaVersion, 'stamped 8');
      CheckTrue(TestLogHasColumn(db, 'qso', 'year_sent'), 'the column');
      CheckEquals('1', QueryText(db, 'SELECT value FROM session_state WHERE key = ''' +
                                     LOG_YEAR_SENT_BACKFILL_KEY + ''''),
                  'and the mark, for the store''s backfill');
      CheckEquals('N', QueryText(db, YEAR_SENT_SQL), 'the row holds no year yet');
   finally
      db.Free;
   end;
   ScrubTestLog(fn);

   (* AN EMPTY LOG HAS NOTHING TO FILL: no mark. *)
   empty := TempLogName('seven-empty.db');
   MakeTestContestLog(empty, ContestHandleOf(EUROPEANHFC), '');
   DowngradeTestLog(empty, 7, Low(LOG_V3_QSO_COLUMNS));
   db := TLogDatabase.Create;
   try
      db.Open(empty);
      CheckTrue(TestLogHasColumn(db, 'qso', 'year_sent'), 'the column');
      CheckEquals('', QueryText(db, 'SELECT value FROM session_state WHERE key = ''' +
                                    LOG_YEAR_SENT_BACKFILL_KEY + ''''),
                  'no mark on an empty log');
   finally
      db.Free;
   end;
   ScrubTestLog(empty);
end;

procedure TLogYearSentTests.Test_TheBackfillFillsOnlyRebuiltRowsOnce;
var
   fn: string;
   db: TLogDatabase;
   repo: TLogRepository;
   imported, stamped: TQsoMyFacts;
begin
   BeginTest('the backfill fills the rows whose export was the session''s, once');
   fn := TempLogName('backfill.db');
   MakeTestContestLog(fn, ContestHandleOf(EUROPEANHFC), '');
   db := TLogDatabase.Create;
   try
      db.Open(fn);
      repo := TLogRepository.Create(db);
      try
         imported := Facts(mfsImported, -1);
         stamped := Facts(mfsStamped, -1);
         SaveRow(repo, 1, Facts(mfsLogged, -1), '599 64');       (* filled *)
         SaveRow(repo, 2, Facts(mfsNotCaptured, -1), '');        (* filled *)
         SaveRow(repo, 3, Facts(mfsEdited, -1), '');             (* filled *)
         SaveRow(repo, 4, Facts(mfsAssumed, -1), '');            (* a peer's: never *)
         SaveRow(repo, 5, imported, '599 77');                   (* its file's text: never *)
         SaveRow(repo, 6, stamped, '');                          (* rebuilt: filled *)
         SaveRow(repo, 7, Facts(mfsLogged, 90), '');             (* has one: kept *)
         SaveRow(repo, 8, NotCapturedMyFacts, '', True);         (* a note: never *)
         repo.SaveSessionValue(LOG_YEAR_SENT_BACKFILL_KEY, '1');
         repo.Commit;

         CheckEquals(4, repo.BackfillYearSent(True, 64), 'four rows filled');
         repo.Commit;
         CheckEquals('64,64,64,N,N,64,90,N', QueryText(db, YEAR_SENT_SQL), 'exactly those');
         CheckEquals(-1, repo.BackfillYearSent(True, 85), 'the mark is gone: never again');
         CheckEquals('64,64,64,N,N,64,90,N', QueryText(db, YEAR_SENT_SQL), 'nothing moved');

         (* A CONTEST THAT SENDS NO YEAR: the mark goes, nothing is filled. *)
         repo.SaveSessionValue(LOG_YEAR_SENT_BACKFILL_KEY, '1');
         repo.Commit;
         CheckEquals(0, repo.BackfillYearSent(False, 0), 'no year to give');
         repo.Commit;
         CheckEquals(-1, repo.BackfillYearSent(True, 64), 'and the mark is gone');
      finally
         repo.Free;
      end;
   finally
      db.Free;
   end;
   ScrubTestLog(fn);
end;

procedure TLogYearSentTests.Test_TheCorrectionTouchesOnlyOurOldYear;
var
   fn: string;
   db: TLogDatabase;
   repo: TLogRepository;
begin
   BeginTest('the correction sets THIS station''s QSOs that sent the old year, and no other');
   fn := TempLogName('correct.db');
   MakeTestContestLog(fn, ContestHandleOf(EUROPEANHFC), '');
   db := TLogDatabase.Create;
   try
      db.Open(fn);
      repo := TLogRepository.Create(db);
      try
         SaveRow(repo, 1, Facts(mfsLogged, 64), '');       (* corrected *)
         SaveRow(repo, 2, Facts(mfsLogged, 90), '');       (* another year: kept *)
         SaveRow(repo, 3, Facts(mfsNotCaptured, 64), '');  (* backfilled: corrected *)
         SaveRow(repo, 4, Facts(mfsAssumed, 64), '');      (* a peer's: kept *)
         SaveRow(repo, 5, Facts(mfsImported, 64), '');     (* a file's: kept *)
         SaveRow(repo, 6, Facts(mfsLogged, -1), '');       (* sent none *)
         repo.Commit;

         CheckEquals(2, repo.CountQSOsSentYear(True, 64), 'two of ours sent 64');
         CheckEquals(1, repo.CountQSOsSentYear(False, 0), 'one of ours sent none');
         CheckEquals(2, repo.CorrectSentYear(True, 64, True, 85), 'two corrected');
         repo.Commit;
         CheckEquals('85,90,85,64,64,N', QueryText(db, YEAR_SENT_SQL), 'exactly those');
         CheckEquals(1, repo.CorrectSentYear(False, 0, True, 85), 'the one that sent none');
         repo.Commit;
         CheckEquals('85,90,85,64,64,85', QueryText(db, YEAR_SENT_SQL), 'given the year');
      finally
         repo.Free;
      end;
   finally
      db.Free;
   end;
   ScrubTestLog(fn);
end;

procedure TLogYearSentTests.Test_TheCorrectionIsOfferedOnlyForAChangeAsSent;
var
   c: TLicenseYearCorrection;
begin
   BeginTest('LicenseYearCorrectionOf offers a correction only for a change in what is sent');
   CheckTrue(LicenseYearCorrectionOf(rykTwoDigitYear, '1964', '1985', 2026, c), 'a new year');
   CheckTrue(c.OldKnown and (c.OldValue = 64), 'from 64');
   CheckTrue(c.NewKnown and (c.NewValue = 85), 'to 85');
   CheckFalse(LicenseYearCorrectionOf(rykTwoDigitYear, '1964', '64', 2026, c),
              'the same year spelled differently: nothing to correct');
   CheckTrue(LicenseYearCorrectionOf(rykTwoDigitYear, '', '1985', 2026, c), 'a first year');
   CheckFalse(c.OldKnown, 'the QSOs that sent none');
   CheckTrue(LicenseYearCorrectionOf(rykTwoDigitYear, '1985', '', 2026, c), 'a cleared year');
   CheckFalse(c.NewKnown, 'to none');
   CheckFalse(LicenseYearCorrectionOf(rykNone, '1964', '1985', 2026, c),
              'a contest that sends no year');
end;

procedure TLogYearSentTests.Test_EditAndImportReadTheYearByTheKind;
var
   q: ContestExchange;
   f: TQsoMyFacts;
begin
   BeginTest('Edit QSO and the ADIF import read a sent year by the contest''s kind');
   q := MakeRow(1, 255);
   q.RSTSent := 599;

   f := Facts(mfsLogged, 64);
   CheckTrue(ApplyEditedSentYear(rykTwoDigitYear, '85', q, f), 'a two-digit year');
   CheckTrue(f.YearSentKnown and (f.YearSent = 85), 'stored 85');
   CheckTrue(ApplyEditedSentYear(rykTwoDigitYear, '', q, f), 'empty is allowed');
   CheckFalse(f.YearSentKnown, 'and is none');
   f := Facts(mfsLogged, 64);
   CheckFalse(ApplyEditedSentYear(rykTwoDigitYear, '1985', q, f), 'four digits in a two-digit contest');
   CheckTrue(f.YearSentKnown and (f.YearSent = 64), 'refused: unchanged');
   CheckFalse(ApplyEditedSentYear(rykTwoDigitYear, 'x', q, f), 'not a year');
   CheckTrue(ApplyEditedSentYear(rykNone, 'anything', q, f), 'no kind: nothing to check');
   CheckTrue(f.YearSentKnown and (f.YearSent = 64), 'and nothing changed');

   f := NotCapturedMyFacts;
   ApplyImportedSentYear(rykTwoDigitYear, '599 77', q, True, 64, f);
   CheckTrue(f.YearSentKnown and (f.YearSent = 77), 'the STX_STRING''s year');
   f := NotCapturedMyFacts;
   ApplyImportedSentYear(rykTwoDigitYear, '599', q, True, 64, f);
   CheckTrue(f.YearSentKnown and (f.YearSent = 64), 'none in the file: the contest''s');
   f := NotCapturedMyFacts;
   ApplyImportedSentYear(rykTwoDigitYear, '', q, False, 0, f);
   CheckFalse(f.YearSentKnown, 'none anywhere: none');
   f := Facts(mfsLogged, 64);
   ApplyImportedSentYear(rykNone, '599 77', q, True, 64, f);
   CheckFalse(f.YearSentKnown, 'a contest that sends no year stores none');

   (* THE STATION ANSWER NEVER MOVES THE RECORD'S YEAR. *)
   f := MyFactsForImport(Facts(mfsImported, 77), Facts(mfsLogged, 64), False);
   CheckEquals(Ord(mfsStamped), Ord(f.Source), 'the contest''s station chosen');
   CheckTrue(f.YearSentKnown and (f.YearSent = 77), 'the year is still the file''s');
end;

procedure TLogYearSentTests.RunAllTests;
begin
   Test_TheValueIsTheTextsNumber;
   Test_WhereANewRowsYearComesFrom;
   Test_TheExportSendsTheRowsYear;
   Test_TheColumnKeepsZeroApartFromNone;
   Test_ASchema7LogGainsTheColumnInOneCommit;
   Test_TheBackfillFillsOnlyRebuiltRowsOnce;
   Test_TheCorrectionTouchesOnlyOurOldYear;
   Test_TheCorrectionIsOfferedOnlyForAChangeAsSent;
   Test_EditAndImportReadTheYearByTheKind;
end;

end.
