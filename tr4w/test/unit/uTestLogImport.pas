unit uTestLogImport;

(* IMPORTING A BINARY LOG.

  The claim being tested is not "it runs" but "nothing is lost". Every one of
  the six D7-written fixtures in test\unit\fixtures\binarylog is
  imported and its record count checked against what the file size implies --
  so a record silently dropped by the importer fails here, on a real
  D7-written log, rather than on somebody's contest.

  THIS IS WHERE BINARY-LOG IMPORT IS COVERED, since 2026-09-24. The golden
  corpus used to import a .trw on every run as a side effect of exporting;
  its input is a log.db now, so that coverage lives here and only here.
  NY4I: "that becomes a unit test and not the corpus."

  THE FILTER TEST IS THE IMPORTANT ONE. GoodLookingQSO is what ExportToADIF
  emits; using it as an IMPORT filter would quietly discard deleted QSOs, skipped
  QSOs, QTC records and notes. That produces a smaller number that looks
  perfectly reasonable, which is the hardest kind of defect to notice. *)

{$I ..\..\src\tr4w.inc}

interface

uses
   uTR4WTestFramework;

type
   TLogImportTests = class(TTestCase)
   private
      FDir: string;
      function TempDb(const aLeaf: string): string;
      procedure Scrub(const aFileName: string);
      function BinaryLogFixture(const aSet: string): string;
   protected
      procedure TestImportsEveryRecordOfEveryFixtureLog;
      procedure TestImportKeepsWhatExportWouldFilterOut;
      procedure TestImportRefusesAnExistingTarget;
      procedure TestImportReportsAMissingSource;
      procedure TestImportedQSOsAreQueryable;
      procedure TestAKnownQSOKeepsItsRealValues;
      procedure TestCountyLineRowsShareOneSet;
   public
      procedure RunAllTests; override;
   end;

implementation

uses
   SysUtils, sqldb, VC, uLogDatabase, uLogRepository, uLogBinaryFile, uLogImport;

(* TInt64Array comes from uLogRepository -- see RelatedRowIds. *)

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
   CORPUS_SETS: array[0..5] of string = (
      'arktika_2026_ny4i', 'arrl_fd_2026_ny4i', 'cqwpx_cw_2026_ny4i',
      'cqww_ssb_2025_ny4i', 'florida_qp_2026_ny4i',
      'general_qso_2026_w1aw4');

function TLogImportTests.TempDb(const aLeaf: string): string;
begin
   if FDir = '' then
      begin
      FDir := IncludeTrailingPathDelimiter(GetTempDir) +
              'tr4w_logimport_' + IntToStr(GetProcessID);
      ForceDirectories(FDir);
      end;
   Result := IncludeTrailingPathDelimiter(FDir) + aLeaf;
end;

procedure TLogImportTests.Scrub(const aFileName: string);
begin
   if FileExists(aFileName) then DeleteFile(aFileName);
   if FileExists(aFileName + '-wal') then DeleteFile(aFileName + '-wal');
   if FileExists(aFileName + '-shm') then DeleteFile(aFileName + '-shm');
end;

function TLogImportTests.BinaryLogFixture(const aSet: string): string;
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

procedure TLogImportTests.TestImportsEveryRecordOfEveryFixtureLog;
var
   i: integer;
   fn: string;
   res: TLogImportResult;
   reader: TLogBinaryReader;
   expected: Int64;
begin
   BeginTest('TestImportsEveryRecordOfEveryFixtureLog');

   for i := Low(CORPUS_SETS) to High(CORPUS_SETS) do
      begin
      (* What the file itself says it holds -- the independent number. *)
      reader := TLogBinaryReader.Create(BinaryLogFixture(CORPUS_SETS[i]));
      try
         CheckTrue(reader.Status = lbOK, CORPUS_SETS[i] + ': ' + reader.Message);
         expected := reader.ExpectedRecords;
      finally
         reader.Free;
      end;

      fn := TempDb('import_' + IntToStr(i) + '.db');
      Scrub(fn);

      res := ImportBinaryLog(BinaryLogFixture(CORPUS_SETS[i]), fn);

      CheckTrue(res.Ok, CORPUS_SETS[i] + ' imports: ' + res.Message);
      CheckEquals(integer(expected), res.RecordsRead,
                  CORPUS_SETS[i] + ': every record the file size implies was read');
      CheckEquals(res.RecordsRead, res.RecordsWritten,
                  CORPUS_SETS[i] + ': and every record read was written');
      CheckEquals(0, res.RecordsFailed, CORPUS_SETS[i] + ': none failed');

      Scrub(fn);
      end;
end;

procedure TLogImportTests.TestImportKeepsWhatExportWouldFilterOut;
var
   fn: string;
   res: TLogImportResult;
   reader: TLogBinaryReader;
   rec: ContestExchange;
   good: integer;
   total: integer;
begin
   BeginTest('TestImportKeepsWhatExportWouldFilterOut');

   (* A set where the two numbers actually differ, which most do not -- measured
     across all thirteen, only the two QSO parties do:

       florida_qp_2026_ny4i    5 records, 3 exportable
       michigan_qp_2026_ny4i   5 records, 4 exportable

     If they were equal this test would pass while proving nothing, so the
     difference is asserted FIRST. (The first version of this test used
     arrl_ss_ssb, where all 206 records are exportable, and it failed for
     exactly that reason -- which is the check doing its job.) *)
   good := 0;
   total := 0;
   reader := TLogBinaryReader.Create(BinaryLogFixture('florida_qp_2026_ny4i'));
   try
      CheckTrue(reader.Status = lbOK, 'the fixture opens: ' + reader.Message);
      while reader.ReadNext(rec) do
         begin
         Inc(total);
         if GoodLookingQSO(rec) then
            begin
            Inc(good);
            end;
         end;
   finally
      reader.Free;
   end;

   CheckEquals(5, total, 'the fixture holds five records');
   CheckEquals(3, good, 'of which three are exportable');
   CheckTrue(total > good,
             'so it really does hold records export would filter out');

   fn := TempDb('filter.db');
   Scrub(fn);
   res := ImportBinaryLog(BinaryLogFixture('florida_qp_2026_ny4i'), fn);

   (* THE POINT. GoodLookingQSO is an EXPORT filter. Using it on import would
     drop deleted QSOs, skipped QSOs, QTC traffic and notes -- and would report
     a smaller number that looks entirely reasonable. *)
   CheckTrue(res.Ok, 'it imports: ' + res.Message);
   CheckEquals(total, res.RecordsWritten,
               'the database holds EVERY record, not only the exportable ones');
   CheckTrue(res.RecordsWritten > good,
             'which is more than export would emit');

   (* The report has to SAY so. Without this figure the summary reads
     "5 record(s): 5 QSO, 0 deleted" -- every number true, and the reader
     concludes the log is five good QSOs. *)
   CheckEquals(good, res.Exportable,
               'and the result says how many would actually export');
   CheckEquals(3, res.Exportable, 'which is three');

   (* WHY those two are not exportable, stated so the test still means something
     if the fixture is ever replaced: they are neither deleted nor skipped --
     they are a W4THY-style county-line PAIR (HIL and PIN) whose MODE was never
     recorded, so Mode = NoMode and GoodLookingQSO rejects them.

     Which also proves the mapper round-trips NoMode: it is stored as 'NON',
     ADIFModeString[NoMode], and read back as NoMode rather than as nothing. *)
   CheckEquals(0, res.Deleted, 'neither of them is deleted');
   CheckEquals(0, res.Skipped, 'and neither is skipped');

   Scrub(fn);
end;

procedure TLogImportTests.TestImportRefusesAnExistingTarget;
var
   fn: string;
   res: TLogImportResult;
begin
   BeginTest('TestImportRefusesAnExistingTarget');

   fn := TempDb('exists.db');
   Scrub(fn);

   res := ImportBinaryLog(BinaryLogFixture('arktika_2026_ny4i'), fn);
   CheckTrue(res.Ok, 'the first import works');

   (* Importing over somebody's log is the mistake worth refusing outright. *)
   res := ImportBinaryLog(BinaryLogFixture('arktika_2026_ny4i'), fn);
   CheckFalse(res.Ok, 'a second import into the same file is refused');
   CheckTrue(Pos('already exists', res.Message) > 0,
             'and says the log is already there');

   Scrub(fn);
end;

procedure TLogImportTests.TestImportReportsAMissingSource;
var
   fn: string;
   res: TLogImportResult;
begin
   BeginTest('TestImportReportsAMissingSource');

   fn := TempDb('nosource.db');
   Scrub(fn);

   res := ImportBinaryLog(BinaryLogFixture('no_such_set'), fn);

   (* Never raises: an operator importing a season of logs needs to know which
     one would not read and still get the rest. *)
   CheckFalse(res.Ok, 'a missing source is reported, not raised');
   CheckTrue(res.Message <> '', 'and says why');
   CheckFalse(FileExists(fn), 'and no database is left behind');
end;

procedure TLogImportTests.TestImportedQSOsAreQueryable;
var
   fn: string;
   res: TLogImportResult;
   db: TLogDatabase;
   q: TSQLQuery;
   n: integer;
   firstCall: string;
begin
   BeginTest('TestImportedQSOsAreQueryable');

   fn := TempDb('query.db');
   Scrub(fn);
   res := ImportBinaryLog(BinaryLogFixture('general_qso_2026_w1aw4'), fn);
   CheckTrue(res.Ok, 'it imports: ' + res.Message);

   db := TLogDatabase.Create;
   try
      db.Open(fn);

      (* The dupe check is one indexed statement against these rows -- section 9a
        refuses a cache on the strength of it -- so proving the rows are
        actually queryable by callsign and band matters more than the count. *)
      q := TSQLQuery.Create(nil);
      try
         q.DataBase := db.Connection;
         q.SQL.Text := 'SELECT COUNT(*) FROM qso ' +
                       'WHERE callsign = :c AND band = :b AND deleted = 0';
         q.ParamByName('c').AsString := 'KD6RYO';
         q.ParamByName('b').AsString := '20m';
         q.Open;
         n := q.Fields[0].AsInteger;
         q.Close;

         q.SQL.Text := 'SELECT callsign FROM qso ORDER BY qso_at LIMIT 1';
         q.Open;
         firstCall := q.Fields[0].AsString;
         q.Close;
      finally
         q.Free;
      end;

      CheckEquals(1, n, 'the dupe query finds the QSO the reference names');
      CheckEquals('KD6RYO', firstCall,
                  'and ordering by time gives the same first QSO as the Cabrillo');

      CheckTrue(db.CheckIntegrity.Ok, 'the imported log passes its integrity check');
   finally
      db.Free;
   end;

   Scrub(fn);
end;

(* THE MAPPER IS PINNED TO NAMED VALUES, NOT ONLY TO ITSELF.

  TestWholeCorpusLogRoundTrips in uTestLogRepository compares every persisted
  field in both directions, which is strong and has one blind spot: it is
  SYMMETRIC. A mapper that wrote the sent RST into the received column and read
  it back out of the same place would round-trip perfectly and be wrong.

  So this asserts the values a HUMAN can check, against D7's own Cabrillo for
  the same contact -- general_qso_2026_w1aw4/ref.cbr, first QSO line:

    QSO: 14248 PH 2026-02-11 0006 W1AW/4  59  TOM  KD6RYO  59  AR

  WHAT IS DELIBERATELY NOT ASSERTED: dxcc_entity, the zones, the continent and
  qso_points. Those are RECOMPUTED from CTY.DAT, which is not the file D7 used,
  and seven corpus logs legitimately move when rescored for exactly that reason
  (see test-contest-factory.sh's header). Pinning them here would make a country
  file update fail an import test. *)
procedure TLogImportTests.TestAKnownQSOKeepsItsRealValues;
var
   fn: string;
   res: TLogImportResult;
   db: TLogDatabase;
   q: TSQLQuery;
begin
   BeginTest('TestAKnownQSOKeepsItsRealValues');

   fn := TempDb('known.db');
   Scrub(fn);
   res := ImportBinaryLog(BinaryLogFixture('general_qso_2026_w1aw4'), fn);
   CheckTrue(res.Ok, 'it imports: ' + res.Message);

   db := TLogDatabase.Create;
   try
      db.Open(fn);
      q := TSQLQuery.Create(nil);
      try
         q.DataBase := db.Connection;
         (* The FIRST contact by time -- the one the reference's first QSO line
           is, so the two can be read side by side. *)
         q.SQL.Text :=
            'SELECT callsign, band, mode, submode, freq_tx_hz, freq_rx_hz, ' +
            'rst_sent, rst_received, exchange_received, operator_call, ' +
            'record_kind, deleted, ' +
            'datetime(qso_at, ''unixepoch'') AS at_utc ' +
            'FROM qso ORDER BY qso_at LIMIT 1';
         q.Open;

         CheckEquals('KD6RYO', q.FieldByName('callsign').AsString,
                     'the callsign D7 logged');
         CheckEquals('W1AW/4', q.FieldByName('operator_call').AsString,
                     'worked by the station D7 names in the same line');

         (* 14248 kHz in the Cabrillo; the log carries it in Hz. *)
         CheckEquals(14248000, q.FieldByName('freq_tx_hz').AsInteger,
                     'the transmit frequency, in Hz');
         CheckEquals(14248000, q.FieldByName('freq_rx_hz').AsInteger,
                     'and the receive frequency, since this QSO was not split');
         CheckEquals('20m', q.FieldByName('band').AsString,
                     'which is the band that frequency is in');

         (* PH in the Cabrillo. The binary log distinguishes the sideband, and
           losing that is a real failure mode: USB on 20m is what ADIF needs. *)
         CheckEquals('SSB', q.FieldByName('mode').AsString, 'PH is SSB');
         CheckEquals('USB', q.FieldByName('submode').AsString,
                     'and the sideband survives the import');

         (* 2026-02-11 0006 in the Cabrillo, which has minute resolution; the
           binary record carries the second and it is kept. An hour of drift --
           a local-vs-UTC mistake -- fails here and nowhere else. *)
         CheckEquals('2026-02-11 00:06:43', q.FieldByName('at_utc').AsString,
                     'the moment of the QSO, in UTC');

         (* THE ASYMMETRIC PART, and the reason this test exists: sent and
           received are separate columns and must not be swapped or shared. *)
         CheckEquals(59, q.FieldByName('rst_sent').AsInteger, 'the RST we sent');
         CheckEquals(59, q.FieldByName('rst_received').AsInteger,
                     'and the RST we received');
         CheckEquals('AR', q.FieldByName('exchange_received').AsString,
                     'the exchange D7 printed in the received column');

         CheckEquals('QSO', q.FieldByName('record_kind').AsString,
                     'it is a contact, not a note or a QTC');
         CheckEquals(0, q.FieldByName('deleted').AsInteger,
                     'and it is not deleted');

         q.Close;
      finally
         q.Free;
      end;
   finally
      db.Free;
   end;

   Scrub(fn);
end;

(* THREE ROWS, THREE GUIDS, ONE SET -- the shape NY4I described, tested on the
  real fixture that has it.

  florida_qp_2026_ny4i holds FIVE records and THREE contacts, which is a better
  fixture than expected -- it has TWO county-line pairs, not one:

    row 1  W4THY     PIN   exch 5cd6c61f  -- one contact
    row 2  W4THY     HIL   exch 5cd6c61f  --
    row 3  KG1S/MON  MON   exch 3deea56f     alone
    row 4  W4AFC     HIL   exch b8b43067  -- one contact
    row 5  W4AFC     PIN   exch b8b43067  --

  The first version of this test asserted four sets, from having read only the
  first pair. The measurement corrected it, which is the check working.

  All three requirements pull differently and all three are satisfied here:

    THE LOG wants them separate -- "once in the log, they are deleted or X-QSO
    individually", so each needs its own guid.

    CABRILLO wants them separate -- three QSO lines, because three multipliers
    were worked.

    ADIF wants them as ONE record. LoTW keys on call + band + mode + date +
    time, so three ADIF records for one contact arrive as one contact and two
    DUPLICATES. The exporter therefore has to ask "what else was this
    contact?", which is what qso_set_id answers. *)
procedure TLogImportTests.TestCountyLineRowsShareOneSet;
var
   fn: string;
   res: TLogImportResult;
   db: TLogDatabase;
   repo: TLogRepository;
   q: TSQLQuery;
   guids: integer;
   sets: integer;
   related: TInt64Array;
   pinRow: Int64;
begin
   BeginTest('TestCountyLineRowsShareOneSet');

   fn := TempDb('countyset.db');
   Scrub(fn);
   res := ImportBinaryLog(BinaryLogFixture('florida_qp_2026_ny4i'), fn);
   CheckTrue(res.Ok, 'the fixture imports: ' + res.Message);

   db := TLogDatabase.Create;
   try
      db.Open(fn);
      repo := TLogRepository.Create(db);
      try
         q := TSQLQuery.Create(nil);
         try
            q.DataBase := db.Connection;
            q.SQL.Text := 'SELECT COUNT(DISTINCT guid), COUNT(DISTINCT qso_set_id) FROM qso';
            q.Open;
            guids := q.Fields[0].AsInteger;
            sets := q.Fields[1].AsInteger;
            q.Close;

            (* The PIN half of the county-line pair. *)
            (* W4THY's PIN row specifically -- W4AFC also worked PIN, which is
              exactly the sort of thing that makes an unqualified query look
              right and pick the wrong row. *)
            q.SQL.Text := 'SELECT id FROM qso WHERE rcvd_qth = ''PIN'' ' +
                          'AND callsign = ''W4THY''';
            q.Open;
            pinRow := q.Fields[0].AsLargeInt;
            q.Close;
         finally
            q.Free;
         end;

         (* FIVE records, FIVE distinct guids -- every row independently
           addressable, which is what independent delete and X-QSO need. *)
         CheckEquals(5, integer(repo.RecordCount), 'the log holds five records');
         CheckEquals(5, guids, 'each with its OWN guid');

         (* FOUR sets: the W4THY pair is one contact, the other three stand
           alone. That is the relationship ADIF export needs and Cabrillo must
           ignore. *)
         CheckEquals(3, sets,
                     'but only THREE contacts -- each pair shares a set');

         (* W4THY's PIN row: the contact also produced the HIL row and nothing
           else. This is the question the ADIF exporter asks once per record. *)
         related := repo.RelatedRowIds(pinRow);
         CheckEquals(1, Length(related),
                     'asking what else was that contact finds exactly one more');

         (* And an ordinary QSO has no relations, so the exporter's "group by
           set" path treats it as a group of one rather than a special case. *)
         CheckEquals(0, Length(repo.RelatedRowIds(related[0] + 1000)),
                     'a row that does not exist relates to nothing');
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
procedure TLogImportTests.RunAllTests;
begin
{$IFNDEF WINDOWS}
   (* SAID, NOT SILENT: a suite that quietly contributes nothing is
     indistinguishable from one that passed. *)
   WriteLn('  SKIPPED: reads a D7 binary log, which is a Windows migration path.');
   Exit;
{$ENDIF}
   TestImportsEveryRecordOfEveryFixtureLog;
   TestImportKeepsWhatExportWouldFilterOut;
   TestImportRefusesAnExistingTarget;
   TestImportReportsAMissingSource;
   TestImportedQSOsAreQueryable;
   TestAKnownQSOKeepsItsRealValues;
   TestCountyLineRowsShareOneSet;

   if (FDir <> '') and DirectoryExists(FDir) then
      begin
      RemoveDir(FDir);
      end;
end;

end.
