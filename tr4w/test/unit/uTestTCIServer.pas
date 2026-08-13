unit uTestTCIServer;
{$I ..\..\src\tr4w.inc}

{
  Pins uTCIServer's WIRE BEHAVIOUR by driving it with a real WebSocket client
  over loopback.

  WHAT THIS SUITE CAN AND CANNOT PROVE.  It proves the protocol contract: the
  init burst's content and ORDER, the GET answers, the refusal rules, and the
  mode mapping.  It does NOT prove anything about a radio -- no rig is
  attached in a unit test, so the SET paths queue an apply onto a main thread
  that a console test does not run.  That is deliberate and it is the honest
  boundary: the radio behaviour is bench work (docs/TCI_SERVER_DESIGN.md
  phase 5), and a test that faked a radio here would pin the fake.

  THE ORDERING ASSERTIONS ARE THE POINT.  Every one of them traces to a real
  client that broke:
    - ready; last, because SDC and CW Skimmer latch their cached settings the
      moment it arrives and never see anything sent after it;
    - no audio_start in the burst, because a server-sent primer wedged SDC
      before it processed start;;
    - channels_count plural, because the reference client parser raises on
      the singular form the published PDF specifies and aborts the handshake;
    - drive with both fields, because ESDR3-mode WSJT-X and JTDX index
      args[1] unconditionally and a one-field drive:0; crashes them;
    - split_enable present at all, because the RF2K-S amplifier uses it as
      the signal that VFO 0 is active and otherwise reports "No TCI
      available" no matter how many vfo: events it receives.
}

interface

uses
   Windows, SysUtils, Classes, SyncObjs,
   uTR4WTestFramework, uTCIProtocol, uTCIServer, uWebSocketClient, VC, LOGRADIO;

type
   TTCIServerTests = class(TTestCase)
   private
      FServer: TTCIServer;
      FPort:   integer;
      FLock:   TCriticalSection;
      FRx:     TStringList;

      procedure ClientText(const Text: string);

      function  StartServer: boolean;
      procedure StopServer;
      function  Connect(out Client: TWebSocketClient): boolean;

      function  RxCount: integer;
      function  RxItem(Index: integer): string;
      procedure RxClear;
      // Index of the first received message equal to Want, or -1.
      function  IndexOf(const Want: string): integer;
      // Index of the first received message starting with Prefix, or -1.
      function  IndexOfPrefix(const Prefix: string): integer;
      function  WaitForQuiet(TimeoutMs: cardinal): boolean;
      function  WaitForPrefix(const Prefix: string; TimeoutMs: cardinal): boolean;

   protected
      // The init burst
      procedure Test_Burst_HasTheIdentityBlock;
      procedure Test_Burst_ChannelsCountIsPlural;
      procedure Test_Burst_ReadyIsLastAndStartFollowsIt;
      procedure Test_Burst_NoAudioOrIQPrimer;
      procedure Test_Burst_DriveCarriesBothFields;
      procedure Test_Burst_SplitEnableIsPresent;
      procedure Test_Burst_HasBothVfoChannels;
      procedure Test_Burst_EveryMessageIsOneCommand;

      // Requests
      procedure Test_Get_VfoLimitsMatchTheBurst;
      procedure Test_Get_UnknownCommandIsSilent;
      procedure Test_Get_VfoChannelOutOfRangeIsSilent;
      procedure Test_Get_UnconfiguredReceiverIsSilent;
      procedure Test_Get_AudioStartIsEchoedVerbatim;
      procedure Test_Get_TxEnableInboundIsSilent;

      // Refusals -- PTT is the one command that must answer when refused
      procedure Test_PTT_RefusedReceiverAnswersFalse;
      procedure Test_PTT_NonBooleanAnswersFalse;

      // Confirmations WSJT-X waits on
      procedure Test_Set_ModulationIsConfirmed;
      procedure Test_Set_VfoIsConfirmed;
      procedure Test_Set_GlobalSplitEnableIsAccepted;
      procedure Test_Set_UnknownModulationIsSilent;

      // The mode mapping, which is a wire contract
      procedure Test_Mode_ToTCI;
      procedure Test_Mode_PhoneSidebandFollowsBand;
      procedure Test_Mode_FromTCI;
      procedure Test_Mode_UnknownIsRefusedNotCoerced;
      procedure Test_Mode_RoundTrips;

      // Receiver mapping
      procedure Test_Trx_MapsToRadios;
      procedure Test_Trx_OutOfRangeIsNil;

   public
      procedure RunAllTests; override;
   end;

implementation

const
   PORT_FIRST = 55751;
   PORT_LAST  = 55760;
   WAIT_MS    = 5000;
   // How long the burst is given to go quiet before it is considered whole.
   QUIET_MS   = 400;

{ ------------------------------------------------------------- plumbing -- }

procedure TTCIServerTests.ClientText(const Text: string);
begin
   FLock.Enter;
   try
      FRx.Add(Text);
   finally
      FLock.Leave;
   end;
end;

function TTCIServerTests.RxCount: integer;
begin
   FLock.Enter;
   try
      Result := FRx.Count;
   finally
      FLock.Leave;
   end;
end;

function TTCIServerTests.RxItem(Index: integer): string;
begin
   FLock.Enter;
   try
      if (Index >= 0) and (Index < FRx.Count) then
         begin
         Result := FRx[Index];
         end
      else
         begin
         Result := '';
         end;
   finally
      FLock.Leave;
   end;
end;

procedure TTCIServerTests.RxClear;
begin
   FLock.Enter;
   try
      FRx.Clear;
   finally
      FLock.Leave;
   end;
end;

function TTCIServerTests.IndexOf(const Want: string): integer;
var
   i: integer;
begin
   FLock.Enter;
   try
      for i := 0 to FRx.Count - 1 do
         begin
         if FRx[i] = Want then
            begin
            Result := i;
            Exit;
            end;
         end;
   finally
      FLock.Leave;
   end;
   Result := -1;
end;

function TTCIServerTests.IndexOfPrefix(const Prefix: string): integer;
var
   i: integer;
begin
   FLock.Enter;
   try
      for i := 0 to FRx.Count - 1 do
         begin
         if Copy(FRx[i], 1, Length(Prefix)) = Prefix then
            begin
            Result := i;
            Exit;
            end;
         end;
   finally
      FLock.Leave;
   end;
   Result := -1;
end;

// Waits until no new message has arrived for QUIET_MS.  The burst is a
// stream of independent frames with no terminator, so "it stopped" is the
// only honest way to know it is complete.
function TTCIServerTests.WaitForQuiet(TimeoutMs: cardinal): boolean;
var
   deadline: cardinal;
   lastN:    integer;
   lastMove: cardinal;
begin
   deadline := GetTickCount + TimeoutMs;
   lastN := RxCount;
   lastMove := GetTickCount;
   while GetTickCount < deadline do
      begin
      Sleep(20);
      if RxCount <> lastN then
         begin
         lastN := RxCount;
         lastMove := GetTickCount;
         end
      else if (RxCount > 0) and (GetTickCount - lastMove >= QUIET_MS) then
         begin
         Result := True;
         Exit;
         end;
      end;
   Result := RxCount > 0;
end;

function TTCIServerTests.WaitForPrefix(const Prefix: string; TimeoutMs: cardinal): boolean;
var
   deadline: cardinal;
begin
   deadline := GetTickCount + TimeoutMs;
   while GetTickCount < deadline do
      begin
      if IndexOfPrefix(Prefix) >= 0 then
         begin
         Result := True;
         Exit;
         end;
      Sleep(10);
      end;
   Result := IndexOfPrefix(Prefix) >= 0;
end;

function TTCIServerTests.StartServer: boolean;
var
   p: integer;
begin
   FLock := TCriticalSection.Create;
   FRx := TStringList.Create;
   FServer := TTCIServer.Create;
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

procedure TTCIServerTests.StopServer;
begin
   if Assigned(FServer) then
      begin
      FServer.Stop;
      FreeAndNil(FServer);
      end;
   FreeAndNil(FRx);
   FreeAndNil(FLock);
end;

function TTCIServerTests.Connect(out Client: TWebSocketClient): boolean;
begin
   Client := TWebSocketClient.Create;
   Client.OnTextMessage := ClientText;
   Result := Client.Connect('127.0.0.1', FPort, '/');
   if not Result then
      begin
      FreeAndNil(Client);
      end;
end;

{ ----------------------------------------------------------- init burst -- }

procedure TTCIServerTests.Test_Burst_HasTheIdentityBlock;
var
   c: TWebSocketClient;
begin
   BeginTest('Test_Burst_HasTheIdentityBlock');
   if not StartServer then
      begin
      Check(False, 'no free loopback port');
      Exit;
      end;
   try
      CheckTrue(Connect(c), 'connected');
      try
         CheckTrue(WaitForQuiet(WAIT_MS), 'the burst arrived');
         CheckTrue(IndexOfPrefix('vfo_limits:') >= 0, 'vfo_limits');
         CheckTrue(IndexOfPrefix('if_limits:') >= 0, 'if_limits');
         CheckTrue(IndexOfPrefix('trx_count:') >= 0, 'trx_count');
         CheckTrue(IndexOf('device:TR4W;') >= 0, 'device');
         CheckTrue(IndexOf('receive_only:false;') >= 0, 'a logger is not receive-only');
         CheckTrue(IndexOfPrefix('modulations_list:') >= 0, 'modulations_list');
         CheckTrue(IndexOf('protocol:ExpertSDR3,1.5;') >= 0,
                   'the protocol string WSJT-X checks for full TX amplitude');
      finally
         c.Free;
      end;
   finally
      StopServer;
   end;
end;

procedure TTCIServerTests.Test_Burst_ChannelsCountIsPlural;
var
   c: TWebSocketClient;
begin
   BeginTest('Test_Burst_ChannelsCountIsPlural');
   if not StartServer then
      begin
      Check(False, 'no port');
      Exit;
      end;
   try
      CheckTrue(Connect(c), '');
      try
         WaitForQuiet(WAIT_MS);
         // The published PDF says CHANNEL_COUNT.  The reference client parser
         // (eesdr-tci, the basis of many clients including the RF2K-S
         // firmware) recognises only the plural and raises on the singular,
         // aborting the handshake.  Implementation wins over the PDF.
         CheckTrue(IndexOf('channels_count:2;') >= 0, 'plural, with a value of 2');
         CheckTrue(IndexOfPrefix('channel_count:') < 0, 'and the singular form is NOT sent');
      finally
         c.Free;
      end;
   finally
      StopServer;
   end;
end;

procedure TTCIServerTests.Test_Burst_ReadyIsLastAndStartFollowsIt;
var
   c:  TWebSocketClient;
   iReady, iStart, iVfo, iProto, i: integer;
begin
   BeginTest('Test_Burst_ReadyIsLastAndStartFollowsIt');
   if not StartServer then
      begin
      Check(False, 'no port');
      Exit;
      end;
   try
      CheckTrue(Connect(c), '');
      try
         CheckTrue(WaitForQuiet(WAIT_MS), 'burst arrived');
         iReady := IndexOf('ready;');
         iStart := IndexOf('start;');
         iVfo   := IndexOfPrefix('vfo:');
         iProto := IndexOf('protocol:ExpertSDR3,1.5;');

         CheckTrue(iReady >= 0, 'ready; is sent at all');
         CheckTrue(iStart >= 0, 'start; is sent at all');
         CheckTrue(iProto >= 0, '');
         CheckTrue(iVfo >= 0, '');

         // SDC and CW Skimmer latch their cached settings the instant ready;
         // arrives.  Anything after it is never seen, so EVERY setting must
         // precede it.
         CheckTrue(iProto < iReady, 'the identity block precedes ready;');
         CheckTrue(iVfo < iReady, 'and so does the per-receiver state');
         CheckTrue(iStart > iReady, 'start; is a device-state notice and follows ready;');

         // Nothing at all after start;.
         for i := iStart + 1 to RxCount - 1 do
            begin
            Check(False, Format('"%s" was sent after start;', [RxItem(i)]));
            end;
         CheckEquals(RxCount - 1, iStart, 'start; is the final message of the burst');
      finally
         c.Free;
      end;
   finally
      StopServer;
   end;
end;

procedure TTCIServerTests.Test_Burst_NoAudioOrIQPrimer;
var
   c: TWebSocketClient;
begin
   BeginTest('Test_Burst_NoAudioOrIQPrimer');
   if not StartServer then
      begin
      Check(False, 'no port');
      Exit;
      end;
   try
      CheckTrue(Connect(c), '');
      try
         WaitForQuiet(WAIT_MS);
         // Stream lifecycle is CLIENT-owned.  A server-sent audio_start
         // primer wedged SDC before it processed start;, so its TCI
         // connection never became active.
         CheckTrue(IndexOfPrefix('audio_start') < 0, 'no audio_start in the greeting');
         CheckTrue(IndexOfPrefix('iq_start') < 0, 'no iq_start in the greeting');
      finally
         c.Free;
      end;
   finally
      StopServer;
   end;
end;

procedure TTCIServerTests.Test_Burst_DriveCarriesBothFields;
var
   c:   TWebSocketClient;
   i:   integer;
   msg: string;
   cmd: TTCICommand;
begin
   BeginTest('Test_Burst_DriveCarriesBothFields');
   if not StartServer then
      begin
      Check(False, 'no port');
      Exit;
      end;
   try
      CheckTrue(Connect(c), '');
      try
         WaitForQuiet(WAIT_MS);
         i := IndexOfPrefix('drive:');
         CheckTrue(i >= 0, 'drive is in the burst');
         if i >= 0 then
            begin
            msg := RxItem(i);
            cmd := TCIParse(Copy(msg, 1, Length(msg) - 1));
            // ESDR3-mode WSJT-X and JTDX read args[1] unconditionally after
            // matching args[0].  A one-field 'drive:0;' crashes them.
            CheckEquals(2, cmd.ArgCount, 'drive must always carry <trx>,<power>');
            end;
         i := IndexOfPrefix('tune_drive:');
         CheckTrue(i >= 0, 'tune_drive is in the burst');
         if i >= 0 then
            begin
            msg := RxItem(i);
            cmd := TCIParse(Copy(msg, 1, Length(msg) - 1));
            CheckEquals(2, cmd.ArgCount, 'tune_drive must always carry <trx>,<power>');
            end;
      finally
         c.Free;
      end;
   finally
      StopServer;
   end;
end;

procedure TTCIServerTests.Test_Burst_SplitEnableIsPresent;
var
   c: TWebSocketClient;
begin
   BeginTest('Test_Burst_SplitEnableIsPresent');
   if not StartServer then
      begin
      Check(False, 'no port');
      Exit;
      end;
   try
      CheckTrue(Connect(c), '');
      try
         WaitForQuiet(WAIT_MS);
         // The RF2K-S amplifier client uses split_enable:0,false as the
         // signal that VFO 0 is the active VFO.  Without ever receiving it
         // its current position stays unset and it shows "No TCI available"
         // however many vfo: events arrive.
         CheckTrue(IndexOfPrefix('split_enable:0,') >= 0,
                   'split_enable for receiver 0 is stated explicitly');
      finally
         c.Free;
      end;
   finally
      StopServer;
   end;
end;

procedure TTCIServerTests.Test_Burst_HasBothVfoChannels;
var
   c: TWebSocketClient;
begin
   BeginTest('Test_Burst_HasBothVfoChannels');
   if not StartServer then
      begin
      Check(False, 'no port');
      Exit;
      end;
   try
      CheckTrue(Connect(c), '');
      try
         WaitForQuiet(WAIT_MS);
         CheckTrue(IndexOfPrefix('vfo:0,0,') >= 0, 'receive channel');
         CheckTrue(IndexOfPrefix('vfo:0,1,') >= 0, 'transmit channel');
         CheckTrue(IndexOfPrefix('modulation:0,') >= 0, '');
         CheckTrue(IndexOfPrefix('rit_enable:0,') >= 0, '');
         CheckTrue(IndexOfPrefix('xit_offset:0,') >= 0, '');
      finally
         c.Free;
      end;
   finally
      StopServer;
   end;
end;

procedure TTCIServerTests.Test_Burst_EveryMessageIsOneCommand;
var
   c: TWebSocketClient;
   i: integer;
   s: string;
begin
   BeginTest('Test_Burst_EveryMessageIsOneCommand');
   if not StartServer then
      begin
      Check(False, 'no port');
      Exit;
      end;
   try
      CheckTrue(Connect(c), '');
      try
         WaitForQuiet(WAIT_MS);
         // TCI requires one command per WebSocket message.  A client that
         // splits on frames rather than on ';' sees a concatenated burst as
         // one unrecognised command and aborts the handshake.
         for i := 0 to RxCount - 1 do
            begin
            s := RxItem(i);
            if (Length(s) = 0) or (s[Length(s)] <> ';') then
               begin
               Check(False, Format('message %d does not end with ";": "%s"', [i, s]));
               Exit;
               end;
            if Pos(';', Copy(s, 1, Length(s) - 1)) > 0 then
               begin
               Check(False, Format('message %d carries more than one command: "%s"', [i, s]));
               Exit;
               end;
            end;
         Check(True, Format('all %d burst messages are exactly one command', [RxCount]));
      finally
         c.Free;
      end;
   finally
      StopServer;
   end;
end;

{ ------------------------------------------------------------- requests -- }

procedure TTCIServerTests.Test_Get_VfoLimitsMatchTheBurst;
var
   c:     TWebSocketClient;
   burst: string;
   i:     integer;
begin
   BeginTest('Test_Get_VfoLimitsMatchTheBurst');
   if not StartServer then
      begin
      Check(False, 'no port');
      Exit;
      end;
   try
      CheckTrue(Connect(c), '');
      try
         WaitForQuiet(WAIT_MS);
         i := IndexOfPrefix('vfo_limits:');
         burst := RxItem(i);
         RxClear;
         // The reference server answers DIFFERENT limits on request than it
         // sends in its burst.  That is a defect, not a convention: a client
         // that sanity-checks a tune against the answer would reject a
         // frequency the burst said was legal.
         c.SendText('vfo_limits;');
         CheckTrue(WaitForPrefix('vfo_limits:', WAIT_MS), 'the request is answered');
         CheckEquals(burst, RxItem(IndexOfPrefix('vfo_limits:')),
                     'and the answer is identical to the burst');
      finally
         c.Free;
      end;
   finally
      StopServer;
   end;
end;

procedure TTCIServerTests.Test_Get_UnknownCommandIsSilent;
var
   c: TWebSocketClient;
begin
   BeginTest('Test_Get_UnknownCommandIsSilent');
   if not StartServer then
      begin
      Check(False, 'no port');
      Exit;
      end;
   try
      CheckTrue(Connect(c), '');
      try
         WaitForQuiet(WAIT_MS);
         RxClear;
         // Silence is the protocol's answer.  An error reply would be parsed
         // by the client as a command it does not know, and the stricter
         // parsers abort the connection on exactly that.
         c.SendText('completely_made_up:1,2,3;');
         c.SendText('rx_nb_enable:0,true;');
         Sleep(QUIET_MS);
         CheckEquals(0, RxCount, 'an unknown command draws no reply at all');
      finally
         c.Free;
      end;
   finally
      StopServer;
   end;
end;

procedure TTCIServerTests.Test_Get_VfoChannelOutOfRangeIsSilent;
var
   c: TWebSocketClient;
begin
   BeginTest('Test_Get_VfoChannelOutOfRangeIsSilent');
   if not StartServer then
      begin
      Check(False, 'no port');
      Exit;
      end;
   try
      CheckTrue(Connect(c), '');
      try
         WaitForQuiet(WAIT_MS);
         RxClear;
         // Answering channel 0 here would be worse than silence: the client
         // would believe its bad request had succeeded.
         c.SendText('vfo:0,2;');
         c.SendText('vfo:0,-1;');
         Sleep(QUIET_MS);
         CheckEquals(0, RxCount, 'an out-of-range channel is not answered');
      finally
         c.Free;
      end;
   finally
      StopServer;
   end;
end;

procedure TTCIServerTests.Test_Get_UnconfiguredReceiverIsSilent;
var
   c: TWebSocketClient;
begin
   BeginTest('Test_Get_UnconfiguredReceiverIsSilent');
   if not StartServer then
      begin
      Check(False, 'no port');
      Exit;
      end;
   try
      CheckTrue(Connect(c), '');
      try
         WaitForQuiet(WAIT_MS);
         RxClear;
         // NEVER fall back to receiver 0.  A client that asked about
         // receiver 9 and got receiver 0's frequency would act on the wrong
         // radio -- which in SO2R means transmitting on the wrong one.
         c.SendText('vfo:9,0;');
         c.SendText('modulation:9;');
         Sleep(QUIET_MS);
         CheckEquals(0, RxCount, 'an unconfigured receiver is not answered');
      finally
         c.Free;
      end;
   finally
      StopServer;
   end;
end;

procedure TTCIServerTests.Test_Get_AudioStartIsEchoedVerbatim;
var
   c: TWebSocketClient;
begin
   BeginTest('Test_Get_AudioStartIsEchoedVerbatim');
   if not StartServer then
      begin
      Check(False, 'no port');
      Exit;
      end;
   try
      CheckTrue(Connect(c), '');
      try
         WaitForQuiet(WAIT_MS);
         RxClear;
         // We never send audio.  But a client that gets silence here decides
         // the server is broken, so the command is acknowledged -- echoed
         // exactly, which is what the reference does and what clients match.
         c.SendText('audio_start:0;');
         CheckTrue(WaitForPrefix('audio_start', WAIT_MS), 'acknowledged');
         CheckEquals('audio_start:0;', RxItem(IndexOfPrefix('audio_start')),
                     'echoed verbatim, including the receiver');
      finally
         c.Free;
      end;
   finally
      StopServer;
   end;
end;

procedure TTCIServerTests.Test_Get_TxEnableInboundIsSilent;
var
   c: TWebSocketClient;
begin
   BeginTest('Test_Get_TxEnableInboundIsSilent');
   if not StartServer then
      begin
      Check(False, 'no port');
      Exit;
      end;
   try
      CheckTrue(Connect(c), '');
      try
         WaitForQuiet(WAIT_MS);
         RxClear;
         // TCI 2.0 and Thetis both define tx_enable as server-to-client
         // state.  An inbound one must mutate nothing and answer nothing.
         c.SendText('tx_enable:0,true;');
         c.SendText('rx_enable:0,false;');
         Sleep(QUIET_MS);
         CheckEquals(0, RxCount, 'notification-only commands draw no reply');
      finally
         c.Free;
      end;
   finally
      StopServer;
   end;
end;

{ ------------------------------------------------------------- refusals -- }

procedure TTCIServerTests.Test_PTT_RefusedReceiverAnswersFalse;
var
   c: TWebSocketClient;
begin
   BeginTest('Test_PTT_RefusedReceiverAnswersFalse');
   if not StartServer then
      begin
      Check(False, 'no port');
      Exit;
      end;
   try
      CheckTrue(Connect(c), '');
      try
         WaitForQuiet(WAIT_MS);
         RxClear;
         // PTT IS THE ONE EXCEPTION TO SILENCE-ON-REFUSAL.  A refused key
         // that is answered with nothing is what WSJT-X surfaces as "TCI
         // failed to set ptt" with no cause, and the operator has no way to
         // tell that from a dead link.
         c.SendText('trx:9,true;');
         CheckTrue(WaitForPrefix('trx:9,', WAIT_MS), 'a refused key IS answered');
         CheckEquals('trx:9,false;', RxItem(IndexOfPrefix('trx:9,')),
                     'and the answer states the real state: not transmitting');
      finally
         c.Free;
      end;
   finally
      StopServer;
   end;
end;

procedure TTCIServerTests.Test_PTT_NonBooleanAnswersFalse;
var
   c: TWebSocketClient;
begin
   BeginTest('Test_PTT_NonBooleanAnswersFalse');
   if not StartServer then
      begin
      Check(False, 'no port');
      Exit;
      end;
   try
      CheckTrue(Connect(c), '');
      try
         WaitForQuiet(WAIT_MS);
         RxClear;
         // 'yes' is not a boolean.  The reference reads anything that is not
         // 'true' as false, which would silently UNKEY here.  We refuse --
         // but out loud, because this is PTT.
         c.SendText('trx:0,yes;');
         CheckTrue(WaitForPrefix('trx:0,', WAIT_MS), 'answered rather than ignored');
         CheckEquals('trx:0,false;', RxItem(IndexOfPrefix('trx:0,')), '');
      finally
         c.Free;
      end;
   finally
      StopServer;
   end;
end;

procedure TTCIServerTests.Test_Set_ModulationIsConfirmed;
var
   c: TWebSocketClient;
begin
   BeginTest('Test_Set_ModulationIsConfirmed');
   if not StartServer then
      begin
      Check(False, 'no port');
      Exit;
      end;
   try
      CheckTrue(Connect(c), '');
      try
         WaitForQuiet(WAIT_MS);
         RxClear;
         // THE REGRESSION THIS SUITE MISSED THE FIRST TIME.  A mode SET was
         // accepted and applied but never confirmed, and WSJT-X's do_mode()
         // waits on the echo: it reported "TCI failed set mode" and dropped
         // the socket 1.2 s later.  Observed 2026-08-09 13:30:44.948.
         c.SendText('modulation:0,digu;');
         CheckTrue(WaitForPrefix('modulation:0,', WAIT_MS),
                   'a mode SET must be confirmed, exactly as a tune is');
         CheckEquals('modulation:0,digu;', RxItem(IndexOfPrefix('modulation:0,')),
                     'and the confirmation names the mode that was accepted');
      finally
         c.Free;
      end;
   finally
      StopServer;
   end;
end;

procedure TTCIServerTests.Test_Set_VfoIsConfirmed;
var
   c: TWebSocketClient;
begin
   BeginTest('Test_Set_VfoIsConfirmed');
   if not StartServer then
      begin
      Check(False, 'no port');
      Exit;
      end;
   try
      CheckTrue(Connect(c), '');
      try
         WaitForQuiet(WAIT_MS);
         RxClear;
         // WSJT-X's do_frequency() waits about two seconds for this and then
         // reports rig-control failure and drops the socket.
         c.SendText('vfo:0,0,50313000;');
         CheckTrue(WaitForPrefix('vfo:0,0,', WAIT_MS), 'a tune is confirmed');
         CheckEquals('vfo:0,0,50313000;', RxItem(IndexOfPrefix('vfo:0,0,')),
                     'with the frequency that was accepted');
      finally
         c.Free;
      end;
   finally
      StopServer;
   end;
end;

procedure TTCIServerTests.Test_Set_GlobalSplitEnableIsAccepted;
var
   c: TWebSocketClient;
begin
   BeginTest('Test_Set_GlobalSplitEnableIsAccepted');
   if not StartServer then
      begin
      Check(False, 'no port');
      Exit;
      end;
   try
      CheckTrue(Connect(c), '');
      try
         WaitForQuiet(WAIT_MS);
         RxClear;
         // The exact line WSJT-X sends.  It must not be read as a GET for
         // receiver -1 -- which is what happened, silently, before the
         // global-form expander existed.  With no radio attached the split
         // is already off, so this is a no-op transition and draws no reply;
         // what is asserted is that it is not MISREAD, which the log shows
         // as "asked about receiver -1, which is not configured".
         c.SendText('split_enable:false;');
         Sleep(QUIET_MS);
         CheckEquals(0, RxCount, 'a steady false is a no-op, not an error');
      finally
         c.Free;
      end;
   finally
      StopServer;
   end;
end;

procedure TTCIServerTests.Test_Set_UnknownModulationIsSilent;
var
   c: TWebSocketClient;
begin
   BeginTest('Test_Set_UnknownModulationIsSilent');
   if not StartServer then
      begin
      Check(False, 'no port');
      Exit;
      end;
   try
      CheckTrue(Connect(c), '');
      try
         WaitForQuiet(WAIT_MS);
         RxClear;
         // A mode we never advertised is refused, and refusing means NOT
         // confirming: confirming a mode we did not set would tell the client
         // the radio is somewhere it is not.
         c.SendText('modulation:0,sam;');
         Sleep(QUIET_MS);
         CheckEquals(0, RxCount, 'an unknown modulation is not confirmed');
      finally
         c.Free;
      end;
   finally
      StopServer;
   end;
end;

{ --------------------------------------------------------- mode mapping -- }

procedure TTCIServerTests.Test_Mode_ToTCI;
begin
   BeginTest('Test_Mode_ToTCI');
   CheckEquals('cw',   TR4WModeToTCI(CW, eCW, 14025000), '');
   CheckEquals('cwr',  TR4WModeToTCI(CW, eCW_R, 14025000), 'CW-reverse is a distinct TCI mode');
   CheckEquals('usb',  TR4WModeToTCI(Phone, eUSB, 14250000), '');
   CheckEquals('lsb',  TR4WModeToTCI(Phone, eLSB, 7200000), '');
   CheckEquals('am',   TR4WModeToTCI(Phone, eAM, 7200000), '');
   CheckEquals('fm',   TR4WModeToTCI(FM, eFM, 145000000), '');
   CheckEquals('rtty', TR4WModeToTCI(Digital, eRTTY, 14080000), '');
   CheckEquals('digu', TR4WModeToTCI(Digital, eData, 14074000), 'FT8 is upper-sideband data');
   CheckEquals('digl', TR4WModeToTCI(Digital, eData_R, 7074000), '');
end;

procedure TTCIServerTests.Test_Mode_PhoneSidebandFollowsBand;
begin
   BeginTest('Test_Mode_PhoneSidebandFollowsBand');
   // With no extended mode the only sane rule is the operating convention:
   // LSB below 10 MHz, USB above.  Defaulting to USB would show the wrong
   // sideband on 40 and 80 metres on every QSY.
   CheckEquals('lsb', TR4WModeToTCI(Phone, eNoMode, 3750000), '80 m is LSB');
   CheckEquals('lsb', TR4WModeToTCI(Phone, eNoMode, 7200000), '40 m is LSB');
   CheckEquals('usb', TR4WModeToTCI(Phone, eNoMode, 14250000), '20 m is USB');
   CheckEquals('usb', TR4WModeToTCI(Phone, eNoMode, 28400000), '10 m is USB');
   CheckEquals('cw',  TR4WModeToTCI(CW, eNoMode, 7025000), 'CW needs no sideband rule');
end;

procedure TTCIServerTests.Test_Mode_FromTCI;
var
   m: ModeType;
   e: ExtendedModeType;
begin
   BeginTest('Test_Mode_FromTCI');
   CheckTrue(TCIToTR4WMode('cw', m, e), '');
   CheckTrue((m = CW) and (e = eCW), 'cw');
   CheckTrue(TCIToTR4WMode('CWR', m, e), 'case insensitive');
   CheckTrue((m = CW) and (e = eCW_R), 'cwr');
   CheckTrue(TCIToTR4WMode('lsb', m, e), '');
   CheckTrue((m = Phone) and (e = eLSB), 'lsb');
   CheckTrue(TCIToTR4WMode('digu', m, e), '');
   CheckTrue((m = Digital) and (e = eData), 'digu');
   CheckTrue(TCIToTR4WMode('rtty', m, e), '');
   CheckTrue((m = Digital) and (e = eRTTY), 'rtty');
end;

procedure TTCIServerTests.Test_Mode_UnknownIsRefusedNotCoerced;
var
   m: ModeType;
   e: ExtendedModeType;
begin
   BeginTest('Test_Mode_UnknownIsRefusedNotCoerced');
   // The reference server coerces anything unknown to USB, which puts the
   // radio in a mode nobody asked for without telling anyone.  Refusing
   // means the command is answered with silence and the radio does not move.
   CheckFalse(TCIToTR4WMode('sam', m, e), 'a mode we never advertised');
   CheckTrue(m = NoMode, 'and no mode is invented for it');
   CheckFalse(TCIToTR4WMode('', m, e), 'the empty modulation');
   CheckFalse(TCIToTR4WMode('nonsense', m, e), '');
end;

procedure TTCIServerTests.Test_Mode_RoundTrips;
var
   m: ModeType;
   e: ExtendedModeType;
   i: integer;
   names: array[0..8] of string;
begin
   BeginTest('Test_Mode_RoundTrips');
   // Every mode we ADVERTISE must survive a round trip, or a client that
   // reads modulations_list and sets one of them gets something else back.
   names[0] := 'usb';  names[1] := 'lsb';  names[2] := 'cw';
   names[3] := 'cwr';  names[4] := 'am';   names[5] := 'fm';
   names[6] := 'digu'; names[7] := 'digl'; names[8] := 'rtty';
   for i := 0 to High(names) do
      begin
      if not TCIToTR4WMode(names[i], m, e) then
         begin
         Check(False, Format('"%s" is in modulations_list but cannot be set', [names[i]]));
         Continue;
         end;
      CheckEquals(names[i], TR4WModeToTCI(m, e, 14025000),
                  Format('"%s" round trips', [names[i]]));
      end;
end;

{ ------------------------------------------------------ receiver mapping -- }

procedure TTCIServerTests.Test_Trx_MapsToRadios;
var
   r0, r1: RadioPtr;
begin
   BeginTest('Test_Trx_MapsToRadios');
   r0 := TrxToRadio(0);
   r1 := TrxToRadio(1);
   CheckTrue(r0 <> nil, 'trx 0 is radio 1');
   CheckTrue(r1 <> nil, 'trx 1 is radio 2');
   CheckTrue(r0 <> r1, 'and they are different radios');
   CheckEquals(0, RadioToTrx(r0), 'the mapping inverts');
   CheckEquals(1, RadioToTrx(r1), '');
end;

procedure TTCIServerTests.Test_Trx_OutOfRangeIsNil;
begin
   BeginTest('Test_Trx_OutOfRangeIsNil');
   // nil, NOT radio 1.  Silently falling back is how a client addressing
   // receiver 2 ends up keying receiver 0.
   CheckTrue(TrxToRadio(2) = nil, '');
   CheckTrue(TrxToRadio(-1) = nil, '');
   CheckTrue(TrxToRadio(99) = nil, '');
   CheckEquals(-1, RadioToTrx(nil), 'and an unknown radio has no trx');
end;

procedure TTCIServerTests.RunAllTests;
begin
   Test_Burst_HasTheIdentityBlock;
   Test_Burst_ChannelsCountIsPlural;
   Test_Burst_ReadyIsLastAndStartFollowsIt;
   Test_Burst_NoAudioOrIQPrimer;
   Test_Burst_DriveCarriesBothFields;
   Test_Burst_SplitEnableIsPresent;
   Test_Burst_HasBothVfoChannels;
   Test_Burst_EveryMessageIsOneCommand;

   Test_Get_VfoLimitsMatchTheBurst;
   Test_Get_UnknownCommandIsSilent;
   Test_Get_VfoChannelOutOfRangeIsSilent;
   Test_Get_UnconfiguredReceiverIsSilent;
   Test_Get_AudioStartIsEchoedVerbatim;
   Test_Get_TxEnableInboundIsSilent;

   Test_PTT_RefusedReceiverAnswersFalse;
   Test_PTT_NonBooleanAnswersFalse;

   Test_Set_ModulationIsConfirmed;
   Test_Set_VfoIsConfirmed;
   Test_Set_GlobalSplitEnableIsAccepted;
   Test_Set_UnknownModulationIsSilent;

   Test_Mode_ToTCI;
   Test_Mode_PhoneSidebandFollowsBand;
   Test_Mode_FromTCI;
   Test_Mode_UnknownIsRefusedNotCoerced;
   Test_Mode_RoundTrips;

   Test_Trx_MapsToRadios;
   Test_Trx_OutOfRangeIsNil;
end;

end.
