unit uTestKenwoodSerial;

{
  Guards TKenwoodSerial against silently drifting away from the LEGACY path.

  Twelve Kenwoods now share this base and only ONE of them (the TS-570) has been
  benched through the factory. For the other eleven the only evidence about what
  the radio accepts is what TR4W has been sending them for years, so "does the
  factory still send what LOGRADIO sent" is the strongest test available.

  THE SPLIT PREFIX. LOGRADIO.PAS:2066 / :2135 send TWO commands:

      AddToOutputBuffer('FR0;FT1;', 8);     // and 'FR0;FT0;' to clear

  with a maintainer's note attached:

      KK1L: 6.71 For some reason needed this to get the FT1; command to take.
                  Started when I added setting mode of B VFO to set freq.

  The migration dropped the FR0; and sent FT alone. Nothing caught it, because a
  driver that sends FT1; looks perfectly reasonable in isolation -- you only see
  the problem by reading the legacy. Hence this test.

  NO TRANSPORT: the probe overrides SendToRadio to capture the wire, so this
  runs in CI and proves what the DRIVER emits, never what a radio accepts.
}

interface

uses
   SysUtils, uTR4WTestFramework, uFactoryRadioBase, uRadioKenwoodSerial,
   uRadioKenwoodTS570, uRadioKenwoodTS950, uRadioKenwoodTS440,
   uRadioRegistry, VC;

type
   TKenwoodSerialTests = class(TTestCase)
   protected
      procedure Test_SplitOnSendsFRThenFT;
      procedure Test_SplitOffSendsFRThenFT;
      procedure Test_SplitTracksActiveVFO;
      procedure Test_ModelsShareTheBaseSplit;
      procedure Test_NoVFOSeedFlipWhileSplitIsOn;
      procedure Test_VFOSeedFlipHappensWhenSplitIsOff;
      procedure Test_TS440UsesIC10SplitCommand;
   public
      procedure RunAllTests; override;
   end;

implementation

type
   TKenwoodProbe = class(TKenwoodSerial)
   public
      sent: string;
      procedure SendToRadio(s: string); overload; override;
      // Connect arms the one-shot VFO-mode seed, but Connect needs a real port.
      // Arm it directly so the seeding path is actually reachable in a test --
      // without this both seed tests pass VACUOUSLY, which is exactly what
      // happened on the first run.
      procedure ArmVFOModeSeed;
   end;

   TTS950Probe = class(TKenwoodTS950Radio)
   public
      sent: string;
      procedure SendToRadio(s: string); overload; override;
   end;

   TTS440Probe = class(TKenwoodTS440Radio)
   public
      sent: string;
      procedure SendToRadio(s: string); overload; override;
   end;

procedure TKenwoodProbe.SendToRadio(s: string);
begin
   sent := sent + s;
end;

procedure TKenwoodProbe.ArmVFOModeSeed;
begin
   FSeedOtherVFOMode := True;
end;

procedure TTS950Probe.SendToRadio(s: string);
begin
   sent := sent + s;
end;

procedure TTS440Probe.SendToRadio(s: string);
begin
   sent := sent + s;
end;

procedure TKenwoodSerialTests.Test_SplitOnSendsFRThenFT;
var
   r: TKenwoodProbe;
begin
   // Exactly what LOGRADIO:2066 puts on the wire.
   BeginTest('Split(True) sends FR0;FT1; -- not FT1; alone');
   r := TKenwoodProbe.Create;
   try
      r.Split(True);
      CheckEquals('FR0;FT1;', r.sent, 'must match the legacy AddToOutputBuffer');
      // Paired opposite: pin the specific regression rather than just "non-empty".
      CheckTrue(r.sent <> 'FT1;', 'FT1; alone was the regression -- KK1L 6.71 says it may not take');
   finally
      r.Free;
   end;
end;

procedure TKenwoodSerialTests.Test_SplitOffSendsFRThenFT;
var
   r: TKenwoodProbe;
begin
   BeginTest('Split(False) sends FR0;FT0; -- not FT0; alone');
   r := TKenwoodProbe.Create;
   try
      r.Split(False);
      CheckEquals('FR0;FT0;', r.sent, 'must match the legacy AddToOutputBuffer');
      CheckTrue(r.sent <> 'FT0;', 'FT0; alone was the regression');
   finally
      r.Free;
   end;
end;

procedure TKenwoodSerialTests.Test_SplitTracksActiveVFO;
var
   r: TKenwoodProbe;
begin
   // FR0; moves the RX pointer to VFO A on the radio. If the driver does not
   // follow, its own idea of the active VFO disagrees with the rig and the next
   // IF parse writes the frequency into the wrong VFO slot.
   BeginTest('Split leaves the driver''s active VFO on A, matching FR0;');
   r := TKenwoodProbe.Create;
   try
      r.SetActiveVFO(nrVFOB);
      r.Split(True);
      CheckEquals(Ord(nrVFOA), Ord(r.GetActiveVFO),
                  'FR0; put RX on VFO A; the driver must agree');
   finally
      r.Free;
   end;
end;

procedure TKenwoodSerialTests.Test_ModelsShareTheBaseSplit;
var
   r: TTS950Probe;
begin
   // The TS-950 is one of the eleven unbenched models and is a thin subclass, so
   // it must inherit the base behaviour verbatim. NY4I confirmed this radio does
   // support FR/FT -- an earlier claim that it did not came from reading
   // HamLib's SILENCE as evidence, which it is not.
   BeginTest('an unbenched model (TS-950) inherits the base split verbatim');
   r := TTS950Probe.Create;
   try
      r.Split(True);
      CheckEquals('FR0;FT1;', r.sent, 'TS-950 must send what LOGRADIO sent it');
   finally
      r.Free;
   end;
end;

// Real IF responses captured from NY4I's TS-570 (tr4w.log, 2026-07-29 12:35:13).
// 37-character bodies -- the terminator is stripped before the driver sees them.
// They differ in ONE character, at L-4, which is the split field.
const
   IF_SPLIT_ON  = 'IF00021300000     -051000 0002001008 ';
   IF_SPLIT_OFF = 'IF00021300000     -051000 0002000008 ';

// A bare FR CANCELS SPLIT on this radio. The driver used to seed the other VFO's
// mode with FR1;IF;FR0;IF; at connect, which silently dropped the operator's
// split seconds after startup -- observed on the bench, and visible in that log
// as the split field going 1 -> 0 on the IF immediately after the flip.
//
// LOGRADIO never sends a bare FR: every occurrence pairs it with an FT in the
// same write, so split is always re-asserted. The flip had no legacy precedent.
procedure TKenwoodSerialTests.Test_NoVFOSeedFlipWhileSplitIsOn;
var
   r: TKenwoodProbe;
begin
   BeginTest('no FR seed flip while split is on -- a bare FR cancels split');
   r := TKenwoodProbe.Create;
   try
      r.ArmVFOModeSeed;
      r.ProcessMsg(IF_SPLIT_ON);
      CheckEquals('', r.sent,
                  'must send NOTHING: an FR flip here cancels the operator''s split');
   finally
      r.Free;
   end;
end;

// Paired opposite. Without this the test above would pass if the seeding were
// deleted outright, or never armed -- neither of which is the intended fix.
procedure TKenwoodSerialTests.Test_VFOSeedFlipHappensWhenSplitIsOff;
var
   r: TKenwoodProbe;
begin
   BeginTest('the FR seed flip still runs when split is off');
   r := TKenwoodProbe.Create;
   try
      r.ArmVFOModeSeed;
      r.ProcessMsg(IF_SPLIT_OFF);
      CheckEquals('FR1;IF;FR0;IF;', r.sent,
                  'with split off the flip is safe and should still seed VFO B''s mode');
   finally
      r.Free;
   end;
end;

// The TS-440 uses the older Kenwood IC-10 interface, where split is its own flag
// rather than a consequence of the FR/FT relationship: SP1;/SP0;, not FR0;FT1;.
// Confirmed by NY4I from the command reference, and independently by HamLib,
// which routes this radio through ic10.c (ic10_set_split_vfo sends exactly that).
//
// Paired with a TS-950 assertion so the test cannot pass by the BASE having been
// changed -- the whole point is that this is ONE model diverging while its eleven
// siblings keep FR0;FT1;.
//
// It must also NOT move the active VFO: no FR is sent, so claiming RX moved would
// put the driver out of step with the radio and misfile the next IF frequency.
procedure TKenwoodSerialTests.Test_TS440UsesIC10SplitCommand;
var
   r440: TTS440Probe;
   r950: TTS950Probe;
begin
   BeginTest('TS-440 splits with SP1;/SP0; while its siblings still use FR0;FT1;');
   r440 := TTS440Probe.Create;
   r950 := TTS950Probe.Create;
   try
      r440.SetActiveVFO(nrVFOB);
      r440.Split(True);
      CheckEquals('SP1;', r440.sent, 'TS-440 split on is the IC-10 SP command');
      CheckEquals(Ord(nrVFOB), Ord(r440.GetActiveVFO),
                  'no FR was sent, so the active VFO must NOT have moved');

      r440.sent := '';
      r440.Split(False);
      CheckEquals('SP0;', r440.sent, 'TS-440 split off is SP0;');

      // The base must be untouched.
      r950.Split(True);
      CheckEquals('FR0;FT1;', r950.sent,
                  'the TS-440 override must not have changed the family default');
   finally
      r440.Free;
      r950.Free;
   end;
end;

procedure TKenwoodSerialTests.RunAllTests;
begin
   Test_SplitOnSendsFRThenFT;
   Test_SplitOffSendsFRThenFT;
   Test_SplitTracksActiveVFO;
   Test_ModelsShareTheBaseSplit;
   Test_NoVFOSeedFlipWhileSplitIsOn;
   Test_VFOSeedFlipHappensWhenSplitIsOff;
   Test_TS440UsesIC10SplitCommand;
end;

end.
