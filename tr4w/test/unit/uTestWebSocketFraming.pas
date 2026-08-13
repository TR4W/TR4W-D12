unit uTestWebSocketFraming;
{$I ..\..\src\tr4w.inc}

{
  Pins uWebSocketFraming -- RFC 6455 frame encode/decode, reassembly, and the
  handshake digest.

  WHY THIS EXISTS.  Until the framing was extracted out of uWebSocketClient it
  had NO tests at all: it was reachable only through an Indy socket pointed at
  a real TCI server, so every assertion about it was a bench observation. The
  extraction made it pure, and this suite is the point of having done that.

  The reader is a memory buffer, not a socket.  WSReadFrame takes a
  "read exactly N bytes" callback precisely so both transports and this test
  can supply their own.

  ROLE ASYMMETRY IS THE MAIN SUBJECT.  RFC 6455 requires a client to mask and
  a server not to, and requires each to REJECT the other's masking state on
  the way in.  The pre-extraction code only ever implemented the client half,
  so the four combinations below (client/server x send/receive) are the tests
  that would have caught a server that forgot to unmask.
}

interface

uses
   SysUtils, Classes, uTR4WTestFramework, uWebSocketFraming;

type
   // Feeds WSReadFrame from a byte array instead of a socket.
   TMemoryFrameReader = class(TObject)
   private
      FData: TBytes;
      FPos:  integer;
   public
      constructor Create(const AData: TBytes);
      // Matches TWSReadExactly.
      function ReadExactly(Count: integer; var Buf: TBytes): boolean;
      property Pos: integer read FPos;
   end;

   TWebSocketFramingTests = class(TTestCase)
   protected
      procedure CheckBytes(const Expected, Actual: TBytes; const Msg: string);

      // Encoding: the three length forms, both roles
      procedure Test_Encode_Short_Client_IsMasked;
      procedure Test_Encode_Short_Server_IsNotMasked;
      procedure Test_Encode_FinAndOpcode;
      procedure Test_Encode_16BitLengthForm;
      procedure Test_Encode_64BitLengthForm;
      procedure Test_Encode_EmptyPayload;
      procedure Test_Encode_ClientMaskActuallyScrambles;

      // Decoding round trips -- the four role combinations
      procedure Test_RoundTrip_ClientToServer;
      procedure Test_RoundTrip_ServerToClient;
      procedure Test_RoundTrip_16BitLengthForm;
      procedure Test_RoundTrip_64BitLengthForm;
      procedure Test_RoundTrip_TwoFramesBackToBack;

      // Decoding: the masking rules, in both directions
      procedure Test_Server_RejectsUnmaskedFrame;
      procedure Test_Client_RejectsMaskedFrame;

      // Decoding: hostile and truncated input
      procedure Test_OversizePayloadRejected;
      procedure Test_HugeLengthRejectedNotTruncated;
      procedure Test_TruncatedHeaderIsClosed;
      procedure Test_TruncatedPayloadIsClosed;
      procedure Test_ZeroMaxPayloadMeansUnlimited;

      // Reassembly
      procedure Test_Reassemble_SingleTextFrame;
      procedure Test_Reassemble_TwoFragments;
      procedure Test_Reassemble_ThreeFragments;
      procedure Test_Reassemble_ResetBetweenMessages;
      procedure Test_Reassemble_BinaryIsDropped;
      procedure Test_Reassemble_BinaryContinuationNotEmittedAsText;
      procedure Test_Reassemble_StrayContinuationIgnored;
      procedure Test_Reassemble_MaxMessageExceeded;
      procedure Test_Reassemble_Utf8AcrossFragments;

      // Text
      procedure Test_Utf8RoundTrip;
      procedure Test_Utf8EmptyIsEmpty;

      // Handshake
      procedure Test_AcceptKey_RFC6455Vector;
      procedure Test_AcceptKey_IsDeterministic;
      procedure Test_ClientKey_IsFreshEachTime;
      procedure Test_BuildRequest_HasRequiredHeaders;
      procedure Test_ParseRequest_Good;
      procedure Test_ParseRequest_ConnectionTokenList;
      procedure Test_ParseRequest_HeaderNamesAreCaseInsensitive;
      procedure Test_ParseRequest_NotAGet;
      procedure Test_ParseRequest_MissingKey;
      procedure Test_ParseRequest_MissingUpgrade;
      procedure Test_ParseRequest_BadVersion;
      procedure Test_ParseRequest_BlankVersionAccepted;
      procedure Test_ParseRequest_Empty;
      procedure Test_ParseRequest_IgnoresPathAndSubprotocol;
      procedure Test_BuildResponse_Is101WithAccept;
      procedure Test_Handshake_ClientAndServerAgree;

   public
      procedure RunAllTests; override;
   end;

implementation

{ --------------------------------------------------------------- helpers -- }

function MakeBytes(const Values: array of Byte): TBytes;
var
   i: integer;
begin
   SetLength(Result, Length(Values));
   for i := 0 to High(Values) do
      begin
      Result[i] := Values[i];
      end;
end;

// A payload of Count bytes with a recognisable, position-dependent pattern --
// a mask bug that XORs with the wrong offset shows up as a mismatch rather
// than surviving because every byte happened to be equal.
function PatternBytes(Count: integer): TBytes;
var
   i: integer;
begin
   SetLength(Result, Count);
   for i := 0 to Count - 1 do
      begin
      Result[i] := Byte((i * 7 + 13) and $FF);
      end;
end;

function Concat2(const A, B: TBytes): TBytes;
begin
   SetLength(Result, Length(A) + Length(B));
   if Length(A) > 0 then
      begin
      Move(A[0], Result[0], Length(A));
      end;
   if Length(B) > 0 then
      begin
      Move(B[0], Result[Length(A)], Length(B));
      end;
end;

function MakeFrame(FIN: boolean; Opcode: Byte; const Payload: TBytes): TWSFrame;
begin
   Result.FIN := FIN;
   Result.Opcode := Opcode;
   Result.Payload := Copy(Payload, 0, Length(Payload));
end;

{ ---------------------------------------------------- TMemoryFrameReader -- }

constructor TMemoryFrameReader.Create(const AData: TBytes);
begin
   inherited Create;
   FData := Copy(AData, 0, Length(AData));
   FPos := 0;
end;

function TMemoryFrameReader.ReadExactly(Count: integer; var Buf: TBytes): boolean;
begin
   SetLength(Buf, 0);
   if Count <= 0 then
      begin
      Result := True;
      Exit;
      end;
   if FPos + Count > Length(FData) then
      begin
      // Short read == the peer went away, which is what a socket does too.
      Result := False;
      Exit;
      end;
   SetLength(Buf, Count);
   Move(FData[FPos], Buf[0], Count);
   Inc(FPos, Count);
   Result := True;
end;

{ ------------------------------------------------ TWebSocketFramingTests -- }

procedure TWebSocketFramingTests.CheckBytes(const Expected, Actual: TBytes;
                                            const Msg: string);
var
   i: integer;
begin
   if Length(Expected) <> Length(Actual) then
      begin
      Check(False, Format('%s: length %d, expected %d',
                          [Msg, Length(Actual), Length(Expected)]));
      Exit;
      end;
   for i := 0 to High(Expected) do
      begin
      if Expected[i] <> Actual[i] then
         begin
         Check(False, Format('%s: byte %d is $%.2x, expected $%.2x',
                             [Msg, i, Actual[i], Expected[i]]));
         Exit;
         end;
      end;
   Check(True, Msg);
end;

{ ------------------------------------------------------------- encoding -- }

procedure TWebSocketFramingTests.Test_Encode_Short_Client_IsMasked;
var
   f: TBytes;
begin
   BeginTest('Test_Encode_Short_Client_IsMasked');
   f := WSEncodeFrame(wsrClient, WS_OP_TEXT, MakeBytes([65, 66, 67]));
   CheckTrue((f[1] and $80) <> 0, 'a client frame must set the MASK bit');
   CheckEquals(3, f[1] and $7F, 'payload length in the 7-bit field');
   // 2 header + 4 mask + 3 payload
   CheckEquals(9, Length(f), 'masked frame carries a 4-byte masking key');
end;

procedure TWebSocketFramingTests.Test_Encode_Short_Server_IsNotMasked;
var
   f: TBytes;
begin
   BeginTest('Test_Encode_Short_Server_IsNotMasked');
   f := WSEncodeFrame(wsrServer, WS_OP_TEXT, MakeBytes([65, 66, 67]));
   CheckTrue((f[1] and $80) = 0, 'RFC 6455 FORBIDS a server masking');
   CheckEquals(5, Length(f), 'unmasked frame has no masking key');
   CheckEquals(65, f[2], 'payload starts right after the 2-byte header');
   CheckEquals(67, f[4], 'payload is verbatim');
end;

procedure TWebSocketFramingTests.Test_Encode_FinAndOpcode;
var
   f: TBytes;
begin
   BeginTest('Test_Encode_FinAndOpcode');
   f := WSEncodeFrame(wsrServer, WS_OP_PING, nil);
   CheckEquals($89, f[0], 'FIN set plus opcode 9');
   f := WSEncodeFrame(wsrServer, WS_OP_CLOSE, nil);
   CheckEquals($88, f[0], 'FIN set plus opcode 8');
   f := WSEncodeFrame(wsrServer, WS_OP_TEXT, nil);
   CheckEquals($81, f[0], 'FIN set plus opcode 1');
end;

procedure TWebSocketFramingTests.Test_Encode_16BitLengthForm;
var
   f: TBytes;
begin
   BeginTest('Test_Encode_16BitLengthForm');
   // 126 is the first length that no longer fits the 7-bit field.
   f := WSEncodeFrame(wsrServer, WS_OP_TEXT, PatternBytes(126));
   CheckEquals(126, f[1] and $7F, 'the 7-bit field holds the 126 escape');
   CheckEquals(0, f[2], 'high byte of the 16-bit length');
   CheckEquals(126, f[3], 'low byte of the 16-bit length');
   CheckEquals(4 + 126, Length(f), 'header is 4 bytes in the 16-bit form');

   f := WSEncodeFrame(wsrServer, WS_OP_TEXT, PatternBytes(65535));
   CheckEquals(255, f[2], 'high byte at the top of the 16-bit form');
   CheckEquals(255, f[3], 'low byte at the top of the 16-bit form');
end;

procedure TWebSocketFramingTests.Test_Encode_64BitLengthForm;
var
   f: TBytes;
begin
   BeginTest('Test_Encode_64BitLengthForm');
   // 65536 is the first length that needs the 64-bit form.
   f := WSEncodeFrame(wsrServer, WS_OP_BINARY, PatternBytes(65536));
   CheckEquals(127, f[1] and $7F, 'the 7-bit field holds the 127 escape');
   CheckEquals(0, f[2], 'length is big-endian, so the top bytes are zero');
   CheckEquals(0, f[5], 'still zero four bytes in');
   CheckEquals(1, f[7], '65536 = $00010000, so byte 7 is $01');
   CheckEquals(0, f[8], '');
   CheckEquals(0, f[9], '');
   CheckEquals(10 + 65536, Length(f), 'header is 10 bytes in the 64-bit form');
end;

procedure TWebSocketFramingTests.Test_Encode_EmptyPayload;
var
   f: TBytes;
begin
   BeginTest('Test_Encode_EmptyPayload');
   // A CLOSE or PING with no payload is the common case and must not
   // allocate or index past the header.
   f := WSEncodeFrame(wsrServer, WS_OP_CLOSE, nil);
   CheckEquals(2, Length(f), 'server close frame is just the header');
   f := WSEncodeFrame(wsrClient, WS_OP_CLOSE, nil);
   CheckEquals(6, Length(f), 'client close frame is header plus mask key');
end;

procedure TWebSocketFramingTests.Test_Encode_ClientMaskActuallyScrambles;
var
   payload: TBytes;
   f:       TBytes;
   i:       integer;
   same:    integer;
begin
   BeginTest('Test_Encode_ClientMaskActuallyScrambles');
   // A mask of all zeroes would satisfy every round-trip test while leaving
   // the frame unmasked in practice.  Assert the bytes really changed.
   payload := PatternBytes(64);
   f := WSEncodeFrame(wsrClient, WS_OP_TEXT, payload);
   same := 0;
   for i := 0 to High(payload) do
      begin
      if f[2 + 4 + i] = payload[i] then
         begin
         Inc(same);
         end;
      end;
   // With a random 4-byte key, ~1 byte in 256 matches by chance; 64 identical
   // bytes means no masking happened at all.
   CheckTrue(same < 32, Format('%d of 64 payload bytes survived unmasked', [same]));
end;

{ ------------------------------------------------------- decode / roles -- }

procedure TWebSocketFramingTests.Test_RoundTrip_ClientToServer;
var
   payload: TBytes;
   rdr:     TMemoryFrameReader;
   frame:   TWSFrame;
   err:     string;
begin
   BeginTest('Test_RoundTrip_ClientToServer');
   payload := PatternBytes(40);
   rdr := TMemoryFrameReader.Create(WSEncodeFrame(wsrClient, WS_OP_TEXT, payload));
   try
      CheckTrue(WSReadFrame(rdr.ReadExactly, wsrServer, 0, frame, err) = wsReadOK,
                'a server must accept a masked client frame: ' + err);
      CheckTrue(frame.FIN, 'FIN survived');
      CheckEquals(WS_OP_TEXT, frame.Opcode, 'opcode survived');
      // The whole point: the server side UNMASKS, so callers never see the
      // scrambled bytes.
      CheckBytes(payload, frame.Payload, 'payload unmasked back to the original');
   finally
      rdr.Free;
   end;
end;

procedure TWebSocketFramingTests.Test_RoundTrip_ServerToClient;
var
   payload: TBytes;
   rdr:     TMemoryFrameReader;
   frame:   TWSFrame;
   err:     string;
begin
   BeginTest('Test_RoundTrip_ServerToClient');
   payload := PatternBytes(40);
   rdr := TMemoryFrameReader.Create(WSEncodeFrame(wsrServer, WS_OP_TEXT, payload));
   try
      CheckTrue(WSReadFrame(rdr.ReadExactly, wsrClient, 0, frame, err) = wsReadOK,
                'a client must accept an unmasked server frame: ' + err);
      CheckBytes(payload, frame.Payload, 'payload verbatim');
   finally
      rdr.Free;
   end;
end;

procedure TWebSocketFramingTests.Test_RoundTrip_16BitLengthForm;
var
   payload: TBytes;
   rdr:     TMemoryFrameReader;
   frame:   TWSFrame;
   err:     string;
begin
   BeginTest('Test_RoundTrip_16BitLengthForm');
   payload := PatternBytes(1000);
   rdr := TMemoryFrameReader.Create(WSEncodeFrame(wsrClient, WS_OP_TEXT, payload));
   try
      CheckTrue(WSReadFrame(rdr.ReadExactly, wsrServer, 0, frame, err) = wsReadOK, err);
      CheckEquals(1000, Length(frame.Payload), 'length decoded from the 16-bit form');
      CheckBytes(payload, frame.Payload, '1000-byte payload round trips');
   finally
      rdr.Free;
   end;
end;

procedure TWebSocketFramingTests.Test_RoundTrip_64BitLengthForm;
var
   payload: TBytes;
   rdr:     TMemoryFrameReader;
   frame:   TWSFrame;
   err:     string;
begin
   BeginTest('Test_RoundTrip_64BitLengthForm');
   payload := PatternBytes(70000);
   rdr := TMemoryFrameReader.Create(WSEncodeFrame(wsrClient, WS_OP_BINARY, payload));
   try
      CheckTrue(WSReadFrame(rdr.ReadExactly, wsrServer, 0, frame, err) = wsReadOK, err);
      CheckEquals(70000, Length(frame.Payload), 'length decoded from the 64-bit form');
      CheckBytes(payload, frame.Payload, '70000-byte payload round trips');
   finally
      rdr.Free;
   end;
end;

procedure TWebSocketFramingTests.Test_RoundTrip_TwoFramesBackToBack;
var
   rdr:   TMemoryFrameReader;
   frame: TWSFrame;
   err:   string;
   buf:   TBytes;
begin
   BeginTest('Test_RoundTrip_TwoFramesBackToBack');
   // A reader that miscounts a header leaves the stream misaligned, and the
   // symptom is the SECOND frame, not the first.
   buf := Concat2(WSEncodeFrame(wsrClient, WS_OP_TEXT, WSStringToUtf8Bytes('one;')),
                  WSEncodeFrame(wsrClient, WS_OP_TEXT, WSStringToUtf8Bytes('two;')));
   rdr := TMemoryFrameReader.Create(buf);
   try
      CheckTrue(WSReadFrame(rdr.ReadExactly, wsrServer, 0, frame, err) = wsReadOK, err);
      CheckEquals('one;', WSUtf8BytesToString(frame.Payload), 'first frame');
      CheckTrue(WSReadFrame(rdr.ReadExactly, wsrServer, 0, frame, err) = wsReadOK, err);
      CheckEquals('two;', WSUtf8BytesToString(frame.Payload), 'second frame, stream still aligned');
      CheckEquals(Length(buf), rdr.Pos, 'both frames consumed exactly');
   finally
      rdr.Free;
   end;
end;

procedure TWebSocketFramingTests.Test_Server_RejectsUnmaskedFrame;
var
   rdr:   TMemoryFrameReader;
   frame: TWSFrame;
   err:   string;
begin
   BeginTest('Test_Server_RejectsUnmaskedFrame');
   // Masking is what stops a scripted browser client poisoning intermediary
   // caches, so a server that tolerates unmasked frames defeats the point.
   rdr := TMemoryFrameReader.Create(WSEncodeFrame(wsrServer, WS_OP_TEXT, PatternBytes(8)));
   try
      CheckTrue(WSReadFrame(rdr.ReadExactly, wsrServer, 0, frame, err) = wsReadProtocolError,
                'a server must refuse an unmasked client frame');
      CheckTrue(Pos('UNMASKED', err) > 0, 'the error says which way it was wrong: ' + err);
   finally
      rdr.Free;
   end;
end;

procedure TWebSocketFramingTests.Test_Client_RejectsMaskedFrame;
var
   rdr:   TMemoryFrameReader;
   frame: TWSFrame;
   err:   string;
begin
   BeginTest('Test_Client_RejectsMaskedFrame');
   rdr := TMemoryFrameReader.Create(WSEncodeFrame(wsrClient, WS_OP_TEXT, PatternBytes(8)));
   try
      CheckTrue(WSReadFrame(rdr.ReadExactly, wsrClient, 0, frame, err) = wsReadProtocolError,
                'a client must refuse a masked server frame');
      CheckTrue(Pos('MASKED', err) > 0, 'the error names the violation: ' + err);
   finally
      rdr.Free;
   end;
end;

procedure TWebSocketFramingTests.Test_OversizePayloadRejected;
var
   rdr:   TMemoryFrameReader;
   frame: TWSFrame;
   err:   string;
begin
   BeginTest('Test_OversizePayloadRejected');
   rdr := TMemoryFrameReader.Create(WSEncodeFrame(wsrClient, WS_OP_TEXT, PatternBytes(1000)));
   try
      CheckTrue(WSReadFrame(rdr.ReadExactly, wsrServer, 500, frame, err) = wsReadProtocolError,
                'a payload over the cap must be refused, not truncated');
   finally
      rdr.Free;
   end;
end;

procedure TWebSocketFramingTests.Test_HugeLengthRejectedNotTruncated;
var
   rdr:   TMemoryFrameReader;
   frame: TWSFrame;
   err:   string;
   hdr:   TBytes;
begin
   BeginTest('Test_HugeLengthRejectedNotTruncated');
   // Hand-built header claiming $0000000100000000 (4 GiB) bytes, masked so it
   // is otherwise legal for a server to read.  The pre-extraction code cast
   // the length to a 32-bit integer, where this became 0 and the frame was
   // silently accepted as empty.  It must be refused outright.
   hdr := MakeBytes([$81, $FF,
                     $00, $00, $00, $01, $00, $00, $00, $00,
                     $01, $02, $03, $04]);
   rdr := TMemoryFrameReader.Create(hdr);
   try
      CheckTrue(WSReadFrame(rdr.ReadExactly, wsrServer, WS_DEFAULT_MAX_PAYLOAD,
                            frame, err) = wsReadProtocolError,
                'a 4 GiB length must be refused before allocating');
   finally
      rdr.Free;
   end;
end;

procedure TWebSocketFramingTests.Test_TruncatedHeaderIsClosed;
var
   rdr:   TMemoryFrameReader;
   frame: TWSFrame;
   err:   string;
begin
   BeginTest('Test_TruncatedHeaderIsClosed');
   // One byte is not a header.  That is a disconnect, not a protocol error --
   // the distinction matters because the transports log the two differently.
   rdr := TMemoryFrameReader.Create(MakeBytes([$81]));
   try
      CheckTrue(WSReadFrame(rdr.ReadExactly, wsrServer, 0, frame, err) = wsReadClosed,
                'a short header reads as end-of-stream');
   finally
      rdr.Free;
   end;
end;

procedure TWebSocketFramingTests.Test_TruncatedPayloadIsClosed;
var
   full:  TBytes;
   part:  TBytes;
   rdr:   TMemoryFrameReader;
   frame: TWSFrame;
   err:   string;
begin
   BeginTest('Test_TruncatedPayloadIsClosed');
   full := WSEncodeFrame(wsrClient, WS_OP_TEXT, PatternBytes(20));
   part := Copy(full, 0, Length(full) - 5);
   rdr := TMemoryFrameReader.Create(part);
   try
      CheckTrue(WSReadFrame(rdr.ReadExactly, wsrServer, 0, frame, err) = wsReadClosed,
                'a half-delivered payload reads as end-of-stream');
   finally
      rdr.Free;
   end;
end;

procedure TWebSocketFramingTests.Test_ZeroMaxPayloadMeansUnlimited;
var
   rdr:   TMemoryFrameReader;
   frame: TWSFrame;
   err:   string;
begin
   BeginTest('Test_ZeroMaxPayloadMeansUnlimited');
   rdr := TMemoryFrameReader.Create(WSEncodeFrame(wsrClient, WS_OP_TEXT, PatternBytes(70000)));
   try
      CheckTrue(WSReadFrame(rdr.ReadExactly, wsrServer, 0, frame, err) = wsReadOK,
                'MaxPayload 0 disables the cap');
      CheckEquals(70000, Length(frame.Payload), '');
   finally
      rdr.Free;
   end;
end;

{ ----------------------------------------------------------- reassembly -- }

procedure TWebSocketFramingTests.Test_Reassemble_SingleTextFrame;
var
   ra:   TWSReassembler;
   text: string;
   err:  string;
begin
   BeginTest('Test_Reassemble_SingleTextFrame');
   ra := TWSReassembler.Create;
   try
      CheckTrue(ra.Accept(MakeFrame(True, WS_OP_TEXT, WSStringToUtf8Bytes('vfo:0,0,14025000;')),
                          0, text, err) = wsAcceptText, 'an unfragmented TEXT frame is complete');
      CheckEquals('vfo:0,0,14025000;', text, '');
   finally
      ra.Free;
   end;
end;

procedure TWebSocketFramingTests.Test_Reassemble_TwoFragments;
var
   ra:   TWSReassembler;
   text: string;
   err:  string;
begin
   BeginTest('Test_Reassemble_TwoFragments');
   ra := TWSReassembler.Create;
   try
      CheckTrue(ra.Accept(MakeFrame(False, WS_OP_TEXT, WSStringToUtf8Bytes('vfo:0,')),
                          0, text, err) = wsAcceptNone, 'a non-final TEXT frame yields nothing yet');
      CheckTrue(ra.Accept(MakeFrame(True, WS_OP_CONTINUATION, WSStringToUtf8Bytes('0,14025000;')),
                          0, text, err) = wsAcceptText, 'the FIN continuation completes it');
      CheckEquals('vfo:0,0,14025000;', text, 'fragments joined in order');
   finally
      ra.Free;
   end;
end;

procedure TWebSocketFramingTests.Test_Reassemble_ThreeFragments;
var
   ra:   TWSReassembler;
   text: string;
   err:  string;
begin
   BeginTest('Test_Reassemble_ThreeFragments');
   ra := TWSReassembler.Create;
   try
      ra.Accept(MakeFrame(False, WS_OP_TEXT, WSStringToUtf8Bytes('aaa')), 0, text, err);
      ra.Accept(MakeFrame(False, WS_OP_CONTINUATION, WSStringToUtf8Bytes('bbb')), 0, text, err);
      CheckTrue(ra.Accept(MakeFrame(True, WS_OP_CONTINUATION, WSStringToUtf8Bytes('ccc')),
                          0, text, err) = wsAcceptText, '');
      CheckEquals('aaabbbccc', text, 'three fragments joined in order');
   finally
      ra.Free;
   end;
end;

procedure TWebSocketFramingTests.Test_Reassemble_ResetBetweenMessages;
var
   ra:   TWSReassembler;
   text: string;
   err:  string;
begin
   BeginTest('Test_Reassemble_ResetBetweenMessages');
   // A reassembler that forgets to clear its buffer prepends the previous
   // message to the next one -- and TCI would see a corrupt command.
   ra := TWSReassembler.Create;
   try
      ra.Accept(MakeFrame(False, WS_OP_TEXT, WSStringToUtf8Bytes('first')), 0, text, err);
      ra.Accept(MakeFrame(True, WS_OP_CONTINUATION, WSStringToUtf8Bytes('!')), 0, text, err);
      CheckEquals('first!', text, '');

      ra.Accept(MakeFrame(False, WS_OP_TEXT, WSStringToUtf8Bytes('second')), 0, text, err);
      CheckTrue(ra.Accept(MakeFrame(True, WS_OP_CONTINUATION, WSStringToUtf8Bytes('?')),
                          0, text, err) = wsAcceptText, '');
      CheckEquals('second?', text, 'the second message carries none of the first');
   finally
      ra.Free;
   end;
end;

procedure TWebSocketFramingTests.Test_Reassemble_BinaryIsDropped;
var
   ra:   TWSReassembler;
   text: string;
   err:  string;
begin
   BeginTest('Test_Reassemble_BinaryIsDropped');
   // TCI audio/IQ arrives as BINARY.  Neither the client nor the server
   // subscribes, so an unsolicited binary frame must be discarded rather than
   // handed up where it would be parsed as a command.
   ra := TWSReassembler.Create;
   try
      CheckTrue(ra.Accept(MakeFrame(True, WS_OP_BINARY, PatternBytes(64)),
                          0, text, err) = wsAcceptNone, 'BINARY never becomes a message');
      CheckEquals('', text, '');
   finally
      ra.Free;
   end;
end;

procedure TWebSocketFramingTests.Test_Reassemble_BinaryContinuationNotEmittedAsText;
var
   ra:   TWSReassembler;
   text: string;
   err:  string;
begin
   BeginTest('Test_Reassemble_BinaryContinuationNotEmittedAsText');
   // The subtle case: a FRAGMENTED binary message.  Its CONTINUATION tail
   // carries the FIN, and a reassembler that only checks FIN would emit the
   // audio bytes as if they were a TCI command.
   ra := TWSReassembler.Create;
   try
      ra.Accept(MakeFrame(False, WS_OP_BINARY, PatternBytes(32)), 0, text, err);
      CheckTrue(ra.Accept(MakeFrame(True, WS_OP_CONTINUATION, PatternBytes(32)),
                          0, text, err) = wsAcceptNone,
                'the tail of a dropped BINARY message must not surface as text');
   finally
      ra.Free;
   end;
end;

procedure TWebSocketFramingTests.Test_Reassemble_StrayContinuationIgnored;
var
   ra:   TWSReassembler;
   text: string;
   err:  string;
begin
   BeginTest('Test_Reassemble_StrayContinuationIgnored');
   ra := TWSReassembler.Create;
   try
      CheckTrue(ra.Accept(MakeFrame(True, WS_OP_CONTINUATION, WSStringToUtf8Bytes('orphan')),
                          0, text, err) = wsAcceptNone,
                'a CONTINUATION with nothing started is not the start of a message');
      CheckEquals('', text, '');
   finally
      ra.Free;
   end;
end;

procedure TWebSocketFramingTests.Test_Reassemble_MaxMessageExceeded;
var
   ra:   TWSReassembler;
   text: string;
   err:  string;
   res:  TWSAcceptResult;
   i:    integer;
begin
   BeginTest('Test_Reassemble_MaxMessageExceeded');
   // Each frame is under the per-frame cap; the ATTACK is the unbounded
   // number of them.  The reassembler has to hold its own ceiling.
   ra := TWSReassembler.Create;
   try
      res := ra.Accept(MakeFrame(False, WS_OP_TEXT, PatternBytes(100)), 250, text, err);
      CheckTrue(res = wsAcceptNone, '');
      res := ra.Accept(MakeFrame(False, WS_OP_CONTINUATION, PatternBytes(100)), 250, text, err);
      CheckTrue(res = wsAcceptNone, '');
      res := wsAcceptNone;
      for i := 1 to 3 do
         begin
         if res = wsAcceptNone then
            begin
            res := ra.Accept(MakeFrame(False, WS_OP_CONTINUATION, PatternBytes(100)), 250, text, err);
            end;
         end;
      CheckTrue(res = wsAcceptError, 'growing past the message cap is an error');
      CheckTrue(err <> '', 'the error is described: ' + err);
   finally
      ra.Free;
   end;
end;

procedure TWebSocketFramingTests.Test_Reassemble_Utf8AcrossFragments;
var
   ra:   TWSReassembler;
   text: string;
   err:  string;
   whole: TBytes;
   part1, part2: TBytes;
begin
   BeginTest('Test_Reassemble_Utf8AcrossFragments');
   // Decoding must happen on the JOINED bytes, never per fragment: a split
   // through the middle of a multi-byte character would otherwise produce two
   // replacement characters instead of one letter.
   whole := WSStringToUtf8Bytes('n' + Chr($E9) + 'e');   // e-acute in the middle
   part1 := Copy(whole, 0, 2);
   part2 := Copy(whole, 2, Length(whole) - 2);
   ra := TWSReassembler.Create;
   try
      ra.Accept(MakeFrame(False, WS_OP_TEXT, part1), 0, text, err);
      CheckTrue(ra.Accept(MakeFrame(True, WS_OP_CONTINUATION, part2), 0, text, err) = wsAcceptText, '');
      CheckEquals('n' + Chr($E9) + 'e', text, 'the split character survives reassembly');
   finally
      ra.Free;
   end;
end;

{ ----------------------------------------------------------------- text -- }

procedure TWebSocketFramingTests.Test_Utf8RoundTrip;
begin
   BeginTest('Test_Utf8RoundTrip');
   CheckEquals('trx:0,true;', WSUtf8BytesToString(WSStringToUtf8Bytes('trx:0,true;')), 'ASCII');
   CheckEquals('device:' + Chr($E9) + 'SDR;',
               WSUtf8BytesToString(WSStringToUtf8Bytes('device:' + Chr($E9) + 'SDR;')),
               'non-ASCII');
end;

procedure TWebSocketFramingTests.Test_Utf8EmptyIsEmpty;
begin
   BeginTest('Test_Utf8EmptyIsEmpty');
   CheckEquals('', WSUtf8BytesToString(nil), 'an empty payload decodes to an empty string');
   CheckEquals(0, Length(WSStringToUtf8Bytes('')), '');
end;

{ ------------------------------------------------------------ handshake -- }

procedure TWebSocketFramingTests.Test_AcceptKey_RFC6455Vector;
begin
   BeginTest('Test_AcceptKey_RFC6455Vector');
   // The worked example from RFC 6455 section 1.3.  This is the one value in
   // the whole handshake that a peer independently recomputes, so an error
   // here shows up as "handshake refused" and nothing else.
   CheckEquals('s3pPLMBiTxaQ9kYGzzhZRbK+xOo=',
               WSBuildAcceptKey('dGhlIHNhbXBsZSBub25jZQ=='),
               'RFC 6455 s1.3 vector');
end;

procedure TWebSocketFramingTests.Test_AcceptKey_IsDeterministic;
begin
   BeginTest('Test_AcceptKey_IsDeterministic');
   CheckEquals(WSBuildAcceptKey('abc123'), WSBuildAcceptKey('abc123'),
               'the digest depends only on the key');
   CheckTrue(WSBuildAcceptKey('abc123') <> WSBuildAcceptKey('abc124'),
             'a different key gives a different digest');
end;

procedure TWebSocketFramingTests.Test_ClientKey_IsFreshEachTime;
var
   a, b: string;
begin
   BeginTest('Test_ClientKey_IsFreshEachTime');
   a := WSMakeClientKey;
   b := WSMakeClientKey;
   CheckEquals(24, Length(a), '16 random bytes Base64 is 24 characters');
   CheckTrue(a <> b, 'a fixed nonce would let a replayed 101 pass validation');
end;

procedure TWebSocketFramingTests.Test_BuildRequest_HasRequiredHeaders;
var
   req: string;
begin
   BeginTest('Test_BuildRequest_HasRequiredHeaders');
   req := WSBuildHandshakeRequest('127.0.0.1', 50001, '/', 'KEYKEYKEY');
   CheckTrue(Pos('GET / HTTP/1.1'#13#10, req) = 1, 'request line first');
   CheckTrue(Pos('Host: 127.0.0.1:50001'#13#10, req) > 0, 'Host');
   CheckTrue(Pos('Upgrade: websocket'#13#10, req) > 0, 'Upgrade');
   CheckTrue(Pos('Connection: Upgrade'#13#10, req) > 0, 'Connection');
   CheckTrue(Pos('Sec-WebSocket-Key: KEYKEYKEY'#13#10, req) > 0, 'the nonce');
   CheckTrue(Pos('Sec-WebSocket-Version: 13'#13#10, req) > 0, 'version 13');
   CheckTrue(Copy(req, Length(req) - 3, 4) = #13#10#13#10, 'headers end with a blank line');
end;

procedure TWebSocketFramingTests.Test_ParseRequest_Good;
var
   lines: TStringList;
   key, err: string;
begin
   BeginTest('Test_ParseRequest_Good');
   lines := TStringList.Create;
   try
      lines.Add('GET / HTTP/1.1');
      lines.Add('Host: 127.0.0.1:50001');
      lines.Add('Upgrade: websocket');
      lines.Add('Connection: Upgrade');
      lines.Add('Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==');
      lines.Add('Sec-WebSocket-Version: 13');
      lines.Add('');
      CheckTrue(WSParseHandshakeRequest(lines, key, err), 'a well-formed request: ' + err);
      CheckEquals('dGhlIHNhbXBsZSBub25jZQ==', key, 'the key is extracted verbatim');
   finally
      lines.Free;
   end;
end;

procedure TWebSocketFramingTests.Test_ParseRequest_ConnectionTokenList;
var
   lines: TStringList;
   key, err: string;
begin
   BeginTest('Test_ParseRequest_ConnectionTokenList');
   // Connection is a comma-separated token list.  Browsers and several TCI
   // clients send "keep-alive, Upgrade", so an equality test on the whole
   // header value refuses a perfectly legal request.
   lines := TStringList.Create;
   try
      lines.Add('GET /tci HTTP/1.1');
      lines.Add('Upgrade: websocket');
      lines.Add('Connection: keep-alive, Upgrade');
      lines.Add('Sec-WebSocket-Key: abcd');
      lines.Add('Sec-WebSocket-Version: 13');
      CheckTrue(WSParseHandshakeRequest(lines, key, err),
                'the Upgrade TOKEN is what matters, not the whole value: ' + err);
   finally
      lines.Free;
   end;
end;

procedure TWebSocketFramingTests.Test_ParseRequest_HeaderNamesAreCaseInsensitive;
var
   lines: TStringList;
   key, err: string;
begin
   BeginTest('Test_ParseRequest_HeaderNamesAreCaseInsensitive');
   lines := TStringList.Create;
   try
      lines.Add('GET / HTTP/1.1');
      lines.Add('upgrade: WebSocket');
      lines.Add('CONNECTION: upgrade');
      lines.Add('sec-websocket-key: abcd');
      CheckTrue(WSParseHandshakeRequest(lines, key, err),
                'HTTP header names are case insensitive: ' + err);
      CheckEquals('abcd', key, '');
   finally
      lines.Free;
   end;
end;

procedure TWebSocketFramingTests.Test_ParseRequest_NotAGet;
var
   lines: TStringList;
   key, err: string;
begin
   BeginTest('Test_ParseRequest_NotAGet');
   lines := TStringList.Create;
   try
      lines.Add('POST / HTTP/1.1');
      lines.Add('Upgrade: websocket');
      lines.Add('Connection: Upgrade');
      lines.Add('Sec-WebSocket-Key: abcd');
      CheckFalse(WSParseHandshakeRequest(lines, key, err), 'only GET can upgrade');
   finally
      lines.Free;
   end;
end;

procedure TWebSocketFramingTests.Test_ParseRequest_MissingKey;
var
   lines: TStringList;
   key, err: string;
begin
   BeginTest('Test_ParseRequest_MissingKey');
   lines := TStringList.Create;
   try
      lines.Add('GET / HTTP/1.1');
      lines.Add('Upgrade: websocket');
      lines.Add('Connection: Upgrade');
      CheckFalse(WSParseHandshakeRequest(lines, key, err),
                 'without a key there is no digest to answer with');
   finally
      lines.Free;
   end;
end;

procedure TWebSocketFramingTests.Test_ParseRequest_MissingUpgrade;
var
   lines: TStringList;
   key, err: string;
begin
   BeginTest('Test_ParseRequest_MissingUpgrade');
   // A plain HTTP GET must NOT be upgraded -- otherwise a browser hitting the
   // port by accident becomes a half-open WebSocket session.
   lines := TStringList.Create;
   try
      lines.Add('GET / HTTP/1.1');
      lines.Add('Host: 127.0.0.1');
      lines.Add('Sec-WebSocket-Key: abcd');
      CheckFalse(WSParseHandshakeRequest(lines, key, err), 'no Upgrade header');
   finally
      lines.Free;
   end;
end;

procedure TWebSocketFramingTests.Test_ParseRequest_BadVersion;
var
   lines: TStringList;
   key, err: string;
begin
   BeginTest('Test_ParseRequest_BadVersion');
   lines := TStringList.Create;
   try
      lines.Add('GET / HTTP/1.1');
      lines.Add('Upgrade: websocket');
      lines.Add('Connection: Upgrade');
      lines.Add('Sec-WebSocket-Key: abcd');
      lines.Add('Sec-WebSocket-Version: 8');
      CheckFalse(WSParseHandshakeRequest(lines, key, err),
                 'version 8 is hybi-08 framing, which we do not speak');
   finally
      lines.Free;
   end;
end;

procedure TWebSocketFramingTests.Test_ParseRequest_BlankVersionAccepted;
var
   lines: TStringList;
   key, err: string;
begin
   BeginTest('Test_ParseRequest_BlankVersionAccepted');
   // Minimal embedded clients omit the version header.  Refusing them buys
   // nothing: if they then speak the wrong framing, the frame decode rejects
   // it anyway with a better message.
   lines := TStringList.Create;
   try
      lines.Add('GET / HTTP/1.1');
      lines.Add('Upgrade: websocket');
      lines.Add('Connection: Upgrade');
      lines.Add('Sec-WebSocket-Key: abcd');
      CheckTrue(WSParseHandshakeRequest(lines, key, err), err);
   finally
      lines.Free;
   end;
end;

procedure TWebSocketFramingTests.Test_ParseRequest_Empty;
var
   lines: TStringList;
   key, err: string;
begin
   BeginTest('Test_ParseRequest_Empty');
   lines := TStringList.Create;
   try
      CheckFalse(WSParseHandshakeRequest(lines, key, err), 'no lines at all');
      CheckTrue(err <> '', 'and it says so');
   finally
      lines.Free;
   end;
end;

procedure TWebSocketFramingTests.Test_ParseRequest_IgnoresPathAndSubprotocol;
var
   lines: TStringList;
   key, err: string;
begin
   BeginTest('Test_ParseRequest_IgnoresPathAndSubprotocol');
   // Deliberate: the reference TCI server accepts any path and negotiates no
   // subprotocol, and real clients connect to '/', '/tci' and worse.  Being
   // stricter than the thing we are compatible with only breaks clients.
   lines := TStringList.Create;
   try
      lines.Add('GET /some/odd/path?x=1 HTTP/1.1');
      lines.Add('Upgrade: websocket');
      lines.Add('Connection: Upgrade');
      lines.Add('Sec-WebSocket-Protocol: something-we-do-not-offer');
      lines.Add('Sec-WebSocket-Key: abcd');
      CheckTrue(WSParseHandshakeRequest(lines, key, err),
                'path and subprotocol are deliberately not checked: ' + err);
   finally
      lines.Free;
   end;
end;

procedure TWebSocketFramingTests.Test_BuildResponse_Is101WithAccept;
var
   resp: string;
begin
   BeginTest('Test_BuildResponse_Is101WithAccept');
   resp := WSBuildHandshakeResponse('dGhlIHNhbXBsZSBub25jZQ==');
   CheckTrue(Pos('HTTP/1.1 101 Switching Protocols'#13#10, resp) = 1, 'status line');
   CheckTrue(Pos('Upgrade: websocket'#13#10, resp) > 0, 'Upgrade');
   CheckTrue(Pos('Connection: Upgrade'#13#10, resp) > 0, 'Connection');
   CheckTrue(Pos('Sec-WebSocket-Accept: s3pPLMBiTxaQ9kYGzzhZRbK+xOo='#13#10, resp) > 0,
             'the computed digest, not the key');
   CheckTrue(Copy(resp, Length(resp) - 3, 4) = #13#10#13#10, 'ends with a blank line');
end;

procedure TWebSocketFramingTests.Test_Handshake_ClientAndServerAgree;
var
   lines: TStringList;
   req:   string;
   clientKey, parsedKey, err: string;
   resp:  string;
   sl:    TStringList;
begin
   BeginTest('Test_Handshake_ClientAndServerAgree');
   // The whole loop end to end: our client builds a request, our server
   // parses it and answers, and the digest the client would compare against
   // is the digest the server sent.  This is what the loopback integration
   // test exercises over a real socket.
   clientKey := WSMakeClientKey;
   req := WSBuildHandshakeRequest('127.0.0.1', 50001, '/', clientKey);

   sl := TStringList.Create;
   lines := TStringList.Create;
   try
      sl.Text := req;
      lines.Assign(sl);
      CheckTrue(WSParseHandshakeRequest(lines, parsedKey, err),
                'the server accepts our own client request: ' + err);
      CheckEquals(clientKey, parsedKey, 'the nonce survives the round trip');

      resp := WSBuildHandshakeResponse(parsedKey);
      CheckTrue(Pos('Sec-WebSocket-Accept: ' + WSBuildAcceptKey(clientKey), resp) > 0,
                'the client would accept the digest the server sent');
   finally
      lines.Free;
      sl.Free;
   end;
end;

procedure TWebSocketFramingTests.RunAllTests;
begin
   Test_Encode_Short_Client_IsMasked;
   Test_Encode_Short_Server_IsNotMasked;
   Test_Encode_FinAndOpcode;
   Test_Encode_16BitLengthForm;
   Test_Encode_64BitLengthForm;
   Test_Encode_EmptyPayload;
   Test_Encode_ClientMaskActuallyScrambles;

   Test_RoundTrip_ClientToServer;
   Test_RoundTrip_ServerToClient;
   Test_RoundTrip_16BitLengthForm;
   Test_RoundTrip_64BitLengthForm;
   Test_RoundTrip_TwoFramesBackToBack;

   Test_Server_RejectsUnmaskedFrame;
   Test_Client_RejectsMaskedFrame;

   Test_OversizePayloadRejected;
   Test_HugeLengthRejectedNotTruncated;
   Test_TruncatedHeaderIsClosed;
   Test_TruncatedPayloadIsClosed;
   Test_ZeroMaxPayloadMeansUnlimited;

   Test_Reassemble_SingleTextFrame;
   Test_Reassemble_TwoFragments;
   Test_Reassemble_ThreeFragments;
   Test_Reassemble_ResetBetweenMessages;
   Test_Reassemble_BinaryIsDropped;
   Test_Reassemble_BinaryContinuationNotEmittedAsText;
   Test_Reassemble_StrayContinuationIgnored;
   Test_Reassemble_MaxMessageExceeded;
   Test_Reassemble_Utf8AcrossFragments;

   Test_Utf8RoundTrip;
   Test_Utf8EmptyIsEmpty;

   Test_AcceptKey_RFC6455Vector;
   Test_AcceptKey_IsDeterministic;
   Test_ClientKey_IsFreshEachTime;
   Test_BuildRequest_HasRequiredHeaders;
   Test_ParseRequest_Good;
   Test_ParseRequest_ConnectionTokenList;
   Test_ParseRequest_HeaderNamesAreCaseInsensitive;
   Test_ParseRequest_NotAGet;
   Test_ParseRequest_MissingKey;
   Test_ParseRequest_MissingUpgrade;
   Test_ParseRequest_BadVersion;
   Test_ParseRequest_BlankVersionAccepted;
   Test_ParseRequest_Empty;
   Test_ParseRequest_IgnoresPathAndSubprotocol;
   Test_BuildResponse_Is101WithAccept;
   Test_Handshake_ClientAndServerAgree;
end;

end.
