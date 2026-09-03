unit uTestLogRepository;

(* ContestExchange -> a qso row -> ContestExchange, ROUND TRIP.

  Task A4 of docs\SQLITE_MIGRATION_TASKS.md, and it is the reason A1's crosswalk
  was written exhaustively rather than by inspection. CLAUDE.md rule 9: a
  silently defaulted field reads as a legal zero. A field the mapper forgets does
  not fail -- it comes back empty, and it comes back empty on somebody's contest
  log a year from now.

  SO THE COMPARISON IS FIELD BY FIELD AND NAMED. Not CompareMem over the record:
  ShortStrings carry undefined bytes past their length, the ZERO_nn padding is
  deliberately not persisted, and a memory compare would either fail for reasons
  that are not defects or be loosened until it caught nothing.

  AND IT RUNS OVER REAL D7-WRITTEN LOGS -- the corpus fixtures. Synthetic records
  would exercise the mapper against values the mapper's author chose. These carry
  what TR4W actually wrote: empty ids, -1 serials, zone 255, Ten-Ten 65535, and
  every combination of flags twenty years of contests produced. *)

{$I ..\..\src\tr4w.inc}

interface

uses
   (* VC is in the INTERFACE because CompareQSO takes ContestExchange. *)
   uTR4WTestFramework, VC;

type
   TLogRepositoryTests = class(TTestCase)
   private
      FDir: string;
      function TempLogName(const aLeaf: string): string;
      procedure Scrub(const aFileName: string);
      function CorpusLog(const aSet: string): string;

      (* A METHOD, not a free function: CheckEquals is protected on TTestCase,
        which is the framework saying assertions belong to a test. *)
      procedure CompareQSO(const a, b: ContestExchange; const where: string);
   protected
      procedure TestOneQSORoundTrips;
      procedure Test_LegacySkippedIsReadAsDeleted;
      procedure TestSentinelsBecomeNullAndComeBack;
      procedure TestEveryRowGetsItsOwnGuid;
      procedure TestCountyLineQSOsShareAnExchangeId;
      procedure TestSearchAndPounceIsInverted;
      procedure TestKidsFollowsTheRecordKind;
      procedure TestUUIDv7ShapeAndOrdering;
      procedure TestImportingTheSameFileTwiceAddsNothing;
      procedure TestImportUpdatesAnExistingQSO;
      procedure TestImportWithNoGuidAppends;
      procedure TestUpdateReplacesTheRow;
      procedure TestUpdateOfAMissingRowSaysSo;
      procedure TestWholeCorpusLogRoundTrips;
      procedure TestIndexAddressesTheSameRecordAsAReadInOrder;
   public
      procedure RunAllTests; override;
   end;

implementation

uses
   (* Windows for MAXBYTE / MAXWORD -- the not-set markers ClearContestExchange
     writes, and the values this suite exists to prove never reach the log. *)
   Windows, SysUtils, Classes, uLogDatabase, uLogSchema, uLogBinaryFile,
   uLogRepository;

function TLogRepositoryTests.TempLogName(const aLeaf: string): string;
begin
   if FDir = '' then
      begin
      FDir := IncludeTrailingPathDelimiter(GetTempDir) +
              'tr4w_logrepo_' + IntToStr(GetProcessID);
      ForceDirectories(FDir);
      end;
   Result := IncludeTrailingPathDelimiter(FDir) + aLeaf;
end;

procedure TLogRepositoryTests.Scrub(const aFileName: string);
begin
   if FileExists(aFileName) then DeleteFile(aFileName);
   if FileExists(aFileName + '-wal') then DeleteFile(aFileName + '-wal');
   if FileExists(aFileName + '-shm') then DeleteFile(aFileName + '-shm');
end;

function TLogRepositoryTests.CorpusLog(const aSet: string): string;
begin
   Result := ExtractFilePath(ParamStr(0)) + '..\corpus\' + aSet + '\log.trw';
end;

(* --------------------------------------------------------------------------- *)

(* EVERY PERSISTED FIELD, NAMED. Adding a column to the mapper without adding it
  here leaves the new column untested, which is the same hole one level up --
  so the crosswalk, the schema and this list are three places that must agree,
  and the build fails if they do not. *)
procedure TLogRepositoryTests.CompareQSO(const a, b: ContestExchange;
                                        const where: string);

   procedure Same(const aName: string; const x, y: AnsiString);
   begin
      CheckEquals(string(x), string(y), where + ': ' + aName);
   end;

   procedure SameInt(const aName: string; x, y: integer);
   begin
      CheckEquals(x, y, where + ': ' + aName);
   end;

   procedure SameBool(const aName: string; x, y: boolean);
   begin
      CheckEquals(Ord(x), Ord(y), where + ': ' + aName);
   end;

begin
   (* identity *)
   SameInt('ceQSOID1', integer(a.ceQSOID1), integer(b.ceQSOID1));
   SameInt('ceQSOID2', integer(a.ceQSOID2), integer(b.ceQSOID2));
   Same('ceComputerID', AnsiString(a.ceComputerID), AnsiString(b.ceComputerID));
   SameInt('ceOperatorID', a.ceOperatorID, b.ceOperatorID);
   SameInt('ceRecordKind', Ord(a.ceRecordKind), Ord(b.ceRecordKind));

   (* COMPARED, even though it is stored on the CONTEST row rather than the QSO
     row. That is exactly why it needs checking: nothing else would notice a
     QSO coming back as DUMMYCONTEST, and PostUnit branches on
     `rec.ceContest = POTA` while exporting. *)
   SameInt('ceContest', Ord(a.ceContest), Ord(b.ceContest));

   (* when and what *)
   SameInt('tSysTime', integer(QSOTimeToUnixUTC(a.tSysTime)),
                       integer(QSOTimeToUnixUTC(b.tSysTime)));
   Same('Callsign', AnsiString(a.Callsign), AnsiString(b.Callsign));
   Same('QTH.StandardCall', AnsiString(a.QTH.StandardCall), AnsiString(b.QTH.StandardCall));
   SameInt('Frequency', a.Frequency, b.Frequency);
   SameInt('Band', Ord(a.Band), Ord(b.Band));
   SameInt('Mode', Ord(a.Mode), Ord(b.Mode));
   SameInt('ExtMode', Ord(a.ExtMode), Ord(b.ExtMode));
   Same('ExchString', AnsiString(a.ExchString), AnsiString(b.ExchString));

   (* the exchange *)
   SameInt('RSTSent', a.RSTSent, b.RSTSent);
   SameInt('RSTReceived', a.RSTReceived, b.RSTReceived);
   SameInt('NumberSent', a.NumberSent, b.NumberSent);
   SameInt('NumberReceived', a.NumberReceived, b.NumberReceived);
   SameInt('Zone', a.Zone, b.Zone);
   Same('Name', AnsiString(a.Name), AnsiString(b.Name));
   SameInt('Age', a.Age, b.Age);
   SameInt('Check', a.Check, b.Check);
   Same('Precedence', AnsiString(a.Precedence), AnsiString(b.Precedence));
   Same('ceClass', AnsiString(a.ceClass), AnsiString(b.ceClass));
   Same('Power', AnsiString(a.Power), AnsiString(b.Power));
   Same('Chapter', AnsiString(a.Chapter), AnsiString(b.Chapter));
   SameInt('Prefecture', a.Prefecture, b.Prefecture);
   SameInt('TenTenNum', a.TenTenNum, b.TenTenNum);
   Same('QTHString', AnsiString(a.QTHString), AnsiString(b.QTHString));
   Same('RandomCharsReceived', AnsiString(a.RandomCharsReceived),
                               AnsiString(b.RandomCharsReceived));
   Same('RandomCharsSent', AnsiString(a.RandomCharsSent), AnsiString(b.RandomCharsSent));
   Same('Kids', AnsiString(a.Kids), AnsiString(b.Kids));
   Same('DomesticQTH', AnsiString(a.DomesticQTH), AnsiString(b.DomesticQTH));

   (* CTY.DAT-derived *)
   Same('QTH.Prefix', AnsiString(a.QTH.Prefix), AnsiString(b.QTH.Prefix));
   Same('QTH.CountryID', AnsiString(a.QTH.CountryID), AnsiString(b.QTH.CountryID));
   SameInt('QTH.Country', a.QTH.Country, b.QTH.Country);
   SameInt('QTH.Zone', a.QTH.Zone, b.QTH.Zone);
   SameInt('QTH.Continent', Ord(a.QTH.Continent), Ord(b.QTH.Continent));

   (* multipliers *)
   Same('Prefix', AnsiString(a.Prefix), AnsiString(b.Prefix));
   Same('DXQTH', AnsiString(a.DXQTH), AnsiString(b.DXQTH));
   Same('DomMultQTH', AnsiString(a.DomMultQTH), AnsiString(b.DomMultQTH));
   SameBool('DomesticMult', a.DomesticMult, b.DomesticMult);
   SameBool('DXMult', a.DXMult, b.DXMult);
   SameBool('PrefixMult', a.PrefixMult, b.PrefixMult);
   SameBool('ZoneMult', a.ZoneMult, b.ZoneMult);
   SameBool('InhibitMults', a.InhibitMults, b.InhibitMults);

   (* state *)
   SameInt('QSOPoints', a.QSOPoints, b.QSOPoints);
   SameBool('ceDupe', a.ceDupe, b.ceDupe);
   SameBool('ceSearchAndPounce', a.ceSearchAndPounce, b.ceSearchAndPounce);
   SameBool('ceXQSO', a.ceXQSO, b.ceXQSO);
   (* ceQSO_Skiped IS DELIBERATELY NOT ROUND-TRIPPED. It is a legacy slot kept
      so the 376-byte binary record still reads; the database never stores it
      and the reader always returns False. Asserting equality here would pin
      the behaviour that was just removed. The FOLD is tested separately -- see
      the fold is exercised by Test_LegacySkippedIsReadAsDeleted, and
      ceQSO_Deleted itself is already asserted below. *)
   SameBool('ceWasSendInQTC', a.ceWasSendInQTC, b.ceWasSendInQTC);
   SameBool('NameSent', a.NameSent, b.NameSent);
   SameBool('MP3Record', a.MP3Record, b.MP3Record);
   SameBool('ceClearDupeSheet', a.ceClearDupeSheet, b.ceClearDupeSheet);
   SameBool('ceClearMultSheet', a.ceClearMultSheet, b.ceClearMultSheet);
   SameInt('ceRadio', Ord(a.ceRadio), Ord(b.ceRadio));
   (* Compared through the same NUL-aware helper the mapper uses -- a direct
     AnsiString() cast of this array is the bug this line would hide. *)
   Same('ceOperator', CharArrayToAnsi(a.ceOperator),
                      CharArrayToAnsi(b.ceOperator));
   SameBool('ceQSO_Deleted', a.ceQSO_Deleted, b.ceQSO_Deleted);
   SameBool('ceSendToServer', a.ceSendToServer, b.ceSendToServer);
   SameBool('ceNeedSendToServerAE', a.ceNeedSendToServerAE, b.ceNeedSendToServerAE);
end;

(* --------------------------------------------------------------------------- *)

procedure TLogRepositoryTests.TestOneQSORoundTrips;
var
   db: TLogDatabase;
   repo: TLogRepository;
   reader: TLogBinaryReader;
   before, after: ContestExchange;
   rowId: Int64;
   fn: string;
   got: boolean;
begin
   BeginTest('TestOneQSORoundTrips');
   fn := TempLogName('one.db');
   Scrub(fn);

   reader := TLogBinaryReader.Create(CorpusLog('cqww_ssb_2025_ny4i'));
   try
      CheckTrue(reader.Status = lbOK, 'the fixture opens: ' + reader.Message);
      got := False;
      while (not got) and reader.ReadNext(before) do
         begin
         got := GoodLookingQSO(before);
         end;
      CheckTrue(got, 'the fixture has a QSO to round-trip');
   finally
      reader.Free;
   end;

   db := TLogDatabase.Create;
   try
      db.CreateNew(fn);
      repo := TLogRepository.Create(db);
      try
         (* The contest lives on the contest row, so it has to be set before a
           QSO can round-trip completely -- which is what the importer does
           from the first record it reads. *)
         repo.SetContest(before.ceContest);
         rowId := repo.SaveQSO(before);
         repo.Commit;
         CheckTrue(repo.LoadQSO(rowId, after), 'the saved QSO reads back');
         CompareQSO(before, after, 'cqww first QSO');
      finally
         repo.Free;
      end;
   finally
      db.Free;
   end;

   Scrub(fn);
end;

(* A DATABASE WRITTEN BEFORE THE FLAGS WERE UNIFIED STILL HIDES ITS DELETIONS.

  ceQSO_Skiped and ceQSO_Deleted were two flags meaning one thing until
  2026-09-02. Logs written before that can carry `is_skipped = 1` on a row whose
  `deleted` is 0 -- Alt-Y set the first, the editor's checkbox set the second.
  The reader folds the legacy column in, so those QSOs stay deleted.

  WITHOUT THE FOLD THEY COME BACK FROM THE DEAD: silently un-deleted, counted
  for score, and exported in the Cabrillo. That is a worse failure than losing
  them, because the operator has no reason to look.

  THE COLUMN IS WRITTEN DIRECTLY, because it has to be. The save path binds
  is_skipped to False now, so there is no way to produce this row through the
  API -- which is exactly why the fold needs a test rather than an argument. *)
procedure TLogRepositoryTests.Test_LegacySkippedIsReadAsDeleted;
var
   db:     TLogDatabase;
   repo:   TLogRepository;
   reader: TLogBinaryReader;
   before, after: ContestExchange;
   fn:     string;
   rowId:  Int64;
   got:    boolean;
begin
   BeginTest('Test_LegacySkippedIsReadAsDeleted');

   fn := TempLogName('legacyskipped.db');
   reader := TLogBinaryReader.Create(CorpusLog('cqww_ssb_2025_ny4i'));
   try
      got := reader.ReadNext(before);
      CheckTrue(got, 'the fixture has a QSO');
   finally
      reader.Free;
   end;

   (* Saved NOT deleted, so the only thing that can delete it is the fold. *)
   before.ceQSO_Deleted := False;
   before.ceQSO_Skiped  := False;

   db := TLogDatabase.Create;
   try
      db.CreateNew(fn);
      repo := TLogRepository.Create(db);
      try
         repo.SetContest(before.ceContest);
         rowId := repo.SaveQSO(before);
         repo.Commit;

         CheckTrue(repo.LoadQSO(rowId, after), 'the QSO reads back');
         CheckFalse(after.ceQSO_Deleted, 'not deleted before the legacy column is set');

         (* Forge the pre-unification shape: skipped set, deleted clear. *)
         db.Connection.ExecuteDirect(
            'UPDATE qso SET is_skipped = 1, deleted = 0 WHERE id = ' +
            IntToStr(rowId));
         db.Transaction.Commit;

         CheckTrue(repo.LoadQSO(rowId, after), 'the forged row reads back');
         CheckTrue(after.ceQSO_Deleted,
                   'a legacy is_skipped row comes back DELETED, not alive');
      finally
         repo.Free;
      end;
   finally
      db.Free;
   end;

   Scrub(fn);
end;

procedure TLogRepositoryTests.TestSentinelsBecomeNullAndComeBack;
var
   db: TLogDatabase;
   repo: TLogRepository;
   before, after: ContestExchange;
   rowId: Int64;
   fn: string;
begin
   BeginTest('TestSentinelsBecomeNullAndComeBack');
   fn := TempLogName('sentinel.db');
   Scrub(fn);

   (* The shape ClearContestExchange leaves: not-set markers that are the type's
     MAXIMUM, not zero. Crosswalk finding 3. *)
   FillChar(before, SizeOf(before), 0);
   before.Band := Band20;
   before.Mode := CW;
   before.ExtMode := eCW;
   before.ceRecordKind := rkQSO;
   before.Callsign := 'NY4I';
   before.NumberSent := -1;
   before.NumberReceived := -1;
   before.Prefecture := MAXBYTE;
   before.Zone := DUMMYZONE;
   before.QTH.Zone := DUMMYZONE;
   before.QTH.Country := UNKNOWN_COUNTRY;
   before.QTH.Continent := UnknownContinent;
   before.TenTenNum := MAXWORD;
   before.tSysTime.qtYear := 26;
   before.tSysTime.qtMonth := 2;
   before.tSysTime.qtDay := 11;

   db := TLogDatabase.Create;
   try
      db.CreateNew(fn);
      repo := TLogRepository.Create(db);
      try
         rowId := repo.SaveQSO(before);
         repo.Commit;
         CheckTrue(repo.LoadQSO(rowId, after), 'it reads back');

         (* Each of these is a value that would look exactly like data if the
           mapper wrote the sentinel through. *)
         CheckEquals(-1, after.NumberSent, 'a -1 serial is not 0');
         CheckEquals(-1, after.NumberReceived, 'nor the received one');
         CheckEquals(integer(DUMMYZONE), integer(after.Zone),
                     'an unset zone comes back unset, not 0 and not 255-as-data');
         CheckEquals(integer(DUMMYZONE), integer(after.QTH.Zone),
                     'and the CTY.DAT one likewise');
         CheckEquals(integer(MAXBYTE), integer(after.Prefecture), 'prefecture');
         CheckEquals(integer(MAXWORD), integer(after.TenTenNum), 'Ten-Ten number');
         CheckEquals(integer(UNKNOWN_COUNTRY), integer(after.QTH.Country), 'country');
         CheckEquals(Ord(UnknownContinent), Ord(after.QTH.Continent), 'continent');
      finally
         repo.Free;
      end;
   finally
      db.Free;
   end;

   Scrub(fn);
end;

procedure TLogRepositoryTests.TestEveryRowGetsItsOwnGuid;
var
   qso: ContestExchange;
   g1, g2: AnsiString;
begin
   BeginTest('TestEveryRowGetsItsOwnGuid');

   FillChar(qso, SizeOf(qso), 0);
   qso.id := '5cd6c61f69cf4422baef44f93b2cbbd2';   (* a real corpus id *)
   qso.tSysTime.qtYear := 26;
   qso.tSysTime.qtMonth := 2;
   qso.tSysTime.qtDay := 11;

   g1 := NewRowGuid(qso);
   g2 := NewRowGuid(qso);

   CheckEquals(32, Length(g1), 'a row guid fits ContestExchange.id exactly');

   (* THE POINT: the same record minted twice gives two guids, because two rows
     are two rows even when they came from one exchange. *)
   CheckTrue(g1 <> g2, 'the same record yields a DIFFERENT guid each time');
   CheckTrue(g1 <> AnsiString(qso.id), 'and it is never the record''s own id');
end;

procedure TLogRepositoryTests.TestCountyLineQSOsShareAnExchangeId;
var
   db: TLogDatabase;
   repo: TLogRepository;
   pin, hil, back: ContestExchange;
   gPin, gHil: Int64;
   fn: string;
begin
   BeginTest('TestCountyLineQSOsShareAnExchangeId');
   fn := TempLogName('countyline.db');
   Scrub(fn);

   (* THE CASE THAT BROKE THE FIRST DESIGN, taken from the corpus: two W4THY
     rows in florida_qp_2026_ny4i, one for PIN and one for HIL, both carrying
     5cd6c61f69cf4422baef44f93b2cbbd2. One exchange, two QSOs. Making the
     record's id the unique row key fails on the second of these -- which is
     every county line in every QSO party. *)
   FillChar(pin, SizeOf(pin), 0);
   pin.ceRecordKind := rkQSO;
   pin.Callsign := 'W4THY';
   pin.id := '5cd6c61f69cf4422baef44f93b2cbbd2';
   pin.QTHString := 'PIN';
   pin.tSysTime.qtYear := 26;
   pin.tSysTime.qtMonth := 5;
   pin.tSysTime.qtDay := 11;

   hil := pin;
   hil.QTHString := 'HIL';

   db := TLogDatabase.Create;
   try
      db.CreateNew(fn);
      repo := TLogRepository.Create(db);
      try
         gPin := repo.SaveQSO(pin);
         gHil := repo.SaveQSO(hil);
         repo.Commit;

         CheckTrue(gPin <> gHil, 'the two QSOs get DIFFERENT rows');
         CheckEquals(2, repo.QSOCount, 'and both are in the log');

         CheckTrue(repo.LoadQSO(gPin, back), 'the PIN row reads back');
         CheckEquals('PIN', string(back.QTHString), 'as PIN');
         CheckEquals('5cd6c61f69cf4422baef44f93b2cbbd2', string(back.id),
                     'carrying the shared exchange id');

         CheckTrue(repo.LoadQSO(gHil, back), 'the HIL row reads back');
         CheckEquals('HIL', string(back.QTHString), 'as HIL');
         CheckEquals('5cd6c61f69cf4422baef44f93b2cbbd2', string(back.id),
                     'carrying the SAME exchange id -- that is the fact, not a clash');
      finally
         repo.Free;
      end;
   finally
      db.Free;
   end;

   Scrub(fn);
end;

procedure TLogRepositoryTests.TestSearchAndPounceIsInverted;
var
   db: TLogDatabase;
   repo: TLogRepository;
   before, after: ContestExchange;
   rowId: Int64;
   fn: string;
begin
   BeginTest('TestSearchAndPounceIsInverted');
   fn := TempLogName('sandp.db');
   Scrub(fn);

   FillChar(before, SizeOf(before), 0);
   before.ceRecordKind := rkQSO;
   before.Callsign := 'W1AW';
   before.ceSearchAndPounce := True;      (* so is_run must be 0 *)
   before.tSysTime.qtYear := 26;
   before.tSysTime.qtMonth := 6;
   before.tSysTime.qtDay := 1;

   db := TLogDatabase.Create;
   try
      db.CreateNew(fn);
      repo := TLogRepository.Create(db);
      try
         rowId := repo.SaveQSO(before);
         repo.Commit;
         CheckTrue(repo.LoadQSO(rowId, after), 'it reads back');

         (* A straight copy instead of an inversion would be wrong in a way
           nothing reports -- every S&P QSO would read as a run QSO. *)
         CheckTrue(after.ceSearchAndPounce,
                   'S&P survives the round trip through an INVERTED is_run');
      finally
         repo.Free;
      end;
   finally
      db.Free;
   end;

   Scrub(fn);
end;

procedure TLogRepositoryTests.TestKidsFollowsTheRecordKind;
var
   db: TLogDatabase;
   repo: TLogRepository;
   qso, qtc, back: ContestExchange;
   gQso, gQtc: Int64;
   fn: string;
begin
   BeginTest('TestKidsFollowsTheRecordKind');
   fn := TempLogName('kids.db');
   Scrub(fn);

   FillChar(qso, SizeOf(qso), 0);
   qso.ceRecordKind := rkQSO;
   qso.Callsign := 'DL8UHJ';
   qso.Kids := 'SOME EXCHANGE';
   qso.tSysTime.qtYear := 26;
   qso.tSysTime.qtMonth := 8;
   qso.tSysTime.qtDay := 8;

   qtc := qso;
   qtc.ceRecordKind := rkQTCS;
   qtc.Kids := 'G3ABC';               (* a CALLSIGN, not exchange text *)

   db := TLogDatabase.Create;
   try
      db.CreateNew(fn);
      repo := TLogRepository.Create(db);
      try
         gQso := repo.SaveQSO(qso);
         gQtc := repo.SaveQSO(qtc);
         repo.Commit;

         (* One column meaning either, depending on another column, is how a
           wrong Cabrillo line gets written two years from now. Two columns,
           and the record kind decides. *)
         CheckTrue(repo.LoadQSO(gQso, back), 'the QSO reads back');
         CheckEquals('SOME EXCHANGE', string(back.Kids),
                     'for rkQSO, Kids is the exchange text');

         CheckTrue(repo.LoadQSO(gQtc, back), 'the QTC reads back');
         CheckEquals('G3ABC', string(back.Kids),
                     'for rkQTCS, Kids is the callsign inside the QTC');
      finally
         repo.Free;
      end;
   finally
      db.Free;
   end;

   Scrub(fn);
end;

procedure TLogRepositoryTests.TestUUIDv7ShapeAndOrdering;
var
   early, late: AnsiString;
begin
   BeginTest('TestUUIDv7ShapeAndOrdering');

   early := NewUUIDv7(1000000000000);     (* 2001 *)
   late  := NewUUIDv7(1800000000000);     (* 2027 *)

   CheckEquals(32, Length(early), 'a guid is 32 hex characters, no dashes');
   (* Six bytes of timestamp are twelve hex characters, so the version nibble is
     the thirteenth. *)
   CheckEquals('7', string(early[13]), 'version 7');

   (* The reason question 5 chose v7 over v4: it sorts by creation time, so rows
     cluster in insertion order and a chooser can order by guid alone. *)
   CheckTrue(early < late, 'a v7 guid sorts by its timestamp');
end;

(* IMPORTING OUR OWN EXPORTED FILE, which is the point of keying on the guid.

  NY4I: "This allows us to import our own exported file. Also good for testing."
  Both halves matter -- an import that duplicates on a second run is one nobody
  dares repeat, and an import that cannot be repeated is useless as a test
  fixture. *)
procedure TLogRepositoryTests.TestImportingTheSameFileTwiceAddsNothing;
var
   db: TLogDatabase;
   repo: TLogRepository;
   a, b: ContestExchange;
   fn: string;
   wasNew: boolean;
   id1, id2: Int64;
begin
   BeginTest('TestImportingTheSameFileTwiceAddsNothing');
   fn := TempLogName('reimport.db');
   Scrub(fn);

   FillChar(a, SizeOf(a), 0);
   a.ceRecordKind := rkQSO;
   a.Callsign := 'W1AW';
   a.QTHString := 'CT';
   a.tSysTime.qtYear := 26;
   a.tSysTime.qtMonth := 6;
   a.tSysTime.qtDay := 1;

   (* The two halves of a COUNTY-LINE contact: one exchange, two QSOs, and in a
     real TR4W ADIF export they carry the SAME APP_TR4W_ID. That is exactly why
     the key here must be a PER-QSO guid: keying on the exchange id would merge
     these two and lose a contact. Measured on the shipped florida_qp export --
     3 records, 2 distinct APP_TR4W_ID. *)
   b := a;
   b.QTHString := 'MA';

   db := TLogDatabase.Create;
   try
      db.CreateNew(fn);
      repo := TLogRepository.Create(db);
      try
         id1 := repo.ImportQSOByGuid('018f3a2b7c1d7abc8def000000000001', a, wasNew);
         CheckTrue(wasNew, 'the first QSO is new');
         id2 := repo.ImportQSOByGuid('018f3a2b7c1d7abc8def000000000002', b, wasNew);
         CheckTrue(wasNew, 'and so is the second');
         repo.Commit;

         CheckTrue(id1 <> id2, 'they are two different rows');
         CheckEquals(2, repo.QSOCount, 'the log holds two QSOs');

         (* THE SECOND PASS -- the same file again. *)
         CheckEquals(id1, repo.ImportQSOByGuid(
                             '018f3a2b7c1d7abc8def000000000001', a, wasNew),
                     'the first QSO matches the row it created');
         CheckFalse(wasNew, 'and is not treated as new');
         CheckEquals(id2, repo.ImportQSOByGuid(
                             '018f3a2b7c1d7abc8def000000000002', b, wasNew),
                     'and so does the second');
         CheckFalse(wasNew, 'likewise');
         repo.Commit;

         CheckEquals(2, repo.QSOCount,
                     're-importing the same file adds NOTHING');
      finally
         repo.Free;
      end;
   finally
      db.Free;
   end;

   Scrub(fn);
end;

procedure TLogRepositoryTests.TestImportUpdatesAnExistingQSO;
var
   db: TLogDatabase;
   repo: TLogRepository;
   qso, back: ContestExchange;
   fn: string;
   wasNew: boolean;
   rowId: Int64;
begin
   BeginTest('TestImportUpdatesAnExistingQSO');
   fn := TempLogName('reimport2.db');
   Scrub(fn);

   FillChar(qso, SizeOf(qso), 0);
   qso.ceRecordKind := rkQSO;
   qso.Callsign := 'W1AW';
   qso.QTHString := 'CT';
   qso.tSysTime.qtYear := 26;
   qso.tSysTime.qtMonth := 6;
   qso.tSysTime.qtDay := 1;

   db := TLogDatabase.Create;
   try
      db.CreateNew(fn);
      repo := TLogRepository.Create(db);
      try
         rowId := repo.ImportQSOByGuid('018f3a2b7c1d7abc8def000000000003', qso, wasNew);

         (* Re-importing a CORRECTED file is the usual reason to do it twice, so
           the second pass must UPDATE rather than skip -- which is why this
           looks the row up instead of catching a unique violation. *)
         qso.QTHString := 'MA';
         CheckEquals(rowId,
                     repo.ImportQSOByGuid('018f3a2b7c1d7abc8def000000000003',
                                          qso, wasNew),
                     'the same guid lands on the same row');
         CheckFalse(wasNew, 'and is not new');
         repo.Commit;

         CheckTrue(repo.LoadQSO(rowId, back), 'it reads back');
         CheckEquals('MA', string(back.QTHString), 'carrying the correction');
         CheckEquals(1, repo.QSOCount, 'and there is still one QSO');
      finally
         repo.Free;
      end;
   finally
      db.Free;
   end;

   Scrub(fn);
end;

procedure TLogRepositoryTests.TestImportWithNoGuidAppends;
var
   db: TLogDatabase;
   repo: TLogRepository;
   qso: ContestExchange;
   fn: string;
   wasNew: boolean;
begin
   BeginTest('TestImportWithNoGuidAppends');
   fn := TempLogName('noguid.db');
   Scrub(fn);

   FillChar(qso, SizeOf(qso), 0);
   qso.ceRecordKind := rkQSO;
   qso.Callsign := 'W1AW';
   qso.tSysTime.qtYear := 26;
   qso.tSysTime.qtMonth := 6;
   qso.tSysTime.qtDay := 1;

   db := TLogDatabase.Create;
   try
      db.CreateNew(fn);
      repo := TLogRepository.Create(db);
      try
         (* A file from another program has no APP_TR4W_ID. With no identity
           there is nothing to match on, and guessing from "looks similar"
           is how an import loses a QSO -- so both go in. *)
         repo.ImportQSOByGuid('', qso, wasNew);
         CheckTrue(wasNew, 'a record with no guid is new');
         repo.ImportQSOByGuid('', qso, wasNew);
         CheckTrue(wasNew, 'and so is the next one');
         repo.Commit;

         CheckEquals(2, repo.QSOCount,
                     'two identical-looking records with no identity stay two');
      finally
         repo.Free;
      end;
   finally
      db.Free;
   end;

   Scrub(fn);
end;

(* UPDATE IS WHAT PHASE B2 ACTUALLY NEEDS. Of the eight sites that write a QSO to
  the log, FIVE seek to a position and rewrite -- DeleteLastContact, uNet's
  UpdateRec and FindAndUpdateQSOInLog, uQTCS.SetSendedQSOs, and the QSO editor.
  Only three append. *)
procedure TLogRepositoryTests.TestUpdateReplacesTheRow;
var
   db: TLogDatabase;
   repo: TLogRepository;
   before, edited, after: ContestExchange;
   rowId: Int64;
   fn: string;
begin
   BeginTest('TestUpdateReplacesTheRow');
   fn := TempLogName('update.db');
   Scrub(fn);

   FillChar(before, SizeOf(before), 0);
   before.ceRecordKind := rkQSO;
   before.Callsign := 'W1AW';
   before.QTHString := 'CT';
   before.RSTReceived := 599;
   before.tSysTime.qtYear := 26;
   before.tSysTime.qtMonth := 6;
   before.tSysTime.qtDay := 1;

   db := TLogDatabase.Create;
   try
      db.CreateNew(fn);
      repo := TLogRepository.Create(db);
      try
         rowId := repo.SaveQSO(before);
         CheckTrue(rowId > 0, 'saving returns a row id');
         CheckEquals(rowId, repo.NewestRowId,
                     'and it is the newest row -- what the three "seek back one ' +
                     'record" sites want');

         (* The edit an operator would make: fix the QTH and mark it a dupe. *)
         edited := before;
         edited.QTHString := 'MA';
         edited.ceDupe := True;

         CheckTrue(repo.UpdateQSO(rowId, edited), 'the update reports success');
         repo.Commit;

         CheckTrue(repo.LoadQSO(rowId, after), 'the row reads back');
         CheckEquals('MA', string(after.QTHString), 'with the edited QTH');
         CheckTrue(after.ceDupe, 'and the edited flag');
         CheckEquals('W1AW', string(after.Callsign), 'and the unchanged callsign');

         (* It REPLACED the row rather than adding one -- the file-based code
           rewrites in place and so must this. *)
         CheckEquals(1, repo.QSOCount, 'and there is still exactly one QSO');
      finally
         repo.Free;
      end;
   finally
      db.Free;
   end;

   Scrub(fn);
end;

procedure TLogRepositoryTests.TestUpdateOfAMissingRowSaysSo;
var
   db: TLogDatabase;
   repo: TLogRepository;
   qso: ContestExchange;
   fn: string;
begin
   BeginTest('TestUpdateOfAMissingRowSaysSo');
   fn := TempLogName('nosuchrow.db');
   Scrub(fn);

   FillChar(qso, SizeOf(qso), 0);
   qso.ceRecordKind := rkQSO;
   qso.Callsign := 'W1AW';

   db := TLogDatabase.Create;
   try
      db.CreateNew(fn);
      repo := TLogRepository.Create(db);
      try
         (* The file-based code CANNOT tell an edit from a no-op: it seeks and
           writes, and a bad offset corrupts or extends the file silently. This
           is one thing the database does better rather than differently, so it
           is worth a test of its own. *)
         CheckFalse(repo.UpdateQSO(999, qso),
                    'updating a row that does not exist reports failure');
         CheckEquals(0, repo.QSOCount, 'and creates nothing');
      finally
         repo.Free;
      end;
   finally
      db.Free;
   end;

   Scrub(fn);
end;

procedure TLogRepositoryTests.TestWholeCorpusLogRoundTrips;
const
   (* Four sets chosen to span the shapes: a DX zone contest, a domestic QSO
     party, a serial-number contest and Field Day's class exchange. *)
   SETS: array[0..3] of string = (
      'cqww_ssb_2025_ny4i', 'florida_qp_2026_ny4i',
      'cqwpx_cw_2026_ny4i', 'arrl_fd_2026_ny4i');
var
   s: integer;
   db: TLogDatabase;
   repo: TLogRepository;
   reader: TLogBinaryReader;
   before, after: ContestExchange;
   rowIds: TList;
   originals: TList;
   rec: ^ContestExchange;
   fn: string;
   i: integer;
   n: integer;
begin
   BeginTest('TestWholeCorpusLogRoundTrips');

   for s := Low(SETS) to High(SETS) do
      begin
      fn := TempLogName('corpus_' + IntToStr(s) + '.db');
      Scrub(fn);

      rowIds := TList.Create;
      originals := TList.Create;
      try
         db := TLogDatabase.Create;
         try
            db.CreateNew(fn);
            repo := TLogRepository.Create(db);
            try
               reader := TLogBinaryReader.Create(CorpusLog(SETS[s]));
               try
                  CheckTrue(reader.Status = lbOK, SETS[s] + ': ' + reader.Message);
                  n := 0;
                  while reader.ReadNext(before) do
                     begin
                     if not GoodLookingQSO(before) then
                        begin
                        Continue;
                        end;
                     (* As the importer does: the contest comes from the records,
                       because a binary log has no header that names it. Without
                       this every QSO reads back as DUMMYCONTEST. *)
                     if n = 0 then
                        begin
                        repo.SetContest(before.ceContest);
                        end;
                     New(rec);
                     rec^ := before;
                     originals.Add(rec);
                     (* A row id fits a pointer on this target and TList is what
                       the tree has; storing it as one keeps the test to the
                       collections already in use. *)
                     rowIds.Add(Pointer(PtrInt(repo.SaveQSO(before))));
                     Inc(n);
                     end;
               finally
                  reader.Free;
               end;
               repo.Commit;

               CheckEquals(n, repo.QSOCount,
                           SETS[s] + ': the database holds every QSO written');

               (* THE EXHAUSTIVE PART. Every QSO in the log, every persisted
                 field, both directions. *)
               for i := 0 to rowIds.Count - 1 do
                  begin
                  CheckTrue(repo.LoadQSO(Int64(PtrInt(rowIds[i])), after),
                            SETS[s] + ': QSO ' + IntToStr(i) + ' reads back');
                  rec := originals[i];
                  CompareQSO(rec^, after,
                             SETS[s] + ' #' + IntToStr(i) + ' (' +
                             string(rec^.Callsign) + ')');
                  end;
            finally
               repo.Free;
            end;
         finally
            db.Free;
         end;
      finally
         for i := 0 to originals.Count - 1 do
            begin
            rec := originals[i];
            Dispose(rec);
            end;
         originals.Free;
         rowIds.Free;
      end;

      Scrub(fn);
      end;
end;

(* ADDRESSING A RECORD BY INDEX MUST LAND ON THE SAME ONE AS COUNTING TO IT.

  Written because it did not. The QSO editor held a BYTE OFFSET into the .TRW
  and converted it back with `IndexInMap div SizeOf(ContestExchange)` --
  and SizeOfTLogHeader and SizeOf(ContestExchange) are BOTH 376 bytes, so the
  offset of record k is (k + 1) * 376 and that division returned k + 1. Every
  edit updated the row AFTER the one being edited: the QSO the operator
  corrected kept its old values, and a QSO they never touched silently took
  the new ones.

  Nothing failed. No exception, no warning, and the corpus could not see it
  because the corpus never edits. The offset is gone -- an index is carried
  from end to end now -- and this pins the contract that made it wrong, on
  EVERY record rather than on one: read the log in order, and separately
  address record i by index, and require them to be the same QSO. An
  off-by-one anywhere in that chain fails here. *)
procedure TLogRepositoryTests.TestIndexAddressesTheSameRecordAsAReadInOrder;
var
   db: TLogDatabase;
   repo: TLogRepository;
   qso, sequential, byIndex: ContestExchange;
   fn: string;
   i: integer;
   rowId: Int64;
   calls: array[0..5] of AnsiString;
begin
   BeginTest('TestIndexAddressesTheSameRecordAsAReadInOrder');
   fn := TempLogName('byindex.db');
   Scrub(fn);

   calls[0] := 'W1AW';  calls[1] := 'K2ABC'; calls[2] := 'N3XYZ';
   calls[3] := 'W4TA';  calls[4] := 'NY4I';  calls[5] := 'K6QQQ';

   db := TLogDatabase.Create;
   try
      db.CreateNew(fn);
      repo := TLogRepository.Create(db);
      try
         for i := 0 to High(calls) do
            begin
            FillChar(qso, SizeOf(qso), 0);
            qso.ceRecordKind := rkQSO;
            qso.Callsign := calls[i];
            qso.NumberReceived := i + 1;
            qso.tSysTime.qtYear := 26;
            qso.tSysTime.qtMonth := 6;
            qso.tSysTime.qtDay := 1;
            CheckTrue(repo.SaveQSO(qso) > 0, 'saved ' + string(calls[i]));
            end;

         CheckEquals(Length(calls), repo.RecordCount,
                     'every QSO is in the log');

         (* Walk it in order and, at each step, address the SAME position by
            index. The two must agree on every record -- not just the first,
            which an off-by-one would still get right when it reads past the
            end and comes back empty. *)
         repo.OpenSequentialRead;
         try
            for i := 0 to High(calls) do
               begin
               CheckTrue(repo.ReadNext(sequential),
                         'the sequential read has a record at position ' + IntToStr(i));

               rowId := repo.RowIdAtIndex(i);
               CheckTrue(rowId > 0, 'index ' + IntToStr(i) + ' names a row');
               CheckTrue(repo.LoadQSO(rowId, byIndex),
                         'and that row loads');

               CheckEquals(string(calls[i]), string(sequential.Callsign),
                           'read in order, position ' + IntToStr(i));
               CheckEquals(string(calls[i]), string(byIndex.Callsign),
                           'addressed by index, position ' + IntToStr(i));
               CheckEquals(i + 1, byIndex.NumberReceived,
                           'and it is the same QSO, not its neighbour');
               end;
         finally
            repo.CloseSequentialRead;
         end;

         (* Off the end returns nothing rather than the last record again --
            the other half of the off-by-one, and the half that turns a wrong
            answer into a silent no-op. *)
         CheckEquals(0, repo.RowIdAtIndex(Length(calls)),
                     'one past the end names no row');
      finally
         repo.Free;
      end;
   finally
      db.Free;
   end;
   Scrub(fn);
end;

procedure TLogRepositoryTests.RunAllTests;
begin
   TestOneQSORoundTrips;
   Test_LegacySkippedIsReadAsDeleted;
   TestSentinelsBecomeNullAndComeBack;
   TestEveryRowGetsItsOwnGuid;
   TestCountyLineQSOsShareAnExchangeId;
   TestSearchAndPounceIsInverted;
   TestKidsFollowsTheRecordKind;
   TestUUIDv7ShapeAndOrdering;
   TestImportingTheSameFileTwiceAddsNothing;
   TestImportUpdatesAnExistingQSO;
   TestImportWithNoGuidAppends;
   TestUpdateReplacesTheRow;
   TestUpdateOfAMissingRowSaysSo;
   TestWholeCorpusLogRoundTrips;
   TestIndexAddressesTheSameRecordAsAReadInOrder;

   if (FDir <> '') and DirectoryExists(FDir) then
      begin
      RemoveDir(FDir);
      end;
end;

end.
