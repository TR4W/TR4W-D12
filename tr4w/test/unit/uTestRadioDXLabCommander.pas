unit uTestRadioDXLabCommander;
{$I ..\..\src\tr4w.inc}

(*
  THE COMMANDER DRIVER AGAINST A FAKE COMMANDER -- NO REAL ONE IS INVOLVED.

  The fake is a TIdTCPServer on an ephemeral loopback port that reads one
  message at a time (by the ADIF lengths, as Commander must) and answers from a
  table.  It can behave each way the document leaves open, so the driver is
  proven against all of them rather than against one guess:

    - keep the connection open after a reply, or close it (as DXKeeper does);
    - send a reply in two pieces;
    - follow a reply with CR/LF;
    - refuse service (close at once), then come back.

  WHAT THIS PROVES: what the driver writes, how it reads, how it reconnects,
  and that a queued command does not outlive a dropped link.  NOT what a real
  Commander accepts -- that is docs/BENCH_QUEUE.md.

  The driver's I/O methods are polling-thread methods; here the test thread
  plays the polling thread and calls them in the order pFactoryRadio does
  (Connect, DrainUrgentQueue, PollRadioState).

  The second half needs no transport at all: a capture subclass records what
  SendToRadio would queue, to pin the split semantics and the capability set.
*)

interface

uses
   SysUtils, Classes, SyncObjs, IdTCPServer, IdContext, IdGlobal, IdIOHandler,
   uTR4WTestFramework, uFactoryRadioBase, uRadioBand, uRadioRegistry,
   uDXLabCommanderProtocol, uRadioDXLabCommander;

type
   TRadioDXLabCommanderTests = class(TTestCase)
   private
      FServer: TIdTCPServer;
      FLock: TCriticalSection;
      FReceived: TStringList;        // 'Command' or 'Command|parameters', in arrival order
      FReplies: TStringList;         // Command=reply
      FCloseAfterReply: boolean;     // hang up after answering a query
      FCloseAfterEvery: boolean;     // hang up after ANY message, as DXKeeper does
      FSplitReply: boolean;
      FAppendCRLF: boolean;
      FRefuse: boolean;
      FConnections: integer;
      procedure ServerConnect(AContext: TIdContext);
      procedure ServerExecute(AContext: TIdContext);
      function  StartServer: Word;
      procedure StopServer;
      procedure ResetPeer;
      procedure SetReply(const ACommand, AReply: string);
      function  CountOf(const ACommand: string): integer;
      function  WaitForCount(const ACommand: string; ACount, ATimeoutMs: integer): boolean;
      function  ReceivedSnapshot: string;
      procedure ClearReceived;
      function  ConnectionCount: integer;
   protected
      procedure Test_PeerThatStaysOpen_PollsOnOneConnection;
      procedure Test_PeerThatClosesAfterEachReply_StillPolls;
      procedure Test_ReplySplitAcrossTwoWrites_IsRead;
      procedure Test_ReplyFollowedByCRLF_IsRead;
      procedure Test_RigNotReporting_ConnectedButNotOperational;
      procedure Test_PeerDownThenBackUp_Reconnects;
      procedure Test_QueuedTXDoesNotSurviveADroppedLink;
      procedure Test_ReceiveJumpsTheQueue;
      procedure Test_PeerThatClosesAfterEveryMessage_SetsKeepTheirOrder;
      procedure Test_UnansweredTXQueryStopsBeingAsked;
      procedure Test_StopAndUnkeyWithNoLink_QueueNothing;
      procedure Test_VFOBWrite_IsAlwaysQSXSplitNeverSetTXFreq;
      procedure Test_StartupCommandMustBeOneMessage;
      procedure Test_VFOAWrite_IsSetFreqThenSetMode_NeverSetFreqMode;
      procedure Test_FrequencyWrittenInTheLocaleSeparator;
      procedure Test_RepliesApplyToTheRadio;
      procedure Test_EveryAbstractIsCallable;
      procedure Test_CapabilitiesAndRegistrationAreExactly;
   public
      procedure RunAllTests; override;
   end;

implementation

type
   (* The shipped driver, with the reply wait shortened so a silent query costs
     a test 150 ms rather than 500. *)
   TCommanderProbe = class(TDXLabCommanderRadio)
   public
      constructor CreateFor(APort: Word);
   end;

   (* No transport: records what would be queued, urgent or not. *)
   TCommanderCapture = class(TDXLabCommanderRadio)
   public
      sent: TStringList;
      constructor Create;
      destructor Destroy; override;
      procedure SendToRadio(s: string); overload; override;
      procedure SendToRadioUrgent(const s: string); override;
      procedure UseSeparator(ASeparator: Char);
      function  All: string;
   end;

const
   REPLY_FREQ  = '<CmdFreq:10>14,010.500';
   REPLY_MODE  = '<CmdMode:2>CW';
   REPLY_SPLIT = '<CmdSplit:3>OFF';
   REPLY_TX    = '<CmdTX:3>OFF';
   WAIT_MS     = 2000;

   (* Spelled here, not imported: the id is what a saved radio definition
     stores, so changing it is a compatibility decision this pin should catch. *)
   DXLAB_COMMANDER_ID = 'DXLABCOMMANDER';

constructor TCommanderProbe.CreateFor(APort: Word);
begin
   inherited Create;
   FReplyTimeoutMs := 150;
   radioAddress := '127.0.0.1';
   radioPort := APort;
end;

constructor TCommanderCapture.Create;
begin
   inherited Create;
   sent := TStringList.Create;
end;

destructor TCommanderCapture.Destroy;
begin
   FreeAndNil(sent);
   inherited Destroy;
end;

procedure TCommanderCapture.SendToRadio(s: string);
begin
   sent.Add(s);
end;

procedure TCommanderCapture.SendToRadioUrgent(const s: string);
begin
   sent.Insert(0, s);
end;

procedure TCommanderCapture.UseSeparator(ASeparator: Char);
begin
   FDecimalSeparator := ASeparator;
end;

function TCommanderCapture.All: string;
begin
   Result := StringReplace(sent.Text, #13#10, '', [rfReplaceAll]);
   Result := StringReplace(Result, #10, '', [rfReplaceAll]);
end;

(* ---- the fake Commander (its own threads) -------------------------------- *)

procedure TRadioDXLabCommanderTests.ServerConnect(AContext: TIdContext);
begin
   FLock.Enter;
   try
      Inc(FConnections);
   finally
      FLock.Leave;
   end;
   if FRefuse then
      begin
      AContext.Connection.Disconnect;
      end;
end;

(* One message per call: <command:N>name<parameters:M>params, read by length
  with the same header parser the driver uses for replies. *)
procedure TRadioDXLabCommanderTests.ServerExecute(AContext: TIdContext);
var
   io: TIdIOHandler;
   header: string;
   name: string;
   len: integer;
   command: string;
   params: string;
   reply: string;
   half: integer;
begin
   if FRefuse then
      begin
      AContext.Connection.Disconnect;
      Exit;
      end;

   io := AContext.Connection.IOHandler;
   header := io.ReadLn('>', 100, -1, IndyTextEncoding_8Bit);
   if io.ReadLnTimedout then
      begin
      Exit;
      end;
   if not TryParseCommanderFieldHeader(header, name, len) then
      begin
      Exit;
      end;
   command := io.ReadString(len, IndyTextEncoding_8Bit);
   header := io.ReadLn('>', 1000, -1, IndyTextEncoding_8Bit);
   if not TryParseCommanderFieldHeader(header, name, len) then
      begin
      Exit;
      end;
   params := '';
   if len > 0 then
      begin
      params := io.ReadString(len, IndyTextEncoding_8Bit);
      end;

   (* Asked again AFTER the read: a test that switches refusal on while this
     thread is parked in ReadLn must not have the message served. *)
   if FRefuse then
      begin
      AContext.Connection.Disconnect;
      Exit;
      end;

   FLock.Enter;
   try
      if params = '' then
         begin
         FReceived.Add(command);
         end
      else
         begin
         FReceived.Add(command + '|' + params);
         end;
      reply := FReplies.Values[command];
   finally
      FLock.Leave;
   end;

   if reply = '' then
      begin
      if FCloseAfterEvery then
         begin
         AContext.Connection.Disconnect;
         end;
      Exit;
      end;
   if FAppendCRLF then
      begin
      reply := reply + #13#10;
      end;

   if FSplitReply then
      begin
      half := Length(reply) div 2;
      io.Write(Copy(reply, 1, half), IndyTextEncoding_8Bit);
      Sleep(40);
      io.Write(Copy(reply, half + 1, Length(reply)), IndyTextEncoding_8Bit);
      end
   else
      begin
      io.Write(reply, IndyTextEncoding_8Bit);
      end;

   if FCloseAfterReply or FCloseAfterEvery then
      begin
      AContext.Connection.Disconnect;
      end;
end;

function TRadioDXLabCommanderTests.StartServer: Word;
begin
   ResetPeer;
   FServer := TIdTCPServer.Create(nil);
   FServer.OnConnect := ServerConnect;
   FServer.OnExecute := ServerExecute;
   with FServer.Bindings.Add do
      begin
      IP := '127.0.0.1';
      Port := 0;
      end;
   FServer.Active := True;
   Result := FServer.Bindings[0].Port;
end;

procedure TRadioDXLabCommanderTests.StopServer;
begin
   if FServer <> nil then
      begin
      FServer.Active := False;
      FreeAndNil(FServer);
      end;
end;

procedure TRadioDXLabCommanderTests.ResetPeer;
begin
   if FLock = nil then
      begin
      FLock := TCriticalSection.Create;
      FReceived := TStringList.Create;
      FReplies := TStringList.Create;
      end;
   FLock.Enter;
   try
      FReceived.Clear;
      FReplies.Clear;
      FReplies.Values['CmdGetFreq'] := REPLY_FREQ;
      FReplies.Values['CmdSendMode'] := REPLY_MODE;
      FReplies.Values['CmdSendSplit'] := REPLY_SPLIT;
      FReplies.Values['CmdSendTX'] := REPLY_TX;
      FCloseAfterReply := False;
      FCloseAfterEvery := False;
      FSplitReply := False;
      FAppendCRLF := False;
      FRefuse := False;
      FConnections := 0;
   finally
      FLock.Leave;
   end;
end;

procedure TRadioDXLabCommanderTests.SetReply(const ACommand, AReply: string);
begin
   FLock.Enter;
   try
      if AReply = '' then
         begin
         FReplies.Values[ACommand] := '';   // removes the entry: no answer
         end
      else
         begin
         FReplies.Values[ACommand] := AReply;
         end;
   finally
      FLock.Leave;
   end;
end;

function TRadioDXLabCommanderTests.CountOf(const ACommand: string): integer;
var
   i: integer;
begin
   Result := 0;
   FLock.Enter;
   try
      for i := 0 to FReceived.Count - 1 do
         begin
         if (FReceived[i] = ACommand) or (Pos(ACommand + '|', FReceived[i]) = 1) then
            begin
            Inc(Result);
            end;
         end;
   finally
      FLock.Leave;
   end;
end;

function TRadioDXLabCommanderTests.WaitForCount(const ACommand: string;
                                                ACount, ATimeoutMs: integer): boolean;
var
   waited: integer;
begin
   waited := 0;
   while (CountOf(ACommand) < ACount) and (waited < ATimeoutMs) do
      begin
      Sleep(10);
      Inc(waited, 10);
      end;
   Result := CountOf(ACommand) >= ACount;
end;

function TRadioDXLabCommanderTests.ReceivedSnapshot: string;
begin
   FLock.Enter;
   try
      Result := FReceived.CommaText;
   finally
      FLock.Leave;
   end;
end;

procedure TRadioDXLabCommanderTests.ClearReceived;
begin
   FLock.Enter;
   try
      FReceived.Clear;
   finally
      FLock.Leave;
   end;
end;

function TRadioDXLabCommanderTests.ConnectionCount: integer;
begin
   FLock.Enter;
   try
      Result := FConnections;
   finally
      FLock.Leave;
   end;
end;

(* ---- transport ----------------------------------------------------------- *)

procedure TRadioDXLabCommanderTests.Test_PeerThatStaysOpen_PollsOnOneConnection;
var
   r: TCommanderProbe;
begin
   BeginTest('Test_PeerThatStaysOpen_PollsOnOneConnection');
   r := TCommanderProbe.CreateFor(StartServer);
   try
      CheckEquals(0, r.Connect, 'Commander answered the probe');
      CheckTrue(r.IsConnected, 'connected');
      CheckTrue(r.IsOperational, 'and the rig is reporting');
      r.PollRadioState;
      CheckEquals(14010500, r.frequency[nrVFOA], 'CmdFreq applied');
      CheckEquals(Ord(rmCW), Ord(r.mode[nrVFOA]), 'CmdMode applied');
      CheckFalse(r.IsSplitEnabled, 'CmdSplit applied');
      CheckFalse(r.IsTransmitting, 'CmdTX applied');
      r.PollRadioState;
      CheckTrue(r.IsConnected, 'still connected after a second poll');
      CheckEquals(1, ConnectionCount, 'a peer that stays open is asked on ONE connection');
   finally
      r.Free;
      StopServer;
   end;
end;

procedure TRadioDXLabCommanderTests.Test_PeerThatClosesAfterEachReply_StillPolls;
var
   r: TCommanderProbe;
begin
   BeginTest('Test_PeerThatClosesAfterEachReply_StillPolls');
   r := TCommanderProbe.CreateFor(StartServer);
   try
      FCloseAfterReply := True;
      CheckEquals(0, r.Connect, 'probe answered');
      r.PollRadioState;
      CheckTrue(r.IsConnected, 'a closed connection is not a lost link');
      CheckEquals(14010500, r.frequency[nrVFOA], 'frequency read');
      CheckEquals(Ord(rmCW), Ord(r.mode[nrVFOA]), 'mode read');
      r.PollRadioState;
      CheckTrue(r.IsConnected, 'and the second poll too');
      CheckEquals(3, CountOf('CmdGetFreq'), 'the probe and two polls, each served once');
      CheckEquals(2, CountOf('CmdSendTX'), 'no query lost to a connection the peer had closed');
      CheckTrue(ConnectionCount >= 9, 'one connection per query');
   finally
      r.Free;
      StopServer;
   end;
end;

procedure TRadioDXLabCommanderTests.Test_ReplySplitAcrossTwoWrites_IsRead;
var
   r: TCommanderProbe;
begin
   BeginTest('Test_ReplySplitAcrossTwoWrites_IsRead');
   r := TCommanderProbe.CreateFor(StartServer);
   try
      FSplitReply := True;
      CheckEquals(0, r.Connect, 'a reply in two pieces still answers');
      r.PollRadioState;
      CheckEquals(14010500, r.frequency[nrVFOA], 'and is read whole');
      CheckEquals(Ord(rmCW), Ord(r.mode[nrVFOA]), '');
   finally
      r.Free;
      StopServer;
   end;
end;

procedure TRadioDXLabCommanderTests.Test_ReplyFollowedByCRLF_IsRead;
var
   r: TCommanderProbe;
begin
   BeginTest('Test_ReplyFollowedByCRLF_IsRead');
   r := TCommanderProbe.CreateFor(StartServer);
   try
      FAppendCRLF := True;
      CheckEquals(0, r.Connect, 'a reply with CR/LF answers');
      r.PollRadioState;
      r.PollRadioState;
      CheckTrue(r.IsConnected, 'the CR/LF ahead of each next reply does not confuse it');
      CheckEquals(14010500, r.frequency[nrVFOA], '');
      CheckEquals(Ord(rmCW), Ord(r.mode[nrVFOA]), '');
      CheckEquals(1, ConnectionCount, 'and the connection is kept');
   finally
      r.Free;
      StopServer;
   end;
end;

procedure TRadioDXLabCommanderTests.Test_RigNotReporting_ConnectedButNotOperational;
var
   r: TCommanderProbe;
begin
   BeginTest('Test_RigNotReporting_ConnectedButNotOperational');
   r := TCommanderProbe.CreateFor(StartServer);
   try
      SetReply('CmdGetFreq', '<CmdFreq:4>.000');
      CheckEquals(0, r.Connect, 'Commander is there');
      CheckTrue(r.IsConnected, 'so the link is up');
      CheckFalse(r.IsOperational, 'but the rig is not reporting: alert stays on');
      CheckEquals(0, r.frequency[nrVFOA], '.000 is not stored as a frequency');

      SetReply('CmdGetFreq', REPLY_FREQ);
      r.PollRadioState;
      CheckTrue(r.IsOperational, 'the rig reports, and it is operational');
   finally
      r.Free;
      StopServer;
   end;
end;

procedure TRadioDXLabCommanderTests.Test_PeerDownThenBackUp_Reconnects;
var
   r: TCommanderProbe;
   port: Word;
begin
   BeginTest('Test_PeerDownThenBackUp_Reconnects');
   port := StartServer;
   r := TCommanderProbe.CreateFor(port);
   try
      FRefuse := True;
      CheckTrue(r.Connect <> 0, 'a peer that refuses is not connected');
      CheckFalse(r.IsConnected, '');

      FRefuse := False;
      CheckEquals(0, r.Connect, 'the same peer back in service');
      CheckTrue(r.IsConnected, '');

      FRefuse := True;
      r.PollRadioState;
      CheckFalse(r.IsConnected, 'a poll nobody answers drops the link');

      FRefuse := False;
      CheckEquals(0, r.Connect, 'and the next Connect brings it back');
      r.PollRadioState;
      CheckTrue(r.IsConnected, '');
   finally
      r.Free;
      StopServer;
   end;
end;

procedure TRadioDXLabCommanderTests.Test_QueuedTXDoesNotSurviveADroppedLink;
var
   r: TCommanderProbe;
begin
   BeginTest('Test_QueuedTXDoesNotSurviveADroppedLink');
   r := TCommanderProbe.CreateFor(StartServer);
   try
      CheckEquals(0, r.Connect, '');
      FRefuse := True;
      r.PollRadioState;
      CheckFalse(r.IsConnected, 'link dropped');

      r.Transmit;                       // the operator keys while Commander is away

      FRefuse := False;
      CheckEquals(0, r.Connect, 'Commander is back');
      r.DrainUrgentQueue;
      Sleep(200);
      CheckEquals(0, CountOf('CmdTX'), 'the stale CmdTX never reaches the wire');

      (* The paired positive: a CmdTX queued on a live link IS sent. *)
      r.Transmit;
      r.DrainUrgentQueue;
      CheckTrue(WaitForCount('CmdTX', 1, WAIT_MS), 'a CmdTX on a live link is sent');
   finally
      r.Free;
      StopServer;
   end;
end;

procedure TRadioDXLabCommanderTests.Test_ReceiveJumpsTheQueue;
var
   r: TCommanderProbe;
   order: string;
begin
   BeginTest('Test_ReceiveJumpsTheQueue');
   r := TCommanderProbe.CreateFor(StartServer);
   try
      CheckEquals(0, r.Connect, '');
      ClearReceived;
      r.SetFrequency(14025000, nrVFOA, rmNone);
      r.Split(True);
      r.Receive;
      r.DrainUrgentQueue;
      CheckTrue(WaitForCount('CmdSplit', 1, WAIT_MS), 'all three went');
      order := ReceivedSnapshot;
      CheckEquals(1, Pos('CmdRX', order), 'CmdRX first, though queued last: ' + order);
      CheckTrue(Pos('CmdSetFreq', order) < Pos('CmdSplit', order), 'the rest keep their order');
   finally
      r.Free;
      StopServer;
   end;
end;

(* A peer that hangs up after every message serves each on its own connection,
  and a server may serve connections side by side.  The driver waits for each
  hang-up before the next message, so the peer still sees them in order, as
  the operator's actions happened. *)
procedure TRadioDXLabCommanderTests.Test_PeerThatClosesAfterEveryMessage_SetsKeepTheirOrder;
var
   r: TCommanderProbe;
   i: integer;
   expected: TStringList;
begin
   BeginTest('Test_PeerThatClosesAfterEveryMessage_SetsKeepTheirOrder');
   expected := TStringList.Create;
   r := TCommanderProbe.CreateFor(StartServer);
   try
      for i := 1 to 3 do
         begin
         expected.Add('CmdSplit|<1:2>on');
         expected.Add('CmdQSXSplit|<xcvrfreq:5>' + IntToStr(14030 + i) +
                      '<SuppressDual:1>Y<SuppressModeChange:1>Y');
         end;
      FCloseAfterEvery := True;
      CheckEquals(0, r.Connect, 'probe answered');
      ClearReceived;
      for i := 1 to 3 do
         begin
         r.Split(True);
         r.SetFrequency(14030000 + i * 1000, nrVFOB, rmNone);
         end;
      r.DrainUrgentQueue;
      CheckTrue(WaitForCount('CmdQSXSplit', 3, WAIT_MS), 'all six arrived');
      CheckEquals(expected.CommaText, ReceivedSnapshot, 'exactly in the order sent');
      CheckTrue(r.IsConnected, 'a hang-up after a set is not a lost link');
   finally
      r.Free;
      StopServer;
      expected.Free;
   end;
end;

procedure TRadioDXLabCommanderTests.Test_UnansweredTXQueryStopsBeingAsked;
var
   r: TCommanderProbe;
   i: integer;
begin
   BeginTest('Test_UnansweredTXQueryStopsBeingAsked');
   r := TCommanderProbe.CreateFor(StartServer);
   try
      SetReply('CmdSendTX', '');        // "Not all transceivers respond"
      CheckEquals(0, r.Connect, '');
      for i := 1 to COMMANDER_TX_QUERY_MAX_MISSES + 2 do
         begin
         r.PollRadioState;
         end;
      CheckEquals(COMMANDER_TX_QUERY_MAX_MISSES, CountOf('CmdSendTX'),
                  'asked until it was plainly unanswered, and no more');
      CheckTrue(r.IsConnected, 'an unanswered TX query is not a lost link');
      CheckEquals(COMMANDER_TX_QUERY_MAX_MISSES + 3, CountOf('CmdGetFreq'),
                  'the frequency kept being polled');

      (* Paired: a fresh Connect gives the question another hearing. *)
      SetReply('CmdSendTX', REPLY_TX);
      CheckEquals(0, r.Connect, '');
      r.PollRadioState;
      CheckEquals(COMMANDER_TX_QUERY_MAX_MISSES + 1, CountOf('CmdSendTX'), 'asked again after a reconnect');
   finally
      r.Free;
      StopServer;
   end;
end;

(* ---- no transport -------------------------------------------------------- *)

procedure TRadioDXLabCommanderTests.Test_StopAndUnkeyWithNoLink_QueueNothing;
var
   r: TCommanderCapture;
begin
   BeginTest('Test_StopAndUnkeyWithNoLink_QueueNothing');
   r := TCommanderCapture.Create;
   try
      r.Receive;
      r.StopCW;
      CheckEquals(0, r.sent.Count, 'nothing to stop on a radio with no link');
      r.Transmit;
      CheckEquals(1, r.sent.Count, 'but a key IS queued (and discarded by the next Connect)');
   finally
      r.Free;
   end;
end;

(* CmdSetTXFreq with split off retunes the RECEIVER, and TR4W learns split a
  poll late -- so a VFO B write is CmdQSXSplit in every state, and the
  state-dependent shape is pinned out, including the race that motivated it:
  split reported on, the operator turns it off, a QSX click inside the poll. *)
procedure TRadioDXLabCommanderTests.Test_VFOBWrite_IsAlwaysQSXSplitNeverSetTXFreq;
var
   r: TCommanderCapture;
   qsx: string;
begin
   BeginTest('Test_VFOBWrite_IsAlwaysQSXSplitNeverSetTXFreq');
   r := TCommanderCapture.Create;
   try
      r.UseSeparator('.');
      qsx := CommanderMessage('CmdQSXSplit',
                              CommanderField('xcvrfreq', '14030') +
                              CommanderField('SuppressDual', 'Y') +
                              CommanderField('SuppressModeChange', 'Y'));

      r.SetFrequency(14030000, nrVFOB, rmCW);
      CheckEquals(1, r.sent.Count, 'split off: one message, and no mode set for VFO B');
      CheckEquals(qsx, r.sent[0], 'QSX split, Dual and TX mode left alone');

      r.sent.Clear;
      r.ProcessMsg('<CmdSplit:2>ON');
      r.SetFrequency(14030000, nrVFOB, rmNone);
      CheckEquals(qsx, r.All, 'split reported on: the same message');

      r.sent.Clear;
      r.Split(False);                        // reported state still says ON
      r.SetFrequency(14030000, nrVFOB, rmNone);
      CheckEquals(0, Pos('CmdSetTXFreq', r.All),
                  'split just turned off, not yet polled: still no CmdSetTXFreq');
      CheckTrue(Pos(qsx, r.All) > 0, 'the QSX goes as CmdQSXSplit');
   finally
      r.Free;
   end;
end;

procedure TRadioDXLabCommanderTests.Test_StartupCommandMustBeOneMessage;
var
   r: TCommanderCapture;
   reason: string;
begin
   BeginTest('Test_StartupCommandMustBeOneMessage');
   r := TCommanderCapture.Create;
   try
      CheckFalse(r.StartupCommandIsSendable('KY <;', reason), 'a K3 startup command left configured');
      CheckTrue(reason <> '', 'and the log is told why');
      CheckTrue(r.StartupCommandIsSendable(CommanderMessage('CmdSyncIcom', ''), reason),
                'a Commander message goes out');
   finally
      r.Free;
   end;
end;

procedure TRadioDXLabCommanderTests.Test_VFOAWrite_IsSetFreqThenSetMode_NeverSetFreqMode;
var
   r: TCommanderCapture;
begin
   BeginTest('Test_VFOAWrite_IsSetFreqThenSetMode_NeverSetFreqMode');
   r := TCommanderCapture.Create;
   try
      r.UseSeparator('.');
      r.SetFrequency(14025000, nrVFOA, rmUSB);
      CheckEquals(2, r.sent.Count, 'frequency, then mode');
      CheckEquals(CommanderMessage('CmdSetFreq', CommanderField('xcvrfreq', '14025')), r.sent[0], '');
      CheckEquals(CommanderMessage('CmdSetMode', CommanderField('1', 'USB')), r.sent[1], '');
      CheckEquals(0, Pos('CmdSetFreqMode', r.All), 'never CmdSetFreqMode: it resets split');

      (* Paired: a mode the radio already reports is not sent again. *)
      r.sent.Clear;
      r.ProcessMsg('<CmdMode:3>USB');
      r.SetFrequency(14026000, nrVFOA, rmUSB);
      CheckEquals(1, r.sent.Count, 'mode already USB: frequency only');
   finally
      r.Free;
   end;
end;

procedure TRadioDXLabCommanderTests.Test_FrequencyWrittenInTheLocaleSeparator;
var
   r: TCommanderCapture;
begin
   BeginTest('Test_FrequencyWrittenInTheLocaleSeparator');
   r := TCommanderCapture.Create;
   try
      r.UseSeparator(',');
      r.SetFrequency(14025500, nrVFOA, rmNone);
      CheckEquals(CommanderMessage('CmdSetFreq', CommanderField('xcvrfreq', '14025,500')),
                  r.All, 'a comma locale writes a comma');
      r.sent.Clear;
      r.UseSeparator('.');
      r.SetFrequency(14025500, nrVFOA, rmNone);
      CheckEquals(CommanderMessage('CmdSetFreq', CommanderField('xcvrfreq', '14025.500')),
                  r.All, 'a period locale writes a period');
   finally
      r.Free;
   end;
end;

procedure TRadioDXLabCommanderTests.Test_RepliesApplyToTheRadio;
var
   r: TCommanderCapture;
begin
   BeginTest('Test_RepliesApplyToTheRadio');
   r := TCommanderCapture.Create;
   try
      r.ProcessMsg('<CmdFreq:10>14,010.500');
      CheckEquals(14010500, r.frequency[nrVFOA], 'RX frequency to VFO A');
      CheckEquals(Ord(rb20m), Ord(r.band[nrVFOA]), 'and its band');
      r.ProcessMsg('<CmdFreq:4>.000');
      CheckEquals(14010500, r.frequency[nrVFOA], '.000 keeps what was known');

      r.ProcessMsg('<CmdMode:4>CW-R');
      CheckEquals(Ord(rmCWRev), Ord(r.mode[nrVFOA]), 'mode');
      r.ProcessMsg('<CmdMode:0>');
      CheckEquals(Ord(rmCWRev), Ord(r.mode[nrVFOA]), 'an unreported mode keeps the last');

      r.ProcessMsg('<CmdTXFreq:10>14,015.000');
      CheckEquals(0, r.frequency[nrVFOB], 'TX frequency is not VFO B outside split');
      r.ProcessMsg('<CmdSplit:2>ON');
      CheckTrue(r.IsSplitEnabled, 'split on');
      r.ProcessMsg('<CmdTXFreq:10>14,015.000');
      CheckEquals(14015000, r.frequency[nrVFOB], 'in split it is');
      r.ProcessMsg('<CmdSplit:3>OFF');
      CheckFalse(r.IsSplitEnabled, 'split off');
      CheckEquals(0, r.frequency[nrVFOB], 'and VFO B is unknown again, not stale');

      r.ProcessMsg('<CmdTX:2>ON');
      CheckTrue(r.IsTransmitting, 'TX on');
      r.ProcessMsg('<CmdTX:3>OFF');
      CheckFalse(r.IsTransmitting, 'TX off');
   finally
      r.Free;
   end;
end;

procedure TRadioDXLabCommanderTests.Test_EveryAbstractIsCallable;
var
   r: TCommanderCapture;
begin
   BeginTest('Test_EveryAbstractIsCallable');
   r := TCommanderCapture.Create;
   try
      r.ToggleMode(nrVFOA);
      r.SetBand(rb40m, nrVFOA);
      r.ToggleBand(nrVFOA);
      r.SetFilter(rfNarrow, nrVFOA);
      r.SetFilterHz(500, nrVFOA);
      r.MemoryKeyer(1);
      r.RITClear(nrVFOA);
      r.XITClear(nrVFOA);
      r.RITOn(nrVFOA);
      r.RITOff(nrVFOA);
      r.XITOn(nrVFOA);
      r.XITOff(nrVFOA);
      r.SetRITFreq(nrVFOA, 100);
      r.SetXITFreq(nrVFOA, 100);
      r.RITBumpUp;
      r.RITBumpDown;
      r.VFOBumpUp(nrVFOA);
      r.VFOBumpDown(nrVFOA);
      r.BufferCW('TEST');
      r.SendCW;
      r.SetCWSpeed(30);
      r.SendToRadio(nrVFOA, 'CmdSyncIcom', '');
      CheckTrue(Pos('CmdSyncIcom', r.All) > 0, 'the three-argument SendToRadio frames a message');
      CheckTrue(r.MemoryKeyer(2), 'MemoryKeyer answers True: not done');
   finally
      r.Free;
   end;
end;

(* EXHAUSTIVE: the whole capability set, not a membership test, so adding or
  losing ANY flag fails here and has to be argued for. *)
procedure TRadioDXLabCommanderTests.Test_CapabilitiesAndRegistrationAreExactly;
const
   EXPECTED: TRadioCapabilitySet = [rcReadSplit, rcReadTXStatus];
var
   r: TFactoryRadioBase;
   cap: TRadioCapability;
begin
   BeginTest('Test_CapabilitiesAndRegistrationAreExactly');
   r := TDXLabCommanderRadio.Create;
   try
      for cap := Low(TRadioCapability) to High(TRadioCapability) do
         begin
         CheckEquals(Ord(cap in EXPECTED), Ord(r.Supports(cap)),
                     'capability ordinal ' + IntToStr(Ord(cap)));
         end;
      CheckFalse(r.Capabilities.HasXIT, 'no XIT message');
      CheckFalse(r.SupportsCWByCAT, 'CW is the keyer factory''s, not Commander''s');
   finally
      r.Free;
   end;

   CheckTrue(IsRegisteredId(DXLAB_COMMANDER_ID), 'registered by id');
   CheckEquals('DXLab Commander', DisplayNameId(DXLAB_COMMANDER_ID), 'display name');
   CheckTrue(SupportsNetworkId(DXLAB_COMMANDER_ID), 'network');
   CheckFalse(SupportsSerialId(DXLAB_COMMANDER_ID), 'and nothing else');
   CheckEquals(52002, RegisteredNetworkPortId(DXLAB_COMMANDER_ID), 'the document''s default port');
   CheckFalse(RegisteredDiscoverableId(DXLAB_COMMANDER_ID), 'no discovery');
   CheckTrue(CapabilitiesForId(DXLAB_COMMANDER_ID) = EXPECTED, 'the registry answers the same set');

   r := CreateInstanceForLinkId(DXLAB_COMMANDER_ID, rlNetwork);
   try
      CheckTrue(r is TDXLabCommanderRadio, 'the network link builds this driver');
   finally
      r.Free;
   end;
end;

procedure TRadioDXLabCommanderTests.RunAllTests;
begin
   try
      Test_PeerThatStaysOpen_PollsOnOneConnection;
      Test_PeerThatClosesAfterEachReply_StillPolls;
      Test_ReplySplitAcrossTwoWrites_IsRead;
      Test_ReplyFollowedByCRLF_IsRead;
      Test_RigNotReporting_ConnectedButNotOperational;
      Test_PeerDownThenBackUp_Reconnects;
      Test_QueuedTXDoesNotSurviveADroppedLink;
      Test_ReceiveJumpsTheQueue;
      Test_PeerThatClosesAfterEveryMessage_SetsKeepTheirOrder;
      Test_UnansweredTXQueryStopsBeingAsked;
      Test_StopAndUnkeyWithNoLink_QueueNothing;
      Test_VFOBWrite_IsAlwaysQSXSplitNeverSetTXFreq;
      Test_StartupCommandMustBeOneMessage;
      Test_VFOAWrite_IsSetFreqThenSetMode_NeverSetFreqMode;
      Test_FrequencyWrittenInTheLocaleSeparator;
      Test_RepliesApplyToTheRadio;
      Test_EveryAbstractIsCallable;
      Test_CapabilitiesAndRegistrationAreExactly;
   finally
      StopServer;
      FreeAndNil(FReceived);
      FreeAndNil(FReplies);
      FreeAndNil(FLock);
   end;
end;

end.
