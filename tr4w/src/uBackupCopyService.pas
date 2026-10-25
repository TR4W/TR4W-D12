unit uBackupCopyService;
{$I tr4w.inc}

(*
 Copyright Thomas M. Schaefer, NY4I (c) 2026.
 This file is part of TR4W  (SRC)
 TR4W is free software: you can redistribute it and/or
 modify it under the terms of the GNU General Public License as
 published by the Free Software Foundation, either version 2 of the
 License, or (at your option) any later version.
 TR4W is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.
 You should have received a copy of the GNU General
     Public License along with TR4W in  GPL_License.TXT.
 If not, ref:
 http://www.gnu.org/licenses/gpl-3.0.txt
*)

(*
  THE PROGRAM'S ONE BACKUP COPIER -- the glue between uBackupCopier (a domain
  unit that knows files, threads and nothing else) and the running program:
  the setting, the log file, the status line and tr4w.log. Issue #98 step 2.

  WHAT HAPPENS, AND ON WHICH THREAD:

    startup (main)     BackupCopyStart: the copier and its worker, the
                       destination from BACKUP DESTINATION (which probes it),
                       and -- if this log's periodic backup is already in
                       uAppPaths.BackupDir -- a copy of it, made only if the
                       destination's copy is missing or different. So a
                       share that was down at the last QSO is caught up at
                       the next start with no new QSO.
    Preferences (main) BackupCopyDestinationChanged, from uSettingsEffects:
                       the new folder is probed; the old one's state goes.
    every N QSOs (main) logstuff.BackupLogNow writes the LOCAL backup and
                       BackupCopySubmit queues it. One local file copy; the
                       destination is the worker's.
    worker             probes, copies, retries every 60 s, and reports.
    shutdown (main)    BackupCopyStop, bounded.

  A REPORT ARRIVES ON THE WORKER THREAD. It is written to tr4w.log there (Log4D
  is called from worker threads elsewhere too -- uNetSendQueue's writer) and
  QUEUED for the status line with Application.QueueAsyncCall, the uNet
  pattern: TThread.Queue would purge its own callback when the queuing thread
  ends. The notices wait in a locked list, and the main thread drains it.

  WHAT AN OPERATOR SEES. The health is reported as TRANSITIONS: one line when
  the destination first answers, one when backups stop reaching it (with a
  warning beep, and an Error line in tr4w.log), one when they reach it again.
  Repeated failures are silent. Each generation that ARRIVES says so --
  "Backup copied to <file>", no beep, and an Info line -- because without it
  the only thing on screen was the local file's name, and NY4I read that as
  the destination being ignored (2026-10-25). A generation the destination
  ALREADY HELD -- the at-open offer, found identical -- writes nothing and
  shows nothing; it is an Info line only ("already up to date at <file>").
  A failure NEVER stops logging --
  nothing here can refuse a QSO.

  SHUTDOWN WAITS AT MOST BACKUP_COPY_SHUTDOWN_MS. If the worker is still
  inside a file operation -- a share that hangs -- the copier is NOT freed:
  the worker still uses it, the process is exiting, and what the worker holds
  is file handles and memory, never a SQLite object (see uBackupCopier). The
  report callback is detached first, so nothing reaches the UI during
  shutdown, and the queued notices are removed before their receiver goes.

  NOT UNDER /EXPORT OR ANY HEADLESS MODE: uProgramMain starts this after every
  headless Halt, so a corpus run never probes a share.
*)

interface

uses
   uBackupCopier;    (* TBackupCopyEvent *)

(* Start the copier, once. aBackupDir is uAppPaths.BackupDir; the outbox is
  'outbox' inside it. aLocalPeriodic is this log's periodic backup there
  (uLogStore.LogStorePeriodicBackupFileName); if it exists it is offered to
  the destination, copied only if the destination's copy differs. *)
procedure BackupCopyStart(const aBackupDir, aLocalPeriodic: string);

(* BACKUP DESTINATION changed: tell the copier, which probes a new folder. A
  no-op before BackupCopyStart. *)
procedure BackupCopyDestinationChanged;

(* A local backup was just published at aLocalBackup: queue it for the
  destination, if there is one. Returns at once; never raises.
  True: queued, and aDestination is the folder it is going to. False with an
  empty aWhy: there is no destination (or no copier). False with aWhy set: the
  queueing failed -- logged at Error here, and aWhy is the sentence for the
  status line. *)
function BackupCopySubmit(const aLocalBackup: string;
   out aDestination, aWhy: string): boolean;

(* WHAT THE STATUS LINE SAYS WHEN A BACKUP HAS BEEN WRITTEN LOCALLY. With a
  copy queued, it names the DESTINATION folder, not the local file -- NY4I
  read the local file's name as "the destination was ignored". A failed
  queueing says why. With no destination, the local report as it was. *)
function BackupDoneText(const aLocalReport: string; aQueued: boolean;
   const aDestination, aSubmitWhy: string): string;

(* THE STATUS-LINE NOTICE FOR ONE COPIER REPORT: its text, and whether it is a
  failure (which beeps). Every event has one, bceCopied included, EXCEPT
  bceAlreadyCurrent: an empty aText means nothing is shown (NY4I,
  2026-10-25 -- at open, a destination already holding the backup is not
  news). Pure; the log lines are the receiver's. *)
procedure BackupCopyNotice(aEvent: TBackupCopyEvent;
   const aDestination, aDetail: string;
   out aText: string; out aIsFailure: boolean);

(* Stop the worker, waiting at most BACKUP_COPY_SHUTDOWN_MS. *)
procedure BackupCopyStop;

const
   BACKUP_COPY_SHUTDOWN_MS = 1500;

implementation

uses
   SysUtils, Classes, SyncObjs, Contnrs,
   Forms,            (* Application.QueueAsyncCall -- the main-thread hop *)
   uSettingsModel,   (* Settings.Log.BackupDestination *)
   uAppStrings,      (* the operator's sentences *)
   MainUnit,         (* logger *)
   LogWind,          (* QuickDisplay -- the status line *)
   LogK1EA;          (* DoABeep *)

type
   TBackupNotice = class(TObject)
   public
      Text: string;
      IsFailure: boolean;
   end;

   TBackupCopyReceiver = class(TObject)
   public
      (* ON THE WORKER THREAD. *)
      procedure Received(aEvent: TBackupCopyEvent; const aDestination, aDetail: string);
      (* ON THE MAIN THREAD, through QueueAsyncCall. *)
      procedure ShowNotices(Data: PtrInt);
   end;

var
   GCopier: TBackupCopier = nil;
   GReceiver: TBackupCopyReceiver = nil;
   GNoticeLock: TCriticalSection = nil;
   GNotices: TObjectList = nil;

function DestinationText(const aFolder: string): string;
begin
   if aFolder = '' then
      begin
      Result := 'none (local backups only)';
      end
   else
      begin
      Result := aFolder;
      end;
end;

function BackupDoneText(const aLocalReport: string; aQueued: boolean;
   const aDestination, aSubmitWhy: string): string;
begin
   if aQueued then
      begin
      Result := SysUtils.Format(SBackupCopyingToDestination, [aDestination]);
      end
   else if aSubmitWhy <> '' then
      begin
      Result := aSubmitWhy;
      end
   else
      begin
      Result := aLocalReport;
      end;
end;

procedure BackupCopyNotice(aEvent: TBackupCopyEvent;
   const aDestination, aDetail: string;
   out aText: string; out aIsFailure: boolean);
begin
   aIsFailure := False;
   case aEvent of
      bceReachable:
         begin
         aText := SysUtils.Format(SBackupDestinationReachable, [aDestination]);
         end;
      bceFailed:
         begin
         aText := SysUtils.Format(SBackupCopyFailed, [aDestination, aDetail]);
         aIsFailure := True;
         end;
      bceRecovered:
         begin
         aText := SysUtils.Format(SBackupCopyRecovered, [aDestination]);
         end;
      bceCopied:
         begin
         (* aDetail is the file written at the destination. Said for every
           generation, periodic and Backup Log alike: it is the only sign on
           screen that the copy arrived. No beep. *)
         aText := SysUtils.Format(SBackupCopiedTo, [aDetail]);
         end;
      bceAlreadyCurrent:
         begin
         (* Nothing was written, so nothing is said on screen. *)
         aText := '';
         end;
   end;
end;

procedure TBackupCopyReceiver.Received(aEvent: TBackupCopyEvent;
   const aDestination, aDetail: string);
var
   notice: TBackupNotice;
begin
   case aEvent of
      bceReachable:
         begin
         logger.Info('[BackupCopy] %s is reachable and a file can be written, '
                     + 'renamed and deleted there', [aDestination]);
         end;
      bceFailed:
         begin
         logger.Error('[BackupCopy] backups are NOT reaching %s: %s. Logging '
                      + 'continues; retrying every %d s.',
                      [aDestination, aDetail, BACKUP_COPY_RETRY_MS div 1000]);
         end;
      bceRecovered:
         begin
         logger.Info('[BackupCopy] backups are reaching %s again', [aDestination]);
         end;
      bceCopied:
         begin
         logger.Info('[BackupCopy] copied and verified: %s', [aDetail]);
         end;
      bceAlreadyCurrent:
         begin
         logger.Info('[BackupCopy] already up to date at %s', [aDetail]);
         end;
   end;

   notice := TBackupNotice.Create;
   BackupCopyNotice(aEvent, aDestination, aDetail, notice.Text, notice.IsFailure);
   if notice.Text = '' then
      begin
      (* No status-line notice for this event. *)
      notice.Free;
      Exit;
      end;

   GNoticeLock.Acquire;
   try
      GNotices.Add(notice);
   finally
      GNoticeLock.Release;
   end;

   if (Application <> nil) and (not Application.Terminated) then
      begin
      Application.QueueAsyncCall(ShowNotices, 0);
      end;
end;

procedure TBackupCopyReceiver.ShowNotices(Data: PtrInt);
var
   waiting: TObjectList;
   notice: TBackupNotice;
   i: integer;
begin
   if GNoticeLock = nil then
      begin
      Exit;
      end;

   GNoticeLock.Acquire;
   try
      waiting := GNotices;
      GNotices := TObjectList.Create(True);
   finally
      GNoticeLock.Release;
   end;

   try
      for i := 0 to waiting.Count - 1 do
         begin
         notice := TBackupNotice(waiting[i]);
         QuickDisplay(notice.Text);
         if notice.IsFailure then
            begin
            DoABeep(Warning);
            end;
         end;
   finally
      waiting.Free;
   end;
end;

procedure BackupCopyStart(const aBackupDir, aLocalPeriodic: string);
var
   why: string;
begin
   if GCopier <> nil then
      begin
      Exit;
      end;

   GNoticeLock := TCriticalSection.Create;
   GNotices := TObjectList.Create(True);
   GReceiver := TBackupCopyReceiver.Create;
   GCopier := TBackupCopier.Create(TBackupFileOps.Create,
                                   IncludeTrailingPathDelimiter(aBackupDir) + 'outbox',
                                   BACKUP_COPY_RETRY_MS, GReceiver.Received);
   BackupCopyDestinationChanged;

   (* AT OPEN: the destination may have missed the last generation -- it was
     down, or the program closed before the copy finished. Copied only if the
     destination's file is missing or different. *)
   if (GCopier.Destination <> '') and FileExists(aLocalPeriodic) then
      begin
      if GCopier.Submit(aLocalPeriodic, True, why) then
         begin
         logger.Info('[BackupCopy] at open: %s offered to %s',
                     [aLocalPeriodic, GCopier.Destination]);
         end
      else
         begin
         logger.Warn('[BackupCopy] at open: %s', [why]);
         end;
      end;
end;

procedure BackupCopyDestinationChanged;
var
   folder: string;
begin
   if GCopier = nil then
      begin
      Exit;
      end;
   folder := Trim(Settings.Log.BackupDestination);
   logger.Info('[BackupCopy] backup destination: %s', [DestinationText(folder)]);
   GCopier.SetDestination(folder);
end;

function BackupCopySubmit(const aLocalBackup: string;
   out aDestination, aWhy: string): boolean;
begin
   Result := False;
   aDestination := '';
   aWhy := '';
   if (GCopier = nil) or (GCopier.Destination = '') then
      begin
      Exit;
      end;
   aDestination := GCopier.Destination;
   Result := GCopier.Submit(aLocalBackup, False, aWhy);
   if not Result then
      begin
      (* LOCAL, so the caller says it on the spot: the outbox copy failed, or
        the destination is the local backup folder itself. *)
      logger.Error('[BackupCopy] %s', [aWhy]);
      end;
end;

procedure BackupCopyStop;
var
   folder: string;
begin
   if GCopier = nil then
      begin
      Exit;
      end;

   folder := GCopier.Destination;
   if GCopier.Shutdown(BACKUP_COPY_SHUTDOWN_MS) then
      begin
      FreeAndNil(GCopier);
      end
   else
      begin
      (* DELIBERATELY NOT FREED: the worker is still inside a file operation
        on the destination and uses the copier. See the unit header. *)
      logger.Warn('[BackupCopy] shutdown: still copying to %s after %d ms; '
                  + 'left to the operating system. Only a .partial can be left '
                  + 'there, never a backup.', [folder, BACKUP_COPY_SHUTDOWN_MS]);
      GCopier := nil;
      end;

   (* The callback is detached (Shutdown did that first), so no new notice
     can arrive; the queued ones go before their receiver does. *)
   if Application <> nil then
      begin
      Application.RemoveAsyncCalls(GReceiver);
      end;
   FreeAndNil(GReceiver);
   FreeAndNil(GNotices);
   FreeAndNil(GNoticeLock);
end;

end.
