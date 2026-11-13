(* THE RECEIVED YEAR IS A FIELD OF ITS OWN -- issue 298, STAGE 1 (2026-11-12).

  The year the other station was first licensed (or how many years it has been
  licensed) was stored in the zone slot (ContestExchange.Zone, rcvd_zone) by
  the European HF Championship and KVP. Stage 1 gives it a home of its own --
  ContestExchange.RcvdYear / RcvdYearKnown, column qso.rcvd_year (log schema
  6), carried in the multi-op QSO packet (network protocol 3) -- and changes no
  reader: uContestBase.StoreLicenceYear writes both, LicenceYearOf still reads
  the zone slot.

  WHAT IS PINNED HERE:
    - the record keeps "a year" and "no year" apart, and 0 is a year (00 =
      first licensed in 2000), through insert, read, update;
    - the schema 6 migration carries an EUHFC log's years out of rcvd_zone, row
      for row, in ONE commit; a zone contest's log gets none; with no contest
      judge assigned the log is refused and left as it was;
    - the .TRW reader clears the year bytes of a D7 record, and the import
      fills them from the zone slot for a year contest only;
    - the QSO packet carries the year out, and a QSO caught up from the
      server's log (the records the server stored from such packets) keeps it.
  The record's offsets are pinned in uTestLogBinaryFile, the column in
  uTestLogRepository's exhaustive round trip, the protocol in uTestNetHello.

  STAGE 2 (2026-11-12) adds: each contest STATES its kind of year
  (TContestBase.ReceivedYearKind -- two-digit, four-digit, years licensed)
  and the range follows from it; exactly the contests whose zone slot holds a
  year state one (a registry walk); the parser, Edit QSO's save and the ADIF
  import ask the kind; the readers read the field; the v7 re-carry of a
  schema-6 log; and a QSO received LIVE through the NET_QSOINFO arm stores
  its year. *)
unit uTestLogReceivedYear;

{$I ..\..\src\tr4w.inc}

interface

uses
   VC,                (* ContestExchange -- MakeRow *)
   uLogDatabase,      (* TLogDatabase -- QueryText *)
   uTR4WTestFramework,
   uTestNetSupport;   (* TNetStoreTestCase -- the wire tests' scratch store *)

type
   TLogReceivedYearTests = class(TTestCase)
   private
      FDir: string;
      function TempLogName(const aLeaf: string): string;
      procedure Scrub(const aFileName: string);
      (* rcvd_year of every row, in row order, NULL as 'N': '85,0,N'. *)
      function YearsOf(const aFileName: string): string;
      (* A scratch log of aContest holding one QSO per zone in aZones (255 is
        no zone), taken back to schema 5. *)
      procedure MakeSchema5Log(const aFileName: string; aContestType: integer;
                               const aZones: array of integer);
      (* The same at aVersion, each row also holding the year in aYears at its
        index (-1, or no entry, is no year) -- a stale copy, for the re-carry. *)
      procedure MakeOldLog(const aFileName: string; aContestType: integer;
                           const aZones, aYears: array of integer;
                           aVersion: integer);
   protected
      procedure Test_TheRuleIsTheContestsOwnAnswer;
      procedure Test_StoreLicenceYearWritesTheSlotAndTheField;
      procedure Test_TheRepositoryKeepsAYearAndNoYearApart;
      procedure Test_AnEUHFCLogCarriesItsYearsAcrossTheMigration;
      procedure Test_AZoneContestsLogGetsNoYear;
      procedure Test_WithNoJudgeTheLogIsLeftAlone;
      procedure Test_TheReaderClearsTheYearBytesOfAD7Record;
      procedure Test_AnImportedYearContestTakesItsYearsFromTheZone;
      (* STAGE 2 (2026-11-12) -- the stated kind, the readers, the re-carry. *)
      procedure Test_EachKindStatesItsDigitsAndRange;
      procedure Test_ExactlyTheYearContestsStateAKind;
      procedure Test_TheParserTakesTheKindsDigitsAndRange;
      procedure Test_TheYearIsReadFromItsField;
      procedure Test_EditQSOSavesTheYearAndTheZoneTogether;
      procedure Test_AnImportedADIFRecordTakesItsYear;
      procedure Test_TheRememberedExchangeReadsTheField;
      procedure Test_ASchema6LogIsReCarriedFromTheZone;
   public
      procedure RunAllTests; override;
   end;

   TNetReceivedYearTests = class(TNetStoreTestCase)
   protected
      procedure Test_AQSOPacketCarriesTheYear;
      procedure Test_AServerLogQSOStoresTheYear;
      procedure Test_AQSOReceivedLiveStoresTheYear;
      procedure Test_APeersSentYearTravelsAndIsStored;
   public
      procedure RunAllTests; override;
   end;

(* SHARED WITH uTestLogYearSent (issue 300, the SENT year): one QSO,
  initialised (not FillChar'd), with no year; and the first column of the
  first row a query answers, '' for none. *)
function MakeRow(aSeed: integer; aZone: integer): ContestExchange;
function QueryText(aDb: TLogDatabase; const aSql: string): string;

implementation

uses
   SysUtils, Classes, sqldb,
   TF,
   uLogSchema, uLogRepository, uLogImport, uLogBinaryFile,
   uLogStore,
   uContestRegistry, uContestBase,
   uNet, uNetClient, uNetCatchUp, uGetServerLog,
   PostUnit,             (* Contest -- the active contest *)
   uTestLatestContest,   (* MakeTestContestLog, DowngradeTestLog, TestLogHasColumn *)
   uTestLogDatabase,     (* CommitFramesInWal *)
   (* STAGE 2 *)
   LogWind,              (* ActiveMode -- the parser's lead form is CW only *)
   LogDupe,              (* GetInitialExchangeStringFromContestExchange, ExchangeInformation *)
   LOGSTUFF,             (* ProcessRSTAndLicenceYearExchange *)
   MainUnit,             (* ParseADIFRecord -- the path ImportFromADIF takes *)
   uContestSession,      (* ContestSession -- the remembered exchange's early exits *)
   uAppStrings,          (* SExchangeImproperLicenseYear *)
   uTestEngineEntry,     (* LoadCountryFile *)
   uTestRegisteredContests, (* ContestsToWalk, HandleOf, ContestWho *)
   uCallsigns,           (* CallsignsList -- a fresh one for the live arm *)
   uTestMainFormHarness; (* EnsureTestMainForm -- the panels the live arm draws *)

const
   (* Not this station: the sender of a received packet. *)
   PEER = 2;

(* One QSO, initialised (not FillChar'd), with no year. *)
function MakeRow(aSeed: integer; aZone: integer): ContestExchange;
begin
   Result := Default(ContestExchange);
   Result.ceRecordKind := rkQSO;
   Result.ceContest := NoContest;
   Result.id := ShortString('year' + IntToStr(aSeed));
   Result.ceQSOID1 := 7000 + aSeed;
   Result.ceQSOID2 := 1;
   Result.tSysTime.qtYear := 26;
   Result.tSysTime.qtMonth := 7;
   Result.tSysTime.qtDay := 11;
   Result.tSysTime.qtHour := 12;
   Result.tSysTime.qtMinute := aSeed;
   Result.Callsign := ShortString('S5' + IntToStr(aSeed) + 'A');
   Result.Frequency := 14025000;
   Result.Band := Band20;
   Result.Mode := CW;
   Result.ExtMode := eCW;
   Result.NumberReceived := -1;
   Result.NumberSent := -1;
   Result.Prefecture := 255;
   Result.Zone := Byte(aZone);
   Result.QTH.Zone := 255;
   Result.TenTenNum := 65535;
end;

function QueryText(aDb: TLogDatabase; const aSql: string): string;
var
   q: TSQLQuery;
begin
   Result := '';
   q := TSQLQuery.Create(nil);
   try
      q.DataBase := aDb.Connection;
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

const
   YEARS_SQL = 'SELECT group_concat(IFNULL(rcvd_year, ''N''), '','') ' +
               'FROM (SELECT rcvd_year FROM qso ORDER BY id)';

(* --------------------------------------------------------------------------- *)
(* TLogReceivedYearTests                                                       *)
(* --------------------------------------------------------------------------- *)

function TLogReceivedYearTests.TempLogName(const aLeaf: string): string;
begin
   if FDir = '' then
      begin
      FDir := IncludeTrailingPathDelimiter(GetTempDir) +
              'tr4w_rcvdyear_' + IntToStr(GetProcessID);
      ForceDirectories(FDir);
      end;
   Result := IncludeTrailingPathDelimiter(FDir) + aLeaf;
end;

procedure TLogReceivedYearTests.Scrub(const aFileName: string);
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

function TLogReceivedYearTests.YearsOf(const aFileName: string): string;
var
   db: TLogDatabase;
begin
   db := TLogDatabase.Create;
   try
      db.Open(aFileName);
      Result := QueryText(db, YEARS_SQL);
   finally
      db.Free;
   end;
end;

procedure TLogReceivedYearTests.MakeSchema5Log(const aFileName: string;
                                               aContestType: integer;
                                               const aZones: array of integer);
begin
   MakeOldLog(aFileName, aContestType, aZones, [], 5);
end;

procedure TLogReceivedYearTests.MakeOldLog(const aFileName: string;
                                           aContestType: integer;
                                           const aZones, aYears: array of integer;
                                           aVersion: integer);
var
   db: TLogDatabase;
   repo: TLogRepository;
   rec: ContestExchange;
   i: integer;
begin
   Scrub(aFileName);
   MakeTestContestLog(aFileName, ContestHandleOf(ContestType(aContestType)), '');
   db := TLogDatabase.Create;
   try
      db.Open(aFileName);
      repo := TLogRepository.Create(db);
      try
         for i := Low(aZones) to High(aZones) do
            begin
            rec := MakeRow(i, aZones[i]);
            (* Written as they stand, NOT through StoreLicenceYear: a stale
              copy is exactly a year that disagrees with the zone. *)
            if (i <= High(aYears)) and (aYears[i] >= 0) then
               begin
               rec.RcvdYear := Word(aYears[i]);
               rec.RcvdYearKnown := True;
               end;
            repo.SaveQSO(rec);
            end;
         repo.Commit;
      finally
         repo.Free;
      end;
   finally
      db.Free;
   end;
   DowngradeTestLog(aFileName, aVersion, Low(LOG_V3_QSO_COLUMNS));
end;

(* THE RULE IS THE CLASS'S OWN ANSWER, not a list: the two contests that keep
  the year in the zone slot say so (MyZoneIsAStationZone False); a zone
  contest and no contest do not. *)
procedure TLogReceivedYearTests.Test_TheRuleIsTheContestsOwnAnswer;
begin
   BeginTest('ContestKeepsYearInZoneSlot is the class''s answer');
   CheckTrue(ContestKeepsYearInZoneSlot(ContestHandleOf(EUROPEANHFC)),
             'the European HF Championship keeps the year in the zone slot');
   CheckTrue(ContestKeepsYearInZoneSlot(ContestHandleOf(KVP)), 'and so does KVP');
   CheckFalse(ContestKeepsYearInZoneSlot(ContestHandleOf(CQWWCW)),
              'CQ WW''s zone slot is a zone');
   CheckFalse(ContestKeepsYearInZoneSlot(NoContest), 'no contest keeps no year');
end;

(* STAGE 1 WRITES BOTH, so the zone slot the multiplier sheet counts and the
  field never disagree; since stage 2 the readers read the field. 0 is a
  year. *)
procedure TLogReceivedYearTests.Test_StoreLicenceYearWritesTheSlotAndTheField;
var
   rec: ContestExchange;
begin
   BeginTest('StoreLicenceYear writes the zone slot and the year field');
   rec := MakeRow(1, 255);
   CheckFalse(rec.RcvdYearKnown, 'a new record has no year');
   StoreLicenceYear(rec, 85);
   CheckEquals(85, rec.Zone, 'the zone slot holds it, as before');
   CheckTrue(rec.RcvdYearKnown, 'the field says there is a year');
   CheckEquals(85, rec.RcvdYear, 'and holds it');
   CheckEquals(85, LicenceYearOf(rec), 'LicenceYearOf reads it');
   StoreLicenceYear(rec, 0);
   CheckTrue(rec.RcvdYearKnown, '00 is a year');
   CheckEquals(0, rec.RcvdYear, 'held as 0');
   CheckEquals(0, rec.Zone, 'in the slot as 0');
end;

(* A YEAR, NO YEAR AND THE YEAR 00 ARE THREE DIFFERENT ROWS: NULL, 0, 85 --
  through insert, read, and an update that removes and replaces the year. *)
procedure TLogReceivedYearTests.Test_TheRepositoryKeepsAYearAndNoYearApart;
var
   fn: string;
   db: TLogDatabase;
   repo: TLogRepository;
   rec, back: ContestExchange;
   idNone, idZero, idYear: Int64;
begin
   BeginTest('rcvd_year keeps a year, the year 00 and no year apart');
   fn := TempLogName('roundtrip.db');
   Scrub(fn);
   db := TLogDatabase.Create;
   try
      db.CreateNew(fn);
      repo := TLogRepository.Create(db);
      try
         idNone := repo.SaveQSO(MakeRow(1, 255));
         rec := MakeRow(2, 255);
         StoreLicenceYear(rec, 0);
         idZero := repo.SaveQSO(rec);
         rec := MakeRow(3, 255);
         rec.RcvdYear := 1985;     (* a four-digit year: the Word holds it *)
         rec.RcvdYearKnown := True;
         idYear := repo.SaveQSO(rec);
         repo.Commit;

         CheckEquals('N,0,1985', QueryText(db, YEARS_SQL), 'the column: NULL, 0, 1985');

         CheckTrue(repo.LoadQSO(idNone, back), 'row 1 reads');
         CheckFalse(back.RcvdYearKnown, 'NULL reads as no year');
         CheckEquals(0, back.RcvdYear, 'and the value is 0');
         CheckTrue(repo.LoadQSO(idZero, back), 'row 2 reads');
         CheckTrue(back.RcvdYearKnown, '0 reads as a year');
         CheckEquals(0, back.RcvdYear, 'the year 00');
         CheckTrue(repo.LoadQSO(idYear, back), 'row 3 reads');
         CheckTrue(back.RcvdYearKnown, 'a year');
         CheckEquals(1985, back.RcvdYear, '1985');

         (* AN EDIT CHANGES IT: rcvd_year is updatable, unlike the my_* columns. *)
         back.RcvdYearKnown := False;
         back.RcvdYear := 0;
         CheckTrue(repo.UpdateQSO(idYear, back), 'the update is written');
         rec := MakeRow(1, 255);
         CheckTrue(repo.LoadQSO(idNone, rec), 'row 1 reads again');
         rec.RcvdYear := 99;
         rec.RcvdYearKnown := True;
         CheckTrue(repo.UpdateQSO(idNone, rec), 'and so is the other');
         repo.Commit;
         CheckEquals('99,0,N', QueryText(db, YEARS_SQL),
                     'an update gives a year and takes one away');
      finally
         repo.Free;
      end;
   finally
      db.Free;
   end;
   Scrub(fn);
end;

(* THE MIGRATION CARRIES AN EUHFC LOG'S YEARS out of rcvd_zone, row for row:
  85 is 85, 0 (the year 00) is 0, and no zone is no year. The ALTER, the copy
  and the version stamp are ONE commit. The zone column is left as it was. *)
procedure TLogReceivedYearTests.Test_AnEUHFCLogCarriesItsYearsAcrossTheMigration;
var
   fn: string;
   db: TLogDatabase;
begin
   BeginTest('a schema-5 EUHFC log carries its years into rcvd_year, in one commit');
   fn := TempLogName('euhfc5.db');
   MakeSchema5Log(fn, Ord(EUROPEANHFC), [85, 0, 255]);
   CheckFalse(FileExists(fn + '-wal'), 'precondition: no WAL is left by the fixture');

   db := TLogDatabase.Create;
   try
      db.Open(fn);
      CheckEquals(1, CommitFramesInWal(fn + '-wal'),
                  'the column, the copy and the stamp went in ONE commit');
      CheckEquals(LOG_SCHEMA_VERSION, db.SchemaVersion, 'stamped current');
      CheckEquals(8, LOG_SCHEMA_VERSION, 'which is 8 (issue 300''s year_sent)');
      CheckEquals('85,0,N', QueryText(db, YEARS_SQL), 'each row''s year, from its zone');
      CheckEquals('85,0,N', QueryText(db,
                  'SELECT group_concat(IFNULL(rcvd_zone, ''N''), '','') ' +
                  'FROM (SELECT rcvd_zone FROM qso ORDER BY id)'),
                  'and the zone column is unchanged');
   finally
      db.Free;
   end;

   (* A SECOND OPEN CHANGES NOTHING. *)
   CheckEquals('85,0,N', YearsOf(fn), 'a second open keeps the years');
   Scrub(fn);
end;

(* A ZONE CONTEST'S ZONES ARE ZONES: the column arrives, empty. *)
procedure TLogReceivedYearTests.Test_AZoneContestsLogGetsNoYear;
var
   fn: string;
begin
   BeginTest('a schema-5 CQ WW log gains rcvd_year with no year in it');
   fn := TempLogName('cqww5.db');
   MakeSchema5Log(fn, Ord(CQWWCW), [14, 0, 255]);
   CheckEquals('N,N,N', YearsOf(fn), 'no row has a year');
   Scrub(fn);
end;

(* NO JUDGE, NO MIGRATION: a log below 6 is refused before anything changes,
  rather than stamped 6 without its years, after which nothing would carry
  them. The program and this test binary assign the judge (uLogStore). *)
procedure TLogReceivedYearTests.Test_WithNoJudgeTheLogIsLeftAlone;
var
   fn: string;
   db: TLogDatabase;
   saved: TLogContestKeepsYearInZone;
   refused: boolean;
begin
   BeginTest('with no contest judge a schema-5 log is refused and left as it was');
   fn := TempLogName('nojudge.db');
   MakeSchema5Log(fn, Ord(EUROPEANHFC), [85]);
   CheckTrue(Assigned(LogContestKeepsYearInZone),
             'precondition: the store assigned the judge at initialization');

   saved := LogContestKeepsYearInZone;
   LogContestKeepsYearInZone := nil;
   try
      refused := False;
      db := TLogDatabase.Create;
      try
         try
            db.Open(fn);
         except
            on E: ELogDatabaseError do
               begin
               (* Refused for the missing judge, not for anything SQL said. *)
               refused := Pos('LogContestKeepsYearInZone', E.Message) > 0;
               end;
         end;
      finally
         db.Free;
      end;
      CheckTrue(refused, 'the open is refused, naming what is missing');
   finally
      LogContestKeepsYearInZone := saved;
   end;

   db := TLogDatabase.Create;
   try
      db.OpenReadOnly(fn);
      CheckEquals(5, db.SchemaVersion, 'the log is still schema 5');
      CheckFalse(TestLogHasColumn(db, 'qso', 'rcvd_year'), 'and has no rcvd_year');
   finally
      db.Free;
   end;
   Scrub(fn);
end;

(* A D7 RECORD NEVER CARRIES A YEAR. Whatever its bytes 324..326 hold (they
  were sReserved), the reader hands the record over with none. *)
procedure TLogReceivedYearTests.Test_TheReaderClearsTheYearBytesOfAD7Record;
var
   source: string;
   s: TMemoryStream;
   rec: ContestExchange;
   reader: TLogBinaryReader;
begin
   BeginTest('the .TRW reader clears the year bytes of a D7 record');
   source := TempLogName('garbage_year.trw');
   Scrub(source);
   s := TMemoryStream.Create;
   try
      s.LoadFromFile(ExtractFilePath(ParamStr(0)) + 'fixtures' + PathDelim +
                     'binarylog' + PathDelim + 'arktika_2026_ny4i.trw');
      CheckEquals(2 * SizeOf(ContestExchange), s.Size, 'a header and one record');
      s.Position := SizeOf(ContestExchange);
      s.ReadBuffer(rec, SizeOf(rec));
      CheckFalse(rec.RcvdYearKnown, 'precondition: the fixture''s bytes are zero');
      rec.RcvdYear := 4321;
      rec.RcvdYearKnown := True;
      s.Position := SizeOf(ContestExchange);
      s.WriteBuffer(rec, SizeOf(rec));
      s.SaveToFile(source);
   finally
      s.Free;
   end;

   reader := TLogBinaryReader.Create(source);
   try
      CheckTrue(reader.Status = lbOK, 'the file reads');
      CheckTrue(reader.ReadNext(rec), 'one record');
      CheckFalse(rec.RcvdYearKnown, 'with no year');
      CheckEquals(0, rec.RcvdYear, 'and the value cleared');
   finally
      reader.Free;
   end;
   Scrub(source);
end;

(* THE IMPORT FILLS THE YEAR FROM THE ZONE SLOT for a contest that kept it
  there, by the migration's rule; any other contest's zones stay zones. *)
procedure TLogReceivedYearTests.Test_AnImportedYearContestTakesItsYearsFromTheZone;
var
   source, fn: string;
   s: TMemoryStream;
   header, rec: ContestExchange;
   res: TLogImportResult;

   procedure WriteTrw(aContest: TContestHandle; const aZones: array of integer);
   var
      i: integer;
      one: ContestExchange;
   begin
      Scrub(source);
      s := TMemoryStream.Create;
      try
         s.WriteBuffer(header, SizeOf(header));
         for i := Low(aZones) to High(aZones) do
            begin
            one := rec;
            one.ceContest := aContest;
            one.Zone := Byte(aZones[i]);
            one.ceQSOID2 := 100 + i;
            one.tSysTime.qtMinute := i;
            one.id := ShortString('trwyear' + IntToStr(i));
            (* Garbage where the year now lives: the reader must not believe it. *)
            one.RcvdYear := 4321;
            one.RcvdYearKnown := True;
            s.WriteBuffer(one, SizeOf(one));
            end;
         s.SaveToFile(source);
      finally
         s.Free;
      end;
   end;

begin
   BeginTest('a .TRW import fills rcvd_year from the zone slot for a year contest only');
   source := TempLogName('year.trw');
   fn := TempLogName('year.db');

   s := TMemoryStream.Create;
   try
      s.LoadFromFile(ExtractFilePath(ParamStr(0)) + 'fixtures' + PathDelim +
                     'binarylog' + PathDelim + 'arktika_2026_ny4i.trw');
      s.Position := 0;
      s.ReadBuffer(header, SizeOf(header));
      s.ReadBuffer(rec, SizeOf(rec));
   finally
      s.Free;
   end;

   WriteTrw(ContestHandleOf(EUROPEANHFC), [85, 0, 255]);
   Scrub(fn);
   res := ImportBinaryLog(source, fn);
   CheckTrue(res.Ok, 'the EUHFC .TRW imports: ' + res.Message);
   CheckEquals('85,0,N', YearsOf(fn), 'each year from its zone; no zone is no year');
   Scrub(fn);

   CheckFalse(ContestKeepsYearInZoneSlot(rec.ceContest),
              'precondition: the fixture''s own contest keeps zones in its slot');
   WriteTrw(rec.ceContest, [14, 0, 255]);
   res := ImportBinaryLog(source, fn);
   CheckTrue(res.Ok, 'the zone contest''s .TRW imports: ' + res.Message);
   CheckEquals('N,N,N', YearsOf(fn), 'and none of its zones becomes a year');
   Scrub(fn);
   Scrub(source);
end;

(* --------------------------------------------------------------------------- *)
(* STAGE 2 -- the stated kind, the readers on the field, the re-carry          *)
(* --------------------------------------------------------------------------- *)

(* EACH KIND STATES ITS DIGITS AND ITS RANGE -- uContestBase.ReceivedYearRange,
  ReceivedYearDigits, ReceivedYearFromWord and ReceivedYearText, the one
  statement the parser, Edit QSO and the import ask. The rows are the DXLog
  files' own (see ReceivedYearRange); the four-digit ceiling is the QSO's own
  year, never the clock. *)
procedure TLogReceivedYearTests.Test_EachKindStatesItsDigitsAndRange;
var
   low, high, fewest, most, year: integer;
   rec: ContestExchange;
begin
   BeginTest('each received-year kind states its digits and its range');
   CheckFalse(ReceivedYearRange(rykNone, 2026, low, high), 'no kind, no range');
   CheckFalse(ReceivedYearDigits(rykNone, fewest, most), 'no kind, no digits');

   CheckTrue(ReceivedYearRange(rykTwoDigitYear, 2026, low, high), 'two-digit: a range');
   CheckEquals(0, low, 'two-digit: from 00');
   CheckEquals(99, high, 'two-digit: to 99');
   CheckTrue(ReceivedYearDigits(rykTwoDigitYear, fewest, most), 'two-digit: digits');
   CheckEquals(1, fewest, 'two-digit: one digit is taken (5 is 05)');
   CheckEquals(2, most, 'two-digit: two at most');

   CheckTrue(ReceivedYearRange(rykYearsLicensed, 2026, low, high), 'a count: a range');
   CheckEquals(0, low, 'a count: from 0 (DXLog HA YL-OM)');
   CheckEquals(99, high, 'a count: to 99');
   CheckTrue(ReceivedYearDigits(rykYearsLicensed, fewest, most), 'a count: digits');
   CheckEquals(2, most, 'a count: two digits at most');

   CheckTrue(ReceivedYearRange(rykFourDigitYear, 2026, low, high), 'four-digit: a range');
   CheckEquals(1900, low, 'four-digit: from 1900');
   CheckEquals(2026, high, 'four-digit: to the QSO''s own year');
   CheckTrue(ReceivedYearDigits(rykFourDigitYear, fewest, most), 'four-digit: digits');
   CheckEquals(4, fewest, 'four-digit: four digits...');
   CheckEquals(4, most, '...exactly');

   CheckTrue(ReceivedYearFromWord(rykTwoDigitYear, '85', 2026, year), '85');
   CheckEquals(85, year, '85 is 85');
   CheckTrue(ReceivedYearFromWord(rykTwoDigitYear, '5', 2026, year), '5');
   CheckEquals(5, year, '5 is 05');
   CheckTrue(ReceivedYearFromWord(rykTwoDigitYear, '00', 2026, year), '00');
   CheckEquals(0, year, '00 is a year');
   CheckFalse(ReceivedYearFromWord(rykTwoDigitYear, '100', 2026, year), 'three digits');
   CheckEquals(NO_RECEIVED_YEAR, year, 'a refusal answers no year');
   CheckFalse(ReceivedYearFromWord(rykTwoDigitYear, '1987', 2026, year), 'four digits, two-digit kind');
   CheckFalse(ReceivedYearFromWord(rykTwoDigitYear, '8A', 2026, year), 'a letter');
   CheckFalse(ReceivedYearFromWord(rykTwoDigitYear, '', 2026, year), 'nothing');
   CheckFalse(ReceivedYearFromWord(rykNone, '85', 2026, year), 'no kind takes nothing');

   CheckTrue(ReceivedYearFromWord(rykFourDigitYear, '1987', 2026, year), '1987');
   CheckEquals(1987, year, '1987 is 1987');
   CheckTrue(ReceivedYearFromWord(rykFourDigitYear, '1900', 2026, year), 'the floor');
   CheckFalse(ReceivedYearFromWord(rykFourDigitYear, '1899', 2026, year), 'below the floor');
   CheckTrue(ReceivedYearFromWord(rykFourDigitYear, '2026', 2026, year), 'the QSO''s own year');
   CheckFalse(ReceivedYearFromWord(rykFourDigitYear, '2027', 2026, year), 'after the QSO');
   CheckFalse(ReceivedYearFromWord(rykFourDigitYear, '87', 2026, year), 'two digits, four-digit kind');
   CheckFalse(ReceivedYearFromWord(rykFourDigitYear, '01987', 2026, year), 'five digits');

   CheckTrue(ReceivedYearFromWord(rykYearsLicensed, '0', 2026, year), 'a count of 0');
   CheckTrue(ReceivedYearFromWord(rykYearsLicensed, '99', 2026, year), 'a count of 99');
   CheckFalse(ReceivedYearFromWord(rykYearsLicensed, '100', 2026, year), 'a count of 100');

   CheckEquals('05', ReceivedYearText(rykTwoDigitYear, 5), 'a two-digit year reads 05');
   CheckEquals('85', ReceivedYearText(rykTwoDigitYear, 85), 'and 85');
   CheckEquals('00', ReceivedYearText(rykTwoDigitYear, 0), 'and 00');
   CheckEquals('1987', ReceivedYearText(rykFourDigitYear, 1987), 'a four-digit year as it is');
   CheckEquals('7', ReceivedYearText(rykYearsLicensed, 7), 'a count as a number');
   CheckEquals('', ReceivedYearText(rykNone, 5), 'no kind, no text');
   CheckEquals('', ReceivedYearText(rykTwoDigitYear, NO_RECEIVED_YEAR), 'no year, no text');

   rec := MakeRow(1, 255);
   CheckEquals(2026, ReferenceYearOfQSO(rec), 'a dated QSO: its own year');
   rec := Default(ContestExchange);
   CheckEquals(LATEST_QSO_YEAR, ReferenceYearOfQSO(rec), 'an undated one: the latest a record holds');
end;

(* EXACTLY THE CONTESTS WHOSE ZONE SLOT HOLDS A YEAR STATE A KIND -- a walk
  over the registry, so a new contest is held too. ContestKeepsYearInZoneSlot
  (the migration's and the .TRW import's rule) was "MyZoneIsAStationZone is
  False" in stage 1 and is the stated kind since stage 2: the two must give
  the same answer for every contest, or the repoint changed which logs are
  migrated. The two classes that exist are named. *)
procedure TLogReceivedYearTests.Test_ExactlyTheYearContestsStateAKind;
var
   c: TContestBase;
   statesKind: boolean;
begin
   BeginTest('exactly the contests whose zone slot holds a year state a kind');
   for c in ContestsToWalk do
      begin
      statesKind := c.ReceivedYearKind <> rykNone;
      CheckTrue(statesKind = (not c.MyZoneIsAStationZone),
                uTestRegisteredContests.ContestWho(c) + ': a stated year kind exactly where MY ZONE is no station zone');
      CheckTrue(statesKind = ContestKeepsYearInZoneSlot(HandleOf(c)),
                uTestRegisteredContests.ContestWho(c) + ': the migration''s rule is the stated kind');
      end;
   CheckTrue(ContestIdentity(ContestHandleOf(EUROPEANHFC)).ReceivedYearKind = rykTwoDigitYear,
             'the European HF Championship: a two-digit year (rule 5)');
   CheckTrue(ContestIdentity(ContestHandleOf(KVP)).ReceivedYearKind = rykTwoDigitYear,
             'KVP: a two-digit year');
   CheckTrue(ContestIdentity(ContestHandleOf(CQWWCW)).ReceivedYearKind = rykNone,
             'CQ WW: no year');
   CheckTrue(ContestReceivedYearKind(nil) = rykNone, 'nil: no year');
end;

(* THE PARSER TAKES THE KIND'S DIGITS AND RANGE -- LOGSTUFF.
  ProcessRSTAndLicenceYearExchange, which both classes reach with their stated
  kind (uTestLicenceYearEntry pins the two-digit kind in full, through the
  engine). No class states the four-digit kind or the count yet, so they are
  driven here directly: the same words, the kind's digits, and the four-digit
  ceiling the QSO's own year (MakeRow is dated 2026). *)
procedure TLogReceivedYearTests.Test_TheParserTakesTheKindsDigitsAndRange;
var
   savedMode: ModeType;
   rx: ContestExchange;

   function Parse(const aText: string; aKind: TReceivedYearKind; aMode: ModeType): boolean;
   begin
      ActiveMode := aMode;
      rx := MakeRow(1, 255);
      StoreLicenceYear(rx, 7);       (* a year no entry types: "untouched" shows *)
      ExchangeErrorMessage := '';
      Result := ProcessRSTAndLicenceYearExchange(ShortString(aText), aKind, rx);
   end;

begin
   BeginTest('the year parser takes the kind''s digits and range');
   savedMode := ActiveMode;
   try
      CheckTrue(Parse('599 1987', rykFourDigitYear, CW), 'four-digit: 599 1987');
      CheckEquals(1987, LicenceYearOf(rx), 'the year 1987');
      CheckEquals(DUMMYZONE, integer(rx.Zone), 'which the zone slot cannot hold: no zone');
      CheckTrue(Parse('1987', rykFourDigitYear, CW), 'four-digit: bare');
      CheckEquals(1987, LicenceYearOf(rx), 'bare, 1987');
      CheckTrue(Parse('1987 579', rykFourDigitYear, CW), 'four-digit: the year, then a CW RST');
      CheckEquals(1987, LicenceYearOf(rx), 'year first, 1987');
      CheckEquals(579, integer(rx.RSTReceived), 'and the report after it');
      CheckTrue(Parse('59 1987', rykFourDigitYear, Phone), 'four-digit on phone');
      CheckTrue(Parse('599 2026', rykFourDigitYear, CW), 'the QSO''s own year');
      CheckFalse(Parse('599 2027', rykFourDigitYear, CW), 'a year after the QSO');
      CheckEquals(SExchangeImproperLicenseYear, ExchangeErrorMessage, 'is improper');
      CheckEquals(7, LicenceYearOf(rx), 'and the year untouched');
      CheckFalse(Parse('599 1899', rykFourDigitYear, CW), 'below 1900');
      CheckFalse(Parse('599 87', rykFourDigitYear, CW), 'two digits, four-digit kind');
      CheckEquals(SExchangeImproperLicenseYear, ExchangeErrorMessage, 'is improper too');
      CheckFalse(Parse('599', rykFourDigitYear, CW), 'a report alone');
      CheckEquals(SExchangeNoLicenseYear, ExchangeErrorMessage, 'has no year');

      CheckTrue(Parse('599 45', rykYearsLicensed, CW), 'a count: 599 45');
      CheckEquals(45, LicenceYearOf(rx), '45 years');
      CheckEquals(45, integer(rx.Zone), 'in the zone slot too, for the sheet');
      CheckTrue(Parse('0', rykYearsLicensed, CW), 'a count of 0');
      CheckEquals(0, LicenceYearOf(rx), '0 years');
      CheckFalse(Parse('599 100', rykYearsLicensed, CW), 'a count of 100');

      CheckTrue(Parse('599 85', rykTwoDigitYear, CW), 'two-digit: unchanged');
      CheckEquals(85, LicenceYearOf(rx), '85');
      CheckFalse(Parse('599 1987', rykTwoDigitYear, CW), 'two-digit: four digits refused');

      CheckFalse(Parse('599 85', rykNone, CW), 'no kind: nothing to parse');
      CheckEquals(SExchangeImproperLicenseYear, ExchangeErrorMessage, 'refused as improper');
   finally
      ActiveMode := savedMode;
      ExchangeErrorMessage := '';
   end;
end;

(* THE YEAR IS READ FROM ITS FIELD -- TryLicenceYearOf / LicenceYearOf. The
  zone slot answers ONLY for a record that never carried the field (Known
  False) and holds a zone -- exactly what the migration and the .TRW import
  would have copied. StoreLicenceYear writes the field and, for a value the
  zone sheet can count, the slot; ClearLicenceYear clears both. *)
procedure TLogReceivedYearTests.Test_TheYearIsReadFromItsField;
var
   rec: ContestExchange;
   year: integer;
begin
   BeginTest('the received year is read from its own field');
   rec := MakeRow(1, 255);
   CheckFalse(TryLicenceYearOf(rec, year), 'no field, no zone: no year');
   CheckEquals(NO_RECEIVED_YEAR, year, 'answered as no year');
   CheckEquals(NO_RECEIVED_YEAR, LicenceYearOf(rec), 'LicenceYearOf too');

   rec.Zone := 40;
   rec.RcvdYear := 85;
   rec.RcvdYearKnown := True;
   CheckEquals(85, LicenceYearOf(rec), 'the field, not the zone slot');

   rec.RcvdYearKnown := False;
   rec.RcvdYear := 0;
   rec.Zone := 33;
   CheckEquals(33, LicenceYearOf(rec),
               'no field: the zone slot, where the migration would have copied it');

   StoreLicenceYear(rec, 1987);
   CheckTrue(rec.RcvdYearKnown, 'a four-digit year is a year');
   CheckEquals(1987, LicenceYearOf(rec), 'held in the field');
   CheckEquals(DUMMYZONE, integer(rec.Zone), 'and no zone the sheet would misread');

   StoreLicenceYear(rec, 0);
   CheckEquals(0, integer(rec.Zone), 'the year 00 in the slot as 0');
   ClearLicenceYear(rec);
   CheckFalse(rec.RcvdYearKnown, 'cleared: no year');
   CheckEquals(DUMMYZONE, integer(rec.Zone), 'cleared: no zone');
   CheckEquals(NO_RECEIVED_YEAR, LicenceYearOf(rec), 'and nothing to read');
end;

(* EDIT QSO SAVES THE YEAR AND THE ZONE TOGETHER -- the stage-1 defect: the
  year box was saved into the zone slot alone, and the record went back to the
  log with its OLD rcvd_year. ApplyEditedReceivedYear is the save's one
  statement; uEditQSO is read to show it is the one the dialog calls (its
  controls need a running form). *)
procedure TLogReceivedYearTests.Test_EditQSOSavesTheYearAndTheZoneTogether;
var
   rec: ContestExchange;
   lines: TStringList;
   text: string;
begin
   BeginTest('Edit QSO saves the received year and the zone slot together');
   rec := MakeRow(1, 255);
   StoreLicenceYear(rec, 85);

   CheckTrue(ApplyEditedReceivedYear(rykTwoDigitYear, '84', rec), '84 is saved');
   CheckEquals(84, integer(rec.RcvdYear), 'the field is 84');
   CheckEquals(84, integer(rec.Zone), 'and so is the zone slot');
   CheckTrue(ApplyEditedReceivedYear(rykTwoDigitYear, ' 05 ', rec), '05 is saved');
   CheckEquals(5, LicenceYearOf(rec), 'as 5');
   CheckTrue(ApplyEditedReceivedYear(rykTwoDigitYear, '', rec), 'an empty box is saved');
   CheckFalse(rec.RcvdYearKnown, 'as no year');
   CheckEquals(DUMMYZONE, integer(rec.Zone), 'and no zone');

   StoreLicenceYear(rec, 85);
   CheckFalse(ApplyEditedReceivedYear(rykTwoDigitYear, '1982', rec), '1982 is refused');
   CheckFalse(ApplyEditedReceivedYear(rykTwoDigitYear, '8A', rec), '8A is refused');
   CheckFalse(ApplyEditedReceivedYear(rykTwoDigitYear, '100', rec), '100 is refused');
   CheckEquals(85, integer(rec.RcvdYear), 'a refusal leaves the field');
   CheckEquals(85, integer(rec.Zone), 'and the zone slot');

   CheckTrue(ApplyEditedReceivedYear(rykFourDigitYear, '1987', rec), 'four-digit: 1987');
   CheckEquals(1987, LicenceYearOf(rec), 'is 1987');
   CheckFalse(ApplyEditedReceivedYear(rykFourDigitYear, '2027', rec),
              'four-digit: after the QSO''s own year');

   lines := TStringList.Create;
   try
      lines.LoadFromFile(AnsiString(ExpandFileName(ExtractFilePath(ParamStr(0)) +
         '..' + PathDelim + '..' + PathDelim + 'src' + PathDelim + 'uEditQSO.pas')));
      text := lines.Text;
   finally
      lines.Free;
   end;
   CheckTrue(Pos('ApplyEditedReceivedYear(', text) > 0, 'the dialog saves through it');
   (* Stage 3: through ReceivedYearTextOf, the one display answer, which
      writes the year as ReceivedYearText does. *)
   CheckTrue(Pos('ReceivedYearTextOf(', text) > 0, 'and shows the year as it is typed');
   CheckTrue(Pos('EditQSOShowZoneBox(', text) > 0, 'with the box''s label and length set for the contest');
end;

(* AN IMPORTED ADIF RECORD TAKES ITS YEAR -- through MainUnit.ParseADIFRecord,
  the path ImportFromADIF takes. TR4W writes the year in SRX_STRING ('599 85')
  and no CQZ for these contests; before stage 2 a TR4W EUHFC file came back
  with NO year (the zone slot was set only by a CQZ tag). A CQZ tag is still
  read when the received exchange has no year -- and it may come before
  CONTEST_ID. A zone contest's zone stays a zone. *)
procedure TLogReceivedYearTests.Test_AnImportedADIFRecordTakesItsYear;
var
   rx: ContestExchange;
   euhfcId, kvpId, cqwwId: string;

   function Tag(const aName, aValue: string): string;
   begin
      Result := '<' + aName + ':' + IntToStr(Length(aValue)) + '>' + aValue + ' ';
   end;

   function Imported(const aTags: string): boolean;
   begin
      ClearContestExchange(rx);
      Result := ParseADIFRecord(Tag('CALL', 'S50A') + Tag('BAND', '20m') + Tag('MODE', 'CW') +
                                Tag('QSO_DATE', '20261101') + Tag('TIME_ON', '120000') +
                                Tag('RST_SENT', '599') + Tag('RST_RCVD', '599') + aTags +
                                '<EOR>', rx);
   end;

begin
   BeginTest('an imported ADIF record takes its received year');
   CheckTrue(LoadCountryFile, 'cty.dat loads');
   euhfcId := ContestIdentity(ContestHandleOf(EUROPEANHFC)).ADIFContestId;
   kvpId := ContestIdentity(ContestHandleOf(KVP)).ADIFContestId;
   cqwwId := ContestIdentity(ContestHandleOf(CQWWCW)).ADIFContestId;

   CheckTrue(Imported(Tag('CONTEST_ID', euhfcId) + Tag('SRX_STRING', '599 85')), 'EUHFC 599 85');
   CheckTrue(rx.RcvdYearKnown, 'has a year');
   CheckEquals(85, integer(rx.RcvdYear), 'from SRX_STRING');
   CheckEquals(85, integer(rx.Zone), 'and the zone slot the sheet counts');

   CheckTrue(Imported(Tag('CONTEST_ID', euhfcId) + Tag('SRX_STRING', '599 05')), 'EUHFC 599 05');
   CheckEquals(5, LicenceYearOf(rx), '05');

   CheckTrue(Imported(Tag('CQZ', '28') + Tag('CONTEST_ID', euhfcId) + Tag('SRX_STRING', '599')),
             'EUHFC with the year only in CQZ, before CONTEST_ID');
   CheckEquals(28, LicenceYearOf(rx), 'the CQZ value is the year');
   CheckTrue(rx.RcvdYearKnown, 'stored in the field');

   CheckTrue(Imported(Tag('CONTEST_ID', euhfcId) + Tag('SRX_STRING', '599 123')), 'EUHFC 599 123');
   CheckFalse(rx.RcvdYearKnown, 'no year of the kind: none');
   CheckEquals(DUMMYZONE, integer(rx.Zone), 'and no zone');

   CheckTrue(Imported(Tag('CONTEST_ID', kvpId) + Tag('SRX_STRING', '599 00')), 'KVP 599 00');
   CheckTrue(rx.RcvdYearKnown, 'KVP: a year');
   CheckEquals(0, integer(rx.RcvdYear), 'the year 00');

   CheckTrue(Imported(Tag('CONTEST_ID', cqwwId) + Tag('CQZ', '14') + Tag('SRX_STRING', '599 14')),
             'CQ WW 599 14');
   CheckFalse(rx.RcvdYearKnown, 'CQ WW: a zone is no year');
   CheckEquals(14, integer(rx.Zone), 'the zone stays a zone');
end;

(* THE REMEMBERED EXCHANGE READS THE FIELD -- LOGDUPE.
  GetInitialExchangeStringFromContestExchange, what a logged QSO leaves for its
  call (the need hint and the call-window prefill; the European HF
  Championship's ZoneMultiplierFromCall reads it back). A year record gives its
  year even where the zone slot disagrees; a zone record its zone. *)
procedure TLogReceivedYearTests.Test_TheRememberedExchangeReadsTheField;
var
   savedFields: ExchangeInformationRecord;
   savedKind: ExchangeType;
   rx: ContestExchange;
begin
   BeginTest('the remembered exchange reads the received year from its field');
   savedFields := ExchangeInformation;
   savedKind := ContestSession.Exchange;
   ExchangeInformation := ContestReceivedExchangeFields(ContestIdentity(ContestHandleOf(EUROPEANHFC)));
   ContestSession.WriteExchange(RSTZoneExchange);
   try
      rx := MakeRow(1, 40);
      rx.RcvdYear := 85;
      rx.RcvdYearKnown := True;
      CheckEquals('85', string(GetInitialExchangeStringFromContestExchange(rx)),
                  'the year, from its field');
      rx.RcvdYearKnown := False;
      rx.RcvdYear := 0;
      CheckEquals('40', string(GetInitialExchangeStringFromContestExchange(rx)),
                  'a record with no year: its zone, as before');
   finally
      ContestSession.WriteExchange(savedKind);
      ExchangeInformation := savedFields;
   end;
end;

(* A SCHEMA-6 LOG IS RE-CARRIED FROM THE ZONE -- the v7 step. Through stage 1
  rcvd_zone was authoritative and rcvd_year a copy an edit could leave stale
  (here 70 beside zone 85, 44 beside no zone). Opening it makes every row's
  year its zone, OVERWRITING, in one commit; a second open changes nothing; a
  zone contest's log keeps whatever it holds. *)
procedure TLogReceivedYearTests.Test_ASchema6LogIsReCarriedFromTheZone;
var
   fn: string;
   db: TLogDatabase;
begin
   BeginTest('a schema-6 year-contest log is re-carried from rcvd_zone, in one commit');
   fn := TempLogName('euhfc6.db');
   MakeOldLog(fn, Ord(EUROPEANHFC), [85, 0, 255, 40], [70, -1, 44, 40], 6);
   CheckFalse(FileExists(fn + '-wal'), 'precondition: no WAL is left by the fixture');

   db := TLogDatabase.Create;
   try
      db.OpenReadOnly(fn);
      CheckEquals(6, db.SchemaVersion, 'precondition: schema 6');
      CheckEquals('70,N,44,40', QueryText(db, YEARS_SQL), 'precondition: the stale copies');
   finally
      db.Free;
   end;

   db := TLogDatabase.Create;
   try
      db.Open(fn);
      CheckEquals(1, CommitFramesInWal(fn + '-wal'), 'the re-carry and the stamp: ONE commit');
      CheckEquals(LOG_SCHEMA_VERSION, db.SchemaVersion, 'stamped current');
      CheckEquals('85,0,N,40', QueryText(db, YEARS_SQL), 'every year is its zone');
   finally
      db.Free;
   end;
   CheckEquals('85,0,N,40', YearsOf(fn), 'a second open changes nothing');
   Scrub(fn);

   fn := TempLogName('cqww6.db');
   MakeOldLog(fn, Ord(CQWWCW), [14, 255], [70, -1], 6);
   CheckEquals('70,N', YearsOf(fn), 'a zone contest''s log is left as it was');
   Scrub(fn);
end;

procedure TLogReceivedYearTests.RunAllTests;
begin
   Test_TheRuleIsTheContestsOwnAnswer;
   Test_StoreLicenceYearWritesTheSlotAndTheField;
   Test_TheRepositoryKeepsAYearAndNoYearApart;
   Test_AnEUHFCLogCarriesItsYearsAcrossTheMigration;
   Test_AZoneContestsLogGetsNoYear;
   Test_WithNoJudgeTheLogIsLeftAlone;
   Test_TheReaderClearsTheYearBytesOfAD7Record;
   Test_AnImportedYearContestTakesItsYearsFromTheZone;
   Test_EachKindStatesItsDigitsAndRange;
   Test_ExactlyTheYearContestsStateAKind;
   Test_TheParserTakesTheKindsDigitsAndRange;
   Test_TheYearIsReadFromItsField;
   Test_EditQSOSavesTheYearAndTheZoneTogether;
   Test_AnImportedADIFRecordTakesItsYear;
   Test_TheRememberedExchangeReadsTheField;
   Test_ASchema6LogIsReCarriedFromTheZone;
   if FDir <> '' then
      begin
      RemoveDir(FDir);
      end;
end;

(* --------------------------------------------------------------------------- *)
(* TNetReceivedYearTests -- the wire, over the real uNet and a stub writer      *)
(* --------------------------------------------------------------------------- *)

(* THE QSO PACKET CARRIES THE YEAR: the record goes out as it is, its year in
  the bytes that were sReserved (the packet is still 384 bytes). *)
procedure TNetReceivedYearTests.Test_AQSOPacketCarriesTheYear;
var
   link: TStubLink;
   rec: ContestExchange;
begin
   BeginTest('a QSO packet carries the received year, and the year 00');
   OpenScratchStore;
   link := TStubLink.Create;
   try
      NetClient := TNetClient.CreateWithWriter(link.Write);
      AttachNetClient(NetClient);
      try
         NetBeginLinkSession;
         CheckEquals(384, SizeOf(TNetQSOInformation), 'the packet did not grow');
         rec := AppendRow('S50YR', 811, 1, False, False);
         rec.RcvdYear := 85;
         rec.RcvdYearKnown := True;
         CheckTrue(SendRecordToServer(NET_QSOINFO_ID, rec), 'posted');
         CheckTrue(WaitWrites(link, 1), 'written');
         CheckTrue(link.Last.qiInformation.RcvdYearKnown, 'the packet has a year');
         CheckEquals(85, link.Last.qiInformation.RcvdYear, 'and it is 85');

         rec.RcvdYear := 0;
         CheckTrue(SendRecordToServer(NET_EDITEDQSO_ID, rec), 'an edit is posted');
         CheckTrue(WaitWrites(link, 2), 'and written');
         CheckTrue(link.Last.qiInformation.RcvdYearKnown, 'the year 00 is a year');
         CheckEquals(0, link.Last.qiInformation.RcvdYear, 'held as 0');
         SettleServerProgress;
      finally
         NetClient.Free;
         NetClient := nil;
      end;
   finally
      link.Free;
      CloseScratchStore;
   end;
end;

(* A QSO FROM THE SERVER'S LOG STORES THE YEAR IT CARRIES. The server stores
  each QSO packet's record as it comes (SERVERLOG.TRW, 376 bytes a record), and
  a station catching up adds the records its log lacks (uGetServerLog.
  MergeServerLog): the year rides the record in and out of rcvd_year.

  THE LIVE RECEIVE ARM is Test_AQSOReceivedLiveStoresTheYear (stage 2), which
  also says why stage 1 could not run it. *)
procedure TNetReceivedYearTests.Test_AServerLogQSOStoresTheYear;
var
   image: TServerLogImage;
   withYear, withoutYear, stored: ContestExchange;
   added, skipped: integer;
   why, backups: string;

   function ServerRecord(const aCall: string; aId2: Cardinal): ContestExchange;
   begin
      Result := Default(ContestExchange);
      Result.ceRecordKind := rkQSO;
      Result.ceContest := Contest;
      Result.ceComputerID := 'B';      (* station 2, who announced our contest *)
      Result.Callsign := ShortString(aCall);
      Result.ceQSOID1 := 812;
      Result.ceQSOID2 := aId2;
      Result.ceSendToServer := True;
      Result.Band := Band20;
      Result.Mode := CW;
      Result.Frequency := 14025000;
      Result.tSysTime.qtYear := 26;
      Result.tSysTime.qtMonth := 6;
      Result.tSysTime.qtDay := 1;
      Result.tSysTime.qtHour := 12;
      Result.tSysTime.qtMinute := aId2;
   end;

begin
   BeginTest('a QSO caught up from the server''s log stores its received year');
   OpenScratchStore;
   backups := IncludeTrailingPathDelimiter(FDir) + 'backup';
   ForceDirectories(backups);
   NetBeginLinkSession;
   try
      FeedHello(PEER, ContestId(Contest));
      withYear := ServerRecord('S51YR', 1);
      withYear.RcvdYear := 92;
      withYear.RcvdYearKnown := True;
      withoutYear := ServerRecord('S52NY', 2);

      image := NewImage([withYear, withoutYear]);
      try
         CheckTrue(MergeServerLog(image, backups, added, skipped, why),
                   'the merge succeeds: ' + why);
         CheckEquals(2, added, 'both QSOs were added');
      finally
         image.Free;
      end;

      CheckTrue(ReadRow(812, 1, stored), 'the first QSO is in the log');
      CheckTrue(stored.RcvdYearKnown, 'with a year');
      CheckEquals(92, stored.RcvdYear, 'the one the server held');
      CheckTrue(ReadRow(812, 2, stored), 'the second QSO is in the log');
      CheckFalse(stored.RcvdYearKnown, 'with none, as the server held it');
   finally
      CloseScratchStore;
   end;
end;

(* A QSO RECEIVED LIVE STORES ITS YEAR -- the real NET_QSOINFO arm, fed
  through NetBuffer: PeerRecordInOurContest, then LogContact(.., False), which
  writes the record as it came (tAddQSOToLog), then UpdateWindows.

  STAGE 1 COULD NOT RUN THIS: the arm raised an access violation here and the
  test was replaced by the catch-up path. STAGE 2 FOUND WHY, by running each
  step of the arm and of LogContact on its own (2026-11-12): LogContact
  completed and the row was STORED, year and all; the fault was the display
  -- UpdateWindows' DisplayTotalScore, DisplayNextQSONumber and
  DisplayQSOsByOpMode, and LogContact's DisplayHour, each write a panel of
  TR4WMainForm, which this binary never creates. In the program the form
  exists before the link can deliver anything (uProgramMain: CreateMainWindow,
  then NetLinkStartup; a received packet is parsed on the main thread through
  Application.QueueAsyncCall), so it was a gap in the harness, not a defect in
  the arm. The designed form is streamed for the test (uTestMainFormHarness)
  and released after it, as uTestStatusAndNotice does.

  THE PEER'S QSOs ARE X-QSOs, so LogContact keeps them off the session's
  totals, sheets and score view -- state this binary shares with every later
  suite -- while the path that STORES the record is the same. The call list
  the arm writes the remembered exchange to is a fresh one, put back after.
  The year rides the record whatever the session's contest (ARRL DX CW here):
  the arm neither parses nor rewrites the exchange. *)
procedure TNetReceivedYearTests.Test_AQSOReceivedLiveStoresTheYear;
var
   pkt: NetQSOInformationPtr;
   desync: boolean;
   stored: ContestExchange;
   savedList: TCallsignsList;

   function PeerQSO(const aCall: string; aId2: Cardinal): ContestExchange;
   begin
      Result := Default(ContestExchange);
      Result.ceRecordKind := rkQSO;
      Result.ceContest := Contest;
      Result.ceComputerID := 'B';
      Result.Callsign := ShortString(aCall);
      Result.ceQSOID1 := 813;
      Result.ceQSOID2 := aId2;
      Result.ceSendToServer := True;
      Result.ceXQSO := True;
      Result.Band := Band20;
      Result.Mode := CW;
      Result.ExtMode := eCW;
      Result.Frequency := 14025000;
      Result.RSTSent := 599;
      Result.RSTReceived := 599;
      Result.NumberSent := -1;
      Result.NumberReceived := -1;
      Result.Prefecture := 255;
      Result.TenTenNum := 65535;
      Result.Zone := DUMMYZONE;
      Result.QTH.Zone := 255;
      Result.tSysTime.qtYear := 26;
      Result.tSysTime.qtMonth := 6;
      Result.tSysTime.qtDay := 1;
      Result.tSysTime.qtHour := 12;
      Result.tSysTime.qtMinute := aId2;
   end;

   procedure Receive(const aRec: ContestExchange);
   begin
      pkt := NetQSOInformationPtr(@NetBuffer[1]);
      pkt^ := Default(TNetQSOInformation);
      pkt^.qiID := NET_QSOINFO_ID;
      pkt^.qiComputerID := 2;          (* not this station's id *)
      pkt^.qiSenderID := PEER;
      pkt^.qiInformation := aRec;
      CheckEquals(SizeOf(TNetQSOInformation),
                  ConsumeNetBuffer(SizeOf(TNetQSOInformation), desync),
                  string(aRec.Callsign) + ': the whole packet was consumed');
      CheckFalse(desync, string(aRec.Callsign) + ': the stream stayed on a message boundary');
   end;

var
   withYear, yearZero, noYear: ContestExchange;
begin
   BeginTest('a QSO received live through the NET_QSOINFO arm stores its received year');
   OpenScratchStore;
   EnsureTestMainForm;
   savedList := CallsignsList;
   CallsignsList := TCallsignsList.Create;
   NetBeginLinkSession;
   try
      FeedHello(PEER, ContestId(Contest));

      withYear := PeerQSO('S53YR', 1);
      StoreLicenceYear(withYear, 85);
      yearZero := PeerQSO('S54YR', 2);
      StoreLicenceYear(yearZero, 0);
      noYear := PeerQSO('S55NY', 3);

      Receive(withYear);
      Receive(yearZero);
      Receive(noYear);

      CheckTrue(ReadRow(813, 1, stored), 'the first QSO is in the log');
      CheckTrue(stored.RcvdYearKnown, 'with a year');
      CheckEquals(85, integer(stored.RcvdYear), 'the one the peer sent');
      CheckTrue(ReadRow(813, 2, stored), 'the second QSO is in the log');
      CheckTrue(stored.RcvdYearKnown, 'the year 00 is a year');
      CheckEquals(0, integer(stored.RcvdYear), 'held as 0');
      CheckTrue(ReadRow(813, 3, stored), 'the third QSO is in the log');
      CheckFalse(stored.RcvdYearKnown, 'with no year, as the peer sent it');
   finally
      CallsignsList.Free;
      CallsignsList := savedList;
      ReleaseTestMainForm;
      CloseScratchStore;
   end;
end;

(* THE SENT YEAR TRAVELS (issue 300, protocol 4). Three links, in a contest that
  sends a year (EUHFC):

    the PACKET    carries YearSent / YearSentKnown at offsets 328 / 327 of the
                  record (inside the 384-byte packet, which did not grow)
    the CATCH-UP  a peer's record in the server's log stores ITS year in
                  year_sent -- 91, the year 00, and none for a record that
                  carries none (an older server log) -- never ours
    the RESEND    a STORED row read back carries the year it holds, so the
                  resend, the restock and an edit send the SENDER's year and
                  not this station's

  The live NET_QSOINFO arm reaches the store through CaptureMyFactsNow, which
  uTestLogMyFacts.TestTheStoreRecordsTheYearOurQSOSent drives. *)
procedure TNetReceivedYearTests.Test_APeersSentYearTravelsAndIsStored;
var
   link: TStubLink;
   image: TServerLogImage;
   rec, stored: ContestExchange;
   one, two, three: ContestExchange;
   added, skipped: integer;
   why, backups: string;

   function PeerRecord(const aCall: string; aId2: Cardinal): ContestExchange;
   begin
      Result := Default(ContestExchange);
      Result.ceRecordKind := rkQSO;
      Result.ceContest := Contest;
      Result.ceComputerID := 'B';      (* station 2, who announced our contest *)
      Result.Callsign := ShortString(aCall);
      Result.ceQSOID1 := 814;
      Result.ceQSOID2 := aId2;
      Result.ceSendToServer := True;
      Result.Band := Band20;
      Result.Mode := CW;
      Result.Frequency := 14025000;
      Result.tSysTime.qtYear := 26;
      Result.tSysTime.qtMonth := 6;
      Result.tSysTime.qtDay := 1;
      Result.tSysTime.qtHour := 12;
      Result.tSysTime.qtMinute := aId2;
   end;

begin
   BeginTest('a peer''s sent year rides the packet, the catch-up and the resend');
   OpenScratchStore;
   Contest := ContestHandleOf(EUROPEANHFC);
   backups := IncludeTrailingPathDelimiter(FDir) + 'backup';
   ForceDirectories(backups);
   link := TStubLink.Create;
   try
      NetClient := TNetClient.CreateWithWriter(link.Write);
      AttachNetClient(NetClient);
      try
         NetBeginLinkSession;
         FeedHello(PEER, ContestId(Contest));

         (* THE PACKET *)
         rec := PeerRecord('S56YS', 9);
         StoreSentLicenceYear(rec, True, 77);
         CheckEquals(327, PtrUInt(@rec.YearSentKnown) - PtrUInt(@rec), 'Known at 327');
         CheckEquals(328, PtrUInt(@rec.YearSent) - PtrUInt(@rec), 'the year at 328');
         CheckTrue(SendRecordToServer(NET_QSOINFO_ID, rec), 'posted');
         CheckTrue(WaitWrites(link, 1), 'written');
         CheckTrue(link.Last.qiInformation.YearSentKnown, 'the packet says there is a year');
         CheckEquals(77, integer(link.Last.qiInformation.YearSent), 'and it is 77');

         (* THE CATCH-UP *)
         one := PeerRecord('S57YS', 1);
         StoreSentLicenceYear(one, True, 91);
         two := PeerRecord('S58YS', 2);
         StoreSentLicenceYear(two, True, 0);
         three := PeerRecord('S59NY', 3);
         image := NewImage([one, two, three]);
         try
            CheckTrue(MergeServerLog(image, backups, added, skipped, why),
                      'the merge succeeds: ' + why);
            CheckEquals(3, added, 'all three were added');
         finally
            image.Free;
         end;

         CheckTrue(ReadRow(814, 1, stored), 'the first is in the log');
         CheckTrue(stored.YearSentKnown, 'it holds the year the peer sent');
         CheckEquals(91, integer(stored.YearSent), 'the peer''s 91');
         CheckTrue(ReadRow(814, 2, stored), 'the second is in the log');
         CheckTrue(stored.YearSentKnown, 'the year 00 is a year');
         CheckEquals(0, integer(stored.YearSent), 'held as 0');
         CheckTrue(ReadRow(814, 3, stored), 'the third is in the log');
         CheckFalse(stored.YearSentKnown, 'a record with none stores none');

         (* THE RESEND OF A STORED ROW carries the year it holds *)
         CheckTrue(ReadRow(814, 1, stored), 'read back for the resend');
         CheckTrue(SendRecordToServer(NET_EDITEDQSO_ID, stored), 'an edit is posted');
         CheckTrue(WaitWrites(link, 2), 'and written');
         CheckTrue(link.Last.qiInformation.YearSentKnown, 'the edit has the year');
         CheckEquals(91, integer(link.Last.qiInformation.YearSent),
                     'the peer''s, not this station''s');
         SettleServerProgress;
      finally
         NetClient.Free;
         NetClient := nil;
      end;
   finally
      link.Free;
      CloseScratchStore;
   end;
end;

procedure TNetReceivedYearTests.RunAllTests;
begin
   Test_AQSOPacketCarriesTheYear;
   Test_AServerLogQSOStoresTheYear;
   Test_AQSOReceivedLiveStoresTheYear;
   Test_APeersSentYearTravelsAndIsStored;
end;

end.
