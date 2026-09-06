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
 Public License along with TR4W in GPL_License.TXT.
 If not, ref: http://www.gnu.org/licenses/gpl-3.0.txt
}
unit uServerNet;
{$I tr4w.inc}

{
  TR4WSERVER'S TRANSPORT, ON INDY.

  WHAT IT REPLACES.  WSAAsyncSelect -- Windows delivering socket events as
  WINDOW MESSAGES.  The server was a Win32 dialog whose procedure answered
  WM_SOCK_NET_ACCEPT, WM_SOCK_NET_RX and WM_SOCK_NET_SYNLISTNER, which meant
  the WINDOW WAS PART OF THE TRANSPORT and neither could be converted without
  the other.  That is the same knot the client's uNet was in until it moved to
  Indy on 2026-08-25, and it is untied the same way.

  Gone with it: socket/bind/listen/accept/recv/closesocket, WSAStartup,
  WSACleanup, the message-only sink window, and TransmitFile with the
  LoadLibrary of MSWSOCK.DLL that fed it.

  THE ENGINE STILL RUNS ON ONE THREAD, AND THAT IS THE WHOLE DESIGN.

  Indy gives every client a thread.  tr4wserverUnit is written for a single
  one: ServerBuffer is a global, ClientsSoocketsArray is a global, the log file
  handle is a global, and the parse loop walks all three.  Letting Indy's
  threads into that would turn a protocol parser into a concurrency problem and
  the failure would look like a corrupted log at a multi-op, six hours in.

  So the connection threads do ONE thing -- move bytes -- and every step that
  touches engine state runs on the main thread through Synchronize.

  SYNCHRONIZE, NOT QUEUE.  Under FPC, TThread.Queue PURGES ITS OWN CALLBACK:
  RemoveQueuedEvents is called for the thread as it finishes, and a queued
  method that has not run yet is discarded -- silently.  Synchronize is exempt
  because it BLOCKS the calling thread until the main thread has run it, which
  is also exactly the back-pressure this wants: a client that floods cannot run
  ahead of the parser.  The client side records the same trap (uTCIServer has
  four such sites).

  THE CLIENT'S IDENTITY IS STILL ITS SOCKET HANDLE.  ClientsSoocketsArray keys
  on clSocket and forty call sites pass it around, so Indy's binding handle is
  what goes in there.  Nothing in the engine changed shape.

  WRITES ARE LOCKED PER CONNECTION.  The engine sends from the main thread
  while that client's own thread may be inside a read; Indy's IOHandler is not
  safe for both at once, so every write takes the connection's lock.
}

interface

uses
   Classes, SysUtils, SyncObjs,
   IdContext, IdCustomTCPServer, IdTCPServer, IdGlobal, IdIOHandler,
   IdTCPConnection, IdYarn, IdExceptionCore, IdException;

type

   (* ONE CONNECTED CLIENT.

     It carries its own receive buffer, because ServerBuffer is a global the
     engine parses from: the connection thread reads into FBuf and the
     Synchronize'd step copies it across.  Two clients reading at once into the
     shared buffer would interleave two protocol streams. *)
   TServerConn = class(TIdServerContext)
   private
      FWriteLock: TCriticalSection;
      FBuf:       array[0..4095] of AnsiChar;
      FLen:       integer;
      FPeerIP:    string;
      FPeerName:  string;
      FAdmitted:  boolean;
      FRefused:   boolean;
      (* THE HANDLE AS IT WAS WHEN THE CLIENT WAS ADMITTED.

        Handle asks the CONNECTION for its binding, and by the time SyncDrop
        runs the socket is gone and it answers 0 -- which matches no entry in
        ClientsSoocketsArray, so the slot was never freed. The log gave it
        away: 'client 6', 'client 7', 'client 8' on successive reconnects.
        After maxclients cycles the server would quietly stop accepting. *)
      FHandle:    Cardinal;

   public
      { Public for the same reason as the methods: the handlers are members of
        a DIFFERENT class in this unit, and private means private to the class,
        not to the unit. }
      property PeerIP: string read FPeerIP write FPeerIP;

      (* THE KEY THIS CLIENT IS REGISTERED UNDER, and the only one to match on.

        Handle asks the CONNECTION for its binding and answers 0 the moment
        that binding is gone, so a lookup by Handle misses a client that is
        still in the list -- measured, with the whole handshake succeeding and
        the reply then dropped (2026-09-06). AddSocketToArray was given
        FHandle; ContextOf must ask for FHandle. *)
      property AdmittedHandle: Cardinal read FHandle;

      { Public because the handlers below are methods of a DIFFERENT class in
        this unit, and a private member is visible only to its own. }
      procedure SyncHandshake;
      procedure SyncCheckPassword;
      procedure SyncParse;
      procedure SyncDrop;
      constructor Create(AConnection: TIdTCPConnection; AYarn: TIdYarn;
                         AList: TIdContextThreadList = nil); override;
      destructor Destroy; override;

      { The socket handle, which is what the engine calls a client. }
      function Handle: Cardinal;

      property WriteLock: TCriticalSection read FWriteLock;
   end;

(* EVERY LOCAL IPv4 ADDRESS, USABLE BEFORE ANYTHING IS LISTENING.

  IncUsage/DecUsage is the point. GStack is nil until something creates it, and
  activating a server is what usually does -- which is why reading
  GStack.LocalAddress before StartServerNet made the program vanish with no
  window and no log line this morning. The drop-down has to be filled BEFORE
  the operator presses Start, so this brings the stack up itself and puts it
  back down.

  GetLocalAddressList rather than the AddLocalAddressesToList shorthand: the
  shorthand is marked deprecated in the vendored Indy and this build's warning
  count is a ratchet. Filtering to Id_IPv4 is exactly what it did. *)
procedure GetLocalAddresses(const aList: TStrings);

{ Starts both listeners on aBindIP -- EMPTY MEANS EVERY INTERFACE, which is
  what this server has always done and stays the default.  False and a logged
  reason if either port is taken -- the old code showed a message box from
  inside bind() and this keeps that, since a server that cannot listen has
  nothing else to say. }
function StartServerNet(const aPort: word; const aSyncPort: word;
                        const aBindIP: string): boolean;

procedure StopServerNet;

{ What sSend became.  Returns the number of bytes written, or -1 -- the same
  contract recv/send had, because BytesSEND accounting depends on it. }
function SendToClient(const aHandle: Cardinal; const aBuf;
                      const aLen: integer): integer;

{ What closesocket(client) became. }
procedure DropClient(const aHandle: Cardinal);

{ True while the listeners are up. }
function ServerNetActive: boolean;

implementation

uses
   IdSocketHandle, IdIOHandlerSocket,
   IdStack,       { TIdStack.IncUsage, GStack, TIdStackLocalAddressList }
   tr4wserverUnit,
   Log4D;

type
   (* SOMEWHERE FOR THE HANDLERS TO LIVE.

     TIdTCPServer's OnConnect, OnExecute and OnDisconnect are
     `procedure(AContext: TIdContext) of object` -- METHOD pointers -- so plain
     procedures cannot be assigned to them. This class exists for no other
     reason; it holds no state. *)
   TServerEvents = class
      procedure MainConnect(AContext: TIdContext);
      procedure MainExecute(AContext: TIdContext);
      procedure MainDisconnect(AContext: TIdContext);
      procedure SyncExecute(AContext: TIdContext);
   end;

var
   GMain:   TIdTCPServer = nil;
   GSync:   TIdTCPServer = nil;
   GEvents: TServerEvents = nil;

(* THE WIRE, IN HEX.

  sRecv used to do this and went with the WinSock read. It is the first thing
  anyone wants when a client will not connect: not "the handshake failed" but
  the bytes that failed it.

  Capped, because a full 4 KB read is 12 KB of hex and the interesting part of
  any TR4W message is its first few bytes -- the two-byte id and what follows. *)
function HexOf(const aBuf; const aLen: integer): string;
const
   MAX_BYTES = 64;
var
   p: PByte;
   i, n: integer;
begin
   Result := '';
   n := aLen;
   if n > MAX_BYTES then
      begin
      n := MAX_BYTES;
      end;

   p := @aBuf;
   for i := 0 to n - 1 do
      begin
      Result := Result + IntToHex(p[i], 2) + ' ';
      end;

   if aLen > n then
      begin
      Result := Result + Format('... (%d more)', [aLen - n]);
      end;
end;

{ ------------------------------------------------------------ TServerConn }

constructor TServerConn.Create(AConnection: TIdTCPConnection; AYarn: TIdYarn;
                               AList: TIdContextThreadList);
begin
   inherited Create(AConnection, AYarn, AList);
   FWriteLock := TCriticalSection.Create;
end;

destructor TServerConn.Destroy;
begin
   FreeAndNil(FWriteLock);
   inherited Destroy;
end;

function TServerConn.Handle: Cardinal;
begin
   Result := 0;
   if (Connection <> nil) and (Connection.Socket <> nil) and
      Connection.Socket.BindingAllocated then
      begin
      Result := Cardinal(Connection.Socket.Binding.Handle);
      end;
end;

(* THE HANDSHAKE, ON THE MAIN THREAD.

  CorrectPassword reads the GLOBAL ServerBuffer, so the bytes have to be there
  before it is called -- which is why this runs here rather than on the
  connection thread. The sequence is the accept arm's, unchanged: check the
  password, answer 'TR4W', record the client, tell it the log size, and
  re-publish the serial numbers. *)
procedure TServerConn.SyncHandshake;
begin
   FRefused := True;

   Move(FBuf[0], ServerBuffer[0], FLen);

   if not CorrectPassword(Handle, FLen) then
      begin
      { CorrectPassword has already sent PASSTR4W. }
      logger.Warn('[Net] client %s refused: password', [FPeerIP]);
      Exit;
      end;

   if sSend(Handle, SENDTR4W, SizeOf(SENDTR4W), dmTR4W) <> SizeOf(SENDTR4W) then
      begin
      logger.Warn('[Net] client %s refused: could not answer TR4W', [FPeerIP]);
      Exit;
      end;

   AddSocketToArray(Handle, PAnsiChar(AnsiString(FPeerIP)),
                    PAnsiChar(AnsiString(FPeerName)));
   DisplayClients;
   SendLogFileInformation(Handle);
   SerialNumbersChanged;

   FRefused  := False;
   FAdmitted := True;
   { FHandle is set in MainConnect, where the binding is certain to be readable. }
   logger.Info('[Net] client %s (%s) admitted as %d', [FPeerIP, FPeerName, FHandle]);
end;

(* THE SYNC PORT'S HANDSHAKE, which is the password check and nothing else.

  A log-sync client is not a multi-op client: it does not join
  ClientsSoocketsArray, gets no 'TR4W' answer, and is gone as soon as the file
  has been written. Same password, different consequence. *)
procedure TServerConn.SyncCheckPassword;
begin
   Move(FBuf[0], ServerBuffer[0], FLen);
   FRefused := not CorrectPassword(Handle, FLen);
   if FRefused then
      begin
      logger.Warn('[Net] log-sync client %s refused: password', [FPeerIP]);
      end;
end;

procedure TServerConn.SyncParse;
begin
   Move(FBuf[0], ServerBuffer[0], FLen);
   BytesRCVD := BytesRCVD + Cardinal(FLen);
   ProcessClientBuffer(FHandle, FLen);
end;

procedure TServerConn.SyncDrop;
begin
   if FAdmitted then
      begin
      FAdmitted := False;
      { Said out loud: at a multi-op, "when did that station drop" is the
        question, and the old code logged nothing at all here. }
      logger.Info('[Net] client %s (%d) disconnected', [FPeerIP, FHandle]);
      { FHandle, not Handle: see the field. }
      DeleteSocketFromArray(FHandle);
      DisplayClients;
      end;
end;

{ ------------------------------------------------------------- handlers -- }

(* WHY THE HANDSHAKE IS IN OnExecute AND NOT OnConnect.

  Indy calls OnConnect before the client has necessarily sent anything, and
  this protocol expects the client to speak first -- the original slept 200 ms
  after accept() and then read ten bytes. A read belongs where reads are
  allowed to block, which is OnExecute. *)
(* EVERY FAULT IN HERE IS REPORTED.

  Indy catches whatever escapes OnExecute and closes the connection, so a bug
  in the read path is indistinguishable from a client hanging up: the log shows
  a clean disconnect and nothing else. That is exactly what NY4I saw --
  connect, handshake, 'Computer ID A accepted', gone, five seconds later again.

  So the body is wrapped and the reason is written down. Re-raised, because
  Indy still has to close the connection; what changes is that we know why. *)
procedure TServerEvents.MainExecute(AContext: TIdContext);
var
   c:   TServerConn;
   got: integer;
   raw: TIdBytes;
begin
   c := TServerConn(AContext);
   try

   if not c.FAdmitted then
      begin
      { The password, and nothing else yet.  ReadTimeout stops a connection
        that says nothing from holding a thread for ever -- the original had
        no such guard and simply blocked. }
      c.Connection.IOHandler.ReadTimeout := 15000;
      SetLength(raw, 0);
      c.Connection.IOHandler.ReadBytes(raw, 10, False);
      got := Length(raw);
      if got <= 0 then
         begin
         c.Connection.Disconnect;
         Exit;
         end;

      c.FLen := got;
      Move(raw[0], c.FBuf[0], got);

      { The handshake in particular: a wrong password looks identical to a
        wrong protocol until you see the bytes. }
      logger.Debug('[Net] handshake: %d bytes from %s', [got, c.FPeerIP]);
      if logger.IsTraceEnabled then
         begin
         logger.Trace('[Net] rx %s: %s', [c.FPeerIP, HexOf(c.FBuf[0], got)]);
         end;

      TThread.Synchronize(nil, c.SyncHandshake);

      if c.FRefused then
         begin
         c.Connection.Disconnect;
         end;
      Exit;
      end;

   { Admitted: whatever has arrived, handed to the parser whole. }
   c.Connection.IOHandler.ReadTimeout := IdTimeoutDefault;
   c.Connection.IOHandler.CheckForDataOnSource(250);
   got := c.Connection.IOHandler.InputBuffer.Size;
   if got <= 0 then
      begin
      Exit;
      end;
   if got > SizeOf(c.FBuf) then
      begin
      got := SizeOf(c.FBuf);
      end;

   SetLength(raw, 0);
   c.Connection.IOHandler.ReadBytes(raw, got, False);
   got := Length(raw);
   if got <= 0 then
      begin
      Exit;
      end;

   c.FLen := got;
   Move(raw[0], c.FBuf[0], got);

   { The wire trace sRecv used to write, now naming the station it came from. }
   logger.Debug('[Net] %d bytes from %s', [got, c.FPeerIP]);
   if logger.IsTraceEnabled then
      begin
      logger.Trace('[Net] rx %s: %s', [c.FPeerIP, HexOf(c.FBuf[0], got)]);
      end;

   TThread.Synchronize(nil, c.SyncParse);

   except
      { A closed connection is ORDINARY and is not a fault: the client quit,
        or the link dropped. Indy signals it by raising, and saying "error"
        about a normal disconnect would be worse than saying nothing. }
      on E: EIdConnClosedGracefully do
         begin
         logger.Debug('[Net] %s closed the connection', [c.FPeerIP]);
      end;
      { EIdSocketError lives in IdStack and is not worth a uses entry for one
        arm; EIdException covers it and everything else Indy raises. }
      on E: EIdException do
         begin
         logger.Info('[Net] %s: %s: %s', [c.FPeerIP, E.ClassName, E.Message]);
         end;
      on E: Exception do
         begin
         { THIS is the one that was invisible. }
         logger.Error('[Net] %s: unhandled %s in the read path: %s',
                      [c.FPeerIP, E.ClassName, E.Message]);
         raise;
         end;
   end;
end;

procedure TServerEvents.MainConnect(AContext: TIdContext);
var
   c: TServerConn;
begin
   c := TServerConn(AContext);
   c.FPeerIP   := AContext.Binding.PeerIP;
   { The original did a reverse DNS lookup with gethostbyaddr and showed '?'
     when it failed.  Indy has no portable equivalent that is worth a blocking
     lookup on the accept path, so the address stands in for the name until
     something better is wanted -- it is a display string only. }
   c.FPeerName := '?';
   c.FAdmitted := False;
   c.FRefused  := False;

   (* THE HANDLE, CAPTURED WHILE IT CAN STILL BE READ.

     Everything that sends to this client finds it by handle, including the
     handshake's own acknowledgement -- so the value has to be valid from the
     moment the context exists, not from the moment the handshake finishes.
     The binding is right here (PeerIP and PeerPort come off it) and the handle
     never changes afterwards; only the ability to ask for it does, which is
     exactly why this is remembered rather than fetched. *)
   c.FHandle := c.Handle;

   (* SAY SO THE MOMENT A SOCKET ARRIVES.

     Nothing was logged here, and the handshake is the first thing that speaks
     -- so a client that CONNECTED and then said nothing, or connected to the
     wrong port, or was refused by a firewall halfway, all looked identical
     from this side: an empty log. NY4I, 2026-09-06: "server shows no
     indication of activity."

     A connection is the first fact the server has about a client and it should
     be the first line about it. *)
   logger.Info('[Net] connection from %s:%d', [c.FPeerIP, AContext.Binding.PeerPort]);
end;

procedure TServerEvents.MainDisconnect(AContext: TIdContext);
begin
   TThread.Synchronize(nil, TServerConn(AContext).SyncDrop);
end;

(* THE LOG-SYNC LISTENER.

  A client connects on the second port, sends the password, and gets the whole
  server log back.  The original did that with TransmitFile from MSWSOCK.DLL --
  loaded with LoadLibrary, called through a GetProcAddress'd pointer, with a
  CreateThread fallback for the Windows versions that did not have it. Indy
  writes a stream. *)
procedure TServerEvents.SyncExecute(AContext: TIdContext);
var
   c:   TServerConn;
   raw: TIdBytes;
   got: integer;
   fs:  TFileStream;
   size: LongInt;
begin
   c := TServerConn(AContext);

   c.Connection.IOHandler.ReadTimeout := 15000;
   SetLength(raw, 0);
   c.Connection.IOHandler.ReadBytes(raw, 50, False);
   got := Length(raw);
   if got <= 0 then
      begin
      c.Connection.Disconnect;
      Exit;
      end;

   c.FLen := got;
   Move(raw[0], c.FBuf[0], got);
   TThread.Synchronize(nil, c.SyncCheckPassword);

   if c.FRefused then
      begin
      c.Connection.Disconnect;
      Exit;
      end;

   try
      fs := TFileStream.Create(String(PAnsiChar(@ServerLogFileName[0])),
                               fmOpenRead or fmShareDenyNone);
      try
         { The size FIRST, as a four-byte head -- that is the protocol: the old
           code put it in TRANSMIT_FILE_BUFFERS.Head. }
         size := fs.Size;
         c.Connection.IOHandler.Write(RawToBytes(size, SizeOf(size)));
         c.Connection.IOHandler.Write(fs, 0, False);
      finally
         fs.Free;
      end;
   except
      on E: Exception do
         begin
         logger.Error('[Net] sync: %s', [E.Message]);
         end;
   end;

   c.Connection.Disconnect;
end;

{ ------------------------------------------------------------- lifetime -- }

function ServerNetActive: boolean;
begin
   Result := (GMain <> nil) and GMain.Active;
end;

procedure GetLocalAddresses(const aList: TStrings);
var
   addrs: TIdStackLocalAddressList;
   i:     integer;
begin
   aList.Clear;

   TIdStack.IncUsage;
   try
      addrs := TIdStackLocalAddressList.Create;
      try
         GStack.GetLocalAddressList(addrs);
         for i := 0 to addrs.Count - 1 do
            begin
            if addrs[i].IPVersion = Id_IPv4 then
               begin
               aList.Add(addrs[i].IPAddress);
               end;
            end;
      finally
         addrs.Free;
      end;
   finally
      TIdStack.DecUsage;
   end;
end;

(* BIND ONE LISTENER, to one address or to all of them.

  Both servers want the identical lines, and a copy is where a difference
  hides. An empty aBindIP leaves Bindings empty, which is how Indy spells
  "every interface" -- the behaviour this program has always had. *)
procedure BindListener(const aServer: TIdTCPServer; const aPort: word;
                       const aBindIP: string);
begin
   aServer.Bindings.Clear;
   aServer.DefaultPort := aPort;

   if aBindIP <> '' then
      begin
      with aServer.Bindings.Add do
         begin
         IP   := aBindIP;
         Port := aPort;
         end;
      end;
end;

function StartServerNet(const aPort: word; const aSyncPort: word;
                        const aBindIP: string): boolean;
var
   where: string;
begin
   Result := False;
   try
      if GEvents = nil then
         begin
         GEvents := TServerEvents.Create;
         end;

      GMain := TIdTCPServer.Create(nil);
      GMain.ContextClass  := TServerConn;
      GMain.OnConnect     := GEvents.MainConnect;
      GMain.OnExecute     := GEvents.MainExecute;
      GMain.OnDisconnect  := GEvents.MainDisconnect;
      BindListener(GMain, aPort, aBindIP);
      GMain.Active        := True;

      GSync := TIdTCPServer.Create(nil);
      GSync.ContextClass  := TServerConn;
      GSync.OnExecute     := GEvents.SyncExecute;
      BindListener(GSync, aSyncPort, aBindIP);
      GSync.Active        := True;

      Result := True;

      { SAY WHICH. "It is listening" and "it is listening where you told it to"
        are different facts, and only the second one helps when a client cannot
        connect. }
      if aBindIP = '' then
         begin
         where := 'all interfaces';
         end
      else
         begin
         where := aBindIP;
         end;
      logger.Info('[Net] listening on %s port %d, log sync on %d',
                  [where, aPort, aSyncPort]);
   except
      on E: Exception do
         begin
         logger.Error('[Net] cannot listen on %s port %d: %s',
                      [aBindIP, aPort, E.Message]);
         ServerMessageBox('The server cannot listen on port ' + IntToStr(aPort)
            + '.' + sLineBreak + sLineBreak + E.Message
            + sLineBreak + sLineBreak
            + 'Check that no other copy of TR4WSERVER is running.',
            0);
         StopServerNet;
      end;
   end;
end;

procedure StopServerNet;
begin
   if GSync <> nil then
      begin
      GSync.Active := False;
      FreeAndNil(GSync);
      end;
   if GMain <> nil then
      begin
      GMain.Active := False;
      FreeAndNil(GMain);
      end;
end;

{ ----------------------------------------------------------- the engine -- }

(* FIND A CLIENT BY ITS SOCKET HANDLE.

  The engine says "send this to socket N" because that is what it has always
  said, so the lookup lives here rather than the identity changing everywhere.
  LockList/UnlockList because Indy owns the list and a client can disconnect
  between the engine deciding to write and the write happening. *)
(* FIND AN ADMITTED CLIENT BY THE HANDLE IT WAS ADMITTED UNDER.

  AdmittedHandle, NOT Handle -- see the property. Handle asks the CONNECTION
  for its binding and answers 0 the moment that binding is gone, so a lookup by
  Handle misses a client that is still in the list. Measured, with the whole
  handshake succeeding and the reply then silently dropped: "looking for 1068,
  list has 1 context(s): 0" (2026-09-06). AddSocketToArray was given FHandle,
  so ContextOf must ask for FHandle -- one key, or no match.

  A zero never matches, which is correct: a context that has connected but not
  finished the handshake has nothing that could be sent to it. *)
function ContextOf(const aHandle: Cardinal): TServerConn;
var
   list: TIdContextList;
   i:    integer;
begin
   Result := nil;
   if (aHandle = 0) or (GMain = nil) then
      begin
      Exit;
      end;

   list := GMain.Contexts.LockList;
   try
      for i := 0 to list.Count - 1 do
         begin
         if TServerConn(list[i]).AdmittedHandle = aHandle then
            begin
            Result := TServerConn(list[i]);
            Exit;
            end;
         end;
   finally
      GMain.Contexts.UnlockList;
   end;
end;

function SendToClient(const aHandle: Cardinal; const aBuf;
                      const aLen: integer): integer;
var
   c: TServerConn;
begin
   Result := -1;
   c := ContextOf(aHandle);
   if c = nil then
      begin
      (* A SEND TO A CLIENT THAT IS NOT THERE, AND IT USED TO BE SILENT.

        SendMessageToClients walks ClientsSoocketsArray and calls sSend for
        every non-zero slot, so a slot left behind by a client that has gone
        makes this fire once per broadcast, for ever, with no trace. That is
        how a leaked slot stayed invisible.

        The slot leak itself is fixed -- see TServerConn.FHandle -- and this
        says so if another one appears. *)
      logger.Warn('[Net] send to %d: no such client (a stale entry in the '
                  + 'client table?)', [aHandle]);
      Exit;
      end;

   c.WriteLock.Acquire;
   try
      try
         c.Connection.IOHandler.Write(RawToBytes(aBuf, aLen));
         Result := aLen;
         if logger.IsTraceEnabled then
            begin
            logger.Trace('[Net] tx %s: %s', [c.FPeerIP, HexOf(aBuf, aLen)]);
            end;
      except
         on E: Exception do
            begin
            logger.Debug('[Net] write to %d failed: %s', [aHandle, E.Message]);
            end;
      end;
   finally
      c.WriteLock.Release;
   end;
end;

procedure DropClient(const aHandle: Cardinal);
var
   c: TServerConn;
begin
   c := ContextOf(aHandle);
   if c <> nil then
      begin
      c.Connection.Disconnect;
      end;
end;

end.
