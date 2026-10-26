unit uTestClusterSocketNoRead;
{$I ..\..\src\tr4w.inc}

(*
  PINS ONE RULE: ONLY THE READER THREAD READS THE DX CLUSTER SOCKET.

  The same defect as the network radio's (commit a4866344, the band-map tune
  hang of 2026-10-25).  Indy's TIdTCPConnection.Connected READS: it ends in
  ReadFromSource(False, 0, False), a zero-timeout select and then a BLOCKING
  recv into the InputBuffer.  TDXClusterClient.GetIsConnected called it from the
  main thread (SendLine, TelnetIsConnected, the toolbar) and from the connect
  thread, while TDXClusterReader sat in ReadLn on the same socket; a bare
  FTCP.Disconnect is Disconnect(True), which probes Connected too.

  HOW THESE TESTS OBSERVE A READ WITHOUT RACING.  The probe overrides
  StartReader to nothing, so NO thread reads.  The fixture server sends a line
  on connect and the test waits (a select, which takes nothing) until it is
  sitting in the kernel buffer.  Anything that then reads the socket moves it
  into Indy's InputBuffer, so "InputBuffer still empty" is exactly "the code
  under test did not read" -- deterministic, no sleeps on the assertion.

  Against the old GetIsConnected and SendLine (FTCP.Connected) the two
  *_DoesNotReadTheSocket tests fail.  The remaining tests pin the other half of
  the fix: the IOHandler is OWNED, so a refused connect no longer frees it out
  from under the main thread.
*)

interface

uses
   SysUtils, Classes, SyncObjs, IdTCPServer, IdContext, IdGlobal, IdIOHandler,
   uTR4WTestFramework, uDXClusterClient;

type
   (* The shipped client, with only the reading thread removed. *)
   TClusterNoReadProbe = class(TDXClusterClient)
   protected
      procedure StartReader; override;
   public
      function  BufferedInbound: Integer;
      function  WaitInboundArrived(AMs: Integer): Boolean;
      function  Handler: TIdIOHandler;
      function  HandlerIsManaged: Boolean;
   end;

   TClusterSocketNoReadTests = class(TTestCase)
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
      procedure Test_SendLine_DoesNotReadTheSocket;
      procedure Test_Disconnect_ClosesAndIsRepeatable;
      procedure Test_NotConnected_SendsNothingAndRaisesNothing;
      procedure Test_FailedConnect_KeepsTheSameIOHandler;
      procedure Test_ConnectAfterFailedConnect_ReusesTheHandler;
   public
      procedure RunAllTests; override;
   end;

implementation

const
   (* What the fixture "cluster" says first, unprompted.  Its only job is to be
     sitting unread on the socket when the code under test runs. *)
   GREETING = 'Welcome to the fixture node';
   TEST_CMD = 'sh/dx 5';

(* ---- probe ---------------------------------------------------------------- *)

procedure TClusterNoReadProbe.StartReader;
begin
   // deliberately nothing: see the unit header
end;

function TClusterNoReadProbe.BufferedInbound: Integer;
begin
   Result := 0;

   if FTCP.IOHandler <> nil then
      begin
      Result := FTCP.IOHandler.InputBuffer.Size;
      end;
end;

(* Readable is a select and nothing else -- it waits for the bytes WITHOUT
  taking them. *)
function TClusterNoReadProbe.WaitInboundArrived(AMs: Integer): Boolean;
begin
   Result := (FTCP.IOHandler <> nil) and FTCP.IOHandler.Readable(AMs);
end;

function TClusterNoReadProbe.Handler: TIdIOHandler;
begin
   Result := FTCP.IOHandler;
end;

function TClusterNoReadProbe.HandlerIsManaged: Boolean;
begin
   Result := FTCP.ManagedIOHandler;
end;

(* ---- fixture server (its own threads) ------------------------------------- *)

procedure TClusterSocketNoReadTests.ServerConnect(AContext: TIdContext);
begin
   AContext.Connection.IOHandler.Write(GREETING + #13#10, IndyTextEncoding_8Bit);
end;

procedure TClusterSocketNoReadTests.ServerExecute(AContext: TIdContext);
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

function TClusterSocketNoReadTests.StartServer: Word;
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

procedure TClusterSocketNoReadTests.StopServer;
begin
   if FServer <> nil then
      begin
      FServer.Active := False;
      FreeAndNil(FServer);
      end;
end;

(* A loopback port nothing listens on: bind an ephemeral one, then let it go.
  A connect to it is refused, which is Indy's failed-connect path. *)
function TClusterSocketNoReadTests.ClosedLoopbackPort: Word;
begin
   Result := StartServer;
   StopServer;
end;

function TClusterSocketNoReadTests.WaitForReceived(const ALine: string; ATimeoutMs: Integer): Boolean;
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

procedure TClusterSocketNoReadTests.Test_IsConnected_DoesNotReadTheSocket;
var
   probe: TClusterNoReadProbe;
begin
   BeginTest('Cluster IsConnected on a live link does not read the socket');

   probe := TClusterNoReadProbe.Create;
   try
      CheckTrue(probe.Connect('127.0.0.1', StartServer), 'precondition: connected');

      CheckTrue(probe.WaitInboundArrived(3000),
                'precondition: the node''s greeting is waiting on the socket');
      CheckEquals(0, probe.BufferedInbound,
                  'precondition: nothing has read it yet');

      (* The main thread and the connect thread both ask this. *)
      CheckTrue(probe.IsConnected, 'an open link reports connected');

      CheckEquals(0, probe.BufferedInbound,
                  'IsConnected READ the socket -- Indy''s Connected does a recv, and ' +
                  'off the reader thread that recv can block for ever');
   finally
      probe.Free;
      StopServer;
   end;
end;

procedure TClusterSocketNoReadTests.Test_SendLine_DoesNotReadTheSocket;
var
   probe: TClusterNoReadProbe;
begin
   BeginTest('Cluster SendLine on a live link does not read the socket');

   probe := TClusterNoReadProbe.Create;
   try
      CheckTrue(probe.Connect('127.0.0.1', StartServer), 'precondition: connected');

      CheckTrue(probe.WaitInboundArrived(3000),
                'precondition: the node''s greeting is waiting on the socket');

      probe.SendLine(AnsiString(TEST_CMD));

      CheckEquals(0, probe.BufferedInbound,
                  'SendLine READ the socket -- it asked a probing Connected first');
      CheckTrue(WaitForReceived(TEST_CMD, 3000),
                'the command still reached the node');
   finally
      probe.Free;
      StopServer;
   end;
end;

procedure TClusterSocketNoReadTests.Test_Disconnect_ClosesAndIsRepeatable;
var
   probe: TClusterNoReadProbe;
begin
   BeginTest('Cluster Disconnect closes the link and a second Disconnect is harmless');

   probe := TClusterNoReadProbe.Create;
   try
      CheckTrue(probe.Connect('127.0.0.1', StartServer), 'precondition: connected');
      (* WAIT FOR THE GREETING BEFORE TEARING DOWN. The greeting is written by
        the server's OnConnect, so its arrival proves the server finished
        setting this connection up. Stopping a TIdTCPServer while a connection
        is still in setup can leave Indy's TerminateAllYarns waiting for ever
        (IdScheduler.pas, a 500 ms sleep loop with no timeout) -- this test hung
        one run in twenty that way. *)
      CheckTrue(probe.WaitInboundArrived(3000),
                'precondition: the server has finished setting up the connection');
      CheckTrue(probe.IsConnected, 'precondition: up');

      probe.Disconnect;
      CheckFalse(probe.IsConnected, 'closed after Disconnect');

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

procedure TClusterSocketNoReadTests.Test_NotConnected_SendsNothingAndRaisesNothing;
var
   probe: TClusterNoReadProbe;
begin
   BeginTest('Cluster SendLine and Disconnect with no connection write nothing and raise nothing');

   probe := TClusterNoReadProbe.Create;
   try
      CheckFalse(probe.IsConnected, 'a never-connected client is not connected');

      try
         probe.SendLine(AnsiString(TEST_CMD));
         probe.Disconnect;
         CheckTrue(True, 'no exception from a never-connected send or disconnect');
      except
         on E: Exception do
            begin
            CheckTrue(False, 'a never-connected call raised ' + E.ClassName + ': ' + E.Message);
            end;
      end;
   finally
      probe.Free;
   end;
end;

(* THE IOHANDLER OUTLIVES A FAILED CONNECT.

  Indy's implicit handler is ManagedIOHandler, and TIdTCPClientCustom.Connect
  FREES it when the connect fails (IdTCPClient.pas:338-342).  Connect runs on
  uTelnet's connect thread while the main thread's Disconnect, IsConnected and
  SendLine load FTCP.IOHandler -- a use-after-free on every refused connect.

  Pinned as an INVARIANT rather than by racing threads for a freed pointer:
  after a refused connect a handler still exists, it is not managed, and a
  second refused connect leaves the SAME instance in place. *)
procedure TClusterSocketNoReadTests.Test_FailedConnect_KeepsTheSameIOHandler;
var
   probe: TClusterNoReadProbe;
   before: TIdIOHandler;
   closedPort: Word;
begin
   BeginTest('A failed cluster connect does not free or replace the IOHandler');

   closedPort := ClosedLoopbackPort;

   probe := TClusterNoReadProbe.Create;
   try
      before := probe.Handler;
      CheckTrue(before <> nil, 'the client has its own handler before any connect');
      CheckFalse(probe.HandlerIsManaged, 'and it is not Indy-managed');

      CheckFalse(probe.Connect('127.0.0.1', closedPort), 'precondition: the connect was refused');
      CheckFalse(probe.IsConnected, 'a refused connect is not connected');
      CheckTrue(probe.Handler = before,
                'a failed Connect freed or replaced the IOHandler -- another thread ' +
                'holding FTCP.IOHandler would dereference freed memory');
      CheckFalse(probe.HandlerIsManaged,
                 'the IOHandler is not Indy-managed (a managed one is freed by a failed Connect)');

      CheckFalse(probe.Connect('127.0.0.1', closedPort), 'a second refused connect');
      CheckTrue(probe.Handler = before, 'a second failed Connect kept the same IOHandler');
   finally
      probe.Free;
   end;
end;

(* Reusing the handler is the behaviour to prove WORKS: refused once, then a
  live server, and the link comes up on the same instance and carries a line. *)
procedure TClusterSocketNoReadTests.Test_ConnectAfterFailedConnect_ReusesTheHandler;
var
   probe: TClusterNoReadProbe;
   before: TIdIOHandler;
   closedPort: Word;
begin
   BeginTest('A cluster connect after a failed connect comes up on the same IOHandler');

   closedPort := ClosedLoopbackPort;

   probe := TClusterNoReadProbe.Create;
   try
      before := probe.Handler;
      CheckFalse(probe.Connect('127.0.0.1', closedPort), 'precondition: the first connect was refused');

      CheckTrue(probe.Connect('127.0.0.1', StartServer), 'the reconnect came up');
      CheckTrue(probe.IsConnected, 'and reports connected');
      CheckTrue(probe.Handler = before, 'on the handler the failed connect left behind');

      probe.SendLine(AnsiString(TEST_CMD));
      CheckTrue(WaitForReceived(TEST_CMD, 3000), 'and it carries a line');
   finally
      probe.Free;
      StopServer;
   end;
end;

procedure TClusterSocketNoReadTests.RunAllTests;
begin
   FLock := TCriticalSection.Create;
   FReceived := TStringList.Create;
   try
      Test_IsConnected_DoesNotReadTheSocket;
      Test_SendLine_DoesNotReadTheSocket;
      Test_Disconnect_ClosesAndIsRepeatable;
      Test_NotConnected_SendsNothingAndRaisesNothing;
      Test_FailedConnect_KeepsTheSameIOHandler;
      Test_ConnectAfterFailedConnect_ReusesTheHandler;
   finally
      StopServer;
      FReceived.Free;
      FLock.Free;
   end;
end;

end.
