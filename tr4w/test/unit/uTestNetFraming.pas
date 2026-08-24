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
   end;

implementation

uses
   VC, uNetFraming;

{ A buffer the walker can be pointed at.  1-based like NetBuffer, which is what
  the real caller passes. }
type
   TNetTestBuffer = array[1..4096] of byte;

procedure PutId(var aBuf: TNetTestBuffer; const aOffset: integer;
                const aId: word);
begin
   PWord(@aBuf[aOffset])^ := aId;
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
   FillChar(buf, SizeOf(buf), 0);
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
   FillChar(buf, SizeOf(buf), 0);
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
   FillChar(buf, SizeOf(buf), 0);
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
   FillChar(buf, SizeOf(buf), 0);
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
   FillChar(buf, SizeOf(buf), 0);
   PutId(buf, 1, NET_COMPUTERID_ID);

   offset := 1;
   Check(NextNetMessage(buf, SizeOf(TComputerNetID), offset, id, res),
         'a buffer holding exactly one message yields it');
   Check(not NextNetMessage(buf, SizeOf(TComputerNetID), offset, id, res),
         'and then nothing');
   Check(res = nwComplete, 'cleanly -- not partial');
end;

procedure TTestNetFraming.RunAllTests;
begin
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
