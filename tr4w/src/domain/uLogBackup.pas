unit uLogBackup;

(* PUBLISHING A VERIFIED BACKUP OF THE CONTEST LOG -- the orchestration only.

  WHY THIS IS A UNIT OF ITS OWN. LogStoreBackup in uLogStore had no test
  coverage, and could not have any in place: uLogStore's implementation drags
  in the TRDOS contest engine, which the unit-test program deliberately does
  not link. The careful part of a backup is not the snapshot -- SQLite does
  that -- it is the ORDER of the file operations around it, and that order
  needs nothing from the program at all. So the order lives here, and the two
  things that do need the live log are asked for through two virtual methods:

     SourceIsReady    is the log open and usable?
     SnapshotTo       write a point-in-time copy to this path

  uLogStore overrides them against its own database; the tests override them
  with fakes that write good bytes, write garbage, or raise.

  THE SEQUENCE, which is the contract (extracted verbatim from
  uLogStore.LogStoreBackup on 2026-09-18 -- a move, not a redesign):

     1. a blank destination is refused BEFORE the log is touched
     2. the source is asked whether it is ready
     3. a staged file left by an interrupted run, <destination>.new, is
        deleted -- it was never the backup, because it never published
     4. the snapshot is written to <destination>.new, never to the destination
     5. <destination>.new is opened on its own connection and verified; a
        failure deletes it and reports, leaving the destination and .bak
        exactly as they were
     6. an existing destination is displaced to <destination>.bak, replacing
        any older .bak; with no existing destination an older .bak is left
        alone. A displacement that FAILS stops the run -- the existing backup
        is left where it is and the verified .new is kept and named
     7. <destination>.new is RENAMED to the destination, not copied
     8. any exception from 3 to 7 deletes <destination>.new and reports

  If the rename in 7 fails the verified file is deliberately KEPT at .new and
  the report names it: it is the newest good copy there is.

  NEVER RAISES, and the report is set on every path, because a periodic backup
  runs unattended and its report is the only thing an operator will see. *)

{$I ..\tr4w.inc}

interface

type
   (* ONE BACKUP RUN. A class rather than two procedure variables so that the
     two things a run needs from the live log stay together, and so a test
     fake is an ordinary subclass. *)
   TLogBackup = class(TObject)
   protected
      (* Is the log open and able to be snapshotted? False is reported as
        "could not be opened"; nothing is written. *)
      function SourceIsReady: boolean; virtual; abstract;

      (* Write a consistent copy of the log to aStaged, which does not exist
        when this is called. May raise; the run reports it. *)
      procedure SnapshotTo(const aStaged: string); virtual; abstract;

      (* Is the staged copy sound? Defaults to StagedBackupIsSound below. A
        test overrides it only to make the check itself fail. *)
      function StagedIsSound(const aStaged: string; out aWhy: string): boolean; virtual;
   public
      function Run(const aDestination: string; out aReport: string): boolean;
   end;

(* Open aPath on its OWN connection and ask SQLite whether it is sound. A
  second connection is the point: verifying through the connection that wrote
  it would prove far less, since that one already has the pages in its own
  cache. Never raises; a file that will not open is not sound, and aWhy says
  why. The connection is closed before this returns, which the publish step
  relies on -- a file still open cannot be renamed on Windows.

  IT IS READ-ONLY, AND THAT TOOK A FIX (measured 2026-09-18, fixed
  2026-09-19). This went through TLogDatabase.Open, which WRITES: its PRAGMA
  journal_mode = WAL rewrote header bytes 18, 19, 27 and 95, so the snapshot
  came out of VACUUM INTO in rollback-journal mode and was published in WAL
  mode. The bytes verified were not the bytes snapshotted, and a check that
  alters its subject has not checked what it hands on. It now goes through
  TLogDatabase.OpenReadOnly -- the connector's own sofReadOnly path, no
  write-side pragmas, no migration -- and the published backup is byte for
  byte the file SQLite produced. The check itself is unchanged and is still a
  real integrity_check plus foreign_key_check. Pinned by uTestLogBackup. *)
function StagedBackupIsSound(const aPath: string; out aWhy: string): boolean;

implementation

uses
   SysUtils, uLogDatabase;

function StagedBackupIsSound(const aPath: string; out aWhy: string): boolean;
var
   check: TLogDatabase;
   verdict: TIntegrityResult;
begin
   Result := False;
   aWhy   := '';
   check  := TLogDatabase.Create;
   try
      try
         check.OpenReadOnly(aPath);
         verdict := check.CheckIntegrity;
         Result  := verdict.Ok;
         if not Result then
            begin
            aWhy := verdict.Report;
            end;
      except
         on E: Exception do
            begin
            (* It would not even OPEN, which is the most important failure to
              report plainly: the snapshot statement said it succeeded. *)
            aWhy := E.Message;
            end;
      end;
   finally
      check.Free;
   end;
end;

function TLogBackup.StagedIsSound(const aStaged: string; out aWhy: string): boolean;
begin
   Result := StagedBackupIsSound(aStaged, aWhy);
end;

function TLogBackup.Run(const aDestination: string; out aReport: string): boolean;
var
   staged: string;
   previous: string;
   why: string;
begin
   Result  := False;
   aReport := '';

   if Trim(aDestination) = '' then
      begin
      aReport := 'No backup file name is set. See BACKUP LOG FILE NAME.';
      Exit;
      end;

   if not SourceIsReady then
      begin
      aReport := 'The contest log could not be opened, so it was not backed up.';
      Exit;
      end;

   staged   := aDestination + '.new';
   previous := aDestination + '.bak';

   try
      (* A staged file left by an interrupted run would make SnapshotTo refuse,
        and it is worth nothing -- the whole point of staging is that it is not
        the backup until it verifies. *)
      if FileExists(staged) then
         begin
         DeleteFile(staged);
         end;

      SnapshotTo(staged);

      if not StagedIsSound(staged, why) then
         begin
         DeleteFile(staged);
         aReport := Format('The backup of %s failed its integrity check and '
                           + 'was discarded: %s', [aDestination, why]);
         Exit;
         end;

      (* PUBLISH. The previous backup is displaced rather than deleted, so a
        machine that dies between these two renames still has one good copy
        under one of the two names. *)
      if FileExists(aDestination) then
         begin
         if FileExists(previous) then
            begin
            DeleteFile(previous);
            end;

         (* THE RESULT IS HONOURED, AND UNTIL 2026-09-19 IT WAS DISCARDED.
           What that cost differs by platform and was worse on Unix. On
           Windows the publish rename below then failed as well (MoveFileW
           will not overwrite an existing target), so the operator was told
           the file "could not be renamed" and never that a backup generation
           had gone. On Unix rename(2) DOES overwrite, so the publish
           succeeded and the previous generation simply vanished, silently,
           with no .bak left at all.

           So a displacement that fails stops the run. The destination still
           holds the previous backup -- the rename is what failed, so nothing
           moved -- and .new still holds the new one, verified. Nothing good
           is lost and both are named. *)
         if not RenameFile(aDestination, previous) then
            begin
            aReport := Format('The backup was written and verified, but the '
                              + 'existing backup at %s could not be moved '
                              + 'aside to %s, so it was left alone. The new '
                              + 'backup is at %s.',
                              [aDestination, previous, staged]);
            Exit;
            end;
         end;

      if not RenameFile(staged, aDestination) then
         begin
         aReport := Format('The backup was written and verified but could not '
                           + 'be renamed to %s. It is at %s.',
                           [aDestination, staged]);
         Exit;
         end;

      aReport := Format('Log backed up to %s.', [aDestination]);
      Result  := True;
   except
      on E: Exception do
         begin
         (* NOT a reason to disable the log. A backup that fails says nothing
           about whether the log itself is writable, and switching the store
           off here would turn a full backup volume into a contest that cannot
           log. The caller decides what else to do; this only reports. *)
         if FileExists(staged) then
            begin
            DeleteFile(staged);
            end;
         aReport := Format('The backup to %s failed: %s',
                           [aDestination, E.Message]);
         end;
   end;
end;

end.
