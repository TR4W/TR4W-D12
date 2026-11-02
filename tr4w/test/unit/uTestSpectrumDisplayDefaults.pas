unit uTestSpectrumDisplayDefaults;
{$I ..\..\src\tr4w.inc}

(*
  THE PANADAPTER'S SCALE, MARGIN AND WATERFALL SHARE ARE STATED BY THE RADIO.

  They were constants in uPanadapterForm -- 80 dB over 10..150, a 10 dB margin
  under the reference, a half-height waterfall -- every one a K4 number applied
  to every radio.  They moved onto the radio (SpectrumDisplayDefaults) on
  2026-11-02, and the window reads them.

  What is pinned:
  - the base answers the neutral record, and it is NOT valid -- a plausible
    default there would hide a driver that forgot to state its own;
  - the K4 answers exactly the old constants, for every source it streams;
  - over the WHOLE REGISTRY: every radio that declares rcSpectrum answers a
    valid record, and every radio that does not answers the neutral one
    (CLAUDE.md note 9 -- the silently-defaulted field is caught by name);
  - and every rcSpectrum radio answers EXACTLY the old constants.  That last
    one is the proof that the move changed no pixel: before it, every radio
    was drawn with those numbers.  Changing a radio's numbers later is a
    DECISION, and the place to record it is this test.
*)

interface

uses
   uTR4WTestFramework;

type
   TSpectrumDisplayDefaultsTests = class(TTestCase)
   protected
      procedure Test_Neutral_IsAllZeroAndNotValid;
      procedure Test_Validity_RejectsEachBrokenField;
      procedure Test_K4_StatesTheOldConstants;
      procedure Test_K4_SameRecordForEverySource;
      procedure Test_IC9700_StatesTheOldConstantsUncalibrated;
      procedure Test_K4AndIcom_ShareOneScaleRange;
      procedure Test_EverySpectrumRadio_StatesAValidRecord;
      procedure Test_EverySpectrumRadio_StatesTheOldConstants;
   public
      procedure RunAllTests; override;
   end;

implementation

uses
   SysUtils, uSpectrumTypes, uFactoryRadioBase, uRadioRegistry, VC;

const
   (* The window's constants as they stood before the move. *)
   OLD_DEFAULT_SCALE_DB = 80;
   OLD_MIN_SCALE_DB = 10;
   OLD_MAX_SCALE_DB = 150;
   OLD_REF_MARGIN_DB = 10.0;
   OLD_WATERFALL_FRACTION = 0.5;

function DescribeDefaults(const d: TSpectrumDisplayDefaults): string;
begin
   Result := Format('%d (%d..%d) margin %.3f fraction %.3f calibrated %s',
                    [d.DefaultScaleDb, d.MinScaleDb, d.MaxScaleDb,
                     d.RefMarginDb, d.WaterfallFraction,
                     BoolToStr(d.LevelsCalibrated, True)]);
end;

(* The draw-relevant fields, compared exactly.  10.0 and 0.5 are exact in
   Single, so equality is the right test. *)
function MatchesOldConstants(const d: TSpectrumDisplayDefaults): Boolean;
begin
   Result := (d.DefaultScaleDb = OLD_DEFAULT_SCALE_DB)       and
             (d.MinScaleDb = OLD_MIN_SCALE_DB)               and
             (d.MaxScaleDb = OLD_MAX_SCALE_DB)               and
             (d.RefMarginDb = OLD_REF_MARGIN_DB)             and
             (d.WaterfallFraction = OLD_WATERFALL_FRACTION);
end;

procedure TSpectrumDisplayDefaultsTests.Test_Neutral_IsAllZeroAndNotValid;
var
   d: TSpectrumDisplayDefaults;
begin
   BeginTest('Base: SpectrumDisplayDefaults is the neutral record, and it is not valid');
   d := SpectrumDisplayDefaultsNone;
   CheckEquals(0, d.DefaultScaleDb, 'neutral default scale');
   CheckEquals(0, d.MinScaleDb, 'neutral min scale');
   CheckEquals(0, d.MaxScaleDb, 'neutral max scale');
   CheckTrue(d.RefMarginDb = 0, 'neutral margin');
   CheckTrue(d.WaterfallFraction = 0, 'neutral fraction');
   CheckFalse(d.LevelsCalibrated, 'neutral calibrated');
   CheckFalse(SpectrumDisplayDefaultsValid(d),
              'the neutral record must not pass as drawable');

   (* That the BASE BODY answers it is pinned by the registry walk below:
      every radio without rcSpectrum -- most of which inherit the base body --
      must answer exactly this record. *)
end;

procedure TSpectrumDisplayDefaultsTests.Test_Validity_RejectsEachBrokenField;
var
   good, d: TSpectrumDisplayDefaults;
begin
   BeginTest('Validity: each broken field alone makes the record invalid');
   good := MakeSpectrumDisplayDefaults(80, 10, 150, 10.0, 0.5, True);
   CheckTrue(SpectrumDisplayDefaultsValid(good), 'the reference record is valid');

   d := good;
   d.MinScaleDb := 0;
   CheckFalse(SpectrumDisplayDefaultsValid(d), 'min 0 -- the scale could reach zero');

   d := good;
   d.DefaultScaleDb := d.MinScaleDb;
   CheckFalse(SpectrumDisplayDefaultsValid(d), 'default not above min');

   d := good;
   d.DefaultScaleDb := d.MaxScaleDb;
   CheckFalse(SpectrumDisplayDefaultsValid(d), 'default not below max');

   d := good;
   d.RefMarginDb := -1;
   CheckFalse(SpectrumDisplayDefaultsValid(d), 'negative margin');

   d := good;
   d.RefMarginDb := 0;
   CheckTrue(SpectrumDisplayDefaultsValid(d), 'a zero margin is allowed');

   d := good;
   d.WaterfallFraction := 0;
   CheckFalse(SpectrumDisplayDefaultsValid(d), 'fraction 0');

   d := good;
   d.WaterfallFraction := 1;
   CheckFalse(SpectrumDisplayDefaultsValid(d), 'fraction 1');
end;

procedure TSpectrumDisplayDefaultsTests.Test_K4_StatesTheOldConstants;
var
   r: TFactoryRadioBase;
   d: TSpectrumDisplayDefaults;
begin
   BeginTest('K4: states exactly the constants the window used to hold');
   r := uRadioRegistry.CreateInstance(K4);
   CheckTrue(r <> nil, 'the registry built no K4');

   if r = nil then
      begin
      Exit;
      end;

   try
      d := r.SpectrumDisplayDefaults(r.PrimarySpectrumSourceId);
      CheckEquals(OLD_DEFAULT_SCALE_DB, d.DefaultScaleDb, 'K4 default scale');
      CheckEquals(OLD_MIN_SCALE_DB, d.MinScaleDb, 'K4 min scale');
      CheckEquals(OLD_MAX_SCALE_DB, d.MaxScaleDb, 'K4 max scale');
      CheckTrue(d.RefMarginDb = OLD_REF_MARGIN_DB,
                'K4 margin is 10 dB, got ' + DescribeDefaults(d));
      CheckTrue(d.WaterfallFraction = OLD_WATERFALL_FRACTION,
                'K4 waterfall share is 0.5, got ' + DescribeDefaults(d));
      CheckTrue(d.LevelsCalibrated, 'the K4 sends real dB');
   finally
      r.Free;
   end;
end;

procedure TSpectrumDisplayDefaultsTests.Test_K4_SameRecordForEverySource;
var
   r: TFactoryRadioBase;
   a: TSpectrumDisplayDefaults;
begin
   BeginTest('K4: pans A, B and the Y mini-pan get one record, as they always have');
   r := uRadioRegistry.CreateInstance(K4);
   CheckTrue(r <> nil, 'the registry built no K4');

   if r = nil then
      begin
      Exit;
      end;

   try
      a := r.SpectrumDisplayDefaults('A');
      CheckTrue(SameSpectrumDisplayDefaults(a, r.SpectrumDisplayDefaults('B')),
                'pan B differs from pan A');
      CheckTrue(SameSpectrumDisplayDefaults(a, r.SpectrumDisplayDefaults('Y')),
                'the Y mini-pan differs from pan A');
   finally
      r.Free;
   end;
end;

(* The walk below would pass on the K4 alone; this names an Icom directly, so
   the family override is seen to be reached. *)
procedure TSpectrumDisplayDefaultsTests.Test_IC9700_StatesTheOldConstantsUncalibrated;
var
   r: TFactoryRadioBase;
   d: TSpectrumDisplayDefaults;
begin
   BeginTest('IC-9700: states the old constants, with uncalibrated levels');
   r := uRadioRegistry.CreateInstance(IC9700);
   CheckTrue(r <> nil, 'the registry built no IC-9700');

   if r = nil then
      begin
      Exit;
      end;

   try
      CheckTrue(r.Supports(rcSpectrum), 'the IC-9700 declares rcSpectrum');
      d := r.SpectrumDisplayDefaults(r.PrimarySpectrumSourceId);
      CheckTrue(SpectrumDisplayDefaultsValid(d),
                'IC-9700 record is valid, got ' + DescribeDefaults(d));
      CheckTrue(MatchesOldConstants(d),
                'IC-9700 is drawn as before the move, got ' + DescribeDefaults(d));
      CheckFalse(d.LevelsCalibrated, 'an Icom sends its own units, not dB');
   finally
      r.Free;
   end;
end;

(* Switching a slot between a K4 and an Icom must keep the operator's slider,
   as it always has: the window resets it only when the scale range differs. *)
procedure TSpectrumDisplayDefaultsTests.Test_K4AndIcom_ShareOneScaleRange;
var
   radioK4, radioIcom: TFactoryRadioBase;
   a, b: TSpectrumDisplayDefaults;
begin
   BeginTest('K4 vs IC-9700: the scale range does not differ, so the slider is kept');
   radioK4 := uRadioRegistry.CreateInstance(K4);
   radioIcom := uRadioRegistry.CreateInstance(IC9700);

   try
      CheckTrue((radioK4 <> nil) and (radioIcom <> nil), 'the registry built both radios');

      if (radioK4 = nil) or (radioIcom = nil) then
         begin
         Exit;
         end;

      a := radioK4.SpectrumDisplayDefaults(radioK4.PrimarySpectrumSourceId);
      b := radioIcom.SpectrumDisplayDefaults(radioIcom.PrimarySpectrumSourceId);
      CheckFalse(SpectrumScaleRangeDiffers(a, b),
                 'K4 ' + DescribeDefaults(a) + ' vs IC-9700 ' + DescribeDefaults(b));
      CheckFalse(SameSpectrumDisplayDefaults(a, b),
                 'the records do differ (LevelsCalibrated) -- which is why the ' +
                 'window must not compare whole records');

      b.MaxScaleDb := b.MaxScaleDb + 1;
      CheckTrue(SpectrumScaleRangeDiffers(a, b), 'a different max is a different range');
   finally
      radioK4.Free;
      radioIcom.Free;
   end;
end;

procedure TSpectrumDisplayDefaultsTests.Test_EverySpectrumRadio_StatesAValidRecord;
var
   ids: TArray<string>;
   id: string;
   r: TFactoryRadioBase;
   d: TSpectrumDisplayDefaults;
   bad: string;
   spectrum, checked: integer;
begin
   BeginTest('Registry: every rcSpectrum radio states a valid record; every other states none');
   bad := '';
   spectrum := 0;
   checked := 0;
   ids := uRadioRegistry.RegisteredIds;

   for id in ids do
      begin
      r := uRadioRegistry.CreateInstanceId(id);

      if r = nil then
         begin
         Continue;
         end;

      try
         Inc(checked);
         d := r.SpectrumDisplayDefaults(r.PrimarySpectrumSourceId);

         if r.Supports(rcSpectrum) then
            begin
            Inc(spectrum);

            if not SpectrumDisplayDefaultsValid(d) then
               begin
               bad := bad + uRadioRegistry.DisplayNameId(id) + ' [' +
                      DescribeDefaults(d) + '] ';
               end;
            end
         else if not SameSpectrumDisplayDefaults(d, SpectrumDisplayDefaultsNone) then
            begin
            bad := bad + uRadioRegistry.DisplayNameId(id) +
                   ' (no rcSpectrum, yet states ' + DescribeDefaults(d) + ') ';
            end;
      finally
         r.Free;
      end;
      end;

   CheckTrue(checked > 0, 'the registry produced no radios to check');
   CheckTrue(spectrum > 0, 'no registered radio declares rcSpectrum');
   CheckEquals('', bad, 'radios whose display defaults disagree with rcSpectrum');
end;

procedure TSpectrumDisplayDefaultsTests.Test_EverySpectrumRadio_StatesTheOldConstants;
var
   ids: TArray<string>;
   id: string;
   r: TFactoryRadioBase;
   d: TSpectrumDisplayDefaults;
   differ: string;
begin
   BeginTest('Registry: every rcSpectrum radio is drawn exactly as before the move');
   differ := '';
   ids := uRadioRegistry.RegisteredIds;

   for id in ids do
      begin
      r := uRadioRegistry.CreateInstanceId(id);

      if r = nil then
         begin
         Continue;
         end;

      try
         if r.Supports(rcSpectrum) then
            begin
            d := r.SpectrumDisplayDefaults(r.PrimarySpectrumSourceId);

            if not MatchesOldConstants(d) then
               begin
               differ := differ + uRadioRegistry.DisplayNameId(id) + ' [' +
                         DescribeDefaults(d) + '] ';
               end;
            end;
      finally
         r.Free;
      end;
      end;

   (* A deliberate change to a radio's display numbers lands here: update this
      pin in the same commit and say why. *)
   CheckEquals('', differ,
               'rcSpectrum radios whose display differs from the pre-move constants');
end;

procedure TSpectrumDisplayDefaultsTests.RunAllTests;
begin
   Test_Neutral_IsAllZeroAndNotValid;
   Test_Validity_RejectsEachBrokenField;
   Test_K4_StatesTheOldConstants;
   Test_K4_SameRecordForEverySource;
   Test_IC9700_StatesTheOldConstantsUncalibrated;
   Test_K4AndIcom_ShareOneScaleRange;
   Test_EverySpectrumRadio_StatesAValidRecord;
   Test_EverySpectrumRadio_StatesTheOldConstants;
end;

end.
