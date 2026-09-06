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
  Classes,        // TFileStream -- the single-instance lock
  IniFiles,       // TIniFile -- the settings, was GetPrivateProfile*
  Dialogs,        // ShowMessage -- was MessageBox
  uAnsiStr,       // StrPLCopy over PAnsiChar; SysUtils' is PWideChar
  uAppPaths,      // where written files go, per platform
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
var
   GLock: TFileStream = nil;

procedure ServerShutDown; forward;

(* START-UP. Was the WM_INITDIALOG arm, and it was never really a window
  message: it reads the ini, opens the server log, scans it for serial numbers
  and starts listening. Called once, by name, after the form exists. *)
procedure ServerStartUp;
var
  BytesReceived: integer;
  ini: TIniFile;
begin
//        SendMessage(hwnddlg, WM_SETICON, ICON_SMALL, LoadIcon(0, IDI_APPLICATION));
        SetServerVersion(FullServerVersion);

        ApplicationHandle := frmServer.Handle;
        InitServerLogger;
        (* THE SETTINGS, THROUGH TIniFile.

          Was GetPrivateProfileInt and GetPrivateProfileStringA -- Win32 API on
          a .ini file. TIniFile is the RTL's, reads the same file format, and
          works wherever FPC does.

          THE ...A SPELLING MATTERED AND THE REASON IS WORTH KEEPING: the
          password is compared BYTE FOR BYTE against what the client sends, and
          under a Unicode binding the generic name bound to
          GetPrivateProfileStringW, which filled an AnsiChar buffer with UTF-16
          ('T'#0'R'#0'4'#0...). The compare matched byte 0 and failed on the #0
          at byte 1, so EVERY CLIENT WAS REJECTED -- including with no ini file
          at all, because the default goes through the same call. TIniFile
          returns a string and the conversion is explicit, so that whole class
          of bug is gone rather than avoided. *)
        (* NAMED EXPLICITLY. _TR4WSERVERINIFILE is the bare 'TR4WSERVER.INI',
          which resolves against the working directory -- right on Windows and
          nowhere sensible elsewhere. DataFilePath, not SettingsFilePath: this
          file has always sat beside the program, not in a settings\ folder,
          and moving it would lose every operator's configuration. *)
        ini := TIniFile.Create(DataFilePath(String(PAnsiChar(_TR4WSERVERINIFILE))));
        try
           PortNumber := ini.ReadInteger(_TR4WSERVER, 'PORT', 1061);
           SetServerPort(PortNumber);

           (* WHICH INTERFACE TO BIND TO. Absent or empty means all of them,
             which is what this server has always done. See
             tr4wserverUnit.ServerBindAddress. *)
           ServerBindAddress := Trim(ini.ReadString(_TR4WSERVER,
                                                    'BIND ADDRESS', ''));
           sAllowTimeSynchronizing := ini.ReadInteger(_TR4WSERVER, 'ALLOW TIME SYNCHRONIZING', 1) = 1;
           SerialNumberLockoutEnable := ini.ReadInteger(_TR4WSERVER, 'SERIAL NUMBER LOCKOUT', 0) = 1;
           SetSerialLockout(SerialNumberLockoutEnable);

//        tGetLogTimeout := GetPrivateProfileInt(_TR4WSERVER, 'GET LOG TIMEOUT', 50, _TR4WSERVERINIFILE);
{$IF SERVERDEBUG}
           ServerDebugMode := ini.ReadInteger(_TR4WSERVER, 'DEBUG', 0) = 1;
{$IFEND}
           uAnsiStr.StrPLCopy(@tr4wServerPassword[0],
              AnsiString(ini.ReadString(_TR4WSERVER, 'SERVER PASSWORD',
                                        String(PAnsiChar(_TR4WSERVER)))),
              High(tr4wServerPassword));
        finally
           ini.Free;
        end;

        (* THE DROP-DOWN IS FILLED BEFORE ANYTHING LISTENS.

          It has to be: the operator chooses there and RunServer reads the
          choice. It can be, because GetLocalAddresses brings Indy's stack up
          itself instead of borrowing one from a running server -- which is the
          nil-GStack trap that made this program vanish with no window this
          morning, answered properly rather than by moving the call. *)
        ShowBindAddresses;

        (* NO WSAStartup, NO MSWSOCK, NO SEPARATE SYNC LISTENER.

          Indy initialises WinSock itself; TransmitFile is gone with the
          LoadLibrary that fetched it; and both listeners come up together
          inside RunServer -- see uServerNet.StartServerNet. *)

        (* THE LOG SITS BESIDE THE EXECUTABLE.

          Was GetModuleFileName followed by lstrcat, and by a magic 14 --
          the length of 'tr4wserver.exe' -- poked in as a NUL to chop the file
          name off. Rename the binary and the path was silently wrong.
          ExtractFilePath(ParamStr(0)) says the same thing and cannot be
          off by a character. *)
        (* THE CONTEST LOG, VIA uAppPaths.

          Was GetModuleFileName + lstrcat with a magic 14 -- the length of
          'tr4wserver.exe' -- poked in as a NUL to chop the file name off.
          Rename the binary and the path was silently wrong. *)
        uAnsiStr.StrPLCopy(@ServerLogFileName[0],
           AnsiString(LogFilePath('SERVERLOG.TRW')),
           High(ServerLogFileName));
{$IF SERVERDEBUG}
        uAnsiStr.StrPLCopy(@ServerDebugFileName[0],
           AnsiString(LogFilePath('DEBUG.TXT')),
           High(ServerDebugFileName));
{$IFEND}
{
        BytesReceived := Windows.GetModuleFileName(0, @MultsFrequenciesFileName, SizeOf(MultsFrequenciesFileName));
        MultsFrequenciesFileName[BytesReceived - 14] := #0;
        Windows.lstrcat(@MultsFrequenciesFileName, 'MULTS_FREQ.BIN');
        LoadinMultsFrequencies;
}
        if OpenServerLog(OPEN_ALWAYS) then
          begin
            if (ServerLog.Size mod SizeOf(ContestExchange)) <> 0 then
            begin
              logger.Error('serverlog.trw size mismatch: file size ' +
                IntToStr(ServerLog.Size) +
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
            if ServerLog.Size = 0 then
              begin
              ServerLog.WriteBuffer(LogHeader, SizeOfTLogHeader);
              end;

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
        { GetVersionEx went with TransmitFile: ServerOS existed only to say
          whether MSWSOCK's TransmitFile was available, and Indy writes a
          stream. }
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
  (* ONE SERVER AT A TIME, WITHOUT A NAMED MUTEX.

    Was CreateMutex + ERROR_ALREADY_EXISTS -- a Win32 kernel object with no
    portable equivalent. A lock file held open exclusively says the same thing
    on every platform: the second instance cannot open it and stops.

    The file is beside the executable, next to the log it guards. It is left
    behind on a crash, which costs nothing: what matters is the exclusive OPEN,
    not the file's existence. *)
  try
     GLock := TFileStream.Create(LogFilePath('tr4wserver.lock'),
                                 fmCreate or fmShareExclusive);
  except
     { Another copy holds it. Say so and go -- the original exited in silence,
       which is why "it just does not start" was a support question. }
     on E: Exception do
        begin
        ShowMessage('TR4WSERVER is already running.');
        Exit;
        end;
  end;


  Application.Initialize;
  Application.CreateForm(TfrmServer, frmServer);

  (* THE WINDOW BEFORE THE WORK, so a failure has somewhere to be reported.

    Start-up used to run before anything was shown, and when it raised -- a nil
    GStack, as it turned out -- the process ended with no window, no dialog and
    a log that stopped mid-sentence. The old Win32 version had the same shape
    of failure when its DIALOG resource went missing, and that hid for weeks.
    A program that can exit without saying why will eventually do it. *)
  frmServer.Show;
  Application.ProcessMessages;

  ServerStopQuery      := @ConfirmStop;
  ServerStopRequested  := @RequestStop;
  ServerStartRequested := @RequestStart;

  SetServerVersion(FullServerVersion);

  (* AND START-UP REPORTS ITS OWN FAILURE.

    Everything below -- the ini, the log file, binding the ports -- can fail,
    and before Application.Run there is no LCL handler to catch it. Without
    this the operator gets a program that disappears; with it they get the
    reason, in the log and on the screen. *)
  try
     ServerStartUp;
  except
     on E: Exception do
        begin
        if logger <> nil then
           begin
           logger.Error('[Startup] failed: %s: %s', [E.ClassName, E.Message]);
           end;
        MessageDlg('TR4WSERVER',
                   'The server could not start:' + sLineBreak + sLineBreak +
                   E.ClassName + ': ' + E.Message + sLineBreak + sLineBreak +
                   'See tr4wserver.log.', mtError, [mbOK], 0);
        Application.Terminate;
        end;
  end;

  Application.Run;

end.

