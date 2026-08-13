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
unit uWebSocketClient;
{$I tr4w.inc}

{
  A MINIMAL RFC 6455 WEBSOCKET CLIENT -- TRANSPORT ONLY, NO RADIO KNOWLEDGE.

  WHY THIS UNIT EXISTS.  Nothing in TR4W spoke WebSocket, and the TCI protocol
  (ExpertSDR / Thetis / AetherSDR) is WebSocket-framed.  Rather than pull in a
  commercial library for one radio type, this implements the small client
  subset TCI actually needs, over the Indy TCP client the factory already uses.

  It lives in src/, NOT src/radioFactory/, deliberately: it is a transport, and
  transports in this project live in their own layer so a second consumer (a
  TCI keyer or peripheral, say) does not have to reach into a radio driver.

  WHAT IS IMPLEMENTED (the client subset, and nothing more):
    - HTTP/1.1 Upgrade handshake with Sec-WebSocket-Key/Accept validation
    - outbound TEXT frames, always masked (RFC 6455 requires client masking)
    - inbound TEXT (1), PING (9) -> auto-PONG, CLOSE (8) -> echo + drop,
      CONTINUATION (0) -> reassembled, BINARY (2) -> discarded
    - all three payload-length forms (7-bit, 16-bit, 64-bit)

  WHERE THE FRAMING LIVES.  Frame encode/decode, reassembly and the handshake
  digest are in uWebSocketFraming, shared with the TCI server.  This unit is
  now the CLIENT TRANSPORT only: an Indy socket, a reader thread, and the
  client half of the handshake.  It passes wsrClient into the framing, which
  is what makes its frames masked and a masked inbound frame fatal.

  WHAT IS DELIBERATELY NOT IMPLEMENTED:
    - extensions.  No permessage-deflate is negotiated; omitting it is the
      client's prerogative and every TCI server works without it.
    - outbound fragmentation.  TCI commands are short; one frame each.

  THREADING.  One reader thread owns all inbound bytes and raises OnTextMessage
  from that thread -- the same shape as the factory's own TReadingThread, so a
  driver's ProcessMsg sees exactly the threading it already expects.  Send is
  serialised with a lock because pings/pongs originate on the reader thread
  while commands originate on the caller's.
}

interface

uses
   Windows, SysUtils, Classes, SyncObjs,
   IdTCPClient, IdGlobal,
   uWebSocketFraming;

type
   TWSTextEvent   = procedure(const Text: string) of object;
   TWSNotifyEvent = procedure of object;

   TWebSocketClient = class;

   TWSReaderThread = class(TThread)
   private
      FOwner: TWebSocketClient;
   protected
      procedure Execute; override;
   public
      constructor Create(AOwner: TWebSocketClient);
   end;

   TWebSocketClient = class(TObject)
   private
      FTCP:        TIdTCPClient;
      FReader:     TWSReaderThread;
      FSendLock:   TCriticalSection;
      FConnected:  boolean;
      FHost:       string;
      FPort:       integer;
      FResource:   string;
      FLastError:  string;
      // Reassembly of CONTINUATION chains; owned by the reader thread.
      FReassembler: TWSReassembler;

      FOnText:         TWSTextEvent;
      FOnConnected:    TWSNotifyEvent;
      FOnDisconnected: TWSNotifyEvent;

      function  DoHandshake: boolean;
      procedure SendFrame(Opcode: Byte; const Payload: TBytes);
      function  ReadExactly(Count: integer; var Buf: TBytes): boolean;
      procedure HandleFrame(const Frame: TWSFrame);
      procedure DropLink;
   public
      constructor Create;
      destructor  Destroy; override;

      // Connects the TCP socket and performs the Upgrade handshake.  Returns
      // True only when the server answered 101 with a valid Sec-WebSocket-Accept.
      function  Connect(const AHost: string; APort: integer;
                        const AResource: string = '/'): boolean;
      procedure Disconnect;

      // Sends one masked TEXT frame.  Safe to call from any thread.
      procedure SendText(const Text: string);
      // Sends a PING; used as a liveness probe when the link has gone quiet.
      procedure Ping;

      property Connected:  boolean read FConnected;
      property LastError:  string  read FLastError;

      property OnTextMessage:  TWSTextEvent   read FOnText         write FOnText;
      property OnConnected:    TWSNotifyEvent read FOnConnected    write FOnConnected;
      property OnDisconnected: TWSNotifyEvent read FOnDisconnected write FOnDisconnected;
   end;

implementation

uses
   MainUnit;   // logger

{ ------------------------------------------------------- TWSReaderThread --- }

constructor TWSReaderThread.Create(AOwner: TWebSocketClient);
begin
   FOwner := AOwner;
   FreeOnTerminate := False;
   inherited Create(False);
end;

procedure TWSReaderThread.Execute;
var
   frame:   TWSFrame;
   errText: string;
   res:     TWSReadResult;
begin
   while (not Terminated) and FOwner.FConnected do
      begin
      try
         res := WSReadFrame(FOwner.ReadExactly, wsrClient,
                            WS_DEFAULT_MAX_PAYLOAD, frame, errText);
         if res = wsReadProtocolError then
            begin
            // A server that masks, or claims an absurd length, is not a
            // stream we can keep trusting.
            logger.Error('[WebSocket] %s - dropping link', [errText]);
            Break;
            end;
         if res <> wsReadOK then
            begin
            Break;
            end;

         FOwner.HandleFrame(frame);
      except
         on E: Exception do
            begin
            // A read error here is the normal shape of "the other end went
            // away"; log at debug so a routine disconnect is not alarming.
            logger.Debug('[WebSocket] reader stopping: %s - %s', [E.ClassName, E.Message]);
            Break;
            end;
      end;
      end;

   FOwner.DropLink;
end;

{ ------------------------------------------------------- TWebSocketClient -- }

constructor TWebSocketClient.Create;
begin
   inherited Create;
   FTCP := TIdTCPClient.Create(nil);
   FSendLock := TCriticalSection.Create;
   FReassembler := TWSReassembler.Create;
   FConnected := False;
end;

destructor TWebSocketClient.Destroy;
begin
   Disconnect;
   FreeAndNil(FReassembler);
   FreeAndNil(FSendLock);
   FreeAndNil(FTCP);
   inherited Destroy;
end;

function TWebSocketClient.DoHandshake: boolean;
var
   clientKey:  string;
   expect:     string;
   req:        string;
   line:       string;
   statusLine: string;
   gotAccept:  string;
   p:          integer;
begin
   Result := False;

   clientKey := WSMakeClientKey;
   expect := WSBuildAcceptKey(clientKey);

   req := WSBuildHandshakeRequest(FHost, FPort, FResource, clientKey);
   FTCP.IOHandler.Write(req);

   statusLine := FTCP.IOHandler.ReadLn;
   if Pos('101', statusLine) = 0 then
      begin
      FLastError := 'handshake refused: ' + statusLine;
      logger.Error('[WebSocket] %s', [FLastError]);
      Exit;
      end;

   gotAccept := '';
   repeat
      line := FTCP.IOHandler.ReadLn;
      p := Pos(':', line);
      if (p > 0) and SameText(Trim(Copy(line, 1, p - 1)), 'Sec-WebSocket-Accept') then
         begin
         gotAccept := Trim(Copy(line, p + 1, Length(line)));
         end;
   until line = '';

   if not SameText(gotAccept, expect) then
      begin
      // Not pedantry: a proxy or a plain HTTP server can answer 101 and still
      // not be a WebSocket peer.  Verifying the digest is what makes the
      // handshake meaningful.
      FLastError := 'Sec-WebSocket-Accept mismatch (got "' + gotAccept + '")';
      logger.Error('[WebSocket] %s', [FLastError]);
      Exit;
      end;

   Result := True;
end;

function TWebSocketClient.Connect(const AHost: string; APort: integer;
                                  const AResource: string): boolean;
begin
   Result := False;
   FLastError := '';
   FHost := AHost;
   FPort := APort;
   if AResource = '' then
      begin
      FResource := '/';
      end
   else
      begin
      FResource := AResource;
      end;

   try
      FTCP.Host := FHost;
      FTCP.Port := FPort;
      FTCP.ConnectTimeout := 5000;
      FTCP.ReadTimeout := -1;          // reader thread blocks; liveness is by ping
      FTCP.Connect;
   except
      on E: Exception do
         begin
         FLastError := E.Message;
         logger.Error('[WebSocket] TCP connect to %s:%d failed: %s', [FHost, FPort, E.Message]);
         Exit;
         end;
   end;

   try
      if not DoHandshake then
         begin
         FTCP.Disconnect;
         Exit;
         end;
   except
      on E: Exception do
         begin
         FLastError := E.Message;
         logger.Error('[WebSocket] handshake failed: %s', [E.Message]);
         try FTCP.Disconnect; except end;
         Exit;
         end;
   end;

   FConnected := True;
   FReassembler.Reset;
   logger.Info('[WebSocket] connected to %s:%d%s', [FHost, FPort, FResource]);
   FReader := TWSReaderThread.Create(Self);
   if Assigned(FOnConnected) then
      begin
      FOnConnected;
      end;
   Result := True;
end;

procedure TWebSocketClient.DropLink;
var
   wasConnected: boolean;
begin
   wasConnected := FConnected;
   FConnected := False;
   if wasConnected and Assigned(FOnDisconnected) then
      begin
      FOnDisconnected;
      end;
end;

procedure TWebSocketClient.Disconnect;
begin
   if FConnected then
      begin
      try
         SendFrame(WS_OP_CLOSE, nil);
      except
         // Best effort: the peer may already be gone.
      end;
      end;
   FConnected := False;

   if Assigned(FReader) then
      begin
      FReader.Terminate;
      try FTCP.Disconnect; except end;
      FReader.WaitFor;
      FreeAndNil(FReader);
      end
   else
      begin
      try FTCP.Disconnect; except end;
      end;
end;

function TWebSocketClient.ReadExactly(Count: integer; var Buf: TBytes): boolean;
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
      FTCP.IOHandler.ReadBytes(idb, Count, False);
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

procedure TWebSocketClient.SendFrame(Opcode: Byte; const Payload: TBytes);
var
   frame: TBytes;
   idb:   TIdBytes;
begin
   // wsrClient: RFC 6455 requires a client to mask every frame it sends.
   frame := WSEncodeFrame(wsrClient, Opcode, Payload);

   FSendLock.Enter;
   try
      SetLength(idb, Length(frame));
      if Length(frame) > 0 then
         begin
         Move(frame[0], idb[0], Length(frame));
         end;
      FTCP.IOHandler.Write(idb);
   finally
      FSendLock.Leave;
   end;
end;

procedure TWebSocketClient.SendText(const Text: string);
begin
   if not FConnected then
      begin
      Exit;
      end;
   try
      SendFrame(WS_OP_TEXT, WSStringToUtf8Bytes(Text));
   except
      on E: Exception do
         begin
         logger.Error('[WebSocket] send failed: %s', [E.Message]);
         DropLink;
      end;
   end;
end;

procedure TWebSocketClient.Ping;
begin
   if not FConnected then
      begin
      Exit;
      end;
   try
      SendFrame(WS_OP_PING, nil);
   except
      on E: Exception do
         begin
         logger.Debug('[WebSocket] ping failed: %s', [E.Message]);
         DropLink;
      end;
   end;
end;

procedure TWebSocketClient.HandleFrame(const Frame: TWSFrame);
var
   text:    string;
   errText: string;
begin
   case Frame.Opcode of
      WS_OP_PING:
         begin
         // RFC 6455: a PONG must echo the PING's payload exactly.
         SendFrame(WS_OP_PONG, Frame.Payload);
         end;

      WS_OP_PONG:
         begin
         // Liveness only -- the caller sees it as "a frame arrived".
         end;

      WS_OP_CLOSE:
         begin
         try
            SendFrame(WS_OP_CLOSE, Frame.Payload);
         except
            // The peer is closing; a failed echo is not interesting.
         end;
         FConnected := False;
         end;
   else
      // Data frames: CONTINUATION / TEXT / BINARY.  The reassembler owns the
      // fragment state; BINARY (TCI audio, which we never subscribe to) is
      // dropped there rather than mis-parsed as a command.
      case FReassembler.Accept(Frame, WS_DEFAULT_MAX_MESSAGE, text, errText) of
         wsAcceptText:
            begin
            if Assigned(FOnText) then
               begin
               FOnText(text);
               end;
            end;

         wsAcceptError:
            begin
            logger.Error('[WebSocket] %s - dropping link', [errText]);
            DropLink;
            end;
      end;
   end;
end;

end.
