(*
 Copyright Thomas M. Schaefer, NY4I (c) 2026.
 This file is part of TR4W  (SRC)
 TR4W is free software: you can redistribute it and/or
 modify it under the terms of the GNU General Public License as
 published by the Free Software Foundation, either version 2 of the
 License, or (at your option) any later version.
 TR4W is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.
 You should have received a copy of the GNU General
     Public License along with TR4W in  GPL_License.TXT.
If not, ref:
http://www.gnu.org/licenses/gpl-3.0.txt
*)
unit uRadioDXLabCommander;
{$I ..\tr4w.inc}

(* DXLAB COMMANDER AS A RADIO (issue 172).  NOT BENCH-VALIDATED.

  Commander is AA6YQ's rig-control program.  It owns the radio's CAT port and
  answers TCP/IP messages on port 52002 by default, so TR4W drives whatever rig
  Commander drives, through one registration.  Like TCI, the "model" is the
  server: there is no per-rig fan-out.

  THE PROTOCOL IS DXLAB'S OWN DOCUMENT, "Commander TCP/IP Messages"; the wire
  format lives in uDXLabCommanderProtocol, which states what the document does
  and does not say.  Written against that document and a fake peer only -- no
  real Commander has answered this code.  docs/BENCH_QUEUE.md lists what a
  bench run has to settle.

  WHAT TR4W DOES WITH IT (the minimum set issue 172 proposed):
    read   RX frequency (CmdGetFreq), mode (CmdSendMode), split (CmdSendSplit),
           TX/RX (CmdSendTX), and the TX frequency while split (CmdGetTXFreq);
    set    RX frequency (CmdSetFreq), mode (CmdSetMode), split (CmdSplit),
           the TX frequency (CmdQSXSplit), PTT (CmdTX / CmdRX).
  NOT DONE, deliberately: CW (cwchars -- TR4W keys CW through its keyer
  factory, and the issue left it out), RIT/XIT (the document has no command),
  the user-defined sequences (seqindex / seqname), CmdSyncIcom.

  THE TRANSPORT IS ONE QUESTION AT A TIME, ON THE POLLING THREAD.
    - Commander PUSHES NOTHING: every reply answers a query.  So there is no
      reading thread.  The polling thread asks, waits a bounded time for the
      one field that answers it, and applies it -- the HamLib Direct shape.
    - Every write is queued.  SendToRadio, from any thread, only appends to
      FQueue; DrainUrgentQueue, which the polling thread calls every tick ahead
      of its poll, writes them.  So the main thread never waits on a socket
      (a band-map click is not a connect), and only one thread ever reads or
      writes FLink.  That thread is FLink's only reader, so the Indy calls
      that read (Connect's own Connected, CheckForDataOnSource) have no second
      reader to race -- the 2026-10-25 hang needs two.  Other threads only
      ever CLOSE it (InterruptLink), with field reads first (uIndyLink).
    - The document does not say whether Commander keeps a connection open
      after it answers.  DXKeeper, its sibling, reads one command per
      connection.  So Connect FINDS OUT, once: after the probe's answer it
      waits COMMANDER_CLOSE_PROBE_MS to see whether the peer hangs up.
        * A peer that stays open gets every message, query and set, on that
          one connection -- in order, because TCP keeps one connection's bytes
          in order.
        * A peer that hangs up gets a fresh connection per message, and after
          a SET the driver waits (COMMANDER_SET_SETTLE_MS at most) for the
          hang-up before sending the next.  Without that wait two sets could
          be served out of order -- a server may handle connections side by
          side -- and CmdSplit arriving after CmdSetTXFreq retunes the
          receiver.
      If a kept connection turns out to be closed anyway, the message is sent
      once more on a fresh one.
    - A queued command does not survive a dropped link.  Connect and
      Disconnect empty the queue: a CmdTX typed while Commander was away must
      never key the radio when it comes back.

  SPLIT, AND TWO TRAPS IN COMMANDER'S OWN SEMANTICS.
    - CmdSetTXFreq with split OFF sets the SELECTED VFO.  TR4W's split callers
      (the band map's QSX, WSJT-X, the TCI server) write VFO B first and ask
      for split after, so a VFO B write would retune the receiver onto the DX's
      listening frequency.  So EVERY VFO B write goes out as CmdQSXSplit,
      which sets the TX frequency AND split in one message, with Dual and the
      TX mode left alone -- right whether or not split is already on, so it
      does not depend on a split state TR4W learns a poll late.
    - CmdSetFreqMode resets split unless told otherwise.  It is never used:
      frequency and mode go as CmdSetFreq and CmdSetMode.

  NUMBERS.  Frequencies are read with CmdGetFreq, whose separators the document
  fixes (',' thousands, '.' decimal), never CmdSendFreq, whose separators are
  the locale's.  Frequencies are WRITTEN in the locale's decimal separator, as
  the document requires; it is taken once, at construction, from
  FormatSettings, because uADIF and others change the global for a moment on
  the main thread and this driver formats on the polling thread.  A whole-kHz
  frequency carries no separator at all. *)

interface

uses
   SysUtils, Classes, SyncObjs,
   IdTCPClient,
   uFactoryRadioBase, uRadioBand, uRadioRegistry, uDXLabCommanderProtocol, VC;

type
   (* How a query ended.  Only caLinkFailed says Commander is unreachable; a
     query nobody answered may be one this rig does not support (the document:
     "Not all transceivers respond" to CmdSendTX). *)
   TCommanderAnswer = (caAnswered, caNoAnswer, caLinkFailed);

   TDXLabCommanderRadio = class(TFactoryRadioBase)
   private
      FLink: TIdTCPClient;            // touched only by the polling thread (InterruptLink closes it)
      FQueue: TStringList;            // messages waiting for DrainUrgentQueue
      FQueueLock: TCriticalSection;
      FLinkUp: boolean;               // Commander answered, and nothing has failed since
      FRigReporting: boolean;         // the last CmdFreq was a frequency, not ".000"
      FPeerClosesAfterReply: boolean; // learned: open a connection per query
      FTXQueryMisses: integer;        // CmdSendTX asked and not answered, in a row
      FTXQueryRefused: boolean;       // ... often enough to stop asking this session

      procedure ClearQueue;
      procedure CloseLink;
      function  OpenLink: boolean;
      function  ReadReplyField(out aName, aValue: string): boolean;
      function  Query(const aCommand, aExpectedField: string): TCommanderAnswer;
      function  SendSet(const aMessage: string): boolean;
      function  PeerHangsUpWithin(aTimeoutMs: integer): boolean;
      procedure ApplyField(const aName, aValue: string);
      function  FrequencyParameter(aHz: LongInt): string;
   protected
      (* How long a query waits for its answer.  Commander answers from its own
        cache, so a local reply is quick; this is short because the polling
        thread is also the PTT path -- a CmdRX waits behind the poll in
        progress.  A field so a test can shorten it. *)
      FReplyTimeoutMs: integer;
      (* For frequencies SENT; see the unit header.  A field so a test can
        state the comma locale rather than inherit the build machine's. *)
      FDecimalSeparator: Char;

      function  GetISConnected: boolean; override;
      function  GetIsOperational: boolean; override;
      function  LinkIsOpen: boolean; override;
   public
      constructor Create; reintroduce;
      destructor  Destroy; override;

      function  Connect: integer; override;
      procedure Disconnect; override;
      procedure InterruptLink; override;

      procedure SendToRadio(s: string); overload; override;
      procedure SendToRadio(whichVFO: TVFO; sCmd: string; sData: string); overload; override;
      procedure SendToRadioUrgent(const s: string); override;
      function  StartupCommandIsSendable(const cmd: string;
                                         out reason: string): boolean; override;
      procedure DrainUrgentQueue; override;
      procedure PollRadioState; override;
      procedure ProcessMsg(msg: string); override;

      procedure Transmit; override;
      procedure Receive; override;

      procedure BufferCW(msg: string); override;
      procedure SendCW; override;
      procedure StopCW; override;
      procedure SetCWSpeed(speed: integer); override;

      procedure SetFrequency(freq: longint; vfo: TVFO; mode: TRadioMode); override;
      procedure SetMode(mode: TRadioMode; vfo: TVFO = nrVFOA); override;
      function  ToggleMode(vfo: TVFO = nrVFOA): TRadioMode; override;
      procedure Split(splitOn: boolean); override;

      procedure RITClear(vfo: TVFO); override;
      procedure XITClear(vfo: TVFO); override;
      procedure RITBumpDown; override;
      procedure RITBumpUp; override;
      procedure RITOn(vfo: TVFO); override;
      procedure RITOff(vfo: TVFO); override;
      procedure XITOn(vfo: TVFO); override;
      procedure XITOff(vfo: TVFO); override;
      procedure SetRITFreq(vfo: TVFO; hz: integer); override;
      procedure SetXITFreq(vfo: TVFO; hz: integer); override;

      procedure SetBand(band: TRadioBand; vfo: TVFO = nrVFOA); override;
      function  ToggleBand(vfo: TVFO = nrVFOA): TRadioBand; override;
      procedure SetFilter(filter: TRadioFilter; vfo: TVFO = nrVFOA); override;
      function  SetFilterHz(hz: integer; vfo: TVFO = nrVFOA): integer; override;
      function  MemoryKeyer(mem: integer): boolean; override;
      procedure VFOBumpDown(whichVFO: TVFO); override;
      procedure VFOBumpUp(whichVFO: TVFO); override;
   end;

const
   (* Unanswered CmdSendTX queries in a row before TR4W stops asking for the
     session.  Three, so one lost reply cannot switch it off. *)
   COMMANDER_TX_QUERY_MAX_MISSES = 3;

implementation

uses
   IdGlobal, IdException, IdExceptionCore,
   uHostResolve, uIndyLink;

const
   COMMANDER_REPLY_TIMEOUT_MS = 500;

   (* A field longer than this is not a Commander reply; reading it would only
     wait out the timeout on bytes that will never come. *)
   COMMANDER_MAX_FIELD_LENGTH = 1024;

   (* Fields read while waiting for the one a query asked for.  A peer that
     sends something else first is tolerated; one that never stops is not. *)
   COMMANDER_MAX_STRAY_FIELDS = 8;

   COMMANDER_POLL_INTERVAL_MS = 250;

   (* How long Connect watches, after the probe's answer, for the peer to hang
     up.  A peer that closes after a reply does so at once; one that keeps the
     connection costs this once per Connect. *)
   COMMANDER_CLOSE_PROBE_MS = 150;

   (* After a set on a peer that hangs up per message: the most the driver
     waits for that hang-up before sending the next message. *)
   COMMANDER_SET_SETTLE_MS = 250;

(* ------------------------------------------------------------- lifecycle -- *)

constructor TDXLabCommanderRadio.Create;
begin
   inherited Create(ProcessMsg);

   radioModel := 'DXLab Commander';

   (* Commander pushes nothing, so the poll is the only way state arrives. *)
   requiresPolling := True;
   pollingInterval := COMMANDER_POLL_INTERVAL_MS;
   autoUpdateCommand := '';
   bAddTermination := False;   // a message is length-delimited; see COMMANDER_MESSAGE_TERMINATOR

   FReplyTimeoutMs := COMMANDER_REPLY_TIMEOUT_MS;
   FDecimalSeparator := FormatSettings.DecimalSeparator;

   (* WHAT TR4W READS FROM COMMANDER, AND NOTHING ELSE.
       rcReadSplit     CmdSendSplit
       rcReadTXStatus  CmdSendTX -- "not all transceivers respond", so a rig
                       that never answers is stopped being asked (see
                       COMMANDER_TX_QUERY_MAX_MISSES); the flag says TR4W
                       reads it, not that every rig answers.
     NOT declared:
       rcReadVFOB      CmdGetTXFreq is the TX frequency, not the unselected
                       VFO's frequency and mode; it fills VFO B only in split.
       rcReadRIT       no RIT/XIT message exists.
       rcCWByCAT       cwchars exists; TR4W does not use it (issue 172).
       rcCWSpeedSync   no speed message exists.
       rcDataMode      DATA-U/DATA-L arrive as modes, not as a sub-mode.
     Pinned, as a whole set, by uTestRadioDXLabCommander. *)
   FCapabilities.Flags := FCapabilities.Flags + [rcReadSplit, rcReadTXStatus];
   FCapabilities.HasXIT := False;

   FLink := TIdTCPClient.Create(nil);
   FQueue := TStringList.Create;
   FQueueLock := TCriticalSection.Create;
end;

destructor TDXLabCommanderRadio.Destroy;
begin
   (* The polling thread has stopped before any radio is freed (issue #104),
     so nothing else holds FLink or the queue now. *)
   if FLink <> nil then
      begin
      CloseLink;
      FreeAndNil(FLink);
      end;
   FreeAndNil(FQueue);
   FreeAndNil(FQueueLock);
   inherited Destroy;
end;

(* A NEW LINK STARTS FROM NOTHING.  Called on the polling thread, at startup
  and on every reconnect.  It asks one question -- the RX frequency -- and the
  link is up when Commander answers it. *)
function TDXLabCommanderRadio.Connect: integer;
begin
   Result := -1;

   (* What TFactoryRadioBase.Connect does for every radio, which this one does
     not call: a fresh hearing on speed sync, and no TX inhibit carried over. *)
   ResetCWSpeedSync;
   SetTXInhibited(False, '');

   ClearQueue;
   FLinkUp := False;
   FRigReporting := False;
   FPeerClosesAfterReply := False;
   FTXQueryMisses := 0;
   FTXQueryRefused := False;
   CloseLink;

   if (radioAddress = '') or (radioPort = 0) then
      begin
      logger.Error('[Commander] no address or port configured (%s:%d)', [radioAddress, radioPort]);
      Exit;
      end;

   logger.Info('[Commander] connecting to %s:%d', [radioAddress, radioPort]);
   if Query('CmdGetFreq', COMMANDER_FIELD_FREQ) = caAnswered then
      begin
      FLinkUp := True;
      Result := 0;
      FPeerClosesAfterReply := PeerHangsUpWithin(COMMANDER_CLOSE_PROBE_MS);
      if FPeerClosesAfterReply then
         begin
         CloseLink;
         logger.Info('[Commander] answering at %s:%d; it closes after each reply -- one connection per message',
                     [radioAddress, radioPort]);
         end
      else
         begin
         logger.Info('[Commander] answering at %s:%d; it keeps the connection -- one connection for everything',
                     [radioAddress, radioPort]);
         end;
      end
   else
      begin
      logger.Info('[Commander] no answer from %s:%d', [radioAddress, radioPort]);
      CloseLink;
      end;
end;

procedure TDXLabCommanderRadio.Disconnect;
begin
   FLinkUp := False;
   FRigReporting := False;
   ClearQueue;
   CloseLink;
end;

(* FROM ANOTHER THREAD, WHILE THE POLLING THREAD MAY BE INSIDE A CONNECT OR A
  READ: close the socket so that call returns, and free nothing.  Field reads
  only before the close -- never Indy's Connected (uIndyLink). *)
procedure TDXLabCommanderRadio.InterruptLink;
begin
   FLinkUp := False;
   if IndyLinkIsOpen(FLink) then
      begin
      try
         FLink.Disconnect(False);
      except
         on E: Exception do
            begin
            logger.Debug('[Commander] closing the link raised: %s - %s', [E.ClassName, E.Message]);
            end;
      end;
      end;
end;

function TDXLabCommanderRadio.GetISConnected: boolean;
begin
   Result := FLinkUp;
end;

(* Commander answering ".000" is Commander up and the rig not reporting -- the
  operator's radio is not under control, so the alert colour stays on. *)
function TDXLabCommanderRadio.GetIsOperational: boolean;
begin
   Result := FLinkUp and FRigReporting;
end;

(* This class writes through its own connection, opened per need, so "the link
  is open" means what IsConnected means: Commander answered and nothing has
  failed since. *)
function TDXLabCommanderRadio.LinkIsOpen: boolean;
begin
   Result := FLinkUp;
end;

(* ------------------------------------------------------------- transport -- *)

procedure TDXLabCommanderRadio.ClearQueue;
var
   dropped: integer;
begin
   FQueueLock.Enter;
   try
      dropped := FQueue.Count;
      FQueue.Clear;
   finally
      FQueueLock.Leave;
   end;
   if dropped > 0 then
      begin
      logger.Info('[Commander] %d queued command(s) discarded -- the link is new or gone', [dropped]);
      end;
end;

(* Polling thread (or after it has stopped).  Also empties what Indy has
  buffered: the handler is reused across connections, and a byte left over
  from the last one would otherwise make Indy's Connect think it is still
  connected. *)
procedure TDXLabCommanderRadio.CloseLink;
begin
   if (FLink = nil) or (FLink.IOHandler = nil) then
      begin
      Exit;
      end;
   try
      FLink.Disconnect(False);
   except
      on E: Exception do
         begin
         logger.Debug('[Commander] closing the link raised: %s - %s', [E.ClassName, E.Message]);
         end;
   end;
   FLink.IOHandler.InputBuffer.Clear;
end;

function TDXLabCommanderRadio.OpenLink: boolean;
begin
   Result := IndyLinkIsOpen(FLink);
   if Result then
      begin
      Exit;
      end;

   if (radioAddress = '') or (radioPort = 0) then
      begin
      Exit;
      end;

   CloseLink;   // a closed-gracefully handler still holds its binding
   IndyLinkOwnHandler(FLink, nil);
   FLink.Port := radioPort;
   FLink.ConnectTimeout := INDY_LINK_CONNECT_TIMEOUT_MS;
   FLink.ReadTimeout := FReplyTimeoutMs;
   FLink.IOHandler.ReadTimeout := FReplyTimeoutMs;   // what ReadString waits
   try
      FLink.Host := AnsiString(ResolveHostForConnect(radioAddress));
      FLink.Connect;
      Result := True;
   except
      on E: Exception do
         begin
         logger.Debug('[Commander] connect to %s:%d failed: %s - %s',
                      [radioAddress, radioPort, E.ClassName, E.Message]);
         CloseLink;
         end;
   end;
end;

(* ONE ADIF FIELD, READ BY ITS DECLARED LENGTH.  First the header, up to the
  closing angle bracket; after it, exactly that many characters.  Anything
  ahead of the opening bracket (a CR/LF, say) is skipped by the header parser.  False when nothing arrived in time or the
  header is not a field; a closed connection raises, for Query to handle. *)
function TDXLabCommanderRadio.ReadReplyField(out aName, aValue: string): boolean;
var
   header: string;
   fieldLength: integer;
begin
   Result := False;
   aName := '';
   aValue := '';

   header := FLink.IOHandler.ReadLn('>', FReplyTimeoutMs, -1, IndyTextEncoding_8Bit);
   if FLink.IOHandler.ReadLnTimedout then
      begin
      Exit;
      end;

   if (not TryParseCommanderFieldHeader(header, aName, fieldLength)) or
      (fieldLength > COMMANDER_MAX_FIELD_LENGTH) then
      begin
      logger.Warn('[Commander] not a reply field: "%s"', [header]);
      aName := '';
      Exit;
      end;

   if fieldLength > 0 then
      begin
      aValue := FLink.IOHandler.ReadString(fieldLength, IndyTextEncoding_8Bit);
      end;
   Result := True;
end;

(* ASK ONE QUESTION AND APPLY THE ANSWER.  Polling thread only. *)
function TDXLabCommanderRadio.Query(const aCommand, aExpectedField: string): TCommanderAnswer;
var
   attempt: integer;
   reused: boolean;
   strays: integer;
   name: string;
   value: string;
begin
   Result := caLinkFailed;

   for attempt := 1 to 2 do
      begin
      if FPeerClosesAfterReply then
         begin
         CloseLink;
         end;
      reused := IndyLinkIsOpen(FLink);
      if not OpenLink then
         begin
         Result := caLinkFailed;
         Exit;
         end;

      try
         (* AnsiString: Indy's string, explicitly.  A message is ASCII. *)
         FLink.IOHandler.Write(AnsiString(CommanderMessage(aCommand, '') + COMMANDER_MESSAGE_TERMINATOR),
                               IndyTextEncoding_8Bit);
         logger.Trace('[Commander TX] %s', [aCommand]);

         strays := 0;
         while True do
            begin
            if not ReadReplyField(name, value) then
               begin
               (* Nothing, or not a field.  The connection's state is now
                 unknown -- a late answer could arrive on it -- so it goes. *)
               CloseLink;
               Result := caNoAnswer;
               Exit;
               end;

            logger.Trace('[Commander RX] <%s> %s', [name, value]);
            ApplyField(name, value);

            if UnicodeSameText(name, aExpectedField) then
               begin
               if FPeerClosesAfterReply then
                  begin
                  CloseLink;
                  end;
               Result := caAnswered;
               Exit;
               end;

            Inc(strays);
            if strays >= COMMANDER_MAX_STRAY_FIELDS then
               begin
               logger.Warn('[Commander] %s: %d fields arrived and none was %s', [aCommand, strays, aExpectedField]);
               CloseLink;
               Result := caNoAnswer;
               Exit;
               end;
            end;
      except
         on E: EIdReadTimeout do
            begin
            (* The header came and the value did not. *)
            CloseLink;
            Result := caNoAnswer;
            Exit;
            end;
         on E: Exception do
            begin
            CloseLink;
            if reused and (attempt = 1) then
               begin
               (* THE PEER HAD CLOSED THE CONNECTION WE KEPT.  Ask again on a
                 fresh one, and from now on open one per query -- this
                 Commander closes after it answers, as DXKeeper does. *)
               if not FPeerClosesAfterReply then
                  begin
                  logger.Info('[Commander] closes the connection after each reply -- one connection per query from now on');
                  FPeerClosesAfterReply := True;
                  end;
               Continue;
               end;
            logger.Debug('[Commander] %s failed: %s - %s', [aCommand, E.ClassName, E.Message]);
            Result := caLinkFailed;
            Exit;
            end;
      end;
      end;
end;

(* DID THE PEER CLOSE THE OPEN CONNECTION, within aTimeoutMs?  Waits for data
  or a hang-up, whichever comes first, and answers from the handler's own
  ClosedGracefully field.  Data that arrives instead (an unasked field) stays
  in the buffer for the next read.  Polling thread only: this reads, and it is
  the only reader.  False when no connection is open. *)
function TDXLabCommanderRadio.PeerHangsUpWithin(aTimeoutMs: integer): boolean;
begin
   Result := False;
   if not IndyLinkIsOpen(FLink) then
      begin
      Exit;
      end;
   try
      FLink.IOHandler.CheckForDataOnSource(aTimeoutMs);
      Result := FLink.IOHandler.ClosedGracefully;
   except
      on E: Exception do
         begin
         (* A reset rather than a close: gone either way. *)
         logger.Debug('[Commander] waiting for a hang-up raised: %s - %s', [E.ClassName, E.Message]);
         Result := True;
         end;
   end;
end;

(* A SET.  Polling thread only.  No reply is read: the document promises none.
  On a peer that keeps its connection, the set goes on it, behind whatever
  went before.  On one that hangs up per message, it goes on a fresh
  connection and the next message waits for the hang-up -- see the unit
  header for why that wait is the ordering guarantee. *)
function TDXLabCommanderRadio.SendSet(const aMessage: string): boolean;
var
   attempt: integer;
   reused: boolean;
begin
   Result := False;

   for attempt := 1 to 2 do
      begin
      if FPeerClosesAfterReply then
         begin
         CloseLink;
         end;
      reused := IndyLinkIsOpen(FLink);
      if not OpenLink then
         begin
         Exit;
         end;

      try
         FLink.IOHandler.Write(AnsiString(aMessage + COMMANDER_MESSAGE_TERMINATOR), IndyTextEncoding_8Bit);
         logger.Trace('[Commander TX] %s', [aMessage]);
         Result := True;
      except
         on E: Exception do
            begin
            CloseLink;
            if reused and (attempt = 1) then
               begin
               Continue;   // the kept connection had gone; once more on a fresh one
               end;
            logger.Debug('[Commander] write failed: %s - %s', [E.ClassName, E.Message]);
            Exit;
            end;
      end;

      if FPeerClosesAfterReply then
         begin
         if not PeerHangsUpWithin(COMMANDER_SET_SETTLE_MS) then
            begin
            logger.Debug('[Commander] no hang-up within %d ms after a set -- closing it ourselves',
                         [COMMANDER_SET_SETTLE_MS]);
            end;
         CloseLink;
         end;
      Exit;
      end;
end;

(* -------------------------------------------------------------- outbound -- *)

(* ANY THREAD.  Queued; DrainUrgentQueue writes it from the polling thread. *)
procedure TDXLabCommanderRadio.SendToRadio(s: string);
begin
   if s = '' then
      begin
      Exit;
      end;
   FQueueLock.Enter;
   try
      FQueue.Add(AnsiString(s));   // wire text, ASCII; TStringList holds AnsiString
   finally
      FQueueLock.Leave;
   end;
end;

(* The command and its parameter fields, framed as one message. *)
procedure TDXLabCommanderRadio.SendToRadio(whichVFO: TVFO; sCmd: string; sData: string);
begin
   SendToRadio(CommanderMessage(sCmd, sData));
end;

(* A STOP GOES FIRST: an unkey must not wait behind a queued tune. *)
procedure TDXLabCommanderRadio.SendToRadioUrgent(const s: string);
begin
   if s = '' then
      begin
      Exit;
      end;
   FQueueLock.Enter;
   try
      FQueue.Insert(0, AnsiString(s));
   finally
      FQueueLock.Leave;
   end;
end;

(* THE OPERATOR'S STARTUP COMMAND GOES OUT RAW, so it must at least be a
  Commander message: a K3's 'KY <;' left configured after a radio swap would
  otherwise land on a peer that parses by length (the Icom precedent,
  30f48554). *)
function TDXLabCommanderRadio.StartupCommandIsSendable(const cmd: string;
                                                      out reason: string): boolean;
begin
   Result := IsOneCommanderMessage(cmd);
   if Result then
      begin
      reason := '';
      end
   else
      begin
      reason := 'not one Commander message (<command:N>name<parameters:M>...)';
      end;
end;

procedure TDXLabCommanderRadio.DrainUrgentQueue;
var
   pending: TStringList;
   i: integer;
begin
   pending := TStringList.Create;
   try
      (* Taken whole under the lock and written outside it, so a sender is
        never held behind a socket. *)
      FQueueLock.Enter;
      try
         pending.Assign(FQueue);
         FQueue.Clear;
      finally
         FQueueLock.Leave;
      end;

      for i := 0 to pending.Count - 1 do
         begin
         if not SendSet(pending[i]) then
            begin
            (* Commander is gone.  What is left is dropped, not kept: it was
              meant for now, and Connect discards anything queued meanwhile. *)
            FLinkUp := False;
            logger.Warn('[Commander] link lost while sending; %d command(s) not sent', [pending.Count - i]);
            Exit;
            end;
         end;
   finally
      pending.Free;
   end;
end;

function TDXLabCommanderRadio.FrequencyParameter(aHz: LongInt): string;
begin
   Result := CommanderField('xcvrfreq', CommanderHzToKHz(aHz, FDecimalSeparator));
end;

procedure TDXLabCommanderRadio.Transmit;
begin
   SendToRadio(CommanderMessage('CmdTX', ''));
end;

procedure TDXLabCommanderRadio.Receive;
begin
   SendStopToRadio(CommanderMessage('CmdRX', ''));
end;

procedure TDXLabCommanderRadio.SetFrequency(freq: longint; vfo: TVFO; mode: TRadioMode);
begin
   if freq <= 0 then
      begin
      logger.Warn('[Commander.SetFrequency] %d Hz is not a frequency -- ignored', [freq]);
      Exit;
      end;

   if vfo = nrVFOB then
      begin
      (* ALWAYS CmdQSXSplit, NEVER CmdSetTXFreq.  CmdSetTXFreq with split off
        retunes the receiver, and whether split is on is something TR4W only
        learns at the next poll -- an operator who turns split off and clicks
        a QSX spot inside that window would move the RX.  CmdQSXSplit sets the
        TX frequency AND split, which is a no-op for split when it is already
        on, so it is right whatever the rig's state.  It also turns split on,
        which is what every caller that writes VFO B is about to ask for. *)
      SendToRadio(CommanderMessage('CmdQSXSplit',
                                   FrequencyParameter(freq) +
                                   CommanderField('SuppressDual', 'Y') +
                                   CommanderField('SuppressModeChange', 'Y')));
      if mode <> rmNone then
         begin
         logger.Debug('[Commander.SetFrequency] VFO B mode not set: Commander sets the TX mode only from its own QSX state');
         end;
      Exit;
      end;

   SendToRadio(CommanderMessage('CmdSetFreq', FrequencyParameter(freq)));
   if (mode <> rmNone) and (not ModeAlreadySet(mode, nrVFOA)) then
      begin
      SetMode(mode, nrVFOA);
      end;
end;

procedure TDXLabCommanderRadio.SetMode(mode: TRadioMode; vfo: TVFO);
var
   name: string;
begin
   if vfo = nrVFOB then
      begin
      logger.Debug('[Commander.SetMode] Commander sets the mode of the selected VFO only -- VFO B ignored');
      Exit;
      end;
   name := RadioModeToCommanderMode(mode);
   if name = '' then
      begin
      logger.Warn('[Commander.SetMode] no Commander mode for %s -- ignored', [ModeToString(mode)]);
      Exit;
      end;
   SendToRadio(CommanderMessage('CmdSetMode', CommanderField('1', name)));
end;

procedure TDXLabCommanderRadio.Split(splitOn: boolean);
begin
   if splitOn then
      begin
      SendToRadio(CommanderMessage('CmdSplit', CommanderField('1', 'on')));
      end
   else
      begin
      SendToRadio(CommanderMessage('CmdSplit', CommanderField('1', 'off')));
      end;
end;

(* NO CALLER OUTSIDE THE FACTORY TODAY.  CW and the phone sideband the band
  normally uses -- LSB below 10 MHz, USB above, a convention and not a fact
  about the rig. *)
function TDXLabCommanderRadio.ToggleMode(vfo: TVFO): TRadioMode;
begin
   if Self.vfo[nrVFOA].mode in [rmCW, rmCWRev] then
      begin
      if Self.vfo[nrVFOA].frequency < 10000000 then
         begin
         Result := rmLSB;
         end
      else
         begin
         Result := rmUSB;
         end;
      end
   else
      begin
      Result := rmCW;
      end;
   SetMode(Result, nrVFOA);
end;

(* Commander has no band message; a band change is a tune to the band's
  calling frequency, from the base's own table. *)
procedure TDXLabCommanderRadio.SetBand(band: TRadioBand; vfo: TVFO);
var
   freq: LongInt;
begin
   freq := BandToFreq(band);
   if freq <= 0 then
      begin
      logger.Warn('[Commander.SetBand] no frequency known for band ordinal %d -- ignored', [Ord(band)]);
      Exit;
      end;
   SetFrequency(freq, nrVFOA, rmNone);
end;

function TDXLabCommanderRadio.ToggleBand(vfo: TVFO): TRadioBand;
begin
   Result := NextSupportedBand(Self.vfo[nrVFOA].band, True);
   SetBand(Result, nrVFOA);
end;

(* --------------------------------------------- what Commander cannot do -- *)

(* None of these has a message in the document.  Each refuses in the log --
  at Debug where TR4W calls it on its own (a RIT clear after a QSO), at Warn
  where only an operator's key press reaches it. *)

procedure TDXLabCommanderRadio.RITClear(vfo: TVFO);
begin
   logger.Debug('[Commander] no RIT message -- RIT clear ignored');
end;

procedure TDXLabCommanderRadio.XITClear(vfo: TVFO);
begin
   logger.Debug('[Commander] no XIT message -- XIT clear ignored');
end;

procedure TDXLabCommanderRadio.RITOn(vfo: TVFO);
begin
   logger.Warn('[Commander] no RIT message -- RIT on ignored');
end;

procedure TDXLabCommanderRadio.RITOff(vfo: TVFO);
begin
   logger.Debug('[Commander] no RIT message -- RIT off ignored');
end;

procedure TDXLabCommanderRadio.XITOn(vfo: TVFO);
begin
   logger.Warn('[Commander] no XIT message -- XIT on ignored');
end;

procedure TDXLabCommanderRadio.XITOff(vfo: TVFO);
begin
   logger.Debug('[Commander] no XIT message -- XIT off ignored');
end;

procedure TDXLabCommanderRadio.SetRITFreq(vfo: TVFO; hz: integer);
begin
   logger.Debug('[Commander] no RIT message -- RIT offset %d ignored', [hz]);
end;

procedure TDXLabCommanderRadio.SetXITFreq(vfo: TVFO; hz: integer);
begin
   logger.Debug('[Commander] no XIT message -- XIT offset %d ignored', [hz]);
end;

procedure TDXLabCommanderRadio.RITBumpDown;
begin
   logger.Warn('[Commander] no RIT message -- RIT bump ignored');
end;

procedure TDXLabCommanderRadio.RITBumpUp;
begin
   logger.Warn('[Commander] no RIT message -- RIT bump ignored');
end;

(* Commander tunes absolutely and TR4W knows no step size; inventing one would
  move this radio by a different amount from the radio beside it. *)
procedure TDXLabCommanderRadio.VFOBumpDown(whichVFO: TVFO);
begin
   logger.Warn('[Commander] no relative tune message -- VFO bump ignored');
end;

procedure TDXLabCommanderRadio.VFOBumpUp(whichVFO: TVFO);
begin
   logger.Warn('[Commander] no relative tune message -- VFO bump ignored');
end;

procedure TDXLabCommanderRadio.SetFilter(filter: TRadioFilter; vfo: TVFO);
begin
   logger.Warn('[Commander] no filter message -- filter change ignored');
end;

function TDXLabCommanderRadio.SetFilterHz(hz: integer; vfo: TVFO): integer;
begin
   logger.Warn('[Commander] no filter message -- %d Hz ignored', [hz]);
   Result := 0;
end;

(* TRUE MEANS NOT DONE, the house convention for this method.  Commander's
  user-defined sequences are not message memories. *)
function TDXLabCommanderRadio.MemoryKeyer(mem: integer): boolean;
begin
   logger.Warn('[Commander] no message-memory message -- memory %d ignored', [mem]);
   Result := True;
end;

(* No rcCWByCAT, so the keyer never sends CW here; these only say so. *)
procedure TDXLabCommanderRadio.BufferCW(msg: string);
begin
   logger.Debug('[Commander] CW by CAT is not supported -- text discarded');
end;

procedure TDXLabCommanderRadio.SendCW;
begin
   logger.Debug('[Commander] CW by CAT is not supported -- nothing to send');
end;

procedure TDXLabCommanderRadio.StopCW;
begin
   logger.Debug('[Commander] CW by CAT is not supported -- nothing to stop');
end;

procedure TDXLabCommanderRadio.SetCWSpeed(speed: integer);
begin
   logger.Debug('[Commander] no CW speed message -- %d wpm not sent', [speed]);
end;

(* --------------------------------------------------------------- inbound -- *)

procedure TDXLabCommanderRadio.PollRadioState;
var
   answer: TCommanderAnswer;
begin
   if not FLinkUp then
      begin
      Exit;
      end;

   (* The frequency is the question that says whether Commander is there. *)
   if Query('CmdGetFreq', COMMANDER_FIELD_FREQ) <> caAnswered then
      begin
      logger.Info('[Commander] no answer to CmdGetFreq -- link down');
      FLinkUp := False;
      Exit;
      end;

   if Query('CmdSendMode', COMMANDER_FIELD_MODE) = caLinkFailed then
      begin
      FLinkUp := False;
      Exit;
      end;

   if Query('CmdSendSplit', COMMANDER_FIELD_SPLIT) = caLinkFailed then
      begin
      FLinkUp := False;
      Exit;
      end;

   if not FTXQueryRefused then
      begin
      answer := Query('CmdSendTX', COMMANDER_FIELD_TX);
      if answer = caLinkFailed then
         begin
         FLinkUp := False;
         Exit;
         end;
      if answer = caAnswered then
         begin
         FTXQueryMisses := 0;
         end
      else
         begin
         Inc(FTXQueryMisses);
         if FTXQueryMisses >= COMMANDER_TX_QUERY_MAX_MISSES then
            begin
            FTXQueryRefused := True;
            logger.Info('[Commander] CmdSendTX unanswered %d times -- this rig does not report TX; not asked again this session',
                        [FTXQueryMisses]);
            end;
         end;
      end;

   if localSplitEnabled then
      begin
      if Query('CmdGetTXFreq', COMMANDER_FIELD_TXFREQ) = caLinkFailed then
         begin
         FLinkUp := False;
         end;
      end;
end;

(* A COMPLETE FIELD, '<CmdFreq:10>14,010.500'.  Not called by a reading thread
  -- there is none -- but kept as the entry for a whole reply, which is also
  how the tests hand one in. *)
procedure TDXLabCommanderRadio.ProcessMsg(msg: string);
var
   name: string;
   value: string;
begin
   if TryParseCommanderField(msg, name, value) then
      begin
      ApplyField(name, value);
      end
   else
      begin
      logger.Debug('[Commander] not a field: "%s"', [msg]);
      end;
end;

procedure TDXLabCommanderRadio.ApplyField(const aName, aValue: string);
var
   hz: LongInt;
   newMode: TRadioMode;
begin
   UpdateLastValidResponse;

   if UnicodeSameText(aName, COMMANDER_FIELD_FREQ) then
      begin
      if TryCommanderKHzToHz(aValue, hz) then
         begin
         Self.vfo[nrVFOA].frequency := hz;
         Self.vfo[nrVFOA].band := FreqToRadioBand(hz);
         FRigReporting := True;
         end
      else
         begin
         (* ".000": Commander is up, the rig has not reported.  Keep what we
           had; IsOperational says the rest. *)
         FRigReporting := False;
         logger.Debug('[Commander] no RX frequency from the rig ("%s")', [aValue]);
         end;
      end
   else if UnicodeSameText(aName, COMMANDER_FIELD_TXFREQ) then
      begin
      if TryCommanderKHzToHz(aValue, hz) and localSplitEnabled then
         begin
         Self.vfo[nrVFOB].frequency := hz;
         Self.vfo[nrVFOB].band := FreqToRadioBand(hz);
         end;
      end
   else if UnicodeSameText(aName, COMMANDER_FIELD_MODE) then
      begin
      if TryCommanderModeToRadioMode(aValue, newMode) then
         begin
         Self.vfo[nrVFOA].mode := newMode;
         end
      else if aValue <> '' then
         begin
         logger.Debug('[Commander] unknown mode "%s" -- kept %s', [aValue, ModeToString(Self.vfo[nrVFOA].mode)]);
         end;
      end
   else if UnicodeSameText(aName, COMMANDER_FIELD_SPLIT) then
      begin
      if UnicodeSameText(aValue, 'ON') then
         begin
         SetSplitOn(True);
         end
      else if UnicodeSameText(aValue, 'OFF') then
         begin
         SetSplitOn(False);
         (* Not split: the TX frequency is the RX frequency, and TR4W has no
           other way to learn VFO B.  Unknown, not stale. *)
         Self.vfo[nrVFOB].frequency := 0;
         Self.vfo[nrVFOB].band := FreqToRadioBand(0);
         end;
      end
   else if UnicodeSameText(aName, COMMANDER_FIELD_TX) then
      begin
      if UnicodeSameText(aValue, 'ON') then
         begin
         SetTransmitting(True);
         end
      else if UnicodeSameText(aValue, 'OFF') then
         begin
         SetTransmitting(False);
         end;
      end
   else
      begin
      logger.Debug('[Commander] field %s not used ("%s")', [aName, aValue]);
      end;
end;

(* ---------------------------------------------------------- registration -- *)

function CreateDXLabCommander: TFactoryRadioBase;
begin
   Result := TDXLabCommanderRadio.Create;
end;

initialization
   (* A string id: Commander has no InterfacedRadioType member and needs none
     (docs/ADDING_A_RADIO.md, step 5).  The id is a LITERAL here, never a
     constant: Lint-RadioRegistry and tools/bench-status read the id and the
     display name as the call's first two quoted strings, and a call with one
     is skipped in silence -- so a constant would hide this radio from the
     display-name collision check.
     Network only: Commander is reached by TCP and nothing else.
     discoverable = False: the document describes no discovery. *)
   RegisterRadioById('DXLABCOMMANDER',
      CreateDXLabCommander,
      'DXLab Commander', [rlNetwork], COMMANDER_DEFAULT_PORT, False,
      SerialParams(0, 0, PARITY_NONE, 0)   // network-only; the serial row is unused
   );

end.
