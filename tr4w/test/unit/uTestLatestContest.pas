unit uTestLatestContest;
{$I ..\..\src\tr4w.inc}

(* THE NEW CONTEST DIALOG'S "LAST CONTEST" BUTTON SAYS WHICH CONTEST AND WHICH
  YEAR -- NY4I, 2026-10-19.

  Two halves, both without a form:

  uLogFileFacts -- the log is read WITHOUT BEING ADOPTED. Over a real log
  made through TLogDatabase and TLogRepository: the facts come back, the year
  is the declared start, else the first QSO, else the day the log was made,
  and the file is byte-for-byte the same afterwards, with no sidecar and no
  lock left. An old .cfg, a missing file, a damaged database and an unknown
  contest token each fall back without raising.

  uLatestContest.FitLatestCaption -- what is given up when the button is too
  small, in order, against a fake measurer that counts characters and lines:
  the file line from its middle, then the file line, then the END of the
  contest name with its year kept. The label is never cut. *)

interface

uses
   SysUtils, Classes, DateUtils,
   uTR4WTestFramework,
   VC,
   uContestNames,
   uContestRegistry,
   uLogDatabase,
   uLogRepository,
   uLogFileFacts,
   uLatestContest,
   uAppStrings;

type
   TLatestContestTests = class(TTestCase)
   private
      FDir: string;
      function TempName(const aLeaf: string): string;
      procedure Scrub(const aFileName: string);
      (* A real log of CQ WW SSB, declared by NY4I, closed. *)
      procedure MakeLog(const aFileName: string);
      procedure Exec(const aFileName, aSQL: string);
      function FileBytes(const aFileName: string): TBytes;
   protected
      procedure Test_ARealLogDescribesItself;
      procedure Test_TheDeclaredStartBeatsTheFirstQSO;
      procedure Test_ALogWithNoQSOsIsDatedByItsCreation;
      procedure Test_ThePeekWritesNothingAndHoldsNothing;
      procedure Test_ALogOpenElsewhereStillDescribesItself;
      procedure Test_TheImmutableURIEscapesThePath;
      procedure Test_TheImmutableURINamesAUNCPath;
      procedure Test_TheImmutableURIKeepsAUnixBackslash;
      procedure Test_AnAwkwardPathIsPeekedImmutable;
      procedure Test_AUNCPathIsPeekedImmutable;
      procedure Test_EverySidecarIsSeen;
      procedure Test_ARollbackLogMidWriteIsNotReadImmutable;
      procedure Test_AnOldCfgFallsBackToThePath;
      procedure Test_AMissingFileFallsBack;
      procedure Test_ADamagedDatabaseFallsBackWithoutRaising;
      procedure Test_AnUnknownTokenShowsTheStoredName;
      procedure Test_ALegacyTokenShowsItsContest;

      procedure Test_EverythingFitsInThreeLines;
      procedure Test_TheFileLineIsCutFromItsMiddleFirst;
      procedure Test_TheFileLineIsDroppedBeforeTheContest;
      procedure Test_TheContestNameIsCutAtItsEndKeepingTheYear;
      procedure Test_AnUndescribedFileKeepsItsPath;
      procedure Test_NoYearShowsTheBareName;
   public
      destructor Destroy; override;
      procedure RunAllTests; override;
   end;

(* SHARED WITH uTestNewContestForm, whose existing-log grid is filled from the
  same description: one way to make a test log, not two. *)

(* A REAL, CLOSED TR4W log of aContest at aFileName, declared by aCall ('' leaves
  my_call empty). Anything already at aFileName is scrubbed first. *)
procedure MakeTestContestLog(const aFileName: string; aContest: TContestHandle;
                             const aCall: string);

(* A FILE THAT PASSES THE BYTE CHECK for a TR4W log and fails in SQLite: the
  magic, a zero application id, then rubbish. *)
procedure WriteDamagedTestLog(const aFileName: string);

(* aFileName and its -wal and -shm, gone. *)
procedure ScrubTestLog(const aFileName: string);

(* A LOG TAKEN BACK TO AN OLDER SCHEMA, ON DISK -- R4, 2026-10-23. Opened at
  the current schema, then EVERY addition made after aToVersion is removed
  and user_version is stamped aToVersion:

    v4  message.edited
    v3  the LOG_V3_QSO_COLUMNS, from index aFirstV3Dropped on (pass
        Low(LOG_V3_QSO_COLUMNS) for a genuine schema-2 file; a later index
        keeps the first few, for a half-repaired one)
    v2  the session_state table

  THE SHARED ONE, because each suite had its own and each dropped only the
  addition it was about: a "schema-2" fixture still had message.edited, and
  the "schema-1" one still had every v3 column. A fixture that keeps a later
  addition cannot test a migration that has to make it. ALTER TABLE DROP
  COLUMN needs SQLite 3.35; the shipped library is newer. *)
procedure DowngradeTestLog(const aFileName: string; aToVersion: integer;
                           aFirstV3Dropped: integer);

(* Does aTable have a column aColumn, asked of an open log -- the question
  every migration test asks of the file before and after. *)
function TestLogHasColumn(aDb: TLogDatabase; const aTable, aColumn: string): boolean;

implementation

uses
   sqldb,        (* TSQLQuery -- TestLogHasColumn *)
   uLogSchema;   (* LOG_V3_QSO_COLUMNS and LOG_V4_MESSAGE_COLUMN -- DowngradeTestLog *)

function TestLogHasColumn(aDb: TLogDatabase; const aTable, aColumn: string): boolean;
var
   q: TSQLQuery;
begin
   q := TSQLQuery.Create(nil);
   try
      q.DataBase := aDb.Connection;
      q.UsePrimaryKeyAsKey := False;
      q.SQL.Text := 'SELECT name FROM pragma_table_info(''' + aTable +
                    ''') WHERE name = ''' + aColumn + '''';
      q.Open;
      Result := not q.EOF;
      q.Close;
   finally
      q.Free;
   end;
end;

procedure ScrubTestLog(const aFileName: string);
begin
   if FileExists(aFileName) then
      begin
      DeleteFile(aFileName);
      end;
   if FileExists(aFileName + '-wal') then
      begin
      DeleteFile(aFileName + '-wal');
      end;
   if FileExists(aFileName + '-shm') then
      begin
      DeleteFile(aFileName + '-shm');
      end;
end;

procedure DowngradeTestLog(const aFileName: string; aToVersion: integer;
                           aFirstV3Dropped: integer);
var
   db: TLogDatabase;
   i: integer;
begin
   db := TLogDatabase.Create;
   try
      db.Open(aFileName);
      if aToVersion < 4 then
         begin
         db.Connection.ExecuteDirect(UTF8Encode('ALTER TABLE message DROP COLUMN ' +
                                                string(LOG_V4_MESSAGE_COLUMN.Name)));
         end;
      if aToVersion < 3 then
         begin
         for i := aFirstV3Dropped to High(LOG_V3_QSO_COLUMNS) do
            begin
            db.Connection.ExecuteDirect(UTF8Encode('ALTER TABLE qso DROP COLUMN ' +
                                                   string(LOG_V3_QSO_COLUMNS[i].Name)));
            end;
         end;
      if aToVersion < 2 then
         begin
         db.Connection.ExecuteDirect('DROP TABLE session_state');
         end;
      (* user_version IS settable inside a transaction, so the stamp rides
        with the drops and there is one commit. *)
      db.Connection.ExecuteDirect(UTF8Encode('PRAGMA user_version = ' +
                                             IntToStr(aToVersion)));
      db.Transaction.Commit;
   finally
      db.Free;
   end;
end;

procedure MakeTestContestLog(const aFileName: string; aContest: TContestHandle;
                             const aCall: string);
var
   db: TLogDatabase;
   repo: TLogRepository;
begin
   ScrubTestLog(aFileName);
   db := TLogDatabase.Create;
   try
      db.CreateNew(aFileName);
      repo := TLogRepository.Create(db);
      try
         repo.SetContest(aContest);
         repo.Commit;
      finally
         repo.Free;
      end;
      if aCall <> '' then
         begin
         db.Connection.ExecuteDirect(AnsiString('UPDATE contest SET my_call = ''' +
                                                aCall + ''' WHERE id = 1'));
         db.Transaction.Commit;
         end;
   finally
      db.Free;
   end;
end;

procedure WriteDamagedTestLog(const aFileName: string);
var
   f: TFileStream;
   junk: array[0..299] of byte;
   i: integer;
const
   MAGIC: AnsiString = 'SQLite format 3';
begin
   ScrubTestLog(aFileName);
   for i := Low(junk) to High(junk) do
      begin
      junk[i] := (i * 37) and $FF;
      end;
   for i := 1 to Length(MAGIC) do
      begin
      junk[i - 1] := Ord(MAGIC[i]);
      end;
   junk[15] := 0;
   for i := 68 to 71 do
      begin
      junk[i] := 0;
      end;
   f := TFileStream.Create(AnsiString(aFileName), fmCreate);
   try
      f.WriteBuffer(junk, SizeOf(junk));
   finally
      f.Free;
   end;
end;

type
   (* A BUTTON THAT HOLDS MaxLines lines of MaxWidth characters. *)
   TFakeButton = class
   public
      MaxLines: integer;
      MaxWidth: integer;
      function Fits(const aCaption: string): boolean;
   end;

function TFakeButton.Fits(const aCaption: string): boolean;
var
   lines: TStringList;
   i: integer;
begin
   lines := TStringList.Create;
   try
      lines.Text := aCaption;
      Result := lines.Count <= MaxLines;
      for i := 0 to lines.Count - 1 do
         begin
         if Length(lines[i]) > MaxWidth then
            begin
            Result := False;
            end;
         end;
   finally
      lines.Free;
   end;
end;

const
   LABEL_TEXT = 'Last Contest, Alt+&A:';
   CRLF = #13#10;

function UnixOf(aYear, aMonth, aDay: word): Int64;
begin
   Result := DateTimeToUnix(EncodeDate(aYear, aMonth, aDay));
end;

function CQWW: TContestHandle;
begin
   Result := ContestFromName('CQ-WW-SSB');
end;

(* ---------------------------------------------------------------------------
  fixture
  --------------------------------------------------------------------------- *)

destructor TLatestContestTests.Destroy;
begin
   if FDir <> '' then
      begin
      RemoveDir(FDir);
      end;
   inherited Destroy;
end;

function TLatestContestTests.TempName(const aLeaf: string): string;
begin
   if FDir = '' then
      begin
      FDir := IncludeTrailingPathDelimiter(GetTempDir) +
              'tr4w_latestcontest_' + IntToStr(GetProcessID);
      ForceDirectories(FDir);
      end;
   Result := IncludeTrailingPathDelimiter(FDir) + aLeaf;
end;

procedure TLatestContestTests.Scrub(const aFileName: string);
begin
   ScrubTestLog(aFileName);
end;

procedure TLatestContestTests.MakeLog(const aFileName: string);
begin
   MakeTestContestLog(aFileName, CQWW, 'NY4I');
end;

procedure TLatestContestTests.Exec(const aFileName, aSQL: string);
var
   db: TLogDatabase;
begin
   db := TLogDatabase.Create;
   try
      db.Open(aFileName);
      db.Connection.ExecuteDirect(AnsiString(aSQL));
      db.Transaction.Commit;
   finally
      db.Free;
   end;
end;

function TLatestContestTests.FileBytes(const aFileName: string): TBytes;
var
   f: TFileStream;
begin
   Result := nil;
   f := TFileStream.Create(AnsiString(aFileName), fmOpenRead or fmShareDenyNone);
   try
      SetLength(Result, f.Size);
      if f.Size > 0 then
         begin
         f.ReadBuffer(Result[0], f.Size);
         end;
   finally
      f.Free;
   end;
end;

function InsertQSOAt(aWhen: Int64): string;
begin
   Result := 'INSERT INTO qso (guid, qso_set_id, qso_at, callsign, freq_tx_hz, ' +
             'freq_rx_hz, band, mode) VALUES (''g' + IntToStr(aWhen) + ''', ''s' +
             IntToStr(aWhen) + ''', ' + IntToStr(aWhen) +
             ', ''K1AR'', 14200000, 14200000, ''20M'', ''SSB'')';
end;

(* ---------------------------------------------------------------------------
  the log, read without being adopted
  --------------------------------------------------------------------------- *)

procedure TLatestContestTests.Test_ARealLogDescribesItself;
var
   fn, why: string;
   facts: TLogFileFacts;
   latest: TLatestContest;
begin
   BeginTest('Test_ARealLogDescribesItself');

   CheckTrue(CQWW <> NoContest, 'CQ-WW-SSB is a registered contest');
   fn := TempName('cqww ssb 2024 ny4i.db');
   MakeLog(fn);
   (* Made in 2026, run in 2024: an IMPORTED log. The year must be the run's. *)
   Exec(fn, 'UPDATE contest SET created_at = ' + IntToStr(UnixOf(2026, 10, 19)));
   Exec(fn, InsertQSOAt(UnixOf(2024, 10, 26)));
   Exec(fn, InsertQSOAt(UnixOf(2024, 10, 27)));

   facts := ReadLogFileFacts(fn, why);
   try
      CheckTrue(facts <> nil, 'a real log describes itself, got "' + why + '"');
      if facts <> nil then
         begin
         CheckEquals(ContestId(CQWW), facts.ContestToken, 'the stored token');
         CheckEquals('NY4I', facts.MyCall, 'the declared call');
         CheckEquals(2024, facts.ContestYear,
                     'the first QSO dates an imported log, not its creation');
         end;
   finally
      facts.Free;
   end;

   latest := TLatestContest.Create(fn);
   try
      CheckTrue(latest.Described, 'described: ' + latest.Why);
      CheckEquals(ContestIdentity(CQWW).DisplayName, latest.ContestName,
                  'the REGISTRY''s display name, not the stored friendly name');
      CheckEquals(2024, latest.Year, 'the year');
      CheckEquals('NY4I', latest.Call, 'the declared call, on its own -- the grid''s Call column');
      CheckEquals(Format(SLatestContestDetail, ['NY4I', 'cqww ssb 2024 ny4i.db']),
                  latest.Detail, 'the call and the file name, no directory');
      CheckEquals(fn, latest.FileName, 'the full path, for the hint');
      CheckTrue(Pos(FDir, latest.Detail) = 0, 'no directory in the detail');
   finally
      latest.Free;
   end;

   Scrub(fn);
end;

procedure TLatestContestTests.Test_TheDeclaredStartBeatsTheFirstQSO;
var
   fn, why: string;
   facts: TLogFileFacts;
begin
   BeginTest('Test_TheDeclaredStartBeatsTheFirstQSO');

   fn := TempName('start.db');
   MakeLog(fn);
   Exec(fn, InsertQSOAt(UnixOf(2024, 10, 26)));
   Exec(fn, 'UPDATE contest SET start_time = ' + IntToStr(UnixOf(2023, 11, 25)));

   facts := ReadLogFileFacts(fn, why);
   try
      CheckTrue(facts <> nil, 'described: ' + why);
      if facts <> nil then
         begin
         CheckEquals(2023, facts.ContestYear, 'start_time is asked first');
         end;
   finally
      facts.Free;
   end;
   Scrub(fn);
end;

procedure TLatestContestTests.Test_ALogWithNoQSOsIsDatedByItsCreation;
var
   fn, why: string;
   facts: TLogFileFacts;
begin
   BeginTest('Test_ALogWithNoQSOsIsDatedByItsCreation');

   fn := TempName('empty.db');
   MakeLog(fn);
   Exec(fn, 'UPDATE contest SET created_at = ' + IntToStr(UnixOf(2025, 3, 1)));

   facts := ReadLogFileFacts(fn, why);
   try
      CheckTrue(facts <> nil, 'described: ' + why);
      if facts <> nil then
         begin
         CheckEquals(2025, facts.ContestYear, 'created_at, with nothing else');
         end;
   finally
      facts.Free;
   end;

   (* And nothing at all: no year, rather than 1970. *)
   Exec(fn, 'UPDATE contest SET created_at = 0');
   facts := ReadLogFileFacts(fn, why);
   try
      CheckTrue(facts <> nil, 'described: ' + why);
      if facts <> nil then
         begin
         CheckEquals(0, facts.ContestYear, 'no date anywhere is year 0');
         end;
   finally
      facts.Free;
   end;
   Scrub(fn);
end;

procedure TLatestContestTests.Test_ThePeekWritesNothingAndHoldsNothing;
var
   fn, why: string;
   before, after: TBytes;
   facts: TLogFileFacts;
   db: TLogDatabase;
begin
   BeginTest('Test_ThePeekWritesNothingAndHoldsNothing');

   fn := TempName('older.db');
   MakeLog(fn);
   (* AN OLDER LOG: user_version 2. Open would migrate it to 3 -- a peek must
     not. Set with a raw pragma, after Open has done its own migrating. *)
   db := TLogDatabase.Create;
   try
      db.Open(fn);
      db.Connection.ExecutePragma('PRAGMA user_version = 2');
   finally
      db.Free;
   end;
   CheckFalse(FileExists(fn + '-wal'), 'precondition: no -wal after a clean close');

   before := FileBytes(fn);
   facts := ReadLogFileFacts(fn, why);
   try
      CheckTrue(facts <> nil, 'an older log still describes itself: ' + why);
   finally
      facts.Free;
   end;
   after := FileBytes(fn);

   CheckEquals(Length(before), Length(after), 'the file is the same length');
   CheckTrue((Length(before) = Length(after)) and
             (CompareMem(@before[0], @after[0], Length(before))),
             'the file is byte-for-byte unchanged -- no migration, no WAL switch');
   CheckFalse(FileExists(fn + '-wal'), 'no -wal left beside the log');
   CheckFalse(FileExists(fn + '-shm'), 'no -shm left beside the log');

   db := TLogDatabase.Create;
   try
      db.OpenReadOnly(fn);
      CheckEquals(2, db.SchemaVersion, 'still schema 2');
   finally
      db.Free;
   end;

   (* NO LOCK HELD: Windows refuses to delete a file somebody has open. *)
   CheckTrue(DeleteFile(fn), 'the log can be deleted the moment the peek returns');
   Scrub(fn);
end;

procedure TLatestContestTests.Test_ALogOpenElsewhereStillDescribesItself;
var
   fn, why: string;
   writer: TLogDatabase;
   facts: TLogFileFacts;
begin
   BeginTest('Test_ALogOpenElsewhereStillDescribesItself');

   fn := TempName('open.db');
   MakeLog(fn);
   writer := TLogDatabase.Create;
   try
      writer.Open(fn);
      (* A write the peek can see only THROUGH the WAL. *)
      writer.Connection.ExecuteDirect(AnsiString(InsertQSOAt(UnixOf(2022, 6, 25))));
      writer.Transaction.Commit;
      CheckTrue(FileExists(fn + '-wal'), 'precondition: the writer has a -wal');

      facts := ReadLogFileFacts(fn, why);
      try
         CheckTrue(facts <> nil, 'an open log still describes itself: ' + why);
         if facts <> nil then
            begin
            CheckEquals(2022, facts.ContestYear,
                        'read through the WAL, so the uncheckpointed QSO counts');
            end;
      finally
         facts.Free;
      end;

      (* And the writer is not disturbed. *)
      writer.Connection.ExecuteDirect(AnsiString(InsertQSOAt(UnixOf(2022, 6, 26))));
      writer.Transaction.Commit;
   finally
      writer.Free;
   end;
   Scrub(fn);
end;

procedure TLatestContestTests.Test_TheImmutableURIEscapesThePath;
begin
   BeginTest('Test_TheImmutableURIEscapesThePath');

   CheckEquals('file:///C:/logs/cq%20ww%23%3F%25.db?immutable=1',
               string(ImmutableURI('C:\logs\cq ww#?%.db')),
               'slashes turned, %, ?, # and space escaped, a third slash for the drive');
end;

(* A UNC NAME KEEPS ITS TWO LEADING SLASHES under an EMPTY authority --
  file:////server/... -- the form sqlite.org/uri.html gives, and the only one
  SQLite's default build accepts (a named authority is refused). The
  end-to-end half is Test_AUNCPathIsPeekedImmutable. *)
procedure TLatestContestTests.Test_TheImmutableURINamesAUNCPath;
begin
   BeginTest('Test_TheImmutableURINamesAUNCPath');

   CheckEquals('file:////server/share/logs/cq%20ww.db?immutable=1',
               string(ImmutableURI('\\server\share\logs\cq ww.db')),
               'four slashes: an empty authority, then //server');
end;

(* ON UNIX A BACKSLASH IS A CHARACTER, NOT A SEPARATOR, so it is escaped
  rather than turned into a "/" that would name a different file -- and "?"
  is a legal file-name character there, so it is escaped too. *)
procedure TLatestContestTests.Test_TheImmutableURIKeepsAUnixBackslash;
begin
   BeginTest('Test_TheImmutableURIKeepsAUnixBackslash');

   CheckEquals('file:///home/op/a%5Cb%3F%20%231.db?immutable=1',
               string(ImmutableURI('/home/op/a\b? #1.db')),
               'the backslash and ? escaped, no third slash before an absolute path');
end;

(* A PATH THAT ONLY WORKS IF THE URI IS RIGHT, through the sqlite3 library the
  tests load (the one that ships). A space, a "#", an accented letter, and
  "%41" -- which an unescaped "%" would let SQLite decode to "A", naming a
  file that is not there.

  WHAT A PASS PROVES. Described: SQLite read the file, so the name was parsed
  as a URI (unparsed, "file:///..." names nothing and a read-only open cannot
  create it) and decoded to this path. Nothing beside it: immutable=1 took
  effect -- a plain read-only open of this WAL-mode log leaves -wal and -shm
  (measured, see OpenToPeek). *)
procedure TLatestContestTests.Test_AnAwkwardPathIsPeekedImmutable;
var
   dir, fn, why: string;
   facts: TLogFileFacts;
begin
   BeginTest('Test_AnAwkwardPathIsPeekedImmutable');

   dir := TempName('peek %41 #1 caf' + WideChar($00E9));
   {$IFDEF UNIX}
   dir := dir + ' a\b?';
   {$ENDIF}
   ForceDirectories(dir);
   fn := IncludeTrailingPathDelimiter(dir) + 'cq ww %41.db';
   MakeLog(fn);
   CheckTrue(LogSidecarPresent(fn) = '', 'precondition: a closed log, nothing beside it');

   facts := ReadLogFileFacts(fn, why);
   try
      CheckTrue(facts <> nil, 'the awkward path is read: ' + why);
      if facts <> nil then
         begin
         CheckEquals('NY4I', facts.MyCall, 'and it is the right file');
         end;
   finally
      facts.Free;
   end;
   CheckEquals('', LogSidecarPresent(fn), 'immutable: nothing left beside the log');

   Scrub(fn);
   RemoveDir(dir);
end;

(* THE SAME PEEK THROUGH A REAL UNC NAME: this machine's own administrative
  share, \\localhost\C$\..., when the temporary directory is on a drive and
  that share answers. Where it does not (no admin share, a policy), the test
  says so rather than passing as though it had looked. *)
procedure TLatestContestTests.Test_AUNCPathIsPeekedImmutable;
var
   fn, unc, why: string;
   facts: TLogFileFacts;
begin
   BeginTest('Test_AUNCPathIsPeekedImmutable');

   fn := TempName('unc peek.db');
   if (Length(fn) < 3) or (fn[2] <> ':') then
      begin
      WriteLn('  NOTE: the temporary directory is not on a drive; UNC peek not tried.');
      Exit;
      end;
   unc := '\\localhost\' + fn[1] + '$' + Copy(fn, 3, MaxInt);
   if not DirectoryExists(ExtractFileDir(unc)) then
      begin
      WriteLn('  NOTE: ' + ExtractFileDir(unc) + ' does not answer; UNC peek not tried.');
      Exit;
      end;

   MakeLog(fn);
   facts := ReadLogFileFacts(unc, why);
   try
      CheckTrue(facts <> nil, 'a log named by UNC is read: ' + why);
      if facts <> nil then
         begin
         CheckEquals('NY4I', facts.MyCall, 'and it is the right file');
         end;
   finally
      facts.Free;
   end;
   CheckEquals('', LogSidecarPresent(fn), 'immutable over UNC too: nothing beside it');
   Scrub(fn);
end;

(* EACH OF THE THREE SIDECARS IS SEEN -- the -journal included, which the
  first version of the peek did not look for (see the next test). *)
procedure TLatestContestTests.Test_EverySidecarIsSeen;
const
   SUFFIXES: array[0..2] of string = ('-wal', '-shm', '-journal');
var
   fn: string;
   i: integer;
begin
   BeginTest('Test_EverySidecarIsSeen');

   fn := TempName('sidecars.db');
   TFileStream.Create(AnsiString(fn), fmCreate).Free;
   CheckEquals('', LogSidecarPresent(fn), 'none beside it');
   for i := Low(SUFFIXES) to High(SUFFIXES) do
      begin
      TFileStream.Create(AnsiString(fn + SUFFIXES[i]), fmCreate).Free;
      CheckEquals(fn + SUFFIXES[i], LogSidecarPresent(fn), SUFFIXES[i] + ' is seen');
      DeleteFile(fn + SUFFIXES[i]);
      end;
   DeleteFile(fn);
end;

(* A ROLLBACK-JOURNAL LOG IN THE MIDDLE OF A WRITE IS NOT READ IMMUTABLE.

  A log SQLite would not put in WAL mode -- a network share -- runs with a
  rollback journal: the writer changes the main file IN PLACE, under a lock,
  and its -journal holds the pages it overwrote. There is no -wal. The first
  version of the peek looked only for a -wal, so it read such a file
  immutable: no lock, the journal ignored, and the writer's UNCOMMITTED pages
  read as the log.

  Here the writer renames the contest and then writes enough rows, through a
  tiny page cache, that SQLite spills the dirty contest page into the main
  file before COMMIT. The peek must not report that name: OpenToPeek sees the
  -journal and opens read-only, which waits for the writer's lock -- here, it
  is refused at once, and the caller answers "not described". *)
procedure TLatestContestTests.Test_ARollbackLogMidWriteIsNotReadImmutable;
const
   UNCOMMITTED = 'UNCOMMITTED NAME';
var
   fn, why: string;
   writer: TLogDatabase;
   facts: TLogFileFacts;
begin
   BeginTest('Test_ARollbackLogMidWriteIsNotReadImmutable');

   fn := TempName('journal.db');
   MakeLog(fn);
   writer := TLogDatabase.Create;
   try
      writer.Open(fn);
      writer.Connection.ExecutePragma('PRAGMA journal_mode = DELETE');
      writer.Connection.ExecutePragma('PRAGMA cache_size = 10');
      writer.Connection.ExecuteDirect(AnsiString('UPDATE contest SET contest_name = ''' +
                                                 UNCOMMITTED + ''' WHERE id = 1'));
      writer.Connection.ExecuteDirect(
         'WITH RECURSIVE n(i) AS (SELECT 1 UNION ALL SELECT i + 1 FROM n ' +
         'WHERE i < 20000) INSERT INTO qso (guid, qso_set_id, qso_at, callsign, ' +
         'freq_tx_hz, freq_rx_hz, band, mode) SELECT ''g'' || i, ''s'' || i, ' +
         '1700000000 + i, ''K1AR'', 14200000, 14200000, ''20M'', ''SSB'' FROM n');
      CheckTrue(FileExists(fn + '-journal'), 'precondition: the writer has a -journal');
      CheckFalse(FileExists(fn + '-wal'), 'precondition: and no -wal');

      facts := nil;
      try
         facts := ReadLogFileFacts(fn, why);
      except
         on E: Exception do
            begin
            CheckTrue(False, 'ReadLogFileFacts raised ' + E.ClassName + ': ' + E.Message);
            end;
      end;
      try
         CheckTrue((facts = nil) or (facts.ContestName <> UNCOMMITTED),
                   'the uncommitted name is never reported');
      finally
         facts.Free;
      end;

      writer.Rollback;
   finally
      writer.Free;
   end;

   (* And once the writer has gone, the log describes itself as committed. *)
   facts := ReadLogFileFacts(fn, why);
   try
      CheckTrue(facts <> nil, 'described after the rollback: ' + why);
      if facts <> nil then
         begin
         CheckTrue(facts.ContestName <> UNCOMMITTED, 'the committed name');
         end;
   finally
      facts.Free;
   end;
   Scrub(fn);
   DeleteFile(fn + '-journal');
end;

procedure TLatestContestTests.Test_AnOldCfgFallsBackToThePath;
var
   fn, why: string;
   lines: TStringList;
   facts: TLogFileFacts;
   latest: TLatestContest;
begin
   BeginTest('Test_AnOldCfgFallsBackToThePath');

   fn := TempName('CQWW SSB.cfg');
   lines := TStringList.Create;
   try
      lines.Add('MY CALL = NY4I');
      lines.Add('CONTEST = CQWWSSB');
      lines.SaveToFile(fn);
   finally
      lines.Free;
   end;

   facts := ReadLogFileFacts(fn, why);
   CheckTrue(facts = nil, 'a .cfg is not a log');
   facts.Free;
   CheckTrue(why <> '', 'and the reason is given');

   latest := TLatestContest.Create(fn);
   try
      CheckFalse(latest.Described, 'not described');
      CheckEquals(LowerCase(fn), latest.Detail, 'the old caption: the lower-cased path');
      CheckTrue(latest.Why <> '', 'with a reason to log');
   finally
      latest.Free;
   end;
   Scrub(fn);
end;

procedure TLatestContestTests.Test_AMissingFileFallsBack;
var
   fn, why: string;
   facts: TLogFileFacts;
   latest: TLatestContest;
begin
   BeginTest('Test_AMissingFileFallsBack');

   fn := TempName('not there.db');
   Scrub(fn);
   facts := ReadLogFileFacts(fn, why);
   CheckTrue(facts = nil, 'nothing to describe');
   facts.Free;
   CheckTrue(why <> '', 'and the reason is given');
   CheckFalse(FileExists(fn), 'and SQLite did not create one');

   latest := TLatestContest.Create(fn);
   try
      CheckFalse(latest.Described, 'not described');
      CheckEquals(LowerCase(fn), latest.Detail, 'the path');
   finally
      latest.Free;
   end;
end;

procedure TLatestContestTests.Test_ADamagedDatabaseFallsBackWithoutRaising;
var
   fn, why: string;
   facts: TLogFileFacts;
   latest: TLatestContest;
begin
   BeginTest('Test_ADamagedDatabaseFallsBackWithoutRaising');

   fn := TempName('damaged.db');
   (* The magic, a zero application id (which classifies as ours), then
     rubbish: it passes the byte check and fails in SQLite. *)
   WriteDamagedTestLog(fn);

   facts := nil;
   try
      facts := ReadLogFileFacts(fn, why);
      CheckTrue(facts = nil, 'a damaged database describes nothing');
      CheckTrue(why <> '', 'and says why: ' + why);
   except
      on E: Exception do
         begin
         CheckTrue(False, 'ReadLogFileFacts raised ' + E.ClassName + ': ' + E.Message);
         end;
   end;
   facts.Free;

   latest := TLatestContest.Create(fn);
   try
      CheckFalse(latest.Described, 'the button falls back to the path');
   finally
      latest.Free;
   end;
   Scrub(fn);
end;

procedure TLatestContestTests.Test_AnUnknownTokenShowsTheStoredName;
var
   fn: string;
   latest: TLatestContest;
begin
   BeginTest('Test_AnUnknownTokenShowsTheStoredName');

   fn := TempName('unknown.db');
   MakeLog(fn);
   Exec(fn, 'UPDATE contest SET contest_type = ''NO SUCH CONTEST'', ' +
            'contest_name = ''Retired Sprint''');

   latest := TLatestContest.Create(fn);
   try
      CheckTrue(latest.Described, 'still described: ' + latest.Why);
      CheckEquals('Retired Sprint', latest.ContestName,
                  'a token the registry does not know shows the stored name');
   finally
      latest.Free;
   end;
   Scrub(fn);

   CheckEquals('NO SUCH CONTEST', LatestContestDisplayName('NO SUCH CONTEST', ''),
               'and with no stored name, the token itself');
end;

procedure TLatestContestTests.Test_ALegacyTokenShowsItsContest;
begin
   BeginTest('Test_ALegacyTokenShowsItsContest');

   CheckEquals(ContestIdentity(ContestFromName('NEWEQP')).DisplayName,
               LatestContestDisplayName('NEQP', 'stored'),
               'a log written as NEQP is New England, by its current name');
end;

(* ---------------------------------------------------------------------------
  the caption, fitted
  --------------------------------------------------------------------------- *)

procedure TLatestContestTests.Test_EverythingFitsInThreeLines;
var
   button: TFakeButton;
   latest: TLatestContest;
begin
   BeginTest('Test_EverythingFitsInThreeLines');

   button := TFakeButton.Create;
   latest := TLatestContest.CreateFor('c:\logs\2026\cqww.db',
                                      'CQ Worldwide DX Contest, SSB', 2026, 'NY4I');
   try
      button.MaxLines := 3;
      button.MaxWidth := 80;
      CheckEquals(LABEL_TEXT + CRLF +
                  Format(SLatestContestLine, ['CQ Worldwide DX Contest, SSB', 2026]) + CRLF +
                  Format(SLatestContestDetail, ['NY4I', 'cqww.db']),
                  FitLatestCaption(LABEL_TEXT, latest, button.Fits),
                  'label, contest and year, call and file name');
   finally
      latest.Free;
      button.Free;
   end;
end;

procedure TLatestContestTests.Test_TheFileLineIsCutFromItsMiddleFirst;
var
   button: TFakeButton;
   latest: TLatestContest;
   lines: TStringList;
   contestLine: string;
begin
   BeginTest('Test_TheFileLineIsCutFromItsMiddleFirst');

   button := TFakeButton.Create;
   latest := TLatestContest.CreateFor('c:\logs\cq worldwide dx contest ssb 2026 ny4i.db',
                                      'CQ WW SSB', 2026, '');
   lines := TStringList.Create;
   try
      button.MaxLines := 3;
      button.MaxWidth := 30;
      contestLine := Format(SLatestContestLine, ['CQ WW SSB', 2026]);
      lines.Text := FitLatestCaption(LABEL_TEXT, latest, button.Fits);
      CheckEquals(3, lines.Count, 'three lines still');
      CheckEquals(LABEL_TEXT, lines[0], 'the label untouched');
      CheckEquals(contestLine, lines[1], 'the contest line untouched');
      CheckTrue(Pos('...', lines[2]) > 1, 'the file line elided in its middle: ' + lines[2]);
      CheckTrue(Copy(lines[2], 1, 4) = 'cq w', 'its start kept');
      CheckTrue(Copy(lines[2], Length(lines[2]) - 2, 3) = '.db', 'its end kept');
      CheckTrue(Length(lines[2]) <= 30, 'and it fits');
   finally
      lines.Free;
      latest.Free;
      button.Free;
   end;
end;

procedure TLatestContestTests.Test_TheFileLineIsDroppedBeforeTheContest;
var
   button: TFakeButton;
   latest: TLatestContest;
begin
   BeginTest('Test_TheFileLineIsDroppedBeforeTheContest');

   button := TFakeButton.Create;
   latest := TLatestContest.CreateFor('c:\x\cqww.db', 'CQ Worldwide DX Contest, SSB',
                                      2026, 'NY4I');
   try
      button.MaxLines := 2;
      button.MaxWidth := 80;
      CheckEquals(LABEL_TEXT + CRLF +
                  Format(SLatestContestLine, ['CQ Worldwide DX Contest, SSB', 2026]),
                  FitLatestCaption(LABEL_TEXT, latest, button.Fits),
                  'two lines of room: the file line goes, the contest stays whole');
   finally
      latest.Free;
      button.Free;
   end;
end;

procedure TLatestContestTests.Test_TheContestNameIsCutAtItsEndKeepingTheYear;
var
   button: TFakeButton;
   latest: TLatestContest;
   lines: TStringList;
begin
   BeginTest('Test_TheContestNameIsCutAtItsEndKeepingTheYear');

   button := TFakeButton.Create;
   latest := TLatestContest.CreateFor('c:\x\cqww.db', 'CQ Worldwide DX Contest, SSB',
                                      2026, 'NY4I');
   lines := TStringList.Create;
   try
      button.MaxLines := 3;
      button.MaxWidth := 22;   (* the label is 21 *)
      lines.Text := FitLatestCaption(LABEL_TEXT, latest, button.Fits);
      CheckEquals(2, lines.Count, 'the file line has gone');
      CheckEquals(LABEL_TEXT, lines[0], 'the label untouched');
      CheckTrue(Copy(lines[1], 1, 5) = 'CQ Wo', 'the name''s start kept: ' + lines[1]);
      CheckTrue(Pos('...', lines[1]) > 0, 'the name cut at its end');
      CheckTrue(Copy(lines[1], Length(lines[1]) - 3, 4) = '2026', 'the year kept');
      CheckTrue(Length(lines[1]) <= 22, 'and it fits');
      CheckTrue(Length(lines[1]) >= 21,
                'cut no further than it had to (got ' + IntToStr(Length(lines[1])) + ')');
   finally
      lines.Free;
      latest.Free;
      button.Free;
   end;
end;

procedure TLatestContestTests.Test_AnUndescribedFileKeepsItsPath;
var
   button: TFakeButton;
   latest: TLatestContest;
   lines: TStringList;
   fn: string;
begin
   BeginTest('Test_AnUndescribedFileKeepsItsPath');

   fn := TempName('not there either.cfg');
   button := TFakeButton.Create;
   latest := TLatestContest.Create(fn);
   lines := TStringList.Create;
   try
      button.MaxLines := 2;
      button.MaxWidth := 1000;
      CheckEquals(LABEL_TEXT + CRLF + LowerCase(fn),
                  FitLatestCaption(LABEL_TEXT, latest, button.Fits),
                  'exactly the old caption when there is room');

      button.MaxLines := 1;
      button.MaxWidth := 30;
      lines.Text := FitLatestCaption(LABEL_TEXT, latest, button.Fits);
      CheckEquals(2, lines.Count, 'the path is never dropped -- it is all there is');
      CheckTrue(Pos('...', lines[1]) > 0, 'only shortened');
   finally
      lines.Free;
      latest.Free;
      button.Free;
   end;
end;

procedure TLatestContestTests.Test_NoYearShowsTheBareName;
begin
   BeginTest('Test_NoYearShowsTheBareName');

   CheckEquals('CQ WW SSB', LatestContestLine('CQ WW SSB', 0), 'no year, no number');
   CheckEquals(Format(SLatestContestLine, ['CQ WW SSB', 2026]),
               LatestContestLine('CQ WW SSB', 2026), 'a year is shown');
   CheckEquals('cqww.db', LatestContestDetail('', 'cqww.db'), 'no call, bare file name');
end;

procedure TLatestContestTests.RunAllTests;
begin
   Test_ARealLogDescribesItself;
   Test_TheDeclaredStartBeatsTheFirstQSO;
   Test_ALogWithNoQSOsIsDatedByItsCreation;
   Test_ThePeekWritesNothingAndHoldsNothing;
   Test_ALogOpenElsewhereStillDescribesItself;
   {$IFDEF WINDOWS}
   Test_TheImmutableURIEscapesThePath;
   Test_TheImmutableURINamesAUNCPath;
   Test_AUNCPathIsPeekedImmutable;
   {$ELSE}
   Test_TheImmutableURIKeepsAUnixBackslash;
   {$ENDIF}
   Test_AnAwkwardPathIsPeekedImmutable;
   Test_EverySidecarIsSeen;
   Test_ARollbackLogMidWriteIsNotReadImmutable;
   Test_AnOldCfgFallsBackToThePath;
   Test_AMissingFileFallsBack;
   Test_ADamagedDatabaseFallsBackWithoutRaising;
   Test_AnUnknownTokenShowsTheStoredName;
   Test_ALegacyTokenShowsItsContest;
   Test_EverythingFitsInThreeLines;
   Test_TheFileLineIsCutFromItsMiddleFirst;
   Test_TheFileLineIsDroppedBeforeTheContest;
   Test_TheContestNameIsCutAtItsEndKeepingTheYear;
   Test_AnUndescribedFileKeepsItsPath;
   Test_NoYearShowsTheBareName;
end;

end.
