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

  THE PROTOCOL HAS NO FRAMING.  No length prefix, no sentinel, no checksum.  A
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
   VC,
   uNetHello;   (* THelloMessage -- the size of the first message *)

type
   { Why a walk stopped. }
   TNetWalkResult = (
      nwComplete,     // the buffer ended exactly on a message boundary
      nwPartial,      // a known id, but not all of its bytes are here yet
      nwUnknownId     // no table entry -- the walk cannot advance past it
   );

{ How many bytes the message with this id occupies, INCLUDING its leading id
  Word, or 0 if the id is not one we know.

  0 IS THE IMPORTANT ANSWER.  It is what tells the caller it cannot advance,
  which is the difference between reporting a desync and spinning on it. }
function NetMessageSize(const aId: word): integer;

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

function NetMessageSize(const aId: word): integer;
begin
   case aId of
      NET_MESSAGESTATE_ID:     Result := SizeOf(TMessageState);
      NET_LOGCOMPARE_ID:       Result := SizeOf(TLogFileInformation);
      NET_INTERCOMMESSAGE_ID:  Result := SizeOf(TIntercomMessage);
      NET_NETWORKDXSPOT_ID:    Result := SizeOf(TNetDXSpot);

      // Three ids, one record: a new QSO, an edited QSO and an offline QSO
      // differ in what the receiver DOES, not in what arrives.
      NET_QSOINFO_ID,
      NET_EDITEDQSO_ID,
      NET_OFFLINEQSO_ID:       Result := SizeOf(TNetQSOInformation);

      NET_TAKESERVERQSO_ID:    Result := SizeOf(TNetSynQSOInformation);
      NET_TIMESYN_ID:          Result := SizeOf(TNetTimeSync);
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

function NextNetMessage(const aBuffer: array of Byte; const aLength: integer;
                        var aOffset: integer; out aId: word;
                        out aResult: TNetWalkResult): boolean;
var
   available: integer;
   remaining: integer;
   size: integer;
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

   size := NetMessageSize(aId);
   if size = 0 then
      begin
      aResult := nwUnknownId;
      Exit;
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
         if step = nwUnknownId then
            begin
            aBadId := id;
            end;
         Break;
         end;
      end;

   Result := offset - 1;
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
