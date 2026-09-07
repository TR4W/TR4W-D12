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
  utils_net,
  WinSock2,
  utils_file,
  Windows,
  Messages,
  LogStuff,
  LogWind,
  uNet,
  LogDupe,
  Tree
  ,
  uTR4WStrings;
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

var

  NewServerLogHandle                    : THandle;
  AmountQSOsFromServer                  : Cardinal;
  { The form's handle while the sync window is open, 0 otherwise.  Set last in
    HandleShow and cleared FIRST in HandleClose. }
  ServerLogFormWnd                      : HWND;
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
  WM_USER_HEADLESS_SYNC_REPLACE = WM_USER + 200;

  // Progress, worker -> sync window.  wParam is one of SYNC_FIELD_*, lParam the
  // value.  Same reasoning as above, generalised: see ReportSyncProgress.
  WM_USER_SYNC_PROGRESS         = WM_USER + 201;

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

procedure ReportSyncProgress(aField: integer; aValue: integer);
begin
   if ServerLogFormWnd = 0 then
      begin
      Exit;
      end;
   Windows.SendMessage(ServerLogFormWnd, WM_USER_SYNC_PROGRESS, aField, aValue);
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
     if Windows.CopyFileA(TR4W_LOG_FILENAME, TempBuffer2, True) = True then
        begin
        StrPCopy(TempBuffer2, AnsiString(SysUtils.Format('%sRSTBACKUP_%.3d.RST',
                                         [PAnsiChar(@TR4W_LOG_PATH_NAME), counter])));
        Windows.CopyFileA(TR4W_RST_FILENAME, TempBuffer2, False);
        Break;
        end;
     end;
  if Replace then
     begin
     Windows.CopyFileA(TR4W_SYN_FILENAME, TR4W_LOG_FILENAME, False);
     LoadinLog;
     end;
  SendStationStatus(sstQSOs);
end;

procedure RunSyncThread;
label
  e, 1, 2;
var
  i                                     : integer;
  TotalBytes, TotalRecords, TotalQ      : integer;
  lpNumberOfBytesWritten                : Cardinal;
  TempRXData                            : ContestExchange;
  ServerLogFillIndex                    : integer;
  tGetNetLogEvent                       : THandle;
  FirstPacket                           : boolean;
  Offset                                : integer;
  LogSize                               : integer;
begin

  CommitChangesInLocalLog;

  FirstPacket := True;

  if not GetConnection(LogSyncSocket, @ServerAddress[1], ServerPort + 1, SOCK_STREAM) then
     begin
     goto e;
     end;
{
  LogSyncSocket :=GetSocket;// socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
  tr4w_saddr.sin_addr.S_addr := inet_addr(tgethostbyname(@ServerAddress[1]));
  tr4w_saddr.sin_port := htons(ServerPort + 1);
  if LogSyncSocket = INVALID_SOCKET then goto e;
  if tConnect(LogSyncSocket, @tr4w_saddr) <> 0 then goto e;
}
  WinSock2.Send(LogSyncSocket, ServerPassword[1], 10, 0);
  //  Sleep(100);
  TotalBytes := 0;
  TotalRecords := 0;
  TotalQ := 0;
  tGetNetLogEvent := WSACreateEvent;
  WinSock2.WSAEventSelect(LogSyncSocket, tGetNetLogEvent, FD_READ or FD_CLOSE);

  1:
  i := WSAWaitForMultipleEvents(1, @tGetNetLogEvent, False, 2000, True);
  if i = 0 then
     begin

     i := recv(LogSyncSocket, SyncNetBuffer, SizeOf(SyncNetBuffer), 0);
     if i > 0 then
        begin
        Offset := 0;
        if FirstPacket then
           begin
           Offset := SizeOf(Cardinal);
           FirstPacket := False;
           LogSize := PInteger(@SyncNetBuffer)^;
           end;
        sWriteFile(NewServerLogHandle, SyncNetBuffer[Offset], i - Offset);
        TotalBytes := TotalBytes + i - Offset;
        if not HeadlessSyncMode then
           begin
           ReportSyncProgress(SYNC_FIELD_BYTES, TotalBytes);
           end;
        end;
     if i <> 0 then
        begin
        goto 1;
        end;
     end;
  WSACloseEvent(tGetNetLogEvent);
  closesocket(LogSyncSocket);

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
     Windows.SetFilePointer(NewServerLogHandle, SizeOfTLogHeader, nil, FILE_BEGIN);

     ServerLogFillIndex := 0;
     (* THE tSetWindowRedraw FREEZE/THAW PAIR IS GONE. It stopped a list view
       repainting itself once per inserted row. A virtual grid paints only what
       is on screen and is not told about rows at all, so there is nothing to
       freeze. *)
     2:
     Windows.ReadFile(NewServerLogHandle, TempRXData, SizeOf(ContestExchange), lpNumberOfBytesWritten, nil);
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
  // Issue #912: headless mode drives the replace from the UI thread via
  // SendMessage.  LoadinLog (called by ReplaceLogByServerLog) accesses
  // Win32 ListView controls, which require their creating thread.
  // SendMessage blocks here until the UI handler returns, which is fine -
  // the worker thread is about to exit anyway.
  if HeadlessSyncMode then
     begin
     if TotalQ > 0 then
        begin
        logger.Info('Auto-sync: download complete (%d records, %d QSOs).  Marshalling replace to UI thread.',
                    [TotalRecords, TotalQ]);
        SendMessage(tr4whandle, WM_USER_HEADLESS_SYNC_REPLACE, 0, 0);
        end
     else
        begin
        logger.Warn('Auto-sync: download produced %d records and %d QSOs - skipping replace.',
                    [TotalRecords, TotalQ]);
        if NewServerLogHandle <> INVALID_HANDLE_VALUE then
           begin
           CloseHandle(NewServerLogHandle);
           NewServerLogHandle := INVALID_HANDLE_VALUE;
           end;
        HeadlessSyncMode := False;
        end;
     end;
end;

end.

