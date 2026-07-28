unit uTestYaesuASCII;

{
  Unit tests for the Yaesu ASCII CAT drivers -- uRadioYaesuASCII (TYaesuSerial),
  uRadioYaesuFTDX10 and uRadioYaesuFT991.

  ---------------------------------------------------------------------------
  WHAT THESE TESTS DO AND DO NOT PROVE  -- read before trusting a green run
  ---------------------------------------------------------------------------
  These are REGRESSION tests, not correctness proofs.  They lock in the wire
  behaviour that was ported from the bench-proven legacy path (uRadioPolling
  pFTDX10_FTDX101 / pFT891_FT991) so a later refactor cannot silently change it.

  A green run does NOT mean the driver is right about a real radio.  The fixtures
  are shaped from TR4W's own legacy parser offsets, so if the legacy path was wrong
  about a field, these tests faithfully preserve that mistake.  Only hardware, the
  manufacturer's CAT manual, or an independent implementation (hamlib, the D7 tree)
  can settle whether a field is genuinely correct.

  The same caveat applies with more force to the Python simulator in tools/radiosim:
  it was written to match this driver, so agreement between the two proves only
  self-consistency.  That trap has already bitten this project once -- a simulator
  disagreement led to "fixing" a TS-890 driver path that was working on hardware.
  ---------------------------------------------------------------------------

  NO TRANSPORT IS INVOLVED.  No COM port, no virtual serial pair, no threads.
  These exercise the protocol layer directly, which is possible because two seams
  are virtual and public:

    ProcessMessage   feed it exactly what the reading thread would deliver
    SendToRadio      overridden by the test doubles below to capture output

  IMPORTANT -- the reading thread STRIPS the ';' terminator before the driver sees
  a message, so the fixtures here carry NO trailing ';'.  A 28-byte IF response on
  the wire reaches ProcessMessage as 27 characters.  Passing the wire form instead
  would shift nothing (these offsets are start-relative) and the tests would still
  pass, which is why this is stated rather than left to be inferred.

  FRAMEWORK NOTE: uTR4WTestFramework calls TearDown after EVERY assertion, not
  after every test method (Check -> RecordPass/RecordFail -> TearDown).  So a
  SetUp-created object would be destroyed by the first Check and any method with a
  second assertion would fault.  Each test therefore owns its radio in a local
  try/finally.  Do not "tidy" this into SetUp.

  MODE ASSERTIONS COMPARE NAMES, NOT ORDINALS, deliberately.  CheckEquals with
  integers reports Ord(TRadioMode), so a mode failure printed "Expected 5 but got
  11" -- which reads like Yaesu MD codes (where 5 is AM and 11 is nothing) but
  actually meant rmFM vs rmPSK.  Two numbering schemes for one concept in the same
  message is a trap; ModeToString removes it.

  Covers:
    - IF; / OI; parse: frequency, band, mode, clarifier, RIT/XIT flags
    - the mode-character map, including the ONE character where the FT-991
      (C4FM) and the FTDX-10 (PSK31) disagree
    - split from FT;, TX state from TX;
    - malformed and short responses leave state untouched
    - the write side: split, set-frequency, set-mode, poll cycle
}

interface

uses
   SysUtils, uTR4WTestFramework, uFactoryRadioBase, uRadioBand,
   uRadioYaesuASCII, uRadioYaesuFTDX10, uRadioYaesuFT991,
   uRadioYaesuFTDX101, uRadioYaesuFT710, uRadioYaesuFTX1F, uRadioYaesuFT891;

type
   // Test doubles.  They add ONE thing: a record of what the driver transmitted.
   // Everything else is the production class, so the tests exercise real code.
   TFT991Probe = class(TYaesuFT991Radio)
   public
      sent: string;
      procedure SendToRadio(s: string); overload; override;
   end;

   TFTDX10Probe = class(TFTDX10Radio)
   public
      sent: string;
      procedure SendToRadio(s: string); overload; override;
   end;

   // One probe per model whose behaviour differs.  Each is the production class
   // plus a capture of what it transmitted.
   TFT710Probe = class(TFT710Radio)
   public
      sent: string;
      procedure SendToRadio(s: string); overload; override;
   end;

   TFT891Probe = class(TFT891Radio)
   public
      sent: string;
      procedure SendToRadio(s: string); overload; override;
   end;

   TFTX1FProbe = class(TFTX1FRadio)
   public
      sent: string;
      procedure SendToRadio(s: string); overload; override;
   end;

   TYaesuASCIITests = class(TTestCase)
   protected
      // Read path -- IF;/OI; parsing
      procedure Test_IF_Frequency;
      procedure Test_IF_Band;
      procedure Test_IF_ModeCW;
      procedure Test_OI_GoesToVFOB;
      procedure Test_IF_RITOn;
      procedure Test_IF_XITOn;
      procedure Test_IF_ClarifierPositive;
      procedure Test_IF_ClarifierNegative;

      // The one character that separates the two families
      procedure Test_FT991_E_IsC4FM_NotPSK;
      procedure Test_FTDX10_E_IsPSK;
      procedure Test_ModeMap_SharedCharsAgree;
      procedure Test_FTDX10_B_IsFMNarrow;

      // Read path -- split and TX
      procedure Test_FT_NonZeroMeansSplit;
      procedure Test_FT_ZeroMeansNoSplit;
      procedure Test_TX_Transmitting;
      procedure Test_TX_Receiving;

      // Robustness
      procedure Test_ShortMessageIgnored;
      procedure Test_NonNumericFrequencyIgnored;

      // Per-model deviations across the family
      procedure Test_FT710_Split_Uses_FT1_FT0;
      procedure Test_FT891_Split_Uses_ST;
      procedure Test_FT891_Polls_ST_Not_FT;
      procedure Test_FT891_Parses_ST_Response;
      procedure Test_FT891_StillHandlesSharedCommands;
      procedure Test_FTX1F_Offsets_AreShiftedByTwo;
      procedure Test_FTX1F_FTDX10Layout_WouldMisparse;
      procedure Test_FTX1F_C4FM_Chars;
      procedure Test_FTX1F_E_StaysPSK;

      // Write path
      procedure Test_Split_On_Sends_FT3;
      procedure Test_Split_Off_Sends_FT2;
      procedure Test_SetFrequency_VFOA_9Digits;
      procedure Test_SetFrequency_VFOB;
      procedure Test_SetMode_Uses_MD0n;
      procedure Test_PollCycle;

   public
      procedure RunAllTests; override;
   end;

implementation

procedure TFT991Probe.SendToRadio(s: string);
begin
   sent := sent + s;      // capture instead of transmitting; no port is open
end;

procedure TFTDX10Probe.SendToRadio(s: string);
begin
   sent := sent + s;
end;

procedure TFT710Probe.SendToRadio(s: string);
begin
   sent := sent + s;
end;

procedure TFT891Probe.SendToRadio(s: string);
begin
   sent := sent + s;
end;

procedure TFTX1FProbe.SendToRadio(s: string);
begin
   sent := sent + s;
end;

// ---------------------------------------------------------------------------
// Fixture builder
//
// Field positions are the legacy ones (GetVFOInfoForYaesuType3/Type5):
//   1-2 head | 3-5 memory ch | 6-14 freq | 15-19 clarifier | 20 RIT | 21 XIT
//   22 mode | 23-27 filler
// NO trailing ';' -- see the note at the top of this unit.
// ---------------------------------------------------------------------------
function IFMsg(const head, freq, clar, rit, xit, mode: string): string;
begin
   Result := head + '000' + freq + clar + rit + xit + mode + '00000';
   if Length(Result) <> 27 then
      begin
      raise Exception.CreateFmt(
         'test fixture is %d chars, must be 27 (the driver parses the ' +
         'terminator-stripped body)', [Length(Result)]);
      end;
end;

// ---------------------------------------------------------------------------
// Read path -- IF;/OI;
// ---------------------------------------------------------------------------

procedure TYaesuASCIITests.Test_IF_Frequency;
var
   r: TFT991Probe;
begin
   BeginTest('IF; sets VFO A frequency from the 9-digit field');
   r := TFT991Probe.Create;
   try
      r.ProcessMessage(IFMsg('IF', '014025000', '+0000', '0', '0', '3'));
      CheckEquals(14025000, r.vfo[nrVFOA].frequency);
   finally
      r.Free;
   end;
end;

procedure TYaesuASCIITests.Test_IF_Band;
var
   r: TFT991Probe;
begin
   BeginTest('IF; derives the band from the frequency');
   r := TFT991Probe.Create;
   try
      r.ProcessMessage(IFMsg('IF', '014025000', '+0000', '0', '0', '3'));
      CheckEquals(Ord(rb20m), Ord(r.vfo[nrVFOA].band));
   finally
      r.Free;
   end;
end;

procedure TYaesuASCIITests.Test_IF_ModeCW;
var
   r: TFT991Probe;
begin
   BeginTest('IF; mode char 3 = CW');
   r := TFT991Probe.Create;
   try
      r.ProcessMessage(IFMsg('IF', '014025000', '+0000', '0', '0', '3'));
      CheckEquals(r.ModeToString(rmCW), r.ModeToString(r.vfo[nrVFOA].mode));
   finally
      r.Free;
   end;
end;

procedure TYaesuASCIITests.Test_OI_GoesToVFOB;
var
   r: TFT991Probe;
begin
   // These radios cannot report both VFOs from one IF; -- VFO B needs OI;.
   // A driver that routed OI; to VFO A would still look healthy on the radio
   // window, so this is worth pinning.
   BeginTest('OI; writes VFO B and leaves VFO A alone');
   r := TFT991Probe.Create;
   try
      r.ProcessMessage(IFMsg('IF', '014025000', '+0000', '0', '0', '3'));
      r.ProcessMessage(IFMsg('OI', '007010000', '+0000', '0', '0', '2'));
      CheckEquals(7010000,  r.vfo[nrVFOB].frequency);
      CheckEquals(14025000, r.vfo[nrVFOA].frequency);
      CheckEquals(r.ModeToString(rmUSB), r.ModeToString(r.vfo[nrVFOB].mode));
   finally
      r.Free;
   end;
end;

procedure TYaesuASCIITests.Test_IF_RITOn;
var
   r: TFT991Probe;
begin
   BeginTest('IF; position 20 turns RIT on');
   r := TFT991Probe.Create;
   try
      r.ProcessMessage(IFMsg('IF', '014025000', '+0000', '1', '0', '3'));
      CheckTrue(r.IsRITOn[nrVFOA]);
   finally
      r.Free;
   end;
end;

procedure TYaesuASCIITests.Test_IF_XITOn;
var
   r: TFT991Probe;
begin
   BeginTest('IF; position 21 turns XIT on');
   r := TFT991Probe.Create;
   try
      r.ProcessMessage(IFMsg('IF', '014025000', '+0000', '0', '1', '3'));
      CheckTrue(r.IsXITOn[nrVFOA]);
   finally
      r.Free;
   end;
end;

procedure TYaesuASCIITests.Test_IF_ClarifierPositive;
var
   r: TFT991Probe;
begin
   BeginTest('IF; clarifier +0250 = +250 Hz');
   r := TFT991Probe.Create;
   try
      r.ProcessMessage(IFMsg('IF', '014025000', '+0250', '1', '0', '3'));
      CheckEquals(250, r.vfo[nrVFOA].RITOffset);
   finally
      r.Free;
   end;
end;

procedure TYaesuASCIITests.Test_IF_ClarifierNegative;
var
   r: TFT991Probe;
begin
   // The sign is its own character ahead of the magnitude; a driver that parsed
   // all 5 characters as one integer would read -0250 as 250.
   BeginTest('IF; clarifier -0250 = -250 Hz');
   r := TFT991Probe.Create;
   try
      r.ProcessMessage(IFMsg('IF', '014025000', '-0250', '1', '0', '3'));
      CheckEquals(-250, r.vfo[nrVFOA].RITOffset);
   finally
      r.Free;
   end;
end;

// ---------------------------------------------------------------------------
// The mode character where the two families disagree.  This is the entire
// reason uRadioYaesuFT991 exists as a separate class.
// ---------------------------------------------------------------------------

procedure TYaesuASCIITests.Test_FT991_E_IsC4FM_NotPSK;
var
   r: TFT991Probe;
begin
   // FT-991 is a System Fusion radio: 'E' is C4FM, reported as FM (matching the
   // legacy Type3 map).  If this ever returns rmPSK, the FT-991 has been wired to
   // the FTDX-10 map and an FM QSO will be logged as PSK31.
   BeginTest('FT-991: mode char E = C4FM -> rmFM');
   r := TFT991Probe.Create;
   try
      r.ProcessMessage(IFMsg('IF', '014025000', '+0000', '0', '0', 'E'));
      CheckEquals(r.ModeToString(rmFM), r.ModeToString(r.vfo[nrVFOA].mode));
   finally
      r.Free;
   end;
end;

procedure TYaesuASCIITests.Test_FTDX10_E_IsPSK;
var
   d: TFTDX10Probe;
begin
   BeginTest('FTDX-10: the same char E = PSK31 -> rmPSK');
   d := TFTDX10Probe.Create;
   try
      d.ProcessMessage(IFMsg('IF', '014025000', '+0000', '0', '0', 'E'));
      CheckEquals(d.ModeToString(rmPSK), d.ModeToString(d.vfo[nrVFOA].mode));
   finally
      d.Free;
   end;
end;

procedure TYaesuASCIITests.Test_ModeMap_SharedCharsAgree;
var
   r: TFT991Probe;
   d: TFTDX10Probe;
   i: integer;
   chars: string;
begin
   // Only 'E' may differ.  The FT-991 class overrides that one character and
   // defers the rest upward; this fails if someone copies the whole table into
   // the subclass and the two copies drift.
   BeginTest('every mode char except E agrees between the two families');
   chars := '123456789ABCD';   // every mapped char except 'E'
   r := TFT991Probe.Create;
   d := TFTDX10Probe.Create;
   try
      for i := 1 to Length(chars) do
         begin
         r.ProcessMessage(IFMsg('IF', '014025000', '+0000', '0', '0', chars[i]));
         d.ProcessMessage(IFMsg('IF', '014025000', '+0000', '0', '0', chars[i]));
         CheckEquals(d.ModeToString(d.vfo[nrVFOA].mode),
                     r.ModeToString(r.vfo[nrVFOA].mode),
                     Format('mode char "%s" differs between FT-991 and FTDX-10',
                            [chars[i]]));
         end;
   finally
      d.Free;
      r.Free;
   end;
end;

procedure TYaesuASCIITests.Test_FTDX10_B_IsFMNarrow;
var
   d: TFTDX10Probe;
begin
   // 'B' (FM-N) and 'F' (DATA-FM) were missing from the first port of this map
   // and produced "unmapped mode char" with no mode at all on a real FM-N QSO.
   BeginTest('FTDX-10: mode chars B = FM-N and F = DATA-FM (was a port gap)');
   d := TFTDX10Probe.Create;
   try
      d.ProcessMessage(IFMsg('IF', '014025000', '+0000', '0', '0', 'B'));
      CheckEquals(d.ModeToString(rmFM), d.ModeToString(d.vfo[nrVFOA].mode));
      d.ProcessMessage(IFMsg('IF', '014025000', '+0000', '0', '0', 'F'));
      CheckEquals(d.ModeToString(rmData), d.ModeToString(d.vfo[nrVFOA].mode));
   finally
      d.Free;
   end;
end;

// ---------------------------------------------------------------------------
// Read path -- split and TX
// ---------------------------------------------------------------------------

procedure TYaesuASCIITests.Test_FT_NonZeroMeansSplit;
var
   r: TFT991Probe;
begin
   BeginTest('FT; with a non-zero TX VFO means split');
   r := TFT991Probe.Create;
   try
      r.ProcessMessage('FT1');
      CheckTrue(r.IsSplitEnabled);
   finally
      r.Free;
   end;
end;

procedure TYaesuASCIITests.Test_FT_ZeroMeansNoSplit;
var
   r: TFT991Probe;
begin
   BeginTest('FT0 clears split');
   r := TFT991Probe.Create;
   try
      r.ProcessMessage('FT1');
      r.ProcessMessage('FT0');
      CheckFalse(r.IsSplitEnabled);
   finally
      r.Free;
   end;
end;

procedure TYaesuASCIITests.Test_TX_Transmitting;
var
   r: TFT991Probe;
begin
   BeginTest('TX1 puts the radio in transmit');
   r := TFT991Probe.Create;
   try
      r.ProcessMessage('TX1');
      CheckTrue(r.IsTransmitting);
   finally
      r.Free;
   end;
end;

procedure TYaesuASCIITests.Test_TX_Receiving;
var
   r: TFT991Probe;
begin
   BeginTest('TX0 returns the radio to receive');
   r := TFT991Probe.Create;
   try
      r.ProcessMessage('TX1');
      r.ProcessMessage('TX0');
      CheckFalse(r.IsTransmitting);
   finally
      r.Free;
   end;
end;

// ---------------------------------------------------------------------------
// Robustness -- a truncated or corrupt frame must not corrupt known state
// ---------------------------------------------------------------------------

procedure TYaesuASCIITests.Test_ShortMessageIgnored;
var
   r: TFT991Probe;
begin
   // Real ports deliver partial frames after a power cycle or a baud mismatch.
   BeginTest('a truncated IF leaves the last good frequency intact');
   r := TFT991Probe.Create;
   try
      r.ProcessMessage(IFMsg('IF', '014025000', '+0000', '0', '0', '3'));
      r.ProcessMessage('IF00014');
      CheckEquals(14025000, r.vfo[nrVFOA].frequency);
   finally
      r.Free;
   end;
end;

procedure TYaesuASCIITests.Test_NonNumericFrequencyIgnored;
var
   r: TFT991Probe;
begin
   BeginTest('a non-numeric frequency field leaves the last good value intact');
   r := TFT991Probe.Create;
   try
      r.ProcessMessage(IFMsg('IF', '014025000', '+0000', '0', '0', '3'));
      r.ProcessMessage(IFMsg('IF', 'XXXXXXXXX', '+0000', '0', '0', '3'));
      CheckEquals(14025000, r.vfo[nrVFOA].frequency);
   finally
      r.Free;
   end;
end;

// ---------------------------------------------------------------------------
// Per-model deviations
//
// Each of these is a place where one model in the family does something the
// others do not.  They are the reason each model has its own unit, and they are
// the assertions most likely to catch a bad refactor of the shared base.
// ---------------------------------------------------------------------------

procedure TYaesuASCIITests.Test_FT710_Split_Uses_FT1_FT0;
var
   r: TFT710Probe;
begin
   // The FT-710 takes the OLDER two-value form.  FT3; would be ignored by the
   // radio and split would silently never engage.
   BeginTest('FT-710 splits with FT1;/FT0;, not FT3;/FT2;');
   r := TFT710Probe.Create;
   try
      r.sent := '';
      r.Split(True);
      r.Split(False);
      CheckEquals('FT1;FT0;', r.sent);
   finally
      r.Free;
   end;
end;

procedure TYaesuASCIITests.Test_FT891_Split_Uses_ST;
var
   r: TFT891Probe;
begin
   // The FT-891 has no FT command at all.
   BeginTest('FT-891 splits with ST1;/ST0;');
   r := TFT891Probe.Create;
   try
      r.sent := '';
      r.Split(True);
      r.Split(False);
      CheckEquals('ST1;ST0;', r.sent);
   finally
      r.Free;
   end;
end;

procedure TYaesuASCIITests.Test_FT891_Polls_ST_Not_FT;
var
   r: TFT891Probe;
begin
   // Asking FT; would get no answer, so split would never update -- and nothing
   // else would look wrong, which is what makes it worth pinning.
   BeginTest('FT-891 poll cycle asks ST; where the family asks FT;');
   r := TFT891Probe.Create;
   try
      r.sent := '';
      r.PollRadioState;
      CheckEquals('IF;OI;ST;TX;', r.sent);
   finally
      r.Free;
   end;
end;

procedure TYaesuASCIITests.Test_FT891_Parses_ST_Response;
var
   r: TFT891Probe;
begin
   BeginTest('FT-891 reads split from the ST; reply');
   r := TFT891Probe.Create;
   try
      r.ProcessMessage('ST1');
      CheckTrue(r.IsSplitEnabled);
      r.ProcessMessage('ST0');
      CheckFalse(r.IsSplitEnabled);
   finally
      r.Free;
   end;
end;

procedure TYaesuASCIITests.Test_FT891_StillHandlesSharedCommands;
var
   r: TFT891Probe;
begin
   // Its ProcessMessage override must DELEGATE, not replace.  If someone
   // copy-pasted the base dispatcher instead of calling inherited, IF; would
   // keep working here but stop tracking any later fix to the shared version --
   // so assert the shared path still runs through the override.
   BeginTest('FT-891 still parses IF; through the inherited dispatcher');
   r := TFT891Probe.Create;
   try
      r.ProcessMessage(IFMsg('IF', '007025000', '+0000', '0', '0', '3'));
      CheckEquals(7025000, r.vfo[nrVFOA].frequency);
      CheckEquals(r.ModeToString(rmCW), r.ModeToString(r.vfo[nrVFOA].mode));
   finally
      r.Free;
   end;
end;

// FTX-1F fixture: 29-char body (30 on the wire).  Every field sits two
// characters later than on the FTDX-10.
function FTX1FMsg(const head, freq, clar, rit, xit, mode: string): string;
begin
   Result := head + '00000' + freq + clar + rit + xit + mode + '00000';
   if Length(Result) <> 29 then
      begin
      raise Exception.CreateFmt(
         'FTX-1F fixture is %d chars, must be 29', [Length(Result)]);
      end;
end;

procedure TYaesuASCIITests.Test_FTX1F_Offsets_AreShiftedByTwo;
var
   r: TFTX1FProbe;
begin
   BeginTest('FTX-1F reads its own +2 field offsets');
   r := TFTX1FProbe.Create;
   try
      r.ProcessMessage(FTX1FMsg('IF', '014025000', '-0250', '1', '1', '3'));
      CheckEquals(14025000, r.vfo[nrVFOA].frequency);
      CheckEquals(-250, r.vfo[nrVFOA].RITOffset);
      CheckTrue(r.IsRITOn[nrVFOA]);
      CheckTrue(r.IsXITOn[nrVFOA]);
      CheckEquals(r.ModeToString(rmCW), r.ModeToString(r.vfo[nrVFOA].mode));
   finally
      r.Free;
   end;
end;

procedure TYaesuASCIITests.Test_FTX1F_FTDX10Layout_WouldMisparse;
var
   r: TFTX1FProbe;
   d: TFTDX10Probe;
   body: string;
begin
   // The two layouts must actually DISAGREE.  If a future edit quietly gave the
   // FTX-1F the FTDX-10 offsets, every other FTX-1F test above would still pass
   // as long as the fixture matched the driver -- both would just be wrong
   // together.  Feeding one radio's frame to the other proves they differ.
   BeginTest('an FTX-1F frame read with FTDX-10 offsets gives a DIFFERENT frequency');
   r := TFTX1FProbe.Create;
   d := TFTDX10Probe.Create;
   try
      body := FTX1FMsg('IF', '014025000', '+0000', '0', '0', '3');
      r.ProcessMessage(body);
      d.ProcessMessage(body);
      CheckEquals(14025000, r.vfo[nrVFOA].frequency);
      CheckFalse(d.vfo[nrVFOA].frequency = 14025000);
   finally
      d.Free;
      r.Free;
   end;
end;

procedure TYaesuASCIITests.Test_FTX1F_C4FM_Chars;
var
   r: TFTX1FProbe;
begin
   // This radio reports C4FM as 'H'/'I' -- NOT by reusing 'E' the way the
   // FT-991 does.
   BeginTest('FTX-1F maps H and I to C4FM (rmFM)');
   r := TFTX1FProbe.Create;
   try
      r.ProcessMessage(FTX1FMsg('IF', '014025000', '+0000', '0', '0', 'H'));
      CheckEquals(r.ModeToString(rmFM), r.ModeToString(r.vfo[nrVFOA].mode));
      r.ProcessMessage(FTX1FMsg('IF', '014025000', '+0000', '0', '0', 'I'));
      CheckEquals(r.ModeToString(rmFM), r.ModeToString(r.vfo[nrVFOA].mode));
   finally
      r.Free;
   end;
end;

procedure TYaesuASCIITests.Test_FTX1F_E_StaysPSK;
var
   r: TFTX1FProbe;
begin
   BeginTest('FTX-1F keeps E as PSK31 even though it has C4FM');
   r := TFTX1FProbe.Create;
   try
      r.ProcessMessage(FTX1FMsg('IF', '014025000', '+0000', '0', '0', 'E'));
      CheckEquals(r.ModeToString(rmPSK), r.ModeToString(r.vfo[nrVFOA].mode));
   finally
      r.Free;
   end;
end;

// ---------------------------------------------------------------------------
// Write path
// ---------------------------------------------------------------------------

procedure TYaesuASCIITests.Test_Split_On_Sends_FT3;
var
   r: TFT991Probe;
begin
   // FT3;/FT2; -- NOT the FT1;/FT0; used by other Yaesu generations.
   BeginTest('Split(True) sends FT3;');
   r := TFT991Probe.Create;
   try
      r.sent := '';
      r.Split(True);
      CheckEquals('FT3;', r.sent);
   finally
      r.Free;
   end;
end;

procedure TYaesuASCIITests.Test_Split_Off_Sends_FT2;
var
   r: TFT991Probe;
begin
   BeginTest('Split(False) sends FT2;');
   r := TFT991Probe.Create;
   try
      r.sent := '';
      r.Split(False);
      CheckEquals('FT2;', r.sent);
   finally
      r.Free;
   end;
end;

procedure TYaesuASCIITests.Test_SetFrequency_VFOA_9Digits;
var
   r: TFT991Probe;
begin
   // 9 digits, not 8 (ny4i Issue #218).
   BeginTest('SetFrequency VFO A sends FA + 9 digits');
   r := TFT991Probe.Create;
   try
      r.sent := '';
      r.SetFrequency(14025000, nrVFOA, rmNone);
      CheckEquals('FA014025000;', r.sent);
   finally
      r.Free;
   end;
end;

procedure TYaesuASCIITests.Test_SetFrequency_VFOB;
var
   r: TFT991Probe;
begin
   BeginTest('SetFrequency VFO B sends FB + 9 digits');
   r := TFT991Probe.Create;
   try
      r.sent := '';
      r.SetFrequency(7010000, nrVFOB, rmNone);
      CheckEquals('FB007010000;', r.sent);
   finally
      r.Free;
   end;
end;

procedure TYaesuASCIITests.Test_SetMode_Uses_MD0n;
var
   r: TFT991Probe;
begin
   // MD0n; -- the extra '0' byte is what separates this from Kenwood's MDn;.
   BeginTest('SetMode sends the 5-char MD0n; form');
   r := TFT991Probe.Create;
   try
      r.sent := '';
      r.SetMode(rmCW, nrVFOA);
      CheckEquals('MD03;', r.sent);
   finally
      r.Free;
   end;
end;

procedure TYaesuASCIITests.Test_PollCycle;
var
   r: TFT991Probe;
begin
   BeginTest('PollRadioState queries both VFOs, split and TX');
   r := TFT991Probe.Create;
   try
      r.sent := '';
      r.PollRadioState;
      CheckEquals('IF;OI;FT;TX;', r.sent);
   finally
      r.Free;
   end;
end;

// ---------------------------------------------------------------------------

procedure TYaesuASCIITests.RunAllTests;
begin
   // IF;/OI; parsing
   Test_IF_Frequency;
   Test_IF_Band;
   Test_IF_ModeCW;
   Test_OI_GoesToVFOB;
   Test_IF_RITOn;
   Test_IF_XITOn;
   Test_IF_ClarifierPositive;
   Test_IF_ClarifierNegative;

   // The family-defining mode character
   Test_FT991_E_IsC4FM_NotPSK;
   Test_FTDX10_E_IsPSK;
   Test_ModeMap_SharedCharsAgree;
   Test_FTDX10_B_IsFMNarrow;

   // Split and TX
   Test_FT_NonZeroMeansSplit;
   Test_FT_ZeroMeansNoSplit;
   Test_TX_Transmitting;
   Test_TX_Receiving;

   // Robustness
   Test_ShortMessageIgnored;
   Test_NonNumericFrequencyIgnored;

   // Per-model deviations
   Test_FT710_Split_Uses_FT1_FT0;
   Test_FT891_Split_Uses_ST;
   Test_FT891_Polls_ST_Not_FT;
   Test_FT891_Parses_ST_Response;
   Test_FT891_StillHandlesSharedCommands;
   Test_FTX1F_Offsets_AreShiftedByTwo;
   Test_FTX1F_FTDX10Layout_WouldMisparse;
   Test_FTX1F_C4FM_Chars;
   Test_FTX1F_E_StaysPSK;

   // Write path
   Test_Split_On_Sends_FT3;
   Test_Split_Off_Sends_FT2;
   Test_SetFrequency_VFOA_9Digits;
   Test_SetFrequency_VFOB;
   Test_SetMode_Uses_MD0n;
   Test_PollCycle;
end;

end.
