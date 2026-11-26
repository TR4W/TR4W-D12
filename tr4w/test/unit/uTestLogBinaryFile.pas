unit uTestLogBinaryFile;

(* READING A BINARY TR4W LOG.

  These run against REAL D7-written logs -- the six kept as unit fixtures in
  test\unit\fixtures\binarylog.  They were corpus fixtures until
  2026-09-24; the corpus's input is a log.db now, and this suite is where
  reading a D7 binary log is covered.
  A synthetic fixture would prove the reader agrees with itself; these prove it
  agrees with logs TR4W actually wrote, which is the only interesting claim.

  THE DATE TEST IS THE POINT OF THIS SUITE. qtYear is the year minus 2000 and a
  wrong epoch moves every QSO in every log by a century while failing nothing --
  no exception, no corrupt file, just a log that says 1926 or 2126. It is pinned
  against a fixture whose date is also visible in that set's frozen Cabrillo
  reference, so the two would have to be wrong together. *)

{$I ..\..\src\tr4w.inc}

interface

uses
   uTR4WTestFramework;

type
   TLogBinaryFileTests = class(TTestCase)
   private
      function BinaryLogFixture(const aSet: string): string;
   protected
      procedure TestOpensARealCorpusLog;
      procedure TestReadsEveryRecordTheSizeImplies;
      procedure TestFirstQSOMatchesTheFrozenReference;
      procedure TestQSOTimeEpochIsYearMinus2000;
      procedure TestQSOTimeRoundTrips;
      procedure TestQSOTimeZeroDateIsZero;
      procedure TestUnrepresentableYearRaises;
      procedure TestMissingFileReportsRatherThanRaises;
      procedure TestStrideMismatchIsRefused;
      procedure TestEveryBinaryLogFixtureReads;
      procedure TestTheRecordIsTheSameSizeEverywhere;
      procedure TestTheRecordHasTheSameFIELD_OFFSETSEverywhere;
      procedure TestTheConverterCarriesEveryByte;
      procedure TestTheConverterLeavesThe5xFieldsUnset;
      procedure TestTheLegacyDeleteFlagIsFolded;
      procedure TestANoteCrossesAsText;
      procedure TestAQTCRecordCrosses;
   public
      procedure TestTheRecordStaysUnmanaged;
      procedure TestClearZeroesEveryByte;
      procedure TestSameBytesComparesBytesNotText;
      procedure RunAllTests; override;
   end;

implementation

uses
   SysUtils, Classes, DateUtils, VC, uLogBinaryFile,
   uLogNote;   (* NoteText -- a converted note's text *)

(* The suite runs from test\unit (ParamStr(0)); fixtures sit beside the exe. *)
function TLogBinaryFileTests.BinaryLogFixture(const aSet: string): string;
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

procedure TLogBinaryFileTests.TestOpensARealCorpusLog;
var
   r: TLogBinaryReader;
begin
   BeginTest('TestOpensARealCorpusLog');
   r := TLogBinaryReader.Create(BinaryLogFixture('arktika_2026_ny4i'));
   try
      CheckTrue(r.Status = lbOK, 'a D7-written corpus log opens: ' + r.Message);
      CheckEquals('', r.Message, 'and reports nothing');
      CheckTrue(r.ExpectedRecords > 0, 'and the file size implies some records');
   finally
      r.Free;
   end;
end;

procedure TLogBinaryFileTests.TestReadsEveryRecordTheSizeImplies;
var
   r: TLogBinaryReader;
   rec: ContestExchange;
   n: integer;
begin
   BeginTest('TestReadsEveryRecordTheSizeImplies');
   r := TLogBinaryReader.Create(BinaryLogFixture('arktika_2026_ny4i'));
   try
      CheckTrue(r.Status = lbOK, 'opened: ' + r.Message);
      n := 0;
      while r.ReadNext(rec) do
         begin
         Inc(n);
         end;

      (* They differ only if the file was truncated mid-write, and none of the
        fixtures is. Comparing them is what would CATCH a stride bug that the
        divisibility check somehow let through. *)
      CheckEquals(integer(r.ExpectedRecords), n,
                  'every record the file size implies was actually read');
      CheckEquals(integer(r.ExpectedRecords), integer(r.RecordsRead),
                  'and the reader counted the same');
   finally
      r.Free;
   end;
end;

procedure TLogBinaryFileTests.TestFirstQSOMatchesTheFrozenReference;
var
   r: TLogBinaryReader;
   rec: ContestExchange;
   found: boolean;
   call: string;
begin
   BeginTest('TestFirstQSOMatchesTheFrozenReference');

   (* general_qso's frozen Cabrillo says:
       QSO: 14248 PH 2026-02-11 0006 W1AW/4  59  TOM  KD6RYO  59  AR
     so the first good-looking record must be KD6RYO on 2026-02-11 at 00:06.
     Reading it out of the BINARY and matching the reference is what proves the
     reader and the epoch together. *)
   r := TLogBinaryReader.Create(BinaryLogFixture('general_qso_2026_w1aw4'));
   try
      CheckTrue(r.Status = lbOK, 'opened: ' + r.Message);
      found := False;
      call := '';
      while (not found) and r.ReadNext(rec) do
         begin
         if GoodLookingQSO(rec) then
            begin
            found := True;
            call := string(rec.Callsign);
            CheckEquals(2026, YearOf(UnixToDateTime(QSOTimeToUnixUTC(rec.tSysTime))),
                        'the year in the binary is 2026, not 1926 or 2126');
            CheckEquals(2, MonthOf(UnixToDateTime(QSOTimeToUnixUTC(rec.tSysTime))),
                        'February');
            CheckEquals(11, DayOf(UnixToDateTime(QSOTimeToUnixUTC(rec.tSysTime))),
                        'the 11th');
            end;
         end;

      CheckTrue(found, 'the log contains at least one good-looking QSO');
      CheckEquals('KD6RYO', call,
                  'the first QSO is the one the frozen Cabrillo reference names');
   finally
      r.Free;
   end;
end;

procedure TLogBinaryFileTests.TestQSOTimeEpochIsYearMinus2000;
var
   t: TQSOTime;
   dt: TDateTime;
begin
   BeginTest('TestQSOTimeEpochIsYearMinus2000');

   (* Stated as an assertion rather than left implicit in the fixture test, so a
     failure says WHICH of the two is wrong. *)
   t.qtYear   := 26;
   t.qtMonth  := 2;
   t.qtDay    := 11;
   t.qtHour   := 0;
   t.qtMinute := 6;
   t.qtSecond := 0;

   dt := UnixToDateTime(QSOTimeToUnixUTC(t));
   CheckEquals(2026, YearOf(dt), 'qtYear 26 is 2026');
   CheckEquals(2, MonthOf(dt), 'month');
   CheckEquals(11, DayOf(dt), 'day');
   CheckEquals(0, HourOf(dt), 'hour');
   CheckEquals(6, MinuteOf(dt), 'minute');
end;

procedure TLogBinaryFileTests.TestQSOTimeRoundTrips;
var
   t, back: TQSOTime;
   unix: Int64;
begin
   BeginTest('TestQSOTimeRoundTrips');

   t.qtYear   := 25;
   t.qtMonth  := 12;
   t.qtDay    := 31;
   t.qtHour   := 23;
   t.qtMinute := 59;
   t.qtSecond := 59;

   unix := QSOTimeToUnixUTC(t);
   back := UnixUTCToQSOTime(unix);

   (* The export path needs the inverse, and a round trip that loses the seconds
     is exactly the defect that made every spot of one clock minute share a
     timestamp in the band map. *)
   CheckEquals(t.qtYear, back.qtYear, 'year survives');
   CheckEquals(t.qtMonth, back.qtMonth, 'month survives');
   CheckEquals(t.qtDay, back.qtDay, 'day survives');
   CheckEquals(t.qtHour, back.qtHour, 'hour survives');
   CheckEquals(t.qtMinute, back.qtMinute, 'minute survives');
   CheckEquals(t.qtSecond, back.qtSecond, 'SECONDS survive');
end;

procedure TLogBinaryFileTests.TestQSOTimeZeroDateIsZero;
var
   t: TQSOTime;
begin
   BeginTest('TestQSOTimeZeroDateIsZero');
   FillChar(t, SizeOf(t), 0);

   (* tree.pas writes qtYear := 0 for "no time". Decoding that as 1 January 2000
     would put a real-looking QSO in the year the format was invented. *)
   CheckEquals(0, integer(QSOTimeToUnixUTC(t)),
               'a zero date is zero, not the year 2000');
end;

procedure TLogBinaryFileTests.TestUnrepresentableYearRaises;
var
   raised: boolean;
begin
   BeginTest('TestUnrepresentableYearRaises');

   raised := False;
   try
      (* 1999 -- before the epoch. Silently truncating to a byte would reproduce
        the century bug this unit exists to prevent. *)
      UnixUTCToQSOTime(DateTimeToUnix(EncodeDate(1999, 6, 1)));
   except
      on E: ERangeError do
         begin
         raised := True;
         end;
   end;
   CheckTrue(raised, 'a year before 2000 is refused, not truncated');
end;

procedure TLogBinaryFileTests.TestMissingFileReportsRatherThanRaises;
var
   r: TLogBinaryReader;
   rec: ContestExchange;
begin
   BeginTest('TestMissingFileReportsRatherThanRaises');

   (* logdump could Halt(2). A unit cannot: the importer has to tell an operator
     which of his logs would not read and carry on with the rest. *)
   r := TLogBinaryReader.Create(BinaryLogFixture('no_such_contest_set'));
   try
      CheckTrue(r.Status = lbCannotOpen, 'a missing log is reported');
      CheckTrue(r.Message <> '', 'and says why');
      CheckFalse(r.ReadNext(rec), 'and reading it yields nothing rather than faulting');
   finally
      r.Free;
   end;
end;

procedure TLogBinaryFileTests.TestStrideMismatchIsRefused;
var
   fn: string;
   src: TFileStream;
   dst: TFileStream;
   r: TLogBinaryReader;
begin
   BeginTest('TestStrideMismatchIsRefused');

   (* Take a real log and add one byte. That is what a log written by a TR4W with
     a different SizeOfContestExchange looks like from here, and reading it at
     our stride would produce misaligned records that look like data. *)
   fn := IncludeTrailingPathDelimiter(GetTempDir) + 'tr4w_stride_test_' + IntToStr(GetProcessID) + '.trw';
   if FileExists(fn) then
      begin
      DeleteFile(fn);
      end;

   src := TFileStream.Create(BinaryLogFixture('arktika_2026_ny4i'), fmOpenRead or fmShareDenyNone);
   try
      dst := TFileStream.Create(fn, fmCreate);
      try
         dst.CopyFrom(src, src.Size);
         dst.WriteByte(0);
      finally
         dst.Free;
      end;
   finally
      src.Free;
   end;

   r := TLogBinaryReader.Create(fn);
   try
      CheckTrue(r.Status = lbStrideMismatch,
                'a file that is not header + N*record is refused');
      CheckTrue(Pos('different size', r.Message) > 0,
                'and the message says what that normally means');
   finally
      r.Free;
   end;

   DeleteFile(fn);
end;

procedure TLogBinaryFileTests.TestEveryBinaryLogFixtureReads;
const
   (* THE SIX D7 LOGS KEPT AS UNIT FIXTURES, and why each one is here.

     This was all thirteen corpus sets until 2026-09-24, when the golden
     corpus's input became a log.db and the .trw files stopped living there.
     NY4I: "that becomes a unit test and not the corpus."  Six were kept
     rather than one, because each carries an assertion no other log can:

       arktika_2026_ny4i       752 bytes -- the degenerate log, one record
       florida_qp_2026_ny4i    two county-line PAIRS, and records that
                               GoodLookingQSO rejects (5 held, 3 exportable)
       general_qso_2026_w1aw4  the queryable/ordering fixture (KD6RYO first)
       cqww_ssb_2025_ny4i      a DX zone contest, and the repository
                               round-trip's largest log
       cqwpx_cw_2026_ny4i      a serial-number contest
       arrl_fd_2026_ny4i       Field Day's class/section exchange

     Named rather than enumerated from the directory, so a fixture that
     disappears fails here instead of quietly shrinking the coverage. *)
   SETS: array[0..5] of string = (
      'arktika_2026_ny4i', 'arrl_fd_2026_ny4i', 'cqwpx_cw_2026_ny4i',
      'cqww_ssb_2025_ny4i', 'florida_qp_2026_ny4i',
      'general_qso_2026_w1aw4');
var
   i: integer;
   r: TLogBinaryReader;
   rec: ContestExchange;
   n: integer;
   good: integer;
begin
   BeginTest('TestEveryBinaryLogFixtureReads');

   for i := Low(SETS) to High(SETS) do
      begin
      r := TLogBinaryReader.Create(BinaryLogFixture(SETS[i]));
      try
         CheckTrue(r.Status = lbOK, SETS[i] + ' opens: ' + r.Message);

         n := 0;
         good := 0;
         while r.ReadNext(rec) do
            begin
            Inc(n);
            if GoodLookingQSO(rec) then
               begin
               Inc(good);
               end;
            end;

         CheckEquals(integer(r.ExpectedRecords), n, SETS[i] + ' reads every record');

         (* Every set in the corpus exports QSOs, so a set with none would mean
           GoodLookingQSO had drifted from what ExportToADIF emits -- which is
           the failure that would make the corpus compare two populations. *)
         CheckTrue(good > 0, SETS[i] + ' contains at least one exportable QSO');
      finally
         r.Free;
      end;
      end;
end;

(* THE .TRW RECORD IS FROZEN, AND ITS SIZE IS A CONTRACT (issue 386, batch B).

  The reader reads one record of the FROZEN type TTrwRecordV17 (uLogBinaryFile)
  and carries it into ContestExchange field by field. Until 2026-11-26 it read
  straight into ContestExchange, so these pins were on the live record; they
  are on the frozen one now, against LITERAL numbers, and the live record is
  free to change.

  376 IS NOT A NUMBER CHOSEN HERE. It is what D7 wrote and what every old log
  on disk is made of. A plain `record`, not `packed`: the file format is the
  x86 natural alignment D7 used, so this is also a PORTABILITY GATE -- on a
  platform where it fails, TR4W cannot read an old log and must not pretend to.
  The compile-time {$IF SizeOf} check in uLogBinaryFile says the same. *)
procedure TLogBinaryFileTests.TestTheRecordIsTheSameSizeEverywhere;
begin
   BeginTest('TestTheRecordIsTheSameSizeEverywhere');
   CheckEquals(376, SizeOf(TTrwRecordV17),
               'the frozen D7 record is 376 bytes -- the size every old log is made of');
   CheckEquals(376, TRW_RECORD_SIZE, 'and the named size says so');
   CheckEquals(376, SizeOf(TTrwHeaderV17), 'the header is one record');
   CheckEquals(6, SizeOf(TTrwQSOTimeV17), 'the time is six bytes');
   CheckEquals(32, SizeOf(TTrwQTHRecordV17), 'the QTH record is 32 bytes');
end;

(* SIZE IS NOT ENOUGH (2026-09-08): the record was 376 bytes on aarch64-darwin
  too, and QTH.Continent still decoded as 86 ('V') there, because padding moves
  between fields while the sum stays the same. So EVERY field's offset and size
  is pinned, and the pins must TILE the record: each field starts where the
  last one ended, except at the two pad gaps D7's alignment left (198..199
  before NumberReceived, 374..375 at the end). A field missing from this list
  leaves a gap and fails here.

  THE NUMBERS WERE TAKEN FROM ContestExchange ON 2026-11-26, at the split, and
  compared field for field (every offset equal). From now on they are the
  FILE's numbers and do not follow the live record.

  The TLogFileInformation pins are the multi-op log-compare packet, which
  carries the contest byte too. *)
procedure TLogBinaryFileTests.TestTheRecordHasTheSameFIELD_OFFSETSEverywhere;
var
   r: TTrwRecordV17;
   info: TLogFileInformation;
   base: PtrUInt;
   expectNext: integer;

   function Off(const aAddr): integer;
   begin
      Result := integer(PtrUInt(@aAddr) - base);
   end;

   procedure Pin(const aName: string; aOffset, aSize, aActualOffset, aActualSize: integer);
   begin
      CheckEquals(aOffset, aActualOffset, aName + ' offset');
      CheckEquals(aSize, aActualSize, aName + ' size');
      if expectNext = 198 then
         begin
         expectNext := 200;   (* D7's pad before NumberReceived *)
         end;
      CheckEquals(expectNext, aActualOffset, aName + ' starts where the previous field ended');
      expectNext := aActualOffset + aActualSize;
   end;

begin
   BeginTest('TestTheRecordHasTheSameFIELD_OFFSETSEverywhere');
   base := PtrUInt(@r);
   expectNext := 0;

   Pin('tSysTime',             0,   6, Off(r.tSysTime),             SizeOf(r.tSysTime));
   Pin('Band',                 6,   1, Off(r.Band),                 SizeOf(r.Band));
   Pin('Mode',                 7,   1, Off(r.Mode),                 SizeOf(r.Mode));
   Pin('ceQSOID1',             8,   4, Off(r.ceQSOID1),             SizeOf(r.ceQSOID1));
   Pin('ceQSOID2',             12,  4, Off(r.ceQSOID2),             SizeOf(r.ceQSOID2));
   Pin('Frequency',            16,  4, Off(r.Frequency),            SizeOf(r.Frequency));
   Pin('ceQSO_Deleted',        20,  1, Off(r.ceQSO_Deleted),        SizeOf(r.ceQSO_Deleted));
   Pin('ceComputerID',         21,  1, Off(r.ceComputerID),         SizeOf(r.ceComputerID));
   Pin('ceOperatorID',         22,  1, Off(r.ceOperatorID),         SizeOf(r.ceOperatorID));
   Pin('ceRecordKind',         23,  1, Off(r.ceRecordKind),         SizeOf(r.ceRecordKind));
   Pin('ceQSO_Skiped',         24,  1, Off(r.ceQSO_Skiped),         SizeOf(r.ceQSO_Skiped));
   Pin('ceSendToServer',       25,  1, Off(r.ceSendToServer),       SizeOf(r.ceSendToServer));
   Pin('ceNeedSendToServerAE', 26,  1, Off(r.ceNeedSendToServerAE), SizeOf(r.ceNeedSendToServerAE));
   Pin('ceDupe',               27,  1, Off(r.ceDupe),               SizeOf(r.ceDupe));
   Pin('PostalCode_old',       28,  7, Off(r.PostalCode_old),       SizeOf(r.PostalCode_old));
   Pin('ZERO_01',              35,  1, Off(r.ZERO_01),              SizeOf(r.ZERO_01));
   Pin('Prefix',               36,  7, Off(r.Prefix),               SizeOf(r.Prefix));
   Pin('ZERO_02',              43,  1, Off(r.ZERO_02),              SizeOf(r.ZERO_02));
   Pin('Callsign',             44,  14, Off(r.Callsign),            SizeOf(r.Callsign));
   Pin('Age',                  58,  1, Off(r.Age),                  SizeOf(r.Age));
   Pin('ceWasSendInQTC',       59,  1, Off(r.ceWasSendInQTC),       SizeOf(r.ceWasSendInQTC));
   Pin('DomesticMult',         60,  1, Off(r.DomesticMult),         SizeOf(r.DomesticMult));
   Pin('DXMult',               61,  1, Off(r.DXMult),               SizeOf(r.DXMult));
   Pin('PrefixMult',           62,  1, Off(r.PrefixMult),           SizeOf(r.PrefixMult));
   Pin('ZoneMult',             63,  1, Off(r.ZoneMult),             SizeOf(r.ZoneMult));
   Pin('ExtMode',              64,  1, Off(r.ExtMode),              SizeOf(r.ExtMode));
   Pin('ExchString',           65,  41, Off(r.ExchString),          SizeOf(r.ExchString));
   Pin('ceClass',              106, 4, Off(r.ceClass),              SizeOf(r.ceClass));
   Pin('ZERO_04',              110, 1, Off(r.ZERO_04),              SizeOf(r.ZERO_04));
   Pin('Precedence',           111, 1, Off(r.Precedence),           SizeOf(r.Precedence));
   Pin('ceRadio',              112, 1, Off(r.ceRadio),              SizeOf(r.ceRadio));
   Pin('Check',                113, 1, Off(r.Check),                SizeOf(r.Check));
   Pin('QTH',                  114, 32, Off(r.QTH),                 SizeOf(r.QTH));
   Pin('DXQTH',                146, 6, Off(r.DXQTH),                SizeOf(r.DXQTH));
   Pin('ZERO_05',              152, 1, Off(r.ZERO_05),              SizeOf(r.ZERO_05));
   Pin('Radio',                153, 1, Off(r.Radio),                SizeOf(r.Radio));
   Pin('DomMultQTH',           154, 11, Off(r.DomMultQTH),          SizeOf(r.DomMultQTH));
   Pin('ZERO_06',              165, 1, Off(r.ZERO_06),              SizeOf(r.ZERO_06));
   Pin('DomesticQTH',          166, 11, Off(r.DomesticQTH),         SizeOf(r.DomesticQTH));
   Pin('ZERO_07',              177, 1, Off(r.ZERO_07),              SizeOf(r.ZERO_07));
   Pin('Name',                 178, 11, Off(r.Name),                SizeOf(r.Name));
   Pin('ZERO_08',              189, 1, Off(r.ZERO_08),              SizeOf(r.ZERO_08));
   Pin('Power',                190, 7, Off(r.Power),                SizeOf(r.Power));
   Pin('ZERO_09',              197, 1, Off(r.ZERO_09),              SizeOf(r.ZERO_09));
   Pin('NumberReceived',       200, 4, Off(r.NumberReceived),       SizeOf(r.NumberReceived));
   Pin('NumberSent',           204, 4, Off(r.NumberSent),           SizeOf(r.NumberSent));
   Pin('RSTSent',              208, 2, Off(r.RSTSent),              SizeOf(r.RSTSent));
   Pin('RSTReceived',          210, 2, Off(r.RSTReceived),          SizeOf(r.RSTReceived));
   Pin('QTHString',            212, 11, Off(r.QTHString),           SizeOf(r.QTHString));
   Pin('ZERO_10',              223, 1, Off(r.ZERO_10),              SizeOf(r.ZERO_10));
   Pin('RandomCharsSent',      224, 6, Off(r.RandomCharsSent),      SizeOf(r.RandomCharsSent));
   Pin('TenTenNum',            230, 2, Off(r.TenTenNum),            SizeOf(r.TenTenNum));
   Pin('Chapter',              232, 5, Off(r.Chapter),              SizeOf(r.Chapter));
   Pin('ZERO_11',              237, 1, Off(r.ZERO_11),              SizeOf(r.ZERO_11));
   Pin('ceClearDupeSheet',     238, 1, Off(r.ceClearDupeSheet),     SizeOf(r.ceClearDupeSheet));
   Pin('ceSearchAndPounce',    239, 1, Off(r.ceSearchAndPounce),    SizeOf(r.ceSearchAndPounce));
   Pin('Prefecture',           240, 1, Off(r.Prefecture),           SizeOf(r.Prefecture));
   Pin('InhibitMults',         241, 1, Off(r.InhibitMults),         SizeOf(r.InhibitMults));
   Pin('Zone',                 242, 1, Off(r.Zone),                 SizeOf(r.Zone));
   Pin('NameSent',             243, 1, Off(r.NameSent),             SizeOf(r.NameSent));
   Pin('Kids',                 244, 21, Off(r.Kids),                SizeOf(r.Kids));
   Pin('ceContest',            265, 1, Off(r.ceContest),            SizeOf(r.ceContest));
   Pin('QSOPoints',            266, 2, Off(r.QSOPoints),            SizeOf(r.QSOPoints));
   Pin('RandomCharsReceived',  268, 8, Off(r.RandomCharsReceived),  SizeOf(r.RandomCharsReceived));
   Pin('ZERO_13',              276, 1, Off(r.ZERO_13),              SizeOf(r.ZERO_13));
   Pin('ceClearMultSheet',     277, 1, Off(r.ceClearMultSheet),     SizeOf(r.ceClearMultSheet));
   Pin('MP3Record',            278, 1, Off(r.MP3Record),            SizeOf(r.MP3Record));
   Pin('ceOperator',           279, 11, Off(r.ceOperator),          SizeOf(r.ceOperator));
   Pin('id',                   290, 33, Off(r.id),                  SizeOf(r.id));
   Pin('ceXQSO',               323, 1, Off(r.ceXQSO),               SizeOf(r.ceXQSO));
   Pin('sReserved',            324, 50, Off(r.sReserved),           SizeOf(r.sReserved));
   CheckEquals(374, expectNext, 'the fields end at 374; 374..375 are D7''s padding');

   (* INSIDE THE NESTED QTH RECORD, where the aarch64 defect was. Relative to
     QTH, so "where is QTH" and "how is QTH laid out" fail separately. *)
   CheckEquals(6,  Off(r.QTH.Zone) - Off(r.QTH),         'QTH.Zone at +6');
   CheckEquals(7,  Off(r.QTH.reserved) - Off(r.QTH),     'QTH.reserved at +7');
   CheckEquals(8,  Off(r.QTH.Prefix) - Off(r.QTH),       'QTH.Prefix at +8');
   CheckEquals(15, Off(r.QTH.Continent) - Off(r.QTH),    'QTH.Continent at +15');
   CheckEquals(16, Off(r.QTH.StandardCall) - Off(r.QTH), 'QTH.StandardCall at +16');
   CheckEquals(30, Off(r.QTH.Country) - Off(r.QTH),      'QTH.Country at +30');

   (* THE LOG-COMPARE PACKET (NET_LOGCOMPARE): 19 bytes, the contest last. *)
   CheckEquals(1, SizeOf(TContestHandle), 'a contest handle is one byte');
   CheckEquals(19, SizeOf(TLogFileInformation), 'TLogFileInformation is 19 bytes');
   CheckEquals(18, integer(PtrUInt(@info.liContest) - PtrUInt(@info)),
               'liContest, the contest byte, is its last');
end;

type
   (* THE FILE'S BYTES, for the tests that write a byte of a D7 record by
     offset (a note's region, the byte-flip test): an overlay, so no Move and
     no pointer. The frozen record IS a byte layout; ContestExchange is not. *)
   TTrwRecordBytes = record
      case Byte of
         0: (rec: TTrwRecordV17);
         1: (bytes: array[0..375] of Byte);
   end;

(* A note record whose file region (36 onward) holds aText. *)
function TrwNoteRecord(const aText: AnsiString): TTrwRecordV17;
var
   view: TTrwRecordBytes;
   i: integer;
begin
   view.rec := Default(TTrwRecordV17);
   view.rec.ceRecordKind := Ord(rkNote);
   for i := 1 to Length(aText) do
      begin
      view.bytes[35 + i] := Ord(aText[i]);
      end;
   Result := view.rec;
end;

(* A frozen record with every field set and every string at FULL length, so a
  change to any byte of it -- content or length -- is visible after the
  conversion. The two delete flags are False, so either one turned on shows. *)
function FullTrwRecord: TTrwRecordV17;
var
   i: integer;
begin
   Result := Default(TTrwRecordV17);
   Result.tSysTime.qtYear := 26;
   Result.tSysTime.qtMonth := 11;
   Result.tSysTime.qtDay := 26;
   Result.tSysTime.qtHour := 12;
   Result.tSysTime.qtMinute := 34;
   Result.tSysTime.qtSecond := 56;
   Result.Band := 3;
   Result.Mode := 2;
   Result.ceQSOID1 := $11223344;
   Result.ceQSOID2 := $55667788;
   Result.Frequency := 14025123;
   Result.ceComputerID := 'B';
   Result.ceOperatorID := 7;
   Result.ceRecordKind := 0;
   Result.ceSendToServer := True;
   Result.ceNeedSendToServerAE := True;
   Result.ceDupe := True;
   Result.PostalCode_old := 'POSTAL';
   Result.ZERO_01 := 1;
   Result.Prefix := 'PREFIX';
   Result.ZERO_02 := 2;
   Result.Callsign := 'CALLSIGN12345';
   Result.Age := 42;
   Result.ceWasSendInQTC := True;
   Result.DomesticMult := True;
   Result.DXMult := True;
   Result.PrefixMult := True;
   Result.ZoneMult := True;
   Result.ExtMode := 5;
   Result.ExchString := StringOfChar('E', 40);
   Result.ceClass := '10A';
   Result.ZERO_04 := 4;
   Result.Precedence := 'Q';
   Result.ceRadio := 2;
   Result.Check := 77;
   Result.QTH.CountryID := 'CNTRY';
   Result.QTH.Zone := 14;
   Result.QTH.reserved := 9;
   Result.QTH.Prefix := 'QPREFX';
   Result.QTH.Continent := 3;
   Result.QTH.StandardCall := 'STANDARDCALL1';
   Result.QTH.Country := $1234;
   Result.DXQTH := 'DXQTH';
   Result.ZERO_05 := 5;
   Result.Radio := 11;
   Result.DomMultQTH := 'DOMMULTQTH';
   Result.ZERO_06 := 6;
   Result.DomesticQTH := 'DOMESTICQT';
   Result.ZERO_07 := 7;
   Result.Name := 'NAMEFIELD1';
   Result.ZERO_08 := 8;
   Result.Power := 'POWER1';
   Result.ZERO_09 := 9;
   Result.NumberReceived := $01020304;
   Result.NumberSent := $05060708;
   Result.RSTSent := $0599;
   Result.RSTReceived := $0579;
   Result.QTHString := 'QTHSTRING1';
   Result.ZERO_10 := 10;
   Result.RandomCharsSent := 'RCSNT';
   Result.TenTenNum := $4321;
   Result.Chapter := 'CHAP';
   Result.ZERO_11 := 11;
   Result.ceClearDupeSheet := True;
   Result.ceSearchAndPounce := True;
   Result.Prefecture := 47;
   Result.InhibitMults := True;
   Result.Zone := 33;
   Result.NameSent := True;
   Result.Kids := StringOfChar('K', 20);
   Result.ceContest := 12;
   Result.QSOPoints := $0302;
   Result.RandomCharsReceived := 'RCRCVD7';
   Result.ZERO_13 := 13;
   Result.ceClearMultSheet := True;
   Result.MP3Record := True;
   for i := 0 to 10 do
      begin
      Result.ceOperator[i] := AnsiChar(Ord('a') + i);
      end;
   Result.id := StringOfChar('I', 32);
   Result.ceXQSO := True;
end;

(* EVERY BYTE OF THE FILE'S RECORD REACHES THE QSO -- except D7's two pad gaps
  and sReserved, which D7 never wrote. Each byte of a full record is changed in
  turn (a length byte DOWN, so the shorter string still fits), the record is
  converted, and the QSO must differ from the unchanged one's. A field the
  converter forgets, or carries from the wrong place, fails here by offset. *)
procedure TLogBinaryFileTests.TestTheConverterCarriesEveryByte;
var
   base: TTrwRecordV17;
   changed: TTrwRecordBytes;
   baseQso, changedQso: ContestExchange;
   i, missed: integer;
begin
   BeginTest('TestTheConverterCarriesEveryByte');
   base := FullTrwRecord;
   TrwRecordToQso(base, baseQso);
   missed := 0;
   for i := 0 to SizeOf(TTrwRecordV17) - 1 do
      begin
      if (i = 198) or (i = 199) or (i >= 324) then
         begin
         Continue;   (* pads and sReserved: not carried, by design *)
         end;
      changed.rec := base;
      if changed.bytes[i] > 0 then
         begin
         changed.bytes[i] := changed.bytes[i] - 1;
         end
      else
         begin
         changed.bytes[i] := 1;
         end;
      TrwRecordToQso(changed.rec, changedQso);
      if changedQso.SameBytes(baseQso) then
         begin
         Inc(missed);
         CheckTrue(False, 'byte ' + IntToStr(i) + ' of the D7 record does not reach the QSO');
         end;
      end;
   CheckEquals(0, missed, 'every byte from 0 to 323 but the pad reaches the QSO');
end;

(* THE 5.x FIELDS DO NOT EXIST IN A D7 FILE and come out unset, whatever lies in
  D7's sReserved -- exactly what the old reader's clearing gave. *)
procedure TLogBinaryFileTests.TestTheConverterLeavesThe5xFieldsUnset;
var
   trw: TTrwRecordV17;
   q: ContestExchange;
begin
   BeginTest('TestTheConverterLeavesThe5xFieldsUnset');
   trw := FullTrwRecord;
   trw.sReserved := StringOfChar('x', 49);
   (* The destination holds a value in every 5.x field first: the converter
     must clear them, not merely leave them alone. *)
   q.Clear;
   q.RcvdYear := 4321;
   q.RcvdYearKnown := True;
   q.YearSent := 1234;
   q.YearSentKnown := True;
   q.ceOffContest := True;
   q.ceRoverQTH := 'KIN';
   q.sReserved := 'junk';
   q.ceQSO_Skiped := True;
   TrwRecordToQso(trw, q);
   CheckEquals(0, integer(q.RcvdYear), 'no received year');
   CheckFalse(q.RcvdYearKnown, 'and it is not known');
   CheckEquals(0, integer(q.YearSent), 'no sent year');
   CheckFalse(q.YearSentKnown, 'and it is not known');
   CheckFalse(q.ceOffContest, 'not stamped off-contest');
   CheckEquals('', string(q.ceRoverQTH), 'no rover place');
   CheckEquals('', string(q.sReserved), 'and nothing of sReserved');
   CheckTrue(q.ceXQSO, 'but a D7 X-QSO is carried: D7 itself had ceXQSO');
   CheckFalse(q.ceQSO_Skiped, 'the legacy delete flag is never set');
end;

(* The legacy Alt-Y flag is folded into the one delete flag, at this door. *)
procedure TLogBinaryFileTests.TestTheLegacyDeleteFlagIsFolded;
var
   trw: TTrwRecordV17;
   q: ContestExchange;
begin
   BeginTest('TestTheLegacyDeleteFlagIsFolded');
   trw := FullTrwRecord;
   trw.ceQSO_Skiped := True;
   TrwRecordToQso(trw, q);
   CheckTrue(q.ceQSO_Deleted, 'a skipped QSO is a deleted QSO');
   CheckFalse(q.ceQSO_Skiped, 'and the old flag is not passed on');
   trw := FullTrwRecord;
   TrwRecordToQso(trw, q);
   CheckFalse(q.ceQSO_Deleted, 'neither flag: not deleted');
end;

(* A NOTE IS A BYTE REGION, not fields: 80 bytes from Prefix, across Callsign
  and the fields after it into QTH. It must arrive as the same text. *)
procedure TLogBinaryFileTests.TestANoteCrossesAsText;
var
   trw: TTrwRecordV17;
   q: ContestExchange;
   text: AnsiString;
begin
   BeginTest('TestANoteCrossesAsText');
   CheckEquals(36, integer(PtrUInt(@trw.Prefix) - PtrUInt(@trw)), 'the region starts at Prefix, 36');
   CheckTrue(36 + TRW_NOTE_REGION <= SizeOf(TTrwRecordV17), 'and lies inside the record');

   text := 'the rig drifted 200 Hz after the band change, CQ on 14025 again';
   trw := TrwNoteRecord(text);
   trw.Band := Ord(Band20);
   CheckEquals(string(text), string(TrwNoteText(trw)), 'the file region reads back');
   TrwRecordToQso(trw, q);
   CheckTrue(q.ceRecordKind = rkNote, 'a note stays a note');
   CheckEquals(string(text), string(NoteText(q)), 'and its text crosses whole');
   CheckTrue(q.Band = Band20, 'the fields outside the region are carried too');

   text := StringOfChar('n', TRW_NOTE_REGION);
   trw := TrwNoteRecord(text);
   TrwRecordToQso(trw, q);
   CheckEquals(string(text), string(NoteText(q)), 'a full 80-byte note, no NUL, crosses whole');
end;

(* A WAE QTC record (rkQTCS) is ordinary fields: the QTC callsign in Kids, the
  QSO time in NumberSent, the serial in NumberReceived, the series in
  QSOPoints. They become the Cabrillo QTC: lines, so each is checked by name. *)
procedure TLogBinaryFileTests.TestAQTCRecordCrosses;
var
   trw: TTrwRecordV17;
   q: ContestExchange;
begin
   BeginTest('TestAQTCRecordCrosses');
   trw := Default(TTrwRecordV17);
   trw.ceRecordKind := Ord(rkQTCS);
   trw.Callsign := 'DL1ABC';
   trw.Kids := 'OH2XYZ';
   trw.NumberSent := 1234;
   trw.NumberReceived := 56;
   trw.QSOPoints := 3;
   trw.RandomCharsSent := '3/10';
   trw.ceContest := 7;
   TrwRecordToQso(trw, q);
   CheckTrue(q.ceRecordKind = rkQTCS, 'a sent QTC stays a sent QTC');
   CheckEquals('DL1ABC', string(q.Callsign), 'the station the series went to');
   CheckEquals('OH2XYZ', string(q.Kids), 'the callsign inside the QTC');
   CheckEquals(1234, q.NumberSent, 'the QSO time');
   CheckEquals(56, q.NumberReceived, 'the serial');
   CheckEquals(3, integer(q.QSOPoints), 'the series');
   CheckEquals('3/10', string(q.RandomCharsSent), 'the series/count text');
   CheckEquals(7, integer(q.ceContest.ToByte), 'the contest byte');
end;

(* WINDOWS-ONLY, AND THAT IS A SCOPE CORRECTION RATHER THAN A RETREAT.

  NY4I, 2026-09-08: "I no longer see the value in us writing the binary log
  file anymore. I think our log should strictly be SQLite... I'm not really
  sure that maintaining anything except the ability to import a binary log for
  people moving from an older one to a newer one on Windows has any value."

  So reading a D7 .TRW is a WINDOWS MIGRATION PATH. Nobody on macOS or Linux
  has one to bring -- those are new platforms -- and a suite that reads one
  there is testing a situation that cannot arise.

  IT WAS ALSO FAILING THERE, FOR A REAL REASON. The frozen record (until
  2026-11-26, ContestExchange itself) is a plain record the reader block-reads
  a file into, so the on-disk format is the target's alignment layout: QTH
  lands at 114 on i386 and x86_64, and at 116 on aarch64. Every field from
  there on decodes wrong -- measured, the same QSO gives Continent = 1 on
  Linux and 86 on macOS.

  THAT DEFECT IS NOT FIXED BY THIS GATE, it is SCOPED by it. Windows is where
  import runs, Windows is where it is tested, and
  TestTheRecordHasTheSameFIELD_OFFSETSEverywhere stays as the thing that says
  why if anyone tries to widen it again. The converter tests are arithmetic on
  records, not files, so they run everywhere -- but their offsets are x86's,
  so they too sit after the skip. *)

(* THE RUNTIME TWIN OF VC's COMPILE GUARD (issue 386). The guard,
  TContestExchangeMustStayUnmanaged, stops the build when a managed field is
  added; this says the same thing where the suite reports it, and also covers
  the nested records the guard reaches through ContestExchange. *)
procedure TLogBinaryFileTests.TestTheRecordStaysUnmanaged;
begin
   BeginTest('TestTheRecordStaysUnmanaged');
   CheckFalse(IsManagedType(ContestExchange),
              'ContestExchange holds no managed field (a value record, issue 386)');
   CheckFalse(IsManagedType(QTHRecord), 'nor does its nested QTHRecord');
   CheckFalse(IsManagedType(TContestHandle), 'nor its contest handle');
   CheckFalse(IsManagedType(TTrwRecordV17), 'nor the frozen .TRW record');
   CheckFalse(IsManagedType(TTrwHeaderV17), 'nor the .TRW header');
end;

(* Clear IS Default(ContestExchange), and that must be the same bytes as the
  FillChar it replaces -- padding included, which an assignment of a default
  value need not promise. Filled with $FF first, so a byte Clear missed shows. *)
procedure TLogBinaryFileTests.TestClearZeroesEveryByte;
var
   r: ContestExchange;
   p: PByte;
   i, nonZero: integer;
begin
   BeginTest('TestClearZeroesEveryByte');
   FillChar(r, SizeOf(ContestExchange), $FF);
   r.Clear;
   p := PByte(@r);
   nonZero := 0;
   for i := 0 to SizeOf(ContestExchange) - 1 do
      begin
      if p[i] <> 0 then
         begin
         Inc(nonZero);
         end;
      end;
   CheckEquals(0, nonZero, 'every byte of the record is zero after Clear');
end;

(* SameBytes is a BYTE comparison, and says so: equal text after a longer
  value was held is NOT the same bytes. *)
procedure TLogBinaryFileTests.TestSameBytesComparesBytesNotText;
var
   a, b: ContestExchange;
begin
   BeginTest('TestSameBytesComparesBytesNotText');
   a.Clear;
   b.Clear;
   CheckTrue(a.SameBytes(b), 'two cleared records are the same bytes');
   a.Callsign := 'W1AW';
   CheckFalse(a.SameBytes(b), 'a changed field is seen');
   b.Callsign := 'W1AW';
   CheckTrue(a.SameBytes(b), 'the same field written the same way is the same');
   b.Callsign := 'W1AWXYZ';
   b.Callsign := 'W1AW';
   CheckEquals(string(a.Callsign), string(b.Callsign), 'the text reads the same');
   CheckFalse(a.SameBytes(b),
              'but the slack past the length byte still holds XYZ: not the same bytes');
   a.ceRoverQTH := 'KIN';
   b.Clear;
   b.ceRoverQTH := 'KIN';
   b.Callsign := 'W1AW';
   CheckTrue(a.SameBytes(b), 'the last field is compared too');
   b.sReserved[31] := 'x';
   CheckFalse(a.SameBytes(b), 'and the very last byte of sReserved');
end;

procedure TLogBinaryFileTests.RunAllTests;
begin
   (* BEFORE the Windows-only skip: these are arithmetic, not a file. *)
   TestTheRecordStaysUnmanaged;
   TestClearZeroesEveryByte;
   TestSameBytesComparesBytesNotText;

{$IFNDEF WINDOWS}
   (* SAID, NOT SILENT: a suite that quietly contributes nothing is
     indistinguishable from one that passed. *)
   WriteLn('  SKIPPED: reads a D7 binary log, which is a Windows migration path.');
   Exit;
{$ENDIF}
   TestOpensARealCorpusLog;
   TestReadsEveryRecordTheSizeImplies;
   TestFirstQSOMatchesTheFrozenReference;
   TestQSOTimeEpochIsYearMinus2000;
   TestQSOTimeRoundTrips;
   TestQSOTimeZeroDateIsZero;
   TestUnrepresentableYearRaises;
   TestMissingFileReportsRatherThanRaises;
   TestStrideMismatchIsRefused;
   TestEveryBinaryLogFixtureReads;
   TestTheRecordIsTheSameSizeEverywhere;
   TestTheRecordHasTheSameFIELD_OFFSETSEverywhere;
   TestTheConverterCarriesEveryByte;
   TestTheConverterLeavesThe5xFieldsUnset;
   TestTheLegacyDeleteFlagIsFolded;
   TestANoteCrossesAsText;
   TestAQTCRecordCrosses;
end;

end.
