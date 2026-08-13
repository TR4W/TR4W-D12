{
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
}
unit uWebSocketServer;
{$I tr4w.inc}

{
  A MINIMAL RFC 6455 WEBSOCKET SERVER -- TRANSPORT ONLY, NO TCI KNOWLEDGE.

  The mirror of uWebSocketClient, over Indy's TIdTCPServer, sharing all its
  framing with uWebSocketFraming.  It exists so TR4W can offer a TCI server:
  only one program can hold a radio's COM port, so anything else that wants
  the radio has to come through us.

  THREADING -- read this before touching anything.

  Indy gives each connection its own thread and calls OnExecute on it in a
  loop.  That thread does the handshake and then blocks reading frames; it is
  the ONLY thread that reads.  Writing is the interesting half:

    A BROADCAST ORIGINATES ON THE RADIO POLLING THREAD.  If a broadcast wrote
    to sockets directly, one wedged client would block the poller for as long
    as TCP takes to notice -- i.e. a client on a dropped Wi-Fi link would
    stall radio polling for the whole station.  That is unacceptable, so
    SendText NEVER touches a socket.  It appends to a per-session queue and
    signals; a per-session sender thread does the blocking write.

  So each connection owns two threads: Indy's reader and our sender.  With the
  client cap at 8 that is a bounded 16, and each sender is parked on an event
  when idle.  This is the same reader/sender pair uExternalLogger already uses.

  The queue is BOUNDED.  A client that stops reading must not make TR4W grow
  without limit; past the cap the session is closed and says why.  Dropping a
  stalled client is the correct answer for a state-broadcast protocol -- the
  data it is missing is superseded on the next poll anyway.

  BINDING.  Loopback by default.  These clients (WSJT-X, JTDX, a skimmer) run
  on the operator's own machine, and an unauthenticated radio-control socket
  on every interface is not something to switch on without being asked.
  uWSJTX's Commander server binds all interfaces unconditionally; that is not
  a precedent worth following.
}

interface

uses
   Windows, SysUtils, Classes, SyncObjs,
   IdTCPServer, IdContext, IdGlobal, IdSocketHandle,
   uWebSocketFraming;

const
   // Ceilings.  Deliberately small: TCI commands are tens of bytes, so
   // anything near these limits is a bug or an attack, not traffic.
   WSS_MAX_CLIENTS      = 8;
   WSS_MAX_FRAME_BYTES  = 64 * 1024;
   WSS_MAX_QUEUED_MSGS  = 512;

type
   TWebSocketServer = class;
   TWSServerSession = class;

   TWSServerTextEvent    = procedure(Session: TWSServerSession; const Text: string) of object;
   TWSServerSessionEvent = procedure(Session: TWSServerSession) of object;

   { Drains one session's outbound queue.  Exists so a blocking socket write
     can never happen on the radio polling thread or on Indy's reader. }
   TWSSenderThread = class(TThread)
   private
      FSession: TWSServerSession;
   protected
      procedure Execute; override;
   public
      constructor Create(ASession: TWSServerSession);
   end;

   { One connected client.  Created in OnConnect, destroyed in OnDisconnect,
     both on that connection's own Indy thread. }
   TWSServerSession = class(TObject)
   private
      FServer:        TWebSocketServer;
      FContext:       TIdContext;
      FId:            integer;
      FPeer:          string;
      FHandshakeDone: boolean;
      FClosed:        boolean;
      FReassembler:   TWSReassembler;

      FQueue:         TStringList;
      FQueueLock:     TCriticalSection;
      FQueueSignal:   TEvent;
      FSender:        TWSSenderThread;

      FTag:           TObject;

      function  ReadExactly(Count: integer; var Buf: TBytes): boolean;
      function  DoHandshake: boolean;
      procedure WriteFrame(Opcode: Byte; const Payload: TBytes);
      // Drains up to the whole queue.  Sender thread only.
      function  DrainOnce: boolean;
      procedure StartSender;
      procedure StopSender;
      procedure DisconnectSocket;
   public
      constructor Create(AServer: TWebSocketServer; AContext: TIdContext; AId: integer);
      destructor  Destroy; override;

      // Queues one TEXT message.  Safe from any thread and never blocks on
      // the socket.  Silently does nothing once the session is closing.
      procedure SendText(const Text: string);

      // Asks the connection to close.  Safe from any thread and never blocks:
      // it only raises the flag and wakes the sender, which does the actual
      // socket teardown.  Closing a socket can block, and this is reachable
      // from the radio polling thread.
      procedure Close;

      property Id:   integer read FId;
      property Peer: string  read FPeer;
      property Closed: boolean read FClosed;

      // Consumer-owned per-session state (the TCI server hangs its PTT
      // ownership here).  The SESSION OWNS IT and frees it -- assign an
      // object, not a reference to something with a longer life.
      property Tag: TObject read FTag write FTag;
   end;

   TWebSocketServer = class(TObject)
   private
      FServer:     TIdTCPServer;
      FSessions:   TThreadList;
      FPort:       integer;
      FBindAll:    boolean;
      FActive:     boolean;
      FLastError:  string;
      FNextId:     integer;

      FOnText:          TWSServerTextEvent;
      FOnSessionOpened: TWSServerSessionEvent;
      FOnSessionClosed: TWSServerSessionEvent;

      procedure DoConnect(AContext: TIdContext);
      procedure DoExecute(AContext: TIdContext);
      procedure DoDisconnect(AContext: TIdContext);

      procedure AddSession(Session: TWSServerSession);
      procedure RemoveSession(Session: TWSServerSession);
   public
      constructor Create;
      destructor  Destroy; override;

      // Binds and listens.  BindAll false means 127.0.0.1 only.
      function  Start(APort: integer; ABindAll: boolean): boolean;
      procedure Stop;

      // Queues Text to every open session.  Safe from any thread; holds the
      // session-list lock only long enough to enqueue, never to write.
      procedure Broadcast(const Text: string);

      function  SessionCount: integer;

      property Active:    boolean read FActive;
      property Port:      integer read FPort;
      property BindAll:   boolean read FBindAll;
      property LastError: string  read FLastError;

      // Raised on the session's own Indy reader thread.
      property OnTextMessage:   TWSServerTextEvent    read FOnText          write FOnText;
      property OnSessionOpened: TWSServerSessionEvent read FOnSessionOpened write FOnSessionOpened;
      // Raised before the session (and its Tag) are destroyed.
      property OnSessionClosed: TWSServerSessionEvent read FOnSessionClosed write FOnSessionClosed;
   end;

implementation

uses
   MainUnit;   // logger

{ ------------------------------------------------------- TWSSenderThread -- }

constructor TWSSenderThread.Create(ASession: TWSServerSession);
begin
   FSession := ASession;
   FreeOnTerminate := False;
   inherited Create(False);
end;

procedure TWSSenderThread.Execute;
begin
   while not Terminated do
      begin
      // A timeout as well as the signal, so a Terminate that races the last
      // Set is still noticed promptly.
      FSession.FQueueSignal.WaitFor(250);
      if Terminated then
         begin
         Break;
         end;
      try
         if not FSession.DrainOnce then
            begin
            Break;
            end;
         if FSession.Closed then
            begin
            // Someone asked for the close from another thread.  Doing the
            // teardown here rather than there is what keeps Close non-blocking.
            FSession.DisconnectSocket;
            Break;
            end;
      except
         on E: Exception do
            begin
            logger.Debug('[TCI-WS] sender %d stopping: %s', [FSession.Id, E.Message]);
            Break;
            end;
      end;
      end;
end;

{ ------------------------------------------------------ TWSServerSession -- }

constructor TWSServerSession.Create(AServer: TWebSocketServer;
                                    AContext: TIdContext; AId: integer);
begin
   inherited Create;
   FServer := AServer;
   FContext := AContext;
   FId := AId;
   FHandshakeDone := False;
   FClosed := False;
   FReassembler := TWSReassembler.Create;
   FQueue := TStringList.Create;
   FQueueLock := TCriticalSection.Create;
   FQueueSignal := TEvent.Create(nil, False, False, '');
   FPeer := '?';
   try
      FPeer := AContext.Binding.PeerIP + ':' + IntToStr(AContext.Binding.PeerPort);
   except
      // A connection can die before we ever ask its address; the label is
      // for the log, so a missing one is not worth failing over.
   end;
end;

destructor TWSServerSession.Destroy;
begin
   StopSender;
   FreeAndNil(FTag);
   FreeAndNil(FQueueSignal);
   FreeAndNil(FQueueLock);
   FreeAndNil(FQueue);
   FreeAndNil(FReassembler);
   inherited Destroy;
end;

procedure TWSServerSession.StartSender;
begin
   if not Assigned(FSender) then
      begin
      FSender := TWSSenderThread.Create(Self);
      end;
end;

procedure TWSServerSession.StopSender;
begin
   if Assigned(FSender) then
      begin
      FSender.Terminate;
      FQueueSignal.SetEvent;
      FSender.WaitFor;
      FreeAndNil(FSender);
      end;
end;

function TWSServerSession.ReadExactly(Count: integer; var Buf: TBytes): boolean;
var
   idb: TIdBytes;
begin
   Result := False;
   SetLength(Buf, 0);
   if Count <= 0 then
      begin
      Result := True;
      Exit;
      end;
   try
      SetLength(idb, 0);
      FContext.Connection.IOHandler.ReadBytes(idb, Count, False);
      if Length(idb) <> Count then
         begin
         Exit;
         end;
      SetLength(Buf, Count);
      Move(idb[0], Buf[0], Count);
      Result := True;
   except
      Result := False;
   end;
end;

function TWSServerSession.DoHandshake: boolean;
var
   lines: TStringList;
   line:  string;
   key:   string;
   err:   string;
begin
   Result := False;
   lines := TStringList.Create;
   try
      // Read the request head.  A blank line ends it; the cap stops a peer
      // that opens a socket and dribbles headers forever.
      repeat
         line := FContext.Connection.IOHandler.ReadLn;
         if line <> '' then
            begin
            lines.Add(line);
            end;
      until (line = '') or (lines.Count > 100);

      if not WSParseHandshakeRequest(lines, key, err) then
         begin
         logger.Warn('[TCI-WS] %s refused: %s', [FPeer, err]);
         try
            FContext.Connection.IOHandler.Write(
               'HTTP/1.1 400 Bad Request'#13#10
               + 'Connection: close'#13#10#13#10);
         except
            // The peer may already be gone.
         end;
         Exit;
         end;

      FContext.Connection.IOHandler.Write(WSBuildHandshakeResponse(key));
      Result := True;
   finally
      lines.Free;
   end;
end;

procedure TWSServerSession.WriteFrame(Opcode: Byte; const Payload: TBytes);
var
   frame: TBytes;
   idb:   TIdBytes;
begin
   // wsrServer: RFC 6455 FORBIDS a server masking its frames.
   frame := WSEncodeFrame(wsrServer, Opcode, Payload);
   SetLength(idb, Length(frame));
   if Length(frame) > 0 then
      begin
      Move(frame[0], idb[0], Length(frame));
      end;
   FContext.Connection.IOHandler.Write(idb);
end;

procedure TWSServerSession.SendText(const Text: string);
var
   overflow: boolean;
begin
   if FClosed or (not FHandshakeDone) then
      begin
      Exit;
      end;

   overflow := False;
   FQueueLock.Enter;
   try
      if FQueue.Count >= WSS_MAX_QUEUED_MSGS then
         begin
         overflow := True;
         end
      else
         begin
         FQueue.Add(Text);
         end;
   finally
      FQueueLock.Leave;
   end;

   if overflow then
      begin
      // A client that has stopped reading is not one we can keep buffering
      // for.  Say so rather than silently dropping messages -- a half-fed
      // client is worse than a disconnected one, because it keeps acting on
      // stale state.
      logger.Warn('[TCI-WS] %s (id %d) is not reading; %d messages queued - closing',
                  [FPeer, FId, WSS_MAX_QUEUED_MSGS]);
      Close;
      Exit;
      end;

   FQueueSignal.SetEvent;
end;

function TWSServerSession.DrainOnce: boolean;
var
   batch: TStringList;
   i:     integer;
begin
   Result := True;
   batch := TStringList.Create;
   try
      FQueueLock.Enter;
      try
         if FQueue.Count = 0 then
            begin
            Exit;
            end;
         batch.Assign(FQueue);
         FQueue.Clear;
      finally
         FQueueLock.Leave;
      end;

      for i := 0 to batch.Count - 1 do
         begin
         if FClosed then
            begin
            Result := False;
            Exit;
            end;
         try
            WriteFrame(WS_OP_TEXT, WSStringToUtf8Bytes(batch[i]));
         except
            on E: Exception do
               begin
               logger.Debug('[TCI-WS] write to %s failed: %s', [FPeer, E.Message]);
               FClosed := True;
               Result := False;
               Exit;
               end;
         end;
         end;
   finally
      batch.Free;
   end;
end;

procedure TWSServerSession.Close;
begin
   FClosed := True;
   FQueueSignal.SetEvent;
end;

procedure TWSServerSession.DisconnectSocket;
begin
   try
      FContext.Connection.Disconnect;
   except
      // Already gone.
   end;
end;

{ -------------------------------------------------------- TWebSocketServer -- }

constructor TWebSocketServer.Create;
begin
   inherited Create;
   FSessions := TThreadList.Create;
   FNextId := 0;
   FActive := False;

   FServer := TIdTCPServer.Create(nil);
   FServer.OnConnect := DoConnect;
   FServer.OnExecute := DoExecute;
   FServer.OnDisconnect := DoDisconnect;
end;

destructor TWebSocketServer.Destroy;
begin
   Stop;
   FreeAndNil(FServer);
   FreeAndNil(FSessions);
   inherited Destroy;
end;

function TWebSocketServer.Start(APort: integer; ABindAll: boolean): boolean;
var
   binding: string;
   handle:  TIdSocketHandle;
begin
   Result := False;
   FLastError := '';
   if FActive then
      begin
      Result := True;
      Exit;
      end;

   FPort := APort;
   FBindAll := ABindAll;

   if FBindAll then
      begin
      binding := '';        // every interface
      end
   else
      begin
      binding := '127.0.0.1';
      end;

   try
      FServer.Bindings.Clear;
      FServer.MaxConnections := WSS_MAX_CLIENTS;
      handle := FServer.Bindings.Add;
      handle.IP := binding;
      handle.Port := FPort;
      FServer.Active := True;
      FActive := True;
      Result := True;
      if FBindAll then
         begin
         logger.Warn('[TCI-WS] listening on ALL interfaces, port %d - ' +
                     'radio control is offered to the whole network', [FPort]);
         end
      else
         begin
         logger.Info('[TCI-WS] listening on 127.0.0.1:%d', [FPort]);
         end;
   except
      on E: Exception do
         begin
         FLastError := E.Message;
         logger.Error('[TCI-WS] could not listen on port %d: %s', [FPort, E.Message]);
         end;
   end;
end;

procedure TWebSocketServer.Stop;
begin
   if not FActive then
      begin
      Exit;
      end;
   FActive := False;
   try
      // Deactivating disconnects every client, which runs DoDisconnect on
      // each connection thread and frees the sessions there.
      FServer.Active := False;
   except
      on E: Exception do
         begin
         logger.Debug('[TCI-WS] stop: %s', [E.Message]);
         end;
   end;
   logger.Info('[TCI-WS] stopped');
end;

procedure TWebSocketServer.AddSession(Session: TWSServerSession);
var
   list: TList;
begin
   list := FSessions.LockList;
   try
      list.Add(Session);
   finally
      FSessions.UnlockList;
   end;
end;

procedure TWebSocketServer.RemoveSession(Session: TWSServerSession);
var
   list: TList;
begin
   list := FSessions.LockList;
   try
      list.Remove(Session);
   finally
      FSessions.UnlockList;
   end;
end;

function TWebSocketServer.SessionCount: integer;
var
   list: TList;
begin
   list := FSessions.LockList;
   try
      Result := list.Count;
   finally
      FSessions.UnlockList;
   end;
end;

procedure TWebSocketServer.Broadcast(const Text: string);
var
   list: TList;
   i:    integer;
begin
   list := FSessions.LockList;
   try
      // SendText only enqueues, so the lock is held for microseconds even
      // with a wedged client in the list.  That is what keeps the radio
      // polling thread safe to call this from.
      for i := 0 to list.Count - 1 do
         begin
         TWSServerSession(list[i]).SendText(Text);
         end;
   finally
      FSessions.UnlockList;
   end;
end;

procedure TWebSocketServer.DoConnect(AContext: TIdContext);
var
   session: TWSServerSession;
begin
   session := TWSServerSession.Create(Self, AContext, InterlockedIncrement(FNextId));
   AContext.Data := session;
   AddSession(session);
   logger.Info('[TCI-WS] client %d connected from %s', [session.Id, session.Peer]);
end;

procedure TWebSocketServer.DoExecute(AContext: TIdContext);
var
   session: TWSServerSession;
   frame:   TWSFrame;
   err:     string;
   text:    string;
   res:     TWSReadResult;
begin
   session := TWSServerSession(AContext.Data);
   if session = nil then
      begin
      AContext.Connection.Disconnect;
      Exit;
      end;

   if not session.FHandshakeDone then
      begin
      if not session.DoHandshake then
         begin
         session.FClosed := True;
         AContext.Connection.Disconnect;
         Exit;
         end;
      session.FHandshakeDone := True;
      // Only now can anything be queued -- SendText before this point would
      // race the 101 onto the wire ahead of the handshake response.
      session.StartSender;
      if Assigned(FOnSessionOpened) then
         begin
         FOnSessionOpened(session);
         end;
      Exit;
      end;

   res := WSReadFrame(session.ReadExactly, wsrServer, WSS_MAX_FRAME_BYTES, frame, err);
   if res = wsReadProtocolError then
      begin
      logger.Warn('[TCI-WS] client %d: %s - closing', [session.Id, err]);
      session.FClosed := True;
      AContext.Connection.Disconnect;
      Exit;
      end;
   if res <> wsReadOK then
      begin
      session.FClosed := True;
      AContext.Connection.Disconnect;
      Exit;
      end;

   case frame.Opcode of
      WS_OP_PING:
         begin
         // RFC 6455: a PONG must echo the PING's payload exactly.  Written
         // straight out rather than queued -- it is a liveness answer and
         // must not sit behind a backlog of state broadcasts.
         try
            session.WriteFrame(WS_OP_PONG, frame.Payload);
         except
            session.FClosed := True;
         end;
         end;

      WS_OP_PONG:
         begin
         // Liveness only.
         end;

      WS_OP_CLOSE:
         begin
         try
            session.WriteFrame(WS_OP_CLOSE, frame.Payload);
         except
            // The peer is closing; a failed echo is not interesting.
         end;
         session.FClosed := True;
         AContext.Connection.Disconnect;
         end;
   else
      case session.FReassembler.Accept(frame, WSS_MAX_FRAME_BYTES, text, err) of
         wsAcceptText:
            begin
            if Assigned(FOnText) then
               begin
               FOnText(session, text);
               end;
            end;

         wsAcceptError:
            begin
            logger.Warn('[TCI-WS] client %d: %s - closing', [session.Id, err]);
            session.FClosed := True;
            AContext.Connection.Disconnect;
            end;
      end;
   end;
end;

procedure TWebSocketServer.DoDisconnect(AContext: TIdContext);
var
   session: TWSServerSession;
begin
   session := TWSServerSession(AContext.Data);
   if session = nil then
      begin
      Exit;
      end;
   AContext.Data := nil;

   session.FClosed := True;
   RemoveSession(session);

   // Fires while the session is still whole, so a consumer can read its Tag
   // (the TCI server unkeys PTT here).  Failing closed on disconnect is the
   // rule: a lost client that owned the transmitter must not leave it keyed.
   if Assigned(FOnSessionClosed) then
      begin
      try
         FOnSessionClosed(session);
      except
         on E: Exception do
            begin
            logger.Error('[TCI-WS] session-closed handler raised: %s', [E.Message]);
            end;
      end;
      end;

   logger.Info('[TCI-WS] client %d (%s) disconnected', [session.Id, session.Peer]);
   session.Free;
end;

end.
