unit uTestN1MMLogListener;
{$I ..\..\src\tr4w.inc}

(*
   THE N1MM LOG LISTENER WITHOUT A SOCKET (issue 45).

   TN1MMLogListener.HandleDatagram and HandleStreamBytes are the whole of what
   Indy's UDP and TCP handlers do; RecordHook replaces the hand-off to the main
   thread, so these tests see exactly which records a socket would pass on.
   Pinned: one record per datagram, a datagram holding two envelopes or two
   records is REFUSED (the framing's rule, not loosened here), a TCP stream
   delivered a byte at a time, coalesced envelopes in order, malformed input
   counted and logged, the buffer limit, and the two small pure rules (the
   blank address, the unknown-mode fallback to Digital).
*)

interface

uses
   Classes, SysUtils,
   uTR4WTestFramework;

type
   (* Collects what the listener would hand to the main thread. *)
   TRecordSink = class(TObject)
   public
      Records: TStringList;
      constructor Create;
      destructor Destroy; override;
      procedure Take(const aAdif: string);
   end;

   TN1MMLogListenerTests = class(TTestCase)
   private
      procedure Test_ADatagramBecomesOneRecord;
      procedure Test_AMalformedDatagramIsRefusedAndCounted;
      procedure Test_TwoEnvelopesInOneDatagramAreRefused;
      procedure Test_TwoRecordsInOneEnvelopeAreRefused;
      procedure Test_AStreamDeliveredAByteAtATime;
      procedure Test_CoalescedStreamEnvelopesKeepTheirOrder;
      procedure Test_AnotherCommandIsIgnoredNotCounted;
      procedure Test_AMalformedStreamIsCounted;
      procedure Test_TheStreamBufferLimitSaysDropTheConnection;
      procedure Test_ABlankAddressIsTheLoopback;
      procedure Test_AnUnknownModeFallsBackToDigital;
      procedure Test_BytesAreCopiedAsBytes;
   public
      procedure RunAllTests; override;
   end;

implementation

uses
   IdGlobal,
   VC,
   uN1MMLogEnvelope,
   uN1MMLogListener,
   uInboundQso;

const
   ADIF_ONE = '<Call:5>K1ABC<Band:3>20M<Mode:3>FT8<EOR>';
   ADIF_TWO = '<Call:5>W2XYZ<Band:3>40M<Mode:3>FT8<EOR>';

constructor TRecordSink.Create;
begin
   inherited Create;
   Records := TStringList.Create;
end;

destructor TRecordSink.Destroy;
begin
   Records.Free;
   inherited Destroy;
end;

procedure TRecordSink.Take(const aAdif: string);
begin
   Records.Add(aAdif);
end;

(* Build an envelope the way a sender does: the count is the byte length of the
  payload. *)
function Envelope(const aCommand: RawByteString;
                  const aPayload: RawByteString): RawByteString;
begin
   Result := '<command:' + RawByteString(IntToStr(Length(aCommand))) + '>' +
      aCommand + '<parameters:' + RawByteString(IntToStr(Length(aPayload))) +
      '>' + aPayload;
end;

procedure TN1MMLogListenerTests.Test_ADatagramBecomesOneRecord;
var
   sink: TRecordSink;
   listener: TN1MMLogListener;
begin
   BeginTest('Test_ADatagramBecomesOneRecord');
   sink := TRecordSink.Create;
   listener := TN1MMLogListener.Create;
   try
      listener.RecordHook := sink.Take;
      listener.HandleDatagram(Envelope('Log', ADIF_ONE), '127.0.0.1');
      CheckEquals(1, sink.Records.Count, 'one record handed on');
      CheckEquals(ADIF_ONE, sink.Records[0], 'the ADIF is untouched');
      CheckEquals(1, listener.Received, 'counted');
      CheckEquals(0, listener.Rejected, 'nothing refused');
   finally
      listener.Free;
      sink.Free;
   end;
end;

procedure TN1MMLogListenerTests.Test_AMalformedDatagramIsRefusedAndCounted;
var
   sink: TRecordSink;
   listener: TN1MMLogListener;
begin
   BeginTest('Test_AMalformedDatagramIsRefusedAndCounted');
   sink := TRecordSink.Create;
   listener := TN1MMLogListener.Create;
   try
      listener.RecordHook := sink.Take;
      listener.HandleDatagram('not an envelope', '127.0.0.1');
      listener.HandleDatagram('<command:3>Log<parameters:99><Call:5>K1', '127.0.0.1');
      CheckEquals(0, sink.Records.Count, 'nothing handed on');
      CheckEquals(2, listener.Rejected, 'garbage and a truncated datagram');
   finally
      listener.Free;
      sink.Free;
   end;
end;

procedure TN1MMLogListenerTests.Test_TwoEnvelopesInOneDatagramAreRefused;
var
   sink: TRecordSink;
   listener: TN1MMLogListener;
begin
   BeginTest('Test_TwoEnvelopesInOneDatagramAreRefused');
   sink := TRecordSink.Create;
   listener := TN1MMLogListener.Create;
   try
      listener.RecordHook := sink.Take;
      (* uN1MMLogEnvelope's rule: one datagram is ONE envelope, so bytes after it
        are an error, and neither record is logged -- a sender that packs two
        gets told so in the log rather than a silent half. *)
      listener.HandleDatagram(Envelope('Log', ADIF_ONE) + Envelope('Log', ADIF_TWO),
                              '127.0.0.1');
      CheckEquals(0, sink.Records.Count, 'neither record is passed on');
      CheckEquals(1, listener.Rejected, 'the datagram is refused');
   finally
      listener.Free;
      sink.Free;
   end;
end;

procedure TN1MMLogListenerTests.Test_TwoRecordsInOneEnvelopeAreRefused;
var
   sink: TRecordSink;
   listener: TN1MMLogListener;
begin
   BeginTest('Test_TwoRecordsInOneEnvelopeAreRefused');
   sink := TRecordSink.Create;
   listener := TN1MMLogListener.Create;
   try
      listener.RecordHook := sink.Take;
      listener.HandleDatagram(Envelope('Log', ADIF_ONE + ADIF_TWO), '127.0.0.1');
      CheckEquals(0, sink.Records.Count, 'a payload with two EORs is refused');
      CheckEquals(1, listener.Rejected, 'counted');
   finally
      listener.Free;
      sink.Free;
   end;
end;

procedure TN1MMLogListenerTests.Test_AStreamDeliveredAByteAtATime;
var
   sink: TRecordSink;
   listener: TN1MMLogListener;
   framer: TN1MMLogFramer;
   bytes: RawByteString;
   i: integer;
begin
   BeginTest('Test_AStreamDeliveredAByteAtATime');
   sink := TRecordSink.Create;
   listener := TN1MMLogListener.Create;
   framer := TN1MMLogFramer.Create;
   try
      listener.RecordHook := sink.Take;
      bytes := Envelope('Log', ADIF_ONE);
      for i := 1 to Length(bytes) do
         begin
         CheckTrue(listener.HandleStreamBytes(framer, Copy(bytes, i, 1), 'peer'),
                   'each byte is accepted');
         if i < Length(bytes) then
            begin
            CheckEquals(0, sink.Records.Count, 'nothing until the envelope is whole');
            end;
         end;
      CheckEquals(1, sink.Records.Count, 'one record at the last byte');
      CheckEquals(ADIF_ONE, sink.Records[0], 'the ADIF');
   finally
      framer.Free;
      listener.Free;
      sink.Free;
   end;
end;

procedure TN1MMLogListenerTests.Test_CoalescedStreamEnvelopesKeepTheirOrder;
var
   sink: TRecordSink;
   listener: TN1MMLogListener;
   framer: TN1MMLogFramer;
begin
   BeginTest('Test_CoalescedStreamEnvelopesKeepTheirOrder');
   sink := TRecordSink.Create;
   listener := TN1MMLogListener.Create;
   framer := TN1MMLogFramer.Create;
   try
      listener.RecordHook := sink.Take;
      (* Two whole envelopes and half of a third in one read. *)
      CheckTrue(listener.HandleStreamBytes(framer,
         Envelope('Log', ADIF_ONE) + Envelope('Log', ADIF_TWO) +
         Copy(Envelope('Log', ADIF_ONE), 1, 20), 'peer'), 'accepted');
      CheckEquals(2, sink.Records.Count, 'the two whole ones');
      CheckEquals(ADIF_ONE, sink.Records[0], 'first');
      CheckEquals(ADIF_TWO, sink.Records[1], 'second');
      CheckTrue(framer.PendingBytes > 0, 'the half envelope waits');
   finally
      framer.Free;
      listener.Free;
      sink.Free;
   end;
end;

procedure TN1MMLogListenerTests.Test_AnotherCommandIsIgnoredNotCounted;
var
   sink: TRecordSink;
   listener: TN1MMLogListener;
   framer: TN1MMLogFramer;
begin
   BeginTest('Test_AnotherCommandIsIgnoredNotCounted');
   sink := TRecordSink.Create;
   listener := TN1MMLogListener.Create;
   framer := TN1MMLogFramer.Create;
   try
      listener.RecordHook := sink.Take;
      listener.HandleStreamBytes(framer,
         Envelope('Ping', 'x') + Envelope('Log', ADIF_ONE), 'peer');
      CheckEquals(1, sink.Records.Count, 'the Log after the Ping is passed on');
      CheckEquals(0, listener.Rejected, 'a command that is not Log is not an error');
   finally
      framer.Free;
      listener.Free;
      sink.Free;
   end;
end;

procedure TN1MMLogListenerTests.Test_AMalformedStreamIsCounted;
var
   sink: TRecordSink;
   listener: TN1MMLogListener;
   framer: TN1MMLogFramer;
begin
   BeginTest('Test_AMalformedStreamIsCounted');
   sink := TRecordSink.Create;
   listener := TN1MMLogListener.Create;
   framer := TN1MMLogFramer.Create;
   try
      listener.RecordHook := sink.Take;
      CheckTrue(listener.HandleStreamBytes(framer, 'garbage garbage', 'peer'),
                'garbage is not a buffer overflow');
      CheckEquals(0, sink.Records.Count, 'nothing passed on');
      CheckEquals(1, listener.Rejected, 'refused once');
   finally
      framer.Free;
      listener.Free;
      sink.Free;
   end;
end;

procedure TN1MMLogListenerTests.Test_TheStreamBufferLimitSaysDropTheConnection;
var
   sink: TRecordSink;
   listener: TN1MMLogListener;
   framer: TN1MMLogFramer;
   chunk: RawByteString;
   dropped: boolean;
   i: integer;
begin
   BeginTest('Test_TheStreamBufferLimitSaysDropTheConnection');
   sink := TRecordSink.Create;
   listener := TN1MMLogListener.Create;
   framer := TN1MMLogFramer.Create;
   try
      listener.RecordHook := sink.Take;
      (* A stream that never yields an envelope: blanks are skipped before a tag,
        so the reader waits and nothing is consumed, and more arrives than the
        framer will hold.  (A declared length of up to 65536 cannot do this: once
        that many payload bytes arrive the envelope IS complete -- the first
        version of this test sent 60000 filler bytes, completed four envelopes,
        and passed four payloads on; the framer was right and the test wrong.) *)
      SetLength(chunk, 4096);
      for i := 1 to Length(chunk) do
         begin
         chunk[i] := ' ';
         end;
      dropped := False;
      for i := 1 to 64 do
         begin
         if not listener.HandleStreamBytes(framer, chunk, 'peer') then
            begin
            dropped := True;
            Break;
            end;
         end;
      CheckTrue(dropped, 'the limit is reached and the caller is told to drop');
      CheckEquals(0, sink.Records.Count, 'no record from a stream that never completed');
   finally
      framer.Free;
      listener.Free;
      sink.Free;
   end;
end;

procedure TN1MMLogListenerTests.Test_ABlankAddressIsTheLoopback;
begin
   BeginTest('Test_ABlankAddressIsTheLoopback');
   CheckEquals('127.0.0.1', N1MMListenAddressFromSetting(''), 'empty');
   CheckEquals('127.0.0.1', N1MMListenAddressFromSetting('   '), 'blanks');
   CheckEquals('192.168.1.20', N1MMListenAddressFromSetting(' 192.168.1.20 '),
               'a LAN address is trimmed and kept');
end;

procedure TN1MMLogListenerTests.Test_AnUnknownModeFallsBackToDigital;
var
   fellBack: boolean;
begin
   BeginTest('Test_AnUnknownModeFallsBackToDigital');
   CheckEquals(Ord(Digital), Ord(InboundQsoMode(NoMode, fellBack)), 'NoMode');
   CheckTrue(fellBack, 'and it says so');
   CheckEquals(Ord(CW), Ord(InboundQsoMode(CW, fellBack)), 'a known mode is kept');
   CheckFalse(fellBack, 'no fallback');
   CheckEquals(Ord(Digital), Ord(InboundQsoMode(Digital, fellBack)), 'Digital');
   CheckFalse(fellBack, 'no fallback for Digital');
end;

procedure TN1MMLogListenerTests.Test_BytesAreCopiedAsBytes;
var
   bytes: TIdBytes;
   raw: RawByteString;
begin
   BeginTest('Test_BytesAreCopiedAsBytes');
   SetLength(bytes, 4);
   bytes[0] := $3C;
   bytes[1] := $00;
   bytes[2] := $C3;
   bytes[3] := $A9;
   raw := N1MMBytesToRaw(bytes);
   CheckEquals(4, Length(raw), 'length is the byte count');
   CheckEquals($C3, Ord(raw[3]), 'a high byte is not converted');
   SetLength(bytes, 0);
   CheckEquals(0, Length(N1MMBytesToRaw(bytes)), 'empty in, empty out');
end;

procedure TN1MMLogListenerTests.RunAllTests;
begin
   Test_ADatagramBecomesOneRecord;
   Test_AMalformedDatagramIsRefusedAndCounted;
   Test_TwoEnvelopesInOneDatagramAreRefused;
   Test_TwoRecordsInOneEnvelopeAreRefused;
   Test_AStreamDeliveredAByteAtATime;
   Test_CoalescedStreamEnvelopesKeepTheirOrder;
   Test_AnotherCommandIsIgnoredNotCounted;
   Test_AMalformedStreamIsCounted;
   Test_TheStreamBufferLimitSaysDropTheConnection;
   Test_ABlankAddressIsTheLoopback;
   Test_AnUnknownModeFallsBackToDigital;
   Test_BytesAreCopiedAsBytes;
end;

end.
