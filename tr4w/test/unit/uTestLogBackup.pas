unit uTestLogBackup;

(* PUBLISHING A BACKUP OF THE CONTEST LOG -- the order of the file operations.

  TLogBackup (src/domain/uLogBackup.pas) is what LogStoreBackup runs. These
  tests drive it with a FAKE source, so that a snapshot can be made to come
  out good, come out as garbage, or raise -- and REAL files in a temporary
  directory, because what is being pinned is exactly which files exist, under
  which names, holding which bytes, after each path.

  THE GOOD SNAPSHOT IS A REAL ONE. The fake's "good" case calls
  TLogDatabase.SnapshotTo on a real log, and verification is the real
  StagedBackupIsSound, so the happy path is SQLite end to end. Only the
  failures are contrived, and they have to be: a real snapshot will not
  corrupt itself on request.

  The report sentences are pinned EXACTLY. They are the only thing an operator
  sees of an unattended periodic backup, so a change to one is a behaviour
  change and should fail a test. *)

{$I ..\..\src\tr4w.inc}

interface

uses
   uTR4WTestFramework;

type
   TLogBackupTests = class(TTestCase)
   private
      FDir: string;
      function TempName(const aLeaf: string): string;
      procedure Scrub(const aDestination: string);
   protected
      (* refusals before anything is written *)
      procedure TestBlankDestinationIsRefusedBeforeTheLogIsAsked;
      procedure TestUnopenedLogIsReportedAndNothingIsWritten;

      (* the happy path *)
      procedure TestFirstBackupPublishes;
      procedure TestSnapshotIsStagedAndVerifiedNotWrittenInPlace;
      procedure TestPublishIsARenameAndTheOldBackupBecomesBak;
      procedure TestAnOlderBakIsReplacedByTheDisplacedBackup;
      procedure TestAnOlderBakIsKeptWhenThereIsNothingToDisplace;
      procedure TestAStaleStagedFileIsDiscardedFirst;

      (* failures *)
      procedure TestCorruptSnapshotIsRejectedAndThePriorBackupSurvives;
      procedure TestSnapshotThatRaisesLeavesNoStagedFile;
      procedure TestVerifierThatRaisesLeavesNoStagedFile;
      procedure TestFailedPublishKeepsTheVerifiedCopyAndNamesIt;

      (* the verifier itself *)
      procedure TestSoundAcceptsARealSnapshotAndReleasesIt;
      procedure TestSoundRejectsGarbage;
      procedure TestSoundRejectsAMissingFile;
   public
      procedure RunAllTests; override;
   end;

implementation

uses
   SysUtils, Classes, uLogDatabase, uLogBackup;

const
   ABSENT = '<absent>';

type
   TSnapshotKind = (skGood, skGarbage, skRaise, skPartialThenRaise);

   (* A BACKUP SOURCE THAT DOES WHAT IT IS TOLD AND WRITES DOWN WHAT IT SAW.

     Calls records every question the run asked, in order, with the path it
     asked about -- which is how the tests prove the snapshot went to .new and
     that .new, not the destination, was verified. *)
   TFakeBackup = class(TLogBackup)
   private
      FSource: TLogDatabase;
   protected
      function SourceIsReady: boolean; override;
      procedure SnapshotTo(const aStaged: string); override;
      function StagedIsSound(const aStaged: string; out aWhy: string): boolean; override;
   public
      Ready: boolean;
      Kind: TSnapshotKind;
      VerifyRaises: boolean;
      Calls: TStringList;
      (* What the destination held at the moment the snapshot was taken. *)
      DestinationAtSnapshot: RawByteString;
      StagedExistedAtSnapshot: boolean;
      (* The exact bytes the snapshot produced. *)
      StagedBytes: RawByteString;
      (* The bytes .new held once verification returned -- the last moment
        before publish, so what a rename must carry across unchanged. NOT the
        same as StagedBytes: see TestPublishIsARenameAndTheOldBackupBecomesBak. *)
      VerifiedBytes: RawByteString;
      Destination: string;
      constructor Create(aSource: TLogDatabase; const aDestination: string);
      destructor Destroy; override;
   end;

function ReadBytes(const aPath: string): RawByteString;
var
   fs: TFileStream;
begin
   if not FileExists(aPath) then
      begin
      Result := ABSENT;
      Exit;
      end;
   fs := TFileStream.Create(aPath, fmOpenRead or fmShareDenyNone);
   try
      Result := '';
      SetLength(Result, fs.Size);
      if fs.Size > 0 then
         begin
         fs.ReadBuffer(Result[1], fs.Size);
         end;
   finally
      fs.Free;
   end;
end;

procedure WriteBytes(const aPath: string; const aBytes: RawByteString);
var
   fs: TFileStream;
begin
   fs := TFileStream.Create(aPath, fmCreate);
   try
      if Length(aBytes) > 0 then
         begin
         fs.WriteBuffer(aBytes[1], Length(aBytes));
         end;
   finally
      fs.Free;
   end;
end;

constructor TFakeBackup.Create(aSource: TLogDatabase; const aDestination: string);
begin
   inherited Create;
   FSource := aSource;
   Destination := aDestination;
   Ready := True;
   Kind := skGood;
   VerifyRaises := False;
   Calls := TStringList.Create;
   DestinationAtSnapshot := '';
   StagedExistedAtSnapshot := False;
   StagedBytes := '';
   VerifiedBytes := '';
end;

destructor TFakeBackup.Destroy;
begin
   Calls.Free;
   inherited Destroy;
end;

function TFakeBackup.SourceIsReady: boolean;
begin
   Calls.Add('ready');
   Result := Ready;
end;

procedure TFakeBackup.SnapshotTo(const aStaged: string);
begin
   Calls.Add('snapshot ' + aStaged);
   DestinationAtSnapshot := ReadBytes(Destination);
   StagedExistedAtSnapshot := FileExists(aStaged);

   case Kind of
      skGood:
         begin
         FSource.SnapshotTo(aStaged);
         end;
      skGarbage:
         begin
         WriteBytes(aStaged, 'this is not a database, whatever the name says');
         end;
      skRaise:
         begin
         raise Exception.Create('the backup volume is full');
         end;
      skPartialThenRaise:
         begin
         WriteBytes(aStaged, 'half a snapshot');
         raise Exception.Create('the backup volume is full');
         end;
   end;

   StagedBytes := ReadBytes(aStaged);
end;

function TFakeBackup.StagedIsSound(const aStaged: string; out aWhy: string): boolean;
begin
   Calls.Add('verify ' + aStaged);
   if VerifyRaises then
      begin
      raise Exception.Create('the verifier fell over');
      end;
   Result := inherited StagedIsSound(aStaged, aWhy);
   VerifiedBytes := ReadBytes(aStaged);
end;

(* ---------------------------------------------------------------------------
  fixture
  --------------------------------------------------------------------------- *)

function TLogBackupTests.TempName(const aLeaf: string): string;
begin
   if FDir = '' then
      begin
      FDir := IncludeTrailingPathDelimiter(GetTempDir) +
              'tr4w_logbackup_' + IntToStr(GetProcessID);
      ForceDirectories(FDir);
      end;
   Result := IncludeTrailingPathDelimiter(FDir) + aLeaf;
end;

(* Every name a run can leave behind, plus the WAL pair SQLite puts beside any
  of them it opens. A destination made a directory by one test is removed as
  one. *)
procedure TLogBackupTests.Scrub(const aDestination: string);
const
   SUFFIXES: array[0..2] of string = ('', '.new', '.bak');
var
   i: integer;
   base: string;
begin
   for i := Low(SUFFIXES) to High(SUFFIXES) do
      begin
      base := aDestination + SUFFIXES[i];
      if DirectoryExists(base) then
         begin
         RemoveDir(base);
         end;
      if FileExists(base) then
         begin
         DeleteFile(base);
         end;
      if FileExists(base + '-wal') then
         begin
         DeleteFile(base + '-wal');
         end;
      if FileExists(base + '-shm') then
         begin
         DeleteFile(base + '-shm');
         end;
      end;
end;

(* ---------------------------------------------------------------------------
  refusals before anything is written
  --------------------------------------------------------------------------- *)

procedure TLogBackupTests.TestBlankDestinationIsRefusedBeforeTheLogIsAsked;
var
   backup: TFakeBackup;
   report: string;
   ok: boolean;
begin
   (* ORDER: the name is checked before the log is asked whether it is ready,
     because asking OPENS the log in the real program -- a side effect a
     backup with nowhere to go should not have. *)
   BeginTest('a blank destination is refused before the log is asked');
   backup := TFakeBackup.Create(nil, '   ');
   try
      ok := backup.Run('   ', report);
      CheckFalse(ok, 'a blank name does not back up');
      CheckEquals('No backup file name is set. See BACKUP LOG FILE NAME.',
                  report, 'and says which setting to fix');
      CheckEquals(0, backup.Calls.Count, 'and the log was never asked anything');
   finally
      backup.Free;
   end;
end;

procedure TLogBackupTests.TestUnopenedLogIsReportedAndNothingIsWritten;
var
   backup: TFakeBackup;
   dest: string;
   report: string;
   ok: boolean;
begin
   BeginTest('a log that will not open is reported and nothing is written');
   dest := TempName('unopened.db');
   Scrub(dest);

   backup := TFakeBackup.Create(nil, dest);
   try
      backup.Ready := False;
      ok := backup.Run(dest, report);
      CheckFalse(ok, 'it does not back up');
      CheckEquals('The contest log could not be opened, so it was not backed up.',
                  report, 'and says why');
      CheckEquals('ready', Trim(backup.Calls.Text), 'no snapshot was attempted');
      CheckFalse(FileExists(dest + '.new'), 'no staged file');
      CheckFalse(FileExists(dest), 'no destination');
   finally
      backup.Free;
   end;
end;

(* ---------------------------------------------------------------------------
  the happy path
  --------------------------------------------------------------------------- *)

procedure TLogBackupTests.TestFirstBackupPublishes;
var
   source: TLogDatabase;
   backup: TFakeBackup;
   src: string;
   dest: string;
   report: string;
   ok: boolean;
   why: string;
begin
   BeginTest('the first backup publishes a sound log and leaves nothing else');
   src  := TempName('first-src.db');
   dest := TempName('first.db');
   Scrub(src);
   Scrub(dest);

   source := TLogDatabase.Create;
   backup := TFakeBackup.Create(source, dest);
   try
      source.CreateNew(src);
      ok := backup.Run(dest, report);
      CheckTrue(ok, 'it backs up: ' + report);
      CheckEquals('Log backed up to ' + dest + '.', report, 'and says where');
      CheckTrue(FileExists(dest), 'the destination exists');
      CheckFalse(FileExists(dest + '.new'), 'the staged file is gone');
      CheckFalse(FileExists(dest + '.bak'), 'there was nothing to displace');
   finally
      backup.Free;
      source.Free;
   end;

   (* The published file is itself sound, not merely present. *)
   CheckTrue(StagedBackupIsSound(dest, why), 'the published backup opens and '
             + 'passes its integrity check: ' + why);

   Scrub(src);
   Scrub(dest);
end;

procedure TLogBackupTests.TestSnapshotIsStagedAndVerifiedNotWrittenInPlace;
var
   source: TLogDatabase;
   backup: TFakeBackup;
   src: string;
   dest: string;
   report: string;
begin
   (* THE DESTINATION IS NEVER WRITTEN IN PLACE: when the snapshot is taken the
     old backup is still there, byte for byte, and the snapshot goes to .new.
     And it is .new that is verified -- verifying the destination would be
     checking the OLD backup. *)
   BeginTest('the snapshot goes to .new and .new is what is verified');
   src  := TempName('staged-src.db');
   dest := TempName('staged.db');
   Scrub(src);
   Scrub(dest);
   WriteBytes(dest, 'OLD BACKUP');

   source := TLogDatabase.Create;
   backup := TFakeBackup.Create(source, dest);
   try
      source.CreateNew(src);
      CheckTrue(backup.Run(dest, report), 'it backs up: ' + report);
      CheckEquals(3, backup.Calls.Count, 'three questions were asked');
      if backup.Calls.Count = 3 then
         begin
         CheckEquals('ready', backup.Calls[0], 'first: is the log ready');
         CheckEquals('snapshot ' + dest + '.new', backup.Calls[1],
                     'second: snapshot to the STAGED name');
         CheckEquals('verify ' + dest + '.new', backup.Calls[2],
                     'third: verify the STAGED file');
         end;
      CheckEquals('OLD BACKUP', string(backup.DestinationAtSnapshot),
                  'the old backup was untouched while the snapshot was taken');
   finally
      backup.Free;
      source.Free;
   end;

   Scrub(src);
   Scrub(dest);
end;

procedure TLogBackupTests.TestPublishIsARenameAndTheOldBackupBecomesBak;
var
   source: TLogDatabase;
   backup: TFakeBackup;
   src: string;
   dest: string;
   report: string;
   staged: RawByteString;
   snapped: RawByteString;
begin
   (* A RENAME, NOT A COPY: after publishing, .new is gone and the destination
     holds exactly the bytes .new held when verification returned. A copy
     would leave .new behind.

     THE BYTES COMPARED ARE THE POST-VERIFICATION ONES, and that is a finding
     rather than a convenience (measured 2026-09-18). Verification opens .new
     through TLogDatabase.Open, whose PRAGMA journal_mode = WAL is a WRITE:
     four header bytes change -- offsets 18 and 19 (rollback journal to WAL),
     27 (the change counter) and 95 (version-valid-for), each 1 to 2 -- and no
     page content. So what is published is the snapshot converted to WAL
     mode, not the snapshot byte for byte. Reported to NY4I; not changed
     here, because this unit is an extraction. *)
   BeginTest('publishing renames .new over the destination and keeps the old as .bak');
   src  := TempName('publish-src.db');
   dest := TempName('publish.db');
   Scrub(src);
   Scrub(dest);
   WriteBytes(dest, 'OLD BACKUP');

   source := TLogDatabase.Create;
   backup := TFakeBackup.Create(source, dest);
   try
      source.CreateNew(src);
      CheckTrue(backup.Run(dest, report), 'it backs up: ' + report);
      staged := backup.VerifiedBytes;
      snapped := backup.StagedBytes;
   finally
      backup.Free;
      source.Free;
   end;

   CheckTrue(Length(snapped) > 0, 'the snapshot produced bytes');
   CheckTrue(Length(staged) > 0, 'and they were still there after verification');
   CheckTrue(ReadBytes(dest) = staged, 'the destination holds the verified bytes');
   CheckFalse(FileExists(dest + '.new'), 'and .new is gone -- it was renamed');
   CheckEquals('OLD BACKUP', string(ReadBytes(dest + '.bak')),
               'the previous backup was displaced to .bak, not deleted');

   Scrub(src);
   Scrub(dest);
end;

procedure TLogBackupTests.TestAnOlderBakIsReplacedByTheDisplacedBackup;
var
   source: TLogDatabase;
   backup: TFakeBackup;
   src: string;
   dest: string;
   report: string;
begin
   (* ONE GENERATION BACK, NOT TWO: the displaced backup replaces an older
     .bak. *)
   BeginTest('an older .bak is replaced by the backup it displaces');
   src  := TempName('older-src.db');
   dest := TempName('older.db');
   Scrub(src);
   Scrub(dest);
   WriteBytes(dest, 'OLD BACKUP');
   WriteBytes(dest + '.bak', 'OLDER BACKUP');

   source := TLogDatabase.Create;
   backup := TFakeBackup.Create(source, dest);
   try
      source.CreateNew(src);
      CheckTrue(backup.Run(dest, report), 'it backs up: ' + report);
   finally
      backup.Free;
      source.Free;
   end;

   CheckEquals('OLD BACKUP', string(ReadBytes(dest + '.bak')),
               '.bak is now the backup that was just displaced');

   Scrub(src);
   Scrub(dest);
end;

procedure TLogBackupTests.TestAnOlderBakIsKeptWhenThereIsNothingToDisplace;
var
   source: TLogDatabase;
   backup: TFakeBackup;
   src: string;
   dest: string;
   report: string;
begin
   (* .bak IS ONLY TOUCHED WHEN THERE IS A DESTINATION TO DISPLACE. With no
     destination -- the operator deleted it, or a crash fell between the two
     renames -- an existing .bak is the only good copy, and it stays. *)
   BeginTest('with no destination to displace, an older .bak is left alone');
   src  := TempName('keepbak-src.db');
   dest := TempName('keepbak.db');
   Scrub(src);
   Scrub(dest);
   WriteBytes(dest + '.bak', 'OLDER BACKUP');

   source := TLogDatabase.Create;
   backup := TFakeBackup.Create(source, dest);
   try
      source.CreateNew(src);
      CheckTrue(backup.Run(dest, report), 'it backs up: ' + report);
   finally
      backup.Free;
      source.Free;
   end;

   CheckTrue(FileExists(dest), 'the new backup is published');
   CheckEquals('OLDER BACKUP', string(ReadBytes(dest + '.bak')),
               'and the older .bak is untouched');

   Scrub(src);
   Scrub(dest);
end;

procedure TLogBackupTests.TestAStaleStagedFileIsDiscardedFirst;
var
   source: TLogDatabase;
   backup: TFakeBackup;
   src: string;
   dest: string;
   report: string;
begin
   (* A .new left by an interrupted run would make the snapshot refuse -- SQLite
     will not VACUUM INTO an existing file -- so it goes first. *)
   BeginTest('a .new left by an interrupted run is discarded before the snapshot');
   src  := TempName('stale-src.db');
   dest := TempName('stale.db');
   Scrub(src);
   Scrub(dest);
   WriteBytes(dest + '.new', 'LEFT BY A CRASH');

   source := TLogDatabase.Create;
   backup := TFakeBackup.Create(source, dest);
   try
      source.CreateNew(src);
      CheckTrue(backup.Run(dest, report), 'it backs up: ' + report);
      CheckFalse(backup.StagedExistedAtSnapshot,
                 'the stale file was gone when the snapshot was taken');
   finally
      backup.Free;
      source.Free;
   end;

   CheckFalse(FileExists(dest + '.new'), 'and nothing is left staged');

   Scrub(src);
   Scrub(dest);
end;

(* ---------------------------------------------------------------------------
  failures
  --------------------------------------------------------------------------- *)

procedure TLogBackupTests.TestCorruptSnapshotIsRejectedAndThePriorBackupSurvives;
var
   backup: TFakeBackup;
   dest: string;
   report: string;
   ok: boolean;
   prefix: string;
begin
   (* THE ONE THAT MATTERS: a snapshot that is not a sound database never
     replaces a backup that is. The real verifier judges it. *)
   BeginTest('a corrupt snapshot is rejected and the previous backup survives');
   dest := TempName('corrupt.db');
   Scrub(dest);
   WriteBytes(dest, 'OLD BACKUP');
   WriteBytes(dest + '.bak', 'OLDER BACKUP');

   backup := TFakeBackup.Create(nil, dest);
   try
      backup.Kind := skGarbage;
      ok := backup.Run(dest, report);
   finally
      backup.Free;
   end;

   CheckFalse(ok, 'it does not report success');
   prefix := 'The backup of ' + dest + ' failed its integrity check and was discarded: ';
   CheckEquals(prefix, Copy(report, 1, Length(prefix)),
               'the report says so and names the file');
   CheckTrue(Length(report) > Length(prefix),
             'and carries SQLite''s reason: ' + report);
   CheckFalse(FileExists(dest + '.new'), 'the rejected snapshot is deleted');
   CheckEquals('OLD BACKUP', string(ReadBytes(dest)),
               'the previous backup is exactly where it was');
   CheckEquals('OLDER BACKUP', string(ReadBytes(dest + '.bak')),
               'and so is .bak');

   Scrub(dest);
end;

procedure TLogBackupTests.TestSnapshotThatRaisesLeavesNoStagedFile;
var
   backup: TFakeBackup;
   dest: string;
   report: string;
   ok: boolean;
begin
   (* A SNAPSHOT THAT FAILS HALFWAY -- the disk filled -- leaves half a file.
     It is deleted, the backups stand, and the run does not raise. *)
   BeginTest('a snapshot that raises part-way leaves no .new and no damage');
   dest := TempName('raises.db');
   Scrub(dest);
   WriteBytes(dest, 'OLD BACKUP');
   WriteBytes(dest + '.bak', 'OLDER BACKUP');

   backup := TFakeBackup.Create(nil, dest);
   try
      backup.Kind := skPartialThenRaise;
      ok := backup.Run(dest, report);
   finally
      backup.Free;
   end;

   CheckFalse(ok, 'it does not report success');
   CheckEquals('The backup to ' + dest + ' failed: the backup volume is full',
               report, 'the report names the file and carries the reason');
   CheckFalse(FileExists(dest + '.new'), 'the partial snapshot is deleted');
   CheckEquals('OLD BACKUP', string(ReadBytes(dest)), 'the backup is untouched');
   CheckEquals('OLDER BACKUP', string(ReadBytes(dest + '.bak')),
               'and so is .bak');

   Scrub(dest);
end;

procedure TLogBackupTests.TestVerifierThatRaisesLeavesNoStagedFile;
var
   source: TLogDatabase;
   backup: TFakeBackup;
   src: string;
   dest: string;
   report: string;
   ok: boolean;
begin
   (* The real verifier cannot raise, but a failure AT ANY STEP is the
     contract, and the step after the snapshot is the one where a complete,
     unverified .new exists. *)
   BeginTest('a verifier that raises leaves no .new and no damage');
   src  := TempName('vraises-src.db');
   dest := TempName('vraises.db');
   Scrub(src);
   Scrub(dest);
   WriteBytes(dest, 'OLD BACKUP');

   source := TLogDatabase.Create;
   backup := TFakeBackup.Create(source, dest);
   try
      source.CreateNew(src);
      backup.VerifyRaises := True;
      ok := backup.Run(dest, report);
   finally
      backup.Free;
      source.Free;
   end;

   CheckFalse(ok, 'it does not report success');
   CheckEquals('The backup to ' + dest + ' failed: the verifier fell over',
               report, 'the report names the file and carries the reason');
   CheckFalse(FileExists(dest + '.new'), 'the unverified snapshot is deleted');
   CheckEquals('OLD BACKUP', string(ReadBytes(dest)), 'the backup is untouched');
   CheckFalse(FileExists(dest + '.bak'), 'and nothing was displaced');

   Scrub(src);
   Scrub(dest);
end;

procedure TLogBackupTests.TestFailedPublishKeepsTheVerifiedCopyAndNamesIt;
var
   source: TLogDatabase;
   backup: TFakeBackup;
   src: string;
   dest: string;
   report: string;
   ok: boolean;
begin
   (* THE ONE FAILURE THAT KEEPS .new, on purpose: the file has been written AND
     verified, so it is the newest good copy there is, and the report says
     where it is.

     The rename is made to fail by putting a DIRECTORY at the destination
     name. That fails on every platform -- MoveFileW refuses any existing
     target and rename(2) refuses a file over a directory -- and FileExists
     is False for a directory on both, so nothing is displaced first. *)
   BeginTest('a publish rename that fails keeps the verified .new and names it');
   src  := TempName('pubfail-src.db');
   dest := TempName('pubfail.db');
   Scrub(src);
   Scrub(dest);
   CreateDir(dest);

   source := TLogDatabase.Create;
   backup := TFakeBackup.Create(source, dest);
   try
      source.CreateNew(src);
      ok := backup.Run(dest, report);
   finally
      backup.Free;
      source.Free;
   end;

   CheckFalse(ok, 'it does not report success');
   CheckEquals('The backup was written and verified but could not be renamed to '
               + dest + '. It is at ' + dest + '.new.',
               report, 'the report names both files');
   CheckTrue(FileExists(dest + '.new'), 'the verified copy is kept');
   CheckFalse(FileExists(dest + '.bak'), 'nothing was displaced');

   Scrub(src);
   Scrub(dest);
end;

(* ---------------------------------------------------------------------------
  the verifier itself
  --------------------------------------------------------------------------- *)

procedure TLogBackupTests.TestSoundAcceptsARealSnapshotAndReleasesIt;
var
   source: TLogDatabase;
   src: string;
   snap: string;
   why: string;
begin
   (* RELEASES IT: the publish step renames the file straight after, and on
     Windows an open file cannot be renamed. Deleting it is the same test. *)
   BeginTest('StagedBackupIsSound accepts a real snapshot and lets go of it');
   src  := TempName('sound-src.db');
   snap := TempName('sound-snap.db');
   Scrub(src);
   Scrub(snap);

   source := TLogDatabase.Create;
   try
      source.CreateNew(src);
      source.SnapshotTo(snap);
   finally
      source.Free;
   end;

   CheckTrue(StagedBackupIsSound(snap, why), 'a real snapshot is sound: ' + why);
   CheckEquals('', why, 'and there is nothing to say about it');
   CheckTrue(DeleteFile(snap), 'the file is not held open afterwards');

   Scrub(src);
   Scrub(snap);
end;

procedure TLogBackupTests.TestSoundRejectsGarbage;
var
   snap: string;
   why: string;
begin
   BeginTest('StagedBackupIsSound rejects a file that is not a database');
   snap := TempName('garbage.db');
   Scrub(snap);
   WriteBytes(snap, 'this is not a database, whatever the name says');

   CheckFalse(StagedBackupIsSound(snap, why), 'garbage is not sound');
   CheckTrue(why <> '', 'and the reason is given');
   CheckTrue(DeleteFile(snap), 'the file is not held open afterwards');

   Scrub(snap);
end;

procedure TLogBackupTests.TestSoundRejectsAMissingFile;
var
   why: string;
begin
   (* Not "created empty and found sound" -- TLogDatabase.Open refuses a
     missing file rather than letting SQLite make one. *)
   BeginTest('StagedBackupIsSound rejects a file that is not there');
   CheckFalse(StagedBackupIsSound(TempName('never-written.db'), why),
              'a missing file is not sound');
   CheckTrue(why <> '', 'and the reason is given');
   CheckFalse(FileExists(TempName('never-written.db')),
              'and checking it did not create it');
end;

procedure TLogBackupTests.RunAllTests;
begin
   TestBlankDestinationIsRefusedBeforeTheLogIsAsked;
   TestUnopenedLogIsReportedAndNothingIsWritten;

   TestFirstBackupPublishes;
   TestSnapshotIsStagedAndVerifiedNotWrittenInPlace;
   TestPublishIsARenameAndTheOldBackupBecomesBak;
   TestAnOlderBakIsReplacedByTheDisplacedBackup;
   TestAnOlderBakIsKeptWhenThereIsNothingToDisplace;
   TestAStaleStagedFileIsDiscardedFirst;

   TestCorruptSnapshotIsRejectedAndThePriorBackupSurvives;
   TestSnapshotThatRaisesLeavesNoStagedFile;
   TestVerifierThatRaisesLeavesNoStagedFile;
   TestFailedPublishKeepsTheVerifiedCopyAndNamesIt;

   TestSoundAcceptsARealSnapshotAndReleasesIt;
   TestSoundRejectsGarbage;
   TestSoundRejectsAMissingFile;

   if (FDir <> '') and DirectoryExists(FDir) then
      begin
      RemoveDir(FDir);
      end;
end;

end.
