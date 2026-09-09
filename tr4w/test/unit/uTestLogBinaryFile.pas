unit uTestLogBinaryFile;

(* READING A BINARY TR4W LOG.

  These run against the REAL corpus fixtures -- 13 D7-written logs in
  test\corpus\<set>\log.trw, the same files the golden-master oracle exports.
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
      function CorpusLog(const aSet: string): string;
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
      procedure TestEverySetInTheCorpusReads;
      procedure TestTheRecordIsTheSameSizeEverywhere;
      procedure TestTheRecordHasTheSameFIELD_OFFSETSEverywhere;
   public
      procedure RunAllTests; override;
   end;

implementation

uses
   SysUtils, Classes, DateUtils, VC, uLogBinaryFile;

(* The suite runs from test\unit (ParamStr(0)), and the corpus is its sibling. *)
function TLogBinaryFileTests.CorpusLog(const aSet: string): string;
begin
   (* PathDelim, NOT HARDCODED BACKSLASHES. Found by RUNNING on Linux, which
     asked to open one file literally named "..\corpus\<set>\log.trw" and
     reported "No such file or directory". It compiles everywhere; it only
     fails where the separator is not a backslash. *)
   Result := ExtractFilePath(ParamStr(0)) + '..' + PathDelim + 'corpus' +
             PathDelim + aSet + PathDelim + 'log.trw';
end;

procedure TLogBinaryFileTests.TestOpensARealCorpusLog;
var
   r: TLogBinaryReader;
begin
   BeginTest('TestOpensARealCorpusLog');
   r := TLogBinaryReader.Create(CorpusLog('arktika_2026_ny4i'));
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
   r := TLogBinaryReader.Create(CorpusLog('arktika_2026_ny4i'));
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
   r := TLogBinaryReader.Create(CorpusLog('general_qso_2026_w1aw4'));
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
   r := TLogBinaryReader.Create(CorpusLog('no_such_contest_set'));
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
   fn := IncludeTrailingPathDelimiter(GetTempDir) + 'tr4w_stride_test.trw';
   if FileExists(fn) then
      begin
      DeleteFile(fn);
      end;

   src := TFileStream.Create(CorpusLog('arktika_2026_ny4i'), fmOpenRead or fmShareDenyNone);
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

procedure TLogBinaryFileTests.TestEverySetInTheCorpusReads;
const
   (* All thirteen. Named rather than enumerated from the directory, so a set
     that disappears fails here instead of quietly shrinking the coverage. *)
   SETS: array[0..12] of string = (
      'arktika_2026_ny4i', 'arrl_digi_2026_ny4i', 'arrl_dx_cw_2025_ny4i',
      'arrl_fd_2026_ny4i', 'arrl_ss_ssb_2024_w4ta', 'cqwpx_cw_2026_ny4i',
      'cqww_ssb_2025_ny4i', 'florida_qp_2026_ny4i', 'general_qso_2026_w1aw4',
      'iaru_hf_2026_ny4i', 'michigan_qp_2026_ny4i', 'na_sprint_cw_2026_ny4i',
      'winter_fd_2025_w4ta');
var
   i: integer;
   r: TLogBinaryReader;
   rec: ContestExchange;
   n: integer;
   good: integer;
begin
   BeginTest('TestEverySetInTheCorpusReads');

   for i := Low(SETS) to High(SETS) do
      begin
      r := TLogBinaryReader.Create(CorpusLog(SETS[i]));
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

(* THE ON-DISK FORMAT IS THE IN-MEMORY LAYOUT, SO ITS SIZE IS A CONTRACT.

  ContestExchange is a plain `record` -- not `packed` -- and TLogBinaryReader
  fills one with a single FStream.Read of SizeOf(aRecord) straight into it. The
  file format therefore IS whatever the compiler chose to lay the record out
  as, which is the DOS/Win32 idiom CLAUDE.md describes: the in-memory layout WAS
  the serialization.

  THAT IS FINE UNTIL THERE IS A SECOND ARCHITECTURE. Field offsets and total
  size come from the target's alignment rules, and nothing in this tree pins
  them -- there is no {$PACKRECORDS} directive anywhere. If aarch64 aligns one
  field differently from i386, the same bytes decode into different fields and
  the failure is SILENT: a QSO reads back with a plausible-looking wrong value.

  376 IS NOT A NUMBER CHOSEN HERE. It is what D7 wrote, what every corpus log
  on disk is made of, and what MainUnit's offset arithmetic assumes -- record k
  begins at (k + 1) * 376. Deployed logs have it; it cannot be changed without
  a format migration.

  SO THIS TEST IS A PORTABILITY GATE, not a tautology. On a platform where it
  fails, TR4W cannot read an existing log correctly and must not pretend to. *)
procedure TLogBinaryFileTests.TestTheRecordIsTheSameSizeEverywhere;
begin
   BeginTest('TestTheRecordIsTheSameSizeEverywhere');
   CheckEquals(376, SizeOf(ContestExchange),
               'ContestExchange is 376 bytes -- the size D7 wrote and every '
               + 'corpus log on disk is made of');
end;

(* SIZE IS NOT ENOUGH, AND THIS TEST EXISTS BECAUSE I LEARNED THAT THE HARD
  WAY (2026-09-08).

  TestTheRecordIsTheSameSizeEverywhere PASSES on aarch64-darwin -- 376 bytes,
  same as Windows and Linux -- and the record still decodes WRONG there. The
  same corpus QSO yields QTH.Continent = 1 on x86_64-linux and 86 on
  aarch64-darwin. 86 is ASCII 'V': the reader is picking up a neighbouring
  field's byte.

  TOTAL SIZE CAN MATCH WHILE OFFSETS DIFFER, because padding moves between
  fields and the sum comes out the same. A size check is therefore a test that
  gives CONFIDENCE WITHOUT COVERAGE, which is worse than no test -- it is what
  let me conclude the layout was safe.

  ContestExchange is a plain `record` with no {$PACKRECORDS} anywhere, and
  TLogBinaryReader block-reads a file straight into one, so the on-disk format
  is whatever the target's alignment rules produce.

  THE FIELDS BELOW ARE NOT ARBITRARY. Each sits after a differently-sized
  neighbour, which is where padding decisions show up; QTH is the nested record
  the live defect was found in. If this test fails on a platform, TR4W CANNOT
  IMPORT A LEGACY LOG THERE and must not pretend otherwise.

  NY4I, 2026-09-08: "Nothing should be reading from a binary file. It's the
  database or JSON. That's it." Exactly so -- which is why this guards the
  IMPORT path and nothing else. The binary reader exists to carry a D7 log into
  SQLite once. It still has to do that correctly. *)
procedure TLogBinaryFileTests.TestTheRecordHasTheSameFIELD_OFFSETSEverywhere;
var
   r: ContestExchange;
   base: PtrUInt;

   function Off(const aAddr): PtrUInt;
   begin
      Result := PtrUInt(@aAddr) - base;
   end;

begin
   BeginTest('TestTheRecordHasTheSameFIELD_OFFSETSEverywhere');
   base := PtrUInt(@r);

   CheckEquals(0,   Off(r.tSysTime),        'tSysTime is first');
   CheckEquals(6,   Off(r.Band),            'Band follows the 6-byte time');
   CheckEquals(7,   Off(r.Mode),            'Mode follows Band');
   CheckEquals(290, Off(r.id),              'id, a string[32], sits at 290');
   CheckEquals(376, SizeOf(ContestExchange), 'and the whole record is 376');

   (* INSIDE THE NESTED RECORD, which is where the live defect was: the
     four offsets above all match on aarch64-darwin and QTH.Continent
     still decodes as 86 there. Its own annotations claim
     6+1+1+7+1+14+2 = 32 bytes, so each field's offset is stated by the
     type and can be checked. *)
   CheckEquals(32, SizeOf(QTHRecord),        'QTHRecord is 32 bytes');
   (* Absolute, unlike the rest: QTH itself sits at 114 in the outer
     record, and every check below is RELATIVE to this field so the two
     questions -- where is QTH, and how is QTH laid out -- fail
     separately and say which. *)
   CheckEquals(114, Off(r.QTH.CountryID),    'QTH starts at 114');
   CheckEquals(6,  Off(r.QTH.Zone) - Off(r.QTH.CountryID),  'Zone at +6');
   CheckEquals(8,  Off(r.QTH.Prefix) - Off(r.QTH.CountryID),'Prefix at +8');
   CheckEquals(15, Off(r.QTH.Continent) - Off(r.QTH.CountryID),
               'Continent at +15');
   CheckEquals(16, Off(r.QTH.StandardCall) - Off(r.QTH.CountryID),
               'StandardCall at +16');
   CheckEquals(30, Off(r.QTH.Country) - Off(r.QTH.CountryID),
               'Country at +30');
   CheckEquals(1,  SizeOf(ContinentType),    'ContinentType is ONE byte');
end;

procedure TLogBinaryFileTests.RunAllTests;
begin
   TestOpensARealCorpusLog;
   TestReadsEveryRecordTheSizeImplies;
   TestFirstQSOMatchesTheFrozenReference;
   TestQSOTimeEpochIsYearMinus2000;
   TestQSOTimeRoundTrips;
   TestQSOTimeZeroDateIsZero;
   TestUnrepresentableYearRaises;
   TestMissingFileReportsRatherThanRaises;
   TestStrideMismatchIsRefused;
   TestEverySetInTheCorpusReads;
   TestTheRecordIsTheSameSizeEverywhere;
   TestTheRecordHasTheSameFIELD_OFFSETSEverywhere;
end;

end.
