unit uTestRadioBand;
{$I ..\..\src\tr4w.inc}

{
  Unit tests for uRadioBand — FreqToRadioBand and RadioBandToFreq.

  Covers:
    - FreqToRadioBand: centre-of-band spot checks for every band
    - FreqToRadioBand: boundary frequencies (just inside / just outside)
    - FreqToRadioBand: edge cases (0 Hz, very high frequencies)
    - RadioBandToFreq: default calling frequency for each band
    - Round-trip: RadioBandToFreq → FreqToRadioBand for all named bands
    - StepRadioBand / NextSupportedRadioBand: band stepping and its wrap, and
      the coverage filter that makes stepping follow the RADIO rather than a
      list typed into a base class
}

interface

uses
   SysUtils, uTR4WTestFramework, uRadioBand, VC, uBandLookup;

type
   TRadioBandTests = class(TTestCase)
   protected
      // FreqToRadioBand — centre of each band
      procedure Test_FreqToBand_160m;
      procedure Test_FreqToBand_80m;
      procedure Test_FreqToBand_60m;
      procedure Test_FreqToBand_40m;
      procedure Test_FreqToBand_30m;
      procedure Test_FreqToBand_20m;
      procedure Test_FreqToBand_17m;
      procedure Test_FreqToBand_15m;
      procedure Test_FreqToBand_12m;
      procedure Test_FreqToBand_10m;
      procedure Test_FreqToBand_6m;
      procedure Test_FreqToBand_4m;
      procedure Test_FreqToBand_2m;
      procedure Test_FreqToBand_125cm;
      procedure Test_FreqToBand_70cm;
      procedure Test_FreqToBand_33cm;
      procedure Test_FreqToBand_23cm;

      // FreqToRadioBand — boundary and edge cases
      procedure Test_FreqToBand_ZeroIsBelow160m;
      procedure Test_FreqToBand_NY4I_IC9700_23cm;
      procedure Test_FreqToBand_OneGHzExactlyIs33cm;
      procedure Test_FreqToBand_Above1500MHzIsNone;
      procedure Test_FreqToBand_40m_UpperEdgeIn;
      procedure Test_FreqToBand_40m_UpperEdgeOut;
      procedure Test_FreqToBand_20m_UpperEdgeIn;
      procedure Test_FreqToBand_20m_UpperEdgeOut;

      // RadioBandToFreq — default calling frequency per band
      procedure Test_BandToFreq_160m;
      procedure Test_BandToFreq_20m;
      procedure Test_BandToFreq_None_Defaults20m;

      // Round-trip
      procedure Test_BandFreq_RoundTrip;

      // Band stepping -- the unfiltered enum walk
      procedure Test_Step_UpThroughHF;
      procedure Test_Step_UpFrom70cmReaches23cm;
      procedure Test_Step_WrapsAtTheTop;
      procedure Test_Step_WrapsAtTheBottom;
      procedure Test_Step_NoneEntersTheCycle;
      procedure Test_Step_DownIsTheInverseOfUp;

      // Band stepping -- filtered by what the radio covers
      procedure Test_Next_VHFRadio_70cmStepsTo23cm;
      procedure Test_Next_VHFRadio_WrapsFrom23cmTo2m;
      procedure Test_Next_VHFRadio_DownFrom2mIs23cm;
      procedure Test_Next_HFRadio_SequenceUnchanged;
      procedure Test_Next_HFRadio_10mWrapsTo160m;
      procedure Test_Next_NoCoverage_IsAPlainStep;
      procedure Test_Next_NoBandCovered_StaysPut;
      procedure Test_Next_SkipsTheGap_4mOmitted;

      // BandType <-> TRadioBand, and agreement with the strict table
      procedure Test_BandTypeRoundTrip_AllNamedBands;
      procedure Test_AgreesWithCalculateBandMode;

   public
      procedure RunAllTests; override;
   end;

implementation

// ---------------------------------------------------------------------------
// FreqToRadioBand — centre of each band
// ---------------------------------------------------------------------------

procedure TRadioBandTests.Test_FreqToBand_160m;
begin
   BeginTest('FreqToRadioBand(1800000) = rb160m');
   CheckEquals(Ord(rb160m), Ord(FreqToRadioBand(1800000)));
end;

procedure TRadioBandTests.Test_FreqToBand_80m;
begin
   BeginTest('FreqToRadioBand(3700000) = rb80m');
   CheckEquals(Ord(rb80m), Ord(FreqToRadioBand(3700000)));
end;

procedure TRadioBandTests.Test_FreqToBand_60m;
begin
   BeginTest('FreqToRadioBand(5357000) = rb60m');
   CheckEquals(Ord(rb60m), Ord(FreqToRadioBand(5357000)));
end;

procedure TRadioBandTests.Test_FreqToBand_40m;
begin
   BeginTest('FreqToRadioBand(7050000) = rb40m');
   CheckEquals(Ord(rb40m), Ord(FreqToRadioBand(7050000)));
end;

procedure TRadioBandTests.Test_FreqToBand_30m;
begin
   BeginTest('FreqToRadioBand(10125000) = rb30m');
   CheckEquals(Ord(rb30m), Ord(FreqToRadioBand(10125000)));
end;

procedure TRadioBandTests.Test_FreqToBand_20m;
begin
   BeginTest('FreqToRadioBand(14200000) = rb20m');
   CheckEquals(Ord(rb20m), Ord(FreqToRadioBand(14200000)));
end;

procedure TRadioBandTests.Test_FreqToBand_17m;
begin
   BeginTest('FreqToRadioBand(18100000) = rb17m');
   CheckEquals(Ord(rb17m), Ord(FreqToRadioBand(18100000)));
end;

procedure TRadioBandTests.Test_FreqToBand_15m;
begin
   BeginTest('FreqToRadioBand(21200000) = rb15m');
   CheckEquals(Ord(rb15m), Ord(FreqToRadioBand(21200000)));
end;

procedure TRadioBandTests.Test_FreqToBand_12m;
begin
   BeginTest('FreqToRadioBand(24940000) = rb12m');
   CheckEquals(Ord(rb12m), Ord(FreqToRadioBand(24940000)));
end;

procedure TRadioBandTests.Test_FreqToBand_10m;
begin
   BeginTest('FreqToRadioBand(28500000) = rb10m');
   CheckEquals(Ord(rb10m), Ord(FreqToRadioBand(28500000)));
end;

procedure TRadioBandTests.Test_FreqToBand_6m;
begin
   BeginTest('FreqToRadioBand(50125000) = rb6m');
   CheckEquals(Ord(rb6m), Ord(FreqToRadioBand(50125000)));
end;

procedure TRadioBandTests.Test_FreqToBand_4m;
begin
   BeginTest('FreqToRadioBand(70200000) = rb4m');
   CheckEquals(Ord(rb4m), Ord(FreqToRadioBand(70200000)));
end;

procedure TRadioBandTests.Test_FreqToBand_2m;
begin
   BeginTest('FreqToRadioBand(144200000) = rb2m');
   CheckEquals(Ord(rb2m), Ord(FreqToRadioBand(144200000)));
end;

procedure TRadioBandTests.Test_FreqToBand_125cm;
begin
   (* 222 MHz was silently reported as 70 cm until 2026-09-24: the chain jumped
      from 170 MHz straight to 500 MHz.  A 1.25 m QSO was LOGGED on 432. *)
   BeginTest('FreqToRadioBand(222100000) = rb125cm');
   CheckEquals(Ord(rb125cm), Ord(FreqToRadioBand(222100000)));
end;

procedure TRadioBandTests.Test_FreqToBand_70cm;
begin
   BeginTest('FreqToRadioBand(432100000) = rb70cm');
   CheckEquals(Ord(rb70cm), Ord(FreqToRadioBand(432100000)));
end;

procedure TRadioBandTests.Test_FreqToBand_33cm;
begin
   BeginTest('FreqToRadioBand(903100000) = rb33cm');
   CheckEquals(Ord(rb33cm), Ord(FreqToRadioBand(903100000)));
end;

procedure TRadioBandTests.Test_FreqToBand_23cm;
begin
   BeginTest('FreqToRadioBand(1296100000) = rb23cm');
   CheckEquals(Ord(rb23cm), Ord(FreqToRadioBand(1296100000)));
end;

// ---------------------------------------------------------------------------
// FreqToRadioBand — boundary and edge cases
// ---------------------------------------------------------------------------

procedure TRadioBandTests.Test_FreqToBand_ZeroIsBelow160m;
begin
   BeginTest('FreqToRadioBand(0) = rb160m  (0 < 2 MHz threshold)');
   CheckEquals(Ord(rb160m), Ord(FreqToRadioBand(0)));
end;

procedure TRadioBandTests.Test_FreqToBand_NY4I_IC9700_23cm;
begin
   (* The bench defect, verbatim: NY4I's IC-9700 over LAN read 1295.20640 MHz
      and TR4W went on showing 432.  This exact frequency appears in tr4w.log
      of 2026-09-24 as FS.Freq=1295196200 with FS.Band=22 (NoBand). *)
   BeginTest('FreqToRadioBand(1295206400) = rb23cm  (NY4I IC-9700 bench defect)');
   CheckEquals(Ord(rb23cm), Ord(FreqToRadioBand(1295206400)));
end;

procedure TRadioBandTests.Test_FreqToBand_OneGHzExactlyIs33cm;
begin
   (* FreqModeArray's 902 entry runs 900..1000 MHz and its 1296 entry starts at
      1000 MHz; CalculateBandMode takes the first hit, so 1.000 GHz is 33 cm.
      This pins the permissive classifier to that choice. *)
   BeginTest('FreqToRadioBand(1000000000) = rb33cm  (the table''s 902 entry owns it)');
   CheckEquals(Ord(rb33cm), Ord(FreqToRadioBand(1000000000)));
end;

procedure TRadioBandTests.Test_FreqToBand_Above1500MHzIsNone;
begin
   (* 2304 MHz and up are named by BandType but unreachable in signed 32-bit
      Hz, so nothing above 1.5 GHz is classified. *)
   BeginTest('FreqToRadioBand(2000000000) = rbNone  (> 1.5 GHz)');
   CheckEquals(Ord(rbNone), Ord(FreqToRadioBand(2000000000)));
end;

procedure TRadioBandTests.Test_FreqToBand_40m_UpperEdgeIn;
begin
   // 7.299.999 Hz is still inside the 40m window (< 7.300.000)
   BeginTest('FreqToRadioBand(7299999) = rb40m  (just inside upper edge)');
   CheckEquals(Ord(rb40m), Ord(FreqToRadioBand(7299999)));
end;

procedure TRadioBandTests.Test_FreqToBand_40m_UpperEdgeOut;
begin
   // 7.300.000 Hz steps into the 30m window (>= 7.300.000)
   BeginTest('FreqToRadioBand(7300000) = rb30m  (just above 40m upper edge)');
   CheckEquals(Ord(rb30m), Ord(FreqToRadioBand(7300000)));
end;

procedure TRadioBandTests.Test_FreqToBand_20m_UpperEdgeIn;
begin
   BeginTest('FreqToRadioBand(14999999) = rb20m  (just inside upper edge)');
   CheckEquals(Ord(rb20m), Ord(FreqToRadioBand(14999999)));
end;

procedure TRadioBandTests.Test_FreqToBand_20m_UpperEdgeOut;
begin
   BeginTest('FreqToRadioBand(15000000) = rb17m  (just above 20m upper edge)');
   CheckEquals(Ord(rb17m), Ord(FreqToRadioBand(15000000)));
end;

// ---------------------------------------------------------------------------
// RadioBandToFreq — default calling frequency per band
// ---------------------------------------------------------------------------

procedure TRadioBandTests.Test_BandToFreq_160m;
begin
   BeginTest('RadioBandToFreq(rb160m) = 1900000');
   CheckEquals(1900000, Integer(RadioBandToFreq(rb160m)));
end;

procedure TRadioBandTests.Test_BandToFreq_20m;
begin
   BeginTest('RadioBandToFreq(rb20m) = 14100000');
   CheckEquals(14100000, Integer(RadioBandToFreq(rb20m)));
end;

procedure TRadioBandTests.Test_BandToFreq_None_Defaults20m;
begin
   BeginTest('RadioBandToFreq(rbNone) = 14100000  (default to 20m)');
   CheckEquals(14100000, Integer(RadioBandToFreq(rbNone)));
end;

// ---------------------------------------------------------------------------
// Round-trip: RadioBandToFreq -> FreqToRadioBand
//
// For every named band (rb160m .. rb23cm), the default calling frequency
// must map back to the same band.  rbNone is excluded because
// RadioBandToFreq(rbNone) returns the 20m default, not a None frequency.
//
// THE RANGE IS WRITTEN AS rb160m..rb23cm ON PURPOSE -- it is the whole enum
// bar rbNone, so adding a band without giving it a calling frequency fails
// here rather than defaulting silently to 20 m.
// ---------------------------------------------------------------------------

procedure TRadioBandTests.Test_BandFreq_RoundTrip;
const
   BandNames: array[rb160m..rb23cm] of string = (
      '160m','80m','60m','40m','30m','20m','17m','15m','12m','10m',
      '6m','4m','2m','125cm','70cm','33cm','23cm');
var
   band  : TRadioBand;
   freq  : LongInt;
   back  : TRadioBand;
begin
   BeginTest('RadioBandToFreq -> FreqToRadioBand round-trip for all named bands');
   for band := rb160m to rb23cm do
      begin
      freq := RadioBandToFreq(band);
      back := FreqToRadioBand(freq);
      if back <> band then
         begin
         CheckEquals(Ord(band), Ord(back),
            Format('Round-trip failed for %s (freq=%d)', [BandNames[band], freq]));
         Exit;
         end;
      end;
   Check(True);
end;

// ---------------------------------------------------------------------------
// BandType <-> TRadioBand
//
// GetRadioBandFromBandType and GetBandTypeFromRadioBand are inverses, and were
// maintained in two different units until 2026-09-24 -- uRadioBand and
// MainUnit.  Both had drifted the same way (no 222, 902 or 1296), which is why
// an IC-9700 on 23 cm displayed and LOGGED 432.  This walks the enum so a band
// added to one side and not the other fails here.
//
// rb60m and rb4m are excluded: BandType genuinely cannot name either.
// ---------------------------------------------------------------------------

procedure TRadioBandTests.Test_BandTypeRoundTrip_AllNamedBands;
var
   band : TRadioBand;
   bt   : BandType;
begin
   BeginTest('TRadioBand -> BandType -> TRadioBand round-trip for every band');
   for band := rb160m to rb23cm do
      begin
      if band in [rb60m, rb4m] then
         begin
         Continue;
         end;

      bt := GetBandTypeFromRadioBand(band);
      if bt = NoBand then
         begin
         Check(False, Format('No BandType for TRadioBand ordinal %d', [Ord(band)]));
         Exit;
         end;

      if GetRadioBandFromBandType(bt) <> band then
         begin
         CheckEquals(Ord(band), Ord(GetRadioBandFromBandType(bt)),
            Format('Round-trip failed for TRadioBand ordinal %d', [Ord(band)]));
         Exit;
         end;
      end;
   Check(True);
end;

// ---------------------------------------------------------------------------
// FreqToRadioBand must agree with CalculateBandMode
//
// THE DRIFT GUARD.  There are two band classifiers in this program and they
// answer different questions: CalculateBandMode is STRICT (which band segment
// is this exactly in, NoBand if none) and FreqToRadioBand is PERMISSIVE (which
// band is the dial nearest, so it still answers out of band).  The difference
// is deliberate.  DISAGREEING is not, and is invisible at run time -- the 23 cm
// defect was exactly that: FreqModeArray had a 1296 row and the factory's enum
// stopped at 70 cm.
//
// Probed at each entry's frMin and its midpoint, NOT its frMax: several frMax
// values are the byte before the next band and the permissive windows round the
// other way by 1 Hz, which is long-standing intended behaviour (see
// Test_FreqToBand_40m_UpperEdgeOut).
// ---------------------------------------------------------------------------

procedure TRadioBandTests.Test_AgreesWithCalculateBandMode;
var
   i      : integer;
   probe  : integer;
   which  : integer;
   band   : BandType;
   mode   : ModeType;
   expect : TRadioBand;
   got    : TRadioBand;
begin
   BeginTest('FreqToRadioBand agrees with CalculateBandMode on every FreqModeArray entry');
   for i := 1 to FreqModeArraySize do
      begin
      for which := 0 to 1 do
         begin
         if which = 0 then
            begin
            probe := FreqModeArray[i].frMin;
            end
         else
            begin
            (* Written as min + half the span: min + max overflows 32 bits once
               the entries reach 1 GHz. *)
            probe := FreqModeArray[i].frMin +
                     ((FreqModeArray[i].frMax - FreqModeArray[i].frMin) div 2);
            end;

         CalculateBandMode(Cardinal(probe), band, mode);
         if band = NoBand then
            begin
            Check(False, Format('FreqModeArray[%d]: CalculateBandMode(%d) = NoBand',
                                [i, probe]));
            Exit;
            end;

         expect := GetRadioBandFromBandType(band);
         if expect = rbNone then
            begin
            Check(False, Format('FreqModeArray[%d]: no TRadioBand for BandType ordinal %d (%d Hz)',
                                [i, Ord(band), probe]));
            Exit;
            end;

         got := FreqToRadioBand(probe);
         if got <> expect then
            begin
            CheckEquals(Ord(expect), Ord(got),
               Format('FreqModeArray[%d] at %d Hz: table says BandType %d, FreqToRadioBand disagrees',
                      [i, probe, Ord(band)]));
            Exit;
            end;
         end;
      end;
   Check(True);
end;

// ---------------------------------------------------------------------------
// Band stepping.
//
// THE POINT OF THESE, beyond the arithmetic: stepping used to be a hand-typed
// `case` ladder in the Icom family base and again in two model units, and all
// three stopped at 70 cm -- so an IC-9700 could not be stepped onto 23 cm.
// The sequence is now the enum and the filter is the radio's own coverage, and
// that is testable without a radio because both halves are data.
//
// TCoverageStub stands in for TFactoryRadioBase.CoversFrequency: same
// signature, same contract (an empty range list means NO OPINION, so
// everything is covered).  Using it rather than a real driver keeps this a
// leaf test -- no transport, no threads, no logger.
// ---------------------------------------------------------------------------

type
   TCoverageStub = class(TObject)
   private
      FLow:  array[0 .. 7] of LongInt;
      FHigh: array[0 .. 7] of LongInt;
      FCount: integer;
   public
      procedure Add(lowHz, highHz: LongInt);
      function Covers(hz: LongInt): boolean;
      (* The method AS A POINTER.  Bound through a typed result rather than
        written at each call site, where a bare `rig.Covers` reads as a call. *)
      function Query: TBandCoverageQuery;
   end;

procedure TCoverageStub.Add(lowHz, highHz: LongInt);
begin
   FLow[FCount]  := lowHz;
   FHigh[FCount] := highHz;
   Inc(FCount);
end;

function TCoverageStub.Covers(hz: LongInt): boolean;
var
   i: integer;
begin
   if FCount = 0 then
      begin
      Result := True;      (* no opinion -- the base class answers the same *)
      Exit;
      end;

   for i := 0 to FCount - 1 do
      begin
      if (hz >= FLow[i]) and (hz <= FHigh[i]) then
         begin
         Result := True;
         Exit;
         end;
      end;

   Result := False;
end;

function TCoverageStub.Query: TBandCoverageQuery;
begin
   Result := Self.Covers;
end;

(* An IC-9700, as the radio itself reported it over LAN on 2026-09-24:
  $1E $00 answered a count of 3, and $1E $01 1..3 gave these three ranges. *)
function NineSevenHundred: TCoverageStub;
begin
   Result := TCoverageStub.Create;
   Result.Add(144000000, 148000000);
   Result.Add(430000000, 450000000);
   Result.Add(1240000000, 1300000000);
end;

procedure TRadioBandTests.Test_Step_UpThroughHF;
begin
   BeginTest('StepRadioBand: 20m steps up to 17m');
   CheckEquals(Ord(rb17m), Ord(StepRadioBand(rb20m, True)));
end;

procedure TRadioBandTests.Test_Step_UpFrom70cmReaches23cm;
begin
   (* THE DEFECT, IN ONE ASSERTION.  The old ladder went rb70cm -> rb160m. *)
   BeginTest('StepRadioBand: 70cm steps up to 33cm, not back to 160m');
   CheckEquals(Ord(rb33cm), Ord(StepRadioBand(rb70cm, True)));
end;

procedure TRadioBandTests.Test_Step_WrapsAtTheTop;
begin
   BeginTest('StepRadioBand: the top band wraps up to 160m');
   CheckEquals(Ord(rb160m), Ord(StepRadioBand(High(TRadioBand), True)));
end;

procedure TRadioBandTests.Test_Step_WrapsAtTheBottom;
begin
   BeginTest('StepRadioBand: 160m wraps down to the top band');
   CheckEquals(Ord(High(TRadioBand)), Ord(StepRadioBand(rb160m, False)));
end;

procedure TRadioBandTests.Test_Step_NoneEntersTheCycle;
begin
   BeginTest('StepRadioBand: rbNone enters at the bottom going up');
   CheckEquals(Ord(rb160m), Ord(StepRadioBand(rbNone, True)));
   BeginTest('StepRadioBand: rbNone enters at the top going down');
   CheckEquals(Ord(High(TRadioBand)), Ord(StepRadioBand(rbNone, False)));
end;

procedure TRadioBandTests.Test_Step_DownIsTheInverseOfUp;
var
   b: TRadioBand;
begin
   BeginTest('StepRadioBand: down undoes up for every band');
   for b := Succ(Low(TRadioBand)) to High(TRadioBand) do
      begin
      CheckEquals(Ord(b), Ord(StepRadioBand(StepRadioBand(b, True), False)));
      end;
end;

procedure TRadioBandTests.Test_Next_VHFRadio_70cmStepsTo23cm;
var
   rig: TCoverageStub;
begin
   rig := NineSevenHundred;
   try
      BeginTest('NextSupportedRadioBand: a 9700 steps 70cm -> 23cm (33cm skipped)');
      CheckEquals(Ord(rb23cm), Ord(NextSupportedRadioBand(rb70cm, True, rig.Query)));
   finally
      rig.Free;
   end;
end;

procedure TRadioBandTests.Test_Next_VHFRadio_WrapsFrom23cmTo2m;
var
   rig: TCoverageStub;
begin
   rig := NineSevenHundred;
   try
      (* Past the top, round through every HF band it does not have, to 2 m. *)
      BeginTest('NextSupportedRadioBand: a 9700 wraps 23cm -> 2m, skipping all HF');
      CheckEquals(Ord(rb2m), Ord(NextSupportedRadioBand(rb23cm, True, rig.Query)));
   finally
      rig.Free;
   end;
end;

procedure TRadioBandTests.Test_Next_VHFRadio_DownFrom2mIs23cm;
var
   rig: TCoverageStub;
begin
   rig := NineSevenHundred;
   try
      BeginTest('NextSupportedRadioBand: a 9700 steps down 2m -> 23cm');
      CheckEquals(Ord(rb23cm), Ord(NextSupportedRadioBand(rb2m, False, rig.Query)));
   finally
      rig.Free;
   end;
end;

procedure TRadioBandTests.Test_Next_HFRadio_SequenceUnchanged;
var
   rig: TCoverageStub;
begin
   (* HF ONLY, AND THIS IS THE REGRESSION GUARD: an HF radio's sequence must be
     exactly what it has always been. *)
   rig := TCoverageStub.Create;
   try
      rig.Add(1800000, 29700000);

      BeginTest('NextSupportedRadioBand: HF-only sequence is unchanged');
      CheckEquals(Ord(rb80m), Ord(NextSupportedRadioBand(rb160m, True, rig.Query)));
      CheckEquals(Ord(rb60m), Ord(NextSupportedRadioBand(rb80m,  True, rig.Query)));
      CheckEquals(Ord(rb40m), Ord(NextSupportedRadioBand(rb60m,  True, rig.Query)));
      CheckEquals(Ord(rb30m), Ord(NextSupportedRadioBand(rb40m,  True, rig.Query)));
      CheckEquals(Ord(rb20m), Ord(NextSupportedRadioBand(rb30m,  True, rig.Query)));
      CheckEquals(Ord(rb17m), Ord(NextSupportedRadioBand(rb20m,  True, rig.Query)));
      CheckEquals(Ord(rb15m), Ord(NextSupportedRadioBand(rb17m,  True, rig.Query)));
      CheckEquals(Ord(rb12m), Ord(NextSupportedRadioBand(rb15m,  True, rig.Query)));
      CheckEquals(Ord(rb10m), Ord(NextSupportedRadioBand(rb12m,  True, rig.Query)));
   finally
      rig.Free;
   end;
end;

procedure TRadioBandTests.Test_Next_HFRadio_10mWrapsTo160m;
var
   rig: TCoverageStub;
begin
   rig := TCoverageStub.Create;
   try
      rig.Add(1800000, 29700000);

      (* 6 m and everything above it are skipped, so the wrap is the same one
        the old ladder produced for an HF rig. *)
      BeginTest('NextSupportedRadioBand: HF-only wraps 10m -> 160m');
      CheckEquals(Ord(rb160m), Ord(NextSupportedRadioBand(rb10m, True, rig.Query)));
   finally
      rig.Free;
   end;
end;

procedure TRadioBandTests.Test_Next_NoCoverage_IsAPlainStep;
var
   rig: TCoverageStub;
begin
   (* NO OPINION IS THE DEFAULT AND IT MUST FILTER NOTHING -- this is what
     keeps every radio that cannot report its ranges behaving as before. *)
   rig := TCoverageStub.Create;
   try
      BeginTest('NextSupportedRadioBand: an empty coverage list filters nothing');
      CheckEquals(Ord(rb17m),  Ord(NextSupportedRadioBand(rb20m,  True, rig.Query)));
      CheckEquals(Ord(rb33cm), Ord(NextSupportedRadioBand(rb70cm, True, rig.Query)));

      BeginTest('NextSupportedRadioBand: a nil query is a plain step');
      CheckEquals(Ord(rb17m), Ord(NextSupportedRadioBand(rb20m, True, nil)));
   finally
      rig.Free;
   end;
end;

procedure TRadioBandTests.Test_Next_NoBandCovered_StaysPut;
var
   rig: TCoverageStub;
begin
   (* A walk driven by what a radio REPORTS must be bounded: a rig covering
     only a frequency no band maps to must not spin. *)
   rig := TCoverageStub.Create;
   try
      rig.Add(100000, 200000);        (* long wave -- no TRadioBand lands here *)

      BeginTest('NextSupportedRadioBand: nothing covered leaves the band alone');
      CheckEquals(Ord(rb20m), Ord(NextSupportedRadioBand(rb20m, True, rig.Query)));
   finally
      rig.Free;
   end;
end;

procedure TRadioBandTests.Test_Next_SkipsTheGap_4mOmitted;
var
   rig: TCoverageStub;
begin
   (* An IC-705 / IC-7110: HF through 6 m, then 2 m and 70 cm, no 4 m.  That
     one fact is what those two model units used to express as a whole
     duplicated `case` ladder. *)
   rig := TCoverageStub.Create;
   try
      rig.Add(1800000, 54000000);
      rig.Add(144000000, 148000000);
      rig.Add(430000000, 450000000);

      BeginTest('NextSupportedRadioBand: 6m steps up to 2m when there is no 4m');
      CheckEquals(Ord(rb2m), Ord(NextSupportedRadioBand(rb6m, True, rig.Query)));

      BeginTest('NextSupportedRadioBand: 70cm wraps to 160m with no 23cm');
      CheckEquals(Ord(rb160m), Ord(NextSupportedRadioBand(rb70cm, True, rig.Query)));
   finally
      rig.Free;
   end;
end;

// ---------------------------------------------------------------------------
// RunAllTests
// ---------------------------------------------------------------------------

procedure TRadioBandTests.RunAllTests;
begin
   // FreqToRadioBand — band centres
   Test_FreqToBand_160m;
   Test_FreqToBand_80m;
   Test_FreqToBand_60m;
   Test_FreqToBand_40m;
   Test_FreqToBand_30m;
   Test_FreqToBand_20m;
   Test_FreqToBand_17m;
   Test_FreqToBand_15m;
   Test_FreqToBand_12m;
   Test_FreqToBand_10m;
   Test_FreqToBand_6m;
   Test_FreqToBand_4m;
   Test_FreqToBand_2m;
   Test_FreqToBand_125cm;
   Test_FreqToBand_70cm;
   Test_FreqToBand_33cm;
   Test_FreqToBand_23cm;

   // FreqToRadioBand — boundaries and edge cases
   Test_FreqToBand_ZeroIsBelow160m;
   Test_FreqToBand_NY4I_IC9700_23cm;
   Test_FreqToBand_OneGHzExactlyIs33cm;
   Test_FreqToBand_Above1500MHzIsNone;
   Test_FreqToBand_40m_UpperEdgeIn;
   Test_FreqToBand_40m_UpperEdgeOut;
   Test_FreqToBand_20m_UpperEdgeIn;
   Test_FreqToBand_20m_UpperEdgeOut;

   // RadioBandToFreq — default frequencies
   Test_BandToFreq_160m;
   Test_BandToFreq_20m;
   Test_BandToFreq_None_Defaults20m;

   // Round-trip
   Test_BandFreq_RoundTrip;

   // Band stepping -- the enum walk
   Test_Step_UpThroughHF;
   Test_Step_UpFrom70cmReaches23cm;
   Test_Step_WrapsAtTheTop;
   Test_Step_WrapsAtTheBottom;
   Test_Step_NoneEntersTheCycle;
   Test_Step_DownIsTheInverseOfUp;

   // Band stepping -- filtered by the radio's own coverage
   Test_Next_VHFRadio_70cmStepsTo23cm;
   Test_Next_VHFRadio_WrapsFrom23cmTo2m;
   Test_Next_VHFRadio_DownFrom2mIs23cm;
   Test_Next_HFRadio_SequenceUnchanged;
   Test_Next_HFRadio_10mWrapsTo160m;
   Test_Next_NoCoverage_IsAPlainStep;
   Test_Next_NoBandCovered_StaysPut;
   Test_Next_SkipsTheGap_4mOmitted;

   // BandType <-> TRadioBand, and agreement with the strict table
   Test_BandTypeRoundTrip_AllNamedBands;
   Test_AgreesWithCalculateBandMode;
end;

end.
