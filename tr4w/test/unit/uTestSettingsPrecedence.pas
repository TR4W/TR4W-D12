(*
 Copyright Thomas M. Schaefer, NY4I (c) 2026.

 This file is part of TR4W  (SRC)

 TR4W is free software: you can redistribute it and/or
 modify it under the terms of the GNU General Public License as
 published by the Free Software Foundation, either version 2 of the
 License, or (at your option) any later version.

 TR4W is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General
     Public License along with TR4W in  GPL_License.TXT.
If not, ref:
http://www.gnu.org/licenses/gpl-3.0.txt
 *)
unit uTestSettingsPrecedence;
{$I ..\..\src\tr4w.inc}

(*
  ONE HOME PER SETTING -- the startup precedence defect, pinned.

  ------------------------------------------------------------------------
  WHAT WAS WRONG
  ------------------------------------------------------------------------

  A setting the settings object owns could ALSO sit in the radio store's
  legacy `commands` bucket, and the bucket won: ApplyStoredCommands re-applies
  the whole of it at every start, AFTER LoadSettingsForStartup has run. Two
  homes, and the wrong one in force.

  MEASURED ON NY4I'S STATION, 2026-09-19: 229 entries in the bucket against a
  settings section holding a single group, and 231 of the 247 names the
  importer seeds are names the settings object owns.

  THE SYMPTOM HE WOULD ACTUALLY HIT: clearing COMPUTER ID did not survive a
  restart. Preferences wrote it through ApplyAndStoreCommand, which put it in
  the bucket and not in the settings section; clearing it deleted the bucket
  entry (TStrings.Values[k] := '' removes the entry outright), the settings
  section still held the old letter, and nothing overrode it.

  ------------------------------------------------------------------------
  WHAT THESE TESTS COVER, AND WHAT THEY CANNOT
  ------------------------------------------------------------------------

  The DECISION lives in two places a unit test can reach: the order
  LoadSettingsForStartup applies its two sources, and what
  CollapseLegacySettingHomes then removes from the file. Both are here.

  ApplyStoredCommands and ApplyAndStoreCommand are in uRadioConfigApply, which
  the unit-test binary does not link -- it needs MainUnit's globals. What is
  asserted instead is the FILE INVARIANT those two now maintain: after the
  collapse there is no settings-owned name left in the bucket, so there is
  nothing for ApplyStoredCommands to re-apply. The golden corpus is the other
  check, because COMPUTER ID decides the Cabrillo TRANSMITTER DIGIT.

  Every fixture is built in the test's own temporary directory, so these run
  on a machine that has never had TR4W installed.
*)

interface

uses
   uTR4WTestFramework;

type
   TSettingsPrecedenceTests = class(TTestCase)
   private
      procedure Test_TheSettingsSectionBeatsTheLegacyBucket;
      procedure Test_ALegacyOnlyValueIsNotLostOnUpgrade;
      procedure Test_TheExportPathDoesNotImportTheBucket;
      procedure Test_TheCollapseRemovesOnlyTheSecondHome;
      procedure Test_TheCollapseIsIdempotent;
      procedure Test_ClearingComputerIdSurvivesARestart;
      procedure Test_DisplayLanguageIsStationOnly;
      procedure Test_StartupMainCallsignReadsTheFile;
      procedure Test_ALegacyIniIsNotAStartupSource;
      procedure Test_AnInertOrAbsentIniChangesNothing;
   public
      procedure RunAllTests; override;
   end;

implementation

uses
   SysUtils, Classes,
   uJSON, fpjson,
   uSettingsModel,
   uTR4WConfigFile;


function TempDirFor(const aWhat: string): string;
begin
   Result := IncludeTrailingPathDelimiter(GetTempDir)
             + 'tr4wprec_' + aWhat + PathDelim;
   ForceDirectories(Result);
end;


(* A settings file in the shape the store actually writes: the legacy commands
  NESTED under a category, and a settings section that carries only what the
  caller asked for. aSettingsBody and aCommandsBody are raw JSON members. *)
function WriteFixture(const aDir: string;
                      const aSettingsBody, aCommandsBody: string): string;
var
   f: TStringList;
begin
   Result := IncludeTrailingPathDelimiter(aDir) + 'tr4w.json';
   f := TStringList.Create;
   try
      f.Add('{');
      f.Add('   "version" : 1,');
      f.Add('   "settings" : {');
      f.Add(aSettingsBody);
      f.Add('   },');
      f.Add('   "commands" : {');
      f.Add(aCommandsBody);
      f.Add('   }');
      f.Add('}');
      f.SaveToFile(Result);
   finally
      f.Free;
   end;
end;


(* The value of one legacy command as the FILE now stands, or a marker when the
  bucket no longer carries it. Read through the same flattener the program
  uses, so a nested entry is found. *)
const
   NOT_IN_BUCKET = '<absent>';

function BucketValue(const aFileName, aCommand: string): string;
var
   text: TStringList;
   root: TJSONValue;
   commands: TJSONValue;
   legacy: TStringList;
begin
   Result := NOT_IN_BUCKET;
   text := TStringList.Create;
   legacy := TStringList.Create;
   try
      text.LoadFromFile(aFileName);
      root := GetJSON(AnsiString(text.Text));
      if not (root is TJSONObject) then
         begin
         Exit;
         end;
      try
         commands := TJSONObject(root).FindValue('commands');
         if not (commands is TJSONObject) then
            begin
            Exit;
            end;
         FlattenLegacyCommands(TJSONObject(commands), legacy);
         if legacy.IndexOfName(AnsiString(aCommand)) >= 0 then
            begin
            Result := string(legacy.Values[AnsiString(aCommand)]);
            end;
      finally
         root.Free;
      end;
   finally
      legacy.Free;
      text.Free;
   end;
end;


(* ---------------------------------------------------------------------
  THE PRECEDENCE ITSELF.

  FAILS AGAINST THE OLD CODE, and for a reason worth stating: the old
  LoadSettingsForStartup imported the bucket ONLY when the settings section
  was absent, and used FindPath, which cannot see a nested entry. So on a file
  with both homes it read the section and ignored the bucket -- which looks
  like the right answer HERE, and was undone a few dozen lines later in
  uProgramMain when ApplyStoredCommands re-applied the bucket.

  What this pins is that the import cannot reverse it: the bucket goes on
  FIRST, so nothing it carries can overwrite a value the section states.
  --------------------------------------------------------------------- *)
procedure TSettingsPrecedenceTests.Test_TheSettingsSectionBeatsTheLegacyBucket;
var
   dir, file_: string;
   s: TR4WSettings;
   value: string;
begin
   BeginTest('Test_TheSettingsSectionBeatsTheLegacyBucket');
   dir := TempDirFor('bothhomes');
   file_ := WriteFixture(dir,
      '      "My" : { "Name" : "FROM SETTINGS" }',
      '      "other" : { "MY NAME" : "FROM COMMANDS" }');

   s := TR4WSettings.Create;
   try
      CheckTrue(LoadSettingsForStartup(file_, s),
                'the file carried a settings section');
      CheckTrue(s.TryGetByCommand('MY NAME', value), 'MY NAME reads back');
      CheckEquals('FROM SETTINGS', value,
                  'the settings section is the home and wins over the bucket');
   finally
      s.Free;
   end;
end;


(* ---------------------------------------------------------------------
  THE UPGRADE CASE, AND IT IS THE ONE THAT COULD LOSE DATA.

  A station whose ONLY home for a value is the bucket -- which is every
  station in the field, NY4I's included -- must still have that value after
  the change. Nothing may be dropped on the way to one home.

  FAILS AGAINST THE OLD CODE: the section is present, so the old import did
  not run at all, and the value reached the object only later through
  ApplyStoredCommands. Remove that reader without this and the setting
  silently reverts to its compiled default.
  --------------------------------------------------------------------- *)
procedure TSettingsPrecedenceTests.Test_ALegacyOnlyValueIsNotLostOnUpgrade;
var
   dir, file_: string;
   s: TR4WSettings;
   value: string;
begin
   BeginTest('Test_ALegacyOnlyValueIsNotLostOnUpgrade');
   dir := TempDirFor('upgrade');
   file_ := WriteFixture(dir,
      '      "ExternalLogger" : { "Port" : 52001 }',
      '      "other" : { "MY GRID" : "EL88", "COMPUTER ID" : "A" }');

   s := TR4WSettings.Create;
   try
      LoadSettingsForStartup(file_, s);

      CheckTrue(s.TryGetByCommand('MY GRID', value), 'MY GRID reads back');
      CheckEquals('EL88', value,
                  'a nested bucket-only value survives -- no silent loss');

      CheckTrue(s.TryGetByCommand('COMPUTER ID', value), 'COMPUTER ID reads back');
      CheckEquals('A', value, 'and so does the one NY4I will try');
   finally
      s.Free;
   end;
end;


(* ---------------------------------------------------------------------
  AND THE ONE CALLER THAT MUST NOT IMPORT: THE HEADLESS /EXPORT.

  THIS TEST EXISTS BECAUSE THE FIRST VERSION OF THE CHANGE BROKE THE CORPUS,
  22/2 against 24/0, within the hour. The bucket is the STATION'S settings as
  they stand today; an export must be configured the way the LOG is. The IARU
  sent exchange is reconstructed from station state at export time, so the
  corpus fixture's MY STATE = FL displaced its MY ITU ZONE = 8 and every QSO
  exported "59 FL" against a frozen D7 reference of "59 8".

  It is the same rule, and the same measured reason, that keeps
  ApplyStoredCommands out of /EXPORT -- 21/1/4 to 8/14/4.

  The fixture below is deliberately that exact pair.
  --------------------------------------------------------------------- *)
procedure TSettingsPrecedenceTests.Test_TheExportPathDoesNotImportTheBucket;
var
   dir, file_: string;
   s: TR4WSettings;
   value: string;
begin
   BeginTest('Test_TheExportPathDoesNotImportTheBucket');
   dir := TempDirFor('export');
   file_ := WriteFixture(dir,
      '      "ExternalLogger" : { "Port" : 52001 }',
      '      "other" : { "MY STATE" : "FL", "MY ITU ZONE" : "8" }');

   s := TR4WSettings.Create;
   try
      LoadSettingsForStartup(file_, s, False);
      CheckTrue(s.TryGetByCommand('MY STATE', value), 'MY STATE reads back');
      CheckEquals('', value,
                  'the station bucket is NOT applied under /EXPORT -- the log '
                  + 'says what the contest was');
   finally
      s.Free;
   end;

   (* AND THE SAME FILE, ON AN ORDINARY START, IS IMPORTED. The gate is the
     caller's, not the file's. *)
   s := TR4WSettings.Create;
   try
      LoadSettingsForStartup(file_, s, True);
      CheckTrue(s.TryGetByCommand('MY STATE', value), 'MY STATE reads back');
      CheckEquals('FL', value, 'an interactive start does import it');
   finally
      s.Free;
   end;

   (* THE ONE NAMED VALUE /EXPORT STILL TAKES FROM THE BUCKET, read without
     importing anything else. *)
   CheckEquals('8', StoredLegacyCommand(file_, 'MY ITU ZONE'),
               'a single named command can still be read out of the bucket');
   CheckEquals('', StoredLegacyCommand(file_, 'NO SUCH COMMAND'),
               'and an absent name is empty-handed, not an error');
end;


(* ---------------------------------------------------------------------
  WHAT THE COLLAPSE MAY AND MAY NOT TOUCH.

  Three kinds of entry live in one bucket and only one of them is a second
  home:

    a settings-owned station setting   the second home -- removed
    a contest-scoped setting           ToJSON leaves it out of the settings
                                       section, so the bucket is its ONLY
                                       copy. Removing it would delete the
                                       value -- kept
    a name no property owns            not this migration's business -- kept
  --------------------------------------------------------------------- *)
procedure TSettingsPrecedenceTests.Test_TheCollapseRemovesOnlyTheSecondHome;
var
   dir, file_: string;
   s: TR4WSettings;
   removed: integer;
   value: string;
begin
   BeginTest('Test_TheCollapseRemovesOnlyTheSecondHome');
   dir := TempDirFor('collapse');
   file_ := WriteFixture(dir,
      '      "ExternalLogger" : { "Port" : 52001 }',
      '      "other" : { "MY GRID" : "EL88", "MP3 PATH" : "C:\\MP3" },'
      + sLineBreak +
      '      "operating" : { "HF BAND ENABLE" : "TRUE" }');

   s := TR4WSettings.Create;
   try
      LoadSettingsForStartup(file_, s);
      removed := CollapseLegacySettingHomes(file_, s);
      CheckTrue(removed > 0, 'something had a second home');

      CheckEquals(NOT_IN_BUCKET, BucketValue(file_, 'MY GRID'),
                  'the settings-owned station setting left the bucket');
      CheckEquals('TRUE', BucketValue(file_, 'HF BAND ENABLE'),
                  'a contest-scoped setting stays -- the bucket is its only copy');
      CheckEquals('C:\MP3', BucketValue(file_, 'MP3 PATH'),
                  'a name no property owns is left entirely alone');
   finally
      s.Free;
   end;

   (* AND THE VALUE IS IN THE SETTINGS SECTION NOW -- the half that makes the
     removal safe. A fresh object, loaded from the rewritten file. *)
   s := TR4WSettings.Create;
   try
      CheckTrue(LoadSettingsForStartup(file_, s), 'the file still loads');
      CheckTrue(s.TryGetByCommand('MY GRID', value), 'MY GRID reads back');
      CheckEquals('EL88', value,
                  'the value moved to the settings section, it was not dropped');
   finally
      s.Free;
   end;
end;


(* A SECOND RUN MUST DO NOTHING AT ALL, including not rewriting the file. A
  save on every start is a save that can fail on every start. *)
procedure TSettingsPrecedenceTests.Test_TheCollapseIsIdempotent;
var
   dir, file_: string;
   s: TR4WSettings;
   before: TStringList;
   after: TStringList;
begin
   BeginTest('Test_TheCollapseIsIdempotent');
   dir := TempDirFor('idempotent');
   file_ := WriteFixture(dir,
      '      "ExternalLogger" : { "Port" : 52001 }',
      '      "other" : { "MY GRID" : "EL88" }');

   s := TR4WSettings.Create;
   before := TStringList.Create;
   after := TStringList.Create;
   try
      LoadSettingsForStartup(file_, s);
      CheckTrue(CollapseLegacySettingHomes(file_, s) > 0, 'the first run works');
      before.LoadFromFile(file_);

      CheckEquals(0, CollapseLegacySettingHomes(file_, s),
                  'the second run finds nothing to do');
      after.LoadFromFile(file_);
      CheckEquals(before.Text, after.Text,
                  'and does not rewrite the file');
   finally
      after.Free;
      before.Free;
      s.Free;
   end;
end;


(* ---------------------------------------------------------------------
  THE CASE NY4I WILL ACTUALLY TRY: clear COMPUTER ID, restart, still clear.

  The restart is simulated the honest way -- save, throw the object away,
  build a new one and load the same file -- because the defect was never in
  the object at all. It was that a second copy of the value outlived the
  clearing.

  FAILS AGAINST THE OLD CODE at the last assertion: the bucket kept "A", and
  ApplyStoredCommands put it back on the next start.
  --------------------------------------------------------------------- *)
procedure TSettingsPrecedenceTests.Test_ClearingComputerIdSurvivesARestart;
var
   dir, file_: string;
   s: TR4WSettings;
   value: string;
begin
   BeginTest('Test_ClearingComputerIdSurvivesARestart');
   dir := TempDirFor('computerid');
   file_ := WriteFixture(dir,
      '      "ExternalLogger" : { "Port" : 52001 }',
      '      "other" : { "COMPUTER ID" : "A" }');

   (* FIRST START: the id is imported out of the bucket and the two homes are
     collapsed into one. *)
   s := TR4WSettings.Create;
   try
      LoadSettingsForStartup(file_, s);
      CheckTrue(s.TryGetByCommand('COMPUTER ID', value), 'COMPUTER ID reads back');
      CheckEquals('A', value, 'the stored id is in force');
      CollapseLegacySettingHomes(file_, s);
      CheckEquals(NOT_IN_BUCKET, BucketValue(file_, 'COMPUTER ID'),
                  'and the bucket no longer carries a second copy');
   finally
      s.Free;
   end;

   (* THE OPERATOR CLEARS IT. What Preferences does through
     ApplyAndStoreCommand, which now persists an owned command to the settings
     section and nowhere else. *)
   s := TR4WSettings.Create;
   try
      LoadSettingsForStartup(file_, s);
      CheckTrue(s.TrySetByCommand('COMPUTER ID', ''),
                'an empty id is a legal value for this setting');
      SaveSettings(file_, s);
   finally
      s.Free;
   end;

   (* THE RESTART. *)
   s := TR4WSettings.Create;
   try
      LoadSettingsForStartup(file_, s);
      CheckTrue(s.TryGetByCommand('COMPUTER ID', value), 'COMPUTER ID reads back');
      CheckEquals('', value, 'the id is STILL cleared after a restart');
      CheckEquals(NOT_IN_BUCKET, BucketValue(file_, 'COMPUTER ID'),
                  'and nothing put a second copy back');
   finally
      s.Free;
   end;
end;


(* ---------------------------------------------------------------------
  A STATION-ONLY SETTING, WHICH IS WHAT LogCfg ASKS BEFORE IT APPLIES A
  CONTEST .cfg LINE.

  DISPLAY LANGUAGE is the one. It could not take effect from a .cfg anyway --
  StartupUILanguage chooses the catalogue before any .cfg is read -- but
  applying it would put the contest's language on the property, and the next
  Preferences save would write that into the station's file for good.

  The marker is a property of the GROUP, so this also pins that an ordinary
  station setting does NOT carry it. Almost everything is the station's and
  may legitimately be overridden by a contest; station-only is the narrow
  case, not the default.
  --------------------------------------------------------------------- *)
procedure TSettingsPrecedenceTests.Test_DisplayLanguageIsStationOnly;
var
   s: TR4WSettings;
begin
   BeginTest('Test_DisplayLanguageIsStationOnly');
   s := TR4WSettings.Create;
   try
      CheckTrue(s.OwnsCommand('DISPLAY LANGUAGE'),
                'the model owns the command at all');
      CheckTrue(s.CommandIsStationOnly('DISPLAY LANGUAGE'),
                'DISPLAY LANGUAGE is the station''s and a contest may not set it');

      CheckFalse(s.CommandIsStationOnly('MY GRID'),
                 'an ordinary station setting is NOT station-only -- a contest '
                 + 'may override it for the duration');
      CheckFalse(s.CommandIsStationOnly('LEADING ZEROS'),
                 'and neither is one six real contest .cfgs set');
      CheckFalse(s.CommandIsStationOnly('NO SUCH COMMAND'),
                 'an unknown name is simply False, not an error');
   finally
      s.Free;
   end;
end;


(* ---------------------------------------------------------------------
  THE NEW CONTEST PRE-FILL, WHICH HAD NEVER ONCE FIRED.

  The dialog runs BEFORE LoadSettingsForStartup, so it read
  Settings.My.MainCallsign from an object still holding its constructor
  defaults: always '', so the guard skipped the assignment every time and the
  box opened empty on a station that has had a callsign for years.

  The fix is the sanctioned shape for anything running that early -- read the
  file, never assign Settings, never save -- so what is pinned here is the
  READER, on the three files it can be handed.
  --------------------------------------------------------------------- *)
procedure TSettingsPrecedenceTests.Test_StartupMainCallsignReadsTheFile;
var
   dir, file_: string;
   f: TStringList;
begin
   BeginTest('Test_StartupMainCallsignReadsTheFile');
   dir := TempDirFor('prefill');

   (* THE ORDINARY CASE: the settings section states it. *)
   file_ := WriteFixture(dir,
      '      "My" : { "MainCallsign" : "NY4I" }',
      '      "other" : { }');
   CheckEquals('NY4I', StartupMainCallsign(file_),
               'the callsign comes out of the settings section');

   (* A STATION THAT HAS NEVER USED THIS DIALOG has My.Call and not
     My.MainCallsign. Offering the callsign it plainly has beats an empty
     box. *)
   file_ := WriteFixture(dir,
      '      "My" : { "Call" : "W4AFC" }',
      '      "other" : { }');
   CheckEquals('W4AFC', StartupMainCallsign(file_),
               'MY CALL is the fallback when MAIN CALLSIGN was never set');

   (* NOT YET COLLAPSED: the value is still only in the legacy bucket, and the
     dialog runs before the collapse on that one upgrade start. *)
   file_ := WriteFixture(dir,
      '      "ExternalLogger" : { "Port" : 52001 }',
      '      "other" : { "MY CALL" : "N6TR" }');
   CheckEquals('N6TR', StartupMainCallsign(file_),
               'the legacy bucket answers on the run before the collapse');

   (* A FIRST RUN WITH NO FILE MUST OPEN WITH AN EMPTY BOX. *)
   CheckEquals('', StartupMainCallsign(dir + 'no_such_file.json'),
               'no file is a first run, not an error');

   (* AND NEITHER A BLANK NOR A CORRUPT FILE MAY CRASH. ReadRootOrEmpty
     answers an empty document for both. *)
   file_ := dir + 'blank.json';
   f := TStringList.Create;
   try
      f.Text := '';
      f.SaveToFile(file_);
      CheckEquals('', StartupMainCallsign(file_), 'a blank file is empty-handed');

      f.Text := '{ this is not json';
      f.SaveToFile(file_ + '.bad.json');
      CheckEquals('', StartupMainCallsign(file_ + '.bad.json'),
                  'and so is a corrupt one -- no crash');
   finally
      f.Free;
   end;
end;



(* ---------------------------------------------------------------------
  THE LEGACY tr4w.ini IS THE CONVERTER'S INPUT, NOT A STARTUP SOURCE.

  NY4I, 2026-09-19: "calling ReadInConfigFile(cfgINI) that does nothing is
  pointless and should be removed."  The startup read is gone, cfgINI is no
  longer a member of TCFGType, and tr4w\tools\tr4wconvert --ini <path> is the
  one thing that reads the file.

  WHAT THESE TWO PIN, AND WHAT THEY CANNOT.  The settings load is reachable
  from a unit test; ReadInConfigFile is not -- it lives in LogCfg, which needs
  MainUnit's globals, which is the same reason ApplyStoredCommands is not
  tested here.  So what is asserted is the invariant an operator would feel:
  a populated tr4w.ini SITTING BESIDE the settings file contributes nothing,
  and an inert or absent one is indistinguishable from it.

  THE REMOVAL ITSELF WAS MEASURED AGAINST THE 5.0.11 BINARY rather than
  asserted here, because the behaviour it removed lived in that unreachable
  half.  A scratch install with

      [COMMANDS]
      HAMSCORE USERNAME=MixedCaseUser

  logged, at HEAD:

      [Config] Loading ...\settings\tr4w.ini
      [case fixup] "HAMSCORE USERNAME" restored, value=MixedCaseUser

  -- the ini's ctPassword/case second pass writing straight onto the settings
  object.  Both lines are absent afterwards.  Note what was ALREADY inert
  before the removal: CheckCommand is called with aApplyJSONOwned = False for
  anything that is not the contest .cfg, so an ordinary settings-owned command
  in an ini could not reach a property even then.  The case pass was the one
  route that bypassed that guard.
  --------------------------------------------------------------------- *)
procedure TSettingsPrecedenceTests.Test_ALegacyIniIsNotAStartupSource;
var
   dir, file_: string;
   s: TR4WSettings;
   value: string;
   ini: TStringList;
begin
   BeginTest('Test_ALegacyIniIsNotAStartupSource');
   dir := TempDirFor('legacyini');

   file_ := WriteFixture(dir,
      '      "Hamscore" : { "Username" : "FROM SETTINGS" }',
      '      "other" : { }');

   (* A POPULATED ini BESIDE IT, in the shape a 4.x station really has: the
     [COMMANDS] section, one KEY=VALUE per line, including the two kinds the
     old read could still apply -- a case-sensitive value and an action. *)
   ini := TStringList.Create;
   try
      ini.Add('[COMMANDS]');
      ini.Add('HAMSCORE USERNAME=MixedCaseUser');
      ini.Add('MY GRID=ZZ99zz');
      ini.Add('ADD DOMESTIC COUNTRY=ZZ');
      ini.SaveToFile(IncludeTrailingPathDelimiter(dir) + 'tr4w.ini');
   finally
      ini.Free;
   end;

   s := TR4WSettings.Create;
   try
      CheckTrue(LoadSettingsForStartup(file_, s),
                'the settings file loads with an ini sitting next to it');

      CheckTrue(s.TryGetByCommand('HAMSCORE USERNAME', value),
                'HAMSCORE USERNAME reads back');
      CheckEquals('FROM SETTINGS', value,
                  'the ini does not displace the settings section -- it is the '
                  + 'converter''s input, not a startup source');

      CheckTrue(s.TryGetByCommand('MY GRID', value), 'MY GRID reads back');
      CheckEquals('', value,
                  'and an ini-only value does not appear from nowhere either');
   finally
      s.Free;
   end;
end;


(* ---------------------------------------------------------------------
  AN INERT OR ABSENT ini IS INDISTINGUISHABLE FROM A POPULATED ONE.

  This is the half that used to need a detector.  NY4I's own tr4w.ini is 67
  bytes of sentinel prose, and the old code carried FileHasCommands purely so
  that file was not opened and not announced.  With no reader at all, "does it
  hold commands" stops being a question the program asks -- so the three cases
  below have to agree, exactly, and the assertion is that agreement rather
  than any one value.

  NO WARNING EITHER.  An in-program "you still have an ini" check was written
  and withdrawn the same day -- NY4I: "it frankly kept getting in the way and
  causing confusion".  That message belongs to SETUP.
  --------------------------------------------------------------------- *)
procedure TSettingsPrecedenceTests.Test_AnInertOrAbsentIniChangesNothing;

   function LoadedUsername(const aDir: string): string;
   var
      file_: string;
      s: TR4WSettings;
   begin
      Result := '<not read>';
      file_ := WriteFixture(aDir,
         '      "Hamscore" : { "Username" : "FROM SETTINGS" }',
         '      "other" : { "MY GRID" : "EL88" }');
      s := TR4WSettings.Create;
      try
         LoadSettingsForStartup(file_, s);
         s.TryGetByCommand('HAMSCORE USERNAME', Result);
      finally
         s.Free;
      end;
   end;

var
   noIni, sentinel, populated: string;
   f: TStringList;
   dir: string;
begin
   BeginTest('Test_AnInertOrAbsentIniChangesNothing');

   (* NO ini AT ALL -- a station installed at 5.x. *)
   noIni := LoadedUsername(TempDirFor('noini'));

   (* THE SENTINEL, byte for byte the shape NY4I's station has: prose, no '='
     on any line, so the old FileHasCommands answered False for it. *)
   dir := TempDirFor('sentinelini');
   f := TStringList.Create;
   try
      f.Add('THIS FILE HAS BEEN MADE READONLY TO STOP THE AGENT FROM WRITING IT.');
      f.SaveToFile(IncludeTrailingPathDelimiter(dir) + 'tr4w.ini');
   finally
      f.Free;
   end;
   sentinel := LoadedUsername(dir);

   (* AND A FULL ONE, which the old read WOULD have acted on. *)
   dir := TempDirFor('fullini');
   f := TStringList.Create;
   try
      f.Add('[COMMANDS]');
      f.Add('HAMSCORE USERNAME=MixedCaseUser');
      f.SaveToFile(IncludeTrailingPathDelimiter(dir) + 'tr4w.ini');
   finally
      f.Free;
   end;
   populated := LoadedUsername(dir);

   CheckEquals('FROM SETTINGS', noIni, 'no ini: the settings section answers');
   CheckEquals(noIni, sentinel,
               'a sentinel ini is indistinguishable from no ini');
   CheckEquals(noIni, populated,
               'and so is a populated one -- startup has no ini reader left');
end;


procedure TSettingsPrecedenceTests.RunAllTests;
begin
   Test_TheSettingsSectionBeatsTheLegacyBucket;
   Test_ALegacyOnlyValueIsNotLostOnUpgrade;
   Test_TheExportPathDoesNotImportTheBucket;
   Test_TheCollapseRemovesOnlyTheSecondHome;
   Test_TheCollapseIsIdempotent;
   Test_ClearingComputerIdSurvivesARestart;
   Test_DisplayLanguageIsStationOnly;
   Test_StartupMainCallsignReadsTheFile;
   Test_ALegacyIniIsNotAStartupSource;
   Test_AnInertOrAbsentIniChangesNothing;
end;

end.
