unit uTestLogRestore;

(* RESTORING THE CONTEST LOG FROM A BACKUP -- uLogRestore (issue 242, stage 1).

  TLogRestoreNameTests: the pure rules -- which file names are this log's
  backups, the newest-first order, the set-aside name.

  TLogRestoreTests: REAL logs in a temporary folder (never tr4w/target). The
  backups are made the way the program makes them, VACUUM INTO through
  TLogDatabase.SnapshotTo, so they are rollback-journal files as a published
  backup is. The log being replaced carries SENTINEL -wal and -shm files: the
  restore never opens the log it replaces, so their content is irrelevant to
  it, and their bytes prove they moved with the database and were never
  rewritten. "Unchanged" is asserted byte for byte. *)

{$I ..\..\src\tr4w.inc}

interface

uses
   uTR4WTestFramework;

type
   TLogRestoreNameTests = class(TTestCase)
   protected
      procedure TestTheNamesTheBackupsAreWrittenUnderAreFound;
      procedure TestOtherFilesAreNotThisLogsBackups;
      procedure TestCandidatesSortNewestQsoFirst;
      procedure TestTheSetAsideNameIsStampedAndNeverTaken;
   public
      procedure RunAllTests; override;
   end;

   TLogRestoreTests = class(TTestCase)
   private
      FDir: string;
      function Dir: string;
      function LogPath: string;
      function BackupDir: string;
      procedure EmptyFolder(const aFolder: string);
      procedure Reset;
      (* A log at aPath with aCount QSOs, the newest at aLastAt (unix UTC). *)
      procedure MakeLog(const aPath: string; aCount: integer; aLastAt: Int64);
      (* A backup of aSource at aBackup, as the program writes one. *)
      procedure MakeBackup(const aSource, aBackup: string);
      procedure AddSentinelSidecars;
      function QsoCountOf(const aPath: string): integer;
      procedure CheckOriginalUntouched(const aBefore: RawByteString; const aWhat: string);
   protected
      procedure TestAGoodRestoreSetsTheLogAsideAndPutsTheBackupInPlace;
      procedure TestACorruptCandidateIsRefused;
      procedure TestADamagedCandidateIsRefused;
      procedure TestACandidateFromANewerBuildIsRefused;
      procedure TestEveryRenameFailureLeavesTheOriginal;
      procedure TestAnOpenLogIsNotReplaced;
      procedure TestTheLogItselfIsNotACandidate;
      procedure TestDeliveryRowsRaiseTheWarning;
      procedure TestTheListFindsSortsAndChecks;
   public
      procedure RunAllTests; override;
   end;

implementation

uses
   SysUtils, Classes, DateUtils, uLogDatabase, uLogSchema, uLogRestore;

const
   SENTINEL_WAL = 'sentinel -wal: never opened by a restore';
   SENTINEL_SHM = 'sentinel -shm: never opened by a restore';

function FileBytes(const aPath: string): RawByteString;
var
   f: TFileStream;
begin
   Result := '';
   if not FileExists(aPath) then
      begin
      Result := '<absent>';
      Exit;
      end;
   f := TFileStream.Create(AnsiString(aPath), fmOpenRead or fmShareDenyNone);
   try
      SetLength(Result, f.Size);
      if f.Size > 0 then
         begin
         f.ReadBuffer(Result[1], f.Size);
         end;
   finally
      f.Free;
   end;
end;

procedure WriteBytes(const aPath: string; const aBytes: RawByteString);
var
   f: TFileStream;
begin
   f := TFileStream.Create(AnsiString(aPath), fmCreate);
   try
      if Length(aBytes) > 0 then
         begin
         f.WriteBuffer(aBytes[1], Length(aBytes));
         end;
   finally
      f.Free;
   end;
end;

(* A rename seam that fails its aFailAt-th call (1-based); 0 = none. *)
type
   TFailingRestoreFiles = class(TLogRestoreFiles)
   public
      FailAt: integer;
      Renames: integer;
      function RenameFile(const aOld, aNew: string): boolean; override;
   end;

function TFailingRestoreFiles.RenameFile(const aOld, aNew: string): boolean;
begin
   inc(Renames);
   if Renames = FailAt then
      begin
      Result := False;
      end
   else
      begin
      Result := inherited RenameFile(aOld, aNew);
      end;
end;

(* A file system that answers "taken" for the names it is given. *)
type
   TTakenNames = class(TLogRestoreFiles)
   public
      Taken: TStringList;
      constructor Create;
      destructor Destroy; override;
      function FileExists(const aPath: string): boolean; override;
   end;

constructor TTakenNames.Create;
begin
   inherited Create;
   Taken := TStringList.Create;
end;

destructor TTakenNames.Destroy;
begin
   Taken.Free;
   inherited Destroy;
end;

function TTakenNames.FileExists(const aPath: string): boolean;
begin
   Result := Taken.IndexOf(AnsiString(aPath)) >= 0;
end;

(* ---------------------------------------------------------------------------
  names
  --------------------------------------------------------------------------- *)

procedure TLogRestoreNameTests.TestTheNamesTheBackupsAreWrittenUnderAreFound;
const
   LOG = 'logs/W1AW CQWW.db';
var
   kind: TRestoreBackupKind;
   previous: boolean;
   staged: boolean;
begin
   BeginTest('every name a backup of the log is written under is found, with its kind');

   CheckTrue(ClassifyRestoreName(LOG, 'W1AW CQWW periodic.db', kind, previous, staged),
             'the periodic backup');
   CheckTrue(kind = rbkPeriodic, 'is periodic');
   CheckFalse(previous or staged, 'and the current generation');

   CheckTrue(ClassifyRestoreName(LOG, 'W1AW CQWW periodic.db.bak', kind, previous, staged),
             'its previous generation');
   CheckTrue((kind = rbkPeriodic) and previous and (not staged), 'is periodic, previous');

   CheckTrue(ClassifyRestoreName(LOG, 'W1AW CQWW periodic.db.new', kind, previous, staged),
             'a verified copy whose publish failed');
   CheckTrue((kind = rbkPeriodic) and staged and (not previous), 'is periodic, staged');

   CheckTrue(ClassifyRestoreName(LOG, 'W1AW CQWW before clear 2026-11-22 143000Z.db',
                                 kind, previous, staged), 'the pre-clear backup');
   CheckTrue(kind = rbkBeforeClear, 'is before clear');

   CheckTrue(ClassifyRestoreName(LOG, 'W1AW CQWW before catch-up 2026-11-22 143000Z.db',
                                 kind, previous, staged), 'the pre-catch-up backup');
   CheckTrue(kind = rbkBeforeCatchUp, 'is before catch-up');

   CheckTrue(ClassifyRestoreName(LOG, 'W1AW CQWW before schema 10 to 13.db',
                                 kind, previous, staged), 'the pre-upgrade backup');
   CheckTrue(kind = rbkBeforeUpgrade, 'is before upgrade');

   CheckTrue(ClassifyRestoreName(LOG, 'W1AW CQWW before schema 10 to 13 2.db',
                                 kind, previous, staged), 'its numbered repeat');
   CheckTrue(kind = rbkBeforeUpgrade, 'is before upgrade too');

   CheckTrue(ClassifyRestoreName('W1AW 2.db', 'W1AW 2 periodic.db', kind, previous, staged),
             'a numbered log has its own periodic backup');
end;

procedure TLogRestoreNameTests.TestOtherFilesAreNotThisLogsBackups;
const
   LOG = 'logs/W1AW.db';
var
   kind: TRestoreBackupKind;
   previous: boolean;
   staged: boolean;
begin
   BeginTest('the log itself, another log''s backups and the copier''s files are not candidates');
   CheckFalse(ClassifyRestoreName(LOG, 'W1AW.db', kind, previous, staged), 'the log''s own name');
   CheckFalse(ClassifyRestoreName(LOG, 'W1AW 2.db', kind, previous, staged), 'another log');
   CheckFalse(ClassifyRestoreName(LOG, 'W1AW 2 periodic.db', kind, previous, staged),
              'the backup of "W1AW 2" is not W1AW''s');
   CheckFalse(ClassifyRestoreName(LOG, 'K1AR periodic.db', kind, previous, staged),
              'another call''s');
   CheckFalse(ClassifyRestoreName(LOG, 'W1AW periodic.db.0123abcd.outbox', kind, previous, staged),
              'an outbox copy');
   CheckFalse(ClassifyRestoreName(LOG, 'W1AW periodic.db.0123abcd.partial', kind, previous, staged),
              'a partial copy');
   CheckFalse(ClassifyRestoreName(LOG, 'W1AW.db.damaged-2026-11-22-143000Z', kind, previous, staged),
              'a set-aside log');
   CheckFalse(ClassifyRestoreName(LOG, 'W1AW.db.restoring', kind, previous, staged),
              'a restore''s staging file');
   CheckFalse(ClassifyRestoreName(LOG, 'W1AW before clear 2026.db', kind, previous, staged),
              'a name that only looks dated');
   CheckFalse(ClassifyRestoreName(LOG, 'W1AW periodic periodic.db', kind, previous, staged),
              'a stacked name the backup code never writes');
end;

procedure TLogRestoreNameTests.TestCandidatesSortNewestQsoFirst;
var
   list: TRestoreCandidateList;
   c: TRestoreCandidate;
begin
   BeginTest('candidates sort by newest QSO, then file time, then path');
   list := TRestoreCandidateList.Create(True);
   try
      c := TRestoreCandidate.Create;
      c.Path := 'old';
      c.LastQSOTime := EncodeDateTime(2026, 11, 22, 10, 0, 0, 0);
      c.FileTimeUTC := EncodeDateTime(2026, 11, 22, 23, 0, 0, 0);
      list.Add(c);
      c := TRestoreCandidate.Create;
      c.Path := 'unreadable';
      list.Add(c);
      c := TRestoreCandidate.Create;
      c.Path := 'newest-b';
      c.LastQSOTime := EncodeDateTime(2026, 11, 22, 12, 0, 0, 0);
      c.FileTimeUTC := EncodeDateTime(2026, 11, 22, 12, 5, 0, 0);
      list.Add(c);
      c := TRestoreCandidate.Create;
      c.Path := 'newest-a';
      c.LastQSOTime := EncodeDateTime(2026, 11, 22, 12, 0, 0, 0);
      c.FileTimeUTC := EncodeDateTime(2026, 11, 22, 12, 5, 0, 0);
      list.Add(c);
      c := TRestoreCandidate.Create;
      c.Path := 'newest-later-copy';
      c.LastQSOTime := EncodeDateTime(2026, 11, 22, 12, 0, 0, 0);
      c.FileTimeUTC := EncodeDateTime(2026, 11, 22, 13, 0, 0, 0);
      list.Add(c);

      SortRestoreCandidates(list);
      CheckEquals('newest-later-copy', list[0].Path, 'same QSO, newer file first');
      CheckEquals('newest-a', list[1].Path, 'then by path');
      CheckEquals('newest-b', list[2].Path, 'then by path');
      CheckEquals('old', list[3].Path, 'an older QSO later, whatever its file time');
      CheckEquals('unreadable', list[4].Path, 'no QSO time last');
   finally
      list.Free;
   end;
end;

procedure TLogRestoreNameTests.TestTheSetAsideNameIsStampedAndNeverTaken;
var
   files: TTakenNames;
   stamp: TDateTime;
begin
   BeginTest('the set-aside name is <log>.damaged-<UTC>Z, numbered when taken');
   stamp := EncodeDateTime(2026, 11, 22, 14, 30, 5, 0);
   CheckEquals('a.db.damaged-2026-11-22-143005Z', DamagedLogBaseName('a.db', stamp),
               'the stamp');
   files := TTakenNames.Create;
   try
      CheckEquals('a.db.damaged-2026-11-22-143005Z', DamagedLogFileName('a.db', stamp, files),
                  'free: the plain name');
      files.Taken.Add('a.db.damaged-2026-11-22-143005Z-wal');
      CheckEquals('a.db.damaged-2026-11-22-143005Z-2', DamagedLogFileName('a.db', stamp, files),
                  'a sidecar name taken is a name taken');
      files.Taken.Add('a.db.damaged-2026-11-22-143005Z-2');
      CheckEquals('a.db.damaged-2026-11-22-143005Z-3', DamagedLogFileName('a.db', stamp, files),
                  'the next free number');
   finally
      files.Free;
   end;
end;

procedure TLogRestoreNameTests.RunAllTests;
begin
   TestTheNamesTheBackupsAreWrittenUnderAreFound;
   TestOtherFilesAreNotThisLogsBackups;
   TestCandidatesSortNewestQsoFirst;
   TestTheSetAsideNameIsStampedAndNeverTaken;
end;

(* ---------------------------------------------------------------------------
  fixture
  --------------------------------------------------------------------------- *)

function TLogRestoreTests.Dir: string;
begin
   if FDir = '' then
      begin
      FDir := IncludeTrailingPathDelimiter(GetTempDir) +
              'tr4w_logrestore_' + IntToStr(GetProcessID);
      ForceDirectories(FDir);
      end;
   Result := IncludeTrailingPathDelimiter(FDir);
end;

function TLogRestoreTests.LogPath: string;
begin
   Result := Dir + 'W1AW.db';
end;

function TLogRestoreTests.BackupDir: string;
begin
   Result := Dir + 'backup' + DirectorySeparator;
end;

procedure TLogRestoreTests.EmptyFolder(const aFolder: string);
var
   found: TUnicodeSearchRec;
begin
   if not DirectoryExists(aFolder) then
      begin
      Exit;
      end;
   if FindFirst(IncludeTrailingPathDelimiter(aFolder) + '*', faAnyFile, found) = 0 then
      begin
      try
         repeat
            if (found.Attr and faDirectory) = 0 then
               begin
               DeleteFile(IncludeTrailingPathDelimiter(aFolder) + found.Name);
               end;
         until FindNext(found) <> 0;
      finally
         FindClose(found);
      end;
      end;
end;

procedure TLogRestoreTests.Reset;
begin
   EmptyFolder(Dir);
   EmptyFolder(BackupDir);
   EmptyFolder(Dir + 'dest');
   ForceDirectories(BackupDir);
   ForceDirectories(Dir + 'dest');
end;

procedure TLogRestoreTests.MakeLog(const aPath: string; aCount: integer; aLastAt: Int64);
var
   db: TLogDatabase;
   i: integer;
   at: Int64;
begin
   db := TLogDatabase.Create;
   try
      db.CreateNew(aPath);
      for i := 1 to aCount do
         begin
         at := aLastAt - (aCount - i) * 60;
         db.Connection.ExecuteDirect(AnsiString(
            'INSERT INTO qso (guid, qso_set_id, qso_at, callsign, freq_tx_hz, ' +
            'freq_rx_hz, band, mode) VALUES (''g' + IntToStr(at) + ''', ''s' +
            IntToStr(at) + ''', ' + IntToStr(at) +
            ', ''K1AR'', 14200000, 14200000, ''20M'', ''CW'')'));
         end;
      db.Transaction.Commit;
   finally
      db.Free;
   end;
end;

procedure TLogRestoreTests.MakeBackup(const aSource, aBackup: string);
var
   db: TLogDatabase;
begin
   db := TLogDatabase.Create;
   try
      db.OpenReadOnly(aSource);
      db.SnapshotTo(aBackup);
   finally
      db.Free;
   end;
   (* A read-only connection to a WAL-mode source leaves its sidecars. *)
   DeleteFile(aSource + '-wal');
   DeleteFile(aSource + '-shm');
end;

procedure TLogRestoreTests.AddSentinelSidecars;
begin
   WriteBytes(LogPath + '-wal', SENTINEL_WAL);
   WriteBytes(LogPath + '-shm', SENTINEL_SHM);
end;

function TLogRestoreTests.QsoCountOf(const aPath: string): integer;
var
   files: TLogRestoreFiles;
   c: TRestoreCandidate;
begin
   files := TLogRestoreFiles.Create;
   c := TRestoreCandidate.Create;
   try
      c.Path := aPath;
      files.Inspect(c);
      Result := c.QSOCount;
      if not c.Readable then
         begin
         Result := -1;
         end;
   finally
      c.Free;
      files.Free;
   end;
end;

procedure TLogRestoreTests.CheckOriginalUntouched(const aBefore: RawByteString;
   const aWhat: string);
var
   found: TUnicodeSearchRec;
   leftovers: string;
begin
   CheckTrue(FileBytes(LogPath) = aBefore, aWhat + ': the log is byte-identical');
   CheckTrue(FileBytes(LogPath + '-wal') = SENTINEL_WAL, aWhat + ': its -wal is back, unchanged');
   CheckTrue(FileBytes(LogPath + '-shm') = SENTINEL_SHM, aWhat + ': its -shm is back, unchanged');
   CheckFalse(FileExists(RestoreStagingFileName(LogPath)), aWhat + ': no staging file');
   CheckFalse(FileExists(RestoreStagingFileName(LogPath) + '.new'), aWhat + ': no staged .new');
   leftovers := '';
   if FindFirst(Dir + '*' + RESTORE_DAMAGED_INFIX + '*', faAnyFile, found) = 0 then
      begin
      try
         repeat
            leftovers := leftovers + ' ' + found.Name;
         until FindNext(found) <> 0;
      finally
         FindClose(found);
      end;
      end;
   CheckEquals('', leftovers, aWhat + ': nothing set aside');
end;

(* ---------------------------------------------------------------------------
  restoring
  --------------------------------------------------------------------------- *)

procedure TLogRestoreTests.TestAGoodRestoreSetsTheLogAsideAndPutsTheBackupInPlace;
var
   backup: string;
   before: RawByteString;
   result: TLogRestoreResult;
   stamp: TDateTime;
   aside: string;
begin
   BeginTest('a good restore sets the log and its sidecars aside and puts the backup in place');
   Reset;
   backup := BackupDir + 'W1AW periodic.db';
   MakeLog(Dir + 'source.db', 3, 1763800000);
   MakeBackup(Dir + 'source.db', backup);
   MakeLog(LogPath, 5, 1763900000);
   AddSentinelSidecars;
   before := FileBytes(LogPath);
   stamp := EncodeDateTime(2026, 11, 22, 14, 30, 5, 0);

   result := RestoreLogFromBackup(LogPath, backup, stamp);
   try
      CheckTrue(result.Ok, 'it restores: ' + result.Reason);
      aside := LogPath + '.damaged-2026-11-22-143005Z';
      CheckEquals(aside, result.SetAsidePath, 'and names where the old log went');
      CheckEquals(3, result.QSOCount, 'the backup''s QSOs');
      CheckFalse(result.DeliveryMayDiffer, 'no delivery rows, no warning');
   finally
      result.Free;
   end;

   CheckTrue(FileBytes(aside) = before, 'the old log is set aside byte for byte');
   CheckTrue(FileBytes(aside + '-wal') = SENTINEL_WAL, 'its -wal went with it');
   CheckTrue(FileBytes(aside + '-shm') = SENTINEL_SHM, 'its -shm went with it');
   CheckFalse(FileExists(LogPath + '-wal'), 'no -wal is left under the log''s name');
   CheckFalse(FileExists(LogPath + '-shm'), 'no -shm is left under the log''s name');
   CheckFalse(FileExists(RestoreStagingFileName(LogPath)), 'the staging file is gone');
   CheckEquals(3, QsoCountOf(LogPath), 'the log now holds the backup''s 3 QSOs');
   CheckTrue(FileExists(backup), 'the backup itself is still there');
end;

procedure TLogRestoreTests.TestACorruptCandidateIsRefused;
var
   backup: string;
   before: RawByteString;
   result: TLogRestoreResult;
begin
   BeginTest('a candidate that is not a database is refused and the log is untouched');
   Reset;
   backup := BackupDir + 'W1AW periodic.db';
   WriteBytes(backup, 'this is not an SQLite database, just bytes in a file');
   MakeLog(LogPath, 5, 1763900000);
   AddSentinelSidecars;
   before := FileBytes(LogPath);

   result := RestoreLogFromBackup(LogPath, backup, Now);
   try
      CheckFalse(result.Ok, 'refused');
      CheckTrue(Pos('could not be read', result.Reason) > 0, 'and says why: ' + result.Reason);
   finally
      result.Free;
   end;
   CheckOriginalUntouched(before, 'a corrupt candidate');
end;

procedure TLogRestoreTests.TestADamagedCandidateIsRefused;
var
   backup: string;
   before: RawByteString;
   bytes: RawByteString;
   result: TLogRestoreResult;
   i: integer;
begin
   (* A real backup with pages past the first overwritten: it opens (page 1
     is intact) and fails either the read or the integrity check. *)
   BeginTest('a backup with damaged pages is refused and the log is untouched');
   Reset;
   backup := BackupDir + 'W1AW periodic.db';
   MakeLog(Dir + 'source.db', 400, 1763800000);
   MakeBackup(Dir + 'source.db', backup);
   bytes := FileBytes(backup);
   CheckTrue(Length(bytes) > 3 * 4096, 'the backup has several pages');
   for i := 2 * 4096 + 1 to Length(bytes) do
      begin
      bytes[i] := AnsiChar($A5);
      end;
   WriteBytes(backup, bytes);
   MakeLog(LogPath, 5, 1763900000);
   AddSentinelSidecars;
   before := FileBytes(LogPath);

   result := RestoreLogFromBackup(LogPath, backup, Now);
   try
      CheckFalse(result.Ok, 'refused: ' + result.Reason);
   finally
      result.Free;
   end;
   CheckOriginalUntouched(before, 'a damaged candidate');
end;

procedure TLogRestoreTests.TestACandidateFromANewerBuildIsRefused;
var
   backup: string;
   before: RawByteString;
   result: TLogRestoreResult;
   db: TLogDatabase;
begin
   BeginTest('a backup from a newer schema than this build is refused');
   Reset;
   backup := BackupDir + 'W1AW periodic.db';
   MakeLog(backup, 2, 1763800000);
   db := TLogDatabase.Create;
   try
      db.Open(backup);
      db.Connection.ExecuteDirect(AnsiString('PRAGMA user_version = ' +
                                             IntToStr(LOG_SCHEMA_VERSION + 1)));
      db.Transaction.Commit;
   finally
      db.Free;
   end;
   MakeLog(LogPath, 5, 1763900000);
   AddSentinelSidecars;
   before := FileBytes(LogPath);

   result := RestoreLogFromBackup(LogPath, backup, Now);
   try
      CheckFalse(result.Ok, 'refused: ' + result.Reason);
   finally
      result.Free;
   end;
   CheckOriginalUntouched(before, 'a newer candidate');
end;

procedure TLogRestoreTests.TestEveryRenameFailureLeavesTheOriginal;
const
   (* The set-aside renames the log, its -wal and its -shm, then the staging
     file is renamed into place: four renames through the seam. *)
   RENAMES = 4;
var
   backup: string;
   before: RawByteString;
   result: TLogRestoreResult;
   files: TFailingRestoreFiles;
   k: integer;
begin
   BeginTest('a failure of any rename leaves the log, its sidecars and the folder as they were');
   for k := 1 to RENAMES do
      begin
      Reset;
      backup := BackupDir + 'W1AW periodic.db';
      MakeLog(Dir + 'source.db', 3, 1763800000);
      MakeBackup(Dir + 'source.db', backup);
      MakeLog(LogPath, 5, 1763900000);
      AddSentinelSidecars;
      before := FileBytes(LogPath);

      files := TFailingRestoreFiles.Create;
      try
         files.FailAt := k;
         result := RestoreLogFromBackup(LogPath, backup, Now, files);
         try
            CheckFalse(result.Ok, UnicodeFormat('rename %d failing refuses: %s', [k, result.Reason]));
            CheckEquals('', result.SetAsidePath, 'and reports nothing set aside');
         finally
            result.Free;
         end;
      finally
         files.Free;
      end;
      CheckOriginalUntouched(before, UnicodeFormat('rename %d failing', [k]));
      end;
end;

procedure TLogRestoreTests.TestAnOpenLogIsNotReplaced;
{$IFDEF WINDOWS}
var
   backup: string;
   before: RawByteString;
   result: TLogRestoreResult;
   holder: TFileStream;
{$ENDIF}
begin
   BeginTest('a log another handle holds open is not replaced (Windows refuses the rename)');
   {$IFDEF WINDOWS}
   Reset;
   backup := BackupDir + 'W1AW periodic.db';
   MakeLog(Dir + 'source.db', 3, 1763800000);
   MakeBackup(Dir + 'source.db', backup);
   MakeLog(LogPath, 5, 1763900000);
   AddSentinelSidecars;
   before := FileBytes(LogPath);

   (* EXCLUSIVE: whether the RTL's deny-none share mode includes
     FILE_SHARE_DELETE is the RTL's business; an exclusive handle refuses a
     rename on every Windows, as SQLite's own handle does. *)
   holder := TFileStream.Create(AnsiString(LogPath), fmOpenRead or fmShareExclusive);
   try
      result := RestoreLogFromBackup(LogPath, backup, Now);
      try
         CheckFalse(result.Ok, 'refused: ' + result.Reason);
      finally
         result.Free;
      end;
   finally
      holder.Free;
   end;
   CheckOriginalUntouched(before, 'an open log');
   {$ELSE}
   (* rename(2) does not care about open handles: the precondition is the
     store's (LogStoreRestoreLog), not the file system's. *)
   CheckTrue(True, 'not a Windows build');
   {$ENDIF}
end;

procedure TLogRestoreTests.TestTheLogItselfIsNotACandidate;
var
   before: RawByteString;
   result: TLogRestoreResult;
begin
   BeginTest('the log cannot be restored from itself');
   Reset;
   MakeLog(LogPath, 5, 1763900000);
   AddSentinelSidecars;
   before := FileBytes(LogPath);
   result := RestoreLogFromBackup(LogPath, LogPath, Now);
   try
      CheckFalse(result.Ok, 'refused');
      CheckTrue(Pos('is the log itself', result.Reason) > 0, 'and says why: ' + result.Reason);
   finally
      result.Free;
   end;
   CheckOriginalUntouched(before, 'the log as its own candidate');
end;

procedure TLogRestoreTests.TestDeliveryRowsRaiseTheWarning;
var
   backup: string;
   result: TLogRestoreResult;
   db: TLogDatabase;
begin
   BeginTest('a backup holding external-logger delivery rows restores with the warning');
   Reset;
   MakeLog(Dir + 'source.db', 2, 1763800000);
   db := TLogDatabase.Create;
   try
      db.Open(Dir + 'source.db');
      db.Connection.ExecuteDirect(AnsiString(
         'INSERT INTO external_delivery (logger, account, logbook, contact, ' +
         'revision, payload, state) VALUES (''wrl'', ''a'', ''b'', ''g1'', 1, ' +
         '''{}'', ''synced'')'));
      db.Transaction.Commit;
   finally
      db.Free;
   end;
   backup := BackupDir + 'W1AW periodic.db';
   MakeBackup(Dir + 'source.db', backup);
   MakeLog(LogPath, 5, 1763900000);

   result := RestoreLogFromBackup(LogPath, backup, Now);
   try
      CheckTrue(result.Ok, 'it restores: ' + result.Reason);
      CheckTrue(result.DeliveryMayDiffer, 'and warns that delivery may differ');
      CheckTrue(result.DeliveryNotice <> '', 'with the notice text');
   finally
      result.Free;
   end;
end;

procedure TLogRestoreTests.TestTheListFindsSortsAndChecks;
var
   list: TRestoreCandidateList;
   i: integer;
   names: string;
begin
   BeginTest('the list holds this log''s backups from both folders, newest QSO first, each checked');
   Reset;
   MakeLog(Dir + 'old.db', 2, 1763800000);
   MakeLog(Dir + 'new.db', 4, 1763900000);
   MakeBackup(Dir + 'old.db', BackupDir + 'W1AW periodic.db');
   MakeBackup(Dir + 'new.db', BackupDir + 'W1AW before clear 2026-11-22 143000Z.db');
   MakeBackup(Dir + 'old.db', Dir + 'dest' + DirectorySeparator + 'W1AW periodic.db');
   WriteBytes(BackupDir + 'W1AW periodic.db.bak', 'garbage, not a database');
   MakeBackup(Dir + 'new.db', BackupDir + 'K1AR periodic.db');
   MakeLog(LogPath, 5, 1764000000);

   list := ListRestoreCandidates(LogPath, BackupDir, Dir + 'dest');
   try
      names := '';
      for i := 0 to list.Count - 1 do
         begin
         names := names + ExtractFileName(list[i].Path) + '|';
         end;
      CheckEquals(4, list.Count, 'four candidates, K1AR''s left out: ' + names);
      if list.Count = 4 then
         begin
         CheckEquals('W1AW before clear 2026-11-22 143000Z.db', ExtractFileName(list[0].Path),
                     'the newest QSO first');
         CheckEquals(4, list[0].QSOCount, 'with its count');
         CheckTrue(list[0].Sound and list[0].Readable, 'and sound');
         CheckEquals(LOG_SCHEMA_VERSION, list[0].SchemaVersion, 'at this schema');
         CheckTrue(list[0].Kind = rbkBeforeClear, 'of its kind');
         CheckTrue((list[1].Place = rbpBackupFolder) <> (list[2].Place = rbpBackupFolder),
                   'the two periodic copies, one from each folder');
         CheckEquals('W1AW periodic.db.bak', ExtractFileName(list[3].Path),
                     'the unreadable one last');
         CheckFalse(list[3].Sound, 'and not sound');
         CheckTrue(list[3].Previous, 'a previous generation');
         CheckTrue(list[3].Why <> '', 'with its reason');
         end;
   finally
      list.Free;
   end;
end;

procedure TLogRestoreTests.RunAllTests;
begin
   TestAGoodRestoreSetsTheLogAsideAndPutsTheBackupInPlace;
   TestACorruptCandidateIsRefused;
   TestADamagedCandidateIsRefused;
   TestACandidateFromANewerBuildIsRefused;
   TestEveryRenameFailureLeavesTheOriginal;
   TestAnOpenLogIsNotReplaced;
   TestTheLogItselfIsNotACandidate;
   TestDeliveryRowsRaiseTheWarning;
   TestTheListFindsSortsAndChecks;
   Reset;
end;

end.
