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
unit uRadioFLRig;
{$I ..\tr4w.inc}

(* FLRIG AS A RADIO, NATIVELY, OVER XML-RPC (issue 5).  NOT BENCH-VALIDATED.

  FLRig (W1HKJ) owns the radio's CAT port and serves XML-RPC over HTTP, by
  default on 127.0.0.1:12345.  TR4W drives whatever rig FLRig drives, through
  one registration: like DXLab Commander and TCI, the "model" is the server.

  THIS REPLACES THE HAMLIB BRIDGE (NY4I, issue 5, answer (a)).  The FLRIG enum
  member, and so the config token 'FLRIG' that profiles store as their
  RegistryId, now builds this class instead of THamLibDirect with rig_model 4.
  The registration still carries HamLib id 4, so an operator who ticks "Drive
  through HamLib" on an FLRig profile still reaches the old bridge -- a
  fallback, not the default.  The display name changed from "FLRig (HamLib
  bridge)" to "FLRig (XML-RPC)": nothing persists the display name (profiles
  key on RegistryId), and the old one would now be untrue.

  WHAT TR4W USES.  Every method name below was read from the flrig 2.0.12
  binary on NY4I's station; the argument and answer types from Hamlib's FLRig
  backend (rigs/dummy/flrig.c).  See uFLRigXmlRpc.
    poll   rig.get_vfoA (required -- it is the liveness question),
           rig.get_modeA, rig.get_ptt, rig.get_split, rig.get_vfoB,
           rig.get_modeB, rig.get_AB (logged only, see VFO below)
    once   rig.get_xcvr (the rig's name, for the log), rig.get_modes
    set    rig.set_vfoA / rig.set_vfoB, rig.set_modeA / rig.set_modeB,
           rig.set_split, rig.set_ptt
  A poll method FLRig answers with a fault (an older FLRig without
  get_modeB, say) is not asked again on that link.

  NOT DONE, deliberately.
    - CW BY CAT.  FLRig's cwio_* methods drive FLRig's OWN keyer -- DTR/RTS on
      a serial port configured inside FLRig ("Configure cwio") -- not the
      rig's CAT text command, and the binary shows no stop method for it.  So
      rcCWByCAT is NOT declared and no frame rule is stated.  A bench question
      (docs/BENCH_QUEUE.md).
    - RIT/XIT, filters, VFO bumps, message memories: no method TR4W can use
      honestly (rig.set_bw is per-rig semantics).  Each refuses in the log.
    - PTT BY CAT is implemented (rig.set_ptt) but classified NOT CONFIRMED
      (issue 36): the feature matrix does not list FLRig and nobody has keyed
      a rig through it from TR4W.  Nothing is declared in the constructor.
    - Keep-alive / silence limit: not declared.  The poll is the liveness
      check -- an unanswered rig.get_vfoA takes the link down.

  THE ACTIVE VFO.  rig.get_AB is read and LOGGED when it changes, but TR4W
  still treats VFO A as the receive VFO: band-map tunes go to rig.set_vfoA.
  Following B (SetActiveVFO) would change what the registry-wide split pins
  see and is follow-up work once a bench says what FLRig's A/B means on a K4.

  THE TRANSPORT -- THE DXLAB COMMANDER SHAPE (uRadioDXLabCommander).
    - FLRig pushes nothing, so there is no reading thread.  The polling
      thread asks and waits a bounded time for each answer.
    - Every set is QUEUED: SendToRadio, from any thread, only appends a
      complete <methodCall> to FQueue; DrainUrgentQueue, on the polling
      thread, posts them.  The main thread never waits on FLRig, and the
      polling thread is the only one that reads or writes FHttp.  That is what
      makes TIdHTTP's internal Connected calls safe here: they READ the
      socket, and the 2026-10-25 hang needs two readers.  Other threads only
      ever CLOSE it (InterruptLink), from field reads (uIndyLink).
    - FHttp is given an IOHandler it OWNS before its first request
      (IndyLinkOwnHandler), so a failed connect only closes it and never frees
      it under InterruptLink.
    - HTTP/1.1 keep-alive when FLRig keeps the connection; a request that
      fails on a kept connection is sent once more on a fresh one.
    - A queued call does not survive a dropped link (Connect and Disconnect
      empty the queue) -- EXCEPT the un-key: once a rig.set_ptt 1 has been
      posted, an un-key is OWED until a rig.set_ptt 0 succeeds, and Connect
      pays it as soon as FLRig answers.  This is Commander's rule, copied: the
      two drivers share the shape but not code, and lifting a common base is
      follow-up work. *)

interface

uses
   SysUtils, Classes, SyncObjs,
   IdHTTP,
   uFactoryRadioBase, uRadioBand, uRadioRegistry, uFLRigXmlRpc, VC;

type
   (* How a call ended.  Only faLinkFailed says FLRig is unreachable. *)
   TFLRigAnswer = (faAnswered, faFault, faNoAnswer, faLinkFailed);

   TFLRigRadio = class(TFactoryRadioBase)
   private
      FHttp: TIdHTTP;                 // polling thread only (InterruptLink closes it)
      FUrl: string;                   // built in Connect
      FQueue: TStringList;            // <methodCall> documents waiting for DrainUrgentQueue
      FQueueLock: TCriticalSection;
      FLinkUp: boolean;               // FLRig answered, and nothing has failed since
      FRigReporting: boolean;         // the last rig.get_vfoA was a frequency, not 0
      FUnkeyOwed: boolean;            // polling thread only; outlives a dropped link on purpose
      FRigModes: TStringList;         // rig.get_modes, in the rig's order; polling thread only
      FRefused: TStringList;          // poll methods FLRig faulted on this link
      FLastAB: string;                // rig.get_AB, for change-only logging
      FRigModesLock: TCriticalSection; // FRigModes is read by SetMode on the caller's thread

      procedure ClearQueue;
      function  DiscardQueuedCall(const aCall: string): integer;
      procedure CloseLink;
      function  PostCall(const aBody: string; out aResponse: string): TFLRigAnswer;
      function  Query(const aMethod: string; aValues: TStrings): TFLRigAnswer;
      function  AskOptional(const aMethod: string; aValues: TStrings): TFLRigAnswer;
      function  SendSet(const aCall: string): TFLRigAnswer;
      function  PttCall(aOn: boolean): string;
   protected
      (* How long a call waits for its answer.  FLRig answers its getters from
        its own cache, so a local reply is quick; this is short because the
        polling thread is also the PTT path.  A field so a test can shorten
        it. *)
      FReplyTimeoutMs: integer;

      (* Apply one answer.  Protected so a test can hand one in. *)
      procedure ApplyAnswer(const aMethod: string; aValues: TStrings);

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

implementation

uses
   IdExceptionCore,
   uHostResolve, uIndyLink;

const
   FLRIG_REPLY_TIMEOUT_MS = 1000;
   FLRIG_POLL_INTERVAL_MS = 250;

   (* Asked every poll after rig.get_vfoA.  Each is optional: a fault stops
     it being asked on this link. *)
   FLRIG_POLLED: array[0..5] of string = (
      'rig.get_modeA',
      'rig.get_ptt',
      'rig.get_split',
      'rig.get_vfoB',
      'rig.get_modeB',
      'rig.get_AB'
   );

(* ------------------------------------------------------------- lifecycle -- *)

constructor TFLRigRadio.Create;
begin
   inherited Create(ProcessMsg);

   radioModel := 'FLRig (XML-RPC)';

   (* FLRig pushes nothing, so the poll is the only way state arrives. *)
   requiresPolling := True;
   pollingInterval := FLRIG_POLL_INTERVAL_MS;
   autoUpdateCommand := '';
   bAddTermination := False;   // a call is a whole XML document

   FReplyTimeoutMs := FLRIG_REPLY_TIMEOUT_MS;

   (* WHAT TR4W READS FROM FLRIG, AND NOTHING ELSE.
       rcReadVFOB      rig.get_vfoB + rig.get_modeB
       rcReadSplit     rig.get_split
       rcReadTXStatus  rig.get_ptt
     NOT declared:
       rcCWByCAT       cwio_* is FLRig's own DTR/RTS keyer (unit header)
       rcCWSpeedSync   follows from the above
       rcReadRIT       no RIT method
       rcDataMode      data arrives as a mode name (DATA, DATA-R...)
     PTTByCAT is left pbcNotConfirmed -- see the unit header. *)
   FCapabilities.Flags := FCapabilities.Flags + [rcReadVFOB, rcReadSplit, rcReadTXStatus];
   FCapabilities.HasXIT := False;

   FHttp := TIdHTTP.Create(nil);
   FHttp.HandleRedirects := False;
   (* WITHOUT THIS EVERY POST IS A NEW CONNECTION: TIdCustomHTTP.Post
     disconnects and drops to HTTP/1.0 unless hoKeepOrigProtocol is set
     (include\Protocols\IdHTTP.pas, Post).  Safe here: this Indy never adds
     'Expect: 100-continue' on its own and writes the body at once, so an
     XML-RPC server that sends no 100 is not waited on. *)
   FHttp.HTTPOptions := FHttp.HTTPOptions + [hoKeepOrigProtocol];
   FHttp.Request.ContentType := 'text/xml';
   FHttp.Request.UserAgent := 'TR4W';
   FHttp.ConnectTimeout := INDY_LINK_CONNECT_TIMEOUT_MS;
   FHttp.ReadTimeout := FReplyTimeoutMs;

   FQueue := TStringList.Create;
   FQueueLock := TCriticalSection.Create;
   FRigModes := TStringList.Create;
   FRigModesLock := TCriticalSection.Create;
   FRefused := TStringList.Create;
end;

destructor TFLRigRadio.Destroy;
begin
   (* The polling thread has stopped before any radio is freed (issue #104),
     so nothing else holds FHttp or the queue now. *)
   if FHttp <> nil then
      begin
      CloseLink;
      FreeAndNil(FHttp);
      end;
   FreeAndNil(FQueue);
   FreeAndNil(FQueueLock);
   FreeAndNil(FRigModes);
   FreeAndNil(FRigModesLock);
   FreeAndNil(FRefused);
   inherited Destroy;
end;

(* A NEW LINK STARTS FROM NOTHING.  Polling thread, at startup and on every
  reconnect.  The link is up when FLRig answers rig.get_vfoA. *)
function TFLRigRadio.Connect: integer;
var
   values: TStringList;
   host: string;
   answer: TFLRigAnswer;
begin
   Result := -1;

   (* What TFactoryRadioBase.Connect does for every radio first; this one
     does not call it, because the base would open a transport of its own. *)
   ResetPerLinkState;

   ClearQueue;
   FLinkUp := False;
   FRigReporting := False;
   FRefused.Clear;
   FLastAB := '';
   FRigModesLock.Enter;
   try
      FRigModes.Clear;
   finally
      FRigModesLock.Leave;
   end;
   CloseLink;

   (* A profile made for the HamLib bridge may carry port 0: that
     registration declared no network port, so the editor offered none.  The
     address and port were always stored apart (THamLibDirect joined them),
     so only the port needs a default. *)
   if radioPort = 0 then
      begin
      logger.Info('[FLRig] no port configured -- using FLRig''s default %d', [FLRIG_DEFAULT_PORT]);
      radioPort := FLRIG_DEFAULT_PORT;
      end;

   if radioAddress = '' then
      begin
      logger.Error('[FLRig] no address configured (port %d)', [radioPort]);
      Exit;
      end;

   host := ResolveHostForConnect(radioAddress);
   if Pos(':', host) > 0 then
      begin
      host := '[' + host + ']';   // an IPv6 literal, as a URL needs it
      end;
   FUrl := 'http://' + host + ':' + IntToStr(radioPort) + FLRIG_RPC_PATH;

   logger.Info('[FLRig] connecting to %s:%d', [radioAddress, radioPort]);
   values := TStringList.Create;
   try
      if Query('rig.get_vfoA', values) <> faAnswered then
         begin
         logger.Info('[FLRig] no answer from %s:%d', [radioAddress, radioPort]);
         CloseLink;
         Exit;
         end;
      FLinkUp := True;
      Result := 0;
      ApplyAnswer('rig.get_vfoA', values);

      answer := Query('rig.get_xcvr', values);
      if (answer = faAnswered) and (values.Count > 0) then
         begin
         logger.Info('[FLRig] answering at %s:%d, driving "%s"', [radioAddress, radioPort, values[0]]);
         end;

      if answer <> faLinkFailed then
         begin
         answer := Query('rig.get_modes', values);
         end;
      if (answer = faAnswered) and (values.Count > 0) then
         begin
         FRigModesLock.Enter;
         try
            FRigModes.Assign(values);
         finally
            FRigModesLock.Leave;
         end;
         logger.Info('[FLRig] rig modes: %s', [values.CommaText]);
         end
      else if answer <> faLinkFailed then
         begin
         logger.Warn('[FLRig] no mode list from rig.get_modes -- modes are sent from TR4W''s own name table');
         end;

      if answer = faLinkFailed then
         begin
         logger.Info('[FLRig] link lost during connect');
         FLinkUp := False;
         Result := -1;
         CloseLink;
         Exit;
         end;

      if FUnkeyOwed then
         begin
         logger.Info('[FLRig] the rig was keyed when the link was lost -- sending rig.set_ptt 0');
         answer := SendSet(PttCall(False));
         if (answer = faAnswered) or (answer = faFault) then
            begin
            FUnkeyOwed := False;
            end
         else
            begin
            logger.Warn('[FLRig] rig.set_ptt 0 not sent -- link lost again; retried on the next connect');
            FLinkUp := False;
            Result := -1;
            end;
         end;
   finally
      values.Free;
   end;
end;

procedure TFLRigRadio.Disconnect;
begin
   FLinkUp := False;
   FRigReporting := False;
   ClearQueue;
   CloseLink;
end;

(* FROM ANOTHER THREAD, WHILE THE POLLING THREAD MAY BE INSIDE A REQUEST:
  close the socket so that call returns, and free nothing.  Field reads only
  before the close -- never Indy's Connected (uIndyLink). *)
procedure TFLRigRadio.InterruptLink;
begin
   FLinkUp := False;
   if IndyLinkIsOpen(FHttp) then
      begin
      try
         FHttp.Disconnect(False);
      except
         on E: Exception do
            begin
            logger.Debug('[FLRig] closing the link raised: %s - %s', [E.ClassName, E.Message]);
            end;
      end;
      end;
end;

function TFLRigRadio.GetISConnected: boolean;
begin
   Result := FLinkUp;
end;

(* FLRig answering 0 for the frequency is FLRig up and no rig behind it: the
  operator's radio is not under control, so the alert colour stays on. *)
function TFLRigRadio.GetIsOperational: boolean;
begin
   Result := FLinkUp and FRigReporting;
end;

function TFLRigRadio.LinkIsOpen: boolean;
begin
   Result := FLinkUp;
end;

(* ------------------------------------------------------------- transport -- *)

procedure TFLRigRadio.ClearQueue;
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
      logger.Info('[FLRig] %d queued call(s) discarded -- the link is new or gone', [dropped]);
      end;
end;

(* ANY THREAD.  Removes every queued call identical to aCall; answers how
  many went. *)
function TFLRigRadio.DiscardQueuedCall(const aCall: string): integer;
var
   i: integer;
begin
   Result := 0;
   FQueueLock.Enter;
   try
      for i := FQueue.Count - 1 downto 0 do
         begin
         if FQueue[i] = aCall then
            begin
            FQueue.Delete(i);
            Inc(Result);
            end;
         end;
   finally
      FQueueLock.Leave;
   end;
end;

(* Polling thread (or after it has stopped).  Also empties what Indy has
  buffered, so a byte left from the last connection cannot make the next
  request think it is still connected. *)
procedure TFLRigRadio.CloseLink;
begin
   if (FHttp = nil) or (FHttp.IOHandler = nil) then
      begin
      Exit;
      end;
   try
      FHttp.Disconnect(False);
   except
      on E: Exception do
         begin
         logger.Debug('[FLRig] closing the link raised: %s - %s', [E.ClassName, E.Message]);
         end;
   end;
   FHttp.IOHandler.InputBuffer.Clear;
end;

(* ONE HTTP POST, ONE ANSWER.  Polling thread only. *)
function TFLRigRadio.PostCall(const aBody: string; out aResponse: string): TFLRigAnswer;
var
   attempt: integer;
   reused: boolean;
   source: TBytesStream;
   reply: TBytesStream;
begin
   Result := faLinkFailed;
   aResponse := '';
   if FUrl = '' then
      begin
      Exit;
      end;

   for attempt := 1 to 2 do
      begin
      reused := IndyLinkIsOpen(FHttp);
      IndyLinkOwnHandler(FHttp, nil);
      FHttp.IOHandler.ReadTimeout := FReplyTimeoutMs;

      source := TBytesStream.Create(TEncoding.UTF8.GetBytes(aBody));
      reply := TBytesStream.Create(nil);
      try
         try
            (* AnsiString: Indy's string, explicitly.  The URL is ASCII. *)
            FHttp.Post(AnsiString(FUrl), source, reply);
            if reply.Size > 0 then
               begin
               (* An XML-RPC answer is far below 2 GB; the Int64 size fits. *)
               aResponse := TEncoding.UTF8.GetString(reply.Bytes, 0, Integer(reply.Size));
               end;
            Result := faAnswered;
            Exit;
         except
            on E: EIdHTTPProtocolException do
               begin
               (* FLRig is there and refused the request. *)
               logger.Warn('[FLRig] HTTP %d from %s', [E.ErrorCode, FUrl]);
               Result := faFault;
               Exit;
               end;
            on E: EIdReadTimeout do
               begin
               (* The connection's state is now unknown -- a late answer could
                 arrive on it -- so it goes. *)
               CloseLink;
               Result := faNoAnswer;
               Exit;
               end;
            on E: Exception do
               begin
               CloseLink;
               if reused and (attempt = 1) then
                  begin
                  Continue;   // the kept connection had gone; once more on a fresh one
                  end;
               logger.Debug('[FLRig] request to %s failed: %s - %s', [FUrl, E.ClassName, E.Message]);
               Result := faLinkFailed;
               Exit;
               end;
         end;
      finally
         source.Free;
         reply.Free;
      end;
      end;
end;

(* ASK ONE QUESTION.  Polling thread only.  aValues holds the answer's
  scalars (one per line for an array). *)
function TFLRigRadio.Query(const aMethod: string; aValues: TStrings): TFLRigAnswer;
var
   response: string;
   fault: string;
begin
   aValues.Clear;
   Result := PostCall(XmlRpcMethodCall(aMethod, []), response);
   if Result <> faAnswered then
      begin
      Exit;
      end;

   case XmlRpcDecodeResponse(response, aValues, fault) of
      xoValue:
         begin
         UpdateLastValidResponse;
         logger.Trace('[FLRig RX] %s -> %s', [aMethod, aValues.CommaText]);
         end;
      xoFault:
         begin
         UpdateLastValidResponse;   // FLRig answered; the method is what failed
         logger.Debug('[FLRig] %s: fault %s', [aMethod, fault]);
         Result := faFault;
         end;
      xoMalformed:
         begin
         logger.Warn('[FLRig] %s: not an XML-RPC response (%d characters)', [aMethod, Length(response)]);
         Result := faFault;
         end;
   end;
end;

function TFLRigRadio.AskOptional(const aMethod: string; aValues: TStrings): TFLRigAnswer;
begin
   aValues.Clear;
   if FRefused.IndexOf(AnsiString(aMethod)) >= 0 then
      begin
      Result := faFault;
      Exit;
      end;
   Result := Query(aMethod, aValues);
   if Result = faFault then
      begin
      FRefused.Add(AnsiString(aMethod));
      logger.Info('[FLRig] %s refused -- not asked again on this link', [aMethod]);
      end;
end;

(* A SET.  Polling thread only.  A fault is reported and is NOT a lost link:
  FLRig is there. *)
function TFLRigRadio.SendSet(const aCall: string): TFLRigAnswer;
var
   response: string;
   values: TStringList;
   fault: string;
begin
   Result := PostCall(aCall, response);
   logger.Trace('[FLRig TX] %s', [XmlRpcMethodNameOf(aCall)]);
   if Result <> faAnswered then
      begin
      Exit;
      end;
   UpdateLastValidResponse;
   values := TStringList.Create;
   try
      if XmlRpcDecodeResponse(response, values, fault) = xoFault then
         begin
         logger.Warn('[FLRig] %s refused: %s', [XmlRpcMethodNameOf(aCall), fault]);
         Result := faFault;
         end;
   finally
      values.Free;
   end;
end;

function TFLRigRadio.PttCall(aOn: boolean): string;
begin
   if aOn then
      begin
      Result := XmlRpcMethodCall('rig.set_ptt', [XmlRpcIntParam(1)]);
      end
   else
      begin
      Result := XmlRpcMethodCall('rig.set_ptt', [XmlRpcIntParam(0)]);
      end;
end;

(* -------------------------------------------------------------- outbound -- *)

(* ANY THREAD.  A complete <methodCall>; DrainUrgentQueue posts it. *)
procedure TFLRigRadio.SendToRadio(s: string);
begin
   if s = '' then
      begin
      Exit;
      end;
   FQueueLock.Enter;
   try
      FQueue.Add(AnsiString(s));
   finally
      FQueueLock.Leave;
   end;
end;

(* sCmd is the method name, sData one encoded <value> (or nothing). *)
procedure TFLRigRadio.SendToRadio(whichVFO: TVFO; sCmd: string; sData: string);
begin
   if sData = '' then
      begin
      SendToRadio(XmlRpcMethodCall(sCmd, []));
      end
   else
      begin
      SendToRadio(XmlRpcMethodCall(sCmd, [sData]));
      end;
end;

(* A STOP GOES FIRST: an un-key must not wait behind a queued tune. *)
procedure TFLRigRadio.SendToRadioUrgent(const s: string);
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

(* A raw startup command means nothing to an XML-RPC server: a K3's 'KY <;'
  left configured after a radio swap would be posted as garbage. *)
function TFLRigRadio.StartupCommandIsSendable(const cmd: string;
                                             out reason: string): boolean;
begin
   Result := False;
   reason := 'FLRig is driven by XML-RPC; a raw CAT startup command cannot be sent through it';
end;

procedure TFLRigRadio.DrainUrgentQueue;
var
   pending: TStringList;
   i: integer;
   answer: TFLRigAnswer;
begin
   pending := TStringList.Create;
   try
      (* Taken whole under the lock and posted outside it, so a sender is
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
         (* OWED BEFORE the post: a post that fails may still have reached
           FLRig.  Paid only by an un-key FLRig answered. *)
         if pending[i] = PttCall(True) then
            begin
            FUnkeyOwed := True;
            end;
         answer := SendSet(pending[i]);
         if (answer = faLinkFailed) or (answer = faNoAnswer) then
            begin
            (* What is left is dropped, not kept: it was meant for now, and
              Connect discards anything queued meanwhile. *)
            FLinkUp := False;
            logger.Warn('[FLRig] link lost while sending; %d call(s) not sent', [pending.Count - i]);
            Exit;
            end;
         if pending[i] = PttCall(False) then
            begin
            FUnkeyOwed := False;
            end;
         end;
   finally
      pending.Free;
   end;
end;

procedure TFLRigRadio.Transmit;
begin
   SendToRadio(PttCall(True));
end;

(* An un-key first CANCELS any key still queued -- always safe, link or no
  link -- then goes to the front of the queue. *)
procedure TFLRigRadio.Receive;
var
   cancelled: integer;
begin
   cancelled := DiscardQueuedCall(PttCall(True));
   if cancelled > 0 then
      begin
      logger.Debug('[FLRig] un-key cancelled %d queued rig.set_ptt 1', [cancelled]);
      end;
   SendStopToRadio(PttCall(False));
end;

procedure TFLRigRadio.SetFrequency(freq: longint; vfo: TVFO; mode: TRadioMode);
begin
   if freq <= 0 then
      begin
      logger.Warn('[FLRig.SetFrequency] %d Hz is not a frequency -- ignored', [freq]);
      Exit;
      end;

   if vfo = nrVFOB then
      begin
      SendToRadio(XmlRpcMethodCall('rig.set_vfoB', [XmlRpcHzParam(freq)]));
      end
   else
      begin
      SendToRadio(XmlRpcMethodCall('rig.set_vfoA', [XmlRpcHzParam(freq)]));
      end;

   if (mode <> rmNone) and (not ModeAlreadySet(mode, vfo)) then
      begin
      SetMode(mode, vfo);
      end;
end;

(* The name sent is the rig's own, from rig.get_modes (uFLRigXmlRpc). *)
procedure TFLRigRadio.SetMode(mode: TRadioMode; vfo: TVFO);
var
   name: string;
begin
   FRigModesLock.Enter;
   try
      name := FLRigModeNameFor(mode, FRigModes);
   finally
      FRigModesLock.Leave;
   end;
   if name = '' then
      begin
      logger.Warn('[FLRig.SetMode] the rig offers no mode for %s -- ignored', [ModeToString(mode)]);
      Exit;
      end;
   if vfo = nrVFOB then
      begin
      SendToRadio(XmlRpcMethodCall('rig.set_modeB', [XmlRpcStringParam(name)]));
      end
   else
      begin
      SendToRadio(XmlRpcMethodCall('rig.set_modeA', [XmlRpcStringParam(name)]));
      end;
end;

procedure TFLRigRadio.Split(splitOn: boolean);
begin
   if splitOn then
      begin
      SendToRadio(XmlRpcMethodCall('rig.set_split', [XmlRpcIntParam(1)]));
      end
   else
      begin
      SendToRadio(XmlRpcMethodCall('rig.set_split', [XmlRpcIntParam(0)]));
      end;
end;

(* CW and the phone sideband the band normally uses -- LSB below 10 MHz, USB
  above, a convention and not a fact about the rig. *)
function TFLRigRadio.ToggleMode(vfo: TVFO): TRadioMode;
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

(* FLRig has no band method TR4W uses; a band change is a tune to the band's
  calling frequency, from the base's own table. *)
procedure TFLRigRadio.SetBand(band: TRadioBand; vfo: TVFO);
var
   freq: LongInt;
begin
   freq := BandToFreq(band);
   if freq <= 0 then
      begin
      logger.Warn('[FLRig.SetBand] no frequency known for band ordinal %d -- ignored', [Ord(band)]);
      Exit;
      end;
   SetFrequency(freq, nrVFOA, rmNone);
end;

function TFLRigRadio.ToggleBand(vfo: TVFO): TRadioBand;
begin
   Result := NextSupportedBand(Self.vfo[nrVFOA].band, True);
   SetBand(Result, nrVFOA);
end;

(* ------------------------------------------- what TR4W does not ask of it -- *)

(* Each refuses in the log -- at Debug where TR4W calls it on its own (a RIT
  clear after a QSO), at Warn where only an operator's key press reaches it. *)

procedure TFLRigRadio.RITClear(vfo: TVFO);
begin
   logger.Debug('[FLRig] no RIT method -- RIT clear ignored');
end;

procedure TFLRigRadio.XITClear(vfo: TVFO);
begin
   logger.Debug('[FLRig] no XIT method -- XIT clear ignored');
end;

procedure TFLRigRadio.RITOn(vfo: TVFO);
begin
   logger.Warn('[FLRig] no RIT method -- RIT on ignored');
end;

procedure TFLRigRadio.RITOff(vfo: TVFO);
begin
   logger.Debug('[FLRig] no RIT method -- RIT off ignored');
end;

procedure TFLRigRadio.XITOn(vfo: TVFO);
begin
   logger.Warn('[FLRig] no XIT method -- XIT on ignored');
end;

procedure TFLRigRadio.XITOff(vfo: TVFO);
begin
   logger.Debug('[FLRig] no XIT method -- XIT off ignored');
end;

procedure TFLRigRadio.SetRITFreq(vfo: TVFO; hz: integer);
begin
   logger.Debug('[FLRig] no RIT method -- RIT offset %d ignored', [hz]);
end;

procedure TFLRigRadio.SetXITFreq(vfo: TVFO; hz: integer);
begin
   logger.Debug('[FLRig] no XIT method -- XIT offset %d ignored', [hz]);
end;

procedure TFLRigRadio.RITBumpDown;
begin
   logger.Warn('[FLRig] no RIT method -- RIT bump ignored');
end;

procedure TFLRigRadio.RITBumpUp;
begin
   logger.Warn('[FLRig] no RIT method -- RIT bump ignored');
end;

(* FLRig tunes absolutely and TR4W knows no step size for it. *)
procedure TFLRigRadio.VFOBumpDown(whichVFO: TVFO);
begin
   logger.Warn('[FLRig] no relative tune method -- VFO bump ignored');
end;

procedure TFLRigRadio.VFOBumpUp(whichVFO: TVFO);
begin
   logger.Warn('[FLRig] no relative tune method -- VFO bump ignored');
end;

(* rig.set_bw exists, but what its number means is per rig. *)
procedure TFLRigRadio.SetFilter(filter: TRadioFilter; vfo: TVFO);
begin
   logger.Warn('[FLRig] filter change not supported through FLRig -- ignored');
end;

function TFLRigRadio.SetFilterHz(hz: integer; vfo: TVFO): integer;
begin
   logger.Warn('[FLRig] filter change not supported through FLRig -- %d Hz ignored', [hz]);
   Result := 0;
end;

(* TRUE MEANS NOT DONE, the house convention for this method. *)
function TFLRigRadio.MemoryKeyer(mem: integer): boolean;
begin
   logger.Warn('[FLRig] no message-memory method -- memory %d ignored', [mem]);
   Result := True;
end;

(* ---------------------------------------------------------------- CW -- *)

(* NOT A CW-BY-CAT RADIO (unit header): rcCWByCAT is not declared, so the
  CW-by-CAT keyer never reaches these, and CWIsFactoryOwned stays False.
  Inert, and silent at Debug -- StopCW is reached on every radio by the
  registry-wide no-link test, which fails on an ERROR. *)
procedure TFLRigRadio.BufferCW(msg: string);
begin
   logger.Debug('[FLRig] CW by CAT is not supported through FLRig -- text ignored');
end;

procedure TFLRigRadio.SendCW;
begin
end;

procedure TFLRigRadio.StopCW;
begin
end;

procedure TFLRigRadio.SetCWSpeed(speed: integer);
begin
   logger.Debug('[FLRig] no CW speed sync -- %d wpm not sent', [speed]);
end;

(* --------------------------------------------------------------- inbound -- *)

procedure TFLRigRadio.PollRadioState;
var
   values: TStringList;
   answer: TFLRigAnswer;
   i: integer;
begin
   if not FLinkUp then
      begin
      Exit;
      end;

   values := TStringList.Create;
   try
      (* The frequency is the question that says whether FLRig is there. *)
      if Query('rig.get_vfoA', values) <> faAnswered then
         begin
         logger.Info('[FLRig] no answer to rig.get_vfoA -- link down');
         FLinkUp := False;
         Exit;
         end;
      ApplyAnswer('rig.get_vfoA', values);

      for i := Low(FLRIG_POLLED) to High(FLRIG_POLLED) do
         begin
         answer := AskOptional(FLRIG_POLLED[i], values);
         if (answer = faLinkFailed) or (answer = faNoAnswer) then
            begin
            logger.Info('[FLRig] no answer to %s -- link down', [FLRIG_POLLED[i]]);
            FLinkUp := False;
            Exit;
            end;
         if answer = faAnswered then
            begin
            ApplyAnswer(FLRIG_POLLED[i], values);
            end;
         end;
   finally
      values.Free;
   end;
end;

(* Not called by a reading thread -- there is none.  Required by the base. *)
procedure TFLRigRadio.ProcessMsg(msg: string);
begin
   logger.Debug('[FLRig] ProcessMsg is not used by this driver ("%s")', [msg]);
end;

procedure TFLRigRadio.ApplyAnswer(const aMethod: string; aValues: TStrings);
var
   hz: LongInt;
   newMode: TRadioMode;
   isOn: boolean;
   first: string;
begin
   if aValues.Count = 0 then
      begin
      logger.Debug('[FLRig] %s answered nothing', [aMethod]);
      Exit;
      end;
   first := aValues[0];

   if aMethod = 'rig.get_vfoA' then
      begin
      if TryFLRigHz(first, hz) and (hz > 0) then
         begin
         Self.vfo[nrVFOA].frequency := hz;
         Self.vfo[nrVFOA].band := FreqToRadioBand(hz);
         FRigReporting := True;
         end
      else
         begin
         (* 0, or not a number: FLRig is up, the rig is not reporting.  Keep
           what we had; IsOperational says the rest. *)
         FRigReporting := False;
         logger.Debug('[FLRig] no VFO A frequency from the rig ("%s")', [first]);
         end;
      end
   else if aMethod = 'rig.get_vfoB' then
      begin
      if TryFLRigHz(first, hz) and (hz > 0) then
         begin
         Self.vfo[nrVFOB].frequency := hz;
         Self.vfo[nrVFOB].band := FreqToRadioBand(hz);
         end;
      end
   else if (aMethod = 'rig.get_modeA') or (aMethod = 'rig.get_modeB') then
      begin
      if FLRigModeToRadioMode(first, newMode) then
         begin
         if aMethod = 'rig.get_modeA' then
            begin
            Self.vfo[nrVFOA].mode := newMode;
            end
         else
            begin
            Self.vfo[nrVFOB].mode := newMode;
            end;
         end
      else
         begin
         logger.Debug('[FLRig] %s: unknown mode "%s" -- kept', [aMethod, first]);
         end;
      end
   else if aMethod = 'rig.get_ptt' then
      begin
      if TryFLRigFlag(first, isOn) then
         begin
         SetTransmitting(isOn);
         end;
      end
   else if aMethod = 'rig.get_split' then
      begin
      if TryFLRigFlag(first, isOn) then
         begin
         SetSplitOn(isOn);
         end;
      end
   else if aMethod = 'rig.get_AB' then
      begin
      if first <> FLastAB then
         begin
         FLastAB := first;
         logger.Info('[FLRig] FLRig reports VFO %s active -- TR4W treats VFO A as the receive VFO', [first]);
         end;
      end
   else
      begin
      logger.Debug('[FLRig] answer to %s not used', [aMethod]);
      end;
end;

(* ---------------------------------------------------------- registration -- *)

function CreateFLRig: TFactoryRadioBase;
begin
   Result := TFLRigRadio.Create;
end;

initialization
   (* THE FLRIG ENUM MEMBER, taken over from the HamLib bridge
     (uRadioHamLibOnly) so existing profiles -- RegistryId 'FLRIG' -- load
     this driver.  Network only: FLRig is reached by HTTP and nothing else.
     discoverable = False: FLRig announces nothing.  HamLib id 4
     (RIG_MODEL_FLRIG) is kept so "Drive through HamLib" still reaches the
     bridge as a fallback. *)
   RegisterRadio(FLRIG,
      CreateFLRig,
      'FLRig (XML-RPC)', [rlNetwork], FLRIG_DEFAULT_PORT, False,
      (* Network only, so the serial row is never used to open a port -- but
        EVERY ENUM REGISTRATION STATES A SELECTABLE SERIAL ROW
        (uTestSerialParams walks the enum: a selectable baud, 8 data bits, no
        parity, the legacy stop-bit rule).  These are the values the HamLib
        bridge registered for FLRIG (57600 8N2, the software bridges' seed),
        kept unchanged so the row a profile was seeded with does not move. *)
      SerialParams(57600, 8, PARITY_NONE, 2),
      4);

   (* The D7-era capability sets never knew a native FLRig driver; comparing
     this one against them would report it wrong for stating facts they
     never held (uRadioRegistry.MarkPostLegacy). *)
   MarkPostLegacy(FLRIG);

end.
