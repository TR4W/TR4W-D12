unit uTestN1MMLogEnvelope;
{$I ..\..\src\tr4w.inc}

(*
   THE N1MM LOG ENVELOPE, FRAMING ONLY (issue 45).

   uN1MMLogEnvelope turns bytes into the ADIF text of one Log command.  These
   tests pin the byte count as authoritative, a TCP stream delivered in
   fragments and in one lump, the refusals (other command, two records,
   garbage, oversize) and the UDP one-datagram form.  No socket is opened.
*)

interface

uses
   SysUtils,
   uTR4WTestFramework;

type
   TN1MMLogEnvelopeTests = class(TTestCase)
   private
      procedure Test_TheDocumentedShapeParses;
      procedure Test_TheByteCountIsAuthoritative;
      procedure Test_TagNamesAreCaseInsensitive;
      procedure Test_Utf8CountsBytesNotCharacters;
      procedure Test_AnotherCommandIsIgnoredAndTheStreamStaysInStep;
      procedure Test_TwoRecordsInOneEnvelopeAreRefused;
      procedure Test_GarbageIsMalformed;
      procedure Test_OversizeLengthIsRefused;
      procedure Test_TcpFragmentsAreReassembled;
      procedure Test_TcpCoalescedEnvelopesComeOutOneByOne;
      procedure Test_TcpBufferIsBounded;
      procedure Test_DatagramMustBeExactlyOneEnvelope;
   public
      procedure RunAllTests; override;
   end;

implementation

uses
   uN1MMLogEnvelope;

const
   SAMPLE_ADIF =
      '<Band:3>20M<Call:5>M4HXM<Freq:6>14.076<Mode:4>JT65' +
      '<QSO_DATE:8>20110419<TIME_ON:6>184000<RST_Rcvd:3>-03' +
      '<RST_Sent:3>-07<TX_PWR:4>20.0<EOR>';

(* Build an envelope the way a sender does: the count is the byte length of
  the payload. *)
function Envelope(const aCommand: RawByteString;
                  const aPayload: RawByteString): RawByteString;
begin
   Result := '<command:' + RawByteString(IntToStr(Length(aCommand))) + '>' +
      aCommand + '<parameters:' + RawByteString(IntToStr(Length(aPayload))) +
      '>' + aPayload;
end;

procedure TN1MMLogEnvelopeTests.Test_TheDocumentedShapeParses;
var
   pos: integer;
   adif: string;
   why: string;
begin
   BeginTest('Test_TheDocumentedShapeParses');
   pos := 1;
   CheckEquals(Ord(esLog),
      Ord(N1MMReadEnvelope(Envelope('Log', SAMPLE_ADIF), pos, adif, why)),
      'status');
   CheckEquals(SAMPLE_ADIF, adif, 'the payload is handed over untouched');
   CheckEquals(Length(Envelope('Log', SAMPLE_ADIF)) + 1, pos,
      'the whole envelope is consumed');
end;

procedure TN1MMLogEnvelopeTests.Test_TheByteCountIsAuthoritative;
var
   pos: integer;
   adif: string;
   why: string;
   text: RawByteString;
begin
   BeginTest('Test_TheByteCountIsAuthoritative');
   (* A count shorter than the text: only that many bytes are the payload; the
     rest is the start of the next thing and is not part of this ADIF. *)
   text := '<command:3>Log<parameters:5><Call:5>K1ABC';
   pos := 1;
   CheckEquals(Ord(esLog), Ord(N1MMReadEnvelope(text, pos, adif, why)),
      'short count status');
   CheckEquals('<Call', adif, 'exactly 5 bytes');
   CheckEquals(Length(text) - 7, pos, 'the unread tail stays in the buffer');

   (* A count longer than what has arrived is not an error, it is "wait". *)
   text := '<command:3>Log<parameters:50><Call:5>K1ABC<EOR>';
   pos := 1;
   CheckEquals(Ord(esNeedMore), Ord(N1MMReadEnvelope(text, pos, adif, why)),
      'long count status');
   CheckEquals(1, pos, 'nothing consumed while waiting');
end;

procedure TN1MMLogEnvelopeTests.Test_TagNamesAreCaseInsensitive;
var
   pos: integer;
   adif: string;
   why: string;
   text: RawByteString;
begin
   BeginTest('Test_TagNamesAreCaseInsensitive');
   text := '<COMMAND:3>LOG<Parameters:18><Call:5>K1ABC<EOR>';
   pos := 1;
   CheckEquals(Ord(esLog), Ord(N1MMReadEnvelope(text, pos, adif, why)),
      'upper and mixed case, and the command value');
   CheckEquals('<Call:5>K1ABC<EOR>', adif, 'payload');
end;

procedure TN1MMLogEnvelopeTests.Test_Utf8CountsBytesNotCharacters;
var
   pos: integer;
   adif: string;
   why: string;
   payload: RawByteString;
begin
   BeginTest('Test_Utf8CountsBytesNotCharacters');
   (* NAME "Jose" with an acute e: 5 characters, 6 bytes as UTF-8. *)
   (* The two bytes are built as AnsiChars: a #$C3 in a string literal is the
     character U+00C3 and would be converted to its own two UTF-8 bytes. *)
   payload := RawByteString('<Name:5>Jos') + AnsiChar(#$C3) + AnsiChar(#$A9) +
      '<EOR>';
   pos := 1;
   CheckEquals(Ord(esLog), Ord(N1MMReadEnvelope(Envelope('Log', payload),
      pos, adif, why)), 'status');
   CheckEquals(Length('<Name:5>Jos') + 1 + Length('<EOR>'), Length(adif),
      'one character for the two bytes of the accented letter');
   CheckEquals(Ord(#$E9), Ord(adif[12]), 'decoded, not left as two bytes');
end;

procedure TN1MMLogEnvelopeTests.Test_AnotherCommandIsIgnoredAndTheStreamStaysInStep;
var
   framer: TN1MMLogFramer;
   adif: string;
   why: string;
begin
   BeginTest('Test_AnotherCommandIsIgnoredAndTheStreamStaysInStep');
   framer := TN1MMLogFramer.Create;
   try
      CheckTrue(framer.Feed(Envelope('Ping', 'x') +
         Envelope('Log', SAMPLE_ADIF)), 'feed');
      CheckEquals(Ord(esIgnored), Ord(framer.Next(adif, why)),
         'other command');
      CheckTrue(why <> '', 'the reason is given');
      CheckEquals(Ord(esLog), Ord(framer.Next(adif, why)),
         'the next envelope is still found');
      CheckEquals(SAMPLE_ADIF, adif, 'payload');
      CheckEquals(Ord(esNeedMore), Ord(framer.Next(adif, why)), 'drained');
   finally
      framer.Free;
   end;
end;

procedure TN1MMLogEnvelopeTests.Test_TwoRecordsInOneEnvelopeAreRefused;
var
   framer: TN1MMLogFramer;
   adif: string;
   why: string;
begin
   BeginTest('Test_TwoRecordsInOneEnvelopeAreRefused');
   framer := TN1MMLogFramer.Create;
   try
      CheckTrue(framer.Feed(Envelope('Log', SAMPLE_ADIF + SAMPLE_ADIF) +
         Envelope('Log', SAMPLE_ADIF)), 'feed');
      CheckEquals(Ord(esMalformed), Ord(framer.Next(adif, why)),
         'two <EOR> in one payload');
      CheckEquals('', adif, 'nothing is handed on');
      CheckEquals(Ord(esLog), Ord(framer.Next(adif, why)),
         'only the bad envelope was consumed');
   finally
      framer.Free;
   end;
end;

procedure TN1MMLogEnvelopeTests.Test_GarbageIsMalformed;
var
   pos: integer;
   adif: string;
   why: string;
begin
   BeginTest('Test_GarbageIsMalformed');
   pos := 1;
   CheckEquals(Ord(esMalformed),
      Ord(N1MMReadEnvelope('hello world', pos, adif, why)), 'no tag');
   CheckTrue(why <> '', 'reason: no tag');
   pos := 1;
   CheckEquals(Ord(esMalformed),
      Ord(N1MMReadEnvelope('<command:x>Log', pos, adif, why)),
      'length is not a number');
   pos := 1;
   CheckEquals(Ord(esMalformed),
      Ord(N1MMReadEnvelope('<command>Log', pos, adif, why)),
      'no length');
   pos := 1;
   CheckEquals(Ord(esMalformed),
      Ord(N1MMReadEnvelope('<call:5>K1ABC', pos, adif, why)),
      'not the command tag first');
   pos := 1;
   CheckEquals(Ord(esMalformed),
      Ord(N1MMReadEnvelope('<command:3>Log<call:5>K1ABC', pos, adif, why)),
      'not the parameters tag second');
   pos := 1;
   CheckEquals(Ord(esMalformed),
      Ord(N1MMReadEnvelope(Envelope('Log', ''), pos, adif, why)),
      'empty payload');
end;

procedure TN1MMLogEnvelopeTests.Test_OversizeLengthIsRefused;
var
   pos: integer;
   adif: string;
   why: string;
begin
   BeginTest('Test_OversizeLengthIsRefused');
   pos := 1;
   CheckEquals(Ord(esMalformed),
      Ord(N1MMReadEnvelope('<command:3>Log<parameters:999999>', pos, adif,
         why)), 'six digits over the payload limit');
   pos := 1;
   CheckEquals(Ord(esMalformed),
      Ord(N1MMReadEnvelope('<command:3>Log<parameters:99999999>', pos, adif,
         why)), 'more digits than a length may have');
end;

procedure TN1MMLogEnvelopeTests.Test_TcpFragmentsAreReassembled;
var
   framer: TN1MMLogFramer;
   adif: string;
   why: string;
   wire: RawByteString;
   i: integer;
   got: integer;
begin
   BeginTest('Test_TcpFragmentsAreReassembled');
   wire := Envelope('Log', SAMPLE_ADIF);
   framer := TN1MMLogFramer.Create;
   try
      got := 0;
      (* One byte at a time: the worst a stream can do. *)
      for i := 1 to Length(wire) do
         begin
         CheckTrue(framer.Feed(Copy(wire, i, 1)), 'feed ' + IntToStr(i));
         if framer.Next(adif, why) = esLog then
            begin
            Inc(got);
            CheckEquals(SAMPLE_ADIF, adif, 'payload');
            CheckEquals(Length(wire), i, 'delivered on the LAST byte only');
            end;
         end;
      CheckEquals(1, got, 'exactly one envelope came out');
   finally
      framer.Free;
   end;
end;

procedure TN1MMLogEnvelopeTests.Test_TcpCoalescedEnvelopesComeOutOneByOne;
var
   framer: TN1MMLogFramer;
   adif: string;
   why: string;
   wire: RawByteString;
   got: integer;
begin
   BeginTest('Test_TcpCoalescedEnvelopesComeOutOneByOne');
   wire := Envelope('Log', SAMPLE_ADIF) + #13#10 +
      Envelope('Log', SAMPLE_ADIF) + #13#10 +
      Copy(Envelope('Log', SAMPLE_ADIF), 1, 20);
   framer := TN1MMLogFramer.Create;
   try
      CheckTrue(framer.Feed(wire), 'feed');
      got := 0;
      while framer.Next(adif, why) = esLog do
         begin
         Inc(got);
         end;
      CheckEquals(2, got, 'two whole envelopes');
      CheckEquals(22, framer.PendingBytes,
         'the line break and the 20 bytes of the third are held, not lost');
      (* The rest of the third arrives. *)
      CheckTrue(framer.Feed(Copy(Envelope('Log', SAMPLE_ADIF), 21,
         Length(wire))), 'feed rest');
      CheckEquals(Ord(esLog), Ord(framer.Next(adif, why)), 'third completes');
   finally
      framer.Free;
   end;
end;

procedure TN1MMLogEnvelopeTests.Test_TcpBufferIsBounded;
var
   framer: TN1MMLogFramer;
   chunk: RawByteString;
   i: integer;
   refused: Boolean;
begin
   BeginTest('Test_TcpBufferIsBounded');
   framer := TN1MMLogFramer.Create;
   try
      (* An envelope that promises 60000 bytes and then never finishes, over
        and over: the buffer must refuse to grow past its ceiling. *)
      chunk := RawByteString('<command:3>Log<parameters:60000>') +
         RawByteString(StringOfChar('A', 3000));
      refused := False;
      for i := 1 to 100 do
         begin
         if not framer.Feed(chunk) then
            begin
            refused := True;
            Break;
            end;
         end;
      CheckTrue(refused, 'Feed refuses past N1MM_LOG_MAX_BUFFER');
      CheckEquals(0, framer.PendingBytes, 'and the buffer is emptied');
   finally
      framer.Free;
   end;
end;

procedure TN1MMLogEnvelopeTests.Test_DatagramMustBeExactlyOneEnvelope;
var
   adif: string;
   why: string;
begin
   BeginTest('Test_DatagramMustBeExactlyOneEnvelope');
   CheckTrue(N1MMParseDatagram(Envelope('Log', SAMPLE_ADIF), adif, why),
      'the documented datagram');
   CheckEquals(SAMPLE_ADIF, adif, 'payload');
   CheckTrue(N1MMParseDatagram(Envelope('Log', SAMPLE_ADIF) + #13#10, adif,
      why), 'a trailing line break is allowed');
   CheckFalse(N1MMParseDatagram(Envelope('Log', SAMPLE_ADIF) +
      Envelope('Log', SAMPLE_ADIF), adif, why), 'two envelopes');
   CheckEquals('bytes after the envelope', why, 'reason: two envelopes');
   CheckFalse(N1MMParseDatagram(Copy(Envelope('Log', SAMPLE_ADIF), 1, 40),
      adif, why), 'truncated');
   CheckEquals('truncated datagram', why, 'reason: truncated');
   CheckFalse(N1MMParseDatagram('', adif, why), 'empty');
   CheckFalse(N1MMParseDatagram(Envelope('Ping', 'x'), adif, why),
      'not the Log command');
   CheckFalse(N1MMParseDatagram('not an envelope', adif, why), 'garbage');
end;

procedure TN1MMLogEnvelopeTests.RunAllTests;
begin
   Test_TheDocumentedShapeParses;
   Test_TheByteCountIsAuthoritative;
   Test_TagNamesAreCaseInsensitive;
   Test_Utf8CountsBytesNotCharacters;
   Test_AnotherCommandIsIgnoredAndTheStreamStaysInStep;
   Test_TwoRecordsInOneEnvelopeAreRefused;
   Test_GarbageIsMalformed;
   Test_OversizeLengthIsRefused;
   Test_TcpFragmentsAreReassembled;
   Test_TcpCoalescedEnvelopesComeOutOneByOne;
   Test_TcpBufferIsBounded;
   Test_DatagramMustBeExactlyOneEnvelope;
end;

end.
