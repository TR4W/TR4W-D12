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
      function BinaryLogFixture(const aSet: string): string;

      (* A METHOD, not a free function: CheckEquals is protected on TTestCase,
        which is the framework saying assertions belong to a test. *)
      procedure CompareQSO(const a, b: ContestExchange; const where: string);
      procedure MakeDistinctQSO(out aQso: ContestExchange; aSeed: integer);
   protected
      procedure TestTheColumnTableAgreesWithQSO_COLUMNS;
      procedure TestAReaderWhoseColumnsDriftedFailsLoudly;
      procedure TestEveryReaderReturnsTheSameRecord;
      procedure TestTheCursorYieldsEachRowsId;
      procedure TestARowIdReaderNeedsTheIdLast;
      procedure TestABatchCommitsByRowId;
      procedure TestAFailedBatchRollsBackWhole;
      procedure TestABatchRefusesWhatWouldBreakIt;
      procedure TestEveryWriteWaitsForItsCommit;
      procedure TestAFreshRepositoryHoldsItsWritesUntilCommit;
      procedure TestABatchSQLiteRollsBackItselfLeavesTheRepositoryUsable;
      procedure TestALogSQLiteRolledBackClosesCleanly;
      procedure TestAnAppendBatchLandsInOneCommit;
      procedure TestAFailedAppendBatchLeavesTheLogAsItWas;
      procedure TestAnAppendBatchWritesRowsAsTheLiveAppendDoes;
      procedure TestAnEditKeepsTheSentExchange;
      procedure TestQSOsWithoutAnExchangeIdAreReported;
      procedure TestTheContestStartTimeIsReadAtOpen;
      procedure TestEveryNowTheLogStoresIsUTC;
      procedure TestTheRepositoryFindsExactlyTheRowsTheServerIsOwed;
      procedure TestMarkingServerProgressWritesTheFlagsAndNothingElse;
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
      procedure TestANoteSurvivesTheLog;
   public
      procedure RunAllTests; override;
   end;

implementation

uses
   uContestRegistry,   (* ContestHandleOf -- a legacy contest's handle, Q108 S2 *)
   (* LCLType for MAXBYTE / MAXWORD -- the not-set markers
     ClearContestExchange writes, and the values this suite exists to prove
     never reach the log.  It was Windows; LCLType declares both and is what
     the rest of the tree now uses for them. *)
   LCLType, SysUtils, Classes, uLogDatabase, uLogSchema, uLogBinaryFile,
   DateUtils,   (* DateTimeToUnix -- the contest row's start_time (Q35) *)
   sqldb,   (* TSQLQuery -- a reader built by hand to drift on purpose *)
   uLogRepository,
   utils_text,   (* CharBufferBytes -- the mapper's own read of ceOperator *)
   uLogNote,   (* NoteText / SetNoteText -- a note's text *)
   uQsoMyFacts,   (* TQsoMyFacts -- the 16th write path, UpdateQSOMyFacts *)
   md5;   (* MD5File -- "the log is byte for byte as it was" *)

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

function TLogRepositoryTests.BinaryLogFixture(const aSet: string): string;
begin
   (* THE D7 BINARY LOGS LIVE HERE, NOT IN THE CORPUS -- 2026-09-24.

     The golden corpus's input is a log.db now, and NY4I scoped what that
     gives up: "Yes I agree it's remnant allow us to validate .Trw
     conversion but that becomes a unit test and not the corpus."  Six of
     the thirteen D7 logs were kept as UNIT fixtures for exactly that, each
     because some assertion here names it; the other seven were deleted and
     are in git history.

     PathDelim, NOT HARDCODED BACKSLASHES. Found by RUNNING on Linux, which
     asked to open one file literally named "..\corpus\<set>\log.trw" and
     reported "No such file or directory". It compiles everywhere; it only
     fails where the separator is not a backslash. *)
   Result := ExtractFilePath(ParamStr(0)) + 'fixtures' + PathDelim +
             'binarylog' + PathDelim + aSet + '.trw';
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
   SameInt('ceContest', a.ceContest.ToByte, b.ceContest.ToByte);

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
   Same('ceOperator', CharBufferBytes(a.ceOperator),
                      CharBufferBytes(b.ceOperator));
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

   reader := TLogBinaryReader.Create(BinaryLogFixture('cqww_ssb_2025_ny4i'));
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
   reader := TLogBinaryReader.Create(BinaryLogFixture('cqww_ssb_2025_ny4i'));
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
               reader := TLogBinaryReader.Create(BinaryLogFixture(SETS[s]));
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

(* WINDOWS-ONLY, AND THAT IS A SCOPE CORRECTION RATHER THAN A RETREAT.

  NY4I, 2026-09-08: "I no longer see the value in us writing the binary log
  file anymore. I think our log should strictly be SQLite... I'm not really
  sure that maintaining anything except the ability to import a binary log for
  people moving from an older one to a newer one on Windows has any value."

  So reading a D7 .TRW is a WINDOWS MIGRATION PATH. Nobody on macOS or Linux
  has one to bring -- those are new platforms -- and a suite that reads one
  there is testing a situation that cannot arise.

  IT WAS ALSO FAILING THERE, FOR A REAL REASON. ContestExchange is a plain
  record and the reader block-reads a file straight into it, so the on-disk
  format is the target's alignment layout: QTH lands at 114 on i386 and
  x86_64, and at 116 on aarch64. Every field from there on decodes wrong --
  measured, the same QSO gives Continent = 1 on Linux and 86 on macOS.

  THAT DEFECT IS NOT FIXED BY THIS GATE, it is SCOPED by it. Windows is where
  import runs, Windows is where it is tested, and
  TestTheRecordHasTheSameFIELD_OFFSETSEverywhere stays as the thing that says
  why if anyone tries to widen it again. *)
(* ===========================================================================
  A NOTE, WRITTEN THE WAY THE PROGRAM WRITES ONE, THROUGH THE LOG.

  THIS TEST FOUND A DATA-LOSS DEFECT, and was written to answer a question
  rather than to pass. A note is not a field: its text runs on from Prefix
  across Callsign and the fields after it. The mapper stored those as
  separate typed columns, and this is what came back:

      wrote      'the rig drifted 200 Hz after the band change'
      read back  Prefix 'he rig', Callsign 'rifted 200 Hz'

  -- the first character of each field consumed as a length, both
  truncated, and everything past byte 22 gone. The text could not be
  recovered from what was stored. The schema had a `notes` column for it
  that nothing bound.

  Now it does, and the record comes back in the layout it was written in.
  If this fails again, a note is being lost on its way into the log. *)
procedure TLogRepositoryTests.TestANoteSurvivesTheLog;
const
   (* Longer than Prefix and Callsign together, as a real note is. *)
   NOTE_TEXT = 'the rig drifted 200 Hz after the band change';
var
   db:      TLogDatabase;
   repo:    TLogRepository;
   reader:  TLogBinaryReader;
   seed, before, after: ContestExchange;
   rowId:   Int64;
   fn:      string;
   got:     boolean;
   s:       ShortString;
   rawText: AnsiString;
begin
   BeginTest('a note written the way the program writes one survives the log');
   fn := TempLogName('note.db');
   Scrub(fn);

   (* The contest comes from a real log, as every other test here takes it. *)
   reader := TLogBinaryReader.Create(BinaryLogFixture('cqww_ssb_2025_ny4i'));
   try
      CheckTrue(reader.Status = lbOK, 'the fixture opens: ' + reader.Message);
      got := reader.ReadNext(seed);
      CheckTrue(got, 'the fixture has a record to take the contest from');
   finally
      reader.Free;
   end;

   (* The way the program writes a note. uTestLogNote proves SetNoteText
     produces the same bytes the old writer did. *)
   s := NOTE_TEXT;
   FillChar(before, SizeOf(ContestExchange), 0);
   before.ceRecordKind := rkNote;
   SetNoteText(before, s);

   db := TLogDatabase.Create;
   try
      db.CreateNew(fn);
      repo := TLogRepository.Create(db);
      try
         repo.SetContest(seed.ceContest);
         rowId := repo.SaveQSO(before);
         repo.Commit;

         CheckTrue(repo.LoadQSO(rowId, after), 'the note reads back');
         CheckTrue(after.ceRecordKind = rkNote, 'it is still a note');

         rawText := NoteText(after);

         CheckEquals(string(NOTE_TEXT), string(rawText),
            'the note''s text is recoverable after the log round trip. ' +
            'NoteText gave [' + string(rawText) + ']; ' +
            'Prefix read as a ShortString gave [' + string(after.Prefix) +
            ']; Callsign gave [' + string(after.Callsign) + ']');
      finally
         repo.Free;
      end;
   finally
      db.Free;
   end;

   Scrub(fn);
end;

(* ===========================================================================
  THE READERS READ BY POSITION NOW -- 2026-10-14. These three pin what makes
  that safe.

  ReadRecord takes column c from Fields[Ord(c)] instead of looking it up by
  name, because the name lookup was most of the cost of every read. A position
  is only right while the SELECT matches QSO_COLUMNS, so the repository checks
  that BY NAME each time a reader opens, and refuses on a mismatch. *)

(* The ordinal table and QSO_COLUMNS are the same list. If this fails, the
  enum in uLogRepository and the column string have drifted -- and no
  repository can be created until they agree. *)
procedure TLogRepositoryTests.TestTheColumnTableAgreesWithQSO_COLUMNS;
begin
   BeginTest('the column table ReadRecord reads by agrees with QSO_COLUMNS');
   CheckEquals('', string(QsoColumnTableProblem),
               'TQsoColumn and QSO_COLUMNS name the same columns in order');
end;

(* THE GUARD FIRES. A reader whose SELECT is QSO_COLUMNS passes; one with two
  columns swapped, one column short or one column extra RAISES -- and says
  which position, so the message points at the drift rather than at a wrong
  value three screens later. *)
procedure TLogRepositoryTests.TestAReaderWhoseColumnsDriftedFailsLoudly;
var
   db: TLogDatabase;
   fn: string;
   list: AnsiString;
   swapped: AnsiString;
   short: AnsiString;

   (* '' when VerifyQsoColumns accepts the SELECT, else what it raised. *)
   function Verdict(const aColumns: AnsiString): string;
   var
      q: TSQLQuery;
   begin
      Result := '';
      q := TSQLQuery.Create(nil);
      try
         q.DataBase := db.Connection;
         q.SQL.Text := 'SELECT ' + aColumns + ' FROM qso';
         q.Open;
         try
            try
               VerifyQsoColumns(q);
            except
               on e: ELogRepositoryError do
                  begin
                  Result := e.Message;
                  if Result = '' then
                     begin
                     Result := '(raised with no message)';
                     end;
                  end;
            end;
         finally
            q.Close;
         end;
      finally
         q.Free;
      end;
   end;

begin
   BeginTest('a qso reader whose columns drifted from QSO_COLUMNS fails loudly');
   fn := TempLogName('columns.db');
   Scrub(fn);

   list := QsoColumnList;
   CheckTrue(Pos(AnsiString('guid, exchange_id, '), list) = 1,
             'the swap below assumes QSO_COLUMNS starts guid, exchange_id');
   swapped := StringReplace(list, 'guid, exchange_id, ', 'exchange_id, guid, ', []);
   short := Copy(list, 1, LastDelimiter(',', list) - 1);

   db := TLogDatabase.Create;
   try
      db.CreateNew(fn);

      CheckEquals('', Verdict(list), 'QSO_COLUMNS itself is accepted');

      CheckTrue(Pos('column 0', Verdict(swapped)) > 0,
                'two columns swapped is refused, naming position 0: ' +
                Verdict(swapped));
      CheckTrue(Verdict(short) <> '',
                'one column short is refused');
      CheckTrue(Verdict(list + ', id') <> '',
                'one column extra is refused');
   finally
      db.Free;
   end;
   Scrub(fn);
end;

(* A QSO WITH A DIFFERENT VALUE IN AS MANY COLUMNS AS THE RECORD ALLOWS -- so a
  column read from the wrong position shows up as a wrong field, not as two
  zeros that happen to agree. The flags alternate with the seed for the same
  reason: corpus data is almost all False, and two False flags swapped look
  correct. *)
procedure TLogRepositoryTests.MakeDistinctQSO(out aQso: ContestExchange;
                                              aSeed: integer);
begin
   (* ContestExchange holds ShortStrings and scalars only, so clearing it
     whole is safe; the reader does the same. *)
   FillChar(aQso, SizeOf(aQso), 0);
   aQso.ceRecordKind := rkQSO;
   aQso.ceContest := NoContest;
   aQso.id := 'exchange' + IntToStr(aSeed);
   aQso.ceQSOID1 := 1000 + aSeed;
   aQso.ceQSOID2 := 2000 + aSeed;
   aQso.ceComputerID := 'B';
   aQso.ceOperatorID := 7 + aSeed;

   aQso.tSysTime.qtYear := 26;
   aQso.tSysTime.qtMonth := 6;
   aQso.tSysTime.qtDay := 1 + aSeed;
   aQso.tSysTime.qtHour := 12;
   aQso.tSysTime.qtMinute := 30 + aSeed;
   aQso.tSysTime.qtSecond := 15 + aSeed;
   aQso.Callsign := 'K' + IntToStr(aSeed) + 'ABC';
   aQso.QTH.StandardCall := 'K' + IntToStr(aSeed) + 'ABC';
   aQso.Frequency := 14025000 + aSeed;
   aQso.Band := Band20;
   aQso.Mode := CW;
   aQso.ExtMode := eCW;
   aQso.ExchString := '599 0' + IntToStr(aSeed);

   aQso.RSTSent := 599;
   aQso.RSTReceived := 579;
   aQso.NumberSent := 11 + aSeed;
   aQso.NumberReceived := 22 + aSeed;
   aQso.Zone := 5;
   aQso.Name := 'TOM';
   aQso.Age := 42;
   aQso.Check := 72;
   aQso.Precedence := 'A';
   aQso.ceClass := '2A';
   aQso.Power := '100';
   aQso.Chapter := '12';
   aQso.Prefecture := 13;
   aQso.TenTenNum := 1234;
   aQso.QTHString := 'FN42';
   aQso.RandomCharsReceived := 'XYZ';
   aQso.RandomCharsSent := 'ABC';
   aQso.Kids := 'KID';
   aQso.DomesticQTH := 'FL';

   aQso.QTH.Prefix := 'K';
   aQso.QTH.CountryID := 'K';
   aQso.QTH.Country := 291;
   aQso.QTH.Zone := 4;
   aQso.QTH.Continent := NorthAmerica;

   aQso.Prefix := 'K4';
   aQso.DXQTH := 'W';
   aQso.DomMultQTH := 'GA';
   aQso.DomesticMult := Odd(aSeed);
   aQso.DXMult := not Odd(aSeed);
   aQso.PrefixMult := Odd(aSeed);
   aQso.ZoneMult := not Odd(aSeed);
   aQso.InhibitMults := Odd(aSeed);

   aQso.QSOPoints := 3 + aSeed;
   aQso.ceDupe := not Odd(aSeed);
   aQso.ceSearchAndPounce := Odd(aSeed);
   aQso.ceXQSO := not Odd(aSeed);
   aQso.ceWasSendInQTC := Odd(aSeed);
   aQso.NameSent := not Odd(aSeed);
   aQso.MP3Record := Odd(aSeed);
   aQso.ceClearDupeSheet := not Odd(aSeed);
   aQso.ceClearMultSheet := Odd(aSeed);
   aQso.ceRadio := RadioTwo;
   AnsiToCharArray(aQso.ceOperator, 'NY4I');
   aQso.ceQSO_Deleted := not Odd(aSeed);
   aQso.ceSendToServer := Odd(aSeed);
   aQso.ceNeedSendToServerAE := not Odd(aSeed);
end;

(* EVERY READER, THE SAME RECORD. There are four ways to read a qso row --
  by id, by guid, a range, and the sequential cursor -- and each one opens
  through the column check. So each must come back field-for-field equal to
  what was written; a reader that drifted would raise first. *)
procedure TLogRepositoryTests.TestEveryReaderReturnsTheSameRecord;
const
   ROWS = 2;
var
   db: TLogDatabase;
   repo: TLogRepository;
   written: array[0..ROWS - 1] of ContestExchange;
   back: ContestExchange;
   ranged: array[0..ROWS - 1] of ContestExchange;
   rowIds: array[0..ROWS - 1] of Int64;
   guids: array[0..ROWS - 1] of AnsiString;
   fn: string;
   i: integer;
begin
   BeginTest('every qso reader returns the record that was written');
   fn := TempLogName('readers.db');
   Scrub(fn);

   db := TLogDatabase.Create;
   try
      db.CreateNew(fn);
      repo := TLogRepository.Create(db);
      try
         for i := 0 to ROWS - 1 do
            begin
            MakeDistinctQSO(written[i], i);
            rowIds[i] := repo.SaveQSO(written[i]);
            guids[i] := repo.LastGuid;
            end;
         repo.Commit;

         for i := 0 to ROWS - 1 do
            begin
            CheckTrue(repo.LoadQSO(rowIds[i], back), 'LoadQSO reads row ' + IntToStr(i));
            CompareQSO(written[i], back, 'LoadQSO #' + IntToStr(i));

            CheckTrue(repo.LoadQSOByGuid(guids[i], back),
                      'LoadQSOByGuid reads row ' + IntToStr(i));
            CompareQSO(written[i], back, 'LoadQSOByGuid #' + IntToStr(i));
            end;

         CheckEquals(ROWS, repo.ReadRange(0, ranged), 'ReadRange reads every row');
         for i := 0 to ROWS - 1 do
            begin
            CompareQSO(written[i], ranged[i], 'ReadRange #' + IntToStr(i));
            end;

         repo.OpenSequentialRead;
         try
            for i := 0 to ROWS - 1 do
               begin
               CheckTrue(repo.ReadNext(back), 'ReadNext reads row ' + IntToStr(i));
               CompareQSO(written[i], back, 'ReadNext #' + IntToStr(i));
               end;
            CheckFalse(repo.ReadNext(back), 'and then the cursor is at the end');
         finally
            repo.CloseSequentialRead;
         end;

         (* RowIdAtIndex holds ONE prepared statement now, re-opened per call.
           Asked twice and out of order, it still answers each index. *)
         CheckEquals(integer(rowIds[1]), integer(repo.RowIdAtIndex(1)), 'index 1');
         CheckEquals(integer(rowIds[0]), integer(repo.RowIdAtIndex(0)), 'index 0');
         CheckEquals(integer(rowIds[1]), integer(repo.RowIdAtIndex(1)), 'index 1 again');
         CheckEquals(0, integer(repo.RowIdAtIndex(ROWS)), 'past the end');
      finally
         repo.Free;
      end;
   finally
      db.Free;
   end;
   Scrub(fn);
end;

(* THE CURSOR'S ROW ID IS THE ROW IT READ. The rescore writes back by that id,
  so a cursor that paired a record with the wrong id -- or with 0 -- would
  rewrite the wrong QSO, or none. Three rows, so a constant answer cannot
  pass; and ReadNext, which now reads through the same routine, still returns
  the same records without the id. *)
procedure TLogRepositoryTests.TestTheCursorYieldsEachRowsId;
const
   ROWS = 3;
var
   db: TLogDatabase;
   repo: TLogRepository;
   written: array[0..ROWS - 1] of ContestExchange;
   rowIds: array[0..ROWS - 1] of Int64;
   back: ContestExchange;
   rowId: Int64;
   fn: string;
   i: integer;
begin
   BeginTest('the sequential cursor yields each record with its own row id');
   fn := TempLogName('cursorids.db');
   Scrub(fn);

   db := TLogDatabase.Create;
   try
      db.CreateNew(fn);
      repo := TLogRepository.Create(db);
      try
         for i := 0 to ROWS - 1 do
            begin
            MakeDistinctQSO(written[i], i);
            rowIds[i] := repo.SaveQSO(written[i]);
            end;
         repo.Commit;
         CheckTrue((rowIds[0] <> rowIds[1]) and (rowIds[1] <> rowIds[2]),
                   'three distinct row ids to tell apart');

         repo.OpenSequentialRead;
         try
            for i := 0 to ROWS - 1 do
               begin
               CheckTrue(repo.ReadNextWithRowId(rowId, back),
                         'ReadNextWithRowId reads row ' + IntToStr(i));
               CheckEquals(integer(rowIds[i]), integer(rowId),
                           'and names the row it read, #' + IntToStr(i));
               CompareQSO(written[i], back, 'ReadNextWithRowId #' + IntToStr(i));
               end;
            CheckFalse(repo.ReadNextWithRowId(rowId, back), 'then the end');
            CheckEquals(0, integer(rowId), 'with no row id at the end');
         finally
            repo.CloseSequentialRead;
         end;

         repo.OpenSequentialRead;
         try
            for i := 0 to ROWS - 1 do
               begin
               CheckTrue(repo.ReadNext(back), 'ReadNext reads row ' + IntToStr(i));
               CompareQSO(written[i], back, 'ReadNext beside the id #' + IntToStr(i));
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
   Scrub(fn);
end;

(* A READER THAT ALSO SELECTS THE ROW ID takes it AFTER QSO_COLUMNS, and the
  guard checks that position by name too. Without the trailing id, with
  another column there, or with the id moved to the front, it refuses. *)
procedure TLogRepositoryTests.TestARowIdReaderNeedsTheIdLast;
var
   db: TLogDatabase;
   fn: string;
   list: AnsiString;

   function Verdict(const aColumns: AnsiString): string;
   var
      q: TSQLQuery;
   begin
      Result := '';
      q := TSQLQuery.Create(nil);
      try
         q.DataBase := db.Connection;
         q.SQL.Text := 'SELECT ' + aColumns + ' FROM qso';
         q.Open;
         try
            try
               VerifyQsoColumns(q, True);
            except
               on e: ELogRepositoryError do
                  begin
                  Result := e.Message;
                  if Result = '' then
                     begin
                     Result := '(raised with no message)';
                     end;
                  end;
            end;
         finally
            q.Close;
         end;
      finally
         q.Free;
      end;
   end;

begin
   BeginTest('a reader that selects the row id must have it after QSO_COLUMNS');
   fn := TempLogName('rowidcolumns.db');
   Scrub(fn);
   list := QsoColumnList;

   db := TLogDatabase.Create;
   try
      db.CreateNew(fn);
      CheckEquals('', Verdict(list + ', id'), 'QSO_COLUMNS then id is accepted');
      CheckTrue(Verdict(list) <> '', 'without the id it is refused');
      CheckTrue(Pos('row id', Verdict(list + ', guid')) > 0,
                'another column in its place is refused, naming the row id: ' +
                Verdict(list + ', guid'));
      CheckTrue(Verdict('id, ' + list) <> '',
                'the id in front, which shifts every column, is refused');
   finally
      db.Free;
   end;
   Scrub(fn);
end;

(* A BATCH WRITES BY ROW ID AND COMMITS -- durably. Two of three rows are
  rewritten through WriteBatch, then the database is CLOSED AND REOPENED, so
  what is checked is what reached the file and not what one connection can
  see of its own transaction. The third row, not in the batch, is unchanged. *)
procedure TLogRepositoryTests.TestABatchCommitsByRowId;
const
   ROWS = 3;
var
   db: TLogDatabase;
   repo: TLogRepository;
   updates: TLogRowUpdates;
   written: array[0..ROWS - 1] of ContestExchange;
   edited: array[0..ROWS - 1] of ContestExchange;
   rowIds: array[0..ROWS - 1] of Int64;
   back: ContestExchange;
   fn: string;
   i: integer;
begin
   BeginTest('a batch rewrites rows by row id and commits them');
   fn := TempLogName('batchcommit.db');
   Scrub(fn);

   db := TLogDatabase.Create;
   try
      db.CreateNew(fn);
      repo := TLogRepository.Create(db);
      try
         for i := 0 to ROWS - 1 do
            begin
            MakeDistinctQSO(written[i], i);
            rowIds[i] := repo.SaveQSO(written[i]);
            edited[i] := written[i];
            end;
         repo.Commit;

         (* Rows 0 and 2, LAST FIRST, so a write that went by position in the
           list rather than by row id would land on the wrong row. *)
         edited[0].QSOPoints := 77;
         edited[0].id := 'minted0';
         edited[2].QSOPoints := 99;
         edited[2].ceDupe := not written[2].ceDupe;

         updates := TLogRowUpdates.Create;
         try
            updates.Add(rowIds[2], edited[2]);
            updates.Add(rowIds[0], edited[0]);
            CheckEquals(2, updates.Count, 'two rows collected');
            CheckEquals(integer(rowIds[2]), integer(updates.RowId(0)),
                        'held in the order added');
            repo.WriteBatch(updates);
         finally
            updates.Free;
         end;
         CheckFalse(repo.InBatch, 'the batch is closed after it commits');
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
         CheckTrue(repo.LoadQSO(rowIds[0], back), 'row 0 reads back after reopening');
         CompareQSO(edited[0], back, 'batched row 0');
         CheckTrue(repo.LoadQSO(rowIds[1], back), 'row 1 reads back');
         CompareQSO(written[1], back, 'row 1, not in the batch, unchanged');
         CheckTrue(repo.LoadQSO(rowIds[2], back), 'row 2 reads back');
         CompareQSO(edited[2], back, 'batched row 2');
         CheckEquals(ROWS, integer(repo.RecordCount), 'and no row was added');
      finally
         repo.Free;
      end;
   finally
      db.Free;
   end;
   Scrub(fn);
end;

(* A BATCH THAT FAILS PART-WAY LEAVES NOTHING OF ITSELF.

  The fault is injected the way it would arrive: the second row of the batch
  does not exist. The first row's UPDATE has already run by then, inside the
  transaction, so this is the case the rollback exists for. Checked after a
  reopen, so it is the FILE that is unchanged.

  It also pins the boundary: a write left UNCOMMITTED before the batch began
  is committed BY BeginBatchUpdate, so it survives the rollback -- the
  rollback undoes the batch and nothing before it.

  THAT WRITE IS A SESSION VALUE, NOT A QSO, and when this was written it had
  to be. sqldb starts a transaction only when a statement PREPARES
  (sqldb.pp:1296), and SaveQSO's FInsert stays prepared, so after a commit it
  executed in SQLite's autocommit and was durable at once -- measured: a QSO
  "saved and not committed" here survived a ROLLBACK of the adopted
  transaction. Section 9c's audit fixed that for every kept write
  (ExecuteKeptWrite, pinned by TestEveryWriteWaitsForItsCommit); the session
  value stays, since it was always a fair test of the boundary. *)
procedure TLogRepositoryTests.TestAFailedBatchRollsBackWhole;
var
   db: TLogDatabase;
   repo: TLogRepository;
   updates: TLogRowUpdates;
   first, edited, back: ContestExchange;
   firstId: Int64;
   raised: boolean;
   fn: string;
begin
   BeginTest('a batch that fails part-way is rolled back whole');
   fn := TempLogName('batchrollback.db');
   Scrub(fn);

   db := TLogDatabase.Create;
   try
      db.CreateNew(fn);
      repo := TLogRepository.Create(db);
      try
         MakeDistinctQSO(first, 1);
         firstId := repo.SaveQSO(first);
         repo.Commit;

         (* Written and deliberately NOT committed. *)
         repo.SaveSessionValue('pinBeforeBatch', 'kept');
         CheckTrue(db.Transaction.Active,
                   'the session write is waiting in an open transaction');

         edited := first;
         edited.QSOPoints := 55;
         edited.Callsign := 'CHANGED';

         updates := TLogRowUpdates.Create;
         try
            updates.Add(firstId, edited);
            updates.Add(firstId + 1000, edited);
            raised := False;
            try
               repo.WriteBatch(updates);
            except
               on e: ELogRepositoryError do
                  begin
                  raised := True;
                  CheckTrue(Pos('no qso row', e.Message) > 0,
                            'it names the missing row: ' + e.Message);
                  end;
            end;
            CheckTrue(raised, 'a batch naming a missing row raises');
         finally
            updates.Free;
         end;
         CheckFalse(repo.InBatch, 'and the batch is closed by the rollback');

         CheckTrue(repo.LoadQSO(firstId, back), 'the first row still reads');
         CompareQSO(first, back, 'the first row, as seen by the same connection');

         (* AND THE NEXT BATCH WORKS: a failed one does not wedge the
           repository. *)
         updates := TLogRowUpdates.Create;
         try
            edited.Callsign := 'LATER';
            updates.Add(firstId, edited);
            repo.WriteBatch(updates);
         finally
            updates.Free;
         end;
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
         CheckEquals('kept', string(repo.SessionValue('pinBeforeBatch', 'lost')),
                     'the write made before the batch survived its rollback');
         CheckTrue(repo.LoadQSO(firstId, back), 'the first row reads after reopening');
         CheckEquals('LATER', string(back.Callsign),
                     'carrying the later batch and not the failed one');
         CheckEquals(55, integer(back.QSOPoints),
                     'whose points the later batch also wrote');
      finally
         repo.Free;
      end;
   finally
      db.Free;
   end;
   Scrub(fn);
end;

(* THE THREE MISUSES THAT WOULD BREAK A BATCH ARE REFUSED, LOUDLY:
  beginning while the sequential cursor is open (the commit would close it
  under its reader), beginning a second batch inside the first, and writing
  a batch row with no batch open. *)
procedure TLogRepositoryTests.TestABatchRefusesWhatWouldBreakIt;
var
   db: TLogDatabase;
   repo: TLogRepository;
   qso: ContestExchange;
   rowId: Int64;
   fn: string;

   function Raises(aStep: integer): boolean;
   begin
      Result := False;
      try
         case aStep of
            0:
               begin
               repo.BeginBatchUpdate;
               end;
            1:
               begin
               repo.UpdateQSOByRowId(rowId, qso);
               end;
         end;
      except
         on ELogRepositoryError do
            begin
            Result := True;
            end;
      end;
   end;

begin
   BeginTest('a batch refuses to begin over a cursor, to nest, or to run unopened');
   fn := TempLogName('batchmisuse.db');
   Scrub(fn);

   db := TLogDatabase.Create;
   try
      db.CreateNew(fn);
      repo := TLogRepository.Create(db);
      try
         MakeDistinctQSO(qso, 0);
         rowId := repo.SaveQSO(qso);
         repo.Commit;

         CheckTrue(Raises(1), 'a batch row with no batch open is refused');

         repo.OpenSequentialRead;
         try
            CheckTrue(Raises(0), 'beginning while the cursor is open is refused');
            CheckFalse(repo.InBatch, 'and no batch was begun');
            CheckTrue(repo.ReadNext(qso), 'and the cursor still reads');
         finally
            repo.CloseSequentialRead;
         end;

         repo.BeginBatchUpdate;
         try
            CheckTrue(Raises(0), 'a second batch inside the first is refused');
            CheckTrue(repo.InBatch, 'and the first is still open');
         finally
            repo.RollbackBatch;
         end;
         CheckFalse(repo.InBatch, 'until it is rolled back');
      finally
         repo.Free;
      end;
   finally
      db.Free;
   end;
   Scrub(fn);
end;

(* WHAT THE FILE HOLDS, AS ONE STRING -- every table a write path touches:
  the QSOs (callsign and points, in id order), the contest row, the config
  rows, the session rows and the messages.

  Read through the connection handed in, which sees its own uncommitted
  writes. That is how a test proves a write HAPPENED before it proves the
  write did not survive -- a pin that cannot tell "rolled back" from "never
  written" proves nothing. *)
function DatabaseFingerprint(aDatabase: TLogDatabase): string;
var
   q: TSQLQuery;
   i: integer;
begin
   Result := '';
   q := TSQLQuery.Create(nil);
   try
      q.DataBase := aDatabase.Connection;
      q.UsePrimaryKeyAsKey := False;
      q.SQL.Text :=
         'SELECT (SELECT COUNT(*) FROM qso), ' +
         '(SELECT group_concat(c, '','') FROM (SELECT callsign || '':'' || ' +
         'IFNULL(qso_points, '''') || '':'' || IFNULL(exchange_sent, '''') ' +
         '|| '':'' || IFNULL(my_grid, '''') || '':'' || IFNULL(my_source, '''') ' +
         '|| '':'' || IFNULL(sent_to_server, '''') || '':'' || ' +
         'IFNULL(server_dirty, '''') AS c FROM qso ORDER BY id)), ' +
         '(SELECT contest_type || '':'' || my_call FROM contest WHERE id = 1), ' +
         '(SELECT group_concat(c, '','') FROM (SELECT command || ''='' || ' +
         'value AS c FROM config ORDER BY command)), ' +
         '(SELECT group_concat(c, '','') FROM (SELECT key || ''='' || value ' +
         'AS c FROM session_state ORDER BY key)), ' +
         '(SELECT group_concat(text, '','') FROM (SELECT text FROM message ' +
         'ORDER BY kind, mode, key_id))';
      q.Open;
      for i := 0 to q.FieldCount - 1 do
         begin
         Result := Result + '|' + q.Fields[i].AsString;
         end;
      q.Close;
   finally
      q.Free;
   end;
end;

(* EVERY WRITE THE REPOSITORY OFFERS WAITS FOR ITS CALLER'S COMMIT.

  The contract is stated on SaveQSO -- "Does NOT commit; the caller decides
  the batch" -- and every caller is written to it: a write, then Commit, and
  on failure no Commit, so the close rolls the write back. For that to be
  true the write has to be INSIDE a transaction when it runs.

  sqldb begins one only when a statement PREPARES (sqldb.pp:1296). The
  statements made per call (config, session, messages, the contest row)
  prepare every time, so they always begin one. FInsert and FUpdate are
  prepared ONCE and kept, so after any Commit they ran in SQLite's
  AUTOCOMMIT: each one durable the moment it executed, whatever the caller
  then did. Measured 2026-10-14 by this test before the fix: SaveQSO,
  UpdateQSO, ImportQSOByGuid with no guid, and both sequences below survived
  a close with no commit.

  EACH STEP: a seeded log is committed, so no transaction is open; one write
  path runs; the fingerprint proves it changed something; the repository
  and database are freed WITHOUT a commit -- Close rolls back what is open,
  which is what SQLite does at the next open with a transaction a crash left
  in the -wal -- and the reopened file must match the seed exactly. *)
procedure TLogRepositoryTests.TestEveryWriteWaitsForItsCommit;
const
   STEPS = 17;
   NAMES: array[0..STEPS - 1] of string = (
      'SaveQSO',
      'UpdateQSO',
      'ImportQSOByGuid with no guid',
      'ImportQSOByGuid with a new guid',
      'ImportQSOByGuid with an existing guid',
      'UpdateQSOBySessionIds',
      'SetContest',
      'SetEntryDeclaration',
      'SaveConfigValue',
      'DeleteConfigValue',
      'SaveSessionValue',
      'SaveMessage',
      'DeleteAllQSOs',
      'two SaveQSOs in a row',
      'UpdateQSO and then SaveConfigValue',
      'UpdateQSOMyFacts',
      'MarkServerProgress');
var
   db: TLogDatabase;
   repo: TLogRepository;
   seed, other, changed: ContestExchange;
   marks: TQsoSessionKeys;
   seedId: Int64;
   seedGuid: AnsiString;
   seedPrint, written: string;
   decl: TLogEntryDeclaration;
   facts: TQsoMyFacts;
   wasNew: boolean;
   fn: string;
   step: integer;
begin
   BeginTest('every repository write waits for its caller''s commit');
   for step := 0 to STEPS - 1 do
      begin
      fn := TempLogName('waits' + IntToStr(step) + '.db');
      Scrub(fn);

      db := TLogDatabase.Create;
      try
         db.CreateNew(fn);
         repo := TLogRepository.Create(db);
         try
            MakeDistinctQSO(seed, 0);
            seedId := repo.SaveQSO(seed);
            seedGuid := repo.LastGuid;
            repo.SetContest(ContestHandleOf(CQWWCW));
            repo.SaveConfigValue('SEED COMMAND', 'seed', 'contest');
            repo.SaveSessionValue('seed', 'seed');
            repo.SaveMessage('CQ', 'CW', 'F1', 'seed', '');
            repo.Commit;
            seedPrint := DatabaseFingerprint(db);

            (* The fingerprint's own read began a transaction. Ended, so the
              write below starts exactly where a caller's Commit leaves it. *)
            repo.Commit;
            CheckFalse(db.Transaction.Active,
                       NAMES[step] + ': no transaction is open before the write');

            MakeDistinctQSO(other, 1);
            changed := seed;
            changed.Callsign := 'CHANGED';
            changed.QSOPoints := 42;

            case step of
               0:
                  begin
                  repo.SaveQSO(other);
                  end;
               1:
                  begin
                  repo.UpdateQSO(seedId, changed);
                  end;
               2:
                  begin
                  repo.ImportQSOByGuid('', other, wasNew);
                  end;
               3:
                  begin
                  repo.ImportQSOByGuid('018f3a2b7c1d7abc8def0000000000aa', other,
                                       wasNew);
                  end;
               4:
                  begin
                  repo.ImportQSOByGuid(seedGuid, changed, wasNew);
                  end;
               5:
                  begin
                  repo.UpdateQSOBySessionIds(seed.ceQSOID1, seed.ceQSOID2,
                                             changed);
                  end;
               6:
                  begin
                  repo.SetContest(ContestHandleOf(CQWWSSB));
                  end;
               7:
                  begin
                  decl.MyCall := 'CHANGED';
                  repo.SetEntryDeclaration(decl);
                  end;
               8:
                  begin
                  repo.SaveConfigValue('SEED COMMAND', 'changed', 'contest');
                  end;
               9:
                  begin
                  repo.DeleteConfigValue('SEED COMMAND');
                  end;
               10:
                  begin
                  repo.SaveSessionValue('seed', 'changed');
                  end;
               11:
                  begin
                  repo.SaveMessage('CQ', 'CW', 'F1', 'changed', '');
                  end;
               12:
                  begin
                  repo.DeleteAllQSOs;
                  end;
               13:
                  begin
                  repo.SaveQSO(other);
                  MakeDistinctQSO(other, 2);
                  repo.SaveQSO(other);
                  end;
               14:
                  begin
                  repo.UpdateQSO(seedId, changed);
                  repo.SaveConfigValue('SEED COMMAND', 'changed', 'contest');
                  end;
               15:
                  begin
                  facts := NotCapturedMyFacts;
                  facts.Source := mfsEdited;
                  facts.Grid := 'FN31PR';
                  repo.UpdateQSOMyFacts(seedId, facts);
                  end;
               16:
                  begin
                  (* The seed is unsent and dirty (MakeDistinctQSO's seed 0),
                    so both flags have something to change. *)
                  SetLength(marks, 1);
                  marks[0].SessionId := seed.ceQSOID1;
                  marks[0].SessionSeq := seed.ceQSOID2;
                  repo.MarkServerProgress(marks, marks);
                  end;
            end;

            written := DatabaseFingerprint(db);
            CheckTrue(written <> seedPrint,
                      NAMES[step] + ': the write happened, as this connection sees it');
            (* NO COMMIT. *)
         finally
            repo.Free;
         end;
      finally
         db.Free;
      end;

      db := TLogDatabase.Create;
      try
         db.Open(fn);
         CheckEquals(seedPrint, DatabaseFingerprint(db),
                     NAMES[step] + ': nothing of it survives a close with no commit');
      finally
         db.Free;
      end;
      Scrub(fn);
      end;
end;

(* A NEW LOG'S FIRST TRANSACTION IS OPEN FROM THE MOMENT ITS REPOSITORY
  EXISTS -- the shape ImportBinaryLog relies on for "one transaction for the
  whole import": CreateNew, a repository, SetContest from the first record,
  every record saved grouped, and ONE Commit at the end.

  So a migration that dies before that Commit leaves no QSO and no contest
  row. It does still leave the FILE, which CreateNew made and committed --
  and since 2026-10-14 that file is the import's STAGED name, renamed to the
  log only after the Commit and the close (docs/SQLITE_LOG_SCHEMA_PLAN.md
  section 9c; pinned in uTestLogImport). *)
procedure TLogRepositoryTests.TestAFreshRepositoryHoldsItsWritesUntilCommit;
var
   db: TLogDatabase;
   repo: TLogRepository;
   qso: ContestExchange;
   fn: string;
   i: integer;
begin
   BeginTest('a new log holds an import''s writes until the one commit');
   fn := TempLogName('importshape.db');
   Scrub(fn);

   db := TLogDatabase.Create;
   try
      db.CreateNew(fn);
      repo := TLogRepository.Create(db);
      try
         repo.SetContest(ContestHandleOf(CQWWCW));
         for i := 0 to 2 do
            begin
            MakeDistinctQSO(qso, i);
            repo.SaveQSOGroupingByExchangeId(qso);
            end;
         CheckEquals(3, integer(repo.RecordCount),
                     'three rows, as the importing connection sees them');
         (* NO COMMIT: the import died here. *)
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
         CheckEquals(0, integer(repo.RecordCount), 'no QSO survives');
         CheckTrue(repo.LogContest = NoContest, 'and no contest row');
      finally
         repo.Free;
      end;
   finally
      db.Free;
   end;
   Scrub(fn);
end;

(* SQLITE CAN END A TRANSACTION BY ITSELF, AND A BATCH MUST SURVIVE IT.

  On SQLITE_FULL, SQLITE_IOERR, SQLITE_NOMEM or SQLITE_BUSY "the transaction
  may or may not be rolled back automatically" (sqlite.org/lang_transaction).
  When it is, sqldb does not know: it still holds its transaction Active, and
  the ROLLBACK RollbackBatch then issues fails with "no transaction is
  active".

  The fault is injected with a trigger whose RAISE(ROLLBACK) does exactly
  that to the second row of a batch, after the first row's UPDATE ran. The
  log must be unchanged after a reopen, the repository must not be left
  believing a batch is open, and the next batch must commit durably. *)
procedure TLogRepositoryTests.TestABatchSQLiteRollsBackItselfLeavesTheRepositoryUsable;
var
   db: TLogDatabase;
   repo: TLogRepository;
   updates: TLogRowUpdates;
   a, b, edited, back: ContestExchange;
   idA, idB: Int64;
   raised: boolean;
   fn: string;
begin
   BeginTest('a batch SQLite rolls back by itself leaves the log and repository whole');
   fn := TempLogName('autorollback.db');
   Scrub(fn);

   db := TLogDatabase.Create;
   try
      db.CreateNew(fn);
      repo := TLogRepository.Create(db);
      try
         MakeDistinctQSO(a, 1);
         MakeDistinctQSO(b, 2);
         idA := repo.SaveQSO(a);
         idB := repo.SaveQSO(b);
         db.Connection.ExecuteDirect(
            'CREATE TRIGGER inject_rollback AFTER UPDATE ON qso ' +
            'WHEN NEW.callsign = ''BOOM'' ' +
            'BEGIN SELECT RAISE(ROLLBACK, ''injected failure''); END');
         repo.Commit;

         (* A NEW REPOSITORY, so its statements are prepared against the
           schema WITH the trigger. The one prepared before it answers
           "database schema has changed", which is a different failure. *)
         repo.Free;
         repo := TLogRepository.Create(db);

         updates := TLogRowUpdates.Create;
         try
            edited := a;
            edited.Callsign := 'CHANGED';
            updates.Add(idA, edited);
            edited := b;
            edited.Callsign := 'BOOM';
            updates.Add(idB, edited);
            raised := False;
            try
               repo.WriteBatch(updates);
            except
               on e: Exception do
                  begin
                  raised := True;
                  CheckTrue(Pos('injected failure', e.Message) > 0,
                            'the failure reported is the one that happened: ' +
                            e.Message);
                  end;
            end;
            CheckTrue(raised, 'the batch raises');
         finally
            updates.Free;
         end;
         CheckFalse(repo.InBatch, 'and the repository is not left inside a batch');
         CheckFalse(db.Transaction.Active,
                    'nor is sqldb left holding a transaction SQLite has ended');

         updates := TLogRowUpdates.Create;
         try
            edited := a;
            edited.Callsign := 'LATER';
            updates.Add(idA, edited);
            raised := False;
            try
               repo.WriteBatch(updates);
            except
               on e: Exception do
                  begin
                  raised := True;
                  CheckTrue(False, 'the next batch raised: ' + e.Message);
                  end;
            end;
            CheckFalse(raised, 'the next batch commits');
         finally
            updates.Free;
         end;
      finally
         repo.Free;
      end;
   finally
      (* Close rolls back what is open; with sqldb out of step that ROLLBACK
        raises too, and must not take the suite down with it. *)
      try
         db.Free;
      except
         on e: Exception do
            begin
            CheckTrue(False, 'closing the log raised: ' + e.Message);
            end;
      end;
   end;

   db := TLogDatabase.Create;
   try
      db.Open(fn);
      repo := TLogRepository.Create(db);
      try
         CheckTrue(repo.LoadQSO(idA, back), 'row A reads after reopening');
         CheckEquals('LATER', string(back.Callsign),
                     'carrying the later batch, durably');
         CheckTrue(repo.LoadQSO(idB, back), 'row B reads after reopening');
         CheckEquals(string(b.Callsign), string(back.Callsign),
                     'and row B is as it was');
      finally
         repo.Free;
      end;
   finally
      db.Free;
   end;
   Scrub(fn);
end;

(* AND OUTSIDE A BATCH, THE CLOSE MUST STILL WORK. This is the QSO append's
  shape: one SaveQSO that SQLite answers by rolling the transaction back
  itself, then the store disabling -- which frees the database. That close
  rolled back through sqldb, whose ROLLBACK failed with "no transaction is
  active" and raised out of the handler meant to report the first failure. *)
procedure TLogRepositoryTests.TestALogSQLiteRolledBackClosesCleanly;
var
   db: TLogDatabase;
   repo: TLogRepository;
   a, b: ContestExchange;
   raised: boolean;
   fn: string;
begin
   BeginTest('a log whose transaction SQLite rolled back still closes cleanly');
   fn := TempLogName('autorollbackclose.db');
   Scrub(fn);

   db := TLogDatabase.Create;
   try
      db.CreateNew(fn);
      repo := TLogRepository.Create(db);
      try
         MakeDistinctQSO(a, 1);
         repo.SaveQSO(a);
         db.Connection.ExecuteDirect(
            'CREATE TRIGGER inject_rollback AFTER INSERT ON qso ' +
            'WHEN NEW.callsign = ''BOOM'' ' +
            'BEGIN SELECT RAISE(ROLLBACK, ''injected failure''); END');
         repo.Commit;
         (* Prepared again, against the schema with the trigger. *)
         repo.Free;
         repo := TLogRepository.Create(db);

         MakeDistinctQSO(b, 2);
         b.Callsign := 'BOOM';
         raised := False;
         try
            repo.SaveQSO(b);
         except
            on e: Exception do
               begin
               raised := True;
               CheckTrue(Pos('injected failure', e.Message) > 0,
                         'the append reports what happened: ' + e.Message);
               end;
         end;
         CheckTrue(raised, 'the append raises');
      finally
         repo.Free;
      end;
   finally
      raised := False;
      try
         db.Free;
      except
         on e: Exception do
            begin
            raised := True;
            CheckTrue(False, 'closing the log raised: ' + e.Message);
            end;
      end;
      CheckFalse(raised, 'the log closes without raising');
   end;

   db := TLogDatabase.Create;
   try
      db.Open(fn);
      repo := TLogRepository.Create(db);
      try
         CheckEquals(1, integer(repo.RecordCount),
                     'the committed QSO is there and the failed one is not');
      finally
         repo.Free;
      end;
   finally
      db.Free;
   end;
   Scrub(fn);
end;

(* The live append's sent exchange, as a test can state it: AppendBatch takes
  a plain function, and uLogStore passes BuildSentExchangeText's. *)
function SentExchangeForTest(const aQso: ContestExchange): AnsiString;
begin
   Result := AnsiString('599 ') + AnsiString(aQso.Callsign);
end;

(* AN APPEND BATCH IS ONE COMMIT, AND THAT COMMIT IS DURABLE.

  The ADIF import's write (NY4I, 2026-10-14: all or nothing). Every row is
  in when AppendBatch returns, no transaction is left open behind it, and the
  rows survive a close with no further commit -- which is what a crash right
  after the import leaves. TestAFailedAppendBatchLeavesTheLogAsItWas is the
  other half: a failure at the third row leaves NONE of the first two, which
  is only true if nothing committed before the end. *)
procedure TLogRepositoryTests.TestAnAppendBatchLandsInOneCommit;
var
   db: TLogDatabase;
   repo: TLogRepository;
   appends: TLogQsoAppends;
   seed, qso: ContestExchange;
   failedAt: integer;
   fn: string;
   i: integer;
begin
   BeginTest('an append batch lands every row in one durable commit');
   fn := TempLogName('appendbatch.db');
   Scrub(fn);

   db := TLogDatabase.Create;
   try
      db.CreateNew(fn);
      repo := TLogRepository.Create(db);
      try
         MakeDistinctQSO(seed, 0);
         repo.SaveQSO(seed);
         repo.Commit;

         appends := TLogQsoAppends.Create;
         try
            for i := 1 to 5 do
               begin
               MakeDistinctQSO(qso, i);
               appends.Add(qso);
               end;
            repo.AppendBatch(appends, failedAt);
         finally
            appends.Free;
         end;
         CheckEquals(-1, failedAt, 'no row failed');
         CheckFalse(repo.InBatch, 'the batch is closed');
         CheckFalse(db.Transaction.Active,
                    'and committed: no transaction is left open behind it');
         CheckEquals(6, integer(repo.RecordCount), 'the seed and five appended rows');
         (* NO COMMIT: a crash right after the import. *)
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
         CheckEquals(6, integer(repo.RecordCount),
                     'all five survive the close: the batch''s commit was its own');
      finally
         repo.Free;
      end;
   finally
      db.Free;
   end;
   Scrub(fn);
end;

(* A FAILURE PART WAY THROUGH AN APPEND BATCH LEAVES THE LOG EXACTLY AS IT WAS.

  Three ways to fail at the third of four rows, each a different path through
  the rollback:

    a QSO with no callsign   the realistic one -- an ADIF record with no CALL.
                             callsign is NOT NULL, so SQLite refuses the row
                             and sqldb's own ROLLBACK ends the batch.
    RAISE(FAIL)              the statement fails; the transaction is ours to
                             end.
    RAISE(ROLLBACK)          SQLite ends the transaction BY ITSELF, as it may on
                             FULL, IOERR, NOMEM or BUSY, and sqldb is not told
                             -- TLogDatabase.Rollback has to resync the two.

  Each is held to the audit's recipe (section 9c): a committed seed; the
  batch fails; the same connection proves the two rows before the failure
  were WRITTEN and then rolled back (its fingerprint, which sees its own
  uncommitted rows, is the seed's again); close with no commit; and the FILE
  is byte for byte what it was before the batch began. *)
procedure TLogRepositoryTests.TestAFailedAppendBatchLeavesTheLogAsItWas;
const
   VARIANTS = 3;
   NAMES: array[0..VARIANTS - 1] of string = (
      'a QSO with no callsign',
      'a RAISE(FAIL) trigger',
      'a RAISE(ROLLBACK) trigger');
var
   db: TLogDatabase;
   repo: TLogRepository;
   appends: TLogQsoAppends;
   seed, qso: ContestExchange;
   failedAt: integer;
   seedPrint, beforeHash, reason: string;
   raised: boolean;
   fn: string;
   v, i: integer;
begin
   BeginTest('a failed append batch leaves the log exactly as it was');
   for v := 0 to VARIANTS - 1 do
      begin
      fn := TempLogName('appendfail' + IntToStr(v) + '.db');
      Scrub(fn);

      db := TLogDatabase.Create;
      try
         db.CreateNew(fn);
         repo := TLogRepository.Create(db);
         try
            MakeDistinctQSO(seed, 0);
            repo.SaveQSO(seed);
            repo.SaveConfigValue('SEED COMMAND', 'seed', 'contest');
            if v = 1 then
               begin
               db.Connection.ExecuteDirect(
                  'CREATE TRIGGER inject_fail AFTER INSERT ON qso ' +
                  'WHEN NEW.callsign = ''BOOM'' ' +
                  'BEGIN SELECT RAISE(FAIL, ''injected failure''); END');
               end;
            if v = 2 then
               begin
               db.Connection.ExecuteDirect(
                  'CREATE TRIGGER inject_rollback AFTER INSERT ON qso ' +
                  'WHEN NEW.callsign = ''BOOM'' ' +
                  'BEGIN SELECT RAISE(ROLLBACK, ''injected failure''); END');
               end;
            repo.Commit;
         finally
            repo.Free;
         end;
      finally
         db.Free;
      end;
      (* After a clean close: the -wal is checkpointed into the file and gone,
        so the file is the whole log. *)
      beforeHash := MD5Print(MD5File(fn));

      db := TLogDatabase.Create;
      try
         db.Open(fn);
         (* A NEW REPOSITORY, prepared against the schema with the trigger. *)
         repo := TLogRepository.Create(db);
         try
            seedPrint := DatabaseFingerprint(db);
            repo.Commit;

            appends := TLogQsoAppends.Create;
            try
               for i := 1 to 4 do
                  begin
                  MakeDistinctQSO(qso, i);
                  if i = 3 then
                     begin
                     if v = 0 then
                        begin
                        qso.Callsign := '';
                        end
                     else
                        begin
                        qso.Callsign := 'BOOM';
                        end;
                     end;
                  appends.Add(qso);
                  end;

               raised := False;
               reason := '';
               try
                  repo.AppendBatch(appends, failedAt);
               except
                  on e: Exception do
                     begin
                     raised := True;
                     reason := e.Message;
                     end;
               end;
            finally
               appends.Free;
            end;

            CheckTrue(raised, NAMES[v] + ': the batch raises');
            CheckEquals(2, failedAt, NAMES[v] + ': and names the third row (index 2)');
            if v = 0 then
               begin
               CheckTrue(Pos('NOT NULL', UpperCase(reason)) > 0,
                         NAMES[v] + ': the reason is SQLite''s own: ' + reason);
               end
            else
               begin
               CheckTrue(Pos('injected failure', reason) > 0,
                         NAMES[v] + ': the reason is the one that happened: ' + reason);
               end;
            CheckFalse(repo.InBatch, NAMES[v] + ': the repository is not left in a batch');
            CheckFalse(db.Transaction.Active,
                       NAMES[v] + ': nor holding a transaction');
            CheckEquals(seedPrint, DatabaseFingerprint(db),
                        NAMES[v] + ': the two rows before the failure are gone, ' +
                        'as this connection sees it');
            repo.Commit;
            (* NO COMMIT OF ANYTHING ELSE: the fingerprint's read is all that
              just ended. *)
         finally
            repo.Free;
         end;
      finally
         db.Free;
      end;

      CheckEquals(beforeHash, MD5Print(MD5File(fn)),
                  NAMES[v] + ': the FILE is byte for byte what it was before the batch');

      db := TLogDatabase.Create;
      try
         db.Open(fn);
         CheckEquals(seedPrint, DatabaseFingerprint(db),
                     NAMES[v] + ': and reopened, it holds the seed and nothing else');
      finally
         db.Free;
      end;
      Scrub(fn);
      end;
end;

(* EACH ROW IS WRITTEN AS THE LIVE APPEND WRITES ONE -- the contest stamped
  from the record, the sent exchange from the caller, and county-line
  grouping that sees the batch's own uncommitted rows. *)
procedure TLogRepositoryTests.TestAnAppendBatchWritesRowsAsTheLiveAppendDoes;
var
   db: TLogDatabase;
   repo: TLogRepository;
   appends: TLogQsoAppends;
   a, b, c: ContestExchange;
   failedAt: integer;
   related: TInt64Array;
   q: TSQLQuery;
   sent: string;
   fn: string;
begin
   BeginTest('an append batch writes each row as the live append does');
   fn := TempLogName('appendshape.db');
   Scrub(fn);

   db := TLogDatabase.Create;
   try
      db.CreateNew(fn);
      repo := TLogRepository.Create(db);
      try
         MakeDistinctQSO(a, 1);
         MakeDistinctQSO(b, 2);
         MakeDistinctQSO(c, 3);
         a.ceContest := ContestHandleOf(CQWWCW);
         b.ceContest := ContestHandleOf(CQWWCW);
         c.ceContest := ContestHandleOf(CQWWCW);
         (* A county line: one exchange, two QSOs. *)
         a.id := 'countyline';
         b.id := 'countyline';

         appends := TLogQsoAppends.Create;
         try
            (* THE SENT EXCHANGE IS THE ROW'S OWN, handed in with it (stage 2:
              the callback that rebuilt it from the live station is gone). *)
            appends.Add(a, NotCapturedMyFacts, SentExchangeForTest(a));
            appends.Add(b, NotCapturedMyFacts, SentExchangeForTest(b));
            appends.Add(c, NotCapturedMyFacts, SentExchangeForTest(c));
            repo.AppendBatch(appends, failedAt);
         finally
            appends.Free;
         end;

         CheckTrue(repo.LogContest = ContestHandleOf(CQWWCW), 'the log is stamped with the records'' contest');

         related := repo.RelatedRowIds(1);
         CheckEquals(1, integer(Length(related)), 'the first row has one relative');
         if Length(related) = 1 then
            begin
            CheckEquals(2, integer(related[0]),
                        'the second -- grouped inside the batch, before any commit');
            end;
         CheckEquals(0, integer(Length(repo.RelatedRowIds(3))),
                     'and the third stands alone');

         sent := '';
         q := TSQLQuery.Create(nil);
         try
            q.DataBase := db.Connection;
            q.UsePrimaryKeyAsKey := False;
            q.SQL.Text := 'SELECT group_concat(exchange_sent, ''|'') FROM ' +
                          '(SELECT exchange_sent FROM qso ORDER BY id)';
            q.Open;
            sent := q.Fields[0].AsString;
            q.Close;
         finally
            q.Free;
         end;
         CheckEquals('599 ' + string(a.Callsign) + '|599 ' + string(b.Callsign) +
                     '|599 ' + string(c.Callsign), sent,
                     'each row carries the sent exchange the caller supplied');
      finally
         repo.Free;
      end;
   finally
      db.Free;
   end;
   Scrub(fn);
end;

(* exchange_sent of one row, '' for NULL, through the connection handed in. *)
function SentExchangeOfRow(aDatabase: TLogDatabase; aRowId: Int64): string;
var
   q: TSQLQuery;
begin
   Result := '';
   q := TSQLQuery.Create(nil);
   try
      q.DataBase := aDatabase.Connection;
      q.UsePrimaryKeyAsKey := False;
      q.SQL.Text := 'SELECT IFNULL(exchange_sent, '''') FROM qso WHERE id = :id';
      q.ParamByName('id').AsLargeInt := aRowId;
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

(* AN EDIT CHANGES ONLY WHAT WAS EDITED -- Q61's latent defect (2), and Q13.

  exchange_sent is what was SENT when the QSO was logged. The record has no
  field for it, so every update bound the repository's next-save value, which
  SaveQSO clears after each insert: Edit QSO, the rescore's batch, a network
  update and a re-import each wrote NULL over it. Every one of those paths is
  run here, and then the row is read back after a REOPEN, so it is the file
  that keeps it.

  ~~And the one path that means to write it on an existing row
  (SetSentExchange) does~~ -- there is no such path since 2026-10-17:
  exchange_sent is insert-only. *)
procedure TLogRepositoryTests.TestAnEditKeepsTheSentExchange;
var
   db: TLogDatabase;
   repo: TLogRepository;
   first, second, edited: ContestExchange;
   firstId, secondId: Int64;
   firstGuid: AnsiString;
   updates: TLogRowUpdates;
   wasNew: boolean;
   fn: string;
begin
   BeginTest('an edit, a rescore, a network update and a re-import keep exchange_sent');
   fn := TempLogName('keepsent.db');
   Scrub(fn);

   db := TLogDatabase.Create;
   try
      db.CreateNew(fn);
      repo := TLogRepository.Create(db);
      try
         MakeDistinctQSO(first, 1);
         MakeDistinctQSO(second, 2);
         repo.SetNextSentExchange('599 05');
         firstId := repo.SaveQSO(first);
         firstGuid := repo.LastGuid;
         repo.SetNextSentExchange('599 06');
         secondId := repo.SaveQSO(second);
         repo.Commit;
         CheckEquals('599 05', SentExchangeOfRow(db, firstId),
                     'the live append recorded what was sent');

         edited := first;
         edited.Callsign := 'EDITED';
         edited.QSOPoints := 9;

         (* Edit QSO and the newest-row rewrite. *)
         CheckTrue(repo.UpdateQSO(firstId, edited), 'the edit found its row');
         repo.Commit;
         CheckEquals('599 05', SentExchangeOfRow(db, firstId),
                     'Edit QSO keeps the sent exchange');

         (* The network's update, keyed on the session pair. *)
         CheckTrue(repo.UpdateQSOBySessionIds(first.ceQSOID1, first.ceQSOID2,
                                              edited),
                   'the network update found its row');
         repo.Commit;
         CheckEquals('599 05', SentExchangeOfRow(db, firstId),
                     'a network update keeps it');

         (* The rescore's batch. *)
         updates := TLogRowUpdates.Create;
         try
            updates.Add(firstId, edited);
            updates.Add(secondId, second);
            repo.WriteBatch(updates);
         finally
            updates.Free;
         end;
         CheckEquals('599 05', SentExchangeOfRow(db, firstId),
                     'a rescore keeps it');
         CheckEquals('599 06', SentExchangeOfRow(db, secondId),
                     'on every row of the batch');

         (* A re-import of our own export: the same guid, an update. *)
         repo.ImportQSOByGuid(firstGuid, edited, wasNew);
         repo.Commit;
         CheckFalse(wasNew, 'the re-import matched the row');
         CheckEquals('599 05', SentExchangeOfRow(db, firstId),
                     'a re-import keeps it');
      finally
         repo.Free;
      end;
   finally
      db.Free;
   end;

   db := TLogDatabase.Create;
   try
      db.Open(fn);
      CheckEquals('599 05', SentExchangeOfRow(db, firstId),
                  'after a reopen, the edited QSO still carries what it sent');
      CheckEquals('599 06', SentExchangeOfRow(db, secondId),
                  'and the other QSO what it sent');
   finally
      db.Free;
   end;
   Scrub(fn);
end;

(* THE VALIDITY CHECK'S QUERY: QSOs with no exchange id, counted in full and
  sampled in log order. Notes are not QSOs and are not counted; a deleted QSO
  is still a contact and is. (F6, NY4I 2026-10-14: a rescore no longer mints
  ids, so a missing one is REPORTED.) *)
procedure TLogRepositoryTests.TestQSOsWithoutAnExchangeIdAreReported;
var
   db: TLogDatabase;
   repo: TLogRepository;
   qso: ContestExchange;
   missing: TMissingExchangeIds;
   fn: string;
begin
   BeginTest('QSOs with no exchange id are counted and sampled');
   fn := TempLogName('missingids.db');
   Scrub(fn);

   db := TLogDatabase.Create;
   try
      db.CreateNew(fn);
      repo := TLogRepository.Create(db);
      try
         missing := repo.QSOsWithoutExchangeId(5);
         CheckEquals(0, missing.Count, 'an empty log has none');
         CheckEquals('', missing.Sample, 'and nothing to sample');

         MakeDistinctQSO(qso, 1);                    (* has an id *)
         repo.SaveQSO(qso);
         MakeDistinctQSO(qso, 2);                    (* none *)
         qso.id := '';
         qso.ceQSO_Deleted := False;
         repo.SaveQSO(qso);
         MakeDistinctQSO(qso, 3);                    (* none, and deleted *)
         qso.id := '';
         qso.ceQSO_Deleted := True;
         repo.SaveQSO(qso);
         MakeDistinctQSO(qso, 4);                    (* a note: not a QSO *)
         qso.id := '';
         qso.ceRecordKind := rkNote;
         repo.SaveQSO(qso);
         MakeDistinctQSO(qso, 5);                    (* none *)
         qso.id := '';
         repo.SaveQSO(qso);
         repo.Commit;

         missing := repo.QSOsWithoutExchangeId(2);
         CheckEquals(3, missing.Count, 'three QSOs carry none: the note is not counted');
         CheckTrue(Pos('K2ABC 2026-06-03 12:32', missing.Sample) > 0,
                   'the first is named with its time: ' + missing.Sample);
         CheckTrue(Pos('K3ABC', missing.Sample) > 0,
                   'the deleted one is still a QSO: ' + missing.Sample);
         CheckEquals(0, Pos('K5ABC', missing.Sample),
                     'and the sample stops at its size; the count does not: ' +
                     missing.Sample);
      finally
         repo.Free;
      end;
   finally
      db.Free;
   end;
   Scrub(fn);
end;

(* THE CONTEST ROW'S start_time IS READ WHEN THE LOG OPENS (Q35) -- the
   contest year a bonus table is chosen by. A new log has none (nothing
   writes it until Q99) and answers 0, never 1 January 1970; a row that
   carries one answers it, as a UTC TDateTime, from a repository opened
   after it was written -- the reopened-old-log case. *)
procedure TLogRepositoryTests.TestTheContestStartTimeIsReadAtOpen;
var
   db: TLogDatabase;
   repo: TLogRepository;
   fn: string;
   start: TDateTime;
begin
   BeginTest('TestTheContestStartTimeIsReadAtOpen');
   fn := TempLogName('starttime.db');
   Scrub(fn);
   start := EncodeDate(2026, 3, 14) + EncodeTime(19, 0, 0, 0);

   db := TLogDatabase.Create;
   try
      db.CreateNew(fn);
      repo := TLogRepository.Create(db);
      try
         repo.SetContest(ContestHandleOf(IDAHOQSOPARTY));
         repo.Commit;
         CheckTrue(repo.LogStartTime = 0, 'a new log records no start');
      finally
         repo.Free;
      end;

      (* What Q99 will write at New Contest. *)
      db.Connection.ExecuteDirect(
         'UPDATE contest SET start_time = ' + IntToStr(DateTimeToUnix(start)) +
         ' WHERE id = 1');
      db.Transaction.Commit;

      repo := TLogRepository.Create(db);
      try
         (* Within a second: the column holds whole unix seconds. *)
         CheckTrue(Abs(repo.LogStartTime - start) < 1.0 / 86400,
                   'a reopened log answers its recorded start: ' +
                   DateTimeToStr(repo.LogStartTime));
      finally
         repo.Free;
      end;

      db.Connection.ExecuteDirect('UPDATE contest SET start_time = 0 WHERE id = 1');
      db.Transaction.Commit;
      repo := TLogRepository.Create(db);
      try
         CheckTrue(repo.LogStartTime = 0, 'a zero start is "not recorded", not 1970');
      finally
         repo.Free;
      end;
   finally
      db.Free;
   end;

   Scrub(fn);
end;

(* EVERY "NOW" THE LOG STORES IS UNIX UTC -- 2026-10-19.

  contest.created_at, config.set_at, session_state.saved_at and the
  millisecond timestamp at the head of the contest row's guid were all
  DateTimeToUnix(Now): LOCAL time stored as if it were UTC. Each is checked
  against a UTC window taken around the writes.

  THIS CAN ONLY CATCH THE DEFECT ON A MACHINE WHOSE CLOCK IS NOT UTC, because
  there local and UTC are the same number. The test says so when it runs on
  one, rather than passing quietly as though it had checked something.
  Mutation-checked 2026-10-19 at UTC-4: putting Now back fails all four. *)
procedure TLogRepositoryTests.TestEveryNowTheLogStoresIsUTC;
var
   db: TLogDatabase;
   repo: TLogRepository;
   q: TSQLQuery;
   fn: string;
   before, after: Int64;
   offsetSeconds: Int64;
   guid: AnsiString;
   guidSeconds: Int64;

   procedure CheckInWindow(aValue: Int64; const aWhat: string);
   begin
      CheckTrue((aValue >= before) and (aValue <= after),
                aWhat + ' is UTC: ' + IntToStr(aValue) + ' not in [' +
                IntToStr(before) + ', ' + IntToStr(after) + '] (local offset ' +
                IntToStr(offsetSeconds) + ' s)');
   end;

begin
   BeginTest('TestEveryNowTheLogStoresIsUTC');
   fn := TempLogName('utcnow.db');
   Scrub(fn);

   offsetSeconds := DateTimeToUnix(Now) - DateTimeToUnix(LocalTimeToUniversal(Now));
   if Abs(offsetSeconds) < 60 then
      begin
      WriteLn('  NOTE: this machine''s clock is UTC, so TestEveryNowTheLogStoresIsUTC ' +
              'cannot tell local from UTC here.');
      end;

   (* A second either side: the column holds whole seconds. *)
   before := DateTimeToUnix(LocalTimeToUniversal(Now)) - 1;

   db := TLogDatabase.Create;
   try
      db.CreateNew(fn);
      repo := TLogRepository.Create(db);
      try
         repo.SetContest(ContestHandleOf(IDAHOQSOPARTY));
         repo.SaveConfigValue('MY CALL', 'NY4I', 'station');
         repo.SaveSessionValue('utc-probe', '1');
         repo.Commit;
      finally
         repo.Free;
      end;
      after := DateTimeToUnix(LocalTimeToUniversal(Now)) + 1;

      q := TSQLQuery.Create(nil);
      try
         q.DataBase := db.Connection;
         q.Transaction := db.Transaction;

         q.SQL.Text := 'SELECT created_at, guid FROM contest WHERE id = 1';
         q.Open;
         CheckInWindow(q.Fields[0].AsLargeInt, 'contest.created_at');
         guid := AnsiString(q.Fields[1].AsString);
         q.Close;
         (* The first twelve hex digits are the UUIDv7's unix milliseconds. *)
         guidSeconds := StrToInt64('$' + string(Copy(guid, 1, 12))) div 1000;
         CheckInWindow(guidSeconds, 'the contest guid''s timestamp');

         q.SQL.Text := 'SELECT set_at FROM config WHERE command = ''MY CALL''';
         q.Open;
         CheckInWindow(q.Fields[0].AsLargeInt, 'config.set_at');
         q.Close;

         q.SQL.Text := 'SELECT saved_at FROM session_state WHERE key = ''utc-probe''';
         q.Open;
         CheckInWindow(q.Fields[0].AsLargeInt, 'session_state.saved_at');
         q.Close;
      finally
         q.Free;
      end;
      db.Transaction.Commit;
   finally
      db.Free;
   end;

   Scrub(fn);
end;

(* WHICH ROWS THE MULTI-OP SERVER STILL HAS TO BE TOLD ABOUT (Phase 1, C5).

  A row is owed a QSO packet while sent_to_server is 0 and an edit packet while
  server_dirty is 1 -- but only a row with a network identity. Eight rows cover
  every combination, and the two with both ids 0 are what an import writes: they
  must never be sent, however their flags read, or a station that opened an
  imported log would flood the network with it. Order is log order. *)
procedure TLogRepositoryTests.TestTheRepositoryFindsExactlyTheRowsTheServerIsOwed;
var
   db: TLogDatabase;
   repo: TLogRepository;
   qso: ContestExchange;
   expected: array of ContestExchange;
   owed: TLogRowUpdates;
   fn: string;
   unsent, dirty, i: integer;

   (* Saves one row; aOwed says whether it should come back. *)
   procedure Add(aSeed: integer; aSent, aDirty: boolean; aId1, aId2: Cardinal;
                 aOwed: boolean);
   begin
      MakeDistinctQSO(qso, aSeed);
      qso.ceSendToServer := aSent;
      qso.ceNeedSendToServerAE := aDirty;
      qso.ceQSOID1 := aId1;
      qso.ceQSOID2 := aId2;
      repo.SaveQSO(qso);
      if aOwed then
         begin
         SetLength(expected, Length(expected) + 1);
         expected[High(expected)] := qso;
         end;
   end;

begin
   BeginTest('the repository finds exactly the rows the server is owed');
   fn := TempLogName('owed.db');
   Scrub(fn);
   SetLength(expected, 0);

   db := TLogDatabase.Create;
   try
      db.CreateNew(fn);
      repo := TLogRepository.Create(db);
      try
         Add(1, True,  False, 1, 1, False);   (* the server has it, current *)
         Add(2, False, False, 2, 2, True);    (* never sent *)
         Add(3, True,  True,  3, 3, True);    (* sent, edited since *)
         Add(4, False, True,  4, 4, True);    (* both *)
         Add(5, False, False, 0, 0, False);   (* an import: no identity *)
         Add(6, False, True,  0, 0, False);   (* an import, edited *)
         Add(7, False, False, 7, 0, True);    (* a half-zero pair is still a pair *)
         Add(8, False, False, 0, 8, True);
         repo.Commit;

         owed := TLogRowUpdates.Create;
         try
            CheckEquals(5, repo.CollectUnsentToServer(owed), 'five rows are owed');
            CheckEquals(5, owed.Count, 'and five were collected');
            for i := 0 to owed.Count - 1 do
               begin
               CompareQSO(expected[i], owed.Row(i), 'owed row ' + IntToStr(i));
               end;
            CheckTrue(owed.RowId(0) < owed.RowId(4), 'oldest first');
         finally
            owed.Free;
         end;

         repo.CountUnsentToServer(unsent, dirty);
         CheckEquals(4, unsent, 'four networked rows were never sent');
         CheckEquals(2, dirty, 'two networked rows were edited since');

         CheckTrue(repo.HasQSOBySessionIds(2, 2), 'a stored key is found');
         CheckTrue(repo.HasQSOBySessionIds(7, 0), 'a half-zero key is found');
         CheckFalse(repo.HasQSOBySessionIds(9, 9), 'an unknown key is not');
         CheckFalse(repo.HasQSOBySessionIds(0, 0),
                    '(0, 0) names nothing, though rows carry it');
      finally
         repo.Free;
      end;
   finally
      db.Free;
   end;
   Scrub(fn);
end;

(* MARKING WRITES THE TWO FLAGS AND NOTHING ELSE, and only where they change.
  Every other column of every row is compared after, field by field, against
  the record that was saved with the flags it should now have. *)
procedure TLogRepositoryTests.TestMarkingServerProgressWritesTheFlagsAndNothingElse;
var
   db: TLogDatabase;
   repo: TLogRepository;
   a, b, c, back, want: ContestExchange;
   idA, idB, idC: Int64;
   sent, edits: TQsoSessionKeys;
   none: TQsoSessionKeys;
   unsent, dirty: integer;
   fn: string;

   function Key(const aQso: ContestExchange): TQsoSessionKey;
   begin
      Result.SessionId := aQso.ceQSOID1;
      Result.SessionSeq := aQso.ceQSOID2;
   end;

begin
   BeginTest('marking server progress writes the two flags and nothing else');
   fn := TempLogName('marks.db');
   Scrub(fn);
   SetLength(none, 0);

   db := TLogDatabase.Create;
   try
      db.CreateNew(fn);
      repo := TLogRepository.Create(db);
      try
         MakeDistinctQSO(a, 10);
         a.ceSendToServer := False;
         a.ceNeedSendToServerAE := True;
         idA := repo.SaveQSO(a);
         MakeDistinctQSO(b, 11);
         b.ceSendToServer := False;
         b.ceNeedSendToServerAE := True;
         idB := repo.SaveQSO(b);
         MakeDistinctQSO(c, 12);
         c.ceSendToServer := True;
         c.ceNeedSendToServerAE := False;
         idC := repo.SaveQSO(c);
         repo.Commit;

         (* A is sent; its edit is still owed. B and C are untouched. *)
         SetLength(sent, 1);
         sent[0] := Key(a);
         CheckEquals(1, repo.MarkServerProgress(sent, none), 'one row changed');
         repo.Commit;
         want := a;
         want.ceSendToServer := True;
         CheckTrue(repo.LoadQSO(idA, back), 'A reads');
         CompareQSO(want, back, 'A: sent, still dirty, nothing else changed');
         CheckTrue(repo.LoadQSO(idB, back), 'B reads');
         CompareQSO(b, back, 'B is untouched');

         (* Marking it again changes nothing: the flag is already set. *)
         CheckEquals(0, repo.MarkServerProgress(sent, none), 'a flag already set is left alone');
         repo.Commit;

         (* A's edit is done; C was not dirty and stays as it is. A key that
           matches no row is not an error. *)
         SetLength(edits, 3);
         edits[0] := Key(a);
         edits[1] := Key(c);
         edits[2].SessionId := 999;
         edits[2].SessionSeq := 999;
         CheckEquals(1, repo.MarkServerProgress(none, edits), 'only A was dirty');
         repo.Commit;
         want.ceNeedSendToServerAE := False;
         CheckTrue(repo.LoadQSO(idA, back), 'A reads again');
         CompareQSO(want, back, 'A: sent and current, nothing else changed');
         CheckTrue(repo.LoadQSO(idC, back), 'C reads');
         CompareQSO(c, back, 'C is untouched');

         repo.CountUnsentToServer(unsent, dirty);
         CheckEquals(1, unsent, 'only B was never sent');
         CheckEquals(1, dirty, 'only B is still edited');
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
   (* FIRST, AND ON EVERY PLATFORM: these need no D7 fixture, and they pin
     the column order every reader depends on. *)
   TestTheColumnTableAgreesWithQSO_COLUMNS;
   TestAReaderWhoseColumnsDriftedFailsLoudly;
   TestEveryReaderReturnsTheSameRecord;
   TestTheCursorYieldsEachRowsId;
   TestARowIdReaderNeedsTheIdLast;
   TestABatchCommitsByRowId;
   TestAFailedBatchRollsBackWhole;
   TestABatchRefusesWhatWouldBreakIt;
   TestEveryWriteWaitsForItsCommit;
   TestAFreshRepositoryHoldsItsWritesUntilCommit;
   TestABatchSQLiteRollsBackItselfLeavesTheRepositoryUsable;
   TestALogSQLiteRolledBackClosesCleanly;
   TestAnAppendBatchLandsInOneCommit;
   TestAFailedAppendBatchLeavesTheLogAsItWas;
   TestAnAppendBatchWritesRowsAsTheLiveAppendDoes;
   TestAnEditKeepsTheSentExchange;
   TestQSOsWithoutAnExchangeIdAreReported;
   TestTheContestStartTimeIsReadAtOpen;
   TestEveryNowTheLogStoresIsUTC;
   TestTheRepositoryFindsExactlyTheRowsTheServerIsOwed;
   TestMarkingServerProgressWritesTheFlagsAndNothingElse;

{$IFNDEF WINDOWS}
   (* SAID, NOT SILENT: a suite that quietly contributes nothing is
     indistinguishable from one that passed. *)
   WriteLn('  SKIPPED (the rest): reads a D7 binary log, which is a Windows migration path.');
   if (FDir <> '') and DirectoryExists(FDir) then
      begin
      RemoveDir(FDir);
      end;
   Exit;
{$ENDIF}
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
   TestANoteSurvivesTheLog;

   if (FDir <> '') and DirectoryExists(FDir) then
      begin
      RemoveDir(FDir);
      end;
end;

end.
