unit uPeriodicBackupService;
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
  THE PROGRAM'S ONE PERIODIC-BACKUP WORKER -- the glue between
  uLogBackupWorker (a domain unit: a thread, files and SQLite, nothing of the
  program) and the running program. Issue 350.

  WHAT HAPPENS, AND ON WHICH THREAD:

    a QSO makes the backup due, or Backup Log is chosen (main)
                       logstuff.BackupLogNow -> PeriodicBackupRequest: the
                       worker is created on first use, the job is handed
                       over, and the call returns. Nothing else on Enter.
    worker             snapshot, verification, publish, and the outbox copy
                       (uBackupCopyService.BackupCopySubmit, lock-guarded in
                       the copier), then Received.
    worker -> main     Received puts the result in a locked list and asks
                       Application.QueueAsyncCall for Deliver -- the
                       uBackupCopyService pattern, for the same reason
                       (TThread.Queue purges its own callback when the
                       queuing thread ends).
    main               Deliver hands each result to the outcome procedure
                       the request named (logstuff.PeriodicBackupArrived),
                       which does what BackupLogNow did after its run: the
                       count, LogStoreNotePeriodicBackup (issue 351's failure
                       state and retry throttle), the status line, the beep.
    shutdown (main)    PeriodicBackupStop, from tr4w_ShutDown BEFORE
                       BackupCopyStop (the worker may still be submitting to
                       the copier) and before LogStoreClose. It waits for the
                       run in progress; see uLogBackupWorker's header.

  IN FLIGHT. PeriodicBackupInFlight is the MAIN THREAD's view: a request was
  made and its last result has not been delivered yet. logstuff asks it so a
  QSO logged while a backup runs does not ask for another -- the count and
  the published file's age both still say "due" until the result arrives.
*)

interface

uses
   uLogBackupWorker;   (* TLogBackupResult *)

type
   (* ON THE MAIN THREAD. Does not own aResult. *)
   TPeriodicBackupOutcome = procedure(aResult: TLogBackupResult);

(* Hand a backup of aLogFile to aDestination (in aBackupDir) to the worker;
  returns at once. aTag comes back on the result. aOutcome is called on the
  main thread with the result; the newest request's aOutcome is the one
  used. *)
function PeriodicBackupRequest(const aLogFile, aBackupDir, aDestination: string;
   aTag: integer; aOutcome: TPeriodicBackupOutcome): boolean;

(* ALLOW THE WORKER -- called once by uProgramMain beside BackupCopyStart,
  AFTER every headless Halt. Until then PeriodicBackupRequest answers False
  and the caller backs up synchronously: a headless run (/MATRIX logs QSOs
  through LogContact) and the unit-test program never start a thread that
  nothing would stop before Halt. *)
procedure PeriodicBackupEnable;

(* A request made and its result not yet delivered (main thread). *)
function PeriodicBackupInFlight: boolean;

(* Stop the worker: a waiting request is dropped, the run in progress
  finishes. Undelivered results are dropped. A no-op if never started. *)
procedure PeriodicBackupStop;

implementation

uses
   SysUtils, Classes, SyncObjs, Contnrs,
   Forms,              (* Application.QueueAsyncCall -- the main-thread hop *)
   uBackupCopyService; (* BackupCopySubmit -- the outbox copy, on the worker *)

type
   TPeriodicBackupReceiver = class(TObject)
   public
      (* ON THE WORKER THREAD. *)
      procedure Received(aResult: TLogBackupResult);
      (* ON THE MAIN THREAD, through QueueAsyncCall. *)
      procedure Deliver(Data: PtrInt);
   end;

var
   GWorker: TLogBackupWorker = nil;
   GReceiver: TPeriodicBackupReceiver = nil;
   GResultLock: TCriticalSection = nil;
   GResults: TObjectList = nil;
   GOutcome: TPeriodicBackupOutcome = nil;
   GAwaiting: boolean = False;
   GEnabled: boolean = False;

procedure TPeriodicBackupReceiver.Received(aResult: TLogBackupResult);
begin
   GResultLock.Acquire;
   try
      GResults.Add(aResult);
   finally
      GResultLock.Release;
   end;

   if (Application <> nil) and (not Application.Terminated) then
      begin
      Application.QueueAsyncCall(Deliver, 0);
      end;
end;

procedure TPeriodicBackupReceiver.Deliver(Data: PtrInt);
var
   waiting: TObjectList;
   i: integer;
begin
   if (GResultLock = nil) or (GWorker = nil) then
      begin
      Exit;
      end;

   GResultLock.Acquire;
   try
      waiting := GResults;
      GResults := TObjectList.Create(True);
   finally
      GResultLock.Release;
   end;

   try
      for i := 0 to waiting.Count - 1 do
         begin
         if Assigned(GOutcome) then
            begin
            GOutcome(TLogBackupResult(waiting[i]));
            end;
         end;
   finally
      waiting.Free;
   end;

   (* The worker marks a run finished BEFORE it reports it, so Busy here is
     True only when another run is waiting or under way -- and that one will
     report too. *)
   GAwaiting := GWorker.Busy;
end;

procedure PeriodicBackupEnable;
begin
   GEnabled := True;
end;

function PeriodicBackupRequest(const aLogFile, aBackupDir, aDestination: string;
   aTag: integer; aOutcome: TPeriodicBackupOutcome): boolean;
begin
   Result := False;
   if not GEnabled then
      begin
      Exit;
      end;
   Result := True;
   if GWorker = nil then
      begin
      GResultLock := TCriticalSection.Create;
      GResults := TObjectList.Create(True);
      GReceiver := TPeriodicBackupReceiver.Create;
      GWorker := TLogBackupWorker.Create(GReceiver.Received, BackupCopySubmit);
      end;
   GOutcome := aOutcome;
   GAwaiting := True;
   GWorker.Request(TLogBackupJob.Create(aLogFile, aBackupDir, aDestination, aTag));
end;

function PeriodicBackupInFlight: boolean;
begin
   Result := (GWorker <> nil) and GAwaiting;
end;

procedure PeriodicBackupStop;
begin
   (* Nothing after shutdown may start it, worker or not. *)
   GEnabled := False;
   if GWorker = nil then
      begin
      Exit;
      end;
   (* Waits for the run in progress; its result is queued and then dropped
     with the list below (Deliver checks GWorker first). *)
   GWorker.Stop;
   FreeAndNil(GWorker);
   (* The worker has ended, so nothing new can be queued; the queued calls go
     before their receiver does (the uBackupCopyService order). *)
   if Application <> nil then
      begin
      Application.RemoveAsyncCalls(GReceiver);
      end;
   FreeAndNil(GReceiver);
   GResultLock.Acquire;
   try
      FreeAndNil(GResults);
   finally
      GResultLock.Release;
   end;
   FreeAndNil(GResultLock);
   GAwaiting := False;
end;

end.
