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
  TF,
  VC,
  utils_file,
  FileUtil,    // CopyFile -- LazUtils, and it is NOT LazFileUtils
  IdTCPClient, // the log download -- see FetchServerLog
  IdGlobal,    // TIdBytes, RawToBytes
  IdException, // EIdConnClosedGracefully and friends, per CLAUDE.md's snag list
  IdStack,
  Windows,
  LogStuff,
  LogWind,
  uNet,
  LogDupe,
  Tree
  ,
  uTR4WStrings;
(* WHAT THE HEADLESS SYNC DOES WHEN THE DOWNLOAD IS FINISHED, on the main
  thread.

  Was the WM_USER_HEADLESS_SYNC_REPLACE arm of uMainWindowProc.WindowProc,
  reached by SendMessage from the download worker. Every piece of state it
  touches belongs to THIS unit, which is why that arm made the window procedure
  use uGetServerLog. It is a procedure now, handed to RunOnMainThread. *)
procedure HeadlessSyncFinished(aData: PtrInt);

procedure ReplaceLogByServerLog(Replace: boolean);
procedure RunSyncThread;

{ HOW THE DOWNLOAD THREAD TALKS TO THE WINDOW.

  RunSyncThread is a raw thread. It used to write straight into the dialog's
  item ids with SetDlgItemInt, which was safe only because they were Win32
  controls; the window is an LCL form now (ui\lcl\uServerLogForm) and touching
  a control's properties off the main thread is not safe at all.

  So the thread calls this, and this SendMessage's -- Windows marshals the call
  onto the window's own thread and blocks until the handler returns, so the
  handler may assign an LCL property directly. Post would NOT do: the values are
  a running total and the thread overwrites its locals immediately.

  A no-op when no window is listening, which is both the headless path and the
  window having closed mid-download. }
procedure ReportSyncProgress(aField: integer; aValue: integer);

(* THE DOWNLOADED SERVER LOG, AS RECORDS, FOR THE SYNC WINDOW'S GRID.

  RunSyncThread is a WORKER, and it used to fill a Win32 list view a row at a
  time with ListView_InsertItem -- safe by accident, as every raw Win32 call
  from a worker was. An LCL control cannot be touched off the main thread, so
  the grid is VIRTUAL: the worker fills this array and the grid asks for the
  rows it is painting, on the thread that owns them.

  NO LOCK, AND THE REASON IS THE ALLOCATION AND NOT THE ACCESS. The array is
  sized ONCE by ResetServerLogRows, from the record count the download already
  knows -- the same number the old LVM_SETITEMCOUNT carried -- so it never
  reallocates under a reader. Which rows the grid may read is published through
  ReportSyncProgress, a SendMessage, which is the ordering barrier; the grid is
  never told a count the worker has not finished writing. TryGetServerLogRow
  bounds-checks anyway, because a window that closes mid-download is ordinary
  rather than exceptional. *)
procedure ResetServerLogRows(const aCount: integer);
procedure SetServerLogRow(const aIndex: integer;
                          const aRecord: ContestExchange);
function TryGetServerLogRow(const aIndex: integer;
                            out aRecord: ContestExchange): boolean;

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

  NewServerLogHandle                    : THandle;
  AmountQSOsFromServer                  : Cardinal;
  { Installed last in HandleShow and cleared FIRST in HandleClose. }
  (* WHERE A PROGRESS REPORT GOES, or nil while no window is listening.

    This was ServerLogFormWnd: HWND, and ReportSyncProgress SendMessage'd
    WM_USER_SYNC_PROGRESS at it. A callback says the same thing without a
    window handle, a private message id or a `message` directive -- and it is
    the form that installs it, so the form's behaviour is discoverable from the
    form. *)
  SyncProgressHandler                   : TSyncProgressProc = nil;
  SynQSOTotalArray                      : QSOTotalArray;
  SyncMode                              : boolean;
  LogSyncThreadID                       : Cardinal;
  showresverlogcontent                  : boolean = True;
  HeadlessSyncMode                      : boolean = False;  // Issue #912 - run sync without any dialog UI

const
  // Issue #912: SendMessage from RunSyncThread (worker) to the UI thread to
  // drive the post-download replace.  Cannot do this from the worker because
  // LoadinLog (called by ReplaceLogByServerLog) accesses ListView controls,
  // and Win32 controls require all messages from their creating thread.

  // Progress, worker -> sync window.  wParam is one of SYNC_FIELD_*, lParam the
  // value.  Same reasoning as above, generalised: see ReportSyncProgress.
  (* WM_USER_SYNC_PROGRESS IS GONE (2026-09-07) -- see SyncProgressHandler.
    A private window message needed a window; a callback does not. *)

  SYNC_FIELD_RECORDS        = 1;
  SYNC_FIELD_BYTES          = 2;
  SYNC_FIELD_QSOS           = 3;
  SYNC_FIELD_ENABLE_REPLACE = 4;   // lParam unused
  // Written from uNet.CommitChangesInLocalLog, which RunSyncThread calls before
  // it opens the socket -- so this field is fed from a DIFFERENT unit on the
  // same worker thread.  It is why the old control id 112 looked unreferenced.
  SYNC_FIELD_SENT           = 5;

implementation
uses SysUtils,   { Format, StrPCopy -- replaced TF.Format/wsprintfA }
   uMainThread,  { RunOnMainThread -- the finished handoff, see HeadlessSyncFinished }
  MainUnit;

{ GetServerLogDlgProc STOOD HERE and went with dialog template 73 on
  2026-08-29 -- the last Win32 dialog in the program. Its window is
  ui\lcl\uServerLogForm now, and every arm of that case statement is a method
  on the form. Only the parts a CONSOLE-reachable unit may own stayed here: the
  download thread, the log replacement, and the progress seam below. }

var
   GServerLogRows: array of ContestExchange;

procedure ResetServerLogRows(const aCount: integer);
begin
   if aCount < 0 then
      begin
      SetLength(GServerLogRows, 0);
      Exit;
      end;
   SetLength(GServerLogRows, aCount);
end;

procedure SetServerLogRow(const aIndex: integer;
                          const aRecord: ContestExchange);
begin
   if (aIndex >= 0) and (aIndex < Length(GServerLogRows)) then
      begin
      GServerLogRows[aIndex] := aRecord;
      end;
end;

function TryGetServerLogRow(const aIndex: integer;
                            out aRecord: ContestExchange): boolean;
begin
   Result := (aIndex >= 0) and (aIndex < Length(GServerLogRows));
   if Result then
      begin
      aRecord := GServerLogRows[aIndex];
      end;
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
  not hold up the work it is reporting on.

  ASYNC IS SAFE HERE, and the direction matters: SYNC_FIELD_RECORDS also tells
  the grid how many rows exist, and the grid must never be told about a row the
  worker has not written yet. A report that arrives LATE understates the count,
  which is the safe side; only an early one would be a fault, and deferring
  cannot make a message early. *)
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

procedure HeadlessSyncFinished(aData: PtrInt);
begin
   if NewServerLogHandle <> INVALID_HANDLE_VALUE then
      begin
      FileClose(NewServerLogHandle);
      NewServerLogHandle := INVALID_HANDLE_VALUE;
      end;
   ReplaceLogByServerLog(True);
   logger.Info('Auto-sync: local log replaced with server log.');
   HeadlessSyncMode := False;
end;

procedure ReplaceLogByServerLog(Replace: boolean);
var
  counter                               : Cardinal;
begin
  for counter := 1 to 1000 do
     begin
     { '%.3d', not '%03d'. Delphi zero-pads by PRECISION; the width flag it
       would otherwise read pads with spaces, and a backup called
       'LOGBACKUP_  1.TRW' is not what the next run looks for. }

     StrPCopy(TempBuffer2, AnsiString(SysUtils.Format('%sLOGBACKUP_%.3d.TRW',
                                      [PAnsiChar(@TR4W_LOG_PATH_NAME), counter])));
     (* THE THIRD ARGUMENT WAS DOING THE WORK, so it is worth saying what
       replaced it.  CopyFileA's bFailIfExists=True is how this loop FINDS a
       free slot: it tries LOGBACKUP_001, _002, ... and stops at the first
       name that did not already exist.  An overwriting copy would succeed on
       the first try and silently destroy backup 001 every time.

       LazUtils' CopyFile expresses that as the ABSENCE of cffOverwriteFile:
       with empty flags it returns False when the destination exists
       (fileutil.inc:226).  The one behavioural difference is that it tests
       with FileExists and then copies, where CopyFileA decided inside one
       call -- so there is a window between the two.  It does not matter here:
       the single-instance mutex means no second TR4W is choosing the same
       slot, and both copies are into the operator's own log directory. *)
     if FileUtil.CopyFile(AnsiString(TR4W_LOG_FILENAME),
                          AnsiString(TempBuffer2), []) then
        begin
        StrPCopy(TempBuffer2, AnsiString(SysUtils.Format('%sRSTBACKUP_%.3d.RST',
                                         [PAnsiChar(@TR4W_LOG_PATH_NAME), counter])));
        (* False was bFailIfExists -- overwrite -- which is what
          cffOverwriteFile says.  Same for the SYN copy below. *)
        FileUtil.CopyFile(AnsiString(TR4W_RST_FILENAME),
                          AnsiString(TempBuffer2), [cffOverwriteFile]);
        Break;
        end;
     end;
  if Replace then
     begin
     FileUtil.CopyFile(AnsiString(TR4W_SYN_FILENAME),
                       AnsiString(TR4W_LOG_FILENAME), [cffOverwriteFile]);
     LoadinLog;
     end;
  SendStationStatus(sstQSOs);
end;

(* THE LOG DOWNLOAD, ON INDY -- and EXTRACTED, which is most of the value.

  This was inline in RunSyncThread: a raw WinSock connect through
  utils_net.GetConnection, a WSAEventSelect/WSAWaitForMultipleEvents pump, a
  recv loop, and two `goto`s. Pulling it out gives the network step one entry
  and one exit, so the caller tests a boolean instead of jumping, and every
  socket call in TR4W is now Indy's (NY4I, 2026-09-08: "Any remaining socket
  calls that are not using Indy ... should switch to Indy").

  THE PROTOCOL, which was never written down: connect to the server's port
  PLUS ONE, write ten bytes of password, then read until the peer stops. The
  first four bytes are the log size in NATIVE byte order, and the count it
  states EXCLUDES itself.

  TWO THINGS THAT LOOK LIKE TRANSLATION AND ARE NOT:

  1. ReadInt32(AConvert := False). Indy converts from NETWORK byte order by
     default; the old code read those four bytes with PInteger, which is
     native. On a little-endian machine the default would have turned a
     25,000-byte log into 3,347,644,416 and failed every size check.
  2. THE FOUR-BYTE HEADER IS NOW READ AS A HEADER. The old loop carried a
     FirstPacket flag and skipped four bytes of whatever the first recv
     happened to return -- which is correct only while that recv returns at
     least four bytes. TCP does not promise that. Reading it explicitly makes
     a short first segment a non-event instead of a corrupted log, and it
     deletes the flag and the offset arithmetic.

  ENDING THE TRANSFER IS UNCHANGED IN MEANING: two seconds with nothing
  arriving, or a close, finishes it -- which is what the 2000 ms
  WSAWaitForMultipleEvents timeout did. There is no length-prefixed framing to
  wait on beyond the size field, so silence is still the signal.

  NOT BENCH TESTED. It needs a running tr4wserver and a second station; see
  BENCH_QUEUE.md. *)
function FetchServerLog(out aTotalBytes, aLogSize: integer): boolean;
const
   CONNECT_TIMEOUT_MS = 5000;
   IDLE_TIMEOUT_MS    = 2000;   // as the old WSAWaitForMultipleEvents wait
   PASSWORD_BYTES     = 10;     // fixed by the server, not by the string type
var
   Client:    TIdTCPClient;
   Chunk:     TIdBytes;
   Available: integer;
begin
   Result      := False;
   aTotalBytes := 0;
   aLogSize    := 0;

   Client := TIdTCPClient.Create(nil);
   try
      (* AnsiString, not string(...).  Indy is built without UnicodeStrings
        here, so Host is an AnsiString; a cast to the generic string type
        widens and then narrows again -- a silent round trip the ratchet
        counts -- the same note logstuff carries about LazUtils' CopyFile. *)
      Client.Host           := AnsiString(ServerAddress);
      Client.Port           := ServerPort + 1;
      Client.ConnectTimeout := CONNECT_TIMEOUT_MS;
      Client.ReadTimeout    := IDLE_TIMEOUT_MS;

      try
         Client.Connect;
      except
         on E: Exception do
            begin
            (* REPORTED, not silent. The WinSock version returned False and
              the caller showed a generic warning, so a wrong address and a
              refused connection looked identical. *)
            logger.Error('[SyncLog] connect to %s:%d failed -- %s',
                         [Client.Host, Client.Port, E.Message]);
            Exit;
            end;
      end;

      try
         Client.IOHandler.Write(RawToBytes(ServerPassword[1], PASSWORD_BYTES));

         aLogSize := Client.IOHandler.ReadInt32(False);   // native order

         repeat
            try
               Client.IOHandler.CheckForDataOnSource(IDLE_TIMEOUT_MS);
            except
               on E: Exception do
                  begin
                  (* A close is how a COMPLETE transfer ends, so this is not
                    an error path -- the size check in the caller decides
                    whether what arrived is whole. *)
                  Break;
                  end;
            end;

            Available := Client.IOHandler.InputBuffer.Size;
            if Available = 0 then
               begin
               Break;   // idle for the timeout: the server has finished
               end;

            SetLength(Chunk, 0);
            Client.IOHandler.InputBuffer.ExtractToBytes(Chunk, Available);
            sWriteFile(NewServerLogHandle, Chunk[0], Length(Chunk));
            Inc(aTotalBytes, Length(Chunk));

            if not HeadlessSyncMode then
               begin
               ReportSyncProgress(SYNC_FIELD_BYTES, aTotalBytes);
               end;
         until False;

         Result := True;
      except
         on E: Exception do
            begin
            logger.Error('[SyncLog] transfer failed after %d byte(s) -- %s',
                         [aTotalBytes, E.Message]);
            end;
      end;
   finally
      Client.Disconnect;
      Client.Free;
   end;
end;

procedure RunSyncThread;
label
  e, 2;
var
  TotalBytes, TotalRecords, TotalQ      : integer;
  lpNumberOfBytesWritten                : LongInt;   { FileRead's result }
  TempRXData                            : ContestExchange;
  ServerLogFillIndex                    : integer;
  LogSize                               : integer;
begin

  CommitChangesInLocalLog;

  TotalRecords := 0;
  TotalQ := 0;

  if not FetchServerLog(TotalBytes, LogSize) then
     begin
     goto e;
     end;

  if TotalBytes > SizeOfTLogHeader then
     begin
     if (LogSize <> TotalBytes) or ((TotalBytes - SizeOfTLogHeader) mod SizeOf(ContestExchange) <> 0) then
        begin
        if HeadlessSyncMode then
           begin
           logger.Error('Auto-sync: failed to receive server log (size=%d, expected=%d)', [TotalBytes, LogSize])
           end
        else
           begin
           showwarning(TC_FAILEDTORECEIVESERVERLOG);
           end;
        goto e;
        end;
     if (not HeadlessSyncMode) and showresverlogcontent then
        begin
        (* SIZED ONCE, HERE. See the note on the row store: this is what makes
          the array safe to fill from this thread and read from the other. *)
        ResetServerLogRows(TotalBytes div SizeOf(ContestExchange));
        end;
     { FileSeek from the start -- what SetFilePointer(FILE_BEGIN) did. }
     FileSeek(NewServerLogHandle, Int64(SizeOfTLogHeader), fsFromBeginning);

     ServerLogFillIndex := 0;
     (* THE tSetWindowRedraw FREEZE/THAW PAIR IS GONE. It stopped a list view
       repainting itself once per inserted row. A virtual grid paints only what
       is on screen and is not told about rows at all, so there is nothing to
       freeze. *)
     2:
     (* FileRead RETURNS the count that ReadFile delivered through a var
       parameter, and -1 on failure. The variable is signed now so a
       failure stays negative instead of becoming a huge Cardinal; the
       test below is unchanged either way, since neither equals the
       record size. *)
     lpNumberOfBytesWritten := FileRead(NewServerLogHandle, TempRXData,
                                       SizeOf(ContestExchange));
     if lpNumberOfBytesWritten = SizeOf(ContestExchange) then
        begin
        inc(TotalRecords);
        if ((TempRXData.Band <> NoBand) and
          (TempRXData.Mode <> NoMode) and
          (not TempRXData.ceQSO_Deleted)) and
          (TempRXData.ceQSO_Deleted = False) then inc(TotalQ);

        if not HeadlessSyncMode then
           begin
           if TotalRecords mod 10 = 0 then
              begin
              ReportSyncProgress(SYNC_FIELD_RECORDS, TotalRecords);
              end;
           if showresverlogcontent then
              begin
              SetServerLogRow(ServerLogFillIndex, TempRXData);
              Inc(ServerLogFillIndex);
              end;
           end;
        goto 2;
        end;
     end;
  if not HeadlessSyncMode then
     begin
     ReportSyncProgress(SYNC_FIELD_RECORDS, TotalRecords);
     ReportSyncProgress(SYNC_FIELD_QSOS, TotalQ);
     if TotalQ > 0 then
        begin
        ReportSyncProgress(SYNC_FIELD_ENABLE_REPLACE, 0);
        end;
     end;
  e:
  LogSyncThreadID := 0;
  (* Issue #912: the replace runs on the UI thread, because LoadinLog touches
    controls and a control belongs to the thread that made it.

    RunOnMainThread, not SendMessage(tr4whandle, WM_USER_...). The message
    needed an id, the main window's HANDLE, an entry in uMainForm's list of
    messages TR4W claims, and an arm in the window procedure -- none of which
    is about the work. It is the same move the other six background results
    made.

    QUEUED RATHER THAN BLOCKING, and that is safe here rather than merely
    convenient: this is the last statement in the branch, the branch is the
    last in the routine, and the handler takes nothing from this thread. *)
  if HeadlessSyncMode then
     begin
     if TotalQ > 0 then
        begin
        logger.Info('Auto-sync: download complete (%d records, %d QSOs).  Marshalling replace to UI thread.',
                    [TotalRecords, TotalQ]);
        RunOnMainThread(@HeadlessSyncFinished, 0);
        end
     else
        begin
        logger.Warn('Auto-sync: download produced %d records and %d QSOs - skipping replace.',
                    [TotalRecords, TotalQ]);
        if NewServerLogHandle <> INVALID_HANDLE_VALUE then
           begin
           FileClose(NewServerLogHandle);
           NewServerLogHandle := INVALID_HANDLE_VALUE;
           end;
        HeadlessSyncMode := False;
        end;
     end;
end;

end.

