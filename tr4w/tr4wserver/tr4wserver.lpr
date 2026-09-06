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

{ Declared ahead of ServerStartUp, which calls it on a failed start. }
procedure ServerShutDown; forward;

(* START-UP. Was the WM_INITDIALOG arm, and it was never really a window
  message: it reads the ini, opens the server log, scans it for serial numbers
  and starts listening. Called once, by name, after the form exists. *)
procedure ServerStartUp;
var
  BytesReceived: integer;
begin
//        SendMessage(hwnddlg, WM_SETICON, ICON_SMALL, LoadIcon(0, IDI_APPLICATION));
        SetServerVersion(FullServerVersion);

        ApplicationHandle := frmServer.Handle;
        InitServerLogger;
        PortNumber := GetPrivateProfileInt(_TR4WSERVER, 'PORT', 1061, _TR4WSERVERINIFILE);
        SetServerPort(PortNumber);
        sAllowTimeSynchronizing := GetPrivateProfileInt(_TR4WSERVER, 'ALLOW TIME SYNCHRONIZING', 1, _TR4WSERVERINIFILE) = 1;
        SerialNumberLockoutEnable := GetPrivateProfileInt(_TR4WSERVER, 'SERIAL NUMBER LOCKOUT', 0, _TR4WSERVERINIFILE) = 1;
        SetSerialLockout(SerialNumberLockoutEnable);

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

        (* NO WSAStartup, NO MSWSOCK, NO SEPARATE SYNC LISTENER.

          Indy initialises WinSock itself; TransmitFile is gone with the
          LoadLibrary that fetched it; and both listeners come up together
          inside RunServer -- see uServerNet.StartServerNet. *)

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
              begin ServerShutDown; Exit; end;
            end;
            if Windows.GetFileSize(ServerLogHandle, nil) = 0 then
              WriteFile(ServerLogHandle, LogHeader, SizeOfTLogHeader, BytesWritten, nil);

            DisplayServerLogSize;
            CloseServerLog;
          end
          else
          begin
            ServerMessageBox('Failed to open/create serverlog.trw', MB_OK or MB_ICONWARNING or MB_TOPMOST);
            begin ServerShutDown; Exit; end;
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

(* SHUTDOWN. Was the WM_CLOSE arm. StopServer takes the listeners down; there
  is no FreeLibrary(MSWSOCK_DLL) and no WSACleanup because Indy owns the
  sockets now. *)
procedure ServerShutDown;
begin
  StopServer;
end;


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
   ServerShutDown;
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

  ServerStopQuery      := @ConfirmStop;
  ServerStopRequested  := @RequestStop;
  ServerStartRequested := @RequestStart;

  SetServerVersion(FullServerVersion);

  { Read the ini, open the log, start listening -- everything the dialog did
    before its window appeared, and no longer wearing a message id. }
  ServerStartUp;

  Application.Run;

end.

