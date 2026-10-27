unit uNetSendQueue;
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
  THE MAIN THREAD NEVER WRITES TO THE MULTI-OP SERVER.

  THE DEFECT.  Every outbound packet to tr4wserver (a QSO, a station status, a
  time sync, an intercom line, a serial-number request) was written by
  TNetClient.Send, on whatever thread called SendToNet -- the main thread for
  all but the connect announcements -- through Indy's IOHandler.Write, which has
  no write timeout.  A stalled server or a link that has stopped acknowledging
  fills the socket's send buffer, and the next Write then blocks the operator's
  keyboard for as long as the stall lasts.

  THE SHAPE (the same as uQsoDispatcher, deliberately).  The caller builds the
  COMPLETE packet bytes on its own thread -- so the packet holds the state of
  the moment it was posted -- and Post copies them into a FIFO and returns.
  ONE writer thread, owned by this object, takes them in order and hands each to
  the writer function.  Order between packets is exactly the order callers
  posted them, because there is one queue and one thread.

  WHY A SEPARATE UNIT.  This unit knows nothing about Indy, the socket, or the
  protocol: the writer is a function the owner supplies.  That is what lets the
  ordering, the no-drop rule, the stall report and the bounded shutdown be unit
  tested with a stub writer and no network.

  NEVER DROPPED.  Unlike the dispatcher's droppable kinds, nothing here is
  stale: a QSO, an edit, a serial-number change and a status are each the only
  copy of an event, and the server's log, the serial lockout and the other
  stations' displays depend on every one arriving in order.  The queue is
  therefore unbounded; a stall grows it by the packets the operator makes (a few
  hundred bytes each) and it drains when the link recovers.  A packet is lost
  only when the WRITE FAILS -- exactly as it was lost when the old synchronous
  send failed -- and that is counted, logged with the packet's kind, and
  reported through OnLost.

  A SLOW WRITE IS NAMED.  A write that takes more than SlowMs (250 ms) logs a
  Warn naming the packet kind, so a sluggish server shows in the log instead of
  as an unexplained pause.  WriteStalledMs tells the owner how long the CURRENT
  write has been in flight, which is how it decides to cut a link that has
  stopped accepting bytes.

  SHUTDOWN IS BOUNDED.  Shutdown(ms) lets the queue drain for up to ms and
  afterwards stops the thread, waiting a short grace for the write in progress.  It
  returns False when the thread is stuck inside a write; the owner then closes
  the socket to unblock it (that is the owner's, not this unit's, business) and
  must not free anything the writer uses until Shutdown returns True.
*)

interface

uses
   SysUtils,
   Classes,
   SyncObjs;

type
   (* Runs on the WRITER THREAD.  True when every byte was written; False, or an
     exception, when the packet could not be sent (a link that is down is
     False). *)
   TNetWriteFunc = function(const aBytes: TBytes): boolean of object;

   (* A packet's write FINISHED, one way or the other.  Both run on the WRITER
     THREAD.  aTag is whatever the poster attached (0 for none): the queue
     never reads it, it hands it back so the owner can tell WHICH packet.

     OnWritten means the bytes were handed to the socket -- not that the far
     end read them.  OnLost means the write failed, or the link was already
     down, and the packet is gone.  A packet still queued when Shutdown ends
     is reported by neither: it was never attempted. *)
   TNetLostEvent = procedure(const aKind: string; const aTag: Int64);
   TNetWrittenEvent = procedure(const aKind: string; const aTag: Int64);

   TNetSendQueue = class
   private
      FLock: TCriticalSection;
      FQueue: TList;
      FWake: TEvent;           // auto-reset: something was posted, or stop
      FIdle: TEvent;           // manual-reset: queue empty and no write in flight
      FDone: TEvent;           // manual-reset: the worker has left RunWorker
      FWorker: TThread;
      FWriter: TNetWriteFunc;
      FOnLost: TNetLostEvent;
      FOnWritten: TNetWrittenEvent;
      FStopping: boolean;
      FInFlight: boolean;
      FWriteStarted: QWord;
      FSlowMs: integer;
      FPosted: integer;
      FWritten: integer;
      FLostCount: integer;
      FSlowCount: integer;

      procedure EnsureWorker;
      procedure FreeQueued;
   public
      constructor Create(const aWriter: TNetWriteFunc);
      destructor Destroy; override;

      (* Copies aBytes and returns at once; never blocks on the network, never
        raises for it.  False only after Shutdown.  aTag rides with the packet
        and comes back through OnWritten or OnLost. *)
      function Post(const aKind: string; const aBytes: TBytes;
                    const aTag: Int64 = 0): boolean;

      // True when everything posted has been written (or lost).
      function WaitIdle(const aTimeoutMs: Cardinal): boolean;

      (* Drains for up to aTimeoutMs, then stops the thread (grace 250 ms for
        the write in progress).  True: the thread is gone.  False: it is stuck
        inside a write.  Packets still queued at the end are counted and
        reported as an Error. *)
      function Shutdown(const aTimeoutMs: Cardinal): boolean;

      // How long the write in flight has been running; 0 when none is.
      function WriteStalledMs: QWord;

      // Called by the worker thread; not for callers.
      procedure RunWorker;

      property SlowMs: integer read FSlowMs write FSlowMs;
      property OnLost: TNetLostEvent read FOnLost write FOnLost;
      property OnWritten: TNetWrittenEvent read FOnWritten write FOnWritten;

      function Posted: integer;
      function Written: integer;
      function LostCount: integer;
      function SlowCount: integer;
      function QueueDepth: integer;
   end;

const
   NET_SLOW_WRITE_MS_DEFAULT = 250;

implementation

uses
   Log4D;

type
   TNetSendItem = class
   public
      Kind: string;
      Bytes: TBytes;
      Tag: Int64;
   end;

   TNetSendThread = class(TThread)
   private
      FOwner: TNetSendQueue;
   protected
      procedure Execute; override;
   public
      constructor Create(const aOwner: TNetSendQueue);
   end;

var
   logger: TLogLogger;

(* TNetSendThread *)

constructor TNetSendThread.Create(const aOwner: TNetSendQueue);
begin
   FOwner := aOwner;
   FreeOnTerminate := False;
   inherited Create(False);
end;

procedure TNetSendThread.Execute;
begin
   FOwner.RunWorker;
end;

(* TNetSendQueue *)

constructor TNetSendQueue.Create(const aWriter: TNetWriteFunc);
begin
   inherited Create;
   FWriter := aWriter;
   FLock   := TCriticalSection.Create;
   FQueue  := TList.Create;
   FWake   := TEvent.Create(nil, False, False, '');
   FIdle   := TEvent.Create(nil, True, True, '');
   FDone   := TEvent.Create(nil, True, False, '');
   FWorker := nil;
   FSlowMs := NET_SLOW_WRITE_MS_DEFAULT;
end;

destructor TNetSendQueue.Destroy;
begin
   if not Shutdown(500) then
      begin
      // A write is stuck.  Memory the worker is using must outlive it.
      FDone.WaitFor(High(Cardinal));
      if FWorker <> nil then
         begin
         FWorker.WaitFor;
         FreeAndNil(FWorker);
         end;
      end;
   FreeQueued;
   FQueue.Free;
   FDone.Free;
   FIdle.Free;
   FWake.Free;
   FLock.Free;
   inherited Destroy;
end;

procedure TNetSendQueue.FreeQueued;
var
   i: integer;
begin
   FLock.Enter;
   try
      for i := 0 to FQueue.Count - 1 do
         begin
         TNetSendItem(FQueue[i]).Free;
         end;
      FQueue.Clear;
   finally
      FLock.Leave;
   end;
end;

procedure TNetSendQueue.EnsureWorker;
begin
   // Caller holds the lock.  Started on first use, so an owner that never
   // posts never owns a thread.
   if FWorker = nil then
      begin
      FWorker := TNetSendThread.Create(Self);
      end;
end;

function TNetSendQueue.Post(const aKind: string; const aBytes: TBytes;
                            const aTag: Int64 = 0): boolean;
var
   item: TNetSendItem;
begin
   item := TNetSendItem.Create;
   item.Kind  := aKind;
   item.Bytes := Copy(aBytes, 0, Length(aBytes));
   item.Tag   := aTag;

   FLock.Enter;
   try
      Result := not FStopping;
      if Result then
         begin
         FQueue.Add(item);
         Inc(FPosted);
         FIdle.ResetEvent;
         EnsureWorker;
         end;
   finally
      FLock.Leave;
   end;

   if Result then
      begin
      FWake.SetEvent;
      end
   else
      begin
      item.Free;
      end;
end;

procedure TNetSendQueue.RunWorker;
var
   item: TNetSendItem;
   stopping: boolean;
   started: QWord;
   elapsed: QWord;
   ok: boolean;
   failure: string;
   slowMs: integer;
begin
   try
      while True do
         begin
         item := nil;
         stopping := False;

         FLock.Enter;
         try
            stopping := FStopping;
            if (not stopping) and (FQueue.Count > 0) then
               begin
               item := TNetSendItem(FQueue[0]);
               FQueue.Delete(0);
               FInFlight := True;
               FWriteStarted := GetTickCount64;
               end;
         finally
            FLock.Leave;
         end;

         if stopping then
            begin
            Break;
            end;

         if item = nil then
            begin
            FWake.WaitFor(1000);
            Continue;
            end;

         ok := False;
         failure := '';
         started := FWriteStarted;
         try
            try
               ok := FWriter(item.Bytes);
            except
               on E: Exception do
                  begin
                  failure := E.ClassName + ': ' + E.Message;
                  end;
            end;
            elapsed := GetTickCount64 - started;

            FLock.Enter;
            try
               FInFlight := False;
               slowMs := FSlowMs;
               if ok then
                  begin
                  Inc(FWritten);
                  end
               else
                  begin
                  Inc(FLostCount);
                  end;
               if elapsed > QWord(slowMs) then
                  begin
                  Inc(FSlowCount);
                  end;
               if FQueue.Count = 0 then
                  begin
                  FIdle.SetEvent;
                  end;
            finally
               FLock.Leave;
            end;

            if elapsed > QWord(slowMs) then
               begin
               logger.Warn('[NetSend] write of %s (%d bytes) took %d ms',
                           [item.Kind, Length(item.Bytes), Integer(elapsed)]);
               end;

            if ok and Assigned(FOnWritten) then
               begin
               try
                  FOnWritten(item.Kind, item.Tag);
               except
                  on E: Exception do
                     begin
                     logger.Error('[NetSend] OnWritten for %s raised %s - %s',
                                  [item.Kind, E.ClassName, E.Message]);
                     end;
               end;
               end;

            if not ok then
               begin
               if failure = '' then
                  begin
                  failure := 'no link';
                  end;
               logger.Warn('[NetSend] send failed, packet %s (%d bytes) not delivered: %s',
                           [item.Kind, Length(item.Bytes), failure]);
               if Assigned(FOnLost) then
                  begin
                  try
                     FOnLost(item.Kind, item.Tag);
                  except
                     on E: Exception do
                        begin
                        logger.Error('[NetSend] OnLost for %s raised %s - %s',
                                     [item.Kind, E.ClassName, E.Message]);
                        end;
                  end;
                  end;
               end;
         finally
            item.Free;
         end;
         end;
   except
      on E: Exception do
         begin
         logger.Error('[NetSend] Writer stopped by %s - %s', [E.ClassName, E.Message]);
         end;
   end;
   FDone.SetEvent;
end;

function TNetSendQueue.WaitIdle(const aTimeoutMs: Cardinal): boolean;
begin
   Result := FIdle.WaitFor(aTimeoutMs) = wrSignaled;
end;

function TNetSendQueue.Shutdown(const aTimeoutMs: Cardinal): boolean;
var
   worker: TThread;
   pending: integer;
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
         logger.Error('[NetSend] Shutdown: the writer thread is still inside a write after %d ms',
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

   FLock.Enter;
   try
      pending := FQueue.Count;
   finally
      FLock.Leave;
   end;
   if pending > 0 then
      begin
      logger.Error('[NetSend] Shutdown: %d packet(s) were NOT delivered to the server', [pending]);
      end;
   FreeQueued;
   FIdle.SetEvent;   // nothing is pending any more, so a later WaitIdle must not wait
   Result := True;
end;

function TNetSendQueue.WriteStalledMs: QWord;
begin
   FLock.Enter;
   try
      if FInFlight then
         begin
         Result := GetTickCount64 - FWriteStarted;
         end
      else
         begin
         Result := 0;
         end;
   finally
      FLock.Leave;
   end;
end;

function TNetSendQueue.Posted: integer;
begin
   FLock.Enter;
   try
      Result := FPosted;
   finally
      FLock.Leave;
   end;
end;

function TNetSendQueue.Written: integer;
begin
   FLock.Enter;
   try
      Result := FWritten;
   finally
      FLock.Leave;
   end;
end;

function TNetSendQueue.LostCount: integer;
begin
   FLock.Enter;
   try
      Result := FLostCount;
   finally
      FLock.Leave;
   end;
end;

function TNetSendQueue.SlowCount: integer;
begin
   FLock.Enter;
   try
      Result := FSlowCount;
   finally
      FLock.Leave;
   end;
end;

function TNetSendQueue.QueueDepth: integer;
begin
   FLock.Enter;
   try
      Result := FQueue.Count;
   finally
      FLock.Leave;
   end;
end;

initialization
   logger := TLogLogger.GetLogger('TR4WDebugLog.NetSend');

end.
