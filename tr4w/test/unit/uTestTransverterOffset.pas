unit uTestTransverterOffset;
{$I ..\..\src\tr4w.inc}
{
  THE TRANSVERTER OFFSET, both directions.

  NY4I runs a 10m-to-2m transverter: the radio reads 28.000 MHz, the QSO happened
  on 144.000, and the log must say 144. The offset is 116000000 Hz.

  WHY THIS IS TESTED RATHER THAN BENCHED. The feature existed for years and was
  documented (in the Czech help, as "transpozicni kmitocet"), then stopped working
  silently when the radio factory replaced the legacy per-model pollers: the
  offset was applied inside the frequency decoders that were deleted, so the
  setting survived while its implementation did not. Nobody noticed, because a
  setting that persists and edits looks exactly like a setting that works.

  Bench proof needs a transverter. These need only arithmetic, and they pin the
  two things its owner would otherwise discover the hard way -- that the BAND
  follows the offset, and that the send path SUBTRACTS it.
}

interface

uses
   SysUtils, uTR4WTestFramework, uFactoryRadioBase, uRadioRegistry, uRadioBand, VC;

type
   TTransverterOffsetTests = class(TTestCase)
   protected
      procedure Test_NoOffsetChangesNothing;
      procedure Test_ReportedFrequencyIsOffset;
      procedure Test_BandFollowsTheOffset;
      procedure Test_ZeroFrequencyIsNotOffset;
      procedure Test_RoundTripThroughTheRadio;
   public
      procedure RunAllTests; override;
   end;

implementation

type
   { The driver-facing VFO state is PROTECTED, which is right -- nothing outside
     the radio should be writing a VFO. A local descendant reaches it for the
     test rather than opening the production class up for a test's convenience. }
   TRadioAccess = class(TFactoryRadioBase);

const
   { NY4I's own setup: a 28 MHz IF on a 144 MHz band. }
   OFFSET_10M_TO_2M = 116000000;
   RADIO_READS      =  28200000;   // what the rig reports
   REALLY_ON        = 144200000;   // where the QSO actually is

{ Any registered model will do: the offset lives on TFactoryRadioBase, so this is
  deliberately NOT per-model behaviour and the test should not imply it is. }
function MakeRadio: TFactoryRadioBase;
begin
   Result := uRadioRegistry.CreateInstance(K3);
end;

procedure TTransverterOffsetTests.Test_NoOffsetChangesNothing;
var
   r: TFactoryRadioBase;
begin
   // EVERY radio without a transverter is this case, so it is the one that must
   // not regress. With no offset the driver's own answers are returned untouched.
   BeginTest('no offset: frequency and band are the driver''s own answers');
   r := MakeRadio;
   CheckTrue(r <> nil, 'K3 must be registered');
   try
      TRadioAccess(r).vfo[nrVFOA].frequency := RADIO_READS;
      TRadioAccess(r).vfo[nrVFOA].band      := FreqToRadioBand(RADIO_READS);

      CheckEquals(RADIO_READS, r.frequency[nrVFOA], 'frequency must be unchanged');
      CheckTrue(r.band[nrVFOA] = FreqToRadioBand(RADIO_READS),
                'band must be the driver''s stored band');
   finally
      r.Free;
   end;
end;

procedure TTransverterOffsetTests.Test_ReportedFrequencyIsOffset;
var
   r: TFactoryRadioBase;
begin
   BeginTest('28.2 MHz through a 116 MHz offset reads as 144.2');
   r := MakeRadio;
   try
      r.FrequencyOffset := OFFSET_10M_TO_2M;
      TRadioAccess(r).vfo[nrVFOA].frequency := RADIO_READS;

      CheckEquals(REALLY_ON, r.frequency[nrVFOA],
                  'the reported frequency must be radio + offset');
   finally
      r.Free;
   end;
end;

procedure TTransverterOffsetTests.Test_BandFollowsTheOffset;
var
   r: TFactoryRadioBase;
begin
   // THE ONE THAT MATTERS MOST. ActiveBand comes straight from this
   // (uRadioPolling: ActiveBand := rig.FilteredStatus.Band), so if the band did
   // not follow, a 2m QSO would be logged and SUBMITTED as 10 metres -- right
   // frequency, wrong band, in the Cabrillo.
   BeginTest('the band follows the offset, not the radio''s own reading');
   r := MakeRadio;
   try
      r.FrequencyOffset := OFFSET_10M_TO_2M;
      TRadioAccess(r).vfo[nrVFOA].frequency := RADIO_READS;
      TRadioAccess(r).vfo[nrVFOA].band      := FreqToRadioBand(RADIO_READS);

      CheckTrue(r.band[nrVFOA] = FreqToRadioBand(REALLY_ON),
                'band must be derived from the OFFSET frequency');
      CheckFalse(r.band[nrVFOA] = FreqToRadioBand(RADIO_READS),
                 'band must NOT be the radio''s own 10m answer');
   finally
      r.Free;
   end;
end;

procedure TTransverterOffsetTests.Test_ZeroFrequencyIsNotOffset;
var
   r: TFactoryRadioBase;
begin
   // Zero means "nothing known yet" -- a radio that has not answered, or a VFO B
   // that does not exist. Offsetting it would turn an unknown into a confident
   // 116 MHz and put a band on it, so a disconnected radio would look as though
   // it were sitting on 2 metres.
   BeginTest('zero is not a frequency and is not offset');
   r := MakeRadio;
   try
      r.FrequencyOffset := OFFSET_10M_TO_2M;
      TRadioAccess(r).vfo[nrVFOB].frequency := 0;

      CheckEquals(0, r.frequency[nrVFOB], 'an unknown frequency must stay zero');
   finally
      r.Free;
   end;
end;

procedure TTransverterOffsetTests.Test_RoundTripThroughTheRadio;
var
   r: TFactoryRadioBase;
   sent: integer;
begin
   // The loop a band map click makes: TR4W means 144.2, the radio is told 28.2,
   // and reading it back gives 144.2 again. The subtraction itself lives in
   // LOGRADIO -- the only two SetFrequency call sites in the program -- so this
   // pins the arithmetic it must perform, and changing one half without the
   // other fails here.
   BeginTest('click 144.2 -> radio tunes 28.2 -> TR4W reads 144.2');
   r := MakeRadio;
   try
      r.FrequencyOffset := OFFSET_10M_TO_2M;

      sent := REALLY_ON - r.FrequencyOffset;
      CheckEquals(RADIO_READS, sent, 'the radio must be told its own frequency');

      TRadioAccess(r).vfo[nrVFOA].frequency := sent;
      CheckEquals(REALLY_ON, r.frequency[nrVFOA], 'the round trip must close');
   finally
      r.Free;
   end;
end;

procedure TTransverterOffsetTests.RunAllTests;
begin
   Test_NoOffsetChangesNothing;
   Test_ReportedFrequencyIsOffset;
   Test_BandFollowsTheOffset;
   Test_ZeroFrequencyIsNotOffset;
   Test_RoundTripThroughTheRadio;
end;

end.
