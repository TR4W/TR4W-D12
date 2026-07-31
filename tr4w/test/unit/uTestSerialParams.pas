unit uTestSerialParams;

{
  Pins every radio's SERIAL DEFAULTS against the legacy they were derived from.

  The values in the 91 RegisterRadio calls were not typed by hand -- they were
  generated from LOGRADIO's own two sources:

    baud       RadioParametersArray[<model>].br
    stop bits  the typeset at LOGRADIO.PAS:1571 --
                 1 for [IC78..IC9700, FT100, ORION], 2 for everything else
    data/parity  8 / none, which LOGRADIO never varied

  A transcription error across 91 sites would be invisible: a radio with the
  wrong baud simply fails to talk, on someone else's bench, months later. So the
  test re-derives the expectation and compares.

  ONE DELIBERATE DIVERGENCE. The Ten-Tec Omni VI is CI-V but sits one slot past
  IC9700 in the enum, so the typeset's "the Icoms" range does not cover it and it
  never got named in the exception list beside FT100/ORION. It therefore shipped
  with 2 stop bits. Its manual (Ten-Tec Model 563, section 5.2) says:

      "the personal computer must first be set-up properly ... NO parity,
       8 data bits and 1 stop bit"

  Manufacturer manual outranks the shipping code, so the registry says 1 and this
  test asserts the DIVERGENCE explicitly rather than letting it look like drift.

  No transport, no radio: this reads registry data only.
}

interface

uses
   SysUtils, uTR4WTestFramework, uRadioRegistry, VC;

type
   TSerialParamsTests = class(TTestCase)
   protected
      procedure Test_StopBitsMatchTheLegacyRule;
      procedure Test_OmniVIDivergesPerItsManual;
      procedure Test_EveryRadioStatesEightDataBitsAndNoParity;
      procedure Test_BaudIsAlwaysAValidRate;
      procedure Test_SerialFormatRoundTrip;
      procedure Test_SerialFormatRejectsGarbage;
   public
      procedure RunAllTests; override;
   end;

implementation

// The legacy rule, restated: 1 stop bit for the Icoms plus the two named
// exceptions. OMNI6 is NOT here -- see the header.
function LegacyWantsOneStopBit(m: InterfacedRadioType): Boolean;
begin
   Result := ((m >= IC78) and (m <= IC9700)) or (m = FT100) or (m = ORION);
end;

procedure TSerialParamsTests.Test_StopBitsMatchTheLegacyRule;
var
   m: InterfacedRadioType;
   sp: TSerialParams;
   expected: Byte;
   bad: string;
begin
   BeginTest('stop bits match the legacy IC78..IC9700 / FT100 / ORION rule');
   bad := '';
   for m := Low(InterfacedRadioType) to High(InterfacedRadioType) do
      begin
      if not uRadioRegistry.IsRegistered(m) then
         begin
         Continue;
         end;
      if m = OMNI6 then
         begin
         Continue;   // asserted separately, with its manual as the reason
         end;
      if (m = K2) or (m = K3) or (m = KX3) or (m = K4) then
         begin
         Continue;   // asserted separately -- Elecraft is 8N1
         end;
      sp := uRadioRegistry.SerialParamsFor(m);
      if LegacyWantsOneStopBit(m) then
         begin
         expected := 1;
         end
      else
         begin
         expected := 2;
         end;
      if sp.stopBits <> expected then
         begin
         bad := bad + Format('%s(got %d want %d) ',
                             [uRadioRegistry.DisplayName(m), sp.stopBits, expected]);
         end;
      end;
   CheckEquals('', bad, 'stop bits diverge from the legacy rule: ' + bad);
end;

procedure TSerialParamsTests.Test_OmniVIDivergesPerItsManual;
var
   sp: TSerialParams;
begin
   // Asserted, not merely allowed: this is the one place the registry knowingly
   // contradicts the shipping legacy, and the reason must not quietly evaporate.
   BeginTest('Omni VI declares 1 stop bit, diverging from the legacy 2');
   sp := uRadioRegistry.SerialParamsFor(OMNI6);
   CheckEquals(1, sp.stopBits,
               'Ten-Tec Model 563 manual 5.2: NO parity, 8 data bits and 1 stop bit');
   CheckFalse(LegacyWantsOneStopBit(OMNI6),
              'the legacy rule really does NOT cover OMNI6 -- that is the point of this test');

   // Same shape of knowing divergence, second instance: Elecraft serial is 8N1
   // (NY4I 2026-07-30; Elecraft docs; HamLib elecraft backends).  The legacy 2
   // came from the blanket "everything non-CI-V gets 2 stop bits" rule.
   BeginTest('Elecraft K2/K3/KX3/K4 declare 1 stop bit, diverging from the legacy 2');
   CheckEquals(1, uRadioRegistry.SerialParamsFor(K2).stopBits, 'K2 is 8N1');
   CheckEquals(1, uRadioRegistry.SerialParamsFor(K3).stopBits, 'K3 is 8N1');
   CheckEquals(1, uRadioRegistry.SerialParamsFor(KX3).stopBits, 'KX3 is 8N1');
   CheckEquals(1, uRadioRegistry.SerialParamsFor(K4).stopBits, 'K4 is 8N1');
end;

procedure TSerialParamsTests.Test_EveryRadioStatesEightDataBitsAndNoParity;
var
   m: InterfacedRadioType;
   sp: TSerialParams;
   bad: string;
begin
   // LOGRADIO never varied these; if a future radio needs to, this test is the
   // prompt to confirm it against a manual rather than let it slip through.
   BeginTest('every radio states 8 data bits and no parity');
   bad := '';
   for m := Low(InterfacedRadioType) to High(InterfacedRadioType) do
      begin
      if not uRadioRegistry.IsRegistered(m) then
         begin
         Continue;
         end;
      sp := uRadioRegistry.SerialParamsFor(m);
      if (sp.dataBits <> 8) or (sp.parity <> PARITY_NONE) then
         begin
         bad := bad + uRadioRegistry.DisplayName(m) + ' ';
         end;
      end;
   CheckEquals('', bad, 'radios with unexpected data bits / parity: ' + bad);
end;

procedure TSerialParamsTests.Test_BaudIsAlwaysAValidRate;
var
   m: InterfacedRadioType;
   sp: TSerialParams;
   bad: string;
   ok: Boolean;
   checked: Integer;
begin
   // A typo'd baud (48000 for 4800) would be silent until someone tried the
   // radio. Constrain it to the rates the dialog can actually offer.
   BeginTest('every registered radio declares a selectable baud rate');
   bad := '';
   checked := 0;
   for m := Low(InterfacedRadioType) to High(InterfacedRadioType) do
      begin
      if not uRadioRegistry.IsRegistered(m) then
         begin
         Continue;
         end;
      Inc(checked);
      sp := uRadioRegistry.SerialParamsFor(m);
      ok := (sp.baud = 1200) or (sp.baud = 2400) or (sp.baud = 4800) or
            (sp.baud = 9600) or (sp.baud = 19200) or (sp.baud = 38400) or
            (sp.baud = 57600) or (sp.baud = 115200);
      if not ok then
         begin
         bad := bad + Format('%s(%d) ', [uRadioRegistry.DisplayName(m), sp.baud]);
         end;
      end;
   // Guard against the loop checking nothing if registration ever breaks.
   CheckTrue(checked > 80, Format('expected 90-odd registered radios, saw %d', [checked]));
   CheckEquals('', bad, 'radios with an unselectable baud rate: ' + bad);
end;

// Every one of the 12 frames the dialog offers must survive
// string -> fields -> string unchanged, and lower case must parse (the config
// file is hand-editable).
procedure TSerialParamsTests.Test_SerialFormatRoundTrip;
const
   Frames: array[0..11] of string =
      ('8N1', '8N2', '8E1', '8E2', '8O1', '8O2',
       '7N1', '7N2', '7E1', '7E2', '7O1', '7O2');
var
   i: integer;
   db, par, sb: Byte;
   bad: string;
begin
   BeginTest('every dialog frame string round-trips through parse/format');
   bad := '';
   for i := Low(Frames) to High(Frames) do
      begin
      if not TryParseSerialFormat(Frames[i], db, par, sb) then
         begin
         bad := bad + Frames[i] + ' (no parse); ';
         Continue;
         end;
      if SerialFormatToString(db, par, sb) <> Frames[i] then
         begin
         bad := bad + Format('%s -> %s; ', [Frames[i], SerialFormatToString(db, par, sb)]);
         end;
      // Lower case parses to the same fields.
      if not TryParseSerialFormat(LowerCase(Frames[i]), db, par, sb) then
         begin
         bad := bad + LowerCase(Frames[i]) + ' (lowercase no parse); ';
         end;
      end;
   CheckEquals('', bad, bad);
end;

procedure TSerialParamsTests.Test_SerialFormatRejectsGarbage;
const
   Garbage: array[0..6] of string =
      ('', '8N', '8N21', '9N1', '8X1', '8N3', '6E1');
var
   i: integer;
   db, par, sb: Byte;
   bad: string;
begin
   // An invalid 'RADIO n SERIAL FORMAT' must FAIL to parse, so the connect
   // path falls back to the radio's registered defaults instead of opening the
   // port with a half-parsed frame.
   BeginTest('invalid serial format strings are rejected');
   bad := '';
   for i := Low(Garbage) to High(Garbage) do
      begin
      if TryParseSerialFormat(Garbage[i], db, par, sb) then
         begin
         bad := bad + '''' + Garbage[i] + ''' accepted; ';
         end;
      end;
   CheckEquals('', bad, bad);
end;

procedure TSerialParamsTests.RunAllTests;
begin
   Test_StopBitsMatchTheLegacyRule;
   Test_OmniVIDivergesPerItsManual;
   Test_EveryRadioStatesEightDataBitsAndNoParity;
   Test_BaudIsAlwaysAValidRate;
   Test_SerialFormatRoundTrip;
   Test_SerialFormatRejectsGarbage;
end;

end.
