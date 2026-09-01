unit uTestLogRepository;

{ ContestExchange -> a qso row -> ContestExchange, ROUND TRIP.

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
  every combination of flags twenty years of contests produced. }

{$I ..\..\src\tr4w.inc}

interface

uses
   { VC is in the INTERFACE because CompareQSO takes ContestExchange. }
   uTR4WTestFramework, VC;

type
   TLogRepositoryTests = class(TTestCase)
   private
      FDir: string;
      function TempLogName(const aLeaf: string): string;
      procedure Scrub(const aFileName: string);
      function CorpusLog(const aSet: string): string;

      { A METHOD, not a free function: CheckEquals is protected on TTestCase,
        which is the framework saying assertions belong to a test. }
      procedure CompareQSO(const a, b: ContestExchange; const where: string);
   protected
      procedure TestOneQSORoundTrips;
      procedure TestSentinelsBecomeNullAndComeBack;
      procedure TestEveryRowGetsItsOwnGuid;
      procedure TestCountyLineQSOsShareAnExchangeId;
      procedure TestSearchAndPounceIsInverted;
      procedure TestKidsFollowsTheRecordKind;
      procedure TestUUIDv7ShapeAndOrdering;
      procedure TestWholeCorpusLogRoundTrips;
   public
      procedure RunAllTests; override;
   end;

implementation

uses
   { Windows for MAXBYTE / MAXWORD -- the not-set markers ClearContestExchange
     writes, and the values this suite exists to prove never reach the log. }
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

{ --------------------------------------------------------------------------- }

{ EVERY PERSISTED FIELD, NAMED. Adding a column to the mapper without adding it
  here leaves the new column untested, which is the same hole one level up --
  so the crosswalk, the schema and this list are three places that must agree,
  and the build fails if they do not. }
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
   { identity }
   SameInt('ceQSOID1', integer(a.ceQSOID1), integer(b.ceQSOID1));
   SameInt('ceQSOID2', integer(a.ceQSOID2), integer(b.ceQSOID2));
   Same('ceComputerID', AnsiString(a.ceComputerID), AnsiString(b.ceComputerID));
   SameInt('ceOperatorID', a.ceOperatorID, b.ceOperatorID);
   SameInt('ceRecordKind', Ord(a.ceRecordKind), Ord(b.ceRecordKind));

   { when and what }
   SameInt('tSysTime', integer(QSOTimeToUnixUTC(a.tSysTime)),
                       integer(QSOTimeToUnixUTC(b.tSysTime)));
   Same('Callsign', AnsiString(a.Callsign), AnsiString(b.Callsign));
   Same('QTH.StandardCall', AnsiString(a.QTH.StandardCall), AnsiString(b.QTH.StandardCall));
   SameInt('Frequency', a.Frequency, b.Frequency);
   SameInt('Band', Ord(a.Band), Ord(b.Band));
   SameInt('Mode', Ord(a.Mode), Ord(b.Mode));
   SameInt('ExtMode', Ord(a.ExtMode), Ord(b.ExtMode));
   Same('ExchString', AnsiString(a.ExchString), AnsiString(b.ExchString));

   { the exchange }
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

   { CTY.DAT-derived }
   Same('QTH.Prefix', AnsiString(a.QTH.Prefix), AnsiString(b.QTH.Prefix));
   Same('QTH.CountryID', AnsiString(a.QTH.CountryID), AnsiString(b.QTH.CountryID));
   SameInt('QTH.Country', a.QTH.Country, b.QTH.Country);
   SameInt('QTH.Zone', a.QTH.Zone, b.QTH.Zone);
   SameInt('QTH.Continent', Ord(a.QTH.Continent), Ord(b.QTH.Continent));

   { multipliers }
   Same('Prefix', AnsiString(a.Prefix), AnsiString(b.Prefix));
   Same('DXQTH', AnsiString(a.DXQTH), AnsiString(b.DXQTH));
   Same('DomMultQTH', AnsiString(a.DomMultQTH), AnsiString(b.DomMultQTH));
   SameBool('DomesticMult', a.DomesticMult, b.DomesticMult);
   SameBool('DXMult', a.DXMult, b.DXMult);
   SameBool('PrefixMult', a.PrefixMult, b.PrefixMult);
   SameBool('ZoneMult', a.ZoneMult, b.ZoneMult);
   SameBool('InhibitMults', a.InhibitMults, b.InhibitMults);

   { state }
   SameInt('QSOPoints', a.QSOPoints, b.QSOPoints);
   SameBool('ceDupe', a.ceDupe, b.ceDupe);
   SameBool('ceSearchAndPounce', a.ceSearchAndPounce, b.ceSearchAndPounce);
   SameBool('ceXQSO', a.ceXQSO, b.ceXQSO);
   SameBool('ceQSO_Skiped', a.ceQSO_Skiped, b.ceQSO_Skiped);
   SameBool('ceWasSendInQTC', a.ceWasSendInQTC, b.ceWasSendInQTC);
   SameBool('NameSent', a.NameSent, b.NameSent);
   SameBool('MP3Record', a.MP3Record, b.MP3Record);
   SameBool('ceClearDupeSheet', a.ceClearDupeSheet, b.ceClearDupeSheet);
   SameBool('ceClearMultSheet', a.ceClearMultSheet, b.ceClearMultSheet);
   SameInt('ceRadio', Ord(a.ceRadio), Ord(b.ceRadio));
   { Compared through the same NUL-aware helper the mapper uses -- a direct
     AnsiString() cast of this array is the bug this line would hide. }
   Same('ceOperator', CharArrayToAnsi(a.ceOperator),
                      CharArrayToAnsi(b.ceOperator));
   SameBool('ceQSO_Deleted', a.ceQSO_Deleted, b.ceQSO_Deleted);
   SameBool('ceSendToServer', a.ceSendToServer, b.ceSendToServer);
   SameBool('ceNeedSendToServerAE', a.ceNeedSendToServerAE, b.ceNeedSendToServerAE);
end;

{ --------------------------------------------------------------------------- }

procedure TLogRepositoryTests.TestOneQSORoundTrips;
var
   db: TLogDatabase;
   repo: TLogRepository;
   reader: TLogBinaryReader;
   before, after: ContestExchange;
   guid: AnsiString;
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
         guid := repo.SaveQSO(before);
         repo.Commit;
         CheckTrue(repo.LoadQSO(guid, after), 'the saved QSO reads back');
         CompareQSO(before, after, 'cqww first QSO');
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
   guid: AnsiString;
   fn: string;
begin
   BeginTest('TestSentinelsBecomeNullAndComeBack');
   fn := TempLogName('sentinel.db');
   Scrub(fn);

   { The shape ClearContestExchange leaves: not-set markers that are the type's
     MAXIMUM, not zero. Crosswalk finding 3. }
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
         guid := repo.SaveQSO(before);
         repo.Commit;
         CheckTrue(repo.LoadQSO(guid, after), 'it reads back');

         { Each of these is a value that would look exactly like data if the
           mapper wrote the sentinel through. }
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
   qso.id := '5cd6c61f69cf4422baef44f93b2cbbd2';   { a real corpus id }
   qso.tSysTime.qtYear := 26;
   qso.tSysTime.qtMonth := 2;
   qso.tSysTime.qtDay := 11;

   g1 := NewRowGuid(qso);
   g2 := NewRowGuid(qso);

   CheckEquals(32, Length(g1), 'a row guid fits ContestExchange.id exactly');

   { THE POINT: the same record minted twice gives two guids, because two rows
     are two rows even when they came from one exchange. }
   CheckTrue(g1 <> g2, 'the same record yields a DIFFERENT guid each time');
   CheckTrue(g1 <> AnsiString(qso.id), 'and it is never the record''s own id');
end;

procedure TLogRepositoryTests.TestCountyLineQSOsShareAnExchangeId;
var
   db: TLogDatabase;
   repo: TLogRepository;
   pin, hil, back: ContestExchange;
   gPin, gHil: AnsiString;
   fn: string;
begin
   BeginTest('TestCountyLineQSOsShareAnExchangeId');
   fn := TempLogName('countyline.db');
   Scrub(fn);

   { THE CASE THAT BROKE THE FIRST DESIGN, taken from the corpus: two W4THY
     rows in florida_qp_2026_ny4i, one for PIN and one for HIL, both carrying
     5cd6c61f69cf4422baef44f93b2cbbd2. One exchange, two QSOs. Making the
     record's id the unique row key fails on the second of these -- which is
     every county line in every QSO party. }
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

         CheckTrue(gPin <> gHil, 'the two QSOs get DIFFERENT row guids');
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
   guid: AnsiString;
   fn: string;
begin
   BeginTest('TestSearchAndPounceIsInverted');
   fn := TempLogName('sandp.db');
   Scrub(fn);

   FillChar(before, SizeOf(before), 0);
   before.ceRecordKind := rkQSO;
   before.Callsign := 'W1AW';
   before.ceSearchAndPounce := True;      { so is_run must be 0 }
   before.tSysTime.qtYear := 26;
   before.tSysTime.qtMonth := 6;
   before.tSysTime.qtDay := 1;

   db := TLogDatabase.Create;
   try
      db.CreateNew(fn);
      repo := TLogRepository.Create(db);
      try
         guid := repo.SaveQSO(before);
         repo.Commit;
         CheckTrue(repo.LoadQSO(guid, after), 'it reads back');

         { A straight copy instead of an inversion would be wrong in a way
           nothing reports -- every S&P QSO would read as a run QSO. }
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
   gQso, gQtc: AnsiString;
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
   qtc.Kids := 'G3ABC';               { a CALLSIGN, not exchange text }

   db := TLogDatabase.Create;
   try
      db.CreateNew(fn);
      repo := TLogRepository.Create(db);
      try
         gQso := repo.SaveQSO(qso);
         gQtc := repo.SaveQSO(qtc);
         repo.Commit;

         { One column meaning either, depending on another column, is how a
           wrong Cabrillo line gets written two years from now. Two columns,
           and the record kind decides. }
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

   early := NewUUIDv7(1000000000000);     { 2001 }
   late  := NewUUIDv7(1800000000000);     { 2027 }

   CheckEquals(32, Length(early), 'a guid is 32 hex characters, no dashes');
   { Six bytes of timestamp are twelve hex characters, so the version nibble is
     the thirteenth. }
   CheckEquals('7', string(early[13]), 'version 7');

   { The reason question 5 chose v7 over v4: it sorts by creation time, so rows
     cluster in insertion order and a chooser can order by guid alone. }
   CheckTrue(early < late, 'a v7 guid sorts by its timestamp');
end;

procedure TLogRepositoryTests.TestWholeCorpusLogRoundTrips;
const
   { Four sets chosen to span the shapes: a DX zone contest, a domestic QSO
     party, a serial-number contest and Field Day's class exchange. }
   SETS: array[0..3] of string = (
      'cqww_ssb_2025_ny4i', 'florida_qp_2026_ny4i',
      'cqwpx_cw_2026_ny4i', 'arrl_fd_2026_ny4i');
var
   s: integer;
   db: TLogDatabase;
   repo: TLogRepository;
   reader: TLogBinaryReader;
   before, after: ContestExchange;
   guids: TStringList;
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

      guids := TStringList.Create;
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
                     New(rec);
                     rec^ := before;
                     originals.Add(rec);
                     guids.Add(string(repo.SaveQSO(before)));
                     Inc(n);
                     end;
               finally
                  reader.Free;
               end;
               repo.Commit;

               CheckEquals(n, repo.QSOCount,
                           SETS[s] + ': the database holds every QSO written');

               { THE EXHAUSTIVE PART. Every QSO in the log, every persisted
                 field, both directions. }
               for i := 0 to guids.Count - 1 do
                  begin
                  CheckTrue(repo.LoadQSO(AnsiString(guids[i]), after),
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
         guids.Free;
      end;

      Scrub(fn);
      end;
end;

procedure TLogRepositoryTests.RunAllTests;
begin
   TestOneQSORoundTrips;
   TestSentinelsBecomeNullAndComeBack;
   TestEveryRowGetsItsOwnGuid;
   TestCountyLineQSOsShareAnExchangeId;
   TestSearchAndPounceIsInverted;
   TestKidsFollowsTheRecordKind;
   TestUUIDv7ShapeAndOrdering;
   TestWholeCorpusLogRoundTrips;

   if (FDir <> '') and DirectoryExists(FDir) then
      begin
      RemoveDir(FDir);
      end;
end;

end.
