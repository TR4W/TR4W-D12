unit uTestRadioConfigLegacyMap;

{
  Pins uRadioConfigLegacyMap -- the renderer that turns a radio definition into
  the legacy [Radio] ini keys.

  THE POINT OF THE PIN TEST.  If activating a definition writes only SOME of the
  keys, the rest are left over from whichever radio was configured before, and
  the operator ends up with (say) an IC-7100 running on a K3's CI-V address or a
  stale keyer port.  Nothing errors.  The radio simply misbehaves in a way that
  looks like a radio fault rather than a configuration fault.

  So Test_RenderedKeySetMatchesCFGCA compares the emitted key set against a
  GOLDEN LIST typed out from uCFG's CFGCA table.  The golden list is
  deliberately hand-written here rather than derived from the same constants the
  renderer uses -- a test that reads its expectation from the code under test
  proves only that the code equals itself.  When a new RADIO ONE key is added to
  CFGCA, this test is what says "and the new configuration path does not write
  it yet".

  The three spellings that break the pattern (KEYER RADIO ONE OUTPUT PORT, POLL
  RADIO ONE, and TYPE/FACTORY ID being mutually exclusive) each get their own
  test, because each is a place where a plausible guess produces a key CFGCA
  silently ignores.
}

interface

uses
   SysUtils, Classes,
   uTR4WTestFramework, uRadioConfigStore, uRadioConfigLegacyMap;

type
   TRadioConfigLegacyMapTests = class(TTestCase)
   private
      function MakeSerialRadio: TRadioDefinition;
      function MakeNetworkRadio: TRadioDefinition;
      // Value for a key, or a sentinel that cannot be mistaken for one.
      function ValueOf(const aRendered: TConfigKeyValues; const aKey: string): string;
      function IsDeleted(const aRendered: TConfigKeyValues; const aKey: string): boolean;
      function HasKey(const aRendered: TConfigKeyValues; const aKey: string): boolean;
   protected
      procedure Test_RenderedKeySetMatchesCFGCA;
      procedure Test_EmittedKeysMatchRenderedKeyNames;
      procedure Test_NoKeyIsEmittedTwice;
      procedure Test_SlotTwoUsesTheOtherSpelling;
      procedure Test_FactoryRadioWritesTypeNoneAndFactoryId;
      procedure Test_EnumRadioWritesTypeAndDeletesFactoryId;
      procedure Test_SerialRadioBlanksTheNetworkKeys;
      procedure Test_NetworkRadioBlanksTheSerialKeys;
      procedure Test_UnsetIntegersRenderEmptyNotZero;
      procedure Test_BooleansUseTheCFGCAVocabulary;
      procedure Test_ProfileCWOutputCATOverridesTheRadio;
      procedure Test_ProfileCWOutputPortOverridesTheRadio;
      procedure Test_ProfileCWOutputNoneTurnsBothOff;
      procedure Test_NoProfileFallsBackToTheRadiosOwnCWFields;
      procedure Test_HamLibIdOnlyForHamLibAny;
      procedure Test_EmptySlotClearsEverything;
      procedure Test_NilRadioRendersAnEmptySlot;
   public
      procedure RunAllTests; override;
   end;

implementation

const
   // NOT DERIVED FROM THE CODE UNDER TEST.  Typed out from the RADIO ONE rows
   // of CFGCA in uCFG.pas -- every row that is still live.  The rows marked
   // csRem there are retired and drive nothing, so they are absent on purpose:
   //   RADIO ONE COMMAND PAUSE, RADIO ONE ID CHARACTER,
   //   RADIO ONE TRACKING ENABLE, RADIO ONE UPDATE SECONDS
   // The ICOM NETWORK USERNAME/PASSWORD rows are absent too: issue #904 made
   // them backward-compatible ALIASES that CFGCA still parses from old files,
   // and uCAT actively DELETES them when it saves.  Writing them would be
   // writing a key the legacy code is trying to retire.
   GOLDENKEYS: array[0..28] of string = (
      'RADIO ONE TYPE',
      'RADIO ONE FACTORY ID',
      'RADIO ONE NAME',
      'RADIO ONE CONTROL PORT',
      'RADIO ONE BAUD RATE',
      'RADIO ONE SERIAL FORMAT',
      'RADIO ONE CAT RTS',
      'RADIO ONE CAT DTR',
      'RADIO ONE IP ADDRESS',
      'RADIO ONE TCP PORT',
      'RADIO ONE NETWORK USERNAME',
      'RADIO ONE NETWORK PASSWORD',
      'KEYER RADIO ONE OUTPUT PORT',
      'RADIO ONE KEYER RTS',
      'RADIO ONE KEYER DTR',
      'RADIO ONE KEYER STOP BITS',
      'RADIO ONE CW BY CAT',
      'RADIO ONE CW SPEED SYNC',
      'RADIO ONE USE HAMLIB',
      'RADIO ONE HAMLIB ID',
      'RADIO ONE RECEIVER ADDRESS',
      'RADIO ONE ICOM DATA MODE ID',
      'RADIO ONE ICOM FILTER BYTE',
      'RADIO ONE WIDE CW FILTER',
      'RADIO ONE FT1000MP CW REVERSE',
      'RADIO ONE FREQUENCY ADDER',
      'RADIO ONE BAND OUTPUT PORT',
      'RADIO ONE STARTUP COMMAND',
      'POLL RADIO ONE'
   );

   NOSUCHKEY = '<<absent>>';

{ ------------------------------------------------------------- helpers ---- }

function TRadioConfigLegacyMapTests.ValueOf(const aRendered: TConfigKeyValues;
                                            const aKey: string): string;
var
   i: integer;
begin
   for i := 0 to High(aRendered) do
      begin
      if SameText(aRendered[i].Key, aKey) then
         begin
         Result := aRendered[i].Value;
         Exit;
         end;
      end;
   // A sentinel rather than '': an ABSENT key and a key written as empty are
   // very different things here, and a test must not confuse them.
   Result := NOSUCHKEY;
end;

function TRadioConfigLegacyMapTests.IsDeleted(const aRendered: TConfigKeyValues;
                                              const aKey: string): boolean;
var
   i: integer;
begin
   Result := False;
   for i := 0 to High(aRendered) do
      begin
      if SameText(aRendered[i].Key, aKey) then
         begin
         Result := aRendered[i].Delete;
         Exit;
         end;
      end;
end;

function TRadioConfigLegacyMapTests.HasKey(const aRendered: TConfigKeyValues;
                                           const aKey: string): boolean;
begin
   Result := ValueOf(aRendered, aKey) <> NOSUCHKEY;
end;

function TRadioConfigLegacyMapTests.MakeSerialRadio: TRadioDefinition;
begin
   Result := TRadioDefinition.Create;
   Result.Name            := 'Shack K3';
   Result.RegistryId      := 'K3';
   Result.Transport       := rtSerial;
   Result.ControlPort     := 'SERIAL 5';
   Result.BaudRate        := 38400;
   Result.SerialFormat    := '8N1';
   Result.CatRTS          := 'ALWAYS ON';
   Result.CatDTR          := 'ALWAYS OFF';
   Result.KeyerOutputPort := 'SERIAL 6';
   Result.KeyerRTS        := 'CW';
   Result.KeyerDTR        := 'PTT';
   Result.KeyerStopBits   := 2;
   Result.CWByCAT         := False;
   Result.CWSpeedSync     := False;
   Result.ReceiverAddress := 0;
   Result.PollingEnable   := True;
end;

function TRadioConfigLegacyMapTests.MakeNetworkRadio: TRadioDefinition;
begin
   Result := TRadioDefinition.Create;
   Result.Name            := 'K4 Remote';
   Result.RegistryId      := 'K4';
   Result.Transport       := rtNetwork;
   // Deliberately ALSO carries serial settings: an operator who switches a
   // definition from serial to network leaves these behind, and they must not
   // reach the ini.
   Result.ControlPort     := 'SERIAL 5';
   Result.BaudRate        := 38400;
   Result.SerialFormat    := '8N1';
   Result.CatRTS          := 'ALWAYS ON';
   Result.IPAddress       := '192.168.73.108';
   Result.TCPPort         := 9200;
   Result.NetworkUsername := 'ny4i';
   Result.NetworkPassword := 'secret';
   Result.PollingEnable   := True;
end;

{ --------------------------------------------------------- the key set ---- }

procedure TRadioConfigLegacyMapTests.Test_RenderedKeySetMatchesCFGCA;
var
   names: TArray<string>;
   i, j: integer;
   found: boolean;
begin
   BeginTest('Test_RenderedKeySetMatchesCFGCA');
   names := RenderedKeyNames(1);

   CheckEquals(Length(GOLDENKEYS), Length(names),
               'the renderer emits exactly the live CFGCA RADIO ONE key set');

   // Every golden key is rendered.  A miss here means activating a definition
   // leaves that setting at whatever the PREVIOUS radio had.
   for i := 0 to High(GOLDENKEYS) do
      begin
      found := False;
      for j := 0 to High(names) do
         begin
         if SameText(names[j], GOLDENKEYS[i]) then
            begin
            found := True;
            Break;
            end;
         end;
      CheckTrue(found, 'CFGCA key is rendered: ' + GOLDENKEYS[i]);
      end;

   // And nothing extra: a key CFGCA does not know is a silent no-op that reads
   // like a working setting.
   for i := 0 to High(names) do
      begin
      found := False;
      for j := 0 to High(GOLDENKEYS) do
         begin
         if SameText(names[i], GOLDENKEYS[j]) then
            begin
            found := True;
            Break;
            end;
         end;
      CheckTrue(found, 'rendered key exists in CFGCA: ' + names[i]);
      end;
end;

procedure TRadioConfigLegacyMapTests.Test_EmittedKeysMatchRenderedKeyNames;
var
   radio: TRadioDefinition;
   rendered: TConfigKeyValues;
   names: TArray<string>;
   i: integer;
begin
   BeginTest('Test_EmittedKeysMatchRenderedKeyNames');
   // RenderRadioKeys emits explicitly rather than walking the key table, so
   // the two CAN drift.  This is the test that stops that.
   radio := MakeSerialRadio;
   try
      rendered := RenderRadioKeys(1, radio, Default(TRadioTypeRendering), nil);
      names    := RenderedKeyNames(1);

      CheckEquals(Length(names), Length(rendered), 'same number of keys');
      for i := 0 to High(names) do
         begin
         CheckTrue(HasKey(rendered, names[i]), 'emitted: ' + names[i]);
         end;
   finally
      radio.Free;
   end;
end;

procedure TRadioConfigLegacyMapTests.Test_NoKeyIsEmittedTwice;
var
   radio: TRadioDefinition;
   rendered: TConfigKeyValues;
   i, j: integer;
begin
   BeginTest('Test_NoKeyIsEmittedTwice');
   // Two instructions for one key means the second silently wins -- and which
   // is second is an accident of the code order.
   radio := MakeNetworkRadio;
   try
      rendered := RenderRadioKeys(1, radio, Default(TRadioTypeRendering), nil);
      for i := 0 to High(rendered) do
         begin
         for j := i + 1 to High(rendered) do
            begin
            CheckFalse(SameText(rendered[i].Key, rendered[j].Key),
                       'key emitted once: ' + rendered[i].Key);
            end;
         end;
   finally
      radio.Free;
   end;
end;

procedure TRadioConfigLegacyMapTests.Test_SlotTwoUsesTheOtherSpelling;
var
   radio: TRadioDefinition;
   rendered: TConfigKeyValues;
begin
   BeginTest('Test_SlotTwoUsesTheOtherSpelling');
   radio := MakeSerialRadio;
   try
      rendered := RenderRadioKeys(2, radio, Default(TRadioTypeRendering), nil);

      CheckTrue(HasKey(rendered, 'RADIO TWO TYPE'), 'RADIO TWO TYPE');
      // The two keys that do not follow the RADIO n <thing> pattern.  Getting
      // either wrong produces a key CFGCA ignores without complaint.
      CheckTrue(HasKey(rendered, 'KEYER RADIO TWO OUTPUT PORT'),
                'KEYER RADIO TWO OUTPUT PORT');
      CheckTrue(HasKey(rendered, 'POLL RADIO TWO'), 'POLL RADIO TWO');
      CheckFalse(HasKey(rendered, 'RADIO TWO KEYER OUTPUT PORT'),
                 'not the plausible-but-wrong spelling');
      CheckFalse(HasKey(rendered, 'RADIO ONE TYPE'), 'nothing from slot one leaks in');
   finally
      radio.Free;
   end;
end;

{ ---------------------------------------------------------- identity ------ }

procedure TRadioConfigLegacyMapTests.Test_FactoryRadioWritesTypeNoneAndFactoryId;
var
   radio: TRadioDefinition;
   rendered: TConfigKeyValues;
   typeRendering: TRadioTypeRendering;
begin
   BeginTest('Test_FactoryRadioWritesTypeNoneAndFactoryId');
   radio := MakeSerialRadio;
   try
      radio.RegistryId := 'IC7300MK2';
      typeRendering.IsFactoryRadio := True;
      typeRendering.LegacyTypeName := '';

      rendered := RenderRadioKeys(1, radio, typeRendering, nil);

      CheckEquals('NONE',      ValueOf(rendered, 'RADIO ONE TYPE'), 'TYPE=NONE');
      CheckEquals('IC7300MK2', ValueOf(rendered, 'RADIO ONE FACTORY ID'), 'FACTORY ID');
      CheckFalse(IsDeleted(rendered, 'RADIO ONE FACTORY ID'), 'and it is written, not deleted');
   finally
      radio.Free;
   end;
end;

procedure TRadioConfigLegacyMapTests.Test_EnumRadioWritesTypeAndDeletesFactoryId;
var
   radio: TRadioDefinition;
   rendered: TConfigKeyValues;
   typeRendering: TRadioTypeRendering;
begin
   BeginTest('Test_EnumRadioWritesTypeAndDeletesFactoryId');
   // The stale-FACTORY-ID trap: leave the key behind and the factory picks the
   // PREVIOUS radio up again, ignoring the enum TYPE that was just written.
   // Blanking is not enough -- the key has to go.
   radio := MakeSerialRadio;
   try
      typeRendering.IsFactoryRadio := False;
      typeRendering.LegacyTypeName := 'K3';

      rendered := RenderRadioKeys(1, radio, typeRendering, nil);

      CheckEquals('K3', ValueOf(rendered, 'RADIO ONE TYPE'), 'TYPE is the enum name');
      CheckTrue(IsDeleted(rendered, 'RADIO ONE FACTORY ID'),
                'FACTORY ID is DELETED, not blanked');
   finally
      radio.Free;
   end;
end;

{ ---------------------------------------------------------- transport ----- }

procedure TRadioConfigLegacyMapTests.Test_SerialRadioBlanksTheNetworkKeys;
var
   radio: TRadioDefinition;
   rendered: TConfigKeyValues;
begin
   BeginTest('Test_SerialRadioBlanksTheNetworkKeys');
   radio := MakeSerialRadio;
   try
      radio.IPAddress := '10.0.0.5';   // left over from an earlier edit
      rendered := RenderRadioKeys(1, radio, Default(TRadioTypeRendering), nil);

      CheckEquals('SERIAL 5', ValueOf(rendered, 'RADIO ONE CONTROL PORT'), 'port');
      CheckEquals('38400',    ValueOf(rendered, 'RADIO ONE BAUD RATE'),    'baud');
      CheckEquals('',         ValueOf(rendered, 'RADIO ONE IP ADDRESS'),
                  'the stale IP address is blanked, not carried over');
      CheckEquals('',         ValueOf(rendered, 'RADIO ONE TCP PORT'), 'TCP port blanked');
   finally
      radio.Free;
   end;
end;

procedure TRadioConfigLegacyMapTests.Test_NetworkRadioBlanksTheSerialKeys;
var
   radio: TRadioDefinition;
   rendered: TConfigKeyValues;
begin
   BeginTest('Test_NetworkRadioBlanksTheSerialKeys');
   // The dangerous direction: a leftover CONTROL PORT makes TR4W open a serial
   // port for a network radio -- and on an SO2R station that port belongs to
   // the OTHER radio.
   radio := MakeNetworkRadio;
   try
      rendered := RenderRadioKeys(1, radio, Default(TRadioTypeRendering), nil);

      CheckEquals(PORT_NONE, ValueOf(rendered, 'RADIO ONE CONTROL PORT'),
                  'the serial port is explicitly NONE');
      CheckEquals('',        ValueOf(rendered, 'RADIO ONE BAUD RATE'),     'baud blanked');
      CheckEquals('',        ValueOf(rendered, 'RADIO ONE SERIAL FORMAT'), 'format blanked');
      CheckEquals('',        ValueOf(rendered, 'RADIO ONE CAT RTS'),       'RTS blanked');

      CheckEquals('192.168.73.108', ValueOf(rendered, 'RADIO ONE IP ADDRESS'), 'IP');
      CheckEquals('9200',           ValueOf(rendered, 'RADIO ONE TCP PORT'),   'TCP port');
      CheckEquals('ny4i',           ValueOf(rendered, 'RADIO ONE NETWORK USERNAME'), 'user');
      CheckEquals('secret',         ValueOf(rendered, 'RADIO ONE NETWORK PASSWORD'), 'password');
   finally
      radio.Free;
   end;
end;

{ ------------------------------------------------------------- values ----- }

procedure TRadioConfigLegacyMapTests.Test_UnsetIntegersRenderEmptyNotZero;
var
   radio: TRadioDefinition;
   rendered: TConfigKeyValues;
begin
   BeginTest('Test_UnsetIntegersRenderEmptyNotZero');
   // A literal 0 is a real setting -- CI-V address zero, baud rate zero -- so
   // an unset field must render empty, which CFGCA treats as absent.
   radio := MakeSerialRadio;
   try
      radio.ReceiverAddress := 0;
      radio.FrequencyAdder  := 0;
      rendered := RenderRadioKeys(1, radio, Default(TRadioTypeRendering), nil);

      CheckEquals('', ValueOf(rendered, 'RADIO ONE RECEIVER ADDRESS'), 'address empty');
      CheckEquals('', ValueOf(rendered, 'RADIO ONE FREQUENCY ADDER'),  'adder empty');

      radio.ReceiverAddress := 136;
      rendered := RenderRadioKeys(1, radio, Default(TRadioTypeRendering), nil);
      CheckEquals('136', ValueOf(rendered, 'RADIO ONE RECEIVER ADDRESS'),
                  'a set address is written');
   finally
      radio.Free;
   end;
end;

procedure TRadioConfigLegacyMapTests.Test_BooleansUseTheCFGCAVocabulary;
var
   radio: TRadioDefinition;
   rendered: TConfigKeyValues;
begin
   BeginTest('Test_BooleansUseTheCFGCAVocabulary');
   // 'TRUE'/'FALSE', not Delphi's 'True'/'False' -- CFGCA would not parse the
   // latter, and the setting would silently stay at its previous value.
   radio := MakeSerialRadio;
   try
      radio.UseHamLib     := True;
      radio.WideCWFilter  := False;
      radio.PollingEnable := True;
      rendered := RenderRadioKeys(1, radio, Default(TRadioTypeRendering), nil);

      CheckEquals('TRUE',  ValueOf(rendered, 'RADIO ONE USE HAMLIB'),      'true spelling');
      CheckEquals('FALSE', ValueOf(rendered, 'RADIO ONE WIDE CW FILTER'),  'false spelling');
      CheckEquals('TRUE',  ValueOf(rendered, 'POLL RADIO ONE'),            'polling');
   finally
      radio.Free;
   end;
end;

{ ------------------------------------------------------------ CW output --- }

procedure TRadioConfigLegacyMapTests.Test_ProfileCWOutputCATOverridesTheRadio;
var
   radio: TRadioDefinition;
   prof: TStationProfile;
   rendered: TConfigKeyValues;
begin
   BeginTest('Test_ProfileCWOutputCATOverridesTheRadio');
   // How CW reaches a slot is a property of the STATION wiring, not the radio:
   // the same K3 keys by CAT at home and off a WinKeyer portable.
   radio := MakeSerialRadio;
   prof  := TStationProfile.Create;
   try
      radio.CWByCAT         := False;
      radio.KeyerOutputPort := 'SERIAL 6';

      prof.CWOutput1  := CWOUTPUT_CAT;
      prof.SpeedSync1 := True;

      rendered := RenderRadioKeys(1, radio, Default(TRadioTypeRendering), prof);

      CheckEquals('TRUE',    ValueOf(rendered, 'RADIO ONE CW BY CAT'), 'CW BY CAT on');
      CheckEquals(PORT_NONE, ValueOf(rendered, 'KEYER RADIO ONE OUTPUT PORT'),
                  'and the keyer port is released');
      CheckEquals('TRUE',    ValueOf(rendered, 'RADIO ONE CW SPEED SYNC'),
                  'speed sync comes from the profile too');
   finally
      prof.Free;
      radio.Free;
   end;
end;

procedure TRadioConfigLegacyMapTests.Test_ProfileCWOutputPortOverridesTheRadio;
var
   radio: TRadioDefinition;
   prof: TStationProfile;
   rendered: TConfigKeyValues;
begin
   BeginTest('Test_ProfileCWOutputPortOverridesTheRadio');
   radio := MakeSerialRadio;
   prof  := TStationProfile.Create;
   try
      radio.CWByCAT := True;   // the radio's own idea, overridden below

      prof.CWOutput2  := 'SERIAL 8';
      prof.SpeedSync2 := False;

      rendered := RenderRadioKeys(2, radio, Default(TRadioTypeRendering), prof);

      CheckEquals('FALSE',    ValueOf(rendered, 'RADIO TWO CW BY CAT'),
                  'a keyer port means CW BY CAT is off');
      CheckEquals('SERIAL 8', ValueOf(rendered, 'KEYER RADIO TWO OUTPUT PORT'), 'the port');
   finally
      prof.Free;
      radio.Free;
   end;
end;

procedure TRadioConfigLegacyMapTests.Test_ProfileCWOutputNoneTurnsBothOff;
var
   radio: TRadioDefinition;
   prof: TStationProfile;
   rendered: TConfigKeyValues;
begin
   BeginTest('Test_ProfileCWOutputNoneTurnsBothOff');
   radio := MakeSerialRadio;
   prof  := TStationProfile.Create;
   try
      radio.CWByCAT         := True;
      radio.KeyerOutputPort := 'SERIAL 6';
      prof.CWOutput1        := CWOUTPUT_NONE;

      rendered := RenderRadioKeys(1, radio, Default(TRadioTypeRendering), prof);

      CheckEquals('FALSE',   ValueOf(rendered, 'RADIO ONE CW BY CAT'), 'CAT off');
      CheckEquals(PORT_NONE, ValueOf(rendered, 'KEYER RADIO ONE OUTPUT PORT'), 'port off');
   finally
      prof.Free;
      radio.Free;
   end;
end;

procedure TRadioConfigLegacyMapTests.Test_NoProfileFallsBackToTheRadiosOwnCWFields;
var
   radio: TRadioDefinition;
   rendered: TConfigKeyValues;
begin
   BeginTest('Test_NoProfileFallsBackToTheRadiosOwnCWFields');
   // This is the seeded case: definitions built from the legacy ini carry the
   // CW settings the operator already had, with no profile expressing them.
   radio := MakeSerialRadio;
   try
      radio.CWByCAT         := True;
      radio.CWSpeedSync     := True;
      radio.KeyerOutputPort := 'SERIAL 6';

      rendered := RenderRadioKeys(1, radio, Default(TRadioTypeRendering), nil);

      CheckEquals('TRUE',     ValueOf(rendered, 'RADIO ONE CW BY CAT'), 'radio''s own CWByCAT');
      CheckEquals('TRUE',     ValueOf(rendered, 'RADIO ONE CW SPEED SYNC'), 'own speed sync');
      CheckEquals('SERIAL 6', ValueOf(rendered, 'KEYER RADIO ONE OUTPUT PORT'), 'own port');
   finally
      radio.Free;
   end;
end;

procedure TRadioConfigLegacyMapTests.Test_HamLibIdOnlyForHamLibAny;
var
   radio: TRadioDefinition;
   rendered: TConfigKeyValues;
begin
   BeginTest('Test_HamLibIdOnlyForHamLibAny');
   // The legacy dialog shows a greyed, informational HamLib number for every
   // radio and only saves it for the HamLib-any selection.  Same rule here:
   // writing the informational number back would pin a model id the operator
   // never chose.
   radio := MakeSerialRadio;
   try
      radio.HamLibID   := 2043;
      radio.RegistryId := 'K3';
      rendered := RenderRadioKeys(1, radio, Default(TRadioTypeRendering), nil);
      CheckEquals('', ValueOf(rendered, 'RADIO ONE HAMLIB ID'),
                  'not written for a specific model');

      radio.RegistryId := 'HAMLIBANY';
      rendered := RenderRadioKeys(1, radio, Default(TRadioTypeRendering), nil);
      CheckEquals('2043', ValueOf(rendered, 'RADIO ONE HAMLIB ID'),
                  'written for HamLib-any, where it IS the operator''s value');
   finally
      radio.Free;
   end;
end;

{ ------------------------------------------------------------ empty slot -- }

procedure TRadioConfigLegacyMapTests.Test_EmptySlotClearsEverything;
var
   rendered: TConfigKeyValues;
   names: TArray<string>;
   i: integer;
begin
   BeginTest('Test_EmptySlotClearsEverything');
   // A profile that fills only slot one must CLEAR slot two, or slot two keeps
   // whatever the previously active profile left there -- a radio the operator
   // did not ask for, on a port they may need for something else.
   rendered := RenderEmptySlot(2);
   names    := RenderedKeyNames(2);

   CheckEquals(Length(names), Length(rendered), 'the whole key set is cleared');
   for i := 0 to High(names) do
      begin
      CheckTrue(HasKey(rendered, names[i]), 'cleared: ' + names[i]);
      end;

   CheckEquals('NONE', ValueOf(rendered, 'RADIO TWO TYPE'),
               'TYPE=NONE is how the legacy config says "no radio"');
   CheckTrue(IsDeleted(rendered, 'RADIO TWO FACTORY ID'), 'FACTORY ID removed');
   CheckEquals(PORT_NONE, ValueOf(rendered, 'RADIO TWO CONTROL PORT'), 'port released');
   CheckEquals(PORT_NONE, ValueOf(rendered, 'KEYER RADIO TWO OUTPUT PORT'), 'keyer released');
   // Booleans go to FALSE, not empty: CFGCA reads an empty boolean as
   // unchanged, which would leave the previous radio's setting in force.
   CheckEquals('FALSE', ValueOf(rendered, 'RADIO TWO CW BY CAT'), 'CW BY CAT off');
   CheckEquals('FALSE', ValueOf(rendered, 'POLL RADIO TWO'), 'polling off');
end;

procedure TRadioConfigLegacyMapTests.Test_NilRadioRendersAnEmptySlot;
var
   rendered: TConfigKeyValues;
begin
   BeginTest('Test_NilRadioRendersAnEmptySlot');
   // The apply layer will hand this a nil for an empty slot; it must not need
   // to remember to call the other function.
   rendered := RenderRadioKeys(2, nil, Default(TRadioTypeRendering), nil);
   CheckEquals(Length(RenderedKeyNames(2)), Length(rendered), 'full clear');
   CheckEquals('NONE', ValueOf(rendered, 'RADIO TWO TYPE'), 'TYPE=NONE');
end;

{ ---------------------------------------------------------------- runner -- }

procedure TRadioConfigLegacyMapTests.RunAllTests;
begin
   Test_RenderedKeySetMatchesCFGCA;
   Test_EmittedKeysMatchRenderedKeyNames;
   Test_NoKeyIsEmittedTwice;
   Test_SlotTwoUsesTheOtherSpelling;

   Test_FactoryRadioWritesTypeNoneAndFactoryId;
   Test_EnumRadioWritesTypeAndDeletesFactoryId;

   Test_SerialRadioBlanksTheNetworkKeys;
   Test_NetworkRadioBlanksTheSerialKeys;

   Test_UnsetIntegersRenderEmptyNotZero;
   Test_BooleansUseTheCFGCAVocabulary;

   Test_ProfileCWOutputCATOverridesTheRadio;
   Test_ProfileCWOutputPortOverridesTheRadio;
   Test_ProfileCWOutputNoneTurnsBothOff;
   Test_NoProfileFallsBackToTheRadiosOwnCWFields;
   Test_HamLibIdOnlyForHamLibAny;

   Test_EmptySlotClearsEverything;
   Test_NilRadioRendersAnEmptySlot;
end;

end.
