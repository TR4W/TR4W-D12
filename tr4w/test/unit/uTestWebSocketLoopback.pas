unit uTestWebSocketLoopback;

{
  Drives TR4W's own WebSocket CLIENT against TR4W's own WebSocket SERVER over
  a real loopback socket.

  WHY THIS IS WORTH A REAL SOCKET.  uTestWebSocketFraming proves the framing
  with a memory buffer, which is the right place for the byte-level rules.
  What it cannot prove is that the two TRANSPORTS agree: that the server
  really answers the handshake our client sends, that the reader threads on
  both ends stay aligned across a real TCP stream (where a frame arrives in
  as many segments as the network feels like), and that the session lifecycle
  -- open, broadcast, disconnect -- fires the events the TCI layer above will
  depend on.

  The two ends were written from opposite sides of the RFC, so each is an
  independent check on the other.  A masking or length-form mistake that both
  halves of one implementation shared would still round-trip in a unit test;
  it cannot survive here, because the client masks and the server does not.

  TIMING.  Everything is asynchronous -- Indy's reader threads raise the
  events -- so the assertions poll with a deadline rather than sleeping a
  fixed interval.  A slow machine takes longer; it does not fail.
}

interface

uses
   Windows, SysUtils, Classes, SyncObjs,
   uTR4WTestFramework, uWebSocketFraming, uWebSocketClient, uWebSocketServer;

type
   // Thread-safe sink for messages that arrive on someone else's thread.
   TMessageSink = class(TObject)
   private
      FLock:  TCriticalSection;
      FItems: TStringList;
   public
      constructor Create;
      destructor  Destroy; override;
      procedure Add(const S: string);
      function  Count: integer;
      function  Item(Index: integer): string;
      procedure Clear;
   end;

   TWebSocketLoopbackTests = class(TTestCase)
   private
      FServer:        TWebSocketServer;
      FPort:          integer;
      FServerRx:      TMessageSink;
      FClientRx:      TMessageSink;
      FOpened:        integer;
      FClosed:        integer;
      FLastSession:   TWSServerSession;

      procedure ServerText(Session: TWSServerSession; const Text: string);
      procedure ServerOpened(Session: TWSServerSession);
      procedure ServerClosed(Session: TWSServerSession);
      procedure ClientText(const Text: string);

      // Starts the server on the first free loopback port in a small range.
      function  StartServer: boolean;
      procedure StopServer;
      function  NewClient(out Client: TWebSocketClient): boolean;

      // Polls until Cond is satisfied or the deadline passes.
      function  WaitForSinkCount(Sink: TMessageSink; Want: integer; TimeoutMs: cardinal): boolean;
      function  WaitForSessions(Want: integer; TimeoutMs: cardinal): boolean;
      function  WaitForOpened(Want: integer; TimeoutMs: cardinal): boolean;
      function  WaitForClosed(Want: integer; TimeoutMs: cardinal): boolean;

   protected
      procedure Test_ClientConnectsAndHandshakes;
      procedure Test_ClientToServerText;
      procedure Test_ServerToClientText;
      procedure Test_BroadcastReachesEveryClient;
      procedure Test_LargeMessageAcrossSegments;
      procedure Test_ManyMessagesStayInOrder;
      procedure Test_ClientDisconnectClosesSession;
      procedure Test_PlainHttpGetIsRefused;
      procedure Test_ServerStopDropsClients;

   public
      procedure RunAllTests; override;
   end;

implementation

uses
   IdTCPClient, IdGlobal;

const
   // A small private range; the first one that binds wins, so a developer
   // machine with something already on 55731 still runs the suite.
   PORT_FIRST = 55731;
   PORT_LAST  = 55740;

   // Generous: these are loopback sockets, but a busy build machine can
   // still take a moment to schedule three threads.
   WAIT_MS    = 5000;

{ ------------------------------------------------------------ TMessageSink -- }

constructor TMessageSink.Create;
begin
   inherited Create;
   FLock := TCriticalSection.Create;
   FItems := TStringList.Create;
end;

destructor TMessageSink.Destroy;
begin
   FreeAndNil(FItems);
   FreeAndNil(FLock);
   inherited Destroy;
end;

procedure TMessageSink.Add(const S: string);
begin
   FLock.Enter;
   try
      FItems.Add(S);
   finally
      FLock.Leave;
   end;
end;

function TMessageSink.Count: integer;
begin
   FLock.Enter;
   try
      Result := FItems.Count;
   finally
      FLock.Leave;
   end;
end;

function TMessageSink.Item(Index: integer): string;
begin
   FLock.Enter;
   try
      if (Index >= 0) and (Index < FItems.Count) then
         begin
         Result := FItems[Index];
         end
      else
         begin
         Result := '';
         end;
   finally
      FLock.Leave;
   end;
end;

procedure TMessageSink.Clear;
begin
   FLock.Enter;
   try
      FItems.Clear;
   finally
      FLock.Leave;
   end;
end;

{ ------------------------------------------------- TWebSocketLoopbackTests -- }

procedure TWebSocketLoopbackTests.ServerText(Session: TWSServerSession; const Text: string);
begin
   FServerRx.Add(Text);
end;

procedure TWebSocketLoopbackTests.ServerOpened(Session: TWSServerSession);
begin
   FLastSession := Session;
   InterlockedIncrement(FOpened);
end;

procedure TWebSocketLoopbackTests.ServerClosed(Session: TWSServerSession);
begin
   if FLastSession = Session then
      begin
      FLastSession := nil;
      end;
   InterlockedIncrement(FClosed);
end;

procedure TWebSocketLoopbackTests.ClientText(const Text: string);
begin
   FClientRx.Add(Text);
end;

function TWebSocketLoopbackTests.StartServer: boolean;
var
   p: integer;
begin
   FServerRx := TMessageSink.Create;
   FClientRx := TMessageSink.Create;
   FOpened := 0;
   FClosed := 0;
   FLastSession := nil;

   FServer := TWebSocketServer.Create;
   FServer.OnTextMessage := ServerText;
   FServer.OnSessionOpened := ServerOpened;
   FServer.OnSessionClosed := ServerClosed;

   Result := False;
   for p := PORT_FIRST to PORT_LAST do
      begin
      if FServer.Start(p, False) then
         begin
         FPort := p;
         Result := True;
         Exit;
         end;
      end;
end;

procedure TWebSocketLoopbackTests.StopServer;
begin
   if Assigned(FServer) then
      begin
      FServer.Stop;
      FreeAndNil(FServer);
      end;
   FreeAndNil(FServerRx);
   FreeAndNil(FClientRx);
end;

function TWebSocketLoopbackTests.NewClient(out Client: TWebSocketClient): boolean;
begin
   Client := TWebSocketClient.Create;
   Client.OnTextMessage := ClientText;
   Result := Client.Connect('127.0.0.1', FPort, '/');
   if not Result then
      begin
      FreeAndNil(Client);
      end;
end;

function TWebSocketLoopbackTests.WaitForSinkCount(Sink: TMessageSink; Want: integer;
                                                  TimeoutMs: cardinal): boolean;
var
   deadline: cardinal;
begin
   deadline := GetTickCount + TimeoutMs;
   while GetTickCount < deadline do
      begin
      if Sink.Count >= Want then
         begin
         Result := True;
         Exit;
         end;
      Sleep(10);
      end;
   Result := Sink.Count >= Want;
end;

function TWebSocketLoopbackTests.WaitForSessions(Want: integer; TimeoutMs: cardinal): boolean;
var
   deadline: cardinal;
begin
   deadline := GetTickCount + TimeoutMs;
   while GetTickCount < deadline do
      begin
      if FServer.SessionCount = Want then
         begin
         Result := True;
         Exit;
         end;
      Sleep(10);
      end;
   Result := FServer.SessionCount = Want;
end;

function TWebSocketLoopbackTests.WaitForOpened(Want: integer; TimeoutMs: cardinal): boolean;
var
   deadline: cardinal;
begin
   deadline := GetTickCount + TimeoutMs;
   while GetTickCount < deadline do
      begin
      if FOpened >= Want then
         begin
         Result := True;
         Exit;
         end;
      Sleep(10);
      end;
   Result := FOpened >= Want;
end;

function TWebSocketLoopbackTests.WaitForClosed(Want: integer; TimeoutMs: cardinal): boolean;
var
   deadline: cardinal;
begin
   deadline := GetTickCount + TimeoutMs;
   while GetTickCount < deadline do
      begin
      if FClosed >= Want then
         begin
         Result := True;
         Exit;
         end;
      Sleep(10);
      end;
   Result := FClosed >= Want;
end;

{ -------------------------------------------------------------- the tests -- }

procedure TWebSocketLoopbackTests.Test_ClientConnectsAndHandshakes;
var
   c: TWebSocketClient;
begin
   BeginTest('Test_ClientConnectsAndHandshakes');
   if not StartServer then
      begin
      Check(False, 'no free loopback port in the test range');
      Exit;
      end;
   try
      // Connect returns True only when the server answered 101 AND the
      // Sec-WebSocket-Accept digest verified, so this one assertion covers
      // the whole handshake in both directions.
      CheckTrue(NewClient(c), 'client handshake with our own server');
      try
         CheckTrue(WaitForOpened(1, WAIT_MS), 'OnSessionOpened fired');
         CheckTrue(WaitForSessions(1, WAIT_MS), 'the server counts one session');
      finally
         c.Free;
      end;
   finally
      StopServer;
   end;
end;

procedure TWebSocketLoopbackTests.Test_ClientToServerText;
var
   c: TWebSocketClient;
begin
   BeginTest('Test_ClientToServerText');
   if not StartServer then
      begin
      Check(False, 'no free loopback port');
      Exit;
      end;
   try
      CheckTrue(NewClient(c), 'connected');
      try
         WaitForOpened(1, WAIT_MS);
         // The client masks; the server has to unmask to see this at all.
         c.SendText('trx:0,true;');
         CheckTrue(WaitForSinkCount(FServerRx, 1, WAIT_MS), 'the server received a message');
         CheckEquals('trx:0,true;', FServerRx.Item(0), 'unmasked back to the original text');
      finally
         c.Free;
      end;
   finally
      StopServer;
   end;
end;

procedure TWebSocketLoopbackTests.Test_ServerToClientText;
var
   c: TWebSocketClient;
begin
   BeginTest('Test_ServerToClientText');
   if not StartServer then
      begin
      Check(False, 'no free loopback port');
      Exit;
      end;
   try
      CheckTrue(NewClient(c), 'connected');
      try
         CheckTrue(WaitForOpened(1, WAIT_MS), 'session opened');
         CheckTrue(FLastSession <> nil, 'the opened session was handed to us');
         if FLastSession <> nil then
            begin
            // The server must NOT mask.  A client that received a masked
            // frame would treat it as a fatal protocol violation, so this
            // arriving at all is the assertion.
            FLastSession.SendText('vfo:0,0,14025000;');
            CheckTrue(WaitForSinkCount(FClientRx, 1, WAIT_MS), 'the client received it');
            CheckEquals('vfo:0,0,14025000;', FClientRx.Item(0), '');
            end;
      finally
         c.Free;
      end;
   finally
      StopServer;
   end;
end;

procedure TWebSocketLoopbackTests.Test_BroadcastReachesEveryClient;
var
   c1, c2: TWebSocketClient;
begin
   BeginTest('Test_BroadcastReachesEveryClient');
   if not StartServer then
      begin
      Check(False, 'no free loopback port');
      Exit;
      end;
   c1 := nil;
   c2 := nil;
   try
      CheckTrue(NewClient(c1), 'first client');
      CheckTrue(NewClient(c2), 'second client');
      CheckTrue(WaitForOpened(2, WAIT_MS), 'both sessions opened');
      CheckEquals(2, FServer.SessionCount, 'two live sessions');

      // TCI is a broadcast protocol: a change one client makes has to reach
      // the others, which is the whole reason the server keeps a session list.
      FServer.Broadcast('modulation:0,cw;');
      CheckTrue(WaitForSinkCount(FClientRx, 2, WAIT_MS), 'both clients received the broadcast');
      CheckEquals('modulation:0,cw;', FClientRx.Item(0), '');
      CheckEquals('modulation:0,cw;', FClientRx.Item(1), '');
   finally
      c1.Free;
      c2.Free;
      StopServer;
   end;
end;

procedure TWebSocketLoopbackTests.Test_LargeMessageAcrossSegments;
var
   c:   TWebSocketClient;
   big: string;
   i:   integer;
begin
   BeginTest('Test_LargeMessageAcrossSegments');
   if not StartServer then
      begin
      Check(False, 'no free loopback port');
      Exit;
      end;
   try
      CheckTrue(NewClient(c), 'connected');
      try
         WaitForOpened(1, WAIT_MS);
         // Past 125 bytes the 16-bit length form kicks in, and past the MTU
         // the payload arrives in several TCP segments -- which is exactly
         // the case a naive "read what is available" reader gets wrong.
         big := '';
         for i := 1 to 400 do
            begin
            big := big + 'abcdefghij';    // 4000 characters
            end;
         c.SendText(big);
         CheckTrue(WaitForSinkCount(FServerRx, 1, WAIT_MS), 'a 4000-byte message arrived');
         CheckEquals(4000, Length(FServerRx.Item(0)), 'whole, not truncated at a segment boundary');
         CheckEquals(big, FServerRx.Item(0), 'and byte-identical');
      finally
         c.Free;
      end;
   finally
      StopServer;
   end;
end;

procedure TWebSocketLoopbackTests.Test_ManyMessagesStayInOrder;
var
   c: TWebSocketClient;
   i: integer;
   ok: boolean;
begin
   BeginTest('Test_ManyMessagesStayInOrder');
   if not StartServer then
      begin
      Check(False, 'no free loopback port');
      Exit;
      end;
   try
      CheckTrue(NewClient(c), 'connected');
      try
         CheckTrue(WaitForOpened(1, WAIT_MS), 'session opened');
         if FLastSession <> nil then
            begin
            // TCI's init burst is ~30 commands sent back to back, and a
            // client that latches on 'ready;' depends on ORDER.  The sender
            // thread must not reorder or coalesce them.
            for i := 0 to 49 do
               begin
               FLastSession.SendText(Format('msg:%d;', [i]));
               end;
            CheckTrue(WaitForSinkCount(FClientRx, 50, WAIT_MS), 'all 50 arrived');
            ok := True;
            for i := 0 to 49 do
               begin
               if FClientRx.Item(i) <> Format('msg:%d;', [i]) then
                  begin
                  ok := False;
                  Check(False, Format('message %d is "%s"', [i, FClientRx.Item(i)]));
                  Break;
                  end;
               end;
            if ok then
               begin
               Check(True, 'order preserved across 50 messages');
               end;
            end;
      finally
         c.Free;
      end;
   finally
      StopServer;
   end;
end;

procedure TWebSocketLoopbackTests.Test_ClientDisconnectClosesSession;
var
   c: TWebSocketClient;
begin
   BeginTest('Test_ClientDisconnectClosesSession');
   if not StartServer then
      begin
      Check(False, 'no free loopback port');
      Exit;
      end;
   try
      CheckTrue(NewClient(c), 'connected');
      WaitForOpened(1, WAIT_MS);
      // The TCI server unkeys PTT in OnSessionClosed, so a disconnect that
      // does not fire it would leave a transmitter keyed with nobody
      // holding it.  This is the failure-closed path.
      c.Free;
      CheckTrue(WaitForClosed(1, WAIT_MS), 'OnSessionClosed fired on disconnect');
      CheckTrue(WaitForSessions(0, WAIT_MS), 'the session was removed from the list');
   finally
      StopServer;
   end;
end;

procedure TWebSocketLoopbackTests.Test_PlainHttpGetIsRefused;
var
   raw:    TIdTCPClient;
   status: string;
begin
   BeginTest('Test_PlainHttpGetIsRefused');
   if not StartServer then
      begin
      Check(False, 'no free loopback port');
      Exit;
      end;
   try
      // A browser (or a port scanner) hitting the port must get a clean 400,
      // not a half-open session that the server then treats as a client.
      raw := TIdTCPClient.Create(nil);
      try
         raw.Host := '127.0.0.1';
         raw.Port := FPort;
         raw.ConnectTimeout := 5000;
         raw.ReadTimeout := 5000;
         raw.Connect;
         raw.IOHandler.Write('GET / HTTP/1.1'#13#10'Host: 127.0.0.1'#13#10#13#10);
         status := raw.IOHandler.ReadLn;
         CheckTrue(Pos('400', status) > 0,
                   'a request without an Upgrade header is refused: ' + status);
         raw.Disconnect;
      finally
         raw.Free;
      end;
      CheckTrue(WaitForSessions(0, WAIT_MS), 'no session survives a refused handshake');
   finally
      StopServer;
   end;
end;

procedure TWebSocketLoopbackTests.Test_ServerStopDropsClients;
var
   c: TWebSocketClient;
begin
   BeginTest('Test_ServerStopDropsClients');
   if not StartServer then
      begin
      Check(False, 'no free loopback port');
      Exit;
      end;
   c := nil;
   try
      CheckTrue(NewClient(c), 'connected');
      WaitForOpened(1, WAIT_MS);
      // Stopping has to tear every session down cleanly -- this is what runs
      // when the operator switches the server off in Preferences, and a leak
      // or a hang here would show up as TR4W refusing to close.
      FServer.Stop;
      CheckTrue(WaitForClosed(1, WAIT_MS), 'stopping the server closes its sessions');
      CheckFalse(FServer.Active, 'and the server reports itself inactive');
   finally
      c.Free;
      StopServer;
   end;
end;

procedure TWebSocketLoopbackTests.RunAllTests;
begin
   Test_ClientConnectsAndHandshakes;
   Test_ClientToServerText;
   Test_ServerToClientText;
   Test_BroadcastReachesEveryClient;
   Test_LargeMessageAcrossSegments;
   Test_ManyMessagesStayInOrder;
   Test_ClientDisconnectClosesSession;
   Test_PlainHttpGetIsRefused;
   Test_ServerStopDropsClients;
end;

end.
