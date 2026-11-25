unit uTestSettingsFreshInstall;

(* WHAT A FRESH INSTALL WRITES, AND WHAT IT READS BACK.

  Five findings from an audit of settings\tr4w.json on a new station
  (2026-09-19), each pinned here against the shape of the defect:

    THE LOG LEVEL HAD TWO HOMES. TLogSettings.Create says DEBUG (NY4I,
    2026-09-14); the radio store's logging section defaulted to INFO and
    ApplyLoggingSettings pushed that over the settings object at every
    start, so a fresh install ran at INFO and saved INFO. The store's
    "absent" now means "no opinion".

    THE SETTINGS OBJECT LEAKED. TR4WSettings.Create built FContest twice,
    and the destructor never freed eleven of its groups.

    COMPUTER ID's "no id" went into the file as a NUL control character and
    read back only by accident; and Preferences could set an id but never
    clear one.

    MP3 RECORDER ENABLE, MP3 PATH and MP3 PLAYER had no reader and are
    retired -- and a file that still carries an "Mp3" object must load.

  THE GLOBAL Settings IS USED ONLY WHERE THE CODE UNDER TEST WRITES IT
  (ApplyLoggingSettings, CheckCommand), and is put back afterwards. Everything
  else builds its own TR4WSettings. *)

{$I ..\..\src\tr4w.inc}

interface

uses
   uTR4WTestFramework;

type
   TSettingsFreshInstallTests = class(TTestCase)
   protected
      procedure Test_AFreshSettingsObjectLogsAtDebug;
      procedure Test_AStoreWithNoLevelLeavesTheSettingAlone;
      procedure Test_AStoreWithALevelWins;
      procedure Test_AFreshStoreWritesNoLevel;
      procedure Test_TheEarlyLoggerReadsTheSameLevel;
      procedure Test_ANoComputerIdIsWrittenAsEmpty;
      procedure Test_AnEmptyComputerIdReadsAsNone;
      procedure Test_AComputerIdLetterRoundTrips;
      procedure Test_TheOldNulSpellingStillReadsAsNone;
      procedure Test_AComputerIdCanBeCleared;
      procedure Test_AnInvalidComputerIdIsStillRefused;
      procedure Test_TheCommandPathClearsTheComputerId;
      procedure Test_AFileWithTheOldMp3SectionStillLoads;
      procedure Test_TheMp3CommandsAreRetired;
      procedure Test_AFileWithTheOldRadioSectionStillLoads;
      procedure Test_TheRadioTcpServerPortIsRetired;
      procedure Test_AFileWithTheOldCountryAndSerialPortsMembersStillLoads;
      procedure Test_TheCountryInformationAndSerialPortsCommandsAreRetired;
      procedure Test_AFileWithTheOldRowCountMemberStillLoads;
      procedure Test_TheRowCountCommandIsRetired;
      procedure Test_TheWindowSizeCommandIsRetired;
      procedure Test_TheTailEndCommandsAreRetired;
      procedure Test_TheTwoNewEntrySettings;
      procedure Test_NoWSJTXOptionIsOnByDefault;
      procedure Test_AFileThatStatesWSJTXKeepsIt;
      procedure Test_BuildingTheSettingsObjectDoesNotLeak;
   public
      procedure RunAllTests; override;
   end;

implementation

uses
   SysUtils, uJSON, uKeychain, uSettingsModel, uCFG,
   uRadioConfigStore, uRadioConfigApply, uTR4WConfigFile,
   uBandmap;   (* SpotTuneFocusesExchange, issue 185 *)

(* The JSON escape for a NUL, built from two literals so that no editor or
  tool on the way to this file can turn the six characters into the byte. *)
function NulEscape: string;
begin
   Result := '\' + 'u0000';
end;

function ParseObject(const aText: string): TJSONObject;
begin
   Result := TJSONObject(TJSONObject.ParseJSONValue(aText));
end;

(* A store whose logging section EXISTS -- so ApplyLoggingSettings does not go
  looking for a tr4w.ini on the machine running the tests -- with or without
  a level. *)
function StoreWithLogging(const aLevelMember: string): TRadioConfigStore;
var
   root: TJSONObject;
begin
   root := ParseObject('{"version":1,"general":{},"radios":[],"profiles":[],' +
                       '"logging":{"hamlibDebug":false' + aLevelMember + '}}');
   try
      Result := TRadioConfigStore.Create;
      Result.LoadFromJSON(root);
   finally
      root.Free;
   end;
end;

function TempSettingsFile: string;
begin
   Result := IncludeTrailingPathDelimiter(GetTempDir) +
             Format('tr4w-freshinstall-%d.json', [Random(1000000000)]);
end;

procedure WriteText(const aFileName, aText: string);
var
   f: TextFile;
begin
   AssignFile(f, aFileName);
   Rewrite(f);
   try
      Write(f, aText);
   finally
      CloseFile(f);
   end;
end;

(* ---------------------------------------------------------------------
  THE LOG LEVEL: ONE HOME.
  --------------------------------------------------------------------- *)

procedure TSettingsFreshInstallTests.Test_AFreshSettingsObjectLogsAtDebug;
var
   s: TR4WSettings;
begin
   BeginTest('a fresh settings object logs at DEBUG (NY4I, 2026-09-14)');
   s := TR4WSettings.Create;
   try
      CheckTrue(s.Log.DebugLevel = llDebug, 'TLogSettings.Create says DEBUG');
   finally
      s.Free;
   end;
end;

procedure TSettingsFreshInstallTests.Test_AStoreWithNoLevelLeavesTheSettingAlone;
var
   store: TRadioConfigStore;
   saved: tLogLevels;
begin
   BeginTest('a store with no logging.level leaves Settings.Log.DebugLevel alone');
   saved := Settings.Log.DebugLevel;
   store := StoreWithLogging('');
   try
      CheckEquals('', store.LogLevelName, 'absent is "no opinion", not INFO');
      Settings.Log.DebugLevel := llDebug;
      ApplyLoggingSettings(store);
      CheckTrue(Settings.Log.DebugLevel = llDebug,
                'the settings object''s DEBUG survives the startup apply');
   finally
      store.Free;
      Settings.Log.DebugLevel := saved;
      UpdateDebugLogLevel;
   end;
end;

procedure TSettingsFreshInstallTests.Test_AStoreWithALevelWins;
var
   store: TRadioConfigStore;
   saved: tLogLevels;
begin
   BeginTest('an operator''s explicit logging.level is honoured');
   saved := Settings.Log.DebugLevel;
   store := StoreWithLogging(',"level":"TRACE"');
   try
      Settings.Log.DebugLevel := llDebug;
      ApplyLoggingSettings(store);
      CheckTrue(Settings.Log.DebugLevel = llTrace, 'TRACE was chosen, TRACE applies');
   finally
      store.Free;
      Settings.Log.DebugLevel := saved;
      UpdateDebugLogLevel;
   end;
end;

procedure TSettingsFreshInstallTests.Test_AFreshStoreWritesNoLevel;
var
   store: TRadioConfigStore;
   root: TJSONObject;
   logging: TJSONValue;
begin
   BeginTest('a store nobody chose a level in writes no logging.level');
   store := TRadioConfigStore.Create;
   try
      root := store.SaveToJSON;
      try
         logging := root.GetValue(JSONKEY_LOGGING);
         CheckTrue(logging is TJSONObject, 'the section is still written');
         CheckTrue(TJSONObject(logging).GetValue('level') = nil,
                   'but it claims no level nobody chose');
      finally
         root.Free;
      end;
   finally
      store.Free;
   end;
end;

procedure TSettingsFreshInstallTests.Test_TheEarlyLoggerReadsTheSameLevel;
var
   path: string;
begin
   BeginTest('StartupLogLevel resolves the precedence the program applies');
   path := TempSettingsFile;
   try
      WriteText(path, '{"general":{}}');
      CheckEquals('', StartupLogLevel(path),
                  'nothing stored: the settings object''s default stands');

      WriteText(path, '{"settings":{"Log":{"DebugLevel":"llInfo"}}}');
      CheckEquals('INFO', StartupLogLevel(path),
                  'the settings section is the level''s home');

      WriteText(path, '{"logging":{"level":"TRACE"},' +
                      '"settings":{"Log":{"DebugLevel":"llInfo"}}}');
      CheckEquals('TRACE', StartupLogLevel(path),
                  'an explicit store level is applied over it, so it wins here too');

      WriteText(path, '{"logging":{"hamlibDebug":false},' +
                      '"settings":{"Log":{"DebugLevel":"llWarn"}}}');
      CheckEquals('WARN', StartupLogLevel(path),
                  'a logging section with no level has no opinion');
   finally
      if FileExists(path) then
         begin
         DeleteFile(path);
         end;
   end;
end;

(* ---------------------------------------------------------------------
  COMPUTER ID: "" IN THE FILE, #0 IN THE PROGRAM.
  --------------------------------------------------------------------- *)

procedure TSettingsFreshInstallTests.Test_ANoComputerIdIsWrittenAsEmpty;
var
   s: TR4WSettings;
   obj: TJSONObject;
   id: TJSONValue;
begin
   BeginTest('#0 is written as "", not as a NUL control character');
   InstallTestKeychain;
   s := TR4WSettings.Create;
   try
      CheckTrue(s.Computer.Id = #0, 'the default is still "no id"');
      obj := s.ToJSON;
      try
         id := obj.FindPath('Computer.Id');
         CheckTrue(id <> nil, 'the member is written');
         CheckEquals('', id.AsString, 'as the empty string');
         CheckTrue(Pos(NulEscape, obj.AsJSON) = 0,
                   'and no NUL escape appears anywhere in the section');
      finally
         obj.Free;
      end;
   finally
      s.Free;
   end;
end;

procedure TSettingsFreshInstallTests.Test_AnEmptyComputerIdReadsAsNone;
var
   s: TR4WSettings;
   obj: TJSONObject;
begin
   BeginTest('"" reads as #0 -- deliberately, even over a letter already held');
   s := TR4WSettings.Create;
   try
      s.Computer.Id := 'B';
      obj := ParseObject('{"Computer":{"Id":""}}');
      try
         s.FromJSON(obj);
      finally
         obj.Free;
      end;
      CheckTrue(s.Computer.Id = #0, 'a file saying "no id" leaves no stale letter');
   finally
      s.Free;
   end;
end;

procedure TSettingsFreshInstallTests.Test_AComputerIdLetterRoundTrips;
var
   a, b: TR4WSettings;
   obj: TJSONObject;
begin
   BeginTest('a letter is written as itself and reads back as itself');
   InstallTestKeychain;
   a := TR4WSettings.Create;
   b := TR4WSettings.Create;
   try
      a.Computer.Id := 'B';
      obj := a.ToJSON;
      try
         CheckEquals('B', obj.FindPath('Computer.Id').AsString, 'written as "B"');
         b.FromJSON(obj);
      finally
         obj.Free;
      end;
      CheckTrue(b.Computer.Id = 'B', 'read back as ''B''');
   finally
      b.Free;
      a.Free;
   end;
end;

procedure TSettingsFreshInstallTests.Test_TheOldNulSpellingStillReadsAsNone;
var
   s: TR4WSettings;
   obj: TJSONObject;
begin
   BeginTest('a file an earlier build wrote -- the NUL escape -- reads as #0');
   s := TR4WSettings.Create;
   try
      s.Computer.Id := 'C';
      obj := ParseObject('{"Computer":{"Id":"' + NulEscape + '"}}');
      CheckTrue(obj <> nil, 'the fixture must parse');
      try
         s.FromJSON(obj);
      finally
         obj.Free;
      end;
      CheckTrue(s.Computer.Id = #0, 'the NUL escape means "no id"');
   finally
      s.Free;
   end;
end;

procedure TSettingsFreshInstallTests.Test_AComputerIdCanBeCleared;
var
   s: TR4WSettings;
   value: string;
begin
   BeginTest('COMPUTER ID can be cleared by name, as D7''s Ctrl-J could');
   s := TR4WSettings.Create;
   try
      CheckTrue(s.TrySetByCommand('COMPUTER ID', 'D'), 'a letter is accepted');
      CheckTrue(s.Computer.Id = 'D', 'and applied');

      CheckTrue(s.TrySetByCommand('COMPUTER ID', ''), 'empty is accepted');
      CheckTrue(s.Computer.Id = #0, 'and means "no id"');

      CheckTrue(s.TryGetByCommand('COMPUTER ID', value), 'it reads back');
      CheckEquals('', value, 'as the empty string, never a NUL');

      s.Computer.Id := 'E';
      CheckTrue(s.TrySetByCommand('COMPUTER ID', '  '), 'blanks are empty too');
      CheckTrue(s.Computer.Id = #0, 'not the letter '' ''');
   finally
      s.Free;
   end;
end;

procedure TSettingsFreshInstallTests.Test_AnInvalidComputerIdIsStillRefused;
var
   s: TR4WSettings;
begin
   BeginTest('anything but "" or one A..Z letter is still refused');
   s := TR4WSettings.Create;
   try
      s.Computer.Id := 'F';
      CheckFalse(s.TrySetByCommand('COMPUTER ID', '1'),  'a digit');
      CheckFalse(s.TrySetByCommand('COMPUTER ID', 'AB'), 'two letters');
      CheckFalse(s.TrySetByCommand('COMPUTER ID', 'b'),  'lower case');
      CheckTrue(s.Computer.Id = 'F', 'and a refusal leaves the id alone');

      (* The other character settings have no check, so empty is still not
        a value for them. *)
      CheckFalse(s.TrySetByCommand('START SENDING NOW KEY', ''),
                 'a character setting without a check still refuses empty');
   finally
      s.Free;
   end;
end;

procedure TSettingsFreshInstallTests.Test_TheCommandPathClearsTheComputerId;
var
   saved: AnsiChar;
begin
   (* The path Preferences takes: ApplyIfChanged -> ApplyAndStoreCommand ->
     CheckCommand with aApplyJSONOwned. *)
   BeginTest('CheckCommand, the Preferences path, clears the id');
   saved := Settings.Computer.Id;
   try
      Settings.Computer.Id := 'G';
      CheckTrue(CheckCommand('COMPUTER ID', '', True), 'accepted');
      CheckTrue(Settings.Computer.Id = #0, 'cleared');
      CheckFalse(CheckCommand('COMPUTER ID', '7', True), 'a digit still refused');
      CheckTrue(Settings.Computer.Id = #0, 'and left alone');
   finally
      Settings.Computer.Id := saved;
   end;
end;

(* ---------------------------------------------------------------------
  THE MP3 SETTINGS ARE RETIRED.
  --------------------------------------------------------------------- *)

procedure TSettingsFreshInstallTests.Test_AFileWithTheOldMp3SectionStillLoads;
var
   s: TR4WSettings;
   obj: TJSONObject;
   written: TJSONObject;
begin
   BeginTest('a tr4w.json that still carries "Mp3" loads, and is not re-written with it');
   InstallTestKeychain;
   s := TR4WSettings.Create;
   try
      obj := ParseObject('{"Mp3":{"RecorderEnable":true,"Path":"C:\\mp3",' +
                         '"Player":""},"Computer":{"Id":"H"}}');
      CheckTrue(obj <> nil, 'the fixture must parse');
      try
         s.FromJSON(obj);
      finally
         obj.Free;
      end;
      CheckTrue(s.Computer.Id = 'H', 'the rest of the section loaded');

      written := s.ToJSON;
      try
         CheckTrue(written.FindPath('Mp3') = nil, 'the retired group is not written');
      finally
         written.Free;
      end;
   finally
      s.Free;
   end;
end;

procedure TSettingsFreshInstallTests.Test_TheMp3CommandsAreRetired;
begin
   BeginTest('the three MP3 names are withdrawn: accepted, and owned by nothing');
   CheckTrue(CommandIsRetired('MP3 RECORDER ENABLE'), 'MP3 RECORDER ENABLE');
   CheckTrue(CommandIsRetired('MP3 PATH'),            'MP3 PATH');
   CheckTrue(CommandIsRetired('MP3 PLAYER'),          'MP3 PLAYER');
   CheckFalse(Settings.OwnsCommand('MP3 RECORDER ENABLE'), 'no property answers to it');
   CheckFalse(Settings.OwnsCommand('MP3 PATH'),            'nor to this');
   CheckFalse(Settings.OwnsCommand('MP3 PLAYER'),          'nor to this');
   (* ACCEPTED, so an old ini line does not raise LogCfg's modal "invalid
     statement in config file". *)
   CheckTrue(CheckCommand('MP3 PATH', 'C:\MP3', False), 'an old line is accepted');
end;

(* ---------------------------------------------------------------------
  RADIO TCP SERVER PORT IS RETIRED (2026-11-01, NY4I).

  Settings.Radio.TcpServerPort named a TCP server TR4W would run for radio
  clients, and nothing read it -- here or in D7. The whole Radio group went
  with it, so a file written before today carries a "Radio" object that no
  property owns. Same shape as the Mp3 pair above.
  --------------------------------------------------------------------- *)

procedure TSettingsFreshInstallTests.Test_AFileWithTheOldRadioSectionStillLoads;
var
   s: TR4WSettings;
   obj: TJSONObject;
   written: TJSONObject;
begin
   BeginTest('a tr4w.json that still carries "Radio" loads, and is not re-written with it');
   InstallTestKeychain;
   s := TR4WSettings.Create;
   try
      obj := ParseObject('{"Radio":{"TcpServerPort":52002},"Computer":{"Id":"H"}}');
      CheckTrue(obj <> nil, 'the fixture must parse');
      try
         s.FromJSON(obj);
      finally
         obj.Free;
      end;
      CheckTrue(s.Computer.Id = 'H', 'the rest of the section loaded');

      written := s.ToJSON;
      try
         CheckTrue(written.FindPath('Radio') = nil, 'the retired group is not written');
      finally
         written.Free;
      end;
   finally
      s.Free;
   end;
end;

procedure TSettingsFreshInstallTests.Test_TheRadioTcpServerPortIsRetired;
begin
   BeginTest('RADIO TCP SERVER PORT is withdrawn: accepted, and owned by nothing');
   CheckTrue(CommandIsRetired('RADIO TCP SERVER PORT'), 'RADIO TCP SERVER PORT');
   CheckFalse(Settings.OwnsCommand('RADIO TCP SERVER PORT'), 'no property answers to it');
   (* ACCEPTED, so an old .cfg or a peer naming it does not raise LogCfg's
     modal "invalid statement in config file". *)
   CheckTrue(CheckCommand('RADIO TCP SERVER PORT', '52002', False),
             'an old line is accepted');
end;

(* ---------------------------------------------------------------------
  COUNTRY INFORMATION FILE AND SHOW ALL SERIAL PORTS ARE RETIRED
  (2026-11-21, NY4I).

  Neither had a reader, here or in D7. Settings.SerialPorts was a group of
  one, so it went whole; Settings.Country keeps UpdateCheckOnStartup and lost
  only InformationFile. So a file written before today carries a whole
  object no property owns AND one member inside a live group -- both shapes,
  in one fixture.
  --------------------------------------------------------------------- *)

procedure TSettingsFreshInstallTests.Test_AFileWithTheOldCountryAndSerialPortsMembersStillLoads;
var
   s: TR4WSettings;
   obj: TJSONObject;
   written: TJSONObject;
begin
   BeginTest('a tr4w.json that still carries SerialPorts and Country.InformationFile loads');
   InstallTestKeychain;
   s := TR4WSettings.Create;
   try
      obj := ParseObject('{"SerialPorts":{"ShowAll":true},'
                         + '"Country":{"InformationFile":"x.txt","UpdateCheckOnStartup":false},'
                         + '"Computer":{"Id":"H"}}');
      CheckTrue(obj <> nil, 'the fixture must parse');
      try
         s.FromJSON(obj);
      finally
         obj.Free;
      end;
      CheckTrue(s.Computer.Id = 'H', 'the rest of the section loaded');
      CheckFalse(s.Country.UpdateCheckOnStartup,
                 'the surviving member of the Country group loaded');

      written := s.ToJSON;
      try
         CheckTrue(written.FindPath('SerialPorts') = nil, 'the retired group is not written');
         CheckTrue(written.FindPath('Country') <> nil, 'the Country group still is');
         CheckTrue(written.FindPath('Country.InformationFile') = nil,
                   'but without the retired member');
      finally
         written.Free;
      end;
   finally
      s.Free;
   end;
end;

procedure TSettingsFreshInstallTests.Test_TheCountryInformationAndSerialPortsCommandsAreRetired;
begin
   BeginTest('COUNTRY INFORMATION FILE and SHOW ALL SERIAL PORTS are withdrawn: accepted, owned by nothing');
   CheckTrue(CommandIsRetired('COUNTRY INFORMATION FILE'), 'COUNTRY INFORMATION FILE');
   CheckTrue(CommandIsRetired('SHOW ALL SERIAL PORTS'),    'SHOW ALL SERIAL PORTS');
   CheckFalse(Settings.OwnsCommand('COUNTRY INFORMATION FILE'), 'no property answers to it');
   CheckFalse(Settings.OwnsCommand('SHOW ALL SERIAL PORTS'),    'nor to this');
   (* ACCEPTED, so an old .cfg line does not raise LogCfg's modal "invalid
     statement in config file". *)
   CheckTrue(CheckCommand('COUNTRY INFORMATION FILE', 'CTYINFO.TXT', False),
             'an old line is accepted');
   CheckTrue(CheckCommand('SHOW ALL SERIAL PORTS', 'TRUE', False),
             'and so is this one');
end;

(* ---------------------------------------------------------------------
  ROW COUNT IS RETIRED (2026-11-21, NY4I).

  Settings.MainWindow.RowCount had become only the log pane's starting
  height; the main window's height decides it now. MainWindow is a live
  group, so an old file carries one member no property owns inside a group
  that still loads -- and ShowGridlines, its neighbour, must still arrive.

  WINDOW SIZE IS RETIRED TOO (2026-11-21, plan stage e6): the main window's
  text scale follows its width and is saved with the window layout, so
  MainWindow.WindowSize is a second member no property owns. The same
  fixture carries both.
  --------------------------------------------------------------------- *)

procedure TSettingsFreshInstallTests.Test_AFileWithTheOldRowCountMemberStillLoads;
var
   s: TR4WSettings;
   obj: TJSONObject;
   written: TJSONObject;
begin
   BeginTest('a tr4w.json that still carries MainWindow.RowCount and WindowSize loads');
   InstallTestKeychain;
   s := TR4WSettings.Create;
   try
      obj := ParseObject('{"MainWindow":{"RowCount":12,"WindowSize":9,'
                         + '"ShowGridlines":true},'
                         + '"Computer":{"Id":"H"}}');
      CheckTrue(obj <> nil, 'the fixture must parse');
      try
         s.FromJSON(obj);
      finally
         obj.Free;
      end;
      CheckTrue(s.Computer.Id = 'H', 'the rest of the file loaded');
      CheckTrue(s.MainWindow.ShowGridlines,
                'the surviving member of the MainWindow group loaded');

      written := s.ToJSON;
      try
         CheckTrue(written.FindPath('MainWindow') <> nil, 'the MainWindow group is still written');
         CheckTrue(written.FindPath('MainWindow.RowCount') = nil,
                   'but without the retired RowCount');
         CheckTrue(written.FindPath('MainWindow.WindowSize') = nil,
                   'and without the retired WindowSize');
      finally
         written.Free;
      end;
   finally
      s.Free;
   end;
end;

procedure TSettingsFreshInstallTests.Test_TheRowCountCommandIsRetired;
begin
   BeginTest('ROW COUNT is withdrawn: accepted, owned by nothing');
   CheckTrue(CommandIsRetired('ROW COUNT'), 'ROW COUNT');
   CheckFalse(Settings.OwnsCommand('ROW COUNT'), 'no property answers to it');
   (* ACCEPTED, so an old .cfg line does not raise LogCfg's modal "invalid
     statement in config file". *)
   CheckTrue(CheckCommand('ROW COUNT', '12', False), 'an old line is accepted');
end;

procedure TSettingsFreshInstallTests.Test_TheWindowSizeCommandIsRetired;
begin
   BeginTest('WINDOW SIZE is withdrawn: accepted, owned by nothing');
   CheckTrue(CommandIsRetired('WINDOW SIZE'), 'WINDOW SIZE');
   CheckFalse(Settings.OwnsCommand('WINDOW SIZE'), 'no property answers to it');
   (* ACCEPTED, so an old .cfg line -- or the corpus fixture's bucket entry --
     does not raise LogCfg's modal "invalid statement in config file". *)
   CheckTrue(CheckCommand('WINDOW SIZE', '10', False), 'an old line is accepted');
end;

(* ISSUE 60: the four TAIL END names, withdrawn 2026-11-22. Before this
  CheckCommand REFUSED them (their CFGCA rows were commented out), so the
  corpus's Winter Field Day .cfg line "TAIL END CW MESSAGE=TU \" took the
  invalid-statement path. *)
procedure TSettingsFreshInstallTests.Test_TheTailEndCommandsAreRetired;
const
   NAMES: array[0..3] of string = ('TAIL END CW MESSAGE', 'TAIL END KEY',
      'TAIL END MESSAGE', 'TAIL END SSB MESSAGE');
   VALUES: array[0..3] of string = ('TU \', ']', 'R', 'TAILEND.WAV');
var
   i: integer;
begin
   BeginTest('the TAIL END names are withdrawn: accepted, owned by nothing');
   for i := Low(NAMES) to High(NAMES) do
      begin
      CheckTrue(CommandIsRetired(NAMES[i]), NAMES[i] + ' is retired');
      CheckFalse(Settings.OwnsCommand(NAMES[i]), NAMES[i] + ': no property answers to it');
      CheckFalse(CommandIsSharedWithPeers(NAMES[i]), NAMES[i] + ' is not shared');
      CheckTrue(CheckCommand(NAMES[i], VALUES[i], False), NAMES[i] + ': an old line is accepted');
      end;
end;

(* ISSUES 180 AND 185: two new station settings, both OFF by default (so the
  default changes no QSO and no focus), set by name, and written and read
  back by the settings file. *)
procedure TSettingsFreshInstallTests.Test_TheTwoNewEntrySettings;
var
   a, b: TR4WSettings;
   obj: TJSONObject;
   value: string;
begin
   BeginTest('ENFORCE VALID CALLSIGN and BAND MAP CLICK GOES TO EXCHANGE');
   InstallTestKeychain;
   a := TR4WSettings.Create;
   b := TR4WSettings.Create;
   try
      CheckFalse(a.CallWindow.EnforceValidCallsign, 'ENFORCE VALID CALLSIGN defaults off');
      CheckFalse(a.BandMap.ClickGoesToExchange, 'BAND MAP CLICK GOES TO EXCHANGE defaults off');
      CheckTrue(a.OwnsCommand('ENFORCE VALID CALLSIGN'), 'ENFORCE VALID CALLSIGN is a setting');
      CheckFalse(a.OwnsCommand('CALL WINDOW ENFORCE VALID CALLSIGN'), 'the derived name is aliased away');
      CheckTrue(a.OwnsCommand('BAND MAP CLICK GOES TO EXCHANGE'), 'BAND MAP CLICK GOES TO EXCHANGE is a setting');
      CheckFalse(CommandIsSharedWithPeers('ENFORCE VALID CALLSIGN'), 'not shared: an operator preference');
      CheckFalse(CommandIsSharedWithPeers('BAND MAP CLICK GOES TO EXCHANGE'), 'not shared: an operator preference');

      CheckTrue(a.TrySetByCommand('ENFORCE VALID CALLSIGN', 'TRUE'), 'set by name');
      CheckTrue(a.TrySetByCommand('BAND MAP CLICK GOES TO EXCHANGE', 'TRUE'), 'set by name');
      CheckTrue(a.CallWindow.EnforceValidCallsign, 'the property took it');
      CheckTrue(a.BandMap.ClickGoesToExchange, 'the property took it');
      CheckTrue(a.TryGetByCommand('ENFORCE VALID CALLSIGN', value), 'read by name');
      CheckTrue(UnicodeSameText('TRUE', value), 'reads TRUE (got ' + value + ')');

      obj := a.ToJSON;
      try
         CheckTrue(obj.FindPath('CallWindow.EnforceValidCallsign') <> nil, 'written to the settings file');
         CheckTrue(obj.FindPath('BandMap.ClickGoesToExchange') <> nil, 'written to the settings file');
         b.FromJSON(obj);
      finally
         obj.Free;
      end;
      CheckTrue(b.CallWindow.EnforceValidCallsign, 'ENFORCE VALID CALLSIGN read back');
      CheckTrue(b.BandMap.ClickGoesToExchange, 'BAND MAP CLICK GOES TO EXCHANGE read back');
   finally
      b.Free;
      a.Free;
   end;

   (* uBandmap's pure decision: the exchange only with the option on AND the
     call placed in the call window. *)
   CheckFalse(SpotTuneFocusesExchange(False, True), 'off: the call window, as D7');
   CheckFalse(SpotTuneFocusesExchange(True, False), 'on, but no call placed (a CQ/NEW marker, the inactive radio): the call window');
   CheckTrue(SpotTuneFocusesExchange(True, True), 'on and the call placed: the exchange window');
   CheckFalse(SpotTuneFocusesExchange(False, False), 'off and nothing placed');
end;

(* ---------------------------------------------------------------------
  NO WSJT-X OPTION IS ON BY DEFAULT (NY4I, 2026-11-25): most operators never
  use WSJT-X. Enabled and SendHighlights defaulted TRUE until then. The port
  and the listen address are values, not options, and keep theirs.
  --------------------------------------------------------------------- *)

procedure TSettingsFreshInstallTests.Test_NoWSJTXOptionIsOnByDefault;
var
   s: TR4WSettings;
begin
   BeginTest('a fresh settings object has every WSJT-X option off');
   s := TR4WSettings.Create;
   try
      CheckFalse(s.Wsjtx.Enabled, 'WSJT-X ENABLED defaults off');
      CheckFalse(s.Wsjtx.SendHighlights, 'WSJT-X SEND HIGHLIGHTS defaults off');
      CheckFalse(s.Wsjtx.RadioControlEnabled, 'WSJT-X RADIO CONTROL ENABLED defaults off');
      CheckFalse(s.Wsjtx.N1mmListenerEnabled, 'ENABLE N1MM LOG LISTENER defaults off');
      CheckEquals(2237, s.Wsjtx.BroadcastPort, 'the port keeps WSJT-X''s own default');
      CheckEquals('', s.Wsjtx.MulticastGroup, 'no multicast group');
   finally
      s.Free;
   end;
end;

(* AN EXISTING FILE KEEPS WHAT IT STATES. The whole settings object is written
  at exit, so a file any 5.x build wrote carries Wsjtx.Enabled and
  Wsjtx.SendHighlights, and a file that said true still says true. A file
  that predates the keys (or has no Wsjtx section) reads the new default:
  off. *)
procedure TSettingsFreshInstallTests.Test_AFileThatStatesWSJTXKeepsIt;
var
   s: TR4WSettings;
   obj: TJSONObject;
begin
   BeginTest('a tr4w.json that states WSJT-X keeps it; one that does not reads off');
   InstallTestKeychain;
   s := TR4WSettings.Create;
   try
      obj := ParseObject('{"Wsjtx":{"Enabled":true,"SendHighlights":true},' +
                         '"Computer":{"Id":"H"}}');
      CheckTrue(obj <> nil, 'the fixture must parse');
      try
         s.FromJSON(obj);
      finally
         obj.Free;
      end;
      CheckTrue(s.Wsjtx.Enabled, 'a stated Enabled true stays true');
      CheckTrue(s.Wsjtx.SendHighlights, 'a stated SendHighlights true stays true');
   finally
      s.Free;
   end;

   s := TR4WSettings.Create;
   try
      obj := ParseObject('{"Computer":{"Id":"H"}}');
      CheckTrue(obj <> nil, 'the fixture must parse');
      try
         s.FromJSON(obj);
      finally
         obj.Free;
      end;
      CheckTrue(s.Computer.Id = 'H', 'the rest of the file loaded');
      CheckFalse(s.Wsjtx.Enabled, 'no Wsjtx section: off');
      CheckFalse(s.Wsjtx.SendHighlights, 'no Wsjtx section: highlights off');
   finally
      s.Free;
   end;
end;

(* ---------------------------------------------------------------------
  THE SETTINGS OBJECT FREES WHAT IT BUILDS.
  --------------------------------------------------------------------- *)

procedure TSettingsFreshInstallTests.Test_BuildingTheSettingsObjectDoesNotLeak;
const
   BUILDS = 50;
   (* Twelve groups a build leaked before the fix -- a few KB per build, so
     well over 100 KB across BUILDS. A correct destructor returns to the same
     heap level; the slack only absorbs allocator bookkeeping. *)
   SLACK_BYTES = 4096;
var
   i: integer;
   before, after: PtrUInt;
begin
   BeginTest('building and freeing the settings object returns the heap');
   TR4WSettings.Create.Free;   // warm-up: any one-time registration is paid here
   before := GetFPCHeapStatus.CurrHeapUsed;
   for i := 1 to BUILDS do
      begin
      TR4WSettings.Create.Free;
      end;
   after := GetFPCHeapStatus.CurrHeapUsed;
   CheckTrue(after <= before + SLACK_BYTES,
             Format('heap grew %d bytes over %d builds',
                    [Int64(after) - Int64(before), BUILDS]));
end;

procedure TSettingsFreshInstallTests.RunAllTests;
begin
   Randomize;
   Test_AFreshSettingsObjectLogsAtDebug;
   Test_AStoreWithNoLevelLeavesTheSettingAlone;
   Test_AStoreWithALevelWins;
   Test_AFreshStoreWritesNoLevel;
   Test_TheEarlyLoggerReadsTheSameLevel;
   Test_ANoComputerIdIsWrittenAsEmpty;
   Test_AnEmptyComputerIdReadsAsNone;
   Test_AComputerIdLetterRoundTrips;
   Test_TheOldNulSpellingStillReadsAsNone;
   Test_AComputerIdCanBeCleared;
   Test_AnInvalidComputerIdIsStillRefused;
   Test_TheCommandPathClearsTheComputerId;
   Test_AFileWithTheOldMp3SectionStillLoads;
   Test_TheMp3CommandsAreRetired;
   Test_AFileWithTheOldRadioSectionStillLoads;
   Test_TheRadioTcpServerPortIsRetired;
   Test_AFileWithTheOldCountryAndSerialPortsMembersStillLoads;
   Test_TheCountryInformationAndSerialPortsCommandsAreRetired;
   Test_AFileWithTheOldRowCountMemberStillLoads;
   Test_TheRowCountCommandIsRetired;
   Test_TheWindowSizeCommandIsRetired;
   Test_TheTailEndCommandsAreRetired;
   Test_TheTwoNewEntrySettings;
   Test_NoWSJTXOptionIsOnByDefault;
   Test_AFileThatStatesWSJTXKeepsIt;
   Test_BuildingTheSettingsObjectDoesNotLeak;
end;

end.
