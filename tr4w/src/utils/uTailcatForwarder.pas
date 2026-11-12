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
 Public License along with TR4W in GPL_License.TXT.
 If not, ref: http://www.gnu.org/licenses/gpl-3.0.txt
*)
unit uTailcatForwarder;
{$I ..\tr4w.inc}

(* A LOCAL DOOR INTO A TAILCAT TUNNEL: what `tailcat forward` does, in-process.

  Issue 293.  For each port the server offers inside the tunnel, this listens
  on 127.0.0.1 at a port the operating system picks, and joins every local
  connection to a stream dialled through the tunnel to that port:

      TNetClient  ->  127.0.0.1:<local>  ->  tunnel  ->  server port
      catch-up    ->  127.0.0.1:<local2> ->  tunnel  ->  server port + 1

  WHY A DOOR AND NOT A TRANSPORT UNDER THE LINK.  The link (TNetClient) and the
  catch-up download are Indy TCP clients with their own handshake, timeouts and
  write queue, proven on the air.  Giving them a second kind of stream would
  touch all of that; giving them a different address touches two lines.  The
  price is one loopback hop and two threads for each connection, on a link
  that carries a few hundred bytes a QSO.  NY4I chose this boundary,
  2026-11-12.

  LOOPBACK ONLY, and that is a security statement: a listener on every
  interface would hand the tunnel -- and with it the server -- to anything on
  the station's network.  The local port is the system's choice (port 0), so it
  cannot collide with a server running on the same machine.

  THREADS.  Indy gives each local connection its own thread (LocalExecute),
  which carries local -> tunnel.  A TTunnelReader thread carries tunnel ->
  local.  That is one reader and one writer on each side, which is what both
  Indy and tailcat.h allow.  The reader never closes the local socket: it
  raises a flag and the connection's own thread closes it, within a quarter of
  a second.

  THIS UNIT LOGS NO ADDRESS.  It is given a log procedure and tells it ports,
  byte-free reasons and status names. *)

interface

uses
   SysUtils, Classes, uTailcatLib;

type
   TTailcatLogLevel = (tllDebug, tllInfo, tllWarn);
   TTailcatLogProc = procedure(const aLevel: TTailcatLogLevel;
                               const aText: string);

   TTailcatForwarder = class
   private
      FAddress:     string;
      FRemotePorts: array of word;
      FLocalPorts:  array of word;
      FServers:     TList;
      FClient:      TTailcatHandle;
      FLog:         TTailcatLogProc;
      FPingMs:      integer;
      procedure Log(const aLevel: TTailcatLogLevel; const aText: string);
      procedure LocalConnect(AContext: TObject);
      procedure LocalExecute(AContext: TObject);
      procedure LocalDisconnect(AContext: TObject);
   public
      (* aRemotePorts: the ports the server listens on inside the tunnel, in
        the order LocalPort answers them. *)
      constructor Create(const aAddress: string;
                         const aRemotePorts: array of word;
                         const aLog: TTailcatLogProc);
      destructor Destroy; override;

      (* MAKE THE CLIENT, REACH THE SERVER THROUGH THE TUNNEL, OPEN THE LOCAL
        PORTS -- in that order, so a True means the server answered a ping
        through the tunnel within aPingTimeoutMs. BLOCKS for up to that long:
        call it from a thread that may wait. The library must be loaded
        (uTailcatLib.TailcatLoad). False leaves nothing running and aWhy
        without the address. *)
      function Start(const aPingTimeoutMs: integer; out aWhy: string): boolean;

      (* Close every connection, the local ports and the client. Waits for the
        connection threads. Safe to call twice. *)
      procedure Stop;

      (* The 127.0.0.1 port standing for aRemotePorts[aIndex]; 0 before Start. *)
      function LocalPort(const aIndex: integer): word;

      (* Whether this forwarder was made for exactly this address and ports,
        so a caller can tell a changed setting without holding the secret. *)
      function IsFor(const aAddress: string;
                     const aRemotePorts: array of word): boolean;

      (* The round trip the ping in Start measured, in milliseconds. *)
      property PingMs: integer read FPingMs;
   end;

implementation

uses
   IdContext, IdCustomTCPServer, IdTCPServer, IdGlobal, IdException,
   IdSocketHandle;

const
   LOOPBACK        = '127.0.0.1';
   (* The link's own handshake gives up after five seconds, so a dial that
     takes longer has already lost its caller. *)
   DIAL_TIMEOUT_MS = 5000;
   PUMP_BYTES      = 16384;

type
   TTunnelReader = class;

   (* One local connection and the tunnel stream it is joined to. *)
   TTunnelContext = class(TIdServerContext)
   public
      FConn:   TTailcatHandle;
      FReader: TTunnelReader;
      (* Set by the reader when the tunnel side has ended; read by the
        connection's own thread. A boolean written once, so no lock. *)
      FTunnelEnded: boolean;
      (* The reader has stopped, or was never started. *)
      procedure ReleaseTunnel;
      destructor Destroy; override;
   end;

   (* tunnel -> local *)
   TTunnelReader = class(TThread)
   private
      FContext: TTunnelContext;
   protected
      procedure Execute; override;
   public
      constructor Create(const aContext: TTunnelContext);
   end;

   (* Indy's events are methods taking a TIdContext; the forwarder's own
     methods take TObject so the interface section needs no Indy unit. *)
   TIndyEvents = class
   public
      FOwner: TTailcatForwarder;
      procedure Connect(AContext: TIdContext);
      procedure Execute(AContext: TIdContext);
      procedure Disconnect(AContext: TIdContext);
   end;

   TForwardServer = class(TIdTCPServer)
   public
      FEvents:     TIndyEvents;
      FRemotePort: word;
      destructor Destroy; override;
   end;

destructor TForwardServer.Destroy;
begin
   inherited Destroy;
   FreeAndNil(FEvents);
end;

procedure TIndyEvents.Connect(AContext: TIdContext);
begin
   FOwner.LocalConnect(AContext);
end;

procedure TIndyEvents.Execute(AContext: TIdContext);
begin
   FOwner.LocalExecute(AContext);
end;

procedure TIndyEvents.Disconnect(AContext: TIdContext);
begin
   FOwner.LocalDisconnect(AContext);
end;

(* ------------------------------------------------------- TTunnelContext -- *)

procedure TTunnelContext.ReleaseTunnel;
begin
   (* Closing the stream is what wakes a reader blocked inside the library. *)
   if FConn <> TAILCAT_NO_HANDLE then
      begin
      TailcatClose(FConn);
      FConn := TAILCAT_NO_HANDLE;
      end;
   if FReader <> nil then
      begin
      FReader.WaitFor;
      FreeAndNil(FReader);
      end;
end;

destructor TTunnelContext.Destroy;
begin
   (* Normally a no-op: LocalDisconnect has done it. This is for a connection
     Indy tears down without raising that event. *)
   ReleaseTunnel;
   inherited Destroy;
end;

(* -------------------------------------------------------- TTunnelReader -- *)

constructor TTunnelReader.Create(const aContext: TTunnelContext);
begin
   FContext := aContext;
   FreeOnTerminate := False;
   inherited Create(False);
end;

procedure TTunnelReader.Execute;
var
   buffer: TIdBytes;
   count:  PtrUInt;
   status: integer;
   conn:   TTailcatHandle;
begin
   SetLength(buffer, PUMP_BYTES);
   (* A copy: ReleaseTunnel zeroes the field on another thread, and a closed
     handle is answered TC_CLOSED, which ends the loop. *)
   conn := FContext.FConn;
   try
      repeat
         status := TailcatRead(conn, @buffer[0], PUMP_BYTES, count);
         (* The bytes first, the status second: a read may deliver its last
           bytes together with the end. *)
         if count > 0 then
            begin
            FContext.Connection.IOHandler.Write(buffer, count);
            end;
      until status <> TC_OK;
   except
      (* The local side went away under the write. The connection's own
        thread sees the same thing and cleans up. *)
      on E: Exception do
         begin
         end;
   end;
   FContext.FTunnelEnded := True;
end;

(* ---------------------------------------------------- TTailcatForwarder -- *)

constructor TTailcatForwarder.Create(const aAddress: string;
                                     const aRemotePorts: array of word;
                                     const aLog: TTailcatLogProc);
var
   i: integer;
begin
   inherited Create;
   FAddress := aAddress;
   FLog := aLog;
   FClient := TAILCAT_NO_HANDLE;
   FServers := TList.Create;
   SetLength(FRemotePorts, Length(aRemotePorts));
   SetLength(FLocalPorts, Length(aRemotePorts));
   for i := 0 to High(aRemotePorts) do
      begin
      FRemotePorts[i] := aRemotePorts[i];
      FLocalPorts[i] := 0;
      end;
end;

destructor TTailcatForwarder.Destroy;
begin
   Stop;
   FreeAndNil(FServers);
   inherited Destroy;
end;

procedure TTailcatForwarder.Log(const aLevel: TTailcatLogLevel;
                                const aText: string);
begin
   if Assigned(FLog) then
      begin
      FLog(aLevel, aText);
      end;
end;

function TTailcatForwarder.IsFor(const aAddress: string;
                                 const aRemotePorts: array of word): boolean;
var
   i: integer;
begin
   Result := (aAddress = FAddress)
             and (Length(aRemotePorts) = Length(FRemotePorts));
   if Result then
      begin
      for i := 0 to High(aRemotePorts) do
         begin
         if aRemotePorts[i] <> FRemotePorts[i] then
            begin
            Result := False;
            end;
         end;
      end;
end;

function TTailcatForwarder.LocalPort(const aIndex: integer): word;
begin
   Result := 0;
   if (aIndex >= 0) and (aIndex <= High(FLocalPorts)) then
      begin
      Result := FLocalPorts[aIndex];
      end;
end;

function TTailcatForwarder.Start(const aPingTimeoutMs: integer;
                                 out aWhy: string): boolean;
var
   i:      integer;
   status: integer;
   server: TForwardServer;
   handle: TIdSocketHandle;
begin
   Result := False;
   aWhy := '';
   Stop;

   status := TailcatClientNew(FAddress, FClient, aWhy);
   if status <> TC_OK then
      begin
      aWhy := 'the Tailcat address was not accepted (' + aWhy + ')';
      Exit;
      end;

   (* THE SERVER, THROUGH THE TUNNEL, BEFORE ANY LOCAL PORT EXISTS. A wrong
     address and a server that is not running both end here and cannot be told
     apart: the address is the only thing that names the server. *)
   status := TailcatClientPing(FClient, aPingTimeoutMs, FPingMs, aWhy);
   if status <> TC_OK then
      begin
      aWhy := 'no answer through the Tailcat tunnel (' + aWhy + '): the address'
              + ' is wrong, the server is not running with Tailcat, or this'
              + ' computer cannot reach the relays';
      Stop;
      Exit;
      end;

   try
      for i := 0 to High(FRemotePorts) do
         begin
         server := TForwardServer.Create(nil);
         FServers.Add(server);
         server.FRemotePort := FRemotePorts[i];
         server.FEvents := TIndyEvents.Create;
         server.FEvents.FOwner := Self;
         server.ContextClass := TTunnelContext;
         server.OnConnect := server.FEvents.Connect;
         server.OnExecute := server.FEvents.Execute;
         server.OnDisconnect := server.FEvents.Disconnect;
         server.Bindings.Clear;
         handle := server.Bindings.Add;
         handle.IP := LOOPBACK;
         handle.Port := 0;
         server.Active := True;
         (* Port 0 asked the system to choose; the binding now holds its
           choice. *)
         FLocalPorts[i] := server.Bindings[0].Port;
         if FLocalPorts[i] = 0 then
            begin
            raise Exception.Create('the system gave no local port');
            end;
         Log(tllDebug, UnicodeFormat('local port %d stands for server port %d',
                              [FLocalPorts[i], FRemotePorts[i]]));
         end;
      Result := True;
   except
      on E: Exception do
         begin
         aWhy := 'could not open a local port for the tunnel (' + E.Message + ')';
         Stop;
         end;
   end;
end;

procedure TTailcatForwarder.Stop;
var
   i: integer;
   server: TForwardServer;
begin
   (* THE CLIENT FIRST. Closing it closes every stream it dialled and
     interrupts a dial in flight, so no connection thread is left blocked in
     the library when the listeners below wait for their threads. *)
   if FClient <> TAILCAT_NO_HANDLE then
      begin
      TailcatClose(FClient);
      FClient := TAILCAT_NO_HANDLE;
      end;

   if FServers <> nil then
      begin
      for i := FServers.Count - 1 downto 0 do
         begin
         server := TForwardServer(FServers[i]);
         try
            server.Active := False;
         except
            on E: Exception do
               begin
               Log(tllDebug, 'closing a local port: ' + E.Message);
               end;
         end;
         server.Free;
         end;
      FServers.Clear;
      end;

   for i := 0 to High(FLocalPorts) do
      begin
      FLocalPorts[i] := 0;
      end;
end;

procedure TTailcatForwarder.LocalConnect(AContext: TObject);
var
   c:      TTunnelContext;
   port:   word;
   status: integer;
   why:    string;
begin
   c := TTunnelContext(AContext);
   port := TForwardServer(c.Server).FRemotePort;

   status := TailcatDial(FClient, port, DIAL_TIMEOUT_MS, c.FConn, why);
   if status <> TC_OK then
      begin
      (* The tunnel is up (Start pinged the server) and this port did not
        answer: nothing is listening on it at the server. *)
      Log(tllWarn, UnicodeFormat('the server did not accept a connection to port %d'
                          + ' through the tunnel (%s)', [port, why]));
      c.FTunnelEnded := True;
      Exit;
      end;

   c.FReader := TTunnelReader.Create(c);
   Log(tllDebug, UnicodeFormat('a connection to server port %d is open', [port]));
end;

procedure TTailcatForwarder.LocalExecute(AContext: TObject);
var
   c:     TTunnelContext;
   bytes: TIdBytes;
   got:   integer;
begin
   c := TTunnelContext(AContext);

   (* The tunnel side has ended (or never began): everything it sent has been
     written to the local socket already, so closing here loses nothing. *)
   if c.FTunnelEnded then
      begin
      c.Connection.Disconnect;
      Exit;
      end;

   (* Indy raises when the local side has closed, and that ends the
     connection's thread through LocalDisconnect; it is the ordinary way out. *)
   if c.Connection.IOHandler.InputBuffer.Size = 0 then
      begin
      c.Connection.IOHandler.CheckForDataOnSource(250);
      c.Connection.IOHandler.CheckForDisconnect(True, True);
      end;
   got := c.Connection.IOHandler.InputBuffer.Size;
   if got <= 0 then
      begin
      Exit;
      end;
   if got > PUMP_BYTES then
      begin
      got := PUMP_BYTES;
      end;

   SetLength(bytes, 0);
   c.Connection.IOHandler.ReadBytes(bytes, got, False);
   if Length(bytes) > 0 then
      begin
      if TailcatWriteAll(c.FConn, @bytes[0], Length(bytes)) <> TC_OK then
         begin
         c.FTunnelEnded := True;
         end;
      end;
end;

procedure TTailcatForwarder.LocalDisconnect(AContext: TObject);
var
   c: TTunnelContext;
begin
   c := TTunnelContext(AContext);
   (* The local side is gone, so nobody is left to read what the server still
     sends: say goodbye and let go of the stream. *)
   if c.FConn <> TAILCAT_NO_HANDLE then
      begin
      TailcatCloseWrite(c.FConn);
      end;
   c.ReleaseTunnel;
end;

end.
