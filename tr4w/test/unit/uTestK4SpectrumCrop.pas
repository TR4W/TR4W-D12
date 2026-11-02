unit uTestK4SpectrumCrop;
{$I ..\..\src\tr4w.inc}

(*
  THE K4 MAIN PAN IS DRAWN AT #SPN, NOT AT THE FRAME'S WIDTH (NY4I, 2026-11-03).

  Two layers, tested separately:

  1. uSpectrumTypes.SpectrumCropCentred -- the pure arithmetic.  Kept count,
     span, centring, the edge guard, the pass-through cases, and the one
     property everything else rests on: bin i of a cropped frame has EXACTLY
     the Hz of bin (i + first) of the frame it came from, so the trace, the
     axis and click-to-tune agree before and after.

  2. TK4Radio.HandleSpectrumFrame -- which source is cropped (A only), with
     which span (the radio's own #SPN, fed here through ProcessMsg exactly as
     the reading thread feeds it) and which guard (K4_EDGE_GUARD_BINS).

  AND AGAINST REAL FRAMES.  The padding this exists to remove is a property
  of the radio, so the evidence is two captures, not a constructed frame:

    fixtures/k4pan-sample.bin        2026-08-25, 30 frames, A/B at 192 kHz
                                     and the Y mini-pan (see uTestK4Spectrum)
    fixtures/k4pan-tiers-sample.bin  2026-11-02 span sweep (#SPN 5k..368k):
                                     14 pan-A frames, every frame width the
                                     K4 served, chosen as the frames with the
                                     WIDEST edge pad at each width
                                     (tools/k4pan_tier_fixture.py)

  "PAD" IS MEASURED PER FRAME, not hard-coded: the run of bins at least 8 dB
  below that frame's median, counted in from each end.  A plain "no bin 8 dB
  below the median" would not do -- about 200 bins of ordinary noise inside
  every main-pan frame dip that far.  The run is what the eye sees as the flat
  line, and the crop must never keep any of it.
*)

interface

uses
   SysUtils, Classes, uTR4WTestFramework, uSpectrumTypes, uK4Spectrum,
   uFactoryRadioBase, uRadioElecraftK4;

type
   (* Reaches the protected HandleSpectrumFrame, the method the spectrum thread
      calls -- so these tests drive the radio through the same door. *)
   TK4CropProbe = class(TK4Radio)
   public
      procedure Feed(const AFrame: TSpectrumFrame);
   end;

   TK4SpectrumCropTests = class(TTestCase)
   protected
      FSeen: Integer;
      FLast: TSpectrumFrame;
      procedure OnFrame(const AFrame: TSpectrumFrame);

      function LoadFrames(const AName: string): TArray<TSpectrumFrame>;
      function NewProbe: TK4CropProbe;
      procedure CheckEqualsI64(const Expected, Actual: Int64; const Msg: string);

      // Bins hold their own index, so a crop says which bins it kept.
      function IndexFrame(ASpanHz, ACentreHz: Int64; const ASource: string): TSpectrumFrame;
      function Median(const ABins: TSpectrumBins; ACount: Integer): Single;
      procedure PadRuns(const AFrame: TSpectrumFrame; out ALeft, ARight: Integer);
      procedure CheckCropExcludesPad(const AFrame, ACropped: TSpectrumFrame; const AWhat: string);
      procedure CheckSameFrame(const AExpected, AActual: TSpectrumFrame; const AWhat: string);

      // The pure arithmetic
      procedure Test_Crop_KeptCountAndSpan;
      procedure Test_Crop_BinHzIsContinuous;
      procedure Test_Crop_PassesThrough;
      procedure Test_Crop_ReusesTheBuffer;

      // The radio
      procedure Test_Radio_UnknownSpanPassesThrough;
      procedure Test_Radio_MainPanIsCroppedToSPN;
      procedure Test_Radio_OtherSourcesPassThrough;
      procedure Test_Radio_FrameAtTheOldWidth;

      // The captures
      procedure Test_Sample_PadIsWhereItWasMeasured;
      procedure Test_Sample_CropExcludesThePad;
      procedure Test_Tiers_CarriesEveryWidth;
      procedure Test_Tiers_CropExcludesThePad;
      procedure Test_Tiers_GuardIsNeededAt368k;
   public
      procedure RunAllTests; override;
   end;

implementation

const
   SAMPLE_FIXTURE = 'k4pan-sample.bin';
   TIERS_FIXTURE = 'k4pan-tiers-sample.bin';

   PAD_BELOW_MEDIAN_DB = 8.0;

   CENTRE_HZ = 3534390;

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

procedure TK4CropProbe.Feed(const AFrame: TSpectrumFrame);
begin
   HandleSpectrumFrame(AFrame);
end;

procedure TK4SpectrumCropTests.OnFrame(const AFrame: TSpectrumFrame);
begin
   (* A COPY of the bins: the radio reuses its crop buffer on the next frame,
      and the subscriber contract (uSpectrumTypes) says copy what you keep. *)
   Inc(FSeen);
   FLast := AFrame;
   FLast.Bins := Copy(AFrame.Bins, 0, Length(AFrame.Bins));
end;

function TK4SpectrumCropTests.NewProbe: TK4CropProbe;
begin
   Result := TK4CropProbe.Create;
   Result.OnSpectrumFrame := OnFrame;
   FSeen := 0;
   FLast := Default(TSpectrumFrame);
end;

procedure TK4SpectrumCropTests.CheckEqualsI64(const Expected, Actual: Int64;
                                              const Msg: string);
begin
   // Through the string overload, so an Int64 is never truncated to compare.
   CheckEquals(IntToStr(Expected), IntToStr(Actual), Msg);
end;

function TK4SpectrumCropTests.LoadFrames(const AName: string): TArray<TSpectrumFrame>;
var
   path: string;
   stream: TFileStream;
   data: TBytes;
   framer: TK4SpectrumFramer;
   frame: TSpectrumFrame;
   count: Integer;
begin
   // Assigned, not SetLength: a managed result is not guaranteed nil on entry.
   Result := nil;
   path := ExtractFilePath(ParamStr(0)) + 'fixtures' + PathDelim + AName;

   // A MISSING FIXTURE FAILS; it never skips.
   if not FileExists(path) then
      begin
      Check(False, 'fixture not found: ' + path);
      Exit;
      end;

   stream := TFileStream.Create(path, fmOpenRead or fmShareDenyWrite);

   try
      SetLength(data, stream.Size);

      if stream.Size > 0 then
         begin
         stream.ReadBuffer(data[0], stream.Size);
         end;
   finally
      stream.Free;
   end;

   framer := TK4SpectrumFramer.Create;

   try
      framer.Feed(data, Length(data));
      count := 0;

      while framer.NextFrame(frame) do
         begin
         SetLength(Result, count + 1);
         Result[count] := frame;
         Inc(count);
         end;

      CheckEqualsI64(0, framer.BadFrames, AName + ': bad frames');
   finally
      framer.Free;
   end;
end;

function TK4SpectrumCropTests.IndexFrame(ASpanHz, ACentreHz: Int64;
                                         const ASource: string): TSpectrumFrame;
var
   i: Integer;
begin
   Result := Default(TSpectrumFrame);
   Result.SourceId := ASource;
   Result.SpanHz := ASpanHz;
   Result.CentreHz := ACentreHz;
   Result.NoiseFloorDb := -125.0;
   Result.BinCount := K4_SAMPLE_COUNT;
   SetLength(Result.Bins, K4_SAMPLE_COUNT);

   for i := 0 to K4_SAMPLE_COUNT - 1 do
      begin
      Result.Bins[i] := i;
      end;
end;

function TK4SpectrumCropTests.Median(const ABins: TSpectrumBins; ACount: Integer): Single;
var
   sorted: TSpectrumBins;
   i, j: Integer;
   v: Single;
begin
   Result := 0;

   if ACount <= 0 then
      begin
      Exit;
      end;

   sorted := Copy(ABins, 0, ACount);

   // Insertion sort: 2048 values, test code, and nothing to get wrong.
   for i := 1 to ACount - 1 do
      begin
      v := sorted[i];
      j := i - 1;

      while (j >= 0) and (sorted[j] > v) do
         begin
         sorted[j + 1] := sorted[j];
         Dec(j);
         end;

      sorted[j + 1] := v;
      end;

   if Odd(ACount) then
      begin
      Result := sorted[ACount div 2];
      end
   else
      begin
      Result := (sorted[(ACount div 2) - 1] + sorted[ACount div 2]) / 2;
      end;
end;

(* How many bins in from each end of the frame are at least
   PAD_BELOW_MEDIAN_DB below its median -- the flat line at the plot bottom. *)
procedure TK4SpectrumCropTests.PadRuns(const AFrame: TSpectrumFrame;
                                       out ALeft, ARight: Integer);
var
   threshold: Single;
begin
   threshold := Median(AFrame.Bins, AFrame.BinCount) - PAD_BELOW_MEDIAN_DB;

   ALeft := 0;

   while (ALeft < AFrame.BinCount) and (AFrame.Bins[ALeft] <= threshold) do
      begin
      Inc(ALeft);
      end;

   ARight := 0;

   while (ARight < AFrame.BinCount) and
         (AFrame.Bins[AFrame.BinCount - 1 - ARight] <= threshold) do
      begin
      Inc(ARight);
      end;
end;

procedure TK4SpectrumCropTests.CheckCropExcludesPad(const AFrame, ACropped: TSpectrumFrame;
                                                    const AWhat: string);
var
   padLeft, padRight: Integer;
   first: Integer;
   last: Integer;
begin
   PadRuns(AFrame, padLeft, padRight);

   // A real main-pan frame HAS a pad; if this ever fails the capture is not
   // the evidence it claims to be.
   Check(padLeft > 30, Format('%s: the frame should carry a left pad, run %d', [AWhat, padLeft]));
   Check(padRight > 30, Format('%s: the frame should carry a right pad, run %d', [AWhat, padRight]));

   first := (AFrame.BinCount - ACropped.BinCount) div 2;
   last := first + ACropped.BinCount - 1;

   Check(ACropped.BinCount < AFrame.BinCount, AWhat + ': the frame should have been cropped');
   Check(first >= padLeft,
         Format('%s: the crop keeps bin %d but the left pad runs to bin %d',
                [AWhat, first, padLeft - 1]));
   Check(last < AFrame.BinCount - padRight,
         Format('%s: the crop keeps bin %d but the right pad starts at bin %d',
                [AWhat, last, AFrame.BinCount - padRight]));
end;

procedure TK4SpectrumCropTests.CheckSameFrame(const AExpected, AActual: TSpectrumFrame;
                                              const AWhat: string);
var
   i: Integer;
   same: Boolean;
begin
   CheckEquals(AExpected.SourceId, AActual.SourceId, AWhat + ': source');
   CheckEqualsI64(AExpected.SpanHz, AActual.SpanHz, AWhat + ': span');
   CheckEqualsI64(AExpected.CentreHz, AActual.CentreHz, AWhat + ': centre');
   CheckEquals(AExpected.BinCount, AActual.BinCount, AWhat + ': bin count');
   CheckEquals(Length(AExpected.Bins), Length(AActual.Bins), AWhat + ': bins');

   same := Length(AExpected.Bins) = Length(AActual.Bins);
   i := 0;

   while same and (i < Length(AExpected.Bins)) do
      begin
      same := AExpected.Bins[i] = AActual.Bins[i];
      Inc(i);
      end;

   CheckTrue(same, AWhat + ': every bin unchanged');
end;

// ---------------------------------------------------------------------------
// The pure arithmetic
// ---------------------------------------------------------------------------

procedure TK4SpectrumCropTests.Test_Crop_KeptCountAndSpan;
type
   TCase = record
      FrameSpan: Int64;
      Want: Int64;
      Guard: Integer;
      Kept: Integer;
      Span: Int64;
   end;
const
   (* Kept is the multiple of the exact step (8 bins at 192 kHz, 4 at 384 kHz,
      64 at 24 kHz -- 750 Hz each) nearest 2048 * Want / FrameSpan, capped at
      2048 - 2 * Guard rounded down to a step. *)
   CASES: array[0..10] of TCase = (
      (FrameSpan: 192000; Want: 150000; Guard: 0;  Kept: 1600; Span: 150000),
      (FrameSpan: 192000; Want: 100000; Guard: 0;  Kept: 1064; Span:  99750),
      (FrameSpan: 192000; Want: 184000; Guard: 0;  Kept: 1960; Span: 183750),
      (FrameSpan: 192000; Want: 184000; Guard: 49; Kept: 1944; Span: 182250),
      (FrameSpan: 192000; Want: 190000; Guard: 49; Kept: 1944; Span: 182250),
      (FrameSpan: 384000; Want: 368000; Guard: 0;  Kept: 1964; Span: 368250),
      (FrameSpan: 384000; Want: 368000; Guard: 49; Kept: 1948; Span: 365250),
      (FrameSpan: 384000; Want: 250000; Guard: 49; Kept: 1332; Span: 249750),
      (FrameSpan: 384000; Want: 150000; Guard: 49; Kept:  800; Span: 150000),
      (FrameSpan:  24000; Want:   5000; Guard: 49; Kept:  448; Span:   5250),
      // An absurd span still keeps SPECTRUM_CROP_MIN_BINS, rounded up a step.
      (FrameSpan: 192000; Want:    100; Guard: 49; Kept:   64; Span:   6000));
var
   c: Integer;
   frame, cropped: TSpectrumFrame;
   buffer: TSpectrumBins;
   what: string;
   first: Integer;
begin
   BeginTest('Test_Crop_KeptCountAndSpan');

   for c := 0 to High(CASES) do
      begin
      what := Format('%d of a %d frame, guard %d',
                     [CASES[c].Want, CASES[c].FrameSpan, CASES[c].Guard]);
      frame := IndexFrame(CASES[c].FrameSpan, CENTRE_HZ, 'A');

      CheckTrue(SpectrumCropCentred(frame, CASES[c].Want, CASES[c].Guard, buffer, cropped),
                what + ': cropped');
      CheckEquals(CASES[c].Kept, cropped.BinCount, what + ': kept');
      CheckEquals(CASES[c].Kept, Length(cropped.Bins), what + ': bins');
      CheckEqualsI64(CASES[c].Span, cropped.SpanHz, what + ': span');
      CheckEqualsI64(CENTRE_HZ, cropped.CentreHz, what + ': centred, so the centre stands');

      // Centred: the same number of bins cut from each end, and they are the
      // bins the crop says it kept.
      first := (K4_SAMPLE_COUNT - CASES[c].Kept) div 2;
      CheckEquals(K4_SAMPLE_COUNT - CASES[c].Kept, 2 * first, what + ': cut evenly');
      CheckEquals(first, Round(cropped.Bins[0]), what + ': first kept bin');
      CheckEquals(first + CASES[c].Kept - 1, Round(cropped.Bins[CASES[c].Kept - 1]),
                  what + ': last kept bin');

      // Everything that is not the width is the frame's own.
      CheckEquals(frame.SourceId, cropped.SourceId, what + ': source');
      CheckEquals(frame.Sequence, cropped.Sequence, what + ': sequence');
      Check(frame.NoiseFloorDb = cropped.NoiseFloorDb, what + ': noise floor');
      end;
end;

procedure TK4SpectrumCropTests.Test_Crop_BinHzIsContinuous;
const
   FRAME_SPANS: array[0..2] of Int64 = (192000, 384000, 24000);
   WANTS: array[0..6] of Int64 = (1000, 5000, 20000, 100000, 150000, 250000, 368000);
   CENTRES: array[0..1] of Int64 = (CENTRE_HZ, 14025123);
var
   s, w, c, i: Integer;
   frame, cropped: TSpectrumFrame;
   buffer: TSpectrumBins;
   first: Integer;
   what: string;
   broken: string;
   cases: Integer;
begin
   BeginTest('Test_Crop_BinHzIsContinuous');
   cases := 0;

   (* THE PROPERTY THE CROP IS BUILT ON.  If bin i of the cropped frame did not
      sit at the Hz of bin (i + first) of the original, the trace would draw a
      signal in one place and click-to-tune would send the radio to another.
      Every bin, every case, to the Hz -- with and without the guard, so the
      capped crop at the top of a tier is covered too. *)
   for s := 0 to High(FRAME_SPANS) do
      begin
      for w := 0 to High(WANTS) do
         begin
         for c := 0 to High(CENTRES) do
            begin
            if WANTS[w] >= FRAME_SPANS[s] then
               begin
               Continue;
               end;

            what := Format('%d of %d at %d', [WANTS[w], FRAME_SPANS[s], CENTRES[c]]);
            frame := IndexFrame(FRAME_SPANS[s], CENTRES[c], 'A');

            if not SpectrumCropCentred(frame, WANTS[w], K4_EDGE_GUARD_BINS, buffer, cropped) then
               begin
               Check(False, what + ': expected a crop');
               Continue;
               end;

            Inc(cases);
            first := (frame.BinCount - cropped.BinCount) div 2;
            broken := '';

            for i := 0 to cropped.BinCount - 1 do
               begin
               if SpectrumBinHz(cropped, i) <> SpectrumBinHz(frame, i + first) then
                  begin
                  broken := Format('bin %d is %d Hz cropped, %d Hz before',
                                   [i, SpectrumBinHz(cropped, i),
                                    SpectrumBinHz(frame, i + first)]);
                  Break;
                  end;

               if SpectrumHzToBin(cropped, SpectrumBinHz(cropped, i)) <> i then
                  begin
                  broken := Format('bin %d does not round-trip in the cropped frame', [i]);
                  Break;
                  end;
               end;

            CheckEquals('', broken, what);

            // The crop's edges are bin edges of the original.
            CheckEqualsI64(SpectrumStartHz(frame) + (first * FRAME_SPANS[s]) div K4_SAMPLE_COUNT,
                           SpectrumStartHz(cropped), what + ': low edge');
            CheckEqualsI64(0, (first * FRAME_SPANS[s]) mod K4_SAMPLE_COUNT,
                           what + ': the low edge is a whole Hz');
            end;
         end;
      end;

   Check(cases >= 30, Format('only %d continuity cases ran', [cases]));
end;

procedure TK4SpectrumCropTests.Test_Crop_PassesThrough;
var
   frame, cropped, empty: TSpectrumFrame;
   buffer: TSpectrumBins;
begin
   BeginTest('Test_Crop_PassesThrough');
   frame := IndexFrame(192000, CENTRE_HZ, 'A');

   // Unknown span: the radio has not said, so nothing is invented.
   CheckFalse(SpectrumCropCentred(frame, 0, K4_EDGE_GUARD_BINS, buffer, cropped), 'span 0');
   CheckSameFrame(frame, cropped, 'span 0');
   CheckFalse(SpectrumCropCentred(frame, -5, K4_EDGE_GUARD_BINS, buffer, cropped), 'negative span');
   CheckSameFrame(frame, cropped, 'negative span');

   // Not narrower than the frame: there is nothing to cut to.
   CheckFalse(SpectrumCropCentred(frame, 192000, K4_EDGE_GUARD_BINS, buffer, cropped), 'equal span');
   CheckSameFrame(frame, cropped, 'equal span');
   CheckFalse(SpectrumCropCentred(frame, 368000, K4_EDGE_GUARD_BINS, buffer, cropped), 'wider span');
   CheckSameFrame(frame, cropped, 'wider span');

   // A frame with no bins, or fewer than it claims, is never indexed.
   empty := Default(TSpectrumFrame);
   empty.SpanHz := 192000;
   CheckFalse(SpectrumCropCentred(empty, 150000, 0, buffer, cropped), 'no bins');
   empty.BinCount := K4_SAMPLE_COUNT;
   CheckFalse(SpectrumCropCentred(empty, 150000, 0, buffer, cropped), 'bins missing');

   // A span with no whole-Hz step inside the frame: odd Hz.
   frame := IndexFrame(192001, CENTRE_HZ, 'A');
   CheckFalse(SpectrumCropCentred(frame, 150000, 0, buffer, cropped), 'odd frame span');
   CheckSameFrame(frame, cropped, 'odd frame span');

   CheckEquals(0, Length(buffer), 'no pass-through touched the buffer');
end;

procedure TK4SpectrumCropTests.Test_Crop_ReusesTheBuffer;
var
   frame, cropped: TSpectrumFrame;
   buffer: TSpectrumBins;
   before: Pointer;
begin
   BeginTest('Test_Crop_ReusesTheBuffer');
   frame := IndexFrame(192000, CENTRE_HZ, 'A');

   CheckTrue(SpectrumCropCentred(frame, 150000, 0, buffer, cropped), 'first crop');
   Check(Pointer(cropped.Bins) = Pointer(buffer), 'the cropped bins ARE the caller''s buffer');
   before := Pointer(buffer);
   cropped := Default(TSpectrumFrame);   // as a subscriber that copied and let go

   // A stream at one span allocates nothing after the first frame.
   CheckTrue(SpectrumCropCentred(frame, 150000, 0, buffer, cropped), 'second crop');
   Check(Pointer(buffer) = before, 'the same span reuses the same buffer');
   CheckEquals(1600, Length(buffer), 'sized to the kept count');

   CheckTrue(SpectrumCropCentred(frame, 100000, 0, buffer, cropped), 'a new span');
   CheckEquals(1064, Length(buffer), 'resized to the new kept count');
   CheckEquals(492, Round(buffer[0]), 'and filled from the new first bin');
end;

// ---------------------------------------------------------------------------
// The radio
// ---------------------------------------------------------------------------

procedure TK4SpectrumCropTests.Test_Radio_UnknownSpanPassesThrough;
var
   probe: TK4CropProbe;
   frame: TSpectrumFrame;
begin
   BeginTest('Test_Radio_UnknownSpanPassesThrough');
   probe := NewProbe;

   try
      // Before the radio answers #SPN; it is 0, and the frame is drawn whole.
      CheckEquals(0, probe.SpectrumSpanHz, 'precondition: no #SPN yet');
      frame := IndexFrame(192000, CENTRE_HZ, 'A');
      probe.Feed(frame);

      CheckEquals(1, FSeen, 'one frame published');
      CheckSameFrame(frame, FLast, 'unknown #SPN');
   finally
      probe.Free;
   end;
end;

procedure TK4SpectrumCropTests.Test_Radio_MainPanIsCroppedToSPN;
var
   probe: TK4CropProbe;
begin
   BeginTest('Test_Radio_MainPanIsCroppedToSPN');
   probe := NewProbe;

   try
      probe.ProcessMsg('#SPN150000');
      CheckEquals(150000, probe.SpectrumSpanHz, 'precondition: the radio said 150 kHz');

      probe.Feed(IndexFrame(192000, CENTRE_HZ, 'A'));
      CheckEquals(1, FSeen, 'one frame published');
      CheckEquals(1600, FLast.BinCount, 'kept');
      CheckEqualsI64(150000, FLast.SpanHz, 'drawn at the radio''s span');
      CheckEqualsI64(CENTRE_HZ, FLast.CentreHz, 'centre');
      CheckEquals(224, Round(FLast.Bins[0]), 'first kept bin');

      // At the top of the 384 kHz frames the guard, not #SPN, decides.
      probe.ProcessMsg('#SPN368000');
      probe.Feed(IndexFrame(384000, CENTRE_HZ, 'A'));
      CheckEquals(2048 - (2 * 50), FLast.BinCount, 'the guard caps the 368 kHz crop');
      CheckEqualsI64(365250, FLast.SpanHz, 'and the span says what is drawn');
      Check(FLast.BinCount <= 2048 - (2 * K4_EDGE_GUARD_BINS), 'never inside the guard');
   finally
      probe.Free;
   end;
end;

procedure TK4SpectrumCropTests.Test_Radio_OtherSourcesPassThrough;
var
   probe: TK4CropProbe;
   frame: TSpectrumFrame;
begin
   BeginTest('Test_Radio_OtherSourcesPassThrough');
   probe := NewProbe;

   try
      (* #SPN is the MAIN pan's span.  The sub pan's is #SPN$, which this
         radio does not track -- so B is never cropped with A's number. *)
      probe.ProcessMsg('#SPN150000');
      probe.ProcessMsg('#SPN$50000');
      CheckEquals(150000, probe.SpectrumSpanHz, 'the sub''s span does not move the main''s');

      frame := IndexFrame(192000, 3555200, 'B');
      probe.Feed(frame);
      CheckSameFrame(frame, FLast, 'pan B');

      // The mini-pans are 3 kHz windows of their own.
      frame := IndexFrame(3000, 3534920, 'Y');
      probe.Feed(frame);
      CheckSameFrame(frame, FLast, 'mini-pan Y');

      frame := IndexFrame(3000, 3555200, 'Z');
      probe.Feed(frame);
      CheckSameFrame(frame, FLast, 'mini-pan Z');

      CheckEquals(3, FSeen, 'every frame published');
   finally
      probe.Free;
   end;
end;

procedure TK4SpectrumCropTests.Test_Radio_FrameAtTheOldWidth;
var
   probe: TK4CropProbe;
   frame: TSpectrumFrame;
begin
   BeginTest('Test_Radio_FrameAtTheOldWidth');
   probe := NewProbe;

   try
      (* The K4 changes frame width 1-3 frames AFTER it reports a new #SPN
         (2026-11-02 sweep), so frames at the old width meet the new span.
         Each is cropped against its OWN span and stays self-consistent. *)
      probe.ProcessMsg('#SPN150000');

      probe.Feed(IndexFrame(384000, CENTRE_HZ, 'A'));
      CheckEquals(800, FLast.BinCount, 'a 384 kHz frame at #SPN 150000');
      CheckEqualsI64(150000, FLast.SpanHz, 'its span');

      probe.Feed(IndexFrame(192000, CENTRE_HZ, 'A'));
      CheckEquals(1600, FLast.BinCount, 'a 192 kHz frame at #SPN 150000');
      CheckEqualsI64(150000, FLast.SpanHz, 'its span');

      // Going UP: the new span is wider than the old frame, which passes
      // through whole until the wider frames arrive.
      probe.ProcessMsg('#SPN368000');
      frame := IndexFrame(192000, CENTRE_HZ, 'A');
      probe.Feed(frame);
      CheckSameFrame(frame, FLast, 'a 192 kHz frame at #SPN 368000');
   finally
      probe.Free;
   end;
end;

// ---------------------------------------------------------------------------
// The captures
// ---------------------------------------------------------------------------

procedure TK4SpectrumCropTests.Test_Sample_PadIsWhereItWasMeasured;
var
   frames: TArray<TSpectrumFrame>;
   threshold: Single;
   i, b: Integer;
   checked: Integer;
   bad: string;
begin
   BeginTest('Test_Sample_PadIsWhereItWasMeasured');
   frames := LoadFrames(SAMPLE_FIXTURE);
   checked := 0;

   (* THE MEASUREMENT, PINNED: on every main-pan frame of the 2026-08-25
      capture, bins 0..38 and 2010..2047 are at least 8 dB below the frame's
      median.  The crop tests below are only as good as this being true. *)
   for i := 0 to High(frames) do
      begin
      if (frames[i].SourceId <> 'A') and (frames[i].SourceId <> 'B') then
         begin
         Continue;
         end;

      Inc(checked);
      threshold := Median(frames[i].Bins, frames[i].BinCount) - PAD_BELOW_MEDIAN_DB;
      bad := '';

      for b := 0 to K4_SAMPLE_COUNT - 1 do
         begin
         if ((b <= 38) or (b >= 2010)) and (frames[i].Bins[b] > threshold) then
            begin
            bad := Format('frame %d (%s) bin %d is %.1f, above %.1f',
                          [i, frames[i].SourceId, b, frames[i].Bins[b], threshold]);
            Break;
            end;
         end;

      CheckEquals('', bad, 'the pad');
      end;

   CheckEquals(20, checked, 'A and B frames in the capture');
end;

procedure TK4SpectrumCropTests.Test_Sample_CropExcludesThePad;
const
   SPANS: array[0..3] of Integer = (100000, 150000, 184000, 190000);
var
   frames: TArray<TSpectrumFrame>;
   probe: TK4CropProbe;
   buffer: TSpectrumBins;
   cropped: TSpectrumFrame;
   i, s: Integer;
   aFrames: Integer;
begin
   BeginTest('Test_Sample_CropExcludesThePad');
   frames := LoadFrames(SAMPLE_FIXTURE);
   probe := NewProbe;
   aFrames := 0;

   try
      for i := 0 to High(frames) do
         begin
         if frames[i].SourceId = 'A' then
            begin
            Inc(aFrames);

            // Through the radio, at every span up to 190 kHz.  (The K4 serves
            // #SPN 190000 at 384 kHz, so 190 kHz of a 192 kHz frame only
            // happens for the frames after a change; the guard covers it.)
            for s := 0 to High(SPANS) do
               begin
               probe.ProcessMsg(Format('#SPN%d', [SPANS[s]]));
               probe.Feed(frames[i]);
               CheckCropExcludesPad(frames[i], FLast,
                                    Format('A frame %d at #SPN %d', [i, SPANS[s]]));
               end;

            // A span equal to the frame's: drawn exactly as decoded.
            probe.ProcessMsg('#SPN192000');
            probe.Feed(frames[i]);
            CheckSameFrame(frames[i], FLast, Format('A frame %d at #SPN 192000', [i]));
            end
         else if frames[i].SourceId = 'B' then
            begin
            (* The radio leaves B alone (above).  The pad is the same shape on
               B, so the same arithmetic would clear it there too. *)
            for s := 0 to High(SPANS) do
               begin
               SpectrumCropCentred(frames[i], SPANS[s], K4_EDGE_GUARD_BINS, buffer, cropped);
               CheckCropExcludesPad(frames[i], cropped,
                                    Format('B frame %d at %d', [i, SPANS[s]]));
               end;
            end;
         end;
   finally
      probe.Free;
   end;

   CheckEquals(10, aFrames, 'pan A frames in the capture');
end;

procedure TK4SpectrumCropTests.Test_Tiers_CarriesEveryWidth;
const
   WIDTHS: array[0..4] of Int64 = (24000, 48000, 96000, 192000, 384000);
   COUNTS: array[0..4] of Integer = (2, 3, 3, 3, 3);
var
   frames: TArray<TSpectrumFrame>;
   i, w, n: Integer;
begin
   BeginTest('Test_Tiers_CarriesEveryWidth');
   frames := LoadFrames(TIERS_FIXTURE);
   CheckEquals(14, Length(frames), 'frames in the tier capture');

   for w := 0 to High(WIDTHS) do
      begin
      n := 0;

      for i := 0 to High(frames) do
         begin
         if (frames[i].SourceId = 'A') and (frames[i].SpanHz = WIDTHS[w]) then
            begin
            Inc(n);
            end;
         end;

      CheckEquals(COUNTS[w], n, Format('pan A frames %d Hz wide', [WIDTHS[w]]));
      end;
end;

procedure TK4SpectrumCropTests.Test_Tiers_CropExcludesThePad;
type
   TTier = record
      Width: Int64;
      Span: Integer;
   end;
const
   (* Every #SPN the 2026-11-02 sweep set, against the frame width the K4
      served it at. *)
   TIERS: array[0..9] of TTier = (
      (Width:  24000; Span:   5000),
      (Width:  24000; Span:  10000),
      (Width:  48000; Span:  20000),
      (Width:  48000; Span:  40000),
      (Width:  96000; Span:  40000),
      (Width:  96000; Span:  80000),
      (Width: 192000; Span: 150000),
      (Width: 384000; Span: 190000),
      (Width: 384000; Span: 250000),
      (Width: 384000; Span: 368000));
var
   frames: TArray<TSpectrumFrame>;
   probe: TK4CropProbe;
   i, t: Integer;
   padLeft, padRight: Integer;
   first, ran: Integer;
begin
   BeginTest('Test_Tiers_CropExcludesThePad');
   frames := LoadFrames(TIERS_FIXTURE);
   probe := NewProbe;
   ran := 0;

   try
      for t := 0 to High(TIERS) do
         begin
         probe.ProcessMsg(Format('#SPN%d', [TIERS[t].Span]));

         for i := 0 to High(frames) do
            begin
            if frames[i].SpanHz <> TIERS[t].Width then
               begin
               Continue;
               end;

            probe.Feed(frames[i]);
            Inc(ran);

            (* Measured per frame, because not every frame has a pad: real
               24 kHz frames do not.  The fixture's other "24 kHz" frame does,
               because its header already says 24000 while its bins are still
               the 48 kHz layout (sweep frame 192, just after #SPN 5000;
               docs/PANADAPTER_LCL_DESIGN.md 10.4).  Wherever there is a pad,
               the crop keeps none of it. *)
            PadRuns(frames[i], padLeft, padRight);
            first := (frames[i].BinCount - FLast.BinCount) div 2;

            Check(FLast.BinCount < frames[i].BinCount,
                  Format('%d Hz frame %d at #SPN %d: cropped', [TIERS[t].Width, i, TIERS[t].Span]));
            Check(first >= padLeft,
                  Format('%d Hz frame %d at #SPN %d: keeps bin %d, left pad to %d',
                         [TIERS[t].Width, i, TIERS[t].Span, first, padLeft - 1]));
            Check(first + FLast.BinCount <= frames[i].BinCount - padRight,
                  Format('%d Hz frame %d at #SPN %d: keeps bin %d, right pad from %d',
                         [TIERS[t].Width, i, TIERS[t].Span, first + FLast.BinCount - 1,
                          frames[i].BinCount - padRight]));
            end;
         end;
   finally
      probe.Free;
   end;

   // 24k 2x2, 48k 2x3, 96k 2x3, 192k 1x3, 384k 3x3.
   CheckEquals(28, ran, 'frame and span pairs checked');
end;

procedure TK4SpectrumCropTests.Test_Tiers_GuardIsNeededAt368k;
var
   frames: TArray<TSpectrumFrame>;
   buffer: TSpectrumBins;
   cropped: TSpectrumFrame;
   i: Integer;
   padLeft, padRight: Integer;
   first: Integer;
   keptPad: Integer;
begin
   BeginTest('Test_Tiers_GuardIsNeededAt368k');
   frames := LoadFrames(TIERS_FIXTURE);
   keptPad := 0;

   (* WHY K4_EDGE_GUARD_BINS EXISTS.  A plain crop to #SPN 368000 keeps 1964 of
      2048 bins, and on the widest-pad 384 kHz frames that keeps pad.  If the
      radio ever stops padding this wide, this fails and the guard can go. *)
   for i := 0 to High(frames) do
      begin
      if frames[i].SpanHz <> 384000 then
         begin
         Continue;
         end;

      SpectrumCropCentred(frames[i], 368000, 0, buffer, cropped);
      PadRuns(frames[i], padLeft, padRight);
      first := (frames[i].BinCount - cropped.BinCount) div 2;

      if (first < padLeft) or (first + cropped.BinCount > frames[i].BinCount - padRight) then
         begin
         Inc(keptPad);
         end;
      end;

   Check(keptPad > 0, 'without the guard a 368 kHz crop should keep pad on some 384 kHz frame');
end;

// ---------------------------------------------------------------------------

procedure TK4SpectrumCropTests.RunAllTests;
begin
   Test_Crop_KeptCountAndSpan;
   Test_Crop_BinHzIsContinuous;
   Test_Crop_PassesThrough;
   Test_Crop_ReusesTheBuffer;

   Test_Radio_UnknownSpanPassesThrough;
   Test_Radio_MainPanIsCroppedToSPN;
   Test_Radio_OtherSourcesPassThrough;
   Test_Radio_FrameAtTheOldWidth;

   Test_Sample_PadIsWhereItWasMeasured;
   Test_Sample_CropExcludesThePad;
   Test_Tiers_CarriesEveryWidth;
   Test_Tiers_CropExcludesThePad;
   Test_Tiers_GuardIsNeededAt368k;
end;

end.
