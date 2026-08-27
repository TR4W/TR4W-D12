unit uTestIcomScope;
{$I ..\..\src\tr4w.inc}

{
  Unit tests for uIcomScope -- the offline half of the Icom panadapter.
  Everything here runs with no radio, no socket and no UI, which is the whole
  reason the decoder was built as a pure unit.

  THE EVIDENCE HERE IS SYNTHETIC, AND THAT IS A WEAKER CLAIM THAN THE K4'S.
  uTestK4Spectrum is driven by fixtures/k4pan-sample.bin, 30 packets recorded
  off a real K4, so its assertions are frozen contents of a capture.  Nothing
  equivalent exists for Icom yet: no scope capture has been taken here, and
  HamLib carries no spectrum geometry at all for the IC-9700, IC-705 or
  IC-7760.  So the frames below are BUILT from the published layout, and what
  they pin is that this decoder implements the layout as three independent
  references describe it -- NOT that any radio actually sends it.

  That distinction is the point of the split, and it is why the numbers used
  are the ones the references disagree about or that a reasonable
  implementation gets wrong:

    * the division counters are BCD, so division 11 is $11 and a binary read
      gives 17 (AetherSDR names this trap; HamLib decodes with from_bcd);
    * centre mode's second frequency is a HALF-width, so the span is 2x it
      (both references say so, and both say implementations get it backwards);
    * a lower edge can be NEGATIVE via $F in the 1 GHz digit (AetherSDR
      handles it, HamLib does not);
    * payload byte [0] is a SCOPE ID and dual-scope rigs interleave two sweeps
      down one link (HamLib handles it, AetherSDR does not).

  Each of those has a test whose failure mode is a plausible wrong picture
  rather than a crash, which is exactly the class a bench session is bad at
  catching and a pin test is good at.

  WHEN A CAPTURE ARRIVES, this file gains fixture-driven tests beside these --
  it does not lose the synthetic ones.  They cover the paths a given rig will
  never exercise: no LAN capture can exercise multi-division assembly, and no
  single-scope rig can exercise scope-id demultiplexing.
}

interface

uses
   SysUtils, Classes, uTR4WTestFramework, uSpectrumTypes, uIcomScope;

type
   TIcomScopeTests = class(TTestCase)
   protected
      // ---- frame builders -------------------------------------------------
      function BcdByte(AValue: Integer): Byte;
      function EncodeEdge(AHz: Int64; ABytes: Integer): TBytes;
      function BuildHeaderDivision(AScopeId, ADivisionMax: Integer;
                                   AMode: TIcomScopeMode;
                                   AFreqA, AFreqB: Int64;
                                   AOutOfRange: Boolean;
                                   const ALevels: TBytes): TBytes;
      function BuildContinuation(AScopeId, ADivision, ADivisionMax: Integer;
                                 const ALevels: TBytes): TBytes;
      function Ramp(ACount, AStart, AStep: Integer): TBytes;
      procedure CheckEqualsI64(const Expected, Actual: Int64; const Msg: string);
      procedure CheckClose(const Expected, Actual: Single; const Msg: string);

      // ---- BCD ------------------------------------------------------------
      procedure Test_BcdByte_DecodesDivisionEleven;
      procedure Test_BcdByte_RefusesNonDecimalNibble;
      procedure Test_Edge_DecodesLittleEndianBcd;
      procedure Test_Edge_DecodesNegativeLowerEdge;
      procedure Test_Edge_RefusesCorruptNibbleElsewhere;
      procedure Test_Edge_RefusesShortBuffer;

      // ---- geometry -------------------------------------------------------
      procedure Test_Geometry_SeedsTheEstimate;
      procedure Test_Geometry_RejectsUnusable;

      // ---- the LAN path (one frame, whole sweep) --------------------------
      procedure Test_Lan_CentreModeDoublesTheHalfWidth;
      procedure Test_Lan_FixedModeUsesEdgesDirectly;
      procedure Test_Lan_ScrollModesAreGeometricallyFixed;
      procedure Test_Lan_LargeGeometryDecodes;

      // ---- the serial path (divisions) ------------------------------------
      procedure Test_Usb_ElevenDivisionsAssemble;
      procedure Test_Usb_DivisionGapAbandonsTheSweep;
      procedure Test_Usb_ContinuationWithoutHeaderIsRefused;
      procedure Test_Usb_RestartDiscardsAHalfBuiltSweep;

      // ---- scope demultiplexing -------------------------------------------
      procedure Test_TwoScopesInterleaveIndependently;
      procedure Test_ScopeIdBecomesSourceId;
      procedure Test_ScopeIdOutOfRangeIsRefused;

      // ---- refusals -------------------------------------------------------
      procedure Test_ShortPayloadIsRefused;
      procedure Test_UnknownModeIsRefusedNotDefaulted;
      procedure Test_OutOfRangeYieldsAFlatSweep;
      procedure Test_ExcessLevelsAreTruncatedNotOverrun;

      // ---- sweep -> TSpectrumFrame ----------------------------------------
      procedure Test_Frame_CarriesCentreAndSpan;
      procedure Test_Frame_MapsLevelsAtTheEstimatedRate;
      procedure Test_Frame_ClampsLevelsAboveTheRange;
      procedure Test_Frame_NoiseFloorIsMeasuredFromTheSweep;
      procedure Test_Frame_FloorTracksAQuietBandDown;
      procedure Test_Percentile_IsExactOnAKnownDistribution;
      procedure Test_Frame_BinCountIsTheGeometryNotAConstant;
      procedure Test_Frame_SequenceAdvancesPerScope;

   public
      procedure RunAllTests; override;
   end;

implementation

const
   // The two published geometries.  Named here rather than reused from the
   // unit's constants in every assertion, so a change to those constants shows
   // up as a test failure instead of silently agreeing with itself.
   POINTS_475 = 475;
   LEVEL_160  = 160;
   POINTS_689 = 689;
   LEVEL_200  = 200;

   // 3 + 1 + 5*2 + 1.  Written out so the test does not compute the same thing
   // the code computes -- if the header size is wrong in one, this catches it.
   HEADER_LEN = 15;

   // What HamLib publishes as the per-division payload for every Icom that has
   // spectrum caps.  475/50 -> 10 data divisions + 1 header = 11.
   DIVISION_PAYLOAD = 50;

// ---------------------------------------------------------------------------
// Builders
// ---------------------------------------------------------------------------

function TIcomScopeTests.BcdByte(AValue: Integer): Byte;
begin
   Result := Byte((((AValue div 10) mod 10) shl 4) or (AValue mod 10));
end;

function TIcomScopeTests.EncodeEdge(AHz: Int64; ABytes: Integer): TBytes;
var
   i: Integer;
   digits: Int64;
   negative: Boolean;
   lo, hi: Integer;
begin
   SetLength(Result, ABytes);

   negative := AHz < 0;
   digits := Abs(AHz);

   // Least-significant pair FIRST -- the opposite of every other Icom field,
   // and the single most common source of Icom bugs.
   for i := 0 to ABytes - 1 do
      begin
      lo := digits mod 10;
      digits := digits div 10;
      hi := digits mod 10;
      digits := digits div 10;
      Result[i] := Byte((hi shl 4) or lo);
      end;

   if negative then
      begin
      // $F in the 1 GHz digit: the high nibble of the LAST byte.
      Result[ABytes - 1] := Byte((Result[ABytes - 1] and $0F) or $F0);
      end;
end;

function TIcomScopeTests.BuildHeaderDivision(AScopeId, ADivisionMax: Integer;
                                             AMode: TIcomScopeMode;
                                             AFreqA, AFreqB: Int64;
                                             AOutOfRange: Boolean;
                                             const ALevels: TBytes): TBytes;
var
   a, b: TBytes;
   i: Integer;
begin
   SetLength(Result, HEADER_LEN + Length(ALevels));

   Result[0] := Byte(AScopeId);
   Result[1] := BcdByte(1);                // this IS the header division
   Result[2] := BcdByte(ADivisionMax);
   Result[3] := Byte(Ord(AMode));

   a := EncodeEdge(AFreqA, 5);
   b := EncodeEdge(AFreqB, 5);

   for i := 0 to 4 do
      begin
      Result[4 + i] := a[i];
      Result[9 + i] := b[i];
      end;

   if AOutOfRange then
      begin
      Result[14] := $01;
      end
   else
      begin
      Result[14] := $00;
      end;

   for i := 0 to Length(ALevels) - 1 do
      begin
      Result[HEADER_LEN + i] := ALevels[i];
      end;
end;

function TIcomScopeTests.BuildContinuation(AScopeId, ADivision, ADivisionMax: Integer;
                                           const ALevels: TBytes): TBytes;
var
   i: Integer;
begin
   SetLength(Result, 3 + Length(ALevels));

   Result[0] := Byte(AScopeId);
   Result[1] := BcdByte(ADivision);
   Result[2] := BcdByte(ADivisionMax);

   for i := 0 to Length(ALevels) - 1 do
      begin
      Result[3 + i] := ALevels[i];
      end;
end;

function TIcomScopeTests.Ramp(ACount, AStart, AStep: Integer): TBytes;
var
   i: Integer;
   v: Integer;
begin
   SetLength(Result, ACount);

   for i := 0 to ACount - 1 do
      begin
      v := AStart + (i * AStep);

      if v < 0 then
         begin
         v := 0;
         end;

      if v > 255 then
         begin
         v := 255;
         end;

      Result[i] := Byte(v);
      end;
end;

procedure TIcomScopeTests.CheckEqualsI64(const Expected, Actual: Int64; const Msg: string);
begin
   Check(Expected = Actual,
         Format('%s: expected %d, got %d', [Msg, Expected, Actual]));
end;

procedure TIcomScopeTests.CheckClose(const Expected, Actual: Single; const Msg: string);
begin
   Check(Abs(Expected - Actual) < 0.01,
         Format('%s: expected %.4f, got %.4f', [Msg, Expected, Actual]));
end;

// ---------------------------------------------------------------------------
// BCD
// ---------------------------------------------------------------------------

procedure TIcomScopeTests.Test_BcdByte_DecodesDivisionEleven;
begin
   { THE TRAP THAT WOULD HAVE SHIPPED.  Division 11 arrives as $11.  Read as a
     plain byte it is 17, which is past every division maximum, so the sweep is
     rejected -- and it can only happen on the USB transport, where a division
     maximum above 9 exists at all.  Over LAN the maximum is 1, so a binary
     read is indistinguishable from a correct one and the defect never fires on
     the transport most operators use. }
   CheckEquals(11, IcomScopeDecodeBcdByte($11), 'division 11 is BCD $11');
   CheckEquals(15, IcomScopeDecodeBcdByte($15), 'division 15 (IC-7610 over USB)');
   CheckEquals(1, IcomScopeDecodeBcdByte($01), 'division 1');
   CheckEquals(99, IcomScopeDecodeBcdByte($99), 'the top of the BCD range');
end;

procedure TIcomScopeTests.Test_BcdByte_RefusesNonDecimalNibble;
begin
   { A REFUSAL, NOT A VALUE.  $0B is what a binary encoder would emit for 11,
     so accepting it would make a wrong encoder look right.  More to the point,
     a division counter fabricated out of a corrupt byte is how one sweep gets
     assembled out of two. }
   CheckEquals(-1, IcomScopeDecodeBcdByte($0B), 'low nibble B is not a digit');
   CheckEquals(-1, IcomScopeDecodeBcdByte($A0), 'high nibble A is not a digit');
   CheckEquals(-1, IcomScopeDecodeBcdByte($FF), 'neither nibble is a digit');
end;

procedure TIcomScopeTests.Test_Edge_DecodesLittleEndianBcd;
var
   raw: TBytes;
   hz: Int64;
begin
   { 14.250000 MHz is TEN digits, "0014250000", split into pairs and sent
     LEAST-SIGNIFICANT PAIR FIRST: 00 00 25 14 00.

     WRITTEN OUT BY HAND, and it caught a wrong reference on the first run.
     AetherSDR's CivCodec.h states this same example as "14.250000 MHz ->
     00 60 25 14 00" (src/core/backends/icom/CivCodec.h, the endianness note).
     Decode those bytes and they are 00 14 25 60 00 = 14,256,000 Hz -- six kHz
     off.  The decoder was right and the transcription was wrong, which is the
     whole reason this assertion is a literal byte sequence rather than a call
     to EncodeEdge: a test that builds its input with the same arithmetic the
     code uses proves only that the code agrees with itself. }
   SetLength(raw, 5);
   raw[0] := $00;
   raw[1] := $00;
   raw[2] := $25;
   raw[3] := $14;
   raw[4] := $00;

   Check(IcomScopeDecodeEdgeHz(raw, 0, 5, hz), '14.25 MHz should decode');
   CheckEqualsI64(14250000, hz, '14.250000 MHz little-endian BCD');

   // And the builder this file uses elsewhere must agree with the hand-typed
   // bytes, or every other test here is built on a private convention.
   raw := EncodeEdge(14250000, 5);
   CheckEquals($00, raw[0], 'byte 0 is the 1 Hz / 10 Hz pair');
   CheckEquals($00, raw[1], 'byte 1 is the 100 Hz / 1 kHz pair');
   CheckEquals($25, raw[2], 'byte 2 is the 10 kHz / 100 kHz pair');
   CheckEquals($14, raw[3], 'byte 3 is the 1 MHz / 10 MHz pair');
   CheckEquals($00, raw[4], 'byte 4 is the 100 MHz / 1 GHz pair');
end;

procedure TIcomScopeTests.Test_Edge_DecodesNegativeLowerEdge;
var
   raw: TBytes;
   hz: Int64;
begin
   { A LOWER EDGE GENUINELY CAN BE NEGATIVE.  The IC-7300MK2's guide documents
     $F in the 1 GHz digit for when a wide span sits near the bottom of the
     tuning range and the display window extends below 0 Hz.  HamLib's parser
     uses plain unsigned from_bcd here and would read this as a huge positive
     frequency; AetherSDR handles it.  Clamping to zero instead would keep the
     number plausible and silently shrink the span, so EVERY bin would map to
     the wrong frequency -- which reads as a tuning fault, not a decode fault. }
   raw := EncodeEdge(-50000, 5);
   Check(IcomScopeDecodeEdgeHz(raw, 0, 5, hz), 'a signed lower edge should decode');
   CheckEqualsI64(-50000, hz, 'negative lower edge');
end;

procedure TIcomScopeTests.Test_Edge_RefusesCorruptNibbleElsewhere;
var
   raw: TBytes;
   hz: Int64;
begin
   { THE SIGN LIVES IN EXACTLY ONE NIBBLE.  Relaxing $F everywhere would give
     back the fabricated-frequency behaviour uIcomCIV exists to prevent -- one
     corrupt byte shifting every digit and producing a wildly wrong number that
     still looks like a frequency. }
   raw := EncodeEdge(14250000, 5);
   raw[2] := $F5;      // $F in a middle byte is corruption, not a sign
   Check(not IcomScopeDecodeEdgeHz(raw, 0, 5, hz),
         '$F outside the 1 GHz digit must be refused');

   raw := EncodeEdge(14250000, 5);
   raw[4] := (raw[4] and $F0) or $0B;   // low nibble of the last byte
   Check(not IcomScopeDecodeEdgeHz(raw, 0, 5, hz),
         'a non-decimal low nibble must be refused even in the sign byte');
end;

procedure TIcomScopeTests.Test_Edge_RefusesShortBuffer;
var
   raw: TBytes;
   hz: Int64;
begin
   raw := EncodeEdge(14250000, 5);
   Check(not IcomScopeDecodeEdgeHz(raw, 2, 5, hz), 'reading past the end must refuse');
   Check(not IcomScopeDecodeEdgeHz(raw, 0, 0, hz), 'a zero-length field must refuse');
   Check(not IcomScopeDecodeEdgeHz(raw, -1, 5, hz), 'a negative offset must refuse');
end;

// ---------------------------------------------------------------------------
// Geometry
// ---------------------------------------------------------------------------

procedure TIcomScopeTests.Test_Geometry_SeedsTheEstimate;
var
   g: TIcomScopeGeometry;
begin
   g := IcomScopeGeometry(POINTS_475, LEVEL_160);

   CheckEquals(POINTS_475, g.Points, 'points');
   CheckEquals(LEVEL_160, g.MaxLevel, 'max level');
   CheckEquals(5, g.FreqBytes, 'five-byte frequencies unless a model says otherwise');

   { 0.5 dB PER UNIT IS AN ESTIMATE WITH A SOURCE.  HamLib publishes a
     signal-strength range per model and all three of its published ones reduce
     to this: IC-7300 0..160 over -80..0, IC-7610 and IC-785x 0..200 over
     -100..0.  Pinned so that changing it is a deliberate act -- it is the one
     number in this unit that a bench measurement is expected to revise. }
   CheckClose(0.5, g.DbPerUnit, 'the estimated dB per display unit');
end;

procedure TIcomScopeTests.Test_Geometry_RejectsUnusable;
var
   g: TIcomScopeGeometry;
begin
   { A SILENTLY-DEFAULTED GEOMETRY READS AS A LEGAL ZERO.  A radio that
     declares rcSpectrum but never states its point count would otherwise
     decode every sweep into nothing at all, and no compiler diagnostic exists
     for it.  The decoder asks this question before it touches a byte. }
   g := IcomScopeGeometry(0, LEVEL_160);
   Check(not IcomScopeGeometryIsValid(g), 'zero points is not a geometry');

   g := IcomScopeGeometry(POINTS_475, 0);
   Check(not IcomScopeGeometryIsValid(g), 'zero level range is not a geometry');

   g := IcomScopeGeometry(POINTS_475, LEVEL_160);
   g.DbPerUnit := 0;
   Check(not IcomScopeGeometryIsValid(g), 'zero dB per unit is not a geometry');

   g := IcomScopeGeometry(POINTS_475, LEVEL_160);
   g.FreqBytes := 0;
   Check(not IcomScopeGeometryIsValid(g), 'zero frequency bytes is not a geometry');

   Check(IcomScopeGeometryIsValid(IcomScopeGeometry(POINTS_475, LEVEL_160)),
         'a seeded geometry is usable');
end;

// ---------------------------------------------------------------------------
// The LAN path
// ---------------------------------------------------------------------------

procedure TIcomScopeTests.Test_Lan_CentreModeDoublesTheHalfWidth;
var
   decoder: TIcomScopeDecoder;
   payload: TBytes;
   sweep: TIcomScopeSweep;
begin
   { ICOM'S SPAN IS A HALF-WIDTH.  The front panel reads "+/-100k" and the
     display covers 200 kHz.  A decoder that treats it as a total width is
     right about the centre and wrong by 2x about the extent, so signals appear
     at half or double their true offset from centre -- which an operator reads
     as a tuning bug, not a geometry bug.  Both references call this out by
     name, and HamLib's parser literally multiplies by two. }
   decoder := TIcomScopeDecoder.Create(IcomScopeGeometry(POINTS_475, LEVEL_160));

   try
      payload := BuildHeaderDivision(0, 1, ismCentre,
                                     14250000,     // centre
                                     100000,       // HALF-width: +/-100 kHz
                                     False, Ramp(POINTS_475, 20, 0));

      Check(decoder.Feed(payload, Length(payload), sweep) = issComplete,
            'a LAN sweep completes in one frame');

      CheckEqualsI64(14150000, sweep.StartHz, 'lower edge is centre - span');
      CheckEqualsI64(14350000, sweep.EndHz, 'upper edge is centre + span');
      CheckEquals(POINTS_475, Length(sweep.Levels), 'a full sweep of levels');
      CheckEquals(1, Integer(decoder.SweepsOut), 'one sweep out');
   finally
      decoder.Free;
   end;
end;

procedure TIcomScopeTests.Test_Lan_FixedModeUsesEdgesDirectly;
var
   decoder: TIcomScopeDecoder;
   payload: TBytes;
   sweep: TIcomScopeSweep;
begin
   decoder := TIcomScopeDecoder.Create(IcomScopeGeometry(POINTS_475, LEVEL_160));

   try
      payload := BuildHeaderDivision(0, 1, ismFixed,
                                     14000000, 14350000,
                                     False, Ramp(POINTS_475, 20, 0));

      Check(decoder.Feed(payload, Length(payload), sweep) = issComplete,
            'fixed mode completes');
      CheckEqualsI64(14000000, sweep.StartHz, 'fixed mode reports the lower edge');
      CheckEqualsI64(14350000, sweep.EndHz, 'fixed mode reports the upper edge');
   finally
      decoder.Free;
   end;
end;

procedure TIcomScopeTests.Test_Lan_ScrollModesAreGeometricallyFixed;
var
   decoder: TIcomScopeDecoder;
   payload: TBytes;
   sweep: TIcomScopeSweep;
   mode: TIcomScopeMode;
begin
   { THE SCROLL MODES REPORT EDGES, LIKE FIXED MODE.  They are kept as distinct
     enum values because they are distinct radio states an operator can see, but
     the geometry has only two cases and this pins that -- a decoder that grew a
     third branch here would be inventing one. }
   for mode := ismScrollCentre to ismScrollFixed do
      begin
      decoder := TIcomScopeDecoder.Create(IcomScopeGeometry(POINTS_475, LEVEL_160));

      try
         payload := BuildHeaderDivision(0, 1, mode, 7000000, 7300000,
                                        False, Ramp(POINTS_475, 20, 0));

         Check(decoder.Feed(payload, Length(payload), sweep) = issComplete,
               'a scroll mode completes');
         Check(sweep.Mode = mode, 'the scroll mode is carried through, not collapsed');
         CheckEqualsI64(7000000, sweep.StartHz, 'scroll mode reports the lower edge');
         CheckEqualsI64(7300000, sweep.EndHz, 'scroll mode reports the upper edge');
      finally
         decoder.Free;
      end;
      end;
end;

procedure TIcomScopeTests.Test_Lan_LargeGeometryDecodes;
var
   decoder: TIcomScopeDecoder;
   payload: TBytes;
   sweep: TIcomScopeSweep;
   frame: TSpectrumFrame;
begin
   { THE IC-7610 IS THE REASON GEOMETRY IS NOT A CONSTANT: 689 points and a
     0..200 level range, both different from the IC-7300 family.  A decoder
     that compiled 475 in would truncate every 7610 sweep by 214 bins and the
     right-hand third of the display would be flat. }
   decoder := TIcomScopeDecoder.Create(IcomScopeGeometry(POINTS_689, LEVEL_200));

   try
      payload := BuildHeaderDivision(0, 1, ismFixed, 14000000, 14500000,
                                     False, Ramp(POINTS_689, 10, 0));

      Check(decoder.Feed(payload, Length(payload), sweep) = issComplete,
            'a 689-point sweep completes');
      CheckEquals(POINTS_689, Length(sweep.Levels), '689 bins, not 475');

      frame := IcomSweepToSpectrumFrame(sweep, IcomScopeGeometry(POINTS_689, LEVEL_200),
                                        IcomScopeSourceId(0));
      CheckEquals(POINTS_689, frame.BinCount, 'BinCount follows the geometry');
   finally
      decoder.Free;
   end;
end;

// ---------------------------------------------------------------------------
// The serial path
// ---------------------------------------------------------------------------

procedure TIcomScopeTests.Test_Usb_ElevenDivisionsAssemble;
var
   decoder: TIcomScopeDecoder;
   payload: TBytes;
   sweep: TIcomScopeSweep;
   d: Integer;
   status: TIcomScopeStatus;
   remaining: Integer;
   take: Integer;
   levels: TBytes;
   emptyLevels: TBytes;
begin
   { THE USB SHAPE, ARITHMETICALLY DERIVED.  HamLib publishes 50 bytes per
     division for every Icom with spectrum caps, so 475 points is 10 data
     divisions -- the last carrying 25 -- plus one header division that carries
     no waveform at all.  11 divisions total, which is exactly the number
     AetherSDR records from Icom's own guide.  Two derivations agreeing is why
     this shape is trusted with no capture behind it.

     THIS PATH CANNOT BE TESTED BY ANY LAN CAPTURE, which is the argument for
     writing it synthetically rather than deferring it. }
   decoder := TIcomScopeDecoder.Create(IcomScopeGeometry(POINTS_475, LEVEL_160));

   try
      SetLength(emptyLevels, 0);
      payload := BuildHeaderDivision(0, 11, ismFixed, 14000000, 14200000,
                                     False, emptyLevels);

      status := decoder.Feed(payload, Length(payload), sweep);
      Check(status = issAssembling, 'the header division starts assembly, it does not finish it');

      remaining := POINTS_475;

      for d := 2 to 11 do
         begin
         take := DIVISION_PAYLOAD;

         if take > remaining then
            begin
            take := remaining;
            end;

         levels := Ramp(take, 30 + d, 0);
         payload := BuildContinuation(0, d, 11, levels);
         status := decoder.Feed(payload, Length(payload), sweep);
         Dec(remaining, take);

         if d < 11 then
            begin
            Check(status = issAssembling,
                  Format('division %d continues assembly', [d]));
            end;
         end;

      Check(status = issComplete, 'the last division completes the sweep');
      CheckEquals(POINTS_475, Length(sweep.Levels), 'a full sweep of levels');
      CheckEquals(0, remaining, '475 points is 9 full divisions and a 25-byte tail');

      // Position matters: the waveform is positional and carries no index, so a
      // sweep assembled in the wrong order looks like real data.  Each division
      // was filled with its own value, so the boundaries are checkable.
      CheckEquals(32, sweep.Levels[0], 'the first division landed at the start');
      CheckEquals(41, sweep.Levels[POINTS_475 - 1], 'the last division landed at the end');
   finally
      decoder.Free;
   end;
end;

procedure TIcomScopeTests.Test_Usb_DivisionGapAbandonsTheSweep;
var
   decoder: TIcomScopeDecoder;
   payload: TBytes;
   sweep: TIcomScopeSweep;
   emptyLevels: TBytes;
begin
   { A GAP MAKES THE SWEEP UNRECOVERABLE.  The waveform is positional and has
     no per-division index inside the payload, so there is nothing to re-align
     against; concatenating what follows draws a SHIFTED trace that looks like
     real data.  Abandoning is the only honest option, and it must be counted
     rather than logged per event. }
   decoder := TIcomScopeDecoder.Create(IcomScopeGeometry(POINTS_475, LEVEL_160));

   try
      SetLength(emptyLevels, 0);
      payload := BuildHeaderDivision(0, 11, ismFixed, 14000000, 14200000,
                                     False, emptyLevels);
      decoder.Feed(payload, Length(payload), sweep);

      payload := BuildContinuation(0, 2, 11, Ramp(DIVISION_PAYLOAD, 40, 0));
      Check(decoder.Feed(payload, Length(payload), sweep) = issAssembling, 'division 2 is in order');

      // Division 3 is lost on the wire; division 4 arrives.
      payload := BuildContinuation(0, 4, 11, Ramp(DIVISION_PAYLOAD, 40, 0));
      Check(decoder.Feed(payload, Length(payload), sweep) = issBadDivision,
            'a gap is refused');
      CheckEquals(1, Integer(decoder.Abandoned), 'the abandoned sweep is counted');

      // And nothing after it is accepted until a new header division arrives:
      // a partial sweep must not resume as though the gap had not happened.
      payload := BuildContinuation(0, 5, 11, Ramp(DIVISION_PAYLOAD, 40, 0));
      Check(decoder.Feed(payload, Length(payload), sweep) = issBadDivision,
            'assembly does not resume mid-sweep');
      CheckEquals(0, Integer(decoder.SweepsOut), 'no sweep was produced');
   finally
      decoder.Free;
   end;
end;

procedure TIcomScopeTests.Test_Usb_ContinuationWithoutHeaderIsRefused;
var
   decoder: TIcomScopeDecoder;
   payload: TBytes;
   sweep: TIcomScopeSweep;
begin
   { NORMAL RIGHT AFTER A CONNECT, and deliberately NOT counted as a rejection:
     joining a stream mid-sweep is expected, and a counter that ticks on every
     connect tells you nothing about the connects where something is wrong. }
   decoder := TIcomScopeDecoder.Create(IcomScopeGeometry(POINTS_475, LEVEL_160));

   try
      payload := BuildContinuation(0, 5, 11, Ramp(DIVISION_PAYLOAD, 40, 0));
      Check(decoder.Feed(payload, Length(payload), sweep) = issBadDivision,
            'a continuation with no header is refused');
      CheckEquals(0, Integer(decoder.Abandoned), 'nothing was abandoned -- there was nothing to abandon');
      CheckEquals(0, Integer(decoder.SweepsOut), 'no sweep');
   finally
      decoder.Free;
   end;
end;

procedure TIcomScopeTests.Test_Usb_RestartDiscardsAHalfBuiltSweep;
var
   decoder: TIcomScopeDecoder;
   payload: TBytes;
   sweep: TIcomScopeSweep;
   emptyLevels: TBytes;
begin
   { A HEADER DIVISION RESTARTS ASSEMBLY UNCONDITIONALLY.  If a previous sweep
     was left half-built by a lost packet, this is where it goes -- keeping it
     would splice two sweeps into one trace, at a seam nothing marks. }
   decoder := TIcomScopeDecoder.Create(IcomScopeGeometry(POINTS_475, LEVEL_160));

   try
      SetLength(emptyLevels, 0);
      payload := BuildHeaderDivision(0, 11, ismFixed, 14000000, 14200000,
                                     False, emptyLevels);
      decoder.Feed(payload, Length(payload), sweep);

      payload := BuildContinuation(0, 2, 11, Ramp(DIVISION_PAYLOAD, 99, 0));
      decoder.Feed(payload, Length(payload), sweep);

      // A new sweep starts, on a different frequency, before the old one ended.
      payload := BuildHeaderDivision(0, 1, ismFixed, 21000000, 21200000,
                                     False, Ramp(POINTS_475, 7, 0));
      Check(decoder.Feed(payload, Length(payload), sweep) = issComplete,
            'the new sweep completes on its own terms');
      CheckEqualsI64(21000000, sweep.StartHz, 'the new sweep''s frequency, not the old one''s');
      CheckEquals(7, sweep.Levels[0], 'no level from the abandoned sweep survived');
   finally
      decoder.Free;
   end;
end;

// ---------------------------------------------------------------------------
// Scope demultiplexing
// ---------------------------------------------------------------------------

procedure TIcomScopeTests.Test_TwoScopesInterleaveIndependently;
var
   decoder: TIcomScopeDecoder;
   payload: TBytes;
   sweep: TIcomScopeSweep;
   emptyLevels: TBytes;
begin
   { THE FINDING THAT CHANGED THIS DECODER.  HamLib reads payload byte [0] as a
     scope id (0 = Main, 1 = Sub) and keys a per-scope cache with it; AetherSDR
     calls the same byte "0x00, fixed" and ignores it.  On a single-scope radio
     the two are indistinguishable -- but the IC-9700, IC-7610 and IC-7760 all
     have two, and ignoring the id splices Main and Sub sweeps into one trace.
     The failure looks like corrupt spectrum rather than a decode bug, which is
     why it needs a test and not a comment.

     Interleaved here the way a real dual-scope rig sends them: two sweeps in
     flight at once, each on its own frequency. }
   decoder := TIcomScopeDecoder.Create(IcomScopeGeometry(POINTS_475, LEVEL_160));

   try
      SetLength(emptyLevels, 0);

      // Both scopes start a multi-division sweep.
      payload := BuildHeaderDivision(0, 11, ismFixed, 14000000, 14200000,
                                     False, emptyLevels);
      Check(decoder.Feed(payload, Length(payload), sweep) = issAssembling, 'scope 0 starts');

      payload := BuildHeaderDivision(1, 11, ismFixed, 21000000, 21200000,
                                     False, emptyLevels);
      Check(decoder.Feed(payload, Length(payload), sweep) = issAssembling, 'scope 1 starts');

      // Scope 1 finishes first, in one go, without disturbing scope 0.
      payload := BuildHeaderDivision(1, 1, ismFixed, 21000000, 21200000,
                                     False, Ramp(POINTS_475, 55, 0));
      Check(decoder.Feed(payload, Length(payload), sweep) = issComplete, 'scope 1 completes');
      CheckEquals(1, Integer(sweep.ScopeId), 'the completed sweep is scope 1');
      CheckEqualsI64(21000000, sweep.StartHz, 'and carries scope 1''s frequency');

      // Scope 0 is still assembling and still its own.
      payload := BuildContinuation(0, 2, 11, Ramp(DIVISION_PAYLOAD, 33, 0));
      Check(decoder.Feed(payload, Length(payload), sweep) = issAssembling,
            'scope 0 was not disturbed by scope 1 completing');
   finally
      decoder.Free;
   end;
end;

procedure TIcomScopeTests.Test_ScopeIdBecomesSourceId;
var
   decoder: TIcomScopeDecoder;
   payload: TBytes;
   sweep: TIcomScopeSweep;
   frame: TSpectrumFrame;
begin
   { SourceId IS THE FIELD FOR THIS.  The K4 puts 'A'/'B'/'Y' in it and streams
     all of them down one socket; an Icom's Main and Sub are the same shape of
     problem, so they use the same mechanism and the window needs no Icom code
     at all.

     SPELLED IN ONE PLACE.  The window filters on string equality and nothing
     validates the spelling, so a producer and a consumer that disagree produce
     a window that simply never draws -- with no error anywhere. }
   decoder := TIcomScopeDecoder.Create(IcomScopeGeometry(POINTS_475, LEVEL_160));

   try
      payload := BuildHeaderDivision(1, 1, ismFixed, 14000000, 14200000,
                                     False, Ramp(POINTS_475, 20, 0));
      decoder.Feed(payload, Length(payload), sweep);

      frame := IcomSweepToSpectrumFrame(sweep, IcomScopeGeometry(POINTS_475, LEVEL_160),
                                        IcomScopeSourceId(sweep.ScopeId));

      CheckEquals(IcomScopeSourceId(1), frame.SourceId, 'the scope id reaches SourceId');
      CheckEquals('1', frame.SourceId, 'and is spelled decimally');

      { NOT 'Main'/'Sub'.  Which id is which is HamLib's claim and has not been
        confirmed on a rig here; spelling it out would put an unverified
        assertion in front of the operator. }
      CheckEquals('0', IcomScopeSourceId(0), 'scope 0');
   finally
      decoder.Free;
   end;
end;

procedure TIcomScopeTests.Test_ScopeIdOutOfRangeIsRefused;
var
   decoder: TIcomScopeDecoder;
   payload: TBytes;
   sweep: TIcomScopeSweep;
begin
   { THE CAP IS A BOUNDS GUARD, NOT AN EXPECTATION.  A corrupt id must not
     index off the end of the assembly array -- and HamLib does exactly this
     check against its own scope count for the same reason. }
   decoder := TIcomScopeDecoder.Create(IcomScopeGeometry(POINTS_475, LEVEL_160));

   try
      payload := BuildHeaderDivision(0, 1, ismFixed, 14000000, 14200000,
                                     False, Ramp(POINTS_475, 20, 0));
      payload[0] := 200;      // not a scope this radio has

      Check(decoder.Feed(payload, Length(payload), sweep) = issBadScopeId,
            'an impossible scope id is refused');
      CheckEquals(0, Integer(decoder.SweepsOut), 'and produces no sweep');
   finally
      decoder.Free;
   end;
end;

// ---------------------------------------------------------------------------
// Refusals
// ---------------------------------------------------------------------------

procedure TIcomScopeTests.Test_ShortPayloadIsRefused;
var
   decoder: TIcomScopeDecoder;
   payload: TBytes;
   sweep: TIcomScopeSweep;
begin
   decoder := TIcomScopeDecoder.Create(IcomScopeGeometry(POINTS_475, LEVEL_160));

   try
      SetLength(payload, 3);
      payload[0] := 0;
      payload[1] := $01;
      payload[2] := $01;

      // Three bytes is the common prefix and nothing else -- not even a mode.
      Check(decoder.Feed(payload, 3, sweep) = issTooShort,
            'a payload with no header is refused');

      // A header division cut off inside the frequency fields.
      payload := BuildHeaderDivision(0, 1, ismFixed, 14000000, 14200000,
                                     False, Ramp(POINTS_475, 20, 0));
      Check(decoder.Feed(payload, 9, sweep) = issTooShort,
            'a truncated header is refused, not decoded from what arrived');

      Check(decoder.Feed(payload, 0, sweep) = issTooShort, 'an empty payload is refused');
   finally
      decoder.Free;
   end;
end;

procedure TIcomScopeTests.Test_UnknownModeIsRefusedNotDefaulted;
var
   decoder: TIcomScopeDecoder;
   payload: TBytes;
   sweep: TIcomScopeSweep;
begin
   { REFUSED, NOT DEFAULTED, AND THIS IS A DELIBERATE DIVERGENCE FROM BOTH
     REFERENCES.  AetherSDR falls back to Fixed for an unknown mode byte;
     HamLib rejects the frame.  HamLib is right, and the reason is specific:
     the GEOMETRY depends entirely on which mode this is.  In centre mode the
     second frequency field is a half-width; in every other mode it is an
     absolute edge.  Guessing wrong yields a sweep confidently placed at the
     wrong frequency, which is worse than one that never appears. }
   decoder := TIcomScopeDecoder.Create(IcomScopeGeometry(POINTS_475, LEVEL_160));

   try
      payload := BuildHeaderDivision(0, 1, ismFixed, 14000000, 14200000,
                                     False, Ramp(POINTS_475, 20, 0));
      payload[3] := $09;      // no such scope mode

      Check(decoder.Feed(payload, Length(payload), sweep) = issBadField,
            'an unknown scope mode is refused');
      CheckEquals(0, Integer(decoder.SweepsOut), 'and no sweep is drawn from a guess');
   finally
      decoder.Free;
   end;
end;

procedure TIcomScopeTests.Test_OutOfRangeYieldsAFlatSweep;
var
   decoder: TIcomScopeDecoder;
   payload: TBytes;
   sweep: TIcomScopeSweep;
   emptyLevels: TBytes;
   i: Integer;
   allZero: Boolean;
begin
   { THE RADIO OMITS THE WAVEFORM ENTIRELY when the scope cannot show the range,
     so the frame is SHORT -- 15 bytes with no levels behind them.  A sweep is
     still produced rather than dropped: a waterfall that stops scrolling reads
     as a hung program, while one that goes flat reads as "nothing here", which
     is what the radio is actually saying.

     Note this also has to complete IMMEDIATELY even when the division maximum
     is 11: there is nothing further coming, so waiting for division 2 would
     stall the display until the rig came back in range. }
   decoder := TIcomScopeDecoder.Create(IcomScopeGeometry(POINTS_475, LEVEL_160));

   try
      SetLength(emptyLevels, 0);
      payload := BuildHeaderDivision(0, 11, ismFixed, 14000000, 14200000,
                                     True, emptyLevels);

      Check(decoder.Feed(payload, Length(payload), sweep) = issComplete,
            'out of range completes immediately, even mid-division-set');
      Check(sweep.OutOfRange, 'the flag is carried out');
      CheckEquals(POINTS_475, Length(sweep.Levels), 'a full-width sweep of floor');

      allZero := True;

      for i := 0 to POINTS_475 - 1 do
         begin
         if sweep.Levels[i] <> 0 then
            begin
            allZero := False;
            end;
         end;

      Check(allZero, 'every bin is floor-filled');
   finally
      decoder.Free;
   end;
end;

procedure TIcomScopeTests.Test_ExcessLevelsAreTruncatedNotOverrun;
var
   decoder: TIcomScopeDecoder;
   payload: TBytes;
   sweep: TIcomScopeSweep;
begin
   { A RADIO SENDING MORE POINTS THAN THE DECLARED GEOMETRY means the geometry
     is wrong for this model -- a configuration fault, not a reason to write
     past the buffer.  The sweep still completes, so the operator gets a display
     and the divergence is visible on the bench rather than as an access
     violation in the field.  This is the exact case a wrong per-model
     declaration produces on a 689-point rig configured as 475. }
   decoder := TIcomScopeDecoder.Create(IcomScopeGeometry(POINTS_475, LEVEL_160));

   try
      payload := BuildHeaderDivision(0, 1, ismFixed, 14000000, 14200000,
                                     False, Ramp(POINTS_689, 20, 0));

      Check(decoder.Feed(payload, Length(payload), sweep) = issComplete,
            'an oversized sweep still completes');
      CheckEquals(POINTS_475, Length(sweep.Levels),
                  'truncated to the declared geometry, never beyond it');
   finally
      decoder.Free;
   end;
end;

// ---------------------------------------------------------------------------
// Sweep -> TSpectrumFrame
// ---------------------------------------------------------------------------

procedure TIcomScopeTests.Test_Frame_CarriesCentreAndSpan;
var
   sweep: TIcomScopeSweep;
   frame: TSpectrumFrame;
begin
   { THE NEUTRAL FRAME IS CENTRE-AND-SPAN; the sweep is edges.  One conversion,
     in one place, so nothing downstream has to know Icom reports edges -- or
     that in centre mode it reported a half-width that was already folded out. }
   sweep := Default(TIcomScopeSweep);
   sweep.StartHz := 14150000;
   sweep.EndHz := 14350000;
   sweep.Levels := Ramp(POINTS_475, 20, 0);

   frame := IcomSweepToSpectrumFrame(sweep, IcomScopeGeometry(POINTS_475, LEVEL_160), '0');

   CheckEqualsI64(14250000, frame.CentreHz, 'centre is the midpoint of the edges');
   CheckEqualsI64(200000, frame.SpanHz, 'span is the TOTAL width, not the half-width');

   // And it must agree with uSpectrumTypes' own arithmetic, which is what the
   // draw path and the click-to-tune path both use.  If these ever disagree the
   // operator clicks on a signal and lands somewhere else.
   CheckEqualsI64(14150000, SpectrumStartHz(frame), 'start round-trips');
   CheckEqualsI64(14350000, SpectrumEndHz(frame), 'end round-trips');
end;

procedure TIcomScopeTests.Test_Frame_MapsLevelsAtTheEstimatedRate;
var
   sweep: TIcomScopeSweep;
   frame: TSpectrumFrame;
   geom: TIcomScopeGeometry;
begin
   geom := IcomScopeGeometry(POINTS_475, LEVEL_160);

   sweep := Default(TIcomScopeSweep);
   sweep.StartHz := 14000000;
   sweep.EndHz := 14200000;
   SetLength(sweep.Levels, 3);
   sweep.Levels[0] := 0;
   sweep.Levels[1] := 80;
   sweep.Levels[2] := 160;

   frame := IcomSweepToSpectrumFrame(sweep, geom, '0');

   { PINNED TO THE PUBLISHED RANGE.  0..160 over -80..0 is what HamLib
     publishes for the IC-7300, and it is the whole basis for the 0.5 dB/unit
     estimate.  If someone revises DbPerUnit after a bench measurement, this
     test is where they will be told the axis moved. }
   CheckClose(-80.0, frame.Bins[0], 'level 0 is the bottom of the axis');
   CheckClose(-40.0, frame.Bins[1], 'level 80 is half way');
   CheckClose(0.0, frame.Bins[2], 'level 160 is the top');
end;

procedure TIcomScopeTests.Test_Frame_ClampsLevelsAboveTheRange;
var
   sweep: TIcomScopeSweep;
   frame: TSpectrumFrame;
begin
   { CLAMP RATHER THAN TRUST.  The published range is 0..160 but the field is a
     whole byte, so a value above it would project above the top of the scale
     and drag the display's contrast with it -- one stray bin flattening the
     entire trace.  AetherSDR clamps here for the same reason. }
   sweep := Default(TIcomScopeSweep);
   sweep.StartHz := 14000000;
   sweep.EndHz := 14200000;
   SetLength(sweep.Levels, 2);
   sweep.Levels[0] := 160;
   sweep.Levels[1] := 255;

   frame := IcomSweepToSpectrumFrame(sweep, IcomScopeGeometry(POINTS_475, LEVEL_160), '0');

   CheckClose(0.0, frame.Bins[0], 'the top of the range');
   CheckClose(0.0, frame.Bins[1], 'and anything above it clamps to the same place');
end;

procedure TIcomScopeTests.Test_Frame_NoiseFloorIsMeasuredFromTheSweep;
var
   sweep: TIcomScopeSweep;
   frame: TSpectrumFrame;
   i: Integer;
begin
   { THE FLOOR IS MEASURED, NOT DECLARED -- the one place this differs from
     AetherSDR, which uses a fixed reference constant.  Icom sends no noise
     floor and the window scales everything relative to one, so it has to come
     from somewhere: taking a low percentile of the sweep itself does the job
     the K4's AutoRef does on the radio's side, with no CAT query.

     100 bins at level 40 with ten spikes: the 10th percentile must land on the
     noise, not on the spikes. }
   sweep := Default(TIcomScopeSweep);
   sweep.StartHz := 14000000;
   sweep.EndHz := 14200000;
   SetLength(sweep.Levels, 100);

   for i := 0 to 99 do
      begin
      sweep.Levels[i] := 40;
      end;

   for i := 90 to 99 do
      begin
      sweep.Levels[i] := 150;
      end;

   frame := IcomSweepToSpectrumFrame(sweep, IcomScopeGeometry(POINTS_475, LEVEL_160), '0');

   CheckClose(-60.0, frame.NoiseFloorDb, 'the floor sits on the noise (level 40)');

   { AND IT IS ON THE SAME AXIS AS THE BINS.  A floor computed on one scale and
     bins on another is the subtler version of the K4's black-waterfall bug:
     everything renders, in the wrong place. }
   CheckClose(-60.0, frame.Bins[0], 'a noise bin sits exactly at the floor');
end;

procedure TIcomScopeTests.Test_Frame_FloorTracksAQuietBandDown;
var
   sweep: TIcomScopeSweep;
   loud, quiet: TSpectrumFrame;
   i: Integer;
begin
   { THIS IS THE PROPERTY THE WHOLE APPROACH EXISTS FOR.  A band change, an
     attenuator, or a different model simply moves the floor and the display
     follows -- which is what a FIXED reference cannot do, and is precisely how
     TR4QT's hard-coded -100..-20 window rendered every K4 pan-A sample as
     solid black (docs/PANADAPTER_LCL_DESIGN.md section 2.3). }
   sweep := Default(TIcomScopeSweep);
   sweep.StartHz := 14000000;
   sweep.EndHz := 14200000;
   SetLength(sweep.Levels, 100);

   for i := 0 to 99 do
      begin
      sweep.Levels[i] := 90;
      end;

   loud := IcomSweepToSpectrumFrame(sweep, IcomScopeGeometry(POINTS_475, LEVEL_160), '0');

   for i := 0 to 99 do
      begin
      sweep.Levels[i] := 20;
      end;

   quiet := IcomSweepToSpectrumFrame(sweep, IcomScopeGeometry(POINTS_475, LEVEL_160), '0');

   Check(quiet.NoiseFloorDb < loud.NoiseFloorDb,
         'a quieter band reports a lower floor');
   CheckClose(35.0, loud.NoiseFloorDb - quiet.NoiseFloorDb,
              'and by exactly the level difference, on the same axis');
end;

procedure TIcomScopeTests.Test_Percentile_IsExactOnAKnownDistribution;
var
   levels: TBytes;
   i: Integer;
begin
   { A HISTOGRAM, NOT A SORT -- O(n) with no allocation, which matters at 30
     sweeps a second on the shared CI-V path.  It is EXACT rather than an
     approximation, because a level IS a byte: the histogram is the
     distribution, not a sampling of it.  So this can be pinned to the value a
     sort would give, and is. }
   SetLength(levels, 100);

   for i := 0 to 99 do
      begin
      levels[i] := Byte(i);
      end;

   CheckEquals(9, IcomScopeLevelPercentile(levels, 100, 10), '10th percentile of 0..99');
   CheckEquals(49, IcomScopeLevelPercentile(levels, 100, 50), 'median of 0..99');
   CheckEquals(0, IcomScopeLevelPercentile(levels, 100, 0), 'the bottom');
   CheckEquals(99, IcomScopeLevelPercentile(levels, 100, 100), 'the top');

   { ROUNDED UP, so a percentile of a tiny sweep names a real sample rather
     than falling through to index zero. }
   SetLength(levels, 3);
   levels[0] := 5;
   levels[1] := 60;
   levels[2] := 120;
   CheckEquals(5, IcomScopeLevelPercentile(levels, 3, 10),
               'a 3-bin sweep still names its lowest sample');

   CheckEquals(0, IcomScopeLevelPercentile(levels, 0, 10), 'no bins, no percentile');
end;

procedure TIcomScopeTests.Test_Frame_BinCountIsTheGeometryNotAConstant;
var
   sweep: TIcomScopeSweep;
   frame: TSpectrumFrame;
begin
   { BinCount IS A FIELD FOR EXACTLY THIS REASON (see uSpectrumTypes).  2048 is
     a K4 number, 475 and 689 are Icom numbers, and a window that indexes any
     of them is a window that has to be rewritten for the next radio. }
   sweep := Default(TIcomScopeSweep);
   sweep.StartHz := 14000000;
   sweep.EndHz := 14200000;
   sweep.Levels := Ramp(POINTS_689, 20, 0);

   frame := IcomSweepToSpectrumFrame(sweep, IcomScopeGeometry(POINTS_689, LEVEL_200), '0');
   CheckEquals(POINTS_689, frame.BinCount, 'BinCount is the actual bin count');
   CheckEquals(POINTS_689, Length(frame.Bins), 'and Bins is that long');

   // An empty sweep must not read as a frame with a floor of 0 dB.
   sweep := Default(TIcomScopeSweep);
   frame := IcomSweepToSpectrumFrame(sweep, IcomScopeGeometry(POINTS_475, LEVEL_160), '0');
   CheckEquals(0, frame.BinCount, 'no bins is reported as no bins');
   CheckClose(-80.0, frame.NoiseFloorDb, 'and the floor is the bottom of the axis, not zero');
end;

procedure TIcomScopeTests.Test_Frame_SequenceAdvancesPerScope;
var
   decoder: TIcomScopeDecoder;
   payload: TBytes;
   sweep: TIcomScopeSweep;
   i: Integer;
   firstSeq: Integer;
begin
   { ICOM SENDS NO SEQUENCE NUMBER, so one is synthesised -- and PER SCOPE,
     because that is what TSpectrumFrame.Sequence already means for the K4,
     whose counter is per pan.  One meaning for the field rather than two.

     Wrapped at 256 to match the K4's, whose counter is a byte. }
   decoder := TIcomScopeDecoder.Create(IcomScopeGeometry(POINTS_475, LEVEL_160));

   try
      payload := BuildHeaderDivision(0, 1, ismFixed, 14000000, 14200000,
                                     False, Ramp(POINTS_475, 20, 0));
      decoder.Feed(payload, Length(payload), sweep);
      firstSeq := sweep.Sequence;

      decoder.Feed(payload, Length(payload), sweep);
      CheckEquals(firstSeq + 1, sweep.Sequence, 'the counter advances');

      // Scope 1's counter is its own, and starts from its own beginning.
      payload := BuildHeaderDivision(1, 1, ismFixed, 21000000, 21200000,
                                     False, Ramp(POINTS_475, 20, 0));
      decoder.Feed(payload, Length(payload), sweep);
      CheckEquals(firstSeq, sweep.Sequence, 'scope 1 counts separately from scope 0');

      // And it wraps rather than growing without bound.
      payload := BuildHeaderDivision(0, 1, ismFixed, 14000000, 14200000,
                                     False, Ramp(POINTS_475, 20, 0));

      for i := 1 to 300 do
         begin
         decoder.Feed(payload, Length(payload), sweep);
         Check((sweep.Sequence >= 0) and (sweep.Sequence < 256),
               'the sequence stays inside a byte');
         end;
   finally
      decoder.Free;
   end;
end;

// ---------------------------------------------------------------------------

procedure TIcomScopeTests.RunAllTests;
begin
   Test_BcdByte_DecodesDivisionEleven;
   Test_BcdByte_RefusesNonDecimalNibble;
   Test_Edge_DecodesLittleEndianBcd;
   Test_Edge_DecodesNegativeLowerEdge;
   Test_Edge_RefusesCorruptNibbleElsewhere;
   Test_Edge_RefusesShortBuffer;

   Test_Geometry_SeedsTheEstimate;
   Test_Geometry_RejectsUnusable;

   Test_Lan_CentreModeDoublesTheHalfWidth;
   Test_Lan_FixedModeUsesEdgesDirectly;
   Test_Lan_ScrollModesAreGeometricallyFixed;
   Test_Lan_LargeGeometryDecodes;

   Test_Usb_ElevenDivisionsAssemble;
   Test_Usb_DivisionGapAbandonsTheSweep;
   Test_Usb_ContinuationWithoutHeaderIsRefused;
   Test_Usb_RestartDiscardsAHalfBuiltSweep;

   Test_TwoScopesInterleaveIndependently;
   Test_ScopeIdBecomesSourceId;
   Test_ScopeIdOutOfRangeIsRefused;

   Test_ShortPayloadIsRefused;
   Test_UnknownModeIsRefusedNotDefaulted;
   Test_OutOfRangeYieldsAFlatSweep;
   Test_ExcessLevelsAreTruncatedNotOverrun;

   Test_Frame_CarriesCentreAndSpan;
   Test_Frame_MapsLevelsAtTheEstimatedRate;
   Test_Frame_ClampsLevelsAboveTheRange;
   Test_Frame_NoiseFloorIsMeasuredFromTheSweep;
   Test_Frame_FloorTracksAQuietBandDown;
   Test_Percentile_IsExactOnAKnownDistribution;
   Test_Frame_BinCountIsTheGeometryNotAConstant;
   Test_Frame_SequenceAdvancesPerScope;
end;

end.
