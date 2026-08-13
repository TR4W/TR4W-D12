program gate_a;

// FPC VIABILITY GATE A -- the I/O stack at RUNTIME.
//
// Compiling proves nothing about behaviour.  This exercises the four things
// TR4W cannot ship without, using the REAL vendored Indy 10.6.3.3 and our own
// uSerialPort, built by FPC for i386-win32:
//
//   1. Indy UDP  server + client   (the WSJT-X / UDP-broadcast shape)
//   2. Indy TCP  server + client   (the tr4wserver shape)
//   3. A line-oriented exchange with an UNTERMINATED prompt
//      (the DX cluster login shape -- the case that broke uTelnet)
//   4. A real COM port opened through our uSerialPort
//
// Build with -Mdelphi on the command line, NOT -MdelphiUnicode.  Indy forces
// Delphi mode on itself, but its conditionals follow FPC_UNICODESTRINGS,
// which the command-line switch sets and its own mode reset does not clear --
// so a command-line -MdelphiUnicode makes IdGlobal contradict itself.  This
// program declares the modeswitch for ITSELF below, which is the model the
// real build would use: our units Unicode, vendored Indy untouched.
//
// Serial test needs a port:  gate_a.exe COM4
// Without one it reports SKIP rather than passing vacuously.
//
// NOTE: these are // comments deliberately.  A compiler directive written
// inside a { } comment ends that comment at its own closing brace.

{$MODE Delphi}
{$MODESWITCH UnicodeStrings}

uses
   SysUtils,
   Classes,
   IdGlobal,
   IdContext,
   IdSocketHandle,
   IdUDPServer,
   IdUDPClient,
   IdTCPServer,
   IdTCPClient,
   IdException,
   IdStack,
   uSerialPort;

const
   UDP_PORT = 52999;
   TCP_PORT = 52998;

var
   Passed: Integer = 0;
   Failed: Integer = 0;
   Skipped: Integer = 0;

procedure Report(const AName: string; AOk: Boolean; const ADetail: string = '');
begin
   if AOk then
      begin
      Inc(Passed);
      WriteLn('  [PASS] ', AName, ' ', ADetail);
      end
   else
      begin
      Inc(Failed);
      WriteLn('  [FAIL] ', AName, ' ', ADetail);
      end;
end;

procedure Skip(const AName: string; const AReason: string);
begin
   Inc(Skipped);
   WriteLn('  [SKIP] ', AName, ' -- ', AReason);
end;

{ Handlers must be methods, so they live on a holder object. }
type
   THarness = class
   public
      UDPText: string;
      UDPGot: Boolean;
      TCPLines: TStringList;
      constructor Create;
      destructor Destroy; override;
      procedure OnUDPRead(AThread: TIdUDPListenerThread; const AData: TIdBytes;
         ABinding: TIdSocketHandle);
      procedure OnTCPExecute(AContext: TIdContext);
   end;

constructor THarness.Create;
begin
   inherited Create;
   TCPLines := TStringList.Create;
end;

destructor THarness.Destroy;
begin
   TCPLines.Free;
   inherited Destroy;
end;

procedure THarness.OnUDPRead(AThread: TIdUDPListenerThread; const AData: TIdBytes;
   ABinding: TIdSocketHandle);
begin
   { BytesToString with an explicit encoding -- Remy's warning applies here:
     Indy is compiled ANSI while we are UTF-16, so never let the boundary
     pick an encoding by default. }
   UDPText := BytesToString(AData, IndyTextEncoding_ASCII);
   UDPGot := True;
end;

procedure THarness.OnTCPExecute(AContext: TIdContext);
var
   line: string;
begin
   line := AContext.Connection.IOHandler.ReadLn;
   TCPLines.Add(line);

   if line = 'PING' then
      begin
      AContext.Connection.IOHandler.WriteLn('PONG');
      end
   else if line = 'LOGIN' then
      begin
      { An UNTERMINATED prompt: no CRLF.  This is the shape that made the
        cluster client hang -- the transport must surface it. }
      AContext.Connection.IOHandler.Write('login: ');
      end
   else
      begin
      AContext.Connection.IOHandler.WriteLn('ECHO ' + line);
      end;
end;

function WaitFor(const ACheck: TThreadMethod; ATimeoutMs: Integer): Boolean; forward;

var
   H: THarness;

{ ---- 1. UDP ------------------------------------------------------------- }
procedure TestUDP;
var
   srv: TIdUDPServer;
   cli: TIdUDPClient;
   waited: Integer;
begin
   srv := TIdUDPServer.Create(nil);
   cli := TIdUDPClient.Create(nil);
   try
      srv.DefaultPort := UDP_PORT;
      srv.Bindings.Add.SetBinding('127.0.0.1', UDP_PORT);
      srv.OnUDPRead := H.OnUDPRead;
      srv.ThreadedEvent := True;
      srv.Active := True;

      H.UDPGot := False;
      H.UDPText := '';

      cli.Host := '127.0.0.1';
      cli.Port := UDP_PORT;
      cli.Send('WSJTX-PROBE-42');

      waited := 0;
      while (not H.UDPGot) and (waited < 3000) do
         begin
         Sleep(25);
         Inc(waited, 25);
         end;

      Report('UDP datagram received', H.UDPGot, '(' + H.UDPText + ')');
      Report('UDP payload intact', H.UDPText = 'WSJTX-PROBE-42',
         'expected WSJTX-PROBE-42');

      srv.Active := False;
   finally
      cli.Free;
      srv.Free;
   end;
end;

{ ---- 2 & 3. TCP server + client, and the unterminated prompt ------------- }
procedure TestTCP;
var
   srv: TIdTCPServer;
   cli: TIdTCPClient;
   bind: TIdSocketHandle;
   reply: string;
   prompt: string;
begin
   srv := TIdTCPServer.Create(nil);
   cli := TIdTCPClient.Create(nil);
   try
      bind := srv.Bindings.Add;
      bind.IP := '127.0.0.1';
      bind.Port := TCP_PORT;
      srv.OnExecute := H.OnTCPExecute;
      srv.Active := True;
      Report('TCP server listening', srv.Active, '127.0.0.1:' + IntToStr(TCP_PORT));

      cli.Host := '127.0.0.1';
      cli.Port := TCP_PORT;
      cli.ConnectTimeout := 3000;
      cli.ReadTimeout := 3000;
      cli.Connect;
      Report('TCP client connected', cli.Connected);

      cli.IOHandler.WriteLn('PING');
      reply := cli.IOHandler.ReadLn;
      Report('TCP line round-trip', reply = 'PONG', '(' + reply + ')');

      cli.IOHandler.WriteLn('HELLO-TR4W');
      reply := cli.IOHandler.ReadLn;
      Report('TCP payload intact', reply = 'ECHO HELLO-TR4W', '(' + reply + ')');

      { The cluster-login shape: server writes `login: ` with no CRLF.  A
        ReadLn would block forever; the transport must let us see pending
        text without consuming it. }
      cli.IOHandler.WriteLn('LOGIN');
      Sleep(300);
      cli.IOHandler.CheckForDataOnSource(1000);
      prompt := cli.IOHandler.InputBufferAsString(IndyTextEncoding_ASCII);
      Report('unterminated prompt visible', Pos('login:', prompt) > 0,
         '(' + Trim(prompt) + ')');

      cli.Disconnect;
      srv.Active := False;
   finally
      cli.Free;
      srv.Free;
   end;
end;

{ ---- 4. Serial ---------------------------------------------------------- }
procedure TestSerial;
var
   port: TSerialPort;
   name: string;
   reply: string;
   waited: Integer;
begin
   name := ParamStr(1);
   if name = '' then
      begin
      Skip('serial port open', 'no port given (run: gate_a.exe COM15)');
      Exit;
      end;

   port := TSerialPort.Create(name);
   try
      try
         // K3S on COM15, 38400 8N1 per NY4I's radio config.  Open() disables
         // DTR and RTS, so nothing can key the rig.
         port.Open(sbr38400, 8, spNone, ssb1);
         Report('serial port opened', port.IsOpen, name + ' @38400 8N1');

         // FA; asks the K3 for VFO A.  A read-only command: it changes
         // nothing on the radio, and the reply proves a real CAT round trip
         // through FPC-compiled code -- not merely that a handle opened.
         port.WriteString('FA;');

         reply := '';
         waited := 0;
         while (Pos(';', reply) = 0) and (waited < 1500) do
            begin
            reply := reply + port.ReadString(64);
            Sleep(50);
            Inc(waited, 50);
            end;

         Report('CAT response received', Pos(';', reply) > 0,
            '(' + Trim(reply) + ')');
         Report('CAT reply is VFO A', Copy(reply, 1, 2) = 'FA',
            'expected FA<11 digits>;');

         port.Close;
         Report('serial port closed', not port.IsOpen, name);
      except
         on E: Exception do
            Report('serial port opened', False, name + ' -- ' + E.Message);
      end;
   finally
      port.Free;
   end;
end;

function WaitFor(const ACheck: TThreadMethod; ATimeoutMs: Integer): Boolean;
begin
   Result := False;
end;

begin
   WriteLn('FPC Gate A -- I/O stack at runtime');
   WriteLn('compiler: FPC ', {$I %FPCVERSION%}, '  target: ', {$I %FPCTARGETCPU%}, '-', {$I %FPCTARGETOS%});
   WriteLn('SizeOf(Char) = ', SizeOf(Char), ' (2 = UnicodeStrings active)');
   WriteLn;

   H := THarness.Create;
   try
      WriteLn('Indy UDP:');
      try
         TestUDP;
      except
         on E: Exception do Report('UDP suite', False, E.ClassName + ': ' + E.Message);
      end;

      WriteLn;
      WriteLn('Indy TCP:');
      try
         TestTCP;
      except
         on E: Exception do Report('TCP suite', False, E.ClassName + ': ' + E.Message);
      end;

      WriteLn;
      WriteLn('Serial:');
      try
         TestSerial;
      except
         on E: Exception do Report('serial suite', False, E.ClassName + ': ' + E.Message);
      end;
   finally
      H.Free;
   end;

   WriteLn;
   WriteLn(Format('PASSED: %d  FAILED: %d  SKIPPED: %d', [Passed, Failed, Skipped]));
   if Failed > 0 then
      Halt(1);
end.
