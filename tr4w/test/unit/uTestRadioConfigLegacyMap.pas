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
   SysUtils, StrUtils, Classes,
   uTR4WTestFramework, uRadioConfigStore, uRadioConfigLegacyMap;

type
   TRadioConfigLegacyMapTests = class(TTestCase)
   private
      function MakeSerialRadio: TRadioDefinition;
      function MakeNetworkRadio: TRadioDefinition;
      // Value for a key, or a sentinel that cannot be mistaken for one.
      function ValueOf(const aRendered: TConfigKeyValues; const aKey: string): string;
      procedure Test_KeyerDeviceNameNeverReachesTheLegacyPortKey;
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
      procedure Test_NumericKeysAreNeverEmpty;
      procedure Test_UnsetNumericsFallBackToTheModelDefault;
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
   GOLDENKEYS: array[0..29] of string = (
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
      'RADIO ONE AUTO INFO',
      'RADIO ONE WIDE CW FILTER',
      'RADIO ONE FT1000MP CW REVERSE',
      'RADIO ONE FREQUENCY ADDER',
      'RADIO ONE BAND OUTPUT PORT',
      'RADIO ONE STARTUP COMMAND',
      'POLL RADIO ONE'
   );

   NOSUCHKEY = '<<absent>>';

   // Every key CFGCA reads as a NUMBER (ctByte / ctWord / ctInteger).  These
   // are the ones for which an empty value is not "unset" but "keep what you
   // had", so none of them may ever render blank.
   // Keys CFGCA parses against a fixed value list.  A blank one is not
   // "unset" -- it is an INVALID STATEMENT that aborts the config load.
   LISTKEYS: array[0..3] of string = (
      'RADIO ONE CAT RTS',
      'RADIO ONE CAT DTR',
      'RADIO ONE KEYER RTS',
      'RADIO ONE KEYER DTR'
   );

   NUMERICKEYS: array[0..8] of string = (
      'RADIO ONE BAUD RATE',
      'RADIO ONE TCP PORT',
      'RADIO ONE KEYER STOP BITS',
      'RADIO ONE HAMLIB ID',
      'RADIO ONE RECEIVER ADDRESS',
      'RADIO ONE ICOM DATA MODE ID',
      'RADIO ONE ICOM FILTER BYTE',
      'RADIO ONE AUTO INFO',
      'RADIO ONE FREQUENCY ADDER'
   );

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
      // The TCP port is a NUMBER, so it cannot be blanked -- an empty numeric
      // would keep the previous radio's port.  It is written as 0 instead,
      // which is inert for a serial radio.
      CheckEquals('0',        ValueOf(rendered, 'RADIO ONE TCP PORT'), 'TCP port zeroed');
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

      // TCP/IP, and this assertion used to say PORT_NONE -- which is how the
      // bug survived a green test suite.  CONTROL PORT is not a serial-only
      // setting to be cleared next to BAUD RATE: it is the key that SELECTS the
      // link.  Writing NONE released the COM port and simultaneously told the
      // legacy path the radio had no link at all, so a K4 with a valid IP and
      // TCP port reported `connection=NO PORT SET` and the factory built no
      // driver for it (NY4I, bench, 2026-08-05).
      //
      // The safety property the old assertion was reaching for still holds, and
      // holds BETTER: TCP/IP is not a serial port either, so TR4W still opens no
      // COM port for a network radio -- which matters most on an SO2R station,
      // where that port belongs to the other radio.
      CheckEquals(PORT_NETWORK, ValueOf(rendered, 'RADIO ONE CONTROL PORT'),
                  'the link is TCP/IP -- not NONE, which would mean "no link"');
      CheckEquals('',        ValueOf(rendered, 'RADIO ONE SERIAL FORMAT'), 'format blanked');
      // NOT blank: 'RADIO ONE CAT RTS=' is an INVALID statement to CFGCA and
      // aborts the whole config load.  NONE is the vocabulary's own "off".
      CheckEquals('NONE',    ValueOf(rendered, 'RADIO ONE CAT RTS'),       'RTS is NONE');
      // Baud is a number and so cannot be blank; it is simply irrelevant on a
      // TCP/IP link.  Asserting it stays a number keeps the never-empty
      // invariant visible here too.
      CheckTrue(ValueOf(rendered, 'RADIO ONE BAUD RATE') <> '', 'baud is not blank');

      CheckEquals('192.168.73.108', ValueOf(rendered, 'RADIO ONE IP ADDRESS'), 'IP');
      CheckEquals('9200',           ValueOf(rendered, 'RADIO ONE TCP PORT'),   'TCP port');
      CheckEquals('ny4i',           ValueOf(rendered, 'RADIO ONE NETWORK USERNAME'), 'user');
      CheckEquals('secret',         ValueOf(rendered, 'RADIO ONE NETWORK PASSWORD'), 'password');
   finally
      radio.Free;
   end;
end;

{ ------------------------------------------------------------- values ----- }

procedure TRadioConfigLegacyMapTests.Test_NumericKeysAreNeverEmpty;
var
   radio: TRadioDefinition;
   rendered: TConfigKeyValues;
   i: integer;
begin
   BeginTest('Test_NumericKeysAreNeverEmpty');
   // THE INVARIANT, and the test that was missing when this shipped.
   //
   // A numeric config key written as an EMPTY value does not mean "use the
   // default" to CFGCA.  It means "this was never set", so the variable keeps
   // whatever it already held -- the PREVIOUSLY ACTIVATED RADIO's value -- and
   // a notice is raised naming the parameter (uCFG.pas:1243-1253).  NY4I found
   // it as a queue of "has no value in the config file" dialogs on the first
   // real profile activation, 2026-08-05.
   //
   // The earlier test asserted the OPPOSITE of this and passed, which is what
   // made the defect invisible: it pinned "unset renders empty" as if that were
   // desirable, when empty was silently keeping the old radio's setting.
   radio := TRadioDefinition.Create;   // everything at its zero value
   try
      radio.Name       := 'Bare';
      radio.RegistryId := 'K3';
      rendered := RenderRadioKeys(1, radio, Default(TRadioTypeRendering), nil);

      for i := 0 to High(NUMERICKEYS) do
         begin
         CheckTrue(ValueOf(rendered, NUMERICKEYS[i]) <> '',
                   'not empty: ' + NUMERICKEYS[i]);
         end;

      // The list-valued keys are stricter still: CFGCA REJECTS a blank one as
      // an invalid statement and stops loading the file, so these must always
      // carry a member of the vocabulary.
      for i := 0 to High(LISTKEYS) do
         begin
         CheckTrue(ValueOf(rendered, LISTKEYS[i]) <> '',
                   'list key not empty: ' + LISTKEYS[i]);
         end;
   finally
      radio.Free;
   end;

   // And the same for a CLEARED slot, where the risk is identical: an empty
   // numeric would leave the departing radio's value in force on a slot that is
   // supposed to be empty.
   rendered := RenderEmptySlot(2);
   for i := 0 to High(NUMERICKEYS) do
      begin
      CheckTrue(ValueOf(rendered, StringReplace(NUMERICKEYS[i], 'ONE', 'TWO',
                                                [rfReplaceAll])) <> '',
                'cleared slot not empty: ' + NUMERICKEYS[i]);
      end;
end;

procedure TRadioConfigLegacyMapTests.Test_UnsetNumericsFallBackToTheModelDefault;
var
   radio: TRadioDefinition;
   rendered: TConfigKeyValues;
   typeRendering: TRadioTypeRendering;
begin
   BeginTest('Test_UnsetNumericsFallBackToTheModelDefault');
   // "Blank" in the UI means "use the model default", and the renderer is where
   // that becomes a concrete number -- the caller resolves the defaults from the
   // registry and passes them in, because this unit has no registry.
   typeRendering := Default(TRadioTypeRendering);
   typeRendering.DefaultCIVAddress := 136;
   typeRendering.DefaultBaudRate   := 19200;
   typeRendering.DefaultTCPPort    := 9200;
   typeRendering.DefaultHamLibID   := 3070;

   radio := MakeSerialRadio;
   try
      radio.ReceiverAddress := 0;
      radio.BaudRate        := 0;
      rendered := RenderRadioKeys(1, radio, typeRendering, nil);

      CheckEquals('136',   ValueOf(rendered, 'RADIO ONE RECEIVER ADDRESS'),
                  'the model CI-V address, not blank');
      CheckEquals('19200', ValueOf(rendered, 'RADIO ONE BAUD RATE'),
                  'the model baud rate, not blank');

      // An operator value always wins over the model default.
      radio.ReceiverAddress := 8;
      rendered := RenderRadioKeys(1, radio, typeRendering, nil);
      CheckEquals('8', ValueOf(rendered, 'RADIO ONE RECEIVER ADDRESS'),
                  'the operator''s address wins');
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
      // The operator's 2043 is NOT written for a specific model -- but the key
      // still gets a number, because a blank one would leave the PREVIOUS
      // radio's HamLib id in place, which is the wrong rig to drive.
      CheckEquals('0', ValueOf(rendered, 'RADIO ONE HAMLIB ID'),
                  'the operator value is not written for a specific model');

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

   // BAUD RATE is the ONE numeric here that cannot be 0.  Its CFGCA row is
   // ckArray, so only a MEMBER of CAT_BAUDRATE_ARRAY is accepted; a 0 was
   // written to the operator's ini and TR4W then refused to start with
   // "Invalid statement in config file. Line 106 RADIO TWO BAUD RATE=0"
   // (NY4I, 2026-08-08).
   //
   // The legal set is TYPED OUT, not imported from uCFG: this unit deliberately
   // does not link the config table, and a test that read the same constant as
   // the code could not fail.  If CAT_BAUDRATE_ARRAY ever changes, this is
   // meant to be updated by hand.
   CheckTrue(IndexStr(ValueOf(rendered, 'RADIO TWO BAUD RATE'),
                      ['1200', '2400', '4800', '9600',
                       '19200', '38400', '57600', '115200']) >= 0,
             'an empty slot must still render a LEGAL baud rate, not 0');
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

procedure TRadioConfigLegacyMapTests.Test_KeyerDeviceNameNeverReachesTheLegacyPortKey;
var
   radio: TRadioDefinition;
   prof: TStationProfile;
   rendered: TConfigKeyValues;
begin
   BeginTest('Test_KeyerDeviceNameNeverReachesTheLegacyPortKey');
   // 'KEYER RADIO ONE OUTPUT PORT' takes the PortTypeSA vocabulary, and
   // CheckCommand REJECTS anything else -- TR4W then refuses to start with
   // "Invalid statement in config file".  That is what happened once the
   // profile's CW output began holding keyer DEVICE names (NY4I, 2026-08-08:
   // a keyer named 'WinKeyer' wrote KEYER RADIO ONE OUTPUT PORT=WINKEYER).
   radio := TRadioDefinition.Create;
   prof := TStationProfile.Create;
   try
      radio.Name := 'K4';
      radio.KeyerOutputPort := 'SERIAL 6';
      prof.Radio1Name := 'K4';

      // A DEVICE NAME with no resolved port must fall back to NONE, never leak.
      prof.CWOutput1 := 'WinKeyer';
      rendered := RenderRadioKeys(1, radio, Default(TRadioTypeRendering), prof);
      CheckEquals('NONE', ValueOf(rendered, 'KEYER RADIO ONE OUTPUT PORT'),
                  'an unresolved device name must not reach the legacy key');

      // AND a RESOLVED device must not reach it either -- this key is the CPU
      // keyer's DTR/RTS port, while a WinKeyer owns and opens its own port.
      // Writing the device's port here made LOGK1EA open COM20 exclusively for
      // DTR/RTS keying, after which the WinKeyer thread died with "Access is
      // denied" (NY4I, 2026-08-08). Two keying mechanisms, one port.
      rendered := RenderRadioKeys(1, radio, Default(TRadioTypeRendering), prof, True);
      CheckEquals('NONE', ValueOf(rendered, 'KEYER RADIO ONE OUTPUT PORT'),
                  'a device owns its own port; the CPU-keyer key must stay NONE');

      // The flag decides, NOT the spelling: a keyer NAMED like a port would
      // otherwise pass the looks-like-a-port test and reintroduce the conflict.
      prof.CWOutput1 := 'SERIAL 20';
      rendered := RenderRadioKeys(1, radio, Default(TRadioTypeRendering), prof, True);
      CheckEquals('NONE', ValueOf(rendered, 'KEYER RADIO ONE OUTPUT PORT'),
                  'a device named like a port is still a device');
      prof.CWOutput1 := 'WinKeyer';

      // The radio-relative token uses the RADIO's own port.
      prof.CWOutput1 := 'RADIOPORT';
      rendered := RenderRadioKeys(1, radio, Default(TRadioTypeRendering), prof);
      CheckEquals('SERIAL 6', ValueOf(rendered, 'KEYER RADIO ONE OUTPUT PORT'),
                  'RADIOPORT means the radio''s own keyer port');

      // A profile written BEFORE the keyer library holds a raw port: unchanged.
      prof.CWOutput1 := 'SERIAL 3';
      rendered := RenderRadioKeys(1, radio, Default(TRadioTypeRendering), prof);
      CheckEquals('SERIAL 3', ValueOf(rendered, 'KEYER RADIO ONE OUTPUT PORT'),
                  'a legacy raw port still passes through');
   finally
      prof.Free;
      radio.Free;
   end;
end;

procedure TRadioConfigLegacyMapTests.RunAllTests;
begin
   Test_KeyerDeviceNameNeverReachesTheLegacyPortKey;
   Test_RenderedKeySetMatchesCFGCA;
   Test_EmittedKeysMatchRenderedKeyNames;
   Test_NoKeyIsEmittedTwice;
   Test_SlotTwoUsesTheOtherSpelling;

   Test_FactoryRadioWritesTypeNoneAndFactoryId;
   Test_EnumRadioWritesTypeAndDeletesFactoryId;

   Test_SerialRadioBlanksTheNetworkKeys;
   Test_NetworkRadioBlanksTheSerialKeys;

   Test_NumericKeysAreNeverEmpty;
   Test_UnsetNumericsFallBackToTheModelDefault;
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
