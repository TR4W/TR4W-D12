unit uTestK4Spectrum;
{$I ..\..\src\tr4w.inc}

{
  Unit tests for uCRC16, uSpectrumTypes and uK4Spectrum -- the offline half of
  the panadapter work.  Everything here runs with no radio, no socket and no
  UI, which is the entire reason the decoder was built as a pure unit.

  TWO KINDS OF EVIDENCE, deliberately kept separate:

  1. A PUBLISHED VECTOR for the CRC.  "123456789" must give $906E for
     CRC-16/X-25.  This is what makes the CRC a named algorithm rather than
     "whatever the K4 seems to accept", and it would still hold if every K4 on
     earth vanished.

  2. A REAL CAPTURE for the frame format.  fixtures/k4pan-sample.bin is 30
     packets recorded off NY4I's K4 at 192.168.73.108 on 2026-08-25 by
     tools/k4panwatch.py, out of a 2,706-packet run in which zero frames
     failed any check.  It is a golden master: the values asserted below are
     the frozen contents of that file, so REGENERATING THE FIXTURE MEANS
     UPDATING THIS FILE.  That is the same bargain the contest corpus makes.

  The fixture deliberately contains all three sources the K4 streams at once
  (A, B and the Y mini-pan, 10 packets each), because the mini-pan is on a
  completely different dB scale and a suite that only ever saw pan A would let
  that regress silently.  See Test_MiniPan_UsesADifferentScale.
}

interface

uses
   SysUtils, Classes, VC, uTR4WTestFramework, uCRC16, uSpectrumTypes, uK4Spectrum,
   uFactoryRadioBase, uRadioElecraftK4;

type
   { Exposes the base's protected publish helper.  A descendant may reach a
     protected member of its ancestor from another unit, which is exactly the
     access a real spectrum-producing radio has -- so this probe tests the seam
     through the same door TK4Radio will use, rather than around it. }
   TSpectrumSeamProbe = class(TK4Radio)
   public
      procedure Publish(const AFrame: TSpectrumFrame);
      procedure ClearSpectrumCapability;   // reaches protected FCapabilities
   end;

   TK4SpectrumTests = class(TTestCase)
   protected
      // Recorded by OnSeamFrame so a test can assert what the subscriber saw.
      FSeamCount: Integer;
      FSeamLast: TSpectrumFrame;
      procedure OnSeamFrame(const AFrame: TSpectrumFrame);

      function FixturePath: string;
      function LoadFixture: TBytes;
      function DecodeAll(const AData: TBytes; out AFramer: TK4SpectrumFramer): TArray<TSpectrumFrame>;
      function FirstOf(const AFrames: TArray<TSpectrumFrame>; const ASource: string;
                       out AFrame: TSpectrumFrame): Boolean;
      procedure CheckEqualsI64(const Expected, Actual: Int64; const Msg: string);
      procedure CheckClose(const Expected, Actual: Single; const Msg: string);

      // uCRC16 -- published vectors
      procedure Test_CRC16_PublishedCheckValue;
      procedure Test_CRC16_EmptyIsZero;

      // uSpectrumTypes -- frequency arithmetic
      procedure Test_FrequencyMath_SpanIsCentred;
      procedure Test_FrequencyMath_BinRoundTrips;
      procedure Test_FrequencyMath_OutOfRangeRefuses;
      procedure Test_ClickTune_CWOffset;

      // uK4Spectrum -- the capture
      procedure Test_Fixture_DecodesCleanly;
      procedure Test_Fixture_CarriesAllThreeSources;
      procedure Test_MainPan_FieldValues;
      procedure Test_MiniPan_UsesADifferentScale;

      // uK4Spectrum -- rejection paths
      procedure Test_BadSync_IsRejected;
      procedure Test_CorruptPayload_FailsCRC;
      procedure Test_CorruptHeader_FailsHeaderSum;
      procedure Test_ShortBuffer_IsRejected;

      // uK4Spectrum -- framing
      procedure Test_LeadingGarbage_ResyncsAndRecovers;
      procedure Test_ChunkedFeed_FindsEveryFrame;
      procedure Test_BytewiseFeed_FindsEveryFrame;
      procedure Test_PartialFrame_YieldsNothing;

      // The seam (step 2): capability by CONNECTION, and the publish path
      procedure Test_Seam_NetworkK4ReportsSpectrum;
      procedure Test_Seam_SerialK4DoesNot;
      procedure Test_Seam_CapabilityGatesAvailability;
      procedure Test_Seam_PublishReachesSubscriber;
      procedure Test_Seam_PublishWithoutSubscriberIsSafe;

      // Stream lifecycle (step 3)
      procedure Test_Stream_StopWithoutStartIsSafe;
      procedure Test_Stream_SerialRadioDoesNotStart;
      procedure Test_Stream_NoAddressDoesNotStart;
      procedure Test_Stream_StartStopIsClean;

   public
      procedure RunAllTests; override;
   end;

implementation

const
   FIXTURE_NAME = 'k4pan-sample.bin';

   // Frozen properties of that capture.
   EXPECTED_FRAMES = 30;
   EXPECTED_PER_SOURCE = 10;

   // Main pans are 192 kHz; the mini-pan is 3 kHz.
   MAIN_SPAN_HZ = 192000;
   MINI_SPAN_HZ = 3000;

   // The first pan-A packet in the capture.
   PAN_A_CENTRE_HZ = 3534390;
   PAN_A_NOISE_DB = -125.9;
   PAN_A_SEQUENCE = 12;

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function TK4SpectrumTests.FixturePath: string;
begin
   // ParamStr(0), not the working directory: several suites resolve their data
   // this way and the test exe is required to live in tr4w\test\unit.
   Result := ExtractFilePath(ParamStr(0)) + 'fixtures\' + FIXTURE_NAME;
end;

function TK4SpectrumTests.LoadFixture: TBytes;
var
   stream: TFileStream;
begin
   SetLength(Result, 0);

   // A MISSING FIXTURE MUST FAIL, NOT SKIP.  A suite that quietly passes when
   // its evidence is absent is worse than no suite: it reports green for a
   // decoder nothing has exercised.
   if not FileExists(FixturePath) then
      begin
      Check(False, 'fixture not found: ' + FixturePath);
      Exit;
      end;

   stream := TFileStream.Create(FixturePath, fmOpenRead or fmShareDenyWrite);

   try
      SetLength(Result, stream.Size);

      if stream.Size > 0 then
         begin
         stream.ReadBuffer(Result[0], stream.Size);
         end;
   finally
      stream.Free;
   end;
end;

function TK4SpectrumTests.DecodeAll(const AData: TBytes;
                                    out AFramer: TK4SpectrumFramer): TArray<TSpectrumFrame>;
var
   frame: TSpectrumFrame;
   count: Integer;
begin
   SetLength(Result, 0);
   count := 0;

   AFramer := TK4SpectrumFramer.Create;
   AFramer.Feed(AData, Length(AData));

   while AFramer.NextFrame(frame) do
      begin
      SetLength(Result, count + 1);
      Result[count] := frame;
      Inc(count);
      end;
end;

function TK4SpectrumTests.FirstOf(const AFrames: TArray<TSpectrumFrame>;
                                  const ASource: string;
                                  out AFrame: TSpectrumFrame): Boolean;
var
   i: Integer;
begin
   Result := False;

   for i := 0 to High(AFrames) do
      begin
      if AFrames[i].SourceId = ASource then
         begin
         AFrame := AFrames[i];
         Result := True;
         Exit;
         end;
      end;
end;

procedure TK4SpectrumTests.CheckEqualsI64(const Expected, Actual: Int64;
                                          const Msg: string);
begin
   // Through the string overload: Int64 truncated into the Integer overload
   // would compare two wrong numbers and report them as agreeing.
   CheckEquals(IntToStr(Expected), IntToStr(Actual), Msg);
end;

procedure TK4SpectrumTests.CheckClose(const Expected, Actual: Single;
                                      const Msg: string);
begin
   if Abs(Expected - Actual) < 0.05 then
      begin
      Check(True, '');
      end
   else
      begin
      Check(False, Format('%s: expected %.2f, got %.2f', [Msg, Expected, Actual]));
      end;
end;

// ---------------------------------------------------------------------------
// uCRC16
// ---------------------------------------------------------------------------

procedure TK4SpectrumTests.Test_CRC16_PublishedCheckValue;
var
   s: AnsiString;
begin
   BeginTest('Test_CRC16_PublishedCheckValue');
   // The catalogue "check" value for CRC-16/X-25.  Every conforming
   // implementation must return $906E for "123456789".  If this fails the
   // algorithm is wrong, independently of anything the K4 does.
   s := '123456789';
   CheckEquals('906E', IntToHex(GetCRC16X25(s[1], Length(s)), 4),
               'CRC16/X-25("123456789")');
end;

procedure TK4SpectrumTests.Test_CRC16_EmptyIsZero;
var
   dummy: Byte;
begin
   BeginTest('Test_CRC16_EmptyIsZero');
   // Init $FFFF complemented by the final xor $FFFF.  Count = 0 leaves the
   // buffer unread, so any valid memory serves as `data`.
   dummy := 0;
   CheckEquals('0000', IntToHex(GetCRC16X25(dummy, 0), 4), 'CRC16/X-25("")');
end;

// ---------------------------------------------------------------------------
// uSpectrumTypes
// ---------------------------------------------------------------------------

procedure TK4SpectrumTests.Test_FrequencyMath_SpanIsCentred;
var
   f: TSpectrumFrame;
begin
   BeginTest('Test_FrequencyMath_SpanIsCentred');
   f := Default(TSpectrumFrame);
   f.CentreHz := PAN_A_CENTRE_HZ;
   f.SpanHz := MAIN_SPAN_HZ;
   f.BinCount := K4_SAMPLE_COUNT;

   // These are the axis labels in the reference screenshot: 3.438390 MHz to
   // 3.630390 MHz around a 3.534390 MHz centre.
   CheckEqualsI64(3438390, SpectrumStartHz(f), 'start');
   CheckEqualsI64(3630390, SpectrumEndHz(f), 'end');
   CheckEqualsI64(PAN_A_CENTRE_HZ, (SpectrumStartHz(f) + SpectrumEndHz(f)) div 2,
                  'the span is centred on CentreHz');

   // Bin centres lie strictly inside the frame -- never on either edge.
   Check(SpectrumBinHz(f, 0) > SpectrumStartHz(f),
         'the first bin centre must be above the low edge');
   Check(SpectrumBinHz(f, K4_SAMPLE_COUNT - 1) < SpectrumEndHz(f),
         'the last bin centre must be below the high edge');
end;

procedure TK4SpectrumTests.Test_FrequencyMath_BinRoundTrips;
var
   f: TSpectrumFrame;
   bin: Integer;
   s: Integer;
const
   SPANS: array[0..1] of Int64 = (MAIN_SPAN_HZ, MINI_SPAN_HZ);
begin
   BeginTest('Test_FrequencyMath_BinRoundTrips');

   // The draw path converts bins to Hz and click-to-tune converts back.  If
   // those two ever disagree the operator clicks a signal and lands somewhere
   // else, so the round trip is pinned rather than assumed.
   //
   // BOTH spans, because they fail differently.  At 192 kHz a bin is 93.75 Hz
   // and at 3 kHz it is 1.46 Hz -- the mini-pan is where a scheme that
   // truncates rather than rounds runs out of room first.
   for s := 0 to High(SPANS) do
      begin
      f := Default(TSpectrumFrame);
      f.CentreHz := PAN_A_CENTRE_HZ;
      f.SpanHz := SPANS[s];
      f.BinCount := K4_SAMPLE_COUNT;

      for bin := 0 to K4_SAMPLE_COUNT - 1 do
         begin
         if SpectrumHzToBin(f, SpectrumBinHz(f, bin)) <> bin then
            begin
            Check(False, Format('span %d Hz: bin %d did not round-trip',
                                [SPANS[s], bin]));
            Exit;
            end;
         end;
      end;

   Check(True, '');
end;

procedure TK4SpectrumTests.Test_FrequencyMath_OutOfRangeRefuses;
var
   f: TSpectrumFrame;
begin
   BeginTest('Test_FrequencyMath_OutOfRangeRefuses');
   f := Default(TSpectrumFrame);
   f.CentreHz := PAN_A_CENTRE_HZ;
   f.SpanHz := MAIN_SPAN_HZ;
   f.BinCount := K4_SAMPLE_COUNT;

   // -1, never a clamp to 0.  A clamped result is a plausible wrong answer:
   // a click off the left edge would tune the lowest visible frequency as
   // though the operator had asked for it.
   CheckEquals(-1, SpectrumHzToBin(f, SpectrumStartHz(f) - 1), 'below range');
   CheckEquals(-1, SpectrumHzToBin(f, SpectrumEndHz(f)), 'the top edge is exclusive');
   CheckEquals(0, SpectrumHzToBin(f, SpectrumStartHz(f)), 'the bottom edge is inclusive');
end;

procedure TK4SpectrumTests.Test_ClickTune_CWOffset;
const
   RF = 14025000;
   PITCH = 600;
begin
   BeginTest('Test_ClickTune_CWOffset');

   // The whole point of the correction: in CW the dial sits a pitch BELOW the
   // signal, in CW-reverse a pitch ABOVE it.  Getting the sign wrong puts the
   // operator 1200 Hz out -- still plausible-looking, and wrong in a way only
   // the radio would reveal.
   CheckEqualsI64(RF - PITCH, SpectrumDialFrequency(RF, PITCH, True, False), 'CW tunes below');
   CheckEqualsI64(RF + PITCH, SpectrumDialFrequency(RF, PITCH, False, True), 'CW-R tunes above');

   // Not a CW mode: the signal is where it is drawn.
   CheckEqualsI64(RF, SpectrumDialFrequency(RF, PITCH, False, False), 'SSB is uncorrected');

   // NO PITCH MEANS NO GUESS.  Nothing in TR4W knows the receiver's CW pitch
   // today, so the default must leave the frequency alone rather than invent
   // an offset from TR4W's own sidetone.
   CheckEqualsI64(RF, SpectrumDialFrequency(RF, 0, True, False), 'zero pitch does not correct');
   CheckEqualsI64(RF, SpectrumDialFrequency(RF, -600, True, False), 'a negative pitch is refused');

   // Both flags set is a caller bug; preferring one silently would hide it.
   CheckEqualsI64(RF, SpectrumDialFrequency(RF, PITCH, True, True), 'contradictory modes do not correct');
end;

// ---------------------------------------------------------------------------
// The capture
// ---------------------------------------------------------------------------

procedure TK4SpectrumTests.Test_Fixture_DecodesCleanly;
var
   data: TBytes;
   frames: TArray<TSpectrumFrame>;
   framer: TK4SpectrumFramer;
begin
   BeginTest('Test_Fixture_DecodesCleanly');
   data := LoadFixture;

   if Length(data) = 0 then
      begin
      Exit;
      end;

   CheckEquals(EXPECTED_FRAMES * K4_PACKET_SIZE, Length(data), 'fixture size');

   frames := DecodeAll(data, framer);

   try
      CheckEquals(EXPECTED_FRAMES, Length(frames), 'frames decoded');
      // A clean capture: nothing discarded, nothing resynced, nothing rejected.
      CheckEqualsI64(0, framer.Discarded, 'bytes discarded');
      CheckEqualsI64(0, framer.Resyncs, 'resyncs');
      CheckEqualsI64(0, framer.BadFrames, 'bad frames');
   finally
      framer.Free;
   end;
end;

procedure TK4SpectrumTests.Test_Fixture_CarriesAllThreeSources;
var
   data: TBytes;
   frames: TArray<TSpectrumFrame>;
   framer: TK4SpectrumFramer;
   i: Integer;
   a, b, y: Integer;
begin
   BeginTest('Test_Fixture_CarriesAllThreeSources');
   data := LoadFixture;

   if Length(data) = 0 then
      begin
      Exit;
      end;

   frames := DecodeAll(data, framer);

   try
      a := 0;
      b := 0;
      y := 0;

      for i := 0 to High(frames) do
         begin
         if frames[i].SourceId = 'A' then Inc(a);
         if frames[i].SourceId = 'B' then Inc(b);
         if frames[i].SourceId = 'Y' then Inc(y);
         end;

      // The K4 interleaves all of its active pans down ONE socket.  A decoder
      // that filtered to a single source here would still pass every other
      // test in this file while throwing away two thirds of the stream.
      CheckEquals(EXPECTED_PER_SOURCE, a, 'pan A frames');
      CheckEquals(EXPECTED_PER_SOURCE, b, 'pan B frames');
      CheckEquals(EXPECTED_PER_SOURCE, y, 'pan Y frames');
   finally
      framer.Free;
   end;
end;

procedure TK4SpectrumTests.Test_MainPan_FieldValues;
var
   data: TBytes;
   frames: TArray<TSpectrumFrame>;
   framer: TK4SpectrumFramer;
   f: TSpectrumFrame;
begin
   BeginTest('Test_MainPan_FieldValues');
   data := LoadFixture;

   if Length(data) = 0 then
      begin
      Exit;
      end;

   frames := DecodeAll(data, framer);

   try
      if not FirstOf(frames, 'A', f) then
         begin
         Check(False, 'no pan A frame in the fixture');
         Exit;
         end;

      CheckEqualsI64(MAIN_SPAN_HZ, f.SpanHz, 'span');
      CheckEqualsI64(PAN_A_CENTRE_HZ, f.CentreHz, 'centre');
      CheckEquals(K4_SAMPLE_COUNT, f.BinCount, 'bin count');
      CheckEquals(K4_SAMPLE_COUNT, Length(f.Bins), 'bins allocated');
      CheckEquals(PAN_A_SEQUENCE, f.Sequence, 'sequence');
      CheckClose(PAN_A_NOISE_DB, f.NoiseFloorDb, 'noise floor');
   finally
      framer.Free;
   end;
end;

procedure TK4SpectrumTests.Test_MiniPan_UsesADifferentScale;
var
   data: TBytes;
   frames: TArray<TSpectrumFrame>;
   framer: TK4SpectrumFramer;
   main, mini: TSpectrumFrame;
begin
   BeginTest('Test_MiniPan_UsesADifferentScale');
   data := LoadFixture;

   if Length(data) = 0 then
      begin
      Exit;
      end;

   frames := DecodeAll(data, framer);

   try
      if (not FirstOf(frames, 'A', main)) or (not FirstOf(frames, 'Y', mini)) then
         begin
         Check(False, 'fixture is missing pan A or pan Y');
         Exit;
         end;

      CheckEqualsI64(MINI_SPAN_HZ, mini.SpanHz, 'mini-pan span');

      // THE FINDING THIS TEST EXISTS TO PRESERVE.  Measured over 75 s: the
      // main pans sit near -125 dB and the 3 kHz mini-pan near 0 dB.  They are
      // not on the same scale, so any renderer that picks a fixed dB window
      // will draw one of them as a flat block of single colour -- which is
      // exactly what TR4QT's hard-coded -100..-20 window does.  Colour and
      // height must be scaled relative to NoiseFloorDb.
      Check(main.NoiseFloorDb < -100.0,
            Format('main pan floor should be far negative, got %.1f', [main.NoiseFloorDb]));
      Check(mini.NoiseFloorDb > -10.0,
            Format('mini-pan floor should be near zero, got %.1f', [mini.NoiseFloorDb]));
      Check(Abs(main.NoiseFloorDb - mini.NoiseFloorDb) > 100.0,
            'the two scales must remain far apart');
   finally
      framer.Free;
   end;
end;

// ---------------------------------------------------------------------------
// Rejection paths
// ---------------------------------------------------------------------------

procedure TK4SpectrumTests.Test_BadSync_IsRejected;
var
   data: TBytes;
begin
   BeginTest('Test_BadSync_IsRejected');
   data := LoadFixture;

   if Length(data) = 0 then
      begin
      Exit;
      end;

   Check(ValidateK4Frame(data, 0) = k4Ok, 'the untouched frame should validate');

   data[1] := data[1] xor $FF;
   Check(ValidateK4Frame(data, 0) = k4BadSync, 'a broken sync marker must be rejected');
end;

procedure TK4SpectrumTests.Test_CorruptPayload_FailsCRC;
var
   data: TBytes;
begin
   BeginTest('Test_CorruptPayload_FailsCRC');
   data := LoadFixture;

   if Length(data) = 0 then
      begin
      Exit;
      end;

   // A payload byte: sync and header sum still pass, so only the CRC can catch
   // this.  That is the whole reason the frame carries one.
   data[K4_HEADER_SIZE + 100] := data[K4_HEADER_SIZE + 100] xor $FF;
   Check(ValidateK4Frame(data, 0) = k4BadCRC, 'corrupt payload must fail the CRC');
end;

procedure TK4SpectrumTests.Test_CorruptHeader_FailsHeaderSum;
var
   data: TBytes;
begin
   BeginTest('Test_CorruptHeader_FailsHeaderSum');
   data := LoadFixture;

   if Length(data) = 0 then
      begin
      Exit;
      end;

   // Byte 10 is inside the ASCII span field.  Both the header sum and the CRC
   // now disagree; the sum is checked first because it costs 64 byte-adds
   // instead of a CRC over 4,160.
   data[10] := data[10] xor $FF;
   Check(ValidateK4Frame(data, 0) = k4BadHeaderSum, 'corrupt header must fail the sum');
end;

procedure TK4SpectrumTests.Test_ShortBuffer_IsRejected;
var
   data: TBytes;
   short: TBytes;
begin
   BeginTest('Test_ShortBuffer_IsRejected');
   data := LoadFixture;

   if Length(data) = 0 then
      begin
      Exit;
      end;

   short := Copy(data, 0, K4_PACKET_SIZE - 1);
   Check(ValidateK4Frame(short, 0) = k4TooShort, 'one byte short must be refused');
   Check(ValidateK4Frame(data, Length(data) - 10) = k4TooShort, 'a tail offset must be refused');
end;

// ---------------------------------------------------------------------------
// Framing
// ---------------------------------------------------------------------------

procedure TK4SpectrumTests.Test_LeadingGarbage_ResyncsAndRecovers;
var
   data: TBytes;
   dirty: TBytes;
   frames: TArray<TSpectrumFrame>;
   framer: TK4SpectrumFramer;
   i: Integer;
const
   JUNK = 37;
begin
   BeginTest('Test_LeadingGarbage_ResyncsAndRecovers');
   data := LoadFixture;

   if Length(data) = 0 then
      begin
      Exit;
      end;

   // Joining a stream mid-frame is the NORMAL case, not an error case: the
   // radio is already transmitting when we connect.
   SetLength(dirty, JUNK + Length(data));

   for i := 0 to JUNK - 1 do
      begin
      dirty[i] := Byte(i * 7 + 1);      // nothing resembling the sync marker
      end;

   Move(data[0], dirty[JUNK], Length(data));

   frames := DecodeAll(dirty, framer);

   try
      CheckEquals(EXPECTED_FRAMES, Length(frames), 'every frame after the junk');
      CheckEqualsI64(JUNK, framer.Discarded, 'exactly the junk was discarded');
      Check(framer.Resyncs > 0, 'a resync should have been recorded');
   finally
      framer.Free;
   end;
end;

procedure TK4SpectrumTests.Test_ChunkedFeed_FindsEveryFrame;
var
   data: TBytes;
   chunk: TBytes;
   framer: TK4SpectrumFramer;
   frame: TSpectrumFrame;
   pos, take, got: Integer;
const
   CHUNK_SIZE = 997;   // prime, so no chunk edge lines up with a frame boundary
begin
   BeginTest('Test_ChunkedFeed_FindsEveryFrame');
   data := LoadFixture;

   if Length(data) = 0 then
      begin
      Exit;
      end;

   // TCP delivers whatever it delivers.  A frame split across two reads is the
   // single most likely framing bug, and it is invisible when a test feeds the
   // whole capture in one go.
   framer := TK4SpectrumFramer.Create;

   try
      pos := 0;
      got := 0;

      while pos < Length(data) do
         begin
         take := CHUNK_SIZE;

         if pos + take > Length(data) then
            begin
            take := Length(data) - pos;
            end;

         chunk := Copy(data, pos, take);
         framer.Feed(chunk, take);
         Inc(pos, take);

         while framer.NextFrame(frame) do
            begin
            Inc(got);
            end;
         end;

      CheckEquals(EXPECTED_FRAMES, got, 'frames across chunked feeds');
      CheckEqualsI64(0, framer.Discarded, 'nothing discarded');
   finally
      framer.Free;
   end;
end;

procedure TK4SpectrumTests.Test_BytewiseFeed_FindsEveryFrame;
var
   data: TBytes;
   oneByte: TBytes;    // NOT 'one' -- that is an existing SmallInt constant,
                       // and Pascal identifiers are case-insensitive
   framer: TK4SpectrumFramer;
   frame: TSpectrumFrame;
   i, got: Integer;
const
   FRAMES_TO_TRY = 2;      // enough to prove it; the whole file would be slow
begin
   BeginTest('Test_BytewiseFeed_FindsEveryFrame');
   data := LoadFixture;

   if Length(data) = 0 then
      begin
      Exit;
      end;

   // The degenerate case: one byte at a time.  Nothing may be lost at a feed
   // boundary even when every byte is its own boundary.
   framer := TK4SpectrumFramer.Create;
   SetLength(oneByte, 1);

   try
      got := 0;

      for i := 0 to (FRAMES_TO_TRY * K4_PACKET_SIZE) - 1 do
         begin
         oneByte[0] := data[i];
         framer.Feed(oneByte, 1);

         while framer.NextFrame(frame) do
            begin
            Inc(got);
            end;
         end;

      CheckEquals(FRAMES_TO_TRY, got, 'frames from byte-at-a-time feeding');
   finally
      framer.Free;
   end;
end;

procedure TK4SpectrumTests.Test_PartialFrame_YieldsNothing;
var
   data: TBytes;
   partial: TBytes;
   framer: TK4SpectrumFramer;
   frame: TSpectrumFrame;
begin
   BeginTest('Test_PartialFrame_YieldsNothing');
   data := LoadFixture;

   if Length(data) = 0 then
      begin
      Exit;
      end;

   framer := TK4SpectrumFramer.Create;

   try
      partial := Copy(data, 0, K4_PACKET_SIZE - 1);
      framer.Feed(partial, Length(partial));

      // One byte short: no frame, no discard, and above all no crash reading
      // past the end of the buffer.
      CheckFalse(framer.NextFrame(frame), 'a partial frame must not be emitted');
      CheckEqualsI64(0, framer.Discarded, 'a partial frame must not be discarded');

      // Completing it releases the frame.
      partial := Copy(data, K4_PACKET_SIZE - 1, 1);
      framer.Feed(partial, 1);
      CheckTrue(framer.NextFrame(frame), 'the completed frame must appear');
      CheckEquals('A', frame.SourceId, 'and be the first pan A frame');
   finally
      framer.Free;
   end;
end;

// ---------------------------------------------------------------------------
// The seam
// ---------------------------------------------------------------------------

procedure TSpectrumSeamProbe.Publish(const AFrame: TSpectrumFrame);
begin
   PublishSpectrumFrame(AFrame);
end;

procedure TSpectrumSeamProbe.ClearSpectrumCapability;
begin
   FCapabilities.Flags := FCapabilities.Flags - [rcSpectrum];
end;

procedure TK4SpectrumTests.Test_Seam_CapabilityGatesAvailability;
var
   probe: TSpectrumSeamProbe;
begin
   BeginTest('Test_Seam_CapabilityGatesAvailability');
   probe := TSpectrumSeamProbe.Create;

   try
      CheckTrue(probe.SpectrumAvailable, 'available while the capability stands');

      // Withdrawing the model capability must switch the feature off even on a
      // network link.  The override tests Supports(rcSpectrum) first precisely
      // so that one edit to the constructor disables the feature, instead of
      // leaving an override that still answers True and contradicts it.
      probe.ClearSpectrumCapability;
      CheckFalse(probe.SpectrumAvailable, 'the capability gates availability');
   finally
      probe.Free;
   end;
end;

procedure TK4SpectrumTests.OnSeamFrame(const AFrame: TSpectrumFrame);
begin
   Inc(FSeamCount);
   FSeamLast := AFrame;
end;

procedure TK4SpectrumTests.Test_Seam_NetworkK4ReportsSpectrum;
var
   radio: TK4Radio;
begin
   BeginTest('Test_Seam_NetworkK4ReportsSpectrum');

   // TRadioFactory's network path sets radioAddress/radioPort and leaves
   // serialPort alone, so a freshly constructed radio is in exactly the state
   // a network-created one is in.
   radio := TK4Radio.Create;

   try
      radio.radioAddress := '192.168.73.108';
      radio.radioPort := 9200;

      CheckTrue(radio.Supports(rcSpectrum), 'a K4 model has a panadapter');
      CheckTrue(radio.SpectrumAvailable, 'and a network K4 can deliver it');

      // The capability dump is how the log answers "what can this rig do".  A
      // flag missing from it is invisible in the field.
      Check(Pos('Spectrum', radio.CapabilitiesAsText) > 0,
            'rcSpectrum must appear in CapabilitiesAsText, got: ' + radio.CapabilitiesAsText);
   finally
      radio.Free;
   end;
end;

procedure TK4SpectrumTests.Test_Seam_SerialK4DoesNot;
var
   radio: TK4Radio;
begin
   BeginTest('Test_Seam_SerialK4DoesNot');
   radio := TK4Radio.Create;

   try
      radio.serialPort := Serial1;

      // THE TWO LEVELS COME APART HERE, which is the point of separating them.
      // The MODEL still has a panadapter -- that fact does not change with a
      // cable -- but THIS connection cannot deliver it, because the K4 serves
      // the stream on a TCP port a serial link does not have.
      CheckTrue(radio.Supports(rcSpectrum), 'the model capability is unchanged by the link');
      CheckFalse(radio.SpectrumAvailable, 'a serial K4 cannot deliver spectrum');

      // And availability must follow the port back, not latch.  The factory
      // assigns serialPort AFTER construction (uRadioFactory.pas:154), so an
      // answer computed once in the constructor would be stuck on the default.
      radio.serialPort := NoPort;
      CheckTrue(radio.SpectrumAvailable, 'availability must track the connection');
   finally
      radio.Free;
   end;
end;

procedure TK4SpectrumTests.Test_Seam_PublishReachesSubscriber;
var
   probe: TSpectrumSeamProbe;
   data: TBytes;
   frames: TArray<TSpectrumFrame>;
   framer: TK4SpectrumFramer;
begin
   BeginTest('Test_Seam_PublishReachesSubscriber');
   data := LoadFixture;

   if Length(data) = 0 then
      begin
      Exit;
      end;

   frames := DecodeAll(data, framer);

   try
      FSeamCount := 0;
      probe := TSpectrumSeamProbe.Create;

      try
         probe.OnSpectrumFrame := OnSeamFrame;
         probe.Publish(frames[0]);

         CheckEquals(1, FSeamCount, 'the subscriber should have been called once');
         CheckEquals(frames[0].SourceId, FSeamLast.SourceId, 'source id survived');
         CheckEqualsI64(frames[0].CentreHz, FSeamLast.CentreHz, 'centre survived');
         CheckEquals(frames[0].BinCount, Length(FSeamLast.Bins), 'the bins came through');
      finally
         probe.Free;
      end;
   finally
      framer.Free;
   end;
end;

procedure TK4SpectrumTests.Test_Seam_PublishWithoutSubscriberIsSafe;
var
   probe: TSpectrumSeamProbe;
   frame: TSpectrumFrame;
begin
   BeginTest('Test_Seam_PublishWithoutSubscriberIsSafe');

   // A radio may stream spectrum with no window open; that is the NORMAL case,
   // not an error.  Publishing into a nil subscriber must simply do nothing.
   frame := Default(TSpectrumFrame);
   probe := TSpectrumSeamProbe.Create;

   try
      probe.Publish(frame);
      Check(True, 'publishing with no subscriber did not raise');
   finally
      probe.Free;
   end;
end;

// ---------------------------------------------------------------------------
// Stream lifecycle
// ---------------------------------------------------------------------------

procedure TK4SpectrumTests.Test_Stream_StopWithoutStartIsSafe;
var
   radio: TK4Radio;
begin
   BeginTest('Test_Stream_StopWithoutStartIsSafe');
   radio := TK4Radio.Create;

   try
      // Idempotent by contract: a window closing without ever having started
      // the stream must not have to remember that.
      radio.StopSpectrum;
      radio.StopSpectrum;
      CheckFalse(radio.SpectrumStreaming, 'nothing should be streaming');
      Check(True, 'stopping an unstarted stream did not raise');
   finally
      radio.Free;
   end;
end;

procedure TK4SpectrumTests.Test_Stream_SerialRadioDoesNotStart;
var
   radio: TK4Radio;
begin
   BeginTest('Test_Stream_SerialRadioDoesNotStart');
   radio := TK4Radio.Create;

   try
      radio.serialPort := Serial1;
      radio.radioAddress := '192.0.2.1';   // TEST-NET-1, deliberately unroutable

      // A caller may drive StartSpectrum unconditionally.  On a serial K4 there
      // is no stream to open, and the important part is that no socket is
      // attempted -- not merely that no frames arrive.
      radio.StartSpectrum;
      CheckFalse(radio.SpectrumStreaming, 'a serial K4 must not open a spectrum socket');
   finally
      radio.Free;
   end;
end;

procedure TK4SpectrumTests.Test_Stream_NoAddressDoesNotStart;
var
   radio: TK4Radio;
begin
   BeginTest('Test_Stream_NoAddressDoesNotStart');
   radio := TK4Radio.Create;

   try
      // SpectrumAvailable is True here -- serialPort is NoPort -- so this pins
      // the second guard: available, but nowhere to connect to.  Without it the
      // thread would spin on a connect to ':9201' forever.
      CheckTrue(radio.SpectrumAvailable, 'precondition: available');
      radio.StartSpectrum;
      CheckFalse(radio.SpectrumStreaming, 'an empty address must not start a reader');
   finally
      radio.Free;
   end;
end;

procedure TK4SpectrumTests.Test_Stream_StartStopIsClean;
var
   radio: TK4Radio;
begin
   BeginTest('Test_Stream_StartStopIsClean');
   radio := TK4Radio.Create;

   try
      // Port 1 on loopback: refused immediately, so this exercises thread
      // creation, a failed connect, the backoff and a clean shutdown WITHOUT
      // needing a radio -- and without the 5 s connect timeout an unroutable
      // address would cost.  What is being tested is the lifecycle, not the
      // networking: StopSpectrum must return promptly even though the reader is
      // sitting in a reconnect wait, which is why that wait is sliced.
      radio.radioAddress := '127.0.0.1';
      radio.radioPort := 0;                 // + K4_SPECTRUM_PORT_OFFSET = 1

      radio.StartSpectrum;
      CheckTrue(radio.SpectrumStreaming, 'the reader should be alive');

      // Alive but not connected -- the distinction the window renders as
      // "Connecting..." rather than "Connected".
      CheckFalse(radio.SpectrumLinkUp, 'a refused port must not report a link');

      radio.StartSpectrum;                  // idempotent: must not start a second
      CheckTrue(radio.SpectrumStreaming, 'still exactly one reader');

      radio.StopSpectrum;
      CheckFalse(radio.SpectrumStreaming, 'the reader should be gone');

      // And the destructor must cope with a second stop.
      radio.StopSpectrum;
   finally
      radio.Free;
   end;
end;

// ---------------------------------------------------------------------------

procedure TK4SpectrumTests.RunAllTests;
begin
   Test_CRC16_PublishedCheckValue;
   Test_CRC16_EmptyIsZero;

   Test_FrequencyMath_SpanIsCentred;
   Test_FrequencyMath_BinRoundTrips;
   Test_FrequencyMath_OutOfRangeRefuses;
   Test_ClickTune_CWOffset;

   Test_Fixture_DecodesCleanly;
   Test_Fixture_CarriesAllThreeSources;
   Test_MainPan_FieldValues;
   Test_MiniPan_UsesADifferentScale;

   Test_BadSync_IsRejected;
   Test_CorruptPayload_FailsCRC;
   Test_CorruptHeader_FailsHeaderSum;
   Test_ShortBuffer_IsRejected;

   Test_LeadingGarbage_ResyncsAndRecovers;
   Test_ChunkedFeed_FindsEveryFrame;
   Test_BytewiseFeed_FindsEveryFrame;
   Test_PartialFrame_YieldsNothing;

   Test_Seam_NetworkK4ReportsSpectrum;
   Test_Seam_SerialK4DoesNot;
   Test_Seam_CapabilityGatesAvailability;
   Test_Seam_PublishReachesSubscriber;
   Test_Seam_PublishWithoutSubscriberIsSafe;

   Test_Stream_StopWithoutStartIsSafe;
   Test_Stream_SerialRadioDoesNotStart;
   Test_Stream_NoAddressDoesNotStart;
   Test_Stream_StartStopIsClean;
end;

end.
