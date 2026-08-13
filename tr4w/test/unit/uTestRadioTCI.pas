unit uTestRadioTCI;
{$I ..\..\src\tr4w.inc}

{
  THE NINE METHODS THAT USED TO CRASH.

  TFactoryRadioBase declares 29 methods Virtual; Abstract. TTCIRadio implemented
  20 of them. The other nine -- ToggleMode, SetBand, ToggleBand, SetFilter,
  MemoryKeyer, RITBumpUp/Down, VFOBumpUp/Down -- were left abstract, so a key
  press that reached any of them was an access violation on a radio that was
  otherwise working.

  The compiler DOES report this, as nine W1020 "Constructing instance of
  TTCIRadio containing abstract method" warnings -- but only on a full /t:Build.
  An incremental /t:Make skips the unit that constructs the object and the
  warnings never appear, which is exactly how they went unnoticed. A warning you
  only see on a build nobody runs before committing is not a safety net; this
  test is.

  THE PRIMARY ASSERTION IS "DOES NOT FAULT". Every one of the nine is called.
  Before the fix each of those calls access-violated; a test that only checked
  the emitted text would have failed for the wrong reason and told us less.

  NO TRANSPORT: the probe overrides SendToRadio to capture the wire, so this
  runs in CI and proves what the DRIVER emits, never what a server accepts.
  Same shape as uTestKenwoodSerial.
}

interface

uses
   SysUtils, uTR4WTestFramework, uFactoryRadioBase, uRadioBand, uRadioTCI, VC;

type
   TRadioTCITests = class(TTestCase)
   protected
      procedure Test_NoneOfTheNineFault;
      procedure Test_ToggleModeCyclesAndSends;
      procedure Test_ToggleModeWrapsAtTheEnd;
      procedure Test_SetBandTunesToTheBandFrequency;
      procedure Test_ToggleBandCyclesAndWraps;
      procedure Test_SetFilterSendsSymmetricEdges;
      procedure Test_MemoryKeyerRefusesAndSendsNothing;
      procedure Test_RelativeTuneSendsNothing;
   public
      procedure RunAllTests; override;
   end;

implementation

type
   TTCIProbe = class(TTCIRadio)
   public
      sent: string;
      procedure SendToRadio(s: string); overload; override;
      procedure Clear;
   end;

procedure TTCIProbe.SendToRadio(s: string);
begin
   // Appended, not replaced: a method that emits two commands must not be able
   // to hide the first one behind the second.
   sent := sent + s;
end;

procedure TTCIProbe.Clear;
begin
   sent := '';
end;

{ ------------------------------------------------------------------------- }

// The regression itself. Every one of the nine is exercised; before the fix
// this test could not even run to completion.
procedure TRadioTCITests.Test_NoneOfTheNineFault;
var
   r: TTCIProbe;
begin
   BeginTest('Test_NoneOfTheNineFault');
   r := TTCIProbe.Create;
   try
      r.ToggleMode(nrVFOA);
      r.SetBand(rb20m, nrVFOA);
      r.ToggleBand(nrVFOA);
      r.SetFilter(rfNarrow, nrVFOA);
      r.MemoryKeyer(1);
      r.RITBumpUp;
      r.RITBumpDown;
      r.VFOBumpUp(nrVFOA);
      r.VFOBumpDown(nrVFOA);

      // Reaching this line IS the assertion -- every call above was an abstract
      // method, and an abstract call raises rather than returning.
      Check(True, 'all nine formerly-abstract methods are callable');
   finally
      r.Free;
   end;
end;

procedure TRadioTCITests.Test_ToggleModeCyclesAndSends;
var
   r: TTCIProbe;
begin
   BeginTest('Test_ToggleModeCyclesAndSends');
   r := TTCIProbe.Create;
   try
      r.vfo[nrVFOA].mode := rmUSB;
      r.Clear;

      CheckEquals(Ord(rmCW), Ord(r.ToggleMode(nrVFOA)),
                  'USB toggles to CW, matching the Icom family order');
      Check(Pos('modulation:', r.sent) > 0,
            'a mode change must actually reach the wire, not only the cache');
   finally
      r.Free;
   end;
end;

// The wrap is the arm that a case statement most often gets wrong, and getting
// it wrong strands the operator on the last mode with the key doing nothing.
procedure TRadioTCITests.Test_ToggleModeWrapsAtTheEnd;
var
   r: TTCIProbe;
begin
   BeginTest('Test_ToggleModeWrapsAtTheEnd');
   r := TTCIProbe.Create;
   try
      r.vfo[nrVFOA].mode := rmFM;
      CheckEquals(Ord(rmLSB), Ord(r.ToggleMode(nrVFOA)), 'FM wraps round to LSB');
   finally
      r.Free;
   end;
end;

procedure TRadioTCITests.Test_SetBandTunesToTheBandFrequency;
var
   r: TTCIProbe;
begin
   BeginTest('Test_SetBandTunesToTheBandFrequency');
   r := TTCIProbe.Create;
   try
      r.Clear;
      r.SetBand(rb20m, nrVFOA);

      // TCI has no band command, so a band change MUST appear as a tune. If this
      // ever emits nothing, the band keys silently stop working.
      Check(Pos('vfo:', r.sent) > 0,
            'SetBand reaches the radio as a vfo: tune');
      Check(Pos(IntToStr(r.BandToFreq(rb20m)), r.sent) > 0,
            'and tunes to the base table frequency, not a second copy of it');
   finally
      r.Free;
   end;
end;

procedure TRadioTCITests.Test_ToggleBandCyclesAndWraps;
var
   r: TTCIProbe;
begin
   BeginTest('Test_ToggleBandCyclesAndWraps');
   r := TTCIProbe.Create;
   try
      r.vfo[nrVFOA].band := rb20m;
      CheckEquals(Ord(rb15m), Ord(r.ToggleBand(nrVFOA)), '20m steps up to 15m');

      r.vfo[nrVFOA].band := rb10m;
      CheckEquals(Ord(rb160m), Ord(r.ToggleBand(nrVFOA)),
                  '10m wraps round to 160m');
   finally
      r.Free;
   end;
end;

procedure TRadioTCITests.Test_SetFilterSendsSymmetricEdges;
var
   r: TTCIProbe;
begin
   BeginTest('Test_SetFilterSendsSymmetricEdges');
   r := TTCIProbe.Create;
   try
      r.Clear;
      r.SetFilter(rfNarrow, nrVFOA);

      // TCI takes EDGES relative to the carrier, not a width -- a driver that
      // sent the width would give a filter twice as wide as asked for.
      Check(Pos('rx_filter_band:0,-250,250;', r.sent) > 0,
            'narrow = 500 Hz wide, sent as -250/+250 edges');

      r.Clear;
      r.SetFilter(rfWide, nrVFOA);
      Check(Pos('rx_filter_band:0,-1350,1350;', r.sent) > 0,
            'wide = 2700 Hz wide, sent as -1350/+1350 edges');
   finally
      r.Free;
   end;
end;

// True means ERROR/UNSUPPORTED for this method -- the house convention, and it
// fails closed. A driver returning False here would tell the caller a memory
// was played when nothing happened.
procedure TRadioTCITests.Test_MemoryKeyerRefusesAndSendsNothing;
var
   r: TTCIProbe;
begin
   BeginTest('Test_MemoryKeyerRefusesAndSendsNothing');
   r := TTCIProbe.Create;
   try
      r.Clear;
      Check(r.MemoryKeyer(1), 'MemoryKeyer reports unsupported (True = error)');
      CheckEquals('', r.sent, 'and puts nothing on the wire');
   finally
      r.Free;
   end;
end;

// Pinned deliberately: these four REFUSE by design, because TCI is an absolute
// protocol and a step size would have to be invented -- moving a TCI radio by a
// different amount than the radio beside it on the same key. If someone later
// implements them against a configured step, this test should be updated WITH
// that change, not deleted by it.
procedure TRadioTCITests.Test_RelativeTuneSendsNothing;
var
   r: TTCIProbe;
begin
   BeginTest('Test_RelativeTuneSendsNothing');
   r := TTCIProbe.Create;
   try
      r.Clear;
      r.RITBumpUp;
      r.RITBumpDown;
      r.VFOBumpUp(nrVFOA);
      r.VFOBumpDown(nrVFOA);

      CheckEquals('', r.sent,
                  'no relative-tune command exists in TCI, so nothing is sent');
   finally
      r.Free;
   end;
end;

procedure TRadioTCITests.RunAllTests;
begin
   Test_NoneOfTheNineFault;
   Test_ToggleModeCyclesAndSends;
   Test_ToggleModeWrapsAtTheEnd;
   Test_SetBandTunesToTheBandFrequency;
   Test_ToggleBandCyclesAndWraps;
   Test_SetFilterSendsSymmetricEdges;
   Test_MemoryKeyerRefusesAndSendsNothing;
   Test_RelativeTuneSendsNothing;
end;

end.
