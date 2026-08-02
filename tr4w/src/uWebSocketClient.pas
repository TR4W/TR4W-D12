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

  WHAT IS DELIBERATELY NOT IMPLEMENTED:
    - extensions.  No permessage-deflate is negotiated; omitting it is the
      client's prerogative and every TCI server works without it.
    - outbound fragmentation.  TCI commands are short; one frame each.
    - server-side masking.  Server frames arrive unmasked per the RFC; a masked
      server frame is a protocol violation and is treated as a fatal error.

  THREADING.  One reader thread owns all inbound bytes and raises OnTextMessage
  from that thread -- the same shape as the factory's own TReadingThread, so a
  driver's ProcessMsg sees exactly the threading it already expects.  Send is
  serialised with a lock because pings/pongs originate on the reader thread
  while commands originate on the caller's.
}

interface

uses
   Windows, SysUtils, Classes, SyncObjs,
   IdTCPClient, IdGlobal, IdHashSHA, IdCoderMIME;

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
      // Reassembly buffer for CONTINUATION frames.
      FFragment:   TBytes;
      FFragmentIsText: boolean;

      FOnText:         TWSTextEvent;
      FOnConnected:    TWSNotifyEvent;
      FOnDisconnected: TWSNotifyEvent;

      function  DoHandshake: boolean;
      function  BuildAcceptKey(const ClientKey: string): string;
      procedure SendFrame(Opcode: Byte; const Payload: TBytes);
      function  ReadExactly(Count: integer; var Buf: TBytes): boolean;
      procedure HandleFrame(FIN: boolean; Opcode: Byte; const Payload: TBytes);
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

const
   // RFC 6455 opcodes.
   WS_OP_CONTINUATION = $0;
   WS_OP_TEXT         = $1;
   WS_OP_BINARY       = $2;
   WS_OP_CLOSE        = $8;
   WS_OP_PING         = $9;
   WS_OP_PONG         = $A;

   // RFC 6455 section 1.3 -- the fixed GUID concatenated with the client key
   // before SHA-1 to produce Sec-WebSocket-Accept.
   WS_MAGIC_GUID = '258EAFA5-E914-47DA-95CA-C5AB0DC85B11';

implementation

uses
   MainUnit;   // logger

{ ---------------------------------------------------------------- helpers -- }

// UTF-8 both ways.  TCI is ASCII in practice, but the RFC says TEXT frames are
// UTF-8 and doing it properly costs nothing.
function StringToUtf8Bytes(const S: string): TBytes;
begin
   Result := TEncoding.UTF8.GetBytes(S);
end;

function Utf8BytesToString(const B: TBytes): string;
begin
   if Length(B) = 0 then
      begin
      Result := '';
      Exit;
      end;
   Result := TEncoding.UTF8.GetString(B);
end;

{ ------------------------------------------------------- TWSReaderThread --- }

constructor TWSReaderThread.Create(AOwner: TWebSocketClient);
begin
   FOwner := AOwner;
   FreeOnTerminate := False;
   inherited Create(False);
end;

procedure TWSReaderThread.Execute;
var
   hdr:      TBytes;
   ext:      TBytes;
   mask:     TBytes;
   payload:  TBytes;
   fin:      boolean;
   opcode:   Byte;
   masked:   boolean;
   len:      Int64;
   i:        integer;
begin
   while (not Terminated) and FOwner.FConnected do
      begin
      try
         // Two-byte fixed header.
         if not FOwner.ReadExactly(2, hdr) then
            begin
            Break;
            end;
         fin    := (hdr[0] and $80) <> 0;
         opcode := hdr[0] and $0F;
         masked := (hdr[1] and $80) <> 0;
         len    := hdr[1] and $7F;

         if len = 126 then
            begin
            if not FOwner.ReadExactly(2, ext) then Break;
            len := (Int64(ext[0]) shl 8) or ext[1];
            end
         else if len = 127 then
            begin
            if not FOwner.ReadExactly(8, ext) then Break;
            len := 0;
            for i := 0 to 7 do
               begin
               len := (len shl 8) or ext[i];
               end;
            end;

         // A server MUST NOT mask.  If it does, the stream is not trustworthy.
         if masked then
            begin
            if not FOwner.ReadExactly(4, mask) then Break;
            logger.Error('[WebSocket] server sent a MASKED frame (protocol violation) - dropping link');
            Break;
            end;

         SetLength(payload, 0);
         if len > 0 then
            begin
            if not FOwner.ReadExactly(integer(len), payload) then Break;
            end;

         FOwner.HandleFrame(fin, opcode, payload);
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
   FConnected := False;
   SetLength(FFragment, 0);
   FFragmentIsText := False;
end;

destructor TWebSocketClient.Destroy;
begin
   Disconnect;
   FreeAndNil(FSendLock);
   FreeAndNil(FTCP);
   inherited Destroy;
end;

function TWebSocketClient.BuildAcceptKey(const ClientKey: string): string;
var
   sha: TIdHashSHA1;
   raw: TIdBytes;
begin
   sha := TIdHashSHA1.Create;
   try
      raw := sha.HashString(ClientKey + WS_MAGIC_GUID);
      Result := TIdEncoderMIME.EncodeBytes(raw);
   finally
      sha.Free;
   end;
end;

function TWebSocketClient.DoHandshake: boolean;
var
   keyBytes:   TIdBytes;
   clientKey:  string;
   expect:     string;
   req:        string;
   line:       string;
   statusLine: string;
   gotAccept:  string;
   i:          integer;
   p:          integer;
begin
   Result := False;

   // 16 random bytes, Base64.  Math.Random is fine here: the key exists to
   // prove the server actually did the handshake, not for security.
   SetLength(keyBytes, 16);
   for i := 0 to 15 do
      begin
      keyBytes[i] := Byte(Random(256));
      end;
   clientKey := TIdEncoderMIME.EncodeBytes(keyBytes);
   expect := BuildAcceptKey(clientKey);

   req := 'GET ' + FResource + ' HTTP/1.1'#13#10
        + 'Host: ' + FHost + ':' + IntToStr(FPort) + #13#10
        + 'Upgrade: websocket'#13#10
        + 'Connection: Upgrade'#13#10
        + 'Sec-WebSocket-Key: ' + clientKey + #13#10
        + 'Sec-WebSocket-Version: 13'#13#10
        + #13#10;
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
   SetLength(FFragment, 0);
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
   n, i, hdrLen: integer;
   mask: array[0..3] of Byte;
   idb: TIdBytes;
begin
   n := Length(Payload);

   // Header: 2 bytes + extended length + 4 mask bytes.  Client frames are
   // ALWAYS masked -- a server must close the connection on an unmasked one.
   if n <= 125 then
      begin
      hdrLen := 2;
      end
   else if n <= 65535 then
      begin
      hdrLen := 4;
      end
   else
      begin
      hdrLen := 10;
      end;

   SetLength(frame, hdrLen + 4 + n);
   frame[0] := $80 or (Opcode and $0F);        // FIN + opcode

   if n <= 125 then
      begin
      frame[1] := $80 or Byte(n);
      end
   else if n <= 65535 then
      begin
      frame[1] := $80 or 126;
      frame[2] := Byte((n shr 8) and $FF);
      frame[3] := Byte(n and $FF);
      end
   else
      begin
      frame[1] := $80 or 127;
      for i := 0 to 7 do
         begin
         frame[2 + i] := Byte((Int64(n) shr ((7 - i) * 8)) and $FF);
         end;
      end;

   for i := 0 to 3 do
      begin
      mask[i] := Byte(Random(256));
      frame[hdrLen + i] := mask[i];
      end;

   for i := 0 to n - 1 do
      begin
      frame[hdrLen + 4 + i] := Payload[i] xor mask[i mod 4];
      end;

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
      SendFrame(WS_OP_TEXT, StringToUtf8Bytes(Text));
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

procedure TWebSocketClient.HandleFrame(FIN: boolean; Opcode: Byte; const Payload: TBytes);
var
   old: integer;
begin
   case Opcode of
      WS_OP_CONTINUATION:
         begin
         old := Length(FFragment);
         SetLength(FFragment, old + Length(Payload));
         if Length(Payload) > 0 then
            begin
            Move(Payload[0], FFragment[old], Length(Payload));
            end;
         if FIN then
            begin
            if FFragmentIsText and Assigned(FOnText) then
               begin
               FOnText(Utf8BytesToString(FFragment));
               end;
            SetLength(FFragment, 0);
            FFragmentIsText := False;
            end;
         end;

      WS_OP_TEXT:
         begin
         if FIN then
            begin
            if Assigned(FOnText) then
               begin
               FOnText(Utf8BytesToString(Payload));
               end;
            end
         else
            begin
            // First fragment of a split message.
            SetLength(FFragment, Length(Payload));
            if Length(Payload) > 0 then
               begin
               Move(Payload[0], FFragment[0], Length(Payload));
               end;
            FFragmentIsText := True;
            end;
         end;

      WS_OP_BINARY:
         begin
         // TCI audio streams arrive as binary.  We never subscribe, so anything
         // here is unsolicited -- discard rather than mis-parse it as a command.
         if not FIN then
            begin
            SetLength(FFragment, 0);
            FFragmentIsText := False;
            end;
         end;

      WS_OP_PING:
         begin
         // RFC 6455: a PONG must echo the PING's payload exactly.
         SendFrame(WS_OP_PONG, Payload);
         end;

      WS_OP_PONG:
         begin
         // Liveness only -- the caller sees it as "a frame arrived".
         end;

      WS_OP_CLOSE:
         begin
         try
            SendFrame(WS_OP_CLOSE, Payload);
         except
            // The peer is closing; a failed echo is not interesting.
         end;
         FConnected := False;
         end;
   end;
end;

initialization
   Randomize;   // masking keys and the handshake nonce

end.
