unit uTestYaesuBinary;

{
  Guards the FT-817 group's CAPABILITY FLAGS -- the small-rig old-binary Yaesus
  (FT-817/818/847/857/897).

  WHY THIS EXISTS.  The FT-847 shares the FT-817's transport and its MAIN-VFO
  opcodes, so it is a subclass -- but its opcode chart (FT-847 manual p.92) has
  NO split row, NO clarifier rows and NO data modes.  Inheriting those methods
  unguarded would send opcodes the radio does not define, and would read
  TX-status bit 5 as split when that radio's Note 2 layout is its own.

  The guards are four subclass-set flags.  A flag is easy to drop in a later
  refactor and the failure is SILENT -- the radio just receives a command it
  never documented -- so each is asserted here by capturing what actually goes
  on the wire.

  NO TRANSPORT.  Probe subclasses override SendToRadio to capture bytes, so
  nothing is opened and this runs in CI. That means these tests prove what the
  DRIVER emits, never what a radio accepts. None of these radios has been
  bench-tested; see docs/RADIO_MIGRATION_ASSUMPTIONS.md.

  Framework note: uTR4WTestFramework calls TearDown after EVERY assertion, so
  each test builds and frees its own probe rather than sharing fixture state.
}

interface

uses
   SysUtils, uTR4WTestFramework, uFactoryRadioBase, uRadioYaesuFT817,
   uRadioYaesuFT847, uRadioYaesuFT857, uRadioRegistry, VC;

type
   TYaesuBinaryTests = class(TTestCase)
   protected
      procedure Test_FT847_DoesNotSendSplit;
      procedure Test_FT817_DoesSendSplit;
      procedure Test_FT847_DoesNotSendClarifier;
      procedure Test_FT847_RefusesDataModes;
      procedure Test_FT857_HasDIGButNotPKT;
      procedure Test_FT847_DeclaresNoSplitCapability;
      procedure Test_GroupModelsAreRegistered;
   public
      procedure RunAllTests; override;
   end;

implementation

type
   // Capture the wire instead of opening a port.
   TFT847Probe = class(TYaesuFT847Radio)
   public
      sent: string;
      procedure SendToRadio(s: string); overload; override;
   end;

   TFT817Probe = class(TYaesuFT817Radio)
   public
      sent: string;
      procedure SendToRadio(s: string); overload; override;
   end;

   TFT857Probe = class(TYaesuFT857Radio)
   public
      sent: string;
      procedure SendToRadio(s: string); overload; override;
   end;

procedure TFT847Probe.SendToRadio(s: string);
begin
   sent := sent + s;
end;

procedure TFT817Probe.SendToRadio(s: string);
begin
   sent := sent + s;
end;

procedure TFT857Probe.SendToRadio(s: string);
begin
   sent := sent + s;
end;

procedure TYaesuBinaryTests.Test_FT847_DoesNotSendSplit;
var
   r: TFT847Probe;
begin
   // The FT-847 chart has no SPLIT row at all; $02/$82 are undefined there.
   BeginTest('FT-847 sends nothing for Split (no such command on that radio)');
   r := TFT847Probe.Create;
   try
      r.sent := '';
      r.Split(True);
      r.Split(False);
      CheckEquals('', r.sent, 'FT-847 emitted a split command');
   finally
      r.Free;
   end;
end;

procedure TYaesuBinaryTests.Test_FT817_DoesSendSplit;
var
   r: TFT817Probe;
begin
   // Guards the guard: if Split were broken for EVERYONE the test above would
   // pass while proving nothing. The FT-817 does have $02/$82 and must use them.
   BeginTest('FT-817 still sends a split command (proves the FT-847 test is not vacuous)');
   r := TFT817Probe.Create;
   try
      r.sent := '';
      r.Split(True);
      CheckTrue(Length(r.sent) = 5, Format('expected a 5-byte frame, got %d bytes',
                                           [Length(r.sent)]));
   finally
      r.Free;
   end;
end;

procedure TYaesuBinaryTests.Test_FT847_DoesNotSendClarifier;
var
   r: TFT847Probe;
begin
   // No CLAR ON/OFF and no CLAR Frequency row in the FT-847 chart.
   BeginTest('FT-847 sends nothing for any RIT entry point');
   r := TFT847Probe.Create;
   try
      r.sent := '';
      r.RITOn(nrVFOA);
      r.RITOff(nrVFOA);
      r.SetRITFreq(nrVFOA, 500);
      r.RITClear(nrVFOA);
      CheckEquals('', r.sent, 'FT-847 emitted a clarifier command');
   finally
      r.Free;
   end;
end;

procedure TYaesuBinaryTests.Test_FT847_RefusesDataModes;
var
   r: TFT847Probe;
begin
   // Mode chart is LSB/USB/CW/CW-R/AM/FM plus narrow variants -- no DIG, no PKT.
   // $FF marks "radio has not got it"; transmitting $FF would be an undefined
   // mode byte, so SetMode must refuse rather than send.
   BeginTest('FT-847 refuses rmData/rmFSK instead of sending $FF');
   r := TFT847Probe.Create;
   try
      r.sent := '';
      r.SetMode(rmData, nrVFOA);
      r.SetMode(rmFSK, nrVFOA);
      CheckEquals('', r.sent, 'FT-847 emitted a data-mode command');
      // ...but a mode it DOES have still works.
      r.sent := '';
      r.SetMode(rmCW, nrVFOA);
      CheckTrue(Length(r.sent) = 5, 'FT-847 failed to send a mode it supports');
   finally
      r.Free;
   end;
end;

procedure TYaesuBinaryTests.Test_FT857_HasDIGButNotPKT;
var
   r: TFT857Probe;
begin
   // Row: DIGU $0A, DIGL $FF. The radio HAS $0C (PKT) but TR4W does not offer it
   // on this model -- preserved from D7 deliberately.
   BeginTest('FT-857 sends DIG for rmData but refuses rmFSK');
   r := TFT857Probe.Create;
   try
      r.sent := '';
      r.SetMode(rmData, nrVFOA);
      CheckTrue(Length(r.sent) = 5, 'FT-857 should send DIG ($0A) for rmData');
      r.sent := '';
      r.SetMode(rmFSK, nrVFOA);
      CheckEquals('', r.sent, 'FT-857 should not send PKT for rmFSK');
   finally
      r.Free;
   end;
end;

procedure TYaesuBinaryTests.Test_FT847_DeclaresNoSplitCapability;
var
   a: TFT847Probe;
   b: TFT817Probe;
begin
   // The absence is DECLARED, so a caller can tell "off" from "cannot know".
   BeginTest('FT-847 declares no split capability; FT-817 declares it');
   a := TFT847Probe.Create;
   b := TFT817Probe.Create;
   try
      CheckFalse(rcReadSplit in a.Capabilities.Flags);
      CheckTrue(rcReadSplit in b.Capabilities.Flags);
   finally
      b.Free;
      a.Free;
   end;
end;

procedure TYaesuBinaryTests.Test_GroupModelsAreRegistered;
var
   missing: string;

   procedure Need(m: InterfacedRadioType; const name: string);
   begin
      if not IsRegistered(m) then
         begin
         missing := missing + name + ' ';
         end;
   end;

begin
   // Every model an operator can buy needs its own entry or it is invisible in
   // the radio list.
   BeginTest('FT-817/818/847/857/897 are all registered in the factory');
   missing := '';
   Need(FT817, 'FT817');
   Need(FT818, 'FT818');
   Need(FT847, 'FT847');
   Need(FT857, 'FT857');
   Need(FT897, 'FT897');
   CheckEquals('', missing, 'unregistered models: ' + missing);
end;

procedure TYaesuBinaryTests.RunAllTests;
begin
   Test_FT847_DoesNotSendSplit;
   Test_FT817_DoesSendSplit;
   Test_FT847_DoesNotSendClarifier;
   Test_FT847_RefusesDataModes;
   Test_FT857_HasDIGButNotPKT;
   Test_FT847_DeclaresNoSplitCapability;
   Test_GroupModelsAreRegistered;
end;

end.
