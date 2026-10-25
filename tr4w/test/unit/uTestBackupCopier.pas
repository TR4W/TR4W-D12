unit uTestBackupCopier;

(* THE BACKUP DESTINATION (issue #98 step 2) -- the copier, and the setting.

  TBackupCopier (src/domain/uBackupCopier.pas) copies each verified local
  backup to a folder on another disk, on its own thread. These tests drive it
  with REAL files in a scratch directory -- what is pinned is which files exist
  in the destination, under which names, holding which bytes -- and with a
  file-operations object that can be told to corrupt a copy, refuse a rename
  or BLOCK, the way a hung share does.

  NOTHING HERE TOUCHES uAppPaths.BackupDir or the real settings: the copier is
  handed its folders, and the settings tests build their own TR4WSettings.

  WAITING. The worker is a real thread, so each test waits for it with
  WaitUntilSettled (nothing in flight, nothing due) rather than sleeping. A
  failed job waits out its retry, which is set to a minute here, so a test
  moves it on with RetryNow -- the retry clock itself is not what is pinned. *)

{$I ..\..\src\tr4w.inc}

interface

uses
   uTR4WTestFramework;

type
   TBackupCopierTests = class(TTestCase)
   private
      FDir: string;
      function Root: string;
      function LocalDir: string;
      function OutboxDir: string;
      function DestDir: string;
      procedure Scrub(const aDir: string);
      procedure ScrubAll;
   protected
      procedure TestACopyArrivesAndThePreviousBecomesBak;
      procedure TestAMissingDestinationIsReportedOnceAndRecoveryOnce;
      procedure TestACorruptedCopyIsRejectedAndTheFinalIsKept;
      procedure TestAFailedPublishPutsBackTheFinalAndTheBak;
      procedure TestNewerGenerationsCoalesce;
      procedure TestShutdownIsBoundedWhileTheDestinationHangs;
      procedure TestTheProbeRunsOffTheCallersThread;
      procedure TestADestinationChangeForgetsTheOldOneAndProbes;
      procedure TestAnUnchangedCopyIsNotCopiedAgainAtOpen;
      procedure TestTheLocalBackupFolderIsNotADestination;
      procedure TestLeftoverOutboxFilesAreDeletedAtStart;
   public
      procedure RunAllTests; override;
   end;

   TBackupDestinationSettingTests = class(TTestCase)
   protected
      procedure TestTheDefaultIsLocalOnly;
      procedure TestAFormerFileNameCarriesItsFolder;
      procedure TestABareFormerFileNameMeansLocalOnly;
      procedure TestADestinationIsTakenAsWritten;
      procedure TestASettingsFileWithTheFormerMemberIsConverted;
      procedure TestTheFormerCommandInTheLegacyBucketIsConverted;
      procedure TestTheSettingsFileNoLongerCarriesTheFormerMember;
   public
      procedure RunAllTests; override;
   end;

   (* WHAT THE STATUS LINE SAYS (uBackupCopyService's two pure functions).
     NY4I saw only the local file's name after Backup Log and concluded the
     destination was ignored; the copy had worked. *)
   TBackupCopyNoticeTests = class(TTestCase)
   protected
      procedure TestAQueuedCopyNamesTheDestinationNotTheLocalFile;
      procedure TestNoDestinationKeepsTheLocalReport;
      procedure TestAFailedQueueingSaysWhy;
      procedure TestEveryCopierEventHasANoticeAndOnlyAFailureBeeps;
   public
      procedure RunAllTests; override;
   end;

implementation

uses
   SysUtils, Classes, SyncObjs, uJSON, uKeychain, uSettingsModel, uBackupCopier,
   uBackupCopyService, uAppStrings;

const
   ABSENT = '<absent>';
   (* Long enough that a failed job is never retried by the clock during a
     test: RetryNow moves it on. *)
   TEST_RETRY_MS = 60000;
   SETTLE_MS = 10000;
   FINAL_NAME = 'CQ-WW-SSB NY4I periodic.db';

type
   (* WHAT THE WORKER REPORTED, counted. Written on the worker thread, read
     on the test's, so under a lock. *)
   TReportRecorder = class(TObject)
   private
      FLock: TCriticalSection;
      FCounts: array[TBackupCopyEvent] of integer;
      FLastDetail: string;
   public
      constructor Create;
      destructor Destroy; override;
      procedure Received(aEvent: TBackupCopyEvent; const aDestination, aDetail: string);
      function Count(aEvent: TBackupCopyEvent): integer;
      function LastDetail: string;
   end;

   (* FILE OPERATIONS THAT MISBEHAVE ON REQUEST. Only operations aimed at the
     destination are affected -- a target ending in .partial, or a probe file
     -- so Submit's local outbox copy is never blocked or corrupted. *)
   TFaultyOps = class(TBackupFileOps)
   private
      FLock: TCriticalSection;
      FPartialCopies: integer;
   public
      CorruptPartials: boolean;
      RefuseRenameOfPartial: boolean;
      BlockPartials: boolean;
      BlockProbes: boolean;
      Entered: TEvent;
      Release: TEvent;
      constructor Create;
      destructor Destroy; override;
      procedure CopyFile(const aSource, aTarget: string); override;
      procedure WriteFile(const aTarget: string; const aBytes: TBytes); override;
      function RenameFile(const aOld, aNew: string): boolean; override;
      function PartialCopies: integer;
   end;

function EndsWith(const aText, aTail: string): boolean;
begin
   Result := (Length(aText) >= Length(aTail)) and
             (Copy(aText, Length(aText) - Length(aTail) + 1, Length(aTail)) = aTail);
end;

procedure WriteText(const aPath: string; const aText: RawByteString);
var
   fs: TFileStream;
begin
   fs := TFileStream.Create(aPath, fmCreate);
   try
      if Length(aText) > 0 then
         begin
         fs.WriteBuffer(aText[1], Length(aText));
         end;
   finally
      fs.Free;
   end;
end;

function ReadText(const aPath: string): RawByteString;
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

(* The names in aDir that end in aTail, sorted, comma separated; '' for none. *)
function NamesEndingIn(const aDir, aTail: string): string;
var
   found: TSearchRec;
   names: TStringList;
begin
   names := TStringList.Create;
   try
      names.Sorted := True;
      if FindFirst(IncludeTrailingPathDelimiter(aDir) + '*', faAnyFile, found) = 0 then
         begin
         repeat
            if ((found.Attr and faDirectory) = 0) and EndsWith(found.Name, aTail) then
               begin
               names.Add(found.Name);
               end;
         until FindNext(found) <> 0;
         FindClose(found);
         end;
      Result := names.CommaText;
   finally
      names.Free;
   end;
end;

function FileCountIn(const aDir: string): integer;
var
   found: TSearchRec;
begin
   Result := 0;
   if FindFirst(IncludeTrailingPathDelimiter(aDir) + '*', faAnyFile, found) = 0 then
      begin
      repeat
         if (found.Attr and faDirectory) = 0 then
            begin
            Inc(Result);
            end;
      until FindNext(found) <> 0;
      FindClose(found);
      end;
end;

(* ---------------------------------------------------------------------------
  TReportRecorder
  --------------------------------------------------------------------------- *)

constructor TReportRecorder.Create;
var
   e: TBackupCopyEvent;
begin
   inherited Create;
   FLock := TCriticalSection.Create;
   for e := Low(TBackupCopyEvent) to High(TBackupCopyEvent) do
      begin
      FCounts[e] := 0;
      end;
   FLastDetail := '';
end;

destructor TReportRecorder.Destroy;
begin
   FLock.Free;
   inherited Destroy;
end;

procedure TReportRecorder.Received(aEvent: TBackupCopyEvent;
   const aDestination, aDetail: string);
begin
   FLock.Acquire;
   try
      Inc(FCounts[aEvent]);
      if aEvent = bceFailed then
         begin
         FLastDetail := aDetail;
         end;
   finally
      FLock.Release;
   end;
end;

function TReportRecorder.Count(aEvent: TBackupCopyEvent): integer;
begin
   FLock.Acquire;
   try
      Result := FCounts[aEvent];
   finally
      FLock.Release;
   end;
end;

function TReportRecorder.LastDetail: string;
begin
   FLock.Acquire;
   try
      Result := FLastDetail;
   finally
      FLock.Release;
   end;
end;

(* ---------------------------------------------------------------------------
  TFaultyOps
  --------------------------------------------------------------------------- *)

constructor TFaultyOps.Create;
begin
   inherited Create;
   FLock := TCriticalSection.Create;
   FPartialCopies := 0;
   CorruptPartials := False;
   RefuseRenameOfPartial := False;
   BlockPartials := False;
   BlockProbes := False;
   Entered := TEvent.Create(nil, True, False, '');
   Release := TEvent.Create(nil, True, False, '');
end;

destructor TFaultyOps.Destroy;
begin
   Release.Free;
   Entered.Free;
   FLock.Free;
   inherited Destroy;
end;

procedure TFaultyOps.CopyFile(const aSource, aTarget: string);
var
   fs: TFileStream;
   b: Byte;
begin
   if not EndsWith(aTarget, BACKUP_PARTIAL_SUFFIX) then
      begin
      inherited CopyFile(aSource, aTarget);
      Exit;
      end;

   FLock.Acquire;
   try
      Inc(FPartialCopies);
   finally
      FLock.Release;
   end;

   if BlockPartials then
      begin
      Entered.SetEvent;
      Release.WaitFor(INFINITE);
      end;

   inherited CopyFile(aSource, aTarget);

   if CorruptPartials then
      begin
      (* SAME SIZE, ONE BYTE DIFFERENT -- the corruption a size check misses. *)
      fs := TFileStream.Create(aTarget, fmOpenReadWrite or fmShareDenyNone);
      try
         fs.Position := 0;
         fs.ReadBuffer(b, 1);
         b := b xor $FF;
         fs.Position := 0;
         fs.WriteBuffer(b, 1);
      finally
         fs.Free;
      end;
      end;
end;

procedure TFaultyOps.WriteFile(const aTarget: string; const aBytes: TBytes);
begin
   if BlockProbes then
      begin
      Entered.SetEvent;
      Release.WaitFor(INFINITE);
      end;
   inherited WriteFile(aTarget, aBytes);
end;

function TFaultyOps.RenameFile(const aOld, aNew: string): boolean;
begin
   if RefuseRenameOfPartial and EndsWith(aOld, BACKUP_PARTIAL_SUFFIX) then
      begin
      Result := False;
      Exit;
      end;
   Result := inherited RenameFile(aOld, aNew);
end;

function TFaultyOps.PartialCopies: integer;
begin
   FLock.Acquire;
   try
      Result := FPartialCopies;
   finally
      FLock.Release;
   end;
end;

(* ---------------------------------------------------------------------------
  fixture
  --------------------------------------------------------------------------- *)

function TBackupCopierTests.Root: string;
begin
   if FDir = '' then
      begin
      FDir := IncludeTrailingPathDelimiter(GetTempDir) +
              'tr4w_backupcopier_' + IntToStr(GetProcessID);
      end;
   Result := IncludeTrailingPathDelimiter(FDir);
end;

function TBackupCopierTests.LocalDir: string;
begin
   Result := Root + 'local';
end;

function TBackupCopierTests.OutboxDir: string;
begin
   Result := Root + 'outbox';
end;

function TBackupCopierTests.DestDir: string;
begin
   Result := Root + 'dest';
end;

procedure TBackupCopierTests.Scrub(const aDir: string);
var
   found: TSearchRec;
begin
   if not DirectoryExists(aDir) then
      begin
      Exit;
      end;
   if FindFirst(IncludeTrailingPathDelimiter(aDir) + '*', faAnyFile, found) = 0 then
      begin
      repeat
         if (found.Attr and faDirectory) = 0 then
            begin
            DeleteFile(IncludeTrailingPathDelimiter(aDir) + found.Name);
            end;
      until FindNext(found) <> 0;
      FindClose(found);
      end;
   RemoveDir(aDir);
end;

(* Every folder a test makes, emptied and removed, and the three a test uses
  made again, empty. *)
procedure TBackupCopierTests.ScrubAll;
begin
   Scrub(LocalDir);
   Scrub(OutboxDir);
   Scrub(DestDir);
   Scrub(DestDir + '-away');
   Scrub(Root + 'other');
   ForceDirectories(LocalDir);
   ForceDirectories(DestDir);
end;

(* ---------------------------------------------------------------------------
  the copier
  --------------------------------------------------------------------------- *)

procedure TBackupCopierTests.TestACopyArrivesAndThePreviousBecomesBak;
var
   rec: TReportRecorder;
   copier: TBackupCopier;
   local, final, why: string;
begin
   BeginTest('a copy arrives verified under its final name, and the previous copy becomes .bak');
   ScrubAll;
   local := IncludeTrailingPathDelimiter(LocalDir) + FINAL_NAME;
   final := IncludeTrailingPathDelimiter(DestDir) + FINAL_NAME;
   rec := TReportRecorder.Create;
   copier := TBackupCopier.Create(TBackupFileOps.Create, OutboxDir, TEST_RETRY_MS, rec.Received);
   try
      copier.SetDestination(DestDir);
      CheckTrue(copier.WaitUntilSettled(SETTLE_MS), 'the probe settles');
      CheckEquals(1, rec.Count(bceReachable), 'the destination is reported reachable once');

      WriteText(local, 'generation one');
      CheckTrue(copier.Submit(local, False, why), 'the first generation is queued: ' + why);
      CheckTrue(copier.WaitUntilSettled(SETTLE_MS), 'and settles');
      CheckEquals('generation one', ReadText(final), 'it arrives under the final name');
      CheckEquals(ABSENT, ReadText(final + '.bak'), 'with nothing to displace, there is no .bak');

      WriteText(local, 'generation two');
      CheckTrue(copier.Submit(local, False, why), 'the second is queued: ' + why);
      CheckTrue(copier.WaitUntilSettled(SETTLE_MS), 'and settles');
      CheckEquals('generation two', ReadText(final), 'the newer generation is the final');
      CheckEquals('generation one', ReadText(final + '.bak'), 'the previous one is the .bak');
      CheckEquals('', NamesEndingIn(DestDir, BACKUP_PARTIAL_SUFFIX), 'no .partial is left');
      CheckEquals('', NamesEndingIn(DestDir, '.old'), 'no moved-aside file is left');
      CheckEquals(2, FileCountIn(DestDir), 'the destination holds the final and the .bak only');
      CheckEquals(0, FileCountIn(OutboxDir), 'the outbox is empty once both arrived');
      CheckEquals(2, rec.Count(bceCopied), 'each generation is reported copied');
      CheckEquals(0, rec.Count(bceFailed), 'and nothing failed');
      CheckEquals('generation two', ReadText(local), 'the local backup is untouched');
   finally
      copier.Free;
      rec.Free;
   end;
end;

procedure TBackupCopierTests.TestAMissingDestinationIsReportedOnceAndRecoveryOnce;
var
   rec: TReportRecorder;
   copier: TBackupCopier;
   local, why, away: string;
   attempts: integer;
begin
   BeginTest('a destination that goes away is reported ONCE, kept intact, and its recovery reported ONCE');
   ScrubAll;
   local := IncludeTrailingPathDelimiter(LocalDir) + FINAL_NAME;
   away := DestDir + '-away';
   rec := TReportRecorder.Create;
   copier := TBackupCopier.Create(TBackupFileOps.Create, OutboxDir, TEST_RETRY_MS, rec.Received);
   try
      copier.SetDestination(DestDir);
      WriteText(local, 'generation one');
      CheckTrue(copier.Submit(local, False, why), 'queued: ' + why);
      CheckTrue(copier.WaitUntilSettled(SETTLE_MS), 'the first copy settles');

      (* THE SHARE GOES: its folder is moved away, contents and all, so what
        it held can be inspected afterwards. *)
      CheckTrue(RenameFile(DestDir, away), 'the destination is taken away');
      WriteText(local, 'generation two');
      CheckTrue(copier.Submit(local, False, why), 'the next generation is still queued: ' + why);
      CheckTrue(copier.WaitUntilSettled(SETTLE_MS), 'the failed attempt settles');
      CheckEquals(1, rec.Count(bceFailed), 'the failure is reported');
      CheckTrue(Pos(DestDir, rec.LastDetail) > 0, 'naming the folder: ' + rec.LastDetail);
      CheckTrue(copier.Health = bdhFailing, 'the destination is failing');
      CheckEquals(1, copier.PendingCount, 'the generation waits to be retried');

      copier.RetryNow;
      CheckTrue(copier.WaitUntilSettled(SETTLE_MS), 'a retry settles');
      copier.RetryNow;
      CheckTrue(copier.WaitUntilSettled(SETTLE_MS), 'and another');
      attempts := copier.Attempts;
      CheckTrue(attempts >= 3, 'the copy was tried again: ' + IntToStr(attempts) + ' attempts');
      CheckEquals(1, rec.Count(bceFailed), 'and repeated failures are NOT reported again');
      CheckFalse(DirectoryExists(DestDir), 'the copier never creates the destination folder');
      CheckEquals('generation one', ReadText(IncludeTrailingPathDelimiter(away) + FINAL_NAME),
                  'the previous copy is exactly as it was');
      CheckEquals('', NamesEndingIn(away, BACKUP_PARTIAL_SUFFIX), 'and no .partial is beside it');

      (* THE SHARE COMES BACK. *)
      CheckTrue(RenameFile(away, DestDir), 'the destination returns');
      copier.RetryNow;
      CheckTrue(copier.WaitUntilSettled(SETTLE_MS), 'the retry settles');
      CheckEquals(1, rec.Count(bceRecovered), 'the recovery is reported once');
      CheckEquals(1, rec.Count(bceFailed), 'and the failure still only once');
      CheckTrue(copier.Health = bdhWorking, 'the destination is working');
      CheckEquals('generation two',
                  ReadText(IncludeTrailingPathDelimiter(DestDir) + FINAL_NAME),
                  'the waiting generation arrived');
      CheckEquals('generation one',
                  ReadText(IncludeTrailingPathDelimiter(DestDir) + FINAL_NAME + '.bak'),
                  'and the previous copy is its .bak');
      CheckEquals(0, copier.PendingCount, 'nothing waits');
      CheckEquals(0, FileCountIn(OutboxDir), 'and the outbox is empty');
   finally
      copier.Free;
      rec.Free;
   end;
end;

procedure TBackupCopierTests.TestACorruptedCopyIsRejectedAndTheFinalIsKept;
var
   rec: TReportRecorder;
   ops: TFaultyOps;
   copier: TBackupCopier;
   local, final, why: string;
begin
   BeginTest('a copy that does not read back the same is rejected, and the final is kept');
   ScrubAll;
   local := IncludeTrailingPathDelimiter(LocalDir) + FINAL_NAME;
   final := IncludeTrailingPathDelimiter(DestDir) + FINAL_NAME;
   rec := TReportRecorder.Create;
   ops := TFaultyOps.Create;
   copier := TBackupCopier.Create(ops, OutboxDir, TEST_RETRY_MS, rec.Received);
   try
      copier.SetDestination(DestDir);
      WriteText(local, 'generation one');
      CheckTrue(copier.Submit(local, False, why), 'queued: ' + why);
      CheckTrue(copier.WaitUntilSettled(SETTLE_MS), 'the first copy settles');

      ops.CorruptPartials := True;
      WriteText(local, 'generation two');
      CheckTrue(copier.Submit(local, False, why), 'queued: ' + why);
      CheckTrue(copier.WaitUntilSettled(SETTLE_MS), 'the corrupted copy settles');
      CheckEquals(1, rec.Count(bceFailed), 'the corrupted copy is a failure');
      CheckTrue(Pos('did not read back the same', rec.LastDetail) > 0,
                'and says why: ' + rec.LastDetail);
      CheckEquals('generation one', ReadText(final), 'the final still holds the previous copy');
      CheckEquals(ABSENT, ReadText(final + '.bak'), 'and nothing was displaced');
      CheckEquals('', NamesEndingIn(DestDir, BACKUP_PARTIAL_SUFFIX),
                  'the corrupted .partial is deleted');

      ops.CorruptPartials := False;
      copier.RetryNow;
      CheckTrue(copier.WaitUntilSettled(SETTLE_MS), 'the retry settles');
      CheckEquals(1, rec.Count(bceRecovered), 'the clean retry is a recovery');
      CheckEquals('generation two', ReadText(final), 'and the generation arrives');
   finally
      copier.Free;
      rec.Free;
   end;
end;

procedure TBackupCopierTests.TestAFailedPublishPutsBackTheFinalAndTheBak;
var
   rec: TReportRecorder;
   ops: TFaultyOps;
   copier: TBackupCopier;
   local, final, why: string;
begin
   BeginTest('a publish rename that fails puts the final and the .bak back as they were');
   ScrubAll;
   local := IncludeTrailingPathDelimiter(LocalDir) + FINAL_NAME;
   final := IncludeTrailingPathDelimiter(DestDir) + FINAL_NAME;
   rec := TReportRecorder.Create;
   ops := TFaultyOps.Create;
   copier := TBackupCopier.Create(ops, OutboxDir, TEST_RETRY_MS, rec.Received);
   try
      copier.SetDestination(DestDir);
      WriteText(local, 'generation one');
      CheckTrue(copier.Submit(local, False, why), 'queued: ' + why);
      CheckTrue(copier.WaitUntilSettled(SETTLE_MS), 'settles');
      WriteText(local, 'generation two');
      CheckTrue(copier.Submit(local, False, why), 'queued: ' + why);
      CheckTrue(copier.WaitUntilSettled(SETTLE_MS), 'settles');
      CheckEquals('generation two', ReadText(final), 'the final before the failure');
      CheckEquals('generation one', ReadText(final + '.bak'), 'the .bak before the failure');

      (* The .partial is written and verified; only its rename to the final
        name is refused, AFTER the final and the .bak have been moved. *)
      ops.RefuseRenameOfPartial := True;
      WriteText(local, 'generation three');
      CheckTrue(copier.Submit(local, False, why), 'queued: ' + why);
      CheckTrue(copier.WaitUntilSettled(SETTLE_MS), 'the failed publish settles');
      CheckEquals(1, rec.Count(bceFailed), 'the failed publish is a failure');
      CheckEquals('generation two', ReadText(final), 'the final is back where it was');
      CheckEquals('generation one', ReadText(final + '.bak'), 'and so is the .bak');
      CheckEquals('', NamesEndingIn(DestDir, BACKUP_PARTIAL_SUFFIX), 'no .partial is left');
      CheckEquals('', NamesEndingIn(DestDir, '.old'), 'no moved-aside file is left');
      CheckEquals(2, FileCountIn(DestDir), 'and nothing else is there');
   finally
      copier.Free;
      rec.Free;
   end;
end;

procedure TBackupCopierTests.TestNewerGenerationsCoalesce;
var
   rec: TReportRecorder;
   ops: TFaultyOps;
   copier: TBackupCopier;
   local, final, why: string;
   i: integer;
begin
   BeginTest('generations that arrive while a copy is in flight coalesce: only the newest is sent');
   ScrubAll;
   local := IncludeTrailingPathDelimiter(LocalDir) + FINAL_NAME;
   final := IncludeTrailingPathDelimiter(DestDir) + FINAL_NAME;
   rec := TReportRecorder.Create;
   ops := TFaultyOps.Create;
   copier := TBackupCopier.Create(ops, OutboxDir, TEST_RETRY_MS, rec.Received);
   try
      copier.SetDestination(DestDir);
      CheckTrue(copier.WaitUntilSettled(SETTLE_MS), 'the probe settles');

      ops.BlockPartials := True;
      WriteText(local, 'generation 1');
      CheckTrue(copier.Submit(local, False, why), 'queued: ' + why);
      CheckTrue(ops.Entered.WaitFor(SETTLE_MS) = wrSignaled, 'the first copy is in flight');

      for i := 2 to 4 do
         begin
         WriteText(local, 'generation ' + IntToStr(i));
         CheckTrue(copier.Submit(local, False, why), 'queued while in flight: ' + why);
         end;
      CheckEquals(1, copier.PendingCount, 'three newer generations leave ONE pending');
      CheckEquals(2, FileCountIn(OutboxDir),
                  'the outbox holds the one in flight and the newest, nothing else');

      ops.BlockPartials := False;
      ops.Release.SetEvent;
      CheckTrue(copier.WaitUntilSettled(SETTLE_MS), 'everything settles');
      CheckEquals(2, ops.PartialCopies, 'two copies were made, not four');
      CheckEquals('generation 4', ReadText(final), 'the newest is the final');
      CheckEquals('generation 1', ReadText(final + '.bak'), 'the one in flight is the .bak');
      CheckEquals(0, FileCountIn(OutboxDir), 'and the outbox is empty');
   finally
      ops.Release.SetEvent;
      copier.Free;
      rec.Free;
   end;
end;

procedure TBackupCopierTests.TestShutdownIsBoundedWhileTheDestinationHangs;
var
   rec: TReportRecorder;
   ops: TFaultyOps;
   copier: TBackupCopier;
   local, why: string;
   started, elapsed: QWord;
   stopped: boolean;
begin
   BeginTest('shutdown returns within its bound while a copy to the destination hangs');
   ScrubAll;
   local := IncludeTrailingPathDelimiter(LocalDir) + FINAL_NAME;
   rec := TReportRecorder.Create;
   ops := TFaultyOps.Create;
   copier := TBackupCopier.Create(ops, OutboxDir, TEST_RETRY_MS, rec.Received);
   try
      copier.SetDestination(DestDir);
      CheckTrue(copier.WaitUntilSettled(SETTLE_MS), 'the probe settles');
      ops.BlockPartials := True;
      WriteText(local, 'generation one');

      started := GetTickCount64;
      CheckTrue(copier.Submit(local, False, why), 'queued: ' + why);
      CheckTrue(GetTickCount64 - started < 2000, 'Submit returns without waiting for the share');
      CheckTrue(ops.Entered.WaitFor(SETTLE_MS) = wrSignaled, 'the copy is hung in flight');

      started := GetTickCount64;
      stopped := copier.Shutdown(200);
      elapsed := GetTickCount64 - started;
      CheckFalse(stopped, 'shutdown says the worker is still inside the copy');
      CheckTrue(elapsed < 2000, 'and returns within its bound: ' + IntToStr(elapsed) + ' ms');
      CheckFalse(copier.Submit(local, False, why), 'a stopped copier queues nothing');
   finally
      (* The hang ends, so the worker can finish and Free can wait for it. *)
      ops.Release.SetEvent;
      copier.Free;
      rec.Free;
   end;
end;

procedure TBackupCopierTests.TestTheProbeRunsOffTheCallersThread;
var
   rec: TReportRecorder;
   ops: TFaultyOps;
   copier: TBackupCopier;
   started: QWord;
begin
   BeginTest('setting a destination returns at once; its probe runs on the worker');
   ScrubAll;
   rec := TReportRecorder.Create;
   ops := TFaultyOps.Create;
   ops.BlockProbes := True;
   copier := TBackupCopier.Create(ops, OutboxDir, TEST_RETRY_MS, rec.Received);
   try
      started := GetTickCount64;
      copier.SetDestination(DestDir);
      CheckTrue(GetTickCount64 - started < 2000, 'SetDestination does not wait for the probe');
      CheckTrue(ops.Entered.WaitFor(SETTLE_MS) = wrSignaled, 'the probe is running, and hung');
      CheckEquals(0, rec.Count(bceReachable), 'nothing is reported while it hangs');

      ops.BlockProbes := False;
      ops.Release.SetEvent;
      CheckTrue(copier.WaitUntilSettled(SETTLE_MS), 'the probe settles once released');
      CheckEquals(1, rec.Count(bceReachable), 'and then reports the destination reachable');
      CheckEquals(0, FileCountIn(DestDir), 'the probe leaves no file behind');
   finally
      ops.Release.SetEvent;
      copier.Free;
      rec.Free;
   end;
end;

procedure TBackupCopierTests.TestADestinationChangeForgetsTheOldOneAndProbes;
var
   rec: TReportRecorder;
   copier: TBackupCopier;
   missing: string;
begin
   BeginTest('a new destination forgets the old one''s state and is probed');
   ScrubAll;
   missing := Root + 'no such folder';
   rec := TReportRecorder.Create;
   copier := TBackupCopier.Create(TBackupFileOps.Create, OutboxDir, TEST_RETRY_MS, rec.Received);
   try
      copier.SetDestination(DestDir);
      CheckTrue(copier.WaitUntilSettled(SETTLE_MS), 'settles');
      CheckEquals(1, rec.Count(bceReachable), 'the first folder is probed and reachable');

      copier.SetDestination(missing);
      CheckTrue(copier.WaitUntilSettled(SETTLE_MS), 'settles');
      CheckEquals(1, rec.Count(bceFailed),
                  'a missing folder fails its probe -- a failure, not a recovery');
      CheckEquals(0, rec.Count(bceRecovered), 'nothing recovered');
      CheckFalse(DirectoryExists(missing), 'and the probe did not create it');

      copier.SetDestination(DestDir);
      CheckTrue(copier.WaitUntilSettled(SETTLE_MS), 'settles');
      CheckEquals(2, rec.Count(bceReachable),
                  'back to the first folder: probed again, reported reachable again');
      CheckEquals(0, rec.Count(bceRecovered),
                  'not as a recovery: the failing state belonged to the other folder');

      copier.SetDestination(DestDir);
      CheckTrue(copier.WaitUntilSettled(SETTLE_MS), 'settles');
      CheckEquals(2, rec.Count(bceReachable), 'the same folder again is not probed again');
   finally
      copier.Free;
      rec.Free;
   end;
end;

procedure TBackupCopierTests.TestAnUnchangedCopyIsNotCopiedAgainAtOpen;
var
   rec: TReportRecorder;
   ops: TFaultyOps;
   copier: TBackupCopier;
   local, final, why: string;
begin
   BeginTest('at open, a destination copy that is already the same is not copied again');
   ScrubAll;
   local := IncludeTrailingPathDelimiter(LocalDir) + FINAL_NAME;
   final := IncludeTrailingPathDelimiter(DestDir) + FINAL_NAME;
   rec := TReportRecorder.Create;
   ops := TFaultyOps.Create;
   copier := TBackupCopier.Create(ops, OutboxDir, TEST_RETRY_MS, rec.Received);
   try
      copier.SetDestination(DestDir);
      WriteText(local, 'generation one');
      CheckTrue(copier.Submit(local, True, why), 'a missing copy is queued: ' + why);
      CheckTrue(copier.WaitUntilSettled(SETTLE_MS), 'settles');
      CheckEquals(1, ops.PartialCopies, 'a missing copy IS made');
      CheckEquals('generation one', ReadText(final), 'and arrives');

      CheckTrue(copier.Submit(local, True, why), 'the same generation again: ' + why);
      CheckTrue(copier.WaitUntilSettled(SETTLE_MS), 'settles');
      CheckEquals(1, ops.PartialCopies, 'an identical copy is NOT made again');
      CheckEquals(ABSENT, ReadText(final + '.bak'), 'and nothing was displaced');

      WriteText(local, 'generation two');
      CheckTrue(copier.Submit(local, True, why), 'a different generation: ' + why);
      CheckTrue(copier.WaitUntilSettled(SETTLE_MS), 'settles');
      CheckEquals(2, ops.PartialCopies, 'a copy that differs IS made');
      CheckEquals('generation two', ReadText(final), 'and arrives');
      CheckEquals(0, FileCountIn(OutboxDir), 'and the outbox is empty');
   finally
      copier.Free;
      rec.Free;
   end;
end;

procedure TBackupCopierTests.TestTheLocalBackupFolderIsNotADestination;
var
   rec: TReportRecorder;
   copier: TBackupCopier;
   local, why: string;
begin
   BeginTest('the local backup folder is refused as a destination, and nothing is copied');
   ScrubAll;
   local := IncludeTrailingPathDelimiter(LocalDir) + FINAL_NAME;
   rec := TReportRecorder.Create;
   copier := TBackupCopier.Create(TBackupFileOps.Create, OutboxDir, TEST_RETRY_MS, rec.Received);
   try
      copier.SetDestination(IncludeTrailingPathDelimiter(LocalDir));
      CheckTrue(copier.WaitUntilSettled(SETTLE_MS), 'settles');
      WriteText(local, 'generation one');
      CheckFalse(copier.Submit(local, False, why), 'the submit is refused');
      CheckTrue(Pos('local backup folder', why) > 0, 'and says why: ' + why);
      CheckEquals(1, FileCountIn(LocalDir), 'the local folder holds only the backup');
      CheckEquals('generation one', ReadText(local), 'which is untouched');
      CheckEquals(0, FileCountIn(OutboxDir), 'and nothing was queued');
   finally
      copier.Free;
      rec.Free;
   end;
end;

procedure TBackupCopierTests.TestLeftoverOutboxFilesAreDeletedAtStart;
var
   copier: TBackupCopier;
   keep: string;
begin
   BeginTest('outbox files a previous run left are deleted when the copier starts');
   ScrubAll;
   ForceDirectories(OutboxDir);
   WriteText(IncludeTrailingPathDelimiter(OutboxDir) + FINAL_NAME + '.abc' + BACKUP_OUTBOX_SUFFIX,
             'left by a crash');
   keep := IncludeTrailingPathDelimiter(OutboxDir) + 'not ours.txt';
   WriteText(keep, 'some other file');
   copier := TBackupCopier.Create(TBackupFileOps.Create, OutboxDir, TEST_RETRY_MS, nil);
   try
      CheckEquals('', NamesEndingIn(OutboxDir, BACKUP_OUTBOX_SUFFIX), 'the leftover is gone');
      CheckTrue(FileExists(keep), 'a file that is not an outbox file is left alone');
   finally
      copier.Free;
      DeleteFile(keep);
   end;
end;

procedure TBackupCopierTests.RunAllTests;
begin
   TestACopyArrivesAndThePreviousBecomesBak;
   TestAMissingDestinationIsReportedOnceAndRecoveryOnce;
   TestACorruptedCopyIsRejectedAndTheFinalIsKept;
   TestAFailedPublishPutsBackTheFinalAndTheBak;
   TestNewerGenerationsCoalesce;
   TestShutdownIsBoundedWhileTheDestinationHangs;
   TestTheProbeRunsOffTheCallersThread;
   TestADestinationChangeForgetsTheOldOneAndProbes;
   TestAnUnchangedCopyIsNotCopiedAgainAtOpen;
   TestTheLocalBackupFolderIsNotADestination;
   TestLeftoverOutboxFilesAreDeletedAtStart;

   Scrub(LocalDir);
   Scrub(OutboxDir);
   Scrub(DestDir);
   Scrub(DestDir + '-away');
   if (FDir <> '') and DirectoryExists(FDir) then
      begin
      RemoveDir(FDir);
      end;
end;

(* ---------------------------------------------------------------------------
  the setting
  --------------------------------------------------------------------------- *)

(* A folder path built from this platform's separator, so the same test means
  the same thing everywhere. *)
function NasFolder: string;
begin
   Result := PathDelim + PathDelim + 'NAS2' + PathDelim + 'Backups';
end;

procedure TBackupDestinationSettingTests.TestTheDefaultIsLocalOnly;
var
   s: TR4WSettings;
begin
   BeginTest('BACKUP DESTINATION is empty by default: local backups only');
   s := TR4WSettings.Create;
   try
      CheckEquals('', s.Log.BackupDestination, 'no destination');
      CheckTrue(s.OwnsCommand('BACKUP DESTINATION'), 'the new name resolves');
      CheckTrue(s.OwnsCommand('BACKUP LOG FILE NAME'), 'and so does the former one');
      CheckFalse(s.OwnsCommand('LOG BACKUP DESTINATION'), 'the derived name does not');
   finally
      s.Free;
   end;
end;

procedure TBackupDestinationSettingTests.TestAFormerFileNameCarriesItsFolder;
var
   s: TR4WSettings;
begin
   BeginTest('a former BACKUP LOG FILE NAME with a folder becomes that folder');
   s := TR4WSettings.Create;
   try
      CheckTrue(s.TrySetByCommand('BACKUP LOG FILE NAME',
                                  NasFolder + PathDelim + 'logback.db'), 'accepted');
      CheckEquals(NasFolder + PathDelim, s.Log.BackupDestination,
                  'the folder the file was in');
      CheckEquals(NasFolder + PathDelim,
                  FolderOfFormerBackupFileName('  ' + NasFolder + PathDelim + 'LOGBACK.TR4W  '),
                  'trimmed, and any extension');
      CheckEquals('/Volumes/nas2/TR4W/', FolderOfFormerBackupFileName('/Volumes/nas2/TR4W/logback.db'),
                  'a forward slash divides on every platform');
   finally
      s.Free;
   end;
end;

procedure TBackupDestinationSettingTests.TestABareFormerFileNameMeansLocalOnly;
var
   s: TR4WSettings;
begin
   BeginTest('a bare former file name -- the old logback.db default -- becomes no destination');
   s := TR4WSettings.Create;
   try
      CheckTrue(s.TrySetByCommand('BACKUP DESTINATION', NasFolder), 'a destination first');
      CheckTrue(s.TrySetByCommand('BACKUP LOG FILE NAME', 'logback.db'), 'accepted');
      CheckEquals('', s.Log.BackupDestination, 'local backups only');
   finally
      s.Free;
   end;
end;

procedure TBackupDestinationSettingTests.TestADestinationIsTakenAsWritten;
var
   s: TR4WSettings;
begin
   (* THE DISCRIMINATING CASE: the conversion is keyed by the NAME. A folder
     given under the new name must not be cut to its parent, which is what
     the former name's rule would do to it. *)
   BeginTest('a folder given as BACKUP DESTINATION is kept as written, not cut to its parent');
   s := TR4WSettings.Create;
   try
      CheckTrue(s.TrySetByCommand('BACKUP DESTINATION', NasFolder), 'accepted');
      CheckEquals(NasFolder, s.Log.BackupDestination, 'the whole folder');
   finally
      s.Free;
   end;
end;

procedure TBackupDestinationSettingTests.TestASettingsFileWithTheFormerMemberIsConverted;
var
   s: TR4WSettings;
   obj: TJSONObject;
   folder: string;
begin
   BeginTest('a settings file written before BACKUP DESTINATION is converted on load');
   InstallTestKeychain;
   folder := 'Z:' + PathDelim;
   s := TR4WSettings.Create;
   try
      obj := TJSONObject(TJSONObject.ParseJSONValue(
                '{"Log":{"BackupFileName":"' +
                StringReplace(folder, '\', '\\', [rfReplaceAll]) + 'LOGBACK.TR4W"}}'));
      CheckTrue(obj <> nil, 'the fixture must parse');
      try
         s.FromJSON(obj);
      finally
         obj.Free;
      end;
      CheckEquals(folder, s.Log.BackupDestination, 'the folder carries over');

      obj := TJSONObject(TJSONObject.ParseJSONValue(
                '{"Log":{"BackupFileName":"logback.db"}}'));
      try
         s.FromJSON(obj);
      finally
         obj.Free;
      end;
      CheckEquals('', s.Log.BackupDestination,
                  'NY4I''s own value, a bare logback.db, becomes local only');

      obj := TJSONObject(TJSONObject.ParseJSONValue(
                '{"Log":{"BackupFileName":"logback.db","BackupDestination":"kept"}}'));
      try
         s.FromJSON(obj);
      finally
         obj.Free;
      end;
      CheckEquals('kept', s.Log.BackupDestination,
                  'a file that has the new member is not converted over it');
   finally
      s.Free;
   end;
end;

procedure TBackupDestinationSettingTests.TestTheFormerCommandInTheLegacyBucketIsConverted;
var
   s: TR4WSettings;
   commands: TJSONObject;
begin
   BeginTest('the legacy commands bucket''s BACKUP LOG FILE NAME is converted on import');
   s := TR4WSettings.Create;
   try
      commands := TJSONObject(TJSONObject.ParseJSONValue(
                     '{"BACKUP LOG FILE NAME":"/Volumes/nas2/TR4W/LOGBACK.TR4W"}'));
      CheckTrue(commands <> nil, 'the fixture must parse');
      try
         s.ImportLegacyCommands(commands);
      finally
         commands.Free;
      end;
      CheckEquals('/Volumes/nas2/TR4W/', s.Log.BackupDestination, 'the folder');
   finally
      s.Free;
   end;
end;

procedure TBackupDestinationSettingTests.TestTheSettingsFileNoLongerCarriesTheFormerMember;
var
   s: TR4WSettings;
   obj: TJSONObject;
   text: string;
begin
   BeginTest('a saved settings section carries BackupDestination and not BackupFileName');
   s := TR4WSettings.Create;
   try
      s.Log.BackupDestination := NasFolder;
      obj := s.ToJSON;
      try
         text := string(obj.AsJSON);
      finally
         obj.Free;
      end;
      CheckTrue(Pos('"BackupDestination"', text) > 0, 'the new member is written');
      CheckEquals(0, Pos('"BackupFileName"', text), 'the former member is not');
   finally
      s.Free;
   end;
end;

procedure TBackupDestinationSettingTests.RunAllTests;
begin
   TestTheDefaultIsLocalOnly;
   TestAFormerFileNameCarriesItsFolder;
   TestABareFormerFileNameMeansLocalOnly;
   TestADestinationIsTakenAsWritten;
   TestASettingsFileWithTheFormerMemberIsConverted;
   TestTheFormerCommandInTheLegacyBucketIsConverted;
   TestTheSettingsFileNoLongerCarriesTheFormerMember;
end;

(* TBackupCopyNoticeTests *)

const
   LOCAL_REPORT = 'Log backed up to C:\settings\backup\CQ-WW-SSB NY4I periodic.db.';
   SHARE_FOLDER = '\\nas2\shared\TR4W-Log-Backups';

procedure TBackupCopyNoticeTests.TestAQueuedCopyNamesTheDestinationNotTheLocalFile;
var
   text: string;
begin
   BeginTest('a backup with a destination says it is copying there, and names the folder');
   text := BackupDoneText(LOCAL_REPORT, True, SHARE_FOLDER, '');
   CheckEquals(SysUtils.Format(SBackupCopyingToDestination, [SHARE_FOLDER]), text,
               'the copying sentence');
   CheckTrue(Pos(SHARE_FOLDER, text) > 0, 'the destination folder is named');
   CheckEquals(0, Pos('periodic.db', text), 'the local file is not');
end;

procedure TBackupCopyNoticeTests.TestNoDestinationKeepsTheLocalReport;
begin
   BeginTest('a backup with no destination says what it said before');
   CheckEquals(LOCAL_REPORT, BackupDoneText(LOCAL_REPORT, False, '', ''),
               'the local report, unchanged');
end;

procedure TBackupCopyNoticeTests.TestAFailedQueueingSaysWhy;
begin
   BeginTest('a copy that could not be queued says why, not that it is copying');
   CheckEquals('the outbox copy failed',
               BackupDoneText(LOCAL_REPORT, False, SHARE_FOLDER, 'the outbox copy failed'),
               'the reason');
end;

procedure TBackupCopyNoticeTests.TestEveryCopierEventHasANoticeAndOnlyAFailureBeeps;
var
   text: string;
   isFailure: boolean;
   finalFile: string;
begin
   BeginTest('every copier report has a status-line notice; bceCopied names the file, no beep');
   finalFile := SHARE_FOLDER + '\' + FINAL_NAME;

   BackupCopyNotice(bceCopied, SHARE_FOLDER, finalFile, text, isFailure);
   CheckEquals(SysUtils.Format(SBackupCopiedTo, [finalFile]), text, 'bceCopied: the sentence');
   CheckTrue(Pos(finalFile, text) > 0, 'bceCopied names the destination file');
   CheckFalse(isFailure, 'bceCopied does not beep');

   BackupCopyNotice(bceReachable, SHARE_FOLDER, '', text, isFailure);
   CheckEquals(SysUtils.Format(SBackupDestinationReachable, [SHARE_FOLDER]), text, 'bceReachable');
   CheckFalse(isFailure, 'bceReachable does not beep');

   BackupCopyNotice(bceFailed, SHARE_FOLDER, 'the share is down', text, isFailure);
   CheckEquals(SysUtils.Format(SBackupCopyFailed, [SHARE_FOLDER, 'the share is down']), text,
               'bceFailed');
   CheckTrue(isFailure, 'bceFailed beeps');

   BackupCopyNotice(bceRecovered, SHARE_FOLDER, '', text, isFailure);
   CheckEquals(SysUtils.Format(SBackupCopyRecovered, [SHARE_FOLDER]), text, 'bceRecovered');
   CheckFalse(isFailure, 'bceRecovered does not beep');
end;

procedure TBackupCopyNoticeTests.RunAllTests;
begin
   TestAQueuedCopyNamesTheDestinationNotTheLocalFile;
   TestNoDestinationKeepsTheLocalReport;
   TestAFailedQueueingSaysWhy;
   TestEveryCopierEventHasANoticeAndOnlyAFailureBeeps;
end;

end.
