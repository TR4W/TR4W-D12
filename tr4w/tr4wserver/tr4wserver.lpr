program tr4wserver;

{$DEFINE LINUX}

{$IMPORTEDDATA OFF}
uses
  (* Interfaces FIRST, and it must be: it is what links the widget set. Without
    it the program compiles and fails at the LINK with a page of
    "Undefined symbol: WSRegisterMenuItem" -- the LCL's widgetset registration
    hooks, which only the interfaces unit supplies. *)
  Interfaces,
  Forms,
  Classes,        // AllocateHWnd -- the socket sink; see the header
  uServerForm,    // the window, at last a designed one
  Windows,
  Messages,
  SysUtils,
  tr4wserverUnit in '..\src\tr4wserverUnit.pas',
  uCRC32 in '..\src\uCRC32.pas',
  WinSock2,     // Winapi.WinSock2 from the RTL -- the vendored D7 WinSock2.pas is retired
  Log4D,        // the dialog proc logs through tr4wserverUnit's logger
  VC in '..\src\vc.pas';

(* THE DIALOG RESOURCE IS GONE, AND WITH IT A WHOLE CLASS OF FAILURE.

  There used to be two resources here, and a long note about why their file
  NAMES had to differ: FPC resolves a resource directive by BASENAME and treats
  the directory as a hint, so when the Lazarus project resource arrived also
  called tr4wserver.res it shadowed the dialog one. The program then linked,
  started, found no DIALOG 100, fell out of end. and exited 0 with no window and
  nothing in any log. That was live for weeks, and invisible because the server
  had stopped compiling in the meantime.

  The window is a designed form now, streamed by the LCL from uServerForm, so
  there is no template to shadow and a missing form is a loud run-time error
  instead of a silent exit.

  res\tr4wserver_dialog.res is left on disk rather than deleted: it is the only
  record of what the original window looked like, and the conversion wants
  checking against it on the bench before it goes. *)
{$R *.res}                       // the Lazarus project resource -- icons

function TR4wServerDlgProc(hwnddlg: HWND; uMsg: UINT; wp: wParam; lp: lParam): BOOL; stdcall;
label
  1, 2, CheckBuffer, Exit1, Exit2;
var
  BytesReceived                         : integer;
  counter                               : Cardinal;
  client_socket                         : Cardinal;
//  IntPtr                                : ^integer;
begin
  Result := False;
  case uMsg of
    WM_INITDIALOG:
      begin
//        SendMessage(hwnddlg, WM_SETICON, ICON_SMALL, LoadIcon(0, IDI_APPLICATION));
        Windows.SetDlgItemText(hwnddlg, 117, FullServerVersion);

        ApplicationHandle := hwnddlg;
        InitServerLogger;
        PortNumber := GetPrivateProfileInt(_TR4WSERVER, 'PORT', 1061, _TR4WSERVERINIFILE);
        Windows.SetDlgItemInt(hwnddlg, 102, PortNumber, False);
        sAllowTimeSynchronizing := GetPrivateProfileInt(_TR4WSERVER, 'ALLOW TIME SYNCHRONIZING', 1, _TR4WSERVERINIFILE) = 1;
        SerialNumberLockoutEnable := GetPrivateProfileInt(_TR4WSERVER, 'SERIAL NUMBER LOCKOUT', 0, _TR4WSERVERINIFILE) = 1;
        Windows.EnableWindow(GetDlgItem(ApplicationHandle, 118), SerialNumberLockoutEnable);

//        tGetLogTimeout := GetPrivateProfileInt(_TR4WSERVER, 'GET LOG TIMEOUT', 50, _TR4WSERVERINIFILE);
{$IF SERVERDEBUG}
        ServerDebugMode := GetPrivateProfileInt(_TR4WSERVER, 'DEBUG', 0, _TR4WSERVERINIFILE) = 1;
{$IFEND}
        // MUST be the ...A variant.  tr4wServerPassword is array[0..10] of AnsiChar
        // and is compared byte-for-byte against what the client sends, but under D12
        // the generic name binds to GetPrivateProfileStringW, which filled the buffer
        // with UTF-16 ('T'#0'R'#0'4'#0...).  The compare then matched byte 0 and failed
        // on the #0 at byte 1, so EVERY client was rejected -- including with no INI
        // file present, because the DEFAULT value goes through the same call.
        GetPrivateProfileStringA(_TR4WSERVER, 'SERVER PASSWORD', _TR4WSERVER, @tr4wServerPassword, 11, _TR4WSERVERINIFILE);

        //if not Load_MSWSOCK then goto Exit2;
        MSWSOCKLoaded := Load_MSWSOCK;
        WSAStartup($0202, net_mywsadata);
        if not RunSyncListener then goto Exit1;

        BytesReceived := Windows.GetModuleFileName(0, @ServerLogFileName, SizeOf(ServerLogFileName));
        ServerLogFileName[BytesReceived - 14] := #0;
        Windows.lstrcat(@ServerLogFileName, 'SERVERLOG.TRW');
{$IF SERVERDEBUG}
        BytesReceived := Windows.GetModuleFileName(0, @ServerDebugFileName, SizeOf(ServerDebugFileName));
        ServerDebugFileName[BytesReceived - 14] := #0;
        Windows.lstrcat(@ServerDebugFileName, 'DEBUG.TXT');
{$IFEND}
{
        BytesReceived := Windows.GetModuleFileName(0, @MultsFrequenciesFileName, SizeOf(MultsFrequenciesFileName));
        MultsFrequenciesFileName[BytesReceived - 14] := #0;
        Windows.lstrcat(@MultsFrequenciesFileName, 'MULTS_FREQ.BIN');
        LoadinMultsFrequencies;
}
        if OpenServerLog(OPEN_ALWAYS) then
          if ServerLogHandle <> INVALID_HANDLE_VALUE then
          begin
            if (Windows.GetFileSize(ServerLogHandle, nil) mod SizeOf(ContestExchange)) <> 0 then
            begin
              logger.Error('serverlog.trw size mismatch: file size ' +
                IntToStr(Windows.GetFileSize(ServerLogHandle, nil)) +
                ' is not a multiple of record size ' + IntToStr(SizeOf(ContestExchange)));
              ServerMessageBox(
                'serverlog.trw cannot be opened: the file size is not a multiple of the ' +
                'current log record size.' + #13#10 + #13#10 +
                'This typically occurs after a server upgrade that changed the log format.' + #13#10 +
                'Please delete or rename serverlog.trw and restart the server.' + #13#10 +
                'A new empty log will be created automatically.',
                MB_OK or MB_ICONWARNING or MB_TOPMOST);
              goto Exit1;
            end;
            if Windows.GetFileSize(ServerLogHandle, nil) = 0 then
              WriteFile(ServerLogHandle, LogHeader, SizeOfTLogHeader, BytesWritten, nil);

            DisplayServerLogSize;
            CloseServerLog;
          end
          else
          begin
            ServerMessageBox('Failed to open/create serverlog.trw', MB_OK or MB_ICONWARNING or MB_TOPMOST);
            goto Exit1;
          end;
        //        SortServerLog;
        ScanLogForSerialsNumbers;

//        SetPointerEvent := CreateEvent(nil, False, False, nil);
        RunServerThread;

        tr4w_osverinfo.dwOSVersionInfoSize := SizeOf(OSVERSIONINFO);
        Windows.GetVersionEx(tr4w_osverinfo);
        ServerOS := tr4w_osverinfo.dwPlatformId;
{
        Windows.SendDlgItemMessage(ApplicationHandle, 109, WM_SETFONT,
          integer(Windows.CreateFont(14, 0, 0, 0, FW_NORMAL, 0, 0, 0, ANSI_CHARSET, OUT_DEFAULT_PRECIS, Clip_Default_Precis, Default_Quality, 34, 'Courier New')),
          0);
}
      end;
    WM_COMMAND:
      begin
        if LoWord(wp) = 104 then goto Exit1;
      end;

    WM_CLOSE:
      begin
        Exit1:
        if nclients <> 0 then
          if ServerMessageBox('Do you really want to disconnect servers`s clients?', MB_YESNO or MB_ICONQUESTION or MB_TOPMOST or MB_DEFBUTTON2) = IDno then Exit;
        StopServer;
//        SaveMultsFrequencies;
        FreeLibrary(MSWSOCK_DLL);
        WSACleanup;
        Exit2:
        PostQuitMessage(0);
      end;

    WM_SOCK_NET_RX:
      begin
        BytesReceived := sRecv(wp, ServerBuffer, SizeOf(ServerBuffer));
        if BytesReceived <= 0 then
        begin
          DeleteSocketFromArray(wp);
          DisplayClients;
          Exit;
        end;

        Bufindex := 0;
        counter := 0;
        //            if br mod 5 <> 0 then MessageBox(ApplicationHandle, PChar(IntToStr(br)), 'recv', MB_YESNO or MB_ICONQUESTION or MB_TOPMOST or MB_DEFBUTTON2);

        CheckBuffer:

        case PWORD(@ServerBuffer[Bufindex])^ of

          NET_MESSAGESTATE_ID:
            begin
              SendMessageToClients(wp, SizeOf(TMessageState), True, dmMessage);
              Bufindex := Bufindex + SizeOf(TMessageState);
            end;

          NET_STATIONSTATUS_ID:
            begin
              SendMessageToClients(wp, SizeOf(TStationState), True, dmStationStatus);
              Bufindex := Bufindex + SizeOf(TStationState);
              if Bufindex = BytesReceived then goto 1;
            end;

          NET_NETWORKDXSPOT_ID:
            begin
              SendMessageToClients(wp, SizeOf(TNetDXSpot), False, dmDXSpot);
              Bufindex := Bufindex + SizeOf(TNetDXSpot);
            end;

          NET_TIMESYN_ID:
            begin
              if sAllowTimeSynchronizing then SendMessageToClients(wp, SizeOf(TNetTimeSync), False, dmTimeSyn);
              Bufindex := Bufindex + SizeOf(TNetTimeSync);
            end;

          NET_PARAMETER_ID:
            begin
              SendMessageToClients(wp, SizeOf(TParameterToNetwork), False, dmParam);
              Bufindex := Bufindex + SizeOf(TParameterToNetwork);
            end;

          NET_INTERCOMMESSAGE_ID:
            begin
              SendMessageToClients(wp, SizeOf(TIntercomMessage), True, dmIntercom);
              Bufindex := Bufindex + SizeOf(TIntercomMessage);
            end;

          NET_EDITEDQSO_ID:
            begin
              SendMessageToClients(wp, SizeOf(TNetQSOInformation), False, dmEditQSO);
              EditedQSOPtr := @ServerBuffer[Bufindex];
              logger.Debug('NET_EDITEDQSO: call=' + string(EditedQSOPtr^.qiInformation.Callsign) +
                ' band=' + IntToStr(Ord(EditedQSOPtr^.qiInformation.Band)) +
                ' mode=' + IntToStr(Ord(EditedQSOPtr^.qiInformation.Mode)) +
                ' exch=' + string(EditedQSOPtr^.qiInformation.ExchString));
              UpdateQSOInServerlog(EditedQSOPtr^.qiInformation);
              SendConfirmMessage(wp);

              Bufindex := Bufindex + SizeOf(TNetQSOInformation);
            end;

          NET_OFFLINEQSO_ID:
            begin
              ServerNewQSOPtr := @ServerBuffer[Bufindex];
              if OpenServerLog(OPEN_EXISTING) then
              begin
                SetFilePointer(ServerLogHandle, 0, nil, FILE_END);
                WriteFile(ServerLogHandle, ServerNewQSOPtr.qiInformation, SizeOf(ContestExchange), BytesWritten, nil);
                FlushFileBuffers(ServerLogHandle);
                DisplayServerLogSize;
                CloseServerLog;
                SendConfirmMessage(wp);
              end;
              Bufindex := Bufindex + SizeOf(TNetQSOInformation);
            end;

          NET_QSOINFO_ID:
            begin
              ServerNewQSOPtr := @ServerBuffer[Bufindex];
              logger.Debug('NET_QSOINFO: call=' + string(ServerNewQSOPtr^.qiInformation.Callsign) +
                ' band=' + IntToStr(Ord(ServerNewQSOPtr^.qiInformation.Band)) +
                ' mode=' + IntToStr(Ord(ServerNewQSOPtr^.qiInformation.Mode)) +
                ' exch=' + string(ServerNewQSOPtr^.qiInformation.ExchString));
              SendMessageToClients(wp, SizeOf(TNetQSOInformation), False, dmQSOInfo);
              if OpenServerLog(OPEN_EXISTING) then
              begin
                SetFilePointer(ServerLogHandle, 0, nil, FILE_END);
                WriteFile(ServerLogHandle, ServerNewQSOPtr.qiInformation, SizeOf(ContestExchange), BytesWritten, nil);
                FlushFileBuffers(ServerLogHandle);
                DisplayServerLogSize;
                CloseServerLog;
              end
              else
                AddContestExchangeToBuffer(ServerNewQSOPtr.qiInformation);
              Bufindex := Bufindex + SizeOf(TNetQSOInformation);
            end;

          NET_CLIENTSTATUS_ID:
            begin
              SetStatus(TClientStatusPtr(@ServerBuffer[Bufindex])^, wp);
              inc(Bufindex, SizeOf(TClientStatus));
            end;

          NET_SPOTVIANETWORK_ID:
            begin
              SendSpotViaNet(TSendSpotViaNetworkPtr(@ServerBuffer[Bufindex])^, wp);
              inc(Bufindex, SizeOf(TSendSpotViaNetwork));
            end;

          NET_COMPUTERID_ID:
            begin
              SetComputerID(TComputerNetIDPtr(@ServerBuffer[Bufindex])^.ciComputerID, wp);
              Bufindex := Bufindex + SizeOf(TComputerNetID);
            end;
{
          NET_MULTSFREQUENCIES_ID:
            begin
              Windows.CopyMemory(@ServerMF, @ServerBuffer[Bufindex + 2], SizeOf(MultsFrequencies));
              SendMFToClients;
              Bufindex := Bufindex + SizeOf(NetMultsFrequencies);
            end;
}
          NET_SERVERMESSAGE_ID:
            begin
              ServerMessagePtr := @ServerBuffer[Bufindex];
              case ServerMessagePtr.smMessage of
{
                SM_CLEARSERVERLOG_MESSAGE:
                  begin
                    if ClearServerLog then SendMessageToClients(wp, SizeOf(TServerMessage), True, dmClearLogs);
                  end;
}

                SM_SERIAL_NUMBER_CHANGED:
                  begin
                    if SerialNumberLockoutEnable then
                      UpdateSerialNumbersStatus(wp, TSerialNumberType(ServerMessagePtr.smParam));
                  end;

                SM_CLEARALLLOGS_MESSAGE:
                  begin
                    if ClearServerLog then SendMessageToClients(wp, SizeOf(TServerMessage), True, dmClearLogs);
                  end;

                SM_CLEAR_DUPESHEET_MESSAGE:
                  begin
                    if tUpdateServerLog(actSetClearDupesheetBit) then SendMessageToClients(wp, SizeOf(TServerMessage), True, dmClearLogs);
                  end;

                SM_CLEAR_MULTSHEET_MESSAGE:
                  begin
                    if tUpdateServerLog(actClearMults) then SendMessageToClients(wp, SizeOf(TServerMessage), True, dmClearLogs);
                  end;
{
                SM_SORTLOG_MESSAGE:
                  begin
                    if OpenServerLog(OPEN_EXISTING) then
                    begin
                      SortServerLog;
                      CloseServerLog;
                    end;
                  end;
}
                SM_SERVERLOG_CHANGED_MESSAGE:
                  begin
                    SendMessageToClients(wp, SizeOf(TServerMessage), False, dmClearLogs);
                  end;

                SM_GETSTATUS_MESSAGE:
                  SendMessageToClients(wp, SizeOf(TServerMessage), False, dmClearLogs);

              end;
              Bufindex := Bufindex + SizeOf(TServerMessage);

            end;

        end;

        if Bufindex = BytesReceived then goto 1;

        if PDWORD(@ServerBuffer[Bufindex])^ = NET_LOGINFO_MESSAGE then
        begin
          SendLogFileInformation(wp);
          Bufindex := Bufindex + SizeOf(NET_LOGINFO_MESSAGE);
          if Bufindex = BytesReceived then goto 1;
        end;

        inc(counter);

        if counter < 25 then goto CheckBuffer;
        1:
        DisplayRCVDBytes;

      end;
    WM_SOCK_NET_SYNLISTNER:
      begin

        client_socket := WinSock2.accept(ListenerSocket, PSockAddr(@client_addr), @addrlen);
        if client_socket <> INVALID_SOCKET then
        begin

          Sleep(50);
          BytesReceived := sRecv(client_socket, ServerBuffer, 50);
            //������!!!!!
{
            if OpenServerLog(OPEN_EXISTING) then
              begin
                SetFilePointer(ServerLogHandle, 0, nil, FILE_BEGIN);
                WriteFile(ServerLogHandle, ServerBuffer, br, BytesWritten, nil);
                CloseServerLog;
              end;
}
          if not CorrectPassword(client_socket, BytesReceived) then
          begin
            closesocket(client_socket);
            Exit;
          end;

          if OpenServerLog(OPEN_EXISTING) then
          begin
            SetFilePointer(ServerLogHandle, 0, nil, FILE_BEGIN);
                //                ServerLogSize := Windows.GetFileSize(ServerLogHandle, nil);
//            Windows.GetFileInformationByHandle(ServerLogHandle, ServerLogFileInformation.liInformation);
            ServerLogFileInformation.liServerLogSize := Windows.GetFileSize(ServerLogHandle, nil);
            Server_TRANSMIT_FILE_BUFFERS.Head := @ServerLogFileInformation.liServerLogSize {ServerLogSize};
            Server_TRANSMIT_FILE_BUFFERS.HeadLength := SizeOf(ServerLogFileInformation.liServerLogSize);
            Server_TRANSMIT_FILE_BUFFERS.Tail := nil;
            Server_TRANSMIT_FILE_BUFFERS.TailLength := 0;
            //if ServerOS = VER_PLATFORM_WIN32_NT then
            if MSWSOCKLoaded then
            begin

              if TransmitFile(client_socket, ServerLogHandle, 0, 0, nil, @Server_TRANSMIT_FILE_BUFFERS, TF_DISCONNECT) then
              begin
                BytesSEND := BytesSEND + Windows.GetFileSize(ServerLogHandle, nil);
                DisplaySENDBytes;
              end;
              CloseServerLog;
              closesocket(client_socket);
            end
            else
              ServerThread := CreateThread(nil, 0, @TransmitServerLog, Pointer(client_socket), 0, ServerThreadID);
                //                  TransmitServerLog(client_socket);

          end;

        end;
      end;

    WM_SOCK_NET_ACCEPT:
      begin
//        AcceptEx(ListenerSocket, client_socket, ServerBuffer, 10, 10, 10, lpdwBytesReceived, nil);
        client_socket := WinSock2.accept(ServerSocket, PSockAddr(@client_addr), @addrlen);
        if client_socket <> INVALID_SOCKET then
        begin
          Sleep(200);

          BytesReceived := sRecv(client_socket, ServerBuffer, 10);
          if BytesReceived = -1 then goto 2;
          if not CorrectPassword(client_socket, BytesReceived) then
          begin
            sSend(client_socket, ServerBuffer, BytesReceived, dmAccept);
            closesocket(client_socket);
            Exit;
          end;

          BytesReceived := sSend(client_socket, SENDTR4W, SizeOf(SENDTR4W), dmTR4W);
          if BytesReceived <> 4 then
          begin
            2:
            closesocket(client_socket);
            Exit;
          end;

          WinSock2.setsockopt(client_socket, IPPROTO_TCP, TCP_NODELAY, @ENABLE_TCP_NODELAY, SizeOf(integer));
          myhostent := WinSock2.gethostbyaddr(@client_addr.sin_addr.S_addr, 4, AF_INET);

          if myhostent = nil then
            AddSocketToArray(client_socket, WinSock2.iNet_ntoa(client_addr.sin_addr), nil)
          else
            AddSocketToArray(client_socket, WinSock2.iNet_ntoa(client_addr.sin_addr), myhostent.h_Name);

          DisplayClients;
          { ServerSocketSink, not hwnddlg: the socket sink is the window that
            answers WM_SOCK_*, and this arm may be entered from either. }
          WinSock2.WSAAsyncSelect(client_socket, ServerSocketSink, WM_SOCK_NET_RX, FD_READ or FD_CLOSE or FD_CONNECT);
//          SendMFToClients;
          SendLogFileInformation(client_socket);
          SerialNumbersChanged;
        end;
      end;
  end;
end;

(* THE SOCKET SINK.

  WSAAsyncSelect delivers FD_ACCEPT, FD_READ and FD_CLOSE as WINDOW MESSAGES,
  so the transport needs an HWND. This is the smallest one that will do: a
  message-only window from AllocateHWnd whose only job is to hand those three
  messages to the same dialog procedure that has always answered them.

  NOT THE FORM'S HANDLE. Routing socket events through the form would make the
  form part of the transport -- the entanglement this change exists to undo --
  and uServerForm's header says it does not know what a socket is.

  THIS WHOLE CLASS IS WHAT THE INDY CHANGE DELETES. One window, one method. *)
type
   TSocketSink = class
      procedure WndProc(var aMsg: TMessage);
   end;

procedure TSocketSink.WndProc(var aMsg: TMessage);
begin
   case aMsg.Msg of
     WM_SOCK_NET_RX,
     WM_SOCK_NET_ACCEPT,
     WM_SOCK_NET_SYNLISTNER:
        begin
        TR4wServerDlgProc(ServerSocketSink, aMsg.Msg, aMsg.WParam, aMsg.LParam);
        aMsg.Result := 0;
        end;
   else
     aMsg.Result := DefWindowProc(ServerSocketSink, aMsg.Msg,
                                  aMsg.WParam, aMsg.LParam);
   end;
end;

var
   GSink: TSocketSink = nil;

(* The operator pressed Stop, or closed the window.  The question is the
  dialog's, word for word -- only the engine knows whether anyone is
  connected. *)
function ConfirmStop: boolean;
begin
   Result := True;
   if nclients <> 0 then
      begin
      Result := ServerMessageBox(
         'Do you really want to disconnect servers`s clients?',
         MB_YESNO or MB_ICONQUESTION or MB_TOPMOST or MB_DEFBUTTON2) <> IDNO;
      end;
end;

procedure RequestStop;
begin
   { The WM_CLOSE arm, reached by a call rather than by a message: StopServer,
     FreeLibrary(MSWSOCK_DLL), WSACleanup.  Its PostQuitMessage is harmless
     here -- Application.Terminate is what actually ends the loop. }
   TR4wServerDlgProc(ServerSocketSink, WM_CLOSE, 0, 0);
end;

procedure RequestStart;
begin
   { Start was disabled from the moment the server came up, so this is only
     reachable if a future change re-enables it.  RunServer is idempotent
     enough to say so rather than to be silently ignored. }
   logger.Warn('Start pressed while the server is already listening -- ignored');
end;

begin
  if CreateMutex(nil, False, _TR4WSERVER) = 0 then Exit;
  if GetLastError = ERROR_ALREADY_EXISTS then Exit;

  Application.Initialize;
  Application.CreateForm(TfrmServer, frmServer);

  { The sink BEFORE start-up: RunServer's WSAAsyncSelect names it. }
  GSink := TSocketSink.Create;
  ServerSocketSink := Classes.AllocateHWnd(GSink.WndProc);

  ServerStopQuery      := @ConfirmStop;
  ServerStopRequested  := @RequestStop;
  ServerStartRequested := @RequestStart;

  SetServerVersion(FullServerVersion);

  { WM_INITDIALOG, by name.  It reads the ini, opens the log, binds and
    listens -- everything the dialog did before its window appeared. The FORM's
    handle, because ApplicationHandle is what ServerMessageBox parents to. }
  TR4wServerDlgProc(frmServer.Handle, WM_INITDIALOG, 0, 0);

  Application.Run;

  if ServerSocketSink <> 0 then
     begin
     Classes.DeallocateHWnd(ServerSocketSink);
     ServerSocketSink := 0;
     end;
  GSink.Free;
end.

