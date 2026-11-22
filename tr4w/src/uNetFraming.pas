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

{ WHERE ONE MULTI-OP MESSAGE ENDS AND THE NEXT BEGINS.

  THIS IS THE MULTI-OPERATOR NETWORK -- TR4WServer, carrying QSOs, radio state
  and operator state.  It is NOT the DX cluster, which is a separate connection
  to a separate peer carrying line-oriented spot text.  The two are unrelated
  and the only place they touch is one spot-forwarding call in uNet.

  PROTOCOL 5 (2026-11-22, design 13.7): THREE IDS CARRY A LENGTH.  A QSO is
  now the row's columns as JSON, so it has no fixed size: NET_WIRE_QSO_ID
  (1041), NET_WIRE_EDIT_ID (1051) and NET_WIRE_OFFLINE_ID (1057) are
  2-byte LE id, 4-byte LE payload length, payload (one sender byte, then the
  UTF-8 JSON).  A declared length over NET_WIRE_MAX_PAYLOAD is a protocol error
  reported as nwOversize from the six header bytes alone -- never as "partial",
  or the buffer would wait for bytes that may never come.  The old 1040, 1050
  and 1055 are UNKNOWN ids here.  Every other message keeps the rule below.

  EVERY OTHER MESSAGE HAS NO FRAMING.  No length prefix, no sentinel, no checksum.  A
  message is a leading Word id followed by the record that id implies, and the
  boundary is therefore IMPLICIT IN A TYPE TABLE.  Both ends compile the same
  VC.pas, so they agree by construction -- until a hand-written advance in one
  arm disagrees with the record it just cast.

  WHICH IS EXACTLY WHAT HAPPENED.  NET_SPOTVIANETWORK_ID cast the buffer to
  TSendSpotViaNetworkPtr and then advanced by SizeOf(NetQSOInfoToSend): 264
  bytes for a 48-byte message.  One network-forwarded spot desynchronised
  everything behind it, silently.  That defect is only possible while the SIZE
  lives beside each arm; here there is one table and the arms cannot disagree
  with it.

  IT DELIBERATELY KNOWS NOTHING ELSE.  No sockets, no windows, no handlers, no
  logging -- so the whole of it is reachable from a unit test, which the parse
  loop inside a dialog procedure never was. }
unit uNetFraming;

{$I tr4w.inc}

interface

uses
   SyncObjs,    (* the refusal latch is touched from more than one thread *)
   SysUtils,
   VC,
   uWireQso,
   uNetHello;   (* THelloMessage -- the size of the first message *)

const
   (* id Word, then the payload length as a LE Cardinal. *)
   NET_WIRE_HEADER_SIZE = 6;
   (* THE LARGEST PAYLOAD (sender byte + JSON) a variable message may declare.
     Measured: the widest real row is a few KB; a bigger declaration is a
     protocol error, not a QSO. *)
   NET_WIRE_MAX_PAYLOAD = 60000;
   (* EVERY RECEIVE BUFFER ON THE LINK (client and both servers): room for a
     whole maximum frame beside the incomplete tail of the previous read. *)
   NET_RECEIVE_BUFFER_SIZE = 131072;

type
   { Why a walk stopped. }
   TNetWalkResult = (
      nwComplete,     // the buffer ended exactly on a message boundary
      nwPartial,      // a known id, but not all of its bytes are here yet
      nwUnknownId,    // no table entry -- the walk cannot advance past it
      nwOversize      // a variable message declares more than NET_WIRE_MAX_PAYLOAD
   );

{ How many bytes the FIXED-size message with this id occupies, INCLUDING its
  leading id Word, or 0 if the id is not one we know -- AND 0 FOR THE THREE
  VARIABLE ids, whose size is in their own header (NetIsWireId).

  0 IS THE IMPORTANT ANSWER.  It is what tells the caller it cannot advance,
  which is the difference between reporting a desync and spinning on it. }
function NetMessageSize(const aId: word): integer;

(* The three protocol-5 QSO messages: id, 4-byte length, payload. *)
function NetIsWireId(const aId: word): boolean;

(* SMALL LITTLE-ENDIAN HELPERS -- the ONE place a header is read or written, so
  no caller pokes bytes through a pointer cast. Put* grow nothing: the caller
  sized the array. Get* read what is there (the caller checked the length). *)
procedure PutWordLE(var aBytes: TBytes; const aAt: integer; const aValue: Word);
procedure PutCardinalLE(var aBytes: TBytes; const aAt: integer; const aValue: Cardinal);
function GetWordLE(const aBytes: array of Byte; const aAt: integer): Word;
function GetCardinalLE(const aBytes: array of Byte; const aAt: integer): Cardinal;

type
   (* WHAT TAKING A WIRE ROW APART FOUND. Everything but wtOk is a REFUSED ROW:
     logged, not stored, not relayed, and the link is NOT dropped. *)
   TWireTake = (
      wtOk,
      wtNoSender,        // an empty payload: not even the sender byte
      wtBadJson,         // not one JSON object
      wtBadChecksum,     // the "k" member is missing, malformed or does not match
      wtBadNumber);      // a numeric column does not hold canonical digits

(* A COMPLETE WIRE MESSAGE for a row: header, sender byte, JSON. Applies
  WireText to every value FIRST (so the checksum is over what the receiver will
  decode), computes the record checksum, omits defaults. Raises EWireQsoError
  when a numeric value is not canonical digits or the payload would exceed
  NET_WIRE_MAX_PAYLOAD; aId must be one of the three wire ids. *)
function BuildWireMessage(const aId: word; const aSender: Byte; aColumns: TWireColumns;
                          const aValues: TWireValues): TBytes;

(* TAKES ONE PAYLOAD APART: aPayload is the bytes after the six header bytes
  (sender byte, then the UTF-8 JSON). aReason says what failed, for the log. *)
function TakeWireMessage(aColumns: TWireColumns; const aPayload: TBytes;
                         out aSender: Byte; out aValues: TWireValues;
                         out aReason: string): TWireTake;

(* THE SYNC STREAM'S FRAMES (design 13.7): 4-byte LE length + UTF-8 JSON, no id
  and no sender byte. The header frame is {"contest":..,"rows":N,"schema":5}. *)
function BuildSyncHeaderFrame(const aContest: string; const aRows: integer): TBytes;
function BuildSyncRowFrame(aColumns: TWireColumns; const aValues: TWireValues): TBytes;
(* aBody: the JSON bytes WITHOUT the 4-byte length. *)
function TakeSyncHeader(const aBody: TBytes; out aContest: string; out aRows: integer;
                        out aSchema: integer): boolean;
function TakeSyncRow(aColumns: TWireColumns; const aBody: TBytes;
                     out aValues: TWireValues; out aReason: string): TWireTake;

(* THE WHOLE OF A WIRE MESSAGE the client is about to send, judged from its own
  bytes: a wire id, a header whose declared length is exactly what follows, a
  payload of at least the sender byte and at most NET_WIRE_MAX_PAYLOAD. *)
function OutboundWireMessageIsWellFormed(const aPacket: TBytes): boolean;

(* IS THIS A PACKET A STATION MAY PUT ON THE LINK?  (2026-10-27)

  True only when aLen is at least the id Word, the id is one NetMessageSize
  knows, and aLen is exactly that message's size. Every record this client
  sends is a packed record that opens with its own id; one whose id was never
  assigned goes out as 00 00, and the server cannot frame the stream past it
  and drops the connection. That is what happened to every DX spot, time sync,
  intercom line and spot-via-network from 2026-08-25: the types were right, the
  sizes were right, and the id was zero. The check is made at the one funnel
  (uNet.SendToNet) so a record added later cannot forget. *)
function OutboundPacketIsWellFormed(const aId: word; const aLen: integer): boolean;

type
   (* WHICH REFUSED PACKETS HAVE ALREADY BEEN REPORTED.  A refused packet is
     reported once per distinct (id, length) per link, not once per packet: the
     station status goes out many times a second and one broken record would
     otherwise fill the log. Thread-safe -- SendToNet is called from the main
     thread and from the radio polling thread. *)
   TNetSendRefusals = class
   private
      FLock: TCriticalSection;
      FKeys: array of Int64;
      FCount: integer;
   public
      constructor Create;
      destructor Destroy; override;

      (* True the FIRST time this (id, length) is seen since Forget. *)
      function FirstSighting(const aId: word; const aLen: integer): boolean;

      (* A new link: report again. *)
      procedure Forget;

      (* How many distinct (id, length) pairs have been reported. *)
      function Count: integer;
   end;

(* Walks one received buffer.

  aOffset is 1-BASED, matching NetBuffer, because the caller holds positions
  that way and a translation at every call would be one more place to be off
  by one. aBuffer is an OPEN ARRAY (P12, 2026-10-18): whatever its declared
  bounds, its first byte is position 1, and it carries its own length.
  aLength is the byte count recv returned; anything past the buffer's real
  end is not read, so an over-stated length reads as a partial message
  rather than as stale memory.

  aOffset is in/out: the 1-based position to read from, advanced past the
  message that was returned.  aId receives the id found there -- two bytes,
  low byte first, which is how every V1 station writes it.

  Returns True when a COMPLETE message is available at aOffset -- and only
  then may the caller cast a record out of the buffer.  Returns False with
  aResult saying why: nwComplete (nothing left), nwPartial (a known message
  that has not all arrived) or nwUnknownId. *)
function NextNetMessage(const aBuffer: array of Byte; const aLength: integer;
                        var aOffset: integer; out aId: word;
                        out aResult: TNetWalkResult): boolean;

(* HOW MUCH OF A RECEIVED STREAM IS WHOLE MESSAGES, AND WHY THE REST STOPPED.

  Returns the byte count, from the start of aBuffer, that is made of complete
  messages only; aResult says what follows them: nwComplete (nothing), nwPartial
  (the front of a known message -- KEEP IT, the next read completes it) or
  nwUnknownId (aBadId; the stream cannot be framed past it, so the connection
  has to be resynchronised or dropped, never re-parsed).

  aAllowLogInfoRequest is for the SERVER's reading side: a client may send the
  four-byte NET_LOGINFO_MESSAGE sentinel ("send me the log-compare packet"),
  which has no Word id and no entry in NetMessageSize. Its low Word is not a
  known id (pinned by a test), so reading it as one can never be ambiguous. *)
function NetWholeBytes(const aBuffer: array of Byte; const aLength: integer;
                       const aAllowLogInfoRequest: boolean;
                       out aResult: TNetWalkResult; out aBadId: word): integer;

type
   (* ONE CONNECTION'S UNPARSED INPUT.

     TCP divides the stream anywhere. The server used to parse each read as if
     it were whole and lose the tail of whatever was cut -- measured 2026-10-27,
     30 QSOs written in one send, 11 relayed and logged. This keeps the bytes
     received and hands back only whole messages; the incomplete tail waits for
     the next read. It knows nothing of sockets, so a test drives it with any
     split of any stream. *)
   TNetStreamBuffer = class
   private
      FData:  array of Byte;
      FCount: integer;
   public
      procedure Append(const aBytes: array of Byte);

      (* The whole-message prefix, as NetWholeBytes reports it. *)
      function WholeBytes(const aAllowLogInfoRequest: boolean;
                          out aResult: TNetWalkResult; out aBadId: word): integer;

      (* Byte aIndex (0-based) of what is held. *)
      function ByteAt(const aIndex: integer): Byte;

      (* Drops the first aCount bytes; what follows becomes the front. *)
      procedure Discard(const aCount: integer);

      property Count: integer read FCount;
   end;

implementation

uses
   fpjson, jsonparser;

function NetMessageSize(const aId: word): integer;
begin
   case aId of
      NET_MESSAGESTATE_ID:     Result := SizeOf(TMessageState);
      NET_LOGCOMPARE_ID:       Result := SizeOf(TLogFileInformation);
      NET_INTERCOMMESSAGE_ID:  Result := SizeOf(TIntercomMessage);
      NET_NETWORKDXSPOT_ID:    Result := SizeOf(TNetDXSpot);

      // 1040, 1050 and 1055 (a fixed 384-byte QSO) are RETIRED with protocol 5
      // and fall to the else: unknown. A QSO is now NET_WIRE_*_ID, whose size
      // is in its own header (NetIsWireId).

      NET_TAKESERVERQSO_ID:    Result := SizeOf(TNetSynQSOInformation);
      NET_TIMESYN_ID:          Result := NET_TIMESYN_SIZE;   // removed feature, frame kept (VC)
      NET_PARAMETER_ID:        Result := SizeOf(TParameterToNetwork);
      NET_STATIONSTATUS_ID:    Result := SizeOf(TStationState);
      NET_CLIENTSTATUS_ID:     Result := SizeOf(TClientStatus);
      NET_SPOTVIANETWORK_ID:   Result := SizeOf(TSendSpotViaNetwork);
      NET_COMPUTERID_ID:       Result := SizeOf(TComputerNetID);
      NET_SERVERMESSAGE_ID:    Result := SizeOf(TServerMessage);
      NET_HELLO_ID:            Result := SizeOf(THelloMessage);
   else
      // NET_THIS_QTC_WAS__SEND_ID (1056) is DELIBERATELY ABSENT: the constant
      // exists in VC.pas but nothing on either side sends or handles it, and
      // guessing a record for it would put a wrong size in the one table that
      // is supposed to be right.
      Result := 0;
   end;
end;

function NetIsWireId(const aId: word): boolean;
begin
   Result := (aId = NET_WIRE_QSO_ID) or (aId = NET_WIRE_EDIT_ID) or
             (aId = NET_WIRE_OFFLINE_ID);
end;

function OutboundPacketIsWellFormed(const aId: word; const aLen: integer): boolean;
var
   size: integer;
begin
   Result := False;
   if aLen < SizeOf(word) then
      begin
      Exit;
      end;

   (* A variable message: only its length can be judged here (the header, the
     sender byte and a payload within the cap). OutboundWireMessageIsWellFormed
     reads the declared length too. *)
   if NetIsWireId(aId) then
      begin
      Result := (aLen >= NET_WIRE_HEADER_SIZE + 1) and
                (aLen <= NET_WIRE_HEADER_SIZE + NET_WIRE_MAX_PAYLOAD);
      Exit;
      end;

   size := NetMessageSize(aId);
   Result := (size > 0) and (aLen = size);
end;

procedure PutWordLE(var aBytes: TBytes; const aAt: integer; const aValue: Word);
begin
   aBytes[aAt] := aValue and $FF;
   aBytes[aAt + 1] := (aValue shr 8) and $FF;
end;

procedure PutCardinalLE(var aBytes: TBytes; const aAt: integer; const aValue: Cardinal);
begin
   aBytes[aAt] := aValue and $FF;
   aBytes[aAt + 1] := (aValue shr 8) and $FF;
   aBytes[aAt + 2] := (aValue shr 16) and $FF;
   aBytes[aAt + 3] := (aValue shr 24) and $FF;
end;

function GetWordLE(const aBytes: array of Byte; const aAt: integer): Word;
begin
   Result := Word(aBytes[aAt]) or (Word(aBytes[aAt + 1]) shl 8);
end;

function GetCardinalLE(const aBytes: array of Byte; const aAt: integer): Cardinal;
begin
   Result := Cardinal(aBytes[aAt]) or (Cardinal(aBytes[aAt + 1]) shl 8) or
             (Cardinal(aBytes[aAt + 2]) shl 16) or (Cardinal(aBytes[aAt + 3]) shl 24);
end;

function OutboundWireMessageIsWellFormed(const aPacket: TBytes): boolean;
var
   declared: Cardinal;
begin
   Result := False;
   if Length(aPacket) < NET_WIRE_HEADER_SIZE + 1 then
      begin
      Exit;
      end;
   if not NetIsWireId(GetWordLE(aPacket, 0)) then
      begin
      Exit;
      end;
   declared := GetCardinalLE(aPacket, 2);
   Result := (declared >= 1) and (declared <= NET_WIRE_MAX_PAYLOAD) and
             (Int64(declared) = Int64(Length(aPacket)) - NET_WIRE_HEADER_SIZE);
end;

constructor TNetSendRefusals.Create;
begin
   inherited Create;
   FLock := TCriticalSection.Create;
end;

destructor TNetSendRefusals.Destroy;
begin
   FLock.Free;
   inherited Destroy;
end;

function TNetSendRefusals.FirstSighting(const aId: word; const aLen: integer): boolean;
var
   key: Int64;
   i: integer;
begin
   (* The length goes in the low 32 bits as it is, so a negative length is a
     distinct key rather than a collision with a large one. *)
   key := (Int64(aId) shl 32) or Int64(Cardinal(aLen));
   Result := True;
   FLock.Enter;
   try
      for i := 0 to FCount - 1 do
         begin
         if FKeys[i] = key then
            begin
            Result := False;
            Exit;
            end;
         end;

      if FCount = Length(FKeys) then
         begin
         SetLength(FKeys, FCount + 8);
         end;
      FKeys[FCount] := key;
      Inc(FCount);
   finally
      FLock.Leave;
   end;
end;

procedure TNetSendRefusals.Forget;
begin
   FLock.Enter;
   try
      FCount := 0;
   finally
      FLock.Leave;
   end;
end;

function TNetSendRefusals.Count: integer;
begin
   FLock.Enter;
   try
      Result := FCount;
   finally
      FLock.Leave;
   end;
end;

function NextNetMessage(const aBuffer: array of Byte; const aLength: integer;
                        var aOffset: integer; out aId: word;
                        out aResult: TNetWalkResult): boolean;
var
   available: integer;
   remaining: integer;
   size: integer;
   declared: Cardinal;
   at: integer;       (* aOffset as an index into aBuffer, which is 0-based *)
begin
   Result := False;
   aId := 0;
   aResult := nwComplete;

   (* The bytes that are really there: what recv said, but never more than
     the buffer holds. *)
   available := aLength;
   if available > Length(aBuffer) then
      begin
      available := Length(aBuffer);
      end;

   if (aOffset < 1) or (available < 1) then
      begin
      Exit;
      end;

   remaining := available - aOffset + 1;
   if remaining <= 0 then
      begin
      Exit;      // ended exactly on a boundary -- nwComplete
      end;

   // NOT EVEN THE ID FITS.  One byte of a two-byte id is a partial message, not
   // an unknown one; calling it unknown would report a garbage id built from
   // one real byte and one stale one.
   if remaining < SizeOf(word) then
      begin
      aResult := nwPartial;
      Exit;
      end;

   at := aOffset - 1;            // 1-based position, 0-based array
   aId := word(aBuffer[at]) or (word(aBuffer[at + 1]) shl 8);

   if NetIsWireId(aId) then
      begin
      (* THE SIZE IS IN THE HEADER. Fewer than the six header bytes is a partial
        message; an over-large declaration is refused from the header alone. *)
      if remaining < NET_WIRE_HEADER_SIZE then
         begin
         aResult := nwPartial;
         Exit;
         end;
      declared := GetCardinalLE(aBuffer, at + 2);
      if declared > NET_WIRE_MAX_PAYLOAD then
         begin
         aResult := nwOversize;
         Exit;
         end;
      size := NET_WIRE_HEADER_SIZE + Integer(declared);
      end
   else
      begin
      size := NetMessageSize(aId);
      if size = 0 then
         begin
         aResult := nwUnknownId;
         Exit;
         end;
      end;

   { THE LENGTH CHECK THE ORIGINAL LOOP NEVER HAD.

     Every arm used to cast a whole record out of the buffer without asking
     whether the whole record was there.  If 100 bytes of a 264-byte QSO had
     arrived, the remaining 164 were STALE BYTES FROM AN EARLIER recv -- and the
     QSO was logged from them.  A duplicate of an earlier contact with a
     plausible call and a wrong band, or a garbage exchange, and nothing in the
     UI marked it.

     This does not make a split message WORK -- that needs a carry-over buffer
     the receive path does not have yet.  It makes it FAIL LOUDLY instead of
     silently logging a wrong QSO, which is the trade this branch takes every
     time. }
   if remaining < size then
      begin
      aResult := nwPartial;
      Exit;
      end;

   Inc(aOffset, size);
   Result := True;
end;

function NetWholeBytes(const aBuffer: array of Byte; const aLength: integer;
                       const aAllowLogInfoRequest: boolean;
                       out aResult: TNetWalkResult; out aBadId: word): integer;
var
   available: integer;
   offset:    integer;       (* 1-based, as NextNetMessage wants it *)
   remaining: integer;
   at:        integer;
   id:        word;
   step:      TNetWalkResult;
   sentinel:  Cardinal;
begin
   aResult := nwComplete;
   aBadId := 0;
   sentinel := NET_LOGINFO_MESSAGE;

   available := aLength;
   if available > Length(aBuffer) then
      begin
      available := Length(aBuffer);
      end;

   offset := 1;
   while offset <= available do
      begin
      remaining := available - offset + 1;
      at := offset - 1;

      if aAllowLogInfoRequest and (remaining >= SizeOf(word)) and
         ((word(aBuffer[at]) or (word(aBuffer[at + 1]) shl 8)) = Word(sentinel and $FFFF)) then
         begin
         if remaining < SizeOf(Cardinal) then
            begin
            aResult := nwPartial;
            Break;
            end;

         if (word(aBuffer[at + 2]) or (word(aBuffer[at + 3]) shl 8)) = Word(sentinel shr 16) then
            begin
            Inc(offset, SizeOf(Cardinal));
            Continue;
            end;

         aResult := nwUnknownId;
         aBadId := Word(sentinel and $FFFF);
         Break;
         end;

      if not NextNetMessage(aBuffer, available, offset, id, step) then
         begin
         aResult := step;
         if (step = nwUnknownId) or (step = nwOversize) then
            begin
            aBadId := id;
            end;
         Break;
         end;
      end;

   Result := offset - 1;
end;

(* ---------------------------------------------------- wire messages (proto 5) *)

const
   CODE_PAGE_UTF8 = 65001;   (* a code page number, not the unit that names it *)

(* The UTF-8 bytes of a string, by indexed copy. *)
function Utf8BytesOf(const aText: string): TBytes;
var
   u: UTF8String;
   i: integer;
begin
   u := UTF8Encode(aText);
   SetLength(Result, Length(u));
   for i := 1 to Length(u) do
      begin
      Result[i - 1] := Ord(u[i]);
      end;
end;

(* The text of the UTF-8 bytes from aFrom to the end. RELABELLED, never
  converted through the program's default code page. *)
function TextOfUtf8(const aBytes: TBytes; const aFrom: integer): string;
var
   raw: RawByteString;
   i, n: integer;
begin
   n := Length(aBytes) - aFrom;
   if n <= 0 then
      begin
      Result := '';
      Exit;
      end;
   SetLength(raw, n);
   for i := 0 to n - 1 do
      begin
      raw[i + 1] := AnsiChar(aBytes[aFrom + i]);
      end;
   SetCodePage(raw, CODE_PAGE_UTF8, False);
   Result := UnicodeString(raw);
end;

(* THE VALUES AS THE RECEIVER WILL DECODE THEM: a NUL never goes on the wire
  (WireText), and the checksum is over that, not over the sender's raw text. *)
function CleanValues(const aValues: TWireValues): TWireValues;
var
   i: integer;
begin
   SetLength(Result, Length(aValues));
   for i := 0 to High(aValues) do
      begin
      Result[i] := WireText(aValues[i]);
      end;
end;

function RowJsonBytes(aColumns: TWireColumns; const aValues: TWireValues): TBytes;
var
   clean: TWireValues;
begin
   clean := CleanValues(aValues);
   Result := Utf8BytesOf(EncodeJson(aColumns, clean, RecordCrc32(aColumns, clean), True));
end;

function BuildWireMessage(const aId: word; const aSender: Byte; aColumns: TWireColumns;
                          const aValues: TWireValues): TBytes;
var
   body: TBytes;
   i: integer;
begin
   if not NetIsWireId(aId) then
      begin
      raise EWireQsoError.CreateFmt('Message id %d is not a wire message.', [aId]);
      end;
   body := RowJsonBytes(aColumns, aValues);
   if 1 + Length(body) > NET_WIRE_MAX_PAYLOAD then
      begin
      raise EWireQsoError.CreateFmt('A wire row of %d bytes is over the %d-byte limit.',
         [1 + Length(body), NET_WIRE_MAX_PAYLOAD]);
      end;
   SetLength(Result, NET_WIRE_HEADER_SIZE + 1 + Length(body));
   PutWordLE(Result, 0, aId);
   PutCardinalLE(Result, 2, 1 + Length(body));
   Result[NET_WIRE_HEADER_SIZE] := aSender;
   for i := 0 to High(body) do
      begin
      Result[NET_WIRE_HEADER_SIZE + 1 + i] := body[i];
      end;
end;

(* The JSON from aFrom on, taken apart and judged: parses, states a checksum
  that matches, and every numeric column holds canonical digits. *)
function TakeJsonBody(aColumns: TWireColumns; const aBytes: TBytes; const aFrom: integer;
                      out aValues: TWireValues; out aReason: string): TWireTake;
var
   stated: Cardinal;
   stamped: boolean;
   i: integer;
   n: Int64;
begin
   aValues := nil;
   aReason := '';
   try
      stamped := DecodeJson(aColumns, TextOfUtf8(aBytes, aFrom), aValues, stated);
   except
      on E: Exception do
         begin
         aValues := nil;
         aReason := E.Message;
         Result := wtBadJson;
         Exit;
         end;
   end;
   if (not stamped) or (RecordCrc32(aColumns, aValues) <> stated) then
      begin
      aReason := 'the record checksum is missing or does not match';
      Result := wtBadChecksum;
      Exit;
      end;
   for i := 0 to aColumns.Count - 1 do
      begin
      if aColumns.Numeric[i] and (aValues[i] <> '') and
         (not TryCanonicalInt64(aValues[i], n)) then
         begin
         aReason := 'column ' + aColumns.Name[i] + ' is numeric and holds "' + aValues[i] + '"';
         Result := wtBadNumber;
         Exit;
         end;
      end;
   Result := wtOk;
end;

function TakeWireMessage(aColumns: TWireColumns; const aPayload: TBytes;
                         out aSender: Byte; out aValues: TWireValues;
                         out aReason: string): TWireTake;
begin
   aSender := 0;
   aValues := nil;
   aReason := '';
   if Length(aPayload) < 1 then
      begin
      aReason := 'an empty payload: no sender byte';
      Result := wtNoSender;
      Exit;
      end;
   aSender := aPayload[0];
   Result := TakeJsonBody(aColumns, aPayload, 1, aValues, aReason);
end;

function BuildSyncHeaderFrame(const aContest: string; const aRows: integer): TBytes;
var
   o: TJSONObject;
   body: TBytes;
   i: integer;
begin
   o := TJSONObject.Create;
   try
      o.Add(UTF8Encode('contest'), UTF8Encode(aContest));
      o.Add(UTF8Encode('rows'), aRows);
      o.Add(UTF8Encode('schema'), NET_PROTOCOL_VERSION);
      body := Utf8BytesOf(o.AsJSON);
   finally
      o.Free;
   end;
   SetLength(Result, 4 + Length(body));
   PutCardinalLE(Result, 0, Length(body));
   for i := 0 to High(body) do
      begin
      Result[4 + i] := body[i];
      end;
end;

function BuildSyncRowFrame(aColumns: TWireColumns; const aValues: TWireValues): TBytes;
var
   body: TBytes;
   i: integer;
begin
   body := RowJsonBytes(aColumns, aValues);
   SetLength(Result, 4 + Length(body));
   PutCardinalLE(Result, 0, Length(body));
   for i := 0 to High(body) do
      begin
      Result[4 + i] := body[i];
      end;
end;

function TakeSyncHeader(const aBody: TBytes; out aContest: string; out aRows: integer;
                        out aSchema: integer): boolean;
var
   d: TJSONData;
   o: TJSONObject;
   item: TJSONData;
begin
   Result := False;
   aContest := '';
   aRows := -1;
   aSchema := -1;
   try
      d := GetJSON(UTF8Encode(TextOfUtf8(aBody, 0)));
   except
      on Exception do
         begin
         Exit;
         end;
   end;
   try
      if not (d is TJSONObject) then
         begin
         Exit;
         end;
      o := TJSONObject(d);
      item := o.Find('contest');
      if (item <> nil) and (not item.IsNull) then
         begin
         aContest := item.AsString;
         end;
      item := o.Find('rows');
      if item <> nil then
         begin
         aRows := item.AsInteger;
         end;
      item := o.Find('schema');
      if item <> nil then
         begin
         aSchema := item.AsInteger;
         end;
      Result := aRows >= 0;
   finally
      d.Free;
   end;
end;

function TakeSyncRow(aColumns: TWireColumns; const aBody: TBytes;
                     out aValues: TWireValues; out aReason: string): TWireTake;
begin
   Result := TakeJsonBody(aColumns, aBody, 0, aValues, aReason);
end;

(* ------------------------------------------------------- TNetStreamBuffer *)

procedure TNetStreamBuffer.Append(const aBytes: array of Byte);
var
   i: integer;
begin
   if Length(aBytes) = 0 then
      begin
      Exit;
      end;

   if FCount + Length(aBytes) > Length(FData) then
      begin
      SetLength(FData, FCount + Length(aBytes));
      end;

   for i := 0 to High(aBytes) do
      begin
      FData[FCount + i] := aBytes[i];
      end;
   Inc(FCount, Length(aBytes));
end;

function TNetStreamBuffer.WholeBytes(const aAllowLogInfoRequest: boolean;
                                     out aResult: TNetWalkResult;
                                     out aBadId: word): integer;
begin
   Result := NetWholeBytes(FData, FCount, aAllowLogInfoRequest, aResult, aBadId);
end;

function TNetStreamBuffer.ByteAt(const aIndex: integer): Byte;
begin
   Result := 0;
   if (aIndex >= 0) and (aIndex < FCount) then
      begin
      Result := FData[aIndex];
      end;
end;

procedure TNetStreamBuffer.Discard(const aCount: integer);
var
   i: integer;
begin
   if aCount <= 0 then
      begin
      Exit;
      end;

   if aCount >= FCount then
      begin
      FCount := 0;
      Exit;
      end;

   for i := aCount to FCount - 1 do
      begin
      FData[i - aCount] := FData[i];
      end;
   Dec(FCount, aCount);
end;

end.
