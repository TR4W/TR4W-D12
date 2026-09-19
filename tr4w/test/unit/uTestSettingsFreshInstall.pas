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
      procedure Test_BuildingTheSettingsObjectDoesNotLeak;
   public
      procedure RunAllTests; override;
   end;

implementation

uses
   SysUtils, uJSON, uKeychain, uSettingsModel, uCFG,
   uRadioConfigStore, uRadioConfigApply, uTR4WConfigFile;

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
   Test_BuildingTheSettingsObjectDoesNotLeak;
end;

end.
