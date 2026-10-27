{
 Copyright Dmitriy Gulyaev UA4WLI 2015.

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
 }
unit uGetServerLog;
{$I tr4w.inc}
{$IMPORTEDDATA OFF}
interface

uses
  Classes,
  IdGlobal,    // TIdBytes -- the password's wire form, in FetchServerLog
  TF,
  VC,
  uNetCatchUp;

(* CATCHING UP FROM THE SERVER'S LOG -- Phase 1, C6 (2026-10-27).

  NY4I: "Late catch-up has to be supported as it was ... to handle a station
  that comes up (reboots) in the middle of the contest." The rules, and why
  the D7 mechanism (a CRC32 of the .TRW, then REPLACE the log with the server's
  file) could not be kept, are uNetCatchUp's header. This unit is the part that
  has a socket, a thread and a log.

  WHAT THE OPERATOR SEES, as it was in D7:

    ON CONNECT, once the server's HELLO has proved the link (uNet.
      NetServiceCatchUp): the log is fetched and compared with this one. If the
      server holds QSOs this log lacks, SERVER AUTO SYNCHRONIZE LOG ON CONNECT
      adds them; with it off the operator is ASKED, with the count. Nothing is
      said when the log is already complete.
    NET > SYNCHRONIZE opens the Synchronize window (uServerLogForm): Get server
      log downloads and SHOWS the server's log, and the button that D7 called
      "Create and use new log" now ADDS the QSOs this log lacks. It no longer
      replaces anything.

  THE THREADS. The download is a worker (a socket read cannot be allowed to
  freeze the keyboard). It owns its own connection and only fills memory: no
  settings, no log, no widget. The comparison, the backup, the write and the
  rescore are the MAIN thread's, because the repository is not thread-safe. The
  worker hands over by RunOnMainThread. *)
type
  (* WHO ASKED FOR THE FETCH. *)
  TCatchUpOrigin = (
     cuOnConnect,    // the link came up: add on its own, or ask
     cuInWindow      // the Synchronize window's Get server log: show, and add on request
  );

(* START A CATCH-UP FETCH. MAIN THREAD. False, and nothing started, when one is
  already under way (it is the operator's to retry) or when no contest is
  selected. *)
function StartServerCatchUp(aOrigin: TCatchUpOrigin): boolean;

(* THE MERGE: add to the contest log every record of aImage that it lacks and
  that is for this contest (uNetCatchUp.BuildCatchUpPlan), INSERT ONLY.

  MAIN THREAD. The plan is made HERE, from the keys the log holds at this
  moment, so a QSO that reached the log between a question and its answer is
  not added twice. Nothing is changed unless there is something to add. If there
  is, it goes in this order: a verified backup of the log in aBackupDir (a log
  that cannot be backed up is not written to), then ONE transaction for every
  record (all or none). aAdded is how many went in; aSkippedContest how many were left
  out because they belong to another contest or to none that can be told. False
  says why in aWhy and the log is as it was. It does not rescore. *)
function MergeServerLog(aImage: TServerLogImage; const aBackupDir: string;
                        out aAdded, aSkippedContest: integer;
                        out aWhy: string): boolean;

(* THE MERGE AND EVERYTHING AROUND IT, as the operator meets it: MergeServerLog
  into uAppPaths.BackupDir, then a rescore (the new rows are scored like any
  other import), the notice, and the log line; a failure is a warning and an
  Error line. True when the log was brought up to date (also when there was
  nothing to add). MAIN THREAD. *)
function AddServerLogToLog(aImage: TServerLogImage): boolean;

(* THE DOWNLOAD ITSELF, on a connection of its own to the server's second port.
  Exported for the unit tests, which run it against a socket they serve; the
  program calls it from the worker. Runs on the CALLING thread and reads no
  setting: the host, the port and the password's wire form are handed in. True
  when exactly the size the server stated has been written to aInto. False says
  why in aWhy and aInto holds whatever arrived. *)
function FetchServerLog(const aHost: AnsiString; aPort: integer;
                        const aPassword: TIdBytes; aInto: TStream;
                        out aDeclaredSize: Int64; out aWhy: string): boolean;

(* HOW MANY QSOS THE SERVER HOLDS THAT THIS LOG DOES NOT, without changing
  anything. False when the log could not be read. MAIN THREAD. *)
function CountMissingFromServer(aImage: TServerLogImage; out aMissing: integer): boolean;

(* HOW THE DOWNLOAD THREAD TALKS TO THE WINDOW.

  The worker may not touch an LCL control, so it calls this, and this queues
  the report to the main thread (RunOnMainThread) where the form's handler
  runs. A report is a field and a value; the worker overwrites its locals
  immediately, so the pair travels as a record.

  A no-op when no window is listening, which is both the on-connect path and the
  window having closed mid-download. *)
procedure ReportSyncProgress(aField: integer; aValue: integer);

(* THE LAST DOWNLOAD THE SYNCHRONIZE WINDOW SHOWS, as records, for its grid. The
  grid is virtual: it asks for the rows it paints, on the main thread, and the
  image behind it is only ever replaced or released on the main thread. The
  window releases it when it closes. *)
function TryGetServerLogRow(const aIndex: integer;
                            out aRecord: ContestExchange): boolean;
function ServerLogWindowImage: TServerLogImage;
procedure ReleaseServerLogImage;

type
  (* WHAT A PROGRESS REPORT IS. A plain procedure, not a method: the worker
    thread has no object to call and the form installs a unit-level wrapper. *)
  TSyncProgressProc = procedure(aField: integer; aValue: integer);

  (* One report, carried across the marshalling call. RunOnMainThread takes a
    single PtrInt, and a field plus a value do not fit in one without packing
    them -- and a byte count is too big to pack safely. *)
  PSyncProgress = ^TSyncProgress;
  TSyncProgress = record
     Field: integer;
     Value: integer;
  end;

var
  { Installed last in HandleShow and cleared FIRST in HandleClose. }
  (* WHERE A PROGRESS REPORT GOES, or nil while no window is listening.

    This was ServerLogFormWnd: HWND, and ReportSyncProgress SendMessage'd
    WM_USER_SYNC_PROGRESS at it. A callback says the same thing without a
    window handle, a private message id or a `message` directive -- and it is
    the form that installs it, so the form's behaviour is discoverable from the
    form. *)
  SyncProgressHandler                   : TSyncProgressProc = nil;
  showresverlogcontent                  : boolean = True;

const
  (* Progress, worker -> sync window. See ReportSyncProgress. The first four are
    reported ON THE MAIN THREAD once the download is whole. *)
  SYNC_FIELD_RECORDS        = 1;   // records in the server's log
  SYNC_FIELD_BYTES          = 2;   // bytes received so far (from the worker)
  SYNC_FIELD_QSOS           = 3;   // the QSOs among them that count
  SYNC_FIELD_ENABLE_REPLACE = 4;   // the log lacks QSOs; the value is how many
  SYNC_FIELD_FAILED         = 5;   // the download failed; Get server log may be pressed again

implementation
uses SysUtils,
   IdTCPClient, // the log download -- see FetchServerLog
   LCLType,     // IDYES
   LogWind,     // QuickDisplay
   PostUnit,    // Contest
   uMainThread,  { RunOnMainThread -- the finished handoff, see CatchUpFetched }
   MainUnit,     // RescoreLog, YesOrNo, logger
   uNet,         // NetPeers, NetIsConnected
   uNetClient,       (* ServerPasswordOnWire -- the one wire form *)
   uSettingsModel,   (* Settings.Server *)
   uAppStrings,
   uTR4WStrings,     (* TC_FAILEDTORECEIVESERVERLOG *)
   uAppPaths,        (* BackupDir *)
   uContestRegistry,
   uLogStore,
   uQsoMyFacts,
   uServerQsoIndex;

{ GetServerLogDlgProc STOOD HERE and went with dialog template 73 on
  2026-08-29 -- the last Win32 dialog in the program. Its window is
  ui\lcl\uServerLogForm now, and every arm of that case statement is a method
  on the form. }

var
   (* The download the Synchronize window is showing. MAIN thread only. *)
   GWindowImage: TServerLogImage = nil;
   (* A fetch is under way, or the question it raised is open. MAIN thread only.
     The worker's thread id is not used for this: it is written by the starter
     after BeginThread returns, and a thread that finishes first would clear it
     before it was set. *)
   GCatchUpBusy: boolean = False;
   GCatchUpThreadID: TThreadID;

(* ------------------------------------------------------------ the window's rows *)

function ServerLogWindowImage: TServerLogImage;
begin
   Result := GWindowImage;
end;

function TryGetServerLogRow(const aIndex: integer;
                            out aRecord: ContestExchange): boolean;
begin
   Result := False;
   if GWindowImage <> nil then
      begin
      Result := GWindowImage.Row(aIndex, aRecord);
      end;
end;

procedure ReleaseServerLogImage;
begin
   FreeAndNil(GWindowImage);
end;

(* Delivers one report on the main thread, and owns the record it was handed. *)
procedure DeliverSyncProgress(aData: PtrInt);
var
   p: PSyncProgress;
begin
   p := PSyncProgress(aData);
   try
      if Assigned(SyncProgressHandler) then
         begin
         SyncProgressHandler(p^.Field, p^.Value);
         end;
   finally
      Dispose(p);
   end;
end;

(* CALLED FROM THE WORKER THREAD, which is why this marshals.

  It was SendMessage to the form's HWND -- which crosses to the window's thread
  and BLOCKS the worker until the labels have been repainted. RunOnMainThread
  does not block, and a progress report is exactly the kind of thing that should
  not hold up the work it is reporting on. A report that arrives LATE
  understates the count, which is the safe side. *)
procedure ReportSyncProgress(aField: integer; aValue: integer);
var
   p: PSyncProgress;
begin
   if not Assigned(SyncProgressHandler) then
      begin
      Exit;
      end;
   New(p);
   p^.Field := aField;
   p^.Value := aValue;
   RunOnMainThread(@DeliverSyncProgress, PtrInt(p));
end;

(* --------------------------------------------------------------- the download *)

(* THE LOG DOWNLOAD, ON INDY -- into MEMORY, on the worker's own connection.

  THE PROTOCOL, which was never written down: connect to the server's port
  PLUS ONE, write ten bytes of password, then read a four-byte size in NATIVE
  byte order and exactly that many bytes. The size is the file's, header
  included.

  D7 READ UNTIL THE PEER WENT QUIET (two seconds of silence ended the transfer)
  and compared the byte count with the size afterwards. The size is stated up
  front, so this reads exactly that many and a short transfer is a read that
  fails, naming how far it got.

  TWO THINGS THAT LOOK LIKE TRANSLATION AND ARE NOT:

  1. ReadInt32(AConvert := False). Indy converts from NETWORK byte order by
     default; those four bytes are native. On a little-endian machine the
     default would have turned a 25,000-byte log into 3,347,644,416.
  2. THE FOUR-BYTE HEADER IS READ AS A HEADER, not skipped out of whatever the
     first read happened to return. TCP does not promise four bytes at once.

  NO SETTINGS ARE READ HERE: the starter captured the address, port and the
  password's wire form on the main thread. Runs on the worker; aProgress is
  called there too. *)
function FetchServerLog(const aHost: AnsiString; aPort: integer;
                        const aPassword: TIdBytes; aInto: TStream;
                        out aDeclaredSize: Int64; out aWhy: string): boolean;
const
   CONNECT_TIMEOUT_MS = 5000;
   IDLE_TIMEOUT_MS    = 15000;   // nothing arriving for this long ends the transfer
   CHUNK_BYTES        = 65536;
var
   Client:    TIdTCPClient;
   Chunk:     TIdBytes;
   Remaining: Int64;
   Take:      integer;
   Received:  Int64;
begin
   Result        := False;
   aDeclaredSize := 0;
   aWhy          := '';
   Received      := 0;

   Client := TIdTCPClient.Create(nil);
   try
      Client.Host           := aHost;
      Client.Port           := aPort;
      Client.ConnectTimeout := CONNECT_TIMEOUT_MS;
      Client.ReadTimeout    := IDLE_TIMEOUT_MS;

      try
         Client.Connect;
      except
         on E: Exception do
            begin
            (* REPORTED, not silent: a wrong address and a refused connection
              are different answers. *)
            aWhy := 'could not connect to ' + string(aHost) + ':' +
                    IntToStr(aPort) + ' -- ' + E.Message;
            Exit;
            end;
      end;

      try
         Client.IOHandler.Write(aPassword);

         aDeclaredSize := Client.IOHandler.ReadInt32(False);   // native order
         if (aDeclaredSize < 0) or (aDeclaredSize > SERVER_LOG_MAX_BYTES) then
            begin
            aWhy := 'the server stated an impossible log size (' +
                    IntToStr(aDeclaredSize) + ' bytes)';
            Exit;
            end;

         Remaining := aDeclaredSize;
         while Remaining > 0 do
            begin
            Take := CHUNK_BYTES;
            if Remaining < Take then
               begin
               Take := Integer(Remaining);
               end;

            SetLength(Chunk, 0);
            Client.IOHandler.ReadBytes(Chunk, Take, False);
            aInto.WriteBuffer(Chunk[0], Length(Chunk));
            Inc(Received, Length(Chunk));
            Dec(Remaining, Length(Chunk));
            ReportSyncProgress(SYNC_FIELD_BYTES, Received);
            end;

         Result := True;
      except
         on E: Exception do
            begin
            (* A READ THAT FAILS LEAVES WHAT HAD ARRIVED IN INDY'S BUFFER. Keep it
              -- the caller was promised whatever arrived -- and count it, so the
              report says how far the transfer really got. *)
            try
               if Client.IOHandler.InputBuffer.Size > 0 then
                  begin
                  SetLength(Chunk, 0);
                  Client.IOHandler.InputBuffer.ExtractToBytes(
                     Chunk, Client.IOHandler.InputBuffer.Size);
                  aInto.WriteBuffer(Chunk[0], Length(Chunk));
                  Inc(Received, Length(Chunk));
                  end;
            except
               (* What could not be salvaged is simply not counted. *)
            end;
            aWhy := 'the transfer failed after ' + IntToStr(Received) +
                    ' of ' + IntToStr(aDeclaredSize) + ' byte(s) -- ' + E.Message;
            end;
      end;
   finally
      try
         Client.Disconnect;
      except
         (* Closing a connection that already failed has nothing to add. *)
      end;
      Client.Free;
   end;
end;

type
   (* ONE FETCH, from the main thread that asked to the worker and back. *)
   TFetchJob = class(TObject)
   public
      Origin:   TCatchUpOrigin;
      Host:     AnsiString;
      Port:     integer;
      Password: TIdBytes;
      Image:    TServerLogImage;
      Ok:       boolean;
      Why:      string;
      destructor Destroy; override;
   end;

destructor TFetchJob.Destroy;
begin
   Image.Free;
   inherited Destroy;
end;

(* THE CONTEST, as the judge needs to know it. *)
function CurrentCatchUpContext: TCatchUpContext;
var
   legacyNumber: integer;
begin
   Result.Peers := NetPeers;
   Result.OurContestId := ContestId(Contest);
   Result.OurHandle := Contest;
   Result.OurIsLegacy := ContestLegacyNumber(Contest, legacyNumber);
end;

(* THE PLAN against the log as it is NOW. False, with nil, when the log's keys
  cannot be read: a plan made without them would add what is already there. *)
function MakePlan(aImage: TServerLogImage; out aPlan: TCatchUpPlan): boolean;
var
   keys: TQsoSessionKeys;
   held: TServerQsoIndex;
   i: integer;
begin
   Result := False;
   aPlan := nil;

   if not LogStoreCollectSessionKeys(keys) then
      begin
      Exit;
      end;

   held := TServerQsoIndex.Create;
   try
      for i := 0 to High(keys) do
         begin
         held.Add(Cardinal(keys[i].SessionId), Cardinal(keys[i].SessionSeq));
         end;
      aPlan := BuildCatchUpPlan(aImage, held, CurrentCatchUpContext);
      Result := True;
   finally
      held.Free;
   end;
end;

function CountMissingFromServer(aImage: TServerLogImage; out aMissing: integer): boolean;
var
   plan: TCatchUpPlan;
begin
   aMissing := 0;
   Result := MakePlan(aImage, plan);
   if Result then
      begin
      try
         aMissing := plan.Count;
         logger.Info('[Net] catch-up: %s', [CatchUpSummary(plan)]);
      finally
         plan.Free;
      end;
      end;
end;

function MergeServerLog(aImage: TServerLogImage; const aBackupDir: string;
                        out aAdded, aSkippedContest: integer;
                        out aWhy: string): boolean;
var
   plan: TCatchUpPlan;
   appends: TLogQsoAppends;
   facts: TQsoMyFacts;
   rec: ContestExchange;
   i, failedIndex: integer;
   backupPath, backupReport, failure: string;
begin
   Result := False;
   aAdded := 0;
   aSkippedContest := 0;
   aWhy := '';

   if not MakePlan(aImage, plan) then
      begin
      aWhy := 'the log could not be read to find what it lacks';
      Exit;
      end;

   try
      logger.Info('[Net] catch-up: %s', [CatchUpSummary(plan)]);
      aSkippedContest := plan.Skipped(cusOtherContest) +
                         plan.Skipped(cusUnknownContest);

      if plan.Count = 0 then
         begin
         Result := True;
         Exit;
         end;

      (* A VERIFIED BACKUP FIRST, AND NO WRITE WITHOUT ONE. This only inserts, but
        it inserts into the contest log from a file this station did not make. *)
      if not LogStoreBackupBeforeCatchUp(aBackupDir, backupPath, backupReport) then
         begin
         aWhy := 'the backup of the log taken first failed -- ' + backupReport;
         logger.Error('[Net] catch-up: not added: %s', [aWhy]);
         Exit;
         end;
      logger.Info('[Net] catch-up: log backed up to %s', [backupPath]);

      (* THE STATION IS OURS, ASSUMED: the V1 record carries no station of its
        own, so each QSO is stamped with THIS station's values and marked so
        (ruling D), exactly as a QSO that arrives live is. It stores no sent
        exchange: we do not know what the author sent. *)
      facts := LogStoreCurrentMyFacts;
      facts.Source := mfsAssumed;

      appends := TLogQsoAppends.Create;
      try
         for i := 0 to plan.Count - 1 do
            begin
            aImage.Row(plan.RowIndex(i), rec);
            StampCaughtUp(rec, Contest);
            appends.Add(rec, facts, '');
            end;

         if not LogStoreAppendQSOs(appends, failedIndex, failure) then
            begin
            aWhy := 'the QSOs could not be written to the log (' + failure + ')';
            logger.Error('[Net] catch-up: not added: %s', [aWhy]);
            Exit;
            end;
      finally
         appends.Free;
      end;

      aAdded := plan.Count;
      Result := True;
   finally
      plan.Free;
   end;
end;

function AddServerLogToLog(aImage: TServerLogImage): boolean;
var
   added, skipped: integer;
   why, notice: string;
begin
   Result := MergeServerLog(aImage, BackupDir, added, skipped, why);

   if not Result then
      begin
      showwarning(SysUtils.Format(SCatchUpMergeFailed, [why]));
      Exit;
      end;

   if added > 0 then
      begin
      (* The new rows are scored like any other import: the rescore walks the
        whole log, recomputes dupes and multipliers in log order, and reloads
        every display. *)
      RescoreLog;
      logger.Info('[Net] catch-up: %d QSO(s) added from the server', [added]);
      end;

   if (added > 0) or (skipped > 0) then
      begin
      notice := '';
      if added > 0 then
         begin
         notice := SysUtils.Format(SNetCaughtUp, [added]);
         end;
      if skipped > 0 then
         begin
         if notice <> '' then
            begin
            notice := notice + ' ';
            end;
         notice := notice + SysUtils.Format(SCatchUpSkipped, [skipped]);
         end;
      QuickDisplay(notice);
      end;
end;

(* -------------------------------------------------------------- the worker *)

procedure CatchUpFetched(aData: PtrInt); forward;

function CatchUpThread(aParameter: Pointer): DWORD; stdcall;
var
   job: TFetchJob;
   declared: Int64;
   why: string;
begin
   Result := 0;   (* the thread exit code -- see TF.TTR4WThreadStart *)
   job := TFetchJob(aParameter);

   try
      job.Ok := FetchServerLog(job.Host, job.Port, job.Password,
                               job.Image.Data, declared, why);
      if job.Ok then
         begin
         job.Ok := job.Image.Accept(declared, why);
         end;
      job.Why := why;
   except
      on E: Exception do
         begin
         job.Ok := False;
         job.Why := E.ClassName + ': ' + E.Message;
         end;
   end;

   RunOnMainThread(@CatchUpFetched, PtrInt(job));
end;

(* ON CONNECT: ADD ON ITS OWN, OR ASK, OR SAY NOTHING.

  Nothing is said when the log is already complete -- a link that comes up and
  goes down all night would otherwise announce it every time. *)
procedure DecideOnConnect(aImage: TServerLogImage);
var
   missing: integer;
begin
   if not CountMissingFromServer(aImage, missing) then
      begin
      logger.Error('[Net] catch-up: the log could not be read; nothing was added');
      Exit;
      end;

   if missing = 0 then
      begin
      Exit;
      end;

   if not Settings.Server.AutoSynchronizeLogOnConnect then
      begin
      if YesOrNo(SysUtils.Format(SCatchUpAsk, [missing])) <> IDYES then
         begin
         logger.Info('[Net] catch-up: %d QSO(s) on the server were not added ' +
                     '(the operator declined)', [missing]);
         Exit;
         end;
      end;

   AddServerLogToLog(aImage);
end;

(* IN THE WINDOW: SHOW WHAT WAS FETCHED and say how many the log lacks. The
  image is the window's from here, until it is replaced or the window closes. *)
procedure ShowFetchedInWindow(aJob: TFetchJob);
var
   missing: integer;
begin
   ReleaseServerLogImage;
   GWindowImage := aJob.Image;
   aJob.Image := nil;

   SyncProgressHandler(SYNC_FIELD_RECORDS, GWindowImage.Count);
   SyncProgressHandler(SYNC_FIELD_QSOS, GWindowImage.QsoCount);

   if CountMissingFromServer(GWindowImage, missing) then
      begin
      if missing > 0 then
         begin
         SyncProgressHandler(SYNC_FIELD_ENABLE_REPLACE, missing);
         end;
      end
   else
      begin
      logger.Error('[Net] catch-up: the log could not be read, so what it lacks ' +
                   'is not known');
      end;
end;

(* THE WORKER HAS FINISHED -- ON THE MAIN THREAD. *)
procedure CatchUpFetched(aData: PtrInt);
var
   job: TFetchJob;
begin
   job := TFetchJob(aData);
   try
      if not job.Ok then
         begin
         logger.Error('[Net] catch-up: could not read the server log -- %s', [job.Why]);
         if job.Origin = cuInWindow then
            begin
            if Assigned(SyncProgressHandler) then
               begin
               SyncProgressHandler(SYNC_FIELD_FAILED, 0);
               end;
            showwarning(TC_FAILEDTORECEIVESERVERLOG + LineEnding + job.Why);
            end
         else
            begin
            QuickDisplay(SysUtils.Format(SCatchUpFetchFailed, [job.Why]));
            end;
         Exit;
         end;

      logger.Info('[Net] catch-up: the server log holds %d record(s), %d QSO(s) ' +
                  '(%d bytes)', [job.Image.Count, job.Image.QsoCount,
                                 job.Image.Data.Size]);

      if job.Origin = cuInWindow then
         begin
         (* The window may have been closed while the bytes came. *)
         if Assigned(SyncProgressHandler) then
            begin
            ShowFetchedInWindow(job);
            end;
         end
      else
         begin
         DecideOnConnect(job.Image);
         end;
   finally
      GCatchUpBusy := False;
      job.Free;
   end;
end;

function StartServerCatchUp(aOrigin: TCatchUpOrigin): boolean;
var
   job: TFetchJob;
begin
   Result := False;

   if GCatchUpBusy then
      begin
      logger.Info('[Net] catch-up: one is already under way');
      Exit;
      end;

   if Contest = NoContest then
      begin
      logger.Info('[Net] catch-up: no contest is selected, so there is nothing ' +
                  'to compare the server log with');
      Exit;
      end;

   job := TFetchJob.Create;
   job.Origin := aOrigin;
   (* CAPTURED HERE, on the main thread: the worker reads no settings. AnsiString,
     because Indy is built without UnicodeStrings and a string would be widened
     and narrowed again. *)
   job.Host := AnsiString(Settings.Server.Address);
   job.Port := Settings.Server.Port + 1;
   job.Password := ServerPasswordOnWire(AnsiString(Settings.Server.Password));
   job.Image := TServerLogImage.Create;

   GCatchUpBusy := True;
   if not ThreadStarted(tCreateThread(CatchUpThread, GCatchUpThreadID, False, job)) then
      begin
      logger.Error('[Net] catch-up: could not start the download thread');
      GCatchUpBusy := False;
      job.Free;
      Exit;
      end;

   Result := True;
end;

initialization

finalization
   FreeAndNil(GWindowImage);

end.
