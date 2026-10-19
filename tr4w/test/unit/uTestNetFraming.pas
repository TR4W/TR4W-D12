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
   end;

implementation

uses
   VC, uNetFraming;

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
   CheckEquals(SizeOf(TNetQSOInformation), NetMessageSize(NET_QSOINFO_ID),
               'QSO info');
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
   Check(NetMessageSize(NET_QSOINFO_ID) > 0, 'qso info');
   Check(NetMessageSize(NET_EDITEDQSO_ID) > 0, 'edited qso');
   Check(NetMessageSize(NET_OFFLINEQSO_ID) > 0, 'offline qso');
   Check(NetMessageSize(NET_TAKESERVERQSO_ID) > 0, 'take server qso');
   Check(NetMessageSize(NET_TIMESYN_ID) > 0, 'time sync');
   Check(NetMessageSize(NET_PARAMETER_ID) > 0, 'parameter');
   Check(NetMessageSize(NET_STATIONSTATUS_ID) > 0, 'station status');
   Check(NetMessageSize(NET_CLIENTSTATUS_ID) > 0, 'client status');
   Check(NetMessageSize(NET_SPOTVIANETWORK_ID) > 0, 'spot via network');
   Check(NetMessageSize(NET_COMPUTERID_ID) > 0, 'computer id');
   Check(NetMessageSize(NET_SERVERMESSAGE_ID) > 0, 'server message');
end;

{ THE DEFECT THIS UNIT WAS WRITTEN FOR.  The spot arm advanced by
  SizeOf(TNetQSOInformation) -- 264 for a 48-byte message.  If these two are
  ever equal the test is meaningless, so it asserts they differ as well. }
procedure TTestNetFraming.Test_SpotIsNotAQSO;
begin
   Check(NetMessageSize(NET_SPOTVIANETWORK_ID) <>
         NetMessageSize(NET_QSOINFO_ID),
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
   PutId(buf, 1, NET_QSOINFO_ID);

   offset := 1;
   // 100 bytes of a 264-byte QSO -- the rest is still in the socket.
   Check(not NextNetMessage(buf, 100, offset, id, res),
         'a partial QSO must never be reported as complete');
   Check(res = nwPartial, 'and it is partial, not unknown');
   CheckEquals(NET_QSOINFO_ID, id, 'the id is known even though the body is not');
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
   IDS: array[0..14] of word = (
      NET_MESSAGESTATE_ID, NET_LOGCOMPARE_ID, NET_INTERCOMMESSAGE_ID,
      NET_NETWORKDXSPOT_ID, NET_QSOINFO_ID, NET_EDITEDQSO_ID,
      NET_OFFLINEQSO_ID, NET_TAKESERVERQSO_ID, NET_TIMESYN_ID,
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

procedure TTestNetFraming.RunAllTests;
begin
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
