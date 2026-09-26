unit uTestIcomTeardown;
{$I ..\..\src\tr4w.inc}

(*
  PINS THE ICOM NETWORK TRANSPORT'S TEARDOWN OWNERSHIP INVARIANT:

      A DISCONNECT THAT ORIGINATES ON AN INDY LISTENER THREAD MUST STILL
      COMPLETE -- SOCKETS FREED, LISTENER THREADS JOINED, THE RADIO TOLD.

  WHY IT TAKES A FAKE RADIO RATHER THAN A MOCK.  The defect this pins is not a
  wrong value, it is WHICH THREAD runs a routine, and that fact comes from
  TIdUDPServer.ThreadedEvent plus the OnUDPRead assignment in CreateSockets.
  Nothing reachable from outside the unit can stand in for it: the handlers, the
  sockets and the request flag are all private.  So the test brings up a real
  TIdUDPServer on the loopback interface, lets the transport handshake with it,
  and then does the one thing the radio does that used to wedge TR4W -- it sends
  an unsolicited $0005 Disconnect.

  Loopback ONLY, deliberately.  Windows Firewall does not filter the loopback
  interface, so this needs no rule and cannot raise a prompt on a CI runner.

  WHAT THE ASSERTIONS ACTUALLY PROVE, AND WHY THEY ARE IN THIS ORDER.

    * icsDisconnected is set at the END of Disconnect, AFTER DestroySockets
      returns.  So observing it proves the whole teardown ran, not merely that
      somebody assigned a state -- which matters here more than anywhere,
      because "the state says Disconnected while a bound socket and a live
      listener thread are still running" IS the 2026-09-24 IC-9700 defect.

    * the fake radio must RECEIVE a $0005 from the transport.  That send sits
      past Disconnect's resource guard, so receiving it proves the guard let the
      teardown through.  Over the whole 2026-09-24 bench log there were 14
      Disconnect calls and exactly ONE $0005: the radio went on servicing
      sessions TR4W had abandoned and refused the next handshake for ~90 s.

  HOW IT FAILS AGAINST THE DEFECT.  With the teardown performed inline on the
  listener thread, Socket.Active := False joins that listener -- from the
  listener -- so Disconnect never returns, the state is never set, and this test
  fails on its timeout.  It does NOT hang the suite: a transport that is wedged
  cannot be freed either, so the timeout path deliberately LEAKS it rather than
  blocking the run in a destructor for ever.  Said out loud because leaking in a
  test is normally wrong.

  WHAT IS NOT COVERED.  The destructor's answer to an outstanding request -- a
  reader thread asking for teardown after the timer thread has been joined and
  freed -- cannot be provoked from outside the unit: the window is inside
  Destroy.  That path is argued in the comment on Disconnect in the destructor
  and is what Lint-IcomTeardownOwner exists to keep honest.
*)

interface

uses
   SysUtils,
   SyncObjs,
   IdUDPServer,
   IdUDPBase,
   IdSocketHandle,
   IdGlobal,
   uTR4WTestFramework,
   uIcomNetworkTypes,
   uIcomNetworkTransport;

type
   (* A RADIO THAT ANSWERS EXACTLY TWICE: "I Am Here", then "Disconnect".

     It holds no protocol state of its own.  Everything it records is written on
     its own Indy listener thread and read on the test's thread, so a lock
     covers all of it -- including the peer address, which is a managed string
     and therefore not safe to assign across threads unguarded. *)
   TFakeIcomRadio = class(TObject)
   private
      FServer:       TIdUDPServer;
      FLock:         TCriticalSection;
      FPeerIP:       string;
      FPeerPort:     Word;
      FTransportId:  LongWord;
      FSawAYT:       Boolean;
      FDisconnects:  Integer;
      procedure DoRead(AThread: TIdUDPListenerThread; const AData: TIdBytes;
                       ABinding: TIdSocketHandle);
      procedure SendControl(PktType: Word; SentID, RcvdID: LongWord);
   public
      constructor Create;
      destructor Destroy; override;
      function  Port: Word;
      function  SawAreYouThere: Boolean;
      function  DisconnectsReceived: Integer;
      procedure ReplyIAmHere;
      procedure SendDisconnect;
   end;

   TIcomTeardownTests = class(TTestCase)
   protected
      procedure Test_RadioDisconnectTearsTheTransportDown;
      procedure Test_FreeWithoutConnectingIsClean;
   public
      procedure RunAllTests; override;
   end;

implementation

const
   FAKE_RADIO_ID = $A1B2C3D4;   (* any non-zero id; the transport only echoes it *)

// ============================================================================
// TFakeIcomRadio
// ============================================================================

constructor TFakeIcomRadio.Create;
var
   binding: TIdSocketHandle;
begin
   inherited Create;

   FLock := TCriticalSection.Create;

   FServer := TIdUDPServer.Create(nil);
   FServer.ThreadedEvent := True;
   FServer.OnUDPRead := DoRead;

   binding := FServer.Bindings.Add;
   binding.IP := '127.0.0.1';
   binding.Port := 0;             (* the OS picks one; we read it back below *)

   FServer.Active := True;
end;

destructor TFakeIcomRadio.Destroy;
begin
   if FServer <> nil then
      begin
      try
         FServer.Active := False;
      except
         (* A fake radio failing to shut down must not mask the test result. *)
      end;
      FreeAndNil(FServer);
      end;

   FreeAndNil(FLock);
   inherited Destroy;
end;

function TFakeIcomRadio.Port: Word;
begin
   Result := FServer.Bindings[0].Port;
end;

procedure TFakeIcomRadio.DoRead(AThread: TIdUDPListenerThread;
                                const AData: TIdBytes; ABinding: TIdSocketHandle);
var
   pkt: TControlPacket;
begin
   if Length(AData) < SizeOf(TControlPacket) then
      begin
      Exit;
      end;

   Move(AData[0], pkt, SizeOf(TControlPacket));

   FLock.Enter;
   try
      FPeerIP   := ABinding.PeerIP;
      FPeerPort := ABinding.PeerPort;

      case pkt.PktType of
        ICOM_PKT_ARE_YOU_THERE:
           begin
           FSawAYT      := True;
           FTransportId := pkt.SentID;
           end;
        ICOM_PKT_DISCONNECT:
           begin
           Inc(FDisconnects);
           end;
      end;
   finally
      FLock.Leave;
   end;
end;

function TFakeIcomRadio.SawAreYouThere: Boolean;
begin
   FLock.Enter;
   try
      Result := FSawAYT;
   finally
      FLock.Leave;
   end;
end;

function TFakeIcomRadio.DisconnectsReceived: Integer;
begin
   FLock.Enter;
   try
      Result := FDisconnects;
   finally
      FLock.Leave;
   end;
end;

(* ONE SEND PATH, so the two replies cannot drift in how they are framed. *)
procedure TFakeIcomRadio.SendControl(PktType: Word; SentID, RcvdID: LongWord);
var
   pkt:  TControlPacket;
   host: string;
   port: Word;
begin
   FLock.Enter;
   try
      host := FPeerIP;
      port := FPeerPort;
   finally
      FLock.Leave;
   end;

   if (host = '') or (port = 0) then
      begin
      Exit;
      end;

   FillChar(pkt, SizeOf(pkt), 0);
   pkt.Len     := SizeOf(TControlPacket);
   pkt.PktType := PktType;
   pkt.Seq     := 0;
   pkt.SentID  := SentID;
   pkt.RcvdID  := RcvdID;

   FServer.SendBuffer(host, port, RawToBytes(pkt, SizeOf(pkt)));
end;

procedure TFakeIcomRadio.ReplyIAmHere;
var
   theirId: LongWord;
begin
   FLock.Enter;
   try
      theirId := FTransportId;
   finally
      FLock.Leave;
   end;

   SendControl(ICOM_PKT_I_AM_HERE, FAKE_RADIO_ID, theirId);
end;

procedure TFakeIcomRadio.SendDisconnect;
begin
   SendControl(ICOM_PKT_DISCONNECT, FAKE_RADIO_ID, 0);
end;

// ============================================================================
// The tests
// ============================================================================

(* Polling rather than an event, because what is being waited for is a state a
  BACKGROUND thread reaches; there is no event to wait on and inventing one
  would mean adding production API for a test. *)
function WaitForState(transport: TIcomNetworkTransport;
                      wanted: TIcomConnectionState;
                      timeoutMs: integer): Boolean;
var
   waited: integer;
begin
   waited := 0;
   while (transport.State <> wanted) and (waited < timeoutMs) do
      begin
      Sleep(10);
      Inc(waited, 10);
      end;

   Result := transport.State = wanted;
end;

function WaitForAYT(radio: TFakeIcomRadio; timeoutMs: integer): Boolean;
var
   waited: integer;
begin
   waited := 0;
   while (not radio.SawAreYouThere) and (waited < timeoutMs) do
      begin
      Sleep(10);
      Inc(waited, 10);
      end;

   Result := radio.SawAreYouThere;
end;

procedure TIcomTeardownTests.Test_RadioDisconnectTearsTheTransportDown;
var
   radio:     TFakeIcomRadio;
   transport: TIcomNetworkTransport;
   tornDown:  Boolean;
begin
   BeginTest('Test_RadioDisconnectTearsTheTransportDown');

   radio     := nil;
   transport := nil;
   tornDown  := False;
   try
      radio := TFakeIcomRadio.Create;

      transport := TIcomNetworkTransport.Create;
      transport.Connect('127.0.0.1', radio.Port, 'tr4wtest', 'tr4wtest');

      Check(WaitForAYT(radio, 3000),
            'the transport never sent Are You There to the fake radio -- ' +
            'loopback UDP is not working, so this test can prove nothing');

      (* Answering carries the session id the transport needs before it will
        send a disconnect of its own, which is the second assertion below. *)
      radio.ReplyIAmHere;
      Check(WaitForState(transport, icsWaitingForReady, 3000),
            'the transport did not accept I Am Here; the fake handshake is ' +
            'wrong, not the teardown');

      (* THE DEFECT, EXACTLY AS THE RADIO PRODUCES IT.  This arrives on the
        control socket's Indy listener thread. *)
      radio.SendDisconnect;

      tornDown := WaitForState(transport, icsDisconnected, 5000);
      Check(tornDown,
            'a $0005 Disconnect from the radio did not tear the transport ' +
            'down within 5 s.  icsDisconnected is set after DestroySockets ' +
            'returns, so this means the teardown never completed -- the ' +
            'classic cause is performing it on the listener thread, which ' +
            'joins itself while holding FLifecycleLock');

      Check(radio.DisconnectsReceived > 0,
            'the transport never told the radio it was leaving.  The $0005 ' +
            'send sits past Disconnect''s resource guard, so this is the ' +
            'guard refusing a teardown that still owned a socket');
   finally
      (* A WEDGED TRANSPORT IS DELIBERATELY LEAKED.  Freeing it calls
        Disconnect, which would block on the very lock the wedge is holding,
        and a test suite that hangs reports nothing at all.  The assertions
        above have already failed by this point. *)
      if tornDown then
         begin
         FreeAndNil(transport);
         end;

      FreeAndNil(radio);
   end;
end;

(* The cheap half of the same lifetime: a transport that never connected owns a
  running timer thread and nothing else, and must still destruct.  This is what
  breaks first if the timer thread ever stops being joined before the sockets
  it can touch are freed. *)
procedure TIcomTeardownTests.Test_FreeWithoutConnectingIsClean;
var
   transport: TIcomNetworkTransport;
begin
   BeginTest('Test_FreeWithoutConnectingIsClean');

   transport := TIcomNetworkTransport.Create;
   try
      Check(transport.State = icsDisconnected,
            'a fresh transport should report Disconnected');

      (* Idempotent on resources: there are none, so this must return at once. *)
      transport.Disconnect;
      Check(transport.State = icsDisconnected,
            'Disconnect on a fresh transport changed its state');
   finally
      FreeAndNil(transport);
   end;

   Check(True, 'the transport destructed without blocking');
end;

procedure TIcomTeardownTests.RunAllTests;
begin
   Test_FreeWithoutConnectingIsClean;
   Test_RadioDisconnectTearsTheTransportDown;
end;

initialization
   RegisterSuite(TIcomTeardownTests.Create('IcomTeardown'));

end.
