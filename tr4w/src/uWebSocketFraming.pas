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
unit uWebSocketFraming;

{
  RFC 6455 FRAMING AND HANDSHAKE -- PURE, ROLE-AWARE, NO SOCKETS.

  WHY THIS UNIT EXISTS.  uWebSocketClient carried the framing inline, and it
  was written client-only in three places that a server needs mirrored:
  outbound frames were unconditionally masked, inbound masked frames were a
  fatal error with no unmask path, and the handshake existed only as the
  client half.  Rather than write a second, subtly different copy for the TCI
  server, the framing moved here and became role-aware.

  RFC 6455 IS ASYMMETRIC, AND THAT ASYMMETRY IS THE WHOLE POINT OF TWSRole:
    - a client MUST mask every frame it sends, and MUST reject a masked frame
      it receives;
    - a server MUST NOT mask anything it sends, and MUST reject an UNMASKED
      frame it receives (the masking exists to defeat cache poisoning by a
      scripted browser client, so a server that accepts unmasked frames
      defeats it).
  Both halves are enforced here so neither transport can forget one.

  NO SOCKET LIVES IN THIS UNIT.  Reading is expressed as a caller-supplied
  "read exactly N bytes, blocking" callback, which is what both transports
  already have (Indy's IOHandler.ReadBytes on a client socket and on a server
  context alike).  That keeps the unit testable with a memory stream and no
  network at all -- the framing had NO tests before this extraction.
}

interface

uses
   SysUtils, Classes;

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

   // Defensive ceilings.  A 64-bit length field arrives straight off the wire,
   // so an unbounded SetLength is a remote out-of-memory.  These are defaults;
   // each transport passes its own.
   WS_DEFAULT_MAX_PAYLOAD = 16 * 1024 * 1024;
   WS_DEFAULT_MAX_MESSAGE = 16 * 1024 * 1024;

type
   // Which end of the connection WE are.
   TWSRole = (wsrClient, wsrServer);

   TWSFrame = record
      FIN:     boolean;
      Opcode:  Byte;
      Payload: TBytes;
   end;

   TWSReadResult = (wsReadOK,             // Frame is valid
                    wsReadClosed,         // peer went away mid-frame
                    wsReadProtocolError); // ErrText says what

   TWSAcceptResult = (wsAcceptNone,       // nothing complete yet, or ignored
                      wsAcceptText,       // Text is a complete TEXT message
                      wsAcceptError);     // ErrText says what

   // Blocking "read exactly Count bytes into Buf".  False means the peer
   // closed or the read failed; the framing treats both as end-of-stream.
   TWSReadExactly = function(Count: integer; var Buf: TBytes): boolean of object;

   { Reassembles CONTINUATION chains into whole messages.  One instance per
     connection; it is NOT thread safe and is owned by that connection's
     reader thread.

     BINARY is deliberately dropped rather than reassembled: neither the TCI
     client (which never subscribes to audio) nor the TCI server (control
     only, by decision) has any use for it, and mis-parsing an audio frame as
     a command is worse than ignoring it. }
   TWSReassembler = class(TObject)
   private
      FFragment:       TBytes;
      FFragmentIsText: boolean;
   public
      constructor Create;
      procedure Reset;

      // Feeds one data frame.  Control frames (PING/PONG/CLOSE) must NOT be
      // passed here -- they are handled by the transport, which owns the
      // socket needed to answer them.
      function Accept(const Frame: TWSFrame; MaxMessage: Int64;
                      out Text: string; out ErrText: string): TWSAcceptResult;
   end;

{ -------------------------------------------------------------- encoding -- }

// Builds one complete, unfragmented frame.  Masks it when Role is wsrClient.
function WSEncodeFrame(Role: TWSRole; Opcode: Byte; const Payload: TBytes): TBytes;

{ -------------------------------------------------------------- decoding -- }

// Reads one whole frame using Reader.  Role is OUR role, and decides which
// masking state is legal on the way in; a server unmasks the payload here so
// no caller ever sees a masked buffer.
function WSReadFrame(const Reader: TWSReadExactly; Role: TWSRole;
                     MaxPayload: Int64; out Frame: TWSFrame;
                     out ErrText: string): TWSReadResult;

{ ------------------------------------------------------------- handshake -- }

// 16 random bytes, Base64.  The nonce proves the peer really did the
// handshake; it is not a security value, so Random is fine.
function WSMakeClientKey: string;

// Base64(SHA1(Key + WS_MAGIC_GUID)).  Direction-symmetric: the client builds
// it to compare, the server builds it to send.
function WSBuildAcceptKey(const ClientKey: string): string;

// The client's GET.  Resource must already be non-empty ('/' if unspecified).
function WSBuildHandshakeRequest(const Host: string; Port: integer;
                                 const Resource, ClientKey: string): string;

// Validates a client's request headers and extracts Sec-WebSocket-Key.
// Lines are the request lines with the CRLFs stripped, request line first,
// terminating blank line optional.  Deliberately does NOT check the URL path
// or negotiate a subprotocol -- real TCI clients rely on both being ignored.
function WSParseHandshakeRequest(const Lines: TStrings; out ClientKey: string;
                                 out ErrText: string): boolean;

// The server's 101.
function WSBuildHandshakeResponse(const ClientKey: string): string;

{ ---------------------------------------------------------------- text ----- }

function WSStringToUtf8Bytes(const S: string): TBytes;
function WSUtf8BytesToString(const B: TBytes): string;

implementation

uses
   IdGlobal, IdHashSHA, IdCoderMIME;

{ ---------------------------------------------------------------- text ----- }

// UTF-8 both ways.  TCI is ASCII in practice, but the RFC says TEXT frames
// are UTF-8 and doing it properly costs nothing.
function WSStringToUtf8Bytes(const S: string): TBytes;
begin
   Result := TEncoding.UTF8.GetBytes(S);
end;

function WSUtf8BytesToString(const B: TBytes): string;
begin
   if Length(B) = 0 then
      begin
      Result := '';
      Exit;
      end;
   Result := TEncoding.UTF8.GetString(B);
end;

{ -------------------------------------------------------------- encoding -- }

function WSEncodeFrame(Role: TWSRole; Opcode: Byte; const Payload: TBytes): TBytes;
var
   n, i, hdrLen: integer;
   maskFlag:     Byte;
   mask:         array[0..3] of Byte;
   maskLen:      integer;
begin
   n := Length(Payload);

   if Role = wsrClient then
      begin
      maskFlag := $80;
      maskLen  := 4;
      end
   else
      begin
      maskFlag := $00;
      maskLen  := 0;
      end;

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

   SetLength(Result, hdrLen + maskLen + n);
   Result[0] := $80 or (Opcode and $0F);        // FIN + opcode

   if n <= 125 then
      begin
      Result[1] := maskFlag or Byte(n);
      end
   else if n <= 65535 then
      begin
      Result[1] := maskFlag or 126;
      Result[2] := Byte((n shr 8) and $FF);
      Result[3] := Byte(n and $FF);
      end
   else
      begin
      Result[1] := maskFlag or 127;
      for i := 0 to 7 do
         begin
         Result[2 + i] := Byte((Int64(n) shr ((7 - i) * 8)) and $FF);
         end;
      end;

   if Role = wsrClient then
      begin
      for i := 0 to 3 do
         begin
         mask[i] := Byte(Random(256));
         Result[hdrLen + i] := mask[i];
         end;
      for i := 0 to n - 1 do
         begin
         Result[hdrLen + 4 + i] := Payload[i] xor mask[i mod 4];
         end;
      end
   else
      begin
      for i := 0 to n - 1 do
         begin
         Result[hdrLen + i] := Payload[i];
         end;
      end;
end;

{ -------------------------------------------------------------- decoding -- }

function WSReadFrame(const Reader: TWSReadExactly; Role: TWSRole;
                     MaxPayload: Int64; out Frame: TWSFrame;
                     out ErrText: string): TWSReadResult;
var
   hdr:    TBytes;
   ext:    TBytes;
   mask:   TBytes;
   masked: boolean;
   len:    Int64;
   i:      integer;
begin
   ErrText := '';
   Frame.FIN := False;
   Frame.Opcode := 0;
   SetLength(Frame.Payload, 0);

   if not Reader(2, hdr) then
      begin
      Result := wsReadClosed;
      Exit;
      end;

   Frame.FIN    := (hdr[0] and $80) <> 0;
   Frame.Opcode := hdr[0] and $0F;
   masked       := (hdr[1] and $80) <> 0;
   len          := hdr[1] and $7F;

   if len = 126 then
      begin
      if not Reader(2, ext) then
         begin
         Result := wsReadClosed;
         Exit;
         end;
      len := (Int64(ext[0]) shl 8) or ext[1];
      end
   else if len = 127 then
      begin
      if not Reader(8, ext) then
         begin
         Result := wsReadClosed;
         Exit;
         end;
      len := 0;
      for i := 0 to 7 do
         begin
         len := (len shl 8) or ext[i];
         end;
      end;

   // The length is attacker-controlled and 64 bits wide.  Refuse before
   // allocating, and refuse a negative one outright -- the pre-extraction
   // code cast it to a 32-bit integer, where a huge length silently became a
   // negative Count and read nothing at all.
   if (len < 0) or ((MaxPayload > 0) and (len > MaxPayload)) then
      begin
      ErrText := Format('frame payload of %d bytes exceeds the %d byte limit', [len, MaxPayload]);
      Result := wsReadProtocolError;
      Exit;
      end;

   // Masking is not a preference: each role has exactly one legal answer.
   if masked <> (Role = wsrServer) then
      begin
      if Role = wsrServer then
         begin
         ErrText := 'client sent an UNMASKED frame (protocol violation)';
         end
      else
         begin
         ErrText := 'server sent a MASKED frame (protocol violation)';
         end;
      Result := wsReadProtocolError;
      Exit;
      end;

   if masked then
      begin
      if not Reader(4, mask) then
         begin
         Result := wsReadClosed;
         Exit;
         end;
      end;

   if len > 0 then
      begin
      if not Reader(integer(len), Frame.Payload) then
         begin
         Result := wsReadClosed;
         Exit;
         end;
      if masked then
         begin
         for i := 0 to Length(Frame.Payload) - 1 do
            begin
            Frame.Payload[i] := Frame.Payload[i] xor mask[i mod 4];
            end;
         end;
      end;

   Result := wsReadOK;
end;

{ -------------------------------------------------------- TWSReassembler -- }

constructor TWSReassembler.Create;
begin
   inherited Create;
   Reset;
end;

procedure TWSReassembler.Reset;
begin
   SetLength(FFragment, 0);
   FFragmentIsText := False;
end;

function TWSReassembler.Accept(const Frame: TWSFrame; MaxMessage: Int64;
                               out Text: string; out ErrText: string): TWSAcceptResult;
var
   old: integer;
begin
   Text := '';
   ErrText := '';
   Result := wsAcceptNone;

   case Frame.Opcode of
      WS_OP_CONTINUATION:
         begin
         if (not FFragmentIsText) and (Length(FFragment) = 0) then
            begin
            // A CONTINUATION with nothing started is either a stray frame or
            // the tail of a BINARY message we dropped.  Ignore it rather than
            // treating it as the start of a text message.
            Exit;
            end;
         old := Length(FFragment);
         if (MaxMessage > 0) and (old + Int64(Length(Frame.Payload)) > MaxMessage) then
            begin
            ErrText := Format('reassembled message exceeds the %d byte limit', [MaxMessage]);
            Reset;
            Result := wsAcceptError;
            Exit;
            end;
         SetLength(FFragment, old + Length(Frame.Payload));
         if Length(Frame.Payload) > 0 then
            begin
            Move(Frame.Payload[0], FFragment[old], Length(Frame.Payload));
            end;
         if Frame.FIN then
            begin
            if FFragmentIsText then
               begin
               Text := WSUtf8BytesToString(FFragment);
               Result := wsAcceptText;
               end;
            Reset;
            end;
         end;

      WS_OP_TEXT:
         begin
         if (MaxMessage > 0) and (Int64(Length(Frame.Payload)) > MaxMessage) then
            begin
            ErrText := Format('text message exceeds the %d byte limit', [MaxMessage]);
            Reset;
            Result := wsAcceptError;
            Exit;
            end;
         if Frame.FIN then
            begin
            Text := WSUtf8BytesToString(Frame.Payload);
            Result := wsAcceptText;
            end
         else
            begin
            // First fragment of a split message.
            SetLength(FFragment, Length(Frame.Payload));
            if Length(Frame.Payload) > 0 then
               begin
               Move(Frame.Payload[0], FFragment[0], Length(Frame.Payload));
               end;
            FFragmentIsText := True;
            end;
         end;

      WS_OP_BINARY:
         begin
         // Dropped, but a fragmented one must still be tracked so its
         // CONTINUATION tail is not mistaken for text.
         if not Frame.FIN then
            begin
            SetLength(FFragment, 0);
            FFragmentIsText := False;
            end;
         end;
   end;
end;

{ ------------------------------------------------------------- handshake -- }

function WSMakeClientKey: string;
var
   keyBytes: TIdBytes;
   i:        integer;
begin
   SetLength(keyBytes, 16);
   for i := 0 to 15 do
      begin
      keyBytes[i] := Byte(Random(256));
      end;
   Result := TIdEncoderMIME.EncodeBytes(keyBytes);
end;

function WSBuildAcceptKey(const ClientKey: string): string;
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

function WSBuildHandshakeRequest(const Host: string; Port: integer;
                                 const Resource, ClientKey: string): string;
begin
   Result := 'GET ' + Resource + ' HTTP/1.1'#13#10
           + 'Host: ' + Host + ':' + IntToStr(Port) + #13#10
           + 'Upgrade: websocket'#13#10
           + 'Connection: Upgrade'#13#10
           + 'Sec-WebSocket-Key: ' + ClientKey + #13#10
           + 'Sec-WebSocket-Version: 13'#13#10
           + #13#10;
end;

function WSParseHandshakeRequest(const Lines: TStrings; out ClientKey: string;
                                 out ErrText: string): boolean;
var
   i:        integer;
   line:     string;
   name:     string;
   value:    string;
   p:        integer;
   upgrade:  string;
   connect:  string;
   version:  string;
begin
   Result := False;
   ClientKey := '';
   ErrText := '';
   upgrade := '';
   connect := '';
   version := '';

   if Lines.Count = 0 then
      begin
      ErrText := 'empty request';
      Exit;
      end;

   if not SameText(Copy(Trim(Lines[0]), 1, 4), 'GET ') then
      begin
      ErrText := 'not a GET: ' + Lines[0];
      Exit;
      end;

   for i := 1 to Lines.Count - 1 do
      begin
      line := Lines[i];
      if Trim(line) = '' then
         begin
         Break;
         end;
      p := Pos(':', line);
      if p = 0 then
         begin
         Continue;
         end;
      name  := Trim(Copy(line, 1, p - 1));
      value := Trim(Copy(line, p + 1, Length(line)));
      if SameText(name, 'Sec-WebSocket-Key') then
         begin
         ClientKey := value;
         end
      else if SameText(name, 'Upgrade') then
         begin
         upgrade := value;
         end
      else if SameText(name, 'Connection') then
         begin
         connect := value;
         end
      else if SameText(name, 'Sec-WebSocket-Version') then
         begin
         version := value;
         end;
      end;

   if not SameText(Trim(upgrade), 'websocket') then
      begin
      ErrText := 'missing or wrong Upgrade header ("' + upgrade + '")';
      Exit;
      end;

   // Connection is a comma-separated token list; browsers send
   // "keep-alive, Upgrade", so match the token, not the whole value.
   if Pos('upgrade', LowerCase(connect)) = 0 then
      begin
      ErrText := 'missing Upgrade token in Connection header ("' + connect + '")';
      Exit;
      end;

   if ClientKey = '' then
      begin
      ErrText := 'missing Sec-WebSocket-Key';
      Exit;
      end;

   // Version 13 is the only version RFC 6455 defines.  Accept a blank one --
   // some minimal clients omit it -- but refuse a version we cannot speak.
   if (version <> '') and (Trim(version) <> '13') then
      begin
      ErrText := 'unsupported Sec-WebSocket-Version "' + version + '"';
      Exit;
      end;

   Result := True;
end;

function WSBuildHandshakeResponse(const ClientKey: string): string;
begin
   Result := 'HTTP/1.1 101 Switching Protocols'#13#10
           + 'Upgrade: websocket'#13#10
           + 'Connection: Upgrade'#13#10
           + 'Sec-WebSocket-Accept: ' + WSBuildAcceptKey(ClientKey) + #13#10
           + #13#10;
end;

initialization
   Randomize;   // masking keys and the handshake nonce

end.
