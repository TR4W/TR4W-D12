unit uTestLogImport;

{ IMPORTING A BINARY LOG.

  The claim being tested is not "it runs" but "nothing is lost". Every one of
  the thirteen corpus fixtures is imported and its record count checked against
  what the file size implies -- so a record silently dropped by the importer
  fails here, on a real D7-written log, rather than on somebody's contest.

  THE FILTER TEST IS THE IMPORTANT ONE. GoodLookingQSO is what ExportToADIF
  emits; using it as an IMPORT filter would quietly discard deleted QSOs, skipped
  QSOs, QTC records and notes. That produces a smaller number that looks
  perfectly reasonable, which is the hardest kind of defect to notice. }

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
      function CorpusLog(const aSet: string): string;
   protected
      procedure TestImportsEveryRecordOfEveryCorpusLog;
      procedure TestImportKeepsWhatExportWouldFilterOut;
      procedure TestImportRefusesAnExistingTarget;
      procedure TestImportReportsAMissingSource;
      procedure TestImportedQSOsAreQueryable;
   public
      procedure RunAllTests; override;
   end;

implementation

uses
   SysUtils, sqldb, VC, uLogDatabase, uLogRepository, uLogBinaryFile, uLogImport;

const
   CORPUS_SETS: array[0..12] of string = (
      'arktika_2026_ny4i', 'arrl_digi_2026_ny4i', 'arrl_dx_cw_2025_ny4i',
      'arrl_fd_2026_ny4i', 'florida_qp_2026_ny4i', 'cqwpx_cw_2026_ny4i',
      'cqww_ssb_2025_ny4i', 'florida_qp_2026_ny4i', 'general_qso_2026_w1aw4',
      'iaru_hf_2026_ny4i', 'michigan_qp_2026_ny4i', 'na_sprint_cw_2026_ny4i',
      'winter_fd_2025_w4ta');

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

function TLogImportTests.CorpusLog(const aSet: string): string;
begin
   Result := ExtractFilePath(ParamStr(0)) + '..\corpus\' + aSet + '\log.trw';
end;

procedure TLogImportTests.TestImportsEveryRecordOfEveryCorpusLog;
var
   i: integer;
   fn: string;
   res: TLogImportResult;
   reader: TLogBinaryReader;
   expected: Int64;
begin
   BeginTest('TestImportsEveryRecordOfEveryCorpusLog');

   for i := Low(CORPUS_SETS) to High(CORPUS_SETS) do
      begin
      { What the file itself says it holds -- the independent number. }
      reader := TLogBinaryReader.Create(CorpusLog(CORPUS_SETS[i]));
      try
         CheckTrue(reader.Status = lbOK, CORPUS_SETS[i] + ': ' + reader.Message);
         expected := reader.ExpectedRecords;
      finally
         reader.Free;
      end;

      fn := TempDb('import_' + IntToStr(i) + '.db');
      Scrub(fn);

      res := ImportBinaryLog(CorpusLog(CORPUS_SETS[i]), fn);

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

   { A set where the two numbers actually differ, which most do not -- measured
     across all thirteen, only the two QSO parties do:

       florida_qp_2026_ny4i    5 records, 3 exportable
       michigan_qp_2026_ny4i   5 records, 4 exportable

     If they were equal this test would pass while proving nothing, so the
     difference is asserted FIRST. (The first version of this test used
     arrl_ss_ssb, where all 206 records are exportable, and it failed for
     exactly that reason -- which is the check doing its job.) }
   good := 0;
   total := 0;
   reader := TLogBinaryReader.Create(CorpusLog('florida_qp_2026_ny4i'));
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
   res := ImportBinaryLog(CorpusLog('florida_qp_2026_ny4i'), fn);

   { THE POINT. GoodLookingQSO is an EXPORT filter. Using it on import would
     drop deleted QSOs, skipped QSOs, QTC traffic and notes -- and would report
     a smaller number that looks entirely reasonable. }
   CheckTrue(res.Ok, 'it imports: ' + res.Message);
   CheckEquals(total, res.RecordsWritten,
               'the database holds EVERY record, not only the exportable ones');
   CheckTrue(res.RecordsWritten > good,
             'which is more than export would emit');

   { The report has to SAY so. Without this figure the summary reads
     "5 record(s): 5 QSO, 0 deleted" -- every number true, and the reader
     concludes the log is five good QSOs. }
   CheckEquals(good, res.Exportable,
               'and the result says how many would actually export');
   CheckEquals(3, res.Exportable, 'which is three');

   { WHY those two are not exportable, stated so the test still means something
     if the fixture is ever replaced: they are neither deleted nor skipped --
     they are a W4THY-style county-line PAIR (HIL and PIN) whose MODE was never
     recorded, so Mode = NoMode and GoodLookingQSO rejects them.

     Which also proves the mapper round-trips NoMode: it is stored as 'NON',
     ADIFModeString[NoMode], and read back as NoMode rather than as nothing. }
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

   res := ImportBinaryLog(CorpusLog('arktika_2026_ny4i'), fn);
   CheckTrue(res.Ok, 'the first import works');

   { Importing over somebody's log is the mistake worth refusing outright. }
   res := ImportBinaryLog(CorpusLog('arktika_2026_ny4i'), fn);
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

   res := ImportBinaryLog(CorpusLog('no_such_set'), fn);

   { Never raises: an operator importing a season of logs needs to know which
     one would not read and still get the rest. }
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
   res := ImportBinaryLog(CorpusLog('general_qso_2026_w1aw4'), fn);
   CheckTrue(res.Ok, 'it imports: ' + res.Message);

   db := TLogDatabase.Create;
   try
      db.Open(fn);

      { The dupe check is one indexed statement against these rows -- section 9a
        refuses a cache on the strength of it -- so proving the rows are
        actually queryable by callsign and band matters more than the count. }
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

procedure TLogImportTests.RunAllTests;
begin
   TestImportsEveryRecordOfEveryCorpusLog;
   TestImportKeepsWhatExportWouldFilterOut;
   TestImportRefusesAnExistingTarget;
   TestImportReportsAMissingSource;
   TestImportedQSOsAreQueryable;

   if (FDir <> '') and DirectoryExists(FDir) then
      begin
      RemoveDir(FDir);
      end;
end;

end.
