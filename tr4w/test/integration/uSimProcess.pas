unit uSimProcess;

{
  Launches tools/radiosim as a child process and drives it.

  The simulator's console loop reads COMMANDS FROM STDIN, one per line
  (radiosim/core.py run()) -- 'f 14200000' to move VFO A, 's' to toggle split,
  'd'/'u' to drop and restore the link, 'q' to quit.  That is what makes an
  automated bench test possible at all: the harness can change what the "radio"
  is doing without a human at the keyboard.

  Python is started with -u so its output is unbuffered and appears in step with
  the harness's own; the child inherits stdout/stderr, so a failing run shows both
  sides of the conversation in one transcript.  Only stdin is redirected.
}

interface

uses Windows, SysUtils;

type
   TSimProcess = class
   private
      FProcess: THandle;
      FThread: THandle;
      FStdinWrite: THandle;
      FRunning: boolean;
   public
      constructor Create;
      destructor Destroy; override;

      // Start `python -u -m radiosim <model> <port> <baud>` in ToolsDir.
      // Returns False (with Why set) rather than raising, so a bench machine
      // without Python fails as a clear SKIP rather than a crash.
      function Start(const ToolsDir, Model, Port: string; Baud: integer;
                     out Why: string): boolean;

      // Send one console command line to the simulator.
      function Send(const Line: string): boolean;

      // 'q', then wait; terminate if it does not exit in time.
      procedure Stop;

      // False once the child has exited.  Checked after startup because the
      // usual failure is the simulator dying immediately -- the virtual port
      // already being open elsewhere -- and without this the harness would
      // instead report a pile of unexplained protocol failures.
      function IsAlive: boolean;

      property Running: boolean read FRunning;
   end;

implementation

constructor TSimProcess.Create;
begin
   inherited Create;
   FProcess := 0;
   FThread := 0;
   FStdinWrite := 0;
   FRunning := False;
end;

destructor TSimProcess.Destroy;
begin
   Stop;
   inherited Destroy;
end;

function TSimProcess.Start(const ToolsDir, Model, Port: string; Baud: integer;
                           out Why: string): boolean;
var
   sa: TSecurityAttributes;
   si: TStartupInfo;
   pi: TProcessInformation;
   readEnd: THandle;
   cmd: string;
begin
   Result := False;
   Why := '';

   sa.nLength := SizeOf(sa);
   sa.lpSecurityDescriptor := nil;
   sa.bInheritHandle := True;         // the child must inherit the read end

   if not CreatePipe(readEnd, FStdinWrite, @sa, 0) then
      begin
      Why := 'CreatePipe failed';
      Exit;
      end;

   // Our WRITE end must NOT be inherited, or the child holds it open and the
   // simulator never sees EOF when we close it.
   if not SetHandleInformation(FStdinWrite, HANDLE_FLAG_INHERIT, 0) then
      begin
      Why := 'SetHandleInformation failed';
      CloseHandle(readEnd);
      Exit;
      end;

   FillChar(si, SizeOf(si), 0);
   si.cb := SizeOf(si);
   si.dwFlags := STARTF_USESTDHANDLES;
   si.hStdInput := readEnd;
   si.hStdOutput := GetStdHandle(STD_OUTPUT_HANDLE);
   si.hStdError := GetStdHandle(STD_ERROR_HANDLE);

   cmd := Format('python -u -m radiosim %s %s %d', [Model, Port, Baud]);

   if not CreateProcess(nil, PChar(cmd), nil, nil, True,
                        CREATE_NO_WINDOW, nil, PChar(ToolsDir), si, pi) then
      begin
      Why := Format('CreateProcess failed (%d) for: %s', [GetLastError, cmd]);
      CloseHandle(readEnd);
      CloseHandle(FStdinWrite);
      FStdinWrite := 0;
      Exit;
      end;

   FProcess := pi.hProcess;
   FThread := pi.hThread;
   CloseHandle(readEnd);              // the child owns it now
   FRunning := True;
   Result := True;
end;

function TSimProcess.Send(const Line: string): boolean;
var
   data: AnsiString;
   written: DWORD;
begin
   Result := False;
   if (not FRunning) or (FStdinWrite = 0) then
      begin
      Exit;
      end;
   // The simulator reads with readline(), so the newline is what makes the
   // command take effect -- without it the child blocks forever.
   data := AnsiString(Line) + #13#10;
   Result := WriteFile(FStdinWrite, PAnsiChar(data)^, Length(data), written, nil)
             and (written = DWORD(Length(data)));
end;

function TSimProcess.IsAlive: boolean;
var
   code: DWORD;
begin
   Result := False;
   if (not FRunning) or (FProcess = 0) then
      begin
      Exit;
      end;
   if GetExitCodeProcess(FProcess, code) then
      begin
      Result := code = STILL_ACTIVE;
      end;
end;

procedure TSimProcess.Stop;
begin
   if not FRunning then
      begin
      Exit;
      end;

   Send('q');

   if FStdinWrite <> 0 then
      begin
      CloseHandle(FStdinWrite);       // EOF also ends the simulator's loop
      FStdinWrite := 0;
      end;

   if WaitForSingleObject(FProcess, 5000) <> WAIT_OBJECT_0 then
      begin
      // It ignored both 'q' and EOF.  Kill it rather than leaving a process
      // holding the virtual COM port, which would make the NEXT run fail with a
      // confusing "port in use" instead of the real problem.
      TerminateProcess(FProcess, 1);
      WaitForSingleObject(FProcess, 2000);
      end;

   if FThread <> 0 then
      begin
      CloseHandle(FThread);
      FThread := 0;
      end;
   if FProcess <> 0 then
      begin
      CloseHandle(FProcess);
      FProcess := 0;
      end;
   FRunning := False;
end;

end.
