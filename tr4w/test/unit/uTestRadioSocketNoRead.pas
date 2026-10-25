unit uTestRadioSocketNoRead;
{$I ..\..\src\tr4w.inc}

(*
  PINS ONE RULE: ONLY THE READING THREAD READS A NETWORK RADIO'S SOCKET.

  The defect (2026-10-25, NY4I, Elecraft K4 on the network at AI5).  A band-map
  double-click hung the main thread for good.  The process dump's stack, top
  first:

     ws2_32!recv
     TIdIOHandler.ReadFromSource
     TIdIOHandlerStack.Connected        <- Indy's "are we connected" READS
     TIdTCPConnection.Connected
     TFactoryRadioBase.SendToRadio      <- was: else if socket.Connected then
     TK4Radio.SetFrequency
     ... uBandmap.TuneRadioToSpot / TfrmBandMap.SpotsDblClick

  TIdIOHandlerStack.Connected calls ReadFromSource(False, 0, False): a
  zero-timeout select and then a BLOCKING recv.  The radio's reading thread
  reads the same socket concurrently.  When the select said "readable" and the
  reading thread took the bytes first, the main thread's recv waited for more,
  for ever.  Rare, and data-timing dependent.

  WHY THESE TESTS DO NOT RACE TWO THREADS.  The race needs the reading thread to
  win a window a few microseconds wide; a test that tried to provoke it would be
  flaky in both directions.  So they pin the INVARIANT instead, and the
  invariant is directly observable: there is NO reading thread here (the probe
  connects the socket without OnConnected, which is what starts one), the
  fixture server sends a line first, and the test waits until those bytes are
  sitting in the kernel buffer.  Anything that then reads the socket moves them
  into Indy's InputBuffer.  So "InputBuffer still empty after SendToRadio" is
  exactly "SendToRadio did not read" -- deterministic, no sleeps on the
  assertion.

  Run against the pre-fix SendToRadio / SocketIsConnected (both called
  socket.Connected) the two *_DoesNotReadTheSocket tests FAIL: the greeting is
  found in the InputBuffer.  The other two pin the not-connected half: sending
  then writes nothing and raises nothing.
*)

interface

uses
   SysUtils, Classes, SyncObjs, IdTCPServer, IdContext, IdGlobal, IdIOHandler,
   uTR4WTestFramework, uFactoryRadioBase, uRadioElecraftK4;

type
   (* A real TK4Radio, so SetFrequency and SendToRadio are the shipped code.
     It reaches the protected socket through the same door any descendant
     has.  It never starts a reading thread -- see the unit header. *)
   TSocketNoReadProbe = class(TK4Radio)
   public
      procedure AttachWithoutReader(const AHost: string; APort: Integer);
      procedure HangUpLocally;
      function  BufferedInbound: Integer;
      function  WaitInboundArrived(AMs: Integer): Boolean;
   end;

   TRadioSocketNoReadTests = class(TTestCase)
   private
      FServer:   TIdTCPServer;
      FLock:     TCriticalSection;
      FReceived: TStringList;      // lines the fixture server heard (server thread)
      FHangUp:   Boolean;          // set by a test: the server closes its end
      procedure ServerConnect(AContext: TIdContext);
      procedure ServerExecute(AContext: TIdContext);
      function  StartServer: Word;
      procedure StopServer;
      function  ReceivedCount: Integer;
      function  WaitForReceived(const ALine: string; ATimeoutMs: Integer): Boolean;
   protected
      procedure Test_SendToRadio_DoesNotReadTheSocket;
      procedure Test_IsConnected_DoesNotReadTheSocket;
      procedure Test_SendToRadio_NotConnected_WritesNothingAndDoesNotRaise;
      procedure Test_SendToRadio_AfterPeerHangsUp_DoesNotRaise;
   public
      procedure RunAllTests; override;
   end;

implementation

(* RELEASE A PROBE THROUGH THE DESTRUCTOR THAT ACTUALLY TEARS IT DOWN.

  NOT probe.Free, and the reason is a defect, reported and NOT fixed here:
  TFactoryRadioBase declares `Destructor Destroy; overload; Virtual;` -- a NEW
  virtual slot that HIDES TObject.Destroy (the compiler says so, every build:
  "An inherited method is hidden by destructor Destroy").  TObject.Free calls
  TObject's slot, so Free runs NO radio destructor at all -- verified with a
  six-line FPC program.  Every connected probe then leaked its TIdTCPClient,
  IOHandler and binding (104 heaptrc blocks over the -Checked ceiling).

  Calling Destroy through the radio's own static type reaches the radio's
  slot, so the real teardown runs.  When the base destructor becomes
  `override`, this becomes probe.Free and nothing else changes. *)
procedure ReleaseProbe(var probe: TSocketNoReadProbe);
begin
   if probe <> nil then
      begin
      probe.Destroy;
      probe := nil;
      end;
end;

const
   (* What the fixture "radio" says first, unprompted -- an AI5 push.  Its only
     job is to be sitting unread on the socket when SendToRadio runs. *)
   GREETING = 'FA00014000000;';
   TUNE_HZ  = 14208700;
   TUNE_CMD = 'FA00014208700;';

(* ---- probe ---------------------------------------------------------------- *)

procedure TSocketNoReadProbe.AttachWithoutReader(const AHost: string; APort: Integer);
begin
   (* OnConnected is what creates the reading thread.  Without it the test's
     own thread is the only party that could read -- so any read is the
     code under test's. *)
   socket.OnConnected := nil;
   socket.Host := AHost;
   socket.Port := APort;
   socket.ConnectTimeout := 3000;
   socket.Connect;
end;

procedure TSocketNoReadProbe.HangUpLocally;
begin
   socket.Disconnect(False);
end;

function TSocketNoReadProbe.BufferedInbound: Integer;
begin
   Result := 0;

   if socket.IOHandler <> nil then
      begin
      Result := socket.IOHandler.InputBuffer.Size;
      end;
end;

(* Readable is a select and nothing else (TIdIOHandlerStack.Readable ->
  Binding.Readable) -- it waits for the bytes WITHOUT taking them. *)
function TSocketNoReadProbe.WaitInboundArrived(AMs: Integer): Boolean;
begin
   Result := (socket.IOHandler <> nil) and socket.IOHandler.Readable(AMs);
end;

(* ---- fixture server (its own threads) ------------------------------------- *)

procedure TRadioSocketNoReadTests.ServerConnect(AContext: TIdContext);
begin
   AContext.Connection.IOHandler.Write(GREETING, IndyTextEncoding_8Bit);
end;

procedure TRadioSocketNoReadTests.ServerExecute(AContext: TIdContext);
var
   line: string;
begin
   if FHangUp then
      begin
      AContext.Connection.Disconnect;
      Exit;
      end;

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

function TRadioSocketNoReadTests.StartServer: Word;
begin
   FHangUp := False;
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

procedure TRadioSocketNoReadTests.StopServer;
begin
   if FServer <> nil then
      begin
      FServer.Active := False;
      FreeAndNil(FServer);
      end;
end;

function TRadioSocketNoReadTests.ReceivedCount: Integer;
begin
   FLock.Enter;
   try
      Result := FReceived.Count;
   finally
      FLock.Leave;
   end;
end;

function TRadioSocketNoReadTests.WaitForReceived(const ALine: string; ATimeoutMs: Integer): Boolean;
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

procedure TRadioSocketNoReadTests.Test_SendToRadio_DoesNotReadTheSocket;
var
   probe: TSocketNoReadProbe;
begin
   BeginTest('SendToRadio on a connected network radio does not read the socket');

   probe := TSocketNoReadProbe.Create;
   try
      probe.AttachWithoutReader('127.0.0.1', StartServer);

      CheckTrue(probe.WaitInboundArrived(3000),
                'precondition: the radio''s unsolicited line is waiting on the socket');
      CheckEquals(0, probe.BufferedInbound,
                  'precondition: nothing has read it yet');

      (* The exact call the hung stack made. *)
      probe.SetFrequency(TUNE_HZ, nrVFOA, rmCW);

      CheckEquals(0, probe.BufferedInbound,
                  'SendToRadio READ the socket -- Indy''s Connected does a recv, and ' +
                  'off the reading thread that recv can block for ever (2026-10-25 hang)');
      CheckTrue(WaitForReceived(TUNE_CMD, 3000),
                'the frequency command still reached the radio');
   finally
      ReleaseProbe(probe);
      StopServer;
   end;
end;

procedure TRadioSocketNoReadTests.Test_IsConnected_DoesNotReadTheSocket;
var
   probe: TSocketNoReadProbe;
begin
   BeginTest('IsConnected on a connected network radio does not read the socket');

   probe := TSocketNoReadProbe.Create;
   try
      probe.AttachWithoutReader('127.0.0.1', StartServer);

      CheckTrue(probe.WaitInboundArrived(3000),
                'precondition: the radio''s unsolicited line is waiting on the socket');

      (* The polling thread and LOGRADIO (main thread) both ask this. *)
      CheckTrue(probe.IsConnected, 'an open socket reports connected');

      CheckEquals(0, probe.BufferedInbound,
                  'IsConnected READ the socket -- it is called off the reading thread');
   finally
      ReleaseProbe(probe);
      StopServer;
   end;
end;

procedure TRadioSocketNoReadTests.Test_SendToRadio_NotConnected_WritesNothingAndDoesNotRaise;
var
   neverConnected: TSocketNoReadProbe;
   closed: TSocketNoReadProbe;
   heardBefore: Integer;
begin
   BeginTest('SendToRadio with no connection writes nothing and raises nothing');

   (* A radio switched off at startup: Indy has not even made an IOHandler. *)
   neverConnected := TSocketNoReadProbe.Create;
   try
      CheckFalse(neverConnected.IsConnected, 'a never-connected radio is not connected');
      try
         neverConnected.SendToRadio(TUNE_CMD);
         CheckTrue(True, 'no exception from a never-connected send');
      except
         on E: Exception do
            begin
            CheckTrue(False, 'a never-connected send raised ' + E.ClassName + ': ' + E.Message);
            end;
      end;
   finally
      ReleaseProbe(neverConnected);
   end;

   (* A link we closed ourselves. *)
   closed := TSocketNoReadProbe.Create;
   try
      closed.AttachWithoutReader('127.0.0.1', StartServer);
      closed.HangUpLocally;

      CheckFalse(closed.IsConnected, 'a closed link is not connected');

      heardBefore := ReceivedCount;
      try
         closed.SendToRadio(TUNE_CMD);
         CheckTrue(True, 'no exception from a send on a closed link');
      except
         on E: Exception do
            begin
            CheckTrue(False, 'a send on a closed link raised ' + E.ClassName + ': ' + E.Message);
            end;
      end;

      CheckFalse(WaitForReceived(TUNE_CMD, 300), 'nothing was written on a closed link');
      CheckEquals(heardBefore, ReceivedCount, 'the server heard nothing new');
   finally
      ReleaseProbe(closed);
      StopServer;
   end;
end;

procedure TRadioSocketNoReadTests.Test_SendToRadio_AfterPeerHangsUp_DoesNotRaise;
var
   probe: TSocketNoReadProbe;
   i: Integer;
begin
   BeginTest('SendToRadio after the radio hangs up raises nothing');

   (* With no reading thread nobody has READ the close, so the field check
     still says open and the write is attempted -- the gap the reading thread
     closes in production by setting Disconnecting.  A write into a dead
     socket raises inside Indy; SendToRadio must contain it. *)
   probe := TSocketNoReadProbe.Create;
   try
      probe.AttachWithoutReader('127.0.0.1', StartServer);
      FHangUp := True;
      Sleep(300);       // let the server thread act on it

      try
         for i := 1 to 3 do
            begin
            probe.SendToRadio(TUNE_CMD);
            Sleep(50);
            end;
         CheckTrue(True, 'no exception from sends into a hung-up link');
      except
         on E: Exception do
            begin
            CheckTrue(False, 'a send into a hung-up link raised ' + E.ClassName + ': ' + E.Message);
            end;
      end;
   finally
      ReleaseProbe(probe);
      StopServer;
   end;
end;

procedure TRadioSocketNoReadTests.RunAllTests;
begin
   FLock := TCriticalSection.Create;
   FReceived := TStringList.Create;
   try
      Test_SendToRadio_DoesNotReadTheSocket;
      Test_IsConnected_DoesNotReadTheSocket;
      Test_SendToRadio_NotConnected_WritesNothingAndDoesNotRaise;
      Test_SendToRadio_AfterPeerHangsUp_DoesNotRaise;
   finally
      StopServer;
      FReceived.Free;
      FLock.Free;
   end;
end;

end.
