program tr4wserver;

{$IMPORTEDDATA OFF}
uses
  (* cthreads AND cwstring, BEFORE Interfaces, AND ONLY ON UNIX.

    This program had NEITHER until 2026-09-16, and build-unix.sh stage 6 builds
    it on both Linux and macOS -- a threaded TCP server with no thread manager
    and no UnicodeString manager. Both are managers the Win32 RTL always has
    and the Unix RTL only gets by LINKING a unit, so no Windows build can show
    the gap and a Unix COMPILE passes either way. cthreads reports
    "This binary has no thread support compiled in"; a missing cwstring raises
    ENoWideStringSupport on the first UnicodeString/AnsiString conversion.

    They go BEFORE Interfaces despite the note below, and the two rules do not
    actually conflict: the program file Lazarus generates lists cthreads first,
    Interfaces second and Forms third. cthreads must come first because unit
    INITIALIZATION runs in uses order and it installs the manager there; the
    Interfaces rule is about LINKING the widgetset, which order cannot
    affect. *)
{$IFDEF UNIX}
  cthreads,
  cwstring,
{$ENDIF}
  (* Interfaces FIRST, and it must be: it is what links the widget set. Without
    it the program compiles and fails at the LINK with a page of
    "Undefined symbol: WSRegisterMenuItem" -- the LCL's widgetset registration
    hooks, which only the interfaces unit supplies. *)
  Interfaces,
  Forms,
  Classes,        // TFileStream -- the single-instance lock
  IniFiles,       // TIniFile -- the settings, was GetPrivateProfile*
  Dialogs,        // ShowMessage -- was MessageBox
  utils_text,     // SetCharBufferBytes -- StrPLCopy without the pointer
  uAppPaths,      // where written files go, per platform
  uServerForm,    // the window, at last a designed one
  (* CRASH REPORTING, AND THE LCL ENTRY POINT IS THE RIGHT ONE HERE.

    THIS PROGRAM HAS A WIDGET SET. It is not the console program CLAUDE.md and
    uCrashLogLCL's own header still describe -- it uses Interfaces, Forms and
    Dialogs above, its window is a streamed .lfm, and Get-SearchPaths.ps1 gives
    the Server target src\ui\lcl and the LCL units, saying in its own header
    that "tr4wserver is an LCL application now". So InstallCrashLog alone would
    install HALF the reporting: the LCL catches exceptions raised inside its own
    control and event-handler code and never lets them reach ExceptProc, which
    is exactly where a fault in frmServer would go.

    uCrashLog itself stays free of the LCL, which is the invariant that matters
    and is unaffected by this: the split is between the two UNITS, not between
    the two programs. *)
  uCrashLogLCL,
  (* LCLType. THE COMMENT THAT STOOD HERE WAS WRONG, AND IT WAS WRITTEN THE
    SAME DAY (2026-09-08).

    It said "LCLType IS NOT AVAILABLE HERE -- tr4wserver is a console program
    and Build-Server.ps1 deliberately keeps the LCL off its search path". That
    HAD been true, and stopped being true on 2026-09-06: Get-SearchPaths.ps1
    adds the LCL units for ALL THREE targets, its own header says "Server has
    it too since it became an LCL application", and the only `-ne 'Server'`
    exclusion left guards SQLite. This program file already uses Interfaces,
    Forms and Dialogs.

    The reason it was wrong is worth more than the fix: it was MEASURED --
    the import was removed and the compiler read -- but measured against a
    build script that had changed two days earlier, and then written down as a
    standing constraint. A measurement dates as fast as the thing it measured.

    MB_OK, MB_ICONWARNING and IDNO come from LCLType. MB_TOPMOST is not
    declared there and is not needed: ServerMessageBox has been
    Dialogs.MessageDlg since the server became an LCL application, and
    MessageDlg has no topmost concept. OPEN_ALWAYS is gone from here entirely
    -- see OpenOrCreateServerLog. *)
  LCLType,
  SysUtils,
  tr4wserverUnit in '..\src\tr4wserverUnit.pas',
  uCRC32 in '..\src\uCRC32.pas',
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

        (* InitServerLogger USED TO BE THE FIRST THING HERE, and it is now the
          first thing in the program body instead -- see the note there. It had
          to move so the crash reporter could be installed the moment the log
          exists rather than after the window had already been built and shown,
          which is where the faults this program has actually had were raised. *)
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
        ini := TIniFile.Create(DataFilePath(_TR4WSERVERINIFILE));
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
           (* BYTES, NOT TEXT. This password is compared byte for byte
             against what a client sends, so it must not be re-encoded on the
             way into the buffer -- SetCharBufferBytes, not SetCharBuffer. *)
           SetCharBufferBytes(tr4wServerPassword,
              AnsiString(ini.ReadString(_TR4WSERVER, 'SERVER PASSWORD',
                                        _TR4WSERVER)));
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
        SetCharBufferBytes(ServerLogFileName,
           AnsiString(LogFilePath('SERVERLOG.TRW')));
{
        BytesReceived := Windows.GetModuleFileName(0, @MultsFrequenciesFileName, SizeOf(MultsFrequenciesFileName));
        MultsFrequenciesFileName[BytesReceived - 14] := #0;
        Windows.lstrcat(@MultsFrequenciesFileName, 'MULTS_FREQ.BIN');
        LoadinMultsFrequencies;
}
        if OpenOrCreateServerLog then
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
                { MB_TOPMOST dropped from these three calls (2026-09-08): ServerMessageBox
                  has been Dialogs.MessageDlg since the server became an LCL
                  application, and MessageDlg has no topmost concept -- the flag
                  had already stopped doing anything. }
                MB_OK or MB_ICONWARNING);
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
            ServerMessageBox('Failed to open/create serverlog.trw', MB_OK or MB_ICONWARNING);
            begin ServerShutDown; Exit; end;
          end;
        //        SortServerLog;
        ScanLogForSerialsNumbers;

//        SetPointerEvent := CreateEvent(nil, False, False, nil);
        RunServerThread;

        (* THE OS VERSION BLOCK IS DELETED (2026-09-08), and the comment that
          stood here had already explained why it was pointless: "GetVersionEx
          went with TransmitFile: ServerOS existed only to say whether
          MSWSOCK's TransmitFile was available, and Indy writes a stream."

          What was left was setting dwOSVersionInfoSize for a call that no
          longer happens, then copying dwPlatformId -- which nothing had
          filled -- into ServerOS, which nothing reads. Checked with the
          comment-blanking reader: one declaration, one write, no readers. *)
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
         MB_YESNO or MB_ICONQUESTION or MB_DEFBUTTON2) <> IDNO;
      end;
end;

procedure RequestStop;
begin
   ServerShutDown;

   (* RE-ENUMERATE, KEEPING WHAT IS SELECTED.

     The list was built once during start-up, and the reason an operator
     presses Stop is usually to change where the server listens -- which is
     exactly when an interface that came up afterwards (a VPN, a cable plugged
     in) needs to be in it. Reading the selection back into ServerBindAddress
     first is what preserves it: an empty string is "all interfaces" and
     reselects row 0. *)
   ServerBindAddress := GetBindAddress;
   ShowBindAddresses;
end;

(* START AGAIN, ON WHATEVER IS IN THE BOXES NOW.

  This used to log "Start pressed while the server is already listening --
  ignored", and said of itself that it was only reachable "if a future change
  re-enables it". This is that change: Stop no longer closes the program, so
  there is a stopped-and-open state to start out of.

  THE PORT IS RE-READ, not just the address. edtPort has been enabled whenever
  the server is stopped since the form was written; until now that could not
  happen, so nothing ever read it back. GetServerPort falls back to the current
  PortNumber, so a box someone has emptied or filled with rubbish keeps the
  port the server already had rather than trying to bind to zero.

  A failure to bind reports itself inside StartServerNet and leaves the window
  in the stopped state, which is the useful place to be: the operator picks a
  different interface or port and presses Start again. *)
procedure RequestStart;
begin
   PortNumber := GetServerPort(PortNumber);
   RunServer;
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

  (* THE LOG, THEN THE CRASH REPORTER, BEFORE ANYTHING THAT CAN FAULT.

    WHERE A tr4wserver CRASH NOW GOES: tr4wserver.log, and nowhere else. It
    needs no new file and no second writer on the application's tr4w.log --
    InitServerLogger configures the ROOT logger with this program's appender
    (TLogBasicConfigurator.Configure), and uCrashLog writes through
    'TR4WDebugLog.CrashLog', which is additive and propagates to that same root
    appender. One file, beside the executable on Windows and under the user's
    log directory elsewhere, which is the file an operator is already asked for.

    WHY HERE AND NOT IN ServerStartUp, where InitServerLogger used to sit.
    Two reasons, both load-bearing:

      - AFTER THE LOCK. A second instance must not open the shared log, which is
        the whole reason the lock is taken first; that is the same rule
        EarlyTrace exists to respect in the application.

      - BEFORE Application.Initialize. ServerStartUp does not run until the form
        has been created and shown, so installing there would leave LFM
        streaming, widgetset start-up and frmServer.Show unreported -- and those
        are not hypothetical gaps: this program has already exited twice with no
        window and nothing in any log (a missing DIALOG resource, then a nil
        GStack), which is what the comments below and in ServerStartUp record.

    uCrashLog captures the main thread at install time, so it must run on the
    thread that goes on to call Application.Run. It does: this is the program
    body.

    UNTIL NOW NOTHING INSTALLED IT AT ALL. The reporter has been LINKED into
    this program for months -- tr4wserverUnit -> TF -> uCrashLog -- and CLAUDE.md
    claimed the call existed. It did not: InstallCrashLog had no live caller
    anywhere in the tree, so a tr4wserver crash produced nothing. Nothing
    failed, which is why it survived; Lint-CrashLogInstalled is the gate that
    stops it coming back. *)
  InitServerLogger;
  InstallCrashLogLCL;

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

