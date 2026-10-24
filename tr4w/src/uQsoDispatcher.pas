unit uQsoDispatcher;
{$I tr4w.inc}

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

(*
  ONE THREAD OWNS EVERY DELIVERY TO A PROGRAM OUTSIDE TR4W.

  THE DEFECT THIS EXISTS FOR.  On 2026-10-24 (CQ WW SSB) two QSOs froze the
  main thread for 2702 ms and 2680 ms (tr4w.log, CR6K and V47T; eight others
  took 2-6 ms).  The block that was timed made no TCP call -- the external
  logger was off and HamScore was off -- so what ran was the UDP broadcast, on
  the thread that had just pressed Enter, to a destination named by HOST NAME
  (Indy resolves it on every send).  The stall is a network stall; what makes
  it an operating defect is WHERE it was allowed to happen.

  THE SHAPE (NY4I's ruling, 2026-10-24): the main thread builds an immutable
  message and posts it.  It does nothing else about delivery.  This thread
  fans the message out to the sinks -- UDP broadcast, external logger, HamScore
  -- in that order, each one contained: a sink that is slow is logged, a sink
  that raises is logged, and neither stops the next.

  A MESSAGE HOLDS RESULTS, NOT STATE.  Everything that reads live state --
  Settings, the active contest, the radio's status record, the CTY tables, the
  operator -- is read by the BUILDER, on the main thread, at log time, and the
  answer is stored in the message as text.  A logged QSO describes the station
  it recorded and never today's settings (Q13).  The dispatcher thread never
  reads that state; it could not do so safely, because the contest object can
  be freed and rebuilt on any call.  What the dispatcher thread DOES read is
  each sink's own configuration, through that sink's lock (Wants), so a
  Preferences change applies to the very next message and cannot tear.

  WHAT THIS UNIT DELIBERATELY DOES NOT KNOW.  Indy, the contest engine, the
  settings model, and every concrete sink.  Sinks are TQsoSink descendants
  installed by uQsoSinks; a test installs recording stubs.  That is what lets
  the routing, the ordering, the bound and the shutdown be unit-tested with no
  socket.

  WHAT IT DOES NOT CARRY: the multi-op network (SendRecordToServer).  Its
  ordering and serial-number lockout belong to multi-op-network.

  THE DROPPABLE PART OF THE QUEUE IS BOUNDED (QueueLimit); THE QSO PART IS NOT.
  A destination that never answers must not grow memory for the rest of a
  contest on lookup, score, radio and rotor packets, all of which are stale as
  soon as the next one exists: when QueueLimit of them are waiting, the OLDEST
  goes.  A QSO-bearing message (new, edited, deleted) is NEVER dropped and Post
  never refuses it -- a resend of a whole log posts thousands -- so that part
  grows with the backlog (a few hundred bytes to ~2 KB each).  The drop is
  reported ONCE PER EPISODE (a run of drops ends when the queue next empties),
  not once per packet.

  ORDER: one FIFO and one thread, so order is preserved for every destination.
  The price is head-of-line blocking: one stalled destination delays the ones
  behind it by its stall.  That is a deliberate trade for simplicity; the slow
  send is named in the log (Warn, > SlowSinkMs), which is what shows whether a
  per-destination thread would ever be worth having.

  SHUTDOWN IS BOUNDED.  Shutdown(ms) waits that long for the queue to drain,
  then stops the thread and waits a short grace for the send in progress.  It
  returns False when the thread is stuck inside a sink; in that case the
  caller must NOT free anything the sink uses (the socket, the external
  logger) -- the process is exiting.
*)

interface

uses
   SysUtils,
   Classes,
   SyncObjs,
   uUDPBroadcastConfig;

type
   // What the message is about.  qmLookup and qmStream are the DROPPABLE kinds.
   TQsoMessageKind = (qmNew, qmEdited, qmDeleted, qmLookup, qmStream);

   // What the external logger is told to do; the commands are already built.
   TQsoExternalOp = (xoNone, xoSingle, xoReplace);

   // What HamScore is told; the body is already rendered.
   TQsoHamScoreOp = (hoNone, hoInfo, hoDelete);

   (* AN IMMUTABLE MESSAGE.  The builder fills the fields, then Posts it and
     does not touch it again: Post takes ownership, and from then on the
     dispatcher thread is the only one that reads it.  Every field is a value
     (a string or an enum) so there is nothing to share. *)
   TQsoMessage = class
   public
      Kind: TQsoMessageKind;
      Description: string;          // the callsign or stream name, for the log only

      // UDP.  An empty payload means this message has no UDP part.
      UDPStream: TUDPStream;
      UDPPayload: AnsiString;
      // DirectPort > 0 sends to exactly this endpoint (PstRotator), bypassing
      // the stream configuration.
      DirectAddress: string;
      DirectPort: integer;

      // External logger (DXKeeper).
      ExtOp: TQsoExternalOp;
      ExtCommand1: string;
      ExtCommand2: string;

      // HamScore.
      HamOp: TQsoHamScoreOp;
      HamQSOID: AnsiString;
      HamBody: AnsiString;

      constructor Create(const aKind: TQsoMessageKind; const aDescription: string);
      function IsDroppable: boolean;
   end;

   (* A DESTINATION FOR MESSAGES.  Wants and Deliver run on the dispatcher
     thread.  Wants answers "is this sink on, and does this message carry
     something for it" from the sink's OWN thread-safe configuration; it must
     not read live QSO state. *)
   TQsoSink = class
   public
      function Name: string; virtual; abstract;
      function Wants(const aMessage: TQsoMessage): boolean; virtual; abstract;
      procedure Deliver(const aMessage: TQsoMessage); virtual; abstract;
   end;

   TQsoDispatcher = class
   private
      FLock: TCriticalSection;
      FSinks: TList;
      FQueue: TList;
      FWake: TEvent;           // auto-reset: something was posted, or stop
      FIdle: TEvent;           // manual-reset: queue empty and nothing in flight
      FDone: TEvent;           // manual-reset: the worker has left RunWorker
      FWorker: TThread;
      FStopping: boolean;
      FSynchronous: boolean;
      FQueueLimit: integer;
      FDroppableQueued: integer;   // droppable messages currently in FQueue
      FSlowSinkMs: integer;
      FDropping: boolean;
      FDropsInEpisode: integer;
      FDropped: integer;
      FDropEpisodes: integer;
      FSlowDeliveries: integer;
      FFailures: integer;
      FDelivered: integer;

      procedure EnsureWorker;
      function PickVictim: integer;
      procedure DeliverToSinks(const aMessage: TQsoMessage);
      procedure FreeQueued;
   public
      constructor Create;
      // Waits for a stuck worker without limit -- see Shutdown.  Callers that
      // may hold a blocked sink call Shutdown first and do not Free on False.
      destructor Destroy; override;

      // Takes ownership.  Order of delivery is the order sinks were added.
      procedure AddSink(const aSink: TQsoSink);
      procedure ClearSinks;

      // Takes ownership of aMessage and returns at once.  Never blocks on a
      // sink, never raises for one.  After Shutdown a message is discarded.
      procedure Post(const aMessage: TQsoMessage);

      // The two UDP-only posts, so a stream packet does not need a builder.
      procedure PostUDP(const aStream: TUDPStream; const aPayload: AnsiString;
                        const aDescription: string);
      procedure PostUDPDirect(const aAddress: string; const aPort: integer;
                              const aPayload: AnsiString; const aDescription: string);

      // True when everything posted has been delivered (or dropped).
      function WaitIdle(const aTimeoutMs: Cardinal): boolean;

      (* Drains for up to aTimeoutMs, then stops the thread (grace 250 ms for
        the send in progress).  True: the thread is gone.  False: it is stuck
        inside a sink.  Messages still queued at the end are counted and
        reported -- a QSO message that never left is an Error. *)
      function Shutdown(const aTimeoutMs: Cardinal): boolean;

      // Called by the worker thread; not for callers.
      procedure RunWorker;

      (* INLINE DELIVERY, no thread.  For unit tests that read what a sink
        received straight after the call that posted it, and for a headless
        tool.  The program leaves it False. *)
      property Synchronous: boolean read FSynchronous write FSynchronous;
      property QueueLimit: integer read FQueueLimit write FQueueLimit;
      property SlowSinkMs: integer read FSlowSinkMs write FSlowSinkMs;

      function Dropped: integer;
      function DropEpisodes: integer;
      function SlowDeliveries: integer;
      function Failures: integer;
      function Delivered: integer;
      function QueueDepth: integer;
   end;

const
   QSO_QUEUE_LIMIT_DEFAULT = 256;
   QSO_SLOW_SINK_MS_DEFAULT = 250;

// The one instance.  Created on first use so no unit's initialisation order
// can matter, and stopped (bounded) in this unit's finalization.
function QsoDispatcher: TQsoDispatcher;

implementation

uses
   Log4D;

type
   TQsoDispatchThread = class(TThread)
   private
      FOwner: TQsoDispatcher;
   protected
      procedure Execute; override;
   public
      constructor Create(const aOwner: TQsoDispatcher);
   end;

var
   gDispatcher: TQsoDispatcher = nil;
   gCreateLock: TCriticalSection = nil;
   logger: TLogLogger;

function QsoDispatcher: TQsoDispatcher;
begin
   gCreateLock.Enter;
   try
      if gDispatcher = nil then
         begin
         gDispatcher := TQsoDispatcher.Create;
         end;
      Result := gDispatcher;
   finally
      gCreateLock.Leave;
   end;
end;

{ TQsoMessage }

constructor TQsoMessage.Create(const aKind: TQsoMessageKind; const aDescription: string);
begin
   inherited Create;
   Kind        := aKind;
   Description := aDescription;
   UDPStream   := usContact;
   UDPPayload  := '';
   DirectAddress := '';
   DirectPort  := 0;
   ExtOp       := xoNone;
   HamOp       := hoNone;
end;

function TQsoMessage.IsDroppable: boolean;
begin
   Result := Kind in [qmLookup, qmStream];
end;

{ TQsoDispatchThread }

constructor TQsoDispatchThread.Create(const aOwner: TQsoDispatcher);
begin
   FOwner := aOwner;
   FreeOnTerminate := False;
   inherited Create(False);
end;

procedure TQsoDispatchThread.Execute;
begin
   FOwner.RunWorker;
end;

{ TQsoDispatcher }

constructor TQsoDispatcher.Create;
begin
   inherited Create;
   FLock  := TCriticalSection.Create;
   FSinks := TList.Create;
   FQueue := TList.Create;
   FWake  := TEvent.Create(nil, False, False, '');
   FIdle  := TEvent.Create(nil, True, True, '');
   FDone  := TEvent.Create(nil, True, False, '');
   FWorker := nil;
   FQueueLimit := QSO_QUEUE_LIMIT_DEFAULT;
   FSlowSinkMs := QSO_SLOW_SINK_MS_DEFAULT;
end;

destructor TQsoDispatcher.Destroy;
begin
   if not Shutdown(500) then
      begin
      // A sink is stuck.  Memory the worker is using must outlive it, so wait.
      FDone.WaitFor(High(Cardinal));
      if FWorker <> nil then
         begin
         FWorker.WaitFor;
         FreeAndNil(FWorker);
         end;
      end;
   FreeQueued;
   ClearSinks;
   FSinks.Free;
   FQueue.Free;
   FDone.Free;
   FIdle.Free;
   FWake.Free;
   FLock.Free;
   inherited Destroy;
end;

procedure TQsoDispatcher.FreeQueued;
var
   i: integer;
begin
   FLock.Enter;
   try
      for i := 0 to FQueue.Count - 1 do
         begin
         TQsoMessage(FQueue[i]).Free;
         end;
      FQueue.Clear;
      FDroppableQueued := 0;
   finally
      FLock.Leave;
   end;
end;

procedure TQsoDispatcher.AddSink(const aSink: TQsoSink);
begin
   FLock.Enter;
   try
      FSinks.Add(aSink);
   finally
      FLock.Leave;
   end;
end;

procedure TQsoDispatcher.ClearSinks;
var
   i: integer;
begin
   FLock.Enter;
   try
      for i := 0 to FSinks.Count - 1 do
         begin
         TQsoSink(FSinks[i]).Free;
         end;
      FSinks.Clear;
   finally
      FLock.Leave;
   end;
end;

procedure TQsoDispatcher.EnsureWorker;
begin
   // Caller holds the lock.  Started on first use, so a program or a test that
   // never posts never owns a thread.
   if FWorker = nil then
      begin
      FWorker := TQsoDispatchThread.Create(Self);
      end;
end;

function TQsoDispatcher.PickVictim: integer;
var
   i: integer;
begin
   // Caller holds the lock.  The oldest droppable message, or -1 for none.
   Result := -1;
   for i := 0 to FQueue.Count - 1 do
      begin
      if TQsoMessage(FQueue[i]).IsDroppable then
         begin
         Result := i;
         Exit;
         end;
      end;
end;

procedure TQsoDispatcher.Post(const aMessage: TQsoMessage);
var
   victim: TQsoMessage;
   idx: integer;
   announce: boolean;
   deliverInline: boolean;
   discard: boolean;
   limit: integer;
   victimName: string;
begin
   if aMessage = nil then
      begin
      Exit;
      end;

   victim        := nil;
   victimName    := '';
   announce      := False;
   deliverInline := False;
   discard       := False;
   limit         := 0;

   FLock.Enter;
   try
      if FStopping then
         begin
         discard := True;
         end
      else if FSynchronous then
         begin
         deliverInline := True;
         end
      else
         begin
         (* THE BOUND APPLIES TO DROPPABLE MESSAGES ONLY.  A QSO-bearing
           message (new, edited, deleted) is never dropped and never refuses:
           "resend the whole log to UDP" and the HamScore resync post one per
           QSO -- thousands -- and each must arrive.  A message is a few
           hundred bytes of text (a contactinfo XML is about 1.5 KB, the
           HamScore body about 0.5 KB, the DXKeeper command about 0.6 KB; the
           message object itself ~100 B), so 5000 queued QSOs are well under
           10 MB.  That part of the queue grows with the backlog. *)
         if aMessage.IsDroppable and (FDroppableQueued >= FQueueLimit) then
            begin
            idx := PickVictim;
            if idx >= 0 then
               begin
               victim := TQsoMessage(FQueue[idx]);
               FQueue.Delete(idx);
               Dec(FDroppableQueued);
               end
            else
               begin
               // A limit of 0 or less: the newcomer is the only candidate.
               victim := aMessage;
               end;
            victimName := victim.Description;
            Inc(FDropped);
            Inc(FDropsInEpisode);
            if not FDropping then
               begin
               FDropping := True;
               Inc(FDropEpisodes);
               announce := True;
               limit := FQueueLimit;
               end;
            end;
         if victim <> aMessage then
            begin
            FQueue.Add(aMessage);
            if aMessage.IsDroppable then
               begin
               Inc(FDroppableQueued);
               end;
            FIdle.ResetEvent;
            EnsureWorker;
            end;
         end;
   finally
      FLock.Leave;
   end;

   if announce then
      begin
      logger.Warn('[QsoDispatcher] Queue full (%d): dropping the oldest droppable message (%s). ' +
                  'A sink is not keeping up; this is logged once per episode.',
                  [limit, victimName]);
      end;
   victim.Free;

   if discard then
      begin
      logger.Debug('[QsoDispatcher] Stopped: discarding the message for %s',
                   [aMessage.Description]);
      aMessage.Free;
      Exit;
      end;

   if deliverInline then
      begin
      try
         DeliverToSinks(aMessage);
      finally
         aMessage.Free;
      end;
      Exit;
      end;

   FWake.SetEvent;
end;

procedure TQsoDispatcher.PostUDP(const aStream: TUDPStream; const aPayload: AnsiString;
                                 const aDescription: string);
var
   msg: TQsoMessage;
begin
   if aStream = usLookup then
      begin
      msg := TQsoMessage.Create(qmLookup, aDescription);
      end
   else
      begin
      msg := TQsoMessage.Create(qmStream, aDescription);
      end;
   msg.UDPStream  := aStream;
   msg.UDPPayload := aPayload;
   Post(msg);
end;

procedure TQsoDispatcher.PostUDPDirect(const aAddress: string; const aPort: integer;
                                       const aPayload: AnsiString;
                                       const aDescription: string);
var
   msg: TQsoMessage;
begin
   msg := TQsoMessage.Create(qmStream, aDescription);
   msg.UDPPayload    := aPayload;
   msg.DirectAddress := aAddress;
   msg.DirectPort    := aPort;
   Post(msg);
end;

procedure TQsoDispatcher.DeliverToSinks(const aMessage: TQsoMessage);
var
   sinks: array of TQsoSink;
   i: integer;
   started: QWord;
   elapsed: QWord;
   slowMs: integer;
begin
   // The sink list is copied under the lock, so AddSink from another thread
   // cannot move it under the loop; the sinks themselves are called outside it.
   FLock.Enter;
   try
      SetLength(sinks, FSinks.Count);
      for i := 0 to FSinks.Count - 1 do
         begin
         sinks[i] := TQsoSink(FSinks[i]);
         end;
      slowMs := FSlowSinkMs;
   finally
      FLock.Leave;
   end;

   for i := 0 to High(sinks) do
      begin
      // ONE SINK'S FAILURE NEVER REACHES THE NEXT.
      try
         if sinks[i].Wants(aMessage) then
            begin
            started := GetTickCount64;
            sinks[i].Deliver(aMessage);
            elapsed := GetTickCount64 - started;
            FLock.Enter;
            try
               Inc(FDelivered);
               if elapsed > QWord(slowMs) then
                  begin
                  Inc(FSlowDeliveries);
                  end;
            finally
               FLock.Leave;
            end;
            if elapsed > QWord(slowMs) then
               begin
               logger.Warn('[QsoDispatcher] Sink %s took %d ms delivering %s for %s',
                           [sinks[i].Name, Integer(elapsed), 'a message', aMessage.Description]);
               end;
            end;
      except
         on E: Exception do
            begin
            FLock.Enter;
            try
               Inc(FFailures);
            finally
               FLock.Leave;
            end;
            logger.Error('[QsoDispatcher] Sink %s FAILED for %s: %s - %s',
                         [sinks[i].Name, aMessage.Description, E.ClassName, E.Message]);
            end;
      end;
      end;
end;

procedure TQsoDispatcher.RunWorker;
var
   msg: TQsoMessage;
   stopping: boolean;
   episodeEnded: boolean;
   episodeDrops: integer;
begin
   try
      while True do
         begin
         msg := nil;
         stopping := False;
         episodeEnded := False;
         episodeDrops := 0;

         FLock.Enter;
         try
            stopping := FStopping;
            if (not stopping) and (FQueue.Count > 0) then
               begin
               msg := TQsoMessage(FQueue[0]);
               FQueue.Delete(0);
               if msg.IsDroppable then
                  begin
                  Dec(FDroppableQueued);
                  end;
               end
            else if FQueue.Count = 0 then
               begin
               FIdle.SetEvent;
               if FDropping then
                  begin
                  FDropping := False;
                  episodeEnded := True;
                  episodeDrops := FDropsInEpisode;
                  FDropsInEpisode := 0;
                  end;
               end;
         finally
            FLock.Leave;
         end;

         if episodeEnded then
            begin
            logger.Info('[QsoDispatcher] Queue recovered; %d message(s) were dropped in that episode',
                        [episodeDrops]);
            end;

         if stopping then
            begin
            Break;
            end;

         if msg = nil then
            begin
            FWake.WaitFor(1000);
            Continue;
            end;

         try
            DeliverToSinks(msg);
         finally
            msg.Free;
         end;
         end;
   except
      on E: Exception do
         begin
         logger.Error('[QsoDispatcher] Worker stopped by %s - %s', [E.ClassName, E.Message]);
         end;
   end;
   FDone.SetEvent;
end;

function TQsoDispatcher.WaitIdle(const aTimeoutMs: Cardinal): boolean;
begin
   Result := FIdle.WaitFor(aTimeoutMs) = wrSignaled;
end;

function TQsoDispatcher.Shutdown(const aTimeoutMs: Cardinal): boolean;
var
   worker: TThread;
   pendingQso: integer;
   pendingAll: integer;
   i: integer;
begin
   // Let what is queued go out, within the bound.
   WaitIdle(aTimeoutMs);

   FLock.Enter;
   try
      FStopping := True;
      worker := FWorker;
   finally
      FLock.Leave;
   end;

   if worker <> nil then
      begin
      FWake.SetEvent;
      if FDone.WaitFor(250) <> wrSignaled then
         begin
         logger.Error('[QsoDispatcher] Shutdown: the dispatcher thread is still inside a sink after %d ms',
                      [aTimeoutMs + 250]);
         Result := False;
         Exit;
         end;
      worker.WaitFor;
      FLock.Enter;
      try
         FWorker := nil;
      finally
         FLock.Leave;
      end;
      worker.Free;
      end;

   pendingQso := 0;
   pendingAll := 0;
   FLock.Enter;
   try
      pendingAll := FQueue.Count;
      for i := 0 to FQueue.Count - 1 do
         begin
         if not TQsoMessage(FQueue[i]).IsDroppable then
            begin
            Inc(pendingQso);
            end;
         end;
   finally
      FLock.Leave;
   end;
   if pendingQso > 0 then
      begin
      logger.Error('[QsoDispatcher] Shutdown: %d QSO message(s) were NOT delivered to the ' +
                   'external programs (%d messages in all)', [pendingQso, pendingAll]);
      end;
   FreeQueued;
   Result := True;
end;

function TQsoDispatcher.Dropped: integer;
begin
   FLock.Enter;
   try
      Result := FDropped;
   finally
      FLock.Leave;
   end;
end;

function TQsoDispatcher.DropEpisodes: integer;
begin
   FLock.Enter;
   try
      Result := FDropEpisodes;
   finally
      FLock.Leave;
   end;
end;

function TQsoDispatcher.SlowDeliveries: integer;
begin
   FLock.Enter;
   try
      Result := FSlowDeliveries;
   finally
      FLock.Leave;
   end;
end;

function TQsoDispatcher.Failures: integer;
begin
   FLock.Enter;
   try
      Result := FFailures;
   finally
      FLock.Leave;
   end;
end;

function TQsoDispatcher.Delivered: integer;
begin
   FLock.Enter;
   try
      Result := FDelivered;
   finally
      FLock.Leave;
   end;
end;

function TQsoDispatcher.QueueDepth: integer;
begin
   FLock.Enter;
   try
      Result := FQueue.Count;
   finally
      FLock.Leave;
   end;
end;

initialization
   gCreateLock := TCriticalSection.Create;
   logger := TLogLogger.GetLogger('TR4WDebugLog.QsoDispatcher');

finalization
   (* BOUNDED.  If a sink is stuck the process is ending anyway; leaking the
     dispatcher is better than hanging the exit. *)
   if gDispatcher <> nil then
      begin
      if gDispatcher.Shutdown(1000) then
         begin
         FreeAndNil(gDispatcher);
         end;
      end;
   FreeAndNil(gCreateLock);

end.
