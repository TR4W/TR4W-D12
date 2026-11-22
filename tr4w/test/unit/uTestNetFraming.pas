{ THE TEST THAT MATTERS FOR THE MULTI-OP LINK.

  uNet had NO test at all -- not one -- and its message loop lived inside a
  dialog procedure where nothing automated could reach it.  Three defects lived
  in there undisturbed: an arm that advanced 264 bytes for a 48-byte message, an
  arm that overwrote the recv byte count with a client index, and no length
  check of any kind before a whole record was cast out of the buffer.

  THE SPLIT-MESSAGE CASE IS THE ONE TO READ FIRST.  TCP may divide a stream
  anywhere; the receive path has no carry-over buffer and restarts at offset 1
  on every message.  So a 264-byte QSO arriving as 100 bytes then 164 used to be
  assembled from STALE BYTES and logged as a real contact.  Test_PartialMessage
  is the pin that says the framer refuses it instead.

  Named after uTestDXClusterClient.Test_LineSplitAcrossSegments, which found the
  same class of defect on the DX cluster -- a different subsystem entirely, and
  the resemblance is in the BUG, not the protocol. }
unit uTestNetFraming;

{$I ..\..\src\tr4w.inc}

interface

uses
   uTR4WTestFramework;

type
   TTestNetFraming = class(TTestCase)
   public
      procedure RunAllTests; override;

   private
      procedure Test_SizeIncludesTheIdWord;
      procedure Test_EverySentIdHasASize;
      procedure Test_SpotIsNotAQSO;
      procedure Test_UnknownIdIsRefused;
      procedure Test_WalksTwoMessages;
      procedure Test_PartialMessage;
      procedure Test_TruncatedIdIsPartialNotUnknown;
      procedure Test_ExactFitEndsClean;

      (* P12 (docs/POINTER_AUDIT.md, 2026-10-18): written BEFORE NextNetMessage
        lost its untyped buffer, and green against it. The last one is the
        pin a 1-based-to-0-based translation would break. *)
      procedure Test_ZeroLengthIsComplete;
      procedure Test_OffsetZeroIsRefused;
      procedure Test_LargestMessageExactAndOneShort;
      procedure Test_TrailingByteAfterAMessageIsPartial;
      procedure Test_MessageEndingOnTheLastByte;

      (* NEW WITH THE OPEN ARRAY, so written after it: the walker knows where
        the buffer ends and an over-stated length cannot carry it past. The
        untyped version would have read whatever memory came next. *)
      procedure Test_OverstatedLengthNeverReadsPastTheBuffer;

      (* C7 (2026-10-27): the server keeps an incomplete tail per connection. *)
      procedure Test_ThirtyBackToBackQSOsAreThirty;
      procedure Test_BurstInSegmentsLosesNothing;
      procedure Test_SplitAtEveryByteIsOneMessage;
      procedure Test_TrailingPartialIsKept;
      procedure Test_UnknownIdIsReportedNotReparsed;
      procedure Test_LogInfoRequestOnlyWhenAllowed;

      (* PROTOCOL 5 (2026-11-22): id + 4-byte length + payload for a QSO. *)
      procedure Test_TheRetiredQsoIdsAreUnknown;
      procedure Test_AnOversizeDeclarationIsRefusedFromTheHeader;
      procedure Test_AWireHeaderCutShortIsPartialAndZeroLengthIsWhole;
      procedure Test_AFixedMessageFollowsAWireFrame;
      procedure Test_LittleEndianHelpers;
      procedure Test_AWireMessageRoundTrips;
      procedure Test_ABadRowIsRefusedNotRelayed;
      procedure Test_BuildRefusesAnOverlongRowAndAnOutboundCheckJudgesBytes;
      procedure Test_TheSyncStreamFramesRoundTrip;
   end;

implementation

uses
   SysUtils, VC, uNetFraming, uNetHello, uWireQso;

{ A buffer the walker can be pointed at.  1-based like NetBuffer, which is what
  the real caller passes. }
type
   TNetTestBuffer = array[1..4096] of byte;

(* The id as V1 writes it: two bytes, low byte first. *)
procedure PutId(var aBuf: TNetTestBuffer; const aOffset: integer;
                const aId: word);
begin
   aBuf[aOffset]     := Lo(aId);
   aBuf[aOffset + 1] := Hi(aId);
end;

(* A clean buffer for each test -- assigned, not FillChar'd (P12/P15). *)
procedure ZeroBuffer(var aBuf: TNetTestBuffer);
var
   i: integer;
begin
   for i := Low(aBuf) to High(aBuf) do
      begin
      aBuf[i] := 0;
      end;
end;

{ Every size is the record's own size, and the id Word is INSIDE the record --
  it is the first field, not a prefix in front of it.  Getting that wrong by two
  bytes per message is exactly the kind of drift this table exists to stop. }
procedure TTestNetFraming.Test_SizeIncludesTheIdWord;
begin
   CheckEquals(SizeOf(TStationState), NetMessageSize(NET_STATIONSTATUS_ID),
               'station status');
   CheckEquals(SizeOf(TParameterToNetwork), NetMessageSize(NET_PARAMETER_ID),
               'parameter');
   CheckEquals(SizeOf(TServerMessage), NetMessageSize(NET_SERVERMESSAGE_ID),
               'server message');
end;

{ EVERY ID THIS PROGRAM CAN PUT ON THE WIRE MUST BE IN THE TABLE.  An id we send
  but cannot size is an id that stops the receiver dead -- which is precisely
  the cross-build hazard around NET_MESSAGESTATE_ID. }
procedure TTestNetFraming.Test_EverySentIdHasASize;
begin
   Check(NetMessageSize(NET_MESSAGESTATE_ID) > 0, 'message state');
   Check(NetMessageSize(NET_LOGCOMPARE_ID) > 0, 'log compare');
   Check(NetMessageSize(NET_INTERCOMMESSAGE_ID) > 0, 'intercom');
   Check(NetMessageSize(NET_NETWORKDXSPOT_ID) > 0, 'dx spot');
   (* PROTOCOL 5: a QSO is a VARIABLE message, so the fixed table has no size
     for it, and the retired 1040/1050/1055 are unknown. *)
   Check(NetIsWireId(NET_WIRE_QSO_ID), 'wire qso');
   Check(NetIsWireId(NET_WIRE_EDIT_ID), 'wire edit');
   Check(NetIsWireId(NET_WIRE_OFFLINE_ID), 'wire offline');
   CheckEquals(0, NetMessageSize(NET_WIRE_QSO_ID), 'a wire id has no fixed size');
   Check(NetMessageSize(NET_TAKESERVERQSO_ID) > 0, 'take server qso');
   Check(NetMessageSize(NET_TIMESYN_ID) > 0, 'time sync');
   Check(NetMessageSize(NET_PARAMETER_ID) > 0, 'parameter');
   Check(NetMessageSize(NET_STATIONSTATUS_ID) > 0, 'station status');
   Check(NetMessageSize(NET_CLIENTSTATUS_ID) > 0, 'client status');
   Check(NetMessageSize(NET_SPOTVIANETWORK_ID) > 0, 'spot via network');
   Check(NetMessageSize(NET_COMPUTERID_ID) > 0, 'computer id');
   Check(NetMessageSize(NET_SERVERMESSAGE_ID) > 0, 'server message');
   Check(NetMessageSize(NET_HELLO_ID) > 0, 'hello (network protocol 2)');
end;

{ THE DEFECT THIS UNIT WAS WRITTEN FOR.  The spot arm advanced by
  SizeOf(TNetQSOInformation) -- 264 for a 48-byte message.  If these two are
  ever equal the test is meaningless, so it asserts they differ as well. }
procedure TTestNetFraming.Test_SpotIsNotAQSO;
begin
   Check(NetMessageSize(NET_SPOTVIANETWORK_ID) <>
         NetMessageSize(NET_PARAMETER_ID),
         'a spot and a QSO must not be the same size, or this test proves nothing');
   CheckEquals(SizeOf(TSendSpotViaNetwork),
               NetMessageSize(NET_SPOTVIANETWORK_ID),
               'the spot advance must match the record the arm casts');
end;

procedure TTestNetFraming.Test_UnknownIdIsRefused;
var
   buf: TNetTestBuffer;
   offset: integer;
   id: word;
   res: TNetWalkResult;
begin
   ZeroBuffer(buf);
   PutId(buf, 1, 4242);            // no such message

   offset := 1;
   Check(not NextNetMessage(buf, 64, offset, id, res),
         'an unknown id must not be reported as a message');
   Check(res = nwUnknownId, 'and the reason must say so');
   CheckEquals(4242, id, 'the id is reported so a log line can name it');
   CheckEquals(1, offset, 'the cursor must not move past bytes we cannot size');
end;

procedure TTestNetFraming.Test_WalksTwoMessages;
var
   buf: TNetTestBuffer;
   offset, total: integer;
   id: word;
   res: TNetWalkResult;
begin
   ZeroBuffer(buf);
   PutId(buf, 1, NET_STATIONSTATUS_ID);
   PutId(buf, 1 + SizeOf(TStationState), NET_SERVERMESSAGE_ID);
   total := SizeOf(TStationState) + SizeOf(TServerMessage);

   offset := 1;
   Check(NextNetMessage(buf, total, offset, id, res), 'first message');
   CheckEquals(NET_STATIONSTATUS_ID, id, 'first id');
   CheckEquals(1 + SizeOf(TStationState), offset, 'cursor after the first');

   Check(NextNetMessage(buf, total, offset, id, res), 'second message');
   CheckEquals(NET_SERVERMESSAGE_ID, id, 'second id');

   Check(not NextNetMessage(buf, total, offset, id, res), 'no third');
   Check(res = nwComplete, 'the buffer ended on a boundary');
end;

{ THE ONE THAT MATTERS.  A QSO that has not all arrived must be refused, not
  assembled from whatever was in the buffer last time. }
procedure TTestNetFraming.Test_PartialMessage;
var
   buf: TNetTestBuffer;
   offset: integer;
   id: word;
   res: TNetWalkResult;
begin
   ZeroBuffer(buf);
   PutId(buf, 1, NET_PARAMETER_ID);

   offset := 1;
   // part of a parameter message -- the rest is still in the socket.
   Check(not NextNetMessage(buf, NetMessageSize(NET_PARAMETER_ID) div 2, offset, id, res),
         'a partial message must never be reported as complete');
   Check(res = nwPartial, 'and it is partial, not unknown');
   CheckEquals(NET_PARAMETER_ID, id, 'the id is known even though the body is not');
   CheckEquals(1, offset, 'the cursor must not move past a message we did not take');
end;

{ One byte of a two-byte id is PARTIAL, not unknown.  Calling it unknown would
  report a garbage id built from one real byte and one stale one. }
procedure TTestNetFraming.Test_TruncatedIdIsPartialNotUnknown;
var
   buf: TNetTestBuffer;
   offset: integer;
   id: word;
   res: TNetWalkResult;
begin
   ZeroBuffer(buf);
   PutId(buf, 1, NET_STATIONSTATUS_ID);

   offset := 1;
   Check(not NextNetMessage(buf, 1, offset, id, res), 'one byte is not a message');
   Check(res = nwPartial, 'a half-arrived id is partial');
end;

procedure TTestNetFraming.Test_ExactFitEndsClean;
var
   buf: TNetTestBuffer;
   offset: integer;
   id: word;
   res: TNetWalkResult;
begin
   ZeroBuffer(buf);
   PutId(buf, 1, NET_COMPUTERID_ID);

   offset := 1;
   Check(NextNetMessage(buf, SizeOf(TComputerNetID), offset, id, res),
         'a buffer holding exactly one message yields it');
   Check(not NextNetMessage(buf, SizeOf(TComputerNetID), offset, id, res),
         'and then nothing');
   Check(res = nwComplete, 'cleanly -- not partial');
end;

{ The id of the LARGEST message V1 defines, found by asking the table rather
  than by naming a record -- so this stays right if a size is ever corrected. }
function LargestMessageId: word;
const
   IDS: array[0..11] of word = (
      NET_MESSAGESTATE_ID, NET_LOGCOMPARE_ID, NET_INTERCOMMESSAGE_ID,
      NET_NETWORKDXSPOT_ID, NET_TAKESERVERQSO_ID, NET_TIMESYN_ID,
      NET_PARAMETER_ID, NET_STATIONSTATUS_ID, NET_CLIENTSTATUS_ID,
      NET_SPOTVIANETWORK_ID, NET_COMPUTERID_ID, NET_SERVERMESSAGE_ID);
var
   i: integer;
begin
   Result := IDS[0];
   for i := 1 to High(IDS) do
      begin
      if NetMessageSize(IDS[i]) > NetMessageSize(Result) then
         begin
         Result := IDS[i];
         end;
      end;
end;

procedure TTestNetFraming.Test_ZeroLengthIsComplete;
var
   buf: TNetTestBuffer;
   offset: integer;
   id: word;
   res: TNetWalkResult;
begin
   ZeroBuffer(buf);
   offset := 1;
   Check(not NextNetMessage(buf, 0, offset, id, res), 'an empty read holds no message');
   Check(res = nwComplete, 'and nothing is pending');
   CheckEquals(1, offset, 'the cursor stays put');
end;

procedure TTestNetFraming.Test_OffsetZeroIsRefused;
var
   buf: TNetTestBuffer;
   offset: integer;
   id: word;
   res: TNetWalkResult;
begin
   ZeroBuffer(buf);
   PutId(buf, 1, NET_COMPUTERID_ID);
   offset := 0;                    // the buffer is 1-based; 0 is before it
   Check(not NextNetMessage(buf, 64, offset, id, res), 'offset 0 is not a position');
   CheckEquals(0, offset, 'and is not advanced');
end;

procedure TTestNetFraming.Test_LargestMessageExactAndOneShort;
var
   buf: TNetTestBuffer;
   offset, size: integer;
   id, largest: word;
   res: TNetWalkResult;
begin
   ZeroBuffer(buf);
   largest := LargestMessageId;
   size := NetMessageSize(largest);
   Check(size <= SizeOf(buf), 'the largest message fits the test buffer');
   PutId(buf, 1, largest);

   offset := 1;
   Check(not NextNetMessage(buf, size - 1, offset, id, res),
         'the largest message one byte short is not complete');
   Check(res = nwPartial, 'it is partial');

   offset := 1;
   Check(NextNetMessage(buf, size, offset, id, res),
         'the largest message, exactly, is complete');
   CheckEquals(largest, id, 'and is the one placed');
   CheckEquals(1 + size, offset, 'and the cursor is past it');
end;

procedure TTestNetFraming.Test_TrailingByteAfterAMessageIsPartial;
var
   buf: TNetTestBuffer;
   offset, total: integer;
   id: word;
   res: TNetWalkResult;
begin
   ZeroBuffer(buf);
   PutId(buf, 1, NET_COMPUTERID_ID);
   buf[1 + SizeOf(TComputerNetID)] := $AA;      // half of the next id
   total := SizeOf(TComputerNetID) + 1;

   offset := 1;
   Check(NextNetMessage(buf, total, offset, id, res), 'the whole message');
   Check(not NextNetMessage(buf, total, offset, id, res), 'then one stray byte');
   Check(res = nwPartial, 'which is the start of an id, so partial');
   CheckEquals(1 + SizeOf(TComputerNetID), offset, 'and is kept for the next read');
end;

procedure TTestNetFraming.Test_MessageEndingOnTheLastByte;
var
   buf: TNetTestBuffer;
   offset, size, start: integer;
   id, largest: word;
   res: TNetWalkResult;
begin
   ZeroBuffer(buf);
   largest := LargestMessageId;
   size := NetMessageSize(largest);
   start := High(buf) - size + 1;               // ends on buf[4096] exactly
   PutId(buf, start, largest);

   offset := start;
   Check(NextNetMessage(buf, High(buf), offset, id, res),
         'a message ending on the buffer''s last byte is complete');
   CheckEquals(largest, id, 'its id is read from the right place');
   CheckEquals(High(buf) + 1, offset, 'the cursor ends one past the buffer');
   Check(not NextNetMessage(buf, High(buf), offset, id, res), 'and nothing follows');
   Check(res = nwComplete, 'cleanly');
end;

procedure TTestNetFraming.Test_OverstatedLengthNeverReadsPastTheBuffer;
var
   small: array[1..8] of byte;
   exact: array of byte;
   offset: integer;
   id, largest: word;
   res: TNetWalkResult;
   i: integer;
begin
   largest := LargestMessageId;
   Check(NetMessageSize(largest) > SizeOf(small),
         'precondition: the largest message does not fit in eight bytes');
   for i := Low(small) to High(small) do
      begin
      small[i] := 0;
      end;
   small[1] := Lo(largest);
   small[2] := Hi(largest);

   offset := 1;
   Check(not NextNetMessage(small, 4096, offset, id, res),
         'eight real bytes of a longer message are not a message, whatever the length says');
   Check(res = nwPartial, 'they are a partial one');
   CheckEquals(largest, id, 'whose id was read from the buffer');

   (* A buffer holding exactly one message, with the length over-stated:
     the message is taken, and then the walk ends at the buffer, cleanly. *)
   SetLength(exact, NetMessageSize(NET_COMPUTERID_ID));
   for i := 0 to High(exact) do
      begin
      exact[i] := 0;
      end;
   exact[0] := Lo(NET_COMPUTERID_ID);
   exact[1] := Hi(NET_COMPUTERID_ID);
   offset := 1;
   Check(NextNetMessage(exact, 4096, offset, id, res), 'the one message is taken');
   Check(not NextNetMessage(exact, 4096, offset, id, res), 'and nothing past the buffer');
   Check(res = nwComplete, 'the buffer ended on a boundary');
end;

(* ---- the server's side: whole messages out of an arbitrarily cut stream ---- *)

type
   TWire = array of Byte;

const
   (* The payload of every wire message these tests build: one sender byte and
     some filler, so a frame is 6 + 100 = 106 bytes. *)
   TEST_PAYLOAD = 100;

(* The bytes one message of this id occupies in these tests. *)
function OneFrame(const aId: word): integer;
begin
   if NetIsWireId(aId) then
      begin
      Result := NET_WIRE_HEADER_SIZE + TEST_PAYLOAD;
      end
   else
      begin
      Result := NetMessageSize(aId);
      end;
end;

(* One message of this id: the id Word (and, for a wire id, the declared length),
  then zeros, aCount of them end to end. *)
function WireMessages(const aId: word; const aCount: integer): TWire;
var
   one, n, i: integer;
begin
   one := OneFrame(aId);
   SetLength(Result, one * aCount);
   for i := 0 to High(Result) do
      begin
      Result[i] := 0;
      end;
   for n := 0 to aCount - 1 do
      begin
      Result[n * one]     := Lo(aId);
      Result[n * one + 1] := Hi(aId);
      if NetIsWireId(aId) then
         begin
         Result[n * one + 2] := TEST_PAYLOAD;    (* low byte of the length; the rest are 0 *)
         end;
      end;
end;

function WireSlice(const aWire: TWire; const aFrom, aCount: integer): TWire;
var
   i: integer;
begin
   SetLength(Result, aCount);
   for i := 0 to aCount - 1 do
      begin
      Result[i] := aWire[aFrom + i];
      end;
end;

(* What the server does with each read: append, take the whole messages, drop
  them. Returns how many messages that was. *)
function ServerPass(const aStream: TNetStreamBuffer; const aRead: TWire;
                    const aLogInfo: boolean; out aResult: TNetWalkResult;
                    out aBadId: word): integer;
var
   whole, offset: integer;
   id: word;
   walk: TNetWalkResult;
   probe: TWire;
   i: integer;
begin
   aStream.Append(aRead);
   whole := aStream.WholeBytes(aLogInfo, aResult, aBadId);
   SetLength(probe, whole);
   for i := 0 to whole - 1 do
      begin
      probe[i] := aStream.ByteAt(i);
      end;
   Result := 0;
   offset := 1;
   while NextNetMessage(probe, whole, offset, id, walk) do
      begin
      Inc(Result);
      end;
   aStream.Discard(whole);
end;

(* THE MEASURED LOSS: 30 QSOs in one send, 11 relayed. *)
procedure TTestNetFraming.Test_ThirtyBackToBackQSOsAreThirty;
var
   wire: TWire;
   res: TNetWalkResult;
   bad: word;
begin
   wire := WireMessages(NET_WIRE_QSO_ID, 30);
   CheckEquals(30 * OneFrame(NET_WIRE_QSO_ID), NetWholeBytes(wire, Length(wire), False, res, bad),
               'all thirty are whole');
   Check(res = nwComplete, 'and the buffer ends on a boundary');
end;

(* The same thirty, delivered the way TCP does: 1460-byte segments, the server
  reading at most its 4096-byte buffer. Nothing may be lost or doubled. *)
procedure TTestNetFraming.Test_BurstInSegmentsLosesNothing;
var
   wire: TWire;
   stream: TNetStreamBuffer;
   res: TNetWalkResult;
   bad: word;
   at, n, total: integer;
begin
   wire := WireMessages(NET_WIRE_QSO_ID, 30);
   stream := TNetStreamBuffer.Create;
   try
      total := 0;
      at := 0;
      while at < Length(wire) do
         begin
         n := Length(wire) - at;
         if n > 1460 then
            begin
            n := 1460;
            end;
         Inc(total, ServerPass(stream, WireSlice(wire, at, n), False, res, bad));
         Inc(at, n);
         end;
      CheckEquals(30, total, 'every message is parsed exactly once');
      CheckEquals(0, stream.Count, 'and nothing is left over');
   finally
      stream.Free;
   end;
end;

(* A message cut at EVERY byte boundary is one message once the rest arrives. *)
procedure TTestNetFraming.Test_SplitAtEveryByteIsOneMessage;
var
   wire: TWire;
   stream: TNetStreamBuffer;
   res: TNetWalkResult;
   bad: word;
   cut, total: integer;
begin
   wire := WireMessages(NET_WIRE_QSO_ID, 1);
   for cut := 1 to Length(wire) - 1 do
      begin
      stream := TNetStreamBuffer.Create;
      try
         total := ServerPass(stream, WireSlice(wire, 0, cut), False, res, bad);
         CheckEquals(0, total, 'cut at ' + IntToStr(cut) + ': the front is not a message');
         Check(res = nwPartial, 'cut at ' + IntToStr(cut) + ': it is kept as partial');
         CheckEquals(cut, stream.Count, 'cut at ' + IntToStr(cut) + ': all of it is kept');
         total := ServerPass(stream, WireSlice(wire, cut, Length(wire) - cut), False, res, bad);
         CheckEquals(1, total, 'cut at ' + IntToStr(cut) + ': the rest completes it');
         CheckEquals(0, stream.Count, 'cut at ' + IntToStr(cut) + ': nothing left');
      finally
         stream.Free;
      end;
      end;
end;

procedure TTestNetFraming.Test_TrailingPartialIsKept;
var
   one: integer;
   wire: TWire;
   stream: TNetStreamBuffer;
   res: TNetWalkResult;
   bad: word;
begin
   one := OneFrame(NET_WIRE_QSO_ID);
   wire := WireMessages(NET_WIRE_QSO_ID, 3);
   stream := TNetStreamBuffer.Create;
   try
      CheckEquals(2, ServerPass(stream, WireSlice(wire, 0, 2 * one + 50), False, res, bad),
                  'two whole messages');
      Check(res = nwPartial, 'then a partial third');
      CheckEquals(50, stream.Count, 'its 50 bytes are kept');
      CheckEquals(1, ServerPass(stream, WireSlice(wire, 2 * one + 50, one - 50), False, res, bad),
                  'the third completes');
      Check(res = nwComplete, 'and ends clean');
   finally
      stream.Free;
   end;
end;

procedure TTestNetFraming.Test_UnknownIdIsReportedNotReparsed;
var
   wire, junk, all: TWire;
   stream: TNetStreamBuffer;
   res: TNetWalkResult;
   bad: word;
   i: integer;
begin
   wire := WireMessages(NET_COMPUTERID_ID, 1);
   SetLength(junk, 8);
   for i := 0 to 7 do
      begin
      junk[i] := 0;
      end;
   junk[0] := Lo(9999);
   junk[1] := Hi(9999);
   SetLength(all, Length(wire) + Length(junk));
   for i := 0 to High(wire) do
      begin
      all[i] := wire[i];
      end;
   for i := 0 to High(junk) do
      begin
      all[Length(wire) + i] := junk[i];
      end;

   stream := TNetStreamBuffer.Create;
   try
      CheckEquals(1, ServerPass(stream, all, False, res, bad),
                  'the message before the bad id is still delivered');
      Check(res = nwUnknownId, 'and the unknown id is REPORTED');
      CheckEquals(9999, bad, 'by number');
      CheckEquals(8, stream.Count, 'the bad bytes are not consumed: the caller must drop the link');
   finally
      stream.Free;
   end;
end;

procedure TTestNetFraming.Test_LogInfoRequestOnlyWhenAllowed;
var
   wire: TWire;
   res: TNetWalkResult;
   bad: word;
   sentinel: Cardinal;
   stream: TNetStreamBuffer;
   cut: integer;
begin
   sentinel := NET_LOGINFO_MESSAGE;
   Check(NetMessageSize(Word(sentinel and $FFFF)) = 0,
         'the sentinel''s low Word must never be a message id');
   SetLength(wire, 4);
   wire[0] := Byte(sentinel);
   wire[1] := Byte(sentinel shr 8);
   wire[2] := Byte(sentinel shr 16);
   wire[3] := Byte(sentinel shr 24);

   CheckEquals(4, NetWholeBytes(wire, 4, True, res, bad), 'the server takes it');
   Check(res = nwComplete, 'whole');
   CheckEquals(0, NetWholeBytes(wire, 4, False, res, bad), 'a client link does not');
   Check(res = nwUnknownId, 'it is an unknown id there');

   for cut := 1 to 3 do
      begin
      stream := TNetStreamBuffer.Create;
      try
         CheckEquals(0, ServerPass(stream, WireSlice(wire, 0, cut), True, res, bad),
                     'cut at ' + IntToStr(cut));
         Check(res = nwPartial, 'a cut sentinel is partial, not unknown');
         ServerPass(stream, WireSlice(wire, cut, 4 - cut), True, res, bad);
         Check(res = nwComplete, 'completed');
         CheckEquals(0, stream.Count, 'and consumed');
      finally
         stream.Free;
      end;
      end;
end;

(* ---- protocol 5: variable-length QSO messages (design 13.7) ---- *)

(* A small column list: text, text with a default, numeric. *)
function TestColumns: TWireColumns;
begin
   Result := TWireColumns.Create;
   Result.Add('guid', False, '');
   Result.Add('callsign', False, '');
   Result.Add('record_kind', False, 'QSO');
   Result.Add('serial', True, '');
   Result.Add('is_off', True, '0');
end;

function TestRow(aColumns: TWireColumns; const aGuid, aCall, aKind, aSerial, aOff: string): TWireValues;
begin
   SetLength(Result, aColumns.Count);
   Result[0] := aGuid;
   Result[1] := aCall;
   Result[2] := aKind;
   Result[3] := aSerial;
   Result[4] := aOff;
end;

function AsciiOf(const aBytes: TBytes): string;
var
   i: integer;
begin
   Result := '';
   for i := 0 to High(aBytes) do
      begin
      Result := Result + Chr(aBytes[i]);
      end;
end;

(* The bytes after the six header bytes. *)
function PayloadOf(const aMsg: TBytes): TBytes;
var
   i: integer;
begin
   SetLength(Result, Length(aMsg) - NET_WIRE_HEADER_SIZE);
   for i := 0 to High(Result) do
      begin
      Result[i] := aMsg[NET_WIRE_HEADER_SIZE + i];
      end;
end;

function HeaderOnly(const aId: word; const aDeclared: Cardinal; const aExtra: integer): TWire;
begin
   SetLength(Result, NET_WIRE_HEADER_SIZE + aExtra);
   Result[0] := Lo(aId);
   Result[1] := Hi(aId);
   PutCardinalLE(TBytes(Result), 2, aDeclared);
end;

procedure TTestNetFraming.Test_TheRetiredQsoIdsAreUnknown;
var
   wire: TWire;
   res: TNetWalkResult;
   bad: word;
   ids: array[0..2] of word;
   i: integer;
begin
   ids[0] := 1040;
   ids[1] := 1050;
   ids[2] := 1055;
   for i := 0 to 2 do
      begin
      CheckEquals(0, NetMessageSize(ids[i]), 'no size for ' + IntToStr(ids[i]));
      Check(not NetIsWireId(ids[i]), 'not a wire id: ' + IntToStr(ids[i]));
      SetLength(wire, 384);
      wire[0] := Lo(ids[i]);
      wire[1] := Hi(ids[i]);
      CheckEquals(0, NetWholeBytes(wire, Length(wire), False, res, bad), 'nothing is whole');
      Check(res = nwUnknownId, 'reported unknown: ' + IntToStr(ids[i]));
      CheckEquals(ids[i], bad, 'by number');
      end;
   CheckEquals(1041, NET_WIRE_QSO_ID, 'the new ids');
   CheckEquals(1051, NET_WIRE_EDIT_ID, 'edit');
   CheckEquals(1057, NET_WIRE_OFFLINE_ID, 'offline');
end;

procedure TTestNetFraming.Test_AnOversizeDeclarationIsRefusedFromTheHeader;
var
   wire: TWire;
   res: TNetWalkResult;
   bad: word;
begin
   (* Over the cap with ONLY the six header bytes present: never "partial". *)
   wire := HeaderOnly(NET_WIRE_QSO_ID, NET_WIRE_MAX_PAYLOAD + 1, 0);
   CheckEquals(0, NetWholeBytes(wire, Length(wire), False, res, bad), 'nothing whole');
   Check(res = nwOversize, 'refused as oversize, not left waiting');
   CheckEquals(NET_WIRE_QSO_ID, bad, 'the id is reported');

   (* A top bit set must not read as a negative length. *)
   wire := HeaderOnly(NET_WIRE_EDIT_ID, $FFFFFFFF, 0);
   NetWholeBytes(wire, Length(wire), False, res, bad);
   Check(res = nwOversize, '$FFFFFFFF is oversize');
   wire := HeaderOnly(NET_WIRE_OFFLINE_ID, $80000000, 0);
   NetWholeBytes(wire, Length(wire), False, res, bad);
   Check(res = nwOversize, '$80000000 is oversize');

   (* Exactly the cap is allowed, and waits for its payload. *)
   wire := HeaderOnly(NET_WIRE_QSO_ID, NET_WIRE_MAX_PAYLOAD, 10);
   CheckEquals(0, NetWholeBytes(wire, Length(wire), False, res, bad), 'not yet whole');
   Check(res = nwPartial, 'the cap itself is partial until it arrives');

   (* Oversize with a payload "present": still refused. *)
   wire := HeaderOnly(NET_WIRE_QSO_ID, NET_WIRE_MAX_PAYLOAD + 1, 70000);
   NetWholeBytes(wire, Length(wire), False, res, bad);
   Check(res = nwOversize, 'refused whatever follows');
end;

procedure TTestNetFraming.Test_AWireHeaderCutShortIsPartialAndZeroLengthIsWhole;
var
   wire: TWire;
   res: TNetWalkResult;
   bad: word;
   cut: integer;
begin
   wire := HeaderOnly(NET_WIRE_QSO_ID, 0, 0);
   for cut := 2 to NET_WIRE_HEADER_SIZE - 1 do
      begin
      CheckEquals(0, NetWholeBytes(wire, cut, False, res, bad), 'cut at ' + IntToStr(cut));
      Check(res = nwPartial, 'a cut header is partial: ' + IntToStr(cut));
      end;
   CheckEquals(NET_WIRE_HEADER_SIZE, NetWholeBytes(wire, Length(wire), False, res, bad),
               'a zero-length payload is a whole frame (a refused row, not a framing error)');
   Check(res = nwComplete, 'and ends clean');
end;

procedure TTestNetFraming.Test_AFixedMessageFollowsAWireFrame;
var
   wire, fixed, all: TWire;
   res: TNetWalkResult;
   bad: word;
   i: integer;
begin
   wire := WireMessages(NET_WIRE_EDIT_ID, 2);
   fixed := WireMessages(NET_COMPUTERID_ID, 1);
   SetLength(all, Length(wire) + Length(fixed));
   for i := 0 to High(wire) do
      begin
      all[i] := wire[i];
      end;
   for i := 0 to High(fixed) do
      begin
      all[Length(wire) + i] := fixed[i];
      end;
   CheckEquals(Length(all), NetWholeBytes(all, Length(all), False, res, bad),
               'two frames and a fixed message');
   Check(res = nwComplete, 'clean');
end;

procedure TTestNetFraming.Test_LittleEndianHelpers;
var
   b: TBytes;
begin
   SetLength(b, 6);
   PutWordLE(b, 0, $0412);
   PutCardinalLE(b, 2, $A1B2C3D4);
   CheckEquals($12, b[0], 'word low');
   CheckEquals($04, b[1], 'word high');
   CheckEquals($D4, b[2], 'cardinal byte 0');
   CheckEquals($A1, b[5], 'cardinal byte 3');
   CheckEquals($0412, GetWordLE(b, 0), 'word back');
   CheckTrue(GetCardinalLE(b, 2) = $A1B2C3D4, 'cardinal back, top bit set');
end;

procedure TTestNetFraming.Test_AWireMessageRoundTrips;
var
   cols: TWireColumns;
   msg, payload: TBytes;
   row, got: TWireValues;
   sender: Byte;
   why: string;
   offset: integer;
   id: word;
   res: TNetWalkResult;
begin
   cols := TestColumns;
   try
      row := TestRow(cols, 'g-1', 'K1' + #0 + 'ABC' + #$00E9 + #$4E2D, 'QSO', '42', '0');
      msg := BuildWireMessage(NET_WIRE_EDIT_ID, 7, cols, row);
      Check(OutboundWireMessageIsWellFormed(msg), 'what the client builds passes its own check');
      offset := 1;
      Check(NextNetMessage(msg, Length(msg), offset, id, res), 'frames as one message');
      CheckEquals(NET_WIRE_EDIT_ID, id, 'with its id');
      CheckEquals(Length(msg) + 1, offset, 'and nothing left over');

      payload := PayloadOf(msg);
      Check(TakeWireMessage(cols, payload, sender, got, why) = wtOk, 'taken apart: ' + why);
      CheckEquals(7, sender, 'the sender byte');
      CheckEquals('g-1', got[0], 'guid');
      CheckEquals('K1ABC' + #$00E9 + #$4E2D, got[1], 'the NUL is gone, the UTF-8 survives');
      CheckEquals('QSO', got[2], 'a default comes back');
      CheckEquals('42', got[3], 'a number');
      CheckEquals('0', got[4], 'a numeric default');

      (* A default field is OMITTED: the JSON does not name it. *)
      Check(Pos('record_kind', AsciiOf(payload)) = 0, 'a field equal to its default is omitted');

      (* NULL and 0 stay distinct. *)
      row := TestRow(cols, 'g-2', 'W1AW', 'QSO', '', '');
      msg := BuildWireMessage(NET_WIRE_QSO_ID, 1, cols, row);
      Check(TakeWireMessage(cols, PayloadOf(msg), sender, got, why) = wtOk, 'null row: ' + why);
      CheckEquals('', got[3], 'a NULL number stays NULL');
      CheckEquals('', got[4], 'and a NULL beside a default of 0 stays NULL');
   finally
      cols.Free;
   end;
end;

procedure TTestNetFraming.Test_ABadRowIsRefusedNotRelayed;
var
   cols: TWireColumns;
   msg, payload: TBytes;
   row, got: TWireValues;
   sender: Byte;
   why, json: string;
   i: integer;
   u: UTF8String;
begin
   cols := TestColumns;
   try
      row := TestRow(cols, 'g-1', 'K1ABC', 'QSO', '42', '0');
      msg := BuildWireMessage(NET_WIRE_QSO_ID, 3, cols, row);

      (* one value changed after the checksum was made *)
      payload := PayloadOf(msg);
      for i := 1 to High(payload) do
         begin
         if payload[i] = Ord('K') then
            begin
            payload[i] := Ord('J');
            Break;
            end;
         end;
      Check(TakeWireMessage(cols, payload, sender, got, why) = wtBadChecksum,
            'a changed byte fails the checksum');

      (* no checksum member at all *)
      u := UTF8Encode('{"guid":"g-1","callsign":"K1ABC"}');
      SetLength(payload, 1 + Length(u));
      payload[0] := 1;
      for i := 1 to Length(u) do
         begin
         payload[i] := Ord(u[i]);
         end;
      Check(TakeWireMessage(cols, payload, sender, got, why) = wtBadChecksum, 'a missing "k" is a bad checksum');

      (* not JSON *)
      u := UTF8Encode('this is not json');
      SetLength(payload, 1 + Length(u));
      payload[0] := 1;
      for i := 1 to Length(u) do
         begin
         payload[i] := Ord(u[i]);
         end;
      Check(TakeWireMessage(cols, payload, sender, got, why) = wtBadJson, 'unparsable JSON');

      (* a JSON array is not an object *)
      u := UTF8Encode('[1,2,3]');
      SetLength(payload, 1 + Length(u));
      payload[0] := 1;
      for i := 1 to Length(u) do
         begin
         payload[i] := Ord(u[i]);
         end;
      Check(TakeWireMessage(cols, payload, sender, got, why) = wtBadJson, 'not one object');

      (* an empty payload has no sender byte *)
      SetLength(payload, 0);
      Check(TakeWireMessage(cols, payload, sender, got, why) = wtNoSender, 'no sender byte');

      (* a numeric column holding 1.5, with a MATCHING checksum, is a bad number *)
      row := TestRow(cols, 'g-9', 'K1ABC', 'QSO', '1.5', '0');
      json := '{"guid":"g-9","callsign":"K1ABC","serial":"1.5","k":"' +
              WireCrcText(RecordCrc32(cols, row)) + '"}';
      u := UTF8Encode(json);
      SetLength(payload, 1 + Length(u));
      payload[0] := 1;
      for i := 1 to Length(u) do
         begin
         payload[i] := Ord(u[i]);
         end;
      Check(TakeWireMessage(cols, payload, sender, got, why) = wtBadNumber, 'a non-integer number');

      (* a real JSON float is refused too (it will not match the checksum made from digits) *)
      json := '{"guid":"g-9","callsign":"K1ABC","serial":1.5,"k":"' + WireCrcText(RecordCrc32(cols, row)) + '"}';
      u := UTF8Encode(json);
      SetLength(payload, 1 + Length(u));
      payload[0] := 1;
      for i := 1 to Length(u) do
         begin
         payload[i] := Ord(u[i]);
         end;
      Check(TakeWireMessage(cols, payload, sender, got, why) <> wtOk, 'a JSON float is refused');
   finally
      cols.Free;
   end;
end;

procedure TTestNetFraming.Test_BuildRefusesAnOverlongRowAndAnOutboundCheckJudgesBytes;
var
   cols: TWireColumns;
   row: TWireValues;
   msg, damaged: TBytes;
   raised: boolean;
begin
   cols := TestColumns;
   try
      row := TestRow(cols, 'g-1', StringOfChar('x', 60001), 'QSO', '1', '0');
      raised := False;
      try
         BuildWireMessage(NET_WIRE_QSO_ID, 1, cols, row);
      except
         on EWireQsoError do
            begin
            raised := True;
            end;
      end;
      Check(raised, 'a row over the cap is refused at the sender');

      row := TestRow(cols, 'g-1', 'K1ABC', 'QSO', '1', '0');
      msg := BuildWireMessage(NET_WIRE_QSO_ID, 1, cols, row);
      Check(OutboundWireMessageIsWellFormed(msg), 'well formed');
      damaged := Copy(msg, 0, Length(msg) - 1);
      Check(not OutboundWireMessageIsWellFormed(damaged), 'a declared length that is not what follows');
      damaged := Copy(msg, 0, Length(msg));
      damaged[0] := Lo(1040);
      damaged[1] := Hi(1040);
      Check(not OutboundWireMessageIsWellFormed(damaged), 'a retired id');
      Check(not OutboundWireMessageIsWellFormed(Copy(msg, 0, 6)), 'a header with no payload');
      Check(OutboundPacketIsWellFormed(NET_WIRE_QSO_ID, Length(msg)), 'the id and length check passes a wire id');
      Check(not OutboundPacketIsWellFormed(NET_QSOINFO_ID, 384), 'and refuses the retired fixed QSO');
   finally
      cols.Free;
   end;
end;

procedure TTestNetFraming.Test_TheSyncStreamFramesRoundTrip;
var
   cols: TWireColumns;
   row, got: TWireValues;
   header, frame: TBytes;
   body: TBytes;
   contest, why: string;
   rows, schema, n: integer;
begin
   cols := TestColumns;
   try
      header := BuildSyncHeaderFrame('ARRL-DX-CW', 3);
      n := Integer(GetCardinalLE(header, 0));
      CheckEquals(Length(header) - 4, n, 'the 4-byte length is the JSON length');
      body := Copy(header, 4, n);
      Check(TakeSyncHeader(body, contest, rows, schema), 'the header parses');
      CheckEquals('ARRL-DX-CW', contest, 'contest');
      CheckEquals(3, rows, 'rows');
      CheckEquals(NET_PROTOCOL_VERSION, schema, 'schema is the protocol');

      row := TestRow(cols, 'g-1', 'K1ABC', 'QSO', '42', '0');
      frame := BuildSyncRowFrame(cols, row);
      n := Integer(GetCardinalLE(frame, 0));
      CheckEquals(Length(frame) - 4, n, 'row frame length');
      Check(TakeSyncRow(cols, Copy(frame, 4, n), got, why) = wtOk, 'the row parses: ' + why);
      CheckEquals('K1ABC', got[1], 'callsign');
      CheckEquals('42', got[3], 'number');

      body := Copy(frame, 4, n);
      body[2] := body[2] xor 1;
      Check(TakeSyncRow(cols, body, got, why) <> wtOk, 'a damaged row frame is refused');
   finally
      cols.Free;
   end;
end;

procedure TTestNetFraming.RunAllTests;
begin
   Test_TheRetiredQsoIdsAreUnknown;
   Test_AnOversizeDeclarationIsRefusedFromTheHeader;
   Test_AWireHeaderCutShortIsPartialAndZeroLengthIsWhole;
   Test_AFixedMessageFollowsAWireFrame;
   Test_LittleEndianHelpers;
   Test_AWireMessageRoundTrips;
   Test_ABadRowIsRefusedNotRelayed;
   Test_BuildRefusesAnOverlongRowAndAnOutboundCheckJudgesBytes;
   Test_TheSyncStreamFramesRoundTrip;
   Test_ThirtyBackToBackQSOsAreThirty;
   Test_BurstInSegmentsLosesNothing;
   Test_SplitAtEveryByteIsOneMessage;
   Test_TrailingPartialIsKept;
   Test_UnknownIdIsReportedNotReparsed;
   Test_LogInfoRequestOnlyWhenAllowed;
   Test_OverstatedLengthNeverReadsPastTheBuffer;
   Test_ZeroLengthIsComplete;
   Test_OffsetZeroIsRefused;
   Test_LargestMessageExactAndOneShort;
   Test_TrailingByteAfterAMessageIsPartial;
   Test_MessageEndingOnTheLastByte;
   Test_SizeIncludesTheIdWord;
   Test_EverySentIdHasASize;
   Test_SpotIsNotAQSO;
   Test_UnknownIdIsRefused;
   Test_WalksTwoMessages;
   Test_PartialMessage;
   Test_TruncatedIdIsPartialNotUnknown;
   Test_ExactFitEndsClean;
end;

end.
