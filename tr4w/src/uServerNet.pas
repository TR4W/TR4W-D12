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

   public
      { Public for the same reason as the methods: the handlers are members of
        a DIFFERENT class in this unit, and private means private to the class,
        not to the unit. }
      property PeerIP: string read FPeerIP write FPeerIP;

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

{ Starts both listeners.  False and a logged reason if either port is taken --
  the old code showed a message box from inside bind() and this keeps that,
  since a server that cannot listen has nothing else to say. }
function StartServerNet(const aPort: word; const aSyncPort: word): boolean;

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
   logger.Info('[Net] client %s (%s) admitted', [FPeerIP, FPeerName]);
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
   ProcessClientBuffer(Handle, FLen);
end;

procedure TServerConn.SyncDrop;
begin
   if FAdmitted then
      begin
      FAdmitted := False;
      { Said out loud: at a multi-op, "when did that station drop" is the
        question, and the old code logged nothing at all here. }
      logger.Info('[Net] client %s disconnected', [FPeerIP]);
      DeleteSocketFromArray(Handle);
      DisplayClients;
      end;
end;

{ ------------------------------------------------------------- handlers -- }

(* WHY THE HANDSHAKE IS IN OnExecute AND NOT OnConnect.

  Indy calls OnConnect before the client has necessarily sent anything, and
  this protocol expects the client to speak first -- the original slept 200 ms
  after accept() and then read ten bytes. A read belongs where reads are
  allowed to block, which is OnExecute. *)
procedure TServerEvents.MainExecute(AContext: TIdContext);
var
   c:   TServerConn;
   got: integer;
   raw: TIdBytes;
begin
   c := TServerConn(AContext);

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

function StartServerNet(const aPort: word; const aSyncPort: word): boolean;
begin
   Result := False;
   try
      if GEvents = nil then
         begin
         GEvents := TServerEvents.Create;
         end;

      GMain := TIdTCPServer.Create(nil);
      GMain.ContextClass  := TServerConn;
      GMain.DefaultPort   := aPort;
      GMain.OnConnect     := GEvents.MainConnect;
      GMain.OnExecute     := GEvents.MainExecute;
      GMain.OnDisconnect  := GEvents.MainDisconnect;
      GMain.Active        := True;

      GSync := TIdTCPServer.Create(nil);
      GSync.ContextClass  := TServerConn;
      GSync.DefaultPort   := aSyncPort;
      GSync.OnExecute     := GEvents.SyncExecute;
      GSync.Active        := True;

      Result := True;
      logger.Info('[Net] listening on %d, log sync on %d', [aPort, aSyncPort]);
   except
      on E: Exception do
         begin
         logger.Error('[Net] cannot listen on %d: %s', [aPort, E.Message]);
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
function ContextOf(const aHandle: Cardinal): TServerConn;
var
   list: TIdContextList;
   i:    integer;
begin
   Result := nil;
   if GMain = nil then
      begin
      Exit;
      end;

   list := GMain.Contexts.LockList;
   try
      for i := 0 to list.Count - 1 do
         begin
         if TServerConn(list[i]).Handle = aHandle then
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
