unit uTestRadioConfigStore;

{
  Pins uRadioConfigStore -- the library of radio definitions and the station
  profiles that activate them.

  WHY THESE TESTS MATTER MORE THAN MOST.  This store is what an operator's whole
  station configuration will live in.  A field that fails to round-trip does not
  crash and does not fail to compile: it comes back as a zero or an empty string
  the next time TR4W starts, and the operator discovers it when the radio does
  not answer during a contest.  So the round-trip test walks EVERY field with a
  distinctive value rather than sampling -- a field left out of Save (or out of
  Load) is exactly the bug that would otherwise ship.

  The store is pure -- no globals, no Win32, no MainUnit -- so all of this runs
  against a TMemIniFile with nothing else booted.  That is the point of keeping
  the store on this side of the line.

  ON THE TEMP FILES.  The fixtures give each TMemIniFile a real (unique, temp)
  path rather than ''.  SaveTo ends with UpdateFile, because "SaveTo" ought to
  mean saved rather than "buffered, and good luck" -- and TMemIniFile.UpdateFile
  needs somewhere to write.  The files are deleted when the suite finishes; the
  side benefit is that the write path is genuinely exercised instead of stopping
  at the in-memory buffer.
}

interface

uses
   SysUtils, Classes, IniFiles, System.JSON, System.IOUtils,
   uTR4WTestFramework, uRadioConfigStore,
   // For the render-then-seed round trip.  The store and the renderer are two
   // halves of one conversation and were tested only separately, which is how
   // they came to disagree about how a network radio is spelled.
   uRadioConfigLegacyMap;

type
   TRadioConfigStoreTests = class(TTestCase)
   private
      // Fills every field of a definition with a value distinguishable from
      // both the type's zero AND from any other field's value, so a Save/Load
      // that crosses two fields is caught as well as one that drops a field.
      function MakeFullyPopulatedRadio(const aName: string): TRadioDefinition;
      procedure CheckRadiosMatch(const aExpected, aActual: TRadioDefinition);
      // A TMemIniFile carrying a realistic legacy [Radio] section.
      function MakeLegacyIni: TMemIniFile;
   protected
      procedure Test_RoundTripsEveryRadioField;
      procedure Test_RoundTripsProfiles;
      procedure Test_SaveRemovesDeletedSections;
      procedure Test_LoadOfEmptyFileYieldsEmptyStore;
      procedure Test_AddRejectsBlankAndDuplicateNames;
      procedure Test_NameMatchingIsCaseInsensitive;
      procedure Test_RenameFixesProfileReferences;
      procedure Test_RenameToTakenNameRefused;
      procedure Test_RenameToADifferentSpellingOfItselfAllowed;
      procedure Test_DeleteReferencedRadioRefused;
      procedure Test_DeleteUnreferencedRadioAllowed;
      procedure Test_DeleteActiveProfileClearsActiveName;
      procedure Test_UniqueRadioNameDedupes;
      procedure Test_ValidateCatchesDanglingReference;
      procedure Test_ValidateCatchesSameRadioInBothSlots;
      procedure Test_ValidateCatchesSerialPortCollision;
      procedure Test_ValidateAllowsNetworkRadiosSharingNothing;
      procedure Test_ValidateCatchesMissingActiveProfile;
      procedure Test_PasswordRoundTripsAsPlaintext;
      procedure Test_SeedFromLegacyIniBuildsBothSlots;
      procedure Test_SeedSkipsUnconfiguredSlot;
      procedure Test_SeedWithNoRadiosProducesEmptyStore;
      procedure Test_SeedInfersNetworkTransport;
      procedure Test_SeedInfersNetworkFromTcpIpControlPort;
      procedure Test_NetworkRadioSurvivesRenderThenSeed;
      procedure Test_SeedUsesFactoryIdAndLegacyNetworkNames;
      procedure Test_SeedDedupesIdenticalSlotNames;
      procedure Test_LegacyIniHasRadiosDetectsFactoryOnlySlot;

      // --- JSON persistence (Track F-5a) ---------------------------------
      procedure Test_JSONRoundTripsEveryRadioField;
      procedure Test_JSONRoundTripsProfilesAndGeneral;
      procedure Test_JSONStoresTheSchemaVersion;
      procedure Test_JSONNameSurvivesIniHostileCharacters;
      procedure Test_JSONLoadOfGarbageLeavesAnEmptyStore;
      procedure Test_JSONMissingFileIsReportedNotRaised;
      procedure Test_JSONFileRoundTripsThroughDisk;
      procedure Test_JSONFileHasNoBOM;
   public
      procedure RunAllTests; override;
   end;

implementation

uses
   Windows;   // GetTempPath, for the fixture files

var
   // Every fixture file this suite created, so RunAllTests can remove them.
   // Unit-level rather than a field because the helper below is a plain
   // function -- the fixtures read better without a method qualifier.
   gTempIniFiles: TStringList = nil;
   gTempIniSeq: integer = 0;

// A TMemIniFile on a path of its own.  Unique per call, so no two fixtures can
// see each other's contents even if a Free is missed somewhere.
// A temp FILE NAME (not an ini object) for the JSON tests, registered for
// cleanup exactly like NewTempIni's.
function NewTempFileName(const aExt: string): string;
var
   buf: array[0..MAX_PATH] of Char;
begin
   Windows.GetTempPath(Length(buf), buf);
   Inc(gTempIniSeq);
   Result := IncludeTrailingPathDelimiter(buf) +
             Format('tr4w_cfgstore_%d_%d.%s',
                    [GetCurrentProcessId, gTempIniSeq, aExt]);
   if FileExists(Result) then
      begin
      SysUtils.DeleteFile(Result);
      end;
   if gTempIniFiles <> nil then
      begin
      gTempIniFiles.Add(Result);
      end;
end;

function NewTempIni: TMemIniFile;
var
   buf: array[0..MAX_PATH] of Char;
   path: string;
begin
   Windows.GetTempPath(Length(buf), buf);
   Inc(gTempIniSeq);
   path := IncludeTrailingPathDelimiter(buf) +
           Format('tr4w_cfgstore_%d_%d.ini', [GetCurrentProcessId, gTempIniSeq]);

   // Start from nothing: a file left behind by an aborted earlier run must not
   // become invisible fixture data.
   if FileExists(path) then
      begin
      // SysUtils.DeleteFile, qualified: Windows comes after SysUtils in the
      // uses clause, so a bare DeleteFile binds to the Win32 PWideChar one.
      SysUtils.DeleteFile(path);
      end;

   if gTempIniFiles = nil then
      begin
      gTempIniFiles := TStringList.Create;
      end;
   gTempIniFiles.Add(path);

   Result := TMemIniFile.Create(path);
end;

procedure RemoveTempInis;
var
   i: integer;
begin
   if gTempIniFiles = nil then
      begin
      Exit;
      end;
   for i := 0 to gTempIniFiles.Count - 1 do
      begin
      if FileExists(gTempIniFiles[i]) then
         begin
         SysUtils.DeleteFile(gTempIniFiles[i]);
         end;
      end;
   FreeAndNil(gTempIniFiles);
end;

{ ------------------------------------------------------------- fixtures --- }

function TRadioConfigStoreTests.MakeFullyPopulatedRadio(const aName: string): TRadioDefinition;
begin
   Result := TRadioDefinition.Create;
   Result.Name              := aName;
   Result.RegistryId        := 'IC7100';
   Result.Transport         := rtNetwork;

   Result.ControlPort       := 'SERIAL 17';
   Result.BaudRate          := 19200;
   Result.SerialFormat      := '8N2';
   Result.CatRTS            := 'ALWAYS ON';
   Result.CatDTR            := 'ALWAYS OFF';

   Result.IPAddress         := '192.168.73.108';
   Result.TCPPort           := 9200;
   Result.NetworkUsername   := 'ny4i';
   Result.NetworkPassword   := 'hunter2';

   Result.KeyerOutputPort   := 'SERIAL 3';
   Result.KeyerRTS          := 'CW';
   Result.KeyerDTR          := 'PTT';
   Result.KeyerStopBits     := 2;

   Result.CWByCAT           := True;
   Result.CWSpeedSync       := True;

   Result.UseHamLib         := True;
   Result.HamLibID          := 3085;
   Result.ReceiverAddress   := 136;
   Result.IcomDataModeID    := 3;
   Result.IcomFilterByte    := 2;
   Result.WideCWFilter      := True;
   Result.FT1000MPCWReverse := True;
   Result.FrequencyAdder    := 12000;
   Result.BandOutputPort    := 'PARALLEL 1';
   Result.StartupCommand    := 'FA00014025000;';
   Result.PollingEnable     := False;
end;

procedure TRadioConfigStoreTests.CheckRadiosMatch(const aExpected, aActual: TRadioDefinition);
begin
   CheckTrue(aActual <> nil, 'the radio came back from the store');
   if aActual = nil then
      begin
      Exit;
      end;

   CheckEquals(aExpected.Name,            aActual.Name,            'Name');
   CheckEquals(aExpected.RegistryId,      aActual.RegistryId,      'RegistryId');
   CheckEquals(Ord(aExpected.Transport),  Ord(aActual.Transport),  'Transport');

   CheckEquals(aExpected.ControlPort,     aActual.ControlPort,     'ControlPort');
   CheckEquals(aExpected.BaudRate,        aActual.BaudRate,        'BaudRate');
   CheckEquals(aExpected.SerialFormat,    aActual.SerialFormat,    'SerialFormat');
   CheckEquals(aExpected.CatRTS,          aActual.CatRTS,          'CatRTS');
   CheckEquals(aExpected.CatDTR,          aActual.CatDTR,          'CatDTR');

   CheckEquals(aExpected.IPAddress,       aActual.IPAddress,       'IPAddress');
   CheckEquals(aExpected.TCPPort,         aActual.TCPPort,         'TCPPort');
   CheckEquals(aExpected.NetworkUsername, aActual.NetworkUsername, 'NetworkUsername');
   CheckEquals(aExpected.NetworkPassword, aActual.NetworkPassword, 'NetworkPassword');

   CheckEquals(aExpected.KeyerOutputPort, aActual.KeyerOutputPort, 'KeyerOutputPort');
   CheckEquals(aExpected.KeyerRTS,        aActual.KeyerRTS,        'KeyerRTS');
   CheckEquals(aExpected.KeyerDTR,        aActual.KeyerDTR,        'KeyerDTR');
   CheckEquals(aExpected.KeyerStopBits,   aActual.KeyerStopBits,   'KeyerStopBits');

   CheckTrue(aExpected.CWByCAT     = aActual.CWByCAT,     'CWByCAT');
   CheckTrue(aExpected.CWSpeedSync = aActual.CWSpeedSync, 'CWSpeedSync');

   CheckTrue(aExpected.UseHamLib = aActual.UseHamLib, 'UseHamLib');
   CheckEquals(aExpected.HamLibID,        aActual.HamLibID,        'HamLibID');
   CheckEquals(aExpected.ReceiverAddress, aActual.ReceiverAddress, 'ReceiverAddress');
   CheckEquals(aExpected.IcomDataModeID,  aActual.IcomDataModeID,  'IcomDataModeID');
   CheckEquals(aExpected.IcomFilterByte,  aActual.IcomFilterByte,  'IcomFilterByte');
   CheckTrue(aExpected.WideCWFilter      = aActual.WideCWFilter,      'WideCWFilter');
   CheckTrue(aExpected.FT1000MPCWReverse = aActual.FT1000MPCWReverse, 'FT1000MPCWReverse');
   CheckEquals(aExpected.FrequencyAdder,  aActual.FrequencyAdder,  'FrequencyAdder');
   CheckEquals(aExpected.BandOutputPort,  aActual.BandOutputPort,  'BandOutputPort');
   CheckEquals(aExpected.StartupCommand,  aActual.StartupCommand,  'StartupCommand');
   CheckTrue(aExpected.PollingEnable = aActual.PollingEnable, 'PollingEnable');
end;

function TRadioConfigStoreTests.MakeLegacyIni: TMemIniFile;
begin
   // Shaped like a real tr4w.ini [Radio] section: an Icom on serial in slot
   // one, an Elecraft on serial in slot two, with the keys spelled the way
   // CFGCA spells them -- including the two that read backwards (KEYER RADIO
   // ONE OUTPUT PORT, POLL RADIO ONE).
   Result := NewTempIni;

   Result.WriteString('Radio', 'RADIO ONE TYPE',              'IC7100');
   Result.WriteString('Radio', 'RADIO ONE NAME',              'Shack IC-7100');
   Result.WriteString('Radio', 'RADIO ONE CONTROL PORT',      'SERIAL 17');
   Result.WriteString('Radio', 'RADIO ONE BAUD RATE',         '19200');
   Result.WriteString('Radio', 'RADIO ONE SERIAL FORMAT',     '8N1');
   Result.WriteString('Radio', 'RADIO ONE CAT RTS',           'ALWAYS ON');
   Result.WriteString('Radio', 'RADIO ONE RECEIVER ADDRESS',  '136');
   Result.WriteString('Radio', 'RADIO ONE CW BY CAT',         'TRUE');
   Result.WriteString('Radio', 'RADIO ONE CW SPEED SYNC',     'TRUE');
   Result.WriteString('Radio', 'KEYER RADIO ONE OUTPUT PORT', 'SERIAL 3');
   Result.WriteString('Radio', 'POLL RADIO ONE',              'TRUE');

   Result.WriteString('Radio', 'RADIO TWO TYPE',              'K3');
   Result.WriteString('Radio', 'RADIO TWO CONTROL PORT',      'SERIAL 5');
   Result.WriteString('Radio', 'RADIO TWO BAUD RATE',         '38400');
   Result.WriteString('Radio', 'KEYER RADIO TWO OUTPUT PORT', 'SERIAL 6');
   Result.WriteString('Radio', 'POLL RADIO TWO',              'FALSE');
end;

{ --------------------------------------------------------- persistence --- }

procedure TRadioConfigStoreTests.Test_RoundTripsEveryRadioField;
var
   store: TRadioConfigStore;
   ini: TMemIniFile;
   original: TRadioDefinition;
   err: string;
begin
   BeginTest('Test_RoundTripsEveryRadioField');
   // Every field, with a distinctive value.  A field missing from either half
   // of the persistence code shows up here and nowhere else until a contest.
   ini := NewTempIni;
   try
      original := MakeFullyPopulatedRadio('K4D');

      store := TRadioConfigStore.Create;
      try
         CheckTrue(store.AddRadio(original.Clone, err), 'added: ' + err);
         store.SaveTo(ini);
      finally
         store.Free;
      end;

      store := TRadioConfigStore.Create;
      try
         store.LoadFrom(ini);
         CheckEquals(1, store.RadioCount, 'one radio came back');
         CheckRadiosMatch(original, store.FindRadio('K4D'));
      finally
         store.Free;
      end;

      original.Free;
   finally
      ini.Free;
   end;
end;

procedure TRadioConfigStoreTests.Test_RoundTripsProfiles;
var
   store: TRadioConfigStore;
   ini: TMemIniFile;
   prof: TStationProfile;
   loaded: TStationProfile;
   radio: TRadioDefinition;
   err: string;
begin
   BeginTest('Test_RoundTripsProfiles');
   ini := NewTempIni;
   try
      store := TRadioConfigStore.Create;
      try
         radio := TRadioDefinition.Create;
         radio.Name := 'K3';
         store.AddRadio(radio, err);

         radio := TRadioDefinition.Create;
         radio.Name := 'IC-7100';
         store.AddRadio(radio, err);

         prof := TStationProfile.Create;
         prof.Name              := 'Home SO2R';
         prof.Radio1Name        := 'K3';
         prof.Radio2Name        := 'IC-7100';
         prof.DefaultActiveSlot := 2;
         prof.CWOutput1         := CWOUTPUT_CAT;
         prof.CWOutput2         := 'SERIAL 4';
         prof.SpeedSync1        := True;
         prof.SpeedSync2        := False;
         prof.SO2REnabled       := True;
         CheckTrue(store.AddProfile(prof, err), 'profile added: ' + err);

         store.ActiveProfileName    := 'Home SO2R';
         store.AutoConnectOnStartup := True;
         store.SaveTo(ini);
      finally
         store.Free;
      end;

      store := TRadioConfigStore.Create;
      try
         store.LoadFrom(ini);
         CheckEquals(1, store.ProfileCount, 'one profile came back');
         loaded := store.FindProfile('Home SO2R');
         CheckTrue(loaded <> nil, 'found by name');
         if loaded <> nil then
            begin
            CheckEquals('K3',        loaded.Radio1Name, 'Radio1Name');
            CheckEquals('IC-7100',   loaded.Radio2Name, 'Radio2Name');
            CheckEquals(2,           loaded.DefaultActiveSlot, 'DefaultActiveSlot');
            CheckEquals(CWOUTPUT_CAT, loaded.CWOutput1, 'CWOutput1');
            CheckEquals('SERIAL 4',  loaded.CWOutput2, 'CWOutput2');
            CheckTrue(loaded.SpeedSync1,       'SpeedSync1');
            CheckFalse(loaded.SpeedSync2,      'SpeedSync2');
            CheckTrue(loaded.SO2REnabled,      'SO2REnabled');
            end;
         CheckEquals('Home SO2R', store.ActiveProfileName, 'ActiveProfileName');
         CheckTrue(store.AutoConnectOnStartup, 'AutoConnectOnStartup');
         CheckTrue(store.ActiveProfile = loaded, 'ActiveProfile resolves');
      finally
         store.Free;
      end;
   finally
      ini.Free;
   end;
end;

procedure TRadioConfigStoreTests.Test_SaveRemovesDeletedSections;
var
   store: TRadioConfigStore;
   ini: TMemIniFile;
   radio: TRadioDefinition;
   err: string;
begin
   BeginTest('Test_SaveRemovesDeletedSections');
   // The classic ini-writer bug: delete a radio in the UI, save, and the old
   // section survives because writing only ever adds.  Next load resurrects
   // the radio the operator just removed.
   ini := NewTempIni;
   try
      store := TRadioConfigStore.Create;
      try
         radio := TRadioDefinition.Create;
         radio.Name := 'Old Rig';
         store.AddRadio(radio, err);
         store.SaveTo(ini);
         CheckTrue(ini.SectionExists('Radio.Old Rig'), 'section written');

         CheckTrue(store.DeleteRadio('Old Rig', err), 'deleted: ' + err);
         store.SaveTo(ini);
         CheckFalse(ini.SectionExists('Radio.Old Rig'), 'section erased on save');
      finally
         store.Free;
      end;

      store := TRadioConfigStore.Create;
      try
         store.LoadFrom(ini);
         CheckEquals(0, store.RadioCount, 'the deleted radio does not come back');
      finally
         store.Free;
      end;
   finally
      ini.Free;
   end;
end;

procedure TRadioConfigStoreTests.Test_LoadOfEmptyFileYieldsEmptyStore;
var
   store: TRadioConfigStore;
   ini: TMemIniFile;
   err: string;
begin
   BeginTest('Test_LoadOfEmptyFileYieldsEmptyStore');
   // First run: the file does not exist yet.  That must be an empty store, not
   // an exception -- TR4W has to start.
   ini := NewTempIni;
   try
      store := TRadioConfigStore.Create;
      try
         store.LoadFrom(ini);
         CheckEquals(0, store.RadioCount,   'no radios');
         CheckEquals(0, store.ProfileCount, 'no profiles');
         CheckEquals('', store.ActiveProfileName, 'no active profile');
         CheckTrue(store.ActiveProfile = nil, 'ActiveProfile is nil');
         CheckTrue(store.Validate(err), 'an empty store is valid: ' + err);
      finally
         store.Free;
      end;
   finally
      ini.Free;
   end;
end;

procedure TRadioConfigStoreTests.Test_PasswordRoundTripsAsPlaintext;
var
   store: TRadioConfigStore;
   ini: TMemIniFile;
   radio: TRadioDefinition;
   err: string;
begin
   BeginTest('Test_PasswordRoundTripsAsPlaintext');
   // Status quo, pinned deliberately so that adding encryption later is a
   // VISIBLE change to this test rather than a silent one.  The legacy
   // RADIO ONE NETWORK PASSWORD key is plaintext today; this store does not
   // change the security posture while changing the storage location.
   ini := NewTempIni;
   try
      store := TRadioConfigStore.Create;
      try
         radio := TRadioDefinition.Create;
         radio.Name := 'K4 Remote';
         radio.NetworkPassword := 'p@ss w0rd!';
         store.AddRadio(radio, err);
         store.SaveTo(ini);
      finally
         store.Free;
      end;

      CheckEquals('p@ss w0rd!',
                  ini.ReadString('Radio.K4 Remote', 'NetworkPassword', ''),
                  'stored as plaintext');

      store := TRadioConfigStore.Create;
      try
         store.LoadFrom(ini);
         CheckEquals('p@ss w0rd!', store.FindRadio('K4 Remote').NetworkPassword,
                     'round-trips including spaces and punctuation');
      finally
         store.Free;
      end;
   finally
      ini.Free;
   end;
end;

{ ------------------------------------------------------ names and edits --- }

procedure TRadioConfigStoreTests.Test_AddRejectsBlankAndDuplicateNames;
var
   store: TRadioConfigStore;
   radio: TRadioDefinition;
   err: string;
begin
   BeginTest('Test_AddRejectsBlankAndDuplicateNames');
   store := TRadioConfigStore.Create;
   try
      radio := TRadioDefinition.Create;
      radio.Name := '   ';
      CheckFalse(store.AddRadio(radio, err), 'a blank name is refused');
      CheckTrue(err <> '', 'and says why');
      radio.Free;   // refused, so the caller still owns it

      radio := TRadioDefinition.Create;
      radio.Name := 'K3';
      CheckTrue(store.AddRadio(radio, err), 'first K3 accepted');

      radio := TRadioDefinition.Create;
      radio.Name := 'K3';
      CheckFalse(store.AddRadio(radio, err), 'second K3 refused');
      radio.Free;

      CheckEquals(1, store.RadioCount, 'only one radio is in the store');
   finally
      store.Free;
   end;
end;

procedure TRadioConfigStoreTests.Test_NameMatchingIsCaseInsensitive;
var
   store: TRadioConfigStore;
   radio: TRadioDefinition;
   err: string;
begin
   BeginTest('Test_NameMatchingIsCaseInsensitive');
   // An operator typing 'k3' means the 'K3' they already defined.  A store
   // holding both would be a trap, and a lookup that missed would be worse.
   store := TRadioConfigStore.Create;
   try
      radio := TRadioDefinition.Create;
      radio.Name := 'K3';
      store.AddRadio(radio, err);

      CheckTrue(store.FindRadio('k3') <> nil,   'lower case finds it');
      CheckTrue(store.FindRadio(' K3 ') <> nil, 'surrounding space is trimmed');

      radio := TRadioDefinition.Create;
      radio.Name := 'k3';
      CheckFalse(store.AddRadio(radio, err), 'a differently-cased duplicate is refused');
      radio.Free;
   finally
      store.Free;
   end;
end;

procedure TRadioConfigStoreTests.Test_RenameFixesProfileReferences;
var
   store: TRadioConfigStore;
   radio: TRadioDefinition;
   prof: TStationProfile;
   err: string;
begin
   BeginTest('Test_RenameFixesProfileReferences');
   // Profiles refer to radios BY NAME, so a rename that does not fix the
   // references leaves a profile silently pointing at nothing.
   store := TRadioConfigStore.Create;
   try
      radio := TRadioDefinition.Create;
      radio.Name := 'K3';
      store.AddRadio(radio, err);

      radio := TRadioDefinition.Create;
      radio.Name := 'IC-7100';
      store.AddRadio(radio, err);

      prof := TStationProfile.Create;
      prof.Name       := 'Home';
      prof.Radio1Name := 'K3';
      prof.Radio2Name := 'IC-7100';
      store.AddProfile(prof, err);

      CheckTrue(store.RenameRadio('K3', 'K3 (loaner)', err), 'renamed: ' + err);
      CheckEquals('K3 (loaner)', prof.Radio1Name, 'slot one reference followed');
      CheckEquals('IC-7100',     prof.Radio2Name, 'the other slot is untouched');
      CheckTrue(store.FindRadio('K3') = nil, 'the old name is gone');
      CheckTrue(store.FindRadio('K3 (loaner)') <> nil, 'the new name resolves');
      CheckTrue(store.Validate(err), 'the store is still valid: ' + err);
   finally
      store.Free;
   end;
end;

procedure TRadioConfigStoreTests.Test_RenameToTakenNameRefused;
var
   store: TRadioConfigStore;
   radio: TRadioDefinition;
   err: string;
begin
   BeginTest('Test_RenameToTakenNameRefused');
   store := TRadioConfigStore.Create;
   try
      radio := TRadioDefinition.Create;
      radio.Name := 'K3';
      store.AddRadio(radio, err);
      radio := TRadioDefinition.Create;
      radio.Name := 'K4';
      store.AddRadio(radio, err);

      CheckFalse(store.RenameRadio('K3', 'K4', err), 'refused');
      CheckTrue(err <> '', 'and says why');
      CheckTrue(store.FindRadio('K3') <> nil, 'the original name survives');
   finally
      store.Free;
   end;
end;

procedure TRadioConfigStoreTests.Test_RenameToADifferentSpellingOfItselfAllowed;
var
   store: TRadioConfigStore;
   radio: TRadioDefinition;
   err: string;
begin
   BeginTest('Test_RenameToADifferentSpellingOfItselfAllowed');
   // Recasing your own radio is legitimate; only a DIFFERENT radio holding the
   // name is a collision.  Getting this wrong makes 'k3' -> 'K3' impossible.
   store := TRadioConfigStore.Create;
   try
      radio := TRadioDefinition.Create;
      radio.Name := 'k3';
      store.AddRadio(radio, err);

      CheckTrue(store.RenameRadio('k3', 'K3', err), 'recasing allowed: ' + err);
      CheckEquals('K3', store.Radio(0).Name, 'the new spelling took');
   finally
      store.Free;
   end;
end;

procedure TRadioConfigStoreTests.Test_DeleteReferencedRadioRefused;
var
   store: TRadioConfigStore;
   radio: TRadioDefinition;
   prof: TStationProfile;
   err: string;
begin
   BeginTest('Test_DeleteReferencedRadioRefused');
   store := TRadioConfigStore.Create;
   try
      radio := TRadioDefinition.Create;
      radio.Name := 'K3';
      store.AddRadio(radio, err);

      prof := TStationProfile.Create;
      prof.Name       := 'Home';
      prof.Radio1Name := 'K3';
      store.AddProfile(prof, err);

      CheckFalse(store.DeleteRadio('K3', err), 'refused while a profile uses it');
      // The message must NAME the profile -- "cannot delete" with no reason is
      // the kind of refusal that makes people delete the ini by hand.
      CheckTrue(Pos('Home', err) > 0, 'the message names the profile: ' + err);
      CheckEquals(1, store.RadioCount, 'still there');
   finally
      store.Free;
   end;
end;

procedure TRadioConfigStoreTests.Test_DeleteUnreferencedRadioAllowed;
var
   store: TRadioConfigStore;
   radio: TRadioDefinition;
   err: string;
begin
   BeginTest('Test_DeleteUnreferencedRadioAllowed');
   store := TRadioConfigStore.Create;
   try
      radio := TRadioDefinition.Create;
      radio.Name := 'Spare 706';
      store.AddRadio(radio, err);

      CheckTrue(store.DeleteRadio('Spare 706', err), 'deleted: ' + err);
      CheckEquals(0, store.RadioCount, 'gone');
      CheckFalse(store.DeleteRadio('Spare 706', err), 'deleting it twice is refused');
   finally
      store.Free;
   end;
end;

procedure TRadioConfigStoreTests.Test_DeleteActiveProfileClearsActiveName;
var
   store: TRadioConfigStore;
   prof: TStationProfile;
   err: string;
begin
   BeginTest('Test_DeleteActiveProfileClearsActiveName');
   // Refusing to delete the active profile would leave the operator unable to
   // remove one without first activating another.  Allowed -- but the active
   // name must be cleared, or the store fails Validate afterwards.
   store := TRadioConfigStore.Create;
   try
      prof := TStationProfile.Create;
      prof.Name := 'Portable';
      store.AddProfile(prof, err);
      store.ActiveProfileName := 'Portable';

      CheckTrue(store.DeleteProfile('Portable', err), 'deleted: ' + err);
      CheckEquals('', store.ActiveProfileName, 'active name cleared');
      CheckTrue(store.Validate(err), 'and the store is still valid: ' + err);
   finally
      store.Free;
   end;
end;

procedure TRadioConfigStoreTests.Test_UniqueRadioNameDedupes;
var
   store: TRadioConfigStore;
   radio: TRadioDefinition;
   err: string;
begin
   BeginTest('Test_UniqueRadioNameDedupes');
   store := TRadioConfigStore.Create;
   try
      CheckEquals('K3', store.UniqueRadioName('K3'), 'unused name comes back as is');

      radio := TRadioDefinition.Create;
      radio.Name := 'K3';
      store.AddRadio(radio, err);
      CheckEquals('K3 (2)', store.UniqueRadioName('K3'), 'second gets a suffix');

      radio := TRadioDefinition.Create;
      radio.Name := 'K3 (2)';
      store.AddRadio(radio, err);
      CheckEquals('K3 (3)', store.UniqueRadioName('K3'), 'and keeps counting');

      CheckEquals('Radio', store.UniqueRadioName('  '), 'a blank base gets a stem');
   finally
      store.Free;
   end;
end;

{ ------------------------------------------------------------- validate --- }

procedure TRadioConfigStoreTests.Test_ValidateCatchesDanglingReference;
var
   store: TRadioConfigStore;
   prof: TStationProfile;
   err: string;
begin
   BeginTest('Test_ValidateCatchesDanglingReference');
   store := TRadioConfigStore.Create;
   try
      prof := TStationProfile.Create;
      prof.Name       := 'Home';
      prof.Radio1Name := 'A Radio That Is Gone';
      store.AddProfile(prof, err);

      CheckFalse(store.Validate(err), 'caught');
      CheckTrue(Pos('A Radio That Is Gone', err) > 0,
                'the message names the missing radio: ' + err);
   finally
      store.Free;
   end;
end;

procedure TRadioConfigStoreTests.Test_ValidateCatchesSameRadioInBothSlots;
var
   store: TRadioConfigStore;
   radio: TRadioDefinition;
   prof: TStationProfile;
   err: string;
begin
   BeginTest('Test_ValidateCatchesSameRadioInBothSlots');
   // One definition in both slots is not SO2R; it is one radio whose port
   // would be opened twice.
   store := TRadioConfigStore.Create;
   try
      radio := TRadioDefinition.Create;
      radio.Name := 'K3';
      store.AddRadio(radio, err);

      prof := TStationProfile.Create;
      prof.Name       := 'Home';
      prof.Radio1Name := 'K3';
      prof.Radio2Name := 'K3';
      store.AddProfile(prof, err);

      CheckFalse(store.Validate(err), 'caught');
      CheckTrue(Pos('both slots', err) > 0, 'the message explains: ' + err);
   finally
      store.Free;
   end;
end;

procedure TRadioConfigStoreTests.Test_ValidateCatchesSerialPortCollision;
var
   store: TRadioConfigStore;
   radio: TRadioDefinition;
   prof: TStationProfile;
   err: string;
begin
   BeginTest('Test_ValidateCatchesSerialPortCollision');
   // Two different serial radios on one COM port: the second open fails and
   // that radio silently never answers.  Better caught here than on the air.
   store := TRadioConfigStore.Create;
   try
      radio := TRadioDefinition.Create;
      radio.Name        := 'K3';
      radio.Transport   := rtSerial;
      radio.ControlPort := 'SERIAL 5';
      store.AddRadio(radio, err);

      radio := TRadioDefinition.Create;
      radio.Name        := 'IC-7100';
      radio.Transport   := rtSerial;
      radio.ControlPort := 'serial 5';   // same port, different spelling
      store.AddRadio(radio, err);

      prof := TStationProfile.Create;
      prof.Name       := 'Home';
      prof.Radio1Name := 'K3';
      prof.Radio2Name := 'IC-7100';
      store.AddProfile(prof, err);

      CheckFalse(store.Validate(err), 'caught despite the casing difference');
      CheckTrue(Pos('SERIAL 5', err) > 0, 'the message names the port: ' + err);
   finally
      store.Free;
   end;
end;

procedure TRadioConfigStoreTests.Test_ValidateAllowsNetworkRadiosSharingNothing;
var
   store: TRadioConfigStore;
   radio: TRadioDefinition;
   prof: TStationProfile;
   err: string;
begin
   BeginTest('Test_ValidateAllowsNetworkRadiosSharingNothing');
   // Both radios carry ControlPort='NONE' (the default).  'NONE' is not a
   // port, so two of them must NOT read as a collision -- this is the false
   // positive that would make every network SO2R profile invalid.
   store := TRadioConfigStore.Create;
   try
      radio := TRadioDefinition.Create;
      radio.Name      := 'K4 Remote';
      radio.Transport := rtNetwork;
      radio.IPAddress := '192.168.73.108';
      store.AddRadio(radio, err);

      radio := TRadioDefinition.Create;
      radio.Name      := 'Flex Remote';
      radio.Transport := rtNetwork;
      radio.IPAddress := '192.168.73.9';
      store.AddRadio(radio, err);

      prof := TStationProfile.Create;
      prof.Name        := 'Remote SO2R';
      prof.Radio1Name  := 'K4 Remote';
      prof.Radio2Name  := 'Flex Remote';
      prof.SO2REnabled := True;
      store.AddProfile(prof, err);
      store.ActiveProfileName := 'Remote SO2R';

      CheckTrue(store.Validate(err), 'valid: ' + err);
   finally
      store.Free;
   end;
end;

procedure TRadioConfigStoreTests.Test_ValidateCatchesMissingActiveProfile;
var
   store: TRadioConfigStore;
   err: string;
begin
   BeginTest('Test_ValidateCatchesMissingActiveProfile');
   // An active-profile name that names nothing would activate nothing, with no
   // visible cause at all.
   store := TRadioConfigStore.Create;
   try
      store.ActiveProfileName := 'Nonexistent';
      CheckFalse(store.Validate(err), 'caught');
      CheckTrue(Pos('Nonexistent', err) > 0, 'names it: ' + err);
   finally
      store.Free;
   end;
end;

{ ----------------------------------------------------------- first run ---- }

procedure TRadioConfigStoreTests.Test_SeedFromLegacyIniBuildsBothSlots;
var
   store: TRadioConfigStore;
   ini: TMemIniFile;
   radio: TRadioDefinition;
   prof: TStationProfile;
   err: string;
begin
   BeginTest('Test_SeedFromLegacyIniBuildsBothSlots');
   // First open of the new dialog: the operator's existing configuration
   // becomes two definitions and a Default profile, without them retyping it.
   ini := MakeLegacyIni;
   store := TRadioConfigStore.Create;
   try
      CheckTrue(TRadioConfigStore.LegacyIniHasRadios(ini), 'legacy radios detected');
      store.SeedFromLegacyIni(ini);

      CheckEquals(2, store.RadioCount, 'both slots seeded');

      radio := store.FindRadio('Shack IC-7100');
      CheckTrue(radio <> nil, 'slot one took the operator''s RADIO ONE NAME');
      if radio <> nil then
         begin
         CheckEquals('IC7100',    radio.RegistryId,  'RegistryId from TYPE');
         CheckEquals('SERIAL 17', radio.ControlPort, 'ControlPort');
         CheckEquals(19200,       radio.BaudRate,    'BaudRate');
         CheckEquals('8N1',       radio.SerialFormat, 'SerialFormat');
         CheckEquals('ALWAYS ON', radio.CatRTS,      'CatRTS');
         CheckEquals(136,         radio.ReceiverAddress, 'ReceiverAddress');
         CheckEquals('SERIAL 3',  radio.KeyerOutputPort,
                     'KEYER RADIO ONE OUTPUT PORT -- the backwards spelling');
         CheckTrue(radio.CWByCAT,       'CWByCAT');
         CheckTrue(radio.CWSpeedSync,   'CWSpeedSync');
         CheckTrue(radio.PollingEnable, 'POLL RADIO ONE = TRUE');
         CheckEquals(Ord(rtSerial), Ord(radio.Transport), 'serial transport');
         end;

      // Slot two has no RADIO TWO NAME, so the id is the fallback name.
      radio := store.FindRadio('K3');
      CheckTrue(radio <> nil, 'slot two named from its type');
      if radio <> nil then
         begin
         CheckEquals('SERIAL 5', radio.ControlPort, 'ControlPort');
         CheckEquals(38400,      radio.BaudRate,    'BaudRate');
         CheckEquals('SERIAL 6', radio.KeyerOutputPort, 'keyer port');
         CheckFalse(radio.PollingEnable, 'POLL RADIO TWO = FALSE is honoured');
         end;

      prof := store.FindProfile('Default');
      CheckTrue(prof <> nil, 'a Default profile was created');
      if prof <> nil then
         begin
         CheckEquals('Shack IC-7100', prof.Radio1Name, 'slot one');
         CheckEquals('K3',            prof.Radio2Name, 'slot two');
         CheckTrue(prof.SO2REnabled,  'two configured slots means SO2R');
         // Slot one keys by CAT, so its CW output is CAT rather than the port.
         CheckEquals(CWOUTPUT_CAT, prof.CWOutput1, 'CW output follows CW BY CAT');
         CheckEquals('SERIAL 6',   prof.CWOutput2, 'slot two keys on its keyer port');
         CheckTrue(prof.SpeedSync1, 'SpeedSync1');
         end;

      CheckEquals('Default', store.ActiveProfileName, 'and it is active');
      CheckTrue(store.Validate(err), 'the seeded store is valid: ' + err);
   finally
      store.Free;
      ini.Free;
   end;
end;

procedure TRadioConfigStoreTests.Test_SeedSkipsUnconfiguredSlot;
var
   store: TRadioConfigStore;
   ini: TMemIniFile;
   prof: TStationProfile;
begin
   BeginTest('Test_SeedSkipsUnconfiguredSlot');
   // One radio is the common case.  TYPE=NONE must not become a definition.
   ini := NewTempIni;
   store := TRadioConfigStore.Create;
   try
      ini.WriteString('Radio', 'RADIO ONE TYPE',         'K3');
      ini.WriteString('Radio', 'RADIO ONE CONTROL PORT', 'SERIAL 5');
      ini.WriteString('Radio', 'RADIO TWO TYPE',         'NONE');

      store.SeedFromLegacyIni(ini);

      CheckEquals(1, store.RadioCount, 'only the configured slot');
      prof := store.FindProfile('Default');
      CheckTrue(prof <> nil, 'profile created');
      if prof <> nil then
         begin
         CheckEquals('K3', prof.Radio1Name, 'slot one filled');
         CheckEquals('',   prof.Radio2Name, 'slot two left empty');
         CheckFalse(prof.SO2REnabled, 'one radio is not SO2R');
         end;
   finally
      store.Free;
      ini.Free;
   end;
end;

procedure TRadioConfigStoreTests.Test_SeedWithNoRadiosProducesEmptyStore;
var
   store: TRadioConfigStore;
   ini: TMemIniFile;
begin
   BeginTest('Test_SeedWithNoRadiosProducesEmptyStore');
   // A brand-new installation.  Seeding must produce nothing at all -- not an
   // empty 'Default' profile pointing at no radios, which would then have to
   // be explained in the UI.
   ini := NewTempIni;
   store := TRadioConfigStore.Create;
   try
      ini.WriteString('Radio', 'RADIO ONE TYPE', 'NONE');
      ini.WriteString('Radio', 'RADIO TWO TYPE', 'NONE');

      CheckFalse(TRadioConfigStore.LegacyIniHasRadios(ini), 'nothing to seed from');
      store.SeedFromLegacyIni(ini);
      CheckEquals(0, store.RadioCount,   'no radios');
      CheckEquals(0, store.ProfileCount, 'and no profile');
   finally
      store.Free;
      ini.Free;
   end;
end;

procedure TRadioConfigStoreTests.Test_SeedInfersNetworkTransport;
var
   store: TRadioConfigStore;
   ini: TMemIniFile;
   radio: TRadioDefinition;
begin
   BeginTest('Test_SeedInfersNetworkTransport');
   // The legacy ini has no transport key; the legacy code infers it the same
   // way -- no serial port but an IP address means network.
   ini := NewTempIni;
   store := TRadioConfigStore.Create;
   try
      ini.WriteString('Radio', 'RADIO ONE TYPE',             'K4');
      ini.WriteString('Radio', 'RADIO ONE NAME',             'K4D');
      ini.WriteString('Radio', 'RADIO ONE CONTROL PORT',     'NONE');
      ini.WriteString('Radio', 'RADIO ONE IP ADDRESS',       '192.168.73.108');
      ini.WriteString('Radio', 'RADIO ONE TCP PORT',         '9200');
      ini.WriteString('Radio', 'RADIO ONE NETWORK USERNAME', 'ny4i');
      ini.WriteString('Radio', 'RADIO ONE NETWORK PASSWORD', 'secret');

      store.SeedFromLegacyIni(ini);
      radio := store.FindRadio('K4D');
      CheckTrue(radio <> nil, 'seeded');
      if radio <> nil then
         begin
         CheckEquals(Ord(rtNetwork), Ord(radio.Transport), 'inferred as network');
         CheckEquals('192.168.73.108', radio.IPAddress, 'IPAddress');
         CheckEquals(9200,             radio.TCPPort,   'TCPPort');
         CheckEquals('ny4i',           radio.NetworkUsername, 'username');
         CheckEquals('secret',         radio.NetworkPassword, 'password');
         CheckEquals('K4D [192.168.73.108:9200]', radio.DisplaySummary,
                     'DisplaySummary reads as the plan specified');
         end;
   finally
      store.Free;
      ini.Free;
   end;
end;

// The spelling the program ACTUALLY writes.  Test_SeedInfersNetworkTransport
// above covers 'NONE' + IP, the pre-2026-08-05 convention -- and covering only
// that is how this defect survived: the writer moved to 'TCP/IP' and the reader
// did not, so a correctly-configured network K4 seeded as SERIAL with its IP
// still attached.  The editor then opened it on the Serial tab, found no
// matching port, and saved CONTROL PORT=NONE over the definition.
procedure TRadioConfigStoreTests.Test_SeedInfersNetworkFromTcpIpControlPort;
var
   store: TRadioConfigStore;
   ini: TMemIniFile;
   radio: TRadioDefinition;
begin
   BeginTest('Test_SeedInfersNetworkFromTcpIpControlPort');
   ini := NewTempIni;
   store := TRadioConfigStore.Create;
   try
      ini.WriteString('Radio', 'RADIO ONE TYPE',         'K4');
      ini.WriteString('Radio', 'RADIO ONE NAME',         'K4-278');
      ini.WriteString('Radio', 'RADIO ONE CONTROL PORT', 'TCP/IP');
      ini.WriteString('Radio', 'RADIO ONE IP ADDRESS',   '192.168.73.108');
      ini.WriteString('Radio', 'RADIO ONE TCP PORT',     '9200');

      store.SeedFromLegacyIni(ini);
      radio := store.FindRadio('K4-278');
      CheckTrue(radio <> nil, 'seeded');
      if radio <> nil then
         begin
         CheckEquals(Ord(rtNetwork), Ord(radio.Transport),
            'CONTROL PORT=TCP/IP must seed as NETWORK.  Read as serial, the '
            + 'radio loses its network identity while keeping its IP, and the '
            + 'factory then refuses to build a driver for it.');
         CheckEquals('192.168.73.108', radio.IPAddress, 'IPAddress');
         CheckEquals(9200,             radio.TCPPort,   'TCPPort');
         end;
   finally
      store.Free;
      ini.Free;
   end;
end;

// THE TEST THAT WOULD HAVE CAUGHT IT, and the one that keeps the two halves
// honest from here on: render a definition the way the program renders it, feed
// exactly those keys back through seeding, and require the radio to come out
// the same.  Neither side is allowed to be the reference for the other -- the
// keys come from RenderRadioKeys, so changing how a network radio is spelled
// fails here rather than silently converting operators' radios to serial.
procedure TRadioConfigStoreTests.Test_NetworkRadioSurvivesRenderThenSeed;
var
   store: TRadioConfigStore;
   ini: TMemIniFile;
   source, seeded: TRadioDefinition;
   rendered: TConfigKeyValues;
   typeRendering: TRadioTypeRendering;
   i: integer;
begin
   BeginTest('Test_NetworkRadioSurvivesRenderThenSeed');
   ini := NewTempIni;
   store := TRadioConfigStore.Create;
   source := TRadioDefinition.Create;
   try
      source.Name       := 'K4-278';
      source.RegistryId := 'K4';
      source.Transport  := rtNetwork;
      source.IPAddress  := '192.168.73.108';
      source.TCPPort    := 9200;
      source.BaudRate   := 38400;

      // A real rendering, not Default().  With an empty LegacyTypeName the
      // renderer writes RADIO ONE TYPE='' and seeding correctly treats the slot
      // as unconfigured -- which made the first version of this test fail for a
      // reason that had nothing to do with transport.
      typeRendering := Default(TRadioTypeRendering);
      typeRendering.LegacyTypeName := 'K4';

      rendered := RenderRadioKeys(1, source, typeRendering, nil);
      for i := 0 to High(rendered) do
         begin
         ini.WriteString('Radio', rendered[i].Key, rendered[i].Value);
         end;
      // The name is not part of the rendered set in every path; seeding needs
      // one to find the radio by.
      ini.WriteString('Radio', 'RADIO ONE NAME', source.Name);

      store.SeedFromLegacyIni(ini);
      seeded := store.FindRadio('K4-278');
      CheckTrue(seeded <> nil, 'the rendered radio seeds back');
      if seeded <> nil then
         begin
         CheckEquals(Ord(rtNetwork), Ord(seeded.Transport),
            'a NETWORK radio must still be NETWORK after render -> seed.  If '
            + 'this fails, the renderer and the seeder disagree about how a '
            + 'network radio is spelled, and every operator with a network rig '
            + 'silently gets a serial definition on migration.');
         CheckEquals(source.IPAddress, seeded.IPAddress, 'IPAddress survived');
         CheckEquals(source.TCPPort,   seeded.TCPPort,   'TCPPort survived');
         end;
   finally
      source.Free;
      store.Free;
      ini.Free;
   end;
end;

procedure TRadioConfigStoreTests.Test_SeedUsesFactoryIdAndLegacyNetworkNames;
var
   store: TRadioConfigStore;
   ini: TMemIniFile;
   radio: TRadioDefinition;
begin
   BeginTest('Test_SeedUsesFactoryIdAndLegacyNetworkNames');
   // A factory (string-id) radio writes TYPE=NONE and puts the real identity in
   // FACTORY ID -- so reading TYPE alone would skip the slot entirely.  The
   // same ini is old enough to still use the ICOM-prefixed network key names
   // that issue #904 replaced.
   ini := NewTempIni;
   store := TRadioConfigStore.Create;
   try
      ini.WriteString('Radio', 'RADIO ONE TYPE',                  'NONE');
      ini.WriteString('Radio', 'RADIO ONE FACTORY ID',            'IC7300');
      ini.WriteString('Radio', 'RADIO ONE CONTROL PORT',          'SERIAL 9');
      ini.WriteString('Radio', 'RADIO ONE ICOM NETWORK USERNAME', 'olduser');
      ini.WriteString('Radio', 'RADIO ONE ICOM NETWORK PASSWORD', 'oldpass');

      CheckTrue(TRadioConfigStore.LegacyIniHasRadios(ini),
                'a FACTORY-ID-only slot counts as configured');

      store.SeedFromLegacyIni(ini);
      radio := store.FindRadio('IC7300');
      CheckTrue(radio <> nil, 'seeded from FACTORY ID');
      if radio <> nil then
         begin
         CheckEquals('IC7300',  radio.RegistryId, 'RegistryId is the factory id');
         CheckEquals('olduser', radio.NetworkUsername, 'legacy username key read');
         CheckEquals('oldpass', radio.NetworkPassword, 'legacy password key read');
         end;
   finally
      store.Free;
      ini.Free;
   end;
end;

procedure TRadioConfigStoreTests.Test_SeedDedupesIdenticalSlotNames;
var
   store: TRadioConfigStore;
   ini: TMemIniFile;
   prof: TStationProfile;
begin
   BeginTest('Test_SeedDedupesIdenticalSlotNames');
   // Two of the same model, or two slots named the same thing, is a real SO2R
   // setup.  Without deduping, the second AddRadio is refused and slot two
   // vanishes silently.
   ini := NewTempIni;
   store := TRadioConfigStore.Create;
   try
      ini.WriteString('Radio', 'RADIO ONE TYPE',         'K3');
      ini.WriteString('Radio', 'RADIO ONE CONTROL PORT', 'SERIAL 5');
      ini.WriteString('Radio', 'RADIO TWO TYPE',         'K3');
      ini.WriteString('Radio', 'RADIO TWO CONTROL PORT', 'SERIAL 6');

      store.SeedFromLegacyIni(ini);

      CheckEquals(2, store.RadioCount, 'both slots survived');
      CheckTrue(store.FindRadio('K3') <> nil,     'first keeps the plain name');
      CheckTrue(store.FindRadio('K3 (2)') <> nil, 'second was deduped');

      prof := store.FindProfile('Default');
      CheckTrue(prof <> nil, 'profile created');
      if prof <> nil then
         begin
         CheckEquals('K3',     prof.Radio1Name, 'slot one reference');
         CheckEquals('K3 (2)', prof.Radio2Name, 'slot two points at the deduped name');
         end;
   finally
      store.Free;
      ini.Free;
   end;
end;

procedure TRadioConfigStoreTests.Test_LegacyIniHasRadiosDetectsFactoryOnlySlot;
var
   ini: TMemIniFile;
begin
   BeginTest('Test_LegacyIniHasRadiosDetectsFactoryOnlySlot');
   ini := NewTempIni;
   try
      CheckFalse(TRadioConfigStore.LegacyIniHasRadios(ini), 'an empty ini has none');

      ini.WriteString('Radio', 'RADIO ONE TYPE', 'NONE');
      CheckFalse(TRadioConfigStore.LegacyIniHasRadios(ini), 'TYPE=NONE is not a radio');

      // Slot TWO only -- the scan must not stop at slot one.
      ini.WriteString('Radio', 'RADIO TWO TYPE', 'TS590');
      CheckTrue(TRadioConfigStore.LegacyIniHasRadios(ini), 'slot two alone counts');
   finally
      ini.Free;
   end;
end;

{ ----------------------------------------------------------------- runner - }

procedure TRadioConfigStoreTests.Test_JSONRoundTripsEveryRadioField;
var
   store: TRadioConfigStore;
   root: TJSONObject;
   original: TRadioDefinition;
   err: string;
begin
   BeginTest('Test_JSONRoundTripsEveryRadioField');
   // The JSON counterpart of Test_RoundTripsEveryRadioField, and it exists for
   // the same reason: a field missing from either half of the persistence code
   // shows up here and nowhere else until a contest.  Both suites are kept --
   // the ini reader is still live for migrating a pre-F-5a store.
   original := MakeFullyPopulatedRadio('K4D');
   try
      store := TRadioConfigStore.Create;
      try
         CheckTrue(store.AddRadio(original.Clone, err), 'added: ' + err);
         root := store.SaveToJSON;
      finally
         store.Free;
      end;

      try
         store := TRadioConfigStore.Create;
         try
            store.LoadFromJSON(root);
            CheckEquals(1, store.RadioCount, 'one radio came back');
            CheckRadiosMatch(original, store.FindRadio('K4D'));
         finally
            store.Free;
         end;
      finally
         root.Free;
      end;
   finally
      original.Free;
   end;
end;

procedure TRadioConfigStoreTests.Test_JSONRoundTripsProfilesAndGeneral;
var
   store: TRadioConfigStore;
   root: TJSONObject;
   prof: TStationProfile;
   loaded: TStationProfile;
   err: string;
begin
   BeginTest('Test_JSONRoundTripsProfilesAndGeneral');
   store := TRadioConfigStore.Create;
   try
      CheckTrue(store.AddRadio(MakeFullyPopulatedRadio('A'), err), 'radio A: ' + err);
      CheckTrue(store.AddRadio(MakeFullyPopulatedRadio('B'), err), 'radio B: ' + err);

      prof := TStationProfile.Create;
      prof.Name              := 'Field Day';
      prof.Radio1Name        := 'A';
      prof.Radio2Name        := 'B';
      prof.DefaultActiveSlot := 2;
      prof.CWOutput1         := 'CAT';
      prof.CWOutput2         := 'NONE';
      CheckTrue(store.AddProfile(prof, err), 'profile: ' + err);

      store.ActiveProfileName    := 'Field Day';
      store.AutoConnectOnStartup := True;

      root := store.SaveToJSON;
   finally
      store.Free;
   end;

   try
      store := TRadioConfigStore.Create;
      try
         store.LoadFromJSON(root);
         CheckEquals(1, store.ProfileCount, 'one profile came back');
         loaded := store.FindProfile('Field Day');
         CheckTrue(loaded <> nil, 'profile found by name');
         CheckEquals('A',    loaded.Radio1Name,        'radio 1');
         CheckEquals('B',    loaded.Radio2Name,        'radio 2');
         CheckEquals(2,      loaded.DefaultActiveSlot, 'default slot');
         CheckEquals('CAT',  loaded.CWOutput1,         'cw output 1');
         CheckEquals('NONE', loaded.CWOutput2,         'cw output 2');
         // [General] travels too -- forgetting it would silently deactivate the
         // operator's profile on the next start.
         CheckEquals('Field Day', store.ActiveProfileName, 'active profile');
         CheckTrue(store.AutoConnectOnStartup, 'auto-connect');
      finally
         store.Free;
      end;
   finally
      root.Free;
   end;
end;

procedure TRadioConfigStoreTests.Test_JSONStoresTheSchemaVersion;
var
   store: TRadioConfigStore;
   root: TJSONObject;
   v: TJSONValue;
begin
   BeginTest('Test_JSONStoresTheSchemaVersion');
   // Pinned so that a shape change cannot ship without someone deciding what
   // the old version should do.  A store with no version is not something this
   // code will ever have written.
   store := TRadioConfigStore.Create;
   try
      root := store.SaveToJSON;
   finally
      store.Free;
   end;

   try
      v := root.GetValue('version');
      CheckTrue(v <> nil, 'a version is written');
      CheckTrue(v is TJSONNumber, 'the version is a number');
      CheckEquals(1, TJSONNumber(v).AsInt, 'schema version');
   finally
      root.Free;
   end;
end;

procedure TRadioConfigStoreTests.Test_JSONNameSurvivesIniHostileCharacters;
var
   store: TRadioConfigStore;
   root: TJSONObject;
   radio: TRadioDefinition;
   err: string;
   hostile: string;
begin
   BeginTest('Test_JSONNameSurvivesIniHostileCharacters');
   // THE REASON FOR THE MOVE, as a test.  The ini form encoded a radio's name
   // in its SECTION HEADER ('[Radio.K3]'), so a name containing ']' or '=' --
   // or with a leading space -- was at the mercy of the ini parser.  In JSON a
   // name is an ordinary value and none of that matters.
   // No LEADING/TRAILING space in the fixture: AddRadio trims deliberately
   // (a name with edge whitespace is its own trap), so testing for it here
   // would be asserting the store's normalisation, not JSON's fidelity.
   hostile := 'K3 [home] = main; "quoted"';

   radio := TRadioDefinition.Create;
   radio.Name       := hostile;
   radio.RegistryId := 'K3';

   store := TRadioConfigStore.Create;
   try
      CheckTrue(store.AddRadio(radio, err), 'added: ' + err);
      root := store.SaveToJSON;
   finally
      store.Free;
   end;

   try
      store := TRadioConfigStore.Create;
      try
         store.LoadFromJSON(root);
         CheckEquals(1, store.RadioCount, 'one radio came back');
         CheckEquals(hostile, store.Radio(0).Name, 'the name survived verbatim');
      finally
         store.Free;
      end;
   finally
      root.Free;
   end;
end;

procedure TRadioConfigStoreTests.Test_JSONLoadOfGarbageLeavesAnEmptyStore;
var
   store: TRadioConfigStore;
   fileName: string;
   err: string;
   ok: boolean;
begin
   BeginTest('Test_JSONLoadOfGarbageLeavesAnEmptyStore');
   // A corrupt settings file must not stop TR4W starting, and must not leave a
   // HALF-loaded library either -- a partial list is harder to diagnose than an
   // obviously empty one.  The failure has to be reported, though, or "my
   // radios vanished" becomes unanswerable.
   fileName := NewTempFileName('json');
   TFile.WriteAllText(fileName, '{ this is not json', TEncoding.UTF8);

   store := TRadioConfigStore.Create;
   try
      ok := store.LoadFromFile(fileName, err);
      CheckFalse(ok, 'a malformed file is reported as a failure');
      CheckTrue(err <> '', 'and the reason is given');
      CheckEquals(0, store.RadioCount, 'the store is empty, not half-loaded');
   finally
      store.Free;
   end;
end;

procedure TRadioConfigStoreTests.Test_JSONMissingFileIsReportedNotRaised;
var
   store: TRadioConfigStore;
   err: string;
begin
   BeginTest('Test_JSONMissingFileIsReportedNotRaised');
   // The first-run path depends on this: no file yet is an ordinary answer, so
   // the caller can fall through to migration or seeding.
   store := TRadioConfigStore.Create;
   try
      CheckFalse(store.LoadFromFile(NewTempFileName('json') + '.absent', err),
                 'absent file returns False');
      CheckTrue(err <> '', 'and says why');
      CheckEquals(0, store.RadioCount, 'store left empty');
   finally
      store.Free;
   end;
end;

procedure TRadioConfigStoreTests.Test_JSONFileRoundTripsThroughDisk;
var
   store: TRadioConfigStore;
   fileName: string;
   original: TRadioDefinition;
   err: string;
begin
   BeginTest('Test_JSONFileRoundTripsThroughDisk');
   // SaveToFile/LoadFromFile together, because that pair is what production
   // actually calls -- the in-memory tests above would still pass if the file
   // were written in the wrong encoding or never flushed.
   fileName := NewTempFileName('json');
   original := MakeFullyPopulatedRadio('IC-7610');
   try
      store := TRadioConfigStore.Create;
      try
         CheckTrue(store.AddRadio(original.Clone, err), 'added: ' + err);
         store.ActiveProfileName := 'Default';
         store.SaveToFile(fileName);
      finally
         store.Free;
      end;

      CheckTrue(FileExists(fileName), 'the file was written');

      store := TRadioConfigStore.Create;
      try
         CheckTrue(store.LoadFromFile(fileName, err), 'loaded: ' + err);
         CheckEquals(1, store.RadioCount, 'one radio came back');
         CheckRadiosMatch(original, store.FindRadio('IC-7610'));
         CheckEquals('Default', store.ActiveProfileName, 'active profile');
      finally
         store.Free;
      end;
   finally
      original.Free;
   end;
end;

procedure TRadioConfigStoreTests.Test_JSONFileHasNoBOM;
var
   store: TRadioConfigStore;
   fileName: string;
   bytes: TBytes;
begin
   BeginTest('Test_JSONFileHasNoBOM');
   // RFC 8259: a JSON text must not begin with a byte order mark.  Delphi's
   // TFile.WriteAllText emits the encoding's preamble, so the first version of
   // SaveToFile wrote one -- our own reader tolerated it and Python's json.load
   // rejected the file outright.  Pinned here because the symptom appears only
   // in some OTHER tool, which is exactly the kind of defect that survives.
   //
   // Opposite of the rule for src\lang\*.pas, which must KEEP their BOM.
   fileName := NewTempFileName('json');
   store := TRadioConfigStore.Create;
   try
      store.SaveToFile(fileName);
   finally
      store.Free;
   end;

   bytes := TFile.ReadAllBytes(fileName);
   CheckTrue(Length(bytes) >= 3, 'the file has content');
   CheckFalse((bytes[0] = $EF) and (bytes[1] = $BB) and (bytes[2] = $BF),
              'no UTF-8 BOM at the start of the JSON');
   CheckEquals(Ord('{'), bytes[0], 'the file starts with the opening brace');
end;

procedure TRadioConfigStoreTests.RunAllTests;
begin
   try
   Test_RoundTripsEveryRadioField;
   Test_RoundTripsProfiles;
   Test_SaveRemovesDeletedSections;
   Test_LoadOfEmptyFileYieldsEmptyStore;
   Test_PasswordRoundTripsAsPlaintext;

   Test_AddRejectsBlankAndDuplicateNames;
   Test_NameMatchingIsCaseInsensitive;
   Test_RenameFixesProfileReferences;
   Test_RenameToTakenNameRefused;
   Test_RenameToADifferentSpellingOfItselfAllowed;
   Test_DeleteReferencedRadioRefused;
   Test_DeleteUnreferencedRadioAllowed;
   Test_DeleteActiveProfileClearsActiveName;
   Test_UniqueRadioNameDedupes;

   Test_ValidateCatchesDanglingReference;
   Test_ValidateCatchesSameRadioInBothSlots;
   Test_ValidateCatchesSerialPortCollision;
   Test_ValidateAllowsNetworkRadiosSharingNothing;
   Test_ValidateCatchesMissingActiveProfile;

   Test_SeedFromLegacyIniBuildsBothSlots;
   Test_SeedSkipsUnconfiguredSlot;
   Test_SeedWithNoRadiosProducesEmptyStore;
   Test_SeedInfersNetworkTransport;
   Test_SeedInfersNetworkFromTcpIpControlPort;
   Test_NetworkRadioSurvivesRenderThenSeed;
   Test_SeedUsesFactoryIdAndLegacyNetworkNames;
   Test_SeedDedupesIdenticalSlotNames;

   Test_JSONRoundTripsEveryRadioField;
   Test_JSONRoundTripsProfilesAndGeneral;
   Test_JSONStoresTheSchemaVersion;
   Test_JSONNameSurvivesIniHostileCharacters;
   Test_JSONLoadOfGarbageLeavesAnEmptyStore;
   Test_JSONMissingFileIsReportedNotRaised;
   Test_JSONFileRoundTripsThroughDisk;
   Test_JSONFileHasNoBOM;
   Test_LegacyIniHasRadiosDetectsFactoryOnlySlot;
   finally
      // Even if a test escapes with an exception, the fixture files go.
      RemoveTempInis;
   end;
end;

end.
