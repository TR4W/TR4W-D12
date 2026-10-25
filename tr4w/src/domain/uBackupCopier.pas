unit uBackupCopier;

(* COPYING A VERIFIED LOCAL BACKUP TO THE BACKUP DESTINATION, OFF THE MAIN
  THREAD (issue #98 step 2, 2026-10-25).

  WHAT IT IS FOR. The periodic backup is written LOCALLY first, to
  uAppPaths.BackupDir, by TLogBackup (staged, verified, published by rename).
  The operator may also name a BACKUP DESTINATION -- a folder on a NAS, a
  mounted share, a Dropbox folder. This unit takes each local generation there,
  on ONE worker thread, so a share that is slow, gone or hung never stops the
  operator logging.

  THE MAIN THREAD NEVER WAITS ON THE DESTINATION. Submit does one LOCAL file
  copy and returns; everything that touches the destination -- the copy, the
  read-back, the renames, the probe -- runs on the worker.

  THE OUTBOX, AND WHY IT EXISTS. The worker never opens the published local
  backup. It copies from an OUTBOX file that Submit makes, under a name that
  is unique to that one submission, in a folder only this object writes:

     <outbox>\<final name>.<guid>.outbox

  The reason is the next local publish. TLogBackup renames the published file
  to .bak and the staged one over it, and on Windows a rename of a file that
  another handle has open FAILS. A worker reading the published file for the
  minutes a slow share can take would make the next local backup fail, which
  is exactly backwards: the local copy is the one that must always succeed.
  With the outbox, the worker's only open handles are on files nobody else
  will ever rename, and THE COPIER HOLDS NO LOCK WHILE IT DOES FILE I/O -- its
  critical section guards the job list and nothing else.

  The price is one extra local copy of the backup per generation, on the
  thread that took the backup. That thread already wrote the whole file through
  VACUUM INTO a moment earlier, so this is the same order of cost, on local
  disk. (Moving the local snapshot itself off the main thread is a later step
  of issue #98; this step leaves it where it was.)

  COALESCING. At most one job per final name is PENDING. A newer generation
  replaces the pending one, and the superseded outbox file is deleted on the
  spot -- it is not in flight, so nobody has it open. A job already in flight
  finishes; if a newer one arrived meanwhile, the in-flight one is not retried
  on failure, because the newer one supersedes it. So the outbox holds at most
  two files per log, whatever the share is doing.

  THE COPY, IN ORDER -- the contract the tests pin:

     1. the destination folder must already exist. It is NEVER created: an
        unmounted share on macOS is an empty folder under /Volumes, and making
        the folder would write the "remote" copy to the local disk
     2. the outbox file is copied to <final>.<guid>.partial IN THE DESTINATION
        FOLDER, flushed (FileFlush), and closed
     3. the .partial is re-opened and compared byte for byte with the outbox
        file; a difference fails the job
     4. publish: an existing .bak is moved aside to a unique .old name, the
        existing final becomes .bak (the previous verified copy), the .partial
        becomes the final, then the .old is deleted. A rename that fails puts
        back what the earlier steps moved, so a failed job leaves the final
        and the .bak exactly as they were. No rename ever targets an existing
        name, so this behaves the same where rename(2) would overwrite and
        where MoveFileW would refuse
     5. on any failure this job's .partial -- and only this job's -- is deleted

  A .partial NEVER HAS THE FINAL NAME, so a copy interrupted at any point,
  including by the process exiting, is never mistaken for a backup.

  THE READ-BACK IS WHAT THE OPERATING SYSTEM HANDS BACK. On a network share
  the client may answer a read from its own cache, so step 3 proves the copy
  as the share's client sees it, not as the server's disk holds it. That is
  the strongest check available without a second protocol.

  RETRIES run on the worker's own clock (aRetryMs, 60 s in the program), not on
  the next QSO. A destination that failed is probed again on the same clock
  even with nothing pending, so recovery is reported without a new QSO.

  REPORTS ARE BY TRANSITION. One report when the destination first answers,
  one when it goes from working (or unknown) to failing, one when it recovers;
  repeated failures say nothing. bceCopied is reported for every generation
  that arrives and is meant for a log line, not for the operator. Reports are
  made ON THE WORKER THREAD, outside the job lock; the receiver must marshal
  anything it shows.

  CHANGING THE DESTINATION forgets the old one's health and probes the new one.
  A job in flight to the old destination finishes there and does not count
  toward the new one; it is re-queued for the new one unless superseded.

  SHUTDOWN IS BOUNDED. Shutdown(ms) detaches the report callback (waiting for
  a report in progress to return), tells the worker to stop and waits at most
  ms. It answers False when the worker is still inside a file operation -- a
  hung share. Then the caller must NOT free this object, and the process may
  exit with the worker blocked. THAT IS SAFE BECAUSE OF WHAT THE WORKER HOLDS:
  file handles and memory, and no SQLite object, no connection, no lock of
  this object's and no lock of the program's. The operating system closes the
  handles at exit; what is left on the share is at worst a .partial, which is
  never a backup by name. Destroy, unlike Shutdown, waits for the worker
  without limit, as uQsoDispatcher does -- it is for a caller that knows the
  worker can finish.

  FILE OPERATIONS ARE INJECTABLE (TBackupFileOps) so the tests can make a copy
  come back corrupted, block, or fail at a chosen step. They are called from
  both threads -- Submit's outbox copy on the caller's, everything else on the
  worker -- so an implementation must keep no state between calls.

  NO PLATFORM CALLS: TFileStream, FileFlush, RenameFile, DeleteFile, FindFirst,
  CreateGUID -- all RTL, on every platform TR4W builds for. *)

{$I ..\tr4w.inc}

interface

uses
   SysUtils, Classes, SyncObjs, Contnrs;

type
   (* EVERY FILE OPERATION THE COPIER MAKES, as virtuals a test can override.
     Each raises or answers False on failure exactly as the RTL routine it
     wraps does. *)
   TBackupFileOps = class(TObject)
   public
      function FolderExists(const aFolder: string): boolean; virtual;
      function FileExists(const aPath: string): boolean; virtual;
      (* Copy aSource to the new file aTarget, flush it to the operating
        system's storage and close it. Raises on any failure. *)
      procedure CopyFile(const aSource, aTarget: string); virtual;
      (* Write aBytes to the new file aTarget, flush and close. Raises. *)
      procedure WriteFile(const aTarget: string; const aBytes: TBytes); virtual;
      (* Do the two files hold the same bytes? Raises if either cannot be
        read. *)
      function SameContent(const aOne, aTwo: string): boolean; virtual;
      function RenameFile(const aOld, aNew: string): boolean; virtual;
      function DeleteFile(const aPath: string): boolean; virtual;
   end;

   TBackupCopyEvent = (
      bceReachable,   (* the destination answered its first probe: writable *)
      bceFailed,      (* it went from working, or unknown, to failing *)
      bceRecovered,   (* it went from failing to working *)
      bceCopied);     (* a generation arrived -- for a log line, not a notice *)

   (* aDetail is the reason for bceFailed and the file written for
     bceCopied; empty otherwise. Called on the worker thread. *)
   TBackupCopyReport = procedure(aEvent: TBackupCopyEvent;
                                 const aDestination, aDetail: string) of object;

   TBackupDestinationHealth = (bdhUnknown, bdhWorking, bdhFailing);

   TBackupCopier = class(TObject)
   private
      FOps: TBackupFileOps;
      FOutboxDir: string;
      FRetryMs: Cardinal;
      FWorker: TThread;
      FWake: TEvent;
      FDone: TEvent;
      (* Guards FOnReport only; held while a report runs, so Shutdown can wait
        for one in progress and then be sure no other starts. *)
      FReportLock: TCriticalSection;
      FOnReport: TBackupCopyReport;
      (* Guards everything below. NEVER HELD ACROSS FILE I/O. *)
      FLock: TCriticalSection;
      FDestination: string;
      FEpoch: integer;
      FHealth: TBackupDestinationHealth;
      FProbeDueAt: QWord;
      FPending: TObjectList;
      FBusy: boolean;
      FStopping: boolean;
      FAttempts: integer;

      procedure RunWorker;
      procedure Report(aEvent: TBackupCopyEvent; const aDestination, aDetail: string);
      function PendingIndexOf(const aFinalName: string): integer;
      procedure DeleteOutboxLeftovers;
      function ProbeDestination(const aFolder: string; out aWhy: string): boolean;
      function CopyToDestination(const aOutbox, aFinalName, aFolder: string;
                                 aOnlyIfDifferent: boolean;
                                 out aWritten, aWhy: string): boolean;
   public
      (* Takes ownership of aOps. aOutboxDir is created if it is missing, and
        any outbox file a previous run left there is deleted -- nothing is in
        flight before the worker starts. aRetryMs is how long a failed job or
        probe waits before it is tried again. aOnReport may be nil. *)
      constructor Create(aOps: TBackupFileOps; const aOutboxDir: string;
                         aRetryMs: Cardinal; aOnReport: TBackupCopyReport);
      destructor Destroy; override;

      (* The folder to copy to; '' for none, which drops every pending job.
        A different folder from the current one forgets the current one's
        health and schedules a probe. The same folder again does nothing. *)
      procedure SetDestination(const aFolder: string);
      function Destination: string;

      (* ON THE CALLER'S THREAD: copy aLocalBackup into the outbox and queue
        it for the destination, replacing any pending generation with the same
        file name. aOnlyIfDifferent skips the copy when the destination's
        final already holds the same bytes (the at-open reconciliation). False,
        with aWhy, when there is no destination, the copier is stopping, the
        destination is the local backup's own folder, or the outbox copy
        fails. Never raises. *)
      function Submit(const aLocalBackup: string; aOnlyIfDifferent: boolean;
                      out aWhy: string): boolean;

      (* Make every waiting retry, and a waiting re-probe, due now. *)
      procedure RetryNow;

      (* See the header. True when the worker has stopped. *)
      function Shutdown(aTimeoutMs: Cardinal): boolean;

      (* FOR TESTS. True once nothing is in flight and nothing is due now
        (a failed job waiting out its retry counts as settled). *)
      function WaitUntilSettled(aTimeoutMs: Cardinal): boolean;
      (* FOR TESTS. Finished copy attempts, probes not counted. *)
      function Attempts: integer;
      (* FOR TESTS. Jobs waiting, the one in flight not counted. *)
      function PendingCount: integer;
      function Health: TBackupDestinationHealth;
   end;

const
   (* What a copier in the program waits before trying a failed destination
     again. *)
   BACKUP_COPY_RETRY_MS = 60000;
   BACKUP_PARTIAL_SUFFIX = '.partial';
   BACKUP_OUTBOX_SUFFIX = '.outbox';

implementation

const
   NOT_DUE = High(QWord);
   COMPARE_CHUNK = 65536;

type
   TBackupCopyJob = class(TObject)
   public
      Outbox: string;
      FinalName: string;
      OnlyIfDifferent: boolean;
      DueAt: QWord;
   end;

   TBackupCopierThread = class(TThread)
   private
      FOwner: TBackupCopier;
   protected
      procedure Execute; override;
   public
      constructor Create(aOwner: TBackupCopier);
   end;

(* A name no other submission, probe or station will produce: a GUID, without
  its braces. *)
function UniqueToken: string;
var
   guid: TGUID;
   text: string;
begin
   if CreateGUID(guid) <> 0 then
      begin
      (* CreateGUID cannot fail on any platform this builds for; a time and a
        process id are unique enough on the one machine if it ever did. *)
      Result := IntToStr(GetProcessID) + '-' + IntToStr(GetTickCount64);
      Exit;
      end;
   text := GUIDToString(guid);
   Result := Copy(text, 2, Length(text) - 2);
end;

(* The same folder, however it was written? Case-insensitive only where the
  file system is. *)
function SameFolder(const aOne, aTwo: string): boolean;
var
   one, two: string;
begin
   one := IncludeTrailingPathDelimiter(ExpandFileName(aOne));
   two := IncludeTrailingPathDelimiter(ExpandFileName(aTwo));
   if FileNameCaseSensitive then
      begin
      Result := one = two;
      end
   else
      begin
      Result := UnicodeSameText(one, two);
      end;
end;

(* ---------------------------------------------------------------------------
  TBackupFileOps
  --------------------------------------------------------------------------- *)

(* EXPLICIT, at a genuine boundary, once: TFileStream's file name is
  AnsiString in FPC 3.2.2 and FPC treats it as the file-system code page --
  the conversion that would happen anyway, said out loud, as uLogDatabase and
  uLogBinaryFile do. *)
function OpenFile(const aPath: string; aMode: Word): TFileStream;
begin
   Result := TFileStream.Create(AnsiString(aPath), aMode);
end;

function TBackupFileOps.FolderExists(const aFolder: string): boolean;
begin
   Result := SysUtils.DirectoryExists(aFolder);
end;

function TBackupFileOps.FileExists(const aPath: string): boolean;
begin
   Result := SysUtils.FileExists(aPath);
end;

procedure TBackupFileOps.CopyFile(const aSource, aTarget: string);
var
   source, target: TFileStream;
begin
   source := OpenFile(aSource, fmOpenRead or fmShareDenyWrite);
   try
      target := OpenFile(aTarget, fmCreate);
      try
         if source.Size > 0 then
            begin
            target.CopyFrom(source, source.Size);
            end;
         (* THE RTL'S OWN FLUSH, given the stream's handle -- the one place a
           handle is asked for, because TFileStream has no Flush of its own.
           FileFlush is FlushFileBuffers on Windows and fsync on Unix. *)
         if not FileFlush(target.Handle) then
            begin
            raise EInOutError.CreateFmt('%s could not be flushed', [aTarget]);
            end;
      finally
         target.Free;
      end;
   finally
      source.Free;
   end;
end;

procedure TBackupFileOps.WriteFile(const aTarget: string; const aBytes: TBytes);
var
   target: TFileStream;
begin
   target := OpenFile(aTarget, fmCreate);
   try
      if Length(aBytes) > 0 then
         begin
         target.WriteBuffer(aBytes[0], Length(aBytes));
         end;
      if not FileFlush(target.Handle) then
         begin
         raise EInOutError.CreateFmt('%s could not be flushed', [aTarget]);
         end;
   finally
      target.Free;
   end;
end;

function TBackupFileOps.SameContent(const aOne, aTwo: string): boolean;
var
   one, two: TFileStream;
   bufOne, bufTwo: TBytes;
   remaining: Int64;
   chunk: integer;
   i: integer;
begin
   Result := False;
   one := OpenFile(aOne, fmOpenRead or fmShareDenyNone);
   try
      two := OpenFile(aTwo, fmOpenRead or fmShareDenyNone);
      try
         if one.Size <> two.Size then
            begin
            Exit;
            end;
         SetLength(bufOne, COMPARE_CHUNK);
         SetLength(bufTwo, COMPARE_CHUNK);
         remaining := one.Size;
         while remaining > 0 do
            begin
            if remaining > COMPARE_CHUNK then
               begin
               chunk := COMPARE_CHUNK;
               end
            else
               begin
               chunk := integer(remaining);
               end;
            one.ReadBuffer(bufOne[0], chunk);
            two.ReadBuffer(bufTwo[0], chunk);
            (* A plain loop: a backup is a few megabytes, and this is the
              worker's time, not the operator's. *)
            for i := 0 to chunk - 1 do
               begin
               if bufOne[i] <> bufTwo[i] then
                  begin
                  Exit;
                  end;
               end;
            remaining := remaining - chunk;
            end;
         Result := True;
      finally
         two.Free;
      end;
   finally
      one.Free;
   end;
end;

function TBackupFileOps.RenameFile(const aOld, aNew: string): boolean;
begin
   Result := SysUtils.RenameFile(aOld, aNew);
end;

function TBackupFileOps.DeleteFile(const aPath: string): boolean;
begin
   Result := SysUtils.DeleteFile(aPath);
end;

(* ---------------------------------------------------------------------------
  the worker thread
  --------------------------------------------------------------------------- *)

constructor TBackupCopierThread.Create(aOwner: TBackupCopier);
begin
   FOwner := aOwner;
   FreeOnTerminate := False;
   inherited Create(False);
end;

procedure TBackupCopierThread.Execute;
begin
   FOwner.RunWorker;
end;

(* ---------------------------------------------------------------------------
  TBackupCopier
  --------------------------------------------------------------------------- *)

constructor TBackupCopier.Create(aOps: TBackupFileOps; const aOutboxDir: string;
   aRetryMs: Cardinal; aOnReport: TBackupCopyReport);
begin
   inherited Create;
   FOps := aOps;
   FOutboxDir := IncludeTrailingPathDelimiter(aOutboxDir);
   FRetryMs := aRetryMs;
   FOnReport := aOnReport;
   FLock := TCriticalSection.Create;
   FReportLock := TCriticalSection.Create;
   FWake := TEvent.Create(nil, False, False, '');
   FDone := TEvent.Create(nil, True, False, '');
   FPending := TObjectList.Create(True);
   FDestination := '';
   FEpoch := 0;
   FHealth := bdhUnknown;
   FProbeDueAt := NOT_DUE;
   FBusy := False;
   FStopping := False;
   FAttempts := 0;

   ForceDirectories(FOutboxDir);
   DeleteOutboxLeftovers;

   FWorker := TBackupCopierThread.Create(Self);
end;

destructor TBackupCopier.Destroy;
var
   i: integer;
begin
   if not Shutdown(500) then
      begin
      (* The worker is inside a file operation and still uses this object, so
        it must finish first. A caller that cannot wait calls Shutdown and
        does not free. *)
      FDone.WaitFor(INFINITE);
      if FWorker <> nil then
         begin
         FWorker.WaitFor;
         FreeAndNil(FWorker);
         end;
      end;

   (* What was still waiting: its outbox files are this object's, and the next
     start would delete them anyway. *)
   for i := 0 to FPending.Count - 1 do
      begin
      FOps.DeleteFile(TBackupCopyJob(FPending[i]).Outbox);
      end;

   FPending.Free;
   FDone.Free;
   FWake.Free;
   FReportLock.Free;
   FLock.Free;
   FOps.Free;
   inherited Destroy;
end;

procedure TBackupCopier.DeleteOutboxLeftovers;
var
   (* The UnicodeString search record, so the names need no conversion. *)
   found: TUnicodeSearchRec;
begin
   if FindFirst(FOutboxDir + '*' + BACKUP_OUTBOX_SUFFIX, faAnyFile, found) = 0 then
      begin
      try
         repeat
            if (found.Attr and faDirectory) = 0 then
               begin
               SysUtils.DeleteFile(FOutboxDir + found.Name);
               end;
         until FindNext(found) <> 0;
      finally
         FindClose(found);
      end;
      end;
end;

procedure TBackupCopier.Report(aEvent: TBackupCopyEvent;
   const aDestination, aDetail: string);
begin
   FReportLock.Acquire;
   try
      if Assigned(FOnReport) then
         begin
         FOnReport(aEvent, aDestination, aDetail);
         end;
   finally
      FReportLock.Release;
   end;
end;

function TBackupCopier.PendingIndexOf(const aFinalName: string): integer;
var
   i: integer;
begin
   Result := -1;
   for i := 0 to FPending.Count - 1 do
      begin
      if UnicodeSameText(TBackupCopyJob(FPending[i]).FinalName, aFinalName) then
         begin
         Result := i;
         Exit;
         end;
      end;
end;

procedure TBackupCopier.SetDestination(const aFolder: string);
var
   dropped: array of string;
   folder: string;
   i: integer;
begin
   folder := Trim(aFolder);
   dropped := nil;
   try
      FLock.Acquire;
      try
         if FStopping or (folder = FDestination) then
            begin
            Exit;
            end;
         FDestination := folder;
         Inc(FEpoch);
         FHealth := bdhUnknown;
         if folder = '' then
            begin
            FProbeDueAt := NOT_DUE;
            SetLength(dropped, FPending.Count);
            for i := 0 to FPending.Count - 1 do
               begin
               dropped[i] := TBackupCopyJob(FPending[i]).Outbox;
               end;
            FPending.Clear;
            end
         else
            begin
            FProbeDueAt := 0;
            (* Pending jobs follow the destination: they are due at once at
              the new one. *)
            for i := 0 to FPending.Count - 1 do
               begin
               TBackupCopyJob(FPending[i]).DueAt := 0;
               end;
            end;
      finally
         FLock.Release;
      end;

      for i := 0 to High(dropped) do
         begin
         FOps.DeleteFile(dropped[i]);
         end;
      FWake.SetEvent;
   finally
      dropped := nil;
   end;
end;

function TBackupCopier.Destination: string;
begin
   FLock.Acquire;
   try
      Result := FDestination;
   finally
      FLock.Release;
   end;
end;

function TBackupCopier.Submit(const aLocalBackup: string; aOnlyIfDifferent: boolean;
   out aWhy: string): boolean;
var
   folder, finalName, outbox, superseded: string;
   job: TBackupCopyJob;
   stopping: boolean;
   i: integer;
begin
   Result := False;
   aWhy := '';

   FLock.Acquire;
   try
      folder := FDestination;
      stopping := FStopping;
   finally
      FLock.Release;
   end;

   if stopping then
      begin
      aWhy := 'the backup copier is stopping';
      Exit;
      end;
   if folder = '' then
      begin
      aWhy := 'no backup destination is set';
      Exit;
      end;
   (* A destination that IS the local backup folder would rename the local
     backup itself into a .bak on the first copy. *)
   if SameFolder(ExtractFilePath(aLocalBackup), folder) then
      begin
      aWhy := 'the backup destination ' + folder + ' is the local backup folder '
              + 'itself, so nothing was copied';
      Exit;
      end;

   finalName := ExtractFileName(aLocalBackup);
   outbox := FOutboxDir + finalName + '.' + UniqueToken + BACKUP_OUTBOX_SUFFIX;
   try
      ForceDirectories(FOutboxDir);
      FOps.CopyFile(aLocalBackup, outbox);
   except
      on E: Exception do
         begin
         if FOps.FileExists(outbox) then
            begin
            FOps.DeleteFile(outbox);
            end;
         aWhy := 'the local backup could not be queued for ' + folder + ': '
                 + E.Message;
         Exit;
         end;
   end;

   superseded := '';
   FLock.Acquire;
   try
      if FStopping then
         begin
         superseded := outbox;
         aWhy := 'the backup copier is stopping';
         end
      else
         begin
         i := PendingIndexOf(finalName);
         if i >= 0 then
            begin
            superseded := TBackupCopyJob(FPending[i]).Outbox;
            FPending.Delete(i);
            end;
         job := TBackupCopyJob.Create;
         job.Outbox := outbox;
         job.FinalName := finalName;
         job.OnlyIfDifferent := aOnlyIfDifferent;
         job.DueAt := 0;
         FPending.Add(job);
         Result := True;
         end;
   finally
      FLock.Release;
   end;

   if superseded <> '' then
      begin
      FOps.DeleteFile(superseded);
      end;
   if Result then
      begin
      FWake.SetEvent;
      end;
end;

procedure TBackupCopier.RetryNow;
var
   i: integer;
begin
   FLock.Acquire;
   try
      for i := 0 to FPending.Count - 1 do
         begin
         TBackupCopyJob(FPending[i]).DueAt := 0;
         end;
      if FProbeDueAt <> NOT_DUE then
         begin
         FProbeDueAt := 0;
         end;
   finally
      FLock.Release;
   end;
   FWake.SetEvent;
end;

function TBackupCopier.Shutdown(aTimeoutMs: Cardinal): boolean;
begin
   (* FIRST, NO MORE REPORTS. Taking the report lock waits for one in
     progress; once it is released with the callback gone, the receiver can be
     torn down. *)
   FReportLock.Acquire;
   try
      FOnReport := nil;
   finally
      FReportLock.Release;
   end;

   FLock.Acquire;
   try
      FStopping := True;
   finally
      FLock.Release;
   end;
   FWake.SetEvent;

   if FWorker = nil then
      begin
      Result := True;
      Exit;
      end;

   Result := FDone.WaitFor(aTimeoutMs) = wrSignaled;
   if Result then
      begin
      FWorker.WaitFor;
      FreeAndNil(FWorker);
      end;
end;

function TBackupCopier.WaitUntilSettled(aTimeoutMs: Cardinal): boolean;
var
   deadline, tick: QWord;
   settled: boolean;
   i: integer;
begin
   deadline := GetTickCount64 + aTimeoutMs;
   repeat
      tick := GetTickCount64;
      FLock.Acquire;
      try
         settled := not FBusy;
         if settled and (FDestination <> '') and (FProbeDueAt <= tick) then
            begin
            settled := False;
            end;
         i := 0;
         while settled and (i < FPending.Count) do
            begin
            if TBackupCopyJob(FPending[i]).DueAt <= tick then
               begin
               settled := False;
               end;
            Inc(i);
            end;
      finally
         FLock.Release;
      end;
      if settled then
         begin
         Result := True;
         Exit;
         end;
      Sleep(5);
   until GetTickCount64 > deadline;
   Result := False;
end;

function TBackupCopier.Attempts: integer;
begin
   FLock.Acquire;
   try
      Result := FAttempts;
   finally
      FLock.Release;
   end;
end;

function TBackupCopier.PendingCount: integer;
begin
   FLock.Acquire;
   try
      Result := FPending.Count;
   finally
      FLock.Release;
   end;
end;

function TBackupCopier.Health: TBackupDestinationHealth;
begin
   FLock.Acquire;
   try
      Result := FHealth;
   finally
      FLock.Release;
   end;
end;

(* A REAL WRITE, NOT A LOOK: create, write, rename and delete a probe file.
  An existing folder can still refuse a write (read-only share, full volume,
  expired credentials), and only a write says so. *)
function TBackupCopier.ProbeDestination(const aFolder: string; out aWhy: string): boolean;
var
   probe, renamed: string;
   bytes: TBytes;
   i: integer;
begin
   Result := False;
   aWhy := '';
   if not FOps.FolderExists(aFolder) then
      begin
      aWhy := 'the folder ' + aFolder + ' is not there (is the share connected?)';
      Exit;
      end;

   probe := IncludeTrailingPathDelimiter(aFolder) + 'tr4w-probe-' + UniqueToken;
   renamed := probe + '.renamed';
   probe := probe + '.tmp';
   SetLength(bytes, 64);
   for i := 0 to High(bytes) do
      begin
      bytes[i] := Byte(i);
      end;
   try
      try
         FOps.WriteFile(probe, bytes);
         if not FOps.RenameFile(probe, renamed) then
            begin
            aWhy := 'a file could be written in ' + aFolder + ' but not renamed';
            Exit;
            end;
         if not FOps.DeleteFile(renamed) then
            begin
            aWhy := 'a file could be written in ' + aFolder + ' but not deleted';
            Exit;
            end;
         Result := True;
      except
         on E: Exception do
            begin
            aWhy := 'a file could not be written in ' + aFolder + ': ' + E.Message;
            end;
      end;
   finally
      if FOps.FileExists(probe) then
         begin
         FOps.DeleteFile(probe);
         end;
      if FOps.FileExists(renamed) then
         begin
         FOps.DeleteFile(renamed);
         end;
   end;
end;

function TBackupCopier.CopyToDestination(const aOutbox, aFinalName, aFolder: string;
   aOnlyIfDifferent: boolean; out aWritten, aWhy: string): boolean;
var
   final, previous, partial, aside: string;
   hadPrevious: boolean;
   token: string;
begin
   Result := False;
   aWhy := '';
   final := IncludeTrailingPathDelimiter(aFolder) + aFinalName;
   aWritten := final;
   previous := final + '.bak';

   if not FOps.FolderExists(aFolder) then
      begin
      aWhy := 'the folder ' + aFolder + ' is not there (is the share connected?)';
      Exit;
      end;

   token := UniqueToken;
   partial := final + '.' + token + BACKUP_PARTIAL_SUFFIX;
   aside := final + '.' + token + '.old';
   try
      try
         if aOnlyIfDifferent and FOps.FileExists(final) and
            FOps.SameContent(aOutbox, final) then
            begin
            (* The destination already holds this generation. *)
            Result := True;
            Exit;
            end;

         FOps.CopyFile(aOutbox, partial);
         if not FOps.SameContent(aOutbox, partial) then
            begin
            aWhy := 'the copy at ' + partial + ' did not read back the same as '
                    + 'the local backup, so it was discarded';
            Exit;
            end;

         if not FOps.FileExists(final) then
            begin
            if not FOps.RenameFile(partial, final) then
               begin
               aWhy := 'the verified copy could not be renamed to ' + final;
               Exit;
               end;
            Result := True;
            Exit;
            end;

         (* PUBLISH OVER AN EXISTING COPY. Each step that fails puts back what
           the steps before it moved. *)
         hadPrevious := FOps.FileExists(previous);
         if hadPrevious and (not FOps.RenameFile(previous, aside)) then
            begin
            aWhy := 'the older copy ' + previous + ' could not be moved aside';
            Exit;
            end;
         if not FOps.RenameFile(final, previous) then
            begin
            if hadPrevious then
               begin
               FOps.RenameFile(aside, previous);
               end;
            aWhy := 'the existing copy ' + final + ' could not be moved to ' + previous;
            Exit;
            end;
         if not FOps.RenameFile(partial, final) then
            begin
            FOps.RenameFile(previous, final);
            if hadPrevious then
               begin
               FOps.RenameFile(aside, previous);
               end;
            aWhy := 'the verified copy could not be renamed to ' + final;
            Exit;
            end;
         if hadPrevious then
            begin
            FOps.DeleteFile(aside);
            end;
         Result := True;
      except
         on E: Exception do
            begin
            aWhy := 'the copy to ' + final + ' failed: ' + E.Message;
            Result := False;
            end;
      end;
   finally
      (* ONLY THIS JOB'S .partial. After a successful publish it has been
        renamed and is not there. *)
      if FOps.FileExists(partial) then
         begin
         FOps.DeleteFile(partial);
         end;
   end;
end;

procedure TBackupCopier.RunWorker;
var
   tick, wait: QWord;
   job: TBackupCopyJob;
   doProbe: boolean;
   folder, why, written, deleteAfter: string;
   epoch: integer;
   ok, superseded, sameEpoch: boolean;
   i: integer;
   events: array[0..1] of TBackupCopyEvent;
   eventCount: integer;
   eventDetail: array[0..1] of string;
begin
   try
      while True do
         begin
         job := nil;
         doProbe := False;
         tick := GetTickCount64;
         wait := FRetryMs;

         FLock.Acquire;
         try
            if FStopping then
               begin
               Break;
               end;
            folder := FDestination;
            epoch := FEpoch;
            if (folder <> '') and (FProbeDueAt <= tick) then
               begin
               doProbe := True;
               FProbeDueAt := NOT_DUE;
               FBusy := True;
               end
            else if folder <> '' then
               begin
               for i := 0 to FPending.Count - 1 do
                  begin
                  if TBackupCopyJob(FPending[i]).DueAt <= tick then
                     begin
                     job := TBackupCopyJob(FPending.Extract(FPending[i]));
                     FBusy := True;
                     Break;
                     end;
                  end;
               end;

            (* Nothing due: sleep until the earliest thing that will be. *)
            if (not doProbe) and (job = nil) then
               begin
               if (FProbeDueAt <> NOT_DUE) and (FProbeDueAt - tick < wait) then
                  begin
                  wait := FProbeDueAt - tick;
                  end;
               for i := 0 to FPending.Count - 1 do
                  begin
                  if TBackupCopyJob(FPending[i]).DueAt - tick < wait then
                     begin
                     wait := TBackupCopyJob(FPending[i]).DueAt - tick;
                     end;
                  end;
               end;
         finally
            FLock.Release;
         end;

         if (not doProbe) and (job = nil) then
            begin
            if wait < 1 then
               begin
               wait := 1;
               end;
            FWake.WaitFor(Cardinal(wait));
            Continue;
            end;

         (* THE FILE I/O, WITH NO LOCK HELD. *)
         written := '';
         ok := False;
         try
            if doProbe then
               begin
               ok := ProbeDestination(folder, why);
               end
            else
               begin
               ok := CopyToDestination(job.Outbox, job.FinalName, folder,
                                       job.OnlyIfDifferent, written, why);
               end;
         except
            on E: Exception do
               begin
               ok := False;
               why := E.Message;
               end;
         end;

         (* THE OUTCOME, under the lock; the reports after it, outside. *)
         eventCount := 0;
         deleteAfter := '';
         FLock.Acquire;
         try
            FBusy := False;
            sameEpoch := epoch = FEpoch;

            if job <> nil then
               begin
               Inc(FAttempts);
               superseded := PendingIndexOf(job.FinalName) >= 0;
               if (ok and sameEpoch) or superseded or (FDestination = '') or FStopping then
                  begin
                  deleteAfter := job.Outbox;
                  FreeAndNil(job);
                  end
               else
                  begin
                  if ok or (not sameEpoch) then
                     begin
                     (* It went to a destination that is no longer the one:
                       take it to the new one at once. *)
                     job.DueAt := 0;
                     end
                  else
                     begin
                     job.DueAt := GetTickCount64 + FRetryMs;
                     end;
                  FPending.Add(job);
                  job := nil;
                  end;
               end;

            if sameEpoch then
               begin
               if ok then
                  begin
                  if FHealth = bdhFailing then
                     begin
                     events[eventCount] := bceRecovered;
                     eventDetail[eventCount] := '';
                     Inc(eventCount);
                     end
                  else if (FHealth = bdhUnknown) and doProbe then
                     begin
                     events[eventCount] := bceReachable;
                     eventDetail[eventCount] := '';
                     Inc(eventCount);
                     end;
                  FHealth := bdhWorking;
                  FProbeDueAt := NOT_DUE;
                  if not doProbe then
                     begin
                     events[eventCount] := bceCopied;
                     eventDetail[eventCount] := written;
                     Inc(eventCount);
                     end;
                  end
               else
                  begin
                  if FHealth <> bdhFailing then
                     begin
                     events[eventCount] := bceFailed;
                     eventDetail[eventCount] := why;
                     Inc(eventCount);
                     end;
                  FHealth := bdhFailing;
                  (* Probe again on the retry clock, so a recovery is seen with
                    nothing pending. *)
                  FProbeDueAt := GetTickCount64 + FRetryMs;
                  end;
               end;
         finally
            FLock.Release;
         end;

         if deleteAfter <> '' then
            begin
            FOps.DeleteFile(deleteAfter);
            end;
         for i := 0 to eventCount - 1 do
            begin
            Report(events[i], folder, eventDetail[i]);
            end;
         end;
   finally
      FDone.SetEvent;
   end;
end;

end.
