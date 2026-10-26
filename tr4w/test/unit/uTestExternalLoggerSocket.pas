unit uTestExternalLoggerSocket;
{$I ..\..\src\tr4w.inc}

(*
  PINS ONE RULE FOR THE EXTERNAL LOGGER'S PERSISTENT SOCKET (the ACLog / HRD
  path in TExternalLoggerBase): ONLY ITS READING THREAD READS IT.

  The defect class is the network-radio hang of 2026-10-25 (commit a4866344).
  Indy's TIdTCPConnection.Connected is not a flag read: it ends in
  ReadFromSource(False, 0, False), a zero-timeout select and then a BLOCKING
  recv into the InputBuffer the reading thread is consuming.  Asked from the
  main thread or the sender thread it can wait for ever, or move the reader's
  bytes out from under it.  A bare Disconnect is Disconnect(True), which asks
  Connected first.

  The base class asked Connected in IsConnected, SendToLogger, Disconnect, the
  default DeliverCommand and the destructor.  They ask IndyLinkIsOpen now.

  HOW THESE TESTS PIN IT WITHOUT RACING TWO THREADS (the same method as
  uTestRadioSocketNoRead): no reading thread exists here (the probe connects
  without OnConnected, which is what starts one), the fixture server sends a
  line first, and the test waits until those bytes are sitting in the kernel
  buffer.  Anything that then reads the socket moves them into Indy's
  InputBuffer, so "InputBuffer still empty" is exactly "did not read".

  The second half pins the IOHandler lifetime: a failed Connect must leave the
  SAME, unmanaged handler in place (Indy frees a managed one on failure,
  IdTCPClient.pas:338-342, under whichever thread holds it).

  NOT COVERED HERE, and why: TExternalLogger (DXKeeper) never touches this
  socket -- DeliverCommand opens a client per command on the sender thread, the
  sole owner of that client.  And the destructor's reading-thread join needs a
  live reading thread against a peer that stays up; it is read, not run.
*)

interface

uses
   SysUtils, Classes, SyncObjs, IdTCPServer, IdContext, IdGlobal, IdIOHandler,
   IdExceptionCore,
   uTR4WTestFramework, uExternalLoggerBase, uExternalLogger, uIndyLink;

type
   (* A real TExternalLogger, so IsConnected, SendToLogger and Connect are the
     shipped code.  It reaches the protected socket through the door any
     descendant has, and never starts a reading thread -- see the unit header. *)
   TLoggerSocketProbe = class(TExternalLogger)
   private
      FAttempts: Integer;          // calls into the socket's Connect (issue #102)
      FAlreadyConnected: Integer;  // of those, how many raised EIdAlreadyConnected
      FConnectDelayMs: Integer;    // widens the race window for the two-thread test
   protected
      procedure DoSocketConnect; override;
   public
      function  ConnectTimeoutValue: Integer;
      property  ConnectAttempts: Integer read FAttempts;
      property  AlreadyConnectedCount: Integer read FAlreadyConnected;
      property  ConnectDelayMs: Integer read FConnectDelayMs write FConnectDelayMs;
      procedure AttachWithoutReader(const AHost: string; APort: Integer);
      function  ConnectThroughBase(const AHost: string; APort: Integer): Integer;
      procedure SendThroughBase(const AText: string);
      function  BufferedInbound: Integer;
      function  WaitInboundArrived(AMs: Integer): Boolean;
      function  Handler: TIdIOHandler;
      function  HandlerIsManaged: Boolean;
   end;

   (* Calls the shipped Connect once the gate opens, so two of them start
     together. *)
   TConnectRacer = class(TThread)
   private
      FProbe:  TLoggerSocketProbe;
      FHost:   string;
      FPort:   Integer;
      FGate:   TEvent;
   public
      Answer:  Integer;
      constructor Create(AProbe: TLoggerSocketProbe; const AHost: string; APort: Integer; AGate: TEvent);
      procedure Execute; override;
   end;

   TExternalLoggerSocketTests = class(TTestCase)
   private
      FServer:   TIdTCPServer;
      FLock:     TCriticalSection;
      FReceived: TStringList;      // lines the fixture server heard (server thread)
      procedure ServerConnect(AContext: TIdContext);
      procedure ServerExecute(AContext: TIdContext);
      function  StartServer: Word;
      procedure StopServer;
      function  ClosedLoopbackPort: Word;
      function  WaitForReceived(const ALine: string; ATimeoutMs: Integer): Boolean;
   protected
      procedure Test_IsConnected_DoesNotReadTheSocket;
      procedure Test_SendToLogger_DoesNotReadTheSocket;
      procedure Test_Disconnect_ClosesTheLink;
      procedure Test_NotConnected_SendRaisesNothing;
      procedure Test_FailedConnect_KeepsTheSameIOHandler;
      procedure Test_AttachAfterFailedConnect_ReusesTheHandler;
      procedure Test_ConnectTimeout_IsARealValue;
      procedure Test_TwoConcurrentConnects_MakeOneAttempt;
   public
      procedure RunAllTests; override;
   end;

implementation

const
   (* What the fixture "logger" says first, unprompted.  Its only job is to be
     sitting unread on the socket when the code under test runs. *)
   GREETING = 'HELLO;';
   TEST_CMD = 'LOOKUP;';

(* ---- probe ---------------------------------------------------------------- *)

procedure TLoggerSocketProbe.AttachWithoutReader(const AHost: string; APort: Integer);
begin
   (* OnConnected is what creates the reading thread.  Without it the test's
     own thread is the only party that could read -- so any read is the code
     under test's. *)
   socket.OnConnected := nil;
   IndyLinkOwnHandler(socket, nil);
   socket.Host := AHost;
   socket.Port := APort;
   socket.ConnectTimeout := 3000;
   socket.Connect;
end;

(* The SHIPPED connect path (TExternalLoggerBase.Connect), with OnConnected
  removed so a success would start no reading thread.  It catches and logs its
  own failures, as in production. *)
function TLoggerSocketProbe.ConnectThroughBase(const AHost: string; APort: Integer): Integer;
begin
   socket.OnConnected := nil;
   Result := TExternalLoggerBase(Self).Connect(AHost, APort);
end;

(* Counts every attempt that reaches the socket, and records an
  EIdAlreadyConnected (Connect called while connected -- the symptom of two
  threads connecting at once).  The optional delay keeps the first attempt in
  flight long enough for a second thread to arrive. *)
procedure TLoggerSocketProbe.DoSocketConnect;
begin
   InterlockedIncrement(FAttempts);

   if FConnectDelayMs > 0 then
      begin
      Sleep(FConnectDelayMs);
      end;

   try
      inherited DoSocketConnect;
   except
      on EIdAlreadyConnected do
         begin
         InterlockedIncrement(FAlreadyConnected);
         raise;
         end;
   end;
end;

function TLoggerSocketProbe.ConnectTimeoutValue: Integer;
begin
   Result := socket.ConnectTimeout;
end;

(* The base one-argument SendToLogger, named through the base so the private
  two-argument overload in TExternalLogger cannot get in the way. *)
procedure TLoggerSocketProbe.SendThroughBase(const AText: string);
begin
   TExternalLoggerBase(Self).SendToLogger(AText);
end;

function TLoggerSocketProbe.BufferedInbound: Integer;
begin
   Result := 0;

   if socket.IOHandler <> nil then
      begin
      Result := socket.IOHandler.InputBuffer.Size;
      end;
end;

(* Readable is a select and nothing else -- it waits for the bytes WITHOUT
  taking them. *)
function TLoggerSocketProbe.WaitInboundArrived(AMs: Integer): Boolean;
begin
   Result := (socket.IOHandler <> nil) and socket.IOHandler.Readable(AMs);
end;

function TLoggerSocketProbe.Handler: TIdIOHandler;
begin
   Result := socket.IOHandler;
end;

function TLoggerSocketProbe.HandlerIsManaged: Boolean;
begin
   Result := socket.ManagedIOHandler;
end;

constructor TConnectRacer.Create(AProbe: TLoggerSocketProbe; const AHost: string;
                                 APort: Integer; AGate: TEvent);
begin
   FProbe := AProbe;
   FHost := AHost;
   FPort := APort;
   FGate := AGate;
   Answer := MaxInt;
   inherited Create(False);
end;

procedure TConnectRacer.Execute;
begin
   FGate.WaitFor(5000);
   Answer := FProbe.ConnectThroughBase(FHost, FPort);
end;

(* ---- fixture server (its own threads) ------------------------------------- *)

procedure TExternalLoggerSocketTests.ServerConnect(AContext: TIdContext);
begin
   AContext.Connection.IOHandler.Write(GREETING, IndyTextEncoding_8Bit);
end;

procedure TExternalLoggerSocketTests.ServerExecute(AContext: TIdContext);
var
   line: string;
begin
   line := AContext.Connection.IOHandler.ReadLn(LF, 100, -1, IndyTextEncoding_8Bit);

   if AContext.Connection.IOHandler.ReadLnTimedout then
      begin
      Exit;
      end;

   FLock.Enter;
   try
      FReceived.Add(Trim(line));
   finally
      FLock.Leave;
   end;
end;

function TExternalLoggerSocketTests.StartServer: Word;
begin
   FReceived.Clear;

   FServer := TIdTCPServer.Create(nil);
   FServer.OnConnect := ServerConnect;
   FServer.OnExecute := ServerExecute;

   with FServer.Bindings.Add do
      begin
      IP := '127.0.0.1';
      Port := 0;          // ephemeral: never collides with a real service
      end;

   FServer.Active := True;
   Result := FServer.Bindings[0].Port;
end;

procedure TExternalLoggerSocketTests.StopServer;
begin
   if FServer <> nil then
      begin
      FServer.Active := False;
      FreeAndNil(FServer);
      end;
end;

(* A loopback port nothing listens on: bind an ephemeral one, then let it go.
  A connect to it is refused, which is Indy's failed-connect path. *)
function TExternalLoggerSocketTests.ClosedLoopbackPort: Word;
begin
   Result := StartServer;
   StopServer;
end;

function TExternalLoggerSocketTests.WaitForReceived(const ALine: string; ATimeoutMs: Integer): Boolean;
var
   waited: Integer;
begin
   waited := 0;
   Result := False;

   while (not Result) and (waited <= ATimeoutMs) do
      begin
      FLock.Enter;
      try
         Result := FReceived.IndexOf(ALine) >= 0;
      finally
         FLock.Leave;
      end;

      if not Result then
         begin
         Sleep(20);
         Inc(waited, 20);
         end;
      end;
end;

(* ---- tests ------------------------------------------------------------------ *)

procedure TExternalLoggerSocketTests.Test_IsConnected_DoesNotReadTheSocket;
var
   probe: TLoggerSocketProbe;
begin
   BeginTest('IsConnected on a connected external logger does not read the socket');

   probe := TLoggerSocketProbe.Create(lt_ACLog);
   try
      probe.AttachWithoutReader('127.0.0.1', StartServer);

      CheckTrue(probe.WaitInboundArrived(3000),
                'precondition: the logger''s unsolicited line is waiting on the socket');
      CheckEquals(0, probe.BufferedInbound, 'precondition: nothing has read it yet');

      CheckTrue(probe.IsConnected, 'an open socket reports connected');

      CheckEquals(0, probe.BufferedInbound,
                  'IsConnected READ the socket -- Indy''s Connected does a recv, and ' +
                  'off the reading thread that recv can block for ever (2026-10-25 hang)');
   finally
      probe.Free;
      StopServer;
   end;
end;

procedure TExternalLoggerSocketTests.Test_SendToLogger_DoesNotReadTheSocket;
var
   probe: TLoggerSocketProbe;
begin
   BeginTest('SendToLogger on a connected external logger does not read the socket');

   probe := TLoggerSocketProbe.Create(lt_ACLog);
   try
      probe.AttachWithoutReader('127.0.0.1', StartServer);

      CheckTrue(probe.WaitInboundArrived(3000),
                'precondition: the logger''s unsolicited line is waiting on the socket');

      probe.SendThroughBase(TEST_CMD);

      CheckEquals(0, probe.BufferedInbound,
                  'SendToLogger READ the socket (it asked Connected) -- see the unit header');
      CheckTrue(WaitForReceived(TEST_CMD, 3000), 'the command still reached the logger');
   finally
      probe.Free;
      StopServer;
   end;
end;

procedure TExternalLoggerSocketTests.Test_Disconnect_ClosesTheLink;
var
   probe: TLoggerSocketProbe;
begin
   BeginTest('Disconnect closes an open link and a second Disconnect is harmless');

   probe := TLoggerSocketProbe.Create(lt_ACLog);
   try
      probe.AttachWithoutReader('127.0.0.1', StartServer);
      (* The greeting proves the server finished setting the connection up;
        stopping it mid-setup can hang Indy's shutdown for ever. See the same
        wait in uTestClusterSocketNoRead. *)
      CheckTrue(probe.WaitInboundArrived(3000),
                'precondition: the server has finished setting up the connection');
      CheckTrue(probe.IsConnected, 'precondition: the link is open');

      probe.Disconnect;
      CheckFalse(probe.IsConnected, 'Disconnect closed the link');

      try
         probe.Disconnect;
         CheckTrue(True, 'a second Disconnect raised nothing');
      except
         on E: Exception do
            begin
            CheckTrue(False, 'a second Disconnect raised ' + E.ClassName + ': ' + E.Message);
            end;
      end;
   finally
      probe.Free;
      StopServer;
   end;
end;

procedure TExternalLoggerSocketTests.Test_NotConnected_SendRaisesNothing;
var
   probe: TLoggerSocketProbe;
begin
   BeginTest('SendToLogger with no connection and no address raises nothing');

   (* The IOHandler does not exist yet: IsConnected must say False without
     touching anything, and the send must log and return. *)
   probe := TLoggerSocketProbe.Create(lt_ACLog);
   try
      CheckFalse(probe.IsConnected, 'a never-connected logger is not connected');

      try
         probe.SendThroughBase(TEST_CMD);
         CheckTrue(True, 'no exception from a never-connected send');
      except
         on E: Exception do
            begin
            CheckTrue(False, 'a never-connected send raised ' + E.ClassName + ': ' + E.Message);
            end;
      end;
   finally
      probe.Free;
   end;
end;

(* THE IOHANDLER OUTLIVES A FAILED CONNECT.

  Indy's implicit handler is ManagedIOHandler, and TIdTCPClientCustom.Connect
  FREES it when the connect fails.  The reading thread runs Connect while the
  main thread and the sender dereference socket.IOHandler.  As with the no-read
  tests, this pins the lifetime INVARIANT rather than racing threads for the
  freed pointer. *)
procedure TExternalLoggerSocketTests.Test_FailedConnect_KeepsTheSameIOHandler;
var
   probe: TLoggerSocketProbe;
   before: TIdIOHandler;
   closedPort: Word;
begin
   BeginTest('A failed connect does not free or replace the logger''s IOHandler');

   closedPort := ClosedLoopbackPort;

   probe := TLoggerSocketProbe.Create(lt_ACLog);
   try
      probe.ConnectThroughBase('127.0.0.1', closedPort);
      CheckFalse(probe.IsConnected, 'precondition: the connect was refused');

      before := probe.Handler;
      CheckTrue(before <> nil,
                'a failed Connect freed the IOHandler -- another thread holding ' +
                'socket.IOHandler would dereference freed memory');
      CheckFalse(probe.HandlerIsManaged,
                 'the IOHandler is not Indy-managed (a managed one is freed by a failed Connect)');

      probe.ConnectThroughBase('127.0.0.1', closedPort);
      CheckTrue(probe.Handler = before, 'a second failed Connect kept the same IOHandler');
      CheckFalse(probe.HandlerIsManaged, 'still not managed after two failed connects');
   finally
      probe.Free;
   end;
end;

(* Reusing the handler is the behaviour, so pin that it WORKS: refused once,
  then a live server, and the link comes up on the same instance and carries a
  command. *)
procedure TExternalLoggerSocketTests.Test_AttachAfterFailedConnect_ReusesTheHandler;
var
   probe: TLoggerSocketProbe;
   before: TIdIOHandler;
   closedPort: Word;
begin
   BeginTest('A connect after a failed connect comes up on the same IOHandler');

   closedPort := ClosedLoopbackPort;

   probe := TLoggerSocketProbe.Create(lt_ACLog);
   try
      probe.ConnectThroughBase('127.0.0.1', closedPort);
      CheckFalse(probe.IsConnected, 'precondition: the first connect was refused');
      before := probe.Handler;
      CheckTrue(before <> nil, 'precondition: the refused connect left a handler');

      probe.AttachWithoutReader('127.0.0.1', StartServer);
      CheckTrue(probe.IsConnected, 'the reconnect came up');
      CheckTrue(probe.Handler = before, 'on the handler the failed connect left behind');

      probe.SendThroughBase(TEST_CMD);
      CheckTrue(WaitForReceived(TEST_CMD, 3000), 'and it carries a command');
   finally
      probe.Free;
      StopServer;
   end;
end;

(* ISSUE #102, FIRST HALF.  Indy's ConnectTimeout is in MILLISECONDS and the
  connect set it to 10, so it gave up after 10 ms on any real network.  The
  value must be the shared 5000 ms constant (TFactoryRadioBase.Connect's), and
  it must be what the socket actually carries after a connect. *)
procedure TExternalLoggerSocketTests.Test_ConnectTimeout_IsARealValue;
var
   probe: TLoggerSocketProbe;
begin
   BeginTest('the external logger connects with a 5000 ms timeout, not 10');

   CheckEquals(5000, INDY_LINK_CONNECT_TIMEOUT_MS, 'the shared constant is the radio base''s 5000 ms');

   probe := TLoggerSocketProbe.Create(lt_ACLog);
   try
      CheckEquals(INDY_LINK_CONNECT_TIMEOUT_MS, probe.ConnectTimeoutValue,
                  'a new logger starts with it');

      CheckEquals(0, probe.ConnectThroughBase('127.0.0.1', StartServer), 'connected');
      CheckTrue(probe.WaitInboundArrived(3000),
                'precondition: the server has finished setting up the connection');
      CheckEquals(INDY_LINK_CONNECT_TIMEOUT_MS, probe.ConnectTimeoutValue,
                  'and Connect leaves it at the constant (it set 10 ms)');
   finally
      probe.Free;
      StopServer;
   end;
end;

(* ISSUE #102, SECOND HALF.  Two threads asking to connect at the same moment
  (the main thread's Connect and the reading thread's reconnect) must produce
  ONE attempt on the socket: the second waits for the first, finds the link
  open and returns.  Before, both ran Socket.Connect -- EIdAlreadyConnected, or
  two connections.  The probe's 250 ms delay inside the attempt holds the first
  in flight so the second arrives while it is. *)
procedure TExternalLoggerSocketTests.Test_TwoConcurrentConnects_MakeOneAttempt;
var
   probe: TLoggerSocketProbe;
   gate: TEvent;
   first, second: TConnectRacer;
   port: Word;
begin
   BeginTest('two concurrent Connect calls make exactly one connection attempt');

   gate := TEvent.Create(nil, True, False, '');   // manual reset: opens both
   probe := TLoggerSocketProbe.Create(lt_ACLog);
   first := nil;
   second := nil;
   try
      probe.ConnectDelayMs := 250;
      port := StartServer;

      first := TConnectRacer.Create(probe, '127.0.0.1', port, gate);
      second := TConnectRacer.Create(probe, '127.0.0.1', port, gate);
      gate.SetEvent;
      first.WaitFor;
      second.WaitFor;

      CheckEquals(1, probe.ConnectAttempts, 'exactly one attempt reached the socket');
      CheckEquals(0, probe.AlreadyConnectedCount, 'no EIdAlreadyConnected');
      CheckEquals(0, first.Answer, 'the first caller reports connected');
      CheckEquals(0, second.Answer, 'the second finds it connected and reports so');
      CheckTrue(probe.IsConnected, 'one live connection');

      (* The greeting proves the server finished setting the connection up;
        stopping it before that can hang Indy's shutdown for ever. *)
      CheckTrue(probe.WaitInboundArrived(3000),
                'precondition for stopping the server: it has finished setting up the connection');
   finally
      first.Free;
      second.Free;
      probe.Free;
      gate.Free;
      StopServer;
   end;
end;

procedure TExternalLoggerSocketTests.RunAllTests;
begin
   FLock := TCriticalSection.Create;
   FReceived := TStringList.Create;
   try
      Test_ConnectTimeout_IsARealValue;
      Test_TwoConcurrentConnects_MakeOneAttempt;
      Test_IsConnected_DoesNotReadTheSocket;
      Test_SendToLogger_DoesNotReadTheSocket;
      Test_Disconnect_ClosesTheLink;
      Test_NotConnected_SendRaisesNothing;
      Test_FailedConnect_KeepsTheSameIOHandler;
      Test_AttachAfterFailedConnect_ReusesTheHandler;
   finally
      StopServer;
      FReceived.Free;
      FLock.Free;
   end;
end;

end.
